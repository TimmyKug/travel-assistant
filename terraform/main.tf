terraform {
  required_version = ">= 1.7.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# ── Service Account — App VM ──────────────────────────────────────────────────
resource "google_service_account" "travel_vm_sa" {
  account_id   = "travel-assistant-vm"
  display_name = "Travel Assistant App VM Service Account"
}

resource "google_project_iam_member" "firestore_user" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.travel_vm_sa.email}"
}

# App VM SA can read from Artifact Registry (for docker pull in startup script)
resource "google_project_iam_member" "artifact_registry_reader" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.travel_vm_sa.email}"
}

# App VM SA can read configs from GCS (for startup script self-healing bootstrap)
resource "google_storage_bucket_iam_member" "app_sa_configs_reader" {
  bucket = google_storage_bucket.app_configs.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.travel_vm_sa.email}"
}

# ── Secret Manager ────────────────────────────────────────────────────────────
# Runtime secrets (Gemini API key, JWT signing key) live in Secret Manager,
# not in the GCS config bucket. The app VM fetches them at startup via the
# service account below. Secret *values* are injected by CI (`gcloud secrets
# versions add`) so they never enter Terraform state.
resource "google_project_service" "secret_manager_api" {
  service            = "secretmanager.googleapis.com"
  disable_on_destroy = false
}

resource "google_secret_manager_secret" "gemini_api_key" {
  secret_id = "gemini-api-key"
  replication {
    auto {}
  }
  depends_on = [google_project_service.secret_manager_api]
}

resource "google_secret_manager_secret" "jwt_secret_key" {
  secret_id = "jwt-secret-key"
  replication {
    auto {}
  }
  depends_on = [google_project_service.secret_manager_api]
}

resource "google_secret_manager_secret_iam_member" "app_sa_gemini_accessor" {
  secret_id = google_secret_manager_secret.gemini_api_key.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.travel_vm_sa.email}"
}

resource "google_secret_manager_secret_iam_member" "app_sa_jwt_accessor" {
  secret_id = google_secret_manager_secret.jwt_secret_key.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.travel_vm_sa.email}"
}

# ── Service Account — Monitoring VM ──────────────────────────────────────────
resource "google_service_account" "monitoring_vm_sa" {
  account_id   = "travel-assistant-monitoring"
  display_name = "Travel Assistant Monitoring VM Service Account"
}

# Prometheus GCE service discovery needs to list and describe compute instances
resource "google_project_iam_member" "monitoring_compute_viewer" {
  project = var.project_id
  role    = "roles/compute.viewer"
  member  = "serviceAccount:${google_service_account.monitoring_vm_sa.email}"
}

# ── Artifact Registry ─────────────────────────────────────────────────────────
resource "google_artifact_registry_repository" "travel_assistant" {
  location      = var.region
  repository_id = "travel-assistant"
  format        = "DOCKER"
  description   = "Travel Assistant Docker images"
}

# ── GCS Bucket — App Configs ──────────────────────────────────────────────────
# Stores non-secret config files (docker-compose.yml, promtail.yml) so the
# startup script can bootstrap a fresh VM without Ansible.
resource "google_storage_bucket" "app_configs" {
  name                        = "${var.project_id}-travel-assistant-configs"
  location                    = var.region
  force_destroy               = true
  uniform_bucket_level_access = true
}

# ── Global Static IP — App Load Balancer ─────────────────────────────────────
# Reserved for the external HTTP load balancer so the app entrypoint remains
# stable while the MIG rolls or autoheals individual VMs behind it.
resource "google_compute_global_address" "app_static_ip" {
  name = "travel-assistant-app-ip"
}

# ── GCP Health Check — App VM ─────────────────────────────────────────────────
# Used by the MIG autohealer. Three consecutive failures (90 s) → VM replaced.
resource "google_compute_health_check" "app_health" {
  name                = "travel-assistant-app-health"
  check_interval_sec  = 30
  timeout_sec         = 10
  healthy_threshold   = 1
  unhealthy_threshold = 3

  http_health_check {
    port         = 80
    request_path = "/api/health"
  }
}

# ── Instance Template — App VM ────────────────────────────────────────────────
# Defines the blueprint for every app VM the MIG creates.
# The startup script bootstraps the full app stack without Ansible,
# enabling zero-touch recovery when the MIG replaces an unhealthy VM.
resource "google_compute_instance_template" "app" {
  name_prefix  = "travel-assistant-app-"
  machine_type = var.machine_type
  region       = var.region

  tags = ["travel-assistant", "http-server"]

  disk {
    source_image = "debian-cloud/debian-12"
    auto_delete  = true
    boot         = true
    disk_size_gb = 20
    disk_type    = "pd-standard"
  }

  network_interface {
    network = "default"
    access_config {
      # Keep an ephemeral public IP so the VM can install packages and pull
      # images without requiring Cloud NAT. User traffic still enters via the
      # external HTTP load balancer plus firewall restrictions below.
    }
  }

  service_account {
    email  = google_service_account.travel_vm_sa.email
    scopes = ["cloud-platform"]
  }

  metadata = {
    ssh-keys = "deploy:${var.ssh_public_key}"

    # Startup script bootstraps the full app on a fresh VM.
    # Variables are rendered at terraform-apply time.
    startup-script = templatefile("${path.module}/../scripts/startup.sh", {
      project_id    = var.project_id
      region        = var.region
      config_bucket = google_storage_bucket.app_configs.name
      image_tag     = var.app_image_tag
      # Internal IP of the monitoring VM — stable for the VM's lifetime.
      loki_url = "http://${google_compute_instance.monitoring_vm.network_interface[0].network_ip}:3100/loki/api/v1/push"
    })
  }

  lifecycle {
    # Ensure new template version exists before the MIG switches over.
    create_before_destroy = true
  }
}

# ── Managed Instance Group — App VM ──────────────────────────────────────────
# Keeps the app fleet alive. If the GCP health check fails three times in a
# row the MIG replaces unhealthy VMs from the instance template above.
resource "google_compute_instance_group_manager" "app" {
  name               = "travel-assistant-app-mig"
  base_instance_name = "travel-assistant-vm"
  zone               = var.zone

  version {
    instance_template = google_compute_instance_template.app.id
  }

  target_size = 2

  update_policy {
    type                  = "PROACTIVE"
    minimal_action        = "REPLACE"
    max_surge_fixed       = 1
    max_unavailable_fixed = 0
    replacement_method    = "SUBSTITUTE"
  }

  auto_healing_policies {
    health_check = google_compute_health_check.app_health.id

    # Give the startup script 5 min to install Docker, pull images and start
    # the stack before the health check is first evaluated.
    initial_delay_sec = 300
  }

  named_port {
    name = "http"
    port = 80
  }
}

resource "google_compute_backend_service" "app" {
  name                  = "travel-assistant-app-bes"
  protocol              = "HTTP"
  port_name             = "http"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  timeout_sec           = 30
  health_checks         = [google_compute_health_check.app_health.id]

  backend {
    group = google_compute_instance_group_manager.app.instance_group
  }
}

resource "google_compute_url_map" "app" {
  name            = "travel-assistant-app-url-map"
  default_service = google_compute_backend_service.app.id
}

resource "google_compute_target_http_proxy" "app" {
  name    = "travel-assistant-app-http-proxy"
  url_map = google_compute_url_map.app.id
}

resource "google_compute_global_forwarding_rule" "app" {
  name                  = "travel-assistant-app-http-fr"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  ip_protocol           = "TCP"
  port_range            = "80"
  ip_address            = google_compute_global_address.app_static_ip.address
  target                = google_compute_target_http_proxy.app.id
}

# ── Persistent Disk for Monitoring Data ──────────────────────────────────────
resource "google_compute_disk" "monitoring_data" {
  name = "travel-assistant-monitoring"
  type = "pd-standard"
  zone = var.zone
  size = var.monitoring_disk_size_gb
}

# ── Monitoring VM ─────────────────────────────────────────────────────────────
resource "google_compute_instance" "monitoring_vm" {
  name         = "travel-assistant-monitoring-vm"
  machine_type = var.monitoring_machine_type
  zone         = var.zone

  tags = ["travel-monitoring", "http-server"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 20
      type  = "pd-standard"
    }
  }

  # Persistent monitoring disk (Prometheus + Grafana + Loki data)
  attached_disk {
    source      = google_compute_disk.monitoring_data.self_link
    device_name = "monitoring-data"
    mode        = "READ_WRITE"
  }

  network_interface {
    network = "default"
    access_config {
      # Ephemeral public IP
    }
  }

  service_account {
    email  = google_service_account.monitoring_vm_sa.email
    scopes = ["cloud-platform"]
  }

  metadata = {
    ssh-keys = "deploy:${var.ssh_public_key}"
  }

  # Adding a service account to an already-running VM requires a stop/start.
  allow_stopping_for_update = true

  lifecycle {
    ignore_changes = [metadata, tags]
  }
}

# ── Firewall Rules ────────────────────────────────────────────────────────────

# App VM — allow traffic only from the external HTTP load balancer and health checks
resource "google_compute_firewall" "allow_lb_http" {
  name    = "travel-assistant-allow-lb-http"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  target_tags   = ["travel-assistant"]
}

# Monitoring VM scrapes the app's /metrics endpoint over the instance private IP
resource "google_compute_firewall" "allow_metrics_from_monitoring" {
  name    = "travel-assistant-allow-monitoring-http"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_tags = ["travel-monitoring"]
  target_tags = ["travel-assistant"]
}

# Monitoring VM — public HTTP and SSH
resource "google_compute_firewall" "monitoring_allow_http" {
  name    = "travel-monitoring-allow-http"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["travel-monitoring"]
}

resource "google_compute_firewall" "monitoring_allow_ssh" {
  name    = "travel-monitoring-allow-ssh"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["travel-monitoring"]
}

# Allow monitoring VM to scrape node-exporter (9100) on the app VM
resource "google_compute_firewall" "allow_node_exporter_from_monitoring" {
  name    = "travel-allow-node-exporter-from-monitoring"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["9100"]
  }

  source_tags = ["travel-monitoring"]
  target_tags = ["travel-assistant"]
}

# Allow app VM's promtail to push logs to Loki (3100) on the monitoring VM
resource "google_compute_firewall" "allow_loki_from_app" {
  name    = "travel-allow-loki-from-app"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["3100"]
  }

  source_tags = ["travel-assistant"]
  target_tags = ["travel-monitoring"]
}
