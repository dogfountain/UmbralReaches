"""Humanoid grunts (r30): wretch, husk, spitter, ossuant, bulwark, chanter. Modelled in the HunchRig
rest pose (the same sockets as boss_kit.SOCKETS: arms and legs hanging straight), flesh as fused
metaball muscle with a mass on every joint pivot, cloth simulated, one baked atlas per kind, one
mesh per socket.

  tools/blender/run.sh grunt_humanoid.py -- --kind wretch [--preview /tmp/w.png] [--no-export]
Writes art/models/grunt_<kind>.glb and art/textures/grunt_<kind>_{albedo,normal,orm,emit}.png
"""
import bpy
import bmesh
import math
import os
import sys
from mathutils import Vector, noise

sys.path.insert(0, os.path.dirname(__file__))
import boss_kit as K
import grunt_kit as GK
from boss_kit import G
from grunt_kit import Flesh

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
KIND = args[args.index("--kind") + 1] if "--kind" in args else "wretch"
PREVIEW = args[args.index("--preview") + 1] if "--preview" in args else ""
EXPORT = "--no-export" not in args

K.reset()
S = dict(K.SOCKETS)

# --- per-kind build -------------------------------------------------------------------------------
#  w      torso width        lr  limb radius     belly  bloat (0 gaunt .. 1 husk)
#  hs     head scale         claw  claw length   neck   forward reach of the neck
P = {
    "wretch":  dict(w=0.92, lr=0.82, belly=0.0, hs=1.0, claw=0.11, neck=0.03, ribs=True,
                    skin=((0.17, 0.15, 0.155), (0.045, 0.035, 0.04)), face=(0.6, 0.55, 0.48), eye=(1.0, 0.36, 0.08)),
    "husk":    dict(w=1.25, lr=1.4, belly=1.0, hs=0.82, claw=0.05, neck=0.0, ribs=False,
                    skin=((0.43, 0.44, 0.25), (0.14, 0.13, 0.06)), face=None, eye=(1.0, 0.5, 0.12)),
    "spitter": dict(w=0.85, lr=0.72, belly=0.0, hs=0.95, claw=0.06, neck=0.16, ribs=True,
                    skin=((0.6, 0.64, 0.56), (0.22, 0.27, 0.22)), face=None, eye=(0.25, 1.0, 0.75)),
    "ossuant": dict(w=1.08, lr=1.15, belly=0.25, hs=0.95, claw=0.06, neck=0.0, ribs=False,
                    skin=((0.2, 0.15, 0.13), (0.06, 0.04, 0.035)), face=None, eye=(1.0, 0.7, 0.22)),
    "bulwark": dict(w=1.3, lr=1.45, belly=0.55, hs=0.9, claw=0.04, neck=0.0, ribs=False,
                    skin=((0.3, 0.29, 0.3), (0.09, 0.085, 0.09)), face=None, eye=(1.0, 0.42, 0.1)),
    "chanter": dict(w=0.82, lr=0.7, belly=0.0, hs=0.92, claw=0.08, neck=0.06, ribs=True,
                    skin=((0.4, 0.42, 0.44), (0.12, 0.12, 0.15)), face=(0.62, 0.6, 0.55), eye=(0.45, 1.0, 0.3)),
}[KIND]
W, LR, BELLY, HS = P["w"], P["lr"], P["belly"], P["hs"]
SEED = float(sum(ord(c) for c in KIND))

SKIN = GK.skin("Skin", P["skin"][0], P["skin"][1], wrinkle=70.0 if KIND != "husk" else 40.0,
               wet=0.45 if KIND == "spitter" else 0.0, rough=0.7 if KIND in ("ossuant", "husk") else 0.62)
# models pass: the face grades into the body's skin down the jaw and nape (it read as a mask stuck on)
_HY = 1.705 - (0.04 if BELLY > 0.5 else 0.0)
FACE = GK.skin("Face", P["face"], tuple(c * 0.35 for c in P["face"]), wrinkle=90.0, rough=0.6,
               fade=(P["skin"][0], _HY - 0.1 * HS, _HY - 0.01 * HS)) if P["face"] else SKIN
CLAW = GK.bone("Claw", (0.42, 0.36, 0.28), (0.1, 0.07, 0.05), 12.0)
EYE = GK.glow("Eye", P["eye"], 8.0)
MATS = [SKIN, CLAW, EYE] + ([FACE] if FACE is not SKIN else [])
objs = []
KEEP = {"Eye", "Glow", "Hair", "Cloth", "Robe", "Linen", "Iron", "Wood", "Leather", "Gland", "Seam"}


def add(o):
    objs.append(o)
    return o


def mat(m):
    if m not in MATS:
        MATS.append(m)
    return m


def g(x, y, z):
    return G(x, y, z)


# --- pieces + skin weights ---------------------------------------------------------------------------
# "torso", "head", "arm_l/r", "leg_l/r" are continuous flesh; "r:<bone>" is rigid on one bone;
# "pelcloth" hangs from the pelvis and follows the legs; "chcloth" rides the chest and shoulders.
P0, C0 = S["pelvis"], S["chest"]
WAIST = g(0, 1.02, 0)
NECK = g(0, 1.63, -0.02 - P["neck"])


def _rigid(bone):
    return lambda p: {bone: 1.0}


def _pelcloth(p):
    y = p.z                                    # Blender z = up
    w = {"pelvis": 1.0}
    for tag, sx in (("l", -1.0), ("r", 1.0)):
        side = GK._smooth(-0.03, 0.1, p.x * sx)
        a = GK._smooth(0.86, 0.4, y) * 0.8 * side
        b = GK._smooth(0.42, 0.12, y) * 0.55 * side
        if a > 0.0:
            w["hip_" + tag] = a * (1.0 - b)
            if b > 0.0:
                w["knee_" + tag] = a * b
            w["pelvis"] -= a
    w["pelvis"] = max(w["pelvis"], 0.0)
    t = sum(w.values()) or 1.0
    return {k: v / t for k, v in w.items()}


def _chcloth(p):
    w = {"chest": 1.0}
    for tag, sx in (("l", -1.0), ("r", 1.0)):
        a = GK._smooth(0.12, 0.24, p.x * sx) * 0.6
        if a > 0.0:
            w["shoulder_" + tag] = a
            w["chest"] -= a
    h = GK._smooth(1.52, 1.64, p.z) * 0.7                # a collar follows the head
    if h > 0.0:
        w["head"] = h * w["chest"]
        w["chest"] *= 1.0 - h
    return w


WEIGHTS = {
    "torso": lambda p: GK.chain_w(p, [("pelvis", P0), ("chest", WAIST), ("head", NECK)], [0.075, 0.035]),
    "head": lambda p: GK.chain_w(p, [("chest", C0), ("head", NECK + G(0, -0.01, 0))], 0.025),
    "pelcloth": _pelcloth,
    "chcloth": _chcloth,
}
for tag in ("l", "r"):
    WEIGHTS["arm_" + tag] = (lambda t: lambda p: GK.chain_w(p, [("chest", C0), ("shoulder_" + t, S["shoulder_" + t] + G(0, 0.035, 0)),
                                                                ("elbow_" + t, S["elbow_" + t]), ("hand_" + t, S["hand_" + t])], [0.03, 0.04, 0.028]))(tag)
    WEIGHTS["leg_" + tag] = (lambda t: lambda p: GK.chain_w(p, [("pelvis", P0), ("hip_" + t, S["hip_" + t] + G(0, 0.03, 0)),
                                                                ("knee_" + t, S["knee_" + t]), ("foot_" + t, S["foot_" + t])], [0.04, 0.045, 0.03]))(tag)
for bn in S:
    WEIGHTS["r:" + bn] = _rigid(bn)


def build(fl, name, m, res=0.0065, rough=0.0015, seed=0.0):
    ob = fl.build(name, m, res, rough, SEED + seed)
    print("FLESH", name, len(ob.data.vertices))
    return add(ob)


# --- torso: hips, glutes, belly, ribcage, back, shoulders, neck ------------------------------------
to = Flesh("torso")
to.ball(g(0, 0.93, 0.0), (0.135 * W, 0.1, 0.095 * W))
for sx in (-1, 1):
    to.ball(g(sx * 0.075 * W, 0.87, 0.05), (0.07 * W, 0.08, 0.065))                 # glutes
    to.ball(g(sx * 0.13 * W, 0.98, 0.0), (0.035, 0.03, 0.045), 4.0)                # iliac crests
to.ball(g(0, 1.03, -0.01), (0.115 * W, 0.1, 0.085 * W))                            # waist
if KIND in ("wretch", "chanter", "spitter"):
    to.ball(g(0, 1.13, 0.005), (0.09 * W, 0.08, 0.068 * W))                        # pinched, starved waist
cage_c = g(0, 1.31, 0.0)
cage = (0.145 * W, 0.17, 0.11 * W)
to.ball(cage_c, cage)
to.ball(g(0, 1.39, 0.035), (0.135 * W, 0.1, 0.085))                                # upper back
for sx in (-1, 1):
    to.ball(g(sx * 0.11 * W, 1.47, 0.025), (0.085 * W, 0.04, 0.055), 2.0)         # trapezius
    to.ball(g(sx * 0.2, 1.42, 0.0), (0.055 * LR, 0.055 * LR, 0.055 * LR))          # shoulder cap
    to.ball(g(sx * 0.095 * W, 1.34, 0.095), (0.065, 0.085, 0.022), 3.0)            # shoulder blades
    to.ball(g(sx * 0.115 * W, 1.18, -0.01), (0.045, 0.08, 0.055))                  # flanks
    if BELLY > 0.3 or KIND == "ossuant":
        to.ball(g(sx * 0.08 * W, 1.37, -0.065), (0.07 * W, 0.05, 0.03), 3.0)      # heavy pectorals (big kinds only)
if BELLY > 0.0:
    bb = BELLY * 0.62                         # (at full it read as a sack, not a gut)
    to.ball(g(0, 1.1, -0.08 - 0.06 * bb), (0.19 * bb + 0.07, 0.17 * bb + 0.06, 0.15 * bb + 0.05))
    to.ball(g(0, 0.96 + 0.02 * bb, -0.08 - 0.06 * bb), (0.2 * bb + 0.07, 0.14 * bb + 0.05, 0.14 * bb + 0.05))
    to.ball(g(0, 0.88, -0.09 * bb - 0.04), (0.16 * bb + 0.05, 0.055, 0.1 * bb + 0.04), 3.0)   # the overhang
    to.ball(g(0, 1.3, -0.04), (0.17 * W, 0.15, 0.12 * W))
to.chain([g(0, 1.42, 0.03), g(0, 1.53, 0.0 - P["neck"] * 0.45), NECK + G(0, 0.02, 0)], [0.058 * W, 0.05, 0.046], 2.0)
for sx in (-1, 1):
    to.along(g(sx * 0.03, 1.44, -0.05), g(sx * 0.03, 1.61, -0.035 - P["neck"]), 0.016, None, 2.0)   # neck cords
    # models pass: the sternocleidomastoid, from behind the ear down to the notch of the collarbones
    to.along(g(sx * 0.055, 1.62, -0.0 - P["neck"]), g(sx * 0.015, 1.455, -0.07), 0.011, None, 3.0)
build(to, "Torso", SKIN, 0.0065, 0.0018, 1)
if P["ribs"]:
    # ribs under the skin, following the ribcage and sloping down toward the front
    for i in range(5):
        y = 1.39 - 0.05 * i
        k = math.sqrt(max(0.05, 1.0 - ((y - 1.31) / 0.17) ** 2))
        for sx in (-1, 1):
            pts = []
            for j in range(10):
                a = 0.35 + 2.3 * j / 9.0
                pts.append(g(sx * math.sin(a) * cage[0] * k * 0.97, y - 0.05 * (1.0 - math.cos(a)) * 0.5, cage[2] * k * 0.97 * math.cos(a)))
            add(K.loft("Rib", pts, [0.007] * 10, "torso", SKIN, 6))
for j in range(9):
    t = j / 8.0
    add(K.blob("Vert", g(0, 1.06 + t * 0.46, 0.085 + 0.025 * math.sin(t * math.pi) + 0.03 * BELLY), (0.015, 0.013, 0.012), "torso", SKIN, 10, 6))
for sx in (-1, 1):
    add(K.loft("Clavicle", [g(sx * 0.02, 1.45, -0.075), g(sx * 0.11, 1.47, -0.065), g(sx * 0.2, 1.45, -0.02)], [0.009, 0.01, 0.011], "torso", SKIN, 8))

# --- head ------------------------------------------------------------------------------------------
HC = g(0, 1.705 - (0.04 if BELLY > 0.5 else 0.0), -0.035 - P["neck"])
hd = Flesh("head")
hd.ball(HC + Vector((0, -0.005, 0.012)) * HS, (0.08 * HS, 0.095 * HS, 0.09 * HS))             # cranium (Blender: +y front)
hd.ball(HC + Vector((0, 0.045, -0.035)) * HS, (0.058 * HS, 0.065 * HS, 0.062 * HS))           # face
hd.chain([HC + Vector((-0.055, 0.0, -0.035)) * HS, HC + Vector((0, 0.08, -0.085)) * HS, HC + Vector((0.055, 0.0, -0.035)) * HS],
         [0.024 * HS, 0.03 * HS, 0.024 * HS], 2.0)                                             # jaw, slung low
hd.ball(HC + Vector((0, -0.01, -0.08)) * HS, (0.045, 0.04, 0.045), 2.0)                       # nape (overlaps the neck)
for sx in (-1, 1):
    hd.ball(HC + Vector((sx * 0.058, 0.055, -0.01)) * HS, (0.02, 0.022, 0.016), 4.0)          # cheekbones
    hd.ball(HC + Vector((sx * 0.032, 0.083, 0.022)) * HS, (0.021, 0.017, 0.014), 2.0, None, True)   # eye sockets (cut)
    hd.ball(HC + Vector((sx * 0.078, -0.005, 0.0)) * HS, (0.012, 0.022, 0.03), 4.0)           # ears
hd.ball(HC + Vector((0, 0.083, 0.045)) * HS, (0.068 * HS, 0.022, 0.016), 4.0)                 # brow ridge
hd.ball(HC + Vector((0, 0.1, -0.005)) * HS, (0.012, 0.016, 0.024), 4.0)                       # nose bridge
hd.ball(HC + Vector((0, 0.1, -0.055)) * HS, (0.032, 0.03, 0.013), 2.0, None, True)            # open mouth (cut)
build(hd, "Head", FACE if P["face"] else SKIN, 0.005, 0.0012, 2)
for sx in (-1, 1):
    add(K.blob("Eye", HC + Vector((sx * 0.032, 0.08, 0.02)) * HS, (0.012, 0.008, 0.008), "head", EYE, 12, 8))
for row, z, sgn in ((0, -0.04, -1), (1, -0.07, 1)):
    for k in range(7):
        a = math.pi * (0.2 + 0.6 * k / 6.0)
        base = HC + Vector((math.cos(a) * 0.035, 0.06 + math.sin(a) * 0.035, z)) * HS
        add(K.loft("Tooth", [base, base + Vector((0, 0.003, sgn * 0.02))], [0.005, 0.0], "head", CLAW, 6, cap0=False))

# --- arms: one continuous limb each, shoulder ball to finger tips ---------------------------------------
fingers = 3 if KIND in ("husk", "bulwark") else 4
heavy = 1.35 if KIND in ("husk", "bulwark") else 1.0
fore = 0.9 if heavy > 1.0 else 1.0
for tag, sx in (("l", -1), ("r", 1)):
    Sh, El, Hd = S["shoulder_" + tag], S["elbow_" + tag], S["hand_" + tag]
    pc = "arm_" + tag
    ar = Flesh(pc)
    ar.ball(Sh + G(sx * 0.005, 0.0, 0), (0.06 * LR, 0.065 * LR, 0.062 * LR))                   # deltoid round the pivot
    ar.ball(Sh + G(sx * 0.012, -0.07, 0.0), (0.05 * LR, 0.06, 0.05 * LR))
    ar.along(Sh + G(0, -0.09, -0.018 * LR), El + G(0, 0.07, -0.012), (0.037 * LR, 0.033 * LR), None)   # biceps
    ar.along(Sh + G(0, -0.06, 0.018 * LR), El + G(0, 0.04, 0.012), (0.04 * LR, 0.037 * LR), None)      # triceps
    ar.chain([Sh + G(0, -0.05, 0), El], [0.04 * LR, 0.03 * LR])
    ar.ball(El + G(0, 0.0, 0.012), (0.03 * LR, 0.034, 0.03 * LR))                               # elbow
    ar.ball(El + G(0, -0.005, 0.03), (0.016, 0.02, 0.014), 4.0)                                 # olecranon
    ar.along(El + G(sx * 0.008, -0.03, -0.012), Hd + G(0, 0.09, -0.004), (0.036 * LR * fore, 0.03 * LR), None)   # flexors
    ar.chain([El + G(0, -0.02, 0), Hd + G(0, 0.02, 0)], [0.03 * LR, 0.021 * LR * heavy])
    ar.ball(Hd, (0.022 * LR * heavy, 0.024, 0.019 * LR * heavy))                                 # wrist
    if KIND in ("wretch", "chanter", "spitter", "ossuant"):
        # models pass: the starved forearm shows its tendons from the mid-forearm to the wrist
        for k in range(3):
            ox = (k - 1) * 0.008
            ar.along(El + G(ox, -0.12, -0.022), Hd + G(ox * 0.7, 0.018, -0.016), 0.0045, None, 4.0)
    ar.ball(Hd + G(0, -0.05, -0.006), (0.033 * heavy, 0.04, 0.015 * heavy), 3.0)                # palm
    build(ar, "Arm_" + tag, SKIN, 0.0055, 0.0015, 3)
    flen = (0.075 if heavy > 1.0 else 0.1) * (1.25 if KIND in ("wretch", "chanter") else 1.0)
    for f in range(fingers):
        fx = (f - (fingers - 1) * 0.5) * 0.019 * heavy
        a0 = Hd + G(fx, -0.075, -0.008)
        a1 = a0 + G(fx * 0.25, -flen * 0.45, -0.012)
        a2 = a1 + G(fx * 0.1, -flen * 0.35, -0.02)
        a3 = a2 + G(0, -flen * 0.2, -0.02)
        r = 0.0085 * heavy
        add(K.loft("Finger", [a0, a1, a2, a3], [r, r * 0.85, r * 0.75, r * 0.6], pc, SKIN, 8))
        for kn in (a1, a2):
            add(K.blob("Knuckle", kn, (r * 1.05, r * 1.05, r * 1.05), pc, SKIN, 8, 6))
        if P["claw"] > 0.0:
            add(GK.claw("Claw", a3, (a3 - a2).normalized() + G(0, 0, -0.25), P["claw"], 0.0055 * heavy, pc, CLAW, 0.55))
    t0 = Hd + G(-sx * 0.026, -0.03, -0.018)
    t1 = t0 + G(-sx * 0.012, -0.035, -0.022)
    t2 = t1 + G(-sx * 0.004, -0.03, -0.014)
    add(K.loft("Finger", [t0, t1, t2], [0.011 * heavy, 0.009 * heavy, 0.007 * heavy], pc, SKIN, 8))
    if P["claw"] > 0.0:
        add(GK.claw("Claw", t2, G(-sx * 0.2, -0.6, -1.0), P["claw"] * 0.6, 0.005 * heavy, pc, CLAW, 0.5))

# --- legs: hip to toes ----------------------------------------------------------------------------------
haunch = 1.3 if KIND == "spitter" else 1.0          # frog-thighs: it squats and strafes
fw = 1.25 if heavy > 1.0 else 1.0
for tag, sx in (("l", -1), ("r", 1)):
    Hp, Kn, Ft = S["hip_" + tag], S["knee_" + tag], S["foot_" + tag]
    pc = "leg_" + tag
    lg = Flesh(pc)
    lg.ball(Hp + G(sx * 0.008, 0.01, 0.0), (0.072 * LR, 0.08, 0.07 * LR))                    # hip
    lg.along(Hp + G(0, -0.03, -0.012), Kn + G(0, 0.09, -0.016), (0.066 * LR * haunch, 0.06 * LR * haunch), None)   # quadriceps
    lg.along(Hp + G(sx * 0.01, -0.06, 0.028), Kn + G(0, 0.1, 0.018), (0.054 * LR * haunch, 0.05 * LR * haunch), None)   # hamstrings
    lg.along(Hp + G(-sx * 0.02, -0.05, 0.0), Kn + G(-sx * 0.01, 0.14, 0.0), (0.04 * LR, 0.045 * LR), None)       # adductors
    lg.chain([Hp + G(0, -0.05, 0), Kn], [0.058 * LR, 0.04 * LR])
    lg.ball(Kn + G(0, 0.005, 0.0), (0.042 * LR, 0.045, 0.04 * LR))                             # knee
    lg.ball(Kn + G(0, 0.005, -0.036 * LR), (0.024, 0.027, 0.014), 4.0)                         # kneecap
    lg.along(Kn + G(0, -0.035, 0.024 * LR), Kn + G(0, -0.24, 0.016 * LR), (0.044 * LR, 0.04 * LR), None)       # calf
    lg.chain([Kn + G(0, -0.03, -0.006), Ft + G(0, 0.03, 0)], [0.033 * LR, 0.022 * LR])
    lg.along(Kn + G(0, -0.06, -0.026 * LR), Ft + G(0, 0.07, -0.016), 0.012, None, 3.0)        # shin ridge
    lg.ball(Ft, (0.025 * LR, 0.028, 0.026 * LR))                                               # ankle
    # models pass: the Achilles from the calf to the heel, and the hamstring tendons behind the knee
    lg.along(Kn + G(0, -0.2, 0.03 * LR), Ft + G(0, 0.012, 0.03), 0.009, None, 4.0)
    for k in (-1, 1):
        lg.along(Kn + G(k * 0.022, 0.08, 0.03 * LR), Kn + G(k * 0.026, -0.03, 0.022 * LR), 0.007, None, 4.0)
    lg.ball(Ft + G(0, -0.012, 0.035), (0.028 * fw, 0.024, 0.03), 2.0)                          # heel
    lg.along(Ft + G(0, -0.008, 0.0), Ft + G(0, -0.022, -0.1), (0.031 * fw, 0.017), None)      # instep
    build(lg, "Leg_" + tag, SKIN, 0.0055, 0.0015, 4)
    for t in range(4):
        tx = (t - 1.5) * 0.018 * fw
        a0 = Ft + G(tx * 0.8, -0.022, -0.085)
        a1 = Ft + G(tx * 1.6, -0.03, -0.135)
        add(K.loft("Toe", [a0, a1], [0.009 * fw, 0.007 * fw], pc, SKIN, 8))
        if KIND in ("wretch", "chanter", "spitter", "ossuant"):
            add(GK.claw("Claw", a1, G(tx * 3.0, -0.3, -1.0), 0.032, 0.005, pc, CLAW, 0.8))


# --- per-kind dress ---------------------------------------------------------------------------------
def collide_body():
    """Collider stand-ins for the cloth sim (removed after)."""
    c = []
    c.append(K.blob("ColHips", S["pelvis"] + G(0, -0.04, -0.03 * BELLY), (0.16 * W + 0.08 * BELLY, 0.16, 0.13 * W + 0.1 * BELLY), "r:pelvis", None, 24, 12))
    c.append(K.blob("ColTorso", S["chest"] + G(0, 0.02, -0.04 * BELLY), (0.17 * W + 0.06 * BELLY, 0.15 + 0.07 * BELLY, 0.24), "r:chest", None, 24, 12))
    for tag in ("l", "r"):
        c.append(K.loft("ColLeg", [S["hip_" + tag], S["foot_" + tag]], [0.075 * LR, 0.045 * LR], "r:pelvis", None, 12))
        c.append(K.blob("ColSh", S["shoulder_" + tag], (0.07, 0.07, 0.07), "r:chest", None, 16, 8))
    for o in c:
        K.collider(o)
    return c


def torn(ob, base_len, depth, seed, zoff=None):
    """Tear the hem: delete faces below a noisy line near the bottom."""
    me = ob.data
    bm = bmesh.new()
    bm.from_mesh(me)
    zs = [v.co.z for v in bm.verts]
    top, bot = max(zs), min(zs)
    kill = []
    for f in bm.faces:
        c = f.calc_center_median()
        ang = math.atan2(c.y, c.x)
        cut = bot + depth * (0.45 + 0.4 * noise.noise(Vector((math.cos(ang) * 2.5, math.sin(ang) * 2.5, seed)))
                             + 0.35 * noise.noise(Vector((ang * 17.0, seed, 0.0))) + 0.2 * noise.noise(Vector((ang * 41.0, seed * 2.0, 1.0))))
        if c.z < cut:
            kill.append(f)
    bmesh.ops.delete(bm, geom=kill, context='FACES')
    bm.to_mesh(me)
    bm.free()


if KIND == "wretch":
    HAIR = mat(GK.cloth("Hair", (0.035, 0.03, 0.03), "rough_linen", 30.0, (0.01, 0.01, 0.01), 0.8))
    RAG = mat(GK.cloth("Cloth", (0.09, 0.075, 0.065), "rough_linen", 7.0))
    # lank hair: flat locks from the crown, falling past the shoulders (it was a fan of cones)
    for k in range(22):
        ang = -2.5 + 5.0 * k / 21.0 + 0.06 * noise.noise(Vector((k, 0, 0)))
        root = HC + Vector((math.sin(ang) * 0.075, -math.cos(ang) * 0.055 - 0.01, 0.075 - 0.03 * abs(math.sin(ang))))
        out = Vector((math.sin(ang) * 0.5, -abs(math.cos(ang)) * 0.4 - 0.15, -1.0)).normalized()
        L = 0.3 + 0.16 * (0.5 + 0.5 * noise.noise(Vector((k * 0.7, 3.0, 0))))
        pts = []
        for j in range(8):
            t = j / 7.0
            wob = Vector((noise.noise(Vector((k, t * 3, 1))), noise.noise(Vector((k, t * 3, 2))), 0)) * 0.03 * t
            pts.append(root + out * L * t + Vector((0, -0.04 * t * t, 0)) + wob)
        add(GK.strip("Hair", pts, 0.022, 0.006, "r:head", HAIR, taper=0.75))
    # rags: broad torn strips layered round the waist and over the shoulders (a skirt read as a box)
    for k in range(17):
        ang = math.tau * k / 17.0 + 0.25 * noise.noise(Vector((k, 5.0, 0)))
        root = S["pelvis"] + G(math.cos(ang) * 0.138 * W, 0.03 - 0.015 * (k % 2), math.sin(ang) * 0.112 * W)
        out = Vector((math.cos(ang), -math.sin(ang), 0.0))          # Blender: Godot -z is +y
        front = max(0.0, math.sin(ang))
        L = 0.22 + 0.16 * (0.5 + 0.5 * noise.noise(Vector((k * 1.3, 2.0, 0)))) + 0.08 * front
        pts = [root + out * (0.005 + 0.035 * t * t) + Vector((0, 0, -L * t)) + out * 0.01 * math.sin(t * 5.0 + k) for t in [i / 7.0 for i in range(8)]]
        add(GK.strip("Rag", pts, 0.06 + 0.015 * (k % 3), 0.006, "pelcloth", RAG, taper=0.6))
    for sx in (-1, 1):
        for j in range(4):
            fr = j < 2
            root = S["chest"] + G(sx * (0.06 + 0.04 * j), 0.19 - 0.012 * j, -0.06 if fr else 0.09)
            d = G(sx * 0.2, -1.0, -0.12 if fr else 0.2).normalized()
            L = 0.16 + 0.06 * j
            pts = [root + d * L * t + G(0, 0, (-0.03 if fr else 0.03) * math.sin(t * math.pi)) for t in [i / 6.0 for i in range(7)]]
            add(GK.strip("Rag", pts, 0.05, 0.006, "chcloth", RAG, taper=0.6))
    # leather cord at the waist and a few wraps on the forearms
    LEATHER = mat(GK.leather("Leather", (0.14, 0.09, 0.06)))
    add(K.loft("Cord", [S["pelvis"] + G(math.cos(a) * 0.15 * W, 0.03, math.sin(a) * 0.125 * W) for a in [math.tau * i / 24 for i in range(25)]], [0.008] * 25, "r:pelvis", LEATHER, 6))
    for tag, sx in (("l", -1), ("r", 1)):
        add(GK.bandage("Linen", S["elbow_" + tag] + G(0, -0.12, 0), S["hand_" + tag] + G(0, 0.03, 0), 0.03, 2.2, 0.012, "arm_" + tag, RAG, sx))

elif KIND == "husk":
    LINEN = mat(GK.cloth("Linen", (0.36, 0.32, 0.25), "rough_linen", 14.0, (0.12, 0.09, 0.05), 0.9))
    LEATHER = mat(GK.leather("Leather", (0.17, 0.11, 0.07)))
    SEAM = mat(GK.glow("Seam", (1.0, 0.55, 0.15), 3.5, (0.15, 0.04, 0.03)))
    STITCH = mat(GK.leather("Stitch", (0.08, 0.05, 0.04), 30.0))
    # the stitched cut down the gut: a dim light leaks from it (it was a bulb in the belly)
    bb = BELLY * 0.62
    seam = [g(0.004 * math.sin(t * 9), 1.22 - 0.33 * t, -0.13 - 0.06 * bb - (0.15 * bb + 0.05) - 0.035 * math.sin(t * math.pi)) for t in [i / 14.0 for i in range(15)]]
    add(K.loft("Seam", seam, [(0.009, 0.004)] * 15, "torso", SEAM, 8))
    for k in range(9):
        t = 0.06 + 0.88 * k / 8.0
        i = int(t * 14)
        p = seam[i]
        add(K.loft("Stitch", [p + G(-0.03, 0.006, 0.012), p + G(0, 0, -0.006), p + G(0.03, -0.006, 0.012)], [0.0035, 0.004, 0.0035], "torso", STITCH, 5))
    # a belt sunk under the overhang of the gut
    add(K.loft("Belt", [S["pelvis"] + G(math.cos(a) * 0.17 * W, 0.0 - 0.02 * max(0.0, -math.sin(a)), math.sin(a) * 0.15 * W - 0.05 * max(0.0, -math.sin(a)))
                        for a in [math.tau * i / 32 for i in range(33)]], [(0.022, 0.008)] * 33, "r:pelvis", LEATHER, 6))
    # bandages: forearms, shins, one across the chest
    for tag, sx in (("l", -1), ("r", 1)):
        add(GK.bandage("Linen", S["elbow_" + tag] + G(0, -0.05, 0), S["hand_" + tag] + G(0, 0.03, 0), 0.032 * LR, 3.0, 0.014, "arm_" + tag, LINEN, sx))
        add(GK.bandage("Linen", S["knee_" + tag] + G(0, -0.08, 0), S["foot_" + tag] + G(0, 0.06, 0), 0.031 * LR, 3.5, 0.014, "leg_" + tag, LINEN, sx))
        add(GK.bandage("Linen", S["shoulder_" + tag] + G(0, -0.1, 0), S["elbow_" + tag] + G(0, 0.05, 0), 0.043 * LR, 1.5, 0.016, "arm_" + tag, LINEN, sx))
    add(GK.bandage("Linen", S["chest"] + G(-0.2, 0.17, 0), S["chest"] + G(0.2, -0.18, 0), 0.17, 0.5, 0.024, "torso", LINEN, 0.3))
    # stitches across the scalp
    sp = [HC + Vector((0.0, 0.07 - 0.14 * t, 0.095 * HS + 0.004 * math.sin(t * math.pi))) for t in [i / 8.0 for i in range(9)]]
    add(K.loft("Stitch", sp, [0.004] * 9, "r:head", STITCH, 5))
    for k in range(5):
        p = sp[1 + k * 1 + k // 2]
        add(K.loft("Stitch", [p + Vector((-0.016, 0, -0.006)), p + Vector((0, 0, 0.003)), p + Vector((0.016, 0, -0.006))], [0.003] * 3, "r:head", STITCH, 5))
    # a rag apron below the gut
    coll = collide_body()
    apron = add(K.hanging_cone("Apron", S["pelvis"] + G(0, -0.04, -0.05), 0.2 * W, 0.17 * W, 0.3, 0.3, "pelcloth", LINEN, 40, 12, open_front=0.0))
    torn(apron, 0.3, 0.16, 4.0)
    K.simulate([apron], 50, 10.0, 0.3)
    K.solidify(apron, 0.006)
    for o in coll:
        bpy.data.objects.remove(o)

elif KIND == "spitter":
    GLAND = mat(GK.membrane("Gland", (0.2, 1.0, 0.75), 2.4, (0.5, 0.62, 0.52)))
    RAG = mat(GK.cloth("Cloth", (0.2, 0.2, 0.17), "rough_linen", 8.0))
    # glands down the spine, swelling toward the neck: they pulse toward the throat
    for k in range(7):
        t = k / 6.0
        y = 1.12 + 0.44 * t
        z = 0.11 + 0.02 * math.sin(t * math.pi)
        s = 0.7 + 0.5 * t
        for sx in (-1, 1):
            add(K.blob("Gland", g(sx * (0.04 + 0.01 * (k % 2)), y, z), (0.022 * s, 0.022 * s, 0.026 * s), "torso", GLAND, 16, 10))
    # the throat pouch's loose skin under the jaw (spitter.gd hangs the swelling sac in it)
    thr = Flesh("torso")
    thr.ball(g(0, 1.52, -0.12), (0.075, 0.07, 0.065))
    thr.ball(g(0, 1.47, -0.08), (0.06, 0.06, 0.05))
    add(thr.build("Throat", SKIN, 0.006, 0.002, SEED + 9))
    coll = collide_body()
    loin = add(K.hanging_cone("Loin", S["pelvis"] + G(0, 0.0, 0), 0.13, 0.11, 0.24, 0.5, "pelcloth", RAG, 36, 10))
    torn(loin, 0.24, 0.14, 5.0)
    K.simulate([loin], 50, 8.0, 0.2)
    K.solidify(loin, 0.005)
    for o in coll:
        bpy.data.objects.remove(o)

elif KIND == "ossuant":
    BONE = mat(GK.bone("Bone", (0.86, 0.8, 0.66), (0.3, 0.24, 0.16)))
    LEATHER = mat(GK.leather("Leather", (0.12, 0.08, 0.06)))
    KEEP.add("Bone")
    # skull mask over the face, a crest of spikes swept back like a helm's (it read as a punk crown)
    def skull_shape(c):
        p = Vector(c)
        n = p.normalized()
        push = 0.0
        for sx in (-1, 1):
            d = (p - Vector((sx * 0.4, 0.9, 0.08))).length
            push -= 0.26 * math.exp(-(d / 0.27) ** 2)
        d = (p - Vector((0, 0.97, -0.3))).length
        push -= 0.2 * math.exp(-(d / 0.14) ** 2)
        if p.z < -0.2 and p.y > 0.0:
            p.x *= 0.82
        return p + n * push
    add(K.blob("Mask", HC + Vector((0, 0.022, 0.012)), (0.094, 0.112, 0.112), "r:head", BONE, 40, 20, skull_shape))
    for k in range(5):
        t = k / 4.0
        base = HC + Vector((0, 0.06 - 0.12 * t, 0.1 - 0.02 * t))
        L = 0.16 + 0.08 * math.sin(t * math.pi)
        add(GK.claw("Bone", base, Vector((0, -1.0, 0.3 - 0.25 * t)), L, 0.02, "r:head", BONE, -0.15))
    for sx in (-1, 1):
        add(GK.claw("Bone", HC + Vector((sx * 0.07, 0.0, 0.06)), Vector((sx * 0.5, -1.0, 0.3)), 0.14, 0.016, "r:head", BONE, -0.2))
    # outer ribcage (bone over the dark chest), sternum plate
    C = S["chest"]
    for i in range(5):
        y = 0.1 - 0.055 * i
        k = math.sqrt(max(0.2, 1.0 - ((y + 0.03) / 0.19) ** 2))
        w = (0.145 * W + 0.05) * k
        d = (0.11 * W + 0.065) * k
        for sx in (-1, 1):
            # an outer rib hugging the chest, flank round to the breastbone, sloping down to the front
            pts = [C + G(sx * math.sin(a) * w, y - 0.06 * (a - 0.9) / 2.0, math.cos(a) * d) for a in [0.9 + 2.0 * q / 10.0 for q in range(11)]]
            add(K.loft("Bone", pts, [(0.016, 0.01)] * 11, "torso", BONE, 8))
    add(K.loft("Bone", [C + G(0, 0.16, -0.135), C + G(0, -0.04, -0.15), C + G(0, -0.17, -0.13)], [(0.03, 0.01), (0.028, 0.01), (0.016, 0.008)], "torso", BONE, 10))
    # pauldrons: bone plates with spurs
    for tag, sx in (("l", -1), ("r", 1)):
        Sh = S["shoulder_" + tag]
        add(GK.plate("Bone", Sh + G(sx * 0.02, 0.05, 0), (0.1, 0.11, 0.05), G(sx * 0.6, 1.0, 0), "r:shoulder_" + tag, BONE, 28, 1.2))
        add(GK.plate("Bone", Sh + G(sx * 0.05, -0.02, 0), (0.085, 0.09, 0.04), G(sx * 1.0, 0.5, 0), "r:shoulder_" + tag, BONE, 24, 1.2))
        for j in range(2):
            add(GK.claw("Bone", Sh + G(sx * (0.04 + 0.03 * j), 0.08, 0.03 - 0.06 * j), G(sx * 0.7, 0.8, 0.3), 0.12 - 0.03 * j, 0.016, "r:shoulder_" + tag, BONE, -0.2))
        add(GK.bandage("Leather", S["elbow_" + tag] + G(0, -0.04, 0), S["hand_" + tag] + G(0, 0.05, 0), 0.031 * LR, 2.5, 0.014, "arm_" + tag, LEATHER, sx))
        # bone greaves on the shins
        Kn = S["knee_" + tag]
        add(GK.plate("Bone", Kn + G(0, -0.17, -0.04), (0.04, 0.16, 0.025), G(0, 0, -1), "r:knee_" + tag, BONE, 20, 2.0))
    # the spine ridge down the back
    for k in range(7):
        y = 1.48 - 0.07 * k
        add(GK.claw("Bone", g(0, y, 0.12), G(0, 0.4, 1.0), 0.08 + 0.02 * (k % 2), 0.014, "r:chest", BONE, -0.3))
    # the fauld: long bones hanging from the belt
    add(K.loft("Leather", [S["pelvis"] + G(math.cos(a) * 0.165 * W, 0.04, math.sin(a) * 0.13 * W) for a in [math.tau * i / 24 for i in range(25)]], [(0.022, 0.008)] * 25, "r:pelvis", LEATHER, 6))
    for k in range(9):
        a = -1.4 + 2.8 * k / 8.0
        o = S["pelvis"] + G(math.sin(a) * 0.17 * W, 0.03, -math.cos(a) * 0.14 * W)
        out = G(math.sin(a) * 0.12, -1.0, -math.cos(a) * 0.12).normalized()
        L = 0.26 + 0.05 * (k % 3)
        add(K.bone("Bone", o, o + out * L, 0.012, "r:pelvis", BONE, 1.7, 10, 10, k))

elif KIND == "bulwark":
    IRON = mat(GK.iron("Iron"))
    WOOD = mat(GK.wood("Wood", (0.2, 0.13, 0.08), 0.6))
    LEATHER = mat(GK.leather("Leather", (0.14, 0.09, 0.06)))
    BONE = mat(GK.bone("Bone", (0.82, 0.76, 0.62)))
    KEEP.add("Bone")
    # the slit helm, a crest of iron spikes, the eyes burning in the slit
    hc = HC + Vector((0, 0.005, 0.015))
    def helm_shape(c):
        p = Vector(c)
        if p.z < -0.35:
            p.z = -0.35 - (p.z + 0.35) * 0.2           # flat bottom rim
        return p
    add(K.blob("Iron", hc, (0.108, 0.12, 0.112), "r:head", IRON, 40, 20, helm_shape))
    add(K.loft("Iron", [hc + Vector((math.cos(a) * 0.112, math.sin(a) * 0.125, -0.04)) for a in [math.tau * i / 32 for i in range(33)]], [(0.008, 0.012)] * 33, "r:head", IRON, 6))
    add(K.blob("Slit", hc + Vector((0, 0.117, 0.012)), (0.07, 0.012, 0.009), "r:head", EYE, 16, 8))
    add(K.loft("Iron", [hc + Vector((0, 0.124, 0.07)), hc + Vector((0, 0.13, -0.05))], [(0.008, 0.006), (0.008, 0.006)], "r:head", IRON, 6))
    for k in range(5):
        t = k / 4.0
        add(GK.claw("Iron", hc + Vector((0, 0.07 - 0.14 * t, 0.1 - 0.015 * abs(t - 0.5))), Vector((0, -0.6, 1.0)), 0.12 - 0.03 * abs(k - 2), 0.016, "r:head", IRON, -0.2))
    # pauldrons and a gorget
    for tag, sx in (("l", -1), ("r", 1)):
        Sh = S["shoulder_" + tag]
        add(GK.plate("Iron", Sh + G(sx * 0.02, 0.06, 0), (0.12, 0.13, 0.05), G(sx * 0.5, 1.0, 0), "r:shoulder_" + tag, IRON, 28, 1.0))
        add(GK.plate("Iron", Sh + G(sx * 0.06, -0.03, 0), (0.1, 0.11, 0.04), G(sx * 1.0, 0.45, 0), "r:shoulder_" + tag, IRON, 24, 1.0))
        for k in range(4):
            a = math.tau * k / 4
            add(K.blob("Iron", Sh + G(sx * 0.02, 0.06, 0) + G(math.cos(a) * 0.08, 0.06, math.sin(a) * 0.08), (0.008, 0.008, 0.008), "r:shoulder_" + tag, IRON, 8, 6))
        add(GK.bandage("Leather", S["elbow_" + tag] + G(0, -0.05, 0), S["hand_" + tag] + G(0, 0.04, 0), 0.032 * LR, 2.0, 0.02, "arm_" + tag, LEATHER, sx))
    add(K.loft("Iron", [S["chest"] + G(math.cos(a) * 0.13, 0.2, math.sin(a) * 0.11) for a in [math.tau * i / 24 for i in range(25)]], [(0.03, 0.01)] * 25, "r:chest", IRON, 6))
    # straps across the chest, a belt
    add(K.loft("Leather", [S["chest"] + G(-0.2, 0.16, -0.08), S["chest"] + G(0, 0.0, -0.21), S["chest"] + G(0.2, -0.16, -0.14)], [(0.025, 0.006)] * 3, "r:chest", LEATHER, 6))
    add(K.loft("Leather", [S["pelvis"] + G(math.cos(a) * 0.19 * W, 0.04, math.sin(a) * 0.16 * W - 0.03) for a in [math.tau * i / 32 for i in range(33)]], [(0.028, 0.01)] * 33, "r:pelvis", LEATHER, 6))
    # THE DOOR-SHIELD (its own part, on the chest: bulwark.gd breaks it off): planks edge to edge,
    # one standing taller, three iron bands studded with rivets, a dented iron boss with a skull
    # nailed over it, scorched. 0.8 m wide: the shield IS the silhouette from the front.
    C = S["chest"]
    cz = -0.42
    planks = 6
    pw = 0.8 / planks
    for k in range(planks):
        x = -0.4 + pw * (k + 0.5)
        top = 0.3 + (0.12 if k == 3 else 0.03 * ((k * 5) % 3))
        bot = -0.86 + 0.02 * ((k * 3) % 2)
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        for v in bm.verts:
            v.co.x *= pw * 0.98
            v.co.y *= 0.045
            v.co.z *= (top - bot)
            v.co += Vector((0, 0, 0)) if True else v.co
        ob = K.mesh_from_bm("Wood", bm, "shield", WOOD, smooth=False)
        for v in ob.data.vertices:
            v.co += C + G(x, (top + bot) * 0.5, cz + 0.004 * math.sin(k * 2.3)) + Vector((0.004 * noise.noise(v.co * 40.0), 0.004 * noise.noise(v.co * 33.0), 0))
        bev = ob.modifiers.new("Bev", 'BEVEL')
        bev.width = 0.006
        bev.segments = 2
        K.apply_mods(ob)
        # a pointed top on the tall plank
        if k == 3:
            add(K.loft("Wood", [C + G(x, top, cz), C + G(x, top + 0.08, cz)], [(pw * 0.48, 0.022), (0.004, 0.01)], "shield", WOOD, 4))
        add(ob)
    for y in (0.14, -0.28, -0.7):
        pts = [C + G(-0.42 + 0.84 * t, y + 0.01 * math.sin(t * 7), cz - 0.03 - 0.008 * math.sin(t * math.pi)) for t in [i / 12.0 for i in range(13)]]
        add(K.loft("Iron", pts, [(0.012, 0.03)] * 13, "shield", IRON, 6))
        for k in range(7):
            add(K.blob("Iron", C + G(-0.36 + 0.12 * k, y, cz - 0.045), (0.011, 0.011, 0.007), "shield", IRON, 10, 6))
    def dent(c):
        p = Vector(c)
        p += p.normalized() * 0.08 * noise.noise(p * 3.0)
        return p
    add(K.blob("Iron", C + G(0, -0.1, cz - 0.04), (0.13, 0.13, 0.045), "shield", IRON, 40, 16, dent))
    add(K.blob("Bone", C + G(0, -0.08, cz - 0.095), (0.06, 0.04, 0.07), "shield", BONE, 24, 12))
    for sx in (-1, 1):
        add(K.blob("Eye", C + G(sx * 0.024, -0.07, cz - 0.135), (0.012, 0.008, 0.01), "shield", EYE, 10, 6))
    add(K.blob("Bone", C + G(0, -0.14, cz - 0.11), (0.035, 0.03, 0.018), "shield", BONE, 16, 8))
    for k in range(6):
        x = -0.33 + 0.132 * k
        add(GK.claw("Iron", C + G(x, 0.32 + (0.1 if k in (2, 3) else 0.0), cz), G(0, 1.0, -0.12), 0.1, 0.015, "shield", IRON, -0.1))
    add(K.loft("Leather", [C + G(-0.2, -0.2, cz + 0.03), C + G(-0.12, -0.14, -0.22), C + G(0.04, -0.1, -0.15)], [(0.02, 0.006)] * 3, "shield", LEATHER, 6))

elif KIND == "chanter":
    ROBE = mat(GK.cloth("Robe", (0.075, 0.08, 0.06), "caban", 8.0, (0.035, 0.03, 0.02), 0.9))
    BONE = mat(GK.bone("Bone", (0.8, 0.74, 0.6)))
    IRON = mat(GK.iron("Iron", (0.16, 0.15, 0.15)))
    GLOAM = mat(GK.glow("Glow", (0.45, 1.0, 0.3), 4.0))
    KEEP.add("Bone")
    # the cowl: a deep hood jutting forward past the face, its mouth dark (it was a tall dunce cone)
    rings, radii = [], []
    for k in range(11):
        t = k / 10.0
        z = 0.12 - 0.3 * t                                    # Godot z: behind the skull -> past the face
        # the crown rises to a soft peak at the back, the mouth droops forward and down over the face
        rings.append(HC + G(0, 0.0 + 0.035 * math.sin(t * math.pi) - 0.07 * t * t, z))
        rr = 0.1 + 0.028 * math.sin(t * math.pi * 0.85)
        radii.append((rr * 1.05, rr * (1.15 - 0.15 * t)))
    hood = K.loft("Robe", rings, radii, "r:head", ROBE, 28, cap0=True, cap1=False)
    K.solidify(hood, 0.012)
    K.subsurf(hood, 1)
    add(hood)
    # a mantle over the shoulders and the robe to the ground, both simulated, torn at the hem
    coll = collide_body()
    head_col = K.blob("ColHead", HC, (0.1, 0.11, 0.11), "r:head", None, 16, 8)
    K.collider(head_col)
    robe = add(K.hanging_cone("Robe", S["pelvis"] + G(0, 0.12, 0), 0.16, 0.13, 1.08, 0.75, "pelcloth", ROBE, 64, 40))
    # the mantle rises into a collar round the neck, so the cowl drapes down onto the shoulders
    mantle = add(K.hanging_cone("Robe", S["chest"] + G(0, 0.33, 0.03), 0.085, 0.08, 0.66, 2.2, "chcloth", ROBE, 64, 30))
    torn(robe, 1.0, 0.25, 7.0)
    torn(mantle, 0.4, 0.14, 8.0)
    K.simulate([robe, mantle], 70, 10.0, 0.25)
    for o in (robe, mantle):
        K.solidify(o, 0.007)
    for o in coll + [head_col]:
        bpy.data.objects.remove(o)
    # the staff: a bone shaft through the right hand, a caged corpse-light at its tip
    # (chanter.gd reads the tip 0.85 above the hand from node Kin_glow_hand_r)
    HR = S["hand_r"]
    shaft = [HR + G(0.005 * math.sin(t * 7), -0.85 + 1.72 * t, -0.03) for t in [i / 16.0 for i in range(17)]]
    add(K.loft("Bone", shaft, [0.016 + 0.004 * math.sin(i * 1.7) for i in range(17)], "staff", BONE, 8, wobble=0.1))
    tip = HR + G(0, 0.85, -0.03)
    for k in range(6):
        a = math.tau * k / 6.0
        pts = [tip + G(math.cos(a) * r, y, math.sin(a) * r) for y, r in ((-0.1, 0.02), (-0.06, 0.06), (0.0, 0.075), (0.07, 0.055), (0.12, 0.012))]
        add(K.curve_tube("Iron", pts, 0.005, "staff", IRON))
    add(K.blob("Glow", tip, (0.045, 0.055, 0.045), "staff", GLOAM, 16, 10))
    for k in range(3):
        add(K.loft("Bone", [tip + G(0.06 * math.cos(k * 2.1), -0.12, 0.06 * math.sin(k * 2.1)), tip + G(0.08 * math.cos(k * 2.1), -0.3, 0.08 * math.sin(k * 2.1))], [0.004, 0.002], "staff", BONE, 4))
        add(K.blob("Bone", tip + G(0.08 * math.cos(k * 2.1), -0.32, 0.08 * math.sin(k * 2.1)), (0.012, 0.02, 0.012), "staff", BONE, 10, 6))

# fuse each piece's flesh into one continuous sculpted surface (no primitives meeting), decimate
objs[:] = K.fuse(objs, 0.0034, keep=KEEP | {"Claw", "Hair", "Stitch", "Seam", "Slit"}, sculpt=0.0011, sculpt_scale=0.018, decimate=0.07)
print("GRUNT", KIND, "parts", len(objs), "tris", sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objs))
if PREVIEW:
    K.preview(PREVIEW, 0.95, 3.0)
if EXPORT:
    WEIGHTS["staff"] = _rigid("hand_r")
    GK.export_skinned(objs, MATS, "grunt_" + KIND, S, WEIGHTS, {"shield": ("shield_chest", S["chest"])}, 2048, 26000)
