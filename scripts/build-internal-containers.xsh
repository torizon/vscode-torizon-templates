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
$XONSH_SUBPROC_CMD_RAISE_ERROR = True

import os
import sys
import shutil
import subprocess
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
$__UTILS_VERSION = "1.3.5"
UTILS_VERSION = $__UTILS_VERSION
$__BUILD_PLATFORMS = "linux/amd64,linux/arm64"
BUILD_PLATFORMS = $__BUILD_PLATFORMS
TRUFFLEHOG_IMAGE = "trufflesecurity/trufflehog:latest"

# this script is invoked from ./scripts, so the repo root is one level up; that
# is where the trufflehog exclude list for the image scans lives
REPO_ROOT = os.path.dirname(os.getcwd())
EXCLUDE_FILE = os.path.join(REPO_ROOT, ".exclude-truffle-docker")

# working area for the throwaway root filesystems used only for scanning
SCAN_DIR = os.path.join(os.getcwd(), ".trufflehog-scan")
os.makedirs(SCAN_DIR, exist_ok=True)

STAGE_REGISTRY = "localhost:5000"
STAGE_REGISTRY_NAME = "trufflehog-stage-registry"

subprocess.run(["docker", "rm", "-f", STAGE_REGISTRY_NAME])
docker run -d --rm -p 5000:5000 --name @(STAGE_REGISTRY_NAME) registry:2


def _build_scan_push(name, label, containerfile, tags, build_args=None):
    build_args = build_args or []

    tag_args = []
    for _tag in tags:
        tag_args += ["-t", _tag]

    build_arg_args = []
    for _arg in build_args:
        build_arg_args += ["--build-arg", _arg]

    stage_ref = f"{STAGE_REGISTRY}/{name}:stage"

    print(f"🔨 :: {label} :: 🔨", color=Color.GREEN)

    print(f"🔨 :: {label} :: BUILD 🔨", color=Color.GREEN)
    docker buildx build \
        --platform @(BUILD_PLATFORMS) \
        --no-cache \
        --push \
        -t @(stage_ref) \
        @(build_arg_args) \
        -f @(containerfile) \
        .

    for _platform in BUILD_PLATFORMS.split(","):
        _slug = _platform.replace("/", "-")
        rootfs_tar = os.path.join(SCAN_DIR, f"{name}-{_slug}-rootfs.tar")
        rootfs_dir = os.path.join(SCAN_DIR, f"{name}-{_slug}-rootfs")

        print(f"📦 :: {label} :: EXPORT ROOTFS ({_platform}) 📦", color=Color.GREEN)
        _cid = $(docker create --platform @(_platform) @(stage_ref)).strip()
        docker export @(_cid) -o @(rootfs_tar)
        docker rm @(_cid)

        os.makedirs(rootfs_dir, exist_ok=True)
        # a rootfs tar can contain members tar cannot recreate (device nodes,
        # etc.); those are irrelevant to secret scanning, so tolerate a non-zero
        # tar exit via subprocess.run (which never aborts the xonsh script)
        subprocess.run(["tar", "-xpf", rootfs_tar, "-C", rootfs_dir])

        # guard against a silent-empty extraction that would "scan clean"
        if not any(os.scandir(rootfs_dir)):
            raise Exception(f"rootfs extraction produced nothing for {name} ({_platform})")

        # scan the exported rootfs; --fail makes trufflehog exit non-zero on any
        # finding and, because $XONSH_SUBPROC_CMD_RAISE_ERROR is True, that aborts
        # the whole script before the promotion below
        print(f"🔍 :: {label} :: TRUFFLEHOG SCAN ({_platform}) 🔍", color=Color.GREEN)
        docker run --rm \
            -v @(f"{rootfs_dir}:/rootfs:ro") \
            -v @(f"{EXCLUDE_FILE}:/exclude-truffle-docker:ro") \
            @(TRUFFLEHOG_IMAGE) \
            filesystem \
            /rootfs \
            --exclude-paths=/exclude-truffle-docker \
            --fail \
            --no-update

        # free the disk (and the pulled arch image) before the next architecture
        os.remove(rootfs_tar)
        shutil.rmtree(rootfs_dir)
        subprocess.run(["docker", "image", "rm", stage_ref])

    print(f"🚀 :: {label} :: PUSH 🚀", color=Color.GREEN)
    docker buildx imagetools create @(tag_args) @(stage_ref)


# # run the build command
_build_scan_push(
    "xonsh",
    "XONSH",
    "./container/Containerfile.xonsh",
    [f"torizonextras/xonsh:{TCD_BRANCH}", f"torizonextras/xonsh:{UTILS_VERSION}"],
    [f"BRANCH={TCD_BRANCH}"]
)

# # run the build command
_build_scan_push(
    "torizon-dev-tasks",
    "TASKS",
    "./container/Containerfile.tasks",
    [f"torizonextras/torizon-dev-tasks:{TCD_BRANCH}", f"torizonextras/torizon-dev-tasks:{UTILS_VERSION}"],
    [f"BRANCH={TCD_BRANCH}", "REPO=toradex/vscode-torizon-templates"]
)

# # run the build command
_build_scan_push(
    "xonsh-wrapper",
    "XONSH-WRAPPER",
    "./container/Containerfile.wrapper",
    [f"torizonextras/xonsh-wrapper:{TCD_BRANCH}", f"torizonextras/xonsh-wrapper:{UTILS_VERSION}"],
    [f"BRANCH={TCD_BRANCH}"]
)

# run the build command
_build_scan_push(
    "torizon-dev",
    "TORIZON-DEV",
    "./container/Containerfile.dev",
    [f"torizonextras/torizon-dev:{TCD_BRANCH}", f"torizonextras/torizon-dev:{UTILS_VERSION}"],
    [f"BRANCH={TCD_BRANCH}", f"UID={TCD_UUID}"]
)

# run the build command
_build_scan_push(
    "ide-port-tunnel",
    "SSH-TUNNEL",
    "./container/Containerfile.ssh",
    ["torizonextras/ide-port-tunnel:0.0.1"]
)

# tear down the staging registry (best effort)
subprocess.run(["docker", "rm", "-f", STAGE_REGISTRY_NAME])
