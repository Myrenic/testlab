variable "proxmox" {
  sensitive = true
  type = object({
    url                   = string
    username              = string
    password              = string
    download_datastore_id = string
    host_description      = string
    host_tags             = list(string)
  })
}

variable "helios" {
  type = object({
    hosts = map(object({
      name           = string
      cores          = number
      memory         = number
      ip_addr        = string
      gateway        = string
      cidr           = string
      node_name      = string
      network_bridge = string
      datastore_id   = string
      vlan_id        = number
      disk_size      = number
    }))
    talos = object({
      cluster_name             = string
      version                  = string
      control_plane_identifier = string
      worker_identifier        = string
      img_id                   = string
      vip                      = string
      vip_interface            = optional(string, "eth0")
    })
  })
}
