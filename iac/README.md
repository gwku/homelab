# Kubernetes Cluster Infrastructure with k3s

This Terraform/Tofu configuration creates a highly available Kubernetes cluster on Proxmox VE using k3s and automatically bootstraps GitOps with Flux.

## Features

- **Multi-node k3s cluster**: Creates master and worker nodes with automatic k3s installation
- **High Availability**: Supports multiple master nodes for HA configuration
- **GitOps Ready**: Automatically bootstraps Flux for GitOps workflow
- **GitHub Integration**: Creates and configures GitHub repository for GitOps
- **Automated Setup**: Complete cluster setup from VM creation to GitOps bootstrap
- **Load Balancing**: Distributes VMs across multiple Proxmox nodes
- **Secure**: Uses SSH keys for authentication and generates secure k3s tokens
- **Configurable**: Flexible VM sizing and cluster topology

## Prerequisites

- Proxmox VE server with API access
- Cloud-init enabled VM template (e.g., Ubuntu 20.04/22.04 or Debian 11/12)
- SSH key pair for VM access
- GitHub account with Personal Access Token
- Terraform/Tofu installed

## Quick Start

1. **Clone and Configure**:
   ```bash
   cp terraform.example.tfvars terraform.tfvars
   ```

2. **Edit Configuration**:
   Update `terraform.tfvars` with your environment settings:
   ```hcl
   # Proxmox Configuration
   pm_api_url          = "https://your-proxmox-server:8006/api2/json"
   pm_api_token_id     = "your-user@pve!token-name"
   pm_api_token_secret = "your-token-secret"
   
   # SSH Configuration
   ssh_keys = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAAB..."
   ssh_private_key = "-----BEGIN OPENSSH PRIVATE KEY-----\n...\n-----END OPENSSH PRIVATE KEY-----"
   
   # Network Configuration
   ip_prefix = "192.168.1"
   ip_start  = 10
   gateway   = "192.168.1.1"
   
   # GitHub/GitOps Configuration
   github_org          = "your-github-username"
   github_repository   = "homelab-gitops"
   github_token        = "ghp_your-personal-access-token"
   flux_cluster_path   = "clusters/production"
   
   # Cluster Configuration
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
   ```

3. **Deploy the Cluster**:
   ```bash
   tofu init
   tofu plan
   tofu apply
   ```

## GitOps with Flux

This configuration automatically sets up GitOps using Flux:

### What Gets Created

1. **GitHub Repository**: A private repository for your GitOps manifests
2. **Flux Bootstrap**: Flux controllers installed in the `flux-system` namespace
3. **Git Integration**: Flux configured to monitor your GitHub repository
4. **Cluster Manifests**: Initial cluster configuration stored in Git

### Repository Structure

After bootstrap, your GitHub repository will contain:
```
clusters/
└── production/
    └── flux-system/
        ├── gotk-components.yaml
        ├── gotk-sync.yaml
        └── kustomization.yaml
```

### Managing Your Cluster

1. **Add Applications**: Place Kubernetes manifests in your repository
2. **Flux Sync**: Flux automatically applies changes from Git
3. **Git Workflow**: Use pull requests for cluster changes

### Example Application Deployment

Add a new application to your repository:
```yaml
# apps/my-app/namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: my-app

---
# apps/my-app/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
  namespace: my-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
      - name: my-app
        image: nginx:latest
        ports:
        - containerPort: 80
```

Then create a Kustomization to deploy it:
```yaml
# clusters/production/my-app.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: my-app
  namespace: flux-system
spec:
  interval: 10m
  path: "./apps/my-app"
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
```

## Cluster Architecture

### k3s Installation Process

1. **First Master Node**: Initializes the cluster with `--cluster-init`
2. **Additional Masters**: Join the cluster as additional server nodes
3. **Worker Nodes**: Join as agent nodes
4. **Kubeconfig**: Automatically retrieved and configured

### Network Configuration

- **Master Nodes**: Get IPs starting from `${ip_prefix}.${ip_start}`
- **Worker Nodes**: Get IPs starting after master nodes
- **Load Balancer**: k3s built-in load balancer for HA masters

## Configuration Options

### VM Types

The `vms` variable supports flexible cluster topologies:

```hcl
vms = {
  master = {
    count       = 3        # Number of master nodes
    cores       = 2        # CPU cores per node
    sockets     = 1        # CPU sockets per node
    memory      = 4096     # RAM in MB
    disk_size   = "50G"    # Disk size
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
```

### SSH Configuration

Configure SSH access using your private key content:

```hcl
ssh_private_key = <<EOF
-----BEGIN OPENSSH PRIVATE KEY-----
your-private-key-content-here
-----END OPENSSH PRIVATE KEY-----
EOF
```

The private key content is used for all SSH connections during k3s installation and kubeconfig retrieval.

## Accessing the Cluster

### Automatic Kubeconfig

The configuration automatically:
- Downloads kubeconfig from the first master node
- Configures it with the correct server IP
- Saves it to `~/.kube/config`

### Manual Kubeconfig Retrieval

If needed, you can manually retrieve the kubeconfig:

```bash
# Get the kubeconfig command from output
tofu output kubeconfig_command

# Or manually:
scp user@master-ip:/etc/rancher/k3s/k3s.yaml ~/.kube/config
sed -i 's/127.0.0.1/MASTER-IP/g' ~/.kube/config
```

### Cluster Information

View cluster details:
```bash
# Get cluster endpoint
tofu output cluster_endpoint

# Get node IPs
tofu output master_ips
tofu output worker_ips

# Get k3s token (sensitive)
tofu output k3s_token
```

## Verification

After deployment, verify the cluster:

```bash
# Check cluster status
kubectl get nodes

# Check all nodes are ready
kubectl get nodes -o wide

# Check k3s system pods
kubectl get pods -n kube-system
```

## Troubleshooting

### Common Issues

1. **SSH Connection Failures**:
   - Verify SSH keys are correct
   - Check network connectivity
   - Ensure cloud-init has completed

2. **k3s Installation Failures**:
   - Check VM internet connectivity
   - Verify sufficient resources
   - Review logs: `journalctl -u k3s`

3. **Node Not Joining**:
   - Verify k3s token
   - Check network connectivity between nodes
   - Review agent logs: `journalctl -u k3s-agent`

### Logs

Check k3s logs on nodes:
```bash
# Master node
sudo journalctl -u k3s -f

# Worker node
sudo journalctl -u k3s-agent -f
```

## Customization

### k3s Configuration

The installation uses these k3s flags:
- `--cluster-init`: Initialize embedded etcd on first master
- `--flannel-iface=eth0`: Use eth0 for flannel CNI
- `--node-external-ip`: Set external IP for node
- `--server`: Join additional masters to cluster

### Advanced Configuration

For custom k3s configuration, modify the provisioner scripts in:
- `modules/k8s-cluster/main.tf`

## Security

- All SSH communications use private keys
- k3s tokens are generated securely and marked as sensitive
- Network traffic is contained within the specified IP range
- Cloud-init passwords are marked as sensitive

## Cleanup

To destroy the cluster:
```bash
tofu destroy
```

This will:
1. Remove all VMs
2. Clean up associated resources
3. Preserve the original VM template 