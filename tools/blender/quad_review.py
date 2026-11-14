"""Review renders of an exported quadruped GLB (r38d): turnarounds (front, side, three-quarter, back) in a
neutral and a moonlit rig, and POSED renders (mid-stride, crouch) with the real skinning: every bone is
posed by forward kinematics about its socket joint, exactly as GruntSkin poses the game's bones.

  tools/blender/run.sh quad_review.py -- --glb /path/grunt_leaper.glb --prefix grunt_leaper --dir /path \
      --out /path/review/leaper [--rig upright|spider] [--samples 40] [--res 900] [--head-z 0.7]
Writes <out>/{front,side,three,back}_{neutral,night}.png, pose_{stride,crouch}_{side,three}.png and
turn_sheet.png / pose_sheet.png.
"""
import bpy
import math
import os
import sys
import numpy as np
from mathutils import Vector, Matrix

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import quad_sculpt_lib as L

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(n, d):
    return args[args.index(n) + 1] if n in args else d


GLB = arg("--glb", "")
PREFIX = arg("--prefix", "grunt_leaper")
DIR = arg("--dir", os.path.dirname(GLB))
OUT = arg("--out", "/private/tmp/claude-501/review")
RIG = arg("--rig", "upright")
SAMPLES = int(arg("--samples", "40"))
RES = int(arg("--res", "900"))
SCALE = float(arg("--scale", "1.0"))
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

bpy.ops.import_scene.gltf(filepath=GLB)
arm = [o for o in bpy.context.scene.objects if o.type == 'ARMATURE'][0]
meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH' and not o.name.startswith(('Icosphere', 'Sphere'))]
for o in list(bpy.context.scene.objects):
    if o.type == 'MESH' and o not in meshes:
        bpy.data.objects.remove(o)


def img(key, cs):
    im = bpy.data.images.load(os.path.join(DIR, "%s_%s.png" % (PREFIX, key)))
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
for k in ('Red', 'Green', 'Blue'):
    nt.links.new(sep.outputs['Red'], cmb.inputs[k])
nt.links.new(cmb.outputs['Color'], mx.inputs[7])
nt.links.new(mx.outputs[2], bs.inputs['Base Color'])
nt.links.new(te.outputs['Color'], bs.inputs['Emission Color'])
bs.inputs['Emission Strength'].default_value = 3.0
for o in meshes:
    o.data.materials.clear()
    o.data.materials.append(m)

# floor, camera, lights
lo, hi = Vector((1e9,) * 3), Vector((-1e9,) * 3)
for o in meshes:
    for c in o.bound_box:
        w = o.matrix_world @ Vector(c)
        lo = Vector((min(lo[i], w[i]) for i in range(3)))
        hi = Vector((max(hi[i], w[i]) for i in range(3)))
ctr = (lo + hi) * 0.5
size = max(hi.z - lo.z, hi.x - lo.x, hi.y - lo.y)
print("BBOX", tuple(round(v, 3) for v in lo), tuple(round(v, 3) for v in hi), "armature scale", tuple(arm.scale), "rot", tuple(arm.rotation_euler))
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


def rig_for(az, mode):
    for o in lights:
        bpy.data.objects.remove(o)
    lights.clear()
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
        light("Moon", 'AREA', at(-60, 1.1), 200 * size * size, (0.5, 0.65, 1.0), size)
        light("Fire", 'AREA', at(70, 0.15), 70 * size * size, (1.0, 0.62, 0.3), size * 0.7)
        light("Rim", 'AREA', at(180, 0.7), 120 * size * size, (0.5, 0.6, 1.0), size)


def shoot(path, az, el, dist, mode, lens=50, target=None):
    cd.lens = lens
    tgt.location = target if target is not None else ctr
    a = math.radians(az)
    D = size * dist
    cam.location = Vector((tgt.location.x + math.cos(a) * D, tgt.location.y + math.sin(a) * D, tgt.location.z + D * el))
    rig_for(az, mode)
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("RENDERED", path)


# --- posing (forward kinematics about the bone heads, as GruntSkin does) ---------------------------------
C = np.array([[1, 0, 0], [0, 0, -1], [0, 1, 0]], dtype=np.float64)     # rig -> blender basis


def R_rig(rx=0.0, ry=0.0, rz=0.0):
    cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
    Rx = np.array([[1, 0, 0], [0, cx, -sx], [0, sx, cx]])
    Ry = np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]])
    Rz = np.array([[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]])
    return Ry @ Rx @ Rz


def about(j, rot_rig, shift_rig=(0, 0, 0)):
    """4x4 (blender): rotate about joint j (blender coords) by a rig-space rotation, then shift."""
    Rb = C @ R_rig(*rot_rig) @ C.T
    M = np.eye(4)
    M[:3, :3] = Rb
    jj = np.array(j)
    M[:3, 3] = jj - Rb @ jj + C @ np.array(shift_rig)
    return M


def pose(spec):
    """spec: {bone: (rx, ry, rz)} local rotation in rig space (chains accumulate: hip -> knee -> foot,
    body -> front -> head, body -> tail); spec["body_shift"] = (x, y, z) rig metres."""
    bones = {b.name: np.array(b.head_local, dtype=np.float64) for b in arm.data.bones}
    chains = [("body",), ("body", "front"), ("body", "front", "head"), ("body", "tail")]
    for t in ("fl", "fr", "bl", "br"):
        chains.append(("body", "leg_%s_hip" % t, "leg_%s_knee" % t, "leg_%s_foot" % t))
    P = {}
    bodyM = about(bones["body"], spec.get("body", (0, 0, 0)), spec.get("body_shift", (0, 0, 0)))
    P["body"] = bodyM
    for ch in chains:
        M = bodyM
        for nm in ch[1:]:
            M = M @ about(bones[nm], spec.get(nm, (0, 0, 0)))
            P[nm] = M
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode='POSE')
    for pb in arm.pose.bones:
        rest = np.array(pb.bone.matrix_local)
        pb.matrix = Matrix((arm.matrix_world.to_3x3().to_4x4() if False else Matrix.Identity(4)) @ Matrix((P.get(pb.name, np.eye(4)) @ rest).tolist()))
    bpy.ops.object.mode_set(mode='OBJECT')
    bpy.context.view_layer.update()


def clear_pose():
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode='POSE')
    for pb in arm.pose.bones:
        pb.matrix_basis = Matrix.Identity(4)
    bpy.ops.object.mode_set(mode='OBJECT')
    bpy.context.view_layer.update()


def stride_pose(upright):
    """What QuadRig does mid-trot (diagonal pairs: fl and br ahead and lifted, fr and bl planted behind)
    and in a coil (the crouch before a pounce): the same angles _animate_upright / _animate_spider use."""
    st, crouch = {}, {}
    for tag, sx, front in (("fl", -1, True), ("fr", 1, True), ("bl", -1, False), ("br", 1, False)):
        ahead = tag in ("fl", "br")
        swing, lift = (-1.0, 1.0) if ahead else (1.0, 0.0)
        h, k, f = "leg_%s_hip" % tag, "leg_%s_knee" % tag, "leg_%s_foot" % tag
        if upright:
            fb = 1.0 if front else -1.0
            hx = -swing * 0.5
            kx = -fb * (lift * 0.9)
            st[h], st[k], st[f] = (hx, 0, 0), (kx, 0, 0), (-(hx + kx), 0, 0)
            bend = 0.6
            hx, kx = fb * bend * 0.55, -fb * bend
            crouch[h], crouch[k], crouch[f] = (hx, 0, 0), (kx, 0, 0), (-(hx + kx), 0, 0)
        else:
            hy = -sx * swing * 0.42
            hz = sx * lift * 0.38
            kz = -sx * lift * 0.25
            st[h], st[k], st[f] = (0, hy, hz), (0, 0, kz), (0, 0, -(hz + kz))
            hz = sx * (-0.25)
            kz = -sx * 0.35
            crouch[h], crouch[k], crouch[f] = (0, 0, hz), (0, 0, kz), (0, 0, -(hz + kz))
    st.update({"body": (0.03, 0, 0.04), "body_shift": (0, 0.02, 0), "front": (0, 0.05, 0), "head": (-0.1, 0.0, 0), "tail": (0, 0.35, 0)})
    crouch.update({"body": (0.18, 0, 0), "body_shift": (0, -0.16, 0), "front": (-0.2, 0, 0), "head": (0.35, 0, 0), "tail": (-0.15 + 0.2, 0, 0)})
    return st, crouch


STRIDE, CROUCH = stride_pose(RIG == "upright")

paths = {}
# turnarounds
for mode in ("night", "neutral"):
    for name, az, el, dist in (("front", 90, 0.28, 1.5), ("side", 0, 0.22, 1.35), ("three", 45, 0.32, 1.45), ("back", 270, 0.28, 1.5)):
        p = os.path.join(OUT, "%s_%s.png" % (name, mode))
        shoot(p, az, el, dist, mode)
        paths.setdefault(mode, []).append(p)
for mode in ("night", "neutral"):
    L.montage(paths[mode], os.path.join(OUT, "turn_sheet_%s.png" % mode), cols=2, scale=0.6)
# a head close-up
head = Vector((ctr.x, hi.y - size * 0.12, hi.z - (hi.z - lo.z) * 0.28))
HT = arg("--head-target", "")
if HT:
    head = Vector([float(v) for v in HT.split(",")])
shoot(os.path.join(OUT, "head_night.png"), 60, 0.12, float(arg("--head-dist", "0.55")), "night", 70, head)
# poses
pp = []
for pname, spec in (("stride", STRIDE), ("crouch", CROUCH)):
    pose(spec)
    for vn, az, el, dist in (("side", 0, 0.2, 1.4), ("three", 40, 0.32, 1.45)):
        p = os.path.join(OUT, "pose_%s_%s.png" % (pname, vn))
        shoot(p, az, el, dist, "night")
        pp.append(p)
    clear_pose()
L.montage(pp, os.path.join(OUT, "pose_sheet.png"), cols=2, scale=0.6)
