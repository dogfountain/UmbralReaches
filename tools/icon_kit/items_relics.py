"""Item icons, set 1: ash, relics, trophies and materials. Category "item", id = the ItemDB id."""
import numpy as np

from objects import *  # noqa: F401,F403
from registry import recipe


def I(name):
    return recipe("item", name)


def G(top, bot, seed, glow=None, at=(0, 0.1), r=0.8, cloud=None, amt=0.4):
    return scene(top, bot, seed, cloud, amt, at, glow, r)


@I("grave_ash")
def grave_ash():
    img = G("#0a0909", "#181516", 301, "#4a4252", (0, 0.2), 0.75, "#2c2832")
    wx, wy = warp(0.03, 5, 302)
    sd = poly([(-0.86, 0.58), (-0.55, 0.12), (-0.18, -0.2), (0.08, -0.3), (0.42, -0.06), (0.86, 0.58)], wx, wy)
    Z = np.clip(-sd / 0.42, 0, 1) ** 0.75 * (0.7 + 0.6 * nz(9, 303, octaves=4))
    Z = Z + 0.18 * nz(26, 304, octaves=3)
    img = floor_shadow(img, 0, 0.58, 0.9, 0.12, 0.5)
    img = heightlit(Z, sd, "#26222a", "#b2acb8", "#f0ecf6", img, k=95,
                    tex=0.8 + 0.4 * nz(60, 305, octaves=3))
    em = sparks(14, 306, (-0.5, 0.0, 0.5, 0.5), (0.004, 0.008)) * smooth(sd)
    img = add(img, C("#ff7a2a"), em * 0.9)
    # a few pale bone flecks in the heap
    for (bx, by, a) in [(-0.34, 0.34, 0.4), (0.3, 0.26, -0.5), (0.05, 0.1, 1.1)]:
        u, v = rot(bx, by, a)
        b = stadium(0, 0, 0.07, 0.022, u, v)
        img = over(img, C("#d8d0bc") * (0.8 + 0.3 * nz(80, 307)[..., None]), smooth(b))
    return finish(img, 31, exposure=1.35, bloom=0.3, grade=(1.0, 0.98, 1.03))


@I("bone_reliquary")
def bone_reliquary():
    img = G("#0a0706", "#1b130d", 310, "#c07a30", (0, 0.1), 0.8, "#3a2412")
    img = floor_shadow(img, 0, 0.62, 0.7, 0.1, 0.6)
    body = box(0, 0.3, 0.56, 0.3)
    lid = poly([(-0.62, 0.02), (-0.4, -0.34), (0.4, -0.34), (0.62, 0.02)])
    br = rough(311, 18)
    img = piece(img, body, "#2a1a0c", "#a87832", "#ffe2a0", 0.1, tex=br * (0.9 + 0.2 * nz(70, 312)))
    img = piece(img, lid, "#2e1d0e", "#b88838", "#ffe8b0", 0.12, tex=br)
    for bx in (-0.38, 0.38):
        band = box(bx, 0.3, 0.035, 0.3)
        img = over(img, C("#20140a") * (0.9 + 0.3 * nz(50, 313)[..., None]), smooth(band) * 0.8)
        for ry in (0.12, 0.48):
            r = circle(bx, ry, 0.03)
            img = piece(img, r, "#3a2410", "#d8a850", "#fff0c0", 0.03, shadowed=False)
    ridge = stadium(0, -0.34, 0.4, 0.035)
    img = piece(img, ridge, "#3a2410", "#d8a850", "#fff0c0", 0.035)
    # the window with a knucklebone inside
    win = box(0, 0.3, 0.24, 0.18)
    img = over(img, C("#100a06"), smooth(win))
    img = add(img, C("#8a5a20"), smooth(win + 0.01) * 0.25)
    bone = stadium(0, 0.3, 0.17, 0.03, *rot(0, 0.3, 0.45))
    img = over(img, C("#e6dcc2"), smooth(bone) * smooth(win))
    for k in (-1, 1):
        for j in (-1, 1):
            b = circle(0.17 * k * np.cos(0.45) + 0.0, 0.3 + 0.17 * k * np.sin(0.45) + 0.03 * j, 0.045)
            img = over(img, C("#f0e8d0"), smooth(b) * smooth(win))
    frame = np.abs(win) - 0.012
    img = over(img, C("#c89a48"), smooth(frame))
    img = add(img, C("#ffffff"), sparks(1, 314, (-0.15, 0.2, -0.1, 0.25), (0.01, 0.015)) * 0.2 * smooth(win))
    # clasp
    img = piece(img, circle(0, 0.58, 0.05), "#3a2410", "#e0b860", "#fff4c8", 0.05)
    img = add(img, C("#ffb050"), sparks(14, 315, (-0.8, -0.6, 0.8, 0.4), (0.003, 0.006)) * 0.5)
    return finish(img, 32, exposure=1.4, bloom=0.35, grade=(1.05, 0.98, 0.92))


@I("thorn_heart")
def thorn_heart():
    img = G("#0b0506", "#1a0a0c", 320, "#8a1a24", (0, 0.05), 0.65, "#3a1018")
    hs = heart_sd(0, 0.02, 0.5)
    wx, wy = warp(0.012, 7, 321)
    hs = heart_sd(0, 0.02, 0.5, wx, wy)
    img = add(img, C("#c02030"), np.exp(-np.maximum(hs, 0) / 0.14) * 0.55)
    veins = cracks(322, 6.0, 0.05)
    tex = 0.7 + 0.5 * nz(26, 323, octaves=4) + 0.25 * veins
    img = piece(img, hs, "#1a0306", "#d02a3c", "#ffd0c8", 0.2, tex=tex, glowc="#ff3040", glowamt=0.2, shine=20.0, relief=1.2)
    # thorny briar wrapped round it
    vine = curve(lambda t: (-0.62 + 1.24 * t, 0.1 + 0.2 * np.sin(t * 9.0 + 0.5) - 0.22 * t * 0), 60)
    d, tt, side = path_t(vine)
    vsd = d - 0.032
    img = piece(img, vsd, "#14100a", "#5a4a24", "#c0a860", 0.032, tex=0.8 + 0.5 * nz(40, 324))
    rng = np.random.default_rng(325)
    for i in range(1, 17):
        px_, py_ = vine[int(i / 17 * 59)]
        s = 1 if i % 2 else -1
        ang = rng.uniform(0.5, 1.1) * s - 1.57
        L = rng.uniform(0.08, 0.13)
        tip = (px_ + np.cos(ang) * L, py_ + np.sin(ang) * L)
        tri = poly([(px_ - 0.022, py_), (px_ + 0.022, py_), tip])
        img = piece(img, tri, "#1a1208", "#8a7438", "#f0e0a0", 0.02, shadowed=False)
    img = add(img, C("#ff5060"), sparks(12, 326, (-0.7, -0.7, 0.7, 0.6), (0.003, 0.006)) * 0.6)
    return finish(img, 33, exposure=1.4, grade=(1.05, 0.96, 0.96))


@I("kin_lamp")
def kin_lamp():
    img = G("#08060a", "#17110d", 330, "#e08a30", (0, 0.05), 0.9, "#3a2412")
    cx = 0.0
    body = stadium(cx, 0.12, 0.5, 0.31, *rot(cx, 0.12, np.pi / 2))
    # vertical horn cylinder
    cyl = box(cx, 0.15, 0.31, 0.46)
    img = bloom_light(img, 0, 0.15, 0.4, "#ff9a3a", 0.5)
    hornc = mix(C("#8a5a20"), C("#ffd890"), 0.5 + 0.5 * np.cos(x / 0.31 * 1.4) * 0)
    horn = mix(C("#c98a3a"), C("#ffe2a0"), (1 - np.clip(np.abs(x) / 0.31, 0, 1) ** 1.6)[..., None][..., 0])
    horn = horn * (0.75 + 0.5 * nz(18, 331, px=x * 1.2, py=y * 0.4)[..., None])
    img = piece(img, cyl, "#8a5a20", "#ffd890", "#fff6d8", 0.3, shadowed=False, tex=0.9 + 0.3 * nz(14, 331), glowc="#ff9a30", glowamt=0.7)
    # flame inside
    img = flame(img, 0.0, 0.4, 0.55, 0.12, 332)
    img = add(img, C("#fff0c0"), smooth(cyl) * np.exp(-np.hypot(x, y - 0.25) / 0.2) * 0.4)
    # horn ribbing
    for ry in (-0.14, 0.02, 0.18, 0.34, 0.5):
        img = over(img, C("#3a2410"), smooth(np.abs(box(cx, ry, 0.31, 0.012)) - 0.0) * 0.28 * smooth(cyl))
    for ry in (-0.34, 0.62):
        cap = box(cx, ry, 0.36, 0.07)
        img = piece(img, cap, "#2a1a0a", "#a87838", "#ffe0a0", 0.07, tex=rough(333, 18))
    ring = np.abs(circle(cx, -0.55, 0.14)) - 0.025
    img = piece(img, ring, "#2a1a0a", "#b88838", "#ffe0a0", 0.025)
    for sx in (-0.31, 0.31):
        img = over(img, C("#3a2212") * (0.8 + 0.4 * nz(60, 334)[..., None]), smooth(box(sx, 0.15, 0.025, 0.46)))
    img = add(img, C("#ffc060"), sparks(16, 335, (-0.6, -0.8, 0.6, 0.2), (0.003, 0.006)) * 0.7)
    return finish(img, 34, exposure=1.4, grade=(1.06, 0.97, 0.9))


@I("slag_heart")
def slag_heart():
    img = G("#0a0706", "#150b08", 340, "#d04a10", (0, 0.1), 0.75, "#3a1408")
    wx, wy = warp(0.05, 5, 341)
    sd = heart_sd(0, 0.04, 0.55, wx, wy)
    img = add(img, C("#ff4a10"), np.exp(-np.maximum(sd, 0) / 0.16) * 0.55)
    n = nz(6.5, 342, octaves=4)
    crack = np.exp(-(np.abs(n - 0.5) / 0.05) ** 2)
    hot = np.exp(-(np.abs(n - 0.5) / 0.13) ** 2)
    tex = 0.5 + 0.9 * nz(20, 343, octaves=4)
    img = piece(img, sd, "#0c0807", "#4a3830", "#c0a090", 0.3, tex=tex, shine=10.0, shadowed=False)
    inside = smooth(sd)
    img = add(img, C("#ff3a08"), (hot * 0.5 + crack * 0.9) * inside * (0.6 + 0.6 * ss(0.5, -0.4, y)))
    img = add(img, C("#ffd070"), crack ** 2 * 0.6 * inside)
    img = add(img, C("#ff9a3a"), sparks(26, 344, (-0.6, -0.8, 0.6, 0.5), (0.003, 0.008)) * 0.9)
    return finish(img, 35, exposure=1.4, grade=(1.06, 0.95, 0.9))


@I("fog_crook")
def fog_crook():
    img = G("#07090d", "#10151c", 350, "#6a7a94", (0.1, -0.1), 0.9, "#34425a", 0.6)
    pts = [(-0.55, 0.88), (0.0, -0.3)]
    r = 0.34
    cx, cy = 0.34, -0.3
    for i in range(1, 30):
        th = np.pi + 1.18 * np.pi * i / 29
        pts.append((cx + r * np.cos(th), cy + r * np.sin(th)))
    d, tt, side = path_t(pts)
    w = 0.05 + 0.02 * ss(1.4, 0.0, tt)
    sd = d - w
    u = tt
    tex = grain(u, side, 351, 2.0, 34.0, 0.9) * (0.8 + 0.4 * nz(9, 352))
    img = piece(img, sd, "#161a1e", "#7a8696", "#e6f0ff", 0.05, tex=tex, shine=30.0, relief=0.8)
    # hook tip bright where it is worn, a rope binding
    tipd = np.hypot(x - pts[-1][0], y - pts[-1][1])
    img = add(img, C("#e8f0ff"), np.exp(-tipd / 0.04) * 0.2)
    for b in (0.12, 0.2):
        bu = box(-0.55 + (0.0 + 0.55) * 0.7, 0.0, 0.0, 0.0)
    # fog drifting over the lower half
    f = ss(0.4, 0.8, nz(2.8, 353, octaves=5) * 0.7 + nz(6, 354, octaves=3) * 0.4)
    img = add(img, C("#9fb0c8"), f * ss(-0.5, 0.9, y) * 0.22)
    img = add(img, C("#c8d4e8"), sparks(18, 355, (-0.8, -0.5, 0.8, 0.8), (0.004, 0.008)) * 0.25)
    return finish(img, 36, exposure=1.4, grade=(0.97, 0.99, 1.06))


@I("ferry_coin")
def ferry_coin():
    img = G("#06090a", "#0d1513", 360, "#3a8a80", (0, 0.0), 0.8, "#1a3a38")
    img = floor_shadow(img, 0.05, 0.62, 0.55, 0.08, 0.5)
    # the cord first, looped behind the coin and hanging below
    cord = curve(lambda t: (0.02 + 0.5 * np.sin(t * 6.0 - 0.8) * (0.3 + t), -0.8 + 1.7 * t), 50)
    d, tt, side = path_t(cord)
    twist = 0.7 + 0.4 * np.sin(tt * 90 + side * 90)
    img = piece(img, d - 0.03, "#1a1008", "#8a6a42", "#e0c898", 0.03, tex=twist)
    coin = circle(0, 0.0, 0.52)
    hole = box(0, 0, 0.12, 0.12)
    ring = np.maximum(coin, -hole - 0.0)
    n = nz(6, 361, octaves=4)
    patina = ss(0.45, 0.65, n)
    tex = 0.75 + 0.5 * nz(40, 362, octaves=3)
    img = piece(img, ring, "#2a1608", "#c08a40", "#ffeab8", 0.12, tex=tex)
    img = over(img, C("#3a9a88") * (0.7 + 0.4 * nz(30, 363)[..., None]), smooth(ring) * patina * 0.55)
    # raised rim and stamped ticks
    rim = np.abs(np.hypot(x, y) - 0.43) - 0.012
    img = over(img, C("#2a1a0a"), smooth(rim) * 0.55 * smooth(ring))
    a = np.arctan2(y, x)
    r = np.hypot(x, y)
    tick = (np.abs(np.sin(a * 12)) > 0.93) & (r > 0.2) & (r < 0.4)
    img = over(img, C("#2a1a0a"), tick.astype(float) * 0.5 * smooth(ring))
    img = over(img, C("#0b0705"), smooth(hole))
    img = add(img, C("#ffd9a0"), np.exp(-np.maximum(np.abs(hole) - 0.0, 0) / 0.01) * 0.2)
    # the cord through the hole
    img = over(img, C("#6a4a28") * twist[..., None], smooth(d - 0.03) * (np.abs(hole + 0.1) < 0.12))
    return finish(img, 37, exposure=1.4, grade=(0.98, 1.0, 1.0))


@I("ash_seed")
def ash_seed():
    img = G("#0a0808", "#161111", 370, "#b0541a", (0, 0.0), 0.7, "#2c2428")
    img = floor_shadow(img, 0.05, 0.64, 0.4, 0.07, 0.6)
    s = 1 - 0.32 * np.clip(-(y - 0.05) / 0.6, -1, 1)
    sd = (np.hypot(x / s / 0.38, (y - 0.04) / 0.6) - 1.0) * 0.38
    img = add(img, C("#ff7a28"), np.exp(-np.maximum(sd, 0) / 0.1) * 0.35)
    img = piece(img, sd, "#050304", "#3e3438", "#ffffff", 0.38, tex=0.8 + 0.4 * nz(40, 371), shine=14.0, shadowed=False)
    # the seam, warm like a banked coal
    seam = np.abs(x - 0.02 * np.sin(y * 7.0)) / 0.012
    img = add(img, C("#ff6a1a"), np.exp(-seam ** 2) * smooth(sd + 0.02) * 0.9 * ss(-0.55, -0.3, y) * ss(0.65, 0.2, y))
    img = add(img, C("#ffb060"), np.exp(-(seam * 0.3) ** 2) * smooth(sd) * 0.2)
    # grey dust drifting off it
    img = add(img, C("#aaa2a8"), sparks(30, 372, (-0.6, -0.8, 0.6, 0.6), (0.004, 0.009)) * 0.4)
    return finish(img, 38, exposure=1.35, grade=(1.03, 0.98, 0.96))


@I("hair_rope")
def hair_rope():
    img = G("#0a0908", "#17130f", 380, "#8a7a62", (0, 0.1), 0.85, "#2c261c")
    img = floor_shadow(img, 0, 0.72, 0.8, 0.08, 0.4)
    pts = curve(lambda t: (-0.75 + 1.5 * t, 0.42 - 0.84 * t + 0.25 * np.sin(t * 6.3)), 70)
    d, tt, side = path_t(pts)
    w = 0.1
    sd = d - w
    ph = (tt * 24.0 + side / w * 1.9) / (2 * np.pi)
    idx = np.floor(ph * 3.0) % 3
    pal = np.stack([C("#8a8680"), C("#6a4a30"), C("#d8b84a")])
    col = pal[idx.astype(int)]
    shade = 0.55 + 0.45 * np.cos(ph * 2 * np.pi * 3.0)
    # round-bodied: darker toward the edges
    edge = 1 - 0.55 * (np.clip(np.abs(side) / w, 0, 1) ** 2)
    col = col * (shade * edge * (0.85 + 0.3 * nz(60, 381)))[..., None]
    img = shadow(img, sd)
    img = over(img, col, smooth(sd) * (tt > 0.02) * (tt < 99))
    img = add(img, C("#fff0d0"), np.exp(-(np.abs(side + 0.03) / 0.012) ** 2) * smooth(sd) * 0.18)
    # tied ends: a dark wrapped cord, a frayed cut
    for tpos in (0.22, 1.3):
        pass
    for e, p0 in enumerate([pts[0], pts[-1]]):
        rng = np.random.default_rng(382 + e)
        for _ in range(9):
            a = rng.uniform(-0.6, 0.6) + (np.pi if e == 0 else 0)
            L = rng.uniform(0.06, 0.14)
            q = (p0[0] + np.cos(a) * L, p0[1] + np.sin(a) * L)
            s = segment(p0[0], p0[1], q[0], q[1])
            img = over(img, [C("#8a8680"), C("#6a4a30"), C("#d8b84a")][int(rng.integers(3))], smooth(s - 0.007))
    for tp in (0.12, 0.88):
        qx, qy = pts[int(tp * 69)]
        band = np.abs(np.hypot(x - qx, y - qy) - 0.0) - 0.0
        bd = circle(qx, qy, 0.1)
        img = over(img, C("#2a1c10") * (0.8 + 0.4 * nz(80, 383)[..., None]), smooth(bd) * smooth(sd + 0.01) * 0.0)
    return finish(img, 39, exposure=1.4, grade=(1.03, 0.99, 0.94))


@I("mason_mark")
def mason_mark():
    img = G("#08090a", "#121413", 390, "#7a7a6a", (-0.1, -0.1), 0.9, "#2a2c28")
    wx, wy = warp(0.025, 6, 391)
    sd = poly([(-0.66, 0.34), (-0.7, -0.22), (-0.28, -0.6), (0.36, -0.56), (0.7, -0.14), (0.62, 0.4), (0.0, 0.62)], wx, wy)
    Z = np.clip(-sd / 0.22, 0, 1) ** 0.6 * (0.55 + 0.45 * nz(8, 392)) + 0.12 * nz(30, 393, octaves=3)
    img = floor_shadow(img, 0.05, 0.6, 0.75, 0.1, 0.5)
    img = heightlit(Z, sd, "#1a1b1a", "#9a9a8c", "#f0f0e0", img, k=70, tex=0.75 + 0.5 * nz(55, 394, octaves=3))
    # the cutter's mark, incised, then a lit lip along its lower-right edge
    mark = polyline([(-0.2, 0.22), (-0.2, -0.26), (0.2, 0.22), (0.2, -0.26)])
    mark = np.minimum(mark, segment(-0.3, 0.0, 0.3, 0.0))
    g = smooth(mark - 0.026) * smooth(sd + 0.05)
    lip = smooth(np.roll(np.roll(mark, 2, 0), 2, 1) - 0.026) * smooth(sd + 0.05) * (1 - g)
    img = img * (1 - 0.8 * g)[..., None]
    img = add(img, C("#e8e8d8"), lip * 0.4)
    img = add(img, C("#ffdc9a"), sparks(3, 395, (-0.3, -0.5, 0.3, 0.2), (0.003, 0.005)) * 0.0)
    return finish(img, 40, exposure=1.4, grade=(1.0, 1.0, 0.98))


@I("abbot_crown")
def abbot_crown():
    img = G("#09070a", "#17110f", 400, "#c8903a", (0, 0.0), 0.85, "#3a2616")
    img = floor_shadow(img, 0, 0.66, 0.7, 0.08, 0.5)
    band = poly([(-0.66, 0.2), (0.66, 0.2), (0.6, 0.52), (-0.6, 0.52)])
    img = piece(img, band, "#0c0a0a", "#4a4440", "#c8c0b8", 0.14, tex=rough(401, 20) * 0.9)
    boxy = [(-0.52, -0.42), (-0.26, -0.62), (0.0, -0.74), (0.26, -0.62), (0.52, -0.42)]
    for i, (bx, top) in enumerate(boxy):
        tine = poly([(bx - 0.1, 0.24), (bx + 0.1, 0.24), (bx + 0.055, top + 0.06), (bx - 0.055, top + 0.06)])
        bone = 0.8 + 0.5 * grain(y, x, 402 + i, 1.5, 20.0, 0.5)
        img = piece(img, tine, "#4a3a26", "#e8dcc0", "#fffaf0", 0.08, tex=bone, relief=0.8)
        for kx in (-0.045, 0.045):
            kn = circle(bx + kx, top + 0.03, 0.05)
            img = piece(img, kn, "#5a4a32", "#f2e8d0", "#ffffff", 0.05, shadowed=False)
        # knuckle joint lines
        jy = (top + 0.3) * 0.5 + 0.1
        img = over(img, C("#5a4630"), smooth(box(bx, jy, 0.09, 0.008)) * 0.6)
    for rx in (-0.5, -0.25, 0.0, 0.25, 0.5):
        img = piece(img, circle(rx, 0.36, 0.035), "#2a2622", "#9a928a", "#ffffff", 0.035, shadowed=False)
    img = over(img, C("#3a0e0e"), smooth(circle(0, 0.36, 0.0)) * 0)
    img = add(img, C("#ffb050"), np.exp(-np.hypot(x, y + 0.1) / 0.5) * 0.08)
    return finish(img, 41, exposure=1.4, grade=(1.04, 0.98, 0.93))


@I("crown_shard")
def crown_shard():
    img = G("#09090a", "#141312", 410, "#8a7a5a", (0.1, -0.1), 0.85, "#2c2a26")
    img = floor_shadow(img, 0, 0.7, 0.6, 0.08, 0.5)
    pts = [(-0.28, 0.66), (-0.22, 0.38), (-0.32, 0.18), (-0.12, -0.2), (0.02, -0.74), (0.14, -0.2), (0.3, 0.12), (0.22, 0.34), (0.3, 0.6), (0.1, 0.5), (0.0, 0.7)]
    wx, wy = warp(0.012, 8, 411)
    sd = poly(pts, wx, wy)
    tex = 0.7 + 0.5 * nz(26, 412, octaves=4)
    img = piece(img, sd, "#2a1e0c", "#c8a458", "#fff0c0", 0.2, tex=tex, relief=0.8, shine=20.0)
    img = over(img, C("#5a8a78") * (0.7 + 0.5 * nz(24, 413)[..., None]), smooth(sd) * ss(0.55, 0.7, nz(5, 414)) * 0.35)
    # a cracked stone set in it
    img = piece(img, circle(0.0, 0.05, 0.08), "#3a0a1c", "#c03060", "#ffd0e0", 0.08, glowc="#ff4080", glowamt=0.4)
    # a mouth of sound lines, a word begun
    for rr, a in [(0.42, 0.35), (0.56, 0.22), (0.7, 0.14)]:
        ring = np.abs(np.hypot(x - 0.0, y - 0.7) - rr)
        ang = np.arctan2(y - 0.7, x)
        arc = ss(-np.pi * 0.85, -np.pi * 0.5, ang) * ss(-np.pi * 0.15, -np.pi * 0.5, ang)
        img = add(img, C("#e8dcb0"), np.exp(-(ring / 0.008) ** 2) * arc * a * 0.0)
    img = add(img, C("#ffffff"), sparks(2, 415, (-0.1, -0.5, 0.1, -0.1), (0.004, 0.006)) * 0.35)
    return finish(img, 42, exposure=1.4, grade=(1.02, 1.0, 0.97))


@I("ascension_seal")
def ascension_seal():
    img = G("#07050d", "#120a1e", 420, "#7a4ae0", (0, 0.0), 0.8, "#2a1a50")
    disc = circle(0, 0.02, 0.58)
    img = bloom_light(img, 0, 0.02, 0.45, "#8a5aff", 0.35)
    tex = 0.8 + 0.4 * nz(40, 421, octaves=3)
    img = piece(img, disc, "#1c1230", "#9a86cc", "#f4eeff", 0.18, tex=tex, shine=18.0)
    ring = np.abs(np.hypot(x, y - 0.02) - 0.45) - 0.02
    img = piece(img, ring, "#241838", "#c8b4f4", "#ffffff", 0.02, shadowed=False)
    # the door in the sky: an arch, and a latch across it
    arch = polyline([(-0.2, 0.3), (-0.2, -0.1)])
    a_ = np.minimum(polyline([(-0.2, 0.3), (-0.2, -0.08)]), polyline([(0.2, 0.3), (0.2, -0.08)]))
    a_ = np.minimum(a_, np.abs(np.hypot(x, (y + 0.08)) - 0.2) + (y > -0.08) * 9)
    img = add(img, C("#b49cff"), smooth(a_ - 0.014) * smooth(disc + 0.1) * 0.8)
    img = add(img, C("#6a46d0"), np.exp(-a_ / 0.05) * smooth(disc + 0.1) * 0.5)
    bar = box(0, 0.1, 0.36, 0.055)
    img = piece(img, bar, "#2a1a48", "#d8c8ff", "#ffffff", 0.055)
    for bx in (-0.36, 0.36):
        img = piece(img, circle(bx, 0.1, 0.07), "#2a1a48", "#c8b4f8", "#ffffff", 0.07, shadowed=False)
    img = piece(img, circle(0, 0.1, 0.075), "#18102c", "#f0e8ff", "#ffffff", 0.075, glowc="#9a7aff", glowamt=0.6, shadowed=False)
    img = add(img, C("#c8b4ff"), sparks(18, 422, (-0.7, -0.7, 0.7, 0.7), (0.003, 0.007)) * 0.7)
    return finish(img, 43, exposure=1.4, grade=(1.0, 0.96, 1.06))


@I("ember_shard")
def ember_shard():
    img = G("#0a0605", "#170b07", 430, "#d0480e", (0, 0.1), 0.8, "#3a1408")
    img = floor_shadow(img, 0.0, 0.68, 0.6, 0.08, 0.6)
    big = poly([(-0.4, 0.66), (-0.5, 0.1), (-0.22, -0.5), (0.1, -0.76), (0.34, -0.1), (0.46, 0.2), (0.3, 0.64)])
    small = poly([(0.3, 0.7), (0.38, 0.46), (0.62, 0.38), (0.7, 0.66)])
    for k, (sd, seed) in enumerate([(small, 431), (big, 432)]):
        img = add(img, C("#ff4a0c"), np.exp(-np.maximum(sd, 0) / 0.12) * 0.5)
        n = nz(5.5, seed, octaves=4)
        tex = 0.55 + 0.75 * np.clip((x * 1.1 - y * 0.5 + (n - 0.5) * 0.5) * 0.9 + 0.55, 0, 1)
        img = piece(img, sd, "#1a0603", "#d8481a", "#ffd890", 0.3, tex=tex, glowc="#ff7a20", glowamt=0.5, shine=36.0, shadowed=False, rim="#ffc060", rim_amt=0.5)
        img = over(img, C("#1a0a08"), smooth(sd) * ss(0.55, 0.75, nz(9, seed + 3)) * 0.5)
    img = add(img, C("#ffb050"), sparks(26, 433, (-0.7, -0.9, 0.8, 0.5), (0.003, 0.007)) * 0.9)
    return finish(img, 44, exposure=1.4, grade=(1.06, 0.96, 0.9))


@I("ash_bloom")
def ash_bloom():
    img = G("#08080a", "#141315", 440, "#7a6a9a", (0, -0.05), 0.75, "#2a2630")
    # soil of ash and a scatter of grey flecks
    soil = ss(0.0, 0.55, nz(40, 441, octaves=3))
    img = add(img, C("#4a4650"), soil[..., None][..., 0] * 0.06)
    for k, (lx, ly, a) in enumerate([(-0.5, 0.45, -0.4), (0.52, 0.48, 0.5)]):
        u, v = rot(lx, ly, a)
        lf = ellipse(0.2, 0, 0.3, 0.1, u, v)
        img = piece(img, lf, "#0a1210", "#3a5a48", "#a8d0b8", 0.1, tex=0.85 + 0.3 * nz(30, 442 + k))
    cx, cy = 0.0, -0.02
    for ring_i, (n, ln, wd, off, dark, light) in enumerate([(7, 0.46, 0.16, 0.0, "#4a4666", "#c8c2e4"), (7, 0.38, 0.13, 0.22, "#6a6688", "#ece8fa")]):
        for k in range(n):
            ang = 2 * np.pi * k / n + off + ring_i * 0.3
            u, v = rot(cx, cy, ang)
            pet = ellipse(ln * 0.55, 0, ln * 0.55, wd, u, v)
            veins = 0.85 + 0.15 * np.cos(v / wd * 6.0)
            img = piece(img, pet, dark, light, "#ffffff", 0.12, tex=veins, shadowed=(ring_i == 0), glowc="#b8a8ff", glowamt=0.25)
    img = piece(img, circle(cx, cy, 0.11), "#6a2a10", "#ff9a3a", "#fff0c0", 0.11, glowc="#ff7a20", glowamt=0.7)
    img = add(img, C("#ffd9a0"), sparks(10, 443, (-0.12, -0.12, 0.12, 0.12), (0.003, 0.005)) * 0.8)
    img = add(img, C("#c8c0f0"), sparks(20, 444, (-0.8, -0.8, 0.8, 0.8), (0.003, 0.006)) * 0.35)
    return finish(img, 45, exposure=1.35, grade=(1.0, 0.98, 1.06))


@I("grave_iron")
def grave_iron():
    img = G("#0a0706", "#150e0b", 450, "#8a3a1a", (0, 0.2), 0.8, "#2c1a12")
    img = floor_shadow(img, 0, 0.58, 0.8, 0.1, 0.5)
    wx, wy = warp(0.05, 5, 451)
    sd = poly([(-0.76, 0.5), (-0.6, -0.1), (-0.2, -0.46), (0.3, -0.4), (0.72, -0.02), (0.78, 0.5), (0.0, 0.62)], wx, wy)
    Z = np.clip(-sd / 0.36, 0, 1) ** 0.7 * (0.6 + 0.6 * nz(7, 452)) + 0.2 * nz(24, 453, octaves=3)
    rust = nz(10, 454, octaves=4)
    tex = 0.6 + 0.8 * nz(34, 455, octaves=3)
    img = heightlit(Z, sd, "#1a0e0a", "#9a4a2a", "#ffc8a0", img, k=85, tex=tex)
    # bright rust veins and fresh iron glints
    vein = cracks(456, 6.5, 0.05)
    img = over(img, C("#d85a2a"), vein * smooth(sd) * 0.35)
    img = add(img, C("#c8c0c0"), (nz(40, 457, octaves=2) > 0.86) * smooth(sd) * 0.35)
    # a coffin nail through it
    u, v = rot(0.1, 0.08, -0.55)
    shaft = stadium(0, 0, 0.7, 0.028, u, v)
    img = piece(img, shaft, "#0c0a09", "#6a625c", "#d0c8c0", 0.028, tex=0.8 + 0.4 * nz(50, 458))
    head = circle(*(lambda p: p)((0.1 + 0.7 * np.cos(-0.55), 0.08 + 0.7 * np.sin(-0.55) * -1 * -1)), 0.06) if False else circle(0.1 - 0.7 * np.cos(-0.55) * -1, 0.08 - 0.7 * np.sin(-0.55) * -1, 0.0)
    hx, hy = 0.1 + 0.68 * np.cos(-0.55), 0.08 - 0.68 * np.sin(-0.55)
    img = piece(img, circle(hx, hy, 0.065), "#0c0a09", "#6a625c", "#d0c8c0", 0.065)
    return finish(img, 46, exposure=1.4, grade=(1.04, 0.98, 0.94))


@I("relic_fragment")
def relic_fragment():
    img = G("#09070c", "#150f1a", 460, "#7a5ac0", (0, 0.1), 0.8, "#2a2040")
    # a fold of dark cloth under three slivers
    cloth = 0.5 + 0.5 * np.sin(x * 5 + nz(3, 461) * 5 + y * 3)
    img = img * (0.8 + 0.25 * cloth[..., None])
    img = floor_shadow(img, 0, 0.5, 0.8, 0.12, 0.3)
    wx, wy = warp(0.01, 9, 462)
    bronze = poly([(-0.74, 0.3), (-0.5, -0.1), (-0.14, -0.32), (-0.02, -0.14), (-0.3, 0.34), (-0.6, 0.5)], wx, wy)
    bone = poly([(0.0, 0.62), (0.08, 0.08), (0.34, -0.5), (0.44, -0.46), (0.28, 0.18), (0.2, 0.62)], wx, wy)
    wood = poly([(0.36, 0.5), (0.5, 0.1), (0.78, -0.12), (0.8, -0.02), (0.64, 0.3), (0.5, 0.56)], wx, wy)
    img = piece(img, bronze, "#14201a", "#5a8a6a", "#c8f0d8", 0.12, tex=0.7 + 0.6 * nz(30, 463, octaves=3))
    img = over(img, C("#c89a40"), smooth(np.abs(bronze + 0.012) - 0.01) * 0.6 * smooth(bronze))
    img = piece(img, bone, "#4a4030", "#f0e8d2", "#ffffff", 0.07, tex=grain(y, x, 464, 3.0, 22.0, 0.4))
    img = piece(img, wood, "#1e100a", "#8a5a34", "#e8c098", 0.07, tex=grain(x + y, x - y, 465, 2.0, 30.0, 0.9))
    img = add(img, C("#ffd070"), np.exp(-np.minimum(np.abs(bronze), 9) / 0.01) * 0.0)
    img = add(img, C("#c8b0ff"), sparks(20, 466, (-0.8, -0.6, 0.8, 0.6), (0.003, 0.007)) * 0.6)
    return finish(img, 47, exposure=1.4, grade=(1.0, 0.98, 1.04))
