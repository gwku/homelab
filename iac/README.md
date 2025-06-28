# Kubernetes Cluster Infrastructure

This OpenTofu configuration creates a Kubernetes cluster on Proxmox VE using cloud-init enabled VMs.

## Setup

1. **Copy the example configuration file:**
   ```bash
   cp terraform.example.tfvars terraform.tfvars
   ```

2. **Edit `terraform.tfvars` with your actual values:**
   - Update Proxmox API credentials
   - Set your SSH public key
   - Adjust VM specifications as needed

3. **Initialize OpenTofu:**
   ```bash
   tofu init
   ```

4. **Plan and apply:**
   ```bash
   tofu plan
   tofu apply
   ```

## Configuration Files

- `terraform.example.tfvars` - Example/default values (committed to git)
- `terraform.tfvars` - Your actual values (excluded from git)
- `variables.tf` - Variable declarations

## VM Configuration

The cluster consists of:
- **Master nodes**: Control plane nodes (default: 2 nodes, 4 cores, 4GB RAM)
- **Worker nodes**: Application workload nodes (default: 3 nodes, 2 cores, 2GB RAM)

You can customize the VM configuration by modifying the `vms` variable in your `terraform.tfvars` file.

## Security

- Never commit `terraform.tfvars` containing real credentials
- Use strong passwords for API access and cloud-init user
- Rotate SSH keys regularly
- Keep OpenTofu state files secure 