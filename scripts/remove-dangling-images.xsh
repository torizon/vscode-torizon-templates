#!/usr/bin/env xonsh

import fcntl
import os
import time
import hashlib
from subprocess import run
from torizon_templates_utils.colors import Color, print

# Get the Docker host from args
docker_host = $ARGS[1] if len($ARGS) > 1 else None

if not docker_host:
    print("Missing DOCKER_HOST as argument.", color=Color.RED)
    exit(1)

# Create a host-specific lock file name using a hash to avoid invalid characters on Windows
lock_id = hashlib.md5(docker_host.encode()).hexdigest()
lock_path = f"/tmp/docker-prune-{lock_id}.lock"

lock_fd = open(lock_path, "w")
print(f"Waiting for prune lock on host {docker_host}", color=Color.YELLOW)

# Block until lock is acquired
fcntl.flock(lock_fd, fcntl.LOCK_EX)

try:
    print(f"Pruning dangling images on {docker_host}", color=Color.GREEN)
    $DOCKER_HOST = docker_host
    run(["docker", "image", "prune", "-f", "--filter=dangling=true"])
finally:
    fcntl.flock(lock_fd, fcntl.LOCK_UN)
    lock_fd.close()

