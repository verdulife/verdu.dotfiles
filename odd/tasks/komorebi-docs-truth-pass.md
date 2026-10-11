# Truth pass: remove the stale FFM/config story from every doc and config

Status: DONE 2026-10-11
Repo: `C:\Users\verdu\verdu.dotfiles`, branch `main`
Date: 2026-10-11
Related: `odd/tasks/komorebi-static-config-hybrid.md`, `odd/tasks/adopt-masir-ffm.md`

## Goal

After two behaviour changes (masir replaces komorebi's `--ffm`; configuration
moved into a static `komorebi.json`), the docs and configs still described the two
old worlds. Make every statement true, in the docs, the manifest and the
remaining configs, so the repo has one story per fact.

## What the code now does (the truth propagated)

- FFM = the standalone `masir` daemon, started by the autostart after komorebi
  answers; it only raises komorebi-managed windows.
- Configuration = `windows/komorebi/komorebi.json`, applied by komorebi itself
  with `--config`. The autostart supervises (retry, dump guard, ordering,
  verify, log) and re-applies nothing.
- The script duplicates `resize_delta` and the workspace count purely as
  verification expectations against the config.

## Inventory of stale items, and what was done

1. `windows/komorebi/README.md` - header, Files list, "Runtime preferences"
   (now "Configuration (`komorebi.json`)"), the FFM section (was titled "why it
   is in AHK, not masir" and claimed masir was retired - the exact opposite),
   the CorelDRAW gotcha, and a **broken hotkey table** (a paragraph sat inside
   it). All fixed; three new gotchas added (single config home, the `name` and
   padding schema details, workspace names not reaching the bar).
2. `AGENTS.md` - the FFM invariant, a new config invariant, the "Where to edit
   what" row (points at `komorebi.json` now), the log line in the health checks,
   and "the four winget prerequisites" (the manifest lists fifteen).
3. `README.md` - the layout tree, the FFM bullet, the dialogs bullet, the
   customization knobs, and gotchas 1, 5, 8, 9, 10, 17, 18, 19; gotcha 22 added
   (single config home + how to test it with `replace-configuration`).
4. `windows/komorebi/komorebi.ahk` - the FFM comment, and a stale comment that
   still pointed at `identify-object-name-change-application exe zen.exe` in the
   autostart.
5. `MANIFEST.md` - a note that `spy-dialog.ps1`, `snapshot-wm.ps1` and `tests/`
   are repo-only, plus the config/supervisor split.

## Extra findings (beyond the original inventory)

- **The Zen rescue timer no longer exists.** `komorebi.ahk` only registers
  `HideTaskbar`; the `RescueUnmanagedWindows`/`FocusManage` timer was removed on
  2026-10-06 (its own header said so). Both READMEs still described it as present
  - fixed to describe it as removed, keeping the AHK v2 `Bind` lesson as a
  warning for anyone re-adding one.
- **The border formula was written in camelCase** (`workspacePadding`...) in both
  READMEs, i.e. in the language of the deleted CLI block. Now snake_case, matching
  `komorebi.json`.
- **`undefined/` is not old junk**: it is written by `opencode-pi` (which resolves
  a cache path to the literal `undefined`) and dated today. Deleting it would only
  make it return, so it is `.gitignore`d with a note instead.
- Verified clean (no stale references): `windows/yasb/*`, `windows/powershell/*`,
  `windows/nushell/*`, `windows/win-terminal/*`.

## Plan (all done)

- [x] Rewrite the komorebi README.
- [x] Fix `AGENTS.md`.
- [x] Fix the root README.
- [x] Fix the `komorebi.ahk` comments.
- [x] `.gitignore` the stray `undefined/`.
- [x] Work-unit commits on `main`.

## Result

Every doc now tells the same story as the code. `komorebi.ahk` was re-deployed
(comment-only change) so the deployed copy stays byte-identical to the repo;
`komorebi.json`, `komorebi-autostart.ps1` and `container-dump.ps1` were verified
in sync (sha256). No remaining statements of the form "FFM is komorebi-native" or
"the autostart re-applies the layout"; the remaining `--ffm` mentions are all
explicitly historical ("why not").

## Still open for a future pass

- `windows/komorebi/tests/container-dump.Tests.ps1` was not run in this pass
  (nothing it tests changed), and there is no test covering `komorebi.json`.
- The GH/PR-facing story in `MANIFEST.md` prerequisites was only corrected where
  it was factually wrong; no re-verification of the winget package list.
