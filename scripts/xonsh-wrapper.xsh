#!/usr/bin/env xonsh
# pylint: disable=invalid-name
"""
xonsh-wrapper.xsh: read xonsh commands from STDIN and execute them line by line.
"""

# Copyright (c) 2025 Toradex
# SPDX-License-Identifier: MIT

##
# This script is used to automate a wrapper for xonsh scripts
##

# use the xonsh environment to update the OS environment
$UPDATE_OS_ENVIRON = True
# Get the full log of error
$XONSH_SHOW_TRACEBACK = True
# always return if a cmd fails
$RAISE_SUBPROC_ERROR = True

import os
import sys
from xonsh.built_ins import XSH  # provides access to execx via XSH.builtins.execx

try:
    # Open stdin with explicit encoding for linting compliance
    with os.fdopen(sys.stdin.fileno(), "r", encoding="utf-8", errors="replace") as f:
        for line in f:
            line = line.strip()
            if line:
                try:
                    XSH.builtins.execx(line)  # execute xonsh code
                except Exception as e:  # pylint: disable=broad-exception-caught
                    print(f"Error executing line: {line}", file=sys.stderr)
                    raise e
except Exception as e:  # pylint: disable=broad-exception-caught
    print(e, file=sys.stderr)
    os._exit(69)

