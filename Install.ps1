[CmdletBinding(SupportsShouldProcess)]
param ()

begin
{
    $localProfilesPath = Join-Path $PSScriptRoot Profiles
    $configFilePath = Join-Path $localProfilesPath ProfileConfig.jsonc
    $defaultConfigFilePath = Join-Path $PSScriptRoot ProfileConfig.Default.jsonc

    function getProfileNames
    {
        $configContent = Get-Content $configFilePath -ErrorAction SilentlyContinue
        if ($configContent)
        {
            $config = $configContent | ConvertFrom-Json
        }
        else
        {
            $config = Get-Content $defaultConfigFilePath | ConvertFrom-Json
        }

        return $config.profiles | Select-Object -ExpandProperty name
    }
}

process
{
    # Install config files.
    if (-not (Test-Path $localProfilesPath))
    {
        New-Item $localProfilesPath -ItemType Directory | Out-Null
    }

    if (-not (Test-Path $configFilePath) -or -not (Get-Content $configFilePath))
    {
        Get-Content $defaultConfigFilePath | ForEach-Object {
            $_ -replace [regex]::Escape('"$schema": "./ProfileConfig.Schema.json"'), '"$schema": "../ProfileConfig.Schema.json"'
        } | Set-Content $configFilePath -ErrorAction Inquire
    }

    # Install profiles.
    $profileDirectory = Split-Path $profile
    if (-not (Test-Path $profileDirectory))
    {
        New-Item $profileDirectory -ItemType Directory -Force
    }

    $localScriptPath = Join-Path $localProfilesPath AllProfiles.ps1
    if (-not (Test-Path $localScriptPath))
    {
        New-Item $localScriptPath -ItemType File | Out-Null
    }

    getProfileNames | ForEach-Object {
        [string] $profileName = $_

        $profileContent = @(
            "`$Global:PSProfile = '$profileName'"
            ". '$PSScriptRoot\Profile.ps1'"
        )

        $profileScriptName = $profileName + "_profile.ps1"

        $localScriptPath = Join-Path $localProfilesPath $profileScriptName
        if (-not (Test-Path $localScriptPath))
        {
            New-Item $localScriptPath -ItemType File | Out-Null
        }

        $profileScriptPath = Join-Path $profileDirectory $profileScriptName
        $profileContent | Set-Content $profileScriptPath -Force -ErrorAction Inquire
    }
}
