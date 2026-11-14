"""Burrower (r38d): a digging beast of the Southern Downs. One sculpted skin: a low, broad domed carapace of
overlapping armour bands (the lip of each band is cut into the surface, amber light leaks from the seams
under it), crusted with clods of earth that grow out of the plates; a blunt wedge of a head with a ridged
nose pad and no eyes, hooked mandibles; massive forelegs (a shoulder girdle, a heavy humerus, a bowed forearm
into a palm) ending in three flat spade claws; short stout hind legs with raking claws.
Rig: QuadRig, spider layout (core/enemy/burrower.gd, rig scaled 1.18)."""
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

NAME = "Burrower"
PREFIX = "grunt_burrower"
VOXEL, SUB, TRIS, SIZE, BAND = 0.0045, 1, 10800, 2048, 0.05
PREVIEW = ((0, 0.35, 0.0), 2.8)
EXTRUDE, RAY = 0.02, 0.07
S = R.rig_sockets(0.36, 1.05, 0.22, 0.24, False)       # burrower.gd: body_height 0.48 -> 0.36 (the legs stood on pins)
B, FR, H, T = S["body"], S["front"], S["head"], S["tail"]
KEYS = [(-0.53, 0, 0.47, 0.1, 0.09, 0.08), (-0.46, 0, 0.47, 0.2, 0.16, 0.14), (-0.3, 0, 0.47, 0.3, 0.215, 0.2), (-0.05, 0, 0.47, 0.35, 0.23, 0.23),
        (0.2, 0, 0.47, 0.34, 0.23, 0.23), (0.38, 0, 0.46, 0.28, 0.2, 0.19), (0.5, 0, 0.45, 0.15, 0.11, 0.1), (0.56, 0, 0.44, 0.03, 0.03, 0.03)]
PITCH = 0.105
Z0 = -0.52


def sockets():
    return S


def segments(S):
    return R.rig_bones(S, 0.3, 0.25) + [("front", V(0, 0.52, -0.5), V(0, 0.52, -0.3), 0.03)]


def elytron_top(x, z):
    """Height of the elytra's surface at (x, z) (the two ellipsoids of field())."""
    cx = 0.14 if x > 0 else -0.14
    q = 1.0 - ((x - cx) / 0.2) ** 2 - ((z - 0.08) / 0.4) ** 2
    return 0.45 + 0.15 * math.sqrt(max(q, 0.0))


def field():
    F = Q.Field()
    # the belly, two elytra with a seam between them, the pronotum shield over the neck
    F.add(Q.Loft([(-0.34, 0, 0.31, 0.09, 0.08, 0.09), (-0.2, 0, 0.31, 0.22, 0.11, 0.15), (0.0, 0, 0.3, 0.25, 0.12, 0.15), (0.25, 0, 0.3, 0.25, 0.12, 0.15),
                  (0.42, 0, 0.3, 0.19, 0.1, 0.12), (0.52, 0, 0.3, 0.09, 0.07, 0.07), (0.56, 0, 0.3, 0.03, 0.03, 0.03)]), 0.04, "skin")
    for sx in (-1, 1):
        F.add(Q.Ell((sx * 0.14, 0.45, 0.08), (0.2, 0.15, 0.4)), 0.012, "shell")
        F.add(Q.Ell((sx * 0.235, 0.37, 0.07), (0.1, 0.12, 0.33)), 0.02, "shell")                                # the elytra's flanks, a skirt over the legs
        F.add(Q.Ell((sx * 0.27, 0.45, -0.37), (0.085, 0.07, 0.15), (0, sx * 0.3, 0)), 0.03, "shell")            # pronotum flares
    F.add(Q.Loft([(-0.56, 0, 0.42, 0.06, 0.06, 0.07), (-0.5, 0, 0.44, 0.17, 0.09, 0.1), (-0.38, 0, 0.47, 0.27, 0.13, 0.13), (-0.24, 0, 0.47, 0.31, 0.14, 0.13),
                  (-0.13, 0, 0.45, 0.25, 0.11, 0.12), (-0.1, 0, 0.42, 0.13, 0.05, 0.05)]), 0.03, "shell")
    # head under the shield: blunt, eyeless, hooked mandibles
    hz = H[2]
    F.add(Q.Ell((0, H[1] - 0.04, hz + 0.01), (0.095, 0.072, 0.1)), 0.05, "skin")
    Pt.chain(F, [V(0, H[1] - 0.04, hz - 0.03), V(0, H[1] - 0.065, hz - 0.12), V(0, H[1] - 0.08, hz - 0.18)], [0.075, 0.056, 0.04], 0.04, "skin", 0.8, (0, 1, 0))
    for sx in (-1, 1):
        Pt.chain(F, [V(sx * 0.05, H[1] - 0.09, hz - 0.1), V(sx * 0.075, H[1] - 0.11, hz - 0.2), V(sx * 0.03, H[1] - 0.12, hz - 0.28)], [0.024, 0.02, 0.008], 0.012, "claw")      # mandibles
        F.sub(Q.Ell((sx * 0.06, H[1] - 0.03, hz - 0.075), (0.006, 0.006, 0.006)), 0.004)
    # legs: a sturdy femur, an armoured knee, a tibia that flares to the foot (a shovel on the forelegs), spines
    for t in ("fl", "fr", "bl", "br"):
        sx = -1 if t.endswith("l") else 1
        front = t.startswith("f")
        hp, kn, ft = S["leg_%s_hip" % t], S["leg_%s_knee" % t], S["leg_%s_foot" % t]
        Pt.chain(F, [hp, hp + (kn - hp) * 0.55, kn], [0.085, 0.078, 0.07] if front else [0.07, 0.065, 0.06], 0.05, "skin")        # femur
        F.add(Q.Ell(kn + V(0, 0.01, 0), (0.088, 0.05, 0.08) if front else (0.07, 0.045, 0.065)), 0.03, "shell")                # knee guard: a pauldron
        Pt.claw(F, kn + V(sx * 0.02, 0.03, 0), (sx * 0.35, 1, 0), 0.1 if front else 0.075, 0.022 if front else 0.017, (0, 0.2, 0.1), 0.02, "claw", 3)   # its spike
        if front:
            # the foreleg's tibia is a flat shovel blade, digging teeth down its leading edge
            Pt.chain(F, [kn, kn + (ft - kn) * 0.5 + V(sx * 0.02, 0, -0.01), ft + V(0, 0.06, -0.02)], [0.06, 0.075, 0.085], 0.04, "skin", 0.45, (0, 0, 1))
            for k in range(3):
                tt = 0.3 + 0.22 * k
                p = kn + (ft - kn) * tt + V(sx * 0.02, 0, -0.06)
                Pt.claw(F, p, (0, -0.35 - 0.15 * k, -1), 0.09 + 0.02 * k, 0.024, (0, -1, -0.3), 0.012, "claw", 3)
            F.add(Q.Ell(ft + V(0, 0.03, -0.04), (0.08, 0.035, 0.1)), 0.03, "skin")
            for k in range(3):
                a = (k - 1) * 0.55
                Pt.claw(F, ft + V(sx * (k - 1) * 0.03, 0.03, -0.12), (sx * 0.2 + math.sin(a) * 0.7, -0.12, -math.cos(a)), 0.17, 0.03, (0, -1, -0.1), 0.012, "claw", 4)
        else:
            Pt.chain(F, [kn, kn + (ft - kn) * 0.5, ft + V(0, 0.05, 0)], [0.05, 0.05, 0.055], 0.04, "skin", 0.6, (0, 0, 1))
            for k in range(2):
                tt = 0.35 + 0.25 * k
                p = kn + (ft - kn) * tt + V(sx * 0.03, 0, 0.0)
                Pt.claw(F, p, (sx * 0.8, -0.2, 0.3), 0.065, 0.014, (0, -0.8, 0.4), 0.01, "claw", 3)
            F.add(Q.Ell(ft + V(0, 0.028, -0.025), (0.06, 0.03, 0.075)), 0.025, "skin")
            for k in range(3):
                x0 = sx * (k - 1) * 0.035
                Pt.claw(F, ft + V(x0, 0.028, -0.085), (x0 * 3, -0.15, -1), 0.085, 0.017, (0, -1, -0.2), 0.008, "claw", 3)
    # clods of earth grown out of the shell: lumpy heaps, a few Ellipsoids deep
    rng = np.random.RandomState(11)
    for k in range(16):
        sx = 1 if k % 2 else -1
        z = rng.uniform(-0.1, 0.4)
        x = sx * rng.uniform(0.06, 0.25)
        for j in range(3):
            r = rng.uniform(0.024, 0.04)
            dx, dz = rng.uniform(-0.03, 0.03), rng.uniform(-0.03, 0.03)
            F.add(Q.Ell((x + dx, elytron_top(x + dx, z + dz) - r * 0.35, z + dz), (r * 1.2, r * 0.9, r * 1.1), (rng.uniform(-.4, .4), rng.uniform(-1, 1), rng.uniform(-.4, .4))), 0.02, "earth")
    for k in range(6):
        a = rng.uniform(-0.2, 0.2)
        z = rng.uniform(-0.45, -0.18)
        r = rng.uniform(0.026, 0.04)
        F.add(Q.Ell((a, 0.57, z), (r * 1.2, r * 0.8, r * 1.1)), 0.02, "earth")
    return F


def carapace_mat():
    m = K.Mat("Shell")
    cell = m.voronoi(11.0, 'F1')
    grain = m.noise(90.0, 4.0, 0.55)
    mott = m.noise(5.0, 5.0, 0.6)
    col = m.ramp(mott, [(0.3, (0.05, 0.036, 0.024)), (0.75, (0.12, 0.085, 0.055))])
    geo = m.n('ShaderNodeNewGeometry')
    ridge = m.math('SUBTRACT', geo.outputs['Pointiness'], 0.5)
    ridge = m.math('MULTIPLY', m.math('MAXIMUM', m.math('SUBTRACT', ridge, 0.03), 0.0), 5.0, True)
    col = m.mix(ridge, col, (0.34, 0.26, 0.18))
    vc = m.n('ShaderNodeVertexColor')
    vc.layer_name = "seam"
    seam = m.mono(vc.outputs['Color'])
    col = m.mix(m.math('MULTIPLY', seam, 0.92), col, (0.015, 0.008, 0.004))
    gate = m.ramp(m.noise(7.0, 3.0, 0.5), [(0.35, (0, 0, 0)), (0.55, (1, 1, 1))])
    heat = m.math('MULTIPLY', seam, m.mono(gate))
    emc = m.mix(heat, (0.0, 0.0, 0.0), (1.0, 0.5, 0.12))
    h = m.math('ADD', m.math('MULTIPLY', cell, 0.5), m.math('MULTIPLY', grain, 0.3))
    h = m.math('ADD', h, m.math('MULTIPLY', seam, -0.8))
    return m.finish(col, m.math('SUBTRACT', 0.7, m.math('MULTIPLY', ridge, 0.2)), 0.0, h, 0.5, 0.003, emit=emc, emit_strength=2.0)


def detail(ctx):
    sc = ctx.sc
    P, N = ctx.P, ctx.N
    tags = ["skin", "shell", "earth", "claw"]
    idx = ctx.region(tags, {"shell": 0.003, "earth": 0.004, "claw": 0.003})
    shell = (idx == 1) | (idx == 2)
    P, N = ctx.P, ctx.N
    # overlapping armour bands across the shell: a lip stepped into the surface every PITCH, the seam under it lit
    u = ((P[:, 2] - Z0) / PITCH) % 1.0
    face = np.clip(N[:, 1] * 1.6 + 0.9, 0.0, 1.0)
    lip = np.where(u < 0.8, u / 0.8, 1.0 - (u - 0.8) / 0.2)
    sc.d += (0.02 * lip * face * shell).astype(np.float32)
    band_seam = np.exp(-((u - 0.88) / 0.05) ** 2) * np.clip(N[:, 1] * 0.9 + 0.6, 0, 1)
    cleft = np.exp(-(P[:, 0] / 0.014) ** 2) * ((P[:, 2] > -0.14) & (P[:, 2] < 0.46)) * (P[:, 1] > 0.5)
    seam = np.maximum(band_seam * 0.8, cleft) * shell
    ctx.attrs["seam"] = np.clip(seam, 0, 1).astype(np.float32)
    sc.noise(30.0, 0.003)
    sc.noise(80.0, 0.001, seed=3)
    sc.folds(55.0, 0.001)
    SHELL = carapace_mat()
    SKIN = GK.ember_chitin("Skin", (0.12, 0.085, 0.055), (0.34, 0.26, 0.18), plates=12.0, rough=0.7, strength=1.8)
    EARTH = GK.earth("Earth")
    CLAW = GK.chitin("Claw", (0.045, 0.036, 0.032), (0.32, 0.25, 0.18), 14.0, 0.42)
    return [SKIN, SHELL, EARTH, CLAW], idx.astype(np.int32)


if __name__ == "__main__":
    R.run(__import__(__name__))
