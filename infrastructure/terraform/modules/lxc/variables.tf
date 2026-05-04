variable "hostname" {
  type        = string
  description = "Container hostname"
}

variable "description" {
  type        = string
  default     = "LXC container deployed from base template"
  description = "Container description"
}

variable "template_vmid" {
  type        = number
  description = "VMID of the LXC template to clone from"
}

variable "node_name" {
  type        = string
  description = "Proxmox node to deploy on"
}

variable "vmid" {
  type        = number
  default     = null
  description = "VMID for the new container (auto-assigned if null)"
}

variable "cores" {
  type        = number
  default     = 2
  description = "Number of CPU cores"
}

variable "memory" {
  type        = number
  default     = 1024
  description = "Memory in MB"
}

variable "disk_size" {
  type        = number
  default     = 8
  description = "Root disk size in GB"
}

variable "datastore_id" {
  type        = string
  default     = "local-lvm"
  description = "Storage for container disk"
}

variable "network_bridge" {
  type        = string
  default     = "vmbr0"
  description = "Network bridge"
}

variable "vlan_id" {
  type        = number
  default     = 0
  description = "VLAN tag (0 = none)"
}

variable "ip_address" {
  type        = string
  description = "Static IP in CIDR notation (e.g., 10.0.0.10/24)"
}

variable "gateway" {
  type        = string
  description = "Default gateway IP"
}

variable "ssh_public_keys" {
  type        = list(string)
  default     = []
  description = "SSH public keys for root access"
}

variable "tags" {
  type        = list(string)
  default     = ["lxc", "almalinux"]
  description = "Tags for the container"
}

variable "start_on_create" {
  type        = bool
  default     = true
  description = "Start container after creation"
}

variable "unprivileged" {
  type        = bool
  default     = true
  description = "Run as unprivileged container"
}

variable "nesting" {
  type        = bool
  default     = true
  description = "Enable nesting (required for some workloads)"
}

variable "startup_order" {
  type        = number
  default     = 0
  description = "Boot order (lower = earlier)"
}
