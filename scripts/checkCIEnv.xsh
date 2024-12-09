#!/usr/bin/env xonsh

import sys

RED = "\x1b[31m"
YELLOW = "\x1b[33m"
RESET = "\x1b[0m"

_envVarsSettings = [
    "DOCKER_REGISTRY",
    "DOCKER_LOGIN",
    "DOCKER_TAG",
    "TCB_CLIENTID",
    "TCB_CLIENTSECRET",
    "TCB_PACKAGE",
    "TCB_FLEET",
    "TORIZON_ARCH"
]

_envVarsSecrets = [
    "DOCKER_PSSWD",
    "PLATFORM_CLIENT_ID",
    "PLATFORM_CLIENT_SECRET",
    "PLATFORM_CREDENTIALS"
]

# Env vars that can be empty
_envVarEmptyAllowed = [
    "DOCKER_REGISTRY"
]

def _gotoError():
    print(f"{YELLOW}\n⚠️ THESE ENV VARIABLES NEED TO BE SET IN YOUR CI/CD ENVIRONMENT\n{RESET}")
    sys.exit(69)

_missingEnvVarSettings = False
_missingEnvVarSecrets  = False

# Check if running in GitLab CI or GitHub Actions
if ("GITLAB_CI" in $ENV and $GITLAB_CI == "true") or ("CI" in $ENV and $CI == "true"):
    # validate the environment variables
    for var in _envVarsSettings:
        if var not in $ENV and var not in _envVarEmptyAllowed:
            print(f"{RED}❌ {var} is not set{RESET}")
            _missingEnvVarSettings = True

    if _missingEnvVarSettings:
        print(f"{RED}Missing settings.json properties, aborting\n{RESET}")

    for var in _envVarsSecrets:
        if var not in $ENV:
            print(f"{RED}❌ {var} is not set{RESET}")
            _missingEnvVarSecrets = True

    if _missingEnvVarSecrets:
        print(f"{RED}Missing protected environment variables, aborting\n{RESET}")

    if _missingEnvVarSettings or _missingEnvVarSecrets:
        _gotoError()
