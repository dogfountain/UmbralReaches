"""Horses (art pass): a realistic skinned horse per breed, built from scratch.

  tools/blender/run.sh horse_build.py -- --breed palfrey [--preview PATH] [--no-export] [--lite]
Writes art/models/horse_<breed>.glb (one skinned mesh on a 32-bone skeleton; walk, trot and gallop
are driven in script from the gait phase, core/world/mount/horse.gd) and the baked atlas
art/textures/horse_<breed>_{albedo,normal,orm,emit}.png (2048). The .blend source goes to art/blender/.

The flesh is fused (torso+neck metaballs, a lofted head, lofted legs, one voxel remesh), the tack is
draped on it by ray casts, hair is wide opaque locks (no alpha, so nothing shimmers with AA off). The
fused high mesh bakes normal / AO / colour onto a ~6k-triangle skinned body.
"""
import bpy
import bmesh
import math
import os
import random
import sys
import numpy as np
from mathutils import Vector, Matrix

sys.path.insert(0, os.path.dirname(__file__))
import boss_kit as K
import grunt_kit as GK
import horse_kit as HK
import horse_tack as HT
from boss_kit import G

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
BREED = args[args.index("--breed") + 1] if "--breed" in args else "palfrey"
PREVIEW = args[args.index("--preview") + 1] if "--preview" in args else ""
EXPORT = "--no-export" not in args
SIZE = 1024 if "--lite" in args else 2048
BODY_TRIS = 5200

# scale (sx lateral, sy height, sz length) and the shape knobs of each breed; coat colours.
BREEDS = {
    "palfrey": dict(S=(1.0, 1.0, 1.0), neck=1.0, crest=1.0, head=1.0, headw=1.0, barrel=0.93, bone=1.0, fetlock=1.0, hoof=1.0, feather=0.0, mane=1.0, tail=1.0, ear=1.0,
                    coat=(0.14, 0.058, 0.032), points=(0.025, 0.021, 0.019), mane_col=(0.035, 0.03, 0.03), socks="", blaze=0.5, dapple=0.0, dorsal=0.0,
                    cloth=(0.28, 0.05, 0.05), trim=(0.5, 0.36, 0.14), leather=(0.2, 0.1, 0.05), seed=3),
    "garron": dict(S=(1.04, 0.935, 0.97), neck=1.1, crest=1.2, head=1.04, headw=1.1, barrel=1.02, bone=1.15, fetlock=1.12, hoof=1.12, feather=0.7, mane=1.35, tail=1.25, ear=0.95,
                   coat=(0.2, 0.2, 0.21), points=(0.085, 0.082, 0.082), mane_col=(0.5, 0.5, 0.5), socks="", blaze=0.0, dapple=0.8, dorsal=0.0,
                   cloth=(0.09, 0.15, 0.27), trim=(0.45, 0.45, 0.48), leather=(0.16, 0.1, 0.06), seed=5),
    "fenpony": dict(S=(0.98, 0.865, 0.9), neck=0.95, crest=1.1, head=0.93, headw=1.05, barrel=1.04, bone=1.1, fetlock=1.05, hoof=1.0, feather=0.5, mane=1.55, tail=1.35, ear=0.9,
                    coat=(0.26, 0.185, 0.1), points=(0.05, 0.04, 0.03), mane_col=(0.07, 0.05, 0.035), socks="", blaze=0.0, dapple=0.0, dorsal=1.0,
                    cloth=(0.1, 0.19, 0.09), trim=(0.38, 0.32, 0.2), leather=(0.18, 0.1, 0.05), seed=9),
    "draught": dict(S=(1.18, 1.14, 1.1), neck=1.25, crest=1.45, head=1.1, headw=1.2, barrel=1.07, bone=1.35, fetlock=1.3, hoof=1.4, feather=1.0, mane=1.25, tail=1.1, ear=1.0,
                    coat=(0.045, 0.04, 0.04), points=(0.03, 0.026, 0.026), mane_col=(0.03, 0.026, 0.026), socks="all", blaze=1.0, dapple=0.0, dorsal=0.0,
                    cloth=(0.36, 0.2, 0.04), trim=(0.2, 0.1, 0.04), leather=(0.12, 0.07, 0.04), seed=7),
}
B = BREEDS[BREED]
rng = random.Random(B["seed"] * 101)
NAME = "horse_" + BREED

K.reset()
sc = bpy.context.scene

# --- materials --------------------------------------------------------------------------------------------


def coat_mat():
    m = K.Mat("Coat")
    base = B["coat"]
    pts = B["points"]
    sep = m.n('ShaderNodeSeparateXYZ')
    m.links.new(m.coord.outputs['Object'], sep.inputs[0])
    X, Y, Z = sep.outputs['X'], sep.outputs['Y'], sep.outputs['Z']        # Blender: Y forward, Z up
    # fur streaks lie along the body: a noise stretched along Y (a long flat scale)
    mp = m.n('ShaderNodeMapping')
    mp.inputs['Scale'].default_value = (70.0, 7.0, 70.0)
    m.links.new(m.coord.outputs['Object'], mp.inputs['Vector'])
    st = m.n('ShaderNodeTexNoise')
    st.inputs['Scale'].default_value = 1.0
    st.inputs['Detail'].default_value = 5.0
    st.inputs['Roughness'].default_value = 0.65
    m.links.new(mp.outputs['Vector'], st.inputs['Vector'])
    streak = st.outputs['Fac']
    mp2 = m.n('ShaderNodeMapping')
    mp2.inputs['Scale'].default_value = (260.0, 260.0, 260.0)
    m.links.new(m.coord.outputs['Object'], mp2.inputs['Vector'])
    st2 = m.n('ShaderNodeTexNoise')
    st2.inputs['Scale'].default_value = 1.0
    st2.inputs['Detail'].default_value = 2.0
    m.links.new(mp2.outputs['Vector'], st2.inputs['Vector'])
    fine = st2.outputs['Fac']
    blot = m.noise(3.0, 6.0, 0.6)
    weather = m.noise(7.0, 5.0, 0.55)
    col = m.mix(m.ramp(blot, [(0.35, (0, 0, 0)), (0.65, (1, 1, 1))]), base, tuple(c * 0.7 for c in base))
    col = m.mix(m.ramp(weather, [(0.66, (0, 0, 0)), (0.8, (0.3, 0.3, 0.3))]), col, tuple(min(1.0, c * 1.35 + 0.02) for c in base))   # sun-bleached patches
    # dapple (greys): soft round spots
    if B["dapple"] > 0.0:
        vo = m.voronoi(11.0, 'F1')
        dap = m.ramp(vo, [(0.15, (1, 1, 1)), (0.45, (0, 0, 0))])
        col = m.mix(m.mono(dap), col, tuple(min(1.0, c * 1.55) for c in base))
    # points: the lower legs, muzzle, ears and tail root darker
    low = m.ramp(Z, [(0.35, (1, 1, 1)), (0.75, (0, 0, 0))])
    face = m.math('MULTIPLY', m.math('GREATER_THAN', Y, 0.9), m.math('GREATER_THAN', Z, 1.25))
    face_lo = m.math('MULTIPLY', face, m.ramp(Z, [(1.3, (1, 1, 1)), (1.46, (0, 0, 0))]))
    pmask = m.math('MAXIMUM', m.mono(low), face_lo)
    pmask = m.math('MULTIPLY', pmask, 1.0 if BREED != "garron" else 0.8)
    col = m.mix(pmask, col, pts)
    # dun: a dark dorsal stripe and faint leg bars
    if B["dorsal"] > 0.0:
        stripe = m.math('MULTIPLY', m.math('LESS_THAN', m.math('ABSOLUTE', X), 0.03), m.math('GREATER_THAN', Z, 1.3))
        bars = m.math('MULTIPLY', m.math('GREATER_THAN', m.noise(40.0, 1.0, 0.5), 0.5), m.math('LESS_THAN', Z, 0.75))
        col = m.mix(m.math('MULTIPLY', m.math('MAXIMUM', stripe, m.math('MULTIPLY', bars, 0.5)), 0.85), col, (0.04, 0.03, 0.02))
    # white: a blaze down the face, socks
    wcol = (0.5, 0.47, 0.42)
    if B["blaze"] > 0.0:
        bl = m.math('MULTIPLY', m.math('MULTIPLY', m.math('LESS_THAN', m.math('ABSOLUTE', X), 0.022 * B["blaze"] + 0.004), m.math('GREATER_THAN', Y, 0.93)), m.math('GREATER_THAN', Z, 1.28))
        col = m.mix(m.math('MULTIPLY', bl, 0.9), col, wcol)
    if B["socks"]:
        lim = 0.34 if B["socks"] == "all" else 0.3
        sock = m.ramp(Z, [(lim - 0.05, (1, 1, 1)), (lim + 0.05, (0, 0, 0))])
        if B["socks"] == "hind":
            sock = m.mono(sock)
            sock = m.math('MULTIPLY', sock, m.math('GREATER_THAN', Y, -1.5))
        else:
            sock = m.mono(sock)
        col = m.mix(sock, col, wcol)
    # mud: splashed up the legs and the belly, dried grey-brown
    mud = m.math('MULTIPLY', m.ramp(Z, [(0.1, (1, 1, 1)), (0.55, (0, 0, 0))]), 1.0)
    mud = m.math('MULTIPLY', m.mono(mud), m.mono(m.ramp(m.noise(9.0, 4.0, 0.6), [(0.42, (0, 0, 0)), (0.62, (1, 1, 1))])))
    col = m.mix(m.math('MULTIPLY', mud, 0.8), col, (0.09, 0.07, 0.05))
    # fur: grain from the streak noise darkens/lightens each strand a little
    col = m.mix(m.math('MULTIPLY', m.math('SUBTRACT', streak, 0.5, True), 0.7), col, tuple(c * 0.5 for c in base))
    h = m.math('ADD', m.math('MULTIPLY', streak, 1.0), m.math('MULTIPLY', fine, 0.5))
    r = m.math('ADD', 0.72, m.math('MULTIPLY', m.math('SUBTRACT', blot, 0.5), 0.25))
    return m.finish(col, r, 0.0, h, 0.45, 0.0014)


def hoof_mat():
    m = K.Mat("Hoof")
    mp = m.n('ShaderNodeMapping')
    mp.inputs['Scale'].default_value = (110.0, 110.0, 5.0)
    m.links.new(m.coord.outputs['Object'], mp.inputs['Vector'])
    t = m.n('ShaderNodeTexNoise')
    t.inputs['Detail'].default_value = 4.0
    m.links.new(mp.outputs['Vector'], t.inputs['Vector'])
    col = m.ramp(t.outputs['Fac'], [(0.3, (0.012, 0.01, 0.009)), (0.7, (0.045, 0.036, 0.03))])
    return m.finish(col, 0.48, 0.0, t.outputs['Fac'], 0.5, 0.0018)


def eye_mat():
    m = K.Mat("Eye")
    return m.finish((0.025, 0.014, 0.01), 0.12, 0.0, None, emit=(0.8, 0.45, 0.16), emit_strength=0.5)


def dark_mat():
    m = K.Mat("Dark")
    return m.finish((0.012, 0.01, 0.01), 0.55)


COAT = coat_mat()
HOOF = hoof_mat()
EYE = eye_mat()
DARK = dark_mat()
LEATHER = GK.leather("Leather", B["leather"], 9.0)
DKLEATHER = GK.leather("DarkLeather", tuple(c * 0.55 for c in B["leather"]), 9.0)
IRON = GK.iron("Iron", (0.13, 0.12, 0.115), (0.2, 0.1, 0.05))
CLOTH = GK.cloth("Wool", B["cloth"], "caban", 14.0, (0.04, 0.035, 0.03))
TRIM = GK.cloth("Trim", B["trim"], "rough_linen", 14.0, (0.05, 0.04, 0.03))
GLASS = GK.glow("Glass", (1.0, 0.58, 0.2), 5.0, (0.15, 0.1, 0.05))
MATS = [COAT, HOOF, EYE, DARK, LEATHER, DKLEATHER, IRON, CLOTH, TRIM, GLASS]

# --- body -------------------------------------------------------------------------------------------------
P = dict(B)
J = HK.joints(P)
parts = HK.build_body(P, J)
high = HK.fuse_parts(parts, 0.0075, 3)
high.name = "High"
print("HIGH verts", len(high.data.vertices))
high.data.materials.clear()
high.data.materials.append(COAT.m)

objs = []     # the game mesh parts (low body first)


def add(o, mat=None):
    if mat is not None:
        o.data.materials.clear()
        o.data.materials.append(mat.m if hasattr(mat, "m") else mat)
    objs.append(o)
    return o


# the game body: a decimated copy
low = high.copy()
low.data = high.data.copy()
low.name = "Body"
bpy.context.scene.collection.objects.link(low)
bpy.ops.object.select_all(action='DESELECT')
low.select_set(True)
bpy.context.view_layer.objects.active = low
tri_hi = sum(len(p.vertices) - 2 for p in low.data.polygons)
dm = low.modifiers.new("Dec", 'DECIMATE')
dm.ratio = min(1.0, BODY_TRIS / tri_hi)
dm.use_collapse_triangulate = True
K.apply_mods(low)
for p in low.data.polygons:
    p.use_smooth = True
low["sock"] = "body"
print("LOW tris", sum(len(p.vertices) - 2 for p in low.data.polygons))
add(low, COAT)

# weights for the body from the part meshes
funcs = HK.weight_funcs(J)
HK.assign_weights(low, parts, funcs)
low["weighted"] = 1

# small rigid parts
for e in HK.ears(P, J):
    add(e, COAT)
for e in HK.eyes(P, EYE):
    add(e, EYE)
for e in HK.nostrils(P, DARK):
    add(e, DARK)
for h in HK.hooves(P, J, HOOF):
    add(h, HOOF)

# tack, draped on the high mesh
tmats = {"leather": LEATHER, "dark": DKLEATHER, "metal": IRON, "cloth": CLOTH, "trim": TRIM, "glass": GLASS}
surf = HT.Surf(high)
tack, info = HT.build(P, surf, tmats)
tack += HT.bridle(P, surf, tmats)
for t in tack:
    add(t)
print("TACK", info)

# hair: wide opaque locks (no alpha)
HAIR = []
for o in HK.mane(P, J, rng, 1, 56) + HK.forelock(P, J, rng, 8) + HK.tail(P, J, rng, 46) + HK.feathers(P, J, rng):
    HAIR.append(o)
    add(o)

# drop the part meshes, the high stays for the bake only
for o in parts.values():
    bpy.data.objects.remove(o)

_cnt = {}
for o in objs:
    _cnt[o.name.split(".")[0]] = _cnt.get(o.name.split(".")[0], 0) + sum(len(p.vertices) - 2 for p in o.data.polygons)
print("TRIS BY PART", _cnt)

# --- UVs: everything but the hair into the left 78% of the atlas, hair strips on the right --------------------
nonhair = [o for o in objs if not o.get("hair")]
bpy.ops.object.select_all(action='DESELECT')
for o in nonhair:
    o.select_set(True)
bpy.context.view_layer.objects.active = low
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.004)
bpy.ops.uv.pack_islands(margin=0.004)
bpy.ops.object.mode_set(mode='OBJECT')
for o in nonhair:
    for d in o.data.uv_layers.active.data:
        d.uv = (d.uv[0] * 0.78, d.uv[1])
for o in HAIR:
    uvl = o.data.uv_layers.active
    for d in uvl.data:
        d.uv = (0.8 + 0.2 * d.uv[0], d.uv[1])

# --- bake --------------------------------------------------------------------------------------------------------
IMG = {}
for key, cs in (("albedo", 'sRGB'), ("normal", 'Non-Color'), ("rough", 'Non-Color'), ("metal", 'Non-Color'), ("ao", 'Non-Color'), ("emit", 'sRGB')):
    img = bpy.data.images.new(NAME + "_" + key, SIZE, SIZE, alpha=False, float_buffer=False)
    img.colorspace_settings.name = cs
    IMG[key] = img
targets = []
for m in MATS:
    t = m.nodes.new('ShaderNodeTexImage')
    m.nodes.active = t
    targets.append((m, t))
sc.render.bake.margin = 8
sc.cycles.use_denoising = False
rest = [o for o in nonhair if o is not low]


def bake(kind, key, route):
    for m, t in targets:
        t.image = IMG[key]
        m.nodes.active = t
        if route:
            K._route(m, route)
    sc.cycles.samples = 24 if kind == 'AO' else 1
    # the body: high -> low
    bpy.ops.object.select_all(action='DESELECT')
    high.select_set(True)
    low.select_set(True)
    bpy.context.view_layer.objects.active = low
    bpy.ops.object.bake(type=kind, use_selected_to_active=True, cage_extrusion=0.03, max_ray_distance=0.06, use_clear=True, margin=8)
    # everything else, onto itself
    bpy.ops.object.select_all(action='DESELECT')
    for o in rest:
        o.select_set(True)
    bpy.context.view_layer.objects.active = rest[0]
    bpy.ops.object.bake(type=kind, use_selected_to_active=False, use_clear=False, margin=8)
    for m, t in targets:
        if route:
            K._unroute(m)
    print("BAKED", key)


for key, kind, route in (("albedo", 'EMIT', "color"), ("rough", 'EMIT', "rough"), ("metal", 'EMIT', "metal"), ("emit", 'EMIT', "emit"), ("normal", 'NORMAL', None), ("ao", 'AO', None)):
    bake(kind, key, route)


def px(img):
    a = np.empty(SIZE * SIZE * 4, dtype=np.float32)
    img.pixels.foreach_get(a)
    return a.reshape(SIZE, SIZE, 4)


alb, nor, rgh, met, ao, emi = (px(IMG[k]) for k in ("albedo", "normal", "rough", "metal", "ao", "emit"))

# hair strip: strands along v (rows), six slices across, root dark to a paler weathered tip
x0 = int(SIZE * 0.8)
W = SIZE - x0
nrng = np.random.default_rng(B["seed"])
mane = np.array(B["mane_col"], dtype=np.float32)
cols = np.arange(W)
strand = np.zeros((SIZE, W), dtype=np.float32)
for sidx in range(6):
    sl = slice(int(sidx * W / 6.0), int((sidx + 1) * W / 6.0))
    wsl = sl.stop - sl.start
    for k in range(wsl // 2 + 1):
        cx = nrng.uniform(0, wsl)
        wdt = nrng.uniform(0.7, 1.6)
        ph = nrng.uniform(0, 6.28)
        rows = np.arange(SIZE)
        wob = np.sin(rows * nrng.uniform(0.004, 0.02) + ph) * nrng.uniform(0.5, 3.0)
        d = (np.arange(wsl)[None, :] - (cx + wob)[:, None]) / wdt
        strand[:, sl] = np.maximum(strand[:, sl], (np.exp(-d * d) * nrng.uniform(0.5, 1.0)).astype(np.float32))
v = np.linspace(0.0, 1.0, SIZE, dtype=np.float32)[:, None]
tone = 0.55 + 0.7 * strand
tone *= (0.65 + 0.55 * v)                                  # root dark, tips weathered paler
tone *= 1.0 + 0.15 * np.sin(v * 31.0 + 1.0)
tint = np.array(B["mane_col"], dtype=np.float32)
tip = np.minimum(tint * 1.7 + 0.03, 1.0)
alb[:, x0:, :3] = (tint[None, None, :] * (1.0 - v[:, :, None] * 0.6) + tip[None, None, :] * (v[:, :, None] * 0.6)) * tone[:, :, None]
alb[:, x0:, 3] = 1.0
gy, gx = np.gradient(strand)
nor[:, x0:, 0] = 0.5 - gx * 0.7
nor[:, x0:, 1] = 0.5 - gy * 0.2
nor[:, x0:, 2] = 1.0
rgh[:, x0:, :3] = (0.55 - 0.1 * strand)[:, :, None]
met[:, x0:, :3] = 0.0
ao[:, x0:, :3] = (0.55 + 0.45 * v * (0.5 + 0.5 * strand))[:, :, None]
emi[:, x0:, :3] = 0.0
alb[:, x0:, :3] = np.clip(alb[:, x0:, :3], 0, 1)

orm = np.ones((SIZE, SIZE, 4), dtype=np.float32)
orm[:, :, 0] = ao[:, :, 0]
orm[:, :, 1] = rgh[:, :, 0]
orm[:, :, 2] = met[:, :, 0]
tex_dir = os.path.join(ROOT, "art", "textures")
os.makedirs(tex_dir, exist_ok=True)


def save(arr, suffix, cs):
    img = bpy.data.images.new(NAME + "_" + suffix + "_out", SIZE, SIZE, alpha=False)
    img.colorspace_settings.name = cs
    arr = arr.copy()
    arr[:, :, 3] = 1.0
    img.pixels.foreach_set(arr.ravel())
    img.filepath_raw = os.path.join(tex_dir, "%s_%s.png" % (NAME, suffix))
    img.file_format = 'PNG'
    img.save()
    print("SAVED", img.filepath_raw)


if EXPORT:
    save(alb, "albedo", 'sRGB')
    save(nor, "normal", 'Non-Color')
    save(orm, "orm", 'Non-Color')
    save(emi, "emit", 'sRGB')

# --- weights for everything but the body ---------------------------------------------------------------------
SPINE_W = funcs["spine"]


def sock_w(o):
    s = o["sock"]
    if s in ("barrel", "chest", "head", "lantern"):
        return lambda p: {s: 1.0}
    if s.startswith("mane_"):
        k = s[-1]
        return lambda p: {"neck" + k: 1.0}
    if s == "tail":
        return lambda p: GK.chain_w(p, [("tail0", J["tail0"]), ("tail1", J["tail1"]), ("tail2", J["tail2"]), ("tail3", J["tail3"])], [0.1, 0.1, 0.1])
    if s == "neck_rein":
        return SPINE_W
    return lambda p: {s: 1.0}        # ear_r, fr_fet, hl_leg, ...


for o in objs:
    if o is low:
        continue
    s = o["sock"]
    if s in ("fr", "fl", "hr", "hl"):
        pass
    s = {"fr": "fr_fet", "fl": "fl_fet", "hr": "hr_fet", "hl": "hl_fet"}.get(s, s)
    o["sock"] = s
    GK.weigh(o, sock_w(o))
    # the lantern's weights are the pendulum bone; hair on the mane also follows its sway bone at the tips
    if o["sock"].startswith("mane_"):
        k = o["sock"][-1]
        root = None
        for v in o.data.vertices:
            pass
        ws = {}
        co = [o.matrix_world @ v.co for v in o.data.vertices]
        top = max(co, key=lambda c: c.z)
        for v in o.data.vertices:
            p = o.matrix_world @ v.co
            f = min(1.0, max(0.0, ((p - top).length - 0.03) / 0.2))
            f = f * f * (3 - 2 * f)
            for g in list(o.vertex_groups):
                g.remove([v.index])
            gn = o.vertex_groups.get("neck" + k) or o.vertex_groups.new(name="neck" + k)
            gm = o.vertex_groups.get("mane" + k) or o.vertex_groups.new(name="mane" + k)
            gn.add([v.index], 1.0 - f, 'REPLACE')
            gm.add([v.index], f, 'REPLACE')

# --- scale the breed, build the armature, join, export -----------------------------------------------------------------
S = B["S"]
M = Matrix.Diagonal((S[0], S[2], S[1], 1.0))        # Blender (x, y = Godot -z, z = Godot y)
for o in objs:
    o.data.transform(M)
    o.data.update()
for k in J:
    J[k] = M @ J[k]
info_scaled = {"seat_y": info["seat_y"] * S[1], "stirrup_y": info["stirrup_y"] * S[1], "stirrup_x": info["stirrup_x"] * S[0],
               "bw": info["bw"] * S[0], "bc": info["bc"] * S[1], "bl": 0.3 * S[2],
               "lantern": tuple(info["lantern_glass"]), "back_y": info["back_y"] * S[1]}
print("INFO", BREED, info_scaled)

E = HK.bone_ends(J)
arm_data = bpy.data.armatures.new("Armature")
arm = bpy.data.objects.new("Armature", arm_data)
sc.collection.objects.link(arm)
bpy.ops.object.select_all(action='DESELECT')
arm.select_set(True)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode='EDIT')
made = {}
for name in HK.PARENT:
    h, t = E[name]
    eb = arm_data.edit_bones.new(name)
    eb.head = h
    eb.tail = t if (t - h).length > 0.01 else h + Vector((0, 0, 0.05))
    made[name] = eb
for name, par in HK.PARENT.items():
    if par:
        made[name].parent = made[par]
bpy.ops.object.mode_set(mode='OBJECT')

# one material, one skinned mesh
atlas = bpy.data.materials.new("Atlas")
for o in objs:
    o.data.materials.clear()
    o.data.materials.append(atlas)
    for p in o.data.polygons:
        p.use_smooth = True
bpy.data.objects.remove(high)
bpy.ops.object.select_all(action='DESELECT')
for o in objs:
    o.select_set(True)
bpy.context.view_layer.objects.active = low
bpy.ops.object.join()
body = bpy.context.view_layer.objects.active
body.name = "horse"
body.data.name = "horse"
body.parent = arm
md = body.modifiers.new("Armature", 'ARMATURE')
md.object = arm
print("FINAL tris", sum(len(p.vertices) - 2 for p in body.data.polygons), "verts", len(body.data.vertices))

if PREVIEW:
    for k_ in ('albedo', 'normal'):
        im_ = IMG[k_]
        im_.filepath_raw = PREVIEW.replace('.png', '_atlas_%s.png' % k_)
        im_.file_format = 'PNG'
        im_.save()
    # textured stills in Cycles: the baked atlas on the joined mesh
    mat = bpy.data.materials.new("PV")
    mat.use_nodes = True
    nt = mat.node_tree
    bs = nt.nodes["Principled BSDF"]
    for key, sock in (("albedo", "Base Color"),):
        t = nt.nodes.new('ShaderNodeTexImage')
        t.image = IMG[key]
        nt.links.new(t.outputs[0], bs.inputs[sock])
    t = nt.nodes.new('ShaderNodeTexImage')
    t.image = IMG["normal"]
    nm = nt.nodes.new('ShaderNodeNormalMap')
    nt.links.new(t.outputs[0], nm.inputs['Color'])
    nt.links.new(nm.outputs[0], bs.inputs['Normal'])
    t = nt.nodes.new('ShaderNodeTexImage')
    t.image = IMG["rough"]
    nt.links.new(t.outputs[0], bs.inputs['Roughness'])
    t = nt.nodes.new('ShaderNodeTexImage')
    t.image = IMG["emit"]
    nt.links.new(t.outputs[0], bs.inputs['Emission Color'])
    bs.inputs['Emission Strength'].default_value = 2.0
    body.data.materials.clear()
    body.data.materials.append(mat)
    K.preview(PREVIEW, 0.85, 5.2, views=((90, 1.1), (50, 1.5), (-30, 1.3), (160, 1.4)))

if EXPORT:
    os.makedirs(os.path.join(ROOT, "art", "blender"), exist_ok=True)
    body.data.materials.clear()
    body.data.materials.append(atlas)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "art", "blender", NAME + ".blend"))
    bpy.ops.object.select_all(action='DESELECT')
    arm.select_set(True)
    body.select_set(True)
    path = os.path.join(ROOT, "art", "models", NAME + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True, export_apply=True, export_yup=True,
                              export_materials='NONE', export_normals=True, export_texcoords=True, export_skins=True,
                              export_animations=False, export_all_influences=False)
    print("EXPORTED", path)
