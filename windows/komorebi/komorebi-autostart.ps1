# Komorebi setup autostart — launched at logon, hidden window.
# Order: komorebi (WM) -> layout preferences -> AHK hotkey script -> YASB bar.
# Remove autostart by deleting komorebi-autostart.vbs (Startup folder) and this file.

$ErrorActionPreference = 'SilentlyContinue'

$komorebic = 'C:\Program Files\komorebi\bin\komorebic.exe'
$ahk       = "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe"
$ahkScript = "$env:USERPROFILE\komorebi.ahk"
$yasb      = 'C:\Program Files\yasb\yasb.exe'
$masir     = 'C:\Program Files\masir\bin\masir.exe'   # focus-follows-mouse helper for komorebi

# Start the window manager
Start-Process -FilePath $komorebic -ArgumentList 'start'
Start-Sleep -Seconds 3

# --- Layout preferences (re-applied at every login) ---
$monitors      = 0, 1     # monitor indexes (zero-based): extend if more monitors
$workspaces    = 5        # workspaces per monitor (matches Win+1..5 bindings)
$workspacePadding = 4     # px: margin from the screen edge
$containerPadding = 0     # px: gap between adjacent tiles (each tile adds one side)
# Visible tile inset = workspacePadding + containerPadding + (borderWidth + borderOffset).
# The border grows INWARD, so its outer edge stays at workspacePadding + containerPadding (4px)
# and keeps lining up with the YASB bar's 4px box. Content inset with these values = 4 + 0 + (6 - 1) = 9px.
$borderWidth   = 6        # px: window border width (komorebi default is 8)
$borderOffset  = -1       # px: komorebi default; part of the inset formula above
$borderStyle   = 'rounded' # 'rounded' = Windows 11-style corners, 'square' = Win10, 'system' = OS default
$resizeStep    = 25       # px per resize key press

& $komorebic resize-delta $resizeStep | Out-Null
& $komorebic border-width $borderWidth | Out-Null
& $komorebic border-offset $borderOffset | Out-Null
& $komorebic border-style $borderStyle | Out-Null

# Border colours (RGB 0-255): focused = dark gray, unfocused = pure black (inverted look)
$borderFocusedRgb   = @(64, 64, 64)   # focused window: RENDERS as ~#2f2f2f (komorebi darkens borders ~27%)
$borderUnfocusedRgb = @(0, 0, 0)      # unfocused window (pure black)
foreach ($kind in 'single', 'stack', 'monocle', 'floating') {
    & $komorebic border-colour -w $kind $borderFocusedRgb[0] $borderFocusedRgb[1] $borderFocusedRgb[2] | Out-Null
}
foreach ($kind in 'unfocused', 'unfocused-locked') {
    & $komorebic border-colour -w $kind $borderUnfocusedRgb[0] $borderUnfocusedRgb[1] $borderUnfocusedRgb[2] | Out-Null
}

# Force-manage rules: komorebi does not auto-register some windows (documented rare case).
# Zen Browser windows need this, otherwise a reopened window stays untiled.
& $komorebic manage-rule exe zen.exe | Out-Null
foreach ($mon in $monitors) {
    & $komorebic ensure-workspaces $mon $workspaces | Out-Null
    foreach ($ws in 0..($workspaces - 1)) {
        & $komorebic container-padding $mon $ws $containerPadding | Out-Null
        & $komorebic workspace-padding  $mon $ws $workspacePadding | Out-Null
    }
}

# Focus-follows-mouse is implemented inside komorebi.ahk (masir is not used: its window
# raising has no effect here and it died from console Ctrl-C signals).
# komorebi's own mouse-follows-focus must stay disabled or it warps the cursor on every
# focus change and fights the pointer-driven focus.
& $komorebic mouse-follows-focus disable | Out-Null

# Hotkeys + status bar
Start-Process -FilePath $ahk -ArgumentList "`"$ahkScript`""
Start-Process -FilePath $yasb