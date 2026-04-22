output "omni_url" {
  description = "Omni UI URL"
  value       = "https://${var.omni.endpoint}"
  sensitive   = true
}

output "vm_password" {
  description = "Ubuntu VM login password"
  value       = random_password.vm_password.result
  sensitive   = true
}
