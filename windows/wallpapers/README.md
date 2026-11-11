# Wallpapers

The videos and images the desktop actually uses, kept here so a rebuilt machine
does not have to hunt them down again. **This folder is the source of truth**;
the wallpaper engine keeps its own working copy elsewhere (see below).

No LFS, no archive step: files stay small enough for plain Git.

## Current set

| File | Kind | Notes |
|---|---|---|
| `beach-house-in-japan.1920x1080.mp4` | video (H.264, 1920x1080) | the wallpaper running on this machine |

## Lively Wallpaper (Microsoft Store build)

Lively ships as an MSIX package here
(`12030rocksdanister.LivelyWallpaper_97hta09mmv6hy`), so its data directory is
**virtualized**: the path the app reports as
`%LOCALAPPDATA%\Lively Wallpaper\Library` is really

```
%LOCALAPPDATA%\Packages\12030rocksdanister.LivelyWallpaper_97hta09mmv6hy\LocalCache\Local\Lively Wallpaper\Library
```

Inside it, `SaveData\wptmp\<id>\` holds the **current** wallpaper: the media file
plus a generated thumbnail and a `LivelyInfo.json` (that one is `"Type": 7` for a
video). `WallpaperLayout.json` in the app folder records which `wptmp` entry is
active per monitor — that is how you find the current video if the name is not
obvious. Do not edit the package paths; Lively regenerates them.

To apply a file from this folder:

1. Copy it wherever it should live on the target (see `MANIFEST.md`);
2. Lively → **Add wallpaper** → pick the file (video wallpapers can be added
   straight from disk, no zip needed);
3. Choose the monitor and confirm it appears under `Library\wallpapers\`.

`WallpaperScaling` and the rest of the engine settings are **not** tracked here:
they belong to Lively's own `Settings.json`, which is machine-local and rewritten
by the app. Only the media files are versioned.
