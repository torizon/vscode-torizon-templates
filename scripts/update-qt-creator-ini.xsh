#!/usr/bin/env xonsh

# Copyright (c) 2025 Toradex
# SPDX-License-Identifier: MIT

##
# This script is used to update the target device settings for Qt Creator
# Warning: This script is not meant to be run directly
##

# use the xonsh environment to update the OS environment
$UPDATE_OS_ENVIRON = True
# Get the full log of error
$XONSH_SHOW_TRACEBACK = True
# always return if a cmd fails
$XONSH_SUBPROC_CMD_RAISE_ERROR = True

import os
import sys
import configparser


# get arguments
_path = sys.argv[1]
_deviceHostname = sys.argv[2]
_projectName = sys.argv[3]
_deviceArch = sys.argv[4]

config = configparser.ConfigParser(
    empty_lines_in_values=False
)

# maintain the case of the keys
config.optionxform = lambda option: option

config.read(f"{_path}/.qt/QtProject/QtCreator.ini")

# debug
print(config["DebugMode"]["StartApplication\\2\\LastServerAddress"])
print("to")
print(_deviceHostname)

# replace
config["DebugMode"]["StartApplication\\2\\LastServerAddress"] = f"{_deviceHostname}"
config["DebugMode"]["StartApplication\\2\\LastExternalExecutable"] = f"{_path}/build-{_deviceArch}/bin/{_projectName}"
config["DebugMode"]["StartApplication\\2\\LastExternalWorkingDirectory"] = f"{_path}/build-{_deviceArch}/bin"

# write
with open(f"{_path}/.qt/QtProject/QtCreator.ini", "w") as configfile:
    config.write(configfile)
