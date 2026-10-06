# YASB v2 — status bar

Transparent bar, black translucent pills (`rgba(0,0,0,0.45)`), rounded 14 px,
28 px tall. Every widget/group is one pill; `styles.css` flattens grouper
children so a group reads as a single surface.

## Live layout

```
left : komorebi_workspaces        (5 dots; active opaque, rest translucent)
center: audio_visualizer          (self-collapses to nothing when quiet)
right : opencode_go               (OpenCode Go usage: 5h · week · month)
        grouper_sysinfo           (cpu · memory · gpu · systray collapsed ▾)
        clock                     (date/time, Spanish locale)
        power_menu                (restart/shutdown/sleep/lock/hibernate)
```

## Widgets in `config.yaml`

| Key | Type | Notes |
|---|---|---|
| `komorebi_workspaces` | `komorebi.workspaces.WorkspaceWidget` | dots via label glyphs `•`/`●`, `hide_empty_workspaces: false` (5 always) |
| `audio_visualizer` | `yasb.audio_visualizer.AudioVisualizerWidget` | bars, `hide_idle: true`, mono; collapses to 0 px when quiet, so the center is empty without audio |

## Center: the audio visualizer alone

The center holds only `audio_visualizer`. Its idle state is a collapse to zero width
(not `hide()`), so the center renders nothing when nothing plays and no empty pill is
left. `grouper_media` and `media_lite` were retired (2026-10-07): YASB v2.0.7's grouper
only hides when every child is `isHidden()`, the visualizer never hides (it collapses),
and click callbacks are per widget, so the visualizer cannot open Media Lite's popup.
Verified against the v2.0.7 sources.
| `grouper_sysinfo` | `yasb.grouper.GrouperWidget` | not collapsible; children cpu/memory/gpu/systray |
| `cpu` / `memory` / `gpu` | `yasb.cpu.CpuWidget` etc. | NF icons (`\uf2db`, `\uefc5`, `\uf0e7`) |
| `systray` | `yasb.systray.SystrayWidget` | `show_unpinned: false` (collapsed by default), `use_hook: false` |
| `clock` | `yasb.clock.ClockWidget` | `{%#d %B %Y · %H:%M h}`, `locale: es_ES`, `tooltip: false` |
| `power_menu` | `yasb.power_menu.PowerMenuWidget` | popup below the pill; requires `shutdown/restart/cancel` keys — the validator rejects otherwise |
| `opencode_go` | `yasb.custom.CustomWidget` | OpenCode Go usage via `opencode_go.py`; 4 states cycled by left click |

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

Clicking the pill rotates four states: full (5h + Week + Month) -> only 5h -> only
Week -> only Month -> full. The cycle state lives in `%TEMP%\opencode-go-usage.state`;
`--next` rotates it, the widget re-renders on its 1 s refresh loop, and the script
only re-questions the API when the 15-minute cache is stale.

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