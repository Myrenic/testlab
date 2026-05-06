locals {
  container_ip         = "${var.tailscale.host.ip_addr}${var.tailscale.host.cidr}"
  bootstrap_public_key = trimspace(file("~/.ssh/id_ed25519.pub"))
  proxmox_ssh_host     = split(":", trimprefix(trimprefix(trimsuffix(var.proxmox.url, "/"), "https://"), "http://"))[0]
  proxmox_ssh_user     = split("@", var.proxmox.username)[0]
}

module "lxc" {
  source = "../../modules/lxc"

  hostname          = var.tailscale.host.name
  description       = var.proxmox.host_description
  template_vmid     = var.tailscale.host.template_vmid
  node_name         = var.tailscale.host.node_name
  vmid              = try(var.tailscale.host.vmid, null)
  cores             = var.tailscale.host.cores
  memory            = var.tailscale.host.memory
  disk_size         = var.tailscale.host.disk_size
  datastore_id      = var.tailscale.host.datastore_id
  network_bridge    = var.tailscale.host.network_bridge
  vlan_id           = var.tailscale.host.vlan_id
  ip_address        = local.container_ip
  gateway           = var.tailscale.host.gateway
  tags              = var.proxmox.host_tags
  start_on_boot     = true
  startup_order     = var.tailscale.host.startup_order
  keyctl            = true
  enable_tun_device = true
}

resource "terraform_data" "bootstrap_ssh" {
  triggers_replace = [
    module.lxc.container_id,
    sha256(local.bootstrap_public_key),
  ]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail
      sshpass -p "$PROXMOX_PASSWORD" ssh -o StrictHostKeyChecking=no -o LogLevel=ERROR "$PROXMOX_SSH_USER@$PROXMOX_SSH_HOST" "CTID='$CONTAINER_ID' KEY_B64='$SSH_PUBLIC_KEY_B64' bash -s" <<'REMOTE'
      set -euo pipefail
      for i in $(seq 1 30); do
        if pct exec "$CTID" -- true >/dev/null 2>&1; then
          break
        fi
        sleep 2
      done
      pct exec "$CTID" -- env KEY_B64="$KEY_B64" bash -lc '
        set -euo pipefail
        KEY=$(printf %s "$KEY_B64" | base64 -d)
        mkdir -p /root/.ssh
        chmod 700 /root/.ssh
        touch /root/.ssh/authorized_keys
        if ! grep -qxF "$KEY" /root/.ssh/authorized_keys; then
          printf "%s\n" "$KEY" >> /root/.ssh/authorized_keys
        fi
        chmod 600 /root/.ssh/authorized_keys
        systemctl enable --now sshd
      '
      REMOTE
    EOT

    environment = {
      CONTAINER_ID       = module.lxc.container_id
      PROXMOX_PASSWORD   = var.proxmox.password
      PROXMOX_SSH_HOST   = local.proxmox_ssh_host
      PROXMOX_SSH_USER   = local.proxmox_ssh_user
      SSH_PUBLIC_KEY_B64 = base64encode(local.bootstrap_public_key)
    }
  }

  depends_on = [module.lxc]
}

resource "ansible_playbook" "deploy" {
  name     = module.lxc.hostname
  playbook = "${path.module}/playbook.yaml"

  extra_vars = {
    ansible_host                 = var.tailscale.host.ip_addr
    ansible_user                 = "root"
    ansible_python_interpreter   = "/usr/bin/python3"
    ansible_ssh_private_key_file = "~/.ssh/id_ed25519"
    ansible_ssh_extra_args       = "-o StrictHostKeyChecking=no"
    tailscale_auth_key           = var.tailscale.tailscale.auth_key
    tailscale_force_reauth       = tostring(var.tailscale.tailscale.force_reauth_with_auth_key)
    tailscale_hostname           = var.tailscale.tailscale.hostname != "" ? var.tailscale.tailscale.hostname : var.tailscale.host.name
    tailscale_ssh                = tostring(var.tailscale.tailscale.ssh)
    tailscale_advertise_exit     = tostring(var.tailscale.tailscale.advertise_exit_node)
    tailscale_accept_dns         = tostring(var.tailscale.tailscale.accept_dns)
    tailscale_accept_routes      = tostring(var.tailscale.tailscale.accept_routes)
    tailscale_advertise_routes   = join(",", var.tailscale.tailscale.advertise_routes)
    tailscale_advertise_tags     = join(",", var.tailscale.tailscale.advertise_tags)
  }

  replayable = true
  depends_on = [terraform_data.bootstrap_ssh]
}
