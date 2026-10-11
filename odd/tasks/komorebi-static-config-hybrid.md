# Adopt a static komorebi.json and make the autostart a resilience supervisor

Status: DONE 2026-10-11
Repo: `C:\Users\verdu\verdu.dotfiles`, branch `main`
Date: 2026-10-11
Related: `odd/tasks/adopt-masir-ffm.md`

## Goal

Move komorebi's declarative configuration into a static `komorebi.json`
(upstream-supported, so `display_index_preferences` and the rest become
available), and keep our own logon script only for what upstream does not
solve: the foreground-lock retry, the unsafe state-dump guard, per-process
guards, ordering, verification and the log.

## Why (decision)

The official mechanism is `komorebic enable-autostart` (a shortcut in
`shell:startup`) plus `komorebic start --config komorebi.json`, which owns the
lifecycle of komorebi and its companions. Our pure-CLI re-application cannot
express `display_index_preferences` (the dual-monitor fix) or other declarative
features, and it re-implements what `komorebic` already does. But going
pure-official loses the resilience layer that solved real failures on this
machine (2026-10-06 logon with no WM; stale dump replay; "restart apps" double
launch) and upstream no longer manages AHK (`--ahk` is gone in 0.1.41).
=> Hybrid: official mechanism + declarative config, our supervisor on top.

## Non-goals (deferred to the cleanup pass)

- Purging every stale doc/config reference (README/AGENTS/MANIFEST wording).
- Reconciling the three contradictory FFM stories in the docs.
- Evaluating `--clean-state` (would drop workspace restoration; not now).
- `--masir` (ordering vs `komorebi.hwnd.json` unverified; masir stays explicit).

## Facts

- komorebic 0.1.41: `enable-autostart`/`start` accept `--config`, `--whkd`,
  `--bar`, `--masir`; both dropped `--ffm` (EOL -> masir) and `--ahk`.
- `komorebi.exe` itself accepts `-c/--config <path>`, so the supervisor keeps its
  stderr redirects while delegating configuration to the static file.
- Schema: monitors[].workspaces[].name is REQUIRED; `workspace_padding` /
  `container_padding` are per-workspace; the YASB widget draws fixed glyphs, so
  workspace names do not change the bar.
- `mouse_follows_focus` default is TRUE -> set false explicitly.
- Main monitor = the one at 0,0 = DISPLAY2 (`CNK51707R2`); secondary =
  DISPLAY1 (`CNK6180S06`).
- `komorebic replace-configuration <path>` replaces the running instance's
  config, so the JSON was proven live before the autostart was changed.
- Global `default_*_padding` leaves `state` padding null (inherited, unverifiable);
  explicit per-workspace padding keeps the state readable and deterministic.

## Plan (all done)

- [x] Author `windows/komorebi/komorebi.json`.
- [x] Prove it live with `komorebic replace-configuration` + `komorebic check`.
- [x] Rewrite the autostart to start komorebi with `--config` and drop the
      redundant CLI preference block.
- [x] Deploy both files; restart via the autostart; verify end to end.
- [x] MANIFEST: `windows/komorebi/komorebi.json` -> `%USERPROFILE%\komorebi.json`.
- [x] Work-unit commit on `main`.

## Result

`komorebi.json` is now the single source of truth for configuration; the
supervisor only supervises.

- `komorebic check`: `Found komorebi.json`.
- Live `replace-configuration`: 2 monitors, 5+5 workspaces, names I-V / 1-5,
  workspace_padding 4, container_padding 0, resize_delta 25,
  mouse_follows_focus false, windows stayed managed.
- Clean restart through the autostart (`komorebic stop` + kill + script):
  - `[warn] removed unsafe state dump (empty-rect:1050096)` (the Zen child).
  - `[ok] config applied: resize_delta=25 mouse_follows_focus=False masir=True
    workspaces=5/5 monitors=2`; exit code 0.
- `komorebi.exe` command line now: `--config C:\Users\verdu\komorebi.json`.
- 0 `ignored-class container present` lines; AHK, YASB, komorebi, masir all up.

## Phase B handoff (the "a conciencia" cleanup, not done here)

Stale items found, to fix in the cleanup pass:

1. `AGENTS.md` invariant: "focus-follows-mouse is komorebi-native (autostart
   starts `komorebi.exe --ffm` ...)" - now doubly false (masir + `--config`).
2. `windows/komorebi/README.md`: claims FFM lives in AHK and that masir was
   "tried and retired"; it is now the FFM of record.
3. `windows/komorebi/komorebi.ahk` lines ~75-80: comment says FFM is
   komorebi-native. Stale.
4. The three docs give three different FFM stories; unify into one.
5. `komorebi.json`'s values are duplicated as `$expected*` verification
   constants in the autostart; document that coupling in the README.
6. Untracked stray `undefined/` directory in the repo root (Oct 9) - decide.
