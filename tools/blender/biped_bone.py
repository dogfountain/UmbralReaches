"""The Ossuary dead (r38 remodel): ossuant and quiller. A dark, dried husk wearing its own bones as armour. The bones are
FITTED, cut from the body's surface (biped_sculpt_lib.Plates): real curved ribs standing off the chest round to a breastbone
plate, a spine of vertebrae with spinous processes, scapula pauldrons with spurs, radius-and-ulna bars on the forearms, a
femur bar and a knee cap and a shin crest on each leg, iliac wings at the hip; a sculpted skull (sockets, cheekbones, nasal
cavity, teeth in two rows) with a halo of rib-antlers; sinew bindings and a belt of finger-bones.

  OSSUANT: asymmetric: a skull trophy on the left shoulder over stacked plates, a ram of fused thigh-bones for a right forearm
           ending in three long claws, knee spurs.
  QUILLER: lighter, hooded in a burial shroud, a quiver of long ribs bristling from its back, a rib drawn in the right hand,
           a bone bracer on the left forearm; the skull bare in the hood (it is the weak point).

  GRUNT_OUT=<dir> tools/blender/run.sh biped_bone.py -- --kind ossuant [--preview /tmp/o.png] [--no-export]
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
import biped_anat as AN
from boss_kit import G

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
KIND = args[args.index("--kind") + 1] if "--kind" in args else "ossuant"
PREVIEW = args[args.index("--preview") + 1] if "--preview" in args else ""
EXPORT = "--no-export" not in args
QUILLER = KIND == "quiller"

K.reset()
BB.fast_ao(16)
BB.lean()
S = dict(K.SOCKETS)
sm = L.smooth

SKIN = GK.hollow_skin("Skin", (0.15, 0.125, 0.105), (0.018, 0.015, 0.013), wet=-0.5, wrinkle=70.0, vein_amt=0.4, liv=(0.78, 0.62, 0.95), extremities=0.0, gain=0.95)   # dried sinew: dark, high contrast
CLAW = GK.grave_bone("Claw", (0.34, 0.3, 0.24), (0.1, 0.07, 0.05), 12.0)
EYE = GK.glow("Eye", (1.0, 0.7, 0.22) if not QUILLER else (0.6, 0.8, 1.0), 8.0)
BONE = GK.grave_bone("Bone", (0.56, 0.45, 0.26) if not QUILLER else (0.6, 0.55, 0.45), (0.2, 0.13, 0.07))
BONE_D = GK.grave_bone("BoneD", (0.3, 0.22, 0.13), (0.1, 0.06, 0.04))
BONE_P = GK.grave_bone("BoneP", (0.62, 0.58, 0.48), (0.24, 0.2, 0.14))
LEATHER = GK.leather("Leather", (0.12, 0.08, 0.06))
_RT = (0.12, 0.1, 0.07) if not QUILLER else (0.045, 0.045, 0.05)
RAG = GK.cloth("Shroud", _RT, "rough_linen", 7.0, _RT, 0.9)     # the hem grime is the cloth's own colour: a darker grime would extrapolate brighter up the body
IRON = GK.iron("Iron", (0.1, 0.095, 0.095), (0.2, 0.085, 0.04))
MATS = [SKIN, CLAW, EYE, BONE, BONE_D, BONE_P, LEATHER, RAG, IRON]

HC = (0, 1.665, -0.035) if not QUILLER else (0, 1.67, -0.07)
OPT = dict(W=1.0 if not QUILLER else 0.92, L=0.7, nk=0.0 if not QUILLER else 0.05, finger=0.14 if not QUILLER else 0.18, wrist=0.74, ribs=0.0, belly=-0.8, collar=1.2, tendon=1.4, hc=HC,
           head_w=0.07, neck_r=0.035, skull=True, nohead=True, cavity=0.045)
def skel(sk):
    if QUILLER:                                          # a marksman: the throwing shoulder raised and set back, the bow side low
        for nm_, f in (("trpr", 0.7), ("dltr", 1.0), ("shr", 1.0), ("ua1r", 0.5)):
            i = sk.arms.idx[nm_]
            x, y, z = sk.arms.p[i]
            sk.arms.p[i] = (x, y, z + 0.04 * f)
        for nm_, f in (("trpl", 0.6), ("dltl", 1.0), ("shl", 1.0)):
            i = sk.arms.idx[nm_]
            x, y, z = sk.arms.p[i]
            sk.arms.p[i] = (x, y, z - 0.03 * f)


def extra(sc, Y, nm):
    AN.muscles(sc, Y, nm, 1.0, lean=0.6)
    AN.joints(sc, Y, nm, 1.0, 0.74, 1.3)
    AN.damage(sc, 21 if QUILLER else 22, count=40, amp=0.008)


ctx = BB.body(OPT, SKIN, CLAW, EYE, claw=0.06, teeth=False, eyes=False, body_tris=3200 if QUILLER else 3400, arm_tris=1200 if QUILLER else 1300, extra=extra, skel=skel)
objs, PAIRS = ctx.objs, ctx.pairs
Y = ctx.Y
WTS = BW.base_weights(ctx, S, neck=OPT["nk"])
WTS["skull"] = lambda p: {"head": 1.0}
WTS["skirt"] = BW.skirt_weights(WTS, y_hip=0.9, y_knee=0.45, spread=0.8, knee_part=0.5, torso_from=0.95)
HB, HA = ctx.hi["Body"], ctx.hi["Arms"]
bones = L.Plates(HB, HB, HA, HA, fine=True)


def fx_(o):
    o["fixed"] = True
    return o


def add(o, sock=None):
    if sock:
        o["sock"] = sock
    objs.append(o)
    return o


# --- the skull: its own sculpted surface, baked like the body ---------------------------------------------------------------------------
_shi = GB.build_skin(GB.skull_part(OPT, Y), "SkullHigh", "a", 0.004)
_ss = GB.Sculpt(_shi)
GB.head_sculpt(_ss, OPT, Y)
_ss.noise(45.0, 0.0015)
_ss.folds(95.0, 0.0006)
_ss.apply()
_shi.data.materials.append(BONE.m)
_shi.hide_render = True
_shi.hide_viewport = True
_slo = GB.make_low(_shi, 1100, "SkullLow")
_slo["sock"] = "skull"
_slo["fixed"] = True
PAIRS.append((_slo, _shi))
objs.append(_slo)
hy, hz = Y(HC[1]), HC[2]
for row, (dy, sgn) in enumerate(((-0.062, -1), (-0.074, 1))):                 # teeth, both rows
    for k in range(11):
        a = math.pi * (0.14 + 0.72 * k / 10.0)
        base = Vector(G(math.cos(a) * 0.036, hy + dy, hz - 0.052 - math.sin(a) * 0.03))
        add(K.loft("Tooth", [base, base + Vector(G(0, -sgn * 0.02, 0))], [0.0052, 0.0], "head", CLAW, 5, cap0=False), "head")
for sx in (-1, 1):
    add(K.blob("Eye", Vector(G(sx * 0.034, hy + 0.012, hz - 0.052)), (0.008, 0.005, 0.008), "head", EYE, 10, 6), "head")

# --- bone cut from the body: ribs, sternum, hips, limbs ----------------------------------------------------------------------------------
n_rib = 9
for i in range(n_rib):
    y0 = 1.44 - 0.04 * i

    def rib_sel(P, N, y0=y0, i=i):
        front = np.clip(-P[:, 2] / 0.11, 0.0, 1.0)
        yc = y0 - 0.055 * front * (0.6 + 0.1 * i)
        band = 0.025 - np.abs(P[:, 1] - yc)
        gap = np.where(P[:, 2] < -0.02, np.abs(P[:, 0]) - (0.034 + 0.002 * i), 1.0)     # the breastbone stands between the ribs' ends
        return np.minimum(band, gap)
    bones.keep(rib_sel, (lambda i: lambda P, N: 0.04 - 0.0012 * i + (0.008 if i % 2 else 0.0) + 0.0 * P[:, 0])(i), 0.02, mat=BONE if i % 3 else BONE_P, bevel=0.006, name="Rib",
               folds=lambda P, N: 0.006 * np.sin(np.arctan2(P[:, 0], -P[:, 2]) * 24.0) * (1.0 + 0.5 * np.sin(P[:, 1] * 40.0)))      # knuckled, carved ribs
bones.keep(lambda P, N: np.where((P[:, 2] < -0.04) & (np.abs(P[:, 0]) < 0.036) & (P[:, 1] > 1.2) & (P[:, 1] < 1.47), np.minimum(0.036 - np.abs(P[:, 0]), (P[:, 1] - 1.2)), -1.0),
           0.05, 0.016, mat=BONE_P, bevel=0.005, name="Sternum")
bones.keep(lambda P, N: np.where((P[:, 2] > 0.03) & (P[:, 1] > 0.98) & (P[:, 1] < 1.51), np.minimum(0.021 - np.abs(P[:, 0]), np.minimum(P[:, 1] - 0.98, 1.51 - P[:, 1])), -1.0),
           lambda P, N: 0.03 + 0.012 * (np.abs(np.sin(P[:, 1] * math.pi / 0.043)) ** 0.6), 0.012, mat=BONE_D, bevel=0.003, name="Spine")      # a column of vertebrae
for k in range(13):                                                              # a spinous process on each
    add(GK.claw("Spinous", Vector(G(0.0, 1.49 - 0.043 * k, 0.118)), Vector(G(0, 0.25 + 0.03 * (k % 2), 1.0)), 0.045 + 0.01 * (k % 3), 0.011, "r:chest", BONE_D, -0.2), "r:chest")
bones.keep(lambda P, N: np.where((P[:, 1] > 0.78) & (P[:, 1] < 0.99) & (np.abs(P[:, 0]) > 0.08) & (N[:, 2] > -0.5), np.minimum(P[:, 1] - 0.78, 0.99 - P[:, 1]), -1.0),
           0.034, 0.012, mat=BONE_D, bevel=0.004, name="Iliac")        # the hip wings
for sx in (-1, 1):
    def seg(a, b, w, sx=sx):
        a, b = np.array(a, dtype=np.float32), np.array(b, dtype=np.float32)
        ab = b - a
        L2 = float(ab @ ab)

        def f(P, N):
            t = np.clip(((P - a) @ ab) / L2, 0.0, 1.0)
            d = np.linalg.norm(P - (a + t[:, None] * ab), axis=1)
            fr = N[:, 2] < 0.35
            return np.where(fr, w - d, -1.0)
        return f
    bones.keep(lambda P, N, sx=sx: np.where(P[:, 0] * sx > 0.02, np.minimum(P[:, 1] - 0.4, 0.76 - P[:, 1]) * (N[:, 2] < 0.6), -1.0), lambda P, N: 0.026 + 0.01 * np.abs(np.sin(P[:, 1] * 30.0)), 0.018, mat=BONE, bevel=0.005, name="Femur")
    kc = np.array([sx * 0.11, 0.345, -0.045], dtype=np.float32)
    bones.keep((lambda kc: lambda P, N: np.where(np.linalg.norm(P - kc, axis=1) < 0.052, 1.0, -1.0))(kc), 0.03, 0.012, mat=BONE_P, bevel=0.004, name="Patella")
    bones.keep(seg((sx * 0.11, 0.29, -0.05), (sx * 0.11, 0.09, -0.035), 0.034), lambda P, N: 0.026 + 0.0 * P[:, 0], 0.014, mat=BONE, bevel=0.005, name="Tibia")
    bones.keep(lambda P, N, sx=sx: np.where((P[:, 0] * sx > 0.17) & (P[:, 1] > 0.78) & (P[:, 1] < 1.05) & (N[:, 0] * sx > 0.15),
                                            np.minimum(0.026 - np.abs(P[:, 2]), np.minimum(P[:, 1] - 0.78, 1.05 - P[:, 1])), -1.0),
               0.018, 0.01, on="arms", mat=BONE, bevel=0.003, name="Ulna")                      # a forearm bar along the outer edge
    for (cy, rx, ry, rz, of_, nm_, mt_) in ((1.44, 0.14, 0.11, 0.13, 0.05, "Scapula", BONE), (1.3, 0.125, 0.085, 0.12, 0.044, "Scapula2", BONE_D), (1.18, 0.105, 0.07, 0.1, 0.038, "Scapula3", BONE)):
        bones.keep((lambda cy, rx, ry, rz, sx: lambda P, N: 1.0 - np.sqrt(((P[:, 0] - sx * 0.27) / rx) ** 2 + ((P[:, 1] - cy) / ry) ** 2 + (P[:, 2] / rz) ** 2))(cy, rx, ry, rz, sx),
                   of_, 0.017, on="arms", mat=mt_, bevel=0.006, name=nm_)                      # shoulder blades, worn as stacked pauldrons
for sx in (-1, 1):                                                              # bundled long bones down each shin and thigh, and bound-on bands
    for dx in (-0.022, 0.0, 0.022):
        for (ya, yb, nm_) in ((0.1, 0.3, "ShinBone"), (0.42, 0.74, "ThighBone")):
            bones.keep((lambda dx, ya, yb, sx: lambda P, N: np.where((P[:, 2] < 0.0) & (P[:, 1] > ya) & (P[:, 1] < yb), 0.011 - np.hypot(P[:, 0] - sx * (0.11 + dx), 0.0 * P[:, 2]), -1.0))(dx, ya, yb, sx),
                       0.034, 0.012, mat=BONE_P if dx == 0.0 else BONE, bevel=0.004, name=nm_)
    for yy in (0.13, 0.25, 0.46, 0.6):
        bones.keep((lambda yy, sx: lambda P, N: np.where(P[:, 0] * sx > 0.02, 0.018 - np.abs(P[:, 1] - yy), -1.0))(yy, sx), 0.048, 0.012, mat=BONE_D, bevel=0.004, name="Band")
bones.finish(4200, "stiff", PAIRS, objs, "Bones")

# sinew bindings (bandage wound round the limbs, a spiral ridge on a thin band) and the belt of finger-bones
# (no hoops and no wound bandages: bands are plates cut from the leg itself, fused to it)
add(L.band_loop("Belt", (0, 0.93, 0.0), 0.19, 0.15, 0.02, LEATHER, "r:pelvis", n=40, sides=6, squash=0.5), "r:pelvis")
for k in range(9):
    a = -1.5 + 3.0 * k / 8.0
    o = Vector(G(math.sin(a) * 0.19, 0.92, -math.cos(a) * 0.15))
    out = Vector(G(math.sin(a) * 0.1, -1.0, -math.cos(a) * 0.1)).normalized()
    add(K.bone("Fing", o, o + out * (0.2 + 0.05 * (k % 3)), 0.011, "r:pelvis", BONE if k % 2 else BONE_D, 1.7, 8, 8, k), "r:pelvis")
for k in range(9):                                                                 # a tabard of burial-linen tatters, front and back
    a = math.tau * (k + 0.5) / 9.0
    root = Vector(G(math.cos(a) * 0.19, 0.84, math.sin(a) * 0.15))
    out = Vector((math.cos(a), -math.sin(a), 0.0))
    Ln = 0.3 * (0.7 + 0.5 * ((k * 7) % 5) / 4.0)
    pts = [root + out * (0.01 + 0.04 * t * t) + Vector((0, 0, -Ln * t)) for t in [i / 7.0 for i in range(8)]]
    add(GK.strip("Cloth", pts, 0.075, 0.006, "skirt", RAG, taper=0.5, sides=4), "skirt")

# --- a crest of ribs growing from the spine and arching over the skull -----------------------------------------------------------------------------
Hc = Vector(G(*HC))
for k in range(9 if not QUILLER else 0):
    x = (k - 4) * 0.032
    ys = 1.3 + 0.018 * abs(k - 4)
    pts = [G(x * 0.35, ys, 0.115), G(x * 0.8, ys + 0.25, 0.2 + 0.02 * abs(k - 4)), G(x * 1.5, 1.98 + 0.05 * (4 - abs(k - 4)) / 4.0, 0.14), G(x * 2.0, 2.12 + 0.07 * (4 - abs(k - 4)) / 4.0, -0.02)]
    add(fx_(K.curve_tube("CrestRib", [Vector(p) for p in pts], 0.019, "r:chest", BONE_D if k % 2 else BONE_P, [1.0, 0.95, 0.7, 0.2])), "r:chest")

if not QUILLER:
    # a skull trophy on the left shoulder over stacked plates, a ram of fused thigh-bones for the right forearm, knee spurs
    Sl = S["shoulder_l"]
    def cranium(c):                                                              # unit sphere -> a skull: narrow at the jaw, full at the temples
        p = Vector(c)
        if p.z < 0.0:
            p.x *= 1.0 + 0.32 * p.z
            p.y *= 1.0 + 0.2 * p.z
        p.x *= 1.0 - 0.1 * max(p.y, 0.0)
        return p
    tc = Sl + G(-0.03, 0.12, -0.04)
    add(K.blob("Trophy", tc, (0.07, 0.08, 0.075), "r:shoulder_l", BONE_P, 28, 18, cranium), "r:shoulder_l")
    add(K.blob("Brow", tc + G(0, 0.022, -0.05), (0.07, 0.013, 0.016), "r:shoulder_l", BONE_P, 16, 8), "r:shoulder_l")
    add(K.blob("Jaw", tc + G(0, -0.075, -0.03), (0.05, 0.03, 0.04), "r:shoulder_l", BONE_P, 14, 8), "r:shoulder_l")
    for sx in (-1, 1):
        add(K.blob("Socket", tc + G(sx * 0.03, 0.002, -0.058), (0.024, 0.02, 0.016), "r:shoulder_l", IRON, 12, 8), "r:shoulder_l")
        add(K.blob("Eye", tc + G(sx * 0.03, 0.002, -0.068), (0.012, 0.009, 0.007), "r:shoulder_l", EYE, 8, 6), "r:shoulder_l")
    for k in range(8):
        add(GK.claw("Tooth", tc + G((k - 3.5) * 0.012, -0.055, -0.066), G(0, -1.0, -0.1), 0.02, 0.0045, "r:shoulder_l", BONE_P, 0.0), "r:shoulder_l")
    Er, Hr = S["elbow_r"], S["hand_r"]                                           # a ram of bundled long bones for the right forearm, bound, ending in claws
    for j in range(6):
        a_ = math.tau * j / 6.0
        o = G(0.0, 0.0, 0.0)
        off = Vector(G(math.cos(a_) * 0.034, 0.0, math.sin(a_) * 0.034))
        add(fx_(K.bone("Ram", Er + off + Vector(G(0, -0.01, 0)), Hr + off * 1.25 + Vector(G(0, -0.2, -0.06)), 0.03, "arm_r", BONE if j % 2 else BONE_P, 1.7, 8, 8, j)), "arm_r")
    for yy in (-0.12, -0.3, -0.48):
        add(fx_(L.band_loop("RamBand", (Er.x, Er.z * 0 + (1.08 + yy), -0.0), 0.062, 0.062, 0.011, LEATHER, "arm_r", n=18, sides=5)), "arm_r")
    for k in range(3):
        add(fx_(GK.claw("Claw", Hr + G(0.034 * (k - 1), -0.22, -0.08), G(0.0, -0.45, -1.0), 0.26, 0.022, "arm_r", BONE_P, 0.35)), "arm_r")
    for tag, sx in (("l", -1), ("r", 1)):
        add(GK.claw("Spur", S["knee_" + tag] + G(sx * 0.03, 0.02, -0.04), G(sx * 0.6, 0.2, -1.0), 0.1, 0.014, "r:knee_" + tag, BONE_P, -0.2), "r:knee_" + tag)
else:
    # a burial shroud hood and mantle (torn), a quiver of long ribs bristling from the back, a rib drawn in the right hand, a bone bracer left
    hd = L.hood("HoodHigh", (HC[0], 1.69, HC[2] + 0.012), RAG, "hood", size=(0.12, 0.138, 0.13), face_r=(0.062, 0.082), face_dy=-0.024, peak=0.02, back_drop=0.22, lip=0.012, seed=5.0, amp=0.007)
    L.hi_lo(hd, 800, "HoodLow", "hood", PAIRS, objs)
    WTS["hood"] = lambda p: {"head": float(sm(1.5, 1.62, p.z)), "chest": float(1.0 - sm(1.5, 1.62, p.z))}
    mk = [(1.575, 0, -0.03, 0.1, 0.09, 0.1, 2.0), (1.52, 0, 0.0, 0.2, 0.13, 0.14, 2.0), (1.43, 0, 0.012, 0.29, 0.16, 0.18, 2.1), (1.28, 0, 0.012, 0.3, 0.17, 0.19, 2.0), (1.12, 0, 0.01, 0.3, 0.175, 0.2, 2.0)]
    _mh0 = L.ragged_hem(1.2, 0.08, seed=6.0, cuts=0.12, scallop=0.05, nscal=11)

    def mh(th):                                          # asymmetric: it falls long on the bow side, short and clear over the throwing arm
        return _mh0(th) - 0.22 * np.exp(-((np.abs(((th - math.pi) + math.pi) % math.tau - math.pi)) / 0.9) ** 2) + 0.1 * np.sin(th)
    md = L.Drape(mk, 1.575, mh, y_fold0=1.5, y_hem_ref=1.1, amp=0.14, waves=L.Waves(seed=11, counts=(3, 6, 10, 17), amps=(1.0, 0.7, 0.4, 0.18)), nth=160, dy=0.008, flare=0.02, seed=6.0)
    L.drape_pair("Mantle", md.points(), RAG, "mantle", 1000, PAIRS, objs, thick=0.007)
    WTS["mantle"] = BW.GB.envelope_weights(ctx.segs, band=0.11, power=1.5)
    # the quiver: a bound sheaf of ribs on the back, lashed with leather and a sling across the chest
    for k in range(11):
        a_ = math.tau * k / 11.0
        r_ = 0.03 + 0.012 * (k % 2)
        base = Vector(G(0.08 + math.cos(a_) * r_, 0.95, 0.22 + math.sin(a_) * r_))
        top = Vector(G(0.02 + math.cos(a_) * (0.035 + 0.02 * (k % 3)), 1.78 + 0.05 * (k % 3), 0.2 + math.sin(a_) * (0.03 + 0.015 * (k % 3))))
        add(fx_(K.bone("Quill", base, top, 0.013, "r:chest", BONE_P if k % 2 else BONE, 1.5, 8, 10, k)), "r:chest")
    for yy, rr in ((1.08, 0.055), (1.3, 0.056), (1.52, 0.058)):
        add(fx_(L.band_loop("Lash", (0.06 - 0.02 * (yy - 1.0), yy, 0.215), rr, rr * 0.9, 0.013, LEATHER, "r:chest", n=20, sides=5)), "r:chest")
    add(K.loft("Sling", [Vector(G(0.07, 1.45, 0.17)), Vector(G(-0.1, 1.38, 0.0)), Vector(G(-0.17, 1.28, -0.1)), Vector(G(-0.04, 1.1, -0.16)), Vector(G(0.12, 0.95, -0.04)), Vector(G(0.09, 1.0, 0.18))], [(0.022, 0.007)] * 6, "r:chest", LEATHER, 5), "r:chest")
    Hr = S["hand_r"]                                                             # the drawn rib: a long curved shaft in the fist
    pts = [Hr + G(0.02, -0.12 + 0.62 * t, -0.04 - 0.1 * math.sin(t * math.pi)) for t in [i / 12.0 for i in range(13)]]
    add(K.curve_tube("Rib", pts, 0.018, "r:hand_r", BONE_P, [1.0 - 0.8 * t ** 2 for t in [i / 12.0 for i in range(13)]]), "r:hand_r")
    for k in range(3):
        add(K.blob("Wrap", Hr + G(0.02, -0.06 - 0.025 * k, -0.04), (0.026, 0.01, 0.026), "r:hand_r", LEATHER, 10, 6), "r:hand_r")
    El = S["elbow_l"]
    add(K.loft("Bracer", [El + G(0, -0.06, 0), El + G(0, -0.2, 0), El + G(0, -0.32, 0)], [(0.05, 0.05), (0.044, 0.044), (0.038, 0.038)], "arm_l", BONE_D, 12), "arm_l")

if PREVIEW:
    L.preview_sheet(PREVIEW, 0.95, 3.3)
L.report(objs)
print("BIPED", KIND, "parts", len(objs), "tris", sum(L.tri_count(o) for o in objs if o.type == 'MESH'))
if EXPORT:
    GK.export_skinned(objs, MATS, "grunt_" + KIND, S, WTS, {}, 2048, 16000, pairs=PAIRS)
