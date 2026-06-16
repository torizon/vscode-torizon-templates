#!/usr/bin/env xonsh

# Copyright (c) 2025 Toradex
# SPDX-License-Identifier: MIT

##
# This script is used to check if the dependencies, Debian packages, or and
# scripts, are installed in the system.
# The list of deb dependencies are defined in the .conf/deps.json file.
##

# use the xonsh environment to update the OS environment
$UPDATE_OS_ENVIRON = True
# Get the full log of error
$XONSH_SHOW_TRACEBACK = True
# this script expect to have the error handling
$XONSH_SUBPROC_CMD_RAISE_ERROR = False

import os
import sys
import json
import shutil
from pathlib import Path
from torizon_templates_utils.network import is_in_gitlab_ci_container
from torizon_templates_utils.errors import Error,Error_Out,last_return_code
from torizon_templates_utils.colors import Color,BgColor,print

args = $ARGS
if len(args) != 3:
    print("Usage: xonsh check-deps.xsh <workspace_root> <is_multi_root>")
    exit(1)

workspace_root = args[1]
is_multi_root = args[2].lower() == 'true'

# clean the workspace set device default to use the local docker engine
$DOCKER_HOST = ""

if is_in_gitlab_ci_container():
    print("ℹ️ :: GITLAB_CI using docker executor :: ℹ️")
    $DOCKER_HOST = "tcp://docker:2375"

# docker and docker-compose are special cases
# TODO: check also for podman or other runtime
if shutil.which("docker") is None:
    Error_Out(
        "❌ you need docker installed",
        Error.ENOCONF
    )

_docker_compose_ret = !(docker compose version).returncode
if _docker_compose_ret != 0:
    Error_Out(
        "❌ you need docker compose plugin installed",
        Error.ENOCONF
    )

workspace_paths = [workspace_root]
if is_multi_root:
    # loop through every immediate subfolder inside workspace_root
    for entry in os.listdir(workspace_root):
        folder = os.path.join(workspace_root, entry)
        deps_file = os.path.join(folder, ".conf", "deps.json")

        # check if it is a directory and has deps.json
        if os.path.isdir(folder) and os.path.isfile(deps_file):
            workspace_paths.append(folder)

_deps_pckgs = []
_deps_scripts = []

# get workspace deps from .conf/deps.json files
for path in workspace_paths:
    conf_dir = os.path.join(path, ".conf")
    deps_file = os.path.join(conf_dir, "deps.json")

    if not os.path.isdir(conf_dir) or not os.path.isfile(deps_file):
        continue

    with open(deps_file) as f:
        _deps = json.load(f)
        if "packages" in _deps:
            _deps_pckgs.extend(_deps["packages"])
        if "installDepsScripts" in _deps:
            if is_multi_root:
                workspace_name = Path(path).name
                _deps_scripts.extend([
                    f"{workspace_name}/{script}"
                    for script in _deps["installDepsScripts"]
                ])
            else:
                _deps_scripts.extend(_deps["installDepsScripts"])

# remove duplicates
_deps_pckgs = list(set(_deps_pckgs))
_deps_scripts = list(set(_deps_scripts))

# ok, docker and docker compose exists so let's check the packages
_packages_to_install = []

print("Checking dependencies...\n", color=Color.YELLOW)
for package in _deps_pckgs:
    dpkg_check = !(dpkg -s @(package))

    if dpkg_check.returncode != 0:
        _packages_to_install.append(package)
        print(f"😵 {package} debian package dependency not installed", color=Color.RED)
    else:
        print(f"👍 {package} debian package dependency installed", color=Color.GREEN)

_scripts_to_install: list[str] = []

for script in _deps_scripts:
    script_installed = False
    if Path(".conf/.depok").exists():
        with open(".conf/.depok", "r") as f:
            if script in f.read():
                script_installed = True

    if not script_installed:
        _scripts_to_install.append(script)
        print(f"😵 {script} dependency installation script not executed before for this project", color=Color.RED)
    else:
        print(f"👍 {script} dependency installation script executed before for this project", color=Color.GREEN)

# this is only for aesthetics, to separate the output
print("")

_installed_scripts = []

# check if there are any packages to be installed or script to be executed
if len(_packages_to_install) == 0 and len(_scripts_to_install) == 0:
    print("✅ All packages already installed")
    print("✅ All installation scripts already executed")

    exit(0)
else:
    _installConfirm = input("Try to install the missing debian packages and execute the missing installation scripts? <y/N>: ")

    if _installConfirm == 'y':
        if len(_packages_to_install) > 0:
            sudo apt-get update

            for package in _packages_to_install:
                sudo apt-get install -y @(package)

                if last_return_code() != 0:
                    Error_Out(
                        f"❌ Error installing {package}",
                        Error.ENOPKG
                    )

        if len(_scripts_to_install) > 0:
            for script in _scripts_to_install:
                if script.endswith('.sh'):
                    chmod +x @(script)

                _installed_scripts.append(script)
                ./@(script)

                if last_return_code() != 0:
                    Error_Out(
                        f"❌ Error executing {script}",
                        Error.ENOPKG
                    )

    if not Path(".conf/.depok").exists():
        _f_depok = open(".conf/.depok", "w")
    else:
        _f_depok = open(".conf/.depok", "a")

    for script in _installed_scripts:
        _f_depok.write(f"{script}\n")
    _f_depok.close()

    # this is only for aesthetics, to separate the output
    print("")

    print("✅ All packages installed")
    print("✅ All installation scripts executed")
