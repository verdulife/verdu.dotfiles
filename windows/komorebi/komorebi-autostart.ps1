# Komorebi setup autostart - launched at logon, hidden window.
# Order: AHK + YASB FIRST (they do not depend on komorebi) -> drop an unsafe state dump
# (komorebi replays it at start, BYPASSING the ignore rules) -> komorebi WITH the static
# config (komorebi.json) -> wait until it answers -> masir (FFM daemon) -> verify,
# including any ignored-class container that still made it into the fresh state.
# Remove autostart by deleting komorebi-autostart.vbs (Startup folder) and this file.
#
# What lives where (the division of responsibility):
#   - komorebi.json is the single source of truth for CONFIGURATION: monitors +
#     workspaces, display_index_preferences (dual monitor), paddings, borders/colours,
#     resize_delta, mouse_follows_focus, ignore/manage rules and the Zen object-name-change
#     application. It is applied by komorebi itself via `--config`.
#   - THIS script is a RESILIENCE SUPERVISOR, for the things upstream does not solve: the
#     logon foreground lock (retry with backoff), the unsafe state dump, per-process guards
#     against Windows "restart apps" double launches, the YASB komorebi-subscription
#     guard, explicit ordering (AHK/YASB first, masir after komorebi), verification and
#     the log. It no longer re-applies the configuration one command at a time.
#
# Why the wait: on a fresh boot komorebi's IPC socket can take several seconds to
# come up. A blind `Start-Sleep 3` before the komorebic calls silently failed on
# busy logons (and after Windows 11 "restart apps" re-launched a bare komorebi),
# leaving komorebi on its defaults. This script stops any previous instance, starts
# komorebi with the static config, waits until the socket answers, then starts the
# masir FFM daemon, verifies what it applied, and writes
# $env:USERPROFILE\komorebi-autostart.log.
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
# the session got no WM until a manual relaunch. Round 2 (2026-10-06) retried ~240 s.
#
# ROUND 3 (2026-10-27): the blind window is NOT bounded by ForegroundLockTimeout, so
# "give up after N seconds" is the defect, not the number. Evidence from this machine:
#   - 2026-10-27 logon: 9 attempts 09:38:36 -> 09:41:52 (196 s), all failed; the same
#     script succeeded on its first attempt at 09:53:16, ~15 min after logon.
#   - 2026-10-23 logon: the same 9 attempts spanned 09:39:35 -> 09:44:44 (309 s) and
#     every one failed too, so widening the window is not a fix either.
#   - The value of ForegroundLockTimeout alone does not predict the outcome: measured
#     here, an armed 200000 ms lock did not always block a fresh process, and komorebi
#     has been seen starting with the lock armed. The gate also depends on which window
#     owns the foreground, which the launcher cannot control at logon.
# Conclusion: the launcher must keep trying until the gate opens, and record enough to
# diagnose the next bad logon. Two phases (burst then steady) below, and every failed
# attempt logs the gate triple (lock / idle / asfw). It still adopts any instance that
# already answers (Windows "restart apps" may have started one) instead of starting a
# second.

$ErrorActionPreference = 'SilentlyContinue'

$komorebic   = 'C:\Program Files\komorebi\bin\komorebic.exe'
$komorebi    = 'C:\Program Files\komorebi\bin\komorebi.exe'
$komorebiJson = "$env:USERPROFILE\komorebi.json"   # deployed by MANIFEST; the static config
$ahk         = "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe"
$ahkScript   = "$env:USERPROFILE\komorebi.ahk"
$yasb        = 'C:\Program Files\yasb\yasb.exe'
$log         = "$env:USERPROFILE\komorebi-autostart.log"
# komorebi writes its own logs to %TEMP% (komorebi.log.<date>), but a start that
# fails the foreground-window check never reaches the logger. These two files are
# our own redirects of the console output for exactly that case.
$komorebiOut = "$env:TEMP\komorebi.out"
$komorebiErr = "$env:TEMP\komorebi.err"
$masir       = 'C:\Program Files\masir\bin\masir.exe'   # FFM daemon (winget LGUG2Z.masir)
$masirOut    = "$env:TEMP\masir.out"
$masirErr    = "$env:TEMP\masir.err"
$containerDump = "$env:USERPROFILE\komorebi-container-dump.ps1"   # deployed alongside this script
$yasbSubscription = "$env:USERPROFILE\komorebi-yasb-subscription.ps1"   # deployed alongside this script
# Dot-sourced here, next to the other deployed paths: `komorebic stop` writes a state
# dump that komorebi replays at start BYPASSING the ignore rules, so a dump written while
# a child window was managed resurrects that container and the layout hole returns
# (README gotcha 19). This one file knows which dumps are unsafe; loading it before
# anything starts means no start can glide past a stale dump.
if (Test-Path $containerDump) { . $containerDump }
# Same guarded dot-source, same reason: a partially copied deployment must still leave a
# working logon. Loaded before anything starts, so the subscription check below can never
# be the reason a session has no window manager.
if (Test-Path $yasbSubscription) { . $yasbSubscription }

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
# This list mirrors `ignore_rules` in komorebi.json, which is what komorebi enforces; it is
# kept here because THREE places must agree: the state-dump sanitizer before the start, the
# post-start check that names anything that slipped in anyway, and the config itself.
$ignoredClasses = @("#32770", "TaskDialog", "MozillaDialogClass", "MozillaDropShadowWindowClass",
                    "ReunionWindowingCaptionControls", "InputNonClientPointerSource")

# Expected values for the verification below. They MIRROR komorebi.json, the single source
# of truth for configuration: if the static config failed to apply, these checks fail and
# the log says so. Keep them in sync with komorebi.json.
$expectedResizeDelta = 25
$expectedWorkspaces  = 5

function Write-Log([string]$msg) {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $msg" | Out-File -FilePath $log -Append -Encoding utf8
}

# --- Gate diagnostics for the log. komorebi's first action is AllowSetForegroundWindow
# --- on itself and it exits if that fails; whether it succeeds depends on Win32
# --- foreground state (which window owns the foreground, the foreground lock timeout,
# --- time since the last user input) that a background launcher cannot control. Three
# --- numbers per failed attempt are what turn the next bad logon into evidence instead
# --- of a mystery: the session lock timeout (SPI_GETFOREGROUNDLOCKTIMEOUT, 0x2000), the
# --- seconds since the last user input, and the same probe komorebi makes, issued for
# --- this process (not ASFW_ANY: a successful probe is also a grant, and a grant to this
# --- launcher would be the wrong, over-broad one).
# --- Guarded twice over (Add-Type and the function body): diagnostics must never be the
# --- reason a session has no window manager.
if (-not ('KomorebiGate' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class KomorebiGate {
    [DllImport("user32.dll", SetLastError = true)] public static extern bool AllowSetForegroundWindow(int pid);
    [DllImport("user32.dll", SetLastError = true)] public static extern bool SystemParametersInfo(uint action, uint param, out uint value, uint winini);
    [DllImport("user32.dll", SetLastError = true)] public static extern bool GetLastInputInfo(ref LastInputInfo info);
    [StructLayout(LayoutKind.Sequential)] public struct LastInputInfo { public uint cbSize; public uint dwTime; }
}
'@ -ErrorAction SilentlyContinue
}
function Get-GateDiagnostics {
    try {
        $lock = 0
        [void][KomorebiGate]::SystemParametersInfo(0x2000, 0, [ref]$lock, 0)
        $lastInput = New-Object KomorebiGate+LastInputInfo
        $lastInput.cbSize = 8
        [void][KomorebiGate]::GetLastInputInfo([ref]$lastInput)
        $idle = [int](([Environment]::TickCount - [int]$lastInput.dwTime) / 1000)
        $asfw = [bool][KomorebiGate]::AllowSetForegroundWindow($PID)
        return "lock=$lock idle=${idle}s asfw=$asfw"
    } catch {
        return 'gate diagnostics unavailable'
    }
}

# --- Hotkeys + status bar first, guarded per process. Deliberately NOT gated on
# --- komorebi: a window-manager failure must not also cost the hotkeys and the bar.
# --- CORRECTION 2026-10-20: this used to claim YASB's komorebi widget "reconnects by
# --- itself when komorebi appears", with a yasb.log line as proof. It does not, and that
# --- belief is exactly why two logins ran half the day with a dead widget:
# --- `komorebic subscribe` is fire-and-forget, so a subscription komorebi DROPS
# --- (contended state lock, 2026-10-20 21:20) or never receives (socket not up yet,
# --- 2026-10-18 10:09) still exits 0, and YASB then waits in ConnectNamedPipe forever.
# --- The subscription is verified and repaired once komorebi is ready (below, and in
# --- yasb-subscription.ps1); it is not left to YASB to notice.
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
# --- answers is ADOPTED rather than restarted (FFM is masir's job now, so an
# --- answering instance is fine regardless of komorebi's focus_follows_mouse). Without
# --- this every command below fails silently against a not-yet-ready socket (the bug
# --- this fixes).
# Phase 1 (burst): a normal logon settles inside a couple of minutes, so probe densely at
# first. Phase 2 (steady): keep trying every minute until the horizon, because the gate has
# been observed closed for ~15 min after logon (see header). Each doomed attempt costs a
# process that exits in milliseconds, so retrying for a long time is cheaper than a session
# with no window manager. The horizon is bounded so a genuinely broken install still ends
# with a visible [FAIL] instead of retrying forever.
$burstBackoff   = @(5, 10, 20, 30, 30, 30, 30, 30)   # phase 1: 9 attempts, ~240 s
$steadyInterval = 60                                  # phase 2: seconds between attempts
$horizonSeconds = 45 * 60                             # phase 1 + 2: give up after 45 min
$attempts = 0
$ready    = $false
$deadline = (Get-Date).AddSeconds($horizonSeconds)
while (-not $ready) {
    if ((Get-Date) -gt $deadline) { break }
    if ($attempts -gt 0) {
        $wait = if ($attempts -le $burstBackoff.Count) { $burstBackoff[$attempts - 1] } else { $steadyInterval }
        if ($wait -gt ($deadline - (Get-Date)).TotalSeconds) { break }
        Start-Sleep -Seconds $wait
    }
    $attempts++

    # Adopt an instance that already answers (e.g. launched by Windows "restart apps"
    # or by hand) instead of starting a second one.
    $adoptRaw = (& $komorebic state 2>$null) -join "`n"
    if ($adoptRaw) {
        $a = $null
        try { $a = $adoptRaw | ConvertFrom-Json } catch { }
        if ($null -ne $a) { $ready = $true; break }
        Write-Log "[warn] an instance is running but not answering; restarting it"
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

    # hidden console: komorebi.exe is a console app. Started WITHOUT --ffm (FFM is masir's
    # job) and WITH the static config, so komorebi applies its own configuration.
    Start-Process -FilePath $komorebi -ArgumentList '--config', $komorebiJson -WindowStyle Hidden `
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
        Write-Log "[warn] komorebi start attempt $attempts failed ($status): $why [$(Get-GateDiagnostics)]"
    }
}

if ($ready) {
    Write-Log '[ok] komorebi ready'

    # --- Focus-follows-mouse: the standalone masir daemon, NOT komorebi's built-in FFM.
    # --- komorebi's "Komorebi" FFM (--ffm + `focus-follows-mouse enable -i komorebi`) dies
    # --- permanently after a video fullscreen: Windows silently drops its low-level mouse
    # --- hook, and a toggle cannot reinstall it - verified 2026-10-11 on komorebi v0.1.41.
    # --- masir runs in its own process with its own hook and only focuses windows listed in
    # --- komorebi's managed-window file (%LOCALAPPDATA%\komorebi\komorebi.hwnd.json), so it
    # --- keeps the same "only managed windows" guarantee without sharing komorebi's lock.
    # --- masir must start AFTER komorebi so that file already exists (it reads it once at
    # --- startup). komorebi's mouse-follows-focus (cursor warp) is disabled in komorebi.json.
    if (-not (Get-Process masir -ErrorAction SilentlyContinue)) {
        Start-Process -FilePath $masir -WindowStyle Hidden `
            -RedirectStandardOutput $masirOut -RedirectStandardError $masirErr
    }

    # --- Verify what komorebi applied from the static config (fields readable from `state`) ---
    $state = (& $komorebic state 2>$null) -join "`n"
    $s = $null
    try { $s = $state | ConvertFrom-Json } catch { }
    $masirOk = $null -ne (Get-Process masir -ErrorAction SilentlyContinue)
    if ($s -and $s.resize_delta -eq $expectedResizeDelta -and -not $s.mouse_follows_focus) {
        $wsMonitors = @($s.monitors.elements).Count
        $wsPerMon   = @($s.monitors.elements | ForEach-Object { @($_.workspaces.elements).Count })
        $wsTotal    = ($wsPerMon | Measure-Object -Sum).Sum
        # Compare against the monitors komorebi actually reports, never against a fixed
        # list: that list is a superset of monitor indexes, so on a single-monitor machine
        # it warned "expected 2x5" at every logon. A log that always warns is a log nobody
        # reads, and this is the first log to read when the layout is missing.
        if ($wsTotal -eq ($wsMonitors * $expectedWorkspaces)) {
            Write-Log "[ok] config applied: resize_delta=$($s.resize_delta) mouse_follows_focus=$($s.mouse_follows_focus) masir=$masirOk workspaces=$($wsPerMon -join '/') monitors=$wsMonitors"
        } else {
            Write-Log "[WARN] workspaces unexpected: $($wsPerMon -join '/') (expected ${wsMonitors}x$expectedWorkspaces)"
        }
    } else {
        Write-Log "[FAIL] verification: resize_delta=$($s.resize_delta) mouse_follows_focus=$($s.mouse_follows_focus) masir=$masirOk"
    }

    # --- YASB's komorebi subscription: verify it, and repair it when it is missing. The
    # --- bar is started BEFORE komorebi on purpose (a WM failure must not cost the bar),
    # --- and this is the price of that ordering. Neither tool retries and neither logs at
    # --- the default level: komorebi drops an AddSubscriberPipe that arrives while its
    # --- state lock is busy and answers nothing, komorebic exits 0 anyway, and YASB then
    # --- blocks in ConnectNamedPipe with no timeout, so the widget just disappears
    # --- (hide_if_offline: true). Evidence and the full mechanism: yasb-subscription.ps1.
    if (Get-Process yasb -ErrorAction SilentlyContinue) {
        if (Get-Command Repair-YasbKomorebiSubscription -ErrorAction SilentlyContinue) {
            $sub = Repair-YasbKomorebiSubscription -Komorebic $komorebic -Path "$env:USERPROFILE\.config\yasb\yasb.log"
            if ($sub.Action -eq 'ok') {
                Write-Log "[ok] yasb subscription ok: $($sub.Pipe)"
            } elseif ($sub.Action -eq 'repaired') {
                Write-Log "[ok] yasb subscription repaired after $($sub.Attempts) attempt(s): $($sub.Pipe)"
            } elseif ($sub.Action -eq 'offline') {
                Write-Log "[FAIL] yasb workspaces widget offline: no komorebi subscription for $($sub.Pipe). Fix it by hand with: $($sub.Detail)"
            } else {
                Write-Log "[warn] yasb: $($sub.Detail); subscription not verified"
            }
        }
    } else {
        Write-Log '[warn] yasb is not running; its komorebi subscription was not verified'
    }

    # Whatever the config says, name every container whose class komorebi was told to
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
    Write-Log "[FAIL] komorebi not ready after $attempts attempts (~$([math]::Ceiling($horizonSeconds / 60)) min); config NOT applied (see $komorebiErr) [$(Get-GateDiagnostics)]"
}

# Report komorebi's outcome as the script's exit code, so a failure is still visible
# to whatever ran this script. The hotkeys and the bar were already started at the top.
if (-not $ready) { exit 1 }
