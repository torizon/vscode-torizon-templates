"""Network utilities for Torizon Templates."""

import os
import re
import subprocess

def get_host_ip() -> str:
    """Gets the host IP address."""
    if "WSL_DISTRO_NAME" in os.environ and os.environ["WSL_DISTRO_NAME"]:
        command = [
            "/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe",
            "-c",
            # pylint:disable=line-too-long
            '(Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias (Get-NetRoute -DestinationPrefix "0.0.0.0/0").InterfaceAlias).IPAddress',
        ]
        if "APOLLOX_CONTAINER" in os.environ:
            command = [
                "sudo","nsenter","-t","1","-m","-u","-n","-i","--",
                "/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe","-c",
                # pylint: disable=line-too-long
                '(Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias (Get-NetRoute -DestinationPrefix "0.0.0.0/0").InterfaceAlias).IPAddress',
            ]
        result = subprocess.run(command, capture_output=True, text=True, check=False)
        m = re.search(r"((1?\d\d?|2[0-4]\d|25[0-5])\.){3}(1?\d\d?|2[0-4]\d|25[0-5])", result.stdout)
        return m.group(0) if m else ""
    command = ["hostname", "-I"]
    if "APOLLOX_CONTAINER" in os.environ:
        command = ["sudo","nsenter","-t","1","-m","-u","-n","-i","--","hostname","-I"]
    result = subprocess.run(command, capture_output=True, text=True, check=False)
    parts = result.stdout.split()
    return parts[0] if parts else ""

def is_in_docker_container() -> bool:
    """Checks if the current environment is a Docker container."""
    return os.path.exists("/.dockerenv")

def is_in_gitlab_ci_container() -> bool:
    """Checks if the current environment is a GitLab CI container."""
    return "GITLAB_CI" in os.environ and is_in_docker_container()

