# CorelDRAW is never managed by komorebi

Status: done — T1-T5 complete and verified live on 2026-10-07
Repo: `C:\Users\verdu\verdu.dotfiles`, branch `main` (personal repo — commits land on `main`)
Date: 2026-10-07
Related: `odd/tasks/komorebi-ghost-containers.md` (the opposite failure: windows that were tiled when they should not be), `odd/tasks/komorebi-child-window-tiling.md`

## Goal

A window the user actually works in must be tileable. CorelDRAW's main frame is not,
and there is no manual lever: the AHK rescue that used to force-manage the focused
window was retired 2026-10-06 (`komorebi.ahk`), so `komorebic manage` from a terminal
is the only remaining option and it is refused too.

## Root cause (proven from source + measurement, not inferred)

komorebi v0.1.41 decides eligibility in `komorebi/src/window.rs`
(`Window::should_manage` → `window_is_eligible`). After the earlier gates
(`is_window`, `rect.right >= MINIMUM_WIDTH`, `rect.bottom >= MINIMUM_HEIGHT`,
readable title, not cloaked, not in the ignore list) the final condition is:

```rust
if (allow_wsl2_gui || allow_titlebar_removed
    || style.contains(WindowStyle::CAPTION) && ex_style.contains(ExtendedWindowStyle::WINDOWEDGE))
   && !ex_style.contains(ExtendedWindowStyle::DLGMODALFRAME)
   && (allow_layered || !ex_style.contains(ExtendedWindowStyle::LAYERED))
   || managed_override
{
    return true;
} else if let Some(event) = event {
    tracing::debug!("ignoring (exe: {}, title: {}, event: {})", exe_name, title, event);
}
false
```

CorelDRAW paints its own title bar, so its frame omits the system `WS_CAPTION`.
`WS_CAPTION` is therefore missing and the window is **ineligible**: komorebi drops
every event for it at the top of `process_event`, and `komorebic manage` refused it.

## Evidence

Measured on the live windows (scripts in `%TEMP%`, kept out of the repo):
`%TEMP%\corel-probe5.txt`, `%TEMP%\corel-windows.txt`, `%TEMP%\corel-probe4.txt`.

| Window | `St` | `WS_CAPTION` | `WS_EX_WINDOWEDGE` | Eligible |
|---|---|---|---|---|
| **`CorelDRAW25`** "CorelDRAW - C:\Users\verdu\Downloads\25-text-2-outlined.cdr" | `0x170f0000` | **False** | True | **NO** |
| `Roland VersaWorks` | `0x14cf0000` | True | True | yes |
| `WindowsTerminal` (x2) | `0x34cf0000` | True | True | yes |
| `zen` | `0x16cf0000` | True | True | yes |

Corroboration:

- `%TEMP%\komorebi.log.2026-10-07`: 37 Corel lines, all `ObjectNameChange`/`TitleUpdate`
  plus 3 `Destroy`, and **zero** `Show`/`SystemForeground`/`FocusChange`/`Cloak` for any
  Corel hwnd, while every other app receives them.
- Guarded live test: `SetForegroundWindow(0x3e0940)` verified as
  `GetForegroundWindow() == 0x3e0940`, then `komorebic manage` → komorebi logged
  `process_command{ManageFocusedWindow}: processed` and the window did **not** enter the
  state (5 containers before and after).
- No komorebi config file exists anywhere on this machine (`~/.config/komorebi/`,
  `~/komorebi.json`, APPDATA, LOCALAPPDATA), so the whole rule set is the CLI calls in
  `komorebi-autostart.ps1`. The string `corel` does not exist in `komorebi.exe`.
- The reason is invisible in production logs because it is emitted at `debug` level and
  the autostart starts komorebi at the default `info`. `komorebi.exe --log-level debug`
  prints the full `RuleDebug` verdict per window.

## Fix

`managed_override` is the only way past that condition, and it comes from
`komorebic manage-rule <exe|class|title|path> <ID>` (legacy matching is
`starts_with || ends_with`, so `CorelDRAW` covers `CorelDRAW25`).

**By class, never by exe.** `CorelDRW.exe` owns a large zoo of top-level windows, and
the override also bypasses the layered check. An exe-wide rule would make komorebi tile
`Dial Wheel` and `Dial Wheel Adornment` (layered, 0x0), `ComboLBox` helpers,
`MSCTFIME UI`/`IME`, `OleDdeWndClass` and the `Afx:…:0` helper frames: the same
"nuclear rule" mistake the repo already paid for with the retired
`manage-rule exe zen.exe`. Class `CorelDRAW` matches the one window the user works in
(verified with a document open: `CorelDRAW25` is the document frame, 1680x1009,
visible, titled `25-text-2-outlined.cdr`).

## Tasks

| # | Task | Status |
|---|---|---|
| T1 | Prove the fix live before touching the repo (`manage-rule class CorelDRAW` + guarded `manage`) | done — the frame entered `ws1 container 1`, log `event="Manage" hwnd=4065600` |
| T2 | Add the rule to `windows/komorebi/komorebi-autostart.ps1` | done — line 212, with the rationale inline |
| T3 | Document the gotcha in `windows/komorebi/README.md` | done — new gotcha + the stale `manage-rule exe zen.exe` entry in the runtime list corrected |
| T4 | Deploy the autostart to `%USERPROFILE%` and verify (byte-identical, parser clean) | done — `cmp` identical, both copies parse clean |
| T5 | Commit on `main` and record the finding | done |

## Verification plan

| Check | Expected |
|---|---|
| live `manage-rule class CorelDRAW` + `manage` on the focused Corel frame | the frame enters a container and is tiled |
| `komorebic state` | the Corel hwnd appears under a workspace container |
| `%TEMP%\komorebi.log.<date>` | an `event="Manage" hwnd=<corel>` line appears |
| deployed `%USERPROFILE%\komorebi-autostart.ps1` | byte-identical to the repo, `Parser::ParseFile` clean |
| the autostart's other rules | untouched; `CorelDRW.exe`'s helper windows stay unmanaged |

## Reverting

There is no `unmanage-rule` subcommand: rules are runtime state, so reverting a live
rule means restarting komorebi (the autostart re-applies only what is in the script).
Removing the line from `komorebi-autostart.ps1` and re-deploying therefore reverts the
change at the next start, and the previous bytes are in git.

## Evidence log

- Diagnosis — see the table and log counts above; probes at `%TEMP%\corel-probe*.txt`,
  `%TEMP%\corel-windows.txt`. Side effect to disclose: the guarded test focused
  `Roland VersaWorks` first (the selector picked the wrong window), which made komorebi
  follow focus and switch to workspace 3, with a Cloak/Uncloak cycle on VersaWorks.
- T1 — `komorebic manage-rule class CorelDRAW` applied live, then the frame was foregrounded
  (`GetForegroundWindow() == 0x3e0940`, verified) and `komorebic manage` run:
  `in state BEFORE = False` → `in state AFTER = True`, landed at
  `monitor DISPLAY1 workspace 1 container 1`, log
  `process_event{event="Manage" hwnd=4065600}`. 
- T2 — `windows/komorebi/komorebi-autostart.ps1` line 212
  (`& $komorebic manage-rule class CorelDRAW | Out-Null`), placed right after the
  `ignore-rule` loop, with the `window_is_eligible` snippet and the exe-wide warning inline.
- T3 — `windows/komorebi/README.md`: new gotcha ("A window without `WS_CAPTION` is never
  managed…") and the runtime-preferences list corrected from `manage-rule exe zen.exe` to
  `identify-object-name-change-application exe zen.exe` + `manage-rule class CorelDRAW`.
- T4 — `cp` + `cmp` byte-identical for the deployed `%USERPROFILE%\komorebi-autostart.ps1`;
  `Parser::ParseFile` clean on both copies. Live state after the change: `resize_delta=25`,
  `focus_follows_mouse=Komorebi`, `is_paused=False`, `mouse_follows_focus=False`,
  and the containers are Terminal (ws0), VersaWorks (ws1), Zen (ws2),
  **CorelDRAW (ws3, hwnd 4065600)**, network share (ws4).
- T5 — see the commit on `main`.

## Follow-ups

1. **The rule has been proven live but not yet exercised at a logon.** The reliable proof
   is the next sign-in: `komorebi-autostart.log` must show `[ok] layout applied` and
   CorelDRAW must tile without a manual `komorebic manage`.
2. **`windows/komorebi/README.md` carries pre-existing staleness**, left untouched because
   it is a different concern: the `RescueUnmanagedWindows` timer it documents under the
   Zen gotcha was retired on 2026-10-06, and the "Focus follows mouse (why it is in AHK,
   not masir)" section predates native FFM (`komorebi.exe --ffm` +
   `focus-follows-mouse enable -i komorebi`, as `komorebi.ahk` states). Both are now
   false statements about the current design and need a separate pass.
3. **`CorelDRAW` is a class prefix, not a full class name.** If a future Corel release
   renames the frame away from the `CorelDRAW*` prefix the rule silently stops matching,
   and the symptom returns as "Corel stopped tiling". `komorebi.exe --log-level debug`
   plus this task's table are the fastest way back.
