#!/usr/bin/env xonsh
"""
merge-docker-compose.xsh: Combine each workspace's docker-compose.yml into a multi-root compose.
"""
# pylint: disable=invalid-name,missing-module-docstring

import sys
import json
from pathlib import Path
import yaml  # third-party import last

# Prefer sys.argv for pylint compatibility (xonsh also populates it)
args = sys.argv

multiroot_workspace = Path(args[1])
workspace_file = next(multiroot_workspace.rglob("*.code-workspace"), None)
if not workspace_file:
    print("No .code-workspace file found. Exiting.")
    sys.exit(1)

workspace_folders = [
    p for p in multiroot_workspace.iterdir()
    if p.is_dir() and (p / ".vscode" / "settings.json").exists()
]

tag_by_folder = {}
for folder in workspace_folders:
    settings_path = folder / ".vscode" / "settings.json"
    try:
        with settings_path.open(encoding="utf-8") as fp:
            settings = json.load(fp)
        tag = settings.get("docker_tag")
        if tag:
            tag_by_folder[folder.name] = tag
    except (OSError, json.JSONDecodeError) as e:
        print(f"Warning: Could not read {settings_path}: {e}")

merged = {"services": {}}
for folder in workspace_folders:
    compose_file = folder / "docker-compose.yml"
    if not compose_file.exists():
        continue

    try:
        with compose_file.open(encoding="utf-8") as fp:
            data = yaml.safe_load(fp)

        if not data or "services" not in data:
            continue

        for name, svc in data["services"].items():
            # Remove build.dockerfile if present
            if "build" in svc and isinstance(svc["build"], dict) and "dockerfile" in svc["build"]:
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

    except (OSError, yaml.YAMLError) as e:
        print(f"Error parsing {compose_file}: {e}")

merged_path = multiroot_workspace / "docker-compose.yml"
try:
    with merged_path.open("w", encoding="utf-8") as fp:
        yaml.dump(merged, fp, default_flow_style=False)
    print(f"Merged Docker Compose written to: {merged_path}")
except (OSError, yaml.YAMLError) as e:
    print(f"Failed to write merged compose: {e}")

