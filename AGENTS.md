# AGENTS — fast path

You are an agent working with this dotfiles repo. This file is the compressed
version of README.md; read README.md for depth, this for procedure.

## What this repo is

Portable personal configuration: a Windows tiling-desktop stack (komorebi +
AutoHotkey + YASB + Windows Terminal + PowerShell) and shared tools (Starship,
Neovim). Linux folders are placeholders until the Arch configs land.

## Commands that matter

```powershell
# install on Windows (idempotent)
powershell -ExecutionPolicy Bypass -File windows\install\setup.ps1

# rollback
powershell -ExecutionPolicy Bypass -File windows\install\cleanup.ps1

# health checks
komorebic state                       # WM alive + layout JSON
Get-Process komorebi,yasb,AutoHotkey64
Get-Content "$HOME\.config\yasb\yasb.log" -Tail 20
```

## Key invariants (do not break)

- **komorebi border formula**: visible inset =
  `workspacePadding + containerPadding + (borderWidth + borderOffset)`.
  The autostart PS1 documents it inline; edits here shift tile↔bar alignment.
- **YASB restarts** after style/config edits — that's how edits take effect.
- **Nerd Font family = "JetBrainsMono NF"** (Propo = `NFP`, use first for icons).
- **`mouse_follows_focus` stays OFF** — focus-follows-mouse lives in AHK and
  would fight the cursor warp.
- YASB widget validation is strict; keep required keys (`power_menu` needs
  `shutdown`, `restart`, `cancel`).

## Where to edit what

| Want to change | File |
|---|---|
| WM hotkeys, FFm, taskbar, Win key | `windows/komorebi/komorebi.ahk` |
| Workspaces/gaps/borders/colours | `windows/komorebi/komorebi-autostart.ps1` |
| Bar widgets/groups/pill look | `windows/yasb/config.yaml` + `styles.css` |
| Prompt | `shared/starship.toml` |
| Neovim | `shared/nvim/` |

## Workflow for adding a machine

1. `git clone`; run `setup.ps1` (Windows) or copy `shared/` (Linux).
2. Verify with the health checks above.
3. If you change a config here, update both the file and the relevant README,
   then re-run `setup.ps1` on the target machine (copies, not symlinks).

## Rules

- No secrets: no tokens/keys — home configs are public-ready.
- Keep the README's "Gotchas" list honest — it is the accumulated hard-won
  knowledge; append when you discover something new.
- Commit logical units with conventional messages.