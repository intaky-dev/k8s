# Jenkins CI/CD Configuration
# This module deploys Jenkins with Kubernetes agents, Docker support, and CI/CD plugins

# Create Jenkins namespace
resource "null_resource" "create_jenkins_namespace" {
  depends_on = [null_resource.wait_for_cluster]

  provisioner "local-exec" {
    command = <<-EOT
      #!/bin/bash
      set -e

      echo "Creating jenkins namespace..."
      kubectl create namespace jenkins --dry-run=client -o yaml | kubectl apply -f -

      echo "✓ Jenkins namespace created"
    EOT

    interpreter = ["bash", "-c"]
  }
}

# Install Helm if not already installed
resource "null_resource" "install_helm" {
  depends_on = [null_resource.wait_for_cluster]

  provisioner "local-exec" {
    command = <<-EOT
      #!/bin/bash
      set -e

      # Check if helm is installed
      if ! command -v helm &> /dev/null; then
        echo "Installing Helm..."
        curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
      else
        echo "✓ Helm is already installed"
        helm version
      fi
    EOT

    interpreter = ["bash", "-c"]
  }
}

# Add Jenkins Helm repository
resource "null_resource" "add_jenkins_helm_repo" {
  depends_on = [null_resource.install_helm]

  provisioner "local-exec" {
    command = <<-EOT
      #!/bin/bash
      set -e

      echo "Adding Jenkins Helm repository..."
      helm repo add jenkins https://charts.jenkins.io
      helm repo update

      echo "✓ Jenkins Helm repo added"
    EOT

    interpreter = ["bash", "-c"]
  }
}

# Deploy Jenkins using Helm
resource "null_resource" "deploy_jenkins" {
  depends_on = [
    null_resource.create_jenkins_namespace,
    null_resource.add_jenkins_helm_repo
  ]

  triggers = {
    jenkins_enabled = var.jenkins_enabled
    jenkins_version = var.jenkins_version
    config_hash     = filemd5("${path.module}/templates/jenkins-values.yaml")
  }

  count = var.jenkins_enabled ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      #!/bin/bash
      set -e

      echo "Deploying Jenkins with Helm..."

      # Build helm command with optional version
      HELM_CMD="helm upgrade --install jenkins jenkins/jenkins --namespace jenkins"

      # Add version flag only if version is specified
      if [ -n "${var.jenkins_version}" ]; then
        HELM_CMD="$HELM_CMD --version ${var.jenkins_version}"
      fi

      HELM_CMD="$HELM_CMD --values ${path.module}/templates/jenkins-values.yaml --wait --timeout 10m"

      # Deploy Jenkins
      eval "$HELM_CMD"

      echo "✓ Jenkins deployed successfully"

      # Wait for Jenkins to be ready
      echo "Waiting for Jenkins to be ready..."
      kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=jenkins-controller \
        -n jenkins --timeout=600s

      echo ""
      echo "=========================================="
      echo "Jenkins Deployment Complete!"
      echo "=========================================="
      echo ""

      # Get initial admin password
      echo "Initial Admin Password:"
      kubectl get secret -n jenkins jenkins -o jsonpath="{.data.jenkins-admin-password}" 2>/dev/null | base64 --decode || echo "Password not found yet"
      echo ""
      echo ""
      echo "To access Jenkins:"
      echo "  kubectl port-forward -n jenkins svc/jenkins 8080:8080"
      echo "  Open: http://localhost:8080"
      echo ""
      echo "Username: admin"
      echo "Password: (shown above)"
      echo ""
    EOT

    interpreter = ["bash", "-c"]
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      #!/bin/bash
      echo "Uninstalling Jenkins..."
      helm uninstall jenkins -n jenkins || true
    EOT

    interpreter = ["bash", "-c"]
  }
}

# Output Jenkins information
resource "null_resource" "jenkins_info" {
  depends_on = [null_resource.deploy_jenkins]

  count = var.jenkins_enabled ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      #!/bin/bash
      echo ""
      echo "=========================================="
      echo "Jenkins CI/CD Server"
      echo "=========================================="
      echo ""
      echo "Namespace: jenkins"
      echo ""
      echo "Pods:"
      kubectl get pods -n jenkins
      echo ""
      echo "Services:"
      kubectl get svc -n jenkins
      echo ""
      echo "Persistent Volumes:"
      kubectl get pvc -n jenkins
      echo ""
    EOT

    interpreter = ["bash", "-c"]
  }
}
