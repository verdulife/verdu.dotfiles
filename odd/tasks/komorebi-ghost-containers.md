# Stop komorebi from tiling Windows that are not user windows

Status: COMPLETE 2026-10-06 - root cause A fixed and measured; root cause B is upstream and open (#1730)
Repo: `C:\Users\verdu\verdu.dotfiles`, branch `fix/komorebi-logon-retry-horizon`
Machine: work PC (single monitor 1680x1050, komorebi 0.1.41 commit `24c0ce0b`)
Related: `odd/tasks/komorebi-child-window-tiling.md` (REOPENED, this closes its root cause),
`odd/tasks/komorebi-autostart-resilience.md`

## Goal

A window that is the only user window on its workspace must own the whole workspace.
An app's `WS_CHILD` helper windows, and containers restored from a stale state dump, must
never take a tile slot. If they appear again, the autostart log must say so by name.

## Non-goals

- No changes to the layout values, borders, FFM, YASB or the hotkey map.
- No komorebi version upgrade (0.1.42 is not released; nightly is not a candidate for a work PC).
- No changes to where windows are placed at logon beyond dropping an unsafe dump.

## Facts (verified 2026-10-06, symptom live)

`komorebic state` with Zen open, before any change:

```
WS 1 (bar "2"): c[0] hwnd=1707458 zen.exe [MozillaWindowClass]               817x943 @9,49  <- HALF of a 1653px work area
                c[1] hwnd=1314186 zen.exe [ReunionWindowingCaptionControls]  -29x393
                c[2] hwnd=1707088 zen.exe [InputNonClientPointerSource]      -29x-108
```

The two `WS_CHILD` windows of Zen hold the other half, invisibly. That is the reported
"the app opens at half or a quarter as if it had more tiles, alone".

Live configuration (`komorebic global-state`):

- `ignore_identifiers` **does** list `ReunionWindowingCaptionControls` and
  `InputNonClientPointerSource` (both `matching_strategy: "Legacy"`), so the Oct-5 fix is
  in place and registered.
- `manage_identifiers` = one entry: `{"kind":"Exe","id":"zen.exe"}` — the nuclear
  force-manage rule.

Two independent mechanisms can put a child window in a container even with the ignore
rules registered, and today's log cannot separate them (neither child appears in a
`Manage` event; both only get `Show` / `FocusChange`):

- **M1, stale dump restore.** `komorebic stop` writes `%TEMP%\komorebi.state.json` and
  komorebi re-applies it on start, bypassing rules. Proven on 2026-10-05 (gotcha 19).
  Amplifier seen today: the 10:02:00 logon start FAILED (`AllowSetForegroundWindow`), so
  Windows "restart apps" launched a bare `komorebi.exe` with no rules at all; that
  instance managed the children freely and its dump was restored by the configured
  instance started at 10:53.
- **M2, focused-window force-manage.** `komorebic manage` acts on whatever window is
  focused, and a forced manage ignores the ignore rules. The AHK rescue
  (`RescueUnmanagedWindows` / `FocusManage`) does `WinActivate(target)` + `Sleep(50)` +
  `Komorebic("manage")`. In the same second of the Zen cold start the OS handed
  foreground focus to the caption child (`FocusChange SystemForeground hwnd=1314186
  [ReunionWindowingCaptionControls]`), so the 50 ms window is enough for the command to
  land on the child instead of the target. 56 `process_command{ManageFocusedWindow}`
  ran in one day, with visible ping-pong between two Zen hwnds.

Also available and currently unused: `komorebic identify-object-name-change-application
exe zen.exe`. Zen is a Gecko browser that sends `EVENT_OBJECT_NAMECHANGE` on launch and
never a `Show` (`name_change_on_launch_identifiers` already ships with `firefox.exe`);
this is the supported fix for the bug both workarounds above were written around.

Independent upstream defects on this exact build, both with the same user-visible
symptom ("a window tiles into a fraction of the screen"), not fixable here:

- `LGUG2Z/komorebi#1730` — a natively minimized window stays in the container tree as a
  ghost container, so the next window is laid out against a phantom.
- `LGUG2Z/komorebi#1729` — `ghost_movement` defaults to true in 0.1.41 and corrupts the
  workspace state; upstream flipped the default to false in 0.1.42-dev, no stable release
  yet. Not exposed by any `komorebic` CLI command, so it needs `komorebi.json`, which this
  setup deliberately does not use.

## Design

1. **`windows/komorebi/container-dump.ps1`** (new, deployed): a pure function
   `Test-ContainerDump` (JSON in -> verdict out) plus `Remove-UnsafeContainerDump`.
   A dump is unsafe if any window record inside it (any object carrying an `hwnd`):
   - has a `class` in the ignore list, or
   - points at an hwnd that no longer exists (`IsWindow` false), or
   - carries a rect parked off-screen (left == -32000).
   An unsafe dump is deleted whole rather than surgically rewritten: rewriting unknown
   serialized state risks an un-deserializable dump, and dropping the dump only costs
   window-to-workspace placement on a manual re-run.
2. **`komorebi-autostart.ps1`**: dot-source the module, call the sanitizer between
   `komorebic stop` and the start, log the verdict, drop the `manage-rule exe zen.exe`,
   add `identify-object-name-change-application exe zen.exe`, and after the start warn
   once per ignored-class container that somehow still got in.
3. **`komorebi.ahk`**: `FocusManage` must verify that the window it activated is still
   the foreground window immediately before `Komorebic("manage")`, and abort otherwise.
   The rescue stays as a safety net (its firing count is the evidence for retiring it in
   a later round).
4. **`windows/komorebi/snapshot-wm.ps1`** (new, repo-only): one command that writes the
   whole evidence bundle for a point in time — `state`, `visible-windows`,
   `global-state`, and per container hwnd `IsWindow` / `IsIconic` / `IsWindowVisible` /
   `GA_ROOT` / class / real rect — so "before" and "after" are compared as measurements
   instead of prose. This is the instrument that turns three diagnostic rounds into one.

## Tasks

| # | Task | Status |
|---|---|---|
| 1 | Add `container-dump.ps1` with failing Pester tests first, then implement | done - RED `Passed: 0 Failed: 13`, GREEN `Passed: 13 Failed: 0` |
| 2 | Capture the baseline snapshot with the symptom live | done - `ws[1] ONE user window zen.exe holds 49% of the work-area width (3 containers)`, 7 violations |
| 3 | Wire the sanitizer into the autostart (stop -> sanitize -> start) with logging | done - real run logged `[warn] removed unsafe state dump (...)` and the dump stayed gone |
| 4 | Drop `manage-rule exe zen.exe`, add `identify-object-name-change-application exe zen.exe` | done - `manage_identifiers` is now empty, `name_change_on_launch` carries `zen.exe` |
| 5 | Guard the AHK rescue against managing a non-target foreground window | done - deployed; 0 rescue firings since the restart (see results) |
| 6 | Add `snapshot-wm.ps1`, deploy everything, recover with stop -> sanitize -> start | done - deployed and hash-verified, recovery run end to end |
| 7 | Functional verification matrix, before/after measured with the snapshot tool | done for the reported flows; dialogs not re-exercised (config byte-identical) |
| 8 | Update README gotchas, close `komorebi-child-window-tiling.md`, commit decision | README + task docs done; commit is the user's call |
| 9 | Decision gate: if ghosts persist, present evidence and decide keep / disable tiling / uninstall | done - user chose: keep komorebi, minimize with Win+Shift+M, retire the AHK rescue |

## Decisions (2026-10-06, user)

1. **Keep komorebi on the work PC.** The remaining failure is upstream #1730 and is
   avoidable by using `komorebic minimize` (**Win+Shift+M**, already bound in
   `komorebi.ahk`) instead of the titlebar/taskbar button.
2. **One work-unit commit** on `fix/komorebi-logon-retry-horizon`, carrying the fix, its
   tests and the docs together.
3. **Retire the AHK rescue** (`RescueUnmanagedWindows` + `FocusManage` are deleted): the
   native identify path registers Zen and Ferdium on cold start, and the rescue fired 0
   times in 540 log events.

Follow-up, deliberately not in this session: watch upstream #1730 and #1729 for a stable
release that fixes ghost containers; when 0.1.42 lands, re-run the native-minimize probe
with `snapshot-wm.ps1` before upgrading anything.

## Verification results (2026-10-06, all measurements from `snapshot-wm.ps1`)

| Step | Result |
|---|---|
| Baseline, Zen open | `ws[1]`, 3 containers: Zen 817x943 (**49%**), plus `ReunionWindowingCaptionControls` and `InputNonClientPointerSource`. 7 violations. |
| Sanitizer vs the real dump (13675 bytes, preserved as `state-dump-raw.json`) | `Safe=False WindowCount=6`, reasons `ignored-class:ReunionWindowingCaptionControls`, `ignored-class:InputNonClientPointerSource` plus `empty-rect` on 4 records - including **two records the live state did not have**, which is the resurrection content. |
| Recovery run (stop -> sanitize -> start) | `[warn] removed unsafe state dump (...)` then `[ok] komorebi ready` then `[ok] layout applied`. No further `[WARN] ignored-class container present` line. |
| After the fix, per workspace | ws[0] Terminal 98%, ws[2] Code 98%, ws[3] **Ferdium cold start alone 98%** - one container each, zero `WS_CHILD` containers anywhere. |
| Zen's children | gone from every snapshot. |
| `komorebic stop` when the children were still tiled | logged `could not get view for hwnd 1314186 / 1707088 ... no view was found` - independent corroboration that those two hwnds were never real windows. |
| AHK rescue after the fix | 0 `ManageFocusedWindow` in 540 log events, including Ferdium's cold start: the native identify path registers the window, so the rescue is now redundant (retire it in a later round, with this count as the evidence). |
| Native minimize + restore of the only window on a workspace | minimizes into a container parked at `-31993,-32000`; restoring gives back the full 98%. Ghost does not survive the restore. |
| Native minimize of one of two windows on a workspace | **the remaining bug**: the visible window stays at 49% while the minimized window keeps its parked container. `komorebic retile` does not clear it, a workspace switch does not clear it, only restoring the window does. Upstream #1730, open on this exact commit. |
| Dialogs | not re-exercised: the `$ignoredClasses` list and the `ignore-rule class` calls are byte-identical to the configuration that already had dialogs floating, so this is reasoning, not a measurement. |

## Verification

The reproduction matrix, run after the fix, each step measured with `snapshot-wm.ps1`:

1. Cold start of Zen (from fully closed) -> exactly 1 container, main window full size,
   zero containers of class `ReunionWindowingCaptionControls` / `InputNonClientPointerSource`.
2. Cold start of Ferdium -> 1 container.
3. Native minimize from the title bar and taskbar restore -> the workspace keeps 1
   container and the window comes back full size (this is the #1730 probe).
4. Workspace switch with both apps open -> layout unchanged.
5. Dialogs (Save As / Explorer copy) still float, not tiled.
6. `komorebi-autostart.log` reports the sanitizer verdict, and `[ok] layout applied`.

Pass condition: no workspace has more containers than user windows in any snapshot, and
the focused window rect matches the workspace rect when it is alone.

## Rollback

Revert the work unit, re-copy `komorebi-autostart.ps1` and `komorebi.ahk` to
`%USERPROFILE%`, delete `%USERPROFILE%\komorebi-container-dump.ps1`, then
`komorebic stop`, delete `%TEMP%\komorebi.state.json`, and run the autostart.

`komorebic toggle-pause` (already bound to Win+Shift+P) stops all tiling without
uninstalling anything: it is the one-key escape hatch if the decision gate at task 9
lands on "disable tiling".

## Commit policy

Not decided in this session: the work sits on the existing feature branch
`fix/komorebi-logon-retry-horizon`, and the harness default is not to commit without an
explicit request. The work unit is prepared for a single conventional commit; the user
decides.
