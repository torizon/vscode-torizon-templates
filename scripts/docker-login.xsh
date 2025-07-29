#!/usr/bin/env xonsh
"""
docker-login.xsh: Log in to a container registry (Docker Hub or custom),
respecting CI Docker host if needed.
"""
# pylint: disable=invalid-name

# Copyright (c) 2025 Toradex
# SPDX-License-Identifier: MIT

##
# This script is used to publish the container image to a registry
# and generate the final production docker-compose file.
##

# use the xonsh environment to update the OS environment
$UPDATE_OS_ENVIRON = True
# Get the full log of error
$XONSH_SHOW_TRACEBACK = True
# always return if a cmd fails
$RAISE_SUBPROC_ERROR = True

import os
import xonsh.environ as xenv
from torizon_templates_utils.network import is_in_gitlab_ci_container
from torizon_templates_utils import errors as _errors
from torizon_templates_utils.colors import Color

# helpers for libs that expose attributes dynamically
Error = getattr(_errors, "Error")
def _Error_Out(msg, code):
    # pylint: disable=no-member
    return _errors.Error_Out(msg, code)

## In case of fire break glass
# from torizon_templates_utils import debug
# debug.vscode_prepare()
# debug.breakpoint()

$DOCKER_HOST = ""

if is_in_gitlab_ci_container():
    print("ℹ️ :: GITLAB_CI using docker executor :: ℹ️")
    $DOCKER_HOST = "tcp://docker:2375"

# initialize for pylint's definite-assignment analysis
_docker_psswd = ""
_docker_login = ""
_docker_registry = ""

# check env vars
if "DOCKER_PSSWD" not in os.environ:
    _Error_Out("❌ DOCKER_PSSWD not set", Error.ENOCONF)
else:
    _docker_psswd = os.environ["DOCKER_PSSWD"]

if "DOCKER_LOGIN" not in os.environ:
    _Error_Out("❌ DOCKER_LOGIN not set", Error.ENOCONF)
else:
    _docker_login = os.environ["DOCKER_LOGIN"]

if "DOCKER_REGISTRY" not in os.environ:
    _Error_Out("❌ DOCKER_REGISTRY not set", Error.ENOCONF)
else:
    _docker_registry = os.environ["DOCKER_REGISTRY"]

# For DockerHub it can be empty
if _docker_registry == "registry-1.docker.io":
    _docker_registry = ""

# xonsh env works in a very weird way, so we need to merge the envs
xos = xenv.Env(os.environ)
__xonsh__.env = xos  # pylint: disable=undefined-variable

# Login
print("Performing container registry login ...")

#pylint: disable=line-too-long
echo @(_docker_psswd) | docker login --username @(_docker_login) --password-stdin @(_docker_registry)

print("✅ Logged in the container registry", color=Color.GREEN)

