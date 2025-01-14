#!/usr/bin/env xonsh

import os
import sys
import requests

# FIXME: ONLY CHANGE THIS WHEN UPDATING THE TorizonPlatformAPI version
_VERSION = "0.2.2"

# fail fast checks
if "PLATFORM_CLIENT_ID" not in $ENV or not $PLATFORM_CLIENT_ID.strip():
    print("\x1b[31mPLATFORM_CLIENT_ID not set\x1b[0m")
    sys.exit("PLATFORM_CLIENT_ID not set")

if "PLATFORM_CLIENT_SECRET" not in $ENV or not $PLATFORM_CLIENT_SECRET.strip():
    print("\x1b[31mPLATFORM_CLIENT_SECRET not set\x1b[0m")
    sys.exit("PLATFORM_CLIENT_SECRET not set")

# We'll store the base URL and token globally after retrieval
BASE_URL = "https://app.torizon.io/api/v2beta"
TOKEN = None

def _getJonOsterToken():
    url = "https://kc.torizon.io/auth/realms/ota-users/protocol/openid-connect/token"
    headers = {
        "Content-Type": "application/x-www-form-urlencoded"
    }
    payload = {
        "grant_type": "client_credentials",
        "client_id": $PLATFORM_CLIENT_ID,
        "client_secret": $PLATFORM_CLIENT_SECRET
    }
    r = requests.post(url, data=payload, headers=headers)
    r.raise_for_status()
    data = r.json()
    return data["access_token"]

# Configure API client by setting global token
TOKEN = _getJonOsterToken()

def api_headers():
    return {
        "Authorization": f"Bearer {TOKEN}",
        "Accept": "application/json"
    }

# The following functions must replicate the behavior of the PowerShell module calls.
# Without official docs, we guess endpoints and JSON shapes.

def get_all_packages():
    # Guessing endpoint: GET /packages
    url = f"{BASE_URL}/packages"
    # If pagination or limit is needed, adapt accordingly
    # Original uses -Limit [System.Int64]::MaxValue to get all, we assume all returned
    r = requests.get(url, headers=api_headers())
    r.raise_for_status()
    return r.json()  # expected {'values': [...], 'total': ...}

def get_all_fleets():
    url = f"{BASE_URL}/fleets"
    r = requests.get(url, headers=api_headers())
    r.raise_for_status()
    return r.json()  # {'values': [...], 'total': ...}

def get_fleet_devices(fleet_id):
    # In PowerShell: Get-TorizonPlatformAPIFleetsFleetidDevices
    url = f"{BASE_URL}/fleets/{fleet_id}/devices"
    r = requests.get(url, headers=api_headers())
    r.raise_for_status()
    return r.json() # {'values': [...], 'total': ...}

def submit_package(packageName, version, dockerComposePath):
    # Guessing endpoint for submitting packages:
    # Possibly POST /packages
    url = f"{BASE_URL}/packages"
    with open(dockerComposePath, 'rb') as f:
        files = {
            'file': f
        }
        data = {
            'name': packageName,
            'version': str(version),
            'hardwareId': 'docker-compose'
        }
        r = requests.post(url, headers=api_headers(), files=files, data=data)
        r.raise_for_status()
        return r.json() # expected to have {'hashes': {'sha256': ...}, ...}

def initialize_update_request(packageIds, fleets):
    # Guess: POST /updates/initialize with payload
    url = f"{BASE_URL}/updates/initialize"
    payload = {
        "packageIds": packageIds,
        "fleets": fleets
    }
    r = requests.post(url, headers=api_headers(), json=payload)
    r.raise_for_status()
    return r.json()

def submit_update_request(updateRequest):
    # Guess: POST /updates
    url = f"{BASE_URL}/updates"
    r = requests.post(url, headers=api_headers(), json=updateRequest)
    r.raise_for_status()
    return r.json()

def _getTargetByHash(_hash):
    packages = get_all_packages()
    for p in packages.get('values', []):
        if p.get('hashes', {}).get('sha256') == _hash:
            return p
    return None

def _getFleetDevices(_fleetName):
    fleets = get_all_fleets()
    fleetId = None
    for f in fleets.get('values', []):
        if f.get('name') == _fleetName:
            fleetId = f.get('id')
            break
    if fleetId is None:
        raise Exception(f"Fleet '{_fleetName}' not found")

    devices = get_fleet_devices(fleetId)
    if devices.get('total',0) == 0:
        raise Exception(f"Fleet '{_fleetName}' has no devices")

    return devices.get('values', [])

def _getFleetId(_fleetName):
    fleets = get_all_fleets()
    for f in fleets.get('values', []):
        if f.get('name') == _fleetName:
            return f.get('id')
    raise Exception(f"Fleet '{_fleetName}' not found")

def _resolvePlatformMetadata(targets, targetName):
    # targets is a dict from get_all_packages
    # We find all packages with that name and pick the highest version
    values = targets.get('values', [])
    latestV = 0
    hsh = None
    for p in values:
        if p.get('name') == targetName:
            v = int(p.get('version',0))
            if v > latestV:
                latestV = v
                hsh = p.get('hashes',{}).get('sha256')
    return {"hash": hsh, "version": latestV}

def package_new(packageName, dockerComposePath):
    # Check file
    if not os.path.exists(dockerComposePath):
        print(f"\x1b[31mFile {dockerComposePath} not found\x1b[0m")
        sys.exit(404)

    ver = package_latest_version(packageName)
    if ver and int(ver) > 0:
        ver = int(ver)+1
    else:
        ver = 1

    ret = submit_package(packageName, ver, dockerComposePath)
    return ret['hashes']['sha256']

def package_latest_hash(packageName):
    packages = get_all_packages()
    ret = _resolvePlatformMetadata(packages, packageName)
    hsh = ret["hash"]
    if hsh is None:
        print("\x1b[31mpackage not found\x1b[0m")
        sys.exit(404)
    return hsh

def package_latest_version(packageName):
    packages = get_all_packages()
    ret = _resolvePlatformMetadata(packages, packageName)
    # returns version (0 if not found)
    return ret["version"]

def update_fleet_latest(targetName, fleetName):
    targetHash = package_latest_hash(targetName)
    target = _getTargetByHash(targetHash)
    if target is None:
        raise Exception(f"package {targetName} not found")

    targetId = target.get('packageId')
    fleetId = _getFleetId(fleetName)

    updateRequest = initialize_update_request([targetId],[fleetId])
    result = submit_update_request(updateRequest)
    return result

# Command parsing
args = $ARGS
if len(args) < 1:
    # show usage
    pass

try:
    # The original uses a pattern: <command> <subcommand> ...
    # Commands supported:
    # package new <package name> <docker-compose.yml path>
    # package latest hash <package name>
    # package latest version <package name>
    # update fleet latest <package name> <fleet name>
    if len(args) == 0:
        raise Exception("No command provided")

    cmd = args[0]
    if cmd == "package":
        if len(args) < 2:
            raise Exception("usage: package new/latest ...")
        sub = args[1]
        if sub == "new":
            if len(args) < 4:
                raise Exception("usage: package new <package name> <docker-compose.yml path>")
            packageName = args[2]
            dockerComposePath = args[3]
            h = package_new(packageName, dockerComposePath)
            print(h)
        elif sub == "latest":
            if len(args) < 3:
                raise Exception("usage: package latest hash|version <package name>")
            sub2 = args[2]
            packageName = args[3] if len(args) > 3 else None
            if sub2 == "hash":
                if packageName is None:
                    raise Exception("usage: package latest hash <package name>")
                h = package_latest_hash(packageName)
                print(h)
            elif sub2 == "version":
                if packageName is None:
                    raise Exception("usage: package latest version <package name>")
                v = package_latest_version(packageName)
                print(v)
            else:
                raise Exception("usage: package latest hash|version <package name>")
        else:
            raise Exception("Unknown package subcommand")

    elif cmd == "update":
        if len(args) < 2:
            raise Exception("usage: update fleet latest <package name> <fleet name>")
        sub = args[1]
        if sub == "fleet":
            if len(args) < 3:
                raise Exception("usage: update fleet latest <package name> <fleet name>")
            sub2 = args[2]
            if sub2 == "latest":
                if len(args) < 5:
                    raise Exception("usage: update fleet latest <package name> <fleet name>")
                packageName = args[3]
                fleetName = args[4]
                res = update_fleet_latest(packageName, fleetName)
                print(res)
            else:
                raise Exception("usage: update fleet latest <package name> <fleet name>")
        else:
            raise Exception("usage: update fleet latest <package name> <fleet name>")
    else:
        # show usage
        print("")
        print("usage:")
        print("")
        print("    Push a new 'docker-compose' package:")
        print("        package new <package name> <docker-compose.yml path>")
        print("    Get the latest hash pushed by package name:")
        print("        package latest hash <package name>")
        print("    Get the latest version pushed by package name:")
        print("        package latest version <package name>")
        print("")
        print("    Update a fleet with a defined package:")
        print("        update fleet latest <package name> <fleet name>")
        print("")
        sys.exit(69)

except Exception as e:
    print(f"\x1b[31m{e}\x1b[0m")
    # No direct ScriptStackTrace equivalent in Python
    import traceback
    lines = traceback.format_exc().splitlines()
    for line in lines:
        print(f"\t{line}\x1b[90m\x1b[0m")
    sys.exit(500)
