terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
  }
}

resource "proxmox_virtual_environment_container" "lxc" {
  description = var.description
  node_name   = var.node_name
  vm_id       = var.vmid
  tags        = var.tags

  clone {
    vm_id = var.template_vmid
  }

  cpu {
    cores = var.cores
  }

  memory {
    dedicated = var.memory
  }

  disk {
    datastore_id = var.datastore_id
    size         = var.disk_size
  }

  network_interface {
    name    = "eth0"
    bridge  = var.network_bridge
    vlan_id = var.vlan_id != 0 ? var.vlan_id : null
  }

  initialization {
    hostname = var.hostname

    ip_config {
      ipv4 {
        address = var.ip_address
        gateway = var.gateway
      }
    }

    user_account {
      keys = var.ssh_public_keys
    }
  }

  features {
    nesting = var.nesting
  }

  started     = var.start_on_create
  unprivileged = var.unprivileged

  startup {
    order = var.startup_order
  }

  lifecycle {
    ignore_changes = [
      initialization[0].user_account,
    ]
  }
}
