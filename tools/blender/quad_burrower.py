"""Burrower (r38d, pass 2): hard armour. A digger built of stone-chitin: overlapping body plates with thickness, a
bevelled crisp lip on each and an undercut under it (pangolin, isopod), pitted and chipped, soil packed into the
seams and amber light only deep in them; a head shield; limbs as ringed segments with a spiked knee plate and a
digging hand whose claws grow from jointed fingers; a face with a split snout, sensory pits and feelers,
hooked mandibles and nothing like eyes.   Rig: QuadRig, spider layout (core/enemy/burrower.gd, 0.36 high, scaled 1.18)."""
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
VOXEL, SUB, TRIS, SIZE, BAND = 0.0042, 1, 11000, 2048, 0.05
PREVIEW = ((0, 0.35, 0.0), 2.8)
EXTRUDE, RAY = 0.02, 0.07
S = R.rig_sockets(0.36, 1.05, 0.22, 0.24, False)       # burrower.gd: body_height 0.48 -> 0.36 (the legs stood on pins)
B, FR, H, T = S["body"], S["front"], S["head"], S["tail"]
PITCH = 0.1
Z0 = -0.44                                              # the seams fall at Z0 + k * PITCH
WK = ([-0.45, -0.3, -0.1, 0.15, 0.3, 0.44], [0.2, 0.29, 0.33, 0.33, 0.29, 0.19])


def sockets():
    return S


def segments(S):
    return R.rig_bones(S, 0.3, 0.25) + [("front", V(0, 0.52, -0.5), V(0, 0.52, -0.3), 0.03)]


def ringed(F, a, b, r0, r1, n, tag="skin", flat=1.0, nrm=(0, 0, 1), k=0.003):
    """A limb of n armour rings: a short rounded cone each, creased where they meet."""
    a, b = V(*a), V(*b)
    for i in range(n):
        t0, t1 = i / n, (i + 1) / n
        p0, p1 = a + (b - a) * (t0 + 0.04 / n), a + (b - a) * (t1 - 0.04 / n)
        ra, rb = r0 + (r1 - r0) * t0, r0 + (r1 - r0) * t1
        F.add(Q.RoundCone(p0, p1, ra * (0.92 if i else 1.0), rb * 1.04, flat, nrm), k, tag)


def field():
    F = Q.Field()
    # the soft belly under the plates
    F.add(Q.Loft([(-0.34, 0, 0.31, 0.08, 0.07, 0.08), (-0.2, 0, 0.31, 0.2, 0.1, 0.15), (0.0, 0, 0.3, 0.23, 0.11, 0.15), (0.25, 0, 0.3, 0.23, 0.11, 0.15),
                  (0.42, 0, 0.3, 0.17, 0.09, 0.12), (0.5, 0, 0.3, 0.07, 0.06, 0.06), (0.54, 0, 0.3, 0.03, 0.03, 0.03)]), 0.03, "skin")
    # body plates: lenses laid like roof tiles, each overlapping the next, crisp where they meet
    for i in range(8):
        z = Z0 + PITCH * (i + 0.5) + 0.0
        w = float(np.interp(z, *WK))
        hh = 0.12 + 0.07 * math.sin(math.pi * (i + 0.5) / 8.0)
        F.add(Q.Box((0, 0.44 + 0.5 * (hh - 0.12), z + 0.01), (w * 0.97, hh, 0.08), 0.085, (0.1, 0, 0)), 0.002, "shell")
    # the head shield, a hood over the skull
    F.add(Q.Ell((0, 0.49, -0.5), (0.27, 0.095, 0.13), (-0.22, 0, 0)), 0.004, "shell")
    F.add(Q.Ell((0, 0.5, -0.56), (0.2, 0.07, 0.1), (-0.3, 0, 0)), 0.004, "shell")
    hz = H[2]
    # head: a wedge of skull, a split snout, hooked mandibles, feelers, sensory pits
    F.add(Q.Ell((0, 0.4, hz + 0.02), (0.1, 0.065, 0.11)), 0.03, "skin")
    Pt.chain(F, [V(0, 0.4, hz - 0.03), V(0, 0.385, hz - 0.13), V(0, 0.37, hz - 0.2)], [0.07, 0.058, 0.05], 0.03, "skin", 0.8, (0, 1, 0))
    F.sub(Q.Box((0, 0.375, hz - 0.2), (0.006, 0.05, 0.07), 0.003), 0.004)                                   # the snout splits
    for sx in (-1, 1):
        Pt.chain(F, [V(sx * 0.045, 0.34, hz - 0.1), V(sx * 0.085, 0.32, hz - 0.2), V(sx * 0.03, 0.31, hz - 0.3)], [0.026, 0.022, 0.008], 0.008, "claw")   # mandibles
        Pt.chain(F, [V(sx * 0.03, 0.43, hz - 0.16), V(sx * 0.05, 0.46, hz - 0.26), V(sx * 0.08, 0.45, hz - 0.34)], [0.009, 0.007, 0.004], 0.006, "claw")    # feelers
        for k in range(4):
            F.sub(Q.Ell((sx * (0.035 + 0.004 * k), 0.415 - 0.006 * k, hz - 0.1 - 0.025 * k), (0.008, 0.008, 0.008)), 0.003)      # sensory pits
    # tail: three stacked plates
    for i in range(3):
        F.add(Q.Ell((0, 0.39 - 0.01 * i, 0.5 + 0.075 * i), (0.14 - 0.035 * i, 0.07 - 0.012 * i, 0.06)), 0.003, "shell")
    # shoulder / hip pauldrons: plates over each leg root
    for t in ("fl", "fr", "bl", "br"):
        sx = -1 if t.endswith("l") else 1
        front = t.startswith("f")
        hp, kn, ft = S["leg_%s_hip" % t], S["leg_%s_knee" % t], S["leg_%s_foot" % t]
        F.add(Q.Box(hp + V(sx * 0.1, 0.12, 0), (0.1, 0.03, 0.1 if front else 0.085), 0.02, (0, 0, sx * 0.45)), 0.003, "shell")
        ringed(F, hp, kn, 0.085 if front else 0.07, 0.07 if front else 0.06, 3, "skin")                    # femur rings
        F.add(Q.Ell(kn + V(0, 0.01, 0), (0.09, 0.045, 0.085) if front else (0.072, 0.04, 0.07)), 0.004, "shell")      # the knee plate
        Pt.claw(F, kn + V(sx * 0.02, 0.03, 0), (sx * 0.35, 1, 0), 0.11 if front else 0.08, 0.022 if front else 0.017, (0, 0.2, 0.1), 0.012, "claw", 3)
        if front:
            ringed(F, kn, ft + V(0, 0.06, -0.02), 0.07, 0.056, 5, "skin", 0.7, (0, 0, 1))                    # forearm rings
            palm = ft + V(0, 0.035, -0.05)
            F.add(Q.Box(palm, (0.07, 0.028, 0.06), 0.014), 0.004, "skin")
            for k in range(4):                                                                              # fingers: two jointed segments, a knuckle, a claw grown from the tip
                a = (k - 1.5) * 0.3
                base = palm + V(sx * 0.0 + (k - 1.5) * 0.034, 0.0, -0.05)
                d = Pt.unit(V(sx * 0.1 + math.sin(a), -0.12, -math.cos(a)))
                j1 = base + d * 0.06
                F.add(Q.Ell(base, (0.018, 0.016, 0.018)), 0.003, "shell")
                Pt.chain(F, [base, j1], [0.019, 0.017], 0.003, "skin")
                F.add(Q.Ell(j1, (0.016, 0.014, 0.016)), 0.003, "shell")
                Pt.chain(F, [j1, j1 + d * 0.07 + V(0, -0.015, 0), j1 + d * 0.17 + V(0, -0.04, 0)], [0.025, 0.022, 0.006], 0.004, "claw", 0.4, (0, 1, 0))
        else:
            ringed(F, kn, ft + V(0, 0.05, 0), 0.058, 0.05, 4, "skin", 0.7, (0, 0, 1))
            palm = ft + V(0, 0.028, -0.03)
            F.add(Q.Box(palm, (0.055, 0.024, 0.05), 0.012), 0.004, "skin")
            for k in range(3):
                x0 = (k - 1) * 0.035
                Pt.claw(F, palm + V(x0, 0, -0.05), (x0 * 3, -0.15, -1), 0.09, 0.017, (0, -1, -0.2), 0.006, "claw", 3)
    return F


def carapace_mat():
    m = K.Mat("Shell")
    cell = m.voronoi(11.0, 'F1')
    grain = m.noise(90.0, 4.0, 0.55)
    mott = m.noise(5.0, 5.0, 0.6)
    col = m.ramp(mott, [(0.3, (0.05, 0.045, 0.04)), (0.75, (0.16, 0.14, 0.115))])
    geo = m.n('ShaderNodeNewGeometry')
    ridge = m.math('SUBTRACT', geo.outputs['Pointiness'], 0.5)
    ridge = m.math('MULTIPLY', m.math('MAXIMUM', m.math('SUBTRACT', ridge, 0.03), 0.0), 5.0, True)
    col = m.mix(ridge, col, (0.4, 0.36, 0.3))                                   # worn pale on every crisp edge
    vc = m.n('ShaderNodeVertexColor')
    vc.layer_name = "seam"
    sep = m.n('ShaderNodeSeparateColor')
    m.links.new(vc.outputs['Color'], sep.inputs['Color'])
    soil, amber = sep.outputs['Red'], sep.outputs['Green']
    soil_n = m.math('MULTIPLY', soil, m.math('ADD', 0.5, m.noise(30.0, 4.0, 0.5)), True)
    col = m.mix(m.math('MULTIPLY', soil_n, 0.95), col, (0.11, 0.075, 0.045))   # soil packed in the seams
    gate = m.ramp(m.noise(7.0, 3.0, 0.5), [(0.4, (0, 0, 0)), (0.55, (1, 1, 1))])
    heat = m.math('MULTIPLY', amber, m.mono(gate))
    emc = m.mix(heat, (0.0, 0.0, 0.0), (1.0, 0.5, 0.12))
    pit = m.math('MULTIPLY', m.math('LESS_THAN', m.voronoi(70.0, 'F1'), 0.12), 0.8)
    col = m.mix(pit, col, (0.025, 0.022, 0.02))
    h = m.math('ADD', m.math('MULTIPLY', cell, 0.5), m.math('MULTIPLY', grain, 0.35))
    h = m.math('ADD', h, m.math('MULTIPLY', pit, -0.8))
    return m.finish(col, m.math('SUBTRACT', 0.72, m.math('MULTIPLY', ridge, 0.25)), 0.0, h, 0.6, 0.003, emit=emc, emit_strength=2.2)


def detail(ctx):
    sc = ctx.sc
    P, N = ctx.P, ctx.N
    tags = ["skin", "shell", "claw"]
    idx = ctx.region(tags, {"shell": 0.003, "claw": 0.003})
    shell = (idx == 1).astype(np.float32)
    u = ((P[:, 2] - Z0) / PITCH) % 1.0
    e = np.minimum(u, 1.0 - u)
    # plate relief: a bevelled lip and a groove under it, then chips and pits cut into the face
    ss = lambda lo, hi, v: (lambda t: t * t * (3 - 2 * t))(np.clip((v - lo) / (hi - lo), 0.0, 1.0))
    face = np.clip(N[:, 1] * 1.4 + 0.8, 0.0, 1.0) * shell
    sc.d += (0.018 * ss(0.0, 0.16, e) * face).astype(np.float32)
    sc.d -= (0.006 * ss(0.0, 0.2, 0.2 - e) * face).astype(np.float32)           # the undercut at the seam
    chips = np.clip(1.0 - 4.0 * np.abs(__import__("quad_sdf").fbm(P, 38.0, 3, 5) - 0.5) * 2.0, 0, 1) * ss(0.1, 0.4, 0.4 - e)
    sc.d -= (0.006 * chips * shell).astype(np.float32)
    sc.noise(95.0, 0.0012, mask=shell, seed=2)
    sc.folds(40.0, 0.0015, mask=1.0 - shell)
    seam = np.exp(-(e / 0.06) ** 2) * shell
    amber = np.exp(-(e / 0.018) ** 2) * shell * np.clip(N[:, 1] + 0.3, 0, 1)
    a4 = np.zeros((len(P), 4), dtype=np.float32)
    a4[:, 0], a4[:, 1] = seam, amber
    ctx.attrs["seam"] = a4
    SHELL = carapace_mat()
    SKIN = GK.ember_chitin("Skin", (0.075, 0.06, 0.045), (0.28, 0.22, 0.16), plates=10.0, rough=0.72, strength=1.4)
    CLAW = GK.chitin("Claw", (0.045, 0.036, 0.032), (0.32, 0.25, 0.18), 14.0, 0.42)
    return [SKIN, SHELL, CLAW], idx.astype(np.int32)


if __name__ == "__main__":
    R.run(__import__(__name__))
