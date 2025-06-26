#!/bin/bash

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRASTRUCTURE_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$INFRASTRUCTURE_DIR")"
CONFIGURATION_DIR="$PROJECT_ROOT/configuration"

echo -e "${BLUE}=== Kubernetes Cluster Deployment Script ===${NC}"
echo "Infrastructure directory: $INFRASTRUCTURE_DIR"
echo "Configuration directory: $CONFIGURATION_DIR"
echo ""

# Function to print colored output
print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Step 1: Apply Tofu infrastructure
print_step "Applying Tofu infrastructure..."
cd "$INFRASTRUCTURE_DIR"

if ! command -v tofu &> /dev/null; then
    print_error "Tofu is not installed or not in PATH"
    exit 1
fi

# Initialize if needed
if [ ! -d ".terraform" ]; then
    print_step "Initializing Tofu..."
    tofu init
fi

# Plan and apply
print_step "Planning Tofu changes..."
tofu plan -out=tfplan

print_step "Applying Tofu changes..."
tofu apply tfplan

# Clean up plan file
rm -f tfplan

print_success "Infrastructure deployment completed"
echo ""

# Step 2: Generate Ansible inventory
print_step "Generating Ansible inventory..."
cd "$INFRASTRUCTURE_DIR"

if [ ! -f "scripts/generate-inventory.sh" ]; then
    print_error "generate-inventory.sh script not found"
    exit 1
fi

# Make sure script is executable
chmod +x scripts/generate-inventory.sh

# Generate inventory
./scripts/generate-inventory.sh

if [ ! -f "$CONFIGURATION_DIR/inventory.ini" ]; then
    print_error "Inventory file was not generated successfully"
    exit 1
fi

print_success "Inventory generated successfully"
echo ""

# Step 3: Wait for VMs to be ready
print_step "Waiting for VMs to be accessible..."
cd "$CONFIGURATION_DIR"

# Test connectivity to all hosts
max_attempts=30
attempt=0

while [ $attempt -lt $max_attempts ]; do
    if ansible -i inventory.ini all -m ping --ssh-common-args='-o ConnectTimeout=10 -o StrictHostKeyChecking=no' > /dev/null 2>&1; then
        print_success "All hosts are accessible"
        break
    else
        attempt=$((attempt + 1))
        print_warning "Attempt $attempt/$max_attempts: Waiting for hosts to be ready..."
        sleep 10
    fi
done

if [ $attempt -eq $max_attempts ]; then
    print_error "Timeout waiting for hosts to become accessible"
    print_warning "You can check connectivity manually with: ansible -i inventory.ini all -m ping"
    exit 1
fi

echo ""

# Step 4: Run Ansible playbook
print_step "Running Kubernetes setup playbook..."
cd "$CONFIGURATION_DIR"

if [ ! -f "setup-k8s.yml" ]; then
    print_error "setup-k8s.yml playbook not found in $CONFIGURATION_DIR"
    exit 1
fi

# Run the playbook
ansible-playbook -i inventory.ini setup-k8s.yml

print_success "Kubernetes cluster setup completed!"
echo ""

# Step 5: Display cluster information
print_step "Cluster deployment summary:"
echo -e "${GREEN}✓${NC} Infrastructure deployed with Tofu"
echo -e "${GREEN}✓${NC} Ansible inventory generated"
echo -e "${GREEN}✓${NC} Kubernetes cluster configured"
echo ""
echo "Next steps:"
echo "1. SSH to a master node: ssh -i ~/.ssh/id_rsa debian@<master-ip>"
echo "2. Check cluster status: kubectl get nodes"
echo "3. View cluster info: kubectl cluster-info"
echo ""
echo "Master nodes:"
grep "k8s-master" "$CONFIGURATION_DIR/inventory.ini" | while read -r line; do
    echo "  - $line"
done
echo ""
echo "Worker nodes:"
grep "k8s-worker" "$CONFIGURATION_DIR/inventory.ini" | while read -r line; do
    echo "  - $line"
done 