"""The works' stacks of cut salt (core/world/realm/east_works_kit.gd, realm_pois_east_works.gd, realm_pois_east_saltmarket.gd), modelled
(the visual pass's leftover, "the salt-sack stairs": Block_Stack in r37e_works.glb is five courses of plain boxes stepped back like stairs).

  tools/blender/run.sh polish_salt.py -- [--preview DIR]

  art/models/salt_stack.glb   Block_Stack: the same footprint and height as the collision box (3.2 m long x 1.7 deep x 2.0 high, origin on the
                              ground at its middle), a stepped stack of hand-cut salt loaves (bevelled, uneven, chipped, lying in courses
                              with their joints broken), a plank on the top course, two sacks slumped against the low end and a rope.
                              Sets: chalk (the loaves), timber (the plank), cloth (the sacks and the rope, vertex-coloured).
Frame: Blender (x, y, z) = the game's (x, -z, y).
"""
import math
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from polish_lib import *     # noqa: F401,F403
from mathutils import Vector


def stack():
    rnd = rnd_for(8201)
    P = CP()
    for r in range(5):
        nx = 6 - r
        for i in range(nx):
            for j in (-1, 1):
                w = 0.5 + rnd.uniform(-0.03, 0.04)
                d = 0.76 + rnd.uniform(-0.04, 0.05)
                h = 0.36 + rnd.uniform(-0.02, 0.03)
                c = (-(nx - 1) * 0.27 + i * 0.54 + rnd.uniform(-0.02, 0.02), j * 0.4 + (0.03 if (i + r) % 2 else -0.03) + rnd.uniform(-0.02, 0.02),
                     0.19 + r * 0.38)
                bblock(P, "chalk", c, (w, d, h), rnd, yaw=rnd.uniform(-0.05, 0.05), bevel=0.05, warp=0.012, pitch=rnd.uniform(-0.02, 0.02), roll=rnd.uniform(-0.02, 0.02),
                       colfn=lambda co: (0.8, 0.82, 0.8, 1.0))
    # chips: two loaves shorter, a corner knocked off (a wedge of salt at the foot)
    for k in range(5):
        bblock(P, "chalk", (rnd.uniform(-1.4, 1.4), rnd.choice((-0.95, 0.95)) + rnd.uniform(-0.1, 0.1), 0.07), (0.22, 0.18, 0.14), rnd, yaw=rnd.uniform(0, 3), bevel=0.03, warp=0.01,
               colfn=lambda co: (0.78, 0.8, 0.78, 1.0))
    # the plank on the top course
    bblock(P, "timber", (0.0, 0.0, 1.98), (2.0, 1.7, 0.08), rnd, bevel=0.015, warp=0.006, colfn=lambda co: (0.30, 0.22, 0.15, 1.0))
    bblock(P, "timber", (0.4, 0.0, 2.05), (0.12, 1.7, 0.06), rnd, bevel=0.01, warp=0.004, colfn=lambda co: (0.26, 0.19, 0.13, 1.0))
    # two sacks slumped against the low end (-x side is the high end in the game: they lean on the +x low end)
    for (sx, sy, sa) in ((1.45, 0.45, 0.4), (1.5, -0.35, -0.3)):
        blob(P, "cloth", (sx, sy, 0.24), (0.34, 0.26, 0.24), (0.55, 0.5, 0.4, 1.0), seg=9, rings=5, yaw=sa, rough=0.08, rnd=rnd,
             colfn=lambda u: (0.58 + 0.1 * u.z, 0.52 + 0.1 * u.z, 0.4 + 0.08 * u.z, 1.0))
        blob(P, "cloth", (sx - 0.02, sy, 0.46), (0.12, 0.1, 0.1), (0.45, 0.4, 0.3, 1.0), seg=6, rings=3, yaw=sa, rough=0.15, rnd=rnd)     # the tied neck
    # a loop of rope over the top
    pts = [Vector((-0.9 + 1.8 * t, 0.62 * math.sin(t * math.pi), 2.08 + 0.1 * math.sin(t * 6))) for t in [i / 8 for i in range(9)]]
    tube(P, "cloth", pts, [0.018] * 9, sides=5, col=(0.42, 0.34, 0.22, 1.0), col_tip=(0.42, 0.34, 0.22, 1.0))
    return P


def build():
    reset()
    o = finish(stack(), "Block_Stack", uv_tile={"chalk": 2.0, "timber": 2.0, "cloth": 2.0})
    for ob in o:
        ob.name = "Block_Stack__" + ob.name.split("__")[-1]
        ob.data.name = ob.name
    export(o, os.path.join(MODELS, "salt_stack.glb"), "salt_stack")
    preview(o, "salt", [((5, -6, 3), (0, 0, 0.9), 40), ((-4, -5, 2.2), (0.3, 0, 0.9), 40), ((0, -6.5, 4.5), (0, 0, 0.8), 36)])
    for ob in o:
        print("TRIS", ob.name, sum(len(p.vertices) - 2 for p in ob.data.polygons))


build()
