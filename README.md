# dotfiles

Personal configuration, ported across machines and OSes. Everything here is
**source of truth**: to use it on a fresh machine, clone and copy/install — no
symlink manager required (copies are simpler and Windows-friendlier).

Works on **Windows** (tiling desktop: komorebi + AutoHotkey + YASB) and is
structured for **Linux** (Arch + Hyprland) — the Linux side currently ships as
ready-made folders with configs to be added from the Arch machine.

Written for humans and agents: see [AGENTS.md](AGENTS.md) for the fast path.

---

## Layout

```
dotfiles/
├── README.md              ← this file
├── AGENTS.md              ← fast path for AI agents
├── shared/
│   ├── starship.toml      ← Starship prompt (both OSes)
│   └── nvim/              ← Neovim config (vim-plug based; currently ~/.config/nvim)
├── windows/
│   ├── komorebi/
│   │   ├── komorebi.ahk              ← AHK v2: hotkeys, focus-follows-mouse, taskbar handling
│   │   ├── komorebi-autostart.ps1    ← logon script: layout/looks + launches everything
│   │   └── README.md
│   ├── yasb/
│   │   ├── config.yaml               ← YASB v2 bar: widgets, groupers, pills
│   │   ├── styles.css                ← theme: transparent bar, black pills
│   │   └── README.md
│   ├── win-terminal/settings.json    ← Windows Terminal
│   ├── powershell/                   ← PS7 profile (sources user_profile.ps1)
│   ├── autostart/komorebi-autostart.vbs  ← windowless logon launcher
│   └── install/
│       ├── setup.ps1                 ← winget + file placement (idempotent)
│       └── cleanup.ps1               ← rollback
└── linux/
    ├── hyprland/        ← placeholder (Arch machine config goes here)
    ├── waybar/          ← placeholder
    └── README.md
```

---

## Quick start — Windows

Prerequisites: Windows 11, [winget](https://github.com/microsoft/winget-cli).

```powershell
git clone <this-repo> C:\Users\<you>\dotfiles
cd C:\Users\<you>\dotfiles
powershell -ExecutionPolicy Bypass -File windows\install\setup.ps1
```

`setup.ps1` (idempotent, safe to re-run):
1. Installs via winget: `LGUG2Z.komorebi` · `AutoHotkey.AutoHotkey` · `AmN.yasb` · `DEVCOM.JetBrainsMonoNerdFont`.
2. Places the config files (komorebi.ahk, autostart, YASB config/styles, PowerShell profile).
3. Installs the logon autostart (`komorebi-autostart.vbs` in `shell:startup`).

Then **log on once** (or run `%USERPROFILE%\komorebi-autostart.ps1` once):
komorebi starts, layout/workspace/border preferences are applied, AHK loads
(hotkeys + focus-follows-mouse + hidden taskbar), YASB renders the bar.

## Quick start — Linux

```bash
git clone <this-repo> ~/dotfiles
ln -sf ~/dotfiles/shared/starship.toml ~/.config/starship.toml
rsync -a ~/dotfiles/shared/nvim/ ~/.config/nvim/
# hyprland/waybar configs land in linux/ as they are ported from the Arch machine
```

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
| Close / fullscreen / float | `Super+W` / `Super+F` / `Super+Shift+V` |
| Minimize / maximize | `Super+Shift+M` / `Super+M` |
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

See `windows/yasb/README.md` for the widget map and the styling notes.

### Starship / Neovim / Terminal

- `shared/starship.toml` — segmented prompt (Catppuccin-flavored).
- `shared/nvim/` — Neovim with **vim-plug** (`init.vim` + `plug.vim`); note:
  despite the project plan mentioning LazyVim, the live config is vim-plug —
  swapping to LazyVim later means replacing this folder and re-plugging.
- `windows/win-terminal/settings.json` — Windows Terminal settings (per-machine
  profiles may need trimming).

---

## Verification (health checks)

```powershell
# komorebi alive + state
komorebic state          # -> JSON; peek is_paused, monitors, workspaces

# processes expected after logon
Get-Process komorebi,yasb,AutoHotkey64

# YASB log (errors show up here after config/style edits)
Get-Content "$HOME\.config\yasb\yasb.log" -Tail 20

# quick sanity: bar is rendering at the top; Super+arrows focuses tiles
```

## Customization knobs

- **Gaps / borders** (komorebi): `workspacePadding`, `containerPadding`,
  `borderWidth`, `borderOffset`, `borderFocusedRgb`, `borderUnfocusedRgb` in
  `komorebi-autostart.ps1` — read the border formula comment first.
- **YASB look**: pill opacity `rgba(0,0,0,0.45)` in `styles.css` (` .widget`);
  widget set/order in `config.yaml` under `bars.status-bar.widgets`.
- **FFm dwell**: in `komorebi.ahk` (`SetTimer(FollowMouse, 60)`; the 
  `stable++ < 2` value is the dwell multiplier).

## Gotchas (learned the hard way)

1. **komorebi border inset formula**: visible inset = `workspacePadding + containerPadding + (borderWidth + borderOffset)`. The border is *part of the geometry* — change it and the tile alignment with the bar shifts.
2. **Nerd Font family names**: the DEVCOM package installs `JetBrainsMono NF` (not "JetBrainsMono Nerd Font"). Use `NFP` (Propo) first for icons so they don't clip.
3. **`%#d`** (not `%-d`) is how Windows Python renders a day without a leading zero.
4. **No per-widget blur in YASB** (DWM limitation, confirmed by the maintainer): blur applies to whole windows; pills share one window.
5. **`mouse_follows_focus` must be OFF** (the autostart disables it) or the cursor gets warped on every focus change and fights focus-follows-mouse.
6. **YASB rewrites its config files on reload**; after editing `styles.css` a YASB restart is the reliable way to see changes. Widget validation is strict (e.g., `power_menu` requires `shutdown`, `restart`, `cancel`).
7. Don't run `komorebic start` from within MSYS bash (it hangs there); use PowerShell `Start-Process` or the logon script.

## Uninstall (Windows)

`powershell -ExecutionPolicy Bypass -File windows\install\cleanup.ps1` removes the
placed files and the startup entry; winget uninstall commands are printed there.

---

## License

Unlicensed: use freely, attribute if you share. No warranty.