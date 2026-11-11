# YASB v2 — status bar

Transparent bar, black translucent pills (`rgba(0,0,0,0.45)`), rounded 14 px,
28 px tall. Every widget/group is one pill; `styles.css` flattens grouper
children so a group reads as a single surface.

## Live layout

```
left : komorebi_workspaces        (5 dots; active opaque, rest translucent)
       pi_agents                  (live Pi sessions: Project STATE ...)
center: audio_visualizer          (self-collapses to nothing when quiet)
right : opencode_go               (OpenCode Go usage: 5h · week · month)
        grouper_sysinfo           (cpu % · memory · gpu · ssd %)
        grouper_actions           (systray collapsed ▾ | clock 00:00 | power)
```

## Widgets in `config.yaml`

| Key | Type | Notes |
|---|---|---|
| `komorebi_workspaces` | `komorebi.workspaces.WorkspaceWidget` | dots via label glyphs `•`/`●`, `hide_empty_workspaces: false` (5 always) |
| `audio_visualizer` | `yasb.audio_visualizer.AudioVisualizerWidget` | bars, `hide_idle: true`, mono; collapses to 0 px when quiet, so the center is empty without audio |
| `grouper_sysinfo` | `yasb.grouper.GrouperWidget` | not collapsible; children cpu/memory/gpu/ssd |
| `grouper_actions` | `yasb.grouper.GrouperWidget` | systray (collapsed ▾) left, clock center, power right |
| `cpu` / `memory` / `gpu` | `yasb.cpu.CpuWidget` etc. | small-caps label + percentage (`{info[percent][total]}%`, no MHz). GPU shows utilization only; the temperature and the memory detail live in `label_alt`, one left click away (`GpuWidget` defaults `on_left` to `toggle_label`) |
| `disk` | `yasb.disk.DiskWidget` | *retired*: replaced by `ssd`, which reports saturation instead of free space |
| `ssd` | `yasb.custom.CustomWidget` | SSD **saturation** (busy time), not free space: `ssd_busy.py` samples `\PhysicalDisk(_Total)\% Disk Time` through `pdh.dll` — the counter behind Task Manager's Disk column — and prints the finished small-caps label. `run_interval: 3000` because the script spends ~500 ms of it sampling |
| `systray` | `yasb.systray.SystrayWidget` | `show_unpinned: false` (collapsed by default), `use_hook: false` |
| `clock` | `yasb.clock.ClockWidget` | label `{%H:%M}`; hover off (v2.0.7 hardcodes the tooltip); left click opens the calendar |
| `power_menu` | `yasb.power_menu.PowerMenuWidget` | popup below the pill; requires `shutdown/restart/cancel` keys — the validator rejects otherwise |
| `opencode_go` | `yasb.custom.CustomWidget` | OpenCode Go usage via `opencode_go.py`; 4 states cycled by left click, right click opens the dashboard |
| `pi_agents` | `yasb.custom.CustomWidget` | live Pi sessions via `pi_agents.py`; `Project STATE` per session (state in faux small caps), Pi mark icon from `pi-logo.png`; left click slides the overflow by one session, right click opens the detail table |

## System info labels: faux small caps (CPU / RAM / GPU / SSD)

Each sysinfo widget opens with its name in the same faux small caps `pi_agents.py`
uses for a session state — upper case, 9px, `#9aa3b2`, no tracking:

```yaml
# built-in widgets: the look comes from the `.sc` class in styles.css
label: "<span class=\"sc\">CPU</span> {info[percent][total]}%"
```

**Why faux:** Qt rich text ignores `font-variant: small-caps`, and no Nerd Font on
this machine carries the Unicode small-caps block (CaskaydiaCove NF/NFP/NFM and
JetBrainsMono NF* lack the glyphs for `b c d e f k m n o p r t w`), so a word cannot
be spelled in real small caps. The `#9aa3b2` tone is the muted label colour the
icons used, so the word reads as a label and the number stays the bright part of the
pill.

**The gap before the number is a margin, not a space.** On a built-in widget the span
and the percentage are separate child labels, so the space in the label string is
collapsed and `CPU8.4%` runs together; `.sc` carries `margin-right: 4px` to restore
it. The `ssd` label is one HTML string, so its space survives on its own — which is
why the two hooks also differ in how the gap is produced.

### Two hooks, because YASB renders the two kinds of label differently

| widget kind | widgets | where the word is styled |
|---|---|---|
| built-in | `cpu`, `memory`, `gpu` | `<span class="sc">CPU</span>` in `config.yaml` + the `.cpu-widget .sc` / `.memory-widget .sc` / `.gpu-widget .sc` rule in `styles.css` |
| custom | `ssd` | inline `<span style="font-size:9px"><font color="#9aa3b2">SSD</font></span>` emitted by `ssd_busy.py` (`LABEL_FONT_SIZE`) |

**Gotcha — YASB discards inline `style` on built-in labels.** A built-in widget's
label mark-up is split into one child QLabel per `<span>`, and the span's inline
`style` attribute is dropped when YASB recreates the label; only `class` survives
(that is how the retired `.icon` / `qproperty-pixmap` rules worked). Proven
experimentally: a `font-size:16px` inline probe on the CPU label changed nothing on
the bar after a config reload. Custom widgets are different — their whole HTML
string is rendered by a single QLabel, so `ssd_busy.py`'s inline style is correct
and must stay inline. Do not "unify" the two: the built-ins cannot use inline
styles and the custom widget does not need a QSS class.

**Gotcha — Qt Style Sheets have no `letter-spacing`.** The built-in labels therefore
carry no tracking, and the SSD span gives its `1px` up to match them, so all four
words look identical. Restoring tracking would need a real rich-text label on every
widget, not a stylesheet edit.

**Retired:** `cpu-icon.png`, `ram-icon.png` and `gpu-icon.png` (28x8 wordmark PNGs
rendered from the FigCraft exports) are gone. The stylesheet stopped referencing
them when the labels became text, and on 2026-11-11 the files and their `MANIFEST.md`
rows were deleted, along with the deployed copies and the generator that drew them,
`make_sysinfo_icons.py`. Reverting is still a config edit, not a redesign: restore
the `<span class="icon"></span>` spans and the `qproperty-pixmap` rules from git
history, plus the three PNGs (`git show <old-commit>:windows/yasb/cpu-icon.png`),
their rows and the generator, and the bar looks exactly as before. Redrawing is the
only thing that does not come back for free: the generator read the FigCraft
exports, which were never tracked here.

## SSD saturation (`ssd_busy.py`)

Task Manager's Disk column is **busy time**, not free space, and Windows exposes it
as a performance counter. `py` (the interpreter the bar shells out to) has no
`psutil`, so the helper reads `\PhysicalDisk(_Total)\% Disk Time` through `pdh.dll`
with `ctypes` — `PdhAddEnglishCounterW`, which is also why the English name works on
this Spanish-locale Windows where `typeperf`/`Get-Counter` reject it.

The counter accumulates per-request service time, so overlapping I/O pushes it past
the wall clock: `clamp_percent` keeps the pill inside 0-100 and `PDH_FMT_NOCAP100` is
never requested. Percentage counters need a baseline, so a run costs one sampling
window (`--window`, default 500 ms) plus interpreter start; `run_interval` is 3000
for that reason.

Verified against the counter it complements: during a sustained 1.2 GB copy,
`% Disk Time` reads 100.0% while `% Idle Time` reads 0.0%. Idle machines read 0.0-2%.

Tests: `py -B -m unittest discover -s windows/yasb -p "test_*.py"` from the repo root.

## Center: the audio visualizer alone

The center holds only `audio_visualizer`. Its idle state is a collapse to zero width
(not `hide()`), so the center renders nothing when nothing plays and no empty pill is
left. `grouper_media` and `media_lite` were retired (2026-10-07): YASB v2.0.7's grouper
only hides when every child is `isHidden()`, the visualizer never hides (it collapses),
and click callbacks are per widget, so the visualizer cannot open Media Lite's popup.
Verified against the v2.0.7 sources.

## OpenCode Go widget (`opencode_go`)

`opencode_go.py` tries the `opencode-go` key of three stores, in this order:

1. `%USERPROFILE%\.gentle-shell\agent\auth.json` — Gentle Shell's managed store
   (`type: api_key`), the one that carries the Go entitlement on this machine.
2. `%USERPROFILE%\.pi\agent\auth.json` — Pi's managed store, kept as a fallback
   for machines that still run a standalone Pi home.
3. `%USERPROFILE%\.local\share\opencode\auth.json` — the opencode CLI store
   (`type: api`); its key answers `401 Unauthorized` for this endpoint
   (measured 2026-11-07; it answered `403 EntitlementError` on 2026-10-06).

The gentle-shell store became the first candidate on 2026-11-07, when the
standalone Pi home was removed from this machine. Only a `type: api_key` entry
carries the entitlement, and the key lives under the JSON field `key`, not
`api_key` — writing the wrong field produces an entry with no key that fails
silently.

A key the endpoint rejects falls through to the next candidate, so an entitled
key in either store is enough. It queries every 5 minutes and returns one JSON
line: the 5h / week / month percentages with their text bars and reset countdowns.
The cache lives in
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

Clicking the pill rotates four states: full (5h + W + M) -> only 5h -> only Week
-> only Month -> full. The cycle state lives in `%TEMP%\opencode-go-usage.state`;
`--next` rotates it, the widget re-renders on its 1 s refresh loop, and the script
only re-questions the API when the 15-minute cache is stale.

Label shapes (same 5-cell bar in both, so the pill does not change width when the
state rotates):

```
full        5h <circle 1/8> 8%  W <circle 2/8> 22%  M <circle 5/8> 59%
single      5h ▰▱▱▱▱ 8% (1h 29m)
single      Week ▰▰▱▱▱ 22% (4d 12h)
single      Month ▰▰▰▱▱ 59% (6d 23h)
```

### The full state uses an eight-step circle, not the text bar

`5h`, `W` and `M` in the full state are painted with Material Design's
`circle-slice-1` .. `circle-slice-8` (U+F0A9E .. U+F0AA5): a donut whose inner
wedge is exactly 1/8 .. 8/8 full (measured on the installed TTF: 12.3 / 25.6 /
38.8 / 51.1 / 63.9 / 75.6 / 88.0 / 100 %). The percent is rounded to the nearest
eighth and floored at 1/8, because there is no 0/8 glyph.

Two things the first attempt got wrong and the script now does on purpose:

- The glyph is rendered at **15 px** (`SLICE_FONT_PX`) although the label is
  ~13 px. The donut's inner hole is about 4 px at bar size, so an eighth of it
  is invisible; the extra size is what makes 1/8 and 2/8 tell apart.
- The glyph uses **`#d7dce2`**, not the muted `#9aa3b2` of the text bars: ring
  and wedge share one colour, so the muted gray hid the filled part.

The single-metric states (`5h`, `Week`, `Month`, with their reset countdown)
still use the `BAR_CELLS`-wide text bar.
The full state abbreviates `W` and `M` to stay a dense three-metric line; the
single-metric states have room for the words. The reset countdown only fits the
single-metric states, and it is word-free there: the parentheses next to the percent
already read as "resets in", and the words cost 10 of the 19 characters the countdown
occupied (`(4d 12h)` instead of `(Resets in 4d 12h)`). `label_text()` in the script owns
both shapes, so the label template in `config.yaml` is just
`<span class="icon"></span> {data[text]}`. The verbose "Resets in ..." wording still
appears per metric in the `--popup` window, which no mouse button opens any more — run
`py %USERPROFILE%\.config\yasb\opencode_go.py --popup` when you want the long form.

Right click opens the OpenCode Go console page in the default browser:
`on_right: 'exec start "" "https://opencode.ai/console/wrk_..."'`. YASB tokenizes a
callback with `".+?"|[^ ]+` and strips the quotes before `Popen(args, shell=True)`,
so the empty `""` arrives as a single space — still a valid `start` window title,
which keeps the URL in the target slot. Drop that first quoted argument and `start`
takes the URL as the title and opens a console instead of the browser. If the URL
ever gains a space or a `&`, replace the callback with an `exec` on a small script:
the tokenizer and `cmd` both break on those.

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

## Pi agents widget (`pi_agents`)

`pi_agents.py` enumerates the Pi sessions running on this machine and paints one
segment per session:

```
🅿 dante-store WORKING   verdu.dotfiles WORKING   vre-mcp IDLE
```

No separator glyph: segments are separated by a gap (`&nbsp;&nbsp;`) and each one
ends with its state. The state is **faux small caps** — upper case at 9 px with
1 px letter spacing, inside the pill's ~13 px label. Real small caps are not
available: no Nerd Font on this machine carries the Unicode small-caps block
(CaskaydiaCove NF/NFP/NFM and JetBrainsMono NF* lack `ᴡ ᴏ ʀ ᴋ ɴ`, checked with
`fontTools`), and Qt rich text ignores `font-variant: small-caps`.

Sources (local files only, no network):

| Source | What it gives |
|---|---|
| `%USERPROFILE%\.gentle-shell\agent\gentle-agents\presence\*.header.json` | one record per running Pi session: `label`, `heartbeat`, `counts{running,queued,waiting}` |
| `...\<hash>.<incarnation>.activity.json` | that session's child tasks (`agent`, `label`, `status`) |
| `%USERPROFILE%\.gentle-shell\agent\sessions\<project>\<iso>_<sessionId>.jsonl` | the transcript tail: last tool call and whether the turn is still open |

A session is **live** while `now - heartbeat <= 15 s` (the window Pi's own presence
publisher uses). Records are grouped by `sessionHash` (`sha256(sessionId)`) and the
newest incarnation wins, so a killed session's leftovers never render. The
transcript is matched by hashing the id in its filename.

States, first match wins:

| State | Meaning |
|---|---|
| `offline` | the presence record reports `unavailable` |
| `blocked` | `counts.waiting > 0` or a child task is `waiting` |
| `authorizing` / `planning` / `exploring` / `researching` / `implementing` / `checking` / `deciding` / `closing` | phase declared by `gentle_odd_phase` for the turn, else inferred from the most recent tool call of the turn that implies one, mirroring `gentle-pi`'s `odd-phase-inference.ts` (`todo` → planning, `read`/`grep`/`find`/`ls` → exploring, `web_search`/`fetch_content`/`source_check` → researching, `edit`/`write` → implementing, `bash` running a checker → checking, `ask_user_*` → deciding) |
| `working` | the turn is open but no tool in it implies a phase |
| `idle` | the last record is an assistant message with `stopReason: stop` |

Precedence inside a turn: an explicit `gentle_odd_phase` marker wins for the whole
 turn, and `clear` hands control back to inference. Inference itself walks back to
the most recent call that implies a phase, so an ambiguous shell command, a memory
call or a web fetch never collapses the label to `working` mid-turn. A `toolResult`
record carries only the tool name, which is why the call — not the result — is read.

Order: `blocked` first, then the working states (phase before plain `working`),
then `idle`; ties by newest heartbeat.

### No horizontal scroll — a sliding window instead

A custom widget **cannot** receive mouse-wheel events: YASB implements
`wheelEvent` only in `komorebi/workspaces`, `komorebi/stack`, `glazewm/workspaces`,
`brightness`, `media` and `media_lite`, and `CustomWidget` dispatches only
left/middle/right. So the width is bounded by a window of at most **five**
segments, then ` +N` for the hidden ones. **Left click** slides that window by one
session — the leftmost segment disappears and the next one is appended — and it
wraps around the ordered list, so clicking is a loop over every live session; the
position lives in `%TEMP%\pi-agents.page`. While every session already fits, the
click changes nothing. **Right click** opens a table with every live session
(project, state, phase, child task, model, session id, uptime).

With no live session the script prints an empty JSON string, and `hide_empty: true`
hides the pill, so nothing empty is left in the bar. The label template is
`"{data}"` and not `"{data[text]}"` on purpose: YASB formats the template *before*
it checks `hide_empty`, so a failed format (a `None` payload) would leave the
literal template painted.

### Icon

The pill starts with the Pi mark: `<span class="icon"></span>` in the label plus a
`qproperty-pixmap` rule in `styles.css` pointing at
`C:/Users/verdu/.config/yasb/pi-logo.png` (absolute, because the stylesheet resolves
relative paths against the YASB working directory). The PNG is 18x18 with a
transparent background, rasterized from the supplied `pi-logo-on-dark.svg`:

The mark is **monochrome white**: all three `fill` values of the supplied
`pi-logo-on-dark.svg` are rewritten to `#FFFFFF` before rasterizing, so the
internal pieces read as one white glyph on the dark pill instead of three colours.

    sed -e 's/#F09082/#FFFFFF/; s/#4D9ABF/#FFFFFF/; s/#F1BE58/#FFFFFF/' \
        pi-logo-on-dark.svg > pi-logo-white.svg
    magick -background none -density 1200 pi-logo-white.svg -resize 18x18 -depth 8 -strip pi-logo.png

No SVG at runtime on purpose: the frozen YASB build is not guaranteed to ship the Qt
SVG image plugin, and the same rule pattern already works for `opencode_go`.

Tests: `py -B -m unittest discover -s windows/yasb -p "test_*.py"` from the repo root.
