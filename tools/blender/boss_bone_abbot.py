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
SHADE = GK.grave_bone("ShadeBone", (0.36, 0.31, 0.24), (0.07, 0.05, 0.035), 7.0, 0.7)    # the skull in the hood: bone gone dark with soot and age


def brocade(name="Cloth", tint=(0.2, 0.17, 0.2)):
    """Black wool with a faint gilt damask: a lattice of diamonds, a darker nap, grime rising from the hem."""
    m = K.Mat(name)
    sc = m.scan("caban", 9.0)
    blot = m.noise(5.0, 6.0, 0.6)
    col = m.mul(m.mono(sc["color"]), tuple(c * 0.85 for c in tint))
    col = m.mix(m.math('MULTIPLY', blot, 0.4), col, (0.012, 0.01, 0.012))
    sep = m.n('ShaderNodeSeparateXYZ')
    geo = m.n('ShaderNodeNewGeometry')
    m.links.new(geo.outputs['Position'], sep.inputs[0])
    wv = lambda a, b: m.math('ABSOLUTE', m.math('SINE', m.math('ADD', m.math('MULTIPLY', sep.outputs['X'], a), m.math('MULTIPLY', sep.outputs['Z'], b))))
    d1 = m.math('LESS_THAN', wv(30.0, 19.0), 0.016)
    d2 = m.math('LESS_THAN', wv(30.0, -19.0), 0.016)
    lat = m.math('MAXIMUM', d1, d2)
    dots = m.math('MULTIPLY', m.math('LESS_THAN', m.voronoi(26.0, 'F1'), 0.035), 1.0)
    pat = m.math('MAXIMUM', m.math('MULTIPLY', lat, 0.35), m.math('MULTIPLY', dots, 0.0))
    col = m.mix(m.math('MULTIPLY', pat, 0.2), col, (0.36, 0.25, 0.1))
    h = m.math('ADD', m.math('MULTIPLY', sc["disp"], 0.9), m.math('MULTIPLY', pat, 0.4))
    rough = m.math('SUBTRACT', m.math('ADD', m.math('MULTIPLY', sc["rough"], 0.3), 0.7), m.math('MULTIPLY', pat, 0.3))
    glow = m.mix(m.math('MULTIPLY', pat, 1.0), (0.0, 0.0, 0.0), (0.62, 0.42, 0.16))        # the gilt damask is lit from within (it was a black cope in a black hall)
    return m.finish(col, rough, m.math('MULTIPLY', pat, 0.4), h, 0.7, 0.0018, emit=glow, emit_strength=0.45)


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
    return m.finish(col, rough, 0.55, h, 0.5, 0.0016, emit=m.mul(col, (0.8, 0.8, 0.8)), emit_strength=0.3)


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
def wine_mat():
    """The cassock, red wool lit from within by the reliquary candle: the glow is strongest at the breast and fades down the skirt."""
    m = K.Mat("Wine")
    sc = m.scan("caban", 9.0)
    blot = m.noise(5.0, 6.0, 0.6)
    col = m.mul(m.mono(sc["color"]), tuple(c * 2.2 for c in (0.2, 0.03, 0.04)))
    col = m.mix(m.math('MULTIPLY', blot, 0.45), col, (0.02, 0.008, 0.012))
    h = m.math('MULTIPLY', sc["disp"], 1.0)
    fall = m.ramp(m.zpos(), [(0.15, (0.25, 0.25, 0.25)), (0.75, (0.7, 0.7, 0.7)), (1.25, (1.0, 1.0, 1.0))])
    glow = m.mix(fall, (0.0, 0.0, 0.0), (0.95, 0.34, 0.08))
    return m.finish(col, 0.8, 0.0, h, 0.6, 0.002, emit=glow, emit_strength=0.16)      # (0.55 flooded the hooded figure orange in the night)


WINE = wine_mat()


def wool_mat():
    """The cassock (hooded Abbot): black wool gone brown with age, dust rising from the hem (in wine, with the surplice
    and the wine cape over it, he was a tiered pink dress once the cope came off)."""
    m = K.Mat("Wool")
    sc = m.scan("caban", 9.0)
    blot = m.noise(5.0, 6.0, 0.6)
    col = m.mul(m.mono(sc["color"]), (0.075, 0.06, 0.06))
    col = m.mix(m.math('MULTIPLY', blot, 0.4), col, (0.02, 0.016, 0.016))
    dust = m.ramp(m.zpos(), [(0.0, (0.5, 0.5, 0.5)), (0.35, (0.0, 0.0, 0.0))])
    col = m.mix(dust, col, (0.16, 0.13, 0.1))
    h = m.math('MULTIPLY', sc["disp"], 1.0)
    return m.finish(col, 0.85, 0.0, h, 0.6, 0.002)


WOOL = wool_mat()


def linen_mat():
    """The surplice and the hand bindings: rough linen gone the colour of old candle-smoke, darker toward the hem."""
    m = K.Mat("Linen")
    sc = m.scan("rough_linen", 7.0)
    blot = m.noise(4.0, 6.0, 0.6)
    col = m.mul(m.mono(sc["color"]), (0.86, 0.79, 0.64))
    dirt = m.ramp(m.zpos(), [(0.2, (0.85, 0.85, 0.85)), (0.75, (0.35, 0.35, 0.35)), (1.3, (0.0, 0.0, 0.0))])     # grime rising from the hem
    col = m.mix(dirt, col, (0.27, 0.22, 0.16))
    col = m.mix(m.math('MULTIPLY', blot, 0.35), col, (0.22, 0.17, 0.11))
    h = m.math('MULTIPLY', sc["disp"], 1.2)
    fall = m.ramp(m.zpos(), [(0.9, (0.0, 0.0, 0.0)), (1.3, (0.5, 0.5, 0.5)), (1.5, (0.8, 0.8, 0.8))])
    glow = m.mix(fall, (0.0, 0.0, 0.0), (0.9, 0.42, 0.12))          # the reliquary's candle on the breast
    return m.finish(col, 0.85, 0.0, h, 0.7, 0.0022, emit=glow, emit_strength=0.1)


def void_mat():
    """The dark inside the cowl: no face, only shadow (the eyes burn in it)."""
    m = K.Mat("Void")
    return m.finish((0.006, 0.004, 0.004), 0.95, 0.0, None)


def rope_mat():
    m = K.Mat("Rope")
    v = m.noise(60.0, 5.0, 0.6)
    col = m.ramp(v, [(0.3, (0.16, 0.11, 0.07)), (0.8, (0.36, 0.27, 0.17))])
    return m.finish(col, 0.9, 0.0, v, 0.8, 0.0025)


LINEN = linen_mat()
VOID = void_mat()
ROPE = rope_mat()
GOLD = gilt()
WAX = wax_mat()
FLAME = glow_mat("Flame", (1.0, 0.62, 0.22), 8.0)
EYE = glow_mat("Eye", (1.0, 0.66, 0.25), 8.0)
SINEW = sinew_mat()
MATS = [BONE, SHADE, CLOTH, WINE, WOOL, LINEN, VOID, ROPE, GOLD, WAX, FLAME, EYE, SINEW]
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


bo, bhi = L.sculpted("Legs", sk, "pel", BONE, "bodyskin", 1500, legs_sculpt, 0.0048, False, PAIRS)
add(bo)
SEGS = L.segs()
WEIGHTS["bodyskin"] = GB.envelope_weights([sg for sg in SEGS if sg[0] in ("pelvis", "hip_l", "hip_r", "knee_l", "knee_r", "foot_l", "foot_r")])

HOODED = True              # (17 Nov: the hooded Abbot: the spine and ribcage are under the surplice and the cope, never seen: not built)
CH = lambda p: {"chest": 1.0}
SPW = lambda p: GK.chain_w(p, [("pelvis", G(0, 0.9, 0.0)), ("chest", G(0, 1.1, 0.07)), ("head", G(0, 1.64, -0.01))], [0.07, 0.05])
WEIGHTS["spine"] = SPW
if not HOODED:
    # the spine: seventeen vertebrae with their processes, curving up behind the ribcage and forward into the skull
    SPW = lambda p: GK.chain_w(p, [("pelvis", G(0, 0.9, 0.0)), ("chest", G(0, 1.1, 0.07)), ("head", G(0, 1.64, -0.01))], [0.07, 0.05])
    WEIGHTS["spine"] = SPW
    for k in range(13):
        t = k / 12.0
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
            for k in range(9):
                a = math.pi * (0.04 + 0.86 * k / 8.0)
                fall = 0.055 * (k / 8.0) ** 1.4
                pts.append(G(sx * math.sin(a) * w + sx * 0.02 * (1 - math.cos(a)) * 0.0, y - fall, 0.02 - math.cos(a) * d))
            add(K.loft("Rib", pts, [rr * (0.8 + 0.3 * math.sin(math.pi * k / 10.0)) for k in range(9)], "chest", BONE, 4, squash=(1.0, 0.55), wobble=0.08), CH)
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
        len_ = [0.9, 1.0, 0.95, 0.8][f] * 1.6
        base = G(fx * 0.9 + ax * 0.1, 0.735, -0.012)
        mc = G(fx, 0.665, -0.02)
        pa(K.bone("Metacarpal", base, mc, 0.0085, sock, BONE, 1.7, 7, 5, f))
        p0 = mc
        pts = [mc]
        yy, zz = 0.665, -0.02
        for j, (ln, rr) in enumerate(((0.052, 0.0094), (0.036, 0.008), (0.028, 0.0066))):
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
    fz_ = K.fuse(parts, 0.0028, keep=set(), sculpt=0.0009, sculpt_scale=0.015, decimate=0.055)
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
HCB = Vector(G(0, hy, hz))
# (the hooded Abbot, 17 Nov) the face: a skull half-seen in the cowl's dark, sooted bone set well back from the brim,
# the embers deep in its sockets, two rows of teeth (a flat black disc with two dots read as a mask; Luke: "except
# for the face"). A dark disc behind it keeps the gaps round the skull black, not the hood's lining.
skp = GB.skull_part(OPT, _Y)
so, shi = L.sculpted("Skull", skp, "a", SHADE, "skull", 2200, skull_sculpt, 0.0035, False, PAIRS)
add(so, lambda p: {"head": 1.0})
L.scale_about([so, shi], HCB, 1.15)
SK = 1.15
add(K.blob("FaceVoid", HCB + Vector(G(0, -0.01, 0.07)), (0.19, 0.04, 0.23), "head", VOID, 20, 12), lambda p: {"head": 1.0})
for row, (dy, sgn) in enumerate(((-0.058, -1), (-0.072, 1))):
    for k in range(11):
        a = math.pi * (0.14 + 0.72 * k / 10.0)
        base = HCB + (Vector(G(math.cos(a) * 0.036, hy + dy, hz - 0.052 - math.sin(a) * 0.03)) - HCB) * SK
        add(K.loft("Tooth", [base, base + Vector(G(0, -sgn * 0.022, 0))], [0.0058, 0.0], "head", SHADE, 5, cap0=False), lambda p: {"head": 1.0})
for sx in (-1, 1):
    eye = HCB + (Vector(G(sx * 0.034, hy + 0.012, hz - 0.07)) - HCB) * SK
    add(K.blob("Eye", eye, (0.011, 0.007, 0.0095), "head", EYE, 12, 8), lambda p: {"head": 1.0})

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
hip_w = L.skirt_weights(1.12, 0.92, 0.42, 0.3)
cass = L.Garment([(1.18, 0, 0, 0.14, 0.105, 0.105, 2.2), (1.0, 0, 0, 0.16, 0.125, 0.125, 2.1), (0.78, 0, 0, 0.2, 0.16, 0.17, 2.0),
                  (0.48, 0, 0.01, 0.29, 0.15, 0.17, 2.0), (0.2, 0, 0.02, 0.4, 0.15, 0.17, 2.0), (-0.1, 0, 0.02, 0.52, 0.15, 0.17, 2.0)],
                 top=1.18, hem=0.025, folds=[(12, 0.0, 1.0, 0.3, 0.1), (25, 0.0, 0.7, 1.3, -0.15), (6, 0.4, 0.3, 2.0, 0)], amp=0.07,
                 ramp=(0.0, 0.45), lay=0.07, lay_r=0.07, hem_lift=0.05, micro=0.0016, back_drop=0.05)
lo, hi = L.shell(cass, "Cassock", "cassock", WOOL if HOODED else WINE, 2600, HI)
PAIRS.append((lo, hi))
add(lo, hip_w)
# the two bands of the stole down the front, orphrey bands at the hem and a placket
for nm, (v0, v1, u0, u1) in (("StoleL", (0.02, 0.97, -0.055, -0.018)), ("StoleR", (0.02, 0.97, 0.018, 0.055)), ("HemBand", (0.885, 0.92, 0.0, 1.0))):
    add(L.band(cass, nm, "cassock_trim", GOLD, v0, v1, u0, u1, n=64 if u1 - u0 > 0.5 else 3, m=36 if v1 - v0 > 0.5 else 2, off=0.012), hip_w)
WEIGHTS["cassock_trim"] = hip_w

# the cope (a long outer cloak) is off the hooded Abbot (17 Nov, Luke: "get rid of the cloak if you can't animate it
# properly"): skinned to the chest it hung as a rigid tent, with no cloth sim to swing it. The code stays for the others.
COPE = False
if COPE:
    cope_w = L.cope_weights(0.5)
    cope = L.Garment([(1.64, 0, 0.04, 0.25, 0.12, 0.17, 2.2), (1.56, 0, 0.03, 0.3, 0.14, 0.18, 2.2), (1.44, 0, 0.0, 0.38, 0.18, 0.2, 2.0),
                      (1.1, 0, 0.0, 0.44, 0.24, 0.27, 2.0), (0.7, 0, 0.02, 0.54, 0.21, 0.24, 2.0), (0.3, 0, 0.03, 0.6, 0.2, 0.23, 2.0),
                      (0.0, 0, 0.04, 0.68, 0.2, 0.23, 2.0), (-0.1, 0, 0.04, 0.72, 0.2, 0.23, 2.0)],
                     top=1.64, hem=0.03, folds=[(9, 0.3, 1.0, 0.3, 0.15), (19, 0.0, 0.6, 1.1, -0.2), (4, 0.6, 0.5, 2.0, 0.0)], amp=0.2,
                     ramp=(0.1, 0.5), gap=0.9, gap_from=0.0, lay=0.06, lay_r=0.09, hem_lift=0.06, flare=0.06, micro=0.0014, back_drop=0.1, tongues=(15, 0.09, 1.5), warp=0.8,
                     top_fn=lambda t: -0.06 + 0.1 * ((np.sin(t) + 1.0) * 0.5) ** 1.5)      # a collar now: the cowl is the hood
    lo, hi = L.shell(cope, "Cope", "cope", CLOTH, 3400, HI, solid=0.011)
    PAIRS.append((lo, hi))
    add(lo, cope_w)
    # the orphrey: a broad gilt band down each front edge and round the hem, a morse (clasp) at the throat
    for nm, (v0, v1, u0, u1) in (("OrphL", (0.08, 0.992, 0.0, 0.045)), ("OrphR", (0.08, 0.992, 0.955, 1.0)), ("CopeHem", (0.885, 0.93, 0.0, 1.0))):
        add(L.band(cope, nm, "cope_trim", GOLD, v0, v1, u0, u1, n=3 if u1 - u0 < 0.5 else 80, m=40 if v1 - v0 > 0.5 else 2, off=0.014), cope_w)
    # the pallium: a Y of gilt orphrey down the back (from each shoulder to the nape, then straight to the hem), a ring at the crossing
    add(L.ribbon(cope, "PalliumL", "cope_trim", GOLD, [(0.3, 0.12), (0.4, 0.22), (0.5, 0.34), (0.5, 0.985)], 0.045, 60, 0.014), cope_w)
    add(L.ribbon(cope, "PalliumR", "cope_trim", GOLD, [(0.7, 0.12), (0.6, 0.22), (0.5, 0.34)], 0.045, 30, 0.014), cope_w)
    _pc = Vector(G(*cope.surf(np.array([0.5]), np.array([0.34]))[0][0]))
    add(K.blob("PalliumBoss", _pc + Vector((0, 0.03, 0)), (0.055, 0.02, 0.055), "cope_trim", GOLD, 20, 10), cope_w)
    add(K.blob("PalliumJewel", _pc + Vector((0, 0.045, 0)), (0.02, 0.01, 0.027), "cope_trim", EYE, 12, 8), cope_w)

    # embroidery: a second gilt line inside each orphrey, studs set along it, a worn pattern of crosses on the field
    for nm, (u0, u1) in (("OrphInL", (0.052, 0.058)), ("OrphInR", (0.942, 0.948))):
        add(L.band(cope, nm, "cope_trim", GOLD, 0.1, 0.9, u0, u1, n=2, m=50, off=0.012), cope_w)
    for uu in (0.025, 0.975):
        for vv in np.linspace(0.14, 0.86, 9):
            pp, nn = cope.surf(np.array([uu]), np.array([vv]))
            add(K.blob("Stud", Vector(G(*(pp[0] + nn[0] * 0.02))), (0.011, 0.011, 0.011), "cope_trim", GOLD, 6, 4), cope_w)
    for vv in (0.34, 0.6):
        for uu in np.linspace(0.16, 0.84, 5):
            pp, nn = cope.surf(np.array([uu]), np.array([vv]))
            c0 = Vector(G(*(pp[0] + nn[0] * 0.013)))
            add(TUBE("Cross", [c0 + Vector((0, 0, -0.035)), c0 + Vector((0, 0, 0.035))], 0.0045, "cope_trim", GOLD), cope_w)
            add(TUBE("Cross", [c0 + Vector((-0.025, 0, 0.01)), c0 + Vector((0.025, 0, 0.01))], 0.0045, "cope_trim", GOLD), cope_w)
    # the morse: a gilt plaque on each lapel and a chain looped across the breast between them
    mp = []
    for uu in (0.012, 0.988):
        pp, nn = cope.surf(np.array([uu]), np.array([0.3]))
        q = Vector(G(*(pp[0] + nn[0] * 0.02)))
        mp.append(q)
        add(K.blob("Morse", q, (0.032, 0.014, 0.032), "cope_trim", GOLD, 10, 6), cope_w)
        add(K.blob("MorseGem", q + Vector((0, 0.02, 0)), (0.013, 0.007, 0.017), "cope_trim", EYE, 8, 5), cope_w)
    sag = [mp[0].lerp(mp[1], t) + Vector((0, 0.04 * math.sin(t * math.pi), -0.09 * math.sin(t * math.pi))) for t in [i / 10.0 for i in range(11)]]
    add(TUBE("MorseChain", sag, 0.005, "cope_trim", GOLD), cope_w)
    WEIGHTS["cope_trim"] = cope_w

# --- the hooded Abbot (17 Nov): a deep cowl, a linen surplice over the breast, a dagged shoulder cape ---------------
# the cowl: thick wool, a crown open round the mitre, a brim that hangs a hand's width over the face, so the face is
# the dark inside it; it drapes onto the shoulders under the cape
cowl_w = lambda p: (lambda h: {"head": h, "chest": 1.0 - h} if 0.0 < h < 1.0 else ({"head": 1.0} if h >= 1.0 else {"chest": 1.0}))(GK._smooth(1.5, 1.68, p.z))
cowl = L.Garment([(1.93, 0, 0.0, 0.17, 0.16, 0.16, 2.2), (1.85, 0, -0.045, 0.215, 0.235, 0.19, 2.1), (1.74, 0, -0.055, 0.23, 0.25, 0.2, 2.1),
                  (1.63, 0, -0.03, 0.235, 0.22, 0.21, 2.1), (1.54, 0, 0.0, 0.27, 0.18, 0.22, 2.1), (1.45, 0, 0.01, 0.32, 0.18, 0.23, 2.0),
                  (1.38, 0, 0.015, 0.34, 0.19, 0.24, 2.0)],
                 top=1.93, hem=1.42, folds=[(6, 0.35, 1.0, 0.2, 0.05), (13, 0.15, 0.6, 1.0, 0.0), (3, 0.5, 0.3, 0.4, 0.0)], amp=0.034, ramp=(0.0, 0.5),
                 gap=0.6, gap_from=0.06, lay=0.0, hem_lift=0.02, flare=0.05, micro=0.0014, seed=0.7)
lo, hi = L.shell(cowl, "Cowl", "cowl", CLOTH, 2800, (200, 120) if not LOWRES else (100, 60), solid=0.016)
PAIRS.append((lo, hi))
add(lo, cowl_w)
add(L.band(cowl, "CowlEdge", "cowl", WINE, 0.0, 0.9, 0.0, 0.025, n=2, m=40, off=0.01), cowl_w)
add(L.band(cowl, "CowlEdgeR", "cowl", WINE, 0.0, 0.9, 0.975, 1.0, n=2, m=40, off=0.01), cowl_w)
WEIGHTS["cowl"] = cowl_w
# the hood's inside: a dark lining a little in from the cloth, so the face opening is shadow to its sides, and a
# fold of the same dark wool filling the opening under the chin (the cape's collar showed there like a bib)
for (u0_, u1_) in ((0.0, 0.3), (0.7, 1.0)):       # (round the opening only: across the back it showed through the cope's cracks)
    add(cowl.mesh("CowlLining", 14, 18, "cowl", VOID, v0=0.0, v1=0.7, u0=u0_, u1=u1_, off=-0.013), cowl_w)
# the liripipe: the hood's tail drawn down the back over the cape to the small of the back, a gilt tassel at its point
# (without the cope the hood's back was a flat box sat on the cape)
_lp = [Vector(G(0, y, z)) for (y, z) in ((1.6, 0.215), (1.5, 0.25), (1.39, 0.275), (1.29, 0.275), (1.17, 0.215), (1.04, 0.195), (0.92, 0.2))]
add(K.loft("Liripipe", _lp, [(0.15, 0.024), (0.14, 0.024), (0.12, 0.022), (0.095, 0.02), (0.06, 0.017), (0.03, 0.013), (0.008, 0.008)], "cowl", CLOTH, 14), CH)
add(K.loft("LiripipeTassel", [_lp[-1], _lp[-1] + Vector(G(0, -0.09, 0.005))], [0.012, 0.022], "cowl", GOLD, 8), CH)

# the surplice: off-white linen from the breast to the thigh, a scalloped lace hem, over the cassock and under the cope
surp_w = L.skirt_weights(1.05, 0.9, 0.42, 0.25)
surp = L.Garment([(1.5, 0, 0.0, 0.19, 0.14, 0.13, 2.2), (1.36, 0, 0.0, 0.21, 0.16, 0.14, 2.2), (1.18, 0, 0.0, 0.2, 0.15, 0.14, 2.1),
                  (1.0, 0, 0.005, 0.24, 0.17, 0.17, 2.0), (0.8, 0, 0.01, 0.31, 0.2, 0.2, 2.0), (0.55, 0, 0.012, 0.37, 0.22, 0.22, 2.0),
                  (0.45, 0, 0.012, 0.39, 0.23, 0.23, 2.0)],
                 top=1.5, hem=0.52, folds=[(14, 0.1, 1.0, 0.4, 0.05), (29, 0.0, 0.5, 1.2, -0.1)], amp=0.03, ramp=(0.2, 0.7),
                 lay=0.0, hem_lift=0.02, micro=0.0012, tongues=(24, 0.03, 2.0), seed=1.3)
lo, hi = L.shell(surp, "Surplice", "surplice", LINEN, 1500, (220, 130) if not LOWRES else (110, 66), solid=0.006)
PAIRS.append((lo, hi))
add(lo, surp_w)
add(L.band(surp, "SurpLace", "surplice", LINEN, 0.9, 0.97, 0.0, 1.0, n=96, m=2, off=0.01), surp_w)
# a wine band embroidered above the lace, edged in a thread of gilt (the linen was a plain field below the cape)
add(L.band(surp, "SurpBand", "surplice", WINE, 0.83, 0.87, 0.0, 1.0, n=96, m=2, off=0.009), surp_w)
add(L.band(surp, "SurpThread", "surplice", GOLD, 0.875, 0.882, 0.0, 1.0, n=96, m=2, off=0.0095), surp_w)
WEIGHTS["surplice"] = surp_w

# the cape over the shoulders (a mozzetta): wine wool, cut in dags at the hem, a gilt band above them; it gives the
# figure shoulders (the cope alone was a tent) and hides where the cowl meets the cope
moz_w = L.cope_weights(0.6)
moz = L.Garment([(1.6, 0, 0.02, 0.22, 0.14, 0.15, 2.3), (1.53, 0, 0.01, 0.3, 0.17, 0.19, 2.2), (1.46, 0, 0.0, 0.36, 0.2, 0.22, 2.1),
                 (1.38, 0, 0.0, 0.385, 0.21, 0.23, 2.0), (1.3, 0, 0.0, 0.395, 0.215, 0.235, 2.0)],
                top=1.6, hem=1.35, folds=[(8, 0.2, 1.0, 0.6, 0.1), (16, 0.0, 0.5, 1.3, 0.0)], amp=0.025, ramp=(0.1, 0.6),
                lay=0.0, hem_lift=0.012, micro=0.0012, tongues=(16, 0.045, 2.4), seed=2.1,      # (to the upper arm: wider and longer was a lampshade)
                top_fn=lambda t: -0.1 * np.clip(-np.sin(t), 0.0, 1.0) ** 3)     # the neckline drops in front, under the cowl's dark (its collar rose into the face)
lo, hi = L.shell(moz, "Mozzetta", "mozzetta", WINE, 1300, (220, 80) if not LOWRES else (110, 40), solid=0.012)
PAIRS.append((lo, hi))
add(lo, moz_w)
add(L.band(moz, "MozBand", "mozzetta", GOLD, 0.62, 0.7, 0.0, 1.0, n=120, m=2, off=0.014), moz_w)
for uu in np.linspace(0.0, 1.0, 19)[:-1]:
    pp, nn = moz.surf(np.array([uu]), np.array([0.66]))
    add(K.blob("MozStud", Vector(G(*(pp[0] + nn[0] * 0.02))), (0.009, 0.009, 0.009), "mozzetta", GOLD, 6, 4), moz_w)
WEIGHTS["mozzetta"] = moz_w

# candles burning on both shoulders, stuck on in their own wax (the Abbot keeps vigil for the counted dead)
CANDLES = [(-0.31, 0.0, 0.1), (-0.3, 0.07, 0.16), (-0.34, -0.05, 0.07), (0.31, 0.0, 0.12), (0.3, 0.07, 0.08), (0.34, -0.05, 0.15)]   # (outside the cowl: at 0.22 one stood in the face opening)
for (cx_, cz_, ch) in CANDLES:
    sx = -1 if cx_ < 0 else 1
    pp, nn = moz.surf(np.array([0.25 if sx < 0 else 0.75]), np.array([0.12]))
    top_y = 1.535 - max(0.0, abs(cx_) - 0.3) / 0.06 * 0.07          # down the cape's shoulder slope (1.53 at 0.3 out, 1.46 at 0.36)
    b0 = Vector(G(cx_, top_y, cz_))
    add(K.blob("WaxPool", b0 + Vector(G(0, -0.004, 0)), (0.034, 0.012, 0.03), "chest", WAX, 12, 6), CH)
    add(K.loft("Candle", [b0, b0 + Vector(G(0, ch, 0))], [0.017, 0.015], "chest", WAX, 10), CH)
    for k in range(3):
        a = k * 2.1 + cx_ * 7.0
        d0 = b0 + Vector(G(math.cos(a) * 0.016, ch * (0.6 + 0.12 * k), math.sin(a) * 0.016))
        add(K.loft("Drip", [d0, d0 + Vector(G(math.cos(a) * 0.003, -ch * (0.3 + 0.1 * k), math.sin(a) * 0.003))], [0.006, 0.004], "chest", WAX, 5), CH)
    add(K.blob("Flame", b0 + Vector(G(0, ch + 0.026, 0)), (0.008, 0.008, 0.02), "chest", FLAME, 10, 6), CH)

# the cincture: a rope round the waist over the surplice, knotted in front with the ends hanging, and on it what the
# Abbot carries: a rosary of small skulls (left), tally bones on cords, a chained book of the count (right)
CW = surp_w
ring = []
for k in range(41):
    a = math.tau * k / 40.0
    pp, nn = surp.surf(np.array([(k / 40.0) % 1.0]), np.array([0.36]))
    ring.append(Vector(G(*(pp[0] + nn[0] * 0.016))))
add(TUBE("Cincture", ring, 0.011, "cincture", ROPE), CW)
kn = ring[0]
add(K.blob("Knot", kn + Vector(G(0, 0, -0.01)), (0.026, 0.022, 0.02), "cincture", ROPE, 12, 8), CW)
for sx in (-1, 1):
    end = [kn + Vector(G(sx * 0.01 * t, -0.42 * t, -0.012 - 0.01 * math.sin(t * 3.0))) for t in [i / 8.0 for i in range(9)]]
    add(TUBE("CinctureEnd", end, 0.009, "cincture", ROPE), CW)
    add(K.loft("Tassel", [end[-1], end[-1] + Vector(G(0, -0.06, 0))], [0.012, 0.02], "cincture", ROPE, 8), CW)
# the skull rosary on the left hip
rp = surp.surf(np.array([0.62]), np.array([0.36]))[0][0]
r0 = Vector(G(*rp))
beads = [r0 + Vector(G(0.03 * math.sin(t * 3.1), -0.36 * t, -0.04 * math.sin(t * math.pi))) for t in [i / 13.0 for i in range(14)]]
add(TUBE("RosaryCord", beads, 0.003, "cincture", ROPE), CW)
for k, b in enumerate(beads[1:]):
    big = k % 4 == 3
    add(K.blob("RosarySkull" if big else "RosaryBead", b, (0.018, 0.02, 0.017) if big else (0.009, 0.009, 0.009), "cincture", BONE, 10, 6), CW)
# tally bones (the count of the dead, knotted on) at the right hip
for k in range(5):
    tp = surp.surf(np.array([0.36 + 0.025 * k]), np.array([0.37]))[0][0]
    t0 = Vector(G(*tp))
    t1 = t0 + Vector(G(0.0, -0.1 - 0.03 * (k % 3), -0.02))
    add(TUBE("TallyCord", [t0, t1], 0.0025, "cincture", ROPE), CW)
    add(K.bone("TallyBone", t1, t1 + Vector(G(0.006, -0.09, -0.004)), 0.007, "cincture", BONE, 1.6, 6, 6, k), CW)
# the book of the count, chained at the right side
bp = Vector(G(*surp.surf(np.array([0.3]), np.array([0.5]))[0][0])) + Vector(G(0.06, 0, -0.02))
book = K.blob("Book", bp, (0.07, 0.095, 0.03), "cincture", WINE, 6, 4)
add(book, CW)
for cx_ in (-1, 1):
    for cy_ in (-1, 1):
        add(K.blob("BookCorner", bp + Vector(G(cx_ * 0.062, cy_ * 0.085, -0.028)), (0.014, 0.014, 0.008), "cincture", GOLD, 6, 4), CW)
add(TUBE("BookChain", [ring[8], ring[8].lerp(bp, 0.5) + Vector(G(0, -0.03, -0.02)), bp + Vector(G(0, 0.09, 0))], 0.004, "cincture", GOLD), CW)
WEIGHTS["cincture"] = CW


for tag, sx in (("l", -1), ("r", 1)):
    # long bell sleeves to below the wrist: only the bound fingers come out of them (the hooded Abbot shows no bone)
    sl = L.Garment([(1.47, sx * 0.23, 0, 0.082, 0.077, 0.077, 2.2), (1.3, sx * 0.24, 0, 0.085, 0.082, 0.082, 2.2), (1.1, sx * 0.245, 0, 0.1, 0.098, 0.098, 2.2),
                    (0.95, sx * 0.258, 0.008, 0.15, 0.145, 0.145, 2.0), (0.82, sx * 0.268, 0.014, 0.2, 0.19, 0.19, 2.0), (0.74, sx * 0.272, 0.016, 0.22, 0.21, 0.21, 2.0)],
                   top=1.47, hem=0.8, folds=[(8, 0.0, 1.0, 0.5, 0.1), (17, 0, 0.6, 1.5, 0)], amp=0.05, ramp=(0.2, 0.7), lay=0.0, hem_lift=0.03, seed=sx,
                   micro=0.0013, back_drop=0.06, tongues=(9, 0.025, 2.0))
    lo, hi = L.shell(sl, "Sleeve" + tag, "sleeve_" + tag, WINE, 1200, (140, 100) if not LOWRES else (80, 60))
    PAIRS.append((lo, hi))
    add(lo, L.sleeve_weights(tag))
    add(L.band(sl, "Cuff" + tag, "sleeve_" + tag + "_t", GOLD, 0.86, 0.93, 0.0, 1.0, n=60, m=3, off=0.012), L.sleeve_weights(tag))
    WEIGHTS["sleeve_" + tag + "_t"] = L.sleeve_weights(tag)
    # linen strips wound round the wrist and the back of the hand, loose ends hanging: the fingers are bone, nothing else is
    ax = sx * 0.24
    for k in range(3):
        wrap = []
        for j in range(19):
            a = math.tau * 1.6 * j / 18.0 + k * 2.0
            wrap.append(Vector(G(ax + math.cos(a) * 0.034, 0.79 - 0.05 * j / 18.0 - 0.012 * k, -0.008 + math.sin(a) * 0.03)))
        add(TUBE("Binding", wrap, 0.0065, "arm_" + tag, LINEN), ARMW["arm_" + tag])
    add(K.loft("BindingEnd", [Vector(G(ax + sx * 0.03, 0.74, -0.02)), Vector(G(ax + sx * 0.04, 0.66, -0.03)), Vector(G(ax + sx * 0.038, 0.6, -0.022))],
               [(0.012, 0.003), (0.011, 0.003), (0.008, 0.002)], "arm_" + tag, LINEN, 6), ARMW["arm_" + tag])

# --- the bone crown (17 Nov, hooded): a gilt circlet round the cowl above the brow, and from it a fan of curved rib
# tines, tallest over the face, falling away to the sides (the tall pale mitre on a dark hood read as a dunce's cap) -----
def _cowl_ring(y, out, a0, a1, n):
    """Points round the cowl at height y, `out` off its surface, from angle a0 to a1 (0 = the face, + = the left)."""
    keys = [(1.93, 0.0, 0.17, 0.16, 0.16), (1.85, -0.045, 0.215, 0.235, 0.19), (1.74, -0.055, 0.23, 0.25, 0.2)]
    for (y0, cz0, ax0, f0, b0), (y1, cz1, ax1, f1, b1) in zip(keys, keys[1:]):
        if y1 <= y <= y0:
            t = (y0 - y) / (y0 - y1)
            cz, ax, f, b = cz0 + (cz1 - cz0) * t, ax0 + (ax1 - ax0) * t, f0 + (f1 - f0) * t, b0 + (b1 - b0) * t
            break
    pts = []
    for k in range(n):
        a = a0 + (a1 - a0) * k / max(1, n - 1)
        c, s = math.cos(a), math.sin(a)
        d = f if c > 0 else b
        pts.append((s * (ax + out), y, cz - c * (d + out), a))
    return pts


CROWN_Y = 1.872
crown = [Vector(G(x, y, z)) for (x, y, z, _a) in _cowl_ring(CROWN_Y, 0.012, -math.pi, math.pi, 49)]
add(TUBE("CrownBand", crown, 0.014, "head", GOLD), lambda p: {"head": 1.0})
crown2 = [Vector(G(x, y, z)) for (x, y, z, _a) in _cowl_ring(CROWN_Y + 0.03, 0.008, -math.pi, math.pi, 49)]
add(TUBE("CrownBand2", crown2, 0.006, "head", GOLD), lambda p: {"head": 1.0})
for k, (x, y, z, a) in enumerate(_cowl_ring(CROWN_Y + 0.012, 0.02, -1.9, 1.9, 11)):
    h = 0.07 + 0.2 * math.cos(a / 1.9 * math.pi * 0.5) ** 1.6       # 0.27 over the face, 0.07 at the ears
    ox, oz = math.sin(a), -math.cos(a)                              # outward on the plan
    pts = []
    for j in range(7):
        t = j / 6.0
        lean = 0.05 * h / 0.27 * math.sin(t * math.pi * 0.85)       # bowed out, the tips turned a little back in
        pts.append(Vector(G(x + ox * lean, y + h * t, z + oz * lean)))
    add(K.loft("CrownTine", pts, [0.015, 0.013, 0.011, 0.009, 0.0068, 0.0045, 0.0018], "head", BONE, 8, seed=k), lambda p: {"head": 1.0})
    add(K.blob("CrownKnuckle", pts[0] + Vector(G(0, 0.004, 0)), (0.017, 0.017, 0.015), "head", BONE, 10, 6), lambda p: {"head": 1.0})
_jf = _cowl_ring(CROWN_Y + 0.016, 0.03, 0.0, 0.0, 1)[0]
add(K.blob("CrownJewel", Vector(G(_jf[0], _jf[1], _jf[2])), (0.019, 0.009, 0.024), "head", EYE, 12, 8), lambda p: {"head": 1.0})

# --- the mitre: a tall ogee of bone, a gilt circlet and orphreys, a jewel, lappets down the back (not on the hooded Abbot)
BASE_Y = 1.85             # (17 Nov: out of the cowl's crown: at 1.725 its circlet sat across the face opening like a visor)
MH = 0.58
plates = []


def mitre_plate(sgn):
    """A peaked shield, bowed out, with an ogee outline: the front and the back plate of the mitre."""
    nv, nu = 14, 10
    P = np.zeros((nv + 1, nu + 1, 3))
    for i in range(nv + 1):
        v = i / nv
        w = 0.15 * (1.0 - v ** 1.6) ** 1.3 * (1.0 + 0.12 * math.sin(v * math.pi)) + 0.003
        for j in range(nu + 1):
            u = -1.0 + 2.0 * j / nu
            bow = 0.032 * (1.0 - u * u) * (1.0 - v) ** 0.8
            P[i, j] = (u * w, BASE_Y + v * MH, -0.03 + sgn * (0.07 - 0.03 * v + bow))
    return P


for sg, nm in ((-1, "MitreFront"), (1, "MitreBack")) if not HOODED else ():
    pl = L.grid_mesh(nm, mitre_plate(sg), False, "head", BONE)
    K.solidify(pl, 0.008)
    add(pl, lambda p: {"head": 1.0})
    # orphrey: gilt edging down both slopes, a central band and a cross-band
    for sx in (-1, 1):
        pts = []
        for i in range(0, 19):
            v = i / 18.0
            w = 0.15 * (1.0 - v ** 1.6) ** 1.3 * (1.0 + 0.12 * math.sin(v * math.pi)) + 0.003
            pts.append(Vector(G(sx * w, BASE_Y + v * MH, -0.03 + sg * (0.07 - 0.03 * v + 0.012))))
        add(TUBE("MitreEdge", pts, 0.0065, "head", GOLD), lambda p: {"head": 1.0})
    add(TUBE("MitreSpine", [Vector(G(0, BASE_Y + v * MH * 0.92, -0.03 + sg * (0.07 - 0.03 * v + 0.044 * (1 - v) ** 0.8 + 0.01))) for v in [i / 10.0 for i in range(11)]], 0.009, "head", GOLD), lambda p: {"head": 1.0})
    add(TUBE("MitreCross", [Vector(G(x, BASE_Y + 0.26, -0.03 + sg * (0.07 - 0.03 * 0.45 + 0.025 * (1 - (x / 0.07) ** 2) * 0.6 + 0.012))) for x in np.linspace(-0.07, 0.07, 7)], 0.008, "head", GOLD), lambda p: {"head": 1.0})
# the cleft between the plates is closed low down by a fold of lining at each side
for sx in (-1, 1) if not HOODED else ():
    add(K.loft("MitreFold", [Vector(G(sx * 0.152, BASE_Y, -0.03)), Vector(G(sx * 0.135, BASE_Y + 0.07, -0.03)), Vector(G(sx * 0.1, BASE_Y + 0.13, -0.03))], [(0.01, 0.075), (0.008, 0.05), (0.004, 0.02)], "head", WINE, 6), lambda p: {"head": 1.0})
MB = Vector(G(0, BASE_Y, -0.03))
circ = [MB + Vector((math.cos(a) * 0.168, math.sin(a) * 0.098, 0.006)) for a in [math.tau * i / 36 for i in range(37)]]
if not HOODED:
    add(TUBE("Circlet", circ, 0.0125, "head", GOLD), lambda p: {"head": 1.0})
circ2 = [MB + Vector((math.cos(a) * 0.165, math.sin(a) * 0.095, 0.05)) for a in [math.tau * i / 36 for i in range(37)]]
if not HOODED:
    add(TUBE("Circlet2", circ2, 0.005, "head", GOLD), lambda p: {"head": 1.0})
if not HOODED:
    add(K.blob("Jewel", MB + Vector((0, 0.1, 0.13)), (0.02, 0.007, 0.028), "head", EYE, 12, 8), lambda p: {"head": 1.0})
if not HOODED:
    add(K.blob("Jewel", MB + Vector((0, -0.1, 0.13)), (0.02, 0.007, 0.028), "head", EYE, 12, 8), lambda p: {"head": 1.0})
for sg in (-1, 1) if not HOODED else ():
    add(K.blob("Finial", Vector(G(0, BASE_Y + MH + 0.01, -0.03 + sg * 0.04)), (0.012, 0.012, 0.02), "head", GOLD, 10, 6), lambda p: {"head": 1.0})
for sx in (-1, 1) if not HOODED else ():          # (no lappets: risen out of the cowl, they hung in the face)
    pts = [MB + Vector((sx * 0.05, -0.07, 0.0)) + Vector((sx * 0.06 * t, -0.03 * t, -0.52 * t)) + Vector((0, -0.012 * math.sin(t * 6.0), 0)) for t in [i / 10.0 for i in range(11)]]
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
fz = K.fuse(cro, 0.006, keep={"Gold", "Flame"}, sculpt=0.0008, sculpt_scale=0.02, decimate=0.09)
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
