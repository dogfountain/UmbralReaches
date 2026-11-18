"""The Bone Abbot, modelled in Blender in the villagers' style (18 Nov). Run:
    blender -b -P tools/blender/vb_bone_abbot.py -- [--out art/models/bosses/vb_bone_abbot.glb] [--renders <dir>] [--no-ao]

The design is the one in core/enemy/abbot_body.gd, built properly: tall and hunched, a huge hood whose peak rises up
and back like a horn with a crown of bone tines round the brim and nothing inside but dark and two ember eyes; a
broad wine mantle, gilt-hemmed and ragged, with candles burning on it; the robe torn open on the breast over a
ribcage with the reliquary burning inside for a heart; long sleeves and skeletal claws, the right round a crozier of
stacked vertebrae with a spiral crook and a flame hung in it, the left open; a robe flaring to the floor in deep
pleats and tatters; a cord with tally bones and a rosary of small skulls.

Rig space: x right, y up, z back, facing -Z, metres (built at a person's scale; the game scales him up).
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


OUT = os.path.join(K.ROOT, arg("--out", "art/models/bosses/vb_bone_abbot.glb"))
RENDERS = arg("--renders")
DO_AO = "--no-ao" not in ARGS

# --- palette (sRGB tints; the villagers' shader adds the weave, the wear and the light) --------------------
ROBE = np.array([0.17, 0.13, 0.115])        # ash-black wool gone brown with age (under the crypt key light 0.2 read lavender-grey)
ROBE_LIT = np.array([0.26, 0.2, 0.17])
STAIN = np.array([0.17, 0.13, 0.1])
MANTLE = np.array([0.38, 0.08, 0.09])       # old wine
MANTLE_DK = np.array([0.24, 0.05, 0.06])
GILT = (0.74, 0.55, 0.24)
BONE = (0.8, 0.74, 0.6)
BONE_DK = (0.62, 0.56, 0.44)
HOLLOW = (0.03, 0.022, 0.022)
WAX = (0.88, 0.84, 0.72)
CORD = (0.46, 0.38, 0.26)
EMBER = (1.0, 0.52, 0.16)
FLAME = (1.0, 0.72, 0.3)

# --- the skeleton (rig space) -----------------------------------------------------------------------------
P = 0.9               # pelvis
HEAD = V(0, 1.53, -0.15)
SKIRT_N = 8
SKIRT_Y = [0.88, 0.6, 0.32, 0.03]
SKIRT_R = [0.21, 0.28, 0.36, 0.44]
MANTLE_N = 6


def skirt_pt(i, lvl):
    a = TAU * i / SKIRT_N
    return V(math.sin(a) * SKIRT_R[lvl], SKIRT_Y[lvl], -math.cos(a) * SKIRT_R[lvl] * 0.92 + 0.02)


def mantle_pt(i, lvl):
    # six links round the sides and back (the front is open)
    a = math.radians(-150.0 + 300.0 * i / (MANTLE_N - 1))
    r = [0.2, 0.36][lvl]
    y = [1.36, 1.12][lvl] - (0.06 if abs(a) > 2.2 else 0.0) * lvl
    return V(math.sin(a) * r, y, -math.cos(a) * r * 0.8 + 0.02)


BONES = {
    "root": (V(0, 0, 0), V(0, 0.12, 0), None, False),
    "pelvis": (V(0, P, 0.0), V(0, 1.02, 0.0), "root", True),
    "spine": (V(0, 1.02, 0.0), V(0, 1.2, -0.03), "pelvis", True),
    "chest": (V(0, 1.2, -0.03), V(0, 1.38, -0.08), "spine", True),
    "neck": (V(0, 1.38, -0.08), V(0, 1.47, -0.13), "chest", True),
    "head": (V(0, 1.47, -0.13), V(0, 1.66, -0.16), "neck", True),
    "horn": (V(0, 1.68, 0.02), V(0, 1.86, 0.17), "head", True),
    "crozier": (V(0.27, 0.66, -0.06), V(0.27, 1.6, -0.06), "hand_r", True),
    "cord_0": (V(-0.12, 0.86, -0.15), V(-0.13, 0.66, -0.17), "pelvis", True),
    "cord_1": (V(-0.13, 0.66, -0.17), V(-0.13, 0.46, -0.18), "cord_0", True),
}
for s, tag in ((-1.0, "l"), (1.0, "r")):
    BONES.update({
        "clav_" + tag: (V(s * 0.04, 1.36, -0.05), V(s * 0.2, 1.36, -0.01), "chest", True),
        "upper_" + tag: (V(s * 0.2, 1.36, -0.01), V(s * 0.25, 1.03, 0.0), "clav_" + tag, True),
        "fore_" + tag: (V(s * 0.25, 1.03, 0.0), V(s * 0.27, 0.7, -0.03), "upper_" + tag, True),
        "hand_" + tag: (V(s * 0.27, 0.7, -0.03), V(s * 0.28, 0.6, -0.06), "fore_" + tag, True),
        "fingers_" + tag: (V(s * 0.28, 0.6, -0.06), V(s * 0.285, 0.46, -0.09), "hand_" + tag, True),
        "thigh_" + tag: (V(s * 0.1, 0.86, 0.0), V(s * 0.11, 0.47, -0.01), "pelvis", True),
        "shin_" + tag: (V(s * 0.11, 0.47, -0.01), V(s * 0.11, 0.08, 0.01), "thigh_" + tag, True),
        "foot_" + tag: (V(s * 0.11, 0.08, 0.01), V(s * 0.11, 0.03, -0.13), "shin_" + tag, True),
    })
for i in range(SKIRT_N):
    for lvl in range(3):
        BONES["skirt_%d_%d" % (i, lvl)] = (skirt_pt(i, lvl), skirt_pt(i, lvl + 1), "pelvis" if lvl == 0 else "skirt_%d_%d" % (i, lvl - 1), True)
for i in range(MANTLE_N):
    BONES["mantle_%d" % i] = (mantle_pt(i, 0), mantle_pt(i, 1), "chest", True)


# --- weights -----------------------------------------------------------------------------------------------

def w_spine(p):
    """Torso: pelvis, spine, chest, neck blended by height."""
    y = p[1]
    pts = [("pelvis", 0.92), ("spine", 1.1), ("chest", 1.3), ("neck", 1.45)]
    out = {}
    for k in range(len(pts) - 1):
        (b0, y0), (b1, y1) = pts[k], pts[k + 1]
        if y0 <= y <= y1:
            t = (y - y0) / (y1 - y0)
            out[b0] = 1.0 - t
            out[b1] = t
            return out
    return {"pelvis": 1.0} if y < 0.92 else {"neck": 1.0}


def w_skirt(p):
    """The robe below the waist: the two nearest skirt chains round, the two nearest links down, and the leg on that
    side for the lower front so the robe walks with the stride."""
    a = math.atan2(p[0], -(p[2] - 0.02))
    if a < 0:
        a += TAU
    f = a / (TAU / SKIRT_N)
    i0 = int(math.floor(f)) % SKIRT_N
    i1 = (i0 + 1) % SKIRT_N
    t = f - math.floor(f)
    y = p[1]
    out = {}
    if y > SKIRT_Y[0] - 0.02:
        return {"pelvis": 1.0}
    for lvl in range(3):
        y0, y1 = SKIRT_Y[lvl], SKIRT_Y[lvl + 1]
        if y1 <= y <= y0 or (lvl == 2 and y < y1):
            u = min(1.0, max(0.0, (y0 - y) / (y0 - y1)))
            # the bone that moves a vertex at this height is the link above it (u near 0) to the one below
            b_lo = "skirt_%d_%d"
            wl = [(lvl, 1.0 - 0.5 * u), (min(lvl + 1, 2), 0.5 * u)] if lvl < 2 else [(2, 1.0)]
            for lv, ww in wl:
                out[b_lo % (i0, lv)] = out.get(b_lo % (i0, lv), 0.0) + ww * (1.0 - t)
                out[b_lo % (i1, lv)] = out.get(b_lo % (i1, lv), 0.0) + ww * t
            break
    # the legs under the front and sides
    side = "r" if p[0] > 0 else "l"
    front = max(0.0, -(p[2] - 0.02)) / 0.45
    leg = 0.35 * smooth(0.0, 0.5, front) * smooth(0.0, 0.15, abs(p[0]))
    if leg > 0.01:
        scale = 1.0 - leg
        out = {k: v * scale for k, v in out.items()}
        out["thigh_" + side if y > 0.47 else "shin_" + side] = leg
    return out


def w_arm(tag):
    def f(p):
        y = p[1]
        if y > 1.03:
            t = smooth(1.36, 1.1, y)
            return {"clav_" + tag: 1.0 - t, "upper_" + tag: t} if y > 1.2 else {"upper_" + tag: 1.0}
        t = smooth(1.08, 0.98, y)
        return {"upper_" + tag: 1.0 - t, "fore_" + tag: t} if y > 0.95 else {"fore_" + tag: 1.0}
    return f


def w_mantle(p):
    """The mantle: chest near the neck, the nearest mantle links toward the edge."""
    a = math.atan2(p[0], -(p[2] - 0.02))
    best = sorted(range(MANTLE_N), key=lambda i: abs(math.atan2(math.sin(a - math.radians(-150 + 300 * i / (MANTLE_N - 1))), math.cos(a - math.radians(-150 + 300 * i / (MANTLE_N - 1))))))[:2]
    r = math.hypot(p[0], p[2] - 0.02)
    edge = smooth(0.18, 0.34, r)
    out = {"chest": 1.0 - edge}
    for k, i in enumerate(best):
        out["mantle_%d" % i] = out.get("mantle_%d" % i, 0.0) + edge * (0.65 if k == 0 else 0.35)
    return out


def w_hood(p):
    """The hood follows the head; the horn follows the horn; its foot on the shoulders follows the neck and chest."""
    if p[1] < 1.44:
        t = smooth(1.34, 1.44, p[1])
        return {"chest": 1.0 - t, "neck": t}
    up = smooth(1.8, 1.9, p[1]) * smooth(-0.05, 0.05, p[2])
    return {"head": 1.0 - up, "horn": up} if up > 0.01 else {"head": 1.0}


def robe(g):
    rng = np.random.default_rng(3)
    ph = rng.uniform(0, TAU, 4)

    def fold(th, y, r):
        depth = 0.006 + 0.05 * smooth(0.9, 0.05, y)
        return depth * (0.62 * math.sin(9 * th + ph[0]) + 0.28 * math.sin(17 * th + ph[1] + y * 3.0) + 0.1 * math.sin(31 * th + ph[2]))

    def col(th, y, dr):
        ridge = (dr / 0.05) * 0.5 + 0.5
        c = ROBE * (1.0 - ridge) + ROBE_LIT * ridge * 0.9 + ROBE * ridge * 0.1
        dirt = smooth(0.25, 0.02, y)
        return tuple(c * (1.0 - 0.55 * dirt) + STAIN * 0.55 * dirt)

    def hem(th):
        return 0.03 * abs(math.sin(13 * th + 0.4)) + 0.02 * abs(math.sin(5 * th + 1.1))

    prof = []
    for k in range(24):
        u = k / 23.0
        y = 0.92 - u * 0.89
        prof.append((y, 0.21 + 0.23 * (u ** 1.3)))
    prof.reverse()
    K.lathe(g, prof, 96, col, "cloth", w_skirt, centre=V(0, 0, 0.02), fold=fold, zscale=0.92, hem=hem)
    # tatters below the hem: flat tongues of different lengths
    for i in range(22):
        a = TAU * i / 22 + 0.12 * math.sin(i * 3.1)
        d = V(math.sin(a), 0, -math.cos(a) * 0.92)
        top = V(0, 0.07, 0.02) + d * 0.455
        ln = 0.06 + 0.06 * abs(math.sin(i * 2.3))
        wd = 0.05 + 0.025 * abs(math.sin(i * 1.7))
        K.tube(g, [top, top + d * 0.01 + V(0, -ln * 0.5, 0), top + d * 0.018 + V(0, -ln, 0)], [wd, wd * 0.85, wd * 0.35], 6,
               tuple(STAIN * 0.9), "cloth", w_skirt, squash=(1.0, 0.14), ref=d)


def torso(g):
    """The bodice: hips to the neck, hunched (the middle of each ring moves forward with height)."""
    rows = []
    for k in range(12):
        u = k / 11.0
        y = 0.88 + u * 0.52
        z = 0.02 - 0.12 * (u ** 1.6)
        rx = 0.2 + 0.03 * math.sin(u * math.pi) - 0.08 * smooth(0.7, 1.0, u)
        rz = 0.15 + 0.03 * math.sin(u * math.pi) - 0.06 * smooth(0.7, 1.0, u)
        rows.append((V(0, y, z), rx, rz))

    def col(th, j, dr, p):
        return tuple(ROBE * (0.95 + 0.1 * math.sin(7 * th)))

    def fold(th, j, n):
        return 0.008 * math.sin(7 * th + j * 0.4)

    K.loft(g, rows, 40, col, "cloth", w_spine, fold=fold)


def chest_wound(g):
    """The robe torn open on the breast: the hollow, the ribs, the sternum, the reliquary and its flame. Drawn about
    the breastbone, then set forward onto the bodice's front (it sat inside the cloth, hidden)."""
    n0 = len(g.v)
    K.blob(g, V(0, 1.16, -0.15), [0.14, 0.18, 0.03], HOLLOW, "cloth", "chest", rings=8, segs=16, lumps=0.06, seed=5)
    for s in (-1.0, 1.0):
        K.tube(g, [V(s * 0.03, 1.34, -0.15), V(s * 0.12, 1.25, -0.165), V(s * 0.135, 1.1, -0.16), V(s * 0.06, 0.98, -0.15)],
               [0.018, 0.024, 0.022, 0.014], 8, tuple(ROBE_LIT), "cloth", "chest", squash=(1.0, 0.5))
    # the breastbone snapped round the reliquary: a stub above, a stub below
    K.tube(g, [V(0, 1.31, -0.165), V(0, 1.25, -0.178), V(0, 1.215, -0.172)], [0.014, 0.017, 0.01], 8, BONE, "linen", "chest")
    K.tube(g, [V(0, 1.085, -0.172), V(0, 1.06, -0.176), V(0, 1.03, -0.168)], [0.009, 0.014, 0.01], 8, BONE, "linen", "chest")
    for j in range(5):
        y = 1.29 - 0.055 * j
        for s in (-1.0, 1.0):
            pts = []
            for t in (0.0, 0.3, 0.6, 0.85, 1.0):
                a = t * 1.35
                pts.append(V(s * (0.015 + math.sin(a) * 0.125), y - t * 0.05 - 0.02 * t * t, -(0.175 - (1.0 - math.cos(a)) * 0.085)))
            K.tube(g, pts, [0.01, 0.011, 0.01, 0.008, 0.006], 6, BONE if j % 2 == 0 else BONE_DK, "linen", "chest")
    rq = V(0, 1.15, -0.175)
    for dy in (0.05, -0.05):
        K.tube(g, [rq + V(math.sin(a) * 0.035, dy, -math.cos(a) * 0.035) for a in np.linspace(0, TAU, 13)], [0.006] * 13, 5, GILT, "metal", "chest", caps=False)
    for i in range(4):
        a = TAU * i / 4 + 0.4
        o = V(math.cos(a), 0, math.sin(a)) * 0.035
        K.tube(g, [rq + o + V(0, 0.05, 0), rq + o * 1.25, rq + o - V(0, 0.05, 0)], [0.005, 0.005, 0.005], 4, GILT, "metal", "chest")
    K.blob(g, rq, [0.028, 0.044, 0.028], EMBER, "eye", "chest", rings=6, segs=10, glow=True)
    for i in range(n0, len(g.v)):
        g.v[i] = g.v[i] + V(0, 0, -0.058)


def mantle(g):
    """A broad stiff mantle over the shoulders down to the elbows, open at the throat, ragged at the edge, gilt-hemmed,
    with candles burning on it."""
    rows = []
    for k in range(10):
        u = k / 9.0
        y = 1.45 - 0.4 * u
        rows.append((V(0, y, -0.02 + 0.03 * u), 0.15 + 0.38 * (u ** 0.75), 0.13 + 0.27 * (u ** 0.75)))
    rows.reverse()
    a0, a1 = math.radians(24.0), math.radians(336.0)

    def hem(th):
        return 0.03 * abs(math.sin(11 * th + 0.3)) + 0.02 * abs(math.sin(4 * th)) - 0.08 * smooth(-0.2, -0.9, math.cos(th))

    def col(th, j, dr, p):
        t = j / 9.0
        ridge = 0.5 + 0.5 * math.sin(9 * th)
        c = MANTLE_DK * (1.0 - t) + MANTLE * t
        return tuple(c * (0.85 + 0.3 * ridge * (1.0 - t)))

    def fold(th, j, n):
        return 0.02 * (1.0 - j / 9.0) * math.sin(9 * th)

    def wm(p):
        out = w_mantle(p)
        side = "clav_r" if p[0] > 0 else "clav_l"
        k = 0.45 * smooth(0.2, 0.42, abs(p[0]))
        if k > 0.01:
            out = {b: w * (1.0 - k) for b, w in out.items()}
            out[side] = k
        return out

    K.loft(g, rows, 56, col, "fur", wm, a0=a0, a1=a1, fold=fold, hem=hem)
    inner = [(V(c[0], c[1] - 0.015, c[2]), rx - 0.016, rz - 0.016) for c, rx, rz in rows]
    K.loft(g, inner, 56, tuple(MANTLE_DK * 0.6), "fur", wm, a0=a1, a1=a0, fold=fold, hem=hem)     # the same span run backwards: faces in
    c0, rx0, rz0 = rows[0]
    pts = [c0 + V(math.sin(th) * (rx0 + 0.006), hem(th) - 0.006, -math.cos(th) * (rz0 + 0.006)) for th in np.linspace(a0, a1, 57)]
    K.tube(g, pts, [0.014] * len(pts), 6, GILT, "metal", wm, caps=False)
    # the open edges at the throat, gilt too
    for th in (a0, a1):
        edge = [c + V(math.sin(th) * (rx + 0.004), 0, -math.cos(th) * (rz + 0.004)) for c, rx, rz in rows]
        K.tube(g, edge, [0.012] * len(edge), 6, GILT, "metal", wm, caps=False)
    # candles on the shoulders: wax stubs with drips and their flames
    for s in (-1.0, 1.0):
        for x, z, h in ((0.28, 0.04, 0.12), (0.34, 0.1, 0.08), (0.24, 0.13, 0.07), (0.31, -0.04, 0.06), (0.38, 0.0, 0.05)):
            u = min(1.0, max(0.0, ((x - 0.15) / 0.38))) ** (1.0 / 0.75)
            top = 1.45 - 0.4 * u + 0.004
            b = V(s * x, top, z)
            K.blob(g, b, [0.036, 0.013, 0.034], tuple(np.array(WAX) * 0.9), "linen", "chest", rings=4, segs=10, lumps=0.25, seed=int(x * 100))
            K.tube(g, [b, b + V(0, h, 0)], [0.018, 0.016], 9, WAX, "linen", "chest")
            K.tube(g, [b + V(0.015, h * 0.92, 0), b + V(0.018, h * 0.4, 0.003)], [0.006, 0.004], 4, WAX, "linen", "chest")
            K.blob(g, b + V(0, h + 0.03, 0), [0.012, 0.028, 0.012], FLAME, "eye", "chest", rings=5, segs=8, glow=True)


def hood(g):
    """One deep cowl: it drapes off the shoulders, rises over a head of nothing and sweeps up and back into a horn. The
    face is an opening cut in its front with only dark behind it and two ember eyes; a rolled rim round the opening;
    a crown of bone tines, uneven and curving back, stands round it."""
    rows = [
        (V(0, 1.34, -0.03), 0.23, 0.21), (V(0, 1.41, -0.07), 0.2, 0.2), (V(0, 1.48, -0.11), 0.18, 0.2),
        (V(0, 1.55, -0.13), 0.17, 0.2), (V(0, 1.62, -0.13), 0.16, 0.19), (V(0, 1.69, -0.11), 0.135, 0.16),
        (V(0, 1.76, -0.07), 0.105, 0.12), (V(0, 1.83, -0.01), 0.08, 0.085), (V(0, 1.89, 0.07), 0.06, 0.06),
        (V(0, 1.93, 0.15), 0.042, 0.042), (V(0, 1.95, 0.23), 0.025, 0.025), (V(0, 1.95, 0.3), 0.008, 0.008),
    ]
    OPEN_ANG = math.radians(48.0)
    OPEN_J = (2.0, 5.0)

    def opening(th, j):
        a = abs(math.atan2(math.sin(th), math.cos(th)))
        # an arch: wide at the cheeks, narrowing to a point at the brow
        lim = OPEN_ANG * (1.0 - 0.55 * smooth(3.6, 5.0, j))
        return a < lim and OPEN_J[0] < j < OPEN_J[1]

    def fold(th, j, n):
        return 0.008 * math.sin(6 * th + j) + 0.012 * smooth(1.5, 0.0, j) * math.sin(9 * th)

    def col(th, j, dr, p):
        a = abs(math.atan2(math.sin(th), math.cos(th)))
        near = smooth(OPEN_ANG + 0.5, OPEN_ANG, a) * smooth(1.2, 2.2, j) * smooth(5.8, 4.8, j)
        shade = 0.82 + 0.12 * math.sin(5 * th + j * 0.7)
        return tuple(ROBE * shade * (1.0 - near) + ROBE_LIT * near)

    K.loft(g, rows, 48, col, "cloth", w_hood, fold=fold, cap_top=True, skip=opening)
    # the inside: lined in near-black (seen through the opening), a head of nothing, the eyes
    K.blob(g, V(0, 1.585, -0.15), [0.15, 0.14, 0.12], HOLLOW, "cloth", w_hood, rings=8, segs=14, seed=9)
    for s in (-1.0, 1.0):
        K.blob(g, V(s * 0.055, 1.6, -0.27), [0.024, 0.015, 0.01], EMBER, "eye", w_hood, rings=8, segs=18, glow=True)
    # the rolled rim round the opening (an arch through the opening's edge points)
    edge = []
    for k in range(25):
        u = k / 24.0
        jj = OPEN_J[0] + 0.15 + (OPEN_J[1] - 0.15 - OPEN_J[0] - 0.15) * math.sin(u * math.pi)
        side = -1.0 if u < 0.5 else 1.0
        lim = OPEN_ANG * (1.0 - 0.55 * smooth(3.6, 5.0, jj))
        th = side * lim
        j0 = int(math.floor(jj))
        t = jj - j0
        (c0, rx0, rz0), (c1, rx1, rz1) = rows[j0], rows[min(j0 + 1, len(rows) - 1)]
        cc = c0 * (1 - t) + c1 * t
        rx, rz = rx0 * (1 - t) + rx1 * t, rz0 * (1 - t) + rz1 * t
        edge.append(cc + V(math.sin(th) * rx, 0, -math.cos(th) * rz))
    K.tube(g, edge, [0.02] * len(edge), 8, tuple(ROBE_LIT * 0.95), "cloth", w_hood)
    # the crown of tines round the opening: uneven, curving up and back
    rng = np.random.default_rng(13)
    for i in range(9):
        u = (i + 0.5) / 9.0
        p0 = edge[int(round(u * 24))]
        side = (p0[0]) / 0.17
        up = V(side * 0.7, 1.0, 0.25)
        up /= np.linalg.norm(up)
        ln = (0.09 + 0.1 * (1.0 - abs(side))) * rng.uniform(0.7, 1.15)
        back = V(0, 0.0, 1.0)
        pts = [p0 + V(0, 0, 0.01), p0 + up * ln * 0.5, p0 + up * ln * 0.85 + back * ln * 0.25, p0 + up * ln + back * ln * 0.45]
        K.tube(g, pts, [0.02, 0.015, 0.009, 0.002], 7, BONE if i % 2 else BONE_DK, "linen", w_hood)

def sleeve(g, s, tag):
    """A long bell sleeve: narrow at the shoulder, wide at the cuff, tattered."""
    path = [V(s * 0.19, 1.37, -0.01), V(s * 0.23, 1.2, 0.0), V(s * 0.25, 1.03, 0.0), V(s * 0.265, 0.86, -0.015), V(s * 0.275, 0.72, -0.03)]
    K.tube(g, path, [0.085, 0.09, 0.1, 0.13, 0.16], 18, tuple(ROBE * 0.95), "cloth", w_arm(tag), caps=False)
    K.tube(g, path, [0.075, 0.08, 0.09, 0.12, 0.15], 18, HOLLOW, "cloth", w_arm(tag), caps=False)
    cuff = path[-1]
    for i in range(12):
        a = TAU * i / 12
        d = V(math.cos(a), 0, math.sin(a))
        top = cuff + d * 0.155
        ln = 0.03 + 0.04 * abs(math.sin(i * 1.9))
        K.tube(g, [top, top + V(0, -ln, 0)], [0.03, 0.008], 5, tuple(STAIN), "cloth", "fore_" + tag, squash=(1.0, 0.25), ref=d)
    K.tube(g, [cuff + V(math.cos(a) * 0.162, 0.03, math.sin(a) * 0.162) for a in np.linspace(0, TAU, 19)], [0.008] * 19, 5, GILT, "metal", "fore_" + tag, caps=False)


def claw(g, s, tag, closed):
    """A skeletal hand: a narrow palm of bone, four long jointed fingers and a thumb; closed round the crozier or open."""
    wr = V(s * 0.272, 0.69, -0.035)
    K.blob(g, wr + V(0, -0.05, -0.01), [0.05, 0.065, 0.03], BONE_DK, "linen", "hand_" + tag, rings=6, segs=10, lumps=0.05, seed=11)
    for f in range(4):
        x = s * (0.272 + (f - 1.5) * 0.024)
        base = V(x, 0.6, -0.04)
        if closed:
            pts = [base, base + V(0, -0.04, -0.035), base + V(-s * 0.006, -0.04, -0.085), base + V(-s * 0.012, 0.0, -0.1)]
        else:
            spread = (f - 1.5) * 0.03
            pts = [base, base + V(spread, -0.08, -0.025), base + V(spread * 2, -0.16, -0.04), base + V(spread * 2.6, -0.22, -0.02)]
        K.tube(g, pts, [0.013, 0.012, 0.01, 0.004], 7, BONE, "linen", "fingers_" + tag)
        for k in (1, 2):
            K.blob(g, pts[k], [0.016, 0.016, 0.016], BONE_DK, "linen", "fingers_" + tag, rings=4, segs=8)
    th = wr + V(-s * 0.02, -0.07, -0.03)
    K.tube(g, [th, th + V(-s * 0.03, -0.04, -0.03), th + V(-s * 0.03, -0.07, -0.05)], [0.01, 0.008, 0.004], 6, BONE, "linen", "hand_" + tag)


def crozier(g):
    """A crozier of stacked vertebrae, a spiral crook at the top with a flame hung in it, a rag tied below."""
    x, z = 0.27, -0.06
    y = 0.03
    k = 0
    while y < 1.66:
        c = V(x, y, z)
        sc = 1.0 - 0.25 * (y / 1.66)
        K.blob(g, c, [0.04 * sc, 0.026, 0.04 * sc], BONE if k % 2 == 0 else BONE_DK, "linen", "crozier", rings=5, segs=12, lumps=0.08, seed=k)
        K.tube(g, [c + V(0, 0, 0.03 * sc), c + V(0, -0.012, 0.07 * sc)], [0.012 * sc, 0.003], 5, BONE_DK, "linen", "crozier")
        for sx in (-1.0, 1.0):
            K.tube(g, [c + V(sx * 0.032 * sc, 0, 0.005), c + V(sx * 0.062 * sc, -0.012, 0.012)], [0.009 * sc, 0.003], 5, BONE_DK, "linen", "crozier")
        y += 0.046
        k += 1
    # the crook: a spiral out and down
    cp = []
    for i in range(18):
        u = i / 17.0
        a = u * 1.6 * math.pi
        r = 0.12 * (1.0 - 0.45 * u)
        cp.append(V(x + math.sin(a) * r - 0.0, 1.66 + (1.0 - math.cos(a)) * 0.0 + math.sin(a) * 0.0 + r * (1.0 - math.cos(a)) * 0.0 + 0.12 * math.sin(a * 0.5) + 0.04, z - (1.0 - math.cos(a)) * r * 0.2))
    cp = [V(x - 0.19 * math.sin(u * 1.65 * math.pi) * (1.0 - 0.35 * u), 1.68 + 0.2 * math.sin(u * 0.95 * math.pi), z) for u in np.linspace(0, 1, 34)]
    K.tube(g, cp, [0.036 * (1.0 - 0.6 * u) for u in np.linspace(0, 1, 34)], 18, BONE, "linen", "crozier")
    hang = cp[-1]
    K.tube(g, [hang, hang + V(0, -0.08, 0)], [0.003, 0.003], 4, (0.3, 0.28, 0.25), "metal", "crozier")
    lc = hang + V(0, -0.14, 0)
    for i in range(5):
        a = TAU * i / 5
        o = V(math.cos(a), 0, math.sin(a)) * 0.048
        K.tube(g, [lc + o + V(0, 0.06, 0), lc + o * 1.25, lc + o + V(0, -0.06, 0)], [0.006] * 3, 5, GILT, "metal", "crozier")
    for dy in (0.06, -0.06):
        K.tube(g, [lc + V(math.cos(a) * 0.05, dy, math.sin(a) * 0.05) for a in np.linspace(0, TAU, 13)], [0.007] * 13, 5, GILT, "metal", "crozier", caps=False)
    K.blob(g, lc, [0.03, 0.05, 0.03], FLAME, "eye", "crozier", rings=6, segs=10, glow=True)
    # a rag tied under the crook
    rg = V(x, 1.58, z)
    K.tube(g, [rg, rg + V(-0.03, -0.12, -0.01), rg + V(-0.02, -0.24, 0.0)], [0.025, 0.02, 0.008], 6, tuple(np.array(BONE) * 0.75), "linen", "crozier", squash=(1.0, 0.25))


def cord(g):
    """A rope belt, a hanging cord with tally bones, and a rosary of small skulls."""
    pts = [V(math.sin(a) * 0.215, 0.88 - 0.015 * math.cos(a), -math.cos(a) * 0.2 + 0.02) for a in np.linspace(0, TAU, 33)]
    K.tube(g, pts, [0.016] * len(pts), 6, CORD, "leather", "pelvis", caps=False)
    hang = [V(-0.12, 0.87, -0.16), V(-0.13, 0.66, -0.18), V(-0.13, 0.46, -0.19)]
    K.tube(g, hang, [0.012, 0.011, 0.009], 6, CORD, "leather", lambda p: {"cord_0": 1.0} if p[1] > 0.66 else {"cord_0": 0.4, "cord_1": 0.6})
    for k, y in enumerate((0.78, 0.7, 0.62, 0.54)):
        c = V(-0.13, y, -0.19)
        K.tube(g, [c + V(-0.03, 0, 0), c + V(0.03, 0.005, 0)], [0.007, 0.006], 5, BONE if k % 2 else BONE_DK, "linen", "cord_0" if y > 0.66 else "cord_1")
    for k in range(5):
        a = math.radians(-70 - k * 16)
        c = V(math.sin(a) * 0.24, 0.82 - 0.02 * k, -math.cos(a) * 0.22 + 0.02)
        K.blob(g, c, [0.034, 0.036, 0.036], BONE, "linen", "pelvis", rings=6, segs=10, seed=20 + k)
        for sx in (-1.0, 1.0):
            K.blob(g, c + V(sx * 0.013, 0.006, -0.03), [0.009, 0.01, 0.006], HOLLOW, "cloth", "pelvis", rings=4, segs=6)


def toes(g):
    for s, tag in ((-1.0, "l"), (1.0, "r")):
        for k in range(3):
            b = V(s * (0.09 + 0.02 * k), 0.02, -0.4 - 0.01 * k)
            K.tube(g, [b, b + V(0, -0.005, -0.05)], [0.012, 0.006], 6, BONE_DK, "linen", "foot_" + tag)


def build_body():
    g = K.Geo()
    robe(g)
    torso(g)
    chest_wound(g)
    mantle(g)
    hood(g)
    for s, tag in ((-1.0, "l"), (1.0, "r")):
        sleeve(g, s, tag)
        claw(g, s, tag, tag == "r")
    crozier(g)
    cord(g)
    toes(g)
    return g


# --- the clips (authored key poses) -----------------------------------------------------------------------
X = V(-1, 0, 0)     # pitch: + leans an upright bone (spine, head, staff) forward and swings a hanging one (arm, leg) back
Y = V(0, 1, 0)      # yaw: + turns the front toward his left
Z = V(0, 0, 1)      # roll (toward +X)


def P_(**kw):
    """A pose: bone=[(axis, deg), ...]."""
    return {b: v for b, v in kw.items()}


REST = P_(spine=[(X, 8)], chest=[(X, 10)], neck=[(X, -6)], head=[(X, -8)],
          upper_r=[(X, -18), (Z, 4)], fore_r=[(X, -30)], hand_r=[(X, 48)], upper_l=[(X, -10), (Z, -6)], fore_l=[(X, -35)], fingers_l=[(X, -10)])


STAFF_CHAIN = ("pelvis", "spine", "chest", "clav_r", "upper_r", "fore_r", "hand_r")


def _q(rots):
    from mathutils import Quaternion, Vector
    q = Quaternion()
    for ax, deg in rots:
        q = Quaternion(Vector(tuple(ax)), math.radians(deg)) @ q
    return q


def aim(pose, *tilt):
    """The pose with the crozier set so the staff points along `tilt` (rig-axis turns from upright) in the world,
    whatever the body and arm do: a bone's world turn is the product of its chain's rig-axis turns, root first."""
    chain = _q([])
    for b in STAFF_CHAIN:
        chain = chain @ _q(pose.get(b, []))
    want = _q(list(tilt))
    ax, ang = (chain.inverted() @ want).to_axis_angle()
    out = dict(pose)
    out["crozier"] = [(V(ax.x, ax.y, ax.z), math.degrees(ang))]
    return out


def m(*poses, **over):
    """Merge poses (later wins per bone)."""
    out = {}
    for p in poses:
        out.update(p)
    out.update(over)
    return out


def clips(arm):
    rest = REST
    breathe_in = m(rest, chest=[(X, 6)], neck=[(X, -8)], head=[(X, -10)])
    shift_r = m(rest, pelvis=[(Z, 3)], spine=[(X, 8), (Z, -3)], head=[(X, -6), (Y, -14)], fingers_l=[(X, -30)])
    shift_l = m(rest, pelvis=[(Z, -3)], spine=[(X, 8), (Z, 3)], head=[(X, -10), (Y, 12)], fingers_l=[(X, 5)])
    chains = [["skirt_%d_%d" % (i, l) for l in range(3)] for i in range(SKIRT_N)] + [["mantle_%d" % i] for i in range(MANTLE_N)] + [["cord_0", "cord_1"], ["horn"]]
    K.key_clip(arm, "idle", [(0.0, rest), (1.1, breathe_in), (2.0, shift_r), (3.1, breathe_in), (4.0, shift_l), (5.2, breathe_in), (6.0, rest)], 6.0,
               loop=True, chains=chains, ripple=0.04)
    # walk: a heavy hunched stride; the crozier planted with the right foot
    def stride(s):
        return m(rest, pelvis=[(Y, 6 * s), (Z, 2 * s)], spine=[(X, 10), (Y, -5 * s)], chest=[(X, 10), (Y, -6 * s)],
                 thigh_r=[(X, -28 * s)], shin_r=[(X, 14 if s < 0 else 34)], thigh_l=[(X, 28 * s)], shin_l=[(X, 14 if s > 0 else 34)],
                 upper_l=[(X, -10 + 16 * s)], fore_l=[(X, -35)], upper_r=[(X, -22 - 10 * s)])
    K.key_clip(arm, "walk", [(0.0, stride(1)), (0.8, stride(-1)), (1.6, stride(1))], 1.6, loop=True, chains=chains, ripple=0.03)
    dip = aim(m(rest, spine=[(X, 16)], chest=[(X, 14)], head=[(X, -14)], upper_r=[(X, -30), (Z, 6)], fore_r=[(X, -30)],
                thigh_r=[(X, -8)], shin_r=[(X, 16)]), (X, 10))
    raise_ = aim(m(rest, spine=[(X, -4), (Y, -16)], chest=[(X, -8), (Y, -12)], neck=[(X, 4), (Y, 8)], head=[(X, -4), (Y, 12)],
                   clav_r=[(Z, 16)], upper_r=[(X, -140), (Z, 14)], fore_r=[(X, -30)],
                   upper_l=[(X, -50), (Z, -30)], fore_l=[(X, -50)], fingers_l=[(X, 15)], thigh_r=[(X, 10)], thigh_l=[(X, -14)], shin_l=[(X, 10)]),
                 (X, -40))
    coil = aim(m(raise_, spine=[(X, -8), (Y, -22)], chest=[(X, -12), (Y, -16)], upper_r=[(X, -152), (Z, 16)]), (X, -55))
    K.key_clip(arm, "windup", [(0.0, rest), (0.25, dip), (0.8, raise_), (1.0, coil)], 1.0, chains=chains)
    K.key_clip(arm, "windup_hold", [(0.0, coil), (0.5, aim(m(coil, chest=[(X, -14), (Y, -19)]), (X, -60))), (1.0, coil)], 1.0, loop=True, chains=chains)
    swing = aim(m(rest, spine=[(X, 10), (Y, -6)], chest=[(X, 6), (Y, -4)], head=[(X, -10)], clav_r=[(Z, 10)],
                  upper_r=[(X, -150), (Z, 8)], fore_r=[(X, -10)], upper_l=[(X, -40), (Z, -24)], fore_l=[(X, -40)]), (X, 30))
    smash = aim(m(rest, spine=[(X, 30), (Y, 10)], chest=[(X, 26), (Y, 8)], head=[(X, 6)], neck=[(X, 4)],
                  upper_r=[(X, -70), (Z, 8)], fore_r=[(X, -20)], upper_l=[(X, -30), (Z, -20)], fore_l=[(X, -20)],
                  thigh_r=[(X, -24)], shin_r=[(X, 34)], thigh_l=[(X, 18)], shin_l=[(X, 10)]), (X, 108))
    sink = aim(m(smash, spine=[(X, 34), (Y, 12)]), (X, 112))
    K.key_clip(arm, "strike", [(0.0, coil), (0.07, swing), (0.14, smash), (0.32, sink), (0.75, aim(m(rest, spine=[(X, 18)]), (X, 30))), (1.25, rest)], 1.25, chains=chains)
    reel = m(rest, spine=[(X, -16), (Z, 8)], chest=[(X, -14)], head=[(X, -24), (Z, 10)], upper_r=[(X, -6), (Z, 30)], upper_l=[(X, 10), (Z, -36)], fore_l=[(X, -10)])
    slump = m(rest, spine=[(X, 26)], chest=[(X, 22)], head=[(X, 30)], upper_r=[(X, -40)], fore_r=[(X, -40)], thigh_r=[(X, -20)], shin_r=[(X, 40)], thigh_l=[(X, -10)], shin_l=[(X, 30)])
    K.key_clip(arm, "stagger", [(0.0, rest), (0.12, reel), (0.6, slump), (1.3, m(slump, head=[(X, 22), (Y, 14)])), (1.8, rest)], 1.8, chains=chains)
    cry = m(rest, spine=[(X, -14)], chest=[(X, -18)], neck=[(X, -20)], head=[(X, -30)],
            clav_r=[(Z, 20)], upper_r=[(X, -120), (Z, 40)], fore_r=[(X, -20)], clav_l=[(Z, -20)], upper_l=[(X, -130), (Z, -45)], fore_l=[(X, -15)], fingers_l=[(X, 25)])
    K.key_clip(arm, "howl", [(0.0, rest), (0.4, m(rest, spine=[(X, 14)], chest=[(X, 16)])), (0.9, cry), (1.6, m(cry, head=[(X, -36), (Z, 6)])), (2.0, rest)], 2.0, chains=chains)
    fall = m(rest, spine=[(X, 50)], chest=[(X, 30)], head=[(X, 30)], upper_r=[(X, -60)], upper_l=[(X, -70)], thigh_r=[(X, -40)], shin_r=[(X, 70)], thigh_l=[(X, -30)], shin_l=[(X, 60)])
    K.key_clip(arm, "death", [(0.0, rest), (0.5, slump), (1.3, m(slump, spine=[(X, 34)])), (2.0, fall), (2.6, fall)], 2.6, chains=chains,
               root_keys=[(0.0, (0, 0, 0)), (1.3, (0, -0.1, 0)), (2.0, (0, -0.42, -0.35)), (2.6, (0, -0.48, -0.42))])
    # signature moves
    lift = aim(m(rest, chest=[(X, -6)], upper_r=[(X, -70), (Z, 8)], fore_r=[(X, -40)], head=[(X, -12)], thigh_r=[(X, -10)]), (X, 4))
    plant = aim(m(rest, spine=[(X, 22)], chest=[(X, 18)], head=[(X, 10)], upper_r=[(X, -20), (Z, 6)], fore_r=[(X, -20)],
                  thigh_r=[(X, -14)], shin_r=[(X, 24)]), (X, 2))
    to_bell = aim(m(rest, spine=[(X, -6)], chest=[(X, -10)], neck=[(X, -8)], head=[(X, -20)], clav_r=[(Z, 14)],
                    upper_r=[(X, -150), (Z, 10)], fore_r=[(X, -20)], upper_l=[(X, -40), (Z, -30)], fore_l=[(X, -40)], fingers_l=[(X, 20)]), (X, -6))
    tremble = aim(m(to_bell, chest=[(X, -12), (Z, 2)], head=[(X, -22), (Z, -3)]), (X, -8), (Z, 3))
    # the cast is 3.6 s (bone_abbot.gd TOLL_TIME): raised to the bell for it, the crozier driven down as it rings, and again
    K.key_clip(arm, "toll", [(0.0, rest), (0.7, to_bell), (1.6, tremble), (2.5, to_bell), (3.25, tremble), (3.5, lift), (3.62, plant),
                             (3.95, lift), (4.1, plant), (4.8, rest)], 4.8, chains=chains)
    claw_up = m(rest, spine=[(X, -6)], chest=[(X, -12), (Y, -10)], head=[(X, -26)], clav_l=[(Z, -24)], upper_l=[(X, -165), (Z, -10)], fore_l=[(X, -5)], fingers_l=[(X, 30)])
    K.key_clip(arm, "bone_rain", [(0.0, rest), (0.5, claw_up), (1.2, m(claw_up, chest=[(X, -12), (Y, 14)])), (2.0, rest)], 2.0, chains=chains)
    drive = aim(m(rest, spine=[(X, 34)], chest=[(X, 24)], head=[(X, 20)], upper_r=[(X, -60)], fore_r=[(X, -70)], upper_l=[(X, -70), (Z, 30)], fore_l=[(X, -60)],
                  thigh_r=[(X, -24)], shin_r=[(X, 46)], thigh_l=[(X, -24)], shin_l=[(X, 46)]), (X, 8))
    K.key_clip(arm, "grave_spikes", [(0.0, rest), (0.8, aim(m(lift, upper_r=[(X, -110), (Z, 8)], upper_l=[(X, -110), (Z, 30)], fore_l=[(X, -30)]), (X, 0))), (1.08, drive), (1.5, aim(m(drive, spine=[(X, 36)]), (X, 8))), (2.0, rest)], 2.0, chains=chains)
    wide_r = aim(m(rest, spine=[(Y, -40), (X, 6)], chest=[(Y, -30)], head=[(Y, 24)], upper_r=[(X, -60), (Z, 50)], fore_r=[(X, -10)], upper_l=[(X, -60), (Z, -20)]),
                 (X, 80), (Y, -120))
    wide_l = aim(m(rest, spine=[(Y, 40), (X, 10)], chest=[(Y, 30)], upper_r=[(X, -80), (Z, -20)], fore_r=[(X, -10)], upper_l=[(X, -20), (Z, -40)], head=[(Y, 10)]),
                 (X, 80), (Y, 110))
    wide_mid = aim(m(rest, spine=[(X, 12)], chest=[(X, 6)], upper_r=[(X, -80), (Z, 10)], fore_r=[(X, -10)]), (X, 82))
    wound = aim(m(wide_r, spine=[(Y, -46), (X, 8)], chest=[(Y, -34)]), (X, 78), (Y, -130))
    K.key_clip(arm, "sweep", [(0.0, rest), (0.5, wide_r), (0.92, wound), (1.05, wide_mid), (1.17, wide_l),
                              (1.45, aim(m(wide_l, spine=[(Y, 46), (X, 12)]), (X, 84), (Y, 125))), (2.0, rest)], 2.0, chains=chains)
    open_ = m(rest, spine=[(X, -10)], chest=[(X, -16)], head=[(X, -34)], clav_r=[(Z, 22)], clav_l=[(Z, -22)],
              upper_r=[(X, -30), (Z, 62)], fore_r=[(X, -30)], upper_l=[(X, -30), (Z, -70)], fore_l=[(X, -5)], fingers_l=[(X, 20)])
    open_ = aim(open_, (Z, -10))
    K.key_clip(arm, "requiem", [(0.0, rest), (0.8, open_), (2.2, aim(m(open_, head=[(X, -40)], chest=[(X, -20)]), (Z, -12))), (3.0, rest)], 3.0, chains=chains,
               root_keys=[(0.0, (0, 0, 0)), (0.8, (0, 0.05, 0)), (2.2, (0, 0.08, 0)), (3.0, (0, 0, 0))])
    beckon = m(rest, chest=[(X, 4)], head=[(X, 4)], upper_l=[(X, -80), (Z, -6)], fore_l=[(X, -70)], fingers_l=[(X, 40)])
    K.key_clip(arm, "tithe", [(0.0, rest), (0.4, beckon), (0.7, m(beckon, fingers_l=[(X, -20)])), (1.0, beckon), (1.3, m(beckon, fingers_l=[(X, -20)])), (1.6, rest)], 1.6, chains=chains)


def main():
    K.clear_scene()
    g = build_body()
    ob = K.make_object(g, "BoneAbbot", subdiv=0)      # 29k tris (subdivided: 115k, the Anchoress 14k)
    arm = K.build_armature(BONES, "AbbotRig")
    K.bind(ob, arm)
    if DO_AO:
        # AO on the base mesh (subdivision applied at export keeps the corner colours)
        K.bake_ao_alpha(ob)
    clips(arm)
    K.export_glb(arm, ob, OUT)
    if RENDERS:
        K.review_renders(arm, ob, RENDERS, "abbot", 1.9, poses=[("windup", 1.0, 70.0), ("strike", 0.07, 70.0), ("strike", 0.2, 70.0), ("howl", 1.0, 20.0),
                                                                   ("toll", 0.5, 50.0), ("requiem", 1.5, 10.0), ("sweep", 0.45, 20.0), ("sweep", 0.7, 20.0),
                                                                   ("grave_spikes", 0.8, 50.0), ("walk", 0.4, 60.0)])
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(K.ROOT, "art/blender/vb_bone_abbot.blend"))


main()
