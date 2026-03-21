output "app_static_ip" {
  description = "Reserved static external IP for the app VM — stable across MIG replacements"
  value       = google_compute_address.app_static_ip.address
}

output "app_mig_name" {
  description = "Name of the app Managed Instance Group"
  value       = google_compute_instance_group_manager.app.name
}

output "monitoring_vm_external_ip" {
  description = "External IP of the monitoring VM"
  value       = google_compute_instance.monitoring_vm.network_interface[0].access_config[0].nat_ip
}

output "monitoring_vm_internal_ip" {
  description = "Internal IP of the monitoring VM — used in promtail Loki URL"
  value       = google_compute_instance.monitoring_vm.network_interface[0].network_ip
}

output "config_bucket_name" {
  description = "GCS bucket that holds non-secret app configs for startup-script bootstrap"
  value       = google_storage_bucket.app_configs.name
}

output "service_account_email" {
  value = google_service_account.travel_vm_sa.email
}
