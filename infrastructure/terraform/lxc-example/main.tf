terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
  }
}

provider "proxmox" {
  endpoint = var.proxmox.url
  username = var.proxmox.username
  password = var.proxmox.password
  insecure = true
}

module "test_lxc" {
  source = "../modules/lxc"

  hostname       = "lxc-test-01"
  description    = "Test LXC container from AlmaLinux base template"
  template_vmid  = var.template_vmid
  node_name      = var.proxmox.node_name
  cores          = 2
  memory         = 1024
  disk_size      = 8
  datastore_id   = var.proxmox.datastore_id
  network_bridge = var.network_bridge
  vlan_id        = var.vlan_id
  ip_address     = var.container_ip
  gateway        = var.container_gw
  tags           = ["lxc", "almalinux", "test"]
}
