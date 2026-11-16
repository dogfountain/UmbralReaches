"""The Anchoress: a hermit who had herself walled into the Crowns' face to pray the sky still and would not come
out when the wall was opened: a gaunt woman in grey wool and the chain she bound herself with, a hood over a
sunken face with a rope across the mouth and a salt-crust on the brow, a cairn-stone anchor on a chain in her right
hand, a caged lantern in her left. ONE skinned mesh on the HunchRig's sockets (GruntModel poses it): a fused sculpted
body and head, wool that is draped geometry (hood, shawl, long skirt, sleeves; boss_sculpt_lib.Garment) skinned to the
chest, hips, knees and arms, a chain of real links wound over the shawl. The anchor (right hand) and the lantern
(left hand) are separate rigid parts on their sockets.

  tools/blender/run.sh boss_anchoress.py -- [--review shots/model_review/anchoress] [--no-export] [--lowres]
Writes art/models/boss_anchoress.glb and art/textures/boss_anchoress_*.png
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
HI = (150, 100) if LOWRES else (280, 180)

K.reset()
S = dict(K.SOCKETS)
P0, C0, H0 = S["pelvis"], S["chest"], S["head"]

# --- materials -----------------------------------------------------------------------------------
SKIN = GK.hollow_skin("Skin", (0.5, 0.4, 0.33), (0.17, 0.12, 0.1), wet=0.0, wrinkle=70.0, liv=(0.78, 0.74, 0.82), extremities=0.5, vein_amt=0.4)
WOOL = GK.cloth("Wool", (0.3, 0.28, 0.25), "caban", 8.0, (0.05, 0.045, 0.04), 0.9)
WOOL2 = GK.cloth("WoolDark", (0.19, 0.18, 0.17), "caban", 9.0, (0.03, 0.028, 0.026), 0.92)
def salt_wool(name, tint, grime, rough=0.9):
    """Grey wool with a salt tide-line: pale crust dried into the cloth along the hem and up in streaks (no separate white bands)."""
    m = K.Mat(name)
    sc = m.scan("caban", 8.0)
    blot = m.noise(5.0, 6.0, 0.6)
    col = m.mul(m.mono(sc["color"]), tuple(c * 2.2 for c in tint))
    col = m.mix(m.math('MULTIPLY', blot, 0.45), col, grime)
    z = m.zpos()
    tide = m.math('ADD', 0.3, m.math('MULTIPLY', m.noise(7.0, 5.0, 0.6), 0.22))
    below = m.math('LESS_THAN', z, tide)
    streak = m.math('GREATER_THAN', m.noise(9.0, 4.0, 0.6), 0.45)
    salt = m.math('MULTIPLY', below, streak)
    col = m.mix(m.math('MULTIPLY', salt, 0.55), col, (0.34, 0.35, 0.33))
    h = m.math('ADD', m.math('MULTIPLY', sc["disp"], 1.0), m.math('MULTIPLY', salt, 0.5))
    return m.finish(col, rough, 0.0, h, 0.6, 0.002)


WOOLS = salt_wool("WoolSalt", (0.19, 0.18, 0.17), (0.03, 0.028, 0.026), 0.92)
IRON = GK.iron("Iron", (0.12, 0.115, 0.12), (0.2, 0.1, 0.05))
STONE = GK.stone("Cairn", (0.3, 0.31, 0.3), (0.09, 0.11, 0.07))
# her face is lit from within, faintly: a lamp-coloured warmth in the skin (the night grade would otherwise drown it)
FACE = GK.hollow_skin("Face", (0.32, 0.24, 0.2), (0.1, 0.065, 0.05), wet=0.0, wrinkle=70.0, liv=(0.78, 0.74, 0.82), extremities=0.0, vein_amt=0.4)
FACE.emit = (1.0, 0.62, 0.3)
FACE.emit_strength = 0.35
FACE.bsdf.inputs['Emission Color'].default_value = (1.0, 0.62, 0.3, 1.0)
FACE.bsdf.inputs['Emission Strength'].default_value = 0.07
SALT = GK.stone("Salt", (0.78, 0.8, 0.78), (0.5, 0.55, 0.5))
ROPE = GK.cloth("Rope", (0.42, 0.33, 0.2), "caban", 20.0, (0.1, 0.08, 0.05), 0.85)
GLOW = GK.glow("Lamp", (1.0, 0.55, 0.16), 8.0)
EYE = GK.glow("EyeGlow", (1.0, 0.6, 0.2), 6.0)
MATS = [SKIN, FACE, WOOL, WOOL2, IRON, STONE, SALT, ROPE, GLOW, EYE, WOOLS]  # HAIRM is appended below
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

# --- the body: torso and neck, thin arms and long hands --------------------------------------------------------
OPT = dict(W=0.78, L=0.66, nk=0.04, finger=0.38, wrist=0.72, ribs=0.0, belly=-1.0, collar=1.5, tendon=1.7, hc=(0, 1.68, -0.06),
           head_w=0.068, neck_r=0.034, nohead=False, jaw_w=0.036, brow=0.014, hand_r=2.3)
sk_full, SEGS, _Y = GB.humanoid(OPT)


def LEAN(y):
    """The stoop modelled into the upper body: a hermit bowed over her chain. Forward (-z) from the waist up, 0 below the belt."""
    y = np.asarray(y, dtype=np.float64)
    t = np.clip((y - 1.0) / 0.55, 0.0, 1.0)
    return -0.085 * t * t * (3.0 - 2.0 * t)


def arm_out(keys):
    """Sleeve sections follow the arms held out from the skirt (the same outward shift as the arm skeleton)."""
    return [(k[0], k[1] + (1.0 if k[1] > 0 else -1.0) * ARMOUT * min(1.0, max(0.0, (1.2 - k[0]) / 0.4)),) + tuple(k[2:]) for k in keys]


def GarmentL(keys, *a, **k):
    return L.Garment(lean_keys(keys), *a, **k)


def lean_keys(keys):
    return [(k[0], k[1], k[2] + float(LEAN(k[0])),) + tuple(k[3:]) for k in keys]


ARMOUT = 0.11                                          # the forearms and hands held a little away from the skirt, so they read outside the cloth
for _i in range(len(sk_full.arms.p)):                  # the arms hang from the bowed shoulders
    _x, _y, _z = sk_full.arms.p[_i]
    _out = ARMOUT * min(1.0, max(0.0, (1.2 - _y) / 0.4)) * (1.0 if _x > 0 else -1.0)
    sk_full.arms.p[_i] = (_x + _out, _y, _z + float(LEAN(_y)))
# the hands DO something: each fist closes round its grip (a link of the chain on the right, the lamp's ring on the left), fingers stacked
# down the grip and wrapped back, outer side, front and inner side round it, the thumb laid across the front (arm nodes are (x, depth+front, height))
for _t, _s in (("r", 1.0), ("l", -1.0)):
    _w = sk_full.arms.p[sk_full.arms.idx["wr" + _t]]
    _ax = _w[0]
    _rr = 0.058
    for _k in range(4):
        _h = 0.69 - 0.05 * _k
        _ring = ((_ax, -_rr * 0.9), (_ax + _s * _rr, 0.0), (_ax, _rr * 1.0), (_ax - _s * _rr * 0.9, 0.0))
        for _j in range(4):
            sk_full.arms.p[sk_full.arms.idx["f%d%s%d" % (_k, _t, _j)]] = (_ring[_j][0], _ring[_j][1] + _w[1], _h - 0.004 * _j)
    sk_full.arms.p[sk_full.arms.idx["th" + _t + "0"]] = (_ax - _s * 0.03, _w[1] + 0.0, 0.67)
    sk_full.arms.p[sk_full.arms.idx["th" + _t + "1"]] = (_ax - _s * 0.012, _w[1] + 0.045, 0.655)
    sk_full.arms.p[sk_full.arms.idx["th" + _t + "2"]] = (_ax + _s * 0.014, _w[1] + 0.05, 0.64)
tsk = GB.Skel()
W_ = 0.78
tsk.loft(lean_keys([(0.78, 0, 0.0, 0.06 * W_, 0.05, 0.05, 2.0), (0.84, 0, 0.0, 0.1 * W_, 0.07, 0.08, 2.2), (0.95, 0, 0.0, 0.125 * W_, 0.08, 0.09, 2.2),
                    (1.05, 0, 0.0, 0.115 * W_ * 0.9, 0.075, 0.085, 2.2), (1.15, 0, 0.0, 0.13 * W_, 0.085, 0.09, 2.2),
                    (1.26, 0, 0.005, 0.145 * W_, 0.095, 0.095, 2.05), (1.36, 0, 0.01, 0.155 * W_, 0.1, 0.1, 2.1), (1.43, 0, 0.012, 0.16 * W_, 0.092, 0.095, 2.25),
                    (1.47, 0, 0.012, 0.15 * W_, 0.075, 0.09, 2.2), (1.5, 0, 0.01, 0.12 * W_, 0.064, 0.08, 2.0), (1.535, 0, 0.0, 0.085 * W_, 0.058, 0.07, 2.0),
                    (1.57, 0, -0.01, 0.034 * 1.2, 0.034 * 1.08, 0.034 * 1.2, 2.0), (1.6, 0, -0.02, 0.034, 0.034, 0.034 * 1.05, 2.0)]))
tsk.v("pel", (0, 0.9, 0), 0.03)
tsk.v("wst", (0, 1.04, 0), 0.03, "pel")


def torso_sculpt(s):
    for sx in (-1, 1):
        s.ridge((sx * 0.02, 1.475, -0.075), (sx * 0.2, 1.455, -0.03), 0.011, 0.012, facing=(0, 0.3, -1))
        s.bump((sx * 0.055, 1.5, -0.065), 0.03, -0.014, facing=(0, 0.4, -1))
    s.noise(26.0, 0.0016)


to, thi = L.sculpted("Torso", tsk, "pel", SKIN, "bodyskin", 1600, torso_sculpt, 0.006, False, PAIRS)
add(to)
WEIGHTS["bodyskin"] = GB.envelope_weights([sg for sg in SEGS if sg[0] in ("pelvis", "chest", "head")], 0.07)


def arm_sculpt(s):
    GB.humanoid_sculpt(s, OPT, _Y)


ao, ahi = L.sculpted("Arms", sk_full.arms, ["trpl", "trpr"], SKIN, "armskin", 3800, arm_sculpt, 0.0042, False, PAIRS)
add(ao)
WEIGHTS["armskin"] = GB.envelope_weights([sg for sg in SEGS if sg[0].startswith(("shoulder_", "elbow_", "hand_")) or sg[0] == "chest"], 0.05)

# --- the head: a gaunt face sunk under the hood --------------------------------------------------------------------
hc = (OPT["hc"][0], OPT["hc"][1], OPT["hc"][2] + float(LEAN(OPT["hc"][1])))
OPT_H = dict(OPT, hc=hc)
hsk = GB.Skel()
hsk.v("a", (hc[0], hc[1], hc[2]), 0.02)
hsk.v("b", (hc[0], hc[1] - 0.03, hc[2] - 0.03), 0.02, "a")
GB.head_masses(hsk, OPT_H, hc[1])
hz = hc[2]
hsk.mass((0, hc[1] + 0.03, hz - 0.052), (0.05, 0.011, 0.02))               # the brow shelf
hsk.mass((0, hc[1] + 0.008, hz - 0.074), (0.012, 0.032, 0.018))               # the bridge of the nose
hsk.mass((0, hc[1] - 0.016, hz - 0.082), (0.017, 0.02, 0.018))               # the nose


def head_sculpt(s):
    GB.head_sculpt(s, OPT_H, _Y)
    for sx in (-1, 1):
        s.bump((sx * 0.031, hc[1] + 0.012, hz - 0.082), 0.026, -0.04, facing=(0, 0, -1))                # deep eye hollows
        s.ridge((sx * 0.006, hc[1] + 0.018, hz - 0.088), (sx * 0.056, hc[1] + 0.02, hz - 0.07), 0.007, 0.011, facing=(0, 0.2, -1))   # the upper lids, closed
        s.ridge((sx * 0.01, hc[1] + 0.003, hz - 0.088), (sx * 0.05, hc[1] + 0.005, hz - 0.074), 0.005, 0.007, facing=(0, 0, -1))     # the lower lids
        s.ridge((sx * 0.014, hc[1] + 0.036, hz - 0.082), (sx * 0.064, hc[1] + 0.04, hz - 0.066), 0.011, 0.018, facing=(0, 0.3, -1))   # the hard brow
        s.bump((sx * 0.05, hc[1] - 0.04, hz - 0.058), 0.04, -0.045, facing=(sx * 0.4, 0, -1))           # cheeks sunk to the bone
        s.bump((sx * 0.06, hc[1] - 0.012, hz - 0.064), 0.024, 0.016, facing=(sx * 0.6, 0, -1))          # cheekbones standing out over them
        s.bump((sx * 0.066, hc[1] - 0.062, hz - 0.044), 0.02, -0.02, facing=(sx, 0, -1))                # the hollow where the rope bites
        s.ridge((sx * 0.012, hc[1] - 0.05, hz - 0.087), (sx * 0.05, hc[1] - 0.046, hz - 0.066), 0.006, 0.009, facing=(0, 0, -1))      # lips, drawn tight round the gag
        s.ridge((sx * 0.01, hc[1] - 0.066, hz - 0.086), (sx * 0.04, hc[1] - 0.062, hz - 0.07), 0.006, 0.007, facing=(0, 0, -1))       # the lower lip
    s.ridge((0, hc[1] + 0.02, hz - 0.1), (0, hc[1] - 0.03, hz - 0.112), 0.011, 0.016, facing=(0, 0, -1))   # the nose
    s.bump((0, hc[1] - 0.032, hz - 0.098), 0.016, -0.012, facing=(0, 0, -1))                              # under the nose
    s.noise(40.0, 0.0012)


ho, hhi = L.sculpted("Face", hsk, "a", FACE, "head", 2600, head_sculpt, 0.0035, False, PAIRS)
add(ho, HEAD1)
FZ = hc[2] - 0.085
# the rope across the mouth, knotted, its ends hanging; the salt-crust on the brow
rope = [G(-0.075, hc[1] - 0.045, hc[2] - 0.04), G(-0.05, hc[1] - 0.056, FZ + 0.01), G(0.0, hc[1] - 0.058, FZ - 0.003), G(0.05, hc[1] - 0.056, FZ + 0.01), G(0.075, hc[1] - 0.045, hc[2] - 0.04)]
add(TUBE("Gag", rope, 0.0125, "head", ROPE), HEAD1)
add(K.blob("GagKnot", G(0.052, hc[1] - 0.057, FZ + 0.012), (0.016, 0.014, 0.016), "head", ROPE, 10, 6), HEAD1)
add(L.thorn("GagEnd", G(0.052, hc[1] - 0.06, FZ + 0.008), Vector(G(0.1, -1.0, -0.2)), 0.12, 0.009, Vector(G(0.03, 0, -0.03)), "head", ROPE, 5, 6, 1.0), HEAD1)
add(L.thorn("GagEnd", G(0.055, hc[1] - 0.06, FZ + 0.008), Vector(G(0.3, -1.0, 0.0)), 0.08, 0.008, Vector(G(0.03, 0, 0.0)), "head", ROPE, 5, 6, 1.0), HEAD1)
for sx in (-1, 1):                      # a coal of light under each lid: she is praying, not sleeping
    add(K.blob("Ember", G(sx * 0.032, hc[1] + 0.009, hc[2] - 0.067), (0.009, 0.005, 0.005), "head", EYE, 8, 6), HEAD1)

HAIRM = GK.cloth("Hair", (0.2, 0.19, 0.19), "rough_linen", 30.0, (0.05, 0.05, 0.05), 0.85)
MATS.append(HAIRM)
rngh = np.random.RandomState(8)
for sx in (-1, 1):                      # lank grey hair framing the face and falling past the jaw: a woman's face, not a skull
    for k in range(7):
        a = 0.2 + 0.1 * k
        root = G(sx * (0.045 + 0.012 * k * 0.3), hc[1] + 0.085 - 0.012 * k, hz - 0.03 + 0.012 * k)
        pts = [Vector(root) + Vector(G(sx * (0.032 + 0.004 * k) * t + 0.01 * math.sin(t * 5 + k), -0.2 * t - 0.01 * k * t, -0.02 * t)) for t in [i / 6.0 for i in range(7)]]
        add(GK.strip("Hair", pts, 0.012, 0.004, "head", HAIRM, taper=0.7), HEAD1)

HCB = Vector(G(hc[0], hc[1], hc[2]))
L.scale_about([o for o in objs if o["sock"] == "head"] + [hhi], HCB, 1.55)

# --- the wool -------------------------------------------------------------------------------------------------------
def hood_w(p):
    h = GK.chain_w(p, [("chest", C0), ("head", G(0, 1.55, -0.02))], 0.08)
    return h


hood = GarmentL([(2.0, 0.0, -0.01, 0.03, 0.03, 0.04, 2.0), (1.96, 0.0, -0.01, 0.1, 0.12, 0.13, 2.0), (1.88, 0.0, -0.01, 0.15, 0.18, 0.2, 2.0), (1.76, 0, 0.0, 0.18, 0.21, 0.23, 2.0),
                 (1.6, 0, 0.02, 0.22, 0.22, 0.26, 2.0), (1.48, 0, 0.03, 0.25, 0.22, 0.28, 2.0), (1.4, 0, 0.03, 0.26, 0.22, 0.29, 2.0)],
                top=2.0, hem=1.45, folds=[(7, 0.3, 1.0, 0.7, 0.1), (15, 0.0, 0.6, 1.9, 0)], amp=0.05, ramp=(0.1, 0.6), gap=1.5, gap_from=0.0, lay=0.0,
                hem_lift=0.05, flare=0.03, micro=0.0016, tongues=(11, 0.1, 1.3), back_drop=0.12)
lo, hi = L.shell(hood, "Hood", "hood", WOOL, 1700, HI, solid=0.007, ratio_floor=0.004)
PAIRS.append((lo, hi))
add(lo, hood_w)

shawl = GarmentL([(1.66, 0, -0.01, 0.052, 0.05, 0.055, 2.0), (1.62, 0, 0.0, 0.1, 0.075, 0.085, 2.1), (1.55, 0, 0.01, 0.17, 0.11, 0.12, 2.1), (1.48, 0, 0.0, 0.25, 0.17, 0.19, 2.0), (1.3, 0, 0.0, 0.25, 0.2, 0.22, 2.0), (1.08, 0, 0.0, 0.25, 0.23, 0.25, 2.0),
                   (0.9, 0, 0.0, 0.3, 0.26, 0.29, 2.0)],
                  top=1.66, hem=1.2, folds=[(8, 0.3, 1.0, 0.5, 0.15), (19, 0.0, 0.6, 1.1, -0.2)], amp=0.06, ramp=(0.1, 0.55), gap=0.45, gap_from=0.25, front=L.FRONT + 0.6, lay=0.0,
                  hem_lift=0.06, flare=0.03, micro=0.0016, tongues=(17, 0.1, 1.2), back_drop=0.15, warp=0.8)
lo, hi = L.shell(shawl, "Shawl", "shawl", WOOL2, 1500, HI, solid=0.008, ratio_floor=0.004)
PAIRS.append((lo, hi))
sh_w = L.cape_weights(0.5)
add(lo, sh_w)

def _wrap(x):
    return (x + math.pi) % math.tau - math.pi


def torn_hem(base, hitch_at, hitch_h, tat):
    """A hem that is not a circle: hitched up on one side (caught on the chain), long behind, torn into tatters."""
    def fn(t):
        t = np.asarray(t, dtype=np.float64)
        h = base + 0.04 * np.abs(np.sin(5.5 * t + 0.3))
        d = np.clip(1.0 - np.abs(_wrap(t - hitch_at)) / 0.8, 0.0, 1.0)
        h = h + hitch_h * d * d * (3.0 - 2.0 * d)
        tt = np.clip(np.sin(9.0 * t + 0.2) + np.sin(23.0 * t + 2.0) + np.sin(37.0 * t) - 1.1, 0.0, None)
        return h + tat * tt
    return fn


skirt = GarmentL([(1.52, 0, 0.01, 0.13, 0.095, 0.1, 2.2), (1.4, 0, 0.01, 0.155, 0.105, 0.11, 2.2), (1.26, 0, 0, 0.155, 0.11, 0.11, 2.2), (1.16, 0, 0, 0.14, 0.1, 0.1, 2.2), (1.0, 0, 0, 0.14, 0.12, 0.12, 2.1), (0.75, 0, 0, 0.15, 0.13, 0.14, 2.0), (0.45, 0, 0.01, 0.21, 0.19, 0.21, 2.0),
                   (0.2, 0, 0.02, 0.42, 0.37, 0.41, 2.0), (-0.1, 0, 0.02, 0.54, 0.49, 0.55, 2.0)],
                  top=1.52, hem=0.03, folds=[(11, 0.0, 1.0, 0.3, 0.1), (23, 0.0, 0.7, 1.3, -0.15), (5, 0.4, 0.3, 2.0, 0)], amp=0.09, ramp=(0.3, 0.6), lay=0.0, lay_r=0.06,
                  hem_lift=0.05, micro=0.0018, hem_fn=torn_hem(0.03, -2.3, 0.2, 0.08))
lo, hi = L.shell(skirt, "Skirt", "skirt", WOOLS, 3000, HI, ratio_floor=0.004)
PAIRS.append((lo, hi))
hip_w = L.skirt_weights(1.12, 0.92, 0.42)
add(lo, hip_w)

# a torn overskirt, open off-centre, over the first
over = GarmentL([(1.2, 0, 0, 0.16, 0.125, 0.125, 2.2), (0.9, 0, 0, 0.17, 0.15, 0.15, 2.0), (0.6, 0, 0.01, 0.22, 0.2, 0.22, 2.0), (0.3, 0, 0.02, 0.43, 0.38, 0.42, 2.0), (0.05, 0, 0.02, 0.58, 0.52, 0.58, 2.0)],
                 top=1.2, hem=0.42, folds=[(9, 0.0, 1.0, 0.9, 0.2), (19, 0.0, 0.7, 2.1, -0.1)], amp=0.08, ramp=(0.05, 0.5), gap=0.75, gap_from=0.0, front=L.FRONT + 0.7,
                 lay=0.0, hem_lift=0.08, micro=0.0016, tongues=(11, 0.14, 1.2), warp=0.9)
lo, hi = L.shell(over, "Overskirt", "overskirt", WOOL, 1000, HI, solid=0.007, ratio_floor=0.004)
PAIRS.append((lo, hi))
add(lo, hip_w)
# (the salt is dried into the wool itself, a tide-line in the WoolSalt material: no separate white bands or loose flakes)

for tag, sx in (("l", -1), ("r", 1)):
    sl = GarmentL(arm_out([(1.47, sx * 0.23, 0, 0.082, 0.078, 0.078, 2.2), (1.3, sx * 0.24, 0, 0.074, 0.074, 0.074, 2.2), (1.1, sx * 0.245, 0, 0.066, 0.066, 0.066, 2.2),
                    (0.95, sx * 0.25, 0, 0.078, 0.076, 0.076, 2.0), (0.86, sx * 0.255, 0.01, 0.1, 0.095, 0.095, 2.0), (0.78, sx * 0.255, 0.01, 0.11, 0.105, 0.105, 2.0)]),
                   top=1.47, hem=1.08, folds=[(7, 0.0, 1.0, 0.5, 0.1), (16, 0, 0.6, 1.5, 0)], amp=0.03, ramp=(0.2, 0.7), lay=0.0, hem_lift=0.025, seed=sx, micro=0.0012,
                   tongues=(9, 0.04, 1.3))
    lo, hi = L.shell(sl, "Sleeve" + tag, "sleeve_" + tag, WOOL, 1300, (120, 90) if not LOWRES else (70, 50))
    PAIRS.append((lo, hi))
    add(lo, L.sleeve_weights(tag))

# the rope belt: two turns round the waist, a knot at the right hip (where the lantern's hook hangs) and its tails
belt = []
for i in range(0, 73):
    a = math.tau * i / 36.0
    belt.append(G(math.cos(a) * (0.16 + 0.004 * math.sin(a * 3)), 1.13 + 0.012 * math.sin(a * 2) + (0.012 if i > 36 else 0.0), math.sin(a) * (0.125 + 0.003 * math.sin(a * 3))))
add(TUBE("Belt", belt, 0.011, "belt", ROPE), hip_w)
WEIGHTS["belt"] = hip_w
KN = G(0.14, 1.1, -0.145)
add(K.blob("Knot", KN, (0.028, 0.026, 0.028), "belt", ROPE, 12, 8), hip_w)
add(L.thorn("BeltTail", KN + G(0, -0.01, 0), Vector(G(0.15, -1.0, -0.1)), 0.34, 0.012, Vector(G(0.03, 0, -0.02)), "belt", ROPE, 5, 8, 1.0), hip_w)
add(L.thorn("BeltTail", KN + G(0, -0.01, 0), Vector(G(-0.05, -1.0, -0.25)), 0.26, 0.011, Vector(G(-0.02, 0, -0.05)), "belt", ROPE, 5, 8, 1.0), hip_w)
# the hip lamp's hook and a small cell-lamp on it (the weak point's light sits at this spot)
add(TUBE("Hook", [KN + G(0, -0.03, 0), KN + G(0.0, -0.07, -0.015), KN + G(0.02, -0.095, -0.02), KN + G(0.0, -0.11, -0.01)], 0.0055, "belt", IRON), hip_w)
add(K.blob("CellLamp", KN + G(0.0, -0.15, -0.02), (0.026, 0.038, 0.026), "belt", GLOW, 10, 8), hip_w)
for k in range(4):
    a = math.tau * k / 4.0
    add(TUBE("CellBar", [KN + G(math.cos(a) * 0.028, -0.1, math.sin(a) * 0.028), KN + G(math.cos(a) * 0.034, -0.15, -0.02 + math.sin(a) * 0.034), KN + G(math.cos(a) * 0.028, -0.2, math.sin(a) * 0.028)], 0.0035, "belt", IRON), hip_w)

# the weight she drags: a heavy chain from the knot down to the floor and trailing behind her, ending in a stone
tp = [G(0.14, 1.1, -0.145), G(0.2, 0.8, -0.22), G(0.24, 0.4, -0.3), G(0.2, 0.06, -0.32), G(0.05, 0.03, -0.12), G(-0.2, 0.03, 0.2), G(-0.55, 0.03, 0.5), G(-0.95, 0.03, 0.7), G(-1.4, 0.03, 0.62), G(-1.85, 0.03, 0.78)]
sm = []
for a_, b_ in zip(tp, tp[1:]):
    for k in range(6):
        sm.append(Vector(a_).lerp(Vector(b_), k / 6.0))
sm.append(Vector(tp[-1]))
add(GK.chain_links("Trail", sm, 0.019, "belt", IRON, 0.05), hip_w)
add(K.blob("TrailRing", Vector(tp[-1]), (0.07, 0.02, 0.07), "belt", IRON, 10, 6), hip_w)
add(GK.slab("TrailStone", Vector(tp[-1]) + Vector(G(-0.1, 0.06, 0.04)), (0.13, 0.11, 0.08), Matrix.Rotation(0.5, 3, 'Z').to_quaternion(), "belt", STONE, 0.0, 0.08, 9.0, 18, 10, 0.5), hip_w)

# a torn strip of the shawl hanging from the left shoulder to the knee, ragged, swinging free of the skirt
tail = GarmentL([(1.5, 0, 0.0, 0.3, 0.22, 0.24, 2.0), (1.2, 0, 0.0, 0.38, 0.27, 0.3, 2.0), (0.85, 0, 0.0, 0.46, 0.34, 0.38, 2.0), (0.5, 0, 0.0, 0.52, 0.4, 0.44, 2.0), (0.25, 0, 0.0, 0.56, 0.44, 0.48, 2.0)],
                 top=1.5, hem=0.48, folds=[(7, 0.4, 1.0, 0.3, 0.1), (17, 0.0, 0.7, 1.3, -0.1)], amp=0.04, ramp=(0.1, 0.5), gap=2.7, gap_from=0.0, front=0.1, lay=0.0,
                 hem_fn=torn_hem(0.45, 0.0, 0.0, 0.16), micro=0.0016, warp=0.8)
lo, hi = L.shell(tail, "Tail", "tail", WOOL, 900, (100, 80) if not LOWRES else (60, 50), solid=0.007, ratio_floor=0.004)
PAIRS.append((lo, hi))
add(lo, L.cape_weights(0.45))

# loose chain swinging out from the right shoulder, down and back to the belt: a loop that breaks the cone's edge
for pts_ in ([G(0.3, 1.46, 0.02), G(0.52, 1.28, 0.0), G(0.66, 0.98, -0.08), G(0.58, 0.7, -0.12), G(0.36, 0.84, -0.18), G(0.18, 1.04, -0.16)],
             [G(-0.3, 1.44, 0.04), G(-0.5, 1.2, 0.1), G(-0.58, 0.9, 0.16), G(-0.4, 0.78, 0.2), G(-0.22, 1.0, 0.1)]):
    sm = []
    for a_, b_ in zip(pts_, pts_[1:]):
        for k in range(7):
            sm.append(Vector(a_).lerp(Vector(b_), k / 7.0))
    sm.append(Vector(pts_[-1]))
    add(GK.chain_links("Loop", sm, 0.015, "chain2", IRON, 0.04), L.cape_weights(0.3))
WEIGHTS["chain2"] = L.cape_weights(0.3)

# the chain she bound herself with: wound over the shawl, crossing the breast, a loop hanging to the knot
sh_a, sh_f = 0.36, 0.255
chain = []
for i in range(0, 121):
    t = i / 120.0
    a = math.tau * 2.6 * t + 0.3
    y = 1.34 - 0.3 * t + 0.015 * math.sin(a * 2)
    chain.append(G(math.sin(a) * (0.255 + 0.01 * t), y, math.cos(a) * (0.17 + 0.01 * t) * 1.0))
add(GK.chain_links("Chain", chain, 0.0115, "chain", IRON, 0.032), L.cape_weights(0.3))
WEIGHTS["chain"] = L.cape_weights(0.3)
for sx in (-1, 1):                      # over each shoulder, crossing to the opposite hip
    pts = [G(sx * 0.13, 1.5, 0.02), G(sx * 0.2, 1.46, -0.07), G(sx * 0.1, 1.3, -0.19), G(-sx * 0.02, 1.15, -0.21), G(-sx * 0.12, 1.02, -0.2)]
    sm = []
    for a_, b_ in zip(pts, pts[1:]):
        for k in range(5):
            sm.append(Vector(a_).lerp(Vector(b_), k / 5.0) + Vector(G(0, -0.01 * math.sin(k / 5.0 * math.pi), 0)))
    sm.append(Vector(pts[-1]))
    add(GK.chain_links("Chain", sm, 0.011, "chain", IRON, 0.03), L.cape_weights(0.3))
loop = [G(-0.12, 1.02, -0.2), G(-0.1, 0.9, -0.215), G(0.0, 0.84, -0.225), G(0.1, 0.9, -0.2), G(0.14, 1.07, -0.16)]
sm = []
for a_, b_ in zip(loop, loop[1:]):
    for k in range(6):
        sm.append(Vector(a_).lerp(Vector(b_), k / 6.0))
sm.append(Vector(loop[-1]))
add(GK.chain_links("Chain", sm, 0.011, "belt", IRON, 0.03), hip_w)

# --- the anchor (right hand): a cairn-stone on a chain, an iron ring, hanging a body-length (rigid) ----------------------
HR = S["hand_r"] + Vector(G(ARMOUT, 0.0, 0.0))
rig_r = []


def radd(o):
    o["sock"] = "hand_r"
    rig_r.append(o)
    return o


radd(GK.chain_links("Chain", [HR + G(0, -0.02, 0), HR + G(0.01, -0.3, -0.02), HR + G(0.0, -0.56, 0.0)], 0.0095, "hand_r", IRON, 0.03))
radd(TUBE("Ring", [HR + G(math.cos(a) * 0.075, -0.6, math.sin(a) * 0.075) for a in [math.tau * i / 18 for i in range(19)]], 0.012, "hand_r", IRON))
for j, (w, h, y, z) in enumerate(((0.2, 0.12, -0.84, 0.0), (0.15, 0.1, -0.73, 0.01), (0.1, 0.08, -0.655, 0.0))):
    radd(GK.slab("Stone", HR + G(0.01 * j, y, z), (w, w * 0.9, h * 0.5), Matrix.Rotation(0.12 * j, 3, 'Z').to_quaternion(), "hand_r", STONE, 0.0, 0.05, j + 2.0, 24, 12, 0.5))
for y in (-0.8, -0.9):
    radd(TUBE("Strap", [HR + G(math.cos(a) * 0.205, y, math.sin(a) * 0.185) for a in [math.tau * i / 20 for i in range(21)]], 0.011, "hand_r", IRON))
for k in range(5):
    rr = np.random.RandomState(20 + k)
    radd(GK.slab("Salt", HR + G(rr.uniform(-0.06, 0.06), -0.69 + rr.uniform(-0.02, 0.01), rr.uniform(-0.05, 0.05)), (0.025, 0.022, 0.03), Matrix.Rotation(k, 3, 'Z').to_quaternion(), "hand_r", SALT, 0.0, 0.2, k, 8, 6, 0.4))
# the chain hand: a gaunt, big-knuckled fist closed round a link, the chain leaving the bottom of it (rigid, on the hand socket, so it moves with the hand)
radd(K.blob("Fist", HR + Vector(G(0.0, -0.05, 0.0)), (0.058, 0.066, 0.062), "hand_r", SKIN, 16, 12))
for k in range(4):
    radd(K.blob("Knuckle", HR + Vector(G(0.0, 0.0 - 0.028 * k, -0.052)), (0.026, 0.018, 0.02), "hand_r", SKIN, 10, 8))
radd(K.loft("Thumb", [HR + Vector(G(0.04, 0.0, -0.01)), HR + Vector(G(0.025, -0.03, -0.06)), HR + Vector(G(-0.005, -0.06, -0.062))], [0.016, 0.014, 0.012], "hand_r", SKIN, 7))
for o in rig_r:
    add(o)

# --- the lantern (left hand): a caged lamp, hot inside (rigid) ---------------------------------------------------------------
HL = S["hand_l"] + Vector(G(-ARMOUT, 0.0, 0.0))
for o in (TUBE("Handle", [HL + G(0, -0.02, 0), HL + G(0, -0.1, 0.0), HL + G(0, -0.15, 0)], 0.0075, "hand_l", IRON),
          K.blob("Cap", HL + G(0, -0.15, 0), (0.055, 0.02, 0.055), "hand_l", IRON, 14, 8), K.blob("Base", HL + G(0, -0.32, 0), (0.05, 0.02, 0.05), "hand_l", IRON, 14, 8),
          K.blob("Flame", HL + G(0, -0.23, 0), (0.045, 0.065, 0.045), "hand_l", GLOW, 12, 10)):
    o["sock"] = "hand_l"
    add(o)
for k in range(6):
    a = math.tau * k / 6.0
    o = TUBE("Bar", [HL + G(math.cos(a) * 0.055, -0.15, math.sin(a) * 0.055), HL + G(math.cos(a) * 0.075, -0.23, math.sin(a) * 0.075), HL + G(math.cos(a) * 0.055, -0.31, math.sin(a) * 0.055)], 0.0045, "hand_l", IRON)
    o["sock"] = "hand_l"
    add(o)
# the lamp hand: a closed fist round the lamp's ring, knuckles forward
for o in (K.blob("Fist", HL + Vector(G(0.0, -0.05, 0.0)), (0.058, 0.066, 0.062), "hand_l", SKIN, 16, 12),
          K.loft("Thumb", [HL + Vector(G(-0.04, 0.0, -0.01)), HL + Vector(G(-0.025, -0.03, -0.06)), HL + Vector(G(0.005, -0.06, -0.062))], [0.016, 0.014, 0.012], "hand_l", SKIN, 7)):
    o["sock"] = "hand_l"
    add(o)
for k in range(4):
    o = K.blob("Knuckle", HL + Vector(G(0.0, 0.0 - 0.028 * k, -0.052)), (0.026, 0.018, 0.02), "hand_l", SKIN, 10, 8)
    o["sock"] = "hand_l"
    add(o)
o = L.thorn("Spike", HL + G(0, -0.34, 0), Vector(G(0, -1, 0)), 0.04, 0.012, Vector((0, 0, 0)), "hand_l", IRON, 5, 4, 1.0)
add(o)

print("ANCHORESS parts", len(objs), "tris", sum(L.tri_count(o) for o in objs))
_t = {}
for o in objs:
    _t[o["sock"]] = _t.get(o["sock"], 0) + L.tri_count(o)
print("TRIS by part", _t)
if REVIEW:
    os.makedirs(os.path.dirname(REVIEW), exist_ok=True)
if REVIEW and not EXPORT:
    L.drop_highs(PAIRS)
    if "--close" in args:
        L.turnarounds(REVIEW + "_hands", 0.85, 2.2, angles=(("a", 75), ("b", 100)), samples=32, size=(700, 700), cam_z=0.9)
        L.turnarounds(REVIEW + "_head", 1.65, 1.6, angles=(("a", 80), ("b", 40)), samples=32, size=(700, 700), cam_z=1.65)
    L.turnarounds(REVIEW + "_raw", 1.0, 5.6, angles=(("front", 90), ("three", 45), ("side", 0), ("back", -90)), samples=32, size=(700, 940), cam_z=1.3)
if EXPORT:
    L.export_skinned2(objs, MATS, "boss_anchoress", S, WEIGHTS, {"hand_r": ("chain_hand_r", S["hand_r"]), "hand_l": ("lamp_hand_l", S["hand_l"])}, 4096 if not LOWRES else 1024, PAIRS)
    L.drop_highs(PAIRS)
    if REVIEW:
        L.use_atlas("boss_anchoress")
        arm = bpy.data.objects["Armature"]
        L.turnarounds(REVIEW + "_turn", 1.0, 5.6, cam_z=1.3)
        for nm, rots in L.POSES.items():
            L.reset_pose(arm)
            L.pose(arm, rots)
            L.turnarounds(REVIEW + "_" + nm, 1.0, 5.6, angles=(("front", 90), ("three", 45), ("side", 0)), cam_z=1.3)
