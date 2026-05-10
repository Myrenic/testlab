locals {
  container_ip         = "${var.homeassistant_voice.host.ip_addr}${var.homeassistant_voice.host.cidr}"
  bootstrap_public_key = trimspace(file("~/.ssh/id_ed25519.pub"))
  proxmox_ssh_host     = split(":", trimprefix(trimprefix(trimsuffix(var.proxmox.url, "/"), "https://"), "http://"))[0]
  proxmox_ssh_user     = split("@", var.proxmox.username)[0]
}

module "lxc" {
  source = "../../modules/lxc"

  hostname       = var.homeassistant_voice.host.name
  description    = var.proxmox.host_description
  template_vmid  = var.homeassistant_voice.host.template_vmid
  node_name      = var.homeassistant_voice.host.node_name
  vmid           = try(var.homeassistant_voice.host.vmid, null)
  cores          = var.homeassistant_voice.host.cores
  memory         = var.homeassistant_voice.host.memory
  disk_size      = var.homeassistant_voice.host.disk_size
  datastore_id   = var.homeassistant_voice.host.datastore_id
  network_bridge = var.homeassistant_voice.host.network_bridge
  vlan_id        = nonsensitive(var.homeassistant_voice.host.vlan_id)
  ip_address     = local.container_ip
  gateway        = var.homeassistant_voice.host.gateway
  tags           = var.proxmox.host_tags
  start_on_boot  = true
  startup_order  = var.homeassistant_voice.host.startup_order
  nesting        = true
}

resource "terraform_data" "bootstrap_ssh" {
  triggers_replace = [
    module.lxc.container_id,
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
    ansible_host                 = var.homeassistant_voice.host.ip_addr
    ansible_user                 = "root"
    ansible_python_interpreter   = "/usr/bin/python3"
    ansible_ssh_private_key_file = "~/.ssh/id_ed25519"
    ansible_ssh_extra_args       = "-o StrictHostKeyChecking=no"
    whisper_model                = var.homeassistant_voice.voice.whisper_model
    whisper_language             = var.homeassistant_voice.voice.whisper_language
    piper_voice                  = var.homeassistant_voice.voice.piper_voice
    wake_word_model              = var.homeassistant_voice.voice.wake_word_model
    ollama_model                 = var.homeassistant_voice.voice.ollama_model
    ollama_keep_alive            = var.homeassistant_voice.voice.ollama_keep_alive
    ollama_context_length        = tostring(var.homeassistant_voice.voice.ollama_context_length)
    ollama_num_parallel          = tostring(var.homeassistant_voice.voice.ollama_num_parallel)
  }

  replayable = false
  depends_on = [terraform_data.bootstrap_ssh]
}
