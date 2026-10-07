# Komorebi setup autostart - launched at logon, hidden window.
# Order: AHK + YASB FIRST (they do not depend on komorebi) -> drop an unsafe state dump
# (komorebi replays it at start, BYPASSING the ignore rules) -> komorebi (WM, with --ffm)
# -> wait until it answers -> layout + FFM -> verify, including any ignored-class
# container that still made it into the fresh state.
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
$containerDump = "$env:USERPROFILE\komorebi-container-dump.ps1"   # deployed alongside this script
# Dot-sourced here, next to the other deployed paths: `komorebic stop` writes a state
# dump that komorebi replays at start BYPASSING the ignore rules, so a dump written while
# a child window was managed resurrects that container and the layout hole returns
# (README gotcha 19). This one file knows which dumps are unsafe; loading it before
# anything starts means no start can glide past a stale dump.
if (Test-Path $containerDump) { . $containerDump }

# Windows komorebi must never manage. Matching is by CLASS, never by exe - matching by exe
# would also float the app's MAIN window. #32770 = standard Windows common dialog (Save As /
# Open / Explorer copy), TaskDialog = modern Windows task dialog, Mozilla* = Zen/Firefox
# dialogs and window shadows, ReunionWindowingCaptionControls / InputNonClientPointerSource
# = Zen/Firefox CHILD windows (WS_CHILD of the main window): the caption-button layer and
# the non-client input sink. Tiling a child window steals a slot that nothing can paint
# into, so the workspace shows a large empty area: on 2026-10-05 the caption child held the
# whole left half of workspace 2 while Ferdium and Zen were squeezed into the right half.
# Signature of the whole family: GetAncestor(hwnd, GA_ROOT) != hwnd. Discover new classes
# with windows/komorebi/spy-dialog.ps1 (repo-only tool).
# One list, because three places must agree: the `ignore-rule class` calls below, the
# state-dump sanitizer before the start, and the post-start check that names anything that
# slipped in anyway.
$ignoredClasses = @("#32770", "TaskDialog", "MozillaDialogClass", "MozillaDropShadowWindowClass",
                    "ReunionWindowingCaptionControls", "InputNonClientPointerSource")

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

    # Sanitize the state dump between the stop above and the start below: `komorebic stop`
    # just wrote it, and komorebi replays it at start BYPASSING the ignore rules, so an
    # unsafe dump brings the wrongly-managed containers straight back (README gotcha 19).
    # Both known paths are checked - %TEMP% today, %LOCALAPPDATA%\komorebi\ if a future
    # release moves it - so a location change cannot silently reintroduce the bug. Nothing
    # is logged when the file is simply absent: this runs on every start attempt and one
    # line per attempt would be noise.
    if (Get-Command Remove-UnsafeContainerDump -ErrorAction SilentlyContinue) {
        foreach ($dumpPath in @("$env:TEMP\komorebi.state.json", "$env:LOCALAPPDATA\komorebi\komorebi.state.json")) {
            $dumpVerdict = Remove-UnsafeContainerDump -Path $dumpPath -IgnoredClasses $ignoredClasses
            if (-not $dumpVerdict.Exists) { continue }
            if ($dumpVerdict.Safe) {
                Write-Log "[ok] state dump clean: $dumpPath"
            } else {
                Write-Log "[warn] removed unsafe state dump ($($dumpVerdict.Reasons -join ', ')): $dumpPath"
            }
        }
    }

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

    # Zen is Gecko-based: it emits EVENT_OBJECT_NAMECHANGE on launch and never a Show
    # event, so komorebi never registers a cold-started window and it stays untiled. The
    # supported fix is to teach komorebi to treat this exe's name change as a window
    # identity event. The old `manage-rule exe zen.exe` force-managed whatever window was
    # focused and IGNORED the ignore rules, which is how Zen's WS_CHILD helper windows got
    # tiled (and why the AHK rescue existed as a workaround).
    & $komorebic identify-object-name-change-application exe zen.exe | Out-Null

    # Floating rules (ignore-rule = the window is left unmanaged, floating above tiles).
    # The class list and the rationale for every entry live in $ignoredClasses at the top,
    # because the dump sanitizer and the post-start check share that one list.
    foreach ($rule in $ignoredClasses) {
        & $komorebic ignore-rule class $rule | Out-Null
    }

    # Managed override (manage-rule = managed_override in komorebi's window_is_eligible).
    # It is the ONLY way past that gate, whose core test is
    #   (WS_CAPTION && WS_EX_WINDOWEDGE) && !WS_EX_DLGMODALFRAME && !WS_EX_LAYERED:
    # CorelDRAW paints its own title bar, so its frame carries WS_THICKFRAME | WS_SYSMENU
    # | WS_MINIMIZEBOX | WS_MAXIMIZEBOX and NO WS_CAPTION. Every event for it is dropped
    # at the top of process_event, so it is never tiled, nothing appears in the log at the
    # default info level, and even `komorebic manage` on the focused window is refused
    # (measured 2026-10-07: St=0x170f0000, Ex=0x00040100; every window komorebi does
    # manage, e.g. VersaWorks/WindowsTerminal/Zen, has WS_CAPTION=True).
    # By CLASS, never by exe: CorelDRW.exe also owns layered `Dial Wheel` popups, ComboLBox,
    # IME, DDE and `Afx:...:0` helper frames, and the override bypasses the layered test
    # too, so an exe-wide rule would tile that junk - the same mistake as the retired
    # `manage-rule exe zen.exe`. Legacy matching is starts_with/ends_with, so `CorelDRAW`
    # covers `CorelDRAW25` and survives the next version bump.
    & $komorebic manage-rule class CorelDRAW | Out-Null

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

    # Whatever the layout pass says, name every container whose class komorebi was told to
    # ignore: that is the signature of a restored stale dump or of a forced manage landing
    # on a child window, and this line is the only thing that tells the next session whether
    # the fix actually held. Exit codes stay as they were - this is diagnostics, not policy.
    # Guarded, because a partially copied deployment must still leave a working logon: the
    # dot-source at the top is conditional, so this function may not exist at all.
    if (Get-Command Get-IgnoredClassViolation -ErrorAction SilentlyContinue) {
        foreach ($violation in @(Get-IgnoredClassViolation -State $s -IgnoredClasses $ignoredClasses)) {
            Write-Log "[WARN] ignored-class container present: class=$($violation.class) hwnd=$($violation.hwnd) ws=$($violation.Workspace)"
        }
    }
} else {
    Write-Log "[FAIL] komorebi not ready after $attempts attempts (~240 s); layout NOT applied (see $komorebiErr)"
}

# Report komorebi's outcome as the script's exit code, so a failure is still visible
# to whatever ran this script. The hotkeys and the bar were already started at the top.
if (-not $ready) { exit 1 }