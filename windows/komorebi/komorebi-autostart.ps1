# Komorebi setup autostart — launched at logon, hidden window.
# Order: komorebi (WM, with --ffm) -> wait until it answers -> layout + FFM -> verify -> AHK -> YASB.
# Remove autostart by deleting komorebi-autostart.vbs (Startup folder) and this file.
#
# Why the wait: on a fresh boot komorebi's IPC socket can take several seconds to
# come up. A blind `Start-Sleep 3` before the komorebic calls silently failed on
# busy logons (and after Windows 11 "restart apps" re-launched a bare komorebi),
# leaving komorebi on its defaults. This script now stops any previous instance,
# starts komorebi with --ffm (custom focus-follows-mouse), waits until the socket
# answers, verifies what it applied, and writes $env:USERPROFILE\komorebi-autostart.log.

$ErrorActionPreference = 'SilentlyContinue'

$komorebic = 'C:\Program Files\komorebi\bin\komorebic.exe'
$komorebi  = 'C:\Program Files\komorebi\bin\komorebi.exe'
$ahk       = "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe"
$ahkScript = "$env:USERPROFILE\komorebi.ahk"
$yasb      = 'C:\Program Files\yasb\yasb.exe'
$log       = "$env:USERPROFILE\komorebi-autostart.log"

function Write-Log([string]$msg) {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $msg" | Out-File -FilePath $log -Append -Encoding utf8
}

# Stop any previous komorebi (e.g. a bare instance relaunched by Windows
# "restart apps", which would run without --ffm and without our layout), then
# start it with --ffm so the custom focus-follows-mouse implementation is usable.
& $komorebic stop 2>$null | Out-Null
Start-Sleep -Seconds 1
Start-Process -FilePath $komorebi -ArgumentList '--ffm'
Start-Sleep -Seconds 2

# --- Wait until komorebi answers; without this every config command below
# --- fails silently against a not-yet-ready socket (the bug this fixes).
$ready = $false
foreach ($i in 1..40) {                      # up to ~20s
    $probe = & $komorebic state 2>$null
    if ($probe) { $ready = $true; break }
    Start-Sleep -Milliseconds 500
}
if (-not $ready) {
    Write-Log '[FAIL] komorebi did not become ready within 20s; layout NOT applied'
    exit 1
}
Write-Log '[ok] komorebi ready'

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
& $komorebic border-offset -- $borderOffset | Out-Null   # '--' so -1 is not parsed as a flag
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

# Focus-follows-mouse: komorebi's OWN custom implementation (requires --ffm above).
# It only focuses komorebi-managed windows, so context menus, the desktop and the
# taskbar are never touched - an AHK WinActivate timer used to break context menus
# by activating the menu's #32768 popup window, which is why FFM now lives here.
# komorebi's mouse-follows-focus (cursor warp on focus change) must stay disabled.
& $komorebic focus-follows-mouse enable -i komorebi | Out-Null
& $komorebic mouse-follows-focus disable | Out-Null

# --- Verify what we just applied (fields readable from `state`) ---
$state = (& $komorebic state 2>$null) -join "`n"
$s = $null
try { $s = $state | ConvertFrom-Json } catch { }
$ffmOk = $null -ne $s.focus_follows_mouse -and $s.focus_follows_mouse -ne $false
if ($s -and $s.resize_delta -eq $resizeStep -and -not $s.mouse_follows_focus -and $ffmOk) {
    $wsPerMon = @($s.monitors.elements | ForEach-Object { @($_.workspaces.elements).Count })
    $wsTotal  = ($wsPerMon | Measure-Object -Sum).Sum
    if ($wsTotal -eq ($monitors.Count * $workspaces)) {
        Write-Log "[ok] layout applied: resize_delta=$($s.resize_delta) mouse_follows_focus=$($s.mouse_follows_focus) ffm=$($s.focus_follows_mouse) workspaces=$($wsPerMon -join '/')"
    } else {
        Write-Log "[WARN] workspaces unexpected: $($wsPerMon -join '/') (expected $($monitors.Count)x$workspaces)"
    }
} else {
    Write-Log "[FAIL] verification: resize_delta=$($s.resize_delta) mouse_follows_focus=$($s.mouse_follows_focus) ffm=$($s.focus_follows_mouse)"
}

# Hotkeys + status bar (guarded: Windows may have re-launched them already via
# "restart apps after sign-in"; starting them again would double every process).
if (-not (Get-Process AutoHotkey64 -ErrorAction SilentlyContinue)) {
    Start-Process -FilePath $ahk -ArgumentList "`"$ahkScript`""
}
if (-not (Get-Process yasb -ErrorAction SilentlyContinue)) {
    Start-Process -FilePath $yasb
}