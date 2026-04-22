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

variable "omni" {
  sensitive = true
  type = object({
    # Hostname clients use to reach the Omni UI/API (e.g. omni.example.com or IP)
    endpoint = string
    # Hostname for the Dex OIDC provider (can be the same as endpoint)
    auth_endpoint = string
    # Initial admin user email — auto-logged in via mockCallback (no password needed)
    admin_email = string
    # Public IP of the VM – used for WireGuard advertisement and TLS SAN
    public_ip = string
  })
}
