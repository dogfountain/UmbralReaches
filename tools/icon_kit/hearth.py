"""Hearth icons: the Keg's and Bet's food and drink, Hild's works, the tithes and the four trades.
Category "hearth", id = the HearthDB id (services are svc_<id>)."""
import numpy as np

from objects import *  # noqa: F401,F403
from registry import recipe
from items_relics import G


def H(name):
    return recipe("hearth", name)


def board(img, seed, cy=0.5, amt=1.0):
    b = box(0, cy, 0.85, 0.2)
    return piece(img, b, "#1e1008", "#6a4426", "#d8b080", 0.1, tex=grain(x, y, seed, 2.5, 26.0, 0.9), relief=0.5)


@H("bread")
def bread():
    img = G("#0a0706", "#17100b", 800, "#c07a30", (0, 0.1), 0.9, "#3a2412")
    img = board(img, 801, 0.5)
    wx, wy = warp(0.02, 5, 802)
    loaf = ellipse(0, 0.12, 0.66, 0.42, wx, wy)
    Z = np.clip(-loaf / 0.4, 0, 1) ** 0.6 + 0.15 * nz(30, 803, octaves=3)
    img = heightlit(Z, loaf, "#1c0e06", "#a8692c", "#ffe0a0", img, k=70, tex=0.7 + 0.6 * nz(44, 804, octaves=3), shine=10.0)
    # scores across the crust, flour dusting and a pat of dripping beside it
    for sx in (-0.3, -0.05, 0.2):
        s = polyline([(sx - 0.1, 0.22), (sx + 0.02, -0.12)])
        img = over(img, C("#e8c88a"), smooth(s - 0.02) * smooth(loaf + 0.04) * 0.55)
        img = over(img, C("#3a1c08"), smooth(s - 0.008) * smooth(loaf + 0.04) * 0.5)
    img = add(img, C("#f4eee0"), sparks(40, 805, (-0.5, -0.2, 0.5, 0.4), (0.003, 0.006)) * 0.45 * smooth(loaf)[..., None][..., 0])
    dish = ellipse(0.68, 0.5, 0.2, 0.1)
    img = piece(img, dish, "#3a2a18", "#a08060", "#ffffff", 0.1)
    img = piece(img, ellipse(0.68, 0.49, 0.15, 0.06), "#a89860", "#f8ecb8", "#ffffff", 0.06, shadowed=False)
    return finish(img, 80, exposure=1.4, grade=(1.05, 0.98, 0.92))


@H("stew")
def stew():
    img = G("#09070a", "#160f0c", 810, "#b8622a", (0, 0.1), 0.85, "#3a2214")
    img = floor_shadow(img, 0, 0.58, 0.8, 0.1, 0.55)
    bowl = ellipse(0, 0.08, 0.72, 0.5)
    img = piece(img, bowl, "#1a0e08", "#7a4a2a", "#e8c8a0", 0.3, tex=0.8 + 0.4 * nz(30, 811), shine=14.0)
    surface = ellipse(0, 0.0, 0.58, 0.36)
    img = over(img, mix(C("#2a1408"), C("#8a4a1c"), ss(-0.4, 0.4, y + 0.0 * x) * (0.6 + 0.5 * nz(10, 812))), smooth(surface))
    img = add(img, C("#ffc070"), np.exp(-(np.hypot(x + 0.15, y + 0.05) / 0.2) ** 2) * smooth(surface) * 0.25)
    # chunks of eel curled in the broth, and green flecks
    for (cx, cy, a) in [(-0.25, 0.0, 0.2), (0.15, -0.06, -0.5), (0.28, 0.1, 0.9), (-0.05, 0.1, -0.2)]:
        curl = path_t(curve(lambda t, a=a: (cx + 0.1 * np.cos(a + t * 5.0), cy + 0.055 * np.sin(a + t * 5.0)), 12))[0]
        img = piece(img, curl - 0.03, "#5a4a30", "#e8dcc0", "#ffffff", 0.03, shadowed=False)
    img = add(img, C("#5a8a3a"), sparks(26, 813, (-0.45, -0.2, 0.45, 0.2), (0.004, 0.008)) * 0.7 * smooth(surface))
    img = piece(img, np.abs(surface) - 0.012, "#2a1a10", "#a87848", "#f0d0a0", 0.012, shadowed=False)
    img = steam(img, 0.0, -0.1, -0.85, 814, 0.28, "#ffe8c8", 3, 0.2)
    return finish(img, 81, exposure=1.4, grade=(1.05, 0.98, 0.92))


@H("mulled")
def mulled():
    img = G("#09060a", "#170b0a", 820, "#d0501a", (0, 0.1), 0.9, "#3a1810")
    img = floor_shadow(img, 0, 0.72, 0.6, 0.08, 0.55)
    img = tankard(img, -0.04, 0.12, 1.2, 821, True, "#ff6a20")
    img = steam(img, -0.04, -0.4, -0.9, 822, 0.3, "#ffd8b0", 3, 0.15)
    # a cinnamon stick and a star anise leaning on it
    stick = stadium(0, 0, 0.26, 0.034, *rot(0.52, 0.66, -0.8))
    img = piece(img, stick, "#3a1a0a", "#a8602a", "#ffd0a0", 0.034, tex=grain(x, y, 823, 4, 40, 0.7))
    pts = []
    for k in range(16):
        a = k * np.pi / 8
        r = 0.1 if k % 2 == 0 else 0.04
        pts.append((-0.62 + r * np.cos(a), 0.7 + r * np.sin(a)))
    img = piece(img, poly(pts), "#2a1004", "#8a4a22", "#e0a060", 0.05)
    img = add(img, C("#ffa050"), sparks(12, 824, (-0.4, -0.8, 0.4, -0.2), (0.003, 0.006)) * 0.6)
    return finish(img, 82, exposure=1.4, grade=(1.06, 0.97, 0.9))


@H("honey")
def honey():
    img = G("#0a0708", "#170e0a", 830, "#d8901f", (0, 0.0), 0.9, "#3a2410")
    img = floor_shadow(img, 0, 0.62, 0.8, 0.1, 0.55)
    side = box(0, 0.22, 0.68, 0.22)
    top = ellipse(0, 0.0, 0.7, 0.34)
    img = piece(img, np.minimum(side, ellipse(0, 0.22, 0.68, 0.34)), "#3a1c08", "#c07a30", "#ffe0a0", 0.18, tex=0.8 + 0.4 * nz(40, 831), shine=10.0)
    img = piece(img, top, "#7a3a08", "#f0b030", "#fff4c0", 0.3, shine=40.0, glowc="#ffc040", glowamt=0.25, shadowed=False)
    # honey running over the edge
    for dx, ln in ((-0.4, 0.2), (-0.1, 0.32), (0.3, 0.24), (0.52, 0.12)):
        dr = stadium(dx, 0.2 + ln * 0.5, 0.05, ln * 0.5 + 0.0, *rot(dx, 0.2 + ln * 0.5, np.pi / 2)) if False else box(dx, 0.22 + ln * 0.4, 0.045, ln * 0.5)
        img = piece(img, dr, "#8a4a08", "#f0b030", "#fff4c0", 0.045, shadowed=False, shine=40.0)
    # bramble berries on top
    for (bx, by) in [(-0.2, -0.08), (0.05, -0.16), (0.22, -0.04), (-0.02, 0.04), (0.38, -0.12)]:
        for (ox, oy) in [(0, 0), (-0.035, 0.03), (0.035, 0.03), (0, -0.04)]:
            img = piece(img, circle(bx + ox, by + oy, 0.034), "#14061c", "#6a2a8a", "#e0b8ff", 0.034, shadowed=(ox == 0 and oy == 0))
    return finish(img, 83, exposure=1.4, grade=(1.06, 0.98, 0.9))


@H("feverfew")
def feverfew():
    img = G("#08090a", "#101410", 840, "#8ab04a", (0, 0.05), 0.85, "#26301a")
    img = floor_shadow(img, 0.1, 0.7, 0.6, 0.08, 0.5)
    body = poly([(-0.2, 0.0), (-0.36, 0.3), (-0.34, 0.66), (0.28, 0.66), (0.3, 0.3), (0.14, 0.0), (0.14, -0.3), (-0.2, -0.3)])
    wx, wy = warp(0.008, 7, 841)
    body = poly([(-0.2, 0.0), (-0.36, 0.3), (-0.34, 0.66), (0.28, 0.66), (0.3, 0.3), (0.14, 0.0), (0.14, -0.3), (-0.2, -0.3)], wx, wy)
    liquid = np.maximum(body, -(y - 0.1) * 1.0 - 0.0 * x)
    img = over(img, mix(C("#5a6a20"), C("#b8c850"), ss(0.1, 0.65, y)), smooth(body) * smooth(y - 0.12) * 0.85)
    img = glass(img, body, "#a8b868", "#e8f4b0", amt=0.14, hi=1.2)
    img = piece(img, poly([(-0.2, -0.5), (0.15, -0.5), (0.17, -0.28), (-0.22, -0.28)]), "#3a2410", "#c89a5a", "#ffe8c0", 0.1, tex=0.8 + 0.5 * nz(60, 842))
    # feverfew: little white daisies on a leafy sprig lying across the front
    sprig = curve(lambda t: (-0.85 + 1.0 * t, 0.7 - 0.28 * t + 0.05 * np.sin(t * 9)), 30)
    img = cord_path(sprig, 0.018, "#0e1a08", "#4a7a28", 843, img, 40.0, shadowed=False)
    for (fx, fy) in [(-0.7, 0.66), (-0.45, 0.6), (-0.2, 0.55), (-0.08, 0.5)]:
        for k in range(8):
            a = k * np.pi / 4
            pet = circle(fx + 0.052 * np.cos(a), fy + 0.052 * np.sin(a), 0.03)
            img = piece(img, pet, "#8a8a7a", "#fafaf0", "#ffffff", 0.03, shadowed=False)
        img = piece(img, circle(fx, fy, 0.03), "#a07a10", "#ffd040", "#fff0a0", 0.03, shadowed=False)
    return finish(img, 84, exposure=1.4, grade=(1.0, 1.02, 0.96))


@H("rue")
def rue():
    img = G("#06090a", "#0d1412", 850, "#4a8a8a", (0, 0.0), 0.85, "#1a3030")
    img = floor_shadow(img, 0, 0.8, 0.5, 0.06, 0.4)
    rng = np.random.default_rng(851)
    stems = []
    for i in range(7):
        a = -0.65 + i * 0.22
        tip = (np.sin(a) * 0.62, -0.55 - 0.1 * np.cos(a * 3))
        stems.append(curve(lambda t, a=a, tip=tip: (tip[0] * t ** 1.3 * 1.0 + 0.0, 0.72 + (tip[1] - 0.72) * t), 20))
    for i, st in enumerate(stems):
        img = cord_path(st, 0.018, "#0a1810", "#4a7a58", 852 + i, img, 30.0)
        for j in range(9, 20, 2):
            px_, py_ = st[j]
            for sx in (-1, 1):
                lf = ellipse(px_ + sx * 0.05, py_ - 0.01, 0.06, 0.035)
                img = piece(img, lf, "#0a2018", "#5aa088" if (i + j) % 2 else "#4a8a78", "#c8f4e4", 0.035, shadowed=False)
        px_, py_ = st[-1]
        img = piece(img, circle(px_, py_ - 0.03, 0.045), "#6a6a10", "#d8d048", "#fffbd0", 0.045, shadowed=False)
    # the bundle's twine and cut ends
    band = np.abs(ellipse(0.0, 0.5, 0.14, 0.05)) - 0.025
    img = piece(img, band, "#2a1c0e", "#a07a4a", "#ffffff", 0.025)
    for tx, ty in [(0.1, 0.55), (-0.1, 0.55)]:
        pass
    img = piece(img, polyline([(0.0, 0.52), (0.12, 0.66)]) - 0.02, "#2a1c0e", "#a07a4a", "#ffffff", 0.02, shadowed=False)
    img = piece(img, polyline([(0.0, 0.52), (-0.1, 0.68)]) - 0.02, "#2a1c0e", "#a07a4a", "#ffffff", 0.02, shadowed=False)
    return finish(img, 85, exposure=1.4, grade=(0.97, 1.02, 1.02))


@H("posset")
def posset():
    img = G("#07060b", "#110e18", 860, "#9a80e0", (0, 0.1), 0.85, "#2a2448")
    img = floor_shadow(img, 0, 0.62, 0.7, 0.08, 0.55)
    cup = poly([(-0.46, -0.12), (0.46, -0.12), (0.38, 0.42), (0.22, 0.58), (-0.22, 0.58), (-0.38, 0.42)])
    handle = np.abs(ellipse(0.5, 0.2, 0.2, 0.22)) - 0.045
    handle = np.maximum(handle, -(x - 0.4))
    img = piece(img, handle, "#2a1a10", "#9a7a56", "#f0d8b0", 0.045)
    img = piece(img, cup, "#2a1a10", "#a88860", "#f0d8b0", 0.3, tex=0.85 + 0.3 * nz(30, 861), shine=18.0)
    rim = ellipse(0, -0.12, 0.46, 0.12)
    img = piece(img, rim, "#2a1a10", "#a88860", "#f0d8b0", 0.06, shadowed=False)
    milk = ellipse(0, -0.12, 0.4, 0.085)
    img = over(img, mix(C("#c8c0e8"), C("#f6f2ff"), ss(-0.3, 0.2, x)), smooth(milk))
    img = add(img, C("#b8a0ff"), np.exp(-(np.hypot(x, y + 0.12) / 0.4) ** 2) * 0.25 * smooth(milk))
    # a pale bloom floating on it, faintly lit from inside
    for k in range(6):
        a = k * np.pi / 3
        pet = ellipse(0.1 + 0.07 * np.cos(a), -0.12 + 0.035 * np.sin(a), 0.055, 0.022)
        img = piece(img, pet, "#6a6688", "#f0eeff", "#ffffff", 0.02, shadowed=False, glowc="#b8a8ff", glowamt=0.4)
    img = piece(img, circle(0.1, -0.12, 0.016), "#6a2a10", "#ff9a3a", "#fff0c0", 0.016, shadowed=False)
    img = steam(img, 0.0, -0.2, -0.8, 862, 0.22, "#e8e0ff", 3, 0.16)
    img = add(img, C("#c8b8ff"), sparks(12, 863, (-0.5, -0.8, 0.5, -0.1), (0.003, 0.006)) * 0.6)
    return finish(img, 86, exposure=1.4, grade=(1.0, 0.98, 1.05))


@H("bloomcake")
def bloomcake():
    img = G("#09070a", "#16100c", 870, "#d8a050", (0, 0.0), 0.9, "#3a2a18")
    img = floor_shadow(img, 0, 0.58, 0.8, 0.1, 0.55)
    wx, wy = warp(0.015, 6, 871)
    cake = ellipse(0, 0.08, 0.76, 0.52, wx, wy)
    Z = np.clip(-cake / 0.4, 0, 1) ** 0.5 + 0.1 * nz(40, 872, octaves=3)
    img = heightlit(Z, cake, "#2a1408", "#c88a3c", "#fff0c0", img, k=60, tex=0.75 + 0.5 * nz(40, 873, octaves=3), shine=12.0)
    # a spiral of honey and pale blooms pressed in
    sp = curve(lambda t: (0.5 * t * np.cos(t * 14.0) * 1.2, 0.08 + 0.34 * t * np.sin(t * 14.0) * 1.2), 160)
    d = path_t(sp)[0]
    img = add(img, C("#ffc040"), smooth(d - 0.018) * smooth(cake + 0.05) * 0.8)
    img = add(img, C("#fff4b0"), np.exp(-(np.abs(d + 0.0) / 0.01) ** 2) * smooth(cake + 0.05) * 0.3)
    for (bx, by, a) in [(-0.38, 0.0, 0.3), (0.3, -0.06, 1.0), (0.04, 0.3, 0.1), (-0.1, -0.2, 0.6)]:
        for k in range(5):
            aa = a + k * 2 * np.pi / 5
            pet = ellipse(bx + 0.06 * np.cos(aa), by + 0.04 * np.sin(aa), 0.06, 0.03, *rot(bx + 0.06 * np.cos(aa), by + 0.04 * np.sin(aa), aa * 0.5))
            img = piece(img, pet, "#6a6688", "#f2eeff", "#ffffff", 0.03, shadowed=False, glowc="#b8a8ff", glowamt=0.3)
        img = piece(img, circle(bx, by, 0.022), "#6a2a10", "#ff9a3a", "#fff0c0", 0.022, shadowed=False)
    return finish(img, 87, exposure=1.4, grade=(1.05, 0.98, 0.93))


@H("baskets")
def baskets():
    img = G("#09060a", "#170a08", 880, "#e0601a", (0, -0.1), 0.9, "#3a1a10")
    img = floor_shadow(img, 0, 0.78, 0.55, 0.07, 0.55)
    img = flame(img, 0.0, -0.1, 0.9, 0.3, 881, strength=1.2)
    # cage of iron bars, round bellied, on three legs
    top = np.abs(ellipse(0, -0.12, 0.46, 0.1)) - 0.03
    img = piece(img, top, "#0c0a0a", "#5a5654", "#f0eeee", 0.03, shadowed=False)
    for i in range(-3, 4):
        bx = i * 0.14
        bar = curve(lambda t, bx=bx: (bx * (1 + 0.5 * np.sin(t * np.pi)) * (1 - 0.55 * t), -0.12 + 0.62 * t), 14)
        d = path_t(bar)[0]
        img = piece(img, d - 0.028, "#0c0a0a", "#6a6664", "#f0eeee", 0.028, shadowed=False)
    img = add(img, C("#ff6a18"), np.exp(-(np.hypot(x / 0.4, (y - 0.2) / 0.3)) ** 2) * 0.35 * (y > -0.1))
    base = np.abs(ellipse(0, 0.5, 0.22, 0.06)) - 0.03
    img = piece(img, base, "#0c0a0a", "#5a5654", "#f0eeee", 0.03, shadowed=False)
    for lx, ex in ((-0.3, -0.42), (0.0, 0.0), (0.3, 0.42)):
        leg = polyline([(lx * 0.8, 0.4), (ex, 0.78)])
        img = piece(img, leg - 0.03, "#0c0a0a", "#5a5654", "#f0eeee", 0.03, shadowed=False)
    img = add(img, C("#ffa050"), sparks(24, 882, (-0.5, -0.9, 0.5, 0.0), (0.003, 0.007)) * 0.8)
    return finish(img, 88, exposure=1.4, grade=(1.06, 0.96, 0.9))


@H("bellows")
def bellows():
    img = G("#08070a", "#150e0a", 890, "#c0701c", (0.0, 0.0), 0.9, "#3a2010")
    img = floor_shadow(img, 0, 0.72, 0.8, 0.08, 0.5)
    # side view: a fixed lower board, a hinged upper board, folded leather between them, a nozzle at the left
    lo = [(-0.5, 0.42), (0.58, 0.42), (0.58, 0.56), (-0.5, 0.56)]
    up = [(-0.5, -0.2), (0.62, -0.58), (0.7, -0.44), (-0.5, -0.04)]
    nozzle = poly([(-0.5, 0.18), (-0.5, 0.3), (-0.92, 0.28), (-0.92, 0.22)])
    img = piece(img, nozzle, "#0c0a0a", "#6a6664", "#f0eeee", 0.06, tex=rough(891, 18))
    handle = stadium(0, 0, 0.22, 0.04, *rot(0.8, -0.6, -0.4))
    img = piece(img, handle, "#241408", "#8a5a30", "#e8c090", 0.04, tex=grain(x, y, 892, 3, 30, 0.8))
    leather = poly([(-0.5, -0.04), (0.62, -0.44), (0.58, 0.42), (-0.5, 0.42)])
    img = piece(img, leather, "#2a1006", "#9a5a2a", "#f0b890", 0.2, tex=0.8 + 0.4 * nz(50, 893), shine=10.0)
    for k in range(1, 6):
        t = k / 6.0
        fy0 = -0.04 + t * 0.46
        fy1 = -0.44 + t * 0.86
        fold = polyline([(-0.5, fy0), (0.62 - 0.04 * t, fy1)])
        img = over(img, C("#1a0a04"), smooth(fold - 0.014) * smooth(leather) * 0.75)
        img = add(img, C("#f0b890"), smooth(np.roll(fold, 3, 0) - 0.01) * smooth(leather) * 0.3)
    img = piece(img, poly(lo), "#2a1608", "#9a6a38", "#f0d0a0", 0.07, tex=grain(x, y, 894, 3, 30, 0.8))
    img = piece(img, poly(up), "#2a1608", "#9a6a38", "#f0d0a0", 0.07, tex=grain(x, y, 895, 3, 30, 0.8))
    for rx, ry in ((-0.38, 0.49), (0.46, 0.49), (-0.38, -0.12)):
        img = piece(img, circle(rx, ry, 0.025), "#161616", "#c8c8c8", "#ffffff", 0.025, shadowed=False)
    img = add(img, C("#ffd8a0"), np.exp(-(np.hypot(x + 1.0, y - 0.25) / 0.1) ** 2) * 0.25)
    return finish(img, 89, exposure=1.4, grade=(1.05, 0.98, 0.92))


@H("ferrule_iron")
def ferrule_iron():
    img = G("#070709", "#0f0e14", 900, "#7a5ad0", (0, -0.4), 0.8, "#2a2450")
    img = floor_shadow(img, 0, 0.8, 0.3, 0.05, 0.4)
    shaft = box(0, 0.35, 0.09, 0.5)
    img = piece(img, shaft, "#241408", "#7a5230", "#e0b888", 0.09, tex=grain(y, x, 901, 3.0, 40.0, 0.9))
    # the iron band under the orb, bright from the anvil
    band = poly([(-0.2, -0.04), (0.2, -0.04), (0.14, 0.2), (-0.14, 0.2)])
    img = piece(img, band, "#0c0c10", "#9a9aa8", "#ffffff", 0.14, tex=0.8 + 0.4 * nz(50, 902), shine=30.0)
    for rx in (-0.08, 0.08):
        img = piece(img, circle(rx, 0.08, 0.022), "#16161a", "#c8c8d4", "#ffffff", 0.022, shadowed=False)
    for cl in (-1, 1):
        claw = curve(lambda t, s=cl: (s * (0.2 - 0.05 * np.sin(t * 3)), -0.04 - 0.34 * t), 12)
        d = path_t(claw)[0]
        img = piece(img, d - 0.025, "#0c0c10", "#a0a0b0", "#ffffff", 0.025, shadowed=False)
    img = bloom_light(img, 0, -0.42, 0.4, "#9a7aff", 0.5)
    img = piece(img, circle(0, -0.42, 0.22), "#2a1a60", "#a98bff", "#ffffff", 0.22, glowc="#7a5aff", glowamt=0.8, shadowed=False)
    img = add(img, C("#ffffff"), np.exp(-np.hypot(x + 0.06, y + 0.5) / 0.05) * 0.8)
    img = add(img, C("#6a8aff"), np.exp(-(np.abs(y - 0.06) / 0.05) ** 2) * smooth(band) * 0.25)
    img = add(img, C("#c8b8ff"), sparks(16, 903, (-0.5, -0.9, 0.5, 0.1), (0.003, 0.006)) * 0.7)
    return finish(img, 90, exposure=1.4, grade=(0.99, 0.98, 1.05))


@H("grate")
def grate():
    img = G("#09060a", "#170a08", 910, "#e0601a", (0, -0.1), 0.9, "#3a1a10")
    img = floor_shadow(img, 0, 0.74, 0.8, 0.07, 0.55)
    # coals under the grate, flames over it
    img = add(img, C("#ff4a0c"), np.exp(-(np.hypot(x / 0.7, (y - 0.5) / 0.2)) ** 2) * 0.8)
    img = flame(img, -0.2, 0.1, 0.8, 0.22, 911, lean=-0.05)
    img = flame(img, 0.2, 0.12, 0.65, 0.2, 912, lean=0.08)
    frame = np.abs(box(0, 0.35, 0.74, 0.17)) - 0.035
    img = piece(img, frame, "#0c0a0a", "#5a5654", "#f0eeee", 0.035)
    for i in range(-5, 6):
        bar = box(i * 0.13, 0.35, 0.024, 0.17)
        img = piece(img, bar, "#0c0a0a", "#6a6664", "#f0eeee", 0.024, shadowed=False)
    for fx in (-0.74, 0.74):
        img = piece(img, box(fx, 0.62, 0.04, 0.14), "#0c0a0a", "#5a5654", "#f0eeee", 0.04, shadowed=False)
    img = add(img, C("#ffa050"), sparks(30, 913, (-0.6, -0.9, 0.6, 0.3), (0.003, 0.007)) * 0.85)
    return finish(img, 91, exposure=1.4, grade=(1.06, 0.96, 0.9))


@H("fire_dogs")
def fire_dogs():
    img = G("#09060a", "#170a08", 920, "#d8501a", (0, 0.1), 0.9, "#3a1a10")
    img = floor_shadow(img, 0, 0.76, 0.85, 0.07, 0.55)
    for sx in (-0.52, 0.52):
        post = box(sx, 0.1, 0.05, 0.5)
        img = piece(img, post, "#0a0808", "#5a4a44", "#d8c8c0", 0.05, tex=0.7 + 0.5 * nz(50, 921), shine=30.0)
        img = piece(img, circle(sx, -0.46, 0.09), "#0a0808", "#6a5a54", "#ffffff", 0.09, tex=0.7 + 0.5 * nz(50, 922))
        foot = poly([(sx - 0.14 * np.sign(sx), 0.72), (sx + 0.14 * np.sign(sx), 0.72), (sx, 0.55)])
        img = piece(img, foot, "#0a0808", "#5a4a44", "#d8c8c0", 0.06, shadowed=False)
        img = piece(img, box(sx, 0.7, 0.14, 0.04), "#0a0808", "#5a4a44", "#d8c8c0", 0.04, shadowed=False)
    # a split log lying across them, red-hot underneath
    log = stadium(0, -0.2, 0.7, 0.14)
    img = add(img, C("#ff4a0c"), np.exp(-np.maximum(log, 0) / 0.1) * 0.5)
    img = piece(img, log, "#120804", "#5a3a22", "#d8a070", 0.14, tex=grain(x, y, 923, 4, 34, 1.0), glowc="#ff4a10", glowamt=0.6)
    img = flame(img, -0.12, -0.28, 0.6, 0.18, 924, strength=1.0)
    img = flame(img, 0.2, -0.28, 0.48, 0.14, 925, strength=1.0)
    img = add(img, C("#ffa050"), sparks(22, 926, (-0.6, -0.9, 0.6, -0.1), (0.003, 0.007)) * 0.8)
    return finish(img, 92, exposure=1.4, grade=(1.06, 0.96, 0.9))


@H("rest")
def rest():
    img = G("#06070d", "#0c1020", 930, "#6a80d8", (0, -0.3), 0.9, "#1a2448", 0.6)
    img = add(img, C("#e8ecff"), stars(931, 40, 0.5))
    img = floor_shadow(img, 0, 0.7, 0.6, 0.08, 0.5)
    # a crescent moon, the pale stretch of the bar
    moon = np.maximum(circle(-0.35, -0.5, 0.2), -circle(-0.28, -0.56, 0.17))
    img = add(img, C("#8aa0e8"), np.exp(-np.maximum(moon, 0) / 0.08) * 0.5)
    img = piece(img, moon, "#8a9ac8", "#f4f6ff", "#ffffff", 0.07, shadowed=False)
    # an offering bowl heaped with ash, the first pale flame over it
    bowl = poly([(-0.52, 0.2), (0.52, 0.2), (0.4, 0.6), (-0.4, 0.6)])
    img = piece(img, bowl, "#1a1410", "#7a6a58", "#e8d8c0", 0.3, tex=rough(932, 18), shine=14.0)
    rim = ellipse(0, 0.2, 0.52, 0.1)
    img = piece(img, rim, "#1a1410", "#8a7a68", "#e8d8c0", 0.06, shadowed=False)
    wx, wy = warp(0.015, 6, 933)
    mound = ellipse(0, 0.12, 0.44, 0.2, wx, wy)
    Z = np.clip(-mound / 0.2, 0, 1) + 0.2 * nz(30, 934, octaves=3)
    img = heightlit(Z, mound, "#26222a", "#b2acb8", "#f0ecf6", img, k=80, shadowed=False)
    img = fire(img, 0.0, 0.1, 0.55, 0.14, 935, cool=True)
    img = add(img, C("#a8c0ff"), sparks(14, 936, (-0.3, -0.5, 0.3, 0.0), (0.003, 0.006)) * 0.8)
    return finish(img, 93, exposure=1.4, grade=(0.97, 0.99, 1.06))


@H("ward")
def ward():
    img = G("#07060a", "#130d0b", 940, "#d4902a", (0, 0.2), 0.95, "#3a2614")
    # a circle of ash on the ground, ward marks round it, a small flame in the middle
    ringd = np.abs(np.hypot(x / 0.82, (y - 0.3) / 0.42) - 1.0) * 0.42 - 0.03
    wx, wy = warp(0.012, 8, 941)
    ringd = np.abs(np.hypot(wx / 0.82, (wy - 0.3) / 0.42) - 1.0) * 0.42 - 0.03
    img = over(img, C("#b0aab4") * (0.8 + 0.3 * nz(60, 942)[..., None]), smooth(ringd))
    for k in range(12):
        a = k * np.pi / 6 + 0.1
        mx, my = 0.82 * np.cos(a), 0.3 + 0.42 * np.sin(a)
        mark = box(mx, my, 0.016, 0.07)
        img = over(img, C("#d8d2dc"), smooth(mark) * 0.9)
    # a dome of warm light standing over the circle, its seams just visible
    for rr in (0.9, 0.6, 0.3):
        arc = np.abs(np.hypot(x, (y - 0.3) * 1.0) - rr) - 0.0
        img = add(img, C("#ffc060"), np.exp(-(arc / 0.012) ** 2) * (y < 0.3) * 0.28)
    img = add(img, C("#ffa040"), np.exp(-(np.hypot(x / 0.9, (y - 0.0) / 0.8)) ** 2) * 0.18)
    img = flame(img, 0.0, 0.3, 0.7, 0.16, 943, strength=1.1)
    stones = [(-0.14, 0.34), (0.14, 0.34), (0.0, 0.4)]
    for sx_, sy_ in stones:
        img = piece(img, ellipse(sx_, sy_, 0.07, 0.045), "#14100e", "#6a625a", "#e0d0c0", 0.045)
    img = add(img, C("#ffc870"), sparks(20, 944, (-0.6, -0.7, 0.6, 0.3), (0.003, 0.007)) * 0.8)
    return finish(img, 94, exposure=1.4, grade=(1.06, 0.97, 0.9))


@H("svc_smith")
def svc_smith():
    img = G("#09070a", "#150d0a", 950, "#d06a20", (-0.2, 0.2), 0.9, "#3a1c10")
    img = floor_shadow(img, 0, 0.72, 0.75, 0.07, 0.6)
    horn = poly([(-0.82, -0.2), (-0.44, -0.3), (-0.4, -0.0), (-0.62, 0.0)])
    face = poly([(-0.44, -0.36), (0.6, -0.36), (0.6, -0.12), (0.44, -0.04), (0.3, 0.12), (0.34, 0.5), (0.5, 0.7), (-0.5, 0.7), (-0.3, 0.5), (-0.26, 0.12), (-0.4, -0.04)])
    sd = np.minimum(horn, face)
    img = piece(img, sd, "#0a0a0c", "#6a6a78", "#f4f4ff", 0.2, tex=0.75 + 0.5 * nz(40, 951), shine=30.0)
    img = add(img, C("#ff7a28"), np.exp(-(np.hypot(x - 0.1, y + 0.4) / 0.25) ** 2) * 0.35 * smooth(sd))
    # hammer resting on the face, a bar of white-hot iron under it
    bar = box(-0.1, -0.42, 0.34, 0.035)
    img = piece(img, bar, "#6a1a06", "#ff8a30", "#fff0c0", 0.035, glowc="#ffd070", glowamt=1.0, shadowed=False)
    img = add(img, C("#ff6a18"), np.exp(-np.maximum(bar, 0) / 0.08) * 0.5)
    handle = stadium(0, 0, 0.5, 0.04, *rot(0.2, -0.62, 0.0))
    img = piece(img, handle, "#241408", "#8a5a34", "#e0b888", 0.04, tex=grain(x, y, 952, 3, 30, 0.8))
    head = box(-0.28, -0.62, 0.12, 0.1)
    img = piece(img, head, "#0a0a0c", "#7a7a88", "#ffffff", 0.1, tex=rough(953, 18), shine=28.0)
    img = add(img, C("#ffb050"), sparks(30, 954, (-0.6, -0.9, 0.5, -0.3), (0.003, 0.007)) * 0.9)
    return finish(img, 95, exposure=1.4, grade=(1.05, 0.97, 0.92))


@H("svc_herbs")
def svc_herbs():
    img = G("#06090a", "#0e1510", 960, "#8ab04a", (0, 0.0), 0.9, "#26361a")
    img = floor_shadow(img, 0, 0.74, 0.7, 0.08, 0.5)
    # herbs and bean-pods sprouting from a wicker basket
    rng = np.random.default_rng(961)
    for i in range(9):
        a = -0.8 + i * 0.2
        tip = (np.sin(a) * 0.7, -0.62 - 0.1 * np.cos(a * 4))
        st = curve(lambda t, tip=tip: (tip[0] * t ** 1.2, 0.2 + (tip[1] - 0.2) * t), 16)
        img = cord_path(st, 0.015, "#0a1808", "#4a7a28", 962 + i, img, 30.0, shadowed=False)
        for j in range(6, 16, 3):
            px_, py_ = st[j]
            for sx in (-1, 1):
                lf = ellipse(px_ + sx * 0.06, py_, 0.07, 0.035, *rot(px_ + sx * 0.06, py_, sx * 0.5))
                img = piece(img, lf, "#0e2a10", "#5aa040" if i % 2 else "#78b848", "#d8ffb8", 0.035, shadowed=False)
    pod = poly([(-0.52, -0.16), (-0.46, -0.1), (-0.32, 0.1), (-0.36, 0.14), (-0.5, -0.04)])
    img = piece(img, pod, "#1a3008", "#78a838", "#d8ffb8", 0.05, shadowed=False)
    basket = poly([(-0.6, 0.08), (0.6, 0.08), (0.46, 0.7), (-0.46, 0.7)])
    weave = 0.65 + 0.35 * (np.sin(x * 40 + y * 3.0) * np.sin(y * 34) > 0)
    img = piece(img, basket, "#2a1808", "#b8884a", "#f4d8a8", 0.28, tex=weave * (0.85 + 0.3 * nz(40, 970)), shine=8.0)
    img = piece(img, ellipse(0, 0.08, 0.62, 0.08), "#2a1808", "#c89a5a", "#f4d8a8", 0.06, shadowed=False)
    return finish(img, 96, exposure=1.4, grade=(1.0, 1.02, 0.96))


@H("svc_bells")
def svc_bells():
    img = G("#08070a", "#150f0a", 980, "#c89a4a", (0, -0.1), 0.9, "#2e2216")
    img = floor_shadow(img, 0, 0.78, 0.5, 0.07, 0.55)
    handle = box(0, 0.5, 0.07, 0.28)
    img = piece(img, handle, "#241408", "#8a5a30", "#e8c090", 0.07, tex=grain(y, x, 981, 3, 40, 0.8))
    img = piece(img, circle(0, 0.78, 0.09), "#241408", "#8a5a30", "#e8c090", 0.09, shadowed=False)
    prof = [(0.13 + 0.2 * (1 - np.exp(-5 * t)) + 0.22 * t ** 4, -0.5 + 0.84 * t) for t in np.linspace(0, 1, 28)]
    outline = [(-px_, py_) for px_, py_ in prof[::-1]] + prof
    bell = poly(outline)
    img = piece(img, bell, "#2a1608", "#d0a050", "#fff4c8", 0.3, tex=0.8 + 0.4 * nz(40, 982), shine=20.0)
    for by in (0.12, 0.26):
        img = over(img, C("#2a1608"), smooth(box(0, by, 0.5, 0.012)) * smooth(bell) * 0.5)
    img = piece(img, ellipse(0, 0.34, 0.5, 0.06), "#1a0e06", "#9a6a30", "#ffe0a0", 0.05, shadowed=False)
    img = piece(img, circle(0, 0.44, 0.07), "#2a1608", "#d0a050", "#fff4c8", 0.07, shadowed=False)
    for r0, a0 in [(0.62, 0.35), (0.78, 0.2)]:
        ang = np.arctan2(y - 0.0, x)
        rr = np.hypot(x, y - 0.0)
        img = add(img, C("#e0b868"), np.exp(-(np.abs(rr - r0) / 0.01) ** 2) * (np.abs(np.cos(ang)) > 0.7) * a0)
    return finish(img, 98, exposure=1.4, grade=(1.05, 0.98, 0.92))


@H("svc_beacon")
def svc_beacon():
    img = G("#05060c", "#0d0d18", 990, "#e07a2a", (0, -0.3), 0.9, "#2a2040", 0.5)
    img = add(img, C("#e8ecff"), stars(991, 36, 0.45))
    img = rays(img, 0.0, -0.35, 12, "#ffb860", 0.9, 14, 0.4)
    tower = poly([(-0.34, 0.8), (-0.26, 0.0), (0.26, 0.0), (0.34, 0.8)])
    wx, wy = warp(0.01, 8, 992)
    tower = poly([(-0.34, 0.8), (-0.26, 0.0), (0.26, 0.0), (0.34, 0.8)], wx, wy)
    stone = 0.7 + 0.5 * nz(18, 993) * (0.6 + 0.6 * (np.sin(y * 28) > 0.5))
    img = piece(img, tower, "#14120f", "#7a7468", "#e8e0d0", 0.24, tex=stone, shine=10.0)
    for by in (0.14, 0.3, 0.46, 0.62):
        img = over(img, C("#0a0908"), smooth(box(0, by, 0.4, 0.008)) * smooth(tower) * 0.6)
    cresset = poly([(-0.34, -0.06), (0.34, -0.06), (0.24, 0.1), (-0.24, 0.1)])
    img = piece(img, cresset, "#0c0a0a", "#6a6664", "#f0eeee", 0.1, tex=rough(994, 18))
    img = flame(img, 0.0, -0.05, 0.95, 0.3, 995, strength=1.4)
    img = add(img, C("#ffa050"), sparks(30, 996, (-0.6, -0.95, 0.6, -0.1), (0.003, 0.007)) * 0.9)
    return finish(img, 99, exposure=1.4, grade=(1.05, 0.97, 0.92))
