locals {
  proxmox_ssh_host = split(":", trimprefix(trimprefix(trimsuffix(var.proxmox.url, "/"), "https://"), "http://"))[0]
  proxmox_ssh_user = split("@", var.proxmox.username)[0]
  build_ip_bare    = split("/", var.templates.build_ip)[0]
  scripts_dir      = "${path.module}/scripts"
}

# ─── Base AlmaLinux Template ─────────────────────────────────────────────────

resource "proxmox_virtual_environment_container" "base_build" {
  description = "Temporary build container for base template"
  node_name   = var.templates.node_name
  vm_id       = var.templates.base_vmid

  cpu {
    cores = 2
  }

  memory {
    dedicated = 1024
  }

  disk {
    datastore_id = var.templates.build_storage
    size         = 4
  }

  network_interface {
    name   = "eth0"
    bridge = var.templates.build_bridge
  }

  initialization {
    hostname = "tmpl-base-build"
    ip_config {
      ipv4 {
        address = var.templates.build_ip
        gateway = var.templates.build_gateway
      }
    }
  }

  features {
    nesting = true
  }

  operating_system {
    template_file_id = data.proxmox_virtual_environment_nodes.nodes.names[0] != "" ? local.os_template_volid : ""
    type             = "centos"
  }

  start_on_boot = false
  started       = true
  unprivileged  = false

  lifecycle {
    ignore_changes = all
  }
}

data "proxmox_virtual_environment_nodes" "nodes" {}

locals {
  os_template_volid = "${var.templates.template_storage}:vztmpl/${data.external.almalinux_template.result.template}"
}

data "external" "almalinux_template" {
  program = ["bash", "-c", <<-EOF
    TICKET=$(curl -sk -d "username=${var.proxmox.username}&password=${var.proxmox.password}" \
      "${var.proxmox.url}/api2/json/access/ticket" | jq -r .data.ticket)
    TEMPLATE=$(curl -sk -b "PVEAuthCookie=$TICKET" \
      "${var.proxmox.url}/api2/json/nodes/${var.templates.node_name}/aplinfo" | \
      jq -r '[.data[] | select(.template | startswith("almalinux-9-default"))] | sort_by(.version) | last | .template')
    echo "{\"template\": \"$TEMPLATE\"}"
  EOF
  ]
}

# Ensure the AlmaLinux template is downloaded
resource "terraform_data" "download_template" {
  triggers_replace = [data.external.almalinux_template.result.template]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOF
      set -euo pipefail
      TICKET=$(curl -sk -d "username=$PROXMOX_USER&password=$PROXMOX_PASS" \
        "$PROXMOX_URL/api2/json/access/ticket" | jq -r .data.ticket)
      CSRF=$(curl -sk -d "username=$PROXMOX_USER&password=$PROXMOX_PASS" \
        "$PROXMOX_URL/api2/json/access/ticket" | jq -r .data.CSRFPreventionToken)

      # Check if already present
      EXISTS=$(curl -sk -b "PVEAuthCookie=$TICKET" \
        "$PROXMOX_URL/api2/json/nodes/$NODE/storage/$STORAGE/content" | \
        jq -r ".data[] | select(.volid | contains(\"$TEMPLATE\")) | .volid")

      if [ -z "$EXISTS" ]; then
        echo "Downloading template $TEMPLATE..."
        curl -sk -X POST -H "CSRFPreventionToken: $CSRF" -b "PVEAuthCookie=$TICKET" \
          --data-urlencode "storage=$STORAGE" \
          --data-urlencode "template=$TEMPLATE" \
          "$PROXMOX_URL/api2/json/nodes/$NODE/aplinfo"
        sleep 30
      fi
    EOF

    environment = {
      PROXMOX_URL  = var.proxmox.url
      PROXMOX_USER = var.proxmox.username
      PROXMOX_PASS = var.proxmox.password
      NODE         = var.templates.node_name
      STORAGE      = var.templates.template_storage
      TEMPLATE     = data.external.almalinux_template.result.template
    }
  }
}

# Bootstrap SSH inside the base build container
resource "terraform_data" "base_bootstrap_ssh" {
  triggers_replace = [proxmox_virtual_environment_container.base_build.id]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOF
      set -euo pipefail
      for i in $(seq 1 30); do
        if sshpass -p "$PVE_PASS" ssh -o StrictHostKeyChecking=no -o LogLevel=ERROR \
          "$PVE_USER@$PVE_HOST" "pct exec $CTID -- true" >/dev/null 2>&1; then
          break
        fi
        sleep 2
      done

      sshpass -p "$PVE_PASS" ssh -o StrictHostKeyChecking=no -o LogLevel=ERROR \
        "$PVE_USER@$PVE_HOST" "pct exec $CTID -- bash -c '
          dnf install -y openssh-server >/dev/null 2>&1
          ssh-keygen -A
          mkdir -p /root/.ssh && chmod 700 /root/.ssh
          echo \"$SSH_KEY\" > /root/.ssh/authorized_keys
          chmod 600 /root/.ssh/authorized_keys
          sed -i \"s/#*PermitRootLogin.*/PermitRootLogin prohibit-password/\" /etc/ssh/sshd_config
          systemctl enable --now sshd
        '"
    EOF

    environment = {
      CTID     = var.templates.base_vmid
      PVE_HOST = local.proxmox_ssh_host
      PVE_USER = local.proxmox_ssh_user
      PVE_PASS = var.proxmox.password
      SSH_KEY  = trimspace(file("~/.ssh/id_ed25519.pub"))
    }
  }

  depends_on = [proxmox_virtual_environment_container.base_build]
}

# Provision the base template
resource "terraform_data" "base_provision" {
  triggers_replace = [terraform_data.base_bootstrap_ssh.id]

  connection {
    type        = "ssh"
    host        = local.build_ip_bare
    user        = "root"
    private_key = file("~/.ssh/id_ed25519")
    timeout     = "5m"
  }

  # Base provisioning
  provisioner "file" {
    source      = "${local.scripts_dir}/provision.sh"
    destination = "/tmp/provision.sh"
  }

  provisioner "remote-exec" {
    inline = ["chmod +x /tmp/provision.sh && /tmp/provision.sh"]
  }

  # SSH hardening
  provisioner "file" {
    source      = "${local.scripts_dir}/harden-ssh.sh"
    destination = "/tmp/harden-ssh.sh"
  }

  provisioner "remote-exec" {
    inline = ["chmod +x /tmp/harden-ssh.sh && /tmp/harden-ssh.sh"]
  }

  # Auto-updates
  provisioner "file" {
    source      = "${local.scripts_dir}/auto-updates.sh"
    destination = "/tmp/auto-updates.sh"
  }

  provisioner "remote-exec" {
    inline = ["chmod +x /tmp/auto-updates.sh && /tmp/auto-updates.sh"]
  }

  # Inject SSH keys from GitHub (optional)
  provisioner "remote-exec" {
    inline = [
      var.templates.github_user != "" ? "curl -sL https://github.com/${var.templates.github_user}.keys >> /root/.ssh/authorized_keys" : "echo 'No GitHub user configured, skipping SSH key injection'"
    ]
  }

  # Final cleanup
  provisioner "remote-exec" {
    inline = [
      "dnf clean all",
      "rm -rf /tmp/* /var/tmp/*",
      "rm -f /etc/ssh/ssh_host_*",
      "truncate -s 0 /etc/machine-id",
      "rm -f /var/log/*.log /var/log/lastlog /var/log/wtmp /var/log/btmp",
      "rm -f /root/.bash_history",
      "history -c || true"
    ]
  }

  depends_on = [terraform_data.base_bootstrap_ssh]
}

# Stop and convert to template
resource "terraform_data" "base_to_template" {
  triggers_replace = [terraform_data.base_provision.id]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOF
      set -euo pipefail
      TICKET=$(curl -sk -d "username=$PROXMOX_USER&password=$PROXMOX_PASS" \
        "$PROXMOX_URL/api2/json/access/ticket" | jq -r .data.ticket)
      CSRF=$(curl -sk -d "username=$PROXMOX_USER&password=$PROXMOX_PASS" \
        "$PROXMOX_URL/api2/json/access/ticket" | jq -r .data.CSRFPreventionToken)

      # Stop the container
      UPID=$(curl -sk -X POST -H "CSRFPreventionToken: $CSRF" -b "PVEAuthCookie=$TICKET" \
        "$PROXMOX_URL/api2/json/nodes/$NODE/lxc/$VMID/status/stop" | jq -r .data)
      while true; do
        STATUS=$(curl -sk -b "PVEAuthCookie=$TICKET" \
          "$PROXMOX_URL/api2/json/nodes/$NODE/tasks/$(python3 -c "import urllib.parse; print(urllib.parse.quote('$UPID', safe=''))")/status" | jq -r .data.status)
        [ "$STATUS" = "stopped" ] && break
        sleep 2
      done

      # Convert to template
      curl -sk -X POST -H "CSRFPreventionToken: $CSRF" -b "PVEAuthCookie=$TICKET" \
        "$PROXMOX_URL/api2/json/nodes/$NODE/lxc/$VMID/template"
      sleep 2

      # Set template name and description
      curl -sk -X PUT -H "CSRFPreventionToken: $CSRF" -b "PVEAuthCookie=$TICKET" \
        --data-urlencode "hostname=almalinux-9-base" \
        --data-urlencode "description=AlmaLinux 9 base LXC template - built $(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        "$PROXMOX_URL/api2/json/nodes/$NODE/lxc/$VMID/config"

      echo "Base template created: VMID $VMID"
    EOF

    environment = {
      PROXMOX_URL  = var.proxmox.url
      PROXMOX_USER = var.proxmox.username
      PROXMOX_PASS = var.proxmox.password
      NODE         = var.templates.node_name
      VMID         = var.templates.base_vmid
    }
  }

  depends_on = [terraform_data.base_provision]
}

# ─── Docker Template (cloned from base) ─────────────────────────────────────

resource "terraform_data" "docker_build" {
  triggers_replace = [terraform_data.base_to_template.id]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOF
      set -euo pipefail
      TICKET=$(curl -sk -d "username=$PROXMOX_USER&password=$PROXMOX_PASS" \
        "$PROXMOX_URL/api2/json/access/ticket" | jq -r .data.ticket)
      CSRF=$(curl -sk -d "username=$PROXMOX_USER&password=$PROXMOX_PASS" \
        "$PROXMOX_URL/api2/json/access/ticket" | jq -r .data.CSRFPreventionToken)

      # Clone base template to docker build container
      UPID=$(curl -sk -X POST -H "CSRFPreventionToken: $CSRF" -b "PVEAuthCookie=$TICKET" \
        --data-urlencode "newid=$DOCKER_VMID" \
        --data-urlencode "hostname=tmpl-docker-build" \
        --data-urlencode "full=1" \
        "$PROXMOX_URL/api2/json/nodes/$NODE/lxc/$BASE_VMID/clone" | jq -r .data)
      
      # Wait for clone
      while true; do
        STATUS=$(curl -sk -b "PVEAuthCookie=$TICKET" \
          "$PROXMOX_URL/api2/json/nodes/$NODE/tasks/$(python3 -c "import urllib.parse; print(urllib.parse.quote('$UPID', safe=''))")/status" | jq -r .data.status)
        [ "$STATUS" = "stopped" ] && break
        sleep 2
      done

      # Configure network on cloned container
      curl -sk -X PUT -H "CSRFPreventionToken: $CSRF" -b "PVEAuthCookie=$TICKET" \
        --data-urlencode "net0=name=eth0,bridge=$BRIDGE,ip=$BUILD_IP,gw=$BUILD_GW" \
        "$PROXMOX_URL/api2/json/nodes/$NODE/lxc/$DOCKER_VMID/config"

      # Start container
      UPID=$(curl -sk -X POST -H "CSRFPreventionToken: $CSRF" -b "PVEAuthCookie=$TICKET" \
        "$PROXMOX_URL/api2/json/nodes/$NODE/lxc/$DOCKER_VMID/status/start" | jq -r .data)
      while true; do
        STATUS=$(curl -sk -b "PVEAuthCookie=$TICKET" \
          "$PROXMOX_URL/api2/json/nodes/$NODE/tasks/$(python3 -c "import urllib.parse; print(urllib.parse.quote('$UPID', safe=''))")/status" | jq -r .data.status)
        [ "$STATUS" = "stopped" ] && break
        sleep 2
      done
      sleep 5
    EOF

    environment = {
      PROXMOX_URL  = var.proxmox.url
      PROXMOX_USER = var.proxmox.username
      PROXMOX_PASS = var.proxmox.password
      NODE         = var.templates.node_name
      BASE_VMID    = var.templates.base_vmid
      DOCKER_VMID  = var.templates.docker_vmid
      BUILD_IP     = var.templates.build_ip
      BUILD_GW     = var.templates.build_gateway
      BRIDGE       = var.templates.build_bridge
    }
  }

  depends_on = [terraform_data.base_to_template]
}

# Provision Docker on the cloned container
resource "terraform_data" "docker_provision" {
  triggers_replace = [terraform_data.docker_build.id]

  connection {
    type        = "ssh"
    host        = local.build_ip_bare
    user        = "root"
    private_key = file("~/.ssh/id_ed25519")
    timeout     = "5m"
  }

  # Install Docker CE from CentOS repo
  provisioner "remote-exec" {
    inline = [
      "dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo",
      "dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin",
      "systemctl enable docker",
      "echo 'Docker CE installed and enabled'"
    ]
  }

  # Create /dev/net/tun on boot (for WireGuard/VPN workloads)
  provisioner "remote-exec" {
    inline = [
      "printf '[Unit]\\nDescription=Create /dev/net/tun device\\nBefore=docker.service\\n\\n[Service]\\nType=oneshot\\nExecStart=/bin/bash -c \"mkdir -p /dev/net && [ -e /dev/net/tun ] || mknod /dev/net/tun c 10 200 && chmod 666 /dev/net/tun\"\\nRemainAfterExit=yes\\n\\n[Install]\\nWantedBy=multi-user.target\\n' > /etc/systemd/system/tun-device.service",
      "systemctl enable tun-device.service"
    ]
  }

  # Cleanup for templating
  provisioner "remote-exec" {
    inline = [
      "dnf clean all",
      "rm -rf /tmp/* /var/tmp/*",
      "rm -f /etc/ssh/ssh_host_*",
      "truncate -s 0 /etc/machine-id",
      "rm -f /var/log/*.log /var/log/lastlog /var/log/wtmp /var/log/btmp",
      "rm -f /root/.bash_history",
      "history -c || true"
    ]
  }

  depends_on = [terraform_data.docker_build]
}

# Stop and convert Docker container to template
resource "terraform_data" "docker_to_template" {
  triggers_replace = [terraform_data.docker_provision.id]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOF
      set -euo pipefail
      TICKET=$(curl -sk -d "username=$PROXMOX_USER&password=$PROXMOX_PASS" \
        "$PROXMOX_URL/api2/json/access/ticket" | jq -r .data.ticket)
      CSRF=$(curl -sk -d "username=$PROXMOX_USER&password=$PROXMOX_PASS" \
        "$PROXMOX_URL/api2/json/access/ticket" | jq -r .data.CSRFPreventionToken)

      # Stop the container
      UPID=$(curl -sk -X POST -H "CSRFPreventionToken: $CSRF" -b "PVEAuthCookie=$TICKET" \
        "$PROXMOX_URL/api2/json/nodes/$NODE/lxc/$VMID/status/stop" | jq -r .data)
      while true; do
        STATUS=$(curl -sk -b "PVEAuthCookie=$TICKET" \
          "$PROXMOX_URL/api2/json/nodes/$NODE/tasks/$(python3 -c "import urllib.parse; print(urllib.parse.quote('$UPID', safe=''))")/status" | jq -r .data.status)
        [ "$STATUS" = "stopped" ] && break
        sleep 2
      done

      # Convert to template
      curl -sk -X POST -H "CSRFPreventionToken: $CSRF" -b "PVEAuthCookie=$TICKET" \
        "$PROXMOX_URL/api2/json/nodes/$NODE/lxc/$VMID/template"
      sleep 2

      # Set template name and description
      curl -sk -X PUT -H "CSRFPreventionToken: $CSRF" -b "PVEAuthCookie=$TICKET" \
        --data-urlencode "hostname=almalinux-9-docker" \
        --data-urlencode "description=AlmaLinux 9 + Docker CE LXC template - built $(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        "$PROXMOX_URL/api2/json/nodes/$NODE/lxc/$VMID/config"

      echo "Docker template created: VMID $VMID"
    EOF

    environment = {
      PROXMOX_URL  = var.proxmox.url
      PROXMOX_USER = var.proxmox.username
      PROXMOX_PASS = var.proxmox.password
      NODE         = var.templates.node_name
      VMID         = var.templates.docker_vmid
    }
  }

  depends_on = [terraform_data.docker_provision]
}
