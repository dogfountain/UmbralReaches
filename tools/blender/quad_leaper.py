"""Leaper (r38d): a starved, long-legged hound of the gloom. One sculpted skin: a deep keel of a ribcage
tucked up to a hollow waist, a scapula standing out behind the shoulder, a thigh of long flat muscle over a
thin cannon bone with the hock standing out and the Achilles cord strung to it, paws with toes and hooked
claws, a wolf skull with a short muzzle, a brow, bared teeth, swept-back horns, a spine of bone spurs grown
out of the vertebrae and a long whip of a tail.   Rig: QuadRig upright (core/enemy/leaper.gd)."""
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

NAME = "Leaper"
PREFIX = "grunt_leaper"
VOXEL, SUB, TRIS, SIZE, BAND = 0.0045, 1, 10600, 2048, 0.045
PREVIEW = ((0, 0.42, 0.15), 2.9)
EXTRUDE, RAY = 0.02, 0.07
S = R.rig_sockets(0.56, 1.15, 0.2, 0.32, True)
B, FR, H, T = S["body"], S["front"], S["head"], S["tail"]
KEYS = [(-0.52, 0.0, 0.585, 0.055, 0.055, 0.055), (-0.46, 0.0, 0.58, 0.1, 0.11, 0.13), (-0.36, 0.0, 0.565, 0.145, 0.15, 0.24),
        (-0.24, 0.0, 0.555, 0.155, 0.15, 0.26), (-0.1, 0.0, 0.565, 0.135, 0.125, 0.205), (0.02, 0.0, 0.58, 0.1, 0.1, 0.1),
        (0.12, 0.0, 0.585, 0.082, 0.088, 0.075), (0.26, 0.0, 0.585, 0.12, 0.11, 0.1), (0.4, 0.0, 0.585, 0.095, 0.09, 0.08),
        (0.5, 0.0, 0.58, 0.05, 0.05, 0.045)]
TRUNK = Q.Loft(KEYS)


def top(z):
    return float(np.interp(z, TRUNK.zs, TRUNK.tab[:, 1] + TRUNK.tab[:, 3]))


def sockets():
    return S


def segments(S):
    segs = R.rig_bones(S, 0.5, 0.2)
    segs += [("body", V(0.1, 0.69, -0.33), V(0.2, 0.52, -0.40), 0.03), ("body", V(0.0, 0.7, -0.3), V(0.0, 0.72, 0.3), 0.03)]
    segs += [("body", V(-0.1, 0.69, -0.33), V(-0.2, 0.52, -0.40), 0.03)]
    return segs


def field():
    F = Q.Field()
    F.add(TRUNK, 0.05, "hide")
    # neck and skull
    Pt.chain(F, [V(0, 0.60, -0.42), V(0, 0.655, -0.53), V(0, 0.665, -0.62), V(0, 0.655, H[2] + 0.02)], [0.1, 0.075, 0.062, 0.055], 0.05)
    hz = H[2]
    F.add(Q.Ell((0, H[1] + 0.03, hz + 0.0), (0.052, 0.054, 0.072)), 0.035, "hide")
    F.add(Q.RoundCone((0, H[1] + 0.012, hz - 0.045), (0, H[1] - 0.005, hz - 0.145), 0.04, 0.028, 0.82, (0, 1, 0)), 0.03, "hide")
    F.add(Q.Ell((0, H[1] - 0.002, hz - 0.165), (0.028, 0.022, 0.03)), 0.015, "hide")
    for sx in (-1, 1):
        F.add(Q.Ell((sx * 0.047, H[1] + 0.005, hz - 0.015), (0.012, 0.024, 0.05)), 0.02, "hide")          # cheekbone
        F.add(Q.Ell((sx * 0.032, H[1] + 0.052, hz - 0.06), (0.02, 0.014, 0.03), (0.2, 0, 0)), 0.012, "hide")    # brow
        Pt.chain(F, [V(sx * 0.034, H[1] - 0.04, hz + 0.01), V(sx * 0.03, H[1] - 0.07, hz - 0.08), V(sx * 0.016, H[1] - 0.072, hz - 0.15)], [0.017, 0.013, 0.011], 0.012)   # lower jaw, slung open
        Pt.chain(F, [V(sx * 0.03, H[1] + 0.07, hz + 0.045), V(sx * 0.045, H[1] + 0.13, hz + 0.065), V(sx * 0.058, H[1] + 0.175, hz + 0.08)], [0.022, 0.017, 0.006], 0.01, "hide", 0.4, (1, 0, 0.3))   # ears
        Pt.chain(F, [V(sx * 0.03, H[1] + 0.06, hz + 0.0), V(sx * 0.06, H[1] + 0.13, hz + 0.04), V(sx * 0.08, H[1] + 0.2, hz + 0.12), V(sx * 0.085, H[1] + 0.25, hz + 0.22)], [0.017, 0.014, 0.01, 0.003], [0.012, 0.004, 0.004], "bone")   # swept horns
        # carve the sockets, light them
        F.sub(Q.Ell((sx * 0.037, H[1] + 0.03, hz - 0.075), (0.014, 0.012, 0.012)), 0.008)
        F.add(Q.Ell((sx * 0.036, H[1] + 0.03, hz - 0.074), (0.009, 0.008, 0.007)), 0.0, "eye")
        for k in range(7):                           # upper teeth, canine at the front
            z = hz - 0.05 - 0.016 * k
            L = 0.034 if k != 5 else 0.05
            Pt.tooth(F, V(sx * (0.027 - 0.0012 * k), H[1] - 0.012, z), (0, -1, 0.1), L, 0.0055)
        for k in range(6):                           # lower teeth bite up between them
            z = hz - 0.06 - 0.018 * k
            Pt.tooth(F, V(sx * (0.021 - 0.001 * k), H[1] - 0.08, z), (0, 1, 0.05), 0.03 if k != 4 else 0.042, 0.005)
    # tail: a whip
    Pt.chain(F, Pt.arc(V(0, 0.585, 0.46), V(0, 0.42, 1.18), V(0, 0.2, 0.0), 8), [0.04, 0.032, 0.026, 0.02, 0.016, 0.012, 0.009, 0.007, 0.005], 0.03)
    # spine of bone spurs grown out of the vertebrae
    for k in range(10):
        z = -0.36 + 0.075 * k
        L = 0.075 * (1.0 - 0.04 * k)
        Pt.claw(F, V(0, top(z) - 0.012, z), (0, 1, 0.55), L, 0.014 - 0.0005 * k, (0, 0, 1), 0.018, "bone", 3)
    # legs
    for sx in (-1, 1):
        t = "fl" if sx < 0 else "fr"
        t2 = "bl" if sx < 0 else "br"
        hp, kn, ft = S["leg_%s_hip" % t], S["leg_%s_knee" % t], S["leg_%s_foot" % t]
        # scapula: a blade lying over the ribs, the shoulder muscle, humerus, elbow, forearm, wrist, paw
        F.add(Q.RoundCone(V(sx * 0.115, 0.7, -0.33), V(sx * 0.19, 0.5, -0.41), 0.04, 0.06, 0.5, (1, 0, 0)), 0.05, "hide")
        F.add(Q.Ell((sx * 0.175, 0.5, -0.385), (0.04, 0.09, 0.08)), 0.07, "hide")                          # shoulder muscle
        F.add(Q.RoundCone(hp + V(0, 0.01, 0.0), kn + V(0, 0.02, 0.0), 0.07, 0.04, 0.68, (1, 0, 0)), 0.04, "hide")
        F.add(Q.Ell(kn + V(0, 0.0, 0.035), (0.026, 0.03, 0.03)), 0.02, "hide")                              # point of the elbow
        wr = V(sx * 0.2, 0.095, -0.385)
        Pt.chain(F, [kn, kn + (wr - kn) * 0.45 + V(0, 0, -0.004), wr], [0.038, 0.028, 0.02], 0.03, "hide", 0.85)
        F.add(Q.Ell(wr + V(0, 0, 0.012), (0.022, 0.026, 0.024)), 0.015, "hide")                            # carpus
        Pt.chain(F, [wr, V(sx * 0.2, 0.05, -0.395)], [0.02, 0.019], 0.015)
        pz = ft[2] - 0.02
        F.add(Q.Ell((sx * 0.2, 0.026, pz), (0.034, 0.026, 0.05)), 0.02, "hide")
        for k in range(4):
            tx = sx * 0.2 + (k - 1.5) * 0.0175
            e = 1.5 - abs(k - 1.5)
            Pt.chain(F, [V(tx, 0.022, pz - 0.03), V(tx, 0.016, pz - 0.07 - 0.008 * e)], [0.0105, 0.0085], 0.01)
            Pt.claw(F, V(tx, 0.014, pz - 0.072 - 0.008 * e), (0, -0.2, -1), 0.04, 0.0072, (0, -1, 0), 0.004, "claw", 3)
        # hind: haunch, thigh, stifle, gaskin, hock with the Achilles cord, cannon, paw
        hp2, kn2, ft2 = S["leg_%s_hip" % t2], S["leg_%s_knee" % t2], S["leg_%s_foot" % t2]
        F.add(Q.RoundCone(V(sx * 0.15, 0.62, 0.34), kn2 + V(0, 0.0, 0.015), 0.078, 0.046, 0.45, (1, 0, 0)), 0.05, "hide")
        F.add(Q.Ell((sx * 0.14, 0.58, 0.35), (0.034, 0.07, 0.078)), 0.07, "hide")                              # gluteal mass
        F.add(Q.RoundCone(V(sx * 0.17, 0.5, 0.42), V(sx * 0.2, 0.3, 0.38), 0.05, 0.03, 0.6, (1, 0, 0)), 0.04, "hide")   # hamstring
        F.add(Q.Ell(kn2 + V(0, 0.0, -0.035), (0.024, 0.032, 0.02)), 0.015, "hide")                          # kneecap
        hk = V(sx * 0.2, 0.155, 0.475)
        Pt.chain(F, [kn2, kn2 + (hk - kn2) * 0.5 + V(0, 0.01, 0.0), hk], [0.048, 0.036, 0.022], 0.03, "hide", 0.8)
        Pt.chain(F, [V(sx * 0.2, 0.33, 0.4), V(sx * 0.2, 0.2, 0.488), hk + V(0, 0.0, 0.015)], [0.014, 0.012, 0.012], 0.012)   # Achilles cord
        F.add(Q.Ell(hk + V(0, 0.0, 0.012), (0.022, 0.03, 0.026)), 0.012, "hide")                            # point of the hock
        Pt.chain(F, [hk, V(sx * 0.2, 0.085, 0.43), V(sx * 0.2, 0.05, ft2[2] - 0.005)], [0.024, 0.0185, 0.019], 0.015)
        pz2 = ft2[2] - 0.02
        F.add(Q.Ell((sx * 0.2, 0.026, pz2), (0.034, 0.026, 0.05)), 0.02, "hide")
        for k in range(4):
            tx = sx * 0.2 + (k - 1.5) * 0.0175
            e = 1.5 - abs(k - 1.5)
            Pt.chain(F, [V(tx, 0.022, pz2 - 0.03), V(tx, 0.016, pz2 - 0.07 - 0.008 * e)], [0.0105, 0.0085], 0.01)
            Pt.claw(F, V(tx, 0.014, pz2 - 0.072 - 0.008 * e), (0, -0.2, -1), 0.04, 0.0072, (0, -1, 0), 0.004, "claw", 3)
    return F


def detail(ctx):
    sc = ctx.sc
    P = ctx.P
    both = (-1, 1)
    # every rib under the hide, a hollow flank, the points of the hip, the shoulder blade's spine
    for k in range(9):
        z = -0.43 + 0.058 * k
        for sx in both:
            sc.ridge((sx * 0.04, 0.72 - 0.004 * k, z), (sx * 0.15, 0.42 + 0.02 * k, z + 0.035), 0.0085, 0.0085 - 0.0004 * k, facing=(sx, 0.1, 0))
    for sx in both:
        sc.bump((sx * 0.1, 0.55, 0.12), 0.07, -0.014, facing=(sx, 0, 0))                           # hollow flank
        sc.bump((sx * 0.12, 0.68, 0.3), 0.03, 0.014, facing=(sx, 1, 0))                             # point of the hip
        sc.ridge((sx * 0.13, 0.69, -0.33), (sx * 0.19, 0.55, -0.4), 0.012, 0.01, facing=(sx, 0.4, 0))   # spine of the scapula
        sc.bump((sx * 0.2, 0.15, 0.488), 0.02, 0.008, facing=(0, 0, 1))
        for z0 in (-0.394, 0.411):                       # tendons down the cannon bones, knuckles of the toes
            sc.ridge((sx * 0.2, 0.1, z0 - 0.01), (sx * 0.2, 0.04, z0 - 0.015), 0.006, 0.005, facing=(0, 0, -1))
    for k in range(16):                                    # knuckled spine
        z = -0.44 + 0.058 * k
        sc.bump((0, top(z) - 0.002, z), 0.014, 0.007, facing=(0, 1, 0))
    # skull: cheek hollows, nostril, lip line
    for sx in both:
        sc.bump((sx * 0.05, H[1] - 0.012, H[2] - 0.05), 0.024, -0.012, facing=(sx, 0, -0.3))
        sc.ridge((sx * 0.026, H[1] - 0.006, H[2] - 0.1), (sx * 0.022, H[1] - 0.012, H[2] - 0.17), 0.006, -0.007, facing=(sx, 0, -0.2))
    sc.bump((0, H[1] - 0.002, H[2] - 0.215), 0.014, 0.007, facing=(0, 0, -1))
    sc.noise(34.0, 0.0022)
    sc.noise(90.0, 0.0008, seed=4)
    sc.folds(60.0, 0.0006)
    SKIN = GK.mangy_hide("Skin")
    BONE = GK.grave_bone("Bone", (0.5, 0.42, 0.3), (0.16, 0.12, 0.08), 9.0)
    CLAW = GK.chitin("Claw", (0.045, 0.036, 0.032), (0.32, 0.25, 0.18), 14.0, 0.42)
    EYE = GK.glow("Eye", (1.0, 0.45, 0.08), 8.0)
    tags = ["hide", "bone", "tooth", "claw", "eye"]
    idx = ctx.region(tags, {"bone": 0.003, "tooth": 0.004, "claw": 0.003, "eye": 0.004})
    idx = np.array([0, 1, 1, 2, 3])[idx]
    return [SKIN, BONE, CLAW, EYE], idx.astype(np.int32)


if __name__ == "__main__":
    R.run(__import__(__name__))
