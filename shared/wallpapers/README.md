# Wallpapers

The media the desktop actually uses, kept here so a rebuilt machine does not have
to hunt it down again. **This folder is the source of truth**; each OS's wallpaper
engine keeps its own working copy elsewhere (see the OS sections).

No LFS, no archive step: files stay small enough for plain Git — the current set
is about 1.9 MB.

## Current set

| File | Kind | Notes |
|---|---|---|
| `beach-house-in-japan.1920x1080.mp4` | video (H.264, 1920x1080) | the wallpaper running on both machines |

## Why this lives in `shared/`

The media is not OS-specific. Windows plays it with Lively Wallpaper and Linux
(Omarchy) plays it with OWE; both read the same file. Only the *engine* differs,
so each engine's documentation stays under its OS folder:

- Windows → `../../windows/wallpapers/README.md` (Lively: which build, where its
  library lands, and the two "start with Windows" switches)
- Linux → this file, below.

## Copy destination

`MANIFEST.md` is the contract; in short:

| OS | Destination |
|---|---|
| Windows | `%USERPROFILE%\Pictures\Wallpapers\<file>` |
| Linux | `~/Wallpapers/<file>` |

The file is a single-file copy on both sides — nothing recursive, no symlink.

## Applying it on Linux (Omarchy)

Omarchy does **not** use `hyprpaper`, `swww` or `swaybg`; none of them is even
installed here. Its Quickshell shell draws still images only, and **video is drawn
by OWE**, which owns a separate layer and transcodes GIFs. The shell deliberately
leaves its own background layer empty behind a video so OWE's layer shows through.

```bash
omarchy-theme-bg-set ~/Wallpapers/beach-house-in-japan.1920x1080.mp4
```

That repoints `~/.local/state/omarchy/current/background` and notifies the shell.
Any file is accepted. The pickers (`omarchy-theme-bg-switcher`,
`omarchy theme bg next`) filter to
`jpg jpeg png gif bmp webp mp4 m4v mov webm mkv avi`.

### Caveats worth knowing before chasing a bug

- **A theme switch replaces it.** `omarchy theme set <name>` and
  `omarchy theme bg next` repoint the same symlink, so re-run the command after
  changing theme. That is the engine's normal behaviour, not a defect.
- **The lock screen never plays video.** It extracts a still poster with
  `ffmpegthumbnailer` and caches it next to the lock plugin.
- **Two monitors: the video is per output, not spanned.** Verified on this
  two-monitor Omarchy machine (2026-11-12): OWE draws the **full frame on each
  screen** instead of stretching one video across the virtual desktop. So a 16:9
  video is the right shape here, and a wide "span" composition would only show
  the same full frame twice. Stills behave differently — the shell centre-crops
  per screen — but neither path has a span mode, so one image across two outputs
  is not something this stack supports.
- **Playback tuning is not tracked.** Pausing rules and transcode limits live in
  OWE's own `~/.config/owe/config.toml` (`[pause]`, `[transcode]`), which is
  machine-local and rewritten by the app — only the media file is versioned.
