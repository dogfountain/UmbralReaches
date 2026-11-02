#!/usr/bin/env python3
"""Palette/brightness stats for look comparison. Usage: python3 tools/palette_stats.py shot1.png shot2.png ...
Optional: --crop=l,t,r,b as fractions (default 0,0,1,1) to cut off UI/overlays.
Coloured pixel = saturation > 0.25 and value > 0.12. Hue shares are of coloured pixels only.
Needs Pillow. Numpy is optional."""
import sys
from PIL import Image

try:
    import numpy as np
except ImportError:
    np = None

BANDS = [("red", 330, 20), ("orange/yellow", 20, 70), ("green", 70, 150), ("teal/cyan", 150, 200),
         ("blue", 200, 250), ("violet", 250, 290), ("magenta", 290, 330)]


def hsv_np(a):
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    mx, mn = a.max(-1), a.min(-1)
    d = mx - mn
    h = np.zeros_like(mx)
    m = d > 1e-6
    rc = (mx == r) & m
    gc = (mx == g) & m & ~rc
    bc = m & ~rc & ~gc
    h[rc] = ((g - b)[rc] / d[rc]) % 6
    h[gc] = (b - r)[gc] / d[gc] + 2
    h[bc] = (r - g)[bc] / d[bc] + 4
    return h * 60, np.where(mx > 1e-6, d / np.maximum(mx, 1e-6), 0), mx


def inband(h, lo, hi):
    return (h >= lo) & (h < hi) if lo < hi else (h >= lo) | (h < hi)


def rgb_to_hsv(r, g, b):
    mx = max(r, g, b)
    mn = min(r, g, b)
    d = mx - mn
    if d < 1e-6:
        h = 0.0
    elif mx == r:
        h = ((g - b) / d) % 6.0
    elif mx == g:
        h = (b - r) / d + 2.0
    else:
        h = (r - g) / d + 4.0
    s = d / mx if mx > 1e-6 else 0.0
    return h * 60.0, s, mx


def stats_py(im):
    px = list(im.getdata())
    n = len(px)
    hues = []
    lumas = []
    coloured = 0
    near_black = 0
    very_bright = 0
    shares = [0] * len(BANDS)
    for r8, g8, b8 in px:
        r, g, b = r8 / 255.0, g8 / 255.0, b8 / 255.0
        luma = 0.2126 * r + 0.7152 * g + 0.0722 * b
        lumas.append(luma)
        if luma < 0.05:
            near_black += 1
        if luma > 0.8:
            very_bright += 1
        h, s, v = rgb_to_hsv(r, g, b)
        if s > 0.25 and v > 0.12:
            coloured += 1
            hues.append(h)
            for i, (_, lo, hi) in enumerate(BANDS):
                if (lo <= h < hi) if lo < hi else (h >= lo or h < hi):
                    shares[i] += 1
    lumas.sort()
    mid = lumas[n // 2] if n else 0.0
    denom = max(coloured, 1)
    return (coloured / max(n, 1) * 100.0, mid, near_black / max(n, 1) * 100.0,
            very_bright / max(n, 1) * 100.0, [s / denom * 100.0 for s in shares])


def main():
    crop = (0.0, 0.0, 1.0, 1.0)
    files = []
    for arg in sys.argv[1:]:
        if arg.startswith("--crop="):
            crop = tuple(float(x) for x in arg.split("=")[1].split(","))
        else:
            files.append(arg)
    print("file | coloured% | median luma | near-black% (<0.05) | very bright% (>0.8) | " + " ".join(n for n, _, _ in BANDS))
    for p in files:
        im = Image.open(p).convert("RGB")
        w, h_ = im.size
        im = im.crop((int(w * crop[0]), int(h_ * crop[1]), int(w * crop[2]), int(h_ * crop[3])))
        if np is not None:
            a = np.asarray(im).astype(np.float32) / 255
            h, s, v = hsv_np(a)
            luma = a @ np.array([0.2126, 0.7152, 0.0722], dtype=np.float32)
            col = (s > 0.25) & (v > 0.12)
            n = max(int(col.sum()), 1)
            shares = " ".join(f"{(inband(h, lo, hi) & col).sum() / n * 100:3.0f}" for _, lo, hi in BANDS)
            print(f"{p} | {col.mean()*100:3.0f} | {np.median(luma):.3f} | {(luma < 0.05).mean()*100:3.0f} | {(luma > 0.8).mean()*100:4.1f} | {shares}")
        else:
            coloured, mid, nb, vb, shares = stats_py(im)
            share_s = " ".join(f"{x:3.0f}" for x in shares)
            print(f"{p} | {coloured:3.0f} | {mid:.3f} | {nb:3.0f} | {vb:4.1f} | {share_s}")


if __name__ == "__main__":
    main()
