# Proxmox API Configuration
# Update these values to match your Proxmox environment
pm_api_url          = "https://your-proxmox-server:8006/api2/json"
pm_api_token_id     = "your-user@pve!token-name"
pm_api_token_secret = "your-token-secret"
pm_tls_insecure     = true

# VM Infrastructure Configuration
# List of Proxmox nodes - VMs will be distributed across these nodes in round-robin fashion
target_nodes    = ["node1", "node2"]
clone_template  = "debian12-cloud"
storage         = "local-lvm"
network_bridge  = "vmbr0"
vm_id_start     = 100  # Starting VM ID (will create VMs with IDs 100, 101, 102, etc.)

# Cloud-init Configuration
ciuser     = "debian"
cipassword = "your-secure-password"

# Network Configuration
ip_prefix = "192.168.2"
ip_start  = 10
gateway   = "192.168.2.254"

# SSH Keys for VM access
ssh_keys = "your-ssh-public-key-here"

# SSH Private Key for k3s installation
# Paste your private key content here
ssh_private_key = <<EOF
-----BEGIN OPENSSH PRIVATE KEY-----
your-private-key-content-here
-----END OPENSSH PRIVATE KEY-----
EOF

# Kubernetes Cluster Configuration
# Default configuration provides 3 masters + 3 workers
# Masters will be distributed: master-1 (node1), master-2 (node2), master-3 (node1)
# Workers will be distributed: worker-1 (node2), worker-2 (node1), worker-3 (node2)
vms = {
  master = {
    count       = 3
    cores       = 2
    sockets     = 1
    memory      = 4096
    disk_size   = "50G"
    name_prefix = "k8s-master"
  }
  worker = {
    count       = 3
    cores       = 4
    sockets     = 1
    memory      = 8192
    disk_size   = "100G"
    name_prefix = "k8s-worker"
  }
} 