variable "proxmox" {
  sensitive = true
  type = object({
    url          = string
    username     = string
    password     = string
    node_name    = string
    datastore_id = string
  })
}

variable "template_vmid" {
  type        = number
  description = "VMID of the AlmaLinux base LXC template built by Packer"
}

variable "network_bridge" {
  type    = string
  default = "vmbr0"
}

variable "vlan_id" {
  type    = number
  default = 0
}

variable "container_ip" {
  type        = string
  description = "Static IP for the test container (CIDR, e.g., 10.0.0.50/24)"
}

variable "container_gw" {
  type        = string
  description = "Gateway IP for the test container"
}
