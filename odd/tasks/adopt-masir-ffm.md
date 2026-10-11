# Adopt masir as the focus-follows-mouse daemon (replace komorebi --ffm FFM)

Status: DONE 2026-10-11
Repo: `C:\Users\verdu\verdu.dotfiles`, branch `main`
Date: 2026-10-11
Related: `odd/tasks/port-work-machine-corrections-to-home.md` (OPEN finding: FFM dies after fullscreen)

## Goal

Stop relying on komorebi's built-in "Komorebi" FFM, which dies permanently after a
video fullscreen, and run the FFM via the standalone `masir` daemon, persisted in the
autostart so it survives the next logon.

## Why (evidence, 2026-10-11)

- komorebi v0.1.41 "Komorebi" FFM is a low-level mouse hook on a thread that contends
  for the global WindowManager lock. On a fullscreen transition the hook stops
  delivering; the config still reports `focus_follows_mouse=Komorebi`, no command
  disables it, and a `focus-follows-mouse enable/disable` toggle does NOT reinstall the
  hook (installed once per process). Reproduced: worked after restart, died at YouTube
  fullscreen.
- The maintainer marks the built-in config field `focus_follows_mouse` as EOL:
  "use https://github.com/LGUG2Z/masir instead".
- `masir` (winget `LGUG2Z.masir`, already installed at `C:\Program Files\masir`) is a
  standalone FFM daemon: own process, own hook, own message loop; only raises windows
  listed in komorebi's `%LOCALAPPDATA%\komorebi\komorebi.hwnd.json`, so it keeps the
  same "only managed windows" guarantee without sharing komorebi's lock.
- A/B verified 2026-10-11: with the built-in FFM disabled and masir running, hover
  focus worked and SURVIVED a YouTube fullscreen (masir.log: 90 raises, 0 errors).

## Non-goals (deferred)

- Purging deprecated/obsolete komorebi + YASB config beyond the FFM lines.
- Full inventory doc of what makes komorebi + YASB work.
- A robust unified launcher for komorebi + yasb + masir.
- Updating README.md / AGENTS.md FFM wording (still says `--ffm`/komorebi-native).

## Facts

- masir must start AFTER komorebi: it reads `komorebi.hwnd.json` once at startup; if the
  file is absent it runs unbound (focuses anything). Placed in the `if ($ready)` block.
- komorebi writes `komorebi.hwnd.json` on every known_hwnds change, independent of
  `--ffm`/`--masir`, so plain komorebi is enough.
- Autostart is launched only at logon; the running test instance is session-only.

## Plan

- [x] Persist masir in `windows/komorebi/komorebi-autostart.ps1`:
      drop `--ffm` and `focus-follows-mouse enable -i komorebi`; keep
      `mouse-follows-focus disable`; start masir guarded, with stdout/stderr captured;
      update the adopt-with-ffm gate and the ffm field in the verification/log.
- [x] Add `winget install -e --id LGUG2Z.masir` to the MANIFEST prerequisites.
- [x] Deploy the updated autostart to `%USERPROFILE%` and run it; verify:
      komorebi up, `focus_follows_mouse` null, masir running, log shows masir=true, and a
      hover + fullscreen is stable.

## Result (2026-10-11)

- `komorebi-autostart.log`: `[ok] layout applied: resize_delta=25 mouse_follows_focus=False masir=True workspaces=5/5 monitors=2` (new `masir=` field replaces `ffm=`).
- komorebi runs WITHOUT `--ffm` (`"C:\Program Files\komorebi\bin\komorebi.exe"`); `state` shows `focus_follows_mouse=null`, `mouse_follows_focus=false`, `paused=false`.
- masir started by the autostart (fresh PID), reads `%LOCALAPPDATA%\komorebi\komorebi.hwnd.json`, zero errors in stderr (captured to `%TEMP%\masir.err`).
- Hover + a YouTube fullscreen verified stable when masir handles FFM.
- Commit: fix(km): run focus-follows-mouse via masir instead of komorebi --ffm

## Post-reboot acceptance (real logon, 2026-10-11)

The Result above is session-scoped: the autostart was run by hand. This is the
first real logon after the change (boot 14:37:01, logon 15:01:48) and it is the
cleanest one in the whole log.

- `komorebi-autostart.log`, first entry with no warning of any kind: no
  `[warn] removed unsafe state dump`, no `[WARN] workspaces unexpected`
  (2026-10-07), no `[FAIL] verification` (2026-10-09).
  `15:02:36 [ok] komorebi ready` /
  `15:02:37 [ok] config applied: resize_delta=25 mouse_follows_focus=False masir=True workspaces=5/5 monitors=2`.
- Start order came out right: AutoHotkey64 15:02:31, yasb 15:02:32, komorebi
  15:02:35, masir 15:02:36 - masir after komorebi, which is what reading
  `komorebi.hwnd.json` once at startup requires.
- `%LOCALAPPDATA%\komorebi\komorebi.hwnd.json` written 15:16:41 (masir live and
  bound); `%TEMP%\masir.err` empty.
- YASB came up clean: pipe server, audio visualizer, `KomorebiEventListener`
  connected, no errors in `yasb.log`.
- User-observed after the reboot: the bar stays hidden, hover focus survives
  fullscreen, and both monitors behave.