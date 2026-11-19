"""The hermits' places (core/world/realm/wonders/r39/hermit_caches.gd), modelled (the map audit's F28: they were OssKit boxes).
Each glb is the LOOK only; the game lays the kit's boxes with its visual off for the collision (OssKit.visual).

  tools/blender/run.sh wonder_hermit.py -- [--only leanto,cell,ring] [--preview DIR]

  hermit_leanto.glb   a lean-to against a low dry-stone wall: posts, a plank and bark roof pitched down to the hearth,
                      wattle sides, a bedroll on a pallet, a hearth ring of fire-blackened stones
  hermit_cell.glb     an anchorite's cell: coursed rubble walls 0.5 m thick, a door with a lintel, a slit in the back wall,
                      a roof of overlapping stone slabs, an altar block
  hermit_ring.glb     five rough standing stones round a capstone table on its supports
Each also has the place's flagged pad (9 m) and the lantern pole with its crook (the lit lantern is the game's).

Frame: Blender (x, y, z) = the game's local (x, -z, y), origin at the pad's level (the kit's c).
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mathutils import Vector
from reach_west_lib import *     # noqa: F401,F403
import reach_west_lib as L

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ONLY = args[args.index("--only") + 1].split(",") if "--only" in args else []


def G(x, y, z):
    return (x, -z, y)


def pad(P, rnd):
    """The flagged pad (the kit's 9 x 9 footing, its top 0.12 over the level), a kerb of bigger stones round it."""
    L.dbox(P, "ashlar", (0.0, 0.0, -0.9), (8.9, 8.9, 1.9), bevel=0.06)
    y = -4.2
    while y < 4.15:
        rh = min(rnd.uniform(0.6, 1.0), 4.2 - y)
        x = -4.2 + rnd.uniform(0.0, 0.4)
        while x < 4.15:
            w = min(rnd.uniform(0.6, 1.2), 4.2 - x)
            if rnd.random() > 0.08:                        # a flag gone: the earth shows
                L.dbox(P, "ashlar", (x + w * 0.5, y + rh * 0.5, 0.06 + rnd.uniform(-0.015, 0.015)), (w * 0.95, rh * 0.95, 0.12),
                       yaw=rnd.uniform(-0.03, 0.03), bevel=0.025)
            x += w
        y += rh
    for (a, b) in (((-4.5, -4.5), (4.5, -4.5)), ((4.5, -4.5), (4.5, 4.5)), ((4.5, 4.5), (-4.5, 4.5)), ((-4.5, 4.5), (-4.5, -4.5))):
        av, bv = Vector(a), Vector(b)
        d = bv - av
        n = int(d.length / 0.9)
        for j in range(n):
            c = av + d * ((j + 0.5) / n)
            L.dbox(P, "ashlar", (c.x, c.y, 0.06), (d.length / n * 0.96 if abs(d.x) > 0.1 else 0.42, d.length / n * 0.96 if abs(d.y) > 0.1 else 0.42, 0.26),
                   yaw=rnd.uniform(-0.05, 0.05), bevel=0.05, warp=0.02)


def pole(P, rnd):
    """The lantern pole at the game's (3.4, 0, -3.2): a trimmed trunk, a crook arm to the lantern's hook, iron bands."""
    base = Vector(G(3.4, 0.0, -3.2))
    rings = []
    for k in range(9):
        t = k / 8.0
        r = 0.2 - 0.06 * t
        wob = Vector((math.sin(t * 5.0) * 0.03, math.cos(t * 4.0) * 0.03, 0.0))
        rings.append((base + wob + Vector((0, 0, 7.2 * t - 0.4)), r))
    for i in range(len(rings) - 1):
        cyl(P, "timber", rings[i][0], rings[i + 1][0], rings[i][1], rings[i + 1][1], seg=7)
    top = base + Vector((0, 0, 6.9))
    beam(P, "timber", top, top + Vector((-1.15, 0.0, 0.0)), 0.13, 0.13)
    beam(P, "timber", top + Vector((-0.05, 0, -0.75)), top + Vector((-0.75, 0, -0.02)), 0.08, 0.08)       # the brace
    for z in (1.0, 5.6):
        cyl(P, "iron", base + Vector((0, 0, z)), base + Vector((0, 0, z + 0.07)), 0.2, 0.2, seg=8)
    cyl(P, "iron", top + Vector((-1.1, 0, -0.02)), top + Vector((-1.1, 0, -0.32)), 0.015, 0.015, seg=4)
    # wedges of stone round its foot
    for j in range(5):
        a = math.tau * j / 5.0 + 0.4
        L.dbox(P, "ashlar", (base.x + math.cos(a) * 0.36, base.y + math.sin(a) * 0.36, 0.22), (0.32, 0.26, 0.3), yaw=a, bevel=0.05, warp=0.03)


def asset_leanto():
    reset()
    P = Parts()
    rnd = L.rnd_for(91)
    L.mason_begin(91)
    pad(P, rnd)
    pole(P, rnd)
    # the back: a low dry-stone wall (the game's box (0, 1.0, -2.4) 5 x 2.2 x 0.25 is its collision)
    L.wall_run(P, None, "ashlar", (-2.5, 2.4), (2.5, 2.4), 0.12, 1.15, 0.5, lambda u, v: v < 1.0 + 0.12 * math.sin(u * 2.3), rnd,
               ch=0.3, col=False, blk=(0.35, 0.7), dress_ends=True)
    # posts and the frame: two at the back on the wall, two at the front
    for x in (-2.35, 2.35):
        beam(P, "timber", (x, 2.4, 0.1), (x, 2.4, 2.55), 0.18, 0.18)
        beam(P, "timber", (x, 0.15, 0.1), (x, 0.15, 1.7), 0.17, 0.17)
        beam(P, "timber", (x, 2.4, 2.45), (x, 0.0, 1.62), 0.16, 0.12)          # the rafter's side
    beam(P, "timber", (-2.6, 2.4, 2.55), (2.6, 2.4, 2.55), 0.2, 0.2)
    beam(P, "timber", (-2.6, 0.15, 1.7), (2.6, 0.15, 1.7), 0.18, 0.18)
    # the plank-and-bark roof pitched down to the hearth (the game's slab: 5.4 x 0.2 x 3.2, 0.28 rad)
    n = 14
    for j in range(n):
        x = -2.65 + (j + 0.5) * 5.3 / n
        a = Vector((x + rnd.uniform(-0.03, 0.03), 2.75, 2.7))
        b = Vector((x + rnd.uniform(-0.05, 0.05), -0.35, 1.78 + rnd.uniform(-0.04, 0.04)))
        beam(P, "timber", a, b, 5.3 / n * 0.92, 0.06)
    # wattle sides (hurdles of withies on the side posts)
    for x in (-2.35, 2.35):
        for k in range(7):
            z = 0.25 + k * 0.22
            beam(P, "timber", (x, 2.35, z), (x, 0.2, z + 0.02), 0.035, 0.035)
        for yy in (0.6, 1.2, 1.8):
            beam(P, "timber", (x, yy, 0.12), (x, yy, 1.75 - (2.4 - yy) * 0.1), 0.03, 0.03)
    # the bedroll on a pallet (game (-0.9, 0.2, -1.0) 1.4 x 0.2 x 2.4)
    for j in range(5):
        box(P, "timber", (-0.9, 1.0 - 1.1 + j * 0.5 + 0.25, 0.17), (1.4, 0.42, 0.08))
    cyl(P, "cloth", (-1.45, 1.0, 0.36), (-0.35, 1.0, 0.36), 0.2, 0.2, seg=10)
    box(P, "cloth", (-0.9, 0.65, 0.27), (1.3, 1.5, 0.08), pitch=0.03)
    # the hearth ring (game (0, 0.12, 1.6), r 0.9): eight fire-blackened stones and the ash bed
    for q in range(8):
        a = math.tau * q / 8.0
        L.dbox(P, "ashlar", (math.cos(a) * 0.9, -(1.6 + math.sin(a) * 0.9), 0.2), (0.42, 0.34, 0.3), yaw=-a, bevel=0.06, warp=0.03)
    cyl(P, "stone", (0.0, -1.6, 0.12), (0.0, -1.6, 0.16), 0.72, 0.68, seg=12)
    objs = finish(P, "Leanto") + L.mason_end("Leanto")
    export(objs, os.path.join(MODELS, "hermit_leanto.glb"), "leanto")
    preview(objs, "leanto", [((-9, -10, 5), (0, 0, 1.2), 32), ((8, -7, 4), (0, 0.5, 1.4), 30), ((0, -4.5, 1.6), (0, 2, 1), 24)])


def asset_cell():
    reset()
    P = Parts()
    rnd = L.rnd_for(92)
    L.mason_begin(92)
    pad(P, rnd)
    pole(P, rnd)
    h = 3.0
    # back (game z -2.2 -> Blender y 2.2) with a slit; the sides; the front (Blender y -2.2) with the door (game x -0.7..0.7, to 2.35)
    L.wall_run(P, None, "ashlar", (-2.3, 2.2), (2.3, 2.2), 0.12, h, 0.5,
               lambda u, v: not (L.rect_hole(u, v, 2.3, 0.3, 1.2, 2.4)), rnd, ch=0.36, col=False, blk=(0.45, 0.9), dress_ends=True)
    for x in (-2.05, 2.05):
        L.wall_run(P, None, "ashlar", (x, 1.95), (x, -1.95), 0.12, h, 0.5, lambda u, v: True, rnd, ch=0.36, col=False, blk=(0.45, 0.9),
                   dress_ends=True)
    L.wall_run(P, None, "ashlar", (-2.3, -2.2), (2.3, -2.2), 0.12, h, 0.5, lambda u, v: not L.rect_hole(u, v, 2.3, 1.4, 0.0, 2.2), rnd,
               ch=0.36, col=False, blk=(0.45, 0.9), dress_ends=True)
    L.dbox(P, "ashlar", (0.0, -2.2, 2.55), (1.9, 0.6, 0.42), bevel=0.05)          # the lintel
    # the roof: overlapping stone slabs (the game's slab 5.2 x 0.5 x 5 over 2.95 .. 3.45)
    for row in range(5):
        y = -2.4 + row * 1.0
        x = -2.6
        while x < 2.55:
            w = min(rnd.uniform(0.8, 1.4), 2.6 - x)
            L.dbox(P, "ashlar", (x + w * 0.5, y + 0.5, 3.12 + row * 0.04), (w * 0.98, 1.12, 0.2), pitch=0.06, yaw=rnd.uniform(-0.03, 0.03),
                   bevel=0.04, warp=0.02)
            x += w
    L.dbox(P, "ashlar", (0.0, 0.0, 3.0), (5.2, 5.0, 0.3), bevel=0.04)
    # the altar (game (0, 0.45, -1.2) 1.8 x 0.9 x 0.9): a block with a slab top and a step
    L.dbox(P, "ashlar", (0.0, 1.2, 0.5), (1.6, 0.8, 0.78), bevel=0.05)
    L.dbox(P, "ashlar", (0.0, 1.2, 0.93), (1.86, 0.92, 0.12), bevel=0.04)
    L.dbox(P, "ashlar", (0.0, 0.6, 0.18), (1.2, 0.4, 0.14), bevel=0.04)
    objs = finish(P, "Cell") + L.mason_end("Cell")
    export(objs, os.path.join(MODELS, "hermit_cell.glb"), "cell")
    preview(objs, "cell", [((-8, -10, 5), (0, 0, 1.6), 32), ((7, 8, 6), (0, 0, 1.6), 30), ((0, -6, 1.6), (0, 0, 1.4), 26)])


def menhir(P, c, w, d, hh, yaw, lean, rnd):
    """A rough standing stone: an irregular seven-sided section, faceted (flat-shaded planes, not a smooth lump), wider at
    the shoulder than the foot, its top broken on a slant; a lean about its width."""
    n = 7
    base = []
    for k in range(n):
        a = math.tau * k / n + rnd.uniform(-0.25, 0.25)
        r = rnd.uniform(0.82, 1.08)
        base.append((math.cos(a) * w * 0.5 * r, math.sin(a) * d * 0.5 * r))
    cz = math.cos(yaw)
    sz = math.sin(yaw)
    slant = rnd.uniform(-0.35, 0.35) * w
    rings = []
    for i, t in enumerate((0.0, 0.08, 0.35, 0.62, 0.86, 1.0)):
        sc = (0.92, 1.0, 1.04, 0.96, 0.82, 0.62)[i]
        ring = []
        for (bx, by) in base:
            x = bx * sc + rnd.uniform(-0.04, 0.04)
            y = by * sc + rnd.uniform(-0.04, 0.04)
            z = t * hh - 0.3 + (bx * slant / max(w, 0.01) if t == 1.0 else 0.0)
            z += lean * by * 0.0
            xx = x * cz - y * sz
            yy = x * sz + y * cz
            ring.append(Vector((c.x + xx + lean * z * cz * 0.0, c.y + yy, z)) + Vector((-sz, cz, 0.0)) * (lean * z))
        rings.append(ring)
    ring_loft(P, "stone", rings)


def asset_ring():
    reset()
    P = Parts()
    rnd = L.rnd_for(93)
    L.mason_begin(93)
    pad(P, rnd)
    pole(P, rnd)
    # five rough standing stones (the game's boxes: 1.0 x (4.0 + 0.5 (q % 3)) x 0.8 at r 3, leaning a little)
    for q in range(5):
        a = math.tau * q / 5.0 + 0.3
        hh = 4.0 + 0.5 * (q % 3)
        c = Vector(G(math.cos(a) * 3.0, 0.0, math.sin(a) * 3.0))
        yaw = -(a + math.pi * 0.5)
        menhir(P, c, 1.0, 0.8, hh, yaw, 0.05 * (q - 2), rnd)
        L.MASON.lump((c.x, c.y, 0.15), (0.75, 0.6, 0.3), rnd)
    # the capstone table on three supports (the game's 2.6 x 0.9 x 2.6 box)
    for j in range(3):
        a = math.tau * j / 3.0 + 0.5
        L.dbox(P, "ashlar", (math.cos(a) * 0.75, math.sin(a) * 0.75, 0.4), (0.5, 0.45, 0.62), yaw=a, bevel=0.06, warp=0.04)
    L.rock_lump(P, "stone", (0.0, 0.0, 0.86), (1.35, 1.25, 0.2), rnd, seg=(9, 4))
    objs = finish(P, "Ring") + L.mason_end("Ring")
    export(objs, os.path.join(MODELS, "hermit_ring.glb"), "ring")
    preview(objs, "ring", [((-10, -11, 6), (0, 0, 2), 30), ((9, 8, 3), (0, 0, 1.8), 30)])


def asset_cairn():
    """The Anchoress's hermit cairn (realm_pois_east_marches.gd: five stacked blocks 2.3 m shrinking 0.36 a course, 0.62
    high, an iron pin on top): a dry-stone cairn of flat, rounded stones laid in rings, each course stepped in, a lid stone
    and the iron pin. Its origin at the foot (the ground), the game turns it per cairn."""
    reset()
    P = Parts()
    rnd = L.rnd_for(94)
    L.mason_begin(94)
    for j in range(5):
        w = 2.3 - 0.36 * j
        r = w * 0.5
        z0 = 0.04 + 0.62 * j
        n = max(6, int(math.tau * r / 0.42))
        for sub in range(2):
            zz = z0 + sub * 0.31
            off = rnd.random() * math.tau
            rr = r * (1.0 - 0.06 * sub)
            for q in range(n):
                a = off + math.tau * q / n
                ln = rr * math.tau / n * rnd.uniform(1.0, 1.25)
                L.dbox(P, "ashlar", (math.cos(a) * rr * 0.86, math.sin(a) * rr * 0.78, zz + 0.15),
                       (ln, 0.34 + rnd.uniform(-0.05, 0.06), 0.27 + rnd.uniform(-0.04, 0.03)), yaw=a + math.pi * 0.5 + rnd.uniform(-0.15, 0.15),
                       pitch=rnd.uniform(-0.08, 0.08), roll=rnd.uniform(-0.1, 0.1), bevel=0.07, warp=0.035)
        # the course's heart: rough fill under the ring
        L.dbox(P, "ashlar", (0.0, 0.0, z0 + 0.3), (r * 1.3, r * 1.15, 0.6), yaw=rnd.random(), bevel=0.1, warp=0.06)
    L.dbox(P, "ashlar", (0.0, 0.0, 3.25), (0.8, 0.7, 0.22), yaw=0.4, bevel=0.06, warp=0.04)
    cyl(P, "iron", (0.0, 0.0, 3.3), (0.0, 0.0, 3.76), 0.06, 0.04, seg=6)
    cyl(P, "iron", (0.0, 0.0, 3.62), (0.0, 0.0, 3.66), 0.12, 0.12, seg=8)
    objs = finish(P, "Cairn") + L.mason_end("Cairn")
    export(objs, os.path.join(MODELS, "anchor_cairn.glb"), "cairn")
    preview(objs, "cairn", [((-5, -6, 3), (0, 0, 1.6), 30)])


ASSETS = {"leanto": asset_leanto, "cell": asset_cell, "ring": asset_ring, "cairn": asset_cairn}
for k, fn in ASSETS.items():
    if not ONLY or k in ONLY:
        fn()
