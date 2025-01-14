#!/usr/bin/env xonsh

import sys
import os
import json

RED = "\x1b[31m"
GREEN = "\x1b[32m"
YELLOW = "\x1b[33m"
RESET = "\x1b[0m"

if len($ARGS) < 1:
    print(f"{RED}❌ Missing architecture argument{RESET}")
    sys.exit(69)

TORIZON_ARCH = $ARGS[0]

TORIZON_ARCHS = ["arm64","armhf","amd64","riscv"]

if TORIZON_ARCH not in TORIZON_ARCHS:
    print(f"{RED}❌ undefined target architecture{RESET}")
    sys.exit(69)

def _getFileLines(file):
    with open(file,"r",encoding="utf-8") as f:
        lines = f.read().splitlines()
    return lines

def _addDepString(value: str):
    # run apt-cache show to determine architecture if needed
    if ":" in value:
        # The arch of package specified explicitly
        return f"\t    {value} \\"
    else:
        # Check architecture via apt-cache
        r = !(apt-cache show @(value))
        value_arch = None
        for line in r:
            if line.startswith("Architecture:"):
                value_arch = line.split(":",1)[1].strip()
                break
        if value_arch == "all":
            return f"\t    {value}:all \\"
        else:
            return f"\t    {value}:{TORIZON_ARCH} \\"

def _ReplaceSection(fileLines, section):
    startIx = None
    endIx = None
    newFileContent = []

    # Find start and end indexes
    ix = 0
    for line in fileLines:
        if f"__{section}_start__" in line:
            startIx = ix
        if f"__{section}_end__" in line:
            endIx = ix
        ix += 1

    ix = 0
    stopAdd = False

    # Load json
    with open("torizonPackages.json","r",encoding="utf-8") as f:
        obj = json.load(f)

    buildPacks = obj.get("buildDeps",[])
    # For backwards compatibility
    devPacks = obj.get("devRuntimeDeps", obj.get("devDeps",[]))
    prodPacks = obj.get("prodRuntimeDeps", obj.get("deps",[]))

    for line in fileLines:
        if ix == startIx:
            newFileContent.append(line)
            stopAdd = True

            if "build" in section:
                for pack in buildPacks:
                    newFileContent.append(_addDepString(pack))
            elif "dev" in section:
                for pack in devPacks:
                    newFileContent.append(_addDepString(pack))
            elif "prod" in section:
                for pack in prodPacks:
                    newFileContent.append(_addDepString(pack))

        if ix == endIx:
            stopAdd = False

        if not stopAdd and ix != startIx:
            newFileContent.append(line)

        ix += 1

    return newFileContent

print("Applying torizonPackages.json ...")

# Dockerfile.debug
if os.path.exists("Dockerfile.debug"):
    print("Applying to Dockerfile.debug ...")
    debugDockerfile = _getFileLines("Dockerfile.debug")
    debugDockerfile = _ReplaceSection(debugDockerfile, "torizon_packages_dev")
    with open("Dockerfile.debug","w",encoding="utf-8") as f:
        f.write("\n".join(debugDockerfile) + "\n")
    print(f"{GREEN}✅ Dockerfile.debug{RESET}")

# Dockerfile.sdk
if os.path.exists("Dockerfile.sdk"):
    print("Applying to Dockerfile.sdk ...")
    debugDockerfileSDK = _getFileLines("Dockerfile.sdk")
    debugDockerfileSDK = _ReplaceSection(debugDockerfileSDK, "torizon_packages_build")
    with open("Dockerfile.sdk","w",encoding="utf-8") as f:
        f.write("\n".join(debugDockerfileSDK) + "\n")
    print(f"{GREEN}✅ Dockerfile.sdk{RESET}")

# Dockerfile
print("Applying to Dockerfile ...")
Dockerfile = _getFileLines("Dockerfile")
Dockerfile = _ReplaceSection(Dockerfile, "torizon_packages_prod")
Dockerfile = _ReplaceSection(Dockerfile, "torizon_packages_build")
with open("Dockerfile","w",encoding="utf-8") as f:
    f.write("\n".join(Dockerfile) + "\n")
print(f"{GREEN}✅ Dockerfile{RESET}")

print("torizonPackages.json applied")
