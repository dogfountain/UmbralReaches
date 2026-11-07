"""HUD buff / debuff icons, repainted as illustrations of a thing (category "aura"): a cracked hourglass,
a broken shield, a frozen hand, a gagged bell, a branding iron ... Each keeps its colour identity, has one
bold subject with a dark outline, and reads at the HUD's 30 px. (flame, hollow and rested live in auras.py.)"""
import numpy as np

from motifs import *  # noqa: F401,F403
from registry import recipe


def A(name):
    return recipe("aura", name)


def _bg(top, bottom, seed, glow, at=(0, 0), r=0.7, st=0):
    return ground(top, bottom, seed, glow, at, r, st)


def _rotpts(pts, ang, cx=0.0, cy=0.0):
    c, s = np.cos(ang), np.sin(ang)
    return [(cx + (px - cx) * c - (py - cy) * s, cy + (px - cx) * s + (py - cy) * c) for px, py in pts]


@A("slow")
def slow():
    img = _bg("#06040c", "#100a1e", 600, "#4a30a0", (0, 0), 0.8)
    glass_pts = [(-0.3, -0.58), (0.3, -0.58), (0.3, -0.44), (0.07, -0.06), (0.07, 0.06), (0.3, 0.44), (0.3, 0.58),
                 (-0.3, 0.58), (-0.3, 0.44), (-0.07, 0.06), (-0.07, -0.06), (-0.3, -0.44)]
    g = poly(glass_pts) - 0.05
    # the frame: two caps and two posts
    for sx in (-0.4, 0.4):
        img = obj(img, stadium(sx, 0, 0.02, 0.7) * 0 + box(sx, 0, 0.035, 0.7), "#1a1020", "#7a5a96", "#e8d0ff", 0.035)
    img = obj(img, box(0, -0.7, 0.5, 0.07) - 0.02, "#241630", "#9a78b8", "#f0e0ff", 0.07, halo="#8a68ff", halo_amt=0.3)
    img = obj(img, box(0, 0.7, 0.5, 0.07) - 0.02, "#241630", "#9a78b8", "#f0e0ff", 0.07)
    # glass body
    glassc = mix(C("#150f2a"), C("#6a58b0"), np.clip(0.35 + (-x) * 0.4 + (-y) * 0.1, 0, 1))
    img = over(add(img, C("#8a68ff"), np.exp(-np.maximum(g, 0) / 0.08) * 0.5), C("#050304"), smooth(g - 0.03) * 0.94)
    img = over(img, glassc, smooth(g))
    inner = g + 0.035
    # sand: a heap below, a little left above, a thread between
    heap = np.maximum(inner, -(y - (0.58 - 0.5 * np.exp(-(x / 0.28) ** 2))))
    heap = np.maximum(inner, (0.28 + 0.2 * (np.abs(x) / 0.3) - y) * -1 + 0.0) if False else np.maximum(inner, -(y - (0.2 + 0.3 * (np.abs(x) / 0.3) ** 2)))
    sand = mix(C("#a888e8"), C("#f0e0ff"), np.clip(0.5 - x * 0.6 - (y - 0.3), 0, 1))
    img = over(img, sand, smooth(heap))
    top = np.maximum(inner, -(y - (-0.46 + 0.0)) * -1) if False else np.maximum(inner, np.maximum(-(y + 0.3 - 0.18 * np.exp(-(x / 0.2) ** 2) * -1), 0) * 0 + (-0.3 - y) * -1 * 0 + (y - -0.12))
    img = over(img, sand * 0.95, smooth(np.maximum(inner, np.maximum(-(y + 0.26 + 0.12 * (np.abs(x) / 0.3)), y + 0.09))))
    img = over(img, C("#f4eaff"), smooth(segment(0, -0.04, 0, 0.3) - 0.012))
    # the crack, with the sand leaking out of it and a chip gone
    crack = polyline([(-0.26, -0.5), (-0.12, -0.32), (-0.22, -0.18), (-0.06, 0.02), (-0.2, 0.2), (-0.1, 0.4)]) - 0.012
    img = add(img, C("#e0c8ff"), np.exp(-np.maximum(crack, 0) / 0.04) * 0.7 * smooth(g + 0.02))
    img = over(img, C("#fff6ff"), smooth(crack) * smooth(g + 0.01))
    img = add(img, C("#ffffff"), np.exp(-np.hypot(x + 0.17, y + 0.38) / 0.05) * 0.5 * smooth(g))
    img = add(img, C("#e8d8ff"), sparks(10, 601, (-0.5, 0.2, 0.2, 0.75), (0.004, 0.009)) * 0.9)
    return finish(img, 60, grade=(1.0, 0.96, 1.06))


@A("sundered")
def sundered():
    img = _bg("#080410", "#150a22", 680, "#a050ff", (0, 0.05), 0.55)
    sh = [(-0.5, -0.56), (0.5, -0.56), (0.52, 0.02), (0.32, 0.42), (0.0, 0.76), (-0.32, 0.42), (-0.52, 0.02)]
    zig = lambda yy: 0.03 * np.sin(yy * 11.0) + 0.05 * np.sign(np.sin(yy * 5.0)) * 0
    for side, dx, dy, ang in ((-1, -0.1, 0.05, -0.1), (1, 0.1, -0.04, 0.09)):
        px, py = xf(x, y, dx, dy, ang)
        s = poly(sh, px, py) - 0.05
        edge = (px - zig(py)) * side * -1                  # >0 on this half's side of the crack
        sd = np.maximum(s, edge - 0.0)
        rim = np.abs(s + 0.07) - 0.022
        img = obj(img, sd, "#241a44", "#8a78d0", "#f0e8ff", 0.12, halo="#a060ff", halo_amt=0.35)
        img = over(img, mix(C("#8a6a30"), C("#f0d078"), np.clip(0.5 - px * 0.4 - py * 0.2, 0, 1)), smooth(np.maximum(rim, sd + 0.02)) * 0.9)
        boss = circle(0, -0.05, 0.14)
        img = over(img, mix(C("#5a4020"), C("#ffe090"), ss(0.15, -0.1, (px * 0.7 + py * 0.7))), smooth(np.maximum(boss, sd + 0.02)))
    img = add(img, C("#e8c8ff"), sparks(14, 681, (-0.2, -0.6, 0.2, 0.7), (0.004, 0.009)))
    return finish(img, 68, grade=(1.0, 0.96, 1.06))


@A("frozen")
def frozen():
    img = _bg("#04080e", "#0a1620", 590, "#4ab0ff", (0, 0), 0.8)
    hand = np.minimum(ellipse(0, 0.25, 0.3, 0.27), segment(-0.31, 0.3, -0.56, 0.02) - 0.085)
    for fx, ty in ((-0.27, -0.34), (-0.09, -0.58), (0.1, -0.6), (0.28, -0.4)):
        hand = smin(hand, segment(fx * 0.8, 0.12, fx * 1.1, ty) - 0.062, 0.04)
    ice = hand - 0.055
    img = obj(img, ice, "#1a4a70", "#c8ecff", "#ffffff", 0.14, halo="#6ac8ff", halo_amt=0.5, outline=0.035)
    img = add(img, C("#9ad8ff"), (0.2 + 0.3 * nz(5, 592)) * smooth(ice + 0.02) * 0.5)
    for i in range(3):                                          # icicles hanging from the wrist
        ix = -0.17 + i * 0.17
        ic = poly([(ix - 0.06, 0.5), (ix + 0.06, 0.5), (ix, 0.78 + 0.08 * (i % 2))])
        img = obj(img, ic, "#2a6a98", "#e8f8ff", "#ffffff", 0.06, outline=0.02)
    flesh = mix(C("#4a6a88"), C("#c8e0f0"), np.clip(0.4 + (-x - y) * 0.4, 0, 1))
    img = over(img, flesh, smooth(hand))
    img = add(img, C("#ffffff"), (nz(24, 593) > 0.55) * smooth(hand) * 0.35)
    cr = polyline([(-0.1, -0.5), (-0.02, -0.2), (0.12, -0.05), (0.05, 0.2), (0.22, 0.38)]) - 0.012
    img = over(img, C("#f4fdff"), smooth(cr) * smooth(ice))
    return finish(img, 59, grade=(0.95, 1.02, 1.07))


@A("silenced")
def silenced():
    img = _bg("#06060a", "#101018", 650, "#7a7ad0", (0, 0), 0.75)
    body = [(-0.15, -0.5), (0.15, -0.5), (0.22, -0.22), (0.3, 0.08), (0.42, 0.36), (0.48, 0.46), (-0.48, 0.46), (-0.42, 0.36), (-0.3, 0.08), (-0.22, -0.22)]
    b = poly(body) - 0.04
    img = obj(img, np.abs(circle(0, -0.62, 0.11)) - 0.035, "#2a2a48", "#a8a8e0", "#ffffff", 0.035, outline=0.025)
    img = obj(img, b, "#26264a", "#b0b0f0", "#ffffff", 0.2, halo="#8a8aff", halo_amt=0.3)
    img = over(img, C("#16163a"), smooth(np.abs(y - 0.3) - 0.012) * smooth(b + 0.03) * 0.8)
    # the gag: a cloth band wrapped across the mouth, knotted at the side, its ends hanging
    bandc = poly([(-0.5, 0.06), (0.5, 0.26), (0.5, 0.42), (-0.5, 0.22)])
    cloth = mix(C("#9a8a70"), C("#f0e4c8"), np.clip(0.55 + np.sin(x * 26 + y * 9) * 0.18 - y * 0.2, 0, 1))
    img = over(img, C("#050304"), smooth(bandc - 0.03) * 0.94)
    img = over(img, cloth, smooth(bandc))
    img = over(img, C("#5a4a34"), smooth(np.abs(bandc + 0.04) - 0.008) * 0.6)
    knot = circle(0.34, 0.33, 0.1)
    img = obj(img, knot, "#6a5a40", "#f4ead0", "#ffffff", 0.1, outline=0.025)
    for ex, ey in ((0.38, 0.52), (0.5, 0.48)):
        img = obj(img, poly([(ex - 0.05, 0.4), (ex + 0.05, 0.4), (ex + 0.03 + (ex - 0.4) * 0.2, ey + 0.2), (ex - 0.05, ey + 0.16)]), "#6a5a40", "#f0e4c8", "#ffffff", 0.05, outline=0.02)
    img = obj(img, circle(-0.0, 0.58, 0.06), "#4a4a70", "#c0c0f0", "#ffffff", 0.06, outline=0.02)
    return finish(img, 65, grade=(0.98, 0.98, 1.05))


@A("ember_scar")
def ember_scar():
    img = _bg("#080403", "#1a0905", 670, "#ff5a10", (0.25, -0.25), 0.7)
    # a branding iron, its face white-hot, a wisp of smoke
    hnd = segment(-0.7, 0.72, 0.02, 0.0) - 0.05
    img = obj(img, hnd, "#2a1a10", "#8a6a48", "#e8c898", 0.05, outline=0.025)
    ferrule = segment(-0.1, 0.12, 0.08, -0.06) - 0.08
    img = obj(img, ferrule, "#2a2420", "#7a7068", "#e0d8d0", 0.08, outline=0.025)
    face = circle(0.32, -0.32, 0.3)
    img = add(img, C("#ff5a10"), np.exp(-np.maximum(face, 0) / 0.14) * 0.9)
    img = obj(img, face, "#a02a08", "#ff9a30", "#fff0b0", 0.12, outline=0.03)
    sig = np.minimum(flame_sd(0.32, -0.2, 0.36, 0.14), np.abs(face + 0.07) - 0.025)
    img = over(img, C("#2a0804"), smooth(sig + 0.0) * 0.9)
    img = over(img, mix(C("#fff0c0"), C("#ffb040"), 0.4), smooth(circle(0.32, -0.32, 0.07)))
    img = add(img, C("#ffd070"), sparks(26, 671, (-0.1, -0.9, 0.9, 0.2), (0.003, 0.009)))
    smk = np.exp(-((x - 0.5 - 0.1 * np.sin(y * 6)) / 0.06) ** 2) * ss(-0.35, -0.9, y) * ss(-1.0, -0.6, y) * 0.35
    img = add(img, C("#c8a898"), smk)
    return finish(img, 67, grade=(1.06, 0.96, 0.9))


@A("tide")
def tide():
    img = _bg("#05040c", "#0c0a20", 550, "#5a40d0", (0, -0.1), 0.8)
    outer = poly([(-1.0, 0.5), (-0.85, 0.22), (-0.62, -0.12), (-0.38, -0.4), (-0.08, -0.6), (0.28, -0.66), (0.58, -0.5), (0.7, -0.2), (0.62, 0.14), (0.0, 0.5)]) - 0.04
    barrel = ellipse(0.42, 0.06, 0.46, 0.27)
    wave = np.minimum(np.maximum(outer, -barrel), -(y - 0.36 - 0.04 * np.sin(x * 8)))
    wc = mix(C("#1a1478"), C("#6a58f0"), np.clip(0.85 - (y + 0.6) * 0.8, 0, 1))
    img = add(img, C("#7a60ff"), np.exp(-np.maximum(wave, 0) / 0.1) * 0.5)
    img = over(img, C("#050304"), smooth(wave - 0.035) * 0.94)
    img = over(img, wc, smooth(wave))
    img = over(img, mix(C('#0a0646'), C('#3a2fb0'), ss(-0.2, 0.3, y)), smooth(barrel) * smooth(wave + 0.01))
    foam = np.exp(-(np.abs(outer + 0.03) / 0.14) ** 2) * ss(0.35, -0.45, y) * 2.2
    img = over(img, C("#f4f0ff"), np.clip(foam, 0, 1) * smooth(wave + 0.01) * 0.95)
    img = add(img, C("#c8c0ff"), np.exp(-(np.abs(barrel) / 0.025) ** 2) * smooth(wave + 0.02) * 0.6)
    for i in range(3):
        wl = np.abs(y - (0.5 + i * 0.14) - 0.03 * np.sin(x * 9 + i * 2)) - 0.012
        img = add(img, C("#b8b0ff"), smooth(wl) * smooth(wave + 0.02) * 0.5)
    img = add(img, C("#ffffff"), sparks(20, 551, (0.1, -0.95, 0.9, -0.3), (0.004, 0.012)))
    return finish(img, 55, grade=(0.98, 0.96, 1.08))


@A("quick")
def quick():
    img = _bg("#080604", "#1a0f06", 520, "#e0901c", (0.1, -0.05), 0.8)
    for i, yy in enumerate((-0.3, 0.12, 0.5)):                  # streaks behind
        img = add(img, C("#ffc060"), smooth(segment(-0.95, yy, -0.45 + i * 0.1, yy) - 0.014) * 0.5)
    far = poly([(0.08, 0.06), (0.0, 0.42), (-0.2, 0.66), (-0.27, 0.46), (-0.37, 0.54), (-0.38, 0.28), (-0.5, 0.3), (-0.3, 0.1)])
    near = poly([(0.14, -0.02), (0.04, -0.5), (-0.18, -0.86), (-0.27, -0.64), (-0.36, -0.74), (-0.4, -0.46), (-0.52, -0.54), (-0.5, -0.2), (-0.3, 0.04)])
    tail = poly([(-0.3, 0.0), (-0.78, -0.1), (-0.64, 0.05), (-0.8, 0.2), (-0.3, 0.12)])
    qx, qy = xf(x, y, 0, 0, -0.1, 0.0, 0.04)
    body = smin(ellipse(0.02, 0.04, 0.36, 0.12, qx, qy), circle(0.36, -0.01, 0.1), 0.06)
    beak = poly([(0.43, -0.05), (0.62, 0.01), (0.44, 0.03)])
    img = obj(img, far, "#6a3208", "#d8902c", "#ffe0a0", 0.12, halo="#ffa030", halo_amt=0.3)
    img = obj(img, tail, "#8a4410", "#f0b050", "#ffe8b0", 0.08, outline=0.025)
    img = obj(img, near, "#9a4a0c", "#ffe0a0", "#ffffff", 0.14, halo="#ffa030", halo_amt=0.4)
    img = obj(img, np.minimum(body, beak), "#a0500c", "#fff0c0", "#ffffff", 0.12, outline=0.03)
    img = over(img, C("#1a0a04"), smooth(circle(0.4, -0.03, 0.025)))
    return finish(img, 52, grade=(1.05, 0.97, 0.9))


def _sword(img, ang, cx, cy, steel=("#4a5078", "#d8dcf8"), glow="#a070ff"):
    blade = _rotpts([(-0.72, -0.075), (0.46, -0.075), (0.78, 0.0), (0.46, 0.075), (-0.72, 0.075)], ang, 0, 0)
    guard = _rotpts([(-0.76, -0.22), (-0.66, -0.22), (-0.66, 0.22), (-0.76, 0.22)], ang, 0, 0)
    sd = poly(blade)
    img = obj(img, sd, steel[0], steel[1], "#ffffff", 0.075, halo=glow, halo_amt=0.4, shine=18)
    fuller = polyline(_rotpts([(-0.6, 0.0), (0.4, 0.0)], ang)) - 0.012
    img = over(img, C("#202448"), smooth(fuller) * smooth(sd + 0.02) * 0.6)
    img = obj(img, poly(guard) - 0.02, "#5a3a10", "#e8c060", "#fff0b0", 0.05, outline=0.02)
    gx, gy = _rotpts([(-0.86, 0.0)], ang)[0]
    hx, hy = _rotpts([(-1.02, 0.0)], ang)[0]
    img = obj(img, segment(gx, gy, hx, hy) - 0.045, "#2a1a0a", "#8a6030", "#e0b070", 0.045, outline=0.02)
    return img


@A("riposte")
def riposte():
    img = _bg("#080410", "#150a22", 530, "#9a50ff", (0.0, 0.0), 0.65)
    img = _sword(img, -0.75, 0, 0)
    img = _sword(img, 0.75 + np.pi, 0, 0, steel=("#46486a", "#f0f0ff"))
    img = rays(img, 0, 0, 8, "#ffffff", 0.4, 40, 1.4)
    img = add(img, C("#fff0ff"), np.exp(-np.hypot(x, y) / 0.1) * 1.2)
    img = add(img, C("#ffe8ff"), sparks(16, 531, (-0.3, -0.3, 0.3, 0.3), (0.004, 0.012)))
    return finish(img, 53, grade=(1.02, 0.96, 1.06))


@A("chain")
def chain():
    img = _bg("#06040c", "#100a1e", 540, "#7a40e0", (0, 0), 0.8)
    for cx, cy, ang, thick in ((-0.42, 0.42, -0.78, True), (0.0, 0.0, -0.78 + np.pi * 0.5, False), (0.42, -0.42, -0.78, True)):
        u, v = rot(cx, cy, ang)
        if thick:
            sd = np.abs(stadium(0, 0, 0.3, 0.19, u, v)) - 0.065
        else:
            sd = stadium(0, 0, 0.3, 0.07, u, v) - 0.04
            img = obj(img, sd, "#2a2640", "#a8a0d8", "#ffffff", 0.07, halo="#8a50ff", halo_amt=0.4, outline=0.03)
            continue
        img = obj(img, sd, "#2a2640", "#b8b0e8", "#ffffff", 0.065, halo="#8a50ff", halo_amt=0.4, outline=0.03)
    img = add(img, C("#d0b8ff"), sparks(10, 541, (-0.6, -0.6, 0.6, 0.6), (0.004, 0.009)))
    return finish(img, 54, grade=(1.0, 0.96, 1.06))


@A("winded")
def winded():
    img = _bg("#06080c", "#0c1218", 560, "#4a88b0", (0, 0.05), 0.75)
    for sx in (-1, 1):
        px = x * sx
        lobe = ellipse(0.28, 0.12, 0.3, 0.5, *xf(px, y, 0, 0, -0.12, 0.28, 0.12))
        lobe = np.minimum(lobe, 1e9) + 0.0
        lobe = np.maximum(lobe, (0.01 - px) * 1.0 + 0.0) if False else lobe
        col_d, col_l = "#4a6a84", "#c8e4f4"
        img = obj(img, lobe, col_d, col_l, "#ffffff", 0.2, halo="#7ac0e8", halo_amt=0.3)
        for i in range(3):                                         # bronchi branches, dark lines
            by = -0.12 + i * 0.2
            br = segment(0.12, -0.12, 0.28, by + 0.05) if i else segment(0.1, -0.1, 0.27, 0.0)
            img = over(img, C("#2a4056"), smooth(br * 1.0 - 0.0 + np.where(sx == sx, 0, 0) - 0.0 + 0.0 * px) * 0 + 0.0)
        bron = np.minimum(segment(0.11, -0.2, 0.22, 0.0, px, y), segment(0.22, 0.0, 0.3, 0.3, px, y))
        bron = np.minimum(bron, segment(0.22, 0.0, 0.16, 0.2, px, y))
        img = over(img, C("#24394c"), smooth(bron - 0.012) * smooth(lobe + 0.01) * 0.8)
    trach = box(0, -0.38, 0.045, 0.2)
    img = obj(img, trach, "#4a6a84", "#d8ecf8", "#ffffff", 0.045, outline=0.025)
    img = over(img, C("#2a4056"), smooth(np.abs(((y + 0.6) * 22) % 2.0 - 1.0) * 0 + np.abs(((y * 24) % 2.0) - 1.0) * 0.04 - 0.015) * smooth(trach + 0.01) * 0.6)
    for i, (px_, py_, r) in enumerate(((-0.1, -0.72, 0.1), (0.14, -0.8, 0.13), (-0.02, -0.92, 0.08))):
        img = add(img, C("#b8dcf0"), np.exp(-(np.hypot(x - px_, y - py_) / r) ** 2) * 0.55)
    return finish(img, 56, grade=(0.96, 1.0, 1.05))


@A("rime")
def rime():
    img = _bg("#04080e", "#0a1620", 580, "#4ac0ff", (0, 0.2), 0.8)
    for ang, h, w, ox in ((-0.45, 0.6, 0.13, -0.28), (0.4, 0.66, 0.14, 0.3), (0.0, 0.92, 0.17, 0.0)):
        base = (ox * 0.5, 0.62)
        pts = _rotpts([(ox * 0.5 - w, 0.62), (ox * 0.5 - w, 0.62 - h * 0.7), (ox * 0.5, 0.62 - h), (ox * 0.5 + w, 0.62 - h * 0.7), (ox * 0.5 + w, 0.62)], ang, base[0], base[1])
        sd = poly(pts)
        img = obj(img, sd, "#1a5a88", "#d0f0ff", "#ffffff", 0.1, halo="#6ad0ff", halo_amt=0.5, outline=0.03)
        ridge = polyline(_rotpts([(ox * 0.5, 0.6), (ox * 0.5, 0.62 - h)], ang, base[0], base[1])) - 0.012
        img = add(img, C("#ffffff"), smooth(ridge) * smooth(sd + 0.01) * 0.5)
    img = add(img, C("#e8f8ff"), sparks(26, 581, (-0.7, -0.8, 0.7, 0.4), (0.004, 0.011)))
    return finish(img, 58, grade=(0.95, 1.02, 1.07))


@A("resonance")
def resonance():
    img = _bg("#080604", "#1a1208", 610, "#d0a040", (0, -0.1), 0.8)
    stem = box(0, 0.62, 0.05, 0.2)
    fork = np.minimum(box(-0.15, -0.2, 0.06, 0.4), box(0.15, -0.2, 0.06, 0.4))
    bend = np.maximum(np.abs(circle(0, 0.2, 0.15)) - 0.06, -(y - 0.2))
    fork = np.minimum(fork, np.maximum(np.abs(circle(0, 0.2, 0.15)) - 0.06, -(y - 0.2) * 1.0))
    tuner = smin(np.minimum(fork, bend), stem, 0.04)
    ring = np.abs(circle(0, 0.86, 0.06)) - 0.025
    img = obj(img, np.minimum(tuner, ring), "#6a4a14", "#ffe098", "#ffffff", 0.07, halo="#ffc040", halo_amt=0.5, outline=0.03, shine=14)
    ang = np.arctan2(y + 0.2, x)
    r = np.hypot(x, y + 0.2)
    for k, rad in enumerate((0.55, 0.72, 0.88)):
        d = np.abs(r - rad) - 0.018
        side = ss(0.7, 0.25, np.abs(np.sin(ang))) * ss(0.95, 0.5, 1 - np.abs(y + 0.2) * 1.0)
        img = add(img, C("#ffd070"), smooth(d) * side * (0.85 - 0.2 * k) * (np.abs(x) > 0.3))
    return finish(img, 61, grade=(1.05, 0.98, 0.9))


@A("surge")
def surge():
    img = _bg("#06040c", "#0e0a22", 620, "#6a40f0", (0.1, 0.3), 0.7)
    cloud = circle(-0.34, -0.2, 0.25)
    for cx, cy, r in ((0.0, -0.36, 0.34), (0.36, -0.18, 0.27), (-0.08, -0.12, 0.3)):
        cloud = smin(cloud, circle(cx, cy, r), 0.07)
    cloud = smin(cloud, box(0.0, -0.06, 0.5, 0.12), 0.07)
    img = obj(img, cloud, "#14102c", "#6a62b8", "#c8c0ff", 0.25, halo="#7a50ff", halo_amt=0.4)
    bolt = poly([(0.14, -0.02), (-0.2, 0.34), (-0.01, 0.34), (-0.24, 0.86), (0.3, 0.2), (0.08, 0.2), (0.32, -0.02)])
    img = add(img, C("#a888ff"), np.exp(-np.maximum(bolt, 0) / 0.08) * 0.9)
    img = obj(img, bolt, "#c8a020", "#fff6b0", "#ffffff", 0.08, outline=0.025)
    return finish(img, 62, grade=(1.0, 0.96, 1.06))


@A("shaken")
def shaken():
    img = _bg("#0a0405", "#1a0a0c", 630, "#d04a40", (0, 0.1), 0.8)
    px, py = warp(0.07, 3.0, 631)
    rock = ellipse(0.0, 0.0, 0.58, 0.5, px, py)
    crackline = polyline([(-0.05, -0.55), (0.06, -0.3), (-0.08, -0.08), (0.1, 0.18), (-0.02, 0.55)]) - 0.025
    halves = ((-1, -0.05), (1, 0.05))
    for sgn, dx in halves:
        qx, qy = xf(px, py, dx, 0.0, sgn * 0.05)
        r2 = ellipse(0.0, 0.0, 0.58, 0.5, qx, qy)
        cut = (qx - 0.0 - 0.03 * np.sin(qy * 11)) * -sgn
        sd = np.maximum(r2, -cut * -1 if False else cut)
        img = obj(img, sd, "#2a1210", "#9a6a58", "#ffd8c0", 0.16, halo="#ff5a40", halo_amt=0.35, texture=0.5, seed=632)
    img = add(img, C("#ff7a50"), np.exp(-np.abs(crackline) / 0.03) * smooth(rock + 0.02) * 0.9)
    for i, (cx, cy, r) in enumerate(((-0.55, 0.62, 0.08), (0.5, 0.7, 0.07), (0.15, 0.82, 0.06), (-0.25, 0.78, 0.05))):
        img = obj(img, poly(_rotpts([(cx - r, cy - r), (cx + r, cy - r * 0.6), (cx + r * 0.6, cy + r), (cx - r * 0.8, cy + r * 0.7)], i)), "#2a1210", "#a07060", "#ffd8c0", 0.05, outline=0.02)
    img = add(img, C("#ff8a60"), sparks(14, 633, (-0.5, -0.5, 0.5, 0.5), (0.003, 0.008)))
    return finish(img, 63, grade=(1.06, 0.95, 0.94))


@A("broken")
def broken():
    img = _bg("#0a0605", "#1a110c", 640, "#ff7a2a", (0.0, 0.0), 0.5)
    a = -0.75
    low = _rotpts([(-0.55, -0.08), (-0.02, -0.08), (0.06, -0.02), (-0.04, 0.03), (0.08, 0.08), (-0.55, 0.08)], a)
    img = add(img, C("#ff7a2a"), np.exp(-np.hypot(x, y) / 0.18) * 1.0)
    img = obj(img, poly(low), "#3a4054", "#d0d4e0", "#ffffff", 0.08, halo="#ff7a2a", halo_amt=0.3, shine=18)
    guard = _rotpts([(-0.62, -0.24), (-0.52, -0.24), (-0.52, 0.24), (-0.62, 0.24)], a)
    img = obj(img, poly(guard) - 0.02, "#5a3a10", "#e8c060", "#fff0b0", 0.05, outline=0.02)
    gx, gy = _rotpts([(-0.7, 0.0)], a)[0]
    hx, hy = _rotpts([(-0.88, 0.0)], a)[0]
    img = obj(img, segment(gx, gy, hx, hy) - 0.045, "#2a1a0a", "#8a6030", "#e0b070", 0.045, outline=0.02)
    tip = _rotpts([(0.2, -0.075), (0.46, -0.075), (0.8, 0.0), (0.46, 0.075), (0.3, 0.07), (0.22, 0.01)], a)
    tip = [(px_ + 0.06, py_ - 0.05) for px_, py_ in _rotpts([(0.2, -0.075), (0.46, -0.075), (0.8, 0.0), (0.46, 0.075), (0.3, 0.07), (0.22, 0.01)], a - 0.12)]
    img = obj(img, poly(tip), "#3a4054", "#d0d4e0", "#ffffff", 0.08, halo="#ff7a2a", halo_amt=0.3, shine=18)
    img = add(img, C("#ffd89a"), sparks(18, 641, (-0.2, -0.3, 0.4, 0.3), (0.003, 0.009)))
    return finish(img, 64, grade=(1.05, 0.97, 0.92))


@A("mark")
def mark():
    img = _bg("#080410", "#150a22", 660, "#a040e0", (0, 0), 0.7)
    for i in range(14):                                        # lines of sight, radiating
        a = i * np.pi * 2 / 14
        img = add(img, C("#d090ff"), smooth(segment(0.78 * np.cos(a), 0.78 * np.sin(a), 0.98 * np.cos(a), 0.98 * np.sin(a)) - 0.012) * 0.7)
    eye = np.maximum(circle(0, 0.62, 0.92), circle(0, -0.62, 0.92))
    img = add(img, C("#a040e0"), np.exp(-np.maximum(eye, 0) / 0.1) * 0.8)
    img = obj(img, eye, "#3a2858", "#e8dcff", "#ffffff", 0.14, outline=0.04)
    sclera = mix(C("#8a7aa8"), C("#f6eeff"), np.clip(0.6 - y * 0.5 * np.sign(y) - 0.2 + (1 - np.abs(x)) * 0.2, 0, 1))
    img = over(img, sclera, smooth(eye + 0.05))
    iris = circle(0, 0, 0.3)
    img = over(img, mix(C("#3a0a70"), C("#d070ff"), np.clip(np.hypot(x, y) / 0.3, 0, 1) ** 1.5), smooth(iris) * smooth(eye + 0.04))
    img = over(img, C("#080210"), smooth(circle(0, 0, 0.12)))
    img = over(img, C("#ffffff"), smooth(circle(-0.09, -0.1, 0.045)))
    img = add(img, C("#40205a"), smooth(np.abs(eye + 0.05) - 0.03) * 0.5)
    return finish(img, 66, grade=(1.02, 0.95, 1.07))


@A("ward")
def ward():
    img = _bg("#060608", "#120d08", 510, "#e08a28", (0, 0.15), 0.8)
    bub = circle(0, 0.0, 0.7)
    img = add(img, C("#ffb347"), np.exp(-np.maximum(bub, 0) / 0.09) * 0.7)
    img = over(img, C("#050304"), smooth(bub - 0.035) * 0.94)
    inner = mix(C("#6a3410"), C("#2a1408"), np.clip(np.hypot(x, y) / 0.7, 0, 1))
    img = over(img, inner, smooth(bub))
    img = fire(img, 0.0, 0.42, 0.78, 0.3, 511, strength=1.1)
    rim = np.abs(bub + 0.02) - 0.03
    img = add(img, C("#ffc766"), smooth(rim) * 0.9)
    img = add(img, C("#fff0c0"), smooth(np.abs(circle(0, 0, 0.55)) - 0.03) * ss(-0.1, -0.7, x * 0.7 + y * 0.7) * ss(-0.1, -0.7, -x * 0.7 + y * 0.7) * 0.8 * 0 + (smooth(np.abs(circle(0, 0, 0.55)) - 0.035) * ((np.arctan2(y, x) < -1.6) & (np.arctan2(y, x) > -2.7)) * 0.85))
    img = obj(img, box(0, 0.78, 0.4, 0.06) - 0.01, "#2a1608", "#9a6a30", "#ffe0a0", 0.06, outline=0.02)
    return finish(img, 51, grade=(1.05, 0.97, 0.9))
