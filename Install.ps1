[CmdletBinding(SupportsShouldProcess)]
param ()

process
{
    # Dot source common commands.
    . (Join-Path $PSScriptRoot Common.ps1)

    $configPath = Get-ProfileConfigPath

    # Create the Profiles directory if it doesn't already exist.
    if (-not (Test-Path $configPath.ConfigDirectory))
    {
        New-Item $configPath.ConfigDirectory -ItemType Directory | Out-Null
    }

    # Clone the default config if the personal config is empty.
    if (-not (Test-Path $configPath.ConfigFile) -or (Get-Item $configPath.ConfigFile).Length -eq 0)
    {
        Get-Content $configPath.DefaultFile | ForEach-Object {
            # Replace the schema reference for the personal config file
            # because it will be placed in a child directory.
            $_ -replace [regex]::Escape('"$schema": "./ProfileConfig.Schema.json"'), '"$schema": "../ProfileConfig.Schema.json"'
        } | Set-Content $configPath.ConfigFile -ErrorAction Inquire
    }

    # Create the script that will be sourced for all profiles.
    $allProfilesScriptPath = Join-Path $configPath.ConfigDirectory AllProfiles.ps1
    if (-not (Test-Path $allProfilesScriptPath))
    {
        New-Item $allProfilesScriptPath -ItemType File | Out-Null
    }

    # Grab the directory containing the PowerShell profile file.
    # This is usually in the user's home directory and differs
    # between Windows PowerShell and PowerShell core.
    $profileDirectory = Split-Path $PROFILE

    # Create the PowerShell profile directory if needed.
    if (-not (Test-Path $profileDirectory))
    {
        New-Item $profileDirectory -ItemType Directory | Out-Null
    }

    # Initialize all configured profiles.
    Get-ProfileConfig | ForEach-Object {
        [string] $profileName = $_.name

        # Construct the name of the script using the same convention for existing profiles.
        # The name of the default profile is Microsoft.PowerShell_profile.ps1.
        $profileScriptName = $profileName + "_profile.ps1"

        # Create a personal profile stub if needed.
        $personalScriptStubPath = Join-Path $configPath.ConfigDirectory $profileScriptName
        if (-not (Test-Path $personalScriptStubPath))
        {
            New-Item $personalScriptStubPath -ItemType File | Out-Null
        }

        # Generate the content for this profile.
        $profileContent = @(
            # Set the profile name so we can know which profile is currently active.
            "`$Global:PSProfile = '$profileName'"
            # Dot source our profile script.
            ". '$PSScriptRoot\Profile.ps1'"
        )

        # Set content of the PowerShell profile script.
        $profileScriptPath = Join-Path $profileDirectory $profileScriptName
        $profileContent | Set-Content $profileScriptPath -Force -ErrorAction Inquire
    }
}
