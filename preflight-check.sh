#!/bin/bash
# k3s ha cluster pre-flight check
# run this before deploying to verify all prerequisites are met

# colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # no color

ERRORS=0
WARNINGS=0


echo -e "${BLUE}k3s ha pre-flight check${NC}"
echo ""

# 1: ansible installed
echo -n "checking ansible installation... "
if command -v ansible &> /dev/null; then
    VERSION=$(ansible --version | head -n1 | awk '{print $2}')
    echo -e "${GREEN}${NC} found version $VERSION"
else
    echo -e "${RED}not found${NC}"
    echo "  install: pipx install ansible"
    ((ERRORS++))
fi

# 2: python version
echo -n "checking python version... "
if command -v python3 &> /dev/null; then
    VERSION=$(python3 --version | awk '{print $2}')
    echo -e "${GREEN}${NC} found version $VERSION"
else
    echo -e "${RED}python3 not found${NC}"
    ((ERRORS++))
fi

# 3: ansible collections
echo -n "checking community.general collection... "
if ansible-galaxy collection list 2>/dev/null | grep -q "community.general"; then
    echo -e "${GREEN}${NC}"
else
    echo -e "${YELLOW}not installed${NC}"
    echo "install: ansible-galaxy collection install community.general"
    ((WARNINGS++))
fi

echo -n "checking ansible.posix collection... "
if ansible-galaxy collection list 2>/dev/null | grep -q "ansible.posix"; then
    echo -e "${GREEN}${NC}"
else
    echo -e "${YELLOW}not installed${NC}"
    echo "install: ansible-galaxy collection install ansible.posix"
    ((WARNINGS++))
fi

# 4: ssh connectivity
echo ""
echo "checking SSH connectivity to all nodes..."
HOSTS=(
    "192.168.1.<cp_1_IP>:k3s-cp-1"
    "192.168.1.<cp_2_IP>:k3s-cp-2"
    "192.168.1.<cp_3_IP>:k3s-cp-3"
    "192.168.1.<wk_1_IP>:k3s-wk-1"
    "192.168.1.<wk_2_IP>:k3s-wk-2"
)

for host_info in "${HOSTS[@]}"; do
    IP="${host_info%%:*}"
    NAME="${host_info##*:}"
    echo -n "  $NAME ($IP)... "
    if timeout 5 ssh -o ConnectTimeout=3 -o StrictHostKeyChecking=no -o BatchMode=yes debian@$IP "exit" &>/dev/null; then
        echo -e "${GREEN}${NC}"
    else
        echo -e "${RED}${NC}"
        ((ERRORS++))
    fi
done

# 5: vip availability
echo ""
VIP_IP=25
echo -n "checking if 192.168.1.$VIP_IP is available... "
if ping -c 1 -W 1 192.168.1.$VIP_IP &>/dev/null; then
    echo -e "${YELLOW}IP is responding (already in use?)${NC}"
    ((WARNINGS++))
else
    echo -e "${GREEN}available${NC}"
fi

# 6: metallb ip range
echo -n "checking metallb IP range availability... "
RANGE_START=30
RANGE_END=60
IN_USE=0

for i in $(seq $RANGE_START $RANGE_END); do
    if timeout 0.3 ping -c 1 192.168.1.$i &>/dev/null; then
        if [ $IN_USE -eq 0 ]; then
            echo ""
            echo -e "  ${YELLOW}Warning: Some IPs in MetalLB range are in use:${NC}"
        fi
        echo "  192.168.1.$i is responding"
        IN_USE=$((IN_USE + 1))
    fi
done

if [ $IN_USE -eq 0 ]; then
    echo -e "${GREEN}all IPs available${NC}"
else
    echo -e "${YELLOW}  $IN_USE IPs in use (may cause conflicts)${NC}"
    ((WARNINGS++))
fi

# 7: project files
echo ""
echo "checking project structure..."
FILES=(
    "site.yml"
    "reset.yml"
    "ansible.cfg"
    "inventory/hosts.ini"
    "group_vars/all.yml"
    "roles/prereq/tasks/main.yml"
    "roles/k3s_server/tasks/main.yml"
)

for file in "${FILES[@]}"; do
    echo -n "  $file... "
    if [ -f "$file" ]; then
        echo -e "${GREEN}${NC}"
    else
        echo -e "${RED}missing${NC}"
        ((ERRORS++))
    fi
done

# summary
echo ""
echo -e "${BLUE}summary${NC}"

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}all checks passed - ready to deploy${NC}"
    echo ""
    echo "run: ./deploy.sh"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}$WARNINGS warning(s) found${NC}"
    exit 0
else
    echo -e "${RED}$ERRORS error(s) and $WARNINGS warning(s) found${NC}"
    echo "fix errors before deploying"
    exit 1
fi