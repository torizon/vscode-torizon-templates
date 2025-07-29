#!/usr/bin/env xonsh
"""
test-duplicates.xsh: Verify CI env sanity by checking for duplicate tasks/inputs
across projects vs common definitions.
"""
# pylint: disable=invalid-name

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

import json
from pathlib import Path
import sys


def load_json(path: Path):
    """Load and return JSON content from path, or None if file is missing."""
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except FileNotFoundError:
        return None


def is_duplicate_task(task_a: dict, task_b: dict) -> bool:
    """Return True if two task dicts are considered duplicates."""
    return (
        (
            task_a.get("command") == task_b.get("command")
            and task_a.get("type") == task_b.get("type")
            and task_a.get("args") == task_b.get("args")
            and task_a.get("dependsOn") == task_b.get("dependsOn")
            and task_a.get("options", {}).get("env", {})
            == task_b.get("options", {}).get("env", {})
        )
        or task_a.get("label") == task_b.get("label")
    )


def is_duplicate_input(input_a: dict, input_b: dict) -> bool:
    """Return True if two input dicts are considered duplicates."""
    return input_a.get("id") == input_b.get("id")


def find_duplicates(project_items: list, common_items: list, dup_func, exceptions: list) -> list:
    """Find items in project_items that duplicate any item in common_items, excluding exceptions."""
    duplicates = []
    for item in project_items:
        if any(dup_func(item, common_item) for common_item in common_items):
            if item.get("label") not in exceptions:
                duplicates.append(item)
    return duplicates


def _process_folder(
    folder: Path,
    common_tasks: list,
    common_inputs: list,
    task_exceptions: list,
    input_exceptions: list,
):
    """Return (duplicate_tasks, duplicate_inputs) for the given folder."""
    vscode_dir = folder / ".vscode"
    tasks_path = vscode_dir / "tasks.json"
    if not tasks_path.exists():
        return [], []

    project_data = load_json(tasks_path)
    if not project_data:
        return [], []

    project_tasks = project_data.get("tasks", [])
    project_inputs = project_data.get("inputs", [])

    dup_tasks = find_duplicates(project_tasks, common_tasks, is_duplicate_task, task_exceptions)
    # pylint: disable=line-too-long
    dup_inputs = find_duplicates(project_inputs, common_inputs, is_duplicate_input, input_exceptions)
    return dup_tasks, dup_inputs


def main():
    """Entry point: walk folders, report duplicates, and set exit code."""
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

    task_exceptions = ["template-specific-initial-task", "template-specific-final-task"]
    input_exceptions: list = []

    for folder in root_dir.iterdir():
        if not folder.is_dir():
            continue

        dup_tasks, dup_inputs = _process_folder(
            folder, common_tasks, common_inputs, task_exceptions, input_exceptions
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

