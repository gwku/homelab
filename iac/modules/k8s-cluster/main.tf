locals {
  # Get VM configurations from variables (with sensible defaults only if not configured)
  master_config = lookup(var.vms, "master", {
    count       = 0
    cores       = 2
    sockets     = 1
    memory      = 4096
    disk_size   = "50G"
    name_prefix = "k8s-master"
  })
  
  worker_config = lookup(var.vms, "worker", {
    count       = 0
    cores       = 4
    sockets     = 1
    memory      = 8192
    disk_size   = "100G"
    name_prefix = "k8s-worker"
  })
  
  # Generate IP addresses
  master_ips = [
    for i in range(local.master_config.count) :
    "${var.ip_prefix}.${var.ip_start + i}"
  ]
  
  worker_ips = [
    for i in range(local.worker_config.count) :
    "${var.ip_prefix}.${var.ip_start + local.master_config.count + i}"
  ]
  
  # All node IPs and hostnames
  all_nodes = concat(
    [
      for i in range(local.master_config.count) : {
        ip       = local.master_ips[i]
        hostname = "${local.master_config.name_prefix}-${i + 1}"
        type     = "master"
        index    = i
      }
    ],
    [
      for i in range(local.worker_config.count) : {
        ip       = local.worker_ips[i]
        hostname = "${local.worker_config.name_prefix}-${i + 1}"
        type     = "worker"
        index    = i
      }
    ]
  )

  # Create flattened VM list for resource creation
  vms_flat = [
    for node in local.all_nodes : {
      key         = "${node.type}-${node.index + 1}"
      name        = node.hostname
      ip          = node.ip
      vm_type     = node.type
      type_index  = node.index
      node_index  = node.index % length(var.target_nodes)
      cores       = node.type == "master" ? local.master_config.cores : local.worker_config.cores
      sockets     = node.type == "master" ? local.master_config.sockets : local.worker_config.sockets
      memory      = node.type == "master" ? local.master_config.memory : local.worker_config.memory
      disk_size   = node.type == "master" ? local.master_config.disk_size : local.worker_config.disk_size
    }
  ]
  
  # Create VM map with sequential VM IDs
  vms_with_ids = {
    for idx, vm in local.vms_flat : vm.key => merge(vm, {
      vm_id = var.vm_id_start + idx
    })
  }

  # Generate /etc/hosts entries
  hosts_entries = join("\n", [
    for node in local.all_nodes :
    "${node.ip} ${node.hostname}"
  ])
  
  # Helper to get node IP by key
  node_ip_map = {
    for vm in local.vms_flat : vm.key => vm.ip
  }
  
  # First master IP for cluster setup
  first_master_ip = length(local.master_ips) > 0 ? local.master_ips[0] : null
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

  ipconfig0 = "ip=${each.value.ip}/24,gw=${var.gateway}"

  ciuser     = var.ciuser
  cipassword = var.cipassword
  sshkeys    = var.ssh_keys

  tags = each.value.vm_type

  # Wait for the VM to be ready
  connection {
    type        = "ssh"
    user        = var.ciuser
    private_key = var.ssh_private_key
    host        = each.value.ip
    timeout     = "5m"
  }

  provisioner "remote-exec" {
    inline = [
      "cloud-init status --wait",
      "sudo apt-get update",
      "sudo apt-get install -y curl"
    ]
  }
}

# Generate k3s token
resource "random_password" "k3s_token" {
  length  = 32
  special = false
}

# Configure /etc/hosts on all nodes
resource "null_resource" "configure_hosts" {
  depends_on = [proxmox_vm_qemu.k8s_nodes]
  
  for_each = local.vms_with_ids

  connection {
    type        = "ssh"
    user        = var.ciuser
    private_key = var.ssh_private_key
    host        = each.value.ip
    timeout     = "5m"
  }

  provisioner "remote-exec" {
    inline = [
      "echo '# k3s cluster nodes' | sudo tee -a /etc/hosts",
      "echo '${local.hosts_entries}' | sudo tee -a /etc/hosts"
    ]
  }
}

# Install k3s on the first master node
resource "null_resource" "k3s_first_master" {
  depends_on = [
    proxmox_vm_qemu.k8s_nodes,
    null_resource.configure_hosts
  ]
  
  count = local.first_master_ip != null ? 1 : 0

  connection {
    type        = "ssh"
    user        = var.ciuser
    private_key = var.ssh_private_key
    host        = local.first_master_ip
    timeout     = "5m"
  }

  provisioner "remote-exec" {
    inline = [
      "curl -sfL https://get.k3s.io | sh -s - server --cluster-init --token=${random_password.k3s_token.result} --node-external-ip=${local.first_master_ip} --flannel-iface=eth0",
      "sudo systemctl enable k3s",
      "sudo systemctl start k3s",
      "sleep 30"
    ]
  }
}

# Install k3s on additional master nodes
resource "null_resource" "k3s_additional_masters" {
  depends_on = [
    null_resource.k3s_first_master,
    null_resource.configure_hosts
  ]
  
  count = length(local.master_ips) > 1 ? length(local.master_ips) - 1 : 0

  connection {
    type        = "ssh"
    user        = var.ciuser
    private_key = var.ssh_private_key
    host        = local.master_ips[count.index + 1]
    timeout     = "5m"
  }

  provisioner "remote-exec" {
    inline = [
      "curl -sfL https://get.k3s.io | sh -s - server --server https://${local.first_master_ip}:6443 --token=${random_password.k3s_token.result} --node-external-ip=${local.master_ips[count.index + 1]} --flannel-iface=eth0",
      "sudo systemctl enable k3s",
      "sudo systemctl start k3s",
      "sleep 15"
    ]
  }
}

# Install k3s on worker nodes
resource "null_resource" "k3s_workers" {
  depends_on = [
    null_resource.k3s_first_master,
    null_resource.k3s_additional_masters,
    null_resource.configure_hosts
  ]
  
  count = length(local.worker_ips)

  connection {
    type        = "ssh"
    user        = var.ciuser
    private_key = var.ssh_private_key
    host        = local.worker_ips[count.index]
    timeout     = "5m"
  }

  provisioner "remote-exec" {
    inline = [
      "curl -sfL https://get.k3s.io | K3S_URL=https://${local.first_master_ip}:6443 K3S_TOKEN=${random_password.k3s_token.result} sh -s - --node-external-ip=${local.worker_ips[count.index]} --flannel-iface=eth0",
      "sudo systemctl enable k3s-agent",
      "sudo systemctl start k3s-agent"
    ]
  }
}

# Get kubeconfig from the first master
resource "null_resource" "get_kubeconfig" {
  depends_on = [
    null_resource.k3s_first_master,
    null_resource.k3s_additional_masters,
    null_resource.k3s_workers
  ]
  
  count = local.first_master_ip != null ? 1 : 0

  # Set up kubeconfig on the remote server
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = var.ciuser
      private_key = var.ssh_private_key
      host        = local.first_master_ip
      timeout     = "5m"
    }
    
    inline = [
      "mkdir -p ~/.kube",
      "sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config && sudo chown $USER ~/.kube/config && chmod 600 ~/.kube/config",
      "echo 'export KUBECONFIG=~/.kube/config' >> ~/.bashrc"
    ]
  }

  # Copy the kubeconfig locally and fix the server address
  provisioner "local-exec" {
    command = <<-EOT
      # Create temporary private key file
      temp_key=$(mktemp)
      echo '${var.ssh_private_key}' > "$temp_key"
      chmod 600 "$temp_key"
      
      # Get kubeconfig
      mkdir -p ~/.kube
      scp -o StrictHostKeyChecking=no -i "$temp_key" ${var.ciuser}@${local.first_master_ip}:~/.kube/config ~/.kube/config
      
      # Update server IP - replace both localhost and 127.0.0.1 with actual master IP
      sed -i 's/127.0.0.1:6443/${local.first_master_ip}:6443/g' ~/.kube/config
      sed -i 's/localhost:6443/${local.first_master_ip}:6443/g' ~/.kube/config
      sed -i 's/localhost:8080/${local.first_master_ip}:6443/g' ~/.kube/config
      
      # Clean up temporary key
      rm "$temp_key"
    EOT
  }
}

# Outputs
output "master_ips" {
  description = "IP addresses of the master nodes"
  value       = local.master_ips
}

output "worker_ips" {
  description = "IP addresses of the worker nodes"
  value       = local.worker_ips
}

output "k3s_token" {
  description = "k3s cluster token (sensitive)"
  value       = random_password.k3s_token.result
  sensitive   = true
}

output "kubeconfig_command" {
  description = "Command to get the kubeconfig file"
  value       = "# Manual kubeconfig retrieval (if needed):\n# 1. Save your private key to a temporary file\n# 2. SSH to master: ssh -i /path/to/private/key ${var.ciuser}@${local.first_master_ip}\n# 3. Set up kubeconfig: mkdir -p ~/.kube && sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config && sudo chown $USER ~/.kube/config && chmod 600 ~/.kube/config\n# 4. Add to bashrc: echo 'export KUBECONFIG=~/.kube/config' >> ~/.bashrc\n# 5. Exit SSH and run: scp -i /path/to/private/key ${var.ciuser}@${local.first_master_ip}:~/.kube/config ~/.kube/config\n# 6. Update server IP: sed -i 's/127.0.0.1:6443/${local.first_master_ip}:6443/g' ~/.kube/config\n# \n# Note: The kubeconfig should be automatically retrieved during terraform apply."
}

output "cluster_endpoint" {
  description = "k3s cluster endpoint"
  value       = local.first_master_ip != null ? "https://${local.first_master_ip}:6443" : null
}

output "hosts_configuration" {
  description = "Hosts entries configured on all nodes"
  value       = local.hosts_entries
}