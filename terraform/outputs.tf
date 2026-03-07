output "vm_external_ip" {
  description = "External IP of the VM — used by Ansible for provisioning"
  value       = google_compute_instance.travel_vm.network_interface[0].access_config[0].nat_ip
}

output "vm_name" {
  value = google_compute_instance.travel_vm.name
}

output "service_account_email" {
  value = google_service_account.travel_vm_sa.email
}
