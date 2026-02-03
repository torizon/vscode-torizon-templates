#!/usr/bin/env xonsh

# Copyright (c) 2025 Toradex
# SPDX-License-Identifier: MIT

##
# This script is used to build the utils containers in the right order.
# WARNING:
# This script is not meant to be run manually. It's make part of the internal
# validation process from CI/CD.
##

# use the xonsh environment to update the OS environment
$UPDATE_OS_ENVIRON = True
# Get the full log of error
$XONSH_SHOW_TRACEBACK = True
# always return if a cmd fails
$RAISE_SUBPROC_ERROR = True

import os
import sys
from torizon_templates_utils.errors import Error,Error_Out,last_return_code
from torizon_templates_utils.colors import Color,BgColor,print

if len(sys.argv) != 2:
    print(f"Usage: {sys.argv[0]} <branch>")
    sys.exit(1)

$__TCD_BRANCH = sys.argv[1]
TCD_BRANCH = $__TCD_BRANCH
$__TCD_SHA_DIR = 0
TCD_SHA_DIR = $__TCD_SHA_DIR
# ⚠️ THIS NEED TO BE IN SYNC WITH THE PYTHON UTILS VERSION
$__UTILS_VERSION = "1.2.0"
UTILS_VERSION = $__UTILS_VERSION

# # run the build command
print(f"🔨 :: XONSH :: 🔨", color=Color.GREEN)
docker compose \
    -f ./container/docker-compose.yml \
    build \
    --no-cache \
    --push \
    xonsh

# rename for have the one with the right tag
docker tag \
    @(f"torizonextras/xonsh:{TCD_BRANCH}") \
    @(f"torizonextras/xonsh:{UTILS_VERSION}")

# # run the build command
print(f"🔨 :: TASKS :: 🔨", color=Color.GREEN)
docker compose \
    -f ./container/docker-compose.yml \
    build \
    --no-cache \
    --push \
    tasks

# create a copy with the right versioning tag
docker tag \
    @(f"torizonextras/torizon-dev-tasks:{TCD_BRANCH}") \
    @(f"torizonextras/torizon-dev-tasks:{UTILS_VERSION}")

# # run the build command
print(f"🔨 :: XONSH-WRAPPER :: 🔨", color=Color.GREEN)
docker compose \
    -f ./container/docker-compose.yml \
    build \
    --no-cache \
    --push \
    xonsh-wrapper

# rename for have the one with the right tag
docker tag \
    @(f"torizonextras/xonsh-wrapper:{TCD_BRANCH}") \
    @(f"torizonextras/xonsh-wrapper:{UTILS_VERSION}")

# run the build command
print(f"🔨 :: TORIZON-DEV :: 🔨", color=Color.GREEN)
docker compose \
    -f ./container/docker-compose.yml \
    build \
    --no-cache \
    --push \
    torizon-dev

# rename for have the one with the right tag
docker tag \
    @(f"torizonextras/torizon-dev:{TCD_BRANCH}") \
    @(f"torizonextras/torizon-dev:{UTILS_VERSION}")

# run the build command
print(f"🔨 :: SSH-TUNNEL :: 🔨", color=Color.GREEN)
docker compose \
    -f ./container/docker-compose.yml \
    build \
    --no-cache \
    --push \
    ssh
