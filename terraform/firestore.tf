# Firestore database in Native mode (required for Firebase SDKs)
# Note: GCP only allows one Firestore database per project in the free tier.
# If you already have a Firestore DB, import it instead of creating:
#   terraform import google_firestore_database.travel_db "(default)"

resource "google_firestore_database" "travel_db" {
  project     = var.project_id
  name        = "(default)"
  location_id = var.firestore_location
  type        = "FIRESTORE_NATIVE"

  # Prevent accidental deletion of your database and all its data
  deletion_policy = "DELETE"

  lifecycle {
    prevent_destroy = true
  }
}
