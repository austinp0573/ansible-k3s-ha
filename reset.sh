#!/bin/bash
# k3s ha cluster reset script
# script to completely removes k3s from all nodes

set -e

# colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # no color

echo -e "${RED}k3s ha cluster reset${NC}"
echo ""
echo -e "${YELLOW}WARNING: this will completely remove k3s from all nodes${NC}"
echo -e "${YELLOW}this action cannot be undone${NC}"
echo ""
ansible all --list-hosts | tail -n +2
echo ""
read -p "are you sure you want to reset the cluster? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "reset cancelled."
    exit 0
fi

echo ""
echo -e "${YELLOW}starting cluster reset...${NC}"
echo ""

if ansible-playbook reset.yml; then
    echo ""
    echo -e "${GREEN}reset complete${NC}"
    echo ""
    echo "all nodes have been cleaned and are ready for fresh deployment"
    echo ""
else
    echo ""
    echo -e "${RED}reset failed - check the output above for errors${NC}"
    exit 1
fi
