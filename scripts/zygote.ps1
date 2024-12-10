#!/usr/bin/env pwsh
param()

$errorActionPreference = "Stop"
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', "Internal PS variable"
)]
$PSNativeCommandUseErrorActionPreference = $true

# include
. "$env:HOME/.apollox/scripts/utils/stackTrace.ps1"

$_VERSION = "0.0.0"

$_mainCommand = $args[0]

function help() {
    Write-Host "📖 :: HELP :: 📖"
    Write-Host ""
    Write-Host " ➡️ connect"
    Write-Host "`t Interactively connect to a network device listed by the scan"
    Write-Host ""
    Write-Host "`t ➡️ help"
    Write-Host "`t`t show the help for the connect command"
    Write-Host ""
    Write-Host " ➡️ help"
    Write-Host "`t Show this help"
    Write-Host ""
    Write-Host " ➡️ init"
    Write-Host "`t Initialize the workspace"
    Write-Host ""
    Write-Host " ➡️ launch"
    Write-Host "`t Run the preLaunchTask of the chosen launch option"
    Write-Host ""
    Write-Host " ➡️ new"
    Write-Host "`t Create a new project from a template using TUI"
    Write-Host ""
    Write-Host " ➡️ new-cli"
    Write-Host "`t Create a new project from a template using CLI"
    Write-Host ""
    Write-Host " ➡️ scan"
    Write-Host "`t Scan for network devices"
    Write-Host ""
    Write-Host "`t ➡️ help"
    Write-Host "`t`t show the help for the scan command"
    Write-Host ""
    Write-Host " ➡️ target"
    Write-Host "`t Show the connected target device"
    Write-Host ""
    Write-Host "`t ➡️ help"
    Write-Host "`t`t show the help for the target command"
    Write-Host ""
    Write-Host " ➡️ tasks"
    Write-Host "`t Run the commands for the tasks defined in the workspace"
    Write-Host ""
    Write-Host "`t ➡️ help"
    Write-Host "`t`t show the help for the tasks command"
    Write-Host ""
    Write-Host " ➡️ version | --version"
    Write-Host "`t Show the torizon-dev version"
    Write-Host ""
}

function _setup_user() {
    try {
        getent passwd $env:UUSER | Out-Null
    } catch {
        useradd -u $env:UUID $env:UUSER
        groupadd -g $env:DGID docker
        usermod -aG docker $env:UUSER
        Write-Output "$env:UUSER ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
    }
}

function _update_templates() {
    $gitRepoBranch = $env:APOLLOX_TEMPLATES_GIT_REPO_BRANCH
    #$gitRepo = $env:APOLLOX_TEMPLATES_GIT_REPO

    # cleanup
    git -C $env:HOME/.apollox clean -f *> /dev/null
    git -C $env:HOME/.apollox fetch *> /dev/null
    git -C $env:HOME/.apollox checkout $gitRepoBranch *> /dev/null
    git -C $env:HOME/.apollox reset --hard origin/$gitRepoBranch *> /dev/null
}

function _scan_network() {
    pwsh -nop `
        -f $env:HOME/.apollox/scripts/scanNetworkDevices.ps1
}

function _scan_network_display_previous_scan() {
    pwsh -nop `
        -f $env:HOME/.apollox/scripts/scanNetworkDevices.ps1 display
}

function _connect_device {
    param(
        [Parameter(Mandatory = $true, HelpMessage="The device id to connect to")]
        [string] $id
    )

    # read the args
    $_login = Read-Host "Login"
    $_pass = Read-Host "Password" -MaskInput
    Write-Host ""

    pwsh -nop `
        -f $env:HOME/.apollox/scripts/connectDevice.ps1 `
            -id $id `
            -login $_login `
            -pass $_pass
}

function _list_connected_devices() {
    Write-Host "📡 :: CONNECTED DEVICES :: 📡"
    Write-Host ""

    # read the connect file
    if (!(Test-Path $env:HOME/.tcd/connected.json)) {
        Write-Host -ForegroundColor Red "❌ :: No devices connected :: ❌"
        Write-Host ""
        exit 404
    }

    $_connectDevs =
        Get-Content $env:HOME/.tcd/connected.json | ConvertFrom-Json -Depth 100

    # read the target file
    $_targetDev = $null
    if (!(Test-Path $env:HOME/.tcd/target.json)) {
        Write-Host -ForegroundColor Yellow "⚠️ :: No target device set :: ⚠️"
        Write-Host ""
    } else {
        $_targetDev =
            Get-Content $env:HOME/.tcd/target.json | ConvertFrom-Json -Depth 100
    }

    $_id = 0

    foreach ($_device in $_connectDevs) {
        $_hostName = $_device.Hostname

        if (
            ($null -ne $_targetDev) -and
            ($_hostName -eq $_targetDev.Hostname)
        ) {
            Write-Host -ForegroundColor Green "`t $_id ✳️ $_hostName"
        } else {
            Write-Host "`t $_id ▶️ $_hostName"
        }

        $_id = $_id + 1
    }

    Write-Host ""
}

function _get_target() {
    # read the target file
    if (!(Test-Path $env:HOME/.tcd/target.json)) {
        Write-Host -ForegroundColor Yellow "⚠️ :: No target device set :: ⚠️"
        Write-Host ""
        exit 404
    }

    return Get-Content $env:HOME/.tcd/target.json | ConvertFrom-Json -Depth 100
}

function _show_target_device() {
    $_targetDev = _get_target

    $_hostName = $_targetDev.Hostname

    Write-Host ""
    Write-Host `
        -ForegroundColor Green `
        "✅ :: target device set to $_hostName :: ✅"
    Write-Host ""
}

function _set_target_device() {
    # read the connect file
    if (!(Test-Path $env:HOME/.tcd/connected.json)) {
        Write-Host -ForegroundColor Red "❌ :: No devices connected :: ❌"
        Write-Host ""
        exit 404
    }

    $_connectDevs =
        Get-Content $env:HOME/.tcd/connected.json | ConvertFrom-Json -Depth 100

    $_id = Read-Host "Device id"

    if ($_id -lt 0 -or $_id -gt $_connectDevs.Count -1) {
        Write-Host -ForegroundColor Red "❌ :: Invalid device id :: ❌"
        Write-Host ""
        exit 400
    }

    $_targetDev = $_connectDevs[$_id]
    $_targetDev | ConvertTo-Json -Depth 100 | Out-File $env:HOME/.tcd/target.json

    $_hostName = $_targetDev.Hostname

    Write-Host ""
    Write-Host `
        -ForegroundColor Green `
        "`t ✅ :: target device set to $_hostName :: ✅"
    Write-Host ""
}

function _target_console() {
    param(
        [string] $cmd = ""
    )

    $_targetDev = _get_target

    $_hostName = $_targetDev.Hostname
    $_ip = $_targetDev.Ip
    $_user = $_targetDev.Login
    $_pass = $_targetDev.__pass__

    Write-Host ""
    Write-Host "🖥️ :: CONNECTING TO $_hostName :: 🖥️"

    # resolve the variables from the command
    $cmd = Invoke-Expression "echo `"$cmd`""

    sshpass `
        -p $_pass `
        ssh `
        -o UserKnownHostsFile=/dev/null `
        -o StrictHostKeyChecking=no `
        $_user@$_ip $cmd

    Write-Host ""
}

function _target_list_builtin_dto () {
    $_targetDev = _get_target

    pwsh -nop `
        -f $env:HOME/.apollox/scripts/targetListDeviceTreeOverlays.ps1 `
            -login $_targetDev.Login `
            -pass $_targetDev.__pass__ `
            -ip $_targetDev.Ip
}

function _target_apply_dto () {
    param(
        [Parameter(Mandatory = $true, HelpMessage="The overlays to apply (comma separated)")]
        [string] $overlays
    )

    Write-Host ""

    $_targetDev = _get_target

    pwsh -nop `
        -f $env:HOME/.apollox/scripts/applyDeviceTreeOverlays.ps1 `
            -login $_targetDev.Login `
            -pass $_targetDev.__pass__ `
            -ip $_targetDev.Ip `
            -overlays $overlays
}

function _target_list_applied_dto () {
    $_targetDev = _get_target

    pwsh -nop `
        -f $env:HOME/.apollox/scripts/targetListAppliedDeviceTreeOverlays.ps1 `
            -login $_targetDev.Login `
            -pass $_targetDev.__pass__ `
            -ip $_targetDev.Ip
}

try {

    _setup_user
    _update_templates

    switch ($_mainCommand) {
        "help" {
            help
        }
        "connect" {
            switch ($args[1]) {
                "help" {
                    Write-Host "📖 :: CONNECT HELP :: 📖"
                    Write-Host ""
                    Write-Host " ➡️ target [id]"
                    Write-Host "`t Set the device connected to use as target. Use the id from the `connect list` command"
                    Write-Host ""
                    Write-Host " ➡️ list"
                    Write-Host "`t Show the list of connected devices"
                    Write-Host ""
                    exit 0
                }
                "list" {
                    _list_connected_devices
                }
                "target" {
                    _set_target_device
                }
                Default {
                    _connect_device
                }
            }
        }
        "init" {
            su $env:UUSER -p `
                -c "pwsh -nop -f $env:HOME/.apollox/scripts/initWorkspace.ps1"
        }
        "launch" {
            $_task = $args[1]

            # make sure that $_task is a valid launch task
            $_validTasks = $(perl -0777 -pe 's{/\*.*?\*/}{}gs; s{\/\/.*}{}g; s/,\s*([\]}])/$1/g' /workspace/.vscode/launch.json | jq '.configurations[].preLaunchTask')
            $_valid = $false
            foreach ($_validTask in $_validTasks) {
                if ($_validTask -eq $(Write-Output "`"$_task`"")) {
                    $_valid = $true
                }
            }

            if (-not $_valid) {
                Write-Host -ForegroundColor Red "❌ :: Invalid launch task :: ❌"
                Write-Host ""
                exit 400
            }

            su $env:UUSER -p `
                -c "pwsh -nop -f /workspace/.vscode/tasks.ps1 run $_task"
        }
        "new" {
            # the host needs to be able to write and read the project generated
            su $env:UUSER -p `
                -c "pwsh -nop -f $env:HOME/.apollox/scripts/createFromTemplateTUI.ps1"
        }
        "new-cli" {
            $_templateFolder = $args[1]
            $_projectName = $args[2]
            $_containerName = $args[3]
            $_location = "/workspace/"
            $_isVscode = "false"
            $_telemetryOn = "false"

            # the host needs to be able to write and read the project generated
            # this is intended to be used by automation only, so vscode and the
            # telemetry are disabled
            su $env:UUSER -p `
                -c "pwsh -nop -f $env:HOME/.apollox/scripts/createFromTemplate.ps1 ${env:HOME}/.apollox/$_templateFolder $_projectName $_containerName $_location $_templateFolder $_isVscode $_telemetryOn"
        }
        "scan" {
            switch ($args[1]) {
                "help" {
                    Write-Host "📖 :: SCAN HELP :: 📖"
                    Write-Host ""
                    Write-Host " ➡️ connect <index>"
                    Write-Host "`t connect to a network device listed in the scan"
                    Write-Host ""
                    Write-Host " ➡️ list"
                    Write-Host "`t display the list of the network devices found in the previous scan"
                    Write-Host ""
                    exit 0
                }
                "list" {
                    _scan_network_display_previous_scan
                }
                "connect" {
                    # make sure that a scan index is provided
                    if ($null -eq $args[2]) {
                        Write-Host -ForegroundColor Red "❌ :: No scan index provided :: ❌"
                        Write-Host ""
                        exit 400
                    }

                    _connect_device -id $args[2]
                }
                Default {
                    _scan_network
                }
            }
        }
        "target" {
            switch ($args[1]) {
                "help" {
                    Write-Host "📖 :: TARGET HELP :: 📖"
                    Write-Host ""
                    Write-Host " ➡️ console"
                    Write-Host "`t Connect to the target device remote console"
                    Write-Host ""
                    Write-Host " ➡️ reboot"
                    Write-Host "`t Reboot the target device"
                    Write-Host ""
                    Write-Host " ➡️ shutdown"
                    Write-Host "`t Shutdown the target device"
                    Write-Host ""
                    Write-Host " ➡️ list-builtin-dto"
                    Write-Host "`t See a list of available pre-built overlays that can be applied to the target device"
                    Write-Host ""
                    Write-Host " ➡️ list-applied-dto"
                    Write-Host "`t See the list of the overlays applied to the target device"
                    Write-Host ""
                    Write-Host " ➡️ apply-dto"
                    Write-Host "`t Apply a list of overlays to the target device"
                    Write-Host ""
                    exit 0
                }
                "console" {
                    try {
                        _target_console
                    } catch {
                        # ignore the error
                    }
                }
                "reboot" {
                    try {
                        _target_console "echo `${_pass} | sudo -S reboot now"
                    } catch {
                        # ignore the error
                    }
                }
                "shutdown" {
                    try {
                        _target_console "echo `${_pass} | sudo -S shutdown now"
                    } catch {
                        # ignore the error
                    }
                }
                "list-builtin-dto" {
                    try {
                        _target_list_builtin_dto
                    } catch {
                        # ignore the error
                    }
                }
                "apply-dto" {
                    try {
                        _target_apply_dto $args[2]
                    } catch {
                        # ignore the error
                    }
                }
                "list-applied-dto" {
                    try {
                        _target_list_applied_dto
                    } catch {
                        # ignore the error
                    }
                }
                Default {
                    if ($args[1] -eq "") {
                        _show_target_device
                    } else {
                        Write-Host -ForegroundColor Red "❌ :: Command not found :: ❌"
                        exit 404
                    }
                }
            }
        }
        "tasks" {
            switch ($args[1]) {
                "help" {
                    Write-Host "📖 :: TASKS HELP :: 📖"
                    Write-Host ""
                    Write-Host " ➡️ list"
                    Write-Host "`t List all the tasks available for the current workspace"
                    Write-Host ""
                    Write-Host " ➡️ desc [id]"
                    Write-Host "`t Show the definition of the task with the given id"
                    Write-Host ""
                    Write-Host " ➡️ run [id]"
                    Write-Host "`t Run the task with the given id"
                    Write-Host ""
                    exit 0
                }
                "desc" {
                    $_task = $args[2]
                    su $env:UUSER -p `
                        -c "pwsh -nop -f /workspace/.vscode/tasks.ps1 desc $_task"
                }
                "list" {
                    su $env:UUSER -p `
                        -c "pwsh -nop -f /workspace/.vscode/tasks.ps1 list"
                }
                "run" {
                    $env:TASKS_DEBUG = $true
                    $_task = $args[2]
                    su $env:UUSER -p `
                        -c "pwsh -nop -f /workspace/.vscode/tasks.ps1 run $_task"
                }
                Default {}
            }
        }
        {$_ -eq "version" -or  $_ -eq "--version"} {
            Write-Host "📖 :: TorizonCore Dev :: 📖"
            Write-Host "v$_VERSION"
            Write-Host "Toradex AG©️ 2023"
            exit 0
        }
        Default {
            Write-Host -ForegroundColor Red "❌ :: Command not found :: ❌"
            help
            exit 404
        }
    }
} catch {
    ShowStackTrace $_
    exit 69
}
