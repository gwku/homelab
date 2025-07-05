variable "pm_api_url" {
  description = "Proxmox API URL (e.g., https://your-proxmox-server:8006/api2/json)"
  type        = string
}

variable "pm_api_token_id" {
  description = "Proxmox API token ID (e.g., user@pve!token-name)"
  type        = string
}

variable "pm_api_token_secret" {
  description = "Proxmox API token secret"
  type        = string
  sensitive   = true
}

variable "pm_tls_insecure" {
  description = "Proxmox TLS insecure"
  type        = bool
}

variable "vm_id_start" {
  description = "Starting VM ID for incremental assignment (e.g., 100 will create VMs with IDs 100, 101, 102, etc.)"
  type        = number
}

# VM Configuration Variables
variable "target_nodes" {
  description = "List of Proxmox nodes to deploy VMs on (VMs will be distributed across these nodes)"
  type        = list(string)
}

variable "clone_template" {
  description = "Template to clone from"
  type        = string
}

variable "storage" {
  description = "Storage pool to use"
  type        = string
}

variable "network_bridge" {
  description = "Network bridge to use"
  type        = string
}

variable "ciuser" {
  description = "Cloud-init user"
  type        = string
}

variable "cipassword" {
  description = "Cloud-init password"
  type        = string
  sensitive   = true
}

variable "ssh_keys" {
  description = "SSH public keys for cloud-init"
  type        = string
}

variable "ssh_private_key" {
  description = "SSH private key content for provisioner connections"
  type        = string
  sensitive   = true
}

variable "ip_prefix" {
  description = "IP prefix for static IP assignment (e.g., '192.168.1')"
  type        = string
}

variable "ip_start" {
  description = "Starting IP address for node assignment"
  type        = number
  default     = 10
}

variable "gateway" {
  description = "Default gateway IP address"
  type        = string
}

# Modular VMs configuration
variable "vms" {
  description = "Configuration for Kubernetes cluster VMs"
  type = map(object({
    count       = number
    cores       = number
    sockets     = number
    memory      = number
    disk_size   = string
    name_prefix = string
  }))
}