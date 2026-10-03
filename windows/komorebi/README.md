# komorebi + AutoHotkey (Windows)

The window-manager half of the Windows desktop. `komorebic` commands live in
`komorebi-autostart.ps1` (layout, workspaces, paddings, borders, colours);
runtime behaviour lives in `komorebi.ahk` (hotkeys, focus-follows-mouse,
hidden taskbar, Start-menu suppression).

## Files

- `komorebi.ahk` — AHK v2 script (hotkeys, FFm timer, `HideTaskbar` watchdog,
  `~LWin` dummy keystroke, `#HotIf !WinActive("ahk_exe Illustrator.exe")` guard).
- `komorebi-autostart.ps1` — logon/apply script: starts komorebi, re-applies
  every runtime preference, launches AHK + YASB.
- `../autostart/komorebi-autostart.vbs` — windowless logon launcher.

## The border formula (READ FIRST)

> **Visible tile inset = `workspacePadding + containerPadding + (borderWidth + borderOffset)`**

The border is part of the geometry. With the shipped values
(4, 0, 6, −1) the tile content sits 9 px in while the border's outer edge lands
exactly on the YASB bar's 4 px box — that is what keeps bar and tiles aligned.
Change `borderWidth`/`borderOffset` and re-derive the paddings, or the bar
misaligns.

## Runtime preferences applied at logon

`resize-delta 25` · `border-width 6` · `border-offset -1` · `border-style rounded`
· focused border `64,64,64` (renders ~#2f2f2f because komorebi darkens ~27%)
· unfocused `0,0,0` · `mouse-follows-focus disable` · `manage-rule exe zen.exe`
· 5 workspaces/monitor · workspacePadding 4 · containerPadding 0.

## Focus follows mouse (why it is in AHK, not masir)

`masir` was tried and retired: its "raise" never changed focus on this system,
and being a console app it died on Ctrl-C from the launching console. AHK's
`WinActivate` on the root window under the cursor (60 ms poll, 2-tick dwell)
works and is already wired into `komorebi.ahk`.

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

Launchers resolve: the registered OS default for the URL scheme first (`http` /
`mailto` via UserChoice ProgId), with fallbacks Ferdium→(known paths, then
plain name), browser→Zen then Brave, email→Mailspring. The Squirrel
`Update.exe` stub is skipped so Mailspring launches the real app. Monocle
(fullscreen) and native maximize are intentionally unbound since `Super+F`/
`Super+M` became launchers.
| Stack / unstack | `Super+Ctrl+Shift+arrows` / `Super+Ctrl+Shift+Space` |
| Terminal | `Super+Enter` |
| Pause tiling | `Super+Shift+P` |

It is a HM-style Toggle: `Super` = the Windows key.