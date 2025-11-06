#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}"
cat << "EOF"
 _                   __ _
| |    __ _ _ __   __ _  / _| | _____      __
| |   / _` | '_ \ / _` || |_  | |/ _ \ \ /\ / /
| |__| (_| | | | | (_| ||  _| | | (_) \ V  V /
|_____\__,_|_| |_|\__, ||_|   |_|\___/ \_/\_/
                  |___/
Deployment Helper
EOF
echo -e "${NC}"

# Get absolute paths
K8S_DIR="$(cd "$(dirname "$0")" && pwd)"
LANGFLOW_INFRA_DIR="$(cd "$K8S_DIR/../langflow-infra" 2>/dev/null && pwd)"
KUBECONFIG_PATH="$K8S_DIR/kubeconfig"

# Check if k3s is installed
echo -e "${BLUE}Checking k3s installation...${NC}"
if [ ! -f "$KUBECONFIG_PATH" ]; then
    echo -e "${RED}✗ k3s not installed${NC}"
    echo ""
    echo "Please install k3s first:"
    echo "  cd $K8S_DIR"
    echo "  ./quick-start.sh"
    echo ""
    exit 1
else
    echo -e "${GREEN}✓ k3s installed${NC}"
fi

# Check if langflow-infra exists
if [ ! -d "$LANGFLOW_INFRA_DIR" ]; then
    echo -e "${RED}✗ langflow-infra directory not found${NC}"
    echo "Expected location: $K8S_DIR/../langflow-infra"
    exit 1
else
    echo -e "${GREEN}✓ langflow-infra directory found${NC}"
fi

# Export kubeconfig
export KUBECONFIG="$KUBECONFIG_PATH"

# Verify cluster is accessible
echo ""
echo -e "${BLUE}Verifying cluster connectivity...${NC}"
if ! kubectl cluster-info &>/dev/null; then
    echo -e "${RED}✗ Cannot connect to k3s cluster${NC}"
    echo "Try:"
    echo "  sudo systemctl status k3s"
    echo "  sudo systemctl restart k3s"
    exit 1
else
    echo -e "${GREEN}✓ Cluster is accessible${NC}"
fi

# Show cluster info
echo ""
echo "Cluster nodes:"
kubectl get nodes

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Langflow Deployment Configuration${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Ask for deployment type
echo "Select deployment type:"
echo "  1) Development (minimal resources, 1 replica each)"
echo "  2) Production (HA setup, multiple replicas)"
echo "  3) Custom (edit terraform.tfvars manually)"
echo ""
read -p "Enter choice [1-3]: " -n 1 -r DEPLOY_TYPE
echo ""

cd "$LANGFLOW_INFRA_DIR"

# Create terraform.tfvars based on choice
case $DEPLOY_TYPE in
    1)
        echo "Creating development configuration..."
        cat > terraform.tfvars <<EOF
# Kubernetes Configuration
kubeconfig_path = "$KUBECONFIG_PATH"
namespace       = "langflow"
environment     = "dev"

# Langflow Configuration
langflow_version = "1.0.18"
broker_type      = "redis"
vector_db_type   = "qdrant"

# Minimal resources for development
postgres_replicas    = 1
redis_replicas       = 1
vector_db_replicas   = 1
ide_replicas         = 1
runtime_min_replicas = 1
runtime_max_replicas = 3

# Reduced storage
postgres_storage_size   = "10Gi"
redis_storage_size      = "5Gi"
vector_db_storage_size  = "10Gi"

# Disable observability to save resources
enable_observability = false

# Ingress configuration
ingress_enabled    = true
ingress_class      = "nginx"
ide_ingress_host   = "langflow.local"
tls_enabled        = false
EOF
        ;;
    2)
        echo "Creating production configuration..."
        cat > terraform.tfvars <<EOF
# Kubernetes Configuration
kubeconfig_path = "$KUBECONFIG_PATH"
namespace       = "langflow"
environment     = "prod"

# Langflow Configuration
langflow_version = "1.0.18"
broker_type      = "rabbitmq"
vector_db_type   = "qdrant"

# HA configuration
postgres_replicas    = 3
rabbitmq_replicas    = 3
vector_db_replicas   = 2
ide_replicas         = 2
runtime_min_replicas = 2
runtime_max_replicas = 10

# Production storage
postgres_storage_size   = "20Gi"
rabbitmq_storage_size   = "10Gi"
vector_db_storage_size  = "20Gi"

# Enable observability
enable_observability = true
prometheus_enabled   = true
grafana_enabled      = true
loki_enabled         = true

# Ingress configuration
ingress_enabled    = true
ingress_class      = "nginx"
ide_ingress_host   = "langflow.local"
tls_enabled        = false
EOF
        ;;
    3)
        echo "Please edit terraform.tfvars manually"
        if [ ! -f terraform.tfvars ]; then
            cp terraform.tfvars.example terraform.tfvars
        fi
        echo "File location: $LANGFLOW_INFRA_DIR/terraform.tfvars"
        echo ""
        read -p "Press Enter after editing..."
        ;;
    *)
        echo -e "${RED}Invalid choice${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}✓ Configuration created${NC}"
echo ""

# Initialize if not done
if [ ! -d ".terraform" ]; then
    echo -e "${BLUE}Initializing Terraform...${NC}"
    terraform init
fi

# Plan
echo ""
echo -e "${BLUE}Creating deployment plan...${NC}"
terraform plan -out=tfplan

if [ $? -ne 0 ]; then
    echo -e "${RED}Planning failed${NC}"
    exit 1
fi

# Confirm deployment
echo ""
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}Ready to deploy Langflow!${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""
echo "This will deploy:"
echo "  • PostgreSQL database"
echo "  • Message broker (RabbitMQ/Redis)"
echo "  • Vector database (Qdrant)"
echo "  • Langflow IDE"
echo "  • Langflow Runtime workers"
if [ "$DEPLOY_TYPE" == "2" ]; then
    echo "  • Observability stack (Prometheus, Grafana, Loki)"
fi
echo ""
echo "Deployment takes approximately 5-10 minutes."
echo ""
read -p "Proceed with deployment? [Y/n] " -n 1 -r
echo

if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    echo ""
    echo -e "${BLUE}Deploying Langflow...${NC}"
    terraform apply tfplan

    if [ $? -eq 0 ]; then
        echo ""
        echo -e "${GREEN}========================================${NC}"
        echo -e "${GREEN}✓ Langflow deployed successfully!${NC}"
        echo -e "${GREEN}========================================${NC}"
        echo ""

        # Wait for pods to be ready
        echo "Waiting for pods to be ready..."
        kubectl wait --for=condition=ready pod -l app=langflow-ide -n langflow --timeout=300s 2>/dev/null || true

        echo ""
        echo "Deployment status:"
        kubectl get pods -n langflow

        echo ""
        echo -e "${BLUE}========================================${NC}"
        echo -e "${BLUE}Access Langflow${NC}"
        echo -e "${BLUE}========================================${NC}"
        echo ""
        echo "Option 1: Port Forward (easiest)"
        echo "  kubectl port-forward -n langflow svc/langflow-ide 7860:7860"
        echo "  Open: http://localhost:7860"
        echo ""
        echo "Option 2: Ingress (requires DNS/hosts configuration)"
        echo "  Add to /etc/hosts: 127.0.0.1 langflow.local"
        echo "  Open: http://langflow.local"
        echo ""
        echo "Useful commands:"
        echo "  • View logs: kubectl logs -n langflow -l app=langflow-ide -f"
        echo "  • View all pods: kubectl get pods -n langflow"
        echo "  • View services: kubectl get svc -n langflow"
        echo ""

        # Offer to start port-forward
        read -p "Start port-forward now? [Y/n] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            echo ""
            echo -e "${GREEN}Starting port-forward...${NC}"
            echo "Access Langflow at: http://localhost:7860"
            echo "Press Ctrl+C to stop"
            echo ""
            kubectl port-forward -n langflow svc/langflow-ide 7860:7860
        fi
    else
        echo -e "${RED}Deployment failed${NC}"
        exit 1
    fi
else
    echo ""
    echo "Deployment cancelled."
fi
