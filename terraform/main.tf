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

# ── VM Instance ──────────────────────────────────────────────────────────────
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

  # Persistent monitoring disk attached as secondary
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
    email  = google_service_account.travel_vm_sa.email
    scopes = ["cloud-platform"]
  }

  metadata = {
    ssh-keys = "deploy:${var.ssh_public_key}"
  }

  lifecycle {
    # Don't recreate the VM if only metadata/tags change
    ignore_changes = [metadata, tags]
  }
}

# ── Firewall Rules ────────────────────────────────────────────────────────────
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

# Grafana and Prometheus are exposed only through nginx on port 80
# Do NOT add a firewall rule for 3000/9090 — access via /grafana and /prometheus paths
