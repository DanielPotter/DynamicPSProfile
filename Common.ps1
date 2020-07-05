# Common commands for managing profiles.
# These commands are not intended for use outside the scripts in this repository.

function Get-ProfileConfigPath
{
    $configDirectory = Join-Path $PSScriptRoot Profiles
    $configFile = Join-Path $configDirectory ProfileConfig.jsonc
    $defaultConfigFile = Join-Path $PSScriptRoot ProfileConfig.Default.jsonc

    return [PSCustomObject] @{
        ConfigDirectory = $configDirectory
        ConfigFile      = $configFile
        DefaultFile     = $defaultConfigFile
    }
}

function Get-ProfileConfig
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
            # Start with default settings.
            $profileProperties = [ordered] @{
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

            $_.PSObject.Properties | ForEach-Object {
                if ($profileProperties[$_.Name] -is [array])
                {
                    $profileProperties[$_.Name] += $_.Value
                }
                else
                {
                    $profileProperties[$_.Name] = $_.Value
                }
            }

            return $profileProperties
        }
    }
}
