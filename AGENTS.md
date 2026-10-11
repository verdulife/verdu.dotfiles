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
- Windows: first install the winget prerequisites listed at the top of the
  manifest (one-time, manual).
- After copying: sign in once (or run `%USERPROFILE%\komorebi-autostart.ps1`).

## Revert

Delete the destination files from the manifest.

## Health checks

```powershell
komorebic state
Get-Process komorebi,yasb,AutoHotkey64
Get-Content "$HOME\.config\yasb\yasb.log" -Tail 20
Get-Content "$HOME\komorebi-autostart.log" -Tail 10   # "[ok] config applied: ..." = the static config took effect
```

## Key invariants (do not break)

- **komorebi border formula**: visible inset =
  `workspace_padding + container_padding + (border_width + border_offset)`.
  The values live in `windows/komorebi/komorebi.json`; `windows/komorebi/README.md`
  documents the formula; editing them shifts tile↔bar alignment.
- **YASB restarts** after style/config edits — that's how edits take effect.
- **Nerd Font family = "JetBrainsMono NF"** (Propo = `NFP`, use first for icons).
- **`mouse_follows_focus` stays OFF**; **focus-follows-mouse is the `masir` daemon**
  (the autostart starts it once komorebi is ready; it reads komorebi's managed-window
  file and only raises managed tiles). Do not go back to komorebi's `--ffm` (its mouse
  hook dies after a fullscreen video and a toggle cannot reinstall it) nor to an AHK
  polling timer (it killed context menus by activating their `#32768` popup).
- **komorebi configuration lives in `windows/komorebi/komorebi.json`** (monitors,
  `display_index_preferences`, paddings, borders, colours, ignore/manage rules),
  applied by komorebi itself with `--config`. `komorebi-autostart.ps1` only supervises
  (retry, state-dump guard, ordering, verification, log) and re-applies nothing; it
  duplicates `resize_delta` and the workspace count purely as verification
  expectations, so keep those two in sync with the JSON.
- YASB widget validation is strict; keep required keys (`power_menu` needs
  `shutdown`, `restart`, `cancel`).

## Where to edit what

| Want to change | File |
|---|---|
| WM hotkeys, taskbar, Win key | `windows/komorebi/komorebi.ahk` |
| Workspaces/gaps/borders/colours, monitors, dialog & manage rules | `windows/komorebi/komorebi.json` (+ `spy-dialog.ps1` repo-only to discover dialog classes) |
| Logon order, retry window, per-process guards, verification | `windows/komorebi/komorebi-autostart.ps1` |
| Bar widgets/groups/pill look | `windows/yasb/config.yaml` + `styles.css` |
| Prompt | `shared/starship.toml` |
| Neovim | `shared/nvim/` |

## Workflow

1. Clone; copy per `MANIFEST.md`.
2. Verify with the health checks.
3. If you change a config in the repo, update the file AND the relevant README,
   then re-copy that single file on the target machine.

## Rules

- **Commit directly to `main` — do not create feature branches.** This is a personal
  repo and it does not warrant them (user decision, repeated). Keep history linear
  and fast-forward; a one-commit detour belongs on `main` too. Push stays the user's
  decision.
- No secrets: no tokens/keys.
- Keep the README's "Gotchas" list honest — append when you discover something.
- Commit logical units with conventional messages.