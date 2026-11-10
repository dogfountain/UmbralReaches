"""The Star-Fall Crater's hero assets, modelled by script (no scans, no downloads).

  star_crater_shards.glb   shard_great_a/b/c  quartz druses rooted in fused glass: a great point and its family (hexagonal
                           prisms, raked or snapped terminations), sprouts, satellites fanning out, chips, a glass skirt
                           shard_ray_a/b      one long point thrown low across the pans
                           shard_crown_a/b    small druses
  star_crater_rim.glb      rim_slab_a/b/c     heaved plates of fused crust (not exported by default)
  star_crater_heart.glb    heart_core         the star: a faceted gem with short points of light
                           heart_drips        thin threads of molten glass hanging beneath it
                           heart_shell        jagged plates of black glass crust laid close over it
                           frag_a-f           small chips that orbit further out
  star_crater_ridge.glb    ridge_plate_a-d, ridge_shelf  snapped quartz columns (walk faces at z=0, bodies below), colonly hulls

  tools/blender/run.sh wonder_star_crater.py -- [--only shards,heart,steps] [--renders DIR] [--no-export]

Conventions (Blender Z up -> Godot Y up; 1 BU = 1 m). Each asset is upright with its root at the origin (Z = 0) and
leans towards +X (Godot +X). UV.x carries the glow parameter (0 at a crystal's root, 1 at its tip), UV.y the face's
kind (0 crystal face, 0.5 fused glass / a shell's inner face, 1 a fracture), UV2 a per-crystal random number and
its thickness (vertex colours do not reach the game); the game's shaders turn these into light. Flat shading throughout (facets are the look). <name>-colonly
meshes are the collision hulls. Renders are Cycles stills of each asset from four sides with the night's light.
"""
import bpy
import bmesh
import math
import os
import sys
import random
from mathutils import Vector, Matrix, noise

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art", "models", "wonders")
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ONLY = args[args.index("--only") + 1].split(",") if "--only" in args else ["shards", "heart", "steps"]
RENDERS = args[args.index("--renders") + 1] if "--renders" in args else ""
EXPORT = "--no-export" not in args
TAU = math.tau


def lerp(a, b, t):
    return a + (b - a) * t


def smooth(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a + 1e-9)))
    return t * t * (3 - 2 * t)


def hsv(h, s, v):
    import colorsys
    r, g, b = colorsys.hsv_to_rgb(h % 1.0, s, v)

    def lin(c):
        return c ** 2.2
    return (lin(r), lin(g), lin(b))


class Piece:
    """One mesh under construction. Per vertex: the glow parameter (UV.x: 0 at a crystal's root, 1 at its tip) and the
    crystal's own random number (its teal-or-violet cast: UV2.x). Per face: the kind (UV.y): 0 a crystal face, 0.5
    fused glass (a skirt round a root; a shell plate's lit inner face), 1 a fracture (a snapped top, a walking top, a
    shell's hot edge, the star's molten drips). At the finish every face is poked into a fan round its centre, and
    UV2.y runs from 1 at the centre to 0 on the face's edges: the shader's thick cores and bright edges. Faces are
    wound outward by construction. Vertex colours do not reach the game, so everything rides in the two UV sets."""

    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.col = {}
        self.kind = {}
        self.cur = 0.0

    def v(self, co, rgba):
        vv = self.bm.verts.new(co)
        self.col[vv] = rgba
        return vv

    def f(self, verts, kind=None):
        try:
            fc = self.bm.faces.new(verts)
        except ValueError:
            return None
        fc.smooth = False
        self.kind[fc] = self.cur if kind is None else kind
        return fc

    def finish(self, recalc=False, poke=True):
        bm = self.bm
        if recalc:
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        centres = set()

        def mixv(a, b, t):
            ca, cb = self.col.get(a, (0.5, 0.5, 0.0, 0.0)), self.col.get(b, (0.5, 0.5, 0.0, 0.0))
            return a.co.lerp(b.co, t), tuple(lerp(ca[i], cb[i], t) for i in range(4))

        def new_v(co_col, centre):
            vv = bm.verts.new(co_col[0])
            self.col[vv] = co_col[1]
            if centre:
                centres.add(vv)
            return vv

        if poke:
            for fc in list(bm.faces):
                k = self.kind.get(fc, self.cur)
                vs = list(fc.verts)
                if len(vs) == 4:
                    a, b, c, d = vs
                    if (b.co - c.co).length + (d.co - a.co).length < (a.co - b.co).length + (c.co - d.co).length:
                        a, b, c, d = b, c, d, a
                    long_len = 0.5 * ((b.co - c.co).length + (d.co - a.co).length)
                    short_len = max(0.5 * ((a.co - b.co).length + (c.co - d.co).length), 1e-4)
                    n = min(12, int(round(long_len / short_len)))
                    if n >= 2:
                        # a long face: a spine up its middle, so the core runs its whole length and only the edges
                        # (the long ones and the two short ends) fall to zero
                        lefts = [a] + [new_v(mixv(a, d, i / n), False) for i in range(1, n)] + [d]
                        rights = [b] + [new_v(mixv(b, c, i / n), False) for i in range(1, n)] + [c]
                        mids = []
                        for i in range(n + 1):
                            co_l, col_l = mixv(a, d, i / n)
                            co_r, col_r = mixv(b, c, i / n)
                            mids.append(new_v(((co_l + co_r) * 0.5, tuple((col_l[q] + col_r[q]) * 0.5 for q in range(4))), 0 < i < n))
                        tris = []
                        # each cell is split on the diagonal that touches an inner spine point (the two end points
                        # sit on the short edges): no triangle lies wholly on the edge
                        for i in range(n):
                            if i == 0:
                                tris += [[lefts[i], mids[i], mids[i + 1]], [lefts[i], mids[i + 1], lefts[i + 1]],
                                         [mids[i], rights[i], mids[i + 1]], [rights[i], rights[i + 1], mids[i + 1]]]
                            else:
                                tris += [[lefts[i], mids[i], lefts[i + 1]], [mids[i], mids[i + 1], lefts[i + 1]],
                                         [mids[i], rights[i], rights[i + 1]], [mids[i], rights[i + 1], mids[i + 1]]]
                        for tri in tris:
                            nf = bm.faces.new(tri)
                            self.kind[nf] = k
                        bmesh.ops.delete(bm, geom=[fc], context='FACES_ONLY')
                        continue
                cols = [self.col.get(v, (0.5, 0.5, 0.0, 0.0)) for v in vs]
                cv = bm.verts.new(sum((v.co for v in vs), Vector()) / len(vs))
                self.col[cv] = tuple(sum(c[i] for c in cols) / len(cols) for i in range(4))
                centres.add(cv)
                for i in range(len(vs)):
                    nf = bm.faces.new([vs[i], vs[(i + 1) % len(vs)], cv])
                    self.kind[nf] = k
                bmesh.ops.delete(bm, geom=[fc], context='FACES_ONLY')
        layer = bm.loops.layers.color.new("Col")
        uvl = bm.loops.layers.uv.new("UVMap")
        uv2 = bm.loops.layers.uv.new("UV2")
        for fc in bm.faces:
            fc.smooth = False
            k = self.kind.get(fc, self.cur)
            for lp in fc.loops:
                c = self.col.get(lp.vert, (0.5, 0.5, 0.0, 0.0))
                lp[layer] = (c[0], c[1], c[2], 1.0)
                # glTF flips V on the way out and Godot reads it as stored: write 1 - v so the game reads v
                lp[uvl].uv = (c[3], 1.0 - k)
                lp[uv2].uv = (c[0], 1.0 - (1.0 if lp.vert in centres else 0.0))
        me = bpy.data.meshes.new(self.name)
        bm.to_mesh(me)
        bm.free()
        me.color_attributes.active_color = me.color_attributes["Col"]
        ob = bpy.data.objects.new(self.name, me)
        bpy.context.scene.collection.objects.link(ob)
        return ob


# --- crystals ---------------------------------------------------------------------------------------------

def basis_for(a):
    e1 = a.cross(Vector((0, 0, 1)) if abs(a.z) < 0.95 else Vector((1, 0, 0))).normalized()
    e2 = a.cross(e1).normalized()
    return e1, e2


def lean_dir(lean, az):
    lr, ar = math.radians(lean), math.radians(az)
    return Vector((math.sin(lr) * math.cos(ar), math.sin(lr) * math.sin(ar), math.cos(lr)))


def crystal(pc, p0, axis, L, R, rng, sides=6, broken=False, sink=0.0, cap=True, rnd=None):
    """A quartz point: a hexagonal prism (faces of unequal width, a slight taper) and a termination of six
    rhombohedral faces raked to an off-centre apex, its foot edge a zigzag; or, `broken`, snapped across on an oblique
    conchoidal face (a fracture). `L` is the length above the ground; `sink` more is buried. Alpha 0 at the ground
    to 1 at the tip."""
    a = axis.normalized()
    e1, e2 = basis_for(a)
    rnd = rng.random() if rnd is None else rnd
    thick = min(1.0, R / 3.0)
    ang0 = rng.uniform(0, TAU)
    phis = [ang0 + TAU * j / sides + rng.uniform(-0.1, 0.1) for j in range(sides)]
    rads = [R * rng.uniform(0.86, 1.12) for _ in range(sides)]
    taper = rng.uniform(0.84, 0.96)
    base = p0 - a * sink
    tot = L + sink

    def glow(z):
        return max(0.0, min(1.0, (z - sink) / L))

    def ring(zs, scale):
        out = []
        for j in range(sides):
            z = zs[j] if isinstance(zs, list) else zs
            co = base + a * z + (e1 * math.cos(phis[j]) + e2 * math.sin(phis[j])) * rads[j] * scale
            out.append(pc.v(co, (rnd, thick, 0.0, glow(z))))
        return out

    if broken:
        cut = tot * rng.uniform(0.6, 0.84)
        phic = rng.uniform(0, TAU)
        slope = rng.uniform(0.25, 0.75)
        tops = [cut + slope * rads[j] * math.cos(phis[j] - phic) for j in range(sides)]
    else:
        th = R * rng.uniform(1.1, 1.55)
        cut = max(tot - th, tot * 0.4)
        tops = [cut + (j % 2) * R * rng.uniform(0.08, 0.3) for j in range(sides)]
    sc_top = lerp(1.0, taper, cut / tot)
    rings = [ring(0.0, 1.0), ring(tops, sc_top)]
    for r0, r1 in zip(rings[:-1], rings[1:]):
        for j in range(sides):
            k = (j + 1) % sides
            pc.f([r0[j], r0[k], r1[k], r1[j]], 0.0)
    top = rings[-1]
    if broken:
        # a shallow conchoidal dish: the fracture face, a fan round a sunken centre
        dish = base + a * (sum(tops) / sides - R * rng.uniform(0.05, 0.16))
        cv = pc.v(dish, (rnd, thick, 0.0, glow(cut)))
        for j in range(sides):
            k = (j + 1) % sides
            pc.f([top[j], top[k], cv], 1.0)
    else:
        apex = pc.v(base + a * tot + (e1 * rng.uniform(-0.3, 0.3) + e2 * rng.uniform(-0.3, 0.3)) * R, (rnd, thick, 0.0, 1.0))
        for j in range(sides):
            k = (j + 1) % sides
            pc.f([top[j], top[k], apex], 0.0)
    if cap:
        pc.f(rings[0][::-1], 0.0)


def mound(pc, R, height, rng, tongues=5, seed=0):
    """A skirt of fused glass round a root: a low cone of rings, tongues of it flowing out over the salt.
    Alpha: 0 at the root, 1 at the lip."""
    rings = 6
    n = 28
    grid = []
    rnd = rng.random()
    tongue_ang = [rng.uniform(0, TAU) for _ in range(tongues)]
    tongue_len = [rng.uniform(0.3, 0.9) for _ in range(tongues)]
    for ri in range(rings + 1):
        u = max(ri / rings, 0.04)
        row = []
        for j in range(n):
            th = TAU * j / n
            s = 1.0
            for ta, tl in zip(tongue_ang, tongue_len):
                d = abs(((th - ta + math.pi) % TAU) - math.pi)
                s += tl * math.exp(-(d / 0.28) ** 2) * u * u
            rr = R * u * s * (1 + 0.12 * noise.noise(Vector((math.cos(th) * 1.7 + seed, math.sin(th) * 1.7, u * 2))))
            h = height * (1 - u ** 1.7) * (1 + 0.25 * noise.noise(Vector((math.cos(th) * 2.2, math.sin(th) * 2.2 + seed, u * 3))))
            z = h + 0.12 * (u > 0.85) * noise.noise(Vector((th * 3, u * 4, seed))) - 0.12 * u
            row.append(pc.v(Vector((math.cos(th) * rr, math.sin(th) * rr, z)), (rnd, 0.0, 0.0, u)))
        grid.append(row)
    for ri in range(rings):
        for j in range(n):
            k = (j + 1) % n
            pc.f([grid[ri][j], grid[ri + 1][j], grid[ri + 1][k], grid[ri][k]], 0.5)
    return grid


def cluster(name, seed, mains, n_sat, n_chip, R_mound, throw=0.35):
    """A druse thrown up out of the glass: `mains` (length, radius, lean degrees, azimuth degrees, broken), the
    first the great one, each with a few sprouts low on its flanks; satellites fanning out round the root (slim,
    leaning outward and along +X, the throw); chips scattered further out; a skirt of fused glass under it all."""
    rng = random.Random(seed)
    pc = Piece(name)
    mound(pc, R_mound, 0.7, rng, tongues=5, seed=seed)
    up = Vector((0, 0, 1))
    for (L, R, lean, az, broken) in mains:
        a = lean_dir(lean, az)
        crystal(pc, Vector((0, 0, 0.0)), a, L, R, rng, broken=broken, sink=R * 0.5 + 0.4)
        if L > 7.0:
            e1m, e2m = basis_for(a)
            for _ in range(rng.randint(2, 4)):
                t = rng.uniform(0.06, 0.32)
                ph = rng.uniform(0, TAU)
                out_d = e1m * math.cos(ph) + e2m * math.sin(ph)
                pos = a * (L * t) + out_d * R * 0.55
                ax = (out_d * 0.9 + a * 0.8).normalized()
                Ls = L * rng.uniform(0.1, 0.2)
                crystal(pc, pos, ax, Ls, Ls / rng.uniform(4.0, 6.0), rng, broken=rng.random() < 0.2, sink=R * 0.45, cap=False)
    L0, R0 = mains[0][0], mains[0][1]
    for i in range(n_sat):
        az = TAU * (i + rng.uniform(-0.35, 0.35)) / n_sat
        rad = R0 * rng.uniform(0.6, 1.5)
        lean = math.radians(rng.uniform(16, 52))
        out = Vector((math.cos(az), math.sin(az), 0.0))
        a = (out * math.sin(lean) + up * math.cos(lean) + Vector((throw, 0, 0))).normalized()
        Ls = L0 * rng.uniform(0.12, 0.4)
        Rs = Ls / rng.uniform(4.5, 7.5)
        crystal(pc, Vector((math.cos(az) * rad, math.sin(az) * rad, 0.0)), a, Ls, Rs, rng, broken=rng.random() < 0.2, sink=Rs * 0.9 + 0.2)
    for i in range(n_chip):
        az = rng.uniform(0, TAU)
        rad = R0 * rng.uniform(1.3, 2.8)
        lean = math.radians(rng.uniform(25, 70))
        out = Vector((math.cos(az + 0.3), math.sin(az + 0.3), 0.0))
        a = (out * math.sin(lean) + up * math.cos(lean)).normalized()
        Lc = rng.uniform(0.5, 2.0)
        crystal(pc, Vector((math.cos(az) * rad, math.sin(az) * rad, 0.0)), a, Lc, Lc / rng.uniform(3.5, 5.5), rng, broken=rng.random() < 0.15, sink=0.25)
    return pc.finish()


def colonly_hull(name, pts_fn):
    bm = bmesh.new()
    pts = pts_fn()
    for p in pts:
        bm.verts.new(p)
    bmesh.ops.convex_hull(bm, input=bm.verts[:])
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def column_colonly(name, L, R, lean_deg, az_deg=0.0, sink=0.9):
    """A coarse solid for the main crystal: a six-sided prism with a pointed top (the rest is dressing)."""
    a = Vector((math.sin(math.radians(lean_deg)) * math.cos(math.radians(az_deg)), math.sin(math.radians(lean_deg)) * math.sin(math.radians(az_deg)), math.cos(math.radians(lean_deg))))
    e1, e2 = basis_for(a)

    def pts():
        out = []
        base = Vector((0, 0, 0.1)) - a * sink
        for t, rs in ((0.0, 1.08), (0.8, 0.98)):
            for j in range(6):
                phi = TAU * j / 6
                out.append(base + a * (L * t) + (e1 * math.cos(phi) + e2 * math.sin(phi)) * R * rs)
        out.append(base + a * L)
        return out
    return colonly_hull(name, pts)


# ============================================================================================================
# SHARDS
# ============================================================================================================
def build_shards():
    out = []
    # three great druses, each a family of quartz points thrown up and out from one root (leaning towards +X, outward)
    great = (("shard_great_a", 11, [(30.0, 3.3, 14, 0, False), (19.0, 2.3, 34, 150, False), (13.0, 1.8, 40, 245, True),
                                    (9.0, 1.3, 46, 70, False), (7.0, 1.0, 30, 300, False)], 9, 12, 3.6),
             ("shard_great_b", 23, [(22.0, 2.8, 22, 20, False), (15.0, 2.0, 10, 200, True), (11.0, 1.6, 40, 300, False),
                                    (7.5, 1.1, 48, 110, False)], 8, 10, 3.2),
             ("shard_great_c", 37, [(17.0, 2.6, 28, 0, True), (13.0, 1.9, 44, 160, False), (9.0, 1.4, 38, 275, False),
                                    (6.0, 1.0, 50, 60, False)], 8, 10, 3.2))
    for nm, seed, mains, n_sat, n_chip, r_mound in great:
        out.append(cluster(nm, seed, mains, n_sat, n_chip, r_mound))
        L, R, lean, az, _b = mains[0]
        sink = R * 0.5 + 0.4
        out.append(column_colonly(nm + "-colonly", L + sink, R, lean, az, sink))
    # rays: one long point thrown low across the pans, a few small ones at its root
    for nm, seed, L, R, lean in (("shard_ray_a", 51, 11.0, 1.6, 68), ("shard_ray_b", 64, 7.5, 1.1, 74)):
        out.append(cluster(nm, seed, [(L, R, lean, 0, False)], 4, 5, 2.2))
        sink = R * 0.5 + 0.4
        out.append(column_colonly(nm + "-colonly", L + sink, R, lean, 0.0, sink))
    out.append(cluster("shard_crown_a", 71, [(4.6, 0.8, 12, 0, False), (3.3, 0.6, 30, 140, False), (2.6, 0.5, 26, 250, True)], 4, 4, 1.2))
    out.append(cluster("shard_crown_b", 83, [(3.4, 0.65, 18, 30, True), (2.3, 0.5, 36, 210, False)], 3, 5, 1.0))
    return out


# ============================================================================================================
# RIM SLABS
# ============================================================================================================
def rim_slab(name, seed, W, D, T, hue=0.6):
    """A heaved plate of fused crust: a spiky, broken outline; a faceted roof (every facet a different plane, like
    a struck pane); thick at the ridge, knife-thin at the lip; one corner snapped to a point."""
    rng = random.Random(seed)
    pc = Piece(name)
    n = 9
    dark = hsv(hue + 0.05, 0.9, 0.03)
    mid = hsv(hue, 0.75, 0.10)
    edge = hsv(hue - 0.02, 0.55, 0.30)
    ang = [TAU * j / n + rng.uniform(-0.18, 0.18) for j in range(n)]
    rad = [(1.25 if j % 3 == 0 else 0.62 + rng.uniform(-0.08, 0.2)) for j in range(n)]
    ridge = Vector((rng.uniform(-0.25, 0.25) * W, rng.uniform(-0.25, 0.25) * D, T * 1.15))
    apex = pc.v(ridge, (mid[0], mid[1], mid[2], 0.1))
    inner = []
    for j in range(n):
        th = ang[j]
        rr = rad[j] * 0.52
        inner.append(pc.v(Vector((math.cos(th) * rr * W, math.sin(th) * rr * D, T * rng.uniform(0.55, 0.95))), (mid[0], mid[1], mid[2], 0.12)))
    outer = []
    for j in range(n):
        th = ang[j]
        outer.append(pc.v(Vector((math.cos(th) * rad[j] * W, math.sin(th) * rad[j] * D, T * rng.uniform(0.0, 0.3))), (edge[0], edge[1], edge[2], 0.5 + 0.4 * (j % 3 == 0))))
    under = []
    for j in range(n):
        x, y, _ = outer[j].co
        under.append(pc.v(Vector((x * 0.55, y * 0.55, -T * rng.uniform(0.7, 1.2))), (dark[0], dark[1], dark[2], 0.0)))
    for j in range(n):
        k = (j + 1) % n
        pc.f([apex, inner[j], inner[k]])
        pc.f([inner[j], outer[j], outer[k], inner[k]])
        pc.f([outer[j], under[j], under[k], outer[k]])
    pc.f(under[::-1])
    return pc.finish(recalc=True)


def build_rim():
    out = []
    for i, (W, D, T, seed) in enumerate(((3.6, 2.2, 0.9, 5), (2.6, 2.0, 0.7, 9), (4.4, 2.6, 1.1, 13))):
        out.append(rim_slab("rim_slab_" + "abc"[i], seed, W, D, T))
    return out


# ============================================================================================================
# THE HEART
# ============================================================================================================
def fib_dirs(n, rng):
    out = []
    ga = math.pi * (3 - math.sqrt(5))
    for i in range(n):
        z = 1 - 2 * (i + 0.5) / n
        r = math.sqrt(1 - z * z)
        th = ga * i + rng.uniform(-0.15, 0.15)
        out.append(Vector((math.cos(th) * r, math.sin(th) * r, z)))
    return out


def shell_plate(pc, rng, dirc, outline, r_in, thick):
    """A broken piece of the star's crust laid close over the core: a curved plate on a sphere, a jagged outline of
    sharp teeth; the outer face black glass (kind 0), the inner face lit by the core (0.5), the broken edge a glowing
    seam (1). Added to `pc` (all the plates are one mesh: they turn with the core)."""
    dirc = dirc.normalized()
    e1, e2 = basis_for(dirc)
    n = len(outline)

    def sph(phi, rho, radius):
        d = dirc * math.cos(rho) + (e1 * math.cos(phi) + e2 * math.sin(phi)) * math.sin(rho)
        return d * radius

    ro = r_in + thick
    rnd = rng.random()
    c_o = pc.v(sph(0.0, 0.0, ro), (rnd, 0.0, 0.0, 0.0))
    c_i = pc.v(sph(0.0, 0.0, r_in), (rnd, 0.0, 0.0, 0.0))
    mid_o = [pc.v(sph(p, r * 0.55, ro * rng.uniform(0.995, 1.01)), (rnd, 0.0, 0.0, 0.5)) for p, r in outline]
    mid_i = [pc.v(sph(p, r * 0.55, r_in), (rnd, 0.0, 0.0, 0.5)) for p, r in outline]
    out_o = [pc.v(sph(p, r, ro * rng.uniform(0.99, 1.0)), (rnd, 0.0, 0.0, 1.0)) for p, r in outline]
    out_i = [pc.v(sph(p, r * 0.97, r_in), (rnd, 0.0, 0.0, 1.0)) for p, r in outline]
    for j in range(n):
        k = (j + 1) % n
        pc.f([c_o, mid_o[j], mid_o[k]], 0.0)
        pc.f([mid_o[j], out_o[j], out_o[k], mid_o[k]], 0.0)
        pc.f([c_i, mid_i[k], mid_i[j]], 0.5)
        pc.f([mid_i[j], mid_i[k], out_i[k], out_i[j]], 0.5)
        pc.f([out_o[j], out_i[j], out_i[k], out_o[k]], 1.0)


def build_heart():
    """THE FALLEN STAR: a dense core of many small facets (hot white at the heart of each, violet-blue at its edges
    in the game), broken plates of black glass crust laid close over it with glowing seams between them, thin
    threads of molten glass hanging beneath, small chips of crust further out."""
    rng = random.Random(7)
    out = []
    pc = Piece("heart_core")
    # an irregular gem: the hull of scattered points on a lumpy sphere (facets of every size and shape, no geodesic
    # pattern)
    for d in fib_dirs(1100, rng):
        d = (d + Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))) * 0.05).normalized()
        r = 2.2 * (1.0 + 0.06 * noise.noise(d * 2.3 + Vector((3, 1, 2))) + rng.uniform(-0.035, 0.035))
        pc.v(d * r, (0.5, 1.0, 0.0, 0.0))
    bmesh.ops.convex_hull(pc.bm, input=pc.bm.verts[:])
    for v in [v for v in pc.bm.verts if not v.link_faces]:
        pc.bm.verts.remove(v)
    bmesh.ops.recalc_face_normals(pc.bm, faces=pc.bm.faces[:])
    for fc in pc.bm.faces:
        fc.smooth = False
        pc.kind[fc] = 0.0
    out.append(pc.finish())
    # threads of molten glass: thin, long, slightly swaying strands from the underside, hot at the root
    pd = Piece("heart_drips")
    pd.cur = 1.0
    for i in range(11):
        th = TAU * (i + rng.uniform(-0.35, 0.35)) / 11
        s = rng.uniform(0.1, 0.8)
        d = Vector((math.cos(th) * s, math.sin(th) * s, -1.0)).normalized()
        base = d * 2.15
        L = rng.uniform(0.9, 3.2) * (1.0 - 0.35 * s)
        w0 = rng.uniform(0.018, 0.032)
        sw = Vector((rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3), 0.0))
        prev = None
        steps = 8
        for si in range(steps + 1):
            t = si / steps
            w = w0 * (1.0 - 0.7 * t) + 0.006
            ring = []
            for q in range(5):
                qa = TAU * q / 5 + th
                co = base + sw * (t * t) + Vector((math.cos(qa) * w, math.sin(qa) * w, -L * t))
                ring.append(pd.v(co, (0.5, 0.0, 0.0, 1.0 - t)))
            if prev:
                for q in range(5):
                    k = (q + 1) % 5
                    pd.f([prev[q], ring[q], ring[k], prev[k]])
            prev = ring
        tip = pd.v(base + sw + Vector((0.0, 0.0, -L * 1.02)), (0.5, 0.0, 0.0, 0.0))
        for q in range(5):
            k = (q + 1) % 5
            pd.f([prev[k], prev[q], tip])
    out.append(pd.finish())
    # the crust: the upper two thirds of a shell of black glass a hand's breadth over the core, broken into
    # shards along the cells round scattered seeds (thin glowing seams between them), its lower edge torn ragged
    # where the shell broke open and the light comes out
    ps = Piece("heart_shell")
    seeds = []
    for d in fib_dirs(80, rng):
        d = (d + Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))) * 0.1).normalized()
        if d.z > -0.2 - 0.25 * rng.random():
            seeds.append(d)

    def owner(v):
        return max(range(len(seeds)), key=lambda i: v.dot(seeds[i]))

    for si, sd in enumerate(seeds):
        sr = random.Random(300 + si)
        if sr.random() < 0.3:
            continue                                   # a shard fallen away: a window onto the core
        e1, e2 = basis_for(sd)
        outline = []
        n = 22
        for j in range(n):
            phi = TAU * j / n
            dirp = e1 * math.cos(phi) + e2 * math.sin(phi)
            lo, hi = 0.0, 1.2
            for _ in range(18):
                m = (lo + hi) * 0.5
                v = sd * math.cos(m) + dirp * math.sin(m)
                if owner(v) == si and v.z > -0.62:
                    lo = m
                else:
                    hi = m
            rho = lo * sr.uniform(0.8, 0.9) - 0.015
            if j % 2 == 1:
                rho *= sr.uniform(0.86, 1.0)          # teeth along the broken edge
            outline.append((phi, max(rho, 0.05)))
        shell_plate(ps, sr, sd, outline, 2.46 + sr.uniform(0.0, 0.16), sr.uniform(0.05, 0.08))
    out.append(ps.finish())
    # six small chips of the shell for further out: a curved plate, a broken edge (kind 1), a lit underside (0.5)
    for i in range(6):
        r = random.Random(200 + i)
        pf = Piece("frag_" + "abcdef"[i])
        n = 7
        sz = r.uniform(0.45, 0.9)
        outer = []
        inner = []
        for j in range(n):
            th = TAU * j / n + r.uniform(-0.2, 0.2)
            rr = sz * (1.0 if j % 2 else r.uniform(0.55, 0.8))
            x, y = math.cos(th) * rr, math.sin(th) * rr * 0.75
            z = 0.28 * (x * x + y * y) / (sz * sz) * sz * 0.6
            outer.append(pf.v(Vector((x, y, z)), (0.5, 0.0, 0.0, 0.0)))
            inner.append(pf.v(Vector((x * 0.9, y * 0.9, z - 0.18 * sz * r.uniform(0.6, 1.2))), (0.5, 0.0, 0.0, 0.0)))
        topc = pf.v(Vector((0, 0, -0.03 * sz)), (0.5, 0.0, 0.0, 0.0))
        botc = pf.v(Vector((0, 0, -0.2 * sz)), (0.5, 0.0, 0.0, 0.0))
        for j in range(n):
            k = (j + 1) % n
            pf.f([topc, outer[j], outer[k]], 0.0)
            pf.f([outer[j], inner[j], inner[k], outer[k]], 1.0)
            pf.f([botc, inner[k], inner[j]], 0.5)
        out.append(pf.finish(recalc=True))
    return out


# ============================================================================================================
# STEPS
# ============================================================================================================
def ridge_plate(name, seed, R, depth, edge_crystals=3, sides=6, flank=2, crown=0.0):
    """A column of quartz heaved up out of the crater floor and snapped off: a fused, faintly domed walking face at
    z = 0 (a fracture, kind 1), a chamfer where the edge chipped, six prism faces of unequal width running down
    `depth` metres (a little wider at the root), and small points grown out of its flanks below the walking face."""
    rng = random.Random(seed)
    pc = Piece(name)
    rnd = rng.random()
    ang0 = rng.uniform(0, TAU)
    phis = [ang0 + TAU * j / sides + rng.uniform(-0.12, 0.12) for j in range(sides)]
    rads = [R * rng.uniform(0.9, 1.1) for _ in range(sides)]

    def ring(scale, z, alpha, jit=0.0):
        return [pc.v(Vector((math.cos(phis[j]) * rads[j] * scale, math.sin(phis[j]) * rads[j] * scale, z + rng.uniform(-jit, jit))), (rnd, 1.0, 0.0, alpha))
                for j in range(sides)]

    centre = pc.v(Vector((rng.uniform(-0.15, 0.15) * R, rng.uniform(-0.15, 0.15) * R, 0.03)), (rnd, 1.0, 0.0, 1.0))
    inner = ring(0.52, 0.0, 1.0, 0.03)
    top = ring(0.9, -0.03, 1.0, 0.02)
    chamf = [pc.v(Vector((math.cos(phis[j]) * rads[j], math.sin(phis[j]) * rads[j], -rng.uniform(0.22, 0.42))), (rnd, 1.0, 0.0, 0.94)) for j in range(sides)]
    bot = ring(1.06, -depth, 0.0)
    for j in range(sides):
        k = (j + 1) % sides
        pc.f([centre, inner[j], inner[k]], 1.0)
        pc.f([inner[j], top[j], top[k], inner[k]], 1.0)
        pc.f([top[j], chamf[j], chamf[k], top[k]], 0.0)
        pc.f([chamf[j], bot[j], bot[k], chamf[k]], 0.0)
    pc.f(bot[::-1], 0.0)
    # flanking points grown up alongside the column out of the floor, all on its +X side (the game turns that side
    # away from the climb): a plate's stay under its walking face, the shelf's rise past it as a crown
    for i in range(flank):
        az = math.radians(rng.uniform(-55.0, 55.0) if crown == 0.0 else lerp(-105.0, 105.0, (i + rng.uniform(0.2, 0.8)) / flank))
        out_d = Vector((math.cos(az), math.sin(az), 0.0))
        lean = math.radians(rng.uniform(8.0, 18.0) if crown == 0.0 else rng.uniform(16.0, 30.0))
        a = (out_d * math.sin(lean) + Vector((0, 0, math.cos(lean)))).normalized()
        tip_z = -rng.uniform(0.45, 1.3) if crown == 0.0 else crown * rng.uniform(0.35, 1.0)
        Lf = (tip_z + depth) / a.z
        Rf = R * (rng.uniform(0.3, 0.42) if crown == 0.0 else rng.uniform(0.2, 0.3))
        crystal(pc, out_d * R * (0.78 if crown == 0.0 else 0.92) + Vector((0, 0, -depth)), a, Lf, Rf, rng, broken=rng.random() < 0.3, sink=0.0, cap=True, rnd=rng.random())
    # small points out of the flanks, pointing out and down, below the walking face
    for i in range(edge_crystals):
        az = math.radians(rng.uniform(-60.0, 60.0))
        out_d = Vector((math.cos(az), math.sin(az), 0.0))
        z0 = -rng.uniform(0.9, 2.2)
        a = (out_d + Vector((0, 0, rng.uniform(-0.6, 0.1)))).normalized()
        Ls = rng.uniform(0.9, 1.8)
        crystal(pc, out_d * R * 0.85 + Vector((0, 0, z0)), a, Ls, Ls / rng.uniform(4.0, 5.5), rng, broken=rng.random() < 0.3, sink=0.25, cap=False, rnd=rnd)
    return pc.finish()


def build_ridge():
    out = []
    for i, (R, seed) in enumerate(((2.1, 3), (2.3, 8), (1.9, 15), (2.2, 21))):
        nm = "ridge_plate_" + "abcd"[i]
        out.append(ridge_plate(nm, seed, R, 4.4))
        out.append(colonly_hull(nm + "-colonly", lambda R=R: [Vector((math.cos(TAU * q / 8 + 0.2) * R * k, math.sin(TAU * q / 8 + 0.2) * R * k, z)) for q in range(8) for k, z in ((0.88, 0.0), (0.84, -1.8), (0.55, -4.4))]))
    out.append(ridge_plate("ridge_shelf", 33, 3.6, 5.0, edge_crystals=4, sides=7, flank=6, crown=2.6))
    out.append(colonly_hull("ridge_shelf-colonly", lambda: [Vector((math.cos(TAU * q / 10 + 0.1) * 3.4 * k, math.sin(TAU * q / 10 + 0.1) * 3.4 * k, z)) for q in range(10) for k, z in ((0.95, 0.0), (0.9, -2.0), (0.6, -5.0))]))
    return out


# ============================================================================================================
# materials, renders, export
# ============================================================================================================
def preview_material():
    m = bpy.data.materials.get("crater_preview")
    if m:
        return m
    m = bpy.data.materials.new("crater_preview")
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    # a stand-in for the game's shader: milky and lit at the root, clear and dark towards the tip, fractures bright
    uv = nt.nodes.new("ShaderNodeUVMap")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(uv.outputs["UV"], sep.inputs[0])
    root = nt.nodes.new("ShaderNodeMath")
    root.operation = 'SUBTRACT'
    root.inputs[0].default_value = 1.0
    nt.links.new(sep.outputs["X"], root.inputs[1])
    glow = nt.nodes.new("ShaderNodeMath")
    glow.operation = 'MAXIMUM'
    nt.links.new(root.outputs[0], glow.inputs[0])
    nt.links.new(sep.outputs["Y"], glow.inputs[1])
    em = nt.nodes.new("ShaderNodeMix")
    em.data_type = 'RGBA'
    em.inputs[6].default_value = (0.03, 0.04, 0.12, 1)
    em.inputs[7].default_value = (0.7, 0.85, 1.0, 1)
    nt.links.new(glow.outputs[0], em.inputs[0])
    bsdf.inputs["Base Color"].default_value = (0.02, 0.025, 0.05, 1)
    nt.links.new(em.outputs[2], bsdf.inputs["Emission Color"])
    bsdf.inputs["Emission Strength"].default_value = 1.2
    bsdf.inputs["Roughness"].default_value = 0.12
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return m


def set_materials(objs):
    pm = preview_material()
    for o in objs:
        if o.name.endswith("-colonly"):
            continue
        o.data.materials.clear()
        o.data.materials.append(pm)


def render_sheet(label, objs, view_h, dist, lens=45, extra_lights=True, size=640):
    """Four views (0, 90, 180, 270 degrees) of `objs` plus one from above, into one sheet."""
    if not RENDERS:
        return
    os.makedirs(RENDERS, exist_ok=True)
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.device = 'CPU'
    sc.cycles.samples = 48
    sc.cycles.use_denoising = True
    sc.render.resolution_x = sc.render.resolution_y = size
    sc.render.film_transparent = False
    w = bpy.data.worlds.new("night")
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.004, 0.008, 0.022, 1)
    w.node_tree.nodes["Background"].inputs[1].default_value = 1.0
    sc.world = w
    ids = [x.identifier for x in sc.view_settings.bl_rna.properties['view_transform'].enum_items]
    sc.view_settings.view_transform = 'AgX' if 'AgX' in ids else 'Standard'
    lights = []
    # sun lamps (crisp facets): a cold key from the front-left, a violet rim from behind, a cyan kick from low
    for nm, rot, col, e in (("key", (55, 0, 35), (0.6, 0.75, 1.0), 2.6), ("rim", (65, 0, 215), (0.55, 0.32, 1.0), 3.2), ("low", (112, 0, 120), (0.25, 0.75, 1.0), 1.4)):
        ld = bpy.data.lights.new(nm, 'SUN')
        ld.energy = e
        ld.color = col
        ld.angle = 0.05
        lo = bpy.data.objects.new(nm, ld)
        lo.rotation_euler = tuple(math.radians(r) for r in rot)
        bpy.context.scene.collection.objects.link(lo)
        lights.append(lo)
    cam_d = bpy.data.cameras.new("cam")
    cam_d.lens = lens
    cam_d.clip_end = 1000
    cam = bpy.data.objects.new("cam", cam_d)
    bpy.context.scene.collection.objects.link(cam)
    sc.camera = cam
    for o in bpy.data.objects:
        if o.name.endswith("-colonly"):
            o.hide_render = True
    target = Vector((0, 0, view_h * 0.5))
    files = []
    views = [(a, 10) for a in (0, 90, 180, 270)] + [(45, 62)]
    for i, (az, el) in enumerate(views):
        ar, er = math.radians(az), math.radians(el)
        cam.location = target + Vector((math.cos(ar) * math.cos(er), math.sin(ar) * math.cos(er), math.sin(er))) * dist
        cam.rotation_euler = (target - cam.location).to_track_quat('-Z', 'Y').to_euler()
        fp = os.path.join(RENDERS, "%s_%d.png" % (label, i))
        sc.render.filepath = fp
        bpy.ops.render.render(write_still=True)
        files.append(fp)
    montage(label, files, size)
    for o in lights + [cam]:
        bpy.data.objects.remove(o)


def montage(label, files, size):
    try:
        import numpy as np
    except ImportError:
        return
    imgs = []
    for fp in files:
        im = bpy.data.images.load(fp)
        a = np.array(im.pixels[:], dtype=np.float32).reshape(size, size, 4)
        imgs.append(a)
        bpy.data.images.remove(im)
    sheet = np.concatenate([np.concatenate(imgs[:3], axis=1), np.concatenate(imgs[3:] + [np.zeros_like(imgs[0])], axis=1)], axis=0)
    h, w, _ = sheet.shape
    out = bpy.data.images.new("sheet", w, h, alpha=True)
    out.pixels = sheet.reshape(-1).tolist()
    out.filepath_raw = os.path.join(RENDERS, "%s_sheet.png" % label)
    out.file_format = 'PNG'
    out.save()
    bpy.data.images.remove(out)


def export(objs, filename):
    if not EXPORT:
        return
    os.makedirs(OUT, exist_ok=True)
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    path = os.path.join(OUT, filename)
    kw = dict(filepath=path, export_format='GLB', use_selection=True, export_apply=True, export_yup=True,
              export_materials='EXPORT', export_image_format='NONE', export_normals=True, export_texcoords=True)
    try:
        bpy.ops.export_scene.gltf(export_vertex_color='ACTIVE', **kw)
    except TypeError:
        bpy.ops.export_scene.gltf(**kw)
    tris = sum(len(o.data.polygons) for o in objs if not o.name.endswith("-colonly"))
    print("EXPORTED %s: %d faces, objects %s" % (path, tris, [o.name for o in objs]))


def clear_scene():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    jobs = {
        "shards": (build_shards, "star_crater_shards.glb", [("great_a", ("shard_great_a",), 24, 46), ("great_b", ("shard_great_b",), 18, 34), ("great_c", ("shard_great_c",), 14, 27),
                                                           ("ray", ("shard_ray_a", "shard_ray_b"), 6, 24), ("crown", ("shard_crown_a", "shard_crown_b"), 4, 11)]),
        "rim": (build_rim, "star_crater_rim.glb", [("slab_a", ("rim_slab_a",), 1.0, 11), ("slab_c", ("rim_slab_c",), 1.0, 13)]),
        "heart": (build_heart, "star_crater_heart.glb", [("heart", ("heart_core", "heart_drips", "heart_shell"), 0.0, 14), ("frags", ("frag_a", "frag_b", "frag_c", "frag_d", "frag_e", "frag_f"), 0.0, 6)]),
        "steps": (build_ridge, "star_crater_ridge.glb", [("ridge", ("ridge_plate_a", "ridge_plate_b"), -2.0, 14), ("shelf", ("ridge_shelf",), -2.5, 16)]),
    }
    for key in ONLY:
        build, fname, sheets = jobs[key]
        clear_scene()
        objs = build()
        set_materials(objs)
        export(objs, fname)
        for label, names, h, dist in sheets:
            shown = [o for o in objs if (names is None or o.name in names) and not o.name.endswith("-colonly")]
            for o in objs:
                o.hide_render = o not in shown and not o.name.endswith("-colonly")
            # lay several pieces side by side for a sheet
            if len(shown) > 1 and names is not None:
                for i, o in enumerate(shown):
                    o.location.x = (i - (len(shown) - 1) / 2) * (dist * 0.35)
            if key == "heart":
                if label == "frags":
                    for i, o in enumerate(shown):
                        o.location.x = (i - 2.5) * 1.5
                else:
                    for o in shown:
                        o.location = Vector((0, 0, 0))
            render_sheet("%s_%s" % (key, label), shown, h, dist)
            for o in objs:
                o.hide_render = False
                if "-colonly" in o.name:
                    pass


main()
