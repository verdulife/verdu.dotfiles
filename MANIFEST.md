# Manifest — where every file goes

Copy-based dotfiles: each repo file maps to exactly one destination on the
target machine. **This file is the contract.** Copiar = `copy` the source to
the destination; never more, never less. No installer, no symlinks.

## Windows

Prerequisites (install once, manually, via winget — not part of the copy):

```
winget install -e --id LGUG2Z.komorebi
winget install -e --id AutoHotkey.AutoHotkey
winget install -e --id AmN.yasb
winget install -e --id DEVCOM.JetBrainsMonoNerdFont
winget install -e --id Nushell.Nushell --scope user
winget install -e --id Schniz.fnm
winget install -e --id ajeetdsouza.zoxide
winget install -e --id Atuinsh.Atuin
winget install -e --id rsteube.Carapace
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
| `windows/komorebi/komorebi.ahk` | `%USERPROFILE%\komorebi.ahk` |
| `windows/komorebi/komorebi-autostart.ps1` | `%USERPROFILE%\komorebi-autostart.ps1` |
| `windows/autostart/komorebi-autostart.vbs` | `%USERPROFILE%\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\komorebi-autostart.vbs` |
| `windows/yasb/config.yaml` | `%USERPROFILE%\.config\yasb\config.yaml` |
| `windows/yasb/styles.css` | `%USERPROFILE%\.config\yasb\styles.css` |
| `windows/win-terminal/settings.json` | `%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json` |
| `windows/powershell/Microsoft.PowerShell_profile.ps1` | `%USERPROFILE%\Documents\PowerShell\Microsoft.PowerShell_profile.ps1` |
| `windows/powershell/user_profile.ps1` | `%USERPROFILE%\.config\powershell\user_profile.ps1` |
| `shared/starship.toml` | `%USERPROFILE%\.config\starship.toml` |
| `shared/nvim/` (recursive) | `%LOCALAPPDATA%\nvim\` (Neovim's config dir on Windows — NOT `~/.config/nvim`) |
| `windows/nushell/config.nu` | `%APPDATA%\nushell\config.nu` |
| `windows/nushell/env.nu` | `%APPDATA%\nushell\env.nu` |
| `windows/herdr/config.toml` | `%APPDATA%\herdr\config.toml` |

> `windows/nushell/setup-autoloads.nu` is NOT copied; run it once after copying,
> from a shell where `nu`, `starship`, `zoxide`, `atuin` and `carapace` are on
> PATH, to regenerate `%APPDATA%\nushell\vendor\autoload\*.nu` (tool-generated,
> embeds per-machine paths):
>
> ```powershell
> nu %USERPROFILE%\verdu.dotfiles\windows\nushell\setup-autoloads.nu
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
- `windows/win-terminal/settings.json` is a full snapshot that carries
  per-machine dynamic profiles (WSL distro names, Visual Studio versions) and a
  machine-local `defaultProfile` GUID. On a different machine, **merge** it —
  add the Nushell profile and point `defaultProfile` at it — instead of copying
  it wholesale, or stale profiles come back. See README → Gotchas.
- `windows/powershell/user_profile.ps1` is dot-sourced by
  `Microsoft.PowerShell_profile.ps1`. Its destination directory
  (`%USERPROFILE%\.config\powershell\`) is not created by anything else, so
  create it first if the copy fails.