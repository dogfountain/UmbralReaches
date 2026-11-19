"""The world pass's towers, modelled as dressed masonry (Luke, 18 Nov: "all models in the game should be blender"; the map
audit's F28: these were OssKit boxes). Each glb is the LOOK only: the game keeps the kit's own collision, stair ramps and
solids, laid by the same numbers with the kit's visual off (OssKit.visual), so the walk is exactly what it was.

  tools/blender/run.sh wonder_towers.py -- [--only wardens,climb] [--preview DIR]

  wonder_wardens_tower.glb   the Wardens' Line keep (core/world/realm/wonders/r39/wardens_line.gd): a 10.4 m square keep
                             on an 11.8 m battered plinth, walls 0.9 m, 12.5 m to the wall head, merlons and corner
                             turrets, a moulded string course, slit windows at two heights on every face (lit glass is
                             the game's, inside each slit), a round-headed door in the west wall, a stair of four flights
                             wound round the hall on solid landings, the roof deck with the well open over the climb, an
                             iron cresset on the deck, a flagged floor, timber hoarding stubs under the head
  wonder_climb_tower.glb     a broken watchtower (climbs.gd), see build_climb

Frame: Blender x = the game's local x, Blender y = the game's -z, Blender z = up (the game's y); the origin is the hall's
floor datum (the kit's y0), so the kit's local numbers carry over as (x, -z, y).
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from mathutils import Vector
from reach_west_lib import *     # noqa: F401,F403
import reach_west_lib as L

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ONLY = args[args.index("--only") + 1].split(",") if "--only" in args else []


def G(x, y, z):
    """The game's local (x, y, z) in Blender."""
    return (x, -z, y)


# ============================================================================================
# THE WARDENS' TOWER (wardens_line.gd: HI 4.3, WALL 0.9, fl 0.3, rise 2.75, top 12.5)
# ============================================================================================
HI = 4.3
WT = 0.9
FL = 0.3
RISE = 2.75
TOP = 12.5
DK = FL + 4.0 * RISE            # the roof deck's top (11.3)
OUT = HI + WT                   # the walls' outer face (5.2)


def ward_walls(P, rnd):
    e = HI + WT * 0.5
    h = TOP - FL
    # (plan a, plan b, the slits on it as (u centre, game y of the sill), the door)
    slits_y = (4.3, 7.9)
    walls = [
        # west (the game's -x): x = -e, from the game's z -5.2 to 5.2 (Blender y 5.2 -> -5.2)
        ((-e, 5.2), (-e, -5.2), [(5.2 - 2.6, 4.3), (5.2 + 3.0, 7.9)], True),
        # east (+x)
        ((e, 5.2), (e, -5.2), [(5.2 + 1.9, 4.3), (5.2 - 1.9, 7.9)], False),
        # the game's -z face (Blender +y), between the side walls
        ((-HI, e), (HI, e), [(HI + 1.9, 4.3), (HI - 1.9, 7.9)], False),
        # the game's +z face (Blender -y)
        ((-HI, -e), (HI, -e), [(HI - 1.9, 4.3), (HI + 1.9, 7.9)], False),
    ]
    for k, (a, b, slits, door) in enumerate(walls):
        def solid(u, v, slits=slits, door=door):
            for (cu, sy) in slits:
                v0 = sy - FL
                if L.rect_hole(u, v, cu, 0.86, v0, v0 + 1.7) or L.arch_hole(u, v, cu, 0.86, v0 + 1.7, v0 + 1.7):
                    return False
            # the door: the game's z 0..1.6 is Blender y -1.6..0, u 5.2..6.8 along this wall (it runs from Blender y 5.2 down)
            if door and L.arch_hole(u, v, 5.2 + 0.8, 1.6, 0.0, 2.0):
                return False
            return True
        L.wall_run(P, None, "ashlar", a, b, FL, h, WT, solid, rnd, ch=0.62, col=False, blk=(0.9, 1.7),
                   ends=(0.0, 0.0) if k < 2 else (0.02, 0.02), dress_ends=True)
    # the door's arch ring
    L.voussoirs(P, "ashlar", (-e, -0.8, FL), math.pi * 0.5, 1.6, 2.0, WT, ring=0.42, n=11)


def ward_plinth(P, rnd):
    # a battered plinth: two set-back courses of big stones round the keep, buried 2.4 m (the ground on site is levelled
    # to the floor datum by the terrace; a slope shows more plinth)
    for half, z0, z1 in ((5.9, -2.6, -0.5), (5.6, -0.5, FL - 0.04)):
        L.wall_run(P, None, "ashlar", (-half + 0.6, -half), (-half + 0.6, half), z0, z1 - z0, 1.2, lambda u, v: True, rnd, ch=0.8, col=False,
                   blk=(1.2, 2.2), faces=(1,))
        L.wall_run(P, None, "ashlar", (half - 0.6, half), (half - 0.6, -half), z0, z1 - z0, 1.2, lambda u, v: True, rnd, ch=0.8, col=False,
                   blk=(1.2, 2.2), faces=(1,))
        L.wall_run(P, None, "ashlar", (half, -half + 0.6), (-half, -half + 0.6), z0, z1 - z0, 1.2, lambda u, v: True, rnd, ch=0.8, col=False,
                   blk=(1.2, 2.2), faces=(1,))
        L.wall_run(P, None, "ashlar", (-half, half - 0.6), (half, half - 0.6), z0, z1 - z0, 1.2, lambda u, v: True, rnd, ch=0.8, col=False,
                   blk=(1.2, 2.2), faces=(1,))
        # the course's chamfered cap
        for (a, b) in (((-half, -half), (half, -half)), ((half, -half), (half, half)), ((half, half), (-half, half)), ((-half, half), (-half, -half))):
            av, bv = Vector(a), Vector(b)
            d = bv - av
            n = int(d.length / 1.3)
            for j in range(n):
                c = av + d * ((j + 0.5) / n)
                inward = Vector((-c.x, -c.y)).normalized() * 0.18
                L.dbox(P, "ashlar", (c.x + inward.x, c.y + inward.y, z1 - 0.12), (d.length / n * 0.98 if abs(d.x) > abs(d.y) else 0.5,
                       d.length / n * 0.98 if abs(d.y) > abs(d.x) else 0.5, 0.26), bevel=0.06)
    # the hall's floor: flags
    y = -HI
    while y < HI - 0.05:
        rh = rnd.uniform(0.7, 1.1)
        rh = min(rh, HI - y)
        x = -HI + rnd.uniform(0.0, 0.5)
        L.dbox(P, "ashlar", (-HI + 0.25, y + rh * 0.5, FL - 0.06), (0.5, rh * 0.97, 0.12), bevel=0.02)
        while x < HI - 0.05:
            w = min(rnd.uniform(0.7, 1.3), HI - x)
            L.dbox(P, "ashlar", (x + w * 0.5, y + rh * 0.5, FL - 0.06), (w * 0.97, rh * 0.97, 0.12), bevel=0.025)
            x += w
        y += rh


def ward_head(P, rnd):
    e = HI + WT * 0.5
    # the string course (game y 11.0 - 11.5): a moulded band proud of every face
    for side in range(4):
        for j in range(9):
            t = -5.45 + (j + 0.5) * (10.9 / 9)
            ln = 10.9 / 9 * 0.98
            if side == 0:
                c, sz = (t, -(OUT + 0.12), 11.25), (ln, 0.5, 0.42)
            elif side == 1:
                c, sz = (t, OUT + 0.12, 11.25), (ln, 0.5, 0.42)
            elif side == 2:
                c, sz = (OUT + 0.12, t, 11.25), (0.5, ln, 0.42)
            else:
                c, sz = (-(OUT + 0.12), t, 11.25), (0.5, ln, 0.42)
            L.dbox(P, "ashlar", c, sz, bevel=0.08)
    # merlons over the wall heads (as the kit: 1.4 x 0.9 x 1.1, five a side) and the four corner turrets (1.4 x 1.4 x 1.8)
    for s in (-1.0, 1.0):
        for q in range(5):
            t = -3.9 + 1.95 * q
            hh = 1.1 * rnd.uniform(0.94, 1.04)
            L.dbox(P, "ashlar", (t, s * e, TOP + hh * 0.5), (1.4, 0.9, hh), bevel=0.07)
            L.dbox(P, "ashlar", (t, s * e, TOP + hh + 0.07), (1.52, 1.02, 0.14), bevel=0.04)
            L.dbox(P, "ashlar", (s * e, t, TOP + hh * 0.5), (0.9, 1.4, hh), bevel=0.07)
            L.dbox(P, "ashlar", (s * e, t, TOP + hh + 0.07), (1.02, 1.52, 0.14), bevel=0.04)
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            for k in range(3):
                L.dbox(P, "ashlar", (sx * e, sy * e, TOP + 0.3 + k * 0.6), (1.4, 1.4, 0.58), yaw=rnd.uniform(-0.02, 0.02), bevel=0.08)
            L.dbox(P, "ashlar", (sx * e, sy * e, TOP + 1.95), (1.6, 1.6, 0.2), bevel=0.05)
    # timber hoarding stubs under the head (the joists of a gallery long burned), two a face
    for s in (-1.0, 1.0):
        for t in (-2.6, 2.6):
            beam(P, "timber", (t, s * (OUT - 0.2), 10.6), (t, s * (OUT + 0.75), 10.6), 0.24, 0.28)
            beam(P, "timber", (s * (OUT - 0.2), t, 10.6), (s * (OUT + 0.75), t, 10.6), 0.24, 0.28)


def ward_stair(P, rnd):
    n = int(math.ceil(RISE / 0.36))
    # flights round the hall (the kit's _flight numbers: (from, to, width, base)), in Blender plan
    flights = [((-2.5, 3.4), (2.5, 3.4), FL, FL),
               ((3.4, 2.5), (3.4, -2.5), FL + RISE, FL),
               ((2.5, -3.4), (-2.5, -3.4), FL + 2 * RISE, FL + 2 * RISE - 0.6),
               ((-3.4, -2.5), (-3.4, 2.5), FL + 3 * RISE, FL + 3 * RISE - 0.6)]
    for (p0, p1, z0, base) in flights:
        d = Vector((p1[0] - p0[0], p1[1] - p0[1], 0.0))
        ln = d.length
        d.normalize()
        yaw = math.atan2(d.y, d.x)
        tread = ln / n
        for i in range(n):
            zt = z0 + RISE / n * (i + 1)
            c = Vector((p0[0], p0[1], 0.0)) + d * (tread * (i + 0.5))
            hh = zt - base
            L.dbox(P, "ashlar", (c.x, c.y, base + hh * 0.5), (tread * 1.06, 1.8, hh), yaw=yaw, bevel=0.035)
    # the solid corner landings (the kit's blocks) and the deck
    for (x0, x1, y0, y1, z1) in ((2.5, HI, 2.5, HI, FL + RISE), (2.5, HI, -HI, -2.5, FL + 2 * RISE), (-HI, -2.5, -HI, -2.5, FL + 3 * RISE)):
        hh = z1 - FL
        k = int(hh / 0.7) + 1
        for j in range(k):
            zz = FL + hh * j / k
            L.dbox(P, "ashlar", ((x0 + x1) * 0.5, (y0 + y1) * 0.5, zz + hh / k * 0.5), (x1 - x0, y1 - y0, hh / k * 0.98),
                   yaw=rnd.uniform(-0.01, 0.01), bevel=0.05)
    for (x0, x1, y0, y1) in ((-2.5, HI, -HI, HI), (-HI, -2.5, 2.5, HI)):
        # the deck: a slab under a grid of flags (not planks)
        L.dbox(P, "ashlar", ((x0 + x1) * 0.5, (y0 + y1) * 0.5, DK - 0.42), (x1 - x0, y1 - y0, 0.56), bevel=0.04)
        y = y0
        while y < y1 - 0.05:
            rh = min(rnd.uniform(0.75, 1.2), y1 - y)
            x = x0 + 0.0
            while x < x1 - 0.05:
                w = min(rnd.uniform(0.7, 1.3), x1 - x)
                L.dbox(P, "ashlar", (x + w * 0.5, y + rh * 0.5, DK - 0.07), (w * 0.965, rh * 0.965, 0.14), bevel=0.03)
                x += w
            y += rh
    # the cresset: a cast-iron basin on three legs over a stone footing (the flame and pilot are the game's)
    L.dbox(P, "ashlar", (0.0, 0.0, DK + 0.2), (1.9, 1.9, 0.4), bevel=0.06)
    cyl(P, "iron", (0.0, 0.0, DK + 0.95), (0.0, 0.0, DK + 1.15), 0.95, 1.05, seg=14)
    cyl(P, "iron", (0.0, 0.0, DK + 0.75), (0.0, 0.0, DK + 0.95), 0.55, 0.95, seg=14)
    for i in range(3):
        a = i * math.tau / 3.0
        beam(P, "iron", (math.cos(a) * 0.95, math.sin(a) * 0.95, DK + 0.4), (math.cos(a) * 0.55, math.sin(a) * 0.55, DK + 1.05), 0.1, 0.1)
    # embers' bed and a scatter of soot on the deck
    cyl(P, "stone", (0.0, 0.0, DK + 1.02), (0.0, 0.0, DK + 1.1), 0.88, 0.85, seg=14)


def ward_far():
    Pf = Parts()
    box(Pf, "stone", (0.0, 0.0, 5.0), (OUT * 2.0, OUT * 2.0, 15.0))
    box(Pf, "stone", (0.0, 0.0, TOP + 0.7), (OUT * 2.0 + 0.4, OUT * 2.0 + 0.4, 1.4))
    objs = finish(Pf, "WardensFar")
    for o in objs:
        o.name = "WardensFar__far"
        o.hide_render = True
    return objs


def asset_wardens():
    reset()
    P = Parts()
    rnd = L.rnd_for(61)
    L.mason_begin(61)
    ward_plinth(P, rnd)
    ward_walls(P, rnd)
    ward_head(P, rnd)
    ward_stair(P, rnd)
    objs = finish(P, "Wardens", smooth_keys=()) + L.mason_end("Wardens")
    far = ward_far()
    export(objs + far, os.path.join(MODELS, "wonder_wardens_tower.glb"), "wardens")
    preview(objs, "wardens", [((-26, -30, 14), (0, 0, 6), 32), ((24, 22, 30), (0, 0, 8), 34), ((-14, -2, 2.2), (-5, -1, 2.5), 30),
                              ((0, 0, 40), (0, 0, 0), 30), ((1.6, -1.2, 1.7), (-4, 3, 4.5), 16)])
    L.bake_blend("wonder_wardens_tower")


# ============================================================================================
# THE BROKEN WATCHTOWER (climbs.gd _tower: a 6 m shaft, walls 0.9, 13 m, breached; the outside stair's second flight, the
# landing and its posts, the timber deck on two stone beams, a ring of hearth stones). The first flight's foot follows the
# ground on each site, so it stays the kit's.
# ============================================================================================
def climb_walls(P, rnd):
    def mask(top_fn, holes):
        def solid(u, v):
            if v > top_fn(u):
                return False
            for (cu, v0, w, hh) in holes:
                if L.rect_hole(u, v, cu, w, v0, v0 + hh) or L.arch_hole(u, v, cu, w, v0 + hh, v0 + hh):
                    return False
            return True
        return solid
    flat13 = lambda u: 13.0
    # (a, b, top, holes): the game's -z wall (Blender +y) full height with a slit at 6 m; +z wall breached to ~9 m; the -x wall
    # full with a slit at 8 m; the +x wall breached to ~7 m
    walls = [((-3.45, 3.0), (3.45, 3.0), flat13, [(3.45, 6.0, 0.74, 1.6)]),
             ((-3.45, -3.0), (3.45, -3.0), L.ragged_top(71, 9.0, 1.4, 0.45), []),
             ((-3.0, 2.55), (-3.0, -2.55), flat13, [(2.55, 8.0, 0.74, 1.6)]),
             ((3.0, 2.55), (3.0, -2.55), L.ragged_top(72, 7.0, 1.6, 0.5), [])]
    for (a, b, top, holes) in walls:
        L.wall_run(P, None, "ashlar", a, b, 0.0, 13.0, 0.9, mask(top, holes), rnd, ch=0.66, col=False, blk=(0.9, 1.8), dress_ends=True)
    # broken merlons on the full wall's head
    for j in range(4):
        mh = 0.9 - 0.25 * (j % 2) - 0.1 * j
        L.dbox(P, "ashlar", (-2.2 + 1.45 * j, 3.0, 13.0 + mh * 0.5 - 0.05), (1.0, 0.9, mh), yaw=rnd.uniform(-0.05, 0.05), bevel=0.08,
               warp=0.03)
    # the plinth: a battered course round the foot, buried
    for half in (3.7,):
        for (a, b) in (((-half + 0.5, -half), (-half + 0.5, half)), ((half - 0.5, half), (half - 0.5, -half)),
                       ((half, -half + 0.5), (-half, -half + 0.5)), ((-half, half - 0.5), (half, half - 0.5))):
            L.wall_run(P, None, "ashlar", a, b, -2.6, 2.6, 1.0, lambda u, v: True, rnd, ch=0.75, col=False, blk=(1.0, 1.9), faces=(1,))
    # the floor inside the shaft: rubble and earth over flags
    L.rubble(P, None, "ashlar", rnd, (-2.3, -2.2, 2.3, 2.2), 7, 0.25, 0.7, ground=0.0)


def climb_stair(P, rnd):
    # the landing at 6 m (the game's box (0.5, 5.8, -4.9) 10 x 0.4 x 2) on its two posts
    x = -4.5
    while x < 5.45:
        w = min(rnd.uniform(0.9, 1.5), 5.5 - x)
        L.dbox(P, "ashlar", (x + w * 0.5, 4.9, 5.8), (w * 0.97, 2.0, 0.4), bevel=0.05)
        x += w
    for (px, py) in ((-3.0, 4.4), (4.8, 5.4)):
        for k in range(8):
            L.dbox(P, "ashlar", (px, py, 0.375 * 2 * k + 0.375), (0.82, 0.82, 0.72), yaw=rnd.uniform(-0.04, 0.04), bevel=0.06)
    # the second flight: up the east face from the landing to the deck (game (4.6, 6, -4.9) -> (4.6, 12, 5.0)), solid to 5.6
    n = int(math.ceil(6.0 / 0.36))
    p0, p1 = Vector((4.6, 4.9, 0.0)), Vector((4.6, -5.0, 0.0))
    d = p1 - p0
    ln = d.length
    d.normalize()
    tread = ln / n
    # a coursed stair mass (its top stepped) under a tread slab on every step
    rise = 6.0 / n

    def stepped(u, v):
        i = min(n - 1, max(0, int(u / tread)))
        return v <= 0.4 + rise * (i + 1) - 0.14
    L.wall_run(P, None, "ashlar", (p0.x, p0.y), (p1.x, p1.y), 5.6, 6.5, 1.8, stepped, rnd, ch=0.5, col=False, blk=(0.6, 1.2), dress_ends=True)
    for i in range(n):
        zt = 6.0 + rise * (i + 1)
        c = p0 + d * (tread * (i + 0.5))
        L.dbox(P, "ashlar", (c.x + rnd.uniform(-0.02, 0.02), c.y, zt - 0.07), (1.86, tread * 1.04, 0.14), bevel=0.025)
    # the deck: planks on two stone beams, the platform at the stair's head; a ring of hearth stones
    for yy in (-2.4, 2.4):
        L.dbox(P, "ashlar", (0.0, yy, 11.45), (5.2, 0.6, 0.5), bevel=0.06, warp=0.02)
    for (cx, cy, sx, sy) in ((0.0, 0.0, 5.2, 4.4), (3.9, -2.4, 3.2, 5.2)):
        n_pl = int(sx / 0.28)
        for j in range(n_pl):
            xx = cx - sx * 0.5 + (j + 0.5) * sx / n_pl
            if rnd.random() < 0.06:
                continue                                    # a board gone
            box(P, "timber", (xx, cy + rnd.uniform(-0.03, 0.03), 11.85 + rnd.uniform(-0.01, 0.01)), (sx / n_pl * 0.93, sy * rnd.uniform(0.96, 1.0), 0.12),
                yaw=rnd.uniform(-0.01, 0.01))
        for yy in (cy - sy * 0.5 + 0.3, cy + sy * 0.5 - 0.3):
            beam(P, "timber", (cx - sx * 0.5, yy, 11.73), (cx + sx * 0.5, yy, 11.73), 0.18, 0.14)
    for j in range(6):
        a = math.tau * j / 6.0
        L.dbox(P, "ashlar", (math.cos(a) * 1.2, -(math.sin(a) * 1.2 + 0.2), 12.2), (0.5, 0.4, 0.35), yaw=-a, bevel=0.06, warp=0.02)


def climb_far():
    Pf = Parts()
    box(Pf, "stone", (0.0, 0.0, 6.0), (6.9, 6.9, 13.0))
    objs = finish(Pf, "ClimbFar")
    for o in objs:
        o.name = "ClimbFar__far"
        o.hide_render = True
    return objs


def asset_climb():
    reset()
    P = Parts()
    rnd = L.rnd_for(73)
    L.mason_begin(73)
    climb_walls(P, rnd)
    climb_stair(P, rnd)
    objs = finish(P, "Climb") + L.mason_end("Climb")
    export(objs + climb_far(), os.path.join(MODELS, "wonder_climb_tower.glb"), "climb")
    preview(objs, "climb", [((-20, -22, 12), (0, 0, 6), 32), ((18, 20, 22), (0, 0, 8), 34), ((14, -14, 9), (2, -1, 8), 30),
                            ((0, 0, 30), (0, 0, 6), 30)])
    L.bake_blend("wonder_climb_tower")


ASSETS = {"wardens": asset_wardens, "climb": asset_climb}

for k, fn in ASSETS.items():
    if not ONLY or k in ONLY:
        fn()
