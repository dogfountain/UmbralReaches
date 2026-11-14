"""The Speaking Crown (the Fallen Hierarch's boss): the Hierarch's voice, kept in his head after the fall. A tall
hollowed cantor fused with the colossus's stone: a cope of carved, cracked masonry drapery to the ground
(pleats that start at the shoulders and widen to a broken hem), stacked stone pauldrons, gauntlets of fitted
blocks over heavy stone fists, and for a head a great fluted speaking-horn, its rolled mouth ringed with the
broken tines of the tiara and an ember in its throat. ONE skinned mesh on the Husk rig's sockets (GruntModel
poses it): fused stone torso and arms, cloth-shaped stone skinned to the chest, pelvis, hips and knees so it
bends and falls with the figure. Procedural materials only.

  tools/blender/run.sh boss_hierarch.py -- [--review shots/model_review/hierarch] [--no-export] [--lowres]
Writes art/models/boss_hierarch.glb and art/textures/boss_hierarch_*.png
"""
import bpy
import math
import os
import sys
import numpy as np
from mathutils import Vector, Matrix, noise

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
def stone_mat(name, base, light, moss=0.0, soot=0.0, scale=7.0):
    m = K.Mat(name)
    n1 = m.noise(scale, 7.0, 0.6)
    n2 = m.noise(scale * 4.0, 5.0, 0.55)
    col = m.ramp(n1, [(0.3, base), (0.8, light)])
    crack = m.math('LESS_THAN', m.voronoi(scale * 1.1, 'DISTANCE_TO_EDGE'), 0.018)
    crack = m.math('MULTIPLY', crack, m.math('GREATER_THAN', m.noise(3.0, 2.0, 0.5), 0.5))
    col = m.mix(crack, col, (0.05, 0.045, 0.04))
    # courses of masonry: faint horizontal joints
    z = m.zpos()
    joint = m.math('LESS_THAN', m.math('ABSOLUTE', m.math('SUBTRACT', m.math('MODULO', z, 0.21), 0.105)), 0.004)
    col = m.mix(m.math('MULTIPLY', joint, 0.5), col, (0.04, 0.04, 0.035))
    if moss > 0.0:
        mo = m.math('MULTIPLY', m.math('GREATER_THAN', m.noise(5.0, 4.0, 0.55), 0.55), moss)
        col = m.mix(mo, col, (0.27, 0.36, 0.17))
    if soot > 0.0:
        col = m.mix(m.math('MULTIPLY', m.math('GREATER_THAN', n2, 0.62), soot), col, (0.07, 0.06, 0.055))
    h = m.math('SUBTRACT', m.math('ADD', m.math('MULTIPLY', n2, 0.5), m.math('MULTIPLY', n1, 0.5)), m.math('MULTIPLY', crack, 0.8))
    h = m.math('SUBTRACT', h, m.math('MULTIPLY', joint, 0.5))
    return m.finish(col, m.math('ADD', 0.62, m.math('MULTIPLY', n2, 0.3)), 0.0, h, 0.7, 0.003)


def gilt_mat():
    m = K.Mat("Gilt")
    wear = m.noise(18.0, 6.0, 0.6)
    col = m.ramp(wear, [(0.3, (0.3, 0.2, 0.08)), (0.65, (0.68, 0.48, 0.2)), (0.9, (0.9, 0.72, 0.4))])
    return m.finish(col, m.math('ADD', 0.28, m.math('MULTIPLY', wear, 0.3)), 0.9, m.noise(90.0, 3.0, 0.5), 0.3, 0.002)


def ember_mat():
    m = K.Mat("Ember")
    pulse = m.noise(9.0, 3.0, 0.5)
    col = m.ramp(pulse, [(0.3, (1.0, 0.35, 0.08)), (0.8, (1.0, 0.72, 0.3))])
    return m.finish((0.08, 0.05, 0.04), 0.5, 0.0, None, emit=col, emit_strength=7.0)


STONE = stone_mat("Stone", (0.085, 0.08, 0.072), (0.25, 0.235, 0.205), moss=0.14, soot=0.3)
DARK = stone_mat("DarkStone", (0.05, 0.047, 0.044), (0.16, 0.15, 0.135), moss=0.0, soot=0.5, scale=9.0)
PALE = stone_mat("PaleStone", (0.17, 0.155, 0.13), (0.42, 0.39, 0.34), moss=0.05, soot=0.15, scale=6.0)
GILT = gilt_mat()
EMBER = ember_mat()
MATS = [STONE, DARK, PALE, GILT, EMBER]
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

# --- the torso, neck and arms: fused stone-flesh ------------------------------------------------------------
OPT = dict(W=1.25, L=1.7, nk=0.0, finger=0.1, wrist=0.72, ribs=0.0, belly=0.2, collar=0.6, tendon=0.6, hc=(0, 1.68, -0.02),
           head_w=0.07, neck_r=0.075, nohead=True, hand_r=1.8)
sk_full, SEGS, _Y = GB.humanoid(OPT)
tsk = L.torso_skel(1.3, 0.075, 1.7)


def torso_sculpt(s):
    s.noise(18.0, 0.003)
    s.folds(30.0, 0.0015)


to, thi = L.sculpted("Torso", tsk, "pel", STONE, "bodyskin", 2400, torso_sculpt, 0.006, False, PAIRS)
add(to)
WEIGHTS["bodyskin"] = GB.envelope_weights([sg for sg in SEGS if sg[0] in ("pelvis", "chest", "head")], 0.07)


def arm_sculpt(s):
    GB.humanoid_sculpt(s, OPT, _Y)
    s.noise(20.0, 0.004)


ao, ahi = L.sculpted("Arms", sk_full.arms, ["trpl", "trpr"], STONE, "armskin", 4400, arm_sculpt, 0.0045, False, PAIRS)
add(ao)
WEIGHTS["armskin"] = GB.envelope_weights([sg for sg in SEGS if sg[0].startswith(("shoulder_", "elbow_", "hand_")) or sg[0] == "chest"], 0.05)

# --- the head: a carved stone visage whose mouth is the speaking-horn --------------------------------------------------------
# a heavy brow, deep sockets with an ember in each, a broken nose and cheek planes, a crown of tines above; the lower face
# breaks open into a great cracked trumpet-mouth that faces the player, an ember deep in its throat
hk = GB.Skel()
hk.v("a", (0, 1.76, -0.02), 0.03)
hk.v("b", (0, 1.7, -0.05), 0.03, "a")
hk.mass((0, 1.79, -0.02), (0.135, 0.15, 0.135))                 # cranium
hk.mass((0, 1.72, -0.06), (0.115, 0.1, 0.1))                    # the cheeks and the upper jaw
hk.mass((0, 1.88, -0.0), (0.105, 0.07, 0.1))                    # the crown block


def visage_sculpt(s):
    fz = -0.145
    front = (0, 0, -1)
    s.ridge((-0.115, 1.835, fz + 0.01), (0.115, 1.835, fz + 0.01), 0.03, 0.035, facing=front)                    # the brow, a stone lintel
    for sx in (-1, 1):
        s.bump((sx * 0.055, 1.795, fz + 0.015), 0.032, -0.05, facing=front)                                    # sockets
        s.bump((sx * 0.1, 1.77, fz + 0.05), 0.04, -0.02, facing=(sx, 0, -1))                                   # temples
        s.bump((sx * 0.085, 1.735, fz + 0.04), 0.04, 0.03, facing=(sx * 0.5, 0, -1))                           # cheekbones
        s.ridge((sx * 0.02, 1.86, fz + 0.01), (sx * 0.09, 1.87, fz + 0.03), 0.02, 0.014, facing=front)         # brow furrows
    s.ridge((0, 1.82, fz + 0.01), (0, 1.73, fz - 0.015), 0.022, 0.032, facing=front)                           # nose
    s.bump((0, 1.9, fz + 0.03), 0.07, 0.02, facing=front)                                                      # forehead boss
    s.noise(24.0, 0.004)
    s.folds(40.0, 0.002)


ho, hhi = L.sculpted("Visage", hk, "a", STONE, "head", 3000, visage_sculpt, 0.0045, False, PAIRS)
add(ho, HEAD1)
for sx in (-1, 1):
    add(K.blob("Eye", Vector(G(sx * 0.055, 1.792, -0.152)), (0.017, 0.008, 0.012), "head", EMBER, 8, 6), HEAD1)
# the mouth: a trumpet breaking out of the jaw, flaring forward and a little down
axis = [Vector(G(0, 1.64, -0.07)), Vector(G(0, 1.6, -0.17)), Vector(G(0, 1.56, -0.28)), Vector(G(0, 1.52, -0.4)), Vector(G(0, 1.47, -0.52))]
rad = [0.07, 0.085, 0.12, 0.17, 0.225]


def cr(vals, t):
    n = len(vals) - 1
    x = min(max(t, 0.0), 1.0) * n
    i = min(int(x), n - 1)
    f = x - i
    p0, p1, p2, p3 = vals[max(i - 1, 0)], vals[i], vals[i + 1], vals[min(i + 2, n)]
    return 0.5 * ((2 * p1) + (-p0 + p2) * f + (2 * p0 - 5 * p1 + 4 * p2 - p3) * f * f + (-p0 + 3 * p1 - 3 * p2 + p3) * f ** 3)


NU, NS = 40, 30
Pr = np.zeros((NS + 1, NU, 3))
for i in range(NS + 1):
    s = i / NS
    c = cr(axis, s)
    tg = (cr(axis, min(s + 0.02, 1.0)) - cr(axis, max(s - 0.02, 0.0))).normalized()
    ux = Vector((1, 0, 0))
    vx = tg.cross(ux).normalized()
    r = cr(rad, s)
    for j in range(NU):
        a = math.tau * j / NU
        fl = (abs(math.cos(0.5 * 12 * a + 0.4)) - 0.64) * 0.03 * s ** 1.1 + (abs(math.cos(0.5 * 26 * a + 1.3)) - 0.64) * 0.005 * s
        # the mouth is cracked and chipped: a ragged lip
        chip = 0.02 * s ** 4 * max(0.0, math.sin(a * 3.0 + 0.7) + math.sin(a * 7.0 + 2.0) - 0.6)
        rr = r + fl - chip + 0.004 * math.sin(a * 5 + s * 7)
        p = c + ux * math.cos(a) * rr + vx * math.sin(a) * rr
        Pr[i, j] = (p.x, p.z, -p.y)
horn = L.grid_mesh("Horn", Pr, True, "head", STONE)
K.solidify(horn, 0.022)
add(horn, HEAD1)
MOUTH = axis[-1]
add(TUBE("HornRim", [MOUTH + Vector((math.cos(a) * 0.29, 0.0, math.sin(a) * 0.29)).copy() for a in [math.tau * i / 36 for i in range(37)]] if False else
         [Vector((MOUTH.x + math.cos(a) * 0.23, MOUTH.y + 0.0, MOUTH.z + math.sin(a) * 0.23)) for a in [math.tau * i / 36 for i in range(37)]], 0.016, "head", PALE), HEAD1)
add(K.blob("Throat", cr(axis, 0.5), (0.085, 0.085, 0.085), "head", EMBER, 18, 10), HEAD1)             # the ember deep in the throat
for t in (0.45, 0.65):
    c = cr(axis, t)
    r = cr(rad, t) + 0.014
    add(TUBE("Band", [Vector((c.x + math.cos(a) * r, c.y + 0.0, c.z + math.sin(a) * r)) for a in [math.tau * i / 26 for i in range(27)]], 0.0075, "head", GILT), HEAD1)
# jaw plates hold the trumpet at each side, a lower lip of stone under it
for sx in (-1, 1):
    add(GK.slab("Jaw", Vector(G(sx * 0.115, 1.66, -0.12)), (0.045, 0.1, 0.07), Matrix.Rotation(sx * 0.3, 3, 'Z').to_quaternion(), "head", PALE, 0.0, 0.01, 2.0 + sx, 14, 8, 0.5), HEAD1)
# the crown: a gilt band round the brow and broken tines standing up from it, several snapped
CC = Vector(G(0, 1.9, -0.02))
add(TUBE("Crown", [CC + Vector((math.cos(a) * 0.125, math.sin(a) * 0.115, 0.0)) for a in [math.tau * i / 28 for i in range(29)]], 0.012, "head", GILT), HEAD1)
for k in range(9):
    a = math.tau * k / 9 + 0.35
    d = Vector((math.cos(a), math.sin(a), 0.0))
    base = CC + Vector((d.x * 0.125, d.y * 0.115, 0.0))
    ln = 0.2 + 0.08 * noise.noise(Vector((k * 1.7, 2.0, 0.0)))
    if k % 3 == 1:
        ln *= 0.3
    add(L.thorn("Tine", base, Vector((0, 0, 1)), ln, 0.022 if k % 3 != 1 else 0.016, d * 0.05 + Vector((0, 0, 0)), "head", PALE, 5, 6, 0.6), HEAD1)

# --- pauldrons and gauntlets: carved, chipped masonry with mouldings (profiles turned on an axis, not blocks) ------------------
def moulded(name, p0, d, prof, sock, mat, sides=20, seed=0.0):
    """A turned stone shape along direction d from p0: prof = [(distance, radius)] (cornices, beads, hollows, a dome)."""
    d = Vector(d).normalized()
    pts = [Vector(p0) + d * t for t, _ in prof]
    return K.loft(name, pts, [r for _, r in prof], sock, mat, sides, cap0=True, cap1=True, wobble=0.05, seed=seed)


for sx, tag in ((-1, "l"), (1, "r")):
    S_ = S["shoulder_" + tag]
    wsh = (lambda t: lambda p: GK.chain_w(p, [("chest", C0), ("shoulder_" + t, S["shoulder_" + t] + G(0, 0.02, 0)), ("elbow_" + t, S["elbow_" + t])], [0.05, 0.05]))(tag)
    WEIGHTS["plate_" + tag] = wsh
    # a stepped dome: cornice, bead, cavetto, a second cornice, the cap, a finial
    prof = [(0.0, 0.17), (0.012, 0.185), (0.03, 0.19), (0.045, 0.165), (0.06, 0.16), (0.075, 0.175), (0.09, 0.176), (0.105, 0.15), (0.13, 0.135), (0.16, 0.115), (0.19, 0.085), (0.215, 0.05), (0.23, 0.02)]
    add(moulded("Pauldron", S_ + G(sx * 0.05, 0.02, 0.0), G(sx * 0.62, 1.0, 0.0), prof, "plate_" + tag, STONE, 22, 1.0 + sx), wsh)
    add(moulded("PauldronSkirt", S_ + G(sx * 0.15, -0.05, 0.0), G(sx * 0.9, 0.5, 0.0), [(0.0, 0.2), (0.015, 0.215), (0.035, 0.205), (0.05, 0.17), (0.07, 0.1), (0.08, 0.0)], "plate_" + tag, PALE, 20, 3.0 + sx), wsh)
    add(TUBE("PauldronRim", [S_ + G(sx * 0.05, 0.02, 0.0) + Vector(G(sx * 0.62, 1.0, 0.0)).normalized() * 0.03 + Vector((math.cos(a) * 0.19, math.sin(a) * 0.19, 0)) for a in [math.tau * i / 24 for i in range(25)]] if False else
             [Vector(S_ + G(sx * 0.05, 0.02, 0.0) + Vector(G(sx * 0.62, 1.0, 0.0)).normalized() * 0.03) + Vector((0, 0, 0)) for _ in range(2)], 0.001, "plate_" + tag, GILT), wsh) if False else None
    add(L.thorn("Finial", S_ + G(sx * 0.05, 0.02, 0.0) + Vector(G(sx * 0.62, 1.0, 0.0)).normalized() * 0.23, G(sx * 0.62, 1.0, 0.0), 0.12, 0.022, Vector((0, 0, 0)), "plate_" + tag, GILT, 6, 5, 1.0), wsh)
    wgl = (lambda t: lambda p: GK.chain_w(p, [("elbow_" + t, S["elbow_" + t]), ("hand_" + t, S["hand_" + t] + G(0, 0.0, 0))], [0.04]))(tag)
    WEIGHTS["gaunt_" + tag] = wgl
    ax = sx * 0.24
    gp = []
    y = 1.06
    for seg in range(3):
        for dy, r in ((0.0, 0.086), (0.012, 0.096), (0.03, 0.098), (0.042, 0.08), (0.058, 0.082), (0.07, 0.095), (0.082, 0.1)):
            gp.append((y - dy - seg * 0.095, r - 0.006 * seg))
    gp.sort(key=lambda q: -q[0])
    add(K.loft("Gauntlet", [G(ax, q[0], 0.0) for q in gp], [q[1] for q in gp], "gaunt_" + tag, PALE, 14, wobble=0.06, seed=sx + 5), wgl)
    add(TUBE("CuffGilt", [G(ax + math.cos(a) * 0.1, 1.045, math.sin(a) * 0.1) for a in [math.tau * i / 20 for i in range(21)]], 0.006, "gaunt_" + tag, GILT), wgl)

# --- the breastplate: a gilt lozenge, an ember at its heart, edict-lines carved over the breast -------------------------
PC = G(0, 1.31, -0.14)
add(K.blob("Plate", PC, (0.09, 0.016, 0.115), "chest", GILT, 20, 10), CHEST1)
add(K.blob("PlateEmber", PC + Vector((0, 0.016, 0)), (0.027, 0.01, 0.036), "chest", EMBER, 12, 8), CHEST1)
add(TUBE("PlateRim", [PC + Vector((math.cos(a) * 0.085, 0.012, math.sin(a) * 0.108)) for a in [math.tau * i / 26 for i in range(27)]], 0.006, "chest", GILT), CHEST1)

# --- the cope: carved drapery, cracked, to the ground, split at the front by a broken hem ---------------------------------
cope_w = L.cape_weights(0.6)
cope = L.Garment([(1.74, 0, 0.06, 0.2, 0.0, 0.1, 2.0), (1.62, 0, 0.04, 0.21, 0.08, 0.17, 2.2), (1.5, 0, 0.02, 0.27, 0.17, 0.2, 2.2), (1.38, 0, 0.0, 0.38, 0.22, 0.25, 2.0), (1.1, 0, 0.0, 0.48, 0.3, 0.33, 2.0),
                  (0.7, 0, 0.02, 0.58, 0.38, 0.45, 2.0), (0.3, 0, 0.03, 0.7, 0.5, 0.64, 2.0), (0.0, 0, 0.04, 0.82, 0.6, 0.82, 2.0), (-0.1, 0, 0.04, 0.86, 0.64, 0.86, 2.0)],
                 top=1.74, hem=0.06, folds=[(8, 0.35, 1.0, 0.4, 0.12), (17, 0.0, 0.7, 1.4, -0.15), (4, 0.6, 0.5, 2.0, 0.0)], amp=0.17,
                 ramp=(0.05, 0.5), gap=0.95, gap_from=0.0, lay=0.03, lay_r=0.06, hem_lift=0.09, flare=0.05, micro=0.0022, micro_k=31.0,
                 tongues=(9, 0.12, 1.5), warp=0.4,
                 top_fn=lambda t: -0.3 + 0.32 * ((np.sin(t) + 1.0) * 0.5) ** 1.3)
lo, hi = L.shell(cope, "Cope", "cope", STONE, 3600, HI, solid=0.02)
PAIRS.append((lo, hi))
add(lo, cope_w)
for nm, (v0, v1, u0, u1) in (("CopeBandL", (0.12, 0.97, 0.0, 0.04)), ("CopeBandR", (0.12, 0.97, 0.96, 1.0)), ("CopeHem", (0.88, 0.93, 0.0, 1.0))):
    add(L.band(cope, nm, "cope_trim", GILT, v0, v1, u0, u1, n=3 if u1 - u0 < 0.5 else 110, m=60 if v1 - v0 > 0.5 else 2, off=0.016), cope_w)
WEIGHTS["cope_trim"] = cope_w

# an under-robe of dark stone, closed, over the hips and legs, seen through the split
hip_w = L.skirt_weights(1.12, 0.92, 0.42)
rob = L.Garment([(1.16, 0, 0, 0.17, 0.125, 0.125, 2.2), (1.0, 0, 0, 0.19, 0.145, 0.145, 2.1), (0.78, 0, 0, 0.2, 0.17, 0.18, 2.0), (0.52, 0, 0.01, 0.24, 0.21, 0.23, 2.0), (0.36, 0, 0.01, 0.3, 0.26, 0.29, 2.0),
                 (0.2, 0, 0.02, 0.43, 0.37, 0.41, 2.0), (-0.1, 0, 0.02, 0.55, 0.49, 0.55, 2.0)],
                top=1.16, hem=0.04, folds=[(10, 0.0, 1.0, 0.3, 0.1), (21, 0.0, 0.7, 1.3, -0.1)], amp=0.07, ramp=(0.0, 0.5), lay=0.05, lay_r=0.05, hem_lift=0.05, micro=0.0018)
lo, hi = L.shell(rob, "Robe", "robe", DARK, 2800, HI)
PAIRS.append((lo, hi))
add(lo, hip_w)
add(L.band(rob, "RobeHem", "robe_trim", GILT, 0.86, 0.9, 0.0, 1.0, n=90, m=2, off=0.012), hip_w)
WEIGHTS["robe_trim"] = hip_w
# a belt, and the Order's tolling-gear: broken chain and two bell-clappers hung from it
add(K.loft("Belt", [G(math.cos(a) * 0.2, 1.14, math.sin(a) * 0.17) for a in [math.tau * i / 24 for i in range(25)]], [(0.03, 0.014)] * 25, "belt", DARK, 6, cap0=False, cap1=False), hip_w)
for sx in (-1, 1):
    pts = [G(sx * 0.14, 1.12 - 0.13 * t, -0.17 - 0.012 * t) for t in [i / 8.0 for i in range(9)]]
    add(GK.chain_links("Chain", pts, 0.0065, "belt", DARK, 0.026), hip_w)
    add(K.blob("Clapper", Vector(pts[-1]) + G(0, -0.045, 0), (0.03, 0.05, 0.03), "belt", GILT, 12, 8), hip_w)
WEIGHTS["belt"] = hip_w

print("HIERARCH parts", len(objs), "tris", sum(L.tri_count(o) for o in objs))
_t = {}
for o in objs:
    _t[o["sock"]] = _t.get(o["sock"], 0) + L.tri_count(o)
print("TRIS by part", _t)
if REVIEW:
    os.makedirs(os.path.dirname(REVIEW), exist_ok=True)
if REVIEW and not EXPORT:
    L.drop_highs(PAIRS)
    if "--close" in args:
        L.turnarounds(REVIEW + "_hands", 0.9, 2.6, angles=(("a", 75), ("b", 100)), samples=32, size=(700, 700), cam_z=1.0)
        L.turnarounds(REVIEW + "_head", 1.9, 3.0, angles=(("a", 80), ("b", 40)), samples=32, size=(700, 700), cam_z=2.0)
    L.turnarounds(REVIEW + "_raw", 1.15, 6.4, angles=(("front", 90), ("three", 45), ("side", 0), ("back", -90)), samples=32, size=(700, 940), cam_z=1.5)
if EXPORT:
    L.export_skinned2(objs, MATS, "boss_hierarch", S, WEIGHTS, {}, 4096 if not LOWRES else 1024, PAIRS)
    L.drop_highs(PAIRS)
    if REVIEW:
        L.use_atlas("boss_hierarch")
        arm = bpy.data.objects["Armature"]
        L.turnarounds(REVIEW + "_turn", 1.15, 6.4, cam_z=1.5)
        for nm, rots in L.POSES.items():
            L.reset_pose(arm)
            L.pose(arm, rots)
            L.turnarounds(REVIEW + "_" + nm, 1.15, 6.4, angles=(("front", 90), ("three", 45), ("side", 0)), cam_z=1.5)
