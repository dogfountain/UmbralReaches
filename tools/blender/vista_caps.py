"""THE RING OF GIANT CAPS: in the Lanternwood nothing burns and nothing needs to; the light grows out of the dead. Three
giant caps stand round a clearing with a fairy ring of smaller ones between them. Each is modelled as a fungus is
built: a fibrous stem rising from a flared, rooted base with a ragged ring (annulus) under the cap, the cap a broad
dome with a turned-down, torn rim and warts on its skin, and under it real gills, thin radial fins from the stem to the
rim, that give off a faint cold light (the only light here: cold, not warmth; under the glow threshold).
Modelled by script (no scans, no downloads).

  tools/blender/run.sh vista_caps.py -- [--preview DIR]

Exports art/models/vista_caps.glb: Giant0..2 and Small0..2, each a set of meshes <Name>__skin (stem and cap, vertex
colour), <Name>__glow (the gills and the cap's underside), and <Name>-colonly (stem and cap as convex-ish prisms).
Frame: Blender Z up -> Godot Y up. Each piece's origin is its stem's foot.
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


def lerp(a, b, t):
    return a + (b - a) * t


def sstep(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3.0 - 2.0 * t)


def new_bm():
    bm = bmesh.new()
    return bm, bm.loops.layers.color.new("Col"), bm.loops.layers.uv.new("UVMap")


def skin_col(p, kind, seed):
    n = noise.noise(p * 0.9 + Vector((seed, 0, 0)))
    n2 = noise.noise(p * 4.0 + Vector((0, seed, 0)))
    if kind == "stem":
        v = 0.72 + 0.1 * n + 0.06 * n2
        return (v * 0.92, v * 0.9, v * 0.86, 1.0)
    if kind == "cap":
        v = 0.55 + 0.12 * n
        return (v * 0.78, v * 0.74, v * 0.82, 1.0)        # a grey-violet skin
    if kind == "wart":
        return (0.82, 0.8, 0.74, 1.0)
    return (0.4, 0.38, 0.36, 1.0)


def mushroom(name, H, R, lean, seed, warts=40, gills=72):
    rnd = random.Random(seed)
    bm, col, uv = new_bm()
    gbm, gcol, guv = new_bm()
    seg = 28
    # the stem's axis: a gentle S, leaning
    def axis(t):
        return Vector((lean * H * (0.6 * t * t) + 0.08 * H * math.sin(t * 2.2 + seed), 0.05 * H * math.sin(t * 3.1 + seed * 2), H * t))
    sr = 0.085 * H
    rings = []
    nz = 22
    for j in range(nz + 1):
        t = j / nz
        c = axis(t)
        foot = 1.0 + 1.3 * (1.0 - sstep(0.0, 0.16, t)) ** 2               # the flared, rooted base
        r = sr * foot * (1.0 - 0.18 * t) * (1.0 + 0.04 * math.sin(t * 9.0))
        ring = []
        for k in range(seg):
            a = 2 * math.pi * k / seg
            fib = 0.05 * sr * noise.noise(Vector((a * 3.0, t * 25.0, seed)))      # fibres along the stem
            root = (0.35 * sr * max(0.0, math.sin(a * 5 + seed)) ** 3) * (1.0 - sstep(0.0, 0.08, t))   # root buttresses
            rr = r + fib + root
            p = c + Vector((math.cos(a) * rr, math.sin(a) * rr, 0.0))
            ring.append((bm.verts.new(p), skin_col(p, "stem", seed), (a * rr, t * H)))
        rings.append(ring)
    for j in range(nz):
        for k in range(seg):
            q = [rings[j][k], rings[j][(k + 1) % seg], rings[j + 1][(k + 1) % seg], rings[j + 1][k]]
            f = bm.faces.new([v[0] for v in q])
            for l, v in zip(f.loops, q):
                l[col] = v[1]
                l[uv].uv = (v[2][0] / 2.0, v[2][1] / 2.0)
    top = axis(1.0)
    # the ragged ring (annulus) a third of the way under the cap
    ta = 0.78
    ca = axis(ta)
    ra0 = sr * (1.0 - 0.18 * ta)
    an = []
    for k in range(seg + 1):
        a = 2 * math.pi * k / seg
        drop = 0.04 * H * (1.0 + 0.6 * noise.noise(Vector((a * 4.0, seed, 3.0))))
        an.append((bm.verts.new(ca + Vector((math.cos(a) * ra0 * 1.02, math.sin(a) * ra0 * 1.02, 0.0))),
                   bm.verts.new(ca + Vector((math.cos(a) * ra0 * 1.9, math.sin(a) * ra0 * 1.9, -drop)))))
    for k in range(seg):
        f = bm.faces.new((an[k][0], an[k][1], an[k + 1][1], an[k + 1][0]))
        for l in f.loops:
            l[col] = (0.8, 0.78, 0.72, 1.0)
            l[uv].uv = (k / seg, 0.0)
    # the cap: a dome over the stem's top, the rim turned down and torn
    cseg = 56
    nr = 14
    tilt = Vector((lean * 0.35, 0.0, 1.0)).normalized()
    def cap_pt(u, a):
        """u 0 (crown) .. 1 (rim)."""
        rr = R * math.sin(u * math.pi * 0.5) ** 0.8
        tear = 0.0
        if u > 0.85:
            tear = 0.12 * R * max(0.0, noise.noise(Vector((a * 3.5, seed, 1.0)))) * sstep(0.85, 1.0, u)
        rr -= tear
        h = 0.38 * R * (1.0 - u ** 1.8) - 0.14 * R * sstep(0.7, 1.0, u)     # the dome, the rim turned down
        h += 0.03 * R * noise.noise(Vector((math.cos(a) * 2.0, math.sin(a) * 2.0, u * 3.0 + seed)))
        wob = 1.0 + 0.05 * math.sin(a * 3.0 + seed) + 0.03 * math.sin(a * 7.0)
        return top + Vector((math.cos(a) * rr * wob + tilt.x * h, math.sin(a) * rr * wob, h + 0.02 * H))
    grid = []
    for i in range(nr + 1):
        u = i / nr
        row = []
        for k in range(cseg):
            a = 2 * math.pi * k / cseg
            p = cap_pt(u, a)
            row.append((bm.verts.new(p), skin_col(p, "cap", seed), (math.cos(a) * u, math.sin(a) * u)))
        grid.append(row)
    crown = bm.verts.new(cap_pt(0.0, 0.0) + Vector((0, 0, 0.01)))
    for k in range(cseg):
        f = bm.faces.new((crown, grid[1][k][0], grid[1][(k + 1) % cseg][0]))
        for l in f.loops:
            l[col] = skin_col(l.vert.co, "cap", seed)
            l[uv].uv = (0.0, 0.0)
    for i in range(1, nr):
        for k in range(cseg):
            q = [grid[i][k], grid[i + 1][k], grid[i + 1][(k + 1) % cseg], grid[i][(k + 1) % cseg]]
            f = bm.faces.new([v[0] for v in q])
            for l, v in zip(f.loops, q):
                l[col] = v[1]
                l[uv].uv = (v[2][0] * R / 2.0, v[2][1] * R / 2.0)
    # the underside: a shallow cone from the rim in to the stem (glow), then the gills
    under = []
    for k in range(cseg):
        a = 2 * math.pi * k / cseg
        p = cap_pt(1.0, a) + Vector((0, 0, 0.01))
        q = top + Vector((math.cos(a) * sr * 0.9, math.sin(a) * sr * 0.9, 0.02 * H))
        under.append((gbm.verts.new(p), gbm.verts.new(q)))
    for k in range(cseg):
        a0, b0 = under[k]
        a1, b1 = under[(k + 1) % cseg]
        f = gbm.faces.new((a0, b0, b1, a1))
        for l in f.loops:
            l[gcol] = (0.08, 0.2, 0.22, 1.0)
            l[guv].uv = (0, 0)
    for g in range(gills):
        a = 2 * math.pi * (g + 0.5 * rnd.random()) / gills
        steps = 6
        prev = None
        for s in range(steps + 1):
            u = lerp(0.12, 0.97, s / steps)
            rim = cap_pt(1.0, a)
            inner = top + Vector((math.cos(a) * sr, math.sin(a) * sr, 0.02 * H))
            p = inner.lerp(rim, (u - 0.12) / 0.85)
            depth = 0.09 * R * math.sin(math.pi * (u - 0.12) / 0.85) + 0.02 * R
            a_ = gbm.verts.new(p + Vector((0, 0, -0.005)))
            b_ = gbm.verts.new(p + Vector((0, 0, -depth)))
            if prev:
                f = gbm.faces.new((prev[0], a_, b_, prev[1]))
                glow = 0.5 + 0.5 * math.sin(math.pi * (u - 0.12) / 0.85)
                for l in f.loops:
                    lit = glow * (1.0 if l.vert is b_ or l.vert is prev[1] else 0.55)
                    l[gcol] = (0.16 * lit, 0.62 * lit, 0.6 * lit, 1.0)
                    l[guv].uv = (0, 0)
            prev = (a_, b_)
    # warts on the cap's skin
    for w in range(warts):
        u = rnd.uniform(0.1, 0.8)
        a = rnd.uniform(0, 2 * math.pi)
        p = cap_pt(u, a)
        s = R * rnd.uniform(0.018, 0.04)
        tmp = bmesh.new()
        bmesh.ops.create_icosphere(tmp, subdivisions=1, radius=s)
        mp = {v: bm.verts.new(p + Vector((v.co.x, v.co.y, v.co.z * 0.6))) for v in tmp.verts}
        for f in tmp.faces:
            nf = bm.faces.new([mp[v] for v in f.verts])
            for l in nf.loops:
                l[col] = skin_col(l.vert.co, "wart", seed)
                l[uv].uv = (0, 0)
        tmp.free()
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    # collision: the stem as a prism, the cap as a flat disc
    cb = bmesh.new()
    for (z0, z1, r0, r1, c0) in ((0.0, H, sr * 1.6, sr * 0.85, Vector((0, 0, 0))),):
        n = 10
        lo = [cb.verts.new(Vector((math.cos(2 * math.pi * k / n) * r0, math.sin(2 * math.pi * k / n) * r0, z0))) for k in range(n)]
        hi = [cb.verts.new(top + Vector((math.cos(2 * math.pi * k / n) * r1, math.sin(2 * math.pi * k / n) * r1, 0))) for k in range(n)]
        for k in range(n):
            cb.faces.new((lo[k], lo[(k + 1) % n], hi[(k + 1) % n], hi[k]))
    n = 12
    rim = [cb.verts.new(cap_pt(0.95, 2 * math.pi * k / n)) for k in range(n)]
    cap_c = cb.verts.new(cap_pt(0.0, 0.0))
    for k in range(n):
        cb.faces.new((cap_c, rim[(k + 1) % n], rim[k]))
    return [mk(bm, name + "__skin"), mk(gbm, name + "__glow", False), mk(cb, name + "-colonly", False)]


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
              export_materials='NONE', export_normals=True, export_texcoords=True)
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
    sc.render.resolution_x, sc.render.resolution_y = 1400, 1000
    sc.world = bpy.data.worlds.new("w")
    sc.world.use_nodes = True
    sc.world.node_tree.nodes["Background"].inputs[0].default_value = (0.03, 0.04, 0.08, 1)
    for o in objs:
        m = bpy.data.materials.new("pv_" + o.name)
        m.use_nodes = True
        nt = m.node_tree
        bsdf = nt.nodes["Principled BSDF"]
        vc = nt.nodes.new("ShaderNodeVertexColor")
        vc.layer_name = "Col"
        nt.links.new(vc.outputs[0], bsdf.inputs["Base Color"])
        bsdf.inputs["Roughness"].default_value = 0.7
        if "glow" in o.name:
            nt.links.new(vc.outputs[0], bsdf.inputs["Emission Color"])
            bsdf.inputs["Emission Strength"].default_value = 4.0
        o.data.materials.append(m)
    bpy.ops.mesh.primitive_circle_add(vertices=64, radius=30.0, fill_type='NGON', location=(0, 0, 0))
    g = bpy.context.active_object
    gm = bpy.data.materials.new("ground")
    gm.use_nodes = True
    gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.05, 0.07, 0.05, 1)
    g.data.materials.append(gm)
    ld = bpy.data.lights.new("moon", 'SUN')
    ld.energy = 1.6
    ld.color = (0.62, 0.72, 1.0)
    lo = bpy.data.objects.new("moon", ld)
    lo.rotation_euler = (math.radians(50), 0, math.radians(30))
    sc.collection.objects.link(lo)
    cd = bpy.data.cameras.new("cam")
    cam = bpy.data.objects.new("cam", cd)
    sc.collection.objects.link(cam)
    sc.camera = cam
    for name, loc, tgt, lens in (("ring", (0, -30, 6), (0, 0, 6), 30), ("under", (2, -7, 2.2), (0, 0, 9), 22), ("high", (14, -22, 22), (0, 0, 5), 30)):
        cam.location = Vector(loc)
        cam.rotation_euler = (Vector(tgt) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
        cd.lens = lens
        sc.render.filepath = os.path.join(PREVIEW, "caps_%s.png" % name)
        bpy.ops.render.render(write_still=True)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    objs = []
    giants = [(13.0, 6.5, 0.12, 11), (10.5, 5.2, -0.2, 22), (8.0, 4.4, 0.25, 33)]
    smalls = [(3.2, 1.6, 0.15, 44), (2.2, 1.2, -0.1, 55), (1.4, 0.8, 0.2, 66)]
    for i, (h, r, ln, sd) in enumerate(giants):
        objs += mushroom("Giant%d" % i, h, r, ln, sd)
    for i, (h, r, ln, sd) in enumerate(smalls):
        objs += mushroom("Small%d" % i, h, r, ln, sd, warts=12, gills=40)
    export(objs, os.path.join(OUT, "vista_caps.glb"))
    if PREVIEW:
        os.makedirs(PREVIEW, exist_ok=True)
        # a preview ring: the giants round a clearing, the smalls between
        place = {"Giant0": (-6, 4, 0.3), "Giant1": (7, 3, 2.2), "Giant2": (0, 9, 4.0), "Small0": (-2, -3, 0), "Small1": (3, -4, 1), "Small2": (-5, -2, 2)}
        for o in objs:
            key = o.name.split("__")[0].split("-")[0]
            if key in place and "colonly" not in o.name:
                x, y, r = place[key]
                o.matrix_world = Matrix.Translation((x, y, 0)) @ Matrix.Rotation(r, 4, 'Z')
            if "colonly" in o.name:
                o.hide_render = True
        render([o for o in objs if "colonly" not in o.name])


main()
