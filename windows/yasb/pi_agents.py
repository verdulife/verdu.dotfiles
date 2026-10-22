#!/usr/bin/env python3
"""YASB custom widget: the live Pi agents on this machine and what each is doing.

The bar label is one JSON string built from three local sources only:

  %USERPROFILE%\\.pi\\agent\\gentle-agents\\presence\\<hash>.<incarnation>.header.json
      one record per running Pi session: label, heartbeat, child-task counters
  ...\\<hash>.<incarnation>.activity.json
      the child tasks of that session (agent, label, status)
  %USERPROFILE%\\.pi\\agent\\sessions\\<project>\\<iso>_<sessionId>.jsonl
      the session transcript; its tail says whether the turn is open and which
      tool ran last, which is what the ODD phase is inferred from

Nothing is written except the page cursor in %TEMP%. No network, and no
transcript content ever reaches the label or the popup.

Usage:
    pi_agents.py             one JSON string for the bar label
    pi_agents.py --next      advance the page first, then the same payload
    pi_agents.py --popup     tkinter table with every live session
"""

from __future__ import annotations

import argparse
import hashlib
import html
import json
import math
import os
import re
import sys
import tempfile
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path

# A session is live while its presence heartbeat is this fresh. Pi's own
# presence publisher heartbeats every 5 s and treats 15 s as the live window
# (gentle-pi lib/orchestrator-presence.ts), so the two agree by construction.
LIVE_MS = 15_000

# Segments per page. Three keeps the pill near the width of the sysinfo group;
# anything longer is reachable with a left click (see README).
MAX_ITEMS = 3

SEPARATOR = "&nbsp;&nbsp;"

# Small caps are "faux": no Nerd Font on this machine carries the Unicode
# small-caps block (fontTools: CaskaydiaCove NF/NFP/NFM and JetBrainsMono NF*
# lack the glyphs for b c d e f k m n o p r t w, so a word such as "working"
# cannot be spelled in small caps) and Qt rich text ignores
# `font-variant: small-caps`, so the state is upper case at ~70% of the label
# size, which is what faux small caps are.
STATE_FONT_SIZE = 9

# How much of a transcript tail is parsed. Session files reach several MB, and
# only the last few records decide the state.
TAIL_BYTES = 128 * 1024

STATE_COLORS = {
    "working": "#8fb3d9",
    "planning": "#c9a8e8",
    "exploring": "#8fc7d9",
    "implementing": "#8fd99f",
    "checking": "#e8d18f",
    "deciding": "#e8b48f",
    "blocked": "#e88f8f",
    "idle": "#7f8c8d",
    "offline": "#6b6b6b",
}

# Sort rank, then "has a specific phase" (0 before 1), then newest heartbeat.
STATE_RANK = {
    "blocked": 0,
    "deciding": 1,
    "planning": 1,
    "exploring": 1,
    "implementing": 1,
    "checking": 1,
    "working": 1,
    "idle": 2,
    "offline": 3,
}

# Mirrors gentle-pi lib/odd-phase-inference.ts: the phase the tools themselves
# imply, so the bar does not depend on the model reporting a phase.
TOOL_PHASES = {
    "read": "exploring",
    "grep": "exploring",
    "find": "exploring",
    "ls": "exploring",
    "codegraph": "exploring",
    "ask_user_choice": "deciding",
    "ask_user_question": "deciding",
    "todo": "planning",
    "gentle_review": "checking",
    "gentle_review_scope": "checking",
    "gentle_review_capture": "checking",
    "gentle_review_capture_group": "checking",
}

DELEGATED_PHASES = {
    "gentle-ai-worker": "implementing",
    "gentle-ai-verify": "checking",
    "gentle-ai-explore": "exploring",
}

WRITE_TOOLS = {"edit", "write"}
SHELL_TOOLS = {"bash", "powershell"}

CHECKING_COMMANDS = [
    re.compile(r"^(pnpm|npm|yarn|bun)\s+(run\s+)?(test|typecheck|lint|build|check)\b"),
    re.compile(r"^node\b.*\s--test\b"),
    re.compile(r"^((npx|pnpx|bunx)\s+|(pnpm|yarn)\s+exec\s+)?(vitest|jest|mocha|tsc|eslint|pytest)\b"),
    re.compile(r"^python3?\s+-m\s+pytest\b"),
    re.compile(r"^py\s+(-m\s+)?(pytest|unittest)\b"),
    re.compile(r"^go\s+(test|build|vet)\b"),
    re.compile(r"^cargo\s+(test|build|check|clippy)\b"),
    re.compile(r"^make\b"),
    re.compile(r"^gh\s+pr\s+checks\b"),
    re.compile(r"^gh\s+run\s+(view|watch|list)\b"),
]

EXPLORING_COMMANDS = [
    re.compile(
        r"^git\s+(status|log|diff|show|blame|rev-parse|rev-list|merge-base|ls-files|ls-remote|ls-tree|"
        r"cat-file|describe|shortlog|reflog|grep|check-ignore|for-each-ref|name-rev|count-objects)\b"
    ),
    re.compile(r"^git\s+(branch|tag|remote|worktree|stash)\s+(-[a-zA-Z]+|--[a-z-]+|list)?\s*$"),
    re.compile(r"^git\s+config\s+(--get|--get-all|--get-regexp|-l|--list)\b"),
    re.compile(r"^gh\s+(pr|issue|repo|release)\s+(view|list|diff|status)\b"),
    re.compile(
        r"^(ls|cat|head|tail|grep|egrep|rg|wc|pwd|tree|stat|file|which|type|readlink|realpath|dirname|"
        r"basename|cut|uniq|tr|nl|column|strings|diff|cmp|od|xxd|hexdump|shasum|sha256sum|md5|md5sum|"
        r"du|df|date|uname|whoami|ps|pgrep|lsof|jq|awk)\b"
    ),
    re.compile(r"^command\s+-v\b"),
    re.compile(r"^(\[\[?|test)\s"),
    re.compile(r"^sort\b(?!.*\s(-o|--output)\b)"),
    re.compile(r"^sed\b(?!.*\s(-[a-zA-Z]*i|--in-place)\b)"),
    re.compile(r"^find\b(?!.*\s-(delete|exec|execdir|ok|okdir|fprint\w*)\b)"),
]

NEUTRAL_COMMANDS = [
    re.compile(r"^(cd|pushd|popd|echo|printf|sleep|true|false|export|set)\b"),
    re.compile(r"^(done|fi|esac|\}|\))$"),
    re.compile(r"^for\s+\w+(\s+in\b.*)?$"),
]

LEADING_KEYWORDS = re.compile(r"^(do|then|else|elif|if|while|until|time|!|\{|\()\s+")

SHELL_SPLIT = re.compile(r"\s*(?:&&|\|\||;|\||\n)\s*")


@dataclass
class Session:
    """One live Pi session, already reduced to what the bar and popup show."""

    session_hash: str
    label: str
    heartbeat: int
    state: str
    phase: str | None = None
    child: str | None = None
    model: str | None = None
    started_at: int | None = None
    session_id: str | None = None


# --------------------------------------------------------------------------- #
# Phase inference (mirrors gentle-pi's tool mapping)
# --------------------------------------------------------------------------- #


def infer_phase(tool_name: str | None, args: dict | None) -> str | None:
    """Return the ODD phase implied by a tool call, or None when it carries none."""
    if not tool_name:
        return None
    name = re.sub(r"^mcp__.+?__", "", tool_name)
    args = args if isinstance(args, dict) else {}
    if name == "subagent_run":
        agent = args.get("agent")
        return DELEGATED_PHASES.get(agent) if isinstance(agent, str) else None
    if name in WRITE_TOOLS:
        path = args.get("path") or args.get("file_path")
        if isinstance(path, str) and re.search(r"(^|/)odd/tasks/", path.replace("\\", "/")):
            return "planning"
        return "implementing"
    if name in SHELL_TOOLS:
        return infer_shell_phase(args.get("command"))
    return TOOL_PHASES.get(name)


def infer_shell_phase(command: object) -> str | None:
    """A shell call checks when any segment runs a checker, explores only when
    every segment is read-only inspection; anything else is ambiguous."""
    if not isinstance(command, str) or not command.strip():
        return None
    segments = []
    for raw in SHELL_SPLIT.split(command):
        segment = LEADING_KEYWORDS.sub("", raw.strip()).strip()
        if segment and not _is_neutral(segment):
            segments.append(segment)
    if not segments:
        return None
    if any(_matches_any(CHECKING_COMMANDS, s) for s in segments):
        return "checking"
    return "exploring" if all(_matches_any(EXPLORING_COMMANDS, s) for s in segments) else None


def _matches_any(patterns: list[re.Pattern[str]], text: str) -> bool:
    return any(p.match(text) for p in patterns)


def _is_neutral(segment: str) -> bool:
    return _matches_any(NEUTRAL_COMMANDS, segment)


# --------------------------------------------------------------------------- #
# Transcript tail
# --------------------------------------------------------------------------- #


def read_tail(path: str | os.PathLike[str] | None, max_bytes: int = TAIL_BYTES) -> list[dict]:
    """Parse the last records of a session transcript; tolerate a partial first line."""
    if not path:
        return []
    try:
        with open(path, "rb") as handle:
            handle.seek(0, os.SEEK_END)
            size = handle.tell()
            start = max(0, size - max_bytes)
            handle.seek(start)
            raw = handle.read()
    except OSError:
        return []
    lines = raw.decode("utf-8", errors="replace").splitlines()
    if start > 0 and lines:
        lines = lines[1:]  # the first line is almost certainly cut in half
    records = []
    for line in lines[-400:]:
        line = line.strip()
        if not line:
            continue
        try:
            record = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(record, dict):
            records.append(record)
    return records


def summarize_tail(records: list[dict]) -> dict:
    """Reduce a transcript tail to the last message and what it implies."""
    empty = {"kind": "unknown", "tool": None, "args": {}}
    for record in reversed(records):
        message = record.get("message")
        if not isinstance(message, dict):
            continue
        role = message.get("role")
        if role == "assistant":
            stop = message.get("stopReason")
            if stop == "stop":
                return {"kind": "turn_closed", "tool": None, "args": {}}
            if stop == "toolUse":
                calls = [p for p in message.get("content") or [] if isinstance(p, dict) and p.get("type") == "toolCall"]
                if calls:
                    last = calls[-1]
                    args = last.get("arguments")
                    return {
                        "kind": "tool_use",
                        "tool": last.get("name"),
                        "args": args if isinstance(args, dict) else {},
                    }
            return {"kind": "turn_open", "tool": None, "args": {}}
        if role == "toolResult":
            return {"kind": "tool_result", "tool": message.get("toolName"), "args": {}}
        if role == "user":
            return {"kind": "turn_open", "tool": None, "args": {}}
        return empty
    return empty


# --------------------------------------------------------------------------- #
# State
# --------------------------------------------------------------------------- #


def derive_state(header: dict, activity: dict, tail: list[dict]) -> tuple[str, str | None, str | None]:
    """Return (state, phase, child) for one session. Precedence: offline, blocked,
    an active turn (with its inferred phase), idle."""
    if header.get("unavailable"):
        return "offline", None, None

    tasks = _task_summaries(activity)
    counts = header.get("counts") if isinstance(header.get("counts"), dict) else {}
    waiting = [t for t in tasks if t.get("status") == "waiting"]
    if waiting or _count(counts, "waiting") > 0:
        return "blocked", None, _child_text(waiting[0] if waiting else None, "waiting")

    summary = summarize_tail(tail)
    phase = _phase_from_summary(summary)
    running = [t for t in tasks if t.get("status") == "running"]
    active = (
        summary["kind"] in {"tool_use", "tool_result", "turn_open"}
        or bool(running)
        or _count(counts, "running") > 0
        or _count(counts, "queued") > 0
    )
    if not active:
        return "idle", None, None
    return phase or "working", phase, _child_text(running[0], "running") if running else None


def _phase_from_summary(summary: dict) -> str | None:
    if summary["kind"] not in {"tool_use", "tool_result"}:
        return None
    return infer_phase(summary["tool"], summary["args"])


def _task_summaries(activity: dict) -> list[dict]:
    tasks = ((activity or {}).get("activity") or {}).get("tasks")
    if not isinstance(tasks, list):
        return []
    summaries = []
    for entry in tasks:
        summary = entry.get("summary") if isinstance(entry, dict) else None
        if isinstance(summary, dict):
            summaries.append(summary)
    return summaries


def _child_text(task: dict | None, status: str) -> str:
    if not task:
        return f"task {status}"
    agent = task.get("agent") or "subagent"
    label = task.get("label") or ""
    text = f"{agent} · {status}"
    return f"{text} · {label}" if label else text


def _count(counts: dict, key: str) -> int:
    value = counts.get(key)
    return value if isinstance(value, int) else 0


# --------------------------------------------------------------------------- #
# Presence + transcript collection
# --------------------------------------------------------------------------- #


def session_hash_of(session_id: str) -> str:
    """Pi keys the presence registry by sha256 of the session id."""
    return hashlib.sha256(session_id.encode("utf-8")).hexdigest()


def collect_sessions(
    presence_dir: str | os.PathLike[str],
    sessions_dir: str | os.PathLike[str],
    now_ms: int,
    live_ms: int = LIVE_MS,
) -> list[Session]:
    """Return every live session, newest incarnation per session hash."""
    best: dict[str, tuple[int, dict, Path]] = {}
    presence_path = Path(presence_dir)
    try:
        headers = list(presence_path.glob("*.header.json"))
    except OSError:
        headers = []
    for path in headers:
        header = _load_json(path)
        if not isinstance(header, dict) or header.get("schema") != 1:
            continue
        session_hash = header.get("sessionHash")
        heartbeat = header.get("heartbeat")
        if not isinstance(session_hash, str) or not isinstance(heartbeat, (int, float)):
            continue
        current = best.get(session_hash)
        if current is None or heartbeat > current[0]:
            best[session_hash] = (int(heartbeat), header, path)

    transcripts = _transcript_index(sessions_dir)
    sessions = []
    for session_hash, (heartbeat, header, path) in best.items():
        if now_ms - heartbeat > live_ms:
            continue
        activity = _load_json(path.with_name(f"{session_hash}.{header.get('incarnation')}.activity.json")) or {}
        transcript, started_at = transcripts.get(session_hash, (None, None))
        tail = read_tail(transcript)
        state, phase, child = derive_state(header, activity, tail)
        running = [t for t in _task_summaries(activity) if t.get("status") == "running"]
        sessions.append(
            Session(
                session_hash=session_hash,
                label=str(header.get("label") or "pi"),
                heartbeat=heartbeat,
                state=state,
                phase=phase,
                child=child,
                model=(running[0].get("model") if running else None),
                started_at=started_at,
                session_id=_session_id_from_path(transcript),
            )
        )
    return sessions


def _transcript_index(sessions_dir: str | os.PathLike[str]) -> dict[str, tuple[Path, int | None]]:
    """Map sha256(sessionId) -> (transcript path, start time) for every session file."""
    index: dict[str, tuple[Path, int | None]] = {}
    try:
        paths = list(Path(sessions_dir).glob("*/*.jsonl"))
    except OSError:
        return index
    for path in paths:
        session_id = _session_id_from_path(path)
        if session_id:
            index[session_hash_of(session_id)] = (path, _started_at(path))
    return index


def _session_id_from_path(path: str | os.PathLike[str] | None) -> str | None:
    if not path:
        return None
    stem = Path(path).stem
    if "_" not in stem:
        return None
    return stem.split("_", 1)[1] or None


def _started_at(path: Path) -> int | None:
    stamp = Path(path).stem.split("_", 1)[0]
    try:
        parsed = datetime.strptime(stamp, "%Y-%m-%dT%H-%M-%S-%fZ").replace(tzinfo=timezone.utc)
    except ValueError:
        return None
    return int(parsed.timestamp() * 1000)


def _load_json(path: Path) -> dict | None:
    try:
        with open(path, encoding="utf-8") as handle:
            data = json.load(handle)
    except (OSError, json.JSONDecodeError, UnicodeDecodeError):
        return None
    return data if isinstance(data, dict) else None


# --------------------------------------------------------------------------- #
# Label
# --------------------------------------------------------------------------- #


def sort_key(session: Session) -> tuple[int, int, int]:
    return (STATE_RANK.get(session.state, 1), 0 if session.phase else 1, -session.heartbeat)


def next_page(page: int, pages: int) -> int:
    return 0 if pages <= 0 else (page + 1) % pages


def format_label(sessions: list[Session], page: int, max_items: int) -> tuple[str, int, int]:
    """Return (label html, clamped page, page count)."""
    ordered = sorted(sessions, key=sort_key)
    if not ordered:
        return "", 0, 0
    max_items = max(1, max_items)
    pages = max(1, math.ceil(len(ordered) / max_items))
    page = page % pages
    window = ordered[page * max_items : (page + 1) * max_items]
    text = SEPARATOR.join(_segment(session) for session in window)
    hidden = len(ordered) - len(window)
    if hidden > 0:
        text += f" +{hidden}"
    return text, page, pages


def _segment(session: Session) -> str:
    color = STATE_COLORS.get(session.state, "#c0c0c0")
    state = session.state.upper()
    return (
        f'{html.escape(session.label)} <span style="font-size:{STATE_FONT_SIZE}px; letter-spacing:1px">'
        f'<font color="{color}">{state}</font></span>'
    )


def error_payload() -> str:
    """A visible failure beats a pill that silently disappears."""
    return '<font color="#e88f8f">pi agents: error</font>'


# --------------------------------------------------------------------------- #
# Popup
# --------------------------------------------------------------------------- #


def show_popup(sessions: list[Session], now_ms: int) -> None:
    """A read-only table of every live session; the bar only shows one page."""
    import tkinter as tk
    from tkinter import ttk

    background = "#1b1b1f"
    foreground = "#e6e6e6"
    root = tk.Tk()
    root.title(f"Pi agents — {len(sessions)} live")
    root.configure(background=background)
    root.attributes("-topmost", True)

    style = ttk.Style(root)
    style.theme_use("clam")
    style.configure("Agents.Treeview", background=background, fieldbackground=background,
                    foreground=foreground, rowheight=24, borderwidth=0)
    style.configure("Agents.Treeview.Heading", background="#26262c", foreground=foreground)
    style.map("Agents.Treeview", background=[("selected", "#3a3a44")])

    columns = ("label", "state", "phase", "child", "model", "session", "uptime")
    tree = ttk.Treeview(root, columns=columns, show="headings", style="Agents.Treeview", height=max(3, len(sessions)))
    headings = {"label": "Project", "state": "State", "phase": "Phase", "child": "Child task",
                "model": "Model", "session": "Session", "uptime": "Uptime"}
    widths = {"label": 190, "state": 100, "phase": 100, "child": 260, "model": 200, "session": 90, "uptime": 80}
    for column in columns:
        tree.heading(column, text=headings[column])
        tree.column(column, width=widths[column], anchor="w", stretch=True)
    for session in sorted(sessions, key=sort_key):
        tree.insert("", "end", values=(
            session.label,
            session.state,
            session.phase or "—",
            session.child or "—",
            session.model or "—",
            (session.session_id or "—")[:8],
            _uptime(session, now_ms),
        ))
    tree.pack(fill="both", expand=True, padx=8, pady=8)
    if not sessions:
        tree.insert("", "end", values=("no live session", "—", "—", "—", "—", "—", "—"))
    root.bind("<Escape>", lambda _event: root.destroy())
    root.mainloop()


def _uptime(session: Session, now_ms: int) -> str:
    reference = session.started_at if session.started_at else session.heartbeat
    seconds = max(0, int((now_ms - reference) / 1000))
    if seconds < 60:
        return f"{seconds}s"
    if seconds < 3600:
        return f"{seconds // 60}m"
    return f"{seconds // 3600}h{(seconds % 3600) // 60:02d}m"


# --------------------------------------------------------------------------- #
# CLI
# --------------------------------------------------------------------------- #


def default_presence_dir() -> Path:
    return Path.home() / ".pi" / "agent" / "gentle-agents" / "presence"


def default_sessions_dir() -> Path:
    return Path.home() / ".pi" / "agent" / "sessions"


def default_page_file() -> Path:
    return Path(tempfile.gettempdir()) / "pi-agents.page"


def _read_page(path: Path) -> int:
    try:
        return max(0, int(path.read_text(encoding="utf-8").strip()))
    except (OSError, ValueError):
        return 0


def _write_page(path: Path, page: int) -> None:
    try:
        path.write_text(str(page), encoding="utf-8")
    except OSError:
        pass


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Live Pi agents for the YASB bar")
    parser.add_argument("--presence", help="presence registry directory")
    parser.add_argument("--sessions", help="Pi sessions directory")
    parser.add_argument("--page-file", help="file that stores the current page")
    parser.add_argument("--max", type=int, default=MAX_ITEMS, help="segments per page")
    parser.add_argument("--next", action="store_true", help="advance the page before rendering")
    parser.add_argument("--popup", action="store_true", help="open the detail table")
    parser.add_argument("--now", type=int, help="current time in ms (tests)")
    args = parser.parse_args(argv)

    now_ms = args.now if args.now is not None else int(time.time() * 1000)
    presence_dir = Path(args.presence) if args.presence else default_presence_dir()
    sessions_dir = Path(args.sessions) if args.sessions else default_sessions_dir()
    page_file = Path(args.page_file) if args.page_file else default_page_file()

    try:
        sessions = collect_sessions(presence_dir, sessions_dir, now_ms)
        page = _read_page(page_file)
        if args.next:
            _, _, pages = format_label(sessions, page, args.max)
            page = next_page(page, pages)
            _write_page(page_file, page)
        if args.popup:
            show_popup(sessions, now_ms)
            return 0
        text, _, _ = format_label(sessions, page, args.max)
        print(json.dumps(text))
    except Exception:  # noqa: BLE001 - the bar must show the failure, not vanish
        print(json.dumps(error_payload()))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
