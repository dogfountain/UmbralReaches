"""Village goods: the Keg's mugs and rumour, lamp oil, the well rope, roof slates, reed thatch.
Category "village", id = the shop glyph name."""
import numpy as np

from objects import *  # noqa: F401,F403
from registry import recipe
from items_relics import G


def V(name):
    return recipe("village", name)


@V("mug")
def mug():
    img = G("#09070a", "#170f0a", 1000, "#d08a30", (0, 0.1), 0.9, "#3a2412")
    img = floor_shadow(img, 0, 0.74, 0.55, 0.07, 0.55)
    img = tankard(img, -0.04, 0.12, 1.3, 1001, True, "#ffa040")
    img = steam(img, -0.04, -0.4, -0.9, 1002, 0.18, "#ffe8c8", 2, 0.12)
    # foam running over the rim
    drip = box(-0.2, -0.26, 0.04, 0.12)
    img = piece(img, drip, "#c8a860", "#fff2d0", "#ffffff", 0.04, shadowed=False)
    return finish(img, 100, exposure=1.4, grade=(1.06, 0.97, 0.9))


@V("mugs")
def mugs():
    img = G("#09070a", "#170f0a", 1010, "#d08a30", (0, 0.0), 0.95, "#3a2412")
    img = floor_shadow(img, 0, 0.7, 0.85, 0.07, 0.55)
    img = tankard(img, -0.36, 0.2, 1.0, 1011, True, "#ffa040")
    img = tankard(img, 0.36, 0.14, 1.0, 1012, True, "#ffa040")
    img = add(img, C("#ffe0a0"), sparks(34, 1013, (-0.2, -0.7, 0.2, -0.1), (0.003, 0.007)) * 0.9)
    img = add(img, C("#fff0c0"), np.exp(-np.hypot(x, y + 0.2) / 0.08) * 0.35)
    return finish(img, 101, exposure=1.4, grade=(1.06, 0.97, 0.9))


@V("ear")
def ear():
    img = G("#09070a", "#150e0c", 1020, "#c08060", (0.2, 0.0), 0.85, "#3a2418")
    # the side of a head leaning in, hair above, the ear turned to the room
    head = circle(-0.95, 0.15, 0.95)
    img = piece(img, head, "#4a2216", "#c88c6c", "#ffe8d8", 0.5, tex=0.85 + 0.3 * nz(30, 1021), shine=10.0, shadowed=False)
    hair = np.maximum(head, -(y + 0.1 - 0.15 * np.sin(x * 9)))
    img = over(img, C("#1a0f0a") * (0.7 + 0.6 * grain(y, x, 1022, 6, 60, 0.6))[..., None], smooth(hair) * smooth(head))
    wx, wy = warp(0.01, 6, 1023)
    outer = poly([(-0.2, -0.56), (0.12, -0.6), (0.34, -0.42), (0.38, -0.1), (0.3, 0.22), (0.22, 0.48), (0.08, 0.66), (-0.1, 0.62), (-0.16, 0.5), (-0.2, 0.3)], wx, wy)
    outer = blur(outer, 9.0) - 0.02
    img = piece(img, outer, "#5a2a1a", "#f0b090", "#fff0e0", 0.22, tex=0.9 + 0.2 * nz(40, 1024), shine=14.0, relief=0.9)
    # the helix: a bright rolled rim round the right, the bowl and canal inside, the lobe below
    rim = curve(lambda t: (0.04 + 0.24 * np.sin(t * 3.0 - 0.1) * 1.0, -0.08 + 0.5 * -np.cos(t * 3.0 - 0.1) * 1.0 + 0.1), 40)
    rim = [(0.02 + 0.27 * np.sin(a_), 0.04 - 0.5 * np.cos(a_)) for a_ in np.linspace(-0.5, 2.5, 40)]
    d = path_t(rim, wx, wy)[0]
    img = over(img, C("#ffd8b8"), smooth(d - 0.032) * smooth(outer + 0.02) * 0.6)
    img = over(img, C("#7a3a28"), smooth(np.abs(d - 0.06) - 0.012) * smooth(outer + 0.02) * 0.5)
    anti = [(0.0 + 0.1 * np.sin(a_), 0.02 - 0.22 * np.cos(a_)) for a_ in np.linspace(-1.2, 2.2, 30)]
    da = path_t(anti, wx, wy)[0]
    img = over(img, C("#e8a888"), smooth(da - 0.02) * smooth(outer + 0.02) * 0.6)
    img = over(img, C("#b06a50"), smooth(ellipse(-0.04, 0.12, 0.1, 0.16, wx, wy)) * smooth(outer) * 0.5)
    img = over(img, C("#2a0e08"), smooth(ellipse(-0.06, 0.1, 0.045, 0.08)) * 0.85)
    img = add(img, C("#fff0e0"), np.exp(-(np.hypot(x - 0.18, y + 0.4) / 0.07) ** 2) * smooth(outer) * 0.35)
    for i, (wy_, ln) in enumerate([(-0.4, 0.5), (-0.05, 0.62), (0.3, 0.46)]):
        w = curve(lambda t, wy_=wy_, ln=ln: (0.9 - ln * t, wy_ + 0.06 * np.sin(t * 9 + i)), 30)
        d = path_t(w)[0]
        img = add(img, C("#ffd8b0"), np.exp(-(d / 0.012) ** 2) * 0.55 * (x > 0.42))
    return finish(img, 102, exposure=1.4, grade=(1.05, 0.98, 0.95))


@V("oil")
def oil():
    img = G("#09070a", "#17100a", 1030, "#e0902a", (0, 0.1), 0.9, "#3a2610")
    img = floor_shadow(img, 0, 0.72, 0.5, 0.07, 0.55)
    body = np.minimum(circle(0, 0.26, 0.48), box(0, -0.32, 0.17, 0.34))
    wx, wy = warp(0.01, 7, 1031)
    body = np.minimum(circle(0, 0.26, 0.48, wx, wy), box(0, -0.32, 0.17, 0.34, wx, wy))
    lvl = 0.0
    oilc = mix(C("#8a4a08"), C("#f0b030"), ss(0.7, -0.2, y) * 0.8)
    img = over(img, oilc, smooth(body) * smooth(y - 0.0))
    img = add(img, C("#ffc040"), np.exp(-(np.hypot(x, y - 0.3) / 0.35) ** 2) * smooth(body) * 0.3)
    img = glass(img, body, "#e0a030", "#fff0b0", amt=0.12, hi=1.4)
    cork = poly([(-0.14, -0.78), (0.14, -0.78), (0.18, -0.62), (-0.18, -0.62)])
    img = piece(img, cork, "#3a2410", "#c89a5a", "#ffe8c0", 0.1, tex=0.8 + 0.5 * nz(60, 1032))
    # a wick end dipped in, hung over the lip, the way Fennick's lamps are fed
    img = piece(img, polyline([(0.0, -0.7), (0.3, -0.62), (0.4, -0.45)]) - 0.016, "#2a1c0e", "#a07a4a", "#ffffff", 0.016, shadowed=False)
    img = add(img, C("#ffd070"), sparks(12, 1033, (-0.5, -0.5, 0.5, 0.6), (0.003, 0.006)) * 0.5)
    return finish(img, 103, exposure=1.4, grade=(1.06, 0.98, 0.9))


@V("rope")
def rope():
    img = G("#09080a", "#16120d", 1040, "#a08a62", (0, 0.05), 0.9, "#2c261c")
    img = floor_shadow(img, 0, 0.62, 0.78, 0.1, 0.5)
    # a heavy coil seen slightly from above, the free end trailing off the bottom right
    ph = np.arctan2((y - 0.04) / 0.62, x)
    coil = None
    sp = curve(lambda t: (np.cos(t * 6.2832 * 2.6) * (0.74 - 0.5 * t) * 1.0, 0.04 + np.sin(t * 6.2832 * 2.6) * (0.74 - 0.5 * t) * 0.62), 280)
    tail = curve(lambda t: (0.0 + 0.7 * t, 0.04 + 0.62 * 0.24 + 0.5 * t * 0.3 + 0.3 * t), 14)
    tail = [(sp[-1][0] + 0.6 * t, sp[-1][1] + 0.4 * t + 0.1 * np.sin(t * 5)) for t in np.linspace(0, 1, 14)]
    for pts, w in ((sp, 0.085), (tail, 0.085)):
        d, tt, side = path_t(pts)
        sd = d - w
        tw = 0.55 + 0.45 * np.sin(tt * 60.0 + side / w * 2.2)
        edge = 1 - 0.5 * np.clip(np.abs(side) / w, 0, 1) ** 2
        img = piece(img, sd, "#241810", "#b89a62", "#f4e4b4", w, tex=tw * edge * (0.85 + 0.3 * nz(60, 1041)), shine=6.0, relief=0.5)
    return finish(img, 104, exposure=1.4, grade=(1.04, 0.99, 0.93))


@V("slates")
def slates():
    img = G("#07080b", "#101318", 1050, "#6a7a98", (0, 0.1), 0.9, "#222a3a")
    img = floor_shadow(img, 0, 0.7, 0.85, 0.08, 0.55)
    # a stack of dressed roof slates, each a little offset, edges split and pale
    for k in range(5):
        oy = 0.48 - k * 0.2
        ox = (k % 2) * 0.08 - 0.04 + 0.02 * k
        slab = poly(rotated_poly([(-0.72 + ox, oy - 0.06), (0.62 + ox, oy - 0.1), (0.7 + ox, oy + 0.08), (-0.64 + ox, oy + 0.14)], ox, oy, 0.02 * (k - 2)))
        tone = 0.75 + 0.35 * nz(30, 1051 + k, octaves=3) + 0.06 * k
        edge = box(ox, oy + 0.12, 0.66, 0.025)
        img = piece(img, slab, "#10141c", "#6a7a94" if k % 2 else "#5a6a84", "#d8e4ff", 0.1, tex=tone, shine=14.0)
        cleave = np.exp(-(np.abs(np.sin(x * 9 + k) * 0.03 + (y - oy)) / 0.01) ** 2) * smooth(slab) * 0.12
        img = add(img, C("#aab8d0"), cleave)
        img = over(img, C("#a8b4c8"), smooth(np.abs(slab + 0.01) - 0.008) * 0.25 * smooth(slab))
    # a drilled nail hole and an iron nail on top
    img = piece(img, circle(-0.5, -0.4, 0.024), "#050507", "#0a0a0e", "#000000", 0.02, shadowed=False)
    nail = stadium(0, 0, 0.14, 0.014, *rot(0.4, -0.5, 0.4))
    img = piece(img, nail, "#0a0a0c", "#6a6460", "#f0f0f0", 0.014)
    img = piece(img, circle(0.5, -0.57, 0.03), "#0a0a0c", "#6a6460", "#f0f0f0", 0.03, shadowed=False)
    return finish(img, 105, exposure=1.4, grade=(0.98, 1.0, 1.05))


@V("thatch")
def thatch():
    img = G("#09080a", "#16130d", 1060, "#d8b050", (0, 0.0), 0.9, "#3a3018")
    img = floor_shadow(img, 0, 0.8, 0.5, 0.07, 0.5)
    # a sheaf of reed, tied near the middle, the cut butts flared at the foot
    rng = np.random.default_rng(1061)
    for i in range(40):
        t = (i / 39.0) * 2 - 1
        top = (t * 0.55 + rng.uniform(-0.05, 0.05), -0.82 + rng.uniform(-0.05, 0.08))
        mid = (t * 0.12, 0.0)
        bot = (t * 0.42 + rng.uniform(-0.03, 0.03), 0.74 + rng.uniform(-0.03, 0.03))
        reed = polyline([top, mid, bot])
        col = ["#8a6a24", "#c8a448", "#e8c868", "#a88838"][i % 4]
        sd = reed - 0.016
        img = piece(img, sd, "#2a2008", col, "#fff0b0", 0.016, shadowed=(i % 6 == 0), shine=30.0, relief=0.6)
    for ty in (-0.04, 0.12):
        band = box(0, ty, 0.2, 0.035)
        img = piece(img, band, "#241608", "#8a6a3a", "#e0c898", 0.035, tex=0.7 + 0.5 * nz(80, 1062))
    img = add(img, C("#f4d890"), sparks(18, 1063, (-0.7, -0.8, 0.7, 0.4), (0.003, 0.006)) * 0.4)
    return finish(img, 106, exposure=1.4, grade=(1.05, 0.99, 0.9))
