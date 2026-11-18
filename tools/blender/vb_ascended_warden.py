"""The Ascended Warden (Aurel, Hierarch), modelled in Blender in the villagers' style (18 Nov). Run:
    blender -b -P tools/blender/vb_ascended_warden.py -- [--out art/models/bosses/vb_ascended_warden.glb] [--renders <dir>] [--no-ao]

Its own design (core/enemy/ascended_warden.gd, warden_body.gd): the final boss, a towering hollowed priest that
floats, nothing stepping under the bell of its robe but the light of the door it holds open pouring out of the hem.
Ivory and gold: an ivory bell robe banded in gold with a hem of small bells; a stiff gold collar rising behind the
neck; an ivory hood over a smooth gold mask, light in its eye slits; a great gold mandorla behind it, an almond of
rays with long rays swept out from the shoulders like wings (its halo, the weak point, a sun-disc at its heart); long
hanging sleeves lined in slate blue; long gilded hands, open; the great key of the door on a chain at its hip.

Silhouette: tall and narrow-waisted over a wide floating bell, the mandorla's wings making it a star from afar.

Rig space: x right, y up, z back, facing -Z, metres (built at a person's scale; the game scales it up).
"""
import bpy
import math
import os
import sys
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import vb_kit as K
from vb_kit import V, TAU, smooth

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(name, default=None):
    return ARGS[ARGS.index(name) + 1] if name in ARGS else default


OUT = os.path.join(K.ROOT, arg("--out", "art/models/bosses/vb_ascended_warden.glb"))
RENDERS = arg("--renders")
DO_AO = "--no-ao" not in ARGS

IVORY = np.array([0.7, 0.66, 0.58])       # (0.8 washed out under its own halo light on the deck)
IVORY_LT = np.array([0.78, 0.74, 0.65])
IVORY_DK = np.array([0.52, 0.48, 0.42])
GOLD = np.array([0.8, 0.6, 0.26])
GOLD_LT = np.array([0.9, 0.74, 0.38])
GOLD_DK = np.array([0.55, 0.39, 0.16])
LINING = np.array([0.26, 0.3, 0.4])
HOLLOW = (0.03, 0.028, 0.03)
LIGHT = (1.0, 0.92, 0.7)
SUN = (1.0, 0.82, 0.48)

HEM = 0.2                     # it floats: the hem a hand above the floor
SKIRT_N = 8
SKIRT_Y = [1.0, 0.72, 0.45, HEM]
SKIRT_R = [0.18, 0.31, 0.45, 0.58]
MC = V(0, 1.72, 0.2)          # the mandorla's centre


def skirt_pt(i, lvl):
    a = TAU * i / SKIRT_N
    return V(math.sin(a) * SKIRT_R[lvl], SKIRT_Y[lvl], -math.cos(a) * SKIRT_R[lvl])


BONES = {
    "root": (V(0, 0, 0), V(0, 0.12, 0), None, False),
    "pelvis": (V(0, 1.0, 0), V(0, 1.12, 0), "root", True),
    "spine": (V(0, 1.12, 0), V(0, 1.3, 0), "pelvis", True),
    "chest": (V(0, 1.3, 0), V(0, 1.5, 0), "spine", True),
    "neck": (V(0, 1.5, 0), V(0, 1.6, -0.01), "chest", True),
    "head": (V(0, 1.6, -0.01), V(0, 1.84, -0.01), "neck", True),
    "halo": (MC + V(0, -0.1, 0), MC + V(0, 0.2, 0), "chest", True),
    "key_0": (V(-0.2, 0.97, -0.1), V(-0.23, 0.76, -0.13), "pelvis", True),
    "key_1": (V(-0.23, 0.76, -0.13), V(-0.24, 0.56, -0.15), "key_0", True),
}
for s, tag in ((-1.0, "l"), (1.0, "r")):
    BONES.update({
        "clav_" + tag: (V(s * 0.04, 1.5, 0.0), V(s * 0.2, 1.5, 0.0), "chest", True),
        "upper_" + tag: (V(s * 0.2, 1.5, 0.0), V(s * 0.26, 1.19, 0.02), "clav_" + tag, True),
        "fore_" + tag: (V(s * 0.26, 1.19, 0.02), V(s * 0.29, 0.91, -0.02), "upper_" + tag, True),
        "hand_" + tag: (V(s * 0.29, 0.91, -0.02), V(s * 0.3, 0.82, -0.04), "fore_" + tag, True),
        "fingers_" + tag: (V(s * 0.3, 0.82, -0.04), V(s * 0.305, 0.68, -0.05), "hand_" + tag, True),
        "sleeve_" + tag: (V(s * 0.275, 1.05, 0.0), V(s * 0.28, 0.66, 0.02), "fore_" + tag, True),
    })
for i in range(SKIRT_N):
    for lvl in range(3):
        BONES["skirt_%d_%d" % (i, lvl)] = (skirt_pt(i, lvl), skirt_pt(i, lvl + 1), "pelvis" if lvl == 0 else "skirt_%d_%d" % (i, lvl - 1), True)


# --- weights -----------------------------------------------------------------------------------------------

def w_spine(p):
    y = p[1]
    pts = [("pelvis", 1.04), ("spine", 1.22), ("chest", 1.42), ("neck", 1.57)]
    for k in range(len(pts) - 1):
        (b0, y0), (b1, y1) = pts[k], pts[k + 1]
        if y0 <= y <= y1:
            t = (y - y0) / (y1 - y0)
            return {b0: 1.0 - t, b1: t}
    return {"pelvis": 1.0} if y < 1.04 else {"neck": 1.0}


def w_skirt(p):
    a = math.atan2(p[0], -p[2])
    if a < 0:
        a += TAU
    f = a / (TAU / SKIRT_N)
    i0 = int(math.floor(f)) % SKIRT_N
    i1 = (i0 + 1) % SKIRT_N
    t = f - math.floor(f)
    y = p[1]
    if y > SKIRT_Y[0] - 0.02:
        return w_spine(p)
    out = {}
    for lvl in range(3):
        y0, y1 = SKIRT_Y[lvl], SKIRT_Y[lvl + 1]
        if y1 <= y <= y0 or (lvl == 2 and y < y1):
            u = min(1.0, max(0.0, (y0 - y) / (y0 - y1)))
            wl = [(lvl, 1.0 - 0.5 * u), (min(lvl + 1, 2), 0.5 * u)] if lvl < 2 else [(2, 1.0)]
            for lv, ww in wl:
                out["skirt_%d_%d" % (i0, lv)] = out.get("skirt_%d_%d" % (i0, lv), 0.0) + ww * (1.0 - t)
                out["skirt_%d_%d" % (i1, lv)] = out.get("skirt_%d_%d" % (i1, lv), 0.0) + ww * t
            break
    return out


def w_arm(tag):
    def f(p):
        y = p[1]
        if y > 1.19:
            t = smooth(1.5, 1.26, y)
            return {"clav_" + tag: 1.0 - t, "upper_" + tag: t} if y > 1.36 else {"upper_" + tag: 1.0}
        t = smooth(1.23, 1.13, y)
        return {"upper_" + tag: 1.0 - t, "fore_" + tag: t} if y > 1.1 else {"fore_" + tag: 1.0}
    return f


def w_sleeve(tag):
    """The sleeve: the arm above the elbow, the forearm round it, the hanging bell of it on the sleeve bone."""
    arm = w_arm(tag)

    def f(p):
        y = p[1]
        if y > 1.06:
            return arm(p)
        t = smooth(1.06, 0.92, y)
        return {"fore_" + tag: 1.0 - t, "sleeve_" + tag: t}
    return f


def w_head(p):
    if p[1] < 1.56:
        t = smooth(1.46, 1.56, p[1])
        return {"chest": 1.0 - t, "neck": t}
    return {"head": 1.0}


# --- the body ----------------------------------------------------------------------------------------------

def robe(g):
    """The bell: waist to the floating hem, deep regular pleats, gold bands and embroidery, a hem of small bells; the
    light of the door inside it, spilling at the hem."""
    def fold(th, y, r):
        depth = 0.008 + 0.035 * smooth(1.0, 0.2, y)
        return depth * (0.75 * math.sin(14 * th) + 0.25 * math.sin(28 * th + y * 2.0))

    def col(th, y, dr):
        ridge = (dr / 0.043) * 0.5 + 0.5
        c = IVORY_DK * (1.0 - ridge) + IVORY_LT * ridge
        return tuple(c)

    prof = []
    for k in range(22):
        u = k / 21.0
        prof.append((1.02 - u * (1.02 - HEM), 0.17 + 0.41 * (u ** 1.5)))
    prof.reverse()
    K.lathe(g, prof, 112, col, "cloth", w_skirt, fold=fold, hem=lambda th: 0.012 * math.sin(14 * th))
    # the lining inside the bell (dark slate) and the light pouring out of it
    inner = [(y, r - 0.012) for y, r in prof[:8]]
    K.lathe(g, list(reversed(inner)), 112, tuple(LINING * 0.7), "cloth", w_skirt, fold=fold)
    K.lathe(g, [(HEM + 0.005, 0.0), (HEM + 0.06, 0.4), (HEM + 0.02, 0.52)], 48, LIGHT, "eye", w_skirt, glow=True)
    # gold bands near the hem and the waist: short lathes on the same pleats, standing proud of them
    for y, w in ((HEM + 0.07, 0.032), (HEM + 0.17, 0.014), (0.98, 0.022)):
        bp = []
        for k in range(4):
            yy = y - w + 2 * w * k / 3.0
            r = 0.17 + 0.41 * (((1.02 - yy) / (1.02 - HEM)) ** 1.5) + (0.008 if k in (1, 2) else 0.002)
            bp.append((yy, r))
        K.lathe(g, bp, 112, tuple(GOLD), "metal", w_skirt, fold=fold)
    for ang in (0.0, -0.95, 0.95, -2.2, 2.2):
        pts = []
        for y in np.linspace(0.99, HEM + 0.1, 12):
            r = 0.17 + 0.41 * (((1.02 - y) / (1.02 - HEM)) ** 1.5) + 0.01
            pts.append(V(math.sin(ang) * r, y, -math.cos(ang) * r))
        wd = 0.045 if ang == 0.0 else 0.016
        K.tube(g, pts, [wd] * len(pts), 6, tuple(GOLD if ang == 0.0 else GOLD_DK), "metal", w_skirt, squash=(1.0, 0.18), ref=V(math.sin(ang), 0, -math.cos(ang)))
        if ang == 0.0:
            for y in np.linspace(0.9, HEM + 0.15, 6):                    # sun-discs stitched down the front band
                r = 0.17 + 0.41 * (((1.02 - y) / (1.02 - HEM)) ** 1.5) + 0.02
                K.blob(g, V(0, y, -r), [0.03, 0.03, 0.01], tuple(GOLD_LT), "metal", w_skirt, rings=4, segs=10)
    for i in range(24):
        a = TAU * i / 24 + 0.13
        r = 0.585
        K.blob(g, V(math.sin(a) * r, HEM + 0.005, -math.cos(a) * r), [0.016, 0.024, 0.016], tuple(GOLD_LT), "metal", w_skirt, rings=4, segs=8)


def torso(g):
    rows = []
    for y, rx, rz in ((0.98, 0.17, 0.13), (1.1, 0.15, 0.11), (1.22, 0.16, 0.115), (1.34, 0.19, 0.125), (1.46, 0.2, 0.13), (1.54, 0.12, 0.09), (1.6, 0.07, 0.065)):
        rows.append((V(0, y, 0.0), rx, rz))
    K.loft(g, rows, 40, lambda th, j, dr, p: tuple(IVORY * (0.94 + 0.08 * math.sin(6 * th))), "cloth", w_spine,
           fold=lambda th, j, n: 0.006 * math.sin(6 * th + j))
    # a girdle of gold plates, the key's chain hung from it
    for a in np.linspace(0, TAU, 13)[:-1]:
        K.blob(g, V(math.sin(a) * 0.175, 0.99, -math.cos(a) * 0.135), [0.035, 0.03, 0.012], tuple(GOLD), "metal", "pelvis",
               basis=K.rot_y(-a), rings=4, segs=8, power=0.5)


def collar(g):
    """A stiff gold collar: a cape of plates over the shoulders, rising behind the neck into a fan."""
    rows = []
    for k in range(6):
        u = k / 5.0
        rows.append((V(0, 1.53 - 0.13 * u, 0.0 + 0.01 * u), 0.13 + 0.17 * (u ** 0.8), 0.11 + 0.11 * (u ** 0.8)))
    rows.reverse()
    K.loft(g, rows, 40, lambda th, j, dr, p: tuple(GOLD * (0.9 + 0.15 * (0.5 + 0.5 * math.sin(12 * th)))), "metal", "chest",
           fold=lambda th, j, n: 0.012 * max(0.0, math.sin(12 * th)) * (1.0 - j / 5.0), hem=lambda th: 0.02 * abs(math.sin(6 * th)))
    for i in range(7):                                                  # the fan behind the neck
        a = math.radians(-60 + 20 * i)
        b = V(math.sin(a) * 0.11, 1.52, 0.06 + math.cos(a) * 0.04)
        K.tube(g, [b, b + V(math.sin(a) * 0.05, 0.16 - abs(a) * 0.05, 0.05)], [0.03, 0.012], 6, tuple(GOLD_LT if i % 2 else GOLD), "metal", "chest",
               squash=(1.0, 0.3), ref=V(0, 0, 1))
    for s in (-1.0, 1.0):                                               # shoulder plates
        K.blob(g, V(s * 0.25, 1.48, 0.0), [0.1, 0.035, 0.1], tuple(GOLD), "metal", "clav_r" if s > 0 else "clav_l",
               basis=K.rot_z(-s * 0.45), rings=5, segs=12)
    for i in range(7):                                                  # tassels on the collar's front
        x = -0.15 + 0.05 * i
        ln = 0.1 + 0.05 * abs(math.sin(i * 1.9))
        K.tube(g, [V(x, 1.43, -0.2), V(x, 1.43 - ln * 0.5, -0.21), V(x, 1.43 - ln, -0.21)], [0.01, 0.008, 0.004], 5, tuple(GOLD), "metal", "chest")
        K.blob(g, V(x, 1.42 - ln, -0.21), [0.011, 0.014, 0.011], tuple(GOLD_LT), "metal", "chest", rings=4, segs=8)


def head(g):
    hc = V(0, 1.69, -0.01)
    # the mask: a smooth gold oval, a ridge for the nose, the eye slits lit, a closed mouth line
    K.blob(g, hc + V(0, 0.0, -0.035), [0.08, 0.11, 0.07], tuple(GOLD_LT), "metal", w_head, rings=12, segs=20)
    K.tube(g, [hc + V(0, 0.05, -0.1), hc + V(0, 0.0, -0.108), hc + V(0, -0.03, -0.106)], [0.008, 0.01, 0.006], 6, tuple(GOLD_LT), "metal", w_head)
    for s in (-1.0, 1.0):
        K.blob(g, hc + V(s * 0.034, 0.018, -0.098), [0.024, 0.006, 0.006], LIGHT, "eye", w_head, basis=K.rot_z(s * 0.15), rings=4, segs=10, glow=True)
    K.tube(g, [hc + V(-0.02, -0.055, -0.094), hc + V(0, -0.058, -0.097), hc + V(0.02, -0.055, -0.094)], [0.003] * 3, 5, HOLLOW, "cloth", w_head)
    # a thin gold diadem on the brow
    K.tube(g, [hc + V(math.sin(a) * 0.088, 0.075, -math.cos(a) * 0.085) for a in np.linspace(-1.4, 1.4, 15)], [0.008] * 15, 5, tuple(GOLD), "metal", w_head)
    K.blob(g, hc + V(0, 0.085, -0.088), [0.016, 0.022, 0.008], SUN, "eye", w_head, rings=4, segs=8, glow=True)
    # the hood
    rows = [(V(0, 1.53, 0.0), 0.16, 0.14), (V(0, 1.6, 0.01), 0.13, 0.13), (V(0, 1.68, 0.01), 0.125, 0.13), (V(0, 1.76, 0.0), 0.115, 0.12),
            (V(0, 1.82, -0.01), 0.09, 0.1), (V(0, 1.86, -0.02), 0.05, 0.06)]
    OPEN = math.radians(56.0)

    def opening(th, j):
        a = abs(math.atan2(math.sin(th), math.cos(th)))
        return a < OPEN * (1.0 - 0.45 * smooth(2.5, 4.3, j)) and 0.7 < j < 4.3

    K.loft(g, rows, 40, lambda th, j, dr, p: tuple(IVORY * (0.9 + 0.08 * math.sin(5 * th + j))), "cloth", w_head,
           fold=lambda th, j, n: 0.006 * math.sin(6 * th + j), cap_top=True, skip=opening)
    K.blob(g, hc + V(0, 0.02, 0.04), [0.1, 0.12, 0.08], HOLLOW, "cloth", w_head, rings=8, segs=12)
    edge = []
    for k in range(25):
        u = k / 24.0
        jj = 0.85 + (4.15 - 0.85) * math.sin(u * math.pi)
        th = (-1.0 if u < 0.5 else 1.0) * OPEN * (1.0 - 0.45 * smooth(2.5, 4.3, jj))
        j0 = min(int(math.floor(jj)), len(rows) - 2)
        t = jj - j0
        (c0, rx0, rz0), (c1, rx1, rz1) = rows[j0], rows[j0 + 1]
        cc = c0 * (1 - t) + c1 * t
        edge.append(cc + V(math.sin(th) * (rx0 * (1 - t) + rx1 * t), 0, -math.cos(th) * (rz0 * (1 - t) + rz1 * t)))
    K.tube(g, edge, [0.016] * len(edge), 8, tuple(GOLD), "metal", w_head)


def mandorla(g):
    """The halo: an almond of gold with rays, an inner ring of beads, a sun-disc at its heart (the weak point), and
    long rays swept out from behind the shoulders like wings."""
    up = np.eye(3)
    ring = [MC + V(math.sin(a) * 0.46, math.cos(a) * 0.6, 0.0) for a in np.linspace(0, TAU, 49)]
    K.tube(g, ring, [0.026] * len(ring), 8, tuple(GOLD), "metal", "halo", caps=False)
    ring2 = [MC + V(math.sin(a) * 0.34, math.cos(a) * 0.45, 0.01) for a in np.linspace(0, TAU, 41)]
    K.tube(g, ring2, [0.014] * len(ring2), 6, tuple(GOLD_LT), "metal", "halo", caps=False)
    for i in range(28):
        a = TAU * i / 28
        K.blob(g, MC + V(math.sin(a) * 0.4, math.cos(a) * 0.525, 0.005), [0.014] * 3, tuple(GOLD_LT), "metal", "halo", rings=4, segs=6)
    for i in range(20):
        a = TAU * i / 20
        if abs(math.sin(a)) > 0.85:
            continue                                              # the wings take the sides
        d = V(math.sin(a) * 0.46, math.cos(a) * 0.6, 0.0)
        ln = 0.22 if i % 2 == 0 else 0.12
        dn = d / np.linalg.norm(d)
        K.tube(g, [MC + d, MC + d + dn * ln * 0.5, MC + d + dn * ln], [0.022, 0.014, 0.002], 5, tuple(GOLD), "metal", "halo",
               squash=(1.0, 0.4), ref=V(0, 0, 1))
    # the sun-disc at its heart, behind the head
    K.blob(g, MC + V(0, 0.0, 0.03), [0.16, 0.16, 0.02], SUN, "eye", "halo", rings=6, segs=20, glow=True)
    K.tube(g, [MC + V(math.sin(a) * 0.17, math.cos(a) * 0.17, 0.03) for a in np.linspace(0, TAU, 25)], [0.012] * 25, 6, tuple(GOLD_DK), "metal", "halo", caps=False)
    # the wings: five long rays a side, fanning from behind the shoulders up and out
    for s in (-1.0, 1.0):
        for k in range(5):
            a = math.radians(18 + 16 * k)
            base = MC + V(s * 0.4, -0.12 - 0.05 * k, -0.01)
            d = V(s * math.cos(a), math.sin(a), 0.06)
            ln = 0.75 - 0.08 * abs(k - 1.5)
            pts = [base, base + d * ln * 0.35, base + d * ln * 0.7 + V(0, 0.03, 0), base + d * ln + V(0, 0.06, 0)]
            K.tube(g, pts, [0.04, 0.03, 0.018, 0.003], 6, tuple(GOLD if k % 2 else GOLD_LT), "metal", "halo", squash=(1.0, 0.28), ref=V(0, 0, 1))


def sleeve(g, s, tag):
    """A long hanging sleeve: fitted to the elbow, then a great bell lined in slate blue hanging to the knee."""
    path = [V(s * 0.19, 1.51, 0.0), V(s * 0.23, 1.35, 0.01), V(s * 0.26, 1.19, 0.02), V(s * 0.27, 1.07, 0.0)]
    K.tube(g, path, [0.07, 0.068, 0.07, 0.085], 16, tuple(IVORY), "cloth", w_arm(tag), caps=False)
    # the bell of it hangs from the forearm (on the sleeve bone, plumb whatever the arm does): narrow at the elbow,
    # opening in deep folds, the hem cut long at the back, lined in slate blue
    top = V(s * 0.275, 1.07, 0.0)
    prof = [(0.0, 0.08), (-0.1, 0.1), (-0.22, 0.135), (-0.34, 0.17), (-0.44, 0.19)]
    rows = [(top + V(0, dy, 0.03 * (dy / -0.44)), r, r * 0.8) for dy, r in prof]

    def hem(th):
        return -0.13 * smooth(0.4, -0.95, math.cos(th)) + 0.025 * abs(math.sin(6 * th + s))     # longer at the back, ragged

    def fold(th, j, n):
        return 0.028 * math.sin(6 * th + s) * (j / 4.0) ** 1.2

    rows_up = list(reversed(rows))
    K.loft(g, rows_up, 30, lambda th, j, dr, p: tuple(IVORY * (0.86 + 0.14 * (0.5 + 0.5 * math.sin(6 * th + s)))), "cloth", w_sleeve(tag),
           fold=lambda th, j, n: fold(th, 4 - j, n), hem=hem)
    rin = [(c + V(0, 0.004, 0), r - 0.012, rz - 0.012) for c, r, rz in rows_up]
    K.loft(g, rin, 30, tuple(LINING), "cloth", w_sleeve(tag), a0=TAU, a1=0.0, fold=lambda th, j, n: fold(th, 4 - j, n), hem=hem)
    c, r, rz = rows[-1]
    K.tube(g, [c + V(math.sin(a) * (r + 0.004 + fold(a, 4, 5)), hem(a), -math.cos(a) * (rz + 0.004 + fold(a, 4, 5))) for a in np.linspace(0, TAU, 31)],
           [0.011] * 31, 6, tuple(GOLD), "metal", "sleeve_" + tag, caps=False)


def hand(g, s, tag):
    """Long gilded hands, open, the fingers slightly curled."""
    wr = V(s * 0.29, 0.91, -0.02)
    K.tube(g, [wr + V(0, 0.08, 0.0), wr], [0.03, 0.028], 10, tuple(GOLD_LT), "metal", "fore_" + tag)
    K.blob(g, wr + V(0, -0.05, -0.012), [0.022, 0.055, 0.04], tuple(GOLD_LT), "metal", "hand_" + tag, rings=6, segs=10)
    for f in range(4):
        z = -0.04 + 0.022 * f
        b = V(s * 0.297, 0.83, z - 0.01)
        ln = [0.12, 0.135, 0.13, 0.105][f]
        pts = [b, b + V(s * 0.004, -ln * 0.45, -0.008), b + V(s * 0.0, -ln * 0.8, -0.022), b + V(-s * 0.006, -ln, -0.032)]
        K.tube(g, pts, [0.011, 0.01, 0.008, 0.004], 6, tuple(GOLD_LT), "metal", "fingers_" + tag)
    th = wr + V(-s * 0.01, -0.03, -0.045)
    K.tube(g, [th, th + V(-s * 0.01, -0.035, -0.03), th + V(-s * 0.01, -0.07, -0.04)], [0.011, 0.009, 0.004], 6, tuple(GOLD_LT), "metal", "hand_" + tag)


def key(g):
    """The key of the door on a chain from the girdle at the left hip: a long gold shank, a sun-wheel bow, the bit."""
    a = V(-0.2, 0.97, -0.1)
    b = V(-0.23, 0.76, -0.13)
    c = V(-0.24, 0.56, -0.15)
    for p0, p1, bone in ((a, b, "key_0"), (b, c + V(0, 0.12, 0), "key_1")):
        n = 6
        for k in range(n):
            q0 = p0 + (p1 - p0) * (k / n)
            q1 = p0 + (p1 - p0) * ((k + 1) / n)
            m = (q0 + q1) * 0.5
            ax = (q1 - q0) / (np.linalg.norm(q1 - q0) + 1e-9)
            s1, s2 = K._frame(ax)
            side = s1 if k % 2 == 0 else s2
            loop = [m + ax * math.cos(t) * 0.022 + side * math.sin(t) * 0.012 for t in np.linspace(0, TAU, 9)]
            K.tube(g, loop, [0.004] * len(loop), 4, tuple(GOLD_DK), "metal", bone, caps=False)
    bow = c + V(0, 0.08, 0)
    K.tube(g, [bow + V(math.sin(t) * 0.05, math.cos(t) * 0.05, 0) for t in np.linspace(0, TAU, 21)], [0.01] * 21, 6, tuple(GOLD), "metal", "key_1", caps=False)
    for i in range(6):
        t = TAU * i / 6
        K.tube(g, [bow, bow + V(math.sin(t) * 0.05, math.cos(t) * 0.05, 0)], [0.006, 0.006], 4, tuple(GOLD), "metal", "key_1")
    K.tube(g, [c + V(0, 0.03, 0), c + V(0, -0.2, 0)], [0.014, 0.012], 8, tuple(GOLD), "metal", "key_1")
    K.blob(g, c + V(0.03, -0.17, 0), [0.03, 0.035, 0.008], tuple(GOLD), "metal", "key_1", rings=4, segs=8, power=0.4)


def build_body():
    g = K.Geo()
    robe(g)
    torso(g)
    collar(g)
    head(g)
    mandorla(g)
    for s, tag in ((-1.0, "l"), (1.0, "r")):
        sleeve(g, s, tag)
        hand(g, s, tag)
    key(g)
    return g


# --- the clips ---------------------------------------------------------------------------------------------
X = V(-1, 0, 0)
Y = V(0, 1, 0)
Z = V(0, 0, 1)


def m(*poses, **over):
    out = {}
    for p in poses:
        out.update(p)
    out.update(over)
    return out


def _q(rots):
    from mathutils import Quaternion, Vector
    q = Quaternion()
    for ax, deg in rots:
        q = Quaternion(Vector(tuple(ax)), math.radians(deg)) @ q
    return q


def plumb(pose):
    """The sleeves' bells hang straight down whatever the arms do (their own follow-through rides on top)."""
    out = dict(pose)
    for tag in ("l", "r"):
        q = _q([])
        for b in ("pelvis", "spine", "chest", "clav_" + tag, "upper_" + tag, "fore_" + tag):
            q = q @ _q(pose.get(b, []))
        ax, ang = q.inverted().to_axis_angle()
        out["sleeve_" + tag] = [(V(ax.x, ax.y, ax.z), math.degrees(ang))]
    return out


REST = m(spine=[(X, 0)], chest=[(X, -2)], head=[(X, 6)],
         upper_r=[(X, -14), (Z, 10)], fore_r=[(X, -36), (Z, 6)], fingers_r=[(X, -10)],
         upper_l=[(X, -14), (Z, -10)], fore_l=[(X, -36), (Z, -6)], fingers_l=[(X, -10)])


def P(**kw):
    return plumb(m(REST, **kw))


def bob(t0, length, n=4, amp=0.035, base=(0.0, 0.0, 0.0)):
    return [(t0 + length * k / n, (base[0], base[1] + (amp if k % 2 else 0.0), base[2])) for k in range(n + 1)]


def clips(arm):
    rest = P()
    cloth = [["skirt_%d_%d" % (i, l) for l in range(3)] for i in range(SKIRT_N)] + [["key_0", "key_1"]]
    hang = [{"bones": ["sleeve_l"], "drive": "fore_l", "gain": 0.5, "add": True, "ripple": 0.5},
            {"bones": ["sleeve_r"], "drive": "fore_r", "gain": 0.5, "add": True, "ripple": 0.5},
            {"bones": ["halo"], "drive": "chest", "gain": 0.35, "add": True, "ripple": 0.25}]
    chains = cloth + hang
    # idle: hanging in the air, rising and sinking a hand's breadth; the hands turn, the head follows you; the halo sways
    a1 = P(head=[(X, 2), (Y, -12)], halo=[(Z, 4)], fore_r=[(X, -44), (Z, 6)], fingers_r=[(X, -24)], upper_l=[(X, -10), (Z, -14)])
    a2 = P(head=[(X, 8), (Y, 10)], halo=[(Z, -4)], fore_l=[(X, -44), (Z, -6)], fingers_l=[(X, -24)], upper_r=[(X, -10), (Z, 14)])
    K.key_clip(arm, "idle", [(0.0, rest), (1.5, a1), (3.0, rest), (4.5, a2), (6.0, rest)], 6.0, loop=True, chains=chains, ripple=0.03,
               root_keys=bob(0.0, 6.0))
    # walk: it glides, leaning into the way, the robe trailing
    glide = P(pelvis=[(X, 6)], spine=[(X, 6)], chest=[(X, 2)], head=[(X, -6)], upper_r=[(X, 6), (Z, 12)], upper_l=[(X, 6), (Z, -12)])
    glide2 = P(pelvis=[(X, 6), (Z, 2)], spine=[(X, 6)], chest=[(X, 2), (Z, -2)], head=[(X, -6)], upper_r=[(X, 2), (Z, 14)], upper_l=[(X, 10), (Z, -10)])
    K.key_clip(arm, "walk", [(0.0, glide), (0.8, glide2), (1.6, glide)], 1.6, loop=True, chains=chains, ripple=0.03, root_keys=bob(0.0, 1.6, 2, 0.03))
    # the Radiant Fan: hands drawn to the breast, then raised forward with the palms out (held), thrust out as it flies
    draw = P(spine=[(X, -4)], chest=[(X, -6)], head=[(X, 0)], upper_r=[(X, -30), (Z, -6)], fore_r=[(X, -100), (Z, -20)], hand_r=[(X, 20)],
             upper_l=[(X, -30), (Z, 6)], fore_l=[(X, -100), (Z, 20)], hand_l=[(X, 20)])
    raise_ = P(spine=[(X, -8)], chest=[(X, -10)], head=[(X, -10)], clav_r=[(Z, 10)], clav_l=[(Z, -10)],
               upper_r=[(X, -130), (Z, 20)], fore_r=[(X, -20)], hand_r=[(X, -50)], fingers_r=[(X, -10)],
               upper_l=[(X, -130), (Z, -20)], fore_l=[(X, -20)], hand_l=[(X, -50)], fingers_l=[(X, -10)], halo=[(X, -6)])
    hold2 = P(spine=[(X, -10)], chest=[(X, -12)], head=[(X, -12)], clav_r=[(Z, 12)], clav_l=[(Z, -12)],
              upper_r=[(X, -136), (Z, 24)], fore_r=[(X, -18)], hand_r=[(X, -54)], upper_l=[(X, -136), (Z, -24)], fore_l=[(X, -18)], hand_l=[(X, -54)], halo=[(X, -8)])
    K.key_clip(arm, "windup", [(0.0, rest), (0.3, draw), (0.85, raise_)], 0.85, chains=chains, root_keys=[(0.0, (0, 0, 0)), (0.85, (0, 0.05, 0))])
    K.key_clip(arm, "windup_hold", [(0.0, raise_), (0.5, hold2), (1.0, raise_)], 1.0, loop=True, chains=chains,
               root_keys=[(0.0, (0, 0.05, 0)), (0.5, (0, 0.065, 0)), (1.0, (0, 0.05, 0))])
    thrust = P(spine=[(X, 12)], chest=[(X, 8)], head=[(X, 2)], upper_r=[(X, -86), (Z, 14)], fore_r=[(X, -4)], hand_r=[(X, -70)], fingers_r=[(X, 10)],
               upper_l=[(X, -86), (Z, -14)], fore_l=[(X, -4)], hand_l=[(X, -70)], fingers_l=[(X, 10)], halo=[(X, 8)])
    K.key_clip(arm, "strike", [(0.0, raise_), (0.1, thrust), (0.45, P(spine=[(X, 14)], chest=[(X, 10)], upper_r=[(X, -80), (Z, 14)], hand_r=[(X, -60)],
                                                                         upper_l=[(X, -80), (Z, -14)], hand_l=[(X, -60)])), (1.2, rest)], 1.2, chains=chains,
               root_keys=[(0.0, (0, 0.05, 0)), (0.1, (0, 0.04, 0.05)), (0.45, (0, 0.02, 0.06)), (1.2, (0, 0, 0))])
    reel = P(spine=[(X, -18), (Z, 6)], chest=[(X, -12)], head=[(X, -22), (Z, 8)], upper_r=[(X, 10), (Z, 30)], upper_l=[(X, 10), (Z, -34)], halo=[(Z, 8)])
    slump = P(spine=[(X, 24)], chest=[(X, 18)], head=[(X, 26)], upper_r=[(X, -20)], upper_l=[(X, -20)], halo=[(X, 6)])
    K.key_clip(arm, "stagger", [(0.0, rest), (0.12, reel), (0.6, slump), (1.3, m(slump, head=[(X, 20), (Y, 12)])), (1.8, rest)], 1.8, chains=chains,
               root_keys=[(0.0, (0, 0, 0)), (0.12, (0, 0.02, 0.06)), (0.6, (0, -0.08, 0.02)), (1.8, (0, 0, 0))])
    cry = P(spine=[(X, -12)], chest=[(X, -16)], neck=[(X, -12)], head=[(X, -26)], clav_r=[(Z, 18)], clav_l=[(Z, -18)],
            upper_r=[(X, -60), (Z, 70)], fore_r=[(X, -10)], upper_l=[(X, -60), (Z, -70)], fore_l=[(X, -10)], halo=[(X, -8)])
    K.key_clip(arm, "howl", [(0.0, rest), (0.4, P(spine=[(X, 10)], chest=[(X, 12)])), (0.9, cry), (1.6, m(cry, head=[(X, -30)])), (2.0, rest)], 2.0,
               chains=chains, root_keys=[(0.0, (0, 0, 0)), (0.9, (0, 0.1, 0)), (1.6, (0, 0.12, 0)), (2.0, (0, 0, 0))])
    fall = P(spine=[(X, 50)], chest=[(X, 30)], head=[(X, 30)], upper_r=[(X, -50), (Z, 30)], upper_l=[(X, -50), (Z, -30)], halo=[(X, 30)])
    K.key_clip(arm, "death", [(0.0, rest), (0.4, reel), (1.2, slump), (2.2, fall), (3.0, fall)], 3.0, chains=chains,
               root_keys=[(0.0, (0, 0, 0)), (0.4, (0, 0.06, 0)), (1.2, (0, -0.06, 0)), (2.2, (0, -0.2, -0.3)), (3.0, (0, -0.22, -0.34))])
    # Mandorla Flare (2.0 s, the deck burns at the end): arms folded over the breast, then flung wide, the head back
    fold = P(spine=[(X, 10)], chest=[(X, 14)], head=[(X, 22)], upper_r=[(X, -40), (Z, -14)], fore_r=[(X, -120), (Z, -30)],
             upper_l=[(X, -40), (Z, 14)], fore_l=[(X, -120), (Z, 30)], halo=[(X, 6)])
    wide = P(spine=[(X, -14)], chest=[(X, -18)], neck=[(X, -10)], head=[(X, -24)], clav_r=[(Z, 20)], clav_l=[(Z, -20)],
             upper_r=[(X, -40), (Z, 92)], fore_r=[(X, -6)], hand_r=[(X, -30)], upper_l=[(X, -40), (Z, -92)], fore_l=[(X, -6)], hand_l=[(X, -30)], halo=[(X, -12)])
    K.key_clip(arm, "flare", [(0.0, rest), (0.6, fold), (1.6, m(fold, chest=[(X, 18)], head=[(X, 26)])), (1.85, wide), (2.4, m(wide, head=[(X, -28)])), (3.0, rest)],
               3.0, chains=chains, root_keys=[(0.0, (0, 0, 0)), (1.6, (0, -0.04, 0)), (1.85, (0, 0.12, 0)), (2.4, (0, 0.14, 0)), (3.0, (0, 0, 0))])
    # Eclipse (2.8 s): the hands rise slowly over the head and cup there, closing the light
    cup = P(spine=[(X, -6)], chest=[(X, -10)], head=[(X, -14)], clav_r=[(Z, 16)], clav_l=[(Z, -16)],
            upper_r=[(X, -168), (Z, -6)], fore_r=[(X, -40), (Z, -30)], hand_r=[(X, -20)], fingers_r=[(X, -30)],
            upper_l=[(X, -168), (Z, 6)], fore_l=[(X, -40), (Z, 30)], hand_l=[(X, -20)], fingers_l=[(X, -30)])
    half = P(upper_r=[(X, -90), (Z, 30)], fore_r=[(X, -30)], upper_l=[(X, -90), (Z, -30)], fore_l=[(X, -30)], head=[(X, -6)])
    K.key_clip(arm, "eclipse", [(0.0, rest), (1.0, half), (2.4, cup), (2.8, m(cup, head=[(X, -18)])), (3.5, rest)], 3.5, chains=chains,
               root_keys=[(0.0, (0, 0, 0)), (2.4, (0, 0.08, 0)), (2.8, (0, 0.08, 0)), (3.5, (0, 0, 0))])
    # Gale of the Door (1.6 s cast, then 5 s of wind): the arms drawn back, then both palms driving forward and held
    back = P(spine=[(X, -8), (Y, 0)], chest=[(X, -10)], upper_r=[(X, 30), (Z, 24)], fore_r=[(X, -60)], upper_l=[(X, 30), (Z, -24)], fore_l=[(X, -60)],
             hand_r=[(X, 30)], hand_l=[(X, 30)])
    def push(k):
        return P(spine=[(X, 14 + 2 * k)], chest=[(X, 10)], head=[(X, -4)], upper_r=[(X, -80 - 3 * k), (Z, 10)], fore_r=[(X, -8)], hand_r=[(X, -75)],
                 upper_l=[(X, -80 + 3 * k), (Z, -10)], fore_l=[(X, -8)], hand_l=[(X, -75)], halo=[(X, 6)])
    K.key_clip(arm, "gale", [(0.0, rest), (1.2, back), (1.6, push(0)), (2.6, push(1)), (3.6, push(-1)), (4.6, push(1)), (5.6, push(-1)), (6.6, push(0)),
                             (7.3, rest)], 7.3, chains=chains,
               root_keys=[(0.0, (0, 0, 0)), (1.2, (0, 0.02, 0.06)), (1.6, (0, 0.03, -0.04)), (6.6, (0, 0.03, -0.04)), (7.3, (0, 0, 0))])
    # Call the Acolytes (2.0 s): the arms raised to the sides, palms up, the head lifted
    call = P(spine=[(X, -6)], chest=[(X, -8)], head=[(X, -16)], upper_r=[(X, -30), (Z, 60)], fore_r=[(X, -40)], hand_r=[(Z, 30)],
             upper_l=[(X, -30), (Z, -60)], fore_l=[(X, -40)], hand_l=[(Z, -30)])
    K.key_clip(arm, "call", [(0.0, rest), (0.7, call), (1.5, m(call, upper_r=[(X, -40), (Z, 74)], upper_l=[(X, -40), (Z, -74)])), (2.0, call), (2.6, rest)],
               2.6, chains=chains, root_keys=[(0.0, (0, 0, 0)), (1.5, (0, 0.08, 0)), (2.6, (0, 0, 0))])
    # Judgement (1.2 s, two lanes crossing at you): the right hand raised high and brought down across, the left after
    high = P(spine=[(X, -6), (Y, -10)], chest=[(X, -8), (Y, -8)], head=[(X, -6)], clav_r=[(Z, 14)], upper_r=[(X, -170), (Z, 10)], fore_r=[(X, -10)],
             upper_l=[(X, -50), (Z, -20)], fore_l=[(X, -60)])
    cross = P(spine=[(X, 12), (Y, 10)], chest=[(X, 10), (Y, 8)], head=[(X, 6)], upper_r=[(X, -60), (Z, -30)], fore_r=[(X, -20)],
              upper_l=[(X, -110), (Z, -30)], fore_l=[(X, -10)])
    K.key_clip(arm, "judgement", [(0.0, rest), (0.7, high), (1.05, m(high, upper_r=[(X, -175), (Z, 8)])), (1.2, cross), (1.6, m(cross, spine=[(X, 14), (Y, 12)])),
                                  (2.2, rest)], 2.2, chains=chains)
    # Ascend (2.0 s): rising with the arms out and up, the head thrown back
    rise = P(spine=[(X, -10)], chest=[(X, -14)], head=[(X, -30)], clav_r=[(Z, 20)], clav_l=[(Z, -20)], upper_r=[(X, -80), (Z, 110)], fore_r=[(X, -10)],
             upper_l=[(X, -80), (Z, -110)], fore_l=[(X, -10)], halo=[(X, -10)])
    K.key_clip(arm, "ascend", [(0.0, rest), (0.5, fold), (1.4, rise), (2.0, m(rise, head=[(X, -34)])), (2.6, rest)], 2.6, chains=chains,
               root_keys=[(0.0, (0, 0, 0)), (0.5, (0, -0.05, 0)), (1.4, (0, 0.25, 0)), (2.0, (0, 0.3, 0)), (2.6, (0, 0, 0))])


def main():
    K.clear_scene()
    g = build_body()
    ob = K.make_object(g, "AscendedWarden", subdiv=0)
    arm = K.build_armature(BONES, "WardenRig")
    K.bind(ob, arm)
    print("VB TRIS", sum(len(p.vertices) - 2 for p in ob.data.polygons))
    if DO_AO:
        K.bake_ao_alpha(ob)
    clips(arm)
    K.export_glb(arm, ob, OUT)
    if RENDERS:
        K.review_renders(arm, ob, RENDERS, "warden", 1.95, poses=[("windup_hold", 0.0, 30.0), ("strike", 0.1, 60.0), ("flare", 1.85, 10.0),
                                                                   ("eclipse", 2.6, 30.0), ("gale", 2.6, 60.0), ("judgement", 1.05, 40.0),
                                                                   ("call", 1.5, 10.0), ("ascend", 2.0, 20.0), ("death", 3.0, 60.0)])
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(K.ROOT, "art/blender/vb_ascended_warden.blend"))


main()
