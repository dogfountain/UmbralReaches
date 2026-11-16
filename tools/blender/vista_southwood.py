"""THE SOUTHWOOD'S PLACES: the charcoal burners stayed when the town went north, and their stacks still smoke on nights
without wind; deeper in, someone lives in the root plate of a fallen giant.
  Clamp     a charcoal clamp: a low dome of turf and earth over the stacked wood, its skin cracked, vents round its foot,
            a charred crown where the fire was let in; scorched ground round it
  Hut       the burners' hut, burned: four charred corner posts, a stone hearth and chimney still standing, the collapsed
            roof's rafters and ridge pole lying across the floor
  Cart      a two-wheeled charcoal cart tipped on its shafts, spoked wheels, a slatted bed
  Hollow    the witch's hollow: a giant tree lying where it fell (its trunk running away into the wood) and its root plate
            standing on edge, 11 m across, earth and stones held in the roots; a hut built against it, plank walls under
            a turf roof, a door, a window with lit panes, a chimney of stones, roots arching over all of it
Modelled by script (no scans, no downloads).

  tools/blender/run.sh vista_southwood.py -- [--preview DIR]
Exports art/models/vista_southwood.glb: <Piece>__<set> meshes (daub: earth and turf; timber; hewn: stones; thatch: the
roof; wax: the lit panes) and <Piece>-colonly. Each piece's origin is its own foot.
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
rnd = random.Random(41)


def sstep(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3.0 - 2.0 * t)


class Part:
    def __init__(self):
        self.bm = bmesh.new()
        self.col = self.bm.loops.layers.color.new("Col")
        self.uv = self.bm.loops.layers.uv.new("UVMap")


def face(p, verts, colours, uvs=None):
    f = p.bm.faces.new(verts)
    for i, l in enumerate(f.loops):
        l[p.col] = colours[i] if isinstance(colours, list) else colours
        w = l.vert.co
        l[p.uv].uv = uvs[i] if uvs else ((w.x + w.z) / 3.0, (w.y + w.z) / 3.0)
    return f


def box(p, c, s, yaw=0.0, tilt=(0.0, 0.0, 0.0), colour=(0.5, 0.45, 0.4, 1.0), warp=0.0, seed=0, char=0.0):
    tmp = bmesh.new()
    bmesh.ops.create_cube(tmp, size=1.0)
    for v in tmp.verts:
        v.co = Vector((v.co.x * s[0], v.co.y * s[1], v.co.z * s[2]))
    if warp:
        for v in tmp.verts:
            v.co += Vector((noise.noise(v.co * 2 + Vector((seed, 0, 0))), noise.noise(v.co * 2 + Vector((0, seed, 0))), noise.noise(v.co * 2 + Vector((0, 0, seed))))) * warp
    m = Matrix.Translation(Vector(c)) @ Matrix.Rotation(yaw, 4, 'Z') @ Matrix.Rotation(tilt[0], 4, 'X') @ Matrix.Rotation(tilt[1], 4, 'Y') @ Matrix.Rotation(tilt[2], 4, 'Z')
    mp = {v: p.bm.verts.new(m @ v.co) for v in tmp.verts}
    for f in tmp.faces:
        cs = []
        for v in f.verts:
            w = m @ v.co
            k = 1.0 - char * (0.5 + 0.5 * noise.noise(w * 1.7))
            cs.append((colour[0] * k, colour[1] * k, colour[2] * k, 1.0))
        face(p, [mp[v] for v in f.verts], cs)
    tmp.free()


def tube(p, pts, r, colour, seg=7, char=0.0):
    rings = []
    for i, q in enumerate(pts):
        d = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        u = d.cross(Vector((0, 0, 1)))
        if u.length < 1e-3:
            u = d.cross(Vector((1, 0, 0)))
        u.normalize()
        w = d.cross(u)
        rr = r[i] if isinstance(r, list) else r
        rings.append([p.bm.verts.new(q + (u * math.cos(2 * math.pi * k / seg) + w * math.sin(2 * math.pi * k / seg)) * rr) for k in range(seg)])
    for i in range(len(rings) - 1):
        for k in range(seg):
            vs = [rings[i][k], rings[i][(k + 1) % seg], rings[i + 1][(k + 1) % seg], rings[i + 1][k]]
            cs = []
            for v in vs:
                kk = 1.0 - char * (0.5 + 0.5 * noise.noise(v.co * 2.3))
                cs.append((colour[0] * kk, colour[1] * kk, colour[2] * kk, 1.0))
            face(p, vs, cs, [(k / seg, i * 0.5)] * 4)


def dome(p, R, H, seed, colour_fn, rings=12, seg=36, vents=0):
    """A low dome (a clamp, a mound): turf lumps, cracks, vents round the foot."""
    grid = []
    for j in range(rings + 1):
        t = j / rings
        row = []
        for k in range(seg):
            a = 2 * math.pi * k / seg
            r = R * math.sin(t * math.pi * 0.5) if j > 0 else 0.0
            r = R * (1.0 - t) if False else R * math.cos(t * math.pi * 0.5)
            z = H * math.sin(t * math.pi * 0.5) ** 0.9
            lump = 0.06 * R * noise.noise(Vector((math.cos(a) * 2, math.sin(a) * 2, t * 3 + seed)))
            vent = 0.0
            if vents and t < 0.25:
                vent = -0.25 * max(0.0, math.cos(a * vents)) ** 8 * (1.0 - t / 0.25)
            rr = r + lump + vent * R * 0.3
            row.append(p.bm.verts.new((math.cos(a) * rr, math.sin(a) * rr, z + lump * 0.5 - 0.2)))
        grid.append(row)
    top = p.bm.verts.new((0, 0, H - 0.15))
    for j in range(rings):
        for k in range(seg):
            vs = [grid[j][k], grid[j][(k + 1) % seg], grid[j + 1][(k + 1) % seg], grid[j + 1][k]]
            face(p, vs, [colour_fn(v.co) for v in vs])
    for k in range(seg):
        vs = [grid[rings][k], grid[rings][(k + 1) % seg], top]
        face(p, vs, [colour_fn(v.co) for v in vs])


def clamp():
    earth = Part()
    R, H = 2.6, 1.9
    def col(w):
        n = noise.noise(w * 1.3)
        crown = sstep(1.1, 1.8, w.z)
        c = (0.24 + 0.06 * n, 0.22 + 0.05 * n, 0.17 + 0.04 * n)
        turf = sstep(0.0, 0.5, noise.noise(w * 0.7 + Vector((4, 0, 0)))) * (1.0 - crown) * 0.6
        c = [c[i] * (1 - turf) + (0.2, 0.25, 0.14)[i] * turf for i in range(3)]
        c = [c[i] * (1 - crown * 0.7) for i in range(3)]
        return (c[0], c[1], c[2], 1.0)
    dome(earth, R, H, 3, col, vents=7)
    # the stacked billets showing at the vents
    wood = Part()
    for k in range(7):
        a = 2 * math.pi * k / 7
        for i in range(3):
            q = Vector((math.cos(a) * (R - 0.25), math.sin(a) * (R - 0.25), 0.12 + i * 0.13))
            d = Vector((math.cos(a), math.sin(a), 0.0))
            tube(wood, [q - d * 0.35, q + d * 0.2], 0.07, (0.14, 0.1, 0.08, 1.0), seg=6, char=0.5)
    return [("Clamp", "daub", earth), ("Clamp", "timber", wood)]


def hut():
    wood = Part()
    stone = Part()
    w, d = 4.6, 3.6
    for sx in (-1, 1):
        for sy in (-1, 1):
            h = rnd.uniform(1.4, 2.6)
            box(wood, (sx * w / 2, sy * d / 2, h / 2), (0.24, 0.24, h), tilt=(rnd.uniform(-0.08, 0.08), rnd.uniform(-0.08, 0.08), 0), colour=(0.16, 0.12, 0.1, 1), warp=0.03, seed=sx + sy * 3, char=0.6)
    # the sill beams, burned through in places
    for sy in (-1, 1):
        box(wood, (0, sy * d / 2, 0.12), (w * 0.85, 0.2, 0.18), colour=(0.14, 0.1, 0.08, 1), warp=0.02, char=0.6)
    box(wood, (-w / 2, 0, 0.12), (0.2, d * 0.6, 0.18), colour=(0.14, 0.1, 0.08, 1), char=0.6)
    # the hearth and chimney at the back, still standing
    z = 0.0
    k = 0
    while z < 3.6:
        ch = rnd.uniform(0.22, 0.34)
        wd = 1.3 if z < 1.0 else 0.8
        for i in range(3):
            box(stone, (w / 2 - 0.4 + (i - 1) * wd * 0.33, 0.0 + rnd.uniform(-0.03, 0.03), z + ch / 2), (wd * 0.32, 0.9 if z < 1.0 else 0.65, ch - 0.02),
                colour=(0.42, 0.4, 0.37, 1), warp=0.04, seed=k * 3 + i, char=0.35 if z > 0.6 else 0.6)
        z += ch
        k += 1
    # the roof fallen in: rafters and the ridge pole lying across the floor
    for i in range(6):
        a = Vector((rnd.uniform(-w / 2, w / 2), -d / 2 + rnd.uniform(-0.3, 0.3), rnd.uniform(0.1, 0.9)))
        b = Vector((a.x + rnd.uniform(-1.0, 1.0), d / 2 + rnd.uniform(-0.3, 0.6), rnd.uniform(0.05, 0.4)))
        tube(wood, [a, b], 0.08, (0.13, 0.1, 0.08, 1), seg=6, char=0.7)
    tube(wood, [Vector((-w / 2 - 0.3, 0.2, 0.9)), Vector((w / 2 - 0.6, -0.1, 0.25))], 0.12, (0.13, 0.1, 0.08, 1), seg=7, char=0.7)
    return [("Hut", "timber", wood), ("Hut", "hewn", stone)]


def cart():
    wood = Part()
    tilt = math.radians(14)
    m = Matrix.Rotation(tilt, 4, 'Y')
    def T(v):
        return m @ Vector(v)
    # the bed
    for i in range(7):
        y = -0.9 + i * 0.3
        a, b = T((-1.3, y, 0.95)), T((1.3, y, 0.95))
        tube(wood, [a, b], 0.06, (0.36, 0.28, 0.2, 1), seg=4)
    for sy in (-1, 1):
        tube(wood, [T((-1.3, sy * 1.0, 1.2)), T((1.3, sy * 1.0, 1.2))], 0.07, (0.32, 0.25, 0.18, 1), seg=5)
        tube(wood, [T((1.3, sy * 0.6, 0.95)), T((3.4, sy * 0.4, 0.95)), Vector((3.6, sy * 0.4, 0.1))], 0.06, (0.32, 0.25, 0.18, 1), seg=5)
    # wheels: rim, hub, spokes
    for sy in (-1, 1):
        c = T((0.0, sy * 1.15, 0.0)) + Vector((0, 0, 0.78))
        rim = [c + Vector((math.cos(2 * math.pi * k / 18) * 0.78, 0.0, math.sin(2 * math.pi * k / 18) * 0.78)) for k in range(19)]
        tube(wood, rim, 0.05, (0.3, 0.23, 0.17, 1), seg=5)
        for k in range(8):
            a = 2 * math.pi * k / 8
            tube(wood, [c, c + Vector((math.cos(a) * 0.74, 0.0, math.sin(a) * 0.74))], 0.03, (0.3, 0.23, 0.17, 1), seg=4)
        tube(wood, [c - Vector((0, 0.12, 0)), c + Vector((0, 0.12, 0))], 0.1, (0.26, 0.2, 0.15, 1), seg=6)
    # a spill of charcoal off the bed
    for i in range(14):
        box(wood, (rnd.uniform(-2.2, -1.2), rnd.uniform(-0.8, 0.8), 0.06), (0.25, 0.12, 0.1), yaw=rnd.uniform(0, 3), colour=(0.06, 0.06, 0.06, 1))
    return [("Cart", "timber", wood)]


def hollow():
    earth = Part()
    wood = Part()
    stone = Part()
    thatch = Part()
    glow = Part()
    bark = (0.38, 0.32, 0.27, 1.0)
    # the fallen trunk, running away (Blender +X) from the root plate, its far end lost in the wood: bark in deep ridges,
    # snapped branch stubs
    n = 24
    seg = 22
    rings = []
    for i in range(n + 1):
        t = i / n
        c = Vector((1.0 + t * 22.0, 0.4 * math.sin(t * 3.0), 2.7 - 0.6 * t))
        r = 2.4 - 0.9 * t
        ring = []
        for k in range(seg):
            a = 2 * math.pi * k / seg
            ridge = 0.09 * abs(math.sin(a * 11.0 + 0.6 * noise.noise(Vector((t * 8.0, a, 1.0)))))
            rr = r * (1.0 + ridge + 0.05 * noise.noise(Vector((t * 4.0, math.cos(a), math.sin(a)))))
            ring.append(wood.bm.verts.new(c + Vector((0.0, math.cos(a) * rr, math.sin(a) * rr))))
        rings.append(ring)
    for i in range(n):
        for k in range(seg):
            vs = [rings[i][k], rings[i][(k + 1) % seg], rings[i + 1][(k + 1) % seg], rings[i + 1][k]]
            cs = []
            for v in vs:
                m = sstep(0.2, 0.8, noise.noise(v.co * 0.4 + Vector((2, 0, 0))) + 0.3) * max(0.0, (v.co.z - 2.0) / 2.5)
                cs.append((bark[0] * (1 - m) + 0.2 * m, bark[1] * (1 - m) + 0.27 * m, bark[2] * (1 - m) + 0.14 * m, 1.0))
            face(wood, vs, cs, [(k / seg * 3.0, i * 0.5)] * 4)
    for b in range(5):
        t = 0.2 + 0.15 * b
        c = Vector((1.0 + t * 22.0, 0.0, 2.7 - 0.6 * t))
        a = rnd.uniform(0.3, 2.8) * (1 if b % 2 else -1)
        d = Vector((rnd.uniform(-0.2, 0.3), math.cos(a), abs(math.sin(a)) + 0.2)).normalized()
        r0 = rnd.uniform(0.35, 0.6)
        tube(wood, [c + d * (2.0 - 0.9 * t), c + d * (3.4 - 0.9 * t + rnd.uniform(0, 1.5))], [r0, r0 * 0.6], bark, seg=8)
    # the root plate on edge: a disc of earth held in the roots, facing -X
    seg = 32
    R = 5.6
    ctr = Vector((0.0, 0.0, 3.6))
    def earth_col(w):
        n = noise.noise(w * 0.9)
        return (0.36 + 0.07 * n, 0.3 + 0.06 * n, 0.23 + 0.05 * n, 1.0)
    rings = []
    for j in range(5):
        rr = R * (j / 4.0)
        ring = []
        for k in range(seg):
            a = 2 * math.pi * k / seg
            rag = (0.9 * noise.noise(Vector((math.cos(a) * 2.5, math.sin(a) * 2.5, 7.0))) + 0.4 * noise.noise(Vector((math.cos(a) * 6, math.sin(a) * 6, 2.0)))) if j >= 3 else 0.0
            off = -0.8 * (1.0 - (j / 4.0) ** 2) + 0.25 * noise.noise(Vector((a, j, 2.0)))
            ring.append(earth.bm.verts.new(ctr + Vector((off, math.cos(a) * (rr + rag), math.sin(a) * (rr + rag) * 0.75))))
        rings.append(ring)
    for j in range(4):
        for k in range(seg):
            vs = [rings[j][k], rings[j + 1][k], rings[j + 1][(k + 1) % seg], rings[j][(k + 1) % seg]]
            face(earth, vs, [earth_col(v.co) for v in vs])
    # roots: a fan of them out of the plate's rim and face, each a tapering curve that arches out and down into the
    # ground, splitting into rootlets; the big ones over the hut make its rafters
    def root(start, out, drop, r0, depth):
        pts = []
        rs = []
        for i in range(7):
            t = i / 6.0
            q = start + out * t + Vector((0, 0, math.sin(t * math.pi) * drop * 0.35 - (start.z + 0.3) * t * t))
            q += Vector((noise.noise(q * 0.5), noise.noise(q * 0.5 + Vector((3, 0, 0))), 0.0)) * 0.3 * t
            pts.append(q)
            rs.append(r0 * (1.0 - 0.85 * t) + 0.03)
        tube(wood, pts, rs, (0.36, 0.3, 0.24, 1.0), seg=7 if r0 > 0.2 else 5)
        if depth > 0:
            for k in range(2):
                i = rnd.randint(2, 4)
                d = (pts[i + 1] - pts[i]).normalized()
                side = d.cross(Vector((0, 0, 1))).normalized() * rnd.choice((-1, 1))
                root(pts[i], (d + side * 0.8) * rnd.uniform(1.2, 2.4), drop * 0.4, rs[i] * 0.6, depth - 1)
    # in the plate's own plane: roots torn off round its rim, gnarled (each curls along the rim as it goes out and wanders),
    # blunt where they tore, uneven; the lowest ones trailing on the ground; thin rootlets in tangles; stubs on its face;
    # three big roots arching off it over the hut
    def gnarl(start, rad, tang, ln, r0, steps=7, sag=0.0):
        pts = []
        rs = []
        d = rad.normalized()
        q = start.copy()
        curl = rnd.uniform(-0.5, 0.5)
        for i in range(steps):
            t = i / (steps - 1)
            pts.append(q.copy())
            rs.append(max(0.05, r0 * (1.0 - 0.7 * t)))
            d = (d + tang * curl * 0.35 + Vector((noise.noise(q * 0.8), noise.noise(q * 0.8 + Vector((5, 0, 0))), noise.noise(q * 0.8 + Vector((0, 5, 0))))) * 0.35).normalized()
            q = q + d * (ln / (steps - 1)) + Vector((0, 0, -sag * t))
        tube(wood, pts, rs, (0.34, 0.28, 0.23, 1.0), seg=6)
    k = 0
    a = 0.0
    while a < 2 * math.pi:
        a += rnd.uniform(0.18, 0.5)
        rad = Vector((0.0, math.cos(a), math.sin(a) * 0.75))
        tang = Vector((0.0, -math.sin(a), math.cos(a) * 0.75)).normalized()
        start = ctr + rad * R * rnd.uniform(0.7, 0.95) + Vector((-0.35, 0, 0))
        low = start.z < 2.2
        big = rnd.random() < 0.35
        gnarl(start, rad + Vector((-0.4 if low else -0.1, 0, 0)), tang, rnd.uniform(2.5, 5.0) if low else rnd.uniform(0.9, 2.6) * (1.6 if big else 1.0),
              rnd.uniform(0.22, 0.34) if big else rnd.uniform(0.09, 0.17), sag=0.8 if low else 0.25)
        for t in range(rnd.randint(1, 3)):
            gnarl(start + rad * rnd.uniform(0.2, 0.8), rad + tang * rnd.uniform(-0.8, 0.8), tang, rnd.uniform(0.6, 1.5), 0.05, steps=5, sag=0.2)
        k += 1
    # soil still clinging in the roots: clods on the plate's face
    for i in range(18):
        aa = rnd.uniform(0, 2 * math.pi)
        rr = rnd.uniform(0.6, 4.8)
        box(earth, ctr + Vector((-0.75 - rnd.uniform(0, 0.4), math.cos(aa) * rr, math.sin(aa) * rr * 0.75)), (rnd.uniform(0.4, 0.9), rnd.uniform(0.5, 1.1), rnd.uniform(0.4, 0.9)),
            yaw=rnd.uniform(0, 3), colour=(0.36, 0.3, 0.23, 1), warp=0.15, seed=i)
    for i in range(14):
        aa = rnd.uniform(0, 2 * math.pi)
        rr = rnd.uniform(0.5, 4.4)
        p0 = ctr + Vector((-0.75, math.cos(aa) * rr, math.sin(aa) * rr * 0.75))
        gnarl(p0, Vector((-1.0, rnd.uniform(-0.4, 0.4), rnd.uniform(-0.5, 0.1))), Vector((0, 1, 0)), rnd.uniform(0.4, 1.2), rnd.uniform(0.07, 0.16), steps=4, sag=0.2)
    for yy in (-1.6, 0.2, 1.8):
        root(ctr + Vector((-0.7, yy, 1.6)), Vector((-6.2, yy * 0.4, 0.0)), 2.2, 0.38, 0)
    # the hut against the plate's face: plank walls, a turf-and-thatch roof, a door, a lit window, a stone chimney
    hx, hw, hd, hh = -3.2, 4.2, 3.4, 2.4
    for i in range(int(hw / 0.32)):
        y = -hw / 2 + i * 0.32 + 0.16
        box(wood, (hx - hd / 2, y, hh / 2), (0.08, 0.3, hh + rnd.uniform(-0.1, 0.15)), colour=(0.32, 0.25, 0.18, 1), warp=0.01, seed=i)
    for sy in (-1, 1):
        for i in range(int(hd / 0.32)):
            x = hx - hd / 2 + i * 0.32 + 0.16
            box(wood, (x, sy * hw / 2, hh / 2), (0.3, 0.08, hh), colour=(0.3, 0.24, 0.17, 1), seed=i + 40)
    # door (dark planks, set in) and window (lit panes, wax set)
    box(wood, (hx - hd / 2 - 0.05, -0.8, 0.95), (0.06, 0.9, 1.9), colour=(0.18, 0.13, 0.1, 1))
    box(glow, (hx - hd / 2 - 0.06, 0.9, 1.4), (0.04, 0.6, 0.5), colour=(1.0, 0.6, 0.3, 1))
    box(wood, (hx - hd / 2 - 0.08, 0.9, 1.4), (0.05, 0.06, 0.55), colour=(0.2, 0.15, 0.1, 1))
    box(wood, (hx - hd / 2 - 0.08, 0.9, 1.4), (0.05, 0.62, 0.05), colour=(0.2, 0.15, 0.1, 1))
    # roof: two pitched slabs of thatch, the back edge tucked under the roots
    for sy in (-1, 1):
        tmp = [Vector((hx - hd / 2 - 0.5, 0.0, hh + 1.3)), Vector((hx + hd / 2 + 0.3, 0.0, hh + 1.3)),
               Vector((hx + hd / 2 + 0.3, sy * (hw / 2 + 0.5), hh - 0.1)), Vector((hx - hd / 2 - 0.5, sy * (hw / 2 + 0.5), hh - 0.1))]
        vs = [thatch.bm.verts.new(v) for v in tmp]
        face(thatch, vs if sy > 0 else list(reversed(vs)), (0.34, 0.3, 0.2, 1))
        for k, t in enumerate((0.0, 0.33, 0.66)):
            a = tmp[0].lerp(tmp[3], t)
            b = tmp[1].lerp(tmp[2], t)
            tube(thatch, [a + Vector((0, 0, 0.12)), b + Vector((0, 0, 0.12))], 0.07, (0.3, 0.27, 0.18, 1), seg=5)
    # chimney of stacked stones beside the plate
    z = 0.0
    k = 0
    while z < hh + 2.0:
        ch = rnd.uniform(0.22, 0.32)
        box(stone, (hx + hd / 2 - 0.3, hw / 2 - 0.5, z + ch / 2), (0.7, 0.7, ch - 0.02), yaw=rnd.uniform(-0.1, 0.1), colour=(0.42, 0.4, 0.36, 1), warp=0.05, seed=k)
        z += ch
        k += 1
    return [("Hollow", "daub", earth), ("Hollow", "timber", wood), ("Hollow", "hewn", stone), ("Hollow", "thatch", thatch), ("Hollow", "wax", glow)]


def colliders():
    out = []
    def boxes(name, items):
        p = Part()
        for (c, s) in items:
            box(p, c, s)
        out.append((name, p))
    boxes("Clamp", [((0, 0, 0.6), (4.4, 4.4, 1.2)), ((0, 0, 1.4), (2.6, 2.6, 0.8))])
    boxes("Hut", [((2.3 - 0.4, 0, 1.8), (1.3, 0.9, 3.6))])
    boxes("Cart", [((0.0, 0.0, 0.8), (2.6, 2.3, 0.9))])
    boxes("Hollow", [((-0.6, 0.0, 3.6), (1.4, 11.0, 8.0)), ((11.0, 0.0, 2.6), (20.0, 4.0, 4.4)), ((-3.2, 0.0, 1.3), (3.4, 4.2, 2.6))])
    return out


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


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    objs = []
    for fn in (clamp, hut, cart, hollow):
        for (piece, set_name, part) in fn():
            bmesh.ops.recalc_face_normals(part.bm, faces=part.bm.faces[:])
            objs.append(mk(part.bm, "%s__%s" % (piece, set_name), set_name in ("daub",)))
    for (piece, p) in colliders():
        objs.append(mk(p.bm, piece + "-colonly", False))
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    kw = dict(filepath=os.path.join(OUT, "vista_southwood.glb"), export_format='GLB', use_selection=True, export_apply=True, export_yup=True,
              export_materials='NONE', export_normals=True, export_texcoords=True, export_tangents=True)
    try:
        bpy.ops.export_scene.gltf(export_vertex_color='ACTIVE', **kw)
    except TypeError:
        bpy.ops.export_scene.gltf(**kw)
    print("EXPORTED", sum(tris(o) for o in objs if "colonly" not in o.name), "tris")
    if PREVIEW:
        os.makedirs(PREVIEW, exist_ok=True)
        place = {"Clamp": (0, 0), "Hut": (8, 2), "Cart": (4, -6), "Hollow": (-14, 12)}
        for o in objs:
            key = o.name.split("__")[0].split("-")[0]
            x, y = place[key]
            o.matrix_world = Matrix.Translation((x, y, 0))
            if "colonly" in o.name:
                o.hide_render = True
        sc = bpy.context.scene
        sc.render.engine = 'CYCLES'
        sc.cycles.device = 'CPU'
        sc.cycles.samples = 28
        sc.cycles.use_denoising = True
        sc.render.resolution_x, sc.render.resolution_y = 1400, 900
        sc.world = bpy.data.worlds.new("w")
        sc.world.use_nodes = True
        sc.world.node_tree.nodes["Background"].inputs[0].default_value = (0.06, 0.07, 0.12, 1)
        for o in objs:
            m = bpy.data.materials.new("pv")
            m.use_nodes = True
            nt = m.node_tree
            vc = nt.nodes.new("ShaderNodeVertexColor")
            vc.layer_name = "Col"
            bs = nt.nodes["Principled BSDF"]
            nt.links.new(vc.outputs[0], bs.inputs["Base Color"])
            if o.name.endswith("__wax"):
                nt.links.new(vc.outputs[0], bs.inputs["Emission Color"])
                bs.inputs["Emission Strength"].default_value = 3.0
            o.data.materials.append(m)
        bpy.ops.mesh.primitive_plane_add(size=80, location=(0, 0, 0))
        ld = bpy.data.lights.new("moon", 'SUN')
        ld.energy = 3.2
        ld.color = (0.62, 0.72, 1.0)
        lo = bpy.data.objects.new("moon", ld)
        lo.rotation_euler = (math.radians(46), 0, math.radians(30))
        sc.collection.objects.link(lo)
        cd = bpy.data.cameras.new("cam")
        cam = bpy.data.objects.new("cam", cd)
        sc.collection.objects.link(cam)
        sc.camera = cam
        for name, loc, tgt, lens in (("burners", (14, -14, 6), (4, 0, 1), 26), ("hollow", (-30, 2, 6), (-14, 12, 3), 26)):
            cam.location = Vector(loc)
            cam.rotation_euler = (Vector(tgt) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
            cd.lens = lens
            sc.render.filepath = os.path.join(PREVIEW, "sw_%s.png" % name)
            bpy.ops.render.render(write_still=True)


main()
