# Port the work-machine corrections to the home machine

Status: closed — T0-T7 done and verified, including T6's start branch, exercised at a real
start on 2026-10-07 01:41 in the user's own terminal: the sanitizer removed the unsafe
dump, komorebi started on the first attempt, layout applied with `monitors=2`. One open
item recorded for another day: komorebi's native focus-follows-mouse stops acting after a
fullscreen enter/exit until a restart.
Repo: `C:\Users\verdu\dotfiles`, branch `chore/apply-home-machine-corrections`
Date: 2026-10-06
Related: `odd/tasks/apply-dotfiles.md` (the original port), `odd/tasks/consolidate-pi-install.md`
(why `pi` depends on a Node >= 22.19 on PATH), `odd/tasks/komorebi-*.md` (work-machine findings).

## Goal

Bring this machine's deployed configuration up to the repo's current state, applying only
what this machine actually needs, adapting what is machine-bound, and skipping what does
not apply.

## Problem and why verification is per item

The 21 commits pulled from `origin/main` (the `188c9f3..edaf1c3` range) were written and
verified on the **work** computer. Every deployed file on this machine still matches
`188c9f3` byte for byte, so none of them is applied here. Two of the corrections are
machine-bound and would be wrong if copied literally:

- `windows/win-terminal/settings.json` is a full snapshot of the **work** machine
  (it carries `archlinux`, `Developer Command Prompt for VS 18`, `Multipass`; this
  machine has `Ubuntu`, `VS 2019`, `VS 2022`). A wholesale copy deletes this machine's
  dynamic profiles.
- The repo now sets `"face": "JetBrainsMono NFP"`. Only `JetBrainsMono NFM` is registered
  on this machine (user scope, `HKCU`), so `NFP` would silently fall back to the WT default.

Two prerequisites are also missing here, so two items are blocked on a decision rather
than on code: no usable `python` on PATH, and the stored `opencode-go` key has no
subscription entitlement on this machine (HTTP 403 `EntitlementError`).

## Scope

In: the seven work units below, each closed with a work-unit commit on a feature branch.

Out: pushing, opening a PR, changing upstream komorebi behaviour, rewriting the YASB widget
to drop Python, any change to `auth.json` or to the subscription state.

## Verified classification

| # | Repo change | Verdict here | Evidence collected at plan time |
|---|---|---|---|
| T1 | `windows/nushell/env.nu` — hand-written fnm hook | **Needed** — this is the `pi` fix | With the persisted PATH alone: `node` = `C:\Program Files\nodejs\node.exe` v21.7.2 and `pi --version` fails with `SyntaxError: ... 'node:module' does not provide an export named 'enableCompileCache'`. With the repo `env.nu`: `node` v24.18.0, `pi --version` = 1.0.2 |
| T2 | YASB `opencode_go` widget (`config.yaml` + `styles.css` + `opencode_go.py` + `opencode-logo.png`) | **Wanted, blocked on entitlement** | `auth.json` has an `opencode-go` key and `CaskaydiaCove NFP` is registered (the label's glyph font). But `py opencode_go.py` returns `{"error":"HTTP Error 403: Forbidden"}`; the API answers `EntitlementError: OpenCode Go subscription required`. Also `python` is only the Microsoft Store alias stub here, while `C:\Python310\python.exe` (3.10.0) works |
| T3 | YASB `audio`: `sensitivity: 70` + `auto_gain: false` | **Needed** (behaviour fix, same file as T2) | Deployed config still has `sensitivity: 50` / `auto_gain: true` |
| T4 | `windows/powershell/user_profile.ps1` — migrated local blocks | **Partial**: keep `herdr`, `ya`/`godot` are inert | `herdr` resolves on this machine; `yazi` and Godot are not installed, so those two blocks cannot run (harmless, and the repo already notes the stale Godot path) |
| T5 | `windows/win-terminal/settings.json` — explicit font, `startingDirectory`, hidden duplicate Nushell profile | **Adapt, never copy** | Profile lists differ (see *Problem*). No `"source": "nu"` duplicate exists here yet — WT generates it only when it materializes the profile. `defaultProfile` already points at the static Nushell GUID here |
| T6 | komorebi hardening: `komorebi-autostart.ps1`, `komorebi.ahk`, `container-dump.ps1`, `tests/`, `README.md` | **Not symptom-driven before the baseline; hardening now applied here** | `komorebi-autostart.log` was all `[ok]` (`workspaces=5/5`, `ffm=Komorebi`, `resize_delta=25`). The baseline snapshot then measured what the log never shows: DISPLAY1 reports a **0x1000** work area with three parked containers (`zen.exe` -983x973, `explorer.exe` -1939x457, `Ferdium.exe` -1939x-59, all alive and not minimized) and `%TEMP%\komorebi.state.json` (2026-10-04) is judged **unsafe** (`dead-hwnd:1640888`, `empty-rect:1640888`, `dead-hwnd:461170`). This machine reports **2** monitors × 5 workspaces |
| T7 | `README.md`, `MANIFEST.md`, `windows/komorebi/README.md` | **Apply with each unit, with one adaptation** | `MANIFEST.md` now says `%USERPROFILE%\verdu.dotfiles\windows\nushell\setup-autoloads.nu`; this machine's clone is `%USERPROFILE%\dotfiles`, so the path must stay neutral or local |

## Constraints and invariants

- Never copy `windows/win-terminal/settings.json` wholesale (gotcha 13).
- Font family on this machine is `JetBrainsMono NFM`; `NFP`/`NF` are not registered here.
- `pi` requires Node >= 22.19; after `%LOCALAPPDATA%\pi-node\current` disappeared, the fnm
  hook in `env.nu` is the only provider on this machine. Do not undo it.
- `nu -c` never loads `env.nu`; scripted checks must use `nu --env-config <path>`.
- `auth.json` is read-only context; never print or copy its values.
- Existing Pester here is 3.4.0 and the new tests use Pester 3 syntax (`Should Be`), so no
  module install is required.

## Tasks

| # | Task | Status |
|---|---|---|
| T0 | Branch off `main` (`chore/apply-home-machine-corrections`) and record the pre-state hashes of every destination | done |
| T1 | Copy `windows/nushell/env.nu`, then verify `pi` in a real Nushell tab | done — `pi` 1.0.2 on Node v24.18.0 |
| T2 | Decide the `opencode-go` entitlement (and `py` vs `python`) and only then add the widget | done — added with `py`, visible; the 403 stays documented |
| T3 | Apply the YASB audio idle fix | done — same file as T2 |
| T4 | Add the `herdr` block (and the inert `ya`/`godot` blocks) to the PowerShell profile | done — whole file copied, functions verified |
| T5 | Merge the portable NT parts into the live `settings.json` (Nushell `startingDirectory`, keep `NFM`, leave `defaultProfile` alone) | done — one key added, dynamic profiles preserved |
| T6 | Apply the komorebi hardening after a layout snapshot and the Pester suite | **done on the adopt path** — the start path runs at the next logon |
| T7 | Sync `README.md`/`MANIFEST.md` with what was actually applied, with the clone path made neutral | done |

Each task: apply, then re-read the destination and compare it with the repo file, then
commit that unit alone with a conventional message.

## Acceptance criteria and checks

- Per task: `cmp <repo file> <destination>` is clean, and the destination's mtime is newer.
- T1: in a **new interactive Nushell tab**, `pi --version` prints a version and `node`
  comes from `fnm_multishells\...`; `nu --env-config <dest>/env.nu -c 'node --version'`
  is the scripted equivalent.
- T2: `py %USERPROFILE%\.config\yasb\opencode_go.py` prints JSON with no `error` key, the
  widget renders in the bar, and YASB restarts without validation errors.
- T3: the audio pill collapses while nothing plays.
- T4: a new PowerShell window starts with no error and `herdr` auto-attach behaves as before.
- T5: WT reloads the file with no error, the Nushell tab opens in `%USERPROFILE%`, and the
  dynamic profiles (`Ubuntu`, `VS 2019/2022`) are still present.
- T6: `Invoke-Pester windows/komorebi/tests` passes; `snapshot-wm.ps1` shows the same
  width share before and after; after a komorebi restart the log ends with
  `[ok] layout applied: ... workspaces=5/5 monitors=2` and no `[warn]` line.
- Global: no secret is written into the repo; no unrelated file is modified.

## Progress and evidence

Pre-state hashes (before any copy), for rollback:

```
env.nu          e9296b9594c16e9f4d3b2fac65e12a72d3f23d7b4cc0ad8c413eb8dfc9c55964
config.yaml     483e797312b3f9bc8a8766df29e1fa45d72b88cd4becd3bf09bca09c67f0fe4f
styles.css      3ed763fca6ef364d2485285d93f1a9d5c650ff00647a8c90488c3ddacbdbf033
user_profile.ps1 399db1f554815959902ae4f3b58c672b8bc4464a04bbfae85002cef994fe6c79
settings.json   ac55a87c901d919160a01d6ed6e12d43f9ed25e510b022c2b0b613ca6ce80643
```

- **T1** — `%APPDATA%\nushell\env.nu` replaced and byte-identical to the repo. Red/green on
  the same machine, both with a PATH built only from the registry: without the file
  `node` v21.7.2 and `pi --version` dies with the `node:module` `enableCompileCache`
  `SyntaxError`; with it `node` v24.18.0 and `pi --version` prints `1.0.2`.
- **T2/T3** — four files deployed (`config.yaml`, `styles.css`, `opencode_go.py`,
  `opencode-logo.png`), all byte-identical. YASB reloaded by itself:
  `Reloading Application because of config change` then `Successfully loaded updated config
  and re-initialised all bars`, new PID 11032, no validation error. `py
  %USERPROFILE%\.config\yasb\opencode_go.py` returns the JSON line; it still carries
  `"error":"HTTP Error 403: Forbidden"` because the key on this machine answers
  `EntitlementError: OpenCode Go subscription required`.
- **T4** — `%USERPROFILE%\.config\powershell\user_profile.ps1` replaced; AST parse clean and
  a dot-source under `pwsh` (with `HERDR_ENV=1` so the auto-attach block stays out) loads
  without error and defines `ya`, `godot`, `sudo`, `vim`.
- **T5** — one key added to the live `settings.json`
  (`profiles.list[Nushell].startingDirectory = "%USERPROFILE%"`). Validated by parsing the
  file: 1 Nushell profile, `defaultProfile` unchanged, `Ubuntu`, `Git Bash`,
  `Developer … VS 2019/2022` still present, and no work-machine profile injected. The font
  stays on `profiles.defaults` = `JetBrainsMono NFM`, which is the family registered here.

- **T6 (komorebi)** — deployed in MANIFEST order (`container-dump.ps1` first, then the
  autostart, then `komorebi.ahk`); all three byte-identical to the repo afterwards.
  Gate: `Invoke-Pester windows/komorebi/tests` under a per-process `-ExecutionPolicy Bypass`
  (Windows PowerShell here is Restricted, and the logon VBS already uses Bypass) →
  **13 passed, 0 failed**.
  Baseline `snapshot-wm.ps1 -Label before` at 23:59:00: DISPLAY1 with a `0x1000` work area
  and three parked containers (`zen.exe` -983x973, `explorer.exe` -1939x457, `Ferdium.exe`
  -1939x-59), DISPLAY2 with one terminal alone at 99%.
  New autostart run on the adopt path (komorebi was already answering with `ffm=Komorebi`, so
  no stop/start): `[ok] komorebi ready` then `[ok] layout applied: resize_delta=25
  mouse_follows_focus=False ffm=Komorebi workspaces=5/5 monitors=2` — the `monitors=` field
  only exists in the new code, and there was no `[FAIL]` and no ignored-class `[WARN]`.
  The two new ignore rules are live, confirmed independently: the after snapshot's
  `ignore-list classes` now ends with `ReunionWindowingCaptionControls,
  InputNonClientPointerSource`, and `%TEMP%\komorebi.log.2026-10-06` logs
  `process_command{IgnoreRule(Class, "ReunionWindowingCaptionControls")} processed` (UTC
  clock: 21:59:44 = 23:59:44 local).
  `komorebi.ahk` reloaded through `#SingleInstance Force` (one process afterwards, new PID
  18128) after `AutoHotkey64.exe /validate` exited 0.
  Post snapshot `-Label after` at 00:00:18: the same three parked containers with the same
  hwnds and rects, and DISPLAY2 still alone at 99% → **no layout regression**. Bundles stay
  outside the repo in `%USERPROFILE%\komorebi-evidence\`.
  The third new rule is live too: komorebi's log shows
  `process_command{IdentifyObjectNameChangeApplication(Exe, "zen.exe")} processed` at the
  same second, and both guards held — one `AutoHotkey64` and one `yasb` process afterwards,
  so the per-process skip did not double them.
- Dump verdict on real data, without deleting it: `Test-ContainerDump` on the live
  `%TEMP%\komorebi.state.json` returns `Exists=True, Safe=False, WindowCount=2` with
  `dead-hwnd:1640888 | empty-rect:1640888 | dead-hwnd:461170` → the next start will drop it.

Adaptations accepted instead of a literal copy (they change the repo, not only the machine):

- `windows/yasb/config.yaml`: `run_cmd` uses `py`, since `python` here is the Microsoft
  Store alias stub while `C:\Python310\python.exe` is a real interpreter.
- `windows/yasb/styles.css`: the family list starts with `CaskaydiaCove NFP` then
  `JetBrainsMono NFM`; the previous list named two families that do not exist here, so every
  metric fell through to Segoe.
- `MANIFEST.md`: the `setup-autoloads.nu` example no longer hardcodes the work machine's
  clone folder (`verdu.dotfiles`); this clone is `dotfiles` until the pending rename to
  `verdu.dotfiles`.
- `README.md` gotcha 2: the JetBrains family is per machine (`NFM` here, `NFM`+`NFP` on the
  work machine), so it no longer prescribes `NFP` unconditionally.

Known follow-ups, not applied here:

- `env.nu` calls `^fnm` unguarded: on a machine without fnm, Nushell would error at start.
  Both machines have it, so parity with the repo file was preferred.
- The widget's visual confirmation in the bar (the JSON and the log prove it runs, not
  that the pill renders). The empty `opencode-go` entry in the opencode CLI store can stay:
  the widget now reads Pi's store first and falls through on a rejected key.
- T6's start branch ran at a real start (2026-10-07 01:41:43): the log shows
  `[warn] removed unsafe state dump (empty-rect:15730594, empty-rect:4982742)` then
  `[ok] komorebi ready` and `[ok] layout applied: ... workspaces=5/5 monitors=2` with no
  retry. Afterwards `manage-list` is empty: the old nuclear `manage-rule exe zen.exe` is
  gone, which was the root cause of the Zen "Save As" dialog flicker — the force-managed
  `#32770` dialog (exe zen) fought for its size against the tile — and the restart also
  revived focus-follows-mouse on this process.
- OPEN, for another day: after a fullscreen enter/exit (e.g. a YouTube video), komorebi's
  native focus-follows-mouse stops acting until a restart. Seen before the restart,
  verified working after it, not yet diagnosed (suspects: the FFM listener against
  fullscreen transitions, YASB `hide_on_fullscreen` dropping the bar to `HWND_BOTTOM`, or
  the fullscreen-exit retile).
- Observed in the after snapshot: a second `WindowsTerminal.exe` container on DISPLAY2 ws[1]
  (hwnd 7080006) that was not there 24 s earlier. It is a normal user window, not a child,
  so nothing looks anomalous — worth confirming it was opened by hand.

## Next step

**T1 is confirmed by the user** (`pi` works in an interactive Nushell tab). Remaining user
items: the widget pill in the bar (the JSON and the log prove it runs, not that it renders),
the fullscreen/FFM finding above, and the clone rename to `verdu.dotfiles` (blocked: the
folder is in use by this session and by at least one shell).
