output "container_id" {
  value       = module.lxc.container_id
  description = "VMID of the Omni LXC container"
  sensitive   = true
}

output "hostname" {
  value       = module.lxc.hostname
  description = "Hostname of the Omni LXC container"
  sensitive   = true
}

output "ip_address" {
  value       = module.lxc.ip_address
  description = "Static IPv4 address assigned to the Omni container"
  sensitive   = true
}

output "omni_url" {
  description = "Omni UI URL"
  value       = "https://${var.omni.omni.endpoint}"
  sensitive   = true
}
