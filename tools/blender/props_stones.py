"""The lore stones of the Pilgrims' Road, modelled by script. No scans, no downloads.

New props -> art/models/props/. Each is split by material set like the West Marches kit (r37_west.py): parts are
named `<Part>__<set>` (ashlar for dressed stone, stone for rough, timber, iron), each with metric box UVs (timber grain
along each board's longest edge) so the game dresses them with art/textures/r37_<set>_{albedo,normal,orm}.png. The
vertex colour is a TONE multiplier only (grime, moss at the foot and on top faces, streaks, wear). Plus a convex hull
named *-convcolonly and empties named TextPoint (DoorPoint) where the inscription sits.

  lore_tablet_weathered / _cracked / _leaning   the lore tablet (box 0.42 x 0.62 x 0.08 before)
  lore_waystone     milestone: footing, tapering shaft, cap, gable, an arrow and a tally cut into a sunk panel
  lore_stele        the Order's stele: step, shaft, belt, lettered panel, the Open Door cut in as an arch
  lore_headstone_round / _cross / _slab / _broken
  lore_cairn_stack  stacked, rounded, smooth-shaded stones
  lore_lectern      stone pedestal (ashlar), timber book rest with iron straps

Remodels (same file name, node names, size and pivot as before): art/models/cairn.glb (Stone.001), rune_slab.glb
(Stone + Mark), rock_a.glb (RockA), rock_b.glb (RockB). Their single mesh uses the plain material "stone".

Carving is real geometry: panels are stepped sunk recesses, and glyphs (arrow, tally, rune, door, crack) are pits cut
through the panel floor with walls (the floor face is re-triangulated around the hole polygons).

Blender is Z up. A model's front (inscribed face) looks along Blender +Y = Godot -Z. 1 BU = 1 m, pivot at the base
centre on the ground (stones are buried a little below z=0).

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
TEX = os.path.join(ROOT, "art", "textures")
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ONLY = args[args.index("--only") + 1].split(",") if "--only" in args else []
PREVIEW = args[args.index("--preview") + 1] if "--preview" in args else ""
DO_EXPORT = "--export" in args

# metres per texture tile; props are small, so tighter than the buildings' 6 / 4 / 2 / 2
TILE = {"stone": 3.0, "ashlar": 1.5, "timber": 1.0, "iron": 1.0, "rune": 1.0}
SETS = ["stone", "ashlar", "timber", "iron", "rune"]
TAG_STONE, TAG_FLOOR, TAG_RELIEF, TAG_CRACK, TAG_MARK = 0, 1, 2, 5, 6


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


# --- 2D triangulation of a polygon with holes (ear clipping + bridges) ------------------------------------
def _cross(o, a, b):
    return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])


def _segs_cross(p1, p2, p3, p4):
    d1, d2 = _cross(p3, p4, p1), _cross(p3, p4, p2)
    d3, d4 = _cross(p1, p2, p3), _cross(p1, p2, p4)
    return d1 * d2 < -1e-12 and d3 * d4 < -1e-12


def _in_tri(q, a, b, c):
    return _cross(a, b, q) > 1e-12 and _cross(b, c, q) > 1e-12 and _cross(c, a, q) > 1e-12


def tri_with_holes(P, outer, holes):
    """P: list of (x, y); outer: indices CCW; holes: lists of indices CCW. Returns triples of indices (CCW)."""
    ring = list(outer)
    for h in sorted(holes, key=lambda hh: -max(P[i][0] for i in hh)):
        hh = list(reversed(h))                       # holes run clockwise
        mi = max(range(len(hh)), key=lambda k: P[hh[k]][0])
        M = hh[mi]
        edges = [(ring[k], ring[(k + 1) % len(ring)]) for k in range(len(ring))]
        edges += [(hh[k], hh[(k + 1) % len(hh)]) for k in range(len(hh))]
        best = None
        for vi, V in enumerate(ring):
            d = (P[V][0] - P[M][0]) ** 2 + (P[V][1] - P[M][1]) ** 2
            if best is not None and d >= best[0]:
                continue
            if any(_segs_cross(P[M], P[V], P[a], P[b]) for a, b in edges if a not in (M, V) and b not in (M, V)):
                continue
            best = (d, vi)
        vi = best[1] if best else 0
        ring = ring[:vi + 1] + hh[mi:] + hh[:mi] + [M] + [ring[vi]] + ring[vi + 1:]
    tris = []
    guard = 0
    while len(ring) > 3 and guard < 4000:
        guard += 1
        n = len(ring)
        for i in range(n):
            a, b, c = ring[i - 1], ring[i], ring[(i + 1) % n]
            if _cross(P[a], P[b], P[c]) <= 1e-12:
                continue
            ok = True
            for k in ring:
                if k in (a, b, c):
                    continue
                q = P[k]
                if q == P[a] or q == P[b] or q == P[c]:
                    continue
                if _in_tri(q, P[a], P[b], P[c]):
                    ok = False
                    break
            if ok:
                tris.append((a, b, c))
                ring.pop(i)
                break
        else:
            ring.pop(0)
    if len(ring) == 3:
        tris.append(tuple(ring))
    return tris


class Mk:
    def __init__(self, seed, st="stone"):
        self.bm = bmesh.new()
        self.r = random.Random(seed)
        self.seed = seed
        self.cur = st
        self.tag = self.bm.faces.layers.int.new("tag")
        self.sk = self.bm.faces.layers.int.new("sk")
        self.hullv = []
        self.points = []     # (name, position, matrix3)

    def face(self, vs, tag=0, st=None):
        try:
            f = self.bm.faces.new(vs)
        except ValueError:
            return None
        f[self.tag] = tag
        f[self.sk] = SETS.index(st or self.cur) + 1
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

    def panel(self, f, inset, depth):
        """A stepped sunk recess: a sloped lip, then a steep wall down to the floor. Returns the floor face."""
        st, tg = f[self.sk], f[self.tag]
        n0 = f.normal.copy()
        c0 = f.calc_center_median()
        for t, d in ((inset * 0.45, depth * 0.35), (inset * 0.08, depth * 0.65)):
            bmesh.ops.inset_individual(self.bm, faces=[f], thickness=t, depth=0.0, use_even_offset=True)
            for v in f.verts:
                v.co -= n0 * d
        f[self.tag] = TAG_FLOOR
        f[self.sk] = st
        # ring faces made by the insets inherit the layers of the source face; make sure
        for e in f.edges:
            for lf in e.link_faces:
                if lf[self.sk] == 0:
                    lf[self.sk] = st
        return f

    def cut(self, face, holes, depth, floor_tag=TAG_FLOOR):
        """Cut pits (polygons in the face's (u, v) frame, CCW) through `face` down by `depth`. Returns the floor
        faces (one per hole) and the frame of the original face."""
        fr = self.frame(face)
        st, tg = face[self.sk], face[self.tag]
        c, n, up, right = fr["c"], fr["n"], fr["up"], fr["right"]
        ov = list(face.verts)
        P = [((v.co - c).dot(right), (v.co - c).dot(up)) for v in ov]
        bverts = list(ov)
        hole_idx = []
        for h in holes:
            idx = []
            for (u, v) in h:
                P.append((u, v))
                bverts.append(self.bm.verts.new(c + right * u + up * v))
                idx.append(len(P) - 1)
            hole_idx.append(idx)
        bmesh.ops.delete(self.bm, geom=[face], context='FACES_ONLY')
        for a, b, cc in tri_with_holes(P, list(range(len(ov))), hole_idx):
            self.face([bverts[a], bverts[b], bverts[cc]], tg, SETS[st - 1])
        floors = []
        for idx in hole_idx:
            bot = [self.bm.verts.new(bverts[i].co - n * depth) for i in idx]
            for k in range(len(idx)):
                j = (k + 1) % len(idx)
                self.face([bverts[idx[k]], bverts[idx[j]], bot[j], bot[k]], 0, SETS[st - 1])
            floors.append(self.face(bot, floor_tag, SETS[st - 1]))
        return floors, fr

    def relief(self, fr, pts, h, tag=TAG_RELIEF, du=0.0, dv=0.0, st=None):
        c, n, up, right = fr["c"], fr["n"], fr["up"], fr["right"]
        base = [self.bm.verts.new(c + right * (u + du) + up * (v + dv)) for u, v in pts]
        top = [self.bm.verts.new(c + right * (u + du) + up * (v + dv) + n * h) for u, v in pts]
        self.face(top, tag, st)
        for i in range(len(pts)):
            j = (i + 1) % len(pts)
            self.face([base[i], base[j], top[j], top[i]], tag, st)

    def pebble(self, c, half, rot=0.0, npts=9, tag=0, hull=True, flat=0.0):
        """A chunky hull of a jittered, rounded box: a hand-split stone."""
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
        vs = [v for v in vs if v.is_valid]
        for f in set(f for v in vs for f in v.link_faces):
            f[self.sk] = SETS.index(self.cur) + 1
        if hull:
            self.hullv += vs
        return vs

    def xf(self, m):
        bmesh.ops.transform(self.bm, matrix=m, verts=self.bm.verts)
        self.points = [(n, m @ p, (m.to_3x3() @ q)) for n, p, q in self.points]

    def point(self, name, pos, q=None):
        self.points.append((name, Vector(pos), q if q is not None else Matrix.Identity(3)))


def rest_on_ground(bm, verts, sink=0.015):
    """Lower a lying piece so its lowest vertex just touches (sinks into) the ground."""
    zmin = min(v.co.z for v in verts)
    for v in verts:
        v.co.z -= zmin + sink


# --- tone (vertex colour multiplies the tiling albedo) -------------------------------------------------
def tone(st, co, n, tag, seed, moss_k=1.0):
    if tag == TAG_MARK:
        return (0.95, 0.42, 0.38)
    off = Vector((seed * 1.7, seed * 0.9, seed * 2.3))
    z = co.z
    damp = 1.0 - 0.40 * (1.0 - smooth(0.0, 0.7, z))
    if st == "timber":
        v = (0.85 + 0.22 * fbm(Vector((co.x * 2, co.y * 9, co.z * 2)) + off, 3)) * (0.7 + 0.3 * damp)
        rot = smooth(0.35, 0.75, fbm(co * 1.6 + off, 2)) * 0.25
        return (v * (1 - rot * 0.4), v * (1 - rot * 0.1), v * (1 - rot * 0.5))
    if st == "iron":
        rs = smooth(-0.1, 0.5, fbm(co * 7 + off, 2))
        return (0.8 + 0.3 * rs, 0.72 - 0.1 * rs, 0.65 - 0.15 * rs)
    nz = max(n.z, 0.0)
    patch = smooth(0.05, 0.5, fbm(co * 2.4 + off, 3))
    foot = (1.0 - smooth(0.0, 0.42, z)) * (0.45 + 0.55 * patch)
    top = smooth(0.4, 0.85, n.z) * patch
    moss = min(0.75, (patch * (0.25 + 0.75 * nz) * (0.5 + 0.5 * (1.0 - smooth(0.0, 1.4, z)))) * 0.45 * moss_k + foot * 0.9 * moss_k + top * 0.5 * moss_k)
    v = (1.0 + 0.30 * fbm(co * 1.5 + off, 3) + 0.08 * fbm(co * 9 + off, 2)) * (0.6 + 0.4 * damp)
    c = [v, v * 0.99, v * 1.02]
    c = [c[0] * (1 - moss) + 0.62 * moss, c[1] * (1 - moss) + 0.78 * moss, c[2] * (1 - moss) + 0.5 * moss]
    streak = smooth(0.1, 0.6, fbm(Vector((co.x * 2.5, co.y * 2.5, co.z * 0.25)) + off, 2)) * (1.0 - nz) * 0.32
    c = [x * (1 - streak) for x in c]
    lich = smooth(0.32, 0.58, fbm(co * 13.0 + off, 2)) * (1.0 - top) * smooth(0.15, 0.6, z) * 0.45 * moss_k
    c = [c[i] * (1 - lich) + (1.05, 1.05, 0.85)[i] * lich for i in range(3)]
    if abs(n.z) < 0.35 and abs(n.x) > 0.3 and abs(n.y) > 0.3:      # worn, lightened chamfers
        c = [x * 1.14 for x in c]
    if tag == TAG_FLOOR:
        c = [x * 0.78 for x in c]
    elif tag == TAG_CRACK:
        c = [x * (0.5 if st == 'stone' and tag == TAG_CRACK and False else 0.3) for x in c]
    return tuple(min(1.3, x) for x in c)


def finish(mk, name, moss_k=1.0, smooth_sets=(), sharp=40.0, split=True, exact=None):
    """Triangulate, box-UV and tone the bmesh, then make one object per material set: `<name>__<set>`.
    `exact` = {set: node name} keeps legacy node names; with split=False the single set keeps `name`."""
    bm = mk.bm
    bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method='BEAUTY', ngon_method='EAR_CLIP')
    bm.normal_update()
    for e in bm.edges:
        e.smooth = True
        if len(e.link_faces) == 2 and e.link_faces[0].normal.length > 1e-6 and e.link_faces[1].normal.length > 1e-6:
            ang = math.degrees(e.link_faces[0].normal.angle(e.link_faces[1].normal))
            e.smooth = ang < sharp
    uv = bm.loops.layers.uv.new("UVMap")
    col = bm.loops.layers.color.new("Col")
    objs = []
    present = sorted({f[mk.sk] for f in bm.faces})
    for si in present:
        st = SETS[si - 1] if si > 0 else mk.cur
        b2 = bm.copy()
        sk2 = b2.faces.layers.int.get("sk")
        tag2 = b2.faces.layers.int.get("tag")
        b2.faces.ensure_lookup_table()
        bmesh.ops.delete(b2, geom=[f for f in b2.faces if f[sk2] != si], context='FACES')
        uv2 = b2.loops.layers.uv.get("UVMap")
        col2 = b2.loops.layers.color.get("Col")
        tile = TILE[st]
        sm = st in smooth_sets
        b2.normal_update()
        for f in b2.faces:
            f.smooth = sm
            n = f.normal
            ax = max(range(3), key=lambda i: abs(n[i]))
            grain = None
            if st == "timber":
                le = max(f.edges, key=lambda e: e.calc_length())
                d = (le.verts[1].co - le.verts[0].co).normalized()
                t1 = n.cross(d)
                if t1.length > 1e-6:
                    grain = (t1.normalized(), d)
            for l in f.loops:
                co = l.vert.co
                if grain is not None:
                    l[uv2].uv = (co.dot(grain[0]) / tile, co.dot(grain[1]) / tile)
                elif ax == 0:
                    l[uv2].uv = (co.y / tile, co.z / tile)
                elif ax == 1:
                    l[uv2].uv = (co.x / tile, co.z / tile)
                else:
                    l[uv2].uv = (co.x / tile, co.y / tile)
                nn = l.vert.normal if sm else n
                c = tone(st, co, nn, f[tag2], mk.seed, moss_k)
                l[col2] = (c[0], c[1], c[2], 1.0)
        nm = (exact or {}).get(st) or (("%s__%s" % (name, st)) if split else name)
        me = bpy.data.meshes.new(nm)
        b2.to_mesh(me)
        b2.free()
        me.materials.append(plain_material(st))
        ob = bpy.data.objects.new(nm, me)
        bpy.context.scene.collection.objects.link(ob)
        me.color_attributes.active_color = me.color_attributes["Col"]
        me.color_attributes.render_color_index = list(me.color_attributes.keys()).index("Col")
        objs.append(ob)
    return objs


def tri_total(objs):
    return sum(len(p.vertices) - 2 for o in objs for p in o.data.polygons)


def plain_material(name):
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    return m


def hull_object(mk, name):
    seen = {}
    for v in mk.hullv:
        if v.is_valid:
            seen[tuple(round(c, 5) for c in v.co)] = v.co.copy()
    bm = bmesh.new()
    vs = [bm.verts.new(p) for p in seen.values()]
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


def rect(hw, hh, du=0.0, dv=0.0):
    return [(du - hw, dv - hh), (du + hw, dv - hh), (du + hw, dv + hh), (du - hw, dv + hh)]


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
        rings.append(oct_ring(r, 0, 0, z, w, D, 0.014, j, r.uniform(-0.02, 0.02), zo, 0.012 if z > 0.4 else 0.0))
    faces, vs = mk.loft(rings)
    floor = mk.panel(faces[(2, 2)], 0.05, 0.016)
    fr = mk.frame(floor)
    hw, hh = fr["hw"], fr["hh"]
    holes = []
    for k, (wf, dz) in enumerate(([(0.7, 0.03)] if variant == 'cracked' else [(0.55, 0.07), (0.7, 0.0)] + ([(0.4, -0.07)] if variant == 'weathered' else []))):
        holes.append(rect(hw * wf * 0.5, 0.008, -hw * 0.25 if variant == "cracked" else 0.0, dz))
    if variant == "cracked":
        # a crack down the right of the panel: a thin dark pit, zig-zagging
        us = [hw * 0.55 + r.uniform(-0.02, 0.02) for _ in range(3)]
        vs_ = [hh * 0.97 - k * (hh * 1.94) / 2 for k in range(3)]
        left = [(us[k] - 0.006, vs_[k]) for k in range(3)]
        right = [(us[k] + 0.006, vs_[k]) for k in range(3)]
        holes.append(left + right[::-1])
    pits, _ = mk.cut(floor, holes, 0.012)
    if variant == "cracked":
        # make the crack pit read as black
        pits[-1][mk.tag] = TAG_CRACK
        lr = []
        for z, w in [(0.0, 0.17), (0.08, 0.12)]:
            lr.append(oct_ring(r, 0, 0, z, w, 0.075, 0.012, 0.006, 0.3))
        _, lv = mk.loft(lr, hull=False)
        rm = Matrix.Translation((0.24, 0.20, 0.0)) @ Matrix.Rotation(0.7, 4, 'Z') @ Matrix.Rotation(1.35, 4, 'X')
        vl = [v for ring in lv for v in ring]
        bmesh.ops.transform(mk.bm, matrix=rm, verts=vl)
        rest_on_ground(mk.bm, vl)
    mk.point("TextPoint", fr["c"] + fr["n"] * 0.004 + fr["up"] * 0.05)
    if variant == "leaning":
        for (x, y, s) in [(-0.1, -0.1, 0.07), (0.12, -0.12, 0.06)]:
            mk.pebble(Vector((x, y, 0.02)), (s * 1.3, s, s * 0.75), r.random() * 3, 8)
        mk.xf(Matrix.Rotation(0.30, 4, 'X') @ Matrix.Rotation(0.11, 4, 'Y'))
    return mk


# --- waystone -----------------------------------------------------------------------------------------
def waystone():
    mk = Mk(51)
    r = mk.r
    j = 0.016
    spec = [(-0.35, 0.76, 0.60, 0.03), (0.0, 0.78, 0.62, 0.03), (0.07, 0.76, 0.60, 0.04), (0.10, 0.62, 0.48, 0.03),
            (0.14, 0.60, 0.46, 0.03), (0.72, 0.56, 0.43, 0.025), (1.20, 0.53, 0.41, 0.025), (1.38, 0.50, 0.38, 0.025),
            (1.43, 0.61, 0.49, 0.03), (1.54, 0.61, 0.49, 0.03), (1.56, 0.52, 0.40, 0.025), (1.84, 0.05, 0.40, 0.01)]
    rings = [oct_ring(r, 0, 0, z, w, d, ch, j, r.uniform(-0.04, 0.04), None, 0.03 if z > 0.3 else 0.0) for z, w, d, ch in spec]
    faces, vs = mk.loft(rings)
    mk.hullv = [v for v in mk.hullv if v.co.z < 1.6]      # solid to the cap: the gable is not part of the collider
    floor = mk.panel(faces[(5, 2)], 0.05, 0.016)
    fr0 = mk.frame(floor)
    arrow = [(-0.13, -0.026), (0.03, -0.026), (0.03, -0.075), (0.14, 0.0), (0.03, 0.075), (0.03, 0.026), (-0.13, 0.026)]
    arrow = [(u * 1.25, v * 1.25 + 0.08) for u, v in arrow]
    tally = [rect(0.01, 0.035, (i - 1) * 0.06, -0.11) for i in range(3)]
    mk.cut(floor, [arrow] + tally, 0.022)
    mk.point("TextPoint", fr0["c"] + fr0["n"] * 0.004 + fr0["up"] * -0.04)
    # the iron bell hook on the road side
    f2 = mk.frame(faces[(7, 0)])
    mk.relief(f2, rect(0.07, 0.012, 0.02, 0.0), 0.045, st="iron")
    mk.relief(f2, rect(0.01, 0.03, 0.08, -0.03), 0.045, st="iron")
    return mk


# --- stele -------------------------------------------------------------------------------------------
def stele():
    mk = Mk(61)
    r = mk.r
    j = 0.02
    step = [oct_ring(r, 0, 0, z, w, d, 0.04, j, r.uniform(-0.01, 0.01)) for z, w, d in [(-0.3, 1.25, 0.70), (0.16, 1.25, 0.70), (0.22, 1.13, 0.62)]]
    mk.cur = "ashlar"
    mk.loft(step)
    mk.cur = "stone"
    ts = [(0.12, 0.92, 0.34), (0.88, 0.92, 0.34), (1.72, 0.91, 0.33), (1.78, 0.91, 0.33), (2.30, 0.90, 0.32), (2.74, 0.06, 0.32)]
    rings = [oct_ring(r, 0, 0, z, w, d, 0.025, j * 0.8, r.uniform(-0.02, 0.02), None, 0.03 if z > 1.0 else 0.0) for z, w, d in ts]
    faces, vs = mk.loft(rings)
    for zz in ((0.46, 0.54), (2.26, 2.34)):
        belt = [oct_ring(r, 0, 0, z, w, d, 0.02, 0.006) for z, w, d in [(zz[0], 1.0, 0.40), (zz[1], 1.0, 0.40)]]
        mk.loft(belt, bot=True, hull=False)
    fl = mk.panel(faces[(1, 2)], 0.08, 0.024)
    fr = mk.frame(fl)
    mk.point("TextPoint", fr["c"] + fr["n"] * 0.004)
    fd = mk.panel(faces[(3, 2)], 0.07, 0.024)
    frd = mk.frame(fd)
    arch = [(0.12, -0.17), (0.12, 0.05)] + [(math.cos(a) * 0.12, 0.05 + math.sin(a) * 0.12) for a in (math.pi / 6, math.pi / 3, math.pi / 2, 2 * math.pi / 3, 5 * math.pi / 6)] + [(-0.12, 0.05), (-0.12, -0.17)]
    floors, _ = mk.cut(fd, [arch], 0.022)
    gap = [(0.05, -0.15), (0.05, 0.04), (0.0, 0.085), (-0.05, 0.04), (-0.05, -0.15)]
    gfl, _ = mk.cut(floors[0], [gap], 0.04, floor_tag=TAG_CRACK)
    mk.point("DoorPoint", frd["c"] + frd["n"] * 0.004)
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
        rings += [oct_ring(r, 0, 0, z, W, T, 0.02, j, 0.0, None, 0.012) for z in (0.22, 0.70)]
        for a in (28, 52, 72, 87):
            ar = math.radians(a)
            rings.append(oct_ring(r, 0, 0, 0.70 + R * math.sin(ar), 2 * R * math.cos(ar), T, 0.02, j * 0.5))
        faces, _ = mk.loft(rings)
        fl = mk.panel(faces[(2, 2)], 0.05, 0.02)
        fr = mk.frame(fl)
        mk.point("TextPoint", fr["c"] + fr["n"] * 0.004)
    elif kind == "slab":
        sp = [(-0.30, W + 0.01, T), (0.0, W, T), (0.22, W, T), (0.70, W, T), (0.80, W, T), (0.80, W + 0.07, T + 0.06), (0.86, W + 0.07, T + 0.06),
              (0.88, W, T), (1.0, 0.05, T * 0.9)]
        rings = [oct_ring(r, 0, 0, z, w, d, 0.02, j, 0.0, None, 0.012 if z > 0.6 else 0.0) for z, w, d in sp]
        faces, _ = mk.loft(rings)
        fl = mk.panel(faces[(2, 2)], 0.05, 0.02)
        fr = mk.frame(fl)
        mk.point("TextPoint", fr["c"] + fr["n"] * 0.004)
    elif kind == "cross":
        plinth = [oct_ring(r, 0, 0, z, w, d, 0.03, j, 0.0, None, 0.015 if z > 0.1 else 0.0) for z, w, d in [(-0.30, 0.46, 0.32), (0.0, 0.46, 0.32), (0.20, 0.45, 0.31), (0.25, 0.39, 0.26)]]
        mk.cur = "ashlar"
        faces, _ = mk.loft(plinth)
        mk.cur = "stone"
        fl = mk.panel(faces[(1, 2)], 0.035, 0.016)
        fr = mk.frame(fl)
        mk.point("TextPoint", fr["c"] + fr["n"] * 0.004)
        # a worn cross: thick chamfers, a softened bevel at every end, chips, an uneven stem
        stem = [oct_ring(r, 0, 0, z, w, T, 0.04, j, r.uniform(-0.03, 0.03), None, 0.02 if z > 0.5 else 0.0)
                for z, w in [(0.2, 0.21), (0.66, 0.18), (0.96, 0.175), (1.0, 0.13)]]
        mk.loft(stem)
        arms = [oct_ring(r, 0, 0, z, w, T, 0.04, j * 0.8, r.uniform(-0.03, 0.03), None, 0.02 if z > 0.7 else 0.0)
                for z, w in [(0.675, 0.5), (0.70, 0.60), (0.82, 0.59), (0.845, 0.50)]]
        mk.loft(arms, bot=True)
    else:
        sp = [(-0.30, W + 0.01), (0.0, W), (0.14, W), (0.46, W), (0.56, W), (0.60, W * 0.97)]
        slope = lambda x, y: -x * 0.45 + 0.05 * math.sin(x * 25)
        rings = []
        for k, (z, w) in enumerate(sp):
            rings.append(oct_ring(r, 0, 0, z, w, T, 0.02, j, 0.0, slope if k >= 4 else None))
        faces, _ = mk.loft(rings)
        fl = mk.panel(faces[(2, 2)], 0.05, 0.02)
        fr = mk.frame(fl)
        mk.point("TextPoint", fr["c"] + fr["n"] * 0.004)
        pr = []
        for z, w in [(0.0, 0.48), (0.2, 0.46), (0.36, 0.30)]:
            pr.append(oct_ring(r, 0, 0, z, w, T, 0.02, 0.008, 0.2, (lambda x, y: -x * 0.5) if z > 0.3 else None))
        _, pv = mk.loft(pr, bot=True, hull=False)
        rm = Matrix.Translation((0.08, 0.62, 0.0)) @ Matrix.Rotation(0.5, 4, 'Z') @ Matrix.Rotation(-math.pi / 2 + 0.12, 4, 'X')
        vl = [v for ring in pv for v in ring]
        bmesh.ops.transform(mk.bm, matrix=rm, verts=vl)
        rest_on_ground(mk.bm, vl)          # the head lies on the ground, not hovering over it
    return mk


# --- cairn --------------------------------------------------------------------------------------------
def cairn_stack(seed=81, size=(0.5, 0.5, 0.6), layers=(6, 5, 4, 2, 1), loose=3, npts=10):
    mk = Mk(seed, "stone")
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
    mk = Mk(91, "ashlar")
    r = mk.r
    j = 0.006
    pl = [oct_ring(r, 0, 0, z, w, d, 0.025, j) for z, w, d in [(-0.10, 0.64, 0.54), (0.0, 0.62, 0.52), (0.10, 0.61, 0.51), (0.14, 0.50, 0.42)]]
    mk.loft(pl)
    sh = [oct_ring(r, 0, 0, z, w, d, 0.03, j, r.uniform(-0.02, 0.02), None, 0.015 if z > 0.5 else 0.0) for z, w, d in
          [(0.12, 0.30, 0.28), (0.40, 0.26, 0.24), (0.85, 0.28, 0.26), (0.96, 0.36, 0.32), (1.02, 0.46, 0.38)]]
    mk.loft(sh)
    tilt = Matrix.Translation(Vector((0, 0, 1.10))) @ Matrix.Rotation(-0.45, 4, 'X')
    mk.cur = "timber"
    board = [oct_ring(r, 0, 0, z, 0.62, 0.46, 0.015, 0.004) for z in (-0.03, 0.03)]
    _, bv = mk.loft(board, bot=True)
    lip = [oct_ring(r, 0, 0.21, z, 0.60, 0.05, 0.01, 0.003) for z in (0.03, 0.09)]
    _, lv = mk.loft(lip, bot=True)
    back = [oct_ring(r, 0, -0.20, z, 0.60, 0.05, 0.01, 0.003) for z in (0.03, 0.10)]
    _, kv = mk.loft(back, bot=True)
    mk.cur = "iron"
    straps = []
    for x in (-0.2, 0.2):                              # iron straps across the board
        sr = [oct_ring(r, x, 0, z, 0.05, 0.47, 0.006, 0.0) for z in (0.03, 0.045)]
        _, sv = mk.loft(sr, bot=True, hull=False)
        straps.append(sv)
    mk.cur = "ashlar"
    bmesh.ops.transform(mk.bm, matrix=tilt, verts=[v for g in (bv, lv, kv) + tuple(straps) for ring in g for v in ring])
    mk.point("TextPoint", tilt @ Vector((0, -0.02, 0.05)), tilt.to_3x3())
    return mk


# --- remodels ------------------------------------------------------------------------------------------
def rune_slab():
    mk = Mk(101, "stone")
    r = mk.r
    j = 0.004
    zoff = lambda x, y: -x * 0.07 + 0.012 * math.sin(x * 40)
    spec = [(0.0, 0.43), (0.06, 0.456), (0.17, 0.456), (0.67, 0.452), (0.70, 0.445), (0.72, 0.42)]
    rings = []
    for k, (z, w) in enumerate(spec):
        rings.append(oct_ring(r, 0, 0, z, w, 0.129, 0.016, j, r.uniform(-0.01, 0.01), zoff if k >= 4 else None, 0.01 if k >= 3 else 0.0))
    faces, _ = mk.loft(rings)
    floor = mk.panel(faces[(2, 2)], 0.045, 0.012)
    # one rune cut into the panel: a stave with two rising branches, a single simple polygon
    glyph = [(-0.015, -0.19), (0.015, -0.19), (0.015, -0.115), (0.095, -0.035), (0.095, 0.005), (0.015, -0.075), (0.015, 0.08),
             (0.095, 0.16), (0.095, 0.20), (0.015, 0.12), (0.015, 0.19), (-0.015, 0.19)]
    floors, fr = mk.cut(floor, [glyph], 0.012)
    ffr = mk.frame(floors[0])
    poly = [((p.co - ffr["c"]).dot(ffr["right"]), (p.co - ffr["c"]).dot(ffr["up"])) for p in floors[0].verts]
    stone = finish(mk, "Stone", split=False, exact={"stone": "Stone"})
    mm = Mk(102, "rune")
    top = [mm.bm.verts.new(ffr["c"] + ffr["right"] * u + ffr["up"] * v + ffr["n"] * 0.003) for u, v in poly]
    mm.face(top, TAG_MARK, "rune")
    mark = finish(mm, "Mark", split=False, exact={"rune": "Mark"})
    return mk, stone + mark


def rock(seed, lo, hi, N, R, planes, name, crack_cols):
    mk = Mk(seed, "stone")
    r = mk.r
    rings = []
    ph0 = r.random() * math.tau
    for k in range(R):
        t = k / (R - 1)
        prof = 0.78 + 0.22 * math.sin(math.pi * min(1.0, t * 1.2)) - 0.34 * smooth(0.65, 1.0, t)
        ring = []
        for jx in range(N):
            ang = ph0 + math.tau * (jx + 0.5 * (k % 2) * 0.6) / N + r.uniform(-0.18, 0.18) * math.tau / N
            rad = prof * (1.0 + r.uniform(-0.08, 0.08)) * (1.0 + 0.12 * fbm(Vector((math.cos(ang) * 1.3, math.sin(ang) * 1.3, t * 2.0)) + Vector((seed, 0, 0)), 2))
            z = t + r.uniform(-0.02, 0.02) * (0 < k < R - 1)
            ring.append([math.cos(ang) * rad, math.sin(ang) * rad, z])
        rings.append(ring)
    # chisel: planes trimming the bulges into flat-ish faces (smooth-shaded, creased where they meet)
    pl = []
    for i in range(planes):
        a = r.random() * math.tau
        e = r.uniform(-0.15, 0.55)
        n = Vector((math.cos(a) * math.cos(e), math.sin(a) * math.cos(e), math.sin(e))).normalized()
        pl.append((n, r.uniform(0.55, 0.78)))
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
    # cracks: a column of vertices drawn in, the faces beside it darkened
    crack_faces = set()
    for cj in crack_cols:
        j0 = cj
        for k in range(1, R - 1):
            j0 = (j0 + r.choice((-1, 0, 0, 1))) % N
            v = vs[k][j0]
            v.co.x *= 0.84
            v.co.y *= 0.84
            for f in v.link_faces:
                crack_faces.add(f)
    for f in crack_faces:
        f[mk.tag] = TAG_FLOOR              # a shaded groove, not black
    fit_bbox(mk, lo, hi)
    for v in mk.bm.verts:
        v.co.z = max(v.co.z, 0.0)
    return mk, finish(mk, name, moss_k=1.2, smooth_sets=("stone",), sharp=38.0, split=False, exact={"stone": name})


# --- build / export / preview --------------------------------------------------------------------------
def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _imgs.clear()


def build(name):
    """Returns dict(objs=[mesh objects], col, empties, path)"""
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
        objs = finish(mk, "Stone.001", moss_k=1.1, smooth_sets=("stone",), sharp=55.0, split=False, exact={"stone": "Stone.001"})
        return dict(objs=objs, col=None, empties=[], path=os.path.join(LEGACY, "cairn.glb"))
    elif name == "legacy_rune_slab":
        mk, objs = rune_slab()
        return dict(objs=objs, col=None, empties=[], path=os.path.join(LEGACY, "rune_slab.glb"))
    elif name == "legacy_rock_a":
        mk, objs = rock(201, (-0.863, -0.76, 0.0), (0.808, 0.76, 1.099), 16, 9, 12, "RockA", (3,))
        return dict(objs=objs, col=None, empties=[], path=os.path.join(LEGACY, "rock_a.glb"))
    elif name == "legacy_rock_b":
        mk, objs = rock(207, (-0.753, -0.689, 0.0), (0.761, 0.669, 1.415), 16, 9, 13, "RockB", (5, 11))
        return dict(objs=objs, col=None, empties=[], path=os.path.join(LEGACY, "rock_b.glb"))
    else:
        raise KeyError(name)
    cname = {"tablet": "Tablet", "headstone": "Headstone"}.get(name.split("_")[0], name.split("_")[0].capitalize())
    smooth_sets = ("stone",) if name == "cairn_stack" else ()
    objs = finish(mk, cname, smooth_sets=smooth_sets, sharp=55.0)
    col = hull_object(mk, cname + "-convcolonly")
    return dict(objs=objs, col=col, empties=empties(mk), path=path)


def export(items, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.object.select_all(action='DESELECT')
    for o in items:
        o.select_set(True)
    kw = dict(filepath=path, export_format='GLB', use_selection=True, export_apply=True, export_yup=True,
              export_materials='EXPORT', export_image_format='NONE', export_normals=True, export_texcoords=True)
    try:
        bpy.ops.export_scene.gltf(export_vertex_color='ACTIVE', **kw)
    except TypeError:
        try:
            bpy.ops.export_scene.gltf(export_active_vertex_color_when_no_material=True, **kw)
        except TypeError:
            bpy.ops.export_scene.gltf(**kw)
    print("EXPORTED", path)


_imgs = {}


def _img(path, cs):
    if path not in _imgs:
        im = bpy.data.images.load(path)
        im.colorspace_settings.name = cs
        _imgs[path] = im
    return _imgs[path]


def preview_material(st):
    """What the game will show: albedo x vertex-colour tone, normal, and ORM (AO, roughness, metal in R, G, B)."""
    m = bpy.data.materials.new("pv_" + st)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    vc = nt.nodes.new("ShaderNodeVertexColor")
    vc.layer_name = "Col"
    if st == "rune":
        nt.links.new(vc.outputs[0], b.inputs["Base Color"])
        nt.links.new(vc.outputs[0], b.inputs["Emission Color"])
        b.inputs["Emission Strength"].default_value = 2.0
        return m
    tx = lambda k, cs: _img(os.path.join(TEX, "r37_%s_%s.png" % (st, k)), cs)
    alb = nt.nodes.new("ShaderNodeTexImage")
    alb.image = tx("albedo", "sRGB")
    orm = nt.nodes.new("ShaderNodeTexImage")
    orm.image = tx("orm", "Non-Color")
    nor = nt.nodes.new("ShaderNodeTexImage")
    nor.image = tx("normal", "Non-Color")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    mp = nt.nodes.new("ShaderNodeMapping")        # the game's prop_mat: uv1_scale 3, normal_scale 0.35
    mp.inputs["Scale"].default_value = (3.0, 3.0, 3.0)
    nt.links.new(tc.outputs["UV"], mp.inputs["Vector"])
    for im in (alb, orm, nor):
        nt.links.new(mp.outputs[0], im.inputs["Vector"])
    mul = nt.nodes.new("ShaderNodeMix")
    mul.data_type = 'RGBA'
    mul.blend_type = 'MULTIPLY'
    mul.inputs[0].default_value = 1.0
    nt.links.new(alb.outputs[0], mul.inputs[6])
    nt.links.new(vc.outputs[0], mul.inputs[7])
    sep = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(orm.outputs[0], sep.inputs[0])
    ao = nt.nodes.new("ShaderNodeMix")
    ao.data_type = 'RGBA'
    ao.blend_type = 'MULTIPLY'
    ao.inputs[0].default_value = 1.0
    nt.links.new(mul.outputs[2], ao.inputs[6])
    nt.links.new(sep.outputs[0], ao.inputs[7])
    nt.links.new(ao.outputs[2], b.inputs["Base Color"])
    nt.links.new(sep.outputs[1], b.inputs["Roughness"])
    nt.links.new(sep.outputs[2], b.inputs["Metallic"])
    nm = nt.nodes.new("ShaderNodeNormalMap")
    nm.inputs["Strength"].default_value = 0.35
    nt.links.new(nor.outputs[0], nm.inputs["Color"])
    nt.links.new(nm.outputs[0], b.inputs["Normal"])
    return m


def preview(label, meshes, focus):
    if not PREVIEW:
        return
    os.makedirs(PREVIEW, exist_ok=True)
    sc = bpy.context.scene
    pvm = {}
    for o in meshes:
        st = o.data.materials[0].name if o.data.materials else "stone"
        if st not in pvm:
            pvm[st] = preview_material(st)
        o.data.materials.clear()
        o.data.materials.append(pvm[st])
    try:
        sc.render.engine = 'BLENDER_EEVEE'
    except TypeError:
        sc.render.engine = 'BLENDER_WORKBENCH'
    try:
        sc.eevee.taa_render_samples = 32
    except Exception:
        pass
    sc.render.resolution_x = sc.render.resolution_y = 960
    sc.view_settings.view_transform = 'Standard'
    pts = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
    mn = Vector((min(p[i] for p in pts) for i in range(3)))
    mx = Vector((max(p[i] for p in pts) for i in range(3)))
    ctr = (mn + mx) / 2
    size = (mx - mn).length
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
        meshes = b["objs"]
        tot = tri_total(meshes)
        budget = next((v for k, v in TRI_BUDGET.items() if nm.startswith(k)), 0)
        print("TRIS %-18s %4d (budget %d)%s  parts %s" % (nm, tot, budget, "" if tot < budget else "  OVER", [o.name for o in meshes]))
        if DO_EXPORT:
            export(meshes + ([b["col"]] if b["col"] else []) + b["empties"], b["path"])
        if PREVIEW:
            if b["col"]:
                b["col"].hide_render = True
                b["col"].hide_viewport = True
            focus = b["empties"][0].location.copy() if b["empties"] else Vector((0, 0, 0.3))
            if not b["empties"]:
                pts = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
                focus = sum(pts, Vector()) / len(pts)
            preview(nm, meshes, focus)
