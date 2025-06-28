terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "3.0.2-rc01"
    }
  }
}

provider "proxmox" {
  pm_api_url          = var.pm_api_url
  pm_api_token_id     = var.pm_api_token_id
  pm_api_token_secret = var.pm_api_token_secret
  pm_tls_insecure     = var.pm_tls_insecure
}

locals {
  # Create a flattened list of VMs with global index for VM ID assignment
  vms_flat = flatten([
    for vm_type, config in var.vms : [
      for i in range(config.count) : {
        key         = "${vm_type}-${i + 1}"
        name        = "${config.name_prefix}-${i + 1}"
        cores       = config.cores
        sockets     = config.sockets
        memory      = config.memory
        disk_size   = config.disk_size
        vm_type     = vm_type
        ip_offset   = i
        node_index  = i % length(var.target_nodes)
        type_index  = i
      }
    ]
  ])
  
  # Create VM map with sequential VM IDs
  vms_with_ids = {
    for idx, vm in local.vms_flat : vm.key => merge(vm, {
      vm_id = var.vm_id_start + idx
    })
  }
}

resource "proxmox_vm_qemu" "k8s_nodes" {
  for_each = local.vms_with_ids

  vmid        = each.value.vm_id
  name        = each.value.name
  target_node = var.target_nodes[each.value.node_index]

  clone      = var.clone_template
  full_clone = true

  os_type = "cloud-init"
  agent   = 1

  cpu {
    cores   = each.value.cores
    sockets = each.value.sockets
    type    = "host"
  }
  
  memory   = each.value.memory
  scsihw   = "virtio-scsi-pci"
  bootdisk = "scsi0"

  disks {
    ide {
      ide2 {
        cloudinit {
          storage = var.storage
        }
      }
    }
    scsi {
      scsi0 {
        disk {
          size    = each.value.disk_size
          cache   = "writeback"
          storage = var.storage
        }
      }
    }
  }

  network {
    id     = 0
    model  = "virtio"
    bridge = var.network_bridge
  }

  serial {
    id   = 0
    type = "socket"
  }

  ipconfig0 = "ip=${var.ip_prefix}.${var.ip_start + each.value.type_index + (each.value.vm_type == "worker" ? var.vms.master.count : 0)}/24,gw=${var.gateway}"

  ciuser     = var.ciuser
  cipassword = var.cipassword
  sshkeys    = var.ssh_keys

  tags = each.value.vm_type

  
}