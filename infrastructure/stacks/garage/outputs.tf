output "container_id" {
  value     = module.lxc.container_id
  sensitive = true
}

output "hostname" {
  value     = module.lxc.hostname
  sensitive = true
}

output "ip_address" {
  value     = var.garage.host.ip_addr
  sensitive = true
}

output "s3_endpoint" {
  value     = "http://${var.garage.host.ip_addr}:3900"
  sensitive = true
}
