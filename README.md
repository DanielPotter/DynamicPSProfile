# Dynamic PowerShell Profile

A PowerShell profile template for multiple profiles.

## Using the profiles

Run `Install.ps1` to generate the config file. Customize the profiles in `Profiles\ProfileConfig.jsonc`. `Install.ps1` must run any time new profiles are added.

To use a profile, simply start PowerShell and dot source one of the generated profile scripts. It is best to start PowerShell without the default profile to avoid running the profile twice. This can be done using the `-NoProfile` argument.

## Windows Terminal

Windows Terminal makes it easy to use custom PowerShell profiles. Simply add a new Terminal profile with the following command line.

```batch
pwsh.exe -NoExit -NoProfile -Command "& { . (Join-Path (Split-Path $PROFILE) Terminal.Custom_profile.ps1) }"
```

Note: The same arguments may be used with `powershell.exe`.
