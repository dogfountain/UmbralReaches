"""The hollowed flesh bipeds (remodel, round two): wretch, gaunt, husk, spitter. Each has a body DESIGNED for what it is (torso
keys, a dragged shoulder, a collapsed or caged chest, a pot belly, long knotted hands), with anatomy sculpted into the fused
surface (biped_anat: muscle, joints, tendon, scars, pits) and its clothes cut from that surface (biped_sculpt_lib):

  WRETCH   a starved scavenger bent under its load: collapsed chest, pot belly, one shoulder dragged down by a strap that bites
           into it, long arms with big knotted hands, a face (brow, sunken eyes, slack jaw), lank hair from the scalp; a cloth
           sack with weight (sagging, patched, tied at the neck, things poking out), a bedroll, a pot, a gaff.
  GAUNT    taller and wrong: stretched limbs, a ribcage like a cage (bone ribs over a dark hollow), hip bones, a hollow stomach,
           hands to the knees; a ragged shroud with thickness clinging to the head and shoulders.
  HUSK     a gravedigger's corpse: vast stitched gut leaking ember, burial linen wound round it, a coffin lid and a headstone
           strapped on, an ember knot between the shoulder blades (husk.gd's weak point at chest + (0, .04, .16)).
  SPITTER  a bloated acid-fisher: wide toad head, a throat cradle of skin and iron that holds spitter.gd's sac (chest + (0,.25,-.13)),
           a pendulous bile belly, warts and a bank of glowing glands on the back, a strap harness hung with phials.

  GRUNT_OUT=<dir> tools/blender/run.sh biped_flesh.py -- --kind wretch [--preview /tmp/w.png] [--no-export]
"""
import bpy
import bmesh
import math
import os
import sys
import numpy as np
from mathutils import Vector, Quaternion, noise

sys.path.insert(0, os.path.dirname(__file__))
import boss_kit as K
import grunt_kit as GK
import grunt_body as GB
import biped_sculpt_lib as L
import biped_body as BB
import biped_weights as BW
import biped_anat as AN
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
WR, GA, HU, SP = KIND == "wretch", KIND == "gaunt", KIND == "husk", KIND == "spitter"


def fx(o):
    o["fixed"] = True
    return o


# --- design ------------------------------------------------------------------------------------------------------------------------
if WR:
    SK = ((0.3, 0.25, 0.18), (0.035, 0.028, 0.02)); EYEC = (1.0, 0.36, 0.08)
    KEYS = [(0.775, 0, 0.0, 0.06, 0.05, 0.05, 2.0), (0.81, 0, 0.0, 0.105, 0.075, 0.085, 2.2), (0.88, 0, 0.005, 0.13, 0.095, 0.11, 2.3),
            (0.97, 0, 0.0, 0.125, 0.13, 0.1, 2.2), (1.05, 0, -0.005, 0.12, 0.165, 0.095, 2.0), (1.12, 0, -0.005, 0.115, 0.15, 0.09, 2.0),
            (1.2, 0, 0.005, 0.115, 0.1, 0.1, 2.05), (1.3, 0, 0.02, 0.125, 0.07, 0.125, 2.1), (1.4, 0, 0.035, 0.135, 0.066, 0.145, 2.25),
            (1.465, 0, 0.045, 0.13, 0.062, 0.155, 2.2), (1.5, 0, 0.035, 0.1, 0.058, 0.13, 2.0), (1.53, 0, 0.0, 0.075, 0.055, 0.1, 2.0),
            (1.57, 0, -0.05, 0.05, 0.05, 0.06, 2.0), (1.62, 0, -0.09, 0.043, 0.043, 0.047, 2.0)]
    OPT = dict(W=0.9, L=1.1, nk=0.1, finger=0.3, hand_r=1.9, wrist=0.56, ribs=0.0105, belly=1.2, collar=1.7, tendon=1.9, hc=(0, 1.69, -0.15), jaw_w=0.04, jaw_out=0.03,
               brow=0.02, waist=0.9, head_w=0.074, neck_r=0.044, hump=0.06, torso=KEYS, cavity=0.02)
elif GA:
    SK = ((0.34, 0.34, 0.37), (0.03, 0.03, 0.042)); EYEC = (0.6, 0.75, 1.0)
    KEYS = [(0.775, 0, 0.0, 0.055, 0.045, 0.045, 2.0), (0.81, 0, 0.0, 0.1, 0.06, 0.07, 2.2), (0.88, 0, 0.005, 0.125, 0.07, 0.09, 2.3),
            (0.97, 0, 0.0, 0.105, 0.065, 0.08, 2.1), (1.05, 0, 0.0, 0.085, 0.05, 0.07, 2.0), (1.14, 0, 0.0, 0.1, 0.06, 0.075, 2.0),
            (1.24, 0, 0.0, 0.128, 0.11, 0.095, 2.0), (1.33, 0, 0.01, 0.14, 0.125, 0.105, 2.05), (1.41, 0, 0.012, 0.145, 0.105, 0.105, 2.2),
            (1.465, 0, 0.02, 0.13, 0.075, 0.095, 2.2), (1.5, 0, 0.015, 0.1, 0.062, 0.085, 2.0), (1.53, 0, -0.01, 0.065, 0.05, 0.065, 2.0),
            (1.58, 0, -0.07, 0.04, 0.04, 0.045, 2.0), (1.62, 0, -0.11, 0.037, 0.037, 0.04, 2.0)]
    OPT = dict(W=0.8, L=0.85, nk=0.14, finger=0.36, hand_r=1.5, wrist=0.46, ribs=0.0, belly=-1.6, collar=1.9, tendon=2.1, hc=(0, 1.7, -0.17), jaw_w=0.036, brow=0.018,
               waist=0.75, head_w=0.066, neck_r=0.038, hump=0.03, torso=KEYS, cavity=0.03)
elif HU:
    SK = ((0.2, 0.19, 0.17), (0.022, 0.02, 0.018)); EYEC = (1.0, 0.5, 0.12)
    KEYS = [(0.775, 0, 0.0, 0.08, 0.07, 0.07, 2.0), (0.81, 0, 0.0, 0.15, 0.11, 0.11, 2.2), (0.88, 0, 0.005, 0.215, 0.15, 0.14, 2.3),
            (0.97, 0, -0.01, 0.225, 0.22, 0.13, 2.2), (1.05, 0, -0.02, 0.23, 0.27, 0.125, 2.1), (1.14, 0, -0.02, 0.225, 0.25, 0.125, 2.1),
            (1.24, 0, -0.005, 0.235, 0.19, 0.135, 2.05), (1.33, 0, 0.01, 0.25, 0.16, 0.145, 2.1), (1.41, 0, 0.015, 0.26, 0.135, 0.145, 2.25),
            (1.465, 0, 0.02, 0.24, 0.105, 0.135, 2.2), (1.495, 0, 0.012, 0.19, 0.09, 0.115, 2.0), (1.525, 0, -0.01, 0.125, 0.075, 0.095, 2.0),
            (1.56, 0, -0.03, 0.08, 0.07, 0.08, 2.0), (1.62, 0, -0.05, 0.065, 0.06, 0.066, 2.0)]
    OPT = dict(W=1.3, L=1.45, nk=0.03, finger=0.1, hand_r=1.4, wrist=0.72, ribs=0.0, belly=1.0, collar=0.5, tendon=0.8, hc=(0, 1.62, -0.07), jaw_w=0.06, jaw_out=0.02,
               brow=0.016, waist=1.25, head_w=0.074, neck_r=0.06, depth=1.2, torso=KEYS)
else:
    SK = ((0.2, 0.25, 0.14), (0.04, 0.055, 0.02)); EYEC = (0.75, 0.95, 0.2)
    KEYS = [(0.775, 0, 0.0, 0.06, 0.055, 0.055, 2.0), (0.81, 0, 0.0, 0.11, 0.08, 0.09, 2.2), (0.88, 0, 0.005, 0.15, 0.1, 0.12, 2.3),
            (0.97, 0, -0.01, 0.15, 0.19, 0.11, 2.1), (1.05, 0, -0.03, 0.15, 0.25, 0.1, 2.0), (1.12, 0, -0.03, 0.14, 0.2, 0.1, 2.0),
            (1.2, 0, 0.0, 0.13, 0.11, 0.105, 2.0), (1.3, 0, 0.02, 0.15, 0.09, 0.125, 2.1), (1.4, 0, 0.03, 0.175, 0.085, 0.15, 2.25),
            (1.465, 0, 0.04, 0.17, 0.08, 0.15, 2.2), (1.5, 0, 0.03, 0.12, 0.07, 0.12, 2.0), (1.53, 0, 0.0, 0.085, 0.066, 0.095, 2.0),
            (1.57, 0, -0.04, 0.07, 0.062, 0.075, 2.0), (1.62, 0, -0.07, 0.07, 0.06, 0.068, 2.0)]
    OPT = dict(W=1.15, L=1.1, nk=0.05, finger=0.17, hand_r=1.5, wrist=0.64, ribs=0.0085, belly=0.9, collar=0.6, tendon=1.0, hc=(0, 1.62, -0.11), jaw_w=0.1, jaw_out=0.05,
               brow=0.014, waist=1.15, head_w=0.12, head_h=0.7, neck_r=0.075, depth=1.15, warts=70, torso=KEYS)
HC = OPT["hc"]

# --- materials ------------------------------------------------------------------------------------------------------------------------
SKIN = GK.hollow_skin("Skin", SK[0], SK[1], wet=0.05, wrinkle=70.0, vein_amt=0.8, liv=(0.9, 0.7, 0.8), extremities=0.8, gain=0.95)
CLAW = GK.grave_bone("Claw", (0.34, 0.3, 0.24), (0.1, 0.07, 0.05), 12.0)
EYE = GK.glow("Eye", EYEC, 8.0)
TUNIC = GK.cloth("Tunic", (0.14, 0.105, 0.075), "rough_linen", 7.0, (0.04, 0.03, 0.02), 0.9)
RAG = GK.cloth("Cloth", (0.09, 0.075, 0.065) if not GA else (0.04, 0.04, 0.046), "rough_linen", 7.0, (0.09, 0.075, 0.065) if not GA else (0.04, 0.04, 0.046))
LINEN = GK.cloth("Linen", (0.36, 0.32, 0.25), "rough_linen", 14.0, (0.12, 0.09, 0.05), 0.9)
WRAP = GK.cloth("Wrap", (0.3, 0.26, 0.19), "rough_linen", 18.0, (0.1, 0.08, 0.05), 0.9)
SACK = GK.cloth("Sack", (0.1, 0.075, 0.05), "rough_linen", 6.0, (0.02, 0.015, 0.01), 0.92)
PATCHM = GK.cloth("Patch", (0.19, 0.13, 0.07), "rough_linen", 9.0, (0.04, 0.03, 0.02), 0.92)
HAIR = GK.cloth("Hair", (0.045, 0.038, 0.034), "rough_linen", 30.0, (0.01, 0.01, 0.01), 0.8)
LEATHER = GK.leather("Leather", (0.15, 0.095, 0.06))
IRON = GK.iron("Iron", (0.12, 0.11, 0.11), (0.17, 0.085, 0.05))
BONE = GK.grave_bone("Bone", (0.6, 0.55, 0.44), (0.2, 0.15, 0.1))
WOOD = GK.wood("Wood", (0.16, 0.1, 0.06), 0.7)
STONE = GK.stone("Stone", (0.2, 0.2, 0.19))
SEAM = GK.glow("Seam", (1.0, 0.5, 0.12), 3.5, (0.15, 0.04, 0.03))
GLAND = GK.membrane("Gland", (0.5, 1.0, 0.25), 2.2, (0.16, 0.2, 0.08))
MATS = [SKIN, CLAW, EYE, TUNIC, RAG, LINEN, WRAP, SACK, PATCHM, HAIR, LEATHER, IRON, BONE, WOOD, STONE, SEAM, GLAND]
for m_ in (TUNIC, RAG, LINEN, WRAP, SACK, PATCHM, HAIR):
    L.soften(m_, 0.45)                                   # the cloth bump is fine grain: halved, so the bake is not fuzz


# --- the body: designed, then sculpted ---------------------------------------------------------------------------------------------------------
STRAPS = []
if WR:
    STRAPS = [[(-0.1, 1.51, 0.0), (-0.135, 1.44, -0.1), (-0.12, 1.26, -0.125), (0.04, 1.08, -0.12)],
              [(-0.1, 1.51, 0.0), (-0.12, 1.4, 0.11), (-0.1, 1.2, 0.14), (0.04, 1.02, 0.13)],
              [(0.1, 1.5, 0.0), (0.12, 1.42, -0.09), (0.12, 1.24, -0.11), (0.0, 1.06, -0.12)],
              [(0.1, 1.5, 0.0), (0.1, 1.38, 0.11), (0.08, 1.2, 0.14), (-0.04, 1.02, 0.13)]]


def skel(sk):
    if WR:                                              # the strap side: the left shoulder dragged down
        for nm_, f in (("trpl", 0.8), ("dltl", 1.0), ("shl", 1.0), ("ua1l", 0.6), ("ua2l", 0.3)):
            i = sk.arms.idx[nm_]
            x, y, z = sk.arms.p[i]
            sk.arms.p[i] = (x, y, z - 0.055 * f)


def extra(sc, Y, nm):
    k = {"wretch": 1.3, "gaunt": 1.2, "husk": 2.0, "spitter": 1.3}[KIND]
    AN.muscles(sc, Y, nm, k, lean=1.0)
    AN.joints(sc, Y, nm, OPT["hand_r"], OPT["wrist"], 1.0 if not HU else 1.2)
    if WR and nm == "Body":
        for pts in STRAPS:                              # straps cut into the flesh: a groove with the meat piled either side
            for a, b in zip(pts[:-1], pts[1:]):
                sc.ridge(a, b, 0.016, -0.011, facing=(0, 0, 0) if False else None)
                n_ = np.array([b[2] - a[2], 0, a[0] - b[0]]); n_ = n_ / (np.linalg.norm(n_) + 1e-9) * 0.022
                for sg in (-1, 1):
                    sc.ridge((a[0] + sg * n_[0], a[1], a[2] + sg * n_[2]), (b[0] + sg * n_[0], b[1], b[2] + sg * n_[2]), 0.01, 0.006)
    if GA and nm == "Body":
        for i in range(7):                              # a cage: each rib stands out and the hollow between sinks
            y = 1.38 - 0.04 * i
            sc.band(Y(y), 0.012, 0.01, 0.2, slope=-0.03, xmin=0.03 + 0.012 * i)
            sc.band(Y(y - 0.02), 0.011, -0.012, 0.2, slope=-0.03, xmin=0.03 + 0.012 * i)
        sc.bump((0.0, Y(1.02), -0.075), 0.11, -0.03, facing=(0, 0, -1))        # a hollow stomach, under the cage
        sc.bump((0.13, Y(0.985), -0.06), 0.03, 0.02, facing=(0.5, 0, -1), sx=(-1, 1))   # hip bones, proud
    if WR and nm == "Body":
        sc.bump((0.0, Y(1.32), -0.07), 0.1, -0.028, facing=(0, 0, -1))         # a collapsed chest
        sc.bump((0.0, Y(1.07), -0.17), 0.13, 0.03, facing=(0, 0, -1))          # the pot belly, tight as a drum
    if HU and nm == "Body":
        sc.bump((0.0, Y(1.05), -0.25), 0.17, 0.035, facing=(0, 0, -1))
        sc.bump((0.0, Y(0.9), -0.2), 0.15, 0.03, facing=(0, 0, -1))
        sc.ridge((0.0, Y(1.26), -0.2), (0.0, Y(0.84), -0.27), 0.012, -0.018, facing=(0, 0, -1))   # the stitched cut down the gut: a lipped wound
        for sg in (-1, 1):
            sc.ridge((sg * 0.016, Y(1.26), -0.2), (sg * 0.016, Y(0.84), -0.27), 0.008, 0.01, facing=(0, 0, -1))
    if SP and nm == "Body":
        sc.bump((0.0, Y(1.53), -0.12), 0.085, -0.022, facing=(0, 0.2, -1))     # the cradle: a hollow for the sac to hang in ...
        for a in np.linspace(0.0, math.tau, 9, endpoint=False):                  # ... ringed by a rim of swollen skin
            sc.bump((0.1 * math.sin(a), Y(1.53) + 0.075 * math.cos(a) * 0.9, -0.1), 0.028, 0.014, facing=(0, 0, -1))
        sc.bump((0.0, Y(1.1), -0.2), 0.14, 0.028, facing=(0, 0, -1))           # the pendulous bile belly
        sc.bump((0.0, Y(0.95), -0.17), 0.12, 0.024, facing=(0, 0, -1))
    AN.damage(sc, {"wretch": 11, "gaunt": 12, "husk": 13, "spitter": 14}[KIND], count={"wretch": 46, "gaunt": 40, "husk": 60, "spitter": 30}[KIND],
              amp=0.009, boils=8 if SP else (14 if HU else 0))


mouth = 0.02 if WR else 0.0
ctx = BB.body(OPT, SKIN, CLAW, EYE, claw=0.16 if (WR or GA) else 0.06, extra=extra, skel=skel, mouth=mouth,
              body_tris={"wretch": 4000, "gaunt": 4000, "husk": 4300, "spitter": 4200}[KIND], arm_tris=1500, toe_claws=WR or GA or SP)
objs, PAIRS = ctx.objs, ctx.pairs
WTS = BW.base_weights(ctx, S, neck=OPT["nk"])
WTS["skirt"] = BW.skirt_weights(WTS, y_hip=0.9, y_knee=0.45, spread=0.8, knee_part=0.5, torso_from=0.95)
HB, HA = ctx.hi["Body"], ctx.hi["Arms"]


def add(o, sock=None):
    if sock:
        o["sock"] = sock
    objs.append(o)
    return o


def ang_noise(th, y, seed, amp):
    return amp * (0.55 * np.sin(th * 5 + seed) + 0.3 * np.sin(th * 11 + seed * 2.1 + y * 3) + 0.2 * np.sin(th * 23 + seed * 3.7) + 0.1 * np.sin(th * 47 + seed))


def cloth_shell(src, name, y0, y1, off, thick, mat, sock, tris, seed=1.0, ragged_bottom=0.05, ragged_top=0.0, folds_amp=0.008, neck_v=False, front_only=False):
    def sel(P, N):
        th = np.arctan2(P[:, 0], -P[:, 2])
        f = np.minimum(P[:, 1] - (y0 + ang_noise(th, P[:, 1], seed, ragged_bottom)), (y1 + ang_noise(th, P[:, 1], seed + 3.0, ragged_top)) - P[:, 1])
        if neck_v:
            f = np.minimum(f, np.where(P[:, 2] < 0.0, (1.47 - P[:, 1]) + np.abs(P[:, 0]) * 2.5, 1.0))
        if front_only:
            f = np.where(N[:, 2] < 0.0, f, -1.0)
        return f

    def fold(P, N):
        th = np.arctan2(P[:, 0], -P[:, 2])
        t = sm(y1, y0, P[:, 1])
        return folds_amp * (0.3 + t) * (np.sin(th * 9 + 3.0 * P[:, 1] + seed) + 0.5 * np.sin(th * 21 + P[:, 1] * 6 + seed * 2)) + 0.0015 * L.hash_noise(P, 26.0, seed)
    hi = L.shell(src, name + "High", sel if callable(off) or True else sel, off, thick, mat, sock, folds=fold, smooth_iter=3)
    return L.hi_lo(hi, tris, name + "Low", sock, PAIRS, objs)


def strap_shell(src, name, pts, w, off, mat, sock, tris, thick=0.005):
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


def locks(n, seed, width, length, mat, sock="r:head", sweep=1.0, rear_only=False):
    """Hair / veil locks that GROW from the scalp: roots spread over the crown, each a flat ribbon with a taper, falling back."""
    rng = np.random.RandomState(seed)
    Hc = Vector(G(*HC))
    for k in range(n):
        th = rng.uniform(-2.7, 2.7) if rear_only else rng.uniform(-math.pi, math.pi)
        ph = rng.uniform(0.15, 1.15)                     # from the crown (0) down the sides
        root = Hc + Vector((math.sin(th) * math.sin(ph) * 0.082, -math.cos(th) * math.sin(ph) * 0.078 - 0.01, math.cos(ph) * 0.085 + 0.0))
        out = Vector((math.sin(th) * 0.45 * sweep, -abs(math.cos(th)) * 0.3 - 0.1, -1.0)).normalized()
        Ln = length * rng.uniform(0.6, 1.2)
        pts = []
        for j in range(8):
            t = j / 7.0
            wob = Vector((noise.noise(Vector((k, t * 3, 1))), noise.noise(Vector((k, t * 3, 2))), 0)) * 0.03 * t
            pts.append(root + out * Ln * t + Vector((0, -0.05 * t * t, 0)) + wob)
        add(GK.strip("Hair", pts, width * rng.uniform(0.7, 1.3), 0.009, sock, mat, taper=0.75, sides=4), sock)


# =============================== WRETCH ==========================================================================================================
if WR:
    cloth_shell(HB, "Tunic", 0.93, 1.45, lambda P, N: 0.013 + 0.06 * sm(1.22, 0.93, P[:, 1]), 0.005, TUNIC, "bodyskin", 1100, seed=2.0, ragged_bottom=0.11, ragged_top=0.012, folds_amp=0.012, neck_v=True)
    for k in range(17):
        ang = math.tau * k / 17.0 + 0.25 * noise.noise(Vector((k, 5.0, 0)))
        root = Vector(G(math.cos(ang) * 0.17, 0.96 - 0.015 * (k % 2), math.sin(ang) * 0.15))
        out = Vector((math.cos(ang), -math.sin(ang), 0.0))
        Ln = 0.22 + 0.16 * (0.5 + 0.5 * noise.noise(Vector((k * 1.3, 2.0, 0)))) + 0.08 * max(0.0, math.sin(ang))
        pts = [root + out * (0.005 + 0.035 * t * t) + Vector((0, 0, -Ln * t)) + out * 0.01 * math.sin(t * 5.0 + k) for t in [i / 7.0 for i in range(8)]]
        add(GK.strip("Rag", pts, 0.07 + 0.015 * (k % 3), 0.006, "skirt", RAG, taper=0.6, sides=4), "skirt")
    for sx in (-1, 1):
        L.wrap_shell(HA, "ArmWrap", 0.74, 0.92, sx, 0.009, WRAP, "armskin", 240, PAIRS, objs, turns=5.0, cx=sx * 0.25, xs=0.17)
        L.wrap_shell(HB, "ShinWrap", 0.04, 0.28, sx, 0.011, WRAP, "bodyskin", 240, PAIRS, objs, turns=6.0, cx=sx * 0.11, xs=0.02)
    for i, pts in enumerate(STRAPS):
        strap_shell(HB, "Strap", pts, 0.026 if i < 2 else 0.018, 0.02, LEATHER, "r:chest", 260)
    strap_shell(HB, "Belt", [(-0.2, 0.97, -0.15), (0.0, 0.97, -0.2), (0.2, 0.97, -0.15), (0.2, 0.97, 0.1), (-0.2, 0.97, 0.1), (-0.2, 0.97, -0.15)], 0.025, 0.03, LEATHER, "r:pelvis", 400, thick=0.006)
    locks(34, 5, 0.03, 0.4, HAIR, rear_only=True)
    # the sack: cloth with weight. It sags (a heavy belly low on the back), is tied at the neck with a gathered mouth, patched, things poke out
    sack = L.lathe("Sack", [(0.0, -0.32), (0.13, -0.3), (0.22, -0.22), (0.265, -0.07), (0.26, 0.09), (0.21, 0.24), (0.13, 0.35), (0.07, 0.42), (0.062, 0.46), (0.085, 0.53), (0.12, 0.58)],
                   (0.03, 0.98, 0.28), SACK, "r:chest", nth=34, wobble=0.22, seed=2.0, fold=0.07, fold_n=5, thick=0.0, ellip=(1.08, 0.9), rows=15)
    rngs = np.random.RandomState(3)
    lumps = [(np.array([0.03 + rngs.uniform(-0.22, 0.22), 0.98 + rngs.uniform(-0.3, 0.15), 0.28 + rngs.uniform(0.0, 0.2)]), rngs.uniform(0.05, 0.1), rngs.uniform(0.025, 0.05)) for _ in range(10)]

    def sack_form(P, N):
        d = 0.012 * L.hash_noise(P, 22.0, 5.0) + 0.018 * L.hash_noise(P * np.array([1.0, 3.0, 1.0]), 9.0, 2.0)
        for c, r, a in lumps:
            d = d + a * L.gauss(P, c, r)
        th = np.arctan2(P[:, 0] - 0.03, P[:, 2] - 0.28)
        return d + 0.02 * np.sin(th * 6 + P[:, 1] * 6.0) * sm(1.1, 1.45, P[:, 1]) - 0.02 * sm(0.75, 0.6, P[:, 1])
    L.displace(sack, sack_form)
    L.smooth_shade(sack)
    add(fx(sack), "r:chest")
    for pi_, (py, pth, pr) in enumerate(((0.9, 0.4, 0.09), (1.05, 3.1, 0.08), (0.78, 5.2, 0.07))):
        c = np.array([0.03 + math.cos(pth) * 0.2, py, 0.28 + math.sin(pth) * 0.2])
        try:
            pt = L.patch(sack, "SackPatch", c, pr, PATCHM, "r:chest", off=0.008, thick=0.0, seed=4.0 + pi_, axis=(0.03, 0.28))
            L.mods(pt, ("DECIMATE", dict(ratio=min(1.0, 90.0 / max(L.tri_count(pt), 1)), use_collapse_triangulate=True)))
            add(fx(pt), "r:chest")
        except RuntimeError:
            pass
    add(fx(L.band_loop("Tie", (0.03, 1.42, 0.28), 0.066, 0.06, 0.013, LEATHER, "r:chest", n=22, sides=5)), "r:chest")
    add(K.loft("Knot", [Vector(G(0.03, 1.41, 0.22)), Vector(G(0.03, 1.32, 0.19))], [0.013, 0.01], "r:chest", LEATHER, 5), "r:chest")
    add(fx(K.loft("Roll", [Vector(G(-0.29, 1.52, 0.2)), Vector(G(0.0, 1.54, 0.22)), Vector(G(0.29, 1.52, 0.2))], [0.075, 0.083, 0.075], "r:chest", WRAP, 12)), "r:chest")
    for x in (-0.17, 0.17):
        add(K.loft("RollTie", [Vector(G(x, 1.52 + 0.085 * math.cos(a), 0.21 + 0.085 * math.sin(a))) for a in [math.tau * i / 14 for i in range(15)]], [(0.011, 0.006)] * 15, "r:chest", LEATHER, 5), "r:chest")
    for k, (dx, h, lean) in enumerate(((0.0, 0.5, -0.25), (0.06, 0.38, 0.35), (-0.05, 0.3, -0.8))):         # things poking from the mouth of the sack
        a = Vector(G(0.03 + dx * 0.4, 1.5, 0.27))
        add(fx(K.bone("Bone", a, a + Vector(G(dx + lean * 0.14, h, 0.03)), 0.013 + 0.002 * k, "r:chest", BONE, 1.9, 8, 8, k)), "r:chest")
    add(fx(K.blob("Skull", Vector(G(0.22, 1.18, 0.38)), (0.055, 0.06, 0.07), "r:chest", BONE, 22, 14)), "r:chest")
    for sx in (-1, 1):
        add(K.blob("Eye", Vector(G(0.22 + sx * 0.02, 1.2, 0.44)), (0.011, 0.006, 0.012), "r:chest", EYE, 10, 6), "r:chest")
    add(fx(K.blob("Pot", Vector(G(-0.22, 0.86, 0.32)), (0.08, 0.08, 0.075), "r:chest", IRON, 20, 12)), "r:chest")
    add(K.loft("PotRim", [Vector(G(-0.22 + 0.08 * math.cos(a), 0.93, 0.32 + 0.08 * math.sin(a))) for a in [math.tau * i / 20 for i in range(21)]], [(0.01, 0.006)] * 21, "r:chest", IRON, 5), "r:chest")
    add(GK.chain_links("Chain", [Vector(G(-0.22, 0.93, 0.32)), Vector(G(-0.18, 1.08, 0.3)), Vector(G(-0.12, 1.24, 0.26))], 0.01, "r:chest", IRON), "r:chest")
    Hl = S["hand_l"]
    add(K.loft("Wood", [Hl + G(0, 0.14, -0.035), Hl + G(0.004, -0.2, -0.035), Hl + G(0.0, -0.52, -0.035)], [0.02, 0.019, 0.016], "r:hand_l", WOOD, 8, wobble=0.06), "r:hand_l")
    hk = [Hl + G(0.0, -0.52 - 0.12 * math.sin(a), -0.035 - 0.12 * (1.0 - math.cos(a))) for a in [-0.3 + 3.6 * i / 10.0 for i in range(11)]]
    add(K.curve_tube("Iron", hk, 0.02, "r:hand_l", IRON, [1.0 - 0.9 * (i / 10.0) ** 1.6 for i in range(11)]), "r:hand_l")
    add(K.blob("Collar", Hl + G(0.0, -0.5, -0.035), (0.03, 0.036, 0.03), "r:hand_l", IRON, 12, 8), "r:hand_l")
    for k in range(9):
        a = math.tau * (k + 0.5) / 9.0
        add(GK.claw("Tooth", Vector(G(math.cos(a) * 0.2, 0.96, math.sin(a) * 0.17)), Vector(G(math.cos(a) * 0.2, -1.0, math.sin(a) * 0.2)), 0.05 + 0.02 * (k % 3), 0.009, "r:pelvis", BONE, 0.2), "r:pelvis")

# =============================== GAUNT ==========================================================================================================
elif GA:
    cloth_shell(HB, "Loin", 0.72, 0.99, 0.016, 0.005, RAG, "bodyskin", 600, seed=2.0, ragged_bottom=0.09)
    bones = L.Plates(HB, HB, HA, HA, fine=True)                     # the ribcage: real bone ribs standing off a dark hollow
    for i in range(8):
        y0 = 1.4 - 0.042 * i

        def rib_sel(P, N, y0=y0, i=i):
            front = np.clip(-P[:, 2] / 0.11, 0.0, 1.0)
            yc = y0 - 0.05 * front * (0.6 + 0.1 * i)
            gap = np.where(P[:, 2] < -0.03, np.abs(P[:, 0]) - (0.03 + 0.003 * i), 1.0)
            return np.minimum(0.0115 - np.abs(P[:, 1] - yc), gap)
        bones.keep(rib_sel, (lambda i: lambda P, N: 0.03 - 0.0015 * i + 0.0 * P[:, 0])(i), 0.012, mat=BONE, bevel=0.0035, name="Rib")
    bones.keep(lambda P, N: np.where((P[:, 2] < -0.04) & (np.abs(P[:, 0]) < 0.03) & (P[:, 1] > 1.18) & (P[:, 1] < 1.46), np.minimum(0.03 - np.abs(P[:, 0]), P[:, 1] - 1.18), -1.0), 0.036, 0.011, mat=BONE, bevel=0.003, name="Sternum")
    bones.keep(lambda P, N: np.where((P[:, 2] > 0.02) & (P[:, 1] > 0.98) & (P[:, 1] < 1.5), np.minimum(0.016 - np.abs(P[:, 0]), np.minimum(P[:, 1] - 0.98, 1.5 - P[:, 1])), -1.0),
               lambda P, N: 0.026 + 0.01 * (np.abs(np.sin(P[:, 1] * math.pi / 0.04)) ** 0.6), 0.011, mat=BONE, bevel=0.003, name="Spine")
    bones.finish(2600, "stiff", PAIRS, objs, "Cage")
    for sx in (-1, 1):
        L.wrap_shell(HA, "HandWrap", 0.62, 0.76, sx, 0.008, WRAP, "armskin", 200, PAIRS, objs, turns=4.0, cx=sx * 0.25, xs=0.17)
        L.wrap_shell(HB, "ShinWrap", 0.06, 0.3, sx, 0.011, WRAP, "bodyskin", 220, PAIRS, objs, turns=6.0, cx=sx * 0.11, xs=0.02)
    # the shroud: a clinging cowl and a mantle with thickness, torn edges and heavy ragged tails
    hd = L.hood("HoodHigh", (HC[0], 1.7, HC[2] + 0.012), RAG, "hood", size=(0.105, 0.125, 0.118), face_r=(0.056, 0.082), face_dy=-0.016, peak=0.03, back_drop=0.26, lip=0.016, seed=7.0, amp=0.009)
    L.hi_lo(hd, 1000, "HoodLow", "hood", PAIRS, objs)
    WTS["hood"] = lambda p: {"head": float(sm(1.5, 1.62, p.z)), "chest": float(1.0 - sm(1.5, 1.62, p.z))}
    mk = [(1.585, 0, -0.1, 0.07, 0.06, 0.07, 2.0), (1.53, 0, -0.01, 0.13, 0.085, 0.1, 2.0), (1.46, 0, 0.02, 0.2, 0.1, 0.12, 2.1), (1.36, 0, 0.012, 0.215, 0.14, 0.13, 2.0), (1.22, 0, 0.0, 0.2, 0.13, 0.13, 2.0), (1.08, 0, 0.0, 0.17, 0.1, 0.12, 2.0)]
    _mh0 = L.ragged_hem(1.14, 0.1, seed=9.0, cuts=0.16, scallop=0.05, nscal=9)

    def mh(th):                                          # open in front from the collar down, so the ribcage shows
        d = np.abs(((th - 1.5 * math.pi + math.pi) % math.tau) - math.pi)
        return _mh0(th) + 0.5 * np.exp(-(d / 0.75) ** 2)
    md = L.Drape(mk, 1.585, mh, y_fold0=1.5, y_hem_ref=1.1, amp=0.05, waves=L.Waves(seed=21, counts=(3, 6, 11, 17), amps=(1.0, 0.7, 0.4, 0.2)), nth=150, dy=0.008, flare=0.04, seed=6.0)
    Pgm = md.points()
    mhi = L.grid_surface("MantleHigh", Pgm, "mantle", RAG, wrap=True, thick=0.012, sub=1)
    L.hi_lo(mhi, 1500, "MantleLow", "mantle", PAIRS, objs)
    WTS["mantle"] = BW.GB.envelope_weights(ctx.segs, band=0.11, power=1.5)
    for k in range(8):                                                                       # heavy ragged tails off the mantle
        th = math.tau * (k + 0.5) / 8.0
        yh = float(mh(np.array([th]))[0]) + 0.012
        p, n = L.surf_pt(Pgm, md, yh, th)
        Ln = 0.2 + 0.18 * ((k * 5) % 3) / 2.0
        pts = [Vector(G(*(p + n * 0.01 * t + np.array([0, -Ln * t, 0.0]) + np.array([0.02 * math.sin(k + t * 5), 0, 0])))) for t in [i / 6.0 for i in range(7)]]
        add(GK.strip("Tail", pts, 0.085, 0.012, "mantle", RAG, taper=0.8, sides=4), "mantle")
    for k in range(6):
        a = math.pi * (0.12 + 0.76 * k / 5.0)
        add(K.blob("Knuckle", Vector(G(math.cos(a) * 0.07, 1.5, -math.sin(a) * 0.09 - 0.02)), (0.011, 0.015, 0.011), "r:chest", BONE, 8, 6), "r:chest")
    for tag, sx in (("l", -1), ("r", 1)):
        add(GK.claw("Spur", S["elbow_" + tag] + G(sx * 0.03, 0.0, 0.03), G(sx * 0.35, 0.3, 1.0), 0.2, 0.014, "arm_" + tag, CLAW, -0.15), "arm_" + tag)

# =============================== HUSK ==========================================================================================================
elif HU:
    cloth_shell(HB, "Shroud", 0.7, 1.0, lambda P, N: 0.02 + 0.03 * sm(1.0, 0.7, P[:, 1]), 0.006, LINEN, "bodyskin", 800, seed=3.0, ragged_bottom=0.07, folds_amp=0.011)
    for sx in (-1, 1):
        L.wrap_shell(HA, "ArmWrap", 0.78, 1.04, sx, 0.012, LINEN, "armskin", 260, PAIRS, objs, turns=4.0, cx=sx * 0.25, xs=0.17)
        L.wrap_shell(HB, "ShinWrap", 0.06, 0.3, sx, 0.012, LINEN, "bodyskin", 240, PAIRS, objs, turns=5.0, cx=sx * 0.11, xs=0.02)
    L.wrap_shell(HB, "GutWrap", 0.84, 1.0, 1, 0.022, LINEN, "bodyskin", 500, PAIRS, objs, turns=3.0, cx=0.0, xs=-1.0)      # linen wound round the hips and under the belly
    # the stitched cut: an ember seam with cross-stitches, and the scalp stitched too
    seam = [G(0.0 + 0.004 * math.sin(t * 9), 1.26 - 0.42 * t, -0.215 - 0.075 * math.sin(t * math.pi * 0.9) - 0.03 * t) for t in [i / 14.0 for i in range(15)]]
    add(fx(K.loft("Seam", seam, [(0.014, 0.006)] * 15, "torso", SEAM, 5)), "torso")
    for k in range(9):
        t = 0.06 + 0.88 * k / 8.0
        p = seam[int(t * 14)]
        add(K.loft("Stitch", [p + G(-0.04, 0.006, 0.012), p + G(0, 0, -0.012), p + G(0.04, -0.006, 0.012)], [0.007, 0.008, 0.007], "torso", LEATHER, 4), "torso")
    for k in range(4):
        a = Vector(G(0.0, 1.76 - 0.03 * k, -0.07)) if False else Vector(G(-0.02, 1.74 - 0.028 * k, HC[2] + 0.075))
        add(K.loft("Stitch", [a, a + Vector(G(0.04, 0.0, 0.0))], [0.004, 0.004], "r:head", LEATHER, 4), "r:head")
    # the ember knot between the shoulder blades (husk.gd breaks it: chest + (0, 0.04, 0.16))
    kn = Vector(G(0.0, 1.32, 0.165))
    add(fx(K.blob("Knot", kn, (0.04, 0.03, 0.035), "r:chest", SEAM, 14, 10)), "r:chest")
    for k in range(6):
        a = math.tau * k / 6.0
        add(GK.claw("Ember", kn + Vector((math.cos(a) * 0.03, 0.01, math.sin(a) * 0.03 * 0 + 0.01)), Vector((math.cos(a) * 0.6, 0.5, math.sin(a) * 0.3)), 0.05, 0.012, "r:chest", SEAM, -0.1), "r:chest")
    # the coffin lid on its back: a six-sided board, curved, nailed, corded to the shoulders; and a headstone on the right shoulder
    outline = [(-0.1, 0.52), (0.1, 0.52), (0.19, 0.78), (0.15, 1.2), (-0.15, 1.2), (-0.19, 0.78)]
    bm = bmesh.new()
    vs = []
    for x, y in outline:
        vs.append(bm.verts.new(Vector(G(x, y, 0.2 - 0.05 * (x / 0.19) ** 2))))
    bm.faces.new(vs)
    lid = K.mesh_from_bm("Lid", bm, "r:chest", WOOD, smooth=False)
    for sub_ in range(3):
        L.mods(lid, ("SUBSURF", dict(levels=1, render_levels=1, subdivision_type='SIMPLE')))
    L.mods(lid, ("SOLIDIFY", dict(thickness=0.04, offset=1.0)), ("BEVEL", dict(width=0.006, segments=1, limit_method='ANGLE', angle_limit=math.radians(40))))
    L.displace(lid, lambda P, N: 0.004 * L.hash_noise(P, 30.0, 9.0))
    add(fx(lid), "r:chest")
    for yy in (0.72, 0.98):
        add(fx(K.loft("LidBand", [Vector(G(-0.17, yy, 0.17)), Vector(G(0.0, yy, 0.24)), Vector(G(0.17, yy, 0.17))], [(0.014, 0.034)] * 3, "r:chest", IRON, 5)), "r:chest")
        for x in (-0.13, -0.04, 0.05, 0.13):
            add(K.blob("Nail", Vector(G(x, yy, 0.255 - 0.04 * (x / 0.19) ** 2)), (0.012, 0.012, 0.008), "r:chest", IRON, 8, 6), "r:chest")
    for sx in (-1, 1):
        add(K.loft("Cord", [Vector(G(sx * 0.1, 1.2, 0.19)), Vector(G(sx * 0.13, 1.42, 0.1)), Vector(G(sx * 0.1, 1.48, -0.02)), Vector(G(sx * 0.13, 1.4, -0.12)), Vector(G(sx * 0.1, 1.1, -0.15))],
                   [(0.012, 0.012)] * 5, "r:chest", LEATHER, 5), "r:chest")
    add(fx(GK.slab("Headstone", Vector(G(0.29, 1.52, 0.04)), (0.1, 0.035, 0.13), Quaternion((1, 0, 0, 0)), "r:chest", STONE, arch=0.5, lump=0.1, seed=2.0)), "r:chest")
    add(K.loft("StoneCord", [Vector(G(0.26, 1.38, -0.06)), Vector(G(0.18, 1.5, 0.0)), Vector(G(0.26, 1.4, 0.1))], [(0.012, 0.012)] * 3, "r:chest", LEATHER, 5), "r:chest")
    locks(10, 8, 0.02, 0.1, HAIR, rear_only=True)

# =============================== SPITTER =========================================================================================================
else:
    cloth_shell(HB, "Loin", 0.72, 0.99, 0.016, 0.005, RAG, "bodyskin", 600, seed=2.0, ragged_bottom=0.09)
    sac = np.array([0.0, 1.53, -0.13])
    cr = [Vector(G(sac[0] + math.sin(a) * 0.115, sac[1] - 0.05 - 0.045 * math.cos(a), sac[2] + 0.0 - math.cos(a) * 0.03)) for a in [-1.7 + 3.4 * i / 16 for i in range(17)]]
    add(fx(K.loft("Cradle", cr, [(0.013, 0.013)] * 17, "r:chest", IRON, 5)), "r:chest")                  # an iron cradle under the sac (the sac is spitter.gd's)
    for a in (-1.3, -0.65, 0.0, 0.65, 1.3):
        add(GK.claw("Prong", Vector(G(sac[0] + math.sin(a) * 0.115, sac[1] - 0.06, sac[2] + 0.0)), Vector(G(math.sin(a) * 0.3, 1.0, -0.5)), 0.08, 0.012, "r:chest", IRON, -0.1), "r:chest")
    for i, pts in enumerate([[(-0.15, 1.46, -0.04), (-0.13, 1.3, -0.12), (0.0, 1.16, -0.2), (0.14, 1.0, -0.2)], [(0.15, 1.46, -0.04), (0.13, 1.3, -0.12), (0.0, 1.16, -0.2), (-0.14, 1.0, -0.2)]]):
        strap_shell(HB, "Harness", pts, 0.022, 0.026, LEATHER, "r:chest", 300)
    strap_shell(HB, "Belt", [(-0.22, 0.96, -0.17), (0.0, 0.96, -0.27), (0.22, 0.96, -0.17), (0.22, 0.96, 0.1), (-0.22, 0.96, 0.1), (-0.22, 0.96, -0.17)], 0.025, 0.04, LEATHER, "r:pelvis", 400, thick=0.006)
    for k in range(5):                                                                              # glass phials of bile hung on the harness
        x = -0.16 + 0.08 * k
        y = 1.0 + 0.02 * (k % 2)
        add(K.loft("Phial", [Vector(G(x, y, -0.255)), Vector(G(x, y - 0.07, -0.26))], [(0.016, 0.016), (0.013, 0.013)], "r:pelvis", IRON, 6), "r:pelvis")
        add(K.blob("Bile", Vector(G(x, y - 0.045, -0.265)), (0.011, 0.022, 0.011), "r:pelvis", GLAND, 10, 8), "r:pelvis")
    for k in range(7):                                                                              # a bank of glands on the back and shoulders
        a = Vector(G(-0.14 + 0.047 * k, 1.38 + 0.05 * math.sin(k * 1.7), 0.15 + 0.03 * (k % 2)))
        add(fx(K.blob("Gland", a, (0.05 + 0.012 * (k % 3), 0.05, 0.045), "r:chest", GLAND, 18, 12)), "r:chest")
    for k in range(5):
        add(K.blob("Gland", Vector(G(-0.1 + 0.05 * k, 1.12 - 0.01 * k, 0.17)), (0.04, 0.04, 0.035), "r:chest", GLAND, 14, 10), "r:chest")
    locks(10, 9, 0.018, 0.14, HAIR, rear_only=True)
    for tag, sx in (("l", -1), ("r", 1)):
        L.wrap_shell(HA, "ArmWrap", 0.7, 0.9, sx, 0.01, WRAP, "armskin", 220, PAIRS, objs, turns=4.0, cx=sx * 0.25, xs=0.17)

if PREVIEW:
    L.preview_sheet(PREVIEW, 0.95, 3.3)
L.report(objs)
print("BIPED", KIND, "parts", len(objs), "tris", sum(L.tri_count(o) for o in objs if o.type == 'MESH'))
if EXPORT:
    GK.export_skinned(objs, MATS, "grunt_" + KIND, S, WTS, {}, 2048, 16000, pairs=PAIRS)
