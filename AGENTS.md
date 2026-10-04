# AGENTS — fast path

Compressed version of README.md. Read README.md for depth; **read
MANIFEST.md to install** — it is the file→destination contract.

## What this repo is

Portable personal configuration: a Windows tiling-desktop stack (komorebi +
AutoHotkey + YASB + Windows Terminal + PowerShell) and shared tools (Starship,
Neovim). Linux folders are placeholders until the Arch configs land.

## Install = copy, per MANIFEST.md

No installers, no symlinks. For each row in `MANIFEST.md`:

- `copy <repo-file> <destination>` — exact paths, do not invent.
- `shared/nvim/` is the only recursive copy.
- Windows: first install the four winget prerequisites (listed at the top of
  the manifest — one-time, manual).
- After copying: sign in once (or run `%USERPROFILE%\komorebi-autostart.ps1`).

## Revert

Delete the destination files from the manifest.

## Health checks

```powershell
komorebic state
Get-Process komorebi,yasb,AutoHotkey64
Get-Content "$HOME\.config\yasb\yasb.log" -Tail 20
Get-Content "$HOME\komorebi-autostart.log" -Tail 10   # "layout applied" = config took effect
```

## Key invariants (do not break)

- **komorebi border formula**: visible inset =
  `workspacePadding + containerPadding + (borderWidth + borderOffset)`.
  The autostart PS1 documents it inline; edits here shift tile↔bar alignment.
- **YASB restarts** after style/config edits — that's how edits take effect.
- **Nerd Font family = "JetBrainsMono NF"** (Propo = `NFP`, use first for icons).
- **`mouse_follows_focus` stays OFF**; **focus-follows-mouse is komorebi-native**
  (autostart starts `komorebi.exe --ffm` and runs `focus-follows-mouse enable
  -i komorebi`, which focuses only managed tiles — an AHK polling timer used to
  kill context menus by activating their `#32768` popup).
- YASB widget validation is strict; keep required keys (`power_menu` needs
  `shutdown`, `restart`, `cancel`).

## Where to edit what

| Want to change | File |
|---|---|
| WM hotkeys, taskbar, Win key | `windows/komorebi/komorebi.ahk` |
| Workspaces/gaps/borders/colours, floating dialog rules | `windows/komorebi/komorebi-autostart.ps1` (+ `spy-dialog.ps1` repo-only to discover dialog classes) |
| Bar widgets/groups/pill look | `windows/yasb/config.yaml` + `styles.css` |
| Prompt | `shared/starship.toml` |
| Neovim | `shared/nvim/` |

## Workflow

1. Clone; copy per `MANIFEST.md`.
2. Verify with the health checks.
3. If you change a config in the repo, update the file AND the relevant README,
   then re-copy that single file on the target machine.

## Rules

- No secrets: no tokens/keys.
- Keep the README's "Gotchas" list honest — append when you discover something.
- Commit logical units with conventional messages.