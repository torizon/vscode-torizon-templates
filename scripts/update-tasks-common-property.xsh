#!/usr/bin/env xonsh
"""
Update a common property on every tasks.json/common.json found under the repo.
"""
# pylint: disable=invalid-name

# Copyright (c) 2025 Toradex
# SPDX-License-Identifier: MIT

##
# This script is used to update the common property in all the tasks.json files
##

# use the xonsh environment to update the OS environment
$UPDATE_OS_ENVIRON = True
# Get the full log of error
$XONSH_SHOW_TRACEBACK = True
# always return if a cmd fails
$RAISE_SUBPROC_ERROR = True

import os
import json

property_to_update = {}

# update all the .vscode/tasks.json
print("Updating tasks.json ...")
for root, dirs, files in os.walk(".."):
    for file in files:
        if file in ["tasks.json", "common.json"]:
            file_path = os.path.join(root, file)
            print(file_path)
            with open(file_path, "r", encoding="utf-8") as f:
                old = json.load(f)

            tasks = old.get("tasks", [])

            for task in tasks:
                for field, value in property_to_update.items():
                    if field not in task:
                        task[field] = value

            with open(file_path, "w", encoding="utf-8") as f:
                json.dump(old, f, indent=4)

