"""THE LAST MILESTONE: where the Pilgrims' Road ends at the west edge of the Realm, the Order set its last mile-stone and a
toll-house beside it. The stone: a tall octagonal shaft on a stepped base, girdled by three carved bands, the Order's
seven-pointed star under its cap, a groove worn round it where pilgrims touched it going home. The toll-house: a small
rubble-stone house, roofless, its gable standing, the door's lintel cracked, a window, the fallen roof timbers inside,
a stone bench by the door. Modelled by script (no scans, no downloads).

  tools/blender/run.sh vista_milestone.py -- [--preview DIR]

Exports art/models/vista_milestone.glb: Stone__hewn (the milestone), House__hewn (the toll-house's stones), Timber__timber
(the fallen roof), Mile-colonly (the stone, the house's walls as boxes). Origin: the milestone's foot; the house stands
6 m to its north (Blender +Y = Godot -Z), its door to the road (Godot +Z).
"""
import bpy
import bmesh
import math
import os
import sys
import random
from mathutils import Vector, Matrix, noise

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art", "models")
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
PREVIEW = args[args.index("--preview") + 1] if "--preview" in args else ""
rnd = random.Random(5)


def sstep(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3.0 - 2.0 * t)


def new_bm():
    bm = bmesh.new()
    return bm, bm.loops.layers.color.new("Col"), bm.loops.layers.uv.new("UVMap")


def tone(w, seed, base=0.74, n=None):
    lic = 0.22 * max(0.0, noise.noise(w * 1.6 + Vector((seed, 1, 2))))
    moss = sstep(0.8, -0.2, w.z) * 0.45 + (max(0.0, n.z) * 0.3 if n is not None else 0.0)
    t = base * (0.88 + 0.2 * noise.noise(w * 0.7 + Vector((0, 0, seed))))
    return (t * (1 - moss * 0.45) + lic, t * (1 - moss * 0.1) + lic * 0.9, t * (1 - moss * 0.5) + lic * 0.7, 1.0)


def block(bm, col, uv, c, size, yaw=0.0, seed=0, base=0.74, warp=0.05, tilt=(0.0, 0.0)):
    tmp = bmesh.new()
    bmesh.ops.create_cube(tmp, size=1.0)
    for v in tmp.verts:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
    bmesh.ops.bevel(tmp, geom=list(tmp.edges), offset=min(size) * 0.08, segments=1, affect='EDGES')
    for v in tmp.verts:
        v.co += Vector((noise.noise(v.co * 2.0 + Vector((seed, 0, 0))), noise.noise(v.co * 2.0 + Vector((0, seed, 0))),
                        noise.noise(v.co * 2.0 + Vector((0, 0, seed))))) * min(size) * warp
    m = Matrix.Translation(Vector(c)) @ Matrix.Rotation(yaw, 4, 'Z') @ Matrix.Rotation(tilt[0], 4, 'X') @ Matrix.Rotation(tilt[1], 4, 'Y')
    mp = {v: bm.verts.new(m @ v.co) for v in tmp.verts}
    tmp.normal_update()
    rot = Matrix.Rotation(yaw, 3, 'Z')
    for f in tmp.faces:
        nf = bm.faces.new([mp[v] for v in f.verts])
        n = rot @ f.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        for l, ol in zip(nf.loops, f.loops):
            w = m @ ol.vert.co
            l[uv].uv = (((w.y, w.z) if ax == 0 else (w.x, w.z) if ax == 1 else (w.x, w.y))[0] / 3.0,
                        ((w.y, w.z) if ax == 0 else (w.x, w.z) if ax == 1 else (w.x, w.y))[1] / 3.0)
            l[col] = tone(w, seed, base, n)
    tmp.free()


def lathe(bm, col, uv, prof, seg, seed, base=0.76, star_at=None):
    """An octagonal (seg) shaft from a profile [(z, r)], chamfered, carved bands as profile steps."""
    rings = []
    for (z, r) in prof:
        ring = []
        for k in range(seg):
            a = 2 * math.pi * (k + 0.5) / seg
            rr = r + 0.012 * noise.noise(Vector((a * 3.0, z * 2.0, seed)))
            ring.append(bm.verts.new((math.cos(a) * rr, math.sin(a) * rr, z)))
        rings.append(ring)
    for j in range(len(rings) - 1):
        for k in range(seg):
            f = bm.faces.new((rings[j][k], rings[j][(k + 1) % seg], rings[j + 1][(k + 1) % seg], rings[j + 1][k]))
            for l in f.loops:
                w = l.vert.co
                l[col] = tone(w, seed, base)
                l[uv].uv = (math.atan2(w.y, w.x) * 0.3, w.z / 3.0)
    top = bm.verts.new((0, 0, prof[-1][0] + 0.25))
    for k in range(seg):
        f = bm.faces.new((rings[-1][k], rings[-1][(k + 1) % seg], top))
        for l in f.loops:
            l[col] = tone(l.vert.co, seed, base * 0.9)
            l[uv].uv = (0, 0)


def star(bm, col, uv, c, nrm, size):
    lat = Vector((0, 0, 1)).cross(nrm).normalized()
    up = Vector((0, 0, 1))
    ctr = bm.verts.new(Vector(c) + nrm * 0.03)
    ring = []
    for k in range(14):
        t = 2 * math.pi * k / 14 + math.pi * 0.5
        rr = size if k % 2 == 0 else size * 0.4
        ring.append(bm.verts.new(Vector(c) + lat * math.cos(t) * rr + up * math.sin(t) * rr))
    for k in range(14):
        f = bm.faces.new((ctr, ring[k], ring[(k + 1) % 14]))
        for l in f.loops:
            l[col] = (0.86, 0.84, 0.78, 1.0)
            l[uv].uv = (0, 0)


def milestone():
    bm, col, uv = new_bm()
    # stepped base: three courses of blocks
    for i, (s, h) in enumerate(((2.6, 0.35), (2.0, 0.3), (1.5, 0.3))):
        z = sum(x[1] for x in ((2.6, 0.35), (2.0, 0.3), (1.5, 0.3))[:i])
        for k in range(4):
            a = math.pi * 0.5 * k
            block(bm, col, uv, (math.cos(a) * s * 0.25, math.sin(a) * s * 0.25, z + h * 0.5 - 0.2), (s * 0.55, s * 0.55, h), a, seed=10 + i * 4 + k, base=0.7)
    z0 = 0.75
    prof = [(z0, 0.5), (z0 + 0.6, 0.48), (z0 + 0.62, 0.53), (z0 + 0.8, 0.53), (z0 + 0.82, 0.47),       # first band
            (z0 + 1.6, 0.45), (z0 + 1.66, 0.49), (z0 + 1.7, 0.49), (z0 + 1.76, 0.43),                     # the worn groove
            (z0 + 2.6, 0.41), (z0 + 2.62, 0.46), (z0 + 2.8, 0.46), (z0 + 2.82, 0.4),                      # second band
            (z0 + 3.5, 0.37), (z0 + 3.52, 0.44), (z0 + 3.7, 0.44), (z0 + 3.72, 0.38),                     # third band
            (z0 + 4.1, 0.36), (z0 + 4.15, 0.48), (z0 + 4.35, 0.48)]                                      # the cap's collar
    lathe(bm, col, uv, prof, 8, 3)
    star(bm, col, uv, (0.0, -0.37, z0 + 3.9), Vector((0, -1, 0)), 0.16)
    return bm


def house():
    bm, col, uv = new_bm()
    cx, cy = 0.0, 7.5
    w, d = 5.2, 4.2
    th = 0.55
    # four walls of coursed rubble; the front (south, -Y side here) with a door, the east with a window; ragged tops
    def wall(x0, y0, x1, y1, h_fn, holes):
        ln = math.hypot(x1 - x0, y1 - y0)
        yaw = math.atan2(y1 - y0, x1 - x0)
        z = 0.0
        ci = 0
        while z < 3.8:
            ch = rnd.uniform(0.18, 0.3) if rnd.random() < 0.5 else rnd.uniform(0.32, 0.5)
            s = 0.0
            while s < ln - 0.05:
                corner = s < 0.1 or s > ln - 0.9
                bl = min(rnd.uniform(0.75, 0.95) if corner else rnd.uniform(0.3, 1.1), ln - s)
                t = (s + bl * 0.5) / ln
                top = h_fn(t)
                if z + ch * 0.5 < top and not any(h[0] < t < h[1] and h[2] < z + ch * 0.5 < h[3] for h in holes):
                    px = x0 + (x1 - x0) * t
                    py = y0 + (y1 - y0) * t
                    out = rnd.uniform(-0.04, 0.06)
                    nx, ny = -math.sin(yaw), math.cos(yaw)
                    block(bm, col, uv, (px + nx * out, py + ny * out, z + ch * 0.5), (bl - 0.04, th + (0.08 if corner else 0.0), ch - 0.03), yaw + rnd.uniform(-0.04, 0.04),
                          seed=ci * 31 + int(s * 10), base=rnd.uniform(0.62, 0.8) * (1.05 if corner else 1.0), warp=0.09, tilt=(rnd.uniform(-0.04, 0.04), rnd.uniform(-0.04, 0.04)))
                s += bl
            z += ch
            ci += 1
    gable = lambda t: 2.6 + 1.6 * (1.0 - abs(t - 0.5) * 2.0)
    wall(cx - w / 2, cy - d / 2, cx + w / 2, cy - d / 2, lambda t: 2.4 - 0.9 * sstep(0.6, 1.0, t) + 0.3 * math.sin(t * 9), [(0.38, 0.62, -1.0, 2.0)])
    wall(cx + w / 2, cy - d / 2, cx + w / 2, cy + d / 2, lambda t: 2.0 - 0.8 * t, [(0.35, 0.6, 1.0, 1.7)])
    wall(cx + w / 2, cy + d / 2, cx - w / 2, cy + d / 2, gable, [])
    wall(cx - w / 2, cy + d / 2, cx - w / 2, cy - d / 2, lambda t: 1.3 + 0.9 * t, [])
    # the door's lintel, cracked in two, one half dropped
    block(bm, col, uv, (cx - 0.25, cy - d / 2, 2.15), (0.75, th + 0.1, 0.32), 0.0, seed=901, base=0.76)
    block(bm, col, uv, (cx + 0.42, cy - d / 2 - 0.05, 1.85), (0.7, th + 0.1, 0.3), 0.0, seed=902, base=0.76, tilt=(0.0, -0.35))
    # a bench by the door
    block(bm, col, uv, (cx - 1.8, cy - d / 2 - 0.55, 0.42), (1.4, 0.45, 0.14), 0.0, seed=903, base=0.72)
    for sx in (-2.3, -1.3):
        block(bm, col, uv, (cx + sx, cy - d / 2 - 0.55, 0.18), (0.3, 0.4, 0.4), 0.0, seed=904 + int(sx * 10), base=0.68)
    return bm


def timbers():
    bm, col, uv = new_bm()
    cx, cy = 0.0, 7.5
    for i, (a, b) in enumerate((((-2.0, 6.0, 0.3), (1.8, 9.2, 2.2)), ((-1.0, 5.8, 0.25), (2.1, 7.0, 0.6)), ((-2.2, 9.0, 1.4), (1.2, 8.6, 0.2)))):
        A, B = Vector(a), Vector(b)
        d = (B - A).normalized()
        u = d.cross(Vector((0, 0, 1))).normalized()
        w = d.cross(u)
        rings = []
        for t in (0.0, 1.0):
            p = A.lerp(B, t)
            rings.append([bm.verts.new(p + (u * math.cos(2 * math.pi * k / 6) + w * math.sin(2 * math.pi * k / 6)) * 0.12) for k in range(6)])
        for k in range(6):
            f = bm.faces.new((rings[0][k], rings[0][(k + 1) % 6], rings[1][(k + 1) % 6], rings[1][k]))
            for l in f.loops:
                l[col] = (0.32, 0.26, 0.2, 1.0)
                l[uv].uv = (k / 6.0, (l.vert.co - A).length / 2.0)
    return bm


def collision():
    bm = bmesh.new()
    def box(c, s):
        tmp = bmesh.new()
        bmesh.ops.create_cube(tmp, size=1.0)
        mp = {v: bm.verts.new(Vector(c) + Vector((v.co.x * s[0], v.co.y * s[1], v.co.z * s[2]))) for v in tmp.verts}
        for f in tmp.faces:
            bm.faces.new([mp[v] for v in f.verts])
        tmp.free()
    box((0, 0, 0.5), (2.6, 2.6, 1.0))
    box((0, 0, 2.6), (1.0, 1.0, 4.0))
    cx, cy, w, d = 0.0, 7.5, 5.2, 4.2
    for (c, s) in (((cx - 1.9, cy - d / 2, 1.2), (1.5, 0.55, 2.4)), ((cx + 1.9, cy - d / 2, 1.2), (1.5, 0.55, 2.4)),
                   ((cx + w / 2, cy, 1.0), (0.55, d, 2.0)), ((cx, cy + d / 2, 1.6), (w, 0.55, 3.2)), ((cx - w / 2, cy, 1.0), (0.55, d, 2.0))):
        box(c, s)
    return bm


def mk(bm, name, smooth=True):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = smooth
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def tris(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


def export(objs, path):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    kw = dict(filepath=path, export_format='GLB', use_selection=True, export_apply=True, export_yup=True,
              export_materials='NONE', export_normals=True, export_texcoords=True, export_tangents=True)
    try:
        bpy.ops.export_scene.gltf(export_vertex_color='ACTIVE', **kw)
    except TypeError:
        bpy.ops.export_scene.gltf(**kw)
    print("EXPORTED", path, "%d tris" % sum(tris(o) for o in objs if "colonly" not in o.name))


def render(objs):
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.device = 'CPU'
    sc.cycles.samples = 32
    sc.cycles.use_denoising = True
    sc.render.resolution_x, sc.render.resolution_y = 1300, 900
    sc.world = bpy.data.worlds.new("w")
    sc.world.use_nodes = True
    sc.world.node_tree.nodes["Background"].inputs[0].default_value = (0.05, 0.06, 0.11, 1)
    tex = os.path.join(ROOT, "art", "textures")
    for o in objs:
        m = bpy.data.materials.new("pv_" + o.name)
        m.use_nodes = True
        nt = m.node_tree
        bsdf = nt.nodes["Principled BSDF"]
        vc = nt.nodes.new("ShaderNodeVertexColor")
        vc.layer_name = "Col"
        img = nt.nodes.new("ShaderNodeTexImage")
        img.image = bpy.data.images.load(os.path.join(tex, "r37_%s_albedo.png" % o.name.split("__")[-1]))
        mul = nt.nodes.new("ShaderNodeMixRGB")
        mul.blend_type = 'MULTIPLY'
        mul.inputs[0].default_value = 1.0
        nt.links.new(img.outputs[0], mul.inputs[1])
        nt.links.new(vc.outputs[0], mul.inputs[2])
        nt.links.new(mul.outputs[0], bsdf.inputs["Base Color"])
        o.data.materials.append(m)
    bpy.ops.mesh.primitive_plane_add(size=60, location=(0, 4, 0))
    ld = bpy.data.lights.new("moon", 'SUN')
    ld.energy = 3.0
    ld.color = (0.62, 0.72, 1.0)
    lo = bpy.data.objects.new("moon", ld)
    lo.rotation_euler = (math.radians(46), 0, math.radians(30))
    sc.collection.objects.link(lo)
    cd = bpy.data.cameras.new("cam")
    cam = bpy.data.objects.new("cam", cd)
    sc.collection.objects.link(cam)
    sc.camera = cam
    for name, loc, tgt, lens in (("front", (4, -11, 3), (0, 3, 2), 28), ("house", (-7, 2, 3.5), (0, 7.5, 1.5), 30)):
        cam.location = Vector(loc)
        cam.rotation_euler = (Vector(tgt) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
        cd.lens = lens
        sc.render.filepath = os.path.join(PREVIEW, "mile_%s.png" % name)
        bpy.ops.render.render(write_still=True)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    objs = [mk(milestone(), "Stone__hewn"), mk(house(), "House__hewn"), mk(timbers(), "Timber__timber", False)]
    co = mk(collision(), "Mile-colonly", False)
    export(objs + [co], os.path.join(OUT, "vista_milestone.glb"))
    if PREVIEW:
        os.makedirs(PREVIEW, exist_ok=True)
        co.hide_render = True
        render(objs)


main()
