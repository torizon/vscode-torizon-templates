#!/usr/bin/env xonsh

# Copyright (c) 2025 Toradex
# SPDX-License-Identifier: MIT

##
# This script is used to check if some service is running under ssh remote
##

# use the xonsh environment to update the OS environment
$UPDATE_OS_ENVIRON = True
# Get the full log of error
$XONSH_SHOW_TRACEBACK = True
# always return if a cmd fails
$RAISE_SUBPROC_ERROR = True


import os
import sys
import json
import time
import subprocess
from torizon_templates_utils.args import get_arg_not_empty,get_optional_arg
from torizon_templates_utils.errors import Error,Error_Out



if len(sys.argv) != 7:
    Error_Out(
        f"Error: Expected 7 arguments, but got {len(sys.argv) -1}.\n" +
        "Report on https://github.com/torizon/vscode-torizon-templates/issues",
        Error.EINVAL
    )


service_name = get_arg_not_empty(1)
torizon_psswd = get_arg_not_empty(2)
torizon_ssh_port = get_arg_not_empty(3)
torizon_user = get_arg_not_empty(4)
torizon_ip = get_arg_not_empty(5)
service_check = get_arg_not_empty(6)

MAX_ATTEMPTS = 15
TIMEOUT_SECONDS = 5
SLEEP_INTERVAL = 1


for i in range(1, MAX_ATTEMPTS + 1):
    try:
        with ${...}.swap(RAISE_SUBPROC_ERROR=False):
            result = !( \
                sshpass \
                    -p @(torizon_psswd) \
                    ssh \
                    -p @(torizon_ssh_port) \
                    -o UserKnownHostsFile=/dev/null \
                    -o StrictHostKeyChecking=no \
                    -o PubkeyAuthentication=no \
                    @(torizon_user)@@(torizon_ip) @(service_check) \
            )

        if result.returncode == 0:
            print('Registry ready')
            sys.exit(0)

    except Exception as e:
        print(f"Exception occurred: {e}")

    print(f"Attempt {i}/{MAX_ATTEMPTS}: waiting for {service_name}...")
    time.sleep(SLEEP_INTERVAL)


Error_Out(
    "Max attempts reached\n" +
    f"Was not possible to get a response from the {service_name}",
    Error.EFAIL
)
