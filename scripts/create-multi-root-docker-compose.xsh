#!/usr/bin/env xonsh
"""
create-multi-root-docker-compose.xsh: combine per-workspace docker-compose.prod.yml
files into a single docker-compose.prod.yml at the workspace root.
"""
# pylint: disable=invalid-name

import sys
import asyncio
import json
from pathlib import Path

import yaml
from torizon_templates_utils.colors import Color
from torizon_templates_utils.errors import Error_Out, Error  # pylint: disable=no-name-in-module

# Read workspace root from CLI
args = sys.argv
workspace_root = Path(args[1]).resolve() if len(args) > 1 else Path(".").resolve()

print(f"Workspace root: {workspace_root}", color=Color.YELLOW)

workspace_file = next(workspace_root.glob("*.code-workspace"), None)
if not workspace_file:
    Error_Out("No .code-workspace file found in root", Error.ENOFOUND)

with open(workspace_file, "r", encoding="utf-8") as wfp:
    workspace_config = json.load(wfp)

folders = [
    (workspace_root / Path(folder["path"])).resolve()
    for folder in workspace_config.get("folders", [])
]
# Exclude the root itself if it appears
folders = [f for f in folders if f != workspace_root]


async def main() -> None:
    """Merge services from each folder's docker-compose.prod.yml into one file."""
    final_compose = {"services": {}}

    for folder in folders:
        compose_path = folder / "docker-compose.prod.yml"
        if not compose_path.exists():
            Error_Out(f"Missing production compose file in {folder}", Error.ENOFOUND)

        with open(compose_path, "r", encoding="utf-8") as fp:
            part = yaml.safe_load(fp) or {}
            final_compose["services"].update(part.get("services", {}))

    out_file = workspace_root / "docker-compose.prod.yml"
    with open(out_file, "w", encoding="utf-8") as fp:
        yaml.dump(final_compose, fp, indent=2)

    print(f"Combined docker-compose.prod.yml written to {out_file}", color=Color.GREEN)


asyncio.run(main())

