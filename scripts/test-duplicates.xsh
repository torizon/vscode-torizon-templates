#!/usr/bin/env xonsh

# Copyright (c) 2025 Toradex
# SPDX-License-Identifier: MIT

##
# This script is used to verify the sanity of the CI environment.
# Is useful to show to the user the env that should be set
# and fail fast if something is missing.
##

# use the xonsh environment to update the OS environment
$UPDATE_OS_ENVIRON = True
# Get the full log of error
$XONSH_SHOW_TRACEBACK = True
# this script should handle the subprocess errors
$RAISE_SUBPROC_ERROR = False

import os
import json
from pathlib import Path
import sys

def load_json(path):
    try:
        with open(path, "r") as f:
            return json.load(f)
    except FileNotFoundError:
        return None

def is_duplicate_task(task_a, task_b):
    return (
        (
            task_a.get("command") == task_b.get("command") and
            task_a.get("type") == task_b.get("type") and
            task_a.get("args") == task_b.get("args") and
            task_a.get("dependsOn") == task_b.get("dependsOn") and
            task_a.get("options", {}).get("env", {}) == task_b.get("options", {}).get("env", {})
        ) or
        task_a.get("label") == task_b.get("label")
    )

def is_duplicate_input(input_a, input_b):
    return input_a.get("id") == input_b.get("id")

def find_duplicates(project_tasks, common_tasks, dup_func, exceptions, project_name=None, project_whitelist=None):
    duplicates = []
    for task in project_tasks:
        if any(dup_func(task, common_task) for common_task in common_tasks):
            label = task.get("label")

            if label in exceptions:
                continue

            if project_whitelist and project_name in project_whitelist:
                if label in project_whitelist[project_name]:
                    continue

            duplicates.append(task)
    return duplicates

def main():
    root_dir = Path(__file__).resolve().parent.parent
    assets_dir = root_dir / "assets" / "tasks"
    print(root_dir, assets_dir)

    common_tasks_data = load_json(assets_dir / "common.json")
    common_inputs_data = load_json(assets_dir / "inputs.json")
    if not common_tasks_data or not common_inputs_data:
        print("Missing common tasks or inputs JSON. Exiting.")
        return

    common_tasks = common_tasks_data.get("tasks", [])
    common_inputs = common_inputs_data.get("inputs", [])

    # Global task exceptions (apply to all projects)
    global_task_exceptions = [
        "template-specific-initial-task",
        "template-specific-final-task",
    ]

    # Per-project task whitelist
    project_task_whitelist = {
        "tcb": ["validate-pipeline-settings"],
    }

    input_exceptions = []

    for folder in root_dir.iterdir():
        if folder.is_dir():
            vscode_dir = folder / ".vscode"
            tasks_path = vscode_dir / "tasks.json"
            if not tasks_path.exists():
                continue

            project_data = load_json(tasks_path)
            if not project_data:
                continue

            project_tasks = project_data.get("tasks", [])
            project_inputs = project_data.get("inputs", [])

            dup_tasks = find_duplicates(
                project_tasks,
                common_tasks,
                is_duplicate_task,
                global_task_exceptions,
                project_name=folder.name,
                project_whitelist=project_task_whitelist,
            )

            dup_inputs = find_duplicates(
                project_inputs,
                common_inputs,
                is_duplicate_input,
                input_exceptions,
            )

            if dup_tasks or dup_inputs:
                print(f"\n🔁 Duplicates in project: {folder.name}")
                for t in dup_tasks:
                    print(f" 🧱 Task: {t.get('label')}")
                for i in dup_inputs:
                    print(f" 🔧 Input: {i.get('id')}")
                sys.exit(-1)

    print("\n🏁 Done processing all folders.")
    sys.exit(0)

if __name__ == "__main__":
    main()
