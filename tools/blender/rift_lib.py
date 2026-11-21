"""The Ashen Rift, from scratch (r39, 21 Nov): the Blender helpers rift_kit.py builds the rift's pieces with.

  ROCK     natural basalt masses: big overlapping blocks fused into one skin (voxel remesh), cut where a stair or a ledge is
           carved into them (boolean), roughened with noise away from the cuts, then dissolved into broad flat facets (planar
           decimate): chunky hand-cut rock in the Enshrouded manner, not stacked boxes. Vertex colour for the game's RockKit
           shader (core/world/realm/rock_kit.gdshader): r cavity / contact shade, g 1 (no moss: the rift burned), b 1 - ember
           (the lowest metres over the lava glow in the "ash" style), a strata (a darker line under each ledge).
  MASONRY  chunky dressed blocks (bevelled, a little off true) for steps, parapets, kerbs and fire plinths, in the WestKit sets
           Hearthward and the West Marches are built of ("stone" for the rough parapets, "hewn" for the dressed steps and flags, as the
           beacons and the modelled masonry use it): vertex colour is plain weathering, soot low and near
           the lava, pale ash on the tops; no moss, no tint.

Frame as everywhere: Blender (x, y, z) = the rift's game coordinates (x, -z, y) (chasm on x 0, z south; 1 BU = 1 m).
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import bmesh
from mathutils import Vector, Matrix, noise
import r37_west as W
from r37_west import reset, make_mat, export, preview, MODELS, fbm, smoothstep   # noqa: F401

LAVA = -15.5


def bl(p):
    """Game (x, y, z) -> Blender."""
    return Vector((p[0], -p[2], p[1]))


def gm(v):
    """Blender -> game (x, y, z)."""
    return (v.x, v.z, -v.y)


# ============================================================================================ rock
def _box_bm(bm, c, half, yaw=0.0, pitch=0.0, roll=0.0):
    """A box at Blender point c with Blender half sizes; yaw about up, then `pitch` raises its local +x end (about its local y), `roll`
    turns it about its local x (radians)."""
    rot = Matrix.Rotation(yaw, 4, 'Z') @ Matrix.Rotation(-pitch, 4, 'Y') @ Matrix.Rotation(roll, 4, 'X')
    M = Matrix.Translation(Vector(c)) @ rot @ Matrix.Diagonal((half[0] * 2, half[1] * 2, half[2] * 2, 1.0))
    bmesh.ops.create_cube(bm, size=1.0, matrix=M)


def _obj_from_bm(bm, name):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def _apply(ob, mod):
    bpy.ops.object.select_all(action='DESELECT')
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.modifier_apply(modifier=mod.name)


def blocks_obj(name, blocks):
    """blocks: [(centre game xyz, half size (x across, y up, z along game z), yaw deg about up, tilt deg about game x, roll deg)] ->
    one object of overlapping boxes (Blender frame)."""
    bm = bmesh.new()
    for b in blocks:
        c, h = b[0], b[1]
        yaw = math.radians(b[2]) if len(b) > 2 else 0.0
        pitch = math.radians(b[3]) if len(b) > 3 else 0.0
        roll = math.radians(b[4]) if len(b) > 4 else 0.0
        _box_bm(bm, bl(c), (h[0], h[2], h[1]), yaw, pitch, roll)
    return _obj_from_bm(bm, name)


class _Keeps:
    """The walk volumes (game AABBs ((x0, y0, z0), (x1, y1, z1))) in Blender space, bucketed on a 4 m grid for the per-vertex test."""
    REACH = 2.6

    def __init__(self, boxes):
        self.boxes = []
        self.grid = {}
        for a, b in boxes:
            pa, pb = bl(a), bl(b)
            lo = Vector((min(pa.x, pb.x), min(pa.y, pb.y), min(pa.z, pb.z)))
            hi = Vector((max(pa.x, pb.x), max(pa.y, pb.y), max(pa.z, pb.z)))
            k = len(self.boxes)
            self.boxes.append((lo, hi))
            for i in range(int(math.floor((lo.x - self.REACH) / 4.0)), int(math.floor((hi.x + self.REACH) / 4.0)) + 1):
                for j in range(int(math.floor((lo.y - self.REACH) / 4.0)), int(math.floor((hi.y + self.REACH) / 4.0)) + 1):
                    self.grid.setdefault((i, j), []).append(k)

    def dist(self, co):
        """Distance to the nearest walk volume (0 inside), or a large number."""
        best = 99.0
        for k in self.grid.get((int(math.floor(co.x / 4.0)), int(math.floor(co.y / 4.0))), ()):
            lo, hi = self.boxes[k]
            dx = max(lo.x - co.x, 0.0, co.x - hi.x)
            dy = max(lo.y - co.y, 0.0, co.y - hi.y)
            dz = max(lo.z - co.z, 0.0, co.z - hi.z)
            d = math.sqrt(dx * dx + dy * dy + dz * dz)
            if d < best:
                best = d
        return best


def rock_mass(name, blocks, voxel=0.45, cuts=(), disp=0.55, freq=0.16, facet=9.0, seed=1, keep=(), flat=(), tris=None, strata=0.0):
    """One natural rock from overlapping blocks: fused (voxel remesh), the cuts taken out (each a block like `blocks`), the skin roughened
    with noise and, with `tris`, collapsed to about that many triangles (broad angular facets). Near the `keep` volumes (the walks: game
    AABBs) the skin may only sink, never grow towards them, and a surface facing up inside one (a floor under the flags) stays true."""
    ob = blocks_obj(name, blocks)
    rm = ob.modifiers.new("vox", 'REMESH')
    rm.mode = 'VOXEL'
    rm.voxel_size = voxel
    rm.use_smooth_shade = False
    _apply(ob, rm)
    if cuts:
        cut = blocks_obj(name + "_cut", cuts)
        bo = ob.modifiers.new("cut", 'BOOLEAN')
        bo.operation = 'DIFFERENCE'
        bo.object = cut
        for solver in ('MANIFOLD', 'EXACT'):
            try:
                bo.solver = solver
                break
            except TypeError:
                continue
        _apply(ob, bo)
        bpy.data.objects.remove(cut)
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.normal_update()
    off = Vector((seed * 13.1, seed * 7.7, seed * 3.3))
    K = _Keeps(list(keep) + list(flat))
    moves = []
    for v in bm.verts:
        co = v.co
        dk = K.dist(co)
        p = co * freq + off
        d = fbm(p, 4) * disp * 1.6 + (fbm(p * 3.1 + Vector((5, 1, 2)), 2)) * disp * 0.45
        d += fbm(co * freq * 0.38 + off * 1.7, 2) * disp * 2.4          # the shape: big swells and hollows, never a box's face
        d *= 1.0 + 1.1 * smoothstep(3.0, 9.0, dk)                       # away from the walks the rock is rougher still
        steep = 1.0 - smoothstep(0.35, 0.6, abs(v.normal.z))
        if steep > 0.0:                                                  # columnar joints: upright grooves every 1.5-3 m on the faces
            ph = (co.x + co.y) * 0.62 + fbm(co * 0.09 + off, 2) * 3.0
            d -= smoothstep(0.78, 0.98, abs(math.sin(ph))) * 0.45 * steep
        if dk < K.REACH:
            if v.normal.z > 0.55 and dk < 0.35:
                d = 0.0                                                  # a floor under a walk: true
            else:
                d = -abs(d) * (0.45 + 0.55 * smoothstep(0.0, K.REACH, dk))   # beside a walk: only sinks back, never flat
        moves.append(v.normal * d)
    for v, m in zip(bm.verts, moves):
        v.co += m
    bm.to_mesh(ob.data)
    bm.free()
    tri = ob.modifiers.new("tri", 'TRIANGULATE')
    _apply(ob, tri)
    if tris and len(ob.data.polygons) > tris:          # collapsed to a low count: broad angular facets, chunky (a dissolve left box faces)
        dc = ob.modifiers.new("lod", 'DECIMATE')
        dc.decimate_type = 'COLLAPSE'
        dc.ratio = tris / float(len(ob.data.polygons))
        _apply(ob, dc)
    for p in ob.data.polygons:
        p.use_smooth = False
    return ob


EMBER_LINES = {}          # object name -> [(a, b, r)]: game segments the rock glows along (a lavafall's cheeks), kept for the re-colour


def _seg_d(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-6)))
    return (p - (a + ab * t)).length


def rock_colour(ob, ember_top=LAVA + 2.6, ember=True, seed=3):
    """RockKit vertex colour (see the module notes) on a rock object, per face corner."""
    me = ob.data
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.normal_update()
    cav = {}
    for v in bm.verts:
        if not v.link_edges:
            cav[v.index] = 0.0
            continue
        s = 0.0
        for e in v.link_edges:
            o = e.other_vert(v)
            s += (o.co - v.co).dot(v.normal) / max((o.co - v.co).length, 1e-4)
        cav[v.index] = s / len(v.link_edges)          # > 0: neighbours stand above the vertex (a crevice)
    lay = bm.loops.layers.color.get("Col") or bm.loops.layers.color.new("Col")
    prv = bm.loops.layers.color.get("Prev") or bm.loops.layers.color.new("Prev")
    lines = [(Vector(a), Vector(b), r) for a, b, r in EMBER_LINES.get(ob.name, ())]
    off = Vector((seed * 2.1, seed * 5.3, 0.0))
    for f in bm.faces:
        for l in f.loops:
            v = l.vert
            y = v.co.z                                     # game height
            a = 1.0 - max(cav[v.index], 0.0) * 1.4
            a *= 0.62 + 0.38 * smoothstep(LAVA - 0.5, LAVA + 6.0, y)            # sooted and shaded near the lava
            a *= 0.88 + 0.12 * max(f.normal.z, 0.0)
            a = max(0.25, min(1.0, a))
            em = 0.0
            if ember:
                em = 1.0 - smoothstep(LAVA + 0.2, ember_top, y)
                gp = Vector((v.co.x, v.co.z, -v.co.y))
                for la, lb, lr in lines:
                    em = max(em, 1.0 - smoothstep(lr * 0.35, lr, _seg_d(gp, la, lb)))
                em *= 0.55 + 0.45 * smoothstep(-0.2, 0.3, fbm(v.co * 0.35 + off, 2))
            st = 1.0 - 0.16 * smoothstep(0.55, 0.95, fbm(Vector((0.0, 0.0, y * 1.3)) + off, 1) * 0.5 + 0.5)
            l[lay] = (a, 1.0, 1.0 - em, st)
            g = 0.3 * a * st
            l[prv] = (g + em * 0.6, g + em * 0.15, g * 1.08, 1.0)     # (what the review renders show: dark basalt, the ember band)
    bm.to_mesh(me)
    bm.free()
    show("Col", me)


def show(name, me):
    """Make colour layer `name` the active and the rendered one (export writes the active: "Col"; the reviews render "Prev")."""
    if name in me.color_attributes:
        me.color_attributes.active_color = me.color_attributes[name]
        me.color_attributes.render_color_index = list(me.color_attributes.keys()).index(name)


def export_clean(objs, path, label):
    """Export without the review colour (the game reads COLOR_0 only: a second layer is dead weight), then put it back for the reviews."""
    rocks = [o for o in objs if o.type == 'MESH' and "Prev" in o.data.color_attributes]
    for o in rocks:
        o.data.color_attributes.remove(o.data.color_attributes["Prev"])
        show("Col", o.data)
    export(objs, path, label)
    for o in rocks:
        rock_colour(o)


def review(objs, label, views, size=(1280, 720)):
    """Workbench renders of `objs` (rocks show their "Prev" colour, masonry its own), then the export colour back."""
    for o in objs:
        if o.type == 'MESH' and "Prev" in o.data.color_attributes:
            show("Prev", o.data)
    preview(objs, label, views, size)
    for o in objs:
        if o.type == 'MESH' and "Prev" in o.data.color_attributes:
            show("Col", o.data)


def rock_finish(ob, name, style="basalt", col_ratio=0.25, ember=True, ember_lines=()):
    """Name the rock `<name>__<style>`, give it its material and colour, and a decimated `<name>-colonly` copy for collision.
    Returns [visual, collision]."""
    ob.name = "%s__%s" % (name, style)
    ob.data.name = ob.name
    if ember_lines:
        EMBER_LINES[ob.name] = list(ember_lines)
    ob.data.materials.clear()
    ob.data.materials.append(make_mat(style))
    rock_colour(ob, ember=ember)
    col = ob.copy()
    col.data = ob.data.copy()
    col.data.materials.clear()
    bpy.context.scene.collection.objects.link(col)
    dc = col.modifiers.new("col", 'DECIMATE')
    dc.decimate_type = 'COLLAPSE'
    dc.ratio = col_ratio
    _apply(col, dc)
    col.name = name + "-colonly"
    col.data.name = col.name
    while col.data.color_attributes:
        col.data.color_attributes.remove(col.data.color_attributes[0])
    return [ob, col]


# ============================================================================================ masonry
class Mas:
    """Masonry for one section: a bmesh per set with per-vertex colour, and the collision boxes / slabs."""

    def __init__(self, seed):
        self.rnd = random.Random(seed)
        self.bm = {}
        self.col = bmesh.new()
        self.keeps = []                    # the walk volumes this section lays (game AABBs): its rock keeps out of them

    def of(self, key):
        if key not in self.bm:
            b = bmesh.new()
            b.verts.layers.float_color.new("vc")
            self.bm[key] = b
        return self.bm[key]

    # ---------------------------------------------------------------- tone
    def tone(self, key, co, n):
        """Weathering only: soot low and over the lava, pale ash on the tops, a stone-to-stone shade (set by `_shade`)."""
        y = co.z
        soot = 1.0 - 0.42 * (1.0 - smoothstep(LAVA + 0.5, LAVA + 7.0, y))
        ash = smoothstep(0.55, 0.95, n.z) * (0.06 + 0.08 * (fbm(co * 0.7, 2) * 0.5 + 0.5))
        streak = smoothstep(0.15, 0.6, fbm(Vector((co.x * 0.8, co.y * 0.8, co.z * 0.06)), 2)) * (1.0 - max(n.z, 0.0)) * 0.22
        v = self._shade * soot * (1.0 - streak)
        v = v + (0.92 - v) * ash
        return (v, v * 0.985, v * 0.97, 1.0)

    _shade = 0.9

    # ---------------------------------------------------------------- pieces
    def block(self, key, c, size, yaw=0.0, pitch=0.0, roll=0.0, bevel=0.07, warp=0.025, shade=None):
        """A dressed block, centre `c` and size (along its length, up, across) in game coordinates; yaw about up (deg: its length turned
        from game +x towards game -z), pitch raises the far end of its length (deg), roll about its length. Chunky: a broad bevel, corners
        a little off true."""
        bm = self.of(key)
        lay = bm.verts.layers.float_color["vc"]
        self._shade = shade if shade is not None else self.rnd.uniform(0.8, 1.0)
        before = set(bm.verts)
        _box_bm(bm, bl(c), (size[0] * 0.5, size[2] * 0.5, size[1] * 0.5), math.radians(yaw), math.radians(pitch), math.radians(roll))
        mine = [v for v in bm.verts if v not in before]
        w = min(bevel, min(size) * 0.28)
        if w > 0.004:
            edges = list({e for v in mine for e in v.link_edges})
            bmesh.ops.bevel(bm, geom=edges, offset=w, segments=1, affect='EDGES')
            mine = [v for v in bm.verts if v not in before]
        for v in mine:
            v.co += Vector((self.rnd.uniform(-1, 1), self.rnd.uniform(-1, 1), self.rnd.uniform(-1, 1))) * warp
        bm.normal_update()
        for v in mine:
            v[lay] = self.tone(key, v.co, v.normal)

    def finish(self, name, uv_tile=None):
        """One object per set (`<name>__<set>`): metric box UVs, the vertex colour as the active colour."""
        uv_tile = uv_tile or {"stone": 3.0, "ashlar": 2.4, "hewn": 1.9}
        objs = []
        for key, bm in self.bm.items():
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
            bm.normal_update()
            uv = bm.loops.layers.uv.new("UVMap")
            col = bm.loops.layers.color.new("Col")
            lay = bm.verts.layers.float_color["vc"]
            tile = uv_tile.get(key, 2.5)
            for f in bm.faces:
                f.smooth = False
                n = f.normal
                ax = max(range(3), key=lambda i: abs(n[i]))
                for l in f.loops:
                    co = l.vert.co
                    if ax == 0:
                        l[uv].uv = (co.y / tile, co.z / tile)
                    elif ax == 1:
                        l[uv].uv = (co.x / tile, co.z / tile)
                    else:
                        l[uv].uv = (co.x / tile, co.y / tile)
                    c = l.vert[lay]
                    l[col] = (c[0], c[1], c[2], 1.0)
            me = bpy.data.meshes.new("%s__%s" % (name, key))
            bm.to_mesh(me)
            bm.free()
            if "vc" in me.attributes:
                me.attributes.remove(me.attributes["vc"])
            me.materials.append(make_mat(key))
            ob = bpy.data.objects.new("%s__%s" % (name, key), me)
            bpy.context.scene.collection.objects.link(ob)
            if "Col" in me.color_attributes:
                me.color_attributes.active_color = me.color_attributes["Col"]
                me.color_attributes.render_color_index = list(me.color_attributes.keys()).index("Col")
            objs.append(ob)
        self.bm = {}
        return objs

    # ---------------------------------------------------------------- collision (game coordinates)
    def col_box(self, c, size, yaw=0.0, pitch=0.0):
        _box_bm(self.col, bl(c), (size[0] * 0.5, size[2] * 0.5, size[1] * 0.5), math.radians(yaw), math.radians(pitch), 0.0)

    def col_finish(self, name):
        ob = _obj_from_bm(self.col, name + "-colonly")
        self.col = bmesh.new()
        return ob
