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
param()

$settingsTemplate = [PSCustomObject]@{
    "torizon_psswd" = ""
    "torizon_login" = ""
    "torizon_ip" = ""
    "torizon_ssh_port" = ""
    "host_ip" = ""
    "torizon_workspace" = "$`{workspaceFolder`}"
    "torizon_debug_ssh_port" = "2222"
    "torizon_debug_port1" = ""
    "torizon_debug_port2" = ""
    "torizon_debug_port3" = ""
    "torizon_gpu" = ""
    "torizon_arch" = ""
    "wait_sync" = "1"
    "torizon_run_as" = "torizon"
    "torizon_app_root" = "/home/torizon/app"
    "docker_tag" = "v0.0.0"
    "tcb.packageName" = "__change__"
    "tcb.version" = "3.11.0"
    "torizon.gpuPrefixRC" = $false
}

# update all the .vscode/settings.json
Write-Host -ForegroundColor Yellow "Updating settings.json ..."
Get-ChildItem -Path ../ `
    -Force -Filter settings.json -Recurse | ForEach-Object {
        Write-Host $_

        if (-not $_.DirectoryName.Contains("vscode-torizon-templates/.vscode")) {
            $old = Get-Content $_ | ConvertFrom-Json
            $oldFields = $old | Get-Member *
            $newFields = $settingsTemplate | Get-Member *

            foreach ($field in $newFields) {
                $hasField = $false

                foreach ($checkField in $oldFields) {
                    if ($checkField.Name -eq $field.Name) {
                        $hasField = $true
                    }
                }

                if (-not $hasField) {
                    # need to update
                    $old | `
                        Add-Member -MemberType NoteProperty `
                        -Name $field.Name `
                        -Value $settingsTemplate.($field.Name)
                }
            }

            # ok, now that we have all the fields updated, order them to the same
            # order as the $stringsTemplate
            # Get the ordered list of property names from $settingsTemplate
            $orderedPropertyNames = $settingsTemplate.PSObject.Properties.Name

            # Create a new object with properties in the order of $settingsTemplate
            $newOld = New-Object PSObject

            foreach ($prop in $orderedPropertyNames) {
                if ($old.PSObject.Properties.Name -contains $prop) {
                    $newOld | Add-Member -MemberType NoteProperty -Name $prop -Value $old.$prop
                }
            }

            # Add any remaining properties from $old that were not in $settingsTemplate
            foreach ($prop in $old.PSObject.Properties.Name) {
                if ($newOld.PSObject.Properties.Name -notcontains $prop) {
                    $newOld | Add-Member -MemberType NoteProperty -Name $prop -Value $old.$prop
                }
            }

            # Now $newOld has the same properties as $old, but in the order of $settingsTemplate
            $old = $newOld

            ConvertTo-Json -InputObject $old | Out-File -FilePath $_
        }
    }
