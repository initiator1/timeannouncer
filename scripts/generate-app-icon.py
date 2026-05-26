#!/usr/bin/env python3
from __future__ import annotations

import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
ICONSET = ROOT / "TimeAnnouncer" / "Assets.xcassets" / "AppIcon.appiconset"

SLOTS = [
    ("16x16", 1, 16),
    ("16x16", 2, 32),
    ("32x32", 1, 32),
    ("32x32", 2, 64),
    ("128x128", 1, 128),
    ("128x128", 2, 256),
    ("256x256", 1, 256),
    ("256x256", 2, 512),
    ("512x512", 1, 512),
    ("512x512", 2, 1024),
]


def rounded_rectangle(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], radius: int, fill):
    draw.rounded_rectangle(box, radius=radius, fill=fill)


def draw_icon(size: int) -> Image.Image:
    scale = 4
    canvas_size = size * scale
    img = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    def p(value: float) -> int:
        return round(value * canvas_size)

    # Full-bleed matte base, with subtle top light and bottom depth.
    rounded_rectangle(draw, (0, 0, canvas_size, canvas_size), p(0.22), (16, 17, 19, 255))
    for y in range(canvas_size):
        t = y / max(canvas_size - 1, 1)
        r = int(27 - 10 * t)
        g = int(26 - 9 * t)
        b = int(24 - 7 * t)
        draw.line((0, y, canvas_size, y), fill=(r, g, b, 255))

    # Inner shadow/vignette.
    vignette = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    vdraw = ImageDraw.Draw(vignette)
    vdraw.rounded_rectangle(
        (p(0.04), p(0.04), p(0.96), p(0.96)),
        radius=p(0.19),
        outline=(0, 0, 0, 95),
        width=max(1, p(0.018)),
    )
    img.alpha_composite(vignette.filter(ImageFilter.GaussianBlur(p(0.012))))

    gold = (228, 179, 82, 255)
    gold_dim = (143, 105, 47, 235)
    gold_hot = (255, 218, 128, 255)

    cx, cy = p(0.47), p(0.50)
    radius = p(0.255)
    width = max(2, p(0.048))

    # Clock ring.
    ring_box = (cx - radius, cy - radius, cx + radius, cy + radius)
    draw.ellipse(ring_box, outline=gold, width=width)
    draw.ellipse(
        (cx - radius + width, cy - radius + width, cx + radius - width, cy + radius - width),
        outline=(65, 49, 27, 150),
        width=max(1, p(0.01)),
    )

    # Clock hands: about 10:30.
    hand_width = max(2, p(0.043))
    draw.line((cx, cy, cx - p(0.10), cy - p(0.125)), fill=gold_hot, width=hand_width)
    draw.line((cx, cy, cx + p(0.14), cy), fill=gold_hot, width=hand_width)
    draw.ellipse((cx - p(0.035), cy - p(0.035), cx + p(0.035), cy + p(0.035)), fill=gold_hot)

    # Minimal sound arcs on the right.
    arc_center_x = p(0.61)
    arc_center_y = cy
    for idx, arc_radius in enumerate((0.20, 0.285)):
        stroke = max(1, p(0.032 - idx * 0.004))
        box = (
            arc_center_x - p(arc_radius),
            arc_center_y - p(arc_radius),
            arc_center_x + p(arc_radius),
            arc_center_y + p(arc_radius),
        )
        draw.arc(box, start=-38, end=38, fill=gold if idx == 0 else gold_dim, width=stroke)

    # Small top tick for clock identity at tiny sizes.
    tick_w = max(1, p(0.028))
    tick_len = p(0.06)
    angle = -math.pi / 2
    tx1 = cx + math.cos(angle) * (radius - tick_len)
    ty1 = cy + math.sin(angle) * (radius - tick_len)
    tx2 = cx + math.cos(angle) * (radius + p(0.005))
    ty2 = cy + math.sin(angle) * (radius + p(0.005))
    draw.line((tx1, ty1, tx2, ty2), fill=gold_hot, width=tick_w)

    return img.resize((size, size), Image.Resampling.LANCZOS)


def main() -> None:
    ICONSET.mkdir(parents=True, exist_ok=True)
    (ICONSET.parent / "Contents.json").write_text(
        json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2) + "\n",
        encoding="utf-8",
    )

    images = []
    for point_size, scale, pixels in SLOTS:
        suffix = "" if scale == 1 else "@2x"
        base_name = point_size.replace("x", "")
        filename = f"app-icon-{base_name}{suffix}.png"
        draw_icon(pixels).save(ICONSET / filename)
        images.append(
            {
                "filename": filename,
                "idiom": "mac",
                "scale": f"{scale}x",
                "size": point_size,
            }
        )

    (ICONSET / "Contents.json").write_text(
        json.dumps({"images": images, "info": {"author": "xcode", "version": 1}}, indent=2) + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
