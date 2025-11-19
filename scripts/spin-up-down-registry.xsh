#!/usr/bin/env xonsh

# Copyright (c) 2025 Toradex
# SPDX-License-Identifier: MIT

##
# This script is used to manage race conditions when spinning up and down
# the torizon-ide-port-tunnel container.
##

# use the xonsh environment to update the OS environment
$UPDATE_OS_ENVIRON = True
# Get the full log of error
$XONSH_SHOW_TRACEBACK = True
# always return if a cmd fails
$RAISE_SUBPROC_ERROR = True


import os
import sys
import fcntl
from torizon_templates_utils.args import get_arg_not_empty,get_optional_arg
from torizon_templates_utils.errors import Error,Error_Out


def _plus_locker(workspace) :
    # read or create the .conf/.registry_locker file
    locker_file = os.path.join(
        "/tmp",
        ".apollox-registry_locker"
    )

    # Use exclusive lock to prevent race conditions
    with open(locker_file, "a+") as f:
        fcntl.flock(f.fileno(), fcntl.LOCK_EX)
        try:
            f.seek(0)
            lines = f.readlines()

            # Parse existing workspace entries
            workspaces = set()
            for line in lines:
                line = line.strip()
                if line:
                    workspaces.add(line)

            # Add workspace if not already present
            if workspace not in workspaces:
                workspaces.add(workspace)

            # Write back all workspaces
            f.seek(0)
            f.truncate()
            for ws_name in workspaces:
                f.write(f"{ws_name}\n")
            f.flush()

            return len(workspaces)
        finally:
            fcntl.flock(f.fileno(), fcntl.LOCK_UN)


def _minus_locker(workspace) :
    # read or create the .conf/.registry_locker file
    locker_file = os.path.join(
        "/tmp",
        ".apollox-registry_locker"
    )

    # Use exclusive lock to prevent race conditions
    with open(locker_file, "a+") as f:
        fcntl.flock(f.fileno(), fcntl.LOCK_EX)
        try:
            f.seek(0)
            lines = f.readlines()

            # Parse existing workspace entries
            workspaces = set()
            for line in lines:
                line = line.strip()
                if line:
                    workspaces.add(line)

            # Remove workspace if present
            if workspace in workspaces:
                workspaces.remove(workspace)

            # Write back remaining workspaces
            f.seek(0)
            f.truncate()
            for ws_name in workspaces:
                f.write(f"{ws_name}\n")
            f.flush()

            return len(workspaces)
        finally:
            fcntl.flock(f.fileno(), fcntl.LOCK_UN)


if len(sys.argv) != 6:
    Error_Out(
        f"Error: Expected 6 argument, but got {len(sys.argv) -1}.\n" +
        "Report on https://github.com/torizon/vscode-torizon-templates/issues",
        Error.EINVAL
    )

action = get_arg_not_empty(1)
psswd = get_arg_not_empty(2)
login = get_arg_not_empty(3)
ip = get_arg_not_empty(4)
workspace = get_arg_not_empty(5)

if action not in ["up","down"]:
    Error_Out(
        f"Error: Invalid argument '{action}'. Expected 'up' or 'down'.\n" +
        "Report on https://github.com/torizon/vscode-torizon-templates/issues",
        Error.EINVAL
    )

if action == "up":
    _plus_locker(workspace)

    $HOME/.local/bin/xonsh ./.conf/run-container-if-not-exists.xsh \
        --container-runtime docker \
        --run-arguments \
        @(f"\"--rm -d --network host torizonextras/ide-port-tunnel:0.0.0 sshpass -p {psswd} ssh -vv -N -R 5002:localhost:5002 -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o PubkeyAuthentication=no {login}@{ip}\"") \
        --container-name \
        torizon-ide-port-tunnel

    sys.exit(0)


if action == "down":
    count = _minus_locker(workspace)

    # just remove the container if no one is using it
    if count == 0:
        $DOCKER_HOST = ""
        os.environ["DOCKER_HOST"] = ""

        docker rm -f torizon-ide-port-tunnel

    sys.exit(0)
