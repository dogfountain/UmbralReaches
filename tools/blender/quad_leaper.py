"""Leaper (r38d, pass 4): a bone-plated hunting hound. A smooth continuous hide body (deep chest, tucked waist, heavy
hindquarters, hock held high, a heavy spined tail lash) that shows only in the gaps, at the belly, throat and joints,
under fused bone armour grown out of it where the hide reads soft: a plate over each shoulder blade, segmented
plates down each thigh ending in a spur at the stifle, greaves on the forearms, gaskins and cannons, overlapping
dorsal plates with the spurs rising from them, arched rib plates on the flanks with the hide sunk between; a bare
bone skull-mask over the muzzle with deep sockets, small ember eyes, exposed teeth, horns swept back flat.
Plates are chipped and have bevelled lips (quad_leaper.detail).   Rig: QuadRig upright (core/enemy/leaper.gd)."""
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
VOXEL, SUB, TRIS, SIZE, BAND = 0.0042, 1, 13000, 2048, 0.045
PREVIEW = ((0, 0.42, 0.15), 2.9)
EXTRUDE, RAY = 0.02, 0.07
S = R.rig_sockets(0.56, 1.15, 0.2, 0.32, True)
B, FR, H, T = S["body"], S["front"], S["head"], S["tail"]
KEYS = [(-0.54, 0.0, 0.6, 0.05, 0.05, 0.05), (-0.48, 0.0, 0.6, 0.085, 0.1, 0.14), (-0.38, 0.0, 0.585, 0.115, 0.14, 0.27),
        (-0.25, 0.0, 0.57, 0.125, 0.14, 0.29), (-0.1, 0.0, 0.59, 0.105, 0.115, 0.2), (0.05, 0.0, 0.63, 0.08, 0.09, 0.1),
        (0.18, 0.0, 0.65, 0.085, 0.095, 0.1), (0.3, 0.0, 0.64, 0.125, 0.12, 0.13), (0.42, 0.0, 0.62, 0.115, 0.11, 0.12),
        (0.52, 0.0, 0.6, 0.085, 0.085, 0.085)]
TRUNK = Q.Loft(KEYS)
PLATES = []          # (centre, half extents, rotation) of every armour plate, for the detail pass


def top(z):
    return float(np.interp(z, TRUNK.zs, TRUNK.tab[:, 1] + TRUNK.tab[:, 3]))


def sockets():
    return S


def segments(S):
    segs = R.rig_bones(S, 0.55, 0.2)
    segs += [("body", V(0.1, 0.7, -0.33), V(0.2, 0.52, -0.40), 0.03), ("body", V(-0.1, 0.7, -0.33), V(-0.2, 0.52, -0.40), 0.03),
             ("body", V(0.0, 0.72, -0.3), V(0.0, 0.7, 0.45), 0.03)]
    for sx in (-1, 1):
        t2 = "bl" if sx < 0 else "br"
        segs += [("leg_%s_hip" % t2, V(sx * 0.12, 0.64, 0.35), V(sx * 0.2, 0.34, 0.3), 0.05),
                 ("leg_%s_knee" % t2, V(sx * 0.2, 0.34, 0.3), V(sx * 0.2, 0.22, 0.49), 0.04)]
    return segs


def plate(F, c, h, rot=(0, 0, 0), rd=0.01, k=0.006, tag="plate"):
    """One armour plate: a thick bevelled slab, welded to the hide by a small blend."""
    F.add(Q.Box(c, h, min(rd, min(h) * 0.9), rot), k, tag)
    PLATES.append((np.asarray(c, dtype=np.float32), np.asarray(h, dtype=np.float32), rot))


def along(F, a, b, n, hw, hl, hd, off=0.0, tilt=0.0, k=0.006, rd=0.01, side=1.0):
    """n overlapping plates down the limb from a to b, standing off its surface by `off` (lateral)."""
    a, b = V(*a), V(*b)
    d = b - a
    L = float(np.linalg.norm(d))
    th = math.atan2(float(d[2]), float(d[1])) if d[1] >= 0 else math.atan2(-float(d[2]), -float(d[1]))
    for i in range(n):
        t = (i + 0.5) / n
        c = a + d * t + V(side * off, 0, 0)
        plate(F, c, (hw * (1.0 - 0.18 * t), hl * (L / n) * 0.62, hd), (th + tilt, 0, 0), rd, k)


def field():
    F = Q.Field()
    PLATES.clear()
    F.add(TRUNK, 0.05, "hide")
    hz = H[2]
    Pt.chain(F, [V(0, 0.66, -0.4), V(0, 0.65, -0.52), V(0, 0.64, hz + 0.0)], [0.115, 0.095, 0.075], 0.04, "hide", 0.85, (0, 1, 0))     # the throat stays hide
    # --- the skull mask: bare bone, wolf proportions, skin-tight, deep sockets ---
    F.add(Q.Box((0, H[1] + 0.02, hz), (0.05, 0.05, 0.075), 0.03), 0.012, "plate")
    F.add(Q.Box((0, H[1] + 0.005, hz - 0.1), (0.036, 0.034, 0.085), 0.014, (-0.06, 0, 0)), 0.008, "plate")
    F.add(Q.Box((0, H[1] - 0.006, hz - 0.19), (0.027, 0.026, 0.05), 0.012, (-0.05, 0, 0)), 0.006, "plate")
    F.add(Q.Box((0, H[1] + 0.055, hz - 0.05), (0.012, 0.012, 0.08), 0.008), 0.006, "plate")
    for sx in (-1, 1):
        F.add(Q.Box((sx * 0.052, H[1] + 0.012, hz - 0.03), (0.01, 0.026, 0.045), 0.006, (0, 0, sx * 0.15)), 0.004, "plate")
        F.add(Q.Box((sx * 0.034, H[1] + 0.052, hz - 0.06), (0.03, 0.01, 0.03), 0.007, (0.25, 0, 0)), 0.005, "plate")
        F.sub(Q.Ell((sx * 0.036, H[1] + 0.033, hz - 0.068), (0.017, 0.016, 0.017)), 0.006)
        F.add(Q.Ell((sx * 0.034, H[1] + 0.033, hz - 0.066), (0.0095, 0.0095, 0.0085)), 0.0, "eye")
        Pt.chain(F, [V(sx * 0.03, H[1] - 0.004, hz - 0.03), V(sx * 0.028, H[1] - 0.008, hz - 0.12), V(sx * 0.02, H[1] - 0.012, hz - 0.205)], [0.011, 0.011, 0.01], 0.004, "gum")
        Pt.chain(F, [V(sx * 0.026, H[1] - 0.074, hz - 0.04), V(sx * 0.02, H[1] - 0.074, hz - 0.16)], [0.01, 0.009], 0.004, "gum")
        Pt.chain(F, [V(sx * 0.032, H[1] - 0.03, hz + 0.02), V(sx * 0.026, H[1] - 0.072, hz - 0.06), V(sx * 0.016, H[1] - 0.078, hz - 0.18)], [0.017, 0.013, 0.011], [0.01, 0.004], "plate")
        for k in range(7):
            z = hz - 0.04 - 0.02 * k
            Pt.tooth(F, V(sx * (0.03 - 0.0012 * k), H[1] - 0.012, z), (0, -1, 0.1), 0.05 if k == 5 else 0.034, 0.0068)
        for k in range(6):
            z = hz - 0.06 - 0.02 * k
            Pt.tooth(F, V(sx * (0.021 - 0.001 * k), H[1] - 0.07, z), (0, 1, 0.05), 0.048 if k == 4 else 0.032, 0.0058)
        Pt.chain(F, [V(sx * 0.03, H[1] + 0.06, hz - 0.01), V(sx * 0.05, H[1] + 0.085, hz + 0.1), V(sx * 0.066, H[1] + 0.09, hz + 0.22), V(sx * 0.07, H[1] + 0.07, hz + 0.34)],
                 [0.019, 0.015, 0.01, 0.003], [0.012, 0.004, 0.004], "bone")                                       # horns swept back flat
    # --- the lash: heavy, spined, tapering from the full width of the rump ---
    tl = Pt.arc(V(0, 0.6, 0.46), V(0, 0.4, 1.3), V(0, 0.22, 0.0), 10)
    Pt.chain(F, tl, [0.092, 0.08, 0.068, 0.058, 0.05, 0.042, 0.034, 0.027, 0.02, 0.014, 0.009], 0.02, "hide")
    for i in range(1, 10):
        p = tl[i]
        L = 0.07 - 0.004 * i
        Pt.claw(F, p + V(0, 0.04 - 0.003 * i, 0), (0, 1, 0.9), L, 0.015 - 0.001 * i, (0, 0.1, 1), 0.012, "bone", 3)
        for sx in (-1, 1):
            Pt.claw(F, p + V(sx * (0.035 - 0.003 * i), 0, 0), (sx * 1.0, 0.3, 0.8), L * 0.7, 0.011 - 0.0008 * i, (0, 0, 1), 0.01, "bone", 3)
    Pt.claw(F, tl[-1], (0, 0.1, 1), 0.12, 0.012, (0, -0.4, 0.6), 0.008, "bone", 4)
    # --- dorsal plates, overlapping, the spurs rising from them ---
    for k in range(11):
        z = -0.4 + 0.082 * k
        plate(F, V(0, top(z) - 0.002, z), (0.045 - 0.0012 * k, 0.012, 0.05), (0.14, 0, 0), 0.01, 0.01)
    for k in range(9):
        z = -0.36 + 0.09 * k
        Pt.claw(F, V(0, top(z) + 0.008, z), (0, 1, 0.6), 0.075 * (1.0 - 0.04 * k), 0.014, (0, 0, 1), 0.012, "bone", 3)
    # --- rib plates: arched, overlapping, the hide sunk between them ---
    for k in range(9):
        z = -0.44 + 0.056 * k
        a = float(np.interp(z, TRUNK.zs, TRUNK.tab[:, 2]))
        up = float(np.interp(z, TRUNK.zs, TRUNK.tab[:, 3]))
        dn = float(np.interp(z, TRUNK.zs, TRUNK.tab[:, 4]))
        cy = float(np.interp(z, TRUNK.zs, TRUNK.tab[:, 1]))
        for sx in (-1, 1):
            pts = []
            for th in np.linspace(1.15, -1.1, 11):
                pts.append(V(sx * (a + 0.006) * math.cos(th), cy + (up if th > 0 else dn) * math.sin(th) * 1.03, z + 0.016 * (1.3 - th)))
            Pt.chain(F, pts, [0.021 - 0.0008 * k] * 11, 0.004, "plate", 0.55, (1, 0, 0))
    # --- the legs ---
    for sx in (-1, 1):
        t = "fl" if sx < 0 else "fr"
        t2 = "bl" if sx < 0 else "br"
        hp, kn, ft = S["leg_%s_hip" % t], S["leg_%s_knee" % t], S["leg_%s_foot" % t]
        # fore: hide limb under armour: a plate over the shoulder blade, greaves down the forearm
        F.add(Q.RoundCone(V(sx * 0.115, 0.7, -0.33), V(sx * 0.19, 0.5, -0.41), 0.034, 0.05, 0.4, (1, 0, 0)), 0.035, "hide")
        F.add(Q.RoundCone(hp + V(0, 0.01, 0.0), kn + V(0, 0.02, 0.0), 0.062, 0.04, 0.62, (1, 0, 0)), 0.03, "hide")
        F.add(Q.RoundCone(V(sx * 0.2, 0.5, -0.4), kn + V(0, 0.03, 0.04), 0.036, 0.026, 0.55, (1, 0, 0)), 0.025, "hide")
        F.add(Q.Ell(kn + V(0, 0.0, 0.04), (0.022, 0.03, 0.028)), 0.012, "hide")
        wr = V(sx * 0.2, 0.095, -0.385)
        Pt.chain(F, [kn, kn + (wr - kn) * 0.45, wr], [0.036, 0.026, 0.017], 0.02, "hide", 0.85)
        F.add(Q.Ell(wr + V(0, 0, 0.012), (0.02, 0.024, 0.022)), 0.01, "hide")
        Pt.chain(F, [wr, V(sx * 0.2, 0.05, -0.395)], [0.016, 0.016], 0.012)
        plate(F, V(sx * 0.14, 0.655, -0.36), (0.017, 0.105, 0.075), (-0.4, 0, sx * 0.3), 0.016, 0.02)          # the shoulder-blade plate
        along(F, kn + V(0, -0.02, 0), wr, 3, 0.026, 0.9, 0.024, off=sx * 0.006, side=1.0)                        # forearm greaves
        along(F, wr, V(sx * 0.2, 0.05, -0.395), 1, 0.016, 0.9, 0.016, off=sx * 0.004)
        Pt.claw(F, kn + V(sx * 0.014, 0.03, 0.045), (0, 0.6, 1), 0.05, 0.012, (0, -0.2, 0.5), 0.01, "bone", 3)      # an elbow spur
        pz = ft[2] - 0.02
        F.add(Q.Ell((sx * 0.2, 0.026, pz), (0.032, 0.025, 0.046)), 0.015, "hide")
        for k in range(4):
            tx = sx * 0.2 + (k - 1.5) * 0.0185
            e = 1.5 - abs(k - 1.5)
            F.add(Q.Ell((tx, 0.02, pz - 0.034), (0.0098, 0.011, 0.011)), 0.006, "hide")
            Pt.chain(F, [V(tx, 0.02, pz - 0.04), V(tx, 0.015, pz - 0.075 - 0.008 * e)], [0.0095, 0.008], 0.006)
            Pt.claw(F, V(tx, 0.013, pz - 0.076 - 0.008 * e), (0, -0.2, -1), 0.045, 0.0075, (0, -1, 0), 0.004, "claw", 3)
        # hind: a big hide thigh under a column of segmented plates ending in a spur at the stifle, the hock held high
        hp2, kn2, ft2 = S["leg_%s_hip" % t2], S["leg_%s_knee" % t2], S["leg_%s_foot" % t2]
        F.add(Q.RoundCone(V(sx * 0.15, 0.64, 0.35), V(sx * 0.2, 0.36, 0.3), 0.088, 0.036, 0.55, (1, 0, 0)), 0.045, "hide")
        F.add(Q.RoundCone(V(sx * 0.165, 0.6, 0.42), V(sx * 0.2, 0.32, 0.385), 0.048, 0.024, 0.5, (1, 0, 0)), 0.03, "hide")
        F.add(Q.Ell(kn2 + V(0, 0.0, -0.036), (0.02, 0.028, 0.018)), 0.01, "hide")
        hk = V(sx * 0.2, 0.24, 0.5)
        Pt.chain(F, [V(sx * 0.2, 0.34, 0.31), V(sx * 0.2, 0.29, 0.4), hk], [0.04, 0.03, 0.021], 0.025, "hide", 0.85)
        Pt.chain(F, [V(sx * 0.2, 0.36, 0.4), V(sx * 0.2, 0.27, 0.49), hk + V(0, 0.0, 0.015)], [0.012, 0.011, 0.011], 0.01)
        F.add(Q.Ell(hk + V(0, 0.0, 0.012), (0.021, 0.028, 0.026)), 0.01, "hide")
        Pt.chain(F, [hk, V(sx * 0.2, 0.085, 0.45), V(sx * 0.2, 0.05, ft2[2] - 0.005)], [0.02, 0.016, 0.017], 0.012)
        along(F, V(sx * 0.17, 0.64, 0.34), V(sx * 0.2, 0.37, 0.3), 5, 0.032, 0.72, 0.056, off=sx * 0.03, tilt=0.0)      # the thigh column
        Pt.claw(F, V(sx * 0.215, 0.345, 0.27), (sx * 0.2, -0.2, -1), 0.07, 0.017, (0, -0.4, -0.3), 0.012, "bone", 3)      # the stifle spur
        along(F, V(sx * 0.2, 0.34, 0.31), hk, 2, 0.024, 0.9, 0.03, off=sx * 0.012)                                       # gaskin greaves
        Pt.claw(F, hk + V(0, 0.03, 0.03), (0, 1, 0.9), 0.06, 0.014, (0, 0.2, 0.7), 0.01, "bone", 3)                         # the hock's bony spur
        along(F, hk, V(sx * 0.2, 0.05, ft2[2]), 2, 0.018, 0.85, 0.02, off=sx * 0.005)                                     # cannon greaves
        pz2 = ft2[2] - 0.02
        F.add(Q.Ell((sx * 0.2, 0.026, pz2), (0.032, 0.025, 0.046)), 0.015, "hide")
        for k in range(4):
            tx = sx * 0.2 + (k - 1.5) * 0.0185
            e = 1.5 - abs(k - 1.5)
            F.add(Q.Ell((tx, 0.02, pz2 - 0.034), (0.0098, 0.011, 0.011)), 0.006, "hide")
            Pt.chain(F, [V(tx, 0.02, pz2 - 0.04), V(tx, 0.015, pz2 - 0.075 - 0.008 * e)], [0.0095, 0.008], 0.006)
            Pt.claw(F, V(tx, 0.013, pz2 - 0.076 - 0.008 * e), (0, -0.2, -1), 0.045, 0.0075, (0, -1, 0), 0.004, "claw", 3)
    return F


def detail(ctx):
    sc = ctx.sc
    P, N = ctx.P, ctx.N
    ss = lambda lo, hi, v: (lambda t: t * t * (3 - 2 * t))(np.clip((v - lo) / (hi - lo), 0.0, 1.0))
    both = (-1, 1)
    tags = ["hide", "plate", "bone", "tooth", "claw", "eye", "gum"]
    idx7 = ctx.region(tags, {"plate": 0.004, "bone": 0.003, "tooth": 0.004, "claw": 0.003, "eye": 0.004, "gum": 0.002})
    plate_m = (idx7 == 1).astype(np.float32)
    hide_m = (idx7 == 0).astype(np.float32)
    # the hide sinks in the gaps: hollow flanks between the rib plates, grooves round every plate
    for sx in both:
        sc.bump((sx * 0.09, 0.6, 0.06), 0.09, -0.02, facing=(sx, 0, 0))
        sc.bump((sx * 0.1, 0.62, 0.2), 0.05, -0.012, facing=(sx, 0.3, 0))
    # plate relief: a lip bevelled up from the hide, chipped edges, pits
    near = np.zeros(len(P), dtype=np.float32)
    for c, h, rot in PLATES:
        d = np.sqrt((((P - c) / (h + 0.012)) ** 2).sum(1))
        near = np.maximum(near, 1.0 - np.clip(d, 0.0, 1.0))
    sc.d += (0.007 * ss(0.0, 0.5, near) * plate_m).astype(np.float32)
    ch = np.clip(1.0 - 3.5 * np.abs(__import__("quad_sdf").fbm(P, 46.0, 3, 9) - 0.5) * 2.0, 0, 1)
    sc.d -= (0.0022 * ch * ss(0.2, 0.7, 0.9 - near) * plate_m).astype(np.float32)
    sc.noise(95.0, 0.0006, mask=plate_m, seed=2)
    crease = ctx.near((0, 0.65, -0.5), 0.13)
    for c in ((-0.2, 0.285, -0.354), (0.2, 0.285, -0.354), (-0.2, 0.34, 0.3), (0.2, 0.34, 0.3)):
        crease = crease + ctx.near(c, 0.08)
    sc.folds(48.0, 0.005, mask=np.clip(crease, 0, 1) * hide_m)
    sc.noise(36.0, 0.0016, mask=hide_m)
    SKIN = GK.mangy_hide("Skin", (0.02, 0.016, 0.014), (0.09, 0.075, 0.06), (0.03, 0.025, 0.022))
    PL = GK.grave_bone("Plate", (0.66, 0.6, 0.47), (0.28, 0.2, 0.13), 8.0)
    BONE = GK.grave_bone("Bone", (0.6, 0.53, 0.4), (0.24, 0.17, 0.11), 9.0)
    CLAW = GK.chitin("Claw", (0.07, 0.058, 0.05), (0.34, 0.27, 0.2), 14.0, 0.42)
    EYE = GK.glow("Eye", (1.0, 0.45, 0.08), 12.0)
    GUM = K.Mat("Gum")
    GUM.finish((0.03, 0.012, 0.014), 0.3, 0.0)
    out = np.array([0, 1, 2, 2, 3, 4, 5])[idx7]          # hide, plate, bone, tooth(bone), claw, eye, gum
    return [SKIN, PL, BONE, CLAW, EYE, GUM], out.astype(np.int32)


if __name__ == "__main__":
    R.run(__import__(__name__))
