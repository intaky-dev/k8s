.PHONY: help init plan apply destroy status kubeconfig clean backup jenkins-deploy jenkins-status jenkins-password

# Variables
KUBECONFIG_FILE := $(shell pwd)/kubeconfig

help:
	@echo "K3s Kubernetes Cluster Management"
	@echo ""
	@echo "Available commands:"
	@echo "  make init             - Initialize Terraform"
	@echo "  make plan             - Show Terraform execution plan"
	@echo "  make apply            - Install k3s cluster"
	@echo "  make destroy          - Uninstall k3s cluster"
	@echo "  make status           - Show cluster status"
	@echo "  make kubeconfig       - Export KUBECONFIG environment variable"
	@echo "  make backup           - Create etcd snapshot backup"
	@echo "  make clean            - Clean Terraform files"
	@echo ""
	@echo "Jenkins commands:"
	@echo "  make jenkins-deploy   - Deploy Jenkins CI/CD"
	@echo "  make jenkins-status   - Show Jenkins status"
	@echo "  make jenkins-password - Get Jenkins admin password"
	@echo ""
	@echo "Usage examples:"
	@echo "  make apply              # Install k3s"
	@echo "  eval \$$(make kubeconfig)  # Configure kubectl"
	@echo "  make status             # Check cluster"
	@echo "  make jenkins-deploy     # Deploy Jenkins"
	@echo "  make destroy            # Uninstall"

init:
	@echo "Initializing Terraform..."
	terraform init

plan:
	@echo "Planning Terraform changes..."
	terraform plan

apply:
	@echo "Installing k3s cluster..."
	terraform apply
	@echo ""
	@echo "Cluster installed successfully!"
	@echo "Run: eval \$$(make kubeconfig)"

destroy:
	@echo "WARNING: This will destroy the k3s cluster and all resources!"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		terraform destroy; \
	fi

status:
	@echo "Checking k3s cluster status..."
	@echo ""
	@echo "=== K3s Service Status ==="
	@sudo systemctl status k3s --no-pager | head -n 10 || echo "k3s not installed"
	@echo ""
	@echo "=== Cluster Nodes ==="
	@export KUBECONFIG=$(KUBECONFIG_FILE) && kubectl get nodes 2>/dev/null || echo "Cannot connect to cluster"
	@echo ""
	@echo "=== System Pods ==="
	@export KUBECONFIG=$(KUBECONFIG_FILE) && kubectl get pods -n kube-system 2>/dev/null || echo "Cannot connect to cluster"
	@echo ""
	@echo "=== Storage Classes ==="
	@export KUBECONFIG=$(KUBECONFIG_FILE) && kubectl get storageclass 2>/dev/null || echo "Cannot connect to cluster"

kubeconfig:
	@echo "export KUBECONFIG=$(KUBECONFIG_FILE)"

backup:
	@echo "Creating etcd snapshot backup..."
	@sudo k3s etcd-snapshot save --name backup-$$(date +%Y%m%d-%H%M%S)
	@echo "Backup created in: /var/lib/rancher/k3s/server/db/snapshots/"
	@ls -lh /var/lib/rancher/k3s/server/db/snapshots/ | tail -n 5

clean:
	@echo "Cleaning Terraform files..."
	rm -rf .terraform
	rm -f .terraform.lock.hcl
	rm -f terraform.tfstate*
	rm -f tfplan*
	rm -f kubeconfig kubeconfig.tmp
	@echo "Clean complete!"

# Quick setup command
setup:
	@echo "Quick k3s setup..."
	@if [ ! -f terraform.tfvars ]; then \
		echo "Creating terraform.tfvars..."; \
		cp terraform.tfvars.example terraform.tfvars; \
	fi
	make init
	make apply
	@echo ""
	@echo "Setup complete! Run: eval \$$(make kubeconfig)"

# Jenkins commands
jenkins-deploy:
	@echo "Deploying Jenkins CI/CD..."
	@bash ./deploy-jenkins.sh

jenkins-status:
	@echo "Jenkins Status"
	@echo "=============="
	@echo ""
	@export KUBECONFIG=$(KUBECONFIG_FILE) && \
	echo "Pods:" && \
	kubectl get pods -n jenkins && \
	echo "" && \
	echo "Services:" && \
	kubectl get svc -n jenkins && \
	echo "" && \
	echo "Persistent Volumes:" && \
	kubectl get pvc -n jenkins

jenkins-password:
	@echo "Jenkins Admin Password:"
	@export KUBECONFIG=$(KUBECONFIG_FILE) && \
	kubectl get secret -n jenkins jenkins -o jsonpath="{.data.jenkins-admin-password}" | base64 --decode
	@echo ""
