#!/usr/bin/env bash
# Setup automatic daily updates via cron on AlmaLinux 9
set -euo pipefail

echo "==> Installing dnf-automatic..."
dnf install -y dnf-automatic

echo "==> Configuring dnf-automatic for all updates..."
cat > /etc/dnf/automatic.conf <<'EOF'
[commands]
upgrade_type = default
random_sleep = 3600
download_updates = yes
apply_updates = yes

[emitters]
emit_via = stdio

[command]
command_format = cat

[command_email]
email_from = root@localhost
email_to = root@localhost
email_host = localhost

[base]
debuglevel = 1
EOF

echo "==> Creating cron job for daily updates..."
cat > /etc/cron.d/auto-updates <<'EOF'
# Run dnf-automatic daily at 3 AM (with random delay up to 1h built into dnf-automatic)
SHELL=/bin/bash
PATH=/sbin:/bin:/usr/sbin:/usr/bin
0 3 * * * root /usr/bin/dnf-automatic /etc/dnf/automatic.conf --timer
EOF

chmod 644 /etc/cron.d/auto-updates

echo "==> Auto-updates configured (daily all updates at 3 AM)."
