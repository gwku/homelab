# Create VMs using k8s-cluster module
module "k8s_cluster" {
  source = "./resources/k8s-cluster"

  pm_api_url          = var.pm_api_url
  pm_api_token_id     = var.pm_api_token_id
  pm_api_token_secret = var.pm_api_token_secret
  pm_tls_insecure     = true
  
  # VM Configuration
  vms = var.vms
  vm_id_start = var.vm_id_start
  
  # Infrastructure Configuration
  target_nodes    = var.target_nodes
  clone_template  = var.clone_template
  storage         = var.storage
  network_bridge  = var.network_bridge
  
  # Network Configuration
  ip_prefix = var.ip_prefix
  ip_start  = var.ip_start
  
  # Cloud-init Configuration
  ciuser     = var.ciuser
  cipassword = var.cipassword
  ssh_keys   = var.ssh_keys
}
