# Common commands for managing profiles.
# These commands are not intended for use outside the scripts in this repository.

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
        $configFile = Get-Item $path.ConfigFile
        if ($configFile.Length -gt 0)
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
            $profileScriptName = "profile_$profileName.ps1"

            return @{
                Name       = $name
                ScriptPath = Join-Path $path.ConfigDirectory $profileScriptName
                Config     = $profileProperties
            }
        }
    }
}
