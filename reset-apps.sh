#!/usr/bin/env bash
# remove day-0 applications from k3s cluster
# does not touch the cluster infrastructure itself

set -e

echo "removing day-0 applications from k3s cluster"
echo ""

# check if kubeconfig exists
if ! [ -f ./kubeconfig ]; then
    echo "error: kubeconfig not found. cluster may not be deployed."
    exit 1
fi

export KUBECONFIG=$(pwd)/kubeconfig

echo "removing argocd..."
kubectl delete namespace argocd --ignore-not-found=true --timeout=120s

echo "removing cert-manager..."
kubectl delete -f https://github.com/cert-manager/cert-manager/releases/download/v1.16.2/cert-manager.yaml --ignore-not-found=true

echo "removing longhorn..."
kubectl delete namespace longhorn-system --ignore-not-found=true --timeout=300s

echo "cleaning up longhorn data on nodes..."
ansible k3s_cluster -b -m shell -a "rm -rf /var/lib/longhorn" 2>&1 | grep -v "DEPRECATION" || true

echo ""
echo "day-0 applications removed successfully"
echo "cluster infrastructure remains intact"
echo ""
echo "to redeploy: ./deploy-apps.sh"