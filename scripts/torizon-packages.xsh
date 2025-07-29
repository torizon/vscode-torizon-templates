#!/usr/bin/env xonsh
# pylint: disable=invalid-name
"""
torizon-packages.xsh: apply Debian packages from torizonPackages.json into
Dockerfile(s) for the selected target architecture.
"""

# Copyright (c) 2025 Toradex
# SPDX-License-Identifier: MIT

##
# This script is used to apply the Debian packages that was set in the
# torizon-packages.json file. This is useful to define the packages once
# and apply then for the right target architecture on the multiple Dockerfile
##

# use the xonsh environment to update the OS environment
$UPDATE_OS_ENVIRON = True
# Get the full log of error
$XONSH_SHOW_TRACEBACK = True
# always return if a cmd fails
$RAISE_SUBPROC_ERROR = True

import os
import json
from torizon_templates_utils.args import get_arg_not_empty  # pylint: disable=no-name-in-module
from torizon_templates_utils.colors import Color
from torizon_templates_utils.errors import Error, Error_Out  # pylint: disable=no-name-in-module

_TORIZON_ARCHS = [
    "arm64",
    "armhf",
    "amd64",
    "riscv",
]

TORIZON_ARCH = get_arg_not_empty(1)

if TORIZON_ARCH not in _TORIZON_ARCHS:
    Error_Out(
        f"Undefined target architecture: {TORIZON_ARCH}.",
        Error.EUSER,
    )


def _add_dep_string(value: str) -> str:
    """Format a package entry with an explicit arch suffix when needed."""
    # If the arch of the package has been explicitly specified, don't add the target arch
    if ":" in value:
        return f"    {value} \\\n"

    # There are certain packages which have "all" as architecture
    # pylint: disable=line-too-long
    value_arch_out = $(apt-cache show @(value) | sed -n '/^Architecture:/ {s/^Architecture: //; p; q}')
    value_arch = value_arch_out.strip()
    if value_arch == "all":
        return f"    {value}:all \\\n"
    return f"    {value}:{TORIZON_ARCH} \\\n"


def _replace_section(file_lines, section):  # pylint: disable=too-many-branches
    """Replace the __<section> markers block with packages according to JSON."""
    start_ix = None
    end_ix = None
    new_file_content = []

    for ix, line in enumerate(file_lines):
        if f"__{section}_start__" in line:
            start_ix = ix
        if f"__{section}_end__" in line:
            end_ix = ix

    stop_add = False

    for ix, line in enumerate(file_lines):
        if ix == start_ix:
            new_file_content.append(line)
            stop_add = True

            with open("torizonPackages.json", "r", encoding="utf-8") as f:
                json_data = json.load(f)

            build_packs = json_data.get("buildDeps", [])

            if "devRuntimeDeps" in json_data:
                dev_packs = json_data["devRuntimeDeps"]
            else:
                dev_packs = json_data.get("devDeps", [])

            if "prodRuntimeDeps" in json_data:
                prod_packs = json_data["prodRuntimeDeps"]
            else:
                prod_packs = json_data.get("deps", [])

            if "build" in section:
                for pack in build_packs:
                    new_file_content.append(_add_dep_string(pack))
            elif "dev" in section:
                for pack in dev_packs:
                    new_file_content.append(_add_dep_string(pack))
            elif "prod" in section:
                for pack in prod_packs:
                    new_file_content.append(_add_dep_string(pack))

        if ix == end_ix:
            stop_add = False

        if not stop_add:
            new_file_content.append(line)

    return new_file_content


print("Applying torizonPackages.json: ")

# Dockerfile.debug
if os.path.exists("Dockerfile.debug"):
    print("Applying to Dockerfile.debug ...")

    with open("Dockerfile.debug", "r", encoding="utf-8") as _dockerfile_debug:
        _dockerfile_debug_lines = _dockerfile_debug.readlines()

    _dockerfile_debug_lines = _replace_section(
        _dockerfile_debug_lines,
        "torizon_packages_dev",
    )

    # write back to the file
    with open("Dockerfile.debug", "w", encoding="utf-8") as _dockerfile_debug_w:
        _dockerfile_debug_w.write("".join(_dockerfile_debug_lines))

    print("✅ Dockerfile.debug", color=Color.GREEN)

# Dockerfile.sdk
if os.path.exists("Dockerfile.sdk"):
    print("Applying to Dockerfile.sdk ...")

    with open("Dockerfile.sdk", "r", encoding="utf-8") as _dockerfile_sdk:
        _dockerfile_sdk_lines = _dockerfile_sdk.readlines()

    _dockerfile_sdk_lines = _replace_section(
        _dockerfile_sdk_lines,
        "torizon_packages_build",
    )

    # write back to the file
    with open("Dockerfile.sdk", "w", encoding="utf-8") as _dockerfile_sdk_w:
        _dockerfile_sdk_w.write("".join(_dockerfile_sdk_lines))

    print("✅ Dockerfile.sdk", color=Color.GREEN)

# Dockerfile (all templates have it)
print("Applying to Dockerfile ...")

with open("Dockerfile", "r", encoding="utf-8") as _dockerfile_r:
    _dockerfile_lines = _dockerfile_r.readlines()

# Dockerfile can have multi-stage for build
_dockerfile_lines = _replace_section(
    _dockerfile_lines,
    "torizon_packages_prod",
)

_dockerfile_lines = _replace_section(
    _dockerfile_lines,
    "torizon_packages_build",
)

# write back to the file
with open("Dockerfile", "w", encoding="utf-8") as _dockerfile_w:
    _dockerfile_w.write("".join(_dockerfile_lines))

print("✅ Dockerfile", color=Color.GREEN)

print("torizonPackages.json applied")

