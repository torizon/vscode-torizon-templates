#!/usr/bin/env bash

# we need this to expand during the source of the file
shopt -s expand_aliases

_COMPOSE_FILE="$HOME/.tcd/docker-compose.yml"
_BASH_COMPLETION_FILE="$HOME/.tcd/torizon-dev-completion.bash"
export APOLLOX_REPO="toradex/vscode-torizon-templates"
export APOLLOX_BRANCH="dev"
export BRANCH="dev"
export UUID=$(id -u)
export DGID=$(getent group docker | cut -d: -f3)

# for the store of the device data
if [ ! -d "$HOME/.tcd" ]; then
    mkdir $HOME/.tcd
else
    # remove the files so we can download it again
    # remove the docker-compose.yml
    rm -rf $HOME/.tcd/docker-compose.yml
    # remove the torizon-dev-completion.bash
    rm -rf $HOME/.tcd/torizon-dev-completion.bash
fi

# check if _COMPOSE_FILE exists
if [ ! -f "$_COMPOSE_FILE" ]; then
    # download it from GitHub
    wget -q https://raw.githubusercontent.com/$APOLLOX_REPO/$APOLLOX_BRANCH/scripts/container/docker-compose.yml -O $_COMPOSE_FILE
fi

# check if _BASH_COMPLETION_FILE exists
if [ ! -f "$_BASH_COMPLETION_FILE" ]; then
    # download it from GitHub
    wget -q https://raw.githubusercontent.com/$APOLLOX_REPO/$APOLLOX_BRANCH/scripts/bash/torizon-dev-completion.bash -O $_BASH_COMPLETION_FILE
fi

# we pull everytime we source it to get updates
docker \
    compose \
    -f $_COMPOSE_FILE \
    pull torizon-dev

function torizon-dev {
    # check if we are in the WSL
    if [ -n "$WSL_DISTRO_NAME" ]; then
        # check if the APOLLOX_PORTS_SHARED is already set
        if [ -z "$APOLLOX_PORTS_SHARED" ]; then
            powershell.exe \
                -NoProfile \
                -C "start-process powershell -verb runas -ArgumentList '-NoProfile -C \"(Remove-NetFireWallRule -DisplayName ApolloX) -or \$true ;  New-NetFireWallRule -DisplayName ApolloX -Direction Outbound -LocalPort 8090,5002 -Action Allow -Protocol TCP ;  New-NetFireWallRule -DisplayName ApolloX -Direction Inbound -LocalPort 8090,5002 -Action Allow -Protocol TCP ;  (netsh interface portproxy delete v4tov4 listenport=8090 listenaddress=0.0.0.0) -or \$true ;  (netsh interface portproxy delete v4tov4 listenport=5002 listenaddress=0.0.0.0) -or \$true ;  (netsh interface portproxy add v4tov4 listenport=8090 listenaddress=0.0.0.0 connectport=8090 connectaddress=172.24.54.164) -or \$true ;  (netsh interface portproxy add v4tov4 listenport=5002 listenaddress=0.0.0.0 connectport=5002 connectaddress=172.24.54.164) -or \$true ; echo done\"'"

            export APOLLOX_PORTS_SHARED="1"
        fi
    fi

    myhash=$(echo -n "$PWD" | openssl dgst -sha256 | sed 's/^.* //')
    export SHA_DIR=$myhash

    # check if the container name already exists
    if [ "$(docker ps -aq -f name=torizon-dev-$myhash)" ]; then
        # start the container
        docker start torizon-dev-$myhash > /dev/null
    # else then run it
    else
        docker \
            compose \
            -f $_COMPOSE_FILE \
            run \
            --name torizon-dev-$myhash \
            -d torizon-dev > /dev/null
    fi

    # exec the zygote with the args
    docker exec -it torizon-dev-$myhash zygote $@
}

# FIXME:    we need to also copy the completion file to
#           /usr/share/bash-completion/completions/torizon-dev
source $_BASH_COMPLETION_FILE
