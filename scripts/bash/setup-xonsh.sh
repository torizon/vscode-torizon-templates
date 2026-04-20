#!/bin/bash

echo "🐚 SETUP XONSH"

function _check_xonsh_global {
    # we need to check if we need to run the setup as root
    # at the first time we should need to symlink the xonsh to the /usr/bin
    # read the /usr/bin/xonsh and check if it is linked to the
    # $HOME/.local/bin/xonsh, if not we need to run with sudo
    local local_xonsh="$HOME/.local/bin/xonsh"
    local global_xonsh="/usr/bin/xonsh"

    if [ ! -f "$local_xonsh" ]; then
        echo "Expected local xonsh at $local_xonsh but it was not found."
        return 1
    fi

    if [ -e "$global_xonsh" ] && [ "$(readlink -f "$global_xonsh")" = "$local_xonsh" ]; then
        return 0
    fi

    if [ -e "$global_xonsh" ]; then
        echo "The xonsh in $global_xonsh is not linked to $local_xonsh, trying to relink ..."
    else
        echo "$global_xonsh does not exist, creating global xonsh link ..."
    fi

    if [ -z "${PSSWD}" ]; then
        echo "Insufficient permissions to create $global_xonsh and PSSWD is not set."
        return 1
    fi

    if ! printf '%s\n' "$PSSWD" | sudo -S ln -sf "$local_xonsh" "$global_xonsh"; then
        echo "Failed to create $global_xonsh using sudo. Check password and sudo permissions."
        return 1
    fi

    return 0
}

# check if xonsh is on $HOME/.local/bin
if [ -f "$HOME/.local/bin/xonsh" ]; then
    echo "xonsh is already installed, updating torizon-templates-utils ..."

    VARS_FILE="./.conf/repo-vars.json"

    if [ -f "$VARS_FILE" ]; then
        echo "Found repo-vars.json, attempting to use custom source..."

        repo=$(jq -r '.repo // empty' "$VARS_FILE")
        branch=$(jq -r '.branch // empty' "$VARS_FILE")
        tag_or_hash=$(jq -r '.tag // empty' "$VARS_FILE")

        if [ -z "$repo" ] || { [ -z "$branch" ] && [ -z "$tag_or_hash" ]; }; then
            echo "Invalid or incomplete config, falling back to package..."
        else
            if [ -e "$repo" ]; then
                repo="file://$(realpath "$repo")"
            fi

            if [ -n "$tag_or_hash" ]; then
                ref="$tag_or_hash"
            else
                ref="$branch"
            fi

            pipx runpip xonsh install --force-reinstall \
                "git+${repo}@${ref}#subdirectory=scripts/utils/pip"

            echo "Installed from custom repo ✅"
            exit 0
        fi
    fi

    # Fallback to package if no repo or branch/tag set
    echo "Using published package..."
    pipx runpip xonsh install --upgrade torizon-templates-utils

    # re-check if we need to link xonsh globally
    if ! _check_xonsh_global; then
        exit 1
    fi

    echo "all ok ✅"
    exit 0
fi

# fail as soon as a command fails, and return the exit status
set -e

pipx install xonsh
pipx ensurepath
pipx inject xonsh distro
pipx inject xonsh shtab
pipx inject xonsh pyyaml
pipx inject xonsh psutil
pipx inject xonsh torizon-templates-utils
pipx inject xonsh GitPython
pipx inject xonsh python-lsp-server
pipx inject xonsh pylsp-rope

# add xonsh to the path if not already present
if ! grep -q "export PATH=\$PATH:\$HOME/.local/bin" ~/.bashrc; then
    echo "export PATH=\$PATH:\$HOME/.local/bin" >> ~/.bashrc
fi

# also for .xonshrc itself
if [ ! -f ~/.xonshrc ]; then
    touch ~/.xonshrc
fi
if ! grep -q "\$HOME/.local/bin" ~/.xonshrc; then
    echo "\$PATH.insert(0, '$HOME/.local/bin')" >> ~/.xonshrc
fi

# also make sure the xonsh is linked to the /usr/bin
if ! _check_xonsh_global; then
    exit 1
fi
