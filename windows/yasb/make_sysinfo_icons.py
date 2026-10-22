#!/usr/bin/env python3
"""Render the CPU / RAM / GPU wordmark icons from their FigCraft exports.

The source exports (1024x384) draw each letter on a 14x4 grid of 64px cells with
62px blocks inside them. Rendering that down by plain resampling loses the thin
gaps between cells and blurs the strokes, so this script reads the grid itself
and repaints every filled cell as a square of `cell` pixels: the result is crisp
block art at exactly 14*cell x 4*cell.

Usage:
    py -B make_sysinfo_icons.py --cell 2          # 28x8, what styles.css expects
    py -B make_sysinfo_icons.py --cell 3 --out .  # 42x12 if the bar should grow

Keep styles.css in sync: the .cpu-widget/.memory-widget/.gpu-widget .icon rules
pin min/max width and height to 14*cell x 4*cell.
"""

from __future__ import annotations

import argparse
import pathlib

from PIL import Image

COLOR = (242, 244, 247, 255)  # #F2F4F7, the bar's text colour
CELLS_X, CELLS_Y = 14, 4
PITCH = 64  # source grid pitch in px; the art starts at (65, 65) inside the canvas
NAMES = (("cpu", "cpu-icon.png"), ("ram", "ram-icon.png"), ("gpu", "gpu-icon.png"))


def read_grid(source: pathlib.Path) -> list[str]:
    """Return the art as rows of '#' (filled) and '.' (empty) characters."""
    image = Image.open(source).convert("RGBA")
    alpha = image.split()[3]
    bbox = image.getbbox()
    if bbox is None:
        raise SystemExit(f"{source}: fully transparent, nothing to render")
    left, top = bbox[0], bbox[1]
    rows = []
    for row in range(CELLS_Y):
        line = ""
        for column in range(CELLS_X):
            x = left + column * PITCH + PITCH // 2 - 1
            y = top + row * PITCH + PITCH // 2 - 1
            line += "#" if alpha.getpixel((x, y)) > 0 else "."
        rows.append(line)
    return rows


def render(rows: list[str], cell: int) -> Image.Image:
    width, height = CELLS_X * cell, CELLS_Y * cell
    image = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    for row, line in enumerate(rows):
        for column, char in enumerate(line):
            if char != "#":
                continue
            x, y = column * cell, row * cell
            image.paste(COLOR, (x, y, x + cell, y + cell))
    return image


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-dir", type=pathlib.Path, default=pathlib.Path.home() / "Desktop")
    parser.add_argument("--out", type=pathlib.Path, default=pathlib.Path(__file__).parent)
    parser.add_argument("--cell", type=int, default=2, help="px per grid cell (2 = 28x8 icons)")
    args = parser.parse_args()

    for name, target in NAMES:
        source = args.source_dir / f"{name}.png"
        if not source.exists():
            raise SystemExit(f"missing source export: {source}")
        image = render(read_grid(source), args.cell)
        image.save(args.out / target)
        print(f"{target}: {image.width}x{image.height}")


if __name__ == "__main__":
    main()
