#!/usr/bin/env xonsh

# Copyright (c) 2025 Toradex
# SPDX-License-Identifier: MIT

##
# This script is used to create a new Torizon project from a template, but
# in an interactive way. The create-from-template script only receive the
# arguments, it does not ask for any input.
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
from torizon_templates_utils.errors import Error,Error_Out
from torizon_templates_utils.colors import Color,BgColor,print

# 1. list the templates
# 2. choose a template
# 3. ask for the project name
# 4. ask for the project container name
# 5. ask for the project path
# 6. create

# .1
_templates = []
with open(f"{os.environ['HOME']}/.apollox/templates.json", "r") as f:
    _templates = json.load(f)["Templates"]

print("📦 :: TEMPLATES :: 📦")
for _template in _templates:
    print("")
    print(f"\t 📦 Template: {_template['folder']}", color=Color.BLACK, bg_color=BgColor.BRIGTH_BLUE)
    print(f"\t\t 📝 Description: {_template['description']}")
    print(f"\t\t 👅 Language: {_template['language']}")
    print(f"\t\t 🏃 Runtime: {_template['runtime']}")
    print("")

# .2
_template_inp = input("Choose a template> ")

# check sanity
if not _template_inp or _template_inp == "":
    Error_Out(
        "❌ :: Template can not be empty :: ❌",
        Error.EUSER
    )

_template = None

for _t in _templates:
    if _t["folder"] == _template_inp:
        _template = _t
        break

if not _template:
    Error_Out(
        f"❌ :: Template [{_template_inp}] not found :: ❌",
        Error.ENOFOUND
    )

# .3
_project_name = input("Project name> ")

# check sanity
if not _project_name or _project_name == "":
    Error_Out(
        "❌ :: Project name can not be empty :: ❌",
        Error.EUSER
    )

# .4
_project_container_name = input("Project container name> ")

# check sanity
if not _project_container_name or _project_container_name == "":
    Error_Out(
        "❌ :: Project container name can not be empty :: ❌",
        Error.EUSER
    )

# .5
_project_path = input("Project path> ")

# check sanity
if not _project_path or _project_path == "":
    Error_Out(
        "❌ :: Project path can not be empty :: ❌",
        Error.EUSER
    )

# Resolve relative paths to absolute paths based on the current working directory
_project_path = os.path.abspath(os.path.join("/workspace", _project_path))

if not os.path.exists(_project_path):
    Error_Out(
        "❌ :: Project path does not exists :: ❌",
        Error.ENOFOUND
    )

if os.path.exists(f"{_project_path}/{_project_name}"):
    Error_Out(
        f"❌ :: Project path with project name [{_project_path}/{_project_name}] already exists :: ❌",
        Error.EINVAL
    )

# .6
print("🆕 Creating project...", color=Color.YELLOW)

xonsh ./create-from-template.xsh \
    @(f"{os.environ['HOME']}/.apollox/{_template['folder']}") \
    @(_project_name) \
    @(_project_name) \
    @(_project_container_name) \
    @(_project_path) \
    @(_template["folder"]) \
    @(False) \
    @(False)

print(f"✅ Project [{_project_name}] created!", color=Color.GREEN)
