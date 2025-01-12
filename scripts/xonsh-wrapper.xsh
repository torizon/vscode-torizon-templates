#!/usr/bin/env xonsh

# Copyright (c) 2025 Toradex
# SPDX-License-Identifier: MIT

##
# This script is used to automate a wrapper for xonsh scripts
##

# use the xonsh environment to update the OS environment
$UPDATE_OS_ENVIRON = True
# always return if a cmd fails
$RAISE_SUBPROC_ERROR = True

import os
import sys


try:
    with open(sys.stdin.fileno(), 'r') as f:
        for line in f:
            line = line.strip()
            if line:
                try:
                    execx(line)
                except Exception as e:
                    print(f"Error executing line: {line}", file=sys.stderr)
                    raise e

except Exception as e:
    print(e, file=sys.stderr)
    os._exit(69)
