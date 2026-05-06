terraform {
  backend "local" {}
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
    ansible = {
      source = "ansible/ansible"
    }
  }
}

provider "proxmox" {
  endpoint = var.proxmox.url
  username = var.proxmox.username
  password = var.proxmox.password
  insecure = true
}
