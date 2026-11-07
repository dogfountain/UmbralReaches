"""Painters for the gear icons: one object per slot (staff head, vestment, lamp-glass, girdle), lit from the
upper left, over a soft dark backdrop tinted by the piece's rarity. tools/icon_kit/gear.py holds the specs."""
import numpy as np

from paint import *  # noqa: F401,F403
import paint as P

C = hex_rgb

# (dark, light, specular) per material
MAT = {
    "iron": ("#16171c", "#7d838c", "#eef2f8"),
    "darkiron": ("#0c0c10", "#444853", "#b8c0d0"),
    "bronze": ("#2e1a0a", "#b8783a", "#ffe2a8"),
    "gilt": ("#4e3208", "#e2b34f", "#fff3b8"),
    "bone": ("#4a4132", "#dfd5ba", "#fffff0"),
    "wood": ("#180e06", "#7c5430", "#d4a878"),
    "pale": ("#4a4030", "#d8c8a0", "#fff8e0"),
    "leather": ("#150b06", "#6c4226", "#b8906a"),
    "darkleather": ("#0c0705", "#3e2616", "#8a6a4a"),
    "stone": ("#1c1d1c", "#7a7c74", "#d0d4c8"),
    "silver": ("#25282e", "#aeb6c4", "#ffffff"),
    "rust": ("#1c0e08", "#8a4a2a", "#e0a070"),
}

RARITY = ["#B4AEBE", "#F0B45E", "#9CCBFF", "#C38CFF", "#FF6E9A"]


def mcol(m):
    return tuple(C(c) for c in MAT[m]) if isinstance(m, str) else tuple(C(c) for c in m)


def grain(seed, scale=40.0, stretch=(1.0, 0.15)):
    return nz(scale, seed, px=x * stretch[0] * 1.0, py=y * stretch[1] * 1.0, octaves=4)


def part(img, sd, mat, width=0.05, shadow=0.55, tex=0.0, seed=0, relief=0.9, shine=24.0, tint=None, texmap=None, glowc=None):
    """A lit, bevelled solid with a soft cast shadow to the lower right."""
    m = smooth(sd)
    if shadow > 0:
        sh = blur(np.roll(np.roll(m, 5, axis=1), 7, axis=0), 5.0)
        img = img * (1 - shadow * np.clip(sh, 0, 1) * (1 - m))[..., None]
    dk, lt, sp = mcol(mat)
    d, s, h = bevel(sd, width, relief=relief, shine=shine)
    col = mix(dk, lt, d) + sp * (s * 0.85)[..., None]
    if tint is not None:
        col = col * C(tint) * 1.4 if isinstance(tint, str) else col * tint
    if tex:
        t = texmap if texmap is not None else nz(60, seed + 3, octaves=3)
        col = col * (1 - tex + tex * 1.7 * t[..., None])
    if glowc is not None:
        col = col + C(glowc) * (0.35 * (1 - h))[..., None]
    return over(img, col, m)


def ground(rar, seed, tint=None):
    """The painted backdrop: a soft dark ground in the rarity colour, a light pool upper left, motes."""
    base = C(tint if tint else RARITY[rar])
    lum = np.array([0.18, 0.18, 0.18])
    dim = base * 0.16 + lum * 0.02
    img = backdrop(dim * 0.9, dim * 0.32 + 0.004, seed, cloud=base * 0.28, cloud_amt=0.3, scale=2.5,
                   centre=(-0.35, -0.4), centre_col=base * (0.42 + 0.06 * rar), centre_r=0.85)
    img = add(img, base * 0.9 + 0.1, stars(seed + 2, 26, 0.22 + 0.04 * rar))
    # a faint floor shadow pool under the object
    img = img * (1 - 0.35 * np.exp(-((x / 0.7) ** 2 + ((y - 0.82) / 0.14) ** 2)))[..., None]
    return img


def rimline(img, rar, tint=None):
    """A thin inner rim in the rarity colour: faint for plain, bright for the great ones."""
    base = C(tint if tint else RARITY[rar])
    m = np.maximum(np.abs(x), np.abs(y))
    line = np.exp(-((m - 0.935) / 0.012) ** 2)
    glow = np.exp(-np.maximum(0.935 - m, 0) / 0.05) * (m < 0.935) * 0.05
    amt = 0.28 + 0.14 * rar
    return img + base[None, None, :] * ((line * amt) + glow * rar * 0.4)[..., None]


def orb_glass(img, cx, cy, r, dark, light, halo=None, haloamt=0.5, swirl=0.6, seed=0, hollow=False, stars_=False):
    d = np.hypot(x - cx, y - cy)
    if halo is not None:
        img = add(img, C(halo), np.exp(-np.maximum(d - r, 0) / (r * 0.7)) * haloamt)
    sph = np.sqrt(np.clip(1 - (d / r) ** 2, 0, 1))
    sw = nz(5, seed, px=(x - cx) * 1.5 + (y - cy) * 0.5, py=(y - cy) * 1.5 - (x - cx) * 0.5)
    t = np.clip(sph * 0.8 + (sw - 0.5) * swirl, 0, 1)
    col = mix(C(dark), C(light), t)
    if stars_:
        col = col + C("#cfd8ff") * (stars(seed + 4, 30, 0.9) * (d < r))[..., None]
    col = col + C(light) * (ss(0.72, 1.0, d / r) * 0.55)[..., None]
    hx, hy = cx - r * 0.38, cy - r * 0.42
    col = col + C("#ffffff") * (np.exp(-(np.hypot(x - hx, (y - hy) * 1.4) / (r * 0.2)) ** 2) * 0.9)[..., None]
    col = col + C("#ffffff") * (np.exp(-(np.hypot(x - cx + r * 0.3, y - cy - r * 0.55) / (r * 0.35)) ** 2) * 0.12)[..., None]
    return over(img, col, smooth(d - r))


def stitches(sd_edge, inset, dash, col, img, phase=0.0, width=0.008):
    """Dashed stitching following an edge (sd of the shape), inset inside it."""
    ring = np.abs(sd_edge + inset) - width
    coord = np.arctan2(y, x) * 40 if False else (x * 0.0 + (x + y * 0.7) * (1.0 / dash)) + phase
    dashes = (np.sin(coord * np.pi * 2) > -0.1)
    return over(img, C(col), smooth(ring) * dashes * 0.85)


# --- rope and cord ----------------------------------------------------------------------------

def rope_col(along, across, base, light, strands=3.0):
    """Twisted-rope shading: along = coordinate along the rope (radians-ish), across = -1..1 over its width."""
    tw = np.sin(along * strands * np.pi * 2 + across * 2.4)
    t = 0.5 + 0.5 * tw
    return mix(C(base), C(light), t)


def knot(img, cx, cy, r, base, light, seed=0):
    sd = circle(cx, cy, r)
    d, s, h = bevel(sd, r * 0.9, relief=1.1, shine=18)
    sh = blur(np.roll(np.roll(smooth(sd), 4, axis=1), 6, axis=0), 4)
    img = img * (1 - 0.5 * sh * (1 - smooth(sd)))[..., None]
    wob = nz(26, seed, px=x - cx, py=y - cy, octaves=2)
    col = mix(C(base), C(light), np.clip(d * 0.9 + (wob - 0.5) * 0.5, 0, 1)) + C("#fff4dc") * (s * 0.4)[..., None]
    return over(img, col, smooth(sd))


def tassel(img, cx, cy, ln, w, base, light, seed=0):
    """Hanging cord end: a neck, then a brush of strands."""
    neck = stadium(cx, cy + 0.04, 0.03, 0.07, py=y)  # vertical-ish bar below
    neck = box(cx, cy + 0.03, 0.028, 0.06)
    img = part(img, neck, (base, light, "#fff0d0"), 0.03, shadow=0.35)
    top = cy + 0.09
    bs = np.zeros_like(x)
    rng = np.random.default_rng(seed)
    for k in range(9):
        o = (k - 4) / 4.0
        l = ln * (0.85 + 0.3 * rng.random())
        sd = segment(cx + o * w * 0.25, top, cx + o * w, top + l) - 0.011
        col = mix(C(base), C(light), 0.35 + 0.5 * rng.random())
        img = over(img, col, smooth(sd))
    return img


def twist_ring(img, cx, cy, rx, ry, thick, base, light, strands=26.0, seed=0, back=None, shadow=0.5):
    """A rope ring (torus) seen in perspective; `back` = 'front' | 'back' | None to draw one half only."""
    e = ellipse(cx, cy, rx, ry)
    sd = np.abs(e) - thick
    if back == "front":
        sd = np.maximum(sd, -(y - cy))
    elif back == "back":
        sd = np.maximum(sd, y - cy)
    ang = np.arctan2((y - cy) / ry, (x - cx) / rx)
    across = np.clip(e / thick, -1, 1)
    m = smooth(sd)
    if shadow > 0:
        sh = blur(np.roll(np.roll(m, 5, axis=1), 7, axis=0), 5.0)
        img = img * (1 - shadow * sh * (1 - m))[..., None]
    d, s, h = bevel(sd, thick, relief=1.0, shine=14)
    rc = rope_col(ang / (2 * np.pi), across, base, light, strands / 3.0)
    col = rc * (0.35 + 0.95 * d[..., None]) + C("#fff4dc") * (s * 0.35)[..., None]
    return over(img, col, m)


# --- emblems (small painted devices for cloth and leather) ------------------------------------

def emblem(img, kind, cx, cy, s, col, dark="#1a0f08"):
    c = C(col)
    px, py = (x - cx) / s, (y - cy) / s
    if kind == "flame":
        sd = flame_sd(0, 0.45, 0.95, 0.38, 0.0, px, py) * s
        img = over(img, c, smooth(sd) * 0.95)
        sd2 = flame_sd(0, 0.5, 0.45, 0.17, 0.0, px, py) * s
        img = over(img, c * 0.4 + 0.55, smooth(sd2) * 0.8)
    elif kind == "bell":
        w = 0.1 + 0.7 * np.clip((py + 0.7) / 1.3, 0, 1) ** 1.5
        sd = np.maximum(np.abs(px) - w, np.maximum(-0.7 - py, py - 0.55)) * s
        img = over(img, c, smooth(sd) * 0.95)
        img = over(img, c, smooth(circle(0, 0.78, 0.13, px, py) * s))
        img = over(img, C(dark), smooth(np.abs(circle(0, -0.8, 0.12, px, py)) * s - 0.01 * s) * 0.9)
    elif kind == "tally":
        for i in range(4):
            sd = segment((i - 1.5) * 0.42, -0.7, (i - 1.5) * 0.42, 0.7, px, py) * s - 0.035
            img = over(img, c, smooth(sd) * 0.9)
        sd = segment(-0.95, 0.5, 0.95, -0.5, px, py) * s - 0.035
        img = over(img, c, smooth(sd) * 0.9)
    elif kind == "cross":
        for a, b, cc, dd in [(0, -0.9, 0, 0.9), (-0.6, -0.25, 0.6, -0.25)]:
            sd = segment(a, b, cc, dd, px, py) * s - 0.1 * s
            img = over(img, c, smooth(sd) * 0.9)
    elif kind == "eye":
        sd = (np.abs(py) - 0.55 * np.sqrt(np.clip(1 - px ** 2 / 1.0, 0, 1))) * s * 0.9
        img = over(img, c, smooth(sd) * 0.9)
        img = over(img, C(dark), smooth(circle(0, 0, 0.3, px, py) * s))
        img = over(img, c, smooth(circle(0.05, -0.05, 0.1, px, py) * s))
    elif kind == "dots":
        for i in range(5):
            img = over(img, c, smooth(circle(-0.8 + i * 0.4, 0.0, 0.1, px, py) * s) * 0.85)
    elif kind == "wave":
        ln = polyline([(-0.9 + i * 0.3, 0.25 * (-1) ** i) for i in range(7)], px, py) * s - 0.05 * s
        img = over(img, c, smooth(ln) * 0.85)
    elif kind == "star":
        for k in range(4):
            a = k * np.pi / 4
            sd = segment(-np.cos(a), -np.sin(a), np.cos(a), np.sin(a), px, py) * s - 0.06 * s
            img = over(img, c, smooth(sd) * 0.9)
    return img


# --- the four painters ------------------------------------------------------------------------

def _front(sd, cy):
    return np.maximum(sd, -(y - cy))


def _back(sd, cy):
    return np.maximum(sd, y - cy)


def focus(img, o):
    """A staff head: shaft below, a holder (cup / cradle / collar / cage / ring / horn / rope / crook), an orb."""
    seed = o.get("seed", 1)
    hm = o.get("mat", "bronze")
    sm = o.get("shaft", "wood")
    od, ol, oh = o.get("orb", ("#3a1aa8", "#a98bff", "#6a42f0"))
    ocx, ocy, r = 0.0, o.get("oy", -0.22), o.get("r", 0.28)
    holder = o.get("holder", "cradle")
    wx, wy = warp(0.008, 5, seed)
    shaft = segment(0.0, 0.98, 0.0, 0.32, wx, wy) - 0.062
    tex = grain(seed + 1, 30, (1.0, 0.1))
    if holder != "ring":
        img = part(img, shaft, sm, 0.06, tex=0.35, texmap=tex)
        for yy in (0.62, 0.82):
            img = part(img, box(0, yy, 0.075, 0.018, wx, wy), hm, 0.02, shadow=0.3)

    def orb():
        return orb_glass(img, ocx, ocy, r, od, ol, oh, o.get("halo", 0.6), 0.7, seed + 7, stars_=o.get("stars", False))

    if holder == "cup":
        img = orb()
        bowl = np.maximum(ellipse(0, 0.08, 0.44, 0.34, wx, wy), -(y - 0.0))
        img = part(img, bowl, hm, 0.1, tex=0.4, texmap=tex)
        img = part(img, np.abs(stadium(0, 0.0, 0.44, 0.05, wx, wy)) - 0.0 + (-0.0) if False else stadium(0, 0.0, 0.45, 0.05, wx, wy), hm, 0.05, shadow=0.2)
        img = part(img, box(0, 0.19, 0.4, 0.018, wx, wy), o.get("band", "iron"), 0.02, shadow=0.0)
        if o.get("coals"):
            img = add(img, C("#ff6a1a"), np.exp(-np.hypot((x) / 0.3, (y + 0.02) / 0.08) ** 2) * 0.5)
    elif holder == "cradle":
        back_p = [[(0, 0.3), (-0.34, 0.1), (-0.4, -0.2), (-0.3, -0.46)], [(0, 0.3), (0.34, 0.1), (0.4, -0.2), (0.3, -0.46)]]
        img = orb()
        for pts in back_p:
            pts = np.array(pts, dtype=float)
            ts = np.linspace(0, 1, 18)
            curve = []
            for t in ts:  # quadratic-ish through the 4 points (cubic bezier)
                p = ((1 - t) ** 3) * pts[0] + 3 * ((1 - t) ** 2) * t * pts[1] + 3 * (1 - t) * t * t * pts[2] + t ** 3 * pts[3]
                curve.append(tuple(p))
            img = part(img, polyline(curve, wx, wy) - 0.03, hm, 0.03, shadow=0.4)
        img = part(img, polyline([(0, 0.3), (0.0, 0.0), (0.0, -0.46)], wx, wy) - 0.026, hm, 0.03, shadow=0.3)
        img = part(img, ellipse(0, 0.3, 0.1, 0.07, wx, wy), hm, 0.06, shadow=0.3)
    elif holder in ("collar", "beads"):
        cy = 0.06
        rx, ry = o.get("rx", 0.46), 0.15
        img = twist_ring(img, 0, cy, rx, ry, 0.06, "#101014", "#101014", back="back", shadow=0.0) if False else img
        back_sd = np.abs(ellipse(0, cy, rx, ry, wx, wy)) - 0.055
        img = part(img, _back(back_sd, cy), hm, 0.055, shadow=0.0)
        img = orb()
        front_sd = np.abs(ellipse(0, cy, rx, ry, wx, wy)) - 0.055
        img = part(img, _front(front_sd, cy), hm, 0.055, shadow=0.45)
        if holder == "beads":
            for k in range(11):
                a = np.pi * (0.06 + 0.88 * k / 10)
                bx, by = rx * np.cos(a), cy + ry * np.sin(a)
                img = knot(img, bx, by, 0.062, hm and MAT[hm][0] if isinstance(hm, str) else "#3a2a18", MAT[hm][1] if isinstance(hm, str) else "#d8c8a0", seed + k)
    elif holder == "cage":
        img = orb()
        for k, a in enumerate((0.0, 0.5, 1.0, 1.5, 2.0, 2.5)):
            rxm = r * 1.18 * abs(np.cos(a + 0.25))
            sd = np.abs(ellipse(0, ocy, max(rxm, 0.02), r * 1.2, wx, wy)) - 0.016
            img = part(img, sd, hm, 0.02, shadow=0.25)
        img = part(img, np.abs(ellipse(0, ocy, r * 1.18, r * 0.22, wx, wy)) - 0.018, hm, 0.02, shadow=0.2)
        img = part(img, polyline([(0, 0.3), (-0.22, 0.12), (-0.26, ocy + 0.3)], wx, wy) - 0.02, hm, 0.02, shadow=0.2)
        img = part(img, polyline([(0, 0.3), (0.22, 0.12), (0.26, ocy + 0.3)], wx, wy) - 0.02, hm, 0.02, shadow=0.2)
        img = part(img, circle(0, ocy - r * 1.28, 0.05, wx, wy), hm, 0.05, shadow=0.2)
        img = part(img, ellipse(0, 0.3, 0.1, 0.07, wx, wy), hm, 0.06, shadow=0.3)
    elif holder == "ring":
        # a big ring held by the shaft, the orb floating in it; an optional hook
        cy = -0.12
        rr = 0.44
        img = part(img, segment(0, 0.98, 0, cy + rr, wx, wy) - 0.058, sm, 0.06, tex=0.35, texmap=tex)
        img = orb_glass(img, 0.0, cy, r * 0.85, od, ol, oh, o.get("halo", 0.5), 0.7, seed + 7)
        rsd = np.abs(circle(0, cy, rr, wx, wy)) - 0.052
        img = part(img, rsd, hm, 0.055, shadow=0.45)
        if o.get("hook"):
            hk = polyline([(0.0, cy + rr), (0.14, cy + rr + 0.12), (0.12, cy + rr + 0.26), (-0.02, cy + rr + 0.26)], wx, wy) - 0.028
            img = part(img, hk, hm, 0.03, shadow=0.3)
    elif holder == "horn":
        w = 0.07 + 0.38 * np.clip((0.3 - wy) / 0.55, 0, 1) ** 1.25
        horn = np.maximum(np.abs(wx) - w, np.maximum(wy - 0.3, -0.26 - wy))
        img = orb()
        img = part(img, horn, hm, 0.09, tex=0.2)
        img = part(img, stadium(0, -0.25, 0.4, 0.04, wx, wy), hm, 0.04, shadow=0.1)
        img = part(img, box(0, 0.2, 0.12, 0.014, wx, wy), "gilt", 0.02, shadow=0.0)
    elif holder == "rope":
        cy = 0.0
        img = twist_ring(img, 0, cy, 0.4, 0.13, 0.05, "#3a2a14", "#b89a68", back="back", shadow=0.0)
        img = orb()
        img = twist_ring(img, 0, cy, 0.4, 0.13, 0.05, "#3a2a14", "#b89a68", back="front")
        img = knot(img, 0.0, cy + 0.15, 0.07, "#3a2a14", "#b89a68", seed)
        img = knot(img, 0.0, 0.25, 0.06, "#3a2a14", "#b89a68", seed + 3)
    elif holder == "crook":
        pts = [(0.0, 0.32), (0.0, -0.1), (0.04, -0.46), (0.3, -0.6), (0.52, -0.42), (0.46, -0.16)]
        img = orb_glass(img, 0.22, -0.3, r * 0.8, od, ol, oh, o.get("halo", 0.5), 0.7, seed + 7)
        img = part(img, polyline(pts, wx, wy) - 0.045, hm, 0.05, shadow=0.4, tex=0.3, texmap=tex)
    elif holder == "splinter":
        pts = [(-0.28, 0.5), (-0.34, -0.1), (-0.16, -0.5), (-0.02, -0.82), (0.1, -0.44), (0.3, -0.18), (0.22, 0.52), (0.06, 0.38), (-0.08, 0.56)]
        poly = np.full_like(x, 1e9)
        # polygon sd by edge distances + winding (convex-ish): use even-odd fill
        inside = np.zeros_like(x, dtype=bool)
        n = len(pts)
        for i in range(n):
            x1, y1 = pts[i]
            x2, y2 = pts[(i + 1) % n]
            cond = ((y1 > wy) != (y2 > wy)) & (wx < (x2 - x1) * (wy - y1) / (y2 - y1 + 1e-9) + x1)
            inside ^= cond
            poly = np.minimum(poly, segment(x1, y1, x2, y2, wx, wy))
        sd = np.where(inside, -poly, poly)
        img = add(img, C("#ffe8b0"), np.exp(-np.maximum(sd, 0) / 0.1) * 0.35)
        img = part(img, sd, "pale", 0.12, tex=0.6, texmap=tex)
        # the keyhole of light and the door-line
        img = over(img, C("#fff0c0"), smooth(circle(0.0, -0.18, 0.06, wx, wy)))
        img = over(img, C("#fff0c0"), smooth(box(0.0, -0.06, 0.022, 0.1, wx, wy)))
        img = add(img, C("#ffe0a0"), np.exp(-np.hypot(x, y + 0.14) / 0.14) * 0.5)
        img = part(img, np.abs(segment(-0.32, 0.5, 0.2, 0.5, wx, wy)) - 0.0 - 0.012, "iron", 0.02, shadow=0.0)
    elif holder == "clapper":
        img = twist_ring(img, 0, -0.02, 0.1, 0.1, 0.03, "#2a2418", "#8a7a60", back=None, shadow=0.3) if False else img
        img = part(img, polyline([(0, 0.32), (0.0, -0.1)], wx, wy) - 0.0 - 0.03, "darkiron", 0.03)
        ball = circle(0, -0.22, 0.3, wx, wy)
        wool = nz(30, seed, octaves=3)
        img = part(img, ball, ("#5a5648", "#d8d2c0", "#ffffff"), 0.3, tex=0.45, texmap=wool, shadow=0.5, relief=1.1, shine=8)
        for k in range(6):  # the wrapping cords
            yy = -0.44 + k * 0.1
            img = over(img, C("#8c846c") * 0.8, smooth(np.abs(ellipse(0, yy, 0.3 * np.sqrt(max(1 - ((yy + 0.22) / 0.3) ** 2, 0.02)), 0.05, wx, wy)) - 0.008) * (np.abs(y + 0.22) < 0.28) * (y > yy - 0.01))
        img = add(img, C(oh), np.exp(-np.hypot(x, y + 0.2) / 0.1) * 0.15)
        img = part(img, circle(0, -0.54, 0.05, wx, wy), "iron", 0.05, shadow=0.2)
    if o.get("moss"):
        for k in range(6):
            mx = -0.36 + k * 0.14
            img = over(img, C("#4a6a2a") * (0.7 + 0.5 * nz(10, k))[..., None], smooth(ellipse(mx, 0.02 + 0.05 * (k % 2), 0.07, 0.05, wx, wy)) * 0.9)
    if o.get("runes"):
        img = add(img, C(oh), np.exp(-np.abs(ellipse(0, ocy, r * 1.4, r * 1.4)) / 0.02) * 0.25)
    return img


def vestment(img, o):
    """A stole, scapular, cloak, veil or apron hung flat: cloth folds, trim, fringe, a device."""
    seed = o.get("seed", 1)
    form = o.get("form", "stole")
    base, light = o.get("cloth", ("#3a3026", "#a08c6c"))
    trim = o.get("trim", "#d8b25a")
    wx, wy = warp(0.012, 4, seed)
    wx, wy = wx * 1.1, (wy - 0.04) * 1.1
    hem = 0.82
    notch = None
    if form == "stole":
        flare = 0.14 + 0.07 * np.clip((wy + 0.5) / 1.3, 0, 1)
        sway = 0.03 * np.sin(wy * 3 + seed)
        spread = 0.2 + 0.1 * np.clip((wy + 0.5) / 1.3, 0, 1)
        left = np.maximum(np.abs(wx + spread - sway) - flare, np.maximum(-0.5 - wy, wy - hem))
        right = np.maximum(np.abs(wx - spread - sway) - flare, np.maximum(-0.5 - wy, wy - hem))
        arc = np.abs(ellipse(0, -0.5, 0.26, 0.3, wx, wy)) - 0.15
        arc = np.maximum(arc, wy - -0.45)
        sd = np.minimum(np.minimum(left, right), arc)
        neck_hole = ellipse(0, -0.46, 0.1, 0.1, wx, wy) * 0
    elif form == "scapular":
        panel = np.maximum(np.abs(wx) - 0.37, np.maximum(-0.72 - wy, wy - hem))
        panel = np.maximum(panel, (wy + 0.4 * np.abs(wx)) - (hem + 0.14))
        notch = (wy + 0.38 + 1.9 * np.abs(wx)) * 0.47
        sd = np.maximum(panel, -notch)
    elif form in ("cloak", "veil"):
        tt = np.clip((wy + 0.7) / 1.55, 0, 1)
        wdt = 0.27 + (0.54 if form == "cloak" else 0.3) * tt ** 0.85
        scallop = 0.05 * np.sin(wx * 16 + seed) if form == "cloak" else 0.05 * np.sin(wx * 22) - 0.04 * np.abs(wx)
        body = np.maximum(np.abs(wx) - wdt, np.maximum(-0.6 - wy, wy - hem - scallop))
        sd = np.minimum(body, ellipse(0, -0.5, 0.36, 0.17, wx, wy))
    else:  # apron
        bib = np.maximum(np.abs(wx) - 0.2, np.maximum(-0.62 - wy, wy - 0.1))
        skirt = np.maximum(np.abs(wx) - 0.43 - 0.1 * np.clip((wy - 0.1), 0, 1), np.maximum(-0.1 - wy, wy - hem))
        sd = np.minimum(bib, skirt)
    mat_is_leather = form == "apron"
    # shadow
    m = smooth(sd)
    sh = blur(np.roll(np.roll(m, 5, axis=1), 8, axis=0), 6.0)
    img = img * (1 - 0.6 * sh * (1 - m))[..., None]
    d, s, h = bevel(sd, 0.1, relief=0.55, shine=10)
    folds = 0.5 + 0.5 * np.sin((wx * (14 if form != "stole" else 20)) + 2.2 * nz(3, seed + 5, octaves=2) + (0.8 * np.sin(wy * 2.2) if form != "apron" else 0))
    shade = (0.45 + 0.75 * folds) * (0.55 + 0.7 * d) * (0.8 + 0.4 * ss(-0.8, 0.8, -wx))
    weave = 0.93 + 0.07 * np.sin(P._X * 1.7) * np.sin(P._Y * 1.7)
    base_c, light_c = C(base), C(light)
    col = mix(base_c, light_c, np.clip(shade * 0.85 - 0.05, 0, 1)) * weave[..., None]
    if mat_is_leather:
        col = col * (0.75 + 0.7 * nz(40, seed, octaves=3))[..., None]
    col = col + C("#fff2d8") * (s * (0.12 if not mat_is_leather else 0.3))[..., None]
    img = over(img, col, m)
    inside = (m > 0.5)
    # hem band and edge stitching
    bandk = o.get("band", True)
    if bandk and form in ("stole", "scapular", "cloak", "veil", "apron"):
        hy = hem - 0.12 if form != "cloak" else hem - 0.1
        band = (wy > hy) & inside
        if form == "scapular":
            band = band & ((wy + 0.4 * np.abs(wx)) > (hem + 0.02))
        bcol = C(trim) * (0.55 + 0.55 * folds)[..., None] * (0.7 + 0.5 * d)[..., None]
        img = over(img, bcol, band * 0.92)
        img = over(img, C("#000000"), band * smooth(np.abs(wy - hy) - 0.006) * 0.0)
        stripe = (np.abs(wy - (hy + 0.06)) < 0.008) & inside
        img = over(img, C(base) * 0.4, stripe * 0.7)
    if o.get("frayed", True) and form in ("stole",):
        rng = np.random.default_rng(seed)
        for xc in (-0.3, 0.3):
            for k in range(11):
                ox = xc - 0.17 + k * 0.034
                ln = 0.08 + 0.05 * rng.random()
                sdf = segment(ox, hem - 0.01, ox + 0.01 * rng.uniform(-1, 1), hem + ln) - 0.0075
                img = over(img, C(trim) * (0.6 + 0.4 * rng.random()), smooth(sdf) * 0.95)
    if form == "scapular" or form == "apron":
        img = stitches(sd, 0.035, 0.05, light if form == "scapular" else "#c8a070", img, 0.0)
    # edge darkening lines (folds' dark creases)
    crease = np.exp(-(np.sin(wx * 14 + 2.2 * nz(3, seed + 5, octaves=2)) - -0.98) ** 2 / 0.01) * inside * 0.0
    # devices
    ev = o.get("emblem")
    if ev:
        ex = -0.0 if form != "stole" else 0.3
        ey = o.get("emblem_y", -0.05 if form != "stole" else 0.28)
        es = o.get("emblem_s", 0.17)
        img = emblem(img, ev, ex, ey, es, o.get("emblem_col", trim))
    if o.get("patches"):
        for (px_, py_, ang) in ((-0.15, 0.1, 0.0), (0.16, 0.42, 0.0)):
            pm = box(px_, py_, 0.1, 0.08, wx, wy)
            img = over(img, C(o["patches"]), smooth(pm) * 0.95 * inside)
            img = stitches(pm, 0.015, 0.035, "#e0d0a8", img, 0.3)
    if form == "scapular":
        # orphrey bands down the sides and round the neck
        for sgn in (-1, 1):
            img = over(img, C(trim) * (0.55 + 0.5 * folds)[..., None], smooth(np.abs(wx - sgn * 0.3) - 0.03) * inside * (wy > -0.62) * (wy < hem - 0.1) * 0.9)
        img = over(img, C(trim) * (0.6 + 0.4 * folds)[..., None], smooth(np.abs(notch - 0.03) - 0.016) * inside * 0.95)
        img = over(img, C("#000000"), smooth(notch + 0.0) * 0.0)
        img = over(img, C(base) * 0.3, smooth(-notch) * 0.0)
    if form in ("cloak", "veil"):
        # a rolled collar, the dark inside of the hood, and the opening of the front
        tt2 = np.clip((wy + 0.55) / 1.4, 0, 1)
        opening = (np.abs(wx) < (0.012 + 0.05 * tt2)) & (wy > -0.5) & inside
        lining = C(trim) * 0.5 * (0.6 + 0.5 * folds)[..., None]
        img = over(img, lining * (0.6 + 0.5 * tt2)[..., None] if False else lining, opening * 0.9)
        col_sd = ellipse(0, -0.56, 0.26, 0.085, wx, wy)
        img = part(img, col_sd, (C(base) * 0.6, C(light) * 0.85, C(light)) if False else (base, light, light), 0.08, shadow=0.35, relief=0.8, shine=8)
        img = over(img, C("#050405"), smooth(ellipse(0, -0.55, 0.16, 0.045, wx, wy)) * 0.85)
    if form == "cloak":
        for sgn in (-1, 1):
            img = part(img, circle(sgn * 0.16, -0.46, 0.04, wx, wy), o.get("clasp", "gilt"), 0.04, shadow=0.3)
        chain = [(-0.16 + 0.32 * t / 8.0, -0.44 + 0.07 * np.sin(np.pi * t / 8.0)) for t in range(9)]
        img = part(img, polyline(chain, wx, wy) - 0.011, o.get("clasp", "gilt"), 0.012, shadow=0.15)
        img = part(img, circle(0.0, -0.37, 0.06, wx, wy), o.get("clasp", "gilt"), 0.06, shadow=0.4)
        img = over(img, C("#3a1a10"), smooth(circle(0, -0.37, 0.02, wx, wy)))
    if form == "veil":
        img = part(img, stadium(0, -0.62, 0.17, 0.028, wx, wy), "gilt", 0.03, shadow=0.3)
        lace = (np.sin(wx * 38) * np.sin((wy - hem) * 38) > 0.2) & (wy > hem - 0.2) & inside
        img = over(img, C(light) * 1.1, lace * 0.55)
    if form == "apron":
        # neck straps and waist ties
        strap_l = polyline([(-0.17, -0.58), (-0.36, -0.82), (-0.0, -0.98)], wx, wy) - 0.025
        strap_r = polyline([(0.17, -0.58), (0.36, -0.82), (0.0, -0.98)], wx, wy) - 0.025
        for sdv in (strap_l, strap_r):
            img = part(img, sdv, "leather", 0.03, shadow=0.3)
        pocket = np.maximum(np.abs(wx) - 0.3, np.maximum(np.abs(wy - 0.5) - 0.17, 0))
        img = over(img, C("#000000"), smooth(np.abs(pocket) - 0.008) * 0.35)
        img = stitches(pocket, 0.02, 0.04, "#d0b078", img, 0.0)
        for rv in ((-0.12, -0.57), (0.12, -0.57)):
            img = part(img, circle(rv[0], rv[1], 0.03, wx, wy), "gilt", 0.03, shadow=0.1)
    if o.get("wrap"):  # winding-cloth bands, diagonal
        k = np.sin((wx * 0.8 + wy * 1.5) * 18 + nz(4, seed) * 3)
        img = over(img, C(base) * 0.35, np.clip(k - 0.7, 0, 1) * 1.6 * inside * 0.5)
    if o.get("roots"):
        for i, pts in enumerate([[(-0.5, -0.5), (-0.3, -0.1), (-0.4, 0.3), (-0.2, 0.7)], [(0.45, -0.55), (0.25, 0.0), (0.35, 0.4), (0.2, 0.8)], [(-0.3, -0.1), (0.1, 0.2), (0.2, 0.6)]]):
            rt = polyline(pts, wx, wy) - (0.022 - 0.004 * i)
            img = part(img, rt, "wood", 0.03, shadow=0.35, tex=0.3)
    if o.get("moss"):
        for k in range(14):
            rr = np.random.default_rng(seed + k)
            mx, my = rr.uniform(-0.5, 0.5), rr.uniform(-0.55, 0.7)
            mm = ellipse(mx, my, rr.uniform(0.05, 0.12), rr.uniform(0.03, 0.07), wx, wy)
            img = over(img, C("#46682a") * (0.6 + 0.6 * nz(20, k))[..., None], smooth(mm) * inside * 0.8)
    if o.get("pockets"):
        for k in range(4):
            px_ = -0.27 + k * 0.18
            pm = box(px_, 0.15 + 0.4 * (k % 2), 0.07, 0.07, wx, wy)
            img = over(img, C(base) * 0.55, smooth(pm) * inside * 0.9)
            img = stitches(pm, 0.012, 0.03, light, img, 0.1)
            img = add(img, C("#9aa0a8"), smooth(circle(px_, 0.15 + 0.4 * (k % 2) - 0.02, 0.02, wx, wy)) * 0.5 * inside)
    if o.get("glowhem"):
        gh = C(o["glowhem"])
        hy = hem - 0.02
        img = add(img, gh, np.exp(-np.abs(wy - hy) / 0.03) * inside * 0.6)
        img = add(img, gh, np.exp(-np.maximum(sd, 0) / 0.05) * (wy > hy - 0.15) * 0.3)
    if o.get("embers"):
        img = add(img, C("#ff8a2a"), sparks(20, seed + 40, (-0.5, -0.3, 0.5, 0.8), (0.004, 0.009)) * inside * 0.9)
    if o.get("salt"):
        img = add(img, C("#e8f0f0"), (nz(120, seed + 9, octaves=1) > 0.82) * inside * 0.35)
    return img


def lantern(img, o):
    """A lamp-glass: glass vessel with a lit flame, metal caps and a ring, tinted by the piece."""
    seed = o.get("seed", 1)
    form = o.get("form", "cylinder")
    metal = o.get("metal", "iron")
    fire_c = o.get("fire", "warm")
    gl = C(o.get("glass", "#ffb454"))
    wx, wy = warp(0.006, 6, seed)
    top, bot = -0.5, 0.52
    if form == "horn":
        w = 0.14 + 0.2 * np.clip((wy - top) / (bot - top), 0, 1) ** 1.1
        glass = np.maximum(np.abs(wx) - w, np.maximum(top - wy, wy - bot))
    elif form == "bulb":
        glass = ellipse(0, 0.02, 0.34, 0.42, wx, wy)
        top, bot = -0.38, 0.4
    elif form == "gothic":
        w = 0.27
        arch = np.maximum(np.abs(wx) - w, wy - bot)
        glass = np.maximum(arch, top + 0.3 * np.clip(np.abs(wx) / w, 0, 1) ** 1.7 - wy)
    elif form == "censer":
        glass = circle(0, 0.06, 0.4, wx, wy)
        top, bot = -0.34, 0.46
    elif form == "coin":
        w = 0.32
        glass = np.maximum(np.abs(wx) - w, np.maximum(top + 0.12 - wy, wy - bot))
    else:  # cylinder
        w = 0.25 + 0.04 * np.sin((wy - top) / (bot - top) * np.pi)
        glass = np.maximum(np.abs(wx) - w, np.maximum(top - wy, wy - bot))
    gm = smooth(glass)
    # warm light behind and around
    fire_col = {"warm": "#ffb040", "teal": "#58e8d4", "pale": "#fff2d0", "red": "#ff5a2a", "ember": "#ff8a2a",
                "violet": "#b890ff", "none": "#5a4a6a", "bone": "#ffe8b8"}.get(fire_c, fire_c)
    fc = C(fire_col)
    img = add(img, fc, np.exp(-np.maximum(glass, 0) / 0.16) * (0.35 if fire_c != "none" else 0.1))
    # inside: gradient glass, flame, glow
    gf = np.exp(-np.hypot(wx * 1.1, (wy - 0.16) * 0.8) / 0.3)
    inner = C("#07060a") + gl * (0.1 + 0.85 * gf ** 1.3)[..., None]
    if fire_c == "none":
        inner = mix(C("#0a0810"), C("#40365a"), np.clip(np.exp(-np.hypot(wx, wy) / 0.4), 0, 1))
    img = over(img, inner, gm)
    if fire_c != "none":
        fl = Image_fire(img, 0.0, 0.3, 0.46, 0.11, seed, fire_c)
        img = over(img, fl, gm)
        glow = np.exp(-np.hypot(wx / 1.0, (wy - 0.12) / 1.4) / 0.2)
        img = add(img, fc, (glow * 0.6 * gm))
    else:
        # an unlit lamp: a face watching from inside
        eyes = [smooth(ellipse(ex, 0.0, 0.05, 0.033, wx, wy)) for ex in (-0.09, 0.09)]
        for e in eyes:
            img = over(img, C("#d8ccff"), e * gm)
        img = add(img, C("#9a8aff"), np.exp(-np.hypot(wx, wy) / 0.1) * 0.2 * gm)
    if o.get("crack"):
        k = polyline([(0.05, -0.4), (-0.04, -0.2), (0.08, 0.0), (-0.02, 0.2), (0.06, 0.4)], wx, wy)
        img = add(img, C("#ff9a40"), np.exp(-k / 0.012) * gm * 0.9)
        img = over(img, C("#ffe0a0"), smooth(k - 0.005) * gm)
    if o.get("brine"):
        img = over(img, C("#e8f0ee"), smooth(wy - 0.3 + 0.03 * np.sin(wx * 20)) * gm * 0.6)
        img = add(img, C("#f4faf8"), (nz(90, seed, octaves=1) > 0.78) * gm * 0.35)
    if form == "horn":
        ridge = 0.5 + 0.5 * np.sin((wy - top) * 42 + nz(4, seed) * 3)
        img = over(img, C("#1a1008"), gm * ridge * 0.22)
    if o.get("smoke"):
        sm = nz(5, seed + 4, px=wx * 1.2, py=wy * 0.8)
        img = over(img, C("#1c1814"), gm * np.clip(sm * 1.3 - 0.15, 0, 0.75))
    if o.get("coin_slot"):
        pass
    # lead bands / frame
    if o.get("leaded"):
        for xx in (-0.14, 0.14):
            img = part(img, box(xx, 0.0, 0.012, 0.52, wx, wy) + 0.0, metal, 0.015, shadow=0.0, relief=0.5)
        for yy in (-0.22, 0.1):
            img = over(img, mcol(metal)[0] * 1.3, smooth(np.abs(wy - yy) - 0.011) * gm * 0.9)
    if form == "gothic":
        for xx in (-0.0,):
            img = over(img, mcol(metal)[1] * 0.6, smooth(np.abs(wx) - 0.012) * gm * (wy > top + 0.12))
        img = over(img, mcol(metal)[1] * 0.5, smooth(np.abs(wy - 0.0) - 0.011) * gm)
    if form == "censer":
        holes = np.zeros_like(x)
        for yy in np.linspace(-0.2, 0.34, 5):
            for xx in np.linspace(-0.3, 0.3, 6):
                holes = np.maximum(holes, smooth(circle(xx + (0.05 if int((yy + 0.4) * 10) % 2 else 0), yy, 0.032, wx, wy)))
        img = over(img, mcol(metal)[1] * (0.5 + 0.8 * bevel(glass, 0.3)[0])[..., None] if False else mix(mcol(metal)[0], mcol(metal)[1], bevel(glass, 0.35, relief=1.1)[0]), gm)
        img = over(img, fc * 1.1 + 0.15, holes * gm)
        img = add(img, fc, np.exp(-np.maximum(glass, 0) / 0.1) * 0.15)
        img = add(img, C("#ffffff"), bevel(glass, 0.35)[1] * gm * 0.6)
        img = over(img, mcol(metal)[0], smooth(np.abs(glass + 0.02) - 0.008) * 0.8)
        img = part(img, np.abs(ellipse(0, 0.06, 0.4, 0.08, wx, wy)) - 0.016, metal, 0.02, shadow=0.0)
    else:
        # glass highlight and rim
        hl = np.exp(-(((wx + 0.12) - 0.0) / 0.035) ** 2 * 1.0) * ss(top, top + 0.15, wy) * ss(bot, bot - 0.15, wy)
        img = add(img, C("#ffffff"), hl * gm * 0.28)
        img = add(img, C("#fff4e0"), np.exp(-np.abs(glass + 0.01) / 0.012) * gm * 0.35 * ss(0.2, -0.3, wx))
        img = over(img, C("#050405"), smooth(np.abs(glass + 0.012) - 0.01) * 0.0)
    # caps
    capw = {"horn": 0.2, "bulb": 0.17, "gothic": 0.3, "censer": 0.12, "coin": 0.36, "cylinder": 0.3}[form]
    img = part(img, stadium(0, bot + 0.04 if form != "bulb" else 0.46, capw * 1.1 + 0.05, 0.075, wx, wy), metal, 0.075, shadow=0.45, tex=0.2)
    ct = top - 0.02 if form not in ("bulb", "censer") else (top - 0.04)
    if form == "gothic":
        ct = top - 0.06
    roof = np.maximum(np.abs(wx) - (0.06 + (wy - (ct - 0.15)) / 0.15 * (capw + 0.05 - 0.06)), np.maximum(ct - 0.15 - wy, wy - ct))
    img = part(img, roof, metal, 0.07, shadow=0.45)
    img = part(img, box(0, ct + 0.02, capw + 0.04, 0.03, wx, wy), metal, 0.04, shadow=0.2)
    ring = np.abs(circle(0, ct - 0.2, 0.1, wx, wy)) - 0.02
    img = part(img, ring, metal, 0.025, shadow=0.4)
    if form == "coin":
        img = part(img, box(0, ct - 0.04, 0.09, 0.016, wx, wy), "darkiron", 0.02, shadow=0.0)
        cn = circle(0.0, ct + 0.12, 0.1, wx, wy)
        img = part(img, cn, "gilt", 0.09, shadow=0.3)
        img = over(img, C("#6a4410"), smooth(np.abs(circle(0, ct + 0.12, 0.065, wx, wy)) - 0.008) * 0.7)
    if o.get("chain"):
        for k in range(5):
            img = part(img, np.abs(ellipse(0, ct - 0.34 - k * 0.1, 0.035, 0.05, wx, wy)) - 0.012, metal, 0.015, shadow=0.2)
    if o.get("briar"):
        pts = [(-0.3, 0.55), (-0.2, 0.2), (-0.3, -0.1), (-0.14, -0.4), (-0.22, -0.55)]
        img = part(img, polyline(pts, wx, wy) - 0.02, "wood", 0.02, shadow=0.35)
        for (tx, ty) in ((-0.22, 0.3), (-0.32, 0.0), (-0.2, -0.25)):
            img = part(img, segment(tx, ty, tx - 0.07, ty - 0.05, wx, wy) - 0.011, "wood", 0.01, shadow=0.0)
        pts = [(0.3, 0.55), (0.18, 0.15), (0.3, -0.2)]
        img = part(img, polyline(pts, wx, wy) - 0.018, "wood", 0.02, shadow=0.35)
        for k in range(5):
            img = over(img, C("#4a6a2a") * (0.7 + 0.5 * nz(8, k))[..., None], smooth(ellipse(-0.22 - 0.03 * (k % 2), 0.4 - k * 0.2, 0.05, 0.028, wx, wy)) * 0.9)
    if o.get("bone"):
        for k in range(7):
            ang = np.pi * (0.1 + 0.8 * k / 6)
            img = part(img, circle(0.0 + 0.3 * np.cos(ang), bot + 0.12 + 0.0 * np.sin(ang) + 0.02, 0.0, wx, wy) - 0.0, "bone", 0.0, shadow=0.0) if False else img
    if o.get("bellshape"):
        pass
    return img


def Image_fire(img, cx, cy, h, w, seed, kind):
    """The painted flame (colour only), as a full image for compositing within the glass."""
    base = np.zeros_like(img)
    cool = kind in ("teal",)
    f = fire(base, cx, cy, h, w, seed, 0.0, 1.0, cool=cool)
    if kind == "red":
        f = fire(base, cx, cy, h, w, seed, 0.0, 1.0)
        f = f[..., [0, 1, 2]] * np.array([1.0, 0.6, 0.55])
    elif kind in ("pale", "violet", "bone"):
        f = fire(base, cx, cy, h, w, seed, 0.0, 1.0)
        tint = {"pale": (1.0, 1.0, 0.92), "violet": (0.62, 0.5, 1.0), "bone": (1.0, 0.92, 0.74)}[kind]
        f = (f * 0.4 + 0.6 * f.mean(axis=2, keepdims=True)) * np.array(tint) * 1.3
    return f


from motifs import fire, flame_sd  # noqa: E402


def girdle(img, o):
    """A belt, cord, chain, bead-string, wrap or plumb-line, laid as a loop or a diagonal strap."""
    seed = o.get("seed", 1)
    form = o.get("form", "belt")
    wx, wy = warp(0.007, 5, seed)
    base = o.get("base", "#3a2a14")
    light = o.get("light", "#b89a68")
    if form in ("belt", "hasp", "harness"):
        ang = -0.38
        u, v = rot(0, 0.0, ang, wx, wy)
        v = v + 0.05 * np.sin(u * 2.6 + 0.6)
        wide = o.get("wide", 0.15)
        strap = np.maximum(np.abs(v) - wide, np.maximum(-0.96 - u, u - 0.92))
        # pointed tail
        strap = np.maximum(strap, (np.abs(v) * 1.3 + u) - 1.1)
        tex = nz(55, seed + 3, px=u * 1.0, py=v * 4.0, octaves=3)
        m = smooth(strap)
        sh = blur(np.roll(np.roll(m, 6, axis=1), 8, axis=0), 6.0)
        img = img * (1 - 0.6 * sh * (1 - m))[..., None]
        d, s, h = bevel(strap, wide * 0.7, relief=0.7, shine=14)
        lm = o.get("leather", "leather")
        dk, lt, sp = mcol(lm)
        if o.get("cloth"):
            dk, lt = C(o["cloth"][0]), C(o["cloth"][1])
            sp = lt
        col = mix(dk, lt, np.clip(d * 0.9 + 0.1 * ss(wide * 0.4, -wide, v), 0, 1)) * (0.8 + 0.5 * tex)[..., None] + sp * (s * 0.35)[..., None]
        img = over(img, col, m)
        img = over(img, C("#000000"), smooth(np.abs(np.abs(v) - wide + 0.004) - 0.004) * m * 0.3)
        # stitches
        dash = np.sin(u * 55) > -0.1
        for sgn in (-1, 1):
            st = np.abs(v - sgn * (wide - 0.035)) - 0.006
            img = over(img, C(o.get("stitch", "#e0c898")), smooth(st) * dash * m * 0.8)
        # holes toward the tail
        for k in range(4):
            hu = 0.28 + k * 0.17
            hs = circle(hu, 0.0, 0.017, u, v)
            img = over(img, C("#050302"), smooth(hs))
        # studs
        if o.get("studs"):
            for k in range(7):
                hu = -0.65 + k * 0.2
                if abs(hu + 0.12) < 0.2:
                    continue
                img = part(img, circle(hu, 0.0, 0.032, u, v), o.get("stud", "bronze"), 0.032, shadow=0.2)
        # buckle: a frame with a prong
        bm = o.get("buckle", "iron")
        if form == "hasp":
            plate = box(-0.2, 0.0, 0.2, wide + 0.05, u, v)
            img = part(img, plate, bm, 0.08, shadow=0.5, tex=0.2)
            for pxx in (-0.34, -0.06):
                for pyy in (-0.07, 0.07):
                    img = part(img, circle(pxx, pyy, 0.022, u, v), "darkiron", 0.02, shadow=0.0)
            img = part(img, box(-0.2, 0.0, 0.03, 0.2, u, v), "darkiron", 0.03, shadow=0.0)
            stp = np.abs(box(0.12, 0.0, 0.07, 0.1, u, v)) - 0.017
            img = part(img, stp, bm, 0.02, shadow=0.3)
            img = part(img, segment(0.0, 0.0, 0.17, 0.0, u, v) - 0.02, "gilt", 0.025, shadow=0.2)
            img = part(img, stadium(0.17, 0.0, 0.05, 0.016, u, v), "gilt", 0.02, shadow=0.0)
        else:
            frame = np.abs(box(-0.2, 0.0, 0.14, wide + 0.06, u, v)) - 0.032
            img = part(img, frame, bm, 0.04, shadow=0.5, tex=0.15)
            img = part(img, segment(-0.2, 0.0, 0.1, 0.0, u, v) - 0.03, bm, 0.035, shadow=0.3)
            if form == "harness":
                f2 = np.abs(box(0.5, 0.0, 0.11, wide + 0.06, u, v)) - 0.03
                img = part(img, f2, bm, 0.04, shadow=0.5)
                img = part(img, segment(0.5, 0.0, 0.72, 0.0, u, v) - 0.028, bm, 0.035, shadow=0.3)
        if o.get("bell"):
            bw = 0.06 + 0.2 * np.clip((wy - 0.12) / 0.32, 0, 1) ** 1.4
            bsd = np.maximum(np.abs(wx - 0.3) - bw, np.maximum(0.12 - wy, wy - 0.46))
            img = part(img, polyline([(0.3, 0.05), (0.3, 0.14)], wx, wy) - 0.02, "darkiron", 0.02, shadow=0.0)
            img = part(img, bsd, "bronze", 0.14, shadow=0.5)
            img = part(img, stadium(0.3, 0.46, 0.27, 0.02, wx, wy), "bronze", 0.03, shadow=0.1)
            img = part(img, circle(0.3, 0.52, 0.045, wx, wy), "darkiron", 0.04, shadow=0.0)
        if o.get("emptyring"):
            img = part(img, np.abs(circle(0.55, 0.0, 0.11, u, v)) - 0.026, "bronze", 0.03, shadow=0.4)
    elif form == "cord":
        cx, cy = 0.0, -0.08
        thick = o.get("thick", 0.055)
        rx, ry = o.get("rx", 0.62), o.get("ry", 0.5)
        img = twist_ring(img, cx, cy, rx, ry, thick, base, light, strands=o.get("strands", 36), seed=seed, shadow=0.5)
        if o.get("coil"):
            img = twist_ring(img, cx, cy, rx - 0.15, ry - 0.14, thick * 0.9, base, light, strands=o.get("strands", 36), seed=seed, shadow=0.35)
        n = o.get("knots", 3)
        kc = o.get("knotc", (base, light))
        for k in range(n):
            a = np.pi * 0.5 + (k + (0.5 if n % 2 == 0 else 0.0)) * (2 * np.pi / max(n, 1)) if n > 1 else np.pi * 0.5
            a = np.pi / 2 + k * (2 * np.pi / n)
            kx, ky = cx + rx * np.cos(a), cy + ry * np.sin(a)
            img = knot(img, kx, ky, o.get("kr", 0.075), kc[0], kc[1], seed + k)
            if o.get("glowknots"):
                img = add(img, C(o["glowknots"]), np.exp(-np.hypot(x - kx, y - ky) / 0.07) * 0.6)
        # hanging ends from the bottom knot
        bx, by = cx, cy + ry
        for sgn in (-1, 1):
            pts = [(bx, by), (bx + sgn * 0.06, by + 0.14), (bx + sgn * 0.13, by + 0.26)]
            img = part(img, polyline(pts, wx, wy) - thick * 0.62, (base, light, "#fff0d0"), 0.04, shadow=0.4)
            img = tassel(img, bx + sgn * 0.13, by + 0.25, 0.1, 0.12, base, light, seed + int(sgn + 3))
        if o.get("bell"):
            bwid = 0.05 + 0.15 * np.clip((wy - (by + 0.26)) / 0.26, 0, 1) ** 1.4
            img = part(img, np.maximum(np.abs(wx - bx) - bwid, np.maximum((by + 0.2) - wy, wy - (by + 0.5))) if False else np.maximum(np.abs(wx - bx) - bwid, np.maximum(by + 0.22 - wy, wy - by - 0.46)), "bronze", 0.1, shadow=0.5)
        if o.get("tally"):
            pass
    elif form == "sash":
        xs = np.linspace(-0.72, 0.72, 70)
        amp = o.get("amp", 0.2)
        ys = 0.3 - 0.5 * (xs + 0.72) / 1.44 + amp * np.sin((xs + 0.72) / 1.44 * 2 * np.pi * 0.9 + seed * 0.7)
        yp = np.interp(wx, xs, ys)
        sl = np.interp(wx, xs, np.gradient(ys, xs))
        off = (wy - yp) / np.sqrt(1 + sl * sl)
        thick = o.get("thick", 0.072)
        sd = np.maximum(np.abs(off) - thick, np.maximum(-0.72 - wx, wx - 0.72))
        m = smooth(sd)
        sh = blur(np.roll(np.roll(m, 5, axis=1), 8, axis=0), 6.0)
        img = img * (1 - 0.55 * sh * (1 - m))[..., None]
        d, sp_, h_ = bevel(sd, thick, relief=1.0, shine=14)
        rc = rope_col(wx, np.clip(off / thick, -1, 1), base, light, o.get("strands", 14))
        col = rc * (0.35 + 0.95 * d[..., None]) + C("#fff4dc") * (sp_ * 0.35)[..., None]
        img = over(img, col, m)
        n = o.get("knots", 3)
        kc = o.get("knotc", (base, light))
        kxs = np.linspace(-0.45, 0.45, n) if n > 1 else [0.0]
        for k, kx in enumerate(kxs):
            ky = float(np.interp(kx, xs, ys))
            img = knot(img, kx, ky, o.get("kr", 0.07), kc[0], kc[1], seed + k)
            if o.get("glowknots"):
                img = add(img, C(o["glowknots"]), np.exp(-np.hypot(x - kx, y - ky) / 0.07) * 0.6)
        for sgn, ex in ((-1, xs[0]), (1, xs[-1])):
            ey = float(np.interp(ex, xs, ys))
            img = knot(img, ex, ey, 0.08, kc[0], kc[1], seed + 20)
            if o.get("bell") and sgn == 1:
                bwid = 0.05 + 0.17 * np.clip((wy - (ey + 0.1)) / 0.24, 0, 1) ** 1.4
                bsd = np.maximum(np.abs(wx - ex) - bwid, np.maximum(ey + 0.1 - wy, wy - ey - 0.34))
                img = part(img, bsd, "bronze", 0.12, shadow=0.5)
                img = part(img, stadium(ex, ey + 0.34, 0.22, 0.018, wx, wy), "bronze", 0.03, shadow=0.1)
                img = part(img, circle(ex, ey + 0.39, 0.04, wx, wy), "darkiron", 0.04, shadow=0.0)
            else:
                img = tassel(img, ex, ey + 0.02, 0.16, 0.12, base, light, seed + int(sgn + 3))
    elif form == "chain":
        cx, cy, rx, ry = 0.0, -0.05, 0.6, 0.48
        n = o.get("links", 18)
        cm = o.get("metal", "iron")
        for k in range(n):
            a = np.pi / 2 + k * 2 * np.pi / n
            lx, ly = cx + rx * np.cos(a), cy + ry * np.sin(a)
            tang = a + np.pi / 2
            uu, vv = rot(lx, ly, tang, wx, wy)
            if k % 2 == 0:
                ls = np.abs(stadium(0, 0, 0.115, 0.058, uu, vv)) - 0.022
            else:
                ls = np.abs(ellipse(0, 0, 0.1, 0.034, uu, vv)) - 0.022
            img = part(img, ls, cm, 0.026, shadow=0.35, relief=1.0)
        if o.get("hang"):
            for k in range(3):
                img = part(img, np.abs(stadium(0.0, cy + ry + 0.15 + k * 0.1, 0.05, 0.035, wx, wy)) - 0.016, cm, 0.02, shadow=0.3)
    elif form == "beads":
        cx, cy, rx, ry = 0.0, -0.05, 0.6, 0.48
        n = o.get("links", 16)
        img = twist_ring(img, cx, cy, rx, ry, 0.012, "#1c140c", "#3a2a18", strands=12, shadow=0.2)
        for k in range(n):
            a = np.pi / 2 + k * 2 * np.pi / n
            bx, by = cx + rx * np.cos(a), cy + ry * np.sin(a)
            r = 0.075 + 0.02 * ((k % 3) == 0)
            bd = circle(bx, by, r, wx, wy)
            d, s, h = bevel(bd, r, relief=1.3, shine=30)
            sh = blur(np.roll(np.roll(smooth(bd), 4, axis=1), 5, axis=0), 3.0)
            img = img * (1 - 0.5 * sh * (1 - smooth(bd)))[..., None]
            dk, lt, sp = mcol(o.get("bead", "bone"))
            col = mix(dk, lt, d) + sp * (s * 0.85)[..., None]
            col = col * (0.8 + 0.4 * nz(30, seed + k))[..., None]
            img = over(img, col, smooth(bd))
        for sgn in (-1, 1):
            img = part(img, polyline([(0.0, cy + ry), (sgn * 0.07, cy + ry + 0.16), (sgn * 0.1, cy + ry + 0.3)], wx, wy) - 0.014, "leather", 0.02, shadow=0.3)
            img = knot(img, sgn * 0.1, cy + ry + 0.31, 0.045, "#d8c8a0" if False else "#4a4132", "#dfd5ba", seed + int(sgn + 3))
    elif form == "plumb":
        cx, cy, rx, ry = 0.0, -0.3, 0.55, 0.36
        img = twist_ring(img, cx, cy, rx, ry, 0.05, base, light, strands=32, seed=seed)
        img = knot(img, cx, cy + ry, 0.075, base, light, seed)
        img = part(img, segment(cx, cy + ry, cx, 0.5, wx, wy) - 0.016, ("#2a2414", "#9a8a5a", "#fff0c0"), 0.02, shadow=0.3)
        # the plumb-bob: a cone, mossy
        bob = np.maximum(np.abs(wx - cx) - 0.14 * np.clip((0.82 - wy) / 0.3, 0, 1) ** 0.7, np.maximum(0.5 - wy, wy - 0.82))
        img = part(img, bob, "bronze", 0.11, shadow=0.5)
        img = over(img, C("#4a6a2a") * (0.6 + 0.6 * nz(14, seed, octaves=2))[..., None], smooth(bob) * np.clip(nz(8, seed + 3) * 1.8 - 0.55, 0, 1) * 0.9)
    elif form == "wraps":
        # rope wound round and round: stacked slanted bands
        for k in range(7):
            t = k / 6.0
            cx, cy = -0.28 + 0.56 * t, -0.5 + 0.9 * t
            img = twist_ring(img, cx, cy, 0.3, 0.17, 0.065, base, light, strands=14, seed=seed + k, shadow=0.35)
        img = part(img, polyline([(0.28, 0.4), (0.38, 0.6), (0.45, 0.8)], wx, wy) - 0.03, (base, light, "#fff0d0"), 0.035, shadow=0.35)
        img = tassel(img, 0.45, 0.8, 0.1, 0.1, base, light, seed)
    return img
