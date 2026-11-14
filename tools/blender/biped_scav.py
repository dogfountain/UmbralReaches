"""Scavenger bipeds (r38 remodel): wretch and gaunt. A starved body WITH muscle on it (deltoid, biceps, forearm, quadriceps,
calf, sculpted onto the fused surface: biped_body.body(extra=)), dressed in clothes cut from the body's own surface
(biped_sculpt_lib.shell): a torn tunic with sleeves, ragged trousers, wrapped forearms and calves, leather straps that
lie on the skin; and the WRETCH carries its whole life on its back (a lumpy sack hung from the straps, a bedroll tied on top,
a pot, bones, a skull, rope), a rusted gaff in the left fist, lank hair. The GAUNT is the same starved frame stripped:
ribs and spine standing out, a mourning veil and shawl in strips, long bound hands, nothing on its back.

  GRUNT_OUT=<dir> tools/blender/run.sh biped_scav.py -- --kind wretch [--preview /tmp/w.png] [--no-export]
"""
import bpy
import bmesh
import math
import os
import sys
import numpy as np
from mathutils import Vector, noise

sys.path.insert(0, os.path.dirname(__file__))
import boss_kit as K
import grunt_kit as GK
import biped_sculpt_lib as L
import biped_body as BB
import biped_weights as BW
from boss_kit import G

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
KIND = args[args.index("--kind") + 1] if "--kind" in args else "wretch"
PREVIEW = args[args.index("--preview") + 1] if "--preview" in args else ""
EXPORT = "--no-export" not in args

K.reset()
BB.fast_ao(16)
BB.lean()
S = dict(K.SOCKETS)
sm = L.smooth
GAUNT = KIND == "gaunt"

SKIN = GK.hollow_skin("Skin", (0.22, 0.19, 0.14) if not GAUNT else (0.3, 0.3, 0.32), (0.06, 0.05, 0.035) if not GAUNT else (0.07, 0.07, 0.09), wet=0.05, wrinkle=62.0,
                      vein_amt=0.55, liv=(0.88, 0.72, 0.8), extremities=0.65)
FACE = GK.hollow_skin("Face", (0.25, 0.22, 0.16) if not GAUNT else (0.34, 0.34, 0.36), (0.075, 0.066, 0.05), wet=0.15, wrinkle=90.0, liv=(0.88, 0.72, 0.8), extremities=0.0,
                      face_fade=((0.22, 0.19, 0.14), 1.6, 1.69))
CLAW = GK.grave_bone("Claw", (0.34, 0.3, 0.24), (0.1, 0.07, 0.05), 12.0)
EYE = GK.glow("Eye", (1.0, 0.36, 0.08) if not GAUNT else (0.6, 0.75, 1.0), 8.0)
TUNIC = GK.cloth("Tunic", (0.13, 0.1, 0.075) if not GAUNT else (0.07, 0.07, 0.085), "rough_linen", 7.0, (0.04, 0.03, 0.02), 0.9)
RAG = GK.cloth("Cloth", (0.09, 0.075, 0.065) if not GAUNT else (0.12, 0.12, 0.14), "rough_linen", 7.0)
WRAP = GK.cloth("Wrap", (0.3, 0.26, 0.19) if not GAUNT else (0.2, 0.2, 0.23), "rough_linen", 18.0, (0.1, 0.08, 0.05), 0.9)
SACK = GK.cloth("Sack", (0.1, 0.075, 0.05), "rough_linen", 6.0, (0.02, 0.015, 0.01), 0.92)
HAIR = GK.cloth("Hair", (0.035, 0.03, 0.03), "rough_linen", 30.0, (0.01, 0.01, 0.01), 0.8)
LEATHER = GK.leather("Leather", (0.14, 0.09, 0.06))
IRON = GK.iron("Iron", (0.12, 0.11, 0.11), (0.17, 0.085, 0.05))
BONE = GK.grave_bone("Bone", (0.6, 0.55, 0.44), (0.2, 0.15, 0.1))
WOOD = GK.wood("Wood", (0.16, 0.1, 0.06), 0.7)
MATS = [SKIN, FACE, CLAW, EYE, TUNIC, RAG, WRAP, SACK, HAIR, LEATHER, IRON, BONE, WOOD]

if GAUNT:
    OPT = dict(W=0.8, L=0.95, nk=0.12, finger=0.3, wrist=0.58, ribs=0.0115, belly=-1.0, collar=1.8, tendon=1.8, hc=(0, 1.7, -0.14), jaw_w=0.038, brow=0.015,
               waist=0.82, head_w=0.068, neck_r=0.04, hump=0.04)
else:
    OPT = dict(W=0.88, L=1.1, nk=0.1, finger=0.26, wrist=0.6, ribs=0.0075, belly=-1.0, collar=1.5, tendon=1.6, hc=(0, 1.7, -0.135), jaw_w=0.04, brow=0.014,
               waist=0.9, head_w=0.072, neck_r=0.044, hump=0.055)
HC = OPT["hc"]
LL = OPT["L"]


def muscle(sc, Y, nm):
    """Stringy muscle on a starved frame: it is what stops the limbs reading as rods."""
    both = (-1, 1)
    k = 0.8 if GAUNT else 1.0
    if nm == "Arms":
        sc.bump((0.26, Y(1.38), 0.0), 0.06, 0.013 * k, facing=(1, 0.4, 0), sx=both)           # deltoid
        sc.bump((0.255, Y(1.23), -0.03), 0.05, 0.012 * k, facing=(0.3, 0, -1), sx=both)       # biceps
        sc.bump((0.255, Y(1.2), 0.035), 0.05, 0.01 * k, facing=(0.3, 0, 1), sx=both)          # triceps
        sc.bump((0.258, Y(0.97), -0.012), 0.05, 0.012 * k, facing=(0.5, 0, -1), sx=both)      # forearm flexors
        sc.bump((0.268, Y(0.95), 0.015), 0.04, 0.008 * k, facing=(1, 0, 0.4), sx=both)        # brachioradialis
    else:
        sc.bump((0.12, 0.58, -0.035), 0.085, 0.015 * k, facing=(0.3, 0, -1), sx=both)          # quadriceps
        sc.bump((0.125, 0.6, 0.04), 0.08, 0.011 * k, facing=(0.3, 0, 1), sx=both)             # hamstrings
        sc.bump((0.115, 0.23, 0.03), 0.065, 0.02 * k, facing=(0.2, 0, 1), sx=both)            # calf
        sc.bump((0.1, 0.84, 0.07), 0.07, 0.014 * k, facing=(0, 0, 1), sx=both)                # glutes
        sc.bump((0.0, Y(1.46), 0.07), 0.12, 0.014, facing=(0, 0.3, 1))                         # trapezius / hump
        sc.bump((0.1, Y(1.36), -0.085), 0.07, 0.007 * k, facing=(0, 0, -1), sx=both)          # a stringy pectoral


ctx = BB.body(OPT, SKIN, CLAW, EYE, claw=0.15 if not GAUNT else 0.18, extra=muscle, body_tris=4200, arm_tris=1600)
objs, PAIRS = ctx.objs, ctx.pairs
WTS = BW.base_weights(ctx, S, neck=OPT["nk"])
HB, HA = ctx.hi["Body"], ctx.hi["Arms"]
WTS["skirt"] = BW.skirt_weights(WTS, y_hip=0.9, y_knee=0.45, spread=0.8, knee_part=0.5, torso_from=0.95)


def add(o, sock=None):
    if sock:
        o["sock"] = sock
    objs.append(o)
    return o


def ang_noise(th, y, seed, amp):
    return amp * (0.55 * np.sin(th * 5 + seed) + 0.3 * np.sin(th * 11 + seed * 2.1 + y * 3) + 0.2 * np.sin(th * 23 + seed * 3.7) + 0.1 * np.sin(th * 47 + seed))


def cloth_shell(src, name, y0, y1, off, thick, mat, sock, tris, seed=1.0, ragged_bottom=0.05, ragged_top=0.0, xmin=None, sx=1, folds_amp=0.006, tail=0.0, neck_v=False):
    """A garment band round the body between heights y0 and y1 with torn edges (noise in the selection)."""
    def sel(P, N):
        th = np.arctan2(P[:, 0], -P[:, 2])
        lo = y0 + ang_noise(th, P[:, 1], seed, ragged_bottom) + tail * np.clip(-N[:, 2] * 0.0 + (P[:, 2] > 0) * 0.5, 0, 1)
        hi = y1 + ang_noise(th, P[:, 1], seed + 3.0, ragged_top)
        f = np.minimum(P[:, 1] - lo, hi - P[:, 1])
        if xmin is not None:
            f = np.minimum(f, P[:, 0] * sx - xmin)
        if neck_v:                                                   # a V neckline in front
            f = np.minimum(f, np.where(P[:, 2] < 0.0, (1.5 - np.abs(P[:, 0]) * 3.2) * 0.0 + (1.47 - P[:, 1]) + np.abs(P[:, 0]) * 2.5 - 0.0, 1.0))
        return f

    def fold(P, N):
        th = np.arctan2(P[:, 0], -P[:, 2])
        t = sm(y1, y0, P[:, 1])
        return folds_amp * (0.3 + t) * (np.sin(th * 9 + 3.0 * P[:, 1] + seed) + 0.5 * np.sin(th * 21 + P[:, 1] * 6 + seed * 2)) + 0.0015 * L.hash_noise(P, 26.0, seed)
    hi = L.shell(src, name + "High", sel, off, thick, mat, sock, folds=fold, smooth_iter=3)
    return L.hi_lo(hi, tris, name + "Low", sock, PAIRS, objs)


def wrap_shell(src, name, y0, y1, xs, off, mat, sock, tris, turns=7.0, sx=1):
    """Bandage wound round a limb: a band whose surface carries a spiral ridge."""
    def sel(P, N):
        return np.where(P[:, 0] * sx > xs, np.minimum(P[:, 1] - y0, y1 - P[:, 1]), -1.0)

    def fold(P, N):
        th = np.arctan2(P[:, 0] - sx * xs * 0.0 - sx * 0.0, P[:, 2] * 0.0 - P[:, 2] + 1e-9)
        ph = (P[:, 1] - y0) / (y1 - y0) * turns * math.tau + np.arctan2(P[:, 2], P[:, 0] - sx * 0.25 if src is HA else P[:, 0] - sx * 0.11)
        return 0.0035 * (np.abs(np.sin(ph * 0.5)) - 0.5) + 0.0012 * L.hash_noise(P, 40.0, 2.0)
    hi = L.shell(src, name + "High", sel, off, 0.004, mat, sock, folds=fold, smooth_iter=2)
    return L.hi_lo(hi, tris, name + "Low", sock, PAIRS, objs)


def strap_shell(src, name, pts, w, off, mat, sock, tris, thick=0.004):
    """A strap lying on the body along a rig-space polyline, w wide."""
    pts = np.array(pts, dtype=np.float32)

    def sel(P, N):
        d = np.full(len(P), 9.0, dtype=np.float32)
        for a, b in zip(pts[:-1], pts[1:]):
            ab = b - a
            t = np.clip(((P - a) @ ab) / max(float(ab @ ab), 1e-9), 0.0, 1.0)
            d = np.minimum(d, np.linalg.norm(P - (a + t[:, None] * ab), axis=1))
        return w - d
    hi = L.shell(src, name + "High", sel, off, thick, mat, sock, smooth_iter=2)
    return L.hi_lo(hi, tris, name + "Low", sock, PAIRS, objs)


# --- clothes cut from the body ----------------------------------------------------------------------------------------------------
if GAUNT:
    cloth_shell(HB, "Loin", 0.7, 0.98, 0.016, 0.005, RAG, "bodyskin", 700, seed=2.0, ragged_bottom=0.08, tail=0.1)         # a rag round the hips, torn up the thigh
    cloth_shell(HB, "Shawl", 1.38, 1.5, 0.014, 0.005, RAG, "bodyskin", 450, seed=5.0, ragged_bottom=0.07, ragged_top=0.01)      # the ribs stay bare under it
else:
    # a sleeveless shirt, hanging loose and torn (it flares away from the hips), a skirt of rag strips below it
    cloth_shell(HB, "Tunic", 0.93, 1.45, lambda P, N: 0.013 + 0.06 * sm(1.22, 0.93, P[:, 1]), 0.005, TUNIC, "bodyskin", 1300, seed=2.0, ragged_bottom=0.11, ragged_top=0.012, folds_amp=0.012, neck_v=True)
    for k in range(17):
        ang = math.tau * k / 17.0 + 0.25 * noise.noise(Vector((k, 5.0, 0)))
        root = Vector(G(math.cos(ang) * 0.17, 0.96 - 0.015 * (k % 2), math.sin(ang) * 0.14))
        out = Vector((math.cos(ang), -math.sin(ang), 0.0))
        front = max(0.0, math.sin(ang))
        Ln = 0.22 + 0.16 * (0.5 + 0.5 * noise.noise(Vector((k * 1.3, 2.0, 0)))) + 0.08 * front
        pts = [root + out * (0.005 + 0.035 * t * t) + Vector((0, 0, -Ln * t)) + out * 0.01 * math.sin(t * 5.0 + k) for t in [i / 7.0 for i in range(8)]]
        add(GK.strip("Rag", pts, 0.07 + 0.015 * (k % 3), 0.006, "skirt", RAG, taper=0.6), "skirt")
for sx in (-1, 1):
    wrap_shell(HA, "ArmWrap", 0.74, 0.92, 0.17, 0.009, WRAP, "armskin", 320, turns=8.0, sx=sx)
    wrap_shell(HB, "ShinWrap", 0.04, 0.3, 0.02, 0.011, WRAP, "bodyskin", 300, turns=7.0, sx=sx)
if not GAUNT:
    for sx in (-1, 1):                      # straps over the shoulders and round under the arms to the sack
        strap_shell(HB, "StrapF", [(sx * 0.1, 1.5, 0.0), (sx * 0.12, 1.45, -0.09), (sx * 0.14, 1.28, -0.12), (sx * 0.15, 1.16, -0.06)], 0.022, 0.026, LEATHER, "r:chest", 320)
        strap_shell(HB, "StrapB", [(sx * 0.1, 1.5, 0.0), (sx * 0.11, 1.42, 0.1), (sx * 0.12, 1.2, 0.12), (sx * 0.14, 1.05, 0.11)], 0.022, 0.026, LEATHER, "r:chest", 300)
    strap_shell(HB, "Belt", [(-0.2, 0.97, -0.12), (0.0, 0.97, -0.18), (0.2, 0.97, -0.12), (0.2, 0.97, 0.1), (-0.2, 0.97, 0.1), (-0.2, 0.97, -0.12)], 0.025, 0.032, LEATHER, "r:pelvis", 500, thick=0.006)

# --- hair / veil -----------------------------------------------------------------------------------------------------------------------
Hc = Vector(G(*HC))
if not GAUNT:
    for k in range(22):                                                     # lank hair: flat locks from the crown, falling past the shoulders
        ang = -2.5 + 5.0 * k / 21.0 + 0.06 * noise.noise(Vector((k, 0, 0)))
        root = Hc + Vector((math.sin(ang) * 0.075, -math.cos(ang) * 0.055 - 0.01, 0.075 - 0.03 * abs(math.sin(ang))))
        out = Vector((math.sin(ang) * 0.5, -abs(math.cos(ang)) * 0.4 - 0.15, -1.0)).normalized()
        Ln = 0.3 + 0.16 * (0.5 + 0.5 * noise.noise(Vector((k * 0.7, 3.0, 0))))
        pts = []
        for j in range(8):
            t = j / 7.0
            wob = Vector((noise.noise(Vector((k, t * 3, 1))), noise.noise(Vector((k, t * 3, 2))), 0)) * 0.03 * t
            pts.append(root + out * Ln * t + Vector((0, -0.04 * t * t, 0)) + wob)
        add(GK.strip("Hair", pts, 0.022, 0.006, "r:head", HAIR, taper=0.75), "r:head")
else:
    for k in range(20):                                                     # a mourning veil: pale strips from the crown, falling behind and to the sides, the face bare
        ang = -2.6 + 5.2 * k / 19.0 + 0.06 * noise.noise(Vector((k, 0, 0)))
        root = Hc + Vector((math.sin(ang) * 0.075, -math.cos(ang) * 0.055 - 0.01, 0.075 - 0.03 * abs(math.sin(ang))))
        out = Vector((math.sin(ang) * 0.5, -abs(math.cos(ang)) * 0.4 - 0.15, -1.0)).normalized()
        Ln = 0.34 + 0.2 * (0.5 + 0.5 * noise.noise(Vector((k * 0.9, 3.0, 0))))
        pts = [root + out * Ln * t + Vector((0, -0.04 * t * t, 0)) + Vector((noise.noise(Vector((k, t * 3, 1))), 0, noise.noise(Vector((k, t * 3, 2))))) * 0.04 * t for t in [i / 7.0 for i in range(8)]]
        add(GK.strip("Veil", pts, 0.04, 0.004, "r:head", RAG, taper=0.7), "r:head")

# --- what the wretch carries ---------------------------------------------------------------------------------------------------------------
if not GAUNT:
    def lumpy(c):
        p = Vector(c)
        return p + p.normalized() * 0.3 * noise.noise(p * 2.1 + Vector((3.0, 1.0, 2.0)))
    # the sack: a gathered, lumpy bag hung from the straps, its neck tied; a second small one beneath
    sack = L.lathe("Sack", [(0.0, -0.3), (0.12, -0.28), (0.2, -0.2), (0.25, -0.05), (0.24, 0.1), (0.19, 0.24), (0.11, 0.34), (0.06, 0.4), (0.065, 0.43), (0.085, 0.49)],
                   (0.03, 0.98, 0.27), SACK, "r:chest", nth=44, wobble=0.26, seed=2.0, fold=0.09, fold_n=5, thick=0.006, ellip=(1.12, 0.9))
    rngs = np.random.RandomState(3)
    lumps = [(np.array([0.03 + rngs.uniform(-0.2, 0.2), 0.98 + rngs.uniform(-0.25, 0.2), 0.27 + rngs.uniform(0.0, 0.2)]), rngs.uniform(0.05, 0.09), rngs.uniform(0.02, 0.045)) for _ in range(9)]

    def sack_form(P, N):                                   # what is in it pushes the cloth out; the cloth sags and creases between
        d = 0.012 * L.hash_noise(P, 22.0, 5.0) + 0.016 * L.hash_noise(P * np.array([1.0, 3.0, 1.0]), 9.0, 2.0)
        for c, r, a in lumps:
            d = d + a * L.gauss(P, c, r)
        th = np.arctan2(P[:, 0] - 0.03, P[:, 2] - 0.27)
        d = d + 0.014 * np.sin(th * 7 + P[:, 1] * 5.0) * sm(1.2, 1.45, P[:, 1])               # pleats gathering into the neck
        return d
    L.displace(sack, sack_form)
    L.smooth_shade(sack)
    add(sack, "r:chest")
    add(K.blob("Sack", Vector(G(-0.08, 0.93, 0.3)), (0.09, 0.08, 0.1), "r:chest", SACK, 24, 12, lumpy), "r:chest")
    add(L.band_loop("Tie", (0.03, 1.4, 0.27), 0.065, 0.058, 0.011, LEATHER, "r:chest", n=20, sides=6), "r:chest")      # the neck of the sack, tied
    add(K.loft("Knot", [Vector(G(0.03, 1.39, 0.2)), Vector(G(0.03, 1.31, 0.17))], [0.012, 0.01], "r:chest", LEATHER, 5), "r:chest")
    # a bedroll tied across the top, its ties
    add(K.loft("Roll", [Vector(G(-0.27, 1.5, 0.19)), Vector(G(0.0, 1.52, 0.21)), Vector(G(0.27, 1.5, 0.19))], [0.07, 0.078, 0.07], "r:chest", WRAP, 14), "r:chest")
    for x in (-0.16, 0.16):
        add(K.loft("RollTie", [Vector(G(x, 1.5 + 0.08 * math.cos(a), 0.2 + 0.08 * math.sin(a))) for a in [math.tau * i / 14 for i in range(15)]], [(0.01, 0.006)] * 15, "r:chest", LEATHER, 5), "r:chest")
    # things hung on it: bones jutting over the shoulder, a skull tied on, a pot and a chain
    for k, (dx, h, lean) in enumerate(((0.0, 0.52, -0.25), (0.05, 0.4, 0.3), (-0.04, 0.3, -0.7))):
        a = Vector(G(0.04 + dx * 0.4, 1.5, 0.24))
        add(K.bone("Bone", a, a + Vector(G(dx + lean * 0.14, h, 0.03)), 0.012 + 0.002 * k, "r:chest", BONE, 1.9, 8, 8, k), "r:chest")
    add(K.blob("Skull", Vector(G(0.2, 1.2, 0.34)), (0.055, 0.06, 0.07), "r:chest", BONE, 22, 14), "r:chest")
    for sx in (-1, 1):
        add(K.blob("Eye", Vector(G(0.2 + sx * 0.02, 1.22, 0.4)), (0.011, 0.006, 0.012), "r:chest", EYE, 10, 6), "r:chest")
    add(K.blob("Pot", Vector(G(-0.2, 0.88, 0.28)), (0.075, 0.075, 0.07), "r:chest", IRON, 20, 12), "r:chest")
    add(K.loft("PotRim", [Vector(G(-0.2 + 0.075 * math.cos(a), 0.95, 0.28 + 0.075 * math.sin(a))) for a in [math.tau * i / 20 for i in range(21)]], [(0.01, 0.006)] * 21, "r:chest", IRON, 5), "r:chest")
    add(GK.chain_links("Chain", [Vector(G(-0.2, 0.95, 0.28)), Vector(G(-0.17, 1.1, 0.26)), Vector(G(-0.12, 1.24, 0.22))], 0.009, "r:chest", IRON), "r:chest")
    # the gaff: a long ash shaft through the left fist, a rusted iron hook bound on with cord
    Hl = S["hand_l"]
    add(K.loft("Wood", [Hl + G(0, 0.14, -0.035), Hl + G(0.004, -0.2, -0.035), Hl + G(0.0, -0.52, -0.035)], [0.018, 0.017, 0.015], "r:hand_l", WOOD, 8, wobble=0.06), "r:hand_l")
    hk = [Hl + G(0.0, -0.52 - 0.12 * math.sin(a), -0.035 - 0.12 * (1.0 - math.cos(a))) for a in [-0.3 + 3.6 * i / 10.0 for i in range(11)]]
    add(K.curve_tube("Iron", hk, 0.018, "r:hand_l", IRON, [1.0 - 0.9 * (i / 10.0) ** 1.6 for i in range(11)]), "r:hand_l")
    add(K.blob("Collar", Hl + G(0.0, -0.5, -0.035), (0.028, 0.034, 0.028), "r:hand_l", IRON, 12, 8), "r:hand_l")
    for k in range(5):
        add(K.loft("Bind", [Hl + G(0.03, -0.45 - 0.014 * k, -0.035), Hl + G(-0.03, -0.46 - 0.014 * k, -0.035)], [(0.01, 0.008)] * 2, "r:hand_l", LEATHER, 5), "r:hand_l")
    # a cord belt hung with teeth
    for k in range(9):
        a = math.tau * (k + 0.5) / 9.0
        root = Vector(G(math.cos(a) * 0.2, 0.96, math.sin(a) * 0.16))
        add(GK.claw("Tooth", root, Vector(G(math.cos(a) * 0.2, -1.0, math.sin(a) * 0.2)), 0.05 + 0.02 * (k % 3), 0.009, "r:pelvis", BONE, 0.2), "r:pelvis")
    # bone spurs off both elbows
    for tag, sx in (("l", -1), ("r", 1)):
        add(GK.claw("Spur", S["elbow_" + tag] + G(sx * 0.03, 0.0, 0.03), G(sx * 0.35, 0.3, 1.0), 0.14, 0.014, "arm_" + tag, CLAW, -0.15), "arm_" + tag)
else:
    # a rag shawl in strips from the shoulders, trailing behind; a cord of knuckle-bones round the neck
    for k in range(9):
        t = k / 8.0
        x = -0.2 + 0.4 * t
        root = Vector(G(x, 1.5 - 0.04 * abs(2 * t - 1), 0.06))
        Ln = 0.4 + 0.14 * (0.5 + 0.5 * noise.noise(Vector((k * 1.7, 4.0, 0)))) + 0.1 * (1.0 - abs(2 * t - 1))
        pts = [root + Vector(G(x * 0.4 * s2 * s2, -Ln * s2, 0.02 + 0.07 * math.sin(s2 * 2.6))) for s2 in [i / 7.0 for i in range(8)]]
        add(GK.strip("Shawl", pts, 0.075, 0.005, "r:chest", RAG, taper=0.65), "r:chest")
    for k in range(7):
        a = math.pi * (0.1 + 0.8 * k / 6.0)
        add(K.blob("Knuckle", Vector(G(math.cos(a) * 0.075, 1.5 - 0.04 * math.sin(a), -math.sin(a) * 0.1 - 0.02)), (0.011, 0.014, 0.011), "r:chest", BONE, 8, 6), "r:chest")
    for tag, sx in (("l", -1), ("r", 1)):                                  # bone spurs off both elbows, long
        add(GK.claw("Spur", S["elbow_" + tag] + G(sx * 0.03, 0.0, 0.03), G(sx * 0.35, 0.3, 1.0), 0.2, 0.014, "arm_" + tag, CLAW, -0.15), "arm_" + tag)

if PREVIEW:
    L.preview_sheet(PREVIEW, 0.95, 3.3)
L.report(objs)
print("BIPED", KIND, "parts", len(objs), "tris", sum(L.tri_count(o) for o in objs if o.type == 'MESH'))
if EXPORT:
    GK.export_skinned(objs, MATS, "grunt_" + KIND, S, WTS, {}, 2048, 16500, pairs=PAIRS)
