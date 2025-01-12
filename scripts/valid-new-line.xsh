#!/usr/bin/env xonsh

# Copyright (c) 2025 Toradex
# SPDX-License-Identifier: MIT

##
# This script is used to check if all the files have a new line at the end.
# WARNING:
# This script is not meant to be run manually. It's make part of the internal
# validation process from CI/CD.
##

# use the xonsh environment to update the OS environment
$UPDATE_OS_ENVIRON = True
# always return if a cmd fails
$RAISE_SUBPROC_ERROR = True

import os
import sys


def check_new_line(file_path):
    with open(file_path, 'rb') as f:
        f.seek(-1, os.SEEK_END)
        last_char = f.read(1)
        return last_char == b'\n'


ignore_folders = [
    ".git",
    "node_modules",
    "id_rsa",
    "css",
    "obj",
    "target",
    ".mypy",
    "egg-info"
]

error_reach = False

for root, dirs, files in os.walk('.'):
    dirs[:] = [d for d in dirs if d not in ignore_folders]
    for file in files:
        file_path = os.path.join(root, file)

        if any(ig in file_path for ig in ignore_folders):
            continue

        mime_type = $(file --mime-type -b @(file_path)).strip()
        if mime_type.startswith('text/') or mime_type in {'application/javascript', 'application/json'}:
            if not check_new_line(file_path):
                print(f"❌ :: {file_path}", file=sys.stderr)
                error_reach = True

if error_reach:
    print("\n❌ :: Files are missing new line at the end\n", file=sys.stderr)
    sys.exit(404)
else:
    print("\n✅ :: All files have new line at the end\n")
    sys.exit(0)
