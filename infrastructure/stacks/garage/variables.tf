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

variable "garage" {
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
      memory         = optional(number, 512)
      disk_size      = optional(number, 32)
      startup_order  = optional(number, 1)
    })
    s3 = object({
      rpc_secret  = string
      admin_token = string
      access_key  = string
      secret_key  = string
      region      = optional(string, "garage")
    })
  })
}
