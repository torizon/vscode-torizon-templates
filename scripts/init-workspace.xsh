#!/usr/bin/env xonsh

# Copyright (c) 2025 Toradex
# SPDX-License-Identifier: MIT

##
# This script is used to initialize the workspace with the data from the target
# device that was set.
# Warning: This script is not meant to be run directly, it is called by the
# zygote script.
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
from torizon_templates_utils.network import get_host_ip
from torizon_templates_utils.errors import Error,Error_Out
from torizon_templates_utils.colors import Color,BgColor,print


def _get_gpu_vendor(model: str, rc_prefix: bool = False):
    model = model.lower()

    if "am62" in model:
        return "am62"
    elif "beagleplay" in model:
        return "am62"
    elif "imx8" in model:
        return "-imx8" if rc_prefix else "-vivante"
    else:
        # generic non gpu specific
        return ""


print("⚒️ :: INITIALIZING WORKSPACE :: ⚒️")
print("")

# check if we have a target device set
if not os.path.exists(f"{os.environ['HOME']}/.tcd/target.json"):
    Error_Out(
        "❌ :: No target device set :: ❌",
        Error.ENOFOUND
    )

# check if the workspace is valid
if os.path.exists("./.conf/metadata.json"):
    _metadata_json_file = open("./.conf/metadata.json", "r")
    _metadata_json = json.load(_metadata_json_file)
    _metadata_json_file.close()

    _template_name = _metadata_json["templateName"]
    _project_name = os.path.basename(os.getcwd())

else:
    Error_Out(
        "❌ :: This folder is not a valid Torizon template :: ❌",
        Error.ETOMCRUISE
    )


# mimic the vs code auto run
if "WSL_DISTRO_NAME" in os.environ and os.environ["WSL_DISTRO_NAME"] != "":
    print("🔧 :: Sharing WSL ports with Windows :: 🔧")
    print("")

    # first check if the powershell is available
    if not os.path.exists("/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe"):
        Error_Out(
            "❌ :: PowerShell not found in Windows path [/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe] :: ❌",
            Error.ENOFOUND
        )

    exc_remoteport = !(sudo nsenter -t 1 -m -u -n -i -- ifconfig eth0 | grep 'inet ')

    ports = [
        8090,
        5002
    ]

    addr = "0.0.0.0"
    _power_line = ""

    for port in ports:
        _power_line += f" (netsh interface portproxy add v4tov4 listenport={port} listenaddress={addr} connectport={port} connectaddress={exc_remoteport.out.split()[1]}) -or $true ; "

    sudo nsenter -t 1 -m -u -n -i -- /mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -NoProfile -C @(f"start-process powershell -verb runas -ArgumentList '-NoProfile -C \"(Remove-NetFireWallRule -DisplayName ApolloX) -or $true ;  New-NetFireWallRule -DisplayName ApolloX -Direction Outbound -LocalPort 8090,5002 -Action Allow -Protocol TCP ;  New-NetFireWallRule -DisplayName ApolloX -Direction Inbound -LocalPort 8090,5002 -Action Allow -Protocol TCP ;  {_power_line}  echo done\"'")
    print("")


print("🔧 :: Running Local Registry :: 🔧")
print("")
xonsh ./.vscode/tasks.xsh run run-docker-registry
print("")

print("🔧 :: Running binfmt registry :: 🔧")
print("")
xonsh ./.vscode/tasks.xsh run run-torizon-binfmt
print("")

print("🔧 :: Running Check dependency :: 🔧")
print("")
xonsh ./.vscode/tasks.xsh run check-deps
print("")

# set the target device into the settings.json
with open(f"./.vscode/settings.json", "r") as f:
    _settings = json.load(f)

with open(f"{os.environ['HOME']}/.tcd/target.json", "r") as f:
    _target_device = json.load(f)

_rc_prefix = None
if "torizon.gpuPrefixRC" in _settings:
    _rc_prefix = _settings["torizon.gpuPrefixRC"]

if _rc_prefix is None:
    _rc_prefix = False

_hostname = _target_device["Hostname"]
_settings["torizon_psswd"] = _target_device["__pass__"]
_settings["torizon_ip"] = _target_device["Ip"]
_settings["torizon_ssh_port"] = f"{_target_device['SshPort']}"
_settings["torizon_login"] = _target_device["Login"]
_settings["host_ip"] = get_host_ip()
_settings["torizon_arch"] = _target_device["Arch"]
_settings["torizon_gpu"] = _get_gpu_vendor(_target_device["Model"], _rc_prefix)

# dump the settings back
with open(f"./.vscode/settings.json", "w") as f:
    json.dump(_settings, f, indent=4)

print("")
print(f"✅ :: Project [{_project_name}] based on [{_template_name}] initialized to work with device [{_hostname}] :: ✅", color=Color.GREEN)
