# Infrastructure Scripts

## generate-inventory.sh

This script generates an Ansible inventory file from the current OpenTofu/Terraform state.

### Prerequisites

- OpenTofu (tofu) command must be available
- jq command must be installed for JSON parsing
- Terraform state must exist (run `tofu apply` first)

### Usage

```bash
# Generate inventory with default output location (../configuration/inventory.ini)
./generate-inventory.sh

# Generate inventory with custom output location
./generate-inventory.sh /path/to/custom/inventory.ini
```

### What it does

1. Reads the current OpenTofu state using `tofu show -json`
2. Extracts VM information for nodes tagged as "master" and "worker"
3. Generates an Ansible inventory file with:
   - `[masters]` section with master nodes and their IP addresses
   - `[workers]` section with worker nodes and their IP addresses
   - `[all:vars]` section with common variables like ansible_user and SSH key path

### Output Format

The generated inventory follows this format:

```ini
[masters]
k8s-master-1 ansible_host=192.168.2.150
k8s-master-2 ansible_host=192.168.2.151
k8s-master-3 ansible_host=192.168.2.152

[workers]
k8s-worker-1 ansible_host=192.168.2.153
k8s-worker-2 ansible_host=192.168.2.154
k8s-worker-3 ansible_host=192.168.2.155

[all:vars]
ansible_user=debian
ansible_ssh_private_key_file=/Users/gerwin/.ssh/id_rsa
```

### Using the Generated Inventory

After generating the inventory, you can use it with Ansible:

```bash
# Test connectivity to all nodes
ansible -i ../configuration/inventory.ini all -m ping

# Run a playbook
ansible-playbook -i ../configuration/inventory.ini ../configuration/setup-k8s.yml
``` 