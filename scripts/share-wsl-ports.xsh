#!/usr/bin/env xonsh

# Copyright (c) 2025 Toradex
# SPDX-License-Identifier: MIT

##
# This script is used to open Windows side firewall.
# This is needed to have access to the services running on WSL outside Windows.
##

# use the xonsh environment to update the OS environment
$UPDATE_OS_ENVIRON = True
# Get the full log of error
$XONSH_SHOW_TRACEBACK = True
# this script should handle the subprocess errors
$XONSH_SUBPROC_CMD_RAISE_ERROR = False

import os
import sys
from xonsh.procs.pipelines import CommandPipeline
from torizon_templates_utils.errors import Error, Error_Out, last_return_code
from torizon_templates_utils.colors import Color, BgColor, print


# this only makes sense for WSL
if "WSL_DISTRO_NAME" in os.environ and os.environ["WSL_DISTRO_NAME"] != "":
    home = os.environ["HOME"]
    workspace = sys.argv[1]

    route = !(ip route show default)
    if route.returncode != 0 or not route.out.strip():
        Error_Out(
            "❌ Error: Cannot determine WSL default route",
            Error.EUNKNOWN
        )

    parts = route.out.split()
    if "dev" not in parts:
        Error_Out(
            "❌ Error: Malformed default route output",
            Error.EUNKNOWN
        )

    iface = parts[parts.index("dev") + 1]

    addr_output: CommandPipeline = !(ip -4 -o addr show dev @(iface))

    if addr_output.returncode != 0 or not addr_output.out.strip():
        Error_Out(
            f"❌ Error: Cannot get IPv4 address for interface {iface}",
            Error.EUNKNOWN
        )

    addr_parts = addr_output.out.split()
    if len(addr_parts) < 4:
        Error_Out(
            f"❌ Error: Malformed IPv4 address output for interface {iface}: '{addr_output.out.strip()}'",
            Error.EUNKNOWN
        )
    wsl_ip = addr_parts[3].split("/")[0]

    print(f"Using WSL interface {iface} (IP: {wsl_ip})")

    # Add here all the ports that you want to share with Windows
    ports = [
        8090,
        5002
    ]

    super_script: str = ""
    addr = "0.0.0.0"
    ports_str = ",".join([str(port) for port in ports])

    # remove firewall exception rules
    super_script += "(Remove-NetFireWallRule -DisplayName ApolloX) -or $true ; "

    # adding exception rules for inbound and outbound rules
    super_script += f" New-NetFireWallRule -DisplayName ApolloX -Direction Outbound -LocalPort {ports_str} -Action Allow -Protocol TCP ; "
    super_script += f" New-NetFireWallRule -DisplayName ApolloX -Direction Inbound -LocalPort {ports_str} -Action Allow -Protocol TCP ; "

    # for each port we need to netsh interface
    for port in ports:
        super_script += f" (netsh interface portproxy delete v4tov4 listenport={port} listenaddress={addr}) -or $true ; "

    # FIXME:    this presumes that the xonsh is installed in the default location
    #           that is the user path .local/bin
    super_script += f" wsl -e /{home}/.local/bin/xonsh {workspace}/.vscode/tasks.xsh run run-docker-registry-wsl ; "

    # add portproxy rules targeting the WSL interface
    for port in ports:
        super_script += f" (netsh interface portproxy add v4tov4 listenport={port} listenaddress={addr} connectport={port} connectaddress={wsl_ip}) -or $true ; "

    # hmmm 😏
    super_script = super_script.strip()

    if "DEBUG_SHARED_PORTS" in os.environ:
        print(f"start-process powershell -verb runas -ArgumentList '-NoProfile -C \"{super_script} echo done\"'")
        powershell.exe -NoProfile -C @(f"start-process powershell -verb runas -ArgumentList '-NoProfile -C \"{super_script} echo done; Read-Host ; \"'")
    else:
        powershell.exe -NoProfile -C @(f"start-process powershell -verb runas -ArgumentList '-NoProfile -C \"{super_script} echo done\"'")
