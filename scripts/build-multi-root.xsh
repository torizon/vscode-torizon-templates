# Copyright (c) 2025 Toradex
# SPDX-License-Identifier: MIT

##
# This script is used to build or update the multi-root files.
##

$UPDATE_OS_ENVIRON = True
$XONSH_SHOW_TRACEBACK = True
$XONSH_SUBPROC_CMD_RAISE_ERROR = True

import os
import shutil
from pathlib import Path
import json
import yaml
import subprocess

args = $ARGS
home = Path.home()
location_folder_join = Path(args[1])
obj_rec = json.loads(args[2])
project_name = obj_rec["Name"]
project_folder = location_folder_join

ENV_MERGE_MAP = {
    "create-image-production-all": {
        "env_name": "DOCKER_TAG",
        "env_value": "docker_tag"
    }
}

# Compose path
compose_path = project_folder / "docker-compose.yml"
compose_template_path = home / ".apollox" / "empty" / "docker-compose.yml"

# Only create docker-compose.yml if it doesn't exist
if not compose_path.exists():
    shutil.copy2(compose_template_path, compose_path)

# Workspace file
workspace_file = project_folder / f"{project_name}.code-workspace"
if not workspace_file.exists():
    workspace_file_orig = project_folder / "multiRoot.code-workspace"
    if workspace_file_orig.exists():
        workspace_file_orig.rename(workspace_file)

with open(workspace_file, "r") as f:
    code_workspace = json.load(f)

# Reset folders and compounds
code_workspace["folders"] = []
code_workspace["launch"]["compounds"][0]["configurations"] = []
code_workspace["launch"]["compounds"][1]["configurations"] = []
code_workspace["settings"]["files.exclude"] = {}

# Load and reset compose YAML
with open(compose_path, "r") as f:
    compose_yaml = yaml.safe_load(f) or {}
compose_yaml["services"] = {}

factor = 0
port_keys = [
    "torizon_debug_port",
    "torizon_debug_ssh_port",
    "torizon_debug_port2",
    "torizon_debug_port3"
]

# Add project templates
for template in obj_rec["Projects"]:
    template_name = template["Name"]

    code_workspace["folders"].append({
        "path": f"{'.' if project_name == template_name else template_name}"
    })

    if template_name != project_name:
        code_workspace["settings"].setdefault("files.exclude", {})[template_name] = True

    if template_name != project_name:
        code_workspace["launch"]["compounds"][0]["configurations"].append({
            "folder": template_name,
            "name": "Torizon arm64"
        })
        code_workspace["launch"]["compounds"][1]["configurations"].append({
            "folder": template_name,
            "name": "Torizon arm32"
        })

    settings_path = location_folder_join / template_name / ".vscode" / "settings.json"
    if settings_path.exists():
        with open(settings_path, "r") as f:
            settings_json = json.load(f)

        settings_json.pop("torizon_workspace", None)

        if "wait_sync" in settings_json:
            try:
                ws = int(settings_json["wait_sync"])
                settings_json["wait_sync"] = str(ws + factor)
                factor += 1
            except ValueError:
                pass

        with open(settings_path, "w") as f:
            json.dump(settings_json, f, indent=4)

    # Merge extensions recommendations
    extensions_path = location_folder_join / template_name / ".vscode" / "extensions.json"
    if extensions_path.exists():
        with open(extensions_path, "r") as f:
            extensions_json = json.load(f)

        ws_ext = code_workspace.setdefault("extensions", {})
        for key in ["recommendations", "unwantedRecommendations"]:
            if key in extensions_json and isinstance(extensions_json[key], list):
                ws_ext.setdefault(key, [])
                for ext in extensions_json[key]:
                    if ext not in ws_ext[key]:
                        ws_ext[key].append(ext)

    # Merge services
    template_compose_path = location_folder_join / template_name / "docker-compose.yml"
    if template_compose_path.exists():
        with open(template_compose_path, "r") as f:
            compose_item_yaml = yaml.safe_load(f) or {}
        services = compose_item_yaml.get("services") or {}
        for service, config in services.items():
            if "build" in config and "dockerfile" in config["build"]:
                del config["build"]
            compose_yaml["services"][service] = config

# Replace ${workspaceFolder} placeholders in task args and cwd with ${workspaceFolder:project_name}
for task in code_workspace.get("tasks", {}).get("tasks", []):
    if "args" in task:
        task["args"] = [
            arg.replace("${workspaceFolder}", f"${{workspaceFolder:{project_name}}}")
            if isinstance(arg, str) else arg
            for arg in task["args"]
        ]
    if "options" in task and isinstance(task["options"], dict):
        cwd = task["options"].get("cwd")
        if isinstance(cwd, str):
            task["options"]["cwd"] = cwd.replace("${workspaceFolder}", f"${{workspaceFolder:{project_name}}}")

    label = task["label"]
    if label in ENV_MERGE_MAP:
        env_info = ENV_MERGE_MAP[label]
        env_name = env_info["env_name"]
        env_value = env_info["env_value"]

        for template in obj_rec["Projects"]:
            template_name = template["Name"]
            if template_name != project_name:
                if "env" not in task["options"] or not isinstance(task["options"]["env"], dict):
                    task["options"]["env"] = {}
                task["options"]["env"][f"{env_name}_{template_name}"] = f"${{command:{env_value}.{template_name}}}"

# Save updated files
with open(compose_path, "w") as f:
    yaml.dump(compose_yaml, f)

with open(workspace_file, "w") as f:
    json.dump(code_workspace, f, indent=4)

# Run conflict check
cmd = f'xonsh "{project_folder}/.conf/check-single-projects-conflicts.xsh" {project_folder} -acceptAll 1'
subprocess.run(cmd, shell=True)
