# OpenCode Go pill: label formats and dashboard click

Status: done — T1-T5 complete and verified live on 2026-10-07
Repo: `C:\Users\verdu\verdu.dotfiles`, branch `main` (personal repo — commits land on
`main` directly, no feature branches)
Machine: work machine (`verdu.dotfiles` clone, `py` -> Python 3.14.6, single monitor)
Related: `windows/yasb/opencode_go.py`, `windows/yasb/config.yaml`, `windows/yasb/README.md`

## Goal

Reshape the three data-bearing states of the `opencode_go` pill and give the widget a
useful right click.

Requested formats (live values at plan time were 5h 8%, week 22%, month 59%):

- Full state (all metrics):
  `5h ▰▱▱▱▱ 8%  W ▰▰▱▱▱ 22%  M ▰▰▰▱▱ 59%`
- Single-metric states (5h / W / M), each with its own reset countdown:
  `5h ▰▱▱▱▱ 8% (Resets in 6d 4h)`
- Right click opens the OpenCode Go dashboard:
  `https://opencode.ai/console/wrk_01KR0RFFBT5FCG3YTKPGW9JTSB`

## Decisions taken at plan time

- **Bar width stays 5 cells** in every state. The request wrote 5 underscores for the
  full state and 4 for the single states; the existing `BAR_CELLS = 5` wins so the bar
  does not change width when the state rotates (one constant to flip if wrong).
- **Single-state names are abbreviated** (`5h`, `W`, `M`), matching the request's own
  `5h/W/M` wording instead of the old `Week`/`Month` words.
- **Reset countdown only in the single states**, exactly as requested: the full state
  stays a dense three-metric line.
- The `--popup` Tkinter window is kept (still reachable by hand) but stops being bound
  to right click, which now opens the dashboard. Middle click stays `do_nothing`.

## Non-goals

- No change to the auth store order, the 15-minute cache, the 1 s refresh loop, or the
  `%TEMP%` cache/state placement.
- No new HTTP call: the reset timestamps already arrive in the usage payload, they were
  simply discarded by `normalize()` before the label saw them.

## Tasks

- [x] T1 Rework `label_text()` in `opencode_go.py`; carry `resetsAt` through
      `normalize()` -> JSON -> label for the three metrics.
      Added `metrics_json()`; both `main_json()` branches (live and error) now build
      their data from it, so the error path can no longer miss a label key.
- [x] T2 Bind `on_right` in `config.yaml` to the dashboard URL.
- [x] T3 Verify: deterministic render check of the four states plus a live script run.
- [x] T4 Update `windows/yasb/README.md` (state line format + right-click behavior).
- [x] T5 Deploy to `%USERPROFILE%\.config\yasb`, restart YASB, check `yasb.log`.
- [x] T6 Follow-up (same day, requested before the review landed): spell the words out in
      the single-metric states — `Week` / `Month` instead of `W` / `M`. The full state
      keeps the abbreviations, because that is the line that has to stay dense.
      Live after the copy alone: the widget re-runs the script every second, and the
      `config.yaml` edit was comment-only, so no reload was needed.

## Evidence

Work unit: `690c4d0` — `feat(yasb): reshape the opencode pill labels and open the dashboard on right click`
(script + config + README + this task doc; not pushed).

Housekeeping before the checks: the temporary probe files under `%TEMP%` were removed,
and the `__pycache__` that importing the script leaves in `windows/yasb/` was deleted
(it is not gitignored).

1. **Four-state render** (imported module, synthetic resets, live percentages 8/22/59):

   ```
   FULL | 5h ▰▱▱▱▱ 8%  W ▰▰▱▱▱ 22%  M ▰▰▰▱▱ 59%
   5h   | 5h ▰▱▱▱▱ 8% (Resets in 4h 11m)
   W    | W ▰▰▱▱▱ 22% (Resets in 6d 3h)
   M    | M ▰▰▰▱▱ 59% (Resets in 21d 2h)
   ```

   Edge values also checked: `0%` renders five empty cells, `100%` five filled cells,
   and a missing `resetsAt` renders `(Resets in Unknown)` instead of raising.

2. **Error path** (`USERPROFILE`/`TEMP` pointed at an empty dir, so no key and no cache):
   emits the full JSON with `*_reset: "Unknown"` and a FULL-state text, exit code 0 —
   the old code shape would have raised `KeyError` here.

3. **Right-click command**: YASB tokenizes a callback with `".+?"|[^ ]+` and strips the
   quotes before `Popen(args, shell=True)`, so `exec start "" "<url>"` reaches `cmd` as
   `start " " <url>`. Probed with a real target (`%TEMP%\probe.cmd` writing a file):
   the file appeared, so the title slot being one space is harmless and the target runs.
   The `start`-must-have-a-title claim is measured, not assumed: without the quoted first
   argument `start` treats the URL as the title and opens a console.

4. **Live pill**: `py %USERPROFILE%\.config\yasb\opencode_go.py` returns
   `5h ▰▱▱▱▱ 8% (Resets in 1h 28m)` with `state: 1` and real `resetsAt` values from the
   API — the reset countdowns come from the existing payload, no new request.

5. **Deployment**: `opencode_go.py` and `config.yaml` copied to
   `%USERPROFILE%\.config\yasb\` per `MANIFEST.md` (diff-clean). YASB picked the config
   change up on its own watcher (`Reloading Application because of config change`), and
   after a forced restart at 13:43 the log shows the widget stack back up with **0 error
   lines** and no validator rejection of the new `on_right` value.

Not verified by automation: the actual browser tab opened by a right click — the
mechanism is proven, the visual confirmation is a human click.

### T6 re-check (single states spell the words out)

Re-ran the same four-state render after the follow-up edit, tags stripped:

```
FULL  | 5h ▰▱▱▱▱ 8%  W ▰▰▱▱▱ 22%  M ▰▰▰▱▱ 59%
5h    | 5h ▰▱▱▱▱ 8% (Resets in 1h 27m)
WEEK  | Week ▰▰▱▱▱ 22% (Resets in 4d 11h)
MONTH | Month ▰▰▰▱▱ 59% (Resets in 6d 22h)
```

Deployed copy re-verified live and it already painted the word form
(`Week ▰▰▱▱▱ 22% (Resets in 4d 12h)`, `stale: false`, no `error`), which also shows the
state file had rotated to `WEEK` on a left click in the meantime. 0 error lines in
`yasb.log` since the restart.

### Review disposition (honest record)

RDD is on, so `review inspect` was run for each candidate. Consent was **declined by the
human in the host UI for both of them**:

| candidate | target | consent result |
|---|---|---|
| after `690c4d0`/`7043e55` | `sha256:878220a1…f22d4` | `consent-declined-this-candidate`, risk `high` (`code that starts other processes in windows/yasb/config.yaml`) |
| after `1256beb` | `sha256:f79b90f5…4fa13` | `consent-declined-this-candidate`, risk `high` (same evidence) |

Both declines returned `lineage_created: false` and `mutation_performed: false`, so **no
native verdict exists for this work** and none may be claimed. A decline is
candidate-scoped: it is not the RDD kill switch, and it never lowers the bar below the
RDD-off path. Delivery of the committed range stays a human decision (nothing pushed).
