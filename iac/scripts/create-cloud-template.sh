#!/bin/bash

# Proxmox Cloud Template Creation Script
# Creates a cloud-init template for Proxmox VE
# Supports Debian 12 and Ubuntu 24.04 (Noble) images
# 
# Required environment variables:
# - VM_ID: The VM ID to use for the template
# - ST_VOL: Storage volume name (e.g., 'local-lvm')
# - PUB_SSHKEY: Path to public SSH key file
# - SOME_PASSWORD: Password for the default user
#
# Optional environment variables with defaults:
# - CLOUD_IMAGE_TYPE: Image type - 'debian' or 'ubuntu' (default: 'debian')
# - VM_MEMORY: Memory in MB (default: 2048)
# - VM_CORES: Number of CPU cores (default: 4)
# - VM_DISK_SIZE: Disk size in GB (default: 30)

set -euo pipefail  # Exit on error, undefined vars, and pipe failures

# Configuration variables with defaults
CLOUD_IMAGE_TYPE=${CLOUD_IMAGE_TYPE:-debian}  # Image type: debian or ubuntu
VM_MEMORY=${VM_MEMORY:-2048}                  # Memory in MB
VM_CORES=${VM_CORES:-4}                       # CPU cores
VM_DISK_SIZE=${VM_DISK_SIZE:-30}              # Disk size in GB

# Cloud image configurations
declare -A IMAGE_CONFIGS
IMAGE_CONFIGS[debian_url]="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"
IMAGE_CONFIGS[debian_filename]="debian-12-generic-amd64.qcow2"
IMAGE_CONFIGS[debian_name]="debian12-cloud"
IMAGE_CONFIGS[debian_display]="Debian 12"
IMAGE_CONFIGS[debian_format]="qcow2"

IMAGE_CONFIGS[ubuntu_url]="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
IMAGE_CONFIGS[ubuntu_filename]="noble-server-cloudimg-amd64.img"
IMAGE_CONFIGS[ubuntu_name]="ubuntu24-cloud"
IMAGE_CONFIGS[ubuntu_display]="Ubuntu 24.04 (Noble)"
IMAGE_CONFIGS[ubuntu_format]="qcow2"

# Set current image configuration based on type
IMAGE_URL="${IMAGE_CONFIGS[${CLOUD_IMAGE_TYPE}_url]}"
IMAGE_FILENAME="${IMAGE_CONFIGS[${CLOUD_IMAGE_TYPE}_filename]}"
VM_NAME="${IMAGE_CONFIGS[${CLOUD_IMAGE_TYPE}_name]}"
IMAGE_DISPLAY="${IMAGE_CONFIGS[${CLOUD_IMAGE_TYPE}_display]}"
IMAGE_FORMAT="${IMAGE_CONFIGS[${CLOUD_IMAGE_TYPE}_format]}"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Validate required environment variables
validate_env() {
    local missing_vars=()
    
    [[ -z "${VM_ID:-}" ]] && missing_vars+=("VM_ID")
    [[ -z "${ST_VOL:-}" ]] && missing_vars+=("ST_VOL")
    [[ -z "${PUB_SSHKEY:-}" ]] && missing_vars+=("PUB_SSHKEY")
    [[ -z "${SOME_PASSWORD:-}" ]] && missing_vars+=("SOME_PASSWORD")
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log_error "Missing required environment variables: ${missing_vars[*]}"
        log_error "Please set these variables before running the script"
        exit 1
    fi
    
    # Validate cloud image type
    if [[ "$CLOUD_IMAGE_TYPE" != "debian" && "$CLOUD_IMAGE_TYPE" != "ubuntu" ]]; then
        log_error "Invalid CLOUD_IMAGE_TYPE: $CLOUD_IMAGE_TYPE. Must be 'debian' or 'ubuntu'"
        exit 1
    fi
    
    # Validate SSH key file exists
    if [[ ! -f "$PUB_SSHKEY" ]]; then
        log_error "SSH public key file not found: $PUB_SSHKEY"
        exit 1
    fi
}

# Cleanup function
cleanup() {
    log_info "Cleaning up temporary files..."
    if [[ -f "$IMAGE_FILENAME" ]]; then
        rm -f "$IMAGE_FILENAME"
        log_info "Removed downloaded image file"
    fi
}

# Set up trap for cleanup on exit
trap cleanup EXIT

# Main script execution
main() {
    log_info "Starting Proxmox cloud template creation process..."
    log_info "Image type: $IMAGE_DISPLAY"
    
    # Validate environment
    validate_env
    
    # Change to home directory
    cd ~
    
    # Destroy existing VM if it exists
    log_info "Destroying existing VM $VM_ID if it exists..."
    if qm status "$VM_ID" &>/dev/null; then
        qm destroy "$VM_ID" || log_warn "Failed to destroy VM $VM_ID (may not exist)"
    fi
    
    # Download latest cloud image
    log_info "Downloading latest $IMAGE_DISPLAY cloud image..."
    if [[ -f "$IMAGE_FILENAME" ]]; then
        log_warn "Image file already exists, removing old version..."
        rm -f "$IMAGE_FILENAME"
    fi
    
    wget -q --show-progress \
        "$IMAGE_URL" \
        -O "$IMAGE_FILENAME"
    
    # Customize the image
    log_info "Customizing cloud image..."
    virt-customize -a "$IMAGE_FILENAME" \
        --install qemu-guest-agent \
        --truncate /etc/machine-id \
        --timezone "Europe/Amsterdam" \
        --append-line '/etc/sysctl.d/99-k8s-cni.conf:' \
        --append-line '/etc/sysctl.d/99-k8s-cni.conf:net.bridge.bridge-nf-call-iptables=1' \
        --append-line '/etc/sysctl.d/99-k8s-cni.conf:net.bridge.bridge-nf-call-ip6tables=1'
    
    # Create VM
    log_info "Creating VM $VM_ID with ${VM_MEMORY}MB RAM and ${VM_CORES} cores..."
    qm create "$VM_ID" \
        --name "$VM_NAME" \
        --cpu host \
        --machine q35 \
        --memory "$VM_MEMORY" \
        --cores "$VM_CORES" \
        --numa 1 \
        --net0 virtio,bridge=vmbr0 \
        --agent enabled=1,fstrim_cloned_disks=1,type=virtio
    
    # Import disk
    log_info "Importing disk to Proxmox storage..."
    qm importdisk "$VM_ID" "$IMAGE_FILENAME" "$ST_VOL" -format "$IMAGE_FORMAT"
    
    # Configure storage and boot
    log_info "Configuring VM storage and boot options..."
    qm set "$VM_ID" \
        --scsihw virtio-scsi-pci \
        --scsi0 "$ST_VOL:vm-$VM_ID-disk-0" \
        --ide2 "$ST_VOL:cloudinit" \
        --boot c \
        --bootdisk scsi0 \
        --serial0 socket \
        --vga serial0
    
    # Resize disk
    # Calculate resize amount (subtract 2GB base size from target size)
    local resize_amount=$((VM_DISK_SIZE - 2))
    log_info "Resizing disk to ${VM_DISK_SIZE}GB..."
    qm resize "$VM_ID" scsi0 "+${resize_amount}G"
    
    # Configure network
    log_info "Configuring network (DHCP)..."
    qm set "$VM_ID" --ipconfig0 ip=dhcp
    
    # Set SSH key
    log_info "Setting SSH public key..."
    qm set "$VM_ID" --sshkey "$PUB_SSHKEY"
    
    # Set password
    log_info "Setting cloud-init password..."
    qm set "$VM_ID" --cipassword "$SOME_PASSWORD"
    
    # Dump cloud-init configuration for verification
    log_info "Dumping cloud-init user configuration..."
    qm cloudinit dump "$VM_ID" user
    
    # Convert to template
    log_info "Converting VM to template..."
    qm template "$VM_ID"
    
    log_info "Template creation completed successfully!"
    log_info "Template ID: $VM_ID"
    log_info "Template Name: $VM_NAME"
    log_info "Image Type: $IMAGE_DISPLAY"
    log_info "Configuration: ${VM_MEMORY}MB RAM, ${VM_CORES} cores, ${VM_DISK_SIZE}GB disk"
}

# Run main function
main "$@"