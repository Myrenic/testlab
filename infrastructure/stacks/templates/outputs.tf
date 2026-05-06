output "base_template_vmid" {
  value       = var.templates.base_vmid
  description = "VMID of the base AlmaLinux 9 template"
}

output "docker_template_vmid" {
  value       = var.templates.docker_vmid
  description = "VMID of the Docker AlmaLinux 9 template"
}
