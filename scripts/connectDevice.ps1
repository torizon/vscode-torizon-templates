#!/usr/bin/env pwsh
param(
    [Parameter(Mandatory=$true)]
    [int] $id,
    [Parameter(Mandatory=$true)]
    [string] $login,
    [Parameter(Mandatory=$true)]
    [string] $pass
)

$errorActionPreference = "Stop"
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', "Internal PS variable"
)]
$PSNativeCommandUseErrorActionPreference = $true

# include
. "$env:HOME/.apollox/scripts/utils/animations.ps1"
. "$env:HOME/.apollox/scripts/utils/stackTrace.ps1"
. "$env:HOME/.apollox/scripts/utils/network.ps1"

# present it to the user with the index identifier
Write-Host "📡 :: CONNECTING DEVICE :: 📡"
Write-Host ""

# connect to the device
try {
    $_connectDevs = New-Object System.Collections.ArrayList

    # first check if the device is already connected
    if (Test-Path $env:HOME/.tcd/connected.json) {
        $_jsonArray = Get-Content $env:HOME/.tcd/connected.json `
            | ConvertFrom-Json -Depth 100

        foreach ($_dev in $_jsonArray) {
            $_connectDevs.Add($_dev) | Out-Null
        }
    }

    # get the scan from the file
    if (Test-Path $env:HOME/.tcd/scan.json) {
        $_nets = Get-Content $env:HOME/.tcd/scan.json `
            | ConvertFrom-Json -Depth 100
    } else {
        $_nets = @()
    }

    if ($_nets.Count -eq 0) {
        Write-Host -ForegroundColor DarkYellow `
            "`t ⚠️ :: No network devices found :: ⚠️"
        Write-Host ""
        Write-Host "Did you ran the scan command?"
        Write-Host ""
        exit 404
    }

    if ($id -lt 0 -or $id -ge $_nets.Count) {
        Write-Host -ForegroundColor Red `
            "`t ❌ :: Invalid device id :: ❌"
        Write-Host ""
        exit 400
    }

    $_net = $_nets[$id]

    if ($_connectDevs.Count -gt 0) {
        # check if the device is already connected
        foreach ($_dev in $_connectDevs) {
            if ($_dev.Ip -eq $_net.Ip) {
                $_hostName = $_net.Hostname

                Write-Host -ForegroundColor DarkYellow `
                    "`t ⚠️ :: Device $_hostname already connected :: ⚠️"
                Write-Host ""
                exit 0
            }
        }
    }

    $_hostName = $_net.Hostname
    Write-Host "`t Trying to connect to $_hostName"
    Write-Host ""

    $_dev = RunCommandInBackgrounWithWaitAnimation {
        param(
            [Parameter(Mandatory=$true)]
            [int] $id,
            [Parameter(Mandatory=$true)]
            [string] $login,
            [Parameter(Mandatory=$true)]
            [string] $pass,
            [Parameter(Mandatory=$true)]
            [string] $hostIp
        )

        node $env:HOME/.apollox/scripts/node/connectNetworkDevice.mjs `
            $id `
            $login `
            $pass `
            $hostIp
    } @($id, $login, $pass, $(GetHostIp)) `
        | ConvertFrom-Json -Depth 100


    # add the __pass__ member to the object
    $_dev | Add-Member -MemberType NoteProperty `
        -Name "__pass__" -Value $pass

    $_connectDevs.Add($_dev) | Out-Null
    $_connectDevs | ConvertTo-Json -AsArray -Depth 100 `
        | Out-File $env:HOME/.tcd/connected.json

    $_hostName = $_dev.Hostname
    $_ip = $_dev.Ip
    $_tcVersion = $_dev.Version
    $_model = $_dev.Model
    $_arch = $_dev.Arch

    Write-Host -ForegroundColor Green `
        "`t ✅ :: Connected to device :: ✅"
    Write-Host ""
    Write-Host "`t Hostname:            $_hostName"
    Write-Host "`t IP Address:          $_ip"
    Write-Host "`t TorizonCore Version: $_tcVersion"
    Write-Host "`t Model:               $_model"
    Write-Host "`t Architecture:        $_arch"
    Write-Host ""
} catch {
    Write-Host -ForegroundColor Red `
        "`t ❌ :: Could not connect to device :: ❌"
    Write-Host ""

    ShowStackTrace $_
    exit 500
}

Write-Host ""
