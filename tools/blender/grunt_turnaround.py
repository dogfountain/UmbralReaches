"""Review renders of an exported grunt GLB (+ its baked atlas): front, 3/4, side and a head close-up,
under a neutral light and under a dark blue night key with a warm fill. 960 px stills and one
contact sheet per kind.

  tools/blender/run.sh grunt_turnaround.py -- --kind wretch --dir /private/tmp/claude-501/grunts/glb \
      --out /private/tmp/claude-501/grunts/wretch [--head 1.62] [--samples 40]
The GLB is grunt_<kind>.glb in --dir, the maps grunt_<kind>_{albedo,normal,orm,emit}.png beside it.
Front of the model is Blender +Y (Godot -Z).
"""
import bpy
import math
import os
import sys
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(n, d):
    return args[args.index(n) + 1] if n in args else d


KIND = arg("--kind", "wretch")
DIR = arg("--dir", "/private/tmp/claude-501/grunts/glb")
OUT = arg("--out", "/private/tmp/claude-501/grunts/" + KIND)
SAMPLES = int(arg("--samples", "40"))
RES = int(arg("--res", "960"))
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
sc.cycles.use_denoising = False
sc.render.resolution_x = RES
sc.render.resolution_y = RES
sc.view_settings.view_transform = 'AgX'

BODYONLY = "--bodyonly" in args
bpy.ops.import_scene.gltf(filepath=os.path.join(DIR, "grunt_%s%s.glb" % (KIND, "_bodyonly" if BODYONLY else "")))
meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH' and not o.name.startswith(('Icosphere', 'Sphere'))]


def img(key, cs):
    p = os.path.join(DIR, "grunt_%s_%s.png" % (KIND, key))
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
nt.links.new(ta.outputs['Color'], bs.inputs['Base Color'])
nm = nt.nodes.new('ShaderNodeNormalMap')
nm.inputs['Strength'].default_value = 1.2
nt.links.new(tn.outputs['Color'], nm.inputs['Color'])
nt.links.new(nm.outputs['Normal'], bs.inputs['Normal'])
sep = nt.nodes.new('ShaderNodeSeparateColor')
nt.links.new(to.outputs['Color'], sep.inputs['Color'])
nt.links.new(sep.outputs['Green'], bs.inputs['Roughness'])
nt.links.new(sep.outputs['Blue'], bs.inputs['Metallic'])
# the AO channel darkens the albedo, as the game shader does
mx = nt.nodes.new('ShaderNodeMix')
mx.data_type = 'RGBA'
mx.blend_type = 'MULTIPLY'
mx.inputs[0].default_value = 1.0
nt.links.new(ta.outputs['Color'], mx.inputs[6])
cmb = nt.nodes.new('ShaderNodeCombineColor')
nt.links.new(sep.outputs['Red'], cmb.inputs['Red'])
nt.links.new(sep.outputs['Red'], cmb.inputs['Green'])
nt.links.new(sep.outputs['Red'], cmb.inputs['Blue'])
nt.links.new(cmb.outputs['Color'], mx.inputs[7])
nt.links.new(mx.outputs[2], bs.inputs['Base Color'])
nt.links.new(te.outputs['Color'], bs.inputs['Emission Color'])
bs.inputs['Emission Strength'].default_value = 3.0
for o in meshes:
    o.data.materials.clear()
    o.data.materials.append(m)

lo, hi = Vector((1e9,) * 3), Vector((-1e9,) * 3)
for o in meshes:
    for c in o.bound_box:
        w = o.matrix_world @ Vector(c)
        lo = Vector((min(lo[i], w[i]) for i in range(3)))
        hi = Vector((max(hi[i], w[i]) for i in range(3)))
ctr = (lo + hi) * 0.5
size = max(hi.z - lo.z, hi.x - lo.x, hi.y - lo.y)
print("BBOX", tuple(round(v, 3) for v in lo), tuple(round(v, 3) for v in hi))

# floor
bpy.ops.mesh.primitive_plane_add(size=400, location=(0, 0, lo.z - 0.002))
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
    return ob


def clear_lights():
    for o in lights:
        bpy.data.objects.remove(o)
    lights.clear()


def rig_for(az, mode):
    """Lights follow the camera azimuth so every view is lit alike."""
    clear_lights()
    R = size * 2.2
    a = math.radians(az)

    def at(off, h):
        b = a + math.radians(off)
        return Vector((ctr.x + math.cos(b) * R, ctr.y + math.sin(b) * R, ctr.z + h * size))
    if mode == "neutral":
        bg.inputs[0].default_value = (0.5, 0.5, 0.5, 1)
        bg.inputs[1].default_value = 0.6
        light("K", 'AREA', at(-40, 0.9), 220 * size * size, (1, 0.98, 0.95), size)
        light("F", 'AREA', at(50, 0.4), 80 * size * size, (0.9, 0.95, 1), size)
    else:
        bg.inputs[0].default_value = (0.012, 0.018, 0.04, 1)
        bg.inputs[1].default_value = 1.0
        light("Moon", 'AREA', at(-60, 1.1), 330 * size * size, (0.5, 0.65, 1.0), size)       # dark blue key, high and to one side
        light("Fire", 'AREA', at(70, 0.15), 110 * size * size, (1.0, 0.62, 0.3), size * 0.7)   # warm low fill
        light("Rim", 'AREA', at(180, 0.7), 170 * size * size, (0.5, 0.6, 1.0), size)


# (name, azimuth deg from +X axis where 90 = front (+Y), elevation fraction, distance factor, target z fraction, lens)
head_z = float(arg("--head", "0")) or (hi.z - (hi.z - lo.z) * 0.12)
quad = (hi.z - lo.z) < 1.4
views = [("front", 90, 0.3, 1.45, 0.5, 50), ("three", 50, 0.34, 1.45, 0.5, 50), ("side", 0, 0.3, 1.45, 0.5, 50), ("head", 62, 0.1, 0.8, None, 70)]
if BODYONLY:
    quad_ = (hi.z - lo.z) < 1.4
    views = [("anatomy", 62, 0.2, 1.1 if quad_ else 0.62, 0.5 if quad_ else 0.74, 50)]
for mode in ("neutral", "night"):
    for name, az, el, dist, tz, lens in views:
        cd.lens = lens
        if tz is None:
            hz = float(arg("--head", "0")) or (hi.z - 0.14 if not quad else hi.z - 0.1)
            if quad:
                hz = float(arg("--head", "0")) or (lo.z + (hi.z - lo.z) * 0.55)
            tgt.location = Vector((ctr.x, (hi.y - 0.16) if quad else ctr.y, hz))
            D = (0.95 if quad else size * dist * 0.55)
            sc.cycles.samples = SAMPLES
        else:
            tgt.location = Vector((ctr.x, ctr.y, lo.z + (hi.z - lo.z) * tz)) if BODYONLY else ctr
            D = size * dist * 1.12
        a = math.radians(az)
        cam.location = Vector((tgt.location.x + math.cos(a) * D, tgt.location.y + math.sin(a) * D, tgt.location.z + D * el))
        rig_for(az, mode)
        sc.render.filepath = os.path.join(OUT, "%s_%s.png" % (name, mode))
        bpy.ops.render.render(write_still=True)
        print("RENDERED", sc.render.filepath)

if BODYONLY:
    sys.exit(0)
# contact sheet: neutral on top, night below (images scaled with Blender's own scaler; no PIL needed)
import numpy as np
T = 480
sheet = np.zeros((T * 2, T * len(views), 4), dtype=np.float32)
for r, mode in enumerate(("night", "neutral")):          # image rows run bottom-up: night ends up below
    for c, v in enumerate(views):
        im = bpy.data.images.load(os.path.join(OUT, "%s_%s.png" % (v[0], mode)))
        im.scale(T, T)
        a = np.empty(T * T * 4, dtype=np.float32)
        im.pixels.foreach_get(a)
        sheet[r * T:(r + 1) * T, c * T:(c + 1) * T] = a.reshape(T, T, 4)
out = bpy.data.images.new("sheet", T * len(views), T * 2, alpha=False)
out.colorspace_settings.name = 'sRGB'
out.pixels.foreach_set(sheet.ravel())
out.filepath_raw = os.path.join(OUT, "sheet.png")
out.file_format = 'PNG'
out.save()
print("SHEET", out.filepath_raw)
