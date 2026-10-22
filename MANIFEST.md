# Manifest — where every file goes

Copy-based dotfiles: each repo file maps to exactly one destination on the
target machine. **This file is the contract.** Copiar = `copy` the source to
the destination; never more, never less. No installer, no symlinks.

## Windows

Prerequisites (install once, manually, via winget — not part of the copy):

```
winget install -e --id LGUG2Z.komorebi
winget install -e --id LGUG2Z.masir
winget install -e --id AutoHotkey.AutoHotkey
winget install -e --id AmN.yasb
winget install -e --id DEVCOM.JetBrainsMonoNerdFont
winget install -e --id Nushell.Nushell --scope user
winget install -e --id Schniz.fnm
winget install -e --id ajeetdsouza.zoxide
winget install -e --id junegunn.fzf
winget install -e --id sharkdp.bat
winget install -e --id jqlang.jq
winget install -e --id JesseDuffield.lazygit
winget install -e --id Neovim.Neovim
```

The PowerShell profile also imports a module that winget does not provide:

```powershell
Install-Module -Name Terminal-Icons -Scope CurrentUser -Force
```

| Repo file | Destination (Windows) |
|---|---|
| `windows/komorebi/komorebi.home.json` | `%USERPROFILE%\komorebi.json` (two-monitor machine only) |
| `windows/komorebi/komorebi.work.json` | `%USERPROFILE%\komorebi.json` (single-monitor machine only) |
| `windows/komorebi/komorebi.ahk` | `%USERPROFILE%\komorebi.ahk` |
| `windows/komorebi/komorebi-autostart.ps1` | `%USERPROFILE%\komorebi-autostart.ps1` |
| `windows/komorebi/container-dump.ps1` | `%USERPROFILE%\komorebi-container-dump.ps1` |
| `windows/komorebi/yasb-subscription.ps1` | `%USERPROFILE%\komorebi-yasb-subscription.ps1` |
| `windows/autostart/komorebi-autostart.vbs` | `%USERPROFILE%\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\komorebi-autostart.vbs` |
| `windows/yasb/config.yaml` | `%USERPROFILE%\.config\yasb\config.yaml` |
| `windows/yasb/styles.css` | `%USERPROFILE%\.config\yasb\styles.css` |
| `windows/yasb/opencode_go.py` | `%USERPROFILE%\.config\yasb\opencode_go.py` |
| `windows/yasb/pi_agents.py` | `%USERPROFILE%\.config\yasb\pi_agents.py` |
| `windows/yasb/pi-logo.png` | `%USERPROFILE%\.config\yasb\pi-logo.png` |
| `windows/yasb/opencode-logo.png` | `%USERPROFILE%\.config\yasb\opencode-logo.png` |
| `windows/yasb/cpu-icon.png` | `%USERPROFILE%\.config\yasb\cpu-icon.png` |
| `windows/yasb/ram-icon.png` | `%USERPROFILE%\.config\yasb\ram-icon.png` |
| `windows/yasb/gpu-icon.png` | `%USERPROFILE%\.config\yasb\gpu-icon.png` |
| `windows/win-terminal/settings.json` | `%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json` |
| `windows/powershell/Microsoft.PowerShell_profile.ps1` | `%USERPROFILE%\Documents\PowerShell\Microsoft.PowerShell_profile.ps1` |
| `windows/powershell/user_profile.ps1` | `%USERPROFILE%\.config\powershell\user_profile.ps1` |
| `shared/starship.toml` | `%USERPROFILE%\.config\starship.toml` |
| `shared/nvim/` (recursive) | `%LOCALAPPDATA%\nvim\` (Neovim's config dir on Windows — NOT `~/.config/nvim`) |
| `windows/nushell/config.nu` | `%APPDATA%\nushell\config.nu` |
| `windows/nushell/env.nu` | `%APPDATA%\nushell\env.nu` |
| `windows/herdr/config.toml` | `%APPDATA%\herdr\config.toml` |

> **Copy exactly one komorebi configuration.** `komorebi.home.json` on the two-monitor
> (home) machine, `komorebi.work.json` on the single-monitor (work) machine — both to
> `%USERPROFILE%\komorebi.json` — and **never the other one**. Tell the machines apart
> with `komorebic state`: `serial_number_id=CZK83705DT` is the work machine, the home
> machine maps `CNK51707R2` + `CNK6180S06`. Every key except `display_index_preferences`
> and `monitors` is shared and must stay identical in both variants;
> `windows/komorebi/tests/` fails when they drift. Details, including how to run it:
> `windows/komorebi/README.md`.

> `windows/nushell/setup-autoloads.nu` is NOT copied; run it once after copying,
> from a shell where `nu`, `starship` and `zoxide` are on PATH, to regenerate
> `%APPDATA%\nushell\vendor\autoload\*.nu` (tool-generated, embeds per-machine
> paths). atuin and carapace are deliberately not integrated — see
> `odd/tasks/nushell-native-line-editor.md`:
>
> ```powershell
> nu "<path-to-the-clone>\windows\nushell\setup-autoloads.nu"
> ```

After copying: sign out and in once (or run `%USERPROFILE%\komorebi-autostart.ps1`
once) so komorebi, the AHK hotkeys and YASB take effect. New Windows Terminal
tabs open Nushell (the default profile). See README → Verification.

## Linux

| Repo file | Destination (Linux) |
|---|---|
| `shared/starship.toml` | `~/.config/starship.toml` |
| `shared/nvim/` (recursive) | `~/.config/nvim/` |
| `linux/hyprland/*` (once populated) | `~/.config/hypr/` |
| `linux/waybar/*` (once populated) | `~/.config/waybar/` |

## Revert

Delete the destination files listed above. Nothing here changes what was on the
machine before.

## Notes for agents

- Destinations are exact; do not invent paths. `%USERPROFILE%` = the home dir.
- On Windows, Neovim reads `%LOCALAPPDATA%\nvim`, NOT `~/.config/nvim`; the
  manifest maps `shared/nvim/` there.
- The `windows/` mappings apply ONLY on Windows; `linux/` on Linux. `shared/` on both.
- `shared/nvim/` is a recursive copy; every other entry is a single file.
- `windows/nushell/setup-autoloads.nu` regenerates tool-generated files; it is
  run, not copied.
- After a config change in the repo, re-copy only the affected file.
- `odd/` is ODD work records (process history): never deployed, and never a source
  of truth — if a record disagrees with a config or with `README.md`, the config
  or `README.md` wins. The three documents the install path depends on are
  `MANIFEST.md` (where files go), `README.md` (what they do) and `AGENTS.md`.
- `windows/komorebi/spy-dialog.ps1`, `windows/komorebi/snapshot-wm.ps1` and
  `windows/komorebi/tests/` are **repo-only** tools (window-class spy, layout
  measuring, Pester tests for the deployed helpers and the drift gate that keeps the
  two komorebi variants' shared keys identical); they are never copied. The
  `windows/komorebi/` rows in the table above are the only komorebi files that get
  deployed.
- `windows/komorebi/komorebi.home.json` and `windows/komorebi/komorebi.work.json` are
  komorebi's **configuration** variants — one per machine, selected by the note under
  the table — and are applied by komorebi itself (`komorebi.exe --config`);
  `komorebi-autostart.ps1` is only the logon supervisor and does not re-apply them.
- `windows/win-terminal/settings.json` is a full snapshot that carries
  per-machine dynamic profiles (WSL distro names, Visual Studio versions) and a
  machine-local `defaultProfile` GUID. On a different machine, **merge** it —
  add the Nushell profile and point `defaultProfile` at it — instead of copying
  it wholesale, or stale profiles come back. See README → Gotchas.
- `windows/powershell/user_profile.ps1` is dot-sourced by
  `Microsoft.PowerShell_profile.ps1`. Its destination directory
  (`%USERPROFILE%\.config\powershell\`) is not created by anything else, so
  create it first if the copy fails.