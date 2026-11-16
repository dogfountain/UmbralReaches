"""Review renders of an exported boss GLB with its four baked maps: turnaround (front, 3/4, side, back), the face and the
hands, each neutral and under the night key. The skeleton is shown in its REST pose (no clip), the maps are the ones the
game uses (albedo, normal, ORM, emit).

  tools/blender/run.sh boss_review.py -- --boss thornwarden [--glb path] [--tex dir] --out DIR [--res 720] [--samples 24]
                                        [--views front,three,side,back,face,hands] [--modes neutral,night] [--pose clip:frame]
Front of the model is Blender +Y (Godot -Z). Needs no game, no Godot.
"""
import bpy
import math
import os
import sys
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(n, d):
    return args[args.index(n) + 1] if n in args else d


BOSS = arg("--boss", "thornwarden")
GLB = arg("--glb", os.path.join(ROOT, "art", "models", "boss_%s.glb" % BOSS))
TEX = arg("--tex", os.path.join(ROOT, "art", "textures"))
OUT = arg("--out", "/private/tmp/claude-501/boss_review/" + BOSS)
RES = int(arg("--res", "720"))
SAMPLES = int(arg("--samples", "24"))
VIEWS = arg("--views", "front,three,side,back,face,hands").split(",")
MODES = arg("--modes", "neutral,night").split(",")
POSE = arg("--pose", "")
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
sc.render.resolution_y = RES
sc.view_settings.view_transform = 'AgX'

bpy.ops.import_scene.gltf(filepath=GLB)
arm = next((o for o in bpy.context.scene.objects if o.type == 'ARMATURE'), None)
meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
if arm is not None:
    arm.data.pose_position = 'REST'
    if arm.animation_data and POSE:
        clip, frame = POSE.split(":")
        act = bpy.data.actions.get(clip)
        if act:
            arm.animation_data.action = act
            arm.data.pose_position = 'POSE'
            sc.frame_set(int(frame))


def img(key, cs):
    p = os.path.join(TEX, "boss_%s_%s.png" % (BOSS, key))
    im = bpy.data.images.load(p)
    im.colorspace_settings.name = cs
    return im


albedo, normal, orm, emit = img("albedo", 'sRGB'), img("normal", 'Non-Color'), img("orm", 'Non-Color'), img("emit", 'sRGB')
m = bpy.data.materials.new("Atlas")
m.use_nodes = True
nt = m.node_tree
bs = nt.nodes["Principled BSDF"]


def tex(im):
    t = nt.nodes.new('ShaderNodeTexImage')
    t.image = im
    return t


ta, tn, to, te = tex(albedo), tex(normal), tex(orm), tex(emit)
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
for ch in ('Red', 'Green', 'Blue'):
    nt.links.new(sep.outputs['Red'], cmb.inputs[ch])
nt.links.new(cmb.outputs['Color'], mx.inputs[7])
nt.links.new(mx.outputs[2], bs.inputs['Base Color'])
nt.links.new(te.outputs['Color'], bs.inputs['Emission Color'])
bs.inputs['Emission Strength'].default_value = 3.0
for o in meshes:
    o.data.materials.clear()
    o.data.materials.append(m)

import numpy as np
dg = bpy.context.evaluated_depsgraph_get()
pts = []
for o in meshes:
    oe = o.evaluated_get(dg)
    me = oe.to_mesh()
    a = np.empty(len(me.vertices) * 3, dtype=np.float32)
    me.vertices.foreach_get("co", a)
    a = a.reshape(-1, 3)
    mw = np.array(o.matrix_world)
    pts.append(a @ mw[:3, :3].T + mw[:3, 3])
    oe.to_mesh_clear()
pts = np.concatenate(pts)
lo = Vector(np.percentile(pts, 1.0, axis=0).tolist())
hi = Vector(np.percentile(pts, 99.9, axis=0).tolist())
ctr = (lo + hi) * 0.5
size = max(hi.z - lo.z, hi.x - lo.x, hi.y - lo.y)
print("BBOX", tuple(round(v, 3) for v in lo), tuple(round(v, 3) for v in hi), "TRIS", sum(len(p.vertices) - 2 for o in meshes for p in o.data.polygons))


def bone_world(*names):
    if arm is None:
        return None
    for n in names:
        b = arm.pose.bones.get(n)
        if b:
            return arm.matrix_world @ b.head
    return None


bpy.ops.mesh.primitive_plane_add(size=40, location=(0, 0, lo.z - 0.002))
fl = bpy.context.active_object
fm = bpy.data.materials.new("F")
fm.use_nodes = True
fm.node_tree.nodes["Principled BSDF"].inputs['Base Color'].default_value = (0.05, 0.05, 0.055, 1)
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


def rig_for(az, mode, around, R):
    for o in lights:
        bpy.data.objects.remove(o)
    lights.clear()
    a = math.radians(az)

    def at(off, h):
        b = a + math.radians(off)
        return Vector((around.x + math.cos(b) * R, around.y + math.sin(b) * R, around.z + h * R * 0.5))
    k = R * R / 25.0
    if mode == "neutral":
        bg.inputs[0].default_value = (0.5, 0.5, 0.5, 1)
        bg.inputs[1].default_value = 0.6
        light("K", 'AREA', at(-40, 0.9), 220 * k, (1, 0.98, 0.95), R * 0.5)
        light("F", 'AREA', at(50, 0.4), 80 * k, (0.9, 0.95, 1), R * 0.5)
    else:
        bg.inputs[0].default_value = (0.012, 0.018, 0.04, 1)
        bg.inputs[1].default_value = 1.0
        light("Moon", 'AREA', at(-60, 1.1), 330 * k, (0.5, 0.65, 1.0), R * 0.5)
        light("Fire", 'AREA', at(70, 0.15), 110 * k, (1.0, 0.62, 0.3), R * 0.35)
        light("Rim", 'AREA', at(180, 0.7), 170 * k, (0.5, 0.6, 1.0), R * 0.5)


head = bone_world("head", "Head")
handl = bone_world("hand_l", "Hand_l")
handr = bone_world("hand_r", "Hand_r")
if head is None:
    head = Vector((ctr.x, hi.y - 0.2, hi.z - 0.2))
H = hi.z - lo.z
# view: (az deg where 90 = front (+Y), elevation fraction, distance in model heights, target, lens)
full = Vector((ctr.x, ctr.y, lo.z + H * 0.5))
V = {
    "front": (90, 0.18, 1.7, full, 50), "three": (52, 0.2, 1.7, full, 50), "side": (0, 0.18, 1.7, full, 50), "back": (-90, 0.18, 1.7, full, 50),
    "face": (68, 0.06, 0.55, head, 85),
    "hands": (80, 0.2, 0.7, ((handl + handr) * 0.5) if handl is not None and handr is not None else full, 70),
}
for mode in MODES:
    for name in VIEWS:
        az, el, dist, target, lens = V[name]
        cd.lens = lens
        tgt.location = target
        D = H * dist if name not in ("face", "hands") else (H * dist if name == "face" else max(H * dist, (handl - handr).length * 1.3 if handl is not None else H * dist))
        a = math.radians(az)
        cam.location = Vector((tgt.location.x + math.cos(a) * D, tgt.location.y + math.sin(a) * D, tgt.location.z + D * el))
        rig_for(az, mode, target, D * 1.1)
        sc.render.filepath = os.path.join(OUT, "%s_%s.png" % (name, mode))
        bpy.ops.render.render(write_still=True)
        print("RENDERED", sc.render.filepath)
