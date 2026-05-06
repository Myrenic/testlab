variable "proxmox" {
  sensitive = true
  type = object({
    url              = string
    username         = string
    password         = string
    host_description = string
    host_tags        = list(string)
  })
}

variable "omni" {
  sensitive = true
  type = object({
    host = object({
      name           = string
      template_vmid  = number
      ip_addr        = string
      gateway        = string
      cidr           = optional(string, "/24")
      node_name      = string
      network_bridge = string
      datastore_id   = string
      vmid           = optional(number)
      vlan_id        = optional(number, 0)
      cores          = optional(number, 4)
      memory         = optional(number, 4096)
      disk_size      = optional(number, 64)
    })
    omni = object({
      endpoint       = string
      auth_endpoint  = string
      admin_email    = string
      admin_password = string
      public_ip      = string
      omni_version   = optional(string, "")
    })
  })
}

variable "renew_certs" {
  description = "Set to true to force server TLS certificate renewal on the next tofu apply."
  type        = bool
  default     = false
}
