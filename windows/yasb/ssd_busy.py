"""SSD saturation for the YASB bar.

The bar shells out to the *system* Python, which has no `psutil`, so this reads the
Windows performance counter the Task Manager's Disk column is built on, through
`pdh.dll` (stdlib `ctypes` only):

    \\PhysicalDisk(_Total)\\% Disk Time

That counter is *service time*: it accumulates per request, so overlapping I/O can
push it past the wall clock. Task Manager clamps at 100% and so does
`clamp_percent`; PDH also caps percentage counters unless `PDH_FMT_NOCAP100` is
requested, which we never do. Percentage counters need two collections separated by
the sampling window, so a run costs `--window` milliseconds (default 500).

Prints one JSON document: a ready-made label for a `yasb.custom.CustomWidget`, with
the word in the same faux small caps as the built-in sysinfo widgets (Qt ignores
`font-variant: small-caps`, so it is upper case at ~70% of the pill size). The span
carries no tracking: Qt style sheets have no `letter-spacing`, so the three built-in
labels have none either and this one gives its 1px up to match them.
"""

from __future__ import annotations

import argparse
import ctypes
import json
import sys
import time
from ctypes import wintypes

COUNTER_PATH = r"\PhysicalDisk(_Total)\% Disk Time"
SAMPLE_WINDOW_MS = 500
LABEL_TEXT = "SSD"
LABEL_COLOUR = "#9aa3b2"
LABEL_FONT_SIZE = 9  # the faux small caps pi_agents.py uses for a session state
ERROR_COLOUR = "#e88f8f"
PDH_FMT_DOUBLE = 0x00000200


class _PdhFmtCounterValue(ctypes.Structure):
    # PDH_FMT_COUNTERVALUE: DWORD CStatus followed by a union; the union's widest
    # member forces 8-byte alignment, so one DWORD of padding sits in between.
    _fields_ = [
        ("CStatus", wintypes.DWORD),
        ("_padding", wintypes.DWORD),
        ("doubleValue", ctypes.c_double),
    ]


def _pdh() -> ctypes.WinDLL:
    pdh = ctypes.WinDLL("pdh.dll")
    pdh.PdhOpenQueryW.argtypes = [wintypes.LPCWSTR, ctypes.c_size_t, ctypes.POINTER(wintypes.HANDLE)]
    pdh.PdhOpenQueryW.restype = wintypes.LONG
    pdh.PdhAddEnglishCounterW.argtypes = [
        wintypes.HANDLE,
        wintypes.LPCWSTR,
        ctypes.c_size_t,
        ctypes.POINTER(wintypes.HANDLE),
    ]
    pdh.PdhAddEnglishCounterW.restype = wintypes.LONG
    pdh.PdhCollectQueryData.argtypes = [wintypes.HANDLE]
    pdh.PdhCollectQueryData.restype = wintypes.LONG
    pdh.PdhGetFormattedCounterValue.argtypes = [
        wintypes.HANDLE,
        wintypes.DWORD,
        ctypes.POINTER(wintypes.DWORD),
        ctypes.POINTER(_PdhFmtCounterValue),
    ]
    pdh.PdhGetFormattedCounterValue.restype = wintypes.LONG
    pdh.PdhCloseQuery.argtypes = [wintypes.HANDLE]
    pdh.PdhCloseQuery.restype = wintypes.LONG
    return pdh


def clamp_percent(value: float) -> float:
    """Keep a reading inside 0-100, and turn "no reading" into a visible 0."""
    if value != value:  # NaN: PDH had no data for the window
        return 0.0
    return max(0.0, min(100.0, float(value)))


def _read_percent(pdh: ctypes.WinDLL, counter: wintypes.HANDLE) -> float:
    value = _PdhFmtCounterValue()
    status = pdh.PdhGetFormattedCounterValue(counter, PDH_FMT_DOUBLE, None, ctypes.byref(value))
    if status != 0:
        raise OSError(f"PdhGetFormattedCounterValue failed (0x{status & 0xFFFFFFFF:08X})")
    return value.doubleValue


def sample_busy_percent(window_ms: int = SAMPLE_WINDOW_MS) -> float:
    """Saturation of the physical disks over `window_ms`, as Task Manager reports it."""
    pdh = _pdh()
    query = wintypes.HANDLE()
    counter = wintypes.HANDLE()
    status = pdh.PdhOpenQueryW(None, 0, ctypes.byref(query))
    if status != 0:
        raise OSError(f"PdhOpenQuery failed (0x{status & 0xFFFFFFFF:08X})")
    try:
        status = pdh.PdhAddEnglishCounterW(query, COUNTER_PATH, 0, ctypes.byref(counter))
        if status != 0:
            raise OSError(f"PdhAddEnglishCounter failed for {COUNTER_PATH} (0x{status & 0xFFFFFFFF:08X})")
        # A percentage counter needs a baseline: collect, wait the window, collect.
        if pdh.PdhCollectQueryData(query) != 0:
            raise OSError("PdhCollectQueryData failed on the baseline sample")
        time.sleep(max(1, window_ms) / 1000.0)
        if pdh.PdhCollectQueryData(query) != 0:
            raise OSError("PdhCollectQueryData failed on the measured sample")
        return clamp_percent(_read_percent(pdh, counter))
    finally:
        pdh.PdhCloseQuery(query)


def format_label(percent: float) -> str:
    """`SSD 12.3%` with the word in faux small caps and the number left bright."""
    return (
        f'<span style="font-size:{LABEL_FONT_SIZE}px">'
        f'<font color="{LABEL_COLOUR}">{LABEL_TEXT}</font></span> {clamp_percent(percent):.1f}%'
    )


def payload(percent: float) -> str:
    return json.dumps(format_label(percent))


def error_payload() -> str:
    """A visible failure beats a pill that silently disappears."""
    return f'<font color="{ERROR_COLOUR}">{LABEL_TEXT}: error</font>'


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Print the SSD saturation label for the YASB bar.")
    parser.add_argument(
        "--window",
        type=int,
        default=SAMPLE_WINDOW_MS,
        metavar="MS",
        help=f"sampling window in milliseconds (default {SAMPLE_WINDOW_MS})",
    )
    args = parser.parse_args(argv)
    try:
        print(payload(sample_busy_percent(args.window)))
    except Exception:  # noqa: BLE001 - the bar must show the failure, not vanish
        print(json.dumps(error_payload()))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
