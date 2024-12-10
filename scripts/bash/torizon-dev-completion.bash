#!/usr/bin/env bash

TCD_COMP_ARGS_MAIN="
    help
    connect
    init
    launch
    new
    scan
    target
    tasks
    version
    --version
"

TCD_COMP_ARGS_SCAN="
    help
    connect
    list
"

TCD_COMP_ARGS_CONNECT="
    help
    target
    list
"

TCD_COMP_ARGS_TARGET="
    help
    console
    reboot
    shutdown
    list-builtin-dto
    list-applied-dto
    apply-dto
"

TCD_COMP_ARGS_TASKS="
    desc
    list
    run
"

_torizon-dev_completions() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    # if the previous word is torizon-dev
    if [[ ${COMP_WORDS[COMP_CWORD-1]} == "torizon-dev" ]]; then
        opts="${TCD_COMP_ARGS_MAIN}"
    # if the previous word is scan
    elif [[ ${COMP_WORDS[COMP_CWORD-1]} == "scan" ]]; then
        opts="${TCD_COMP_ARGS_SCAN}"
    # if the previous word is connect
    elif [[ ${COMP_WORDS[COMP_CWORD-1]} == "connect" ]]; then
        opts="${TCD_COMP_ARGS_CONNECT}"
    # if the previous word is target
    elif [[ ${COMP_WORDS[COMP_CWORD-1]} == "target" ]]; then
        opts="${TCD_COMP_ARGS_TARGET}"
    elif [[ ${COMP_WORDS[COMP_CWORD-1]} == "tasks" ]]; then
        opts="${TCD_COMP_ARGS_TASKS}"
    elif [[ ${COMP_WORDS[COMP_CWORD-2]} == "tasks" ]]; then
        if [[ ${COMP_WORDS[COMP_CWORD-1]} == "run" ]]; then
            # list all tasks
            opts=$(jq '.tasks[].label' $PWD/.vscode/tasks.json)
        fi

        if [[ ${COMP_WORDS[COMP_CWORD-1]} == "desc" ]]; then
            # list all tasks
            opts=$(jq '.tasks[].label' $PWD/.vscode/tasks.json)
        fi
    elif [[ ${COMP_WORDS[COMP_CWORD-1]} == "launch" ]]; then
        opts=$(perl -0777 -pe 's{/\*.*?\*/}{}gs; s{\/\/.*}{}g; s/,\s*([\]}])/$1/g' $PWD/.vscode/launch.json | jq '.configurations[].preLaunchTask')
    fi

    COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
    return 0
}

complete -o bashdefault -F _torizon-dev_completions torizon-dev
