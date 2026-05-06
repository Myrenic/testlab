output "container_id" {
  value       = module.lxc.container_id
  description = "VMID of the Atlas LXC container"
  sensitive   = true
}

output "hostname" {
  value       = module.lxc.hostname
  description = "Hostname of the Atlas LXC container"
  sensitive   = true
}

output "ip_address" {
  value       = module.lxc.ip_address
  description = "Static IPv4 address assigned to the Atlas container"
  sensitive   = true
}
