output "runner_ip" {
  value       = var.runner.host.ip_addr
  sensitive   = true
  description = "IP address of the GitHub Actions runner"
}

output "runner_container_id" {
  value       = module.lxc.container_id
  sensitive   = true
  description = "Proxmox container ID"
}
