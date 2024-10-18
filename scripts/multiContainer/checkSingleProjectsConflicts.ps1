# suppress warnings that we need to use
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidOverwritingBuiltInCmdlets', ""
)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingWriteHost', ""
)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingInvokeExpression', ""
)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingPositionalParameters', ""
)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidGlobalVars', ""
)]

param(
    [Parameter(Mandatory=$false)]
    [bool] $acceptAll
)

$scriptDir = Split-Path $MyInvocation.MyCommand.Path
$workspaceDir = Split-Path -Parent $scriptDir

Push-Location $workspaceDir

$projectName = $objMetadata.multiContainerProjectName

$objCodeWorkspaces = Get-Content ("./*.code-workspace") | `
    Out-String | ConvertFrom-Json

function AddValue ($list, $name, $settingName, $value) {
    if ($value -ne "") {
        $list.Add(@{ "name" = $name; "settingName" = $settingName; "settingValue" = [int]$value}) | out-null
    }
}

function FixDuplicates ($settingsList) {
    $duplicated = $false
    $list = $settingsList
    $i = 0
    while ($i -lt $list.Count -1) {

        if ($list[$i].settingValue -eq $list[$i+1].settingValue ) {
            $duplicated = $true
            $j=$i+1
            while ($list[$j+1].settingValue - $list[$j].settingValue -lt 2) {
                if ($j+1 -eq $list.Count) {
                    break
                } else {
                    $j = $j + 1
                }
            }
            $newSettingValue = [int]$list[$j].settingValue + 1
            Write-Host -ForegroundColor Yellow " $($list[$i].name) $($list[$i].settingName) and $($list[$i+1].name) $($list[$i+1].settingName) have the same value $($list[$i].settingValue) -> new suggested value for $($list[$i].name) $($list[$i].settingName) : $newSettingValue"
            $list[$i].settingValue = $newSettingValue
            $sortedList = $list | Sort-Object -Property settingValue
            $list = $sortedList
        } else {
            $i = $i+1
        }
    }
    return $list, $duplicated
}


$dockerComposeYaml = Get-Content ("./docker-compose.yml") | Out-String | ConvertFrom-Yaml

$dockerComposePorts = New-Object System.Collections.ArrayList

foreach ($service in $dockerComposeYaml.services.GetEnumerator()) {
    foreach ($port in $service.Value.ports) {
        $hostPort = $($port -split ":")[0]
        $hostNum = $hostPort -as [int]
        if ($null -ne $hostNum) {
            if ($dockerComposePorts.settingValue -contains $hostPort) {
                Write-Output "$hostPort host port is duplicated on docker-compose.yml"
            } else {
                AddValue $dockerComposePorts $projectName "yaml_docker_compose_port" $hostPort
            }
        }
    }
}

$debugPortsSettings = New-Object System.Collections.ArrayList

$waitSyncSettings = New-Object System.Collections.ArrayList


foreach ($item in $objCodeWorkspaces.folders){
    $projectName = $item.path
    if ($projectName -ne ".") {
        $projectSettings = Get-Content ("$projectName/.vscode/settings.json") | Out-String | ConvertFrom-Json

        AddValue $debugPortsSettings $projectName "torizon_debug_ssh_port" $projectSettings.torizon_debug_ssh_port
        AddValue $debugPortsSettings $projectName "torizon_debug_port1" $projectSettings.torizon_debug_port1
        AddValue $debugPortsSettings $projectName "torizon_debug_port2" $projectSettings.torizon_debug_port2
        AddValue $debugPortsSettings $projectName "torizon_debug_port3" $projectSettings.torizon_debug_port3

        AddValue $waitSyncSettings $projectName "wait_sync" $projectSettings.wait_sync
    }
}

$debugPortsSettings += $dockerComposePorts

if ( $debugPortsSettings.Count -gt 1) {
    $sortedDebugPortsSettings = $debugPortsSettings | Sort-Object -Property settingValue
    $newDebugPortsSettings, $debugPortDuplicated = FixDuplicates $sortedDebugPortsSettings
}

if ( $waitSyncSettings.Count -gt 1) {
    $sortedWaitSyncSettings = $waitSyncSettings | Sort-Object -Property settingValue
    $newWaitSyncSettings, $waitSyncDuplicated = FixDuplicates $sortedWaitSyncSettings
}


if ($debugPortDuplicated -or $waitSyncDuplicated) {

    if ($acceptAll -eq $true) {
        $_updateConfirm = 'y'
    } else {
        $_updateConfirm = Read-Host `
            "Do you want to update the debug ports and wait_syncs to the suggested values? <y/N>"
    }

    if ($_updateConfirm -eq 'y') {

        foreach ($item in $objCodeWorkspaces.folders){
            $projectName = $item.path
            if ($projectName -ne ".") {
                $projectSettings = Get-Content ("$projectName/.vscode/settings.json") | Out-String | ConvertFrom-Json

                foreach ($setting in $newDebugPortsSettings) {
                    if ($setting.name -eq $projectName) {
                        $settingName = $setting.settingName
                        $projectSettings.$settingName = [string]$setting.settingValue
                    }
                }
                foreach ($setting in $newWaitSyncSettings) {
                    if ($setting.name -eq $projectName) {
                        $settingName = $setting.settingName
                        $projectSettings.$settingName = [string]$setting.settingValue
                    }
                }

                ConvertTo-Json -Depth 100 -InputObject $projectSettings | `
                    Out-File -FilePath "$projectName/.vscode/settings.json"
            }
        }
        Write-Host -ForegroundColor DarkGreen "✅ Debug port and wait_sync settings conflicts solved (new setting values applied)"
    }   else {
        Write-Host -ForegroundColor DarkRed "❌ Please solve debug port and wait_sync settings conflicts before running the commands"
    }
} else {
    Write-Host -ForegroundColor DarkGreen "✅ No debug port or wait_sync settings conflicts"
}

Pop-Location
