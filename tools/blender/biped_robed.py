"""Robed bipeds (r38 remodel): chanter, tollman, pilgrim. A sculpted body (biped_body.py) under garments that are
FITTED to it (biped_sculpt_lib.py): a pleated robe from collar to hem, a torn mantle, wide sleeves, a deep cowl with
a rolled lip, a rope belt with things hung on it, patches sewn on, and each kind's own carried thing (the Chanter's
caged corpse-light staff, the Tollman's black iron hand-bell, the Pilgrim's candle and staff). One atlas, one skinned
mesh; the bell is a rigid part on the right hand.

  GRUNT_OUT=<dir> tools/blender/run.sh biped_robed.py -- --kind chanter [--preview /tmp/c.png] [--no-export]
Writes grunt_<kind>.glb and grunt_<kind>_{albedo,normal,orm,emit}.png into GRUNT_OUT (default art/models / art/textures).
"""
import bpy
import bmesh
import math
import os
import sys
import numpy as np
from mathutils import Vector, noise

sys.path.insert(0, os.path.dirname(__file__))
import boss_kit as K
import grunt_kit as GK
import biped_sculpt_lib as L
import biped_body as BB
import biped_weights as BW
from boss_kit import G

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
KIND = args[args.index("--kind") + 1] if "--kind" in args else "chanter"
PREVIEW = args[args.index("--preview") + 1] if "--preview" in args else ""
EXPORT = "--no-export" not in args

K.reset()
BB.fast_ao(16)
BB.lean()
S = dict(K.SOCKETS)
sm = L.smooth

# --- per-kind design ---------------------------------------------------------------------------------------
D = {
    "chanter": dict(W=0.82, Lm=0.72, nk=0.07, finger=0.24, wrist=0.62, hc=(0, 1.7, -0.1), head_w=0.07, neck_r=0.04, hump=0.04, waist=0.9,
                    skin=((0.3, 0.36, 0.44), (0.06, 0.08, 0.12)), face=(0.4, 0.46, 0.54), eye=(0.45, 1.0, 0.3),
                    robe=(0.085, 0.09, 0.07), patch=(0.17, 0.15, 0.1), hem=0.06, tears=0.14, claw=0.08, hem_y=0.045, peak=0.15),
    "tollman": dict(W=0.9, Lm=0.8, nk=0.12, finger=0.2, wrist=0.64, hc=(0, 1.69, -0.13), head_w=0.07, neck_r=0.042, hump=0.07, waist=1.0,
                    skin=((0.32, 0.3, 0.3), (0.06, 0.055, 0.055)), face=(0.36, 0.34, 0.33), eye=(1.0, 0.72, 0.25),
                    robe=(0.19, 0.16, 0.115), patch=(0.12, 0.09, 0.06), hem=0.05, tears=0.1, claw=0.07, hem_y=0.22, peak=0.012),
    "pilgrim": dict(W=0.88, Lm=0.78, nk=0.04, finger=0.2, wrist=0.64, hc=(0, 1.7, -0.06), head_w=0.072, neck_r=0.042, hump=0.02, waist=0.95,
                    skin=((0.26, 0.24, 0.2), (0.055, 0.05, 0.04)), face=(0.3, 0.27, 0.22), eye=(1.0, 0.82, 0.4),
                    robe=(0.2, 0.17, 0.12), patch=(0.1, 0.08, 0.06), hem=0.07, tears=0.12, claw=0.06, hem_y=0.08, peak=0.035),
}[KIND]
Wd = D["W"]
nk, hump, wa, nkr = D["nk"], D["hump"], D["waist"], D["neck_r"]
HC = D["hc"]
FRONT = 1.5 * math.pi                                   # the grid angle that faces -Z (the front)

# --- materials ----------------------------------------------------------------------------------------------
SKIN = GK.hollow_skin("Skin", D["skin"][0], D["skin"][1], wet=0.25, wrinkle=62.0, vein_amt=0.55, liv=(0.78, 0.7, 0.9), extremities=0.5)
FACE = GK.hollow_skin("Face", D["face"], tuple(c * 0.3 for c in D["face"]), wet=0.15, wrinkle=90.0, liv=(0.78, 0.7, 0.9), extremities=0.0,
                      face_fade=(D["skin"][0], 1.7 - 0.1, 1.7 - 0.01))
CLAW = GK.grave_bone("Claw", (0.34, 0.3, 0.24), (0.1, 0.07, 0.05), 12.0)
EYE = GK.glow("Eye", D["eye"], 8.0)
ROBE = GK.cloth("Robe", D["robe"], "caban", 8.0, (0.035, 0.03, 0.02), 0.9)
MANTLE = GK.cloth("Mantle", tuple(c * 0.8 for c in D["robe"]), "rough_linen", 7.0, (0.03, 0.025, 0.02), 0.92)
PATCH = GK.cloth("Patch", D["patch"], "rough_linen", 11.0, (0.03, 0.025, 0.02), 0.92)
LEATHER = GK.leather("Leather", (0.14, 0.09, 0.06))
IRON = GK.iron("Iron", (0.075, 0.07, 0.07) if KIND == "tollman" else (0.12, 0.11, 0.11), (0.2, 0.09, 0.04))
BONE = GK.grave_bone("Bone", (0.64, 0.59, 0.48))
WOOD = GK.wood("Wood", (0.2, 0.13, 0.08), 0.5)
ROPE = GK.cloth("Rope", (0.3, 0.24, 0.16), "rough_linen", 30.0, (0.1, 0.08, 0.05), 0.9)
LIGHT = GK.glow("Glow", (1.0, 0.62, 0.2) if KIND == "pilgrim" else (0.45, 1.0, 0.3), 4.0)
MATS = [SKIN, CLAW, EYE, FACE, ROBE, MANTLE, PATCH, LEATHER, IRON, BONE, WOOD, ROPE, LIGHT]
for _m in (ROBE, MANTLE, PATCH, ROPE):
    L.soften(_m, 0.4)                                # the cloth bump is fine grain: it baked to fuzz

# --- the body ---------------------------------------------------------------------------------------------------
OPT = dict(W=Wd, L=D["Lm"], nk=nk, finger=D["finger"], wrist=D["wrist"], ribs=0.006, belly=-1.0, collar=1.3, tendon=1.4, hc=HC,
           jaw_w=0.04, brow=0.013, waist=wa, head_w=D["head_w"], neck_r=nkr, hump=hump)


def face_extra(sc, Y, nm):
    """The Chanter's face (a pale blank oval in shadow under the hood): brow ridge, deep sockets with lids, a nose with a flat
    bridge, hollow cheeks over standing cheekbones, a thin lipless mouth, a hard chin; strong enough to read at 8 cm of face."""
    if nm != "Body" or KIND != "chanter":
        return
    hy, hz = Y(HC[1]), HC[2]
    fz = hz - 0.086
    fr = (0, 0, -1)
    for sx_ in (-1, 1):
        sc.bump((sx_ * 0.032, hy + 0.012, fz + 0.004), 0.03, -0.05, facing=fr)                         # deep sockets
        sc.ridge((sx_ * 0.01, hy + 0.036, fz), (sx_ * 0.06, hy + 0.04, fz + 0.012), 0.012, 0.024, facing=(sx_ * 0.3, 0.2, -1))   # a heavy brow, drawn down
        sc.ridge((sx_ * 0.016, hy + 0.0, fz + 0.004), (sx_ * 0.052, hy - 0.004, fz + 0.01), 0.006, 0.01, facing=fr)               # the lower lids
        sc.bump((sx_ * 0.052, hy - 0.032, hz - 0.066), 0.034, -0.034, facing=(sx_ * 0.4, 0, -1))        # cheeks hollowed
        sc.bump((sx_ * 0.058, hy - 0.006, hz - 0.07), 0.02, 0.017, facing=(sx_ * 0.5, 0, -1))           # cheekbones standing over them
        sc.ridge((sx_ * 0.012, hy - 0.05, fz - 0.002), (sx_ * 0.04, hy - 0.056, fz + 0.008), 0.006, -0.011, facing=fr)               # the line of the mouth, drawn back
    sc.ridge((0, hy + 0.022, fz - 0.002), (0, hy - 0.026, fz - 0.016), 0.011, 0.022, facing=fr)           # the nose
    sc.bump((0, hy - 0.026, fz - 0.012), 0.014, -0.018, facing=fr)                                         # its nostrils
    sc.ridge((-0.025, hy - 0.052, fz - 0.004), (0.025, hy - 0.052, fz - 0.004), 0.006, -0.014, facing=fr)   # the lipless mouth
    sc.bump((0, hy - 0.082, hz - 0.082), 0.02, 0.014, facing=fr)                                           # a hard chin


ctx = BB.body(OPT, SKIN, CLAW, EYE, claw=D["claw"], body_tris=2500, arm_tris=1300, toe_claws=False, extra=face_extra)
objs, PAIRS = ctx.objs, ctx.pairs
WTS = BW.base_weights(ctx, S, neck=nk)


def add(o, sock=None):
    if sock:
        o["sock"] = sock
    objs.append(o)
    return o


def Hi(ob, tris, name, sock):
    return L.hi_lo(ob, tris, name, sock, PAIRS, objs)


def fx_(o):
    o["fixed"] = True
    return o


def rope(name, pts, r, sock, mat=None, taper=None):
    return add(K.curve_tube(name, [Vector(G(*p)) for p in pts], r, sock, mat or ROPE, taper), sock)


# --- the robe: collar -> hem, fitted over the sculpted torso, pleated from the belt down -------------------------
pad = 0.032
if KIND == "tollman":
    skirt = [(0.78, 0, 0.005, 0.17, 0.12, 0.13, 2.0), (0.5, 0, 0.0, 0.2, 0.15, 0.16, 2.0), (0.22, 0, 0.01, 0.235, 0.18, 0.2, 2.0), (0.0, 0, 0.012, 0.25, 0.19, 0.21, 2.0)]
else:
    skirt = [(0.78, 0, 0.005, 0.18, 0.128, 0.14, 2.0), (0.5, 0, 0.0, 0.235, 0.18, 0.2, 2.0), (0.22, 0, 0.01, 0.29, 0.235, 0.255, 2.0),
             (-0.02, 0, 0.012, 0.33, 0.27, 0.295, 2.0), (-0.2, 0, 0.012, 0.34, 0.28, 0.3, 2.0)]
SH = {"chanter": 0.0, "tollman": 0.17, "pilgrim": 0.1}[KIND]             # a shoulder yoke: the robe's shoulder line reaches out over the arms (no capped sleeve ends)
keys = [
    (1.585, 0, -nk * 0.9, nkr * 1.2 + 0.03, nkr * 1.1 + 0.03, nkr * 1.3 + 0.03, 2.0),
    (1.525, 0, -nk * 0.35, 0.085 * Wd + pad + 0.35 * SH, 0.058 + pad, 0.074 + 0.35 * hump + pad, 2.0),
    (1.495, 0, 0.012 - nk * 0.2, 0.122 * Wd + pad + 0.75 * SH, 0.066 + pad, 0.085 + 0.6 * hump + pad, 2.0),
    (1.465, 0, 0.014 - nk * 0.1, 0.15 * Wd + pad + SH, 0.078 + pad, 0.092 + 0.8 * hump + pad, 2.2),
    (1.41, 0, 0.012, 0.16 * Wd + pad + 1.05 * SH, 0.1 + pad, 0.10 + hump + pad, 2.2),
    (1.33, 0, 0.01, 0.155 * Wd + pad + 0.95 * SH, 0.11 + pad, 0.10 + 0.7 * hump + pad, 2.1),
    (1.24, 0, 0.005, 0.145 * Wd + pad + 0.6 * SH, 0.105 + pad, 0.095 + 0.3 * hump + pad, 2.05),
    (1.14, 0, 0.0, 0.13 * Wd + pad + 0.25 * SH, 0.09 + pad, 0.09 + pad, 2.2),
    (1.04, 0, 0.0, 0.118 * Wd * wa + pad + 0.006, 0.078 + pad, 0.085 + pad, 2.2),
    (0.94, 0, 0.0, 0.14 * Wd + pad + 0.01, 0.088 + pad + 0.01, 0.105 + pad + 0.01, 2.2),
] + skirt
hem = L.ragged_hem(D["hem_y"], D["hem"], seed=2.0, cuts=D["tears"], scallop=0.03 if KIND == "tollman" else 0.0, nscal=18)
wv = L.Waves(seed={"chanter": 5, "tollman": 8, "pilgrim": 3}[KIND], counts=(5, 8, 14, 22), amps=(1.0, 0.6, 0.3, 0.15))
robe_d = L.Drape(keys, 1.585, hem, y_fold0=1.25, y_hem_ref=0.1, amp=0.2 if KIND != "tollman" else 0.12, waves=wv, nth=224, dy=0.008, flare=0.02, seed=2.0)
Pg = robe_d.points()
robe_hi = L.grid_surface("RobeHigh", Pg, "robe", ROBE, wrap=True, thick=0.008, sub=1)
co, nr = L.mesh_arrays(robe_hi)
P_ = L.to_rig(co)
disp = 0.0 * L.hash_noise(P_, 38.0, 1.0) + 0.0022 * L.hash_noise(P_ * np.array([2.5, 0.35, 2.5]), 9.0, 3.0)
robe_hi.data.vertices.foreach_set('co', (co + L.to_bl(L.to_rig(nr)) * disp[:, None]).astype(np.float32).ravel())
robe_hi.data.update()
WTS["robe"] = BW.skirt_weights(WTS, y_hip=0.9, y_knee=0.45, spread=0.85, knee_part=0.55, torso_from=1.0)

# cloth patches sewn on (cut from the robe's own surface, lifted)
PATCHES = {"chanter": [(0.62, 4.3, 0.075), (0.3, 5.1, 0.06), (0.42, 1.9, 0.085)], "tollman": [(0.62, 4.1, 0.07), (0.9, 5.3, 0.06), (0.5, 2.2, 0.07)],
           "pilgrim": [(0.7, 4.4, 0.08), (0.4, 1.4, 0.07), (0.95, 5.0, 0.055)]}[KIND]
for pi, (py, pth, pr) in enumerate(PATCHES):
    pc, pn = L.surf_pt(Pg, robe_d, py, pth)
    try:
        pt = add(L.patch(robe_hi, "Patch", pc, pr, PATCH, "robe", off=0.006, thick=0.004, seed=2.0 + pi), "robe")
        L.mods(pt, ("DECIMATE", dict(ratio=min(1.0, 110.0 / max(L.tri_count(pt), 1)), use_collapse_triangulate=True)))
    except RuntimeError as e:
        print("PATCH skipped", e)
robe_lo = Hi(robe_hi, 3000, "RobeLow", "robe")

# --- sleeves: hang from the shoulder, loose, a cuff past the hand ----------------------------------------------------
sleeve_len = {"chanter": 0.12, "tollman": 0.12, "pilgrim": 0.06}[KIND]
SLV = {"chanter": (0.085, 0.07), "tollman": (0.066, 0.064), "pilgrim": (0.072, 0.064)}[KIND]
for tag, sx in (("l", -1), ("r", 1)):
    ax = sx * 0.248
    sl = L.sleeve("SleeveHigh", (ax * 0.92, 1.36, 0.0), (ax, D["wrist"] + 0.06, -0.005), SLV[0], SLV[1], MANTLE, "sleeve_" + tag, hem_amp=0.05,
                  droop=0.0, seed=3.0 + sx, amp=0.034, nth=56, rows=40, thick=0.006, drop_len=sleeve_len)
    L.hi_lo(sl, 600, "SleeveLow", "sleeve_" + tag, PAIRS, objs)
    WTS["sleeve_" + tag] = WTS["armskin"]

# --- the cowl ------------------------------------------------------------------------------------------------------------
hd = L.hood("HoodHigh", (HC[0], 1.7 + (0.012 if KIND != "tollman" else 0.004), HC[2] + 0.02), ROBE, "hood", size=(0.122, 0.14, 0.126), face_r=(0.07, 0.092) if KIND != "chanter" else (0.082, 0.106),
            face_dy=-0.022 if KIND != "chanter" else -0.012, peak=D["peak"], back_drop=0.2, lip=0.014, seed=4.0, amp=0.007)
L.hi_lo(hd, 1000 if KIND != "chanter" else 2200, "HoodLow", "hood", PAIRS, objs)
WTS["hood"] = lambda p: {"head": float(sm(1.5, 1.62, p.z)), "chest": float(1.0 - sm(1.5, 1.62, p.z))}

# --- a mantle (chanter: poncho; tollman: scapular; pilgrim: a long cloak open in front) -------------------------------------
if KIND == "pilgrim":
    mk = [(1.575, 0, 0.0 - nk * 0.5, 0.1, 0.09, 0.1, 2.0), (1.52, 0, 0.0, 0.2, 0.13, 0.14, 2.0), (1.43, 0, 0.012, 0.33, 0.16, 0.18, 2.1),
          (1.2, 0, 0.012, 0.34, 0.18, 0.2, 2.0), (0.9, 0, 0.012, 0.34, 0.2, 0.235, 2.0), (0.55, 0, 0.012, 0.36, 0.23, 0.28, 2.0), (0.25, 0, 0.012, 0.4, 0.26, 0.31, 2.0)]
    base_h = L.ragged_hem(0.56, 0.08, seed=9.0, cuts=0.12)

    def mh(th):
        d = np.abs(((th - FRONT + math.pi) % math.tau) - math.pi)
        return base_h(th) + 0.8 * np.exp(-(d / 0.42) ** 2) + 0.05 * np.exp(-(d / 0.9) ** 2)      # the front falls open in a V
    md = L.Drape(mk, 1.575, mh, y_fold0=1.4, y_hem_ref=0.3, amp=0.11, waves=L.Waves(seed=11, counts=(4, 7, 12, 19), amps=(1.0, 0.6, 0.35, 0.16)),
                 nth=200, dy=0.008, flare=0.03, seed=6.0)
elif KIND == "tollman":
    mk = [(1.575, 0, 0.0 - nk * 0.5, 0.1, 0.09, 0.1, 2.0), (1.52, 0, 0.0, 0.17, 0.13, 0.14, 2.0), (1.43, 0, 0.012, 0.19, 0.16, 0.18, 2.1),
          (1.2, 0, 0.012, 0.19, 0.165, 0.185, 2.0), (0.95, 0, 0.01, 0.2, 0.17, 0.19, 2.0)]
    mh = L.ragged_hem(1.0, 0.05, seed=6.0, cuts=0.08)
    md = L.Drape(mk, 1.575, mh, y_fold0=1.5, y_hem_ref=1.0, amp=0.07, waves=L.Waves(seed=12, counts=(4, 7, 12, 19), amps=(1.0, 0.6, 0.35, 0.16)),
                 nth=176, dy=0.008, flare=0.02, seed=6.0)
else:
    mk = [(1.575, 0, 0.0 - nk * 0.5, 0.1, 0.09, 0.1, 2.0), (1.52, 0, 0.0, 0.2, 0.13, 0.14, 2.0), (1.43, 0, 0.012, 0.33, 0.165, 0.18, 2.1),
          (1.32, 0, 0.012, 0.345, 0.17, 0.19, 2.1), (1.18, 0, 0.01, 0.345, 0.175, 0.19, 2.0), (1.06, 0, 0.01, 0.345, 0.175, 0.2, 2.0)]
    mh = L.ragged_hem(1.17, 0.07, seed=6.0, cuts=0.1, scallop=0.04, nscal=12)
    md = L.Drape(mk, 1.575, mh, y_fold0=1.5, y_hem_ref=1.1, amp=0.09, waves=L.Waves(seed=11, counts=(4, 7, 12, 19), amps=(1.0, 0.6, 0.35, 0.16)),
                 nth=176, dy=0.008, flare=0.03, seed=6.0)
Pgm = md.points()
mantle_hi = L.grid_surface("MantleHigh", Pgm, "mantle", MANTLE, wrap=True, thick=0.007, sub=1)
L.hi_lo(mantle_hi, 1500 if KIND != "tollman" else 1200, "MantleLow", "mantle", PAIRS, objs)
WTS["mantle"] = BW.GB.envelope_weights(ctx.segs, band=0.11, power=1.5)
if KIND == "pilgrim":
    WTS["mantle"] = BW.skirt_weights(WTS, y_hip=0.9, y_knee=0.45, spread=0.55, knee_part=0.4, torso_from=1.0)

# hanging tatters and charms from the mantle's hem (chanter: bone charms; tollman: small iron bells)
if KIND in ("chanter", "tollman"):
    for k in range(9):
        th = math.tau * (k + 0.5) / 9.0
        yh = float(mh(np.array([th]))[0]) + 0.012
        p, n = L.surf_pt(Pgm, md, yh, th)
        L_ = 0.1 + 0.07 * ((k * 5) % 3)
        pts = [Vector(G(*(p + n * 0.012 * t + np.array([0, -L_ * t, 0])))) for t in (0.0, 0.25, 0.5, 0.75, 1.0)]
        add(GK.strip("Cord", pts, 0.012, 0.004, "mantle", LEATHER, taper=0.2), "mantle")
        end = p + n * 0.012 + np.array([0, -L_ - 0.01, 0])
        if KIND == "chanter":
            add(K.bone("Charm", Vector(G(*end)), Vector(G(*(end + np.array([0.0, -0.06 - 0.02 * (k % 2), 0.0])))), 0.007, "mantle", BONE, 1.8, 6, 6, k), "mantle")
        else:
            add(K.blob("Bell", Vector(G(*(end + np.array([0, -0.014, 0])))), (0.014, 0.018, 0.014), "mantle", IRON, 12, 8), "mantle")

# a clasp at the collar: an iron ring and a bone pin
cp, cn = L.surf_pt(Pgm, md, 1.5, FRONT)
ring = [Vector(G(*(cp + cn * 0.022 + np.array([math.cos(a) * 0.03, math.sin(a) * 0.03, 0.0])))) for a in [math.tau * i / 20 for i in range(21)]]
add(K.loft("Iron", ring, [(0.0055, 0.0055)] * 21, "r:chest", IRON, 6), "r:chest")
add(K.bone("Pin", Vector(G(*(cp + cn * 0.03 + np.array([-0.05, 0.02, 0])))), Vector(G(*(cp + cn * 0.03 + np.array([0.05, -0.02, 0])))), 0.005, "r:chest", BONE, 1.4, 6, 6, 1.0), "r:chest")

# --- belt, cords, things on them ------------------------------------------------------------------------------------------
belt_y = 1.02
rowk = L.catmull(keys, np.array([belt_y]), 6)[0]
ba, bf, bb = float(rowk[2]), float(rowk[3]), float(rowk[4])
rx, rz = ba + 0.03, (bf + bb) * 0.5 + 0.03
add(L.band_loop("Belt", (0, belt_y, (bb - bf) * 0.5), rx, rz, 0.017, ROPE, "r:pelvis", n=28, sides=5), "r:pelvis")
for k in range(3):                                   # the knot and the hanging ends
    a0 = FRONT + 0.22 * (k - 1)
    p0 = (math.cos(a0) * rx * 0.97, belt_y - 0.01, math.sin(a0) * rz)
    rope("Cord", [p0, (p0[0] * 1.02, belt_y - 0.14 - 0.03 * k, p0[2] - 0.03), (p0[0] * 1.05 + 0.02 * k, belt_y - 0.3 - 0.05 * k, p0[2] - 0.04)], 0.011, "r:pelvis", ROPE, [1.0, 0.9, 0.55])
add(K.blob("Knot", Vector(G(0.0, belt_y - 0.01, -rz - 0.012)), (0.03, 0.026, 0.022), "r:pelvis", ROPE, 16, 10), "r:pelvis")
# a pouch, a phial and a charm on the left hip
hx = -(rx * 0.74)
add(K.blob("Pouch", Vector(G(hx - 0.01, belt_y - 0.13, -rz * 0.62)), (0.052, 0.07, 0.04), "r:pelvis", LEATHER, 20, 12), "r:pelvis")
add(K.loft("Strap", [Vector(G(hx + 0.02, belt_y - 0.03, -rz * 0.6)), Vector(G(hx - 0.01, belt_y - 0.07, -rz * 0.66)), Vector(G(hx - 0.04, belt_y - 0.09, -rz * 0.66))], [(0.02, 0.004)] * 3, "r:pelvis", LEATHER, 6), "r:pelvis")
if KIND == "chanter":
    add(K.blob("Glow", Vector(G(hx + 0.1, belt_y - 0.17, -rz * 0.5)), (0.017, 0.032, 0.017), "r:pelvis", LIGHT, 12, 8), "r:pelvis")
    rope("Cord", [(hx + 0.1, belt_y - 0.01, -rz * 0.5), (hx + 0.1, belt_y - 0.09, -rz * 0.52)], 0.005, "r:pelvis", LEATHER)

# --- what each carries -----------------------------------------------------------------------------------------------------------------
rigid = {}
HR = S["hand_r"]
if KIND == "chanter":
    # the staff: a bone shaft through the right hand (chanter.gd reads the tip 0.85 above the hand), a caged corpse-light
    shaft = [HR + G(0.005 * math.sin(t * 7), -0.85 + 1.72 * t, -0.03) for t in [i / 16.0 for i in range(17)]]
    add(K.loft("Bone", shaft, [0.016 + 0.004 * math.sin(i * 1.7) for i in range(17)], "staff", BONE, 8, wobble=0.1), "staff")
    tip = HR + G(0, 0.85, -0.03)
    for k in range(6):
        a = math.tau * k / 6.0
        pts = [tip + G(math.cos(a) * r, y, math.sin(a) * r) for y, r in ((-0.1, 0.02), (-0.06, 0.06), (0.0, 0.075), (0.07, 0.055), (0.12, 0.012))]
        add(K.curve_tube("Iron", pts, 0.005, "staff", IRON), "staff")
    add(K.blob("Glow", tip, (0.045, 0.055, 0.045), "staff", LIGHT, 16, 10), "staff")
    for k in range(3):
        add(K.loft("Bone", [tip + G(0.06 * math.cos(k * 2.1), -0.12, 0.06 * math.sin(k * 2.1)), tip + G(0.08 * math.cos(k * 2.1), -0.3, 0.08 * math.sin(k * 2.1))], [0.004, 0.002], "staff", BONE, 4), "staff")
        add(K.blob("Bone", tip + G(0.08 * math.cos(k * 2.1), -0.32, 0.08 * math.sin(k * 2.1)), (0.012, 0.02, 0.012), "staff", BONE, 10, 6), "staff")
elif KIND == "tollman":
    # the hand-bell: a grip through the fist, a flared black iron bell with a rolled lip, bands and a clapper.
    # Its own rigid part on the hand (tollman.gd swings it about the hand when it rings).
    c = (0.248, 0.0, -0.03)
    BS = 1.32
    by0 = 0.4 - 0.268 * BS                                    # the lip's height: the bell hangs from the fist
    prof = [(r_ * BS, h_ * BS) for r_, h_ in [(0.108, 0.0), (0.112, 0.012), (0.1, 0.03), (0.088, 0.075), (0.072, 0.13), (0.058, 0.18), (0.046, 0.22), (0.032, 0.248), (0.02, 0.262), (0.0, 0.268)]]
    objs.append(L.lathe("Bell", prof, (c[0], by0, c[2]), IRON, "bell", nth=40, wobble=0.015, seed=1.0, fold=0.0))
    add(L.band_loop("Lip", (c[0], by0, c[2]), 0.112 * BS, 0.112 * BS, 0.014, IRON, "bell", n=28, sides=6), "bell")
    for yb in (0.06, 0.1):
        add(L.band_loop("Band", (c[0], by0 + yb * BS, c[2]), (0.09 - 0.35 * (yb - 0.06)) * BS, (0.09 - 0.35 * (yb - 0.06)) * BS, 0.006, IRON, "bell", n=24, sides=5), "bell")
    add(K.loft("Grip", [Vector(G(c[0], 0.4, c[2])), Vector(G(c[0], 0.63, c[2]))], [(0.022, 0.022), (0.018, 0.018)], "bell", WOOD, 10), "bell")
    for k in range(6):
        add(K.loft("Wrap", [Vector(G(c[0], 0.43 + 0.03 * k, c[2])), Vector(G(c[0], 0.447 + 0.03 * k, c[2]))], [(0.026, 0.026)] * 2, "bell", LEATHER, 8), "bell")
    add(K.blob("Pommel", Vector(G(c[0], 0.645, c[2])), (0.028, 0.022, 0.028), "bell", IRON, 14, 10), "bell")
    add(K.blob("Clapper", Vector(G(c[0], by0 + 0.03, c[2])), (0.03, 0.036, 0.03), "bell", IRON, 14, 10), "bell")
    add(K.loft("Clap", [Vector(G(c[0], by0 + 0.05, c[2])), Vector(G(c[0], by0 + 0.17, c[2]))], [(0.006, 0.006)] * 2, "bell", IRON, 6), "bell")
    rigid = {"bell": ("bell_hand_r", S["hand_r"])}
    # the rope it rings with, over the shoulder
    tr = []
    for k in range(9):
        t = k / 8.0
        yy, thh = 1.5 - 0.5 * t, FRONT + 1.0 - 1.9 * t
        pp, nn = L.surf_pt(Pgm if yy > 1.0 else Pg, md if yy > 1.0 else robe_d, yy, thh)
        tr.append(pp + nn * 0.03)
    rope("TollRope", tr, 0.02, "r:chest", ROPE)
elif KIND == "pilgrim":
    # a pilgrim's staff of ash, crooked at the head with a gourd hung from it; a candle on a cord at the breast
    shaft = [HR + G(0.0 + 0.012 * math.sin(t * 5), -0.72 + 1.82 * t, -0.03) for t in [i / 16.0 for i in range(17)]]
    add(K.loft("Wood", shaft, [0.017 + 0.003 * math.sin(i * 1.3) for i in range(17)], "staff", WOOD, 8, wobble=0.08), "staff")
    top = HR + G(0, 1.1, -0.03)
    hk = [top + G(0.05 - 0.07 * math.cos(a), 0.07 * math.sin(a), 0.0) for a in [i * math.pi * 1.1 / 8 for i in range(9)]]
    add(K.curve_tube("Wood", hk, 0.016, "staff", WOOD, [1.0 - 0.4 * (i / 8.0) for i in range(9)]), "staff")
    add(K.blob("Gourd", top + G(0.0, -0.14, 0.01), (0.05, 0.075, 0.05), "staff", WOOD, 18, 12), "staff")
    add(K.blob("Gourd", top + G(0.0, -0.06, 0.01), (0.026, 0.03, 0.026), "staff", WOOD, 14, 8), "staff")
    add(K.loft("Shod", [HR + G(0, -0.74, -0.03), HR + G(0, -0.66, -0.03)], [(0.026, 0.026), (0.019, 0.019)], "staff", IRON, 8), "staff")
    cx, cy, cz = 0.0, 1.14, -0.2
    rope("Cord", [(0.07, 1.5, -0.1), (0.05, 1.32, -0.19), (0.0, 1.2, -0.205)], 0.006, "r:chest", LEATHER)
    add(K.loft("Candle", [Vector(G(cx, cy - 0.08, cz)), Vector(G(cx, cy + 0.05, cz))], [(0.021, 0.021), (0.018, 0.018)], "r:chest", BONE, 10), "r:chest")
    for k in range(3):
        add(K.blob("Wax", Vector(G(cx + 0.015 * math.cos(k * 2.3), cy + 0.01 - 0.02 * k, cz - 0.018 * math.sin(k * 2.3 + 1) - 0.012)), (0.005, 0.018, 0.005), "r:chest", BONE, 8, 6), "r:chest")
    add(K.blob("Flame", Vector(G(cx, cy + 0.085, cz)), (0.011, 0.028, 0.011), "r:chest", LIGHT, 10, 8), "r:chest")
    add(L.band_loop("Holder", (cx, cy - 0.075, cz), 0.03, 0.03, 0.004, IRON, "r:chest", n=16, sides=5), "r:chest")
    # the pack it bends under: a canvas pack with a bedroll and a blanket, slung from rope straps over the cloak
    pk = L.lathe("Pack", [(0.0, -0.26), (0.12, -0.25), (0.2, -0.16), (0.225, 0.0), (0.2, 0.15), (0.14, 0.27), (0.06, 0.33)], (0.0, 1.0, 0.36), PATCH, "r:chest", nth=26, wobble=0.12, seed=4.0, fold=0.05, fold_n=4, thick=0.0, ellip=(1.15, 0.8), rows=10)
    L.displace(pk, lambda P, N: 0.012 * L.hash_noise(P, 14.0, 2.0) + 0.012 * np.sin(np.arctan2(P[:, 0], P[:, 2] - 0.36) * 5 + P[:, 1] * 5))
    L.smooth_shade(pk)
    pk["fixed"] = True
    add(pk, "r:chest")
    add(fx_(K.loft("PackRoll", [Vector(G(-0.27, 1.36, 0.3)), Vector(G(0.0, 1.38, 0.32)), Vector(G(0.27, 1.36, 0.3))], [0.07, 0.078, 0.07], "r:chest", MANTLE, 10)), "r:chest")
    for sx in (-1, 1):
        rope("PackStrap", [(sx * 0.1, 1.5, 0.12), (sx * 0.15, 1.46, 0.0), (sx * 0.16, 1.34, -0.14), (sx * 0.12, 1.12, -0.12), (sx * 0.1, 1.0, 0.12), (sx * 0.14, 1.2, 0.25)], 0.014, "r:chest", ROPE)
    add(fx_(K.blob("PackPot", Vector(G(0.17, 0.82, 0.4)), (0.06, 0.06, 0.06), "r:chest", IRON, 14, 10)), "r:chest")
    shp = L.surf_pt(Pgm, md, 1.43, FRONT - 0.7)
    objs.append(L.lathe("Shell", [(0.0, 0.0), (0.03, 0.01), (0.052, 0.03), (0.05, 0.036), (0.0, 0.012)], (shp[0][0], shp[0][1], shp[0][2] - 0.03), BONE, "r:chest", nth=18, fold=0.18, fold_n=7, thick=0.004))

if PREVIEW:
    L.preview_sheet(PREVIEW, 0.95, 3.3)
L.report(objs)
print("BIPED", KIND, "parts", len(objs), "tris", sum(L.tri_count(o) for o in objs if o.type == 'MESH'))
if EXPORT:
    GK.export_skinned(objs, MATS, "grunt_" + KIND, S, WTS, rigid, 2048, 16500, pairs=PAIRS)
