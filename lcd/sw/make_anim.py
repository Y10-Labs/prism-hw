#!/usr/bin/env python3
"""
Generate a seamless N-frame animation for 60 fps VDMA playback, stored as
one full background frame plus small per-frame patches.

    ./make_anim.py <out.anim> [--frames 32] [--png-dir DIR]

Every frame = the background + its own few changed rectangles, so only the
differences cross the 115200-baud UART; lcdctl.py `anim load` rebuilds all N
frames in the reserved DDR on the board.

Content, one full loop per N frames (so it repeats without a jump):
  - a ball orbiting the centre, 1/N of a turn per frame
  - a clock-style spoke turning the other way, 1/N turn per frame
  - a counter "07/32": the frame index, to spot dropped or repeated frames
    in a slow-motion phone video (at 60 fps each frame is 16.6 ms)

File format (little-endian), gzip-compressed as a whole:
  magic  b"LCDANIM1"
  u16 width, u16 height, u16 nframes, u16 bytes_per_pixel (4)
  background: width*height*4 bytes, XRGB8888 (0x00RRGGBB)
  per frame: u16 nrects, then per rect: u16 x, y, w, h + w*h*4 pixel bytes
"""

import argparse
import gzip
import math
import os
import struct

from PIL import Image, ImageChops, ImageDraw, ImageFont

W, H = 800, 480
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
CX, CY = 400, 250          # centre of the stage
ORBIT = 150                # ball orbit radius
BALL = 28                  # ball radius
SPOKE = 95                 # spoke length


def background():
    im = Image.new("RGB", (W, H))
    px = im.load()
    for y in range(H):                     # dim blue-to-purple backdrop
        for x in range(W):
            px[x, y] = (20 + x * 40 // W, 16, 50 + y * 60 // H)
    d = ImageDraw.Draw(im)
    d.ellipse([CX - ORBIT - BALL - 12, CY - ORBIT - BALL - 12,
               CX + ORBIT + BALL + 12, CY + ORBIT + BALL + 12], fill=(8, 8, 16))
    d.ellipse([CX - ORBIT, CY - ORBIT, CX + ORBIT, CY + ORBIT],
              outline=(70, 70, 90), width=2)
    d.rectangle([0, 0, W - 1, H - 1], outline=(255, 255, 255), width=3)
    d.rectangle([0, 0, 23, 23], fill=(255, 0, 0))
    d.rectangle([W - 24, 0, W - 1, 23], fill=(0, 255, 0))
    d.rectangle([0, H - 24, 23, H - 1], fill=(0, 0, 255))
    title = ImageFont.truetype(FONT, 26)
    d.text((40, 20), "DDR -> VDMA -> LCD @ 60 fps", font=title, fill=(230, 230, 230))
    d.rectangle([600, 400, 770, 455], fill=(0, 0, 0))   # counter box
    return im


def frame(bg, i, n):
    im = bg.copy()
    d = ImageDraw.Draw(im)
    a = 2 * math.pi * i / n
    bx, by = CX + ORBIT * math.cos(a), CY + ORBIT * math.sin(a)
    d.ellipse([bx - BALL, by - BALL, bx + BALL, by + BALL], fill=(255, 200, 40),
              outline=(255, 255, 255), width=2)
    s = -a                                  # spoke turns the other way
    d.line([(CX, CY), (CX + SPOKE * math.cos(s), CY + SPOKE * math.sin(s))],
           fill=(80, 220, 255), width=6)
    d.ellipse([CX - 8, CY - 8, CX + 8, CY + 8], fill=(255, 255, 255))
    f = ImageFont.truetype(FONT, 36)
    d.text((612, 406), "%02d/%02d" % (i, n), font=f, fill=(0, 255, 120))
    return im


def xrgb(im):
    out = bytearray(im.width * im.height * 4)
    k = 0
    for r, g, b in im.getdata():
        out[k] = b; out[k + 1] = g; out[k + 2] = r
        k += 4
    return bytes(out)


def changed_rects(bg, im):
    """Bounding boxes of the differences, one per region of interest, so a
    frame is a few small patches instead of one box spanning them all."""
    regions = [(CX - ORBIT - BALL - 12, CY - ORBIT - BALL - 12,
                CX + ORBIT + BALL + 13, CY + ORBIT + BALL + 13),   # stage
               (600, 400, 771, 456)]                              # counter
    rects = []
    for reg in regions:
        diff = ImageChops.difference(bg.crop(reg), im.crop(reg)).getbbox()
        if diff:
            x0, y0, x1, y1 = diff
            rects.append((reg[0] + x0, reg[1] + y0, x1 - x0, y1 - y0))
    return rects


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("out")
    ap.add_argument("--frames", type=int, default=32)
    ap.add_argument("--png-dir")
    a = ap.parse_args()

    os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
    if a.png_dir:
        os.makedirs(a.png_dir, exist_ok=True)
    bg = background()
    blob = bytearray(b"LCDANIM1" + struct.pack("<4H", W, H, a.frames, 4))
    blob += xrgb(bg)
    patch_bytes = 0
    for i in range(a.frames):
        im = frame(bg, i, a.frames)
        if a.png_dir:
            im.save("%s/anim%02d.png" % (a.png_dir, i))
        rects = changed_rects(bg, im)
        blob += struct.pack("<H", len(rects))
        for (x, y, w, h) in rects:
            blob += struct.pack("<4H", x, y, w, h)
            blob += xrgb(im.crop((x, y, x + w, y + h)))
            patch_bytes += w * h * 4
    z = gzip.compress(bytes(blob), 9)
    open(a.out, "wb").write(z)
    full = a.frames * W * H * 4
    print("%d frames: patches %d B (%.1f%% of %d B of full frames), file %d B gzipped"
          % (a.frames, patch_bytes, 100.0 * patch_bytes / full, full, len(z)))


if __name__ == "__main__":
    main()
