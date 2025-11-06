terraform {
  required_version = ">= 1.5.0"

  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
  }
}

# Install k3s on local Ubuntu server
resource "null_resource" "install_k3s" {
  triggers = {
    k3s_version = var.k3s_version
    k3s_options = var.k3s_install_options
  }

  provisioner "local-exec" {
    command = <<-EOT
      #!/bin/bash
      set -e

      # Helper function to run commands with sudo if needed
      maybe_sudo() {
        if [ "$EUID" -eq 0 ]; then
          "$@"
        elif command -v sudo >/dev/null 2>&1; then
          sudo "$@"
        else
          "$@"
        fi
      }

      echo "Installing k3s version ${var.k3s_version}..."

      # Install k3s
      curl -sfL https://get.k3s.io | \
        INSTALL_K3S_VERSION="${var.k3s_version}" \
        INSTALL_K3S_EXEC="${var.k3s_install_options}" \
        sh -

      # Wait for k3s to be ready
      echo "Waiting for k3s to be ready..."
      timeout 120 bash -c 'until k3s kubectl get nodes 2>/dev/null | grep -q Ready; do sleep 2; done'

      # Configure kubectl for current user
      mkdir -p $HOME/.kube
      maybe_sudo cp /etc/rancher/k3s/k3s.yaml $HOME/.kube/config
      maybe_sudo chown $(id -u):$(id -g) $HOME/.kube/config
      chmod 600 $HOME/.kube/config

      # Update server address in kubeconfig
      sed -i 's/127.0.0.1/${var.server_ip}/g' $HOME/.kube/config

      echo "k3s installation completed successfully!"
    EOT

    interpreter = ["bash", "-c"]
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      #!/bin/bash
      # Helper function to run commands with sudo if needed
      maybe_sudo() {
        if [ "$EUID" -eq 0 ]; then
          "$@"
        elif command -v sudo >/dev/null 2>&1; then
          sudo "$@"
        else
          "$@"
        fi
      }

      echo "Uninstalling k3s..."
      if [ -f /usr/local/bin/k3s-uninstall.sh ]; then
        maybe_sudo /usr/local/bin/k3s-uninstall.sh
      fi
    EOT

    interpreter = ["bash", "-c"]
  }
}

# Wait for k3s cluster to be fully ready
resource "null_resource" "wait_for_cluster" {
  depends_on = [null_resource.install_k3s]

  provisioner "local-exec" {
    command = <<-EOT
      #!/bin/bash
      set -e

      echo "Verifying k3s cluster status..."

      # Wait for all system pods to be ready
      timeout 180 bash -c 'until [ $(kubectl get pods -n kube-system --no-headers | grep -v Running | grep -v Completed | wc -l) -eq 0 ]; do
        echo "Waiting for system pods to be ready..."
        sleep 5
      done'

      echo "k3s cluster is fully operational!"
      kubectl get nodes
      kubectl get pods -A
    EOT

    interpreter = ["bash", "-c"]
  }
}

# Save kubeconfig to file
resource "local_file" "kubeconfig" {
  depends_on = [null_resource.install_k3s]

  content = templatefile("${path.module}/templates/kubeconfig.tpl", {
    server_ip   = var.server_ip
    server_port = var.server_port
  })
  filename        = "${path.module}/kubeconfig"
  file_permission = "0600"

  provisioner "local-exec" {
    command = <<-EOT
      #!/bin/bash
      # Helper function to run commands with sudo if needed
      maybe_sudo() {
        if [ "$EUID" -eq 0 ]; then
          "$@"
        elif command -v sudo >/dev/null 2>&1; then
          sudo "$@"
        else
          "$@"
        fi
      }

      # Copy the actual k3s kubeconfig
      maybe_sudo cp /etc/rancher/k3s/k3s.yaml ${path.module}/kubeconfig.tmp
      maybe_sudo chown $(id -u):$(id -g) ${path.module}/kubeconfig.tmp

      # Update server address
      sed 's/127.0.0.1/${var.server_ip}/g' ${path.module}/kubeconfig.tmp > ${path.module}/kubeconfig
      rm ${path.module}/kubeconfig.tmp
      chmod 600 ${path.module}/kubeconfig
    EOT

    interpreter = ["bash", "-c"]
  }
}

# Create storage class if needed
resource "null_resource" "setup_storage" {
  depends_on = [null_resource.wait_for_cluster]

  count = var.setup_local_storage ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      #!/bin/bash
      set -e

      echo "Setting up local-path storage..."

      # k3s comes with local-path provisioner by default
      # Make it the default storage class
      kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

      kubectl get storageclass
    EOT

    interpreter = ["bash", "-c"]
  }
}

# Install metrics-server for HPA (if not included in k3s)
resource "null_resource" "install_metrics_server" {
  depends_on = [null_resource.wait_for_cluster]

  count = var.install_metrics_server ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      #!/bin/bash
      set -e

      echo "Installing metrics-server..."

      kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

      # Patch metrics-server for local deployment (disable TLS verification)
      kubectl patch deployment metrics-server -n kube-system --type='json' \
        -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]' || true

      # Wait for metrics-server to be ready
      kubectl wait --for=condition=ready pod -l k8s-app=metrics-server -n kube-system --timeout=120s || true

      echo "Metrics-server installed!"
    EOT

    interpreter = ["bash", "-c"]
  }
}

# Output cluster information
resource "null_resource" "cluster_info" {
  depends_on = [
    null_resource.wait_for_cluster,
    null_resource.setup_storage,
    null_resource.install_metrics_server
  ]

  provisioner "local-exec" {
    command = <<-EOT
      #!/bin/bash
      echo "=========================================="
      echo "k3s Cluster Information"
      echo "=========================================="
      echo ""
      echo "Cluster nodes:"
      kubectl get nodes -o wide
      echo ""
      echo "Cluster version:"
      kubectl version --short || kubectl version
      echo ""
      echo "Storage classes:"
      kubectl get storageclass
      echo ""
      echo "Kubeconfig location: ${path.module}/kubeconfig"
      echo ""
      echo "To use this cluster:"
      echo "export KUBECONFIG=${path.module}/kubeconfig"
      echo ""
      echo "=========================================="
    EOT

    interpreter = ["bash", "-c"]
  }
}
