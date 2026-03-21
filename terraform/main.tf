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

# ── Service Account ──────────────────────────────────────────────────────────
resource "google_service_account" "travel_vm_sa" {
  account_id   = "travel-assistant-vm"
  display_name = "Travel Assistant VM Service Account"
}

resource "google_project_iam_member" "firestore_user" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.travel_vm_sa.email}"
}

resource "google_project_iam_member" "firebase_auth" {
  project = var.project_id
  role    = "roles/firebase.sdkAdminServiceAgent"
  member  = "serviceAccount:${google_service_account.travel_vm_sa.email}"
}

# ── Artifact Registry ─────────────────────────────────────────────────────────
resource "google_artifact_registry_repository" "travel_assistant" {
  location      = var.region
  repository_id = "travel-assistant"
  format        = "DOCKER"
  description   = "Travel Assistant Docker images"
}

# ── Persistent Disk for Monitoring Data ──────────────────────────────────────
resource "google_compute_disk" "monitoring_data" {
  name  = "travel-assistant-monitoring"
  type  = "pd-standard"
  zone  = var.zone
  size  = var.monitoring_disk_size_gb

  lifecycle {
    # Never destroy monitoring data even if disk config changes
    prevent_destroy = true
  }
}

# ── App VM ───────────────────────────────────────────────────────────────────
resource "google_compute_instance" "travel_vm" {
  name         = "travel-assistant-vm"
  machine_type = var.machine_type
  zone         = var.zone

  tags = ["travel-assistant", "http-server"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 20
      type  = "pd-standard"
    }
  }

  network_interface {
    network = "default"
    access_config {
      # Ephemeral public IP
    }
  }

  service_account {
    email  = google_service_account.travel_vm_sa.email
    scopes = ["cloud-platform"]
  }

  metadata = {
    ssh-keys = "deploy:${var.ssh_public_key}"
  }

  lifecycle {
    ignore_changes = [metadata, tags]
  }
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

  metadata = {
    ssh-keys = "deploy:${var.ssh_public_key}"
  }

  lifecycle {
    ignore_changes = [metadata, tags]
  }
}

# ── Firewall Rules ────────────────────────────────────────────────────────────

# App VM — public HTTP and SSH
resource "google_compute_firewall" "allow_http" {
  name    = "travel-assistant-allow-http"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["travel-assistant"]
}

resource "google_compute_firewall" "allow_ssh" {
  name    = "travel-assistant-allow-ssh"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["travel-assistant"]
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
