#!/bin/bash
set -e

# This is a script to install .NET on Ubuntu, based on the official Microsoft recommended method of installation:
# https://learn.microsoft.com/en-us/dotnet/core/install/linux-ubuntu

# Check if we are running on the LTS Ubuntu or Debian
if [ -f /etc/os-release ]; then
    # unset the exit with error
    set +e
    . /etc/os-release
    set -e

    if [ "$ID" = "ubuntu" ]; then
        repo="ubuntu"
        repo_version="24.04"
    elif [ "$ID" = "debian" ]; then
        repo="debian"
        repo_version="12"
    elif [ "$ID" = "torizon" ]; then
        repo="debian"
        repo_version="12"
    else
        echo "🔴 Unsupported distribution"
        echo "Please use the latest LTS of Debian or Ubuntu"
        echo "If you are using WSL 2 check the Torizon OS environment for WSL 2: https://bit.ly/4b2T1hd"
        exit 69
    fi
else
    echo "Unsupported distribution"
    exit 69
fi

DOTNET_CHANNEL="10.0"
INSTALL_DIR="/usr/share/dotnet"

echo "🔵 Installing .NET $DOTNET_CHANNEL..."

SCRIPT_PATH="$(mktemp /tmp/dotnet-install.XXXXXX.sh)"

wget -q https://dot.net/v1/dotnet-install.sh -O "$SCRIPT_PATH"
chmod +x "$SCRIPT_PATH"

sudo mkdir -p "$INSTALL_DIR"

sudo "$SCRIPT_PATH" --channel "$DOTNET_CHANNEL" --install-dir "$INSTALL_DIR"

if [ -x "$INSTALL_DIR/dotnet" ]; then
    sudo ln -sf "$INSTALL_DIR/dotnet" /usr/bin/dotnet
fi

echo "✔️ .NET installation complete!"
dotnet --list-sdks
