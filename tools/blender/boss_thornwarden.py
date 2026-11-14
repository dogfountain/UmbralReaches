"""The Thornwarden (r38d): the Thorn Henge's keeper, rebuilt as ONE continuous sculpted skin on the Leaper's QuadRig
(thornwarden.gd extends Leaper, upright hound legs). A stag-boar of bark and briar: a high humped shoulder
over a deep ribcage and a tucked waist, a neck that flows from the hump down into a long deer skull
(bone-white, embers in the sockets, jaw, teeth), a crown of branching antlers that grows out of the skull's crest,
bark shingles laid in rows that follow the ribs, the haunch and every limb, a spine of thorns and a mane of
briar canes grown from the vertebrae, thick-muscled legs with a point of elbow, a carpus, a hock, and cloven
hooves gripped by root tendrils, a thorned tail ending in a bramble knot, an ember heart split into the
breast. Skinned to the rig's bones (a bone per socket) with smooth weights; baked from a ~1M-polygon high.

  tools/blender/run.sh boss_thornwarden.py -- [--no-bake] [--preview /tmp/t.png] [--voxel 0.006] [--size 4096]
Writes art/models/boss_thornwarden.glb and art/textures/boss_thornwarden_{albedo,normal,orm,emit}.png
"""
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
import quad_bark as BK
from quad_parts import V

NAME = "Thornwarden"
PREFIX = "boss_thornwarden"
VOXEL, SUB, TRIS, SIZE, BAND = 0.0058, 1, 40000, 4096, 0.07
PREVIEW = ((0, 0.9, -0.1), 5.2)
EXTRUDE, RAY = 0.04, 0.1
WSMOOTH = 4
S = R.rig_sockets(0.56, 1.15, 0.2, 0.32, True)
B, FR, H, T = S["body"], S["front"], S["head"], S["tail"]
KEYS = [(-0.60, 0.0, 0.62, 0.07, 0.08, 0.08), (-0.52, 0.0, 0.64, 0.17, 0.16, 0.17), (-0.4, 0.0, 0.69, 0.26, 0.28, 0.23),
        (-0.22, 0.0, 0.7, 0.29, 0.3, 0.23), (-0.02, 0.0, 0.65, 0.26, 0.25, 0.21), (0.18, 0.0, 0.64, 0.24, 0.19, 0.19),
        (0.34, 0.0, 0.64, 0.25, 0.18, 0.19), (0.48, 0.0, 0.63, 0.19, 0.15, 0.15), (0.58, 0.0, 0.62, 0.09, 0.09, 0.09), (0.65, 0.0, 0.61, 0.03, 0.03, 0.03)]
TRUNK = Q.Loft(KEYS)
rng = np.random.RandomState(4417)


def top(z):
    return float(np.interp(z, TRUNK.zs, TRUNK.tab[:, 1] + TRUNK.tab[:, 3]))


def sockets():
    return S


def segments(S):
    segs = R.rig_bones(S, 0.6, 0.3)
    # the crown follows the head; the shoulder hump and scapulae the body
    for sx in (-1, 1):
        segs += [("head", V(sx * 0.07, 0.75, -0.65), V(sx * 0.25, 1.15, -0.55), 0.09), ("head", V(sx * 0.25, 1.15, -0.55), V(sx * 0.45, 1.5, -0.35), 0.1),
                 ("head", V(sx * 0.45, 1.5, -0.35), V(sx * 0.5, 1.8, 0.0), 0.1), ("body", V(sx * 0.12, 0.95, -0.35), V(sx * 0.22, 0.6, -0.42), 0.05)]
    segs += [("body", V(0, 0.95, -0.3), V(0, 0.8, 0.3), 0.06), ("front", V(0, 0.75, -0.5), V(0, 0.68, -0.66), 0.06)]
    return segs


def tine(F, p0, p1, bend, r0, r1, tag="bone", k=0.015, n=6, fork=0.0, fork_to=None):
    p0, p1 = V(*p0), V(*p1)
    bend = V(*bend)
    pts = [p0 + (p1 - p0) * (i / n) + bend * 4.0 * (i / n) * (1 - i / n) for i in range(n + 1)]
    rad = [r0 + (r1 - r0) * (i / n) ** 0.9 for i in range(n + 1)]
    Pt.chain(F, pts, rad, k, tag)
    if fork and fork_to is not None:
        i = int(n * fork)
        ft_ = V(*fork_to)
        tine(F, pts[i], ft_, (0, 0.03, 0), rad[i] * 0.75, r1, tag, k * 0.7, 4)
    return pts


def crown(F, sx):
    root = V(sx * 0.07, 0.77, H[2] - 0.0)
    beam = [root, V(sx * 0.2, 1.0, -0.64), V(sx * 0.36, 1.25, -0.52), V(sx * 0.5, 1.45, -0.35), V(sx * 0.58, 1.6, -0.12), V(sx * 0.55, 1.72, 0.1)]
    rad = [0.056, 0.048, 0.04, 0.033, 0.026, 0.018]
    Pt.chain(F, beam, rad, 0.03, "bark")
    F.add(Q.Ell(root + V(0, 0.0, 0.0), (0.06, 0.045, 0.055)), 0.04, "bark")
    # tines staggered up the beam (not sprayed from one spot), each its own length and lean, the long ones forked once
    def beam_at(t):
        f = t * (len(beam) - 1)
        i = min(int(f), len(beam) - 2)
        return beam[i] + (beam[i + 1] - beam[i]) * (f - i)
    for t_, d_, L_, r_, fork_ in [(0.16, (0.1 * sx, -0.05, -1.0), 0.5, 0.04, True), (0.3, (0.5 * sx, 1.0, -0.6), 0.5, 0.034, True),
                                  (0.45, (0.9 * sx, 0.8, -0.2), 0.45, 0.032, True), (0.6, (0.4 * sx, 1.0, 0.5), 0.4, 0.03, False),
                                  (0.74, (0.9 * sx, 0.7, 0.2), 0.4, 0.026, True), (0.88, (0.2 * sx, 1.0, 0.6), 0.3, 0.02, False)]:
        p0_ = beam_at(t_)
        d_ = Pt.unit(V(*d_))
        p1_ = p0_ + d_ * L_
        tine(F, p0_, p1_, (0, 0.05, 0), r_, 0.008, "bone", 0.016, 6, 0.65 if fork_ else 0.0, p0_ + d_ * L_ * 0.65 + Pt.unit(V(sx * 0.4, 0.8, 0.5)) * L_ * 0.45)
    for i in range(1, 5):                                             # burls on the beam
        F.add(Q.Ell(beam[i] + V(sx * 0.02, 0.02, 0.03), (0.034, 0.03, 0.036)), 0.02, "bark")


def field():
    F = Q.Field()
    F.add(TRUNK, 0.06, "bark")
    hz = H[2]
    # neck, thick, flowing down from the hump into the skull
    Pt.chain(F, [V(0, 0.82, -0.4), V(0, 0.8, -0.52), V(0, 0.74, -0.62), V(0, 0.69, hz + 0.01)], [0.2, 0.15, 0.115, 0.09], 0.07, "bark")
    # the deer skull: a rounded cranium, orbits ringed in raised bone with the ember set deep, a long face that narrows
    # to a nose with its nasal opening, a zygomatic arch, a slung jaw with teeth
    HS = 1.22                                                    # the head is the beast's face: it fills the frame
    CZ = hz - 0.02

    def sp(x, y, z):
        return V(x * HS, 0.69 + (y - 0.69) * HS, CZ + (z - CZ) * HS)

    def sr(*r):
        return tuple(v * HS for v in r)
    F.add(Q.Ell(sp(0, 0.69, hz - 0.02), sr(0.118, 0.105, 0.15)), 0.05, "bone")
    F.add(Q.Ell(sp(0, 0.775, hz + 0.0), sr(0.065, 0.032, 0.09)), 0.03, "bone")                                  # the crest the crown grows from
    F.add(Q.Ell(sp(0, 0.66, hz - 0.15), sr(0.095, 0.085, 0.1)), 0.05, "bone")
    F.add(Q.Ell(sp(0, 0.74, hz - 0.1), sr(0.1, 0.03, 0.07)), 0.04, "bone")
    F.add(Q.Ell(sp(0, 0.635, hz - 0.22), sr(0.07, 0.068, 0.075)), 0.04, "bone")
    F.add(Q.Ell(sp(0, 0.625, hz - 0.25), sr(0.056, 0.054, 0.05)), 0.03, "bone")
    F.add(Q.Ell(sp(0, 0.7, hz - 0.2), sr(0.02, 0.026, 0.13)), 0.04, "bone")                                    # nasal bridge ridge
    for sx in (-1, 1):
        F.add(Q.Ell(sp(sx * 0.112, 0.71, hz - 0.1), sr(0.04, 0.068, 0.064)), 0.03, "bone")                         # the orbit's rim
        F.add(Q.Ell(sp(sx * 0.085, 0.752, hz - 0.12), sr(0.055, 0.028, 0.07), (0.15, 0, 0)), 0.03, "bone")           # brow
        Pt.chain(F, [sp(sx * 0.11, 0.65, hz - 0.12), sp(sx * 0.125, 0.625, hz - 0.03), sp(sx * 0.09, 0.6, hz + 0.05)], [0.016 * HS, 0.017 * HS, 0.02 * HS], 0.012, "bone")   # zygomatic arch
        Pt.chain(F, [sp(sx * 0.07, 0.585, hz + 0.02), sp(sx * 0.058, 0.535, hz - 0.2), sp(sx * 0.03, 0.53, hz - 0.25)], [0.034 * HS, 0.028 * HS, 0.02 * HS], 0.012, "bone")      # lower jaw, slung open
        F.sub(Q.Ell(sp(sx * 0.13, 0.71, hz - 0.1), sr(0.04, 0.048, 0.046)), 0.012)
        F.add(Q.Ell(sp(sx * 0.122, 0.71, hz - 0.1), sr(0.03, 0.042, 0.04)), 0.004, "ember")
        for k in range(5):
            z = hz - 0.17 - 0.036 * k
            Pt.tooth(F, sp(sx * (0.056 - 0.002 * k), 0.592, z), (0, -1, 0.05), 0.045 * HS, (0.01 if k > 2 else 0.0075) * HS, "bone")
            Pt.tooth(F, sp(sx * (0.048 - 0.0015 * k), 0.535, z + 0.015), (0, 1, 0.05), 0.04 * HS, 0.009 * HS, "bone")
    F.sub(Q.Ell(sp(0, 0.635, hz - 0.28), sr(0.018, 0.021, 0.03)), 0.008)                                          # the nasal opening
    # the antler crown, rooted in the skull's crest
    for sx in (-1, 1):
        crown(F, sx)
    # the thorn mane: canes of briar grown from the hump and the neck, swept back
    for k in range(9):
        t = k / 8.0
        z = -0.5 + 0.7 * t
        r0 = V(0, top(z) - 0.03, z)
        for side in (-1, 1):
            tip = r0 + V(side * (0.06 + 0.05 * math.sin(t * 5)), 0.3 + 0.1 * math.sin(t * 7 + side), 0.18)
            mid = (r0 + tip) * 0.5 + V(side * 0.03, 0.05, -0.04)
            Pt.chain(F, [r0, mid, tip], [0.02, 0.014, 0.004], 0.025, "bark")
    # the spine of thorns
    for k in range(8):
        z = -0.42 + 0.125 * k
        L = 0.3 - 0.022 * k
        Pt.claw(F, V(0, top(z) - 0.02, z), (0, 1, 0.5), L, 0.05 - 0.003 * k, (0, 0, 1), 0.04, "bone", 4)
    # tail: thick root, bark ridged, ending in a bramble knot
    tl = Pt.arc(V(0, 0.6, 0.55), V(0, 0.3, 1.0), V(0, 0.08, 0.0), 8)
    Pt.chain(F, tl, [0.14, 0.12, 0.1, 0.085, 0.07, 0.058, 0.048, 0.04, 0.036], 0.05, "bark")
    kn = tl[-1] + V(0, -0.02, 0.05)
    F.add(Q.Ell(kn, (0.085, 0.085, 0.1)), 0.04, "bark")
    for k in range(12):
        a = k * 2.4
        d = V(math.cos(a), math.sin(a) * 0.8, 0.35 + 0.6 * math.sin(k * 1.3))
        Pt.claw(F, kn + Pt.unit(d) * 0.05, d, 0.16 + 0.04 * (k % 3), 0.024, (0, -0.3, 0.2), 0.015, "bone", 3)
    # the ember heart: a split down the breast between bark plates, lit inside, thorn lips
    F.sub(Q.Ell((0, 0.52, -0.64), (0.028, 0.16, 0.06)), 0.02)
    F.add(Q.Ell((0, 0.52, -0.6), (0.016, 0.13, 0.03)), 0.0, "ember")
    # legs
    for sx in (-1, 1):
        t = "fl" if sx < 0 else "fr"
        t2 = "bl" if sx < 0 else "br"
        hp, kn_, ft = S["leg_%s_hip" % t], S["leg_%s_knee" % t], S["leg_%s_foot" % t]
        # shoulder: a scapula under the hump, a heavy muscle, a humerus, the point of the elbow, a forearm, carpus, cannon
        F.add(Q.RoundCone(V(sx * 0.14, 0.95, -0.34), V(sx * 0.21, 0.52, -0.42), 0.09, 0.14, 0.5, (1, 0, 0)), 0.08, "bark")
        F.add(Q.Ell((sx * 0.22, 0.5, -0.4), (0.09, 0.17, 0.15)), 0.09, "bark")
        F.add(Q.RoundCone(hp + V(0, 0.02, 0), kn_ + V(0, 0.02, 0), 0.14, 0.085, 0.8, (1, 0, 0)), 0.06, "bark")
        F.add(Q.Ell(kn_ + V(0, 0.0, 0.07), (0.052, 0.06, 0.06)), 0.03, "bark")
        wr = V(sx * 0.2, 0.115, -0.385)
        Pt.chain(F, [kn_, kn_ + (wr - kn_) * 0.5, wr], [0.085, 0.07, 0.046], 0.05, "bark", 0.88)
        F.add(Q.Ell(wr + V(0, 0.0, 0.02), (0.05, 0.055, 0.05)), 0.03, "bark")
        Pt.chain(F, [wr, V(sx * 0.2, 0.06, -0.395)], [0.04, 0.036], 0.025, "hide")
        # cloven hoof gripped by roots
        for hf, hdx in ((0, -0.027), (1, 0.027)):
            F.add(Q.Ell((sx * 0.2 + hdx, 0.03, ft[2] - 0.035), (0.034, 0.036, 0.07)), 0.01, "bone")
        F.add(Q.Ell((sx * 0.2, 0.055, ft[2] - 0.01), (0.05, 0.04, 0.06)), 0.03, "hide")
        for k in range(3):
            a = (k - 1) * 0.8
            Pt.claw(F, V(sx * 0.2 + math.sin(a) * 0.035, 0.05, ft[2] - 0.03), (math.sin(a), -0.1, -math.cos(a)), 0.11, 0.026, (0, -0.8, 0), 0.025, "bark", 4)
        # hind: haunch, thigh, stifle, gaskin, hock, cannon, hoof
        hp2, kn2, ft2 = S["leg_%s_hip" % t2], S["leg_%s_knee" % t2], S["leg_%s_foot" % t2]
        F.add(Q.RoundCone(V(sx * 0.15, 0.7, 0.34), kn2 + V(0, 0.0, 0.02), 0.15, 0.08, 0.5, (1, 0, 0)), 0.07, "bark")
        F.add(Q.Ell((sx * 0.15, 0.64, 0.35), (0.07, 0.12, 0.13)), 0.09, "bark")
        F.add(Q.RoundCone(V(sx * 0.17, 0.52, 0.43), V(sx * 0.2, 0.28, 0.4), 0.07, 0.04, 0.6, (1, 0, 0)), 0.05, "bark")
        F.add(Q.Ell(kn2 + V(0, 0.0, -0.05), (0.04, 0.05, 0.034)), 0.02, "bark")
        hk = V(sx * 0.2, 0.17, 0.5)
        Pt.chain(F, [kn2, kn2 + (hk - kn2) * 0.5 + V(0, 0.01, 0.0), hk], [0.09, 0.07, 0.052], 0.04, "bark", 0.88)
        F.add(Q.Ell(hk + V(0, 0.0, 0.02), (0.04, 0.05, 0.04)), 0.02, "bark")
        Pt.chain(F, [V(sx * 0.2, 0.36, 0.42), V(sx * 0.2, 0.22, 0.52), hk + V(0, 0, 0.03)], [0.02, 0.018, 0.018], 0.015, "bark")
        Pt.chain(F, [hk, V(sx * 0.2, 0.09, 0.44), V(sx * 0.2, 0.06, ft2[2] - 0.0)], [0.046, 0.04, 0.042], 0.025, "hide")
        for hf, hdx in ((0, -0.027), (1, 0.027)):
            F.add(Q.Ell((sx * 0.2 + hdx, 0.03, ft2[2] - 0.035), (0.034, 0.036, 0.07)), 0.01, "bone")
        F.add(Q.Ell((sx * 0.2, 0.055, ft2[2] - 0.01), (0.05, 0.04, 0.06)), 0.03, "hide")
        for k in range(3):
            a = (k - 1) * 0.8
            Pt.claw(F, V(sx * 0.2 + math.sin(a) * 0.035, 0.05, ft2[2] - 0.03), (math.sin(a), -0.1, -math.cos(a)), 0.11, 0.026, (0, -0.8, 0), 0.025, "bark", 4)
    return F


# --- materials ---------------------------------------------------------------------------------------

def attr(m, name):
    n = m.n('ShaderNodeVertexColor')
    n.layer_name = name
    sp = m.n('ShaderNodeSeparateColor')
    m.links.new(n.outputs['Color'], sp.inputs['Color'])
    return sp.outputs['Red'], sp.outputs['Green'], sp.outputs['Blue']


def bark_mat():
    m = K.Mat("Bark")
    sc = m.scan("bark_brown_02", 3.5)
    crev, pid, moss_a = attr(m, "bark")
    col = m.mul(sc["color"], (0.5, 0.42, 0.37))
    col = m.mul(col, (0.62, 0.62, 0.62))
    vary = m.ramp(pid, [(0.0, (0.55, 0.5, 0.48)), (1.0, (1.25, 1.15, 1.05))])
    col = m.mul(col, (1.0, 1.0, 1.0))
    mx = m.n('ShaderNodeMix')
    mx.data_type = 'RGBA'
    mx.blend_type = 'MULTIPLY'
    mx.inputs[0].default_value = 1.0
    m.links.new(col, mx.inputs[6])
    m.links.new(vary, mx.inputs[7])
    col = mx.outputs[2]
    moss_n = m.noise(5.0, 6.0, 0.6)
    moss = m.math('MULTIPLY', m.math('GREATER_THAN', moss_n, 0.5), m.math('ADD', crev, 0.2), True)
    col = m.mix(moss, col, (0.045, 0.06, 0.03))
    char = m.math('MULTIPLY', m.math('GREATER_THAN', crev, 0.55), 0.9)
    col = m.mix(char, col, (0.012, 0.008, 0.006))
    h = m.math('ADD', m.math('MULTIPLY', sc["disp"], 1.0), m.math('MULTIPLY', crev, -0.8))
    gate = m.math('GREATER_THAN', m.noise(3.0, 2.0, 0.5), 0.54)
    seam = m.math('MULTIPLY', m.math('GREATER_THAN', crev, 0.9), gate)
    ember = m.mix(seam, (0.0, 0.0, 0.0), (1.0, 0.3, 0.05))
    return m.finish(col, m.math('ADD', m.math('MULTIPLY', sc["rough"], 0.4), 0.5), 0.0, h, 1.0, 0.006, emit=ember, emit_strength=2.4)


def bone_mat():
    m = K.Mat("Bone")
    sc = m.scan("beige_wall_001", 8.0)
    dirt = m.noise(8.0, 8.0, 0.6)
    crack = m.math('LESS_THAN', m.voronoi(30.0, 'DISTANCE_TO_EDGE'), 0.018)
    crack = m.math('MULTIPLY', crack, m.math('GREATER_THAN', m.noise(7.0, 3.0, 0.5), 0.5))
    col = m.mul(m.mono(sc["color"]), (0.95, 0.84, 0.66))
    col = m.mix(m.math('MULTIPLY', m.math('SUBTRACT', 1.0, dirt), 0.65), col, (0.3, 0.22, 0.14))
    col = m.mix(crack, col, (0.13, 0.09, 0.06))
    h = m.math('ADD', m.math('MULTIPLY', sc["disp"], 0.7), m.math('MULTIPLY', crack, -0.7))
    return m.finish(col, m.math('ADD', m.math('MULTIPLY', sc["rough"], 0.5), 0.3), 0.0, h, 0.8, 0.0025)


def hide_mat():
    m = K.Mat("Hide")
    sc = m.scan("brown_leather", 5.0)
    v = m.noise(6.0, 6.0, 0.6)
    col = m.mul(sc["color"], (0.3, 0.24, 0.2))
    moss = m.math('MULTIPLY', m.math('GREATER_THAN', m.noise(4.0, 6.0, 0.6), 0.62), m.math('GREATER_THAN', m.zpos(), 0.75))
    col = m.mix(moss, col, (0.04, 0.055, 0.03))
    col = m.mix(m.math('MULTIPLY', v, 0.3), col, (0.02, 0.012, 0.01))
    h = m.math('ADD', m.math('MULTIPLY', sc["disp"], 1.0), m.math('MULTIPLY', v, 0.2))
    return m.finish(col, m.math('ADD', m.math('MULTIPLY', sc["rough"], 0.5), 0.35), 0.0, h, 0.9, 0.005)


def ember_mat():
    m = K.Mat("Ember")
    v = m.noise(24.0, 4.0, 0.5)
    col = m.ramp(v, [(0.3, (1.0, 0.3, 0.05)), (0.8, (1.0, 0.65, 0.2))])
    return m.finish((0.05, 0.02, 0.01), 0.6, 0.0, None, emit=col, emit_strength=8.0)


def axes():
    A = []
    A.append(BK.Axis(V(0, 0.66, -0.5), V(0, 0.62, 0.55), (0, 1, 0), 0.25, 0.14, 0.17, 0.03))              # the trunk
    A.append(BK.Axis(V(0, 0.82, -0.4), V(0, 0.7, -0.64), (0, 1, 0), 0.15, 0.1, 0.12, 0.022))            # the neck
    for sx in (-1, 1):
        t, t2 = ("fl", "bl") if sx < 0 else ("fr", "br")
        hp, kn, ft = S["leg_%s_hip" % t], S["leg_%s_knee" % t], S["leg_%s_foot" % t]
        A.append(BK.Axis(hp + V(0, 0.1, 0), kn, (sx, 0, 0), 0.1, 0.09, 0.11, 0.018))
        A.append(BK.Axis(kn, V(sx * 0.2, 0.1, -0.385), (sx, 0, 0), 0.07, 0.08, 0.1, 0.014))
        hp2, kn2, ft2 = S["leg_%s_hip" % t2], S["leg_%s_knee" % t2], S["leg_%s_foot" % t2]
        A.append(BK.Axis(V(sx * 0.16, 0.66, 0.36), kn2, (sx, 0, 0), 0.12, 0.1, 0.12, 0.02))
        A.append(BK.Axis(kn2, V(sx * 0.2, 0.17, 0.5), (sx, 0, 0), 0.06, 0.08, 0.1, 0.014))
    A.append(BK.Axis(V(0, 0.58, 0.55), V(0, 0.4, 1.35), (0, 1, 0), 0.07, 0.05, 0.08, 0.012))
    return A


def detail(ctx):
    sc = ctx.sc
    P, N = ctx.P, ctx.N
    tags = ["bark", "hide", "bone", "ember"]
    idx = ctx.region(tags, {"bone": 0.004, "ember": 0.006, "hide": 0.0})
    barkish = (idx == 0) | (idx == 1)
    # bark zone: the upper and outer surfaces; hide under the belly, the throat, the lower legs
    zone = np.clip((N[:, 1] + 1.2) * 1.0, 0.0, 1.0) * barkish
    low_leg = np.clip((0.12 - P[:, 1]) * 14.0, 0.0, 1.0)
    zone = zone * (1.0 - low_leg)
    zone = np.where(idx == 1, 0.0, zone)                                     # a prim tagged hide stays hide
    zone = np.where(P[:, 2] < -0.62, zone * np.clip((0.7 - P[:, 1]) * 0 + 1.0, 0, 1) * 0.0, zone)       # not on the face
    zone = zone * np.clip((ctx.tag('bone') - 0.004) / 0.03, 0.0, 1.0)
    disp, crev, pid = BK.plates(P, N, axes(), zone, warp=0.55)
    sc.d += disp
    sc.noise(22.0, 0.004, mask=zone, seed=2)
    sc.noise(48.0, 0.0018, seed=7)
    sc.folds(36.0, 0.0016, mask=1.0 - zone)
    # the skull: deep sockets, brow, a long nasal channel; the ribs under the hide of the flank
    hz = H[2]
    for sx in (-1, 1):
        sc.bump((sx * 0.077, 0.7, hz - 0.11), 0.034, -0.014, facing=(sx, 0.2, -0.6))
        sc.bump((sx * 0.07, 0.64, hz - 0.2), 0.03, -0.01, facing=(sx, 0, -0.3))
        sc.ridge((sx * 0.04, 0.735, hz - 0.13), (sx * 0.075, 0.74, hz - 0.08), 0.014, 0.008, facing=(0, 1, 0))
        sc.ridge((sx * 0.025, 0.66, hz - 0.2), (sx * 0.028, 0.615, hz - 0.33), 0.008, -0.006, facing=(sx, 0.3, -0.4))
    mask_attr = np.zeros((len(P), 4), dtype=np.float32)
    mask_attr[:, 0] = crev
    mask_attr[:, 1] = pid
    ctx.attrs["bark"] = mask_attr
    BARK = bark_mat()
    HIDE = hide_mat()
    BONE = bone_mat()
    EMBER = ember_mat()
    out = np.zeros(len(P), dtype=np.int32)
    out[(idx == 0) | (idx == 1)] = 1                  # bark by default (the plates carry the pattern)
    out[(zone < 0.35) & barkish] = 0                  # hide where the plates fade out
    out[idx == 2] = 2
    out[idx == 3] = 3
    return [HIDE, BARK, BONE, EMBER], out


if __name__ == "__main__":
    R.run(__import__(__name__))
