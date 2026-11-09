"""The Upward Falls (core/world/realm/wonders/upward_falls.gd): the Order's weir across the Sorrow, modelled by script
(no scans, no downloads), on the r37 West Marches pipeline (r37_west.py: tiling PBR sets dress the meshes in Godot,
metric box UVs, vertex colours carry the macro tone, a -colonly node is the collision).

  upward_falls.glb       the sluice-house (the weir) with its three recesses, the sluice gate, the cornice on
                         corbels, the corner pylons; the glacis the river climbs, its cheek walls and paving; the
                         basin ring on the roof; the two flood arches of the arcade, the abutment, the deck with
                         its parapet; the three torn flights of the hydrographers' stair on their piers; the
                         east end, where the arches fell (a broken arch ring, torn masonry, a deck stub);
                         tumbled voussoirs, column drums and coping
  upward_falls_far.glb   the same silhouette in a few thousand triangles, for the distance

  tools/blender/run.sh wonder_upward_falls.py -- [--renders DIR] [--no-export]

Frame: Blender X east, Y north (upstream; Godot -Z), Z up (Godot +Y). Origin: the weir's centre (Godot x -207, z -18)
on the ground (Godot y 0). The river's bed is at z -0.8, the water at 0.6; the deck is at z 10.0.
Every stone is its own chamfered, slightly warped block (voussoirs are wedges): nothing is a plain box.
"""
import bpy
import bmesh
import math
import os
import random
import sys
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import r37_west as W   # noqa: E402  (the shared helpers; its main is guarded)

ROOT = W.ROOT
MODELS = W.MODELS
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
RENDERS = args[args.index("--renders") + 1] if "--renders" in args else "/private/tmp/claude-501/upward_falls_renders"
NO_EXPORT = "--no-export" in args
TEXT = os.path.join(ROOT, "art", "textures")
RNG = random.Random(4417)

DECK = 10.0
SLAB = 1.2
UNDER = DECK - SLAB
BASE = -1.8
THETA = math.atan2(DECK + 0.9, 8.0)           # the glacis' slope
W.TILE["stone"] = 1.8


# --- stones -------------------------------------------------------------------------------------------------------
def _tint_layer(bm):
    return bm.verts.layers.float.get("tint") or bm.verts.layers.float.new("tint")


def _hew(bm, n0, ch, jit, tint):
    """Chamfer the arrises of the verts made since n0, warp them a little, tint the block."""
    bm.verts.ensure_lookup_table()
    fresh = list(bm.verts[n0:])
    if ch > 0.0:
        edges = list({e for v in fresh for e in v.link_edges})
        bmesh.ops.bevel(bm, geom=edges, offset=ch, offset_type='OFFSET', segments=1, affect='EDGES')
        bm.verts.ensure_lookup_table()
        fresh = list(bm.verts[n0:])
    lay = _tint_layer(bm)
    t = tint if tint is not None else RNG.uniform(0.82, 1.14)
    for v in fresh:
        if jit > 0.0:
            v.co += Vector((RNG.uniform(-jit, jit), RNG.uniform(-jit, jit), RNG.uniform(-jit, jit)))
        v[lay] = t


def block(P, key, c, size, yaw=0.0, pitch=0.0, roll=0.0, ch=0.035, jit=0.012, tint=None):
    bm = P.of(key)
    _tint_layer(bm)
    n0 = len(bm.verts)
    rot = Matrix.Rotation(yaw, 4, 'Z') @ Matrix.Rotation(pitch, 4, 'X') @ Matrix.Rotation(roll, 4, 'Y')
    M = Matrix.Translation(Vector(c)) @ rot @ Matrix.Diagonal((size[0], size[1], size[2], 1.0))
    bmesh.ops.create_cube(bm, size=1.0, matrix=M)
    _hew(bm, n0, min(ch, min(size) * 0.3), jit, tint)


def hexa(P, key, corners, ch=0.03, jit=0.01, tint=None):
    """A hexahedron from 8 corners keyed (sx, sy, sz) in {0, 1}."""
    bm = P.of(key)
    _tint_layer(bm)
    n0 = len(bm.verts)
    res = bmesh.ops.create_cube(bm, size=1.0)
    for v in res['verts']:
        v.co = Vector(corners[(int(v.co.x > 0), int(v.co.y > 0), int(v.co.z > 0))])
    _hew(bm, n0, ch, jit, tint)


def core(P, c, size, tint=0.45, yaw=0.0, pitch=0.0):
    """Plain fill behind the dressed faces (nobody sees it, the light does not reach it)."""
    block(P, "stone", c, size, yaw=yaw, pitch=pitch, ch=0.0, jit=0.0, tint=tint)


def arch(P, cx, cz, r_in, t, depth, y=0.0, n=13, only=None, proj=0.16, key_stone=True):
    """A semicircular arch ring of wedge voussoirs in the XZ plane (depth along Y), keystone proud. `only`: the indices
    that stand (a broken arch)."""
    for i in range(n):
        if only is not None and i not in only:
            continue
        a0 = math.pi - math.pi * i / n - 0.004
        a1 = math.pi - math.pi * (i + 1) / n + 0.004
        mid = (n % 2 == 1) and i == n // 2 and key_stone
        ro = r_in + t + (proj if mid else 0.0)
        d = depth + (0.22 if mid else 0.0)
        ri = r_in - (0.04 if mid else 0.0)
        co = {}
        for sx, a in ((0, a0), (1, a1)):
            for sz, r in ((0, ri), (1, ro)):
                for sy, yy in ((0, -d * 0.5), (1, d * 0.5)):
                    co[(sx, sy, sz)] = (cx + math.cos(a) * r, y + yy, cz + math.sin(a) * r)
        hexa(P, "stone", co, ch=0.04, jit=0.012)


def courses(P, x0, x1, z0, z1, y, depth, face, hole=None, hmin=0.5, hmax=0.7, wmin=0.9, wmax=1.8, x_skip=None):
    """Coursed ashlar on the plane y (face = +1 looks north, -1 south), running bond, a block `depth` thick."""
    z = z0
    row = 0
    while z < z1 - 0.12:
        h = min(RNG.uniform(hmin, hmax), z1 - z)
        if z1 - z - h < 0.3:
            h = z1 - z
        x = x0 - RNG.uniform(0.0, 1.2) * (row % 2)
        while x < x1 - 0.05:
            w = RNG.uniform(wmin, wmax)
            xa, xb = max(x, x0), min(x + w, x1)
            if xb - xa > 0.25:
                cx, cz = (xa + xb) * 0.5, z + h * 0.5
                skip = hole is not None and hole(cx, cz, (xb - xa) * 0.5, h * 0.5)
                if x_skip is not None and x_skip(cx):
                    skip = True
                if not skip:
                    block(P, "stone", (cx, y + face * depth * 0.5, cz), (xb - xa - 0.03, depth, h - 0.03),
                          ch=0.03, jit=0.01)
            x += w
        z += h
        row += 1


def coursed_end(P, x, y0, y1, z0, z1, face, depth=0.55):
    """The same on an end face (a plane x = const, face = +1 looks east)."""
    z = z0
    row = 0
    while z < z1 - 0.12:
        h = min(RNG.uniform(0.5, 0.7), z1 - z)
        if z1 - z - h < 0.3:
            h = z1 - z
        y = y0 - RNG.uniform(0.0, 1.0) * (row % 2)
        while y < y1 - 0.05:
            w = RNG.uniform(0.9, 1.6)
            ya, yb = max(y, y0), min(y + w, y1)
            if yb - ya > 0.25:
                block(P, "stone", (x + face * depth * 0.5, (ya + yb) * 0.5, z + h * 0.5), (depth, yb - ya - 0.03, h - 0.03), ch=0.03, jit=0.01)
            y += w
        z += h
        row += 1


def corbelled_cornice(P, x0, x1, y, z, face, proj=0.55, step=0.95):
    """A row of corbels under a cornice course: stepped blocks, then the course over them."""
    x = x0 + step * 0.5
    while x < x1:
        block(P, "stone", (x, y + face * proj * 0.35, z - 0.28), (0.5, proj * 0.7, 0.55), ch=0.04, jit=0.01)
        block(P, "stone", (x, y + face * proj * 0.62, z - 0.05), (0.62, proj * 0.75, 0.28), ch=0.04, jit=0.01)
        x += step
    n = max(2, int((x1 - x0) / 2.2))
    for i in range(n):
        xa = x0 + (x1 - x0) * i / n
        xb = x0 + (x1 - x0) * (i + 1) / n
        block(P, "stone", ((xa + xb) * 0.5, y + face * proj * 0.55, z + 0.17), (xb - xa - 0.04, proj * 1.1, 0.38), ch=0.05, jit=0.012)


def pylon(P, c, w, h, cap, broken=False, yaw=0.0):
    """A tapering pylon: stacked banded blocks, a belt course, a pyramid cap (or a torn top)."""
    x, y, z0 = c
    n = 6
    core(P, (x, y, z0 + (h * 0.67 if broken else h) * 0.5), (w * 0.8, w * 0.8, h * 0.67 if broken else h), tint=0.45, yaw=yaw)
    zz = z0
    ht = h / n
    for i in range(n):
        s = w * (1.0 - 0.1 * i / n)
        if broken and i >= 4:
            break
        block(P, "stone", (x, y, zz + ht * 0.5), (s, s, ht - 0.02), yaw=yaw, ch=0.05, jit=0.012)
        if i % 2 == 0:
            block(P, "stone", (x, y, zz + 0.07), (s + 0.14, s + 0.14, 0.14), yaw=yaw, ch=0.03, jit=0.008)
        zz += ht
    if broken:
        for k in range(5):
            a = RNG.uniform(0, math.tau)
            block(P, "stone", (x + math.cos(a) * 0.3, y + math.sin(a) * 0.3, zz + RNG.uniform(0.05, 0.4)), (RNG.uniform(0.3, 0.55), RNG.uniform(0.3, 0.55), RNG.uniform(0.2, 0.5)),
                  yaw=RNG.uniform(0, 3), pitch=RNG.uniform(-0.3, 0.3), ch=0.03, jit=0.04)
        return
    s = w * 0.9
    block(P, "stone", (x, y, zz + 0.1), (s + 0.3, s + 0.3, 0.2), yaw=yaw, ch=0.04, jit=0.006)
    hw = s * 0.5
    apex = (x, y, zz + 0.2 + cap)
    bm = P.of("stone")
    _tint_layer(bm)
    n0 = len(bm.verts)
    base = [Vector((x + sx * hw, y + sy * hw, zz + 0.2)) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    vs = [bm.verts.new(p) for p in base]
    ap = bm.verts.new(apex)
    for i in range(4):
        bm.faces.new((vs[i], vs[(i + 1) % 4], ap))
    bm.faces.new(vs[::-1])
    bm.verts.ensure_lookup_table()
    lay = _tint_layer(bm)
    for v in bm.verts[n0:]:
        v[lay] = 1.0
    block(P, "stone", (x, y, zz + 0.2 + cap + 0.08), (0.2, 0.2, 0.2), yaw=0.7, pitch=0.3, ch=0.03, jit=0.0)


def parapet(P, p0, p1, z, h=1.0, t=0.42, gap=0.2, ruin=0.0):
    """A coped parapet wall of blocks from p0 to p1 (xy), pieces gone here and there."""
    a, b = Vector(p0), Vector(p1)
    d = b - a
    L = d.length
    dir_ = d / L
    yaw = math.atan2(dir_.y, dir_.x)
    s = 0.0
    while s < L - 0.2:
        seg = min(RNG.uniform(1.0, 2.0), L - s)
        c = a + dir_ * (s + seg * 0.5)
        if RNG.random() > gap:
            hh = h * (RNG.uniform(0.5, 1.0) if RNG.random() < ruin else 1.0)
            rows = max(1, int(hh / 0.45))
            rh = hh / rows
            for r in range(rows):
                block(P, "stone", (c.x, c.y, z + rh * (r + 0.5)), (seg - 0.03, t, rh - 0.03), yaw=yaw, ch=0.03, jit=0.01)
            if hh > h * 0.95:
                block(P, "stone", (c.x, c.y, z + hh + 0.07), (seg + 0.02, t + 0.14, 0.16), yaw=yaw, ch=0.04, jit=0.008)
        s += seg


def rubble_pile(P, c, n, spread, size=(0.35, 1.0), ground=0.0):
    for _ in range(n):
        a = RNG.uniform(0, math.tau)
        r = RNG.uniform(0, spread)
        s = RNG.uniform(*size)
        block(P, "stone", (c[0] + math.cos(a) * r, c[1] + math.sin(a) * r, ground + s * 0.3), (s * RNG.uniform(0.9, 1.6), s * RNG.uniform(0.7, 1.2), s * RNG.uniform(0.6, 1.0)),
              yaw=RNG.uniform(0, math.tau), pitch=RNG.uniform(-0.35, 0.35), roll=RNG.uniform(-0.3, 0.3), ch=0.05, jit=0.03)


# --- the build ----------------------------------------------------------------------------------------------------
def build_weir(P):
    """The sluice-house: x -8..8, y -3.5..3.5, z -1.8..8.8, a roof slab to 10. Three recesses in its south face."""
    # footing: a battered plinth in dressed blocks, to 1.6
    core(P, (0, 0, (BASE + 1.6) / 2), (16.8, 7.8, 1.6 - BASE))
    for face, y in ((-1, -3.5), (1, 3.5)):
        courses(P, -8.6, 8.6, BASE + 0.4, 1.6, y + face * 0.35, 0.8, face, hmin=0.5, hmax=0.6)
    for face, x in ((-1, -8.0), (1, 8.0)):
        coursed_end(P, x + face * 0.35, -3.9, 3.9, BASE + 0.4, 1.6, face, 0.8)
    block(P, "stone", (0, -4.1, 1.62), (17.6, 0.45, 0.22), ch=0.06, jit=0.0, tint=1.0)          # the plinth's cap, south
    # the body: a core, faced in coursed ashlar on four sides
    core(P, (0, 0, (1.6 + UNDER) / 2), (15.6, 6.6, UNDER - 1.6))
    arch_cx = (0.0, -6.3, 6.3)
    spans = (5.5, 2.4, 2.4)
    spring = 4.8

    def hole(cx, cz, hx, hz):
        for ax, w in zip(arch_cx, spans):
            dx = abs(cx - ax)
            if cz - hz < 1.6 + 3.2:
                if dx - hx < w * 0.5 + 0.55:
                    return True
            elif math.hypot(max(dx - hx, 0.0), max(cz - 4.8 - hz, 0.0)) < w * 0.5 + 0.62:
                return True
        return False

    courses(P, -7.7, 7.7, 1.6, UNDER, -3.5, 0.9, -1, hole=hole)
    # the recesses: dark back stones set in, arch rings, impost blocks
    for ax, w in zip(arch_cx, spans):
        r = w * 0.5
        core(P, (ax, -3.2, (1.6 + 1.6 + 3.2) * 0.5), (w + 0.4, 0.5, 3.2), tint=0.3)
        n = 13 if w > 4 else 9
        arch(P, ax, 1.6 + 3.2, r, 0.62 if w > 4 else 0.42, 1.0, y=-3.95, n=n)
        for sx in (-1, 1):
            block(P, "stone", (ax + sx * (r + 0.1), -3.95, 1.6 + 3.2 - 0.12), (0.5, 1.15, 0.28), ch=0.04, jit=0.006)    # the imposts
            block(P, "stone", (ax + sx * (r + 0.28), -3.95, 1.6 + 1.6), (0.72 if w > 4 else 0.5, 1.0, 3.0), ch=0.04, jit=0.01)   # the jambs
        # a thin core fills the spandrel behind the ring
    core(P, (0, -3.35, 7.1), (16.0, 0.3, 3.4), tint=0.5)
    # the string course (the springline's) and a lower one
    block(P, "stone", (0, -3.95, 5.0), (16.4, 0.25, 0.3), ch=0.05, jit=0.0, tint=1.0)
    block(P, "stone", (0, 3.95, 5.0), (16.4, 0.25, 0.3), ch=0.05, jit=0.0, tint=1.0)
    # pilasters on the north face, either side of the glacis
    for sx in (-1, 1):
        for off in (6.6, 7.4):
            n = 7
            hh = (UNDER - 1.6) / n
            for i in range(n):
                block(P, "stone", (sx * off, 3.95, 1.6 + hh * (i + 0.5)), (0.74, 0.5, hh - 0.04), ch=0.04, jit=0.01)
    # cornice on corbels, all four sides, and the roof
    corbelled_cornice(P, -8.3, 8.3, -3.5, UNDER - 0.05, -1)
    corbelled_cornice(P, -8.3, 8.3, 3.5, UNDER - 0.05, 1)
    for sx in (-1, 1):
        for i in range(7):
            y = -3.1 + i * 1.0
            block(P, "stone", (sx * 8.4, y, UNDER - 0.2), (0.7, 0.55, 0.5), ch=0.04, jit=0.01)
        block(P, "stone", (sx * 8.45, 0, UNDER + 0.17), (0.75, 7.6, 0.38), ch=0.05, jit=0.012)
    core(P, (0, 0, DECK - SLAB / 2 + 0.02), (16.2, 7.0, SLAB - 0.04), tint=0.55)
    # roof paving: flagstones, with the basin's plinth drawn at its centre
    gx = -8.0
    while gx < 8.0:
        gw = min(RNG.uniform(1.3, 2.0), 8.2 - gx)
        gy = -3.6
        while gy < 3.6:
            gl = min(RNG.uniform(1.1, 1.8), 3.7 - gy)
            if gl > 0.2:
                block(P, "stone", (gx + gw * 0.5, gy + gl * 0.5, DECK - 0.1), (gw - 0.05, gl - 0.05, 0.22), ch=0.025, jit=0.012)
            gy += gl
        gx += gw
    # a fascia course on the roof's edges
    for sy in (-1, 1):
        n = 9
        for i in range(n):
            block(P, "stone", (-8.0 + (i + 0.5) * 16.6 / n, sy * 3.7, DECK - SLAB * 0.5), (16.6 / n - 0.03, 0.32, SLAB - 0.05), ch=0.03, jit=0.01)
    # the corner pylons (the north-west and south-east stand broken)
    for sx in (-1, 1):
        for sy in (-1, 1):
            pylon(P, (sx * 7.45, sy * 2.95, DECK), 1.1, 4.4, 1.7, broken=(sx * sy < 0), yaw=0.05 * sx)
    # the roof parapets
    parapet(P, (-7.9, -3.15), (7.9, -3.15), DECK, ruin=0.5, gap=0.18)
    parapet(P, (-7.9, 3.15), (-5.4, 3.15), DECK, ruin=0.0, gap=0.0)
    parapet(P, (5.4, 3.15), (7.9, 3.15), DECK, ruin=0.0, gap=0.0)
    parapet(P, (-7.9, -3.15), (-7.9, 3.15), DECK, ruin=0.5, gap=0.15)
    parapet(P, (7.9, -3.15), (7.9, 3.15), DECK, ruin=0.5, gap=0.15)


def build_gate_arch(P):
    """The ruined gate over the basin, framing the rising water: two piers on the roof, the arch ring springing from
    them at 8 m, the east half fallen. The sheet climbs through its opening."""
    spring = DECK + 8.0
    for sx in (-1, 1):
        x = sx * 5.5
        top = spring if sx < 0 else DECK + 4.9
        z = DECK
        rows = 0
        core(P, (x, 0, (DECK + top) / 2), (1.9, 2.8, top - DECK), tint=0.45)
        while z < top - 0.05:
            h = min(RNG.uniform(0.55, 0.7), top - z)
            batter = 0.03 * (z - DECK)
            for part in range(2):
                block(P, "stone", (x + (part - 0.5) * 1.1 * 1.0, 0.0, z + h * 0.5), (1.08 - batter * 0.2, 3.2 - batter, h - 0.03), ch=0.04, jit=0.012)
            z += h
            rows += 1
        block(P, "stone", (x, 0, DECK + 0.2), (2.8, 3.7, 0.4), ch=0.05, jit=0.008, tint=1.0)          # the foot's moulding
        if sx < 0:
            block(P, "stone", (x + 0.2, 0, spring - 0.15), (2.7, 3.5, 0.32), ch=0.05, jit=0.008, tint=1.0)   # the impost
        else:
            for k in range(6):
                block(P, "stone", (x + RNG.uniform(-0.8, 0.8), RNG.uniform(-1.2, 1.2), top + RNG.uniform(0.0, 0.5)), (RNG.uniform(0.5, 1.0), RNG.uniform(0.6, 1.1), RNG.uniform(0.3, 0.6)),
                      yaw=RNG.uniform(0, 3), pitch=RNG.uniform(-0.3, 0.3), ch=0.04, jit=0.05)
    arch(P, 0.0, spring, 4.4, 1.1, 3.0, y=0.0, n=13, only=set(range(0, 8)))
    # the fallen half of the ring lies on the roof, east of the basin
    for i in range(8, 13):
        a = math.pi * (1.0 - (i + 0.5) / 13.0)
        block(P, "stone", (4.2 + (i - 8) * 0.5 + RNG.uniform(-0.3, 0.3), 1.6 - (i - 8) * 0.55, DECK + 0.4), (1.15, 3.0, 0.85), yaw=a + RNG.uniform(-0.6, 0.6), pitch=RNG.uniform(-0.25, 0.25), roll=RNG.uniform(-0.2, 0.2), ch=0.05, jit=0.02)


def build_gate(P):
    """The sluice gate in the great recess: planks, iron straps, a lifting ring, hung half raised and askew."""
    x0 = 0.0
    y = -3.2
    zb = 2.6
    for i in range(9):
        w = 0.5
        xx = x0 - 2.0 + i * 0.5
        block(P, "timber", (xx + 0.25, y, zb + 1.6), (w - 0.03, 0.14, 3.2 + RNG.uniform(-0.15, 0.15)), pitch=-0.03, ch=0.015, jit=0.008)
    for z in (0.6, 1.7, 2.8):
        block(P, "iron", (x0 + 0.25, y - 0.1, zb + z), (4.7, 0.05, 0.14), ch=0.01, jit=0.0)
    for sx in (-2.3, 2.3):
        block(P, "iron", (x0 + sx, y - 0.04, zb + 1.7), (0.12, 0.2, 3.5), ch=0.01, jit=0.0)
    ring = P.of("iron")
    n0 = len(ring.verts)
    W.cyl(P, "iron", (x0 + 0.25, y - 0.12, zb + 3.5), (x0 + 0.25, y - 0.12, zb + 3.2), 0.18, seg=10)
    ring.verts.ensure_lookup_table()


def build_glacis(P):
    """The glacis the river climbs: paved with flags, cheek walls coped, a sill at the foot, the foot's apron."""
    top = Vector((0.0, 3.5, DECK))
    d = Vector((0.0, math.cos(THETA), -math.sin(THETA)))                # down the slope, northward
    nrm = Vector((0.0, math.sin(THETA), math.cos(THETA)))               # up out of it
    length = (DECK + 0.9) / math.sin(THETA)
    s = 0.0
    row = 0
    while s < length - 0.1:
        sl = min(RNG.uniform(1.1, 1.5), length - s)
        xs = -3.2
        while xs < 3.2:
            w = min(RNG.uniform(1.7, 2.3), 3.2 - xs)
            p = top + d * (s + sl * 0.5) + nrm * -0.16 + Vector((xs + w * 0.5, 0, 0))
            block(P, "stone", p, (w - 0.05, sl - 0.05, 0.34), pitch=-THETA, ch=0.03, jit=0.01)
            xs += w
        s += sl
        row += 1
    # the body under it
    mid = top + d * (length * 0.5)
    core(P, mid - nrm * 4.2, (6.6, length, 8.0), pitch=-THETA)
    for sx in (-1, 1):
        cx = sx * 3.95
        core(P, mid + nrm * 0.25 - nrm * 4.2 + Vector((cx, 0, 0)), (1.5, length, 8.9), pitch=-THETA)
        s = 0.0
        while s < length - 0.1:
            sl = min(RNG.uniform(1.2, 1.7), length - s)
            c0 = top + d * (s + sl * 0.5) + Vector((cx, 0, 0))
            for r, (hh, off) in enumerate(((0.62, 0.15), (0.6, 0.78))):
                block(P, "stone", c0 + nrm * (off + hh * 0.5 - 0.1), (1.5, sl - 0.04, hh - 0.03), pitch=-THETA, ch=0.04, jit=0.012)
            # the coping, wider than the wall
            block(P, "stone", c0 + nrm * 1.58, (1.85, sl + 0.02, 0.3), pitch=-THETA, ch=0.05, jit=0.012, tint=RNG.uniform(0.95, 1.1))
            s += sl
        # the faces toward the channel and out: dressed courses
    # sill and apron where it meets the pond
    foot = top + d * length
    for i in range(6):
        block(P, "stone", (foot.x - 2.9 + i * 1.16, foot.y + 0.3 + RNG.uniform(0, 0.25), foot.z + 0.05), (1.1, 1.3, 0.5), yaw=RNG.uniform(-0.15, 0.15), ch=0.05, jit=0.03)
    rubble_pile(P, (foot.x + 1.0, foot.y + 1.6, -0.8), 8, 3.0, (0.3, 0.7), ground=-0.8)
    # iron posts at the cheeks' feet, with a chain's rings
    for sx in (-1, 1):
        W.cyl(P, "iron", (sx * 4.2, foot.y - 0.2, foot.z + 1.4), (sx * 4.2, foot.y - 0.2, foot.z + 3.4), 0.1, 0.07, seg=8)


def build_basin(P):
    """The basin on the roof: an octagonal two-step plinth, a ring wall of wedge blocks with the notch where the
    river comes in, the coping, a ring of studs."""
    cy = 0.2
    for k, (sz, zz) in enumerate(((5.4, 0.12), (4.8, 0.32))):
        for a in (0.0, math.pi * 0.25):
            block(P, "stone", (0, cy, DECK + zz), (sz, sz, 0.26), yaw=a, ch=0.05, jit=0.01, tint=1.0)
    n = 16
    for i in range(n):
        a0 = math.pi * 0.5 + math.tau * i / n + 0.012          # starts at the north (+Y in Blender), the notch
        a1 = a0 + math.tau / n - 0.024
        if i == 0:
            continue
        h = 0.95 if i not in (1, n - 1) else 0.45
        if i == 7:
            h = 0.62
        co = {}
        for sx, a in ((0, a0), (1, a1)):
            for sz, r in ((0, 2.05), (1, 2.72)):
                for sy, z in ((0, DECK + 0.42), (1, DECK + 0.42 + h)):
                    co[(sx, sz, sy)] = (math.cos(a) * r, cy + math.sin(a) * r, z)
        # corners keyed (sx, sy, sz): remap so sy is the radial index and sz the height
        hexa(P, "stone", {(sx, sr, sh): co[(sx, sr, sh)] for sx in (0, 1) for sr in (0, 1) for sh in (0, 1)}, ch=0.045, jit=0.012)
        if h > 0.9:
            am = (a0 + a1) * 0.5
            block(P, "stone", (math.cos(am) * 2.74, cy + math.sin(am) * 2.74, DECK + 0.42 + h * 0.55), (0.34, 0.34, 0.34), yaw=am, ch=0.05, jit=0.0, tint=1.0)
    # the sill the water pours over, worn hollow
    block(P, "stone", (0, cy + 2.4, DECK + 0.46), (1.7, 1.2, 0.2), ch=0.04, jit=0.01)


def build_arcade(P):
    """Two flood arches and the abutment west of the sluice-house, with the deck and its parapets."""
    # the piers and the arches: x centres -11 and -19.4 (spans 6), wall y +-2.0
    ys = 2.0
    cxs = (-11.0, -19.4)
    # the wall's body as piers and spandrels in coursed blocks, the arch rings in wedges
    pier_spans = [(-16.4, -14.0)]
    # the whole wall, coursed on both faces
    def holef(cx, cz, hx, hz):
        for ax in cxs:
            dx = abs(cx - ax)
            if dx - hx * 0.4 < 3.05 and cz - hz * 0.4 < 4.2:
                return True
            dz = cz - 4.2
            if dz > 0 and math.hypot(dx - hx * 0.4, max(dz - hz * 0.4, 0.0)) < 3.5:
                return True
        return False
    core(P, (-11.0, 0, (UNDER + BASE) / 2 + 0.3), (6.4 + 3.0, 3.6, 0.0 + 0.001), tint=0.0)    # (no-op placeholder: keeps indices stable)
    for ax in cxs:
        arch(P, ax, 4.2, 3.0, 0.7, ys * 2.0 + 0.1, y=0.0, n=13)
        for sx in (-1, 1):
            block(P, "stone", (ax + sx * 3.1, 0.0, 4.2 - 0.14), (0.6, ys * 2 + 0.3, 0.3), ch=0.04, jit=0.008)
    # piers: from the sluice-house west wall to the arch 1, between the arches, the abutment
    for (xa, xb) in ((-13.4, -8.0 - 0.1), (-24.0 + 1.6, -16.4 + 0.0)):
        pass
    for (xa, xb) in (((-14.0, -8.0)), ((-23.6, -16.4))):
        pass
    # explicit pier blocks (coursed, battered), the arch's own jambs
    def pier(xa, xb, z0, z1):
        for face in (-1, 1):
            courses(P, xa, xb, z0, z1, face * ys, 0.5, face, hmin=0.5, hmax=0.65, wmin=0.6, wmax=1.2)
        core(P, ((xa + xb) / 2, 0, (z0 + z1) / 2), (xb - xa - 0.1, ys * 2 - 0.5, z1 - z0), tint=0.45)
    pier(-16.4, -14.0, BASE + 0.4, 4.2)
    pier(-8.0 - 0.0 - 0.0, -8.0, BASE, BASE + 0.1)
    pier(-14.0, -8.0 - 0.01, BASE, BASE + 0.01)
    for ax in cxs:
        for sx in (-1, 1):
            pass
    # the arch's springing blocks down to the ground on the near side of each pier (the pier above), the spandrels
    # above the rings: coursed fill between the ring's outer edge and the deck's underside
    def span(cx, cz, hx, hz):
        for ax in cxs:
            if math.hypot(cx - ax, max(cz - 4.2, 0.0)) < 3.7 and abs(cx - ax) < 3.7:
                return True
        return False
    for face in (-1, 1):
        courses(P, -30.0, -8.0, 4.2, UNDER, face * ys, 0.5, face, hole=span, hmin=0.5, hmax=0.65, wmin=0.7, wmax=1.4)
    core(P, (-19.0, 0, (7.9 + UNDER) / 2), (22.0, 3.6, UNDER - 7.9), tint=0.45)
    core(P, (-15.2, 0, (4.2 + UNDER) / 2), (2.4, 3.6, UNDER - 4.2), tint=0.45)
    pier(-23.6, -22.4, BASE + 0.4, 4.2)
    core(P, (-23.0, 0, (4.2 + UNDER) / 2), (1.2, 3.6, UNDER - 4.2), tint=0.45)
    # the abutment: solid, x -30..-23.6; each long face has a tall blind arch, buttresses at the corners
    core(P, (-26.8, 0, (UNDER + BASE) / 2), (6.4, 4.8, UNDER - BASE), tint=0.45)

    def abut_hole(cx, cz, hx, hz):
        dx = abs(cx + 26.8)
        if cz - hz < 4.7:
            return dx - hx < 1.6 + 0.5
        return math.hypot(max(dx - hx, 0.0), max(cz - 4.7 - hz, 0.0)) < 1.6 + 0.5
    for face in (-1, 1):
        courses(P, -30.2, -23.5, BASE + 0.3, UNDER, face * 2.4, 0.55, face, hole=abut_hole)
        core(P, (-26.8, face * 2.35, (BASE + 4.7) * 0.5 + 0.6), (3.5, 0.3, 4.7 - BASE - 0.6), tint=0.3)
        arch(P, -26.8, 4.7, 1.6, 0.46, 0.8, y=face * 2.62, n=9)
        for sx in (-1, 1):
            z = BASE + 0.4
            while z < 4.55:
                h = min(RNG.uniform(0.5, 0.62), 4.7 - z)
                block(P, "stone", (-26.8 + sx * 1.85, face * 2.62, z + h * 0.5), (0.52, 0.8, h - 0.03), ch=0.035, jit=0.01)
                z += h
        for sx in (-1, 1):                                      # buttresses at the corners
            for i in range(9):
                hh = (UNDER - BASE) / 9
                block(P, "stone", (-26.8 + sx * 3.05, face * 2.65, BASE + hh * (i + 0.5)), (0.7 - 0.0, 0.55, hh - 0.03), ch=0.04, jit=0.012)
    coursed_end(P, -30.0, -2.4, 2.4, BASE + 0.3, UNDER, -1, 0.6)
    for sy in (-1, 1):
        pylon(P, (-29.4, sy * 1.7, DECK), 0.9, 3.2, 1.3, broken=(sy > 0), yaw=0.04)
    # the pier faces between the arches and the first arch's piers: jamb stones of the arches reaching down
    for ax in cxs:
        for sx in (-1, 1):
            for face in (-1, 1):
                z = BASE + 0.4
                while z < 4.2 - 0.3:
                    h = min(RNG.uniform(0.5, 0.65), 4.2 - z)
                    block(P, "stone", (ax + sx * 3.4, face * (ys + 0.02), z + h * 0.5), (0.8, 0.55, h - 0.03), ch=0.03, jit=0.01)
                    z += h
    # the deck: corbelled cornice both faces, the slab, its paving, the parapets
    for face in (-1, 1):
        corbelled_cornice(P, -30.0, -8.0, face * 2.4, UNDER - 0.05, face, proj=0.5)
    core(P, (-19.0, 0, DECK - SLAB / 2), (22.6, 5.0, SLAB - 0.05), tint=0.55)
    gx = -30.3
    while gx < -7.9:
        gw = min(RNG.uniform(1.3, 2.0), -7.8 - gx)
        gy = -2.4
        while gy < 2.4:
            gl = min(RNG.uniform(1.1, 1.7), 2.5 - gy)
            if gl > 0.2:
                block(P, "stone", (gx + gw * 0.5, gy + gl * 0.5, DECK - 0.1), (gw - 0.05, gl - 0.05, 0.22), ch=0.025, jit=0.012)
            gy += gl
        gx += gw
    for sy in (-1, 1):
        parapet(P, (-30.0, sy * 2.3), (-8.0, sy * 2.3), DECK, ruin=0.45, gap=0.18)
    parapet(P, (-30.0, -2.3), (-30.0, 2.3), DECK, ruin=0.3, gap=0.5)
    # cutwaters on the upstream face of the pier between the arches
    for k, (w, h) in enumerate(((1.6, 4.0), (1.1, 6.0))):
        co = {}
        for sx in (0, 1):
            for sy in (0, 1):
                for sz in (0, 1):
                    xx = -15.2 + (sx - 0.5) * (w if sy == 0 else 0.15)
                    yy = ys + (0.0 if sy == 0 else 0.9 + k * 0.3)
                    zz = (BASE if sz == 0 else (h if sy == 0 else h - 0.6 - k * 0.4))
                    co[(sx, sy, sz)] = (xx, yy, zz)
        hexa(P, "stone", co, ch=0.05, jit=0.012)


def build_stair(P, g0=3.0):
    """The hydrographers' stair: three flights up the west face of the abutment, each on a pier with a little arch,
    a break of one jump between them. Same numbers as upward_falls.gd."""
    n = 14
    run = 4.2
    gap = 1.5
    brk = 0.6
    r = (DECK - g0 - 3.0 * brk) / (3.0 - 2.0 / n)
    lo = g0
    x_hi = -30.0 - gap
    info = []
    for f in range(3):
        hi_x = x_hi - (2 - f) * (run + gap)
        lo_x = hi_x - run
        hi = lo + r
        tread = run / n
        rise = (hi - lo) / n
        # treads: each a block, a nosing proud, a riser dressed in the block below
        for i in range(n):
            top = lo + rise * (i + 1)
            x = lo_x + tread * (i + 0.5)
            bot = lo - 0.45 if f > 0 else min(g0 - 0.8, lo - 0.45)
            block(P, "stone", (x, 0, top - 0.11), (tread + 0.1, 2.7, 0.22), ch=0.025, jit=0.006, tint=RNG.uniform(0.9, 1.12))
            if i % 2 == 0:
                block(P, "stone", (x, 0, (top - 0.22 + bot) / 2), (tread * 2.0 - 0.02, 2.5, top - 0.22 - bot), ch=0.0, jit=0.0, tint=0.5)
        # side walls: a continuous stringer of blocks along the rake, a coping over it
        ang = math.atan2(hi - lo, run)
        L = math.hypot(run, hi - lo)
        seg_n = max(2, int(L / 1.3))
        for sy in (-1, 1):
            for j in range(seg_n):
                t = (j + 0.5) / seg_n
                cxm = lo_x + run * t
                czm = lo + (hi - lo) * t
                block(P, "stone", (cxm, sy * 1.5, czm + 0.2), (L / seg_n + 0.02, 0.5, 1.2), roll=-ang, ch=0.04, jit=0.012)
                block(P, "stone", (cxm, sy * 1.5, czm + 0.9), (L / seg_n + 0.05, 0.72, 0.2), roll=-ang, ch=0.05, jit=0.008, tint=RNG.uniform(0.95, 1.1))
        # the pier below the flight: coursed, an arch in it
        if f > 0:
            zb = _ground_near(lo_x, g0)
            z_top = lo - 0.5
            core(P, ((lo_x + hi_x) / 2, 0, (zb + z_top) / 2), (run - 0.4, 2.2, z_top - zb), tint=0.45)
            for face in (-1, 1):
                courses(P, lo_x + 0.15, hi_x - 0.15, zb, z_top, face * 1.1, 0.45, face, hmin=0.5, hmax=0.65)
            for sx in (-1, 1):
                coursed_end(P, (lo_x if sx < 0 else hi_x) + sx * 0.0, -1.1, 1.1, zb, z_top, sx, 0.4)
        info.append((lo_x, hi_x, lo, hi))
        # the break: fallen steps and a torn stub of the old tread
        bx = hi_x + gap * 0.5
        rubble_pile(P, (bx, 0), 2, 1.1, (0.35, 0.6), ground=_ground_near(bx, g0))
        lo = hi + brk - r / n
    return info


def _ground_near(x, g0):
    """The valley floor under the stair, modelled as it is in the Realm: ~0.4 east of x -240, rising to g0 at -254."""
    return max(0.2, min(g0, 0.3 + 2.7 * max(0.0, (-x - 238.0 - -207.0 * -1) / 1000.0)))


def build_east(P):
    """Where the east arches fell: the broken springers of an arch ring off the sluice-house wall, the torn deck stub,
    the pier's stub, fallen voussoirs, column drums, torn masonry."""
    # the deck stub: a cantilever of the slab, broken in a diagonal line
    for i in range(4):
        x = 8.2 + i * 1.0
        torn = 3.4 - i * 0.55 + RNG.uniform(-0.3, 0.3)
        block(P, "stone", (x + 0.5, 0, DECK - SLAB * 0.5), (1.0 - 0.03, 5.0 if i < 2 else 5.0 - i * 0.8, SLAB - 0.05), ch=0.03, jit=0.012)
    parapet(P, (8.0, -2.3), (10.5, -2.3), DECK, ruin=0.7, gap=0.1)
    for sx in (0,):
        for i in range(4):
            block(P, "stone", (8.8 + i * 1.0, 2.3 * (-1 if i % 2 else 1), DECK + 0.3), (0.9, 0.4, 0.5), pitch=RNG.uniform(-0.4, 0.4), ch=0.04, jit=0.04)
    for x, h in ((8.4, 5.4), (9.5, 4.4), (10.6, 3.4)):                                   # corbels under the stub
        block(P, "stone", (x, 0, UNDER - 0.5), (0.9, 3.4, 0.45), ch=0.04, jit=0.01)
    # the east arch ring, only its springers standing, off the wall's east face
    arch(P, 11.0, 4.2, 3.0, 0.7, 4.1, y=0.0, n=13, only={9, 10, 11, 12})
    arch(P, 11.0, 4.2, 3.0, 0.7, 4.1, y=0.0, n=13, only={0, 1})
    # the east pier's stump, torn: stacked blocks that thin out as they rise, a ragged crown
    core(P, (15.2, 0, (BASE + 3.0) / 2), (2.0, 3.0, 3.0 - BASE), tint=0.45)
    z = BASE + 0.3
    while z < 4.9:
        h = RNG.uniform(0.5, 0.65)
        for ix in (-0.6, 0.6):
            for iy in (-0.85, 0.85):
                if z > 3.0 and RNG.random() < (z - 3.0) / 2.2:
                    continue
                block(P, "stone", (15.2 + ix + RNG.uniform(-0.04, 0.04), iy, z + h * 0.5), (1.18, 1.7, h - 0.03), yaw=RNG.uniform(-0.03, 0.03), ch=0.04, jit=0.015)
        z += h
    for k in range(7):
        block(P, "stone", (15.2 + RNG.uniform(-1.0, 1.0), RNG.uniform(-1.4, 1.4), 4.5 + RNG.uniform(0.0, 0.4)), (RNG.uniform(0.5, 1.0), RNG.uniform(0.5, 1.0), RNG.uniform(0.3, 0.6)),
              yaw=RNG.uniform(0, 3), pitch=RNG.uniform(-0.3, 0.3), ch=0.04, jit=0.05)
    # fallen: voussoirs on the ground, column drums, torn courses
    for i in range(9):
        a = math.pi * (0.1 + 0.8 * i / 8.0) + 0.4
        c = (13.0 + math.cos(a) * 4.0, 4.6 + math.sin(a) * 3.8)
        block(P, "stone", (c[0], c[1], 0.45), (0.9, 1.5, 0.8), yaw=a + 1.5 + RNG.uniform(-0.2, 0.2), pitch=RNG.uniform(-0.3, 0.3), roll=RNG.uniform(-0.25, 0.25), ch=0.05, jit=0.02)
    for (x, y) in ((11.5, -5.0), (13.6, -6.6)):
        W.cyl(P, "stone", (x, y, 0.45), (x + 1.8, y + 0.4, 0.55), 0.62, 0.58, seg=14)
    rubble_pile(P, (12.5, 0.5), 16, 5.5, (0.4, 1.1))
    rubble_pile(P, (-34.0, 3.0), 6, 3.0, (0.4, 0.9))
    rubble_pile(P, (-3.0, -5.8), 6, 3.0, (0.4, 0.9))
    rubble_pile(P, (3.5, -6.2), 5, 2.4, (0.4, 0.8))


def build_collision(P):
    """Boxes: the sluice-house, the glacis, the arcade's piers and lintel, the abutment, the deck, the stair's ramps."""
    W.box(P, "stone", (0, 0, (BASE + DECK) / 2), (16.2, 7.0, DECK - BASE))
    top = Vector((0.0, 3.5, DECK))
    d = Vector((0.0, math.cos(THETA), -math.sin(THETA)))
    nrm = Vector((0.0, math.sin(THETA), math.cos(THETA)))
    length = (DECK + 0.9) / math.sin(THETA)
    mid = top + d * (length * 0.5)
    W.box(P, "stone", tuple(mid - nrm * 4.0), (6.6, 8.0, length), yaw=0.0, pitch=0.0)   # replaced below by a rotated slab
    P.bm["stone"].clear()
    W.box(P, "stone", (0, 0, (BASE + DECK) / 2), (16.2, 7.0, DECK - BASE))
    slab = Matrix.Translation(mid - nrm * 4.0) @ Matrix.Rotation(-THETA, 4, 'X') @ Matrix.Diagonal((6.6, length, 8.0, 1.0))
    bmesh.ops.create_cube(P.of("stone"), size=1.0, matrix=slab)
    for sx in (-1, 1):
        cheek = Matrix.Translation(mid - nrm * 3.45 + Vector((sx * 3.95, 0, 0))) @ Matrix.Rotation(-THETA, 4, 'X') @ Matrix.Diagonal((1.8, length, 9.1, 1.0))
        bmesh.ops.create_cube(P.of("stone"), size=1.0, matrix=cheek)
    # the arcade: piers and a lintel over each arch
    W.box(P, "stone", (-15.2, 0, (BASE + UNDER) / 2), (2.4, 4.0, UNDER - BASE))
    W.box(P, "stone", (-26.8, 0, (BASE + UNDER) / 2), (6.4, 5.0, UNDER - BASE))
    for ax in (-11.0, -19.4):
        W.box(P, "stone", (ax, 0, (4.2 + 3.0 + UNDER) / 2 + 0.0), (6.0, 4.0, UNDER - 7.2))
    W.box(P, "stone", (-19.0, 0, DECK - SLAB / 2), (22.6, 5.2, SLAB))
    for sy in (-1, 1):
        W.box(P, "stone", (-19.0, sy * 2.3, DECK + 0.45), (22.0, 0.4, 0.9))
        W.box(P, "stone", (0, sy * 3.15, DECK + 0.45), (15.8, 0.42, 0.9))
    W.box(P, "stone", (-5.5, 0, DECK + 4.0), (2.2, 3.2, 8.0))
    W.box(P, "stone", (5.5, 0, DECK + 2.4), (2.2, 3.2, 4.8))
    # the east stub and pier
    W.box(P, "stone", (10.2, 0, DECK - SLAB / 2), (4.4, 4.6, SLAB))
    W.box(P, "stone", (15.2, 0, (BASE + 4.5) / 2), (2.4, 3.6, 4.5 - BASE))
    # the stair: a ramp under each flight and a pier under it
    n = 14
    run = 4.2
    gap = 1.5
    brk = 0.6
    g0 = 3.0
    r = (DECK - g0 - 3.0 * brk) / (3.0 - 2.0 / n)
    lo = g0
    for f in range(3):
        hi_x = -30.0 - gap - (2 - f) * (run + gap)
        lo_x = hi_x - run
        hi = lo + r
        ang = math.atan2(hi - lo, run)
        L = math.hypot(run, hi - lo)
        ramp = Matrix.Translation(((lo_x + hi_x) / 2, 0, (lo + hi) / 2 - 0.12)) @ Matrix.Rotation(-ang, 4, 'Y') @ Matrix.Diagonal((L + 0.3, 2.7, 0.3, 1.0))
        bmesh.ops.create_cube(P.of("stone"), size=1.0, matrix=ramp)
        zb = _ground_near(lo_x, g0)
        if f > 0:
            W.box(P, "stone", ((lo_x + hi_x) / 2, 0, (zb + lo - 0.4) / 2), (run - 0.4, 2.2, lo - 0.4 - zb))
        else:
            W.box(P, "stone", ((lo_x + hi_x) / 2, 0, (zb - 0.8 + lo) / 2), (run, 2.4, lo - zb + 0.8))
        lo = hi + brk - r / n


def build_far():
    """The silhouette in a few thousand triangles: the masses, the arch rings as eight wedges, the glacis, the pylons."""
    P = W.Parts()
    W.box(P, "stone", (0, 0, (BASE + UNDER) / 2), (17.0, 7.4, UNDER - BASE))
    W.box(P, "stone", (0, 0, DECK - SLAB / 2), (16.8, 7.4, SLAB))
    for sx in (-1, 1):
        for sy in (-1, 1):
            W.box(P, "stone", (sx * 7.45, sy * 2.95, DECK + (2.2 if sx * sy > 0 else 1.0)), (1.2, 1.2, 4.4 if sx * sy > 0 else 2.0))
    top = Vector((0.0, 3.5, DECK))
    d = Vector((0.0, math.cos(THETA), -math.sin(THETA)))
    nrm = Vector((0.0, math.sin(THETA), math.cos(THETA)))
    length = (DECK + 0.9) / math.sin(THETA)
    mid = top + d * (length * 0.5)
    W.box(P, "stone", tuple(mid - nrm * 3.0), (9.4, length, 6.0), pitch=-THETA)
    for ax in (-11.0, -19.4):
        for sx in (-1, 1):
            pass
    W.box(P, "stone", (-15.2, 0, (BASE + UNDER) / 2), (2.8, 4.4, UNDER - BASE))
    W.box(P, "stone", (-26.8, 0, (BASE + UNDER) / 2), (6.8, 5.2, UNDER - BASE))
    for ax in (-11.0, -19.4):
        arch(P, ax, 4.2, 3.0, 0.7, 4.0, n=7, key_stone=False)
        W.box(P, "stone", (ax, 0, (7.9 + UNDER) / 2), (6.8, 4.4, UNDER - 7.9))
    W.box(P, "stone", (-19.0, 0, DECK - SLAB / 2), (23.0, 5.4, SLAB))
    W.box(P, "stone", (10.2, 0, DECK - SLAB / 2), (4.4, 5.0, SLAB))
    W.box(P, "stone", (15.2, 0, (BASE + 4.5) / 2), (2.6, 3.8, 4.5 - BASE))
    n = 14
    run, gap, brk, g0 = 4.2, 1.5, 0.6, 3.0
    r = (DECK - g0 - 3.0 * brk) / (3.0 - 2.0 / n)
    lo = g0
    for f in range(3):
        hi_x = -30.0 - gap - (2 - f) * (run + gap)
        lo_x = hi_x - run
        hi = lo + r
        ang = math.atan2(hi - lo, run)
        L = math.hypot(run, hi - lo)
        ramp = Matrix.Translation(((lo_x + hi_x) / 2, 0, (lo + hi) / 2 - 0.4)) @ Matrix.Rotation(-ang, 4, 'Y') @ Matrix.Diagonal((L, 2.7, 0.9, 1.0))
        bmesh.ops.create_cube(P.of("stone"), size=1.0, matrix=ramp)
        if f > 0:
            W.box(P, "stone", ((lo_x + hi_x) / 2, 0, (0.3 + lo - 0.4) / 2), (run - 0.4, 2.2, lo - 0.7))
        lo = hi + brk - r / n
    return P


# --- finishing -----------------------------------------------------------------------------------------------------
def finish(P, name, tone=True):
    """r37_west's finish with the per-block tint multiplied in."""
    objs = []
    for key, bm in P.bm.items():
        if len(bm.faces) == 0:
            bm.free()
            continue
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.normal_update()
        uv = bm.loops.layers.uv.new("UVMap")
        col = bm.loops.layers.color.new("Col")
        lay = bm.verts.layers.float.get("tint")
        tile = W.TILE.get(key, 4.0)
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
                c = W.tone_for(key, co, n, True)
                t = l.vert[lay] if lay else 1.0
                # damp stonework at the water line: a green-black band (the pond's reach) and the spray's wet above the foot
                l[col] = (min(1.0, c[0] * t), min(1.0, c[1] * t), min(1.0, c[2] * t), 1.0)
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
    return objs


# --- previews ------------------------------------------------------------------------------------------------------
def pbr_material(key):
    """The Godot set as a Blender material, so the turnaround shows what the game will."""
    m = bpy.data.materials.get(key)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(bsdf.outputs[0], out.inputs[0])
    base = os.path.join(TEXT, "r37_%s_" % key)
    alb = nt.nodes.new("ShaderNodeTexImage")
    alb.image = bpy.data.images.load(base + "albedo.png")
    nrm = nt.nodes.new("ShaderNodeTexImage")
    nrm.image = bpy.data.images.load(base + "normal.png")
    nrm.image.colorspace_settings.name = "Non-Color"
    orm = nt.nodes.new("ShaderNodeTexImage")
    orm.image = bpy.data.images.load(base + "orm.png")
    orm.image.colorspace_settings.name = "Non-Color"
    vc = nt.nodes.new("ShaderNodeVertexColor")
    vc.layer_name = "Col"
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = 'RGBA'
    mix.blend_type = 'MULTIPLY'
    mix.inputs[0].default_value = 1.0
    nt.links.new(alb.outputs[0], mix.inputs[6])
    nt.links.new(vc.outputs[0], mix.inputs[7])
    nt.links.new(mix.outputs[2], bsdf.inputs["Base Color"])
    nm = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(nrm.outputs[0], nm.inputs["Color"])
    nt.links.new(nm.outputs[0], bsdf.inputs["Normal"])
    sep = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(orm.outputs[0], sep.inputs[0])
    nt.links.new(sep.outputs[1], bsdf.inputs["Roughness"])
    if key == "iron":
        nt.links.new(sep.outputs[2], bsdf.inputs["Metallic"])


def render_turnaround(objs, label, views, size=(1280, 720), night=True):
    os.makedirs(RENDERS, exist_ok=True)
    sc = bpy.context.scene
    for o in list(bpy.data.objects):
        if o.name.endswith("-colonly"):
            o.hide_render = True
    for key in ("stone", "timber", "iron"):
        if bpy.data.materials.get(key):
            pbr_material(key)
    try:
        sc.render.engine = 'BLENDER_EEVEE'
    except TypeError:
        sc.render.engine = 'BLENDER_EEVEE_NEXT'
    sc.render.resolution_x, sc.render.resolution_y = size
    sc.render.film_transparent = False
    w = bpy.data.worlds.new("night")
    w.use_nodes = True
    bg = w.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.09, 0.13, 0.22, 1.0)
    bg.inputs[1].default_value = 1.6
    sc.world = w
    # moon (cold, low) and a warm ground-bounce fill, like the Realm's night
    moon = bpy.data.lights.new("moon", 'SUN')
    moon.energy = 7.0
    moon.color = (0.62, 0.74, 1.0)
    mo = bpy.data.objects.new("moon", moon)
    mo.rotation_euler = (math.radians(58), 0, math.radians(35))
    sc.collection.objects.link(mo)
    fill = bpy.data.lights.new("fill", 'SUN')
    fill.energy = 1.8
    fill.color = (0.6, 0.65, 0.9)
    fo = bpy.data.objects.new("fill", fill)
    fo.rotation_euler = (math.radians(70), 0, math.radians(-150))
    sc.collection.objects.link(fo)
    # the ground and the river (stand-ins, for scale)
    gm = bpy.data.meshes.new("ground")
    gb = bmesh.new()
    bmesh.ops.create_grid(gb, x_segments=2, y_segments=2, size=120.0, matrix=Matrix.Translation((0, 0, 0.9)))
    gb.to_mesh(gm)
    gb.free()
    gmat = bpy.data.materials.new("gnd")
    gmat.diffuse_color = (0.08, 0.1, 0.07, 1.0)
    gmat.use_nodes = True
    gmat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.07, 0.09, 0.06, 1.0)
    gmat.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 1.0
    gm.materials.append(gmat)
    go = bpy.data.objects.new("ground", gm)
    sc.collection.objects.link(go)
    wm = bpy.data.meshes.new("water")
    wb = bmesh.new()
    bmesh.ops.create_grid(wb, x_segments=2, y_segments=2, size=1.0, matrix=Matrix.Translation((0, -22, 0.62)) @ Matrix.Diagonal((8.5, 40, 1, 1)))
    wb.to_mesh(wm)
    wb.free()
    wmat = bpy.data.materials.new("wat")
    wmat.use_nodes = True
    wmat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.05, 0.12, 0.2, 1.0)
    wmat.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.15
    wm.materials.append(wmat)
    wo = bpy.data.objects.new("water", wm)
    sc.collection.objects.link(wo)
    cam_d = bpy.data.cameras.new("cam")
    cam = bpy.data.objects.new("cam", cam_d)
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam_d.clip_end = 800
    for i, (loc, target, lens) in enumerate(views):
        cam.location = Vector(loc)
        cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
        cam_d.lens = lens
        sc.render.filepath = os.path.join(RENDERS, "%s_%d.png" % (label, i))
        bpy.ops.render.render(write_still=True)
        print("RENDER", sc.render.filepath)


def main():
    W.reset()
    P = W.Parts()
    build_weir(P)
    build_gate_arch(P)
    build_gate(P)
    build_glacis(P)
    build_basin(P)
    build_arcade(P)
    build_stair(P)
    build_east(P)
    objs = finish(P, "Weir")
    PC = W.Parts()
    build_collision(PC)
    col = W.finish(PC, "WeirCol")
    for o in col:
        o.name = "Weir-colonly"
        o.data.name = o.name
        o.data.materials.clear()
    tri = sum(W.tris(o) for o in objs)
    print("TRIS near", tri)
    if not NO_EXPORT:
        W.export(objs + col, os.path.join(MODELS, "upward_falls.glb"), "upward falls")
        FP = build_far()
        far = finish(FP, "WeirFar")
        W.export(far, os.path.join(MODELS, "upward_falls_far.glb"), "upward falls far")
        for o in far:
            bpy.data.objects.remove(o)
    render_turnaround(objs, "weir", [
        ((46, -34, 14), (-4, 0, 5), 28),          # from the south-east, the pool
        ((34, 30, 12), (-2, 0, 5), 30),           # from the north-east
        ((-48, 26, 14), (-14, 0, 5), 34),         # from the north-west (the stair, the glacis)
        ((-52, -26, 14), (-16, 0, 5), 34),        # from the south-west
        ((6, 22, 9), (0, 0, 5), 42),              # the glacis face on
        ((4, -20, 6), (0, -3, 5), 42),            # the south recesses close
        ((0, -3.5, 12.4), (0, 0.5, 10.8), 55),    # the deck
        ((30, -60, 12), (-2, 0, 12), 30),         # the arch from the south
        ((-14, -62, 7), (-14, 0, 6), 36),         # the south elevation of the arcade
        ((-66, -10, 8), (-40, 0, 6), 40),         # the stair from the west
    ])


if __name__ == "__main__":
    main()
