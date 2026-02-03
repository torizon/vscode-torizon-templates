#!/usr/bin/env xonsh

# Copyright (c) 2025 Toradex
# SPDX-License-Identifier: MIT

# This script runs the given tasks in all workspaces

$UPDATE_OS_ENVIRON = True
$XONSH_SHOW_TRACEBACK = True
$RAISE_SUBPROC_ERROR = True

import os
import subprocess
import json
from pathlib import Path

# Validate arguments
args = $ARGS
if len(args) < 2:
    print("Usage: xonsh multi-root-tasks.xsh [<task1> <task2> ...]")
    exit(1)

task_names = args[1:]

script_dir = Path(__file__).resolve().parent
top_level = script_dir.parent
original_dir = Path.cwd()

def task_exists_in_workspace(workspace: Path, task_name: str) -> bool:
    tasks_json = workspace / ".vscode" / "tasks.json"
    if not tasks_json.exists():
        return False

    try:
        with open(tasks_json) as f:
            data = json.load(f)
    except json.JSONDecodeError:
        print(f"[Invalid JSON in {tasks_json}]")
        return False

    tasks = data.get("tasks", [])
    for task in tasks:
        if task.get("label") == task_name:
            return True

    return False

for workspace in top_level.iterdir():
    if not workspace.is_dir() or workspace.name.startswith("."):
        continue

    tasks_xsh = workspace / ".vscode" / "tasks.xsh"
    if not tasks_xsh.exists():
        print(f"[Skipping: No tasks.xsh in {workspace}]")
        continue

    for task_name in task_names:
        if not task_exists_in_workspace(workspace, task_name):
            print(f"[Skipping: Task '{task_name}' not found in {workspace.name}]")
            continue

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

