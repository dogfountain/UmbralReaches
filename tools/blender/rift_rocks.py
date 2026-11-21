"""THE ASHEN RIFT's loose basalt (r39, from scratch): the rock the lava cooled into, modelled once and set about the rift by
core/world/realm/rift/features.gd (shores, islands, crust rafts, stacks) and threshold.gd (the Watchers' plinths).

  tools/blender/run.sh rift_rocks.py -- [--preview DIR]

  art/models/rift_rocks.glb   one node per variant, `<Variant>__basalt` (or `__ash`: an ember-edged foot) and `<Variant>-colonly`,
                              each in its own frame: origin on the lava line (game y -15.5 = 0 here), +x across, game -z = Blender +y.

Every piece is a few overlapping blocks fused into one skin and dissolved into broad facets (rift_lib.rock_mass): chunky natural rock.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rift_lib as R

OUT = os.path.join(R.MODELS, "rift_rocks.glb")
L = R.LAVA


def _blobs(rnd, n, rx, rz, top, foot, lean=6.0, tall=0.0):
    """n blocks scattered in an ellipse rx x rz (game), tops round `top` (m over the lava), feet at `foot`."""
    out = []
    for i in range(n):
        a = rnd.uniform(0, math.tau)
        d = math.sqrt(rnd.uniform(0.0, 1.0)) * 0.6
        cx, cz = math.cos(a) * rx * d, math.sin(a) * rz * d
        hx = rnd.uniform(0.45, 0.8) * rx * (1.0 - d * 0.5)
        hz = rnd.uniform(0.45, 0.8) * rz * (1.0 - d * 0.5)
        t = top * rnd.uniform(0.55, 1.0) * (1.0 - d * 0.6) + (tall if i == 0 else 0.0)
        h = (t - foot) * 0.5
        out.append(((cx, L + foot + h, cz), (hx, h, hz), rnd.uniform(-40, 40), rnd.uniform(-lean, lean) * 2.0, rnd.uniform(-lean, lean) * 2.0))
    return out


def variant(objs, name, blocks, seed, style="basalt", voxel=0.3, disp=0.5, tris=1600, facet=10.0, flat=()):
    ob = R.rock_mass(name, blocks, voxel=voxel, disp=disp, seed=seed, tris=tris, facet=facet, flat=flat)
    vis, col = R.rock_finish(ob, name, style, col_ratio=0.18)
    for o in (vis, col):                     # the origin on the lava line at the piece's centre (the game places by it)
        for v in o.data.vertices:
            v.co.z -= L
    objs += [vis, col]
    print("ROCK", name, len(vis.data.polygons), "tris")


def build():
    R.reset()
    objs = []
    rnd = random.Random(3901)
    # islands: low, broad, a few broken ledges (tops 0.5 .. 1.5 m over the lava)
    for i, (rx, rz, top) in enumerate([(4.2, 3.0, 1.1), (5.5, 3.6, 0.8), (3.0, 2.4, 1.5), (6.5, 4.5, 0.6)]):
        b = _blobs(rnd, 5 + i, rx, rz, top, -3.0, lean=5.0)
        variant(objs, "Isle%d" % i, b, 10 + i, "ash" if i % 2 else "basalt", tris=1400)
    # crust rafts: thin, wide, a jagged edge (tops 0.15 .. 0.35 m over the lava)
    for i, (rx, rz) in enumerate([(5.0, 3.2), (7.0, 4.0), (3.6, 2.6)]):
        b = _blobs(rnd, 7, rx, rz, 0.32, -1.2, lean=2.5)
        variant(objs, "Plate%d" % i, b, 20 + i, "ash", disp=0.3, tris=900, facet=7.0)
    # shores: along a wall foot, the back high (buried in the wall), the front a broken step to the lava; long along game z
    for i, (ln, dp, hi) in enumerate([(12.0, 4.5, 5.0), (9.0, 3.8, 3.2), (14.0, 5.5, 7.5)]):
        b = []
        n = 6
        for k in range(n):
            z = (k / (n - 1) - 0.5) * ln
            back = hi * rnd.uniform(0.7, 1.15)
            b.append(((-dp * 0.25 + rnd.uniform(-0.5, 0.5), L + (back - 3.0) * 0.5, z), (dp * rnd.uniform(0.32, 0.5), (back + 3.0) * 0.5, ln / n * rnd.uniform(0.6, 0.95)), rnd.uniform(-22, 22), rnd.uniform(-12, 12), rnd.uniform(-10, 10)))
            front = rnd.uniform(0.5, 1.4)
            b.append(((dp * 0.3, L + (front - 3.0) * 0.5, z + rnd.uniform(-0.6, 0.6)), (dp * 0.35, (front + 3.0) * 0.5, ln / n * 0.7), rnd.uniform(-25, 25), 0, rnd.uniform(-5, 5)))
        variant(objs, "Shore%d" % i, b, 30 + i, "basalt", tris=2000)
    # stacks: tall broken basalt in the molten heart (skyline)
    for i, (h, r) in enumerate([(9.0, 2.2), (13.0, 2.8), (6.5, 1.8)]):
        b = [((0, L + (h - 3.0) * 0.5, 0), (r, (h + 3.0) * 0.5, r * 0.9), rnd.uniform(0, 60), rnd.uniform(-4, 4), rnd.uniform(-4, 4))]
        for k in range(3):
            a = rnd.uniform(0, math.tau)
            hh = h * rnd.uniform(0.35, 0.7)
            b.append(((math.cos(a) * r * 0.9, L + (hh - 3.0) * 0.5, math.sin(a) * r * 0.9), (r * 0.7, (hh + 3.0) * 0.5, r * 0.6), rnd.uniform(0, 90), rnd.uniform(-8, 8), 0))
        variant(objs, "Stack%d" % i, b, 40 + i, "basalt", tris=1600, disp=0.6)
    # the Watchers' plinth: a broad basalt table, its top flat at +1.3 (rift/threshold.gd WATCHER_LIFT), the sides broken
    b = [((0, L + (1.3 - 3.5) * 0.5, 0), (6.6, (1.3 + 3.5) * 0.5, 6.6), 8, 0, 0)]
    for k in range(7):
        a = k / 7.0 * math.tau + rnd.uniform(-0.2, 0.2)
        b.append(((math.cos(a) * 6.2, L + (0.7 - 3.5) * 0.5, math.sin(a) * 6.2), (2.6, (0.7 + 3.5) * 0.5, 2.0), math.degrees(a) + rnd.uniform(-20, 20), 0, rnd.uniform(-6, 6)))
    variant(objs, "Plinth", b, 50, "ash", tris=2400, flat=[((-6.2, L + 1.0, -6.2), (6.2, L + 1.6, 6.2))])
    # the dressing the banks and islands are crowded with (set densely by features.gd, no collision):
    # boulders: chunky, half sunk (tops 0.5 .. 1.6 m over the lava)
    for i, (r, top) in enumerate([(0.9, 0.8), (1.4, 1.2), (2.0, 1.6), (1.1, 0.5), (1.7, 0.9)]):
        b = [((0, L + (top - 1.4) * 0.5, 0), (r, (top + 1.4) * 0.5, r * rnd.uniform(0.7, 0.95)), rnd.uniform(0, 90), rnd.uniform(-12, 12), rnd.uniform(-12, 12))]
        for k in range(2):
            a = rnd.uniform(0, math.tau)
            t = top * rnd.uniform(0.4, 0.75)
            b.append(((math.cos(a) * r * 0.7, L + (t - 1.4) * 0.5, math.sin(a) * r * 0.7), (r * 0.55, (t + 1.4) * 0.5, r * 0.5), rnd.uniform(0, 90), rnd.uniform(-15, 15), rnd.uniform(-15, 15)))
        variant(objs, "Boulder%d" % i, b, 60 + i, "basalt" if i % 2 == 0 else "ash", voxel=0.14, disp=0.22, tris=420)
    # cooled spatter: flat lumpy heaps where the lava threw itself on the bank (tops 0.25 .. 0.6)
    for i, (rx, rz) in enumerate([(1.6, 1.1), (2.4, 1.5), (1.2, 0.9)]):
        b = []
        for k in range(6):
            a = rnd.uniform(0, math.tau)
            d = rnd.uniform(0.0, 0.7)
            t = rnd.uniform(0.25, 0.6)
            b.append(((math.cos(a) * rx * d, L + (t - 0.8) * 0.5, math.sin(a) * rz * d), (rx * rnd.uniform(0.3, 0.55), (t + 0.8) * 0.5, rz * rnd.uniform(0.3, 0.55)), rnd.uniform(0, 90), rnd.uniform(-8, 8), rnd.uniform(-8, 8)))
        variant(objs, "Spatter%d" % i, b, 70 + i, "ash", voxel=0.12, disp=0.16, tris=380)
    # crust slabs: broken plates of cooled crust heaved up on edge (0.35 m thick, tipped 15 .. 35 degrees)
    for i, (lx, lz, tilt) in enumerate([(3.0, 2.0, 18.0), (2.2, 1.6, 32.0), (3.6, 2.4, 24.0)]):
        b = [((0, L + 0.1, 0), (lx * 0.5, 0.18, lz * 0.5), rnd.uniform(0, 90), tilt, rnd.uniform(-8, 8)),
             ((lx * 0.45, L - 0.05, lz * 0.2), (lx * 0.25, 0.16, lz * 0.3), rnd.uniform(0, 90), tilt * 0.4, rnd.uniform(-10, 10))]
        variant(objs, "Slab%d" % i, b, 80 + i, "ash", voxel=0.1, disp=0.08, tris=320)
    R.export_clean(objs, OUT, "rift_rocks")
    vis = [o for o in objs if not o.name.endswith("-colonly")]
    # review: lay them out in a row
    x = 0.0
    for o in vis:
        o.location.x = x
        x += 16.0
    R.review(vis, "rift_rocks", [((x * 0.5, -90, 30), (x * 0.5, 0, 0), 35)] + [((o.location.x + 9, -14, 7), (o.location.x, 0, 0.5), 35) for o in vis[::2]])


build()
