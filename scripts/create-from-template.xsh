#!/usr/bin/env xonsh

# Copyright (c) 2025 Toradex
# SPDX-License-Identifier: MIT

##
# This script is used to create a new project from a template.
##

# use the xonsh environment to update the OS environment
$UPDATE_OS_ENVIRON = True
# always return if a cmd fails
$RAISE_SUBPROC_ERROR = True

import os
import sys
import json
from pathlib import Path
from typing import TypeVar
from xonsh.procs.pipelines import CommandPipeline
from torizon_templates_utils.tasks import replace_tasks_input
from torizon_templates_utils.args import get_arg_not_empty,get_optional_arg
from torizon_templates_utils.errors import Error,Error_Out
from torizon_templates_utils.colors import Color,BgColor,print


if len(sys.argv) < 5:
    print(
"""
Usage:

    create-from-template.xsh <template_folder> <project_name> <container_name> <new_project_path> [template] [vscode] [telemetry]

    <template_folder>   The folder where the template that will be used to create
                        the new project is located.

    <project_name>      The name of the new project.

    <container_name>    The name of the container that will be used for the new project.

    <new_project_path>  The path where the new project will be created.

    Optional:

    [template]          The name of the template to be used. If not provided, the
                        script will use the folder name from <template_folder>.

    [vscode]            This is a bool like argument. This signals if the script
                        is being used from VS Code extension.

    [telemetry]         This is a bool like argument. This signals if the script
                        is being used from VS Code extension.
"""
    )

    Error_Out("", Error.EUSER)


_old_cwd = os.getcwd()

template_folder = get_arg_not_empty(1)
project_name = get_arg_not_empty(2)
container_name = get_arg_not_empty(3)
new_project_path = get_arg_not_empty(4)

# get the template_folder name
_template = Path(template_folder).name

# optional
template = get_optional_arg(5, _template)
vscode = get_optional_arg(6, False)
telemetry = get_optional_arg(7, True)

# the new_project_path need to be a full path
new_project_path = f"{new_project_path}/{project_name}"


print("Data:")
print(f"\tTemplate Folder: {template_folder}")
print(f"\tProject Name: {project_name}")
print(f"\tContainer Name: {container_name}")
print(f"\tNew Project Path: {new_project_path}")
print(f"\tTemplate: {template}")
print(f"\tIs VS Code: {vscode}")
print(f"\tSend Telemetry: {telemetry}")

# get the template metadata from ../templates.json
try:
    with open(f"{template_folder}/../templates.json", 'r') as  file:
        _metadata = json.load(file)
except FileNotFoundError as fex:
    Error_Out(
        f"Error: {fex.strerror} :: {fex.filename}",
        Error.ENOFOUND
    )

_template_metadata = next(
    (t for t in _metadata["Templates"] if t["folder"] == template),
    None
)

if _template_metadata is None:
    Error_Out(
        f"Error: Template '{template}' not found in templates.json",
        Error.ENOFOUND
    )

# send telemetry
if telemetry:
    try:
        import http.client
        import urllib.parse

        _query = urllib.parse.urlencode({
            "template": template
        }).encode("utf-8")

        _conn = http.client.HTTPConnection("ec2-3-133-114-116.us-east-2.compute.amazonaws.com")
        _conn.request(
            "GET", "/api/template/plus",
            body=_query
        )

        _res = _conn.getresponse()

        if _res.status != 200:
            print(f"Telemetry failed: {_res.status}", Color.YELLOW)

        _conn.close()
    except Exception as ex:
        print(f"Telemetry error: {ex}", Color.YELLOW)
else:
    print(f"Telemetry disabled", color=Color.BLUE)

# create the copy
print("Creating from template ...", color=Color.YELLOW)
cp -r @(template_folder) @(new_project_path)
print("✅ Folder copy done!", color=Color.GREEN)

# apply the common tasks and inputs
if "mergeCommon" not in _template_metadata or _template_metadata['mergeCommon'] != False:
    print("Applying common tasks ...", color=Color.YELLOW)

    _f_commontasks = open(f"{template_folder}/../assets/tasks/common.json", "r")
    _common_tasks = json.load(_f_commontasks)
    _f_commontasks.close()

    _f_commoninputs = open(f"{template_folder}/../assets/tasks/inputs.json", "r")
    _common_inputs = json.load(_f_commoninputs)
    _f_commoninputs.close()

    _f_projtasks = open(f"{new_project_path}/.vscode/tasks.json", "r")
    _proj_tasks = json.load(_f_projtasks)
    _f_projtasks.close()

    # merge then
    _proj_tasks["tasks"] += _common_tasks["tasks"]
    _proj_tasks["inputs"] += _common_inputs["inputs"]

    # write back
    _f_projtasks = open(f"{new_project_path}/.vscode/tasks.json", "w+")
    _f_projtasks.write(json.dumps(_proj_tasks, indent=4))
    _f_projtasks.close()

    print("✅ Common tasks applied!", color=Color.GREEN)

# we have to also copy the scripts
cp -r @(template_folder)/../scripts/check-deps.xsh @(new_project_path)/.conf/
cp -r @(template_folder)/../scripts/run-container-if-not-exists.xsh @(new_project_path)/.conf/
cp -r @(template_folder)/../scripts/share-wsl-ports.xsh @(new_project_path)/.conf/
cp -r @(template_folder)/../scripts/create-docker-compose-production.xsh @(new_project_path)/.conf/
cp -r @(template_folder)/../scripts/torizon-packages.xsh @(new_project_path)/.conf/
cp -r @(template_folder)/../scripts/.vscode/tasks.xsh @(new_project_path)/.vscode/
cp -r @(template_folder)/../scripts/bash/tcb-env-setup.sh @(new_project_path)/.conf/
cp -r @(template_folder)/../scripts/torizon-io.xsh @(new_project_path)/.conf/
cp -r @(template_folder)/../scripts/check-ci-env.xsh @(new_project_path)/.conf/
cp -r @(template_folder)/../scripts/validate-deps-running.xsh @(new_project_path)/.conf/


template_name = os.path.basename(template_folder)

# torizonPackages.json fixups
# TCB template does not use it
if template_name != "tcb":
    _tor_package_json_file = open(f"{template_folder}/../assets/json/torizonPackages.json", "r")
    _tor_package_json = json.load(_tor_package_json_file)
    _tor_package_json_file.close()

    _dockerfile_file = open(f"{template_folder}/Dockerfile", "r")
    _dockerfile_lines = _dockerfile_file.readlines()
    _dockerfile_file.close()

    _build_dep_dockerfile = False

    for line in _dockerfile_lines:
        if "torizon_packages_build" in line:
            _build_dep_dockerfile = True
            break

    # the torizonPackages.json comes with the buildDeps, devRuntimeDeps and prodRuntimeDeps
    # but some templates can not use all of them
    # so we groom the JSON object to remove the unnecessary keys
    if not os.path.exists(f"{template_folder}/Dockerfile.sdk"):
        _tor_package_json.pop("buildDeps")

    if not os.path.exists(f"{template_folder}/Dockerfile.debug"):
        _tor_package_json.pop("devRuntimeDeps")

    # save the modified JSON object
    _tor_package_json_file = open(f"{new_project_path}/torizonPackages.json", "w+")
    _tor_package_json_file.write(json.dumps(_tor_package_json, indent=4))
    _tor_package_json_file.close()


# check .conf/deps.json
_deps_json_file = open(f"{template_folder}/.conf/deps.json", "r")
_deps_json = json.load(_deps_json_file)
_deps_json_file.close()

# if there are installation scripts listed on the .conf/deps.json
# we need to copy them to the new project
if "installDepsScripts" in _deps_json and len(_deps_json["installDepsScripts"]) > 0:
    if not os.path.exists(f"{new_project_path}/.conf/installDepsScripts"):
        os.makedirs(f"{new_project_path}/.conf/installDepsScripts")

    # copy the scripts
    for script in _deps_json["installDepsScripts"]:
        if not os.path.exists(f"{new_project_path}/{script}") and ".conf/installDepsScripts" in script:
            _script_source = script.replace(".conf", "scripts")
            cp -r @(template_folder)/../@(_script_source) @(new_project_path)/@(script)


# copy the github actions if not exists
if not os.path.exists(f"{new_project_path}/.github"):
    mkdir -p @(new_project_path)/.github
    cp -r @(template_folder)/../assets/github/workflows @(new_project_path)/.github


# copy the .gitlab ci if not exists
if not os.path.exists(f"{new_project_path}/.gitlab-ci.yml"):
    cp -r @(template_folder)/../assets/gitlab/.gitlab-ci.yml @(new_project_path)/.gitlab-ci.yml

# create a metadata.json to store
# template name
# container name
# base TOR used when created
_proj_metadata_json = {
    "projectName": project_name,
    "templateName": template,
    "containerName": container_name,
    "torizonOSMajor": _metadata["TorizonOSMajor"]
}

# save the metadata json file
_proj_metadata_json_file = open(f"{new_project_path}/.conf/metadata.json", "w+")
_proj_metadata_json_file.write(json.dumps(_proj_metadata_json, indent=4))
_proj_metadata_json_file.close()

print("✅ Scripts copy done", color=Color.GREEN)

os.chdir(new_project_path)


# change the folders that is needed
print("Renaming folders ...", color=Color.YELLOW)

for item in Path('.').rglob('*__change__*'):
    print(item)
    new_name = str(item).replace('__change__', project_name)
    item.rename(new_name)

print("✅ Project folders ok", color=Color.GREEN)


# change the contents
print("Renaming file contents ...", color=Color.YELLOW)

for item in Path('.').rglob('*'):
    if item.is_file():
        mime_type: CommandPipeline
        mime_type = !(file --mime-encoding @(item))

        if "binary" not in mime_type.out:
            if "id_rsa" not in str(item):
                with open(item, 'r') as file:
                    content = file.read()
                content = content.replace("__change__", project_name)
                content = content.replace("__container__", container_name)
                content = content.replace("__home__", os.environ['HOME'])
                content = content.replace("__templateFolder__", template)
                with open(item, 'w') as file:
                    file.write(content)
            elif "id_rsa.pub" not in str(item):
                os.chmod(item, 0o400)


# the project updater does not need to change the contents
cp -r @(template_folder)/../scripts/project-updater.xsh @(new_project_path)/.conf/

# if from vs code we need to replace the inputs
if vscode != False:
    replace_tasks_input()


print("✅ Renaming file contents ok", color=Color.GREEN)

# back
os.chdir(_old_cwd)
