#!/usr/bin/env xonsh
"""
validate-json.xsh: validate all JSON files under the repo (with an allowlist).
"""
# pylint: disable=invalid-name

# Copyright (c) 2025 Toradex
# SPDX-License-Identifier: MIT

##
# This script is used to configure a Torizon device to be ready for development.
# WARNING:
# This script is not meant to be run manually. It's make part of the internal
# validation process from CI/CD.
##

# use the xonsh environment to update the OS environment
$UPDATE_OS_ENVIRON = True
# Get the full log of error
$XONSH_SHOW_TRACEBACK = True
# always return if a cmd fails
$RAISE_SUBPROC_ERROR = True

import os
import sys
import json

$SCRIPT_PATH = os.path.dirname(os.path.realpath(__file__))

# 1. go to the apollox directory
cd $SCRIPT_PATH/..

# Build the list of *.json files in pure Python (avoids pylint confusion with !find)
_files_list = []
for _root, _dirs, _files in os.walk(".", topdown=True):
    for _fname in _files:
        if _fname.endswith(".json"):
            _files_list.append(os.path.abspath(os.path.join(_root, _fname)))

_has_invalid_files = False

_allow_list = [
    "vscode-torizon-templates/.vscode/settings.json",
    "vscode-torizon-templates/scripts/.vscode/tasks.json",
    "vscode-torizon-templates/scripts/.vscode/launch.json",
]

for _file in _files_list:
    try:
        _can_skip = False
        for _allow in _allow_list:
            if _allow in _file:
                _can_skip = True
                break
        if _can_skip:
            continue

        with open(_file, "r", encoding="utf-8") as f:
            json.load(f)

    except json.JSONDecodeError as e:
        _has_invalid_files = True
        print(f"❌ :: {_file}:{e.lineno} :: ❌")
        print(f"\t {e}")
        print("")
        continue

    except OSError as e:
        _has_invalid_files = True
        print(f"❌ :: {_file} :: ❌")
        print(f"\t {e}")
        print("")
        continue

if _has_invalid_files:
    sys.exit(1)
else:
    print("✅ :: All files are valid JSON :: ✅")
    sys.exit(0)

