# dotfiles

Personal configuration, ported across machines and OSes. Everything here is
**source of truth**; to use it anywhere you **copy files to their exact
destinations** — see [MANIFEST.md](MANIFEST.md), which maps every file. No
installers, no symlink managers: copy is the contract. Machines get exactly the
same setup by following the same manifest.

Works on **Windows** (tiling desktop: komorebi + AutoHotkey + YASB) and is
structured for **Linux** (Arch + Hyprland) — the Linux side currently ships as
ready-made folders with configs to be added from the Arch machine.

Written for humans and agents: **read [MANIFEST.md](MANIFEST.md) to install**,
[AGENTS.md](AGENTS.md) is the fast path for AI agents.

---

## Layout

```
dotfiles/
├── MANIFEST.md           ← WHERE EVERY FILE GOES (the contract for copying)
├── README.md
├── AGENTS.md
├── shared/
│   ├── starship.toml     ← Starship prompt (both OSes)
│   └── nvim/             ← Neovim config (vim-plug based)
├── windows/
│   ├── komorebi/
│   │   ├── komorebi.ahk              ← AHK v2: hotkeys, focus-follows-mouse, taskbar
│   │   ├── komorebi-autostart.ps1    ← applies layout/looks + launches everything
│   │   └── README.md
│   ├── yasb/
│   │   ├── config.yaml               ← YASB v2 bar: widgets, groupers, pills
│   │   ├── styles.css                ← theme: transparent bar, black pills
│   │   └── README.md
│   ├── win-terminal/settings.json    ← Windows Terminal
│   ├── powershell/                   ← PS7 profile + user_profile.ps1
│   └── autostart/komorebi-autostart.vbs  ← windowless logon launcher
└── linux/
    ├── hyprland/        ← placeholder (Arch machine config goes here)
    ├── waybar/          ← placeholder
    └── README.md
```

---

## Install — copy per the manifest

1. Clone the repo anywhere.
2. Open **`MANIFEST.md`** — it lists each repo file and its exact destination
   for Windows and Linux.
3. Copy the files to those destinations (a handful of `copy`/`cp` commands; the
   `shared/nvim/` entry is a recursive copy).
4. Windows: install the four prerequisites (winget commands are at the top of
   the manifest — they are one-time, not part of the repo), then sign in once
   (or run `%USERPROFILE%\komorebi-autostart.ps1` once) and verify (below).

That is the whole install. Nothing else runs.

---

## What each piece does

### komorebi + AutoHotkey (`windows/komorebi/`)

Super (Win) key as the main modifier, Hyprland-style — all window management is
keyboard-driven; the native taskbar is hidden and the YASB bar replaces it.

| Action | Keys |
|---|---|
| Focus / move window | `Super+arrows` / `Super+Shift+arrows` |
| Resize (direction-aware) | `Super+Ctrl+arrows` (grows toward the pointed neighbor) |
| Workspaces | `Super+1..5` · move: `Super+Shift+1..5` |
| Close / float | `Super+W` / `Super+Shift+V` |
| App launchers | `Super+F` Ferdium · `Super+B` default browser (Zen→Brave) · `Super+M` default email (Mailspring) |
| Minimize | `Super+Shift+M` |
| Stack / unstack | `Super+Ctrl+Shift+arrows` / `Super+Ctrl+Shift+Space` |
| Terminal | `Super+Enter` |
| Pause tiling | `Super+Shift+P` |

Implied/native details worth knowing:
- **Focus follows mouse** is implemented in AHK (masir was retired: its raising
  never changed focus on this system and it died on console Ctrl-C).
- The **native taskbar is hidden** by an AHK watchdog (auto-hide leaves a 2 px
  sliver that reveals it; hiding the window kills the sliver). The YASB systray
  widget replaces the tray.
- A **dummy keystroke** (`~LWin::Send("{Blind}{vkE8}")`) stops the lone Super
  press from opening the Start menu; all `Super+letter` system shortcuts keep
  working.

See `windows/komorebi/README.md` for the border/padding *formula* — the single
most important gotcha for hand-editing this stack.

### YASB (`windows/yasb/`)

Transparent bar, black translucent pills, one pill per group:

```
left   : ●●●●● (workspaces as dots)
center : [audio visualizer + media lite]   (hidden when nothing plays)
right  : ⟲ cpu%·MHz  MEM%  ⚡ gpu%·temp  ▾tray  ·  date time h  ⏻
```

- Workspaces: 5 dynamic dots (active = opaque white, others translucent).
- Systray is collapsed by default inside the system group (the ▾ expands it).
- Click widgets for their popups (media player controls + per-app volume,
  power menu with restart/shutdown/sleep/lock/hibernate).

See `windows/yasb/README.md` for the widget map and styling notes.

### Starship / Neovim / Terminal

- `shared/starship.toml` — segmented prompt (Catppuccin-flavored).
- `shared/nvim/` — Neovim with **vim-plug** (`init.vim` + `plug.vim`); the live
  config is not LazyVim — swapping later means replacing this folder.
- `windows/win-terminal/settings.json` — Windows Terminal settings (per-machine
  profiles may need trimming).

---

## Verification (health checks)

```powershell
komorebic state          # WM alive + layout JSON
Get-Process komorebi,yasb,AutoHotkey64
Get-Content "$HOME\.config\yasb\yasb.log" -Tail 20
# sanity: the bar renders at the top; Super+arrows focuses tiles
```

## Customization knobs

- **Gaps / borders** (komorebi): `workspacePadding`, `containerPadding`,
  `borderWidth`, `borderOffset`, `borderFocusedRgb`, `borderUnfocusedRgb` in
  `komorebi-autostart.ps1` — read the border formula comment first.
- **YASB look**: pill opacity `rgba(0,0,0,0.45)` in `styles.css` (` .widget`);
  widget set/order in `config.yaml` under `bars.status-bar.widgets`.
- **FFm dwell**: in `komorebi.ahk` (`SetTimer(FollowMouse, 60)`; the
  `stable++ < 2` value is the dwell multiplier).
- After editing a config, **re-copy that single file** to reinstall it.

## Gotchas (learned the hard way)

1. **komorebi border inset formula**: visible inset = `workspacePadding + containerPadding + (borderWidth + borderOffset)`. The border is *part of the geometry* — change it and the tile alignment with the bar shifts.
2. **Nerd Font family names**: the DEVCOM package installs `JetBrainsMono NF` (not "JetBrainsMono Nerd Font"). Use `NFP` (Propo) first for icons so they don't clip.
3. **`%#d`** (not `%-d`) is how Windows Python renders a day without a leading zero.
4. **No per-widget blur in YASB** (DWM limitation, confirmed by the maintainer): blur applies to whole windows; pills share one window.
5. **`mouse_follows_focus` must be OFF** (the autostart disables it) or the cursor gets warped on every focus change and fights focus-follows-mouse.
6. **YASB rewrites its config files on reload**; after editing `styles.css` a YASB restart is the reliable way to see changes. Widget validation is strict (e.g., `power_menu` requires `shutdown`, `restart`, `cancel`).
7. Don't run `komorebic start` from within MSYS bash (it hangs there); use PowerShell `Start-Process` or the logon script.
8. **Reboots can silently undo the komorebi layout**: Windows 11 can re-launch a bare `komorebi.exe` (plus AHK/YASB) at sign-in via "restart apps" before/without the autostart script, and komorebi's IPC socket can lag on a busy boot. The autostart handles both: it waits until `komorebic state` answers (up to 20s), re-applies the layout, skips AHK/YASB if already running, and logs to `%USERPROFILE%\komorebi-autostart.log`. If the layout is missing after a reboot, read that log first.
9. **`komorebic border-offset -1` fails**: `-1` is parsed as a flag; use `border-offset -- -1` (the autostart already does).

## Revert

Delete the destination files listed in `MANIFEST.md` (optionally uninstall the
four winget prerequisites). Nothing here modifies what was previously on the
machine.

---

## License

Unlicensed: use freely, attribute if you share. No warranty.