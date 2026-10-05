# Stop komorebi from tiling Zen's child windows

Status: REOPENED 2026-10-05 20:08 - the fix is deployed and the state verified clean, but the user reports the symptom persists. Not closed.
Repo: `C:\Users\verdu\verdu.dotfiles`, branch `main`
Date: 2026-10-05
Related: `odd/tasks/komorebi-autostart-resilience.md` (same script, different defect)

## Goal

Workspace 2 must lay out only real windows. An app's child windows (caption layers,
input sinks) must never consume a tile slot.

## Non-goals

- No changes to the layout values, FFM, borders or AHK bindings.
- No `--clean-state` on the autostart: the dumped-state behaviour is a separate question.

## Facts (verified 2026-10-05)

YASB numbers workspaces from 1 (`label_zero_index: false`), so the bar's "2" is
komorebi index **1**.

`komorebic state` showed workspace index 1 holding four containers:

| Container | hwnd | exe | class | verdict |
|---|---|---|---|---|
| c[0] | 1509596 | zen.exe | `ReunionWindowingCaptionControls` | **child of the Zen main window** |
| c[1] | 66860 | Ferdium.exe | `Chrome_WidgetWin_1` | real |
| c[2] | 854450 | zen.exe | `InputNonClientPointerSource` | **child of the Zen main window** |
| c[3] | 985448 | zen.exe | `MozillaWindowClass` | real (Zen Browser) |

Win32 evidence for the two suspects:

```
hwnd=1509596 class=ReunionWindowingCaptionControls  rect=(1259,599) 799x992  styles=[WS_CHILD,LAYERED]  GA_ROOT=985448
hwnd=854450  class=InputNonClientPointerSource      rect=(2068,1100) 421x491 styles=[WS_CHILD,LAYERED]  GA_ROOT=985448
hwnd=985448  class=MozillaWindowClass               styles=[top-level]  GA_ROOT=SI  (Zen Browser)
```

The computed layout for that workspace was:

```
c[0] x=9    y=49  w=799 h=992   <- whole left half, held by the caption child
c[1] x=818  y=49  w=853 h=491   <- Ferdium, squeezed into the top right
c[2] x=818  y=550 w=421 h=491
c[3] x=1249 y=550 w=422 h=491   <- Zen Browser, a quarter tile
```

A tiled child window cannot paint in its tile (it is clipped to its parent, and
komorebi parks it off-screen), so the left half of the workspace stayed empty while
the real windows were compressed into the right half. Confirmed as the observed
symptom by the user.

Root cause: these two classes were never in the autostart's `ignore-rule class` list
(the same mechanism already covers `#32770`, `TaskDialog`, `MozillaDialogClass` and
`MozillaDropShadowWindowClass`). The signature of the whole family is
`GetAncestor(hwnd, GA_ROOT) != hwnd`.

## Tasks

| # | Task | Status |
|---|---|---|
| 1 | Diagnose the workspace-2 layout and identify the offending windows | done |
| 2 | Add the two classes to the autostart's `ignore-rule class` list | done |
| 3 | Deploy to `%USERPROFILE%` and restart komorebi through the autostart | done - needed two attempts, see below |
| 4 | Verify workspace index 1 ends with two containers and no child windows anywhere | done - the child windows are gone from the whole state |
| 5 | Record the pattern in the README gotchas (detection + fix) | done - gotcha 19, including the dumped-state trap |
| 6 | Commit the work unit | done |

## Reopened (2026-10-05 20:08) - the user still sees it

The user reported the symptom persists right after the verification. The state captured
at 20:08:47 could not confirm it:

```
ws[0] (bar '1'): 1377920 WindowsTerminal.exe
ws[1] (bar '2'):  66860 Ferdium.exe
child classes anywhere in the state: 0
ignore_identifiers: ... ReunionWindowingCaptionControls, InputNonClientPointerSource
```

...but **hwnd 985448 (Zen Browser) and both child hwnds were already destroyed at that
moment**: Zen had been closed, so that snapshot cannot prove anything either way. The one
configuration that matters is **Zen open**, and that is exactly what the 20:04 check
covered (children alive, komorebi not managing them).

Next session, in this order:

1. With Zen open, dump the state and look for the two classes. If they are absent, the
   ignore rules are doing their job and the visible symptom is something else.
2. If they are present, the class rule is not matching child windows: try
   `float-rule class` for them, or pass `--clean-state` to komorebi in the autostart so a
   dumped state can never resurrect them, and re-read `komorebic global-state` ->
   `ignore_identifiers`.
3. If they are absent *and* the left half still looks empty, capture fresh evidence with
   the workspace on screen: `komorebic state` (per-workspace containers) plus the
   visible-window enumeration, and compare the tile rects against the real window rects.
   Watch for a single-container workspace where the BSP tree kept a split.

Note: `komorebic ignore-rule class <ID>` has no matching-strategy option, so the
`"matching_strategy": "Legacy"` seen in `global-state` is how class rules are stored, not a
misconfiguration.

## Verification (2026-10-05)

First attempt — rules deployed, then the autostart run (`20:03:50 [ok] komorebi ready`):

```
ws[1] still had 4 containers, including 1509596 [ReunionWindowingCaptionControls]
and 854450 [InputNonClientPointerSource]        <- FAILED, the rules did not apply
```

The cause was the dumped state, not the rules: `komorebic stop` had just written
`%TEMP%\komorebi.state.json` (12.478 bytes, 20:03:47) and it contained both child
classes and all five hwnds. komorebi auto-applies that dump on start, so the
containers were *restored* rather than re-managed, bypassing the ignore rules.

Second attempt — `komorebic stop`, delete `%TEMP%\komorebi.state.json`, run the
autostart (`20:04:20 [ok] komorebi ready`):

```
ws[0] (barra '1'): 1377920 WindowsTerminal.exe | 985448 zen.exe [MozillaWindowClass] | 66860 Ferdium.exe
ws[1] (barra '2'): (empty)
child classes anywhere in the state: 0
```

Side effect: dropping the dump also dropped the window-to-workspace assignments, so
the three windows came back together in the current workspace. Nothing is broken;
they just need redistributing with the hotkeys.

Residual risk: the same trap would repeat for a *future* class that komorebi manages
wrongly before the rule exists. The recovery recipe is in README gotcha 19. Making
the autostart pass `--clean-state` would harden this, at the cost of losing window
placement on every manual re-run (not applied; the user's decision).

## Verification

After the restart, `komorebic state` must show workspace index 1 with exactly two
containers (Ferdium + Zen Browser) and no `ReunionWindowingCaptionControls` or
`InputNonClientPointerSource` anywhere in the state.

## Rollback

`git revert` the work unit, re-copy `komorebi-autostart.ps1` to `%USERPROFILE%` and
restart komorebi. Without the rules the child windows get tiled again on the next
window event.
