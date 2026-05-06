terraform {
  backend "s3" {
    bucket = "tfstate"
    key    = "templates/terraform.tfstate"
    endpoints = {
      s3 = "http://10.0.3.22:3900"
    }
    region                      = "garage"
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_metadata_api_check     = true
    skip_requesting_account_id  = true
    use_path_style              = true
  }
  required_version = ">= 1.6"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.66.0"
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
