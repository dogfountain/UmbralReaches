"""Leaper (r38d, pass 3): a predator built to leap, made of planes. A deep narrow chest on a long arched loin and a
much heavier pelvis; hind legs folded like a spring (a flat-sided thigh with a hard edge at the hamstring, the
stifle forward, a gaskin back to a hock held high on a bony point, a long pastern, splayed toes with long
claws); a flat scapula blade, a foreleg that is a bone ridge with the muscle to one side; ribs as form (the cage
pushes out, the skin sinks between and behind them, hip bones and spine stand proud); a low head on a thick neck,
a long wolfish skull with the skin stretched over it, deep sockets, lips pulled back off dark gums and bared teeth,
horns swept back along the skull; a heavy spined lash of a tail tapering from the full width of the rump.
Near-black hide, scarred pale patches, raw bone at the spurs.   Rig: QuadRig upright (core/enemy/leaper.gd)."""
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
VOXEL, SUB, TRIS, SIZE, BAND = 0.0042, 1, 13000, 2048, 0.04
PREVIEW = ((0, 0.42, 0.15), 2.9)
EXTRUDE, RAY = 0.05, 0.14
S = R.rig_sockets(0.56, 1.15, 0.2, 0.32, True)
B, FR, H, T = S["body"], S["front"], S["head"], S["tail"]
# deep narrow chest, a long arched loin, a heavy pelvis
KEYS = [(-0.54, 0.0, 0.6, 0.05, 0.05, 0.05), (-0.48, 0.0, 0.6, 0.085, 0.1, 0.14), (-0.38, 0.0, 0.585, 0.125, 0.14, 0.27),
        (-0.25, 0.0, 0.57, 0.135, 0.14, 0.29), (-0.1, 0.0, 0.59, 0.115, 0.12, 0.2), (0.05, 0.0, 0.64, 0.09, 0.095, 0.11),
        (0.18, 0.0, 0.66, 0.095, 0.1, 0.11), (0.3, 0.0, 0.64, 0.14, 0.13, 0.14), (0.42, 0.0, 0.62, 0.13, 0.12, 0.13),
        (0.52, 0.0, 0.6, 0.085, 0.085, 0.085)]
TRUNK = Q.Loft(KEYS)


def top(z):
    return float(np.interp(z, TRUNK.zs, TRUNK.tab[:, 1] + TRUNK.tab[:, 3]))


def sockets():
    return S


def segments(S):
    segs = R.rig_bones(S, 0.55, 0.2)
    segs += [("body", V(0.1, 0.7, -0.33), V(0.2, 0.52, -0.40), 0.03), ("body", V(-0.1, 0.7, -0.33), V(-0.2, 0.52, -0.40), 0.03),
             ("body", V(0.0, 0.72, -0.3), V(0.0, 0.7, 0.45), 0.03)]
    # the slabs of the upper legs take their leg's bone, not the body's
    for sx in (-1, 1):
        t = "fl" if sx < 0 else "fr"
        t2 = "bl" if sx < 0 else "br"
        segs += [("leg_%s_hip" % t, V(sx * 0.1, 0.62, -0.4), S["leg_%s_knee" % t], 0.05),
                 ("leg_%s_hip" % t2, V(sx * 0.1, 0.66, 0.35), V(sx * 0.2, 0.36, 0.3), 0.05),
                 ("leg_%s_hip" % t2, V(sx * 0.09, 0.64, 0.45), V(sx * 0.2, 0.36, 0.4), 0.05),
                 ("leg_%s_knee" % t2, V(sx * 0.2, 0.36, 0.33), V(sx * 0.2, 0.25, 0.5), 0.04),
                 ("leg_%s_knee" % t, S["leg_%s_knee" % t], V(sx * 0.2, 0.1, -0.385), 0.04)]
    return segs


def plank(F, a, b, hw, hd, rd, tag="hide", k=0.006, tilt=0.0):
    """A flat-sided bar from a to b: width 2*hw across the limb (x), depth 2*hd, hard edges (corner radius rd)."""
    a, b = V(*a), V(*b)
    d = b - a
    L = float(np.linalg.norm(d))
    if d[1] < 0:
        d = -d
    th = math.asin(max(-1.0, min(1.0, float(d[2]) / L)))
    cth = max(math.cos(th), 1e-3)
    ph = -math.asin(max(-1.0, min(1.0, float(d[0]) / (L * cth))))
    F.add(Q.Box((a + b) * 0.5, (hw, L * 0.5, hd), min(rd, hw * 0.9, hd * 0.9), (th, 0.0, ph + tilt)), k, tag)


def toes(F, sx, pz, n_claw=0.07):
    """Splayed toes with a knuckle each and a long claw."""
    for k in range(4):
        a = (k - 1.5) * 0.42
        base = V(sx * 0.2 + (k - 1.5) * 0.012, 0.02, pz - 0.03)
        d = Pt.unit(V(math.sin(a) * 0.9, -0.08, -math.cos(a)))
        F.add(Q.Ell(base, (0.011, 0.012, 0.012)), 0.004, "hide")
        Pt.chain(F, [base, base + d * 0.05], [0.0105, 0.0085], 0.005)
        Pt.claw(F, base + d * 0.05, d + V(0, -0.1, 0), n_claw * (1.15 if k in (1, 2) else 0.9), 0.0075, (0, -1, 0), 0.004, "claw", 3)


def field():
    F = Q.Field()
    F.add(TRUNK, 0.04, "hide")
    hz = H[2]
    # the ribs as form: a cage pushing out of the deep chest, the skin sinking between the arches
    for k in range(9):
        z = -0.44 + 0.056 * k
        a = float(np.interp(z, TRUNK.zs, TRUNK.tab[:, 2]))
        up = float(np.interp(z, TRUNK.zs, TRUNK.tab[:, 3]))
        dn = float(np.interp(z, TRUNK.zs, TRUNK.tab[:, 4]))
        cy = float(np.interp(z, TRUNK.zs, TRUNK.tab[:, 1]))
        for sx in (-1, 1):
            pts = []
            for th in np.linspace(1.2, -1.15, 12):
                pts.append(V(sx * (a + 0.004) * math.cos(th), cy + (up if th > 0 else dn) * math.sin(th) * 1.02, z + 0.014 * (1.3 - th)))
            Pt.chain(F, pts, [0.016 - 0.0006 * k] * 12, 0.003, "hide")
    # a heavy pelvis: the hip bones and the pin bones stand proud
    F.add(Q.Box((0, 0.64, 0.36), (0.15, 0.09, 0.12), 0.04, (0.12, 0, 0)), 0.02, "hide")
    for sx in (-1, 1):
        F.add(Q.Box((sx * 0.115, 0.72, 0.29), (0.02, 0.018, 0.05), 0.012, (0.3, 0, sx * 0.4)), 0.004, "hide")          # the hip bone
        F.add(Q.Box((sx * 0.07, 0.66, 0.46), (0.014, 0.014, 0.035), 0.01, (-0.2, 0, 0)), 0.004, "hide")               # the pin bone
    # neck: thick and low-slung; the head hangs below the withers
    Pt.chain(F, [V(0, 0.66, -0.4), V(0, 0.65, -0.52), V(0, 0.64, hz + 0.0)], [0.115, 0.095, 0.075], 0.03, "hide", 0.8, (0, 1, 0))
    # skull: a long wolfish wedge, skin tight over it
    F.add(Q.Box((0, H[1] + 0.02, hz + 0.0), (0.05, 0.05, 0.075), 0.03), 0.012, "hide")                               # cranium
    F.add(Q.Box((0, H[1] + 0.005, hz - 0.1), (0.036, 0.034, 0.085), 0.014, (-0.06, 0, 0)), 0.008, "hide")           # the muzzle, a long plane
    F.add(Q.Box((0, H[1] - 0.006, hz - 0.19), (0.027, 0.026, 0.05), 0.012, (-0.05, 0, 0)), 0.006, "hide")
    F.add(Q.Box((0, H[1] + 0.055, hz - 0.05), (0.012, 0.012, 0.08), 0.008), 0.006, "hide")                           # the sagittal crest, a ridge
    for sx in (-1, 1):
        F.add(Q.Box((sx * 0.052, H[1] + 0.012, hz - 0.03), (0.01, 0.026, 0.045), 0.006, (0.0, 0.0, sx * 0.15)), 0.004, "hide")   # the zygomatic plate
        F.add(Q.Box((sx * 0.034, H[1] + 0.052, hz - 0.06), (0.03, 0.01, 0.03), 0.007, (0.25, 0, 0)), 0.005, "hide")        # brow shelf
        F.sub(Q.Ell((sx * 0.036, H[1] + 0.033, hz - 0.068), (0.017, 0.016, 0.017)), 0.006)                                  # a deep socket
        F.add(Q.Ell((sx * 0.034, H[1] + 0.033, hz - 0.066), (0.008, 0.008, 0.007)), 0.0, "eye")
        # lips pulled back off dark gums, teeth set in them
        Pt.chain(F, [V(sx * 0.03, H[1] - 0.004, hz - 0.03), V(sx * 0.028, H[1] - 0.008, hz - 0.12), V(sx * 0.02, H[1] - 0.012, hz - 0.205)], [0.012, 0.012, 0.011], 0.004, "gum")
        Pt.chain(F, [V(sx * 0.026, H[1] - 0.074, hz - 0.04), V(sx * 0.02, H[1] - 0.074, hz - 0.16)], [0.011, 0.01], 0.004, "gum")
        Pt.chain(F, [V(sx * 0.032, H[1] - 0.03, hz + 0.02), V(sx * 0.026, H[1] - 0.072, hz - 0.06), V(sx * 0.016, H[1] - 0.078, hz - 0.18)], [0.017, 0.013, 0.011], [0.01, 0.004], "bone")   # the lower jaw, hanging open, raw
        for k in range(7):
            z = hz - 0.04 - 0.02 * k
            Pt.tooth(F, V(sx * (0.03 - 0.0012 * k), H[1] - 0.012, z), (0, -1, 0.1), 0.05 if k in (5,) else 0.034, 0.0068)
        for k in range(6):
            z = hz - 0.06 - 0.02 * k
            Pt.tooth(F, V(sx * (0.021 - 0.001 * k), H[1] - 0.07, z), (0, 1, 0.05), 0.048 if k == 4 else 0.032, 0.0058)
        # horns swept back along the skull
        Pt.chain(F, [V(sx * 0.03, H[1] + 0.06, hz - 0.01), V(sx * 0.05, H[1] + 0.085, hz + 0.1), V(sx * 0.066, H[1] + 0.09, hz + 0.22), V(sx * 0.07, H[1] + 0.07, hz + 0.34)],
                 [0.019, 0.015, 0.01, 0.003], [0.012, 0.004, 0.004], "bone")
        Pt.chain(F, [V(sx * 0.034, H[1] + 0.05, hz + 0.05), V(sx * 0.052, H[1] + 0.085, hz + 0.1)], [0.016, 0.004], 0.008, "hide", 0.4, (1, 0, 0))   # a torn ear, laid back
    # the lash: heavy, spined, tapering from the full width of the rump
    tl = Pt.arc(V(0, 0.6, 0.46), V(0, 0.4, 1.3), V(0, 0.22, 0.0), 10)
    Pt.chain(F, tl, [0.092, 0.08, 0.068, 0.058, 0.05, 0.042, 0.034, 0.027, 0.02, 0.014, 0.009], 0.02, "hide")
    for i in range(1, 10):
        p = tl[i]
        L = 0.07 - 0.004 * i
        Pt.claw(F, p + V(0, 0.04 - 0.003 * i, 0), (0, 1, 0.9), L, 0.015 - 0.001 * i, (0, 0.1, 1), 0.012, "bone", 3)
        for sx in (-1, 1):
            Pt.claw(F, p + V(sx * (0.035 - 0.003 * i), 0, 0), (sx * 1.0, 0.3, 0.8), L * 0.7, 0.011 - 0.0008 * i, (0, 0, 1), 0.01, "bone", 3)
    Pt.claw(F, tl[-1], (0, 0.1, 1), 0.12, 0.012, (0, -0.4, 0.6), 0.008, "bone", 4)                                    # a bone blade at the tip
    # the spine: a ridge of vertebrae standing proud, spurs grown out of it
    for k in range(18):
        z = -0.44 + 0.052 * k
        F.add(Q.Box((0, top(z) + 0.002, z), (0.01, 0.012, 0.016), 0.006), 0.006, "hide")
    for k in range(9):
        z = -0.36 + 0.085 * k
        Pt.claw(F, V(0, top(z), z), (0, 1, 0.6), 0.07 * (1.0 - 0.04 * k), 0.013, (0, 0, 1), 0.012, "bone", 3)
    for sx in (-1, 1):
        t = "fl" if sx < 0 else "fr"
        t2 = "bl" if sx < 0 else "br"
        hp, kn, ft = S["leg_%s_hip" % t], S["leg_%s_knee" % t], S["leg_%s_foot" % t]
        # fore: a flat scapula blade, the humerus a plank, the elbow a point, the foreleg a bone ridge with the muscle to one side
        F.add(Q.Box(V(sx * 0.12, 0.64, -0.36), (0.016, 0.1, 0.07), 0.015, (-0.4, 0, sx * 0.3)), 0.022, "hide")
        F.add(Q.RoundCone(V(sx * 0.11, 0.63, -0.4), kn + V(0, -0.02, 0), 0.055, 0.03, 0.5, (1, 0, 0)), 0.02, "hide")
        F.add(Q.Box(kn + V(0, 0.0, 0.035), (0.016, 0.02, 0.026), 0.01, (0.3, 0, 0)), 0.005, "hide")                     # the elbow point
        wr = V(sx * 0.2, 0.1, -0.385)
        plank(F, kn + V(0, 0.03, 0.0), wr + V(0, 0.03, 0), 0.018, 0.026, 0.01, "hide", 0.006)                         # the bone ridge
        plank(F, kn + V(sx * 0.022, 0.02, 0.012), wr + V(sx * 0.016, 0.06, 0.014), 0.016, 0.02, 0.008, "hide", 0.006)  # the muscle beside it
        F.add(Q.Box(wr, (0.018, 0.016, 0.022), 0.008), 0.005, "hide")                                                  # carpus
        plank(F, wr, V(sx * 0.2, 0.04, -0.395), 0.008, 0.013, 0.005, "hide", 0.004)
        pz = ft[2] - 0.02
        F.add(Q.Box((sx * 0.2, 0.022, pz), (0.026, 0.014, 0.036), 0.01), 0.006, "hide")
        toes(F, sx, pz)
        F.add(Q.Ell(kn, (0.026, 0.032, 0.03)), 0.014, "hide")                                                       # the elbow
        F.add(Q.Ell(wr, (0.02, 0.024, 0.022)), 0.01, "hide")                                                        # the wrist
        # hind: the pelvis's slab of thigh, flat-sided, a hard hamstring edge behind it, the stifle forward, a gaskin back to a high bony hock
        hp2, kn2, ft2 = S["leg_%s_hip" % t2], S["leg_%s_knee" % t2], S["leg_%s_foot" % t2]
        F.add(Q.RoundCone(V(sx * 0.11, 0.66, 0.35), V(sx * 0.2, 0.37, 0.3), 0.09, 0.036, 0.42, (1, 0, 0)), 0.025, "hide")                    # the thigh: a flat-sided wedge
        plank(F, V(sx * 0.09, 0.64, 0.45), V(sx * 0.2, 0.36, 0.4), 0.03, 0.034, 0.02, "hide", 0.015)                    # the hamstring, its own hard edge
        F.add(Q.Box(V(sx * 0.2, 0.34, 0.268), (0.014, 0.024, 0.016), 0.008), 0.005, "hide")                              # the knee, forward
        hk = V(sx * 0.2, 0.25, 0.5)
        plank(F, V(sx * 0.2, 0.36, 0.33), hk + V(0, 0.01, 0), 0.027, 0.038, 0.012, "hide", 0.014)                          # the gaskin
        F.add(Q.Box(hk + V(0, 0.03, 0.022), (0.014, 0.034, 0.014), 0.007, (0.4, 0, 0)), 0.004, "hide")                   # the calcaneus: the hock's bony point
        plank(F, V(sx * 0.2, 0.4, 0.4), hk + V(0, 0.06, 0.03), 0.007, 0.011, 0.004, "hide", 0.004)                      # the Achilles cord
        plank(F, hk, V(sx * 0.2, 0.05, ft2[2] - 0.0), 0.019, 0.022, 0.008, "hide", 0.01)                                # the long pastern
        F.add(Q.Box(V(sx * 0.2, 0.052, ft2[2] - 0.0), (0.02, 0.016, 0.02), 0.008), 0.005, "hide")
        pz2 = ft2[2] - 0.02
        F.add(Q.Box((sx * 0.2, 0.022, pz2), (0.026, 0.014, 0.036), 0.01), 0.006, "hide")
        toes(F, sx, pz2)
        F.add(Q.Ell(V(sx * 0.2, 0.34, 0.3), (0.028, 0.032, 0.034)), 0.014, "hide")                                    # the stifle
        F.add(Q.Ell(hk, (0.022, 0.028, 0.028)), 0.012, "hide")                                                        # the hock
        F.add(Q.Ell(V(sx * 0.2, 0.06, ft2[2]), (0.02, 0.02, 0.02)), 0.01, "hide")                                    # the pastern
    return F


def detail(ctx):
    sc = ctx.sc
    P = ctx.P
    both = (-1, 1)
    # the flank sinks behind the last rib and between them; the loin is a hollow beside the spine
    for sx in both:
        sc.bump((sx * 0.085, 0.6, 0.06), 0.09, -0.02, facing=(sx, 0, 0))
        sc.bump((sx * 0.1, 0.52, -0.1), 0.06, -0.012, facing=(sx, -0.2, 0))
        sc.bump((sx * 0.1, 0.62, 0.2), 0.05, -0.012, facing=(sx, 0.3, 0))
        sc.ridge((sx * 0.2, 0.36, 0.33), (sx * 0.2, 0.3, 0.45), 0.006, -0.008, facing=(sx, 0, 0.3))
    # hard folds where the skin gathers: neck, elbows, stifles, the flank
    crease = ctx.near((0, 0.65, -0.5), 0.13)
    for c in ((-0.2, 0.285, -0.354), (0.2, 0.285, -0.354), (-0.2, 0.34, 0.3), (0.2, 0.34, 0.3), (-0.1, 0.6, 0.1), (0.1, 0.6, 0.1)):
        crease = crease + ctx.near(c, 0.09)
    sc.folds(48.0, 0.005, mask=np.clip(crease, 0, 1))
    hy, hz = H[1], H[2]
    for k in range(4):                                     # wrinkles pulled across the muzzle by the snarl
        for sx in both:
            sc.ridge((sx * 0.004, hy + 0.01, hz - 0.1 - 0.02 * k), (sx * 0.03, hy + 0.004, hz - 0.095 - 0.02 * k), 0.004, 0.007, facing=(0, 1, 0))
    sc.noise(36.0, 0.0018)
    sc.noise(95.0, 0.0007, seed=4)
    sc.folds(62.0, 0.0006)
    SKIN = GK.mangy_hide("Skin", (0.022, 0.018, 0.015), (0.1, 0.085, 0.065), (0.04, 0.03, 0.026))
    BONE = GK.grave_bone("Bone", (0.55, 0.47, 0.34), (0.22, 0.15, 0.1), 9.0)
    CLAW = GK.chitin("Claw", (0.04, 0.032, 0.028), (0.3, 0.23, 0.17), 14.0, 0.42)
    EYE = GK.glow("Eye", (1.0, 0.45, 0.08), 8.0)
    GUM = K.Mat("Gum")
    GUM.finish((0.03, 0.012, 0.014), 0.3, 0.0)
    tags = ["hide", "bone", "tooth", "claw", "eye", "gum"]
    idx = ctx.region(tags, {"bone": 0.003, "tooth": 0.004, "claw": 0.003, "eye": 0.004, "gum": 0.002})
    idx = np.array([0, 1, 1, 2, 3, 4])[idx]
    return [SKIN, BONE, CLAW, EYE, GUM], idx.astype(np.int32)


if __name__ == "__main__":
    R.run(__import__(__name__))
