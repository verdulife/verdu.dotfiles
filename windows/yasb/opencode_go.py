#!/usr/bin/env python3

"""
OpenCode Go usage helper for YASB CustomWidget.

Reads the OpenCode Go API key from the first store that has one and is accepted:
%USERPROFILE%\\.pi\\agent\\auth.json            (Pi's managed store: `type: api_key`)
%USERPROFILE%\\.local\\share\\opencode\\auth.json  (opencode CLI store: `type: api`)
The Pi store is tried first: on this machine only its key holds the Go entitlement,
the opencode one answers 403 EntitlementError even though its entry is also called
`opencode-go` (verified 2026-10-06).

Output modes:
    (default) -> one compact JSON line for YASB
    --next    -> rotate the pill state (full -> 5h -> week -> month -> full)
    --popup   -> Tkinter popup with detailed usage
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path


HOME = Path(os.environ.get("USERPROFILE", str(Path.home())))

# Candidate stores, in order. Pi's managed store first: its `opencode-go` entry is an
# `api_key` carrying the Go entitlement, while the opencode CLI store's `type: api` key
# is rejected with 403 EntitlementError for the same endpoint (verified 2026-10-06). A
# key that the endpoint rejects falls through to the next candidate instead of leaving
# the widget at 0%.
AUTH_PATHS = (
    HOME / ".pi" / "agent" / "auth.json",
    HOME / ".local" / "share" / "opencode" / "auth.json",
)
AUTH_PATH = AUTH_PATHS[0]   # kept for messages: the store the widget prefers

USAGE_URL = "https://opencode.ai/zen/go/v1/usage"

TIMEOUT = 10
CACHE_MAX_AGE = 900  # 15 minutes

# Text progress bars for the YASB label: ▰ U+25B0 BLACK PARALLELOGRAM (filled) and ▱
# U+25B1 WHITE PARALLELOGRAM (empty), exactly as requested. These glyphs are NOT in the
# JetBrains Mono Nerd Font, but CaskaydiaCove NFP is installed and covers both (verified
# 2026-10-06), and the label template forces that family on the bar cells via
# `<font face="CaskaydiaCove NFP" ...>` so every cell of a bar renders from one font.
BAR_CELLS = 5
BAR_FULL = "\u25b0"
BAR_EMPTY = "\u25b1"


def load_keys() -> list[tuple[Path, str]]:
    """Every `opencode-go` key found, in candidate-store order."""
    found: list[tuple[Path, str]] = []
    unreadable: list[str] = []

    for path in AUTH_PATHS:
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except FileNotFoundError:
            continue
        except Exception as error:
            unreadable.append(f"{path}: {error}")
            continue

        key = (data.get("opencode-go") or {}).get("key")

        if key:
            found.append((path, key))

    if found:
        return found

    detail = f" ({'; '.join(unreadable)})" if unreadable else ""

    raise RuntimeError(
        "No opencode-go.key found in "
        + ", ".join(str(path) for path in AUTH_PATHS)
        + detail
    )


def fetch_usage() -> dict:
    """Fetch current usage, trying each candidate key until one is accepted."""
    last_error = None

    for path, key in load_keys():
        request = urllib.request.Request(
            USAGE_URL,
            headers={
                "Authorization": f"Bearer {key}",
                "Accept": "application/json",
                "User-Agent": "YASB-OpenCode-Go-Usage/1.0",
            },
            method="GET",
        )

        try:
            with urllib.request.urlopen(request, timeout=TIMEOUT) as response:
                if response.status != 200:
                    raise RuntimeError(f"HTTP {response.status}")

                return json.loads(
                    response.read().decode("utf-8")
                )
        except Exception as error:
            last_error = f"{path}: {error}"

    raise RuntimeError(f"No accepted opencode-go key - {last_error}")


def normalize(data: dict) -> dict:
    """Normalize the API response into a predictable structure."""
    usage = data.get("usage", data)

    result = {}

    for name in ("rolling", "weekly", "monthly"):
        item = usage.get(name, {}) or {}

        try:
            percent = int(round(float(item.get("percent", 0))))
        except (TypeError, ValueError):
            percent = 0

        result[name] = {
            "percent": max(0, min(100, percent)),
            "resetsAt": item.get("resetsAt"),
            "status": item.get("status", "ok"),
        }

    return result


def cache_path() -> Path:
    """Return the cache file path.

    Deliberately NOT next to the script: the deployed script lives in
    `%USERPROFILE%\\.config\\yasb`, which YASB watches for config changes, so a cache
    write every 5 minutes there risks poking the watcher and reloading the bar. The
    cache is runtime state, so it goes to %TEMP% (or the home directory as a fallback).
    """
    state_dir = Path(
        os.environ.get("TEMP") or os.environ.get("TMP") or str(HOME)
    )
    return state_dir / "opencode-go-usage.cache.json"


def load_cache() -> dict | None:
    """Load cached usage if it is still fresh."""
    try:
        path = cache_path()

        if not path.exists():
            return None

        age = time.time() - path.stat().st_mtime

        if age > CACHE_MAX_AGE:
            return None

        with path.open("r", encoding="utf-8") as f:
            return json.load(f)

    except Exception:
        return None


def save_cache(data: dict) -> None:
    """Save usage data to the local cache."""
    try:
        path = cache_path()
        temp_path = path.with_suffix(".tmp")

        with temp_path.open("w", encoding="utf-8") as f:
            json.dump(data, f)

        temp_path.replace(path)

    except Exception:
        pass


def get_usage() -> tuple[dict, bool]:
    """
    Get current usage.

    Returns:
        (usage_data, stale)

    stale=True means cached data is being used.
    """
    try:
        data = normalize(fetch_usage())
        save_cache(data)
        return data, False

    except Exception:
        cached = load_cache()

        if cached:
            return cached, True

        raise


def format_reset(iso: str | None) -> str:
    """Convert an ISO timestamp into a human-readable countdown."""
    if not iso:
        return "Unknown"

    try:
        dt = datetime.fromisoformat(
            iso.replace("Z", "+00:00")
        )

        now = datetime.now(timezone.utc)

        seconds = max(
            0,
            int((dt - now).total_seconds())
        )

        days, remainder = divmod(seconds, 86400)
        hours, remainder = divmod(remainder, 3600)
        minutes, _ = divmod(remainder, 60)

        if days:
            return f"{days}d {hours}h"

        if hours:
            return f"{hours}h {minutes}m"

        return f"{minutes}m"

    except Exception:
        return iso


def usage_bar(percent: int, cells: int = BAR_CELLS) -> str:
    """Render a percent (0-100) as a `cells`-wide text bar, e.g. usage_bar(8) == "█░░░░"."""
    clamped = max(0, min(100, int(percent)))
    filled = min(cells, (clamped * cells + 99) // 100)  # ceil, capped at cells
    return (BAR_FULL * filled) + (BAR_EMPTY * (cells - filled))


# Click cycle: the pill shows one of four states and the left click rotates it.
# The state file lives in %TEMP% next to the cache; a missing or corrupt file
# means STATE_FULL, the default.
STATE_FULL, STATE_ROLLING, STATE_WEEKLY, STATE_MONTHLY = 0, 1, 2, 3
STATE_COUNT = 4


def state_path() -> Path:
    state_dir = Path(os.environ.get("TEMP") or os.environ.get("TMP") or str(HOME))
    return state_dir / "opencode-go-usage.state"


def read_state() -> int:
    try:
        value = int(state_path().read_text(encoding="utf-8").strip())
        return value if value in range(STATE_COUNT) else STATE_FULL
    except Exception:
        return STATE_FULL


def write_state(value: int) -> None:
    tmp = state_path().with_suffix(".tmp")
    tmp.write_text(str(value), encoding="utf-8")
    tmp.replace(state_path())


def next_state() -> None:
    """Rotate full -> 5h -> week -> month -> full (the click action)."""
    write_state((read_state() + 1) % STATE_COUNT)


def label_text(state: int, data: dict) -> str:
    """The pill text for a state, bars included with their font tags.

    The `<font>` spans force the family that owns the glyphs (CaskaydiaCove NFP)
    and the muted icon gray, exactly like the old inline template did.
    """
    bar = lambda glyph: f'<font face="CaskaydiaCove NFP" color="#9aa3b2">{glyph}</font>'

    parts = (
        f"{data['rolling']}% {bar(data['rolling_bar'])} 5h",
        f"{data['weekly']}%  {bar(data['weekly_bar'])} Week",
        f"{data['monthly']}% {bar(data['monthly_bar'])} Month",
    )

    if state == STATE_ROLLING:
        return parts[0]
    if state == STATE_WEEKLY:
        return parts[1]
    if state == STATE_MONTHLY:
        return parts[2]
    return "  ".join(parts)


def main_json() -> int:
    """Output compact JSON for YASB."""
    try:
        usage, stale = get_usage()

        output = {
            "rolling": usage["rolling"]["percent"],
            "weekly": usage["weekly"]["percent"],
            "monthly": usage["monthly"]["percent"],
            "rolling_bar": usage_bar(usage["rolling"]["percent"]),
            "weekly_bar": usage_bar(usage["weekly"]["percent"]),
            "monthly_bar": usage_bar(usage["monthly"]["percent"]),
            "stale": stale,
        }
        output["text"] = label_text(read_state(), output)

        print(
            json.dumps(
                output,
                separators=(",", ":")
            )
        )

        return 0

    except Exception as error:
        data = {
            "rolling": 0,
            "weekly": 0,
            "monthly": 0,
            "rolling_bar": usage_bar(0),
            "weekly_bar": usage_bar(0),
            "monthly_bar": usage_bar(0),
            "error": str(error),
        }
        data["text"] = label_text(read_state(), data)

        print(json.dumps(data, separators=(",", ":")))

        return 0


def popup() -> int:
    """Show a detailed Tkinter popup."""
    import tkinter as tk

    try:
        usage, stale = get_usage()

    except Exception as error:
        usage = {
            "rolling": {
                "percent": 0,
                "resetsAt": None,
                "status": "error",
            },
            "weekly": {
                "percent": 0,
                "resetsAt": None,
                "status": "error",
            },
            "monthly": {
                "percent": 0,
                "resetsAt": None,
                "status": "error",
            },
        }

        stale = False
        error_message = str(error)

    else:
        error_message = None

    root = tk.Tk()

    root.title("OpenCode Go")
    root.resizable(False, False)
    root.configure(bg="#202020")

    # Keep the popup above other windows.
    root.attributes("-topmost", True)

    outer = tk.Frame(
        root,
        bg="#202020",
        padx=18,
        pady=16,
    )

    outer.pack()

    # Header row: the OpenCode logo (PNG, pre-scaled next to this script), then the title.
    header = tk.Frame(outer, bg="#202020")
    header.pack(fill="x", pady=(0, 12))

    logo_path = Path(__file__).with_name("opencode-logo.png")
    if logo_path.exists():
        try:
            logo_img = tk.PhotoImage(file=str(logo_path))
            logo_lbl = tk.Label(header, image=logo_img, bg="#202020")
            logo_lbl.image = logo_img  # keep a reference so Tk does not garbage-collect it
            logo_lbl.pack(side="left", padx=(0, 8))
        except Exception:
            pass

    tk.Label(
        header,
        text="OpenCode Go",
        bg="#202020",
        fg="#ffffff",
        font=("Segoe UI", 13, "bold"),
        anchor="w",
    ).pack(side="left", fill="x")

    if error_message:
        tk.Label(
            outer,
            text=f"Error: {error_message}",
            bg="#202020",
            fg="#ff6b6b",
            font=("Segoe UI", 9),
            justify="left",
            wraplength=330,
        ).pack(anchor="w")

    else:
        labels = (
            ("5 hours", "rolling"),
            ("Weekly", "weekly"),
            ("Monthly", "monthly"),
        )

        for caption, key in labels:
            row = tk.Frame(
                outer,
                bg="#202020",
            )

            row.pack(
                fill="x",
                pady=5,
            )

            percent = max(
                0,
                min(
                    100,
                    usage[key]["percent"],
                ),
            )

            tk.Label(
                row,
                text=caption,
                bg="#202020",
                fg="#d8d8d8",
                font=("Segoe UI", 10),
                width=10,
                anchor="w",
            ).pack(side="left")

            bar_bg = tk.Frame(
                row,
                bg="#3a3a3a",
                width=180,
                height=9,
            )

            bar_bg.pack(
                side="left",
                padx=8,
            )

            bar_bg.pack_propagate(False)

            fill_width = max(
                1,
                int(180 * percent / 100),
            )

            fill = tk.Frame(
                bar_bg,
                bg="#7aa2f7",
                width=fill_width,
                height=9,
            )

            fill.pack(side="left")

            tk.Label(
                row,
                text=f"{percent}%",
                bg="#202020",
                fg="#ffffff",
                font=("Segoe UI", 10, "bold"),
                width=5,
                anchor="e",
            ).pack(side="right")

            reset_text = (
                f"Resets in "
                f"{format_reset(usage[key].get('resetsAt'))}"
            )

            tk.Label(
                outer,
                text=reset_text,
                bg="#202020",
                fg="#8b8b8b",
                font=("Segoe UI", 8),
            ).pack(
                anchor="w",
                padx=(102, 0),
            )

        if stale:
            tk.Label(
                outer,
                text="Offline: showing cached values",
                bg="#202020",
                fg="#d7a84a",
                font=("Segoe UI", 8),
            ).pack(
                anchor="w",
                pady=(10, 0),
            )

    root.update_idletasks()

    width = root.winfo_width()
    height = root.winfo_height()

    x = root.winfo_pointerx() - width // 2
    y = root.winfo_pointery() + 12

    root.geometry(
        f"+{max(0, x)}+{max(0, y)}"
    )

    root.bind(
        "<Escape>",
        lambda event: root.destroy(),
    )

    root.bind(
        "<FocusOut>",
        lambda event: root.after(
            150,
            root.destroy,
        ),
    )

    root.mainloop()

    return 0


if __name__ == "__main__":
    parser = argparse.ArgumentParser()

    parser.add_argument(
        "--popup",
        action="store_true",
        help="Show the detailed usage popup.",
    )
    parser.add_argument(
        "--next",
        action="store_true",
        help="Rotate the pill state: full -> 5h -> week -> month -> full.",
    )

    args = parser.parse_args()

    if args.next:
        next_state()
        sys.exit(0)

    sys.exit(
        popup()
        if args.popup
        else main_json()
    )