variable "proxmox" {
  type = object({
    url      = string
    username = string
    password = string
  })
  sensitive   = true
  description = "Proxmox connection details"
}

variable "templates" {
  type = object({
    node_name        = string
    build_storage    = string
    template_storage = string
    build_ip         = string
    build_gateway    = string
    build_bridge     = string
    base_vmid        = number
    docker_vmid      = number
    github_user      = optional(string, "")
  })
  description = "Template build configuration"
}
