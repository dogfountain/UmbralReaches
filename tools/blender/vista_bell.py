"""THE EIGHTH BELL: the Founder cast seven bells for the Stair; the eighth was cast in the sky, and the sky let it fall.
It lies on its side in the Bellfall's crater, a third sunk in the scorched floor, its mouth toward the south lip.
A true bell profile turned in bronze (lip, sound bow, waist, shoulder, crown), raised moulding lines at the bow and the
shoulder, a band of the Order's seven-pointed stars round the waist, six canons on the crown with the torn stub of its
timber yoke, a wedge broken out of the lip with the crack run up from it to the shoulder, cold runes along the crack.
Verdigris pools in the recesses and runs down from the mouldings; the bronze is dark where it lay in the fire.
Modelled by script (no scans, no downloads).

  tools/blender/run.sh vista_bell.py -- [--preview DIR]

Exports (art/models/):
  vista_bell.glb      Bell__bronze (the shell, inside and out, mouldings, stars, canons), Yoke__timber (the torn stub),
                      Runes__glow (the marks along the crack), Shard0..3__bronze (the lip's broken pieces, laid apart),
                      Bell-colonly (outer and inner shell: you walk into its mouth)
  vista_bell_far.glb  ~300 triangles (BellFar__bronze)
Vertex colour carries the bronze, the patina and the scorch. Frame: Godot Y up; the bell's own axis runs from the mouth
(+Z) to the crown (-Z), tilted TILT up toward the crown; origin on the crater floor under the bell's middle.
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
rnd = random.Random(8)

SEG = 112
TILT = math.radians(14.0)         # the crown end raised: it lies on its shoulder and lip
SINK = 2.6                        # how far the low side is under the floor
BREAK_A = math.radians(-62.0)     # where on the lip the wedge broke out (-90 = the bell's top as it lies, +90 under it)
BREAK_W = math.radians(38.0)

# outer profile (height up the bell from the lip, radius), inner profile: a bell 12 m across the mouth, 11 m to the crown
OUTER = [(0.0, 6.3), (0.18, 6.38), (0.5, 6.2), (1.0, 5.8), (1.7, 5.2), (2.7, 4.6), (3.9, 4.15), (5.3, 3.85),
         (6.6, 3.7), (7.8, 3.68), (8.7, 3.8), (9.3, 3.72), (9.8, 3.35), (10.25, 2.55), (10.55, 1.5), (10.7, 0.0)]
INNER = [(0.0, 5.62), (0.6, 5.1), (1.6, 4.55), (2.8, 4.1), (4.2, 3.75), (5.8, 3.45), (7.4, 3.32), (8.6, 3.3),
         (9.4, 3.2), (9.9, 2.6), (10.12, 1.4), (10.2, 0.0)]
BANDS = [(0.95, 0.07, 0.05), (1.25, 0.06, 0.04), (6.9, 0.09, 0.06), (7.55, 0.09, 0.06), (8.75, 0.07, 0.05)]   # z, height, proud


def lerp(a, b, t):
    return a + (b - a) * t


def sstep(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3.0 - 2.0 * t)


def prof(tab, z):
    for i in range(len(tab) - 1):
        if tab[i][0] <= z <= tab[i + 1][0]:
            t = (z - tab[i][0]) / (tab[i + 1][0] - tab[i][0])
            t = t * t * (3.0 - 2.0 * t)
            return lerp(tab[i][1], tab[i + 1][1], t)
    return tab[-1][1]


def broken(a, z):
    """How far (m) the lip is broken away at angle a: a jagged wedge, deepest at its middle."""
    d = abs(((a - BREAK_A + math.pi) % (2 * math.pi)) - math.pi)
    if d > BREAK_W:
        return 0.0
    depth = 3.4 * (1.0 - (d / BREAK_W) ** 1.6) + 0.35 * noise.noise(Vector((a * 9.0, 0.0, 1.0)))
    return max(0.0, depth)


def bands(z):
    b = 0.0
    for (bz, bh, bp) in BANDS:
        b = max(b, bp * sstep(bh, bh * 0.4, abs(z - bz)))
    return b


def star_relief(a, z):
    """Seven-pointed stars in relief round the waist band (between the waist lines), twelve of them."""
    zc = 7.22
    if abs(z - zc) > 0.32:
        return 0.0
    k = round(a / (2 * math.pi / 12.0))
    ac = k * 2 * math.pi / 12.0
    r0 = prof(OUTER, zc)
    dx = (a - ac) * r0
    dz = z - zc
    rr = math.hypot(dx, dz)
    th = math.atan2(dz, dx)
    edge = 0.22 + 0.1 * math.cos(7.0 * th)
    return 0.045 * sstep(edge, edge - 0.04, rr)


def colour(a, z, outer, crack):
    """Bronze: dark brown-gold, verdigris in recesses and streaking down from the mouldings, scorched dark on the side
    that lay in the fire (the low side), the crack's lips bright where the bronze tore."""
    base = (0.36, 0.25, 0.14)
    n1 = noise.noise(Vector((a * 3.0, z * 0.6, 2.0)))
    n2 = noise.noise(Vector((a * 11.0, z * 2.4, 5.0)))
    verd = (0.22, 0.42, 0.36)
    streak = sstep(0.25, 0.7, noise.noise(Vector((a * 9.0, z * 0.35, 9.0))) + 0.2) * (0.5 + 0.5 * sstep(0.0, 9.0, z))
    mott = noise.noise(Vector((a * 4.5, z * 1.1, 4.0))) * 0.5 + noise.noise(Vector((a * 17.0, z * 4.0, 6.0))) * 0.25
    pat = max(0.0, min(1.0, 0.2 + 0.4 * n1 + 0.25 * streak + 0.35 * mott + (0.25 if not outer else 0.0)))
    c = [lerp(base[i], verd[i], pat * 0.75) for i in range(3)]
    # the low side lay in the fire
    low = sstep(0.1, 0.9, math.sin(a))
    for i in range(3):
        c[i] *= lerp(1.0, 0.45, low * (0.6 + 0.4 * n2))
    if crack > 0.0:
        bright = (0.62, 0.45, 0.24)
        c = [lerp(c[i], bright[i], crack) for i in range(3)]
    return (c[0], c[1], c[2], 1.0)


def crack_amount(a, z):
    """The crack: from the break's middle up the bell to the shoulder, wandering."""
    ac = BREAK_A + 0.18 * math.sin(z * 0.9) + 0.06 * noise.noise(Vector((z * 2.0, 0.0, 3.0)))
    d = abs(((a - ac + math.pi) % (2 * math.pi)) - math.pi) * prof(OUTER, z)
    if z < 3.0 or z > 9.2:
        return 0.0
    w = 0.09 * (1.0 - sstep(7.5, 9.2, z))
    return sstep(w, 0.0, d)


def frame():
    """The bell's own frame into the crater: axis along -Y (Blender) toward the crown, tilted up, sunk."""
    return Matrix.Translation((0.0, 0.0, 6.3 - SINK)) @ Matrix.Rotation(TILT, 4, 'X') @ Matrix.Translation((0.0, -5.4, 0.0)) @ Matrix.Rotation(math.radians(-90.0), 4, 'X')


def shell():
    bm = bmesh.new()
    col = bm.loops.layers.color.new("Col")
    uv = bm.loops.layers.uv.new("UVMap")
    zs_o = sorted(set([i * 0.12 for i in range(int(10.7 / 0.12) + 1)] + [b[0] + o for b in BANDS for o in (-b[1], 0.0, b[1])]))
    zs_o = [z for z in zs_o if z <= 10.7]
    zs_i = [i * 0.25 for i in range(int(10.2 / 0.25) + 1)]
    m = frame()

    def ring(z, r_fn, outer):
        out = []
        for k in range(SEG):
            a = 2 * math.pi * k / SEG
            r = r_fn(z)
            br = broken(a, z)
            cz = z
            if br > 0.0 and z < br:
                cz = br                       # the broken wedge: the surface steps up to the break's edge
                r = r_fn(br)
            cr = crack_amount(a, cz)
            if outer:
                r += bands(cz) + star_relief(a, cz) - 0.06 * cr
                r += 0.012 * noise.noise(Vector((a * 6.0, cz * 1.5, 7.0)))
            else:
                r += 0.04 * cr
            # the lip curls a little where it struck
            p = Vector((math.cos(a) * r, math.sin(a) * r, cz))
            out.append((bm.verts.new(m @ p), colour(a, cz, outer, cr), (a * 6.0 / math.pi, cz / 3.0)))
        return out

    def skin(rings, flip):
        for j in range(len(rings) - 1):
            for k in range(SEG):
                a, b, c, d = rings[j][k], rings[j][(k + 1) % SEG], rings[j + 1][(k + 1) % SEG], rings[j + 1][k]
                vs = [a, b, c, d] if not flip else [d, c, b, a]
                try:
                    f = bm.faces.new([v[0] for v in vs])
                except ValueError:
                    continue
                for l, v in zip(f.loops, vs):
                    l[col] = v[1]
                    l[uv].uv = v[2]
    outer = [ring(z, lambda zz: prof(OUTER, zz), True) for z in zs_o[:-1]]
    inner = [ring(z, lambda zz: prof(INNER, zz), False) for z in zs_i[:-1]]
    skin(outer, False)
    skin(inner, True)
    # the lip: join the bottom outer ring to the bottom inner ring
    lo, li = outer[0], inner[0]
    for k in range(SEG):
        vs = [lo[k], li[k], li[(k + 1) % SEG], lo[(k + 1) % SEG]]
        try:
            f = bm.faces.new([v[0] for v in vs])
        except ValueError:
            continue
        for l, v in zip(f.loops, vs):
            l[col] = (0.5, 0.36, 0.2, 1.0)
            l[uv].uv = v[2]
    # caps at the crown
    for rings, flip in ((outer, False), (inner, True)):
        top = rings[-1]
        cz = 10.7 if not flip else 10.2
        c = bm.verts.new(m @ Vector((0, 0, cz)))
        for k in range(SEG):
            vs = [top[k], top[(k + 1) % SEG]]
            try:
                f = bm.faces.new([vs[0][0], vs[1][0], c] if not flip else [vs[1][0], vs[0][0], c])
            except ValueError:
                continue
            for l in f.loops:
                l[col] = (0.3, 0.32, 0.26, 1.0)
                l[uv].uv = (0, 0)
    canons(bm, col, uv, m)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return bm


def torus_part(bm, col, uv, m, c, axis_a, R, r, a0, a1, seg=14, tseg=7, colr=(0.3, 0.33, 0.27, 1.0)):
    """A section of a ring (a canon loop) standing up from the crown, in the bell's frame."""
    rings = []
    for i in range(seg + 1):
        t = lerp(a0, a1, i / seg)
        cen = c + Vector((math.cos(axis_a) * math.cos(t) * R, math.sin(axis_a) * math.cos(t) * R, math.sin(t) * R))
        tang = Vector((-math.cos(axis_a) * math.sin(t), -math.sin(axis_a) * math.sin(t), math.cos(t)))
        u = tang.cross(Vector((-math.sin(axis_a), math.cos(axis_a), 0.0))).normalized()
        w = tang.cross(u).normalized()
        rings.append([bm.verts.new(m @ (cen + (u * math.cos(2 * math.pi * k / tseg) + w * math.sin(2 * math.pi * k / tseg)) * r)) for k in range(tseg)])
    for i in range(seg):
        for k in range(tseg):
            f = bm.faces.new((rings[i][k], rings[i][(k + 1) % tseg], rings[i + 1][(k + 1) % tseg], rings[i + 1][k]))
            for l in f.loops:
                l[col] = colr
                l[uv].uv = (i / seg, k / tseg)


def canons(bm, col, uv, m):
    """Six loops on the crown and a thicker central argent."""
    for j in range(6):
        a = 2 * math.pi * j / 6.0
        c = Vector((math.cos(a) * 0.75, math.sin(a) * 0.75, 10.55))
        torus_part(bm, col, uv, m, c, a, 0.55, 0.13, 0.0, math.pi, seg=12, tseg=6)
    torus_part(bm, col, uv, m, Vector((0, 0, 10.6)), 0.0, 0.8, 0.2, 0.0, math.pi, seg=14, tseg=8)


def yoke():
    """The timber yoke's torn stub still through the argent: two beams, splintered ends, an iron strap."""
    bm = bmesh.new()
    col = bm.loops.layers.color.new("Col")
    uv = bm.loops.layers.uv.new("UVMap")
    m = frame()
    for side, ln in ((-1, 2.4), (1, 1.5)):
        tmp = bmesh.new()
        bmesh.ops.create_cube(tmp, size=1.0)
        for v in tmp.verts:
            v.co = Vector((v.co.x * ln, v.co.y * 0.5, v.co.z * 0.55))
            if v.co.x * side > 0.0:
                v.co.z += rnd.uniform(-0.2, 0.25)
                v.co.y += rnd.uniform(-0.12, 0.12)
                v.co.x += rnd.uniform(-0.3, 0.2)
        mp = {}
        for v in tmp.verts:
            mp[v] = bm.verts.new(m @ (v.co + Vector((side * ln * 0.5, 0.0, 11.15))))
        for f in tmp.faces:
            nf = bm.faces.new([mp[v] for v in f.verts])
            for l, ol in zip(nf.loops, f.loops):
                l[col] = (0.3, 0.22, 0.15, 1.0) if ol.vert.co.x * side < ln * 0.3 else (0.12, 0.09, 0.07, 1.0)
                l[uv].uv = (ol.vert.co.x, ol.vert.co.z)
        tmp.free()
    return bm


def runes():
    """Cold marks along the crack: short strokes in groups, just proud of the bronze (emissive in the game)."""
    bm = bmesh.new()
    col = bm.loops.layers.color.new("Col")
    uv = bm.loops.layers.uv.new("UVMap")
    m = frame()
    z = 3.3
    while z < 8.9:
        ac = BREAK_A + 0.18 * math.sin(z * 0.9)
        for side in (-1, 1):
            a = ac + side * (0.16 + 0.05 * rnd.random())
            r = prof(OUTER, z) + bands(z) + 0.025
            for s in range(rnd.randint(2, 3)):
                zz = z + s * 0.12
                ln = rnd.uniform(0.12, 0.26)
                tilt = rnd.uniform(-0.6, 0.6)
                p0 = Vector((math.cos(a) * r, math.sin(a) * r, zz))
                t = Vector((-math.sin(a), math.cos(a), 0.0)) * math.cos(tilt) * ln + Vector((0, 0, math.sin(tilt) * ln))
                nrm = Vector((math.cos(a), math.sin(a), 0.0))
                w = t.cross(nrm).normalized() * 0.025
                vs = [bm.verts.new(m @ q) for q in (p0 - w, p0 + w, p0 + t + w, p0 + t - w)]
                f = bm.faces.new(vs)
                for l in f.loops:
                    l[col] = (0.55, 0.75, 1.0, 1.0)
                    l[uv].uv = (0, 0)
        z += rnd.uniform(0.45, 0.8)
    return bm


def shard(i):
    """A piece of the broken lip: a curved slab of the sound bow, ragged where it broke."""
    bm = bmesh.new()
    col = bm.loops.layers.color.new("Col")
    uv = bm.loops.layers.uv.new("UVMap")
    span = rnd.uniform(0.35, 0.6)
    h = rnd.uniform(1.0, 2.2)
    n = 10
    rows = []
    for j in range(4):
        z = h * j / 3.0
        row = []
        for k in range(n + 1):
            a = -span * 0.5 + span * k / n
            rag = 0.25 * noise.noise(Vector((a * 9.0 + i, z, 3.0))) if j == 3 else 0.0
            for (r, w) in ((prof(OUTER, z) + 0.02, 1), (prof(INNER, z) - 0.02, 0)):
                pass
            ro = prof(OUTER, z + rag)
            ri = prof(INNER, z + rag)
            row.append((Vector((math.cos(a) * ro, math.sin(a) * ro, z + rag)), Vector((math.cos(a) * ri, math.sin(a) * ri, z + rag))))
        rows.append(row)
    vo = [[bm.verts.new(p[0]) for p in row] for row in rows]
    vi = [[bm.verts.new(p[1]) for p in row] for row in rows]
    for j in range(3):
        for k in range(n):
            for grid, flip in ((vo, False), (vi, True)):
                q = [grid[j][k], grid[j][k + 1], grid[j + 1][k + 1], grid[j + 1][k]]
                bm.faces.new(q if not flip else list(reversed(q)))
    for k in range(n):
        for j in (0, 3):
            q = [vo[j][k], vi[j][k], vi[j][k + 1], vo[j][k + 1]]
            bm.faces.new(q if j == 0 else list(reversed(q)))
    for j in range(3):
        for k in (0, n):
            q = [vo[j][k], vo[j + 1][k], vi[j + 1][k], vi[j][k]]
            bm.faces.new(q if k == n else list(reversed(q)))
    for f in bm.faces:
        for l in f.loops:
            l[col] = colour(0.3 * i, l.vert.co.z, True, 0.0)
            l[uv].uv = (l.vert.co.x / 3.0, l.vert.co.z / 3.0)
    # laid on the floor: fallen on its face, turned
    c = Vector((0, 0, 0))
    for v in bm.verts:
        c += v.co
    c /= len(bm.verts)
    rot = Matrix.Rotation(rnd.uniform(0, 2 * math.pi), 4, 'Z') @ Matrix.Rotation(math.radians(rnd.uniform(70, 100)), 4, 'Y')
    for v in bm.verts:
        v.co = rot @ (v.co - c)
    zmin = min(v.co.z for v in bm.verts)
    places = [(-9.5, 6.0), (7.5, 9.0), (-4.0, 11.5), (11.0, 2.0)]
    for v in bm.verts:
        v.co += Vector((places[i][0], -places[i][1], -zmin - 0.25))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return bm


def far():
    bm = bmesh.new()
    col = bm.loops.layers.color.new("Col")
    m = frame()
    seg = 14
    zs = [0.0, 1.6, 4.2, 7.8, 9.6, 10.5]
    rings = []
    for z in zs:
        r = prof(OUTER, z)
        rings.append([bm.verts.new(m @ Vector((math.cos(2 * math.pi * k / seg) * r, math.sin(2 * math.pi * k / seg) * r, z))) for k in range(seg)])
    for j in range(len(rings) - 1):
        for k in range(seg):
            f = bm.faces.new((rings[j][k], rings[j][(k + 1) % seg], rings[j + 1][(k + 1) % seg], rings[j + 1][k]))
            for l in f.loops:
                l[col] = (0.32, 0.3, 0.22, 1.0)
    c = bm.verts.new(m @ Vector((0, 0, 10.7)))
    for k in range(seg):
        f = bm.faces.new((rings[-1][k], rings[-1][(k + 1) % seg], c))
        for l in f.loops:
            l[col] = (0.32, 0.3, 0.22, 1.0)
    inner = [bm.verts.new(m @ Vector((math.cos(2 * math.pi * k / seg) * 5.4, math.sin(2 * math.pi * k / seg) * 5.4, 0.3))) for k in range(seg)]
    for k in range(seg):
        f = bm.faces.new((rings[0][(k + 1) % seg], rings[0][k], inner[k], inner[(k + 1) % seg]))
        for l in f.loops:
            l[col] = (0.08, 0.07, 0.06, 1.0)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
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
    sc.cycles.samples = 40
    sc.cycles.use_denoising = True
    sc.render.resolution_x, sc.render.resolution_y = 1400, 1000
    sc.world = bpy.data.worlds.new("w")
    sc.world.use_nodes = True
    sc.world.node_tree.nodes["Background"].inputs[0].default_value = (0.05, 0.06, 0.11, 1)
    for o in objs:
        m = bpy.data.materials.new("pv_" + o.name)
        m.use_nodes = True
        nt = m.node_tree
        bsdf = nt.nodes["Principled BSDF"]
        vc = nt.nodes.new("ShaderNodeVertexColor")
        vc.layer_name = "Col"
        nt.links.new(vc.outputs[0], bsdf.inputs["Base Color"])
        if "bronze" in o.name:
            bsdf.inputs["Metallic"].default_value = 0.75
            bsdf.inputs["Roughness"].default_value = 0.42
        if "glow" in o.name:
            nt.links.new(vc.outputs[0], bsdf.inputs["Emission Color"])
            bsdf.inputs["Emission Strength"].default_value = 3.0
        o.data.materials.append(m)
    bpy.ops.mesh.primitive_circle_add(vertices=64, radius=26.0, fill_type='NGON', location=(0, 0, 0))
    g = bpy.context.active_object
    gm = bpy.data.materials.new("ground")
    gm.use_nodes = True
    gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.06, 0.05, 0.05, 1)
    g.data.materials.append(gm)
    for n, rot, e, c in (("moon", (math.radians(46), 0, math.radians(30)), 3.4, (0.62, 0.72, 1.0)),
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
    for name, loc, tgt, lens in (("front", (8, -26, 8), (0, 0, 4), 35), ("side", (24, -4, 7), (0, 0, 4), 35),
                                 ("crown", (-10, 22, 10), (0, 0, 5), 35), ("mouth", (2, -12, 3), (0, 0, 4.5), 24)):
        cam.location = Vector(loc)
        cam.rotation_euler = (Vector(tgt) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
        cd.lens = lens
        sc.render.filepath = os.path.join(PREVIEW, "bell_%s.png" % name)
        bpy.ops.render.render(write_still=True)


def collision():
    bm = bmesh.new()
    m = frame()
    seg = 24
    for tab, flip in ((OUTER, False), (INNER, True)):
        zs = [tab[i][0] for i in range(len(tab))]
        rings = [[bm.verts.new(m @ Vector((math.cos(2 * math.pi * k / seg) * prof(tab, z), math.sin(2 * math.pi * k / seg) * prof(tab, z), z))) for k in range(seg)] for z in zs[:-1]]
        for j in range(len(rings) - 1):
            for k in range(seg):
                q = [rings[j][k], rings[j][(k + 1) % seg], rings[j + 1][(k + 1) % seg], rings[j + 1][k]]
                bm.faces.new(q if not flip else list(reversed(q)))
    return bm


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    objs = [mk(shell(), "Bell__bronze"), mk(yoke(), "Yoke__timber", False), mk(runes(), "Runes__glow", False)]
    for i in range(4):
        objs.append(mk(shard(i), "Shard%d__bronze" % i, False))
    co = mk(collision(), "Bell-colonly", False)
    export(objs + [co], os.path.join(OUT, "vista_bell.glb"))
    fo = mk(far(), "BellFar__bronze", False)
    export([fo], os.path.join(OUT, "vista_bell_far.glb"))
    if PREVIEW:
        os.makedirs(PREVIEW, exist_ok=True)
        co.hide_render = True
        fo.hide_render = True
        render(objs)


main()
