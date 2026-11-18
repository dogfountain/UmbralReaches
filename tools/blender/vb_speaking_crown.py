"""The Speaking Crown (the Hierarch's cantor), modelled in Blender in the villagers' style (18 Nov). Run:
    blender -b -P tools/blender/vb_speaking_crown.py -- [--out art/models/bosses/vb_speaking_crown.glb] [--renders <dir>] [--no-ao]

Its own design (core/enemy/hierarch_voice.gd, crown_body.gd): the colossus's head was hollow so one voice could be
heard across the Marches, and the boy who spoke the edicts through it was never let out. A squat, heavy husk under a
stone cope that hangs to the shins like a bell, carved bands round it, cracked, embers in the cracks; great stone
pauldrons, thick stone arms and huge fists bound in bronze; stone pillar legs under the hem. Where a head should be,
a bronze speaking-horn rises out of the shoulders, tipped forward like a gramophone, its mouth six bronze petals that
close to a bud at rest and flare open when it speaks (the tell, and its weak point: the throat glowing within); round
the horn's root a crown of stone tines, prayer flags tied about its neck; a chain of small bells at the girdle.

Silhouette: a squat stone bell with a great horn for a head; the petals opening read from across the skull.

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


OUT = os.path.join(K.ROOT, arg("--out", "art/models/bosses/vb_speaking_crown.glb"))
RENDERS = arg("--renders")
DO_AO = "--no-ao" not in ARGS

STONE = np.array([0.38, 0.36, 0.33])          # (0.44 read pale cream under the skull's fires)
STONE_LT = np.array([0.45, 0.43, 0.39])
STONE_DK = np.array([0.26, 0.25, 0.23])
BRONZE = np.array([0.55, 0.4, 0.2])
BRONZE_LT = np.array([0.68, 0.52, 0.28])
BRONZE_DK = np.array([0.32, 0.22, 0.11])
VERDIGRIS = np.array([0.3, 0.45, 0.38])
CRACK = (1.0, 0.5, 0.16)
VOICE = (1.0, 0.85, 0.55)
HOLLOW = (0.03, 0.025, 0.025)
FLAGS = [(0.55, 0.2, 0.15), (0.62, 0.56, 0.4), (0.3, 0.36, 0.48), (0.5, 0.42, 0.22)]

B = V(0, 1.42, -0.02)                       # the horn's root, on the shoulders
AX = np.array([0.0, 0.76, -0.65])
AX = AX / np.linalg.norm(AX)
M = B + AX * 0.5                            # the throat: where the petals hinge
S1, S2 = K._frame(AX, ref=V(1, 0, 0))       # the horn's cross-section axes
PETALS = 6
RIM_R = 0.36
PET_LEN = 0.26


def radial(th):
    return S1 * math.cos(th) + S2 * math.sin(th)


def petal_hinge(k):
    th = TAU * (k + 0.5) / PETALS
    return M + radial(th) * 0.13, th


BONES = {
    "root": (V(0, 0, 0), V(0, 0.12, 0), None, False),
    "pelvis": (V(0, 0.82, 0), V(0, 0.98, 0), "root", True),
    "spine": (V(0, 0.98, 0), V(0, 1.18, -0.01), "pelvis", True),
    "chest": (V(0, 1.18, -0.01), V(0, 1.4, -0.02), "spine", True),
    "head": (B, M, "chest", True),
}
for k in range(PETALS):
    h, th = petal_hinge(k)
    BONES["petal_%d" % k] = (h, h + AX * 0.12 + radial(th) * 0.12, "head", True)
for k in range(3):
    a = math.radians(-35 + 35 * k)
    top = V(math.sin(a) * 0.43, 0.84, -math.cos(a) * 0.36)
    BONES["bell_%d" % k] = (top, top + V(0, -0.16, 0), "pelvis", True)
for s, tag in ((-1.0, "l"), (1.0, "r")):
    BONES.update({
        "clav_" + tag: (V(s * 0.06, 1.36, -0.02), V(s * 0.34, 1.37, 0.0), "chest", True),
        "upper_" + tag: (V(s * 0.34, 1.37, 0.0), V(s * 0.41, 1.06, 0.02), "clav_" + tag, True),
        "fore_" + tag: (V(s * 0.41, 1.06, 0.02), V(s * 0.44, 0.76, -0.02), "upper_" + tag, True),
        "hand_" + tag: (V(s * 0.44, 0.76, -0.02), V(s * 0.45, 0.58, -0.05), "fore_" + tag, True),
        "thigh_" + tag: (V(s * 0.14, 0.8, 0.0), V(s * 0.16, 0.44, -0.01), "pelvis", True),
        "shin_" + tag: (V(s * 0.16, 0.44, -0.01), V(s * 0.16, 0.09, 0.01), "thigh_" + tag, True),
        "foot_" + tag: (V(s * 0.16, 0.09, 0.01), V(s * 0.16, 0.04, -0.16), "shin_" + tag, True),
    })


def w_spine(p):
    y = p[1]
    pts = [("pelvis", 0.86), ("spine", 1.06), ("chest", 1.26)]
    for k in range(len(pts) - 1):
        (b0, y0), (b1, y1) = pts[k], pts[k + 1]
        if y0 <= y <= y1:
            t = (y - y0) / (y1 - y0)
            return {b0: 1.0 - t, b1: t}
    return {"pelvis": 1.0} if y < 0.86 else {"chest": 1.0}


def w_cope(p):
    """The stone cope: rigid on the trunk; low at the front a little of each thigh, so the stride lifts its hem."""
    out = w_spine(p)
    if p[1] < 0.7:
        side = "r" if p[0] > 0 else "l"
        k = 0.3 * smooth(0.7, 0.35, p[1]) * smooth(0.0, 0.2, abs(p[0])) * smooth(0.1, -0.3, p[2])
        if k > 0.01:
            out = {b: w * (1.0 - k) for b, w in out.items()}
            out["thigh_" + side] = k
    return out


def w_arm(tag):
    def f(p):
        y = p[1]
        if y > 1.06:
            t = smooth(1.36, 1.15, y)
            return {"clav_" + tag: 1.0 - t, "upper_" + tag: t} if y > 1.25 else {"upper_" + tag: 1.0}
        t = smooth(1.1, 1.0, y)
        return {"upper_" + tag: 1.0 - t, "fore_" + tag: t} if y > 0.97 else {"fore_" + tag: 1.0}
    return f


def w_leg(tag):
    def f(p):
        y = p[1]
        if y > 0.44:
            t = smooth(0.5, 0.4, y)
            return {"thigh_" + tag: 1.0 - t, "shin_" + tag: t} if y < 0.5 else {"thigh_" + tag: 1.0}
        return {"shin_" + tag: 1.0} if y > 0.1 else {"foot_" + tag: 1.0}
    return f


# --- the body ----------------------------------------------------------------------------------------------

def cope(g):
    rng = np.random.default_rng(4)

    def fold(th, y, r):
        return (0.015 + 0.03 * smooth(1.2, 0.35, y)) * (0.7 * math.sin(8 * th + 0.3) + 0.3 * math.sin(15 * th + y * 3))

    def col(th, y, dr):
        ridge = (dr / 0.045) * 0.5 + 0.5
        c = STONE_DK * (1.0 - ridge) + STONE_LT * ridge
        moss = smooth(0.5, 0.33, y) * (0.5 + 0.5 * math.sin(5 * th + 1))
        return tuple(c * (1 - 0.3 * moss) + np.array([0.25, 0.3, 0.2]) * 0.3 * moss)

    prof = []
    for k in range(20):
        u = k / 19.0
        y = 1.46 - u * (1.46 - 0.34)
        r = 0.2 + 0.32 * math.sin(min(1.0, u * 1.25) * math.pi * 0.5) + 0.02 * u
        prof.append((y, r))
    prof.reverse()
    K.lathe(g, prof, 72, col, "linen", w_cope, fold=fold, zscale=0.9,
            hem=lambda th: 0.025 * abs(math.sin(7 * th + 0.5)) + 0.02 * abs(math.sin(13 * th)))
    K.lathe(g, [(0.34, 0.5), (0.36, 0.48), (0.42, 0.44)], 72, HOLLOW, "linen", w_cope, zscale=0.9)
    # carved bands: a broad one above the hem, a narrow one at the waist; bronze studs on the broad one
    def r_at(y):
        for k in range(len(prof) - 1):
            (y0, r0), (y1, r1) = prof[k], prof[k + 1]
            if y0 <= y <= y1:
                return r0 + (r1 - r0) * (y - y0) / (y1 - y0)
        return prof[-1][1]
    for y, w, c in ((0.47, 0.05, STONE_LT), (0.98, 0.025, STONE_LT * 0.95)):
        band = [(y - w, r_at(y - w) + 0.03), (y - w * 0.4, r_at(y) + 0.05), (y + w * 0.4, r_at(y) + 0.05), (y + w, r_at(y + w) + 0.03)]
        K.lathe(g, band, 72, tuple(c), "linen", w_cope, fold=fold, zscale=0.9)
    for i in range(16):
        a = TAU * i / 16
        r = r_at(0.47) + 0.08
        K.blob(g, V(math.sin(a) * r, 0.47, -math.cos(a) * r * 0.9), [0.022] * 3, tuple(BRONZE_LT), "metal", w_cope, rings=4, segs=8)
    # cracks with embers in them
    for i in range(7):
        a = TAU * i / 7 + rng.uniform(-0.2, 0.2)
        y = rng.uniform(1.05, 1.3)
        pts = []
        for k in range(6):
            yy = y - k * rng.uniform(0.08, 0.12)
            aa = a + rng.uniform(-0.12, 0.12)
            r = r_at(max(0.4, yy)) + 0.035
            pts.append(V(math.sin(aa) * r, yy, -math.cos(aa) * r * 0.9))
        K.tube(g, pts, [0.009, 0.012, 0.011, 0.012, 0.009, 0.005], 5, CRACK, "eye", w_cope, glow=True)
    # a girdle of bronze links, three small bells hung from it
    K.tube(g, [V(math.sin(a) * (r_at(0.86) + 0.05), 0.86, -math.cos(a) * (r_at(0.86) + 0.05) * 0.9) for a in np.linspace(0, TAU, 41)], [0.018] * 41, 6,
           tuple(BRONZE), "metal", "pelvis", caps=False)
    for k in range(3):
        a = math.radians(-35 + 35 * k)
        top = V(math.sin(a) * 0.43, 0.84, -math.cos(a) * 0.36)
        bb = "bell_%d" % k
        K.tube(g, [top, top + V(0, -0.08, 0)], [0.005, 0.005], 4, tuple(BRONZE_DK), "metal", bb)
        K.lathe(g, [(-0.15, 0.045), (-0.12, 0.04), (-0.09, 0.03), (-0.08, 0.0)], 12, tuple(BRONZE_LT), "metal", bb, centre=top, cap_top=True)


def shoulders(g):
    """Great stone pauldrons over the cope's shoulders, the yoke between them under the horn."""
    K.blob(g, V(0, 1.4, -0.0), [0.28, 0.1, 0.22], tuple(STONE), "linen", "chest", rings=7, segs=16, lumps=0.06, power=0.8)
    for s, tag in ((-1.0, "l"), (1.0, "r")):
        c = V(s * 0.36, 1.39, 0.0)
        K.blob(g, c, [0.17, 0.12, 0.17], tuple(STONE_LT), "linen", (lambda p, tag=tag: {"clav_" + tag: 0.4, "upper_" + tag: 0.6}), rings=8, segs=14, lumps=0.08, power=0.7, seed=3 + int(s))
        K.tube(g, [c + V(math.sin(a) * 0.175, -0.05, -math.cos(a) * 0.175) for a in np.linspace(-1.9, 1.9, 15)], [0.016] * 15, 6, tuple(BRONZE), "metal",
               (lambda p, tag=tag: {"clav_" + tag: 0.4, "upper_" + tag: 0.6}))
        for k in range(3):                                                    # chipped edges
            K.blob(g, c + V(s * (0.1 + 0.03 * k), 0.06 - 0.04 * k, -0.05 + 0.06 * k), [0.05, 0.035, 0.045], tuple(STONE_DK), "linen",
                   (lambda p, tag=tag: {"clav_" + tag: 0.4, "upper_" + tag: 0.6}), rings=4, segs=8, lumps=0.2, seed=20 + k)


def arm(g, s, tag):
    sh, el, wr = V(s * 0.36, 1.33, 0.0), V(s * 0.41, 1.06, 0.02), V(s * 0.44, 0.76, -0.02)
    K.tube(g, [sh, sh + (el - sh) * 0.5, el], [0.11, 0.1, 0.095], 12, tuple(STONE_DK), "linen", w_arm(tag))
    K.blob(g, el, [0.1, 0.1, 0.1], tuple(STONE), "linen", (lambda p, tag=tag: {"upper_" + tag: 0.5, "fore_" + tag: 0.5}), rings=6, segs=10, lumps=0.1)
    K.tube(g, [el, el + (wr - el) * 0.5, wr], [0.1, 0.1, 0.11], 12, tuple(STONE_DK), "linen", "fore_" + tag)
    for y in (0.0, 0.05):
        K.tube(g, [wr + V(math.sin(a) * 0.12, y, -math.cos(a) * 0.12) for a in np.linspace(0, TAU, 17)], [0.02] * 17, 6, tuple(BRONZE), "metal", "fore_" + tag, caps=False)
    # the fist: a great block, the knuckles bossed with bronze
    fc = V(s * 0.45, 0.62, -0.05)
    K.blob(g, fc, [0.14, 0.15, 0.15], tuple(STONE), "linen", "hand_" + tag, rings=8, segs=12, power=0.5, lumps=0.05, seed=7)
    for k in range(4):
        kp = fc + V(s * 0.01, 0.06 - 0.045 * k, -0.15)
        K.blob(g, kp, [0.045, 0.03, 0.03], tuple(STONE_LT), "linen", "hand_" + tag, rings=4, segs=8, power=0.6)
        K.blob(g, kp + V(0, 0, -0.022), [0.022, 0.016, 0.01], tuple(BRONZE_LT), "metal", "hand_" + tag, rings=3, segs=6)
    K.blob(g, fc + V(-s * 0.14, 0.03, -0.06), [0.04, 0.06, 0.045], tuple(STONE_LT), "linen", "hand_" + tag, rings=4, segs=8)       # the thumb


def legs(g):
    for s, tag in ((-1.0, "l"), (1.0, "r")):
        K.tube(g, [V(s * 0.15, 0.62, 0.0), V(s * 0.16, 0.44, -0.01), V(s * 0.16, 0.1, 0.01)], [0.12, 0.11, 0.1], 12, tuple(STONE_DK), "linen", w_leg(tag))
        K.blob(g, V(s * 0.16, 0.06, -0.06), [0.13, 0.065, 0.19], tuple(STONE), "linen", "foot_" + tag, rings=6, segs=12, power=0.6, lumps=0.08)
        for k in range(3):
            K.blob(g, V(s * (0.12 + 0.04 * k), 0.04, -0.24), [0.035, 0.035, 0.04], tuple(STONE_LT), "linen", "foot_" + tag, rings=4, segs=8)


def horn(g):
    """The speaking-horn: a bronze throat out of the shoulders, banded, verdigris in its seams; six petals at its
    mouth (on their own bones) that close to a bud and flare open; the voice glowing deep in the throat."""
    path = [B + AX * t for t in (-0.06, 0.08, 0.2, 0.32, 0.44, 0.5)]
    radii = [0.13, 0.1, 0.09, 0.095, 0.11, 0.13]
    K.tube(g, path, radii, 20, tuple(BRONZE), "metal", lambda p: {"chest": 1.0} if np.dot(p - B, AX) < 0.04 else {"head": 1.0}, caps=False)
    K.tube(g, path, [r - 0.012 for r in radii], 20, tuple(BRONZE_DK), "metal", "head", caps=False)
    for t, r in ((0.1, 0.105), (0.26, 0.1), (0.42, 0.12)):
        c = B + AX * t
        K.tube(g, [c + radial(a) * r for a in np.linspace(0, TAU, 21)], [0.016] * 21, 6, tuple(BRONZE_LT), "metal", "head", caps=False)
        K.tube(g, [c + radial(a) * (r + 0.004) + AX * 0.02 for a in np.linspace(0, TAU, 21)], [0.006] * 21, 4, tuple(VERDIGRIS), "metal", "head", caps=False)
    # the voice: a glow deep in the throat
    K.blob(g, M - AX * 0.06, [0.075, 0.075, 0.075], VOICE, "eye", "head", rings=6, segs=12, glow=True)
    # the petals: curved bronze plates from the throat ring to the rim, overlapping, each on its bone
    for k in range(PETALS):
        h, thc = petal_hinge(k)
        bone = "petal_%d" % k
        nu, nv = 7, 9
        a0, a1 = thc - math.pi / PETALS - 0.12, thc + math.pi / PETALS + 0.12
        def surf(u, v, inset):
            th = a0 + (a1 - a0) * v
            r = 0.13 + (RIM_R - 0.13) * (u ** 1.5) - inset
            tip = 0.03 * math.sin(v * math.pi) * u                                         # the petal's edge curls back
            return M + AX * (PET_LEN * u - inset * 0.3) + radial(th) * (r + tip)
        verts_o, verts_i, faces, cols_o, cols_i = [], [], [], [], []
        for i in range(nu):
            for j in range(nv):
                u, v = i / (nu - 1), j / (nv - 1)
                verts_o.append(surf(u, v, 0.0))
                verts_i.append(surf(u, v, 0.014))
                edge = smooth(0.7, 1.0, u) + smooth(0.15, 0.0, v) + smooth(0.85, 1.0, v)
                cols_o.append(tuple(BRONZE * (0.9 + 0.2 * (j % 2)) * (1 - 0.3 * min(1, edge)) + BRONZE_LT * 0.3 * min(1, edge)))
                cols_i.append(tuple(BRONZE_DK * (1.0 + 0.8 * (1 - u))))
        for i in range(nu - 1):
            for j in range(nv - 1):
                a = i * nv + j
                faces.append([a, a + nv, a + nv + 1, a + 1])
        uv = [(0.0, 0.0)] * len(verts_o)
        g.add(verts_o, faces, cols_o, "metal", uv, bone)
        g.add(verts_i, [list(reversed(f)) for f in faces], cols_i, "metal", uv, bone)
        # the rim's bead and a rivet line
        rim = [surf(1.0, v, 0.0) for v in np.linspace(0, 1, nv)]
        K.tube(g, rim, [0.012] * len(rim), 5, tuple(BRONZE_LT), "metal", bone, caps=False)
        K.blob(g, surf(0.35, 0.5, -0.004), [0.016] * 3, tuple(BRONZE_LT), "metal", bone, rings=3, segs=6)
    # the crown of tines round the horn's root, standing out of the yoke
    rng = np.random.default_rng(17)
    for i in range(9):
        a = TAU * i / 9 + 0.2
        base = V(math.sin(a) * 0.2, 1.43, -math.cos(a) * 0.17 - 0.02)
        out = V(math.sin(a), 0, -math.cos(a))
        ln = rng.uniform(0.22, 0.34) if i % 2 == 0 else rng.uniform(0.12, 0.2)
        if i == 4:
            ln = 0.08                                                     # one snapped
        pts = [base, base + V(0, ln * 0.5, 0) + out * 0.03, base + V(0, ln, 0) + out * 0.08]
        K.tube(g, pts, [0.04, 0.026, 0.004 if i != 4 else 0.02], 6, tuple(STONE_LT if i % 2 else STONE), "linen", "chest")
    # prayer flags tied round the throat
    c = B + AX * 0.3
    for i in range(8):
        a = TAU * i / 8
        p0 = c + radial(a) * 0.105
        ln = 0.12 + 0.05 * abs(math.sin(i * 2.3))
        K.tube(g, [p0, p0 + V(0, -ln * 0.5, 0) + radial(a) * 0.02, p0 + V(0, -ln, 0) + radial(a) * 0.03], [0.02, 0.022, 0.018], 4, FLAGS[i % 4], "linen", "head",
               squash=(1.0, 0.12), ref=radial(a))
    K.tube(g, [c + radial(a) * 0.108 for a in np.linspace(0, TAU, 21)], [0.007] * 21, 4, (0.46, 0.38, 0.26), "leather", "head", caps=False)


def build_body():
    g = K.Geo()
    cope(g)
    shoulders(g)
    for s, tag in ((-1.0, "l"), (1.0, "r")):
        arm(g, s, tag)
    legs(g)
    horn(g)
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


def petals(deg):
    """Every petal turned `deg` about its own hinge: + opens (flares the bell), - closes it to a bud."""
    out = {}
    for k in range(PETALS):
        h, th = petal_hinge(k)
        tang = np.cross(AX, radial(th))
        out["petal_%d" % k] = [(tang, deg)]
    return out


REST = m(petals(-24), spine=[(X, 4)], chest=[(X, 4)], head=[(X, 6)],
         upper_r=[(X, -6), (Z, 6)], fore_r=[(X, -14)], upper_l=[(X, -6), (Z, -6)], fore_l=[(X, -14)])


def P(*extra, **kw):
    return m(REST, *extra, **kw)


def clips(arm):
    rest = P()
    chains = [["bell_0"], ["bell_1"], ["bell_2"]]
    breathe = P(petals(-14), chest=[(X, 1)], head=[(X, 2), (Y, -10)], fore_r=[(X, -22)])
    look = P(petals(-20), chest=[(X, 5)], head=[(X, 8), (Y, 12)], fore_l=[(X, -22)], pelvis=[(Z, 2)])
    K.key_clip(arm, "idle", [(0.0, rest), (1.6, breathe), (3.2, rest), (4.8, look), (6.4, rest)], 6.4, loop=True, chains=chains, ripple=0.05)
    def stride(s):
        return P(pelvis=[(Y, 5 * s), (Z, 3 * s)], spine=[(X, 6), (Y, -4 * s)], chest=[(Y, -5 * s)], head=[(Y, 4 * s)],
                 thigh_r=[(X, -22 * s)], shin_r=[(X, 10 if s < 0 else 26)], thigh_l=[(X, 22 * s)], shin_l=[(X, 10 if s > 0 else 26)],
                 upper_r=[(X, -6 - 14 * s), (Z, 6)], upper_l=[(X, -6 + 14 * s), (Z, -6)])
    K.key_clip(arm, "walk", [(0.0, stride(1)), (0.9, stride(-1)), (1.8, stride(1))], 1.8, loop=True, chains=chains, ripple=0.03,
               root_keys=[(0.0, (0, 0, 0)), (0.45, (0, -0.03, 0)), (0.9, (0, 0, 0)), (1.35, (0, -0.03, 0)), (1.8, (0, 0, 0))])
    # the fist: both fists raised over the horn (the tell, held), hammered down together
    lift = P(petals(-30), spine=[(X, -8)], chest=[(X, -10)], head=[(X, -8)], clav_r=[(Z, 16)], clav_l=[(Z, -16)],
             upper_r=[(X, -150), (Z, -10)], fore_r=[(X, -40)], upper_l=[(X, -150), (Z, 10)], fore_l=[(X, -40)],
             thigh_r=[(X, -6)], thigh_l=[(X, 6)])
    lift2 = m(lift, upper_r=[(X, -158), (Z, -12)], upper_l=[(X, -158), (Z, 12)], chest=[(X, -13)])
    K.key_clip(arm, "windup", [(0.0, rest), (0.35, P(spine=[(X, 10)], chest=[(X, 8)], upper_r=[(X, -40)], upper_l=[(X, -40)])), (1.0, lift)], 1.0, chains=chains)
    K.key_clip(arm, "windup_hold", [(0.0, lift), (0.5, lift2), (1.0, lift)], 1.0, loop=True, chains=chains)
    slam = P(petals(-10), spine=[(X, 28)], chest=[(X, 22)], head=[(X, 18)], upper_r=[(X, -50), (Z, -14)], fore_r=[(X, -10)],
             upper_l=[(X, -50), (Z, 14)], fore_l=[(X, -10)], thigh_r=[(X, -22)], shin_r=[(X, 30)], thigh_l=[(X, -22)], shin_l=[(X, 30)])
    K.key_clip(arm, "strike", [(0.0, lift), (0.1, m(slam, upper_r=[(X, -90), (Z, -12)], upper_l=[(X, -90), (Z, 12)])), (0.18, slam),
                               (0.6, m(slam, spine=[(X, 30)])), (1.3, rest)], 1.3, chains=chains,
               root_keys=[(0.0, (0, 0, 0)), (0.18, (0, -0.08, 0)), (0.6, (0, -0.08, 0)), (1.3, (0, 0, 0))])
    reel = P(petals(10), spine=[(X, -14), (Z, 6)], chest=[(X, -10)], head=[(X, -24), (Z, 12)], upper_r=[(X, 10), (Z, 26)], upper_l=[(X, 10), (Z, -30)])
    slump = P(petals(-34), spine=[(X, 22)], chest=[(X, 16)], head=[(X, 30)], upper_r=[(X, -20)], upper_l=[(X, -20)], thigh_r=[(X, -16)], shin_r=[(X, 30)])
    K.key_clip(arm, "stagger", [(0.0, rest), (0.12, reel), (0.6, slump), (1.3, m(slump, head=[(X, 24), (Y, 14)])), (1.8, rest)], 1.8, chains=chains)
    cry = P(petals(28), spine=[(X, -10)], chest=[(X, -14)], head=[(X, -36)], clav_r=[(Z, 16)], clav_l=[(Z, -16)],
            upper_r=[(X, -40), (Z, 60)], fore_r=[(X, -30)], upper_l=[(X, -40), (Z, -60)], fore_l=[(X, -30)])
    K.key_clip(arm, "howl", [(0.0, rest), (0.4, P(spine=[(X, 12)], chest=[(X, 12)])), (0.9, cry), (1.6, m(cry, head=[(X, -40)])), (2.0, rest)], 2.0, chains=chains)
    kneel = P(petals(-40), spine=[(X, 26)], chest=[(X, 20)], head=[(X, 34)], thigh_r=[(X, -80)], shin_r=[(X, 110)], thigh_l=[(X, -50)], shin_l=[(X, 100)],
              upper_r=[(X, -30)], upper_l=[(X, -30)])
    down = m(kneel, petals(-50), spine=[(X, 50)], chest=[(X, 30)], head=[(X, 46)], upper_r=[(X, -70), (Z, 20)], upper_l=[(X, -70), (Z, -20)])
    K.key_clip(arm, "death", [(0.0, rest), (0.5, slump), (1.3, kneel), (2.2, down), (3.0, down)], 3.0, chains=chains,
               root_keys=[(0.0, (0, 0, 0)), (1.3, (0, -0.28, 0)), (2.2, (0, -0.36, -0.2)), (3.0, (0, -0.38, -0.22))])
    # Edict of Silence (2.2 s): it plants its feet and the horn tips at you and opens wide; the voice goes at 2.2
    brace = P(petals(20), spine=[(X, 8)], chest=[(X, 10)], head=[(X, 22)], upper_r=[(X, 20), (Z, 24)], fore_r=[(X, -40)],
              upper_l=[(X, 20), (Z, -24)], fore_l=[(X, -40)], thigh_r=[(X, -14), (Z, 8)], shin_r=[(X, 16)], thigh_l=[(X, 10), (Z, -8)])
    wide = m(brace, petals(52), head=[(X, 30)], chest=[(X, 12)])
    blast = m(wide, petals(56), spine=[(X, -6)], chest=[(X, -8)], head=[(X, 18)])
    K.key_clip(arm, "edict", [(0.0, rest), (0.6, brace), (1.6, wide), (2.1, m(wide, petals(55), head=[(X, 32)])), (2.25, blast), (2.6, m(blast, petals(40))),
                              (3.2, rest)], 3.2, chains=chains, root_keys=[(0.0, (0, 0, 0)), (2.1, (0, 0, 0)), (2.25, (0, 0, 0.06)), (3.2, (0, 0, 0))])
    # Echo (the ring breaks at 1.0): it shudders, the petals rattling
    def shiver(k):
        return P(petals(-10 + 14 * k), chest=[(X, 4 + 3 * k), (Z, 3 * k)], head=[(X, 6 - 4 * k), (Z, -5 * k)], upper_r=[(X, -6), (Z, 10 + 4 * k)],
                 upper_l=[(X, -6), (Z, -10 + 4 * k)])
    K.key_clip(arm, "echo", [(0.0, rest), (0.3, shiver(1)), (0.45, shiver(-1)), (0.6, shiver(1)), (0.75, shiver(-1)), (0.9, shiver(1)), (1.0, P(petals(30), chest=[(X, -8)], head=[(X, -14)])),
                             (1.6, rest)], 1.6, chains=chains)
    # Falling Crown (the stones go at 1.2): it hunches and the horn jerks side to side, shedding
    hunch = P(petals(-34), spine=[(X, 16)], chest=[(X, 14)], head=[(X, 20)], upper_r=[(X, -30), (Z, 20)], upper_l=[(X, -30), (Z, -20)])
    K.key_clip(arm, "falling_crown", [(0.0, rest), (0.8, hunch), (1.05, m(hunch, head=[(X, 10), (Z, 18)])), (1.2, m(hunch, head=[(X, 24), (Z, -22)])),
                                      (1.35, m(hunch, head=[(X, 14), (Z, 14)])), (1.5, m(hunch, head=[(X, 18), (Z, -8)])), (2.1, rest)], 2.1, chains=chains,
               root_keys=[(0.0, (0, 0, 0)), (1.2, (0, -0.04, 0)), (2.1, (0, 0, 0))])
    # Toll of the Crown (2.4 s cast, lanes round the floor until ~4.4 s): the horn bowed, the trunk turning like a clock hand
    def turn(a):
        return P(petals(-6), pelvis=[(Y, a * 0.3)], spine=[(X, 12), (Y, a * 0.35)], chest=[(X, 10), (Y, a * 0.35)], head=[(X, 30)],
                 upper_r=[(X, -20), (Z, 30)], upper_l=[(X, -20), (Z, -30)])
    K.key_clip(arm, "toll", [(0.0, rest), (0.8, turn(0)), (1.6, turn(-50)), (2.4, turn(-25)), (3.0, turn(10)), (3.6, turn(40)), (4.2, turn(55)), (5.0, rest)],
               5.0, chains=chains)
    # Verdict (rings at 1.4, 2.3 and 3.2 s): three blasts from the open horn, the body jolting at each
    def open_(k):
        return P(petals(46), spine=[(X, -4)], chest=[(X, -6)], head=[(X, -20 - 4 * k)], upper_r=[(X, 10), (Z, 30)], upper_l=[(X, 10), (Z, -30)],
                 thigh_r=[(Z, 8)], thigh_l=[(Z, -8)])
    def jolt(k):
        return m(open_(k), petals(58), chest=[(X, -14)], head=[(X, -30 - 4 * k)])
    K.key_clip(arm, "verdict", [(0.0, rest), (1.0, open_(0)), (1.4, jolt(0)), (1.9, open_(1)), (2.3, jolt(1)), (2.8, open_(2)), (3.2, jolt(2)), (3.9, rest)],
               3.9, chains=chains, root_keys=[(0.0, (0, 0, 0)), (1.4, (0, 0.03, 0.03)), (1.9, (0, 0, 0)), (2.3, (0, 0.03, 0.03)), (2.8, (0, 0, 0)),
                                              (3.2, (0, 0.04, 0.04)), (3.9, (0, 0, 0))])
    # Call the Choir (1.6 s): the fists raised to the sides, the horn lifted to the sky and opening
    call = P(petals(36), spine=[(X, -8)], chest=[(X, -12)], head=[(X, -34)], upper_r=[(X, -60), (Z, 70)], fore_r=[(X, -40)],
             upper_l=[(X, -60), (Z, -70)], fore_l=[(X, -40)])
    K.key_clip(arm, "choir", [(0.0, rest), (0.7, call), (1.6, m(call, petals(44), head=[(X, -38)])), (2.3, rest)], 2.3, chains=chains)


def main():
    K.clear_scene()
    g = build_body()
    ob = K.make_object(g, "SpeakingCrown", subdiv=0)
    arm = K.build_armature(BONES, "CrownRig")
    K.bind(ob, arm)
    print("VB TRIS", sum(len(p.vertices) - 2 for p in ob.data.polygons))
    if DO_AO:
        K.bake_ao_alpha(ob)
    clips(arm)
    K.export_glb(arm, ob, OUT)
    if RENDERS:
        K.review_renders(arm, ob, RENDERS, "crown", 2.1, poses=[("windup_hold", 0.0, 40.0), ("strike", 0.18, 60.0), ("edict", 2.1, 20.0),
                                                                ("echo", 0.6, 30.0), ("falling_crown", 1.2, 30.0), ("toll", 1.6, 30.0),
                                                                ("verdict", 3.2, 20.0), ("choir", 1.6, 10.0), ("death", 3.0, 60.0)])
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(K.ROOT, "art/blender/vb_speaking_crown.blend"))


main()
