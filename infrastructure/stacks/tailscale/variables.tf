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

variable "tailscale" {
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
      cores          = optional(number, 1)
      memory         = optional(number, 1024)
      disk_size      = optional(number, 8)
      startup_order  = optional(number, 0)
    })
    tailscale = object({
      auth_key                   = optional(string, "")
      force_reauth_with_auth_key = optional(bool, false)
      hostname                   = optional(string, "")
      ssh                        = optional(bool, true)
      advertise_exit_node        = optional(bool, false)
      accept_dns                 = optional(bool, false)
      accept_routes              = optional(bool, false)
      advertise_routes           = optional(list(string), [])
      advertise_tags             = optional(list(string), [])
    })
  })
}
