#!/usr/bin/env bash
#
# build.sh - Orchestrates Packer LXC template build on Proxmox
#
# This script:
#   1. Downloads AlmaLinux 9 LXC template to Proxmox
#   2. Creates a temporary container
#   3. Bootstraps SSH via pct exec on the Proxmox host
#   4. Runs Packer provisioning over SSH
#   5. Stops container and converts to template
#
# Prerequisites:
#   - curl, jq, ssh-keygen, packer, sshpass
#   - Network access to Proxmox API and SSH to Proxmox host
#
# Usage:
#   export PROXMOX_URL="https://proxmox.example.com:8006"
#   export PROXMOX_USERNAME="root@pam"
#   export PROXMOX_PASSWORD="your-password"
#   export PROXMOX_NODE="pve"
#   export PROXMOX_SSH_HOST="proxmox.example.com"  # defaults to host from URL
#   export BUILD_STORAGE="local-lvm"
#   export TEMPLATE_STORAGE="local"
#   export CONTAINER_IP="10.0.3.200/24"
#   export CONTAINER_GW="10.0.3.1"
#   export CONTAINER_BRIDGE="vmbr0"
#   export TEMPLATE_VMID="9000"  # optional, auto-assigned if empty
#   ./build.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Configuration ---
PROXMOX_URL="${PROXMOX_URL:?Set PROXMOX_URL}"
PROXMOX_USERNAME="${PROXMOX_USERNAME:?Set PROXMOX_USERNAME}"
PROXMOX_PASSWORD="${PROXMOX_PASSWORD:?Set PROXMOX_PASSWORD}"
PROXMOX_NODE="${PROXMOX_NODE:?Set PROXMOX_NODE}"

# Extract host from PROXMOX_URL for SSH access (strip protocol and port)
PROXMOX_SSH_HOST="${PROXMOX_SSH_HOST:-$(echo "${PROXMOX_URL}" | sed -E 's|https?://||;s|:[0-9]+$||')}"
# Extract SSH user from PROXMOX_USERNAME (root@pam -> root)
PROXMOX_SSH_USER="${PROXMOX_USERNAME%%@*}"

BUILD_STORAGE="${BUILD_STORAGE:-local-lvm}"
TEMPLATE_STORAGE="${TEMPLATE_STORAGE:-local}"
CONTAINER_IP="${CONTAINER_IP:?Set CONTAINER_IP (CIDR, e.g., 10.0.3.200/24)}"
CONTAINER_GW="${CONTAINER_GW:?Set CONTAINER_GW}"
CONTAINER_BRIDGE="${CONTAINER_BRIDGE:-vmbr0}"
CONTAINER_VLAN="${CONTAINER_VLAN:-}"
TEMPLATE_VMID="${TEMPLATE_VMID:-}"
TEMPLATE_NAME="${TEMPLATE_NAME:-almalinux-9-base}"
GITHUB_USER="${GITHUB_USER:-}"

# Template name is auto-discovered from the Proxmox appliance catalog
ALMALINUX_TEMPLATE=""

# --- Helpers ---
TMPDIR_BUILD="$(mktemp -d)"
SSH_KEY_FILE="${TMPDIR_BUILD}/packer_key"
CSRF_TOKEN=""
TICKET=""

cleanup() {
  echo "==> Cleaning up temporary files..."
  rm -rf "${TMPDIR_BUILD}"

  if [[ -n "${BUILD_VMID:-}" ]]; then
    echo "==> Stopping and destroying build container ${BUILD_VMID}..."
    pve_ssh "pct stop ${BUILD_VMID} 2>/dev/null; sleep 2; pct destroy ${BUILD_VMID} --purge 2>/dev/null" || true
  fi
}
trap cleanup EXIT

log() { echo "[$(date '+%H:%M:%S')] $*"; }

pve_ssh() {
  sshpass -p "${PROXMOX_PASSWORD}" ssh -o StrictHostKeyChecking=no -o LogLevel=ERROR \
    "${PROXMOX_SSH_USER}@${PROXMOX_SSH_HOST}" "$@"
}

api_auth() {
  log "Authenticating with Proxmox API..."
  local response
  response=$(curl -sk -d "username=${PROXMOX_USERNAME}&password=${PROXMOX_PASSWORD}" \
    "${PROXMOX_URL}/api2/json/access/ticket")
  TICKET=$(echo "${response}" | jq -r '.data.ticket')
  CSRF_TOKEN=$(echo "${response}" | jq -r '.data.CSRFPreventionToken')

  if [[ "${TICKET}" == "null" || -z "${TICKET}" ]]; then
    echo "ERROR: Failed to authenticate with Proxmox API" >&2
    echo "${response}" >&2
    exit 1
  fi
}

api_request() {
  local method="$1"
  local path="$2"
  shift 2
  curl -sk -X "${method}" \
    -H "CSRFPreventionToken: ${CSRF_TOKEN}" \
    -b "PVEAuthCookie=${TICKET}" \
    "$@" \
    "${PROXMOX_URL}/api2/json${path}"
}

wait_for_task() {
  local upid="$1"
  local encoded_upid
  encoded_upid=$(python3 -c "import urllib.parse; print(urllib.parse.quote('${upid}', safe=''))")
  log "Waiting for task: ${upid}"
  while true; do
    local status
    status=$(api_request "GET" "/nodes/${PROXMOX_NODE}/tasks/${encoded_upid}/status" | jq -r '.data.status')
    if [[ "${status}" == "stopped" ]]; then
      local exitstatus
      exitstatus=$(api_request "GET" "/nodes/${PROXMOX_NODE}/tasks/${encoded_upid}/status" | jq -r '.data.exitstatus')
      if [[ "${exitstatus}" == "OK" ]]; then
        log "Task completed successfully."
        return 0
      else
        log "ERROR: Task failed with status: ${exitstatus}"
        return 1
      fi
    fi
    sleep 2
  done
}

# --- Main ---
log "Starting AlmaLinux 9 LXC template build..."

# Verify SSH access to Proxmox host
log "Verifying SSH access to Proxmox host ${PROXMOX_SSH_HOST}..."
if ! pve_ssh "echo ok" >/dev/null 2>&1; then
  log "ERROR: Cannot SSH to Proxmox host ${PROXMOX_SSH_HOST} as ${PROXMOX_SSH_USER}"
  exit 1
fi

# Generate ephemeral SSH key
ssh-keygen -t ed25519 -f "${SSH_KEY_FILE}" -N "" -q
SSH_PUBKEY="$(cat "${SSH_KEY_FILE}.pub")"

# Authenticate
api_auth

# Discover the latest AlmaLinux 9 template from Proxmox appliance catalog
log "Discovering latest AlmaLinux 9 template from appliance catalog..."
ALMALINUX_TEMPLATE=$(api_request "GET" "/nodes/${PROXMOX_NODE}/aplinfo" | \
  jq -r '[.data[] | select(.template | startswith("almalinux-9-default"))] | sort_by(.version) | last | .template')

if [[ -z "${ALMALINUX_TEMPLATE}" || "${ALMALINUX_TEMPLATE}" == "null" ]]; then
  log "ERROR: Could not find AlmaLinux 9 template in Proxmox appliance catalog"
  exit 1
fi
log "Found template: ${ALMALINUX_TEMPLATE}"

# Download AlmaLinux template if not present
log "Ensuring AlmaLinux template is available on ${PROXMOX_NODE}..."
EXISTING=$(api_request "GET" "/nodes/${PROXMOX_NODE}/storage/${TEMPLATE_STORAGE}/content" | \
  jq -r ".data[] | select(.volid | contains(\"${ALMALINUX_TEMPLATE}\")) | .volid")

if [[ -z "${EXISTING}" ]]; then
  log "Downloading AlmaLinux 9 template..."
  RESPONSE=$(api_request "POST" "/nodes/${PROXMOX_NODE}/aplinfo" \
    --data-urlencode "storage=${TEMPLATE_STORAGE}" \
    --data-urlencode "template=${ALMALINUX_TEMPLATE}")
  UPID=$(echo "${RESPONSE}" | jq -r '.data')
  if [[ -n "${UPID}" && "${UPID}" != "null" ]]; then
    wait_for_task "${UPID}"
  fi
else
  log "Template already available: ${EXISTING}"
fi

# Determine template volid
OSTEMPLATE="${TEMPLATE_STORAGE}:vztmpl/${ALMALINUX_TEMPLATE}"

# Get next VMID if not specified
if [[ -z "${TEMPLATE_VMID}" ]]; then
  BUILD_VMID=$(api_request "GET" "/cluster/nextid" | jq -r '.data')
else
  BUILD_VMID="${TEMPLATE_VMID}"
fi
log "Using VMID: ${BUILD_VMID}"

# Build network config string
NET_CONFIG="name=eth0,bridge=${CONTAINER_BRIDGE},ip=${CONTAINER_IP},gw=${CONTAINER_GW}"
if [[ -n "${CONTAINER_VLAN}" ]]; then
  NET_CONFIG="${NET_CONFIG},tag=${CONTAINER_VLAN}"
fi

# Create container
log "Creating build container..."
RESPONSE=$(api_request "POST" "/nodes/${PROXMOX_NODE}/lxc" \
  --data-urlencode "vmid=${BUILD_VMID}" \
  --data-urlencode "ostemplate=${OSTEMPLATE}" \
  --data-urlencode "hostname=packer-build-${BUILD_VMID}" \
  --data-urlencode "storage=${BUILD_STORAGE}" \
  --data-urlencode "rootfs=${BUILD_STORAGE}:4" \
  --data-urlencode "memory=1024" \
  --data-urlencode "cores=2" \
  --data-urlencode "net0=${NET_CONFIG}" \
  --data-urlencode "start=0" \
  --data-urlencode "unprivileged=0" \
  --data-urlencode "features=nesting=1")

UPID=$(echo "${RESPONSE}" | jq -r '.data')
wait_for_task "${UPID}"

# Start container
log "Starting build container..."
RESPONSE=$(api_request "POST" "/nodes/${PROXMOX_NODE}/lxc/${BUILD_VMID}/status/start")
UPID=$(echo "${RESPONSE}" | jq -r '.data')
wait_for_task "${UPID}"

# Bootstrap SSH inside the container via pct exec
log "Bootstrapping SSH inside container via pct exec..."
pve_ssh bash -s <<BOOTSTRAP
set -e
pct exec ${BUILD_VMID} -- bash -c '
  dnf install -y openssh-server
  ssh-keygen -A
  mkdir -p /root/.ssh
  chmod 700 /root/.ssh
  echo "${SSH_PUBKEY}" > /root/.ssh/authorized_keys
  chmod 600 /root/.ssh/authorized_keys
  sed -i "s/#*PermitRootLogin.*/PermitRootLogin prohibit-password/" /etc/ssh/sshd_config
  systemctl enable --now sshd
'
BOOTSTRAP
log "SSH bootstrap complete."

# Extract IP without CIDR prefix
CONTAINER_IP_BARE="${CONTAINER_IP%%/*}"

# Wait for SSH
log "Waiting for SSH on ${CONTAINER_IP_BARE}..."
for i in $(seq 1 30); do
  if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=2 -i "${SSH_KEY_FILE}" \
    root@"${CONTAINER_IP_BARE}" "echo ready" >/dev/null 2>&1; then
    log "SSH is ready."
    break
  fi
  if [[ $i -eq 30 ]]; then
    log "ERROR: Timed out waiting for SSH"
    exit 1
  fi
  sleep 2
done

# Run Packer
log "Running Packer provisioning..."
cd "${SCRIPT_DIR}"
packer init .
packer build \
  -var "proxmox_url=${PROXMOX_URL}" \
  -var "proxmox_username=${PROXMOX_USERNAME}" \
  -var "proxmox_password=${PROXMOX_PASSWORD}" \
  -var "container_ip=${CONTAINER_IP_BARE}" \
  -var "ssh_private_key_file=${SSH_KEY_FILE}" \
  -var "github_user=${GITHUB_USER}" \
  .

# Stop container
log "Stopping build container..."
RESPONSE=$(api_request "POST" "/nodes/${PROXMOX_NODE}/lxc/${BUILD_VMID}/status/stop")
UPID=$(echo "${RESPONSE}" | jq -r '.data')
wait_for_task "${UPID}"

# Convert to template
log "Converting container ${BUILD_VMID} to template '${TEMPLATE_NAME}'..."
api_request "POST" "/nodes/${PROXMOX_NODE}/lxc/${BUILD_VMID}/template"
sleep 2

# Rename the template
api_request "PUT" "/nodes/${PROXMOX_NODE}/lxc/${BUILD_VMID}/config" \
  --data-urlencode "hostname=${TEMPLATE_NAME}" \
  --data-urlencode "description=AlmaLinux 9 base LXC template - built $(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Unset BUILD_VMID so cleanup doesn't destroy the template
BUILD_VMID=""

log "=========================================="
log "Template build complete!"
log "Template VMID: ${TEMPLATE_VMID}"
log "Template Name: ${TEMPLATE_NAME}"
log "=========================================="
