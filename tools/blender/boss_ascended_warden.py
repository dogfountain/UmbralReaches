"""The Ascended Warden: the last priest, floating over the dais in a bell robe of pale linen (no legs), a veil
and mantle of draped cloth, a sculpted white-gold mask with slit eyes and a hairline crack, long open ashen
hands in gilt bracers, and a halo that is a wrought, three-dimensional thorned crown-wheel (a rim of rope-twisted
gold, a lit inner ring on spokes, alternating thorns forward and back, a second ring set across the first, a
circlet on the brow bracketed to it). ONE skinned mesh on the rig's sockets (GruntModel poses it). The cloth is
draped geometry (boss_sculpt_lib.Garment) skinned to the chest, pelvis and arms.

  tools/blender/run.sh boss_ascended_warden.py -- [--review shots/model_review/ascended_warden] [--no-export] [--lowres]
Writes art/models/boss_ascended_warden.glb and art/textures/boss_ascended_warden_*.png
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
def linen_mat():
    m = K.Mat("Linen")
    sc = m.scan("rough_linen", 7.0)
    weave = sc["disp"]
    blot = m.noise(4.0, 6.0, 0.6)
    col = m.mul(m.mono(sc["color"]), (0.88, 0.84, 0.77))
    col = m.mix(m.math("MULTIPLY", blot, 0.55), col, (0.3, 0.27, 0.22))
    z = m.zpos()
    grime = m.math('SUBTRACT', 1.0, m.math('MULTIPLY', m.math('SUBTRACT', z, 0.25), 1.6), True)
    col = m.mix(m.math("MULTIPLY", grime, 0.6), col, (0.12, 0.1, 0.08))
    h = m.math('MULTIPLY', weave, 0.5)
    rough = m.math('SUBTRACT', 0.92, m.math('MULTIPLY', weave, 0.1))
    return m.finish(col, rough, 0.0, h, 0.5, 0.002)


def gold_mat(name="Gold", base=(0.8, 0.58, 0.24)):
    m = K.Mat(name)
    wear = m.noise(16.0, 6.0, 0.6)
    col = m.ramp(wear, [(0.3, (0.34, 0.22, 0.08)), (0.62, base), (0.9, (0.96, 0.8, 0.46))])
    brick = m.n('ShaderNodeTexBrick')
    brick.inputs['Scale'].default_value = 80.0
    brick.inputs['Mortar Size'].default_value = 0.06
    m.links.new(m.coord.outputs['Object'], brick.inputs['Vector'])
    rough = m.math('ADD', 0.2, m.math('MULTIPLY', m.math('SUBTRACT', 1.0, wear), 0.35))
    h = m.math('ADD', m.noise(110.0, 3.0, 0.5), m.math('MULTIPLY', brick.outputs['Fac'], 0.5))
    return m.finish(col, rough, 0.95, h, 0.4, 0.0018)


def mask_mat():
    m = K.Mat("Mask")
    scr = m.noise(240.0, 2.0, 0.5)
    tone = m.noise(6.0, 4.0, 0.5)
    col = m.ramp(tone, [(0.3, (0.82, 0.72, 0.5)), (0.8, (0.98, 0.92, 0.76))])
    crack = m.math('LESS_THAN', m.voronoi(9.0, 'DISTANCE_TO_EDGE'), 0.01)
    crack = m.math('MULTIPLY', crack, m.math('GREATER_THAN', m.noise(4.0, 2.0, 0.5), 0.58))
    col = m.mix(crack, col, (0.08, 0.05, 0.02))
    h = m.math('ADD', m.math('MULTIPLY', scr, 0.15), m.math('MULTIPLY', crack, -0.8))
    return m.finish(col, m.math('ADD', 0.18, m.math('MULTIPLY', scr, 0.15)), 0.55, h, 0.5, 0.002)


def ash_mat():
    m = K.Mat("Ash")
    sc = m.scan("beige_wall_001", 9.0)
    col = m.mul(m.mono(sc["color"]), (0.6, 0.58, 0.57))
    return m.finish(col, m.math('ADD', m.math('MULTIPLY', sc["rough"], 0.5), 0.35), 0.0, sc["disp"], 0.8, 0.002)


def glow_mat(name, col, strength):
    m = K.Mat(name)
    return m.finish((0.08, 0.07, 0.05), 0.5, 0.0, None, emit=col, emit_strength=strength)


LINEN = linen_mat()
GOLD = gold_mat()
MASK = mask_mat()
ASH = GK.hollow_skin("Ash", (0.42, 0.4, 0.38), (0.12, 0.11, 0.1), wet=0.1, wrinkle=60.0, liv=(0.8, 0.78, 0.85), extremities=0.0)
INNER = glow_mat("Inner", (0.0, 0.0, 0.0), 0.0)
HALO = glow_mat("Halo", (1.0, 0.86, 0.6), 8.0)
EYE = glow_mat("Eye", (1.0, 0.9, 0.7), 8.0)
MATS = [LINEN, GOLD, MASK, ASH, HALO, EYE, INNER]
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


HEAD1 = lambda p: {"head": 1.0}
CHEST1 = lambda p: {"chest": 1.0}

# --- the torso, neck and arms: one fused skin each -------------------------------------------------------
OPT = dict(W=0.85, L=0.78, nk=0.0, finger=0.22, wrist=0.7, ribs=0.0, belly=-0.4, collar=1.2, tendon=1.3, hc=(0, 1.7, -0.02),
           head_w=0.07, neck_r=0.04, nohead=True, hand_r=0.95)
sk_full, SEGS, _Y = GB.humanoid(OPT)
tsk = L.torso_skel(0.85, 0.04, 1.64)


# --- the forearms are carried forward into a gesture (an offering: forearms out, palms turned up), so the hands read
# in silhouette instead of hanging lost in the skirt. The rig's bones stay where they are (sockets are the contract); the
# mesh below each elbow is bent about the elbow socket and skinned wholly to the elbow bone, so every pose keeps the gesture.
PITCH = math.radians(68.0)        # the forearm swings forward from hanging to nearly level
ROLL = math.radians(58.0)         # the palm turns from facing the thigh toward the sky
YAW = math.radians(30.0)          # and the forearms open a little outward


def _sst(e0, e1, x):
    t = min(max((x - e0) / (e1 - e0), 0.0), 1.0)
    return t * t * (3.0 - 2.0 * t)


def bend_rig(p, sx):
    """rig-space point -> its place with the forearm carried forward (blended over the elbow)."""
    ax = sx * 0.24
    d = Vector((p[0] - ax, p[1] - 1.08, p[2]))
    b = _sst(0.07, -0.11, d.y)
    if b <= 0.0:
        return Vector(p)
    r, th, ps = ROLL * b * -sx, PITCH * b, YAW * b * -sx
    x, y, z = d
    x, z = x * math.cos(r) + z * math.sin(r), -x * math.sin(r) + z * math.cos(r)      # roll about the forearm's own (vertical) axis
    y, z = y * math.cos(th) - z * math.sin(th), y * math.sin(th) + z * math.cos(th)   # pitch forward about the elbow
    x, z = x * math.cos(ps) + z * math.sin(ps), -x * math.sin(ps) + z * math.cos(ps)  # yaw outward
    return Vector((ax + x, 1.08 + y, z))


def bend_obj(o, sx):
    """Bend a Blender mesh (rig -> bend -> rig); only the side `sx` (the arm it hangs on)."""
    for v in o.data.vertices:
        q = bend_rig((v.co.x, v.co.z, -v.co.y), sx)
        v.co = Vector(G(q.x, q.y, q.z))
    o.data.update()


def arm_chain_w(tag):
    """Skin weights for anything on an arm: the chest at the shoulder, the shoulder bone to the elbow, everything below
    the elbow (the bent forearm, hand, bracer, cuff) to the elbow bone alone."""
    sx = -1.0 if tag == "l" else 1.0
    wr = bend_rig((sx * 0.24, 0.78, 0.0), sx)
    chain = [("chest", G(sx * 0.12, 1.43, 0)), ("shoulder_" + tag, G(sx * 0.24, 1.40, 0)), ("elbow_" + tag, G(sx * 0.24, 1.08, 0)), ("elbow_" + tag, Vector(G(wr.x, wr.y, wr.z)))]
    return lambda p: GK.chain_w(p, chain, [0.04, 0.06, 0.05])



def torso_sculpt(s):
    for sx in (-1, 1):
        s.ridge((sx * 0.02, 1.47, -0.075), (sx * 0.2, 1.455, -0.03), 0.011, 0.01, facing=(0, 0.3, -1))     # collarbones
        s.bump((sx * 0.055, 1.5, -0.065), 0.03, -0.012, facing=(0, 0.4, -1))
        s.ridge((sx * 0.03, 1.6, -0.0), (sx * 0.018, 1.47, -0.07), 0.009, 0.007, facing=(sx, 0, -0.6))      # neck cords
    s.noise(26.0, 0.0016)


to, thi = L.sculpted("Torso", tsk, "pel", ASH, "bodyskin", 1800, torso_sculpt, 0.006, False, PAIRS)
add(to)
WEIGHTS["bodyskin"] = GB.envelope_weights([sg for sg in SEGS if sg[0] in ("pelvis", "chest", "head")], 0.07)


def arm_sculpt(s):
    GB.humanoid_sculpt(s, OPT, _Y)


ao, ahi = L.sculpted("Arms", sk_full.arms, ["trpl", "trpr"], ASH, "armskin", 3600, arm_sculpt, 0.0042, False, PAIRS)
for _o in (ao, ahi):                              # both arms in one surface: bend each half about its own elbow
    for v in _o.data.vertices:
        sxv = -1 if v.co.x < 0 else 1
        q = bend_rig((v.co.x, v.co.z, -v.co.y), sxv)
        v.co = Vector(G(q.x, q.y, q.z))
    _o.data.update()
add(ao)
_awl, _awr = arm_chain_w("l"), arm_chain_w("r")
WEIGHTS["armskin"] = lambda p: (_awl if p.x < 0 else _awr)(p)

# --- the head: a sculpted mask of white gold, calm, with slit eyes and a hairline crack ----------------------
mk = GB.Skel()
mk.v("a", (0, 1.7, -0.03), 0.02)
mk.v("b", (0, 1.68, -0.04), 0.02, "a")
mk.mass((0, 1.715, -0.025), (0.088, 0.13, 0.104))
mk.mass((0, 1.665, -0.05), (0.07, 0.085, 0.085))
FZ = -0.025 - 0.104
front = (0, 0, -1)


def mask_sculpt(s):
    ey = 1.735
    for sx in (-1, 1):
        s.bump((sx * 0.036, ey, FZ + 0.012), 0.03, -0.011, facing=front)                 # the hollows round the eyes
        s.ridge((sx * 0.018, ey - 0.002, FZ + 0.004), (sx * 0.058, ey + 0.008, FZ + 0.02), 0.0055, -0.0125, facing=front)   # slit eyes
        s.ridge((sx * 0.016, ey + 0.012, FZ + 0.0), (sx * 0.06, ey + 0.022, FZ + 0.02), 0.007, 0.006, facing=front)        # brow arches
        s.bump((sx * 0.058, ey - 0.04, FZ + 0.03), 0.028, 0.012, facing=(sx * 0.4, 0, -1))                            # cheekbones
        s.bump((sx * 0.07, ey - 0.07, FZ + 0.05), 0.03, -0.006, facing=(sx * 0.6, 0, -1))
    s.ridge((0, ey + 0.03, FZ + 0.004), (0, ey - 0.05, FZ - 0.012), 0.011, 0.014, facing=front)    # nose bridge
    s.bump((0, ey - 0.052, FZ - 0.012), 0.013, 0.008, facing=front)                               # tip
    s.bump((0, ey + 0.04, FZ + 0.01), 0.04, 0.007, facing=front)                                   # brow
    s.ridge((-0.028, ey - 0.095, FZ + 0.005), (0.028, ey - 0.095, FZ + 0.005), 0.0065, -0.0085, facing=front)   # the closed mouth
    s.bump((0, ey - 0.083, FZ + 0.0), 0.016, 0.006, facing=front)
    s.bump((0, ey - 0.108, FZ + 0.012), 0.02, 0.01, facing=front)                                 # chin
    # a hairline crack from the crown across the left brow into the cheek
    pts = [(0.012, ey + 0.1), (0.004, ey + 0.07), (0.022, ey + 0.045), (0.03, ey + 0.015), (0.044, ey - 0.012), (0.04, ey - 0.04)]
    for a_, b_ in zip(pts, pts[1:]):
        s.ridge((a_[0], a_[1], FZ + 0.01), (b_[0], b_[1], FZ + 0.012), 0.0022, -0.0045, facing=front)
    s.noise(60.0, 0.0006)


mo, mhi = L.sculpted("Mask", mk, "a", MASK, "head", 2800, mask_sculpt, 0.0035, False, PAIRS)
add(mo, HEAD1)
for sx in (-1, 1):
    add(K.blob("Slit", Vector(G(sx * 0.039, 1.739, FZ + 0.012)), (0.015, 0.004, 0.0035), "head", EYE, 10, 6), HEAD1)
    mo_ = Vector(G(sx * 0.039, 1.739, FZ + 0.012))

# --- the halo: a wrought, three-dimensional thorned crown-wheel -----------------------------------------------
HC = Vector(G(0, 1.78, 0.2))                       # (the weak point sits here: behind the mask)
R_OUT, R_IN = 0.36, 0.25


def ring_pts(c, r, n, plane="xz", tilt=0.0, phase=0.0):
    out = []
    for i in range(n + 1):
        a = math.tau * i / n + phase
        v = Vector((math.cos(a) * r, 0.0, math.sin(a) * r))
        if tilt:
            from mathutils import Matrix
            v = Matrix.Rotation(tilt, 3, 'Z') @ v
        out.append(c + v)
    return out


add(TUBE("Rim", ring_pts(HC, R_OUT, 40), 0.017, "head", GOLD), HEAD1)
# a rope of wire twisted round the rim
rope = []
for i in range(0, 97):
    a = math.tau * i / 96.0
    rad = Vector((math.cos(a), 0.0, math.sin(a)))
    off = rad * (0.017 * math.cos(a * 30.0)) + Vector((0, 1, 0)) * (0.017 * math.sin(a * 30.0))
    rope.append(HC + rad * R_OUT + off)
add(TUBE("Rope", rope, 0.0052, "head", GOLD), HEAD1)
add(TUBE("Inner", ring_pts(HC, R_IN, 32), 0.011, "head", HALO), HEAD1)
add(TUBE("InnerEdge", ring_pts(HC, R_IN * 0.62, 28), 0.006, "head", GOLD), HEAD1)
for k in range(8):                                    # spokes: curved from the inner ring to the rim, alternating to the two faces
    a = math.tau * k / 8.0
    d = Vector((math.cos(a), 0.0, math.sin(a)))
    sgn = 1 if k % 2 == 0 else -1
    pts = [HC + d * R_IN * 0.62, HC + d * (R_IN * 0.8) + Vector((0, 0.02 * sgn, 0)), HC + d * (R_IN * 1.05), HC + d * (R_OUT - 0.01)]
    add(TUBE("Spoke", pts, 0.0065, "head", GOLD), HEAD1)
for k in range(10):                                    # lit beads along the inner ring
    a = math.tau * (k + 0.5) / 10.0
    add(K.blob("Bead", HC + Vector((math.cos(a) * R_IN, 0.0, math.sin(a) * R_IN)), (0.017, 0.017, 0.017), "head", HALO, 10, 6), HEAD1)
for k in range(20):                                    # thorns round the rim, long and short, leaning forward and back alternately
    a = math.tau * (k + 0.25) / 20.0
    d = Vector((math.cos(a), 0.0, math.sin(a)))
    ln = 0.24 if k % 2 == 0 else 0.12
    sgn = 1 if (k // 2) % 2 == 0 else -1
    add(L.thorn("Thorn", HC + d * (R_OUT + 0.012), d, ln, 0.026 if k % 2 == 0 else 0.019, Vector((0, 0.09 * sgn, 0)) + d * 0.0, "head", GOLD, 4, 6, 0.5), HEAD1)
    if k % 2 == 0:
        add(K.blob("Boss", HC + d * (R_OUT + 0.004), (0.026, 0.026, 0.026), "head", GOLD, 10, 6), HEAD1)
for k in range(10):                                    # shorter thorns point inward from the rim
    a = math.tau * (k + 0.75) / 10.0
    d = Vector((math.cos(a), 0.0, math.sin(a)))
    add(L.thorn("InThorn", HC + d * (R_OUT - 0.012), -d, 0.075, 0.014, Vector((0, 0.03 * (1 if k % 2 else -1), 0)), "head", GOLD, 4, 5, 0.5), HEAD1)
# a second ring set across the first, tilted, with its own small thorns: the wheel has depth from every side
for tilt, rr in ((math.radians(32), 0.3),):
    pts = ring_pts(HC, rr, 32, tilt=tilt)
    add(TUBE("Ring2", pts, 0.011, "head", GOLD), HEAD1)
    for k in range(8):
        a = math.tau * k / 8.0 + 0.2
        from mathutils import Matrix
        d = Matrix.Rotation(tilt, 3, 'Z') @ Vector((math.cos(a), 0.0, math.sin(a)))
        add(L.thorn("Thorn2", HC + d * (rr + 0.006), d, 0.075, 0.015, Vector((0, 0.04, 0)), "head", HALO, 4, 5, 0.5), HEAD1)
# the circlet on the brow, five up-curving prongs, bracketed back to the wheel by struts
CC = Vector(G(0, 1.83, -0.025))
add(TUBE("Circlet", [CC + Vector((math.cos(a) * 0.102, math.sin(a) * 0.095, 0.0)) for a in [math.tau * i / 28 for i in range(29)]], 0.0085, "head", GOLD), HEAD1)
for k in range(5):
    a = math.pi * (0.2 + 0.6 * k / 4.0)
    base = CC + Vector((math.cos(a) * 0.1, -math.sin(a) * 0.095 * 0 + math.sin(a) * 0.095, 0))
    add(L.thorn("Prong", base, Vector((0, 0, 1)), 0.1 if k == 2 else 0.065, 0.014, Vector((math.cos(a) * 0.02, 0, 0)), "head", GOLD, 4, 5, 0.6), HEAD1)
add(K.blob("Jewel", CC + Vector((0, 0.1, 0.015)), (0.013, 0.006, 0.02), "head", HALO, 10, 6), HEAD1)
for sx in (-1, 1):
    pts = [CC + Vector((sx * 0.09, -0.06, 0.0)), CC + Vector((sx * 0.14, -0.16, 0.0)), HC + Vector((sx * 0.2, 0.0, -0.24)), HC + Vector((sx * R_OUT * 0.93, 0.0, -0.08))]
    add(TUBE("Strut", pts, 0.009, "head", GOLD), HEAD1)
pts = [CC + Vector((0, -0.095, 0.0)), CC + Vector((0, -0.14, 0.04)), HC + Vector((0, 0.0, -R_OUT * 0.9))]
add(TUBE("Strut", pts, 0.009, "head", GOLD), HEAD1)

# --- the pectoral: a gilt sun with an eye, on the breast ------------------------------------------------------
PC = G(0, 1.34, -0.135)
add(K.blob("Pectoral", PC, (0.075, 0.012, 0.075), "chest", GOLD, 24, 10), CHEST1)
add(TUBE("PectoralRim", [PC + Vector((math.cos(a) * 0.072, 0.008, math.sin(a) * 0.072)) for a in [math.tau * i / 28 for i in range(29)]], 0.006, "chest", GOLD), CHEST1)
add(K.blob("PectoralEye", PC + Vector((0, 0.012, 0)), (0.02, 0.008, 0.02), "chest", EYE, 12, 8), CHEST1)
for k in range(12):
    a = math.tau * k / 12.0
    d = Vector((math.cos(a), 0, math.sin(a)))
    add(L.thorn("Ray", PC + d * 0.07 + Vector((0, 0.006, 0)), d, 0.05 if k % 2 == 0 else 0.03, 0.01, Vector((0, 0.01, 0)), "chest", GOLD, 4, 4, 0.5), CHEST1)

# --- the cloth ------------------------------------------------------------------------------------------------
robe_w = lambda p: {"chest": GK._smooth(0.98, 1.3, p.z), "pelvis": 1.0 - GK._smooth(0.98, 1.3, p.z)}


def veil_w(p):
    h = GK._smooth(1.45, 1.72, p.z)
    return {"head": h * 0.9, "chest": 1.0 - h * 0.9}


def mantle_w(p):
    w = {"chest": 1.0}
    for tag, sx in (("l", -1.0), ("r", 1.0)):
        a = GK._smooth(0.14, 0.34, p.x * sx) * 0.55 * GK._smooth(0.95, 1.35, p.z)
        if a > 0:
            w["shoulder_" + tag] = a
    lo = GK._smooth(1.15, 0.8, p.z) * 0.5
    if lo > 0:
        w["pelvis"] = lo
    h = GK._smooth(1.52, 1.64, p.z) * 0.6
    if h > 0:
        w["head"] = h
    w["chest"] = max(1.0 - sum(v for k, v in w.items() if k != "chest") * 0.6, 0.2)
    t = sum(w.values())
    return {k: v / t for k, v in w.items()}


def ragged(base, depth):
    """A tattered hem: a slow swell, a finer one, and sparse long tatters hanging lower (no regular fringe)."""
    def fn(t):
        h = base + 0.05 * np.sin(5 * t + 0.4) + 0.03 * np.sin(13 * t + 1.1)
        tat = np.clip(np.sin(9 * t + 0.2) + np.sin(23 * t + 2.0) + np.sin(37 * t) - 1.3, 0.0, None)
        return h - depth * tat
    return fn


# a tall bell: narrow through the shoulders, then a full heavy skirt that sweeps out and trails behind the hands
rk = [(1.52, 0, 0.0, 0.17, 0.12, 0.12, 2.2), (1.34, 0, 0.03, 0.25, 0.15, 0.19, 2.1), (1.1, 0, 0.12, 0.34, 0.17, 0.32, 2.0), (0.85, 0, 0.24, 0.46, 0.17, 0.46, 2.0),
      (0.55, 0, 0.35, 0.6, 0.22, 0.58, 2.0), (0.25, 0, 0.42, 0.76, 0.3, 0.74, 2.0), (-0.05, 0, 0.45, 0.9, 0.36, 0.86, 2.0), (-0.3, 0, 0.45, 0.98, 0.4, 0.92, 2.0)]
robe = L.Garment(rk, top=1.52, hem=0.18, folds=[(12, 0.2, 1.0, 0.3, 0.12), (27, 0.0, 0.7, 1.4, -0.1), (6, 0.5, 0.4, 2.0, 0)], amp=0.1, ramp=(0.05, 0.5),
                 lay=0.0, micro=0.0016, hem_fn=ragged(0.16, 0.2), warp=0.8)
lo, hi = L.shell(robe, "Robe", "robe", LINEN, 2000, HI, solid=0.007, ratio_floor=0.004)
PAIRS.append((lo, hi))
add(lo, robe_w)
for nm, (v0, v1, u0, u1) in (("RobeBand", (0.02, 0.9, -0.025, 0.025)), ("RobeHem", (0.8, 0.84, 0.0, 1.0)), ("RobeHem2", (0.7, 0.715, 0.0, 1.0))):
    add(L.band(robe, nm, "robe_trim", GOLD, v0, v1, u0, u1, n=3 if u1 - u0 < 0.5 else 90, m=36 if v1 - v0 > 0.5 else 2, off=0.014), robe_w)
WEIGHTS["robe_trim"] = robe_w
# the hollow dark inside the bell, seen from below: a shell just inside the robe, facing in
vk = [(k_[0], k_[1], k_[2], k_[3] * 0.93, k_[4] * 0.93, k_[5] * 0.93, k_[6]) for k_ in rk]
void = L.Garment(vk, top=1.2, hem=0.22, folds=[(12, 0.2, 1.0, 0.3, 0.12)], amp=0.04, ramp=(0.05, 0.5), lay=0.0, hem_fn=ragged(0.2, 0.12))
vo = void.mesh("Void", 36, 18, "robe_void", INNER)
bpy.context.view_layer.objects.active = vo
import bmesh as _bm
_b = _bm.new()
_b.from_mesh(vo.data)
_bm.ops.reverse_faces(_b, faces=_b.faces)
_b.to_mesh(vo.data)
_b.free()
add(vo, robe_w)
WEIGHTS["robe_void"] = robe_w
# a layered tabard of the same linen over the breast and belly, open at the front, banded in gilt
tab = L.Garment([(1.44, 0, 0.0, 0.21, 0.15, 0.15, 2.1), (1.2, 0, 0.1, 0.24, 0.17, 0.24, 2.0), (1.0, 0, 0.16, 0.27, 0.17, 0.3, 2.0), (0.8, 0, 0.22, 0.3, 0.17, 0.36, 2.0)],
                top=1.44, hem=0.86, folds=[(7, 0.3, 1.0, 0.8, 0.1), (15, 0.0, 0.6, 1.9, 0)], amp=0.05, ramp=(0.1, 0.6), gap=0.4, gap_from=0.15, lay=0.0,
                micro=0.0013, hem_fn=ragged(0.86, 0.06))
lo, hi = L.shell(tab, "Tabard", "tabard", LINEN, 950, HI, solid=0.006, ratio_floor=0.004)
PAIRS.append((lo, hi))
add(lo, robe_w)
for nm, (v0, v1, u0, u1) in (("TabL", (0.12, 0.96, 0.0, 0.04)), ("TabR", (0.12, 0.96, 0.96, 1.0))):
    add(L.band(tab, nm, "tab_trim", GOLD, v0, v1, u0, u1, n=3, m=24, off=0.01), robe_w)
add(L.band(tab, "TabHem", "tab_trim", GOLD, 0.84, 0.9, 0.0, 1.0, n=3, m=2, off=0.01), robe_w) if False else None
WEIGHTS["tab_trim"] = robe_w

mantle = L.Garment([(1.64, 0, 0.02, 0.12, 0.1, 0.11, 2.2), (1.54, 0, 0.02, 0.3, 0.16, 0.17, 2.1), (1.4, 0, 0.0, 0.46, 0.22, 0.23, 2.0), (1.15, 0, 0.0, 0.52, 0.3, 0.32, 2.0),
                    (0.9, 0, 0.0, 0.58, 0.38, 0.4, 2.0), (0.7, 0, 0.0, 0.62, 0.42, 0.45, 2.0)],
                   top=1.64, hem=1.0, folds=[(8, 0.3, 1.0, 0.5, 0.15), (17, 0.0, 0.6, 1.1, -0.2)], amp=0.09, ramp=(0.1, 0.55), gap=0.5, gap_from=0.2, lay=0.0,
                   flare=0.04, micro=0.0013, hem_fn=ragged(1.0, 0.1), back_drop=0.0)
lo, hi = L.shell(mantle, "Mantle", "mantle", LINEN, 1500, HI, solid=0.008, ratio_floor=0.004)
PAIRS.append((lo, hi))
add(lo, mantle_w)
for nm, (v0, v1, u0, u1) in (("MantleL", (0.22, 0.985, 0.0, 0.035)), ("MantleR", (0.22, 0.985, 0.965, 1.0))):
    add(L.band(mantle, nm, "mantle_trim", GOLD, v0, v1, u0, u1, n=3, m=44, off=0.012), mantle_w)
WEIGHTS["mantle_trim"] = mantle_w

veil = L.Garment([(1.98, 0, 0.03, 0.04, 0.04, 0.04, 2.0), (1.95, 0, 0.03, 0.1, 0.1, 0.1, 2.0), (1.88, 0, 0.03, 0.14, 0.13, 0.145, 2.0), (1.76, 0, 0.04, 0.17, 0.15, 0.18, 2.0),
                  (1.6, 0, 0.06, 0.22, 0.17, 0.24, 2.0), (1.4, 0, 0.07, 0.3, 0.2, 0.3, 2.0), (1.15, 0, 0.08, 0.34, 0.24, 0.35, 2.0)],
                 top=1.98, hem=1.0, folds=[(7, 0.3, 1.0, 0.7, 0.1), (15, 0.0, 0.6, 1.9, 0)], amp=0.06, ramp=(0.1, 0.6), gap=1.15, gap_from=0.04, lay=0.0,
                 hem_lift=0.04, flare=0.03, micro=0.0012, hem_fn=ragged(1.0, 0.14))
lo, hi = L.shell(veil, "Veil", "veil", LINEN, 1400, HI, solid=0.006, ratio_floor=0.004)
PAIRS.append((lo, hi))
add(lo, veil_w)
add(L.band(veil, "VeilL", "veil_trim", GOLD, 0.1, 0.99, 0.0, 0.03, n=3, m=40, off=0.01), veil_w)
add(L.band(veil, "VeilR", "veil_trim", GOLD, 0.1, 0.99, 0.97, 1.0, n=3, m=40, off=0.01), veil_w)
WEIGHTS["veil_trim"] = veil_w

for tag, sx in (("l", -1), ("r", 1)):
    sl = L.Garment([(1.47, sx * 0.23, 0, 0.085, 0.08, 0.08, 2.2), (1.3, sx * 0.24, 0, 0.082, 0.08, 0.08, 2.2), (1.15, sx * 0.245, 0, 0.1, 0.1, 0.1, 2.2),
                    (1.02, sx * 0.25, 0, 0.17, 0.16, 0.16, 2.0), (0.9, sx * 0.255, 0.01, 0.23, 0.22, 0.22, 2.0), (0.8, sx * 0.255, 0.01, 0.26, 0.25, 0.25, 2.0)],
                   top=1.47, hem=0.95, folds=[(8, 0.0, 1.0, 0.5, 0.1), (18, 0, 0.6, 1.5, 0)], amp=0.06, ramp=(0.2, 0.7), lay=0.0, hem_lift=0.04, seed=sx,
                   micro=0.0013, hem_fn=ragged(0.95, 0.05))
    lo, hi = L.shell(sl, "Sleeve" + tag, "sleeve_" + tag, LINEN, 1400, (140, 100) if not LOWRES else (80, 60))
    bend_obj(lo, sx)
    bend_obj(hi, sx)
    PAIRS.append((lo, hi))
    add(lo, arm_chain_w(tag))
    cuf = L.band(sl, "Cuff" + tag, "sleeve_" + tag + "_t", GOLD, 0.86, 0.915, 0.0, 1.0, n=50, m=2, off=0.012)
    bend_obj(cuf, sx)
    add(cuf, arm_chain_w(tag))
    WEIGHTS["sleeve_" + tag + "_t"] = arm_chain_w(tag)
    # the bracer: a gilt sleeve on the forearm with raised rings, below the cuff
    ax = sx * 0.24
    yy = [0.97, 0.92, 0.86, 0.8, 0.76]
    br = K.loft("Bracer", [G(ax, y, 0.0) for y in yy], [0.034, 0.0345, 0.032, 0.029, 0.027], "bracer_" + tag, GOLD, 14, cap0=False, cap1=False)
    bend_obj(br, sx)
    add(br, arm_chain_w(tag))
    for y in (0.945, 0.84):
        rg = TUBE("BracerRing", [G(ax + math.cos(a) * 0.037, y, math.sin(a) * 0.037) for a in [math.tau * i / 18 for i in range(19)]], 0.004, "bracer_" + tag, GOLD)
        bend_obj(rg, sx)
        add(rg, arm_chain_w(tag))
    WEIGHTS["bracer_" + tag] = arm_chain_w(tag)

# a gilt cord at the waist with two long tails
for sx in (-1, 1):
    pts = [G(sx * 0.12 + sx * 0.012 * math.sin(t * 5), 1.12 - 0.62 * t, -0.17 - 0.03 * t) for t in [i / 10.0 for i in range(11)]]
    add(K.loft("Tail", pts, [(0.016, 0.004)] * 11, "cord", GOLD, 6), robe_w)
    add(K.blob("Tassel", Vector(pts[-1]) + Vector((0, 0, -0.03)), (0.02, 0.02, 0.04), "cord", GOLD, 10, 6), robe_w)
add(TUBE("Cord", [G(math.cos(a) * 0.17, 1.12 - 0.012 * math.cos(a), math.sin(a) * 0.14) for a in [math.tau * i / 28 for i in range(29)]], 0.008, "cord", GOLD), robe_w)
WEIGHTS["cord"] = robe_w

print("WARDEN parts", len(objs), "tris", sum(L.tri_count(o) for o in objs))
_t = {}
for o in objs:
    _t[o["sock"]] = _t.get(o["sock"], 0) + L.tri_count(o)
print("TRIS by part", _t)
if REVIEW:
    os.makedirs(os.path.dirname(REVIEW), exist_ok=True)
if REVIEW and not EXPORT:
    L.drop_highs(PAIRS)
    if "--close" in args:
        L.turnarounds(REVIEW + "_hands", 0.75, 2.4, angles=(("a", 75), ("b", 100)), samples=32, size=(700, 700), cam_z=0.9)
        L.turnarounds(REVIEW + "_head", 1.78, 2.2, angles=(("a", 80), ("b", 40)), samples=32, size=(700, 700), cam_z=1.8)
    L.turnarounds(REVIEW + "_raw", 1.25, 6.4, angles=(("front", 90), ("three", 45), ("side", 0), ("back", -90)), samples=32, size=(700, 940), cam_z=1.6)
if EXPORT:
    L.export_skinned2(objs, MATS, "boss_ascended_warden", S, WEIGHTS, {}, 4096 if not LOWRES else 1024, PAIRS)
    L.drop_highs(PAIRS)
    if REVIEW:
        L.use_atlas("boss_ascended_warden")
        arm = bpy.data.objects["Armature"]
        L.turnarounds(REVIEW + "_turn", 1.25, 6.4, cam_z=1.6)
        for nm, rots in L.POSES.items():
            L.reset_pose(arm)
            L.pose(arm, rots)
            L.turnarounds(REVIEW + "_" + nm, 1.25, 6.4, angles=(("front", 90), ("three", 45), ("side", 0)), cam_z=1.6)
