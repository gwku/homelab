terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "3.0.2-rc01"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
} 