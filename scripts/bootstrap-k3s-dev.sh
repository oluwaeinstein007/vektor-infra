#!/usr/bin/env bash
# INFRA-003 (dev half): stand up the single-node k3s cluster that
# terraform/environments/dev targets (kube context "k3s-dev"). Cluster
# bootstrap itself is a shell script, not Terraform — there's no cloud API
# to provision against (§11.1: same bare-metal-style stack in every tier),
# and Terraform's kubernetes/helm providers need a cluster to already exist
# before they can do anything.
#
# Prod cluster bootstrap (RKE2 across the §11.3 rack, 3-node HA control
# plane) is deliberately not scripted here — it's a change-controlled,
# DevOps + Security Lead-approved runbook (§9.9), not a one-shot curl-pipe.
# That runbook is a DOC-001 deliverable, tracked separately in the roadmap.
set -euo pipefail

K3S_VERSION="${K3S_VERSION:-v1.31.4+k3s1}"

echo "==> Installing k3s ${K3S_VERSION}"
curl -sfL https://get.k3s.io | \
  INSTALL_K3S_VERSION="${K3S_VERSION}" \
  INSTALL_K3S_EXEC="--disable traefik --write-kubeconfig-mode 644" \
  sh -

echo "==> Waiting for node to be Ready"
until sudo k3s kubectl get node -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -q True; do
  sleep 2
done

echo "==> Merging kubeconfig into ~/.kube/config as context 'k3s-dev'"
mkdir -p "$HOME/.kube"
sudo k3s kubectl config view --raw | sudo tee /tmp/k3s-dev.yaml > /dev/null
KUBECONFIG="$HOME/.kube/config:/tmp/k3s-dev.yaml" kubectl config view --flatten > /tmp/merged.yaml
mv /tmp/merged.yaml "$HOME/.kube/config"
kubectl config rename-context default k3s-dev --kubeconfig "$HOME/.kube/config" 2>/dev/null || true
rm -f /tmp/k3s-dev.yaml

echo "==> k3s dev cluster ready. Next: cd terraform/environments/dev && terraform init && terraform apply"
