"""The Pilgrims' Chapel at the Pilgrims' Threshold, modelled by script (no scans, no downloads).

  threshold_chapel.glb   a small stone chapel built against the foot of the rift's west wall where the starfall pours: a
                         facade of coursed ashlar with a pointed doorway (jambs, a voussoir ring, a keystone), blind
                         lancets, a rose of starlight and a corbel cornice; buttressed side walls; inside, a pointed
                         barrel vault on ribs over coursed webs, six niches each with a carved pilgrim, the back wall
                         and the kneeling stone with the page cut into it; a pier (forecourt and jetty with a stone
                         balustrade) that leads to it from the terrace walk.

  tools/blender/run.sh wonder_threshold_chapel.py -- [--preview DIR]

Frame: 1 BU = 1 m, Blender Z up -> Godot Y up, Blender +Y -> Godot -Z. Origin: the middle of the doorway's threshold on
the floor; +Y into the chapel, +X across. Parts are named <part>__<set>: stone / ashlar are dressed in Godot with the r37
PBR sets, rune is the starlight (emissive in Godot). Chapel-colonly: plain boxes for the walls, floor, roof, stone, pier.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import bmesh
from mathutils import Vector, Matrix
import r37_west as W

MODELS = W.MODELS
BLEND = W.BLEND
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ONLY = args[args.index("--only") + 1].split(",") if "--only" in args else []

RUN = 0.761          # arc length between step centres
RISE = 0.3308        # the stair's own rise per step
RADIUS = 6.3
WID = 2.3            # tread width
TREAD_D = 0.98       # tread slab depth (the nosing overhangs the riser)
TILE = {"stone": 5.0, "ashlar": 3.0, "rune": 1.0}


class Build:
    """Geometry by material set, one bmesh each; blocks are bevelled, jittered boxes with a baked tone."""

    def __init__(self, seed):
        self.bm = {}
        self.rng = random.Random(seed)
        self.seed = seed
        self.col = bmesh.new()                     # collision boxes

    def of(self, key):
        if key not in self.bm:
            b = bmesh.new()
            b.faces.layers.float.new("tone")
            self.bm[key] = b
        return self.bm[key]

    def vnoise(self, co, f, o):
        return Vector((W.fbm(co * f + Vector((o, 1.3, 2.1)), 2), W.fbm(co * f + Vector((4.2, o, 7.7)), 2), W.fbm(co * f + Vector((9.1, 3.3, o)), 2)))

    def blk(self, key, c, size, ex, ey, ez, bevel=0.02, jit=0.006, tone=None, sub=0, dish=0.0, rough=0.0, taper=None, cut=None):
        """A bevelled box (size along ex, ey, ez), vertices jittered by smooth noise, optional dished top.
        taper = (lo_scale_x, lo_scale_y): the foot drawn in (torn pieces). rough: extra jitter for broken faces."""
        tmp = bmesh.new()
        bmesh.ops.create_cube(tmp, size=1.0)
        for v in tmp.verts:
            v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
            if taper and v.co.z < 0:
                v.co.x *= taper[0]
                v.co.y *= taper[1]
        if bevel > 0 and min(size) > bevel * 3.0:
            bmesh.ops.bevel(tmp, geom=tmp.edges[:], offset=min(bevel, min(size) * 0.2), offset_type='OFFSET', segments=1, profile=0.5, affect='EDGES')
        cuts_l = cut if isinstance(cut, list) else ([cut] if cut else [])
        if sub > 0 or cuts_l:
            bmesh.ops.subdivide_edges(tmp, edges=tmp.edges[:], cuts=max(sub, 1), use_grid_fill=True)
        fractured = []
        for (pc0, pn0) in cuts_l:
            pc, pn = Vector(pc0), Vector(pn0).normalized()
            bmesh.ops.bisect_plane(tmp, geom=tmp.verts[:] + tmp.edges[:] + tmp.faces[:], dist=0.0001, plane_co=pc, plane_no=pn, clear_outer=True)
            bnd = [e for e in tmp.edges if e.is_boundary]
            if bnd:
                fill = bmesh.ops.holes_fill(tmp, edges=bnd, sides=len(bnd))
                nf = fill.get("faces", [])
                if nf:
                    tri = bmesh.ops.triangulate(tmp, faces=nf)
                    sub_e = list({e for f in tri["faces"] for e in f.edges if not e.is_boundary})
                    bmesh.ops.subdivide_edges(tmp, edges=sub_e, cuts=2, use_grid_fill=False)
            fractured += [(v, pn) for v in tmp.verts if abs((v.co - pc).dot(pn)) < 0.004]
        o = self.rng.uniform(0, 50)
        ctr = Vector(c)
        for v in tmp.verts:
            p = v.co.copy()
            if dish > 0 and p.z > size[2] * 0.5 - 0.04:
                p.z -= dish * math.exp(-((p.x / (size[0] * 0.24)) ** 2)) * (0.6 + 0.4 * math.sin(p.y * 3.1 + o))
            for (fv, fn) in fractured:
                if fv is v:
                    p += fn * (W.fbm(p * 11.0 + Vector((o, 2, 3)), 3) * 0.05 + self.rng.uniform(-0.01, 0.01))
                    break
            n = self.vnoise(p + ctr, 6.0, o)
            amp = jit + rough * (0.5 + 0.5 * W.fbm(p * 9.0 + Vector((o, 0, 0)), 2))
            p += n * amp
            v.co = p
        M = Matrix(((ex[0], ey[0], ez[0], c[0]), (ex[1], ey[1], ez[1], c[1]), (ex[2], ey[2], ez[2], c[2]), (0, 0, 0, 1)))
        bmesh.ops.transform(tmp, matrix=M, verts=tmp.verts)
        self.merge(tmp, key, tone if tone is not None else self.rng.uniform(0.86, 1.04))

    def merge(self, tmp, key, tone):
        bm = self.of(key)
        lay = bm.faces.layers.float["tone"]
        vm = {}
        for v in tmp.verts:
            vm[v] = bm.verts.new(v.co)
        for f in tmp.faces:
            try:
                nf = bm.faces.new([vm[v] for v in f.verts])
            except ValueError:
                continue
            nf[lay] = tone
        tmp.free()

    def rock(self, key, c, size, ex, ey, ez, tone=0.8, bevel_ratio=0.0, flat=0.0):
        """A dressed block that has been chipped: a squared ashlar with one or two corners spalled off."""
        h = Vector(size) * 0.5
        cuts = []
        for _ in range(self.rng.randint(1, 2)):
            sx, sy, sz = [self.rng.choice((-1, 1)) for _ in range(3)]
            depth = self.rng.uniform(0.45, 0.8)
            pt = (sx * h.x * depth, sy * h.y * depth, sz * h.z * depth)
            cuts.append((pt, (sx * self.rng.uniform(0.6, 1.2), sy * self.rng.uniform(0.6, 1.2), sz * self.rng.uniform(0.6, 1.2))))
        self.blk(key, c, size, ex, ey, ez, bevel=0.03, jit=0.008, sub=1, tone=tone, cut=cuts, rough=0.01)

    def sphere(self, key, c, r, scale=(1, 1, 1), tone=1.0, sub=2):
        tmp = bmesh.new()
        bmesh.ops.create_icosphere(tmp, subdivisions=sub, radius=r)
        for v in tmp.verts:
            v.co = Vector((v.co.x * scale[0], v.co.y * scale[1], v.co.z * scale[2])) + Vector(c)
        self.merge(tmp, key, tone)

    def cone(self, key, c, r1, r2, h, tone=1.0, seg=10, squash=(1.0, 1.0)):
        tmp = bmesh.new()
        bmesh.ops.create_cone(tmp, cap_ends=True, cap_tris=False, segments=seg, radius1=r1, radius2=r2, depth=h)
        for v in tmp.verts:
            v.co = Vector((v.co.x * squash[0], v.co.y * squash[1], v.co.z)) + Vector(c)
        self.merge(tmp, key, tone)

    def colbox(self, c, size, ex, ey, ez):
        tmp = bmesh.new()
        bmesh.ops.create_cube(tmp, size=1.0)
        for v in tmp.verts:
            v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
        M = Matrix(((ex[0], ey[0], ez[0], c[0]), (ex[1], ey[1], ez[1], c[1]), (ex[2], ey[2], ez[2], c[2]), (0, 0, 0, 1)))
        bmesh.ops.transform(tmp, matrix=M, verts=tmp.verts)
        vm = {v: self.col.verts.new(v.co) for v in tmp.verts}
        for f in tmp.faces:
            self.col.faces.new([vm[v] for v in f.verts])
        tmp.free()

    def loft(self, key, rings, tone=0.95, close=True):
        """Quad-loft consecutive rings (lists of Vector, same count)."""
        bm = self.of(key)
        lay = bm.faces.layers.float["tone"]
        vr = [[bm.verts.new(p) for p in ring] for ring in rings]
        n = len(vr[0])
        for i in range(len(vr) - 1):
            for j in range(n):
                f = bm.faces.new((vr[i][j], vr[i][(j + 1) % n], vr[i + 1][(j + 1) % n], vr[i + 1][j]))
                f[lay] = tone
        if close:
            for ring in (vr[0], vr[-1]):
                f = bm.faces.new(ring[::-1] if ring is vr[0] else ring)
                f[lay] = tone

    def crack(self, pts, n, width=0.022, lift=0.008):
        """A hairline crack of starlight along pts lying on a surface with normal n (rune set)."""
        n = Vector(n).normalized()
        for a, b in zip(pts[:-1], pts[1:]):
            d = Vector(b) - Vector(a)
            L = d.length
            if L < 1e-4:
                continue
            ey = d / L
            ex = ey.cross(n).normalized()
            self.blk("rune", (Vector(a) + Vector(b)) * 0.5 + n * lift, (width, L * 1.04, 0.012), ex, ey, n, bevel=0, jit=0.0, tone=1.0)

    def zigzag(self, a, b, n, amp, count=7, width=0.02):
        a, b = Vector(a), Vector(b)
        d = b - a
        side = d.normalized().cross(Vector(n)).normalized()
        pts = []
        for i in range(count + 1):
            t = i / count
            p = a + d * t + side * (self.rng.uniform(-amp, amp) if 0 < i < count else 0.0)
            pts.append(p)
        self.crack(pts, n, width)


def finish(B, name, smooth=()):
    """Objects <name>__<set> with box UVs and baked vertex tone (cool stone, moon-catching tops, dark undersides)."""
    objs = []
    for key, bm in B.bm.items():
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.normal_update()
        uv = bm.loops.layers.uv.new("UVMap")
        col = bm.loops.layers.color.new("Col")
        lay = bm.faces.layers.float["tone"]
        tile = TILE.get(key.split("_")[0], 4.0)
        for f in bm.faces:
            f.smooth = key.endswith("_s")
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
                t = f[lay]
                if key == "rune":
                    l[col] = (1, 1, 1, 1)
                    continue
                up = max(n.z, 0.0)
                dn = max(-n.z, 0.0)
                shade = t * (0.82 + 0.26 * W.fbm(co * 0.9 + Vector((3, 1, 5)), 3)) * (1.0 + 0.18 * up - 0.42 * dn)
                shade *= 0.74 + 0.26 * W.smoothstep(-1.4, 0.2, co.z) if key != "rune" else 1.0
                l[col] = (shade * 0.96, shade * 0.98, shade * 1.06, 1.0)
        me = bpy.data.meshes.new("%s__%s" % (name, key))
        bm.to_mesh(me)
        bm.free()
        me.materials.append(W.make_mat(key))
        ob = bpy.data.objects.new("%s__%s" % (name, key), me)
        bpy.context.scene.collection.objects.link(ob)
        if "Col" in me.color_attributes:
            me.color_attributes.active_color = me.color_attributes["Col"]
            me.color_attributes.render_color_index = list(me.color_attributes.keys()).index("Col")
        objs.append(ob)
    # the collision object
    me = bpy.data.meshes.new(name + "-colonly")
    B.col.to_mesh(me)
    B.col.free()
    col = bpy.data.objects.new(name + "-colonly", me)
    bpy.context.scene.collection.objects.link(col)
    return objs, col


def far_copy(objs, name, ratio):
    out = []
    for o in objs:
        c = o.copy()
        c.data = o.data.copy()
        c.name = o.name.replace(name, name + "Far")
        bpy.context.scene.collection.objects.link(c)
        if not c.name.endswith("__rune"):
            md = c.modifiers.new("dec", 'DECIMATE')
            md.ratio = ratio
            bpy.context.view_layer.objects.active = c
            bpy.ops.object.modifier_apply(modifier=md.name)
        out.append(c)
    return out



# ------------------------------------------------------------------------------------------------------
# THE PILGRIMS' CHAPEL
# ------------------------------------------------------------------------------------------------------
# Frame: origin = the middle of the doorway's threshold on the floor (z 0 = floor, the lowest terrace walk); +Y goes
# into the chapel (towards the rock), +X across, Z up. The facade face is y = 0. The pier (forecourt and jetty) lies
# at y < 0 and x < -1.9 (the jetty runs along the chapel's side to the terrace walk).
X_ = Vector((1, 0, 0))
Y_ = Vector((0, 1, 0))
Z_ = Vector((0, 0, 1))
HALF = 1.9           # half width of the chapel
INNER = 1.2          # half width of the chamber
WALL_TOP = 5.0
SPRING = 2.1         # the vault's springing height
FACADE_T = 0.9
CH_Y0, CH_Y1 = 0.9, 5.4     # the chamber's length
BACK_T = 0.8
DOOR_A = 0.72        # half width of the doorway
DOOR_ZS = 1.9        # its springing height


def pointed(a, zs, x, z, margin=0.0):
    """Inside a pointed (two-centred) arch opening of half width a springing at zs, with a rectangle below."""
    a = a + margin
    if z < zs:
        return abs(x) < a
    R = 2.0 * a
    if x >= 0:
        return (x + a) ** 2 + (z - zs) ** 2 < R * R
    return (x - a) ** 2 + (z - zs) ** 2 < R * R


def course_wall(B, c0, u, depth, ey_sign, length, z0, z1, hole=None, tone=(0.92, 1.08), hrow=(0.34, 0.46), blen=(0.7, 1.25), bevel=0.028, rough=0.0, sub=0):
    """A wall of coursed ashlar. c0: the wall's origin point at u = 0 (its centre plane), u: unit run, `depth` thick along
    ey = Z x u (flipped by ey_sign). hole(u, z) -> True where there is an opening. Staggered courses of dressed blocks."""
    rng = B.rng
    ey = Z_.cross(u) * ey_sign
    ex = u
    ez = ex.cross(ey)
    z = z0
    row = 0
    while z < z1 - 0.05:
        h = min(rng.uniform(*hrow), z1 - z)
        if z1 - (z + h) < 0.2:
            h = z1 - z
        pos = -rng.uniform(0.0, 0.5) if row % 2 else 0.0
        while pos < length:
            ln = rng.uniform(*blen)
            a, b = max(pos, 0.0), min(pos + ln, length)
            if b - a > 0.15:
                skip = False
                if hole:
                    for (uu, zz) in ((a, z), (b, z), (a, z + h), (b, z + h), ((a + b) * 0.5, z + h * 0.5), ((a + b) * 0.5, z), ((a + b) * 0.5, z + h)):
                        if hole(uu, zz):
                            skip = True
                            break
                if not skip:
                    c = c0 + u * ((a + b) * 0.5) + Z_ * (z + h * 0.5)
                    B.blk("ashlar", c, (b - a - 0.02, depth, h - 0.02), ex, ey, ez * (1 if ez.z > 0 else -1) if False else ez, bevel=bevel, jit=0.006, rough=rough, sub=sub,
                          tone=rng.uniform(*tone))
            pos += ln
        z += h
        row += 1


def vault_arc(zs, inner, n_side=6):
    """Points (theta list) for one side of a pointed arch of half span `inner`: returns [(centre_x, theta0, theta1)]."""
    R = 2.0 * inner
    th_apex = math.pi - math.acos(inner / R)       # apex at x = 0 on the left circle
    return R, th_apex


def chapel_build(seed=41):
    B = Build(seed)
    rng = B.rng
    TX = Vector((1, 0, 0))
    # --- the floor and the threshold ------------------------------------------------------------------
    y = CH_Y0 - 0.15
    ri = 0
    while y < CH_Y1 + 0.3:
        ln = rng.uniform(0.8, 1.05)
        xs = [-INNER - 0.05, -0.0, INNER + 0.05]
        cuts = [-INNER - 0.05, rng.uniform(-0.5, 0.2), INNER + 0.05] if ri % 2 else [-INNER - 0.05, rng.uniform(-0.2, 0.5), INNER + 0.05]
        for j in range(2):
            w = cuts[j + 1] - cuts[j]
            B.blk("stone", Vector(((cuts[j] + cuts[j + 1]) * 0.5, y + ln * 0.5, -0.14)), (w - 0.04, ln - 0.04, 0.28), X_, Y_, Z_, bevel=0.028, jit=0.003, sub=1, dish=0.01,
                  tone=rng.uniform(0.9, 1.04))
        B.colbox(Vector((0, y + ln * 0.5, -0.14)), (2 * INNER + 0.1, ln, 0.28), X_, Y_, Z_)
        y += ln
        ri += 1
    # the threshold stone under the doorway, worn hollow
    B.blk("stone", Vector((0, 0.45, -0.13)), (2 * DOOR_A + 0.5, 1.0, 0.26), X_, Y_, Z_, bevel=0.035, jit=0.003, sub=2, dish=0.02, tone=1.05)
    B.colbox(Vector((0, 0.45, -0.13)), (2 * DOOR_A + 0.5, 1.0, 0.26), X_, Y_, Z_)
    # --- the facade: an outer layer with the lancets and the rose cut through it, a solid core --------
    def facade_hole(u, z):
        x = u - HALF
        if pointed(DOOR_A, DOOR_ZS, x, z, 0.0):
            return True
        for sx in (-1, 1):                                  # a blind lancet either side of the door
            if pointed(0.2, 2.4, x - sx * 1.42, z, 0.0) and z > 1.3:
                return True
        # a rose over the door
        if (x * x + (z - 4.25) ** 2) < 0.34 ** 2:
            return True
        return False
    course_wall(B, Vector((-HALF, 0.2, 0.0)), X_, 0.4, 1, 2 * HALF, 0.0, WALL_TOP, facade_hole, rough=0.004)
    # the facade core (behind the outer layer): plain, with the doorway through it
    def core_hole(u, z):
        return pointed(DOOR_A, DOOR_ZS, u - HALF, z, 0.0)
    course_wall(B, Vector((-HALF, 0.62, 0.0)), X_, 0.46, 1, 2 * HALF, 0.0, WALL_TOP, core_hole, hrow=(0.6, 0.9), blen=(1.0, 1.6), bevel=0.0)
    # the doorway's reveal: jambs and a ring of voussoirs, a roll moulding, a hood-mould with carved stops
    a, zs = DOOR_A, DOOR_ZS
    R = 2.0 * a
    th_apex = math.pi - math.acos(a / R)
    n = 8
    for side in (-1, 1):
        # jamb: a roll of stacked drums either side
        for j in range(5):
            zc = 0.25 + j * 0.38
            if zc + 0.19 > zs + 0.05:
                break
            B.blk("stone", Vector((side * (a + 0.12), 0.18, zc)), (0.26, 0.5, 0.36), X_, Y_, Z_, bevel=0.06, jit=0.002, sub=1, tone=1.05)
            B.blk("stone", Vector((side * (a + 0.34), 0.18, zc)), (0.18, 0.4, 0.36), X_, Y_, Z_, bevel=0.03, jit=0.002, tone=0.98)
        for i in range(n):
            t0 = th_apex + (math.pi - th_apex) * i / n
            t1 = th_apex + (math.pi - th_apex) * (i + 1) / n
            tm = (t0 + t1) * 0.5
            # the left circle (centre (a, zs)) bounds the left half; mirrored for the right half
            cx = a if side < 0 else -a
            nxv = math.cos(tm) * (-side if False else (1 if side < 0 else -1)) * (1 if side < 0 else -1)
            ang = tm if side < 0 else math.pi - tm
            rad = R
            for k, (off, dep, th) in enumerate(((0.12, 0.5, 0.26), (0.34, 0.4, 0.18))):
                rr = rad + off
                px = (a if side < 0 else -a) + rr * math.cos(ang)
                pz = zs + rr * math.sin(ang)
                tang = Vector((-math.sin(ang), 0, math.cos(ang)))
                ex = tang
                ey = Y_
                ez = ex.cross(ey)
                L = rad * (t1 - t0) * 1.03
                B.blk("stone", Vector((px, 0.18 if k == 0 else 0.13, pz)), (L, dep, th), ex, ey, ez, bevel=0.03 if k == 0 else 0.02, jit=0.002, tone=1.04 if k == 0 else 0.98)
    # the keystone, carved with a ring of starlight
    kz = zs + math.sqrt(R * R - a * a)
    B.blk("stone", Vector((0, 0.13, kz + 0.2)), (0.36, 0.56, 0.5), X_, Y_, Z_, bevel=0.04, jit=0.002, sub=1, tone=1.08)
    B.blk("rune", Vector((0, -0.15, kz + 0.2)), (0.14, 0.012, 0.014), X_, Y_, Z_, bevel=0, jit=0, tone=1)
    B.blk("rune", Vector((0, -0.15, kz + 0.2)), (0.014, 0.012, 0.14), X_, Y_, Z_, bevel=0, jit=0, tone=1)
    # rune slits in the blind lancets, and the rose's tracery of starlight
    for sx in (-1, 1):
        B.blk("rune", Vector((sx * 1.42, 0.62, 2.2)), (0.04, 0.02, 0.9), X_, Y_, Z_, bevel=0, jit=0, tone=1)
        B.blk("rune", Vector((sx * 1.42, 0.62, 2.55)), (0.34, 0.02, 0.035), X_, Y_, Z_, bevel=0, jit=0, tone=1)
    for j in range(12):
        ang = (j + 0.5) * math.pi / 6.0
        d = Vector((math.cos(ang), 0, math.sin(ang)))
        tg = Vector((-math.sin(ang), 0, math.cos(ang)))
        B.blk("stone", Vector((0, 0.12, 4.25)) + d * 0.5, (0.28, 0.46, 0.18), tg, Y_, tg.cross(Y_), bevel=0.03, jit=0.002, tone=1.05)
    for j in range(12):
        ang = j * math.pi / 6.0
        d = Vector((math.cos(ang), 0, math.sin(ang)))
        tangv = Vector((-math.sin(ang), 0, math.cos(ang)))
        c = Vector((0, 0.45, 4.25)) + d * 0.2
        B.blk("rune", c, (0.2, 0.02, 0.03), tangv, Y_, tangv.cross(Y_), bevel=0, jit=0, tone=1)
    B.blk("rune", Vector((0, 0.45, 4.25)), (0.07, 0.02, 0.07), X_, Y_, Z_, bevel=0, jit=0, tone=1)
    # --- the side walls: an inner layer with the niches cut through, an outer layer, buttresses -------
    niche_y = [1.9, 3.15, 4.4]
    def niche_hole(u, z):
        for cy in niche_y:
            if abs(u - cy) < 0.36 and 0.95 < z < 2.15:
                return True
            if 2.1 <= z < 2.62 and abs(u - cy) < 0.36 - (z - 2.1) * 0.69:
                return True
        return False
    for sx in (-1, 1):
        # inner layer x INNER..INNER+0.28 (course blocks with niches), outer layer INNER+0.36..HALF
        c_in = Vector((sx * (INNER + 0.14), 0.0, 0.0))
        c_out = Vector((sx * (INNER + 0.55), 0.0, 0.0))
        u = Y_
        ey_sign = -sx          # Z x Y = -X; wanting depth along x: sign flips (depth is symmetric about the centre anyway)
        course_wall(B, c_in + Y_ * CH_Y0, u, 0.28, 1, CH_Y1 - CH_Y0, 0.0, WALL_TOP, lambda uu, zz: niche_hole(uu + CH_Y0, zz), hrow=(0.34, 0.44), blen=(0.6, 1.0))
        course_wall(B, c_out + Y_ * 0.0, u, 0.34, 1, CH_Y1 + BACK_T, 0.0, WALL_TOP, None, rough=0.004)
        # the core between, plain
        B.blk("ashlar", Vector((sx * (INNER + 0.33), (CH_Y1 + BACK_T) * 0.5, WALL_TOP * 0.5)), (0.16, CH_Y1 + BACK_T - 0.1, WALL_TOP - 0.1), X_, Y_, Z_, bevel=0, jit=0, tone=0.8)
        B.colbox(Vector((sx * (INNER + 0.35), (CH_Y1 + BACK_T) * 0.5, WALL_TOP * 0.5)), (HALF - INNER, CH_Y1 + BACK_T, WALL_TOP), X_, Y_, Z_)
        # buttresses
        for by in (1.6, 4.0):
            for j, (dz, bw, bh) in enumerate(((0.0, 0.62, 1.6), (1.6, 0.5, 1.5), (3.1, 0.42, 1.2))):
                B.blk("ashlar", Vector((sx * (HALF + 0.12 + (0.0 if j == 0 else 0.0)), by, dz + bh * 0.5)), (0.34 - 0.04 * j, bw, bh), X_, Y_, Z_, bevel=0.035, jit=0.004, sub=1,
                      tone=rng.uniform(0.92, 1.06))
            B.blk("stone", Vector((sx * (HALF + 0.12), by, 4.45)), (0.3, 0.38, 0.12), X_, Y_, Z_, bevel=0.03, jit=0.002, tone=1.05)
        # the niches: a sill, a carved pilgrim, a lit slit behind
        for cy in niche_y:
            xin = sx * (INNER + 0.02)
            B.blk("stone", Vector((sx * (INNER - 0.04), cy, 0.88)), (0.3, 0.84, 0.14), X_, Y_, Z_, bevel=0.03, jit=0.002, sub=1, tone=1.04)
            # the figure: a robed pilgrim, hooded, hands together, looking down the aisle
            fx = sx * (INNER + 0.14)
            z0 = 0.97 + 0.07
            face = -sx
            B.blk("stone", Vector((fx, cy, 0.97 + 0.035)), (0.34, 0.34, 0.07), X_, Y_, Z_, bevel=0.015, jit=0.002, tone=1.0)             # a base
            B.cone("stone_s", Vector((fx, cy, z0 + 0.22)), 0.15, 0.085, 0.44, 1.0, 10, (1.0, 0.85))                                      # the robe
            B.sphere("stone_s", Vector((fx, cy, z0 + 0.42)), 0.09, (0.9, 1.45, 0.62), 1.02)                                               # the shoulders
            B.sphere("stone_s", Vector((fx - face * 0.02, cy, z0 + 0.53)), 0.082, (1.0, 1.0, 1.2), 1.06)                                  # the hood
            B.sphere("stone_s", Vector((fx + face * 0.03, cy, z0 + 0.52)), 0.05, (0.7, 0.9, 1.0), 0.92)                                   # the face in shadow
            B.sphere("stone_s", Vector((fx + face * 0.1, cy, z0 + 0.32)), 0.045, (1.0, 0.8, 1.2), 1.0)                                    # the hands
            B.blk("rune", Vector((sx * (INNER + 0.285), cy, 1.62)), (0.012, 0.03, 0.8), X_, Y_, Z_, bevel=0, jit=0, tone=1)
    # --- the back wall -------------------------------------------------------------------------------
    course_wall(B, Vector((-INNER - 0.4, CH_Y1 + 0.15, 0.0)), X_, 0.3, 1, 2 * INNER + 0.8, 0.0, WALL_TOP, None, hrow=(0.34, 0.44), blen=(0.7, 1.2))
    B.blk("ashlar", Vector((0, CH_Y1 + 0.55, WALL_TOP * 0.5)), (2 * HALF, 0.5, WALL_TOP), X_, Y_, Z_, bevel=0, jit=0, tone=0.8)
    B.colbox(Vector((0, CH_Y1 + 0.4, WALL_TOP * 0.5)), (2 * HALF, 0.8, WALL_TOP), X_, Y_, Z_)
    # a pointed blind arch on the back wall, the kneeling stone before it
    kc = Vector((0, CH_Y1 - 0.55, 0.0))
    B.blk("stone", kc + Vector((0, 0, 0.14)), (1.5, 0.72, 0.28), X_, Y_, Z_, bevel=0.04, jit=0.004, sub=1, tone=1.0)
    B.blk("stone", kc + Vector((0, 0.04, 0.42)), (1.3, 0.56, 0.28), X_, Y_, Z_, bevel=0.04, jit=0.004, sub=1, tone=1.03)
    # the desk, sloped towards the one who kneels (the way in), the page cut into it in rows
    sl = 0.32
    ey_d = Vector((0, math.cos(sl), -math.sin(sl)))
    ez_d = Vector((0, math.sin(sl), math.cos(sl)))
    B.blk("stone", kc + Vector((0, 0.04, 0.78)), (1.42, 0.62, 0.14), X_, ey_d, ez_d, bevel=0.03, jit=0.002, sub=2, tone=1.06)
    for j in range(9):
        yy = -0.22 + j * 0.055
        B.blk("stone", kc + Vector((0, 0.04, 0.78)) + ey_d * yy + ez_d * 0.085, (1.12 - 0.06 * (j % 3), 0.014, 0.014), X_, ey_d, ez_d, bevel=0.004, jit=0.0005, tone=0.82)
    B.blk("rune", kc + Vector((0, 0.04, 0.78)) + ey_d * 0.0 + ez_d * 0.075, (0.5, 0.02, 0.012), X_, ey_d, ez_d, bevel=0, jit=0, tone=1)
    B.colbox(kc + Vector((0, 0, 0.45)), (1.5, 0.72, 0.9), X_, Y_, Z_)
    # --- the vault: pointed barrel, voussoir ribs every cell, coursed webs between ------------------
    Rv = 2.0 * INNER
    th_a = math.pi - math.acos(INNER / Rv)
    ribs = [CH_Y0 + 0.05, 2.5, 4.0, CH_Y1 - 0.05]
    def arc_pt(side, th, rr):
        ang = th if side < 0 else math.pi - th
        cx = INNER if side < 0 else -INNER
        return Vector((cx + rr * math.cos(ang), 0, SPRING + rr * math.sin(ang))), ang
    nseg = 7
    for side in (-1, 1):
        for i in range(nseg):
            t0 = th_a + (math.pi - th_a) * i / nseg
            t1 = th_a + (math.pi - th_a) * (i + 1) / nseg
            tm = (t0 + t1) * 0.5
            # the webs: the cells between the ribs, laid as coursed blocks on the arc
            for ci in range(len(ribs) - 1):
                ya, yb = ribs[ci] + 0.14, ribs[ci + 1] - 0.14
                off = 0.0 if (i % 2 == 0) else 0.45
                p, ang = arc_pt(side, tm, Rv + 0.14)
                tang = Vector((-math.sin(ang), 0, math.cos(ang)))
                ez = tang.cross(Y_)
                L = Rv * (t1 - t0) * 1.02
                mid = (ya + yb) * 0.5
                B.blk("ashlar", Vector((p.x, mid, p.z)), (L, (yb - ya) - 0.03, 0.28), tang, Y_, ez, bevel=0.0, jit=0.002, tone=rng.uniform(0.95, 1.12))
        # the ribs: heavier voussoirs standing proud of the web
    for ry in ribs:
        for side in (-1, 1):
            for i in range(nseg):
                t0 = th_a + (math.pi - th_a) * i / nseg
                t1 = th_a + (math.pi - th_a) * (i + 1) / nseg
                tm = (t0 + t1) * 0.5
                p, ang = arc_pt(side, tm, Rv + 0.1)
                tang = Vector((-math.sin(ang), 0, math.cos(ang)))
                ez = tang.cross(Y_)
                B.blk("stone", Vector((p.x, ry, p.z)), (Rv * (t1 - t0) * 1.03, 0.28, 0.36), tang, Y_, ez, bevel=0.03, jit=0.002, sub=1, tone=1.06)
    # springers: a corbel at each rib's foot on each side
    for ry in ribs:
        for side in (-1, 1):
            B.blk("stone", Vector((side * (INNER + 0.02), ry, SPRING - 0.14)), (0.3, 0.42, 0.28), X_, Y_, Z_, bevel=0.04, jit=0.003, sub=1, tone=1.05)
            B.blk("stone", Vector((side * (INNER + 0.02), ry, SPRING - 0.4)), (0.22, 0.3, 0.26), X_, Y_, Z_, bevel=0.04, jit=0.003, taper=(0.6, 0.7), tone=1.0)
    # the vault's extrados filled solid to the roof, and the roof: big flags with a kerb
    B.blk("ashlar", Vector((0, (CH_Y0 + CH_Y1) * 0.5, SPRING + 1.35 + 0.28 + 0.2)), (2 * HALF - 0.3, CH_Y1 - CH_Y0 + 0.3, 1.3), X_, Y_, Z_, bevel=0, jit=0, tone=0.7)
    B.colbox(Vector((0, (CH_Y0 + CH_Y1) * 0.5 + 0.5, WALL_TOP - 0.4)), (2 * HALF, CH_Y1 - CH_Y0 + 1.7, 0.8), X_, Y_, Z_)
    y = -0.05
    ri = 0
    while y < 8.6:
        ln = rng.uniform(0.95, 1.3)
        for j, (x0, x1) in enumerate(((-HALF - 0.15, -0.05), (0.05, HALF + 0.15))):
            xx0 = x0 + (0.25 if ri % 2 else 0.0)
            B.blk("stone", Vector(((xx0 + x1) * 0.5, y + ln * 0.5, WALL_TOP + 0.1)), (x1 - xx0 - 0.03, ln - 0.03, 0.22), X_, Y_, Z_, bevel=0.035, jit=0.003, sub=1, dish=0.006,
                  tone=rng.uniform(0.95, 1.08))
        y += ln
        ri += 1
    B.colbox(Vector((0, 4.2, WALL_TOP + 0.1)), (2 * HALF + 0.3, 8.8, 0.24), X_, Y_, Z_)
    # the rear mass keyed into the rock behind, and the plinth under the whole chapel down into the pool
    B.blk("ashlar", Vector((0, 7.5, 2.4)), (2 * HALF, 2.6, 4.8), X_, Y_, Z_, bevel=0.0, jit=0.0, tone=0.7)
    B.blk("ashlar", Vector((0, 4.1, -2.5)), (2 * HALF - 0.1, 8.6, 4.6), X_, Y_, Z_, bevel=0.0, jit=0.0, tone=0.7)
    course_wall(B, Vector((-HALF - 0.25, -0.38, 0.0)), X_, 0.5, 1, 2 * HALF + 0.5, -4.5, 0.0, None, hrow=(0.4, 0.55), blen=(0.8, 1.4), rough=0.004)
    for sx in (-1, 1):
        course_wall(B, Vector((sx * (HALF + 0.14), -0.1, 0.0)), Y_, 0.46, 1, 8.6, -4.5, 0.0, None, hrow=(0.4, 0.55), blen=(0.8, 1.4), rough=0.004)
    B.blk("stone", Vector((0, -0.4, 0.0)), (2 * HALF + 0.7, 0.62, 0.16), X_, Y_, Z_, bevel=0.04, jit=0.003, sub=1, tone=1.05)     # the plinth's moulded cap
    B.colbox(Vector((0, 4.1, -2.5)), (2 * HALF + 0.5, 8.8, 4.7), X_, Y_, Z_)
    # a kerb round the roof, a cornice with a corbel table on the facade, pinnacles on the facade corners
    for sx in (-1, 1):
        B.blk("stone", Vector((sx * (HALF + 0.02), 3.8, WALL_TOP + 0.34)), (0.3, 7.7, 0.22), X_, Y_, Z_, bevel=0.04, jit=0.003, sub=1, tone=1.04)
    B.blk("stone", Vector((0, -0.12, WALL_TOP + 0.28)), (2 * HALF + 0.5, 0.5, 0.2), X_, Y_, Z_, bevel=0.04, jit=0.003, sub=1, tone=1.06)
    for j in range(9):
        B.blk("stone", Vector((-HALF + 0.2 + j * (2 * HALF - 0.4) / 8, -0.04, WALL_TOP - 0.22)), (0.2, 0.34, 0.3), X_, Y_, Z_, bevel=0.04, jit=0.003, taper=(0.6, 0.7), tone=1.0)
    for sx in (-1, 1):
        px = sx * (HALF - 0.05)
        B.blk("ashlar", Vector((px, -0.14, 2.6)), (0.5, 0.42, 5.2), X_, Y_, Z_, bevel=0.04, jit=0.004, sub=1, tone=1.0)
        B.blk("stone", Vector((px, -0.14, 5.3)), (0.62, 0.54, 0.14), X_, Y_, Z_, bevel=0.035, jit=0.002, tone=1.05)
        B.blk("stone", Vector((px, -0.14, 5.65)), (0.44, 0.44, 0.58), X_, Y_ * -1, Z_ * -1, bevel=0.02, jit=0.002, taper=(0.1, 0.1), tone=1.06)
    # a gablet over the door with the stepped sides, a carved boss
    for j, (w, hz) in enumerate(((1.9, 0.0), (1.4, 0.2), (0.9, 0.4))):
        pass
    # candle shelf by the door and a lamp-hook: a stone bracket
    # --- the pier: a forecourt in front of the facade, a jetty along the side to the terrace walk ----
    def slab(x0, x1, y0, y1, label=None):
        xs = x0
        k = 0
        while xs < x1 - 0.05:
            ln = min(rng.uniform(0.9, 1.3), x1 - xs)
            ys = y0
            while ys < y1 - 0.05:
                ly = min(rng.uniform(0.9, 1.25), y1 - ys)
                B.blk("stone", Vector((xs + ln * 0.5, ys + ly * 0.5, -0.14)), (ln - 0.05, ly - 0.05, 0.28), X_, Y_, Z_, bevel=0.03, jit=0.003, sub=0, dish=0.007, tone=rng.uniform(0.9, 1.05))
                ys += ly
            xs += ln
        B.colbox(Vector(((x0 + x1) * 0.5, (y0 + y1) * 0.5, -0.14)), (x1 - x0, y1 - y0, 0.28), X_, Y_, Z_)
    JX0 = -4.5               # the jetty's outer edge (the terrace side of the chapel is -x)
    slab(JX0 + 0.0, HALF + 0.25, -2.6, 0.0)           # the forecourt
    slab(JX0, -HALF - 0.05, 0.0, 4.3)                  # the jetty along the side wall (towards +y, the rock)
    # piers under it
    for (px, py) in ((HALF, -2.4), (-0.6, -2.4), (-3.4, -2.4), (-4.2, 0.2), (-4.2, 3.9), (HALF, 0.0)):
        B.blk("ashlar", Vector((px, py, -2.7)), (0.8, 0.8, 5.0), X_, Y_, Z_, bevel=0.05, jit=0.01, sub=1, tone=0.8)
    # a plinth course of the facade
    for sx in (-1, 1):
        pass
    # balustrades: along the forecourt's outer edge and sides, and the jetty's outer edge; open at the door and at the terrace end
    def bal(p0, p1):
        d = p1 - p0
        L = d.length
        u = d / L
        ey = Z_.cross(u)
        ez = u.cross(ey)
        n = max(2, int(L / 1.2))
        for i in range(n + 1):
            c = p0 + u * (L * i / n)
            B.blk("stone", c + Vector((0, 0, 0.1)), (0.4, 0.4, 0.2), u, ey, ez, bevel=0.03, jit=0.002, tone=1.0)
            B.blk("stone", c + Vector((0, 0, 0.55)), (0.28, 0.28, 0.9), u, ey, ez, bevel=0.025, jit=0.003, tone=rng.uniform(0.95, 1.05))
            B.blk("stone", c + Vector((0, 0, 1.05)), (0.38, 0.38, 0.09), u, ey, ez, bevel=0.025, jit=0.002, tone=1.04)
            B.blk("stone", c + Vector((0, 0, 1.2)), (0.3, 0.3, 0.2), u, ey * -1, ez * -1, bevel=0.015, jit=0.002, taper=(0.12, 0.12), tone=1.06)
        for i in range(n):
            a = p0 + u * (L * i / n)
            b = p0 + u * (L * (i + 1) / n)
            m = (a + b) * 0.5
            ln = (b - a).length - 0.34
            B.blk("stone", m + Vector((0, 0, 0.9)), (ln, 0.2, 0.13), u, ey, ez, bevel=0.025, jit=0.002, tone=1.02)       # the coping rail
            B.blk("stone", m + Vector((0, 0, 0.27)), (ln, 0.2, 0.14), u, ey, ez, bevel=0.025, jit=0.002, tone=0.98)       # the sill
            nb = max(2, int(ln / 0.42))
            for j in range(nb):
                bp = a + u * (0.17 + (j + 0.5) * ln / nb)
                B.blk("stone", bp + Vector((0, 0, 0.42)), (0.2, 0.2, 0.2), u, ey, ez, bevel=0.05, jit=0.001, tone=1.02)
                B.blk("stone", bp + Vector((0, 0, 0.68)), (0.13, 0.13, 0.32), u, ey, ez, bevel=0.0, jit=0.001, tone=1.0)
            B.colbox(m + Vector((0, 0, 0.55)), (ln + 0.3, 0.3, 1.1), u, ey, ez)
    bal(Vector((HALF + 0.05, -2.45, 0.0)), Vector((HALF + 0.05, 0.0, 0.0)) if False else Vector((HALF + 0.05, -0.2, 0.0)))
    bal(Vector((HALF + 0.05, -2.45, 0.0)), Vector((JX0 + 0.2, -2.45, 0.0)))
    bal(Vector((JX0 + 0.2, -2.45, 0.0)), Vector((JX0 + 0.2, 4.2, 0.0)))
    # candles' sills: the facade's two bracket stones either side of the door
    # a worn crack of starlight through the forecourt flags and across the threshold
    B.crack([Vector((-1.3, -2.1, 0.0)), Vector((-0.8, -1.3, 0.0)), Vector((-0.9, -0.5, 0.0)), Vector((-0.3, 0.2, 0.0)), Vector((-0.45, 0.9, 0.0))], (0, 0, 1), 0.024, 0.0)
    return B


def asset_chapel():
    if ONLY and "chapel" not in ONLY:
        return
    W.reset()
    B = chapel_build()
    objs, col = finish(B, "Chapel")
    W.export(objs + [col], os.path.join(MODELS, "threshold_chapel.glb"), "chapel")
    W.preview(objs, "chapel", [
        ((-6.5, -9.0, 4.5), (-0.5, 0.5, 2.0), 38), ((6.5, -8.0, 3.0), (0, 1.0, 2.2), 38), ((0, -9.0, 1.8), (0, 0, 2.2), 36),
        ((-9.0, 4.0, 5.5), (-1.0, 3.5, 2.5), 38), ((0.0, 1.0, 1.7), (0, 5.2, 1.9), 20), ((0.0, 5.1, 1.8), (0, 0.8, 2.0), 20),
        ((0.5, 2.2, 1.7), (-1.2, 3.6, 1.6), 22), ((-0.6, 3.0, 1.6), (1.2, 4.0, 3.0), 22), ((7.5, 3.0, 9.0), (-1, 3.5, 3.0), 34), ((-0.1, 1.9, 1.55), (-1.3, 1.9, 1.5), 55)])
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(BLEND, "threshold_chapel.blend"))


if __name__ == "__main__":
    os.makedirs(MODELS, exist_ok=True)
    asset_chapel()
