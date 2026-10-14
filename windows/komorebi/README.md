# komorebi + AutoHotkey (Windows)

The window-manager half of the Windows desktop. `komorebi.json` is the single
source of truth for the WM's **configuration** (monitors, workspaces, paddings,
borders, colours, rules) and komorebi applies it itself; `komorebi-autostart.ps1`
is the **logon supervisor** that starts everything and verifies it;
`komorebi.ahk` holds the hotkeys and the desktop behaviour (hidden taskbar,
Start-menu suppression).

## Files

- `komorebi.json` — the static komorebi configuration, applied by komorebi itself
  with `--config`. Monitors and workspaces, `display_index_preferences` (the
  dual-monitor mapping), paddings, borders/colours, `resize_delta`,
  `mouse_follows_focus: false`, the dialog `ignore_rules`, the CorelDRAW
  `manage_rules` and the `object_name_change_applications` list (Zen, plus the Word
  and Excel frames — see the gotcha on Office). **Change a look or
  behaviour knob here**, not in the script.
- `komorebi.ahk` — AHK v2 script: Win-prefixed hotkeys, `~LWin` dummy keystroke (no
  Start menu on a lone Win press), `HideTaskbar` watchdog. Focus-follows-mouse is not
  here and not in komorebi — the `masir` daemon does it (see below) — and there is no
  per-app `#HotIf` gate: every binding is Win-prefixed, so application shortcuts
  cannot collide with them.
- `komorebi-autostart.ps1` — logon **supervisor**: starts AHK/YASB, starts komorebi
  with `komorebi.json`, waits for it, starts `masir`, verifies the applied config
  and logs the outcome. It deliberately re-applies nothing.
- `../autostart/komorebi-autostart.vbs` — windowless logon launcher.

## The border formula (READ FIRST)

> **Visible tile inset = `workspace_padding + container_padding + (border_width + border_offset)`**

The border is part of the geometry. With the shipped values
(4, 0, 6, −1) the tile content sits 9 px in while the border's outer edge lands
exactly on the YASB bar's 4 px box — that is what keeps bar and tiles aligned.
Change `border_width`/`border_offset` and re-derive the paddings, or the bar
misaligns.

## Configuration (`komorebi.json`)

`komorebi.json` is the source of truth. komorebi applies it at start; to re-apply
it to a **running** instance without logging out, run
`komorebic replace-configuration "$HOME\komorebi.json"` and compare
`komorebic state` (`komorebic check` validates the file in place). Shipped values:

`resize_delta 25` · `border_width 6` · `border_offset -1` · `border_style Rounded`
· focused border `{64,64,64}` (renders ~#2f2f2f because komorebi darkens ~27%)
· unfocused `{0,0,0}` · `mouse_follows_focus false` ·
`object_name_change_applications`: `exe zen.exe`, `class OpusApp` (Word),
`class XLMAIN` (Excel) · `manage_rules`: `class CorelDRAW`
(`StartsWith`, so it matches `CorelDRAW25`) · `ignore_rules`: the dialog/child
classes in the gotcha below · 2 monitors × 5 workspaces · per-workspace padding 4/0.

Two of those values are duplicated on purpose in `komorebi-autostart.ps1` as
*expected* values for the post-start verification (`$expectedResizeDelta`,
`$expectedWorkspaces`): if the config ever fails to apply, the checks fail and the
log says so. **Change `resize_delta` or the workspace count in both files.**

## Focus follows mouse (masir — not komorebi, not AHK)

FFM is the standalone `masir` daemon (winget `LGUG2Z.masir`), started by the
autostart once komorebi is ready. It reads komorebi's managed-window file
(`%LOCALAPPDATA%\komorebi\komorebi.hwnd.json`) once at startup, so it only raises
windows komorebi manages — context menus, the desktop and the taskbar are never
touched.

- **Why not komorebi's own FFM** (`--ffm` + `focus-follows-mouse enable -i
  komorebi`): it is a low-level mouse hook installed once per process, and Windows
  silently drops it when the callback stalls past `LowLevelHooksTimeout`. A video
  going fullscreen killed it permanently and a disable/enable toggle could not
  reinstall it (measured here on komorebi v0.1.41, 2026-10-11). `--ffm` is EOL
  upstream — the maintainer's guidance is to use masir. masir keeps its hook in its
  own process and survived the same fullscreen test.
- **Why not an AHK timer**: it activated whatever root window sat under the cursor
  with no knowledge of komorebi's model and also matched the `#32768` popup of
  context menus, which then closed instantly. masir only touches managed windows,
  so that class of bug cannot come back.

`mouse_follows_focus` (komorebi's cursor warp, a different feature) stays OFF, set
in `komorebi.json`.

## Hotkeys (cheat sheet)

| Action | Keys |
|---|---|
| Focus window | `Super+arrows` |
| Move window | `Super+Shift+arrows` |
| Resize (toward the neighbor = grow) | `Super+Ctrl+arrows` |
| Workspaces 1–5 | `Super+1..5` · move `Super+Shift+1..5` |
| Close | `Super+W` |
| Float | `Super+Shift+V` |
| App launchers | `Super+F` Ferdium · `Super+B` default browser · `Super+M` default email |
| Minimize | `Super+Shift+M` |
| Stack / unstack | `Super+Ctrl+Shift+arrows` / `Super+Ctrl+Shift+Space` |
| Terminal | `Super+Enter` |
| Pause tiling | `Super+Shift+P` |

Launchers resolve: the registered OS default for the URL scheme first (`http` /
`mailto` via UserChoice ProgId), with fallbacks Ferdium→(known paths, then
plain name), browser→Zen then Brave, email→Mailspring. The Squirrel
`Update.exe` stub is skipped so Mailspring launches the real app. Monocle
(fullscreen) and native maximize are intentionally unbound since `Super+F`/
`Super+M` became launchers.

It is a HM-style Toggle: `Super` = the Windows key.

## Gotchas

- **Zen cold start escapes tiling, and its AHK rescue is gone.** If Zen was fully
  closed, its main window can be created WITHOUT a `Show` window event (only a
  `TitleUpdate` arrives), so komorebi never registered it as a tile and the window
  floated until a second one was opened. What covers it now is the
  `object_name_change_applications` entry for `exe zen.exe` in `komorebi.json`: Zen is
  Gecko-based and emits `EVENT_OBJECT_NAMECHANGE` on launch instead of a `Show`.
  The AHK `RescueUnmanagedWindows` timer that used to force the window with
  `komorebic manage` was **removed on 2026-10-06** — it had fired zero times in 540
  log events, and it was dangerous: `komorebic manage` acts on the FOCUSED window, so
  it could tile a `WS_CHILD` helper of the very app it was rescuing. Do not re-add it;
  if a Zen window still escapes, run `komorebic manage` by hand or widen the
  `object_name_change_applications` rule. (If a timer is ever re-added: AHK v2 needs
  `Fn.Bind(args)` — arrow closures do **not** capture local variables, and a bare
  `Bind()` call silently kills the script.)
- **A window without `WS_CAPTION` is never managed, and no command will force it.**
  komorebi's eligibility gate ends with
  `(style.contains(WS_CAPTION) && ex_style.contains(WS_EX_WINDOWEDGE)) &&
  !ex_style.contains(WS_EX_DLGMODALFRAME) && (allow_layered ||
  !ex_style.contains(WS_EX_LAYERED))`, so a window that draws its own title bar and
  omits the system caption bit is dropped before anything is logged. **CorelDRAW is
  exactly this case**: its frame (`CorelDRAW25`, the window that actually holds the
  document) measured `St=0x170f0000` / `Ex=0x00040100` — `WS_THICKFRAME`, `WS_SYSMENU`,
  `WS_MINIMIZEBOX`, `WS_MAXIMIZEBOX`, `WS_EX_APPWINDOW`, `WS_EX_WINDOWEDGE`, **no
  `WS_CAPTION`** — while every window komorebi does tile has `WS_CAPTION=True`. The only
  escape is `managed_override`, i.e. a manage rule, which `komorebi.json` applies
  **by class** (`manage_rules`: `class CorelDRAW` with `matching_strategy: StartsWith`,
  matching `CorelDRAW25`). Do not widen it to `exe CorelDRW.exe`: that app also owns
  layered `Dial Wheel` popups, `ComboLBox`, IME, DDE and `Afx:...:0` helpers, and the
  override bypasses the layered test as well, so an exe-wide rule tiles that junk.
  There is no `unmanage-rule`; the rules are applied at start from `komorebi.json`, so
  reverting means editing that file and restarting komorebi. To see the verdict for any
  window, start komorebi with `--log-level debug`: it prints
  `ignoring (exe: …, title: …, event: …)` plus the full decision record.
- **Office frames never send a `Show`, so they need the object-name-change lever, not
  a manage rule.** Word (`OpusApp`) and Excel (`XLMAIN`) frames pass
  `window_is_eligible` on their own — measured 2026-10-14, `style 0x16cf0000` /
  `ex_style 0x00000110` (the minimized variant adds `WS_MINIMIZE`: `0x36cf0000`):
  `WS_CAPTION` and `WS_EX_WINDOWEDGE` set, neither
  `WS_EX_DLGMODALFRAME` nor `WS_EX_LAYERED`. What is missing is the **event**: Office
  creates the frame already visible, so Windows reports only
  `EVENT_OBJECT_NAMECHANGE` (logged as `event="TitleUpdate"`) and `should_manage` is
  never reached. `komorebi/src/window_manager_event.rs` maps `ObjectNameChange` to
  `Show` — i.e. runs the gate — for whatever matches
  `object_name_change_applications`, and only while the window is **not** minimized
  (upstream #941). That is why the frame tiles on a restore from the taskbar either
  way, but never on a cold open, and why this list is the lever here: a `manage_rules`
  entry (the CorelDRAW lever) is only consulted once a `Show` has already arrived, so
  it would do nothing. **By class, not by exe**: `WINWORD.EXE` also owns `MsoSplash`,
  `_WwB`, `_WwO`, `OleDdeWndClass`, `MsoStdCompMgr`, `AcroStubUnloadWClass`,
  `OfficePowerManagerWindow`, `HardwareMonitorWindowClass`, `MSCTFIME UI`, `IME` and
  `ARC Event Window 00`, and `EXCEL.EXE` its own set (`ComboLBox`, …).
- **Configuration lives in exactly one place.** `komorebi.json` is applied by komorebi
  (`--config`); the logon script supervises and verifies but re-applies nothing, so a
  knob that is only in a doc or only in the script does not exist. Two schema details
  bite when hand-editing it: every workspace needs a `name` (it is required), and
  `workspace_padding`/`container_padding` should be written **per workspace** — the
  global `default_workspace_padding`/`default_container_padding` keys work, but they
  leave `state` padding `null` (inherited), which makes the applied configuration
  unverifiable from `komorebic state`.
- **Workspace names do not reach the bar.** The YASB `komorebi_workspaces` widget draws
  fixed glyphs (`•`/`●`), so naming the workspaces `I…V` / `1…5` in `komorebi.json`
  changed nothing visually — that is why the names exist without a doc caveat.