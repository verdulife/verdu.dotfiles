"""Tests for the YASB Pi agents widget helper.

Run from the repository root:

    py -B -m unittest discover -s windows/yasb -p "test_*.py" -v

The script is imported as a module (it lives next to this file); every check
goes through its public functions, never through internal helpers.
"""

from __future__ import annotations

import contextlib
import io
import json
import os
import tempfile
import unittest
from pathlib import Path

import pi_agents as pa

NOW_MS = 1_792_600_000_000
LIVE_MS = pa.LIVE_MS


def header(label: str, heartbeat: int, *, session_hash: str = "h1", running: int = 0, waiting: int = 0,
           queued: int = 0, unavailable: object = None, incarnation: str = "inc1") -> dict:
    return {
        "schema": 1,
        "sessionHash": session_hash,
        "incarnation": incarnation,
        "label": label,
        "heartbeat": heartbeat,
        "generation": 1,
        "counts": {"running": running, "queued": queued, "waiting": waiting, "finished": 0},
        "digest": "d",
        "unavailable": unavailable,
    }


def activity(*tasks: dict, session_hash: str = "h1", incarnation: str = "inc1") -> dict:
    return {
        "schema": 1,
        "sessionHash": session_hash,
        "incarnation": incarnation,
        "generation": 1,
        "activity": {"tasks": [{"summary": t, "thread": {"version": 1, "dropped": 0, "items": []}} for t in tasks]},
    }


def task(status: str, *, agent: str = "gentle-ai-explore", label: str = "map the repo",
         model: str = "opencode-go/deepseek-v4.1-flash") -> dict:
    return {"id": "t1", "agent": agent, "label": label, "status": status, "model": model,
            "createdAt": NOW_MS - 60_000, "startedAt": NOW_MS - 60_000, "endedAt": None,
            "lastActivityAt": NOW_MS - 1_000}


def assistant_tool(name: str, arguments: dict | None = None) -> dict:
    return {
        "type": "message",
        "message": {
            "role": "assistant",
            "stopReason": "toolUse",
            "content": [
                {"type": "thinking", "text": "..."},
                {"type": "toolCall", "id": "c1", "name": name, "arguments": arguments or {}},
            ],
        },
    }


def tool_result(name: str) -> dict:
    return {"type": "message", "message": {"role": "toolResult", "toolName": name, "content": [{"type": "text", "text": "ok"}]}}


def assistant_stop() -> dict:
    return {"type": "message", "message": {"role": "assistant", "stopReason": "stop", "content": [{"type": "text", "text": "done"}]}}


def user_message() -> dict:
    return {"type": "message", "message": {"role": "user", "content": [{"type": "text", "text": "do it"}]}}


class PhaseInferenceTests(unittest.TestCase):
    def test_read_tool_explores(self):
        self.assertEqual(pa.infer_phase("read", {"path": "README.md"}), "exploring")

    def test_edit_tool_implements(self):
        self.assertEqual(pa.infer_phase("edit", {"path": "src/main.py"}), "implementing")

    def test_write_to_odd_tasks_is_planning(self):
        self.assertEqual(pa.infer_phase("write", {"path": "odd/tasks/feature.md"}), "planning")

    def test_write_to_odd_tasks_with_windows_separators_is_planning(self):
        self.assertEqual(pa.infer_phase("write", {"path": r"odd\tasks\feature.md"}), "planning")

    def test_todo_tool_is_planning(self):
        self.assertEqual(pa.infer_phase("todo", {"action": "write"}), "planning")

    def test_asking_the_human_is_deciding(self):
        self.assertEqual(pa.infer_phase("ask_user_question", {}), "deciding")

    def test_checking_shell_command_is_checking(self):
        self.assertEqual(pa.infer_phase("bash", {"command": "py -m pytest -q"}), "checking")

    def test_read_only_shell_command_explores(self):
        self.assertEqual(pa.infer_phase("bash", {"command": "git status --short"}), "exploring")

    def test_mutating_shell_command_has_no_phase(self):
        self.assertIsNone(pa.infer_phase("bash", {"command": "npm install left-pad"}))

    def test_delegated_explorer_explores(self):
        self.assertEqual(pa.infer_phase("subagent_run", {"agent": "gentle-ai-explore"}), "exploring")

    def test_delegated_verifier_checks(self):
        self.assertEqual(pa.infer_phase("subagent_run", {"agent": "gentle-ai-verify"}), "checking")

    def test_unknown_tool_has_no_phase(self):
        self.assertIsNone(pa.infer_phase("mem_save", {}))


class TailSummaryTests(unittest.TestCase):
    def test_last_tool_call_wins(self):
        tail = [user_message(), assistant_tool("bash", {"command": "git log"})]
        summary = pa.summarize_tail(tail)
        self.assertEqual(summary["kind"], "tool_use")
        self.assertEqual(summary["tool"], "bash")
        self.assertEqual(summary["args"], {"command": "git log"})

    def test_tool_result_means_the_turn_is_open(self):
        tail = [assistant_tool("read", {"path": "a"}), tool_result("read")]
        self.assertEqual(pa.summarize_tail(tail)["kind"], "tool_result")

    def test_assistant_stop_means_idle(self):
        tail = [tool_result("read"), assistant_stop()]
        self.assertEqual(pa.summarize_tail(tail)["kind"], "turn_closed")

    def test_user_message_means_a_turn_is_starting(self):
        tail = [assistant_stop(), user_message()]
        self.assertEqual(pa.summarize_tail(tail)["kind"], "turn_open")

    def test_non_message_records_are_ignored(self):
        tail = [{"type": "model_change"}, {"type": "label"}]
        self.assertEqual(pa.summarize_tail(tail)["kind"], "unknown")

    def test_empty_tail_is_unknown(self):
        self.assertEqual(pa.summarize_tail([])["kind"], "unknown")


class StateTests(unittest.TestCase):
    def test_unavailable_header_is_offline(self):
        h = header("verdu.dotfiles", NOW_MS - 100, unavailable={"reason": "transport"})
        state, _, _ = pa.derive_state(h, activity(), [])
        self.assertEqual(state, "offline")

    def test_waiting_child_is_blocked(self):
        h = header("verdu.dotfiles", NOW_MS - 100, waiting=1)
        state, _, child = pa.derive_state(h, activity(task("waiting")), [])
        self.assertEqual(state, "blocked")
        self.assertIn("waiting", child)

    def test_running_child_with_read_tail_reports_the_phase(self):
        h = header("verdu.dotfiles", NOW_MS - 100, running=1)
        state, phase, child = pa.derive_state(h, activity(task("running")), [assistant_tool("read", {"path": "x"})])
        self.assertEqual(state, "exploring")
        self.assertEqual(phase, "exploring")
        self.assertIn("gentle-ai-explore", child)

    def test_open_turn_without_a_phase_is_working(self):
        h = header("verdu.dotfiles", NOW_MS - 100)
        state, phase, _ = pa.derive_state(h, activity(), [assistant_tool("bash", {"command": "npm ci"})])
        self.assertEqual(state, "working")
        self.assertIsNone(phase)

    def test_tool_result_keeps_the_phase_of_the_tool_that_ran(self):
        h = header("verdu.dotfiles", NOW_MS - 100)
        state, phase, _ = pa.derive_state(h, activity(), [assistant_tool("read", {}), tool_result("read")])
        self.assertEqual((state, phase), ("exploring", "exploring"))

    def test_phase_less_tool_result_is_working(self):
        h = header("verdu.dotfiles", NOW_MS - 100)
        state, _, _ = pa.derive_state(h, activity(), [assistant_tool("bash", {"command": "npm ci"}), tool_result("bash")])
        self.assertEqual(state, "working")

    def test_closed_turn_is_idle(self):
        h = header("verdu.dotfiles", NOW_MS - 100)
        state, _, _ = pa.derive_state(h, activity(), [tool_result("read"), assistant_stop()])
        self.assertEqual(state, "idle")

    def test_missing_transcript_falls_back_to_the_counters(self):
        h = header("verdu.dotfiles", NOW_MS - 100)
        state, _, _ = pa.derive_state(h, activity(), [])
        self.assertEqual(state, "idle")


class LabelTests(unittest.TestCase):
    def session(self, label: str, state: str, heartbeat: int = NOW_MS) -> pa.Session:
        return pa.Session(session_hash=label, label=label, heartbeat=heartbeat, state=state,
                          phase=state if state in pa.STATE_RANK and state not in {"working", "idle", "blocked", "offline"} else None,
                          child=None, model=None, started_at=None, session_id=None)

    def test_two_sessions_render_name_and_small_caps_state(self):
        text, offset, count = pa.format_label([self.session("verdu.dotfiles", "working"),
                                               self.session("vre-mcp", "idle")], 0, 3)
        self.assertEqual(
            text,
            'verdu.dotfiles <span style="font-size:9px; letter-spacing:1px"><font color="#8fb3d9">WORKING</font></span>'
            '&nbsp;&nbsp;'
            'vre-mcp <span style="font-size:9px; letter-spacing:1px"><font color="#7f8c8d">IDLE</font></span>',
        )
        self.assertEqual((offset, count), (0, 2))
        self.assertNotIn("|", text)
        self.assertNotIn("(", text)

    def test_default_window_holds_five_sessions(self):
        sessions = [self.session(f"p{i}", "idle") for i in range(6)]
        text, _, count = pa.format_label(sessions, 0, pa.MAX_ITEMS)
        self.assertEqual(count, 6)
        self.assertEqual(text.count("&nbsp;&nbsp;"), 4)  # five segments, four gaps
        self.assertTrue(text.endswith(" +1"), text)

    def test_overflow_shows_the_hidden_count(self):
        sessions = [self.session(f"p{i}", "idle") for i in range(5)]
        text, offset, count = pa.format_label(sessions, 0, 3)
        self.assertTrue(text.endswith(" +2"), text)
        self.assertEqual((offset, count), (0, 5))

    def test_sliding_window_hides_the_first_and_shows_the_next(self):
        sessions = [self.session(f"p{i}", "idle") for i in range(5)]
        text, offset, count = pa.format_label(sessions, 1, 3)
        self.assertTrue(text.startswith("p1 <span"), text)
        self.assertNotIn("p0 <span", text)
        self.assertIn("p3 <span", text)
        self.assertTrue(text.endswith(" +2"), text)
        self.assertEqual((offset, count), (1, 5))

    def test_window_wraps_past_the_last_session(self):
        sessions = [self.session(f"p{i}", "idle") for i in range(5)]
        text, offset, _ = pa.format_label(sessions, 4, 3)
        self.assertTrue(text.startswith("p4 <span"), text)
        self.assertIn("p0 <span", text)
        self.assertEqual(offset, 4)

    def test_out_of_range_offset_wraps(self):
        sessions = [self.session(f"p{i}", "idle") for i in range(5)]
        text, offset, _ = pa.format_label(sessions, 7, 3)
        self.assertEqual(offset, 2)
        self.assertTrue(text.startswith("p2 <span"), text)

    def test_offset_is_ignored_when_every_session_fits(self):
        sessions = [self.session(f"p{i}", "idle") for i in range(3)]
        text, offset, count = pa.format_label(sessions, 2, 5)
        self.assertEqual((offset, count), (0, 3))
        self.assertTrue(text.startswith("p0 <span"), text)
        self.assertNotIn("+", text)

    def test_no_sessions_render_nothing(self):
        self.assertEqual(pa.format_label([], 0, 3), ("", 0, 0))

    def test_label_is_html_escaped(self):
        text, _, _ = pa.format_label([self.session("a<b>&c", "idle")], 0, 3)
        self.assertIn("a&lt;b&gt;&amp;c", text)

    def test_order_puts_blocked_first_and_idle_last(self):
        sessions = [self.session("idle-one", "idle"), self.session("work", "working"),
                    self.session("blocked-one", "blocked")]
        ordered = sorted(sessions, key=pa.sort_key)
        self.assertEqual([s.label for s in ordered], ["blocked-one", "work", "idle-one"])

    def test_phase_states_sort_before_plain_working(self):
        sessions = [self.session("plain", "working"), self.session("plan", "planning")]
        ordered = sorted(sessions, key=pa.sort_key)
        self.assertEqual([s.label for s in ordered], ["plan", "plain"])

    def test_next_offset_slides_by_one_and_wraps(self):
        self.assertEqual(pa.next_offset(0, 5, 3), 1)
        self.assertEqual(pa.next_offset(3, 5, 3), 4)
        self.assertEqual(pa.next_offset(4, 5, 3), 0)
        self.assertEqual(pa.next_offset(7, 5, 3), 3)
        self.assertEqual(pa.next_offset(0, 0, 3), 0)

    def test_next_offset_is_zero_when_every_session_fits(self):
        self.assertEqual(pa.next_offset(2, 3, 5), 0)


class PresenceCollectionTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.presence = self.root / "presence"
        self.sessions = self.root / "sessions"
        self.presence.mkdir()
        self.sessions.mkdir()

    def tearDown(self):
        self.tmp.cleanup()

    def write_presence(self, h: dict, act: dict | None = None):
        base = f"{h['sessionHash']}.{h['incarnation']}"
        (self.presence / f"{base}.header.json").write_text(json.dumps(h), encoding="utf-8")
        (self.presence / f"{base}.activity.json").write_text(json.dumps(act or activity()), encoding="utf-8")

    def test_stale_heartbeat_is_not_live(self):
        self.write_presence(header("dead", NOW_MS - LIVE_MS - 1))
        self.assertEqual(pa.collect_sessions(self.presence, self.sessions, NOW_MS), [])

    def test_heartbeat_at_the_boundary_is_live(self):
        self.write_presence(header("alive", NOW_MS - LIVE_MS))
        self.assertEqual([s.label for s in pa.collect_sessions(self.presence, self.sessions, NOW_MS)], ["alive"])

    def test_newest_incarnation_wins(self):
        self.write_presence(header("old", NOW_MS - 5_000, incarnation="a"))
        self.write_presence(header("new", NOW_MS - 100, incarnation="b"))
        labels = [s.label for s in pa.collect_sessions(self.presence, self.sessions, NOW_MS)]
        self.assertEqual(labels, ["new"])

    def test_malformed_presence_file_is_skipped(self):
        self.write_presence(header("ok", NOW_MS - 100))
        (self.presence / "broken.header.json").write_text("{not json", encoding="utf-8")
        self.assertEqual([s.label for s in pa.collect_sessions(self.presence, self.sessions, NOW_MS)], ["ok"])

    def test_transcript_is_matched_by_hashed_session_id(self):
        session_id = "01a15f8c-cebb-703d-8d76-40b25777a35f"
        session_hash = pa.session_hash_of(session_id)
        self.write_presence(header("verdu.dotfiles", NOW_MS - 100, session_hash=session_hash))
        project = self.sessions / "--C--Users-verdu-verdu.dotfiles--"
        project.mkdir()
        lines = [json.dumps({"type": "session", "id": session_id}),
                 json.dumps(assistant_tool("read", {"path": "x"}))]
        (project / f"2026-10-21T17-40-25-915Z_{session_id}.jsonl").write_text("\n".join(lines) + "\n", encoding="utf-8")
        sessions = pa.collect_sessions(self.presence, self.sessions, NOW_MS)
        self.assertEqual(len(sessions), 1)
        self.assertEqual(sessions[0].state, "exploring")
        self.assertEqual(sessions[0].session_id, session_id)

    def test_unknown_hash_leaves_the_state_from_counters(self):
        self.write_presence(header("orphan", NOW_MS - 100, session_hash="0" * 64, running=1))
        sessions = pa.collect_sessions(self.presence, self.sessions, NOW_MS)
        self.assertEqual(sessions[0].state, "working")


class CliTests(unittest.TestCase):
    def run_main(self, root: Path, *extra: str) -> str:
        buffer = io.StringIO()
        with contextlib.redirect_stdout(buffer):
            pa.main([
                "--presence", str(root / "presence"),
                "--sessions", str(root / "sessions"),
                "--page-file", str(root / "page"),
                "--now", str(NOW_MS),
                *extra,
            ])
        return buffer.getvalue()

    def test_empty_presence_prints_an_empty_json_string(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "presence").mkdir()
            (root / "sessions").mkdir()
            self.assertEqual(json.loads(self.run_main(root)), "")

    def test_live_session_prints_a_json_string_with_the_label(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            presence = root / "presence"
            sessions = root / "sessions"
            presence.mkdir()
            sessions.mkdir()
            h = header("verdu.dotfiles", NOW_MS - 100)
            base = f"{h['sessionHash']}.{h['incarnation']}"
            (presence / f"{base}.header.json").write_text(json.dumps(h), encoding="utf-8")
            (presence / f"{base}.activity.json").write_text(json.dumps(activity()), encoding="utf-8")
            self.assertIn("verdu.dotfiles", json.loads(self.run_main(root)))

    def test_next_writes_the_page_file(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            presence = root / "presence"
            sessions = root / "sessions"
            presence.mkdir()
            sessions.mkdir()
            for i in range(7):
                h = header(f"p{i}", NOW_MS - 100, session_hash=f"h{i}")
                base = f"{h['sessionHash']}.{h['incarnation']}"
                (presence / f"{base}.header.json").write_text(json.dumps(h), encoding="utf-8")
                (presence / f"{base}.activity.json").write_text(json.dumps(activity()), encoding="utf-8")
            first = json.loads(self.run_main(root))
            second = json.loads(self.run_main(root, "--next"))
            self.assertEqual((root / "page").read_text(encoding="utf-8").strip(), "1")
            self.assertNotEqual(first, second)
            self.assertTrue(second.startswith("p"), second)

    def test_error_payload_is_visible(self):
        self.assertIn("pi agents: error", pa.error_payload())


if __name__ == "__main__":
    unittest.main()
