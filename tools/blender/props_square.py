"""The village square's clutter, modelled by script (replaces the code boxes of core/world/realm/site_props.gd).

  tools/blender/run.sh props_square.py -- [--only crate,barrel,...] [--preview DIR]

Revision 2: every prop is split into <part>__<set> meshes (timber / iron, plus a plain `water` for the trough) with metric
UVs (1 UV unit = tile metres, grain along each face's longest edge, exactly as r37_west.py), and the game dresses
the sets with art/textures/r37_<set>_{albedo,normal,orm}.png. Vertex colour is a TONE multiplier only (grime, moss at
the foot, rust). Burlap uses the new `cloth` set (r37_west_textures.py).

One glb per prop in art/models/props/, in GODOT metres, pivot at the base centre, y up, same size as the old box
builders so the swap is drop-in:
  crate.glb  crate_broken.glb     0.66 x 0.67 x 0.66
  barrel.glb barrel_tipped.glb    upright 0.85 tall, 0.63 across the belly (r 0.255 ends, 0.315 bulge); tipped lies on its side
  bench.glb                       1.5 x 0.34 x 0.475
  trough.glb                      1.3 x 0.45 x 0.46 (plank trough on trestle feet, iron straps)
  firewood.glb                    0.9 x 0.84 x 0.58 (3-2-1 stack, stakes at the corners)
  sack.glb (tied) sack_open.glb   lying 0.6 x 0.47 x 0.3 / standing 0.5 tall
  handcart.glb                    1.5 bed, 0.9 wide, wheels r 0.36, shafts lying on the ground out to x 1.85

Each glb holds the near mesh (one material "Prop", colours baked into COLOR_0 vertex colours: wood grain tone, grime,
moss at the foot, rust on the iron) and a `<name>-colonly` box for Godot's collision import. No far mesh: every
prop is under 700 triangles; let Godot's import LODs (or the MultiMesh visibility range) handle distance.

Authored in Godot coordinates (x right, y up, z back); mapped to Blender (x, -z, y) at the vertex, a proper rotation,
so the winding written here is the winding exported.
"""
import bpy
import bmesh
import math
import os
import sys
import random
from itertools import product
from mathutils import Vector, Matrix, noise

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art", "models", "props")
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ONLY = args[args.index("--only") + 1].split(",") if "--only" in args else []
PREVIEW = args[args.index("--preview") + 1] if "--preview" in args else ""
SHEETS = args[args.index("--sheets") + 1] if "--sheets" in args else ""


def B(g):
    return Vector((g[0], -g[2], g[1]))


def G(b):
    return Vector((b[0], b[2], -b[1]))


def V(x, y, z):
    return Vector((x, y, z))


def rotm(yaw=0.0, pitch=0.0, roll=0.0):
    return Matrix.Rotation(yaw, 3, 'Y') @ Matrix.Rotation(pitch, 3, 'X') @ Matrix.Rotation(roll, 3, 'Z')


def smooth(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a + 1e-9)))
    return t * t * (3 - 2 * t)


def fbm(p, octaves=3):
    a, f, s, n = 1.0, 1.0, 0.0, 0.0
    for _ in range(octaves):
        s += a * noise.noise(Vector(p) * f)
        n += a
        a *= 0.5
        f *= 2.0
    return s / n


WOOD, IRON, CLOTH, GRAIN, DARK, WATER = 0, 1, 2, 3, 4, 5      # face kinds: drive the finishing pass
KEY = {WOOD: 'timber', IRON: 'iron', CLOTH: 'cloth', GRAIN: 'timber', DARK: 'timber', WATER: 'water'}
MERGE = {}      # per model: sets folded into another so the game draws fewer surfaces (crate nails -> timber)
TILE = {'timber': 2.0, 'iron': 2.0, 'cloth': 2.0, 'water': 2.0}

CUBE = {
    '+x': [(1, 0, 0), (1, 1, 0), (1, 1, 1), (1, 0, 1)],
    '-x': [(0, 0, 0), (0, 0, 1), (0, 1, 1), (0, 1, 0)],
    '+y': [(0, 1, 0), (0, 1, 1), (1, 1, 1), (1, 1, 0)],
    '-y': [(0, 0, 0), (1, 0, 0), (1, 0, 1), (0, 0, 1)],
    '+z': [(0, 0, 1), (1, 0, 1), (1, 1, 1), (0, 1, 1)],
    '-z': [(0, 0, 0), (0, 1, 0), (1, 1, 0), (1, 0, 0)],
}


class P:
    """One prop under construction."""

    def __init__(self, seed):
        self.bm = bmesh.new()
        self.cl = self.bm.loops.layers.color.new("Col")
        self.kl = self.bm.faces.layers.int.new("kind")
        self.rng = random.Random(seed)

    def wood(self, tone="mid"):
        base = {"mid": (0.95, 0.88, 0.80), "pale": (1.0, 0.95, 0.86), "grey": (0.82, 0.82, 0.80),
                "dark": (0.62, 0.57, 0.52), "fresh": (1.0, 0.92, 0.78)}[tone]
        v = self.rng.uniform(0.84, 1.0)
        w = self.rng.uniform(-0.02, 0.02)
        return (base[0] * v + w, base[1] * v, base[2] * v - w)

    def iron(self):
        v = self.rng.uniform(0.8, 1.0)
        return (0.95 * v, 0.9 * v, 0.88 * v)

    def fc(self, vs, cols, kind, smooth_=False, out=None):
        """A face from bmesh verts; cols is one colour or one per vert. `out` is a point inside a convex piece:
        the winding is flipped if the face looks at it."""
        if not isinstance(cols[0], (tuple, list)):
            cols = [cols] * len(vs)
        if out is not None:
            pts = [G(v.co) for v in vs]
            cen = sum(pts, Vector()) / len(pts)
            nrm = Vector()
            for i in range(len(pts)):
                a, b = pts[i], pts[(i + 1) % len(pts)]
                nrm += Vector(((a.y - b.y) * (a.z + b.z), (a.z - b.z) * (a.x + b.x), (a.x - b.x) * (a.y + b.y)))
            if nrm.dot(cen - out) < 0:
                vs, cols = vs[::-1], cols[::-1]
        f = self.bm.faces.new(vs)
        f.smooth = smooth_
        f[self.kl] = kind
        for l, c in zip(f.loops, cols):
            l[self.cl] = (c[0], c[1], c[2], 1.0)
        return f

    def vt(self, g):
        return self.bm.verts.new(B(g))


def box(p, c, s, R=None, omit=(), col=None, cols=None, kind=WOOD, jit=0.0, taper=(1.0, 1.0), tone="mid"):
    """A box (size s) centred on c, rotated by R, faces named by local axis. taper scales the top face."""
    R = R if R is not None else Matrix.Identity(3)
    col = col or (p.iron() if kind == IRON else p.wood(tone))
    cols = cols or {}
    lv = {}
    for ix, iy, iz in product((0, 1), (0, 1), (0, 1)):
        tx, tz = taper if iy else (1.0, 1.0)
        loc = Vector(((ix - 0.5) * s[0] * tx, (iy - 0.5) * s[1], (iz - 0.5) * s[2] * tz))
        if jit:
            loc += Vector((p.rng.uniform(-jit, jit), p.rng.uniform(-jit, jit), p.rng.uniform(-jit, jit)))
        lv[(ix, iy, iz)] = p.vt(Vector(c) + R @ loc)
    for name, idx in CUBE.items():
        if name in omit:
            continue
        fcol = cols.get(name, col)
        m = p.rng.uniform(0.9, 1.08) if kind != DARK else 1.0
        fcol = (fcol[0] * m, fcol[1] * m, fcol[2] * m)
        p.fc([lv[i] for i in idx], fcol, kind)
    return lv


def ext(p, poly, depth, c, R=None, axis='z', col=None, cols=None, kind=WOOD, jit=0.0, omit=(), tone="mid"):
    """Extrude a 2D polygon (a, b) = (across, up) by `depth`. axis 'z': a=x, extrusion along z; axis 'x': a=z,
    extrusion along x. Faces: 'cap0', 'cap1', 'side<i>'."""
    R = R if R is not None else Matrix.Identity(3)
    area = sum(poly[i][0] * poly[(i + 1) % len(poly)][1] - poly[(i + 1) % len(poly)][0] * poly[i][1] for i in range(len(poly)))
    if area < 0:
        poly = poly[::-1]
    col = col or (p.iron() if kind == IRON else p.wood(tone))
    cols = cols or {}
    n = len(poly)
    rings = []
    for t in (-depth / 2, depth / 2):
        ring = []
        for a, b in poly:
            loc = Vector((a, b, t)) if axis == 'z' else Vector((t, b, a))
            if jit:
                loc += Vector((p.rng.uniform(-jit, jit), p.rng.uniform(-jit, jit), p.rng.uniform(-jit, jit)))
            ring.append(p.vt(Vector(c) + R @ loc))
        rings.append(ring)
    flip = axis != 'z'

    def put(name, vs):
        if name in omit:
            return
        fcol = cols.get(name, col)
        m = p.rng.uniform(0.95, 1.05)
        p.fc(vs[::-1] if flip else vs, (fcol[0] * m, fcol[1] * m, fcol[2] * m), kind)
    put('cap1', rings[1])
    put('cap0', rings[0][::-1])
    for i in range(n):
        j = (i + 1) % n
        put('side%d' % i, [rings[0][i], rings[0][j], rings[1][j], rings[1][i]])
    return rings


def nail(p, pos, nrm, r=0.011, h=0.009):
    """A nail head: a four-sided pyramid pointing along nrm."""
    nrm = Vector(nrm).normalized()
    t = nrm.cross(Vector((0, 1, 0)) if abs(nrm.y) < 0.9 else Vector((1, 0, 0))).normalized()
    u = nrm.cross(t)
    base = [Vector(pos) + (t * math.cos(a) + u * math.sin(a)) * r * 1.15 for a in (0.4, 0.4 + 2.094, 0.4 + 4.188)]
    bv = [p.vt(b) for b in base]
    ap = p.vt(Vector(pos) + nrm * h)
    c = p.iron()
    for i in range(3):
        p.fc([bv[i], bv[(i + 1) % 3], ap], c, IRON, out=Vector(pos) - nrm * 0.02)


def loft(p, rings, col, kind, smooth_=True, cap0=True, cap1=True, cap_cols=(None, None), ring_cols=None, facecol=None):
    """A tube through rings (lists of Godot points, same count). Winding by looking away from each ring pair's middle."""
    vr = [[p.vt(q) for q in r] for r in rings]
    n = len(rings[0])
    cen = [sum(r, Vector()) / len(r) for r in rings]
    for k in range(len(rings) - 1):
        mid = (cen[k] + cen[k + 1]) / 2
        for i in range(n):
            j = (i + 1) % n
            cc = col if ring_cols is None else ring_cols[k]
            if facecol is not None:
                cc = facecol(k, i)
            p.fc([vr[k][i], vr[k][j], vr[k + 1][j], vr[k + 1][i]], cc, kind, smooth_, out=mid)
    for flag, k, other in ((cap0, 0, 1), (cap1, len(rings) - 1, len(rings) - 2)):
        if not flag:
            continue
        cc = cap_cols[0 if k == 0 else 1] or col
        cv = p.vt(cen[k])
        for i in range(n):
            j = (i + 1) % n
            p.fc([vr[k][i], vr[k][j], cv], cc if not isinstance(cc, list) else cc, kind, smooth_, out=cen[other])
    return vr


# --- tone: the finishing pass over every baked colour ----------------------------------------------------
def tone(kind, co, n, c):
    """The macro tone multiplied on the tiling albedo: foot AO, damp, moss, dirt streaks, rust."""
    y = co.y
    if kind == DARK:
        return tuple(min(1.0, x * (0.8 + 0.3 * fbm(co * 9.0, 2))) for x in c)
    if kind == WATER:
        return c
    mott = 1.0 + 0.30 * fbm(co * 5.0 + Vector((3, 1, 5)), 3)
    ao = 0.5 + 0.5 * smooth(0.0, 0.17, y)
    r, g, b = c[0] * mott * ao, c[1] * mott * ao, c[2] * mott * ao
    streak = smooth(0.0, 0.5, fbm(Vector((co.x * 10.0, 0.0, co.z * 10.0)) + Vector((4, 0, 8)), 2)) * (1.0 - smooth(0.0, 0.7, y)) * (1.0 - abs(n.y)) * 0.35
    r, g, b = r * (1 - streak), g * (1 - streak), b * (1 - streak)
    if kind in (WOOD, CLOTH, GRAIN):
        moss = (1.0 - smooth(0.015, 0.13, y)) * smooth(-0.2, 0.45, fbm(co * 11.0 + Vector((9, 2, 4)), 3)) * 0.8
        r, g, b = r * (1 - moss) + 0.45 * moss, g * (1 - moss) + 0.62 * moss, b * (1 - moss) + 0.3 * moss
    elif kind == IRON:
        rs = smooth(0.0, 0.45, fbm(co * 12.0, 3) + 0.1)
        r, g, b = r * (1 - 0.4 * rs) + 0.95 * 0.4 * rs, g * (1 - 0.4 * rs) + 0.62 * 0.4 * rs, b * (1 - 0.4 * rs) + 0.4 * 0.4 * rs
    return (min(1.0, r), min(1.0, g), min(1.0, b))


def tri_count(objs):
    return sum(sum(len(q.vertices) - 2 for q in o.data.polygons) for o in objs)


def set_material(key):
    """Bare material (exported); the preview swaps in the textured one."""
    m = bpy.data.materials.get(key)
    if m is None:
        m = bpy.data.materials.new(key)
        m.use_nodes = True
        if key == "water":
            b = m.node_tree.nodes["Principled BSDF"]
            b.inputs["Base Color"].default_value = (0.02, 0.05, 0.06, 1)
            b.inputs["Roughness"].default_value = 0.08
    return m


def finish(p, name, col_box):
    """Split by set, write grain-aligned metric UVs and tone colours, make the -colonly box. -> (objs, col)."""
    bm = p.bm
    loose = [v for v in bm.verts if not v.link_faces]
    if loose:
        bmesh.ops.delete(bm, geom=loose, context='VERTS')
    bm.verts.index_update()
    bm.normal_update()
    out = {}
    for f in bm.faces:
        kind = f[p.kl]
        key = MERGE.get(KEY[kind], KEY[kind])
        if key not in out:
            nb = bmesh.new()
            out[key] = (nb, nb.loops.layers.uv.new("UVMap"), nb.loops.layers.color.new("Col"), {})
        nbm, uvl, cl, vmap = out[key]
        n = f.normal
        le = max(f.edges, key=lambda e: e.calc_length())
        d = (le.verts[1].co - le.verts[0].co).normalized()
        t1 = n.cross(d)
        grain = (t1.normalized(), d) if t1.length > 1e-6 else None
        vs = []
        for l in f.loops:
            if l.vert.index not in vmap:
                vmap[l.vert.index] = nbm.verts.new(l.vert.co)
            vs.append(vmap[l.vert.index])
        try:
            nf = nbm.faces.new(vs)
        except ValueError:
            continue
        nf.smooth = f.smooth
        tile = TILE[key]
        for l, nl in zip(f.loops, nf.loops):
            co = l.vert.co
            if grain is not None:
                nl[uvl].uv = (co.dot(grain[0]) / tile, co.dot(grain[1]) / tile)
            nn = l.vert.normal if f.smooth else n
            c = l[p.cl]
            t = tone(kind, G(co), G(nn), (c[0], c[1], c[2]))
            nl[cl] = (t[0], t[1], t[2], 1.0)
    bm.free()
    objs = []
    for key, (nbm, uvl, cl, vmap) in out.items():
        me = bpy.data.meshes.new("%s__%s" % (name, key))
        nbm.to_mesh(me)
        nbm.free()
        me.color_attributes.active_color = me.color_attributes["Col"]
        me.color_attributes.render_color_index = list(me.color_attributes.keys()).index("Col")
        me.materials.append(set_material(key))
        ob = bpy.data.objects.new("%s__%s" % (name, key), me)
        bpy.context.scene.collection.objects.link(ob)
        objs.append(ob)
    c, s = col_box
    cm = bpy.data.meshes.new(name + "-colonly")
    cb = bmesh.new()
    vs = {}
    for ix, iy, iz in product((0, 1), (0, 1), (0, 1)):
        vs[(ix, iy, iz)] = cb.verts.new(B(Vector(c) + Vector(((ix - 0.5) * s[0], (iy - 0.5) * s[1], (iz - 0.5) * s[2]))))
    for idx in CUBE.values():
        cb.faces.new([vs[i] for i in idx])
    cb.to_mesh(cm)
    cb.free()
    co_ = bpy.data.objects.new(name + "-colonly", cm)
    bpy.context.scene.collection.objects.link(co_)
    return objs, co_


def textured_material(key):
    """The game's tiling set from the PNGs: albedo x tone, normal, ORM (AO, roughness, metal)."""
    if key == "water":
        return set_material("water")
    m = bpy.data.materials.new("pv_" + key)
    m.use_nodes = True
    nt = m.node_tree
    nodes, links = nt.nodes, nt.links
    bsdf = nodes["Principled BSDF"]
    base = os.path.join(ROOT, "art", "textures", "r37_%s_" % key)

    def img(suffix, cs):
        n = nodes.new("ShaderNodeTexImage")
        n.image = bpy.data.images.load(base + suffix + ".png", check_existing=True)
        n.image.colorspace_settings.name = cs
        return n
    uvn = nodes.new("ShaderNodeUVMap")
    uvn.uv_map = "UVMap"
    al, nr, orm = img("albedo", "sRGB"), img("normal", "Non-Color"), img("orm", "Non-Color")
    mp = nodes.new("ShaderNodeMapping")        # props use the game's prop_mat: uv scale 3
    mp.inputs["Scale"].default_value = (3.0, 3.0, 3.0)
    links.new(uvn.outputs[0], mp.inputs[0])
    for t in (al, nr, orm):
        links.new(mp.outputs[0], t.inputs[0])
    vc = nodes.new("ShaderNodeVertexColor")
    vc.layer_name = "Col"
    mul = nodes.new("ShaderNodeMix")
    mul.data_type = 'RGBA'
    mul.blend_type = 'MULTIPLY'
    mul.inputs[0].default_value = 1.0
    links.new(al.outputs[0], mul.inputs[6])
    links.new(vc.outputs[0], mul.inputs[7])
    ao = nodes.new("ShaderNodeMix")
    ao.data_type = 'RGBA'
    ao.blend_type = 'MULTIPLY'
    ao.inputs[0].default_value = 1.0
    links.new(mul.outputs[2], ao.inputs[6])
    links.new(orm.outputs[0], ao.inputs[7])
    links.new(ao.outputs[2], bsdf.inputs["Base Color"])
    sep = nodes.new("ShaderNodeSeparateColor")
    links.new(orm.outputs[0], sep.inputs[0])
    links.new(sep.outputs[1], bsdf.inputs["Roughness"])
    if key == "iron":
        links.new(sep.outputs[2], bsdf.inputs["Metallic"])
    nm = nodes.new("ShaderNodeNormalMap")
    nm.inputs["Strength"].default_value = 0.35      # prop_mat: normal_scale 0.35 of the set's
    links.new(nr.outputs[0], nm.inputs["Color"])
    links.new(nm.outputs[0], bsdf.inputs["Normal"])
    return m


# =========================================================================================================
# the props
# =========================================================================================================
def build_crate(broken=False):
    p = P(11 if not broken else 12)
    rng = p.rng
    dark = (0.045, 0.035, 0.03)
    POST_H, W = 0.60, 0.295
    # --- the body behind the slats (dark, so the gaps read as shadow)
    if not broken:
        box(p, V(0, 0.30, 0), (0.56, 0.58, 0.56), omit=('-y', '+y'), col=dark, kind=DARK)
    else:
        box(p, V(0, 0.30, 0), (0.56, 0.58, 0.56), omit=('-y', '+y', '+x', '-x', '+z', '-z'), col=dark, kind=DARK)
        box(p, V(0, 0.07, 0), (0.56, 0.02, 0.56), omit=('-y', '+x', '-x', '+z', '-z'), col=(0.13, 0.1, 0.07), kind=DARK)
    # --- corner posts
    for sx, sz in product((-1, 1), (-1, 1)):
        if broken and sx == -1 and sz == 1:
            ext(p, [(-0.035, 0.0), (0.035, 0.0), (0.035, 0.37), (0.014, 0.45), (0.0, 0.34), (-0.016, 0.50), (-0.035, 0.40)],
                0.07, V(sx * W, 0.0, sz * W), kind=WOOD, tone="dark", omit=('side0',))
        else:
            box(p, V(sx * W, POST_H / 2, sz * W), (0.07, POST_H, 0.07), omit=('-y',), tone="dark", jit=0.004)
    # --- slats: three a face, each a little off true
    for fi in range(4):
        yaw = fi * math.pi / 2
        R0 = rotm(yaw)
        for row in range(3):
            if broken and fi == 0 and row == 2:
                continue                                     # the top slat of the front is gone
            y = 0.105 + row * 0.2 + rng.uniform(-0.006, 0.006)
            ln = 0.52
            ang = rng.uniform(-0.012, 0.012)
            ctr = Vector((0, y, 0.295))
            Rl = rotm(0, 0, ang)
            tone_ = "pale" if rng.random() < 0.3 else "mid"
            if broken and fi == 0 and row == 1:              # hangs by one nail, dropped at the left
                ang = -0.42
                piv = Vector((0.25, y, 0.295))
                ctr = piv + rotm(0, 0, ang) @ Vector((-ln / 2, 0, 0))
                Rl = rotm(0, 0, ang)
            if broken and fi == 3 and row == 0:              # a short, split board
                ln = 0.31
                ctr = Vector((-0.105, y, 0.295))
            omit = () if broken else ('-z',)
            box(p, R0 @ ctr, (ln, 0.18 + rng.uniform(-0.006, 0.004), 0.03), R0 @ Rl, omit=omit, tone=tone_, jit=0.003)
            if not broken or not (fi == 0 and row == 1):
                for sx in (-1, 1):
                    if rng.random() < 0.6 and ln > 0.4:
                        nail(p, R0 @ Vector((sx * 0.235, y, 0.31)), R0 @ Vector((0, 0, 1)))
    # --- the lid
    LY = POST_H + 0.02
    for i, x in enumerate((-0.225, 0.0, 0.225)):
        if broken and i == 2:
            continue                                         # gone
        tn = "pale" if i == 1 else "mid"
        if broken and i == 1:
            box(p, V(x, LY, -0.165), (0.215, 0.04, 0.33), omit=(), tone=tn, jit=0.004)
            a = 0.62
            hinge = V(x, LY, 0.0)
            box(p, hinge + rotm(0, a, 0) @ V(0, 0, 0.165), (0.215, 0.04, 0.33), rotm(0, a, 0), tone=tn, jit=0.004)
        else:
            box(p, V(x, LY, 0), (0.215, 0.04, 0.66), omit=() if broken else ('-y',), tone=tn, jit=0.004)
    for z in (-0.21, 0.21):
        if broken:
            ln = 0.44 if z > 0 else 0.5
            box(p, V(-0.33 + ln / 2, LY + 0.032, z), (ln, 0.03, 0.07), rotm(0.02 if z > 0 else -0.015), tone="grey", jit=0.003)
        else:
            box(p, V(0, LY + 0.032, z), (0.66, 0.03, 0.07), omit=('-y',), tone="grey", jit=0.003)
        xs = (-0.225, 0.0, 0.225) if not broken else (-0.225, 0.0)
        for x in xs:
            nail(p, V(x, LY + 0.049, z), V(0, 1, 0))
    return finish(p, "crate_broken" if broken else "crate", (V(0, 0.335, 0), (0.66, 0.67, 0.66)))


BARREL_H = 0.85


def barrel_r(t):
    return 0.255 + 0.06 * (1.0 - (2 * t - 1) ** 2)


def build_barrel(tipped=False):
    p = P(21 if not tipped else 22)
    rng = p.rng
    seg = 16
    h = BARREL_H
    ts = [0.0, 0.06, 0.27, 0.5, 0.73, 0.94, 1.0]
    if tipped:
        def X(q):
            q = Vector(q) - V(0, h / 2, 0)
            return rotm(0.5) @ (Matrix.Rotation(-math.pi / 2, 3, 'Z') @ q) + V(0, 0.317, 0)
    else:
        def X(q):
            return Vector(q)
    th = [2 * math.pi * i / seg + rng.uniform(-0.02, 0.02) for i in range(seg)]
    jr = [rng.uniform(-0.003, 0.003) for _ in range(seg)]

    def pt(i, t, off=0.0, y=None):
        r = barrel_r(t) + jr[i] + off
        return X(V(r * math.cos(th[i]), t * h if y is None else y, r * math.sin(th[i])))
    stave = [p.wood("pale" if rng.random() < 0.2 else "mid") for _ in range(seg)]
    center = X(V(0, h / 2, 0))
    rings = [[p.vt(pt(i, t)) for i in range(seg)] for t in ts]
    for k in range(len(ts) - 1):
        for i in range(seg):
            j = (i + 1) % seg
            m = 1.0 + 0.03 * ((k * 7 + i * 3) % 5 - 2)
            c = stave[i]
            p.fc([rings[k][i], rings[k][j], rings[k + 1][j], rings[k + 1][i]], (c[0] * m, c[1] * m, c[2] * m), WOOD, True, out=center)
    # the head: a lip, then the lid (or, knocked out, the inner wall and the dark inside)
    lipin = 0.025
    lo = [p.vt(pt(i, 1.0)) for i in range(seg)]
    li = [p.vt(pt(i, 1.0, off=-lipin)) for i in range(seg)]
    for i in range(seg):
        j = (i + 1) % seg
        p.fc([lo[i], lo[j], li[j], li[i]], p.wood("pale"), WOOD, out=center)
    if tipped:
        depth = 0.12
        wl = [p.vt(pt(i, 1.0, off=-lipin)) for i in range(seg)]
        wi = [p.vt(pt(i, 1.0, off=-lipin, y=h - depth)) for i in range(seg)]
        ax_mid = X(V(0, h - depth * 0.5, 0))
        for i in range(seg):
            j = (i + 1) % seg
            quad = [wl[i], wi[i], wi[j], wl[j]]
            cen = sum((G(v.co) for v in quad), Vector()) / 4
            p.fc(quad, (0.14, 0.1, 0.07), DARK, False, out=cen + (cen - ax_mid))
        hc = p.vt(X(V(0, h - depth, 0)))
        for i in range(seg):
            j = (i + 1) % seg
            p.fc([wi[i], wi[j], hc], (0.07, 0.05, 0.04), DARK, out=X(V(0, h - 2 * depth - 0.1, 0)))
        bo = [p.vt(pt(i, 0.0)) for i in range(seg)]
        cv = p.vt(X(V(0, 0.0, 0)))
        for i in range(seg):
            j = (i + 1) % seg
            p.fc([bo[i], bo[j], cv], p.wood("grey"), WOOD, out=X(V(0, h * 0.5, 0)))
    else:
        cv = p.vt(X(V(0, h - 0.02, 0)))
        for i in range(seg):
            j = (i + 1) % seg
            shade = 0.9 + 0.12 * math.sin(th[i] * 3.0)
            c = p.wood("grey")
            p.fc([li[i], li[j], cv], (c[0] * shade, c[1] * shade, c[2] * shade), WOOD, out=X(V(0, h - 0.2, 0)))
    # iron hoops: a band standing 12 mm off the staves, smooth round
    off = 0.012
    spans = ((0.07, 0.15), (0.85, 0.93), (0.27, 0.34)) if tipped else ((0.06, 0.14), (0.24, 0.31), (0.69, 0.76), (0.86, 0.94))
    for (ta, tb) in spans:
        ra = [p.vt(pt(i, ta, off=off)) for i in range(seg)]
        rb = [p.vt(pt(i, tb, off=off)) for i in range(seg)]
        c = p.iron()
        for i in range(seg):
            j = (i + 1) % seg
            m = 1.0 + 0.06 * ((i * 5) % 3 - 1)
            p.fc([ra[i], ra[j], rb[j], rb[i]], (c[0] * m, c[1] * m, c[2] * m), IRON, True, out=center)
    if tipped:
        return finish(p, "barrel_tipped", (V(0, 0.317, 0), (0.86, 0.64, 0.66)))
    return finish(p, "barrel", (V(0, h / 2, 0), (0.63, h, 0.63)))


def build_bench():
    p = P(31)
    rng = p.rng
    T, SY = 0.07, 0.405
    ch = 0.012
    for z in (-0.0865, 0.0865):
        w = 0.165
        poly = [(-w / 2, 0), (w / 2, 0), (w / 2, T - ch), (w / 2 - ch, T), (-w / 2 + ch, T), (-w / 2, T - ch)]
        ext(p, poly, 1.5, V(0, SY, z), axis='x', omit=('side0',), jit=0.003, tone="pale" if z > 0 else "mid")
    # trestle ends: an arched slab
    leg = [(-0.15, 0.0), (-0.105, 0.0), (-0.07, 0.115), (0.07, 0.115), (0.105, 0.0), (0.15, 0.0), (0.14, SY), (-0.14, SY)]
    for sx in (-0.6, 0.6):
        ext(p, leg, 0.08, V(sx, 0.0, 0), rotm(math.pi / 2), axis='z', omit=('side0', 'side4'), jit=0.002, tone="dark")
    # long rail through the legs, tenons showing
    box(p, V(0, 0.285, 0), (1.30, 0.045, 0.05), jit=0.003, tone="grey")
    for sx in (-1, 1):
        box(p, V(sx * 0.665, 0.285, 0), (0.025, 0.07, 0.022), tone="pale")           # the wedge
    # aprons under the seat
    for z in (-0.12, 0.12):
        box(p, V(0, SY - 0.045, z), (1.18, 0.07, 0.03), omit=('-y',), tone="grey", jit=0.003)
    for sx in (-1, 1):
        for z in (-0.0865, 0.0865):
            nail(p, V(sx * 0.68, SY + T + 0.0, z), V(0, 1, 0), r=0.012)
    return finish(p, "bench", (V(0, 0.2375, 0), (1.5, 0.475, 0.34)))


def build_trough():
    p = P(41)
    rng = p.rng
    wet = (0.15, 0.13, 0.095)
    # feet: arched trestles
    foot = [(-0.25, 0.0), (-0.18, 0.0), (-0.14, 0.06), (0.14, 0.06), (0.18, 0.0), (0.25, 0.0), (0.22, 0.13), (-0.22, 0.13)]
    for sx in (-0.55, 0.55):
        ext(p, foot, 0.09, V(sx, 0.0, 0), axis='x', omit=('side0', 'side4'), jit=0.002, tone="dark")
    # the floor board
    box(p, V(0, 0.125, 0), (1.3, 0.05, 0.43), cols={'+y': wet}, tone="grey", jit=0.003)
    # sides: two planks a side, leaning out a little
    for side in (-1, 1):
        lean = 0.1 * side
        for row, yc in enumerate((0.225, 0.385)):
            for_pitch = lean
            cy = yc
            inner = '-z' if side > 0 else '+z'
            cz = side * (0.19 + 0.1 * (cy - 0.30))
            box(p, V(0, cy, cz), (1.3, 0.15, 0.05), rotm(0, for_pitch, 0), cols={inner: wet}, tone="grey" if row == 0 else "mid", jit=0.004)
    # ends: a tall board, set in
    for sx in (-1, 1):
        box(p, V(sx * 0.625, 0.305, 0), (0.05, 0.32, 0.40), cols={('-x' if sx > 0 else '+x'): wet}, tone="dark", jit=0.003)
    # iron straps round the sides and under
    for sx in (-0.38, 0.38):
        box(p, V(sx, 0.095, 0), (0.05, 0.016, 0.46), kind=IRON, jit=0.001)
        for side in (-1, 1):
            lean = 0.1 * side
            box(p, V(sx, 0.31, side * 0.225), (0.05, 0.35, 0.014), rotm(0, lean, 0), kind=IRON, jit=0.001)
            nail(p, V(sx, 0.40, side * 0.235), V(0, 0.1 * side, side), r=0.012)
            nail(p, V(sx, 0.22, side * 0.222), V(0, 0.1 * side, side), r=0.012)
    # dark water, a hand below the rim
    wy = 0.385
    wv = [p.vt(V(x, wy, z)) for x, z in ((-0.6, -0.15), (0.6, -0.15), (0.6, 0.15), (-0.6, 0.15))]
    p.fc(wv, (0.02, 0.05, 0.06), WATER, out=V(0, wy - 0.1, 0))
    return finish(p, "trough", (V(0, 0.23, 0), (1.3, 0.46, 0.46)))


def build_firewood():
    p = P(51)
    rng = p.rng
    segs = 7
    logs = [(-0.375, 0.118), (-0.125, 0.118), (0.125, 0.118), (0.375, 0.118),
            (-0.25, 0.323), (0.0, 0.323), (0.25, 0.323), (0.125, 0.528)]
    for (x, y) in logs:
        r = rng.uniform(0.105, 0.122)
        ln = rng.uniform(0.78, 0.88)
        R = rotm(rng.uniform(-0.04, 0.04), rng.uniform(-0.02, 0.02), 0)
        bark = p.wood("dark" if rng.random() < 0.5 else "grey")
        cen = V(x + rng.uniform(-0.01, 0.01), y, rng.uniform(-0.03, 0.03))
        rot0 = rng.uniform(0, 6.28)
        ang = [rot0 + 2 * math.pi * i / segs for i in range(segs)]
        rr = [r * rng.uniform(0.9, 1.06) for _ in range(segs)]

        def at(i, z, k=1.0):
            return cen + R @ V(rr[i] * k * math.cos(ang[i]), rr[i] * k * math.sin(ang[i]), z)
        e0 = [p.vt(at(i, -ln / 2)) for i in range(segs)]
        e1 = [p.vt(at(i, ln / 2)) for i in range(segs)]
        for i in range(segs):
            j = (i + 1) % segs
            m = rng.uniform(0.85, 1.05)
            p.fc([e0[i], e0[j], e1[j], e1[i]], (bark[0] * m, bark[1] * m, bark[2] * m), WOOD, True, out=cen)
        # the sawn ends: a dark heart inside a pale sap ring, the front one ringed
        zf = ln / 2 + 0.003
        outer = [p.vt(at(i, zf)) for i in range(segs)]
        inner = [p.vt(at(i, zf + 0.002, 0.52)) for i in range(segs)]
        for i in range(segs):
            j = (i + 1) % segs
            p.fc([outer[i], outer[j], inner[j], inner[i]], (1.0, 0.84, 0.6), GRAIN, out=cen)
        hv = p.vt(cen + R @ V(rng.uniform(-0.01, 0.01), rng.uniform(-0.01, 0.01), zf + 0.004))
        for i in range(segs):
            j = (i + 1) % segs
            p.fc([inner[i], inner[j], hv], (0.72, 0.5, 0.32), GRAIN, out=cen)
        bo = [p.vt(at(i, -ln / 2 - 0.003)) for i in range(segs)]
        bc = p.vt(cen + R @ V(0, 0, -ln / 2 - 0.006))
        for i in range(segs):
            j = (i + 1) % segs
            p.fc([bo[i], bo[j], bc], (0.88, 0.72, 0.52), GRAIN, out=cen)
    for sx, sz in product((-1, 1), (-1, 1)):
        box(p, V(sx * 0.545, 0.31, sz * 0.31), (0.065, 0.62, 0.06), omit=('-y',), tone="dark", jit=0.004,
            R=rotm(0, 0.0, -sx * 0.025))
    return finish(p, "firewood", (V(0, 0.33, 0), (1.14, 0.66, 0.92)))


def build_sack(open_=False):
    p = P(61 if not open_ else 62)
    rng = p.rng
    cloth = (1.0, 0.88, 0.66)
    patch = (0.62, 0.5, 0.36)
    cord = (0.5, 0.38, 0.25)

    def wob(q, c, amp, fr):
        """crumple a point about its ring centre: burlap never holds a clean curve"""
        return c + (q - c) * (1.0 + amp * fbm(q * fr + Vector((5, 2, 7)), 2))
    if not open_:
        # standing, slumped, the neck gathered in pleats and bound with cord, a frill above
        seg = 10
        spec = [(0.0, 0.20, 0.17), (0.04, 0.245, 0.205), (0.14, 0.255, 0.215), (0.25, 0.215, 0.18), (0.33, 0.13, 0.11),
                (0.385, 0.062, 0.055), (0.425, 0.058, 0.052), (0.47, 0.12, 0.105), (0.52, 0.145, 0.125)]
        rings = []
        for ki, (y, rx, rz) in enumerate(spec):
            lean = 0.09 * (y / 0.5) ** 2
            ring = []
            pl = 0.0 if ki < 4 else (0.18 if ki < 7 else 0.3)
            for i in range(seg):
                a = 2 * math.pi * i / seg + 0.2
                m = 1.0 + pl * math.sin(5 * a + ki * 0.3)
                q = V(lean + rx * m * math.cos(a), y, rz * m * math.sin(a))
                q = wob(q, V(lean, y, 0), 0.22 if ki < 4 else 0.08, 9.0)
                if ki == 0:
                    q.y = 0.0
                ring.append(q)
            rings.append(ring)

        def fcol(k, i):
            m = rng.uniform(0.88, 1.0)
            base = patch if (k in (1, 2) and i in (6, 7)) else cloth
            if k >= 4:
                base = (0.92, 0.8, 0.6)
            return (base[0] * m, base[1] * m, base[2] * m)
        loft(p, rings, cloth, CLOTH, True, False, False, facecol=fcol)
        top = [p.vt(q) for q in rings[-1]]
        tc = p.vt(sum(rings[-1], Vector()) / seg + V(0, -0.025, 0))
        for i in range(seg):
            j = (i + 1) % seg
            p.fc([top[i], top[j], tc], (0.55, 0.45, 0.32), CLOTH, True, out=V(0.1, 0.1, 0))
        cen = sum(rings[5], Vector()) / seg
        cr = [cen + (q - cen) * 1.3 + V(0, 0.016, 0) for q in rings[5]]
        cr2 = [cen + (q - cen) * 1.3 - V(0, 0.016, 0) for q in rings[5]]
        loft(p, [cr2, cr], cord, CLOTH, True, False, False)
        return finish(p, "sack", (V(0.04, 0.26, 0.0), (0.52, 0.52, 0.44)))
    # standing, slumped, the mouth rolled down, grain showing
    seg = 9
    spec = [(0.0, 0.17, 0.15), (0.03, 0.235, 0.20), (0.12, 0.245, 0.215), (0.24, 0.215, 0.19), (0.34, 0.185, 0.165),
            (0.40, 0.205, 0.185), (0.45, 0.23, 0.21)]
    rings = []
    for ki, (y, rx, rz) in enumerate(spec):
        lean = 0.10 * (y / 0.45) ** 2
        ring = []
        for i in range(seg):
            a = 2 * math.pi * i / seg + 0.3
            ex = 1.0 + 0.1 * math.sin(3 * a + y * 9)
            q = V(lean + rx * ex * math.cos(a), y, rz * ex * math.sin(a))
            if ki == len(spec) - 1:
                q.y += 0.035 * math.sin(a * 1.0 + 0.7) + rng.uniform(-0.008, 0.008)
            q = wob(q, V(lean, y, 0), 0.22, 9.0)
            q.y = max(q.y, 0.0) if ki > 0 else 0.0
            ring.append(q)
        rings.append(ring)

    def fcol(k, i):
        m = rng.uniform(0.88, 1.0)
        base = patch if (k in (2, 3) and i in (5, 6)) else cloth
        if k >= 4:
            base = (0.92, 0.8, 0.6)
        return (base[0] * m, base[1] * m, base[2] * m)
    loft(p, rings, cloth, CLOTH, True, False, False, facecol=fcol)
    top = rings[-1]
    lean = 0.10
    inner = []
    for i in range(seg):
        a = 2 * math.pi * i / seg + 0.3
        inner.append(V(lean + 0.17 * math.cos(a), top[i].y - 0.045, 0.15 * math.sin(a)))
    vt_top = [p.vt(q) for q in top]
    vt_in = [p.vt(q) for q in inner]
    for i in range(seg):
        j = (i + 1) % seg
        p.fc([vt_top[i], vt_top[j], vt_in[j], vt_in[i]], (0.8, 0.68, 0.5), CLOTH, True, out=V(lean, 0.2, 0))
    gv = [p.vt(V(q.x, q.y - 0.02, q.z)) for q in inner]
    for i in range(seg):
        j = (i + 1) % seg
        p.fc([vt_in[i], vt_in[j], gv[j], gv[i]], (0.25, 0.2, 0.12), DARK, False, out=V(lean, 0.2, 0))
    peak = p.vt(V(lean + 0.01, 0.46, 0.0))
    for i in range(seg):
        j = (i + 1) % seg
        p.fc([gv[i], gv[j], peak], [(1.0, 0.85, 0.45), (1.0, 0.85, 0.45), (1.0, 0.92, 0.6)], GRAIN, False, out=V(lean, 0.2, 0))
    sp = []
    for i in range(7):
        a = 2 * math.pi * i / 7
        sp.append(p.vt(V(0.2 + 0.11 * math.cos(a), 0.0, 0.17 + 0.07 * math.sin(a))))
    top_ = p.vt(V(0.2, 0.03, 0.17))
    for i in range(7):
        j = (i + 1) % 7
        p.fc([sp[i], sp[j], top_], [(0.8, 0.65, 0.35), (0.8, 0.65, 0.35), (1.0, 0.85, 0.45)], GRAIN, False, out=V(0.2, -0.1, 0.17))
    return finish(p, "sack_open", (V(0.07, 0.24, 0.0), (0.58, 0.5, 0.46)))


def wheel(p, cx, cy, cz, flipz, N=10, nsp=8):
    """A spoked wheel in the XY plane at z=cz: iron tyre, felloes, spokes, hub."""
    s = flipz
    ang0 = p.rng.uniform(0, 0.6)

    def ringv(r, z, a_off=0.0):
        return [p.vt(V(cx + r * math.cos(a_off + 2 * math.pi * i / N), cy + r * math.sin(a_off + 2 * math.pi * i / N), cz + z)) for i in range(N)]
    cen = V(cx, cy, cz)
    # tyre (outer + both sides)
    t_out_a, t_out_b = ringv(0.362, -0.04, ang0), ringv(0.362, 0.04, ang0)
    t_in_a, t_in_b = ringv(0.318, -0.04, ang0), ringv(0.318, 0.04, ang0)
    ic = p.iron()
    s_out_a, s_out_b = ringv(0.362, -0.04, ang0), ringv(0.362, 0.04, ang0)
    for i in range(N):
        j = (i + 1) % N
        m = p.rng.uniform(0.9, 1.1)
        c = (ic[0] * m, ic[1] * m, ic[2] * m)
        p.fc([t_out_a[i], t_out_a[j], t_out_b[j], t_out_b[i]], c, IRON, True, out=cen)
        p.fc([s_out_a[i], t_in_a[i], t_in_a[j], s_out_a[j]], c, IRON, out=cen)
        p.fc([s_out_b[i], s_out_b[j], t_in_b[j], t_in_b[i]], c, IRON, out=cen)
    # felloes (wood): the inner face and both sides, set back of the tyre
    f_a, f_b = ringv(0.268, -0.032, ang0 + 0.02), ringv(0.268, 0.032, ang0 + 0.02)
    t_a2, t_b2 = ringv(0.318, -0.032, ang0 + 0.02), ringv(0.318, 0.032, ang0 + 0.02)
    for i in range(N):
        j = (i + 1) % N
        wc = p.wood("pale" if i % 2 else "mid")
        mc = V(cx + 0.29 * math.cos(ang0 + 2 * math.pi * (i + 0.5) / N), cy + 0.29 * math.sin(ang0 + 2 * math.pi * (i + 0.5) / N), cz)
        cin = cen + (mc - cen) * 2.0
        p.fc([f_a[i], f_b[i], f_b[j], f_a[j]], wc, WOOD, out=cin)
        p.fc([f_a[i], f_a[j], t_a2[j], t_a2[i]], wc, WOOD, out=cen + V(0, 0, 0.1))
        p.fc([f_b[i], t_b2[i], t_b2[j], f_b[j]], wc, WOOD, out=cen - V(0, 0, 0.1))
    # spokes
    hubr = 0.07
    for k in range(nsp):
        a = ang0 + 2 * math.pi * k / nsp
        d = V(math.cos(a), math.sin(a), 0)
        n_ = V(-math.sin(a), math.cos(a), 0)
        r0, r1 = 0.055, 0.285
        w0, w1 = 0.022, 0.017
        zt = 0.016
        pts = {}
        for (rr, ww, zz, nm) in ((r0, w0, -zt, 'a0'), (r0, -w0, -zt, 'b0'), (r1, w1, -zt, 'a1'), (r1, -w1, -zt, 'b1'),
                                 (r0, w0, zt, 'c0'), (r0, -w0, zt, 'd0'), (r1, w1, zt, 'c1'), (r1, -w1, zt, 'd1')):
            pts[nm] = p.vt(cen + d * rr + n_ * ww + V(0, 0, zz))
        sc = p.wood("grey")
        for (q0, q1, q2, q3) in (('a0', 'a1', 'b1', 'b0'), ('c0', 'd0', 'd1', 'c1'), ('a0', 'c0', 'c1', 'a1'), ('b0', 'b1', 'd1', 'd0')):
            p.fc([pts[q0], pts[q1], pts[q2], pts[q3]], sc, WOOD, out=cen + d * 0.17)
    # hub: eight-sided barrel, long on the outer side
    h0, h1 = (-0.03, 0.085) if s > 0 else (-0.085, 0.03)
    ha, hb = [], []
    for i in range(8):
        a = ang0 + 2 * math.pi * i / 8
        ha.append(p.vt(V(cx + hubr * math.cos(a), cy + hubr * math.sin(a), cz + h0)))
        hb.append(p.vt(V(cx + hubr * math.cos(a), cy + hubr * math.sin(a), cz + h1)))
    hc = p.wood("dark")
    hcen = V(cx, cy, cz + (h0 + h1) / 2)
    for i in range(8):
        j = (i + 1) % 8
        p.fc([ha[i], ha[j], hb[j], hb[i]], hc, WOOD, out=hcen)
    outer = hb if s > 0 else ha
    oz = h1 if s > 0 else h0
    cv = p.vt(V(cx, cy, cz + oz + (0.012 if s > 0 else -0.012)))
    ic = p.iron()
    for i in range(8):
        j = (i + 1) % 8
        p.fc([outer[i], outer[j], cv], ic, IRON, out=hcen)


def build_cart():
    p = P(71)
    rng = p.rng
    # floor boards
    for z in (-0.3, 0.0, 0.3):
        box(p, V(0, 0.55, z), (1.5, 0.06, 0.298), tone="grey", jit=0.003, omit=('-y',))
    # side walls: two planks, stakes outside
    for sz in (-1, 1):
        for y, hh in ((0.665, 0.16), (0.84, 0.14)):
            inner = '-z' if sz > 0 else '+z'
            box(p, V(0, y, sz * 0.42), (1.5, hh, 0.04), tone="pale" if y > 0.7 else "mid", jit=0.003)
        for sx in (-0.7, 0.0, 0.7):
            box(p, V(sx, 0.745, sz * 0.462), (0.06, 0.40, 0.04), omit=('-y',), tone="dark", jit=0.003)
    # back (x -) and the low front board
    for y, hh in ((0.665, 0.16), (0.84, 0.14)):
        box(p, V(-0.73, y, 0), (0.04, hh, 0.84), tone="mid", jit=0.003, omit=('-y',) if y < 0.7 else ())
    box(p, V(0.73, 0.65, 0), (0.04, 0.12, 0.84), tone="grey", jit=0.003)
    # under-frame: the shaft rails run under the bed and out to the ground
    ang = -math.atan2(0.38, 1.17)
    ln = math.hypot(1.17, 0.38)
    for sz in (-1, 1):
        z = sz * 0.30
        box(p, V(-0.035, 0.485, z), (1.43, 0.07, 0.065), tone="dark", jit=0.003)
        box(p, V(1.265, 0.30, z), (ln, 0.065, 0.06), rotm(0, 0, ang), tone="dark", jit=0.003)
        # the grip: a fatter end
        box(p, V(1.77, 0.135, z), (0.2, 0.08, 0.08), rotm(0, 0, ang), tone="pale", jit=0.002)
        box(p, V(-0.1, 0.43, z), (0.12, 0.1, 0.1), omit=('-y', '+y'), tone="dark")      # axle bracket
    box(p, V(1.55, 0.208, 0.0), (0.045, 0.045, 0.66), rotm(0, 0, ang), tone="grey", jit=0.002)    # pulling bar
    # axle
    box(p, V(-0.1, 0.36, 0), (0.06, 0.06, 1.2), tone="dark", omit=('+z', '-z'))
    # wheels
    wheel(p, -0.1, 0.36, 0.545, 1)
    wheel(p, -0.1, 0.36, -0.545, -1)

    return finish(p, "handcart", (V(-0.05, 0.46, 0.0), (1.6, 0.92, 1.18)))


# =========================================================================================================
# export + preview
# =========================================================================================================
def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def export(objs, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    kw = dict(filepath=path, export_format='GLB', use_selection=True, export_apply=True, export_yup=True,
              export_materials='EXPORT', export_image_format='NONE', export_normals=True)
    try:
        bpy.ops.export_scene.gltf(export_vertex_color='ACTIVE', export_active_vertex_color_when_no_material=True, **kw)
    except TypeError:
        try:
            bpy.ops.export_scene.gltf(export_vertex_color='ACTIVE', **kw)
        except TypeError:
            bpy.ops.export_scene.gltf(**kw)


def bounds(objs):
    pts = [G(o.matrix_world @ Vector(c)) for o in objs for c in o.bound_box]
    lo = Vector((min(q.x for q in pts), min(q.y for q in pts), min(q.z for q in pts)))
    hi = Vector((max(q.x for q in pts), max(q.y for q in pts), max(q.z for q in pts)))
    return lo, hi


def render_set(ob, label, focus):
    for o in ob:
        o.data.materials[0] = textured_material(o.name.split('__')[-1])
    """Eight renders: 4 views x (neutral, night)."""
    sc = bpy.context.scene
    os.makedirs(PREVIEW, exist_ok=True)
    try:
        sc.render.engine = 'BLENDER_EEVEE'
    except TypeError:
        sc.render.engine = 'BLENDER_WORKBENCH'
    sc.render.resolution_x = sc.render.resolution_y = 960
    sc.view_settings.view_transform = 'Standard'
    lo, hi = bounds(ob)
    ctr = (lo + hi) / 2
    rad = max((hi - lo).length / 2, 0.3)
    # a ground disc
    bpy.ops.mesh.primitive_circle_add(vertices=48, radius=rad * 3.2, fill_type='NGON', location=B(V(ctr.x, 0.0, ctr.z)))
    gr = bpy.context.object
    gm = bpy.data.materials.new("ground")
    gm.use_nodes = True
    gb = gm.node_tree.nodes["Principled BSDF"]
    gr.data.materials.append(gm)
    cam_d = bpy.data.cameras.new("cam")
    cam = bpy.data.objects.new("cam", cam_d)
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam_d.lens = 60
    cam_d.clip_end = 100
    d = rad * 3.4
    views = [
        ("front", ctr, d, 0.0, 12.0),
        ("three", ctr, d, 40.0, 26.0),
        ("side", ctr, d, 90.0, 12.0),
        ("close", focus, d * 0.5, -35.0, 28.0),
    ]
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    sc.world = world
    bg = world.node_tree.nodes["Background"]
    sun_d = bpy.data.lights.new("sun", 'SUN')
    sun = bpy.data.objects.new("sun", sun_d)
    sc.collection.objects.link(sun)
    fill_d = bpy.data.lights.new("fire", 'POINT')
    fill = bpy.data.objects.new("fire", fill_d)
    sc.collection.objects.link(fill)
    for mode in ("neutral", "night"):
        if mode == "neutral":
            gb.inputs[0].default_value = (0.28, 0.26, 0.23, 1)
            bg.inputs[0].default_value = (0.55, 0.57, 0.6, 1)
            bg.inputs[1].default_value = 1.0
            sun_d.energy, sun_d.color = 3.0, (1.0, 0.97, 0.92)
            sun.rotation_euler = (math.radians(50), 0, math.radians(35))
            fill_d.energy = 0
        else:
            gb.inputs[0].default_value = (0.1, 0.09, 0.08, 1)
            bg.inputs[0].default_value = (0.03, 0.045, 0.12, 1)
            bg.inputs[1].default_value = 1.0
            sun_d.energy, sun_d.color = 2.4, (0.42, 0.52, 1.0)
            sun.rotation_euler = (math.radians(58), 0, math.radians(-50))
            fill_d.color = (1.0, 0.56, 0.26)
            fill_d.energy = 260 * (rad / 0.5) ** 2
            fill_d.shadow_soft_size = 0.15
            fill.location = B(V(ctr.x + rad * 1.6, rad * 0.7 + 0.2, ctr.z + rad * 1.5))
        for name, tgt, dist, az, el in views:
            a, e = math.radians(az), math.radians(el)
            pos = tgt + V(dist * math.sin(a) * math.cos(e), dist * math.sin(e), dist * math.cos(a) * math.cos(e))
            cam.location = B(pos)
            cam.rotation_euler = (B(tgt) - B(pos)).to_track_quat('-Z', 'Y').to_euler()
            idx = ["front", "three", "side", "close"].index(name) + (4 if mode == "night" else 0)
            sc.render.filepath = os.path.join(PREVIEW, label, "%s_%d.png" % (label, idx))
            bpy.ops.render.render(write_still=True)


MODELS = [
    ("crate", lambda: build_crate(False), V(0, 0.5, 0.3)),
    ("crate_broken", lambda: build_crate(True), V(0, 0.55, 0.0)),
    ("barrel", lambda: build_barrel(False), V(0, 0.65, 0)),
    ("barrel_tipped", lambda: build_barrel(True), V(0.2, 0.3, 0.1)),
    ("bench", lambda: build_bench(), V(0.4, 0.3, 0)),
    ("trough", lambda: build_trough(), V(0.3, 0.3, 0.1)),
    ("firewood", lambda: build_firewood(), V(0, 0.4, 0.4)),
    ("sack", lambda: build_sack(False), V(0.25, 0.2, 0)),
    ("sack_open", lambda: build_sack(True), V(0.05, 0.4, 0)),
    ("handcart", lambda: build_cart(), V(-0.1, 0.4, 0.5)),
]


def main():
    for name, fn, focus in MODELS:
        if ONLY and name not in ONLY:
            continue
        reset()
        MERGE.clear()
        if name in ("crate", "crate_broken", "bench"):
            MERGE["iron"] = "timber"            # nails only: not worth a draw call
        if name.startswith("sack"):
            MERGE["timber"] = "cloth"           # grain and the dark inside use the burlap set too
        vis, col = fn()
        near = tri_count(vis)
        export(vis + [col], os.path.join(OUT, name + ".glb"))
        lo, hi = bounds(vis)
        print("PROP %-14s tris %4d  size x %.2f..%.2f  y %.2f..%.2f  z %.2f..%.2f" % (
            name, near, lo.x, hi.x, lo.y, hi.y, lo.z, hi.z))
        if PREVIEW:
            col.hide_render = True
            render_set(vis, name, focus)


main()
