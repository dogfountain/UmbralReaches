"""THE MARCH BEACONS: the Order's signal towers on the high ground at the edge of the Marches, one in sight of the next,
looking out over the Far Reaches. When the sky went dark they went out. A round tower of coursed rubble on a battered
foot, its stones laid one by one (each its own face, proud of a recessed mortar joint), a stair of cantilevered slabs
winding up the outside to a corbelled parapet with a broken merlon, an iron fire-basket on a stone drum at the top
(the wanderer kindles it), a timber hoist arm over the parapet with its pulley, a walled-up door at the foot with the
Order's star cut over it. Modelled by script (no scans, no downloads).

  tools/blender/run.sh vista_beacon.py -- [--preview DIR] [--seed 3]

Exports (art/models/):
  vista_beacon.glb      Tower__hewn (shell, parapet, corbels, floor, stair: the stones are geometry, the tiling hewn set is
                        their grain), Mortar__hewn (the dark core behind the joints), Basket__iron, Hoist__timber,
                        Logs__timber, Beacon-colonly (shaft, stair treads, floor, parapet: walkable)
  vista_beacon_far.glb  ~260 triangle far mesh (BeaconFar__hewn)
Vertex colour carries each stone's tone, the joints' shade, moss low on the north face and soot under the basket.

Frame: Blender Z up -> Godot Y up, Blender +Y -> Godot -Z. 1 BU = 1 m. Origin = the tower's axis at the ground.
The stair starts on the south side (Godot +Z, Blender -Y) and climbs clockwise seen from above.
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


def arg(name, default=""):
    if name in args:
        i = args.index(name)
        return args[i + 1] if i + 1 < len(args) else default
    return default


PREVIEW = arg("--preview")
SEED = int(arg("--seed", "3"))
rnd = random.Random(SEED)

FOOT = -1.4             # the buried skirt (the tower stands on sloped ground)
TOP = 20.2              # the shaft's top: the corbels start here (it stands over the downs' woods)
FLOOR = 20.9            # the platform
PAR_H = 1.05            # the parapet over the floor
STEP_RISE = 0.3
STAIR_Z0 = 0.35         # the first tread (over the ground at the axis)
STAIR_W = 1.15          # how far a tread stands out from the wall
TURNS = 2.05


def lerp(a, b, t):
    return a + (b - a) * t


def sstep(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3.0 - 2.0 * t)


def radius(z):
    """The shaft's outer radius: a battered foot that curves into a gently tapering shaft."""
    foot = 3.35 - 0.62 * sstep(-0.2, 3.0, z)
    return foot - 0.5 * max(0.0, z - 2.4) / (TOP - 2.4)


# ============================================================================================ stones

def course_table():
    """[(z0, z1, [joint angles]), ...] from the buried skirt to TOP. Lower courses are bigger stones."""
    out = []
    z = FOOT
    while z < TOP - 0.05:
        big = z < 2.4
        roll = rnd.random()
        if big:
            h = rnd.uniform(0.46, 0.64)
        elif roll < 0.14:
            h = rnd.uniform(0.15, 0.21)                   # a levelling course of thin stones
        elif roll < 0.3:
            h = rnd.uniform(0.5, 0.62)
        else:
            h = rnd.uniform(0.3, 0.46)
        if z + h > TOP - 0.18:
            h = TOP - z
        r = radius(z + h * 0.5)
        circ = 2.0 * math.pi * r
        joints = []
        a = rnd.uniform(0.0, 2.0 * math.pi)
        acc = 0.0
        while acc < circ - 0.4:
            if big:
                ln = rnd.uniform(0.8, 1.45)
            elif h < 0.22:
                ln = rnd.uniform(0.35, 0.8)
            else:
                ln = rnd.uniform(0.4, 1.0) if rnd.random() < 0.9 else rnd.uniform(1.2, 1.6)
            joints.append((a + acc / r) % (2.0 * math.pi))
            acc += ln
        joints.sort()
        out.append((z, z + h, joints))
        z += h
    return out


def stone_params(ci, k):
    """Per stone: (proud m, tone, tilt) from a hash of course and index (stable across rebuilds)."""
    h = random.Random(ci * 7919 + k * 104729 + SEED)
    return (h.uniform(0.045, 0.1), h.uniform(-1.0, 1.0), h.uniform(-0.6, 0.6), h.random())


MORTAR = 0.03


def band(bm, col_l, uv_l, ci, z0, z1, joints, rad_fn, seam=True):
    """One course: its stones laid round the shaft as a strip, each with pillowed edges proud of the joint."""
    n = len(joints)
    cols = []          # (angle, stone k, s along stone, stone length)
    for k in range(n):
        a0 = joints[k]
        a1 = joints[(k + 1) % n] + (2.0 * math.pi if k == n - 1 else 0.0)
        r = rad_fn(0.5 * (z0 + z1))
        ln = (a1 - a0) * r
        ss = [0.0, 0.05]
        mid = 0.05
        while mid + 0.55 < ln - 0.05:
            mid += 0.48
            ss.append(mid)
        ss += [ln - 0.05]
        ss = sorted(set(round(s, 4) for s in ss if 0.0 <= s < ln))
        for s in ss:
            cols.append((a0 + s / r, k, s, ln))
    hgt = z1 - z0
    mids = [hgt * 0.5] if hgt > 0.3 else []
    ts = sorted(set([0.0, min(0.05, hgt * 0.3)] + mids + [hgt - min(0.05, hgt * 0.3), hgt]))
    ts = [t for t in ts if 0.0 <= t <= hgt]
    grid = []
    for (ang, k, s, ln) in cols + [(cols[0][0] + 2.0 * math.pi, cols[0][1], cols[0][2], cols[0][3])]:
        prm = stone_params(ci, k)
        row = []
        for t in ts:
            z = z0 + t
            es = min(s, ln - s)
            et = min(t, hgt - t)
            e = min(es, et)
            if s == 0.0 or t == 0.0 or t == hgt:
                e = 0.0
            pill = sstep(0.0, 0.05, e)
            d = prm[0] * 0.7 * pill - 0.032 * (1.0 - pill)
            d += pill * 0.03 * prm[2] * ((s / ln) - 0.5)       # one end of the stone sits proud
            # the face is not flat: a hand-dressed stone has hollows and a tilt
            p = Vector((math.cos(ang) * 2.0, math.sin(ang) * 2.0, z * 1.3))
            d += pill * (0.016 * noise.noise(p * 1.7 + Vector((ci, k, 0))) + 0.008 * noise.noise(p * 5.1))
            d += pill * 0.012 * prm[2] * ((t / hgt) - 0.5)
            r = rad_fn(z) + d
            v = bm.verts.new((math.cos(ang) * r, math.sin(ang) * r, z))
            row.append((v, prm, pill, ang, z))
        grid.append(row)
    for i in range(len(grid) - 1):
        for j in range(len(ts) - 1):
            a, b, c, d = grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1]
            if a[0] is b[0]:
                continue
            f = bm.faces.new((a[0], b[0], c[0], d[0]))
            for l, src in zip(f.loops, (a, b, c, d)):
                v, prm, pill, ang, z = src
                l[uv_l].uv = (ang * radius(z) / 3.0, z / 3.0)
                l[col_l] = stone_colour(prm, pill, ang, z)
    return len(grid) * len(ts)


def stone_colour(prm, pill, ang, z):
    """A stone's tone (grey to warm buff), darker joints, moss low on the north (Blender +Y = Godot -Z) and
    on the up-facing lips, soot streaking down from the basket."""
    tone = 0.72 + 0.14 * prm[1]
    fam = prm[3]
    if fam < 0.45:
        c = [tone * 0.9, tone * 0.93, tone * 1.0]           # blue-grey
    elif fam < 0.8:
        c = [tone * 1.04, tone * 0.98, tone * 0.86]         # buff
    else:
        c = [tone * 0.86, tone * 0.8, tone * 0.74]          # a darker, iron-stained stone
    joint = 1.0 - pill
    for i in range(3):
        c[i] *= lerp(1.0, 0.42, joint)
    north = max(0.0, math.sin(ang))
    moss = sstep(6.0, 0.0, z) * (0.35 + 0.65 * north) * (0.55 + 0.45 * noise.noise(Vector((ang * 3.0, z * 0.8, 1.0))))
    moss = max(0.0, min(1.0, moss * 0.8))
    mc = (0.42, 0.5, 0.3)
    for i in range(3):
        c[i] = lerp(c[i], mc[i] * tone, moss * 0.65)
    # rain streaks from the corbels down, and soot from the basket on the lee side
    streak = sstep(TOP - 6.0, TOP, z) * max(0.0, noise.noise(Vector((ang * 14.0, 0.7, z * 0.08))) * 1.6)
    soot = sstep(TOP - 3.0, TOP + 0.5, z) * (0.5 + 0.5 * noise.noise(Vector((ang * 6.0, 0.3, z * 0.2))))
    dark = max(0.0, min(1.0, 0.45 * streak + 0.5 * soot))
    for i in range(3):
        c[i] *= lerp(1.0, 0.5, dark)
    # lichen: pale rosettes on the stone faces, more on the weather side
    lic = noise.noise(Vector((ang * 9.0, z * 2.4, 3.0))) * 0.5 + 0.5
    lic = sstep(0.68, 0.8, lic) * pill * (0.4 + 0.6 * max(0.0, -math.cos(ang)))
    lc = (0.86, 0.85, 0.72)
    for i in range(3):
        c[i] = lerp(c[i], lc[i], lic * 0.55)
    return (min(c[0], 1.0), min(c[1], 1.0), min(c[2], 1.0), 1.0)


def new_bm():
    bm = bmesh.new()
    col = bm.loops.layers.color.new("Col")
    uv = bm.loops.layers.uv.new("UVMap")
    return bm, col, uv


def box(bm, col, uv, c, size, yaw=0.0, tone=0.78, bevel=0.035, warp=0.0, seed=0, colour=None):
    """A dressed block: chamfered edges, a slightly irregular face; metric UVs and a vertex tone."""
    tmp = bmesh.new()
    bmesh.ops.create_cube(tmp, size=1.0)
    for v in tmp.verts:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
    if bevel > 0.0:
        bmesh.ops.bevel(tmp, geom=list(tmp.edges), offset=bevel, segments=1, affect='EDGES')
    if warp > 0.0:
        for v in tmp.verts:
            v.co += Vector((noise.noise(v.co * 2.3 + Vector((seed, 0, 0))), noise.noise(v.co * 2.3 + Vector((0, seed, 0))),
                            noise.noise(v.co * 2.3 + Vector((0, 0, seed))))) * warp
    m = Matrix.Translation(Vector(c)) @ Matrix.Rotation(yaw, 4, 'Z')
    mp = {}
    for v in tmp.verts:
        mp[v] = bm.verts.new(m @ v.co)
    tmp.normal_update()
    rot = Matrix.Rotation(yaw, 3, 'Z')
    for f in tmp.faces:
        nf = bm.faces.new([mp[v] for v in f.verts])
        n = rot @ f.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        for l, ol in zip(nf.loops, f.loops):
            w = m @ ol.vert.co
            l[uv].uv = (((w.y, w.z) if ax == 0 else (w.x, w.z) if ax == 1 else (w.x, w.y))[0] / 3.0,
                        ((w.y, w.z) if ax == 0 else (w.x, w.z) if ax == 1 else (w.x, w.y))[1] / 3.0)
            if colour is not None:
                l[col] = colour
            else:
                shade = 0.62 if n.z < -0.5 else 1.0
                l[col] = (tone * shade, tone * shade * 0.97, tone * shade * 0.92, 1.0)
    tmp.free()


def tube(bm, col, uv, pts, r, seg=6, colour=(0.55, 0.52, 0.5, 1.0)):
    """A bar along pts (iron)."""
    rings = []
    for i, p in enumerate(pts):
        a = pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]
        a.normalize()
        u = a.cross(Vector((0, 0, 1)))
        if u.length < 1e-3:
            u = a.cross(Vector((1, 0, 0)))
        u.normalize()
        w = a.cross(u)
        ring = []
        for k in range(seg):
            t = 2.0 * math.pi * k / seg
            ring.append(bm.verts.new(p + (u * math.cos(t) + w * math.sin(t)) * r))
        rings.append(ring)
    acc = [0.0]
    for i in range(1, len(pts)):
        acc.append(acc[-1] + (pts[i] - pts[i - 1]).length)
    for i in range(len(rings) - 1):
        for k in range(seg):
            f = bm.faces.new((rings[i][k], rings[i][(k + 1) % seg], rings[i + 1][(k + 1) % seg], rings[i + 1][k]))
            for j, l in enumerate(f.loops):
                kk = k + (1 if j in (1, 2) else 0)
                ii = i + (1 if j in (2, 3) else 0)
                l[uv].uv = (kk / seg * 2.0 * math.pi * r, acc[ii])
                l[col] = colour
    for ring in (rings[0], rings[-1]):
        f = bm.faces.new(ring if ring is rings[-1] else list(reversed(ring)))
        for l in f.loops:
            l[col] = colour
            l[uv].uv = (0.0, 0.0)


# ============================================================================================ the parts

def tower():
    bm, col, uv = new_bm()
    table = course_table()
    for ci, (z0, z1, joints) in enumerate(table):
        band(bm, col, uv, ci, z0, z1, joints, radius)
    # the corbel table: stepped brackets carrying the parapet out over the shaft
    rt = radius(TOP)
    n_corb = 22
    arr = stair_arrival_angle()
    for k in range(n_corb):
        a = 2.0 * math.pi * (k + 0.5) / n_corb
        if -1.0 < ang_diff(a, arr) < 0.2:
            continue                                                     # the stair's last treads pass here
        for step, (dz, out, h) in enumerate(((0.0, 0.22, 0.28), (0.28, 0.42, 0.24))):
            rr = rt + out * 0.5
            box(bm, col, uv, (math.cos(a) * rr, math.sin(a) * rr, TOP + dz + h * 0.5), (out + 0.25, 0.42, h), yaw=a,
                tone=0.72 + 0.06 * math.sin(k * 3.1), bevel=0.03, warp=0.012, seed=k)
    # the slab ring the corbels carry (the floor's edge), then the floor
    r_out = rt + 0.55
    ring_band(bm, col, uv, TOP + 0.52, FLOOR, rt - 0.2, r_out, 30, 0.74)
    # the parapet: two courses of blocks round the edge, crenels on the open side, one merlon broken off
    r_in = r_out - 0.42
    stair_gap = stair_arrival_angle()
    for course in range(3):
        z0 = FLOOR + course * 0.35
        nb = 26
        off = (course % 2) * 0.5
        for k in range(nb):
            a = 2.0 * math.pi * (k + off) / nb
            da = ang_diff(a, stair_gap)
            if abs(da) < 0.36:
                continue                                             # the stair arrives here
            crenel = course == 2 and (k % 3 == 1)
            broken = course >= 1 and ang_diff(a, stair_gap + 2.3) ** 2 < 0.09
            if crenel or broken:
                continue
            rr = 0.5 * (r_in + r_out)
            ln = 2.0 * math.pi * rr / nb - 0.035
            box(bm, col, uv, (math.cos(a) * rr, math.sin(a) * rr, z0 + 0.175), (0.42, ln, 0.33), yaw=a,
                tone=0.7 + 0.08 * math.sin(k * 1.7 + course), bevel=0.03, warp=0.014, seed=k * 3 + course)
    # copings on the merlons
    # the floor slab (stone flags) over the corbels
    disc(bm, col, uv, FLOOR, r_in + 0.02, 0.78)
    # the stair: cantilevered slabs from the wall, a kerb on every third
    for i, (a, z) in enumerate(stair_steps()):
        r = radius(z) if z < TOP else rt
        rr = r + STAIR_W * 0.5 - 0.05
        tread = 0.66
        box(bm, col, uv, (math.cos(a) * rr, math.sin(a) * rr, z - 0.12), (STAIR_W + 0.1, tread + 0.08, 0.24), yaw=a,
            tone=0.72 + 0.07 * math.sin(i * 2.3), bevel=0.03, warp=0.015, seed=i)
        if i % 2 == 0 and z > 1.2:
            rb = r + 0.22
            box(bm, col, uv, (math.cos(a) * rb, math.sin(a) * rb, z - 0.42), (0.5, 0.34, 0.36), yaw=a,
                tone=0.66 + 0.05 * math.sin(i), bevel=0.03, warp=0.012, seed=i + 90)
        if i % 3 == 1 and z > 1.5:
            ro = r + STAIR_W - 0.08
            box(bm, col, uv, (math.cos(a) * ro, math.sin(a) * ro, z + 0.09), (0.16, tread * 0.9, 0.22), yaw=a,
                tone=0.66, bevel=0.02, warp=0.01, seed=i + 50)
    # the walled-up door at the foot (north-east, away from the stair's start), the Order's star cut over it
    a = math.radians(55.0)
    for side in (-1, 1):
        for k in range(4):
            z = 0.28 + k * 0.5
            box(bm, col, uv, rotp(a, radius(z) + 0.05, side * 0.62, z), (0.3, 0.3 if k % 2 else 0.42, 0.47), yaw=a,
                tone=0.82, bevel=0.03, seed=7 + side + k * 3)
    box(bm, col, uv, rotp(a, radius(2.25) + 0.07, 0.0, 2.25), (0.34, 1.65, 0.36), yaw=a, tone=0.84, bevel=0.035, seed=9)
    for k in range(5):
        z = 0.3 + k * 0.38
        box(bm, col, uv, rotp(a, radius(z) - 0.02, rnd.uniform(-0.3, 0.3), z), (0.24, 0.46, 0.34), yaw=a,
            tone=0.6, bevel=0.03, warp=0.02, seed=20 + k)
    star(bm, col, uv, a, radius(2.25) + 0.25, 2.25)
    # a string course round the shaft at the stair's first turn, broken where the stair passes
    zs = 8.7
    steps_at = stair_steps()
    for k in range(40):
        a2 = 2.0 * math.pi * (k + 0.5) / 40
        if any(abs(ang_diff(a2, sa)) < 0.2 and abs(sz - zs) < 0.9 for (sa, sz) in steps_at):
            continue
        rr = radius(zs) + 0.09
        box(bm, col, uv, (math.cos(a2) * rr, math.sin(a2) * rr, zs), (0.26, 2 * math.pi * rr / 40 + 0.01, 0.2), yaw=a2,
            tone=0.8, bevel=0.03, seed=k + 700)
    # arrow slits: a dark recess in a surround of four dressed stones
    for (sa, sz) in ((math.radians(150.0), 5.6), (math.radians(-20.0), 11.2), (math.radians(95.0), 13.6)):
        rr = radius(sz)
        for (lat, dz, w, h) in ((-0.2, 0.0, 0.18, 1.0), (0.2, 0.0, 0.18, 1.0), (0.0, 0.6, 0.6, 0.2), (0.0, -0.6, 0.6, 0.2)):
            box(bm, col, uv, rotp(sa, rr + 0.04, lat, sz + dz), (0.2, w, h), yaw=sa, tone=0.82, bevel=0.025, seed=int(sz * 10 + lat * 10))
        box(bm, col, uv, rotp(sa, rr - 0.02, 0.0, sz), (0.12, 0.22, 1.0), yaw=sa, bevel=0.0, colour=(0.05, 0.05, 0.06, 1.0))
    bm.normal_update()
    return bm


def rotp(a, r, lateral, z):
    return (math.cos(a) * r - math.sin(a) * lateral, math.sin(a) * r + math.cos(a) * lateral, z)


def ang_diff(a, b):
    d = (a - b + math.pi) % (2.0 * math.pi) - math.pi
    return d


def stair_steps():
    """[(angle, tread top z)] from the first tread to the floor; it starts south (Blender -Y) and climbs clockwise."""
    n = int(round((FLOOR - STAIR_Z0) / STEP_RISE))
    a0 = -math.pi * 0.5
    out = []
    for i in range(n):
        z = STAIR_Z0 + (FLOOR - STAIR_Z0) * i / n
        a = a0 - 2.0 * math.pi * TURNS * i / n
        out.append((a, z))
    return out


def stair_arrival_angle():
    return -math.pi * 0.5 - 2.0 * math.pi * TURNS


def ring_band(bm, col, uv, z0, z1, ri, ro, n, tone):
    arr = stair_arrival_angle()
    for k in range(n):
        a = 2.0 * math.pi * (k + 0.5) / n
        if -1.0 < ang_diff(a, arr) < 0.2 and z0 < FLOOR - 0.3:
            continue
        rr = 0.5 * (ri + ro)
        ln = 2.0 * math.pi * ro / n + 0.02
        box(bm, col, uv, (math.cos(a) * rr, math.sin(a) * rr, 0.5 * (z0 + z1)), (ro - ri, ln, z1 - z0), yaw=a,
            tone=tone + 0.06 * math.sin(k * 2.9), bevel=0.025, warp=0.01, seed=k + 300)


def disc(bm, col, uv, z, r, tone):
    """Flagstones: rings of slabs over the floor (their tops at z)."""
    rings = [(0.0, 0.9, 1), (0.9, 1.75, 7), (1.75, r, 12)]
    for (r0, r1, n) in rings:
        for k in range(n):
            if n == 1:
                box(bm, col, uv, (0, 0, z - 0.1), (1.7, 1.7, 0.2), tone=tone, bevel=0.03, seed=400)
                continue
            a = 2.0 * math.pi * (k + 0.5) / n
            rr = 0.5 * (r0 + r1)
            ln = 2.0 * math.pi * r1 / n - 0.04
            box(bm, col, uv, (math.cos(a) * rr, math.sin(a) * rr, z - 0.1), (r1 - r0 - 0.04, ln, 0.2), yaw=a,
                tone=tone + 0.05 * math.sin(k * 3.3 + r0), bevel=0.025, warp=0.008, seed=k + int(r0 * 10))


def star(bm, col, uv, a, r, z):
    """The Order's seven-pointed star in relief on the lintel stone."""
    c = Vector(rotp(a, r, 0.0, z))
    out_n = Vector((math.cos(a), math.sin(a), 0.0))
    lat = Vector((-math.sin(a), math.cos(a), 0.0))
    up = Vector((0, 0, 1))
    ctr = bm.verts.new(c + out_n * 0.03)
    ring = []
    for k in range(14):
        t = 2.0 * math.pi * k / 14 + math.pi * 0.5
        rr = 0.15 if k % 2 == 0 else 0.06
        ring.append(bm.verts.new(c + lat * math.cos(t) * rr + up * math.sin(t) * rr))
    for k in range(14):
        f = bm.faces.new((ctr, ring[k], ring[(k + 1) % 14]))
        for l in f.loops:
            l[col] = (0.9, 0.88, 0.82, 1.0)
            l[uv].uv = (0.0, 0.0)


def mortar_core():
    """A dark core just behind the joints, so no crack between two courses ever shows the sky."""
    bm, col, uv = new_bm()
    seg = 48
    zs = [FOOT + (TOP + 0.4 - FOOT) * i / 16.0 for i in range(17)]
    rings = []
    for z in zs:
        r = radius(min(z, TOP)) - 0.03
        rings.append([bm.verts.new((math.cos(2 * math.pi * k / seg) * r, math.sin(2 * math.pi * k / seg) * r, z)) for k in range(seg)])
    for i in range(len(rings) - 1):
        for k in range(seg):
            f = bm.faces.new((rings[i][k], rings[i][(k + 1) % seg], rings[i + 1][(k + 1) % seg], rings[i + 1][k]))
            for l in f.loops:
                l[col] = (0.22, 0.21, 0.2, 1.0)
                l[uv].uv = (k / seg * 6.0, i * 0.3)
    bm.normal_update()
    return bm


def basket():
    """An iron fire-basket on a stone drum: curved bars from a foot ring flaring to a lip ring, a band at the waist, the
    bars' heads curled outward. Origin of its parts: the tower's axis; it stands at the floor's middle."""
    bm, col, uv = new_bm()
    iron = (0.5, 0.47, 0.45, 1.0)
    z0 = FLOOR + 0.62
    nb = 10
    for k in range(nb):
        a = 2.0 * math.pi * k / nb
        pts = []
        for i in range(9):
            t = i / 8.0
            r = lerp(0.42, 0.98, t ** 0.8)
            z = z0 + 1.15 * t
            pts.append(Vector((math.cos(a) * r, math.sin(a) * r, z)))
        # the curl over the lip
        for i in range(1, 5):
            t = i / 4.0
            r = 0.98 + 0.16 * math.sin(t * math.pi * 0.9)
            z = z0 + 1.15 + 0.18 * math.sin(t * math.pi) - 0.05 * t
            pts.append(Vector((math.cos(a) * r, math.sin(a) * r, z)))
        tube(bm, col, uv, pts, 0.032, seg=6, colour=iron)
    for (zr, rr) in ((z0, 0.42), (z0 + 0.55, 0.74), (z0 + 1.15, 0.98)):
        pts = [Vector((math.cos(2 * math.pi * k / 28) * rr, math.sin(2 * math.pi * k / 28) * rr, zr)) for k in range(29)]
        tube(bm, col, uv, pts, 0.04 if zr != z0 + 0.55 else 0.028, seg=6, colour=iron)
    # the grate across the foot
    for k in range(4):
        y = -0.3 + 0.2 * k
        tube(bm, col, uv, [Vector((-0.38, y, z0 + 0.04)), Vector((0.38, y, z0 + 0.04))], 0.025, seg=5, colour=iron)
    bm.normal_update()
    return bm


def drum():
    bm, col, uv = new_bm()
    for k in range(8):
        a = 2.0 * math.pi * (k + 0.5) / 8
        box(bm, col, uv, (math.cos(a) * 0.48, math.sin(a) * 0.48, FLOOR + 0.3), (0.42, 0.42, 0.6), yaw=a, tone=0.7, bevel=0.03,
            warp=0.01, seed=k + 600, colour=(0.56, 0.53, 0.5, 1.0))
    box(bm, col, uv, (0, 0, FLOOR + 0.3), (0.72, 0.72, 0.58), tone=0.5, bevel=0.0)
    bm.normal_update()
    return bm


def logs():
    """Charred logs laid in the basket (unlit: cold ash; the flame is the lamp's)."""
    bm, col, uv = new_bm()
    z = FLOOR + 0.62 + 0.18
    for k in range(5):
        a = rnd.uniform(0, math.pi)
        ln = rnd.uniform(0.9, 1.3)
        c = Vector((rnd.uniform(-0.15, 0.15), rnd.uniform(-0.15, 0.15), z + k * 0.09))
        d = Vector((math.cos(a), math.sin(a), rnd.uniform(-0.15, 0.25))).normalized()
        tube(bm, col, uv, [c - d * ln * 0.5, c, c + d * ln * 0.5], rnd.uniform(0.06, 0.09), seg=7, colour=(0.2, 0.17, 0.15, 1.0))
    bm.normal_update()
    return bm


def hoist():
    """A timber arm over the parapet on the open side, a pulley block and a rope down."""
    bm, col, uv = new_bm()
    a = stair_arrival_angle() + 2.3 + 0.55
    r0 = radius(TOP) - 0.6
    wood = (0.62, 0.52, 0.42, 1.0)
    base = Vector((math.cos(a) * r0, math.sin(a) * r0, FLOOR))
    up = base + Vector((0, 0, 1.4))
    out = Vector((math.cos(a) * (radius(TOP) + 1.7), math.sin(a) * (radius(TOP) + 1.7), FLOOR + 3.1))
    tube(bm, col, uv, [base, base.lerp(up, 0.5), up], 0.12, seg=6, colour=wood)
    tube(bm, col, uv, [base + (base - out).normalized() * -0.2, base.lerp(out, 0.5), out], 0.085, seg=6, colour=wood)
    tie = up
    tube(bm, col, uv, [tie, tie.lerp(out, 0.5), out], 0.02, seg=4, colour=(0.55, 0.48, 0.36, 1.0))
    box(bm, col, uv, (out.x, out.y, out.z - 0.22), (0.24, 0.16, 0.32), yaw=a, bevel=0.02, colour=(0.45, 0.38, 0.3, 1.0))
    tube(bm, col, uv, [out - Vector((0, 0, 0.35)), out - Vector((0, 0, 3.2)), out - Vector((0.05, 0.05, 6.0))], 0.018, seg=4,
         colour=(0.55, 0.48, 0.36, 1.0))
    bm.normal_update()
    return bm


def collision():
    """Walkable collision: the shaft (a 24-sided prism), each tread a slab, the floor, the parapet ring."""
    bm, col, uv = new_bm()
    seg = 24
    for (z0, z1) in ((FOOT, 2.6), (2.6, TOP + 0.5)):
        r0 = radius(max(z0, 0.0)) + 0.02
        r1 = radius(z1) + 0.02
        a = [bm.verts.new((math.cos(2 * math.pi * k / seg) * r0, math.sin(2 * math.pi * k / seg) * r0, z0)) for k in range(seg)]
        b = [bm.verts.new((math.cos(2 * math.pi * k / seg) * r1, math.sin(2 * math.pi * k / seg) * r1, z1)) for k in range(seg)]
        for k in range(seg):
            bm.faces.new((a[k], a[(k + 1) % seg], b[(k + 1) % seg], b[k]))
        bm.faces.new(list(reversed(a)))
        bm.faces.new(b)
    for (a, z) in stair_steps():
        r = radius(z) if z < TOP else radius(TOP)
        rr = r + STAIR_W * 0.5 - 0.05
        box(bm, col, uv, (math.cos(a) * rr, math.sin(a) * rr, z - 0.12), (STAIR_W + 0.2, 0.7, 0.24), yaw=a, bevel=0.0)
    rt = radius(TOP) + 0.55
    disc_c = [bm.verts.new((math.cos(2 * math.pi * k / seg) * rt, math.sin(2 * math.pi * k / seg) * rt, FLOOR)) for k in range(seg)]
    bm.faces.new(disc_c)
    gap = stair_arrival_angle()
    for k in range(seg):
        a = 2.0 * math.pi * (k + 0.5) / seg
        if abs(ang_diff(a, gap)) < 0.36:
            continue
        box(bm, col, uv, (math.cos(a) * (rt - 0.21), math.sin(a) * (rt - 0.21), FLOOR + 0.55), (0.42, 2 * math.pi * rt / seg, 1.1), yaw=a, bevel=0.0)
    box(bm, col, uv, (0, 0, FLOOR + 0.3), (0.9, 0.9, 0.6), bevel=0.0)
    bm.normal_update()
    return bm


def far():
    """The far mesh: the shaft as a 10-sided prism in four rings, the parapet's drum, the basket's cone."""
    bm, col, uv = new_bm()
    seg = 10
    zs = [FOOT, 0.4, 2.6, 9.0, TOP]
    tone = (0.7, 0.68, 0.64, 1.0)
    rings = [[bm.verts.new((math.cos(2 * math.pi * k / seg) * radius(z), math.sin(2 * math.pi * k / seg) * radius(z), z)) for k in range(seg)] for z in zs]
    rp = radius(TOP) + 0.55
    for z in (TOP + 0.25, FLOOR + PAR_H):
        rings.append([bm.verts.new((math.cos(2 * math.pi * k / seg) * rp, math.sin(2 * math.pi * k / seg) * rp, z)) for k in range(seg)])
    for i in range(len(rings) - 1):
        for k in range(seg):
            f = bm.faces.new((rings[i][k], rings[i][(k + 1) % seg], rings[i + 1][(k + 1) % seg], rings[i + 1][k]))
            for l in f.loops:
                l[col] = tone
                l[uv].uv = (k / seg, i * 0.2)
    f = bm.faces.new(rings[-1])
    for l in f.loops:
        l[col] = tone
    # the basket
    b0 = [bm.verts.new((math.cos(2 * math.pi * k / 6) * 0.45, math.sin(2 * math.pi * k / 6) * 0.45, FLOOR + PAR_H)) for k in range(6)]
    b1 = [bm.verts.new((math.cos(2 * math.pi * k / 6) * 1.0, math.sin(2 * math.pi * k / 6) * 1.0, FLOOR + 1.85)) for k in range(6)]
    for k in range(6):
        f = bm.faces.new((b0[k], b0[(k + 1) % 6], b1[(k + 1) % 6], b1[k]))
        for l in f.loops:
            l[col] = (0.3, 0.28, 0.27, 1.0)
    bm.normal_update()
    return bm


# ============================================================================================ scene, export, review

def mk(bm, name):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def tris(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


def export_glb(objs, path):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    kw = dict(filepath=path, export_format='GLB', use_selection=True, export_apply=True, export_yup=True,
              export_materials='NONE', export_normals=True, export_texcoords=True, export_tangents=True)
    try:
        bpy.ops.export_scene.gltf(export_vertex_color='ACTIVE', **kw)
    except TypeError:
        bpy.ops.export_scene.gltf(**kw)
    print("EXPORTED", path, "%d tris" % sum(tris(o) for o in objs if "colonly" not in o.name))


def review_materials(objs):
    tex = os.path.join(ROOT, "art", "textures")
    for o in objs:
        set_name = o.name.split("__")[-1] if "__" in o.name else "hewn"
        m = bpy.data.materials.new("pv_" + o.name)
        m.use_nodes = True
        nt = m.node_tree
        bsdf = nt.nodes["Principled BSDF"]
        img = nt.nodes.new("ShaderNodeTexImage")
        img.image = bpy.data.images.load(os.path.join(tex, "r37_%s_albedo.png" % set_name))
        vc = nt.nodes.new("ShaderNodeVertexColor")
        vc.layer_name = "Col"
        mul = nt.nodes.new("ShaderNodeMixRGB")
        mul.blend_type = 'MULTIPLY'
        mul.inputs[0].default_value = 1.0
        nt.links.new(img.outputs[0], mul.inputs[1])
        nt.links.new(vc.outputs[0], mul.inputs[2])
        nt.links.new(mul.outputs[0], bsdf.inputs["Base Color"])
        bsdf.inputs["Roughness"].default_value = 0.85
        if set_name == "iron":
            bsdf.inputs["Metallic"].default_value = 0.6
        o.data.materials.append(m)


def render(objs):
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.device = 'CPU'
    sc.cycles.samples = 40
    sc.cycles.use_denoising = True
    sc.render.resolution_x, sc.render.resolution_y = 1100, 1400
    sc.world = bpy.data.worlds.new("w")
    sc.world.use_nodes = True
    sc.world.node_tree.nodes["Background"].inputs[0].default_value = (0.05, 0.06, 0.11, 1)
    sc.world.node_tree.nodes["Background"].inputs[1].default_value = 1.0
    # a ground disc
    bpy.ops.mesh.primitive_circle_add(vertices=48, radius=14.0, fill_type='NGON', location=(0, 0, 0))
    g = bpy.context.active_object
    gm = bpy.data.materials.new("ground")
    gm.use_nodes = True
    gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.12, 0.13, 0.1, 1)
    g.data.materials.append(gm)
    for n, t, rot, e, c in (("moon", 'SUN', (math.radians(44), 0, math.radians(35)), 3.2, (0.62, 0.72, 1.0)),
                            ("fill", 'SUN', (math.radians(70), 0, math.radians(215)), 0.8, (0.6, 0.65, 0.85))):
        ld = bpy.data.lights.new(n, t)
        ld.energy = e
        ld.color = c
        lo = bpy.data.objects.new(n, ld)
        lo.rotation_euler = rot
        sc.collection.objects.link(lo)
    cd = bpy.data.cameras.new("cam")
    cam = bpy.data.objects.new("cam", cd)
    sc.collection.objects.link(cam)
    sc.camera = cam
    cd.clip_end = 500
    views = [("front", (0, -30, 9), (0, 0, 8.5), 50), ("side", (27, 12, 7), (0, 0, 8.5), 50),
             ("top", (6, -9, 18.5), (0, 0, 16.0), 28), ("foot", (6, -7.5, 2.0), (0, 0, 3.0), 32)]
    for name, loc, tgt, lens in views:
        cam.location = Vector(loc)
        cam.rotation_euler = (Vector(tgt) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
        cd.lens = lens
        sc.render.filepath = os.path.join(PREVIEW, "beacon_%s.png" % name)
        bpy.ops.render.render(write_still=True)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    objs = [mk(tower(), "Tower__hewn"), mk(mortar_core(), "Mortar__hewn"), mk(drum(), "Drum__hewn"), mk(basket(), "Basket__iron"),
            mk(logs(), "Logs__timber"), mk(hoist(), "Hoist__timber")]
    colo = mk(collision(), "Beacon-colonly")
    export_glb(objs + [colo], os.path.join(OUT, "vista_beacon.glb"))
    fo = mk(far(), "BeaconFar__hewn")
    export_glb([fo], os.path.join(OUT, "vista_beacon_far.glb"))
    for o in objs:
        print("PART", o.name, tris(o))
    if PREVIEW:
        os.makedirs(PREVIEW, exist_ok=True)
        colo.hide_render = True
        fo.hide_render = True
        review_materials(objs)
        render(objs)


main()
