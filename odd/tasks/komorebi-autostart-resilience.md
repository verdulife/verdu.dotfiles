# Keep the session usable when komorebi fails to start at logon

Status: done - fixed, deployed and verified live; the logon path is confirmed at the next reboot
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
