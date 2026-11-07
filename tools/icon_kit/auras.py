"""HUD buff / debuff icons (category "aura"). Bold single motifs: they are read at about 30 px."""
import numpy as np

from motifs import *  # noqa: F401,F403
from registry import recipe


def A(name):
    return recipe("aura", name)


def _dark(top, bottom, seed, glow, glow_col):
    return scene(top, bottom, seed, glow, 0.5, (0, 0), glow_col, 0.7)


@A("flame")
def flame():
    img = _dark("#080403", "#1a0905", 500, "#4a1a0a", "#d0501a")
    img = fire(img, 0.0, 0.5, 1.15, 0.42, 501, strength=1.3)
    return finish(img, 50, grade=(1.06, 0.97, 0.9))


@A("ward")
def ward():
    img = _dark("#060608", "#120d08", 510, "#4a3216", "#d08a28")
    img = add(img, C("#ffb347"), np.exp(-np.abs(np.hypot(x, y) - 0.78) / 0.03) * 0.8)
    body = ellipse(0, 0.1, 0.4, 0.45)
    img = over(add(img, C("#ffa83a"), np.exp(-np.maximum(body, 0) / 0.1) * 0.6),
               mix(C("#ff9a2a"), C("#fff0b8"), np.exp(-np.hypot(x, y - 0.1) / 0.3)), smooth(body))
    img = solid(img, box(0, -0.4, 0.28, 0.06), "#1a100a", "#8a6a40", "#f0d090", 0.06)
    img = solid(img, box(0, 0.6, 0.26, 0.05), "#1a100a", "#8a6a40", "#f0d090", 0.05)
    return finish(img, 51, grade=(1.05, 0.97, 0.9))


@A("quick")
def quick():
    img = _dark("#080604", "#1a0f06", 520, "#503010", "#d08a20")
    for i, ox in enumerate((-0.28, 0.12)):
        pts = [(ox - 0.15, -0.65), (ox + 0.3, 0.0), (ox - 0.15, 0.65)]
        d = polyline(pts) - 0.07
        img = add(img, C("#ff9a2a"), np.exp(-np.maximum(d, 0) / 0.08) * 0.6)
        img = solid(img, d, "#c04a10", "#ffe098", "#ffffff", 0.07)
    return finish(img, 52, grade=(1.05, 0.97, 0.9))


@A("riposte")
def riposte():
    img = _dark("#080410", "#150a22", 530, "#3a1a66", "#8a40d0")
    for ang, w in ((-0.78, 0.05), (0.78, 0.04)):
        u, v = rot(0, 0, ang)
        sd = np.maximum(np.abs(v) - w * (1 - ss(-0.2, 0.8, u) * 0.9), np.abs(u) - 0.8)
        img = add(img, C("#b070ff"), np.exp(-np.maximum(sd, 0) / 0.06) * 0.6)
        img = solid(img, sd, "#4a2a80", "#e8d8ff", "#ffffff", 0.05)
        img = solid(img, box(0, 0, 0.03, 0.2, *rot(-0.5, 0, 0, u * np.cos(ang) - v * np.sin(ang), u * np.sin(ang) + v * np.cos(ang))) if False else np.maximum(np.abs(u + 0.5) - 0.03, np.abs(v) - 0.2), "#3a2a10", "#c8a050", "#fff0b0", 0.03)
    img = add(img, C("#ffe8ff"), sparks(12, 531, (-0.4, -0.4, 0.5, 0.5), (0.004, 0.01)))
    return finish(img, 53, grade=(1.02, 0.96, 1.06))


@A("chain")
def chain():
    img = _dark("#06040c", "#100a1e", 540, "#301a5a", "#8a40d0")
    for cx in (-0.28, 0.28):
        sd = np.abs(stadium(cx, 0, 0.34, 0.24)) - 0.07
        img = add(img, C("#a060ff"), np.exp(-np.maximum(sd, 0) / 0.06) * 0.55)
        img = solid(img, sd, "#2a1a4a", "#a888e8", "#ffffff", 0.07)
    return finish(img, 54, grade=(1.0, 0.96, 1.06))


@A("tide")
def tide():
    img = _dark("#05040c", "#0c0a20", 550, "#241a5a", "#5a40c0")
    for i, yy in enumerate((-0.4, 0.0, 0.4)):
        d = np.abs(y - yy - 0.1 * np.sin(x * 7 + i)) - 0.05
        img = add(img, C("#7a60ff"), np.exp(-np.maximum(d, 0) / 0.06) * 0.5)
        img = over(img, mix(C("#4a38b0"), C("#b8a8ff"), np.clip(0.5 - (y - yy) * 4, 0, 1)), smooth(d))
    return finish(img, 55, grade=(0.98, 0.96, 1.08))


@A("winded")
def winded():
    img = _dark("#06080c", "#0c1218", 560, "#1c3040", "#4a7a98")
    for r, a0, a1 in ((0.62, 0.3, 5.2), (0.38, 1.6, 5.6), (0.18, 0.0, 4.0)):
        ang = np.arctan2(y, x) % (2 * np.pi)
        d = np.abs(np.hypot(x, y) - r) - 0.04
        m = smooth(d) * (ang > a0) * (ang < a1)
        img = add(img, C("#a8c8e8"), np.exp(-np.maximum(d, 0) / 0.05) * 0.3 * ((ang > a0) & (ang < a1)))
        img = over(img, C("#d8ecff"), m)
    return finish(img, 56, grade=(0.96, 1.0, 1.05))


@A("hollow")
def hollow():
    img = _dark("#04030a", "#0e0a1c", 570, "#2a2058", "#4a3aa0")
    head = ellipse(0, -0.05, 0.46, 0.58)
    img = add(img, C("#6a5ad0"), np.exp(-np.maximum(head, 0) / 0.1) * 0.5)
    img = over(img, mix(C("#08060f"), C("#3a3470"), bevel(head, 0.35)[0]), smooth(head))
    face = ellipse(0, 0.0, 0.27, 0.36)
    img = over(img, C("#010005"), smooth(face))
    for ex in (-0.11, 0.11):
        e = np.hypot(x - ex, (y + 0.06) / 1.5) - 0.05
        img = add(img, C("#b8a8ff"), np.exp(-np.maximum(e, 0) / 0.05) * 0.9)
        img = over(img, C("#ffffff"), smooth(e))
    return finish(img, 57, grade=(1.0, 0.97, 1.06))


@A("rime")
def rime():
    img = _dark("#04080e", "#0a1620", 580, "#1c4a68", "#4a9ad0")
    for i in range(3):
        a = i * np.pi / 3
        sd = segment(-0.8 * np.cos(a), -0.8 * np.sin(a), 0.8 * np.cos(a), 0.8 * np.sin(a)) - 0.04
        img = add(img, C("#6ac8ff"), np.exp(-np.maximum(sd, 0) / 0.06) * 0.6)
        img = solid(img, sd, "#4a90c0", "#e8f8ff", "#ffffff", 0.04)
    img = orb(img, 0, 0, 0.12, "#6ac8ff", "#ffffff", halo="#8adaff", halo_amt=0.8)
    return finish(img, 58, grade=(0.95, 1.02, 1.07))


@A("frozen")
def frozen():
    img = _dark("#04080e", "#0a1620", 590, "#1c4a68", "#4a9ad0")
    blk = box(0, 0.02, 0.58, 0.62)
    d, sp, h = bevel(blk, 0.2, relief=0.7)
    ice = mix(C("#1a4a70"), C("#c8ecff"), np.clip(d * 0.9 + (nz(5, 591) - 0.5) * 0.5, 0, 1)) + C("#ffffff") * sp[..., None] * 0.5
    img = add(img, C("#6ac8ff"), np.exp(-np.maximum(blk, 0) / 0.1) * 0.5)
    img = over(img, ice, smooth(blk) * 0.95)
    img = add(img, C("#ffffff"), cracks(592, 4.0, 0.03) * smooth(blk) * 0.5)
    return finish(img, 59, grade=(0.95, 1.02, 1.07))


@A("slow")
def slow():
    img = _dark("#06040c", "#100a1e", 600, "#2a1a5a", "#6a48d0")
    r = np.hypot(x, y)
    ring = np.abs(r - 0.6) - 0.05
    img = add(img, C("#8a68ff"), np.exp(-np.maximum(ring, 0) / 0.06) * 0.5)
    img = solid(img, ring, "#3a2a80", "#c8b8ff", "#ffffff", 0.05)
    for ang, ln in ((-np.pi / 2, 0.42), (0.35, 0.3)):
        sd = segment(0, 0, ln * np.cos(ang), ln * np.sin(ang)) - 0.04
        img = solid(img, sd, "#3a2a80", "#e8e0ff", "#ffffff", 0.04)
    return finish(img, 60, grade=(1.0, 0.96, 1.06))


@A("resonance")
def resonance():
    img = _dark("#080604", "#1a1208", 610, "#4a3416", "#d0a040")
    r = np.hypot(x, y)
    a = np.arctan2(y, x)
    for k, rad in enumerate((0.3, 0.55, 0.8)):
        d = np.abs(r - rad) - 0.03
        side = ss(0.9, 0.3, np.abs(np.sin(a)))
        img = add(img, C("#ffc766"), np.exp(-np.maximum(d, 0) / 0.04) * 0.5 * side)
        img = over(img, C("#ffe8b0"), smooth(d) * side * (0.95 - 0.2 * k))
    img = orb(img, 0, 0, 0.14, "#c08a20", "#fff0c0", halo="#ffc040", halo_amt=0.8)
    return finish(img, 61, grade=(1.05, 0.98, 0.9))


@A("surge")
def surge():
    img = _dark("#06040c", "#0e0a22", 620, "#2a1a6a", "#7a50e8")
    pts = [(0.25, -0.85), (-0.35, 0.1), (0.15, 0.1), (-0.25, 0.85)]
    d = polyline(pts) - 0.06
    img = add(img, C("#a888ff"), np.exp(-np.maximum(d, 0) / 0.09) * 0.8)
    img = solid(img, d, "#6a48d8", "#f0e8ff", "#ffffff", 0.06)
    return finish(img, 62, grade=(1.0, 0.96, 1.06))


@A("shaken")
def shaken():
    img = _dark("#0a0405", "#1a0a0c", 630, "#5a1a1c", "#d04a40")
    pts = [(-0.2, -0.85), (0.2, -0.1), (-0.2, 0.3), (0.25, 0.85)]
    d = polyline(pts) - 0.05
    img = add(img, C("#ff5a4a"), np.exp(-np.maximum(d, 0) / 0.08) * 0.7)
    img = solid(img, d, "#8a2a24", "#ffd0c0", "#ffffff", 0.05)
    return finish(img, 63, grade=(1.06, 0.95, 0.94))


@A("broken")
def broken():
    img = _dark("#0a0605", "#1a110c", 640, "#4a2a1a", "#a06a3a")
    for sgn in (-1, 1):
        sd = np.maximum(np.abs(x - sgn * 0.3 - (y * 0.2)) - 0.26, np.abs(y) - 0.5)
        img = solid(img, sd, "#2a1a10", "#9a7a5a", "#f0d8b0", 0.1, texture=0.4, seed=641)
    d = polyline([(-0.05, -0.75), (0.1, -0.2), (-0.1, 0.2), (0.05, 0.75)]) - 0.03
    img = over(add(img, C("#ff7a2a"), np.exp(-np.maximum(d, 0) / 0.05) * 0.6), C("#ffd89a"), smooth(d))
    return finish(img, 64, grade=(1.05, 0.97, 0.92))


@A("silenced")
def silenced():
    img = _dark("#06060a", "#101018", 650, "#2a2a40", "#5a5a90")
    r = np.hypot(x, y)
    ring = np.abs(r - 0.6) - 0.07
    img = add(img, C("#9a9aff"), np.exp(-np.maximum(ring, 0) / 0.06) * 0.35)
    img = solid(img, ring, "#3a3a60", "#d0d0f8", "#ffffff", 0.07)
    d = segment(-0.42, -0.42, 0.42, 0.42) - 0.07
    img = solid(img, d, "#3a3a60", "#d0d0f8", "#ffffff", 0.07)
    return finish(img, 65, grade=(0.98, 0.98, 1.05))


@A("mark")
def mark():
    img = _dark("#080410", "#150a22", 660, "#3a1a66", "#a040e0")
    r = np.hypot(x, y)
    for rad in (0.55, 0.3):
        d = np.abs(r - rad) - 0.03
        img = add(img, C("#c070ff"), np.exp(-np.maximum(d, 0) / 0.05) * 0.5)
        img = over(img, C("#f0d8ff"), smooth(d))
    for ang in (0, np.pi / 2, np.pi, -np.pi / 2):
        sd = segment(0.55 * np.cos(ang), 0.55 * np.sin(ang), 0.85 * np.cos(ang), 0.85 * np.sin(ang)) - 0.03
        img = over(img, C("#f0d8ff"), smooth(sd))
    img = orb(img, 0, 0, 0.1, "#a040e0", "#ffffff", halo="#c070ff", halo_amt=0.8)
    return finish(img, 66, grade=(1.02, 0.95, 1.07))


@A("ember_scar")
def ember_scar():
    img = _dark("#080403", "#1a0905", 670, "#4a1a0a", "#d0501a")
    for off in (-0.25, 0.0, 0.25):
        d = segment(-0.5 + off, -0.7, 0.4 + off, 0.7) - 0.05
        d2 = polyline([(-0.5 + off, -0.7), (-0.2 + off, -0.2), (-0.35 + off, 0.15), (0.4 + off, 0.7)]) - 0.045
        img = add(img, C("#ff5a10"), np.exp(-np.maximum(d2, 0) / 0.07) * 0.8)
        img = over(img, mix(C("#ff7a20"), C("#fff0b0"), 0.6), smooth(d2 + 0.01))
    return finish(img, 67, grade=(1.06, 0.96, 0.9))


@A("sundered")
def sundered():
    img = _dark("#080410", "#150a22", 680, "#3a1a66", "#a040e0")
    for sgn in (-1, 1):
        sd = np.maximum(np.abs(x - sgn * 0.28) - 0.24, np.abs(y - sgn * 0.0 * 1) - 0.55)
        sd = np.maximum(sd, sgn * (x - 0.0) * -1 * 0 - 0.0)
        img = solid(img, sd, "#2a1a4a", "#a888e8", "#ffffff", 0.1, halo="#a060ff", halo_amt=0.4)
    d = polyline([(0.0, -0.8), (-0.1, -0.3), (0.1, 0.1), (-0.05, 0.8)]) - 0.03
    img = over(add(img, C("#e0b0ff"), np.exp(-np.maximum(d, 0) / 0.06) * 0.8), C("#ffffff"), smooth(d))
    return finish(img, 68, grade=(1.0, 0.96, 1.06))


@A("rested")
def rested():
    img = _dark("#05050c", "#0c0c20", 690, "#242a5a", "#6a70d0")
    moon = circle(-0.05, 0.0, 0.5)
    cut = circle(0.2, -0.1, 0.42)
    sd = np.maximum(moon, -cut)
    img = add(img, C("#a8b0ff"), np.exp(-np.maximum(sd, 0) / 0.1) * 0.6)
    img = solid(img, sd, "#6a70c0", "#f0f0ff", "#ffffff", 0.15)
    img = add(img, C("#e8e8ff"), sparks(10, 691, (0.0, -0.8, 0.8, 0.6), (0.004, 0.01)))
    return finish(img, 69, grade=(0.98, 0.98, 1.06))
