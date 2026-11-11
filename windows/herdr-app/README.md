# Herdr app mods

The two Herdr **app** mods that carry personal edits, kept here byte for byte so a
rebuilt machine does not lose them. **This folder is the source of truth** for
these two mods; the app only ever works on its own copy under the app home.

Only `files/` and `changes/` are versioned (see *Why only these two*). Everything
else the app writes stays on the machine.

## Where the app's home is

`HERDR_APP_HOME` can move it; when it is unset the home is
`%USERPROFILE%\.config\herdr-app` on Windows. The app itself prints that path in
`herdr-app --help`, where it reads `~/.config/herdr-app`.

It is **not** `%APPDATA%\herdr`. That directory belongs to the other Herdr (the
TUI) — see *Two plugin systems* below.

## What a mod is here

A mod is a folder holding `mod.json`, a `main.js` and whatever assets `main.js`
loads (here: SVG icons). The folders in `mods/` are copies of the mods the app
ships, and they are **editable in place**: the app refreshes files it shipped, but
a personal copy it finds in the home is left alone, so an edit survives restarts.

`mod.json` describes the mod. On this machine every folder in `mods/` carries
`"place": "none"`; some also declare a `title` and an `overlay` block (dialog or
popup with width/height). Both mods here are the minimal shape:

```json
{ "place": "none" }
```

Validate a mod folder with the app's own checker:

```powershell
herdr-app check "<home>\mods\files"
```

`main.js` paths inside a mod are relative to the app home, not to the mod folder:
`files/main.js` draws its icons as `svg("mods/files/folder.svg")`. That is why this
repo mirrors the home's layout (`windows/herdr-app/mods/<mod>/`) instead of
flattening it — copying a folder back to `<home>\mods\` restores it whole.

## Why only these two mods are versioned

The other 19 folders in `mods/` are still exactly the defaults the app ships. They
are not tracked here, because the app rewrites its shipped copies on start: a
versioned default would drift into a fork of the shipped mod with no edit to show
for it. `files` and `changes` are tracked because they *are* edited.

**Adding another mod means adding a row to `MANIFEST.md`** — the manifest is the
contract, and a mod folder with no row is not part of the copy.

## Two plugin systems — do not mix them up

| | app mods (this folder) | TUI plugins |
|---|---|---|
| Managed by | the Herdr desktop app | `herdr plugin install` |
| Directory | `%USERPROFILE%\.config\herdr-app\mods\` | `%APPDATA%\herdr` |
| Registry | none in this repo — files are copied per `MANIFEST.md` | `%APPDATA%\herdr\plugins.json` (`windows/herdr/plugins.json`) |
| Installable from GitHub | **no** | yes |

`files` and `changes` are app mods. They do not exist as TUI plugins and cannot be
installed with `herdr plugin install`; that command will never produce them.

## Never copied into the repo

Everything below lives in the same home and stays there: `installed.json`,
`view.json`, `window.json`, `share*.json`, `keys.json`, `herdr-app.sock`,
`telemetry/`, `frame/`, `update-notes*`, and the generated typings
(`gpui-kit.d.ts`, `herdr.d.ts`, `AGENTS.md`).

They are **machine-local state and generated artifacts** — which space was open,
window geometry, share targets, key bindings, the IPC socket, telemetry, the
rendered frame cache, the update notes. The app rewrites them at will and some are
megabytes (`gpui-kit.d.ts` is ~790 KB, `AGENTS.md` ~65 KB of generated API
reference). Versioning them would record one machine's state as if it were
configuration, and every rewrite would show up as a diff.

## The two mods

| Folder | Files | What it is |
|---|---|---|
| `files/` | `main.js`, `mod.json`, `chevron-down.svg`, `chevron-right.svg`, `file.svg`, `folder.svg` | a lazy file browser for the focused pane's folder, with bounded read-only previews. Lists at most 500 entries per folder and 5000 overall, refreshes on a 10 s timer plus a folder watch, and on a Windows pane lists through PowerShell (`[Console]::OutputEncoding` set to UTF-8 so names survive the console code page) instead of `sh` |
| `changes/` | `main.js`, `mod.json`, `changes.svg` | a git changes view with a commit box: it resolves the repo root with `git rev-parse --show-toplevel` and diffs the selected path against `HEAD` |

`changes/main.js` runs every git read with `--no-optional-locks -c
core.fsmonitor=false -c diff.autoRefreshIndex=false` on purpose: a plain `git
status` writes to `.git` (index refresh, fsmonitor cookie), the folder watch would
see that write, and every refresh would trigger the next one.

## Verification

All nine files were compared with `sha256sum` against
`C:\Users\verdu\.config\herdr-app\mods\` on 2026-11-11: every hash matches, so the
copies are byte-identical (CRLF line endings included — `main.js` and `mod.json`
in both mods are CRLF, as are the SVGs).
