"""The Thornwarden, modelled in Blender in the villagers' style (18 Nov). Run:
    blender -b -P tools/blender/vb_thornwarden.py -- [--out art/models/bosses/vb_thornwarden.glb] [--renders <dir>] [--no-ao]

Its own design (core/enemy/thornwarden.gd, thorn_body.gd): the keeper of the Thorn Henge, a great stag-wolf of bark
and thorn. Long-legged and heavy in front, a hump of thorn hackles over the shoulders, the head carried low on a long
neck; a long wolf's skull of bark plates with ember eyes and a jaw of thorn teeth; a crown of briar antlers twisting up
and back; thorns down its spine and moss on its back; legs of twisted root ending in root claws; a bramble whip of a
tail; and at its breast, under the neck, a heart-knot of woven roots with a light in it (its weak point).

Silhouette: low and long, the antlers' crown and the hackle hump breaking the line; the heart glowing under the neck.

Rig space: x right, y up, z back, facing -Z, metres (built at a large wolf's scale; the game scales it up).
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


OUT = os.path.join(K.ROOT, arg("--out", "art/models/bosses/vb_thornwarden.glb"))
RENDERS = arg("--renders")
DO_AO = "--no-ao" not in ARGS

BARK = np.array([0.26, 0.19, 0.13])
BARK_LT = np.array([0.38, 0.28, 0.19])
BARK_DK = np.array([0.16, 0.12, 0.08])
THORN = np.array([0.55, 0.48, 0.37])
MOSS = np.array([0.24, 0.31, 0.17])
MOSS_LT = np.array([0.34, 0.42, 0.22])
ROOT = np.array([0.33, 0.25, 0.17])
EMBER = (1.0, 0.5, 0.15)
HEART = (1.0, 0.58, 0.2)
HOLLOW = (0.03, 0.02, 0.015)
BERRY = (0.55, 0.08, 0.1)

HEART_AT = V(0, 0.8, -0.56)

BONES = {
    "root": (V(0, 0, 0), V(0, 0.12, 0), None, False),
    "pelvis": (V(0, 0.92, 0.46), V(0, 0.97, 0.12), "root", True),
    "spine": (V(0, 0.97, 0.12), V(0, 1.02, -0.2), "pelvis", True),
    "chest": (V(0, 1.02, -0.2), V(0, 1.06, -0.46), "spine", True),
    "neck": (V(0, 1.06, -0.46), V(0, 1.12, -0.78), "chest", True),
    "head": (V(0, 1.12, -0.78), V(0, 1.04, -1.14), "neck", True),
    "jaw": (V(0, 1.04, -0.86), V(0, 0.96, -1.12), "head", True),
    "tail_0": (V(0, 0.94, 0.6), V(0, 0.88, 0.84), "pelvis", True),
    "tail_1": (V(0, 0.88, 0.84), V(0, 0.78, 1.06), "tail_0", True),
    "tail_2": (V(0, 0.78, 1.06), V(0, 0.66, 1.26), "tail_1", True),
    "tail_3": (V(0, 0.66, 1.26), V(0, 0.56, 1.46), "tail_2", True),
}
for s, tag in ((-1.0, "l"), (1.0, "r")):
    BONES.update({
        "fl_upper_" + tag: (V(s * 0.21, 0.9, -0.38), V(s * 0.22, 0.47, -0.3), "chest", True),
        "fl_lower_" + tag: (V(s * 0.22, 0.47, -0.3), V(s * 0.22, 0.1, -0.36), "fl_upper_" + tag, True),
        "fl_foot_" + tag: (V(s * 0.22, 0.1, -0.36), V(s * 0.22, 0.03, -0.5), "fl_lower_" + tag, True),
        "bl_upper_" + tag: (V(s * 0.2, 0.88, 0.5), V(s * 0.23, 0.45, 0.66), "pelvis", True),
        "bl_lower_" + tag: (V(s * 0.23, 0.45, 0.66), V(s * 0.23, 0.1, 0.54), "bl_upper_" + tag, True),
        "bl_foot_" + tag: (V(s * 0.23, 0.1, 0.54), V(s * 0.23, 0.03, 0.4), "bl_lower_" + tag, True),
    })


def _seg_d(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, float(np.dot(p - a, ab) / (np.dot(ab, ab) + 1e-9))))
    return float(np.linalg.norm(p - (a + ab * t)))


def w_near(bones, power=4.0, top=2):
    """Weights by nearness to the named bones' segments: the nearest two, inverse distance to a power."""
    segs = [(b, BONES[b][0], BONES[b][1]) for b in bones]

    def f(p):
        d = sorted(((_seg_d(p, a, c), b) for b, a, c in segs))[:top]
        w = {b: 1.0 / max(dd, 0.01) ** power for dd, b in d}
        t = sum(w.values())
        return {b: v / t for b, v in w.items()}
    return f


TRUNK = ["pelvis", "spine", "chest", "neck"]
w_trunk = w_near(TRUNK)
w_head = w_near(["neck", "head"])
w_tail = w_near(["pelvis", "tail_0", "tail_1", "tail_2", "tail_3"])


def w_leg(pre, tag):
    return w_near([pre + "upper_" + tag, pre + "lower_" + tag, pre + "foot_" + tag, "chest" if pre == "fl_" else "pelvis"], power=5.0)


# --- the body ----------------------------------------------------------------------------------------------

def thorn(g, base, d, ln, r, weights, col=None):
    d = d / (np.linalg.norm(d) + 1e-9)
    bend = np.cross(d, V(1, 0, 0))
    bend = bend / (np.linalg.norm(bend) + 1e-9) if np.linalg.norm(bend) > 1e-6 else V(0, 0, 1)
    K.tube(g, [base, base + d * ln * 0.55 + bend * ln * 0.06, base + d * ln + bend * ln * 0.18], [r, r * 0.45, r * 0.05], 5,
           tuple(THORN if col is None else col), "wood", weights)


def trunk(g):
    """The barrel: hips to the shoulders, deep at the chest, a hump of hackles over the shoulders; bark plates over it,
    moss along the back, thorns down the spine."""
    path = [V(0, 0.9, 0.66), V(0, 0.94, 0.5), V(0, 0.97, 0.26), V(0, 0.99, 0.02), V(0, 1.02, -0.22), V(0, 1.04, -0.42), V(0, 1.06, -0.56)]
    radii = [0.13, 0.22, 0.25, 0.27, 0.31, 0.3, 0.2]
    K.tube(g, path, radii, 22, tuple(BARK), "wood", w_trunk, squash=(0.82, 1.0), ref=V(0, 1, 0))
    # bark plates over the flanks and back, overlapping like a pine's
    rng = np.random.default_rng(3)
    for k in range(90):
        z = rng.uniform(-0.5, 0.58)
        ang = rng.uniform(-2.3, 2.3)                        # 0 the top of the back
        i = min(len(path) - 2, max(0, int(np.searchsorted([-p[2] for p in path], -z)) - 1))
        p0, p1 = path[i], path[i + 1]
        t = (z - p0[2]) / ((p1[2] - p0[2]) or 1e-6)
        c = p0 + (p1 - p0) * t
        r = radii[i] + (radii[i + 1] - radii[i]) * t
        n = V(math.sin(ang) * 0.82, math.cos(ang), 0.0)
        n = n / np.linalg.norm(n)
        at = c + V(math.sin(ang) * r * 0.82, math.cos(ang) * r, 0.0)
        col = BARK_LT * rng.uniform(0.75, 1.05) if k % 3 else BARK_DK * rng.uniform(0.9, 1.3)
        yaw = math.atan2(n[0], n[1])
        K.blob(g, at + n * 0.005, [0.05, 0.016, 0.13], tuple(col), "wood", w_trunk, basis=K.rot_z(-yaw) @ K.rot_x(-0.12), rings=4, segs=8, power=0.55,
               lumps=0.18, seed=k)
    # moss on the back
    for k in range(16):
        z = rng.uniform(-0.3, 0.5)
        x = rng.uniform(-0.1, 0.1)
        i = min(len(path) - 2, max(0, int(np.searchsorted([-p[2] for p in path], -z)) - 1))
        y = path[i][1] + radii[i] * 0.98
        K.blob(g, V(x, y, z), [0.08, 0.03, 0.09], tuple(MOSS if k % 2 else MOSS_LT), "fur", w_trunk, rings=4, segs=8, lumps=0.35, seed=40 + k)
    # thorns down the spine, the hackle hump over the shoulders the tallest
    for k in range(16):
        z = 0.55 - k * 0.075
        i = min(len(path) - 2, max(0, int(np.searchsorted([-p[2] for p in path], -z)) - 1))
        y = path[i][1] + radii[i] * 0.95
        hump = smooth(0.0, -0.3, z) * smooth(-0.62, -0.42, z)
        ln = 0.08 + 0.2 * hump + 0.03 * (k % 2)
        for sx in ((-0.05, 0.05) if hump > 0.3 else (0.0,)):
            thorn(g, V(sx, y - 0.02, z), V(sx * 4, 1.0, 0.35), ln, 0.028 + 0.02 * hump, w_trunk)
    # the belly darker, a tuft of root-hair under it
    for k in range(6):
        z = -0.2 + 0.12 * k
        thorn(g, V(0, 0.73 + 0.01 * k, z), V(0, -1, 0.3), 0.08, 0.02, w_trunk, ROOT)


def neck_head(g):
    # the neck: thick at the shoulders, down and forward, thorn hackles along its crest
    path = [V(0, 1.04, -0.42), V(0, 1.07, -0.58), V(0, 1.1, -0.72), V(0, 1.12, -0.82)]
    K.tube(g, path, [0.22, 0.17, 0.13, 0.12], 16, tuple(BARK), "wood", w_head, squash=(0.85, 1.0))
    for k in range(5):
        z = -0.48 - 0.07 * k
        thorn(g, V(0, 1.2 - 0.01 * k - (0.04 if k > 2 else 0.0), z), V(0, 1.0, 0.5), 0.18 - 0.025 * k, 0.03, w_head)
    # the skull: a long wolf's head of bark plates, the brow heavy, the snout long
    hc = V(0, 1.13, -0.86)
    K.blob(g, hc, [0.12, 0.1, 0.12], tuple(BARK), "wood", "head", rings=8, segs=14, lumps=0.06, seed=2)
    K.tube(g, [hc + V(0, -0.005, -0.06), hc + V(0, -0.03, -0.17), hc + V(0, -0.06, -0.27)], [0.085, 0.065, 0.045], 12, tuple(BARK_LT), "wood", "head",
           squash=(1.0, 0.8))
    K.blob(g, hc + V(0, -0.065, -0.29), [0.035, 0.025, 0.025], HOLLOW, "wood", "head", rings=4, segs=8)            # the nose
    for s in (-1.0, 1.0):
        K.blob(g, hc + V(s * 0.065, 0.04, -0.07), [0.05, 0.022, 0.05], tuple(BARK_DK), "wood", "head", basis=K.rot_z(s * 0.3), rings=4, segs=8)   # brow
        K.blob(g, hc + V(s * 0.06, 0.02, -0.1), [0.024, 0.014, 0.014], EMBER, "eye", "head", basis=K.rot_y(s * 0.4), rings=4, segs=10, glow=True)
        K.tube(g, [hc + V(s * 0.07, 0.06, 0.04), hc + V(s * 0.11, 0.13, 0.08), hc + V(s * 0.12, 0.17, 0.1)], [0.03, 0.02, 0.004], 6, tuple(BARK_LT), "wood", "head")  # ears
    # the jaw and its thorn teeth
    jb = V(0, 1.04, -0.88)
    K.tube(g, [jb, jb + V(0, -0.03, -0.12), jb + V(0, -0.05, -0.22)], [0.07, 0.05, 0.035], 10, tuple(BARK_DK), "wood", "jaw", squash=(1.0, 0.6))
    for k in range(5):
        for s in (-1.0, 1.0):
            t = 0.04 + 0.04 * k
            thorn(g, hc + V(s * (0.045 - 0.006 * k), -0.06 - 0.008 * k, -0.08 - t), V(0, -1, -0.2), 0.04, 0.01, "head", (0.8, 0.74, 0.6))
            thorn(g, jb + V(s * (0.04 - 0.006 * k), -0.01 - 0.01 * k, -0.06 - t), V(0, 1, -0.2), 0.03, 0.009, "jaw", (0.8, 0.74, 0.6))
    # the crown of briar antlers: twisted branches up and back, forking, thorned, berries on them
    rng = np.random.default_rng(23)

    def branch(p, d, ln, r, depth, s):
        pts = [p]
        q = p
        dd = d / np.linalg.norm(d)
        for k in range(4):
            dd = dd + V(rng.uniform(-0.25, 0.25), rng.uniform(-0.1, 0.25), rng.uniform(-0.2, 0.2))
            dd = dd / np.linalg.norm(dd)
            q = q + dd * ln / 4
            pts.append(q)
        K.tube(g, pts, [r, r * 0.85, r * 0.68, r * 0.5, r * 0.25], 6, tuple(BARK_DK if depth else BARK), "wood", "head")
        for k in (1, 2, 3):
            if rng.random() < 0.7:
                out = np.cross(dd, V(0, 1, 0)) * rng.choice([-1, 1]) + V(0, 0.3, 0)
                thorn(g, pts[k], out, r * 2.5, r * 0.45, "head")
        if rng.random() < 0.35:
            K.blob(g, pts[2] + V(0, -r, 0), [0.016] * 3, BERRY, "skin", "head", rings=3, segs=6)
        if depth < 2:
            for k in ((1, 2, 4) if depth == 0 else (2, 4)):
                nd = dd + V(s * rng.uniform(0.3, 0.8), rng.uniform(0.2, 0.6), rng.uniform(-0.1, 0.4))
                branch(pts[k], nd, ln * 0.6, r * 0.6, depth + 1, s)

    for s in (-1.0, 1.0):
        branch(hc + V(s * 0.06, 0.08, 0.02), V(s * 0.75, 1.0, 0.5), 0.55, 0.045, 0, s)


def heart(g):
    """The heart-knot at the breast: roots woven into a cage round a light."""
    K.blob(g, HEART_AT, [0.07, 0.08, 0.07], HEART, "eye", "chest", rings=8, segs=12, glow=True)
    for k in range(7):
        a = TAU * k / 7
        pts = []
        for t in np.linspace(0, 1, 7):
            th = a + t * 2.2
            r = 0.09 * math.sin(t * math.pi) + 0.02
            pts.append(HEART_AT + V(math.cos(th) * r, -0.13 + 0.26 * t, math.sin(th) * r * 0.9))
        K.tube(g, pts, [0.012] * len(pts), 5, tuple(ROOT if k % 2 else BARK_DK), "wood", "chest")
    # the roots that hold it, running up into the chest
    for s in (-1.0, 1.0):
        K.tube(g, [HEART_AT + V(s * 0.05, 0.08, 0.0), HEART_AT + V(s * 0.12, 0.17, 0.08), V(s * 0.16, 0.98, -0.38)], [0.018, 0.02, 0.016], 6, tuple(ROOT), "wood", "chest")


def leg(g, pre, s, tag):
    up, lo, ft = BONES[pre + "upper_" + tag], BONES[pre + "lower_" + tag], BONES[pre + "foot_" + tag]
    a, b, c, d = up[0], up[1], lo[1], ft[1]
    front = pre == "fl_"
    w = w_leg(pre, tag)
    # the shoulder or haunch: a great muscle of bark grown into the flank, tapering into a corded leg; the knee knotted
    body_w = "chest" if front else "pelvis"
    mus = a + (b - a) * 0.28 + V(s * 0.02, 0.02, 0)
    K.blob(g, mus, [0.11, 0.2 if front else 0.22, 0.15 if front else 0.18], tuple(BARK), "wood",
           lambda p: {body_w: 0.45, pre + "upper_" + tag: 0.55} if p[1] > mus[1] else {pre + "upper_" + tag: 1.0},
           basis=K.rot_x(-0.12 if front else 0.35), rings=8, segs=12, lumps=0.05, seed=3)
    for k in range(4):                                     # bark plates on the muscle
        K.blob(g, mus + V(s * 0.1, 0.08 - 0.07 * k, (-0.04 + 0.03 * k) * (1 if front else -1)), [0.02, 0.05, 0.07], tuple(BARK_LT if k % 2 else BARK_DK), "wood",
               w, rings=4, segs=8, power=0.6, lumps=0.15, seed=11 + k)
    K.tube(g, [a + (b - a) * 0.4, a + (b - a) * 0.75, b], [0.075, 0.06, 0.05], 10, tuple(BARK_DK), "wood", w)
    K.blob(g, b, [0.058, 0.06, 0.062], tuple(BARK_DK), "wood", w, rings=5, segs=8, lumps=0.2, seed=7)
    for k in range(3):
        o = V(math.cos(k * 2.1) * 0.03, 0, math.sin(k * 2.1) * 0.03)
        K.tube(g, [b + o, b + (c - b) * 0.5 + o * 1.3, c + o * 0.7], [0.042, 0.036, 0.032], 7, tuple(ROOT if k == 1 else BARK), "wood", w, twist=0.3)
    # the paw: root claws splayed
    K.blob(g, c + V(0, -0.02, -0.03), [0.07, 0.04, 0.08], tuple(BARK_DK), "wood", w, rings=5, segs=8, lumps=0.2)
    for k in range(4):
        sp = (k - 1.5) * 0.035
        tip = c + V(sp * 1.4, -0.07, -0.16)
        K.tube(g, [c + V(sp, -0.02, -0.05), c + V(sp * 1.2, -0.05, -0.11), tip], [0.018, 0.014, 0.003], 5, tuple(THORN * 0.9), "wood", w)
    if front:
        for k in range(3):                                  # thorns on the back of the forearm
            p = b + (c - b) * (0.2 + 0.3 * k)
            thorn(g, p + V(0, 0, 0.03), V(s * 0.3, 0.2, 1.0), 0.07, 0.016, w)


def tail(g):
    pts = [BONES["tail_0"][0]] + [BONES["tail_%d" % i][1] for i in range(4)]
    K.tube(g, pts, [0.07, 0.055, 0.04, 0.03, 0.012], 10, tuple(BARK), "wood", w_tail, twist=0.4)
    rng = np.random.default_rng(31)
    for k in range(14):
        i = k / 13.0 * 3.99
        j = int(i)
        p = pts[j] + (pts[j + 1] - pts[j]) * (i - j)
        a = rng.uniform(0, TAU)
        thorn(g, p, V(math.cos(a), math.sin(a) * 0.6 + 0.4, 0.3), 0.06, 0.014, w_tail)
    tip = pts[-1]
    for k in range(6):
        a = TAU * k / 6
        K.tube(g, [tip, tip + V(math.cos(a) * 0.06, math.sin(a) * 0.06, 0.12)], [0.012, 0.002], 5, tuple(BARK_DK), "wood", "tail_3")


def build_body():
    g = K.Geo()
    trunk(g)
    neck_head(g)
    heart(g)
    for s, tag in ((-1.0, "l"), (1.0, "r")):
        leg(g, "fl_", s, tag)
        leg(g, "bl_", s, tag)
    tail(g)
    return g


# --- the clips ---------------------------------------------------------------------------------------------
X = V(-1, 0, 0)     # + tips a forward bone's end down (the head bows) and swings a hanging leg back
Y = V(0, 1, 0)
Z = V(0, 0, 1)


def m(*poses, **over):
    out = {}
    for p in poses:
        out.update(p)
    out.update(over)
    return out


REST = m(neck=[(X, 4)], head=[(X, 6)], tail_0=[(X, 6)], tail_1=[(X, 6)], tail_2=[(X, 4)])


def legs(fl_l=0.0, fl_r=0.0, bl_l=0.0, bl_r=0.0, lift=None):
    """Leg swings (deg, + back) with the lower joints bent by how far each leg is lifted (lift[leg] 0..1)."""
    lift = lift or {}
    out = {}
    for nm, deg in (("fl_l", fl_l), ("fl_r", fl_r), ("bl_l", bl_l), ("bl_r", bl_r)):
        pre, tag = nm[:3], nm[3]
        k = lift.get(nm, 0.0)
        out[pre + "upper_" + tag] = [(X, deg)]
        out[pre + "lower_" + tag] = [(X, (-40.0 if pre == "fl_" else 46.0) * k)]
        out[pre + "foot_" + tag] = [(X, (50.0 if pre == "fl_" else -30.0) * k)]
    return out


def clips(arm):
    rest = m(REST)
    chains = [["tail_0", "tail_1", "tail_2", "tail_3"]]
    sniff = m(REST, neck=[(X, 14), (Y, -10)], head=[(X, 14), (Y, -8)], jaw=[(X, 4)])
    look = m(REST, neck=[(X, -4), (Y, 14)], head=[(X, -2), (Y, 10)], spine=[(Z, 2)])
    breathe = m(REST, chest=[(X, -2)], neck=[(X, 2)], jaw=[(X, 6)])
    K.key_clip(arm, "idle", [(0.0, rest), (1.4, breathe), (2.6, sniff), (3.8, rest), (5.0, look), (6.4, rest)], 6.4, loop=True, chains=chains, ripple=0.12)
    # walk: a heavy trot, diagonal pairs, the head nodding with the forefeet
    def trot(s):
        return m(REST, legs(fl_l=-22 * s, fl_r=22 * s, bl_l=20 * s, bl_r=-20 * s,
                            lift={"fl_l": 0.6 if s > 0 else 0.0, "fl_r": 0.6 if s < 0 else 0.0, "bl_r": 0.6 if s > 0 else 0.0, "bl_l": 0.6 if s < 0 else 0.0}),
                 spine=[(Y, 4 * s), (Z, 2 * s)], neck=[(X, 8), (Y, -4 * s)], head=[(X, 4)])
    K.key_clip(arm, "walk", [(0.0, trot(1)), (0.55, trot(-1)), (1.1, trot(1))], 1.1, loop=True, chains=chains, ripple=0.08,
               root_keys=[(0.0, (0, 0, 0)), (0.275, (0, 0.03, 0)), (0.55, (0, 0, 0)), (0.825, (0, 0.03, 0)), (1.1, (0, 0, 0))])
    # run: a bounding gallop, the spine bunching and stretching
    stretch = m(REST, legs(fl_l=-50, fl_r=-42, bl_l=44, bl_r=50, lift={"fl_l": 0.2, "fl_r": 0.3}), pelvis=[(X, -8)], spine=[(X, 6)], chest=[(X, 4)],
                neck=[(X, -6)], head=[(X, 4)])
    gather = m(REST, legs(fl_l=30, fl_r=36, bl_l=-40, bl_r=-34, lift={"fl_l": 0.9, "fl_r": 0.8, "bl_l": 0.7, "bl_r": 0.8}), pelvis=[(X, 10)], spine=[(X, -8)],
               chest=[(X, -6)], neck=[(X, 14)], head=[(X, 6)])
    K.key_clip(arm, "run", [(0.0, stretch), (0.33, gather), (0.66, stretch)], 0.66, loop=True, chains=chains, ripple=0.05,
               root_keys=[(0.0, (0, 0.06, 0)), (0.33, (0, -0.02, 0)), (0.66, (0, 0.06, 0))])
    # the tell (the pounce's crouch, the volley's): down on the haunches, the crown lowered at you, the heart showing
    crouch = m(REST, legs(fl_l=-14, fl_r=-14, bl_l=-26, bl_r=-26, lift={"fl_l": 0.5, "fl_r": 0.5, "bl_l": 0.7, "bl_r": 0.7}),
               pelvis=[(X, 8)], spine=[(X, -4)], neck=[(X, 22)], head=[(X, 18)], tail_0=[(X, -20)], tail_1=[(X, -10)])
    coil = m(crouch, neck=[(X, 26)], head=[(X, 22)], jaw=[(X, 16)])
    K.key_clip(arm, "windup", [(0.0, rest), (0.35, crouch), (0.7, coil)], 0.7, chains=chains,
               root_keys=[(0.0, (0, 0, 0)), (0.35, (0, -0.1, 0.02)), (0.7, (0, -0.14, 0.04))])
    K.key_clip(arm, "windup_hold", [(0.0, coil), (0.5, m(coil, jaw=[(X, 22)], head=[(X, 24)])), (1.0, coil)], 1.0, loop=True, chains=chains,
               root_keys=[(0.0, (0, -0.14, 0.04)), (0.5, (0, -0.15, 0.05)), (1.0, (0, -0.14, 0.04))])
    lunge = m(REST, legs(fl_l=-40, fl_r=-30, bl_l=30, bl_r=34, lift={"fl_l": 0.3}), pelvis=[(X, -6)], spine=[(X, 4)], neck=[(X, -6)], head=[(X, 28)],
              jaw=[(X, 30)], tail_0=[(X, -10)])
    K.key_clip(arm, "strike", [(0.0, coil), (0.1, lunge), (0.22, m(lunge, head=[(X, 36)], jaw=[(X, 4)])), (0.6, m(REST, neck=[(X, 10)])), (1.1, rest)], 1.1,
               chains=chains, root_keys=[(0.0, (0, -0.14, 0.04)), (0.1, (0, 0.02, -0.22)), (0.22, (0, -0.02, -0.26)), (1.1, (0, 0, 0))])
    # the leap: stretched in the air, then the landing taken low
    fly = m(REST, legs(fl_l=-70, fl_r=-62, bl_l=60, bl_r=66, lift={"fl_l": 0.2, "fl_r": 0.2}), pelvis=[(X, -6)], neck=[(X, -10)], head=[(X, 10)],
            jaw=[(X, 18)], tail_0=[(X, -14)], tail_1=[(X, -10)])
    K.key_clip(arm, "air", [(0.0, fly), (0.5, m(fly, neck=[(X, -4)], head=[(X, 20)])), (1.0, fly)], 1.0, loop=True, chains=chains)
    land = m(REST, legs(fl_l=-10, fl_r=-6, bl_l=-20, bl_r=-24, lift={"fl_l": 0.7, "fl_r": 0.7, "bl_l": 0.8, "bl_r": 0.8}), neck=[(X, 18)], head=[(X, 14)])
    K.key_clip(arm, "land", [(0.0, fly), (0.08, land), (0.5, m(REST, neck=[(X, 10)])), (0.7, rest)], 0.7, chains=chains,
               root_keys=[(0.0, (0, 0, 0)), (0.08, (0, -0.16, 0)), (0.5, (0, -0.02, 0)), (0.7, (0, 0, 0))])
    reel = m(REST, legs(fl_l=-20, fl_r=10, bl_r=10), spine=[(Z, 8)], neck=[(X, -20), (Z, 14)], head=[(X, -20), (Y, 20)], jaw=[(X, 20)])
    K.key_clip(arm, "stagger", [(0.0, rest), (0.12, reel), (0.6, m(REST, neck=[(X, 24)], head=[(X, 20)], spine=[(Z, -6)])), (1.6, rest)], 1.6, chains=chains,
               root_keys=[(0.0, (0, 0, 0)), (0.12, (0, 0.03, 0.12)), (0.6, (0, -0.06, 0.1)), (1.6, (0, 0, 0))])
    # the roar (the generic call): rearing a little, the head thrown up, the jaw wide
    roar = m(REST, legs(fl_l=-30, fl_r=-26, bl_l=-10, bl_r=-10, lift={"fl_l": 0.5}), pelvis=[(X, -16)], spine=[(X, -10)], neck=[(X, -40)], head=[(X, -20)],
             jaw=[(X, 34)], tail_0=[(X, -20)])
    K.key_clip(arm, "howl", [(0.0, rest), (0.4, m(REST, neck=[(X, 20)], head=[(X, 10)])), (0.9, roar), (1.6, m(roar, head=[(X, -26)])), (2.0, rest)], 2.0,
               chains=chains, root_keys=[(0.0, (0, 0, 0)), (0.9, (0, 0.1, 0.06)), (1.6, (0, 0.1, 0.06)), (2.0, (0, 0, 0))])
    side = m(REST, legs(fl_l=-30, fl_r=20, bl_l=30, bl_r=-20, lift={"fl_l": 0.5, "bl_r": 0.6}), spine=[(Z, 80)], pelvis=[(Z, 10)], neck=[(X, 30), (Z, 10)],
             head=[(X, 20)], jaw=[(X, 26)])
    K.key_clip(arm, "death", [(0.0, rest), (0.4, reel), (1.0, m(REST, legs(bl_l=-30, bl_r=-30, lift={"bl_l": 0.9, "bl_r": 0.9}), neck=[(X, 30)])), (1.9, side), (2.6, side)],
               2.6, chains=chains, root_keys=[(0.0, (0, 0, 0)), (1.0, (0, -0.2, 0)), (1.9, (0.25, -0.5, 0)), (2.6, (0.26, -0.52, 0))])
    # Thornstorm (3.2 s, cannot be broken): it rears up on its hind legs, forelegs raking the air, and comes down at 3.2
    rear = m(REST, legs(fl_l=-70, fl_r=-50, bl_l=-50, bl_r=-46, lift={"fl_l": 0.9, "fl_r": 1.0, "bl_l": 0.4, "bl_r": 0.4}), pelvis=[(X, -46)], spine=[(X, -8)],
             chest=[(X, -6)], neck=[(X, -10)], head=[(X, -4)], jaw=[(X, 30)], tail_0=[(X, 30)], tail_1=[(X, 10)])
    rear2 = m(rear, legs(fl_l=-50, fl_r=-74, bl_l=-50, bl_r=-46, lift={"fl_l": 1.0, "fl_r": 0.8, "bl_l": 0.4, "bl_r": 0.4}), neck=[(X, -16)], head=[(X, -10)])
    crash = m(REST, legs(fl_l=-20, fl_r=-20, bl_l=-10, bl_r=-10, lift={"fl_l": 0.6, "fl_r": 0.6}), pelvis=[(X, 6)], neck=[(X, 30)], head=[(X, 20)], jaw=[(X, 26)])
    K.key_clip(arm, "thornstorm", [(0.0, rest), (0.6, crouch), (1.3, rear), (1.9, rear2), (2.5, rear), (2.9, rear2), (3.2, crash), (3.6, m(crash, neck=[(X, 24)])),
                                   (4.3, rest)], 4.3, chains=chains,
               root_keys=[(0.0, (0, 0, 0)), (0.6, (0, -0.1, 0)), (1.3, (0, 0.35, 0.3)), (2.9, (0, 0.35, 0.3)), (3.2, (0, -0.08, -0.05)), (4.3, (0, 0, 0))])
    # Briar Snare (1.3 s): head down, the crown raking the ground side to side
    def rake(a):
        return m(REST, legs(fl_l=-10, fl_r=-10, lift={"fl_l": 0.4, "fl_r": 0.4}), spine=[(Y, a * 0.3)], neck=[(X, 40), (Y, a)], head=[(X, 30), (Z, a * 0.4)])
    K.key_clip(arm, "snare", [(0.0, rest), (0.4, rake(-20)), (0.7, rake(22)), (1.0, rake(-18)), (1.3, rake(10)), (1.8, rest)], 1.8, chains=chains,
               root_keys=[(0.0, (0, 0, 0)), (0.4, (0, -0.08, 0)), (1.3, (0, -0.08, 0)), (1.8, (0, 0, 0))])
    # Sap Mending (3.0 s, breakable): it lies down and curls round, drinking from the henge with its head to the ground
    curl = m(REST, legs(fl_l=-60, fl_r=-56, bl_l=-80, bl_r=-80, lift={"fl_l": 1.0, "fl_r": 1.0, "bl_l": 1.0, "bl_r": 1.0}), spine=[(Y, -18)], chest=[(Y, -14)],
             neck=[(X, 50), (Y, -20)], head=[(X, 20)], tail_0=[(Y, -30)], tail_1=[(Y, -30)], tail_2=[(Y, -20)])
    sip = m(curl, head=[(X, 30)], jaw=[(X, 14)])
    K.key_clip(arm, "mend", [(0.0, rest), (0.7, curl), (1.3, sip), (1.8, curl), (2.4, sip), (3.0, curl), (3.7, rest)], 3.7, chains=chains,
               root_keys=[(0.0, (0, 0, 0)), (0.7, (0, -0.42, 0)), (3.0, (0, -0.42, 0)), (3.7, (0, 0, 0))])
    # Rooting (the intermission, 2.0 s): its legs sink into the altar, the head bowed, the crown low
    sink = m(REST, legs(fl_l=-20, fl_r=-20, bl_l=-30, bl_r=-30, lift={"fl_l": 0.8, "fl_r": 0.8, "bl_l": 0.9, "bl_r": 0.9}), neck=[(X, 34)], head=[(X, 24)],
             tail_0=[(X, 20)], tail_1=[(X, 20)])
    K.key_clip(arm, "rooting", [(0.0, rest), (0.8, m(REST, neck=[(X, -20)], head=[(X, -14)], jaw=[(X, 30)])), (1.4, sink), (2.0, m(sink, neck=[(X, 38)])),
                                (2.6, sink)], 2.6, chains=chains,
               root_keys=[(0.0, (0, 0, 0)), (0.8, (0, 0.06, 0)), (1.4, (0, -0.24, 0)), (2.6, (0, -0.3, 0))])
    K.key_clip(arm, "rooted_hold", [(0.0, sink), (2.0, m(sink, neck=[(X, 40)], head=[(X, 28)], chest=[(X, 3)], jaw=[(X, 8)])), (4.0, sink)], 4.0, loop=True,
               chains=chains, ripple=0.08, root_keys=[(0.0, (0, -0.3, 0)), (2.0, (0, -0.32, 0)), (4.0, (0, -0.3, 0))])
    # Bloom of Thorns (1.4 s, rings at 1.4/2.3/3.2): the spine arches, a shudder, the thorns stand
    arch = m(REST, legs(fl_l=-10, fl_r=-10, bl_l=10, bl_r=10), pelvis=[(X, 8)], spine=[(X, -14)], chest=[(X, -6)], neck=[(X, 24)], head=[(X, 20)])
    shud = m(arch, spine=[(X, -16), (Z, 4)], neck=[(X, 26), (Z, -6)])
    K.key_clip(arm, "bloom", [(0.0, rest), (0.6, arch), (1.0, shud), (1.2, arch), (1.4, m(REST, neck=[(X, -24)], head=[(X, -16)], jaw=[(X, 30)])),
                              (2.0, m(REST, neck=[(X, -10)])), (2.6, rest)], 2.6, chains=chains,
               root_keys=[(0.0, (0, 0, 0)), (1.2, (0, -0.06, 0)), (1.4, (0, 0.06, 0)), (2.6, (0, 0, 0))])


def main():
    K.clear_scene()
    g = build_body()
    ob = K.make_object(g, "Thornwarden", subdiv=0)
    arm = K.build_armature(BONES, "ThornRig")
    K.bind(ob, arm)
    print("VB TRIS", sum(len(p.vertices) - 2 for p in ob.data.polygons))
    if DO_AO:
        K.bake_ao_alpha(ob)
    clips(arm)
    K.export_glb(arm, ob, OUT)
    if RENDERS:
        K.review_renders(arm, ob, RENDERS, "thorn", 1.4, poses=[("walk", 0.27, 90.0), ("run", 0.33, 90.0), ("windup_hold", 0.0, 40.0),
                                                                ("strike", 0.1, 70.0), ("air", 0.0, 90.0), ("thornstorm", 1.9, 60.0),
                                                                ("snare", 0.7, 30.0), ("mend", 1.3, 40.0), ("death", 2.6, 40.0)])
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(K.ROOT, "art/blender/vb_thornwarden.blend"))


main()
