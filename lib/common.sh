#!/bin/bash

# Common helper functions for k8s scripts

# Colors
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export NC='\033[0m' # No Color

# Helper function to run commands with sudo if needed
maybe_sudo() {
    if [ "$EUID" -eq 0 ]; then
        # Running as root, no sudo needed
        "$@"
    elif command -v sudo >/dev/null 2>&1; then
        # sudo available, use it
        sudo "$@"
    else
        # No sudo, try without (may fail)
        "$@"
    fi
}

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Print colored message
print_info() {
    echo -e "${BLUE}$1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Check if running with appropriate privileges
check_privileges() {
    if [ "$EUID" -eq 0 ]; then
        print_success "Running as root"
        return 0
    elif command_exists sudo; then
        print_success "sudo available"
        return 0
    else
        print_warning "No sudo found - assuming privileged environment"
        return 0
    fi
}
