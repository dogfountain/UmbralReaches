"""Control prompts (category "key"): the painted caps the HUD sets a key's name on (ui/key_cap.gd). A cap of dark slate
in a bronze skirt, lit from the top left like every mark in the kit; the mouse with the button that is meant lit in
lantern gold; a pad's thumbstick and face button. RGBA with a dark outline, stored at 128 px so a cap stays crisp at
the 34-44 px the prompts draw it. The cap is plain across its middle: ui/key_cap.gd stretches it sideways for long
names (Shift, Space, Ctrl) by its two ends and a stretched middle."""
import numpy as np

from marks import INK
from motifs import *  # noqa: F401,F403
from registry import recipe


def K(name):
    return recipe("key", name)


SLATE_TOP = "#2a2622"
SLATE_FOOT = "#14110e"
BRONZE_D = "#3a2410"
BRONZE_L = "#c8954e"
LANTERN = "#ffb347"


def _rbox(cx, cy, hx, hy, r):
    return box(cx, cy, hx - r, hy - r) - r


def _finish(img, sd):
    """Outline, a breath of grain, and the alpha from the shape."""
    img = np.clip(img + (nz(300, 9, octaves=1) - 0.5)[..., None] * 0.02, 0, 1)
    return np.dstack([img, smooth(sd - 0.035)])


@K("cap")
def cap():
    outer = _rbox(0.0, 0.02, 0.84, 0.8, 0.24)
    img = np.zeros((N, N, 3)) + C(INK)
    # the skirt: bronze, bevelled, darker at the foot (the cap stands on the board)
    d, sp, _ = bevel(outer, 0.2, relief=0.8)
    skirt = mix(C(BRONZE_D), C(BRONZE_L), d * 0.85) + C("#fff0c8") * sp[..., None] * 0.45
    skirt = skirt * (1.0 - 0.35 * ss(-0.2, 0.9, y))[..., None]
    img = over(img, C(INK), smooth(outer))
    img = over(img, skirt, smooth(outer + 0.035))
    # the face: a slab of slate, dished a little, worn lighter at the top edge
    face = _rbox(0.0, -0.05, 0.66, 0.6, 0.17)
    img = over(img, C("#0a0705"), smooth(face - 0.03) * 0.9)
    fd, fsp, fh = bevel(face, 0.12, relief=0.5)
    slate = mix(C(SLATE_FOOT), C(SLATE_TOP), ss(0.6, -0.65, y))
    slate = slate * (0.9 + 0.2 * nz(22, 4401, octaves=3))[..., None]
    slate = slate + C("#6a5a46") * (fd * (1.0 - fh) * 0.5)[..., None] + C("#ffe0b0") * fsp[..., None] * 0.12
    img = over(img, slate, smooth(face))
    # a faint lantern glow pooled in the dish, so the name set on it reads warm
    img = add(img, C(LANTERN), smooth(face) * np.exp(-((x / 0.7) ** 2 + ((y + 0.05) / 0.5) ** 2)) * 0.06)
    return _finish(img, outer)


def _mouse(lit):
    body = ellipse(0.0, 0.04, 0.56, 0.84)
    img = np.zeros((N, N, 3)) + C(INK)
    d, sp, h = bevel(body, 0.3, relief=0.7)
    shell = mix(C("#14110e"), C("#4a4038"), d) + C("#ffe8c8") * sp[..., None] * 0.35
    shell = shell * (0.92 + 0.14 * nz(20, 4411, octaves=3))[..., None]
    img = over(img, C(INK), smooth(body))
    img = over(img, shell, smooth(body + 0.04))
    # the bronze band round the waist and the parting between the buttons
    band = np.abs(ellipse(0.0, 0.04, 0.56, 0.84)) - 0.02
    img = over(img, C(BRONZE_L) * 0.8, smooth(band + 0.01) * 0.0)
    split = np.maximum(segment(0.0, -0.8, 0.0, -0.06) - 0.022, body + 0.02)
    waist = np.maximum(np.abs(y + 0.06) - 0.022, body + 0.02)
    img = over(img, C("#050302"), smooth(np.minimum(split, waist)) * 0.95)
    # the button meant: lantern gold, glowing a little past its edge
    top = np.maximum(body + 0.05, y + 0.08)
    if lit in ("l", "r"):
        side = top if lit == "l" else top
        side = np.maximum(side, x - 0.0 + 0.03) if lit == "l" else np.maximum(side, -x + 0.03)
        img = add(img, C(LANTERN), np.exp(-np.maximum(side, 0) / 0.08) * 0.35)
        gd, gsp, _ = bevel(side, 0.12, relief=0.6)
        gold = mix(C("#8a4a10"), C("#ffc870"), gd) + C("#ffffff") * gsp[..., None] * 0.5
        img = over(img, gold, smooth(side))
    # the wheel
    wheel = _rbox(0.0, -0.44, 0.085, 0.17, 0.07)
    if lit == "m":
        img = add(img, C(LANTERN), np.exp(-np.maximum(wheel, 0) / 0.07) * 0.5)
    img = over(img, C("#050302"), smooth(wheel - 0.035))
    wd, wsp, _ = bevel(wheel, 0.06, relief=0.6)
    wc = mix(C("#8a4a10"), C("#ffc870"), wd) if lit == "m" else mix(C("#2a241e"), C("#7a6a58"), wd)
    for k in range(4):                                               # the wheel's treads
        wc = wc * (1.0 - 0.35 * smooth(np.abs(y + 0.56 - k * 0.08) - 0.012))[..., None]
    img = over(img, wc + C("#ffffff") * wsp[..., None] * 0.3, smooth(wheel))
    return _finish(img, body)


@K("mouse")
def mouse():
    return _mouse("")


@K("mouse_l")
def mouse_l():
    return _mouse("l")


@K("mouse_r")
def mouse_r():
    return _mouse("r")


@K("mouse_m")
def mouse_m():
    return _mouse("m")


@K("stick")
def stick():
    """A pad's thumbstick seen from above: a dished top in a bronze collar (the HUD sets L or R on it)."""
    ring = circle(0.0, 0.0, 0.84)
    img = np.zeros((N, N, 3)) + C(INK)
    d, sp, _ = bevel(ring, 0.22, relief=0.8)
    collar = mix(C(BRONZE_D), C(BRONZE_L), d * 0.85) + C("#fff0c8") * sp[..., None] * 0.4
    img = over(img, C(INK), smooth(ring))
    img = over(img, collar, smooth(ring + 0.035))
    top = circle(0.0, 0.0, 0.6)
    img = over(img, C("#0a0705"), smooth(top - 0.03))
    td, tsp, th = bevel(top, 0.3, relief=0.5, light=(0.55, 0.65))      # dished: lit from the opposite side
    slate = mix(C(SLATE_FOOT), C(SLATE_TOP), td) * (0.9 + 0.2 * nz(22, 4421, octaves=3))[..., None]
    img = over(img, slate, smooth(top))
    for k in range(10):                                               # the grip ridges round the dish
        a = k * np.pi / 5.0
        img = over(img, C("#3a3028"), smooth(segment(0.48 * np.cos(a), 0.48 * np.sin(a), 0.56 * np.cos(a), 0.56 * np.sin(a)) - 0.018) * 0.7)
    return _finish(img, ring)


@K("button")
def button():
    """A pad's round face button (the HUD sets A, B, X or Y on it)."""
    ring = circle(0.0, 0.0, 0.84)
    img = np.zeros((N, N, 3)) + C(INK)
    d, sp, _ = bevel(ring, 0.18, relief=0.8)
    rim = mix(C(BRONZE_D), C(BRONZE_L), d * 0.85) + C("#fff0c8") * sp[..., None] * 0.4
    img = over(img, C(INK), smooth(ring))
    img = over(img, rim, smooth(ring + 0.035))
    top = circle(0.0, -0.03, 0.64)
    img = over(img, C("#0a0705"), smooth(top - 0.03))
    td, tsp, _ = bevel(top, 0.4, relief=0.8)
    slate = mix(C(SLATE_FOOT), C("#3a332c"), td) + C("#ffe8c8") * tsp[..., None] * 0.3
    img = over(img, slate * (0.92 + 0.16 * nz(22, 4431, octaves=3))[..., None], smooth(top))
    return _finish(img, ring)
