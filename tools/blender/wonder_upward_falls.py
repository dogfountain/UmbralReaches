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


def courses(P, x0, x1, z0, z1, y, depth, face, hole=None, hmin=0.5, hmax=0.7, wmin=0.9, wmax=1.8, x_skip=None, gaps=()):
    """Coursed ashlar on the plane y (face = +1 looks north, -1 south), running bond, a block `depth` thick."""
    hmin, hmax, wmin, wmax = hmin * 1.25, hmax * 1.25, wmin * 1.3, wmax * 1.3
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
            pieces = [(xa, xb)]
            for (g0, g1, gz) in gaps:                       # an opening: blocks are trimmed to it, not dropped
                if z < gz:
                    nxt = []
                    for (pa, pb) in pieces:
                        if pb <= g0 or pa >= g1:
                            nxt.append((pa, pb))
                        else:
                            if g0 - pa > 0.25:
                                nxt.append((pa, g0))
                            if pb - g1 > 0.25:
                                nxt.append((g1, pb))
                    pieces = nxt
            for (xa, xb) in pieces:
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
# A hydraulic work, long and low across the river: a stepped weir the Sorrow climbs, a crest platform with the scoured
# bowl the water stands up out of, a south wall with two sluice bays and the Order's shrine niche, wing walls to the
# banks (the east wing fallen), cutwaters, a keeper's sluice-house on the west bank.
CREST = 4.8                     # the crest platform's top
BED = -0.8
N_STEP = 7
TREAD = 1.5
Y_C = 2.4                       # the platform's north edge; it runs to Y_S on the south
Y_S = -2.6
RIVER_HW = 6.8                  # half the stepped width
WING = 19.0                     # the wings' ends
BOWL = (0.0, -0.1)
BOWL_R = 2.35
LIP = []                         # the bowl's lip stones (centre, size, yaw), for the collision
STEP_TOPS = [0.95 + (CREST - 0.95) * k / N_STEP for k in range(N_STEP)]
FOOT = BED - 1.0


def build_steps(P):
    """The stepped weir: seven broad treads of dressed slabs, risers dressed, an apron of heavy stones on the bed."""
    for k, zt in enumerate(STEP_TOPS):
        y1 = Y_C + TREAD * (N_STEP - k)
        y0 = y1 - TREAD
        ym = (y0 + y1) * 0.5
        core(P, (0, ym, (FOOT + zt - 0.55) * 0.5), (2 * RIVER_HW + 0.2, TREAD, zt - 0.55 - FOOT), tint=0.45)
        n = 5
        xs = -RIVER_HW
        for i in range(n):
            w = (2 * RIVER_HW) / n
            block(P, "stone", (xs + w * 0.5, ym, zt - 0.275), (w - 0.05 + RNG.uniform(-0.05, 0.05), TREAD - 0.04, 0.55), ch=0.05, jit=0.015)
            xs += w
        # a worn lip: a few chips and a heavier nosing stone
        for i in range(3):
            xx = RNG.uniform(-RIVER_HW + 1.0, RIVER_HW - 1.0)
            block(P, "stone", (xx, y0 + 0.1, zt + 0.02), (RNG.uniform(0.5, 1.0), 0.24, 0.1), ch=0.03, jit=0.02)
    # the apron: heavy stones laid on the bed where the pond meets the first step
    yf = Y_C + TREAD * N_STEP + 0.4
    for i in range(9):
        xx = -RIVER_HW + 0.8 + i * (2 * RIVER_HW - 1.6) / 8
        block(P, "stone", (xx, yf + RNG.uniform(0.0, 0.7), BED + 0.15), (1.4, 1.2, 0.5), yaw=RNG.uniform(-0.2, 0.2), ch=0.06, jit=0.03)
    # the funnel: kerbs on the top three treads draw the water in toward the bowl
    for sx in (-1, 1):
        for k in range(4, N_STEP):
            zt = STEP_TOPS[k]
            y1 = Y_C + TREAD * (N_STEP - k)
            f = (k - 3) / 4.0
            x = sx * (RIVER_HW - 1.3 - f * 2.4)
            block(P, "stone", (x, y1 - TREAD * 0.5, zt + 0.22), (0.7, TREAD + 0.1, 0.45), yaw=sx * (0.12 + 0.05 * f), ch=0.04, jit=0.012)


def build_body(P):
    """The platform and the south wall: coursed, a plinth, a string course, a coped edge; sluice bays and the niche."""
    ym = (Y_S + Y_C) * 0.5
    core(P, (0, ym, (FOOT + CREST - 0.3) * 0.5), (2 * RIVER_HW + 0.2, Y_C - Y_S, CREST - 0.3 - FOOT), tint=0.45)
    # the south wall's plinth, battered, in heavy blocks
    courses(P, -RIVER_HW - 0.2, RIVER_HW + 0.2, FOOT + 0.3, 1.4, Y_S - 0.35, 0.8, -1, hmin=0.55, hmax=0.7, wmin=1.2, wmax=2.2)
    block(P, "stone", (0, Y_S - 0.72, 1.45), (2 * RIVER_HW + 1.2, 0.5, 0.24), ch=0.06, jit=0.0, tint=1.0)
    bays = (-3.6, 3.6)

    def hole(cx, cz, hx, hz):
        for ax in bays:
            dx = abs(cx - ax)
            if cz - hz < 1.4 + 2.2:
                if dx - hx < 1.2 + 0.5:
                    return True
            elif math.hypot(max(dx - hx, 0.0), max(cz - 3.6 - hz, 0.0)) < 1.2 + 0.58:
                return True
        dx = abs(cx)
        if cz - hz < 1.4 + 2.7:
            return dx - hx < 0.75 + 0.45
        return math.hypot(max(dx - hx, 0.0), max(cz - 4.1 - hz, 0.0)) < 0.75 + 0.5
    courses(P, -RIVER_HW - 0.2, RIVER_HW + 0.2, 1.4, CREST - 0.35, Y_S, 0.9, -1, hole=hole, hmin=0.45, hmax=0.62, wmin=0.9, wmax=1.7)
    # sluice bays: dark back, wedge arch rings, jambs, imposts, the timber gate half raised
    for ax in bays:
        core(P, (ax, Y_S + 0.05, 1.4 + 1.5), (2.8, 0.4, 3.0), tint=0.28)
        arch(P, ax, 3.6, 1.2, 0.5, 1.0, y=Y_S - 0.45, n=9)
        for sx in (-1, 1):
            block(P, "stone", (ax + sx * 1.45, Y_S - 0.45, 1.4 + 1.1), (0.55, 1.0, 2.2), ch=0.04, jit=0.01)
            block(P, "stone", (ax + sx * 1.3, Y_S - 0.45, 3.6 - 0.1), (0.62, 1.1, 0.24), ch=0.04, jit=0.006)
        gate(P, ax)
    # the Order's niche between them: a pointed recess, a carved glyph, a bracket, a plinth for offerings
    core(P, (0, Y_S + 0.05, 1.4 + 1.5), (1.7, 0.4, 3.0), tint=0.28)
    arch(P, 0.0, 4.1, 0.75, 0.38, 0.9, y=Y_S - 0.45, n=7)
    for sx in (-1, 1):
        block(P, "stone", (sx * 1.0, Y_S - 0.45, 1.4 + 1.35), (0.45, 0.9, 2.7), ch=0.04, jit=0.01)
    block(P, "stone", (0, Y_S - 0.35, 1.4 + 0.45), (1.1, 0.7, 0.5), ch=0.05, jit=0.01, tint=1.0)       # the offering plinth
    W.cyl(P, "iron", (0.0, Y_S - 0.38, 1.4 + 0.74), (0.0, Y_S - 0.38, 1.4 + 0.9), 0.26, 0.2, seg=12)    # the bowl on it
    glyph(P, (0.0, Y_S - 0.95, 4.35), 0.0)
    # the string course and the coped edge
    block(P, "stone", (0, Y_S - 0.62, CREST - 0.5), (2 * RIVER_HW + 0.6, 0.45, 0.28), ch=0.05, jit=0.0, tint=1.0)
    for sy, y in ((-1, Y_S), (1, Y_C)):
        n = 8
        for i in range(n):
            xa = -RIVER_HW + (2 * RIVER_HW) * i / n
            block(P, "stone", (xa + RIVER_HW / n, y + sy * 0.1, CREST - 0.15), (2 * RIVER_HW / n - 0.04, 0.55, 0.3), ch=0.05, jit=0.012)
    # the crest paving: flags, a few lifted or gone, clear of the bowl
    gx = -RIVER_HW
    while gx < RIVER_HW - 0.1:
        gw = min(RNG.uniform(1.3, 2.0), RIVER_HW - gx)
        gy = Y_S + 0.35
        while gy < Y_C - 0.35:
            gl = min(RNG.uniform(1.0, 1.6), Y_C - 0.35 - gy)
            cx, cy = gx + gw * 0.5, gy + gl * 0.5
            if gl > 0.25 and math.hypot(cx - BOWL[0], cy - BOWL[1]) > BOWL_R + 0.55 and RNG.random() > 0.08:
                block(P, "stone", (cx, cy, CREST - 0.12), (gw - 0.05, gl - 0.05, 0.24), pitch=RNG.uniform(-0.02, 0.02), ch=0.025, jit=0.01)
            gy += gl
        gx += gw
    # the bowl: a broken lip of stones round the scoured hollow the water stands up out of; one stone gone at the north
    n = 13
    for i in range(n):
        a = math.pi * 0.5 + math.tau * (i + 0.5) / n
        if i in (0, n - 1):
            continue
        h = RNG.uniform(0.35, 0.95)
        p = (BOWL[0] + math.cos(a) * BOWL_R, BOWL[1] + math.sin(a) * BOWL_R)
        block(P, "stone", (p[0], p[1], CREST + h * 0.5 - 0.05), (1.25, 0.78, h), yaw=a + math.pi * 0.5, pitch=RNG.uniform(-0.12, 0.12), roll=RNG.uniform(-0.1, 0.1), ch=0.06, jit=0.035)
        LIP.append(((p[0], p[1], CREST + h * 0.5 - 0.05), (1.25, 0.78, h), a + math.pi * 0.5))
    for i in range(4):                                                       # stones fallen out of the lip
        a = RNG.uniform(0, math.tau)
        block(P, "stone", (BOWL[0] + math.cos(a) * 3.8, BOWL[1] + math.sin(a) * 3.0, CREST + 0.2), (0.9, 0.7, 0.45), yaw=RNG.uniform(0, 3), pitch=RNG.uniform(-0.3, 0.3), ch=0.05, jit=0.03)
    # wear at the foot of the south wall: green-black water line is in the vertex tone (z < 2); weed-lipped stones lie in the pool
    rubble_pile(P, (-2.0, Y_S - 3.4), 6, 2.4, (0.4, 0.8), ground=0.3)
    rubble_pile(P, (3.5, Y_S - 3.8), 5, 2.4, (0.4, 0.8), ground=0.3)


def glyph(P, c, yaw):
    """The Order's glyph cut proud on a roundel: a ring of small blocks, three rays and a boss (facing south)."""
    x, y, z = c
    r = 0.46
    for i in range(12):
        a = math.tau * i / 12
        block(P, "stone", (x + math.cos(a) * r, y, z + math.sin(a) * r), (0.15, 0.12, 0.15), yaw=0.0, roll=-a, ch=0.02, jit=0.0, tint=1.15)
    for a in (math.pi * 0.5, math.pi * 0.5 + math.tau / 3, math.pi * 0.5 + 2 * math.tau / 3):
        for j in range(1, 3):
            block(P, "stone", (x + math.cos(a) * 0.2 * j, y, z + math.sin(a) * 0.2 * j), (0.13, 0.14, 0.13), ch=0.015, jit=0.0, tint=1.15)
    block(P, "stone", (x, y, z), (0.24, 0.2, 0.24), ch=0.03, jit=0.0, tint=1.2)


def gate(P, ax):
    """A sluice gate in its bay: vertical planks, iron straps, a lifting bar, raised askew and left."""
    y = Y_S - 0.12
    zb = 1.4 + 0.9
    for i in range(5):
        block(P, "timber", (ax - 0.96 + i * 0.48, y, zb + 1.35), (0.45, 0.13, 2.5 + RNG.uniform(-0.12, 0.12)), roll=0.012, ch=0.015, jit=0.008)
    for z in (0.5, 1.5, 2.3):
        block(P, "iron", (ax, y - 0.08, zb + z), (2.45, 0.05, 0.12), ch=0.01, jit=0.0)
    block(P, "iron", (ax, y - 0.1, zb + 2.8), (0.14, 0.08, 0.7), ch=0.01, jit=0.0)
    W.cyl(P, "iron", (ax - 0.32, y - 0.16, zb + 3.2), (ax + 0.32, y - 0.16, zb + 3.2), 0.07, seg=8)


def build_wings(P):
    """Wing walls to the banks, stepping down; the east one fallen at its middle. Coursed both faces, coped."""
    for sx in (-1, 1):
        x_a = RIVER_HW + 0.2
        segs = [(6.8, 12.0, CREST - 0.3), (12.0, 15.6, 3.7), (15.6, WING, 2.7)] if sx < 0 else [(6.8, 10.6, CREST - 0.3), (10.6, 12.6, 3.4), (12.6, 14.4, 2.2)]
        for (a, b, top) in segs:
            xa, xb = (-b, -a) if sx < 0 else (a, b)
            core(P, ((xa + xb) / 2, 0.0, (FOOT + top) / 2), (b - a, Y_C - Y_S - 0.2, top - FOOT), tint=0.45)
            for face, y in ((-1, Y_S), (1, Y_C)):
                courses(P, xa, xb, FOOT + 0.3, top, y, 0.5, face, hmin=0.5, hmax=0.65, wmin=1.0, wmax=1.7)
            n = max(2, int((b - a) / 1.6))
            for i in range(n):
                xx = xa + (xb - xa) * (i + 0.5) / n
                block(P, "stone", (xx, 0.0, top + 0.12), ((xb - xa) / n - 0.03, Y_C - Y_S + 0.3, 0.26), ch=0.05, jit=0.012)
        xe = -WING if sx < 0 else 14.4
        coursed_end(P, xe, Y_S, Y_C, FOOT + 0.3, (2.7 if sx < 0 else 2.2), 1 if sx > 0 else -1, 0.5)
    # the east wing's torn end: stones thin out toward the bank, fallen into the water
    for k in range(10):
        block(P, "stone", (RNG.uniform(11.0, 15.5), RNG.uniform(Y_S, Y_C), RNG.uniform(1.8, 3.0)), (RNG.uniform(0.6, 1.3), RNG.uniform(0.6, 1.2), RNG.uniform(0.4, 0.8)),
              yaw=RNG.uniform(0, 3), pitch=RNG.uniform(-0.3, 0.3), ch=0.05, jit=0.05)
    rubble_pile(P, (13.0, 0.5), 9, 1.8, (0.5, 1.0))
    rubble_pile(P, (-27.0, -7.5), 5, 2.0, (0.4, 0.9))
    # cutwaters: pointed prows on the upstream face where the wings meet the steps
    for sx in (-1, 1):
        xs = sx * (RIVER_HW + 0.7)
        co = {}
        for a in (0, 1):
            for b in (0, 1):
                for c in (0, 1):
                    if b == 0:
                        co[(a, b, c)] = (xs + (a - 0.5) * 2.0, Y_C, FOOT if c == 0 else 3.6)
                    else:
                        co[(a, b, c)] = (xs, Y_C + 2.6, FOOT if c == 0 else 2.4)
        hexa(P, "stone", co, ch=0.0, jit=0.0, tint=0.95)
        for i in range(5):
            block(P, "stone", (xs, Y_C + 0.6 + i * 0.35, 3.62 - i * 0.28), (1.4 - i * 0.24, 0.5, 0.2), ch=0.03, jit=0.0, tint=1.0)


def build_house(P):
    """The keeper's sluice-house on the west bank: ashlar walls, a door under the Order's lintel, a pitched slate roof."""
    cx, cy = -23.0, -3.4
    w, d, h = 5.6, 4.6, 3.0
    zb = 0.3
    core(P, (cx, cy, (FOOT + h) / 2), (w - 0.2, d - 0.2, h - FOOT), tint=0.45)
    courses(P, cx - w / 2, cx + w / 2, FOOT + 0.3, h, cy - d / 2, 0.5, -1, gaps=[(cx - 0.75, cx + 0.75, 2.3 + zb)], hmin=0.45, hmax=0.6, wmin=0.8, wmax=1.5)
    courses(P, cx - w / 2, cx + w / 2, FOOT + 0.3, h, cy + d / 2, 0.5, 1, hmin=0.45, hmax=0.6, wmin=0.8, wmax=1.5)
    coursed_end(P, cx - w / 2, cy - d / 2, cy + d / 2, FOOT + 0.3, h, -1, 0.5)
    coursed_end(P, cx + w / 2, cy - d / 2, cy + d / 2, FOOT + 0.3, h, 1, 0.5)
    # the door and its glyph lintel
    block(P, "timber", (cx, cy - d / 2 - 0.1, zb + 1.1), (1.3, 0.16, 2.2), ch=0.02, jit=0.008)
    for z in (0.5, 1.7):
        block(P, "iron", (cx, cy - d / 2 - 0.2, zb + z), (1.3, 0.05, 0.13), ch=0.01, jit=0.0)
    for sx in (-1, 1):
        block(P, "stone", (cx + sx * 0.85, cy - d / 2 - 0.2, zb + 1.2), (0.4, 0.5, 2.5), ch=0.04, jit=0.01)
    block(P, "stone", (cx, cy - d / 2 - 0.22, zb + 2.5), (2.2, 0.55, 0.42), ch=0.05, jit=0.008, tint=1.0)
    glyph(P, (cx, cy - d / 2 - 0.55, zb + 2.5), 0.0)
    block(P, "stone", (cx, cy - d / 2 - 0.5, zb - 0.05), (1.8, 0.8, 0.2), ch=0.04, jit=0.01)          # the doorstep
    # a shuttered slit on the north, a stack on the west gable
    block(P, "stone", (cx - 1.2, cy + d / 2 + 0.28, 1.9), (0.6, 0.1, 0.9), ch=0.02, jit=0.0, tint=0.3)
    block(P, "stone", (cx - w / 2 + 0.6, cy + 0.6, h + 1.4), (0.8, 0.8, 3.2), ch=0.04, jit=0.012)
    block(P, "stone", (cx - w / 2 + 0.6, cy + 0.6, h + 3.1), (1.0, 1.0, 0.2), ch=0.04, jit=0.006, tint=1.0)
    # the gable ends: stepped courses narrowing to the ridge, so the roof closes on both ends
    rise = 2.2
    zg = h
    while zg < h + rise - 0.1:
        gw = d * (1.0 - (zg + 0.3 - h) / rise) - 0.15
        if gw > 0.3:
            for sx in (-1, 1):
                block(P, "stone", (cx + sx * (w / 2 - 0.1), cy, zg + 0.27), (0.5, gw, 0.52), ch=0.03, jit=0.01)
        zg += 0.5
    # the roof: courses of slates, a ridge, eaves proud; each slope tilted about the ridge
    half = d / 2 + 0.5
    ang = math.atan2(rise, d / 2)
    rows = 9
    for sy in (-1, 1):
        for r in range(rows):
            t = (r + 0.5) / rows
            dist = half * (1.0 - t * 0.98)
            slope_len = half / math.cos(ang) / rows
            n = 11
            for i in range(n):
                xx = cx - w / 2 - 0.4 + (w + 0.8) * (i + 0.5) / n
                zz = h + rise * (t if True else 0.0) * 1.0 + 0.02
                yy = cy + sy * (half * (1.0 - t))
                block(P, "timber", (xx, yy, h + 0.1 + (rise + 0.25) * t), ((w + 0.8) / n + 0.04, slope_len * 1.25, 0.09), pitch=-sy * ang, ch=0.0, jit=0.006, tint=RNG.uniform(0.55, 0.85))
    block(P, "stone", (cx, cy, h + rise + 0.35), (w + 0.9, 0.34, 0.2), ch=0.03, jit=0.008, tint=0.9)
    # barrels and a boat hook against the wall
    rubble_pile(P, (cx + 3.4, cy - 1.0), 3, 1.0, (0.3, 0.5), ground=0.9)


def build_collision(P):
    """Boxes: the body, the steps, the wings, the house, the bowl's lip as one low ring."""
    W.box(P, "stone", (0, (Y_S + Y_C) / 2, (FOOT + CREST) / 2), (2 * RIVER_HW + 0.2, Y_C - Y_S, CREST - FOOT))
    for k, zt in enumerate(STEP_TOPS):
        y1 = Y_C + TREAD * (N_STEP - k)
        W.box(P, "stone", (0, y1 - TREAD * 0.5, (FOOT + zt) / 2), (2 * RIVER_HW + 0.2, TREAD, zt - FOOT))
    for sx in (-1, 1):
        segs = [(6.8, 12.0, CREST), (12.0, 15.6, 3.7), (15.6, WING, 2.7)] if sx < 0 else [(6.8, 10.6, CREST), (10.6, 12.6, 3.4), (12.6, 14.4, 2.2)]
        for (a, b, top) in segs:
            xc = -(a + b) / 2 if sx < 0 else (a + b) / 2
            W.box(P, "stone", (xc, 0.0, (FOOT + top) / 2), (b - a, Y_C - Y_S, top - FOOT))
        W.box(P, "stone", (sx * (RIVER_HW + 1.2), Y_C + 1.0, (FOOT + 3.0) / 2), (1.6, 2.0, 3.0 - FOOT))
    W.box(P, "stone", (-23.0, -3.4, (FOOT + 3.0) / 2), (5.6, 4.6, 3.0 - FOOT))
    W.box(P, "stone", (-23.0, -3.4, 4.4), (5.6, 1.6, 2.8))
    for (c, size, yaw) in LIP:
        W.box(P, "stone", c, size, yaw=yaw)


def build_far():
    """The silhouette in about a thousand triangles."""
    P = W.Parts()
    W.box(P, "stone", (0, (Y_S + Y_C) / 2, (FOOT + CREST) / 2), (2 * RIVER_HW + 0.6, Y_C - Y_S + 0.4, CREST - FOOT))
    for k, zt in enumerate(STEP_TOPS):
        y1 = Y_C + TREAD * (N_STEP - k)
        W.box(P, "stone", (0, y1 - TREAD * 0.5, (FOOT + zt) / 2), (2 * RIVER_HW + 0.4, TREAD, zt - FOOT))
    for sx in (-1, 1):
        segs = [(6.8, 12.0, CREST), (12.0, 15.6, 3.7), (15.6, WING, 2.7)] if sx < 0 else [(6.8, 10.6, CREST), (10.6, 12.6, 3.4), (12.6, 14.4, 2.2)]
        for (a, b, top) in segs:
            xc = -(a + b) / 2 if sx < 0 else (a + b) / 2
            W.box(P, "stone", (xc, 0.0, (FOOT + top) / 2), (b - a, Y_C - Y_S + 0.3, top - FOOT))
    W.box(P, "stone", (-23.0, -3.4, (FOOT + 3.0) / 2), (5.8, 4.8, 3.0 - FOOT))
    W.box(P, "stone", (-23.0, -3.4, 4.2), (5.8, 3.0, 2.4), pitch=0.0)
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
                if t <= 0.001:
                    t = 0.85                       # a vertex the block pass did not reach: never black
                # damp stonework at the water line: a green-black band (the pond's reach) and the spray's wet above the foot
                gain = 0.85 if key == "stone" else 1.0       # the night grade eats stone: the tone is baked lighter
                l[col] = (min(1.0, c[0] * t * gain), min(1.0, c[1] * t * gain), min(1.0, c[2] * t * gain), 1.0)
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


def standin_water(sc):
    """For the turnaround only: the river climbing the steps, the bowl, the rising sheet and its lean (the game's
    shaders do the real thing), so the composition can be judged."""
    mat = bpy.data.materials.new("water_standin")
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bs = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bs.inputs["Base Color"].default_value = (0.55, 0.82, 1.0, 1.0)
    bs.inputs["Emission Color"].default_value = (0.55, 0.82, 1.0, 1.0)
    bs.inputs["Emission Strength"].default_value = 2.2
    bs.inputs["Alpha"].default_value = 0.45
    nt.links.new(bs.outputs[0], out.inputs[0])
    try:
        mat.surface_render_method = 'BLENDED'
    except Exception:
        mat.blend_method = 'BLEND'

    def mesh_from(name, verts, quads, alphas):
        me = bpy.data.meshes.new(name)
        bm = bmesh.new()
        vs = [bm.verts.new(v) for v in verts]
        for q in quads:
            bm.faces.new([vs[i] for i in q])
        lay = bm.loops.layers.color.new("A")
        for f in bm.faces:
            for l in f.loops:
                a = alphas[l.vert.index] if l.vert.index < len(alphas) else 1.0
                l[lay] = (a, a, a, 1.0)
        bm.to_mesh(me)
        bm.free()
        me.materials.append(mat)
        ob = bpy.data.objects.new(name, me)
        sc.collection.objects.link(ob)
        return ob
    # the water climbing the steps (tapering toward the bowl)
    verts, quads, al = [], [], []
    pts = [(Y_C + TREAD * N_STEP + 0.8, 0.65)]
    for k, zt in enumerate(STEP_TOPS):
        y1 = Y_C + TREAD * (N_STEP - k)
        pts.append((y1 - 0.05, zt + 0.08))
        pts.append((y1 - TREAD + 0.15, zt + 0.08))
    pts.append((Y_C - 0.2, CREST + 0.1))
    pts.append((BOWL[1] + BOWL_R * 0.7, CREST + 0.1))
    for i, (y, z) in enumerate(pts):
        f = i / (len(pts) - 1)
        hw = (5.6 - 3.2 * max(0.0, (f - 0.4) / 0.6)) * (1.0 if i > 0 else 0.9)
        verts += [(-hw, y, z), (hw, y, z)]
        al += [0.85, 0.85]
        if i > 0:
            b = (i - 1) * 2
            quads.append((b, b + 1, b + 3, b + 2))
    mesh_from("climb", verts, quads, al)
    # the bowl's disc
    verts, quads, al = [], [], []
    verts.append((BOWL[0], BOWL[1], CREST + 0.14))
    al.append(1.0)
    for i in range(24):
        a = math.tau * i / 24
        verts.append((BOWL[0] + math.cos(a) * 2.05, BOWL[1] + math.sin(a) * 2.05, CREST + 0.14))
        al.append(0.8)
    for i in range(24):
        quads.append((0, 1 + i, 1 + (i + 1) % 24))
    mesh_from("bowl", verts, [q for q in quads], al)
    # the sheet: three planes, tapering, leaning south and east, fading out at the top
    for yaw in (0.0, 1.05, 2.1):
        verts, quads, al = [], [], []
        H = 66.0
        n = 24
        for i in range(n + 1):
            t = i / n
            h = H * t
            lean = Vector((5.0 * t * t, -15.0 * t * t, 0.0))
            w = 1.7 * (1 + 0.7 * min(1.0, h / 16.0)) * (1.0 - 0.6 * max(0.0, (t - 0.4) / 0.6))
            ax = Vector((math.cos(yaw), math.sin(yaw), 0.0))
            c = Vector((BOWL[0], BOWL[1], CREST + 0.15 + h)) + lean
            verts += [tuple(c - ax * w), tuple(c + ax * w)]
            a = (0.75 if t < 0.15 else 0.75 * (1.0 - (t - 0.15) / 0.85) ** 1.3)
            al += [a, a]
            if i > 0:
                b = (i - 1) * 2
                quads.append((b, b + 1, b + 3, b + 2))
        mesh_from("sheet%.1f" % yaw, verts, quads, al)


def main():
    W.reset()
    P = W.Parts()
    build_steps(P)
    build_body(P)
    build_wings(P)
    build_house(P)
    objs = finish(P, "Weir")
    PC = W.Parts()
    build_collision(PC)
    col = W.finish(PC, "WeirCol")
    for o in col:
        o.name = "Weir-colonly"
        o.data.name = o.name
        o.data.materials.clear()
    tri = sum(W.tris(o) for o in objs)
    print("TRIS near", tri, {o.name: W.tris(o) for o in objs})
    if not NO_EXPORT:
        W.export(objs + col, os.path.join(MODELS, "upward_falls.glb"), "upward falls")
        FP = build_far()
        far = finish(FP, "WeirFar")
        W.export(far, os.path.join(MODELS, "upward_falls_far.glb"), "upward falls far")
        for o in far:
            bpy.data.objects.remove(o)
    standin_water(bpy.context.scene)
    render_turnaround(objs, "weir", [
        ((34, -38, 10), (0, 2, 4), 30),            # from the south-east, the pool
        ((32, 44, 12), (0, 2, 4), 30),             # from the north-east
        ((-36, 40, 10), (-6, 2, 4), 32),           # from the north-west (the house)
        ((-40, -32, 8), (-8, 0, 3), 34),           # from the south-west
        ((0, 46, 7), (0, 4, 7), 34),               # head on, up the steps
        ((0, -17, 4), (0, -2.6, 3.0), 45),         # the south wall close
        ((7, -10, 7.5), (0, 0, 7), 58),            # the crest
        ((150, -230, 18), (0, 0, 30), 26),         # from afar, the column
        ((-30, -12, 3), (-23, -3.4, 3), 40),           # the sluice-house
        ((0, 18, 14), (0, 0, 8), 40),              # above the steps, down onto the bowl
    ], size=(1280, 720))


if __name__ == "__main__":
    main()
