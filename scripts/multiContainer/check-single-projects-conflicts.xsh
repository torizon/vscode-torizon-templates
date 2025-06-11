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
from pathlib import Path
from collections import defaultdict
from torizon_templates_utils.colors import print, Color

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
    env_dict = content.get("containers.environment", {})

    for key, val in env_dict.items():
        if val and val.isdigit():
            ports.append({
                "settingName": key,
                "settingValue": int(val),
                "name": "settings.json containers.environment",
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
    # Group ports by base service name (e.g., qt, py) or settings.json entries separately
    by_base_service = defaultdict(list)
    settings_ports = []

    def get_base_service(p):
        return base_service_name(p.get("service", "")) if "service" in p else None

    for p in all_ports:
        base = get_base_service(p)
        if base:
            by_base_service[base].append(p)
        else:
            settings_ports.append(p)

    # Build groups: each group is a base service or settings.json ports (each settings port alone)
    port_groups = []
    for base, ports in by_base_service.items():
        port_groups.append({
            "type": "base_service",
            "base": base,
            "ports": ports,
            "values": set(p["settingValue"] for p in ports),
        })
    for sp in settings_ports:
        port_groups.append({
            "type": "settings",
            "base": None,
            "ports": [sp],
            "values": {sp["settingValue"]},
        })

    n = len(port_groups)

    # Detect conflicting port values across different groups
    # Ignore conflicts *within* the same base service group — only cross-group conflicts matter
    conflicts = []
    for i in range(n):
        for j in range(i + 1, n):
            g1 = port_groups[i]
            g2 = port_groups[j]
            # Skip same base service group
            if g1["base"] is not None and g1["base"] == g2["base"]:
                continue
            # Check intersection of port values
            overlap = g1["values"].intersection(g2["values"])
            if overlap:
                conflicts.append((i, j, overlap))

    if not conflicts:
        print("✅ No port conflicts detected across docker-compose and settings.json ports.", color=Color.GREEN)
        return all_ports, []

    # Collect all conflicting ports across all conflicts (to know where to start reassignment)
    conflicting_ports = set()
    groups_to_fix = set()
    for i, j, overlap in conflicts:
        conflicting_ports.update(overlap)
        groups_to_fix.add(i)
        groups_to_fix.add(j)

    min_conflict_port = min(conflicting_ports)

    # Assign new ports for groups that must be fixed
    # For each group, assign new ports *per port value* distinctively
    # For base service groups, assign each distinct port a unique new port (to keep ports distinct within the group)
    # For settings groups (single port), assign that port one new port

    assigned_ports = set(p["settingValue"] for p in all_ports)
    assigned_ports = assigned_ports.difference(conflicting_ports)  # free up conflicting ports for reassignment
    next_port = min_conflict_port

    group_port_new_port_map = {}

    for idx in groups_to_fix:
        group = port_groups[idx]
        old_values = sorted(group["values"])
        new_port_map = {}
        for old_val in old_values:
            # If old_val not conflicting, keep it
            if old_val not in conflicting_ports:
                new_port_map[old_val] = old_val
                continue

            # Find next free port
            while next_port in assigned_ports or next_port in conflicting_ports:
                next_port += 1
            new_port_map[old_val] = next_port
            assigned_ports.add(next_port)
            next_port += 1

        group_port_new_port_map[idx] = new_port_map

    # Now generate the suggestions per individual port entry
    suggestions = []
    for idx, new_port_map in group_port_new_port_map.items():
        group = port_groups[idx]
        for p in group["ports"]:
            old_val = p["settingValue"]
            new_val = new_port_map.get(old_val, old_val)
            if old_val != new_val:
                suggestions.append((p, old_val, new_val))

    # Print summary of conflicts and suggestions
    for idx, new_port_map in group_port_new_port_map.items():
        group = port_groups[idx]
        base = group["base"] or "settings.json containers.environment"
        ports_desc = ", ".join(f"{p['settingName']}{' (' + p.get('service','') + ')' if 'service' in p else ''}: {p['settingValue']}" for p in group["ports"])
        changes_desc = ", ".join(f"{old} -> {new_port_map[old]}" for old in sorted(new_port_map) if old != new_port_map[old])
        print(f"⚠️ Port conflict for base '{base}' with ports {ports_desc}. Suggested changes: {changes_desc}", color=Color.YELLOW)

    return all_ports, suggestions

    by_base_service = defaultdict(list)
    settings_ports = []

    def get_base_service(p):
        return base_service_name(p.get("service", "")) if "service" in p else None

    for p in all_ports:
        base = get_base_service(p)
        if base:
            by_base_service[base].append(p)
        else:
            settings_ports.append(p)

    port_groups = []
    for base, ports in by_base_service.items():
        port_groups.append({
            "type": "base_service",
            "base": base,
            "ports": ports,
            "values": set(p["settingValue"] for p in ports),
        })
    for sp in settings_ports:
        port_groups.append({
            "type": "settings",
            "base": None,
            "ports": [sp],
            "values": {sp["settingValue"]},
        })

    n = len(port_groups)
    changed_groups = set()
    for i in range(n):
        for j in range(i+1, n):
            g1 = port_groups[i]
            g2 = port_groups[j]
            if g1["base"] is not None and g1["base"] == g2["base"]:
                continue
            if g1["values"].intersection(g2["values"]):
                changed_groups.add(i)
                changed_groups.add(j)

    if not changed_groups:
        print("✅ No port conflicts detected across docker-compose and settings.json ports.", color=Color.GREEN)
        return all_ports, []

    used_ports = set()
    for group in port_groups:
        used_ports.update(group["values"])

    max_port = max(used_ports) if used_ports else 5000
    assigned_ports = set(used_ports)
    group_new_port_map = {}

    for idx in changed_groups:
        new_port = max_port + 1
        while new_port in assigned_ports:
            new_port += 1
        max_port = new_port
        assigned_ports.add(new_port)
        group_new_port_map[idx] = new_port

    suggestions = []
    for idx, new_port in group_new_port_map.items():
        group = port_groups[idx]
        for p in group["ports"]:
            old_val = p["settingValue"]
            if old_val != new_port:
                suggestions.append((p, old_val, new_port))

    for idx, new_port in group_new_port_map.items():
        group = port_groups[idx]
        base = group["base"] or "settings.json containers.environment"
        ports_desc = ", ".join(f"{p['settingName']}{' (' + p.get('service','') + ')' if 'service' in p else ''}: {p['settingValue']}" for p in group["ports"])
        print(f"⚠️ Port conflict for base '{base}' with ports {ports_desc}. Suggested new port: {new_port}", color=Color.YELLOW)

    return all_ports, suggestions

def apply_suggestions(suggestions):
    files_to_update = defaultdict(lambda: {"type": None, "content": None, "changes": []})

    for p, old_val, new_val in suggestions:
        path = p["path"]
        if files_to_update[path]["content"] is None:
            if path.endswith('.json'):
                with open(path, 'r') as f:
                    files_to_update[path]["content"] = json.load(f)
                    files_to_update[path]["type"] = "json"
            else:
                with open(path, 'r') as f:
                    files_to_update[path]["content"] = yaml.safe_load(f)
                    files_to_update[path]["type"] = "yaml"

        files_to_update[path]["changes"].append((p, old_val, new_val))

    for path, info in files_to_update.items():
        content = info["content"]
        if info["type"] == "json":
            for p, old_val, new_val in info["changes"]:
                key = p["settingName"]
                if "containers.environment" in content and key in content["containers.environment"]:
                    content["containers.environment"][key] = str(new_val)

            with open(path, 'w') as f:
                json.dump(content, f, indent=4)
            print(f"Applied changes to {path}", color=Color.GREEN)

        elif info["type"] == "yaml":
            for p, old_val, new_val in info["changes"]:
                service = p["service"]
                port_key = p["settingName"]
                idx = int(port_key.replace("ports[", "").replace("]", ""))
                old_port_str = p["service_ports"][idx]
                parts = old_port_str.split(":")
                if len(parts) == 2:
                    parts[0] = str(new_val)
                    new_port_str = ":".join(parts)
                    p["service_ports"][idx] = new_port_str
                else:
                    p["service_ports"][idx] = f"{new_val}:{new_val}"
            
                content["services"][service]["ports"][idx] = new_port_str

            with open(path, 'w') as f:
                yaml.dump(content, f, sort_keys=False)
            print(f"Applied changes to {path}", color=Color.GREEN)

def ask_and_apply_suggestions(suggestions):
    if not suggestions:
        print("No suggestions to apply.", color=Color.GREEN)
        return

    print("\nSuggested port changes:", color=Color.YELLOW)
    for p, old_val, new_val in suggestions:
        folder = p.get("folder", "?")
        service = p.get("service") or "settings.json"
        setting_name = p["settingName"]
        print(f"- {folder} / {service} / {setting_name} : {old_val} -> {new_val}", color=Color.YELLOW)

    ans = input("Apply these changes? (y/N): ").strip().lower()
    if ans == 'y':
        apply_suggestions(suggestions)
    else:
        print("No changes applied.", color=Color.YELLOW)

def main():
    root_path = Path.cwd()
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
    ask_and_apply_suggestions(suggestions)

if __name__ == "__main__":
    main()

