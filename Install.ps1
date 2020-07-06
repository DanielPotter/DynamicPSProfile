# Installs the profile to the default profile location.
# This will overwrite the default profile specified by the bulit-in PowerShell $PROFILE variable.
[CmdletBinding(SupportsShouldProcess)]
param ()

process
{
    # Dot source common commands.
    . (Join-Path $PSScriptRoot Common.ps1)

    # Create the config files if necessary.
    Initialize-ProfileConfig

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

        Write-Verbose "Initializing the '$profileName' profile script."

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
