# Consolidate the Pi coding agent into one managed installation

Status: done — tasks 1-8 complete and verified.
Repo: `C:\Users\verdu\verdu.dotfiles`, branch `chore/apply-dotfiles-port`
Date: 2026-10-05
Related: `odd/tasks/apply-dotfiles.md` (this work is the follow-up of that port's fallout)

## Goal

End up with exactly one Pi installation on this machine, provided by Pi's own
managed installer (`~/.pi/agent/install` + shims in `~/.pi/agent/bin`), and remove
the three duplicate distributions found during the audit.

## Non-goals

- No change to Pi's user configuration (`~/.pi/agent/*.json`, sessions, packages).
- No removal of `%LOCALAPPDATA%\pi-node\current`: it holds the Node runtime the
  managed launchers spawn (`pi.cmd` runs `node "%~dp0pi-launcher.js"` with `node`
  taken from PATH), so it is a dependency, not a duplicate.
- No push and no pull request: only the document itself was committed, with explicit
  user approval (commit `e9640e9`).
- The accidental empty `git init` in `%USERPROFILE%` was reported and later removed
  with explicit approval; it was never part of the consolidation.

## Environment facts (pre-state, audited 2026-10-05)

| Item | State |
|---|---|
| Active install (this session) | `~\.bun\install\global\node_modules\@earendil-works\pi-coding-agent` **1.0.3**, shim `~\.bun\bin\pi.exe` |
| Duplicate 2 | `%APPDATA%\fnm\node-versions\v26.4.0\installation\...` **1.0.0** + `pi.cmd`/`pi.ps1` (npm -g, 2026-10-02) |
| Duplicate 3 | `%APPDATA%\fnm\node-versions\v24.4.1\installation\...` **0.85.1** + `pi.cmd` (npm -g, 2026-09-17) |
| Runtime (not a duplicate) | `%LOCALAPPDATA%\pi-node\current` = Node 22.23.3 + npm 10.9.9, no Pi. First user-PATH entry, so it is the `node.exe` that executes the bun-installed Pi |
| Cached leftovers | `%LOCALAPPDATA%\npm-cache\_npx\...\@earendil-works\pi-coding-agent` 0.85.1 (npm cache, harmless); `~\.pi\agent\npm\node_modules\@earendil-works\` (empty) |
| Managed install dir | `~\.pi\agent\install` does **not** exist; `~\.pi\agent\bin` holds only `fd.exe`, `rg.exe` |
| Latest published npm version | 1.0.3 (= the version now active) |
| fnm | 1.39.0. `fnm env --shell` supports `bash, zsh, fish, powershell, cmd` — **no nushell** |
| nvm | not installed |

## Root cause of the outage (evidence-based)

The old Pi lived only inside fnm's per-version npm prefix (node v26.4.0, default
alias). fnm is a per-shell version manager: it exposes that prefix only in shells
where its hook ran, and the hook (`fnm env --use-on-cd --shell power-shell`) exists
only in `~/.config/powershell/user_profile.ps1`. Nushell has no fnm hook in
`config.nu`, `env.nu`, or `vendor/autoload/*`. The dotfiles port made Nushell the
Windows Terminal default profile, so `pi` (and `node`) stopped resolving there.
The Nushell `history.txt` was recreated on 2026-10-05, so the original error text is
gone; the hook/origin chain above is the surviving evidence.

## Decisions (confirmed with the user)

1. **Option 2 — consolidate on the official managed installer.** Rationale: pinned
   dependency tree, `pi update` works, and it does not depend on any version manager.
2. Remove the fnm duplicates with each Node version's own npm (`npm uninstall -g`),
   not by deleting directories.
3. The bun copy must be removed **before** the installer runs: the managed install
   refuses to replace a Pi it does not own (task 4 → task 5). Consequence: the
   machine has no `pi` between the two steps, and the recovery is
   `bun add -g --ignore-scripts @earendil-works/pi-coding-agent`.

## Tasks

| # | Task | Status |
|---|---|---|
| 1 | Snapshot every Pi distribution and the Node runtime; record the rollback path | done |
| 2 | Uninstall Pi 1.0.0 from fnm node v26.4.0 | done — `removed 147 packages in 16s` |
| 3 | Uninstall Pi 0.85.1 from fnm node v24.4.1 | done — `removed 131 packages in 11s` |
| 4 | **User:** remove the bun copy (`bun remove -g @earendil-works/pi-coding-agent`) in a terminal outside Pi, then confirm `where.exe pi` prints nothing | done — bun left two orphan shims behind, removed by hand |
| 5 | **User:** run the official installer in a fresh terminal and answer its prompts | done — managed install at `~\.pi\agent\install\releases\1.0.3` |
| 6 | Verify the managed install in a new shell (version, resolved shim, packages, `pi update`) | done — see *Managed install verified*; `pi update` deliberately not run |
| 7 | Decide the shell/Node strategy: keep `pi-node` on PATH and, if wanted, add an fnm hook to Nushell via `fnm env --json | from json | load-env` | done — fnm integration added to Nushell and committed separately |
| 8 | Close: record the final state, update this document, save memory | done |

Task 4-5 must run in the user's own terminal: the installer prompts via `Read-Host`
(Node choice, action menu, "Add ~\.pi\agent\bin to your user PATH now? [Y/n]") and
falls back to "no terminal detected" defaults when stdin is not a TTY.
Task 4 is the user's because this Pi session *is* the bun copy: deleting its files
from inside can break the running process.

## Installer guard (observed 2026-10-05)

Running the installer with the bun copy still on PATH aborts after "Will reinstall
Pi." with:

```
Installation failed.

Managed install refused to replace Pi at C:\Users\verdu\.bun\bin\pi.exe. Uninstall it first.
```

Source: `install.ps1` (v1.0.3) lines 1541-1548. When `$env:PI_EXISTING_PATH` (the
`pi` resolved from PATH) has no managed-install marker at the target root, the
installer refuses to write. The only other branch is `PI_INSTALL_ACTION = migrate`,
an internal knob for the legacy npm migration. Do not fake it: the correct order is
to remove the other distribution first.

The refusal is safe and leaves no partial state (verified): `~/.pi/agent/install`
still absent, `~/.pi/agent/bin` still holds only `fd.exe` and `rg.exe`, the user
PATH is unchanged, and `where.exe pi` still returns a single match.

## `bun remove -g` leaves its shims behind (observed 2026-10-05)

`bun remove -g @earendil-works/pi-coding-agent` removed the package from
`~/.bun/install/global/node_modules/@earendil-works/` and dropped the dependency
from `~/.bun/install/global/package.json`, but **left the launchers in place**:
`~/.bun/bin/pi.exe` and `~/.bun/bin/pi.bunx` survived the removal. The leftover shim
still put `C:\Users\verdu\.bun\bin\pi.exe` first on PATH while pointing at a deleted
bundle, so it failed with
`Cannot find module ...\pi-coding-agent\dist\bundle\cli.js` — and it would have made
the installer guard refuse a second time.

Fixed by deleting both orphan files by hand. Verified afterwards:

```
where.exe pi   -> no match (exit 1)
```

The running Pi session survived the removal of its own files: the Node process had
already loaded the bundle, and Windows allows deleting the image of a running
process (delete-pending), so `~/.bun/bin/pi.exe` (PID 19688, this session's parent)
was still listed as a live process after its file was gone. That session is
unreliable from that moment on: any lazily loaded module crashes it, so a fresh
managed Pi should replace it rather than be trusted to keep working.

## Verification evidence (2026-10-05)

Pre-state snapshot: PATH order was `[4] ~\.pi\agent\bin`, `[32] %LOCALAPPDATA%\pi-node\current`,
`[40] ~\.bun\bin`, `[77] %LOCALAPPDATA%\Programs\nu\bin`; `where.exe pi` returned only
`C:\Users\verdu\.bun\bin\pi.exe`; `node` resolved to `pi-node\current` (v22.23.3).

After tasks 2-3:

```
where.exe pi            -> C:\Users\verdu\.bun\bin\pi.exe   (single match)
pi --version            -> 1.0.3                              (session still alive)
find ~/.pi ~/.bun ~/AppData/Local/pi-node ~/AppData/Roaming/fnm -name 'pi.cmd|pi.ps1|pi-launcher.js'
                        -> none outside ~/.bun
```

The empty `node_modules/@earendil-works` scope directories left by npm in both fnm
Node versions were removed as well.

## Managed install verified (2026-10-05)

The decisive evidence is the process tree of the reopened session: it *is* the
managed install, not the old copy.

```
cmd.exe /c ""~\.pi\agent\bin\pi.cmd" -c"          <- how Nushell launched it
  -> node "~\.pi\agent\bin\pi-launcher.js" -c     <- resolves current-version
     -> %LOCALAPPDATA%\pi-node\current\node.exe
        ~\.pi\agent\install\releases\1.0.3\node_modules\@earendil-works\pi-coding-agent\dist\bundle\cli.js -c
```

`pi-launcher.js` reads `install/current-version`, resolves
`install/releases/<version>/node_modules/<package>` and re-spawns the CLI with
`process.execPath` (the Node found on PATH). Supporting facts:

| Check | Result |
|---|---|
| `where.exe pi` | `~\.pi\agent\bin\pi` and `~\.pi\agent\bin\pi.cmd` only |
| `pi --version` | 1.0.3 |
| `install/current-version` | 1.0.3 |
| `install/managed-install.json` | `kind: pi-managed-install`, `layout: releases-v1` |
| `install/releases/1.0.3/` | `metadata.json`, `package.json`, **`package-lock.json`** (pinned tree), `node_modules` |
| User PATH, first entries | `~\.pi\agent\bin`, then `%LOCALAPPDATA%\pi-node\current` |
| Extensions | `~/.pi/agent/npm/package.json` and `settings.json` packages unchanged; harness and memory tools load |
| Runtime | `pi-node\current\node.exe` v22.23.3 (>= 22.19 required) |

`pi update` was executed by the user on 2026-10-05 with the managed install in
place: it completed and Pi kept running on 1.0.3. It changed nothing on disk
(`releases/1.0.3` and `current-version` keep their installer timestamps, and
`staging/` is empty), so the install was already current — but the update path is
now proven, not merely inferred from the `releases-v1` layout.

## Nushell and fnm (task 7)

fnm 1.39 has no nushell target, and `fnm env --json` reports the `FNM_*` variables
**without PATH** (verified: the JSON has no `PATH` key). The shells fnm supports get
`<multishell>;<old PATH>` prepended. `windows/nushell/env.nu` now replicates that:
load the JSON, then prepend `FNM_MULTISHELL_PATH` to `$env.PATH`, guarded against a
second prepend when the file is re-sourced.

Verification note: **`nu -c` does not load `env.nu`** (a marker print appended to it
did not run in command mode). The change was therefore verified with
`nu --env-config <path> -c 'node --version'` and with an explicit `source` — and then
confirmed by the user in a fresh interactive Nushell tab — both of
which report `v26.4.0` and `node` resolving through `fnm_multishells\...`. Auto
switching on directory change is not wired into Nushell (PowerShell has it through
`--use-on-cd`); `fnm use` inside a session still works.

## Final state (2026-10-05)

Exactly **one** Pi installation plus one runtime:

```
~\.pi\agent\install\releases\1.0.3   managed Pi 1.0.3 (active)
%LOCALAPPDATA%\pi-node\current        Node 22.23.3 + npm 10.9.9 (runtime for the launcher)
```

Remaining copies of the package are caches, not installations: bun's download cache
(`~/.bun/install/cache/@earendil-works/pi-coding-agent`) and the npm `_npx` cache
(`%LOCALAPPDATA%\npm-cache\_npx\2d88ef2af9274b5e`, 0.85.1). Neither provides a
command and neither is on PATH. Purge them with `bun pm cache rm` and by deleting
that `_npx` directory if ever desired.

Cleanups approved and done: `%USERPROFILE%\.git` (empty accidental repo: 0 commits,
0 tracked files, 0 remotes) and the empty
`~/.pi/agent/npm/node_modules/@earendil-works/`.

Committed separately, as `feat(nushell): integrate fnm into the environment`: the repo
file `windows/nushell/env.nu`, its destination copy under `%APPDATA%\nushell` (the two
are byte-identical), and the README/MANIFEST notes that now record fnm as a
prerequisite.

## Rollback

- Duplicates 2 and 3: `npm install -g --ignore-scripts @earendil-works/pi-coding-agent@<ver>`
  with the matching Node version's `npm.cmd` (v26.4.0 → 1.0.0, v24.4.1 → 0.85.1).
- Bun copy: `bun add -g --ignore-scripts @earendil-works/pi-coding-agent` restores 1.0.3.
- Managed install: re-run the installer and choose **u** (uninstall) in the action menu.
- PATH: the installer only ever prepends `~\.pi\agent\bin`; it never removes entries.

## Notes for agents

- `pi.cmd` from the managed install calls `node` **from PATH**. Do not remove
  `%LOCALAPPDATA%\pi-node\current` unless another Node >= 22.19 is guaranteed on PATH.
- Never let two distributions sit on PATH at once: the first match wins silently.
  After task 6, `where.exe pi` must return exactly one path.
