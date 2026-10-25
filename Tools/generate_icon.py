#!/usr/bin/env python3
"""Generate PassportProof's opaque App Store icon and launch symbol.

Original vector-like geometry rendered with Pillow at 3x and downsampled for
clean small-size edges. No text, transparency, external artwork or dependencies
beyond Pillow. Run with the project's managed Python environment.
"""

from __future__ import annotations

import json
import os

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "PassportProof", "Resources", "Assets.xcassets")
ICON_OUT = os.path.join(ASSETS, "AppIcon.appiconset", "icon-1024.png")
LAUNCH_DIR = os.path.join(ASSETS, "LaunchSymbol.imageset")
SIZE = 1024
SCALE = 3
PAPER = (244, 241, 234, 255)
INK = (20, 37, 33, 255)
ACCENT = (83, 199, 174, 255)
DEEP = (13, 107, 96, 255)


def scaled(values):
    return tuple(int(round(v * SCALE)) for v in values)


def background() -> Image.Image:
    image = Image.new("RGB", (SIZE, SIZE))
    draw = ImageDraw.Draw(image)
    start = (24, 62, 59)
    end = (8, 28, 32)
    for y in range(SIZE):
        t = y / (SIZE - 1)
        color = tuple(int(a + (b - a) * t) for a, b in zip(start, end))
        draw.line((0, y, SIZE, y), fill=color)
    image = image.resize((SIZE * SCALE, SIZE * SCALE), Image.Resampling.LANCZOS).convert("RGBA")

    glow = Image.new("RGBA", image.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse(scaled((540, -240, 1220, 440)), fill=(83, 199, 174, 54))
    glow = glow.filter(ImageFilter.GaussianBlur(90 * SCALE))
    return Image.alpha_composite(image, glow)


def app_icon() -> Image.Image:
    image = background()

    shadow = Image.new("RGBA", image.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle(scaled((194, 176, 830, 876)), radius=132 * SCALE, fill=(0, 0, 0, 100))
    shadow = shadow.filter(ImageFilter.GaussianBlur(28 * SCALE))
    image = Image.alpha_composite(image, shadow)

    card = Image.new("RGBA", image.size, (0, 0, 0, 0))
    cd = ImageDraw.Draw(card)
    cd.rounded_rectangle(scaled((202, 152, 822, 852)), radius=128 * SCALE, fill=PAPER)
    cd.rounded_rectangle(scaled((238, 192, 786, 812)), radius=100 * SCALE, fill=(233, 229, 218, 255))

    # Measurement band and viewfinder ticks, derived from the product's guide.
    for y in (330, 590):
        cd.rounded_rectangle(scaled((286, y - 6, 738, y + 6)), radius=6 * SCALE, fill=DEEP)
    tick = 64
    width = 13
    for x, y, sx, sy in ((272, 264, 1, 1), (752, 264, -1, 1), (272, 742, 1, -1), (752, 742, -1, -1)):
        cd.rectangle(scaled((x if sx > 0 else x - tick, y, x + tick if sx > 0 else x, y + width)), fill=DEEP)
        cd.rectangle(scaled((x, y if sy > 0 else y - tick, x + width, y + tick if sy > 0 else y)), fill=DEEP)

    # Head and shoulders are clipped to the rounded photo cell.
    subject = Image.new("RGBA", image.size, (0, 0, 0, 0))
    sub = ImageDraw.Draw(subject)
    sub.ellipse(scaled((405, 350, 619, 564)), fill=INK)
    sub.ellipse(scaled((314, 584, 710, 956)), fill=INK)
    mask = Image.new("L", image.size, 0)
    md = ImageDraw.Draw(mask)
    md.rounded_rectangle(scaled((238, 192, 786, 812)), radius=100 * SCALE, fill=255)
    subject.putalpha(ImageChops.multiply(subject.getchannel("A"), mask))
    card = Image.alpha_composite(card, subject)

    # Validation seal: the only additional mark, readable at small sizes.
    cd = ImageDraw.Draw(card)
    cd.ellipse(scaled((636, 636, 830, 830)), fill=PAPER)
    cd.ellipse(scaled((650, 650, 816, 816)), fill=DEEP)
    cd.line(scaled((694, 733, 726, 766, 778, 700)), fill=(255, 255, 255, 255), width=17 * SCALE, joint="curve")

    image = Image.alpha_composite(image, card)
    return image.convert("RGB").resize((SIZE, SIZE), Image.Resampling.LANCZOS)


def launch_symbol() -> Image.Image:
    canvas = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    draw.rounded_rectangle((24, 24, 488, 488), radius=116, fill=DEEP)
    draw.ellipse((118, 118, 394, 394), outline=PAPER, width=22)
    draw.line((164, 260, 226, 322, 356, 184), fill=PAPER, width=28, joint="curve")
    return canvas


def main() -> int:
    os.makedirs(os.path.dirname(ICON_OUT), exist_ok=True)
    os.makedirs(LAUNCH_DIR, exist_ok=True)
    app_icon().save(ICON_OUT, "PNG", optimize=True)

    launch = launch_symbol()
    for pixels, scale in ((160, "1x"), (320, "2x"), (480, "3x")):
        launch.resize((pixels, pixels), Image.Resampling.LANCZOS).save(
            os.path.join(LAUNCH_DIR, f"launch-{pixels}.png"), "PNG", optimize=True
        )
    contents = {
        "images": [
            {"filename": f"launch-{pixels}.png", "idiom": "universal", "scale": scale}
            for pixels, scale in ((160, "1x"), (320, "2x"), (480, "3x"))
        ],
        "info": {"author": "xcode", "version": 1},
    }
    with open(os.path.join(LAUNCH_DIR, "Contents.json"), "w", encoding="utf-8", newline="\n") as handle:
        json.dump(contents, handle, indent=2)
        handle.write("\n")

    with Image.open(ICON_OUT) as check:
        assert check.mode == "RGB" and check.size == (SIZE, SIZE), (check.mode, check.size)
    print(f"wrote {ICON_OUT} ({os.path.getsize(ICON_OUT)} bytes)")
    print(f"wrote {LAUNCH_DIR} (1x/2x/3x)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
