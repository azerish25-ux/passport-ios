#!/usr/bin/env python3
"""
Generates the PassportProof app icon (1024x1024, opaque, no alpha).

The composition is the app's own capture screen, reduced to its four marks:
the paper ground, the ink photo cell, the head-and-shoulders silhouette, and
the head-height band that is the product's whole reason for existing. Flat,
hard-edged, no gradients, no text -- the same rules the DesignSystem.md
imposes on the interface.

Colours are lifted from PassportProof/Design/Theme.swift:
  paper  #F4F1EA   ink  #14120F   accent #10565C (light) / #4FA3A8 (dark)

Run:  python Tools/generate_icon.py
Writes: PassportProof/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png
"""

from __future__ import annotations

import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(
    ROOT, "PassportProof", "Resources", "Assets.xcassets", "AppIcon.appiconset", "icon-1024.png"
)

SIZE = 1024

PAPER = (0xF4, 0xF1, 0xEA, 255)
INK = (0x14, 0x12, 0x0F, 255)
ACCENT = (0x4F, 0xA3, 0xA8, 255)  # the dark-appearance accent: reads on ink


def rect(d: ImageDraw.ImageDraw, box: tuple[int, int, int, int], fill) -> None:
    d.rectangle(box, fill=fill)


def main() -> int:
    img = Image.new("RGB", (SIZE, SIZE), PAPER[:3])
    d = ImageDraw.Draw(img)

    # The photo cell: a square ink field, centred, 640x640.
    cell = (192, 192, 832, 832)
    rect(d, cell, INK)

    # Head-and-shoulders silhouette in paper, clipped to the cell.
    silhouette = Image.new("L", (SIZE, SIZE), 0)
    sd = ImageDraw.Draw(silhouette)
    sd.ellipse((414, 322, 610, 518), fill=255)          # head: chin at y=518
    sd.ellipse((337, 560, 687, 880), fill=255)          # shoulders, running past the cell edge
    paper_layer = Image.new("RGB", (SIZE, SIZE), PAPER[:3])
    img.paste(paper_layer, (0, 0), silhouette)

    # Head-height band: the crown line and the chin line. This is the clause
    # the corpus encodes and the one number the app will not approximate.
    band_x0, band_x1 = 232, 792
    for y in (322, 518):
        rect(d, (band_x0, y - 4, band_x1, y + 4), ACCENT)

    # Corner ticks, echoing FramingOverlay: onInk marks on the ink ground.
    tick_len, tick_w = 56, 10
    cx0, cy0, cx1, cy1 = cell
    for (hx, hy) in ((cx0, cy0), (cx1 - tick_len, cy0), (cx0, cy1 - tick_w), (cx1 - tick_len, cy1 - tick_w)):
        rect(d, (hx, hy, hx + tick_len, hy + tick_w), PAPER)
    for (vx, vy) in ((cx0, cy0), (cx0, cy1 - tick_len), (cx1 - tick_w, cy0), (cx1 - tick_w, cy1 - tick_len)):
        rect(d, (vx, vy, vx + tick_w, vy + tick_len), PAPER)

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    img.save(OUT, "PNG", optimize=True)

    # iOS requires an opaque icon; assert rather than trust.
    with Image.open(OUT) as check:
        assert check.mode == "RGB" and check.size == (SIZE, SIZE), check.mode
    print(f"wrote {OUT} ({os.path.getsize(OUT)} bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
