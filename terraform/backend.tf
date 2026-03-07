terraform {
  backend "gcs" {
    bucket = "DEIN_PROJECT_ID-terraform-state"  # ← anpassen, muss weltweit eindeutig sein
    prefix = "travel-assistant"
  }
}
