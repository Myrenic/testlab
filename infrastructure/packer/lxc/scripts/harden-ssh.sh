#!/usr/bin/env bash
# SSH hardening for AlmaLinux 9 LXC template
set -euo pipefail

echo "==> Hardening SSH configuration..."

SSHD_CONF="/etc/ssh/sshd_config.d/99-hardening.conf"

cat > "${SSHD_CONF}" <<'EOF'
# SSH Hardening - managed by Packer template build
PermitRootLogin prohibit-password
PasswordAuthentication no
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding no
MaxAuthTries 3
MaxSessions 5
ClientAliveInterval 300
ClientAliveCountMax 2
LoginGraceTime 60
AllowAgentForwarding no
AllowTcpForwarding no
EOF

chmod 600 "${SSHD_CONF}"

echo "==> Ensuring sshd is enabled..."
systemctl enable sshd

echo "==> SSH hardening complete."
