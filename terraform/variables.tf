variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "europe-west3"
}

variable "zone" {
  description = "GCP zone"
  type        = string
  default     = "europe-west3-a"
}

variable "machine_type" {
  description = "VM machine type"
  type        = string
  default     = "e2-small"
}

variable "monitoring_disk_size_gb" {
  description = "Size in GB for the persistent monitoring disk (Prometheus + Grafana data)"
  type        = number
  default     = 10
}

variable "ssh_public_key" {
  description = "SSH public key for the deploy user (stored in GitHub Variables: SSH_PUBLIC_KEY)"
  type        = string
}

variable "firebase_app_id" {
  description = "Firebase App ID (stored in GitHub Variables: FIREBASE_APP_ID)"
  type        = string
}

variable "firestore_location" {
  description = "Firestore multi-region location. Cannot be changed after creation. eur3=Europe (covers europe-west*), nam5=US, asia1=Asia."
  type        = string
  default     = "eur3"
}
