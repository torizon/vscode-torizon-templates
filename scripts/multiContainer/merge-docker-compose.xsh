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
workspace_root = Path(args[1])

workspace_file = next(workspace_root.glob("*.code-workspace"), None)
if not workspace_file:
    print("No .code-workspace file found. Exiting.")
    exit(1)

workspace_folders = [
    p for p in workspace_root.iterdir()
    if p.is_dir() and (p / ".vscode" / "settings.json").exists()
]

tag_by_folder = {}
for folder in workspace_folders:
    settings_path = folder / ".vscode" / "settings.json"
    try:
        with settings_path.open() as f:
            settings = json.load(f)
        tag = settings.get("docker_tag")
        if tag:
            tag_by_folder[folder.name] = tag
    except Exception as e:
        print(f"Warning: Could not read {settings_path}: {e}")

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

            # Replace ${TAG} with the docker_tag if applicable
            tag = tag_by_folder.get(folder.name)
            if tag:
                svc_yaml = yaml.dump(svc)
                svc_yaml = svc_yaml.replace("${TAG}", tag)
                svc = yaml.safe_load(svc_yaml)

            # Add profiles based on service name
            if "debug" in name.lower():
                svc["profiles"] = ["debug"]
            else:
                svc["profiles"] = ["release"]

            merged["services"][name] = svc

    except Exception as e:
        print(f"Error parsing {compose_file}: {e}")

merged_path = workspace_root / "docker-compose.yml"
try:
    with merged_path.open("w") as f:
        yaml.dump(merged, f, default_flow_style=False)
    print(f"Merged Docker Compose written to: {merged_path}")
except Exception as e:
    print(f"Failed to write merged compose: {e}")
