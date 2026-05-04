# LXC Base Image Templating System

Packer-based build pipeline for creating hardened AlmaLinux 9 LXC templates on Proxmox, with a reusable Terraform module for deploying containers from the built image.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  build.sh (Orchestrator)                                    │
│                                                             │
│  1. Download AlmaLinux 9 template → Proxmox                 │
│  2. Create temporary LXC container (SSH key injected)       │
│  3. Start container, wait for SSH                           │
│  4. Run Packer (provision via SSH)                          │
│  5. Stop container → Convert to Proxmox template            │
└─────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────┐
│  Proxmox Template (VMID: 9000)                              │
│  ─ AlmaLinux 9 base                                         │
│  ─ Packages: git, htop, sudo, curl, wget, vim              │
│  ─ SSH hardened (key-only, no root password)                │
│  ─ Auto security updates (cron, daily 3AM)                  │
│  ─ Admin group with passwordless sudo                       │
└─────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────┐
│  Terraform Module (infrastructure/terraform/modules/lxc)    │
│  Clone template → per-application LXC deployments           │
└─────────────────────────────────────────────────────────────┘
```

## Prerequisites

- **Proxmox VE** 7.x+ with API access
- **Packer** 1.9+
- **OpenTofu/Terraform** 1.5+
- `curl`, `jq`, `ssh-keygen`, `python3` on the build machine

## Quick Start

### 1. Build the Base Template

```bash
cd infrastructure/packer/lxc/

export PROXMOX_URL="https://proxmox.example.com:8006"
export PROXMOX_USERNAME="root@pam"
export PROXMOX_PASSWORD="your-password"
export PROXMOX_NODE="pve"
export BUILD_STORAGE="local-lvm"
export TEMPLATE_STORAGE="local"
export CONTAINER_IP="10.0.0.200/24"
export CONTAINER_GW="10.0.0.1"
export CONTAINER_BRIDGE="vmbr0"
export TEMPLATE_VMID="9000"

./build.sh
```

### 2. Deploy a Container from the Template

```bash
cd infrastructure/terraform/lxc-example/
cp terraform.auto.tfvars.example terraform.auto.tfvars
# Edit terraform.auto.tfvars with your values
tofu init
tofu plan
tofu apply
```

## Update Strategy: Immutable Rebuild

This system uses an **immutable rebuild** strategy:

1. **Rebuild the template** periodically (weekly/monthly) by re-running `build.sh`
2. **Redeploy containers** by running `tofu apply` — Terraform detects the template change and recreates containers
3. **Auto-updates** handle day-to-day security patches between rebuilds via the cron job

### Recommended Workflow

```bash
# Rebuild template (can be CI/CD triggered)
cd infrastructure/packer/lxc/
./build.sh

# Redeploy all containers using the updated template
cd infrastructure/terraform/lxc-<app>/
tofu apply
```

### CI/CD Integration

Add to your pipeline (e.g., GitHub Actions on a schedule):

```yaml
- name: Build LXC Template
  run: |
    cd infrastructure/packer/lxc
    ./build.sh
  env:
    PROXMOX_URL: ${{ secrets.PROXMOX_URL }}
    PROXMOX_USERNAME: ${{ secrets.PROXMOX_USERNAME }}
    PROXMOX_PASSWORD: ${{ secrets.PROXMOX_PASSWORD }}
    # ... other vars
```

## What's Included in the Base Image

| Category | Details |
|----------|---------|
| **OS** | AlmaLinux 9 (RHEL-compatible) |
| **Packages** | git, htop, sudo, curl, wget, vim, bash-completion, cronie |
| **SSH** | Key-only auth, root password login disabled, max 3 auth tries |
| **Updates** | dnf-automatic via cron, daily security updates at 3 AM |
| **Users** | `admins` group with passwordless sudo |
| **Security** | SSH agent/TCP forwarding disabled, X11 disabled |

## Configuration Reference

### Build Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `PROXMOX_URL` | ✅ | — | Proxmox API endpoint |
| `PROXMOX_USERNAME` | ✅ | — | API username |
| `PROXMOX_PASSWORD` | ✅ | — | API password |
| `PROXMOX_NODE` | ✅ | — | Target Proxmox node |
| `BUILD_STORAGE` | ❌ | `local-lvm` | Storage for build container |
| `TEMPLATE_STORAGE` | ❌ | `local` | Storage for LXC templates |
| `CONTAINER_IP` | ✅ | — | Build container IP (CIDR) |
| `CONTAINER_GW` | ✅ | — | Build container gateway |
| `CONTAINER_BRIDGE` | ❌ | `vmbr0` | Network bridge |
| `CONTAINER_VLAN` | ❌ | — | VLAN tag |
| `TEMPLATE_VMID` | ❌ | auto | Template VMID |
| `TEMPLATE_NAME` | ❌ | `almalinux-9-base` | Template hostname |

### Terraform Module Variables

See `infrastructure/terraform/modules/lxc/variables.tf` for the full list.

## Extending

To add more provisioning to the base image, create a new script in `scripts/` and add it as a provisioner in `almalinux-base.pkr.hcl`:

```hcl
provisioner "shell" {
  script = "scripts/my-custom-setup.sh"
}
```

## Per-Application Deployments

For each application, create a separate Terraform configuration:

```
infrastructure/terraform/lxc-myapp/
├── main.tf          # uses module "../modules/lxc"
├── variables.tf
└── terraform.auto.tfvars
```

This keeps each application's lifecycle independent while sharing the same hardened base image.
