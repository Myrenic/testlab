#!/usr/bin/env bash
# Provision base packages on AlmaLinux 9 LXC template
set -euo pipefail

echo "==> Updating system packages..."
dnf update -y

echo "==> Enabling EPEL repository..."
dnf install -y epel-release

echo "==> Installing base packages..."
dnf install -y \
  git \
  htop \
  sudo \
  curl \
  wget \
  vim-minimal \
  bash-completion \
  dnf-utils \
  policycoreutils \
  cronie

echo "==> Enabling crond service..."
systemctl enable crond

echo "==> Creating standard admin group with sudo access..."
if ! getent group admins >/dev/null 2>&1; then
  groupadd admins
fi
echo '%admins ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/admins
chmod 440 /etc/sudoers.d/admins

echo "==> Base provisioning complete."
