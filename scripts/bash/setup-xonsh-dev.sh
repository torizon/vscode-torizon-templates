#!/bin/bash

echo "SETUP ENVIRONMENT FOR TORIZON TEMPLATES SCRIPTS DEVELOPMENT"
echo "NEEDS SUPER USER PRIVILEGIES 🐮"
sudo echo "OK"

# install python3 and pip3 from Debian packages
sudo apt update
sudo apt install -y \
    python3 \
    python3-pip \
    python3-setuptools

# install the pylsp using pipx
pipx install xonsh
pipx inject xonsh distro
pipx inject xonsh shtab
pipx inject xonsh pyyaml
pipx inject xonsh psutil
# Install the Torizon Templates utils from the source
pipx inject xonsh ./utils/pip/
pipx inject xonsh GitPython
pipx inject xonsh xontrib-powerline2
pipx inject xonsh python-lsp-server
pipx inject xonsh pylsp-rope
# FIXME: mypy is not working with xonsh
# pipx inject xonsh pylsp-mypy

# to be able to publish the package to PyPI
pipx install twine

# install the apollox nodejs module as global
# npm install -g apollox

# inject into the .vscode/settings.json the home dir on the pylsp.executable
# to make it work with the pylsp installed with pipx
sed -i "s|\"/usr/bin/pylsp\"|\"$HOME/.local/bin/pylsp\"|" .vscode/settings.json
