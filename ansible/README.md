# Kubernetes Cluster Configuration

This directory contains Ansible playbooks and inventory for setting up a Kubernetes cluster.

## Files

- `inventory.ini` - Ansible inventory file (auto-generated from terraform state)
- `setup-k8s.yml` - Main playbook for setting up Kubernetes cluster
- `ansible.cfg` - Ansible configuration

## Dynamic Cluster Setup

The `setup-k8s.yml` playbook is fully dynamic and will work with any number of master and worker nodes defined in your inventory. No hardcoded hostnames!

### Key Features

- **Dynamic node discovery**: Automatically detects all masters and workers from inventory groups
- **Flexible master count**: Works with 1, 3, 5, or any number of master nodes
- **Scalable workers**: Add or remove worker nodes without changing the playbook
- **Auto-generated /etc/hosts**: Dynamically creates host entries for all cluster nodes

### Inventory Requirements

Your inventory must have two groups:

```ini
[masters]
k8s-master-1 ansible_host=192.168.2.150
k8s-master-2 ansible_host=192.168.2.151
k8s-master-3 ansible_host=192.168.2.152

[workers]
k8s-worker-1 ansible_host=192.168.2.153
k8s-worker-2 ansible_host=192.168.2.154

[all:vars]
ansible_user=debian
ansible_ssh_private_key_file=/Users/gerwin/.ssh/id_rsa
```

### How It Works

1. **Primary Master**: Always uses `masters[0]` (first master in the list)
2. **Additional Masters**: Uses `masters[1:]` (all masters except the first)
3. **Workers**: Uses the entire `workers` group
4. **Control Plane Endpoint**: Defaults to the primary master (can be customized)

### Customization Options

#### Single Master Setup
If you only have one master, the playbook will automatically skip the "Join additional masters" step.

#### Load Balancer Setup
To use a load balancer for the control plane endpoint, modify the `cluster_endpoint` variable:

```yaml
vars:
  cluster_endpoint: "k8s-api.example.com"  # Your load balancer FQDN
```

#### Different Kubernetes Version
Change the version in the playbook vars:

```yaml
vars:
  kubernetes_version: "1.29"  # or any supported version
```

#### Different Pod Network CIDR
Modify the pod network:

```yaml
vars:
  pod_network_cidr: "172.16.0.0/16"  # or your preferred range
```

## Usage

### Generate Inventory
First, generate the inventory from your terraform state:

```bash
cd ../infrastructure
./scripts/generate-inventory.sh
```

### Run the Playbook
```bash
# Test connectivity
ansible -i inventory.ini all -m ping

# Deploy the cluster
ansible-playbook -i inventory.ini setup-k8s.yml
```

### Adding Nodes

To add more nodes:

1. Update your terraform configuration
2. Run `tofu apply`
3. Regenerate inventory: `../infrastructure/scripts/generate-inventory.sh`
4. Run the playbook again: `ansible-playbook -i inventory.ini setup-k8s.yml`

The playbook is idempotent, so existing nodes won't be affected, and only new nodes will be configured.

### Removing Nodes

1. Remove nodes from terraform configuration
2. Run `tofu apply`
3. Regenerate inventory: `../infrastructure/scripts/generate-inventory.sh`
4. (Optional) Run the playbook to update /etc/hosts on remaining nodes

## Troubleshooting

### Common Issues

1. **"undefined variable" errors**: Ensure your inventory has `masters` and `workers` groups
2. **Join failures**: Check that the primary master is accessible and kubeadm init completed
3. **Network issues**: Verify that all nodes can reach each other on the specified IPs

### Verify Cluster Status

After deployment, check cluster status from the primary master:

```bash
# SSH to primary master
ssh debian@<primary-master-ip>

# Check cluster status
kubectl get nodes
kubectl get pods --all-namespaces
``` 