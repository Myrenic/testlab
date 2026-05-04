#!/usr/bin/env bash
# Fetch and install SSH authorized keys from GitHub
# The GITHUB_USER env var is passed from build.sh via Packer
set -euo pipefail

GITHUB_USER="${GITHUB_USER:-}"

if [[ -z "${GITHUB_USER}" ]]; then
  echo "==> GITHUB_USER not set, skipping SSH key injection"
  exit 0
fi

echo "==> Fetching SSH keys from GitHub user: ${GITHUB_USER}..."
KEYS=$(curl -fsSL "https://github.com/${GITHUB_USER}.keys")

if [[ -z "${KEYS}" ]]; then
  echo "WARNING: No SSH keys found for GitHub user ${GITHUB_USER}"
  exit 0
fi

mkdir -p /root/.ssh
chmod 700 /root/.ssh
echo "${KEYS}" > /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys

KEY_COUNT=$(echo "${KEYS}" | wc -l)
echo "==> Installed ${KEY_COUNT} SSH key(s) from github.com/${GITHUB_USER}"
