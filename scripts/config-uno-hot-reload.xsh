#!/usr/bin/env xonsh
"""
config-uno-hot-reload.xsh: inject host IP into the Uno .csproj for hot reload.
"""
# pylint: disable=invalid-name

# Copyright (c) 2025 Toradex
# SPDX-License-Identifier: MIT

##
# This script automatically set the host ip in the csproj file.
# WARNING:
# This script is not meant to be run manually. It's make part of the tasks
# for the .NET Uno framework template.
##

# use the xonsh environment to update the OS environment
$UPDATE_OS_ENVIRON = True
# Get the full log of error
$XONSH_SHOW_TRACEBACK = True
# always return if a cmd fails
$RAISE_SUBPROC_ERROR = True

import sys
import glob
import json
import xml.etree.ElementTree as ET
from torizon_templates_utils import errors as _errors
from torizon_templates_utils.colors import Color

# stable references without importing names that pylint can't resolve statically
Error = getattr(_errors, "Error")
def _Error_Out(msg, code):
    # pylint: disable=no-member
    return _errors.Error_Out(msg, code)

# get the workspace folder
workspaceFolder = sys.argv[1]

# get the path of the xml file
files = glob.glob(f"{workspaceFolder}/*.Skia.*/*.csproj")
csproj_path = files[0]

# load the csproj file as XML
with open(csproj_path, "r", encoding="utf-8") as f:
    csproj = ET.parse(f)

# get my ip address
with open(f"{workspaceFolder}/.vscode/settings.json", "r", encoding="utf-8") as f:
    settings = json.load(f)
host_ip = settings.get("host_ip")

if not host_ip:
    print("Did you forget to set a default device?", color=Color.YELLOW)
    #pylint: disable=line-too-long
    print("https://developer.toradex.com/torizon/application-development/ide-extension/connect-a-torizoncore-target-device \n")
    _Error_Out("The host ip is not set in the .vscode/settings.json file", Error.ENOCONF)

print(f"Injecting the host ip {host_ip}")
print("into the csproj file: ")
print(f"{csproj_path} \n\n")

# update it
property_group = csproj.find(".//PropertyGroup")
uno_remote_control_host = property_group.find("UnoRemoteControlHost")
if uno_remote_control_host is None:
    #pylint: disable=line-too-long
    uno_remote_control_host = ET.SubElement(property_group, "UnoRemoteControlHost")
uno_remote_control_host.text = host_ip

# save it
csproj.write(csproj_path)

print("✅ Success! \n")

