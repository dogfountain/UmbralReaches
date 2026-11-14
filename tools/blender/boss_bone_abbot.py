"""The Bone Abbot: a skeletal abbot, lit from within by a reliquary candle, in a black cassock and an open cope
with gilt orphreys, a tall bone mitre, a crozier of fused vertebrae. ONE skinned mesh on the rig's sockets
(GruntModel poses it): a fused sculpted skeleton body, a skull with sockets and teeth, and cloth that is
draped geometry (boss_sculpt_lib.Garment: pleats that start at the belt and shoulders and widen to the
hem, a hem that pools on the ground, lapels rolling back) skinned to the hips, knees, chest and arms, so it
moves with the figure. The crozier is a separate rigid part on the right hand (bone_abbot.gd keeps it upright).

  tools/blender/run.sh boss_bone_abbot.py -- [--review shots/model_review/bone_abbot] [--no-export] [--lowres]
Writes art/models/boss_bone_abbot.glb and art/textures/boss_bone_abbot_{albedo,normal,orm,emit}.png
"""
import bpy
import math
import os
import sys
import numpy as np
from mathutils import Vector, noise

sys.path.insert(0, os.path.dirname(__file__))
import boss_kit as K
import grunt_kit as GK
import grunt_body as GB
import boss_sculpt_lib as L
from boss_kit import G

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
REVIEW = args[args.index("--review") + 1] if "--review" in args else ""
EXPORT = "--no-export" not in args
LOWRES = "--lowres" in args
HI = (150, 100) if LOWRES else (300, 190)

K.reset()
S = dict(K.SOCKETS)
P0, C0, H0 = S["pelvis"], S["chest"], S["head"]

# --- materials -----------------------------------------------------------------------------------
BONE = GK.grave_bone("Bone", (0.7, 0.64, 0.52), (0.22, 0.17, 0.11), 7.0, 0.7)


def brocade(name="Cloth", tint=(0.2, 0.17, 0.2)):
    """Black wool with a faint gilt damask: a lattice of diamonds, a darker nap, grime rising from the hem."""
    m = K.Mat(name)
    sc = m.scan("caban", 9.0)
    blot = m.noise(5.0, 6.0, 0.6)
    col = m.mul(m.mono(sc["color"]), tuple(c * 0.55 for c in tint))
    col = m.mix(m.math('MULTIPLY', blot, 0.4), col, (0.012, 0.01, 0.012))
    sep = m.n('ShaderNodeSeparateXYZ')
    geo = m.n('ShaderNodeNewGeometry')
    m.links.new(geo.outputs['Position'], sep.inputs[0])
    wv = lambda a, b: m.math('ABSOLUTE', m.math('SINE', m.math('ADD', m.math('MULTIPLY', sep.outputs['X'], a), m.math('MULTIPLY', sep.outputs['Z'], b))))
    d1 = m.math('LESS_THAN', wv(30.0, 19.0), 0.035)
    d2 = m.math('LESS_THAN', wv(30.0, -19.0), 0.035)
    lat = m.math('MAXIMUM', d1, d2)
    dots = m.math('MULTIPLY', m.math('LESS_THAN', m.voronoi(26.0, 'F1'), 0.035), 1.0)
    pat = m.math('MAXIMUM', m.math('MULTIPLY', lat, 0.5), dots)
    col = m.mix(m.math('MULTIPLY', pat, 0.38), col, (0.36, 0.25, 0.1))
    h = m.math('ADD', m.math('MULTIPLY', sc["disp"], 0.9), m.math('MULTIPLY', pat, 0.4))
    rough = m.math('SUBTRACT', m.math('ADD', m.math('MULTIPLY', sc["rough"], 0.3), 0.7), m.math('MULTIPLY', pat, 0.3))
    return m.finish(col, rough, m.math('MULTIPLY', pat, 0.4), h, 0.7, 0.0018)


def gilt(name="Gold", base=(0.78, 0.55, 0.22)):
    m = K.Mat(name)
    wear = m.noise(18.0, 6.0, 0.6)
    col = m.ramp(wear, [(0.3, (0.32, 0.2, 0.07)), (0.62, base), (0.9, (0.95, 0.76, 0.4))])
    brick = m.n('ShaderNodeTexBrick')
    brick.inputs['Scale'].default_value = 90.0
    brick.inputs['Mortar Size'].default_value = 0.05
    m.links.new(m.coord.outputs['Object'], brick.inputs['Vector'])
    rough = m.math('ADD', 0.24, m.math('MULTIPLY', m.math('SUBTRACT', 1.0, wear), 0.4))
    h = m.math('ADD', m.noise(90.0, 3.0, 0.5), m.math('MULTIPLY', brick.outputs['Fac'], 0.6))
    return m.finish(col, rough, 0.95, h, 0.5, 0.0016)


def wax_mat():
    m = K.Mat("Wax")
    v = m.noise(30.0, 4.0, 0.5)
    col = m.ramp(v, [(0.3, (0.66, 0.6, 0.48)), (0.8, (0.85, 0.8, 0.66))])
    return m.finish(col, 0.42, 0.0, v, 0.3, 0.003)


def glow_mat(name, col, strength):
    m = K.Mat(name)
    return m.finish((0.05, 0.03, 0.01), 0.6, 0.0, None, emit=col, emit_strength=strength)


def sinew_mat():
    m = K.Mat("Sinew")
    v = m.noise(40.0, 6.0, 0.6)
    col = m.ramp(v, [(0.3, (0.08, 0.04, 0.035)), (0.8, (0.22, 0.12, 0.09))])
    return m.finish(col, 0.5, 0.0, v, 0.6, 0.002)


CLOTH = brocade()
WINE = GK.cloth("Wine", (0.14, 0.02, 0.03), "caban", 9.0, (0.02, 0.008, 0.012), 0.8)
GOLD = gilt()
WAX = wax_mat()
FLAME = glow_mat("Flame", (1.0, 0.62, 0.22), 8.0)
EYE = glow_mat("Eye", (1.0, 0.66, 0.25), 8.0)
SINEW = sinew_mat()
MATS = [BONE, CLOTH, WINE, GOLD, WAX, FLAME, EYE, SINEW]
objs = []
PAIRS = []
WEIGHTS = {}


def TUBE(*a, **k):
    return K.curve_tube(*a, res=1, **k)


def add(o, w=None):
    objs.append(o)
    if w is not None:
        WEIGHTS[o["sock"]] = w
    return o


# --- the skeleton -------------------------------------------------------------------------------------------------
# the pelvis and legs are one fused sculpted surface; the spine, ribs, collarbones and arms are real bones
# (long bones with knobbed ends, fused where they meet), every one weighted along its own length so the figure
# bends at the waist, the shoulders, the elbows and the knees
W, LL = 0.92, 0.62
sk = GB.Skel()
sk.v("pel", (0, 0.90, 0), 0.04)
sk.v("wst", (0, 1.02, 0), 0.03, "pel")
sk.loft([(0.775, 0, 0.0, 0.06 * W, 0.05, 0.05, 2.0), (0.81, 0, 0.0, 0.09 * W, 0.06, 0.07, 2.2), (0.88, 0, 0.005, 0.11 * W, 0.07, 0.09, 2.3),
         (0.97, 0, 0.0, 0.12 * W, 0.07, 0.09, 2.2), (1.04, 0, 0.0, 0.07, 0.05, 0.06, 2.0), (1.08, 0, 0.03, 0.04, 0.035, 0.04, 2.0)])
for sx, tag in ((-1, "l"), (1, "r")):
    lx = sx * 0.11
    sk.v("hip" + tag, (sx * 0.1, 0.88, 0), 0.06, "pel")
    sk.v("th1" + tag, (lx, 0.76, 0), 0.052, "hip" + tag)
    sk.v("th2" + tag, (lx, 0.6, -0.004), 0.044, "th1" + tag)
    sk.v("th3" + tag, (lx, 0.46, -0.012), 0.036, "th2" + tag)
    sk.v("kn" + tag, (lx, 0.34, -0.01), 0.032, "th3" + tag)
    sk.v("c1" + tag, (lx, 0.255, 0.018), (0.03, 0.034), "kn" + tag)
    sk.v("c2" + tag, (lx, 0.16, 0.014), (0.022, 0.026), "c1" + tag)
    sk.v("an" + tag, (lx, 0.07, 0.01), 0.018, "c2" + tag)
    sk.v("hl" + tag, (lx, 0.035, 0.045), 0.022, "an" + tag)
    sk.v("ft" + tag, (lx, 0.03, -0.055), (0.026, 0.018), "an" + tag)
    for k in range(4):
        tx = lx + (k - 1.5) * 0.019
        e_ = 1.5 - abs(k - 1.5)
        sk.chain("ft" + tag, "t%d%s" % (k, tag), [((tx, 0.022, -0.115 - 0.006 * e_), 0.0095), ((tx * 1.03, 0.013, -0.15 - 0.008 * e_), 0.007)])


def legs_sculpt(s):
    for sx in (-1, 1):
        lx = sx * 0.11
        s.bump((lx, 0.345, -0.04), 0.026, 0.014, facing=(0, 0, -1))              # kneecaps
        s.ridge((lx, 0.31, -0.036), (lx, 0.1, -0.03), 0.009, 0.01, facing=(0, 0, -1))   # shin edges
        s.ridge((lx, 0.62, -0.02), (lx, 0.38, -0.014), 0.01, 0.006, facing=(0, 0, -1))
    s.noise(30.0, 0.0018)


bo, bhi = L.sculpted("Legs", sk, "pel", BONE, "bodyskin", 2000, legs_sculpt, 0.0048, False, PAIRS)
add(bo)
SEGS = L.segs()
WEIGHTS["bodyskin"] = GB.envelope_weights([sg for sg in SEGS if sg[0] in ("pelvis", "hip_l", "hip_r", "knee_l", "knee_r", "foot_l", "foot_r")])

# the spine: seventeen vertebrae with their processes, curving up behind the ribcage and forward into the skull
SPW = lambda p: GK.chain_w(p, [("pelvis", G(0, 0.9, 0.0)), ("chest", G(0, 1.1, 0.07)), ("head", G(0, 1.64, -0.01))], [0.07, 0.05])
WEIGHTS["spine"] = SPW
for k in range(16):
    t = k / 15.0
    y = 1.0 + t * 0.62
    z = 0.075 - 0.02 * math.sin(t * 2.2) + (-0.075 * max(0.0, (t - 0.72) / 0.28) ** 1.6)
    s_ = 1.0 - 0.38 * t
    add(K.blob("Vert", G(0, y, z), (0.025 * s_, 0.021 * s_, 0.017), "spine", BONE, 10, 6), SPW)
    add(K.loft("Spinous", [G(0, y, z + 0.012), G(0, y - 0.015, z + 0.05 * s_)], [0.008 * s_, 0.0025], "spine", BONE, 5), SPW)
    for sx in (-1, 1):
        add(K.loft("Transverse", [G(0, y, z), G(sx * 0.045 * s_, y, z + 0.006)], [0.0065 * s_, 0.0035], "spine", BONE, 5), SPW)

# the ribcage: ten pairs, slanting down toward the breastbone, shorter at the top and the bottom; clavicles and shoulder blades
CH = lambda p: {"chest": 1.0}
for i in range(9):
    t = i / 8.0
    y = 1.46 - 0.043 * i
    w = (0.085 + 0.085 * math.sin(min(t * 1.15, 1.0) * math.pi * 0.62)) * (1.0 - 0.22 * t * t)
    d = 0.1 + 0.012 * math.sin(t * math.pi)
    rr = 0.0085 + 0.0015 * math.sin(t * math.pi)
    for sx in (-1, 1):
        pts = []
        for k in range(11):
            a = math.pi * (0.04 + 0.86 * k / 10.0)
            fall = 0.055 * (k / 10.0) ** 1.4
            pts.append(G(sx * math.sin(a) * w + sx * 0.02 * (1 - math.cos(a)) * 0.0, y - fall, 0.02 - math.cos(a) * d))
        add(K.loft("Rib", pts, [rr * (0.8 + 0.3 * math.sin(math.pi * k / 10.0)) for k in range(11)], "chest", BONE, 5, squash=(1.0, 0.55), wobble=0.08), CH)
        if i < 7:
            add(K.loft("Cartilage", [pts[-1], G(sx * 0.016, y - 0.07, -0.112 - 0.004 * i)], [rr * 0.8, rr * 0.9], "chest", SINEW, 4), CH)
add(K.loft("Sternum", [G(0, 1.47, -0.108), G(0, 1.31, -0.122), G(0, 1.17, -0.112)], [(0.024, 0.007), (0.021, 0.008), (0.011, 0.006)], "chest", BONE, 8), CH)
add(K.blob("Manubrium", G(0, 1.46, -0.1), (0.034, 0.012, 0.022), "chest", BONE, 12, 8), CH)
for sx in (-1, 1):
    add(K.bone("Clavicle", G(sx * 0.02, 1.475, -0.095), G(sx * 0.215, 1.455, -0.03), 0.0095, "chest", BONE, 1.7, 8, 12, sx), CH)
    sc_ = K.blob("Scapula", G(sx * 0.12, 1.37, 0.115), (0.07, 0.01, 0.085), "chest", BONE, 20, 10)
    sc_.rotation_euler = (0.0, 0.0, sx * 0.3)
    add(sc_, CH)
    add(K.bone("Spine of scapula", G(sx * 0.05, 1.41, 0.12), G(sx * 0.2, 1.46, 0.06), 0.007, "chest", BONE, 1.4, 6, 8, sx), CH)

# the arms: humerus, radius and ulna, a hand of carpals, metacarpals and three-jointed fingers with long claws
ARMW = {}
for tag, sx in (("l", -1), ("r", 1)):
    ax = sx * 0.24
    sock = "arm_" + tag
    parts = []

    def pa(o):
        o["sock"] = sock
        parts.append(o)
        return o
    pa(K.blob("HumHead", G(ax, 1.4, 0), (0.034, 0.034, 0.032), sock, BONE, 18, 10))
    pa(K.bone("Humerus", G(ax, 1.39, 0), G(ax, 1.1, 0.004), 0.0165, sock, BONE, 1.8, 12, 14, sx))
    pa(K.blob("Olecranon", G(ax, 1.075, 0.026), (0.02, 0.022, 0.026), sock, BONE, 12, 8))
    for dz, nm in ((-0.012, "Radius"), (0.012, "Ulna")):
        pa(K.bone(nm, G(ax + sx * 0.002, 1.075, dz), G(ax + sx * 0.003, 0.77, dz * 0.7), 0.0095, sock, BONE, 1.9, 10, 14, dz))
    pa(K.blob("Carpals", G(ax + sx * 0.002, 0.75, -0.008), (0.027, 0.021, 0.019), sock, BONE, 14, 8))
    for f in range(4):
        fx = ax + (f - 1.5) * 0.017
        len_ = [0.9, 1.0, 0.95, 0.8][f] * 1.2
        base = G(fx * 0.9 + ax * 0.1, 0.735, -0.012)
        mc = G(fx, 0.665, -0.02)
        pa(K.bone("Metacarpal", base, mc, 0.0075, sock, BONE, 1.7, 7, 5, f))
        p0 = mc
        pts = [mc]
        yy, zz = 0.665, -0.02
        for j, (ln, rr) in enumerate(((0.052, 0.0082), (0.036, 0.007), (0.028, 0.0058))):
            yy -= ln * len_ * 0.96
            zz -= (0.008 + 0.012 * j) * len_
            pts.append(G(fx + sx * 0.0015 * f, yy, zz))
            pa(K.bone("Phalanx", pts[-2], pts[-1], rr, sock, BONE, 1.55, 7, 4, f + j))
        d = Vector(pts[-1]) - Vector(pts[-2])
        pa(GK.claw("Claw", pts[-1], d.normalized() + Vector(G(0, -0.15, -0.3)), 0.055 * len_, 0.0042, sock, BONE, 0.55))
    tb = G(ax - sx * 0.022, 0.73, -0.016)
    pa(K.bone("ThumbA", tb, G(ax - sx * 0.04, 0.68, -0.04), 0.0072, sock, BONE, 1.6, 7, 4))
    pa(K.bone("ThumbB", G(ax - sx * 0.04, 0.68, -0.04), G(ax - sx * 0.05, 0.635, -0.062), 0.0058, sock, BONE, 1.5, 7, 4))
    pa(GK.claw("Claw", G(ax - sx * 0.05, 0.635, -0.062), Vector(G(-sx * 0.2, -1.0, -0.5)), 0.045, 0.004, sock, BONE, 0.5))
    fz_ = K.fuse(parts, 0.0028, keep=set(), sculpt=0.0009, sculpt_scale=0.015, decimate=0.07)
    for o in fz_:
        o["fixed"] = True
        add(o)
    ARMW[sock] = (lambda t, sx_: (lambda p: GK.chain_w(p, [("chest", C0), ("shoulder_" + t, S["shoulder_" + t]),
                                                         ("elbow_" + t, S["elbow_" + t] + G(0, 0.02, 0)), ("hand_" + t, S["hand_" + t] + G(0, 0.0, 0))],
                                                        [0.03, 0.03, 0.022])))(tag, sx)
    WEIGHTS[sock] = ARMW[sock]

# --- the skull: its own sculpted surface, sockets and nasal cavity cut in, a loose jaw of teeth --------------------
def skull_sculpt(s):
    GB.head_sculpt(s, OPT, _Y)
    s.noise(45.0, 0.0015)
    s.folds(95.0, 0.0006)


OPT = dict(W=0.92, L=0.62, nk=0.0, finger=0.17, wrist=0.74, hc=(0, 1.665, -0.035), head_w=0.07, neck_r=0.03, skull=True, nohead=True)
_Y = lambda y: y
hy, hz = OPT["hc"][1], OPT["hc"][2]
skp = GB.skull_part(OPT, _Y)
so, shi = L.sculpted("Skull", skp, "a", BONE, "skull", 2800, skull_sculpt, 0.0035, False, PAIRS)
add(so, lambda p: {"head": 1.0})
HCB = Vector(G(0, hy, hz))
L.scale_about([so, shi], HCB, 1.2)
for row, (dy, sgn) in enumerate(((-0.058, -1), (-0.072, 1))):
    for k in range(11):
        a = math.pi * (0.14 + 0.72 * k / 10.0)
        base = HCB + (Vector(G(math.cos(a) * 0.036, hy + dy, hz - 0.052 - math.sin(a) * 0.03)) - HCB) * 1.2
        add(K.loft("Tooth", [base, base + Vector(G(0, -sgn * 0.024, 0))], [0.0062, 0.0], "head", BONE, 5, cap0=False), lambda p: {"head": 1.0})
for sx in (-1, 1):
    add(K.blob("Eye", HCB + (Vector(G(sx * 0.034, hy + 0.012, hz - 0.075)) - HCB) * 1.2, (0.0125, 0.008, 0.0125), "head", EYE, 12, 8), lambda p: {"head": 1.0})

# the reliquary: a gilt cage of curved bars, a candle burning in it, on a chain from the neck
RQ = C0 + G(0, -0.12, -0.27)
for k in range(6):
    a = math.tau * k / 6.0
    pts = [RQ + G(math.cos(a) * (0.02 + 0.05 * math.sin(j / 8.0 * math.pi)), 0.08 - j / 8.0 * 0.18, math.sin(a) * (0.02 + 0.05 * math.sin(j / 8.0 * math.pi))) for j in range(9)]
    add(TUBE("Bar", pts, 0.006, "chest", GOLD), CH)
for y, r in ((0.085, 0.03), (-0.1, 0.028)):
    add(K.blob("Cap", RQ + G(0, y, 0), (r, r, 0.016), "chest", GOLD, 24, 10), CH)
add(K.loft("Finial", [RQ + G(0, 0.09, 0), RQ + G(0, 0.15, 0)], [0.01, 0.0], "chest", GOLD, 8), CH)
add(K.loft("Candle", [RQ + G(0, -0.09, 0), RQ + G(0, -0.01, 0)], [0.018, 0.017], "chest", WAX, 14), CH)
add(K.blob("Flame", RQ + G(0, 0.02, 0), (0.011, 0.011, 0.026), "chest", FLAME, 12, 8), CH)
chain = [G(-0.11, 1.5, -0.07), G(-0.06, 1.38, -0.15), RQ + G(0, 0.15, 0), G(0.06, 1.38, -0.15), G(0.11, 1.5, -0.07)]
add(TUBE("Chain", chain, 0.0045, "chest", GOLD), CH)

# --- cloth ---------------------------------------------------------------------------------------------------
hip_w = L.skirt_weights(1.12, 0.92, 0.42)
cass = L.Garment([(1.18, 0, 0, 0.14, 0.105, 0.105, 2.2), (1.0, 0, 0, 0.16, 0.125, 0.125, 2.1), (0.78, 0, 0, 0.2, 0.16, 0.17, 2.0),
                  (0.48, 0, 0.01, 0.29, 0.24, 0.26, 2.0), (0.2, 0, 0.02, 0.4, 0.34, 0.38, 2.0), (-0.1, 0, 0.02, 0.52, 0.47, 0.52, 2.0)],
                 top=1.18, hem=0.025, folds=[(12, 0.0, 1.0, 0.3, 0.1), (25, 0.0, 0.7, 1.3, -0.15), (6, 0.4, 0.3, 2.0, 0)], amp=0.07,
                 ramp=(0.0, 0.45), lay=0.07, lay_r=0.07, hem_lift=0.05, micro=0.0016, back_drop=0.05)
lo, hi = L.shell(cass, "Cassock", "cassock", WINE, 4200, HI)
PAIRS.append((lo, hi))
add(lo, hip_w)
# the two bands of the stole down the front, orphrey bands at the hem and a placket
for nm, (v0, v1, u0, u1) in (("StoleL", (0.02, 0.97, -0.055, -0.018)), ("StoleR", (0.02, 0.97, 0.018, 0.055)), ("HemBand", (0.875, 0.925, 0.0, 1.0)),
                             ("HemBand2", (0.83, 0.845, 0.0, 1.0))):
    add(L.band(cass, nm, "cassock_trim", GOLD, v0, v1, u0, u1, n=90 if u1 - u0 > 0.5 else 3, m=50 if v1 - v0 > 0.5 else 2, off=0.012), hip_w)
WEIGHTS["cassock_trim"] = hip_w

cope_w = L.cape_weights(0.5)
cope = L.Garment([(1.86, 0, 0.1, 0.2, 0.0, 0.1, 2.0), (1.72, 0, 0.07, 0.2, 0.06, 0.15, 2.0), (1.58, 0, 0.03, 0.24, 0.13, 0.17, 2.2), (1.44, 0, 0.0, 0.38, 0.18, 0.2, 2.0),
                  (1.1, 0, 0.0, 0.44, 0.26, 0.29, 2.0), (0.7, 0, 0.02, 0.54, 0.34, 0.41, 2.0), (0.3, 0, 0.03, 0.66, 0.46, 0.6, 2.0),
                  (0.0, 0, 0.04, 0.78, 0.57, 0.78, 2.0), (-0.1, 0, 0.04, 0.82, 0.61, 0.82, 2.0)],
                 top=1.86, hem=0.03, folds=[(9, 0.3, 1.0, 0.3, 0.15), (19, 0.0, 0.6, 1.1, -0.2), (4, 0.6, 0.5, 2.0, 0.0)], amp=0.2,
                 ramp=(0.1, 0.5), gap=0.9, gap_from=0.0, lay=0.06, lay_r=0.09, hem_lift=0.06, flare=0.06, micro=0.0014, back_drop=0.1,
                 top_fn=lambda t: -0.24 + 0.34 * ((np.sin(t) + 1.0) * 0.5) ** 1.5)
lo, hi = L.shell(cope, "Cope", "cope", CLOTH, 3000, HI, solid=0.011)
PAIRS.append((lo, hi))
add(lo, cope_w)
# the orphrey: a broad gilt band down each front edge and round the hem, a morse (clasp) at the throat
for nm, (v0, v1, u0, u1) in (("OrphL", (0.08, 0.992, 0.0, 0.045)), ("OrphR", (0.08, 0.992, 0.955, 1.0)), ("CopeHem", (0.885, 0.93, 0.0, 1.0))):
    add(L.band(cope, nm, "cope_trim", GOLD, v0, v1, u0, u1, n=3 if u1 - u0 < 0.5 else 110, m=60 if v1 - v0 > 0.5 else 2, off=0.014), cope_w)
# the pallium: a Y of gilt orphrey down the back (from each shoulder to the nape, then straight to the hem), a ring at the crossing
add(L.ribbon(cope, "PalliumL", "cope_trim", GOLD, [(0.3, 0.12), (0.4, 0.22), (0.5, 0.34), (0.5, 0.985)], 0.045, 60, 0.014), cope_w)
add(L.ribbon(cope, "PalliumR", "cope_trim", GOLD, [(0.7, 0.12), (0.6, 0.22), (0.5, 0.34)], 0.045, 30, 0.014), cope_w)
_pc = Vector(G(*cope.surf(np.array([0.5]), np.array([0.34]))[0][0]))
add(K.blob("PalliumBoss", _pc + Vector((0, 0.03, 0)), (0.055, 0.02, 0.055), "cope_trim", GOLD, 20, 10), cope_w)
add(K.blob("PalliumJewel", _pc + Vector((0, 0.045, 0)), (0.02, 0.01, 0.027), "cope_trim", EYE, 12, 8), cope_w)
WEIGHTS["cope_trim"] = cope_w


for tag, sx in (("l", -1), ("r", 1)):
    sl = L.Garment([(1.47, sx * 0.23, 0, 0.082, 0.077, 0.077, 2.2), (1.3, sx * 0.24, 0, 0.078, 0.078, 0.078, 2.2), (1.08, sx * 0.245, 0, 0.09, 0.09, 0.09, 2.2),
                    (1.08, sx * 0.25, 0, 0.13, 0.12, 0.12, 2.0), (0.98, sx * 0.26, 0, 0.18, 0.165, 0.165, 2.0), (0.88, sx * 0.265, 0.01, 0.2, 0.19, 0.19, 2.0)],
                   top=1.47, hem=1.0, folds=[(8, 0.0, 1.0, 0.5, 0.1), (17, 0, 0.6, 1.5, 0)], amp=0.055, ramp=(0.2, 0.7), lay=0.0, hem_lift=0.035, seed=sx,
                   micro=0.0013, back_drop=0.05)
    lo, hi = L.shell(sl, "Sleeve" + tag, "sleeve_" + tag, WINE, 1500, (140, 100) if not LOWRES else (80, 60))
    PAIRS.append((lo, hi))
    add(lo, L.sleeve_weights(tag))
    add(L.band(sl, "Cuff" + tag, "sleeve_" + tag + "_t", GOLD, 0.9, 0.99, 0.0, 1.0, n=60, m=3, off=0.012), L.sleeve_weights(tag))
    WEIGHTS["sleeve_" + tag + "_t"] = L.sleeve_weights(tag)

# --- the mitre: a tall ogee of bone, a gilt circlet and orphreys, a jewel, lappets down the back ------------------------
MB = H0 + G(0, 0.085, -0.03)
NU, NS = 36, 14
Pr = np.zeros((NS + 1, NU, 3))
for i in range(NS + 1):
    s = i / NS
    for j in range(NU):
        a = math.tau * j / NU
        # the front and back are shields rising to the peak; at the sides the cleft closes into a fold
        hmax = 0.56 * (0.2 + 0.8 * abs(math.sin(a)) ** 0.7)
        rx = 0.158 * (1.0 - s) ** 1.45 + 0.0035 * s
        ry = 0.095 * (1.0 - s ** 1.2) ** 0.9 + 0.003
        # rig space: x, y up, z (the front is -z); the mitre sits on the head
        Pr[i, j] = (math.cos(a) * rx, 1.64 + 0.085 + s * hmax, -0.03 - math.sin(a) * ry)
mit = L.grid_mesh("Mitre", Pr, True, "head", BONE)
add(mit, lambda p: {"head": 1.0})
circ = [MB + Vector((math.cos(a) * 0.166, math.sin(a) * 0.1, 0.012)) for a in [math.tau * i / 36 for i in range(37)]]
add(TUBE("Circlet", circ, 0.0125, "head", GOLD), lambda p: {"head": 1.0})
circ2 = [MB + Vector((math.cos(a) * 0.15, math.sin(a) * 0.09, 0.055)) for a in [math.tau * i / 36 for i in range(37)]]
add(TUBE("Circlet2", circ2, 0.005, "head", GOLD), lambda p: {"head": 1.0})
for sy in (-1, 1):
    pts = []
    for k in range(14):
        t = k / 13.0
        pts.append(MB + Vector((0, sy * (0.095 * (1.0 - t ** 1.2) ** 0.9 + 0.007), 0.012 + t * 0.55)))
    add(TUBE("Orphrey", pts, 0.008, "head", GOLD), lambda p: {"head": 1.0})
    for k in range(5):
        t = 0.15 + 0.17 * k
        y = sy * (0.095 * (1.0 - t ** 1.2) ** 0.9 + 0.01)
        add(K.blob("Boss", MB + Vector((0, y, t * 0.56)), (0.012, 0.007, 0.012), "head", GOLD, 10, 5), lambda p: {"head": 1.0})
# the cross of gilt on the front shield
add(TUBE("CrossV", [MB + Vector((0, 0.099, 0.06)), MB + Vector((0, 0.09, 0.36))], 0.009, "head", GOLD), lambda p: {"head": 1.0})
add(TUBE("CrossH", [MB + Vector((-0.055, 0.094, 0.24)), MB + Vector((0.055, 0.094, 0.24))], 0.009, "head", GOLD), lambda p: {"head": 1.0})
add(K.blob("Jewel", MB + Vector((0, 0.108, 0.11)), (0.018, 0.006, 0.026), "head", EYE, 12, 8), lambda p: {"head": 1.0})
add(K.blob("Finial", MB + Vector((0, 0, 0.57)), (0.014, 0.014, 0.022), "head", GOLD, 12, 8), lambda p: {"head": 1.0})
for sx in (-1, 1):
    pts = [MB + Vector((sx * 0.05, -0.085, 0.0)) + Vector((sx * 0.06 * t, -0.03 * t, -0.52 * t)) + Vector((0, -0.012 * math.sin(t * 6.0), 0)) for t in [i / 10.0 for i in range(11)]]
    add(K.loft("Lappet", pts, [(0.03, 0.004)] * 11, "head", WINE, 8), lambda p: {"head": 1.0})
    add(K.loft("LappetTrim", pts[6:], [(0.026, 0.006)] * 5, "head", GOLD, 8), lambda p: {"head": 1.0})

# --- the crozier: a staff of fused vertebrae, a gilt knop, a spiral crook with a skull and a flame (rigid, right hand) ---
HR = S["hand_r"]
cro = []


def cadd(o):
    o["sock"] = "crozier"
    cro.append(o)
    return o


shaft = [HR + G(0.0, -0.75 + 1.9 * t, -0.04) for t in [i / 20.0 for i in range(21)]]
cadd(K.loft("Shaft", shaft, [0.014] * 21, "crozier", BONE, 10, wobble=0.05))
for k in range(26):
    cadd(K.blob("Bead", HR + G(0.0, -0.72 + 0.072 * k, -0.04), (0.021, 0.021, 0.013), "crozier", BONE, 14, 6))
cadd(K.blob("Knop", HR + G(0, 1.13, -0.04), (0.036, 0.036, 0.032), "crozier", GOLD, 24, 12))
crook = []
for k in range(30):
    a = k / 29.0 * math.pi * 1.6
    r = 0.13 * (1.0 - 0.32 * k / 29.0)
    crook.append(HR + G(0.0, 1.15 + math.sin(a) * r, -0.04 - (1.0 - math.cos(a)) * r))
cadd(K.loft("Crook", crook, [0.016 * (1.0 - 0.6 * k / 29.0) for k in range(30)], "crozier", BONE, 10))
for k in range(1, 28, 3):
    cadd(K.blob("CrookBead", crook[k], (0.019, 0.019, 0.019), "crozier", BONE, 12, 6))
cadd(K.blob("CrookSkull", HR + G(0, 1.2, -0.12), (0.03, 0.036, 0.033), "crozier", BONE, 20, 12))
cadd(K.blob("CrookFlame", HR + G(0, 1.27, -0.17), (0.012, 0.012, 0.03), "crozier", FLAME, 12, 8))
fz = K.fuse(cro, 0.006, keep={"Gold", "Flame"}, sculpt=0.0008, sculpt_scale=0.02, decimate=0.12)
objs.extend(fz)

print("ABBOT parts", len(objs), "tris", sum(L.tri_count(o) for o in objs))
_t = {}
for o in objs:
    _t[o["sock"]] = _t.get(o["sock"], 0) + L.tri_count(o)
print("TRIS by part", _t)
if REVIEW:
    os.makedirs(os.path.dirname(REVIEW), exist_ok=True)
if REVIEW and not EXPORT:
    L.drop_highs(PAIRS)
    if "--close" in args:
        L.turnarounds(REVIEW + "_hands", 0.8, 2.2, angles=(("a", 75), ("b", 100)), samples=32, size=(700, 700), cam_z=0.9)
        L.turnarounds(REVIEW + "_head", 1.7, 1.8, angles=(("a", 80), ("b", 40)), samples=32, size=(700, 700), cam_z=1.7)
    if "--nocloth" in args:
        for o in objs:
            if o["sock"] in ("cassock", "cope", "cope_trim", "cassock_trim", "sleeve_l", "sleeve_r", "sleeve_l_t", "sleeve_r_t"):
                o.hide_render = True
    L.turnarounds(REVIEW + "_raw", 1.05, 5.4, angles=(("front", 90), ("three", 45), ("side", 0), ("back", -90)), samples=32, size=(700, 940))
if EXPORT:
    WEIGHTS["crozier"] = lambda p: {"hand_r": 1.0}
    L.export_skinned2(objs, MATS, "boss_bone_abbot", S, WEIGHTS, {"crozier": ("staff_hand_r", S["hand_r"])}, 4096 if not LOWRES else 1024, PAIRS)
    L.drop_highs(PAIRS)
    if REVIEW:
        L.use_atlas("boss_bone_abbot")
        arm = bpy.data.objects["Armature"]
        L.turnarounds(REVIEW + "_turn", 1.05, 5.4)
        for nm, rots in L.POSES.items():
            L.reset_pose(arm)
            L.pose(arm, rots)
            L.turnarounds(REVIEW + "_" + nm, 1.05, 5.4, angles=(("front", 90), ("three", 45), ("side", 0)))
