#!/usr/bin/env bash
# Unified OpenTofu wrapper for all infrastructure stacks.
# Decrypts infra.json via SOPS, extracts per-stack config, and runs tofu.
#
# Usage: ./tofu.sh <stack> <command>
#   stack:   helios | atlas | omni | tailscale | templates | garage | runner
#   command: init | plan | apply | destroy
#
# Environment:
#   AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY - required for S3 state backend
#   TF_VAR_github_pat - required for runner stack
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

# Stacks using S3 backend need credentials
if [[ "$STACK" != "garage" && "$STACK" != "runner" ]]; then
  if [[ -z "${AWS_ACCESS_KEY_ID:-}" || -z "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
    echo "Error: S3 backend requires AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY" >&2
    echo "  export AWS_ACCESS_KEY_ID='GK...'" >&2
    echo "  export AWS_SECRET_ACCESS_KEY='...'" >&2
    exit 1
  fi
fi

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
