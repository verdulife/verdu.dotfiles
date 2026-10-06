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

`opencode_go.py` reads the key at
`%USERPROFILE%\.local\share\opencode\auth.json` (entry `opencode-go`), queries
the usage endpoint every 5 minutes and returns one JSON line: the 5h / week /
month percentages plus their text bars. Requirements:

- An interpreter the Windows launcher resolves: `run_cmd` uses `py`, not
  `python`, because on a machine where the Microsoft Store app-execution alias
  owns `python` that stub fails even though a real Python is installed.
- `CaskaydiaCove NFP` for the ▰/▱ bar glyphs (the label also forces it on the
  bar cells); see the family list in `styles.css`.
- A key with an active OpenCode Go entitlement: without it the endpoint answers
  `403 EntitlementError: OpenCode Go subscription required` and the widget
  renders `0%` with empty bars. It stays in the layout on purpose — the error
  is not silent in the JSON, but the pill itself only shows zeros.

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