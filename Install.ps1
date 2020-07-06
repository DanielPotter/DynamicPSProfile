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
        Get-Content $configPath.TemplateFile | ForEach-Object {
            # Replace the schema reference for the personal config file
            # because it will be placed in a child directory.
            $_ -replace [regex]::Escape('"$schema": "./ProfileConfig.Schema.json"'), '"$schema": "../ProfileConfig.Schema.json"'
        } | Set-Content $configPath.ConfigFile -ErrorAction Inquire
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
    Get-ProfileInfo | ForEach-Object {
        $profileInfo = $_
        $profileName = $profileInfo.name

        # If needed, create the config script that will be executed before the profile config script.
        # Only create the script if at least one profile is configured to use it.
        if ($profileInfo.Config.usePreProfileConfigScript -and -not (Test-Path $configPath.PreProfileScript))
        {
            @(
                "# This script will be executed before the profile config script."
                "# Any functions or variables created in the script scope of this file"
                "# will be added to the global scope."
            ) | New-Item $configPath.PreProfileScript -ItemType File | Out-Null
        }

        # If needed, create the profile config script that Profile.ps1 will execute.
        # Only create the script if the profile is configured to use it.
        if ($profileInfo.Config.useProfileConfigScript -and -not (Test-Path $profileInfo.ScriptPath))
        {
            @(
                "# This profile config script will be executed while loading the $profileName profile."
                "# Any functions or variables created in script scope of this file"
                "# will be added to the global scope."
            ) | New-Item $profileInfo.ScriptPath -ItemType File | Out-Null
        }

        # If needed, create the config script that will be executed after the profile config script.
        # Only create the script if at least one profile is configured to use it.
        if ($profileInfo.Config.usePostProfileConfigScript -and -not (Test-Path $configPath.PostProfileScript))
        {
            @(
                "# This script will be executed after the profile config script."
                "# Any functions or variables created in the script scope of this file"
                "# will be added to the global scope."
            ) | New-Item $configPath.PostProfileScript -ItemType File | Out-Null
        }

        # Construct the name of the profile script using the same convention for existing profiles.
        # The name of the default profile is Microsoft.PowerShell_profile.ps1.
        $profileScriptName = $profileName + "_profile.ps1"

        # Set content of the PowerShell profile script.
        $profileScriptPath = Join-Path $profileDirectory $profileScriptName

        # Set the content of the script that will set up the profile.
        @(
            # Set the profile name so we can know which profile is currently active.
            "`$Global:PSProfile = '$profileName'"
            # Dot source our profile script.
            ". '$PSScriptRoot\Profile.ps1'"
        ) | Set-Content $profileScriptPath -Force -ErrorAction Inquire
    }
}
