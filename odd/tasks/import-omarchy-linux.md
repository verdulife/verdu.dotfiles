# Import the Linux side: Omarchy shell config

Status: in progress
Repo: `~/Projects/verdu.dotfiles`, branch `main`
Date: 2026-11-12
Machine: Omarchy 4.0.0.alpha (Arch + Hyprland + Quickshell), kernel from the Arch install

## Goal

Populate `linux/` with the configuration this machine actually runs, so a rebuilt
Arch machine reproduces it by copying files — the same contract as `windows/`.

## Non-goals

- No `linux/hyprland/`: `~/.config/hypr/` is byte-identical to
  `/usr/share/omarchy/config/hypr/`, so versioning it would freeze package
  defaults while adding zero personal decisions.
- No `linux/waybar/`: this machine has no waybar. The bar is `omarchy-shell`.
- No wallpaper media here — it already lives in `shared/wallpapers/`.
- No push, PR, or merge: those stay the user's decision.

## Environment facts (verified)

| Item | State on this machine |
|---|---|
| Omarchy | `4.0.0.alpha` (`/usr/share/omarchy/version`) |
| `~/.config/hypr/` | 9 files, all text-identical to `/usr/share/omarchy/config/hypr/` |
| Wallpaper engine | Quickshell plugin `omarchy.background` for stills; **OWE** for video; no hyprpaper/swww/swaybg installed |
| `~/.config/omarchy/shell.json` | full user copy (2083 B), 3 real deltas: clock format, `elsewhen` cities, `superwhisper.panel` in the tray |
| `~/.config/omarchy/shell.toml` | `[font] base-size = 12`, no packaged counterpart |
| `~/.config/omarchy/language` | `es-MX` |
| `~/.config/omarchy/defaults/` | `agent` → `opencode`, `dictation` → `superwhisper`, plus generated `dictation.lock` |
| `~/.config/omarchy/branding/` | `about.txt` (2734 B), `screensaver.txt` (1525 B) |
| `~/.config/omarchy/hooks/theme-set.d/` | one active hook `10-owe-sync` (393 B) + stock samples |
| `~/.config/omarchy/plugins/superwhisper-panel` | **symlink** → `/opt/superwhisper/assets/omarchy-plugin/superwhisper-panel` (root-owned, package-shipped) |
| `~/.config/omarchy/themes/wallhaven-jerw1y/` | Aether-generated (`.aether-managed`, generated `colors.toml`, 3500×1748 JPEGs) |

## Specs

- **S1** — The Linux side must reflect what this machine runs: Omarchy/Hyprland,
  not a generic Arch + waybar layout.
- **S2** — `linux/hyprland/` is dropped. Hyprland config belongs to the package;
  the repo documents that instead of forking it.
- **S3** — `linux/omarchy-shell/` replaces `linux/waybar/` and holds only files
  that carry a personal decision.
- **S4** — Package-owned and generated files stay out: the `superwhisper-panel`
  symlink, the Aether theme, `defaults/dictation.lock`, stock `.sample` hooks and
  the stock `extensions/omarchy-menu.jsonc`.
- **S5** — The copy contract holds: no symlinks, no installers, and every imported
  file gets a `MANIFEST.md` row naming its exact destination.
- **S6** — Commit directly to `main`; pushing stays the user's decision.

## Tasks

| ID | Spec | What | Commit |
|---|---|---|---|
| T1 | S1, S3 | Restructure: drop `linux/hyprland/`, rename `linux/waybar/` → `linux/omarchy-shell/` | — |
| T2 | S3, S4 | Import `shell.json`, `shell.toml`, `language`, `defaults/{agent,dictation}` | — |
| T3 | S3, S4 | Import `branding/{about.txt,screensaver.txt}` and `hooks/theme-set.d/10-owe-sync` | — |
| T4 | S3, S4 | Write `linux/omarchy-shell/README.md` and rewrite `linux/README.md` | — |
| T5 | S5 | Add the Linux rows to `MANIFEST.md` and the notes on what is never copied | — |
| T6 | S5 | Update `README.md` layout tree and `AGENTS.md` | — |
| T7 | S6 | Verify no stale references, commit on `main` | `feat(linux): import the Omarchy shell config` |

## Log

- **L1** (user): «ok, clona mi verdu.dotfile que hoy empezaremos a nutrir la parte
  de linux que estaba vacia»
- **L2** (user): «1» — choosing to populate `linux/` with what this Omarchy machine
  actually has, rather than keeping a generic Arch + waybar placeholder.
- **L3** (user): «ok dale» — approving the pivot from `linux/hyprland/` +
  `linux/waybar/` to `linux/omarchy-shell/`.
- **L4** (evidence): inventory of `~/.config/hypr/` and `~/.config/omarchy/`.
  Every Hyprland file is stock; the personal decisions live in `omarchy/`.
- **L5** (correction): `plugins/superwhisper-panel` is a symlink into
  `/opt/superwhisper/`, so it is package-owned, not user config. The first
  inventory pass proposed importing its 13 files — excluded instead.
- **L6** (evidence): `omarchy-theme-bg-set` only repoints the state symlink and
  notifies the shell; it does **not** notify OWE. `hooks/theme-set.d/10-owe-sync`
  is the only thing that pings the OWE daemon. Recorded in
  `shared/wallpapers/README.md`.
