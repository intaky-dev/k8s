#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}"
cat << "EOF"
 _    _____
| | _|___ / ___
| |/ / |_ \/ __|
|   < ___) \__ \
|_|\_\____/|___/

Kubernetes Cluster Quick Start
EOF
echo -e "${NC}"

# Check prerequisites
echo -e "${BLUE}Step 1: Checking prerequisites...${NC}"
if [ -f "./check-prerequisites.sh" ]; then
    bash ./check-prerequisites.sh
    if [ $? -ne 0 ]; then
        echo -e "${RED}Prerequisites check failed. Please fix the issues above.${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}Warning: check-prerequisites.sh not found, skipping checks${NC}"
fi

echo ""
echo -e "${BLUE}Step 2: Configuring Terraform...${NC}"

# Create terraform.tfvars if it doesn't exist
if [ ! -f "terraform.tfvars" ]; then
    echo "Creating terraform.tfvars from example..."
    cp terraform.tfvars.example terraform.tfvars
    echo -e "${GREEN}✓ Created terraform.tfvars${NC}"
    echo ""
    echo -e "${YELLOW}You can edit terraform.tfvars to customize the installation${NC}"
    echo "Press Enter to continue with default settings, or Ctrl+C to exit and edit..."
    read
else
    echo -e "${GREEN}✓ terraform.tfvars already exists${NC}"
fi

echo ""
echo -e "${BLUE}Step 3: Initializing Terraform...${NC}"
terraform init
if [ $? -ne 0 ]; then
    echo -e "${RED}Terraform init failed${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Terraform initialized${NC}"

echo ""
echo -e "${BLUE}Step 4: Planning installation...${NC}"
terraform plan -out=tfplan
if [ $? -ne 0 ]; then
    echo -e "${RED}Terraform plan failed${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Plan created${NC}"

echo ""
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}Ready to install k3s!${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""
echo "This will:"
echo "  • Install k3s on your Ubuntu server"
echo "  • Configure kubectl"
echo "  • Setup local storage"
echo "  • Install metrics-server"
echo ""
echo "Installation takes approximately 2-3 minutes."
echo ""
read -p "Do you want to proceed? [Y/n] " -n 1 -r
echo

if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    echo ""
    echo -e "${BLUE}Step 5: Installing k3s...${NC}"
    terraform apply tfplan

    if [ $? -eq 0 ]; then
        echo ""
        echo -e "${GREEN}========================================${NC}"
        echo -e "${GREEN}✓ k3s installation completed!${NC}"
        echo -e "${GREEN}========================================${NC}"
        echo ""

        # Export kubeconfig
        KUBECONFIG_PATH="$(pwd)/kubeconfig"

        echo "To start using your cluster, run:"
        echo ""
        echo -e "${YELLOW}  export KUBECONFIG=$KUBECONFIG_PATH${NC}"
        echo ""
        echo "Verify the installation:"
        echo ""
        echo "  kubectl get nodes"
        echo "  kubectl get pods -A"
        echo ""
        echo "Next steps:"
        echo ""
        echo "  1. Deploy Langflow:"
        echo "     cd ../langflow-infra"
        echo "     terraform apply -var=\"kubeconfig_path=$KUBECONFIG_PATH\""
        echo ""
        echo "  2. Access Langflow:"
        echo "     kubectl port-forward -n langflow svc/langflow-ide 7860:7860"
        echo "     Open: http://localhost:7860"
        echo ""

        # Offer to export kubeconfig now
        read -p "Export KUBECONFIG now and test? [Y/n] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            export KUBECONFIG=$KUBECONFIG_PATH
            echo ""
            echo "Cluster nodes:"
            kubectl get nodes
            echo ""
            echo "System pods:"
            kubectl get pods -n kube-system
            echo ""
            echo -e "${GREEN}Everything looks good!${NC}"
        fi
    else
        echo -e "${RED}Installation failed. Check the errors above.${NC}"
        exit 1
    fi
else
    echo ""
    echo "Installation cancelled."
    echo "You can run 'terraform apply' manually when ready."
fi
