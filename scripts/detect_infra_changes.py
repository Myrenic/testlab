#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import PurePosixPath

ALL_STACKS = [
    "templates",
    "tailscale",
    "atlas",
    "omni",
    "garage",
    "helios",
    "runner",
]
AUTO_APPLY_STACKS = [stack for stack in ALL_STACKS if stack != "runner"]
MODULE_STACKS = {
    "lxc": ["atlas", "garage", "omni", "runner", "tailscale"],
    "talos-image": ["helios"],
    "talos-vm": ["helios"],
    "talos-cluster": ["helios"],
}
PATCH_STACKS = {
    "talos": ["helios"],
}
WORKFLOW_PATHS = {
    ".github/workflows/infra-apply.yaml",
    ".github/workflows/validate-changes.yaml",
    "scripts/detect_infra_changes.py",
}


def git_changed_files(base_sha: str, head_sha: str) -> list[str]:
    if not base_sha or set(base_sha) == {"0"}:
        command = ["git", "diff-tree", "--no-commit-id", "--name-only", "-r", head_sha]
    else:
        command = ["git", "diff", "--name-only", base_sha, head_sha]

    completed = subprocess.run(command, check=True, capture_output=True, text=True)
    return [line.strip() for line in completed.stdout.splitlines() if line.strip()]


def detect_stacks(
    changed_files: list[str],
    auto_stacks: list[str],
    include_all_stacks_for_workflow_changes: bool,
) -> tuple[list[str], bool, bool]:
    stacks: set[str] = set()
    infra_changed = False
    kubernetes_changed = False

    for changed_file in changed_files:
        if changed_file.startswith("kubernetes/"):
            kubernetes_changed = True
            continue

        if changed_file in WORKFLOW_PATHS:
            infra_changed = True
            if include_all_stacks_for_workflow_changes:
                stacks.update(auto_stacks)
            continue

        if not changed_file.startswith("infrastructure/"):
            continue

        infra_changed = True
        path = PurePosixPath(changed_file)
        parts = path.parts

        if changed_file == "infrastructure/infra.json":
            stacks.update(auto_stacks)
            continue

        if len(parts) >= 3 and parts[1] == "stacks":
            stack = parts[2]
            if stack in ALL_STACKS:
                stacks.add(stack)
            continue

        if len(parts) >= 3 and parts[1] == "modules":
            stacks.update(MODULE_STACKS.get(parts[2], auto_stacks))
            continue

        if len(parts) >= 3 and parts[1] == "patches":
            stacks.update(PATCH_STACKS.get(parts[2], auto_stacks))

    return sorted(stack for stack in stacks if stack in auto_stacks), infra_changed, kubernetes_changed


def main() -> int:
    parser = argparse.ArgumentParser(description="Detect changed infrastructure stacks.")
    parser.add_argument("--head-sha", required=True, help="Git SHA at the tip of the diff range.")
    parser.add_argument(
        "--base-sha",
        default="",
        help="Git SHA at the start of the diff range. Leave empty for single-commit detection.",
    )
    parser.add_argument(
        "--mode",
        choices=("apply", "validate"),
        default="validate",
        help="Auto-detected stack scope.",
    )
    parser.add_argument(
        "--stack",
        help="Explicit stack override, typically for workflow_dispatch applies.",
    )
    args = parser.parse_args()

    auto_stacks = AUTO_APPLY_STACKS if args.mode == "apply" else ALL_STACKS
    include_all_stacks_for_workflow_changes = args.mode == "validate"

    if args.stack:
        if args.stack not in ALL_STACKS:
            parser.error(f"unknown stack {args.stack!r}")
        stacks = [args.stack]
        infra_changed = True
        kubernetes_changed = False
    else:
        changed_files = git_changed_files(args.base_sha, args.head_sha)
        stacks, infra_changed, kubernetes_changed = detect_stacks(
            changed_files,
            auto_stacks,
            include_all_stacks_for_workflow_changes,
        )

    print(f"stacks={json.dumps(stacks)}")
    print(f"infra_changed={'true' if infra_changed else 'false'}")
    print(f"kubernetes_changed={'true' if kubernetes_changed else 'false'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
