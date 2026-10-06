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
4. Windows: install the prerequisites listed at the top of the manifest (winget
   commands — one-time, not part of the repo), then sign in once (or run
   `%USERPROFILE%\komorebi-autostart.ps1` once) and verify (below).

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
- **Focus follows mouse** is komorebi's own implementation (autostart starts it
  with `--ffm` and runs `focus-follows-mouse enable -i komorebi`): it only
  focuses windows komorebi manages, so context menus/desktop/taskbar are never
  touched. (An earlier AHK-based version broke context menus by activating the
  menu's `#32768` popup — that is why FFM no longer lives in AHK.)
- The **native taskbar is hidden** by an AHK watchdog (auto-hide leaves a 2 px
  sliver that reveals it; hiding the window kills the sliver). The YASB systray
  widget replaces the tray.
- A **dummy keystroke** (`~LWin::Send("{Blind}{vkE8}")`) stops the lone Super
  press from opening the Start menu; all `Super+letter` system shortcuts keep
  working.
- **Dialogs float**: the autostart adds `ignore-rule` for the common dialog
  classes (`#32770`, `TaskDialog`) and Zen's dialog shadow
  (`MozillaDialogClass` / `MozillaDropShadowWindowClass`), so Save As, open and
  copy-progress dialogs stay unmanaged above the tiles. Match by **class**, never
  by exe (that would float the app's main window too). Custom dialogs (e.g.
  Illustrator) can be discovered with `windows/komorebi/spy-dialog.ps1`
  (repo-only tool: `spy-dialog.ps1 -Watch 90` while you open it) and added to
  the same rule list.

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

### Starship / Neovim / Terminal / Shell

- `shared/starship.toml` — segmented prompt (Catppuccin-flavored).
- `shared/nvim/` — **LazyVim** (GentlemanNvim from Gentleman.Dots, adapted for
  Windows: node paths quoted, current extras, AI plugins the user does not use
  disabled). Installed to `%LOCALAPPDATA%\nvim` on Windows (Neovim ignores
  `~/.config/nvim` there). First launch bootstraps lazy.nvim and all plugins.
- `windows/nushell/` — Nushell config (`config.nu`, `env.nu`) + `setup-autoloads.nu`
  which regenerates the tool-generated `vendor/autoload/*.nu` (starship/zoxide/
  atuin/carapace) at the destination. `env.nu` also wires **fnm** into Nushell by
  hand: fnm has no nushell target and `fnm env --json` reports no `PATH`, so the
  file loads the JSON and prepends `FNM_MULTISHELL_PATH` itself. fnm is therefore a
  prerequisite (see `MANIFEST.md`).
- `windows/herdr/config.toml` — Herdr (agent multiplexer): Gentle theme, prefix
  `ctrl+a`, arrow-key pane navigation, alt+arrow resize, default shell Nushell.
- `windows/win-terminal/settings.json` — Windows Terminal settings; Nushell is
  the default profile (per-machine profiles may need trimming).

---

## Verification (health checks)

```powershell
komorebic state          # WM alive + layout JSON
Get-Process komorebi,yasb,AutoHotkey64
Get-Content "$HOME\komorebi-autostart.log" -Tail 5   # what the autostart did at logon, and why
Get-Content "$HOME\.config\yasb\yasb.log" -Tail 20
# sanity: the bar renders at the top; Super+arrows focuses tiles
```

## Customization knobs

- **Gaps / borders** (komorebi): `workspacePadding`, `containerPadding`,
  `borderWidth`, `borderOffset`, `borderFocusedRgb`, `borderUnfocusedRgb` in
  `komorebi-autostart.ps1` — read the border formula comment first.
- **YASB look**: pill opacity `rgba(0,0,0,0.45)` in `styles.css` (` .widget`);
  widget set/order in `config.yaml` under `bars.status-bar.widgets`.
- **Focus follows mouse**: komorebi native — `--ffm` on start and
  `focus-follows-mouse enable -i komorebi` in `komorebi-autostart.ps1`; it
  focuses only managed tiles. Never re-add an AHK polling loop for this.
- After editing a config, **re-copy that single file** to reinstall it.

## Gotchas (learned the hard way)

1. **komorebi border inset formula**: visible inset = `workspacePadding + containerPadding + (borderWidth + borderOffset)`. The border is *part of the geometry* — change it and the tile alignment with the bar shifts.
2. **Nerd Font family names and scope**: the JetBrains Nerd Fonts are installed **per user** here — files in `%LOCALAPPDATA%\Microsoft\Windows\Fonts`, registered under `HKCU`, with **zero** entries in `HKLM` and none in `C:\Windows\Fonts` — so elevated processes and other accounts do not see them. Windows Terminal only accepts a registered *family* name, and the valid ones are `JetBrainsMono NF`, `JetBrainsMono NFM`, `JetBrainsMono NFP` plus the `JetBrainsMonoNL …` variants. `"JetBrainsMonoNL Nerd Font"` — the value this repo used to ship — is **not** a family, and WT then falls back to its default font **silently**: no error in any log, the only symptom being missing or clipped prompt icons. A profile with **no** `font` key gets the WT default too. Use `NFP` (Propo) first for icons so they don't clip, and set `font` explicitly on every profile you care about.
3. **`%#d`** (not `%-d`) is how Windows Python renders a day without a leading zero.
4. **No per-widget blur in YASB** (DWM limitation, confirmed by the maintainer): blur applies to whole windows; pills share one window.
5. **`mouse_follows_focus` must be OFF** (the autostart disables it) or the cursor gets warped on every focus change and fights focus-follows-mouse.
6. **YASB rewrites its config files on reload**; after editing `styles.css` a YASB restart is the reliable way to see changes. Widget validation is strict (e.g., `power_menu` requires `shutdown`, `restart`, `cancel`).
7. Don't run `komorebic start` from within MSYS bash (it hangs there); use PowerShell `Start-Process` or the logon script.
8. **Reboots can silently undo the komorebi layout**: Windows 11 can re-launch a bare `komorebi.exe` (plus AHK/YASB) at sign-in via "restart apps" before/without the autostart script, and komorebi's IPC socket can lag on a busy boot. The autostart handles both: it starts AHK/YASB first (they never wait on the WM), then starts komorebi with retries over a ~240 s backoff window until `komorebic state` answers — adopting an instance that is already up rather than starting a second one — re-applies the layout, and logs every attempt to `%USERPROFILE%\komorebi-autostart.log`. If the layout is missing after a reboot, read that log first: the `[warn] komorebi start attempt n/9 failed (...)` lines carry the reason (see gotcha 17).
9. **`komorebic border-offset -1` fails**: `-1` is parsed as a flag; use `border-offset -- -1` (the autostart already does).
10. **Focus-follows-mouse is komorebi-native**: the autostart starts `komorebi.exe --ffm` and enables `focus-follows-mouse -i komorebi`, which focuses only managed windows. An AHK `WinActivate` polling timer (the old approach) made every context menu close instantly by activating the menu's `#32768` popup window — if menus break again, check no AHK timer is competing with komorebi's FFM.
11. **YASB hides on real fullscreen only**: `hide_on_fullscreen: true` (requires `always_on_top: true`) drops the bar to `HWND_BOTTOM` via the `ABN_FULLSCREENAPP` appbar notification — browser fullscreen video and exclusive-fullscreen games hide it, but borderless-windowed games do not (YASB limitation). If a fullscreen app stays under the bar, it is either a maximized window (not fullscreen) or borderless windowed.
12. **Windows Terminal rewrites `settings.json` while it is running**: editing the file live is fine (WT hot-reloads it), but WT also *materialises* dynamic profiles during that reload. Installing Nushell made WT add a second, auto-generated "Nushell" profile (`"source": "nu"`) next to the static one from this repo — the menu then shows two. Keep the repo's static profile visible and set `"hidden": true` on the auto-generated one: the dynamic entry cannot be deleted, only hidden.
13. **`windows/win-terminal/settings.json` is a snapshot, not a portable fragment**: it embeds per-machine dynamic profiles (WSL distro names, Visual Studio versions) and a machine-local `defaultProfile` GUID. On a new machine, merge the Nushell profile into the existing file instead of copying this one wholesale.
14. **`Terminal-Icons` is required by the PowerShell profile and is not a winget package**: without `Install-Module Terminal-Icons -Scope CurrentUser` the profile throws on every shell start.
15. **`komorebic` must be on `PATH` for YASB**: the komorebi MSI adds `C:\Program Files\komorebi\bin\` to the machine `PATH`, and YASB's `komorebi_workspaces` widget shells out to `komorebic.exe`. In a shell that predates the install (or a fresh CI-like environment) the widget logs `Komorebi failed to subscribe named pipe` and shows offline tiles. New logon, or add the directory manually.
16. **A missing Windows Installer cache makes an MSI uninstallable**: `whkd` (the pre-AHK hotkey daemon) refused to uninstall with MSI error `1612` after its cached package disappeared from `C:\Windows\Installer`; force-recaching the same MSI failed with `1603`. The files and the ARP entry survive unless the registry key is removed by hand. Disk cleaners that purge `C:\Windows\Installer` are the usual culprit.
17. **komorebi can die instantly if `AllowSetForegroundWindow` fails, and it fails silently**: `komorebi/src/main.rs` retries `AllowSetForegroundWindow` five times and then `bail!`s, so `komorebi.exe` exits immediately and `komorebic state` never answers. Two details make this hard to diagnose, both verified against `v0.1.41` **and `master`**: the five retries have **no delay between them** (in practice a single instant attempt), and the loop runs **before `setup(opts.log_level)`**, so a failed start writes nothing to `%TEMP%\komorebi.log.<date>` — the signature is "no log entries at all, no `Application` error event, no `CrashDumps` entry". Upstream had not changed this at the time of writing, so **do not expect a version bump to fix it**. Seen here at the 2026-10-05 17:40 logon, twice during the port (13:27, 13:28; a plain retry succeeded at 13:30), and at the 2026-10-06 logon (10:01:54 / 10:01:57 / 10:02:00, boot 09:59:49). Why it is a *logon-only* failure: `AllowSetForegroundWindow` only succeeds when the caller may already set the foreground window, and Microsoft's conditions — the caller is/was started by the foreground process, received the last input event, or the foreground lock timeout (`HKCU\Control Panel\Desktop\ForegroundLockTimeout` → `SPI_GETFOREGROUNDLOCKTIMEOUT`, default `200000` ms) has expired — are all false for a startup-folder chain a couple of seconds after logon. The gate only opens on user input or after ~200 s, so any launcher must outlast that blind window. `komorebi-autostart.ps1` therefore starts AutoHotkey and YASB first (they never wait on the WM — YASB's komorebi widget reconnects by itself, verified in `yasb.log`), then retries the launch across ~240 s with backoff (9 attempts, sleeps 5/10/20/30/30/30/30/30 s), tells "process exited" apart from "not answering yet", adopts an instance that already answers (restarting it only to enforce `--ffm`), redirects komorebi's stdout/stderr to `%TEMP%\komorebi.out` and `%TEMP%\komorebi.err`, and re-applies the layout whenever komorebi finally answers. The call only succeeds when the caller may itself set the foreground window, which is why it is sensitive to the launch context; upstream's own retry loop (`46d5ea4`, added for exactly this "sporadically fail") has no delay and is effectively a single attempt — issue #683 ("Auto Start is very unstable") is still open, and native autostart (`komorebic enable-autostart`) does not change the timing.
18. **The workspace count is verified against the monitors komorebi reports**: `$monitors` in `komorebi-autostart.ps1` is a *superset* of monitor indexes (configuring an index that does not exist fails silently), so the verification must compare against `state.monitors`. It used to compare against that list and therefore logged `[WARN] workspaces unexpected: 5 (expected 2x5)` at every logon on a single-monitor machine. Do not reintroduce a hardcoded monitor count there: a log that always warns is a log nobody reads, and that log is the first thing to read when the layout is missing.
19. **An app's *child* windows can get tiled, leaving a hole in the layout**: komorebi has managed Zen/Firefox child windows — `ReunionWindowingCaptionControls` (the caption-button layer) and `InputNonClientPointerSource` (the non-client input sink) — as if they were user windows. A tiled child window cannot paint inside its tile (it is clipped to its parent, and komorebi parks it off-screen), so the workspace shows a large empty area while the real windows are squeezed into the rest: on 2026-10-05 workspace 2 gave the caption child the whole left half and pushed Ferdium and Zen into the right half. Signature of the family: style `WS_CHILD` and `GetAncestor(hwnd, GA_ROOT) != hwnd` (both suspicious windows had `GA_ROOT` = the Zen main window). Fix: add the class to the `ignore-rule class` list in the autostart **and clear the dumped state**. The rules only apply to windows managed *after* they are set, and a plain restart is **not enough**: komorebi re-applies `%TEMP%\komorebi.state.json` on start, so the wrongly-managed containers come straight back (verified 2026-10-05 — the dump still listed both child hwnds and resurrected them after the rules were in place). Recovery: `komorebic stop`, delete that file, start again. Find the class with `windows/komorebi/spy-dialog.ps1` while the broken workspace is on screen.
20. **fnm needs a hand-written Nushell hook, and `nu -c` will not show it**: fnm 1.39
    has no `--shell nushell` target and `fnm env --json` reports only the `FNM_*`
    variables, with no `PATH`, so `env.nu` loads the JSON and prepends
    `FNM_MULTISHELL_PATH` itself. Verify it in an *interactive* Nushell tab:
    `nu -c '<command>'` never loads `env.nu`, so a command-mode check misleadingly
    reports the pre-existing `node`. For scripted checks use
    `nu --env-config <path>/env.nu -c 'node --version'`.

## Revert

Delete the destination files listed in `MANIFEST.md` (optionally uninstall the
winget prerequisites listed there). Nothing here modifies what was previously on
the machine.

---

## License

Unlicensed: use freely, attribute if you share. No warranty.
