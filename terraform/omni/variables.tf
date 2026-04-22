variable "host" {
  type = object({
    name           = string
    cores          = number
    memory         = number
    ip_addr        = string
    gateway        = string
    cidr           = string
    node_name      = string
    network_bridge = string
    datastore_id   = string
    vlan_id        = optional(number, 0)
    disk_size      = number
  })
}

variable "proxmox" {
  sensitive = true
  type = object({
    url                   = string
    username              = string
    password              = string
    download_node_name    = string
    download_datastore_id = string
    host_description      = string
    host_tags             = list(string)
  })
}

variable "renew_certs" {
  description = "Set to true to force server TLS certificate renewal on the next tofu apply."
  type        = bool
  default     = false
}

variable "omni" {
  sensitive = true
  type = object({
    # Hostname clients use to reach the Omni UI/API (e.g. omni.example.com or IP)
    endpoint = string
    # Hostname for the Dex OIDC provider (can be the same as endpoint)
    auth_endpoint = string
    # Initial admin user email
    admin_email = string
    # Admin login password (plain-text; bcrypt-hashed on the remote host, never stored in state)
    admin_password = string
    # Public IP of the VM – used for WireGuard advertisement and TLS SAN
    public_ip = string
  })
}
