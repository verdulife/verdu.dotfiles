# verdu.dotfiles

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
verdu.dotfiles/
├── MANIFEST.md           ← WHERE EVERY FILE GOES (the contract for copying)
├── README.md
├── AGENTS.md
├── odd/                  ← ODD work records: process history, never deployed
├── shared/
│   ├── starship.toml     ← Starship prompt (both OSes)
│   └── nvim/             ← Neovim config (LazyVim, lazy.nvim)
├── windows/
│   ├── komorebi/
│   │   ├── komorebi.json             ← the WM config: monitors, paddings, borders, rules
│   │   ├── komorebi.ahk              ← AHK v2: hotkeys, taskbar, Win key
│   │   ├── komorebi-autostart.ps1    ← logon supervisor: start, verify, log
│   │   ├── container-dump.ps1        ← refuses to replay a state dump komorebi must not
│   │   ├── snapshot-wm.ps1           ← repo-only: measure the layout before/after a fix
│   │   ├── spy-dialog.ps1            ← repo-only: discover a dialog's window class
│   │   ├── tests/                    ← repo-only: Pester tests for container-dump.ps1
│   │   └── README.md
│   ├── yasb/
│   │   ├── config.yaml               ← YASB v2 bar: widgets, groupers, pills
│   │   ├── styles.css                ← theme: transparent bar, black pills
│   │   └── README.md
│   ├── win-terminal/settings.json    ← Windows Terminal
│   ├── powershell/                   ← PS7 profile + user_profile.ps1
│   ├── nushell/                      ← Nushell config (+ setup-autoloads.nu: run, not copied)
│   ├── herdr/config.toml             ← Herdr (agent multiplexer)
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
- **Focus follows mouse** is the `masir` daemon (the autostart starts it once
  komorebi is ready): it reads komorebi's managed-window file, so it only raises
  windows komorebi manages and context menus/desktop/taskbar are never touched.
  komorebi's own `--ffm` FFM is EOL — Windows drops its mouse hook after a
  fullscreen video and a toggle cannot reinstall it (verified on v0.1.41) — and an
  earlier AHK-based version broke context menus by activating the menu's `#32768`
  popup.
- The **native taskbar is hidden** by an AHK watchdog (auto-hide leaves a 2 px
  sliver that reveals it; hiding the window kills the sliver). The YASB systray
  widget replaces the tray.
- A **dummy keystroke** (`~LWin::Send("{Blind}{vkE8}")`) stops the lone Super
  press from opening the Start menu; all `Super+letter` system shortcuts keep
  working.
- **Dialogs float**: `ignore_rules` in `windows/komorebi/komorebi.json` lists the
  common dialog classes (`#32770`, `TaskDialog`) and Zen's dialog shadow
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
Get-Process komorebi,masir,yasb,AutoHotkey64   # masir = focus-follows-mouse; if it is missing, FFM is dead
Get-Content "$HOME\komorebi-autostart.log" -Tail 5   # what the autostart did at logon, and why
Get-Content "$HOME\.config\yasb\yasb.log" -Tail 20
# sanity: the bar renders at the top; Super+arrows focuses tiles
```

## Customization knobs

- **Gaps / borders** (komorebi): `workspace_padding`, `container_padding`,
  `border_width`, `border_offset`, `border_colours` in
  `windows/komorebi/komorebi.json` — read the border formula first. Monitors and
  `display_index_preferences` live in the same file.
- **YASB look**: pill opacity `rgba(0,0,0,0.45)` in `styles.css` (` .widget`);
  widget set/order in `config.yaml` under `bars.status-bar.widgets`.
- **Focus follows mouse**: the `masir` daemon, started by the autostart; it only
  raises managed tiles. Never re-add an AHK polling loop for this.
- After editing a config, **re-copy that single file** to reinstall it.

## Gotchas (learned the hard way)

1. **komorebi border inset formula**: visible inset = `workspace_padding + container_padding + (border_width + border_offset)`. The border is *part of the geometry* — change it and the tile alignment with the bar shifts.
2. **Nerd Font family names and scope**: the JetBrains Nerd Fonts are installed **per user** here — files in `%LOCALAPPDATA%\Microsoft\Windows\Fonts`, registered under `HKCU`, with **zero** entries in `HKLM` and none in `C:\Windows\Fonts` — so elevated processes and other accounts do not see them. Windows Terminal only accepts a registered *family* name, and the valid ones are `JetBrainsMono NF`, `JetBrainsMono NFM`, `JetBrainsMono NFP` plus the `JetBrainsMonoNL …` variants. `"JetBrainsMonoNL Nerd Font"` — the value this repo used to ship — is **not** a family, and WT then falls back to its default font **silently**: no error in any log, the only symptom being missing or clipped prompt icons. A profile with **no** `font` key gets the WT default too. Which of those families exists is **per machine** — read `HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts` before choosing a face: one machine registers `NFM` and `NFP`, the other only `NFM`, so a face hardcoded from the other machine falls back silently (measured 2026-10-06: the home machine has `JetBrainsMono NFM` only, the work machine `NFM` and `NFP`). Use the family that is actually registered (`NFP` or `NFM`) first for icons so they don't clip, and set `font` explicitly on every profile you care about.
3. **`%#d`** (not `%-d`) is how Windows Python renders a day without a leading zero.
4. **No per-widget blur in YASB** (DWM limitation, confirmed by the maintainer): blur applies to whole windows; pills share one window.
5. **`mouse_follows_focus` must be OFF** (set in `komorebi.json`) or the cursor gets warped on every focus change and fights focus-follows-mouse.
6. **YASB rewrites its config files on reload**; after editing `styles.css` a YASB restart is the reliable way to see changes. Widget validation is strict (e.g., `power_menu` requires `shutdown`, `restart`, `cancel`).
7. Don't run `komorebic start` from within MSYS bash (it hangs there); use PowerShell `Start-Process` or the logon script.
8. **Reboots can silently undo the komorebi layout**: Windows 11 can re-launch a bare `komorebi.exe` (plus AHK/YASB) at sign-in via "restart apps" before/without the autostart script, and komorebi's IPC socket can lag on a busy boot. The autostart handles both: it starts AHK/YASB first (they never wait on the WM), then starts komorebi with retries over a ~240 s backoff window until `komorebic state` answers — adopting an instance that is already up rather than starting a second one — verifying the static config it applied, and logging every attempt to `%USERPROFILE%\komorebi-autostart.log`. If the layout is missing after a reboot, read that log first: the `[warn] komorebi start attempt n/9 failed (...)` lines carry the reason (see gotcha 17).
9. **`komorebic border-offset -1` fails**: `-1` is parsed as a flag; use `border-offset -- -1` on the CLI. In `komorebi.json` just write `"border_offset": -1` (which is what the repo ships).
10. **Focus-follows-mouse is the `masir` daemon**: the autostart starts `masir.exe` after komorebi answers, and it raises only windows listed in komorebi's managed-window file. komorebi's own `--ffm` was retired because Windows drops its per-process mouse hook once the callback stalls (a fullscreen video triggered it here on v0.1.41) and a disable/enable toggle cannot reinstall it; an AHK `WinActivate` polling timer (the approach before that) made every context menu close instantly by activating the menu's `#32768` popup window — if menus break again, check no AHK timer is competing with masir.
11. **YASB hides on real fullscreen only**: `hide_on_fullscreen: true` (requires `always_on_top: true`) drops the bar to `HWND_BOTTOM` via the `ABN_FULLSCREENAPP` appbar notification — browser fullscreen video and exclusive-fullscreen games hide it, but borderless-windowed games do not (YASB limitation). If a fullscreen app stays under the bar, it is either a maximized window (not fullscreen) or borderless windowed.
12. **Windows Terminal rewrites `settings.json` while it is running**: editing the file live is fine (WT hot-reloads it), but WT also *materialises* dynamic profiles during that reload. Installing Nushell made WT add a second, auto-generated "Nushell" profile (`"source": "nu"`) next to the static one from this repo — the menu then shows two. Keep the repo's static profile visible and set `"hidden": true` on the auto-generated one: the dynamic entry cannot be deleted, only hidden.
13. **`windows/win-terminal/settings.json` is a snapshot, not a portable fragment**: it embeds per-machine dynamic profiles (WSL distro names, Visual Studio versions) and a machine-local `defaultProfile` GUID. On a new machine, merge the Nushell profile into the existing file instead of copying this one wholesale.
14. **`Terminal-Icons` is required by the PowerShell profile and is not a winget package**: without `Install-Module Terminal-Icons -Scope CurrentUser` the profile throws on every shell start.
15. **`komorebic` must be on `PATH` for YASB**: the komorebi MSI adds `C:\Program Files\komorebi\bin\` to the machine `PATH`, and YASB's `komorebi_workspaces` widget shells out to `komorebic.exe`. In a shell that predates the install (or a fresh CI-like environment) the widget logs `Komorebi failed to subscribe named pipe` and shows offline tiles. New logon, or add the directory manually.
16. **A missing Windows Installer cache makes an MSI uninstallable**: `whkd` (the pre-AHK hotkey daemon) refused to uninstall with MSI error `1612` after its cached package disappeared from `C:\Windows\Installer`; force-recaching the same MSI failed with `1603`. The files and the ARP entry survive unless the registry key is removed by hand. Disk cleaners that purge `C:\Windows\Installer` are the usual culprit.
17. **komorebi can die instantly if `AllowSetForegroundWindow` fails, and it fails silently**: `komorebi/src/main.rs` retries `AllowSetForegroundWindow` five times and then `bail!`s, so `komorebi.exe` exits immediately and `komorebic state` never answers. Two details make this hard to diagnose, both verified against `v0.1.41` **and `master`**: the five retries have **no delay between them** (in practice a single instant attempt), and the loop runs **before `setup(opts.log_level)`**, so a failed start writes nothing to `%TEMP%\komorebi.log.<date>` — the signature is "no log entries at all, no `Application` error event, no `CrashDumps` entry". Upstream had not changed this at the time of writing, so **do not expect a version bump to fix it**. Seen here at the 2026-10-05 17:40 logon, twice during the port (13:27, 13:28; a plain retry succeeded at 13:30), and at the 2026-10-06 logon (10:01:54 / 10:01:57 / 10:02:00, boot 09:59:49). Why it is a *logon-only* failure: `AllowSetForegroundWindow` only succeeds when the caller may already set the foreground window, and Microsoft's conditions — the caller is/was started by the foreground process, received the last input event, or the foreground lock timeout (`HKCU\Control Panel\Desktop\ForegroundLockTimeout` → `SPI_GETFOREGROUNDLOCKTIMEOUT`, default `200000` ms) has expired — are all false for a startup-folder chain a couple of seconds after logon. The gate only opens on user input or after ~200 s, so any launcher must outlast that blind window. `komorebi-autostart.ps1` therefore starts AutoHotkey and YASB first (they never wait on the WM — YASB's komorebi widget reconnects by itself, verified in `yasb.log`), then retries the launch across ~240 s with backoff (9 attempts, sleeps 5/10/20/30/30/30/30/30 s), tells "process exited" apart from "not answering yet", adopts an instance that already answers, starts komorebi with its static config (`--config komorebi.json`), redirects komorebi's stdout/stderr to `%TEMP%\komorebi.out` and `%TEMP%\komorebi.err`, and verifies the applied configuration whenever komorebi finally answers. The call only succeeds when the caller may itself set the foreground window, which is why it is sensitive to the launch context; upstream's own retry loop (`46d5ea4`, added for exactly this "sporadically fail") has no delay and is effectively a single attempt — issue #683 ("Auto Start is very unstable") is still open, and native autostart (`komorebic enable-autostart`) does not change the timing.
18. **The workspace count is verified against the monitors komorebi reports**: the check multiplies `state.monitors` by `$expectedWorkspaces` from `komorebi-autostart.ps1`, never a fixed monitor count. The old code compared against a hardcoded `$monitors` list (a *superset* of monitor indexes — configuring an index that does not exist fails silently) and therefore logged `[WARN] workspaces unexpected: 5 (expected 2x5)` at every logon on a single-monitor machine. Do not reintroduce a hardcoded monitor count there: a log that always warns is a log nobody reads, and that log is the first thing to read when the layout is missing.
19. **An app's *child* windows can get tiled, leaving a hole in the layout**: komorebi has managed Zen/Firefox child windows — `ReunionWindowingCaptionControls` (the caption-button layer) and `InputNonClientPointerSource` (the non-client input sink) — as if they were user windows. A tiled child window cannot paint inside its tile (it is clipped to its parent, and komorebi parks it off-screen), so the workspace shows a large empty area while the real windows are squeezed into the rest: on 2026-10-05 workspace 2 gave the caption child the whole left half and pushed Ferdium and Zen into the right half. Signature of the family: style `WS_CHILD` and `GetAncestor(hwnd, GA_ROOT) != hwnd` (both suspicious windows had `GA_ROOT` = the Zen main window). Fix: the class list lives in `ignore_rules` in `komorebi.json` (komorebi enforces it) and is mirrored in `$ignoredClasses` in the autostart for the dump sanitizer and the post-start check, and three separate paths had to be closed, because the rules alone are **not** enough (verified 2026-10-06, with the symptom live): komorebi **replays `%TEMP%\komorebi.state.json` on start and a container restore BYPASSES every rule**; the `manage-rule exe zen.exe` was a nuclear force-manage that matched *every* `zen.exe` window, and a forced manage ignores the ignore rules; and the AHK rescue ran `komorebic manage`, which acts on whatever window is focused — Gecko hands foreground to its caption child in the same second the rescue activates the main window. So: `container-dump.ps1` (deployed) deletes an unsafe dump between `komorebic stop` and the start, the nuclear rule is replaced by the `object_name_change_applications` entry (`exe zen.exe`) in `komorebi.json` (Zen is Gecko-based and emits `EVENT_OBJECT_NAMECHANGE` on launch instead of a `Show`, which is the whole reason the force-manage rule and the rescue existed), and the AHK rescue timer itself was **removed on 2026-10-06** (it had fired zero times in 540 log events, and `komorebic manage` acts on the focused window, so it could tile a `WS_CHILD` helper of the app it was rescuing). Verified after the fix: a Ferdium cold start alone on a workspace holds **98%** of the work-area width, and no container anywhere is a `WS_CHILD`. Measure with `windows/komorebi/snapshot-wm.ps1` instead of reading `komorebic state` by eye — and never diagnose with the offending window already closed: three rounds were lost that way, because the containers were gone by the time anyone looked. Find new classes with `windows/komorebi/spy-dialog.ps1` while the broken workspace is on screen.
20. **fnm needs a hand-written Nushell hook, and `nu -c` will not show it**: fnm 1.39
    has no `--shell nushell` target and `fnm env --json` reports only the `FNM_*`
    variables, with no `PATH`, so `env.nu` loads the JSON and prepends
    `FNM_MULTISHELL_PATH` itself. Verify it in an *interactive* Nushell tab:
    `nu -c '<command>'` never loads `env.nu`, so a command-mode check misleadingly
    reports the pre-existing `node`. For scripted checks use
    `nu --env-config <path>/env.nu -c 'node --version'`.
21. **A window minimized with the native button keeps its container, and the next window opened on that workspace is squeezed**: verified on this build with the symptom live. On a workspace holding a visible Zen and a Windows Terminal minimized with the native button/taskbar, `komorebic state` keeps the minimized window as a container parked at `-31993,-32000` and Zen stays at **49%** of the work-area width while nothing else is on screen — the reported "the app opens at half, alone". Neither `komorebic retile` nor a workspace switch clears it; only restoring the minimized window does (both measured, `snapshot-wm.ps1` prints the share). This is upstream issue **#1730**, still open on `v0.1.41` and unrelated to the rules in gotcha 19 — do not try to fix it with `ignore-rule`s, the window is a real window. #1729 (`ghost_movement` default) is the same family, and no stable release fixes either yet. Workarounds: minimize with `komorebic minimize` instead of the titlebar/taskbar button — **Win+Shift+M**, already bound in `komorebi.ahk` — or clear it with a komorebi restart — which now also drops the bad dump, so the layout comes back clean. Consequence to expect: any session that ends with a minimized or natively parked window writes a dump the sanitizer refuses, so window-to-workspace placement is not restored at the next logon (the windows come back in the focused workspace). That is deliberate: a replayed dump is how the wrongly-managed containers come back.
22. **komorebi configuration has one home, and you can test it without logging out**: `windows/komorebi/komorebi.json` is applied by komorebi itself (`--config`), and the logon script only supervises and verifies. To prove a change on the running instance, run `komorebic replace-configuration "$HOME\komorebi.json"` and compare `komorebic state` (`komorebic check` validates the file in place) — that is how the migration was validated before the autostart was touched. Two values (`resize_delta`, workspace count) are duplicated in the script as verification expectations on purpose, so keep them in sync. Write `workspace_padding`/`container_padding` **per workspace**: the global `default_*_padding` keys work, but they leave `state` padding `null` (inherited), which makes the applied config unverifiable from `komorebic state`. And note that a `komorebi.json` workspace requires a `name` — the YASB dots use fixed glyphs, so names are invisible to the bar.

## Revert

Delete the destination files listed in `MANIFEST.md` (optionally uninstall the
winget prerequisites listed there). Nothing here modifies what was previously on
the machine.

---

## License

Unlicensed: use freely, attribute if you share. No warranty.
