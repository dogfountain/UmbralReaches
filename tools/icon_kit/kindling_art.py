"""Kindling icons repainted as illustrations of a thing (category "kindling"): a tally stick, a wax seal ..."""
import numpy as np

from motifs import *  # noqa: F401,F403
from registry import recipe


def K(name):
    return recipe("kindling", name)


def _rp(pts, ang, cx=0.0, cy=0.0):
    c, s = np.cos(ang), np.sin(ang)
    return [(cx + (px - cx) * c - (py - cy) * s, cy + (px - cx) * s + (py - cy) * c) for px, py in pts]


@K("quick")
def quick():
    img = scene("#080604", "#1a0d06", 230, "#503010", 0.5, (0.2, -0.1), "#d08a20", 0.8)
    for i, yy in enumerate((-0.2, 0.2, 0.55)):
        img = add(img, C("#ffc060"), smooth(segment(-0.95, yy, -0.5 + i * 0.1, yy) - 0.014) * 0.5)
    boot = poly([(-0.2, -0.46), (0.18, -0.46), (0.18, 0.0), (0.34, 0.12), (0.58, 0.28), (0.6, 0.52), (-0.28, 0.52), (-0.3, 0.2)]) - 0.03
    img = obj(img, boot, "#3a1c08", "#c07a38", "#ffe0a0", 0.14, halo="#ffa030", halo_amt=0.35, texture=0.3, seed=231)
    img = over(img, C("#1a0c04"), smooth(box(0.16, 0.5, 0.45, 0.055) - 0.0) * smooth(boot + 0.04) * 0.9)
    img = over(img, C("#e8c060"), smooth(box(-0.02, -0.46, 0.2, 0.04)) * smooth(boot + 0.01) * 0.9)
    for ang, ln in ((np.pi + 0.95, 0.5), (np.pi + 0.62, 0.62), (np.pi + 0.3, 0.64)):    # the wing: three feathers fanned from the ankle
        pts = _rp([(-0.26, -0.22 - 0.07), (-0.26 + ln * 0.9, -0.3 - 0.08), (-0.26 + ln, -0.3), (-0.26 + ln * 0.9, -0.3 + 0.08), (-0.26, -0.22 + 0.07)], ang, -0.26, -0.22)
        img = obj(img, poly(pts), "#a0782c", "#fff4d0", "#ffffff", 0.07, halo="#ffd070", halo_amt=0.3, outline=0.025)
    return finish(img, 23, grade=(1.05, 0.97, 0.9))


@K("tally")
def tally():
    img = scene("#070707", "#141210", 260, "#a06020", 0.4, (0, 0), "#a06020", 0.8)
    a = -0.78
    u, v = rot(0, 0, a)
    stick = np.maximum(np.abs(v) - 0.13, np.abs(u) - 0.86)
    stick = np.maximum(stick, 0) * 1.0 + np.minimum(stick, 0)
    img = obj(img, stick - 0.02, "#2a1a0a", "#b8884a", "#ffe8b0", 0.12, halo="#ff8a2a", halo_amt=0.25, texture=0.5, seed=261)
    grain = (nz(80, 262, px=u * 0.4, py=v * 6.0) - 0.5) * 0.35
    img = add(img, C("#2a1808"), np.clip(grain, 0, 1) * smooth(stick) * 0.5)
    for k in range(9):                                       # notches, in fives: four cuts and a slash
        gx = -0.6 + k * 0.14
        slash = k == 4
        cut = np.abs(u - gx) - 0.022
        if slash:
            cut = np.abs((u - gx) * 0.8 + v * 0.6) - 0.022
        m = smooth(cut) * (np.abs(v) < 0.125)
        img = over(img, C("#1a0804"), m * 0.95)
        img = add(img, C("#ff8a2a"), m * 0.5 * np.exp(-np.abs(v) / 0.1))
    knot = np.abs(circle(*_rp([(0.82, 0.0)], a)[0], 0.09)) - 0.03
    img = obj(img, knot, "#5a3a14", "#e0b060", "#fff0b0", 0.03, outline=0.02)
    cord = polyline([_rp([(0.9, 0.0)], a)[0], (0.78, -0.62), (0.4, -0.78)]) - 0.025
    img = obj(img, cord, "#4a2a10", "#c89050", "#ffe0a0", 0.03, outline=0.02)
    img = add(img, C("#ffd070"), sparks(14, 263, (-0.7, -0.7, 0.7, 0.7), (0.003, 0.008)) * 0.7)
    return finish(img, 26, grade=(1.04, 0.98, 0.92))


@K("heart")
def heart():
    img = scene("#0a0406", "#1c0a0c", 270, "#ff4a30", 0.5, (0, 0.05), "#d0301a", 0.75)
    lobes = smin(circle(-0.27, -0.16, 0.34), circle(0.27, -0.16, 0.34), 0.05)
    tip = poly([(-0.58, -0.02), (0.58, -0.02), (0.0, 0.74)]) - 0.06
    h = smin(lobes, tip, 0.14)
    img = add(img, C("#ff3a10"), np.exp(-np.maximum(h, 0) / 0.12) * 0.8)
    img = obj(img, h, "#1a0a08", "#6a2a20", "#ffb090", 0.28, outline=0.035, shine=10)
    cr = cracks(271, 4.2, 0.05) * smooth(h + 0.03)
    heat = (0.4 + 0.6 * ss(-0.5, 0.5, -(y + 0.1))) * cr
    img = add(img, C("#ff4a0c"), heat * 0.9)
    img = add(img, C("#ffd070"), heat * heat * 0.6)
    img = add(img, C("#ff5a20"), np.exp(-np.hypot(x, y + 0.05) / 0.35) * 0.35 * smooth(h))
    img = add(img, C("#ffb050"), sparks(24, 272, (-0.5, -0.9, 0.5, 0.0), (0.003, 0.008)) * 0.9)
    return finish(img, 27, grade=(1.06, 0.96, 0.9))


@K("sigil")
def sigil():
    img = scene("#05070c", "#0a1018", 280, "#3a70d0", 0.4, (0, 0), "#3a70d0", 0.8)
    for sx, rot_ in ((-0.2, 0.18), (0.2, -0.18)):             # ribbon tails
        rb = poly(_rp([(sx - 0.1, 0.3), (sx + 0.1, 0.3), (sx + 0.1, 0.9), (sx, 0.78), (sx - 0.1, 0.9)], rot_, sx, 0.3))
        img = obj(img, rb, "#4a1a1a", "#c04a3a", "#ffc0a0", 0.08, outline=0.025)
    px, py = warp(0.045, 4.0, 281)
    wax = circle(0, -0.05, 0.56, px, py)
    img = add(img, C("#4a80ff"), np.exp(-np.maximum(wax, 0) / 0.1) * 0.6)
    img = obj(img, wax, "#0e1a4a", "#4a78d8", "#d8e8ff", 0.2, outline=0.035)
    ring = np.abs(circle(0, -0.05, 0.4)) - 0.03
    d, sp, h = bevel(ring, 0.03)
    img = over(img, mix(C("#0a1440"), C("#6a98f0"), d) + C("#ffffff") * sp[..., None] * 0.4, smooth(ring))
    star = None
    for k in range(5):
        a0 = -np.pi / 2 + k * 2 * np.pi * 2 / 5
        a1 = -np.pi / 2 + (k + 1) * 2 * np.pi * 2 / 5
        seg = segment(0.36 * np.cos(a0), -0.05 + 0.36 * np.sin(a0), 0.36 * np.cos(a1), -0.05 + 0.36 * np.sin(a1)) - 0.022
        star = seg if star is None else np.minimum(star, seg)
    d, sp, h = bevel(star, 0.025)
    img = over(img, mix(C("#0a1440"), C("#a8c8ff"), d) + C("#ffffff") * sp[..., None] * 0.4, smooth(star))
    img = add(img, C("#8ab0ff"), sparks(10, 282, (-0.6, -0.6, 0.6, 0.5), (0.003, 0.007)) * 0.6)
    return finish(img, 28, grade=(0.97, 1.0, 1.06))


@K("rime")
def rime():
    img = scene("#04080e", "#0a1620", 395, "#1c4a68", 0.5, (0, 0.2), "#4ac0ff", 0.8)
    px, py = warp(0.05, 3.0, 396)
    stone = ellipse(0.0, 0.3, 0.74, 0.42, px, py)
    img = obj(img, stone, "#10202c", "#58788c", "#d8f0ff", 0.3, halo="#4ac0ff", halo_amt=0.4, texture=0.4, seed=397)
    frost = (nz(26, 398) > 0.52) * smooth(stone + 0.02)
    img = add(img, C("#e8f8ff"), frost * ss(0.3, -0.1, y) * 0.7)
    for ox, h_, w_, ang in ((-0.35, 0.5, 0.11, -0.3), (0.0, 0.78, 0.14, 0.0), (0.36, 0.55, 0.11, 0.3)):
        base = (ox, 0.28)
        sd = poly(_rp([(ox - w_, 0.28), (ox - w_, 0.28 - h_ * 0.7), (ox, 0.28 - h_), (ox + w_, 0.28 - h_ * 0.7), (ox + w_, 0.28)], ang, base[0], base[1]))
        img = obj(img, sd, "#1a5a88", "#d0f0ff", "#ffffff", 0.1, halo="#6ad0ff", halo_amt=0.5, outline=0.03)
    img = add(img, C("#e8f8ff"), sparks(24, 399, (-0.7, -0.8, 0.7, 0.3), (0.004, 0.011)))
    return finish(img, 29, grade=(0.95, 1.02, 1.07))
