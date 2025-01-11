#!/bin/bash

echo "🐚 SETUP XONSH"

pipx install xonsh
pipx inject xonsh distro
pipx inject xonsh shtab
pipx inject xonsh pyyaml
pipx inject xonsh psutil
pipx inject xonsh torizon-templates-utils
pipx inject xonsh GitPython
pipx inject xonsh xontrib-powerline2
pipx inject xonsh python-lsp-server
pipx inject xonsh pylsp-rope
