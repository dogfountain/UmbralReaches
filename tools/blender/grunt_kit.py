"""Shared helpers for the rank-and-file enemy models (r30): metaball flesh with real muscle and joint
masses, procedural skin / chitin / hide / iron / wood materials, and the export of one GLB + one
baked atlas per kind. Builds on boss_kit (rig-space placement, cloth sim, atlas bake, per-socket
split), which stays the bosses' and is not edited here.

Rigid parts, one per rig socket, as for the bosses -- so every joint is modelled to bend: the child
part carries a mass centred ON its own pivot (shoulder ball, elbow, knee, ankle), the parent's end
reaches into it. A part rotating about its pivot keeps that mass in place, so a bent elbow or knee
shows flesh, never a crack between two cylinders.

Coordinates: G(x, y, z) is a Godot rig-space point (+Y up, the body faces -Z).
"""
import bpy
import math
import os
import sys
from mathutils import Vector, Quaternion, noise

sys.path.insert(0, os.path.dirname(__file__))
import boss_kit as K
from boss_kit import G

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

# a lone metaball of size s and stiffness k draws its surface at about s * f(k)
_KF = ((1.0, 0.394), (2.0, 0.574), (4.0, 0.684), (8.0, 0.76))


def _kf(st):
    for (a, fa), (b, fb) in zip(_KF, _KF[1:]):
        if st <= b:
            t = max(0.0, min(1.0, (st - a) / (b - a)))
            return fa + (fb - fa) * t
    return _KF[-1][1]


def _rot_to(d):
    d = Vector(d)
    if d.length < 1e-6:
        return Quaternion()
    return Vector((0, 0, 1)).rotation_difference(d.normalized())


class Flesh:
    """Metaball elements for one socket's flesh: balls, oriented ellipsoids and tapering chains,
    built into ONE smooth mesh (muscle flows into muscle, no primitives glued together)."""

    def __init__(self, sock):
        self.sock = sock
        self.e = []

    def ball(self, c, r, st=2.0, rot=None, neg=False):
        """r = (across, up, depth) like a Godot size (an oriented one is in its own frame)."""
        if isinstance(r, (int, float)):
            r = (r, r, r)
        elif rot is None:
            r = (r[0], r[2], r[1])
        self.e.append((Vector(c), tuple(r), st, rot or Quaternion(), neg))
        return self

    def along(self, a, b, r_side, r_len=None, st=2.0, squash=1.0, neg=False):
        """One ellipsoid from a to b (a muscle belly): radius r_side across, half the length along."""
        a, b = Vector(a), Vector(b)
        hl = (b - a).length * 0.5 if r_len is None else r_len
        rx = r_side if isinstance(r_side, (int, float)) else r_side[0]
        ry = r_side * squash if isinstance(r_side, (int, float)) else r_side[1]
        return self.ball((a + b) * 0.5, (rx, ry, hl), st, _rot_to(b - a) if (b - a).length > 1e-6 else Quaternion((1, 0, 0, 0)), neg)

    def chain(self, pts, radii, st=2.0, squash=1.0, step=0.7):
        """A tapering limb through `pts` with a radius per point, as overlapping ellipsoids."""
        pts = [Vector(p) for p in pts]
        for i in range(len(pts) - 1):
            a, b = pts[i], pts[i + 1]
            L = (b - a).length
            r0, r1 = radii[i], radii[i + 1]
            n = max(1, int(math.ceil(L / (max(min(r0, r1), 0.004) * step))))
            for k in range(n):
                t = (k + 0.5) / n
                r = r0 + (r1 - r0) * t
                self.ball(a.lerp(b, t), (r * 0.92, r * 0.92 * squash, max(L / n * 0.75, r * 0.92)), st, _rot_to(b - a) if L > 1e-6 else Quaternion((1, 0, 0, 0)))
        return self

    def build(self, name, mat, res=0.007, rough=0.0, seed=0.0):
        mb = bpy.data.metaballs.new(name)
        mb.resolution = res
        mb.render_resolution = res
        mb.threshold = 0.6
        for c, r, st, rot, neg in self.e:
            el = mb.elements.new(type='ELLIPSOID')
            el.co = c
            el.radius = 1.0
            f = _kf(st)
            el.size_x, el.size_y, el.size_z = r[0] / f, r[1] / f, r[2] / f
            el.stiffness = st
            el.rotation = rot
            el.use_negative = neg
        ob = bpy.data.objects.new(name, mb)
        bpy.context.scene.collection.objects.link(ob)
        bpy.ops.object.select_all(action='DESELECT')
        ob.select_set(True)
        bpy.context.view_layer.objects.active = ob
        bpy.ops.object.convert(target='MESH')
        ob = bpy.context.view_layer.objects.active
        ob.name = name
        ob["sock"] = self.sock
        ob.data.materials.clear()
        ob.data.materials.append(mat.m if hasattr(mat, "m") else mat)
        if rough > 0.0:
            for v in ob.data.vertices:
                n = v.normal
                v.co += n * rough * (noise.noise(v.co * 11.0 + Vector((seed, 0, 0))) + 0.4 * noise.noise(v.co * 29.0))
        for p in ob.data.polygons:
            p.use_smooth = True
        return ob


# --- materials ------------------------------------------------------------------------------------

def mulc(m, a, b):
    """Colour socket times colour socket (or a constant colour)."""
    node = m.n('ShaderNodeMix')
    node.data_type = 'RGBA'
    node.blend_type = 'MULTIPLY'
    node.inputs[0].default_value = 1.0
    for sock, v in ((node.inputs[6], a), (node.inputs[7], b)):
        if isinstance(v, tuple):
            sock.default_value = (v[0], v[1], v[2], 1.0)
        else:
            m.links.new(v, sock)
    return node.outputs[2]


def cavity(m, lo=0.46, hi=0.56, dark=0.35, edge=1.12):
    """Crease darkening and ridge lift from the mesh curvature (Cycles pointiness, baked)."""
    geo = m.n('ShaderNodeNewGeometry')
    return m.ramp(geo.outputs['Pointiness'], [(lo, (dark, dark, dark)), (0.5, (1, 1, 1)), (hi, (edge, edge, edge))])


def skin(name, base, deep, vein=(0.1, 0.04, 0.05), wrinkle=55.0, rough=0.66, wet=0.0, scale=1.0, pore=0.5, vein_amt=0.5, fade=None):
    """Dead, dry hide: two-tone mottle, a cellular wrinkle field, pores, creeping veins, darkened
    creases. `wet` lowers the roughness (the spitter's slick skin)."""
    m = K.Mat(name)
    mott = m.noise(4.0 * scale, 6.0, 0.62)
    col = m.ramp(mott, [(0.3, deep), (0.72, base)])
    blot = m.noise(13.0 * scale, 4.0, 0.5)
    col = m.mix(m.math('MULTIPLY', m.math('SUBTRACT', blot, 0.45, True), 0.9), col, deep)
    wr = m.voronoi(wrinkle * scale, 'DISTANCE_TO_EDGE')
    lines = m.math('SUBTRACT', 1.0, m.math('MULTIPLY', m.math('LESS_THAN', wr, 0.045), 1.0))
    vn = m.noise(9.0 * scale, 3.0, 0.4, dist=0.6)
    vmask = m.math('MULTIPLY', m.math('LESS_THAN', m.math('ABSOLUTE', m.math('SUBTRACT', vn, 0.5)), 0.012), vein_amt)
    col = m.mix(vmask, col, vein)
    if fade is not None:
        # models pass: (colour, z0, z1): below z0 (object/world height, Blender Z) the colour is the
        # body's, above z1 this material's, graded between: a pale face grows out of a dark neck
        sep = m.n('ShaderNodeSeparateXYZ')
        m.links.new(m.coord.outputs['Object'], sep.inputs[0])
        f = m.math('MULTIPLY', m.math('SUBTRACT', sep.outputs['Z'], fade[1]), 1.0 / max(fade[2] - fade[1], 1e-4), True)
        col = m.mix(f, fade[0], col)
    col = mulc(m, col, cavity(m))
    pores = m.noise(260.0 * scale, 2.0, 0.5)
    h = m.math('ADD', m.math('MULTIPLY', wr, 2.4), m.math('MULTIPLY', pores, pore))
    h = m.math('ADD', h, m.math('MULTIPLY', vmask, 0.5))
    h = m.math('ADD', h, m.math('MULTIPLY', m.noise(30.0 * scale, 5.0, 0.6), 0.6))
    r = m.math('ADD', m.math('MULTIPLY', lines, 0.0), rough - wet * 0.35)
    r = m.math('ADD', r, m.math('MULTIPLY', m.math('SUBTRACT', blot, 0.5), 0.12))
    return m.finish(col, r, 0.0, h, 0.55, 0.0035)


def chitin(name, base, edge, plates=14.0, rough=0.58):
    """Matte chitin: dark plates, a paler worn edge on every ridge (from curvature), a fine grain;
    lacquered only at the very edges."""
    m = K.Mat(name)
    v = m.voronoi(plates, 'F1')
    grain = m.noise(90.0, 4.0, 0.55)
    col = m.ramp(m.noise(5.0, 5.0, 0.6), [(0.3, tuple(c * 0.6 for c in base)), (0.75, base)])
    geo = m.n('ShaderNodeNewGeometry')
    ridge = m.math('SUBTRACT', geo.outputs['Pointiness'], 0.5)
    ridge = m.math('MULTIPLY', m.math('MAXIMUM', m.math('SUBTRACT', ridge, 0.03), 0.0), 5.0, True)
    col = m.mix(ridge, col, edge)
    col = mulc(m, col, cavity(m, 0.44, 0.56, 0.3, 1.0))
    h = m.math('ADD', m.math('MULTIPLY', v, 0.6), m.math('MULTIPLY', grain, 0.35))
    r = m.math('SUBTRACT', rough, m.math('MULTIPLY', ridge, 0.25))
    return m.finish(col, r, 0.0, h, 0.45, 0.003)


def bone(name="Bone", base=(0.78, 0.71, 0.58), dirt=(0.32, 0.25, 0.16), scale=7.0):
    m = K.Mat(name)
    sc = m.scan("beige_wall_001", scale)
    d = m.noise(7.0, 8.0, 0.6)
    cracks = m.voronoi(34.0, 'DISTANCE_TO_EDGE')
    gate = m.math('GREATER_THAN', m.noise(9.0, 3.0, 0.5), 0.5)
    crack = m.math('MULTIPLY', m.math('LESS_THAN', cracks, 0.016), gate)
    col = m.mul(m.mono(sc["color"]), tuple(c * 1.6 for c in base))
    col = m.mix(m.math('MULTIPLY', m.math('SUBTRACT', 1.0, d), 0.6), col, dirt)
    col = m.mix(m.math('MULTIPLY', crack, 0.85), col, (0.1, 0.08, 0.06))
    col = mulc(m, col, cavity(m, 0.45, 0.56, 0.45, 1.1))
    h = m.math('ADD', m.math('MULTIPLY', sc["disp"], 0.7), m.math('MULTIPLY', crack, -0.7))
    rough = m.math('ADD', m.math('MULTIPLY', sc["rough"], 0.5), 0.38)
    return m.finish(col, rough, 0.0, h, 0.7, 0.0025)


def cloth(name, tint, scan="caban", scale=9.0, grime=(0.05, 0.04, 0.03), rough=0.86):
    m = K.Mat(name)
    sc = m.scan(scan, scale)
    blot = m.noise(5.0, 6.0, 0.6)
    col = m.mul(m.mono(sc["color"]), tuple(c * 2.2 for c in tint))
    col = m.mix(m.math('MULTIPLY', blot, 0.45), col, grime)
    # grime rising from the hem
    z = m.zpos()
    hem = m.math('SUBTRACT', 1.0, m.math('MULTIPLY', z, 2.2), True)
    col = m.mix(m.math('MULTIPLY', hem, 0.6), col, grime)
    h = m.math('MULTIPLY', sc["disp"], 1.0)
    return m.finish(col, rough, 0.0, h, 0.6, 0.002)


def leather(name, tint=(0.25, 0.16, 0.1), scale=6.0):
    m = K.Mat(name)
    sc = m.scan("brown_leather", scale)
    col = m.mul(m.mono(sc["color"]), tuple(c * 2.0 for c in tint))
    col = mulc(m, col, cavity(m, 0.45, 0.56, 0.5, 1.15))
    rough = m.math('ADD', m.math('MULTIPLY', sc["rough"], 0.4), 0.45)
    return m.finish(col, rough, 0.0, sc["disp"], 0.5, 0.002)


def iron(name="Iron", base=(0.11, 0.105, 0.11), rust=(0.17, 0.08, 0.04)):
    m = K.Mat(name)
    r = m.noise(11.0, 7.0, 0.65)
    pit = m.noise(120.0, 3.0, 0.5)
    rmask = m.ramp(m.math('ADD', r, m.math('MULTIPLY', pit, 0.2)), [(0.6, (0, 0, 0)), (0.74, (1, 1, 1))])
    rmask = m.mono(rmask)
    col = m.mix(rmask, base, rust)
    geo = m.n('ShaderNodeNewGeometry')
    edge = m.math('MULTIPLY', m.math('MAXIMUM', m.math('SUBTRACT', geo.outputs['Pointiness'], 0.55), 0.0), 6.0, True)
    col = m.mix(m.math('MULTIPLY', edge, 0.35), col, (0.32, 0.31, 0.3))
    col = mulc(m, col, cavity(m, 0.45, 0.55, 0.45, 1.0))
    rough = m.math('ADD', 0.45, m.math('MULTIPLY', rmask, 0.42))
    metal = m.math('SUBTRACT', 0.8, m.math('MULTIPLY', rmask, 0.8))
    h = m.math('ADD', m.math('MULTIPLY', pit, 0.4), m.math('MULTIPLY', rmask, 0.3))
    return m.finish(col, rough, metal, h, 0.45, 0.002)


def wood(name="Wood", base=(0.2, 0.13, 0.08), scorch=0.5):
    """Weathered planks: grain along Z (the plank's length), soot rising from below."""
    m = K.Mat(name)
    mp = m.n('ShaderNodeMapping')
    mp.inputs['Scale'].default_value = (34.0, 34.0, 2.5)
    m.links.new(m.coord.outputs['Object'], mp.inputs['Vector'])
    gtex = m.n('ShaderNodeTexNoise')
    gtex.inputs['Scale'].default_value = 3.0
    gtex.inputs['Detail'].default_value = 8.0
    gtex.inputs['Distortion'].default_value = 1.5
    m.links.new(mp.outputs['Vector'], gtex.inputs['Vector'])
    grain = gtex.outputs['Fac']
    col = m.ramp(grain, [(0.35, tuple(c * 0.5 for c in base)), (0.65, base)])
    soot = m.mono(m.ramp(m.noise(3.0, 5.0, 0.6), [(0.55 - 0.2 * scorch, (0, 0, 0)), (0.75 - 0.2 * scorch, (1, 1, 1))]))
    col = m.mix(m.math('MULTIPLY', soot, 0.85), col, (0.025, 0.02, 0.018))
    col = mulc(m, col, cavity(m, 0.45, 0.56, 0.4, 1.1))
    h = m.math('MULTIPLY', grain, 1.0)
    return m.finish(col, 0.85, 0.0, h, 0.8, 0.003)


def earth(name="Earth", base=(0.2, 0.14, 0.09)):
    m = K.Mat(name)
    sc = m.scan("bark_brown_02", 5.0)
    clod = m.voronoi(18.0, 'F1')
    col = m.mul(m.mono(sc["color"]), tuple(c * 2.0 for c in base))
    col = m.mix(m.math('MULTIPLY', m.noise(8.0, 4.0, 0.6), 0.5), col, tuple(c * 0.45 for c in base))
    col = mulc(m, col, cavity(m, 0.45, 0.56, 0.35, 1.15))
    h = m.math('ADD', m.math('MULTIPLY', clod, 0.8), m.math('MULTIPLY', sc["disp"], 0.6))
    return m.finish(col, 0.95, 0.0, h, 0.9, 0.004)


def glow(name, col, strength=8.0, body=(0.04, 0.03, 0.02)):
    m = K.Mat(name)
    return m.finish(body, 0.5, 0.0, None, emit=col, emit_strength=strength)


def membrane(name, col, strength, skin_col):
    """A glowing sac under skin: veined, lit from within."""
    m = K.Mat(name)
    v = m.voronoi(22.0, 'DISTANCE_TO_EDGE')
    veins = m.math('LESS_THAN', v, 0.04)
    em = m.mix(veins, col, tuple(c * 0.25 for c in col))
    alb = m.mix(veins, skin_col, (0.08, 0.05, 0.05))
    return m.finish(alb, 0.3, 0.0, m.math('MULTIPLY', veins, -1.0), 0.6, 0.002, emit=em, emit_strength=strength)


# --- shapes -----------------------------------------------------------------------------------------

def strip(name, pts, width, thick, sock, mat, twist=0.0, taper=0.0, sides=6):
    """A flat strip (hair lock, rag, strap, bandage end): a loft of flattened sections."""
    n = len(pts)
    radii = []
    for i in range(n):
        t = i / max(n - 1, 1)
        w = width * 0.5 * (1.0 - taper * t)          # width is the full width
        radii.append((max(w, 0.0015), thick * 0.5))
    return K.loft(name, pts, radii, sock, mat, sides, cap0=True, cap1=True)


def bandage(name, a, b, r, turns, width, sock, mat, seed=0.0):
    """A strip of linen spiralling round the segment a -> b."""
    a, b = Vector(a), Vector(b)
    ax = b - a
    u, v = K.frame_from(ax)
    pts = []
    n = int(turns * 14) + 2
    for k in range(n):
        t = k / (n - 1)
        ang = t * turns * math.tau + seed
        rr = r * (1.0 + 0.05 * math.sin(t * 31.0 + seed))
        pts.append(a + ax * t + (u * math.cos(ang) + v * math.sin(ang)) * rr)
    return K.loft(name, pts, [(width, 0.004)] * n, sock, mat, 5)


def claw(name, base, direction, length, width, sock, mat, curl=0.5):
    """A hooked claw: thick root, curving down toward a sharp tip."""
    d = Vector(direction).normalized()
    side = d.cross(Vector((0, 0, 1)))
    if side.length < 0.1:
        side = d.cross(Vector((0, 1, 0)))
    down = side.cross(d).normalized()
    if down.z > 0:
        down = -down
    pts, radii = [], []
    for k in range(7):
        t = k / 6.0
        pts.append(Vector(base) + d * length * t + down * length * curl * t * t)
        radii.append((width * (1.0 - t) ** 0.8 + 0.0005, width * 0.75 * (1.0 - t) ** 0.8 + 0.0005))
    return K.loft(name, pts, radii, sock, mat, 8)


def plate(name, center, size, normal, sock, mat, segs=20, bend=0.0):
    """A curved shell plate (chitin, armour, a scale): a squashed half-dome bent over the body."""
    def deform(c):
        p = Vector(c)
        if p.z < 0:
            p.z *= 0.25                      # flat underside
        p.z -= bend * (p.x * p.x + p.y * p.y)
        return p
    ob = K.blob(name, Vector((0, 0, 0)), size, sock, mat, segs, max(8, segs // 2), deform)
    q = Vector((0, 0, 1)).rotation_difference(Vector(normal).normalized())
    for v in ob.data.vertices:
        v.co = q @ v.co + Vector(center)
    return ob


# --- skinning ------------------------------------------------------------------------------------
# The grunts are ONE skinned mesh on a flat skeleton, one bone per rig socket (GruntModel poses each
# bone from its socket every frame). Weights are written by hand, not bone heat: along each limb
# chain a vertex belongs to the segment it lies on, blended over a short band across every joint
# plane, so knees, elbows and the waist bend as flesh.

def _smooth(e0, e1, x):
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3.0 - 2.0 * t)


def chain_w(p, chain, band=0.05):
    """{bone: weight} for point p along chain [(bone, joint)]: joint k separates bone k-1 from bone k
    by the plane through it normal to the next segment (or the previous one, for the last)."""
    n = len(chain)
    if n == 1:
        return {chain[0][0]: 1.0}
    f = [0.0] * n
    for k in range(1, n):
        j = chain[k][1]
        d = (chain[k + 1][1] - j) if k + 1 < n else (j - chain[k - 1][1])
        d = d.normalized()
        b = band[k - 1] if isinstance(band, (list, tuple)) else band
        f[k] = _smooth(-b, b, (p - j).dot(d))
    w = {}
    for k in range(n):
        lo = f[k] if k > 0 else 1.0
        hi = f[k + 1] if k + 1 < n else 0.0
        v = lo * (1.0 - hi)
        if v > 1e-4:
            w[chain[k][0]] = w.get(chain[k][0], 0.0) + v
    tot = sum(w.values()) or 1.0
    return {b: v / tot for b, v in w.items()}


def weigh(ob, fn):
    """Write vertex groups from fn(world point) -> {bone: weight}."""
    groups = {}
    for v in ob.data.vertices:
        for b, wv in fn(ob.matrix_world @ v.co).items():
            if b not in groups:
                groups[b] = ob.vertex_groups.get(b) or ob.vertex_groups.new(name=b)
            groups[b].add([v.index], wv, 'REPLACE')


def armature(sockets, name="Armature"):
    """A flat armature: one unparented bone per socket, its head on the socket."""
    arm = bpy.data.armatures.new(name)
    ob = bpy.data.objects.new(name, arm)
    bpy.context.scene.collection.objects.link(ob)
    bpy.ops.object.select_all(action='DESELECT')
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode='EDIT')
    for nm, at in sockets.items():
        b = arm.edit_bones.new(nm)
        b.head = at
        b.tail = at + Vector((0, 0, 0.06))
        b.roll = 0.0
    bpy.ops.object.mode_set(mode='OBJECT')
    return ob


def budget(objs, target):
    """Decimate every part by one ratio so the whole model lands near `target` triangles (before
    the bake, so the maps match the final geometry). Tiny parts (eyes, teeth) are left alone."""
    tri = lambda o: sum(len(p.vertices) - 2 for p in o.data.polygons)
    total = sum(tri(o) for o in objs)
    if total <= target:
        return
    big = [o for o in objs if tri(o) > 300]
    fixed = total - sum(tri(o) for o in big)
    ratio = max(0.05, (target - fixed) / max(1, total - fixed))
    for o in big:
        d = o.modifiers.new("Budget", 'DECIMATE')
        d.ratio = ratio
        d.use_collapse_triangulate = True
        K.apply_mods(o)
    print("BUDGET", total, "->", sum(tri(o) for o in objs), "ratio", round(ratio, 3))


def export_skinned(objs, mats, name, sockets, weights, rigid=None, size=2048, target=0):
    """Bake the atlas, weight every part (weights[o["sock"]] is fn(point) -> {bone: w}), join them
    into one skinned "body" on a flat armature, keep `rigid` parts ({sock: (export name, joint)}) as
    separate meshes with their origin on the joint, export art/models/<name>.glb."""
    rigid = rigid or {}
    if target > 0:
        budget(objs, target)
    K.bake_atlas(objs, mats, name, os.path.join(ROOT, "art", "textures"), size)
    os.makedirs(os.path.join(ROOT, "art", "blender"), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "art", "blender", name + ".blend"))
    arm = armature(sockets)
    skinned, solo = [], {}
    for o in objs:
        if o["sock"] in rigid:
            solo.setdefault(o["sock"], []).append(o)
        else:
            weigh(o, weights[o["sock"]])
            skinned.append(o)
    bpy.ops.object.select_all(action='DESELECT')
    for o in skinned:
        o.select_set(True)
    bpy.context.view_layer.objects.active = skinned[0]
    bpy.ops.object.join()
    body = bpy.context.view_layer.objects.active
    body.name = "body"
    body.data.name = "body"
    body.parent = arm
    md = body.modifiers.new("Armature", 'ARMATURE')
    md.object = arm
    out = [arm, body]
    for sock, group in solo.items():
        bpy.ops.object.select_all(action='DESELECT')
        for o in group:
            o.select_set(True)
        bpy.context.view_layer.objects.active = group[0]
        if len(group) > 1:
            bpy.ops.object.join()
        ob = bpy.context.view_layer.objects.active
        nm, joint = rigid[sock]
        ob.name = nm
        ob.data.name = nm
        bpy.context.scene.cursor.location = joint
        bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
        ob.location = Vector((0, 0, 0))
        out.append(ob)
    bpy.ops.object.select_all(action='DESELECT')
    for o in out:
        o.select_set(True)
    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in out if o.type == 'MESH')
    path = os.path.join(ROOT, "art", "models", name + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True, export_apply=True,
                              export_yup=True, export_materials='NONE', export_normals=True, export_texcoords=True,
                              export_skins=True, export_animations=False, export_all_influences=False)
    print("EXPORTED", path, "tris", tris, "verts", len(body.data.vertices))


# --- export -----------------------------------------------------------------------------------------

def export(objs, mats, name, sockets, rename=None, size=2048, preview_path=""):
    """Bake the atlas (art/textures/<name>_*.png), keep the .blend, split per socket, export the GLB."""
    if preview_path:
        K.preview(preview_path, 0.9, 3.2)
    K.bake_atlas(objs, mats, name, os.path.join(ROOT, "art", "textures"), size)
    os.makedirs(os.path.join(ROOT, "art", "blender"), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "art", "blender", name + ".blend"))
    K.split_and_export(objs, os.path.join(ROOT, "art", "models", name + ".glb"), rename or {}, sockets)
