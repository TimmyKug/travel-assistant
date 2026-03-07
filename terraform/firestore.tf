resource "google_firestore_database" "travel_db" {
  project     = var.project_id
  name        = "(default)"
  location_id = var.firestore_location
  type        = "FIRESTORE_NATIVE"

  # ABANDON means Terraform removes it from state on `terraform destroy`
  # without deleting the GCP resource — safest default.
  deletion_policy = "ABANDON"
}
