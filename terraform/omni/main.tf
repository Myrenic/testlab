data "http" "github_keys" {
  url = "https://github.com/Myrenic.keys"
}

resource "random_password" "vm_password" {
  length           = 16
  override_special = "_%@"
  special          = true
}

resource "proxmox_download_file" "ubuntu_image" {
  content_type = "iso"
  datastore_id = var.proxmox.download_datastore_id
  node_name    = var.proxmox.download_node_name
  file_name    = "ubuntu-22.04-cloudimg-amd64.img"
  url          = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
  overwrite    = false
}

resource "proxmox_virtual_environment_vm" "omni" {
  name        = var.host.name
  description = var.proxmox.host_description
  tags        = var.proxmox.host_tags
  node_name   = var.host.node_name
  on_boot     = true

  cpu {
    cores = var.host.cores
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = var.host.memory
  }

  agent {
    enabled = true
    timeout = "1s"
  }

  network_device {
    bridge  = var.host.network_bridge
    vlan_id = var.host.vlan_id == 0 ? null : var.host.vlan_id
  }

  disk {
    datastore_id = var.host.datastore_id
    file_id      = proxmox_download_file.ubuntu_image.id
    file_format  = "raw"
    interface    = "virtio0"
    size         = var.host.disk_size
  }

  operating_system {
    type = "l26"
  }

  initialization {
    datastore_id = var.host.datastore_id

    ip_config {
      ipv4 {
        address = "${var.host.ip_addr}${var.host.cidr}"
        gateway = var.host.gateway
      }
    }

    user_account {
      username = "ubuntu"
      password = random_password.vm_password.result
      keys = concat(
        compact(split("\n", chomp(data.http.github_keys.response_body))),
        [trimspace(file("~/.ssh/id_ed25519.pub"))]
      )
    }
  }
}

resource "ansible_playbook" "deploy_omni" {
  name     = proxmox_virtual_environment_vm.omni.name
  playbook = "${path.module}/playbook.yaml"

  extra_vars = {
    ansible_host                 = var.host.ip_addr
    ansible_user                 = "ubuntu"
    ansible_ssh_private_key_file = "~/.ssh/id_ed25519"
    ansible_ssh_extra_args       = "-o StrictHostKeyChecking=no"
    omni_endpoint                = var.omni.endpoint
    auth_endpoint                = var.omni.auth_endpoint
    admin_email                  = var.omni.admin_email
    admin_password               = var.omni.admin_password
    public_ip                    = var.omni.public_ip
  }

  replayable = true
  depends_on = [proxmox_virtual_environment_vm.omni]
}
