# ─── Firestore (Serverless NoSQL Database) ───────────────────────────────────
# Firestore in Native mode is fully serverless — no instances to manage.
# It scales automatically and has a generous free tier (1 GiB storage, 50k reads/day, 20k writes/day).

resource "google_firestore_database" "travel_db" {
  project     = var.project_id
  name        = "(default)"
  location_id = var.firestore_location
  type        = "FIRESTORE_NATIVE"

  # Serverless: no provisioning needed — billed per operation
  deletion_policy = "DELETE"
}

# Composite indexes for efficient querying
resource "google_firestore_index" "conversations_by_user" {
  project    = var.project_id
  database   = google_firestore_database.travel_db.name
  collection = "conversations"

  fields {
    field_path = "user_id"
    order      = "ASCENDING"
  }
  fields {
    field_path = "created_at"
    order      = "DESCENDING"
  }
}

resource "google_firestore_index" "api_usage_by_date" {
  project    = var.project_id
  database   = google_firestore_database.travel_db.name
  collection = "api_usage"

  fields {
    field_path = "date"
    order      = "DESCENDING"
  }
  fields {
    field_path = "request_count"
    order      = "DESCENDING"
  }
}
