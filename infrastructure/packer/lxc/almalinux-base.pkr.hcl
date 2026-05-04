packer {
  required_plugins {}
}

variable "proxmox_url" {
  type        = string
  description = "Proxmox API URL (e.g., https://proxmox.example.com:8006)"
}

variable "proxmox_username" {
  type        = string
  description = "Proxmox API username (e.g., root@pam)"
}

variable "proxmox_password" {
  type        = string
  sensitive   = true
  description = "Proxmox API password"
}

variable "container_ip" {
  type        = string
  description = "IP address assigned to the build container (set by build.sh)"
}

variable "ssh_private_key_file" {
  type        = string
  description = "Path to SSH private key for provisioning (set by build.sh)"
}

variable "ssh_username" {
  type        = string
  default     = "root"
  description = "SSH user for provisioning"
}

source "null" "almalinux" {
  communicator  = "ssh"
  ssh_host      = var.container_ip
  ssh_username  = var.ssh_username
  ssh_private_key_file = var.ssh_private_key_file
  ssh_timeout   = "5m"
}

build {
  sources = ["source.null.almalinux"]

  provisioner "shell" {
    script = "scripts/provision.sh"
  }

  provisioner "shell" {
    script = "scripts/harden-ssh.sh"
  }

  provisioner "shell" {
    script = "scripts/auto-updates.sh"
  }

  provisioner "shell" {
    inline = [
      "dnf clean all",
      "rm -rf /tmp/* /var/tmp/*",
      "rm -f /etc/ssh/ssh_host_*",
      "truncate -s 0 /etc/machine-id",
      "rm -f /var/log/*.log /var/log/lastlog /var/log/wtmp /var/log/btmp",
      "history -c"
    ]
  }
}
