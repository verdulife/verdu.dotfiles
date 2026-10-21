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
S5. Width control: at most `MAX_ITEMS = 3` segments per page. When more sessions
    are live, the pill appends ` +N` (N = hidden sessions) and a left click
    cycles to the next page. Page index persists in `%TEMP%\pi-agents.page`.
S6. Zero live sessions prints an empty JSON string, so `hide_empty: true` hides
    the pill and it leaves no empty surface.
S7. Mouse wheel cannot scroll a custom widget: YASB implements `wheelEvent`
    only in komorebi/glazewm workspaces, komorebi stack, brightness, media and
    media_lite, and `CustomWidget` exposes only left/middle/right callbacks.
    Paging in S5 is the substitute.
S8. Left click = next page. Right click = tkinter popup listing every live
    session with label, state, phase, child task, model and uptime.
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
