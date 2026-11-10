"""THE WATCHERS: two great lantern pillars either side of the Threshold's gate, facing the village. Each is a carved stone
column on a stepped plinth: coursed drums with chamfered joints (one cracked and shifted), a spiral road of climbing
pilgrims modelled in relief up the shaft, a deep-cut capital ringed with lit Order glyphs, a forged iron lantern-cage
burning violet on top, chains hung from the capital to rings in the plinth with pilgrims' cloths tied to them, votive
candles on the steps. Modelled by script (no scans, no downloads).

  tools/blender/run.sh wonder_watchers.py -- [--preview DIR] [--tex 2048] [--reuse]

Exports (art/models/wonders/):
  watchers_west.glb / watchers_east.glb   near mesh: Pillar_fig (the stone: shaft, relief, capital; baked UVs), Pillar_base (the
                                          plinth's laid blocks, vertex colour), Pillar_iron (lantern, chains, rings), Pillar_orb
                                          (emissive), Pillar_glow (the glyphs, emissive), Pillar_cloth, Pillar_cand (wax),
                                          Pillar_flame (emissive), Pillar_rubble, Pillar_*-convcolonly hulls
  watchers_west_far.glb / ..._east_far    ~1.3k triangle far mesh (stone, base, iron, orb)
  watchers_pillar_{albedo,normal,orm}.png baked maps (shared: the east pillar is the mirrored mesh)

Frame: Blender Z up -> Godot Y up, Blender +Y -> Godot -Z. 1 BU = 1 m. Origin = the centre of the plinth's bottom face.
"""
import bpy
import bmesh
import math
import os
import sys
import random
import numpy as np
from mathutils import Vector, Matrix, noise

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art", "models", "wonders")
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(name, default=""):
    return args[args.index(name) + 1] if name in args else default


PREVIEW = arg("--preview")
NOBAKE = "--no-bake" in args
HI_STEP = 0.07
TEX = int(arg("--tex", "2048"))
FS = 1.0                          # the final scale (metres in Godot)
WATER_Z = 1.7                     # the pool's surface above the plinth's foot (-15.5 vs -17.2)


def lerp(a, b, t):
    return a + (b - a) * t


def sstep(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a + 1e-9)))
    return t * t * (3 - 2 * t)


def fbm(p, octaves=3, lac=2.0, gain=0.5):
    a, f, s, n = 1.0, 1.0, 0.0, 0.0
    for _ in range(octaves):
        s += a * noise.noise(p * f)
        n += a
        a *= gain
        f *= lac
    return s / n


def prof(tab, x):
    """Piecewise smooth interpolation of rows (x, a, b, ...) at x -> tuple of the other columns."""
    if x <= tab[0][0]:
        return tab[0][1:]
    for i in range(len(tab) - 1):
        if x <= tab[i + 1][0]:
            t = sstep(tab[i][0], tab[i + 1][0], x)
            return tuple(lerp(a, b, t) for a, b in zip(tab[i][1:], tab[i + 1][1:]))
    return tab[-1][1:]


def catmull(pts, t):
    """Catmull-Rom through pts at t in [0, 1]."""
    n = len(pts) - 1
    x = max(0.0, min(0.9999999, t)) * n
    i = int(x)
    u = x - i
    p0 = pts[max(i - 1, 0)]
    p1 = pts[i]
    p2 = pts[i + 1]
    p3 = pts[min(i + 2, n)]
    return 0.5 * ((2 * p1) + (-p0 + p2) * u + (2 * p0 - 5 * p1 + 4 * p2 - p3) * u * u + (-p0 + 3 * p1 - 3 * p2 + p3) * u ** 3)


# --- bmesh primitives -----------------------------------------------------------------------------
class Parts:
    def __init__(self):
        self.bm = {}

    def of(self, key):
        if key not in self.bm:
            self.bm[key] = bmesh.new()
        return self.bm[key]


def loft(bm, rings, cap0=True, cap1=True):
    """rings: lists of Vectors (equal count), consecutive rings joined by quads (outward for CCW rings going up)."""
    vr = [[bm.verts.new(p) for p in ring] for ring in rings]
    n = len(vr[0])
    for i in range(len(vr) - 1):
        for j in range(n):
            bm.faces.new((vr[i][j], vr[i][(j + 1) % n], vr[i + 1][(j + 1) % n], vr[i + 1][j]))
    if cap0:
        bm.faces.new(vr[0][::-1])
    if cap1:
        bm.faces.new(vr[-1])
    # UV seams: down the first column, and round each capped end
    for i in range(len(vr) - 1):
        e = bm.edges.get((vr[i][0], vr[i + 1][0]))
        if e:
            e.seam = True
    for ring, capped in ((vr[0], cap0), (vr[-1], cap1)):
        if capped:
            for j in range(n):
                e = bm.edges.get((ring[j], ring[(j + 1) % n]))
                if e:
                    e.seam = True
    return vr


def frame_at(pts, k, prev_u=None):
    """A rotation-minimising frame (u, v, T) with u x v = T along a polyline of centres."""
    a = pts[max(k - 1, 0)]
    b = pts[min(k + 1, len(pts) - 1)]
    T = (b - a).normalized()
    if prev_u is None:
        ref = Vector((0, 1, 0)) if abs(T.y) < 0.9 else Vector((1, 0, 0))
        u = (ref - T * ref.dot(T)).normalized()
    else:
        u = (prev_u - T * prev_u.dot(T)).normalized()
    v = T.cross(u)
    return u, v, T


def tube(bm, centres, radii, seg=8, cap0=True, cap1=True, squash=None, twist=0.0, ring_fn=None):
    """A lofted tube along a list of centres with a radius per centre. ring_fn(k, phi, c, u, v, r) -> point."""
    rings = []
    u = None
    for k, c in enumerate(centres):
        u, v, T = frame_at(centres, k, u)
        r = radii[k]
        ring = []
        for j in range(seg):
            phi = math.tau * j / seg + twist * k
            if ring_fn:
                ring.append(ring_fn(k, phi, c, u, v, r))
            else:
                sq = squash[k] if squash else 1.0
                ring.append(c + u * (math.cos(phi) * r) + v * (math.sin(phi) * r * sq))
        rings.append(ring)
    return loft(bm, rings, cap0, cap1)


def seg_tube(bm, a, b, r0, r1=None, seg=8, cap0=True, cap1=True):
    a, b = Vector(a), Vector(b)
    tube(bm, [a, (a + b) * 0.5, b], [r0, (r0 + (r0 if r1 is None else r1)) * 0.5, r0 if r1 is None else r1], seg, cap0, cap1)


def sphere(bm, c, r, seg=8, rings=5, scale=(1, 1, 1)):
    M = Matrix.Translation(Vector(c)) @ Matrix.Diagonal((scale[0], scale[1], scale[2], 1.0))
    res = bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=r, matrix=M)
    cc = Vector(c)
    for e in {ed for v in res["verts"] for ed in v.link_edges}:
        a, b = e.verts
        if abs(a.co.y - cc.y) < 1e-5 and abs(b.co.y - cc.y) < 1e-5 and a.co.x >= cc.x - 1e-5 and b.co.x >= cc.x - 1e-5:
            e.seam = True


def box(bm, c, size, yaw=0.0, pitch=0.0, roll=0.0):
    rot = Matrix.Rotation(yaw, 4, 'Z') @ Matrix.Rotation(pitch, 4, 'X') @ Matrix.Rotation(roll, 4, 'Y')
    M = Matrix.Translation(Vector(c)) @ rot @ Matrix.Diagonal((size[0], size[1], size[2], 1.0))
    res = bmesh.ops.create_cube(bm, size=1.0, matrix=M)
    for v in res["verts"]:
        for e in v.link_edges:
            e.seam = True


def torus(bm, c, R, r, seg=24, tseg=6, axis='Z'):
    pts = []
    for k in range(seg + 1):
        a = math.tau * k / seg
        pts.append(Vector(c) + (Vector((math.cos(a) * R, math.sin(a) * R, 0)) if axis == 'Z' else Vector((math.cos(a) * R, 0, math.sin(a) * R))))
    # a closed ring: loft the circle sections by hand
    rings = []
    for k in range(seg):
        a = math.tau * k / seg
        ctr = Vector(c) + (Vector((math.cos(a) * R, math.sin(a) * R, 0)) if axis == 'Z' else Vector((math.cos(a) * R, 0, math.sin(a) * R)))
        radial = (ctr - Vector(c)).normalized()
        up = Vector((0, 0, 1)) if axis == 'Z' else Vector((0, 1, 0))
        ring = []
        for j in range(tseg):
            p = math.tau * j / tseg
            ring.append(ctr + radial * (math.cos(p) * r) + up * (math.sin(p) * r))
        rings.append(ring)
    vr = [[bm.verts.new(p) for p in ring] for ring in rings]
    for i in range(seg):
        i2 = (i + 1) % seg
        for j in range(tseg):
            j2 = (j + 1) % tseg
            bm.faces.new((vr[i][j], vr[i][j2], vr[i2][j2], vr[i2][j]))


def translate(bm, v):
    bmesh.ops.translate(bm, vec=Vector(v), verts=bm.verts)


# --- cloth ----------------------------------------------------------------------------------------
def fd(phi, z, amp, tw, seeds, seed=0.0):
    """Drapery as a radial offset in metres: deep V valleys, rounded ridges, bundles of deep and shallow folds."""
    warp = 0.8 * fbm(Vector((math.cos(phi) * 1.1 + seed, math.sin(phi) * 1.1, z * 0.18)), 2)
    f = 0.0
    for n, ph, w in seeds:
        s = math.sin(n * phi + ph + tw * z + warp * 1.0)
        f += w * (0.5 - abs(s) ** 0.8)
    mod = 0.5 + 1.0 * (0.5 + 0.5 * noise.noise(Vector((math.cos(phi) * 0.9 + seed * 1.7, math.sin(phi) * 0.9, z * 0.1 + 3.0))))
    return amp * f * mod


def gauss(x, w):
    return math.exp(-((x / w) ** 2))


def ring3(bm, c, axis, R, r, seg=14, tseg=5):
    """A torus about an arbitrary axis."""
    axis = Vector(axis).normalized()
    u = axis.cross(Vector((0, 0, 1)) if abs(axis.z) < 0.9 else Vector((1, 0, 0))).normalized()
    v = axis.cross(u)
    rings = []
    for k in range(seg):
        a = math.tau * k / seg
        ctr = Vector(c) + (u * math.cos(a) + v * math.sin(a)) * R
        rad = (u * math.cos(a) + v * math.sin(a))
        ring = []
        for j in range(tseg):
            p = math.tau * j / tseg
            ring.append(ctr + rad * (math.cos(p) * r) + axis * (math.sin(p) * r))
        rings.append(ring)
    vr = [[bm.verts.new(p) for p in ring] for ring in rings]
    for i in range(seg):
        i2 = (i + 1) % seg
        for j in range(tseg):
            bm.faces.new((vr[i][j], vr[i][(j + 1) % tseg], vr[i2][(j + 1) % tseg], vr[i2][j]))


def append_bm(dst, src):
    mp = {}
    for v in src.verts:
        mp[v] = dst.verts.new(v.co)
    for f in src.faces:
        dst.faces.new([mp[v] for v in f.verts])
    for e in src.edges:
        if e.seam:
            de = dst.edges.get((mp[e.verts[0]], mp[e.verts[1]]))
            if de:
                de.seam = True


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def box_uv_and_paint(bm, seed, tile=4.0, smooth=False, paint=True):
    """Metric box UVs (a tile is `tile` metres) and the baked albedo as vertex colours."""
    bm.normal_update()
    uv = bm.loops.layers.uv.new("UVMap")
    col = bm.loops.layers.color.new("Col")
    co = np.array([v.co[:] for v in bm.verts])
    nr = np.array([v.normal[:] for v in bm.verts])
    cc = stone_color(co, nr, np.ones(len(co)), seed=seed) if paint else np.full((len(co), 3), 0.85)
    for f in bm.faces:
        n = f.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        for l in f.loops:
            c = l.vert.co
            l[uv].uv = ((c.y, c.z) if ax == 0 else (c.x, c.z) if ax == 1 else (c.x, c.y))
            l[uv].uv = (l[uv].uv[0] / tile, l[uv].uv[1] / tile)
            k = cc[l.vert.index]
            l[col] = (k[0], k[1], k[2], 1.0)


# ============================================================================================
# DRIVER: scene, high-res detail, bake, collision, far mesh, export
# ============================================================================================
import numpy as np

def vnoise(P, f, seed):
    q = P * f + seed * 17.123
    fl = np.floor(q)
    u = q - fl
    i = fl.astype(np.int64)
    u = u * u * (3.0 - 2.0 * u)

    def h(dx, dy, dz):
        n = ((i[:, 0] + dx) * 73856093) ^ ((i[:, 1] + dy) * 19349663) ^ ((i[:, 2] + dz) * 83492791) ^ (seed * 2654435)
        n &= 0x7fffffff
        n = ((n ^ (n >> 13)) * 1274126177) & 0x7fffffff
        n ^= n >> 16
        return (n & 0xffff) / 65535.0
    ux, uy, uz = u[:, 0], u[:, 1], u[:, 2]
    c00 = h(0, 0, 0) * (1 - ux) + h(1, 0, 0) * ux
    c10 = h(0, 1, 0) * (1 - ux) + h(1, 1, 0) * ux
    c01 = h(0, 0, 1) * (1 - ux) + h(1, 0, 1) * ux
    c11 = h(0, 1, 1) * (1 - ux) + h(1, 1, 1) * ux
    return (c00 * (1 - uy) + c10 * uy) * (1 - uz) + (c01 * (1 - uy) + c11 * uy) * uz


def fbm_np(P, f, octaves, seed):
    s, a, n = 0.0, 1.0, 0.0
    for o in range(octaves):
        s = s + a * vnoise(P, f * (2.0 ** o), seed + o)
        n += a
        a *= 0.5
    return s / n


def sstep_np(a, b, x):
    t = np.clip((x - a) / (b - a + 1e-9), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def stone_detail(P, kind, seed=1):
    """Chisel marks, hairline cracks and, on the masonry, course joints and chipped arrises: metres along the normal."""
    chisel = (fbm_np(P, 2.2, 3, seed) - 0.5) * 0.06 + (fbm_np(P, 9.0, 3, seed + 3) - 0.5) * 0.03 + (vnoise(P, 30.0, seed + 5) - 0.5) * 0.012
    c = np.abs(vnoise(P, 0.42, seed + 7) - 0.5)
    crack = -0.1 * np.clip(1 - c / 0.014, 0, 1) ** 1.5
    c2 = np.abs(vnoise(P, 1.3, seed + 9) - 0.5)
    crack += -0.04 * np.clip(1 - c2 / 0.02, 0, 1) ** 1.5
    d = chisel + crack
    if kind == "tier":
        course = 0.9
        row = np.floor(P[:, 2] / course)
        along = P[:, 0] + P[:, 1] + row * 1.37
        bw = 2.3
        fr = np.abs(((along / bw) % 1.0) - 0.5) * 2.0                  # 0 at the block's middle, 1 at a joint
        fz = np.abs(((P[:, 2] / course) % 1.0) - 0.5) * 2.0
        joint = np.maximum(sstep_np(0.965, 1.0, fr), sstep_np(0.95, 1.0, fz))
        d = d - 0.055 * joint
        # chipped edges: noise that bites the lower corners and the blocks' arrises
        chip = sstep_np(0.62, 0.8, fbm_np(P, 1.4, 3, seed + 11)) * (joint * 0.8 + 0.2)
        d = d - 0.12 * chip * sstep_np(0.0, 0.3, 1.0 - fz * 0.0)
    return crack, d, c


def stone_color(P, N, crack_mask, z_foot_damp=True, seed=1, curv=None):
    """Albedo: warm and cool strata of weathered stone, drum-to-drum tone, grime and moss creeping up from the base,
    lichen on the ledges, pale wear on the arrises, rain streaks under the capital, the waterline and its crust."""
    z = P[:, 2]
    warm = np.array([0.60, 0.52, 0.42])
    cool = np.array([0.40, 0.46, 0.55])
    hue = fbm_np(P, 0.14, 3, seed + 60)
    hue = sstep_np(0.3, 0.7, hue)
    base = 0.37 + 0.12 * fbm_np(P, 0.33, 4, seed + 20) + 0.06 * (fbm_np(P, 1.6, 3, seed + 21) - 0.5)
    col = (warm[None, :] * (1 - hue)[:, None] + cool[None, :] * hue[:, None]) * base[:, None] / 0.7
    dh = (SH1 - SH0) / NDRUM
    di = np.floor((z - SH0) / dh)
    tone = 0.88 + 0.2 * (((di * 7919) % 13) / 13.0)
    col *= np.where((z > SH0) & (z < SH1), tone, 1.0)[:, None]
    col *= (1.0 - 0.5 * np.clip(1 - crack_mask / 0.012, 0, 1))[:, None]
    nz = np.clip(N[:, 2], 0, 1)
    # grime and moss creeping up from the foot, with a ragged edge
    edge = 7.5 + 5.0 * (fbm_np(P, 0.5, 3, seed + 70) - 0.5)
    grime = 1.0 - sstep_np(1.2, edge, z)
    col *= (1.0 - 0.4 * grime)[:, None] * np.array([0.95, 1.0, 0.92])[None, :]
    moss = sstep_np(0.5, 0.64, fbm_np(P, 1.3, 3, seed + 32) + 0.35 * grime - 0.15) * (0.35 + 0.65 * nz) * (1.0 - sstep_np(2.0, 11.0, z))
    col = col * (1 - 0.75 * moss[:, None]) + 0.75 * moss[:, None] * np.array([0.26, 0.38, 0.13])
    # lichen on the ledges: the up-facing surfaces, in pale grey-green and ochre patches
    up = sstep_np(0.3, 0.75, N[:, 2])
    lich = sstep_np(0.56, 0.66, fbm_np(P, 3.2, 3, seed + 33)) * up
    col = col * (1 - 0.75 * lich[:, None]) + 0.75 * lich[:, None] * np.array([0.66, 0.68, 0.45])
    lich2 = sstep_np(0.64, 0.72, fbm_np(P, 5.0, 3, seed + 35)) * np.clip(0.3 + up, 0, 1)
    col = col * (1 - 0.6 * lich2[:, None]) + 0.6 * lich2[:, None] * np.array([0.72, 0.58, 0.28])
    # pale wear on the arrises
    if curv is not None:
        w = sstep_np(0.004, 0.02, curv) * (0.5 + 0.5 * fbm_np(P, 8.0, 2, seed + 36))
        col = col * (1 - 0.35 * w[:, None]) + 0.35 * w[:, None] * np.array([0.82, 0.78, 0.7])
    # the waterline: damp and dark below it, a pale mineral crust just above
    wl = WATER_Z + 0.25 * (fbm_np(P, 1.2, 3, seed + 40) - 0.5)
    damp = 1.0 - sstep_np(wl - 0.1, wl + 0.1, z)
    col *= (1.0 - 0.45 * damp)[:, None]
    crust = np.exp(-(((z - (wl + 0.35)) / 0.3) ** 2)) * sstep_np(0.4, 0.6, fbm_np(P, 2.0, 3, seed + 41))
    col = col * (1 - 0.55 * crust[:, None]) + 0.55 * crust[:, None] * np.array([0.7, 0.7, 0.76])
    # rain streaks running down from under the capital (and from every ledge)
    q = P * np.array([5.0, 5.0, 0.22])
    st = sstep_np(0.55, 0.75, fbm_np(q, 1.0, 3, seed + 50)) * (1 - nz)
    below = sstep_np(SH1 - 10.0, SH1 + 0.2, z) * (1.0 - sstep_np(SH1 + 0.3, SH1 + 1.0, z))
    col *= (1.0 - (0.18 + 0.4 * below) * st)[:, None]
    col = col * (1 - 0.25 * (st * below)[:, None]) + 0.25 * (st * below)[:, None] * np.array([0.3, 0.36, 0.2])
    return np.clip(col, 0.03, 1.0)


def vertex_ao(P, N, polys, nrays=10, dist=6.0):
    """Ambient occlusion per vertex by ray casting against the mesh itself (BVH): cosine-weighted hemisphere."""
    from mathutils.bvhtree import BVHTree
    bvh = BVHTree.FromPolygons([tuple(v) for v in P.tolist()], polys)
    golden = 2.399963
    dirs = []
    for k in range(nrays):
        r = math.sqrt((k + 0.5) / nrays)
        a = k * golden
        dirs.append((r * math.cos(a), r * math.sin(a), math.sqrt(max(0.0, 1 - r * r))))
    out = np.ones(len(P))
    rnd = random.Random(4)
    for i in range(len(P)):
        n = Vector(N[i])
        t = n.cross(Vector((0, 0, 1)) if abs(n.z) < 0.9 else Vector((1, 0, 0)))
        if t.length < 1e-6:
            continue
        t.normalize()
        b = n.cross(t)
        sp = rnd.random() * 6.283
        cs, sn = math.cos(sp), math.sin(sp)
        o = Vector(P[i]) + n * 0.06
        hit = 0.0
        for lx, ly, lz in dirs:
            x, y = lx * cs - ly * sn, lx * sn + ly * cs
            h = bvh.ray_cast(o, t * x + b * y + n * lz, dist)
            if h[0] is not None:
                hit += 1.0 - 0.55 * h[3] / dist
        out[i] = max(0.0, 1.0 - hit / nrays)
    return out


def mesh_np(me):
    n = len(me.vertices)
    co = np.empty(n * 3, dtype=np.float32)
    me.vertices.foreach_get("co", co)
    nr = np.empty(n * 3, dtype=np.float32)
    me.vertex_normals.foreach_get("vector", nr)
    return co.reshape(-1, 3).astype(np.float64), nr.reshape(-1, 3).astype(np.float64)


def grid_boxes(boxes, step):
    """The masonry boxes as gridded quads (six faces each) for displacement: returns a Mesh."""
    verts, faces, edge = [], [], []
    for c, size in boxes:
        hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
        for axis in range(3):
            for sgn in (-1, 1):
                a1, a2 = [(1, 2), (0, 2), (0, 1)][axis]
                h = (hx, hy, hz)
                n1 = max(2, int(round(2 * h[a1] / step)))
                n2 = max(2, int(round(2 * h[a2] / step)))
                base = len(verts)
                for i in range(n1 + 1):
                    for j in range(n2 + 1):
                        p = [0.0, 0.0, 0.0]
                        p[axis] = sgn * h[axis]
                        p[a1] = -h[a1] + 2 * h[a1] * i / n1
                        p[a2] = -h[a2] + 2 * h[a2] * j / n2
                        verts.append((c[0] + p[0], c[1] + p[1], c[2] + p[2]))
                        edge.append(min(h[a1] - abs(p[a1]), h[a2] - abs(p[a2])))
                for i in range(n1):
                    for j in range(n2):
                        v0 = base + i * (n2 + 1) + j
                        q = (v0, v0 + 1, v0 + n2 + 2, v0 + n2 + 1)
                        faces.append(q if -sgn * (1, -1, 1)[axis] > 0 else q[::-1])
    me = bpy.data.meshes.new("grid")
    me.from_pydata(verts, [], faces)
    return me, np.array(edge)


def detailed(low_me, name, kind, mat_key, seed, boxes=None, extra_me=None, extra=None):
    """The high-poly twin of a low mesh: subdivided, chiselled, cracked, coloured (Col), occluded (AO), glowing (Glow)."""
    ob0 = bpy.data.objects.new("tmp_low", low_me)
    bpy.context.scene.collection.objects.link(ob0)
    md = ob0.modifiers.new("sub", 'SUBSURF')
    md.levels = 2
    md.render_levels = 2
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob0.evaluated_get(dg))
    bpy.data.objects.remove(ob0)
    P, N = mesh_np(me)
    n_t = len(P)
    crack, d, craw = stone_detail(P, "fig", seed)
    glow = np.zeros(n_t)
    if extra is not None:
        ed, glow = extra(P, N)
        d = d + ed
    P2 = P + N * d[:, None]
    me.vertices.foreach_set("co", P2.astype(np.float32).ravel())
    me.update()
    P2, N2 = mesh_np(me)
    ev = np.empty(len(me.edges) * 2, dtype=np.int32)
    me.edges.foreach_get("vertices", ev)
    ev = ev.reshape(-1, 2)
    nb = np.zeros_like(P2)
    cnt = np.zeros(n_t)
    np.add.at(nb, ev[:, 0], P2[ev[:, 1]])
    np.add.at(nb, ev[:, 1], P2[ev[:, 0]])
    np.add.at(cnt, ev[:, 0], 1)
    np.add.at(cnt, ev[:, 1], 1)
    nbm = nb / np.maximum(cnt, 1)[:, None]
    curv = -np.einsum('ij,ij->i', nbm - P2, N2)                # > 0 where the surface is convex (an arris)
    polys = [tuple(p_.vertices) for p_ in me.polygons]
    ao = vertex_ao(P2, N2, polys)
    for _ in range(2):                                         # no specks: average each vertex with its neighbours
        sm = np.zeros(n_t)
        np.add.at(sm, ev[:, 0], ao[ev[:, 1]])
        np.add.at(sm, ev[:, 1], ao[ev[:, 0]])
        ao = 0.5 * ao + 0.5 * sm / np.maximum(cnt, 1)
    col = np.ones((n_t, 4))
    col[:, :3] = stone_color(P2, N2, craw, seed=seed, curv=curv)
    ca = me.color_attributes.new("Col", 'FLOAT_COLOR', 'POINT')
    ca.data.foreach_set("color", col.astype(np.float32).ravel())
    aoc = np.ones((n_t, 4))
    aoc[:, 0] = aoc[:, 1] = aoc[:, 2] = np.clip(ao ** 1.2, 0.28, 1.0)
    a2 = me.color_attributes.new("AO", 'FLOAT_COLOR', 'POINT')
    a2.data.foreach_set("color", aoc.astype(np.float32).ravel())
    gc = np.zeros((n_t, 4))
    gc[:, :3] = glow[:, None] * np.array([0.17, 0.06, 0.4])[None, :]
    gc[:, 3] = 1.0
    a3 = me.color_attributes.new("Glow", 'FLOAT_COLOR', 'POINT')
    a3.data.foreach_set("color", gc.astype(np.float32).ravel())
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    for p_ in me.polygons:
        p_.use_smooth = True
    emit = bpy.data.materials.new(name + "_emit")
    emit.use_nodes = True
    nt = emit.node_tree
    nt.nodes.clear()
    a = nt.nodes.new('ShaderNodeAttribute')
    a.attribute_name = "Col"
    e = nt.nodes.new('ShaderNodeEmission')
    o = nt.nodes.new('ShaderNodeOutputMaterial')
    nt.links.new(a.outputs['Color'], e.inputs['Color'])
    nt.links.new(e.outputs['Emission'], o.inputs['Surface'])
    me.materials.clear()
    me.materials.append(emit)
    return ob


def unwrap(ob, margin=0.003):
    bpy.ops.object.select_all(action='DESELECT')
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.unwrap(method='CONFORMAL', margin=margin)
    bpy.ops.uv.average_islands_scale()
    bpy.ops.uv.pack_islands(margin=margin)
    bpy.ops.object.mode_set(mode='OBJECT')


def write_png(path, rgb):
    """A minimal RGB PNG writer (rows top to bottom)."""
    import zlib
    import struct
    h, w, _ = rgb.shape
    raw = b"".join(b"\x00" + rgb[y].tobytes() for y in range(h))

    def chunk(t, d):
        c = struct.pack(">I", len(d)) + t + d
        return c + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw, 6)) + chunk(b"IEND", b""))


def bake_pair(low, high, tag, size):
    """normal, ao, albedo from `high` onto `low`'s UVs -> PNGs; returns the written paths."""
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.device = 'CPU'
    sc.cycles.use_denoising = False
    bk = sc.render.bake
    bk.use_selected_to_active = True
    bk.cage_extrusion = 0.4
    bk.max_ray_distance = 1.2
    bk.margin = 12
    bk.target = 'IMAGE_TEXTURES'
    paths = {}
    mat = bpy.data.materials.new("bake_" + tag)
    mat.use_nodes = True
    low.data.materials.clear()
    low.data.materials.append(mat)
    nt = mat.node_tree
    img_node = nt.nodes.new('ShaderNodeTexImage')
    hmat = high.data.materials[0]
    himg = hmat.node_tree.nodes.new('ShaderNodeTexImage')
    for kind, btype, samples in (("normal", 'NORMAL', 8), ("ao", 'AO', 48), ("albedo", 'EMIT', 1), ("emit", 'EMIT', 1)):
        img = bpy.data.images.new("%s_%s" % (tag, kind), size, size, alpha=False, float_buffer=False)
        img.generated_color = {"normal": (0.5, 0.5, 1.0, 1.0), "ao": (1, 1, 1, 1), "albedo": (0.3, 0.3, 0.3, 1), "emit": (0, 0, 0, 1)}[kind]
        img.colorspace_settings.name = 'sRGB' if kind in ("albedo", "emit") else 'Non-Color'
        sc.cycles.samples = samples
        bpy.ops.object.select_all(action='DESELECT')
        if kind == "normal":
            img_node.image = img
            nt.nodes.active = img_node
            bk.use_selected_to_active = True
            high.select_set(True)
            low.select_set(True)
            bpy.context.view_layer.objects.active = low
            bpy.ops.object.bake(type='NORMAL', normal_space='TANGENT')
        else:
            # self bake on the high mesh (it carries the low mesh's UVs): the low mesh is out of the scene
            himg.image = img
            hmat.node_tree.nodes.active = himg
            bk.use_selected_to_active = False
            low.hide_render = True
            high.select_set(True)
            bpy.context.view_layer.objects.active = high
            for nd in hmat.node_tree.nodes:
                if nd.bl_idname == 'ShaderNodeAttribute':
                    nd.attribute_name = {"ao": "AO", "emit": "Glow"}.get(kind, "Col")
            bpy.ops.object.bake(type='EMIT')
            low.hide_render = False
        if kind == "ao":
            a = np.empty(size * size * 4, dtype=np.float32)
            img.pixels.foreach_get(a)
            a = a.reshape(-1, 4)
            print("AO mean", float(a[:, 0].mean()))
            orm = np.ones_like(a)
            orm[:, 0] = a[:, 0]
            orm[:, 1] = 0.78 + 0.2 * (1.0 - a[:, 0])
            orm[:, 2] = 0.0
            write_png(os.path.join(OUT, "watchers_%s_orm.png" % tag), (np.clip(orm[:, :3], 0, 1) * 255).astype(np.uint8).reshape(size, size, 3)[::-1])
        path = os.path.join(OUT, "watchers_%s_%s.png" % (tag, kind))
        img.filepath_raw = path
        img.file_format = 'PNG'
        img.save()
        paths[kind] = path
        print("BAKED", path)
    return paths


def make_orm(tag):
    """Pack R = ambient occlusion, G = roughness (a little lower on the lit faces), B = 0 into one PNG."""
    ao = bpy.data.images.load(os.path.join(OUT, "watchers_%s_ao.png" % tag), check_existing=False)
    w, h = ao.size
    a = np.empty(w * h * 4, dtype=np.float32)
    ao.pixels.foreach_get(a)
    a = a.reshape(-1, 4)
    orm = np.ones_like(a)
    orm[:, 0] = a[:, 0]
    orm[:, 1] = 0.78 + 0.2 * (1.0 - a[:, 0])
    orm[:, 2] = 0.0
    img = bpy.data.images.new("orm_" + tag, w, h, alpha=False)
    img.pixels.foreach_set(orm.ravel())
    img.colorspace_settings.name = 'Non-Color'
    img.filepath_raw = os.path.join(OUT, "watchers_%s_orm.png" % tag)
    img.file_format = 'PNG'
    img.save()


def mk_object(bm, name, smooth, mat):
    for f in bm.faces:
        f.smooth = smooth
    bm.normal_update()
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    m = bpy.data.materials.get(mat) or bpy.data.materials.new(mat)
    me.materials.append(m)
    return ob


def tris(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


def rubble(seed, mirror):
    """Fallen pieces in the pool: worn blocks, a snapped hood tip, a broken finger: one tiled-stone mesh."""
    rnd = random.Random(seed)
    bm = bmesh.new()
    spots = [(-4.7, 3.0, 0.7), (4.5, -3.4, 0.6), (-4.3, -4.2, 0.7), (4.8, 4.0, 0.5), (0.4, -4.8, 0.5), (-5.0, 0.2, 0.45), (5.1, -0.6, 0.5), (2.4, 4.9, 0.45), (-2.6, -5.0, 0.45)]
    for (x, y, r) in spots:
        r *= rnd.uniform(0.9, 1.6)
        sub = bmesh.new()
        pts = []
        sx, sy, sz = rnd.uniform(0.8, 1.6), rnd.uniform(0.7, 1.3), rnd.uniform(0.5, 0.9)
        for _ in range(16):
            v = Vector((rnd.choice((-1, 1)) * rnd.uniform(0.75, 1.0) * sx, rnd.choice((-1, 1)) * rnd.uniform(0.75, 1.0) * sy, rnd.choice((-1, 1)) * rnd.uniform(0.7, 1.0) * sz)) * r
            pts.append(v)
        for v in pts:
            sub.verts.new(v)
        bmesh.ops.convex_hull(sub, input=sub.verts)
        rot = Matrix.Rotation(rnd.uniform(0, 3), 4, 'Z') @ Matrix.Rotation(rnd.uniform(-0.4, 0.4), 4, 'X')
        zbase = rnd.uniform(-0.1, 0.3)
        mp = {v: bm.verts.new(rot @ v.co + Vector((x, y, zbase + r * 0.4))) for v in sub.verts}
        for f in sub.faces:
            bm.faces.new([mp[v] for v in f.verts])
        sub.free()
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if mirror:
        for v in bm.verts:
            v.co.x = -v.co.x
        bmesh.ops.reverse_faces(bm, faces=bm.faces)
    box_uv_and_paint(bm, seed)
    return bm


def hull_obj(name, verts):
    bm = bmesh.new()
    for v in verts:
        bm.verts.new(v)
    bmesh.ops.convex_hull(bm, input=bm.verts)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def scale_objs(objs, s):
    for o in objs:
        for v in o.data.vertices:
            v.co *= s
        o.data.update()


def mirror_objs(objs):
    for o in objs:
        for v in o.data.vertices:
            v.co.x = -v.co.x
        o.data.flip_normals()
        o.data.update()


def export_glb(objs, path):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    kw = dict(filepath=path, export_format='GLB', use_selection=True, export_apply=True, export_yup=True,
              export_materials='EXPORT', export_image_format='NONE', export_normals=True, export_texcoords=True, export_tangents=True)
    try:
        bpy.ops.export_scene.gltf(export_vertex_color='ACTIVE', **kw)
    except TypeError:
        bpy.ops.export_scene.gltf(**kw)
    print("EXPORTED", path, "%d tris" % sum(tris(o) for o in objs if "colonly" not in o.name))


def lit_render(objs_hide, tag, views, size=(1280, 960), samples=48):
    """Cycles stills with the baked maps on the figure, a violet pool light below and a cold moon behind."""
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.device = 'CPU'
    sc.cycles.samples = samples
    sc.cycles.use_denoising = True
    sc.render.resolution_x, sc.render.resolution_y = size
    sc.world = bpy.data.worlds.new("w")
    sc.world.use_nodes = True
    sc.world.node_tree.nodes["Background"].inputs[0].default_value = (0.03, 0.04, 0.09, 1)
    sc.world.node_tree.nodes["Background"].inputs[1].default_value = 1.0
    for o in objs_hide:
        o.hide_render = True
    lights = [("moon", 'SUN', (0, 0, 0), (math.radians(50), 0, math.radians(200)), 3.0, (0.55, 0.65, 1.0)),
              ("pool", 'AREA', (0, 22, -2), (math.radians(105), 0, 0), 26000.0, (0.55, 0.38, 1.0)),
              ("fire", 'AREA', (-30, 30, 8), (math.radians(80), 0, math.radians(-40)), 2500.0, (1.0, 0.6, 0.3))]
    for n, t, loc, rot, e, c in lights:
        ld = bpy.data.lights.new(n, t)
        ld.energy = e
        ld.color = c
        if t == 'AREA':
            ld.size = 14.0
        lo = bpy.data.objects.new(n, ld)
        lo.location = loc
        lo.rotation_euler = rot
        sc.collection.objects.link(lo)
    cd = bpy.data.cameras.new("cam")
    cam = bpy.data.objects.new("cam", cd)
    sc.collection.objects.link(cam)
    sc.camera = cam
    cd.clip_end = 900
    for name, loc, tgt, lens in views:
        cam.location = Vector(loc)
        cam.rotation_euler = (Vector(tgt) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
        cd.lens = lens
        sc.render.filepath = os.path.join(PREVIEW, "%s_%s.png" % (tag, name))
        bpy.ops.render.render(write_still=True)


def textured_materials(tag_by_obj):
    """Principled materials using the baked maps: for the Blender-side review renders."""
    for ob, tag in tag_by_obj:
        m = bpy.data.materials.new("pv_" + tag)
        m.use_nodes = True
        nt = m.node_tree
        bs = nt.nodes["Principled BSDF"]
        al = nt.nodes.new('ShaderNodeTexImage')
        al.image = bpy.data.images.load(os.path.join(OUT, "watchers_%s_albedo.png" % tag))
        nm = nt.nodes.new('ShaderNodeTexImage')
        nm.image = bpy.data.images.load(os.path.join(OUT, "watchers_%s_normal.png" % tag))
        nm.image.colorspace_settings.name = 'Non-Color'
        orm = nt.nodes.new('ShaderNodeTexImage')
        orm.image = bpy.data.images.load(os.path.join(OUT, "watchers_%s_orm.png" % tag))
        orm.image.colorspace_settings.name = 'Non-Color'
        nmap = nt.nodes.new('ShaderNodeNormalMap')
        mul = nt.nodes.new('ShaderNodeMix')
        mul.data_type = 'RGBA'
        mul.blend_type = 'MULTIPLY'
        mul.inputs[0].default_value = 1.0
        sep = nt.nodes.new('ShaderNodeSeparateColor')
        if arg("--dbg") == "albedo":
            nt.links.new(al.outputs['Color'], bs.inputs['Base Color'])
            ob.data.materials.clear()
            ob.data.materials.append(m)
            continue
        nt.links.new(al.outputs['Color'], mul.inputs[6])
        nt.links.new(orm.outputs['Color'], sep.inputs[0])
        nt.links.new(sep.outputs[0], mul.inputs[7])
        nt.links.new(mul.outputs[2], bs.inputs['Base Color'])
        nt.links.new(sep.outputs[1], bs.inputs['Roughness'])
        em = nt.nodes.new('ShaderNodeTexImage')
        em.image = bpy.data.images.load(os.path.join(OUT, "watchers_%s_emit.png" % tag))
        nt.links.new(em.outputs['Color'], bs.inputs['Emission Color'])
        bs.inputs['Emission Strength'].default_value = 1.0
        nt.links.new(nm.outputs['Color'], nmap.inputs['Color'])
        if arg('--dbg') != 'nonormal':
            nt.links.new(nmap.outputs['Normal'], bs.inputs['Normal'])
        ob.data.materials.clear()
        ob.data.materials.append(m)


# ============================================================================================
# THE PILLAR: a slender carved column (about 1:9) on a stepped base with a moulded torus, a sunk spiral frieze of
# pilgrims in high relief, a deep-cut capital whose band is incised with Order glyphs (a faint violet glow in the
# grooves), and a forged iron lantern-cage with an iron-leaf crown. Origin = the centre of the foot's bottom face;
# +Y faces the village.
# ============================================================================================
TIERS = [  # (name, half, z0, z1)
    ("foot", 3.5, 0.0, 0.7),
    ("step", 2.9, 0.7, 1.4),
]
SH0, SH1 = 2.9, 20.9                  # the shaft's foot and its top (18 m)
NDRUM = 12
BACK = -math.pi / 2
CAP_H = 2.5
ABACUS_Z = SH1 + CAP_H
TOP = ABACUS_Z + 0.75
DRUM_H = 1.2
LBASE = TOP + DRUM_H                   # the lantern's floor
PITCH = 2.5                           # the frieze climbs this much a turn
Z0S = SH0 + 0.9                       # the frieze's lowest edge
BAND_H = 1.4
RECESS = 0.28


def shaft_r(z):
    t = max(0.0, min(1.0, (z - SH0) / (SH1 - SH0)))
    return lerp(1.4, 1.2, t) + 0.06 * math.sin(math.pi * t ** 0.8)


def recess(z, phi):
    """How deep the spiral frieze is sunk into the shaft at (z, angle)."""
    th = (phi - BACK) % math.tau
    ph = (z - Z0S - PITCH * th / math.tau) % PITCH
    inb = sstep(0.0, 0.05, ph) * (1.0 - sstep(BAND_H - 0.05, BAND_H, ph))
    inb *= sstep(Z0S - 0.15, Z0S + 0.25, z) * (1.0 - sstep(SH1 - 1.9, SH1 - 1.3, z))
    return RECESS * inb


def build_shaft(P, rnd):
    """Coursed drums with chamfered joints, a gentle taper and entasis; the frieze sunk into them; one drum cracked
    and shifted a few cm."""
    bm = P.of("fig")
    N = 72
    zb = [SH0 + (SH1 - SH0) * i / NDRUM for i in range(NDRUM + 1)]
    for i in range(NDRUM):
        z0, z1 = zb[i], zb[i + 1]
        sh = Vector((0.045, 0.03, 0.0)) if i == 7 else Vector((rnd.uniform(-0.012, 0.012), rnd.uniform(-0.012, 0.012), 0.0))
        nint = max(2, int((z1 - z0 - 0.14) / 0.09))
        rows = [(z0, -0.07), (z0 + 0.07, 0.0)] + [(lerp(z0 + 0.07, z1 - 0.07, (k + 1) / (nint + 1)), 0.0) for k in range(nint)] + [(z1 - 0.07, 0.0), (z1, -0.07)]
        rings = []
        for z, ins in rows:
            ring = []
            for j in range(N):
                ph = BACK + math.tau * j / N
                R = shaft_r(z) + ins - recess(z, ph)
                ring.append(Vector((math.cos(ph) * R, math.sin(ph) * R, z)) + sh)
            rings.append(ring)
        loft(bm, rings, False, False)


def sq_ring(z, h, n, N=96):
    """A rounded square (a superellipse of exponent n; n = 2 is a circle) of half-width h at height z."""
    e = 2.0 / n
    pts = []
    for j in range(N):
        a = BACK + math.tau * j / N
        c, s_ = math.cos(a), math.sin(a)
        pts.append(Vector((h * math.copysign(abs(c) ** e, c), h * math.copysign(abs(s_) ** e, s_), z)))
    return pts


PLINTH = [(0.0, 3.42, 14), (0.05, 3.5, 14), (0.35, 3.5, 14), (0.62, 3.5, 14), (0.7, 3.45, 14), (0.7, 3.3, 14), (0.7, 3.12, 14), (0.7, 2.97, 12),
          (0.73, 2.93, 12), (0.8, 2.9, 12), (1.1, 2.9, 12), (1.32, 2.9, 12), (1.4, 2.86, 10), (1.4, 2.72, 8), (1.4, 2.58, 5), (1.4, 2.45, 3), (1.4, 2.4, 2),
          (1.46, 2.52, 2), (1.62, 2.74, 2), (1.8, 2.64, 2), (1.98, 2.38, 2), (2.12, 2.08, 2), (2.3, 1.92, 2), (2.5, 1.7, 2), (2.7, 1.55, 2), (SH0 + 0.02, 1.42, 2)]


def build_base_drum(P):
    """The stepped plinth and the moulded base (a torus, a scotia, a fillet) as one baked loft."""
    bm = P.of("fig")
    loft(bm, [sq_ring(z, h, n) for (z, h, n) in PLINTH], True, False)


def slab_between(bm, a, b, w, d, n):
    """A flat bar from a to b (w wide, d thick, d along n): a staff carved flat against the stone."""
    dirv = (b - a)
    L = dirv.length
    if L < 1e-5:
        return
    dirv = dirv / L
    x = n.cross(dirv).normalized()
    nn = dirv.cross(x).normalized()
    M = Matrix.Translation((a + b) * 0.5) @ Matrix((x, nn, dirv)).transposed().to_4x4() @ Matrix.Diagonal((w, d, L, 1.0))
    res = bmesh.ops.create_cube(bm, size=1.0, matrix=M)
    for v in res["verts"]:
        for e in v.link_edges:
            e.seam = True


def pilgrim(bm, org, t, n, rnd, k, kind="walk", other=None):
    """A pilgrim in high relief on the frieze floor: half a figure bent into the climb, a cloak dragging behind, a pack,
    an arm to a staff carved flat against the stone (every bar follows the shaft's curve). kind: walk, kneel, fall."""
    up = Vector((0, 0, 1))
    H = 1.1 + 0.1 * rnd.random()
    PR = 0.7
    th0 = math.atan2(n.y, n.x)
    R0 = math.hypot(org.x, org.y)
    zb0 = org.z

    def pos(sv, zz, nn):
        a = th0 + sv / R0
        r = R0 + nn
        return Vector((math.cos(a) * r, math.sin(a) * r, zb0 + zz)), Vector((math.cos(a), math.sin(a), 0.0))

    def hug(s0, z0_, s1, z1_, w, d, nn, steps=3):
        for i in range(steps):
            sa, sb = lerp(s0, s1, i / steps), lerp(s0, s1, (i + 1) / steps)
            za, zb_ = lerp(z0_, z1_, i / steps), lerp(z0_, z1_, (i + 1) / steps)
            pa, na = pos(sa, za, nn)
            pb, nb = pos(sb, zb_, nn)
            slab_between(bm, pa, pb, w, d, (na + nb).normalized())
    if kind == "fall":
        a = org + t * (-0.46) + n * 0.02 + up * 0.15
        b = org + t * 0.38 + n * 0.02 + up * 0.17
        tube(bm, [a, (a + b) * 0.5 + up * 0.03, b], [0.11, 0.15, 0.1], 8, True, True)
        sphere(bm, b + t * 0.14 + up * 0.04, 0.12, 8, 5)
        hug(0.45, 0.06, 0.95, 0.12, 0.07, 0.06, 0.02)
        hug(-0.3, 0.03, 0.55, 0.45, 0.05, 0.04, 0.03)
        return
    kneel = kind == "kneel"
    h = H * (0.66 if kneel else 1.0)
    lean = (0.4 if kneel else 0.3) + 0.08 * rnd.random()
    rows = [(0.0, 0.34, 0.3), (0.1, 0.33, 0.29), (0.4, 0.24, 0.22), (0.62, 0.27, 0.24), (0.72, 0.33, 0.27), (0.78, 0.25, 0.23), (0.82, 0.13, 0.13),
            (0.86, 0.18, 0.18), (0.95, 0.23, 0.22), (1.04, 0.19, 0.19), (1.13, 0.09, 0.09), (1.18, 0.0, 0.0)]
    rings = []
    for f, rt, rn in rows:
        zz = f * h
        sh = lean * zz * (0.5 + 0.9 * f) + (0.1 if f > 0.82 else 0.0)
        ring = []
        for j in range(10):
            ang = math.tau * j / 10
            out = math.sin(ang) * rn * PR * 1.4 * (1.0 + 0.06 * math.sin(5 * ang + k))
            ring.append(org + t * (sh + math.cos(ang) * rt) + n * max(0.0, out) + up * zz)
        rings.append(ring)
    loft(bm, rings[::-1], True, True)
    # the cloak dragging behind, flat on the stone
    hug(lean * 0.5 * h, 0.55 * h, -0.3, 0.08, 0.2, 0.05, 0.07, 3)
    # the arm and the staff, carved flat
    s_sh = 0.1 + lean * 0.7 * h
    s_hand = 0.5 if not kneel else 0.35
    hug(s_sh, 0.72 * h, s_hand, 0.5 * h, 0.12, 0.08, 0.1, 2)
    hug(0.42, 0.0 if not kneel else 0.05, 0.9, 1.3 * H, 0.05, 0.045, 0.045, 3)


NICHES = []


def niche_list():
    """Arched niches between the turns: (angle, height, kind); even ones hold a votive cup, odd ones a carved pilgrim's mark."""
    if NICHES:
        return NICHES
    for k in range(12):
        m = k // 2
        th = (2.3 * m + 0.8 + (k % 2) * math.pi) % math.tau
        z = Z0S + PITCH * (th / math.tau + m) + BAND_H + 0.5
        if z < SH1 - 2.9 and z > Z0S + 1.0:
            NICHES.append((BACK + th, z, "cup" if k % 2 == 0 else "mark"))
    return NICHES


def build_niches(P):
    """The votive cups (and their flames) standing in the cup niches."""
    bm = P.of("fig")
    fl = P.of("flame")
    for (phi, zc, kind) in niche_list():
        if kind != "cup":
            continue
        R = shaft_r(zc) - 0.07
        n = Vector((math.cos(phi), math.sin(phi), 0.0))
        c = Vector((n.x * R, n.y * R, zc - 0.27))
        rows = [(0.0, 0.03), (0.03, 0.085), (0.09, 0.12), (0.15, 0.13), (0.17, 0.11)]
        rings = []
        for dz, r in rows:
            rings.append([c + Vector((0, 0, dz)) + Vector((math.cos(math.tau * j / 12) * r, math.sin(math.tau * j / 12) * r, 0)) for j in range(12)])
        loft(bm, rings, True, True)
        sphere(fl, c + Vector((0, 0, 0.27)), 0.06, 6, 4, (1, 1, 1.7))


def cap_r(z_rel, phi):
    rows = [(0.0, 0.0), (0.12, 0.1), (0.25, 0.04), (0.65, 0.5), (1.1, 1.0), (1.5, 1.45), (1.8, 1.75)]
    d = prof(rows, min(z_rel, 1.8))[0]
    r = shaft_r(SH1) + d
    if 0.55 < z_rel < 1.85:
        r += (0.5 - abs(math.sin(8 * phi))) * 0.25 * sstep(0.55, 0.8, z_rel) - 0.1 * sstep(0.55, 0.8, z_rel)
    return r


GLYPH_Z = SH1 + 2.17
GLYPH_CELLS = 36
BAND_R = 3.0


ABACUS = [(0.0, 3.05, 10), (0.04, 3.15, 10), (0.12, 3.32, 10), (0.22, 3.5, 10), (0.3, 3.56, 10), (0.4, 3.56, 10), (0.43, 3.25, 10), (0.47, 3.18, 10),
          (0.58, 3.3, 10), (0.7, 3.34, 10), (0.75, 3.28, 10), (0.75, 3.0, 10), (0.75, 2.5, 8), (0.75, 1.9, 4), (0.75, 1.2, 2), (0.75, 0.5, 2)]


def build_capital(P, rnd):
    bm = P.of("fig")
    N = 120
    zs = [0.0, 0.1, 0.2, 0.3, 0.45, 0.6, 0.8, 1.0, 1.2, 1.4, 1.6, 1.8, 1.86, 1.94, 2.02, 2.1, 2.18, 2.26, 2.34, 2.42, 2.5]
    rings = []
    for zr in zs:
        ring = []
        for j in range(N):
            ph = BACK + math.tau * j / N
            R = cap_r(zr, ph) if zr <= 1.8 else cap_r(1.8, 0.0) + 0.04
            ring.append(Vector((math.cos(ph) * R, math.sin(ph) * R, SH1 + zr)))
        rings.append(ring)
    loft(bm, rings, False, False)
    # the abacus: ovolo and cavetto mouldings, a rounded square, topped
    loft(bm, [sq_ring(ABACUS_Z + z, h, n) for (z, h, n) in ABACUS], True, True)
    # the short moulded drum the lantern stands on
    drum = [(0.0, 2.1), (0.08, 2.2), (0.2, 2.05), (0.32, 1.85), (0.9, 1.82), (1.0, 1.95), (1.12, 2.08), (1.2, 2.0)]
    loft(bm, [sq_ring(TOP + z, r, 2, 72) for (z, r) in drum] + [sq_ring(TOP + 1.2, 1.4, 2, 72), sq_ring(TOP + 1.2, 0.5, 2, 72)], True, True)


# the Order's glyphs: irregular strokes per cell, drawn once
_GLYPHS = []


def glyph_strokes():
    """An inscription: every cell a vertical stave with ticks at a steady rhythm; every third cell a lozenge."""
    if _GLYPHS:
        return _GLYPHS
    rnd = random.Random(77)
    for c in range(GLYPH_CELLS):
        segs = []
        if c % 3 == 2:
            segs += [(0, -0.2, 0.13, 0.0), (0.13, 0.0, 0, 0.2), (0, 0.2, -0.13, 0.0), (-0.13, 0.0, 0, -0.2)]
            segs.append((0, -0.06, 0, 0.06))
        else:
            x0 = rnd.uniform(-0.02, 0.02)
            segs.append((x0, -0.21, x0, 0.21))
            for i in range(3):
                y = -0.13 + 0.13 * i
                side = 1 if (c + i) % 2 == 0 else -1
                segs.append((x0, y, x0 + side * 0.13, y + 0.07 + rnd.uniform(-0.015, 0.015)))
        _GLYPHS.append(segs)
    return _GLYPHS


def seg_dist(px, py, x0, y0, x1, y1):
    dx, dy = x1 - x0, y1 - y0
    L2 = dx * dx + dy * dy + 1e-9
    t = np.clip(((px - x0) * dx + (py - y0) * dy) / L2, 0, 1)
    return np.hypot(px - (x0 + t * dx), py - (y0 + t * dy))


def pillar_extra(P, N):
    """High-poly detail only the pillar needs: chipped arrises at the joints, the cracked drum's split, worn figures,
    and the glyphs cut into the capital's band (returns the displacement and the faint glow in the grooves)."""
    zb = [SH0 + (SH1 - SH0) * i / NDRUM for i in range(NDRUM + 1)]
    z = P[:, 2]
    rad = np.hypot(P[:, 0], P[:, 1])
    d = np.zeros(len(P))
    glow = np.zeros(len(P))
    on_shaft = (z > SH0 - 0.1) & (z < SH1 + 0.1) & (rad < 1.6) & (np.abs(N[:, 2]) < 0.5)
    chip = sstep_np(0.55, 0.8, fbm_np(P, 2.2, 3, 21))
    for zj in zb[1:-1]:
        d -= 0.045 * chip * np.exp(-(((z - zj) / 0.1) ** 2)) * on_shaft
    z0, z1 = zb[8], zb[9]
    ang = np.arctan2(P[:, 1], P[:, 0])
    cr = np.abs(((ang - 0.9 - 0.5 * (z - z0) + math.pi) % math.tau) - math.pi)
    d -= 0.06 * np.exp(-((cr / 0.022) ** 2)) * ((z > z0) & (z < z1)) * on_shaft
    # worn relief: weather eats the figures
    d += 0.012 * (fbm_np(P, 7.0, 3, 41) - 0.5) * on_shaft
    # the sunk stair: small steps rising along the band's floor
    a_ = (np.arctan2(P[:, 1], P[:, 0]) - BACK) % math.tau
    ph_ = (z - Z0S - PITCH * a_ / math.tau) % PITCH
    in_band = on_shaft & (z > Z0S) & (z < SH1 - 1.6)
    floor_m = sstep_np(0.12, 0.2, ph_) * (1.0 - sstep_np(BAND_H - 0.2, BAND_H - 0.12, ph_)) * in_band
    w_ = math.tau * (z - ph_ - Z0S) / PITCH + a_
    Rm = np.maximum(rad, 0.5)
    stepf = (w_ * Rm / 0.6) % 1.0
    d += floor_m * 0.14 * sstep_np(0.0, 0.8, stepf)
    d -= floor_m * 0.03 * sstep_np(0.9, 1.0, stepf)
    # the arched niches between the turns: a votive cup in some, a pilgrim's mark (staff and cloak) incised in the rest
    ang0 = np.arctan2(P[:, 1], P[:, 0])
    for (phi, zc, kind) in niche_list():
        du = ((ang0 - phi + math.pi) % math.tau - math.pi) * Rm
        dv = z - zc
        near = on_shaft & (np.abs(du) < 0.4) & (np.abs(dv) < 0.5)
        if not near.any():
            continue
        ii = np.nonzero(near)[0]
        u, v = du[ii], dv[ii]
        arch = (np.abs(u) < 0.26) & (v > -0.34) & ((v < 0.1) | (u * u + (v - 0.1) ** 2 < 0.26 ** 2))
        edge_ = np.minimum(0.26 - np.abs(u), v + 0.34)
        mk = np.where(arch, sstep_np(0.0, 0.05, edge_), 0.0)
        d[ii] -= 0.11 * mk
        if kind == "mark":
            dist = np.minimum.reduce([seg_dist(u, v, 0.07, -0.3, 0.09, 0.26), seg_dist(u, v, -0.03, 0.1, -0.15, -0.28), seg_dist(u, v, -0.03, 0.1, 0.08, -0.28), seg_dist(u, v, -0.15, -0.28, 0.08, -0.28)])
            d[ii] -= 0.022 * mk * (1.0 - sstep_np(0.012, 0.026, dist))
    # the masonry of the plinth: course joints, paving joints on the treads, chips
    pl = (z < 1.45) & (rad > 2.3)
    row = np.floor(z / 0.7)
    along = P[:, 0] + P[:, 1] + row * 1.37
    fr = np.abs(((along / 1.7) % 1.0) - 0.5) * 2.0
    wall = (np.abs(N[:, 2]) < 0.6) & pl
    joint = sstep_np(0.955, 1.0, fr) * wall
    d -= 0.04 * joint
    tread = (N[:, 2] > 0.8) & pl
    gx = np.abs(((P[:, 0] / 1.8) % 1.0) - 0.5) * 2.0
    gy = np.abs(((P[:, 1] / 1.5) % 1.0) - 0.5) * 2.0
    d -= 0.03 * np.maximum(sstep_np(0.95, 1.0, gx), sstep_np(0.95, 1.0, gy)) * tread
    d -= 0.05 * sstep_np(0.65, 0.82, fbm_np(P, 1.8, 3, 55)) * (joint * 0.7 + 0.3 * tread) * pl
    # the glyph band
    band = (z > SH1 + 1.9) & (z < SH1 + 2.46) & (rad > 2.4)
    if band.any():
        idx = np.nonzero(band)[0]
        a = (np.arctan2(P[idx, 1], P[idx, 0]) - BACK) % math.tau
        cell = np.minimum((a / (math.tau / GLYPH_CELLS)).astype(int), GLYPH_CELLS - 1)
        u = ((a / (math.tau / GLYPH_CELLS)) - cell - 0.5) * (math.tau * BAND_R / GLYPH_CELLS)
        v = z[idx] - GLYPH_Z
        gl = glyph_strokes()
        dist = np.full(len(idx), 9.0)
        for c in range(GLYPH_CELLS):
            m = cell == c
            if not m.any():
                continue
            for (x0, y0, x1, y1) in gl[c]:
                dist[m] = np.minimum(dist[m], seg_dist(u[m], v[m], x0, y0, x1, y1))
        d[idx] -= 0.055 * (1.0 - sstep_np(0.02, 0.042, dist))
        glow[idx] = np.exp(-((dist / 0.013) ** 2)) * 0.9
    return d, glow


# --- the lantern --------------------------------------------------------------------------------
LANT_R = 1.0


def blade(bm, pts, wmax, thick):
    """An iron leaf or spike: a flat lozenge section along a path, widest about a third up."""
    tmp = bmesh.new()
    rings = []
    for i, c in enumerate(pts):
        t = i / (len(pts) - 1)
        w = wmax * math.sin(math.pi * min(1.0, t * 1.1 + 0.08)) ** 0.8 * (1.0 - 0.6 * t) + 0.012
        T = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        side = T.cross(Vector((c.x, c.y, 0.0)).normalized()).normalized()
        rad = side.cross(T).normalized()
        rings.append([c + side * w, c + rad * thick, c - side * w, c - rad * thick])
    loft(tmp, rings, True, True)
    bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces)
    append_bm(bm, tmp)
    tmp.free()


def lantern(P, rnd):
    """A forged cage about 2.4 m across: eight hammered square bars, three strapped rings, an X of strapwork in every
    panel, rivets, a floor plate with spikes, an iron-leaf crown; a violet-white flame inside a cracked smoked glass shell."""
    st = P.of("iron")
    z0 = LBASE + 0.05
    H = 1.9
    tube(st, [Vector((0, 0, z0)), Vector((0, 0, z0 + 0.15)), Vector((0, 0, z0 + 0.4))], [1.55, 1.6, 1.4], 18, True, True)
    ring3(st, (0, 0, z0 + 0.2), (0, 0, 1), 1.55, 0.1, 24, 5)
    for k in range(10):
        a = math.tau * k / 10
        seg_tube(st, Vector((math.cos(a) * 1.5, math.sin(a) * 1.5, z0 + 0.1)), Vector((math.cos(a) * 1.78, math.sin(a) * 1.78, z0 - 0.4)), 0.12, 0.02, 4)
    nb = 8
    zb = z0 + 0.4
    zt = zb + H
    bars = []
    for i in range(nb):
        a = math.tau * (i + 0.5) / nb
        pts, rad = [], []
        for k in range(12):
            t = k / 11.0
            r = LANT_R + 0.16 * math.sin(math.pi * t)
            j = rnd.uniform(-0.018, 0.018)
            pts.append(Vector((math.cos(a) * (r + j), math.sin(a) * (r + j), lerp(zb, zt, t))))
            rad.append(0.095 * rnd.uniform(0.85, 1.2))
        bars.append((a, pts))
        cut = 8 if i == 5 else 12
        tube(st, pts[:cut], rad[:cut], 4, True, True)
        for t in (0.04, 0.5, 0.96):
            sphere(st, pts[min(int(t * 11), 11)], 0.085, 6, 4)
    for t in (0.04, 0.5, 0.96):
        z = lerp(zb, zt, t)
        ring3(st, (0, 0, z), (0, 0, 1), LANT_R + 0.16 * math.sin(math.pi * t) + 0.02, 0.07, 32, 4)
    for i in range(nb):
        a0, p0 = bars[i]
        a1, p1 = bars[(i + 1) % nb]
        if i in (5, 4):
            continue
        for (pa, pb) in ((p0[1], p1[10]), (p0[10], p1[1])):
            tube(st, [pa, (pa + pb) * 0.5, pb], [0.03, 0.036, 0.03], 4, True, True)
        sphere(st, (p0[5] + p1[5]) * 0.5, 0.07, 6, 4)
    # the crown: a rim, twelve iron leaves curving in, shorter spikes between, a finial and a loop
    ring3(st, (0, 0, zt + 0.08), (0, 0, 1), 1.22, 0.1, 32, 5)
    for k in range(8):
        a = math.tau * k / 8
        pts = []
        for s_ in range(7):
            t = s_ / 6.0
            r = 1.22 - 0.72 * t ** 1.4
            pts.append(Vector((math.cos(a) * r, math.sin(a) * r, zt + 0.08 + 1.05 * t)))
        blade(st, pts, 0.17, 0.04)
    for k in range(8):
        a = math.tau * (k + 0.5) / 8
        pts = [Vector((math.cos(a) * (1.18 + 0.4 * (s_ / 4.0) ** 1.5), math.sin(a) * (1.18 + 0.4 * (s_ / 4.0) ** 1.5), zt + 0.08 + 0.5 * (s_ / 4.0) ** 0.9)) for s_ in range(5)]
        blade(st, pts, 0.07, 0.035)
    sphere(st, (0, 0, zt + 1.22), 0.2, 8, 6)
    tube(st, [Vector((0, 0, zt + 1.3)), Vector((0, 0, zt + 1.65)), Vector((0, 0, zt + 2.0))], [0.1, 0.07, 0.015], 6, True, True)
    ring3(st, (0, 0, zt + 1.45), (1, 0, 0), 0.3, 0.05, 12, 4)
    # the flame: a hot core, a violet halo, a cracked smoked-glass shell with holes
    c = Vector((0, 0, zb + H * 0.5))
    sphere(P.of("core"), c, 0.34, 14, 9)
    sphere(P.of("orb"), c, 0.68, 18, 11)
    gl = P.of("glass")
    res = bmesh.ops.create_uvsphere(gl, u_segments=20, v_segments=12, radius=0.86, matrix=Matrix.Translation(c))
    dirs = [Vector((1, 0.3, 0.2)), Vector((-0.4, -1, 0.5)), Vector((0.2, 0.9, -0.5)), Vector((-1, 0.2, -0.3))]
    kill = []
    for f in gl.faces:
        fc = (f.calc_center_median() - c).normalized()
        if any(fc.dot(d.normalized()) > 0.93 for d in dirs[:3]):
            kill.append(f)
    bmesh.ops.delete(gl, geom=kill, context='FACES')
    return c, zt + 2.0


def oval_link(bm, c, ax, side, a, b, r, seg=12, tseg=5):
    """A forged oval link: an ellipse of a x b round a tube of radius r."""
    nrm = ax.cross(side).normalized()
    rings = []
    for k in range(seg):
        ph = math.tau * k / seg
        pos = c + ax * (a * math.cos(ph)) + side * (b * math.sin(ph))
        rad = (ax * (math.cos(ph) / a) + side * (math.sin(ph) / b)).normalized()
        ring = []
        for q in range(tseg):
            qq = math.tau * q / tseg
            ring.append(pos + rad * (math.cos(qq) * r) + nrm * (math.sin(qq) * r))
        rings.append(ring)
    vr = [[bm.verts.new(p) for p in ring] for ring in rings]
    for i in range(seg):
        i2 = (i + 1) % seg
        for j in range(tseg):
            bm.faces.new((vr[i][j], vr[i][(j + 1) % tseg], vr[i2][(j + 1) % tseg], vr[i2][j]))


def chain_path(st, pts, rnd, a=0.36, b=0.2, r=0.12, spacing=0.52):
    """Forged oval links along a polyline (a list of points), alternately turned."""
    total = 0.0
    seglen = []
    for i in range(len(pts) - 1):
        seglen.append((pts[i + 1] - pts[i]).length)
        total += seglen[-1]
    n = max(2, int(total / spacing))
    for k in range(n):
        f = (k + 0.5) / n * total
        acc = 0.0
        for i, L in enumerate(seglen):
            if acc + L >= f:
                t = (f - acc) / L
                p = pts[i].lerp(pts[i + 1], t)
                Tl = (pts[i + 1] - pts[i]).normalized()
                break
            acc += L
        ref = Vector((0, 0, 1)) if abs(Tl.z) < 0.9 else Vector((1, 0, 0))
        s1 = Tl.cross(ref).normalized()
        s2 = Tl.cross(s1).normalized()
        j = 1.0 + rnd.uniform(-0.08, 0.08)
        oval_link(st, p, Tl, s1 if k % 2 == 0 else s2, a * j, b * j, r * rnd.uniform(0.92, 1.1))


def chains_and_rings(P, cloth, rnd, zt):
    """Heavy festoons between the four corners of the abacus, pilgrims' cloths knotted at the corner eyes, and one chain
    from the cage's crown to a ring on the abacus."""
    st = P.of("iron")
    h = 3.32
    zc = ABACUS_Z + 0.12
    corners = [Vector((sx * h, sy * h, zc)) for sx, sy in ((1, 1), (-1, 1), (-1, -1), (1, -1))]
    for i, c in enumerate(corners):
        out = Vector((c.x, c.y, 0)).normalized()
        tube(st, [c - out * 0.02, c + out * 0.1], [0.2, 0.2], 12, True, True)          # a round bolted plate
        ring3(st, c + out * 0.3, Vector((-out.y, out.x, 0)), 0.34, 0.085, 14, 5)
    for i in range(4):
        A, B = corners[i] + Vector((corners[i].x, corners[i].y, 0)).normalized() * 0.3, corners[(i + 1) % 4] + Vector((corners[(i + 1) % 4].x, corners[(i + 1) % 4].y, 0)).normalized() * 0.3
        pts = []
        for k in range(13):
            t = k / 12.0
            p = A.lerp(B, t)
            out = Vector((p.x, p.y, 0)).normalized()
            p = p + out * (0.25 * math.sin(math.pi * t)) - Vector((0, 0, 2.1 * math.sin(math.pi * t)))
            pts.append(p)
        chain_path(st, pts, rnd)
    # the single chain from the crown's rim to a ring on the abacus
    A = Vector((1.25, 0.0, zt + 0.1))
    B = Vector((2.7, 0.0, TOP + 0.1))
    box(st, B + Vector((0, 0, -0.02)), (0.5, 0.5, 0.06))
    ring3(st, B + Vector((0, 0, 0.1)), Vector((0, 1, 0)), 0.26, 0.075, 12, 4)
    pts = []
    for k in range(10):
        t = k / 9.0
        p = A.lerp(B, t) + Vector((0.5 * math.sin(math.pi * t), 0, -0.9 * math.sin(math.pi * t)))
        pts.append(p)
    chain_path(st, pts, rnd, 0.3, 0.17, 0.1, 0.46)


def plinth(P, rnd):
    """Votive candles in clusters of three to five on the treads, a third as big again."""
    cand = P.of("cand")
    flame = P.of("flame")
    centres = [(x, 3.2, 0.7) for x in (-2.5, -0.9, 0.8, 2.4)] + [(3.2, y, 0.7) for y in (-1.6, 1.4)] + [(-3.2, y, 0.7) for y in (-1.4, 1.6)] + [(x, 2.55, 1.4) for x in (-1.6, 0.2, 1.7)]
    for (cx, cy, z) in centres:
        for k in range(rnd.randint(3, 5)):
            a = rnd.uniform(0, math.tau)
            r = rnd.uniform(0.0, 0.34) if k else 0.0
            x, y = cx + math.cos(a) * r, cy + math.sin(a) * r
            hh = rnd.uniform(0.3, 0.75)
            tube(cand, [Vector((x, y, z + 0.05)), Vector((x, y, z + hh * 0.5)), Vector((x, y, z + hh))], [0.17, 0.15, 0.135], 8, True, True)
            sphere(cand, (x, y, z + 0.05), 0.21, 8, 3, (1, 1, 0.3))
            sphere(flame, (x, y, z + hh + 0.17), 0.11, 6, 4, (1, 1, 1.7))


def build_all():
    rnd = random.Random(11)
    P = Parts()
    cloth = bmesh.new()
    build_base_drum(P)
    build_shaft(P, rnd)
    build_capital(P, rnd)
    plinth(P, rnd)
    build_niches(P)
    orb_c, top = lantern(P, rnd)
    chains_and_rings(P, cloth, rnd, top - 2.0)
    return P, orb_c, top


def tier_hulls():
    objs = []
    for i, (name, h, z0, z1) in enumerate(TIERS):
        objs.append(hull_obj("Pillar_tier%d-convcolonly" % i, [Vector((sx * h, sy * h, z)) for sx in (-1, 1) for sy in (-1, 1) for z in (z0, z1)]))
    return objs


def collision_hulls(top):
    objs = tier_hulls()
    N = 14
    objs.append(hull_obj("Pillar_base-convcolonly", [Vector((math.cos(math.tau * j / N) * r, math.sin(math.tau * j / N) * r, z)) for j in range(N) for (z, r) in ((1.4, 2.3), (1.7, 2.7), (SH0, 1.3))]))
    objs.append(hull_obj("Pillar_shaft-convcolonly", [Vector((math.cos(math.tau * j / N) * shaft_r(z) * 1.04, math.sin(math.tau * j / N) * shaft_r(z) * 1.04, z)) for j in range(N) for z in (SH0, (SH0 + SH1) / 2, SH1)]))
    objs.append(hull_obj("Pillar_capital-convcolonly", [Vector((math.cos(math.tau * j / N) * 3.0, math.sin(math.tau * j / N) * 3.0, z)) for j in range(N) for z in (SH1 + 1.0, ABACUS_Z)]
                         + [Vector((sx * 3.5, sy * 3.5, z)) for sx in (-1, 1) for sy in (-1, 1) for z in (ABACUS_Z, TOP)]))
    objs.append(hull_obj("Pillar_lantern-convcolonly", [Vector((math.cos(math.tau * j / 10) * 1.75, math.sin(math.tau * j / 10) * 1.75, z)) for j in range(10) for z in (LBASE, LBASE + 3.6)]))
    return objs


def far_set(stone, orb_c, top):
    """>150 m: the stone decimated, a thin lantern and the flame."""
    f = stone.copy()
    f.data = stone.data.copy()
    f.name = "Pillar_stone_far"
    bpy.context.scene.collection.objects.link(f)
    bpy.context.view_layer.objects.active = f
    md = f.modifiers.new("d", 'DECIMATE')
    md.ratio = 1000.0 / max(1, tris(f))
    bpy.ops.object.modifier_apply(modifier=md.name)
    f.data.materials.clear()
    f.data.materials.append(bpy.data.materials.get("stone"))
    bm = bmesh.new()
    for name, h, z0, z1 in TIERS:
        box(bm, (0, 0, (z0 + z1) / 2), (2 * h, 2 * h, z1 - z0))
    me = bpy.data.meshes.new("Pillar_base_far")
    bm.to_mesh(me)
    b = bpy.data.objects.new("Pillar_base_far", me)
    bpy.context.scene.collection.objects.link(b)
    b.data.materials.append(bpy.data.materials.get("stone"))
    bm2 = bmesh.new()
    tube(bm2, [Vector((0, 0, LBASE)), Vector((0, 0, LBASE + 0.5)), Vector((0, 0, LBASE + 2.1)), Vector((0, 0, LBASE + 3.6))], [1.6, 1.3, 1.3, 0.05], 8, True, True)
    me2 = bpy.data.meshes.new("Pillar_iron_far")
    bm2.to_mesh(me2)
    i = bpy.data.objects.new("Pillar_iron_far", me2)
    bpy.context.scene.collection.objects.link(i)
    i.data.materials.append(bpy.data.materials.get("iron") or bpy.data.materials.new("iron"))
    bm3 = bmesh.new()
    sphere(bm3, orb_c, 0.8, 10, 6)
    me3 = bpy.data.meshes.new("Pillar_orb_far")
    bm3.to_mesh(me3)
    o = bpy.data.objects.new("Pillar_orb_far", me3)
    bpy.context.scene.collection.objects.link(o)
    o.data.materials.append(bpy.data.materials.get("orb") or bpy.data.materials.new("orb"))
    return [f, b, i, o]


def tint(bm, fn):
    """Vertex colours from fn(position) -> (r, g, b) for meshes painted by hand (cloth, wax, iron)."""
    col = bm.loops.layers.color.get("Col") or bm.loops.layers.color.new("Col")
    for f in bm.faces:
        for l in f.loops:
            c = fn(l.vert.co)
            l[col] = (c[0], c[1], c[2], 1.0)


def rust(p):
    """Hammered iron with rust creeping from the joints and the lower bars."""
    n = noise.noise(p * 1.1) + 0.6 * noise.noise(p * 3.7 + Vector((4, 1, 2)))
    k = max(0.0, min(1.0, (n + 0.05) * 1.5))
    base = (0.3, 0.3, 0.34)
    rs = (0.62, 0.3, 0.12)
    return tuple(base[i] * (1 - k) + rs[i] * k for i in range(3))


def emissive(name, color, strength):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    e = nt.nodes.new('ShaderNodeEmission')
    e.inputs['Color'].default_value = color
    e.inputs['Strength'].default_value = strength
    o = nt.nodes.new('ShaderNodeOutputMaterial')
    nt.links.new(e.outputs['Emission'], o.inputs['Surface'])
    return m


def main():
    os.makedirs(OUT, exist_ok=True)
    reset()
    P, orb_c, top = build_all()
    box_uv_and_paint(P.bm["iron"], 3, 2.0, paint=False)
    tint(P.bm["iron"], rust)
    tint(P.bm["cand"], lambda p: (0.8, 0.74, 0.58))
    stone = mk_object(P.bm["fig"], "Pillar_fig", True, "stone")
    iron = mk_object(P.bm["iron"], "Pillar_iron", True, "iron")
    orb = mk_object(P.bm["orb"], "Pillar_orb", True, "orb")
    core = mk_object(P.bm["core"], "Pillar_core", True, "core")
    glass = mk_object(P.bm["glass"], "Pillar_glass", True, "glass")
    cand = mk_object(P.bm["cand"], "Pillar_cand", True, "cand")
    flame = mk_object(P.bm["flame"], "Pillar_flame", True, "flame")
    print("TRIS stone %d iron %d cand %d glass %d" % (tris(stone), tris(iron), tris(cand), tris(glass)))
    unwrap(stone)
    if "--reuse" not in args:
        hi = detailed(stone.data, "hi_fig", "fig", "stone", 1, extra=pillar_extra)
        print("HI verts", len(hi.data.vertices))
        bake_pair(stone, hi, "pillar", TEX)
        bpy.data.objects.remove(hi)
    objs = [stone, iron, orb, core, glass, cand, flame]
    collisions = collision_hulls(top)
    far = far_set(stone, orb_c, top)
    rub = mk_object(rubble(3, False), "Pillar_rubble", False, "stone")
    for o in objs + collisions + far + [rub]:
        for v in o.data.vertices:
            v.co *= FS
        o.data.update()
    export_glb(objs + [rub] + collisions, os.path.join(OUT, "watchers_west.glb"))
    export_glb(far, os.path.join(OUT, "watchers_west_far.glb"))
    if PREVIEW:
        textured_materials([(stone, "pillar")])
        vc = bpy.data.materials.new("pv_base")
        vc.use_nodes = True
        an = vc.node_tree.nodes.new('ShaderNodeAttribute')
        an.attribute_name = "Col"
        vc.node_tree.links.new(an.outputs['Color'], vc.node_tree.nodes['Principled BSDF'].inputs['Base Color'])
        vc.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value = 0.85
        for o in (cand, rub):
            o.data.materials.clear()
            o.data.materials.append(vc)
        ib = bpy.data.materials.new("pv_iron")
        ib.use_nodes = True
        an2 = ib.node_tree.nodes.new('ShaderNodeAttribute')
        an2.attribute_name = "Col"
        ib.node_tree.links.new(an2.outputs['Color'], ib.node_tree.nodes['Principled BSDF'].inputs['Base Color'])
        ib.node_tree.nodes['Principled BSDF'].inputs['Metallic'].default_value = 0.6
        ib.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value = 0.55
        iron.data.materials.clear()
        iron.data.materials.append(ib)
        orb.data.materials.clear()
        orb.data.materials.append(emissive("pv_orb", (0.5, 0.3, 1.0, 1), 5.0))
        core.data.materials.clear()
        core.data.materials.append(emissive("pv_core", (0.95, 0.88, 1.0, 1), 30.0))
        gm = bpy.data.materials.new("pv_glass")
        gm.use_nodes = True
        gb = gm.node_tree.nodes['Principled BSDF']
        gb.inputs['Base Color'].default_value = (0.08, 0.06, 0.1, 1)
        gb.inputs['Roughness'].default_value = 0.15
        gb.inputs['Alpha'].default_value = 0.45
        glass.data.materials.clear()
        glass.data.materials.append(gm)
        flame.data.materials.clear()
        flame.data.materials.append(emissive("pv_flame", (1.0, 0.6, 0.25, 1), 10.0))
        ld = bpy.data.lights.new("orbl", 'POINT')
        ld.energy = 12000.0
        ld.color = (0.6, 0.45, 1.0)
        ld.shadow_soft_size = 0.6
        lo = bpy.data.objects.new("orbl", ld)
        lo.location = orb_c
        bpy.context.scene.collection.objects.link(lo)
        zc = SH1 + 3.4
        lit_render(collisions + far, "lit", [
            ("front", (0, 92, 14), (0, 0, 14), 45),
            ("q3", (66, 66, 15), (0, 0, 14), 45),
            ("side", (92, 0, 14), (0, 0, 14), 45),
            ("relief", (-6.5, 9.0, 11.5), (0, 0.4, 11.0), 50),
            ("cage", (7.0, 8.5, TOP + 4.0), (0, 0, TOP + 2.0), 50),
            ("capital", (7.5, 8.5, zc), (0, 0, SH1 + 2.0), 50),
            ("below", (0, 42, 1.0), (0, 0, TOP + 1.5), 34)], samples=64)
    mirror_objs(objs + collisions + far)
    rub_e = mk_object(rubble(7, True), "Pillar_rubble_e", False, "stone")
    for v in rub_e.data.vertices:
        v.co *= FS
    rub.name = "old_rubble"
    rub_e.name = "Pillar_rubble"
    rub_e.data.update()
    export_glb(objs + [rub_e] + collisions, os.path.join(OUT, "watchers_east.glb"))
    export_glb(far, os.path.join(OUT, "watchers_east_far.glb"))


if __name__ == "__main__":
    main()
