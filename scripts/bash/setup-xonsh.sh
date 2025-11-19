#!/bin/bash

echo "🐚 SETUP XONSH"

# check if xonsh is on $HHOME/.local/bin
if [ -f "$HOME/.local/bin/xonsh" ]; then
    echo "xonsh is already installed, updating torizon-templates-utils ..."
    # force the install of the latest version of torizon-templates-utils

    repo="${TEST_TEMPLATES_GIT_REPO:-https://github.com/toradex/torizon-templates.git}"
    branch="${TEST_TEMPLATES_GIT_REPO_BRANCH:-main}"
    tag_or_hash="${TEST_TEMPLATES_GIT_TAG}"

    # Detect if repo is a local path
    if [ -d "$repo" ] || [ -f "$repo" ]; then
        repo="file://$(realpath "$repo")"
    else
        # Ensure repo ends with .git
        case "$repo" in
            *.git) ;;
            *) repo="${repo}.git" ;;
        esac
    fi

    if [ -n "$tag_or_hash" ]; then
    ref="$tag_or_hash"
    else
    ref="$branch"
    fi

    pipx runpip xonsh install --force-reinstall "git+${repo}@${ref}#subdirectory=scripts/utils/pip"

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
