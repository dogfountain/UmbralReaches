"""Kindling icons: upgrades, oaths, path nodes, unlocks, orb cores. Category "kindling"."""
import numpy as np

from motifs import *  # noqa: F401,F403
from registry import recipe


def K(name):
    return recipe("kindling", name)


@K("hearth")
def hearth():
    img = scene("#080505", "#1c0e07", 200, "#4a2210", 0.5, (0, 0.2), "#c0501a", 0.8)
    # ring of fire-stones and crossed logs
    for ang in (0.35, -0.35):
        u, v = rot(0, 0.52, ang)
        sd = stadium(0, 0, 0.62, 0.085, u, v)
        img = solid(img, sd, "#1a0d06", "#6a3a1a", "#ffb070", 0.08, texture=0.5, seed=201, glowc=C("#ff5a10"), glowamt=0.5)
    img = fire(img, 0.0, 0.42, 0.95, 0.34, 202)
    for i in range(7):
        a = np.pi * (0.05 + 0.9 * i / 6)
        cx, cy = 0.8 * np.cos(a) * 0.95, 0.72 + 0.14 * np.sin(a) * 0.4
        sd = ellipse(cx, 0.78 + 0.02 * (i % 2), 0.13, 0.095)
        img = solid(img, sd, "#1c1815", "#6a6058", "#e0c8a8", 0.07, texture=0.4, seed=210 + i, glowc=C("#ff6a20"), glowamt=0.35)
    img = add(img, C("#ffb14a"), sparks(34, 203, (-0.5, -0.9, 0.5, 0.3), (0.003, 0.008)) * 0.9)
    return finish(img, 20, grade=(1.06, 0.97, 0.9))


@K("coals")
def coals():
    img = scene("#060403", "#140805", 210, "#3a1408", 0.5)
    n = nz(5.5, 211, octaves=4)
    crack = np.exp(-(np.abs(n - 0.5) / 0.045) ** 2) * ss(-0.95, 0.0, -y * 0 + (y - 0.0) * 0.0 + 0.0) * 1.0
    hot = np.exp(-(np.abs(n - 0.5) / 0.1) ** 2)
    chunk = np.maximum(nz(3.0, 212, octaves=3) * 1.4 - 0.4, 0)
    mound = ellipse(0, 0.35, 0.85, 0.55)
    rock = mix(C("#120a08"), C("#3a2418"), nz(14, 213)) * (0.5 + 0.9 * ss(-0.2, 0.6, 0.6 - y))[..., None]
    img = over(img, rock, smooth(mound))
    img = add(img, C("#ff4a0c"), (hot * 0.55 + crack * 0.9) * smooth(mound)[..., None][..., 0] * (0.5 + 0.9 * ss(0.8, -0.2, y)))
    img = add(img, C("#ffd070"), crack * 0.5 * smooth(mound))
    img = add(img, C("#ff5a10"), np.exp(-np.maximum(mound, 0) / 0.12) * 0.5)
    img = add(img, C("#ff9a3a"), sparks(36, 214, (-0.7, -0.7, 0.7, 0.3), (0.003, 0.008)) * 0.9)
    return finish(img, 21, grade=(1.06, 0.96, 0.9))


@K("will")
def will():
    img = scene("#0a0604", "#1e0f06", 220, "#5a3010", 0.5, (0, 0.0), "#d08020", 0.7)
    img = rays(img, 0, 0.1, 14, "#ffb860", 0.8, 14, 0.5)
    ring = np.abs(circle(0, 0.05, 0.62)) - 0.025
    img = add(img, C("#ff9a2a"), np.exp(-np.maximum(ring, 0) / 0.06) * 0.7)
    img = solid(img, ring, "#6a3a10", "#ffcf80", "#fff4d0", 0.025)
    img = fire(img, 0.0, 0.45, 0.95, 0.3, 221, strength=1.4)
    img = add(img, C("#ffd9a0"), sparks(22, 222, (-0.6, -0.7, 0.6, 0.6), (0.003, 0.007)) * 0.9)
    return finish(img, 22, grade=(1.07, 0.97, 0.88))


@K("cord")
def cord():
    img = scene("#0a0705", "#1c130b", 240, "#4a3418", 0.4, (0, 0), "#b07a30", 0.6)
    # a braided ring of rope with a hanging tassel
    r = np.hypot(x, y + 0.1)
    a = np.arctan2(y + 0.1, x)
    ring_sd = np.abs(r - 0.5) - 0.12
    twist = 0.5 + 0.5 * np.sin(a * 22 + (r - 0.5) * 38)
    rope = mix(C("#4a2f14"), C("#d9a45a"), np.clip(twist * (0.5 + 0.6 * ss(0.12, -0.12, ring_sd + 0.0)), 0, 1))
    d, sp, h = bevel(ring_sd, 0.12, relief=0.6)
    rope = rope * (0.5 + 0.8 * d[..., None]) + C("#ffe0a0") * sp[..., None] * 0.3
    img = over(add(img, C("#e0a040"), np.exp(-np.maximum(ring_sd, 0) / 0.08) * 0.3), rope, smooth(ring_sd))
    knot = circle(0, 0.4, 0.13)
    img = solid(img, knot, "#3a220e", "#d09a50", "#ffe8b0", 0.13, texture=0.3, seed=241)
    for tx in (-0.07, 0.0, 0.07):
        sd = stadium(tx, 0.68, 0.015, 0.14, y * 0 + x, y) if False else box(tx, 0.7, 0.03, 0.14)
        img = solid(img, sd, "#3a220e", "#c8904a", "#ffe0a0", 0.03)
    img = add(img, C("#ffd9a0"), sparks(16, 242, (-0.7, -0.8, 0.7, 0.8), (0.003, 0.006)) * 0.7)
    return finish(img, 24, grade=(1.05, 0.98, 0.9))


@K("hollow")
def hollow():
    img = scene("#04030a", "#0e0a1c", 250, "#2a2058", 0.6, (0, -0.1), "#4a3aa0", 0.6, 30)
    # a hood and a face of nothing, two cold eyes
    head = ellipse(0, -0.05, 0.46, 0.58)
    d, sp, h = bevel(head, 0.35, relief=0.6)
    cloth = mix(C("#08060f"), C("#3a3470"), d) * (0.8 + 0.4 * nz(20, 251)[..., None])
    img = add(img, C("#6a5ad0"), np.exp(-np.maximum(head, 0) / 0.1) * 0.5)
    img = over(img, cloth, smooth(head))
    face = ellipse(0, 0.0, 0.27, 0.36)
    img = over(img, C("#010005"), smooth(face))
    img = add(img, C("#6a5ad0"), np.exp(-np.abs(face) / 0.02) * 0.5)
    for ex in (-0.11, 0.11):
        e = np.hypot((x - ex) / 1.0, (y + 0.06) / 1.5) - 0.045
        img = add(img, C("#b8a8ff"), np.exp(-np.maximum(e, 0) / 0.05) * 0.9)
        img = over(img, C("#ffffff"), smooth(e))
    mouth = np.abs(circle(0, 0.5, 0.18)) - 0.01
    img = add(img, C("#8a7aff"), smooth(mouth) * (y > 0.3) * 0.0)
    return finish(img, 25, grade=(1.0, 0.97, 1.06))


@K("door")
def door():
    img = scene("#05070c", "#0c0e14", 270, "#243050", 0.4, (0, 0.1), "#d08a30", 0.6, 20)
    frame = np.maximum(np.abs(x) - 0.5, np.maximum(-0.62 - y, y - 0.78))
    arch = np.minimum(frame, np.maximum(np.hypot(x, y + 0.12) - 0.5, y - 0.0 + 0.0 * x + 5.0 * (y > -0.12) * 0))
    arch = np.where(y < -0.12, np.hypot(x, y + 0.12) - 0.5, np.maximum(np.abs(x) - 0.5, y - 0.78))
    wall = box(0, 0, 0.9, 0.9)
    img = over(img, mix(C("#14120f"), C("#3a342c"), nz(14, 271)) * (0.7 + 0.5 * nz(60, 272)[..., None]), smooth(wall) * 0.0 + 0.0)
    # warm light beyond the door
    inner = np.where(y < -0.12, np.hypot(x, y + 0.12) - 0.4, np.maximum(np.abs(x) - 0.4, y - 0.78))
    light = mix(C("#ffd890"), C("#ff8a1a"), ss(-0.5, 0.8, y)) * (0.8 + 0.4 * np.exp(-np.hypot(x * 1.4, y - 0.4) / 0.4))[..., None]
    img = add(img, C("#ff9a3a"), np.exp(-np.maximum(arch, 0) / 0.1) * 0.55)
    img = solid(img, arch, "#14100c", "#5a4a38", "#d8b890", 0.1, texture=0.4, seed=273)
    img = over(img, light, smooth(inner))
    # the door leaf, swung open: a dark slab in perspective on the left
    leaf = np.array([(-0.4, -0.45), (-0.05, -0.38), (-0.05, 0.7), (-0.4, 0.78)])
    mask = np.ones((N, N))
    sd = np.full((N, N), -9.0)
    for i in range(4):
        a_, b_ = leaf[i], leaf[(i + 1) % 4]
        e = b_ - a_
        nrm = np.array([e[1], -e[0]]) / np.linalg.norm(e)
        sd = np.maximum(sd if i else -9 + 0 * x, (x - a_[0]) * nrm[0] + (y - a_[1]) * nrm[1])
    img = solid(img, sd, "#0a0806", "#4a3a2c", "#b89870", 0.08, texture=0.4, seed=274)
    img = add(img, C("#ffd9a0"), sparks(18, 275, (-0.3, -0.5, 0.4, 0.8), (0.003, 0.007)) * 0.6)
    # boundary of the beam on the ground
    beam = np.maximum(np.abs(x) - 0.35 - (y - 0.7) * 0.9, 0.7 - y)
    img = add(img, C("#ff9a3a"), smooth(beam) * 0.0)
    return finish(img, 27, grade=(1.03, 0.98, 0.95))


@K("bramble")
def bramble():
    img = scene("#040806", "#0a140d", 280, "#1c4a28", 0.5, (0, 0), "#1a5a26", 0.35)
    rng = np.random.default_rng(281)
    for k in range(4):
        a0 = k * np.pi / 2 + 0.4
        pts = [(0.62 * np.cos(a0 + t * 1.5 + 0.2 * np.sin(t * 9)), 0.62 * np.sin(a0 + t * 1.5 + 0.2 * np.sin(t * 9))) for t in np.linspace(0, 1, 18)]
        sd = polyline(pts) - 0.035
        img = solid(img, sd, "#0a1c0c", "#4aa04a", "#d0ffc8", 0.04, halo="#3ac04a", halo_amt=0.3)
        for t in np.linspace(0.1, 0.9, 5):
            p = pts[int(t * 17)]
            ang = np.arctan2(p[1], p[0]) + rng.choice([-1, 1]) * 0.9
            tip = (p[0] + 0.2 * np.cos(ang), p[1] + 0.2 * np.sin(ang))
            ts = segment(p[0], p[1], tip[0], tip[1]) - 0.02
            img = over(img, C("#d8c8b0"), smooth(ts) * 0.9)
            img = add(img, C("#ff4a3a"), np.exp(-np.hypot(x - tip[0], y - tip[1]) / 0.02) * 0.6)
    img = orb(img, 0, 0, 0.17, "#0a1a10", "#6aff8a", halo="#2a9a4a", halo_amt=0.7)
    return finish(img, 28, grade=(0.95, 1.04, 0.95))


@K("skull")
def skull():
    img = scene("#05080a", "#0c1216", 290, "#1c3a40", 0.5, (0, 0), "#3a8a90", 0.7)
    cran = ellipse(0, -0.12, 0.5, 0.48)
    jaw = box(0, 0.38, 0.28, 0.2)
    shape = np.minimum(cran, jaw + 0.0)
    img = add(img, C("#5ab8c0"), np.exp(-np.maximum(shape, 0) / 0.1) * 0.35)
    img = solid(img, shape, "#3a4440", "#d8d4c0", "#ffffff", 0.3, texture=0.35, seed=291, shine=12)
    for ex in (-0.2, 0.2):
        e = ellipse(ex, -0.08, 0.14, 0.16)
        img = over(img, C("#020608"), smooth(e))
        img = add(img, C("#5ae0e8"), np.exp(-np.hypot(x - ex, y + 0.06) / 0.05) * 0.55)
    nose = np.maximum(np.abs(x) - 0.05 + (y - 0.12) * 0.3, np.abs(y - 0.17) - 0.07)
    img = over(img, C("#020608"), smooth(nose))
    for tx in np.linspace(-0.2, 0.2, 5):
        sd = box(tx, 0.45, 0.012, 0.1)
        img = over(img, C("#10181a"), smooth(sd) * 0.85)
    return finish(img, 29, grade=(0.96, 1.02, 1.04))


@K("crown")
def crown():
    img = scene("#07040c", "#150a1f", 300, "#40205a", 0.5, (0, -0.1), "#a07a20", 0.7, 20)
    band = box(0, 0.32, 0.55, 0.13)
    pts_ = [(-0.55, 0.2), (-0.62, -0.5), (-0.3, -0.05), (-0.0, -0.62), (0.3, -0.05), (0.62, -0.5), (0.55, 0.2)]
    sd = np.full((N, N), -9.0)
    # polygon union by convexity decomposition: triangles fan from base centre
    base = np.array([0.0, 0.25])
    tri_sd = None
    for i in range(len(pts_) - 1):
        a_, b_ = np.array(pts_[i]), np.array(pts_[i + 1])
        t = tri(base, a_, b_)
        tri_sd = t if tri_sd is None else np.minimum(tri_sd, t)
    shape = np.minimum(tri_sd, band)
    img = solid(img, shape, "#4a2c06", "#f0b83a", "#fff6c8", 0.1, halo="#ffc040", halo_amt=0.5, halo_r=0.1, glowc=C("#a06a10"), glowamt=0.3)
    for gx, col in ((-0.3, "#ff3a4a"), (0.0, "#4ab0ff"), (0.3, "#ff3a4a")):
        g = circle(gx, 0.32, 0.065)
        img = solid(img, g, "#200808", col, "#ffffff", 0.065, halo=col, halo_amt=0.5, halo_r=0.05)
    for px_, py_ in pts_[1:-1:2] + [(0.0, -0.62)]:
        img = orb(img, px_, py_ - 0.02, 0.055, "#8a5a10", "#fff0b0", halo="#ffc040", halo_amt=0.4)
    return finish(img, 30, grade=(1.04, 0.97, 0.94))


def tri(a, b, c):
    """Signed distance (approx, convex) to a triangle."""
    def edge(p0, p1, third):
        e = p1 - p0
        n = np.array([e[1], -e[0]]) / (np.linalg.norm(e) + 1e-9)
        if np.dot(n, third - p0) > 0:
            n = -n
        return (x - p0[0]) * n[0] + (y - p0[1]) * n[1]
    return np.maximum(np.maximum(edge(a, b, c), edge(b, c, a)), edge(c, a, b))


@K("candle")
def candle():
    img = scene("#080604", "#1a1008", 330, "#4a3016", 0.5, (0, -0.35), "#d0801a", 0.55)
    wax = box(0, 0.35, 0.17, 0.5)
    img = solid(img, wax, "#6a5a40", "#f5e8c8", "#ffffff", 0.17, shine=10, glowc=C("#ff9a3a"), glowamt=0.2)
    drip = stadium(0.1, 0.0, 0.03, 0.12, y, x) if False else box(0.17, -0.05, 0.03, 0.12)
    img = solid(img, drip, "#8a7a5a", "#fff4d8", "#ffffff", 0.03)
    img = fire(img, 0.0, -0.1, 0.5, 0.12, 331, strength=1.4)
    img = add(img, C("#ffd070"), np.exp(-np.hypot(x, y + 0.2) / 0.25) * 0.5)
    img = solid(img, box(0, 0.84, 0.4, 0.06), "#1a140e", "#6a5a48", "#c8b090", 0.06)
    return finish(img, 33, grade=(1.06, 0.97, 0.9))


@K("lantern")
def lantern():
    img = scene("#060608", "#0e0b0a", 340, "#3a2a18", 0.4, (0, 0.1), "#d08a28", 0.6)
    body = ellipse(0, 0.2, 0.38, 0.42)
    img = add(img, C("#ffa83a"), np.exp(-np.maximum(body, 0) / 0.12) * 0.6)
    glass = mix(C("#ff9a2a"), C("#fff0b8"), np.exp(-np.hypot(x, y - 0.22) / 0.3))
    img = over(img, glass, smooth(body))
    img = fire(img, 0.0, 0.34, 0.5, 0.13, 341, strength=0.5)
    for bx in (-0.2, 0.0, 0.2):
        sd = segment(bx * 1.3, -0.22, bx * 0.9, 0.62) - 0.014
        img = over(img, C("#2a1c10") * 1.1, smooth(sd) * smooth(body + 0.04))
    img = solid(img, box(0, -0.25, 0.2, 0.05), "#1a100a", "#7a5a38", "#e0c090", 0.05)
    img = solid(img, box(0, 0.65, 0.22, 0.05), "#1a100a", "#7a5a38", "#e0c090", 0.05)
    hook = np.abs(circle(0, -0.5, 0.2)) - 0.02
    hook = np.where(y < -0.3, hook, 9.0)
    img = solid(img, hook, "#1a100a", "#8a6a40", "#e8cc98", 0.02)
    return finish(img, 34, grade=(1.05, 0.97, 0.9))


@K("waystone")
def waystone():
    img = scene("#04080b", "#0a1218", 350, "#183a48", 0.5, (0, 0), "#2a90b0", 0.7, 40)
    pts = [(-0.3, 0.7), (-0.38, -0.2), (-0.12, -0.7), (0.2, -0.62), (0.4, -0.1), (0.3, 0.7)]
    sd = np.full((N, N), -9.0)
    c0 = np.array([0.0, 0.0])
    t_ = None
    for i in range(len(pts)):
        a_, b_ = np.array(pts[i]), np.array(pts[(i + 1) % len(pts)])
        tt = tri(c0, a_, b_)
        t_ = tt if t_ is None else np.minimum(t_, tt)
    wx, wy = warp(0.015, 6, 351)
    img = add(img, C("#3ac0e0"), np.exp(-np.maximum(t_, 0) / 0.12) * 0.4)
    img = solid(img, t_, "#0c1418", "#5a6a70", "#c8e8f0", 0.2, texture=0.5, seed=352, relief=0.7) if False else solid(img, t_, "#0c1418", "#5a6a70", "#c8e8f0", 0.2, texture=0.5, seed=352)
    rune = [(0.0, -0.4), (0.0, 0.3)], [(-0.15, -0.15), (0.15, 0.05)], [(0.15, -0.15), (-0.15, 0.05)]
    for p0, p1 in rune:
        sd = segment(p0[0], p0[1], p1[0], p1[1]) - 0.014
        img = add(img, C("#4ae8ff"), np.exp(-np.maximum(sd, 0) / 0.05) * 0.7)
        img = over(img, C("#e8ffff"), smooth(sd))
    return finish(img, 35, grade=(0.95, 1.02, 1.05))


@K("core")
def core():
    img = scene("#05030c", "#0e0820", 360, "#301a66", 0.6, (0, 0), "#6a40d0", 0.7)
    cradle = np.abs(ellipse(0, 0.35, 0.55, 0.2)) - 0.04
    img = orb(img, 0, -0.05, 0.4, "#2a1090", "#a98bff", halo="#7a50ff", halo_amt=1.0, swirl=0.9, seed=361)
    img = solid(img, np.where(y > 0.35, cradle, 9.0), "#14102a", "#6a5aa8", "#d8d0ff", 0.04)
    for ang in (0.2, 2.0, 4.1):
        a = np.arctan2(y + 0.05, x)
        arc = np.abs(np.hypot(x, y + 0.05) - 0.56) - 0.012
        img = add(img, C("#c8b8ff"), np.exp(-np.maximum(arc, 0) / 0.03) * 0.35 * (np.cos(a - ang) > 0.8))
    return finish(img, 36, grade=(1.0, 0.96, 1.06))


@K("prism")
def prism():
    img = scene("#04060b", "#0a1018", 370, "#1c3a50", 0.5, (0, 0), "#4a90c0", 0.7, 30)
    pr = tri(np.array([0.0, -0.6]), np.array([-0.5, 0.45]), np.array([0.5, 0.45]))
    # a white beam in, a spectrum out
    beam = segment(-0.95, 0.15, -0.15, 0.0) - 0.02
    img = add(img, C("#ffffff"), np.exp(-np.maximum(beam, 0) / 0.04) * 0.5)
    img = over(img, C("#ffffff"), smooth(beam))
    for i, col in enumerate(("#ff4a3a", "#ffa63a", "#ffe83a", "#4aff6a", "#3ac0ff", "#7a5aff")):
        yy = -0.1 + i * 0.12
        sd = segment(0.2, 0.05, 0.95, yy + 0.05) - 0.022
        img = add(img, C(col), np.exp(-np.maximum(sd, 0) / 0.04) * 0.55)
        img = over(img, C(col), smooth(sd) * 0.9)
    img = solid(img, pr, "#18303c", "#a0e0f8", "#ffffff", 0.3, halo="#7ad0ff", halo_amt=0.5, shine=8)
    img = add(img, C("#e0f8ff"), (ss(0.02, 0.0, np.abs(pr + 0.18)) * 0.25) * smooth(pr))
    return finish(img, 37, grade=(0.97, 1.02, 1.05))


@K("lodestar")
def lodestar():
    img = scene("#0a0804", "#1a1408", 380, "#4a3a14", 0.5, (0, 0), "#d0a020", 0.7, 25)
    img = rays(img, 0, 0, 8, "#ffd860", 0.9, 30, 0.9, np.pi / 2)
    pts = []
    for i in range(8):
        r = 0.72 if i % 2 == 0 else 0.16
        a = i * np.pi / 4 - np.pi / 2
        pts.append((r * np.cos(a), r * np.sin(a)))
    t_ = None
    c0 = np.array([0.0, 0.0])
    for i in range(8):
        tt = tri(c0, np.array(pts[i]), np.array(pts[(i + 1) % 8]))
        t_ = tt if t_ is None else np.minimum(t_, tt)
    img = solid(img, t_, "#6a4a10", "#ffd84a", "#fff8d0", 0.1, halo="#ffc040", halo_amt=0.8, halo_r=0.1)
    img = orb(img, 0, 0, 0.1, "#c08a20", "#fff6d0", halo="#ffd860", halo_amt=0.6)
    return finish(img, 38, grade=(1.06, 0.99, 0.88))


@K("cinder")
def cinder():
    img = scene("#080403", "#180804", 390, "#4a1a0a", 0.5, (0, 0.1), "#d04a10", 0.7)
    lump = circle(0, 0.05, 0.46)
    wx, wy = warp(0.05, 4, 391)
    lump = circle(0, 0.05, 0.46, wx, wy)
    rock = mix(C("#150b08"), C("#4a2a1c"), nz(9, 392)) * (0.6 + 0.8 * nz(30, 393)[..., None])
    img = add(img, C("#ff5a10"), np.exp(-np.maximum(lump, 0) / 0.14) * 0.8)
    img = over(img, rock, smooth(lump))
    cr = cracks(394, 6.5, 0.05)
    img = add(img, C("#ff7a20"), cr * smooth(lump) * 1.2)
    img = add(img, C("#ffd070"), cr ** 3 * smooth(lump) * 0.9)
    img = add(img, C("#ffb04a"), sparks(34, 395, (-0.8, -0.9, 0.8, 0.5), (0.003, 0.008)) * 0.9)
    return finish(img, 39, grade=(1.06, 0.96, 0.9))
