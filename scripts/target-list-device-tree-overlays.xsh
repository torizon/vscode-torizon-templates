#!/usr/bin/env xonsh
"""
target-list-device-tree-overlays.xsh: list built-in device tree overlays on the target.
"""

# use the xonsh environment to update the OS environment
$UPDATE_OS_ENVIRON = True
# Get the full log of error
$XONSH_SHOW_TRACEBACK = True
# this script should handle the subprocess errors
$RAISE_SUBPROC_ERROR = False

import sys
import json
import subprocess
from types import SimpleNamespace
import torizon_templates_utils.errors as errors
from torizon_templates_utils.colors import Color
from torizon_templates_utils.animations import run_command_with_wait_animation


def main() -> None:
    # args: login, password, ip
    _login = sys.argv[1] if len(sys.argv) > 1 else None
    _pass = sys.argv[2] if len(sys.argv) > 2 else None
    _ip = sys.argv[3] if len(sys.argv) > 3 else None

    if _login is None or _pass is None or _ip is None:
        print("invalid arguments", color=Color.RED)
        sys.exit(69)

    def __dev_list():
        """Run the node lister and return an object with returncode/out/err."""
        proc = subprocess.run(
            ["node", "./node/listDeviceTreeOverlays.mjs", _ip, _login, _pass],
            capture_output=True,
            text=True,
            check=False,
        )
        return SimpleNamespace(returncode=proc.returncode, out=proc.stdout, err=proc.stderr)

    dev_list = run_command_with_wait_animation(__dev_list)

    if dev_list.returncode != 0:
        errors.Error_Out(
            f"Error listing device tree overlays :: [{dev_list.returncode}] :: {dev_list.err}",
            errors.Error.EFAIL,
        )
        return

    try:
        dev_list_obj = json.loads(dev_list.out)
    except Exception as exc:  # pylint: disable=broad-except
        errors.Error_Out(
            f"Error parsing device tree overlays :: {repr(exc)}",
            errors.Error.EFAIL,
        )
        return

    print("")
    print("🌳 :: DEVICE TREE OVERLAYS :: 🌳")
    print("")
    for dev in dev_list_obj:
        print(f"\t{dev}")
        print("")


if __name__ == "__main__":
    main()

