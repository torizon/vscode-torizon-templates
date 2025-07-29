#!/usr/bin/env xonsh
"""
remove-dangling-images.xsh: prune dangling Docker images on a given DOCKER_HOST,
using a per-host file lock to avoid concurrent prunes.
"""
# pylint: disable=invalid-name

import sys
import fcntl
import os
import hashlib
from subprocess import run
from torizon_templates_utils.colors import Color

# Read DOCKER_HOST from CLI args
args = sys.argv
docker_host = args[1] if len(args) > 1 else None
if not docker_host:
    print("Missing DOCKER_HOST as argument.", color=Color.RED)
    sys.exit(1)

# Per-host lock file (hash avoids invalid filename chars)
LOCK_ID = hashlib.md5(docker_host.encode()).hexdigest()
LOCK_PATH = f"/tmp/docker-prune-{LOCK_ID}.lock"

print(f"Waiting for prune lock on host {docker_host}", color=Color.YELLOW)

# Hold the lock for the duration of the prune
with open(LOCK_PATH, "w", encoding="utf-8") as lock_fd:
    fcntl.flock(lock_fd, fcntl.LOCK_EX)
    try:
        print(f"Pruning dangling images on {docker_host}", color=Color.GREEN)
        os.environ["DOCKER_HOST"] = docker_host
        run(["docker", "image", "prune", "-f", "--filter=dangling=true"], check=False)
    finally:
        fcntl.flock(lock_fd, fcntl.LOCK_UN)

# Cleanup lock file
if os.path.exists(LOCK_PATH):
    os.remove(LOCK_PATH)

