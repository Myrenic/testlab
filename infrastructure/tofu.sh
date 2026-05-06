#!/usr/bin/env bash
# Unified OpenTofu wrapper for all infrastructure stacks.
# Decrypts infra.json via SOPS, extracts per-stack config, and runs tofu.
#
# Usage: ./tofu.sh <stack> <command>
#   stack:   helios | atlas | omni | tailscale
#   command: init | plan | apply | destroy
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_JSON="${SCRIPT_DIR}/infra.json"
STACKS_DIR="${SCRIPT_DIR}/stacks"

STACK="${1:?Usage: $0 <stack> <command>}"
COMMAND="${2:?Usage: $0 <stack> <command>}"

if [[ ! -d "${STACKS_DIR}/${STACK}" ]]; then
  echo "Error: Unknown stack '${STACK}'. Available: $(ls "${STACKS_DIR}" | tr '\n' ' ')" >&2
  exit 1
fi

if [[ ! "$COMMAND" =~ ^(init|plan|apply|destroy)$ ]]; then
  echo "Error: Unknown command '${COMMAND}'. Must be: init, plan, apply, destroy" >&2
  exit 1
fi

cd "${STACKS_DIR}/${STACK}"

# Runner stack requires github_pat passed via environment
if [[ "$STACK" == "runner" && "$COMMAND" != "init" ]]; then
  if [[ -z "${TF_VAR_github_pat:-}" ]]; then
    echo "Error: Runner stack requires TF_VAR_github_pat environment variable" >&2
    echo "  export TF_VAR_github_pat='ghp_...'" >&2
    exit 1
  fi
fi

case "$COMMAND" in
  init)
    tofu init
    ;;
  plan|apply|destroy)
    sops exec-file --filename infra.json "${INFRA_JSON}" \
      "tofu ${COMMAND} -var-file={}"
    ;;
esac
