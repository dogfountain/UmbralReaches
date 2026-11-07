"""Item icons, set 2: the charms and elite bounties worn on cords. Category "item"."""
import numpy as np

from objects import *  # noqa: F401,F403
from registry import recipe
from items_relics import G, I


@I("charm_candle")
def charm_candle():
    img = G("#0a0706", "#180f0a", 500, "#e0902f", (0, -0.2), 0.8, "#3a2414")
    img = bloom_light(img, 0, -0.25, 0.5, "#ff9a3a", 0.45)
    img = floor_shadow(img, 0.05, 0.62, 0.7, 0.09, 0.55)
    saucer = ellipse(0, 0.52, 0.62, 0.14)
    img = piece(img, saucer, "#2a1a0a", "#b88838", "#ffe0a0", 0.12, tex=rough(501, 18))
    img = over(img, C("#140c06"), smooth(ellipse(0, 0.5, 0.42, 0.075)) * 0.8)
    ring = np.abs(ellipse(0.62, 0.5, 0.16, 0.12)) - 0.025
    img = piece(img, ring, "#2a1a0a", "#b88838", "#ffe0a0", 0.025)
    stub = poly([(-0.2, 0.52), (-0.19, -0.08), (-0.1, -0.14), (0.12, -0.12), (0.2, -0.06), (0.21, 0.52)])
    wx, wy = warp(0.01, 8, 502)
    stub = poly([(-0.2, 0.52), (-0.19, -0.08), (-0.1, -0.14), (0.12, -0.12), (0.2, -0.06), (0.21, 0.52)], wx, wy)
    img = piece(img, stub, "#6a5430", "#f4e4b4", "#fff8e0", 0.2, tex=0.9 + 0.2 * nz(30, 503), glowc="#ff9a40", glowamt=0.35)
    # a drip that ran down one side, and the pool at the foot
    drip = stadium(-0.14, 0.18, 0.045, 0.2, *rot(0, 0, 0)) if False else box(-0.15, 0.12, 0.03, 0.17)
    img = over(img, C("#fff0c8"), smooth(drip) * 0.5 * smooth(stub))
    img = piece(img, ellipse(0, 0.5, 0.3, 0.05), "#8a7448", "#f4e4b4", "#ffffff", 0.05, shadowed=False)
    # wick and flame
    img = over(img, C("#1a1008"), smooth(box(0, -0.18, 0.012, 0.07)))
    img = flame(img, 0.01, -0.2, 0.62, 0.11, 504)
    img = add(img, C("#ffc870"), sparks(14, 505, (-0.4, -0.9, 0.4, -0.1), (0.003, 0.006)) * 0.6)
    return finish(img, 50, exposure=1.4, grade=(1.06, 0.97, 0.9))


@I("charm_thread")
def charm_thread():
    img = G("#0a0607", "#170c0d", 510, "#b02a26", (0, 0.0), 0.8, "#3a1416")
    img = floor_shadow(img, 0, 0.7, 0.6, 0.08, 0.4)
    loop1 = curve(lambda t: (-0.3 + 0.3 * np.cos(t * 2 * np.pi + np.pi), -0.12 + 0.28 * np.sin(t * 2 * np.pi + np.pi) * 1.0), 50)
    loop1 = curve(lambda t: (-0.36 * np.sin(np.pi * t) * 1.2 * (1 if t < 0.5 else 1) - 0.0, 0.0), 2)
    # a bow: two lobes crossing at the knot, and two tails
    lobe_l = curve(lambda t: (-0.54 * np.sin(np.pi * t), -0.3 * np.sin(2 * np.pi * t) * 0.8 - 0.02), 60)
    lobe_r = curve(lambda t: (0.54 * np.sin(np.pi * t), 0.3 * np.sin(2 * np.pi * t) * 0.8 - 0.02), 60)
    tail_l = curve(lambda t: (-0.04 - 0.16 * t + 0.1 * np.sin(t * 7), 0.04 + 0.62 * t), 40)
    tail_r = curve(lambda t: (0.04 + 0.2 * t - 0.12 * np.sin(t * 6), 0.04 + 0.55 * t), 40)
    for pts in (tail_l, tail_r, lobe_l, lobe_r):
        d, tt, side = path_t(pts)
        w = 0.075
        sd = d - w
        tw = 0.6 + 0.45 * np.sin(tt * 70 + side / w * 3.0)
        fuzz = 0.85 + 0.3 * nz(90, 511)
        img = piece(img, sd, "#3a0808", "#d4342c", "#ffb0a0", w, tex=tw * fuzz, shine=6.0)
    knot = ellipse(0, 0.02, 0.13, 0.11)
    img = piece(img, knot, "#3a0808", "#c82c26", "#ffb0a0", 0.12, tex=0.8 + 0.4 * nz(70, 512), shine=6.0)
    img = add(img, C("#ff8070"), sparks(18, 513, (-0.7, -0.5, 0.7, 0.8), (0.003, 0.006)) * 0.35)
    return finish(img, 51, exposure=1.4, grade=(1.05, 0.96, 0.96))


@I("charm_lampglass")
def charm_lampglass():
    img = G("#08070a", "#15100c", 520, "#e0a850", (0.1, -0.1), 0.9, "#3a2c18")
    img = bloom_light(img, 0.2, -0.2, 0.5, "#ffc870", 0.5)
    pane = poly([(-0.5, 0.64), (-0.38, -0.5), (0.1, -0.7), (0.58, -0.58), (0.7, -0.14), (0.52, 0.5), (0.0, 0.7)])
    img = floor_shadow(img, 0, 0.72, 0.6, 0.06, 0.45)
    img = shadow(img, pane, amt=0.4)
    img = glass(img, pane, "#e8c880", "#fff0c0", amt=0.38, hi=1.0)
    m = smooth(pane)
    # the sheen across it and a crack from the broken corner
    sheen = np.exp(-((x + y * 0.55 - 0.18) / 0.07) ** 2) + 0.5 * np.exp(-((x + y * 0.55 + 0.25) / 0.03) ** 2)
    img = add(img, C("#fff6dc"), sheen * m * 0.35)
    crack = polyline([(0.7, -0.14), (0.4, -0.02), (0.3, 0.14), (0.1, 0.2), (0.0, 0.4)])
    crack = np.minimum(crack, polyline([(0.3, 0.14), (0.38, 0.34)]))
    img = add(img, C("#fff0c0"), smooth(crack - 0.006) * m * 0.8)
    img = add(img, C("#e8c070"), np.exp(-np.abs(pane + 0.03) / 0.012) * m * 0.25)
    # soot at one edge: the pane came out of a lamp
    img = img * (1 - 0.45 * ss(0.5, 0.9, 1 - (x * 0.5 + 0.5)) * m * 0.0)[..., None]
    img = over(img, C("#1a1208"), m * ss(0.15, 0.6, nz(5, 521)) * ss(0.2, 0.7, -(y * 0.6 + x * 0.4) + 0.4) * 0.35)
    img = add(img, C("#ffd890"), sparks(12, 522, (-0.6, -0.6, 0.7, 0.6), (0.003, 0.006)) * 0.6)
    return finish(img, 52, exposure=1.4, grade=(1.05, 0.98, 0.92))


@I("charm_bead")
def charm_bead():
    img = G("#08070a", "#16120f", 530, "#c0a880", (0, 0.0), 0.8, "#2c261e")
    img = floor_shadow(img, 0.02, 0.62, 0.55, 0.08, 0.5)
    # frayed bit of cord through the bead
    cordp = curve(lambda t: (-0.85 + 1.7 * t, 0.02 + 0.03 * np.sin(t * 9)), 40)
    img = cord_path(cordp, 0.04, "#2a1a0e", "#8a6a44", 531, img, 90.0)
    bead = circle(0, 0.0, 0.43)
    tex = 0.8 + 0.3 * grain(x, y, 532, 3.0, 22.0, 0.5)
    img = piece(img, bead, "#4a3e30", "#f2e8d2", "#ffffff", 0.43, tex=tex, shine=12.0)
    # the bore and a ring of tally nicks
    img = over(img, C("#0a0705"), smooth(circle(0.0, 0.0, 0.1)))
    img = add(img, C("#e8dcc0"), np.exp(-(np.abs(np.hypot(x, y) - 0.1) / 0.012) ** 2) * 0.35)
    a = np.arctan2(y, x)
    r = np.hypot(x, y)
    nick = (np.abs(np.sin(a * 7.0)) > 0.97) & (r > 0.2) & (r < 0.37)
    img = over(img, C("#4a3a28"), nick.astype(float) * 0.7 * smooth(bead))
    img = over(img, C("#6a5a46"), smooth(bead) * ss(0.3, 0.8, nz(7, 533)) * 0.12)
    img = over(img, C("#2a1a0e") * 1.0, smooth(circle(0.0, 0.0, 0.065)) * 1.0)
    return finish(img, 53, exposure=1.4, grade=(1.03, 0.99, 0.95))


@I("charm_clapper")
def charm_clapper():
    img = G("#08070a", "#150f0b", 540, "#b07a3a", (0, 0.1), 0.85, "#2e2216")
    img = floor_shadow(img, 0, 0.72, 0.4, 0.07, 0.5)
    ring = np.abs(circle(0, -0.62, 0.14)) - 0.03
    rod = stadium(0, -0.15, 0.06, 0.4, x, -y if False else y)
    rod = box(0, -0.18, 0.055, 0.44)
    ball = circle(0, 0.36, 0.28)
    neck = poly([(-0.07, 0.0), (0.07, 0.0), (0.16, 0.2), (-0.16, 0.2)])
    sd = np.minimum(np.minimum(rod, ball), np.minimum(neck, ring))
    patina = ss(0.5, 0.72, nz(7, 541, octaves=4))
    tex = 0.75 + 0.5 * nz(40, 542, octaves=3)
    img = piece(img, sd, "#2a1608", "#c8924a", "#ffe8b0", 0.16, tex=tex, shine=20.0)
    img = over(img, C("#3a8a68") * (0.7 + 0.5 * nz(30, 543)[..., None]), smooth(sd) * patina * 0.4)
    # the stroke marks on the ball: a worn bright face where it struck
    img = add(img, C("#ffe0a0"), np.exp(-(np.hypot(x - 0.0, y - 0.55) / 0.1) ** 2) * smooth(ball) * 0.25)
    # echoes of a last stroke
    ang = np.arctan2(y - 0.36, x)
    rr = np.hypot(x, y - 0.36)
    for r0, a0 in [(0.42, 0.45), (0.56, 0.3)]:
        arc = np.exp(-(np.abs(rr - r0) / 0.01) ** 2) * (np.abs(np.cos(ang)) > 0.6) * a0
        img = add(img, C("#d8b070"), arc * 0.6)
    return finish(img, 54, exposure=1.4, grade=(1.05, 0.98, 0.92))


@I("charm_ring")
def charm_ring():
    img = G("#08080a", "#121216", 550, "#6a6a80", (0, 0.0), 0.85, "#2a2a34")
    img = floor_shadow(img, 0, 0.58, 0.7, 0.1, 0.55)
    # wood chips from the axe-haft, still pale
    for (cx, cy, a) in [(0.55, 0.52, 0.5), (-0.62, 0.55, -0.3)]:
        u, v = rot(cx, cy, a)
        ch = box(0, 0, 0.12, 0.035, u, v)
        img = piece(img, ch, "#4a2e18", "#c89a60", "#ffe8c0", 0.04, tex=grain(u, v, 551, 4, 40, 0.5))
    outer = ellipse(0, 0.0, 0.66, 0.5)
    inner = ellipse(0, 0.0, 0.4, 0.27)
    sd = np.maximum(outer, -inner)
    tex = 0.7 + 0.5 * nz(50, 552, octaves=3)
    img = piece(img, sd, "#0c0c10", "#8a8a98", "#f0f0ff", 0.17, tex=tex, shine=28.0)
    img = over(img, C("#6a3a22") * (0.7 + 0.4 * nz(30, 553)[..., None]), smooth(sd) * ss(0.55, 0.75, nz(6, 554)) * 0.45)
    # the oval of the haft worn into it: a flat bright side
    img = add(img, C("#e8e8f4"), np.exp(-(np.abs(x + 0.5 - (y * y) * 0.6) / 0.025) ** 2) * smooth(sd) * 0.3)
    return finish(img, 55, exposure=1.4, grade=(0.99, 0.99, 1.04))


@I("hobbs_knuckles")
def hobbs_knuckles():
    img = G("#09080a", "#141214", 560, "#6a6064", (0, 0.1), 0.9, "#2a2628")
    img = floor_shadow(img, 0, 0.58, 0.8, 0.09, 0.55)
    bar = stadium(0, 0.3, 0.72, 0.09)
    img = piece(img, bar, "#0e0e10", "#7a7678", "#f0eeee", 0.09, tex=rough(561, 20) * 0.9, shine=28.0)
    for i, rx in enumerate((-0.5, -0.17, 0.17, 0.5)):
        outer = ellipse(rx, -0.06, 0.17, 0.34)
        inner = ellipse(rx, -0.06, 0.085, 0.2)
        sd = np.maximum(outer, -inner)
        img = piece(img, sd, "#0c0c0e", "#9a9698", "#ffffff", 0.1, tex=0.75 + 0.5 * nz(50, 562 + i), shine=30.0)
        img = over(img, C("#5a3828"), smooth(sd) * ss(0.6, 0.8, nz(8, 570 + i)) * 0.3)
    img = add(img, C("#fff0e0"), np.exp(-(np.abs(x + 0.4) / 0.03) ** 2) * 0.0)
    # bright where the pilgrim's door-knocking wore the left side
    return finish(img, 56, exposure=1.4, grade=(1.0, 0.99, 0.99))


@I("lisles_tally")
def lisles_tally():
    img = G("#09070a", "#15100c", 580, "#a07a44", (0, 0.0), 0.9, "#2c2216")
    img = floor_shadow(img, 0.04, 0.68, 0.7, 0.07, 0.5)
    board = rotated_poly([(-0.62, -0.7), (0.58, -0.7), (0.62, 0.7), (-0.58, 0.7)], 0, 0, 0.12)
    wx, wy = warp(0.008, 7, 581)
    sd = poly(board, wx, wy)
    u, v = rot(0, 0, 0.12)
    tex = grain(v, u, 582, 2.0, 22.0, 0.9)
    img = piece(img, sd, "#2a1a0e", "#b08650", "#f4d8a8", 0.08, tex=tex, shine=14.0, relief=0.6)
    # scored strokes: groups of five; the last group is three, a fourth begun
    def stroke(ax, ay, bx, by):
        s = segment(ax, ay, bx, by, u + 0.0 * x, v + 0.0 * y) if False else segment(ax, ay, bx, by, u, v)
        return s
    marks = None
    rows = [(-0.4, 2, 0), (-0.02, 2, 0), (0.36, 0, 3)]
    for ri, (ry, full, extra) in enumerate(rows):
        gx = -0.38
        for g in range(full):
            for k in range(4):
                s = stroke(gx + k * 0.08, ry - 0.11, gx + k * 0.08, ry + 0.11)
                marks = s if marks is None else np.minimum(marks, s)
            s = stroke(gx - 0.05, ry + 0.07, gx + 0.3, ry - 0.07)
            marks = np.minimum(marks, s)
            gx += 0.42
        if extra:
            for k in range(extra):
                marks = np.minimum(marks, stroke(gx + k * 0.08, ry - 0.11, gx + k * 0.08, ry + 0.11))
            marks = np.minimum(marks, stroke(gx + 0.24, ry - 0.11, gx + 0.24, ry - 0.0))
    g = smooth(marks - 0.016) * smooth(sd + 0.03)
    lip = smooth(np.roll(np.roll(marks, 2, 0), 2, 1) - 0.016) * (1 - g) * smooth(sd + 0.03)
    img = img * (1 - 0.82 * g)[..., None]
    img = add(img, C("#f0d8a8"), lip * 0.3)
    hole = circle(-0.38, -0.62, 0.05)
    hole = circle(*(-0.42, -0.6), 0.045)
    img = over(img, C("#0a0604"), smooth(hole))
    return finish(img, 58, exposure=1.4, grade=(1.05, 0.98, 0.92))


@I("briar_antler")
def briar_antler():
    img = G("#09060a", "#140a0b", 590, "#8a2a1a", (0, 0.0), 0.8, "#3a1a16")
    img = floor_shadow(img, 0.0, 0.78, 0.5, 0.06, 0.4)
    beam = curve(lambda t: (-0.3 + 0.25 * t + 0.25 * np.sin(t * 3.0), 0.8 - 1.6 * t), 50)
    tines = [curve(lambda t, b=b: (beam[b][0] + 0.38 * t * s, beam[b][1] - 0.35 * t - 0.05 * np.sin(t * 5)), 20)
             for b, s in ((14, -1), (22, 1), (32, -1), (40, 1))]
    shapes = []
    d, tt, side = path_t(beam)
    w = 0.11 * (1 - 0.35 * np.clip(tt / 2.0, 0, 1))
    sd = d - w
    for k, tp in enumerate(tines):
        dd, t2, s2 = path_t(tp)
        sd = np.minimum(sd, dd - 0.075 * (1 - 0.8 * np.clip(t2 / 0.5, 0, 1)))
    tex = grain(tt, side, 591, 2.0, 30.0, 0.7) * (0.8 + 0.3 * nz(14, 592))
    img = piece(img, sd, "#1e0e0a", "#9a5a34", "#f0c098", 0.11, tex=0.8 + 0.4 * nz(50, 593, octaves=3), shine=16.0)
    # briar thorns growing from it, and a green tendril wound up the beam
    vine = curve(lambda t: (-0.25 + 0.25 * t + 0.25 * np.sin(t * 3.0) + 0.06 * np.sin(t * 22), 0.78 - 1.5 * t), 100)
    img = cord_path(vine, 0.018, "#10160a", "#4a6a28", 594, img, 40.0, shadowed=False)
    rng = np.random.default_rng(595)
    for i in range(14):
        px_, py_ = vine[int(rng.integers(5, 95))]
        a = rng.uniform(0, 2 * np.pi)
        L = rng.uniform(0.07, 0.12)
        tri = poly([(px_ - 0.018, py_), (px_ + 0.018, py_), (px_ + np.cos(a) * L, py_ + np.sin(a) * L)])
        img = piece(img, tri, "#1a1208", "#7a6a34", "#ffe8b0", 0.02, shadowed=False)
    return finish(img, 59, exposure=1.4, grade=(1.05, 0.97, 0.95))


@I("heart_stone")
def heart_stone():
    img = G("#06090a", "#0d1312", 600, "#3a7a68", (0, 0.0), 0.85, "#1a3a34")
    img = floor_shadow(img, 0.0, 0.62, 0.7, 0.1, 0.55)
    wx, wy = warp(0.03, 4, 601)
    sd = ellipse(0, 0.04, 0.66, 0.54, wx, wy)
    tex = 0.75 + 0.45 * nz(28, 602, octaves=4)
    img = piece(img, sd, "#18241f", "#7a9a90", "#e0fff4", 0.5, tex=tex, shine=10.0, relief=0.8)
    # one face warm, as if it still sat near a hearth
    warm = np.exp(-(np.hypot(x - 0.3, y - 0.3) / 0.45) ** 2) * smooth(sd)
    img = add(img, C("#ff9a50"), warm * 0.32)
    # the rope sling: a worn groove and two turns of cord
    for a, off in ((0.0, 0.0), (1.0, 0.0)):
        pass
    sling = curve(lambda t: (0.66 * np.cos(t * 2 * np.pi) * 0.98, 0.04 + 0.4 * np.sin(t * 2 * np.pi) * 0.98 - 0.12 * np.cos(t * 2 * np.pi)), 80)
    d, tt, side = path_t(sling)
    img = over(img, C("#0a0e0c"), smooth(d - 0.05) * smooth(sd + 0.02) * 0.0)
    knot_cord = curve(lambda t: (-0.4 + 0.8 * t, -0.34 + 0.0 * t + 0.02 * np.sin(t * 9)), 30)
    loopc = curve(lambda t: (0.0 + 0.09 * np.sin(t * 6.2832), -0.34 - 0.6 * t), 30)
    img = cord_path(knot_cord, 0.035, "#2a1c0e", "#a07a4a", 603, img, 90.0)
    img = cord_path(loopc, 0.035, "#2a1c0e", "#a07a4a", 604, img, 90.0)
    img = add(img, C("#a8ffe0"), sparks(14, 605, (-0.8, -0.8, 0.8, 0.8), (0.003, 0.006)) * 0.3)
    return finish(img, 60, exposure=1.35, grade=(0.98, 1.02, 1.0))


@I("cinder_censer")
def cinder_censer():
    img = G("#09060a", "#170c0a", 610, "#d4501a", (0, 0.2), 0.8, "#3a1a10")
    img = floor_shadow(img, 0, 0.7, 0.55, 0.07, 0.5)
    # chains up to the ring
    for sx in (-0.34, 0.0, 0.34):
        ch = polyline([(sx, 0.0), (0.0, -0.66)])
        for k in range(8):
            t = k / 8.0
            px_, py_ = sx * (1 - t), -0.0 - 0.66 * t
            lk = np.abs(ellipse(px_, py_, 0.035, 0.055)) - 0.014
            img = piece(img, lk, "#1a1410", "#8a7448", "#ffe0a0", 0.014, shadowed=False)
    ring = np.abs(circle(0, -0.72, 0.1)) - 0.025
    img = piece(img, ring, "#1a1410", "#b08a48", "#ffe0a0", 0.025)
    bowl = poly([(-0.44, 0.0), (0.44, 0.0), (0.34, 0.3), (0.16, 0.5), (-0.16, 0.5), (-0.34, 0.3)])
    dome = np.maximum(ellipse(0, 0.0, 0.44, 0.38), -(y - 0.0))
    foot = box(0, 0.56, 0.2, 0.05)
    img = piece(img, foot, "#241a10", "#8a6a38", "#ffe0a0", 0.05)
    img = piece(img, bowl, "#241a10", "#9a7a3c", "#ffe8b0", 0.3, tex=rough(611, 16))
    img = add(img, C("#ff5a18"), np.exp(-np.abs(bowl) / 0.05) * 0.0)
    img = piece(img, dome, "#2a1c10", "#b08a44", "#fff0c0", 0.3, tex=rough(612, 16))
    # the coal glows through the pierced dome
    rng = np.random.default_rng(613)
    for i in range(11):
        a = rng.uniform(0.25, np.pi - 0.25)
        r = rng.uniform(0.08, 0.3)
        hx, hy = r * np.cos(a) * 1.2, -r * np.sin(a) * 0.95 + 0.0
        hs = circle(hx, hy - 0.05, 0.022)
        img = add(img, C("#ff7a22"), np.exp(-np.maximum(hs, 0) / 0.03) * 0.5)
        img = over(img, C("#ffc060"), smooth(hs))
    img = add(img, C("#ff6a20"), np.exp(-np.abs(box(0, 0.0, 0.44, 0.0)) / 0.02) * 0.5)
    img = add(img, C("#ffa050"), sparks(14, 614, (-0.5, -0.7, 0.5, 0.1), (0.003, 0.006)) * 0.6)
    return finish(img, 61, exposure=1.4, grade=(1.05, 0.97, 0.92))


@I("scraped_face")
def scraped_face():
    img = G("#08080a", "#141416", 620, "#a8a49e", (0, -0.1), 0.85, "#2c2c2e")
    img = floor_shadow(img, 0, 0.78, 0.4, 0.06, 0.5)
    wx, wy = warp(0.012, 6, 621)
    face = poly([(-0.46, -0.52), (-0.3, -0.7), (0.3, -0.7), (0.46, -0.52), (0.44, 0.1), (0.3, 0.5), (0.0, 0.78), (-0.3, 0.5), (-0.44, 0.1)], wx, wy)
    tex = 0.8 + 0.4 * nz(44, 622, octaves=3)
    img = piece(img, face, "#3a3834", "#e4dfd6", "#ffffff", 0.3, tex=tex, shine=10.0, relief=0.7)
    # chisel scrapes, long and shallow
    for i in range(18):
        rng = np.random.default_rng(623 + i)
        cx, cy = rng.uniform(-0.3, 0.3), rng.uniform(-0.55, 0.55)
        a = rng.uniform(-0.4, 0.4)
        L = rng.uniform(0.1, 0.24)
        s = segment(cx - np.cos(a) * L, cy - np.sin(a) * L, cx + np.cos(a) * L, cy + np.sin(a) * L)
        img = over(img, C("#6a665e"), smooth(s - 0.007) * smooth(face + 0.02) * 0.5)
        img = over(img, C("#f6f2e8"), smooth(np.roll(s, 2, 0) - 0.006) * smooth(face + 0.02) * 0.2)
    # the slits where eyes were, and the ridge of a nose
    for ex in (-0.19, 0.19):
        e = ellipse(ex, -0.12, 0.1, 0.028)
        img = over(img, C("#050405"), smooth(e))
    img = over(img, C("#8a867c"), smooth(box(0, 0.12, 0.03, 0.16)) * smooth(face) * 0.4)
    # inside, a small carved fire gives its glow through the left slit
    img = add(img, C("#ff8a30"), np.exp(-np.maximum(ellipse(-0.19, -0.12, 0.1, 0.028), 0) / 0.02) * 0.45)
    img = flame(img, -0.19, -0.1, 0.12, 0.03, 624, strength=0.0)
    img = over(img, C("#ffb050"), smooth(ellipse(-0.19, -0.12, 0.05, 0.012)) * 0.9)
    for hx in (-0.4, 0.4):
        img = over(img, C("#0a0a0a"), smooth(circle(hx, -0.4, 0.025)))
    return finish(img, 62, exposure=1.4, grade=(1.0, 1.0, 1.0))


@I("charm_hook")
def charm_hook():
    img = G("#06090a", "#0d1415", 630, "#4a9a90", (0.1, -0.1), 0.85, "#183a38")
    img = floor_shadow(img, 0.0, 0.78, 0.5, 0.06, 0.4)
    pole = curve(lambda t: (-0.55 + 0.7 * t, 0.85 - 1.2 * t), 10)
    d, tt, side = path_t(pole)
    img = piece(img, d - 0.055, "#1a0e08", "#8a5a34", "#e8c098", 0.055, tex=grain(tt, side, 631, 2, 30, 0.8))
    # iron socket and the hook, its point turned back
    hk = [(-0.4 + 0.7 * 1.0 + 0.0, 0.0)]
    hook = [(0.15, -0.35), (0.22, -0.5)]
    for i in range(0, 26):
        th = -0.5 * np.pi + (-0.2 + 1.55 * np.pi * i / 25)
        hook.append((0.14 + 0.33 * np.cos(th + np.pi * 0.0) * 1.0 + 0.0, -0.55 + 0.33 * np.sin(th) * 1.0 + 0.33))
    hook = [(0.15, -0.28), (0.15, -0.55)] + [(0.15 + 0.3 - 0.3 * np.cos(a), -0.55 - 0.3 * np.sin(a)) for a in np.linspace(0, np.pi * 1.15, 24)]
    dh, th_, sh = path_t(hook)
    w = 0.055 * (1 - 0.7 * ss(1.0, 1.9, th_))
    img = piece(img, dh - w, "#0a1214", "#6a8a90", "#e0ffff", 0.055, tex=0.8 + 0.4 * nz(40, 632), shine=26.0)
    sock = poly([(0.04, -0.12), (0.26, -0.12), (0.22, -0.42), (0.08, -0.42)])
    sock = np.minimum(sock, box(0.0 + 0.15, -0.2, 0.11, 0.2)) if False else sock
    img = piece(img, sock, "#0a1214", "#7a9aa0", "#e0ffff", 0.08, tex=rough(633, 16))
    img = over(img, C("#3a8a70"), smooth(dh - w) * ss(0.55, 0.7, nz(8, 634)) * 0.3)
    # a frayed stub of rope tied on
    rope = curve(lambda t: (-0.05 - 0.25 * t, 0.15 + 0.35 * t + 0.05 * np.sin(t * 9)), 20)
    img = cord_path(rope, 0.04, "#2a1c0e", "#a07a4a", 635, img, 90.0)
    return finish(img, 63, exposure=1.4, grade=(0.98, 1.02, 1.02))


@I("charm_rosary")
def charm_rosary():
    img = G("#09060a", "#170b08", 640, "#d4601a", (0, 0.0), 0.8, "#3a1a10")
    img = floor_shadow(img, 0, 0.78, 0.5, 0.07, 0.4)
    ringp = curve(lambda t: (0.56 * np.cos(t * 2 * np.pi + np.pi / 2), -0.12 + 0.46 * np.sin(t * 2 * np.pi + np.pi / 2)), 80)
    stem = curve(lambda t: (0.0, 0.34 + 0.2 * t), 10)
    img = cord_path(ringp, 0.014, "#1a1008", "#6a4a2a", 641, img, 60.0)
    img = cord_path(stem, 0.014, "#1a1008", "#6a4a2a", 642, img, 60.0)
    n = 15
    for k in range(n):
        a = 2 * np.pi * k / n + np.pi / 2 + 0.2
        bx, by = 0.56 * np.cos(a), -0.12 + 0.46 * np.sin(a)
        if abs(a % (2 * np.pi) - np.pi / 2) < 0.15:
            continue
        r = 0.082
        img = add(img, C("#ff5a18"), np.exp(-np.maximum(circle(bx, by, r), 0) / 0.05) * 0.3)
        img = piece(img, circle(bx, by, r), "#5a1a08", "#ff8a3a", "#fff0c0", r, glowc="#ff7a22", glowamt=0.6, shine=14.0, shadowed=True)
    img = piece(img, circle(0, 0.34, 0.085), "#5a1a08", "#ff8a3a", "#fff0c0", 0.085, glowc="#ff7a22", glowamt=0.6)
    # a small cross of fired clay hangs below
    cr = np.minimum(box(0, 0.7, 0.032, 0.14), box(0, 0.64, 0.1, 0.032))
    img = piece(img, cr, "#4a1408", "#d4602a", "#ffd8a0", 0.04, glowc="#ff6a20", glowamt=0.4)
    img = add(img, C("#ffa050"), sparks(18, 643, (-0.7, -0.6, 0.7, 0.6), (0.003, 0.006)) * 0.5)
    return finish(img, 64, exposure=1.4, grade=(1.06, 0.97, 0.9))


@I("charm_jar")
def charm_jar():
    img = G("#07060c", "#110d1a", 650, "#7a5aff", (0, 0.1), 0.85, "#2a1f4a")
    img = floor_shadow(img, 0, 0.72, 0.5, 0.07, 0.5)
    body = poly([(-0.36, 0.0), (-0.44, 0.3), (-0.38, 0.7), (0.38, 0.7), (0.44, 0.3), (0.36, 0.0), (0.22, -0.28), (-0.22, -0.28)])
    wx, wy = warp(0.01, 7, 651)
    body = poly([(-0.36, 0.0), (-0.44, 0.3), (-0.38, 0.7), (0.38, 0.7), (0.44, 0.3), (0.36, 0.0), (0.22, -0.28), (-0.22, -0.28)], wx, wy)
    neck = box(0, -0.38, 0.2, 0.1)
    # the wisp inside: a small brilliant core with a curling tail and a face of two dark dots
    wisp = np.exp(-np.hypot(x, (y - 0.25) * 1.2) / 0.16) * 1.1
    tail = path_t(curve(lambda t: (0.04 * np.sin(t * 6), 0.4 - 0.5 * t), 20))[0]
    img = add(img, C("#8a6aff"), np.exp(-tail / 0.06) * smooth(body) * 0.6)
    img = add(img, C("#8a6aff"), wisp * smooth(body))
    img = add(img, C("#e8e0ff"), np.exp(-np.hypot(x, y - 0.28) / 0.07) * 0.9 * smooth(body))
    img = over(img, C("#1a1030"), smooth(circle(-0.045, 0.27, 0.018)) * smooth(body))
    img = over(img, C("#1a1030"), smooth(circle(0.045, 0.27, 0.018)) * smooth(body))
    img = glass(img, body, "#8a7ad0", "#d8ccff", amt=0.16, hi=1.2)
    img = glass(img, neck, "#8a7ad0", "#d8ccff", amt=0.16, hi=0.8)
    # cork and a twine
    cork = poly([(-0.17, -0.5), (0.17, -0.5), (0.2, -0.36), (-0.2, -0.36)])
    img = piece(img, cork, "#3a2410", "#c89a5a", "#ffe8c0", 0.1, tex=0.8 + 0.5 * nz(60, 652))
    twine = curve(lambda t: (-0.22 + 0.44 * t, -0.3 + 0.03 * np.sin(t * 20)), 20)
    img = cord_path(twine, 0.02, "#2a1c0e", "#a07a4a", 653, img, 80.0, shadowed=False)
    img = add(img, C("#c8b8ff"), sparks(10, 654, (-0.3, -0.2, 0.3, 0.6), (0.003, 0.006)) * 0.7)
    return finish(img, 65, exposure=1.4, grade=(1.0, 0.97, 1.05))


@I("charm_ferrule")
def charm_ferrule():
    img = G("#08080a", "#131316", 660, "#8a8aa0", (0, 0.1), 0.85, "#2a2a34")
    img = floor_shadow(img, 0.0, 0.78, 0.5, 0.06, 0.5)
    ang = 0.0
    sd = poly([(-0.3, -0.6), (0.3, -0.6), (0.2, 0.55), (0.0, 0.8), (-0.2, 0.55)])
    wx, wy = warp(0.008, 9, 661)
    sd = poly([(-0.3, -0.6), (0.3, -0.6), (0.2, 0.55), (0.0, 0.8), (-0.2, 0.55)], wx, wy)
    # hammer facets
    hm = 0.75 + 0.5 * nz(18, 662, px=x * 1.0, py=y * 3.0, octaves=3)
    img = piece(img, sd, "#0c0c10", "#8a8a98", "#f0f0ff", 0.3, tex=hm * (0.85 + 0.3 * nz(60, 663)), shine=30.0, relief=0.8)
    for ry, wd in ((-0.5, 0.31), (-0.2, 0.28)):
        band = box(0, ry, wd, 0.035)
        img = piece(img, band, "#16161a", "#a8a8b4", "#ffffff", 0.035, shadowed=False)
    for rx in (-0.14, 0.14):
        img = piece(img, circle(rx, 0.1, 0.035), "#16161a", "#c8c8d4", "#ffffff", 0.035, shadowed=False)
    # the heat-blue of the anvil still in it, and the ring it makes when it strikes stone
    img = add(img, C("#6a8aff"), np.exp(-(np.abs(y + 0.6) / 0.05) ** 2) * smooth(sd) * 0.25)
    rr = np.hypot(x, y - 0.85)
    for r0, a0 in [(0.2, 0.5), (0.34, 0.3)]:
        img = add(img, C("#e8ecff"), np.exp(-(np.abs(rr - r0) / 0.008) ** 2) * (y < 0.85) * a0 * 0.6)
    return finish(img, 66, exposure=1.4, grade=(0.99, 0.99, 1.03))


@I("charm_waystone")
def charm_waystone():
    img = G("#08090a", "#121411", 670, "#c0a460", (0.0, 0.2), 0.85, "#2a2c22")
    img = floor_shadow(img, 0.0, 0.7, 0.55, 0.08, 0.55)
    wx, wy = warp(0.03, 6, 671)
    sd = poly([(-0.46, 0.7), (-0.5, -0.1), (-0.3, -0.6), (0.06, -0.78), (0.4, -0.5), (0.52, 0.1), (0.48, 0.7)], wx, wy)
    Z = np.clip(-sd / 0.3, 0, 1) ** 0.6 * (0.6 + 0.4 * nz(7, 672)) + 0.12 * nz(30, 673, octaves=3)
    img = heightlit(Z, sd, "#1a1c18", "#9a9a88", "#f0f0e0", img, k=75, tex=0.75 + 0.5 * nz(50, 674, octaves=3))
    # moss on the shaded top and lichen spots
    moss = ss(0.5, 0.72, nz(6, 675, octaves=4)) * ss(-0.1, -0.6, y) * smooth(sd)
    img = over(img, C("#4a6a2a") * (0.7 + 0.5 * nz(40, 676)[..., None]), moss * 0.55)
    # a carved way-mark: an arrow of the road, its groove lit along one edge
    mk = polyline([(0.0, -0.3), (0.0, 0.3)])
    mk = np.minimum(mk, polyline([(-0.16, 0.12), (0.0, 0.3), (0.16, 0.12)]))
    g = smooth(mk - 0.026) * smooth(sd + 0.05)
    lip = smooth(np.roll(np.roll(mk, 2, 0), 2, 1) - 0.026) * (1 - g) * smooth(sd + 0.05)
    img = img * (1 - 0.8 * g)[..., None]
    img = add(img, C("#f0f0e0"), lip * 0.35)
    img = add(img, C("#ffc860"), np.exp(-np.hypot(x - 0.4, y + 0.5) / 0.1) * 0.3 * smooth(sd))
    return finish(img, 67, exposure=1.4, grade=(1.02, 1.0, 0.95))


@I("charm_chalk")
def charm_chalk():
    img = G("#07080a", "#101214", 680, "#8a96a0", (0, 0.0), 0.9, "#262a30")
    # a corner of slate in a worn wooden frame, with a tally in chalk
    sl = rotated_poly([(-0.9, -0.75), (0.8, -0.75), (0.8, 0.85), (-0.9, 0.85)], 0, 0, -0.1)
    frame = poly(sl)
    slate = poly(rotated_poly([(-0.82, -0.67), (0.72, -0.67), (0.72, 0.77), (-0.82, 0.77)], 0, 0, -0.1))
    img = piece(img, frame, "#241408", "#7a5230", "#e0b888", 0.1, tex=grain(x, y, 681, 3.0, 28.0, 0.8))
    img = piece(img, slate, "#0e1012", "#3a4248", "#a8b8c8", 0.06, tex=0.75 + 0.4 * nz(24, 682, octaves=3), shadowed=False, relief=0.4)
    img = add(img, C("#8a9aa8"), smooth(slate) * ss(0.45, 0.8, nz(3, 683)) * 0.06)
    u, v = rot(0, 0, -0.1)
    marks = None
    for gx in (-0.55, -0.1):
        for k in range(4):
            s = segment(gx + k * 0.09, -0.46, gx + k * 0.09, -0.2, u, v)
            marks = s if marks is None else np.minimum(marks, s)
        marks = np.minimum(marks, segment(gx - 0.06, -0.24, gx + 0.34, -0.42, u, v))
    for k in range(3):
        marks = np.minimum(marks, segment(-0.55 + k * 0.09, -0.04, -0.55 + k * 0.09, 0.22, u, v))
    ch = (nz(120, 684, octaves=2) * 0.7 + 0.5)
    img = add(img, C("#f4f2ec"), smooth(marks - 0.012) * smooth(slate) * 0.8 * ch)
    # the stub itself
    st = rotated_poly([(0.05, 0.3), (0.62, 0.3), (0.62, 0.46), (0.05, 0.46)], 0.33, 0.38, -0.5)
    stub = poly(st)
    img = piece(img, stub, "#a8a49a", "#fbfaf4", "#ffffff", 0.08, tex=0.9 + 0.2 * nz(70, 685))
    img = add(img, C("#f4f2ec"), np.exp(-np.hypot(x - 0.0, y - 0.62) / 0.12) * 0.0)
    img = add(img, C("#e8e8e4"), sparks(26, 686, (-0.2, 0.2, 0.6, 0.8), (0.003, 0.006)) * 0.5)
    return finish(img, 68, exposure=1.4, grade=(1.0, 1.0, 1.02))
