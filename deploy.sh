#!/bin/bash
# k3s ha cluster deployment script
# this script helps deploy the k3s cluster with proper checks and setup

set -e

# colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # no color

echo -e "${GREEN}k3s ha cluster deployment${NC}"
echo ""

# check if I'm in the right directory
if [ ! -f "site.yml" ]; then
    echo -e "${RED}error: site.yml not found - please run this script from the ansible-k3s-ha directory${NC}"
    exit 1
fi

# check if ansible is installed
if ! command -v ansible &> /dev/null; then
    echo -e "${RED}error: ansible is not installed.${NC}"
    echo "install with: pipx install ansible"
    exit 1
fi

echo -e "${GREEN}${NC} ansible found: $(ansible --version | head -n1)"

# check required collections
echo ""
echo "checking ansible collections..."
if ! ansible-galaxy collection list | grep -q "community.general"; then
    echo -e "${YELLOW}Installing community.general collection...${NC}"
    ansible-galaxy collection install community.general
else
    echo -e "${GREEN}${NC} community.general collection installed"
fi

if ! ansible-galaxy collection list | grep -q "ansible.posix"; then
    echo -e "${YELLOW}installing ansible.posix collection...${NC}"
    ansible-galaxy collection install ansible.posix
else
    echo -e "${GREEN}${NC} ansible.posix collection installed"
fi

# test connectivity
echo ""
echo "testing SSH connectivity to all nodes..."
if ansible all -m ping &> /dev/null; then
    echo -e "${GREEN}${NC} all nodes are reachable"
else
    echo -e "${RED}${NC} cannot reach all nodes - check SSH configuration"
    echo "debug with: ansible all -m ping"
    exit 1
fi

# ask for confirmation
echo ""
echo -e "${YELLOW}ready to deploy k3s cluster to:${NC}"
ansible all --list-hosts | tail -n +2
echo ""
read -p "continue with deployment? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "deployment cancelled"
    exit 0
fi

# Run the playbook
echo ""
echo -e "${GREEN}starting deployment...${NC}"
echo ""

if ansible-playbook site.yml; then
    echo ""
    echo -e "${GREEN}deployment complete${NC}"
    echo ""
    echo "kubeconfig saved to: $(pwd)/kubeconfig"
    echo ""
    echo "to use the new cluster:"
    echo "  export KUBECONFIG=$(pwd)/kubeconfig"
    echo "  kubectl get nodes"
    echo ""
else
    echo ""
    echo -e "${RED}deployment failed - check the output above for errors${NC}"
    exit 1
fi
