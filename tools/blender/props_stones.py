"""The lore stones of the Pilgrims' Road, modelled by script. No scans, no downloads.

New props -> art/models/props/ (one mesh, one material "NightStone" whose colour is the vertex colour; a
simple convex hull named *-convcolonly; empties named TextPoint where the inscription / glint sits):

  lore_tablet_weathered / _cracked / _leaning   the lore tablet (was a box 0.42 x 0.62 x 0.08, leaning)
  lore_waystone     milestone: footing, tapering shaft, cap, gable, carved arrow + tally, bell hook
  lore_stele        the Order's stele: step, tall shaft, belt moulding, lettered panel, Open Door arch
  lore_headstone_round / _cross / _slab / _broken
  lore_cairn_stack  a pilgrims' cairn, stacked and chipped (the legacy art/models/cairn.glb is remodelled too)
  lore_lectern      stone pedestal, timber book rest with lip

Remodels (same file name, node names, size and pivot as before, so realm_assets.gd needs no change):
  art/models/cairn.glb (node Stone.001)   art/models/rune_slab.glb (nodes Stone + Mark)
  art/models/rock_a.glb (RockA)           art/models/rock_b.glb (RockB)

Blender is Z up. A model's front (its inscribed face) looks along Blender +Y, which the glTF export turns
into Godot -Z, the same way the game's kits face their text. 1 BU = 1 m, pivot at the base centre on the
ground (the stone is buried a little below z=0).

  tools/blender/run.sh props_stones.py -- [--only a,b] [--preview DIR] [--export]
"""
import bpy
import bmesh
import math
import os
import sys
import random
from mathutils import Vector, Matrix, noise

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
PROPS = os.path.join(ROOT, "art", "models", "props")
LEGACY = os.path.join(ROOT, "art", "models")
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ONLY = args[args.index("--only") + 1].split(",") if "--only" in args else []
PREVIEW = args[args.index("--preview") + 1] if "--preview" in args else ""
DO_EXPORT = "--export" in args

TAG_STONE, TAG_FLOOR, TAG_RELIEF, TAG_TIMBER, TAG_IRON, TAG_CRACK, TAG_MARK = 0, 1, 2, 3, 4, 5, 6


# --- helpers ----------------------------------------------------------------------------------------
def fbm(p, octaves=3, lac=2.0, gain=0.5):
    a, f, s, n = 1.0, 1.0, 0.0, 0.0
    for _ in range(octaves):
        s += a * noise.noise(Vector(p) * f)
        n += a
        a *= gain
        f *= lac
    return s / n


def smooth(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a + 1e-9)))
    return t * t * (3 - 2 * t)


def oct_ring(r, cx, cy, z, w, d, ch, j=0.0, rot=0.0, zoff=None, chip=0.0):
    """A chamfered-rectangle cross-section, 8 points, counter-clockwise from above. Edge 2 is the front (+Y)."""
    ch = min(ch, w * 0.4, d * 0.4)
    hw, hd = w / 2, d / 2
    pts = [(hw, -hd + ch), (hw, hd - ch), (hw - ch, hd), (-hw + ch, hd), (-hw, hd - ch), (-hw, -hd + ch), (-hw + ch, -hd), (hw - ch, -hd)]
    out = []
    ca, sa = math.cos(rot), math.sin(rot)
    cx += r.uniform(-j, j) * 1.2
    cy += r.uniform(-j, j) * 0.6
    w *= 1.0 + r.uniform(-0.03, 0.03)
    ci = r.randrange(8) if (chip and r.random() < 0.7) else -1
    for i, (x, y) in enumerate(pts):
        x, y = x * ca - y * sa, x * sa + y * ca
        jy = j * (0.25 if i in (2, 3) else 0.7)
        x += cx + r.uniform(-j, j)
        y += cy + r.uniform(-jy, jy)
        zz = z + r.uniform(-j, j) * 0.5
        if zoff:
            zz += zoff(x, y)
        if i == ci:
            x, y, zz = cx + (x - cx) * (1 - chip * 3), cy + (y - cy) * (1 - chip * 3), zz - chip * 1.5
        out.append(Vector((x, y, zz)))
    return out


class Mk:
    def __init__(self, seed):
        self.bm = bmesh.new()
        self.r = random.Random(seed)
        self.seed = seed
        self.tag = self.bm.faces.layers.int.new("tag")
        self.crack = self.bm.verts.layers.float.new("crack")
        self.hullv = []
        self.points = []     # (name, position, matrix3)

    def face(self, vs, tag=0):
        try:
            f = self.bm.faces.new(vs)
        except ValueError:
            return None
        f[self.tag] = tag
        return f

    def loft(self, rings, top=True, bot=False, tag=0, hull=True):
        n = len(rings[0])
        vs = [[self.bm.verts.new(p) for p in ring] for ring in rings]
        faces = {}
        for i in range(len(rings) - 1):
            for s in range(n):
                faces[(i, s)] = self.face([vs[i][s], vs[i][(s + 1) % n], vs[i + 1][(s + 1) % n], vs[i + 1][s]], tag)
        if top:
            self.face(list(vs[-1]), tag)
        if bot:
            self.face(list(reversed(vs[0])), tag)
        if hull:
            for ring in vs:
                self.hullv += ring
        return faces, vs

    def panel(self, f, inset, depth, tag=TAG_FLOOR):
        """Sink a face: a stepped border and a recessed floor. Returns the floor's frame."""
        n0 = f.normal.copy()
        c0 = f.calc_center_median()
        bmesh.ops.inset_individual(self.bm, faces=[f], thickness=inset, depth=-depth, use_even_offset=True)
        c1 = f.calc_center_median()
        shift = -depth - (c1 - c0).dot(n0)
        for v in f.verts:
            v.co += n0 * shift
        f[self.tag] = tag
        return self.frame(f)

    def frame(self, f):
        f.normal_update()
        n = f.normal.copy()
        c = f.calc_center_median()
        up = Vector((0, 0, 1)) - n * n.z
        up.normalize()
        right = (-n).cross(up)
        hw = max(abs((v.co - c).dot(right)) for v in f.verts)
        hh = max(abs((v.co - c).dot(up)) for v in f.verts)
        return dict(c=c, n=n, up=up, right=right, hw=hw, hh=hh)

    def relief(self, fr, pts, h, tag=TAG_RELIEF, du=0.0, dv=0.0):
        c, n, up, right = fr["c"], fr["n"], fr["up"], fr["right"]
        base = [self.bm.verts.new(c + right * (u + du) + up * (v + dv)) for u, v in pts]
        top = [self.bm.verts.new(c + right * (u + du) + up * (v + dv) + n * h) for u, v in pts]
        self.face(top, tag)
        for i in range(len(pts)):
            j = (i + 1) % len(pts)
            self.face([base[i], base[j], top[j], top[i]], tag)

    def pebble(self, c, half, rot=0.0, npts=9, tag=0, hull=True, flat=0.0):
        """A chunky hull of a few points on a squashed ellipsoid: a hand-split stone."""
        r = self.r
        a, b, cz = half
        pts = []
        for sx in (-1, 1):
            for sy in (-1, 1):
                for sz in (-1, 1):
                    k = r.uniform(0.62, 0.92)
                    pts.append(Vector((sx * a * k * r.uniform(0.9, 1.05), sy * b * k * r.uniform(0.9, 1.05), sz * cz * r.uniform(0.8, 1.0))))
        for q in range(max(0, npts - 8)):
            ax = r.randrange(3)
            sg = r.choice((-1, 1)) if q else 1
            v = [r.uniform(-0.3, 0.3) * a, r.uniform(-0.3, 0.3) * b, r.uniform(-0.3, 0.3) * cz]
            v[ax] = sg * (a, b, cz)[ax] * r.uniform(1.0, 1.12)
            pts.append(Vector(v))
        if flat:
            for p in pts:
                p.z = min(p.z, cz * (1.0 - flat))
        rm = Matrix.Rotation(rot, 3, 'Z') @ Matrix.Rotation(r.uniform(-0.3, 0.3), 3, 'X') @ Matrix.Rotation(r.uniform(-0.3, 0.3), 3, 'Y')
        vs = [self.bm.verts.new(c + rm @ p) for p in pts]
        res = bmesh.ops.convex_hull(self.bm, input=vs)
        dead = list({g for g in res["geom_interior"] + res["geom_unused"] if isinstance(g, bmesh.types.BMVert)})
        if dead:
            bmesh.ops.delete(self.bm, geom=dead, context='VERTS')
        for f in self.bm.faces:
            if f[self.tag] == 0 and False:
                pass
        if hull:
            self.hullv += [v for v in vs if v.is_valid]
        return [v for v in vs if v.is_valid]

    def xf(self, m):
        bmesh.ops.transform(self.bm, matrix=m, verts=self.bm.verts)
        self.points = [(n, m @ p, (m.to_3x3() @ q)) for n, p, q in self.points]

    def point(self, name, pos, n=None):
        self.points.append((name, Vector(pos), Matrix.Identity(3)))


# --- colour ----------------------------------------------------------------------------------------
def stone_col(co, n, tag, seed, cw=0.0, moss_k=1.0):
    off = Vector((seed * 1.7, seed * 0.9, seed * 2.3))
    v = 0.36 + 0.17 * fbm(co * 2.2 + off, 3) + 0.05 * fbm(co * 9.0 + off, 2) + 0.05 * fbm(Vector((co.x * 6, co.y * 6, co.z * 0.7)) + off, 2)
    base = (v * 1.0, v * 0.985, v * 1.04)
    if tag == TAG_TIMBER:
        g = 0.27 + 0.09 * fbm(Vector((co.x * 2.0, co.y * 14.0, co.z * 2.0)) + off, 3)
        base = (g * 1.1, g * 0.78, g * 0.52)
    elif tag == TAG_IRON:
        rs = smooth(-0.1, 0.5, fbm(co * 8 + off, 2))
        base = (0.17 + 0.2 * rs, 0.17 + 0.08 * rs, 0.2 - 0.05 * rs)
        return base
    elif tag == TAG_CRACK:
        return (0.05, 0.05, 0.06)
    elif tag == TAG_MARK:
        return (0.95, 0.42, 0.38)
    z = co.z
    patch = smooth(-0.15, 0.35, fbm(co * 5.0 + off + Vector((3, 1, 7)), 3))
    foot = 1.0 - smooth(0.0, 0.34, z)
    top = smooth(0.4, 0.85, n.z)
    moss = min(1.0, (foot * (0.45 + 0.55 * patch) + top * patch * 0.85 + 0.06 * patch)) * moss_k
    stain = smooth(0.05, 0.5, fbm(Vector((co.x * 5, co.y * 5, co.z * 0.7)) + off, 2)) * 0.4
    base = tuple(b * (1 - stain) for b in base)
    moss = min(1.0, moss + smooth(0.25, 0.6, fbm(co * 3.0 + off + Vector((9, 2, 4)), 3)) * 0.35 * moss_k * (1 - smooth(0.6, 1.4, z)))
    if tag == TAG_TIMBER:
        moss *= 0.35
    mc = (0.12 + 0.05 * patch, 0.20 + 0.07 * patch, 0.07)
    damp = 1.0 - 0.16 * foot
    c = [base[i] * damp * (1 - moss) + mc[i] * moss for i in range(3)]
    lich = smooth(0.32, 0.58, fbm(co * 13.0 + off, 2)) * (1.0 - top) * smooth(0.15, 0.6, z) * 0.5 * moss_k
    lc = (0.60, 0.63, 0.45)
    c = [c[i] * (1 - lich) + lc[i] * lich for i in range(3)]
    if abs(n.z) < 0.35 and abs(n.x) > 0.3 and abs(n.y) > 0.3:
        c = [min(1.0, x * 1.18) for x in c]
    if tag == TAG_FLOOR:
        c = [x * 0.72 for x in c]
    elif tag == TAG_RELIEF:
        c = [min(1.0, x * 1.1) for x in c]
    if cw > 0:
        c = [x * (1 - 0.75 * cw) for x in c]
    return tuple(min(1.0, x) for x in c)


def finish(mk, name, matname="NightStone", moss_k=1.0, flat=True):
    bm = mk.bm
    bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method='BEAUTY', ngon_method='EAR_CLIP')
    bm.normal_update()
    uv = bm.loops.layers.uv.new("UVMap")
    col = bm.loops.layers.color.new("Col")
    for f in bm.faces:
        f.smooth = not flat
        n = f.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        t = f[mk.tag]
        for l in f.loops:
            co = l.vert.co
            if ax == 0:
                l[uv].uv = (co.y / 2.0, co.z / 2.0)
            elif ax == 1:
                l[uv].uv = (co.x / 2.0, co.z / 2.0)
            else:
                l[uv].uv = (co.x / 2.0, co.y / 2.0)
            c = stone_col(co, n, t, mk.seed, l.vert[mk.crack], moss_k)
            l[col] = (c[0], c[1], c[2], 1.0)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    me.color_attributes.active_color = me.color_attributes["Col"]
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    ob.data.materials.append(material(matname))
    tris = len(me.polygons)
    return ob, tris


_mats = {}


def material(name):
    if name in _mats and name in bpy.data.materials:
        return bpy.data.materials[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    vc = nt.nodes.new("ShaderNodeVertexColor")
    vc.layer_name = "Col"
    nt.links.new(vc.outputs[0], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.88
    bsdf.inputs["Metallic"].default_value = 0.0
    _mats[name] = m
    return m


def hull_object(mk, name, verts_world=None):
    """A convex collision hull from the registered solid vertices, above the ground (and a little below)."""
    seen = {}
    for v in mk.hullv:
        if v.is_valid:
            seen[tuple(round(c, 5) for c in v.co)] = v.co.copy()
    pts = list(seen.values())
    bm = bmesh.new()
    vs = [bm.verts.new(p) for p in pts]
    res = bmesh.ops.convex_hull(bm, input=vs)
    dead = list({g for g in res["geom_interior"] + res["geom_unused"] if isinstance(g, bmesh.types.BMVert)})
    if dead:
        bmesh.ops.delete(bm, geom=dead, context='VERTS')
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def empties(mk):
    out = []
    for n, p, q in mk.points:
        e = bpy.data.objects.new(n, None)
        e.empty_display_type = 'PLAIN_AXES'
        e.empty_display_size = 0.06
        e.location = p
        e.rotation_euler = q.to_euler()
        bpy.context.scene.collection.objects.link(e)
        out.append(e)
    return out


def fit_bbox(mk, lo, hi):
    vs = mk.bm.verts
    mn = Vector((min(v.co[i] for v in vs) for i in range(3)))
    mx = Vector((max(v.co[i] for v in vs) for i in range(3)))
    for v in vs:
        for i in range(3):
            v.co[i] = lo[i] + (v.co[i] - mn[i]) / (mx[i] - mn[i]) * (hi[i] - lo[i])


# --- tablets (0.42 x 0.62 x 0.08) ---------------------------------------------------------------------
def tablet(variant):
    seed = {"weathered": 11, "cracked": 23, "leaning": 37}[variant]
    mk = Mk(seed)
    r = mk.r
    j = 0.009
    W, D = 0.42, 0.08
    zoff = None
    if variant == "cracked":
        zoff = lambda x, y: -max(0.0, x - 0.05) * 0.8 - (0.04 if x > 0.14 else 0.0)   # the right shoulder sheared off
    arch = [(0.50, 0.405), (0.565, 0.36), (0.605, 0.27), (0.62, 0.15)]
    zs = [(-0.10, 0.40), (0.04, W), (0.14, 0.43), (0.50, 0.415)] + arch
    rings = []
    for z, w in zs:
        zo = zoff if (variant == "cracked" and z >= 0.5) else None
        rings.append(oct_ring(r, 0, 0, z, w, D, 0.014, j, r.uniform(-0.02, 0.02), zo))
    faces, vs = mk.loft(rings)
    fr = mk.panel(faces[(2, 2)], 0.045, 0.014)
    if variant == "cracked":
        # a hairline crack running down the right of the face, dark strips just proud of it
        x0, z0 = 0.16, 0.44
        pts = []
        for i in range(5):
            pts.append((x0 + r.uniform(-0.025, 0.025) + 0.02 * i * (-1 if i % 2 else 1) * 0.3, z0 - i * 0.1))
        yf = D / 2 + 0.0015
        for a, b in zip(pts, pts[1:]):
            d = Vector((b[0] - a[0], 0, b[1] - a[1]))
            nx = Vector((d.z, 0, -d.x)).normalized() * 0.004
            p0, p1 = Vector((a[0], yf, a[1])), Vector((b[0], yf, b[1]))
            q = [mk.bm.verts.new(p0 - nx), mk.bm.verts.new(p0 + nx), mk.bm.verts.new(p1 + nx), mk.bm.verts.new(p1 - nx)]
            mk.face(q[::-1] if True else q, TAG_CRACK)
        # the sheared-off piece lying at the foot
        lr = []
        for z, w in [(0.0, 0.17), (0.05, 0.17), (0.09, 0.12)]:
            lr.append(oct_ring(r, 0, 0, z, w, 0.075, 0.012, 0.006, 0.3))
        _, lv = mk.loft(lr, hull=False)
        rm = Matrix.Translation((0.24, 0.20, 0.04)) @ Matrix.Rotation(0.7, 4, 'Z') @ Matrix.Rotation(1.35, 4, 'X')
        bmesh.ops.transform(mk.bm, matrix=rm, verts=[v for ring in lv for v in ring])
    # a few score lines on the face (the game lays its glint across the first)
    for i, (wf, dz) in enumerate([(0.62, 0.075), (0.82, 0.0)] + ([] if variant == 'cracked' else [(0.45, -0.075)])):
        hw = fr["hw"] * wf
        mk.relief(fr, [(-hw, -0.009), (hw, -0.009), (hw, 0.009), (-hw, 0.009)], 0.004, dv=dz + 0.02, du=(-0.04 if i == 2 else 0.0))
    tp = fr["c"] + fr["n"] * 0.008 + fr["up"] * 0.095
    mk.point("TextPoint", tp)
    if variant == "leaning":
        # propped on two wedge stones behind it
        for (x, y, s) in [(-0.1, -0.1, 0.07), (0.12, -0.12, 0.06)]:
            mk.pebble(Vector((x, y, 0.02)), (s * 1.3, s, s * 0.75), r.random() * 3, 8)
        m = Matrix.Rotation(0.30, 4, 'X') @ Matrix.Rotation(0.11, 4, 'Y')
        mk.xf(m)
    return mk


# --- waystone -----------------------------------------------------------------------------------------
def waystone():
    mk = Mk(51)
    r = mk.r
    j = 0.016
    spec = [(-0.35, 0.76, 0.60, 0.03), (0.0, 0.78, 0.62, 0.03), (0.07, 0.76, 0.60, 0.04), (0.10, 0.62, 0.48, 0.03),
            (0.14, 0.60, 0.46, 0.03), (0.72, 0.56, 0.43, 0.025), (1.20, 0.53, 0.41, 0.025), (1.38, 0.50, 0.38, 0.025),
            (1.43, 0.61, 0.49, 0.03), (1.54, 0.61, 0.49, 0.03), (1.56, 0.52, 0.40, 0.025), (1.84, 0.05, 0.40, 0.01)]
    rings = [oct_ring(r, 0, 0, z, w, d, ch, j, r.uniform(-0.03, 0.03)) for z, w, d, ch in spec]
    faces, vs = mk.loft(rings)
    fr = mk.panel(faces[(5, 2)], 0.05, 0.016)
    # the arrow, pointing along the road, with a tally of miles beneath it
    mk.relief(fr, [(-0.13, -0.026), (0.03, -0.026), (0.03, 0.026), (-0.13, 0.026)], 0.011, dv=0.075)
    mk.relief(fr, [(0.03, -0.075), (0.14, 0.0), (0.03, 0.075)], 0.011, dv=0.075)
    for i in range(3):
        mk.relief(fr, [(-0.007, -0.03), (0.007, -0.03), (0.007, 0.03), (-0.007, 0.03)], 0.009, du=(i - 1) * 0.05, dv=-0.1)
    mk.point("TextPoint", fr["c"] + fr["n"] * 0.01 + fr["up"] * -0.04)
    # the iron bell hook on the road side
    hook = [(-0.09, -0.012), (0.09, -0.012), (0.09, 0.012), (-0.09, 0.012)]
    f2 = Mk.frame(mk, faces[(7, 0)])
    mk.relief(f2, [(-0.05, -0.012), (0.09, -0.012), (0.09, 0.012), (-0.05, 0.012)], 0.045, tag=TAG_IRON, dv=0.0)
    mk.relief(f2, [(0.07, -0.05), (0.09, -0.05), (0.09, 0.012), (0.07, 0.012)], 0.045, tag=TAG_IRON, dv=0.0, du=0.0)
    return mk


# --- stele -------------------------------------------------------------------------------------------
def stele():
    mk = Mk(61)
    r = mk.r
    j = 0.02
    step = [oct_ring(r, 0, 0, z, w, d, 0.04, j, r.uniform(-0.01, 0.01)) for z, w, d in [(-0.3, 1.25, 0.70), (0.16, 1.25, 0.70), (0.22, 1.13, 0.62)]]
    mk.loft(step)
    ts = [(0.12, 0.92, 0.34), (0.88, 0.92, 0.34), (1.72, 0.91, 0.33), (1.78, 0.91, 0.33), (2.30, 0.90, 0.32), (2.74, 0.06, 0.32)]
    rings = [oct_ring(r, 0, 0, z, w, d, 0.025, j * 0.8, r.uniform(-0.01, 0.01)) for z, w, d in ts]
    faces, vs = mk.loft(rings)
    belt = [oct_ring(r, 0, 0, z, w, d, 0.02, 0.006) for z, w, d in [(0.46, 1.0, 0.40), (0.54, 1.0, 0.40)]]
    mk.loft(belt, bot=True, hull=False)
    cornice = [oct_ring(r, 0, 0, z, w, d, 0.02, 0.006) for z, w, d in [(2.26, 1.02, 0.40), (2.34, 1.02, 0.40)]]
    mk.loft(cornice, bot=True, hull=False)
    fr = mk.panel(faces[(1, 2)], 0.08, 0.02)
    mk.point("TextPoint", fr["c"] + fr["n"] * 0.008)
    fd = mk.panel(faces[(3, 2)], 0.07, 0.02)
    # the Open Door: an arch with a dark gap
    arch = [(0.12, -0.17), (0.12, 0.05)] + [(math.cos(a) * 0.12, 0.05 + math.sin(a) * 0.12) for a in (math.pi / 6, math.pi / 3, math.pi / 2, 2 * math.pi / 3, 5 * math.pi / 6)] + [(-0.12, 0.05), (-0.12, -0.17)]
    mk.relief(fd, arch, 0.012)
    gap = [(0.05, -0.15), (0.05, 0.04), (0.0, 0.085), (-0.05, 0.04), (-0.05, -0.15)]
    mk.relief(fd, gap, 0.016, tag=TAG_CRACK)
    mk.point("DoorPoint", fd["c"] + fd["n"] * 0.008)
    return mk


# --- headstones ---------------------------------------------------------------------------------------
def headstone(kind):
    seed = {"round": 71, "cross": 72, "slab": 73, "broken": 74}[kind]
    mk = Mk(seed)
    r = mk.r
    j = 0.012
    W, T = 0.55, 0.16
    if kind == "round":
        R = W / 2
        rings = [oct_ring(r, 0, 0, z, W + 0.01, T, 0.02, j) for z in (-0.30, 0.0)]
        rings += [oct_ring(r, 0, 0, z, W, T, 0.02, j) for z in (0.22, 0.70)]
        for a in (28, 52, 72, 87):
            ar = math.radians(a)
            rings.append(oct_ring(r, 0, 0, 0.70 + R * math.sin(ar), 2 * R * math.cos(ar), T, 0.02, j * 0.5))
        faces, _ = mk.loft(rings)
        fr = mk.panel(faces[(2, 2)], 0.05, 0.014)
        mk.point("TextPoint", fr["c"] + fr["n"] * 0.006)
    elif kind == "slab":
        sp = [(-0.30, W + 0.01, T), (0.0, W, T), (0.22, W, T), (0.70, W, T), (0.80, W, T), (0.80, W + 0.07, T + 0.06), (0.86, W + 0.07, T + 0.06),
              (0.88, W, T), (1.0, 0.05, T * 0.9)]
        rings = [oct_ring(r, 0, 0, z, w, d, 0.02, j) for z, w, d in sp]
        faces, _ = mk.loft(rings)
        fr = mk.panel(faces[(2, 2)], 0.05, 0.014)
        mk.point("TextPoint", fr["c"] + fr["n"] * 0.006)
    elif kind == "cross":
        plinth = [oct_ring(r, 0, 0, z, w, d, 0.02, j) for z, w, d in [(-0.30, 0.46, 0.32), (0.0, 0.46, 0.32), (0.20, 0.45, 0.31), (0.25, 0.40, 0.27)]]
        faces, _ = mk.loft(plinth)
        fr = mk.panel(faces[(1, 2)], 0.035, 0.012)
        mk.point("TextPoint", fr["c"] + fr["n"] * 0.006)
        stem = [oct_ring(r, 0, 0, z, w, T, 0.02, j) for z, w in [(0.2, 0.2), (0.6, 0.18), (1.0, 0.17)]]
        mk.loft(stem)
        arms = [oct_ring(r, 0, 0, z, w, T, 0.02, j * 0.5) for z, w in [(0.68, 0.60), (0.68 + 0.17, 0.60)]]
        mk.loft(arms, bot=True)
    else:
        sp = [(-0.30, W + 0.01), (0.0, W), (0.14, W), (0.46, W), (0.56, W), (0.60, W * 0.97)]
        slope = lambda x, y: -x * 0.45 + 0.05 * math.sin(x * 25)
        rings = []
        for k, (z, w) in enumerate(sp):
            rings.append(oct_ring(r, 0, 0, z, w, T, 0.02, j, 0.0, slope if k >= 4 else None))
        faces, _ = mk.loft(rings)
        fr = mk.panel(faces[(2, 2)], 0.05, 0.014)
        mk.point("TextPoint", fr["c"] + fr["n"] * 0.006)
        # the head, snapped off and lying in front, face up
        pr = []
        for z, w in [(0.0, 0.48), (0.2, 0.46), (0.36, 0.30)]:
            pr.append(oct_ring(r, 0, 0, z, w, T, 0.02, 0.008, 0.2, (lambda x, y: -x * 0.5) if z > 0.3 else None))
        _, pv = mk.loft(pr, bot=True, hull=False)
        rm = Matrix.Translation((0.08, 0.62, 0.05)) @ Matrix.Rotation(0.5, 4, 'Z') @ Matrix.Rotation(-math.pi / 2 + 0.12, 4, 'X')
        bmesh.ops.transform(mk.bm, matrix=rm, verts=[v for ring in pv for v in ring])
    return mk


# --- cairn --------------------------------------------------------------------------------------------
def cairn_stack(seed=81, size=(0.5, 0.5, 0.6), layers=(6, 5, 4, 2, 1), loose=3, npts=10):
    mk = Mk(seed)
    r = mk.r
    z = 0.0
    sx, sy, H = size
    for li, n in enumerate(layers):
        t = li / max(1, len(layers) - 1)
        rad = (0.20 * (1 - t * 0.75)) if n > 1 else 0.0
        hh = H / (len(layers) + 0.6)
        for i in range(n):
            a = math.tau * i / max(n, 1) + r.uniform(-0.3, 0.3) + li * 0.7
            rr = rad * r.uniform(0.85, 1.1)
            c = Vector((math.cos(a) * rr * sx, math.sin(a) * rr * sy, z + hh * 0.5 * 0.92))
            size_k = (1 - t * 0.35)
            half = (0.20 * sx * size_k * r.uniform(0.85, 1.1), 0.18 * sy * size_k * r.uniform(0.85, 1.1), hh * 0.62 * r.uniform(0.9, 1.1))
            mk.pebble(c, half, r.random() * 6.28, npts)
        z += hh * 0.72
    for i in range(loose):
        a = r.random() * math.tau
        mk.pebble(Vector((math.cos(a) * 0.3 * sx, math.sin(a) * 0.3 * sy, 0.02)), (0.05, 0.045, 0.03), r.random() * 6, 8)
    return mk


# --- lectern ------------------------------------------------------------------------------------------
def lectern():
    mk = Mk(91)
    r = mk.r
    j = 0.006
    pl = [oct_ring(r, 0, 0, z, w, d, 0.025, j) for z, w, d in [(-0.10, 0.64, 0.54), (0.0, 0.62, 0.52), (0.10, 0.61, 0.51), (0.14, 0.50, 0.42)]]
    mk.loft(pl)
    sh = [oct_ring(r, 0, 0, z, w, d, 0.03, j, r.uniform(-0.02, 0.02)) for z, w, d in
          [(0.12, 0.30, 0.28), (0.40, 0.26, 0.24), (0.85, 0.28, 0.26), (0.96, 0.36, 0.32), (1.02, 0.46, 0.38)]]
    faces, _ = mk.loft(sh)
    # the book rest: a timber board, tilted toward the reader (+Y), with a lip and a back stop
    pivot = Vector((0, 0, 1.10))
    tilt = Matrix.Translation(pivot) @ Matrix.Rotation(-0.45, 4, 'X')
    board = [oct_ring(r, 0, 0, z, 0.62, 0.46, 0.015, 0.004) for z in (-0.03, 0.03)]
    _, bv = mk.loft(board, bot=True, tag=TAG_TIMBER)
    lip = [oct_ring(r, 0, 0.21, z, 0.60, 0.05, 0.01, 0.003) for z in (0.03, 0.09)]
    _, lv = mk.loft(lip, bot=True, tag=TAG_TIMBER)
    back = [oct_ring(r, 0, -0.20, z, 0.60, 0.05, 0.01, 0.003) for z in (0.03, 0.10)]
    _, kv = mk.loft(back, bot=True, tag=TAG_TIMBER)
    bmesh.ops.transform(mk.bm, matrix=tilt, verts=[v for g in (bv, lv, kv) for ring in g for v in ring])
    mk.point("TextPoint", tilt @ Vector((0, -0.02, 0.05)))
    # tell the TextPoint to face the reader as the board does
    n, p, q = mk.points[-1]
    mk.points[-1] = (n, p, tilt.to_3x3())
    return mk


# --- remodels ------------------------------------------------------------------------------------------
def rune_slab():
    mk = Mk(101)
    r = mk.r
    j = 0.004
    zoff = lambda x, y: -x * 0.07 + 0.012 * math.sin(x * 40)
    spec = [(0.0, 0.43), (0.06, 0.456), (0.17, 0.456), (0.67, 0.452), (0.70, 0.445), (0.72, 0.42)]
    rings = []
    for k, (z, w) in enumerate(spec):
        rings.append(oct_ring(r, 0, 0, z, w, 0.129, 0.016, j, r.uniform(-0.01, 0.01), zoff if k >= 4 else None))
    faces, _ = mk.loft(rings)
    fr = mk.panel(faces[(2, 2)], 0.045, 0.012)
    stone, st = finish(mk, "Stone")
    mkm = Mk(102)
    mkm.tag_default = TAG_MARK
    stroke = lambda a, b, w: _stroke(a, b, w)
    fr2 = dict(fr)
    for a, b, w in [((0, -0.19), (0, 0.19), 0.03), ((0, 0.19), (0.09, 0.09), 0.026), ((0, 0.04), (0.10, -0.07), 0.026), ((0, -0.03), (-0.09, 0.07), 0.026),
                    ((-0.07, -0.19), (0.07, -0.19), 0.02)]:
        mkm.relief(fr2, _stroke(a, b, w), 0.016, tag=TAG_MARK)
    mark, mt = finish(mkm, "Mark", "NightRune")
    return mk, stone, st, [(mark, mt)]


def _stroke(a, b, w):
    a, b = Vector(a), Vector(b)
    d = (b - a).normalized()
    nx = Vector((-d.y, d.x)) * (w / 2)
    e = d * (w / 2)
    pts = [a - e - nx, b + e - nx, b + e + nx, a - e + nx]
    return [(p.x, p.y) for p in pts]


def rock(seed, lo, hi, N, R, planes, name, crack_cols):
    mk = Mk(seed)
    r = mk.r
    rings = []
    ph0 = r.random() * math.tau
    for k in range(R):
        t = k / (R - 1)
        prof = 0.78 + 0.22 * math.sin(math.pi * min(1.0, t * 1.2)) - 0.34 * smooth(0.65, 1.0, t)
        ring = []
        for jx in range(N):
            ang = ph0 + math.tau * (jx + 0.5 * (k % 2) * 0.6) / N + r.uniform(-0.18, 0.18) * math.tau / N
            rad = prof * (1.0 + r.uniform(-0.1, 0.1)) * (1.0 + 0.12 * fbm(Vector((math.cos(ang) * 1.3, math.sin(ang) * 1.3, t * 2.0)) + Vector((seed, 0, 0)), 2))
            z = t + r.uniform(-0.02, 0.02) * (0 < k < R - 1)
            ring.append([math.cos(ang) * rad, math.sin(ang) * rad, z])
        rings.append(ring)
    # chisel: planes trimming the bulges into flat facets
    pl = []
    for i in range(planes):
        a = r.random() * math.tau
        e = r.uniform(-0.15, 0.55)
        n = Vector((math.cos(a) * math.cos(e), math.sin(a) * math.cos(e), math.sin(e))).normalized()
        pl.append((n, r.uniform(0.52, 0.74)))
    pl.append((Vector((r.uniform(-0.3, 0.3), r.uniform(-0.3, 0.3), 1.0)).normalized(), 0.5))
    for ring in rings:
        for p in ring:
            for n, d in pl:
                q = Vector((p[0], p[1], (p[2] - 0.45) * 1.2))
                pr = n.dot(q)
                if pr > d:
                    q -= n * (pr - d)
                    p[0], p[1], p[2] = q.x, q.y, q.z / 1.2 + 0.45
    vs = [[mk.bm.verts.new(p) for p in ring] for ring in rings]
    for k in range(R - 1):
        for jx in range(N):
            mk.face([vs[k][jx], vs[k][(jx + 1) % N], vs[k + 1][(jx + 1) % N], vs[k + 1][jx]])
    mk.face(list(vs[-1]))
    mk.face(list(reversed(vs[0])))
    # cracks: a column of vertices drawn in and darkened
    for cj in crack_cols:
        j0 = cj
        for k in range(1, R - 1):
            j0 = (j0 + r.choice((-1, 0, 0, 1))) % N
            v = vs[k][j0]
            v[mk.crack] = 1.0
            v.co.x *= 0.9
            v.co.y *= 0.9
            for dj in (-1, 1):
                w = vs[k][(j0 + dj) % N]
                w[mk.crack] = max(w[mk.crack], 0.35)
    fit_bbox(mk, lo, hi)
    for v in mk.bm.verts:
        v.co.z = max(v.co.z, 0.0)
    ob, tr = finish(mk, name, moss_k=1.2)
    return mk, ob, tr


# --- build / export / preview --------------------------------------------------------------------------
def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _mats.clear()


def build(name):
    """Returns dict(objs=[(mesh object, tris)], col, empties, path)"""
    out = {}
    path = os.path.join(PROPS, "lore_%s.glb" % name)
    if name.startswith("tablet_"):
        mk = tablet(name.split("_", 1)[1])
    elif name == "waystone":
        mk = waystone()
    elif name == "stele":
        mk = stele()
    elif name.startswith("headstone_"):
        mk = headstone(name.split("_", 1)[1])
    elif name == "cairn_stack":
        mk = cairn_stack()
    elif name == "lectern":
        mk = lectern()
    elif name == "legacy_cairn":
        mk = cairn_stack(seed=84, size=(0.39 / 0.5 * 1.2, 0.29 / 0.5 * 1.2, 0.61), layers=(5, 4, 3, 2, 1), loose=3, npts=10)
        fit_bbox(mk, (-0.19, -0.125, 0.005), (0.2, 0.165, 0.615))
        ob, tr = finish(mk, "Stone.001", moss_k=1.1)
        return dict(objs=[(ob, tr)], col=None, empties=[], path=os.path.join(LEGACY, "cairn.glb"))
    elif name == "legacy_rune_slab":
        mk, ob, tr, extra = rune_slab()
        return dict(objs=[(ob, tr)] + extra, col=None, empties=[], path=os.path.join(LEGACY, "rune_slab.glb"))
    elif name == "legacy_rock_a":
        mk, ob, tr = rock(201, (-0.863, -0.76, 0.0), (0.808, 0.76, 1.099), 14, 8, 12, "RockA", (3,))
        return dict(objs=[(ob, tr)], col=None, empties=[], path=os.path.join(LEGACY, "rock_a.glb"))
    elif name == "legacy_rock_b":
        mk, ob, tr = rock(207, (-0.753, -0.689, 0.0), (0.761, 0.669, 1.415), 14, 8, 13, "RockB", (5, 11))
        return dict(objs=[(ob, tr)], col=None, empties=[], path=os.path.join(LEGACY, "rock_b.glb"))
    else:
        raise KeyError(name)
    cname = {"tablet": "Tablet", "headstone": "Headstone"}.get(name.split("_")[0], name.split("_")[0].capitalize())
    ob, tr = finish(mk, cname)
    col = hull_object(mk, cname + "-convcolonly")
    em = empties(mk)
    return dict(objs=[(ob, tr)], col=col, empties=em, path=path)


def export(items, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.object.select_all(action='DESELECT')
    for o in items:
        o.select_set(True)
    kw = dict(filepath=path, export_format='GLB', use_selection=True, export_apply=True, export_yup=True,
              export_materials='EXPORT', export_image_format='NONE', export_normals=True, export_texcoords=True)
    try:
        bpy.ops.export_scene.gltf(export_vertex_color='ACTIVE', export_active_vertex_color_when_no_material=True, **kw)
    except TypeError:
        try:
            bpy.ops.export_scene.gltf(export_vertex_color='ACTIVE', **kw)
        except TypeError:
            bpy.ops.export_scene.gltf(**kw)
    print("EXPORTED", path)


def preview(label, meshes, focus):
    if not PREVIEW:
        return
    os.makedirs(PREVIEW, exist_ok=True)
    sc = bpy.context.scene
    try:
        sc.render.engine = 'BLENDER_EEVEE'
    except TypeError:
        sc.render.engine = 'BLENDER_WORKBENCH'
    try:
        sc.eevee.taa_render_samples = 24
    except Exception:
        pass
    sc.render.resolution_x = sc.render.resolution_y = 960
    sc.view_settings.view_transform = 'Standard'
    pts = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
    mn = Vector((min(p[i] for p in pts) for i in range(3)))
    mx = Vector((max(p[i] for p in pts) for i in range(3)))
    ctr = (mn + mx) / 2
    size = (mx - mn).length
    # ground
    bpy.ops.mesh.primitive_circle_add(vertices=48, radius=size * 0.85, fill_type='NGON', location=(ctr.x, ctr.y, -0.002))
    gr = bpy.context.active_object
    gm = bpy.data.materials.new("ground")
    gm.use_nodes = True
    gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.09, 0.11, 0.07, 1)
    gm.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 1.0
    gr.data.materials.append(gm)
    cam_d = bpy.data.cameras.new("cam")
    cam = bpy.data.objects.new("cam", cam_d)
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam_d.lens = 50
    dist = size * 1.9
    views = [("front", Vector((0.0, 1.0, 0.22)), dist, ctr),
             ("q3", Vector((0.8, 0.85, 0.45)), dist, ctr),
             ("side", Vector((1.0, 0.04, 0.2)), dist, ctr),
             ("close", Vector((0.3, 1.0, 0.32)), dist * 0.5, focus)]
    for light in ("neutral", "night"):
        for o in list(bpy.data.objects):
            if o.type == 'LIGHT':
                bpy.data.objects.remove(o)
        w = bpy.data.worlds.new(light)
        w.use_nodes = True
        bg = w.node_tree.nodes["Background"]
        sc.world = w
        if light == "neutral":
            bg.inputs[0].default_value = (0.55, 0.55, 0.58, 1)
            bg.inputs[1].default_value = 0.7
            sun = bpy.data.lights.new("sun", 'SUN')
            sun.energy = 2.6
            so = bpy.data.objects.new("sun", sun)
            sc.collection.objects.link(so)
            so.rotation_euler = (math.radians(50), 0, math.radians(150))
        else:
            bg.inputs[0].default_value = (0.05, 0.07, 0.2, 1)
            bg.inputs[1].default_value = 0.8
            moon = bpy.data.lights.new("moon", 'SUN')
            moon.energy = 2.2
            moon.color = (0.62, 0.7, 1.0)
            mo = bpy.data.objects.new("moon", moon)
            sc.collection.objects.link(mo)
            mo.rotation_euler = (math.radians(55), 0, math.radians(145))
            warm = bpy.data.lights.new("fire", 'POINT')
            warm.energy = 90 * max(1.0, size) ** 2
            warm.color = (1.0, 0.62, 0.32)
            warm.shadow_soft_size = 0.1
            wo = bpy.data.objects.new("fire", warm)
            sc.collection.objects.link(wo)
            wo.location = ctr + Vector((size * 0.9, size * 1.0, -size * 0.1))
        for vn, d, dd, tgt in views:
            cam.location = tgt + d.normalized() * dd
            cam.rotation_euler = (tgt - cam.location).to_track_quat('-Z', 'Y').to_euler()
            sc.render.filepath = os.path.join(PREVIEW, "%s_%s_%s.png" % (label, light, vn))
            bpy.ops.render.render(write_still=True)


NAMES = ["tablet_weathered", "tablet_cracked", "tablet_leaning", "waystone", "stele", "headstone_round", "headstone_cross",
         "headstone_slab", "headstone_broken", "cairn_stack", "lectern", "legacy_cairn", "legacy_rune_slab", "legacy_rock_a", "legacy_rock_b"]
TRI_BUDGET = {"tablet": 200, "waystone": 300, "stele": 300, "headstone": 200, "cairn_stack": 400, "lectern": 300,
              "legacy_cairn": 400, "legacy_rune_slab": 250, "legacy_rock": 300}

if __name__ == "__main__":
    for nm in NAMES:
        if ONLY and nm not in ONLY:
            continue
        reset()
        b = build(nm)
        tot = sum(t for _, t in b["objs"])
        budget = next((v for k, v in TRI_BUDGET.items() if nm.startswith(k)), 0)
        print("TRIS %-18s %4d (budget %d)%s" % (nm, tot, budget, "" if tot < budget else "  OVER"))
        meshes = [o for o, _ in b["objs"]]
        focus = Vector((0, 0, 0))
        if b["empties"]:
            focus = b["empties"][0].location.copy()
        else:
            pts = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
            focus = sum(pts, Vector()) / len(pts)
        if PREVIEW:
            if b["col"]:
                b["col"].hide_render = True
                b["col"].hide_viewport = True
            preview(nm, meshes, focus)
        if DO_EXPORT:
            items = meshes + ([b["col"]] if b["col"] else []) + b["empties"]
            if b["col"]:
                b["col"].hide_render = False
                b["col"].hide_viewport = False
            export(items, b["path"])
