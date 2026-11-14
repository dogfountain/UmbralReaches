"""Mite (r38d): a tick of the rift. One sculpted skin: a swollen translucent sac (cyan light moving in its cells)
held in a cage of pale chitin meridians that grow out of it, a small armoured head with four cyan eyes, hooked
chelicerae and a pair of palps, and eight jointed legs (the rig's four plus four more skinned to their
neighbours) with knuckled joints, bristles and a hooked tarsus.  Half-size in game (rig scale 0.5).
Rig: QuadRig, spider layout (core/enemy/mite.gd)."""
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

NAME = "Mite"
PREFIX = "grunt_mite"
VOXEL, SUB, TRIS, SIZE, BAND = 0.0035, 1, 5200, 1024, 0.04
PREVIEW = ((0, 0.28, 0.0), 2.0)
EXTRUDE, RAY = 0.02, 0.06
S = R.rig_sockets(0.34, 0.72, 0.14, 0.24, False)
B, FR, H, T = S["body"], S["front"], S["head"], S["tail"]
EXTRA = []


def sockets():
    return S


def segments(S):
    segs = R.rig_bones(S, 0.3, 0.2)
    segs += [("body", V(sx_ * 0.15, 0.4, 0.05), V(sx_ * 0.15, 0.4, 0.3), 0.05) for sx_ in (-1, 0, 1)] + [("body", V(0, 0.56, 0.05), V(0, 0.56, 0.3), 0.05)]
    for (t, sx, hp, kn, ft) in EXTRA:
        segs += [("leg_%s_hip" % t, hp, kn, 0.03), ("leg_%s_knee" % t, kn, ft, 0.03), ("leg_%s_foot" % t, ft, ft + V(0, -0.02, 0.0), 0.03)]
    return segs


def leg(F, sx, hip, kn, ft, sc):
    F.add(Q.Ell(hip + V(-sx * 0.01, 0, 0), (0.04 * sc,) * 3), 0.035, "chitin")
    mid = (hip + kn) * 0.5 + V(0, 0.04 * sc, 0)
    Pt.chain(F, [hip, mid, kn], [0.03 * sc, 0.025 * sc, 0.023 * sc], 0.02, "chitin")
    F.add(Q.Ell(kn, (0.036 * sc, 0.034 * sc, 0.034 * sc)), 0.014, "claw")
    d = ft - kn
    p1 = kn + d * 0.4 + V(sx * 0.06, 0, 0)
    p2 = kn + d * 0.75 + V(sx * 0.03, 0, 0)
    tip = ft + V(0, 0.01, 0)
    Pt.chain(F, [kn, p1, p2, tip], [0.024 * sc, 0.019 * sc, 0.0135 * sc, 0.008 * sc], 0.012, "chitin")
    F.add(Q.Ell(p1, (0.022 * sc,) * 3), 0.01, "claw")
    for t_ in (0.25, 0.5, 0.75):                                        # bristles
        p = kn + d * t_ + V(sx * 0.05 * (1 - abs(t_ - 0.4)), 0, 0)
        Pt.claw(F, p, (sx * 0.9, 0.5, 0.2), 0.05 * sc, 0.006, (0, 0.3, 0), 0.006, "claw", 2)
    Pt.claw(F, tip, (sx * 0.1, -0.9, -0.4), 0.065 * sc, 0.009 * sc, (0, -0.5, -0.9), 0.005, "claw", 3)


def field():
    F = Q.Field()
    # the sac: a big glowing globe riding on the back
    F.add(Q.Ell((0, 0.4, 0.15), (0.2, 0.2, 0.26)), 0.05, "sac")
    F.add(Q.Ell((0, 0.31, 0.12), (0.15, 0.1, 0.22)), 0.05, "chitin")                                  # a chitin cradle under it
    # chitin meridians over the sac
    for k in range(8):
        phi = -0.35 + (math.pi + 0.7) * k / 7.0
        pts = []
        for j in range(15):
            t = 0.08 + (math.pi - 0.16) * j / 14.0
            pts.append(V(math.cos(phi) * 0.21 * math.sin(t) * 1.04, 0.4 + math.sin(phi) * 0.205 * math.sin(t) * 1.04, 0.15 - 0.265 * math.cos(t) * 1.04))
        Pt.chain(F, pts, [0.0105] * 15, [0.01] * 14, "chitin")
    # thorax and head
    F.add(Q.Ell((0, 0.37, -0.2), (0.12, 0.085, 0.12)), 0.05, "chitin")
    F.add(Q.Ell((0, 0.4, -0.2), (0.1, 0.05, 0.09)), 0.03, "chitin")
    hz = H[2]
    F.add(Q.Ell((0, H[1] - 0.02, hz + 0.02), (0.07, 0.06, 0.07)), 0.04, "chitin")
    Pt.chain(F, [V(0, 0.38, -0.25), V(0, H[1] - 0.025, hz + 0.05)], [0.07, 0.06], 0.04, "chitin")        # the neck: head and thorax are one
    for sx in (-1, 1):
        for k in range(2):
            ex = sx * (0.024 + 0.02 * k)
            F.sub(Q.Ell((ex, H[1] + 0.012 + 0.008 * k, hz - 0.035 + 0.01 * k), (0.011, 0.009, 0.008)), 0.006)
            F.add(Q.Ell((ex, H[1] + 0.012 + 0.008 * k, hz - 0.032 + 0.01 * k), (0.0075, 0.0065, 0.006)), 0.0, "eye")
        Pt.claw(F, V(sx * 0.03, H[1] - 0.05, hz - 0.04), (-sx * 0.35, -0.3, -1), 0.1, 0.014, (-sx * 0.8, -0.5, -0.3), 0.01, "claw", 4)     # chelicerae
        Pt.chain(F, [V(sx * 0.05, H[1] - 0.04, hz - 0.02), V(sx * 0.065, H[1] - 0.06, hz - 0.1), V(sx * 0.05, H[1] - 0.09, hz - 0.14)], [0.011, 0.009, 0.006], 0.01, "chitin")   # palps
    for k in range(5):                                           # barbs along the thorax ridge
        Pt.claw(F, V(0, 0.45 - 0.002 * k, -0.28 + 0.05 * k), (0, 1, 0.5), 0.055, 0.011, (0, 0, 1), 0.012, "claw", 3)
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
    hy, hz = H[1], H[2]
    for sx in (-1, 1):
        sc.bump((sx * 0.034, hy + 0.0, hz - 0.045), 0.02, -0.008, facing=(sx * 0.4, 0, -1))
    sc.noise(40.0, 0.0016)
    sc.noise(100.0, 0.0006, seed=5)
    sc.folds(80.0, 0.0006)
    SHELL = GK.ember_chitin("Chitin", (0.2, 0.18, 0.21), (0.46, 0.42, 0.45), plates=18.0, rough=0.5, strength=2.0)
    SAC = GK.membrane("Sac", (0.25, 1.0, 0.8), 4.6, (0.3, 0.42, 0.4))
    CLAW = GK.chitin("Claw", (0.17, 0.15, 0.18), (0.5, 0.46, 0.5), 14.0, 0.44)
    EYE = GK.glow("Eye", (0.25, 1.0, 0.8), 8.0)
    tags = ["chitin", "sac", "claw", "eye"]
    idx = ctx.region(tags, {"sac": 0.0, "claw": 0.003, "eye": 0.004})
    return [SHELL, SAC, CLAW, EYE], idx.astype(np.int32)


if __name__ == "__main__":
    R.run(__import__(__name__))
