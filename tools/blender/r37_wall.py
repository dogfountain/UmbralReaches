"""The March Wall kit (tools/blender/r37_south.py build_wall calls build() here).

A wall that is read from a day's walk away and from two paces. Local frame of every wall part: x along the wall, +z the
outer face (towards the March), y up, the origin on the ground at the middle of the part; towers and the gate are
centred on the line of the wall.

  WallSeg_A  the standard bay 12 m long: a battered, coarse-stoned footing, a weathered water table, the body, a string course,
             a corbel table under an oversailing parapet with crenels and merlons, a buttress at the middle, arrow loops
  WallSeg_B  the same bay with pilaster strips, a repaired patch of another stone and two merlons down
  WallSeg_C  the half-fallen bay: the upper wall down on one side, its stones at the foot
  WallSeg_D  the stair bay (Weirford's face): a landing under a door in the parapet, no corbels over it
  Tower      a square tower that stands 3.5 m forward of the curtain and 7 m above its walk: batter, quoins, string
             courses, corbels and a parapet of its own, a stair turret with a roof
  TowerRuin  the same tower broken
  Gatehouse  twin drum towers, a deep pointed passage of voussoirs and ribs, a portcullis in its slot, a machicolated
             gallery over the arch, a crest
  BreachStub the standing end of a breach (the gap end is +x): the wall stepping down through its core to rubble
  Rubble     a tumbled fan of ashlar, merlons and corbels
  WallStair  Weirford's stair up the wall's face to the landing of WallSeg_D (the top at x = 0, descending to +x)
  WallShed   a timber lean-to against the wall's foot
  WallFar TowerFar GateFar  the silhouettes
"""
import math
import os
import importlib
from mathutils import Vector, Matrix
import r37_south_lib as L
import r37_wall_lib as WL
importlib.reload(WL)
from r37_wall_lib import W, rng, lerp, clamp

LEN = 12.0
WALK = 7.75                     # the wall walk's height
SILL = 1.05
MH = 0.95
CREST = WALK + SILL + MH + 0.12
FACE = 1.42                     # the outer face of the body at the string course
INNER = -1.28                   # the inner face at the walk
Y0 = WALK - 1.2                 # the corbels start here (they rise 0.9, the slab 0.3)

# tower
TS = 8.4                        # width of the tower shaft at its foot's top
TD = 8.4
TZC = 0.9                       # the tower's centre sits this far forward of the line
T_PLINTH = 2.6
T_SHAFT_TOP = 13.2              # the corbels start here
T_WALK = T_SHAFT_TOP + 1.2      # the tower's deck
T_TOP = T_WALK + SILL + MH + 0.12


def half_t(y):
    """Half the tower shaft's width at height y (the batter)."""
    return lerp(4.2, 3.75, clamp((y - T_PLINTH) / (T_SHAFT_TOP - T_PLINTH), 0.0, 1.0)) if y > T_PLINTH else lerp(4.7, 4.28, y / T_PLINTH)


def tints():
    return {
        "damp": (0.82, 0.86, 0.86), "pale": (1.0, 0.98, 0.94), "warm": (1.0, 0.9, 0.78), "dark": (0.7, 0.72, 0.74),
        "core": (0.62, 0.62, 0.66), "plain": (0.92, 0.92, 0.92),
    }


# =================================================================================================
# the curtain
# =================================================================================================

def outer_z(y):
    """The outer face of the curtain at height y (the batter, from the footing to the string course)."""
    if y <= 1.9:
        return lerp(2.15, 1.78, y / 1.9)
    if y <= 2.3:
        return 1.9
    return lerp(1.56, FACE, clamp((y - 2.3) / 3.7, 0.0, 1.0))


def inner_z(y):
    if y <= 1.9:
        return lerp(-1.85, -1.55, y / 1.9)
    return lerp(-1.5, INNER, clamp((y - 2.3) / 3.7, 0.0, 1.0))


def wall_courses(b, x0, x1, h, T, seed, jit=0.045, ends_fixed=True):
    """The curtain's body from the ground to height h (clipped inside the body zone <= 6.0; above that the belt and upper wall)."""
    # footing: the coarse battered plinth, big stones
    top = min(h, 1.9)
    prof = [(-1.85, 0.0), (2.15, 0.0), (outer_z(top), top), (inner_z(top), top)]
    b.prism_x(prof, x0, x1, "stone", uv=0.6, tint=T["damp"], jit=jit, seed=seed)
    if h <= 1.9:
        return
    # the water table: a weathered ledge, the footing's cap
    top = min(h, 2.3)
    prof = [(inner_z(1.9), 1.9), (1.78, 1.9), (1.92, 1.96), (1.92, 2.06), (outer_z(top), top), (inner_z(top), top)] if top >= 2.3 else \
           [(inner_z(1.9), 1.9), (1.78, 1.9), (1.92, 1.96), (1.92, 2.06), (1.92, top), (inner_z(top), top)]
    b.prism_x(prof, x0, x1, "stone", uv=1.0, tint=T["pale"], jit=jit * 0.6, seed=seed + 1)
    if h <= 2.3:
        return
    top = min(h, 6.0)
    prof = [(inner_z(2.3), 2.3), (outer_z(2.3), 2.3), (outer_z(top), top), (inner_z(top), top)]
    b.prism_x(prof, x0, x1, "stone", uv=1.0, tint=T["plain"], jit=jit, seed=seed + 2)


def belt_and_upper(b, x0, x1, T, seed):
    """The string course (a drip moulding under the corbel table) and the wall behind the corbels up to the walk."""
    prof = [(INNER, 6.0), (FACE, 6.0), (1.68, 6.14), (1.68, 6.34), (1.52, 6.5), (INNER, 6.5)]
    b.prism_x(prof, x0, x1, "stone", uv=1.5, tint=T["pale"], jit=0.025, seed=seed + 3)
    prof = [(INNER, 6.5), (1.5, 6.5), (FACE, WALK), (INNER, WALK)]
    b.prism_x(prof, x0, x1, "stone", uv=1.25, tint=T["dark"], jit=0.03, seed=seed + 4)          # soot under the corbels


def inner_face(b, x0, x1, T, seed, strips=(-4.2, 0.0, 4.2)):
    """The inner face: pilaster strips and a low kerb on the walk's edge."""
    for k, x in enumerate(strips):
        b.box((x, 3.1, INNER - 0.1), (0.62, 6.1, 0.22), "stone", uv=1.1, tint=T["pale"], jit=0.015, cuts=2)
        b.box((x, 6.18, INNER - 0.14), (0.8, 0.3, 0.3), "stone", uv=1.4, tint=T["pale"], jit=0.01)
    b.box(((x0 + x1) / 2, WALK + 0.27, INNER + 0.22), (x1 - x0, 0.54, 0.44), "stone", uv=1.3, tint=T["plain"], jit=0.01, cuts=3)


def loop(b, x, y, T, seed, h=1.35):
    """An arrow loop: a dressed surround and the slot, on the outer face at height y."""
    z = outer_z(y)
    b.box((x, y, z - 0.02), (0.15, h, 0.14), "dark", cuts=0)
    for sx in (-1, 1):
        b.box((x + sx * 0.2, y, z + 0.01), (0.2, h + 0.4, 0.14), "stone", uv=1.6, tint=T["pale"], jit=0.01, cuts=0)
    b.box((x, y + h / 2 + 0.22, z + 0.02), (0.62, 0.22, 0.17), "stone", uv=1.6, tint=T["pale"], jit=0.01, cuts=0)
    b.box((x, y - h / 2 - 0.2, z + 0.04), (0.66, 0.16, 0.22), "stone", uv=1.6, tint=T["pale"], jit=0.01, cuts=0)
    b.box((x, y, z - 0.09), (0.34, h + 0.1, 0.06), "dark", cuts=0)


def buttress(b, x, wdt, T, seed, top=6.2):
    prof = [(1.3, 0.0), (3.1, 0.0), (2.92, 1.6), (2.5, 3.4), (2.2, 5.0), (2.12, top - 0.35), (1.58, top + 0.15), (1.3, top + 0.15)]
    b.prism_x(prof, x - wdt / 2, x + wdt / 2, "stone", uv=1.0, tint=T["plain"], jit=0.035, seed=seed, xstep=1.3)
    # the weathering cap: a sloped coping stone
    b.box((x, top - 0.12, 2.0), (wdt + 0.14, 0.2, 0.9), "stone", uv=1.5, tint=T["pale"], jit=0.01, cuts=0, pitch=0.45)


def pilaster(b, x, T, seed):
    prof = [(1.3, 0.0), (2.4, 0.0), (2.18, 1.9), (1.78, 2.0), (1.7, 6.0), (1.3, 6.0)]
    b.prism_x(prof, x - 0.3, x + 0.3, "stone", uv=1.2, tint=T["pale"], jit=0.015, seed=seed, xstep=1.3, dens=1.0)


def bay(name, kind, seed, mats):
    T = tints()
    b = W(name, mats, seed, damp=1.0)
    x0, x1 = -LEN / 2, LEN / 2
    # the foundation below the ground (hidden except on a slope)
    b.box((0, -1.8, 0), (LEN + 0.3, 3.4, 4.5), "stone", uv=0.6, tint=T["damp"], cuts=2, jit=0.02)
    if kind == "C":
        # the ruin: the left half stands, the right half is down to a broken core
        wall_courses(b, x0, 0.4, 6.0, T, seed)
        belt_and_upper(b, x0, 0.4, T, seed)
        b.battlement([("line", (x0, FACE), (0.4, FACE))], Y0, (0, -4), seed, tint=T["dark"], mer_tint=T["plain"], pitch=2.0)
        inner_face(b, x0, 0.4, T, seed, strips=(-4.2,))
        r = rng(seed)
        # the broken half: stepped, ragged, the core showing (no outer face to speak of at the top)
        hs = [(0.4, 1.8, 5.4), (1.8, 3.2, 4.4), (3.2, 4.6, 3.1), (4.6, 6.0, 2.2)]
        for i, (xa, xb, hh) in enumerate(hs):
            wall_courses(b, xa, xb, hh, T, seed + 10 * i, jit=0.09)
            tc = hh
            prof = [(inner_z(min(tc, 6.0)) if tc > 2.3 else -1.55, tc), (outer_z(min(tc, 6.0)) if tc > 2.3 else 1.78, tc), (outer_z(min(tc, 6.0)) - 0.5, tc + r.uniform(0.3, 0.7)), (inner_z(min(tc, 6.0)) + 0.4, tc + r.uniform(0.2, 0.7))]
            b.prism_x(prof, xa, xb, "stone", uv=1.0, tint=T["core"], jit=0.14, seed=seed + 40 + i, xstep=0.7, dens=0.7)
        loop(b, -3.6, 4.0, T, seed)
        loop(b, -2.0, 4.0, T, seed)
        # the fallen: heaps at the foot of the outer face and some inside
        heap(b, 3.1, 3.4, 11, 3.0, 1.15, seed + 60, T)
        heap(b, 2.0, -3.0, 6, 1.7, 0.8, seed + 61, T)
        return b.finish()
    wall_courses(b, x0, x1, 6.0, T, seed)
    belt_and_upper(b, x0, x1, T, seed)
    skip = ()
    gaps = ()
    if kind == "D":
        gaps = ((0, 5.0, 7.2),)
    if kind == "B":
        skip = (2, 3)
    b.battlement([("line", (x0, FACE), (x1, FACE))], Y0, (0, -4), seed, skip=skip, gaps=gaps, tint=T["dark"], mer_tint=T["plain"], pitch=2.0)
    inner_face(b, x0, x1, T, seed, strips=(-4.2, 0.0, 4.2))
    if kind == "A":
        buttress(b, 0.0, 1.3, T, seed + 7)
        loop(b, -3.5, 3.9, T, seed)
        loop(b, 3.5, 3.9, T, seed)
    elif kind == "E":
        # the other plain bay: two slender buttresses off the middle, one loop between them, a repaired course low down
        buttress(b, -2.6, 0.9, T, seed + 7)
        buttress(b, 3.4, 0.9, T, seed + 8)
        loop(b, 0.4, 4.1, T, seed)
        loop(b, -4.6, 3.8, T, seed)
        b.box((-0.5, 3.2, outer_z(3.2) + 0.0), (5.6, 0.7, 0.14), "stone", uv=1.2, tint=T["warm"], jit=0.03, cuts=3)
    elif kind == "B":
        pilaster(b, -2.3, T, seed + 7)
        pilaster(b, 2.3, T, seed + 8)
        loop(b, 0.0, 4.0, T, seed)
        loop(b, -4.6, 3.9, T, seed)
        # a repair: the wall rebuilt in squarer, warmer stone
        b.box((3.9, 3.3, outer_z(3.3) - 0.01), (3.0, 4.4, 0.12), "stone", uv=1.7, tint=T["warm"], jit=0.03, cuts=3)
        b.box((-4.1, 1.1, outer_z(1.1) + 0.02), (3.4, 1.2, 0.16), "stone", uv=0.9, tint=T["warm"], jit=0.03, cuts=3)
        # the table has a gap where the parapet fell: loose merlons on the walk
        r = rng(seed)
        for k in range(3):
            b.box((r.uniform(-0.8, 0.8) + k * 0.5, WALK + 0.35, r.uniform(-0.2, 0.7)), (1.0, 0.7, 0.55), "stone", uv=1.3, tint=T["plain"], yaw=r.uniform(0, 3), jit=0.03)
    elif kind == "D":
        buttress(b, -5.3, 1.1, T, seed + 7)
        buttress(b, 5.3, 1.1, T, seed + 8)
        loop(b, -3.6, 3.9, T, seed)
        loop(b, 3.6, 3.9, T, seed)
        # the landing: a slab on three stepped brackets out from the face, the stair arriving at its outer edge (z 3.7);
        # a low wall on each side, the parapet door's jambs and lintel, a door leaf standing open on the walk
        b.box((0.0, WALK - 0.18, 2.55), (3.4, 0.36, 2.3), "stone", uv=1.4, tint=T["pale"], cuts=3, jit=0.012)
        for sx in (-1.1, 0.0, 1.1):
            for (ya, yb, pr) in ((WALK - 1.2, WALK - 0.8, 0.5), (WALK - 0.8, WALK - 0.4, 1.2), (WALK - 0.4, WALK - 0.18, 2.2)):
                b.box((sx, (ya + yb) / 2, FACE + pr / 2 - 0.1), (0.7, yb - ya, pr + 0.1), "stone", uv=1.5, tint=T["pale"], jit=0.01, cuts=0)
        for sx in (-1.0, 1.0):
            b.box((sx * 1.0, WALK + 1.05, FACE + 0.4), (0.4, 2.1, 0.9), "stone", uv=1.4, tint=T["pale"], jit=0.01, cuts=1)
            b.box((sx * 1.0, WALK + 2.18, FACE + 0.4), (0.5, 0.18, 1.0), "stone", uv=1.5, tint=T["pale"], jit=0.01, cuts=0)
            b.box((sx * 1.7, WALK + 0.45, 2.55), (0.34, 0.9, 2.3), "stone", uv=1.3, tint=T["plain"], jit=0.01, cuts=2)
        b.box((0.0, WALK + 2.38, FACE + 0.4), (2.6, 0.3, 1.0), "stone", uv=1.4, tint=T["pale"], jit=0.01, cuts=1)
        # the door leaf, held back along the inner parapet
        b.box((1.1, WALK + 1.1, INNER + 0.9), (0.14, 2.2, 1.4), "wood", uv=1.0, yaw=0.0, jit=0.0, cuts=0)
    return b.finish()


def heap(b, cx, cz, n, spread, hmax, seed, T, y0=0.0):
    r = rng(seed)
    for k in range(n):
        a = r.uniform(0, math.tau)
        d = r.uniform(0, spread) * r.uniform(0.3, 1.0)
        s = r.uniform(0.45, 1.0) * hmax
        hy = y0 + max(0.0, 1.0 - d / (spread * 1.15)) * hmax * 0.8 + s * 0.3
        t = T["plain"] if r.random() < 0.7 else T["warm"]
        b.box((cx + math.cos(a) * d, hy, cz + math.sin(a) * d * 0.75), (s * r.uniform(1.0, 1.7), s * r.uniform(0.6, 0.9), s * r.uniform(0.9, 1.4)), "stone", uv=r.choice((0.8, 1.0, 1.4)),
              tint=t, yaw=r.uniform(0, 3), pitch=r.uniform(-0.35, 0.35), roll=r.uniform(-0.35, 0.35), cuts=0 if s < 0.8 else 1, jit=0.05, seed=seed + k)


# =================================================================================================
# the tower
# =================================================================================================

def tower_outline(c=(0.0, TZC)):
    """The face line of the tower under its corbels: four runs, clockwise."""
    h = half_t(T_SHAFT_TOP)
    x0, x1 = c[0] - h, c[0] + h
    z0, z1 = c[1] - h, c[1] + h
    return [("line", (x0, z0), (x1, z0)), ("line", (x1, z0), (x1, z1)), ("line", (x1, z1), (x0, z1)), ("line", (x0, z1), (x0, z0))]


def quoins(b, cx, cz, y0, y1, T, seed, rect=True):
    r = rng(seed)
    n = int((y1 - y0) / 0.62)
    for i in range(n):
        y = y0 + 0.31 + i * 0.62
        h = half_t(y)
        for (sx, sz) in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            long_x = (i + (1 if sx * sz > 0 else 0)) % 2 == 0
            lx, lz = (1.0, 0.5) if long_x else (0.5, 1.0)
            b.box((cx + sx * (h - lx / 2 + 0.07), y, cz + sz * (h - lz / 2 + 0.07)), (lx, 0.58, lz), "stone", uv=1.4, tint=T["pale"], jit=0.012, cuts=0)


def grouped(b, fn, yaw, at):
    """Run fn (which builds at the origin, facing +z) and then turn what it made by yaw about y and move it to `at`."""
    n0 = len(b.bm.verts)
    fn()
    b.bm.verts.ensure_lookup_table()
    R = Matrix.Rotation(yaw, 3, 'Y')
    for v in list(b.bm.verts)[n0:]:
        v.co = R @ Vector(v.co) + Vector(at)


def arch_poly(cx, spring, w, y0):
    """The outline of a pointed opening from y0: the jambs to the springing, the two arcs to the crown."""
    n = 8
    left = []
    right = []
    for i in range(n + 1):
        th = math.pi - (math.pi / 3.0) * i / n
        left.append((cx + w / 2 + w * math.cos(th), spring + w * math.sin(th)))
        right.append((cx - w / 2 - w * math.cos(th), spring + w * math.sin(th)))
    return [(cx - w / 2, y0), (cx + w / 2, y0)] + right + list(reversed(left))[1:]


def pointed_door(b, cx, y0, w, h_side, T, seed, depth=0.3, steps=True, wood=True):
    """A pointed doorway in a wall face at z = 0 (the face looks +z): a ring of voussoirs standing 0.16 proud, jambs, the
    plank door set back, a step. Built at the origin: wrap it in grouped() to put it on a face."""
    spring = y0 + h_side
    za, zb = -depth, 0.16
    b.arch(cx, spring, w, 0.4, za, zb, "stone", uv=1.5, n=5, tint=T["pale"], seed=seed, jit=0.008, alt=0.05)
    for sx in (-1, 1):
        b.box((cx + sx * (w / 2 + 0.2), y0 + h_side / 2, (za + zb) / 2), (0.4, h_side, zb - za), "stone", uv=1.5, tint=T["pale"], jit=0.008, cuts=1)
    b.poly_z(arch_poly(cx, spring, w, y0), za + 0.04, za + 0.12, "wood" if wood else "dark", uv=1.0)
    if steps:
        b.box((cx, y0 + 0.08, zb + 0.35), (w + 0.9, 0.16, 0.7), "stone", uv=1.4, tint=T["pale"], jit=0.01, cuts=0)


def tower(name, ruin, seed, mats):
    T = tints()
    b = W(name, mats, seed)
    cz = TZC
    r = rng(seed)
    H = T_SHAFT_TOP if not ruin else 9.4
    # foundation
    b.box((0, -2.1, cz), (9.8, 4.0, 9.8), "stone", uv=0.6, tint=T["damp"], cuts=3, jit=0.03)
    # battered plinth: coarse stones
    b.frustum(0, cz, (4.75, 4.75), (4.3, 4.3), 0.0, T_PLINTH, "stone", uv=0.6, tint=T["damp"], jit=0.05, seed=seed, edge=1.35)
    # the plinth's cap (a weathered ledge)
    b.frustum(0, cz, (4.46, 4.46), (4.32, 4.32), T_PLINTH, T_PLINTH + 0.3, "stone", uv=1.3, tint=T["pale"], jit=0.015, seed=seed + 1, levels=2)
    shaft_top = H
    b.frustum(0, cz, (4.2, 4.2), (half_t(shaft_top), half_t(shaft_top)), T_PLINTH + 0.3, shaft_top, "stone", uv=1.0, tint=T["plain"], jit=0.045, seed=seed + 2)
    quoins(b, 0, cz, T_PLINTH + 0.3, shaft_top - 0.2, T, seed + 3)
    # string courses: one at the curtain's walk (where the wall meets it) and one under the corbels
    for ys in (WALK - 0.6, T_SHAFT_TOP - 0.7):
        if ys < shaft_top:
            h = half_t(ys)
            b.frustum(0, cz, (h + 0.2, h + 0.2), (h + 0.2, h + 0.2), ys, ys + 0.32, "stone", uv=1.6, tint=T["pale"], jit=0.01, seed=seed + 4, levels=2)
    if not ruin:
        walk = b.battlement(tower_outline(), T_SHAFT_TOP, (0, cz), seed, tint=T["dark"], mer_tint=T["plain"], ends_merlon=True)
        # the deck: a slab inside the parapet
        b.box((0, walk - 0.1, cz), (7.3, 0.3, 7.3), "stone", uv=1.3, tint=T["plain"], cuts=3, jit=0.01)
        # the stair turret, in the corner away from the curtain's walk: a small tower with a roof
        tx, tz = -2.55, cz - 2.55
        b.box((tx, walk + 1.6, tz), (2.7, 3.2 + 0.0, 2.7), "stone", uv=1.2, tint=T["plain"], cuts=2, jit=0.03)
        b.box((tx, walk + 3.4, tz), (3.1, 0.4, 3.1), "stone", uv=1.5, tint=T["pale"], jit=0.015)
        b.frustum(tx, tz, (1.75, 1.75), (0.1, 0.1), walk + 3.6, walk + 6.0, "wood", uv=1.0, tint=(0.85, 0.85, 0.88), jit=0.0, levels=2)
        b.box((tx, walk + 6.4, tz), (0.08, 0.9, 0.08), "iron")
        b.box((tx + 0.25, walk + 6.7, tz), (0.5, 0.3, 0.04), "iron")
        # a window in the turret and its door on the deck
        b.box((tx + 1.37, walk + 1.1, tz + 0.3), (0.1, 1.5, 0.6), "dark", cuts=0)
    else:
        broken_top(b, cz, H, seed, T)
    # arrow loops on three faces, two levels; each in a dressed surround
    for lv in (4.6, 8.4, 11.0):
        if lv < H - 1.0:
            h = half_t(lv)
            for (nx, nz, ax) in ((0, 1, 0), (1, 0, 1), (-1, 0, 1)):
                if nx == 0:
                    c = (0.0, lv, cz + nz * (h + 0.03))
                    sz = (0.15, 1.3, 0.12)
                else:
                    c = (nx * (h + 0.03), lv, cz)
                    sz = (0.12, 1.3, 0.15)
                b.box(c, sz, "dark", cuts=0)
                if nx == 0:
                    b.box((c[0], c[1], c[2] + 0.04 * nz), (0.5, 1.8, 0.14), "stone", uv=1.6, tint=T["pale"], cuts=0, jit=0.008)
                    b.box((c[0], c[1], c[2] + 0.07 * nz), (0.15, 1.3, 0.07), "dark", cuts=0)
                else:
                    b.box((c[0] + 0.04 * nx, c[1], c[2]), (0.14, 1.8, 0.5), "stone", uv=1.6, tint=T["pale"], cuts=0, jit=0.008)
                    b.box((c[0] + 0.07 * nx, c[1], c[2]), (0.07, 1.3, 0.15), "dark", cuts=0)
    # the walk enters the tower by a pointed door in each side face; a raised door on the inner face with a flight of steps
    hs = half_t(WALK + 1.0)
    for sx in (-1, 1):
        grouped(b, lambda: pointed_door(b, 0.0, WALK, 1.5, 1.7, T, seed + 11, depth=0.5, steps=False), math.atan2(sx, 0.0), (sx * hs, 0.0, 0.1))
    hz0 = half_t(T_PLINTH + 0.4)
    y_door = T_PLINTH + 0.3

    def ground_door():
        pointed_door(b, 0.0, y_door, 1.6, 1.5, T, seed + 12, depth=0.5, steps=False)
        for i in range(4):
            top = y_door - 0.72 * (i + 1) + 0.72
            b.box((0.0, (top - 1.0) / 2, 0.16 + 0.35 + i * 0.62), (2.3, top + 1.0, 0.62), "stone", uv=1.4, tint=T["pale"], jit=0.01, cuts=0)
    grouped(b, ground_door, math.pi, (0.0, 0.0, cz - hz0))
    return b.finish()


def broken_top(b, cz, H, seed, T):
    r = rng(seed)
    h = half_t(H)
    # a jagged stump: stepped blocks, one corner standing a storey higher, fallen stones in the ring
    for (cx_, cz_, w, d, up) in ((1.9, 1.7, 3.6, 3.4, 3.4), (-1.6, -0.3, 3.4, 4.6, 1.4), (0.2, -2.9, 5.0, 2.2, 0.7), (-2.4, 2.6, 2.8, 2.4, 0.5)):
        b.box((cx_, H + up / 2 - 0.1, cz + cz_), (w, up + 0.2, d), "stone", uv=1.0, tint=T["core"], cuts=2, jit=0.18, seed=seed + int(cx_ * 7))
    for k in range(10):
        a = r.uniform(0, math.tau)
        d = r.uniform(h + 0.6, h + 2.6)
        s = r.uniform(0.5, 1.2)
        b.box((math.cos(a) * d, s * 0.3, cz + math.sin(a) * d), (s * 1.4, s * 0.8, s * 1.1), "stone", uv=1.0, tint=T["plain"], yaw=r.uniform(0, 3), pitch=r.uniform(-.3, .3), cuts=1, jit=0.08)


# =================================================================================================
# the breach
# =================================================================================================

def stub(mats):
    T = tints()
    b = W("BreachStub", mats, 700)
    seed = 700
    r = rng(seed)
    x0 = -3.2
    # the standing end: full wall at x0, then stepping down through its core to the foundation at the gap end (+x)
    b.box((0, -1.8, 0), (6.5, 3.4, 4.5), "stone", uv=0.6, tint=T["damp"], cuts=2, jit=0.02)
    wall_courses(b, x0, 0.4, 6.0, T, seed)
    belt_and_upper(b, x0, 0.0, T, seed)
    b.battlement([("line", (x0, FACE), (0.0, FACE))], Y0, (0, -4), seed, tint=T["dark"], mer_tint=T["plain"], pitch=2.0)
    inner_face(b, x0, 0.0, T, seed, strips=(-2.6,))
    steps = [(0.0, 0.8, 7.0), (0.8, 1.6, 5.6), (1.6, 2.3, 4.2), (2.3, 2.9, 2.8), (2.9, 3.2, 1.5)]
    for i, (xa, xb, hh) in enumerate(steps):
        hz = hh
        top = min(hz, 6.0)
        # the body continues at full thickness, but the stone is torn: the face thins and the core shows on top
        wall_courses(b, xa, xb, min(hh, 6.0), T, seed + 20 * (i + 1), jit=0.09)
        if hh > 6.0:
            belt_and_upper(b, xa, xb, T, seed + i)
        ty = hh
        zo = outer_z(min(ty, 6.0)) if ty > 2.3 else 1.78
        zi = inner_z(min(ty, 6.0)) if ty > 2.3 else -1.55
        prof = [(zi, ty), (zo, ty), (zo - r.uniform(0.2, 0.7), ty + r.uniform(0.25, 0.6)), (zi + r.uniform(0.3, 0.8), ty + r.uniform(0.2, 0.7))]
        b.prism_x(prof, xa, xb, "stone", uv=1.0, tint=T["core"], jit=0.12, seed=seed + 30 + i, xstep=0.6, dens=0.6)
    # loose stones on the steps, the collapsed outer facing
    heap(b, 3.4, 3.1, 14, 3.1, 1.25, seed + 40, T)
    heap(b, 3.0, -2.7, 7, 2.0, 0.9, seed + 41, T)
    # the arrow loop in the standing part
    loop(b, -1.9, 3.9, T, seed)
    return b.finish()


def rubble(mats):
    T = tints()
    b = W("Rubble", mats, 800, damp=1.4)
    r = rng(800)
    # a fan of fallen wall: a core of large stones, ashlar scattered out in a fan, a merlon or two lying where they fell
    b.box((0, 0.35, 0), (7.4, 0.7, 4.8), "stone", uv=0.7, tint=T["core"], cuts=3, jit=0.22)
    heap(b, 0, 0, 22, 4.2, 1.15, 801, T)
    for (x, z, yw) in ((-2.0, 1.5, 0.5), (1.8, -1.0, 2.4), (0.3, 2.3, 1.2)):
        b.box((x, 0.55, z), (1.3, 0.95, 0.6), "stone", uv=1.3, tint=T["plain"], yaw=yw, pitch=0.25, roll=-0.3, jit=0.02, cuts=0)    # a fallen merlon
    for (x, z, yw) in ((1.2, 1.9, 0.9), (-1.2, -1.5, 2.2)):
        for (ya, yb, pr) in ((0.0, 0.32, 0.2), (0.32, 0.62, 0.38), (0.62, 0.9, 0.56)):
            b.box((x, (ya + yb) / 2 + 0.3, z + pr * 0.0), (0.56 - pr * 0.18, yb - ya, pr), "stone", uv=1.5, tint=T["plain"], yaw=yw, pitch=0.2, cuts=0)             # a fallen corbel
    # a length of dressed string course lying across it
    b.box((-1.0, 0.8, -1.2), (3.2, 0.34, 0.7), "stone", uv=1.6, tint=T["pale"], yaw=0.35, pitch=0.18, roll=0.12, jit=0.02, cuts=2)
    return b.finish()


# =================================================================================================
# the far meshes
# =================================================================================================

def far(mats):
    out = []
    stone = {"stone": mats["stone"]}
    b = W("WallFar", stone, 1)
    b.box((0, 3.6, 0), (12.0, 7.4, 3.2), "stone", cuts=0, jit=0.0, uv=1.0)
    b.box((0, 8.4, 0.5), (12.0, 1.9, 0.8), "stone", cuts=0, jit=0.0, uv=1.2)
    out.append(b.finish())
    b = W("TowerFar", stone, 2)
    b.box((0, 7.2, TZC), (8.4, 14.4, 8.4), "stone", cuts=0, jit=0.0, uv=1.0, taper=0.9)
    b.box((0, 15.2, TZC), (9.6, 2.6, 9.6), "stone", cuts=0, jit=0.0, uv=1.0)
    b.box((-2.5, 18.2, TZC - 2.5), (2.8, 3.4, 2.8), "stone", cuts=0, jit=0.0, uv=1.0)
    out.append(b.finish())
    b = W("GateFar", stone, 3)
    for sx in (-1.0, 1.0):
        b.box((sx * 6.5, 7.0, -1.85), (7.4, 14.0, 4.9), "stone", cuts=0, jit=0.0, uv=1.0)
        b.frustum(sx * 7.1, 0.6, 3.5, 3.1, 0.0, 14.0, "stone", uv=1.0, jit=0.0, levels=2, round_n=10)
        b.frustum(sx * 7.1, 0.6, 3.9, 3.9, 14.0, 17.0, "stone", uv=1.0, jit=0.0, levels=2, round_n=10)
    b.box((0, 10.6, -1.5), (7.8, 6.0, 5.6), "stone", cuts=0, jit=0.0, uv=1.0)
    out.append(b.finish())
    return out


def build(mats, objs, DATA, preview_dir=""):
    for kind, seed in (("A", 100), ("B", 200), ("C", 300), ("D", 150), ("E", 120)):
        objs.append(bay("WallSeg_" + kind, kind, seed, mats))
    objs.append(tower("Tower", False, 400, mats))
    objs.append(tower("TowerRuin", True, 500, mats))
    objs.append(stub(mats))
    objs.append(rubble(mats))
    objs.extend(far(mats))
    import r37_wall_gate as G
    import r37_wall_town as TW
    importlib.reload(G)
    importlib.reload(TW)
    objs.append(G.gatehouse(mats, 600))
    objs.append(TW.stair(mats))
    objs.append(TW.shed(mats))
    DATA["GATE_CROWN"] = G.CROWN
    DATA["GATE_H"] = G.DECK
    DATA["GATE_PX"] = 6.5
    DATA["GATE_TW"] = 7.4
    DATA["GATE_TD"] = 8.8
    DATA["GATE_PW"] = G.PW
    DATA["TOWER_DECK"] = T_WALK
    DATA["GATE_DECK"] = G.DECK
    DATA["GATE_ROOM_WALK"] = G.ROOM_WALK
    DATA["GATE_DRUM_X"] = G.DC
    DATA["GATE_DRUM_Z"] = G.DZ
    DATA["GATE_DRUM_R"] = G.DR
    DATA["GATE_REAR_Z"] = G.ZB
    DATA["GATE_FRONT_Z"] = G.ZF
    DATA["GATE_SPRING"] = G.SPRING
    DATA["STAIR_EDGE"] = TW.STAIR_EDGE
    DATA["STAIR_LEN"] = TW.STAIR_N * TW.STAIR_RUN
    DATA["STAIR_W"] = TW.STAIR_W
    DATA["SHED_L"] = TW.SHED_L
    DATA["SHED_D"] = TW.SHED_D
    DATA["WALL_LEN"] = LEN
    DATA["WALL_H"] = CREST
    DATA["WALL_WALK"] = WALK
    DATA["WALL_T"] = 3.1
    DATA["TOWER_S"] = 2 * half_t(T_PLINTH + 0.3)
    DATA["TOWER_H"] = T_TOP
    DATA["TOWER_ZC"] = TZC


def previews(objs, out):
    """Stills of the kit laid out in a row: textured and clay, several sides."""
    order = ["WallSeg_A", "WallSeg_E", "WallSeg_B", "WallSeg_C", "WallSeg_D", "Tower", "TowerRuin", "BreachStub", "Rubble", "Gatehouse", "WallStair", "WallShed"]
    x = 0.0
    pos = {}
    for name in order:
        for o in objs:
            if o.name == name:
                if name == "WallStair":
                    import r37_wall_town as TW0
                    o.location = L.G((pos["WallSeg_D"], 0, TW0.STAIR_EDGE))
                    o.rotation_euler = (0.0, 0.0, -math.pi / 2)
                    continue
                w = {"Gatehouse": 26.0, "Tower": 12.0, "TowerRuin": 12.0}.get(name, 14.0)
                x += w / 2
                o.location = L.G((x, 0, 0))
                pos[name] = x
                x += w / 2
    for o in objs:
        if o.name.endswith("Far"):
            o.hide_render = True
    import bpy
    import sys
    only = os.environ.get("WALL_SHOTS", "")
    shots = {
        "stair": ((pos.get("WallSeg_D", 0), 4, 7), 30.0, ((25, 0.25), (-35, 0.2), (90, 0.12), (180, 0.3)), (1300, 800)),
        "shed": ((pos.get("WallShed", 0), 2, 2), 14.0, ((20, 0.2), (-35, 0.25)), (1200, 800)),
        "bays": ((pos.get("WallSeg_B", 0) + 7, 6, 0), 60.0, ((20, 0.18), (200, 0.2)), (1800, 700)),
        "tower": ((pos.get("Tower", 0), 8, 0), 34.0, ((25, 0.2), (155, 0.22), (90, 0.1), (-60, 0.35)), (1100, 1100)),
        "ruin": ((pos.get("TowerRuin", 0) + 8, 4, 0), 40.0, ((25, 0.2), (200, 0.2)), (1500, 800)),
        "gate": ((pos.get("Gatehouse", 0), 8, 0), 34.0, ((15, 0.14), (-25, 0.2), (170, 0.18), (90, 0.1)), (1200, 900)),
    }
    for nm, (look, dist, views, res) in shots.items():
        if only and nm not in only.split(","):
            continue
        for clay in (False, True):
            WL.clay_preview(os.path.join(out, "%s%s.png" % (nm, "_clay" if clay else "")), objs, look, dist, views, res, 35, clay)
