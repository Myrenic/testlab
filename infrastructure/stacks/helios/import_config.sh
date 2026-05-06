#!/usr/bin/env bash
# Import kubeconfig and talosconfig from the helios stack output.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_JSON="${SCRIPT_DIR}/../../infra.json"

cd "${SCRIPT_DIR}"

sops exec-file --filename infra.json "$INFRA_JSON" 'tofu output -var-file={} -raw kubeconfig' > ~/.kube/config
sops exec-file --filename infra.json "$INFRA_JSON" 'tofu output -var-file={} -raw talosconfig' > ~/.talos/config

export KUBECONFIG=~/.kube/config
export TALOSCONFIG=~/.talos/config

kubectl get nodes
