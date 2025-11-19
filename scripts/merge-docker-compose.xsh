#!/usr/bin/env xonsh

# Copyright (c) 2025 Toradex
# SPDX-License-Identifier: MIT

# This script builds the multiroot docker-compose.yml by combining
# each workspace's docker-compose.prod.yml

import os
import json
import yaml
from pathlib import Path

args = $ARGS

multiroot_workspace = Path(args[1])
workspace_file = next(multiroot_workspace.rglob("*.code-workspace"), None)
if not workspace_file:
    print("No .code-workspace file found. Exiting.")
    exit(1)

workspace_folders = [
    p for p in multiroot_workspace.iterdir()
    if p.is_dir()
    and (p / ".vscode" / "settings.json").exists()
]

merged = {"services": {}}
for folder in workspace_folders:
    compose_file = folder / "docker-compose.yml"
    if not compose_file.exists():
        continue

    try:
        with compose_file.open() as f:
            data = yaml.safe_load(f)

        if not data or "services" not in data:
            continue

        for name, svc in data["services"].items():
            # Remove build.dockerfile if present
            if "build" in svc and "dockerfile" in svc["build"]:
                del svc["build"]

            merged["services"][name] = svc

    except Exception as e:
        print(f"Error parsing {compose_file}: {e}")

merged_path = multiroot_workspace / "docker-compose.yml"
try:
    with merged_path.open("w") as f:
        yaml.dump(merged, f, default_flow_style=False)
    print(f"Merged Docker Compose written to: {merged_path}")
except Exception as e:
    print(f"Failed to write merged compose: {e}")
