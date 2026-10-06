# Komorebi setup autostart - launched at logon, hidden window.
# Order: AHK + YASB FIRST (they do not depend on komorebi) -> komorebi (WM, with --ffm)
# -> wait until it answers -> layout + FFM -> verify.
# Remove autostart by deleting komorebi-autostart.vbs (Startup folder) and this file.
#
# Why the wait: on a fresh boot komorebi's IPC socket can take several seconds to
# come up. A blind `Start-Sleep 3` before the komorebic calls silently failed on
# busy logons (and after Windows 11 "restart apps" re-launched a bare komorebi),
# leaving komorebi on its defaults. This script stops any previous instance, starts
# komorebi with --ffm (custom focus-follows-mouse), waits until the socket answers,
# verifies what it applied, and writes $env:USERPROFILE\komorebi-autostart.log.
#
# Why the long retry horizon (2026-10-06): AllowSetForegroundWindow only succeeds when
# the caller may already set the foreground window. At logon none of the conditions
# hold - the foreground right belongs to the shell, the process did not receive the
# last input event, and the foreground lock re-arms for ForegroundLockTimeout
# (default 200000 ms) after the last input - so the call fails until the lock expires
# or the user generates input (~200 s, whichever comes first). komorebi's OWN retry
# loop (5 attempts, added upstream in 46d5ea4 for exactly this) has no delay between
# attempts and bails in ~0 s, so the horizon must live outside the binary. Round 1
# (2026-10-05) retried 3 times in ~10 s, which stayed entirely inside the blind
# window: at the 2026-10-06 logon komorebi died at 10:01:54 / 10:01:57 / 10:02:00 and
# the session got no WM until a manual relaunch. This round retries for ~240 s with
# backoff, and adopts any instance that already answers (Windows "restart apps" may
# have started one) instead of blindly starting a second.

$ErrorActionPreference = 'SilentlyContinue'

$komorebic   = 'C:\Program Files\komorebi\bin\komorebic.exe'
$komorebi    = 'C:\Program Files\komorebi\bin\komorebi.exe'
$ahk         = "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe"
$ahkScript   = "$env:USERPROFILE\komorebi.ahk"
$yasb        = 'C:\Program Files\yasb\yasb.exe'
$log         = "$env:USERPROFILE\komorebi-autostart.log"
# komorebi writes its own logs to %TEMP% (komorebi.log.<date>), but a start that
# fails the foreground-window check never reaches the logger. These two files are
# our own redirects of the console output for exactly that case.
$komorebiOut = "$env:TEMP\komorebi.out"
$komorebiErr = "$env:TEMP\komorebi.err"

function Write-Log([string]$msg) {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $msg" | Out-File -FilePath $log -Append -Encoding utf8
}

# --- Hotkeys + status bar first, guarded per process. Deliberately NOT gated on
# --- komorebi: a window-manager failure must not also cost the hotkeys and the bar,
# --- and YASB's komorebi widget reconnects by itself when komorebi appears (yasb.log:
# --- pipe subscribe failed at sign-in, connected the moment komorebi answered).
# --- Guarded per process because Windows may have re-launched them already via
# --- "restart apps after sign-in"; starting them twice would double them.
if (-not (Get-Process AutoHotkey64 -ErrorAction SilentlyContinue)) {
    Start-Process -FilePath $ahk -ArgumentList "`"$ahkScript`""
}
if (-not (Get-Process yasb -ErrorAction SilentlyContinue)) {
    Start-Process -FilePath $yasb
}

# --- Start komorebi and wait until it answers, retrying with backoff. The gate that
# --- blocks the start is the Win32 foreground lock (see header): it opens on user
# --- input or after ~200 s, which is why the horizon is ~4 min and no longer ~10 s.
# --- "not answering yet" (socket still starting) and "already dead" (the
# --- AllowSetForegroundWindow bail) are told apart, and an instance that already
# --- answers is ADOPTED rather than restarted - unless it lacks --ffm, in which case
# --- it is stopped and started again with --ffm. Without this every config command
# --- below fails silently against a not-yet-ready socket (the bug this fixes).
$attempts = 9
$backoff  = @(5, 10, 20, 30, 30, 30, 30, 30)   # s between attempts (attempt n waits backoff[n-1]); horizon ~240 s
$ready    = $false
for ($attempt = 1; $attempt -le $attempts -and -not $ready; $attempt++) {
    if ($attempt -gt 1) { Start-Sleep -Seconds $backoff[$attempt - 2] }

    # Adopt an instance that already answers (e.g. launched by Windows "restart apps"
    # or by hand) instead of starting a second one.
    $adoptRaw = (& $komorebic state 2>$null) -join "`n"
    if ($adoptRaw) {
        $a = $null
        try { $a = $adoptRaw | ConvertFrom-Json } catch { }
        $ffmOn = $null -ne $a.focus_follows_mouse -and $a.focus_follows_mouse -ne $false
        if ($ffmOn) { $ready = $true; break }
        Write-Log "[warn] an instance is running without --ffm; restarting it with --ffm"
    }

    # Clean slate for our own start: stop any instance and kill a lingering one.
    & $komorebic stop 2>$null | Out-Null
    Get-Process komorebi -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 500

    # hidden console: komorebi.exe is a console app
    Start-Process -FilePath $komorebi -ArgumentList '--ffm' -WindowStyle Hidden `
        -RedirectStandardOutput $komorebiOut -RedirectStandardError $komorebiErr

    foreach ($i in 1..12) {                      # up to ~6 s per attempt
        Start-Sleep -Milliseconds 500
        if (& $komorebic state 2>$null) { $ready = $true; break }
        if (-not (Get-Process komorebi -ErrorAction SilentlyContinue)) { break }
    }

    if (-not $ready) {
        $alive  = [bool](Get-Process komorebi -ErrorAction SilentlyContinue)
        $status = if ($alive) { 'still running but not answering' } else { 'process exited' }
        $why    = (Get-Content $komorebiErr -Raw -ErrorAction SilentlyContinue)
        $why    = if ($why) { ($why -replace '\s+', ' ').Trim() } else { 'no stderr output' }
        if ($why.Length -gt 200) { $why = $why.Substring(0, 200) + '...' }
        Write-Log "[warn] komorebi start attempt $attempt/$attempts failed ($status): $why"
    }
}

if ($ready) {
    Write-Log '[ok] komorebi ready'

    # --- Layout preferences (re-applied at every login) ---
    $monitors      = 0, 1     # monitor indexes (zero-based); a superset is fine (a nonexistent index fails silently) - the check below uses the monitors komorebi reports
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

    # Floating rules (ignore-rule = the window is left unmanaged, floating above tiles):
    # - class #32770 = standard Windows common dialog (Save As / Open / Explorer copy)
    # - class TaskDialog = modern Windows task dialog
    # - class MozillaDialogClass = Zen/Firefox dialog windows (main window is MozillaWindowClass)
    # - class ReunionWindowingCaptionControls / InputNonClientPointerSource = Zen/Firefox
    #   CHILD windows (WS_CHILD of the main window): the caption-button layer and the
    #   non-client input sink. Tiling a child window steals a slot that nothing can paint
    #   into, so the workspace shows a large empty area: on 2026-10-05 the caption child
    #   held the whole left half of workspace 2 while Ferdium and Zen were squeezed into
    #   the right half. Signature of this whole family: GetAncestor(hwnd, GA_ROOT) != hwnd.
    # Matching by exe would float the app's MAIN window too, so dialogs are matched by class.
    # Discover new dialog classes with windows/komorebi/spy-dialog.ps1 (repo-only tool).
    foreach ($rule in @("#32770", "TaskDialog", "MozillaDialogClass", "MozillaDropShadowWindowClass",
                        "ReunionWindowingCaptionControls", "InputNonClientPointerSource")) {
        & $komorebic ignore-rule class $rule | Out-Null
    }
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
        $wsMonitors = @($s.monitors.elements).Count
        $wsPerMon   = @($s.monitors.elements | ForEach-Object { @($_.workspaces.elements).Count })
        $wsTotal    = ($wsPerMon | Measure-Object -Sum).Sum
        # Compare against the monitors komorebi actually reports, never against the
        # $monitors list above: that list is a superset of monitor indexes, so on a
        # single-monitor machine it warned "expected 2x5" at every logon. A log that
        # always warns is a log nobody reads, and this is the first log to read when
        # the layout is missing.
        if ($wsTotal -eq ($wsMonitors * $workspaces)) {
            Write-Log "[ok] layout applied: resize_delta=$($s.resize_delta) mouse_follows_focus=$($s.mouse_follows_focus) ffm=$($s.focus_follows_mouse) workspaces=$($wsPerMon -join '/') monitors=$wsMonitors"
        } else {
            Write-Log "[WARN] workspaces unexpected: $($wsPerMon -join '/') (expected ${wsMonitors}x$workspaces)"
        }
    } else {
        Write-Log "[FAIL] verification: resize_delta=$($s.resize_delta) mouse_follows_focus=$($s.mouse_follows_focus) ffm=$($s.focus_follows_mouse)"
    }
} else {
    Write-Log "[FAIL] komorebi not ready after $attempts attempts (~240 s); layout NOT applied (see $komorebiErr)"
}

# Report komorebi's outcome as the script's exit code, so a failure is still visible
# to whatever ran this script. The hotkeys and the bar were already started at the top.
if (-not $ready) { exit 1 }