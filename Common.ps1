# Common commands for managing profiles.
# These commands are not intended for use outside the scripts in this repository.

<#
.SYNOPSIS
Gets the paths of various standard config files and scripts.
#>
function Get-ProfileConfigPath
{
    $configDirectory = Join-Path $PSScriptRoot Profiles

    return [PSCustomObject] @{
        ConfigDirectory   = $configDirectory
        ConfigFile        = Join-Path $configDirectory ProfileConfig.jsonc
        TemplateFile      = Join-Path $PSScriptRoot ProfileConfig.Template.jsonc
        PreProfileScript  = Join-Path $configDirectory PreProfileScript.ps1
        PostProfileScript = Join-Path $configDirectory PostProfileScript.ps1
    }
}

<#
.SYNOPSIS
Gets the configured profiles.

.DESCRIPTION
Long description

.PARAMETER ProfileName
The name of the profile to get.
If not specified, this will default to '*' result in all profiles being returned.
#>
function Get-ProfileInfo
{
    param (
        [Parameter()]
        [SupportsWildcards()]
        [string]
        $ProfileName = "*"
    )

    begin
    {
        function readJson
        {
            [CmdletBinding()]
            param (
                [Parameter(
                    Mandatory,
                    Position = 0
                )]
                [string]
                $Path
            )

            if ($PSVersionTable.PSVersion.Major -ge 6)
            {
                return Get-Content $Path | ConvertFrom-Json
            }
            else
            {
                # The ConvertFrom-Json command in PowerShell 6 supports comments and trailing commas.
                # We must strip them out if we are executing in an older version PowerShell.
                $content = Get-Content $Path -Raw

                # Remove all line and block comments that are not in strings.
                # Source: https://stackoverflow.com/a/57092959/2503153
                $content = $content -replace '(?m)(?<=^([^"]|"[^"]*")*)//.*' -replace '(?ms)/\*.*?\*/'

                # Remove trailing commas that are not in strings.
                $content = $content -replace '(?m)(?<=^([^"]|"[^"]*")*),(?=\s*[}\]])'

                return $content | ConvertFrom-Json
            }
        }
    }

    process
    {
        $path = Get-ProfileConfigPath

        # Get the config data.
        $configFile = Get-Item $path.ConfigFile -ErrorAction SilentlyContinue
        if ($configFile -and $configFile.Length -gt 0)
        {
            $config = readJson $path.ConfigFile
        }

        # If we failed to read the config file, fall back to the template config file.
        # This is expected on first-run.
        if (-not $config)
        {
            $config = readJson $path.TemplateFile
        }

        # Set the configured profile settings.
        $config.profiles | Where-Object Name -Like $ProfileName | ForEach-Object {
            $profileConfig = $_
            $name = $profileConfig.name

            # Start with default settings.
            $profileProperties = @{
                showLongLoadTime      = $true
                longLoadTimeThreshold = 1
            }

            # Set the configured defaults.
            $config.defaults.PSObject.Properties | ForEach-Object {
                if ($_)
                {
                    $profileProperties[$_.Name] = $_.Value
                }
            }

            # Overrite the default settings with profile-specific settings.
            $profileConfig.PSObject.Properties | ForEach-Object {
                if ($profileProperties[$_.Name] -is [array])
                {
                    $profileProperties[$_.Name] += $_.Value
                }
                else
                {
                    $profileProperties[$_.Name] = $_.Value
                }
            }

            # Construct the name of the script that Profile.ps1 will execute for this profile.
            $profileScriptName = "profile_$name.ps1"

            return @{
                Name       = $name
                ScriptPath = Join-Path $path.ConfigDirectory $profileScriptName
                Config     = $profileProperties
            }
        }
    }
}

<#
.SYNOPSIS
Creates config files if necessary.
#>
function Initialize-ProfileConfig
{
    [CmdletBinding(SupportsShouldProcess)]
    param ()

    process
    {
        $configPath = Get-ProfileConfigPath

        # Create the Profiles directory if it doesn't already exist.
        if (-not (Test-Path $configPath.ConfigDirectory))
        {
            New-Item $configPath.ConfigDirectory -ItemType Directory | Out-Null
        }

        # Clone the default config if the personal config is empty.
        if (-not (Test-Path $configPath.ConfigFile) -or (Get-Item $configPath.ConfigFile).Length -eq 0)
        {
            Write-Debug "Creating the config file."
            Get-Content $configPath.TemplateFile | ForEach-Object {
                # Because we are using a relative path reference for the Json schema,
                # we must fix the path when we copy the file to a child directory.
                $_ -replace `
                    [regex]::Escape('"$schema": "./ProfileConfig.Schema.json"'), `
                    '"$schema": "../ProfileConfig.Schema.json"'
            } | Set-Content $configPath.ConfigFile -ErrorAction Inquire
        }

        # While these flags are not necessary, they help reduce WhatIf spam.
        # Otherwise, the user would be notified for the creation of these scripts on each profile.
        # Without WhatIf, these scripts would only be created once.
        [ref] $hasCreatedPreProfileConfigScript = $false
        [ref] $hasCreatedPostProfileConfigScript = $false

        # Initialize all configured profiles.
        Get-ProfileInfo | ForEach-Object {
            $profileInfo = $_
            $profileName = $profileInfo.name

            Write-Verbose "Initializing the config files for the '$profileName' profile."

            # If needed, create the config script that will be executed before the profile config script.
            # Only create the script if at least one profile is configured to use it.
            if ($profileInfo.Config.usePreProfileConfigScript -and `
                    -not $hasCreatedPreProfileConfigScript.Value -and `
                    -not (Test-Path $configPath.PreProfileScript))
            {
                $hasCreatedPreProfileConfigScript.Value = $true
                Write-Debug "Creating the pre-profile config script."
                @(
                    "# This script will be executed before the profile config script."
                    "# Any functions or variables created in the script scope of this file"
                    "# will be added to the global scope."
                ) | Set-Content $configPath.PreProfileScript
            }

            # If needed, create the profile config script that Profile.ps1 will execute.
            # Only create the script if the profile is configured to use it.
            if ($profileInfo.Config.useProfileConfigScript -and -not (Test-Path $profileInfo.ScriptPath))
            {
                Write-Debug "Creating the profile config script."
                @(
                    "# This profile config script will be executed while loading the $profileName profile."
                    "# Any functions or variables created in script scope of this file"
                    "# will be added to the global scope."
                ) | Set-Content $profileInfo.ScriptPath
            }

            # If needed, create the config script that will be executed after the profile config script.
            # Only create the script if at least one profile is configured to use it.
            if ($profileInfo.Config.usePostProfileConfigScript -and `
                    -not $hasCreatedPostProfileConfigScript.Value -and `
                    -not (Test-Path $configPath.PostProfileScript))
            {
                $hasCreatedPostProfileConfigScript.Value = $true
                Write-Debug "Creating the post-profile config script."
                @(
                    "# This script will be executed after the profile config script."
                    "# Any functions or variables created in the script scope of this file"
                    "# will be added to the global scope."
                ) | Set-Content $configPath.PostProfileScript
            }
        }
    }
}
