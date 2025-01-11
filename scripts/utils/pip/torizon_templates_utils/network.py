
import os
import re
import subprocess


def get_host_ip():
    if 'WSL_DISTRO_NAME' in os.environ:
        command = ["/mnt/c/Windows/System32/Wbem/WMIC.exe", "NICCONFIG", "WHERE", "IPEnabled=true", "GET", "IPAddress"]
        result = subprocess.run(command, capture_output=True, text=True)
        ip_address = re.search(r'((1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])\.){3}(1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])', result.stdout)
        if ip_address:
            return ip_address.group(0)
    else:
        command = ["hostname", "-I"]
        result = subprocess.run(command, capture_output=True, text=True)
        return result.stdout.split()[0]
