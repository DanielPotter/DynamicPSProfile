# Pepares the profile be generating scripts when needed.
[CmdletBinding(SupportsShouldProcess)]
param ()

process
{
    # Dot source common commands.
    . (Join-Path $PSScriptRoot Common.ps1)

    # Create the config files if necessary.
    Initialize-ProfileConfig
}
