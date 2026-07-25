#!/usr/bin/env python3
"""Generate Ditto4Mac app icon PNGs at all required sizes."""

import os
import math
from PIL import Image, ImageDraw, ImageFont

SIZES = [16, 32, 64, 128, 256, 512, 1024]
OUTPUT_DIR = "scripts/icon.iconset"
os.makedirs(OUTPUT_DIR, exist_ok=True)

def draw_clipboard(draw, size, scale=1):
    """Draw a clipboard icon on the given draw context."""
    w, h = size, size
    margin = int(w * 0.12)
    corner = int(w * 0.18)

    # Background: rounded rect with gradient (deep blue)
    bg_rect = [margin, margin, w - margin, h - margin]
    draw.rounded_rectangle(bg_rect, radius=corner, fill=(30, 80, 200, 255))

    # Clipboard body (white)
    cb_left = int(w * 0.22)
    cb_right = int(w * 0.78)
    cb_top = int(h * 0.28)
    cb_bottom = int(h * 0.90)

    # Clip (top part of clipboard - darker)
    clip_height = int(h * 0.11)
    clip_top = cb_top - clip_height
    clip_left = int(w * 0.36)
    clip_right = int(w * 0.64)
    draw.rounded_rectangle(
        [clip_left, clip_top + margin * 0.5, clip_right, cb_top],
        radius=int(w * 0.04), fill=(240, 240, 245, 255)
    )
    draw.rounded_rectangle(
        [clip_left + int(w * 0.02), clip_top + margin, clip_right - int(w * 0.02), cb_top + int(h * 0.02)],
        radius=int(w * 0.03), fill=(200, 200, 210, 255)
    )

    # Clipboard paper
    draw.rounded_rectangle(
        [cb_left, cb_top, cb_right, cb_bottom],
        radius=int(w * 0.04), fill=(250, 250, 255, 255)
    )

    # Lines on clipboard
    line_color = (180, 190, 210, 255)
    line_margin = int(w * 0.085)
    for i in range(4):
        y = cb_top + int(h * 0.08) + i * int(h * 0.11)
        line_len = cb_right - cb_left - line_margin * 2
        # First line is wider (header-like)
        if i == 0:
            x_start = cb_left + line_margin
            x_end = x_start + int(line_len * 0.7)
        elif i == 1:
            x_start = cb_left + line_margin
            x_end = x_start + int(line_len * 0.85)
        elif i == 2:
            x_start = cb_left + line_margin
            x_end = x_start + int(line_len * 0.55)
        else:
            x_start = cb_left + line_margin
            x_end = x_start + int(line_len * 0.75)
        draw.rounded_rectangle(
            [x_start, y, x_end, y + max(1, int(h * 0.015))],
            radius=max(1, int(w * 0.008)), fill=line_color
        )


for s in SIZES:
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw_clipboard(draw, s)
    name = f"icon_{s}x{s}.png"
    if s == 16:
        name = "icon_16x16.png"
    elif s == 32:
        name = "icon_16x16@2x.png"
    elif s == 64:
        name = "icon_32x32@2x.png"
    elif s == 128:
        name = "icon_128x128.png"
    elif s == 256:
        name = "icon_256x256.png"
    elif s == 512:
        name = "icon_512x512.png"
    elif s == 1024:
        name = "icon_512x512@2x.png"
    path = os.path.join(OUTPUT_DIR, name)
    img.save(path)
    print(f"  {name} ({s}x{s})")

# Also create 32@1x and 128@2x
img32 = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
draw_clipboard(ImageDraw.Draw(img32), 32)
img32.save(os.path.join(OUTPUT_DIR, "icon_32x32.png"))

img256 = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
draw_clipboard(ImageDraw.Draw(img256), 256)
img256.save(os.path.join(OUTPUT_DIR, "icon_128x128@2x.png"))

img512 = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
draw_clipboard(ImageDraw.Draw(img512), 512)
img512.save(os.path.join(OUTPUT_DIR, "icon_256x256@2x.png"))

print("Done!")
