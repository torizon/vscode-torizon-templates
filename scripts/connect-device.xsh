#!/usr/bin/env xonsh

# Copyright (c) 2025 Toradex
# SPDX-License-Identifier: MIT

##
# This script is used to configure a Torizon device to be ready for development.
# WARNING:
# This script is not meant to be run manually. It is called by the Zygote.
##

# use the xonsh environment to update the OS environment
$UPDATE_OS_ENVIRON = True
# always return if a cmd fails
$RAISE_SUBPROC_ERROR = True

import os
import sys
import tty
import json
import getpass
import termios
from torizon_templates_utils.network import get_host_ip
from torizon_templates_utils.errors import Error,Error_Out
from torizon_templates_utils.colors import Color,BgColor,print
from torizon_templates_utils.animations import run_command_with_wait_animation


$SCRIPT_PATH = os.path.dirname(os.path.realpath(__file__))


# 🤡
def masked_input(prompt=''):
    print(prompt, end='', flush=True)
    fd = sys.stdin.fileno()
    old_settings = termios.tcgetattr(fd)
    try:
        tty.setraw(fd)
        password = ''
        while True:
            ch = sys.stdin.read(1)
            if ch == '\n' or ch == '\r':
                print('')
                break
            elif ch == '\x7f':  # Handle backspace
                if len(password) > 0:
                    password = password[:-1]
                    print('\b \b', end='', flush=True)
            else:
                password += ch
                print('*', end='', flush=True)
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)
    return password


_id = sys.argv[1]


print("📡 :: CONNECTING DEVICE :: 📡")
print("")

_connected_devs = None

if os.path.exists(f"{os.environ['HOME']}/.tcd/connected.json"):
    with open(f"{os.environ['HOME']}/.tcd/connected.json", "r") as f:
        _connected_devs = json.load(f)

with open(f"{os.environ['HOME']}/.tcd/scan.json", "r") as f:
    _net = json.load(f)

# get the reference
dev = None
_ix = 0
for _dev in _net:
    if _ix == int(_id):
        dev = _dev
        break
    _ix += 1

if _connected_devs != None:
    for __dev in _connected_devs:
        if __dev["Ip"] == dev["Ip"] or __dev["Hostname"] == dev["Hostname"]:
            print(
                f"\t ⚠️ :: Device [{dev['Hostname']}] already connected :: ⚠️",
                color=Color.YELLOW
            )

            sys.exit(0)
else:
    _connected_devs = []

_hostname = dev["Hostname"]
_ip = dev["Ip"]

print("")
_login = input("Login> ")
_password = masked_input("Password> ")
print("")

# check login sanity
if _login == "":
    Error_Out(
        "❌ :: Login cannot be empty :: ❌",
        Error.EUSER
    )

if _password == "":
    Error_Out(
        "❌ :: Password cannot be empty :: ❌",
        Error.EUSER
    )

# all ok, try to connect
print(f"\t Trying to connect to [{_hostname}]")
print("")


def __try_connect_dev():
    _host_ip = get_host_ip()

    cd $SCRIPT_PATH

    node ./node/connectNetworkDevice.mjs \
        @(_id) \
        @(_login) \
        @(_password) \
        @(_host_ip)


try:
    run_command_with_wait_animation(__try_connect_dev)
except e:
    _short_error = repr(e)
    Error_Out(
        f"❌ :: Could not connect to device :: {_short_error} ❌",
        Error.EUNKNOWN
    )

with open(f"{os.environ['HOME']}/.tcd/connected.json", "r") as f:
    _connected_devs = json.load(f)

_dev = None
for __dev in _connected_devs:
    if __dev["Ip"] == dev["Ip"] or __dev["Hostname"] == dev["Hostname"]:
        _dev = __dev

# display the data
print("")
print(f"\t 🎉 :: Device [{_hostname}] connected :: 🎉", color=Color.GREEN)
print("")
print(f"\t Hostname: {_hostname}")
print(f"\t IP Addr: {_ip}")
print(f"\t Torizon Ver: {_dev['Version']}")
print(f"\t HW Model: {_dev['Model']}")
print(f"\t HW Arch: {_dev['Arch']}")
