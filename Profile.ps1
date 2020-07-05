# Execute the profile in a new scope to avoid adding variables to the global scope.
& {
    $startTime = Get-Date

    $config = Get-Content "$PSScriptRoot\Profiles\ProfileConfig.jsonc" | ConvertFrom-Json

    # Start with default settings.
    $profileProperties = [ordered] @{
        showLongLoadTime      = $true
        longLoadTimeThreshold = 1
    }

    # Set the configured defaults.
    $config.defaults.PSObject.Properties | Where-Object { $_ } | ForEach-Object {
        $profileProperties.($_.Name) = $_.Value
    }

    # Set the configured profile settings.
    $config.profiles | Where-Object Name -EQ $Global:PSProfile | ForEach-Object {
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

    # If desired, print the name of the profile.
    if ($profileProperties.writeProfileOnStart)
    {
        Write-Host "Profile: $Global:PSProfile"
        Write-Host
    }

    # If desired, set the history path to be specific to this profile.
    if ($profileProperties.useProfileSpecificHistory)
    {
        # Get the directory of the default history file.
        $historyDirectory = Split-Path (Get-PSReadLineOption).HistorySavePath

        # Ensure the profile-specific hisotry file exists.
        $profileHistoryPath = Join-Path $historyDirectory "$($Global:PSProfile)_history.txt"
        if (-not (Test-Path $profileHistoryPath))
        {
            New-Item $profileHistoryPath -ItemType File | Out-Null
        }

        # Set the path to the history file.
        Set-PSReadLineOption -HistorySavePath $profileHistoryPath
    }

    # Add configured module locations.
    if ($profileProperties.moduleLocations)
    {
        $env:PSModulePath += ";" + ($profileProperties.moduleLocations -join ";")
    }

    # Import configured modules.
    if ($profileProperties.autoImportModules)
    {
        $profileProperties.autoImportModules | Import-Module
    }

    $allProfilesScriptPath = Join-Path $PSScriptRoot Profiles -AdditionalChildPath AllProfiles.ps1
    if (Test-Path $allProfilesScriptPath)
    {
        # Return the path of the global personal profile to be dot sourced.
        $allProfilesScriptPath
    }

    $profileScriptPath = Join-Path $PSScriptRoot Profiles -AdditionalChildPath ($Global:PSProfile + "_profile.ps1")
    if (Test-Path $profileScriptPath)
    {
        # Return the path of the profile-specific script to be dot sourced.
        $profileScriptPath
    }

    if ($profileProperties.workspaceProfile -and (Test-Path $profileProperties.workspaceProfile))
    {
        # Resolve the path because dot sourcing sometimes has trouble with relative paths.
        $workspaceProfile = Resolve-Path $profileProperties.workspaceProfile

        # Return the path of the workspace profile.
        $workspaceProfile
    }

    $endTime = Get-Date

    $loadTime = New-TimeSpan -Start $startTime -End $endTime

    # If the profile took a long time to load, notify the user.
    if ($profileProperties.showLongLoadTime)
    {
        if ($loadTime.TotalSeconds -gt $profileProperties.longLoadTimeThreshold)
        {
            Write-Host "Loading personal profile took $([int]$loadTime.TotalMilliseconds)ms."
        }
    }
} | ForEach-Object {
    if ($_)
    {
        # Dot source the file into the global scope.
        # This works because ForEach-Object executes this block in the parent scope.
        . $_
    }
}
