#!/usr/bin/env bash

# this script is mean to be sourced and register the torizon-dev command

__TCD_COMPOSE_FILE="$HOME/.tcd/docker-compose.yml"
__TCD_BASH_COMPLETION_FILE="$HOME/.tcd/torizon-dev-completion.bash"
export __TCD_APOLLOX_REPO="torizon/vscode-torizon-templates"
export __TCD_APOLLOX_BRANCH="dev"
# ⚠️ THIS NEED TO BE IN SYNC WITH THE PYTHON UTILS VERSION
export __TCD_BRANCH="1.3.1"
export __TCD_UUID=$(id -u)
export __TCD_DGID=$(getent group docker | cut -d: -f3)

# for the store of the device data
if [ ! -d "$HOME/.tcd" ]; then
    echo "Creating $HOME/.tcd ..."
    mkdir $HOME/.tcd
else
    echo "Found $HOME/.tcd ..."
    echo "Cleaning up container assets ..."
    # remove the files so we can download it again
    # remove the docker-compose.yml
    rm -rf $HOME/.tcd/docker-compose.yml
    # remove the torizon-dev-completion.bash
    rm -rf $HOME/.tcd/torizon-dev-completion.bash
fi

# check if _COMPOSE_FILE exists
if [ ! -f "$__TCD_COMPOSE_FILE" ]; then
    echo "Downloading docker-compose.yml ..."
    # download it from GitHub
    wget -q https://raw.githubusercontent.com/$__TCD_APOLLOX_REPO/$__TCD_APOLLOX_BRANCH/scripts/container/docker-compose.yml -O $__TCD_COMPOSE_FILE
fi

# check if _BASH_COMPLETION_FILE exists
if [ ! -f "$__TCD_BASH_COMPLETION_FILE" ]; then
    echo "Downloading tool completion ..."
    # download it from GitHub
    wget -q https://raw.githubusercontent.com/$__TCD_APOLLOX_REPO/$__TCD_APOLLOX_BRANCH/scripts/bash/tcd-completion.bash -O $__TCD_BASH_COMPLETION_FILE
fi

echo "Pulling the torizon-dev image ..."
# we pull everytime we source it to get updates
docker \
    compose \
    -f $__TCD_COMPOSE_FILE \
    pull torizon-dev

function torizon-dev {
    myhash=$(echo -n "$PWD" | openssl dgst -sha256 | sed 's/^.* //')
    export __TCD_SHA_DIR=$myhash

    # check if the container name already exists
    if [ "$(docker ps -aq -f name=torizon-dev-$myhash)" ]; then
        # start the container
        docker start torizon-dev-$myhash > /dev/null
    # else then run it
    else
        _workspace=$(basename $PWD)
        echo "Configuring environment for the [$_workspace] workspace ..."
        echo "Please wait ..."

        docker \
            compose \
            -f $__TCD_COMPOSE_FILE \
            run \
            --entrypoint /bin/bash \
            --name torizon-dev-$myhash \
            --user root \
            -d torizon-dev > /dev/null

        # also add the torizon user in the docker group
        docker exec -it --user root torizon-dev-$myhash usermod -u $__TCD_UUID torizon
        docker exec -it --user root torizon-dev-$myhash groupadd -g $__TCD_DGID docker
        docker exec -it --user root torizon-dev-$myhash usermod -aG $__TCD_DGID torizon
        # /home/torizon need to be owned by the new torizon user
        docker exec -it --user root torizon-dev-$myhash chown -R torizon:torizon /home/torizon
    fi

    # exec the zygote with the args
    docker exec -it --user torizon torizon-dev-$myhash zygote $@
}

echo "Sourcing the completion file ..."
# FIXME:    we need to also copy the completion file to
#           /usr/share/bash-completion/completions/torizon-dev
source $__TCD_BASH_COMPLETION_FILE

echo "Done ✅"
echo "Anyone who has never made a mistake has never tried anything new. - Albert Einstein"
