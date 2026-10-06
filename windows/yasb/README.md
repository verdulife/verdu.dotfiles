# YASB v2 — status bar

Transparent bar, black translucent pills (`rgba(0,0,0,0.45)`), rounded 14 px,
28 px tall. Every widget/group is one pill; `styles.css` flattens grouper
children so a group reads as a single surface.

## Live layout

```
left : komorebi_workspaces        (5 dots; active opaque, rest translucent)
center: grouper_media             (audio_visualizer + media_lite; hidden when idle)
right : opencode_go               (OpenCode Go usage: 5h · week · month)
        grouper_sysinfo           (cpu · memory · gpu · systray collapsed ▾)
        clock                     (date/time, Spanish locale)
        power_menu                (restart/shutdown/sleep/lock/hibernate)
```

## Widgets in `config.yaml`

| Key | Type | Notes |
|---|---|---|
| `komorebi_workspaces` | `komorebi.workspaces.WorkspaceWidget` | dots via label glyphs `•`/`●`, `hide_empty_workspaces: false` (5 always) |
| `grouper_media` | `yasb.grouper.GrouperWidget` | `hide_empty: true`; children: `audio_visualizer`, `media_lite` |
| `audio_visualizer` | `yasb.audio_visualizer.AudioVisualizerWidget` | bars, `hide_idle: true`, mono |
| `media_lite` | `yasb.media_lite.MediaWidget` | cover + single-line title; click → popup player (incl. per-app volume) |
| `grouper_sysinfo` | `yasb.grouper.GrouperWidget` | not collapsible; children cpu/memory/gpu/systray |
| `cpu` / `memory` / `gpu` | `yasb.cpu.CpuWidget` etc. | NF icons (`\uf2db`, `\uefc5`, `\uf0e7`) |
| `systray` | `yasb.systray.SystrayWidget` | `show_unpinned: false` (collapsed by default), `use_hook: false` |
| `clock` | `yasb.clock.ClockWidget` | `{%#d %B %Y · %H:%M h}`, `locale: es_ES`, `tooltip: false` |
| `power_menu` | `yasb.power_menu.PowerMenuWidget` | popup below the pill; requires `shutdown/restart/cancel` keys — the validator rejects otherwise |
| `opencode_go` | `yasb.custom.CustomWidget` | OpenCode Go usage (5h · week · month) via `opencode_go.py`; display-only (all clicks inert) |

## OpenCode Go widget (`opencode_go`)

`opencode_go.py` tries the `opencode-go` key of two stores, in this order:

1. `%USERPROFILE%\.pi\agent\auth.json` — Pi's managed store (`type: api_key`),
   the one that carries the Go entitlement on this machine.
2. `%USERPROFILE%\.local\share\opencode\auth.json` — the opencode CLI store
   (`type: api`); its key answers `403 EntitlementError: OpenCode Go
   subscription required` for this endpoint (measured 2026-10-06).

A key the endpoint rejects falls through to the next candidate, so an entitled
key in either store is enough. It queries every 5 minutes and returns one JSON
line: the 5h / week / month percentages plus their text bars. The cache lives in
`%TEMP%\opencode-go-usage.cache.json` on purpose: next to the script it would sit
in the directory YASB watches for config changes and could poke the bar into
reloading every interval.

Requirements:

- An interpreter the Windows launcher resolves: `run_cmd` uses `py`, not
  `python`, because on a machine where the Microsoft Store app-execution alias
  owns `python` that stub fails even though a real Python is installed.
- `CaskaydiaCove NFP` for the ▰/▱ bar glyphs (the label also forces it on the
  bar cells); see the family list in `styles.css`.
- A key with an active OpenCode Go entitlement somewhere: without one the
  endpoint answers `403 EntitlementError` for every candidate, the widget falls
  back to the cached values (`stale: true`) and, with no cache, renders `0%` with
  empty bars. The pill itself only shows zeros; the `error` is in the JSON.

## Fullscreen behavior

`hide_on_fullscreen: true` (combined with `always_on_top: true`, which the
feature requires) makes the bar drop to `HWND_BOTTOM` while a **real
fullscreen** window is active — browser fullscreen video (F11), exclusive
fullscreen games — and restore it when fullscreen closes. It uses the native
Windows appbar notification `ABN_FULLSCREENAPP`, so borderless-windowed games
(which are ordinary top-level windows) do **not** trigger it; that is a YASB
limitation, not a config one.

## Editing rules

- After changing `styles.css` or `config.yaml`, **restart YASB** (it rewrites
  files on reload; the watcher is not reliable for styles).
- YASB requires `komorebic` on `PATH` at startup.
- Font families in `styles.css` are per machine: check what is registered before
  naming one, and never list an unregistered family first (the whole label falls
  through to the Segoe default with different metrics).
- Popups are separate windows: blur works there (not per-widget in the bar —
  Windows limitation).