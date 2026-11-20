"""The Sleeper's two fires (core/world/realm/wonders/r39/the_sleeper.gd), modelled (the visual pass's leftover: the hand's basin was a flat iron
box with a dark lid and the heart's furnace a rotated glowing cube on four sticks).

  tools/blender/run.sh polish_hearths.py -- [--preview DIR]

  art/models/sleeper_hearths.glb   Basin (the great fire basin on the palm: a hammered bronze bowl 3.6 m across on three clawed legs, a rolled
                                    rim, a band of studs, the legs braced to a ring; origin at the floor under the bowl's centre),
                                    Furnace (the heart: a squat iron-banded drum on four feet with a flared hood, a faceted glow gem in its
                                    mouth, a bellows-pipe; origin at the floor under it). Sets: iron (vertex-tinted), wax (the lit gem and
                                    embers, unshaded in the game).
"""
import math
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from polish_lib import *     # noqa: F401,F403
from mathutils import Vector

BRONZE = (0.30, 0.24, 0.14, 1.0)
BRONZE_HI = (0.46, 0.36, 0.18, 1.0)
IRON = (0.14, 0.13, 0.13, 1.0)
IRON_HI = (0.26, 0.24, 0.22, 1.0)
EMBER = (0.95, 0.42, 0.14, 1.0)


def basin():
    rnd = rnd_for(8101)
    P = CP()
    R = 1.8
    # the bowl: foot ring, belly, shoulder, rolled rim (outer wall, then the inner wall down to the coal bed)
    prof = [(0.7, 0.55), (0.9, 0.52), (1.2, 0.6), (1.55, 0.78), (1.75, 0.98), (1.82, 1.18), (1.84, 1.26), (1.78, 1.32), (1.7, 1.28), (1.66, 1.16),
            (1.5, 0.96), (1.2, 0.8), (0.9, 0.74), (0.0, 0.72)]
    def colfn(r, z, a):
        hi = 0.5 + 0.5 * math.sin(a * 5.0 + z * 6.0)
        k = 0.8 + 0.2 * hi
        base = BRONZE if z < 1.2 else BRONZE_HI
        return (base[0] * k, base[1] * k, base[2] * k, 1.0)
    lathe(P, "iron", prof, seg=30, colfn=colfn, center=(0, 0, 0), rough=0.012, rnd=rnd)
    # hammer facets: a ring of shallow dents is the jitter above; a band of studs under the rim
    for i in range(24):
        a = math.tau * i / 24
        blob(P, "iron", (math.cos(a) * 1.78, math.sin(a) * 1.78, 1.02), (0.07, 0.07, 0.07), BRONZE_HI, seg=6, rings=3)
    # a heavy iron band round the belly
    lathe(P, "iron", [(1.5, 0.74), (1.58, 0.74), (1.6, 0.8), (1.6, 0.9), (1.56, 0.94), (1.5, 0.94)], seg=30, col=IRON_HI, center=(0, 0, 0))
    # three clawed legs: a curved tube from the foot out under the belly, the claw gripping the floor
    for k in range(3):
        a = math.tau * k / 3 + 0.4
        d = Vector((math.cos(a), math.sin(a), 0))
        pts = [Vector((0, 0, 0)) + d * 1.5 + Vector((0, 0, 0.02)), d * 1.55 + Vector((0, 0, 0.18)), d * 1.4 + Vector((0, 0, 0.42)), d * 1.15 + Vector((0, 0, 0.62)),
               d * 0.85 + Vector((0, 0, 0.78))]
        tube(P, "iron", pts, [0.1, 0.11, 0.115, 0.12, 0.1], sides=7, col=IRON, col_tip=IRON_HI)
        # the claw toes
        for t in (-1, 0, 1):
            side = Vector((-d.y, d.x, 0))
            tp = d * 1.5 + side * (t * 0.1)
            tube(P, "iron", [tp + Vector((0, 0, 0.08)), tp + d * 0.18 + Vector((0, 0, 0.03)), tp + d * 0.34 + Vector((0, 0, 0.0))], [0.06, 0.045, 0.02], sides=5, col=IRON, col_tip=IRON_HI)
    # a brace ring tying the legs under the bowl
    for k in range(3):
        a0 = math.tau * k / 3 + 0.4
        a1 = math.tau * (k + 1) / 3 + 0.4
        pts = [Vector((math.cos(a0 + (a1 - a0) * s / 6) * 1.2, math.sin(a0 + (a1 - a0) * s / 6) * 1.2, 0.35)) for s in range(7)]
        tube(P, "iron", pts, [0.05] * 7, sides=5, col=IRON, col_tip=IRON)
    # the coal bed (lit, unshaded in the game): a mound of dull embers in the bowl
    for i in range(40):
        a = rnd.uniform(0, math.tau)
        r = rnd.uniform(0.0, 1.45) ** 0.9
        z = 0.78 + 0.5 * (1.0 - (r / 1.5) ** 2) * rnd.uniform(0.7, 1.0)
        c = (0.9 + rnd.uniform(-0.1, 0.05), 0.32 + rnd.uniform(-0.1, 0.1), 0.1, 1.0)
        blob(P, "wax", (math.cos(a) * r, math.sin(a) * r, z), (0.16, 0.14, 0.1), c, seg=6, rings=3, rough=0.2, rnd=rnd)
    return P


def furnace():
    rnd = rnd_for(8102)
    P = CP()
    # four feet
    for k in range(4):
        a = math.tau * k / 4 + math.pi / 4
        d = Vector((math.cos(a), math.sin(a), 0))
        tube(P, "iron", [d * 0.95 + Vector((0, 0, 0.0)), d * 0.88 + Vector((0, 0, 0.3)), d * 0.7 + Vector((0, 0, 0.55))], [0.09, 0.09, 0.08], sides=6, col=IRON, col_tip=IRON_HI)
    # the drum: a squat barrel of banded iron
    prof = [(0.78, 0.5), (0.9, 0.58), (0.98, 0.9), (1.0, 1.3), (0.96, 1.7), (0.86, 1.95), (0.62, 2.12), (0.4, 2.22)]
    lathe(P, "iron", prof, seg=20, colfn=lambda r, z, a: tuple(c * (0.8 + 0.2 * math.sin(a * 4 + z * 9)) for c in IRON_HI[:3]) + (1.0,), center=(0, 0, 0), rough=0.01, rnd=rnd)
    for zb in (0.72, 1.12, 1.52, 1.86):
        r = 1.0 if zb < 1.6 else 0.9
        lathe(P, "iron", [(r + 0.0, zb - 0.05), (r + 0.06, zb - 0.03), (r + 0.06, zb + 0.03), (r, zb + 0.05)], seg=20, col=IRON, center=(0, 0, 0))
    # the chimney collar and a rolled cap
    lathe(P, "iron", [(0.4, 2.22), (0.34, 2.5), (0.34, 2.72), (0.46, 2.78), (0.46, 2.86), (0.28, 2.86)], seg=14, col=IRON_HI, center=(0, 0, 0))
    # the mouth: a rounded opening on +x with a lit gem in it (the faceted heart), a lintel and jambs
    mouth = Vector((0.98, 0, 1.15))
    for sg in (-1, 1):
        bblock(P, "iron", (mouth.x, sg * 0.5, mouth.z), (0.22, 0.16, 0.9), rnd, bevel=0.04, tone="timber", colfn=lambda co: IRON)
    bblock(P, "iron", (mouth.x, 0, mouth.z + 0.52), (0.22, 1.2, 0.16), rnd, bevel=0.04, colfn=lambda co: IRON)
    bblock(P, "iron", (mouth.x, 0, mouth.z - 0.52), (0.22, 1.2, 0.16), rnd, bevel=0.04, colfn=lambda co: IRON)
    # the gem: an octahedron-ish faceted core, hot orange (unshaded in the game: kept under the bloom threshold there)
    blob(P, "wax", (mouth.x - 0.2, 0, mouth.z), (0.26, 0.42, 0.42), EMBER, seg=6, rings=3, rough=0.12, rnd=rnd, colfn=lambda u: (0.95, 0.35 + 0.35 * max(u.x, 0.0), 0.1, 1.0))
    # a bellows pipe from the back to the floor
    tube(P, "iron", [Vector((-0.9, 0, 0.9)), Vector((-1.25, 0, 0.8)), Vector((-1.5, 0, 0.45)), Vector((-1.6, 0, 0.12))], [0.1, 0.1, 0.1, 0.12], sides=7, col=IRON, col_tip=IRON_HI)
    # hearth stones round the feet
    for k in range(8):
        a = math.tau * k / 8 + 0.2
        bblock(P, "iron", (math.cos(a) * 1.3, math.sin(a) * 1.3, 0.1), (0.5, 0.4, 0.22), rnd, yaw=a, bevel=0.05, colfn=lambda co: (0.2, 0.19, 0.18, 1.0))
    return P


def build():
    reset()
    objs = []
    for nm, fn in (("Basin", basin), ("Furnace", furnace)):
        o = finish(fn(), nm)
        for ob in o:
            ob.name = nm + "__" + ob.name.split("__")[-1]
            ob.data.name = ob.name
        objs += o
    off = 0.0
    for ob in objs:
        if ob.name.startswith("Furnace"):
            ob.location.x = 5.0
    export(objs, os.path.join(MODELS, "sleeper_hearths.glb"), "sleeper_hearths")
    preview(objs, "hearths", [((5.5, -9, 4), (1.5, 0, 1.2), 34), ((-6, -7, 4.5), (0, 0, 1), 34), ((11, -4, 3.5), (5, 0, 1.4), 34), ((0.4, -4, 5.5), (0, 0, 0.9), 40)])
    for ob in objs:
        print("TRIS", ob.name, sum(len(p.vertices) - 2 for p in ob.data.polygons))


build()
