# Wallpapers — the Windows engine

The media itself lives in `../../shared/wallpapers/` (it is not OS-specific and
Linux plays the same file through OWE). **This folder is documentation only**: how
Lively Wallpaper is built and where it keeps its own working copy, so a rebuilt
machine does not hunt for it again.

## Lively Wallpaper: which build, and where its data lands

Two builds exist and they keep the library in completely different places, so check
before hunting for it. `Get-AppxPackage *Lively*` settles it: a package means the
Store build, no package means the plain one.

| Build | Program | Library |
|---|---|---|
| **Win32** — what the home machine has (verified 2026-11-11) | `C:\Program Files\Lively Wallpaper\Lively.exe` | `%LOCALAPPDATA%\Lively Wallpaper\Library` |
| Microsoft Store (MSIX, `12030rocksdanister.LivelyWallpaper_97hta09mmv6hy`) | app package | **virtualized**: the path the app reports as `%LOCALAPPDATA%\Lively Wallpaper\Library` is really `%LOCALAPPDATA%\Packages\12030rocksdanister.LivelyWallpaper_97hta09mmv6hy\LocalCache\Local\Lively Wallpaper\Library` |

With the Store build the app reports the un-virtualized path and the file is not
there — that redirect is the only reason this table exists.

Inside the library, `SaveData\wptmp\<id>\` holds the **current** wallpaper: the media file
plus a generated thumbnail and a `LivelyInfo.json` (that one is `"Type": 7` for a
video). `WallpaperLayout.json` in the app folder records which `wptmp` entry is
active per monitor — that is how you find the current video if the name is not
obvious. Do not edit the package paths; Lively regenerates them.

To apply a file from the repo:

1. Copy `shared/wallpapers/<file>` to its manifest destination
   (`%USERPROFILE%\Pictures\Wallpapers\<file>`);
2. Lively → **Add wallpaper** → pick the file (video wallpapers can be added
   straight from disk, no zip needed);
3. Choose the monitor and confirm it appears under `Library\wallpapers\`.

`WallpaperScaling` and the rest of the engine settings are **not** tracked here:
they belong to Lively's own `Settings.json`, which is machine-local and rewritten
by the app. Only the media files are versioned.

## Start with Windows

There are **two** switches, and the second one silently overrides the first:

- `HKCU\Software\Microsoft\Windows\CurrentVersion\Run` → `Lively` =
  `"C:\Program Files\Lively Wallpaper\Lively.exe"` (what the app's own toggle writes);
- `HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run` →
  `Lively`, a 12-byte blob whose **first byte decides**: `02` enabled, `03` disabled
  (the other eight bytes record when it changed).

On 2026-11-11 the `Run` value was there but the blob began with `03`, so Lively
never started at logon — the app had been disabled once in Task Manager → Startup
apps, and that state survived. Enabling it was writing `02 00 00 00` plus eight zero
bytes to that value (exactly what that Task Manager toggle does). To disable it
again, use the toggle or write `03 00 00 00` followed by the current FILETIME;
removing the `Run` value alone does work, but the leftover blob is what makes a
reinstall come back disabled.

## Linux

Not here — see `../../shared/wallpapers/README.md`.
