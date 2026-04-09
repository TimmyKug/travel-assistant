resource "google_firestore_database" "travel_db" {
  project     = var.project_id
  name        = "(default)"
  location_id = var.firestore_location
  type        = "FIRESTORE_NATIVE"

  # ABANDON means Terraform removes it from state on `terraform destroy`
  # without deleting the GCP resource — safest default.
  deletion_policy = "ABANDON"
}

resource "google_storage_bucket" "firestore_backups" {
  name                        = "${var.project_id}-firestore-backups"
  location                    = var.region
  force_destroy               = true
  uniform_bucket_level_access = true

  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type = "Delete"
    }
  }
}

resource "google_service_account" "firestore_backup_sa" {
  account_id   = "firestore-backup-sa"
  display_name = "Firestore Backup Service Account"
}

resource "google_project_iam_member" "firestore_export_admin" {
  project = var.project_id
  role    = "roles/datastore.importExportAdmin"
  member  = "serviceAccount:${google_service_account.firestore_backup_sa.email}"
}

resource "google_storage_bucket_iam_member" "firestore_backup_bucket_admin" {
  bucket = google_storage_bucket.firestore_backups.name
  role   = "roles/storage.admin"
  member = "serviceAccount:${google_service_account.firestore_backup_sa.email}"
}

resource "google_cloud_scheduler_job" "firestore_daily_export" {
  name        = "firestore-daily-export"
  description = "Triggers a daily Firestore export"
  schedule    = "0 3 * * *"
  time_zone   = "Europe/Berlin"
  region      = var.region

  http_target {
    http_method = "POST"
    uri         = "https://firestore.googleapis.com/v1/projects/${var.project_id}/databases/(default):exportDocuments"

    oauth_token {
      service_account_email = google_service_account.firestore_backup_sa.email
    }

    headers = {
      "Content-Type" = "application/json"
    }

    body = base64encode(jsonencode({
      outputUriPrefix = "gs://${google_storage_bucket.firestore_backups.name}/scheduled"
    }))
  }
}
