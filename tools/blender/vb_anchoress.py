"""The Anchoress, modelled in Blender in the villagers' style (18 Nov). Run:
    blender -b -P tools/blender/vb_anchoress.py -- [--out art/models/bosses/vb_anchoress.glb] [--renders <dir>] [--no-ao]

Her own design (core/enemy/anchoress.gd): a hermit who had herself walled into the cliff to pray the sky still and
would not come out when the wall was opened, so she brought the wall with her. Tall, gaunt and bowed under it: a slab
of her cell's mortared stones strapped to her back with chain, the squint window still in it with her candle burning
behind the bars; grey wool to the floor, wound round and round from the shoulders to the knees in the chain she bound
herself with, padlocks and faded prayer ribbons hung from it; a deep hood over a pale face, a linen band over her
shut eyes, her mouth a thin line; a shawl of darker wool; thin pale hands, the right fist round the chain of her
anchor (a cairn of three stones bound in iron, hanging to the floor and dragged behind her), the left holding a
caged lantern at the hip (her weak point: the Toll of the Cell).

Silhouette: broad and square at the top (the wall), a narrow bowed body under it, the anchor's mass low at her right.

Rig space: x right, y up, z back, facing -Z, metres (built at a person's scale; the game scales her up).
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


OUT = os.path.join(K.ROOT, arg("--out", "art/models/bosses/vb_anchoress.glb"))
RENDERS = arg("--renders")
DO_AO = "--no-ao" not in ARGS

# --- palette (sRGB) ------------------------------------------------------------------------------------------
WOOL = np.array([0.33, 0.32, 0.3])
WOOL_LIT = np.array([0.42, 0.41, 0.38])
WOOL_DK = np.array([0.2, 0.19, 0.18])
SHAWL = np.array([0.24, 0.2, 0.17])
MUD = np.array([0.2, 0.17, 0.13])
SKIN = (0.62, 0.57, 0.52)
SKIN_DK = (0.48, 0.43, 0.4)
LINEN = (0.66, 0.6, 0.5)
LINEN_DK = (0.5, 0.45, 0.37)
STONE = np.array([0.42, 0.4, 0.37])
STONE_DK = np.array([0.3, 0.29, 0.27])
MORTAR = (0.46, 0.43, 0.38)
IRON = (0.2, 0.2, 0.21)
IRON_LT = (0.33, 0.32, 0.31)
RIBBON = [(0.5, 0.17, 0.13), (0.55, 0.48, 0.3), (0.42, 0.3, 0.22), (0.62, 0.58, 0.48)]
HOLLOW = (0.03, 0.025, 0.025)
FLAME = (1.0, 0.7, 0.32)
EMBER = (1.0, 0.55, 0.2)

# --- the skeleton (rig space) -----------------------------------------------------------------------------
P = 0.92
SKIRT_N = 8
SKIRT_Y = [0.9, 0.61, 0.32, 0.03]
SKIRT_R = [0.18, 0.25, 0.32, 0.4]
SHAWL_N = 6
GRIP_R = V(0.255, 0.7, -0.07)          # the right fist round the anchor chain
GRIP_L = V(-0.25, 0.74, -0.06)          # the left round the lantern's ring
ANCHOR_TOP = 0.42                        # the stone's iron ring
LANT_Y = 0.52                            # the lantern's middle


def skirt_pt(i, lvl):
    a = TAU * i / SKIRT_N
    return V(math.sin(a) * SKIRT_R[lvl], SKIRT_Y[lvl], -math.cos(a) * SKIRT_R[lvl] * 0.9 + 0.02)


def shawl_pt(i, lvl):
    a = math.radians(-150.0 + 300.0 * i / (SHAWL_N - 1))
    r = [0.17, 0.31][lvl]
    y = [1.38, 1.13][lvl]
    return V(math.sin(a) * r, y, -math.cos(a) * r * 0.8 + 0.02)


BONES = {
    "root": (V(0, 0, 0), V(0, 0.12, 0), None, False),
    "pelvis": (V(0, P, 0.0), V(0, 1.04, 0.0), "root", True),
    "spine": (V(0, 1.04, 0.0), V(0, 1.22, -0.03), "pelvis", True),
    "chest": (V(0, 1.22, -0.03), V(0, 1.4, -0.07), "spine", True),
    "neck": (V(0, 1.4, -0.07), V(0, 1.5, -0.12), "chest", True),
    "head": (V(0, 1.5, -0.12), V(0, 1.7, -0.14), "neck", True),
    "achain_0": (GRIP_R, V(0.255, 0.56, -0.07), "hand_r", True),
    "achain_1": (V(0.255, 0.56, -0.07), V(0.255, ANCHOR_TOP, -0.07), "achain_0", True),
    "anchor": (V(0.255, ANCHOR_TOP, -0.07), V(0.255, 0.06, -0.07), "achain_1", True),
    "lantern": (GRIP_L, V(-0.25, LANT_Y - 0.08, -0.06), "hand_l", True),
}
for s, tag in ((-1.0, "l"), (1.0, "r")):
    BONES.update({
        "clav_" + tag: (V(s * 0.04, 1.38, -0.05), V(s * 0.19, 1.37, -0.01), "chest", True),
        "upper_" + tag: (V(s * 0.19, 1.37, -0.01), V(s * 0.23, 1.06, 0.0), "clav_" + tag, True),
        "fore_" + tag: (V(s * 0.23, 1.06, 0.0), V(s * 0.25, 0.78, -0.03), "upper_" + tag, True),
        "hand_" + tag: (V(s * 0.25, 0.78, -0.03), V(s * 0.255, 0.7, -0.06), "fore_" + tag, True),
        "thigh_" + tag: (V(s * 0.09, 0.88, 0.0), V(s * 0.1, 0.48, -0.01), "pelvis", True),
        "shin_" + tag: (V(s * 0.1, 0.48, -0.01), V(s * 0.1, 0.08, 0.01), "thigh_" + tag, True),
        "foot_" + tag: (V(s * 0.1, 0.08, 0.01), V(s * 0.1, 0.03, -0.12), "shin_" + tag, True),
    })
for i in range(SKIRT_N):
    for lvl in range(3):
        BONES["skirt_%d_%d" % (i, lvl)] = (skirt_pt(i, lvl), skirt_pt(i, lvl + 1), "pelvis" if lvl == 0 else "skirt_%d_%d" % (i, lvl - 1), True)
for i in range(SHAWL_N):
    BONES["shawl_%d" % i] = (shawl_pt(i, 0), shawl_pt(i, 1), "chest", True)


# --- weights -----------------------------------------------------------------------------------------------

def w_spine(p):
    y = p[1]
    pts = [("pelvis", 0.94), ("spine", 1.12), ("chest", 1.32), ("neck", 1.47)]
    for k in range(len(pts) - 1):
        (b0, y0), (b1, y1) = pts[k], pts[k + 1]
        if y0 <= y <= y1:
            t = (y - y0) / (y1 - y0)
            return {b0: 1.0 - t, b1: t}
    return {"pelvis": 1.0} if y < 0.94 else {"neck": 1.0}


def w_skirt(p):
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
        return w_spine(p)
    for lvl in range(3):
        y0, y1 = SKIRT_Y[lvl], SKIRT_Y[lvl + 1]
        if y1 <= y <= y0 or (lvl == 2 and y < y1):
            u = min(1.0, max(0.0, (y0 - y) / (y0 - y1)))
            wl = [(lvl, 1.0 - 0.5 * u), (min(lvl + 1, 2), 0.5 * u)] if lvl < 2 else [(2, 1.0)]
            for lv, ww in wl:
                out["skirt_%d_%d" % (i0, lv)] = out.get("skirt_%d_%d" % (i0, lv), 0.0) + ww * (1.0 - t)
                out["skirt_%d_%d" % (i1, lv)] = out.get("skirt_%d_%d" % (i1, lv), 0.0) + ww * t
            break
    side = "r" if p[0] > 0 else "l"
    front = max(0.0, -(p[2] - 0.02)) / 0.4
    leg = 0.4 * smooth(0.0, 0.5, front) * smooth(0.0, 0.14, abs(p[0]))
    if leg > 0.01:
        out = {k: v * (1.0 - leg) for k, v in out.items()}
        out["thigh_" + side if y > 0.48 else "shin_" + side] = leg
    return out


def w_body(p):
    return w_skirt(p) if p[1] < SKIRT_Y[0] else w_spine(p)


def w_arm(tag):
    def f(p):
        y = p[1]
        if y > 1.06:
            t = smooth(1.38, 1.12, y)
            return {"clav_" + tag: 1.0 - t, "upper_" + tag: t} if y > 1.22 else {"upper_" + tag: 1.0}
        t = smooth(1.1, 1.0, y)
        return {"upper_" + tag: 1.0 - t, "fore_" + tag: t} if y > 0.98 else {"fore_" + tag: 1.0}
    return f


def w_shawl(p):
    a = math.atan2(p[0], -(p[2] - 0.02))
    def ang(i):
        return math.radians(-150 + 300 * i / (SHAWL_N - 1))
    best = sorted(range(SHAWL_N), key=lambda i: abs(math.atan2(math.sin(a - ang(i)), math.cos(a - ang(i)))))[:2]
    r = math.hypot(p[0], p[2] - 0.02)
    edge = smooth(0.17, 0.3, r)
    out = {"chest": 1.0 - edge}
    for k, i in enumerate(best):
        out["shawl_%d" % i] = out.get("shawl_%d" % i, 0.0) + edge * (0.65 if k == 0 else 0.35)
    side = "clav_r" if p[0] > 0 else "clav_l"
    k = 0.4 * smooth(0.18, 0.36, abs(p[0]))
    if k > 0.01:
        out = {b: w * (1.0 - k) for b, w in out.items()}
        out[side] = k
    return out


def w_hood(p):
    if p[1] < 1.47:
        t = smooth(1.36, 1.47, p[1])
        return {"chest": 1.0 - t, "neck": t}
    return {"head": 1.0}


# --- the body ----------------------------------------------------------------------------------------------

def robe(g):
    rng = np.random.default_rng(7)
    ph = rng.uniform(0, TAU, 4)

    def fold(th, y, r):
        depth = 0.006 + 0.045 * smooth(0.92, 0.05, y)
        return depth * (0.6 * math.sin(11 * th + ph[0]) + 0.3 * math.sin(19 * th + ph[1] + y * 2.5) + 0.1 * math.sin(29 * th + ph[2]))

    def col(th, y, dr):
        ridge = (dr / 0.045) * 0.5 + 0.5
        c = WOOL * (1.0 - ridge) + WOOL_LIT * ridge
        dirt = smooth(0.3, 0.02, y)
        return tuple(c * (1.0 - 0.6 * dirt) + MUD * 0.6 * dirt)

    def hem(th):
        return 0.025 * abs(math.sin(15 * th + 0.4)) + 0.02 * abs(math.sin(6 * th + 1.1))

    prof = []
    for k in range(24):
        u = k / 23.0
        prof.append((0.94 - u * 0.91, 0.18 + 0.22 * (u ** 1.4)))
    prof.reverse()
    K.lathe(g, prof, 96, col, "cloth", w_skirt, centre=V(0, 0, 0.02), fold=fold, zscale=0.9, hem=hem)
    for i in range(18):
        a = TAU * i / 18 + 0.15 * math.sin(i * 2.7)
        d = V(math.sin(a), 0, -math.cos(a) * 0.9)
        top = V(0, 0.06, 0.02) + d * 0.41
        ln = 0.05 + 0.05 * abs(math.sin(i * 2.1))
        wd = 0.045 + 0.02 * abs(math.sin(i * 1.3))
        K.tube(g, [top, top + d * 0.01 + V(0, -ln * 0.5, 0), top + d * 0.016 + V(0, -ln, 0)], [wd, wd * 0.8, wd * 0.3], 6,
               tuple(MUD * 0.95), "cloth", w_skirt, squash=(1.0, 0.14), ref=d)


def torso(g):
    """Narrow and bowed: hips to the neck, the top leaning forward under the wall."""
    rows = []
    for k in range(12):
        u = k / 11.0
        y = 0.9 + u * 0.52
        z = 0.02 - 0.1 * (u ** 1.5)
        rx = 0.17 + 0.03 * math.sin(u * math.pi) - 0.07 * smooth(0.72, 1.0, u)
        rz = 0.13 + 0.02 * math.sin(u * math.pi) - 0.05 * smooth(0.72, 1.0, u)
        rows.append((V(0, y, z), rx, rz))
    K.loft(g, rows, 40, lambda th, j, dr, p: tuple(WOOL * (0.92 + 0.1 * math.sin(7 * th))), "cloth", w_spine,
           fold=lambda th, j, n: 0.007 * math.sin(7 * th + j * 0.5))


def body_r(y):
    """The robe's (or bodice's) radius at height y, for winding the chain round it."""
    if y < 0.94:
        u = (0.94 - y) / 0.91
        return 0.18 + 0.22 * (u ** 1.4), 0.9
    u = min(1.0, (y - 0.9) / 0.52)
    rx = 0.17 + 0.03 * math.sin(u * math.pi) - 0.07 * smooth(0.72, 1.0, u)
    rz = 0.13 + 0.02 * math.sin(u * math.pi) - 0.05 * smooth(0.72, 1.0, u)
    return rx, rz / max(rx, 1e-3)


def chain_links(g, pts, size, weights, col=IRON):
    """A chain along a path: oval links, each turned a quarter to the last, `size` long."""
    pts = [np.asarray(p, dtype=np.float64) for p in pts]
    # resample by length
    seg = [float(np.linalg.norm(pts[i + 1] - pts[i])) for i in range(len(pts) - 1)]
    total = sum(seg)
    n = max(2, int(total / (size * 0.78)))
    out = []
    for k in range(n + 1):
        d = total * k / n
        i = 0
        while i < len(seg) - 1 and d > seg[i]:
            d -= seg[i]
            i += 1
        t = d / seg[i] if seg[i] > 0 else 0.0
        out.append(pts[i] * (1 - t) + pts[i + 1] * t)
    for k in range(n):
        a, b = out[k], out[k + 1]
        c = (a + b) * 0.5
        ax = (b - a) / (np.linalg.norm(b - a) + 1e-9)
        s1, s2 = K._frame(ax)
        side = s1 if k % 2 == 0 else s2
        r_long, r_wide = size * 0.55, size * 0.3
        loop = [c + ax * math.cos(t) * r_long + side * math.sin(t) * r_wide for t in np.linspace(0, TAU, 11)[:-1]]
        loop.append(loop[0])
        K.tube(g, loop, [size * 0.09] * len(loop), 5, col, "metal", weights, caps=False)


def wound_chain(g):
    """The chain she bound herself with, from the shoulders to the knees, with padlocks and prayer ribbons."""
    pts = []
    for i in range(140):
        t = i / 139.0
        a = t * TAU * 3.4 + 0.5
        y = 1.32 - t * 0.86 - 0.035 * math.sin(a * 0.5)
        rx, zs = body_r(y)
        r = rx + 0.02
        z0 = 0.02 - (0.1 * (min(1.0, max(0.0, (y - 0.9) / 0.52)) ** 1.5) if y > 0.9 else 0.0)
        pts.append(V(math.sin(a) * r, y, -math.cos(a) * r * zs + z0))
    chain_links(g, pts, 0.034, w_body)
    rng = np.random.default_rng(31)
    for k in range(9):
        cp = pts[8 + 14 * k]
        out = cp * V(1, 0, 1)
        out = out / (np.linalg.norm(out) + 1e-9)
        lk = cp + out * 0.03 + V(0, -0.04, 0)
        K.blob(g, lk, [0.026, 0.03, 0.014], IRON_LT if k % 2 else IRON, "metal", w_body, basis=K.rot_y(math.atan2(out[0], -out[2])), rings=5, segs=10, power=0.55)
        K.tube(g, [lk + V(-0.014, 0.02, 0), lk + V(-0.014, 0.045, 0), lk + V(0.014, 0.045, 0), lk + V(0.014, 0.02, 0)],
               [0.005] * 4, 5, IRON, "metal", w_body, caps=False)
        if k % 2 == 0:
            ln = rng.uniform(0.14, 0.26)
            c = RIBBON[k // 2 % len(RIBBON)]
            K.tube(g, [cp + out * 0.03, cp + out * 0.045 + V(0.01, -ln * 0.5, 0), cp + out * 0.05 + V(0, -ln, 0.01)],
                   [0.016, 0.014, 0.006], 5, c, "linen", w_body, squash=(1.0, 0.18), ref=out)


def wall(g):
    """The slab of her cell's wall strapped to her back, lying along her bowed back with its top over her shoulders:
    mortared stones, uneven, broken off along the top; the squint window with three iron bars and her candle burning
    behind them; moss in the joints; chains over each shoulder and crossed on her breast to hold it. Built in the
    slab's own frame (x right, y up the slab, z out of its face) and laid on her back."""
    C = V(0, 1.31, 0.25)
    R = K.rot_x(0.06) @ np.diag([0.88, 0.9, 1.0])   # near upright on her bowed back (the bow leans it ~20 deg)
    flip = np.diag([1.0, 1.0, 1.0])

    def T(p):
        return C + R @ (flip @ np.asarray(p, dtype=np.float64))

    def stone(lc, half, col, seed, yaw=0.0, roll=0.0, power=0.2, lumps=0.07):
        n0 = len(g.v)
        K.blob(g, V(0, 0, 0), list(half), col, "linen", "chest", basis=K.rot_z(roll) @ K.rot_y(yaw), rings=8, segs=16, power=power, lumps=lumps, seed=seed)
        for i in range(n0, len(g.v)):
            g.v[i] = T(g.v[i] + lc)

    rng = np.random.default_rng(11)
    stone(V(0, 0, -0.04), (0.29, 0.31, 0.06), MORTAR, 2, power=0.35, lumps=0.03)
    rows = [(-0.24, 3), (-0.08, 4), (0.08, 3), (0.24, 2)]
    for r, (dy, n) in enumerate(rows):
        w = 0.56 / n
        for k in range(n):
            if r == 2 and k == 1:
                continue                                        # the squint
            x = -0.28 + w * (k + 0.5) + (0.03 if r % 2 else -0.02)
            col = STONE * rng.uniform(0.85, 1.1) if (r + k) % 3 else STONE_DK * rng.uniform(0.9, 1.1)
            stone(V(x, dy, 0.015), (w * 0.46 * rng.uniform(0.9, 1.04), 0.072 * rng.uniform(0.9, 1.08), 0.06), tuple(col), 40 + r * 7 + k)
    stone(V(-0.12, 0.36, 0.0), (0.13, 0.06, 0.06), tuple(STONE * 0.95), 71, roll=0.18, lumps=0.08)
    stone(V(0.16, 0.34, -0.005), (0.09, 0.05, 0.055), tuple(STONE_DK), 72, roll=-0.3, lumps=0.1)
    # the squint: dark inside, the candle, the bars
    sq = V(0.0, 0.08, 0.0)
    n0 = len(g.v)
    K.blob(g, sq + V(0, 0, -0.01), [0.08, 0.07, 0.05], HOLLOW, "cloth", "chest", rings=6, segs=10, power=0.4)
    K.blob(g, sq + V(0, -0.03, 0.0), [0.026, 0.02, 0.026], (0.85, 0.8, 0.68), "linen", "chest", rings=4, segs=8)
    K.blob(g, sq + V(0, 0.016, 0.0), [0.017, 0.035, 0.017], FLAME, "eye", "chest", rings=5, segs=8, glow=True)
    for bx in (-0.045, 0.0, 0.045):
        K.tube(g, [sq + V(bx, -0.085, 0.06), sq + V(bx, 0.085, 0.06)], [0.009, 0.009], 6, IRON, "metal", "chest")
    K.tube(g, [sq + V(-0.085, 0.0, 0.062), sq + V(0.085, 0.0, 0.062)], [0.007, 0.007], 5, IRON, "metal", "chest")
    for x in (-0.05, 0.05):
        K.tube(g, [sq + V(x, -0.08, 0.07), sq + V(x * 1.1, -0.12, 0.075), sq + V(x * 1.1, -0.16, 0.072)], [0.008, 0.007, 0.004], 5, (0.86, 0.82, 0.7), "linen", "chest")
    for k in range(9):
        x = rng.uniform(-0.25, 0.25)
        y = float(rng.choice([-0.16, 0.0, 0.16])) + rng.uniform(-0.02, 0.02)
        K.blob(g, V(x, y, 0.045), [0.04, 0.012, 0.02], (0.24, 0.3, 0.16), "fur", "chest", rings=3, segs=6, lumps=0.4, seed=90 + k)
    for i in range(n0, len(g.v)):
        g.v[i] = T(g.v[i])
    # the straps: over each shoulder, crossed on the breast, under the other arm to the slab's foot
    for s in (-1.0, 1.0):
        chain_links(g, [T(V(s * 0.2, 0.27, -0.05)), V(s * 0.14, 1.47, 0.0), V(s * 0.11, 1.4, -0.15), V(s * 0.05, 1.28, -0.205),
                        V(-s * 0.06, 1.17, -0.205), V(-s * 0.17, 1.1, -0.12), V(-s * 0.21, 1.08, 0.04), T(V(-s * 0.24, -0.27, -0.05))], 0.03, "chest")


def shawl(g):
    rows = []
    for k in range(9):
        u = k / 8.0
        rows.append((V(0, 1.46 - 0.34 * u, -0.03 + 0.03 * u), 0.14 + 0.18 * (u ** 0.7), 0.12 + 0.14 * (u ** 0.7)))
    rows.reverse()
    a0, a1 = math.radians(30.0), math.radians(330.0)

    def hem(th):
        return 0.025 * abs(math.sin(9 * th + 0.3)) - 0.06 * smooth(-0.2, -0.9, math.cos(th))

    def col(th, j, dr, p):
        t = j / 8.0
        return tuple(SHAWL * (0.8 + 0.25 * t) * (0.9 + 0.12 * math.sin(8 * th)))

    def fold(th, j, n):
        return 0.016 * (1.0 - j / 8.0) * math.sin(8 * th)

    K.loft(g, rows, 48, col, "fur", w_shawl, a0=a0, a1=a1, fold=fold, hem=hem)
    inner = [(V(c[0], c[1] - 0.012, c[2]), rx - 0.014, rz - 0.014) for c, rx, rz in rows]
    K.loft(g, inner, 48, tuple(SHAWL * 0.55), "fur", w_shawl, a0=a1, a1=a0, fold=fold, hem=hem)
    # a rosary of pebbles at the throat
    for i in range(13):
        a = -1.2 + 2.4 * i / 12
        K.blob(g, V(math.sin(a) * 0.12, 1.36 - 0.04 * math.cos(a * 0.8), -math.cos(a) * 0.1 - 0.035), [0.014] * 3, tuple(STONE * 0.9), "linen", "chest", rings=4, segs=6, lumps=0.15, seed=i)


def head(g):
    """A deep hood, a liripipe tail down her back; inside, a pale gaunt face: cheekbones and a long nose, a linen band
    over the shut eyes, knotted at the back."""
    hc = V(0, 1.58, -0.17)
    # the face (seen inside the hood)
    K.blob(g, hc, [0.072, 0.1, 0.085], SKIN, "skin", w_hood, rings=10, segs=16, seed=3)
    K.blob(g, hc + V(0, -0.07, -0.03), [0.04, 0.035, 0.045], SKIN_DK, "skin", w_hood, rings=6, segs=12)                 # a narrow chin
    for s in (-1.0, 1.0):
        K.blob(g, hc + V(s * 0.045, -0.02, -0.055), [0.022, 0.018, 0.018], SKIN_DK, "skin", w_hood, rings=5, segs=8)     # cheekbones
    K.tube(g, [hc + V(0, 0.02, -0.08), hc + V(0, -0.01, -0.094), hc + V(0, -0.026, -0.096)], [0.01, 0.013, 0.01], 8, SKIN, "skin", w_hood)
    K.tube(g, [hc + V(-0.022, -0.052, -0.083), hc + V(0, -0.056, -0.087), hc + V(0.022, -0.052, -0.083)], [0.004] * 3, 5, HOLLOW, "cloth", w_hood)
    # the linen band over her shut eyes, knotted at the back, its ends hanging
    band = [hc + V(math.sin(a) * 0.08, 0.022 + 0.004 * math.sin(3 * a), -math.cos(a) * 0.092) for a in np.linspace(-2.6, 2.6, 21)]
    K.tube(g, band, [0.026] * len(band), 6, LINEN, "linen", w_hood, squash=(0.35, 1.0), ref=V(0, 1, 0))
    K.blob(g, hc + V(0, 0.02, 0.09), [0.022, 0.018, 0.016], LINEN_DK, "linen", w_hood, rings=4, segs=8, lumps=0.2)
    for s in (-1.0, 1.0):
        K.tube(g, [hc + V(s * 0.01, 0.02, 0.095), hc + V(s * 0.03, -0.06, 0.115), hc + V(s * 0.025, -0.14, 0.125)], [0.012, 0.01, 0.004], 5, LINEN_DK, "linen", w_hood, squash=(1.0, 0.25))
    # the hood: a deep cowl, peaked, falling to a tail
    rows = [
        (V(0, 1.38, -0.04), 0.2, 0.18), (V(0, 1.45, -0.08), 0.17, 0.17), (V(0, 1.52, -0.12), 0.145, 0.165),
        (V(0, 1.59, -0.14), 0.135, 0.16), (V(0, 1.66, -0.14), 0.13, 0.155), (V(0, 1.72, -0.12), 0.115, 0.14),
        (V(0, 1.77, -0.09), 0.09, 0.11), (V(0, 1.8, -0.05), 0.06, 0.075), (V(0, 1.81, -0.01), 0.03, 0.04),
    ]
    OPEN = math.radians(52.0)

    def opening(th, j):
        a = abs(math.atan2(math.sin(th), math.cos(th)))
        lim = OPEN * (1.0 - 0.5 * smooth(3.8, 5.6, j))
        return a < lim and 1.6 < j < 5.6

    def col(th, j, dr, p):
        a = abs(math.atan2(math.sin(th), math.cos(th)))
        rim = smooth(OPEN + 0.45, OPEN, a) * smooth(1.0, 2.0, j) * smooth(6.2, 5.2, j)
        return tuple(WOOL_DK * (0.9 + 0.1 * math.sin(5 * th + j)) * (1.0 - rim) + WOOL * rim)

    K.loft(g, rows, 44, col, "cloth", w_hood, fold=lambda th, j, n: 0.008 * math.sin(6 * th + j), cap_top=True, skip=opening)
    edge = []
    for k in range(25):
        u = k / 24.0
        jj = 1.75 + (5.45 - 1.75) * math.sin(u * math.pi)
        lim = OPEN * (1.0 - 0.5 * smooth(3.8, 5.6, jj))
        th = (-1.0 if u < 0.5 else 1.0) * lim
        j0 = min(int(math.floor(jj)), len(rows) - 2)
        t = jj - j0
        (c0, rx0, rz0), (c1, rx1, rz1) = rows[j0], rows[j0 + 1]
        cc = c0 * (1 - t) + c1 * t
        rx, rz = rx0 * (1 - t) + rx1 * t, rz0 * (1 - t) + rz1 * t
        edge.append(cc + V(math.sin(th) * rx, 0, -math.cos(th) * rz))
    K.tube(g, edge, [0.018] * len(edge), 8, tuple(WOOL * 0.9), "cloth", w_hood)
    K.blob(g, hc + V(0, 0.02, 0.05), [0.12, 0.13, 0.1], HOLLOW, "cloth", w_hood, rings=8, segs=12)                     # dark behind the face


def sleeve(g, s, tag):
    path = [V(s * 0.18, 1.38, -0.01), V(s * 0.21, 1.22, 0.0), V(s * 0.23, 1.06, 0.0), V(s * 0.24, 0.92, -0.015), V(s * 0.25, 0.8, -0.03)]
    K.tube(g, path, [0.065, 0.062, 0.06, 0.065, 0.075], 16, tuple(WOOL * 0.95), "cloth", w_arm(tag), caps=False)
    K.tube(g, path, [0.055, 0.052, 0.05, 0.055, 0.067], 16, HOLLOW, "cloth", w_arm(tag), caps=False)
    cuff = path[-1]
    for i in range(10):
        a = TAU * i / 10
        d = V(math.cos(a), 0, math.sin(a))
        top = cuff + d * 0.072
        ln = 0.025 + 0.03 * abs(math.sin(i * 1.9))
        K.tube(g, [top, top + V(0, -ln, 0)], [0.022, 0.006], 5, tuple(MUD), "cloth", "fore_" + tag, squash=(1.0, 0.25), ref=d)
    # a thin pale wrist
    K.tube(g, [cuff + V(0, 0.05, 0), cuff + V(0, -0.03, -0.01)], [0.03, 0.028], 10, SKIN, "skin", "hand_" + tag)


def hand(g, s, tag, grip):
    """A thin hand closed round a grip (the anchor's chain, the lantern's ring): a palm, four bent fingers, a thumb."""
    hb = "hand_" + tag
    palm = grip + V(-s * 0.012, 0.04, 0.012)
    K.blob(g, palm, [0.032, 0.045, 0.024], SKIN, "skin", hb, rings=6, segs=10)
    for f in range(4):
        y = grip[1] + 0.03 - f * 0.018
        b = V(grip[0] - s * 0.03, y, grip[2] + 0.004)
        pts = [b, b + V(s * 0.005, 0, -0.03), b + V(s * 0.028, -0.004, -0.032), b + V(s * 0.034, -0.004, -0.008)]
        K.tube(g, pts, [0.011, 0.01, 0.009, 0.006], 6, SKIN, "skin", hb)
        K.blob(g, pts[1], [0.012] * 3, SKIN_DK, "skin", hb, rings=4, segs=6)
    th = grip + V(-s * 0.03, 0.035, -0.02)
    K.tube(g, [th, th + V(s * 0.02, -0.015, -0.025), th + V(s * 0.03, -0.035, -0.022)], [0.011, 0.009, 0.006], 6, SKIN, "skin", hb)


def anchor(g):
    """The anchor: a chain out of her fist to a cairn of three stones bound in iron bands with a ring at the top."""
    chain_links(g, [GRIP_R + V(0, 0.05, 0), V(0.255, 0.56, -0.07)], 0.036,
                lambda p: {"hand_r": 1.0} if p[1] > GRIP_R[1] - 0.005 else {"achain_0": 1.0})
    chain_links(g, [V(0.255, 0.56, -0.07), V(0.255, ANCHOR_TOP + 0.02, -0.07)], 0.036, "achain_1")
    top = V(0.255, ANCHOR_TOP, -0.07)
    K.tube(g, [top + V(math.cos(a) * 0.035, -0.035 + math.sin(a) * 0.035, 0) for a in np.linspace(0, TAU, 15)], [0.011] * 15, 6, IRON, "metal", "anchor", caps=False)
    rng = np.random.default_rng(5)
    stones = [(V(0, -0.1, 0), (0.085, 0.06, 0.075), 0.15), (V(0.01, -0.21, 0.0), (0.12, 0.07, 0.1), -0.2), (V(-0.005, -0.32, 0.005), (0.15, 0.08, 0.13), 0.35)]
    for k, (o, r, yaw) in enumerate(stones):
        K.blob(g, top + o, list(r), tuple(STONE * rng.uniform(0.85, 1.05)), "linen", "anchor", basis=K.rot_y(yaw), rings=7, segs=12,
               power=0.4, lumps=0.14, seed=60 + k)
    # iron bands down the sides, a collar under the ring
    for a in (0.0, math.pi * 0.5, math.pi, math.pi * 1.5):
        d = V(math.cos(a), 0, math.sin(a))
        pts = [top + V(0, -0.055, 0) + d * 0.05, top + V(0, -0.1, 0) + d * 0.09, top + V(0, -0.21, 0) + d * 0.125,
               top + V(0, -0.32, 0) + d * 0.155, top + V(0, -0.385, 0) + d * 0.1]
        K.tube(g, pts, [0.01] * 5, 5, IRON, "metal", "anchor", squash=(1.0, 0.4), ref=d)
    K.blob(g, top + V(0, -0.055, 0), [0.055, 0.02, 0.055], IRON_LT, "metal", "anchor", rings=4, segs=10)
    # lichen
    for k in range(5):
        a = rng.uniform(0, TAU)
        K.blob(g, top + V(math.cos(a) * 0.12, -0.24 - 0.04 * k % 0.12, math.sin(a) * 0.1), [0.035, 0.012, 0.03], (0.4, 0.42, 0.28), "fur", "anchor", rings=3, segs=6, lumps=0.4, seed=k)


def lantern(g):
    """A caged lantern from the left fist: a short chain, a cap, four bars, a horn pane glowing, a flame."""
    lc = V(-0.25, LANT_Y, -0.06)
    K.tube(g, [GRIP_L, lc + V(0, 0.09, 0)], [0.005, 0.005], 4, IRON, "metal", "lantern")
    K.blob(g, lc + V(0, 0.085, 0), [0.05, 0.03, 0.05], IRON, "metal", "lantern", rings=5, segs=10, phi=(0.0, 0.55))
    K.tube(g, [lc + V(0, 0.115, 0), lc + V(0, 0.14, 0)], [0.012, 0.004], 6, IRON, "metal", "lantern")
    for dy in (0.065, -0.07):
        K.tube(g, [lc + V(math.cos(a) * 0.05, dy, math.sin(a) * 0.05) for a in np.linspace(0, TAU, 13)], [0.007] * 13, 5, IRON, "metal", "lantern", caps=False)
    for i in range(4):
        a = TAU * i / 4 + 0.785
        o = V(math.cos(a), 0, math.sin(a)) * 0.05
        K.tube(g, [lc + o + V(0, 0.065, 0), lc + o * 1.15, lc + o + V(0, -0.07, 0)], [0.006] * 3, 5, IRON, "metal", "lantern")
    K.blob(g, lc, [0.042, 0.06, 0.042], EMBER, "eye", "lantern", rings=6, segs=10, glow=True)
    K.blob(g, lc + V(0, -0.075, 0), [0.05, 0.015, 0.05], IRON, "metal", "lantern", rings=4, segs=10)


def feet(g):
    for s, tag in ((-1.0, "l"), (1.0, "r")):
        b = V(s * 0.1, 0.03, -0.25)
        K.blob(g, b, [0.034, 0.024, 0.045], tuple(MUD * 0.7), "linen", "foot_" + tag, rings=5, segs=8)
        K.tube(g, [b + V(-0.04, 0.0, 0.01), b + V(0, 0.03, 0.02), b + V(0.04, 0.0, 0.01)], [0.008] * 3, 5, LINEN_DK, "linen", "foot_" + tag)


def build_body():
    g = K.Geo()
    robe(g)
    torso(g)
    wound_chain(g)
    shawl(g)
    wall(g)
    head(g)
    for s, tag in ((-1.0, "l"), (1.0, "r")):
        sleeve(g, s, tag)
    hand(g, 1.0, "r", GRIP_R)
    hand(g, -1.0, "l", GRIP_L)
    anchor(g)
    lantern(g)
    feet(g)
    return g


# --- the clips ---------------------------------------------------------------------------------------------
X = V(-1, 0, 0)     # + leans an upright bone forward, swings a hanging one back
Y = V(0, 1, 0)      # + turns the front toward her left
Z = V(0, 0, 1)      # + on a right arm raises it out to the side; on a hanging bone points it to her right (+X)


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


ARM_R = ("pelvis", "spine", "chest", "clav_r", "upper_r", "fore_r", "hand_r")
ARM_L = ("pelvis", "spine", "chest", "clav_l", "upper_l", "fore_l", "hand_l")


def aim(pose, bone, chain, *tilt):
    """`bone` (hanging from the end of `chain`) set to point along its rest direction turned by `tilt` in the world,
    whatever the body and arm do."""
    q = _q([])
    for b in chain:
        q = q @ _q(pose.get(b, []))
    ax, ang = (q.inverted() @ _q(list(tilt))).to_axis_angle()
    out = dict(pose)
    out[bone] = [(V(ax.x, ax.y, ax.z), math.degrees(ang))]
    return out


def hang(pose, anchor_tilt=(), sag=0.0):
    """The anchor's chain (aimed) with its lower link bent by `sag`, and the lantern hanging plumb."""
    p = aim(pose, "achain_0", ARM_R, *anchor_tilt) if anchor_tilt else aim(pose, "achain_0", ARM_R)
    p["achain_1"] = [(X, sag)]
    p["anchor"] = [(X, sag * 0.6)]
    return aim(p, "lantern", ARM_L)


REST = m(spine=[(X, 8)], chest=[(X, 12)], neck=[(X, -2)], head=[(X, 6)],
         upper_r=[(X, -8), (Z, 3)], fore_r=[(X, -12)], upper_l=[(X, -12), (Z, -4)], fore_l=[(X, -30)])


def clips(arm):
    rest = hang(REST)
    cloth = [["skirt_%d_%d" % (i, l) for l in range(3)] for i in range(SKIRT_N)] + [["shawl_%d" % i] for i in range(SHAWL_N)]
    swingers = [{"bones": ["achain_1", "anchor"], "drive": "hand_r", "gain": 0.7, "add": True, "ripple": 0.3},
                {"bones": ["lantern"], "drive": "hand_l", "gain": 0.9, "add": True, "ripple": 0.6}]
    chains = cloth + swingers
    # idle: she prays under her breath, the head bobbing, rocking from foot to foot; the lantern sways
    pray_a = hang(m(REST, spine=[(X, 10)], chest=[(X, 14)], head=[(X, 12)], neck=[(X, 2)]))
    pray_b = hang(m(REST, pelvis=[(Z, 2)], spine=[(X, 6), (Z, -2)], head=[(X, 2), (Y, -10)], fore_l=[(X, -38)]))
    pray_c = hang(m(REST, pelvis=[(Z, -2)], spine=[(X, 7), (Z, 2)], head=[(X, 4), (Y, 9)], fore_r=[(X, -18)]))
    K.key_clip(arm, "idle", [(0.0, rest), (0.9, pray_a), (1.8, rest), (2.7, pray_b), (3.6, pray_a), (4.5, pray_c), (5.4, rest)], 5.4,
               loop=True, chains=chains, ripple=0.035)
    # walk: a bowed trudge, the anchor dragged at her right side, trailing
    def stride(s):
        return hang(m(REST, pelvis=[(Y, 5 * s), (Z, 2 * s)], spine=[(X, 12), (Y, -4 * s)], chest=[(X, 12), (Y, -5 * s)],
                      thigh_r=[(X, -26 * s)], shin_r=[(X, 12 if s < 0 else 30)], thigh_l=[(X, 26 * s)], shin_l=[(X, 12 if s > 0 else 30)],
                      upper_l=[(X, -12 + 12 * s)], upper_r=[(X, 4), (Z, 6)]), ((X, 28),), sag=-12)
    K.key_clip(arm, "walk", [(0.0, stride(1)), (0.85, stride(-1)), (1.7, stride(1))], 1.7, loop=True, chains=chains, ripple=0.03)
    # the Anchor Swing: the anchor hauled up and round over the right shoulder (the tell, held), then flung down the lane
    heave = hang(m(REST, spine=[(X, 22), (Y, -14)], chest=[(X, 16), (Y, -10)], head=[(X, 0)], upper_r=[(X, 30), (Z, 12)], fore_r=[(X, -20)],
                   thigh_r=[(X, -10)], shin_r=[(X, 20)], thigh_l=[(X, 8)]), ((X, 70),), sag=20)
    lift = hang(m(REST, spine=[(X, -6), (Y, -26)], chest=[(X, -10), (Y, -18)], head=[(X, -8), (Y, 16)], clav_r=[(Z, 14)],
                  upper_r=[(X, -120), (Z, 20)], fore_r=[(X, -40)], upper_l=[(X, -30), (Z, -26)], fore_l=[(X, -40)],
                  thigh_l=[(X, -12)], shin_l=[(X, 8)], thigh_r=[(X, 10)]), ((X, 165),), sag=-30)
    coil = hang(m(lift, spine=[(X, -10), (Y, -32)], chest=[(X, -12), (Y, -22)], upper_r=[(X, -138), (Z, 22)]), ((X, 175), (Y, -30)), sag=-40)
    K.key_clip(arm, "windup", [(0.0, rest), (0.3, heave), (0.75, lift), (1.0, coil)], 1.0, chains=chains)
    K.key_clip(arm, "windup_hold", [(0.0, coil), (0.5, hang(m(coil, chest=[(X, -14), (Y, -25)]), ((X, 172), (Y, -36)), sag=-46)), (1.0, coil)], 1.0,
               loop=True, chains=chains)
    over = hang(m(REST, spine=[(X, 4), (Y, -8)], chest=[(X, 0), (Y, -4)], clav_r=[(Z, 12)], upper_r=[(X, -150), (Z, 10)], fore_r=[(X, -10)],
                  upper_l=[(X, -30), (Z, -20)]), ((X, 200),), sag=-20)
    fling = hang(m(REST, spine=[(X, 22), (Y, 10)], chest=[(X, 10), (Y, 8)], head=[(X, -6)], upper_r=[(X, -80), (Z, 6)], fore_r=[(X, -10)],
                   upper_l=[(X, 20), (Z, -24)], fore_l=[(X, -30)], thigh_r=[(X, -26)], shin_r=[(X, 30)], thigh_l=[(X, 20)], shin_l=[(X, 12)]),
                 ((X, 270),), sag=12)
    slam = hang(m(fling, spine=[(X, 26), (Y, 12)], upper_r=[(X, -55), (Z, 6)], pelvis=[(X, 6)]), ((X, 292),), sag=24)
    K.key_clip(arm, "strike", [(0.0, coil), (0.08, over), (0.16, fling), (0.26, slam), (0.7, hang(m(slam, spine=[(X, 24)]), ((X, 300),), sag=8)),
                               (1.3, hang(m(REST, spine=[(X, 14)]), ((X, 345),), sag=0)), (1.6, rest)], 1.6, chains=chains)
    # stagger, howl (the generic cry), death
    reel = hang(m(REST, spine=[(X, -14), (Z, 8)], chest=[(X, -12)], head=[(X, -22), (Z, 10)], upper_r=[(X, 6), (Z, 22)], upper_l=[(X, 10), (Z, -30)]), ((X, -20),))
    slump = hang(m(REST, spine=[(X, 28)], chest=[(X, 22)], head=[(X, 30)], thigh_r=[(X, -20)], shin_r=[(X, 40)], thigh_l=[(X, -10)], shin_l=[(X, 30)]))
    K.key_clip(arm, "stagger", [(0.0, rest), (0.12, reel), (0.6, slump), (1.3, m(slump, head=[(X, 22), (Y, 12)])), (1.8, rest)], 1.8, chains=chains)
    cry = hang(m(REST, spine=[(X, -10)], chest=[(X, -16)], neck=[(X, -18)], head=[(X, -28)], clav_l=[(Z, -14)], upper_l=[(X, -110), (Z, -30)],
                 fore_l=[(X, -20)], upper_r=[(X, -30), (Z, 14)]))
    K.key_clip(arm, "howl", [(0.0, rest), (0.4, hang(m(REST, spine=[(X, 16)], chest=[(X, 18)]))), (0.9, cry), (1.6, hang(m(cry, head=[(X, -34)]))), (2.0, rest)], 2.0, chains=chains)
    kneel = hang(m(REST, spine=[(X, 30)], chest=[(X, 20)], head=[(X, 30)], upper_r=[(X, -20)], thigh_r=[(X, -80)], shin_r=[(X, 110)],
                   thigh_l=[(X, -60)], shin_l=[(X, 120)]))
    down = hang(m(kneel, spine=[(X, 44)], chest=[(X, 22)], head=[(X, 20)], upper_l=[(X, -60)], upper_r=[(X, -60)]))
    K.key_clip(arm, "death", [(0.0, rest), (0.5, slump), (1.3, kneel), (2.1, down), (2.8, down)], 2.8, chains=chains,
               root_keys=[(0.0, (0, 0, 0)), (0.5, (0, -0.05, 0)), (1.3, (0, -0.32, 0)), (2.1, (0, -0.42, -0.2)), (2.8, (0, -0.44, -0.22))])
    # Chain Ring (1.7 s; the ring lands at 1.55): the anchor drawn out to her right and whirled round her once and a half
    out_r = hang(m(REST, spine=[(X, 6), (Y, -18)], chest=[(Y, -12)], clav_r=[(Z, 18)], upper_r=[(X, -20), (Z, 70)], fore_r=[(X, -10)],
                   thigh_l=[(X, -10)]), ((Z, 60),), sag=10)
    def whirl(a, lean):
        return hang(m(REST, spine=[(X, -4), (Y, a * 0.25)], chest=[(Y, a * 0.15), (Z, -lean)], head=[(Y, -a * 0.1)], clav_r=[(Z, 20)],
                      upper_r=[(X, -10), (Z, 80)], fore_r=[(X, -6)], upper_l=[(X, -20), (Z, -30)]), ((Z, 85), (Y, a)), sag=-8)
    K.key_clip(arm, "chain_ring", [(0.0, rest), (0.6, out_r), (0.95, whirl(0, 6)), (1.15, whirl(90, 8)), (1.3, whirl(180, 10)), (1.45, whirl(270, 10)),
                                   (1.55, whirl(360, 8)), (1.75, whirl(450, 6)), (2.1, hang(m(REST, spine=[(X, 14)]), ((Z, 20),), sag=10)), (2.6, rest)],
               2.6, chains=cloth + swingers[1:])
    # Toll of the Cell (2.4 s): the lantern lifted high to the cells, the other hand at her breast, the head thrown back
    lift_l = hang(m(REST, spine=[(X, -6)], chest=[(X, -12)], neck=[(X, -10)], head=[(X, -24)], clav_l=[(Z, -18)], upper_l=[(X, -160), (Z, -12)],
                    fore_l=[(X, -10)], upper_r=[(X, -40), (Z, -10)], fore_r=[(X, -100)]))
    shake = hang(m(lift_l, chest=[(X, -14), (Z, 2)], head=[(X, -28), (Z, -4)], upper_l=[(X, -164), (Z, -16)]))
    K.key_clip(arm, "toll", [(0.0, rest), (0.6, lift_l), (1.2, shake), (1.7, lift_l), (2.2, shake), (2.4, lift_l), (3.1, rest)], 3.1, chains=chains)
    # Rockfall (the stones answer at 1.1 s): she lifts a foot and stamps, the whole body jolting
    raise_f = hang(m(REST, spine=[(X, -4)], chest=[(X, -6)], head=[(X, -10)], thigh_r=[(X, -36)], shin_r=[(X, 40)], upper_r=[(Z, 18)],
                     upper_l=[(Z, -20)], fore_l=[(X, -50)]), ((X, 8),))
    stamp = hang(m(REST, spine=[(X, 26)], chest=[(X, 22)], head=[(X, 18)], thigh_r=[(X, -14)], shin_r=[(X, 18)], thigh_l=[(X, -12)], shin_l=[(X, 20)],
                   upper_r=[(Z, 10)]), sag=10)
    K.key_clip(arm, "rockfall", [(0.0, rest), (0.7, raise_f), (1.0, hang(m(raise_f, thigh_r=[(X, -40)]), ((X, 10),))), (1.1, stamp),
                                 (1.3, hang(m(stamp, spine=[(X, 30)]), sag=16)), (1.9, rest)], 1.9, chains=chains,
               root_keys=[(0.0, (0, 0, 0)), (1.0, (0, 0.02, 0)), (1.1, (0, -0.04, 0)), (1.3, (0, -0.05, 0)), (1.9, (0, 0, 0))])
    # The Undertow (3.4 s): both hands on the chain, leaning back and hauling it in hand over hand, a last heave
    def haul(k, deep):
        return hang(m(REST, pelvis=[(X, -6)], spine=[(X, -14 - deep)], chest=[(X, -6 - deep * 0.5), (Y, 6 * k)], head=[(X, 14)],
                      upper_r=[(X, -18 + 8 * k), (Z, -14)], fore_r=[(X, -22)], upper_l=[(X, -24 - 8 * k), (Z, 22)], fore_l=[(X, -40)],
                      thigh_r=[(X, -22)], shin_r=[(X, 22)], thigh_l=[(X, 16)], shin_l=[(X, 8)]), ((X, -58 + 5 * k),), sag=10)
    K.key_clip(arm, "undertow", [(0.0, rest), (0.5, haul(1, 0)), (1.0, haul(-1, 8)), (1.5, haul(1, 4)), (2.0, haul(-1, 12)), (2.5, haul(1, 8)),
                                 (3.0, haul(-1, 18)), (3.4, haul(1, 24)), (4.1, rest)], 4.1, chains=chains,
               root_keys=[(0.0, (0, 0, 0)), (1.0, (0, 0, 0.04)), (2.0, (0, 0, 0.08)), (3.4, (0, -0.03, 0.12)), (4.1, (0, 0, 0))])


def main():
    K.clear_scene()
    g = build_body()
    ob = K.make_object(g, "Anchoress", subdiv=0)
    arm = K.build_armature(BONES, "AnchoressRig")
    K.bind(ob, arm)
    print("VB TRIS", sum(len(p.vertices) - 2 for p in ob.data.polygons))
    if DO_AO:
        K.bake_ao_alpha(ob)
    clips(arm)
    K.export_glb(arm, ob, OUT)
    if RENDERS:
        K.review_renders(arm, ob, RENDERS, "anch", 1.85, poses=[("windup", 1.0, 70.0), ("strike", 0.16, 70.0), ("strike", 0.26, 60.0),
                                                                 ("chain_ring", 1.15, 30.0), ("chain_ring", 1.45, 30.0), ("toll", 1.2, 20.0),
                                                                 ("rockfall", 0.9, 60.0), ("undertow", 2.0, 60.0), ("walk", 0.4, 60.0),
                                                                 ("death", 2.8, 60.0)])
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(K.ROOT, "art/blender/vb_anchoress.blend"))


main()
