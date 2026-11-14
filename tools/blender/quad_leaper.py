"""Leaper (r38d): a starved hunting hound of the gloom. One sculpted skin: every rib standing up under a hollow flank,
a tucked waist, hip bones and the edge of the scapula showing through, a vertebra ridge that is part of the back,
a lean thigh with the stifle held forward and a thin gaskin down to the hock and its cord, triceps and tendons,
toes with knuckles and hooked claws, a skull with a heavy brow, a cheek, a snarl (wet dark gum, teeth set in it),
raw bone at the lower jaw, horns and the spurs; near-black hide with pale mange and scars.
Rig: QuadRig upright (core/enemy/leaper.gd)."""
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
KEYS = [(-0.52, 0.0, 0.585, 0.055, 0.055, 0.055), (-0.46, 0.0, 0.58, 0.095, 0.105, 0.13), (-0.36, 0.0, 0.565, 0.135, 0.145, 0.24),
        (-0.24, 0.0, 0.555, 0.145, 0.145, 0.26), (-0.1, 0.0, 0.565, 0.125, 0.12, 0.2), (0.02, 0.0, 0.58, 0.088, 0.095, 0.09),
        (0.12, 0.0, 0.585, 0.075, 0.085, 0.065), (0.26, 0.0, 0.585, 0.11, 0.105, 0.09), (0.4, 0.0, 0.585, 0.088, 0.088, 0.075),
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
    Pt.chain(F, [V(0, 0.60, -0.42), V(0, 0.655, -0.53), V(0, 0.665, -0.62), V(0, 0.655, H[2] + 0.02)], [0.095, 0.07, 0.058, 0.052], 0.05)
    hz = H[2]
    F.add(Q.Ell((0, H[1] + 0.03, hz + 0.0), (0.054, 0.056, 0.074)), 0.035, "hide")                          # cranium
    F.add(Q.RoundCone((0, H[1] + 0.012, hz - 0.045), (0, H[1] - 0.005, hz - 0.145), 0.042, 0.028, 0.8, (0, 1, 0)), 0.03, "hide")
    F.add(Q.Ell((0, H[1] - 0.002, hz - 0.165), (0.028, 0.022, 0.03)), 0.015, "hide")
    F.add(Q.Ell((0, H[1] + 0.05, hz - 0.075), (0.016, 0.014, 0.05)), 0.02, "hide")                          # the nasal ridge
    for sx in (-1, 1):
        F.add(Q.Ell((sx * 0.05, H[1] - 0.002, hz - 0.02), (0.012, 0.026, 0.05)), 0.02, "hide")             # cheekbone
        F.add(Q.Ell((sx * 0.036, H[1] + 0.056, hz - 0.058), (0.026, 0.017, 0.04), (0.25, 0, 0)), 0.01, "hide")    # a heavy brow
        Pt.chain(F, [V(sx * 0.034, H[1] - 0.04, hz + 0.01), V(sx * 0.03, H[1] - 0.07, hz - 0.08), V(sx * 0.016, H[1] - 0.074, hz - 0.15)], [0.017, 0.013, 0.011], [0.012, 0.004], "bone")   # raw lower jaw
        # the snarl: the lip drawn back off the gum, wet and dark, the teeth set in it
        Pt.chain(F, [V(sx * 0.026, H[1] - 0.006, hz - 0.045), V(sx * 0.025, H[1] - 0.01, hz - 0.11), V(sx * 0.02, H[1] - 0.012, hz - 0.17)], [0.011, 0.01, 0.009], 0.004, "gum")
        Pt.chain(F, [V(sx * 0.024, H[1] - 0.07, hz - 0.05), V(sx * 0.02, H[1] - 0.07, hz - 0.14)], [0.008, 0.007], 0.004, "gum")
        Pt.chain(F, [V(sx * 0.03, H[1] + 0.07, hz + 0.0), V(sx * 0.06, H[1] + 0.13, hz + 0.04), V(sx * 0.08, H[1] + 0.2, hz + 0.12), V(sx * 0.085, H[1] + 0.25, hz + 0.22)], [0.017, 0.014, 0.01, 0.003], [0.012, 0.004, 0.004], "bone")   # horns
        Pt.chain(F, [V(sx * 0.03, H[1] + 0.07, hz + 0.045), V(sx * 0.045, H[1] + 0.12, hz + 0.065), V(sx * 0.052, H[1] + 0.165, hz + 0.08)], [0.022, 0.017, 0.006], 0.01, "hide", 0.4, (1, 0, 0.3))   # ears
        F.sub(Q.Ell((sx * 0.037, H[1] + 0.03, hz - 0.075), (0.014, 0.012, 0.012)), 0.008)
        F.add(Q.Ell((sx * 0.036, H[1] + 0.03, hz - 0.074), (0.009, 0.008, 0.007)), 0.0, "eye")
        for k in range(7):
            z = hz - 0.05 - 0.016 * k
            L = 0.034 if k != 5 else 0.056
            Pt.tooth(F, V(sx * (0.027 - 0.0012 * k), H[1] - 0.014, z), (0, -1, 0.1), L, 0.0058)
        for k in range(6):
            z = hz - 0.06 - 0.018 * k
            Pt.tooth(F, V(sx * (0.021 - 0.001 * k), H[1] - 0.078, z), (0, 1, 0.05), 0.03 if k != 4 else 0.044, 0.005)
    F.add(Q.Ell((0, H[1] - 0.045, hz - 0.1), (0.012, 0.007, 0.05)), 0.006, "gum")                           # the wet tongue
    Pt.chain(F, Pt.arc(V(0, 0.585, 0.46), V(0, 0.42, 1.18), V(0, 0.2, 0.0), 8), [0.04, 0.032, 0.026, 0.02, 0.016, 0.012, 0.009, 0.007, 0.005], 0.03)
    # the vertebra ridge is part of the back; the spurs grow out of it
    F.add(Q.RoundCone(V(0, top(-0.4) - 0.012, -0.4), V(0, top(0.42) - 0.012, 0.42), 0.014, 0.01), 0.02, "hide")
    for k in range(10):
        z = -0.36 + 0.075 * k
        L = 0.075 * (1.0 - 0.04 * k)
        Pt.claw(F, V(0, top(z) - 0.012, z), (0, 1, 0.55), L, 0.014 - 0.0005 * k, (0, 0, 1), 0.02, "bone", 3)
    for sx in (-1, 1):
        t = "fl" if sx < 0 else "fr"
        t2 = "bl" if sx < 0 else "br"
        hp, kn, ft = S["leg_%s_hip" % t], S["leg_%s_knee" % t], S["leg_%s_foot" % t]
        # fore: a blade of scapula, a lean shoulder, humerus, the triceps hanging off the elbow, a thin forearm
        F.add(Q.RoundCone(V(sx * 0.115, 0.7, -0.33), V(sx * 0.19, 0.5, -0.41), 0.034, 0.05, 0.4, (1, 0, 0)), 0.035, "hide")
        F.add(Q.RoundCone(hp + V(0, 0.01, 0.0), kn + V(0, 0.02, 0.0), 0.06, 0.038, 0.62, (1, 0, 0)), 0.03, "hide")
        F.add(Q.RoundCone(V(sx * 0.2, 0.5, -0.4), kn + V(0, 0.03, 0.04), 0.036, 0.026, 0.55, (1, 0, 0)), 0.025, "hide")   # triceps
        F.add(Q.Ell(kn + V(0, 0.0, 0.04), (0.022, 0.03, 0.028)), 0.012, "hide")                              # point of the elbow
        wr = V(sx * 0.2, 0.095, -0.385)
        Pt.chain(F, [kn, kn + (wr - kn) * 0.45 + V(0, 0, -0.004), wr], [0.036, 0.026, 0.017], 0.02, "hide", 0.85)
        F.add(Q.Ell(wr + V(0, 0, 0.012), (0.02, 0.024, 0.022)), 0.01, "hide")                              # carpus
        Pt.chain(F, [wr, V(sx * 0.2, 0.05, -0.395)], [0.016, 0.016], 0.012)
        pz = ft[2] - 0.02
        F.add(Q.Ell((sx * 0.2, 0.026, pz), (0.032, 0.025, 0.046)), 0.015, "hide")
        for k in range(4):
            tx = sx * 0.2 + (k - 1.5) * 0.0175
            e = 1.5 - abs(k - 1.5)
            F.add(Q.Ell((tx, 0.02, pz - 0.034), (0.0098, 0.011, 0.011)), 0.006, "hide")                  # the knuckle
            Pt.chain(F, [V(tx, 0.02, pz - 0.04), V(tx, 0.015, pz - 0.075 - 0.008 * e)], [0.0095, 0.008], 0.006)
            Pt.claw(F, V(tx, 0.013, pz - 0.076 - 0.008 * e), (0, -0.2, -1), 0.04, 0.0072, (0, -1, 0), 0.004, "claw", 3)
        # hind: a lean thigh to a stifle held forward, the hamstring behind, a thin gaskin to the hock, its cord
        hp2, kn2, ft2 = S["leg_%s_hip" % t2], S["leg_%s_knee" % t2], S["leg_%s_foot" % t2]
        F.add(Q.RoundCone(V(sx * 0.16, 0.63, 0.35), V(sx * 0.2, 0.37, 0.31), 0.082, 0.036, 0.6, (1, 0, 0)), 0.035, "hide")
        F.add(Q.RoundCone(V(sx * 0.165, 0.58, 0.41), V(sx * 0.2, 0.3, 0.385), 0.044, 0.024, 0.5, (1, 0, 0)), 0.03, "hide")      # hamstring
        F.add(Q.Ell(kn2 + V(0, 0.0, -0.036), (0.02, 0.028, 0.018)), 0.01, "hide")                              # kneecap, forward
        hk = V(sx * 0.2, 0.155, 0.475)
        Pt.chain(F, [kn2, kn2 + (hk - kn2) * 0.5 + V(0, 0.01, 0.0), hk], [0.04, 0.03, 0.02], 0.025, "hide", 0.85)
        Pt.chain(F, [V(sx * 0.2, 0.33, 0.4), V(sx * 0.2, 0.2, 0.488), hk + V(0, 0.0, 0.015)], [0.012, 0.011, 0.011], 0.01)
        F.add(Q.Ell(hk + V(0, 0.0, 0.012), (0.02, 0.028, 0.024)), 0.01, "hide")                              # point of the hock
        Pt.chain(F, [hk, V(sx * 0.2, 0.085, 0.43), V(sx * 0.2, 0.05, ft2[2] - 0.005)], [0.02, 0.016, 0.017], 0.012)
        pz2 = ft2[2] - 0.02
        F.add(Q.Ell((sx * 0.2, 0.026, pz2), (0.032, 0.025, 0.046)), 0.015, "hide")
        for k in range(4):
            tx = sx * 0.2 + (k - 1.5) * 0.0175
            e = 1.5 - abs(k - 1.5)
            F.add(Q.Ell((tx, 0.02, pz2 - 0.034), (0.0098, 0.011, 0.011)), 0.006, "hide")
            Pt.chain(F, [V(tx, 0.02, pz2 - 0.04), V(tx, 0.015, pz2 - 0.075 - 0.008 * e)], [0.0095, 0.008], 0.006)
            Pt.claw(F, V(tx, 0.013, pz2 - 0.076 - 0.008 * e), (0, -0.2, -1), 0.04, 0.0072, (0, -1, 0), 0.004, "claw", 3)
    return F


def detail(ctx):
    sc = ctx.sc
    both = (-1, 1)
    # a starved body: every rib stands up under a hollow flank, the hip bones and the scapula's edge show through
    for k in range(10):
        z = -0.43 + 0.056 * k
        a = float(np.interp(z, TRUNK.zs, TRUNK.tab[:, 2]))
        up = float(np.interp(z, TRUNK.zs, TRUNK.tab[:, 3]))
        dn = float(np.interp(z, TRUNK.zs, TRUNK.tab[:, 4]))
        cy = float(np.interp(z, TRUNK.zs, TRUNK.tab[:, 1]))
        for sx in both:
            pts = []
            for th in np.linspace(1.35, -0.75, 16):         # round the ribcage, hugging the section, a little swept back
                pts.append((sx * a * math.cos(th), cy + (up if th > 0 else dn) * math.sin(th), z + 0.02 * (1.4 - th)))
            for p0, p1 in zip(pts[:-1], pts[1:]):
                sc.ridge(p0, p1, 0.009, 0.0085 - 0.0004 * k, facing=(sx, 0.2, 0))
    for sx in both:
        sc.bump((sx * 0.1, 0.55, 0.12), 0.08, -0.03, facing=(sx, 0, 0))
        sc.bump((sx * 0.1, 0.5, -0.05), 0.06, -0.012, facing=(sx, -0.2, 0))
        sc.bump((sx * 0.115, 0.68, 0.3), 0.03, 0.03, facing=(sx, 1, 0))
        sc.bump((sx * 0.07, 0.64, 0.42), 0.03, 0.018, facing=(sx, 0.5, 0.5))
        sc.ridge((sx * 0.13, 0.69, -0.33), (sx * 0.19, 0.55, -0.4), 0.01, 0.016, facing=(sx, 0.4, 0))
        sc.ridge((sx * 0.2, 0.5, -0.38), (sx * 0.2, 0.3, -0.34), 0.01, 0.007, facing=(sx, 0, 0.6))
        sc.ridge((sx * 0.2, 0.28, -0.4), (sx * 0.2, 0.12, -0.38), 0.005, 0.005, facing=(sx, 0, -0.5))
        sc.ridge((sx * 0.2, 0.28, 0.34), (sx * 0.2, 0.12, 0.42), 0.005, 0.005, facing=(sx, 0, 0.5))
        sc.ridge((sx * 0.2, 0.3, 0.325), (sx * 0.2, 0.15, 0.455), 0.006, 0.008, facing=(sx, 0, 0.3))
    for sx in both:                                        # the muscles read as separate masses: grooves between them, bone landmarks
        sc.ridge((sx * 0.2, 0.6, 0.31), (sx * 0.2, 0.33, 0.33), 0.008, -0.012, facing=(sx, 0, -0.3))
        sc.ridge((sx * 0.2, 0.58, 0.4), (sx * 0.2, 0.34, 0.37), 0.007, -0.01, facing=(sx, 0, 0.3))
        sc.ridge((sx * 0.2, 0.55, -0.43), (sx * 0.2, 0.34, -0.38), 0.008, -0.012, facing=(sx, 0, -0.3))
        sc.bump((sx * 0.2, 0.63, 0.36), 0.03, 0.014, facing=(sx, 0.6, 0))
        sc.bump((sx * 0.2, 0.62, -0.42), 0.03, 0.012, facing=(sx, 0.6, 0))
    for k in range(17):
        z = -0.44 + 0.055 * k
        sc.bump((0, top(z), z), 0.015, 0.013, facing=(0, 1, 0))
    hy, hz = H[1], H[2]
    for sx in both:
        sc.bump((sx * 0.052, hy - 0.012, hz - 0.045), 0.026, -0.016, facing=(sx, 0, -0.3))
        sc.ridge((sx * 0.03, hy + 0.06, hz - 0.075), (sx * 0.048, hy + 0.04, hz - 0.03), 0.01, 0.012, facing=(sx, 1, 0))
        sc.ridge((sx * 0.045, hy + 0.01, hz - 0.02), (sx * 0.05, hy - 0.01, hz - 0.075), 0.008, 0.01, facing=(sx, 0, 0))
    for k in range(4):                                     # the snarl: wrinkles over the muzzle
        sc.ridge((-0.03, hy + 0.012, hz - 0.08 - 0.02 * k), (0.03, hy + 0.012, hz - 0.08 - 0.02 * k), 0.005, 0.008, facing=(0, 1, 0))
    sc.bump((0, hy - 0.002, hz - 0.215), 0.014, 0.009, facing=(0, 0, -1))
    # sharper creases where the skin folds: the neck, the elbows, the flanks, the stifles
    crease = ctx.near((0, 0.62, -0.55), 0.13)
    for c in ((-0.2, 0.285, -0.354), (0.2, 0.285, -0.354), (-0.2, 0.285, 0.31), (0.2, 0.285, 0.31)):
        crease = crease + ctx.near(c, 0.08)
    for c in ((-0.12, 0.5, 0.1), (0.12, 0.5, 0.1)):
        crease = crease + ctx.near(c, 0.12)
    sc.folds(46.0, 0.006, mask=np.clip(crease, 0, 1))
    sc.noise(34.0, 0.0022)
    sc.noise(90.0, 0.0008, seed=4)
    sc.folds(60.0, 0.0006)
    SKIN = GK.mangy_hide("Skin", (0.03, 0.024, 0.02), (0.2, 0.17, 0.13), (0.05, 0.035, 0.03))
    BONE = GK.grave_bone("Bone", (0.55, 0.47, 0.34), (0.2, 0.14, 0.09), 9.0)
    CLAW = GK.chitin("Claw", (0.045, 0.036, 0.032), (0.32, 0.25, 0.18), 14.0, 0.42)
    EYE = GK.glow("Eye", (1.0, 0.45, 0.08), 8.0)
    GUM = K.Mat("Gum")
    GUM.finish((0.07, 0.008, 0.012), 0.22, 0.0)
    tags = ["hide", "bone", "tooth", "claw", "eye", "gum"]
    idx = ctx.region(tags, {"bone": 0.003, "tooth": 0.004, "claw": 0.003, "eye": 0.004, "gum": 0.002})
    idx = np.array([0, 1, 1, 2, 3, 4])[idx]
    return [SKIN, BONE, CLAW, EYE, GUM], idx.astype(np.int32)


if __name__ == "__main__":
    R.run(__import__(__name__))
