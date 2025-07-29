#!/usr/bin/env xonsh
"""
check-ci-env.xsh: verify CI environment variables and fail fast if missing.
"""
# pylint: disable=invalid-name

# Copyright (c) 2025 Toradex
# SPDX-License-Identifier: MIT

##
# This script is used to verify the sanity of the CI environment.
# Is useful to show to the user the env that should be set
# and fail fast if something is missing.
##

# use the xonsh environment to update the OS environment
$UPDATE_OS_ENVIRON = True
# Get the full log of error
$XONSH_SHOW_TRACEBACK = True
# this script should handle the subprocess errors
$RAISE_SUBPROC_ERROR = False

import os
from torizon_templates_utils import errors as _errors
from torizon_templates_utils.colors import Color, BgColor

_env_vars_settings = [
    "DOCKER_REGISTRY",
    "DOCKER_LOGIN",
    "DOCKER_TAG",
    "TCB_CLIENTID",
    "TCB_CLIENTSECRET",
    "TCB_PACKAGE",
    "TCB_FLEET",
]

_env_vars_secrets = [
    "DOCKER_PSSWD",
    "PLATFORM_CLIENT_ID",
    "PLATFORM_CLIENT_SECRET",
    "PLATFORM_CREDENTIALS",
]

_env_vars_file_path = [
    "TORIZON_CI_SETTINGS_FILE",
]

_env_vars_empty_allowed = [
    "DOCKER_REGISTRY",
]


def _goto_error():
    _errors.Error_Out(  # pylint: disable=no-member
        "\n❌ THESE ENV VARIABLES NEED TO BE SET IN YOUR CI/CD ENVIRONMENT. Aborting ...\n",
        _errors.Error.ENOCONF,
    )


MISSING_ENV_VAR_SETTINGS = False
MISSING_ENV_VAR_SECRETS = False
MISSING_ENV_VAR_FILE_PATH = False

# check if we are running in a GitLab CI or GitHub Actions environment
if "CI" in os.environ:
    # validate the env vars
    for _env_var in _env_vars_settings:
        if _env_var not in os.environ and _env_var not in _env_vars_empty_allowed:
            MISSING_ENV_VAR_SETTINGS = True
            print(f"❌ {_env_var} is not set and is required", color=Color.RED)

    if MISSING_ENV_VAR_SETTINGS:
        # pylint: disable=line-too-long
        print(
            " ⚠️ Missing settings.json variables \n",
            color=Color.BLACK,
            bg_color=BgColor.BRIGTH_YELLOW,
        )

    for _env_var in _env_vars_secrets:
        if _env_var not in os.environ and _env_var not in _env_vars_empty_allowed:
            MISSING_ENV_VAR_SECRETS = True
            print(f"❌ {_env_var} is not set and is required", color=Color.RED)

    if MISSING_ENV_VAR_SECRETS:
        # pylint: disable=line-too-long
        print(
            " ⚠️ Missing protected environment variables. Be sure to protect them using secrets or other mechanism from your CI/CD service provider. \n",
            color=Color.BLACK,
            bg_color=BgColor.BRIGTH_YELLOW,
        )

    for _env_var in _env_vars_file_path:
        if _env_var not in os.environ:
            MISSING_ENV_VAR_FILE_PATH = True
            print(f"❌ {_env_var} is not set and is required", color=Color.RED)
        elif not os.path.exists(os.environ[_env_var]):
            MISSING_ENV_VAR_FILE_PATH = True
            print(f"❌ No file at the path set in {_env_var} variable", color=Color.RED)

    if MISSING_ENV_VAR_FILE_PATH:
        # pylint: disable=line-too-long
        print(
            " ⚠️ Missing variable or with wrong file path \n",
            color=Color.BLACK,
            bg_color=BgColor.BRIGTH_YELLOW,
        )

    # pylint: disable=line-too-long
    if (
        MISSING_ENV_VAR_SETTINGS
        or MISSING_ENV_VAR_SECRETS
        or MISSING_ENV_VAR_FILE_PATH
    ):
        _goto_error()

