#!/usr/bin/env xonsh

import os
import sys
import json

if len($ARGS) < 3:
    print("Usage: runContainerIfNotExists.xsh <ContainerRuntime> <RunArguments> <ContainerName>")
    sys.exit(1)

ContainerRuntime = $ARGS[0]
RunArguments = $ARGS[1]
ContainerName = $ARGS[2]

$DOCKER_HOST = ""

if "GITLAB_CI" in $ENV and $GITLAB_CI == "true":
    print("ℹ️ :: GITLAB_CI :: ℹ️")
    $DOCKER_HOST = "tcp://docker:2375"

_containerRuntime = ContainerRuntime
_runArguments = RunArguments.strip("'").strip('"')
_containerName = ContainerName

print(f"Container Runtime: {_containerRuntime}")
print(f"Run Arguments: {_runArguments}")
print(f"Container Name: {_containerName}")

# Execute the container inspect command
r = !($"{_containerRuntime} container inspect {_containerName}")

# If the command fails or returns empty, container doesn't exist
if r.returncode != 0 or len(r) == 0:
    # Container does not exist
    print("Container does not exist. Starting ...")
    # Start the container
    cmd = f"{_containerRuntime} run --name {_containerName} {_runArguments}"
    run_result = !($cmd)
    sys.exit(run_result.returncode)
else:
    # We got some JSON output, parse it
    try:
        _containerInfo = json.loads("\n".join(r))
    except json.JSONDecodeError:
        # If not valid JSON, assume container does not exist
        print("Container does not exist. Starting ...")
        cmd = f"{_containerRuntime} run --name {_containerName} {_runArguments}"
        run_result = !($cmd)
        sys.exit(run_result.returncode)

    if isinstance(_containerInfo, list) and len(_containerInfo) > 0:
        _containerInfo = _containerInfo[0]
    else:
        # no valid info means no container
        print("Container does not exist. Starting ...")
        cmd = f"{_containerRuntime} run --name {_containerName} {_runArguments}"
        run_result = !($cmd)
        sys.exit(run_result.returncode)

    print("Container Exists")

    # Check if container is running
    state = _containerInfo.get("State", {})
    running = state.get("Running", False)

    if not running:
        # Start container
        cmd = f"{_containerRuntime} start {_containerName}"
        run_result = !($cmd)
        sys.exit(run_result.returncode)
    else:
        print("Container is running")
        sys.exit(0)
