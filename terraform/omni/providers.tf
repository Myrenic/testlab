terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
    ansible = {
      source = "ansible/ansible"
    }
    random = {
      source = "hashicorp/random"
    }
    http = {
      source = "hashicorp/http"
    }
  }
}

provider "proxmox" {
  endpoint = var.proxmox.url
  username = var.proxmox.username
  password = var.proxmox.password
  insecure = true
}
