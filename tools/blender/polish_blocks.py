"""Dressed foundation blocks (the polish pass): a 1.04 m ashlar block, rounded at its arrises, its faces pillowed a little and
chipped at a corner, three variants, for the footings that stand on falling ground (the Lamplighters' Spire's plinth, which was
a column of plain boxes per cell: core/world/realm/realm_pois_east_marches.gd _plinth). The game stacks them (a MultiMesh, one
draw): the footing reads as coursed masonry, not a smooth block.

  tools/blender/run.sh polish_blocks.py -- [--preview DIR]

  art/models/found_block.glb   Block0 (plain), Block1 (a chipped corner), Block2 (moss on the top and a broken arris), 1.04 m cubes,
                               origin at the centre, vertex colour (stone grey, damp low, moss high).
"""
import math
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from polish_lib import *     # noqa: F401,F403
from mathutils import Vector

S = 1.04


def block(P, rnd, variant):
    bm = P.of("stone")
    lay = bm.verts.layers.float_color.get("vc") or bm.verts.layers.float_color.new("vc")
    r = bmesh.ops.create_cube(bm, size=S)
    bmesh.ops.bevel(bm, geom=list(bm.edges) + list(bm.verts), offset=0.06, segments=2, affect='EDGES', profile=0.5)
    # a grid of cuts on the big faces, so they can pillow and chip
    bmesh.ops.subdivide_edges(bm, edges=[e for e in bm.edges if e.calc_length() > 0.2], cuts=1, use_grid_fill=True)
    h = S * 0.5
    for v in bm.verts:
        p = v.co.copy()
        for i in range(3):
            if abs(p[i]) > h * 0.985:
                others = [abs(p[j]) / h for j in range(3) if j != i]
                near = max(others)
                p[i] += math.copysign(0.014 * max(0.0, 1.0 - near ** 3), p[i])
        p += Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-1, 1))) * 0.008
        v.co = p
    # chips and weathering
    if variant == 1:
        corner = Vector((1, 1, 1)) if rnd.random() < 0.5 else Vector((-1, 1, -1))
        for v in bm.verts:
            d = (v.co - corner * h).length
            if d < 0.3:
                v.co -= corner.normalized() * (0.3 - d) * 0.35
    if variant == 2:
        for v in bm.verts:
            if v.co.z > h * 0.9 and v.co.x < -h * 0.3:
                v.co.z -= 0.05 * (1.0 + rnd.uniform(-0.4, 0.4))
    for v in bm.verts:
        z = (v.co.z + h) / S
        damp = 1.0 - 0.18 * (1.0 - z)
        base = 0.52 + 0.1 * rnd.uniform(0, 1)
        c = [base * damp, base * 0.97 * damp, base * 0.92 * damp, 1.0]
        if variant == 2 and z > 0.7:
            m = (z - 0.7) / 0.3
            c = [c[0] * (1 - 0.7 * m) + 0.2 * m, c[1] * (1 - 0.7 * m) + 0.34 * m, c[2] * (1 - 0.7 * m) + 0.14 * m, 1.0]
        v[lay] = tuple(c)


def build():
    reset()
    objs = []
    for i, seed in enumerate((7101, 7102, 7103)):
        P = CP()
        block(P, rnd_for(seed), i)
        o = finish(P, "Block%d" % i, uv_tile={"stone": 2.0})
        for ob in o:
            ob.name = "Block%d" % i
            ob.data.name = ob.name
        objs += o
    off = 0.0
    for ob in objs:
        ob.location.x = off
        off += 1.4
    export(objs, os.path.join(MODELS, "found_block.glb"), "found_block")
    preview(objs, "blocks", [((1.4, -4.2, 1.6), (1.4, 0, 0), 40), ((0.5, -2.2, 3.0), (1.4, 0, 0), 40)])
    for ob in objs:
        print("TRIS", ob.name, sum(len(p.vertices) - 2 for p in ob.data.polygons))


build()
