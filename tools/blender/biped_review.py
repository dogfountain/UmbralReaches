"""Review renders of an exported biped GLB + its atlas (the proof the remodel asks for): a turnaround (front, 3/4,
side, back) under a neutral key and under the night key, and POSED renders that bend the skeleton the way the game
does (the flat armature is driven by forward kinematics over the rig's joint tree): arms raised overhead for the
wind-up, kneeling, a stride, a lunge with the shield arm forward. Rigid parts (bell_, shield_, staff_) ride their joint.

  tools/blender/run.sh biped_review.py -- --kind chanter --dir <glb dir> --out <out dir> [--res 640] [--samples 32]
                                          [--only turn|pose] [--head 1.62]
Writes <out>/turn_<view>_<light>.png, pose_<pose>_<view>.png, turn_sheet.png, pose_sheet.png.
Front of the model is Blender +Y (Godot -Z).
"""
import bpy
import math
import os
import sys
import numpy as np
from mathutils import Vector, Matrix, Euler

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(n, d):
    return args[args.index(n) + 1] if n in args else d


KIND = arg("--kind", "wretch")
DIR = arg("--dir", "/private/tmp/claude-501/m/out")
OUT = arg("--out", "/private/tmp/claude-501/m/review_" + KIND)
SAMPLES = int(arg("--samples", "32"))
RES = int(arg("--res", "640"))
ONLY = arg("--only", "")
os.makedirs(OUT, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
sc.render.engine = 'CYCLES'
sc.cycles.device = 'CPU'
if os.environ.get("BOSS_BAKE_CPU", "") != "1":
    try:
        prefs = bpy.context.preferences.addons["cycles"].preferences
        prefs.compute_device_type = 'METAL'
        if hasattr(prefs, "kernel_optimization_level"):
            prefs.kernel_optimization_level = 'OFF'
        if hasattr(prefs, "use_metalrt"):
            prefs.use_metalrt = False
        prefs.get_devices()
        for d in prefs.devices:
            d.use = d.type != 'CPU'
        sc.cycles.device = 'GPU'
    except Exception as e:
        print("GPU unavailable", e)
sc.cycles.samples = SAMPLES
sc.cycles.use_denoising = True
sc.render.resolution_x = RES
sc.render.resolution_y = int(RES * 1.25)
sc.view_settings.view_transform = 'AgX'

bpy.ops.import_scene.gltf(filepath=os.path.join(DIR, "grunt_%s.glb" % KIND))
arm = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']


def img(key, cs):
    im = bpy.data.images.load(os.path.join(DIR, "grunt_%s_%s.png" % (KIND, key)))
    im.colorspace_settings.name = cs
    return im


m = bpy.data.materials.new("Atlas")
m.use_nodes = True
nt = m.node_tree
bs = nt.nodes["Principled BSDF"]


def tex(im):
    t = nt.nodes.new('ShaderNodeTexImage')
    t.image = im
    return t


ta, tn, to, te = tex(img("albedo", 'sRGB')), tex(img("normal", 'Non-Color')), tex(img("orm", 'Non-Color')), tex(img("emit", 'sRGB'))
nm = nt.nodes.new('ShaderNodeNormalMap')
nm.inputs['Strength'].default_value = 1.2
nt.links.new(tn.outputs['Color'], nm.inputs['Color'])
nt.links.new(nm.outputs['Normal'], bs.inputs['Normal'])
sep = nt.nodes.new('ShaderNodeSeparateColor')
nt.links.new(to.outputs['Color'], sep.inputs['Color'])
nt.links.new(sep.outputs['Green'], bs.inputs['Roughness'])
nt.links.new(sep.outputs['Blue'], bs.inputs['Metallic'])
mx = nt.nodes.new('ShaderNodeMix')
mx.data_type = 'RGBA'
mx.blend_type = 'MULTIPLY'
mx.inputs[0].default_value = 1.0
nt.links.new(ta.outputs['Color'], mx.inputs[6])
cmb = nt.nodes.new('ShaderNodeCombineColor')
for c in ('Red', 'Green', 'Blue'):
    nt.links.new(sep.outputs['Red'], cmb.inputs[c])
nt.links.new(cmb.outputs['Color'], mx.inputs[7])
nt.links.new(mx.outputs[2], bs.inputs['Base Color'])
nt.links.new(te.outputs['Color'], bs.inputs['Emission Color'])
bs.inputs['Emission Strength'].default_value = 3.0
for o in meshes:
    o.data.materials.clear()
    o.data.materials.append(m)

# the rig's joint tree (CharacterRig sockets)
PARENT = {"chest": "pelvis", "head": "chest", "hip_l": "pelvis", "hip_r": "pelvis", "knee_l": "hip_l", "knee_r": "hip_r", "foot_l": "knee_l", "foot_r": "knee_r",
          "shoulder_l": "chest", "shoulder_r": "chest", "elbow_l": "shoulder_l", "elbow_r": "shoulder_r", "hand_l": "elbow_l", "hand_r": "elbow_r"}
ORDER = ["pelvis", "chest", "head", "hip_l", "hip_r", "knee_l", "knee_r", "foot_l", "foot_r", "shoulder_l", "shoulder_r", "elbow_l", "elbow_r", "hand_l", "hand_r"]
bones = {b.name: b for b in arm.data.bones}
HEAD = {n: arm.matrix_world @ b.head_local for n, b in bones.items()}
REST = {n: arm.matrix_world @ b.matrix_local for n, b in bones.items()}
rigid = {}
for o in meshes:
    for tag in ("shield_", "bell_", "staff_"):
        if o.name.startswith(tag) and o.name[len(tag):].split(".")[0] in bones:
            rigid[o] = o.name[len(tag):].split(".")[0]
for o in rigid:
    o.parent = None


def pose(spec, root_t=(0, 0, 0)):
    """spec: {bone: (rx, ry, rz) degrees, Blender axes about the joint}. FK from the pelvis."""
    A = {}
    for n in ORDER:
        if n not in bones:
            continue
        r = Euler([math.radians(v) for v in spec.get(n, (0, 0, 0))], 'XYZ').to_matrix().to_4x4()
        p = HEAD[n]
        local = Matrix.Translation(p) @ r @ Matrix.Translation(-p)
        par = A.get(PARENT.get(n), Matrix.Translation(root_t) if n == "pelvis" else Matrix.Identity(4))
        A[n] = par @ local
    for n, pb in arm.pose.bones.items():
        pb.matrix = A.get(n, Matrix.Identity(4)) @ REST[n]
    bpy.context.view_layer.update()
    for o, sock in rigid.items():
        o.matrix_world = A[sock] @ Matrix.Translation(HEAD[sock])


pose({})
lo, hi = Vector((1e9,) * 3), Vector((-1e9,) * 3)
dg = bpy.context.evaluated_depsgraph_get()
for o in meshes:
    ev = o.evaluated_get(dg)
    for c in ev.bound_box:
        w = ev.matrix_world @ Vector(c)
        lo = Vector((min(lo[i], w[i]) for i in range(3)))
        hi = Vector((max(hi[i], w[i]) for i in range(3)))
ctr = (lo + hi) * 0.5
size = max(hi.z - lo.z, hi.x - lo.x)
print("BBOX", tuple(round(v, 3) for v in lo), tuple(round(v, 3) for v in hi))

bpy.ops.mesh.primitive_plane_add(size=400, location=(0, 0, lo.z - 0.002))
fl = bpy.context.active_object
fm = bpy.data.materials.new("F")
fm.use_nodes = True
fm.node_tree.nodes["Principled BSDF"].inputs['Base Color'].default_value = (0.06, 0.06, 0.065, 1)
fm.node_tree.nodes["Principled BSDF"].inputs['Roughness'].default_value = 0.9
fl.data.materials.append(fm)
tgt = bpy.data.objects.new("T", None)
sc.collection.objects.link(tgt)
cd = bpy.data.cameras.new("C")
cam = bpy.data.objects.new("C", cd)
sc.collection.objects.link(cam)
sc.camera = cam
tr = cam.constraints.new('TRACK_TO')
tr.target = tgt
tr.track_axis = 'TRACK_NEGATIVE_Z'
tr.up_axis = 'UP_Y'
world = bpy.data.worlds.new("W")
world.use_nodes = True
sc.world = world
bg = world.node_tree.nodes["Background"]
lights = []


def light(name, kind, loc, energy, col, sz=2.0):
    ld = bpy.data.lights.new(name, kind)
    ld.energy = energy
    ld.color = col
    if kind == 'AREA':
        ld.size = sz
    ob = bpy.data.objects.new(name, ld)
    ob.location = loc
    sc.collection.objects.link(ob)
    t = ob.constraints.new('TRACK_TO')
    t.target = tgt
    t.track_axis = 'TRACK_NEGATIVE_Z'
    t.up_axis = 'UP_Y'
    lights.append(ob)


def rig_for(az, mode, c0):
    for o in lights:
        bpy.data.objects.remove(o)
    lights.clear()
    R = 4.8
    a = math.radians(az)

    def at(off, h):
        b = a + math.radians(off)
        return Vector((c0.x + math.cos(b) * R, c0.y + math.sin(b) * R, c0.z + h))
    if mode == "neutral":
        bg.inputs[0].default_value = (0.5, 0.5, 0.5, 1)
        bg.inputs[1].default_value = 0.6
        light("K", 'AREA', at(-40, 2.0), 1100, (1, 0.98, 0.95), 3.0)
        light("F", 'AREA', at(50, 0.8), 380, (0.9, 0.95, 1), 3.0)
    else:
        bg.inputs[0].default_value = (0.012, 0.018, 0.04, 1)
        bg.inputs[1].default_value = 1.0
        light("Moon", 'AREA', at(-60, 2.6), 1500, (0.5, 0.65, 1.0), 3.0)
        light("Fire", 'AREA', at(70, 0.4), 500, (1.0, 0.62, 0.3), 2.2)
        light("Rim", 'AREA', at(180, 1.8), 800, (0.5, 0.6, 1.0), 3.0)


def shoot(name, az, el, dist, tz, lens, mode, c0=None):
    c0 = c0 or Vector((0, 0, tz))
    cd.lens = lens
    tgt.location = c0
    a = math.radians(az)
    cam.location = Vector((c0.x + math.cos(a) * dist, c0.y + math.sin(a) * dist, c0.z + dist * el))
    rig_for(az, mode, c0)
    sc.render.filepath = os.path.join(OUT, name + ".png")
    bpy.ops.render.render(write_still=True)
    print("RENDERED", sc.render.filepath)
    return sc.render.filepath


def sheet(paths, cols, out, tile):
    tw, th = tile
    rows = (len(paths) + cols - 1) // cols
    sh = np.zeros((th * rows, tw * cols, 4), dtype=np.float32)
    for i, p in enumerate(paths):
        im = bpy.data.images.load(p)
        im.scale(tw, th)
        a = np.empty(tw * th * 4, dtype=np.float32)
        im.pixels.foreach_get(a)
        r, c = divmod(i, cols)
        rr = rows - 1 - r                                    # image rows run bottom-up
        sh[rr * th:(rr + 1) * th, c * tw:(c + 1) * tw] = a.reshape(th, tw, 4)
    o = bpy.data.images.new("sheet", tw * cols, th * rows, alpha=False)
    o.pixels.foreach_set(sh.ravel())
    o.filepath_raw = out
    o.file_format = 'PNG'
    o.save()
    print("SHEET", out)


H = hi.z - lo.z
tz = lo.z + H * 0.5
D0 = max(H, 1.9) * 1.5
if ONLY in ("", "turn"):
    pose({})
    ps = []
    for mode in ("night", "neutral"):
        for name, az in (("front", 90), ("three", 50), ("side", 0), ("back", 270)):
            ps.append(shoot("turn_%s_%s" % (name, mode), az, 0.1, D0, tz, 85, mode))
    cd.lens = 70
    hz = float(arg("--head", "0")) or 1.67
    for mode in ("night",):
        ps.append(shoot("head_" + mode, 62, 0.05, 1.1, 0, 70, mode, Vector((0, 0, hz))))
    sheet(ps[:8], 4, os.path.join(OUT, "turn_sheet.png"), (360, 450))
if ONLY in ("", "pose"):
    P = {
        "windup": ({"shoulder_l": (165, 0, 8), "shoulder_r": (172, 0, -8), "elbow_l": (24, 0, 0), "elbow_r": (30, 0, 0), "chest": (-14, 0, 0), "head": (-10, 0, 0), "hand_l": (20, 0, 0), "hand_r": (20, 0, 0)}, (0, 0, 0)),
        "kneel": ({"hip_l": (4, 0, 0), "hip_r": (10, 0, 0), "knee_l": (-118, 0, 0), "knee_r": (-122, 0, 0), "foot_l": (35, 0, 0), "foot_r": (35, 0, 0), "chest": (22, 0, 0), "head": (-14, 0, 0),
                   "shoulder_l": (35, 0, 0), "shoulder_r": (35, 0, 0), "elbow_l": (30, 0, 0), "elbow_r": (30, 0, 0)}, (0, 0, -0.43)),
        "stride": ({"hip_l": (42, 0, 0), "knee_l": (-30, 0, 0), "hip_r": (-26, 0, 0), "knee_r": (-6, 0, 0), "foot_r": (14, 0, 0), "shoulder_l": (-34, 0, 0), "shoulder_r": (34, 0, 0), "elbow_r": (38, 0, 0),
                    "elbow_l": (12, 0, 0), "chest": (6, 0, 12), "pelvis": (0, 0, -8), "head": (0, 0, -8)}, (0, 0, 0)),
        "lunge": ({"hip_l": (62, 0, 0), "knee_l": (-72, 0, 0), "hip_r": (-34, 0, 0), "knee_r": (-12, 0, 0), "chest": (28, 0, 0), "head": (-18, 0, 0), "shoulder_l": (72, 0, 0), "elbow_l": (50, 0, 0),
                   "shoulder_r": (-50, 0, 0), "elbow_r": (30, 0, 0), "foot_l": (12, 0, 0)}, (0, 0, -0.2)),
    }
    pp = []
    for name, (spec, rt) in P.items():
        pose(spec, rt)
        dg = bpy.context.evaluated_depsgraph_get()
        lo2, hi2 = Vector((1e9,) * 3), Vector((-1e9,) * 3)
        for o in meshes:
            ev = o.evaluated_get(dg)
            for c in ev.bound_box:
                w = ev.matrix_world @ Vector(c)
                lo2 = Vector((min(lo2[i], w[i]) for i in range(3)))
                hi2 = Vector((max(hi2[i], w[i]) for i in range(3)))
        c2 = (lo2 + hi2) * 0.5
        d2 = max(hi2.z - lo2.z, hi2.x - lo2.x, 1.4) * 1.55
        for view, az in (("three", 50), ("side", 0), ("front", 90)):
            pp.append(shoot("pose_%s_%s" % (name, view), az, 0.1, d2, c2.z, 75, "night", Vector((0, 0, c2.z))))
    sheet(pp, 3, os.path.join(OUT, "pose_sheet.png"), (400, 500))
