"""More lamp-glass silhouettes for the gear icons: a porthole lens, a slit-window box, a bell-shaped glass,
a slender taper. Same look as gear_parts.lantern (lit from upper left, flame behind glass, metal fittings)."""
import numpy as np

from paint import *  # noqa: F401,F403
from gear_parts import part, mcol, Image_fire, C, stitches  # noqa: F401
from motifs import fire  # noqa: F401

FIRE = {"warm": "#ffb040", "teal": "#58e8d4", "pale": "#fff2d0", "red": "#ff5a2a", "ember": "#ff8a2a",
        "violet": "#b890ff", "bone": "#ffe8b8"}


def _fill(img, glass, o, wx, wy, fy, fh, fw):
    """Glass interior: dark tint, glow, the flame; returns the new image and the glass mask."""
    gm = smooth(glass)
    gl = C(o.get("glass", "#ffb454"))
    fc = C(FIRE.get(o.get("fire", "warm"), "#ffb040"))
    img = add(img, fc, np.exp(-np.maximum(glass, 0) / 0.16) * 0.35)
    gf = np.exp(-np.hypot(wx * 1.1, (wy - fy) * 0.8) / 0.3)
    img = over(img, C("#07060a") + gl * (0.1 + 0.85 * gf ** 1.3)[..., None], gm)
    f = Image_fire(img, 0.0, fy + fh * 0.6, fh, fw, o.get("seed", 1), o.get("fire", "warm"))
    img = over(img, f, gm)
    img = add(img, fc, np.exp(-np.hypot(wx, (wy - fy + 0.1) * 1.3) / 0.2) * 0.5 * gm)
    img = add(img, C("#ffffff"), np.exp(-((wx + 0.12) / 0.03) ** 2) * gm * 0.22)
    img = add(img, C("#fff4e0"), np.exp(-np.abs(glass + 0.01) / 0.012) * gm * 0.3 * ss(0.2, -0.3, wx))
    return img, gm


def lantern2(img, o):
    form = o["form"]
    metal = o.get("metal", "iron")
    seed = o.get("seed", 1)
    wx, wy = warp(0.006, 6, seed)
    if form == "porthole":
        cy = 0.04
        glass = circle(0, cy, 0.31, wx, wy)
        img, gm = _fill(img, glass, o, wx, wy, cy + 0.12, 0.42, 0.1)
        ring = np.abs(circle(0, cy, 0.37, wx, wy)) - 0.065
        img = part(img, ring, metal, 0.07, shadow=0.5, tex=0.2)
        for k in range(8):
            a = k * np.pi / 4 + 0.2
            img = part(img, circle(0.37 * np.cos(a), cy + 0.37 * np.sin(a), 0.026, wx, wy), "darkiron", 0.026, shadow=0.1)
        img = part(img, np.maximum(np.abs(wx) - 0.2, np.maximum(0.38 - wy, wy - 0.56)), metal, 0.08, shadow=0.45)
        img = part(img, np.abs(circle(0, -0.5, 0.09, wx, wy)) - 0.02, metal, 0.025, shadow=0.35)
        img = part(img, box(0, -0.38, 0.05, 0.05, wx, wy), metal, 0.05, shadow=0.2)
        if o.get("chain"):
            for k in range(3):
                img = part(img, np.abs(stadium(0, -0.64 - k * 0.1, 0.035, 0.05, wx, wy)) - 0.012, metal, 0.015, shadow=0.2)
    elif form == "slit":
        cy = 0.06
        body = box(0, cy, 0.36, 0.42, wx, wy)
        spill = np.exp(-np.abs(wx) / 0.35) * ss(0.0, 0.5, wy) * ss(0.95, 0.4, wy)
        fc = C(FIRE.get(o.get("fire", "warm"), "#ffb040"))
        img = add(img, fc, np.exp(-np.hypot(wx / 1.0, (wy - 0.2) / 0.5) / 0.3) * 0.18 + spill * 0.12)
        img = part(img, body, metal, 0.09, shadow=0.55, tex=0.25)
        sl = box(0, 0.0, 0.25, 0.038, wx, wy)
        img = add(img, fc, np.exp(-np.maximum(sl, 0) / 0.05) * 0.8)
        img = over(img, C("#fff4d0"), smooth(sl))
        for sg in (-1, 1):
            img = part(img, circle(sg * 0.27, -0.28, 0.025, wx, wy), "darkiron", 0.025, shadow=0.0)
            img = part(img, circle(sg * 0.27, 0.34, 0.025, wx, wy), "darkiron", 0.025, shadow=0.0)
        img = part(img, box(0, 0.22, 0.2, 0.02, wx, wy), "darkiron", 0.02, shadow=0.0)    # a hatch plate
        img = part(img, np.abs(circle(0, -0.5, 0.1, wx, wy)) - 0.022, metal, 0.025, shadow=0.35)
        # light thrown across the floor
        img = add(img, fc, np.exp(-((wy - 0.62) / 0.05) ** 2) * np.exp(-(wx / 0.5) ** 2) * 0.35)
    elif form == "bellglass":
        top, bot = -0.42, 0.46
        t = np.clip((wy - top) / (bot - top), 0, 1)
        w = 0.1 + 0.3 * t ** 1.7 + 0.04 * np.sin(t * 9)
        glass = np.maximum(np.abs(wx) - w, np.maximum(top - wy, wy - bot))
        img, gm = _fill(img, glass, o, wx, wy, 0.3, 0.46, 0.1)
        for yy in (0.3, 0.38):
            img = over(img, mcol(metal)[1] * 0.8, smooth(np.abs(wy - yy) - 0.01) * gm * 0.8)
        img = part(img, stadium(0, bot + 0.03, 0.42, 0.04, wx, wy), metal, 0.05, shadow=0.45)
        img = part(img, circle(0.0, bot + 0.09, 0.045, wx, wy), "darkiron", 0.045, shadow=0.2)
        img = part(img, np.maximum(np.abs(wx) - 0.08, np.maximum(top - 0.12 - wy, wy - top + 0.02)), metal, 0.06, shadow=0.4)
        img = part(img, np.abs(circle(0, top - 0.2, 0.1, wx, wy)) - 0.022, metal, 0.025, shadow=0.35)
    else:  # taper
        glass = np.maximum(np.abs(wx) - 0.13 + 0.02 * np.cos(wy * 5), np.maximum(-0.46 - wy, wy - 0.46))
        img, gm = _fill(img, glass, o, wx, wy, 0.1, 0.5, 0.06)
        img = part(img, stadium(0, 0.5, 0.2, 0.06, wx, wy), metal, 0.06, shadow=0.45)
        img = part(img, box(0, 0.64, 0.07, 0.1, wx, wy), metal, 0.06, shadow=0.35)
        img = part(img, stadium(0, 0.74, 0.24, 0.035, wx, wy), metal, 0.04, shadow=0.35)
        img = part(img, np.maximum(np.abs(wx) - 0.07 - (wy + 0.7) * 0.5, np.maximum(-0.66 - wy, wy + 0.46)), metal, 0.06, shadow=0.4)
        img = part(img, np.abs(circle(0, -0.78, 0.07, wx, wy)) - 0.018, metal, 0.02, shadow=0.35)
    return img
