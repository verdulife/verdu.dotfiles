# Keep the session usable when komorebi fails to start at logon

Status: REOPENED 2026-10-06 - Round 1 (failure handling) is done and verified; Round 2
fixes the residual failure: the retry window was so short it stayed inside the
~200 s foreground-lock blind window, so the 2026-10-06 logon got no WM at all.
Repo: `C:\Users\verdu\verdu.dotfiles`, branch `chore/apply-dotfiles-port`
Date: 2026-10-05
Related: `odd/tasks/apply-dotfiles.md` (the port that introduced this autostart)

## Goal

At logon, a failure of `komorebi.exe` must not leave the session without hotkeys
and status bar, and the failure must be diagnosable from the autostart log alone.

## Non-goals

- No change to the layout values, the AHK bindings or the YASB config.
- No komorebi upgrade or patch: the fatal call is in the vendor binary (see Facts).
- No new autostart mechanism: the Startup `.vbs` stays as the single entry point.

## Facts (verified 2026-10-05)

| Fact | Evidence |
|---|---|
| Reboot at 17:34:27; logon chain ran ~17:40:23 | `Win32_OperatingSystem.LastBootUpTime`; autostart log entry 17:40:46 |
| `komorebi.exe` died within milliseconds | `%TEMP%\komorebi.err` from a manual run: `Error: failed call to AllowSetForegroundWindow after 5 retries` / `Location: komorebi\src\main.rs:219:13` |
| A failed start writes nothing to komorebi's own log | In `komorebi/src/main.rs` the retry loop runs **before** `setup(opts.log_level)`, so no subscriber exists yet. On disk: `komorebi.log.2026-10-05` ends 17:33:03 (last activity before the reboot) |
| Not a crash | No `Application` error event and no `CrashDumps` entry for komorebi; `bail!` is a clean exit |
| The 5 retries are effectively one attempt | Source (`v0.1.41` **and** `master`): the `while` loop has no sleep/backoff between `allow_set_foreground_window` attempts, then `bail!` |
| No upstream fix to wait for | `master/komorebi/src/main.rs` still has the identical loop, the `bail!` and the loop before `setup()` |
| The failure is transient and a retry works | Autostart log: `13:27:31 FAIL`, `13:28:29 FAIL`, `13:30:41 [ok] komorebi ready` |
| The real defect is the failure handling | In the old script `exit 1` was reached before the AutoHotkey and YASB launches, so neither started on the 17:40 logon |
| Redirection is available | `Start-Process -WindowStyle Hidden` + `-RedirectStandardOutput/-RedirectStandardError` works in Windows PowerShell 5.1 (tested); with redirection PS 5.1 does not return the exit code, so failure detection must use "process gone" + stderr content |

## Tasks

| # | Task | Status |
|---|---|---|
| 1 | Record the diagnosis and the evidence chain | done |
| 2 | Rewrite the komorebi start as bounded retries that detect "the process died" | done - 3 attempts, ~6 s probe each, "process exited" told apart from "not answering yet" |
| 3 | Start AutoHotkey and YASB regardless of komorebi's readiness; keep the exit code informative | done - both launches moved out of the guarded block; `exit 1` only at the very end |
| 4 | Capture komorebi's stderr and echo it into the autostart log | done - `%TEMP%\komorebi.out` / `%TEMP%\komorebi.err`, reason trimmed into the log line |
| 5 | Copy the script to `%USERPROFILE%` (MANIFEST destination) and run it live | done - byte-identical copy, syntax-checked, live run succeeded on the first attempt |
| 6 | Update README gotcha 17 with the verified mechanism and the no-upstream-fix note | done - gotcha 17 rewritten; gotcha 8 and the health-check block aligned with the new behavior |
| 7 | Commit the work unit on `chore/apply-dotfiles-port` | done - see the work-unit commit on this branch |
| 8 | Close: record the outcome; the logon path is proven at the next reboot (user action) | done - live run recorded below; reboot pending |

## Live run (2026-10-05 19:24)

```
komorebi-autostart.ps1 -> exit code 0
  19:24:29 [ok] komorebi ready                              (first attempt, no retry needed)
  19:24:30 [WARN] workspaces unexpected: 5 (expected 2x5)   (known single-monitor false alarm, gotcha 18)
processes: komorebi 22356, yasb 22236, AutoHotkey64 21620
komorebic state: resize_delta=25, mouse_follows_focus=False, ffm=Komorebi, workspaces=5
%TEMP%\komorebi.err: empty
```

The failure path cannot be triggered on demand, because the failure is transient by
nature. What is verified is the structure (the AHK/YASB launches are no longer after
an early `exit`) and the syntax (`[Parser]::ParseFile` on both copies). The real proof
is the next reboot: the log must either show `[ok] komorebi ready` on the first attempt
or `[warn] komorebi start attempt n/3 failed (...)` followed by success, and it must
never end with hotkeys and bar unstarted.

## Follow-up: the workspace-count false alarm (2026-10-05 19:34)

The verification compared `state.monitors` against the hardcoded `$monitors` index
list, so this single-monitor machine logged `[WARN] workspaces unexpected: 5
(expected 2x5)` at every logon (README gotcha 18). The check now compares against the
monitors komorebi actually reports, and the `[ok]` line records them. `$monitors` stays
a superset on purpose: configuring an index that does not exist fails silently, while
the verification must describe reality.

Live run after the change, exit 0:

```
19:34:05 [ok] komorebi ready
19:34:06 [ok] layout applied: resize_delta=25 mouse_follows_focus=False ffm=Komorebi workspaces=5 monitors=1
```

No `[WARN]` line, and the delta from the previous run is what matters: `19:24:30
[WARN] workspaces unexpected: 5 (expected 2x5)` is gone. README gotcha 10
(focus-follows-mouse) was also moved to its numeric position, where it belongs.

## Verification

- Immediate: run the script from a terminal and check that (a) komorebi answers, or
  that retries are logged with the stderr reason, and (b) AutoHotkey and YASB are
  running even in the failure case.
- Real proof: the next reboot. `%USERPROFILE%\komorebi-autostart.log` must show
  either `[ok] komorebi ready` on the first attempt or a `[warn] … attempt 2/3`
  followed by success — and no path that leaves AHK/YASB unstarted.

## Rollback

`git revert` the work-unit commit, or restore the previous script from it and
re-copy it to `%USERPROFILE%\komorebi-autostart.ps1`.

## Round 2: the logon race is a ~200 s blind window (2026-10-06)

Round 1 made the failure *diagnosable* but did not *recover* from it: 3 attempts in
~10 s all land inside the same blind window. The 2026-10-06 logon proved it - the
log shows the failure cleanly, and the session still had no WM until a manual run.

### Symptom (2026-10-06, reported by the user)

- Boot 09:59:49; komorebi start attempts 10:01:54 / 10:01:57 / 10:02:00, all
  `process exited` with the stderr reason below; script gave up at 10:02:00.
- No tiling at all; YASB showed no workspaces widget. The user guessed YASB started
  before komorebi - it did not: YASB's komorebi listener reconnects by itself when
  komorebi appears (yasb.log 10:02:05 subscribe failed -> 10:53:47 connected, no
  restart). The widget simply hides while offline (`hide_if_offline: true`, kept by
  user decision on 2026-10-06), which made the outage look like "widget did not
  load".

### Mechanism (verified against source and Microsoft docs)

- `AllowSetForegroundWindow` fails unless the caller may already set the foreground
  window. Microsoft's conditions: the caller is the foreground process, was started
  by it, received the last input event, is being debugged, there is no foreground
  window, **or the foreground lock timeout has expired**
  (`SPI_GETFOREGROUNDLOCKTIMEOUT` / `HKCU\Control Panel\Desktop\ForegroundLockTimeout`,
  default `200000` ms).
- At logon, the startup chain (`wscript.exe` -> `powershell.exe` -> `komorebi.exe`,
  10:01:54, ~2 min after boot) satisfies none of them: the foreground right belongs
  to the shell and the lock re-armed with the logon input, so the gate only opens on
  fresh user input or after ~200 s. This is why the same binary always succeeds on a
  manual run minutes later.
- Upstream added retries for exactly this (`46d5ea4`, "The startup Win32 API call can
  sporadically fail"), but the loop has **no delay between attempts** - verified in
  `master` `komorebi/src/main.rs:203-221` on 2026-10-06, still identical to v0.1.41 -
  so it bails after ~0 s. Issue #683 ("Auto Start is very unstable") stays open.
  Native autostart (`komorebic enable-autostart`, `.lnk` in `shell:startup`) and a
  static `komorebi.json` do not change the timing and hit the same race.

### Tasks (Round 2)

| # | Task | Status |
|---|---|---|
| 1 | Record the 2026-10-06 failure and the lock mechanism | done |
| 2 | Start AHK + YASB before komorebi (guarded per process), so nothing waits on the WM | done |
| 3 | Replace the 3-attempt loop with 9 attempts and backoff (5/10/20/30/30/30/30/30 s, horizon ~240 s, covering the ~200 s lock) | done |
| 4 | Adopt an instance that already answers (`komorebic state` probe per attempt) instead of starting a second; restart it only if it lacks `--ffm` | done |
| 5 | Copy to `%USERPROFILE%` (MANIFEST destination), syntax-check both copies, live run | done - byte-identical copy, `[ok] layout applied` on the first attempt |
| 6 | Update README gotchas 8 and 17 | done |
| 7 | Commit the work unit on `fix/komorebi-logon-retry-horizon` | done - see the work-unit commit on this branch |
| 8 | Close: the reboot test (user action) - expect `[ok] komorebi ready` or `[warn] … attempt n/9` followed by success within ~4 min | pending - reboot is the user's call |

### Live run before reboot (2026-10-06 10:53+, after the user-approved restore)

```
komorebi-autostart.ps1 -> exit code 0
  [ok] komorebi ready
  [ok] layout applied: resize_delta=25 mouse_follows_focus=False ffm=Komorebi workspaces=5 monitors=1
procs: komorebi, yasb, AutoHotkey64 (no duplicates)
yasb.log: connected to named pipe at the moment komorebi answered (no YASB restart)
```

Note for whoever hits the failure path next: the `[warn] … attempt n/9` lines now
span up to ~240 s of logon, and AHK/YASB are already up by then (they start before
the loop). The reboot is the only real proof of the failure path.
