variable "proxmox" {
  type = object({
    url              = string
    username         = string
    password         = string
    host_description = optional(string, "Managed by OpenTofu")
    host_tags        = optional(list(string), ["lxc", "almalinux"])
  })
  sensitive   = true
  description = "Proxmox connection details"
}

variable "runner" {
  type = object({
    host = object({
      name           = string
      ip_addr        = string
      cidr           = optional(string, "/24")
      gateway        = string
      template_vmid  = number
      node_name      = string
      vmid           = optional(number)
      cores          = optional(number, 2)
      memory         = optional(number, 2048)
      disk_size      = optional(number, 16)
      datastore_id   = optional(string, "local-lvm")
      network_bridge = optional(string, "vmbr0")
      vlan_id        = optional(number, 0)
    })
    runner = object({
      github_pat  = string
      github_repo = optional(string, "myrenic/testlab")
      labels      = optional(string, "self-hosted,linux,tofu")
    })
  })
  sensitive   = true
  description = "Runner stack configuration"
}
