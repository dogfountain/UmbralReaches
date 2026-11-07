"""Reusable painted motifs for the smaller icon sets: flames, orbs, crystals, faces, rays, rings."""
import numpy as np

from paint import *  # noqa: F401,F403

C = hex_rgb


def metal(sd, width, dark, light, spec, glowc=None, glowamt=0.0, lightdir=(-0.55, -0.65), shine=24.0):
    d, sp, h = bevel(sd, width, light=lightdir, shine=shine)
    col = mix(np.asarray(dark), np.asarray(light), d) + np.asarray(spec) * sp[..., None] * 0.9
    if glowc is not None:
        col = col + np.asarray(glowc) * (glowamt * (1 - h))[..., None]
    return col


def solid(img, sd, dark, light, spec, width=0.05, halo=None, halo_r=0.08, halo_amt=0.4, texture=0.0, seed=0, **kw):
    """Composite a lit, bevelled object over img (with an optional outer halo)."""
    if halo is not None:
        img = add(img, C(halo) if isinstance(halo, str) else halo, np.exp(-np.maximum(sd, 0) / halo_r) * halo_amt)
    col = metal(sd, width, C(dark), C(light), C(spec), **kw)
    if texture:
        col = col * (1 - texture + texture * 1.6 * nz(48, seed + 3)[..., None])
    return over(img, col, smooth(sd))


def flame_sd(cx, cy, h, w, lean=0.0, px=None, py=None):
    """A teardrop flame, tip up, belly at cy. h = height above belly, w = half-width."""
    px = x if px is None else px
    py = y if py is None else py
    t = (cy - py) / h                                   # 0 at the belly line, 1 at the tip
    body = np.where(t >= 0, np.sqrt(np.clip(1 - np.clip(t, 0, 1) ** 1.5, 0, 1)),
                    np.sqrt(np.clip(1 - (t / 0.45) ** 2, 0, 1)))
    cxl = cx + lean * np.clip(t, 0, 1) ** 2
    sd = (np.abs(px - cxl) - w * body) * 0.9
    # capped at the tip and the belly: past them the body is zero-width and would trail a hairline
    return np.maximum(sd, np.maximum((t - 1.0) * h, -(t + 0.45) * h))


def fire(img, cx, cy, h, w, seed, lean=0.0, strength=1.0, cool=False):
    """Layered painted flame: outer orange, mid yellow, hot white core, with licking noise."""
    wx = x + (nz(7, seed, py=y * 1.0) - 0.5) * 0.07 * (1 + np.clip((cy - y) / h, 0, 1))
    outer = flame_sd(cx, cy, h, w, lean, wx, y)
    mid = flame_sd(cx, cy + 0.02, h * 0.72, w * 0.62, lean * 0.6, wx, y)
    core = flame_sd(cx, cy + 0.03, h * 0.42, w * 0.32, lean * 0.3, wx, y)
    pal = ("#2a6bff", "#7fd0ff", "#eaffff") if cool else ("#ff4a10", "#ffb02a", "#fff4c8")
    img = add(img, C(pal[0]), np.exp(-np.maximum(outer, 0) / 0.12) * 0.55 * strength)
    img = over(img, C(pal[0]) * 1.1, smooth(outer) * 0.95)
    img = over(img, C(pal[1]), smooth(mid))
    img = over(img, C(pal[2]), smooth(core))
    return img


def orb(img, cx, cy, r, dark, light, spark="#ffffff", halo=None, halo_amt=0.7, swirl=0.0, seed=0):
    d = np.hypot(x - cx, y - cy)
    if halo is not None:
        img = add(img, C(halo), np.exp(-np.maximum(d - r, 0) / (r * 0.8)) * halo_amt)
    sph = np.sqrt(np.clip(1 - (d / r) ** 2, 0, 1))
    t = sph
    if swirl:
        t = np.clip(sph * 0.9 + (nz(6, seed, px=(x - cx) * 1.5, py=(y - cy) * 1.5) - 0.5) * swirl, 0, 1)
    col = mix(C(dark), C(light), t)
    col = col + C(spark) * (np.exp(-np.hypot(x - cx + r * 0.3, y - cy + r * 0.35) / (r * 0.22)) * 0.85)[..., None]
    col = col + C(light) * (ss(0.7, 1.0, d / r) * 0.5)[..., None]
    return over(img, col, smooth(d - r))


def rays(img, cx, cy, n, col, length=0.7, power=24, amt=0.5, rot_=0.0):
    r = np.hypot(x - cx, y - cy)
    a = np.arctan2(y - cy, x - cx)
    k = (np.abs(np.cos((a - rot_) * n / 2)) ** power) * np.exp(-r / length)
    return add(img, C(col), k * amt)


def cracks(seed, scale=7.0, width=0.06):
    """Thin bright network (cracks / veins): 1 on the lines."""
    n = nz(scale, seed, octaves=4)
    return np.exp(-(np.abs(n - 0.5) / width) ** 2)


def scene(top, bottom, seed, cloud=None, cloud_amt=0.4, glow_at=None, glow_col=None, glow_r=0.7, stars_=0):
    img = backdrop(C(top), C(bottom), seed, cloud=C(cloud) if cloud else None, cloud_amt=cloud_amt, scale=2.4,
                   centre=glow_at or (0, 0), centre_col=C(glow_col) * 0.7 if glow_col else None, centre_r=glow_r)
    if stars_:
        img = add(img, C("#e8e8ff"), stars(seed + 1, stars_, 0.4))
    return img


def C_(s):
    return C(s)


# --- shared by the repainted illustration sets --------------------------------------------------

def poly(pts, px=None, py=None):
    """Signed distance to a simple polygon (negative inside). pts = [(x, y), ...] in the -1..1 square."""
    px = x if px is None else px
    py = y if py is None else py
    d = np.full(np.shape(px), 1e9)
    inside = np.zeros(np.shape(px), dtype=bool)
    n = len(pts)
    for i in range(n):
        ax, ay = pts[i]
        bx, by = pts[(i + 1) % n]
        d = np.minimum(d, segment(ax, ay, bx, by, px, py))
        cond = ((ay > py) != (by > py)) & (px < (bx - ax) * (py - ay) / (by - ay + 1e-12) + ax)
        inside ^= cond
    return np.where(inside, -d, d)


def xf(px, py, dx=0.0, dy=0.0, ang=0.0, cx=0.0, cy=0.0):
    """Coordinates for evaluating a shape that was moved by (dx, dy) and turned by ang about (cx, cy)."""
    qx, qy = px - dx - cx, py - dy - cy
    c, s = np.cos(ang), np.sin(ang)
    return qx * c + qy * s + cx, -qx * s + qy * c + cy


def smin(a, b, k=0.06):
    """Smooth union of two distance fields."""
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0, 1)
    return b * (1 - h) + a * h - k * h * (1 - h)


def obj(img, sd, dark, light, spec, width=0.06, outline=0.03, halo=None, halo_amt=0.45, halo_r=0.07, texture=0.0, seed=0, **kw):
    """A lit object with a dark painted outline (so its silhouette holds at 30 px) and an optional halo."""
    if halo is not None:
        img = add(img, C(halo), np.exp(-np.maximum(sd, 0) / halo_r) * halo_amt)
    img = over(img, C("#050304"), smooth(sd - outline) * 0.94)
    col = metal(sd, width, C(dark), C(light), C(spec), **kw)
    if texture:
        col = col * (1 - texture + texture * 1.6 * nz(48, seed + 3)[..., None])
    return over(img, col, smooth(sd))


def ground(top, bottom, seed, glow_col, glow_at=(0, 0), glow_r=0.7, stars_=0):
    img = scene(top, bottom, seed, glow_col, 0.45, glow_at, glow_col, glow_r, stars_)
    return img
