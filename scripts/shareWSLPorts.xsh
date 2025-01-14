#!/usr/bin/env xonsh

import os
import sys
import re

if "WSL_DISTRO_NAME" in $ENV and $WSL_DISTRO_NAME.strip() != "":
    if len($ARGS) < 1:
        print("Usage: shareWSLPorts.xsh <workspace_path>")
        sys.exit(1)

    _workspace = $ARGS[0]

    # Get the WSL IP:
    remoteport_output = !(bash -c "ifconfig eth0 | grep 'inet '")
    remoteport_str = "\n".join(remoteport_output)

    # Regex to find IP
    match = re.search(r'\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}', remoteport_str)
    if match:
        remoteport = match.group(0)
    else:
        print("The Script Exited, the IP address of WSL 2 cannot be found")
        sys.exit(1)

    # Ports to forward
    ports = [8090, 5002]
    addr = '0.0.0.0'
    ports_a = ",".join(str(p) for p in ports)

    # Build the PowerShell superScript
    # Remove Firewall Exception Rules
    superScript = "(Remove-NetFireWallRule -DisplayName ApolloX) -or $true ; "

    # Add Exception Rules
    superScript += f"New-NetFireWallRule -DisplayName ApolloX -Direction Outbound -LocalPort {ports_a} -Action Allow -Protocol TCP ; "
    superScript += f"New-NetFireWallRule -DisplayName ApolloX -Direction Inbound -LocalPort {ports_a} -Action Allow -Protocol TCP ; "

    # Remove existing portproxy rules
    for port in ports:
        superScript += f"(netsh interface portproxy delete v4tov4 listenport={port} listenaddress={addr}) -or $true ; "

    # Run the run-docker-registry-wsl task
    superScript += f"wsl -e pwsh -nop -File {_workspace}/.vscode/tasks.ps1 run run-docker-registry-wsl ; "

    # Add portproxy again
    for port in ports:
        superScript += f"(netsh interface portproxy add v4tov4 listenport={port} listenaddress={addr} connectport={port} connectaddress={remoteport}) -or $true ; "

    superScript = superScript.strip()

    # If DEBUG_SHARED_PORTS is true
    debug_shared_ports = False
    if "DEBUG_SHARED_PORTS" in $ENV and $DEBUG_SHARED_PORTS.lower() == "true":
        debug_shared_ports = True

    # Build the command to run as admin on Windows
    # The original uses powershell.exe and start-process
    # We'll try to replicate the same command structure:
    if debug_shared_ports:
        # includes Read-Host
        final_cmd = f"start-process powershell -verb runas -ArgumentList '-NoProfile -C \"{superScript} echo done; Read-Host ; \"'"
    else:
        final_cmd = f"start-process powershell -verb runas -ArgumentList '-NoProfile -C \"{superScript} echo done\"'"

    # Run this command via powershell.exe in WSL:
    # This requires powershell.exe accessible from WSL (usually possible if you're using WSL interop)
    !(powershell.exe -NoProfile -C @(final_cmd))
