#!/usr/bin/env xonsh
"""
valid-new-line.xsh: verify that text files end with a newline.
"""
# pylint: disable=invalid-name

# use the xonsh environment to update the OS environment
$UPDATE_OS_ENVIRON = True
# Get the full log of error
$XONSH_SHOW_TRACEBACK = True
# always return if a cmd fails
$RAISE_SUBPROC_ERROR = True

import os

def check_new_line(fpath):
    """Return True if file ends with a newline byte."""
    with open(fpath, "rb") as f:
        f.seek(-1, os.SEEK_END)
        last_char = f.read(1)
        return last_char == b"\n"


ignore_folders = [
    ".git",
    "node_modules",
    "id_rsa",
    "css",
    "obj",
    "target",
    ".mypy",
    "egg-info",
]

ERROR_REACH = False

for root, dirs, files in os.walk("."):
    dirs[:] = [d for d in dirs if d not in ignore_folders]
    for name in files:
        filepath = os.path.join(root, name)

        if any(ig in filepath for ig in ignore_folders):
            continue

        mime_type = $(file --mime-type -b @(filepath)).strip()
        # pylint: disable=line-too-long
        if mime_type.startswith("text/") or mime_type in {"application/javascript", "application/json"}:
            if not check_new_line(filepath):
                print(f"❌ :: {filepath}", file=sys.stderr)
                ERROR_REACH = True
if ERROR_REACH:
    print("\n❌ :: Files are missing new line at the end\n", file=sys.stderr)
    sys.exit(404)
else:
    print("\n✅ :: All files have new line at the end\n")
    sys.exit(0)

