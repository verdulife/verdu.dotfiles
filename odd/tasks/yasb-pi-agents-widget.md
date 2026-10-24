# YASB Pi agents widget

A custom YASB pill that enumerates the live Pi sessions on this machine and
shows each one's state, e.g. `verdu.dotfiles (working) | vre-mcp (idle)`.
Data comes from Pi's on-disk presence registry plus the session transcript tail;
no network, no writes outside `%TEMP%`.

## Specs

S1. The pill enumerates live sessions as `Label (state) | Label (state)`, with
    `Label` = `header.label` from the presence record (the project name) and
    `state` = one of the words in S2.
S2. State vocabulary and precedence, first match wins:
    1. `offline` — the presence header carries a non-null `unavailable`.
    2. `blocked` — `counts.waiting > 0`, or any child task `status == "waiting"`.
    3. the inferred phase — `planning`, `exploring`, `implementing`, `checking`
       — when the session's last tool call maps to one.
    4. `working` — the turn is open (tool in flight, tool result pending, or a
       user message is the last record).
    5. `idle` — the last record is an assistant message with `stopReason: stop`.
S3. Liveness: a session is live when `now - header.heartbeat <= 15000` ms.
    Records are grouped by `sessionHash`; the incarnation with the newest
    heartbeat wins, so a killed session's leftovers never render.
S4. Ordering: `blocked`, then the working states (`planning`, `exploring`,
    `implementing`, `checking`, `working`), then `idle`; ties by newest
    heartbeat first.
S5. Width control: at most `MAX_ITEMS = 5` segments in the visible window. When
    more sessions are live, the pill appends ` +N` (N = hidden sessions) and a
    left click slides the window by exactly one session: the leftmost segment
    disappears and the next one is appended, wrapping past the last session. The
    window offset persists in `%TEMP%\pi-agents.page`. While every session
    already fits, a click leaves the window at offset 0.
S6. Zero live sessions prints an empty JSON string, so `hide_empty: true` hides
    the pill and it leaves no empty surface.
S7. Mouse wheel cannot scroll a custom widget: YASB implements `wheelEvent`
    only in komorebi/glazewm workspaces, komorebi stack, brightness, media and
    media_lite, and `CustomWidget` exposes only left/middle/right callbacks.
    The sliding window in S5 is the substitute.
S8. Left click = slide the window by one session. Right click = tkinter popup
    listing every live session with label, state, phase, child task, model and
    uptime.
S9. A script failure must be visible: on exception the pill renders
    `pi agents: error` instead of disappearing.
S10. Reads only `%USERPROFILE%\.pi\agent\gentle-agents\presence` and
     `%USERPROFILE%\.pi\agent\sessions`; writes only `%TEMP%\pi-agents.page`.
     No session content is copied into the label or the popup.

## Tasks

| ID | Task | Specs | Route | Commit |
|---|---|---|---|---|
| T1 | RED tests for state derivation, ordering, label and paging | S2-S5 | inline | `f90f8d7` |
| T2 | `windows/yasb/pi_agents.py` core (presence, tail, states, label) | S1-S4, S6, S10 | inline | `f90f8d7` |
| T3 | CLI: default JSON, `--next`, `--popup`, `--max` | S5, S7, S8, S9 | inline | `f90f8d7` |
| T4 | `config.yaml` widget block + `styles.css` rule | S1, S6 | inline | `feat(yasb): show live Pi agents in the bar` |
| T5 | README section + MANIFEST row | S7 | inline | `feat(yasb): show live Pi agents in the bar` |
| T6 | Deploy to `%USERPROFILE%\.config\yasb`, restart YASB, verify live | S1-S6 | inline | `feat(yasb): show live Pi agents in the bar` |
| T7 | Window of 5 and a slide-by-one cursor that replaces paging (supersedes the paging half of T3) | S5, S7, S8 | inline | `feat(yasb): slide the pi agents window by one session` |

## Log

L1 (user, verbatim):
> me gustaria crea un widget nuevo para yasb

L2 (user, verbatim):
> Quiero enumere los agentes activos dentro de pi agent/gentle shell (revisar cual es mejor) y me de el estado de cada uno: working, planning, idle, etc

L3 (user, verbatim):
> yo haria que que luzca mas o menos asi: Nombre del proyecto (estado) | Nomb... (estado) | ...
> la duda es si se puede hacer scroll horizontal con la rueda del raton por si hay mas de 3 corriendo para que no se haga un width enorme. luego ya buscaremos iconos o caracteres especiales para decorarlo

L4 (evidence, 2026-10-21): wheel scrolling is not expressible for a custom
widget. `grep -rn wheelEvent` over `amnweb/yasb@main` returns only
`src/core/ui/components/slider.py`, `views/themes.py`,
`widgets/glazewm/workspaces.py:481`, `widgets/komorebi/stack.py:490`,
`widgets/komorebi/workspaces.py:623`, `services/control_center/...`,
`services/wallpapers/gallery.py`, `services/weather/widgets.py`,
`services/open_meteo/widgets.py`, `widgets/yasb/brightness.py:459`,
`widgets/yasb/launchpad.py:553`, `widgets/yasb/media.py:1003`,
`widgets/yasb/media_lite.py:825,1104`. `src/core/widgets/base.py:122-136`
dispatches only left/middle/right in `_handle_mouse_events`.

L5 (evidence, 2026-10-21): presence registry shape verified live —
`~/.pi/agent/gentle-agents/presence/<sha256(sessionId)>.<incarnation>.header.json`
= `{schema, sessionHash, incarnation, label, heartbeat, generation, counts{running,queued,waiting,finished}, digest, unavailable}`
and the twin `.activity.json` = `{schema, sessionHash, incarnation, generation, activity{tasks[{summary{id,agent,label,status,model,createdAt,startedAt,endedAt,lastActivityAt}}]}}`.

L6 (evidence, 2026-10-21): session transcript shape —
`~/.pi/agent/sessions/<cwd-slug>/<ISO>_<sessionId>.jsonl`; assistant records
carry `message.stopReason` (`toolUse` / `stop`) and `content[].type == "toolCall"`
with `name` + `arguments`; tool results are `role: "toolResult"` with `toolName`.
Phase mapping mirrors `gentle-pi/lib/odd-phase-inference.ts`.

L7 (decision, 2026-10-21): `label: '{data}'` with a JSON **string** (not
`{data[text]}` with a dict) because YASB's `_update_label` formats the template
before the `hide_empty` check: `'{data[text]}'.format(data=None)` raises and
leaves the literal template painted. A falsy empty string hides the pill
correctly (`src/core/widgets/yasb/custom.py:101-124`).

L8 (evidence, 2026-10-21, T1-T3): RED first — `ModuleNotFoundError: No module
named 'pi_agents'`; after the implementation `py -B -m unittest discover -s
windows/yasb -p "test_*.py"` = 45 tests OK. Two expectations were corrected
while writing the tests, both against the code, not the tests: `tool_result`
carries the tool name, so the phase survives the wait for the next model step
(`read` stays `exploring`), and the `Session` fixture must set `phase` when the
state is a phase word, or the ordering check measures nothing.

L9 (evidence, 2026-10-21, T3): CLI measured on the live registry —
`py pi_agents.py` -> 3 segments; `--max 1` -> 1 segment + ` +2`; `--next` wraps
to page 0 when there is a single page and writes `%TEMP%\pi-agents.page`;
`--popup` stays open (killed by `timeout 4`, exit 124, no traceback).

L10 (evidence, 2026-10-21, T4-T6): deployed `config.yaml`, `styles.css` and
`pi_agents.py` to `%USERPROFILE%\.config\yasb` after checking the deployed
copies were identical to `HEAD` (no drift). YASB restarted at 20:09:46 (v2.0.7);
`Get-CimInstance Win32_Process` caught `py.exe` running
`C:\Users\verdu\.config\yasb\pi_agents.py`, 0 `[ERROR]`/`[WARNING]` lines in
`yasb.log` since the restart, and a screenshot of the bar reads
`dante-store (checking) | verdu.dotfiles (working) | verdu.dotfiles (idle)` in
the left cluster with the existing widgets untouched. `dante-store (checking)`
sorts first because a specific phase outranks plain `working` (S4).

L11 (review disposition, 2026-10-21): the work is left **unreviewed** by
candidate-scoped decision. `gentle_review inspect` offered `review.start` for
target `sha256:6965635bf402e94040de1fb78c5c4576a3fe7ac6877a0a79d79e54010490caa5`
(7 paths, 1201 changed lines, base `f9f88b0`, committed-only). The first START
omitted `baseRef`/`committedOnly`, so the facade projected `current-changes` and
blocked with `empty_candidate_base_ref_required` (no lineage); the retry carried
the offered base ref and the consent answer came back
`consent-declined-this-candidate`, with `lineage_created: false`,
`mutation_performed: false`, `correction_budget: 0`. Provider risk evidence named
"code that starts other processes in windows/yasb/config.yaml" (the widget's
`run_cmd` and its two `exec` callbacks). Nothing was reviewed, nothing was
corrected, and no authority was burned. Delivery is unaffected: both commits are
on `main`, unpushed.

L12 (user, 2026-10-21, verbatim):
> en mi escritorio te he dejado un svg del logotipo de pi. quiero añadirlo al inicio igual que lo hicimos en el de opencode

L13 (user, 2026-10-21, verbatim):
> me gusta que le has quitado el fondo negro, pero podrias hacer que todas las piezas internas sean blancas?

L14 (evidence, 2026-10-21): icon added with the `opencode_go` pattern — an empty
`<span class="icon"></span>` in the label plus `.pi-agents-widget .icon {
qproperty-pixmap: url("C:/Users/verdu/.config/yasb/pi-logo.png") }` at 18x18 with a
transparent background (no SVG at runtime: the frozen build is not guaranteed to
ship the Qt SVG plugin). Rasterized with `magick -density 1200 ... -resize 18x18
-depth 8 -strip`. Per L13 the three `fill` values are rewritten to `#FFFFFF`
first, so the mark is monochrome white; the coloured version was rejected after
seeing it in the bar. Verified by screenshot after a YASB restart (PID 19196, 0
ERROR/WARNING lines in `yasb.log`).

L15 (user, 2026-10-22, verbatim):
> quiero quitar el "|" que separa los agentes y si existen versalitas, usarlas para el estado sin los "()"

L16 (evidence, 2026-10-22, findings): real small caps do not exist here. A
`fontTools` sweep over the registered Nerd Fonts (`CaskaydiaCove NF/NFP/NFM`,
`JetBrainsMono NF/NFP/NFM/NL`) reports the Unicode small-caps block missing for
`b c d e f k m n o p r t w` (all families), i.e. `ᴡᴏʀᴋɪɴɢ` would be tofu; and Qt
rich text ignores `font-variant: small-caps` (a local PyQt6 render showed no
metric change). Faux small caps are the honest equivalent.

L17 (decision, 2026-10-22): `SEPARATOR = "&nbsp;&nbsp;"` (a gap, no glyph) and
`_segment()` emits `Project <span style="font-size:9px; letter-spacing:1px"><font
color=...>STATE</font></span>`; the parentheses are gone. Verified in the bar by
screenshot after a restart: `dante-store WORKING   verdu.dotfiles WORKING`, 0
ERROR/WARNING lines in `yasb.log`. Tests updated (45 OK), including assertions
that the label contains neither `|` nor `(`.

L18 (user, 2026-10-22, verbatim):
> ahora solo pregunta, podriamos hacer que al clicar en el widget de los agentes de pi, haga focus en la terminal que lo contiene?
> no es lo que busco. tenemos que confirmar si hay alguna manera de poder clicar cada agente de forma invividual o descartamos esta funcionalidad
> ok, pue anotamos, commit y push

L19 (investigation, 2026-10-22): per-agent clicks are **discarded**. Three
blockers, all verified, not assumed:

1. The grouper cannot have dynamic children:
   `GrouperWidgetConfig.widgets: list[str] = []` (yasb main,
   `src/core/validation/widgets/yasb/grouper.py:15`). Sessions are dynamic, so
   the most that could exist is a fixed number of slots (`pi_agent_1..N`),
   each bound to the Nth live session — scaffolding, not the feature.
2. There is no session -> process mapping: the presence header carries
   `schema, sessionHash, incarnation, label, heartbeat, generation, counts,
   digest, unavailable` and no `pid`; and the Pi processes are
   `node ...\pi-launcher.js -c` with no session id in the command line
   (observed PIDs 10604, 11864, 27088 with three live sessions).
3. Even with a pid there would be no tab to focus: Pi nulls the terminal
   title on purpose — `setTitle: () => { }` in
   `pi-coding-agent/dist/core/extensions/runner.js:146` — so Windows Terminal
   tab titles cannot identify a session, and the window title only reflects the
   active tab (observed "Help" on the single WT window, PID 7412).

Consequence: with one Windows Terminal window holding several tabs, every
per-session click would focus the same window, so N clickable slots would add
nothing over a single click target. Making it real needs `pid` in the presence
publisher (a package patch that `pi update` can overwrite), the session id in
the terminal title, and UI Automation to select the tab: a package-level
project, not a widget change.

L20 (decision, 2026-10-22): option A stays **available but not implemented** —
one click on the pill brings the terminal window forward (enumerate
`pi-launcher.js` processes, walk `ParentProcessId` to the process with a
`MainWindowHandle`, `ShowWindow(SW_RESTORE)` + `SetForegroundWindow`), with
left = focus, middle = page, right = detail table. The user did not ask for it
now; the pill remains read-only with left = page, right = popup. Nothing in the
widget changed for this line of investigation.

L21 (user, 2026-10-24, verbatim):
> ok, gracias. veo que si hay mas de 3 se paginan. amplia eso a 5

L22 (user, 2026-10-24, verbatim):
> no solo eso, si no que en lugar de cambiar de pagina, muestre el siguiente y oculte el primero (como un falso slider)

L23 (decision, 2026-10-24): L22 replaces paging, it does not add a second mode.
`format_label` now returns `(text, offset, count)` over a circular window, the
` +N` count stays constant (it is no longer a per-page remainder), and `--next`
advances one session with `next_offset`; the offset is a no-op while every
session fits. Renamed `next_page(page, pages)` to `next_offset(offset, count,
max_items)`; the `%TEMP%\pi-agents.page` file and the `--page-file` flag keep
their names because their content is still one integer cursor, now an offset.

L24 (evidence, 2026-10-24, T7): RED first — 7 failures + 2 errors against the
paging tests; after the change `py -B -m unittest discover -s windows/yasb -p
"test_*.py"` = 49 tests OK. Measured on the live registry with `--max 2` and a
scratch cursor: `[p0 p1] [p1 p2] [p2 p3] [p3 p0] [p0 p1]` — the leftmost leaves
and the next enters, wrapping. With 4 live sessions and the default window the
pill shows all of them and `--next` leaves the cursor at 0, as designed.
`import math` was removed: `math.ceil` was the only use and the window no longer
computes page counts.

L25 (evidence, 2026-10-24, T7 deployed): the deployed copy in
`%USERPROFILE%\.config\yasb\pi_agents.py` was verified identical to `HEAD`
before copying (line endings aside), then replaced with the working-tree file;
YASB killed (PID 1412) and restarted v2.0.7 (PID 21132) with no new error lines
in `yasb.log`. Deployed script measured with `--max 2` on a scratch cursor:
`[p0 p1] [p1 p2] [p2 p3]` — slide by one. Live pill with the default window of 5
and four live sessions renders all four and leaves the cursor at offset 0.

L26 (delivery, 2026-10-24, T7): one work-unit commit on `main`, subject
`feat(yasb): slide the pi agents window by one session`, carrying the widget,
its tests, the README, the `config.yaml` comment and this document; the exact
sha is in `git log`. The unrelated working-tree edits in
`windows/nushell/config.nu` and `windows/powershell/user_profile.ps1` (the `gs`
alias) belong to another task and were left out of this commit.
