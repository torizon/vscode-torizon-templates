#!/usr/bin/env xonsh

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
$XONSH_SUBPROC_CMD_RAISE_ERROR = True

import os
import sys
import xml
import glob
import json
from torizon_templates_utils.errors import Error,Error_Out
from torizon_templates_utils.colors import Color,BgColor,print

# get the workspace folder
workspaceFolder = sys.argv[1]

# get the path of the xml file
files = glob.glob(f"{workspaceFolder}/*.Skia.*/*.csproj")
csproj_path = files[0]

# load the csproj file as XML
with open(csproj_path, 'r') as f:
    csproj = xml.etree.ElementTree.parse(f)

# get my ip address
with open(f"{workspaceFolder}/.vscode/settings.json", 'r') as f:
    settings = json.load(f)
host_ip = settings.get('host_ip')

if not host_ip:
    print(
        "Did you forget to set a default device?",
        color=Color.YELLOW
    )
    print("https://developer.toradex.com/torizon/application-development/ide-extension/connect-a-torizoncore-target-device \n")

    Error_Out(
        "The host ip is not set in the .vscode/settings.json file",
        Error.ENOCONF
    )

print(f"Injecting the host ip {host_ip}")
print(f"into the csproj file: ")
print(f"{csproj_path} \n\n")

# update it
property_group = csproj.find('.//PropertyGroup')
uno_remote_control_host = property_group.find('UnoRemoteControlHost')
if uno_remote_control_host is None:
    uno_remote_control_host = xml.etree.ElementTree.SubElement(property_group, 'UnoRemoteControlHost')
uno_remote_control_host.text = host_ip

# save it
csproj.write(csproj_path)

print("✅ Success! \n")
