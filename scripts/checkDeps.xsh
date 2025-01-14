#!/usr/bin/env xonsh

import os
import sys
import json
from pathlib import Path

RED = "\x1b[31m"
GREEN = "\x1b[32m"
YELLOW = "\x1b[33m"
RESET = "\x1b[0m"

# param() is not needed, as we rely on $ARGS if required
# No arguments used in original script

$DOCKER_HOST = ""

if "GITLAB_CI" in $ENV and $GITLAB_CI == "true":
    print("ℹ️ :: GITLAB_CI :: ℹ️")
    $DOCKER_HOST = "tcp://docker:2375"

# Check docker installed
docker_path = $(which docker)
if docker_path is None or docker_path.strip() == "":
    print(f"{RED}❌ you need docker installed{RESET}")
    sys.exit(69)

# Check docker compose plugin
try:
    out = !(docker compose version)
    if out.returncode != 0:
        print(f"{RED}❌ you need docker compose plugin installed{RESET}")
        sys.exit(69)
except:
    print(f"{RED}❌ you need docker compose plugin installed{RESET}")
    sys.exit(69)

# Load deps.json
with open(".conf/deps.json","r",encoding="utf-8") as f:
    _deps = json.load(f)

_packagesToInstall = []
_scriptsToInstall = []

print(f"{YELLOW}Checking dependencies ...{RESET}")

# Check packages
for package in _deps.get("packages",[]):
    r = !(dpkg -s @(package))
    if r.returncode != 0:
        _packagesToInstall.append(package)
        print(f"{RED}😵 {package} debian package dependency not installed{RESET}")
    else:
        print(f"{GREEN}👍 {package} debian package dependency installed{RESET}")

# Check if scripts have been executed before
depok_path = Path(".conf/.depok")
depok_list = []
if depok_path.exists():
    depok_list = depok_path.read_text(encoding="utf-8").splitlines()

for script in _deps.get("installDepsScripts", []):
    scriptInstalled = False
    if depok_path.exists():
        # Check if script name is in .depok
        if any(script in line for line in depok_list):
            scriptInstalled = True

    if not scriptInstalled:
        _scriptsToInstall.append(script)
        print(f"{RED}😵 {script} dependency installation script not executed before for this project{RESET}")
    else:
        print(f"{GREEN}👍 {script} dependency installation script executed before for this project{RESET}")

# Decide what to do
if len(_packagesToInstall) == 0 and len(_scriptsToInstall) == 0:
    print(f"{GREEN}✅ All packages already installed and installation scripts executed before for this project{RESET}")

    if not depok_path.exists():
        depok_path.parent.mkdir(parents=True, exist_ok=True)
        depok_path.touch()
else:
    # Need user confirmation
    packagesInstalledOk = (len(_packagesToInstall) == 0)
    scriptsInstalledOk = (len(_scriptsToInstall) == 0)

    _installConfirm = input("Try to install the missing debian packages and execute the missing installation scripts? <y/N> ")
    if _installConfirm.lower() == 'y':
        if len(_packagesToInstall) > 0:
            # Update list first
            r = !(sudo apt-get update)
            if r.returncode != 0:
                print(f"{RED}❌ error trying to update package list{RESET}")
                sys.exit(69)

            # Try to install packages
            for item in _packagesToInstall:
                r = !(sudo apt-get install -y @(item))
                if r.returncode != 0:
                    print(f"{RED}❌ error trying to install package {item}{RESET}")
                    sys.exit(69)

            packagesInstalledOk = True

        installedScripts = []
        if len(_scriptsToInstall) > 0:
            # Execute installation scripts
            for item in _scriptsToInstall:
                if item.endswith('.sh'):
                    !(chmod +x @(item))
                r = !./@(item)
                if r.returncode != 0:
                    print(f"{RED}❌ error trying to execute the dependency installation script {item}{RESET}")
                    sys.exit(69)
                installedScripts.append(item)

            scriptsInstalledOk = True

        if packagesInstalledOk and scriptsInstalledOk:
            print(f"{GREEN}✅ All packages installed and installation scripts executed successfully{RESET}")

            if not depok_path.exists():
                depok_path.parent.mkdir(parents=True, exist_ok=True)
                depok_path.touch()

            # Add script names to .depok
            if len(installedScripts) > 0:
                with depok_path.open("a",encoding="utf-8") as f:
                    for s in installedScripts:
                        f.write(s+"\n")
    else:
        # User did not confirm
        # If still missing, we just exit or do nothing?
        # The original script just ends here without installing if user says no.
        pass
