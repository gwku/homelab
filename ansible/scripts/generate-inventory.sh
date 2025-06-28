#!/bin/bash

# Script to generate Ansible inventory from tofu/terraform state
# Usage: ./generate-inventory.sh [output_file]

set -e

# Default paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$ANSIBLE_DIR")"
IAC_DIR="$PROJECT_ROOT/iac"
CONFIG_DIR="$PROJECT_ROOT/ansible"
DEFAULT_OUTPUT_FILE="$CONFIG_DIR/inventory.ini"

# Allow custom output file as argument
OUTPUT_FILE="${1:-$DEFAULT_OUTPUT_FILE}"

# SSH key path - will extract from existing inventory or use default
SSH_KEY_PATH="$HOME/.ssh/id_rsa"

echo "Generating Ansible inventory from tofu state..."
echo "Infrastructure directory: $IAC_DIR"
echo "Output file: $OUTPUT_FILE"

# Change to infrastructure directory
cd "$IAC_DIR"

# Check if tofu is available and state exists
if ! command -v tofu &> /dev/null; then
    echo "Error: tofu command not found. Please install OpenTofu."
    exit 1
fi

if [ ! -f "terraform.tfstate" ]; then
    echo "Error: No terraform state found in $IAC_DIR. Please run 'tofu apply' first."
    exit 1
fi

# Get terraform state as JSON
echo "Extracting VM information from tofu state..."
JSON_OUTPUT=$(tofu show -json)

# Extract VM information using jq
if ! command -v jq &> /dev/null; then
    echo "Error: jq command not found. Please install jq for JSON parsing."
    exit 1
fi

# Extract master nodes
echo "Extracting master nodes..."
MASTERS=$(echo "$JSON_OUTPUT" | jq -r '
  .values.root_module.child_modules[].resources[] | 
  select(.type == "proxmox_vm_qemu" and .values.tags == "master") |
  "\(.values.name) ansible_host=\(.values.default_ipv4_address)"
' | sort)

# Extract worker nodes  
echo "Extracting worker nodes..."
WORKERS=$(echo "$JSON_OUTPUT" | jq -r '
  .values.root_module.child_modules[].resources[] |
  select(.type == "proxmox_vm_qemu" and .values.tags == "worker") |
  "\(.values.name) ansible_host=\(.values.default_ipv4_address)"
' | sort)

# Extract ansible user from terraform state
echo "Extracting ansible user..."
ANSIBLE_USER=$(echo "$JSON_OUTPUT" | jq -r '
  .values.root_module.child_modules[].resources[] |
  select(.type == "proxmox_vm_qemu") |
  .values.ciuser
' | head -n1)

# Check if we found any nodes
if [ -z "$MASTERS" ] && [ -z "$WORKERS" ]; then
    echo "Error: No master or worker nodes found in terraform state."
    exit 1
fi

# Extract SSH key path from existing inventory if it exists
if [ -f "$OUTPUT_FILE" ]; then
    EXISTING_SSH_KEY=$(grep "ansible_ssh_private_key_file" "$OUTPUT_FILE" 2>/dev/null | sed 's/.*ansible_ssh_private_key_file=//' || true)
    if [ -n "$EXISTING_SSH_KEY" ]; then
        SSH_KEY_PATH="$EXISTING_SSH_KEY"
        echo "Using existing SSH key path: $SSH_KEY_PATH"
    fi
fi

# Create output directory if it doesn't exist
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Generate inventory file
echo "Writing inventory to: $OUTPUT_FILE"
cat > "$OUTPUT_FILE" << EOF
[masters]
$MASTERS

[workers]
$WORKERS

[all:vars]
ansible_user=$ANSIBLE_USER
ansible_ssh_private_key_file=$SSH_KEY_PATH
EOF

echo ""
echo "Inventory file generated successfully!"
echo ""
echo "Summary:"
echo "- Masters: $(echo "$MASTERS" | wc -l | tr -d ' ')"
echo "- Workers: $(echo "$WORKERS" | wc -l | tr -d ' ')"
echo "- Ansible user: $ANSIBLE_USER"
echo "- SSH key: $SSH_KEY_PATH"
echo ""
echo "Inventory contents:"
echo "==================="
cat "$OUTPUT_FILE"
echo "==================="
echo ""
echo "You can now run ansible commands using this inventory:"
echo "  ansible -i $OUTPUT_FILE all -m ping"
echo "  ansible-playbook -i $OUTPUT_FILE your-playbook.yml" 