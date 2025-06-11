#!/usr/bin/env xonsh

# Copyright (c) 2025 Toradex
# SPDX-License-Identifier: MIT

# This script builds the multiroot docker-compose.prod.yml by combining
# each workspace's docker-compose.prod.yml, after generating each
# through their own create-docker-compose-production task.

$UPDATE_OS_ENVIRON = True
$XONSH_SHOW_TRACEBACK = True
$RAISE_SUBPROC_ERROR = True

import yaml
import asyncio
import json
from pathlib import Path
from torizon_templates_utils.colors import Color, print
from torizon_templates_utils.errors import Error_Out, Error

args = $ARGS
workspace_root = Path(args[1]).resolve()

print(f"Workspace root: {workspace_root}", color=Color.YELLOW)
workspace_file = next(workspace_root.glob("*.code-workspace"), None)

if not workspace_file:
    Error_Out("No .code-workspace file found in root", Error.ENOFOUND)

with open(workspace_file) as f:
    workspace_config = json.load(f)

folders = [Path(folder["path"]) for folder in workspace_config.get("folders", [])]
folders.pop(0)

async def main():
    final_compose = {"services": {}}

    for folder in folders:
        compose_path = workspace_root / folder / "docker-compose.prod.yml"
        if not compose_path.exists():
            Error_Out(f"Missing production compose file in {folder}", Error.ENOFOUND)
        with open(compose_path) as f:
            part = yaml.safe_load(f)
            final_compose["services"].update(part.get("services", {}))

    out_file = workspace_root / "docker-compose.prod.yml"
    with open(out_file, "w") as f:
        yaml.dump(final_compose, f, indent=2)

    print(f"Combined docker-compose.prod.yml written to {out_file}", color=Color.GREEN)

asyncio.run(main())

