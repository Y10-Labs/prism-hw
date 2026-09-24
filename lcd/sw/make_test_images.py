#!/usr/bin/env python3
"""
Generate the two test frames for the DDR -> VDMA -> panel path.

    ./make_test_images.py <outdir>

Writes, for each frame N in {0, 1}:
    frameN.png   what it should look like (for eyes)
    frameN.raw   800 x 480 x 4 bytes, the exact frame-buffer layout the VDMA
                 reads: one little-endian 32-bit word per pixel, 0x00RRGGBB
                 (bytes B, G, R, 0 in memory), rows packed, stride 3200 B.

The two frames are deliberately unlike each other, so each one is obvious at
a glance at 5 fps, and between them they exercise every data bit:
    frame 0 "A": R ramps left->right, G ramps top->bottom, B fixed;
                 a white border, and a big A.
    frame 1 "B": hue wheel around the centre, fading to white; grey ramp
                 strip; black border; a big B.
Both carry corner markers (red top-left, green top-right, blue bottom-left)
matching the RTL grid pattern, so orientation is checkable too.
"""

import colorsys
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFont

W, H = 800, 480
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"


def corner_markers(d):
    d.rectangle([0, 0, 23, 23], fill=(255, 0, 0))
    d.rectangle([W - 24, 0, W - 1, 23], fill=(0, 255, 0))
    d.rectangle([0, H - 24, 23, H - 1], fill=(0, 0, 255))


def label(d, text, sub, fg, shadow):
    big = ImageFont.truetype(FONT, 260)
    small = ImageFont.truetype(FONT, 28)
    x0, y0, x1, y1 = d.textbbox((0, 0), text, font=big)
    tx, ty = (W - (x1 - x0)) // 2 - x0, (H - (y1 - y0)) // 2 - y0 - 20
    d.text((tx + 6, ty + 6), text, font=big, fill=shadow)
    d.text((tx, ty), text, font=big, fill=fg)
    x0, _, x1, _ = d.textbbox((0, 0), sub, font=small)
    d.text(((W - (x1 - x0)) // 2, H - 70), sub, font=small, fill=fg)


def frame_a():
    im = Image.new("RGB", (W, H))
    px = im.load()
    for y in range(H):
        g = y * 255 // (H - 1)
        for x in range(W):
            px[x, y] = (x * 255 // (W - 1), g, 96)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, W - 1, H - 1], outline=(255, 255, 255), width=4)
    corner_markers(d)
    label(d, "A", "frame 0  (store 0)", (255, 255, 255), (0, 0, 0))
    return im


def frame_b():
    im = Image.new("RGB", (W, H))
    px = im.load()
    cx, cy, rmax = W / 2, H / 2, math.hypot(W / 2, H / 2)
    for y in range(H):
        for x in range(W):
            hue = (math.atan2(y - cy, x - cx) / (2 * math.pi)) % 1.0
            sat = min(1.0, math.hypot(x - cx, y - cy) / (0.6 * rmax))
            r, g, b = colorsys.hsv_to_rgb(hue, sat, 1.0)
            px[x, y] = (int(r * 255), int(g * 255), int(b * 255))
    d = ImageDraw.Draw(im)
    for x in range(W):                       # 0..255 grey strip along the top
        v = x * 255 // (W - 1)
        d.line([(x, 30), (x, 60)], fill=(v, v, v))
    d.rectangle([0, 0, W - 1, H - 1], outline=(0, 0, 0), width=4)
    corner_markers(d)
    label(d, "B", "frame 1  (store 1)", (20, 20, 20), (255, 255, 255))
    return im


def to_raw(im):
    out = bytearray(W * H * 4)
    i = 0
    for r, g, b in im.getdata():
        out[i] = b; out[i + 1] = g; out[i + 2] = r   # 0x00RRGGBB little-endian
        i += 4
    return bytes(out)


def main():
    outdir = sys.argv[1] if len(sys.argv) > 1 else "."
    os.makedirs(outdir, exist_ok=True)
    for n, im in enumerate((frame_a(), frame_b())):
        im.save(os.path.join(outdir, "frame%d.png" % n))
        with open(os.path.join(outdir, "frame%d.raw" % n), "wb") as f:
            f.write(to_raw(im))
        print("frame%d: %s/frame%d.{png,raw}" % (n, outdir, n))


if __name__ == "__main__":
    main()
