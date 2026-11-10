"""Quadruped grunts (r30): crawler, leaper, burrower, mite. Modelled in their QuadRig's rest pose
(core/enemy/quad_rig.gd; the leaper on its opt-in `upright` hound legs), flesh as fused metaball
muscle, chitin / bone / earth as their own materials, one baked atlas per kind, ONE skinned mesh on a
flat skeleton (a bone per rig socket) weighted across every joint.

  tools/blender/run.sh grunt_quad.py -- --kind leaper [--preview /tmp/l.png] [--no-export]
Writes art/models/grunt_<kind>.glb and art/textures/grunt_<kind>_{albedo,normal,orm,emit}.png
"""
import bpy
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
KIND = args[args.index("--kind") + 1] if "--kind" in args else "crawler"
PREVIEW = args[args.index("--preview") + 1] if "--preview" in args else ""
EXPORT = "--no-export" not in args

K.reset()

# the rig each kind builds (crawler.gd, leaper.gd, burrower.gd, mite.gd)
RIG = {
    "crawler": (0.34, 0.72, 0.14, 0.24, False),
    "burrower": (0.34, 0.72, 0.14, 0.24, False),
    "mite": (0.34, 0.72, 0.14, 0.24, False),
    "leaper": (0.56, 1.15, 0.2, 0.32, True),
}[KIND]
BH, BL, HSP, UL, UPRIGHT = RIG
SEED = float(sum(ord(c) for c in KIND))


def sockets():
    s = {"body": G(0, BH, 0)}
    s["front"] = s["body"] + G(0, 0.04, -BL * 0.45)
    s["head"] = s["front"] + G(0, 0.03, -0.16)
    s["tail"] = s["body"] + G(0, 0.02, BL * 0.45)
    for tag, sx, front in (("fl", -1, True), ("fr", 1, True), ("bl", -1, False), ("br", 1, False)):
        z = -BL * 0.36 if front else BL * 0.34
        hip = s["body"] + G(sx * HSP, -0.02, z)
        if UPRIGHT:
            seg = (BH - 0.05) * 0.5
            knee = hip + G(0, -seg, 0.06 if front else -0.08)
            foot = knee + G(0, -seg, -0.04 if front else 0.1)
        else:
            knee = hip + G(sx * UL, 0.1, 0.0)
            foot = knee + G(sx * 0.07, -(BH + 0.08), 0.0)
        s["leg_%s_hip" % tag], s["leg_%s_knee" % tag], s["leg_%s_foot" % tag] = hip, knee, foot
    return s


S = sockets()
B, F, H, T = S["body"], S["front"], S["head"], S["tail"]
objs = []


def add(o):
    objs.append(o)
    return o


def g(x, y, z):
    return G(x, y, z)


# --- weights ------------------------------------------------------------------------------------------
def _spine(p):
    if (p - B).y > 0.0:            # Blender +y = Godot -z = toward the head
        return GK.chain_w(p, [("body", B), ("front", F + G(0, 0, 0.04)), ("head", H + G(0, 0, 0.02))], [0.07, 0.035])
    return GK.chain_w(p, [("body", B), ("tail", T + G(0, 0, -0.03))], 0.06)


WEIGHTS = {"spine": _spine,
           "head": lambda p: GK.chain_w(p, [("front", F), ("head", H + G(0, 0, 0.02))], 0.03)}
for tag in ("fl", "fr", "bl", "br"):
    WEIGHTS["leg_" + tag] = (lambda t: lambda p: GK.chain_w(p, [("body", B), ("leg_%s_hip" % t, S["leg_%s_hip" % t]),
                                                                ("leg_%s_knee" % t, S["leg_%s_knee" % t]), ("leg_%s_foot" % t, S["leg_%s_foot" % t])],
                                                            [0.035, 0.03, 0.025]))(tag)
for bn in S:
    WEIGHTS["r:" + bn] = (lambda b: lambda p: {b: 1.0})(bn)


def build(fl, name, m, res=0.006, rough=0.0015, seed=0.0):
    ob = fl.build(name, m, res, rough, SEED + seed)
    print("FLESH", name, len(ob.data.vertices))
    return add(ob)


EYE_COL = {"crawler": (1.0, 0.16, 0.08), "leaper": (1.0, 0.45, 0.08), "burrower": (1.0, 0.5, 0.1), "mite": (0.25, 1.0, 0.8)}[KIND]
EYE = GK.glow("Eye", EYE_COL, 8.0)
CLAW = GK.chitin("Claw", (0.045, 0.036, 0.032), (0.32, 0.25, 0.18), 14.0, 0.42)
MATS = [EYE, CLAW]
KEEP = {"Eye", "Claw", "Glow", "Sac"}


def mat(m):
    if m not in MATS:
        MATS.append(m)
    return m


# =====================================================================================================
if KIND == "leaper":
    SKIN = mat(GK.ember_chitin("Skin", (0.055, 0.045, 0.045), (0.22, 0.16, 0.13), plates=13.0, rough=0.52, strength=2.0))
    BONE = mat(GK.chitin("Bone", (0.09, 0.075, 0.065), (0.38, 0.3, 0.22), 9.0, 0.46))
    EMBER = mat(GK.glow("Glow", (1.0, 0.42, 0.08), 4.0, (0.05, 0.015, 0.01)))
    # body: a deep chest, a tucked waist, heavy haunches; the shoulder hump at the withers
    bd = Flesh("spine")
    bd.ball(B + G(0, 0.0, -0.3), (0.13, 0.22, 0.19))                       # deep, narrow chest
    bd.ball(B + G(0, -0.08, -0.28), (0.11, 0.12, 0.15))                    # brisket, keel low
    bd.ball(B + G(0, 0.2, -0.26), (0.11, 0.1, 0.15))                     # withers: a hump
    bd.ball(B + G(0, 0.16, -0.1), (0.1, 0.08, 0.14))
    bd.chain([B + G(0, 0.02, -0.15), B + G(0, 0.04, 0.05), B + G(0, 0.03, 0.22)], [0.115, 0.08, 0.11])   # waist, tucked
    bd.ball(B + G(0, -0.03, 0.04), (0.08, 0.06, 0.12))                     # the tuck under the loin
    for sx in (-1, 1):
        bd.ball(B + G(sx * 0.1, 0.03, 0.3), (0.1, 0.17, 0.16), 1.5)    # haunches
        bd.ball(B + G(sx * 0.1, 0.03, -0.35), (0.06, 0.12, 0.09), 1.5)     # shoulders
    bd.ball(B + G(0, 0.07, 0.36), (0.12, 0.09, 0.14))                      # croup
    bd.chain([B + G(0, 0.09, -0.4), F + G(0, 0.05, 0.02), H + G(0, 0.0, 0.07)], [0.11, 0.085, 0.065])   # neck, rising
    bd.chain([B + G(0, 0.06, 0.44), T + G(0, 0.0, 0.08)], [0.075, 0.05])   # tail root
    build(bd, "Body", SKIN, 0.0075, 0.002, 1)
    # ribs showing through the flanks
    for sx in (-1, 1):
        for k in range(6):
            z = -0.36 + 0.07 * k
            r = 0.15 - 0.012 * k
            pts = [B + G(sx * math.sin(a) * r * 1.07, 0.1 * math.cos(a) * 1.3 + 0.02, z + 0.02 * a) for a in [0.3 + 1.9 * j / 8.0 for j in range(9)]]
            add(K.loft("Rib", pts, [0.0125] * 9, "spine", SKIN, 6))
    # dorsal spines graded big at the shoulders to small at the tail (it was an even comb)
    for k in range(13):
        t = k / 12.0
        z = lerp = -0.42 + 0.84 * t
        y = 0.2 - 0.07 * t + 0.03 * math.sin(t * math.pi)
        L = 0.3 * (1.0 - t) ** 1.2 + 0.04
        add(GK.claw("Bone", B + G(0, y, z), G(0, 1.0, 0.75), L, 0.024 * (1.0 - 0.6 * t) + 0.007, "spine", BONE, -0.35))
    # the ember line along the belly
    belly = [B + G(0, -0.185 + 0.13 * t ** 0.55, -0.33 + 0.5 * t) for t in [i / 14.0 for i in range(15)]]
    add(K.loft("Glow", belly, [(0.008, 0.006)] * 15, "spine", EMBER, 6))
    # head: a long lean sight-hound skull, the jaw open, ember eyes deep in the sockets
    hd = Flesh("head")
    hd.ball(H + G(0, 0.03, 0.0), (0.06, 0.06, 0.08))                       # cranium
    hd.chain([H + G(0, 0.02, -0.05), H + G(0, 0.0, -0.17), H + G(0, -0.02, -0.25)], [0.05, 0.035, 0.025], 3.0)   # muzzle
    hd.chain([H + G(-0.04, -0.03, 0.0), H + G(0, -0.06, -0.2), H + G(0.04, -0.03, 0.0)], [0.022, 0.018, 0.022])   # lower jaw, slung open
    for sx in (-1, 1):
        hd.ball(H + G(sx * 0.045, 0.04, -0.06), (0.02, 0.016, 0.02), 2.0, None, True)          # sockets
        hd.ball(H + G(sx * 0.055, 0.0, -0.01), (0.025, 0.03, 0.035), 3.0)                      # masseter
        hd.ball(H + G(sx * 0.035, 0.07, 0.04), (0.018, 0.045, 0.03), 4.0)                      # ears laid back
    hd.ball(H + G(0, 0.03, 0.1), (0.04, 0.04, 0.04))                       # into the neck
    build(hd, "Head", SKIN, 0.004, 0.001, 2)
    # r38: swept horns, and plates of bone armour over the shoulder blades, a hide flap hanging off the belly
    for sx in (-1, 1):
        add(GK.claw("Bone", H + G(sx * 0.04, 0.07, 0.04), G(sx * 0.45, 0.45, 1.0), 0.26, 0.02, "head", BONE, -0.6))
        for j in range(4):
            add(GK.claw("Bone", B + G(sx * (0.1 + 0.01 * j), 0.16 - 0.03 * j, -0.38 + 0.07 * j), G(sx * (0.8 - 0.1 * j), 0.7, 0.1 + 0.25 * j), 0.17 - 0.015 * j, 0.022, "spine", BONE, -0.4))   # swept pauldron spikes
    for k in range(5):
        t = k / 4.0
        add(GK.strip("Hide", [B + G((t - 0.5) * 0.14, -0.15, -0.3 + 0.55 * t), B + G((t - 0.5) * 0.17, -0.25 - 0.05 * (k % 2), -0.3 + 0.55 * t + 0.03), B + G((t - 0.5) * 0.19, -0.32 - 0.05 * (k % 2), -0.3 + 0.55 * t + 0.06)], 0.05, 0.006, "spine", SKIN, taper=0.7))
    for sx in (-1, 1):
        add(K.blob("Eye", H + G(sx * 0.042, 0.04, -0.07), (0.012, 0.011, 0.008), "head", EYE, 12, 8))
        for k in range(7):
            z = -0.05 - 0.028 * k
            add(K.loft("Tooth", [H + G(sx * (0.028 - 0.002 * k), -0.015, z), H + G(sx * (0.028 - 0.002 * k), -0.07 - 0.02 * (k % 2), z)], [0.007, 0.0], "head", CLAW, 6))
            add(K.loft("Tooth", [H + G(sx * (0.024 - 0.002 * k), -0.05, z + 0.01), H + G(sx * (0.024 - 0.002 * k), -0.03, z + 0.01)], [0.004, 0.0], "head", CLAW, 6))
    # tail: long, tapering, a double row of spikes
    tl = Flesh("r:tail")
    tp = [T + G(0, -0.08 * t * t + 0.02 * math.sin(t * 3), 0.9 * t) for t in [i / 8.0 for i in range(9)]]
    tl.chain(tp, [0.06 * (1.0 - t * 0.85) for t in [i / 8.0 for i in range(9)]])
    build(tl, "Tail", SKIN, 0.005, 0.0015, 3)
    # r38: a bone scythe at the end of the tail, the rig's whip lash made a blade
    add(GK.claw("Bone", T + G(0, -0.075, 0.88), G(0, 0.25, 1.0), 0.3, 0.034, "r:tail", BONE, -0.9))
    add(GK.claw("Bone", T + G(0, -0.07, 0.82), G(0, -0.2, 1.0), 0.16, 0.02, "r:tail", BONE, 0.7))
    for k in range(9):
        t = 0.12 + 0.1 * k
        p = T + G(0, -0.08 * t * t + 0.02 * math.sin(t * 3), 0.9 * t)
        add(GK.claw("Bone", p + G(0, 0.04 * (1 - t), 0), G(0, 1.0, 0.6), 0.07 * (1.0 - 0.5 * t), 0.01, "r:tail", BONE, -0.3))
        for sx in (-1, 1):
            add(GK.claw("Bone", p + G(sx * 0.04 * (1 - t), 0, 0), G(sx, 0.2, 0.5), 0.045 * (1.0 - 0.5 * t), 0.007, "r:tail", BONE, -0.2))
    # legs: forelegs (shoulder, elbow back, a long forearm onto the paw), hind legs (thigh, stifle
    # forward, a hock, a long metatarsal): hound legs, not stilts
    for tag in ("fl", "fr", "bl", "br"):
        sx = -1 if tag.endswith("l") else 1
        front = tag.startswith("f")
        hip, kn, ft = S["leg_%s_hip" % tag], S["leg_%s_knee" % tag], S["leg_%s_foot" % tag]
        lg = Flesh("leg_" + tag)
        if front:
            lg.ball(hip + G(sx * 0.0, 0.01, 0.0), (0.08, 0.1, 0.09), 1.5)
            lg.along(hip + G(0, -0.02, 0.0), kn + G(0, 0.04, 0.0), (0.078, 0.07), None)
            lg.ball(kn, (0.04, 0.045, 0.045))
            lg.ball(kn + G(0, 0.0, 0.035), (0.025, 0.03, 0.02), 4.0)                     # point of the elbow
            lg.along(kn + G(0, -0.02, -0.01), kn + G(0, -0.14, -0.015), (0.04, 0.036), None)
            lg.chain([kn + G(0, -0.02, 0), ft + G(0, 0.04, 0.0)], [0.035, 0.022])
            lg.ball(ft + G(0, 0.02, 0.0), (0.025, 0.03, 0.03))                           # wrist
        else:
            lg.ball(hip + G(sx * 0.0, 0.02, 0.02), (0.09, 0.125, 0.125), 1.5)                # the haunch into the thigh
            lg.along(hip + G(0, -0.02, 0.0), kn + G(0, 0.05, 0.02), (0.088, 0.08), None)
            lg.ball(kn, (0.04, 0.045, 0.045))
            hock = kn + G(0, -0.16, 0.14)
            lg.along(kn + G(0, -0.02, 0.02), hock + G(0, 0.06, -0.04), (0.045, 0.04), None)   # gaskin
            lg.chain([kn, hock, ft + G(0, 0.03, 0.0)], [0.035, 0.024, 0.022])
            lg.ball(hock + G(0, 0.0, 0.015), (0.022, 0.03, 0.028), 4.0)                  # point of the hock
            lg.ball(ft + G(0, 0.02, 0.0), (0.024, 0.028, 0.028))
        # the paw: a pad, four toes, hooked claws
        lg.ball(ft + G(0, -0.01, -0.02), (0.046, 0.026, 0.05))
        for k in range(4):
            tx = (k - 1.5) * 0.018
            lg.ball(ft + G(tx, -0.012, -0.055 - 0.01 * (1.5 - abs(k - 1.5))), (0.012, 0.014, 0.016))
        build(lg, "Leg_" + tag, SKIN, 0.005, 0.0012, 4)
        for k in range(4):
            tx = (k - 1.5) * 0.018
            add(GK.claw("Claw", ft + G(tx, -0.01, -0.07 - 0.01 * (1.5 - abs(k - 1.5))), G(tx * 2, -0.6, -1.0), 0.09, 0.0085, "leg_" + tag, CLAW, 0.7))
        if not front:
            add(GK.claw("Bone", hip + G(sx * 0.06, 0.06, 0.04), G(sx * 0.7, 0.6, 0.4), 0.08, 0.012, "leg_" + tag, BONE, -0.2))   # a spur off the haunch

# =====================================================================================================
elif KIND == "crawler":
    # r38: a bone spider. A cage of ribs arched over a swollen ember-lit abdomen, a grinning skull
    # head with a pair of fang-mandibles, eight legs of long bone (the rig's four, plus four more
    # skinned to their neighbours) with knuckled joints, barbs down the shin and a blade at the tip.
    SKIN = mat(GK.ember_chitin("Skin", (0.05, 0.042, 0.045), (0.2, 0.15, 0.13), plates=15.0, rough=0.55))
    BONE = mat(GK.grave_bone("Bone", (0.46, 0.4, 0.3), (0.14, 0.1, 0.07), 8.0))
    SAC = mat(GK.membrane("Sac", (1.0, 0.38, 0.08), 6.0, (0.2, 0.09, 0.06)))
    KEEP.update({"Bone", "Sac"})
    bd = Flesh("spine")
    bd.ball(B + G(0, 0.0, -0.17), (0.125, 0.09, 0.16))                      # thorax
    bd.ball(B + G(0, -0.02, 0.18), (0.12, 0.085, 0.2))                      # the abdomen's under-skin, below the cage
    for k in range(4):
        z = -0.27 + 0.17 * k
        for sx in (-1, 1):
            bd.ball(B + G(sx * 0.1, -0.01, z), (0.045, 0.045, 0.05))
    bd.chain([B + G(0, 0.0, -0.26), F + G(0, 0.0, 0.0), H + G(0, -0.01, 0.06)], [0.09, 0.07, 0.055])
    bd.chain([B + G(0, 0.03, 0.3), T + G(0, 0.0, 0.1)], [0.1, 0.05])
    build(bd, "Body", SKIN, 0.006, 0.0015, 1)
    # the swollen glowing abdomen inside the cage
    add(K.blob("Sac", B + G(0, 0.03, 0.19), (0.125, 0.2, 0.11), "spine", SAC, 28, 16))
    # eight rib arches over it, graded; two bony spines at the front of the thorax
    for k in range(9):
        z = -0.01 + 0.048 * k
        s = 0.55 + 0.45 * math.sin(math.pi * (k + 0.8) / 9.8)
        w, hh = 0.19 * s, 0.17 * s
        pts = [B + G(math.sin(a) * w, -0.005 + math.cos(a) * hh * 1.05, z + 0.012 * math.sin(a * 2.0)) for a in [-1.85 + 3.7 * j / 12.0 for j in range(13)]]
        add(K.loft("Bone", pts, [(0.0125 * (0.6 + 0.4 * s), 0.009)] * 13, "spine", BONE, 6))
    # the spine: knuckled vertebrae the length of the back, each with a hooked spur
    for k in range(13):
        t = k / 12.0
        z = -0.3 + 0.7 * t
        y = 0.085 + 0.095 * math.sin(math.pi * min(1.0, t * 1.15)) + 0.1 * (0.5 - abs(t - 0.62))
        add(K.blob("Bone", B + G(0, y, z), (0.022 * (1.1 - 0.5 * t), 0.024, 0.02), "spine", BONE, 10, 6))
        add(GK.claw("Bone", B + G(0, y + 0.008, z), G(0, 1.0, 0.7), 0.075 * (1.0 - 0.45 * t) + 0.015, 0.011, "spine", BONE, -0.3))
    # shoulder hooks over the front leg roots
    for sx in (-1, 1):
        add(GK.claw("Bone", B + G(sx * 0.13, 0.05, -0.24), G(sx * 0.7, 1.0, -0.3), 0.15, 0.022, "spine", BONE, -0.45))
        add(GK.claw("Bone", B + G(sx * 0.12, 0.03, 0.0), G(sx * 0.9, 0.7, 0.0), 0.11, 0.017, "spine", BONE, -0.35))

    def skull_c(c):
        p = Vector(c)
        n = p.normalized()
        push = 0.0
        for sx in (-1, 1):
            d = (p - Vector((sx * 0.45, 0.88, 0.1))).length
            push -= 0.24 * math.exp(-(d / 0.26) ** 2)
            d = (p - Vector((sx * 0.62, 0.62, 0.42))).length
            push -= 0.12 * math.exp(-(d / 0.18) ** 2)
        d = (p - Vector((0, 0.98, -0.25))).length
        push -= 0.14 * math.exp(-(d / 0.14) ** 2)
        return p + n * push
    hd = Flesh("head")
    hd.ball(H + G(0, 0.0, -0.02), (0.07, 0.055, 0.075))
    hd.ball(H + G(0, -0.02, 0.05), (0.06, 0.05, 0.05))
    build(hd, "Head", SKIN, 0.004, 0.001, 2)
    add(K.blob("Bone", H + G(0, 0.01, -0.035), (0.075, 0.1, 0.075), "head", BONE, 36, 18, skull_c))
    add(K.blob("Bone", H + G(0, -0.05, -0.1), (0.045, 0.06, 0.018), "head", BONE, 16, 8))                 # the lower jaw
    for sx in (-1, 1):
        add(K.blob("Eye", H + G(sx * 0.034, 0.012, -0.108), (0.013, 0.01, 0.013), "head", EYE, 12, 8))
        add(K.blob("Eye", H + G(sx * 0.046, 0.045, -0.085), (0.008, 0.007, 0.008), "head", EYE, 10, 6))
        add(GK.claw("Bone", H + G(sx * 0.038, -0.04, -0.105), G(-sx * 0.3, -0.35, -1.0), 0.2, 0.017, "head", BONE, 0.5))
        add(GK.claw("Bone", H + G(sx * 0.02, -0.04, -0.115), G(-sx * 0.1, -0.25, -1.0), 0.09, 0.009, "head", BONE, 0.3))
        add(GK.claw("Bone", H + G(sx * 0.06, 0.06, 0.0), G(sx * 0.8, 0.7, 0.3), 0.14, 0.014, "head", BONE, -0.4))     # brow horns

    def leg_bone(name, a, b, r, bulge, sock, rk=1.0, side=0.0):
        mid = (a + b) * 0.5 + G(side, bulge, 0)
        pts = [a, a.lerp(mid, 0.5), mid, mid.lerp(b, 0.5), b]
        rad = [r * 1.25, r * 0.9, r * 0.85, r * 0.8 * rk, r * 1.0 * rk]
        return K.loft(name, [Vector(p) for p in pts], rad, sock, BONE, 8, wobble=0.07)

    def leg(tag, sx, hip, kn, ft, scale, front):
        sock = "leg_" + tag
        r = 0.03 * scale
        add(K.blob("Skin", hip, (r * 1.6, r * 1.6, r * 1.6), sock, SKIN, 14, 8))
        add(K.blob("Skin", kn, (r * 1.25, r * 1.25, r * 1.25), sock, SKIN, 14, 8))
        add(leg_bone("Bone", hip + G(sx * 0.02, 0.0, 0.0), kn, 0.03 * scale, 0.06, sock))
        add(K.blob("Bone", kn, (r * 1.2, r * 1.2, r * 1.2), sock, BONE, 14, 8))                     # the knuckled knee
        add(GK.claw("Bone", kn + G(0, 0.01, 0.0), G(sx * 0.25, 1.0, -0.2), 0.11 * scale, 0.018 * scale, sock, BONE, -0.35))   # knee spur
        tip = ft + G(0, 0.04, 0)
        add(leg_bone("Bone", kn, tip, 0.022 * scale, 0.0, sock, 0.5, side=sx * 0.055))
        for t in (0.3, 0.52, 0.74):
            p = kn.lerp(ft, t)
            add(GK.claw("Bone", p, G(sx * 0.9, 0.5, 0.15), 0.06 * scale * (1.1 - 0.4 * t), 0.008, sock, BONE, -0.2))
        add(GK.claw("Claw", ft + G(0, 0.04, 0), G(sx * 0.15, -1.0, -0.35), 0.1 * scale, 0.013 * scale, sock, CLAW, 0.35))

    for tag in ("fl", "fr", "bl", "br"):
        sx = -1 if tag.endswith("l") else 1
        front = tag.startswith("f")
        hip, kn, ft = S["leg_%s_hip" % tag], S["leg_%s_knee" % tag], S["leg_%s_foot" % tag]
        leg(tag, sx, hip, kn, ft, 1.0, front)
        dz = 0.17 if front else -0.17
        # the second pair of each side: shorter, set between the main legs, skinned to its neighbour
        leg(tag, sx, hip + G(0, 0.0, dz), kn + G(sx * -0.03, -0.03, dz), ft + G(sx * -0.06, 0.0, dz), 0.85, front)

else:
    big = {"crawler": 1.0, "burrower": 1.15, "mite": 0.9}[KIND]
    if KIND == "crawler":
        SKIN = mat(GK.ember_chitin("Skin", (0.06, 0.05, 0.052), (0.2, 0.15, 0.13), plates=15.0, rough=0.55))
        SHELL = mat(GK.ember_chitin("Chitin", (0.05, 0.042, 0.045), (0.26, 0.2, 0.17), plates=9.0, rough=0.46, strength=2.2))
    elif KIND == "burrower":
        SKIN = mat(GK.ember_chitin("Skin", (0.12, 0.085, 0.055), (0.34, 0.26, 0.18), plates=12.0, rough=0.7, strength=1.8))
        SHELL = mat(GK.ember_chitin("Chitin", (0.1, 0.07, 0.045), (0.36, 0.28, 0.2), plates=8.0, rough=0.66, strength=1.8))
    else:
        SKIN = mat(GK.ember_chitin("Skin", (0.2, 0.18, 0.21), (0.46, 0.42, 0.45), plates=18.0, rough=0.5, strength=2.0))
        SHELL = mat(GK.ember_chitin("Chitin", (0.17, 0.15, 0.18), (0.5, 0.46, 0.5), plates=14.0, rough=0.44, strength=2.0))
    # chitin is fused + decimated with the rest (kept apart it was half the triangles)
    # body: a thorax at the front, a swollen abdomen behind, hung low between the knees
    bd = Flesh("spine")
    bd.ball(B + G(0, 0.0, -0.18), (0.13 * big, 0.09 * big, 0.17))
    bd.ball(B + G(0, 0.02, 0.17), (0.16 * big, 0.12 * big, 0.21))
    bd.ball(B + G(0, -0.05, 0.05), (0.1 * big, 0.06, 0.14))
    for k in range(4):
        z = -0.25 + 0.17 * k
        for sx in (-1, 1):
            bd.ball(B + G(sx * 0.1 * big, -0.01, z), (0.04, 0.04, 0.05))                   # leg roots
    bd.chain([B + G(0, 0.0, -0.26), F + G(0, 0.0, 0.0), H + G(0, -0.01, 0.06)], [0.09 * big, 0.07, 0.055])
    bd.chain([B + G(0, 0.03, 0.3), T + G(0, 0.0, 0.1)], [0.1 * big, 0.06])
    build(bd, "Body", SKIN, 0.006, 0.0015, 1)
    # overlapping chitin plates down the back, side plates on the abdomen
    n = 7
    for k in range(n):
        t = k / (n - 1)
        z = -0.3 + 0.62 * t
        y = 0.075 * big + 0.05 * math.sin(t * math.pi) * big
        w = (0.11 + 0.07 * math.sin(t * math.pi)) * big
        add(GK.plate("Chitin", B + G(0, y, z), (w, 0.075, 0.03), G(0, 1.0, 0.35), "spine", SHELL, 28, 3.0))
    for sx in (-1, 1):
        for k in range(3):
            z = 0.05 + 0.13 * k
            add(GK.plate("Chitin", B + G(sx * 0.13 * big, 0.0, z), (0.05, 0.06, 0.02), G(sx, 0.5, 0.2), "spine", SHELL, 18, 2.0))
    # head: a blunt chitin head, mandibles; four eyes (the burrower is eyeless, a ridged snout)
    hd = Flesh("head")
    hd.ball(H + G(0, 0.0, -0.02), (0.075 * big, 0.06 * big, 0.08))
    hd.ball(H + G(0, -0.02, 0.05), (0.06, 0.05, 0.05))
    build(hd, "Head", SKIN, 0.004, 0.001, 2)
    add(GK.plate("Chitin", H + G(0, 0.04 * big, -0.02), (0.075 * big, 0.08, 0.025), G(0, 1.0, -0.3), "head", SHELL, 24, 3.0))
    if KIND == "burrower":
        for k in range(5):
            add(GK.plate("Chitin", H + G(0, 0.05 - 0.01 * k, -0.06 - 0.035 * k), (0.06 - 0.007 * k, 0.04, 0.018), G(0, 1.0, -0.6), "head", SHELL, 18, 3.0))
        add(GK.claw("Claw", H + G(0, -0.01, -0.21), G(0, -0.3, -1.0), 0.09, 0.024, "head", CLAW, 0.4))
    else:
        for k in range(4):
            ex = (0.024 + 0.022 * (k % 2)) * (-1 if k < 2 else 1)
            add(K.blob("Eye", H + G(ex, 0.03 + 0.012 * (k % 2), -0.085 + 0.015 * (k % 2)), (0.011, 0.01, 0.01), "head", EYE, 10, 6))
        for sx in (-1, 1):
            add(GK.claw("Claw", H + G(sx * 0.04, -0.03, -0.07), G(-sx * 0.35, -0.3, -1.0), 0.09 * big, 0.012, "head", CLAW, 0.5))
    # legs: segmented, a swollen band at each joint, spines down the shin, a hooked tip on the ground
    for tag in ("fl", "fr", "bl", "br"):
        sx = -1 if tag.endswith("l") else 1
        hip, kn, ft = S["leg_%s_hip" % tag], S["leg_%s_knee" % tag], S["leg_%s_foot" % tag]
        lg = Flesh("leg_" + tag)
        r = 0.032 * big
        lg.ball(hip, (r * 1.3, r * 1.3, r * 1.3))
        lg.chain([hip, kn], [r * 1.15, r * 0.9])
        lg.ball(kn, (r * 1.05, r * 1.05, r * 1.05))
        lg.chain([kn, kn.lerp(ft, 0.5), ft + G(0, 0.03, 0)], [r * 0.9, r * 0.7, r * 0.45])
        build(lg, "Leg_" + tag, SKIN, 0.0045, 0.001, 4)
        # models pass: armoured segments, not beads on a tube: a femur and a tibia sheath each swell
        # mid-shaft and stop short of the joints, so the soft, darker articulation shows between them
        # (the old round chitin balls read as a toy)
        def sheath(a, b, r0, rmid, r1, n=7):
            pts, rad = [], []
            for i in range(n):
                t = 0.08 + 0.84 * i / (n - 1)
                pts.append(a.lerp(b, t))
                u = i / (n - 1)
                base = r0 + (r1 - r0) * u
                rad.append(base + (rmid - base) * math.sin(math.pi * u))
            return K.loft("Chitin", pts, rad, "leg_" + tag, SHELL, 12)
        add(sheath(hip, kn, r * 1.25, r * 1.45, r * 1.0))
        mid = kn.lerp(ft, 0.62)
        add(sheath(kn, mid, r * 1.0, r * 1.15, r * 0.78))
        add(sheath(mid, ft + G(0, 0.03, 0), r * 0.74, r * 0.8, r * 0.5))
        for t in (0.25, 0.5, 0.75):
            p = kn.lerp(ft, t)
            if KIND != "mite":
                add(GK.claw("Claw", p + G(sx * r * 0.75, 0, 0), G(sx, 0.4, 0.2), 0.05 * big, 0.007, "leg_" + tag, CLAW, -0.2))
        # the hooked tip that takes the weight; the burrower's forelegs end in spades
        if KIND == "burrower" and tag.startswith("f"):
            for k in range(3):
                a = (k - 1) * 0.42
                d = G(math.sin(a) * 0.8 + sx * 0.15, -0.18, -math.cos(a)).normalized()
                cl = GK.claw("Claw", ft + G(0, 0.06, 0), d, 0.22, 0.036, "leg_" + tag, CLAW, 0.3)
                # flatten it into a spade blade across the dig direction
                side = d.cross(Vector((0, 0, 1))).normalized()
                for v in cl.data.vertices:
                    rel = v.co - (ft + G(0, 0.06, 0))
                    along = rel.dot(d)
                    perp = rel - d * along
                    v.co = (ft + G(0, 0.06, 0)) + d * along + side * perp.dot(side) * 1.5 + (perp - side * perp.dot(side)) * 0.28
                add(cl)
        else:
            add(GK.claw("Claw", ft + G(0, 0.03, 0), G(sx * 0.2, -1.0, -0.4), 0.07 * big, 0.012 * big, "leg_" + tag, CLAW, 0.4))

    if KIND == "burrower":
        EARTH = mat(GK.earth("Earth"))
        AMBER = mat(GK.glow("Glow", (1.0, 0.5, 0.12), 3.0, (0.05, 0.03, 0.01)))
        # a domed carapace crusted with earth; amber light leaking from under its rim
        def dome(c):
            p = Vector(c)
            if p.z < 0:
                p.z *= 0.15
            p += p.normalized() * 0.06 * noise.noise(p * 4.0)
            return p
        add(K.blob("Chitin", B + G(0, 0.06, 0.02), (0.24, 0.36, 0.16), "spine", SHELL, 48, 20, dome))
        for k in range(26):
            a = math.tau * noise.noise(Vector((k, 1.0, 0))) * 3.0
            rr = 0.5 + 0.5 * noise.noise(Vector((k, 2.0, 0)))
            cx, cz = math.cos(a) * 0.2 * rr, math.sin(a) * 0.3 * rr
            top = 0.06 + 0.16 * math.sqrt(max(0.0, 1.0 - (cx / 0.24) ** 2 - (cz / 0.36) ** 2))
            c = B + G(cx, top - 0.005, cz + 0.02)
            add(K.blob("Earth", c, (0.04 + 0.02 * (k % 3), 0.035 + 0.015 * (k % 2), 0.025), "spine", EARTH, 12, 8, lambda q: q + q.normalized() * 0.3 * noise.noise(q * 3.0)))
        rim = [B + G(math.cos(a) * 0.222, 0.045, math.sin(a) * 0.335 + 0.02) for a in [math.tau * i / 40 for i in range(41)]]
        add(K.loft("Glow", rim, [(0.008, 0.005)] * 41, "spine", AMBER, 6))
    elif KIND == "mite":
        SAC = mat(GK.membrane("Sac", (0.25, 1.0, 0.8), 7.0, (0.3, 0.42, 0.4)))
        add(K.blob("Sac", B + G(0, 0.13, 0.12), (0.11, 0.14, 0.09), "spine", SAC, 32, 16))
        for k in range(6):
            a = math.tau * k / 6.0
            add(K.loft("Chitin", [B + G(math.cos(a) * 0.115, 0.08, 0.12 + math.sin(a) * 0.14), B + G(math.cos(a) * 0.08, 0.2, 0.12 + math.sin(a) * 0.1),
                                  B + G(math.cos(a) * 0.02, 0.23, 0.12 + math.sin(a) * 0.02)], [0.01, 0.007, 0.004], "spine", SHELL, 6))
        for k in range(5):
            add(GK.claw("Claw", B + G(0, 0.09, -0.06 - 0.05 * k), G(0, 1.0, 0.5), 0.06, 0.012, "spine", CLAW, -0.3))

dec = {"mite": 0.05, "leaper": 0.06, "crawler": 0.08, "burrower": 0.08}[KIND]
objs[:] = K.fuse(objs, 0.0034, keep=KEEP | {"Tooth"}, sculpt=0.0012, sculpt_scale=0.018, decimate=dec, folds=0.0016 if KIND in ("leaper", "crawler") else 0.0, fold_mats={"Skin"})
print("GRUNT", KIND, "parts", len(objs), "tris", sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objs))
if PREVIEW:
    K.preview(PREVIEW, BH * 0.8, 2.6 if KIND != "leaper" else 3.4, views=((35, BH + 0.5), (95, BH + 0.3)))
if EXPORT:
    GK.export_skinned(objs, MATS, "grunt_" + KIND, S, WEIGHTS, {}, 1024 if KIND == "mite" else 2048,
                      {"mite": 5000, "crawler": 9000, "burrower": 10000, "leaper": 11000}[KIND])
