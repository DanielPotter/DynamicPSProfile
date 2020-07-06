# Common commands for managing profiles.
# These commands are not intended for use outside the scripts in this repository.

function Get-ProfileConfigPath
{
    $configDirectory = Join-Path $PSScriptRoot Profiles

    return [PSCustomObject] @{
        ConfigDirectory   = $configDirectory
        ConfigFile        = Join-Path $configDirectory ProfileConfig.jsonc
        DefaultFile       = Join-Path $PSScriptRoot ProfileConfig.Default.jsonc
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

    process
    {
        $path = Get-ProfileConfigPath

        # Get the config data.
        $configContent = Get-Content $path.ConfigFile -ErrorAction SilentlyContinue
        if ($configContent)
        {
            $config = $configContent | ConvertFrom-Json
        }
        else
        {
            # Fall back to the default config file.
            $config = Get-Content $path.DefaultFile | ConvertFrom-Json
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
