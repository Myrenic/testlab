terraform {
  required_version = ">= 1.6"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.66.0"
    }
    ansible = {
      source  = "ansible/ansible"
      version = ">= 1.3.0"
    }
  }
}

provider "proxmox" {
  endpoint = var.proxmox.url
  username = var.proxmox.username
  password = var.proxmox.password
  insecure = true

  ssh {
    agent    = false
    username = split("@", var.proxmox.username)[0]
    password = var.proxmox.password
  }
}
