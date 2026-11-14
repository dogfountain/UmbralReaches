"""The common enemies built the way the wanderer and the bosses are now: clean garment and plate geometry in tiling
materials (boss_look.gd), vertex-colour tints, glow painted in, faces as hoods, masks and helms with lit eyes.
No sculpted blobs, no baked atlas. Each kind is skinned to the flat socket armature its procedural rig drives
(HunchRig for the two-legged ones), so the game's animation carries it unchanged (grunt_skin.gd).

    tools/blender/run.sh grunt_build.py -- [--only wretch,husk] [--look <dir>]

Writes art/models/grunt_<kind>.glb. Rig space: x right, y up, z back, facing -Z, metres.
"""
import bpy
import math
import os
import sys
import numpy as np
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import boss_build as B
from boss_build import Geo, V, TAU

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(name, default=None):
    return ARGS[ARGS.index(name) + 1] if name in ARGS else default


def bl(p):
    return Vector((p[0], -p[2], p[1]))


SOCK = {"pelvis": V(0, 0.94, 0), "chest": V(0, 1.28, 0), "head": V(0, 1.64, 0)}
for _t, _sx in (("l", -1), ("r", 1)):
    SOCK.update({"shoulder_" + _t: V(_sx * 0.24, 1.40, 0), "elbow_" + _t: V(_sx * 0.24, 1.08, 0), "hand_" + _t: V(_sx * 0.24, 0.78, 0),
                 "hip_" + _t: V(_sx * 0.11, 0.75, 0), "knee_" + _t: V(_sx * 0.11, 0.33, 0), "foot_" + _t: V(_sx * 0.11, -0.09, 0)})


def side(sx):
    return "l" if sx < 0 else "r"


# --- shared parts --------------------------------------------------------------------------------------

def legs(g, col, mat="wool", boot=(0.16, 0.12, 0.1), boot_mat="leather", r=(0.075, 0.06, 0.05)):
    for sx in (-1, 1):
        t = side(sx)
        g.tube([V(sx * 0.11, 0.98, 0.0), V(sx * 0.11, 0.75, 0.0), V(sx * 0.11, 0.55, -0.01)], [r[0] * 1.15, r[0], r[0] * 0.92], col, mat, "hip_" + t, n=12)
        g.tube([V(sx * 0.11, 0.55, -0.01), V(sx * 0.11, 0.33, -0.02), V(sx * 0.11, 0.06, 0.0)], [r[1] * 1.08, r[1], r[2]], col, mat, "knee_" + t, n=12)
        g.box(V(sx * 0.11, -0.035, -0.04), (0.055, 0.045, 0.1), boot, boot_mat, "foot_" + t)
        g.lathe([(r[2] * 1.4, 0.0), (r[2] * 1.5, 0.05), (r[2] * 1.25, 0.12)], V(sx * 0.11, 0.02, 0.0), boot, boot_mat, "foot_" + t, n=12)


def arms(g, col, mat="wool", r=(0.055, 0.045, 0.035)):
    for sx in (-1, 1):
        t = side(sx)
        g.tube([V(sx * 0.2, 1.43, 0.0), V(sx * 0.24, 1.36, 0.0), V(sx * 0.24, 1.2, 0.0), V(sx * 0.24, 1.08, 0.0)], [r[0] * 1.3, r[0] * 1.1, r[0], r[0] * 0.9], col, mat, "shoulder_" + t, n=12)
        g.tube([V(sx * 0.24, 1.08, 0.0), V(sx * 0.24, 0.92, -0.01), V(sx * 0.24, 0.8, 0.0)], [r[1], r[1] * 0.95, r[2]], col, mat, "elbow_" + t, n=12)


def hood(g, col, dark=(0.015, 0.015, 0.02), eye=(1.0, 0.6, 0.25, 0.0), peak=0.0, open_=38, low=1.48, eye_r=0.015, face_y=1.7):
    rings = [(low, 0.2, 0.17, 0.02), (low + 0.1, 0.18, 0.16, 0.015), (1.7, 0.165, 0.17, 0.0), (1.82, 0.15, 0.165, 0.008), (1.9, 0.11, 0.13, 0.025),
             (1.95 + peak * 0.5, 0.05, 0.07, 0.04 + peak * 0.3), (1.97 + peak, 0.01, 0.015, 0.05 + peak * 0.6)]
    g.robe(rings, col, "wool", lambda p: "head" if p[1] > 1.58 else "chest", n=40, t0=math.radians(open_), t1=TAU - math.radians(open_), pleats=6, pleat_amp=0.04)
    g.ball(V(0.0, face_y, 0.0), 0.128, dark, "iron", "head", n=10, sy=1.12)
    B.eyes(g, face_y + 0.015, -0.115, 0.045, eye_r, eye)


def mantle(g, col, trim=None, y0=1.56, y1=1.16, r1=0.36, tatter=0.04):
    rings = [(y0, 0.2, 0.15, 0.01), (y0 - 0.06, 0.28, 0.19, 0.01), (y0 - 0.16, 0.32, 0.22, 0.02), ((y0 + y1) * 0.5 - 0.1, r1 * 0.95, r1 * 0.7, 0.03), (y1, r1, r1 * 0.75, 0.03)]
    g.robe(rings, col, "wool", "chest", n=60, pleats=8, pleat_amp=0.05, pleat_from=y0 - 0.06, tatter=tatter)
    if trim:
        g.ring_band(y1 + 0.02, y1 + 0.07, r1 * 1.01, r1 * 0.76, 0.03, trim, "trim", "chest", n=60)


def robe_body(g, col, hem=0.05, waist=1.0, flare=0.4, pleats=16, amp=0.07, tatter=0.0, belt=None, trim=None):
    rings = [(1.5, 0.18, 0.125, 0.0), (1.38, 0.2, 0.14, 0.0), (1.22, 0.195, 0.145, 0.0), (waist + 0.04, 0.17, 0.135, 0.0), (waist, 0.17, 0.13, 0.0),
             (waist - 0.15, 0.2 + flare * 0.1, 0.16 + flare * 0.1, 0.0), (0.55, 0.22 + flare * 0.3, 0.19 + flare * 0.3, 0.01), (hem + 0.15, 0.25 + flare * 0.45, 0.22 + flare * 0.45, 0.02),
             (hem, 0.26 + flare * 0.5, 0.23 + flare * 0.5, 0.02)]
    g.robe(rings, col, "wool", B.waist_split(waist - 0.02), n=96, pleats=pleats, pleat_amp=amp, pleat_from=waist, tatter=tatter, hem_break=0.02 if hem < 0.06 else 0.0)
    if belt:
        g.ring_band(waist - 0.02, waist + 0.05, 0.178, 0.138, 0.0, belt, "leather", "chest", n=48)
    if trim:
        r = rings[-2]
        g.ring_band(hem + 0.04, hem + 0.12, r[1] * 1.03, r[2] * 1.03, r[3], trim, "trim", "pelvis", n=96)
    return rings


def strap(g, pts, col, lab="chest", w=0.035):
    g.band(pts, w, col, "leather", lab, out=0.01, up=[V(0, 0, -1) if p[2] < 0 else V(0, 0, 1) for p in pts])


# --- the kinds -----------------------------------------------------------------------------------------
# Each reads in silhouette at 15 m, and by what it carries says what it does.

def wretch():
    """A starved scavenger bent under its load: rags over a thin frame, a sack and a gaff, a hood with two coals."""
    g = Geo()
    RAG, SKIN, SACK, BELT = (0.3, 0.26, 0.22), (0.36, 0.3, 0.27), (0.4, 0.33, 0.24), (0.2, 0.14, 0.1)
    legs(g, SKIN, "leather", boot=(0.16, 0.12, 0.09), r=(0.06, 0.05, 0.04))
    for sx in (-1, 1):
        t = side(sx)
        for k in range(3):                                                 # wrappings round the shins
            y = 0.12 + 0.12 * k
            g.lathe([(0.057, 0.0), (0.06, 0.025), (0.056, 0.05)], V(sx * 0.11, y, 0.0), RAG, "wool", "knee_" + t, n=12)
    robe_body(g, RAG, hem=0.48, waist=1.0, flare=0.25, pleats=10, amp=0.09, tatter=0.18, belt=BELT)
    arms(g, SKIN, "leather", r=(0.045, 0.037, 0.03))
    for sx in (-1, 1):
        B.hand(g, sx, (0.45, 0.38, 0.33), "hand_" + side(sx), closed=0.6)
    mantle(g, RAG, y1=1.2, r1=0.3, tatter=0.1)
    hood(g, RAG, eye=(1.0, 0.45, 0.15, 0.0), eye_r=0.012)
    # the sack: hung on the back from two straps, tied at the neck, things poking out
    S = V(0.0, 1.22, 0.28)
    g.ball(S, 0.24, SACK, "linen", "chest", n=12, sx=1.0, sy=1.15, sz=0.8)
    g.lathe([(0.08, 0.0), (0.05, 0.05), (0.08, 0.12)], S + V(0, 0.26, -0.02), SACK, "linen", "chest", n=12)
    g.lathe([(0.055, 0.0), (0.058, 0.03)], S + V(0, 0.27, -0.02), BELT, "leather", "chest", n=12)
    g.tube([S + V(-0.05, 0.3, 0.0), S + V(-0.12, 0.62, 0.05)], 0.018, (0.3, 0.22, 0.14), "wood", "chest", n=6)
    g.tube([S + V(0.06, 0.28, 0.0), S + V(0.14, 0.52, 0.02)], 0.014, (0.3, 0.22, 0.14), "wood", "chest", n=6)
    g.ball(S + V(0.14, 0.05, 0.16), 0.07, (0.18, 0.16, 0.15), "iron", "chest", n=8)                    # a pot
    for sx in (-1, 1):
        strap(g, [V(sx * 0.13, 1.5, -0.13), V(sx * 0.15, 1.38, -0.17), V(sx * 0.14, 1.12, -0.16), V(sx * 0.16, 1.0, 0.0), V(sx * 0.15, 1.12, 0.18)], BELT)
    # the gaff, in the right hand
    gf = Geo()
    gf.tube([V(0, -0.5, -0.03), V(0, 0.9, -0.03)], 0.016, (0.28, 0.2, 0.13), "wood", "hand_r", n=8)
    gf.tube([V(0, 0.9, -0.03), V(0, 1.0, -0.06), V(0, 1.02, -0.14), V(0, 0.96, -0.2), V(0, 0.9, -0.19)], [0.014, 0.012, 0.01, 0.008, 0.002], (0.35, 0.33, 0.32), "iron", "hand_r", n=8)
    return g.to_object("body"), [gf.to_object("staff_hand_r")]


def husk():
    """A gravedigger grown huge: a long stained coat strained over a barrel of a body, an ember split where it is torn,
    a sacking cowl with two coals in it, a coffin lid strapped on the back."""
    g = Geo()
    COAT, SACK, SKIN, LID, BELT = (0.2, 0.15, 0.11), (0.36, 0.3, 0.22), (0.42, 0.36, 0.32), (0.22, 0.16, 0.11), (0.12, 0.09, 0.07)
    legs(g, (0.18, 0.15, 0.13), "wool", boot=(0.12, 0.1, 0.08), r=(0.1, 0.085, 0.07))
    coat = [(1.55, 0.26, 0.2, 0.02), (1.45, 0.34, 0.27, 0.02), (1.3, 0.37, 0.31, 0.0), (1.12, 0.38, 0.33, -0.02), (0.96, 0.36, 0.31, -0.02),
            (0.8, 0.34, 0.29, -0.01), (0.55, 0.36, 0.31, 0.0), (0.38, 0.38, 0.33, 0.0)]
    g.robe(coat, COAT, "leather", B.waist_split(0.9), n=72, t0=math.radians(10), t1=TAU - math.radians(10), pleats=8, pleat_amp=0.05, pleat_from=0.9, tatter=0.08)
    g.ring_band(0.92, 1.0, 0.365, 0.315, -0.02, BELT, "leather", "chest", n=72)
    g.tube([V(0.0, 1.0, -0.36), V(0.0, 1.24, -0.355)], 0.02, (1.0, 0.45, 0.12, 0.0), "glow", "chest", n=6)        # the split, through the gap
    for k in range(4):
        y = 1.03 + 0.06 * k
        g.tube([V(-0.05, y, -0.35), V(0.05, y + 0.01, -0.35)], 0.007, (0.1, 0.08, 0.06), "leather", "chest", n=4)
    for sx in (-1, 1):
        B.sleeve(g, sx, COAT, BELT, r_top=0.12, r_cuff=0.11, drop=0.02)
        B.hand(g, sx, SKIN, "hand_" + side(sx), closed=0.9)
    hood(g, SACK, eye=(1.0, 0.5, 0.15, 0.0), low=1.5, face_y=1.66, eye_r=0.017)
    def lid(u, v):
        w = 0.26 * (1.0 - 0.35 * abs(v - 0.7))
        return V((u - 0.5) * 2.0 * w, 0.75 + 0.95 * v, 0.36 + 0.03 * math.sin(u * math.pi))
    g.plate(lid, 5, 7, LID, "wood", "chest")
    g.tube([V(-0.12, 1.4, 0.39), V(0.12, 1.4, 0.39)], 0.014, (0.45, 0.4, 0.38), "iron", "chest", n=5)
    g.tube([V(0.0, 1.27, 0.39), V(0.0, 1.55, 0.39)], 0.014, (0.45, 0.4, 0.38), "iron", "chest", n=5)
    for sx in (-1, 1):
        strap(g, [V(sx * 0.16, 1.55, -0.22), V(sx * 0.24, 1.48, -0.28), V(sx * 0.34, 1.25, -0.1), V(sx * 0.3, 1.3, 0.33)], BELT)
    return g.to_object("body"), []


def hooded(robe_col, mantle_col, eye, trim=None, belt=(0.16, 0.11, 0.08), peak=0.0, hem=0.05, flare=0.4, tatter=0.04, arms_col=(0.42, 0.38, 0.34), hands=True):
    g = Geo()
    robe_body(g, robe_col, hem=hem, flare=flare, tatter=tatter, belt=belt, trim=trim)
    for sx in (-1, 1):
        B.sleeve(g, sx, robe_col, trim or belt, r_top=0.08, r_cuff=0.13, drop=0.12)
        if hands:
            B.hand(g, sx, arms_col, "hand_" + side(sx), closed=0.5)
    mantle(g, mantle_col, trim, tatter=tatter)
    hood(g, mantle_col, eye=eye, peak=peak)
    return g


def chanter():
    """A tall hooded caster in green-black, bone charms on cords, a caged corpse-light raised on a staff."""
    G1, G2, BONE = (0.13, 0.16, 0.11), (0.08, 0.1, 0.07), (0.8, 0.75, 0.62)
    g = hooded(G1, G2, (0.6, 1.0, 0.4, 0.0), trim=(0.55, 0.62, 0.3), peak=0.12)
    for k, x in enumerate((-0.12, -0.04, 0.05, 0.13)):
        y = 1.02 - 0.06 * (k % 2)
        g.tube([V(x, 1.0, -0.15), V(x, y - 0.12, -0.17)], 0.003, (0.3, 0.25, 0.18), "leather", "pelvis", n=4)
        g.box(V(x, y - 0.16, -0.17), (0.012, 0.03, 0.006), BONE, "bone", "pelvis")
    st = Geo()
    st.tube([V(0, -0.78, -0.03), V(0, 1.0, -0.03)], 0.016, (0.2, 0.16, 0.12), "wood", "hand_r", n=8)
    C = V(0, 1.14, -0.03)
    st.ball(C, 0.05, (0.6, 1.0, 0.45, 0.0), "glow", "hand_r", n=8)
    for k in range(6):
        a = TAU * k / 6
        st.tube([C + V(math.cos(a) * 0.075 * math.sin(p), -0.1 * math.cos(p), math.sin(a) * 0.075 * math.sin(p)) for p in np.linspace(0.1, math.pi - 0.1, 7)], 0.005, (0.3, 0.3, 0.25), "iron", "hand_r", n=4)
    return g.to_object("body"), [st.to_object("staff_hand_r")]


def tollman():
    """Broad and stooped in a black coat with a yoke, a deep cowl, the toll-rope at the belt, the iron bell in hand."""
    COAT, CAPE, ROPE = (0.08, 0.075, 0.075), (0.11, 0.1, 0.1), (0.5, 0.42, 0.3)
    g = hooded(COAT, CAPE, (1.0, 0.65, 0.3, 0.0), trim=(0.5, 0.35, 0.2), hem=0.1, flare=0.55)
    g.tube([V(0.17, 1.0, -0.08), V(0.22, 0.85, -0.12), V(0.2, 0.62, -0.1), V(0.24, 0.4, -0.06)], 0.012, ROPE, "leather", "pelvis", n=6)
    b = Geo()
    b.tube([V(0, 0.06, -0.03), V(0, -0.1, -0.03)], 0.014, (0.25, 0.18, 0.12), "wood", "hand_r", n=6)
    b.lathe([(0.0, -0.14), (0.05, -0.15), (0.07, -0.22), (0.1, -0.33), (0.115, -0.37), (0.105, -0.36)], V(0, 0.0, -0.03), (0.16, 0.15, 0.15), "iron", "hand_r", n=18)
    return g.to_object("body"), [b.to_object("bell_hand_r")]


def pilgrim():
    """A bent pilgrim in a travelling cloak with a scallop at the breast, a pack and bedroll, a crooked staff."""
    CLOAK, ROBE, PACK = (0.32, 0.27, 0.2), (0.24, 0.2, 0.16), (0.3, 0.22, 0.15)
    g = hooded(ROBE, CLOAK, (1.0, 0.75, 0.4, 0.0), belt=(0.2, 0.14, 0.1), hem=0.12, tatter=0.08)
    g.lathe([(0.0, 0.0), (0.05, 0.004), (0.045, 0.012)], V(0.0, 1.36, -0.18), (0.85, 0.8, 0.7), "bone", "chest", n=12, axis="z")
    g.box(V(0.0, 1.2, 0.24), (0.17, 0.2, 0.08), PACK, "leather", "chest")
    g.tube([V(-0.2, 1.43, 0.26), V(0.2, 1.43, 0.26)], 0.07, (0.4, 0.33, 0.24), "wool", "chest", n=12)
    st = Geo()
    st.tube([V(0, -0.8, -0.03), V(0, 0.4, -0.03), V(0.02, 0.9, -0.04), V(0.0, 1.05, -0.02), V(-0.06, 1.1, -0.04)], [0.02, 0.019, 0.018, 0.016, 0.01], (0.3, 0.22, 0.14), "wood", "hand_r", n=8)
    st.ball(V(0.03, 0.7, -0.07), 0.05, (0.5, 0.42, 0.25), "leather", "hand_r", n=8, sy=1.3)
    return g.to_object("body"), [st.to_object("staff_hand_r")]


def gaunt():
    """Too tall and too thin under a grey shroud that clings to the head, ribs through a torn shift, hands to the knees."""
    g = Geo()
    SHROUD, SKIN = (0.36, 0.37, 0.4), (0.5, 0.48, 0.47)
    legs(g, SKIN, "leather", r=(0.05, 0.042, 0.032))
    g.ball(V(0.0, 1.25, 0.0), 0.17, SKIN, "leather", "chest", n=12, sx=0.9, sy=1.6, sz=0.7)
    for k in range(6):
        y = 1.12 + 0.05 * k
        for sx in (-1, 1):
            g.tube([V(sx * 0.03, y, -0.115), V(sx * 0.12, y - 0.02, -0.08), V(sx * 0.15, y - 0.05, 0.0)], 0.009, (0.6, 0.58, 0.55), "bone", "chest", n=4)
    robe_body(g, SHROUD, hem=0.4, flare=0.15, pleats=10, amp=0.08, tatter=0.25)
    arms(g, SKIN, "leather", r=(0.04, 0.034, 0.028))
    for sx in (-1, 1):
        t = side(sx)
        g.tube([V(sx * 0.24, 0.8, 0.0), V(sx * 0.24, 0.62, -0.02)], [0.028, 0.024], SKIN, "leather", "hand_" + t, n=8)
        for k in range(4):
            fx = (k - 1.5) * 0.016
            g.tube([V(sx * 0.24 + fx, 0.62, -0.02), V(sx * 0.24 + fx, 0.48, -0.03), V(sx * 0.24 + fx, 0.4, -0.01)], [0.008, 0.006, 0.002], SKIN, "leather", "hand_" + t, n=5)
    mantle(g, SHROUD, y1=1.05, r1=0.28, tatter=0.2)
    hood(g, SHROUD, eye=(0.75, 0.85, 1.0, 0.0), open_=30, eye_r=0.011, peak=0.05)
    return g.to_object("body"), []


def quiller():
    """A shrouded marksman: hooded, bound at the forearms, a quiver of long rib-darts on the back."""
    SH, RAG = (0.27, 0.29, 0.3), (0.2, 0.2, 0.2)
    g = hooded(RAG, SH, (0.7, 0.85, 1.0, 0.0), belt=(0.18, 0.13, 0.09), hem=0.3, flare=0.2, tatter=0.15)
    g.lathe([(0.07, 0.0), (0.075, 0.5), (0.065, 0.52)], V(0.1, 1.0, 0.22), (0.22, 0.16, 0.11), "leather", "chest", n=12)
    for k in range(6):
        a = TAU * k / 6
        g.tube([V(0.1 + math.cos(a) * 0.035, 1.45, 0.22 + math.sin(a) * 0.035), V(0.1 + math.cos(a) * 0.045, 1.72, 0.25 + math.sin(a) * 0.04)], [0.007, 0.002], (0.85, 0.8, 0.7), "bone", "chest", n=4)
    strap(g, [V(-0.14, 1.5, -0.13), V(0.0, 1.25, -0.17), V(0.16, 1.02, -0.13)], (0.16, 0.11, 0.08))
    d = Geo()
    d.tube([V(0, 0.02, -0.03), V(0, 0.42, -0.03)], [0.008, 0.002], (0.85, 0.8, 0.7), "bone", "hand_r", n=5)
    return g.to_object("body"), [d.to_object("staff_hand_r")]


def ossuant():
    """A walking reliquary of fused bone: ribs as a breastplate, femur greaves, a skull helm crested with ribs."""
    g = Geo()
    BONE, OLD, DARK = (0.82, 0.76, 0.62), (0.6, 0.55, 0.44), (0.02, 0.02, 0.025)
    legs(g, DARK, "iron", boot=(0.6, 0.55, 0.44), boot_mat="bone", r=(0.07, 0.06, 0.05))
    for sx in (-1, 1):
        t = side(sx)
        g.tube([V(sx * 0.11, 0.92, -0.08), V(sx * 0.11, 0.58, -0.085)], [0.035, 0.03], BONE, "bone", "hip_" + t, n=8)
        g.tube([V(sx * 0.11, 0.52, -0.075), V(sx * 0.11, 0.1, -0.07)], [0.032, 0.026], BONE, "bone", "knee_" + t, n=8)
    g.ball(V(0.0, 1.22, 0.0), 0.22, DARK, "iron", "chest", n=12, sy=1.3, sz=0.8)
    g.tube([V(0.0, 0.95, 0.17), V(0.0, 1.55, 0.15)], 0.03, OLD, "bone", "chest", n=8)
    for k in range(7):
        y = 0.98 + 0.075 * k
        for sx in (-1, 1):
            g.tube([V(sx * 0.02, y, -0.18), V(sx * 0.16, y - 0.015, -0.13), V(sx * 0.22, y - 0.03, 0.0), V(sx * 0.15, y - 0.02, 0.14)], [0.018, 0.016, 0.014, 0.01], BONE, "bone", "chest", n=6)
    g.box(V(0.0, 1.18, -0.19), (0.025, 0.24, 0.012), BONE, "bone", "chest")
    arms(g, DARK, "iron", r=(0.06, 0.05, 0.04))
    for sx in (-1, 1):
        t = side(sx)
        g.ball(V(sx * 0.27, 1.42, 0.0), 0.11, BONE, "bone", "shoulder_" + t, n=10, sy=0.6)
        g.tube([V(sx * 0.27, 1.06, -0.03), V(sx * 0.27, 0.82, -0.04)], [0.045, 0.04], BONE, "bone", "elbow_" + t, n=8)
        B.hand(g, sx, BONE, "hand_" + t, closed=0.7)
    g.lathe([(0.0, 1.86), (0.08, 1.84), (0.125, 1.76), (0.135, 1.64), (0.12, 1.56), (0.1, 1.53)], V(0.0, 0.0, 0.0), BONE, "bone", "head", n=18)
    g.ball(V(0.0, 1.66, 0.0), 0.11, DARK, "iron", "head", n=8)
    def face(u, v):
        th = (u - 0.5) * math.radians(100)
        tooth = abs(((u * 8.0) % 1.0) - 0.5) * 2.0
        y = 1.71 - 0.17 * v - (0.015 * tooth if v > 0.95 else 0.0)
        return V(math.sin(th) * 0.13, y, -math.cos(th) * 0.135)
    g.plate(face, 17, 5, BONE, "bone", "head")
    B.eyes(g, 1.68, -0.125, 0.048, 0.012, (1.0, 0.8, 0.45, 0.0))
    for k in range(7):
        a = (k - 3) * 0.14
        g.tube([V(math.sin(a) * 0.08, 1.74, math.cos(a) * 0.04), V(math.sin(a) * 0.15, 2.02 - abs(k - 3) * 0.04, 0.1 + math.cos(a) * 0.05)], [0.014, 0.003], BONE, "bone", "head", n=5)
    return g.to_object("body"), []


def bulwark():
    """Plate over quilting: a great helm with a lit slit, pauldrons of lames, a tower of planks and iron as a shield."""
    g = Geo()
    IRON, QUILT, WOOD, BAND = (0.26, 0.26, 0.28), (0.3, 0.24, 0.18), (0.32, 0.22, 0.14), (0.2, 0.2, 0.22)
    legs(g, QUILT, "wool", boot=IRON, boot_mat="iron", r=(0.085, 0.07, 0.06))
    for sx in (-1, 1):
        t = side(sx)
        g.lathe([(0.088, 0.0), (0.094, 0.15), (0.088, 0.3)], V(sx * 0.11, 0.55, -0.005), IRON, "iron", "hip_" + t, n=14)
        g.lathe([(0.072, 0.0), (0.078, 0.18), (0.068, 0.36)], V(sx * 0.11, 0.06, -0.01), IRON, "iron", "knee_" + t, n=14)
        g.ball(V(sx * 0.11, 0.38, -0.06), 0.06, IRON, "iron", "knee_" + t, n=8, sz=0.7)
    robe_body(g, QUILT, hem=0.55, flare=0.15, pleats=8, amp=0.03)
    g.ball(V(0.0, 1.25, -0.01), 0.27, IRON, "iron", "chest", n=14, sx=1.0, sy=1.05, sz=0.82)
    g.ring_band(0.97, 1.05, 0.25, 0.21, 0.0, (0.18, 0.13, 0.09), "leather", "chest", n=48)
    for k in range(3):
        g.ring_band(0.86 - 0.09 * k, 0.94 - 0.09 * k, 0.26 + 0.02 * k, 0.22 + 0.02 * k, 0.0, IRON, "iron", "pelvis", n=48)
    arms(g, QUILT, "wool", r=(0.075, 0.065, 0.055))
    for sx in (-1, 1):
        t = side(sx)
        for k in range(3):
            g.ball(V(sx * (0.27 - 0.01 * k), 1.47 - 0.07 * k, 0.0), 0.15 - 0.015 * k, IRON, "iron", "shoulder_" + t, n=10, sy=0.45)
        g.lathe([(0.07, 0.0), (0.075, 0.2), (0.06, 0.28)], V(sx * 0.24, 0.82, 0.0), IRON, "iron", "elbow_" + t, n=12)
        g.box(V(sx * 0.24, 0.72, -0.02), (0.045, 0.06, 0.05), IRON, "iron", "hand_" + t)
    g.lathe([(0.0, 1.98), (0.1, 1.95), (0.14, 1.88), (0.145, 1.7), (0.14, 1.55), (0.13, 1.5)], V(0.0, 0.0, 0.0), IRON, "iron", "head", n=20)
    g.box(V(0.0, 1.76, -0.14), (0.09, 0.008, 0.008), (1.0, 0.55, 0.2, 0.0), "glow", "head")
    g.box(V(0.0, 1.7, -0.14), (0.008, 0.05, 0.008), (0.2, 0.2, 0.2), "iron", "head")
    for k in range(5):
        g.tube([V(0.0, 1.95, -0.06 + 0.04 * k), V(0.0, 2.08 - 0.02 * abs(k - 2), -0.05 + 0.045 * k)], [0.012, 0.002], IRON, "iron", "head", n=4)
    sh = Geo()
    def board(u, v):
        return V(-0.12 + (u - 0.5) * 0.72, 0.15 + v * 1.15, -0.2 - 0.06 * math.cos((u - 0.5) * math.pi))
    sh.plate(board, 9, 8, WOOD, "wood", "chest")
    for y in (0.3, 0.75, 1.15):
        sh.band([board(u, (y - 0.15) / 1.15) + V(0, 0, -0.012) for u in np.linspace(0.0, 1.0, 9)], 0.07, BAND, "iron", "chest", out=0.0, up=[V(0, 0, -1)] * 9)
    sh.lathe([(0.0, 0.0), (0.09, 0.0), (0.07, 0.05), (0.0, 0.1)], V(-0.12, 0.75, -0.27), IRON, "iron", "chest", n=14, axis="z")
    return g.to_object("body"), [sh.to_object("shield_chest")]


def spitter():
    """Thin and pale in a leather harness, a long neck, and a glowing sac in a cage at the throat."""
    g = Geo()
    SKIN, HARN = (0.55, 0.55, 0.5), (0.18, 0.13, 0.09)
    legs(g, SKIN, "leather", r=(0.055, 0.045, 0.035))
    g.ball(V(0.0, 1.2, 0.02), 0.2, SKIN, "leather", "chest", n=12, sy=1.3, sz=0.75)
    robe_body(g, (0.22, 0.2, 0.16), hem=0.55, flare=0.1, pleats=8, amp=0.06, tatter=0.15, belt=HARN)
    arms(g, SKIN, "leather", r=(0.045, 0.036, 0.03))
    for sx in (-1, 1):
        B.hand(g, sx, SKIN, "hand_" + side(sx), closed=0.4)
        strap(g, [V(sx * 0.12, 1.48, -0.1), V(-sx * 0.05, 1.2, -0.17), V(-sx * 0.15, 1.0, -0.12)], HARN)
    g.tube([V(0.0, 1.42, 0.0), V(0.0, 1.58, -0.08), V(0.0, 1.66, -0.12)], [0.06, 0.055, 0.05], SKIN, "leather", "head", n=10)
    g.ball(V(0.0, 1.7, -0.16), 0.1, SKIN, "leather", "head", n=10, sx=1.1, sy=0.7, sz=1.3)
    B.eyes(g, 1.73, -0.25, 0.05, 0.013, (0.4, 1.0, 0.7, 0.0))
    g.ball(V(0.0, 1.5, -0.13), 0.09, (0.4, 1.0, 0.7, 0.0), "glow", "head", n=10)
    for k in range(5):
        a = TAU * k / 5
        g.tube([V(math.cos(a) * 0.1 * math.sin(p), 1.5 - 0.1 * math.cos(p), -0.13 + math.sin(a) * 0.1 * math.sin(p)) for p in np.linspace(0.2, math.pi - 0.2, 6)], 0.007, HARN, "leather", "head", n=4)
    return g.to_object("body"), []


def cinder_caster():
    """A smith of the dead: a leather apron over a scorched coat, goggles in a hood, a ladle of slag that glows."""
    COAT, APRON, IRON = (0.17, 0.13, 0.11), (0.3, 0.2, 0.12), (0.2, 0.19, 0.19)
    g = hooded(COAT, COAT, (1.0, 0.5, 0.15, 0.0), belt=(0.16, 0.11, 0.08), hem=0.25, flare=0.25, tatter=0.06)
    def apron(u, v):
        th = (u - 0.5) * math.radians(90)
        return V(math.sin(th) * (0.2 + 0.1 * v), 1.4 - 1.05 * v, -math.cos(th) * (0.16 + 0.12 * v) - 0.02)
    g.plate(apron, 9, 9, APRON, "leather", lambda p: "chest" if p[1] > 0.95 else "pelvis")
    for sx in (-1, 1):
        g.lathe([(0.0, 0.0), (0.03, 0.0), (0.03, 0.02)], V(sx * 0.045, 1.75, -0.13), IRON, "iron", "head", n=10, axis="z")
        g.ball(V(sx * 0.045, 1.75, -0.155), 0.022, (1.0, 0.55, 0.2, 0.0), "glow", "head", n=6, sz=0.4)
    for k in range(6):
        a = k * 1.1
        g.box(V(math.sin(a) * 0.22, 0.7 + 0.08 * k, -math.cos(a) * 0.2), (0.04, 0.03, 0.02), (0.3, 0.12, 0.05, 0.4), "stone", "pelvis")
    l = Geo()
    l.tube([V(0, 0.05, -0.03), V(0, -0.3, -0.03), V(0, -0.5, -0.1)], 0.014, IRON, "iron", "hand_r", n=6)
    l.lathe([(0.0, -0.08), (0.07, -0.06), (0.08, 0.0), (0.075, 0.01)], V(0, -0.55, -0.16), IRON, "iron", "hand_r", n=14)
    l.ball(V(0, -0.555, -0.16), 0.06, (1.0, 0.45, 0.1, 0.0), "glow", "hand_r", n=8, sy=0.3)
    return g.to_object("body"), [l.to_object("staff_hand_r")]


# --- the four-legged kinds (QuadRig) -------------------------------------------------------------------

def quad_sockets(BH, BL, HSP, UL, upright):
    """Rest sockets of a QuadRig (core/enemy/quad_rig.gd), as the rig builds them."""
    s = {"body": V(0, BH, 0)}
    s["front"] = s["body"] + V(0, 0.04, -BL * 0.45)
    s["head"] = s["front"] + V(0, 0.03, -0.16)
    s["tail"] = s["body"] + V(0, 0.02, BL * 0.45)
    for tag, sx, front in (("fl", -1, True), ("fr", 1, True), ("bl", -1, False), ("br", 1, False)):
        z = -BL * 0.36 if front else BL * 0.34
        hip = s["body"] + V(sx * HSP, -0.02, z)
        if upright:
            seg = (BH - 0.05) * 0.5
            knee = hip + V(0, -seg, 0.06 if front else -0.08)
            foot = knee + V(0, -seg, -0.04 if front else 0.1)
        else:
            knee = hip + V(sx * UL, 0.1, 0.0)
            foot = knee + V(sx * 0.07, -(BH + 0.08), 0.0)
        s["leg_%s_hip" % tag], s["leg_%s_knee" % tag], s["leg_%s_foot" % tag] = hip, knee, foot
    return s


QSOCK = {"crawler": (0.34, 0.72, 0.14, 0.24, False), "mite": (0.34, 0.72, 0.14, 0.24, False),
         "burrower": (0.36, 1.05, 0.22, 0.24, False), "leaper": (0.56, 1.15, 0.2, 0.32, True)}


def quad_leg(g, S, tag, col, mat="bone", r=(0.035, 0.028, 0.012), spikes=0, spike_col=None, claw_col=None, extra=None):
    """A leg from hip to knee to foot, labelled in three, a claw at the foot; `extra` = (dz) adds a second leg beside it
    (spiders have eight: the extra pair rides the same bones)."""
    hip, knee, foot = S["leg_%s_hip" % tag], S["leg_%s_knee" % tag], S["leg_%s_foot" % tag]
    for dz in [0.0] + ([extra] if extra else []):
        o = V(0, 0, dz)
        g.tube([hip + o, (hip + knee) * 0.5 + o + V(0, 0.02, 0), knee + o], [r[0], r[0] * 0.95, r[1] * 1.1], col, mat, "leg_%s_hip" % tag, n=10)
        g.tube([knee + o, (knee + foot) * 0.5 + o, foot + o + V(0, 0.03, 0)], [r[1] * 1.1, r[1], r[2] * 1.4], col, mat, "leg_%s_knee" % tag, n=10)
        g.tube([foot + o + V(0, 0.03, 0), foot + o + V(0, -0.0, -0.03), foot + o + V(0, -0.01, -0.07)], [r[2] * 1.4, r[2], 0.002], claw_col or col, mat, "leg_%s_foot" % tag, n=6)
        g.ball(knee + o, r[1] * 1.35, col, mat, "leg_%s_knee" % tag, n=6)
        for k in range(spikes):
            p = knee + o + (foot - knee) * (0.2 + 0.25 * k)
            g.tube([p, p + V(0.03 * np.sign(p[0]), 0.035, 0.0)], [0.009, 0.001], spike_col or col, mat, "leg_%s_knee" % tag, n=4)


def shell(g, c, rx, ry, rz, col, mat, lab, bands=6, gap=0.012, flare=0.0, front=-1.0):
    """A segmented carapace: overlapping bands along z, each a half-shell with a lifted back edge."""
    for k in range(bands):
        z0 = -rz + 2.0 * rz * k / bands
        z1 = -rz + 2.0 * rz * (k + 1) / bands + gap * 2.0
        def band(u, v, z0=z0, z1=z1):
            th = (u - 0.5) * math.pi * 1.15
            z = z0 + (z1 - z0) * v
            t = z / rz
            prof = max(0.0, 1.0 - t * t) ** 0.5
            lift = 1.0 + 0.06 * v + flare * v
            return c + V(math.sin(th) * rx * prof * lift, math.cos(th) * ry * prof * lift - 0.0, z)
        g.plate(band, 15, 4, col, mat, lab)


def quad_part_label(S, keys):
    def f(p):
        return min(keys, key=lambda k: float(np.linalg.norm(p - S[k])))
    return f


def crawler():
    """A bone spider: a skull for a head, a banded carapace, a lit sac in a cage of ribs behind, eight jointed legs."""
    S = quad_sockets(*QSOCK["crawler"])
    g = Geo()
    BONE, CHIT, DARK = (0.78, 0.72, 0.6), (0.24, 0.2, 0.18), (0.03, 0.025, 0.03)
    lab = quad_part_label(S, ["front", "body", "tail"])
    shell(g, S["body"] + V(0, 0.04, -0.05), 0.17, 0.1, 0.2, CHIT, "iron", lab, bands=5)
    g.ball(S["body"] + V(0, 0.0, -0.05), 0.15, DARK, "iron", lab, n=10, sy=0.6, sz=1.4)
    sac = S["tail"] + V(0, 0.05, 0.06)
    g.ball(sac, 0.15, (1.0, 0.4, 0.15, 0.0), "glow", "tail", n=10, sy=0.85, sz=1.1)
    for k in range(5):
        a = -0.5 + k * 0.25
        g.tube([sac + V(math.sin(a) * 0.17 * math.sin(p), 0.17 * math.cos(p) * 0.85, math.cos(a) * 0.0 + (p - 1.57) * 0.1) for p in np.linspace(0.3, 2.9, 8)], 0.012, BONE, "bone", "tail", n=5)
    for k in range(6):
        p = sac + V(0, 0.0, -0.18 + 0.07 * k)
        g.tube([p + V(-0.18, -0.02, 0), p + V(-0.05, 0.16, 0), p + V(0.05, 0.16, 0), p + V(0.18, -0.02, 0)], 0.011, BONE, "bone", "tail", n=5)
    H = S["head"]
    g.ball(H + V(0, 0.0, 0.02), 0.085, BONE, "bone", "head", n=10, sx=1.15, sy=0.85, sz=1.0)
    g.ball(H + V(0, -0.03, -0.06), 0.055, BONE, "bone", "head", n=8, sx=1.0, sy=0.7)
    for sx in (-1, 1):
        g.ball(H + V(sx * 0.04, 0.015, -0.055), 0.02, DARK, "iron", "head", n=6)
        g.ball(H + V(sx * 0.04, 0.015, -0.066), 0.011, (1.0, 0.3, 0.15, 0.0), "glow", "head", n=5)
        g.tube([H + V(sx * 0.03, -0.05, -0.09), H + V(sx * 0.05, -0.09, -0.13), H + V(sx * 0.02, -0.12, -0.16)], [0.012, 0.008, 0.002], BONE, "bone", "head", n=5)
        g.tube([H + V(sx * 0.05, 0.05, 0.0), H + V(sx * 0.08, 0.12, 0.03), H + V(sx * 0.07, 0.16, 0.08)], [0.012, 0.007, 0.001], BONE, "bone", "head", n=5)
    for tag in ("fl", "fr", "bl", "br"):
        quad_leg(g, S, tag, BONE, "bone", r=(0.028, 0.022, 0.01), spikes=2, claw_col=DARK, extra=(0.1 if tag[0] == "f" else -0.1))
    return g.to_object("body"), [], S


def mite():
    """A blood-tick: a round cracked shell over a cyan sac that glows through its seams, a small armoured head, eight legs."""
    S = quad_sockets(*QSOCK["mite"])
    g = Geo()
    CHIT, DARK, GLOW = (0.32, 0.3, 0.34), (0.03, 0.03, 0.035), (0.3, 1.0, 0.85, 0.0)
    lab = quad_part_label(S, ["front", "body", "tail"])
    c = S["body"] + V(0, 0.03, 0.04)
    g.ball(c, 0.25, GLOW, "glow", lab, n=12, sy=0.7, sz=1.1)
    for k in range(8):                                                   # the shell: meridian plates with gaps of light
        a0 = TAU * k / 8 + 0.05
        def pl(u, v, a0=a0):
            a = a0 + u * (TAU / 8 - 0.12)
            ph = 0.15 + v * 1.25
            return c + V(math.cos(a) * math.sin(ph) * 0.27, math.cos(ph) * 0.2 + 0.0, math.sin(a) * math.sin(ph) * 0.29)
        g.plate(pl, 4, 7, CHIT, "iron", lab)
    H = S["head"] + V(0, -0.04, 0.06)
    g.ball(H, 0.075, CHIT, "iron", "head", n=8, sx=1.1, sy=0.75)
    for sx in (-1, 1):
        for k in (0, 1):
            g.ball(H + V(sx * (0.025 + 0.025 * k), 0.035, -0.055 + 0.015 * k), 0.012, GLOW, "glow", "head", n=5)
        g.tube([H + V(sx * 0.02, -0.03, -0.06), H + V(sx * 0.03, -0.06, -0.12)], [0.012, 0.002], DARK, "iron", "head", n=5)
    for tag in ("fl", "fr", "bl", "br"):
        quad_leg(g, S, tag, CHIT, "iron", r=(0.022, 0.018, 0.008), claw_col=DARK, extra=(0.1 if tag[0] == "f" else -0.1))
    return g.to_object("body"), [], S


def burrower():
    """A digger in banded stone-plate, like an armadillo of slate: a blunt shovel snout, amber deep in the seams,
    forelimbs ending in broad digging claws."""
    S = quad_sockets(*QSOCK["burrower"])
    g = Geo()
    PLATE, DARK, CLAW = (0.4, 0.38, 0.34), (0.03, 0.025, 0.02), (0.2, 0.19, 0.18)
    lab = quad_part_label(S, ["front", "body", "tail"])
    g.ball(S["body"] + V(0, -0.02, 0.0), 0.26, (1.0, 0.55, 0.2, 0.0), "glow", lab, n=10, sy=0.5, sz=2.0)
    shell(g, S["body"] + V(0, 0.0, 0.0), 0.3, 0.22, 0.5, PLATE, "stone", lab, bands=8, gap=0.015, flare=0.05)
    H = S["head"] + V(0, -0.05, 0.0)
    g.lathe([(0.0, 0.0), (0.1, 0.02), (0.13, 0.1), (0.11, 0.2), (0.06, 0.27), (0.0, 0.28)], H + V(0, 0, 0.12), PLATE, "stone", "head", n=14, axis="z", squash=0.7)
    for sx in (-1, 1):
        g.ball(H + V(sx * 0.06, 0.04, -0.06), 0.016, (1.0, 0.55, 0.2, 0.0), "glow", "head", n=5)
    g.lathe([(0.0, 0.0), (0.035, 0.0), (0.03, 0.06)], H + V(0, -0.02, -0.15), DARK, "iron", "head", n=10, axis="z")
    for tag in ("fl", "fr", "bl", "br"):
        quad_leg(g, S, tag, PLATE, "stone", r=(0.06, 0.05, 0.025), claw_col=CLAW)
        if tag[0] == "f":
            foot = S["leg_%s_foot" % tag]
            for k in range(3):
                g.tube([foot + V((k - 1) * 0.03, 0.03, -0.02), foot + V((k - 1) * 0.04, 0.0, -0.1), foot + V((k - 1) * 0.045, -0.02, -0.16)], [0.016, 0.012, 0.002], CLAW, "iron", "leg_%s_foot" % tag, n=6)
    tl = [S["tail"] + V(0, -0.02 - 0.03 * k, 0.08 * k) for k in range(5)]
    g.tube(tl, [0.1, 0.085, 0.065, 0.045, 0.01], PLATE, "stone", "tail", n=10)
    return g.to_object("body"), [], S


def leaper():
    """A bone-plated hound: a lean dark body, a skull for a face with coals in it, plates down the spine and over the
    shoulders and thighs, a heavy lash of a tail."""
    S = quad_sockets(*QSOCK["leaper"])
    g = Geo()
    HIDE, BONE, DARK = (0.12, 0.1, 0.1), (0.8, 0.74, 0.62), (0.02, 0.02, 0.02)
    lab = quad_part_label(S, ["front", "body", "tail"])
    spine = [S["tail"] + V(0, -0.02, 0.04), S["body"] + V(0, 0.04, 0.2), S["body"] + V(0, 0.07, -0.1), S["front"] + V(0, 0.05, 0.05), S["front"] + V(0, 0.08, -0.08)]
    g.tube(spine, [0.13, 0.15, 0.16, 0.17, 0.13], HIDE, "leather", lab, n=14, flat=1.15)
    for k in range(10):                                                  # spine plates
        t = k / 9
        p = spine[0] * (1 - t) + spine[-1] * t + V(0, 0.15 + 0.03 * math.sin(t * math.pi), 0)
        g.tube([p + V(0, -0.02, 0.04), p + V(0, 0.06, -0.02)], [0.025, 0.004], BONE, "bone", lab(p), n=5)
    for sx in (-1, 1):
        for (key, z, ln) in (("front", 0.06, 0.22), ("body", 0.28, 0.24)):
            c = S[key] + V(sx * 0.15, 0.02, z)
            def pl(u, v, c=c, sx=sx, ln=ln):
                return c + V(sx * (0.04 + 0.06 * math.sin(v * math.pi)), 0.1 - 0.2 * v, (u - 0.5) * ln)
            g.plate(pl, 5, 5, BONE, "bone", key, flip=sx > 0)
    H = S["head"]
    g.lathe([(0.0, -0.1), (0.07, -0.08), (0.085, 0.0), (0.06, 0.12), (0.035, 0.2), (0.0, 0.22)], H + V(0, 0.02, 0.0), BONE, "bone", "head", n=12, axis="z", squash=0.8)
    for sx in (-1, 1):
        g.ball(H + V(sx * 0.05, 0.04, -0.02), 0.02, DARK, "iron", "head", n=6)
        g.ball(H + V(sx * 0.05, 0.04, -0.033), 0.011, (1.0, 0.45, 0.15, 0.0), "glow", "head", n=5)
        g.tube([H + V(sx * 0.05, 0.08, 0.05), H + V(sx * 0.09, 0.14, 0.15), H + V(sx * 0.1, 0.13, 0.26)], [0.018, 0.012, 0.002], BONE, "bone", "head", n=6)
    for k in range(6):
        g.tube([H + V((k - 2.5) * 0.02, -0.035, -0.13 + 0.02 * abs(k - 2.5)), H + V((k - 2.5) * 0.02, -0.07, -0.13 + 0.02 * abs(k - 2.5))], [0.006, 0.001], BONE, "bone", "head", n=4)
    for tag in ("fl", "fr", "bl", "br"):
        quad_leg(g, S, tag, HIDE, "leather", r=(0.05, 0.035, 0.018), claw_col=BONE)
    tail = [S["tail"] + V(0, -0.02 - 0.06 * k * k * 0.1, 0.12 * k) for k in range(7)]
    g.tube(tail, [0.07, 0.06, 0.05, 0.04, 0.03, 0.02, 0.004], HIDE, "leather", "tail", n=10)
    g.tube([tail[-2], tail[-1] + V(0, 0.02, 0.12)], [0.03, 0.002], BONE, "bone", "tail", n=6)
    return g.to_object("body"), [], S


KINDS = {"wretch": wretch, "husk": husk, "chanter": chanter, "tollman": tollman, "pilgrim": pilgrim, "gaunt": gaunt, "quiller": quiller,
         "ossuant": ossuant, "bulwark": bulwark, "spitter": spitter, "cinder_caster": cinder_caster,
         "crawler": crawler, "mite": mite, "burrower": burrower, "leaper": leaper}


# --- skin and export -----------------------------------------------------------------------------------

def soften(ob, iters=3):
    """Blend the rigid part weights a little across the seams between parts, so a joint bends instead of tearing."""
    me = ob.data
    n = len(me.vertices)
    names = [g.name for g in ob.vertex_groups]
    W = np.zeros((n, len(names)))
    for v in me.vertices:
        for gr in v.groups:
            W[v.index, gr.group] = gr.weight
    e = np.empty(len(me.edges) * 2, dtype=np.int32)
    me.edges.foreach_get('vertices', e)
    e = e.reshape(-1, 2)
    cnt = np.maximum(np.bincount(e.ravel(), minlength=n), 1).astype(np.float64)
    for _ in range(iters):
        s = np.zeros_like(W)
        for k in range(W.shape[1]):
            s[:, k] = np.bincount(e[:, 0], weights=W[e[:, 1], k], minlength=n) + np.bincount(e[:, 1], weights=W[e[:, 0], k], minlength=n)
        W = 0.5 * W + 0.5 * s / cnt[:, None]
    W = W / np.maximum(W.sum(1, keepdims=True), 1e-9)
    for k, nm in enumerate(names):
        g = ob.vertex_groups[nm]
        g.remove(list(range(n)))
        sel = np.nonzero(W[:, k] > 0.02)[0]
        wq = np.round(W[sel, k] * 50.0) / 50.0
        for v in np.unique(wq):
            g.add(sel[wq == v].tolist(), float(v), 'REPLACE')


def armature(sock):
    data = bpy.data.armatures.new("Armature")
    ob = bpy.data.objects.new("Armature", data)
    bpy.context.scene.collection.objects.link(ob)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode='EDIT')
    for nm, at in sock.items():
        b = data.edit_bones.new(nm)
        b.head = bl(at)
        b.tail = bl(at) + Vector((0, 0, 0.06))
        b.roll = 0.0
    bpy.ops.object.mode_set(mode='OBJECT')
    return ob


def build_kind(kind):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    out = KINDS[kind]()
    body, held = out[0], out[1]
    sock = out[2] if len(out) > 2 else SOCK
    soften(body)
    arm = armature(sock)
    body.parent = arm
    md = body.modifiers.new("Armature", 'ARMATURE')
    md.object = arm
    for h in held:                                                            # held things: origin on their socket's joint
        if h.name.startswith("shield_"):                                     # (the shield is drawn in rig space)
            h.data.transform(__import__("mathutils").Matrix.Translation(-bl(sock[h.name.split("_", 1)[1]])))
    if arg("--look") and sock is SOCK:
        look(kind, [body] + held, arg("--look"))
    bpy.ops.object.select_all(action='DESELECT')
    for o in [arm, body] + held:
        o.select_set(True)
    bpy.context.view_layer.objects.active = arm
    path = os.path.join(ROOT, "art", "models", "grunt_%s.glb" % kind)
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True, export_apply=True, export_yup=True,
                              export_materials='EXPORT', export_vertex_color='ACTIVE', export_active_vertex_color_when_no_material=True,
                              export_normals=True, export_tangents=True, export_texcoords=True, export_skins=True, export_animations=False,
                              export_all_influences=False)
    tris = sum(len(p.vertices) - 2 for p in body.data.polygons)
    print("EXPORTED", kind, tris, "tris")


def look(kind, obs, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_WORKBENCH'
    sc.display.shading.light = 'STUDIO'
    sc.display.shading.color_type = 'VERTEX'
    sc.display.shading.show_cavity = True
    sc.display.shading.show_backface_culling = False
    sc.render.resolution_x, sc.render.resolution_y = 500, 760
    cam = bpy.data.objects.new("C", bpy.data.cameras.new("C"))
    cam.data.lens = 70
    sc.collection.objects.link(cam)
    sc.camera = cam
    held_sock = {}
    for o in obs[1:]:
        o.location = bl(SOCK[o.name.split("_", 1)[1]])
    for name, ang in (("front", 0.0), ("q34", 0.75)):
        cam.location = bl(V(math.sin(ang) * 6.0, 1.3, -math.cos(ang) * 6.0))
        cam.rotation_euler = (bl(V(0, 1.0, 0)) - cam.location).to_track_quat('-Z', 'Y').to_euler()
        sc.render.filepath = os.path.join(out_dir, "%s_%s.png" % (kind, name))
        bpy.ops.render.render(write_still=True)
    for o in obs[1:]:
        o.location = (0, 0, 0)
    bpy.data.objects.remove(cam)


def main():
    only = arg("--only")
    for k in (only.split(",") if only else KINDS):
        build_kind(k)


main()
