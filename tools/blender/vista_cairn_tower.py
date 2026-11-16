"""THE CAIRN TOWER: on the crown of the Thousand Cairns, where the pilgrims who turned back each left a stone, someone
began to lay the stones up instead of heaping them, and others went on with it: a stepped cone of dry-laid stone in
three tiers, each set back from the one below, a ledge walk round each, a ramp of slabs climbing the face from ledge to
ledge, small cairns left on every ledge, and at the top the first cairn, the great one, with a pole hung with rags.
No mortar anywhere: thin slabs and fieldstones in rough courses, every face uneven, the joints open and dark, a
through-stone standing out here and there, lichen on the weather side, moss low. Modelled by script (no scans).

  tools/blender/run.sh vista_cairn_tower.py -- [--preview DIR]

Exports (art/models/):
  vista_cairn_tower.glb      Tower__hewn (the tiers, ledges, ramps, cairns), Pole__timber, Rags__cloth,
                             Tower-colonly (tiers as prisms, ledges, ramp treads: walkable to the top)
  vista_cairn_tower_far.glb  ~200 triangles (TowerFar__hewn)
Frame: Blender Z up -> Godot Y up, Blender +Y -> Godot -Z. Origin on the ground at the axis; the first ramp starts on
the south side (Godot +Z).
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
rnd = random.Random(31)

# tiers: (z0, z1, radius at foot, radius at top) - each battered inward; a ledge at z1 out to the next tier's foot
TIERS = [(-1.2, 7.0, 11.0, 9.6), (7.0, 13.2, 7.9, 6.9), (13.2, 18.8, 5.4, 4.6)]
LEDGE = 1.6                      # the walk's width on each ledge (from the tier above's foot)
RAMP_W = 1.5
RISE = 0.32


def lerp(a, b, t):
    return a + (b - a) * t


def sstep(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3.0 - 2.0 * t)


def tier_r(tier, z):
    z0, z1, r0, r1 = tier
    t = max(0.0, min(1.0, (z - z0) / (z1 - z0)))
    return lerp(r0, r1, t ** 0.85)


def new_bm():
    bm = bmesh.new()
    return bm, bm.loops.layers.color.new("Col"), bm.loops.layers.uv.new("UVMap")


def tone(seed, a, z, pill, up=0.0):
    h = random.Random(seed)
    v = h.uniform(0.62, 0.88)
    fam = h.random()
    c = [v * 0.96, v * 0.95, v * 0.9] if fam < 0.6 else ([v * 1.02, v * 0.96, v * 0.84] if fam < 0.85 else [v * 0.82, v * 0.84, v * 0.88])
    j = 1.0 - pill
    for i in range(3):
        c[i] *= lerp(1.0, 0.25, j)              # open joints: dark, no mortar
    # lichen on the weather side (west, Blender -X), pale orange and white rosettes
    lic = sstep(0.62, 0.76, noise.noise(Vector((a * 8.0, z * 2.2, 4.0))) * 0.5 + 0.5) * pill * (0.35 + 0.65 * max(0.0, -math.cos(a)))
    lc = (0.9, 0.78, 0.55) if h.random() < 0.5 else (0.86, 0.86, 0.8)
    moss = sstep(3.0, -1.0, z) * (0.5 + 0.5 * noise.noise(Vector((a * 3.0, z, 1.0)))) * 0.7 + up * 0.45
    for i in range(3):
        c[i] = lerp(c[i], lc[i], lic * 0.6)
        c[i] = lerp(c[i], (0.36, 0.44, 0.26)[i] * v, max(0.0, min(1.0, moss)))
    return (min(c[0], 1.0), min(c[1], 1.0), min(c[2], 1.0), 1.0)


def courses(z0, z1):
    out = []
    z = z0
    while z < z1 - 0.05:
        h = rnd.uniform(0.22, 0.4) if rnd.random() < 0.7 else rnd.uniform(0.42, 0.58)
        if z + h > z1 - 0.1:
            h = z1 - z
        out.append((z, z + h))
        z += h
    return out


def wall(bm, col, uv, tier, ti, skip=None):
    """One tier's battered face, stone by stone: each stone its own proud, uneven face over an open dark joint."""
    for ci, (z0, z1) in enumerate(courses(tier[0], tier[1])):
        rm = tier_r(tier, 0.5 * (z0 + z1))
        circ = 2 * math.pi * rm
        joints = []
        acc = 0.0
        a0 = rnd.uniform(0, 2 * math.pi)
        while acc < circ - 0.3:
            ln = rnd.uniform(0.7, 1.8) if rnd.random() < 0.93 else rnd.uniform(1.9, 2.5)
            joints.append((a0 + acc / rm) % (2 * math.pi))
            acc += ln
        joints.sort()
        n = len(joints)
        hgt = z1 - z0
        for k in range(n):
            ja = joints[k]
            jb = joints[(k + 1) % n] + (2 * math.pi if k == n - 1 else 0.0)
            ln = (jb - ja) * rm
            seed = ti * 100000 + ci * 1000 + k
            h = random.Random(seed)
            proud = h.uniform(0.0, 0.12)
            tilt = h.uniform(-0.05, 0.05)
            if skip is not None and skip(0.5 * (ja + jb), 0.5 * (z0 + z1)):
                continue
            ss = [0.0, 0.04]
            m = 0.04
            while m + 0.75 < ln - 0.04:
                m += 0.7
                ss.append(m)
            ss += [ln - 0.04, ln]
            ts = [0.0, min(0.04, hgt * 0.3), hgt - min(0.04, hgt * 0.3), hgt]
            grid = []
            for s in ss:
                a = ja + s / rm
                row = []
                for t in ts:
                    z = z0 + t
                    e = min(s, ln - s, t, hgt - t)
                    pill = sstep(0.0, 0.04, e)
                    r = tier_r(tier, z) + (proud + tilt * (s / ln - 0.5) * 2.0 + 0.03 * noise.noise(Vector((a * 7.0, z * 3.0, seed * 0.01)))) * pill - 0.07 * (1.0 - pill)
                    row.append((bm.verts.new((math.cos(a) * r, math.sin(a) * r, z)), tone(seed, a, z, pill), (a * rm / 3.0, z / 3.0)))
                grid.append(row)
            for i in range(len(grid) - 1):
                for j in range(len(ts) - 1):
                    q = [grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1]]
                    f = bm.faces.new([v[0] for v in q])
                    for l, v in zip(f.loops, q):
                        l[col] = v[1]
                        l[uv].uv = v[2]


def slab(bm, col, uv, c, size, yaw, seed, pitch=0.0, roll=0.0, up=0.0):
    """A rough flat stone: a box with chamfers and a warped top."""
    tmp = bmesh.new()
    bmesh.ops.create_cube(tmp, size=1.0)
    for v in tmp.verts:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
    bmesh.ops.bevel(tmp, geom=list(tmp.edges), offset=min(size) * 0.18, segments=1, affect='EDGES')
    for v in tmp.verts:
        v.co += Vector((noise.noise(v.co * 1.7 + Vector((seed, 0, 0))), noise.noise(v.co * 1.7 + Vector((0, seed, 0))),
                        noise.noise(v.co * 1.7 + Vector((0, 0, seed))))) * min(size) * 0.22
    m = Matrix.Translation(Vector(c)) @ Matrix.Rotation(yaw, 4, 'Z') @ Matrix.Rotation(pitch, 4, 'Y') @ Matrix.Rotation(roll, 4, 'X')
    mp = {v: bm.verts.new(m @ v.co) for v in tmp.verts}
    for f in tmp.faces:
        nf = bm.faces.new([mp[v] for v in f.verts])
        for l, ol in zip(nf.loops, f.loops):
            w = m @ ol.vert.co
            l[col] = tone(seed, math.atan2(w.y, w.x), w.z, 1.0 if f.normal.z < 0.5 else 0.9, up * max(0.0, f.normal.z))
            l[uv].uv = (w.x / 3.0 + w.z / 3.0, w.y / 3.0)
    tmp.free()


def cairn(bm, col, uv, c, r, h, seed):
    """A heap of fieldstones: rings of stones, each course smaller, a capstone."""
    hh = random.Random(seed)
    z = c[2]
    rr = r
    k = 0
    while z < c[2] + h and rr > 0.12:
        n = max(1, int(2 * math.pi * rr / (rr * 0.9 + 0.25)))
        for i in range(n):
            a = 2 * math.pi * (i + hh.random() * 0.4) / n
            s = rr * 0.75 + 0.18
            slab(bm, col, uv, (c[0] + math.cos(a) * rr * 0.8, c[1] + math.sin(a) * rr * 0.8, z + s * 0.22), (s, s * 0.8, s * 0.45), a + hh.uniform(-0.4, 0.4), seed + k * 31 + i, hh.uniform(-0.2, 0.2), hh.uniform(-0.2, 0.2), 0.3)
        z += rr * 0.42 + 0.1
        rr *= 0.72
        k += 1
    slab(bm, col, uv, (c[0], c[1], z + 0.1), (0.5, 0.4, 0.22), hh.uniform(0, 3), seed + 999)


def ramps():
    """For each tier, a half turn of slab treads up its face from the ledge below to the ledge above, a kerb of
    stones on the outer edge. [(tier index, angle, z, radius of the face there)] for the treads."""
    out = []
    a_start = -math.pi * 0.5                      # south (Blender -Y = Godot +Z)
    for ti, tier in enumerate(TIERS):
        z0 = 0.15 if ti == 0 else tier[0] + 0.15
        z1 = tier[1]
        n = int(round((z1 - z0) / RISE))
        span = math.pi * (1.1 if ti == 0 else 0.95)
        for i in range(n + 1):
            t = i / n
            a = a_start - span * t
            z = z0 + (z1 - z0) * t
            out.append((ti, a, z))
        a_start = a_start - span + math.pi * 0.35   # the next ramp starts a little round the ledge
    return out


def tower():
    bm, col, uv = new_bm()
    steps = ramps()

    for ti, tier in enumerate(TIERS):
        wall(bm, col, uv, tier, ti)
        # the ledge: flat slabs from this tier's top edge in to the next tier's foot (or a floor at the top)
        r_out = tier_r(tier, tier[1]) + 0.1
        r_in = TIERS[ti + 1][2] - 0.3 if ti + 1 < len(TIERS) else 0.0
        z = tier[1]
        rr = r_out - 0.45
        ring = 0
        while rr > max(r_in, 0.4):
            n = max(6, int(2 * math.pi * rr / 1.15))
            for i in range(n):
                a = 2 * math.pi * (i + 0.5 * (ring % 2)) / n
                s = 2 * math.pi * rr / n
                slab(bm, col, uv, (math.cos(a) * rr, math.sin(a) * rr, z - 0.12), (0.92, s * 0.94, 0.24), a, ti * 7000 + ring * 100 + i, rnd.uniform(-0.04, 0.04), rnd.uniform(-0.04, 0.04), 0.4)
            rr -= 0.9
            ring += 1
        # a kerb of stones along the ledge's edge (not where the ramp leaves it)
        n = int(2 * math.pi * r_out / 0.9)
        for i in range(n):
            a = 2 * math.pi * i / n
            if any(st[0] == ti + 1 and abs(((a - st[1] + math.pi) % (2 * math.pi)) - math.pi) < 0.25 and st[2] < tier[1] + 1.0 for st in steps):
                continue
            if rnd.random() < 0.2:
                continue
            slab(bm, col, uv, (math.cos(a) * (r_out - 0.15), math.sin(a) * (r_out - 0.15), z + 0.2), (0.5, 0.75, 0.38), a, ti * 9000 + i, 0, 0, 0.3)
        # small cairns left on the ledge by the ones who climbed it
        for k in range(5 if ti < 2 else 3):
            a = rnd.uniform(0, 2 * math.pi)
            if any(abs(((a - st[1] + math.pi) % (2 * math.pi)) - math.pi) < 0.35 for st in steps if st[0] == ti + 1):
                continue
            rc = 0.5 * (r_out + max(r_in, 0.0)) if ti < 2 else rnd.uniform(1.5, 3.4)
            cairn(bm, col, uv, (math.cos(a) * rc, math.sin(a) * rc, z), rnd.uniform(0.3, 0.55), rnd.uniform(0.6, 1.1), 50000 + ti * 100 + k)
    # the ramps' treads
    for i, (ti, a, z) in enumerate(steps):
        tier = TIERS[ti]
        rf = tier_r(tier, min(z, tier[1]))
        rr = rf + RAMP_W * 0.5 - 0.05
        slab(bm, col, uv, (math.cos(a) * rr, math.sin(a) * rr, z - 0.14), (RAMP_W + 0.2, 0.62, 0.28), a, 70000 + i, 0, 0, 0.35)
        if i % 2 == 0:
            ro = rf + RAMP_W - 0.1
            slab(bm, col, uv, (math.cos(a) * ro, math.sin(a) * ro, z + 0.12), (0.3, 0.55, 0.3), a, 80000 + i, 0, 0, 0.3)
        # the treads are carried on a battered stack of stones down to the ledge below
        if i % 4 == 0:
            zb = (TIERS[ti - 1][1] if ti > 0 else -0.6)
            zz = zb
            k = 0
            while zz < z - 0.45:
                sh = min(rnd.uniform(0.3, 0.5), z - 0.3 - zz)
                rr2 = rf + RAMP_W * 0.55 + rnd.uniform(-0.1, 0.1)
                slab(bm, col, uv, (math.cos(a) * rr2, math.sin(a) * rr2, zz + sh * 0.5), (RAMP_W * rnd.uniform(0.7, 0.95), rnd.uniform(0.6, 0.85), sh), a + rnd.uniform(-0.08, 0.08), 90000 + i * 20 + k)
                zz += sh
                k += 1
    # the first cairn on the top floor
    top = TIERS[-1][1]
    cairn(bm, col, uv, (0.0, 0.0, top), 1.9, 3.6, 123)
    bm.normal_update()
    return bm


def pole():
    bm, col, uv = new_bm()
    top = TIERS[-1][1]
    pts = [Vector((0.05 * math.sin(i), 0.04 * math.cos(i * 1.3), top + 1.0 + i * 1.2)) for i in range(6)]
    tube(bm, col, uv, pts, 0.09, (0.34, 0.27, 0.2, 1.0))
    # a cross-tree with rope to hang the rags on
    tube(bm, col, uv, [Vector((-1.1, 0.0, top + 5.2)), Vector((1.1, 0.0, top + 5.4))], 0.06, (0.32, 0.26, 0.2, 1.0))
    return bm


def rags():
    """Strips of cloth tied to the cross-tree and the pole, hanging and blown a little east."""
    bm, col, uv = new_bm()
    top = TIERS[-1][1]
    cols = [(0.62, 0.55, 0.42), (0.55, 0.3, 0.24), (0.7, 0.68, 0.6), (0.4, 0.42, 0.5), (0.6, 0.5, 0.3)]
    for i in range(14):
        x = rnd.uniform(-1.0, 1.0) if i < 10 else rnd.uniform(-0.1, 0.1)
        z = top + 5.3 + 0.1 * x if i < 10 else top + rnd.uniform(2.0, 4.6)
        ln = rnd.uniform(0.7, 1.8)
        w = rnd.uniform(0.08, 0.18)
        c = cols[i % len(cols)]
        segs = 5
        prev = None
        for s in range(segs + 1):
            t = s / segs
            off = Vector((0.35 * t * t, 0.1 * math.sin(t * 3 + i), -ln * t))
            p = Vector((x, 0.0, z)) + off
            a = bm.verts.new(p + Vector((0, -w * 0.5, 0)))
            b = bm.verts.new(p + Vector((0, w * 0.5, 0)))
            if prev:
                f = bm.faces.new((prev[0], prev[1], b, a))
                for l in f.loops:
                    l[col] = (c[0] * (1 - 0.3 * t), c[1] * (1 - 0.3 * t), c[2] * (1 - 0.3 * t), 1.0)
                    l[uv].uv = (0.0, t)
            prev = (a, b)
    return bm


def tube(bm, col, uv, pts, r, colour, seg=7):
    rings = []
    for i, p in enumerate(pts):
        d = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        u = d.cross(Vector((0, 0, 1)))
        if u.length < 1e-3:
            u = d.cross(Vector((1, 0, 0)))
        u.normalize()
        w = d.cross(u)
        rings.append([bm.verts.new(p + (u * math.cos(2 * math.pi * k / seg) + w * math.sin(2 * math.pi * k / seg)) * r) for k in range(seg)])
    for i in range(len(rings) - 1):
        for k in range(seg):
            f = bm.faces.new((rings[i][k], rings[i][(k + 1) % seg], rings[i + 1][(k + 1) % seg], rings[i + 1][k]))
            for l in f.loops:
                l[col] = colour
                l[uv].uv = (k / seg, i * 0.5)


def prism(bm, z0, z1, r0, r1, seg=24):
    a = [bm.verts.new((math.cos(2 * math.pi * k / seg) * r0, math.sin(2 * math.pi * k / seg) * r0, z0)) for k in range(seg)]
    b = [bm.verts.new((math.cos(2 * math.pi * k / seg) * r1, math.sin(2 * math.pi * k / seg) * r1, z1)) for k in range(seg)]
    for k in range(seg):
        bm.faces.new((a[k], a[(k + 1) % seg], b[(k + 1) % seg], b[k]))
    bm.faces.new(list(reversed(a)))
    bm.faces.new(b)


def collision():
    bm = bmesh.new()
    for tier in TIERS:
        prism(bm, tier[0], tier[1], tier[2] + 0.05, tier[3] + 0.05)
    for (ti, a, z) in ramps():
        rf = tier_r(TIERS[ti], min(z, TIERS[ti][1]))
        rr = rf + RAMP_W * 0.5 - 0.05
        tmp = bmesh.new()
        bmesh.ops.create_cube(tmp, size=1.0)
        m = Matrix.Translation((math.cos(a) * rr, math.sin(a) * rr, z - 0.14)) @ Matrix.Rotation(a, 4, 'Z') @ Matrix.Diagonal((RAMP_W + 0.3, 0.7, 0.28, 1.0))
        mp = {v: bm.verts.new(m @ v.co) for v in tmp.verts}
        for f in tmp.faces:
            bm.faces.new([mp[v] for v in f.verts])
        tmp.free()
    prism(bm, TIERS[-1][1], TIERS[-1][1] + 2.4, 1.9, 0.6, 10)
    return bm


def far():
    bm, col, uv = new_bm()
    seg = 10
    pts = []
    for tier in TIERS:
        pts += [(tier[0], tier[2]), (tier[1], tier[3]), (tier[1], tier[3] + 0.1)]
    pts.append((TIERS[-1][1] + 3.2, 0.3))
    rings = [[bm.verts.new((math.cos(2 * math.pi * k / seg) * r, math.sin(2 * math.pi * k / seg) * r, z)) for k in range(seg)] for (z, r) in pts]
    for j in range(len(rings) - 1):
        for k in range(seg):
            f = bm.faces.new((rings[j][k], rings[j][(k + 1) % seg], rings[j + 1][(k + 1) % seg], rings[j + 1][k]))
            for l in f.loops:
                l[col] = (0.62, 0.6, 0.55, 1.0)
    bm.normal_update()
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
    sc.render.resolution_x, sc.render.resolution_y = 1300, 1100
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
        path = os.path.join(tex, "r37_%s_albedo.png" % set_name)
        if os.path.exists(path):
            img = nt.nodes.new("ShaderNodeTexImage")
            img.image = bpy.data.images.load(path)
            mul = nt.nodes.new("ShaderNodeMixRGB")
            mul.blend_type = 'MULTIPLY'
            mul.inputs[0].default_value = 1.0
            nt.links.new(img.outputs[0], mul.inputs[1])
            nt.links.new(vc.outputs[0], mul.inputs[2])
            nt.links.new(mul.outputs[0], bsdf.inputs["Base Color"])
        else:
            nt.links.new(vc.outputs[0], bsdf.inputs["Base Color"])
        bsdf.inputs["Roughness"].default_value = 0.9
        o.data.materials.append(m)
    bpy.ops.mesh.primitive_circle_add(vertices=64, radius=30.0, fill_type='NGON', location=(0, 0, 0))
    g = bpy.context.active_object
    gm = bpy.data.materials.new("ground")
    gm.use_nodes = True
    gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.14, 0.13, 0.1, 1)
    g.data.materials.append(gm)
    for n, rot, e, c in (("moon", (math.radians(46), 0, math.radians(30)), 3.2, (0.62, 0.72, 1.0)),
                         ("fill", (math.radians(66), 0, math.radians(210)), 0.9, (0.6, 0.65, 0.85))):
        ld = bpy.data.lights.new(n, 'SUN')
        ld.energy = e
        ld.color = c
        lo = bpy.data.objects.new(n, ld)
        lo.rotation_euler = rot
        sc.collection.objects.link(lo)
    cd = bpy.data.cameras.new("cam")
    cam = bpy.data.objects.new("cam", cd)
    sc.collection.objects.link(cam)
    sc.camera = cam
    for name, loc, tgt, lens in (("front", (6, -46, 12), (0, 0, 10), 40), ("side", (40, 14, 16), (0, 0, 10), 40),
                                 ("ledge", (9, -14, 9.5), (0, 0, 9), 26), ("top", (6, -9, 22), (0, 0, 19), 30)):
        cam.location = Vector(loc)
        cam.rotation_euler = (Vector(tgt) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
        cd.lens = lens
        sc.render.filepath = os.path.join(PREVIEW, "cairn_%s.png" % name)
        bpy.ops.render.render(write_still=True)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    objs = [mk(tower(), "Tower__hewn"), mk(pole(), "Pole__timber"), mk(rags(), "Rags__cloth", False)]
    co = mk(collision(), "Tower-colonly", False)
    export(objs + [co], os.path.join(OUT, "vista_cairn_tower.glb"))
    fo = mk(far(), "TowerFar__hewn", False)
    export([fo], os.path.join(OUT, "vista_cairn_tower_far.glb"))
    for o in objs:
        print("PART", o.name, tris(o))
    if PREVIEW:
        os.makedirs(PREVIEW, exist_ok=True)
        co.hide_render = True
        fo.hide_render = True
        render(objs)


main()
