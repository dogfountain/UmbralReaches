"""Item icons, set 3: staff cores, the anchor-stone and the elite bounties not yet in the ItemDB."""
import numpy as np

from objects import *  # noqa: F401,F403
from registry import recipe
from items_relics import G, I


def collar(img, seed, cy=0.5):
    """The brass collar every staff core sits in, claws curling up round the stone."""
    base = poly([(-0.3, cy + 0.2), (-0.34, cy + 0.02), (0.34, cy + 0.02), (0.3, cy + 0.2)])
    img = piece(img, base, "#2a1a0a", "#b88838", "#ffe0a0", 0.1, tex=rough(seed, 18))
    for sx in (-1, 1):
        claw = curve(lambda t, s=sx: (s * (0.3 + 0.12 * np.sin(t * 2.4)), cy + 0.02 - 0.5 * t), 14)
        d, tt, side = path_t(claw)
        img = piece(img, d - 0.035 * (1 - 0.5 * np.clip(tt / 0.5, 0, 1)), "#2a1a0a", "#c89a48", "#fff0c0", 0.04, shadowed=False)
    return img


@I("core_prism")
def core_prism():
    img = G("#050a0d", "#0a1519", 700, "#4ab8d0", (0, -0.1), 0.85, "#16343c")
    img = floor_shadow(img, 0, 0.78, 0.5, 0.06, 0.5)
    img = bloom_light(img, 0, -0.1, 0.5, "#8aeaff", 0.5)
    top = (0.0, -0.74)
    pts_outer = [(0.0, -0.74), (0.34, -0.36), (0.34, 0.22), (0.0, 0.46), (-0.34, 0.22), (-0.34, -0.36)]
    facets = [([(0.0, -0.74), (0.34, -0.36), (0.0, -0.12), (-0.34, -0.36)], "#8aeaff", "#e8ffff"),
              ([(-0.34, -0.36), (0.0, -0.12), (0.0, 0.46), (-0.34, 0.22)], "#2a8aa8", "#7ad8f0"),
              ([(0.34, -0.36), (0.34, 0.22), (0.0, 0.46), (0.0, -0.12)], "#1a6a88", "#5ac0e0")]
    img = shadow(img, poly(pts_outer))
    for pts, dark, light in facets:
        sd = poly(pts)
        a = np.linspace(0, 1, 1)
        g = ss(-0.74, 0.46, y)[..., None]
        col = mix(C(light), C(dark), g[..., 0])
        img = over(img, col, smooth(sd))
        img = add(img, C("#ffffff"), np.exp(-np.abs(sd) / 0.008) * 0.55 * smooth(sd + 0.02))
    # refraction: a rainbow fan thrown from the right facet
    for i, col in enumerate(["#ff6a6a", "#ffd86a", "#6aff9a", "#6ab8ff", "#b86aff"]):
        a = -0.18 + i * 0.09
        s = segment(0.3, 0.05, 0.3 + np.cos(a) * 0.55, 0.05 + np.sin(a) * 0.55)
        img = add(img, C(col), np.exp(-(s / 0.012) ** 2) * 0.7 * (x > 0.3))
    img = add(img, C("#ffffff"), np.exp(-np.hypot(x + 0.1, y + 0.3) / 0.05) * 0.8 * smooth(poly(pts_outer) + 0.02))
    img = collar(img, 701, 0.5)
    img = add(img, C("#c8f4ff"), sparks(14, 702, (-0.7, -0.8, 0.7, 0.5), (0.003, 0.006)) * 0.7)
    return finish(img, 70, exposure=1.4, grade=(0.97, 1.02, 1.05))


@I("core_lodestar")
def core_lodestar():
    img = G("#0a0806", "#1a130a", 710, "#e0a840", (0, -0.05), 0.85, "#3a2c14")
    img = floor_shadow(img, 0, 0.78, 0.5, 0.06, 0.5)
    orb = circle(0, -0.08, 0.52)
    img = bloom_light(img, 0, -0.08, 0.5, "#ffc860", 0.35)
    img = piece(img, orb, "#3a2410", "#d8a850", "#fff4c8", 0.52, tex=0.8 + 0.4 * nz(40, 711, octaves=3), shine=22.0, shadowed=False)
    # an eight-point star inlaid, with a bright spark at its heart
    pts = []
    for k in range(16):
        a = -np.pi / 2 + k * np.pi / 8
        pts.append((0.46 * (1 if k % 2 == 0 else 0.2) * np.cos(a) * 0.9, -0.08 + 0.46 * (1 if k % 2 == 0 else 0.2) * np.sin(a) * 0.9))
    star = poly(pts)
    img = piece(img, star, "#6a4a14", "#fff0b0", "#ffffff", 0.2, glowc="#ffd870", glowamt=0.9, shadowed=False)
    img = add(img, C("#ffffff"), np.exp(-np.hypot(x, y + 0.08) / 0.05) * 0.9)
    ringd = np.abs(np.hypot(x, y + 0.08) - 0.49) - 0.012
    img = over(img, C("#2a1a08"), smooth(ringd) * 0.5 * smooth(orb))
    img = collar(img, 712, 0.52)
    img = add(img, C("#ffe0a0"), sparks(16, 713, (-0.7, -0.8, 0.7, 0.6), (0.003, 0.006)) * 0.7)
    return finish(img, 71, exposure=1.4, grade=(1.05, 0.98, 0.92))


@I("core_cinder")
def core_cinder():
    img = G("#0a0605", "#180a06", 720, "#e04a10", (0, 0.0), 0.9, "#3a1408")
    img = floor_shadow(img, 0, 0.78, 0.5, 0.06, 0.5)
    wx, wy = warp(0.035, 5, 721)
    orb = circle(0, -0.08, 0.52, wx, wy)
    img = add(img, C("#ff4a0c"), np.exp(-np.maximum(orb, 0) / 0.16) * 0.7)
    n = nz(6, 722, octaves=4)
    crack = np.exp(-(np.abs(n - 0.5) / 0.05) ** 2)
    hot = np.exp(-(np.abs(n - 0.5) / 0.14) ** 2)
    img = piece(img, orb, "#0c0605", "#4a2c20", "#c09070", 0.5, tex=0.6 + 0.8 * nz(24, 723, octaves=4), shine=10.0, shadowed=False)
    m = smooth(orb)
    img = add(img, C("#ff3a08"), (hot * 0.5 + crack) * m * 0.9)
    img = add(img, C("#ffd070"), crack ** 2 * m * 0.7)
    for k, lx in enumerate((-0.2, 0.0, 0.22)):
        img = flame(img, lx, -0.5 + 0.03 * k, 0.4, 0.08, 724 + k, lean=0.1 * (k - 1), strength=0.8)
    img = collar(img, 727, 0.52)
    img = add(img, C("#ffa050"), sparks(24, 728, (-0.6, -0.9, 0.6, 0.4), (0.003, 0.007)) * 0.8)
    return finish(img, 72, exposure=1.4, grade=(1.06, 0.96, 0.9))


@I("core_rime")
def core_rime():
    img = G("#050709", "#0a1017", 730, "#5a9ad8", (0, -0.1), 0.85, "#1a2c44")
    img = floor_shadow(img, 0, 0.78, 0.5, 0.06, 0.5)
    img = bloom_light(img, 0, -0.15, 0.5, "#7ac0ff", 0.4)
    spikes = [(0.0, -0.74, 0.14, 0.62), (-0.26, -0.5, 0.11, 0.55), (0.26, -0.52, 0.11, 0.55), (-0.42, -0.2, 0.09, 0.4), (0.42, -0.22, 0.09, 0.4)]
    base = ellipse(0, 0.2, 0.46, 0.3)
    img = piece(img, base, "#1a3050", "#a8d8ff", "#ffffff", 0.3, shine=30.0, tex=0.8 + 0.4 * nz(30, 731))
    for i, (cx, top, hw, ln) in enumerate(spikes):
        a = (cx) * -0.5
        pts = rotated_poly([(cx - hw, top + ln), (cx - hw, top + 0.12), (cx, top), (cx + hw, top + 0.12), (cx + hw, top + ln)], cx, top + ln, a)
        sd = poly(pts)
        img = piece(img, sd, "#2a5a8a", "#d8f0ff", "#ffffff", hw, glowc="#8ac8ff", glowamt=0.35, shine=34.0, shadowed=(i < 1))
        img = add(img, C("#ffffff"), np.exp(-np.abs(sd) / 0.007) * 0.4 * smooth(sd + 0.02))
    img = add(img, C("#e8f6ff"), sparks(30, 732, (-0.8, -0.9, 0.8, 0.5), (0.003, 0.007)) * 0.8)
    mist = ss(0.45, 0.8, nz(3.2, 733, octaves=5))
    img = add(img, C("#9ac8ee"), mist * ss(0.0, 0.9, y) * 0.16)
    img = collar(img, 734, 0.52)
    return finish(img, 73, exposure=1.4, grade=(0.95, 1.0, 1.08))


@I("anchor_stone")
def anchor_stone():
    img = G("#08080a", "#131414", 740, "#7a8078", (0, 0.1), 0.9, "#2a2c2a")
    img = floor_shadow(img, 0, 0.66, 0.8, 0.1, 0.55)
    wx, wy = warp(0.04, 4.5, 741)
    sd = ellipse(0, 0.18, 0.74, 0.5, wx, wy)
    Z = np.clip(-sd / 0.45, 0, 1) ** 0.6 * (0.6 + 0.5 * nz(6, 742)) + 0.12 * nz(28, 743, octaves=3)
    img = heightlit(Z, sd, "#161816", "#8e928a", "#f0f4ec", img, k=75, tex=0.75 + 0.5 * nz(46, 744, octaves=3))
    # the ring: lead poured round its foot, iron worn bright inside by the chain
    lead = ellipse(0.0, -0.18, 0.28, 0.12)
    img = piece(img, lead, "#2a2c30", "#9a9ea6", "#ffffff", 0.12, tex=0.8 + 0.4 * nz(50, 745), shadowed=True)
    outer = ellipse(0.0, -0.52, 0.3, 0.38)
    inner = ellipse(0.0, -0.52, 0.17, 0.25)
    ring = np.maximum(outer, -inner)
    ring = np.maximum(ring, y + 0.12)  # sunk into the lead at the bottom
    img = piece(img, ring, "#0a0a0c", "#7a7a86", "#f0f0ff", 0.1, tex=0.75 + 0.5 * nz(50, 746), shine=28.0)
    # link-marks worn into the ring's inner top
    for k in range(5):
        img = add(img, C("#f0f0ff"), np.exp(-(np.hypot(x - (-0.1 + 0.05 * k), y + 0.7 - 0.04 * np.sin(k)) / 0.015) ** 2) * 0.0)
    img = add(img, C("#e8e8f4"), np.exp(-(np.abs(np.hypot(x / 0.17, (y + 0.52) / 0.25) - 1) / 0.12) ** 2) * (y < -0.52) * smooth(ring) * 0.35)
    return finish(img, 74, exposure=1.4, grade=(1.0, 1.0, 1.0))


@I("oak_heartwood")
def oak_heartwood():
    img = G("#09070a", "#160e0a", 750, "#d06a1a", (0, 0.1), 0.85, "#3a2010")
    img = floor_shadow(img, 0.0, 0.62, 0.8, 0.1, 0.55)
    # a split log end, the heart glowing like banked coals
    log = ellipse(0, 0.0, 0.62, 0.52)
    img = piece(img, log, "#1e1008", "#7a4a28", "#e8c098", 0.2, tex=0.8 + 0.3 * nz(40, 751), shadowed=True)
    r = np.hypot(x / 0.62, y / 0.52)
    rings = 0.55 + 0.45 * np.sin(r * 36.0 + nz(5, 752) * 4.0)
    img = over(img, C("#a8743c") * (0.45 + 0.7 * rings)[..., None] , smooth(ellipse(0, 0, 0.55, 0.45)))
    heart = ss(0.38, 0.0, r)
    img = add(img, C("#ff6a18"), heart * smooth(log) * 0.9)
    img = add(img, C("#ffc060"), ss(0.2, 0.0, r) * smooth(log) * 0.7)
    # the split, a jagged dark crack through it all
    split = polyline([(-0.5, -0.38), (-0.2, -0.1), (0.1, 0.05), (0.3, 0.3), (0.5, 0.42)])
    img = over(img, C("#0a0604"), smooth(split - 0.022) * smooth(log))
    img = add(img, C("#ffa040"), np.exp(-(split / 0.03) ** 2) * smooth(log) * 0.6)
    bark = np.abs(log + 0.04) - 0.04
    img = over(img, C("#1a0e08") * (0.6 + 0.8 * nz(70, 753)[..., None]), smooth(bark) * smooth(log + 0.0) * 0.0)
    img = add(img, C("#ffb050"), sparks(20, 754, (-0.6, -0.9, 0.6, 0.3), (0.003, 0.006)) * 0.7)
    return finish(img, 75, exposure=1.4, grade=(1.06, 0.97, 0.9))


@I("echo_bell")
def echo_bell():
    img = G("#08070a", "#150f0a", 760, "#c89a4a", (0, -0.1), 0.85, "#2e2216")
    img = floor_shadow(img, 0, 0.5, 0.5, 0.07, 0.5)
    # the second, softer ring below: an echo of the bell
    for r0, a0 in [(0.46, 0.5), (0.62, 0.32), (0.78, 0.18)]:
        d = np.abs(np.hypot((x) / 1.0, (y - 0.62) / 0.32) - r0 / 0.55 * 0.9) - 0.0
        img = add(img, C("#d8b070"), np.exp(-(d / 0.03) ** 2) * a0 * 0.35 * (y > 0.45))
    prof = [(0.13 + 0.2 * (1 - np.exp(-5 * t)) + 0.2 * t ** 4, -0.42 + 0.92 * t) for t in np.linspace(0, 1, 28)]
    outline = [(-px_, py_) for px_, py_ in prof[::-1]] + prof
    wx, wy = warp(0.008, 8, 761)
    body = poly(outline, wx, wy)
    img = piece(img, body, "#2a1608", "#c8924a", "#fff0c0", 0.3, tex=0.8 + 0.4 * nz(40, 762), shine=18.0)
    for by in (0.28, 0.4):
        img = over(img, C("#2a1608"), smooth(box(0, by, 0.5, 0.012)) * smooth(body) * 0.5)
    img = piece(img, circle(0.0, 0.62, 0.08), "#2a1608", "#c8924a", "#fff0c0", 0.08)
    ring = np.abs(circle(0, -0.54, 0.13)) - 0.03
    img = piece(img, ring, "#2a1608", "#c8924a", "#fff0c0", 0.03)
    img = add(img, C("#ffe0a0"), np.exp(-(np.hypot(x + 0.14, y - 0.0) / 0.09) ** 2) * smooth(body) * 0.2)
    return finish(img, 76, exposure=1.4, grade=(1.05, 0.98, 0.92))


@I("varrs_signet")
def varrs_signet():
    img = G("#09080a", "#17110c", 770, "#d4a448", (0, 0.1), 0.85, "#3a2c14")
    img = floor_shadow(img, 0, 0.62, 0.7, 0.08, 0.5)
    outer = ellipse(0, 0.1, 0.62, 0.52)
    inner = ellipse(0, 0.16, 0.36, 0.28)
    band = np.maximum(outer, -inner)
    img = piece(img, band, "#3a2208", "#d8a848", "#fff2c0", 0.16, tex=0.8 + 0.3 * nz(50, 771), shine=24.0)
    # the flat bezel on top, stamped with a wall and tower, worn flat on one side
    bez = ellipse(0, -0.34, 0.34, 0.22)
    img = piece(img, bez, "#4a2e0c", "#e8b858", "#fff6d0", 0.2, shine=28.0)
    tower = box(0, -0.34, 0.07, 0.11)
    wall = box(0, -0.26, 0.26, 0.04)
    img = over(img, C("#3a2208"), smooth(np.minimum(tower, wall)) * 0.75 * smooth(bez + 0.04))
    img = over(img, C("#3a2208"), smooth(box(0, -0.46, 0.09, 0.025)) * 0.75 * smooth(bez + 0.04))
    img = add(img, C("#fff0c0"), np.exp(-(np.hypot(x + 0.2, y + 0.42) / 0.1) ** 2) * smooth(bez) * 0.35)
    return finish(img, 77, exposure=1.4, grade=(1.06, 0.98, 0.9))


@I("brine_censer")
def brine_censer():
    img = G("#07090b", "#0f1417", 780, "#a0c8d8", (0, 0.1), 0.9, "#26343a")
    img = floor_shadow(img, 0, 0.62, 0.8, 0.08, 0.5)
    pan = ellipse(-0.1, 0.18, 0.5, 0.4)
    handle = stadium(0.0, 0.0, 0.5, 0.05, *rot(0.45, -0.1, 0.55))
    img = piece(img, handle, "#0c0c0e", "#6a6a74", "#f0f0ff", 0.05, tex=rough(781, 20), shine=26.0)
    img = piece(img, pan, "#0e0e12", "#5a5a64", "#f0f0ff", 0.18, tex=rough(782, 20), shine=22.0)
    # the brine itself, dried to layered white salt that has grown over the iron
    wx, wy = warp(0.02, 9, 783)
    salt = ellipse(-0.1, 0.12, 0.4, 0.28, wx, wy)
    Z = np.clip(-salt / 0.25, 0, 1) ** 0.6 + 0.25 * nz(34, 784, octaves=4)
    img = heightlit(Z, salt, "#9aa8b0", "#f4fafc", "#ffffff", img, k=70, shadowed=False, tex=0.9 + 0.2 * nz(70, 785))
    rng = np.random.default_rng(786)
    for i in range(14):
        cx, cy = rng.uniform(-0.35, 0.2), rng.uniform(-0.05, 0.28)
        s = rng.uniform(0.025, 0.05)
        a = rng.uniform(0, 1.5)
        u, v = rot(cx, cy, a)
        cr = box(0, 0, s, s * 1.3, u, v)
        img = piece(img, cr, "#aab8c0", "#ffffff", "#ffffff", s, shadowed=False)
    img = add(img, C("#e0f4ff"), sparks(14, 787, (-0.6, -0.4, 0.4, 0.4), (0.003, 0.006)) * 0.5)
    return finish(img, 78, exposure=1.4, grade=(0.98, 1.0, 1.04))
