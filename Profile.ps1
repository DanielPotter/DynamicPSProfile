# Execute the profile in a new scope to avoid adding unwanted variables to the global scope.
& {
    $startTime = Get-Date

    # Dot source common commands.
    . (Join-Path $PSScriptRoot Common.ps1)

    $profileInfo = Get-ProfileInfo -ProfileName $Global:PSProfile

    # If desired, print the name of the profile.
    if ($profileInfo.Config.writeProfileOnStart)
    {
        Write-Host "Profile: $Global:PSProfile"
        Write-Host
    }

    # If desired, set the history path to be specific to this profile.
    if ($profileInfo.Config.useProfileSpecificHistory)
    {
        # Get the directory of the default history file.
        $historyDirectory = Split-Path (Get-PSReadLineOption).HistorySavePath

        # Ensure the profile-specific history file exists.
        $profileHistoryPath = Join-Path $historyDirectory "$($Global:PSProfile)_history.txt"
        if (-not (Test-Path $profileHistoryPath))
        {
            New-Item $profileHistoryPath -ItemType File | Out-Null
        }

        # Set the path to the history file.
        Set-PSReadLineOption -HistorySavePath $profileHistoryPath
    }

    # Add configured module locations.
    if ($profileInfo.Config.moduleLocations)
    {
        $env:PSModulePath += ";" + ($profileInfo.Config.moduleLocations -join ";")
    }

    # Import configured modules.
    if ($profileInfo.Config.autoImportModules)
    {
        $profileInfo.Config.autoImportModules | Import-Module
    }

    # Get the standard paths of config files and scripts from Common.ps1.
    $configPath = Get-ProfileConfigPath

    # If desired, execute the pre-profile config script.
    if ($profileInfo.Config.usePreProfileConfigScript)
    {
        # Write the path to the pipeline so it can be dot sourced.
        $configPath.PreProfileScript
    }

    # If desired, execute the profile config script.
    if ($profileInfo.Config.useProfileConfigScript)
    {
        # Write the path to the pipeline so it can be dot sourced.
        $profileInfo.ScriptPath
    }

    # If specified, execute the workspace config script.
    if ($profileInfo.Config.workspaceProfile)
    {
        # Write the path to the pipeline so it can be dot sourced.
        $profileInfo.Config.workspaceProfile
    }

    # If desired, execute the post-profile config script.
    if ($profileInfo.Config.usePostProfileConfigScript)
    {
        # Write the path to the pipeline so it can be dot sourced.
        $configPath.PostProfileScript
    }

    # We are done setting up the profile.
    $endTime = Get-Date

    # If the profile took a long time to load, notify the user.
    if ($profileInfo.Config.showLongLoadTime)
    {
        $loadTime = New-TimeSpan -Start $startTime -End $endTime

        # Display the loading time message if it took a greater time than the configured threshold.
        # This threshold defaults to one second.
        if ($loadTime.TotalSeconds -gt $profileInfo.Config.longLoadTimeThreshold)
        {
            Write-Host "Loading personal profile took $([int]$loadTime.TotalMilliseconds)ms."
        }
    }
} | ForEach-Object {
    if ($_ -and (Test-Path $_))
    {
        # Resolve the path because dot sourcing sometimes has trouble with relative paths.
        $absolutePath = Resolve-Path $_

        # Dot source the file into the global scope.
        # This works because ForEach-Object executes this block in the parent scope.
        . $absolutePath
    }
}
