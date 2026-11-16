"""THE KING'S BARROW: before the Order, before the Rooted, kings were laid on the ridge with their faces to the west, and
one door stands open. A long earthen mound (34 m by 15, 6 m high, its back end lower) ringed at its foot by a kerb of
set stones, some leaning, some fallen; at its east end a forecourt between two horns of tall orthostats, and in the
middle a doorway of two jambs and a great lintel, the blocking stone pulled out and lying in the forecourt. Through
the door a passage of upright slabs roofed with capstones runs into the mound to a chamber with two side cells and a
corbelled roof. You can walk in. Modelled by script (no scans, no downloads).

  tools/blender/run.sh vista_barrow.py -- [--preview DIR]

Exports art/models/vista_barrow.glb: Mound__daub (the turf skin: vertex colour heather and grass), Stones__hewn (kerb,
forecourt, door, passage, chamber), Barrow-colonly (the mound's shell with the passage open, the stones as boxes).
Frame: Blender Z up -> Godot Y up, Blender +Y -> Godot -Z. Origin on the ground at the mound's middle; the door faces
Blender -X (Godot -X: the stone row and barrow_track lie east... the builder turns it).
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
rnd = random.Random(19)

L, W, H = 34.0, 15.0, 6.0        # the mound
DOOR_X = L * 0.5                 # the door at the +X end (the builder turns +X to face the way)
PASS_W, PASS_H = 2.0, 2.4
PASS_LEN = 9.0
CH_R = 3.2                       # the chamber's half size


def sstep(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3.0 - 2.0 * t)


def new_bm():
    bm = bmesh.new()
    return bm, bm.loops.layers.color.new("Col"), bm.loops.layers.uv.new("UVMap")


def mound_h(x, y):
    """The mound: a long ellipsoid, higher at the door end, cut by the passage; turf lumps."""
    u = x / (L * 0.5)
    v = y / (W * 0.5)
    e = u * u + v * v
    if e >= 1.0:
        return 0.0
    hh = H * (0.75 + 0.25 * sstep(-1.0, 0.6, u)) * (1.0 - e) ** 0.62
    hh += 0.18 * noise.noise(Vector((x * 0.3, y * 0.3, 1.0))) * (1.0 - e)
    return hh


def turf(x, y, z):
    n = noise.noise(Vector((x * 0.9, y * 0.9, 7.0))) * 0.6 + noise.noise(Vector((x * 2.6, y * 2.6, 2.0))) * 0.4
    heather = sstep(0.0, 0.5, n) * 0.6
    g = (0.27, 0.29, 0.2)
    h = (0.3, 0.25, 0.27)
    c = [g[i] * (1 - heather) + h[i] * heather for i in range(3)]
    worn = sstep(0.4, 0.8, noise.noise(Vector((x * 0.4, y * 0.4, 9.0)))) * 0.5     # bare earth where the turf has slipped
    c = [c[i] * (1 - worn) + (0.3, 0.26, 0.21)[i] * worn for i in range(3)]
    v = 0.85 + 0.15 * noise.noise(Vector((x * 3.0, y * 3.0, 3.0)))
    return (c[0] * v * 0.9, c[1] * v * 0.9, c[2] * v * 0.9, 1.0)


def in_passage(x, y, z):
    return x > DOOR_X - PASS_LEN - CH_R * 2 and abs(y) < PASS_W * 0.5 + 0.3 and z < PASS_H + 0.6


def mound():
    bm, col, uv = new_bm()
    nx, ny = 70, 32
    verts = {}
    for i in range(nx + 1):
        for j in range(ny + 1):
            x = -L * 0.55 + L * 1.1 * i / nx
            y = -W * 0.55 + W * 1.1 * j / ny
            z = mound_h(x, y)
            verts[(i, j)] = (bm.verts.new((x, y, z - 0.25 * (1.0 if z <= 0.0 else 0.0))), (x, y, z))
    for i in range(nx):
        for j in range(ny):
            q = [verts[(i, j)], verts[(i + 1, j)], verts[(i + 1, j + 1)], verts[(i, j + 1)]]
            cx = sum(v[1][0] for v in q) / 4
            cy = sum(v[1][1] for v in q) / 4
            # the passage's mouth is open in the mound's door end
            if cx > DOOR_X - 2.4 and abs(cy) < PASS_W * 0.5 + 0.2:
                continue
            if all(v[1][2] <= 0.0 for v in q):
                continue
            f = bm.faces.new([v[0] for v in q])
            for l, v in zip(f.loops, q):
                l[col] = turf(*v[1])
                l[uv].uv = (v[1][0] / 3.0, v[1][1] / 3.0)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    for f in bm.faces:
        if f.normal.z < 0:
            f.normal_flip()
    return bm


def stone(bm, col, uv, c, size, yaw=0.0, lean=(0.0, 0.0), seed=0, tone=0.72, warp=0.08):
    warp *= 1.9
    tmp = bmesh.new()
    bmesh.ops.create_cube(tmp, size=1.0)
    bmesh.ops.subdivide_edges(tmp, edges=list(tmp.edges), cuts=2, use_grid_fill=True)
    for v in tmp.verts:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
    for v in tmp.verts:
        top = max(0.0, v.co.z / max(size[2] * 0.5, 0.01))
        v.co.x *= 1.0 - 0.22 * top * top                 # weathered: narrower toward the top, rounded shoulders
        v.co.y *= 1.0 - 0.15 * top * top
        v.co += Vector((noise.noise(v.co * 1.3 + Vector((seed, 0, 0))), noise.noise(v.co * 1.3 + Vector((0, seed, 0))),
                        noise.noise(v.co * 1.3 + Vector((0, 0, seed))))) * min(size) * warp * 2.0
        v.co += Vector((0, 0, 0)) if top < 0.85 else Vector((0, 0, -0.08 * size[2] * noise.noise(v.co * 2.0)))
    m = Matrix.Translation(Vector(c)) @ Matrix.Rotation(yaw, 4, 'Z') @ Matrix.Rotation(lean[0], 4, 'X') @ Matrix.Rotation(lean[1], 4, 'Y')
    mp = {v: bm.verts.new(m @ v.co) for v in tmp.verts}
    tmp.normal_update()
    rot = Matrix.Rotation(yaw, 3, 'Z')
    for f in tmp.faces:
        nf = bm.faces.new([mp[v] for v in f.verts])
        n = rot @ f.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        for l, ol in zip(nf.loops, f.loops):
            w = m @ ol.vert.co
            l[uv].uv = ((w.y, w.z) if ax == 0 else (w.x, w.z) if ax == 1 else (w.x, w.y))
            l[uv].uv = (l[uv].uv[0] / 3.0, l[uv].uv[1] / 3.0)
            lic = 0.25 * max(0.0, noise.noise(w * 1.3 + Vector((seed, 1, 2))))
            moss = sstep(0.6, -0.2, w.z) * 0.4 + max(0.0, n.z) * 0.25
            t = tone * (0.9 + 0.2 * noise.noise(w * 0.5))
            l[col] = (t * (1 - moss * 0.4) + lic, t * (1 - moss * 0.1) + lic * 0.9, t * (1 - moss * 0.5) + lic * 0.7, 1.0)
    tmp.free()


def stones():
    bm, col, uv = new_bm()
    # the kerb: set stones round the foot, a few leaning or fallen
    n = 46
    for k in range(n):
        a = 2 * math.pi * k / n
        x = math.cos(a) * L * 0.5 * 1.02
        y = math.sin(a) * W * 0.5 * 1.04
        if x > DOOR_X - 4.0 and abs(y) < 4.5:
            continue
        r = rnd.random()
        if r < 0.12:
            continue
        hgt = rnd.uniform(0.7, 1.3)
        lean = (rnd.uniform(-0.15, 0.15), rnd.uniform(-0.15, 0.15))
        if r < 0.2:
            stone(bm, col, uv, (x * 1.05, y * 1.05, 0.25), (1.2, 0.45, 0.5), a + 0.3, (0.0, 1.4), seed=k)
            continue
        stone(bm, col, uv, (x, y, hgt * 0.5 - 0.3), (0.95, 0.4, hgt + 0.6), a + math.pi * 0.5, lean, seed=k)
    # the forecourt: two horns of tall orthostats curving out from the door
    for side in (-1, 1):
        for i in range(5):
            t = i / 4.0
            ang = side * (0.35 + 0.9 * t)
            r = 4.0 + 3.5 * t
            x = DOOR_X + 0.6 + math.cos(ang) * r * 0.55
            y = math.sin(ang) * r
            hgt = 3.4 - 1.6 * t + rnd.uniform(-0.2, 0.2)
            stone(bm, col, uv, (x, y, hgt * 0.5 - 0.4), (0.6, 1.3, hgt + 0.8), ang + math.pi * 0.5, (rnd.uniform(-0.05, 0.05), rnd.uniform(-0.08, 0.08)), seed=100 + i * 2 + side, tone=0.68)
    # the door: two jambs and a lintel; the blocking stone pulled out and lying in the forecourt
    for side in (-1, 1):
        stone(bm, col, uv, (DOOR_X, side * (PASS_W * 0.5 + 0.4), 1.3), (0.9, 0.8, 3.0), 0.0, (0.0, 0.0), seed=200 + side, tone=0.66, warp=0.04)
    stone(bm, col, uv, (DOOR_X + 0.05, 0.0, PASS_H + 0.55), (1.3, PASS_W + 2.4, 1.1), 0.0, (0.0, 0.0), seed=210, tone=0.7, warp=0.04)
    stone(bm, col, uv, (DOOR_X + 3.4, 1.2, 0.35), (2.6, 0.7, 1.9), 0.4, (1.35, 0.1), seed=220, tone=0.62)
    # the passage: upright slabs each side, capstones over
    x = DOOR_X - 0.4
    k = 0
    while x > DOOR_X - PASS_LEN:
        ln = rnd.uniform(1.2, 1.7)
        for side in (-1, 1):
            stone(bm, col, uv, (x - ln * 0.5, side * (PASS_W * 0.5 + 0.25), PASS_H * 0.5 - 0.2), (ln, 0.45, PASS_H + 0.4), 0.0, (side * 0.04, 0.0), seed=300 + k * 2 + side, tone=0.6, warp=0.05)
        stone(bm, col, uv, (x - ln * 0.5, 0.0, PASS_H + 0.3), (ln + 0.1, PASS_W + 1.4, 0.6), 0.0, (0.0, 0.0), seed=400 + k, tone=0.62, warp=0.05)
        x -= ln
        k += 1
    # the chamber: a ring of uprights, two side cells, a corbelled roof of stepped slabs closing to a capstone
    cx = x - CH_R
    n = 10
    for i in range(n):
        a = 2 * math.pi * (i + 0.5) / n
        if abs(math.cos(a)) > 0.85 and math.cos(a) > 0:
            continue                                               # the passage comes in here
        stone(bm, col, uv, (cx + math.cos(a) * CH_R, math.sin(a) * CH_R, PASS_H * 0.6 - 0.2), (0.5, 1.9, PASS_H * 1.2 + 0.4), a, (0.0, 0.0), seed=500 + i, tone=0.58, warp=0.05)
    for c in range(4):
        r = CH_R - 0.55 * c
        z = PASS_H * 1.2 + 0.1 + c * 0.45
        m = max(6, int(2 * math.pi * r / 1.4))
        for i in range(m):
            a = 2 * math.pi * (i + 0.5 * (c % 2)) / m
            stone(bm, col, uv, (cx + math.cos(a) * r, math.sin(a) * r, z), (0.7, 1.5, 0.45), a, (0.0, 0.0), seed=600 + c * 20 + i, tone=0.6, warp=0.05)
    stone(bm, col, uv, (cx, 0.0, PASS_H * 1.2 + 2.1), (2.4, 2.2, 0.55), 0.3, (0.0, 0.0), seed=700, tone=0.6, warp=0.04)
    for side in (-1, 1):
        for i in range(3):
            stone(bm, col, uv, (cx + (i - 1) * 1.0, side * (CH_R + 1.6), PASS_H * 0.5 - 0.2), (1.0, 0.45, PASS_H + 0.2), 0.0, (0.0, 0.0), seed=800 + i + side * 7, tone=0.58)
        stone(bm, col, uv, (cx, side * (CH_R + 0.9), PASS_H + 0.35), (3.2, 1.8, 0.5), 0.0, (0.0, 0.0), seed=820 + side, tone=0.6)
    # the chamber floor: a few flags
    for i in range(6):
        stone(bm, col, uv, (cx + rnd.uniform(-2, 2), rnd.uniform(-2, 2), -0.05), (1.4, 1.2, 0.18), rnd.uniform(0, 3), (0.0, 0.0), seed=900 + i, tone=0.5, warp=0.03)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return bm, cx


def collision(cx):
    """Walls you cannot walk through and a floor you can: the mound as boxes left and right of the passage and over it,
    the passage and chamber open."""
    bm = bmesh.new()
    def box(c, s):
        tmp = bmesh.new()
        bmesh.ops.create_cube(tmp, size=1.0)
        mp = {v: bm.verts.new(Vector(c) + Vector((v.co.x * s[0], v.co.y * s[1], v.co.z * s[2]))) for v in tmp.verts}
        for f in tmp.faces:
            bm.faces.new([mp[v] for v in f.verts])
        tmp.free()
    # the mound's body except a corridor (passage + chamber) along y = 0 at the door end
    open_x0 = cx - CH_R - 0.6
    box(((open_x0 - L * 0.5) * 0.5, 0.0, H * 0.4), (open_x0 + L * 0.5, W * 0.9, H * 0.8))
    for side in (-1, 1):
        box((0.5 * (open_x0 + DOOR_X), side * (0.5 * (W * 0.45 + PASS_W * 0.5 + 0.4)), H * 0.4), (DOOR_X - open_x0, W * 0.45 - PASS_W * 0.5 - 0.4, H * 0.8))
    box((0.5 * (open_x0 + DOOR_X), 0.0, PASS_H + 0.3 + (H * 0.8 - PASS_H) * 0.5), (DOOR_X - open_x0, PASS_W + 0.8, H * 0.8 - PASS_H))
    for side in (-1, 1):
        box((DOOR_X, side * (PASS_W * 0.5 + 0.4), 1.3), (0.9, 0.8, 3.0))
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
    sc.render.resolution_x, sc.render.resolution_y = 1400, 900
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
        set_name = o.name.split("__")[-1]
        img = nt.nodes.new("ShaderNodeTexImage")
        img.image = bpy.data.images.load(os.path.join(tex, "r37_%s_albedo.png" % set_name))
        mul = nt.nodes.new("ShaderNodeMixRGB")
        mul.blend_type = 'MULTIPLY'
        mul.inputs[0].default_value = 1.0
        nt.links.new(img.outputs[0], mul.inputs[1])
        nt.links.new(vc.outputs[0], mul.inputs[2])
        nt.links.new(mul.outputs[0], bsdf.inputs["Base Color"])
        bsdf.inputs["Roughness"].default_value = 0.9
        o.data.materials.append(m)
    bpy.ops.mesh.primitive_plane_add(size=120, location=(0, 0, -0.02))
    g = bpy.context.active_object
    gm = bpy.data.materials.new("ground")
    gm.use_nodes = True
    gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.1, 0.11, 0.07, 1)
    g.data.materials.append(gm)
    for n, rot, e in (("moon", (math.radians(46), 0, math.radians(120)), 3.2), ("fill", (math.radians(66), 0, math.radians(300)), 0.8)):
        ld = bpy.data.lights.new(n, 'SUN')
        ld.energy = e
        ld.color = (0.62, 0.72, 1.0)
        lo = bpy.data.objects.new(n, ld)
        lo.rotation_euler = rot
        sc.collection.objects.link(lo)
    cd = bpy.data.cameras.new("cam")
    cam = bpy.data.objects.new("cam", cd)
    sc.collection.objects.link(cam)
    sc.camera = cam
    for name, loc, tgt, lens in (("door", (34, -10, 5), (14, 0, 2), 32), ("long", (-6, -40, 14), (0, 0, 2), 32), ("in", (16.5, 0.3, 1.5), (4, 0, 1.6), 18)):
        cam.location = Vector(loc)
        cam.rotation_euler = (Vector(tgt) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
        cd.lens = lens
        sc.render.filepath = os.path.join(PREVIEW, "barrow_%s.png" % name)
        bpy.ops.render.render(write_still=True)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sbm, cx = stones()
    objs = [mk(mound(), "Mound__daub"), mk(sbm, "Stones__hewn")]
    co = mk(collision(cx), "Barrow-colonly", False)
    export(objs + [co], os.path.join(OUT, "vista_barrow.glb"))
    print("CHAMBER_X", cx)
    if PREVIEW:
        os.makedirs(PREVIEW, exist_ok=True)
        co.hide_render = True
        render(objs)


main()
