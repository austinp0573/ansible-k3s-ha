#!/usr/bin/env bash
# deploy day-0 applications to k3s cluster
# requires cluster to be already deployed via site.yml

set -e

echo "deploying day-0 applications to k3s cluster"
echo ""

# check if ansible is installed
if ! command -v ansible-playbook &> /dev/null; then
    echo "error: ansible not found. install ansible first."
    exit 1
fi

echo "checking if cluster is accessible..."
if ! [ -f ./kubeconfig ]; then
    echo "error: kubeconfig not found. deploy cluster first with ./deploy.sh"
    exit 1
fi

echo "deploying applications..."
ansible-playbook apps.yml 2>&1 | tee deploy-apps.log

if [ $? -eq 0 ]; then
    echo ""
    echo "day-0 applications deployed successfully"
    echo ""
    echo "access applications:"
    echo ""
    echo "1 - longhorn ui:"
    echo "   export KUBECONFIG=\$(pwd)/kubeconfig"
    echo "   kubectl port-forward -n longhorn-system svc/longhorn-frontend 8080:80"
    echo ""
    echo "2 - argocd ui:"
    echo "   export KUBECONFIG=\$(pwd)/kubeconfig"
    echo "   kubectl port-forward -n argocd svc/argocd-server 8081:443"
    echo "   username: admin"
    echo "   password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d"
else
    echo ""
    echo "deployment failed - check deploy-apps.log for errors"
    exit 1
fi