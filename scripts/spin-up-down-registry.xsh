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
$XONSH_SUBPROC_CMD_RAISE_ERROR = True


import os
import sys
import fcntl
import hashlib
from torizon_templates_utils.args import get_arg_not_empty,get_optional_arg
from torizon_templates_utils.errors import Error,Error_Out

# Locker file path for tracking workspace registrations
LOCKER_FILE = "/tmp/.apollox-registry_locker"


def _parse_locker_entries(lines):
    """
    Parse locker file entries into a workspaces dictionary.

    Args:
        lines: List of lines from the locker file

    Returns:
        Tuple of (workspaces_dict, old_format_detected)
    """
    workspaces = {}
    old_format_detected = False

    for line in lines:
        line = line.strip()
        if line:
            if ":" in line:
                ws_name, ws_hash = line.split(":", 1)
                workspaces[ws_name] = ws_hash
            else:
                # Old format detected (just workspace name)
                old_format_detected = True

    return workspaces, old_format_detected


def _plus_locker(workspace, args_hash) :
    # read or create the .conf/.registry_locker file
    # Use exclusive lock to prevent race conditions
    with open(LOCKER_FILE, "a+") as f:
        fcntl.flock(f.fileno(), fcntl.LOCK_EX)
        try:
            f.seek(0)
            lines = f.readlines()

            # Parse existing workspace entries
            workspaces, _ = _parse_locker_entries(lines)

            # Update or add workspace with its args hash
            workspaces[workspace] = args_hash

            # Write back all workspaces with their hashes
            f.seek(0)
            f.truncate()
            for ws_name, ws_hash in workspaces.items():
                f.write(f"{ws_name}:{ws_hash}\n")
            f.flush()

            return (len(workspaces), workspaces)
        finally:
            fcntl.flock(f.fileno(), fcntl.LOCK_UN)


def _minus_locker(workspace) :
    # read or create the .conf/.registry_locker file
    # Use exclusive lock to prevent race conditions
    with open(LOCKER_FILE, "a+") as f:
        fcntl.flock(f.fileno(), fcntl.LOCK_EX)
        try:
            f.seek(0)
            lines = f.readlines()

            # Parse existing workspace entries
            workspaces, old_format_detected = _parse_locker_entries(lines)

            # If old format was detected, clean up legacy container
            if old_format_detected:
                try:
                    $DOCKER_HOST = ""
                    os.environ["DOCKER_HOST"] = ""
                    docker rm -f torizon-ide-port-tunnel
                except Exception:
                    pass  # Container might not exist

            # Remove workspace if present
            if workspace in workspaces:
                del workspaces[workspace]

            # Write back remaining workspaces with their hashes
            f.seek(0)
            f.truncate()
            for ws_name, ws_hash in workspaces.items():
                f.write(f"{ws_name}:{ws_hash}\n")
            f.flush()

            return (len(workspaces), workspaces)
        finally:
            fcntl.flock(f.fileno(), fcntl.LOCK_UN)


def _get_args_hash(psswd, login, ip):
    """Generate a hash of the container arguments to detect changes."""
    args_str = f"{login}:{ip}"
    return hashlib.sha256(args_str.encode()).hexdigest()


def _get_container_name(args_hash):
    """Generate unique container name based on argument hash."""
    # Use first 8 characters of hash for readability
    hash_suffix = args_hash[:8]
    return f"torizon-ide-port-tunnel-{hash_suffix}"


def _count_workspaces_for_hash(all_workspaces, target_hash):
    """Count how many workspaces are using a specific argument hash."""
    return sum(1 for ws_hash in all_workspaces.values() if ws_hash == target_hash)


def _safe_remove_container_if_unused(container_name, args_hash):
    """
    Safely remove a container only if no workspace is using it.
    Re-checks the locker file with a lock to prevent race conditions.

    Returns:
        True if container was removed, False if still in use
    """
    # Re-check with lock to prevent race condition
    if os.path.exists(LOCKER_FILE):
        with open(LOCKER_FILE, "r") as f:
            fcntl.flock(f.fileno(), fcntl.LOCK_SH)
            try:
                lines = f.readlines()
                workspaces, _ = _parse_locker_entries(lines)

                # Check if any workspace is still using this hash
                count = _count_workspaces_for_hash(workspaces, args_hash)

                if count > 0:
                    # Another workspace registered while we were deciding
                    return False
            finally:
                fcntl.flock(f.fileno(), fcntl.LOCK_UN)

    # Safe to remove - no workspaces using this hash
    $DOCKER_HOST = ""
    os.environ["DOCKER_HOST"] = ""
    docker rm -f @(container_name)
    return True


if len(sys.argv) != 6:
    Error_Out(
        f"Error: Expected 6 arguments, but got {len(sys.argv) -1}.\n" +
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

elif action == "up":
    # Check arguments before locking
    args_hash = _get_args_hash(psswd, login, ip)

    # Generate unique container name for this argument set
    container_name = _get_container_name(args_hash)

    # Add this workspace to the locker
    _plus_locker(workspace, args_hash)

    # Set SSH password in environment so it is not exposed on the command line
    $SSHPASS = psswd
    os.environ["SSHPASS"] = psswd

    # Each unique argument set gets its own container
    $HOME/.local/bin/xonsh ./.conf/run-container-if-not-exists.xsh \
        --container-runtime docker \
        --run-arguments \
        @(f"\"--rm -d --network host -e SSHPASS torizonextras/ide-port-tunnel:0.0.1 sshpass -e ssh -vv -N -R 5002:localhost:5002 -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o PubkeyAuthentication=no {login}@{ip}\"") \
        --container-name \
        @(container_name)

elif action == "down":
    # Get the args hash for this workspace before removing it
    args_hash = _get_args_hash(psswd, login, ip)
    container_name = _get_container_name(args_hash)

    # Remove workspace from locker and get remaining workspaces atomically
    _, remaining_workspaces = _minus_locker(workspace)

    # Check if any remaining workspaces are still using this hash
    workspaces_with_same_hash = _count_workspaces_for_hash(remaining_workspaces, args_hash)

    # Only attempt removal if initially no workspaces are using this hash
    if workspaces_with_same_hash == 0:
        # Re-check with lock right before removal to prevent race condition
        _safe_remove_container_if_unused(container_name, args_hash)
