# Homelab Infrastructure

A complete Infrastructure as Code (IaC) solution for deploying a Kubernetes cluster on Proxmox VE using OpenTofu/Terraform and Ansible.

## 🏗️ Architecture Overview

This homelab setup provides:

- **Infrastructure Layer**: Proxmox VE virtual machines provisioned with OpenTofu/Terraform
- **Configuration Layer**: Kubernetes cluster deployment and configuration with Ansible
- **Automation**: Automated inventory generation and cluster scaling

### Components

- **Proxmox VE**: Hypervisor platform hosting the virtual machines
- **OpenTofu/Terraform**: Infrastructure provisioning and VM lifecycle management
- **Ansible**: Configuration management and Kubernetes cluster deployment
- **Kubernetes**: Container orchestration platform

## 📋 Prerequisites

### Proxmox VE Setup

1. **Proxmox VE Cluster**: Running Proxmox VE 7.x or 8.x
2. **Cloud-Init Template**: Debian 12 cloud image template configured
3. **Network Configuration**: Bridge network (default: `vmbr0`) with DHCP or static IP range
4. **API Access**: Proxmox API token with sufficient privileges

### Local Environment

- **OpenTofu/Terraform**: v1.6+ installed
- **Ansible**: v2.14+ installed
- **jq**: JSON processor for inventory generation
- **SSH Key Pair**: For accessing the VMs

## 🚀 Quick Start

### 1. Proxmox Template Preparation

Create a Debian 12 cloud-init template on your Proxmox cluster:

```bash
# Run the template creation script in the Proxmox host machine
cd infrastructure/scripts
./create-cloud-template.sh
```

See [infrastructure/scripts/README.md](infrastructure/scripts/README.md) for detailed template setup instructions.

### 2. Infrastructure Deployment

Configure and deploy the virtual machines:

```bash
# Navigate to infrastructure directory
cd infrastructure

# Copy and edit configuration
cp terraform.example.tfvars terraform.auto.tfvars
# Edit terraform.auto.tfvars with your Proxmox details

# Initialize and deploy
tofu init
tofu plan
tofu apply
```

### 3. Generate Ansible Inventory

```bash
# Generate inventory from Terraform state
cd infrastructure/scripts
./generate-inventory.sh
```

### 4. Deploy Kubernetes Cluster

```bash
# Navigate to configuration directory
cd configuration

# Test connectivity
ansible -i inventory.ini all -m ping

# Deploy Kubernetes cluster
ansible-playbook -i inventory.ini setup-k8s.yml
```

## 📁 Project Structure

```
homelab/
├── README.md                          # This file
├── infrastructure/                    # Infrastructure as Code
│   ├── main.tf                       # Main Terraform configuration
│   ├── variables.tf                  # Variable declarations
│   ├── terraform.example.tfvars      # Example configuration
│   ├── resources/k8s-cluster/        # Kubernetes cluster module
│   ├── scripts/                      # Infrastructure automation scripts
│   └── README.md                     # Infrastructure documentation
└── configuration/                     # Configuration management
    ├── setup-k8s.yml                # Kubernetes deployment playbook
    ├── inventory.ini                 # Ansible inventory (auto-generated)
    ├── ansible.cfg                   # Ansible configuration
    ├── vars.yml                      # Ansible variables
    └── README.md                     # Configuration documentation
```

## 🔧 Configuration

### Infrastructure Configuration

Edit `infrastructure/terraform.auto.tfvars`:

```hcl
# Proxmox API Configuration
pm_api_url          = "https://your-proxmox-server:8006/api2/json"
pm_api_token_id     = "your-user@pve!token-name"
pm_api_token_secret = "your-token-secret"

# VM Infrastructure
target_nodes   = ["node1", "node2"]
clone_template = "debian12-cloud"
storage        = "local-lvm"
network_bridge = "vmbr0"

# Network Configuration
ip_prefix = "192.168.2"
ip_start  = 150
gateway   = "192.168.2.1"

# SSH and Cloud-init
ciuser     = "debian"
cipassword = "your-secure-password"
ssh_keys   = "ssh-rsa AAAAB3NzaC1yc2E..."

# Cluster Configuration
vms = {
  master = {
    count       = 3
    cores       = 2
    memory      = 4096
    disk_size   = "50G"
    name_prefix = "k8s-master"
  }
  worker = {
    count       = 3
    cores       = 4
    memory      = 8192
    disk_size   = "100G"
    name_prefix = "k8s-worker"
  }
}
```

### Kubernetes Configuration

The Ansible playbook supports various customizations through `configuration/vars.yml`:

- Kubernetes version
- Pod network CIDR
- Control plane endpoint
- Additional Kubernetes components

## 📖 Detailed Documentation

- **[Infrastructure Setup](infrastructure/README.md)**: Detailed OpenTofu/Terraform configuration and deployment
- **[Configuration Management](configuration/README.md)**: Ansible playbook usage and Kubernetes deployment
- **[Infrastructure Scripts](infrastructure/scripts/README.md)**: Automation scripts and utilities

## 🔄 Workflow

### Initial Deployment

1. **Prepare Proxmox Environment**
   - Set up Proxmox VE cluster
   - Create cloud-init template
   - Configure networking

2. **Deploy Infrastructure**
   - Configure `terraform.auto.tfvars`
   - Run `tofu apply` to create VMs

3. **Generate Inventory**
   - Run `generate-inventory.sh` script
   - Verify connectivity with Ansible

4. **Deploy Kubernetes**
   - Run `setup-k8s.yml` playbook
   - Verify cluster deployment

### Scaling Operations

#### Adding Nodes

1. Update VM counts in `terraform.auto.tfvars`
2. Apply infrastructure changes: `tofu apply`
3. Regenerate inventory: `./scripts/generate-inventory.sh`
4. Run Ansible playbook: `ansible-playbook -i inventory.ini setup-k8s.yml`

#### Removing Nodes

1. Update VM counts in `terraform.auto.tfvars`
2. Apply infrastructure changes: `tofu apply`
3. Regenerate inventory: `./scripts/generate-inventory.sh`

### Maintenance

- **Updates**: Run the Ansible playbook periodically for system updates
- **Backup**: Back up Terraform state and Kubernetes cluster data
- **Monitoring**: Implement cluster monitoring and alerting

## 🛠️ Troubleshooting

### Common Issues

1. **Proxmox API Connection**
   - Verify API URL and credentials
   - Check network connectivity
   - Ensure API token has sufficient privileges

2. **VM Creation Failures**
   - Verify template exists and is accessible
   - Check storage availability
   - Ensure VM IDs don't conflict

3. **Ansible Connection Issues**
   - Verify SSH key configuration
   - Check VM network configuration
   - Ensure cloud-init completed successfully

4. **Kubernetes Deployment Failures**
   - Check system requirements (swap disabled, kernel modules)
   - Verify network connectivity between nodes
   - Review container runtime configuration

### Getting Help

- Check individual README files for component-specific troubleshooting
- Review Ansible playbook output for specific error messages
- Verify Proxmox logs for VM-related issues

## 🔐 Security Considerations

- **Credentials**: Never commit `terraform.auto.tfvars` with real credentials
- **SSH Keys**: Use strong SSH key pairs and rotate regularly
- **Network Security**: Configure firewalls and network segmentation
- **API Security**: Use dedicated API tokens with minimal required privileges
- **Backup Security**: Encrypt and secure backup storage

## 🏷️ Versioning

This project uses semantic versioning. Check individual component versions:

- **Kubernetes**: v1.30 (configurable)
- **OpenTofu**: v1.6+
- **Ansible**: v2.14+

---

For detailed setup instructions, see the component-specific README files:
- [Infrastructure Setup Guide](infrastructure/README.md)
- [Kubernetes Configuration Guide](configuration/README.md)
- [Infrastructure Scripts Guide](infrastructure/scripts/README.md) 