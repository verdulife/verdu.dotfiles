# Apply the home-machine YASB update to the work machine

Status: done — T1-T6 complete and verified live on 2026-10-07
Repo: `C:\Users\verdu\verdu.dotfiles`, branch `chore/apply-home-machine-yasb-update`
Date: 2026-10-07
Related: `odd/tasks/port-work-machine-corrections-to-home.md` (the reverse direction, `188c9f3..edaf1c3`), `odd/tasks/apply-dotfiles.md` (the original port), `odd/tasks/komorebi-autostart-resilience.md` (the logon defect still open below)

## Goal

Bring this machine's deployed configuration up to `origin/main` after the 13
commits in `edaf1c3..2c1339e`, applying only what this machine actually needs and
verifying at runtime the prerequisites the incoming README adds.

## Orientation: which machine is this

The 13 incoming commits were authored and verified on the **home** machine (the
`C:\Users\verdu\dotfiles` clone, 2 monitors, only `JetBrainsMono NFM`
registered, no usable `python` on `PATH`). This is the **work** machine:

| Fact | This machine | Home machine (per the incoming docs) |
|---|---|---|
| Clone | `C:\Users\verdu\verdu.dotfiles` | `C:\Users\verdu\dotfiles` |
| Monitors | 1 (`Radeon RX 580 Series` 1680x1050) | 2 |
| Interpreter | `py` → Python **3.14.6** (real), plus a real `python.exe` | `python` only as the Microsoft Store stub, `C:\Python310` real |
| `CaskaydiaCove NFP` | registered | registered |
| `JetBrainsMono NF` / `NFP` / `NFM` | **all three registered** | only `NFM` |
| `opencode-go` key | present in Pi's store **and** the opencode CLI store | present in both, no entitlement at plan time |

Consequence: no incoming change is machine-bound in a way that breaks here.
Two incoming notes are home-machine-specific but harmless:

- `styles.css` names `"CaskaydiaCove NFP", "JetBrainsMono NFM"`. Both are
  registered here, and the same file already names `JetBrainsMono NFP` first in
  six other rules, which resolves on this machine and would not on the home one.
- The `run_cmd` comment explains the `py` choice through the Store-alias problem,
  which is the home machine's symptom. `py` is the right choice on both.

## Scope

In: the fast-forward of `main`, the three changed YASB files at their manifest
destinations, the YASB restart, the komorebi stack restart, and this record.

Out: pushing, opening a PR, merging into `main` (all the user's decisions), any
change to `auth.json`, and any change to the incoming shared docs (their
home-machine statements are accurate about the home machine).

## Prerequisite check (measured before the deploy)

| Prerequisite | Requirement source | State here |
|---|---|---|
| `py` launcher | `windows/yasb/README.md`, `config.yaml` `run_cmd` | OK — `C:\Users\verdu\AppData\Local\Programs\Python\Launcher\py.exe`, Python 3.14.6 |
| `CaskaydiaCove NFP` | `styles.css` `.opencode-go-widget .label`, `config.yaml` `<font face=...>` | OK — registered (with NF/NFM/NFP/JetBrains variants) |
| `opencode-go` entitlement | `windows/yasb/README.md` | **OK on this machine** — the script returns live data with `stale: false` and no `error` |
| `windows/yasb/opencode-logo.png` | `.opencode-go-widget` pixmap | unchanged by the incoming range, so the deployed copy still matches |

## Tasks

| # | Task | Status |
|---|---|---|
| T1 | Fast-forward `main` to `origin/main` | done — `edaf1c3` → `2c1339e`, 9 files, +487/-137 |
| T2 | Copy the three changed YASB files to `%USERPROFILE%\.config\yasb\` | done — 3/3 byte-identical |
| T3 | Verify the widget at runtime (`py`, entitlement, `--next` rotation) | done — live data + 4 states |
| T4 | Restart YASB and verify the bar layout | done — 0 ERROR, 0 WARNING, pipe connected, widget executing |
| T5 | Restart the komorebi stack and verify the layout | done — `[ok]` both lines, 1 monitor × 5 workspaces |
| T6 | Record this pass and commit it on the feature branch | done |

## Verification results

| Check | Result |
|---|---|
| `main` vs `origin/main` | identical; tree clean before the branch was cut |
| the three deployed files | `cmp` byte-identical |
| `config.yaml` parses | 15 widgets; `center = ['audio_visualizer']`, `right = ['grouper_sysinfo','opencode_go','grouper_actions']`; `grouper_media` and `media_lite` ABSENT |
| `opencode_go` options as shipped | `run_cmd: py %USERPROFILE%\.config\yasb\opencode_go.py`, `run_interval: 1000`, `on_left: exec py … --next` |
| `py opencode_go.py` | one JSON line, live values (`rolling 0`, `weekly 19`, `monthly 57`), `stale: false`, **no `error` key** → entitled here |
| click rotation | `0` → full (5h+Week+Month), `1` → 5h only, `2` → Week only, `3` → Month only, then back to `0`; the state file was returned to the value it had before the test (`3`) |
| widget actually executing | `Win32_Process` caught `py.exe` with `CommandLine = py C:\Users\verdu\.config\yasb\opencode_go.py`, i.e. YASB runs the new `run_cmd` on its 1 s loop |
| `yasb.log` since the 10:17 restart | **0 ERROR, 0 WARNING** lines; `Komorebi connected to named pipe` (the 10:08 restart could not connect because komorebi was down) |
| `komorebic state` | JSON parses; `resize_delta = 25` (layout applied), `is_paused = False`, `mouse_follows_focus = False`, `focus_follows_mouse = Komorebi` (native FFM), 1 monitor × 5 workspaces |
| processes | `komorebi.exe` 10612, `yasb.exe` 7376 (new pid → restarted), `AutoHotkey64.exe` 9416 |
| `komorebi-autostart.log` | `[ok] komorebi ready` 10:17:04 + `[ok] layout applied: resize_delta=25 mouse_follows_focus=False ffm=Komorebi workspaces=5 monitors=1` 10:17:05 |

Not verified mechanically: the bar's **visual** layout. This session's model
cannot read images, so the screenshot check was inconclusive; the structure is
verified in the parsed config plus the clean log, and the eyeball check is the
user's.

## Findings recorded on the way

1. **Launching `komorebi-autostart.ps1` from a shell whose stdout is captured
   hangs the caller.** komorebi is started with `Start-Process … -WindowStyle
   Hidden` and inherits the inherited pipe, so the pipe never sees EOF while
   komorebi lives. The autostart had in fact finished successfully
   (`[ok] komorebi ready`, 10:17:04) while the wrapper was still waiting. Run it
   detached (`cmd /c start`), or redirect its output to a file.
2. **The entitlement is machine-scoped, not account-scoped.** The same
   `opencode-go` key that answered `403 EntitlementError` on the home machine at
   plan time returns live usage here. Any future "the widget only shows zeros"
   report must be diagnosed per machine, not per key.
3. **No content drift outside the three files.** Every other manifest
   destination was already identical. `komorebi-autostart.ps1`,
   `container-dump.ps1` and `nushell/env.nu` differ **only** in line endings
   (repo CRLF from `core.autocrlf=true`, deployed LF); `diff --strip-trailing-cr`
   reports 0 differences. The repo has no `.gitattributes`.

## Open item carried in (separate from this pass)

This machine's logon start failed today and is **not** addressed by the incoming
range (all 13 commits are YASB plus docs):

```
2026-10-07 10:08:46 [warn] komorebi start attempt 1/9 failed (process exited):
  Error: failed call to AllowSetForegroundWindow after 5 retries
  Location: komorebi\src\main.rs:219:13
...
2026-10-07 10:12:06 [FAIL] komorebi not ready after 9 attempts (~240 s); layout NOT applied
```

The same failure hit 2026-10-06 20:15 (9/9, then a manual launch at 20:22
succeeded). The manual run in T5 then succeeded on the first attempt. So the
condition is logon-specific, the ~240 s retry horizon does **not** cover it, and
`komorebi.exe` bails before initialising its logger (the reason nothing lands in
`%TEMP%\komorebi.log.<date>`). `apply-dotfiles.md` recorded this once as "not
reproducible"; it now reproduces at every logon here. It deserves its own task,
and the practical mitigation is that the session must be able to recover without
a manual launch.

## Follow-ups

1. **komorebi logon failure** — needs its own diagnosis task (see above). Not
   started here because the user scoped this pass to the dotfiles update.
2. **No `.gitattributes`**: with `core.autocrlf=true` every deployed `.ps1`/`.nu`
   under `%USERPROFILE%` ends up LF while the repo checkout is CRLF, so each
   future byte-comparison audit reports three false diffs. A `* text=auto eol=lf`
   (or an explicit decision to deploy with CRLF) would end the churn. Not applied:
   it is a repo-wide decision.
3. **Incoming docs are home-machine-phrased.** `windows/yasb/README.md` and the
   `styles.css` comment name `JetBrainsMono NFM` as "the JetBrains family actually
   registered on the home machine". True where it was written, and useful on this
   machine only as a fallback entry. Left untouched on purpose.
4. **`nvim` plugin sync** and the stale Godot `PATH` entry from `apply-dotfiles.md`
   are still open.

## Evidence log

- T1 — `git merge --ff-only origin/main`: `edaf1c3` → `2c1339e`, 9 files changed,
  487 insertions / 137 deletions; branch `chore/apply-home-machine-yasb-update`
  created from the new `main`. `cmp` before the deploy: `config.yaml`,
  `styles.css`, `opencode_go.py` all `differs`; every other manifest destination
  already identical.
- T2 — `cp` + `cmp`: 3/3 `byte-identical OK`. YAML parse: 15 widgets, center
  `audio_visualizer` alone, `grouper_media`/`media_lite` absent, `grouper_actions`
  present.
- T3 — `py opencode_go.py` → `{"rolling":0,"weekly":19,"monthly":57,…,"stale":false,`
  `"text":…}`; four `--next` steps produced exactly the four documented states and
  the state file went 3 → 0 → 1 → 2 → 3. `Win32_Process` poll confirmed
  `py C:\Users\verdu\.config\yasb\opencode_go.py`.
- T4 — `Stop-Process yasb` then the autostart relaunch: `yasb.exe` 7376,
  `Komorebi connected to named pipe`, 0 ERROR / 0 WARNING in `yasb.log` after
  10:17.
- T5 — autostart run: `[ok] komorebi ready` 10:17:04, `[ok] layout applied …`
  10:17:05; `komorebic state` parses with `resize_delta=25`, `monitors: 1`,
  `DISPLAY1`, 5 workspaces, `focus_follows_mouse: Komorebi`.
- T6 — this document, committed on `chore/apply-home-machine-yasb-update`.
