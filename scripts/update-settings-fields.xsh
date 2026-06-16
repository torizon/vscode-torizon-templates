#!/usr/bin/env xonsh

# Copyright (c) 2025 Toradex
# SPDX-License-Identifier: MIT

##
# This script is used to update the common property in all the settings.json files
##

# use the xonsh environment to update the OS environment
$UPDATE_OS_ENVIRON = True
# Get the full log of error
$XONSH_SHOW_TRACEBACK = True
# always return if a cmd fails
$XONSH_SUBPROC_CMD_RAISE_ERROR = True

import os
import sys
import json


settingsTemplate = {
    "torizon_psswd": "",
    "torizon_login": "",
    "torizon_ip": "",
    "torizon_ssh_port": "",
    "host_ip": "",
    "torizon_workspace": "$`{workspaceFolder`}",
    "torizon_debug_ssh_port": "2222",
    "torizon_debug_port1": "",
    "torizon_debug_port2": "",
    "torizon_debug_port3": "",
    "torizon_gpu": "",
    "torizon_arch": "",
    "wait_sync": "1",
    "torizon_run_as": "torizon",
    "torizon_app_root": "/home/torizon/app",
    "docker_tag": "v0.0.0",
    "tcb.packageName": "__change__",
    "tcb.version": "3.11.0",
    "torizon.gpuPrefixRC": True
}

print("Updating settings.json ...")

for root, dirs, files in os.walk(".."):
    for file in files:
        if file == "settings.json" and "vscode-torizon-templates/.vscode" not in root:
            file_path = os.path.join(root, file)
            print(file_path)

            with open(file_path, 'r') as f:
                old = json.load(f)

            old_fields = old.keys()
            new_fields = settingsTemplate.keys()

            for field in new_fields:
                if field not in old_fields:
                    old[field] = settingsTemplate[field]

            ordered_property_names = list(settingsTemplate.keys())
            new_old = {prop: old[prop] for prop in ordered_property_names if prop in old}

            for prop in old:
                if prop not in new_old:
                    new_old[prop] = old[prop]

            with open(file_path, 'w') as f:
                json.dump(new_old, f, indent=4)
