#!/usr/bin/env xonsh

# Copyright (c) 2025 Toradex
# SPDX-License-Identifier: MIT

##
# This script is used to initialize the Torizon development environment.
##

# use the xonsh environment to update the OS environment
$UPDATE_OS_ENVIRON = True
# always return if a cmd fails
$RAISE_SUBPROC_ERROR = True

import os
import sys
import json
import distro
import shtab
import argparse
from torizon_templates_utils.errors import Error,Error_Out
from torizon_templates_utils.colors import Color,BgColor,print
from torizon_templates_utils.animations import run_command_with_wait_animation


_VERSION = "0.0.0"
$SCRIPT_PATH = os.path.dirname(os.path.realpath(__file__))


# make sure we have the $HOME/.tcd directory
mkdir -p $HOME/.tcd


def __node_scan():
    # we need to set the location because node package is installed there
    cd $SCRIPT_PATH/node
    node scanNetworkDevices.mjs


def _scan_list(args):
    if os.path.exists(f"{os.environ['HOME']}/.tcd/scan.json"):
        with open(f"{os.environ['HOME']}/.tcd/scan.json", "r") as f:
            nets = json.load(f)

        # aesthetic
        print("")

        _ix = 0
        for net in nets:
            _ip = net["Ip"]
            _hostname = net["Hostname"]

            print(f"\t\t {_ix} ➡️  {_hostname} ({_ip})")
            _ix += 1

        # aesthetic
        print("")

        if _ix == 0:
            Error_Out(
                "❌ :: No network devices found :: ❌",
                Error.ENOFOUND
            )

    else:
        Error_Out(
            "❌ :: scan list does not exists. Did you already ran the scan command? :: ❌",
            Error.ENOFOUND
        )


def _scan(args):
    print("🔍 :: SCANNING NETWORK :: 🔍", color=Color.YELLOW)
    run_command_with_wait_animation(__node_scan)
    _scan_list(args)


def _connect(args):
    if os.path.exists(f"{os.environ['HOME']}/.tcd/scan.json"):
        with open(f"{os.environ['HOME']}/.tcd/scan.json", "r") as f:
            nets = json.load(f)

        # aesthetic
        print("")

        _ix = 0
        _ip = None
        _hostname = None

        for net in nets:
            _ip = net["Ip"]
            _hostname = net["Hostname"]

            if _ix == args.id:
                print(f" ➡️  {_hostname} ({_ip})")
                break

            _ix += 1

        # aesthetic
        print("")

        if _ip is not None:
            cd $SCRIPT_PATH
            xonsh ./connect-device.xsh @(args.id)
            # aesthetic
            print("")

        else:
            Error_Out(
                f"❌ :: Device with id [{args.id}] not found :: ❌",
                Error.ENOFOUND
            )
    else:
        Error_Out(
            "❌ :: scan list does not exists. Did you already ran the scan command? :: ❌",
            Error.ENOFOUND
        )


def _new(args):
    try:
        cd $SCRIPT_PATH
        xonsh ./create-from-template-it.xsh
    except Exception as e:
        # does nothing since the error should be handled by the script
        pass

    # aesthetic
    print("")


def _new_cli(args):

    _templates = []
    with open(f"{os.environ['HOME']}/.apollox/templates.json", "r") as f:
        _templates = json.load(f)["Templates"]

    # sanity
    # check if the template exists
    _template_exists = False
    for _t in _templates:
        if _t["folder"] == args.template:
            _template_exists = True
            break

    if not _template_exists:
        Error_Out(
            f"❌ :: Template [{args.template}] not found :: ❌",
            Error.EINVAL
        )

    # check if the path already exists
    if os.path.exists(f"{args.path}/{args.name}"):
        Error_Out(
            f"❌ :: Project path [{args.path}/{args.name}] with project name [{args.name}] already exists :: ❌",
            Error.EINVAL
        )

    cd $SCRIPT_PATH
    xonsh ./create-from-template.xsh \
        @(f"{os.environ['HOME']}/.apollox/{args.template}") \
        @(args.name) \
        @(args.container_name) \
        @(args.path) \
        @(args.template) \
        @(False) \
        @(False)

    # aesthetic
    print("")
    print("✅ :: PROJECT CREATED :: ✅", color=Color.GREEN)
    print("")


def _scan_connect(args):
    _scan(args)

    # get the ix
    _ix = input("The index of the device to connect to: ")
    args.id = int(_ix)

    _connect(args)


def _connected_list(args):
    print("📡 :: CONNECTED DEVICES :: 📡")
    print("")

    connects = None
    target = None

    if os.path.exists(f"{os.environ['HOME']}/.tcd/connected.json"):
        with open(f"{os.environ['HOME']}/.tcd/connected.json", "r") as f:
            connects = json.load(f)

    if os.path.exists(f"{os.environ['HOME']}/.tcd/target.json"):
        with open(f"{os.environ['HOME']}/.tcd/target.json", "r") as f:
            target = json.load(f)

    if connects is not None and len(connects) > 0:
        _id = 0

        for conn in connects:
            _ip = conn["Ip"]
            _hostname = conn["Hostname"]
            _is_target = False

            if target is not None:
                if target["Ip"] == _ip:
                    print(f"\t {_id} ✳️ {_hostname} ({_ip})", bg_color=BgColor.BRIGTH_GREEN)
                    _is_target = True

            if not _is_target:
                print(f"\t {_id} ➡️ {_hostname} ({_ip})", bg_color=BgColor.BRIGTH_BLUE)

            print(f"\t\t Machine Arch: {conn['Arch']}")
            print(f"\t\t Machine: {conn['Model']}")
            print(f"\t\t Torizon Version: {conn['Version']}")
            print(f"\t\t IP: {_ip}")
            print(f"\t\t SSH Port: {conn['SshPort']}")
            print(f"\t\t Hostname: {_hostname}")
            print(f"\t\t Username: {conn['Login']}")
            print("")

            _id += 1

    else:
        Error_Out(
            "❌ :: No devices connected :: ❌",
            Error.ENOFOUND
        )

    # aesthetic
    print("")


def _target_get(args):
    target = None

    if os.path.exists(f"{os.environ['HOME']}/.tcd/target.json"):
        with open(f"{os.environ['HOME']}/.tcd/target.json", "r") as f:
            target = json.load(f)

    if target is not None:
        _ip = target["Ip"]
        _hostname = target["Hostname"]

        print(f"🎯 :: TARGET DEVICE :: 🎯")
        print("")
        print(f"\t ✳️ {_hostname} ({_ip})")
        print("")

    else:
        Error_Out(
            "❌ :: No target device set :: ❌",
            Error.ENOFOUND
        )


def _target_set(args):
    if os.path.exists(f"{os.environ['HOME']}/.tcd/connected.json"):
        with open(f"{os.environ['HOME']}/.tcd/connected.json", "r") as f:
            connects = json.load(f)

        # sanity
        if args.id > len(connects) or args.id < 0:
            Error_Out(
                f"❌ :: Invalid device index :: ❌",
                Error.EINVAL
            )

        if len(connects) > 0:
            _id = 0
            _target = {}

            for conn in connects:
                if _id == args.id:
                    _target = conn
                    break

                _id += 1

            with open(f"{os.environ['HOME']}/.tcd/target.json", "w") as f:
                json.dump(_target, f)

            print("🎯 :: TARGET DEVICE SET :: 🎯")
            print(f"\t ✳️ {_target['Hostname']} ({_target['Ip']})")
            print("")
            return

    Error_Out(
        "❌ :: No devices connected. Impossible set device as target :: ❌",
        Error.ETOMCRUISE
    )


def __get_target():
    target = None

    if os.path.exists(f"{os.environ['HOME']}/.tcd/target.json"):
        with open(f"{os.environ['HOME']}/.tcd/target.json", "r") as f:
            target = json.load(f)

    return target


def _target(args):
    _connected_list(args)

    # get the ix
    _ix = input("The index of the device to set as target: ")
    args.id = int(_ix)
    _target_set(args)


def _target_console(args):
    target = __get_target()

    if target is not None:
        print(f"🖥️ :: CONNECTING TO {target['Hostname']} :: 🖥️")
        print("")

        $RAISE_SUBPROC_ERROR = False

        sshpass \
            -p @(target['__pass__']) \
            ssh \
            -o UserKnownHostsFile=/dev/null \
            -o StrictHostKeyChecking=no \
            -p @(target['SshPort']) \
            @(target['Login'])@@(target['Ip']) @(args.cmd if "cmd" in args else "")

        $RAISE_SUBPROC_ERROR = True

        # aesthetic
        print("")

    else:
        Error_Out(
            "❌ :: No target device set :: ❌",
            Error.ENOFOUND
        )


def _target_list_builtin_dto(args):
    _target = __get_target()

    if _target == None:
        Error_Out(
            "❌ :: No target device set :: ❌",
            Error.ENOFOUND
        )
    else:
        _target_get(args)

        cd $SCRIPT_PATH
        xonsh ./target-list-device-tree-overlays.xsh \
            @(f"{_target['Login']}") \
            @(f"{_target['__pass__']}") \
            @(f"{_target['Ip']}")


def _target_list_applied_dto(args):
    _target = __get_target()

    if _target == None:
        Error_Out(
            "❌ :: No target device set :: ❌",
            Error.ENOFOUND
        )
    else:
        _target_get(args)

        cd $SCRIPT_PATH
        xonsh ./target-list-applied-device-tree-overlays.xsh \
            @(f"{_target['Login']}") \
            @(f"{_target['__pass__']}") \
            @(f"{_target['Ip']}")


def _init_workspace(args):
    xonsh @(f"{os.environ['HOME']}/.apollox/scripts/init-workspace.xsh")


def _target_reboot(args):
    target = __get_target()
    args.cmd = f"echo {target['__pass__']} | sudo -S reboot now"

    _target_console(args)


def _target_shutdown(args):
    target = __get_target()
    args.cmd = f"echo {target['__pass__']} | sudo -S shutdown now"

    _target_console(args)


def _tasks_list(args):
    if os.path.exists(f"./.vscode/tasks.json") and os.path.exists(f"./.vscode/tasks.xsh"):
        xonsh ./.vscode/tasks.xsh list
    else:
        print(f"❌ :: Current folder [{os.getcwd()}] is not a valid Torizon template :: ❌", color=Color.RED)
        Error_Out(
            f"❌ :: Current folder [{os.getcwd()}] does not ./.vscode/tasks.json or ./.vscode/tasks.xsh :: ❌",
            Error.ETOMCRUISE
        )


def _tasks_desc(args):
    if os.path.exists(f"./.vscode/tasks.json") and os.path.exists(f"./.vscode/tasks.xsh"):
        xonsh ./.vscode/tasks.xsh desc @(args.label)
    else:
        print(f"❌ :: Current folder [{os.getcwd()}] is not a valid Torizon template :: ❌", color=Color.RED)
        Error_Out(
            f"❌ :: Current folder [{os.getcwd()}] does not ./.vscode/tasks.json or ./.vscode/tasks.xsh :: ❌",
            Error.ETOMCRUISE
        )


def _tasks_run(args):
    if os.path.exists(f"./.vscode/tasks.json") and os.path.exists(f"./.vscode/tasks.xsh"):
        xonsh ./.vscode/tasks.xsh run @(args.label)
    else:
        print(f"❌ :: Current folder [{os.getcwd()}] is not a valid Torizon template :: ❌", color=Color.RED)
        Error_Out(
            f"❌ :: Current folder [{os.getcwd()}] does not ./.vscode/tasks.json or ./.vscode/tasks.xsh :: ❌",
            Error.ETOMCRUISE
        )


def _tasks_apply_dto(args):
    _target = __get_target()

    if _target == None:
        Error_Out(
            "❌ :: No target device set :: ❌",
            Error.ENOFOUND
        )
    else:
        _target_get(args)

        cd $SCRIPT_PATH
        xonsh ./apply-device-tree-overlay.xsh \
            @(f"{_target['Login']}") \
            @(f"{_target['__pass__']}") \
            @(f"{_target['Ip']}") \
            @(args.dto_list)


class PrintVersionAction(argparse.Action):
    def __call__(self, parser, namespace, values, option_string=None):
        distro_info = distro.os_release_info()

        print(
f"""
Torizon Development Environment

Version: {_VERSION}
Arch: {os.uname().machine}
Distro: {distro_info["pretty_name"]}
Kernel: {os.uname().release}

Copyrigth (c) 2025 Toradex and contributors
This product is open source licensed under the MIT License.
"""
        )
        parser.exit()


parser = argparse.ArgumentParser(description="Torizon Development Environment")
subparser = parser.add_subparsers(title="subcommands")


# ------------------------------------------------------------------------- SCAN
parser_scan = subparser.add_parser(
    "scan",
    help="Scan for network devices"
)
parser_scan.set_defaults(func=_scan)
parser_scan_sub = parser_scan.add_subparsers(title="subcommands")
parser_scan_list = parser_scan_sub.add_parser(
    "list",
    help="display the list of the network devices found in the previous scan",
)
parser_scan_list.set_defaults(func=_scan_list)
parser_scan_connect = parser_scan_sub.add_parser(
    "connect",
    help="connect to a network device listed in the scan"
)
parser_scan_connect.add_argument(
    "id",
    type=int,
    help="index of the network device to connect to"
)
parser_scan_connect.set_defaults(func=_connect)
# ------------------------------------------------------------------------- SCAN


# ----------------------------------------------------------------------- TARGET
parser_target = subparser.add_parser(
    "target",
    help="Set the target device interactively"
)
parser_target.set_defaults(func=_target)
parser_target_sub = parser_target.add_subparsers(title="subcommands")
parser_target_list = parser_target_sub.add_parser(
    "get",
    help="Show the device set as target"
)
parser_target_list.set_defaults(func=_target_get)
parser_target_set = parser_target_sub.add_parser(
    "set",
    help="Set the target device"
)
parser_target_set.add_argument(
    "id",
    type=int,
    help="index of the network device to set as target (use the 'connected list' command to get the index)"
)
parser_target_set.set_defaults(func=_target_set)
parser_target_console = parser_target_sub.add_parser(
    "console",
    help="Open a remote console to the target device"
)
parser_target_console.set_defaults(func=_target_console)
parser_target_reboot = parser_target_sub.add_parser(
    "reboot",
    help="Reboot the target device"
)
parser_target_reboot.set_defaults(func=_target_reboot)
parser_target_shutdown = parser_target_sub.add_parser(
    "shutdown",
    help="Shutdown the target device"
)
parser_target_shutdown.set_defaults(func=_target_shutdown)
parser_target_list_built_in = parser_target_sub.add_parser(
    "list-builtin-dto",
    help="Show a list of available pre-built overlays that can be applied to the target device"
)
parser_target_list_built_in.set_defaults(func=_target_list_builtin_dto)
parser_target_list_applied = parser_target_sub.add_parser(
    "list-applied-dto",
    help="Show a list of the overlays applied to the target device"
)
parser_target_list_applied.set_defaults(func=_target_list_applied_dto)
parser_target_apply_dto = parser_target_sub.add_parser(
    "apply-dto",
    help="Apply a list of device tree overlay to the target device"
)
parser_target_apply_dto.add_argument(
    "dto_list",
    type=str,
    help="List of device tree overlays to apply (comma separated)"
)
parser_target_apply_dto.set_defaults(func=_tasks_apply_dto)
# ----------------------------------------------------------------------- TARGET


# ---------------------------------------------------------------------- CONNECT
connect_scan = subparser.add_parser(
    "connect",
    help="Scan network for devices and interactively connect"
)
connect_scan.set_defaults(func=_scan_connect)
connect_scan_sub = connect_scan.add_subparsers(title="subcommands")
connect_scan_list = connect_scan_sub.add_parser(
    "list",
    help="Show the list of connected devices",
)
connect_scan_list.set_defaults(func=_connected_list)
# ---------------------------------------------------------------------- CONNECT


# -------------------------------------------------------------------------- NEW
parser_new = subparser.add_parser(
    "new",
    help="Create a new Torizon project"
)
parser_new.set_defaults(func=_new)
parser_new_sub = parser_new.add_subparsers(title="subcommands")
parser_new_cli = parser_new_sub.add_parser(
    "cli",
    help="Create a new Torizon project using the CLI"
)
parser_new_cli.add_argument(
    "--template", "-t",
    help="Template folder name",
    type=str,
    required=True
)
parser_new_cli.add_argument(
    "--name", "-n",
    help="Name of the project",
    type=str,
    required=True
)
parser_new_cli.add_argument(
    "--container-name", "-c",
    help="Name of the service container",
    type=str,
    required=True
)
parser_new_cli.add_argument(
    "--path", "-p",
    help="Path to create the new project",
    type=str,
    required=True
)
parser_new_cli.set_defaults(func=_new_cli)
# -------------------------------------------------------------------------- NEW


# ------------------------------------------------------------------------- INIT
parser_init = subparser.add_parser(
    "init",
    help="Initialize the workspace to work with the target device"
)
parser_init.set_defaults(func=_init_workspace)
# ------------------------------------------------------------------------- INIT


# ------------------------------------------------------------------------ TASKS
parser_tasks = subparser.add_parser(
    "tasks",
    help="Show the list of tasks available on workspace"
)
parser_tasks_sub = parser_tasks.add_subparsers(title="subcommands")
parser_tasks_list = parser_tasks_sub.add_parser(
    "list",
    help="Show the list of tasks available on workspace"
)
parser_tasks_list.set_defaults(func=_tasks_list)
parser_tasks_desc = parser_tasks_sub.add_parser(
    "desc",
    help="Show the description of a given task"
)
parser_tasks_desc.add_argument(
    "label",
    type=str,
    help="Name of the task to show the description"
)
parser_tasks_desc.set_defaults(func=_tasks_desc)
parser_tasks_run = parser_tasks_sub.add_parser(
    "run",
    help="Run a given task"
)
parser_tasks_run.add_argument(
    "label",
    type=str,
    help="Name of the task to run"
)
parser_tasks_run.set_defaults(func=_tasks_run)
# ------------------------------------------------------------------------ TASKS


# ---------------------------------------------------------------------- VERSION
parser.add_argument(
    "--version", "-v",
    help="Show the version of the Torizon Development Environment",
    action=PrintVersionAction,
    nargs=0
)
# ---------------------------------------------------------------------- VERSION


# FIXME: only export this argument when need to update the bash completion
# Magic completion 🌈
shtab.add_argument_to(parser, "--print-completion")


try:
    args = parser.parse_args()

    if hasattr(args, "func"):
        args.func(args)
    else:
        parser.print_help()
except KeyboardInterrupt:
    Error_Out(
        "❌ :: User interrupted the process :: ❌",
        Error.EABORT
    )
