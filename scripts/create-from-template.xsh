#!/usr/bin/env xonsh

# Copyright (c) 2025 Toradex
# SPDX-License-Identifier: MIT

##
# This script is used to create a new project from a template.
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
from glob import glob
from pathlib import Path
from typing import TypeVar
from datetime import date
from xonsh.procs.pipelines import CommandPipeline
from torizon_templates_utils.tasks import replace_tasks_input
from torizon_templates_utils.args import get_arg_not_empty,get_optional_arg
from torizon_templates_utils.errors import Error,Error_Out
from torizon_templates_utils.colors import Color,BgColor,print


if len(sys.argv) < 5:
    print(
"""
Usage:

    create-from-template.xsh <template_folder> <folder_name> <project_name> <container_name> <new_project_path> [template] [vscode] [telemetry]

    <template_folder>   The folder where the template that will be used to create
                        the new project is located.

    <folder_name>       The name of the workspace.

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

    Exception Behavior:

    --customFields      When this flag is set, the script will be used to
                        create a new project from a template that has custom
                        fields.

"""
    )

    Error_Out("", Error.EUSER)


_old_cwd = os.getcwd()
_has_custom_fields = False
_custom_fields = []

template_folder = get_arg_not_empty(1)
folder_name = get_arg_not_empty(2)
project_name = get_arg_not_empty(3)
container_name = get_arg_not_empty(4)
new_project_path = get_arg_not_empty(5)

# get the template_folder name
_template = Path(template_folder).name

# optional
template = get_optional_arg(6, _template)
vscode = get_optional_arg(7, False)
telemetry = get_optional_arg(8, True)


if "--customFields" in sys.argv:
    _has_custom_fields = True
    _custom_fields = json.loads(sys.argv[sys.argv.index("--customFields") + 1])

# the new_project_path need to be a full path
new_project_path = f"{new_project_path}/{folder_name}"
root_path = Path(new_project_path).resolve()


print("Data:")
print(f"\tTemplate Folder: {template_folder}")
print(f"\tFolder Name: {folder_name}")
print(f"\tProject Name: {project_name}")
print(f"\tContainer Name: {container_name}")
print(f"\tNew Project Path: {new_project_path}")
print(f"\tTemplate: {template}")
print(f"\tIs VS Code: {vscode}")
print(f"\tSend Telemetry: {telemetry}")
print(f"\tHas Custom Fields: {_has_custom_fields}")

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
            "template": template,
            "dateTime": date.today().isoformat()
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
if _template == "multiRoot":
    files_to_copy = glob(template_folder + '/*') + [
        f for f in glob(template_folder + '/.*')
        if os.path.basename(f) not in ('.', '..')
    ]
    cp -r @(files_to_copy) @(new_project_path)
else:
    cp -r @(template_folder) @(new_project_path)
print("✅ Folder copy done!", color=Color.GREEN)

# apply the common tasks and inputs
print("Applying common tasks ...", color=Color.YELLOW)

with open(f"{template_folder}/../assets/tasks/common.json", "r") as f:
    _common_tasks = json.load(f)

with open(f"{template_folder}/../assets/tasks/inputs.json", "r") as f:
    _common_inputs = json.load(f)

with open(f"{new_project_path}/.vscode/tasks.json", "r") as f:
    _proj_tasks = json.load(f)

merge_config = _template_metadata.get("mergeCommon", {})
task_labels_to_merge = merge_config.get("tasks", "all")
input_ids_to_merge = merge_config.get("inputs", "all")

def should_merge(item_label, allowed):
    return allowed == "all" or "all" in allowed or item_label in allowed

# Check if template-specific tasks are on the template's tasks.json
# If so, we need to exclude them from the merge list (that is, not add the ones that are on common.json)
template_specific_tasks = ["template-specific-initial-task", "template-specific-final-task"]
existing_template_tasks = {task.get("label") for task in _proj_tasks.get("tasks", [])}
tasks_to_exclude = [task for task in template_specific_tasks if task in existing_template_tasks]

if tasks_to_exclude:
    if task_labels_to_merge == "all":
        # Convert "all" to explicit list
        task_labels_to_merge = [task.get("label") for task in _common_tasks.get("tasks", [])]
    # Remove tasks listed in tasks_to_exclude
    task_labels_to_merge = [label for label in task_labels_to_merge if label not in tasks_to_exclude]

merged_tasks = [
    task for task in _common_tasks.get("tasks", [])
    if should_merge(task.get("label"), task_labels_to_merge)
]
merged_inputs = [
    input_ for input_ in _common_inputs.get("inputs", [])
    if should_merge(input_.get("id"), input_ids_to_merge)
]

_proj_tasks.setdefault("tasks", []).extend(merged_tasks)
_proj_tasks.setdefault("inputs", []).extend(merged_inputs)

with open(f"{new_project_path}/.vscode/tasks.json", "w") as f:
    f.write(json.dumps(_proj_tasks, indent=4))

print("✅ Common tasks applied!", color=Color.GREEN)


print("Applying common settings ...", color=Color.YELLOW)

code_workspace_config = _template_metadata.get("codeWorkspace", False)
common_settings_path = f"{template_folder}/../assets/settings/common.json"
if not code_workspace_config:
    project_settings_path = f"{new_project_path}/.vscode/settings.json"
else:
    project_settings_path = f"{new_project_path}/multiRoot.code-workspace"

try:
    with open(common_settings_path, "r") as f:
        _common_settings = json.load(f)
except FileNotFoundError:
    raise FileNotFoundError("Missing common.json file.")

try:
    with open(project_settings_path, "r") as f:
        _proj_settings = json.load(f)
except FileNotFoundError:
    raise FileNotFoundError("Missing settings.json or .code-workspace.")

# Apply only keys that don't already exist in project settings
if code_workspace_config:
    _proj_settings.setdefault("settings", {})
    for key, value in _common_settings.items():
        _proj_settings["settings"].setdefault(key, value)
else:
    for key, value in _common_settings.items():
        _proj_settings.setdefault(key, value)

with open(project_settings_path, "w") as f:
    json.dump(_proj_settings, f, indent=4)

print("✅ Common settings applied!", color=Color.GREEN)

# If scripts not specified, copy common scripts
template_scripts = _template_metadata.get("scripts")
if template_scripts is None:
    # we have to also copy the scripts
    cp -r @(template_folder)/../scripts/check-deps.xsh @(new_project_path)/.conf/
    cp -r @(template_folder)/../scripts/run-container-if-not-exists.xsh @(new_project_path)/.conf/
    cp -r @(template_folder)/../scripts/share-wsl-ports.xsh @(new_project_path)/.conf/
    cp -r @(template_folder)/../scripts/docker-login.xsh @(new_project_path)/.conf/
    cp -r @(template_folder)/../scripts/create-docker-compose-production.xsh @(new_project_path)/.conf/
    cp -r @(template_folder)/../scripts/torizon-packages.xsh @(new_project_path)/.conf/
    cp -r @(template_folder)/../scripts/.vscode/tasks.xsh @(new_project_path)/.vscode/
    cp -r @(template_folder)/../scripts/bash/tcb-env-setup.sh @(new_project_path)/.conf/
    cp -r @(template_folder)/../scripts/torizon-io.xsh @(new_project_path)/.conf/
    cp -r @(template_folder)/../scripts/check-ci-env.xsh @(new_project_path)/.conf/
    cp -r @(template_folder)/../scripts/validate-deps-running.xsh @(new_project_path)/.conf/
    cp -r @(template_folder)/../scripts/apply-ci-settings-file.xsh @(new_project_path)/.conf/
    cp -r @(template_folder)/../scripts/validate-json.xsh @(new_project_path)/.conf/
    cp -r @(template_folder)/../scripts/service-check.xsh @(new_project_path)/.conf/
    cp -r @(template_folder)/../scripts/spin-up-down-registry.xsh @(new_project_path)/.conf/
else:
    for script in template_scripts:
        cp -r @(os.path.join(template_folder, "..", "scripts", script)) @(os.path.join(new_project_path, ".conf"))

# torizonPackages.json fixups
ignore_torizon_packages = _template_metadata.get("ignoreTorizonPackages", False)
if not ignore_torizon_packages:
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
    "torizonOSMajor": _metadata["TorizonOSMajor"],
    "hasCustomFields": _has_custom_fields,
    "customFields": _custom_fields
}

# save the metadata json file
_proj_metadata_json_file = open(f"{new_project_path}/.conf/metadata.json", "w+")
_proj_metadata_json_file.write(json.dumps(_proj_metadata_json, indent=4))
_proj_metadata_json_file.close()

print("✅ Scripts copy done", color=Color.GREEN)

os.chdir(new_project_path)

def is_nested_workspace_folder(folder: Path) -> bool:
    return (folder / '.conf' / 'metadata.json').exists()

def walk_workspace(path: Path):
    for item in path.iterdir():
        if item.is_dir():
            if is_nested_workspace_folder(item):
                continue
            yield from walk_workspace(item)
        yield item

print("Renaming folders ...", color=Color.YELLOW)
root_path = Path(new_project_path).resolve()

for item in walk_workspace(root_path):
    # Rename folders and files containing __change__
    if '__change__' in item.name:
        renamed = item.with_name(item.name.replace('__change__', project_name))
        item.rename(renamed)
        item = renamed

    # If it's a file, process contents
    if item.is_file():
        if "id_rsa" in str(item) and "id_rsa.pub" not in str(item):
            os.chmod(item, 0o400)
            continue

        mime_type = !(file --mime-encoding @(item))
        if "binary" in mime_type.out:
            continue

        if "id_rsa" not in str(item) and ".conf/update.json" not in str(item):
            with open(item, 'r') as file:
                content = file.read()

            content = content.replace("__change__", project_name)

            if not _has_custom_fields:
                content = content.replace("__container__", container_name)
            else:
                for _field in _custom_fields:
                    content = content.replace(f"__{_field['id']}__", _field['value'])

            content = content.replace("__home__", os.environ['HOME'])
            content = content.replace("__templateFolder__", template)

            with open(item, 'w') as file:
                file.write(content)

print("✅ Project folders and contents renamed", color=Color.GREEN)


# remove-dangling-images and project-updater don't require changing contents
cp -r @(template_folder)/../scripts/project-updater.xsh @(new_project_path)/.conf/
cp -r @(template_folder)/../scripts/remove-dangling-images.xsh @(new_project_path)/.conf/

# if from vs code we need to replace the inputs
if vscode != False:
    replace_tasks_input()


print("✅ Renaming file contents ok", color=Color.GREEN)

# back
os.chdir(_old_cwd)
