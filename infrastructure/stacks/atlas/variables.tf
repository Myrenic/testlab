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

variable "atlas" {
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
    atlas = object({
      nfs_export_network = string
      nfs_exports = list(object({
        path  = string
        owner = optional(number, 65534)
        group = optional(number, 65534)
        mode  = optional(string, "0775")
      }))
    })
  })
}
