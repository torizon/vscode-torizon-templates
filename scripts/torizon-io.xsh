#!/usr/bin/env xonsh
"""
torizon-io.xsh: small CLI wrapper around the Torizon Cloud (v2beta) API
to push docker-compose packages and trigger fleet updates.
"""
#pylint: disable=invalid-name
# always return if a cmd fails
$RAISE_SUBPROC_ERROR = True
# use the xonsh environment to update the OS environment
$UPDATE_OS_ENVIRON = True
# Get the full log of error
$XONSH_SHOW_TRACEBACK = True

import os
import sys
import traceback
from typing import List

import requests  # pylint: disable=import-error
import torizon_io_api as torizon_cloud  # pylint: disable=import-error
from torizon_templates_utils.errors import (  # pylint: disable=no-name-in-module
    Error,
    Error_Out,
)

# fail fast
if "PLATFORM_CLIENT_ID" not in os.environ:
    Error_Out("❌ Environment variable PLATFORM_CLIENT_ID not set", Error.ENOCONF)

if "PLATFORM_CLIENT_SECRET" not in os.environ:
    Error_Out("❌ Environment variable PLATFORM_CLIENT_SECRET not set", Error.ENOCONF)


def __get_jon_oster_token() -> str:
    """Obtain OAuth token from Keycloak using client credentials."""
    headers = {"Content-Type": "application/x-www-form-urlencoded"}
    payload = {
        "grant_type": "client_credentials",
        "client_id": os.environ.get("PLATFORM_CLIENT_ID"),
        "client_secret": os.environ.get("PLATFORM_CLIENT_SECRET"),
    }

    response = requests.post(
        "https://kc.torizon.io/auth/realms/ota-users/protocol/openid-connect/token",
        headers=headers,
        data=payload,
        timeout=60,
    )
    response.raise_for_status()
    # And we have the AWESOME Jon Oster Token 🦪
    return response.json().get("access_token", "")


_token = __get_jon_oster_token()
_cfg = torizon_cloud.Configuration(host="https://app.torizon.io/api/v2beta", access_token=_token)


def __get_target_by_hash(_hash: str) -> torizon_cloud.Package:
    """Fetch a package object by its sha256 hash."""
    with torizon_cloud.ApiClient(_cfg) as api_client:
        api = torizon_cloud.PackagesApi(api_client)
        packages = api.get_packages(limit=sys.maxsize, hashes=[_hash])

        if packages.total == 0:
            Error_Out(f"❌ Package with hash {_hash} not found", Error.ENOFOUND)

        return packages.values.pop()


def __get_fleed_id(fleet_name: str) -> str:
    """Resolve a fleet name to its ID."""
    with torizon_cloud.ApiClient(_cfg) as api_client:
        api = torizon_cloud.FleetsApi(api_client)
        fleets = api.get_fleets(limit=sys.maxsize)

        fleet_id = None
        for fleet in fleets.values:
            if fleet.name == fleet_name:
                fleet_id = fleet.id
                break

        if fleet_id is None:
            Error_Out(f"❌ Fleet {fleet_name} not found", Error.ENOFOUND)

        return fleet_id


def __get_fleet_devices(fleet_name: str):
    """Return device list for a given fleet name."""
    fleet_id = __get_fleed_id(fleet_name)
    with torizon_cloud.ApiClient(_cfg) as api_client:
        api = torizon_cloud.FleetsApi(api_client)
        devices = api.get_fleets_fleetid_devices(fleet_id=fleet_id, limit=sys.maxsize)
        return devices.values


def __resolve_platform_metadata(
    packages: List[torizon_cloud.Package], package_name: str
) -> dict:
    """From a list of packages with same name, return latest version and hash."""
    latest_version = 0
    latest_hash = None

    for package in packages:
        if package.name == package_name:
            if int(package.version) > latest_version:
                latest_version = int(package.version)
                latest_hash = package.hashes["sha256"]

    return {"hash": latest_hash, "version": latest_version if latest_hash else None}


def package_new(package_name: str, docker_compose_path: str) -> None:
    """Create a new docker-compose package with version bumped from latest."""
    if not os.path.exists(docker_compose_path):
        Error_Out(f"❌ File {docker_compose_path} not found", Error.ENOFOUND)

    # read the file
    with open(docker_compose_path, "rb") as f:
        compose_content = f.read()

    # get the latest version and increment it
    ver = package_latest_version(package_name)
    ver = int(ver) + 1

    # push it
    with torizon_cloud.ApiClient(_cfg) as api_client:
        api = torizon_cloud.PackagesApi(api_client)
        ret = api.post_packages(
            name=package_name,
            version=str(ver),
            target_format="BINARY",
            content_length=len(compose_content),
            body=compose_content,
            hardware_id=["docker-compose"],
        )
        print(ret.hashes["sha256"])


def package_latest_hash(package_name: str) -> str:
    """Print and return the latest package hash for a given name."""
    with torizon_cloud.ApiClient(_cfg) as api_client:
        api = torizon_cloud.PackagesApi(api_client)
        packages = api.get_packages(limit=sys.maxsize, name_contains=package_name)

        meta = __resolve_platform_metadata(packages.values, package_name)
        if meta["hash"] is None:
            Error_Out(f"❌ Package {package_name} not found", Error.ENOFOUND)

        print(meta["hash"])
        return str(meta["hash"])


def package_latest_version(package_name: str) -> int:
    """Print and return the latest version for a given package name."""
    with torizon_cloud.ApiClient(_cfg) as api_client:
        api = torizon_cloud.PackagesApi(api_client)
        packages = api.get_packages(limit=sys.maxsize, name_contains=package_name)

        meta = __resolve_platform_metadata(packages.values, package_name)
        if meta["version"] is None:
            Error_Out(f"❌ Package {package_name} not found", Error.ENOFOUND)

        print(meta["version"])
        return int(meta["version"])  # type: ignore[return-value]


def update_fleet_latest(package_name: str, fleet_name: str) -> None:
    """Create an update using the latest package version for a given fleet."""
    _hash = package_latest_hash(package_name)
    package = __get_target_by_hash(_hash)

    with torizon_cloud.ApiClient(_cfg) as api_client:
        api = torizon_cloud.UpdatesApi(api_client)
        update_rq = torizon_cloud.UpdateRequest()
        update_rq.package_ids = [package.package_id]
        update_rq.fleets = [__get_fleed_id(fleet_name)]

        ret = api.post_updates(update_request=update_rq)
        print(len(ret.affected))


def _usage() -> None:
    """Print CLI usage."""
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


# "main"
try:
    _cmd = sys.argv[1]
    _sub = sys.argv[2]
    _third = sys.argv[3]
except IndexError:
    _usage()
    Error_Out("❌ Command not found", Error.ENOFOUND)

# used to make the skip of the arguments dynamic depending on the command
ARG_SKIP = 3

try:
    # check if the function exists
    _func = globals()[f"{_cmd}_{_sub}"]
except KeyError:
    # possible a cmd with three verbs?
    try:
        ARG_SKIP = 4
        _func = globals()[f"{_cmd}_{_sub}_{_third}"]
    except KeyError:
        # no so let's show the usage and exit
        _usage()
        Error_Out(f"❌ Command {_cmd} not found", Error.ENOFOUND)

try:
    # execute the function
    _func(*sys.argv[ARG_SKIP:])
except Exception:  # pylint: disable=broad-exception-caught
    traceback.print_exc()
    Error_Out(f"❌ {_cmd} {_sub} {_third} failed", Error.EFAIL)

