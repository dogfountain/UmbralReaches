"""Shared helpers for the painted object icons (items, food, works): polygons, ropes along a path,
height-field lit lumps, drop shadows, grain. Built on paint.py and motifs.py."""
import numpy as np

from motifs import *  # noqa: F401,F403


def poly(pts, px=None, py=None):
    """Signed distance to a polygon (negative inside)."""
    px = x if px is None else px
    py = y if py is None else py
    d = None
    inside = np.zeros(px.shape, dtype=bool)
    n = len(pts)
    for i in range(n):
        ax, ay = pts[i]
        bx, by = pts[(i + 1) % n]
        s = segment(ax, ay, bx, by, px, py)
        d = s if d is None else np.minimum(d, s)
        inside ^= ((ay > py) != (by > py)) & (px < (bx - ax) * (py - ay) / (by - ay + 1e-12) + ax)
    return np.where(inside, -d, d)


def path_t(pts, px=None, py=None):
    """Distance to a polyline plus the arc-length parameter and signed side of the nearest point."""
    px = x if px is None else px
    py = y if py is None else py
    best = np.full(px.shape, 9.0)
    tt = np.zeros(px.shape)
    side = np.zeros(px.shape)
    acc = 0.0
    for i in range(len(pts) - 1):
        ax, ay = pts[i]
        bx, by = pts[i + 1]
        dx, dy = bx - ax, by - ay
        L = np.hypot(dx, dy) + 1e-9
        t = np.clip(((px - ax) * dx + (py - ay) * dy) / (L * L), 0, 1)
        qx, qy = ax + dx * t, ay + dy * t
        dd = np.hypot(px - qx, py - qy)
        sg = np.sign((px - ax) * dy - (py - ay) * dx)
        m = dd < best
        best = np.where(m, dd, best)
        tt = np.where(m, acc + t * L, tt)
        side = np.where(m, sg * dd, side)
        acc += L
    return best, tt, side


def curve(fn, n=40):
    return [fn(i / (n - 1)) for i in range(n)]


def heart_sd(cx, cy, s, px=None, py=None):
    px = x if px is None else px
    py = y if py is None else py
    u = (px - cx) / s * 1.15
    v = -(py - cy) / s * 1.15 - 0.1
    f = (u * u + v * v - 1) ** 3 - u * u * v ** 3
    gy, gx = np.gradient(f)
    g = np.hypot(gx, gy) / PX + 1e-6
    return f / g


def shadow(img, sd, off=(0.04, 0.06), amt=0.55, soft=5.0):
    m = smooth(sd)
    dx = int(round(off[0] / PX))
    dy = int(round(off[1] / PX))
    sh = blur(np.roll(np.roll(m, dy, 0), dx, 1), soft)
    return img * (1 - amt * np.clip(sh, 0, 1))[..., None]


def floor_shadow(img, cx, cy, rx, ry, amt=0.6):
    sd = ellipse(cx, cy, rx, ry)
    sh = blur(smooth(sd), 6)
    return img * (1 - amt * np.clip(sh, 0, 1))[..., None]


def piece(img, sd, dark, light, spec, width=0.06, tex=None, shadowed=True, glowc=None, glowamt=0.0,
          shine=24.0, lightdir=(-0.55, -0.65), alpha=1.0, relief=0.9, rim=None, rim_amt=0.4):
    """A bevel-lit object over img with an optional drop shadow, texture multiplier and rim light."""
    if shadowed:
        img = shadow(img, sd)
    d, sp, h = bevel(sd, width, relief=relief, light=lightdir, shine=shine)
    col = mix(C(dark) if isinstance(dark, str) else np.asarray(dark),
              C(light) if isinstance(light, str) else np.asarray(light), d)
    col = col + (C(spec) if isinstance(spec, str) else np.asarray(spec)) * sp[..., None] * 0.9
    if tex is not None:
        col = col * np.asarray(tex)[..., None]
    if glowc is not None:
        col = col + (C(glowc) if isinstance(glowc, str) else np.asarray(glowc)) * (glowamt * (1 - h))[..., None]
    if rim is not None:
        col = col + (C(rim) if isinstance(rim, str) else np.asarray(rim)) * (rim_amt * ss(0.55, 1.0, 1 - h) * (1 - h))[..., None]
    return over(img, col, smooth(sd) * alpha)


def grain(u, v, seed, scale=3.0, fine=38.0, amt=0.8):
    """Wood / fibre grain: stretched noise along u."""
    g = fbm(u * scale + 3.0, v * fine, seed, 4)
    return 0.62 + amt * g


def rough(seed, scale=14.0, amt=1.1, base=0.6):
    return base + amt * nz(scale, seed, octaves=4) * 0.6 + 0.35 * nz(scale * 4, seed + 4, octaves=2)


def heightlit(Z, mask, dark, light, spec, img, k=55.0, lightdir=(-0.55, -0.65), shine=18.0, shadowed=True, tex=None):
    """A lumpy height-field object (ash, ore, stone): lit from the gradient. mask is a signed distance."""
    if shadowed:
        img = shadow(img, mask)
    Zb = blur(Z, 0.9)
    gy, gx = np.gradient(Zb)
    nx, ny = -gx * k, -gy * k
    inv = 1.0 / np.sqrt(nx * nx + ny * ny + 1.0)
    nx, ny, nzv = nx * inv, ny * inv, inv
    lx, ly = lightdir
    lz = 0.62
    ln = np.sqrt(lx * lx + ly * ly + lz * lz)
    dif = np.clip((nx * lx + ny * ly + nzv * lz) / ln, 0, 1)
    hv = np.array([lx, ly, lz + 0.8]) / np.linalg.norm([lx, ly, lz + 0.8])
    sp = np.clip(nx * hv[0] + ny * hv[1] + nzv * hv[2], 0, 1) ** shine
    occl = 0.55 + 0.6 * np.clip(Zb, 0, 1)
    col = mix(C(dark), C(light), np.clip(dif * 1.15, 0, 1)) * occl[..., None] + C(spec) * sp[..., None] * 0.5
    if tex is not None:
        col = col * np.asarray(tex)[..., None]
    # a dark crease where the object meets the ground
    edge = ss(0.0, 0.06, -mask)
    col = col * (0.55 + 0.45 * edge)[..., None]
    return over(img, col, smooth(mask))


def lump(cx, cy, rx, ry, seed, rough_amt=0.25, scale=4.0):
    """A noisy blob: returns (signed distance, height field)."""
    wx, wy = warp(rough_amt * 0.4, scale, seed)
    sd = ellipse(cx, cy, rx, ry, wx, wy)
    Z = np.clip(-sd / (min(rx, ry) * 0.9), 0, 1)
    Z = Z * (0.75 + 0.5 * nz(scale * 2.5, seed + 7, octaves=4))
    return sd, Z


def pool(img, cx, cy, r, col, amt=0.4):
    d = np.hypot(x - cx, y - cy)
    return add(img, C(col) if isinstance(col, str) else col, np.exp(-(d / r) ** 2) * amt)


def glass(img, sd, tint, edge, amt=0.35, hi=0.8):
    """Translucent glass body: a tint over what is behind, a bright rim, a diagonal sheen."""
    m = smooth(sd)
    h = np.clip(-sd / 0.07, 0, 1)
    d, sp, hh = bevel(sd, 0.07, relief=0.6, shine=40.0)
    img = over(img, mix(img, C(tint), amt), m)
    img = add(img, C(edge), (1 - h) * m * 0.5)
    img = add(img, np.array([1.0, 1.0, 1.0]), sp * hi * m * 0.5)
    return img


def bloom_light(img, cx, cy, r, col, amt=0.8):
    d = np.hypot(x - cx, y - cy)
    return add(img, C(col), np.exp(-d / r) * amt)


def tuple_c(c):
    return C(c) if isinstance(c, str) else c


def flame(img, cx, cy, h, w, seed, lean=0.0, strength=1.0, cool=False):
    """fire() limited to the flame's own box, so the tip never trails a hairline up the icon."""
    out = fire(img, cx, cy, h, w, seed, lean, strength, cool)
    reg = smooth(box(cx, cy - h * 0.5 + 0.04, w * 2.6 + 0.06, h * 0.55 + 0.06), 3.0)
    return mix(img, out, reg)


def cord_path(pts, width, dark, light, seed, img, freq=60.0, shadowed=True):
    d, tt, side = path_t(pts)
    tw = 0.65 + 0.4 * np.sin(tt * freq + side / width * 3.0)
    return piece(img, d - width, dark, light, "#ffffff", width, tex=tw, shadowed=shadowed, shine=10.0)


def rotated_poly(pts, cx, cy, ang):
    c, s = np.cos(ang), np.sin(ang)
    return [(cx + (px_ - cx) * c - (py_ - cy) * s, cy + (px_ - cx) * s + (py_ - cy) * c) for px_, py_ in pts]


def steam(img, cx, y0, y1, seed, amt=0.25, col="#fff4e0", n=3, spread=0.12):
    """Soft rising wisps between y0 (base) and y1 (top, smaller y)."""
    for i in range(n):
        ph = seed * 0.7 + i * 2.1
        wob = cx + (i - (n - 1) / 2) * spread + 0.06 * np.sin((y - y0) * 11.0 + ph)
        fade = ss(y0, y0 + (y1 - y0) * 0.25, y) * ss(y1, y1 + (y0 - y1) * 0.5, y)
        w = 0.035 + 0.03 * ss(y0, y1, y)
        img = add(img, C(col), np.exp(-((x - wob) / w) ** 2) * fade * amt * (0.6 + 0.6 * nz(6, seed + i)))
    return img


def tankard(img, cx, cy, s, seed, foam=True, glowc="#ff9a3a"):
    """A wooden-staved, iron-hooped tankard with a handle. Returns img."""
    body = poly([(cx - 0.3 * s, cy - 0.38 * s), (cx + 0.3 * s, cy - 0.38 * s), (cx + 0.34 * s, cy + 0.4 * s), (cx - 0.34 * s, cy + 0.4 * s)])
    handle = np.abs(ellipse(cx + 0.38 * s, cy + 0.02 * s, 0.22 * s, 0.26 * s)) - 0.045 * s
    handle = np.maximum(handle, -(x - (cx + 0.3 * s)) )
    img = piece(img, handle, "#2a1608", "#8a6038", "#e8c090", 0.045 * s, tex=grain(y, x, seed, 3, 30, 0.7))
    stave = grain(y, x, seed + 1, 2.5, 46.0, 0.9)
    img = piece(img, body, "#2e1a0c", "#a87848", "#f0d0a0", 0.28 * s, tex=stave * (0.8 + 0.3 * np.sin((x - cx) / (0.07 * s) * 3.14159) ** 2), shine=12.0)
    for hy in (-0.22, 0.26):
        hoop = box(cx, cy + hy * s, 0.33 * s + 0.01 * (hy > 0), 0.028 * s)
        img = piece(img, hoop, "#101010", "#6a6864", "#f0f0f0", 0.03 * s, shadowed=False)
    if foam:
        fm = ellipse(cx, cy - 0.38 * s, 0.31 * s, 0.1 * s)
        img = piece(img, fm, "#c8a860", "#fff2d0", "#ffffff", 0.1 * s, glowc=glowc, glowamt=0.2, shadowed=False)
    return img
