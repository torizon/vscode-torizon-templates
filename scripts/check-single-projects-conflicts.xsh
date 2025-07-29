#!/usr/bin/env xonsh
"""
check-single-projects-conflicts.xsh:
Scan workspaces for port conflicts across docker-compose and .vscode/settings.json
and suggest/apply non-overlapping ports.
"""

# use the xonsh environment to update the OS environment
$UPDATE_OS_ENVIRON = True
# Get the full log of error
$XONSH_SHOW_TRACEBACK = True
# this script should handle the subprocess errors
$RAISE_SUBPROC_ERROR = False

import yaml
import json
from pathlib import Path
from collections import defaultdict
from torizon_templates_utils.colors import Color

def base_service_name(service_name):
    """Trim common suffixes so debug/dev/test services share a base name."""
    for suffix in ['-debug', '-dev', '-test']:
        if service_name.endswith(suffix):
            return service_name[: -len(suffix)]
    return service_name

def parse_ports_from_docker_compose(docker_compose_path, workspace_folder_name):
    """Return list of dicts describing host ports exposed by services in compose."""
    with open(docker_compose_path, "r", encoding="utf-8") as f:
        content = yaml.safe_load(f) or {}

    results = []
    for service_name, service_value in (content.get("services") or {}).items():
        svc_ports = service_value.get("ports") or []
        for idx, port_mapping in enumerate(svc_ports):
            # Only handle "HOST:CONTAINER" style strings for now
            if isinstance(port_mapping, str):
                host_part = port_mapping.split(":", 1)[0].strip()
                if host_part.isdigit():
                    results.append({
                        "settingName": f"ports[{idx}]",
                        "settingValue": int(host_part),
                        "name": "docker-compose port",
                        "service": service_name,
                        "folder": workspace_folder_name,
                        "path": docker_compose_path,
                        "full_content": content,
                        "service_ports": svc_ports,
                    })
    return results

def parse_containers_environment_from_settings(settings_path, workspace_folder_name):
    """Return list of dicts describing numeric env ports from settings.json."""
    with open(settings_path, "r", encoding="utf-8") as f:
        content = json.load(f)

    ports = []
    env_dict = content.get("containers.environment", {}) or {}

    for key, val in env_dict.items():
        # accept "1234" or 1234
        if isinstance(val, int):
            ports.append({
                "settingName": key,
                "settingValue": int(val),
                "name": "settings.json containers.environment",
                "folder": workspace_folder_name,
                "path": settings_path,
                "full_content": content,
            })
        elif isinstance(val, str) and val.isdigit():
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
    """Collect all candidate host ports from compose and settings in each folder."""
    all_ports = []
    for wf in workspace_folders:
        for fname in ("docker-compose.yml", "docker-compose.yaml"):
            dc_path = wf / fname
            if dc_path.is_file():
                all_ports.extend(parse_ports_from_docker_compose(str(dc_path), wf.name))
        settings_path = wf / ".vscode" / "settings.json"
        if settings_path.is_file():
            all_ports.extend(parse_containers_environment_from_settings(str(settings_path), wf.name))
    return all_ports

def suggest_fixes_for_all_ports(all_ports):
    """
    Group ports by base service (qt/py/etc) and by single settings entries.
    Only flag conflicts across different groups. Propose the smallest available
    new ports that avoid clashes.
    """
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
    conflicts = []
    for i in range(n):
        for j in range(i + 1, n):
            g1 = port_groups[i]
            g2 = port_groups[j]
            # ignore conflicts within same base (debug/release variants)
            if g1["base"] is not None and g1["base"] == g2["base"]:
                continue
            overlap = g1["values"].intersection(g2["values"])
            if overlap:
                conflicts.append((i, j, overlap))

    if not conflicts:
        print("✅ No port conflicts detected across docker-compose and settings.json ports.", color=Color.GREEN)
        return all_ports, []

    conflicting_ports = set()
    groups_to_fix = set()
    for i, j, overlap in conflicts:
        conflicting_ports.update(overlap)
        groups_to_fix.add(i)
        groups_to_fix.add(j)

    min_conflict_port = min(conflicting_ports)
    assigned_ports = set(p["settingValue"] for p in all_ports)
    assigned_ports.difference_update(conflicting_ports)
    next_port = min_conflict_port

    group_port_new_port_map = {}
    for idx in groups_to_fix:
        group = port_groups[idx]
        new_port_map = {}
        for old_val in sorted(group["values"]):
            if old_val not in conflicting_ports:
                new_port_map[old_val] = old_val
                continue
            while next_port in assigned_ports or next_port in conflicting_ports:
                next_port += 1
            new_port_map[old_val] = next_port
            assigned_ports.add(next_port)
            next_port += 1
        group_port_new_port_map[idx] = new_port_map

    suggestions = []
    for idx, new_port_map in group_port_new_port_map.items():
        group = port_groups[idx]
        for p in group["ports"]:
            old_val = p["settingValue"]
            new_val = new_port_map.get(old_val, old_val)
            if old_val != new_val:
                suggestions.append((p, old_val, new_val))

    for idx, new_port_map in group_port_new_port_map.items():
        group = port_groups[idx]
        base = group["base"] or "settings.json containers.environment"
        ports_desc = ", ".join(
            f"{p['settingName']}{' (' + p.get('service','') + ')' if 'service' in p else ''}: {p['settingValue']}"
            for p in group["ports"]
        )
        changes_desc = ", ".join(
            f"{old} -> {new_port_map[old]}" for old in sorted(new_port_map) if old != new_port_map[old]
        )
        print(
            f"⚠️ Port conflict for base '{base}' with ports {ports_desc}. Suggested changes: {changes_desc}",
            color=Color.YELLOW,
        )
    return all_ports, suggestions

def apply_suggestions(suggestions):
    """Write the suggested port changes back to JSON/YAML files."""
    files_to_update = defaultdict(lambda: {"type": None, "content": None, "changes": []})

    for p, old_val, new_val in suggestions:
        path = p["path"]
        info = files_to_update[path]
        if info["content"] is None:
            if path.endswith(".json"):
                with open(path, "r", encoding="utf-8") as f:
                    info["content"] = json.load(f)
                info["type"] = "json"
            else:
                with open(path, "r", encoding="utf-8") as f:
                    info["content"] = yaml.safe_load(f)
                info["type"] = "yaml"
        info["changes"].append((p, old_val, new_val))

    for path, info in files_to_update.items():
        content = info["content"]
        if info["type"] == "json":
            for p, _, new_val in info["changes"]:
                key = p["settingName"]
                if "containers.environment" in content and key in content["containers.environment"]:
                    content["containers.environment"][key] = str(new_val)
            with open(path, "w", encoding="utf-8") as f:
                json.dump(content, f, indent=4)
            print(f"Applied changes to {path}", color=Color.GREEN)

        elif info["type"] == "yaml":
            for p, _, new_val in info["changes"]:
                service = p["service"]
                idx = int(p["settingName"].replace("ports[", "").replace("]", ""))
                old_port_str = p["service_ports"][idx]
                parts = old_port_str.split(":")
                if len(parts) == 2:
                    parts[0] = str(new_val)
                    new_port_str = ":".join(parts)
                else:
                    # fallback: mirror host->container
                    new_port_str = f"{new_val}:{new_val}"
                p["service_ports"][idx] = new_port_str
                content["services"][service]["ports"][idx] = new_port_str
            with open(path, "w", encoding="utf-8") as f:
                yaml.dump(content, f, sort_keys=False)
            print(f"Applied changes to {path}", color=Color.GREEN)

def ask_and_apply_suggestions(suggestions):
    """Prompt user to apply changes; write them if confirmed."""
    if not suggestions:
        print("No suggestions to apply.", color=Color.GREEN)
        return

    print("\nSuggested port changes:", color=Color.YELLOW)
    for p, old_val, new_val in suggestions:
        folder = p.get("folder", "?")
        service = p.get("service") or "settings.json"
        print(f"- {folder} / {service} / {p['settingName']} : {old_val} -> {new_val}", color=Color.YELLOW)

    ans = input("Apply these changes? (y/N): ").strip().lower()
    if ans == "y":
        apply_suggestions(suggestions)
    else:
        print("No changes applied.", color=Color.YELLOW)

def main():
    args = $ARGS
    if len(args) < 2:
        print("Usage: xonsh check-single-projects-conflicts.xsh <root-folder>", color=Color.YELLOW)
        return
    root_path = Path(args[1]).resolve()
    if not root_path.exists():
        print(f"Folder not found: {root_path}", color=Color.RED)
        return

    # Detect workspace folders (need compose and/or .vscode/settings.json)
    workspace_folders = []
    for entry in root_path.iterdir():
        if not entry.is_dir():
            continue
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

