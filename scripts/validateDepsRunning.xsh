#!/usr/bin/env xonsh

import os
import sys

RED = "\x1b[31m"
GREEN = "\x1b[32m"
YELLOW = "\x1b[33m"
RESET = "\x1b[0m"

$DOCKER_HOST = ""

if "GITLAB_CI" in $ENV and $GITLAB_CI == "true":
    print("ℹ️ :: GITLAB_CI :: ℹ️")
    $DOCKER_HOST = "tcp://docker:2375"

_envVarsSettings = [
    "TORIZON_PSSWD",
    "TORIZON_LOGIN",
    "HOST_IP",
    "TORIZON_IP",
    "TORIZON_ARCH"
]

print(f"{YELLOW}\n⚠️ VALIDATING ENVIRONMENT\n{RESET}")

_missingEnvVarSettings = False

# validate the environment variables
for var in _envVarsSettings:
    if var not in $ENV or $ENV[var].strip() == "":
        _missingEnvVarSettings = True

if _missingEnvVarSettings:
    print(f"{RED}❌ Missing settings.json properties, aborting\n{RESET}")
    print(f"{YELLOW}⚠️  Did you forget to set default device?")
    print("If you are facing issues even after setting default device, please remove the registered device and connect it again.\n")
    sys.exit(69)

# check if docker is running
docker_info = !(docker info)
if docker_info.returncode != 0:
    print(f"{RED}❌ Docker is not running!\n{RESET}")
    print(f"{RED}⚠️  Please start Docker{RESET}")
    print(f"{RED}⚠️  Please make sure to reload the VS Code window after starting Docker{RESET}")
    sys.exit(69)

# check if the docker container with name registry is running
docker_ps_registry = !(docker ps -q -f name=registry)
if len(docker_ps_registry) == 0:
    print(f"{RED}❌ Docker container registry is not running!\n{RESET}")
    print(f"{RED}⚠️  Please make sure to reload the VS Code Window if you had initialization errors{RESET}")
    sys.exit(69)

print(f"{GREEN}\n✅ Environment is valid!\n{RESET}")
