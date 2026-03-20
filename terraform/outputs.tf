output "app_vm_external_ip" {
  description = "External IP of the app VM"
  value       = google_compute_instance.app_vm.network_interface[0].access_config[0].nat_ip
}

output "app_vm_internal_ip" {
  description = "Internal IP of the app VM"
  value       = google_compute_instance.app_vm.network_interface[0].network_ip
}

output "monitoring_vm_external_ip" {
  description = "External IP of the monitoring VM"
  value       = google_compute_instance.monitoring_vm.network_interface[0].access_config[0].nat_ip
}

output "monitoring_vm_internal_ip" {
  description = "Internal IP of the monitoring VM"
  value       = google_compute_instance.monitoring_vm.network_interface[0].network_ip
}

output "app_vm_name" {
  value = google_compute_instance.app_vm.name
}

output "monitoring_vm_name" {
  value = google_compute_instance.monitoring_vm.name
}

output "service_account_email" {
  value = google_service_account.travel_vm_sa.email
}

output "vm_external_ip" {
  description = "Backward-compatible alias for the app VM external IP"
  value       = google_compute_instance.app_vm.network_interface[0].access_config[0].nat_ip
}
