# dotfiles — Windows bootstrap (idempotent: safe to re-run).
# Installs the winget packages and places the configuration files where the
# Windows tooling expects them. Run from the repo root:
#   powershell -ExecutionPolicy Bypass -File windows\install\setup.ps1
$ErrorActionPreference = 'Stop'

$Dot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)   # repo root (dotfiles/)

function Install-WinGet($id) {
    Write-Host "  installing $id ..."
    winget install -e --id $id --accept-package-agreements --accept-source-agreements --silent
    if ($LASTEXITCODE -ne 0) { Write-Warning "winget failed for $id (exit $LASTEXITCODE)" }
}

Write-Host "== 1) Packages (winget) =="
Install-WinGet 'LGUG2Z.komorebi'          # tiling window manager
Install-WinGet 'AutoHotkey.AutoHotkey'    # v2: hotkeys + FFm + taskbar handling
Install-WinGet 'AmN.yasb'                 # status bar
Install-WinGet 'DEVCOM.JetBrainsMonoNerdFont'  # icon font (family name: "JetBrainsMono NF")

Write-Host "== 2) Configuration files =="
$homeFiles = @(
    @{ Src = "$Dot\windows\komorebi\komorebi.ahk";                 Dst = "$HOME\komorebi.ahk" },
    @{ Src = "$Dot\windows\komorebi\komorebi-autostart.ps1";       Dst = "$HOME\komorebi-autostart.ps1" },
    @{ Src = "$Dot\windows\yasb\config.yaml";                      Dst = "$HOME\.config\yasb\config.yaml" },
    @{ Src = "$Dot\windows\yasb\styles.css";                       Dst = "$HOME\.config\yasb\styles.css" },
    @{ Src = "$Dot\windows\powershell\Microsoft.PowerShell_profile.ps1"; Dst = "$HOME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1" },
    @{ Src = "$Dot\windows\powershell\user_profile.ps1";           Dst = "$HOME\.config\powershell\user_profile.ps1" }
)
foreach ($f in $homeFiles) {
    New-Item -ItemType Directory -Force -Path (Split-Path $f.Dst) | Out-Null
    Copy-Item $f.Src $f.Dst -Force
    Write-Host "  -> $($f.Dst)"
}

Write-Host "== 3) Startup folder (logon autostart) =="
$startup = [Environment]::GetFolderPath('Startup')
Copy-Item "$Dot\windows\autostart\komorebi-autostart.vbs" (Join-Path $startup 'komorebi-autostart.vbs') -Force
Write-Host "  -> $startup\komorebi-autostart.vbs"

Write-Host ""
Write-Host "Done. To activate on this machine:"
Write-Host "  1) Make sure PATH sees komorebic (new terminal / logon)."
Write-Host "  2) Log on (or run $HOME\komorebi-autostart.ps1 once) - it starts komorebi,"
Write-Host "     applies workspace/layout/border settings, launches AHK (hotkeys + FFm +")
Write-Host "     hidden taskbar), then YASB."
Write-Host "  3) See README.md -> 'Verification' for health checks."