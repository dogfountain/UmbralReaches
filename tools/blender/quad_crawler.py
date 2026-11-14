"""Crawler (r38d): a bone spider. One continuous sculpted skin: an ember-cracked chitin thorax pinched to a
waist, a swollen glowing abdomen held in a cage of rib arches that grow out of its surface, a skull for a
face with four ember eyes, long hooked fangs and brow horns, and eight legs of knuckled bone (the rig's four
plus four more skinned to their neighbours): a femur that climbs out of a coxa, a patella knob with its
spur, a barbed tibia, a bowed metatarsus and a hooked tarsal claw.   Rig: QuadRig, spider layout."""
import math
import os
import sys
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import boss_kit as K
import grunt_kit as GK
import quad_sdf as Q
import quad_parts as Pt
import quad_run as R
from quad_parts import V

NAME = "Crawler"
PREFIX = "grunt_crawler"
VOXEL, SUB, TRIS, SIZE, BAND = 0.0038, 1, 11800, 2048, 0.04
PREVIEW = ((0, 0.3, 0.0), 2.4)
EXTRUDE, RAY = 0.02, 0.06
S = R.rig_sockets(0.34, 0.72, 0.14, 0.24, False)
B, FR, H, T = S["body"], S["front"], S["head"], S["tail"]
EXTRA = []        # (bone prefix, hip, knee, foot, sx) of the four inner legs, for the weights


def sockets():
    return S


def segments(S):
    segs = R.rig_bones(S, 0.3, 0.2)
    # the rib cage and the sac ride the body bone, whatever the hind legs do under them
    segs += [("body", V(sx_ * 0.17, 0.4, 0.05), V(sx_ * 0.17, 0.4, 0.45), 0.05) for sx_ in (-1, 0, 1)] + [("body", V(0, 0.6, 0.08), V(0, 0.6, 0.42), 0.05)]
    for (t, sx, hp, kn, ft) in EXTRA:
        segs += [("leg_%s_hip" % t, hp, kn, 0.03), ("leg_%s_knee" % t, kn, ft, 0.03), ("leg_%s_foot" % t, ft, ft + V(0, -0.02, 0.0), 0.03)]
    return segs


def leg(F, sx, hip, kn, ft, sc):
    F.add(Q.Ell(hip + V(-sx * 0.015, 0.0, 0.0), (0.048 * sc, 0.042 * sc, 0.046 * sc)), 0.04, "chitin")        # coxa, rooted in the thorax
    mid = (hip + kn) * 0.5 + V(0, 0.042 * sc, 0)
    Pt.chain(F, [hip, mid, kn], [0.042 * sc, 0.036 * sc, 0.03 * sc], 0.02, "bone")                          # femur
    F.add(Q.Ell(kn, (0.04 * sc, 0.038 * sc, 0.038 * sc)), 0.015, "chitin")                                   # patella knuckle
    Pt.claw(F, kn + V(0, 0.02, 0), (sx * 0.15, 1, 0), 0.1 * sc, 0.016 * sc, (sx * 0.3, 0, 0.1), 0.02, "bone", 3)  # knee spur
    d = ft - kn
    p1 = kn + d * 0.35 + V(sx * 0.075, 0, 0)
    p2 = kn + d * 0.72 + V(sx * 0.04, 0, 0)
    tip = ft + V(0, 0.012, 0)
    Pt.chain(F, [kn, p1, p2, tip], [0.032 * sc, 0.025 * sc, 0.017 * sc, 0.0095 * sc], 0.012, "bone")        # tibia, metatarsus
    F.add(Q.Ell(p1, (0.026 * sc, 0.024 * sc, 0.026 * sc)), 0.012, "chitin")                                  # second joint
    for t_, L in ((0.2, 0.07), (0.45, 0.062), (0.7, 0.052)):                                                 # barbs down the shin
        p = kn + d * t_ + V(sx * (0.075 * (1 - abs(t_ - 0.4) * 1.5)), 0, 0)
        Pt.claw(F, p, (sx * 0.9, 0.45, 0.15), L * sc, 0.0085 * sc, (0, 0.3, 0), 0.008, "bone", 2)
    Pt.claw(F, tip, (sx * 0.1, -0.9, -0.4), 0.075 * sc, 0.0105 * sc, (0, -0.5, -0.9), 0.006, "claw", 3)      # the hooked tarsal claw


def field():
    F = Q.Field()
    # thorax: a carapace pinched to a waist; abdomen: a swollen sac
    thorax = Q.Loft([(-0.38, 0, 0.385, 0.05, 0.045, 0.04), (-0.34, 0, 0.38, 0.1, 0.085, 0.075), (-0.22, 0, 0.385, 0.145, 0.105, 0.085),
                     (-0.1, 0, 0.375, 0.125, 0.09, 0.08), (-0.03, 0, 0.352, 0.06, 0.05, 0.05), (0.0, 0, 0.35, 0.045, 0.045, 0.045)])
    F.add(thorax, 0.04, "chitin")
    sac = Q.Loft([(-0.01, 0, 0.35, 0.045, 0.045, 0.045), (0.05, 0, 0.365, 0.125, 0.13, 0.1), (0.15, 0, 0.395, 0.195, 0.22, 0.15),
                  (0.27, 0, 0.4, 0.215, 0.24, 0.16), (0.38, 0, 0.385, 0.175, 0.19, 0.12), (0.47, 0, 0.345, 0.09, 0.08, 0.07), (0.52, 0, 0.335, 0.03, 0.03, 0.03)])
    F.add(sac, 0.05, "sac")
    # rib arches over the sac, standing proud of it
    for k in range(9):
        z = 0.05 + 0.047 * k
        s_ = 0.55 + 0.45 * math.sin(math.pi * (k + 0.9) / 9.8)
        w, h = 0.215 * s_ * 1.05, 0.24 * s_ * 1.04
        cy = 0.4
        pts = [V(math.sin(a) * w, cy + math.cos(a) * h, z + 0.01 * math.sin(a * 2.0)) for a in [-1.9 + 3.8 * j / 14.0 for j in range(15)]]
        Pt.chain(F, pts, [0.0125 * (0.65 + 0.35 * s_)] * 15, [0.01] * 14, "bone")
    # spurs along the carapace ridge, a hooked vertebra on each
    for k in range(6):
        z = -0.3 + 0.045 * k
        Pt.claw(F, V(0, 0.46 - 0.013 * k, z), (0, 1, 0.5), 0.08 * (1.0 - 0.1 * k), 0.013, (0, 0, 1), 0.015, "bone", 3)
    for sx in (-1, 1):                                                           # shoulder hooks over the front legs
        Pt.claw(F, V(sx * 0.11, 0.4, -0.27), (sx * 0.7, 1, -0.3), 0.14, 0.022, (-sx * 0.3, 0.3, 0.3), 0.025, "bone", 4)
    # the head: a skull with its own eye pits, brow horns and fangs
    hz = H[2]
    F.add(Q.Ell((0, H[1] + 0.01, hz - 0.02), (0.068, 0.058, 0.072)), 0.04, "bone")
    F.add(Q.Ell((0, H[1] - 0.012, hz - 0.075), (0.05, 0.044, 0.05)), 0.03, "bone")
    F.add(Q.Ell((0, H[1] - 0.05, hz - 0.09), (0.04, 0.014, 0.05)), 0.018, "bone")                           # lower jaw
    Pt.chain(F, [V(0, 0.375, -0.34), V(0, 0.388, -0.42), V(0, H[1] - 0.005, hz + 0.01)], [0.05, 0.055, 0.058], 0.04, "chitin")   # neck
    for sx in (-1, 1):
        F.sub(Q.Ell((sx * 0.032, H[1] + 0.012, hz - 0.085), (0.017, 0.015, 0.013)), 0.01)
        F.add(Q.Ell((sx * 0.032, H[1] + 0.012, hz - 0.082), (0.0105, 0.009, 0.008)), 0.0, "eye")
        F.sub(Q.Ell((sx * 0.048, H[1] + 0.045, hz - 0.058), (0.012, 0.011, 0.009)), 0.008)
        F.add(Q.Ell((sx * 0.047, H[1] + 0.045, hz - 0.055), (0.0075, 0.0065, 0.006)), 0.0, "eye")
        Pt.claw(F, V(sx * 0.036, H[1] - 0.035, hz - 0.1), (-sx * 0.25, -0.35, -1.0), 0.2, 0.019, (-sx * 0.8, -0.35, -0.3), 0.012, "bone", 5)   # fangs
        Pt.claw(F, V(sx * 0.02, H[1] - 0.04, hz - 0.11), (-sx * 0.1, -0.25, -1.0), 0.09, 0.011, (-sx * 0.5, -0.4, -0.3), 0.01, "bone", 4)
        Pt.claw(F, V(sx * 0.055, H[1] + 0.05, hz - 0.01), (sx * 0.8, 0.7, 0.3), 0.14, 0.016, (sx * 0.1, -0.2, 0.9), 0.015, "bone", 4)       # brow horns
        Pt.chain(F, [V(sx * 0.05, H[1] - 0.03, hz - 0.06), V(sx * 0.07, H[1] - 0.05, hz - 0.15), V(sx * 0.05, H[1] - 0.085, hz - 0.2)], [0.011, 0.009, 0.006], 0.01, "bone")   # palps
    # the eight legs
    for t in ("fl", "fr", "bl", "br"):
        sx = -1 if t.endswith("l") else 1
        front = t.startswith("f")
        hp, kn, ft = S["leg_%s_hip" % t], S["leg_%s_knee" % t], S["leg_%s_foot" % t]
        leg(F, sx, hp, kn, ft, 1.0)
        dz = 0.17 if front else -0.17
        h2, k2, f2 = hp + V(0, 0, dz), kn + V(-sx * 0.03, -0.03, dz), ft + V(-sx * 0.06, 0, dz)
        leg(F, sx, h2, k2, f2, 0.88)
        EXTRA.append((t, sx, h2, k2, f2))
    return F


def detail(ctx):
    sc = ctx.sc
    P = ctx.P
    hy, hz = H[1], H[2]
    for sx in (-1, 1):
        sc.bump((sx * 0.032, hy + 0.012, hz - 0.1), 0.02, -0.014, facing=(sx * 0.4, 0, -1))
        sc.ridge((sx * 0.01, hy + 0.05, hz - 0.095), (sx * 0.062, hy + 0.045, hz - 0.055), 0.011, 0.009, facing=(0, 1, -0.4))
        sc.bump((sx * 0.06, hy - 0.01, hz - 0.03), 0.02, -0.009, facing=(sx, 0, 0))                  # temple hollow
    sc.bump((0, hy - 0.012, hz - 0.115), 0.012, -0.012, facing=(0, 0, -1))                           # nose hole
    # chitin plate ridges across the carapace, the cage's seams
    for k in range(7):
        z = -0.37 + 0.04 * k
        sc.ridge((-0.12, 0.31, z), (0.12, 0.31, z), 0.009, 0.007, facing=(0, 1, 0))
    sc.noise(36.0, 0.0018)
    sc.noise(95.0, 0.0006, seed=5)
    sc.folds(80.0, 0.0008)
    SKIN = GK.ember_chitin("Skin", (0.05, 0.042, 0.045), (0.2, 0.15, 0.13), plates=15.0, rough=0.55)
    BONE = GK.grave_bone("Bone", (0.46, 0.4, 0.3), (0.14, 0.1, 0.07), 8.0)
    SAC = GK.membrane("Sac", (1.0, 0.38, 0.08), 4.2, (0.2, 0.09, 0.06))
    CLAW = GK.chitin("Claw", (0.045, 0.036, 0.032), (0.32, 0.25, 0.18), 14.0, 0.42)
    EYE = GK.glow("Eye", (1.0, 0.16, 0.08), 8.0)
    tags = ["chitin", "bone", "sac", "claw", "eye"]
    idx = ctx.region(tags, {"bone": 0.004, "claw": 0.003, "eye": 0.004})
    return [SKIN, BONE, SAC, CLAW, EYE], idx.astype(np.int32)


if __name__ == "__main__":
    R.run(__import__(__name__))
