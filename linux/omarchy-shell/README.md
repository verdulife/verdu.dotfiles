# omarchy-shell

The Omarchy shell (Quickshell) configuration: bar, tray, font size, language,
branding and the one hook that matters. Everything here maps to a file under
`~/.config/omarchy/` — see `MANIFEST.md` for the exact destinations.

This folder holds **only** files that carry a personal decision. Hyprland config,
themes and plugins are deliberately absent; `../README.md` explains why.

## What each file is

| File | Destination | What it controls |
|---|---|---|
| `shell.json` | `~/.config/omarchy/shell.json` | bar layout, dock pins, idle timings, tray widgets |
| `shell.toml` | `~/.config/omarchy/shell.toml` | shell font size (`[font] base-size = 12`) |
| `language` | `~/.config/omarchy/language` | locale the shell formats dates and numbers with (`es-MX`) |
| `defaults/agent` | `~/.config/omarchy/defaults/agent` | which agent the launcher opens (`opencode`) |
| `defaults/dictation` | `~/.config/omarchy/defaults/dictation` | which dictation engine the launcher opens (`superwhisper`) |
| `branding/about.txt` | `~/.config/omarchy/branding/about.txt` | ASCII letterform art shown by the "about" panel |
| `branding/screensaver.txt` | `~/.config/omarchy/branding/screensaver.txt` | ASCII art shown by the screensaver |
| `hooks/theme-set.d/10-owe-sync` | `~/.config/omarchy/hooks/theme-set.d/10-owe-sync` | pings the OWE daemon after a theme change (must stay executable) |

## `shell.json` is a full user copy, and that is on purpose

It is not a sparse patch: it is the complete file as this machine runs it, copied
verbatim. The only deltas against `/usr/share/omarchy/config/omarchy/shell.json`
are three:

1. clock format `"ddd d MMM HH:mm"` (packaged default: `"dddd HH:mm"`);
2. `omarchy.elsewhen` carries a `cities` array of five zones (Madrid, Dubai,
   Tokyo, Los Angeles, New York);
3. a `bar.layout.tray` entry for the `superwhisper.panel` widget.

**Consequence to remember:** because the whole file is pinned, upstream default
changes shipped by `omarchy update` will not reach this file. Re-diff it against
the packaged version after a major update and merge what you actually want.

## The OWE hook, and why it exists

Omarchy's video wallpapers are drawn by **OWE**, not by the shell (the shell draws
stills only and leaves its layer empty behind a video). `omarchy-theme-bg-set`
repoints the background symlink and notifies the *shell* — it does not notify OWE.
The `theme-set` hook is what pings the daemon:

```bash
printf '{"cmd":"refresh"}\n' | socat - "UNIX-CONNECT:$XDG_RUNTIME_DIR/owe/owed.sock"
```

So: change the theme and the video wallpaper re-syncs; change only the background
with `omarchy-theme-bg-set` and OWE may need that ping by hand. `socat` is a hard
dependency of the hook, and it does nothing when the socket is absent.

## What is never copied from here

- `defaults/dictation.lock` — a runtime lock, generated.
- Any `*.sample` under `hooks/` — packaged samples, inert, re-shipped by Omarchy.
- `extensions/omarchy-menu.jsonc` — stock on this machine (comments only).
- `themes/` and `plugins/` — Aether-generated and package-symlinked respectively.
