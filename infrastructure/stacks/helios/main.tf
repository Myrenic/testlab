module "image" {
  source     = "../../modules/talos-image"
  proxmox    = var.proxmox
  talos      = var.helios.talos
  node_names = toset([for host in var.helios.hosts : host.node_name])
}

module "vm" {
  source    = "../../modules/talos-vm"
  hosts     = var.helios.hosts
  proxmox   = var.proxmox
  image_ids = module.image.image_ids
  talos     = var.helios.talos
}

module "talos" {
  source            = "../../modules/talos-cluster"
  hosts             = var.helios.hosts
  talos             = var.helios.talos
  control_plane_ips = module.vm.control_plane_ips
  worker_ips        = module.vm.worker_ips
  depends_on        = [module.vm]
}
