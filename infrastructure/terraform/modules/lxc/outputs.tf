output "container_id" {
  value       = proxmox_virtual_environment_container.lxc.vm_id
  description = "VMID of the created container"
}

output "hostname" {
  value       = var.hostname
  description = "Hostname of the container"
}

output "ip_address" {
  value       = var.ip_address
  description = "IP address of the container"
}
