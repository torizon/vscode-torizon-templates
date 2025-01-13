#!/usr/bin/env xonsh

# Copyright (c) 2025 Toradex
# SPDX-License-Identifier: MIT

##
# This script is used to list the built in device tree overlays
# WARNING:
# This script is not intended to be executed directly, but rather
# to be called by zygote.
##

# use the xonsh environment to update the OS environment
$UPDATE_OS_ENVIRON = True
# always return if a cmd fails
$RAISE_SUBPROC_ERROR = False

import os
import sys
import json
from torizon_templates_utils.errors import Error,Error_Out
from torizon_templates_utils.colors import Color,BgColor,print
from torizon_templates_utils.animations import run_command_with_wait_animation

_login = sys.argv[1] if len(sys.argv) >= 1 else None
_pass = sys.argv[2] if len(sys.argv) >= 2 else None
_ip = sys.argv[3] if len(sys.argv) >= 3 else None

if _login is None or _pass is None or _ip is None:
    print("invalid arguments")
    os._exit(69)


def __dev_list():
    return !(node ./node/listDeviceTreeOverlays.mjs \
                @(_ip) \
                @(_login) \
                @(_pass))


dev_list = run_command_with_wait_animation(__dev_list)

if dev_list.returncode != 0:
    Error_Out(
        f"Error listing device tree overlays :: [{dev_list.returncode}] :: {dev_list.err}",
        Error.EFAIL
    )
else:
    try:
        dev_list_obj = json.loads(dev_list.out)
    except Exception as e:
        Error_Out(
            f"Error parsing device tree overlays :: {repr(e)}",
            Error.EFAIL
        )

    print("")
    print("🌳 :: DEVICE TREE OVERLAYS :: 🌳")
    print("")

    for dev in dev_list_obj:
        print(f"\t{dev}")
        print("")
