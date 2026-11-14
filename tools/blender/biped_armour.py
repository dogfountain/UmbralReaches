"""The Bulwark (r38 remodel): a bloated, hide-grey brute buried in plate and quilting, behind a battered tower door-shield.
Armour is FITTED to the sculpted body (biped_sculpt_lib.shell): a ridged cuirass, belly lames that overlap and flare, a
fauld, tassets, cuisses, knee cops, greaves, sabatons, a gorget, pauldrons built of lames, couters, vambraces and gauntlets,
over a quilted gambeson; a great helm with a slit, a nasal bar and a crest of spikes; a chain and a tabard of torn cloth.
The shield is its own rigid part on the chest socket (bulwark.gd looks it up and breaks it off): curved boards with gaps,
an iron rim and three bands with rivets, a spiked boss, a skull nailed over it, broken arrows, arm straps on the back.

  GRUNT_OUT=<dir> tools/blender/run.sh biped_armour.py -- --kind bulwark [--preview /tmp/b.png] [--no-export]
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
KIND = args[args.index("--kind") + 1] if "--kind" in args else "bulwark"
PREVIEW = args[args.index("--preview") + 1] if "--preview" in args else ""
EXPORT = "--no-export" not in args

K.reset()
BB.fast_ao(16)
BB.lean()
S = dict(K.SOCKETS)
sm = L.smooth

SKIN = GK.hollow_skin("Skin", (0.17, 0.2, 0.27), (0.04, 0.05, 0.075), wet=0.3, wrinkle=40.0, vein_amt=0.6, liv=(0.78, 0.62, 0.95), extremities=0.0)
FACE = SKIN
CLAW = GK.grave_bone("Claw", (0.34, 0.3, 0.24), (0.1, 0.07, 0.05), 12.0)
EYE = GK.glow("Eye", (1.0, 0.42, 0.1), 8.0)
PLATE = GK.iron("Plate", (0.085, 0.085, 0.095), (0.15, 0.085, 0.055))
IRON = GK.iron("Iron", (0.11, 0.105, 0.11), (0.2, 0.09, 0.05))
GAMB = GK.cloth("Gambeson", (0.16, 0.13, 0.095), "caban", 6.0, (0.04, 0.03, 0.02), 0.92)
CLOTH = GK.cloth("Tabard", (0.14, 0.07, 0.05), "rough_linen", 7.0, (0.04, 0.025, 0.02), 0.92)
LEATHER = GK.leather("Leather", (0.14, 0.09, 0.06))
WOOD = GK.wood("Wood", (0.2, 0.13, 0.08), 0.6)
BONE = GK.grave_bone("Bone", (0.66, 0.61, 0.5))
MATS = [SKIN, CLAW, EYE, PLATE, IRON, GAMB, CLOTH, LEATHER, WOOD, BONE]

KEYS = [
    (0.775, 0, 0.0, 0.07, 0.06, 0.06, 2.0), (0.81, 0, 0.0, 0.13, 0.09, 0.1, 2.2), (0.88, 0, 0.005, 0.2, 0.12, 0.13, 2.3),
    (0.97, 0, 0.0, 0.2, 0.15, 0.12, 2.2), (1.05, 0, 0.0, 0.205, 0.19, 0.115, 2.2), (1.14, 0, 0.0, 0.2, 0.2, 0.12, 2.2),
    (1.24, 0, 0.005, 0.215, 0.17, 0.125, 2.05), (1.33, 0, 0.01, 0.225, 0.15, 0.13, 2.1), (1.41, 0, 0.012, 0.235, 0.13, 0.125, 2.25),
    (1.465, 0, 0.014, 0.22, 0.1, 0.115, 2.2), (1.495, 0, 0.012, 0.18, 0.085, 0.105, 2.0), (1.525, 0, 0.0, 0.12, 0.07, 0.09, 2.0),
    (1.56, 0, 0.0, 0.075, 0.065, 0.075, 2.0), (1.62, 0, 0.0, 0.062, 0.058, 0.064, 2.0)]
HC = (0, 1.665, -0.035)
OPT = dict(W=1.3, L=1.4, nk=0.0, finger=0.1, hand_r=1.3, wrist=0.74, ribs=0.0, belly=1.0, collar=0.5, tendon=0.6, hc=HC, jaw_w=0.055, brow=0.012,
           waist=1.25, head_w=0.075, neck_r=0.06, depth=1.2, torso=KEYS)
ctx = BB.body(OPT, SKIN, CLAW, EYE, claw=0.04, teeth=False, eyes=False, body_tris=3800, arm_tris=1500)
objs, PAIRS = ctx.objs, ctx.pairs
WTS = BW.base_weights(ctx, S, neck=0.0)
HB, HA = ctx.hi["Body"], ctx.hi["Arms"]
import grunt_body as GB
MB = GB.make_low(HB, 9000, "BodyMed")          # plates for the GAME mesh are cut from these medium copies, the bake's high ones from the full surface
MA = GB.make_low(HA, 4000, "ArmsMed")
for _m in (MB, MA):
    _m.hide_render = True
    _m.hide_viewport = True
plates, plates_lo = [], []
gamb = []


def add(o, sock=None):
    if sock:
        o["sock"] = sock
    objs.append(o)
    return o


def keep(sel_fn, off, thick=0.01, src=HB, name="Plate", mat=PLATE, folds=None, bevel=0.003, smooth_iter=5, bucket=None):
    o = L.shell(src, name, sel_fn, off, thick, mat, "stiff", folds=folds, smooth_iter=smooth_iter, bevel=bevel)
    plates.append(o)
    med = MA if src is HA else MB
    lo = L.shell(med, name + "Lo", sel_fn, off, 0.0, mat, "stiff", folds=folds, smooth_iter=max(2, smooth_iter - 2), bevel=0.0)
    plates_lo.append(lo)
    return o


def band(y0, y1, xmin=0.0, xmax=9.0):
    def sel(P, N):
        ax = np.abs(P[:, 0])
        return np.minimum(np.minimum(P[:, 1] - y0, y1 - P[:, 1]), np.minimum(ax - xmin, xmax - ax) * 4.0 + 0.001) + 0.0
    return sel


def outer(P, N):
    return (N[:, 0] * P[:, 0] + N[:, 2] * P[:, 2]) > -0.0


# --- torso: cuirass with a ridge, belly lames, fauld, gorget ----------------------------------------------------------
def ridge(P, N, amp=0.016):
    front = np.clip(-N[:, 2] * 1.5, 0.0, 1.0)
    return amp * np.exp(-(P[:, 0] / 0.045) ** 2) * front * sm(1.2, 1.35, P[:, 1])


keep(band(1.2, 1.5, 0.0, 0.3), lambda P, N: 0.024 + 0.0 * P[:, 0], 0.012, folds=ridge, bevel=0.004)
for i in range(4):                                       # belly lames: overlapping, the upper ones outside
    y1 = 1.2 - 0.065 * i + 0.006
    keep(band(y1 - 0.07, y1), (lambda k: lambda P, N: 0.026 - 0.004 * k + 0.0 * P[:, 0])(i), 0.009, bevel=0.0025)
for i in range(3):                                       # the fauld, flaring over the hips
    y1 = 0.945 - 0.07 * i + 0.006
    keep(band(y1 - 0.075, y1, 0.0, 0.3), (lambda k: lambda P, N: 0.03 + 0.012 * k)(i), 0.009, bevel=0.0025)
keep(band(1.5, 1.565), 0.018, 0.009, bevel=0.003)         # gorget


def tasset(P, N):                                         # a plate hanging off the fauld over each thigh, pointed
    ax = np.abs(P[:, 0])
    bottom = 0.56 + 0.075 * np.clip(ax / 0.19, 0, 1.2)
    ok = (P[:, 1] < 0.76) & (P[:, 1] > bottom) & (ax > 0.03) & (ax < 0.2) & (N[:, 2] < 0.2)
    return np.where(ok, 1.0, -1.0)


keep(tasset, 0.034, 0.01, bevel=0.003)

# --- legs: cuisses, knee cops, greaves, sabatons ---------------------------------------------------------------------
for sx in (-1, 1):
    cx = sx * 0.11

    def leg(y0, y1, sx=sx):
        def sel(P, N):
            return np.where((P[:, 0] * sx > 0.015), np.minimum(P[:, 1] - y0, y1 - P[:, 1]), -1.0)
        return sel
    keep(leg(0.4, 0.56), 0.02, 0.009, bevel=0.0025)                        # cuisse below the tasset
    kc = np.array([cx, 0.345, -0.04])
    keep((lambda kc: lambda P, N: np.where(np.linalg.norm(P - kc, axis=1) < 0.085, 1.0 - 0.0 * P[:, 0], -1.0))(kc),
         lambda P, N: 0.028 + 0.0 * P[:, 0], 0.012, bevel=0.004)         # knee cop
    keep(leg(0.1, 0.27), lambda P, N: 0.016 + 0.01 * sm(0.27, 0.1, P[:, 1]), 0.009, bevel=0.003)       # greave
    keep(leg(0.0, 0.085), lambda P, N: 0.014 + 0.0 * P[:, 0], 0.008, bevel=0.0025)                    # sabaton

# --- arms: pauldrons of lames, couters, vambraces, gauntlets (cut from the arm surface) -------------------------------------
for sx in (-1, 1):
    def arm_band(y0, y1, sx=sx, xmin=0.14):
        def sel(P, N):
            return np.where(P[:, 0] * sx > xmin, np.minimum(P[:, 1] - y0, y1 - P[:, 1]), -1.0)
        return sel
    keep(arm_band(1.37, 1.52, xmin=0.1), lambda P, N: 0.04 + 0.0 * P[:, 0], 0.012, src=HA, bevel=0.004)      # pauldron crown
    keep(arm_band(1.285, 1.38, xmin=0.15), lambda P, N: 0.036, 0.01, src=HA, bevel=0.003)
    keep(arm_band(1.2, 1.29, xmin=0.17), lambda P, N: 0.03, 0.01, src=HA, bevel=0.003)
    keep(arm_band(1.03, 1.12, xmin=0.17), lambda P, N: 0.03 + 0.0 * P[:, 0], 0.011, src=HA, bevel=0.003)       # couter
    keep(arm_band(0.8, 1.03, xmin=0.17), lambda P, N: 0.018 + 0.012 * sm(0.85, 1.03, P[:, 1]), 0.009, src=HA, bevel=0.003)   # vambrace
    keep(arm_band(0.5, 0.78, xmin=0.17), lambda P, N: 0.012, 0.007, src=HA, bevel=0.002)                                   # gauntlet

# --- the quilted gambeson under it all (shows at the gaps) ------------------------------------------------------------------
def quilt(P, N):
    th = np.arctan2(P[:, 0], -P[:, 2])
    return 0.0035 * np.sin(th * 14.0) * np.sin(P[:, 1] * 52.0) + 0.002 * L.hash_noise(P, 30.0, 4.0)


gb = L.shell(HB, "Gamb", band(0.74, 1.52), 0.009, 0.007, GAMB, "bodyskin", folds=quilt, smooth_iter=3)
gamb.append(gb)
for sx in (-1, 1):
    ga = L.shell(HA, "GambArm", (lambda sx: lambda P, N: np.where(P[:, 0] * sx > 0.12, np.minimum(P[:, 1] - 0.99, 1.45 - P[:, 1]), -1.0))(sx), 0.008, 0.006, GAMB, "armskin", folds=quilt, smooth_iter=3)
    gamb.append(ga)


def check(step):
    dead = 0
    for o in objs:
        try:
            o.name
        except ReferenceError:
            dead += 1
    print("CHECK", step, "dead", dead)


def joined(lst, name):
    bpy.ops.object.select_all(action='DESELECT')
    for o in lst:
        o.select_set(True)
    bpy.context.view_layer.objects.active = lst[0]
    bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    ob.name = name
    return ob


n_lo = sum(L.tri_count(o) for o in plates_lo)
ratio = min(1.0, 3700.0 / max(n_lo, 1))
print("PLATES lo tris", n_lo, "ratio", ratio)
if ratio < 1.0:
    for o in plates_lo:
        L.mods(o, ("DECIMATE", dict(ratio=ratio, use_collapse_triangulate=True)))
plate_hi = joined(plates, "PlatesHigh")
plate_lo = joined(plates_lo, "PlatesLow")
for o in (plate_hi,):
    o.hide_render = True
    o.hide_viewport = True
plate_lo["sock"] = "stiff"
plate_lo["fixed"] = True
L.smooth_shade(plate_lo)
PAIRS.append((plate_lo, plate_hi))
objs.append(plate_lo)
gb_hi = joined([g for g in gamb if g.get("sock") == "bodyskin"], "GambHigh")
L.hi_lo(gb_hi, 700, "GambLow", "bodyskin", PAIRS, objs)
for g in gamb:
    if g.name.startswith("GambArm"):
        L.hi_lo(g, 320, "GambArmLow", "armskin", PAIRS, objs)

# --- the great helm ---------------------------------------------------------------------------------------------------------------
hy, hz = HC[1], HC[2]
prof = [(0.102, -0.14), (0.109, -0.11), (0.113, -0.05), (0.115, 0.01), (0.112, 0.06), (0.1, 0.1), (0.078, 0.128), (0.045, 0.141), (0.0, 0.146)]
helm = L.lathe("Helm", prof, (HC[0], hy, hz + 0.01), PLATE, "r:head", nth=56, wobble=0.01, seed=2.0, thick=0.0, ellip=(1.0, 1.12), rows=16)
helm["fixed"] = True
L.smooth_shade(helm)
add(helm, "r:head")
# the eye slit: a dark channel between a raised brow plate and a cheek plate, the eyes burning in it; breaths down the left cheek
add(K.loft("SlitGlow", [Vector(G(-0.072, hy + 0.012, hz - 0.1)), Vector(G(0.0, hy + 0.012, hz - 0.124)), Vector(G(0.072, hy + 0.012, hz - 0.1))], [(0.011, 0.004)] * 3, "r:head", EYE, 5), "r:head")
for yy, w in ((hy + 0.03, 0.082), (hy - 0.008, 0.078)):
    pts = [Vector(G(-w, yy, hz - 0.085)), Vector(G(-w * 0.55, yy, hz - 0.121)), Vector(G(0.0, yy, hz - 0.13)), Vector(G(w * 0.55, yy, hz - 0.121)), Vector(G(w, yy, hz - 0.085))]
    add(K.loft("SlitLip", pts, [(0.0075, 0.0075)] * 5, "r:head", PLATE, 5), "r:head")
for k in range(5):
    add(K.blob("Breath", Vector(G(-0.05 - 0.004 * k, hy - 0.04 - 0.017 * k, hz - 0.1 + 0.0 * k - 0.014)), (0.007, 0.004, 0.007), "r:head", IRON, 8, 6), "r:head")
# a nasal bar, a brow band, a rolled bottom rim, a skull-cap ridge and the crest of spikes
add(K.loft("Bar", [Vector(G(HC[0], hy + 0.13, hz - 0.1)), Vector(G(HC[0], hy + 0.01, hz - 0.14)), Vector(G(HC[0], hy - 0.11, hz - 0.13))], [(0.008, 0.007)] * 3, "r:head", PLATE, 6), "r:head")
add(L.band_loop("Rim", (HC[0], hy - 0.14, hz + 0.01), 0.104, 0.116, 0.007, PLATE, "r:head", n=32, sides=5), "r:head")
add(L.band_loop("Brow", (HC[0], hy + 0.03, hz + 0.01), 0.116, 0.13, 0.006, PLATE, "r:head", n=32, sides=5), "r:head")
add(K.loft("Ridge", [Vector(G(HC[0], hy + 0.146, hz + 0.13)), Vector(G(HC[0], hy + 0.15, hz + 0.01)), Vector(G(HC[0], hy + 0.145, hz - 0.12))], [(0.007, 0.01)] * 3, "r:head", PLATE, 6), "r:head")
for k in range(7):
    t = k / 6.0
    zz = hz + 0.1 - 0.2 * t
    add(GK.claw("Spike", Vector(G(HC[0], hy + 0.148 - 0.01 * abs(t - 0.5), zz)), Vector(G(0, 1.0, 0.25 * (t - 0.4))), 0.08 + 0.07 * (1.0 - abs(2 * t - 1.0)), 0.012, "r:head", PLATE, -0.15), "r:head")
for sx in (-1, 1):
    add(K.blob("Eye", Vector(G(sx * 0.034, hy + 0.012, hz - 0.075)), (0.012, 0.008, 0.012), "r:head", EYE, 12, 8), "r:head")
    for k in range(3):
        a = k * 2.1
    add(K.blob("Rivet", Vector(G(sx * 0.113, hy + 0.005, hz + 0.01)), (0.01, 0.01, 0.01), "r:head", IRON, 10, 6), "r:head")

# --- belt, chain, tabard, straps ---------------------------------------------------------------------------------------------------
add(L.band_loop("Belt", (0, 0.93, 0.0), 0.255, 0.255 * 0.74, 0.03, LEATHER, "r:pelvis", n=36, sides=5, squash=0.4), "r:pelvis")
add(K.blob("Buckle", Vector(G(0.0, 0.93, -0.215)), (0.06, 0.05, 0.016), "r:pelvis", IRON, 20, 12), "r:pelvis")
add(K.blob("Buckle", Vector(G(0.0, 0.93, -0.226)), (0.03, 0.028, 0.01), "r:pelvis", PLATE, 14, 8), "r:pelvis")
for sx in (-1, 1):
    add(GK.chain_links("Chain", [Vector(G(sx * 0.2, 0.92, -0.14)), Vector(G(sx * 0.26, 0.8, -0.1)), Vector(G(sx * 0.27, 0.66, -0.06))], 0.01, "r:pelvis", IRON), "r:pelvis")
    add(K.blob("Ring", Vector(G(sx * 0.2, 0.92, -0.14)), (0.02, 0.02, 0.012), "r:pelvis", IRON, 10, 6), "r:pelvis")
WTS["skirt"] = BW.skirt_weights(WTS, y_hip=0.9, y_knee=0.45, spread=0.8, knee_part=0.5, torso_from=0.95)
for k in range(9):                                        # a tabard of torn cloth, front and back, under the fauld
    a = math.tau * (k + 0.5) / 9.0
    for off, wid, lng in ((0.255, 0.085, 0.34),):
        rx, rz = 0.255, 0.19
        root = Vector(G(math.cos(a) * rx, 0.78, math.sin(a) * rz))
        out = Vector((math.cos(a), -math.sin(a), 0.0))
        L_ = lng * (0.7 + 0.5 * ((k * 7) % 5) / 4.0)
        pts = [root + out * (0.01 + 0.04 * t * t) + Vector((0, 0, -L_ * t)) + out * 0.008 * math.sin(t * 5.0 + k) for t in [i / 7.0 for i in range(8)]]
        add(GK.strip("Cloth", pts, wid, 0.007, "skirt", CLOTH, taper=0.5), "skirt")
add(K.loft("Strap", [Vector(G(-0.22, 1.47, -0.07)), Vector(G(0.0, 1.32, -0.215)), Vector(G(0.22, 1.12, -0.1))], [(0.028, 0.007)] * 3, "r:chest", LEATHER, 6), "r:chest")
# a bone fetish and teeth on cords at the hip
for k in range(4):
    add(GK.claw("Tooth", Vector(G(0.07 + 0.03 * k, 0.9, -0.225)), Vector(G(0, -1.0, -0.1)), 0.045, 0.01, "r:pelvis", BONE, 0.2), "r:pelvis")

# --- THE DOOR-SHIELD (a rigid part on the chest socket; bulwark.gd looks it up as Kin_shield_chest) --------------------------------------
C = S["chest"]
cz0 = -0.42
SH_W, SH_TOP, SH_BOT = 0.86, 1.62, 0.40


def sz(x):                                                  # the face of the shield bows forward (rig -z)
    return cz0 - 0.07 * (1.0 - (x / (SH_W / 2)) ** 2)


planks = 6
pw = SH_W / planks
rng = np.random.RandomState(4)
for k in range(planks):
    x0, x1 = -SH_W / 2 + pw * k + 0.0025, -SH_W / 2 + pw * (k + 1) - 0.0025
    top = SH_TOP - (0.0 if k in (2, 3) else 0.04 * ((k * 5) % 3)) - 0.02 * rng.rand()
    bot = SH_BOT + 0.03 * ((k * 3) % 2) + 0.02 * rng.rand()
    # a board is a curved slab: u across, v up, thickness 0.045 toward the back
    nu, nv = 3, 12
    bm = bmesh.new()
    vf, vb = [], []
    for j in range(nv + 1):
        y = bot + (top - bot) * j / nv
        rowf, rowb = [], []
        for i in range(nu + 1):
            x = x0 + (x1 - x0) * i / nu
            warp = 0.004 * math.sin(k * 2.3 + y * 6.0) + 0.0025 * noise.noise(Vector((x * 20, y * 8, k)))
            edge = 0.004 * (1.0 - math.cos(math.pi * i / nu)) * 0.5     # rounded long edges
            rowf.append(bm.verts.new(Vector(G(x, y, sz(x) + warp - 0.0))))
            rowb.append(bm.verts.new(Vector(G(x, y, sz(x) + 0.048 + warp + edge * 0.0))))
        vf.append(rowf)
        vb.append(rowb)
    for j in range(nv):
        for i in range(nu):
            bm.faces.new((vf[j][i], vf[j][i + 1], vf[j + 1][i + 1], vf[j + 1][i]))
            bm.faces.new((vb[j][i + 1], vb[j][i], vb[j + 1][i], vb[j + 1][i + 1]))
    for j in range(nv):
        bm.faces.new((vf[j][0], vf[j + 1][0], vb[j + 1][0], vb[j][0]))
        bm.faces.new((vf[j][nu], vb[j][nu], vb[j + 1][nu], vf[j + 1][nu]))
    for i in range(nu):
        bm.faces.new((vf[0][i], vb[0][i], vb[0][i + 1], vf[0][i + 1]))
    # a pointed, split top
    tip = bm.verts.new(Vector(G((x0 + x1) * 0.5 + 0.01 * (k % 3 - 1), top + 0.05 * ((k * 3) % 2), sz((x0 + x1) * 0.5) + 0.024)))
    for i in range(nu):
        bm.faces.new((vf[nv][i + 1], vf[nv][i], tip))
        bm.faces.new((vb[nv][i], vb[nv][i + 1], tip))
    bm.faces.new((vf[nv][0], vb[nv][0], tip))
    bm.faces.new((vb[nv][nu], vf[nv][nu], tip))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    o = K.mesh_from_bm("Board", bm, "shield", WOOD, smooth=False)
    mods = o.modifiers.new("Bev", 'BEVEL')
    mods.width = 0.004
    mods.segments = 1
    K.apply_mods(o)
    objs.append(o)
    # gouges and a cleft in the planks: darker nicks along an edge
# iron: a rim round the top and sides, three bands across with rivets, a spiked boss, skull
def rim_pts(frac_a, frac_b, y_fn, n=18, off=0.0):
    return [Vector(G(-SH_W / 2 + SH_W * (frac_a + (frac_b - frac_a) * i / n), y_fn(i / n), sz(-SH_W / 2 + SH_W * (frac_a + (frac_b - frac_a) * i / n)) - 0.012 - off)) for i in range(n + 1)]


for yb, wb in ((SH_BOT + 0.11, 0.03), (0.86, 0.034), (SH_TOP - 0.1, 0.03)):
    pts = rim_pts(0.0, 1.0, lambda t, yb=yb: yb + 0.008 * math.sin(t * 7.0), 22)
    add(K.loft("Band", pts, [(0.0125, 0.032)] * len(pts), "shield", IRON, 6), "shield")
    for i in range(9):
        t = i / 8.0
        x = -SH_W / 2 + 0.035 + (SH_W - 0.07) * t
        add(K.blob("Rivet", Vector(G(x, yb + 0.008 * math.sin(t * 7.0), sz(x) - 0.045)), (0.0105, 0.0105, 0.007), "shield", IRON, 10, 6), "shield")
    for sx in (-1, 1):                                       # the band's end flares in a plate
        x = sx * (SH_W / 2 - 0.02)
        add(K.blob("EndPlate", Vector(G(x, yb, sz(x) - 0.03)), (0.034, 0.05, 0.012), "shield", IRON, 14, 8), "shield")
for sx in (-1, 1):                                           # the edge strips down both sides
    x = sx * (SH_W / 2 + 0.002)
    pts = [Vector(G(x, SH_BOT + 0.01 + (SH_TOP - SH_BOT - 0.12) * i / 14, sz(x) + 0.024)) for i in range(15)]
    add(K.loft("Edge", pts, [(0.012, 0.03)] * 15, "shield", IRON, 6), "shield")
# the boss: an iron dome with a spike on a flange of rivets, a skull nailed above, eyes lit
bc = np.array([0.0, 1.0, sz(0.0) - 0.05])
dome = L.lathe("Boss", [(0.15, 0.0), (0.145, 0.014), (0.12, 0.04), (0.085, 0.068), (0.045, 0.086), (0.0, 0.092)], (bc[0], bc[1], bc[2]), IRON, "shield", nth=28, wobble=0.03, seed=3.0, thick=0.008)
for p in dome.data.vertices:
    p.co = Vector((p.co.x, p.co.y, p.co.z))
# the lathe's axis is vertical; rotate it to face front: swap y and z (blender: front is +y)
for p in dome.data.vertices:
    c0 = Vector(G(*bc))
    d = p.co - c0
    p.co = c0 + Vector((d.x, d.z, d.y * -1.0))
dome.data.update()
add(dome, "shield")
add(GK.claw("Spike", Vector(G(bc[0], bc[1], bc[2] - 0.085)), Vector(G(0, 0, -1.0)), 0.07, 0.022, "shield", IRON, 0.0), "shield")
for i in range(10):
    a = math.tau * i / 10.0
    add(K.blob("Rivet", Vector(G(bc[0] + math.cos(a) * 0.14, bc[1] + math.sin(a) * 0.14, bc[2] - 0.0)), (0.011, 0.011, 0.008), "shield", IRON, 10, 6), "shield")
sk_c = np.array([0.0, 1.3, sz(0.0) - 0.07])


def cranium(c):                                           # unit sphere -> a skull: narrow at the jaw, full at the temples
    p = Vector(c)
    if p.z < 0.0:
        p.x *= 1.0 + 0.32 * p.z
        p.y *= 1.0 + 0.2 * p.z
    p.x *= 1.0 - 0.1 * max(p.y, 0.0)
    return p


add(K.blob("Skull", Vector(G(*sk_c)), (0.056, 0.066, 0.06), "shield", BONE, 32, 20, cranium), "shield")
add(K.blob("Brow", Vector(G(sk_c[0], sk_c[1] + 0.022, sk_c[2] - 0.038)), (0.056, 0.012, 0.014), "shield", BONE, 18, 8), "shield")
for sx in (-1, 1):
    add(K.blob("Cheek", Vector(G(sx * 0.04, sk_c[1] - 0.026, sk_c[2] - 0.034)), (0.014, 0.012, 0.018), "shield", BONE, 12, 8), "shield")
    add(K.blob("Socket", Vector(G(sx * 0.0245, sk_c[1] + 0.004, sk_c[2] - 0.042)), (0.02, 0.016, 0.013), "shield", IRON, 14, 10), "shield")
    add(K.blob("Eye", Vector(G(sx * 0.0245, sk_c[1] + 0.004, sk_c[2] - 0.05)), (0.011, 0.009, 0.006), "shield", EYE, 10, 6), "shield")
add(K.blob("Nose", Vector(G(0.0, sk_c[1] - 0.026, sk_c[2] - 0.05)), (0.01, 0.012, 0.01), "shield", IRON, 10, 6), "shield")
add(K.blob("Jaw", Vector(G(0.0, sk_c[1] - 0.07, sk_c[2] - 0.026)), (0.042, 0.024, 0.032), "shield", BONE, 18, 10), "shield")
for k in range(8):
    x = (k - 3.5) * 0.0105
    add(GK.claw("Tooth", Vector(G(x, sk_c[1] - 0.048, sk_c[2] - 0.05)), Vector(G(0, -1.0, -0.1)), 0.016, 0.004, "shield", BONE, 0.0), "shield")
    add(GK.claw("Tooth", Vector(G(x, sk_c[1] - 0.062, sk_c[2] - 0.052)), Vector(G(0, 1.0, -0.1)), 0.012, 0.004, "shield", BONE, 0.0), "shield")
for k in range(4):
    add(K.blob("Nail", Vector(G((k - 1.5) * 0.045, sk_c[1] - 0.12, sk_c[2] + 0.01)), (0.008, 0.008, 0.009), "shield", IRON, 8, 6), "shield")
# broken arrows stuck in it, and a hatchet head
for k, (ax_, ay_, ang) in enumerate(((-0.24, 1.12, 0.5), (0.28, 0.72, -0.4), (0.12, 1.48, 0.2))):
    base = np.array([ax_, ay_, sz(ax_) - 0.03])
    d = np.array([math.sin(ang) * 0.4, math.cos(ang) * 0.5, -0.8])
    d /= np.linalg.norm(d)
    tip = base + d * 0.02
    end = base + d * (0.18 + 0.06 * k)
    add(K.loft("Arrow", [Vector(G(*tip)), Vector(G(*end))], [0.006, 0.006], "shield", WOOD, 6), "shield")
    for f in range(3):
        a = f * 2.1
        fp = end - d * 0.0
        add(K.blob("Fletch", Vector(G(*(end - d * 0.015 * f + np.array([math.cos(a) * 0.01, math.sin(a) * 0.01, 0])))), (0.004, 0.02, 0.003), "shield", BONE, 6, 4), "shield")
# the back: two battens, an arm-strap and a grip (seen when it swings aside)
for yb in (0.62, 1.4):
    add(K.loft("Batten", [Vector(G(-SH_W / 2 + 0.03, yb, sz(-SH_W / 2 + 0.03) + 0.07)), Vector(G(0, yb, sz(0) + 0.07)), Vector(G(SH_W / 2 - 0.03, yb, sz(SH_W / 2 - 0.03) + 0.07))], [(0.035, 0.014)] * 3, "shield", WOOD, 6), "shield")
add(K.loft("ArmStrap", [Vector(G(-0.14, 0.85, sz(-0.14) + 0.09)), Vector(G(-0.14, 1.0, sz(-0.14) + 0.12)), Vector(G(-0.14, 1.15, sz(-0.14) + 0.09))], [(0.026, 0.006)] * 3, "shield", LEATHER, 6), "shield")
add(K.loft("Grip", [Vector(G(0.1, 0.98, sz(0.1) + 0.1)), Vector(G(0.1, 1.2, sz(0.1) + 0.1))], [0.016, 0.016], "shield", WOOD, 8), "shield")
rigid = {"shield": ("shield_chest", S["chest"])}

if PREVIEW:
    L.preview_sheet(PREVIEW, 0.95, 3.6)
L.report(objs)
print("BIPED", KIND, "parts", len(objs), "tris", sum(L.tri_count(o) for o in objs if o.type == 'MESH'))
if EXPORT:
    GK.export_skinned(objs, MATS, "grunt_" + KIND, S, WTS, rigid, 2048, 19000, pairs=PAIRS)
