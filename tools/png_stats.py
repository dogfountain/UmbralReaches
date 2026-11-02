#!/usr/bin/env python3
"""Stdlib palette stats (no Pillow/numpy). Same bands as palette_stats.py."""
import struct
import sys
import zlib

BANDS = [("red", 330, 20), ("orange/yellow", 20, 70), ("green", 70, 150), ("teal/cyan", 150, 200),
         ("blue", 200, 250), ("violet", 250, 290), ("magenta", 290, 330)]


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


def read_png(path):
    with open(path, "rb") as f:
        assert f.read(8) == b"\x89PNG\r\n\x1a\n"
        w = h = None
        raw = b""
        while True:
            length = struct.unpack(">I", f.read(4))[0]
            ctype = f.read(4)
            data = f.read(length)
            f.read(4)
            if ctype == b"IHDR":
                w, h, bit, color = struct.unpack(">IIBB", data[:10])
                if bit != 8 or color not in (2, 6):
                    raise SystemExit("need 8-bit RGB/RGBA: %s" % path)
            elif ctype == b"IDAT":
                raw += data
            elif ctype == b"IEND":
                break
    rows = zlib.decompress(raw)
    bpp = 3 if color == 2 else 4
    stride = 1 + w * bpp
    px = []
    prev = bytes(w * bpp)
    for y in range(h):
        filt = rows[y * stride]
        scan = bytearray(rows[y * stride + 1:y * stride + stride])
        if filt == 1:
            for i in range(len(scan)):
                scan[i] = (scan[i] + (scan[i - bpp] if i >= bpp else 0)) & 255
        elif filt == 2:
            for i in range(len(scan)):
                scan[i] = (scan[i] + prev[i]) & 255
        elif filt == 3:
            for i in range(len(scan)):
                a = scan[i - bpp] if i >= bpp else 0
                scan[i] = (scan[i] + ((a + prev[i]) // 2)) & 255
        elif filt == 4:
            for i in range(len(scan)):
                a = scan[i - bpp] if i >= bpp else 0
                b = prev[i]
                c = prev[i - bpp] if i >= bpp else 0
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pr = a if pa <= pb and pa <= pc else (b if pb <= pc else c)
                scan[i] = (scan[i] + pr) & 255
        prev = bytes(scan)
        px.append(scan)
    return w, h, bpp, b"".join(px)


def main():
    print("file | coloured% | median luma | near-black% (<0.05) | very bright% (>0.8) | " + " ".join(n for n, _, _ in BANDS))
    for path in sys.argv[1:]:
        w, h, bpp, data = read_png(path)
        n = w * h
        lumas = []
        coloured = near_black = very_bright = 0
        shares = [0] * len(BANDS)
        for i in range(n):
            o = i * bpp
            r, g, b = data[o] / 255.0, data[o + 1] / 255.0, data[o + 2] / 255.0
            luma = 0.2126 * r + 0.7152 * g + 0.0722 * b
            lumas.append(luma)
            if luma < 0.05:
                near_black += 1
            if luma > 0.8:
                very_bright += 1
            hv, s, v = rgb_to_hsv(r, g, b)
            if s > 0.25 and v > 0.12:
                coloured += 1
                for bi, (_, lo, hi) in enumerate(BANDS):
                    if (lo <= hv < hi) if lo < hi else (hv >= lo or hv < hi):
                        shares[bi] += 1
        lumas.sort()
        mid = lumas[n // 2]
        denom = max(coloured, 1)
        share_s = " ".join("%3.0f" % (s / denom * 100.0) for s in shares)
        print("%s | %3.0f | %.3f | %3.0f | %4.1f | %s" % (
            path, coloured / n * 100.0, mid, near_black / n * 100.0, very_bright / n * 100.0, share_s))


if __name__ == "__main__":
    main()
