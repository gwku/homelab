# Create VMs using k8s-cluster module
module "k8s_cluster" {
  source = "./modules/k8s-cluster"

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
  gateway   = var.gateway
  
  # Cloud-init Configuration
  ciuser     = var.ciuser
  cipassword = var.cipassword
  ssh_keys   = var.ssh_keys
  
  # SSH Configuration for k3s installation
  ssh_private_key = var.ssh_private_key
}

# Output values from the k3s cluster module
output "master_ips" {
  description = "IP addresses of the master nodes"
  value       = module.k8s_cluster.master_ips
}

output "worker_ips" {
  description = "IP addresses of the worker nodes"
  value       = module.k8s_cluster.worker_ips
}

output "k3s_token" {
  description = "k3s cluster token (sensitive)"
  value       = module.k8s_cluster.k3s_token
  sensitive   = true
}

output "kubeconfig_command" {
  description = "Command to get the kubeconfig file"
  value       = module.k8s_cluster.kubeconfig_command
}

output "cluster_endpoint" {
  description = "k3s cluster endpoint"
  value       = module.k8s_cluster.cluster_endpoint
}

# ==========================================
# Bootstrap k3s cluster with Flux
# ==========================================

resource "flux_bootstrap_git" "k3s_cluster" {
  depends_on = [
    module.k8s_cluster
  ]

  embedded_manifests = true
  path               = var.flux_cluster_path
}
