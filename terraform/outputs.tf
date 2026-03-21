output "vm_external_ip" {
  description = "External IP of the app VM"
  value       = google_compute_instance.travel_vm.network_interface[0].access_config[0].nat_ip
}

output "vm_internal_ip" {
  description = "Internal IP of the app VM — used in Prometheus scrape config"
  value       = google_compute_instance.travel_vm.network_interface[0].network_ip
}

output "vm_name" {
  value = google_compute_instance.travel_vm.name
}

output "monitoring_vm_external_ip" {
  description = "External IP of the monitoring VM"
  value       = google_compute_instance.monitoring_vm.network_interface[0].access_config[0].nat_ip
}

output "monitoring_vm_internal_ip" {
  description = "Internal IP of the monitoring VM — used in promtail Loki URL"
  value       = google_compute_instance.monitoring_vm.network_interface[0].network_ip
}

output "service_account_email" {
  value = google_service_account.travel_vm_sa.email
}
