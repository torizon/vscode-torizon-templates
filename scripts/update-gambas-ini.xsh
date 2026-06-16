#!/usr/bin/env xonsh

# Copyright (c) 2025 Toradex
# SPDX-License-Identifier: MIT

##
# This script is used to update the target device setting on Gambas project
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
_devicePort = sys.argv[3]
_projectName = sys.argv[4]

# read the ini file
config = configparser.ConfigParser()
config.read(f"{_path}/{_projectName}/.settings")

# debug
print(config['Debug']['RemoteServer'])
print("to")
print(_deviceHostname)

# replace
config['Debug']['RemoteServer'] = _deviceHostname
config['Debug']['RemotePort'] = _devicePort

# write the ini file
with open(f"{_path}/{_projectName}/.settings", 'w') as configfile:
    config.write(configfile)
