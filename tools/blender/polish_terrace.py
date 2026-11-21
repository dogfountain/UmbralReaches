"""The Pilgrims' Threshold's terrace bays (core/world/realm/rift/threshold.gd), modelled (the visual pass's leftover: "the chasm's
stair-stepped walls": a plain block with a few kit boxes on it per tier).

  tools/blender/run.sh polish_terrace.py -- [--preview DIR]

  art/models/terrace_bay.glb   Bay0, Bay1 (4 m along the wall, 4 m tall, 0.9 m out from the rock): a facing of coursed, rounded
                               ashlar, corner pilasters with base and capital, a pointed blind arch in voussoirs on the face, a
                               string course, a moulded coping and a balustrade with post caps. Frame: Blender x = out from the face
                               (the pool side), y along the wall, z up; the origin at the foot of the face on the wall's line, y
                               centred. The game turns it for the east wall and stretches it to the tier's height.
"""
import math
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from polish_lib import *     # noqa: F401,F403
from mathutils import Vector

BAY = 4.0
H = 4.0


def bay(seed, variant):
    rnd = rnd_for(seed)
    P = CP()
    # the facing: courses 0.5 m, blocks 0.9-1.5 m long, staggered, a hand proud of the wall plane (x 0 .. 0.2)
    courses = 7
    ch = (H - 0.8) / courses
    for r in range(courses):
        z = 0.15 + ch * (r + 0.5)
        y = -BAY * 0.5 + 0.55
        off = 0.0 if r % 2 == 0 else -0.5
        y += off
        while y < BAY * 0.5 - 0.55:
            ln = rnd.uniform(0.9, 1.5)
            ln = min(ln, BAY * 0.5 - 0.55 - y)
            if ln < 0.3:
                break
            # the arch's opening leaves the middle clear above the springing: the blocks stay (it is blind), only the string course shows
            bblock(P, "stone", (0.1 + rnd.uniform(-0.02, 0.03), y + ln * 0.5, z), (0.26, ln * 0.97, ch * 0.96), rnd, bevel=0.045, warp=0.012)
            y += ln
    # corner pilasters, base block and capital
    for sg in (-1, 1):
        yy = sg * (BAY * 0.5 - 0.35)
        bblock(P, "stone", (0.3, yy, 0.25), (0.72, 0.84, 0.5), rnd, bevel=0.06)                         # base
        for q in range(3):
            bblock(P, "stone", (0.28, yy, 0.5 + 0.95 + q * 0.9), (0.52, 0.74, 0.9), rnd, bevel=0.05)    # shaft drums
        bblock(P, "stone", (0.34, yy, H - 0.55), (0.78, 0.98, 0.42), rnd, bevel=0.07)                    # capital
        bblock(P, "stone", (0.34, yy, H - 0.18), (0.86, 1.06, 0.2), rnd, bevel=0.04)                     # abacus
    # the string course under the arch's springing, along the face between the pilasters
    bblock(P, "stone", (0.2, 0.0, 1.35), (0.42, BAY - 1.9, 0.16), rnd, bevel=0.035)
    # the blind pointed arch: voussoirs round a pointed head, 1.8 m clear, springing at 1.5 m: two arcs of radius R whose centres lie
    # on the springing line at the far jamb, meeting at the point
    w = 1.8
    spring = 1.5
    R = w * 0.96
    phi_max = math.acos((R - w * 0.5) / R)
    nh = 6 if variant == 0 else 7
    for side in (-1, 1):
        cy = -side * (R - w * 0.5)
        for i in range(nh):
            phi = phi_max * (i + 0.5) / nh
            py = cy + side * R * math.cos(phi)
            pz = spring + R * math.sin(phi)
            th = (math.pi * 0.5 - phi) * (1.0 if side < 0 else -1.0)
            bblock(P, "stone", (0.36, py, pz), (0.2, 0.34, 0.42), rnd, bevel=0.03, warp=0.006, pitch=th)
    bblock(P, "stone", (0.38, 0.0, spring + R * math.sin(phi_max) + 0.02), (0.24, 0.3, 0.3), rnd, bevel=0.04, warp=0.006)       # the keystone
    # the arch's jambs below the springing
    for sg in (-1, 1):
        bblock(P, "stone", (0.36, sg * w * 0.5, spring * 0.5 + 0.1), (0.2, 0.34, spring - 0.2), rnd, bevel=0.03, warp=0.008)
    # coping: a moulded lip along the walk's edge, a hand proud of the face; under it a drip course
    bblock(P, "stone", (0.18, 0.0, H + 0.12), (0.92, BAY, 0.24), rnd, bevel=0.06, warp=0.006)
    bblock(P, "stone", (0.06, 0.0, H - 0.1), (0.5, BAY - 0.2, 0.16), rnd, bevel=0.03, warp=0.006)
    # the balustrade on the walk: a low wall 0.8 m with a cap, and a post at each pilaster and one in the middle, capped
    bblock(P, "stone", (0.42, 0.0, H + 0.24 + 0.42), (0.26, BAY - 0.5, 0.84), rnd, bevel=0.04, warp=0.005)
    bblock(P, "stone", (0.42, 0.0, H + 0.24 + 0.88), (0.38, BAY - 0.3, 0.1), rnd, bevel=0.03, warp=0.004)
    for y in (-BAY * 0.5 + 0.3, 0.0, BAY * 0.5 - 0.3):
        bblock(P, "stone", (0.42, y, H + 0.24 + 0.55), (0.46, 0.46, 1.1), rnd, bevel=0.05, warp=0.006)
        bblock(P, "stone", (0.42, y, H + 0.24 + 1.18), (0.56, 0.56, 0.14), rnd, bevel=0.04, warp=0.004)
        bblock(P, "stone", (0.42, y, H + 0.24 + 1.32), (0.3, 0.3, 0.16), rnd, bevel=0.04, warp=0.004)
    return P


def build():
    reset()
    objs = []
    for i, seed in enumerate((7201, 7202)):
        o = finish(bay(seed, i), "Bay%d" % i, uv_tile={"stone": 2.0})
        for ob in o:
            ob.name = "Bay%d" % i
            ob.data.name = ob.name
        objs += o
    off = 0.0
    for ob in objs:
        ob.location.y = off
        off += 4.6
    export(objs, os.path.join(MODELS, "terrace_bay.glb"), "terrace_bay")
    preview(objs, "terrace", [((9, -2, 3.5), (0, 1.0, 3.0), 36), ((7, -8, 6), (0, 3, 2.2), 36), ((4, 0, 3.2), (0, 2.4, 3.0), 50)])
    for ob in objs:
        print("TRIS", ob.name, sum(len(p.vertices) - 2 for p in ob.data.polygons))


build()
