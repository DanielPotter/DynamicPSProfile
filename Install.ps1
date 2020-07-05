[CmdletBinding(SupportsShouldProcess)]
param ()

process
{
    $personalProfileDirectoryPath = Join-Path $PSScriptRoot Profiles
    $personalConfigFilePath = Join-Path $personalProfileDirectoryPath ProfileConfig.jsonc
    $defaultConfigFilePath = Join-Path $PSScriptRoot ProfileConfig.Default.jsonc

    # Create the Profiles directory if it doesn't already exist.
    if (-not (Test-Path $personalProfileDirectoryPath))
    {
        New-Item $personalProfileDirectoryPath -ItemType Directory | Out-Null
    }

    # Clone the default config if the personal config is empty.
    if (-not (Test-Path $personalConfigFilePath) -or (Get-Item $personalConfigFilePath).Length -eq 0)
    {
        Get-Content $defaultConfigFilePath | ForEach-Object {
            # Replace the schema reference for the personal config file
            # because it will be placed in a child directory.
            $_ -replace [regex]::Escape('"$schema": "./ProfileConfig.Schema.json"'), '"$schema": "../ProfileConfig.Schema.json"'
        } | Set-Content $personalConfigFilePath -ErrorAction Inquire
    }

    # Create the script that will be sourced for all profiles.
    $personalScriptStubPath = Join-Path $personalProfileDirectoryPath AllProfiles.ps1
    if (-not (Test-Path $personalScriptStubPath))
    {
        New-Item $personalScriptStubPath -ItemType File | Out-Null
    }

    # Grab the directory of the PowerShell profile directory.
    # This is usually in the user's home directory and differs
    # between Windows PowerShell and PowerShell core.
    $profileDirectory = Split-Path $PROFILE

    # Create the PowerShell profile directory if needed.
    if (-not (Test-Path $profileDirectory))
    {
        New-Item $profileDirectory -ItemType Directory | Out-Null
    }

    # Get the config data.
    $configContent = Get-Content $personalConfigFilePath -ErrorAction SilentlyContinue
    if ($configContent)
    {
        $config = $configContent | ConvertFrom-Json
    }
    else
    {
        # Fall back to the default config file.
        # Since the config file was just cloned, this is here to allow this
        # script to run with -WhatIf where Set-Content won't actually run.
        $config = Get-Content $defaultConfigFilePath | ConvertFrom-Json
    }

    # Initialize all configured profiles.
    $config.profiles | Select-Object -ExpandProperty name | ForEach-Object {
        [string] $profileName = $_

        $profileScriptName = $profileName + "_profile.ps1"

        # Create a personal profile stub if needed.
        $personalScriptStubPath = Join-Path $personalProfileDirectoryPath $profileScriptName
        if (-not (Test-Path $personalScriptStubPath))
        {
            New-Item $personalScriptStubPath -ItemType File | Out-Null
        }

        # Set up the content for profiles.
        $profileContent = @(
            "`$Global:PSProfile = '$profileName'"
            ". '$PSScriptRoot\Profile.ps1'"
        )

        # Set content of the PowerShell profile script.
        $profileScriptPath = Join-Path $profileDirectory $profileScriptName
        $profileContent | Set-Content $profileScriptPath -Force -ErrorAction Inquire
    }
}
