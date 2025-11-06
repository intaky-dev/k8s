#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}"
cat << "EOF"
     _            _    _
    | | ___ _ __ | | _(_)_ __  ___
 _  | |/ _ \ '_ \| |/ / | '_ \/ __|
| |_| |  __/ | | |   <| | | | \__ \
 \___/ \___|_| |_|_|\_\_|_| |_|___/

CI/CD Deployment Helper
EOF
echo -e "${NC}"

# Get absolute paths
K8S_DIR="$(cd "$(dirname "$0")" && pwd)"
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
echo -e "${BLUE}Jenkins CI/CD Deployment${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if Helm is installed
echo -e "${BLUE}Checking Helm installation...${NC}"
if ! command -v helm &> /dev/null; then
    echo -e "${YELLOW}Helm not found. Installing Helm...${NC}"
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ Failed to install Helm${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Helm installed${NC}"
else
    echo -e "${GREEN}✓ Helm is already installed${NC}"
    helm version --short
fi

echo ""
echo -e "${BLUE}Adding Jenkins Helm repository...${NC}"
helm repo add jenkins https://charts.jenkins.io
helm repo update
echo -e "${GREEN}✓ Helm repository added${NC}"

# Create namespace
echo ""
echo -e "${BLUE}Creating jenkins namespace...${NC}"
kubectl create namespace jenkins --dry-run=client -o yaml | kubectl apply -f -
echo -e "${GREEN}✓ Namespace created${NC}"

# Ask for deployment confirmation
echo ""
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}Ready to deploy Jenkins!${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""
echo "This will deploy:"
echo "  • Jenkins Controller (LTS version)"
echo "  • Kubernetes dynamic agents"
echo "  • Docker-in-Docker support"
echo "  • Pre-installed CI/CD plugins:"
echo "    - Git, GitHub, GitLab, Bitbucket"
echo "    - Docker Pipeline"
echo "    - Pipeline plugins"
echo "    - Blue Ocean UI"
echo "    - Prometheus metrics"
echo "  • 20Gi persistent storage"
echo ""
echo "Resources required:"
echo "  • 2 CPU, 4Gi RAM (controller)"
echo "  • 1 CPU, 1Gi RAM per agent"
echo "  • 20Gi disk space"
echo ""
echo "Deployment takes approximately 3-5 minutes."
echo ""
read -p "Proceed with deployment? [Y/n] " -n 1 -r
echo

if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    echo ""
    echo -e "${BLUE}Deploying Jenkins...${NC}"

    # Deploy Jenkins with Helm
    helm upgrade --install jenkins jenkins/jenkins \
        --namespace jenkins \
        --values "$K8S_DIR/templates/jenkins-values.yaml" \
        --wait \
        --timeout 10m

    if [ $? -eq 0 ]; then
        echo ""
        echo -e "${GREEN}========================================${NC}"
        echo -e "${GREEN}✓ Jenkins deployed successfully!${NC}"
        echo -e "${GREEN}========================================${NC}"
        echo ""

        # Wait for Jenkins to be ready
        echo "Waiting for Jenkins to be ready..."
        kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=jenkins-controller \
            -n jenkins --timeout=600s 2>/dev/null || true

        echo ""
        echo "Deployment status:"
        kubectl get pods -n jenkins

        echo ""
        echo -e "${BLUE}========================================${NC}"
        echo -e "${BLUE}Jenkins Access Information${NC}"
        echo -e "${BLUE}========================================${NC}"
        echo ""

        # Get admin password
        echo -e "${YELLOW}Initial Admin Credentials:${NC}"
        echo "Username: admin"
        echo -n "Password: "
        kubectl get secret -n jenkins jenkins -o jsonpath="{.data.jenkins-admin-password}" | base64 --decode
        echo ""
        echo ""

        echo -e "${BLUE}Access Jenkins:${NC}"
        echo "1. Port Forward:"
        echo "   kubectl port-forward -n jenkins svc/jenkins 8080:8080"
        echo ""
        echo "2. Open in browser:"
        echo "   http://localhost:8080"
        echo ""

        echo -e "${BLUE}Useful Commands:${NC}"
        echo "  • View logs:"
        echo "    kubectl logs -n jenkins -l app.kubernetes.io/component=jenkins-controller -f"
        echo ""
        echo "  • View all resources:"
        echo "    kubectl get all -n jenkins"
        echo ""
        echo "  • Access Jenkins CLI:"
        echo "    kubectl exec -n jenkins -it svc/jenkins -c jenkins -- bash"
        echo ""
        echo "  • Restart Jenkins:"
        echo "    kubectl rollout restart deployment -n jenkins"
        echo ""

        echo -e "${BLUE}Jenkins Configuration:${NC}"
        echo "  • Plugins: Pre-installed with Git, Docker, Kubernetes"
        echo "  • Agents: Dynamic Kubernetes agents"
        echo "  • Storage: 20Gi persistent volume"
        echo "  • Metrics: Prometheus endpoint enabled"
        echo ""

        echo -e "${BLUE}Example Pipeline:${NC}"
        echo "  Create a new Pipeline job with:"
        echo ""
        echo "  pipeline {"
        echo "    agent {"
        echo "      kubernetes {"
        echo "        label 'docker'"
        echo "      }"
        echo "    }"
        echo "    stages {"
        echo "      stage('Build') {"
        echo "        steps {"
        echo "          container('docker') {"
        echo "            sh 'docker build -t myapp .'"
        echo "          }"
        echo "        }"
        echo "      }"
        echo "    }"
        echo "  }"
        echo ""

        echo -e "${BLUE}Langflow Integration:${NC}"
        echo "  To trigger Langflow workflows from Jenkins:"
        echo "  1. Get Langflow API endpoint"
        echo "  2. Use HTTP Request plugin in Jenkins pipeline"
        echo "  3. Example:"
        echo "     httpRequest url: 'http://langflow-ide.langflow.svc.cluster.local:7860/api/v1/run'"
        echo ""

        # Offer to start port-forward
        read -p "Start port-forward now? [Y/n] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            echo ""
            echo -e "${GREEN}Starting port-forward...${NC}"
            echo "Access Jenkins at: http://localhost:8080"
            echo ""
            echo "Username: admin"
            echo -n "Password: "
            kubectl get secret -n jenkins jenkins -o jsonpath="{.data.jenkins-admin-password}" | base64 --decode
            echo ""
            echo ""
            echo "Press Ctrl+C to stop port-forwarding"
            echo ""
            kubectl port-forward -n jenkins svc/jenkins 8080:8080
        fi
    else
        echo -e "${RED}Deployment failed${NC}"
        echo ""
        echo "Check logs with:"
        echo "  kubectl logs -n jenkins -l app.kubernetes.io/component=jenkins-controller"
        echo ""
        echo "Check events:"
        echo "  kubectl get events -n jenkins --sort-by='.lastTimestamp'"
        exit 1
    fi
else
    echo ""
    echo "Deployment cancelled."
fi
