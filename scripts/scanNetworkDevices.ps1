#!/usr/bin/env pwsh

# include
. "$env:HOME/.apollox/scripts/utils/animations.ps1"

Write-Host "📡 :: NETWORK DEVICES :: 📡"
Write-Host ""

if (
    $null -eq $args[0]
) {
    RunCommandInBackgroundWithWaitAnimationAsync {
        node $env:HOME/.apollox/scripts/node/scanNetworkDevices.mjs
    }
}

# read the output
if (
    Test-Path "$env:HOME/.tcd/scan.json"
) {
    $nets = Get-Content "$env:HOME/.tcd/scan.json" | ConvertFrom-Json
} else {
    $nets = @()
}

if ($nets.Length -lt 1) {
    Write-Host -ForegroundColor DarkYellow `
        "`t ❌ :: No network devices found :: ❌"
    Write-Host ""
    exit 404
} elseif ($args[0] -eq "display") {
    $_ix = 0
    foreach ($net in $nets) {
        $_ip = $net.Ip
        $_hostname = $net.Hostname

        Write-Host "`t`t $_ix ➡️  $_hostname ($_ip)"

        $_ix++
    }
}

Write-Host ""
