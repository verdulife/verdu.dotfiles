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

## Two third-party layout bundles

A layout is one file, `layouts/<name>.json`: the whole window, its blocks and its
look. It needs no registration — the app lists every file it finds in `layouts/`
and in `Settings`, and `ctrl-shift-l` (`layout.switch`) cycles through them. A
layout is useless without the mods it points at, so each bundle is pinned here as
one unit: `layouts/<name>.json` plus every `mods/<name>/` it names. These are
tracked copies, not edits of Herdr's own files — the app replaces its own on every
start and leaves a folder it finds in the home alone.

| Bundle | Upstream | Pinned commit | What the person sees (from the upstream README) |
|---|---|---|---|
| `pixel` | <https://github.com/murtuzaalisurti/herdr-pixel-layout> | `79a25da3c30d3682d7843fbb13ee2f209079398a` | "A retro pixel-art layout … bitmap-font headings and turns each agent into a card with a tiny scene that shows its status … Tabs and terminal frames are square, the focused one is orange, and the status bar reads like a DOS status line." |
| `main-pixel` | <https://github.com/pilmokim/herdr-pixel-spaces> | `72ae9e425586b75a36daab55e9e4752ae8590f94` | "A pixel-art sidebar … Each space wears a little 8×8 sprite in its color instead of a letter tile, the Go to picker shows the same sprites, Claude Code and Codex get 9×9 pixel icons, and the sidebar's header drops Herdr's logo for … whether an agent is waiting for you." |

Both upstream trees are laid out like an app home (`layouts/`, `mods/`, a
`RECIPE.md`, a `preview.png`, `LICENSE`), so the copies keep the upstream file
names and folder nesting; only `RECIPE.md` and `preview.png` are left out, as the
app's own guide asks. Each bundle's Apache-2.0 `LICENSE` is kept under
`licenses/<upstream-repo>/` (repo-only, not copied); the per-mod license files
(`mods/pixel-spaces/fonts/LICENSE-*.txt`, `mods/main-pixel-chrome/LICENSE-Lucide.txt`)
travel with their mod.

**The one deliberate deviation:** the two bundles both name a mod `pixel-spaces`
and a mod `pixel-chrome`, and two folders cannot share a name in one `mods/`. The
first bundle asked for keeps its names; the second's two colliding folders are
prefixed with the layout they belong to, so `pixel-spaces/pixel-chrome` (retro
layout) and `main-pixel-spaces`/`main-pixel-chrome` (sprite sidebar) can live side
by side. That rename is applied in the layout's `mod` fields and in
`mods/main-pixel-chrome/main.js`'s own `mods/main-pixel-chrome/…svg` paths — the
app's guide requires exactly that when a name is taken. `pixel-picker` did not
collide and keeps its name.

Deploy (after the `MANIFEST.md` rows for this folder):

```powershell
# pixel — retro layout
Copy-Item windows/herdr-app/layouts/pixel.json "$HOME\.config\herdr-app\layouts\"
'pixel-spaces','pixel-agents','pixel-tabs','pixel-pane','pixel-status','pixel-chrome' | ForEach-Object {
  Copy-Item "windows/herdr-app/mods/$_" "$HOME\.config\herdr-app\mods\" -Recurse -Force
}
# main-pixel — sprite sidebar (+ its Go-to picker)
Copy-Item windows/herdr-app/layouts/main-pixel.json "$HOME\.config\herdr-app\layouts\"
'main-pixel-spaces','main-pixel-chrome','pixel-picker' | ForEach-Object {
  Copy-Item "windows/herdr-app/mods/$_" "$HOME\.config\herdr-app\mods\" -Recurse -Force
}
Copy-Item windows/herdr-app/programs.json "$HOME\.config\herdr-app\programs.json"   # only if none exists
Copy-Item windows/herdr-app/pixel-icons "$HOME\.config\herdr-app\" -Recurse -Force
```

Validate each mod the bundle brought, then switch to it:

```powershell
$HERDR = "$env:LOCALAPPDATA\Programs\herdr-app\herdr-app.exe"
'pixel-spaces','pixel-agents','pixel-tabs','pixel-pane','pixel-status','pixel-chrome',
'main-pixel-spaces','main-pixel-chrome','pixel-picker' | ForEach-Object {
  & $HERDR check "$HOME\.config\herdr-app\mods\$_"
}
& $HERDR do layout.switch '{"name":"pixel"}'
& $HERDR do layout.switch '{"name":"main-pixel"}'
```

Each `check` must exit 0 with no error text; a failure exits 1 and prints the
exact error. A layout has no `check`: it is proven by switching to it, and an
invalid layout keeps the previous one on screen and writes
`~/.config/herdr-app/layout.error`.

### Switching between them, and what they collide with

Nothing is overwritten: `pixel` and `main-pixel` are new names, the tracked
`files`/`changes` mods stay as they are, and Herdr's `main`, `terminals` and
`win98` layouts and the `atom-one-dark`/`win98` themes are untouched (neither
bundle ships a theme). Switch with `ctrl-shift-l`, or
`herdr-app do layout.switch '{"name":"pixel"}'`, `…'{"name":"main-pixel"}'`,
and back with `…'{"name":"main"}'`. Every layout shares the same spaces, tabs
and terminals; only the drawing changes. Removing a bundle = deleting its layout
file and its mod folders.

Both bundles clone Herdr's shipped mods (0.1.14 and 0.1.11) and the installed app
is 0.1.15, so expect small drift: `check` and the switch are what prove them here.

### What the third-party code does

Read every file before deploying; this is what they contain.

- **No network access.** No `fetch`, `WebSocket` or URL in either bundle.
- **Programs run** (both bundles' spaces mods, inherited verbatim from Herdr's own
  shipped `spaces` mod, not added by the authors): `exec("git", ["--no-optional-locks",
  "-c", "core.fsmonitor=false", "status", "--porcelain=v2", "--branch"])`,
  `git rev-parse`, and `hc(["machine", "ls", "--json"])` / `hc([...args, "--json"])`
  for the remote-machine menu. Read-only, scoped to the pane's `cwd`.
  `pixel-spaces/main.js` (the retro bundle) also carries the inherited
  `ask(["machine", "rm", name])` entry of that menu — shipped Herdr has the same
  line; nothing calls it without a click.
- **Folder watches:** `watchFolder(repo)` on the pane's repo, same as shipped.
- **Paths:** every asset path is relative to the app home (`mods/<mod>/…`); no
  absolute paths, no writes outside the mod folder and the app's own shared state
  (`setShared`, inherited).
- **Files outside their own folder are read** through the shipped mods' assets:
  `mods/workspace-chrome/*.svg` (`plus`, `branch`, `search`, `spinner`,
  `chevron-*`). Those files are Herdr's and rewritten on start, so they are there,
  but deleting the shipped `workspace-chrome` mod would break those glyphs.
- **Telemetry:** none of their own; the app's own `settings.json` switch applies.
- **Fonts:** `pixel-spaces/fonts/*.ttf` (PxPlus IBM VGA 8x16, CC BY-SA 4.0;
  Pixelated MS Sans Serif, CC BY-SA 3.0) load from the mod folder, so the mod and
  its fonts travel together as the guide describes.

### Machine-local files these need (not copied)

- `keys.json` — the sprite bundle suggests one binding for its picker, kept here as
  `keys.pixel-picker.merge.json` (repo-only, no manifest row):
  `{"global": {"cmd-p": "mod.open:pixel-picker"}}`. `keys.json` is machine-local
  and **merged, never overwritten** — the current file already uses `ctrl-shift-p`
  for the palette and `ctrl-shift-k` for `mod.open:picker`; `cmd` does not exist on
  Windows, so a Windows key (e.g. `ctrl-shift-k` — already taken — or a free one)
  is a human decision. Without it, the sidebar's search button opens the picker.
- `programs.json` — `{"programs": {"claude": {"icon": "pixel-icons/claude.svg",
  "tint": false}, "codex": {"icon": "pixel-icons/codex.svg", "tint": false}}}`.
  There is no `programs.json` in the home yet, so the row copies it whole; once the
  person adds entries it is theirs and further syncs mean merging.
- `installed.json` needs **no** entry: it is the app's own file-hash record, and a
  layout or mod folder is picked up from its file alone.
