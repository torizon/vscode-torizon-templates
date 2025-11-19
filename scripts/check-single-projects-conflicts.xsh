#!/usr/bin/env xonsh

# Copyright (c) 2025 Toradex
# SPDX-License-Identifier: MIT

##
# This script is used to check for port conflicts across the project.
##

# use the xonsh environment to update the OS environment
$UPDATE_OS_ENVIRON = True
# Get the full log of error
$XONSH_SHOW_TRACEBACK = True
# this script should handle the subprocess errors
$RAISE_SUBPROC_ERROR = False

import os
import yaml
import json
import subprocess
from pathlib import Path
from collections import defaultdict
from torizon_templates_utils.colors import print, Color

TORIZON_TO_CONTAINER_PORT_MAP = {
    "torizon_debug_ssh_port": "DEBUG_SSH_PORT",
    "torizon_debug_port1": "DEBUG_PORT1",
    "torizon_debug_port2": "DEBUG_PORT2",
    "torizon_debug_port3": "DEBUG_PORT3",
}
# Extracts the base service name by removing common suffixes.
def base_service_name(service_name):
    for suffix in ['-debug', '-dev', '-test']:
        if service_name.endswith(suffix):
            return service_name[: -len(suffix)]
    return service_name

def parse_ports_from_docker_compose(docker_compose_path, workspace_folder_name):
    with open(docker_compose_path, 'r') as f:
        content = yaml.safe_load(f)

    ports = []
    for service_name, service_value in content.get('services', {}).items():
        svc_ports = service_value.get('ports', [])
        for idx, port_mapping in enumerate(svc_ports):
            if isinstance(port_mapping, str):
                host_port = port_mapping.split(":")[0].strip()
                if host_port.isdigit():
                    ports.append({
                        "settingName": f"ports[{idx}]",
                        "settingValue": int(host_port),
                        "name": f"docker-compose port",
                        "service": service_name,
                        "folder": workspace_folder_name,
                        "path": docker_compose_path,
                        "full_content": content,
                        "service_ports": svc_ports,
                    })
    return ports

def parse_containers_environment_from_settings(settings_path, workspace_folder_name):
    with open(settings_path, 'r') as f:
        content = json.load(f)

    ports = []
    containers_env = content.get("containers.environment", {})

    for torizon_key, container_key in TORIZON_TO_CONTAINER_PORT_MAP.items():
        torizon_val = content.get(torizon_key)
        container_val = containers_env.get(container_key)
        if torizon_val or container_val:
            torizon_val = torizon_val or container_val
            if torizon_val and str(torizon_val).isdigit():
                ports.append({
                    "settingName": torizon_key,
                    "settingValue": int(torizon_val),
                    "name": "settings.json torizon_debug_port",
                    "folder": workspace_folder_name,
                    "path": settings_path,
                    "full_content": content,
                })
    return ports

def gather_all_ports(workspace_folders):
    all_ports = []

    for wf in workspace_folders:
        for fname in ["docker-compose.yml", "docker-compose.yaml"]:
            dc_path = wf / fname
            if dc_path.is_file():
                all_ports.extend(parse_ports_from_docker_compose(str(dc_path), wf.name))

        settings_path = wf / ".vscode" / "settings.json"
        if settings_path.is_file():
            all_ports.extend(parse_containers_environment_from_settings(str(settings_path), wf.name))

    return all_ports

def suggest_fixes_for_all_ports(all_ports):
    port_usage = defaultdict(list)
    for p in all_ports:
        val = p["settingValue"]
        port_usage[val].append(p)

    # Group ports by unique identifier to treat variants as one unit
    # For docker-compose: base service name (my_project, my_project-debug -> my_project)
    # For settings.json: folder + setting name (each setting is separate)
    base_service_groups = defaultdict(lambda: defaultdict(list))
    for port, plist in port_usage.items():
        for p in plist:
            service = p.get("service", "")
            folder = p.get("folder", "")
            setting_name = p.get("settingName", "")
            
            if service:
                # Docker-compose service: group by base service name
                base = base_service_name(service)
                identifier = f"{folder}:{base}"
            else:
                # Settings.json: each setting is separate
                identifier = f"{folder}:{setting_name}"
            
            base_service_groups[port][identifier].append(p)

    # Find real conflicts (same port, different identifiers)
    real_conflicts = {}
    for port, base_groups in base_service_groups.items():
        if len(base_groups) > 1:
            # Multiple different identifiers using the same port = conflict
            real_conflicts[port] = base_groups

    if not real_conflicts:
        print("✅ No conflicts found among torizon_debug_* ports.", color=Color.GREEN)
        return all_ports, []

    used_ports = set(port_usage.keys())

    suggestions = []

    for port, base_groups in real_conflicts.items():
        base_list = list(base_groups.items())
        # Keep the first identifier at the original port, reassign the rest
        next_port = port + 1
        for identifier, ports_list in base_list[1:]:
            while next_port in used_ports:
                next_port += 1
            # Add ALL variants (base + debug) to suggestions
            for p in ports_list:
                suggestions.append((p, port, next_port))
            used_ports.add(next_port)
            next_port += 1

    for port, base_groups in real_conflicts.items():
        involved = ", ".join(base_groups.keys())
        print(f"⚠️ Port {port} conflict across: {involved}", color=Color.YELLOW)

    for p, old, new in suggestions:
        service = p.get('service', 'settings')
        print(f"Suggested fix for {p['folder']} / {service} / {p['settingName']}: {old} → {new}", color=Color.YELLOW)

    return all_ports, suggestions

def apply_suggestions(suggestions, root_path):
    files_to_update = defaultdict(lambda: {"content": None, "format": None, "changes": []})

    for p, old_val, new_val in suggestions:
        path = p["path"]
        if files_to_update[path]["content"] is None:
            with open(path, 'r') as f:
                if path.endswith('.yml') or path.endswith('.yaml'):
                    files_to_update[path]["content"] = yaml.safe_load(f)
                    files_to_update[path]["format"] = "yaml"
                else:
                    files_to_update[path]["content"] = json.load(f)
                    files_to_update[path]["format"] = "json"
        files_to_update[path]["changes"].append((p, old_val, new_val))

    for path, info in files_to_update.items():
        content = info["content"]
        file_format = info["format"]

        if file_format == "json":
            # Handle settings.json files
            containers_env = content.setdefault("containers.environment", {})

            for p, old_val, new_val in info["changes"]:
                torizon_key = p["settingName"]
                container_key = TORIZON_TO_CONTAINER_PORT_MAP.get(torizon_key)
                # update torizon port
                content[torizon_key] = str(new_val)
                # update matching container port
                if container_key:
                    containers_env[container_key] = str(new_val)

            with open(path, 'w') as f:
                json.dump(content, f, indent=4)

        else:
            # Handle docker-compose.yml files
            services = content.get("services", {})

            for p, old_val, new_val in info["changes"]:
                service_name = p.get("service")
                setting_name = p.get("settingName", "")
                
                if not service_name or service_name not in services:
                    continue

                # Extract index from "ports[N]"
                if setting_name.startswith("ports[") and setting_name.endswith("]"):
                    try:
                        idx = int(setting_name[6:-1])
                    except Exception:
                        continue

                    svc_ports = services[service_name].get("ports", [])
                    if 0 <= idx < len(svc_ports):
                        port_mapping = svc_ports[idx]
                        
                        if isinstance(port_mapping, str):
                            # Handle "host:container" format
                            parts = port_mapping.split(":", 1)
                            if len(parts) == 2:
                                parts[0] = str(new_val)
                                svc_ports[idx] = ":".join(parts)
                            else:
                                svc_ports[idx] = str(new_val)
                        elif isinstance(port_mapping, dict):
                            # Handle long syntax with "published" key
                            port_mapping["published"] = int(new_val)
                            svc_ports[idx] = port_mapping

                        services[service_name]["ports"] = svc_ports

            with open(path, 'w') as f:
                yaml.safe_dump(content, f, sort_keys=False)

        print(f"✅ Applied changes to {path}", color=Color.GREEN)

    # Run merge docker compose script again
    cmd = f'xonsh "{root_path}/.conf/merge-docker-compose.xsh" {root_path}'
    result = subprocess.run(cmd, shell=True)
    if result.returncode != 0:
        print('Warning: merge-docker-compose failed', color=Color.YELLOW)

def ask_and_apply_suggestions(suggestions, prompt_user: bool, root_path):
    if not suggestions:
        print("No suggestions to apply.", color=Color.GREEN)
        return

    print("\nSuggested port changes:", color=Color.YELLOW)
    for p, old_val, new_val in suggestions:
        folder = p.get("folder", "?")
        service = p.get("service") or "settings.json"
        setting_name = p["settingName"]
        print(f"- {folder} / {service} / {setting_name} : {old_val} -> {new_val}", color=Color.YELLOW)

    if prompt_user:
        ans = input("Apply these changes? (y/N): ").strip().lower()
        if ans == 'y':
            apply_suggestions(suggestions)
        else:
            print("No changes applied.", color=Color.YELLOW)
    else:
        apply_suggestions(suggestions, root_path)

def main():
    args = $ARGS
    root_path = Path(args[1]).resolve()
    prompt_user = False if len(args) < 3 else args[2].lower() == "true"
    workspace_folders = []

    # Detect workspace folders (folders with docker-compose.yml or .vscode/settings.json)
    for entry in root_path.iterdir():
        if entry.is_dir():
            dc_yml = entry / "docker-compose.yml"
            dc_yaml = entry / "docker-compose.yaml"
            settings_json = entry / ".vscode" / "settings.json"
            if dc_yml.is_file() or dc_yaml.is_file() or settings_json.is_file():
                workspace_folders.append(entry)

    if not workspace_folders:
        print("No workspace folders with docker-compose or settings.json found.", color=Color.RED)
        return

    all_ports = gather_all_ports(workspace_folders)
    _, suggestions = suggest_fixes_for_all_ports(all_ports)
    ask_and_apply_suggestions(suggestions, prompt_user, root_path)

if __name__ == "__main__":
    main()
