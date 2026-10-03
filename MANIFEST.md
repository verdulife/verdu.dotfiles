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
| `shared/nvim/` (recursive) | `%USERPROFILE%\.config\nvim\` |

After copying: sign out and in once (or run `%USERPROFILE%\komorebi-autostart.ps1`
once) so komorebi, the AHK hotkeys and YASB take effect. See README → Verification.

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
- The `windows/` mappings apply ONLY on Windows; `linux/` on Linux. `shared/` on both.
- `shared/nvim/` is a recursive copy; every other entry is a single file.
- After a config change in the repo, re-copy only the affected file.