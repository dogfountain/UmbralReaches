"""The Star-Fall Crater's hero assets, modelled by script (no scans, no downloads).

  star_crater_shards.glb   shard_great_a/b/c  quartz clusters rooted in fused glass: a tall main crystal with ledges,
                           a snapped or wedge termination, satellites and chips, a molten skirt that flows off the base
                           shard_ray_a/b      one long crystal thrown across the pans, dragging a tongue of glass
                           shard_crown_a/b    the small clusters along the crest
  star_crater_rim.glb      rim_slab_a/b/c     heaved plates of fused crust (conchoidal ripples, chipped edges)
  star_crater_heart.glb    heart_core         the star: a faceted core with long and short spikes
                           heart_ring_a/b/c   three broken bands (turned at different rates in the engine)
                           frag_a/b/c/d       the fragments that orbit it
  star_crater_steps.glb    step_a/b/c, platform  fused-glass slabs hung on a crystal point, with colonly hulls

  tools/blender/run.sh wonder_star_crater.py -- [--only shards,rim,heart,steps] [--renders DIR] [--no-export]

Conventions (Blender Z up -> Godot Y up; 1 BU = 1 m). Each asset is upright with its root at the origin (Z = 0) and
leans towards +X (Godot +X). Vertex colour: rgb the body colour, alpha 0 at a crystal's root and 1 at its tip, which the
game's crystal shader turns into glow. Flat shading throughout (facets are the look). <name>-colonly meshes are the
collision hulls. Renders are Cycles stills of each asset from four sides with the night's light.
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
ONLY = args[args.index("--only") + 1].split(",") if "--only" in args else ["shards", "rim", "heart", "steps"]
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
    """One mesh under construction: bmesh + a colour per vertex."""

    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.col = {}

    def v(self, co, rgba):
        vv = self.bm.verts.new(co)
        self.col[vv] = rgba
        return vv

    def f(self, verts):
        try:
            fc = self.bm.faces.new(verts)
            fc.smooth = False
            return fc
        except ValueError:
            return None

    def finish(self, recalc=True):
        bm = self.bm
        if recalc:
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        layer = bm.loops.layers.color.new("Col")
        for fc in bm.faces:
            fc.smooth = False
            for lp in fc.loops:
                lp[layer] = self.col.get(lp.vert, (0.05, 0.1, 0.15, 0.0))
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


def palette(hue, glassy=1.0):
    """root, mid, tip colours of a crystal of this hue (rgba, linear)."""
    root = hsv(hue + 0.04, 0.85, 0.05 * glassy + 0.02)
    mid = hsv(hue, 0.78, 0.13)
    tip = hsv(hue - 0.03, 0.55, 0.40)
    return root, mid, tip


def mixc(a, b, t, alpha):
    return (lerp(a[0], b[0], t), lerp(a[1], b[1], t), lerp(a[2], b[2], t), alpha)


def crystal(pc, p0, axis, L, R, rng, hue, sides=6, wedge=False, broken=False, bend=0.0, steps=1, sink=0.0, cap=True):
    """A quartz point: an irregular hexagonal column with growth ledges and a raked termination (a point, a wedge
    ridge, or a snapped oblique face). Alpha 0 at the root to 1 at the tip."""
    a = axis.normalized()
    e1, e2 = basis_for(a)
    root, mid, tip = palette(hue)
    side_s = [1.0 + rng.uniform(-0.16, 0.16) for _ in range(sides)]
    ang0 = rng.uniform(0, TAU)
    twist = rng.uniform(-0.2, 0.2)
    ledge = [rng.uniform(0.25, 1.3) for _ in range(sides)]
    prof = [(0.0, 1.12), (0.1, 1.0), (0.3, 1.02)]
    for k in range(steps):
        st = rng.uniform(0.38 + 0.12 * k, 0.5 + 0.14 * k)
        prof += [(st, 0.92 - 0.01 * k), (st + 0.014, 1.07 - 0.01 * k)]
    prof += [(0.76, 0.99)]
    prof.sort()
    prof = [(t * 0.995, r) for t, r in prof]
    base_origin = p0 - a * sink
    ring_verts = []
    for ri, (t, rs) in enumerate(prof):
        ring = []
        for j in range(sides):
            phi = ang0 + TAU * j / sides + twist * t
            rs_j = 1.0 + (rs - 1.0) * (ledge[j] if abs(rs - 1.0) > 0.035 else 1.0)
            rr = R * rs_j * side_s[j] * (1 + rng.uniform(-0.03, 0.03))
            centre = base_origin + a * (L * t + sink * (1 - t) * 0) + e1 * (bend * L * t * t)
            co = centre + (e1 * math.cos(phi) + e2 * math.sin(phi)) * rr
            alpha = max(0.0, min(1.0, t))
            c = mixc(root, mid, smooth(0.0, 0.6, t), alpha)
            ring.append(pc.v(co, c))
        ring_verts.append(ring)
    # the termination
    top_ring = []
    for j in range(sides):
        phi = ang0 + TAU * j / sides + twist
        lj = math.cos(phi) * 0.5 + 0.5
        t_top = 1.0 - (R * rng.uniform(1.4, 2.7)) / L if not broken else 0.8 + 0.12 * (lj - 0.5)
        t_top = max(t_top, prof[-1][0] + 0.02)
        rr = R * (rng.uniform(0.42, 0.82) if not broken else 0.78) * side_s[j]
        centre = base_origin + a * (L * t_top) + e1 * (bend * L * t_top * t_top)
        co = centre + (e1 * math.cos(phi) + e2 * math.sin(phi)) * rr
        top_ring.append(pc.v(co, mixc(mid, tip, 0.6, 0.86)))
    for r0, r1 in zip(ring_verts[:-1], ring_verts[1:]):
        for j in range(sides):
            k = (j + 1) % sides
            pc.f([r0[j], r0[k], r1[k], r1[j]])
    last = ring_verts[-1]
    for j in range(sides):
        k = (j + 1) % sides
        pc.f([last[j], last[k], top_ring[k], top_ring[j]])
    tipc = (tip[0] * 1.6, tip[1] * 1.6, tip[2] * 1.6, 1.0)
    if broken:
        pc.f(top_ring)
    elif wedge:
        ra = pc.v(base_origin + a * L * 0.995 + e1 * (bend * L) + (e1 * math.cos(ang0) + e2 * math.sin(ang0)) * R * 0.3, tipc)
        rb = pc.v(base_origin + a * L * 0.985 + e1 * (bend * L) - (e1 * math.cos(ang0) + e2 * math.sin(ang0)) * R * 0.3, tipc)
        grp = [math.cos(ang0 + TAU * j / sides - ang0) * 0.0 + (1 if j < sides // 2 else 0) for j in range(sides)]
        for j in range(sides):
            k = (j + 1) % sides
            if grp[j] == grp[k]:
                pc.f([top_ring[j], top_ring[k], ra if grp[j] else rb])
            elif grp[j]:
                pc.f([top_ring[j], top_ring[k], rb, ra])
            else:
                pc.f([top_ring[j], top_ring[k], ra, rb])
    else:
        apex = pc.v(base_origin + a * L + e1 * (bend * L) + (e1 * rng.uniform(-0.12, 0.12) + e2 * rng.uniform(-0.12, 0.12)) * R, tipc)
        for j in range(sides):
            k = (j + 1) % sides
            pc.f([top_ring[j], top_ring[k], apex])
    if cap:
        pc.f(ring_verts[0][::-1])


def mound(pc, centre, R, height, rng, tongues=5, seed=0, hue=0.6):
    """A skirt of fused glass round a root: a low lava-like cone of concentric rings, tongues of it flowing out
    over the salt, the outer lip scorched pale."""
    rings = 6
    n = 28
    grid = []
    dark = hsv(hue + 0.05, 0.9, 0.03)
    glow = hsv(hue, 0.7, 0.10)
    salt = (0.34, 0.37, 0.42, 0.0)
    tongue_ang = [rng.uniform(0, TAU) for _ in range(tongues)]
    tongue_len = [rng.uniform(0.3, 0.9) for _ in range(tongues)]
    for ri in range(rings + 1):
        u = ri / rings
        row = []
        for j in range(n):
            th = TAU * j / n
            s = 1.0
            for ta, tl in zip(tongue_ang, tongue_len):
                d = abs(((th - ta + math.pi) % TAU) - math.pi)
                s += tl * math.exp(-(d / 0.28) ** 2) * u * u
            rr = R * u * s * (1 + 0.12 * noise.noise(Vector((math.cos(th) * 1.7 + seed, math.sin(th) * 1.7, u * 2))))
            h = height * (1 - u ** 1.7) * (1 + 0.25 * noise.noise(Vector((math.cos(th) * 2.2, math.sin(th) * 2.2 + seed, u * 3))))
            z = centre.z + h + 0.18 * (u > 0.85) * noise.noise(Vector((th * 3, u * 4, seed))) - 0.1 * u
            c = dark if u < 0.8 else tuple(lerp(dark[i], salt[i], smooth(0.8, 1.0, u)) for i in range(3))
            if (ri + j) % 5 == 0 and u > 0.2:
                c = glow
            row.append(pc.v(Vector((centre.x + math.cos(th) * rr, centre.y + math.sin(th) * rr, z)), (c[0], c[1], c[2], 0.0)))
        grid.append(row)
    for ri in range(rings):
        for j in range(n):
            k = (j + 1) % n
            pc.f([grid[ri][j], grid[ri][k], grid[ri + 1][k], grid[ri + 1][j]])
    return grid


def cluster(name, seed, hue, mains, n_sat, n_chip, R_mound, lean_dir=Vector((1, 0, 0))):
    """mains: list of (length, radius, lean degrees, azimuth degrees, options)."""
    rng = random.Random(seed)
    pc = Piece(name)
    mound(pc, Vector((0, 0, 0)), R_mound, 0.9, rng, tongues=5, seed=seed, hue=hue)
    for (L, R, lean, az, opt) in mains:
        a = Vector((math.sin(math.radians(lean)) * math.cos(math.radians(az)), math.sin(math.radians(lean)) * math.sin(math.radians(az)), math.cos(math.radians(lean))))
        crystal(pc, Vector((0, 0, 0.1)), a, L, R, rng, hue + rng.uniform(-0.02, 0.02), sink=0.9, **opt)
    L0, R0 = mains[0][0], mains[0][1]
    L1, R1, lean1, az1, _o = mains[0]
    a1 = Vector((math.sin(math.radians(lean1)) * math.cos(math.radians(az1)), math.sin(math.radians(lean1)) * math.sin(math.radians(az1)), math.cos(math.radians(lean1))))
    e1m, e2m = basis_for(a1)
    for i in range(3 if L0 > 8 else 0):
        t = rng.uniform(0.2, 0.55)
        ph = rng.uniform(0, TAU)
        out_d = e1m * math.cos(ph) + e2m * math.sin(ph)
        pos = a1 * (L0 * t) + out_d * R0 * 0.8
        ax = (out_d * 0.9 + a1 * 0.7).normalized()
        crystal(pc, pos, ax, L0 * rng.uniform(0.14, 0.26), R0 * rng.uniform(0.2, 0.32), rng, hue + rng.uniform(-0.03, 0.03), steps=0, sink=R0 * 0.5, cap=False)
    for i in range(n_sat):
        az = TAU * (i + rng.uniform(-0.3, 0.3)) / n_sat
        rad = R0 * rng.uniform(0.9, 1.9)
        lean = rng.uniform(14, 46)
        a = Vector((math.sin(math.radians(lean)) * math.cos(az), math.sin(math.radians(lean)) * math.sin(az), math.cos(math.radians(lean))))
        Ls = L0 * rng.uniform(0.16, 0.42)
        crystal(pc, Vector((math.cos(az) * rad, math.sin(az) * rad, 0.1)), a, Ls, R0 * rng.uniform(0.26, 0.5), rng, hue + rng.uniform(-0.04, 0.03),
                wedge=rng.random() < 0.3, broken=rng.random() < 0.15, sink=0.5, steps=0)
    for i in range(n_chip):
        az = rng.uniform(0, TAU)
        rad = R0 * rng.uniform(1.6, 3.2)
        lean = rng.uniform(25, 70)
        a = Vector((math.sin(math.radians(lean)) * math.cos(az + 0.4), math.sin(math.radians(lean)) * math.sin(az + 0.4), math.cos(math.radians(lean))))
        crystal(pc, Vector((math.cos(az) * rad, math.sin(az) * rad, 0.05)), a, rng.uniform(0.5, 1.6), R0 * rng.uniform(0.07, 0.16), rng, hue, sides=5, sink=0.2, steps=0)
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
    out.append(cluster("shard_great_a", 11, 0.60, [(23.0, 2.7, 11, 0, {"steps": 3, "bend": 0.04, "wedge": True}), (15.0, 1.9, 28, 150, {"steps": 2, "wedge": True}),
                                                   (11.0, 1.5, 34, 255, {"steps": 1, "broken": True}), (7.0, 1.1, 40, 60, {"steps": 1})], 6, 10, 2.6))
    out.append(column_colonly("shard_great_a-colonly", 23.0, 2.7, 11))
    out.append(cluster("shard_great_b", 23, 0.66,
                       [(17.0, 2.2, 9, 20, {"steps": 3, "bend": -0.04}), (13.0, 1.7, 30, 200, {"wedge": True, "steps": 2, "bend": 0.05}),
                                  (8.5, 1.2, 38, 300, {"steps": 1})], 5, 9, 2.4))
    out.append(column_colonly("shard_great_b-colonly", 17.0, 2.2, 9, 20))
    out.append(cluster("shard_great_c", 37, 0.55, [(13.5, 2.1, 6, 0, {"broken": True, "steps": 3}), (10.0, 1.4, 38, 160, {"wedge": True, "steps": 2}),
                                                  (8.0, 1.2, 34, 275, {"steps": 1}), (5.0, 0.9, 44, 60, {"steps": 1})], 6, 9, 2.6))
    out.append(column_colonly("shard_great_c-colonly", 13.5, 2.1, 6))
    # a ray shard: lies low, pointing along +X, its tongue of glass dragged behind
    for nm, seed, L, R, lean in (("shard_ray_a", 51, 9.5, 1.5, 66), ("shard_ray_b", 64, 6.5, 1.1, 72)):
        out.append(cluster(nm, seed, 0.58, [(L, R, lean, 0, {"steps": 1, "bend": 0.03})], 2, 3, 2.2))
        out.append(column_colonly(nm + "-colonly", L, R, lean))
    out.append(cluster("shard_crown_a", 71, 0.63, [(4.2, 0.7, 10, 0, {"steps": 1}), (3.1, 0.55, 28, 140, {"steps": 0}), (2.4, 0.45, 24, 250, {"wedge": True, "steps": 0})], 3, 4, 1.1))
    out.append(cluster("shard_crown_b", 83, 0.5, [(3.2, 0.6, 18, 30, {"steps": 1, "wedge": True}), (2.2, 0.45, 36, 210, {"steps": 0})], 3, 5, 0.9))
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
    return pc.finish()


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


def heart_colours(t):
    deep = hsv(0.58, 0.8, 0.12)
    white = (1.0, 1.0, 1.0)
    return (lerp(deep[0], white[0], t), lerp(deep[1], white[1], t), lerp(deep[2], white[2], t), t)


def build_heart():
    rng = random.Random(7)
    out = []
    pc = Piece("heart_core")
    # the faceted body: an icosphere pushed about so no two facets agree
    bm = pc.bm
    ico = bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1.05)
    for v in ico["verts"]:
        v.co *= 1.0 + 0.16 * noise.noise(v.co * 2.3 + Vector((3, 1, 2)))
        pc.col[v] = heart_colours(0.45)
    longs = fib_dirs(13, rng)
    for i, d in enumerate(longs):
        L = rng.uniform(2.6, 3.7) * (1.15 if i in (0, 6) else 1.0)
        crystal(pc, d * 0.7, d, L - 0.7, rng.uniform(0.34, 0.5), rng, 0.55, sides=6, wedge=(i % 4 == 0), steps=1, sink=0.3, cap=False)
    for i, d in enumerate(fib_dirs(14, random.Random(8))):
        d2 = (d + longs[i % len(longs)] * 0.6).normalized()
        crystal(pc, d2 * 0.75, d2, rng.uniform(1.1, 1.9), rng.uniform(0.16, 0.26), rng, 0.6, sides=5, steps=0, sink=0.3, cap=False)
    # recolour: everything on the heart is lit from within: rgb rises with alpha
    for v, c in list(pc.col.items()):
        pc.col[v] = heart_colours(min(1.0, c[3] * 0.9 + 0.1))
    out.append(pc.finish(recalc=False))
    bm2 = None
    # the bands: faceted hexagonal-section rings, each broken in two places, beads at the breaks
    for nm, R, tilt, spin, seed in (("heart_ring_a", 3.6, 25, 0, 1), ("heart_ring_b", 4.3, -40, 70, 2), ("heart_ring_c", 5.0, 35, 140, 3)):
        r = random.Random(seed)
        pr = Piece(nm)
        segs = 56
        breaks = [r.uniform(0, TAU), r.uniform(0, TAU)]
        gap = 0.34

        def inside(th):
            for b in breaks:
                if abs(((th - b + math.pi) % TAU) - math.pi) < gap:
                    return False
            return True
        prev = None
        sec = []
        for s in range(segs + 1):
            th = TAU * s / segs
            if not inside(th):
                prev = None
                continue
            w = 0.09 + 0.05 * (0.5 + 0.5 * math.sin(th * 3 + seed))
            ring = []
            for q in range(6):
                qa = TAU * q / 6 + 0.5
                rr = R + math.cos(qa) * w * 1.5
                zz = math.sin(qa) * w
                c = heart_colours(0.35 + 0.4 * (0.5 + 0.5 * math.cos(qa)))
                ring.append(pr.v(Vector((math.cos(th) * rr, math.sin(th) * rr, zz)), c))
            if prev is not None:
                for q in range(6):
                    k = (q + 1) % 6
                    pr.f([prev[q], prev[k], ring[k], ring[q]])
            prev = ring
        # beads (small octahedra) every 40 degrees and a spike at each break
        for s in range(0, 9):
            th = TAU * s / 9
            if inside(th):
                crystal(pr, Vector((math.cos(th) * R, math.sin(th) * R, 0)), Vector((0, 0, 1 if s % 2 else -1)), 0.5, 0.09, r, 0.55, sides=4, steps=0, cap=True)
        for b in breaks:
            for sgn in (-1, 1):
                th = b + sgn * gap
                tdir = Vector((-math.sin(th), math.cos(th), 0)) * (-sgn)
                crystal(pr, Vector((math.cos(th) * R, math.sin(th) * R, 0)), (tdir + Vector((0, 0, 0.0))).normalized(), 0.9, 0.12, r, 0.55, sides=5, steps=0, cap=True)
        ob = pr.finish(recalc=False)
        ob.rotation_euler = (math.radians(tilt), math.radians(spin * 0.2), math.radians(spin))
        out.append(ob)
    # the fragments: snapped crystal, a thin rhomb flake, a twisted shard, a chunk
    for i, nm in enumerate(("frag_a", "frag_b", "frag_c", "frag_d")):
        r = random.Random(100 + i)
        pf = Piece(nm)
        if i == 0:
            crystal(pf, Vector((0, 0, -0.5)), Vector((0.1, 0.0, 1)), 1.1, 0.27, r, 0.58, broken=True, steps=1, sink=0.0)
        elif i == 1:
            # a flake: two shallow pyramids on a hexagon
            ring = []
            for q in range(6):
                th = TAU * q / 6 + 0.3
                rr = 0.62 * (1 + r.uniform(-0.25, 0.2))
                ring.append(pf.v(Vector((math.cos(th) * rr, math.sin(th) * rr * 0.7, 0.0)), heart_colours(0.3)))
            top = pf.v(Vector((0.05, 0.0, 0.14)), heart_colours(0.9))
            bot = pf.v(Vector((-0.05, 0.0, -0.12)), heart_colours(0.9))
            for q in range(6):
                k = (q + 1) % 6
                pf.f([ring[q], ring[k], top])
                pf.f([ring[k], ring[q], bot])
        elif i == 2:
            crystal(pf, Vector((0, 0, -0.45)), Vector((0.0, 0.2, 1)), 0.95, 0.19, r, 0.6, wedge=True, steps=0, sink=0.0, bend=0.15)
            crystal(pf, Vector((0.08, 0, -0.2)), Vector((0.7, 0.0, 0.7)), 0.55, 0.1, r, 0.6, steps=0, sink=0.0)
        else:
            crystal(pf, Vector((0, 0, -0.35)), Vector((0.2, 0.1, 1)), 0.7, 0.3, r, 0.56, broken=True, sink=0.0, steps=0)
            crystal(pf, Vector((0, 0, -0.35)), Vector((-0.6, 0.3, 0.7)), 0.55, 0.22, r, 0.6, wedge=True, sink=0.0, steps=0)
        for v, c in list(pf.col.items()):
            pf.col[v] = heart_colours(min(1.0, 0.25 + c[3] * 0.75))
        out.append(pf.finish())
    return out


# ============================================================================================================
# STEPS
# ============================================================================================================
def glass_step(name, seed, R, T, hang, hue=0.6, n_edge=3, rim_crystals=True):
    """A slab of fused glass: an irregular polygon top (domed a little, with a ridge of ripples), chamfered lip,
    a thick lower edge that runs down into a crystal point hanging beneath, and edge crystals thrown outward."""
    rng = random.Random(seed)
    pc = Piece(name)
    n = 9
    dark = hsv(hue + 0.05, 0.9, 0.04)
    mid = hsv(hue, 0.75, 0.11)
    ang = [TAU * j / n + rng.uniform(-0.1, 0.1) for j in range(n)]
    rad = [1.0 + rng.uniform(-0.14, 0.12) for _ in range(n)]
    rings = 3
    grid = []
    for ri in range(rings + 1):
        u = ri / rings
        row = []
        for j in range(n):
            rr = R * rad[j] * u * (0.94 if ri == rings else 1.0)
            x = math.cos(ang[j]) * rr
            y = math.sin(ang[j]) * rr
            z = 0.06 * (1 - u * u) + 0.03 * math.sin(u * 14 + seed) + 0.025 * math.sin(ang[j] * 3 + seed) * u + (-0.09 if ri == rings else 0.0)
            c = mixc(mid, dark, smooth(0.2, 1.0, u), 0.15 * (1 - u))
            row.append(pc.v(Vector((x, y, z)), c))
        grid.append(row)
    lip = []
    for j in range(n):
        x0, y0, _ = grid[-1][j].co
        lip.append(pc.v(Vector((x0 * 0.9, y0 * 0.9, -T * rng.uniform(0.85, 1.1))), (*dark, 0.0)))
    under = []
    for j in range(n):
        x0, y0, _ = grid[-1][j].co
        under.append(pc.v(Vector((x0 * 0.5, y0 * 0.5, -T * 1.5 + rng.uniform(-0.1, 0.05))), (*dark, 0.0)))
    for ri in range(rings):
        for j in range(n):
            k = (j + 1) % n
            if ri == 0:
                pc.f([grid[0][0], grid[1][j], grid[1][k]] if j else [grid[0][0], grid[1][0], grid[1][1]])
            else:
                pc.f([grid[ri][j], grid[ri + 1][j], grid[ri + 1][k], grid[ri][k]])
    for j in range(n):
        k = (j + 1) % n
        pc.f([grid[-1][j], lip[j], lip[k], grid[-1][k]])
        pc.f([lip[j], under[j], under[k], lip[k]])
    pc.f(under[::-1])
    # the hanging point and two lesser ones
    crystal(pc, Vector((0, 0, -T * 1.4)), Vector((0.05, 0.02, -1)), hang, R * 0.36, rng, hue, steps=1, sink=0.0, cap=False)
    for i in range(2):
        az = rng.uniform(0, TAU)
        crystal(pc, Vector((math.cos(az) * R * 0.45, math.sin(az) * R * 0.45, -T * 1.3)), Vector((math.cos(az) * 0.35, math.sin(az) * 0.35, -1)), hang * rng.uniform(0.3, 0.5), R * 0.15, rng, hue, sides=5, steps=0, sink=0.0, cap=False)
    if rim_crystals:
        for i in range(n_edge):
            th = TAU * (i + rng.uniform(0.1, 0.6)) / n_edge + 0.4
            rr = R * 0.97
            a = Vector((math.cos(th) * 0.95, math.sin(th) * 0.95, 0.38)).normalized()
            crystal(pc, Vector((math.cos(th) * rr, math.sin(th) * rr, -0.1)), a, rng.uniform(0.5, 0.9) * R * 0.7, R * 0.075, rng, hue, sides=5, steps=0, sink=0.0)
    ob = pc.finish()
    return ob


def build_steps():
    out = []
    for i, (R, T, hang, seed) in enumerate(((1.25, 0.5, 2.2, 3), (1.15, 0.45, 1.8, 8), (1.3, 0.55, 2.6, 15))):
        nm = "step_" + "abc"[i]
        out.append(glass_step(nm, seed, R, T, hang))
        out.append(colonly_hull(nm + "-colonly", lambda R=R, T=T: [Vector((math.cos(TAU * q / 8 + 0.2) * R * 0.92, math.sin(TAU * q / 8 + 0.2) * R * 0.92, z)) for q in range(8) for z in (0.0, -T)]))
    out.append(glass_step("platform", 21, 2.55, 0.7, 3.8, n_edge=6))
    out.append(colonly_hull("platform-colonly", lambda: [Vector((math.cos(TAU * q / 10 + 0.1) * 2.4, math.sin(TAU * q / 10 + 0.1) * 2.4, z)) for q in range(10) for z in (0.0, -0.7)]))
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
    att = nt.nodes.new("ShaderNodeAttribute")
    att.attribute_name = "Col"
    mul = nt.nodes.new("ShaderNodeMath")
    mul.operation = 'POWER'
    mul.inputs[1].default_value = 2.0
    em = nt.nodes.new("ShaderNodeMix")
    em.data_type = 'RGBA'
    em.inputs[6].default_value = (0.05, 0.2, 0.45, 1)
    em.inputs[7].default_value = (0.5, 0.85, 1.1, 1)
    nt.links.new(att.outputs["Alpha"], mul.inputs[0])
    nt.links.new(mul.outputs[0], em.inputs[0])
    nt.links.new(att.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(em.outputs[2], bsdf.inputs["Emission Color"])
    bsdf.inputs["Emission Strength"].default_value = 0.35
    bsdf.inputs["Roughness"].default_value = 0.22
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
              export_materials='EXPORT', export_image_format='NONE', export_normals=True, export_texcoords=False)
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
        "heart": (build_heart, "star_crater_heart.glb", [("heart", None, 0.0, 16), ("frags", ("frag_a", "frag_b", "frag_c", "frag_d"), 0.0, 5)]),
        "steps": (build_steps, "star_crater_steps.glb", [("step_a", ("step_a",), -1.4, 9), ("platform", ("platform",), -2.0, 17)]),
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
                        o.location.x = (i - 1.5) * 1.3
                else:
                    for o in shown:
                        o.location = Vector((0, 0, 0))
            render_sheet("%s_%s" % (key, label), shown, h, dist)
            for o in objs:
                o.hide_render = False
                if "-colonly" in o.name:
                    pass


main()
