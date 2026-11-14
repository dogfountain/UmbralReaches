"""The Cinder Caster (r38 remodel): a bell-founder's hollowed, soot-black and heavy, throat swollen with slag. A smith, not a
spitter with a tint: a burnt leather apron and straps fitted to the body, forearm guards scorched through, shoulders and back
crusted in cracked slag with the ember lit in the cracks (a cooled-then-reheated crust, cut from the body's surface), smoked
goggles pushed up on a hooded brow, an iron cradle round the throat that holds the sac (spitter.gd hangs the swelling sac in it;
this model leaves the space), a long iron ladle of molten slag in the right fist, tongs and a crucible on the belt.

  GRUNT_OUT=<dir> tools/blender/run.sh biped_smith.py -- --kind cinder_caster [--preview /tmp/c.png] [--no-export]
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
import grunt_body as GB
import biped_sculpt_lib as L
import biped_body as BB
import biped_weights as BW
from boss_kit import G

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
KIND = args[args.index("--kind") + 1] if "--kind" in args else "cinder_caster"
PREVIEW = args[args.index("--preview") + 1] if "--preview" in args else ""
EXPORT = "--no-export" not in args

K.reset()
BB.fast_ao(16)
BB.lean()
S = dict(K.SOCKETS)
sm = L.smooth

SKIN = GK.hollow_skin("Skin", (0.12, 0.1, 0.09), (0.03, 0.025, 0.022), wet=0.1, wrinkle=40.0, vein_amt=0.5, liv=(0.9, 0.6, 0.5), extremities=0.0)
CLAW = GK.grave_bone("Claw", (0.2, 0.17, 0.14), (0.08, 0.06, 0.04), 12.0)
EYE = GK.glow("Eye", (1.0, 0.4, 0.1), 8.0)
SLAG = GK.ember_chitin("Slag", (0.045, 0.04, 0.04), (0.28, 0.22, 0.18), ember=(1.0, 0.36, 0.06), plates=9.0, rough=0.62, crack_w=0.04, strength=2.4)
APRON = GK.leather("Apron", (0.09, 0.055, 0.035))
LEATHER = GK.leather("Leather", (0.13, 0.085, 0.055))
IRON = GK.iron("Iron", (0.08, 0.075, 0.075), (0.18, 0.08, 0.04))
CLOTH = GK.cloth("Cloth", (0.07, 0.055, 0.045), "rough_linen", 7.0, (0.02, 0.015, 0.012), 0.92)
WOOD = GK.wood("Wood", (0.12, 0.08, 0.05), 0.9)
MOLTEN = GK.glow("Molten", (1.0, 0.36, 0.05), 5.0)
GLASS = GK.glow("Lens", (1.0, 0.7, 0.3), 3.0, body=(0.1, 0.06, 0.03))
MATS = [SKIN, CLAW, EYE, SLAG, APRON, LEATHER, IRON, CLOTH, WOOD, MOLTEN, GLASS]

HC = (0, 1.64, -0.08)
OPT = dict(W=1.12, L=1.25, nk=0.04, finger=0.14, hand_r=1.3, wrist=0.7, ribs=0.0, belly=0.6, collar=0.7, tendon=0.8, hc=HC, jaw_w=0.07, jaw_out=0.03, brow=0.016,
           waist=1.1, head_w=0.095, head_h=0.8, neck_r=0.07, depth=1.1)
ctx = BB.body(OPT, SKIN, CLAW, EYE, claw=0.05, body_tris=3000, arm_tris=1300)
objs, PAIRS = ctx.objs, ctx.pairs
WTS = BW.base_weights(ctx, S, neck=0.04)
WTS["skirt"] = BW.skirt_weights(WTS, y_hip=0.9, y_knee=0.45, spread=0.8, knee_part=0.5, torso_from=0.95)
HB, HA = ctx.hi["Body"], ctx.hi["Arms"]
MB = GB.make_low(HB, 9000, "BodyMed")
MA = GB.make_low(HA, 4000, "ArmsMed")
for _m in (MB, MA):
    _m.hide_render = True
    _m.hide_viewport = True
crust = L.Plates(HB, MB, HA, MA)


def fx_s(o):
    o["fixed"] = True
    return o


def add(o, sock=None):
    if sock:
        o["sock"] = sock
    objs.append(o)
    return o


def ragged(th, y, seed, amp):
    return amp * (0.55 * np.sin(th * 5 + seed) + 0.3 * np.sin(th * 11 + seed * 2.1 + y * 3) + 0.2 * np.sin(th * 23 + seed * 3.7))


# --- the slag crust: lumps on the shoulders and across the back, cracked, ember in the cracks -----------------------------------------------------
def blob_sel(c, r):
    c = np.array(c, dtype=np.float32)
    r = np.array(r, dtype=np.float32)
    return lambda P, N: 1.0 - np.sqrt((((P - c) / r) ** 2).sum(1)) + 0.12 * L.hash_noise(P, 12.0, 3.0)


def lumpy(P, N):
    return 0.012 * L.hash_noise(P, 16.0, 2.0) + 0.008 * L.hash_noise(P, 40.0, 4.0)


for sx in (-1, 1):
    crust.keep(blob_sel((sx * 0.27, 1.42, 0.0), (0.12, 0.1, 0.12)), 0.04, 0.016, on="arms", mat=SLAG, folds=lumpy, bevel=0.004, name="Shoulder")
    crust.keep(blob_sel((sx * 0.27, 1.3, 0.02), (0.1, 0.07, 0.1)), 0.032, 0.014, on="arms", mat=SLAG, folds=lumpy, bevel=0.004, name="Shoulder2")
crust.keep(blob_sel((0.0, 1.32, 0.08), (0.2, 0.17, 0.09)), 0.034, 0.016, mat=SLAG, folds=lumpy, bevel=0.004, name="Back")
crust.keep(blob_sel((0.0, 1.12, 0.1), (0.15, 0.12, 0.08)), 0.03, 0.014, mat=SLAG, folds=lumpy, bevel=0.004, name="Back2")
for sx in (-1, 1):
    crust.keep(blob_sel((sx * 0.11, 0.35, -0.04), (0.07, 0.07, 0.07)), 0.025, 0.012, mat=SLAG, folds=lumpy, bevel=0.004, name="Knee")
    crust.keep(blob_sel((sx * 0.28, 0.98, 0.0), (0.055, 0.1, 0.07)), 0.022, 0.011, on="arms", mat=SLAG, folds=lumpy, bevel=0.004, name="Elbow")
crust.finish(2200, "stiff", PAIRS, objs, "Slag")
for k in range(9):                                            # slag cooled into horns and spikes: the crust breaks the silhouette at the shoulders and spine
    sx = -1 if k % 2 else 1
    if k < 4:
        base = Vector(G(sx * (0.25 + 0.03 * (k // 2)), 1.46 + 0.02 * (k // 2), 0.0))
        d = Vector(G(sx * 0.7, 1.0, 0.1 * (k // 2) - 0.1))
    else:
        base = Vector(G(0.0 + 0.045 * (k - 6), 1.5 - 0.065 * (k - 4), 0.13))
        d = Vector(G(0.15 * (k - 6), 0.45, 1.0))
    add(fx_s(GK.claw("SlagSpike", base, d, 0.2 + 0.05 * (k % 3), 0.045, "r:chest" if k >= 4 else "r:shoulder_" + ("l" if sx < 0 else "r"), SLAG, -0.15)), "r:chest" if k >= 4 else "r:shoulder_" + ("l" if sx < 0 else "r"))


# --- the apron and straps, fitted -------------------------------------------------------------------------------------------------------------
def apron_sel(P, N):
    th = np.arctan2(P[:, 0], -P[:, 2])
    width = 0.15 + 0.06 * sm(1.35, 0.6, P[:, 1])
    lo = 0.62 + ragged(th * 1.7, P[:, 1], 3.0, 0.055) + 0.06 * (np.abs(P[:, 0]) / 0.2) ** 2
    f = np.minimum(np.minimum(P[:, 1] - lo, 1.38 - P[:, 1]), width - np.abs(P[:, 0]))
    for hc_, hr_ in (((0.07, 1.12, -0.2), 0.045), ((-0.1, 0.85, -0.26), 0.06), ((0.12, 0.74, -0.27), 0.04)):      # burnt through in three places
        f = np.minimum(f, np.linalg.norm(P - np.array(hc_, dtype=np.float32), axis=1) - hr_)
    return np.where(N[:, 2] < -0.05, f, -1.0)


def apron_fold(P, N):
    return (0.009 * np.sin(P[:, 0] * 34.0 + P[:, 1] * 5.0) + 0.005 * np.sin(P[:, 0] * 71.0 - P[:, 1] * 7.0)) * (0.25 + sm(1.2, 0.6, P[:, 1])) + 0.003 * L.hash_noise(P, 22.0, 6.0)


ap = L.shell(HB, "ApronHigh", apron_sel, lambda P, N: 0.03 + 0.05 * sm(1.0, 0.6, P[:, 1]), 0.02, APRON, "skirt", folds=apron_fold, smooth_iter=3)
L.hi_lo(ap, 1300, "ApronLow", "skirt", PAIRS, objs)


def strap(name, pts, w, off, mat, sock, tris, thick=0.005, planar=False):
    pts = np.array(pts, dtype=np.float32)
    front = float(pts[:, 2].mean()) < 0.0

    def sel(P, N):
        d = np.full(len(P), 9.0, dtype=np.float32)
        Q = P.copy()
        a_, b_ = pts.copy(), pts.copy()
        if planar:                                   # follow the path in x, y only (on whichever side faces the path): it lies ON the surface wherever that is
            Q[:, 2] = 0.0
            pts2 = pts.copy()
            pts2[:, 2] = 0.0
        else:
            pts2 = pts
        for a, b in zip(pts2[:-1], pts2[1:]):
            ab = b - a
            t = np.clip(((Q - a) @ ab) / max(float(ab @ ab), 1e-9), 0.0, 1.0)
            d = np.minimum(d, np.linalg.norm(Q - (a + t[:, None] * ab), axis=1))
        f = w - d
        if planar:
            f = np.where((N[:, 2] < -0.1) if front else (N[:, 2] > 0.1), f, -1.0)
        return f
    hi = L.shell(HB, name + "High", sel, off, thick, mat, sock, smooth_iter=2)
    return L.hi_lo(hi, tris, name + "Low", sock, PAIRS, objs)


for sx in (-1, 1):
    strap("ApronStrap", [(sx * 0.06, 1.38, -0.12), (sx * 0.09, 1.48, -0.06), (sx * 0.1, 1.5, 0.04), (sx * 0.1, 1.4, 0.12), (sx * 0.14, 1.12, 0.12)], 0.02, 0.034, LEATHER, "r:chest", 300)
for pts_ in ([(-0.2, 1.46, -0.07), (-0.08, 1.3, -0.19), (0.1, 1.12, -0.23), (0.2, 0.98, -0.15)], [(0.2, 1.46, -0.07), (0.08, 1.3, -0.19), (-0.1, 1.12, -0.23), (-0.2, 0.98, -0.15)],
             ):      # a harness of crossed straps over the apron and round the ribs
    strap("Harness", pts_, 0.024, 0.05, LEATHER, "r:chest", 260, planar=True)
for hx_, hy_ in ((-0.075, 1.3), (0.075, 1.3), (0.0, 1.17)):
    add(K.blob("Ring", Vector(G(hx_, hy_, -0.215)), (0.026, 0.026, 0.01), "r:chest", IRON, 12, 8), "r:chest")
strap("Belt", [(-0.22, 0.97, -0.12), (0.0, 0.97, -0.2), (0.22, 0.97, -0.12), (0.22, 0.97, 0.12), (-0.22, 0.97, 0.12), (-0.22, 0.97, -0.12)], 0.028, 0.05, LEATHER, "r:pelvis", 600, thick=0.007)
add(K.blob("Buckle", Vector(G(0.0, 0.97, -0.235)), (0.05, 0.04, 0.014), "r:pelvis", IRON, 18, 10), "r:pelvis")
# forearm guards: leather, scorched through at the edges
for sx in (-1, 1):
    ga = L.shell(HA, "GuardHigh", (lambda sx: lambda P, N: np.where(P[:, 0] * sx > 0.17, np.minimum(P[:, 1] - 0.72, 1.02 - P[:, 1]), -1.0))(sx), 0.02, 0.008, LEATHER, "armskin",
                 folds=lambda P, N: 0.003 * np.sin(P[:, 1] * 60.0) + 0.002 * L.hash_noise(P, 25.0, 3.0), smooth_iter=2)
    L.hi_lo(ga, 450, "GuardLow", "armskin", PAIRS, objs)
    for yy in (0.8, 0.9, 0.98):
        c0 = Vector(G(sx * 0.255, yy, 0.0))
        add(K.loft("Buckle", [c0 + Vector(G(math.cos(a) * 0.058, 0.0, math.sin(a) * 0.058)) for a in [math.tau * i / 16 for i in range(17)]], [(0.008, 0.005)] * 17, "arm_" + ("l" if sx < 0 else "r"), IRON, 5), "arm_" + ("l" if sx < 0 else "r"))

# --- head: a hood of scorched cloth and goggles pushed up ------------------------------------------------------------------------------------------
hd = L.hood("HoodHigh", (HC[0], 1.655, HC[2] + 0.0), CLOTH, "hood", size=(0.15, 0.15, 0.16), face_r=(0.085, 0.085), face_dy=-0.03, peak=0.0, back_drop=0.14, lip=0.012, seed=2.0, amp=0.006)
L.hi_lo(hd, 800, "HoodLow", "hood", PAIRS, objs)
WTS["hood"] = lambda p: {"head": float(sm(1.5, 1.62, p.z)), "chest": float(1.0 - sm(1.5, 1.62, p.z))}
for sx in (-1, 1):
    c = Vector(G(sx * 0.055, 1.72, HC[2] - 0.152))
    add(L.band_loop("GogRim", (sx * 0.052, 1.745, HC[2] - 0.115), 0.036, 0.036, 0.007, IRON, "r:head", n=20, sides=6) if False else
        K.loft("GogRim", [c + Vector(G(math.cos(a) * 0.036, math.sin(a) * 0.036, 0.0)) for a in [math.tau * i / 20 for i in range(21)]], [(0.007, 0.007)] * 21, "r:head", IRON, 6), "r:head")
    add(K.blob("Lens", c, (0.028, 0.01, 0.028), "r:head", GLASS, 14, 8), "r:head")
add(K.loft("GogStrap", [Vector(G(-0.12, 1.72, HC[2] - 0.04)), Vector(G(-0.07, 1.72, HC[2] - 0.15)), Vector(G(0.0, 1.725, HC[2] - 0.16)), Vector(G(0.07, 1.72, HC[2] - 0.15)), Vector(G(0.12, 1.72, HC[2] - 0.04))], [(0.014, 0.004)] * 5, "r:head", LEATHER, 6), "r:head")

# --- the throat cradle (the sac hangs in it) ----------------------------------------------------------------------------------------------------------
sac = np.array([0.0, 1.53, -0.13])
cr = [Vector(G(sac[0] + math.sin(a) * 0.1, sac[1] - 0.03 - 0.05 * math.cos(a) * 0.4, sac[2] + 0.02 - math.cos(a) * 0.02)) for a in [-1.5 + 3.0 * i / 14 for i in range(15)]]
add(K.loft("Cradle", cr, [(0.012, 0.012)] * 15, "r:chest", IRON, 6), "r:chest")
for a in (-1.2, -0.6, 0.0, 0.6, 1.2):
    add(GK.claw("Prong", Vector(G(sac[0] + math.sin(a) * 0.1, sac[1] - 0.04, sac[2] + 0.02)), Vector(G(math.sin(a) * 0.3, 1.0, -0.4)), 0.07, 0.012, "r:chest", IRON, -0.1), "r:chest")

# --- the ladle of molten slag, tongs and a crucible -------------------------------------------------------------------------------------------------------------
HR = S["hand_r"]
shaft = [HR + G(0.0, -0.45 + 1.15 * t, -0.04 - 0.03 * math.sin(t * math.pi)) for t in [i / 12.0 for i in range(13)]]
add(K.loft("Shaft", shaft, [0.016] * 13, "staff", IRON, 8), "staff")
add(K.loft("Grip", [HR + G(0.0, -0.1, -0.04), HR + G(0.0, 0.12, -0.04)], [(0.024, 0.024)] * 2, "staff", WOOD, 8), "staff")
tipc = HR + G(0.0, 0.72, -0.1)
bowl = L.lathe("Bowl", [(0.0, -0.075), (0.05, -0.065), (0.085, -0.03), (0.105, 0.015), (0.108, 0.04)], (0.0, 0.0, 0.0), IRON, "staff", nth=20, thick=0.0)
for v in bowl.data.vertices:
    v.co = v.co + tipc
bowl["sock"] = "staff"
bowl["fixed"] = True
objs.append(bowl)
add(K.blob("Molten", tipc + G(0.0, 0.034, 0.0), (0.098, 0.014, 0.098), "staff", MOLTEN, 20, 6), "staff")
for k in range(3):
    a = k * 2.1
    add(K.blob("Drip", tipc + G(math.cos(a) * 0.1, -0.04 - 0.02 * k, math.sin(a) * 0.1), (0.012, 0.03, 0.012), "staff", MOLTEN, 8, 6), "staff")
add(K.loft("TongA", [Vector(G(0.2, 0.97, -0.05)), Vector(G(0.24, 0.7, -0.07)), Vector(G(0.23, 0.46, -0.09))], [(0.01, 0.006)] * 3, "r:pelvis", IRON, 6), "r:pelvis")
add(K.loft("TongB", [Vector(G(0.2, 0.97, -0.07)), Vector(G(0.26, 0.7, -0.07)), Vector(G(0.25, 0.46, -0.07))], [(0.01, 0.006)] * 3, "r:pelvis", IRON, 6), "r:pelvis")
pot_c = Vector(G(-0.24, 0.8, 0.0))
pot = L.lathe("Crucible", [(0.0, -0.09), (0.05, -0.085), (0.075, -0.03), (0.085, 0.03), (0.075, 0.075), (0.082, 0.085)], (0.0, 0.0, 0.0), IRON, "r:pelvis", nth=16, thick=0.0)
for v in pot.data.vertices:
    v.co = v.co + pot_c
pot["fixed"] = True
objs.append(pot)
add(K.loft("PotChain", [Vector(G(-0.2, 0.96, 0.0)), Vector(G(-0.24, 0.9, 0.0))], [0.008, 0.008], "r:pelvis", IRON, 5), "r:pelvis")

if PREVIEW:
    L.preview_sheet(PREVIEW, 0.95, 3.3)
L.report(objs)
print("BIPED", KIND, "parts", len(objs), "tris", sum(L.tri_count(o) for o in objs if o.type == 'MESH'))
if EXPORT:
    GK.export_skinned(objs, MATS, "grunt_" + KIND, S, WTS, {}, 2048, 16500, pairs=PAIRS)
