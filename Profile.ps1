# Wrap everything in a script block to avoid adding functions and variables to the global scope.
& {
    function getProfile
    {
        param (
            [Parameter()]
            [string]
            $ProfileName
        )

        $config = Get-Content "$PSScriptRoot\Profiles\ProfileConfig.jsonc" | ConvertFrom-Json

        $profileProperties = [System.Collections.Specialized.OrderedDictionary]::new()

        $config.defaults.PSObject.Properties | Where-Object { $_ } | ForEach-Object {
            $profileProperties.($_.Name) = $_.Value
        }

        $config.profiles | Where-Object Name -EQ $ProfileName | ForEach-Object {
            $_.PSObject.Properties | Where-Object { $_ } | ForEach-Object {
                if ($profileProperties.($_.Name) -is [array])
                {
                    $profileProperties.($_.Name) += $_.Value
                }
                else
                {
                    $profileProperties.($_.Name) = $_.Value
                }
            }
        }

        return [PSCustomObject] $profileProperties
    }

    $profileProperties = getProfile -Profile $Global:PSProfile

    if ($profileProperties.writeProfileOnStart)
    {
        Write-Host "Profile: $Global:PSProfile"
        Write-Host
    }

    # Configure history.
    if ($profileProperties.useProfileSpecificHistory)
    {
        $historyDirectory = Split-Path (Get-PSReadLineOption).HistorySavePath
        $profileHistoryPath = Join-Path $historyDirectory "$($Global:PSProfile)_history.txt"
        if (-not (Test-Path $profileHistoryPath))
        {
            New-Item $profileHistoryPath -ItemType File | Out-Null
        }

        Set-PSReadLineOption -HistorySavePath $profileHistoryPath
    }

    # Configure modules.
    if ($profileProperties.moduleLocations)
    {
        $env:PSModulePath += ";" + ($profileProperties.moduleLocations -join ";")
    }

    if ($profileProperties.autoImportModules)
    {
        $profileProperties.autoImportModules | Import-Module
    }

    # Source local profile.
    $allProfilesScriptPath = Join-Path $PSScriptRoot Profiles -AdditionalChildPath AllProfiles.ps1
    if (Test-Path $allProfilesScriptPath)
    {
        $allProfilesScriptPath
    }

    $localProfileScriptPath = Join-Path $PSScriptRoot Profiles -AdditionalChildPath ($Global:PSProfile + "_profile.ps1")
    if (Test-Path $localProfileScriptPath)
    {
        $localProfileScriptPath
    }

    # Source workspace profile.
    if ($profileProperties.localProfile -and (Test-Path $profileProperties.localProfile))
    {
        $localProfile = Resolve-Path $profileProperties.localProfile
        $localProfile
    }
} | ForEach-Object {
    if ($_)
    {
        . $_
    }
}
