# dotfiles — Windows rollback (interactive).
# Removes the files placed by setup.ps1 and the startup entry.
# Winget packages are NOT removed by default (uncomment the block below to do so).
$ErrorActionPreference = 'Stop'

Write-Host "Removing placed configuration files..."
$paths = @(
    "$HOME\komorebi.ahk",
    "$HOME\komorebi-autostart.ps1",
    "$HOME\.config\yasb\config.yaml",
    "$HOME\.config\yasb\styles.css",
    "$HOME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1",
    "$HOME\.config\powershell\user_profile.ps1",
    (Join-Path ([Environment]::GetFolderPath('Startup')) 'komorebi-autostart.vbs')
)
foreach ($p in $paths) {
    if (Test-Path $p) { Remove-Item $p -Force; Write-Host "  removed $p" }
}

Write-Host ""
Write-Host "Optional: uninstall the winget packages with:"
Write-Host "  winget uninstall -e --id LGUG2Z.komorebi"
Write-Host "  winget uninstall -e --id AutoHotkey.AutoHotkey"
Write-Host "  winget uninstall -e --id AmN.yasb"
Write-Host "  winget uninstall -e --id DEVCOM.JetBrainsMonoNerdFont"