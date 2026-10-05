# Apply verdu.dotfiles to this machine

Status: done — tasks 1-13 complete, task 14 blocked on a user decision
Repo: `C:\Users\verdu\verdu.dotfiles`, branch `chore/apply-dotfiles-port` (5 commits)
Date: 2026-10-05
Backup: `C:\Users\verdu\dotfiles-backup-20261005-130613` (see its `MANIFEST.txt`)

## Goal

Bring this PC to parity with the repo's Windows stack: install the missing
prerequisites, copy every file in `MANIFEST.md`, update the files that have
drifted, and remove the legacy leftovers that the repo replaces.

## Non-goals

- No Linux (`linux/` folders stay placeholders).
- No push, PR, or merge: those stay the user's decision.
- `%LOCALAPPDATA%\nvim-data` (172 MB of plugins) is not part of the manifest and
  was not touched.

## Environment facts (verified)

| Item | State on this PC |
|---|---|
| Installed before | `bat`, `lazygit`, `Neovim 0.12.4`, `starship 1.26.0`, Herdr, JetBrainsMono NF fonts |
| Installed during this work | `komorebi 0.1.41`, `AutoHotkey v2` (user scope), `yasb 2.0.7`, `Nushell 0.116.1`, `zoxide`, `atuin`, `carapace`, `fzf`, `jq` |
| Installed during this work (non-winget) | PowerShell module `Terminal-Icons 0.11.0` |
| `whkd` + `~/.config/whkdrc` | `whkdrc` deleted; **the `whkd` package is not uninstallable** (see Blockers) |
| `%LOCALAPPDATA%\nvim` | was a `LazyVim/starter` clone; replaced with `shared/nvim/` |
| `~/komorebi.json`, `~/komorebi.bar.json` | deleted (stale June leftovers) |

## Decisions (confirmed with the user)

1. **nvim** — replace `%LOCALAPPDATA%\nvim` with the repo's `shared/nvim/`;
   backup first, starter clone not kept in place.
2. **Windows Terminal** — merge. Add the repo's Nushell profile and colour
   scheme, keep the local profiles (`archlinux`, `Multipass`, `VS 18`).
3. **PowerShell** — adopt the repo's profile split and re-add the three
   local-only functions: herdr auto-attach, `godot` launcher, and `ya` (yazi).
4. **Legacy** — delete `whkd`, `~/.config/whkdrc`, `~/komorebi.json`,
   `~/komorebi.bar.json`, and `Microsoft.PowerShell_profile.ps1.bak-20261001`,
   each with a backup.

### Sub-decisions taken during implementation

- **Scheme name reused, no duplicate added.** The repo's `Catppuccin-Mocha`
  scheme is colour-identical to the local `Catppuccin Mocha`; only the name
  differs (hyphen vs space). The Nushell profile points at the existing local
  name instead of adding a redundant second entry to the picker.
- **Dynamic Nushell duplicate hidden.** On reload, Windows Terminal
  materialised an auto-generated Nushell profile (`source: "nu"`). The repo's
  static profile stays visible and carries the scheme/padding/scrollbar; the
  dynamic one is `hidden: true`.
- **Local `themes`, `initialCols`/`initialRows` kept.** The repo's copies differ
  and changing them is a visual regression the user did not ask for.
- **`godot` migrated with a caveat.** Godot is no longer installed on this
  machine, so the function's hardcoded path is stale. It is kept (the user asked
  for all three functions) with a comment marking the path as stale.

## Tasks

| # | Task | Status |
|---|---|---|
| 1 | Back up every existing destination | done — 8/8 byte-identical, nvim 44/44 |
| 2 | Install missing winget prerequisites | done — 9/9, all at the paths the repo expects |
| 3 | Copy the shell layer (`nushell/*.nu`, `starship.toml`) | done — 3/3 byte-exact |
| 4 | Copy the PowerShell layer with the three functions | done — syntax OK, functions/aliases verified |
| 5 | Copy `windows/herdr/config.toml` | done — byte-exact, `nu.exe` target exists |
| 6 | Replace `%LOCALAPPDATA%\nvim` | done — trees identical, 42/42 |
| 7 | Merge the Windows Terminal settings | done — 1 visible Nushell, locals kept |
| 8 | Copy the komorebi layer | done — 3/3 byte-exact, AHK validates |
| 9 | Copy the YASB layer | done — byte-exact, all widgets load |
| 10 | Run `setup-autoloads.nu` | done — 4 autoloads regenerated |
| 11 | Remove the legacy leftovers | partial — 4 files deleted; package blocked |
| 12 | Back-port into the repo (files + README/MANIFEST) | done |
| 13 | Start the stack and run the health checks | done — stack up, all checks pass |
| 14 | Resolve the `whkd` package removal | **blocked** — see below |

## Task 13 verification (the stack is running)

| Check | Result |
|---|---|
| `komorebic state` | OK, JSON parses |
| Monitors / workspaces | 1 (DISPLAY1) × 5 workspaces, focused index 0 |
| Processes | `komorebi(13924)`, `AutoHotkey64(5936)`, `yasb(15184)` |
| `is_paused` | `False` |
| `resize_delta` | `25` (layout applied) |
| Native taskbar | `Shell_TrayWnd` visible = **False** (hidden by the AHK watchdog) |
| YASB bar | window present, visible |
| `yasb.log` | 0 ERROR lines; `Komorebi connected to named pipe` |
| `komorebi-autostart.log` | `[ok] komorebi ready` |
| Startup `.vbs` | present, so the stack also starts at logon |

### Two findings recorded on the way

1. **First two launches aborted with `failed call to AllowSetForegroundWindow after
   5 retries`.** `komorebi.exe` exited immediately and `komorebic state` panicked
   with `os error 10050`. It happened through both a direct `Start-Process` and the
   Startup `.vbs` logon path. It is **not reproducible**: after one successful
   `cmd /c start` launch, all five launch forms succeeded (`hidden`, `normal`,
   `minimized`, `cmd start`, `-NoNewWindow`). `ForegroundLockTimeout` is at the
   Windows default `200000`, which lets a background process refuse the grant, but
   the transient nature is unexplained and is recorded as such rather than
   attributed.
2. **`[WARN] workspaces unexpected: 5 (expected 2x5)`** is a false alarm: this
   machine has one monitor, so 5 workspaces is correct. The layout still applied.
3. **YASB's komorebi widget needs `komorebic` on `PATH`.** It logged
   `Komorebi failed to subscribe named pipe` while launched from a shell whose
   `PATH` predated the install; relaunching with the machine `PATH` produced
   `Komorebi connected to named pipe`. At logon the machine `PATH` is already
   complete, so this is a non-issue for the real startup path.

## Blockers

**`whkd` cannot be uninstalled (MSI error 1612).** Its Windows Installer cache is
gone, so `msiexec /x` cannot find the source. Three attempts failed:
`winget uninstall` (48/1612), `winget uninstall --force` (48/1612), and
`msiexec /i <same msi> REINSTALL=ALL REINSTALLMODE=vomus` (1603, after which both
`/x <msi>` and `/x {product}` still returned 1612). The product codes match, so
the MSI is the right one. Left behind: `C:\Program Files\whkd\` (2 files) and an
ARP entry. Manual cleanup means deleting that directory plus the registry key
`HKLM\...\Uninstall\{96B2D7B2-62E0-425E-B9F3-998667C147A4}` — not done without
an explicit decision. Functionally `whkd` is already neutralised: it is not
running and its config file is gone.

## Evidence log

- Task 1 — backup at `~/dotfiles-backup-20261005-130613`; `cmp` 8/8 identical,
  nvim 44/44 files.
- Task 2 — `winget list` shows all 9; `komorebic --version` = 0.1.41;
  `C:\Program Files\komorebi\bin\`, `C:\Program Files\yasb\` on the machine PATH.
- Task 3 — `cmp` byte-exact x3; `starship print-config` parses; `nu --version` = 0.116.1.
- Task 4 — `Parser::ParseFile` clean; `Get-Command ya,godot,sudo,Get-ScriptDirectory`
  and `Get-Alias ll,g,vim` all resolve.
- Task 5 — `cmp` byte-exact; `default_shell` resolves to an existing `nu.exe`.
- Task 6 — `diff -r` identical; no `.git` left.
- Task 7 — 11 profiles, exactly 1 visible `Nushell`, `defaultProfile` = Nushell,
  local profiles intact; globals survived a Windows Terminal reload.
- Task 8 — `cmp` byte-exact x3; `AutoHotkey64.exe /validate` exit 0;
  `Parser::ParseFile` clean.
- Task 9 — `cmp` byte-exact x2; YASB's own log shows every widget loading with
  zero validation errors.
- Task 10 — `setup-autoloads.nu` printed 4 checkmarks; 4 non-empty `.nu` files.
- Task 11 — 4 files verified in the backup and deleted; `whkd` blocked.
- Task 12 — see the commits on the feature branch.

## Follow-ups

1. **nvim plugin sync**: the repo lockfile pins 71 plugins, 37 are installed.
   First `nvim` launch installs the missing 34; `:Lazy restore` is the
   reproducible path.
2. **Stale Godot entry in the user `PATH`**:
   `...\WinGet\Packages\GodotEngine.GodotEngine_..._8wekyb3d8bbwe` no longer
   exists. Removing a PATH entry was not part of this plan.
3. **`whkd` removal** — needs a decision (see Blockers).
4. **Optional:** make the autostart's workspace check compare against
   `monitors × 5` instead of a hardcoded `2x5`, to stop the false warning on
   single-monitor machines.
