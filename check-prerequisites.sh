#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "K3s Prerequisites Check"
echo "=========================================="
echo ""

# Check if running on Linux
if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    echo -e "${RED}✗ Not running on Linux${NC}"
    echo "  K3s requires Linux. Detected: $OSTYPE"
    exit 1
else
    echo -e "${GREEN}✓ Running on Linux${NC}"
fi

# Check distribution
if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo -e "${GREEN}✓ Distribution: $NAME $VERSION${NC}"
else
    echo -e "${YELLOW}⚠ Cannot detect distribution${NC}"
fi

# Check if running as root or has sudo
if [ "$EUID" -eq 0 ]; then
    echo -e "${GREEN}✓ Running as root${NC}"
elif sudo -n true 2>/dev/null; then
    echo -e "${GREEN}✓ Has sudo access${NC}"
else
    echo -e "${RED}✗ No sudo access${NC}"
    echo "  K3s installation requires sudo privileges"
    exit 1
fi

# Check CPU cores
CPU_CORES=$(nproc)
if [ "$CPU_CORES" -ge 2 ]; then
    echo -e "${GREEN}✓ CPU cores: $CPU_CORES${NC}"
else
    echo -e "${YELLOW}⚠ CPU cores: $CPU_CORES (minimum 2 recommended)${NC}"
fi

# Check RAM
TOTAL_RAM=$(free -m | awk 'NR==2{print $2}')
if [ "$TOTAL_RAM" -ge 2000 ]; then
    echo -e "${GREEN}✓ RAM: ${TOTAL_RAM}MB${NC}"
else
    echo -e "${RED}✗ RAM: ${TOTAL_RAM}MB (minimum 2GB required)${NC}"
    exit 1
fi

# Check disk space
DISK_SPACE=$(df -BG / | awk 'NR==2{print $4}' | sed 's/G//')
if [ "$DISK_SPACE" -ge 20 ]; then
    echo -e "${GREEN}✓ Disk space: ${DISK_SPACE}GB available${NC}"
else
    echo -e "${YELLOW}⚠ Disk space: ${DISK_SPACE}GB (minimum 20GB recommended)${NC}"
fi

# Check if curl is installed
if command -v curl &> /dev/null; then
    echo -e "${GREEN}✓ curl installed${NC}"
else
    echo -e "${RED}✗ curl not installed${NC}"
    echo "  Install with: sudo apt-get install curl"
    exit 1
fi

# Check if terraform is installed
if command -v terraform &> /dev/null; then
    TERRAFORM_VERSION=$(terraform version -json | grep -o '"terraform_version":"[^"]*' | cut -d'"' -f4)
    echo -e "${GREEN}✓ Terraform installed: $TERRAFORM_VERSION${NC}"
else
    echo -e "${RED}✗ Terraform not installed${NC}"
    echo "  Install from: https://www.terraform.io/downloads"
    exit 1
fi

# Check if k3s is already installed
if command -v k3s &> /dev/null; then
    K3S_VERSION=$(k3s --version | head -n1 | awk '{print $3}')
    echo -e "${YELLOW}⚠ K3s already installed: $K3S_VERSION${NC}"
    echo "  Run 'sudo /usr/local/bin/k3s-uninstall.sh' to uninstall first"
else
    echo -e "${GREEN}✓ K3s not installed (ready for installation)${NC}"
fi

# Check firewall status
if command -v ufw &> /dev/null; then
    if sudo ufw status | grep -q "Status: active"; then
        echo -e "${YELLOW}⚠ UFW firewall is active${NC}"
        echo "  Ensure port 6443 is open: sudo ufw allow 6443/tcp"
    else
        echo -e "${GREEN}✓ UFW firewall inactive${NC}"
    fi
fi

# Check if ports are available
if command -v ss &> /dev/null; then
    if ss -tuln | grep -q ":6443 "; then
        echo -e "${RED}✗ Port 6443 already in use${NC}"
        exit 1
    else
        echo -e "${GREEN}✓ Port 6443 available${NC}"
    fi
fi

echo ""
echo "=========================================="
echo -e "${GREEN}Prerequisites check passed!${NC}"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. cp terraform.tfvars.example terraform.tfvars"
echo "  2. vim terraform.tfvars  # Edit if needed"
echo "  3. terraform init"
echo "  4. terraform apply"
echo ""
