# Stop komorebi from tiling Zen's child windows

Status: in progress
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
