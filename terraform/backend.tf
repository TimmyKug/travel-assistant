# GCS backend — bucket and prefix are passed via -backend-config in CI.
# For local development, run:
#   terraform init \
#     -backend-config="bucket=YOUR_PROJECT_ID-tf-state" \
#     -backend-config="prefix=travel-assistant/state"
terraform {
  backend "gcs" {}
}
