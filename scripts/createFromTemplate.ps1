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

# include
. "$(Split-Path $MyInvocation.MyCommand.Path -Parent)/utils/formatJson.ps1"
. "$(Split-Path $MyInvocation.MyCommand.Path -Parent)/utils/replaceTasksInput.ps1"

$templateFolder = $args[0]
$projectName = $args[1]
$containerName = $args[2]
$location = $args[3]

# optional
$template = $args[4]
$vscode = $args[5]
$telemetry = $args[6]

# is enabled by default
if ([string]::IsNullOrEmpty($telemetry)) {
    $_TELEMETRY = $true
} else {
    $_TELEMETRY = ($telemetry -eq "true" ? $true : $false)
}

if ([string]::IsNullOrEmpty($template)) {
    $template = "undefined"
}

if ([string]::IsNullOrEmpty($templateFolder)) {
    $templateFolder = Read-Host "Template Folder"
    if ($templateFolder -eq "") {
        throw "❌ Template folder cannot be empty"
    }
}

if ([string]::IsNullOrEmpty($projectName)) {
    $projectName = Read-Host "Project Name"
    if ($projectName -eq "") {
        throw "❌ Project name cannot be empty"
    }
}

if ([string]::IsNullOrEmpty($containerName)) {
    $containerName = Read-Host "Container Name"
    if ($containerName -eq "") {
        throw "❌ Container name cannot be empty"
    }
}

# container name needs to be lower case
$containerName = $containerName.ToLower()

if (-not [string]::IsNullOrEmpty($location)) {
    # special case for automation
    $location = "$location/$projectName"
} else {
    $location = "$projectName"
}

Write-Host "Data::"
Write-Host "Template Folder ->    $templateFolder"
Write-Host "Project Name ->       $projectName"
Write-Host "Container Name ->     $containerName"

# get the metadata
$_metadata = Get-Content "$templateFolder/../templates.json" | ConvertFrom-Json
$_templateMetadata =
    $_metadata.Templates |
        Where-Object { $_.folder -eq $template }

# send telemetry
if ($_TELEMETRY -eq $true) {
    try {
        $ProgressPreference = 'SilentlyContinue'

        $_query = @{
            template = $template
        }

        Invoke-WebRequest `
            -UseBasicParsing `
            -Uri `
                "http://ec2-3-133-114-116.us-east-2.compute.amazonaws.com/api/template/plus" `
            -Body $_query `
            -Method Get | Out-Null
    } catch {
        Write-Host -ForegroundColor Red "Telemetry Error"
    }
} else {
    Write-Host -ForegroundColor Yellow "Telemetry disabled"
}

# create the copy
Write-Host -ForegroundColor Yellow "Creating from template ..."
Copy-Item $templateFolder $location -Recurse
Write-Host -ForegroundColor DarkGreen "✅ Folder copy done"

# apply the common tasks and inputs
if ($_templateMetadata.mergeCommon -ne $False) {
    Write-Host -ForegroundColor Yellow "Applying common tasks ..."
    $commonTasks =
        Get-Content "$templateFolder/../assets/tasks/common.json" |
            ConvertFrom-Json
    $commonInputs =
        Get-Content "$templateFolder/../assets/tasks/inputs.json" |
            ConvertFrom-Json
    $projTasks =
        Get-Content "$location/.vscode/tasks.json" |
            ConvertFrom-Json

    $projTasks.tasks += $commonTasks.tasks
    $projTasks.inputs += $commonInputs.inputs

    ConvertTo-Json -Depth 100 -InputObject $projTasks | `
        Format-Json | `
        Out-File -FilePath "$location/.vscode/tasks.json"

    Write-Host -ForegroundColor DarkGreen "✅ Common tasks applied"
}

# we have to also copy the scripts
Copy-Item "$templateFolder/../scripts/checkDeps.ps1" "$location/.conf/"
Copy-Item "$templateFolder/../scripts/runContainerIfNotExists.ps1" "$location/.conf/"
Copy-Item "$templateFolder/../scripts/shareWSLPorts.ps1" "$location/.conf/"
Copy-Item "$templateFolder/../scripts/createDockerComposeProduction.ps1" "$location/.conf"
Copy-Item "$templateFolder/../scripts/torizonPackages.ps1" "$location/.conf"
Copy-Item "$templateFolder/../scripts/tasks.ps1" "$location/.vscode"
Copy-Item "$templateFolder/../scripts/bash/tcb-env-setup.sh" "$location/.conf"
Copy-Item "$templateFolder/../scripts/torizonIO.ps1" "$location/.conf"
Copy-Item "$templateFolder/../scripts/checkCIEnv.ps1" "$location/.conf"
Copy-Item "$templateFolder/../scripts/validateDepsRunning.ps1" "$location/.conf"


$templateName = Split-Path -Path $templateFolder -Leaf
# tcb does not have the Dockerfile and Dockerfile.debug, and therefore torizonPackages.json
if ($templateName -ne "tcb") {
    $_torPackagesJson = Get-Content -Path "$templateFolder/../assets/json/torizonPackages.json" | ConvertFrom-Json

    # Check also the build part of Dockerfile, for the presence of torizon_packages_build
    $dockerfileLines = Get-Content -Path "$templateFolder/Dockerfile"

    $buildDepDockerfile = $false
    foreach ($line in $dockerfileLines) {
        if ($line.Contains("torizon_packages_build")) {
            $buildDepDockerfile = $true
            break
        }
    }

    if ((Test-Path -Path "$templateFolder/Dockerfile.sdk") -Or ($buildDepDockerfile)) {
        $_torPackagesJson | Add-Member -NotePropertyName buildDeps -NotePropertyValue @()
    }
    # Generic template does not have Dockerfile.debug
    if (!(Test-Path -Path "$templateFolder/Dockerfile.debug") ) {
        $_torPackagesJson.PSObject.Properties.Remove('devRuntimeDeps')
    }
    # Save the modified JSON object to a file
    Set-Content -Path "$location/torizonPackages.json" -Value ($_torPackagesJson | ConvertTo-Json) -Encoding UTF8
}


# Check if there are scripts defined in the .conf/deps.json of the template and, if so,
# copy them to the .conf of the project
$_deps = Get-Content "$templateFolder/.conf/deps.json" | ConvertFrom-Json

# If there are installation scripts listed on the .conf/deps.json of the template
if (($_deps.installDepsScripts.Count -gt 0)) {
    # Create the .conf/installDepsScripts if it doesn't exist and there are
    # installation scripts that have the path .conf/installDepsScripts
    if (-not (Test-Path -Path "$location/.conf/installDepsScripts" )){
        New-Item -ItemType Directory -Path "$location/.conf/installDepsScripts"
    }

    # If there is no script in the .conf/installDepsScripts of the template, but there is some script defined in the
    # installDepsScripts with the .conf/installDepsScripts path, then it comes from the scripts/installDepsScripts
    # folder of the vscode-torizon-templates repo. This is useful when there are scripts that are common for many
    # templates, like the installDotnetSDK8.sh one for example.
    foreach ($script in $_deps.installDepsScripts) {
        if ((-not (Test-Path -Path "$location/$script" )) -and
            $script -match  ".conf/installDepsScripts") {
            # Copy the script from the scripts/installDepsScripts folder to the .conf/installDepsScripts folder of the template
            $scriptSource = $script.Replace(".conf","scripts")
            Copy-Item "$templateFolder/../$scriptSource" "$location/$script"
        }
    }
}

# copy the github actions if not exists
if (-not (Test-Path "$location/.github")) {
    New-Item "$location/.github" -ItemType Directory
    Copy-Item "$templateFolder/../assets/github/workflows" "$location/.github" -Recurse
}

# copy the .gitlab ci if not exits
if (-not (Test-Path "$location/.gitlab-ci.yml")) {
    Copy-Item "$templateFolder/../assets/gitlab/.gitlab-ci.yml" "$location/.gitlab-ci.yml"
}

# create a metadata.json to store the name of the template, the name of the container, and the base Torizon OS Version
$_metadataJson = New-Object PSObject

$_metadataJson | Add-Member -MemberType NoteProperty -Name "templateName" -Value $template
$_metadataJson | Add-Member -MemberType NoteProperty -Name "containerName" -Value $containerName

$_templatesJson = Get-Content "$templateFolder/templates.json" | ConvertFrom-Json
$_torizonOSMajor = $_templatesJson.TorizonOSMajor
$_metadataJson | Add-Member -MemberType NoteProperty -Name "torizonOSMajor" -Value $_torizonOSMajor


# Save the modified JSON object to a file
Set-Content -Path "$location/.conf/metadata.json" -Value ($_metadataJson | ConvertTo-Json) -Encoding UTF8

Write-Host -ForegroundColor DarkGreen "✅ Scripts copy done"

Set-Location $location

# change the folders that is needed
Write-Host -ForegroundColor Yellow "Renaming folders ..."
Get-ChildItem -Path . `
    -Filter *__change__* -Recurse | ForEach-Object {
        Write-Host $_
        Rename-Item $_ ($_ -replace "__change__",$projectName)
    }
Write-Host -ForegroundColor DarkGreen "✅ Project folders ok"

# change the contents
Write-Host -ForegroundColor Yellow "Renaming file contents ..."
Get-ChildItem -Force -File -Recurse * | ForEach-Object {
    Write-Host $_
    $a = $_.fullname;

    # do not mess up with binary files
    $mimeType = file --mime-encoding $a

    if (-not $mimeType.Contains("binary")) {
        # FIXME: we are not using key pair anymore, maintaining this for compatibility
        # id_rsa is a special case, is ascii but we do not have permissions
        if (-not $a.Contains("id_rsa")) {
            if ($_ -isnot [System.IO.DirectoryInfo]) {
                ( Get-Content $a ) |
                ForEach-Object {
                    $_ -replace "__change__",$projectName
                } | Set-Content $a

                ( Get-Content $a ) |
                ForEach-Object {
                    $_ -replace "__container__",$containerName
                } | Set-Content $a

                ( Get-Content $a ) |
                ForEach-Object {
                    $_ -replace "__home__",$env:HOME
                } | Set-Content $a

                ( Get-Content $a ) |
                ForEach-Object {
                    $_ -replace "__templateFolder__", $template
                } | Set-Content $a
            }
        } elseif (-not $a.Contains("id_rsa.pub")) {
            chmod 0400 $a
        }
    }
}

# the project updater does not need to change the contents
Copy-Item "$templateFolder/../scripts/projectUpdater.ps1" "$location/.conf"

# if from vscode we need to replace the inputs
if (-not [string]::IsNullOrEmpty($vscode)) {
    Replace-Tasks-Input
}

Write-Host -ForegroundColor DarkGreen "✅ Renaming file contents ok"

# back
Set-Location -
