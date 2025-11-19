#!/usr/bin/env xonsh

# Copyright (c) 2025 Toradex
# SPDX-License-Identifier: MIT

# This script runs the given tasks in all workspaces

$UPDATE_OS_ENVIRON = True
$XONSH_SHOW_TRACEBACK = True
$RAISE_SUBPROC_ERROR = True

import os
import subprocess
from pathlib import Path

# Validate arguments
args = $ARGS
if len(args) < 2:
    print("Usage: xonsh multi-root-tasks.xsh [<task1> <task2> ...]")
    exit(1)

task_names = args[1:]

script_dir = Path(__file__).resolve().parent
# Traverse two levels up to locate the top-level directory containing all workspaces.
top_level = script_dir.parent.parent
original_dir = Path.cwd()

for workspace in top_level.iterdir():
    if not workspace.is_dir() or workspace.name.startswith("."):
        continue

    tasks_xsh = workspace / ".vscode" / "tasks.xsh"
    if not tasks_xsh.exists():
        print(f"[Skipping: No tasks.xsh in {workspace}]")
        continue

    for task_name in task_names:
        print(f"\n[Running task '{task_name}' in workspace: {workspace.name}]")
        try:
            os.chdir(workspace)
            subprocess.run(
                ["xonsh", ".vscode/tasks.xsh", "run", task_name],
                check=True
            )
        except subprocess.CalledProcessError as e:
            print(f"[Task '{task_name}' failed in {workspace.name} with exit code {e.returncode}]")
        finally:
            os.chdir(original_dir)

