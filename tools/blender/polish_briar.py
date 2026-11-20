"""The Thornwarden's briar wall (core/world/henge_raid.gd), modelled (the visual pass's leftover: procedural CreatureMesh tubes).

  tools/blender/run.sh polish_briar.py -- [--preview DIR]

  art/models/briar_wall.glb   BriarA, BriarB, BriarC (a 3.3 m module of the wall, 5.2 m high, 1.8 m through: a mat of old canes
                              that climb and arch over and cross each other in two planes, red-brown to near-black, thorns
                              along every cane, a few dead leaf clusters) and BriarTrunk (a briar grown thick as a tree, 8 m,
                              the wall's silhouette). Local frame like the game's wall: x along the wall, +y up (Godot), z across.
Frame in Blender: x along the wall, y across, z up; the glb carries it to Godot's y up.
"""
import math
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from polish_lib import *     # noqa: F401,F403
from mathutils import Vector

LEN = 3.3
HEIGHT = 7.0
DEPTH = 1.1
LO = False                    # the far version of each module (under ~1k tris): fewer canes, 3 sides, no thorns, no leaves

BARK = [(0.15, 0.085, 0.06, 1), (0.11, 0.065, 0.05, 1), (0.19, 0.1, 0.07, 1), (0.09, 0.07, 0.06, 1)]
BARK_RED = (0.26, 0.09, 0.06, 1)
THORN = (0.2, 0.1, 0.07, 1)
THORN_TIP = (0.52, 0.2, 0.12, 1)
LEAF = [(0.16, 0.12, 0.05, 1), (0.22, 0.13, 0.05, 1), (0.12, 0.1, 0.06, 1)]


def cane(P, rnd, x, y, tall, lean, r0, sides=5, wob=0.35, arch=0.0, thorn_every=0.34):
    """One cane: from the ground at (x, y), climbing `tall`, leaning along (lean) and wobbling; the tip arches over."""
    n = 7 if LO else 11
    pts, rad = [], []
    ph = rnd.uniform(0, 6.28)
    ph2 = rnd.uniform(0, 6.28)
    cur = Vector((x, y, -0.15))
    for q in range(n):
        t = q / (n - 1)
        px = x + lean[0] * t * tall + math.sin(t * 3.6 + ph) * wob * (0.3 + t)
        py = y + lean[1] * t * tall + math.cos(t * 3.0 + ph2) * wob * 0.6 * (0.3 + t)
        pz = -0.15 + t * tall - arch * t * t * tall * 0.35
        pts.append(Vector((px, py, pz)))
        rad.append(max(r0 * (1.0 - t * 0.82), 0.014))
    c0 = BARK[rnd.randrange(len(BARK))]
    cols = BARK_RED if rnd.random() < 0.18 else c0
    tube(P, "bramble", pts, rad, sides=3 if LO else sides, col=c0, col_tip=cols)
    if LO:
        return pts
    # thorns: pairs along the cane, angled outward and back toward the root
    d = 0.0
    for q in range(n - 1):
        a, b = pts[q], pts[q + 1]
        seg = (b - a).length
        k = 0.0
        while k < seg:
            f = k / seg
            p = a.lerp(b, f)
            tang = (b - a).normalized()
            r = rad[q] * (1 - f) + rad[q + 1] * f
            if r > 0.02:
                for side in (0, 1):
                    ang = rnd.uniform(0, 6.28)
                    out = Vector((math.cos(ang), math.sin(ang), rnd.uniform(-0.3, 0.2)))
                    dirv = (out * 0.8 - tang * 0.35).normalized()
                    thorn(P, "bramble", p + out * r * 0.6, dirv, rnd.uniform(0.16, 0.3) * (0.6 + r * 5), max(r * 0.45, 0.012), THORN, THORN_TIP)
            k += thorn_every * rnd.uniform(0.8, 1.25)
    return pts


def leaves(P, rnd, c, n=4):
    for _ in range(n):
        d = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-0.3, 0.6))).normalized()
        base = Vector(c)
        s = rnd.uniform(0.12, 0.22)
        w = s * 0.55
        side = d.cross(Vector((0, 0, 1)))
        if side.length < 1e-3:
            side = Vector((1, 0, 0))
        side.normalize()
        bm = P.of("bramble")
        lay = bm.verts.layers.float_color.get("vc") or bm.verts.layers.float_color.new("vc")
        col = LEAF[rnd.randrange(len(LEAF))]
        vs = []
        for p in (base, base + d * s * 0.5 + side * w, base + d * s, base + d * s * 0.5 - side * w):
            v = bm.verts.new(p)
            v[lay] = col
            vs.append(v)
        try:
            bm.faces.new(vs)
        except ValueError:
            pass


def module(seed, trunk=False):
    rnd = rnd_for(seed)
    P = CP()
    nc = 9 if LO else 16
    for i in range(nc):
        x = -LEN * 0.5 + LEN * (i + rnd.uniform(0.1, 0.9)) / nc
        y = rnd.uniform(-DEPTH * 0.5, DEPTH * 0.5)
        tall = HEIGHT * rnd.uniform(0.8, 1.22)
        lean = (rnd.uniform(-0.3, 0.3), rnd.uniform(-0.35, 0.35))
        cane(P, rnd, x, y, tall, lean, rnd.uniform(0.11, 0.2), sides=5, wob=0.6, arch=rnd.uniform(0.3, 0.9), thorn_every=0.5)
    # the crossing canes: long ones that lace the wall along its length (two planes)
    for i in range(0 if LO else 8):
        x = -LEN * 0.5 + rnd.uniform(0, LEN * 0.3)
        y = (-0.3 if i % 2 else 0.3) + rnd.uniform(-0.1, 0.1)
        z0 = rnd.uniform(0.5, HEIGHT * 0.7)
        n = 7
        pts, rad = [], []
        ph = rnd.uniform(0, 6.28)
        for q in range(n):
            t = q / (n - 1)
            pts.append(Vector((x + t * LEN * rnd.uniform(0.75, 1.05), y + math.sin(t * 5 + ph) * 0.3, z0 + math.sin(t * 4 + ph) * 0.55 + t * rnd.uniform(-0.6, 0.9))))
            rad.append(max(0.05 * (1 - t * 0.6), 0.016))
        c0 = BARK[rnd.randrange(len(BARK))]
        tube(P, "bramble", pts, rad, sides=4, col=c0, col_tip=BARK_RED)
        for q in range(1, n - 1, 2):
            ang = rnd.uniform(0, 6.28)
            out = Vector((rnd.uniform(-0.4, 0.4), math.cos(ang), math.sin(ang)))
            thorn(P, "bramble", pts[q], out, rnd.uniform(0.16, 0.26), 0.022, THORN, THORN_TIP)
    # the body of the thicket: loops and snarls of thin cane laid through the depth, so the wall closes the sight
    for i in range(7 if LO else 34):
        cx = rnd.uniform(-LEN * 0.5, LEN * 0.5)
        cy = rnd.uniform(-0.35, 0.35)
        cz = rnd.uniform(0.5, HEIGHT * 0.85)
        rr = rnd.uniform(0.3, 0.7)
        a0 = rnd.uniform(0, 6.28)
        tilt = rnd.uniform(-1.0, 1.0)
        n = 6
        pp = []
        for q in range(n):
            t = q / (n - 1)
            ang = a0 + t * rnd.uniform(3.0, 4.6)
            pp.append(Vector((cx + math.cos(ang) * rr, cy + math.sin(ang) * rr * 0.55 + tilt * t * 0.2, cz + math.sin(ang * 0.8 + a0) * rr * 0.7 + t * 0.25)))
        c0 = BARK[rnd.randrange(len(BARK))]
        tube(P, "bramble", pp, [(0.05 if LO else 0.03) - 0.012 * (q / (n - 1)) for q in range(n)], sides=3, col=c0, col_tip=BARK_RED)
        if i % 3 == 0 and not LO:
            for q in (1, 3):
                out = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-0.3, 0.6)))
                thorn(P, "bramble", pp[q], out, rnd.uniform(0.12, 0.2), 0.016, THORN, THORN_TIP)
    # a low mat at the foot and leaf clusters
    for i in range(0 if LO else 4):
        x = -LEN * 0.5 + LEN * (i + 0.5) / 4
        cane(P, rnd, x, rnd.uniform(-0.5, 0.5), rnd.uniform(1.4, 2.3), (rnd.uniform(-0.5, 0.5), rnd.uniform(-0.6, 0.6)), 0.08, sides=4, wob=0.5, arch=0.9, thorn_every=0.55)
    for i in range(0 if LO else 4):
        leaves(P, rnd, (rnd.uniform(-LEN * 0.5, LEN * 0.5), rnd.uniform(-0.4, 0.4), rnd.uniform(0.5, HEIGHT * 0.9)), 3)
    if trunk:
        tall = 11.5
        pts, rad = [], []
        for q in range(10):
            t = q / 9.0
            pts.append(Vector((math.sin(t * 4.0) * 0.55, math.cos(t * 3.0) * 0.45, -0.3 + t * tall)))
            rad.append(max(0.6 * (1 - t) ** 0.8, 0.06))
        tube(P, "bramble", pts, rad, sides=7, col=(0.1, 0.06, 0.05, 1), col_tip=(0.2, 0.1, 0.07, 1))
        for k in range(0 if LO else 12):
            t = 0.1 + 0.8 * k / 12.0
            q = int(t * 9)
            base = pts[q].lerp(pts[min(q + 1, 9)], t * 9 - q)
            ang = k * 2.4
            out = Vector((math.cos(ang), math.sin(ang), 0.45)).normalized()
            thorn(P, "bramble", base + out * 0.3, out, rnd.uniform(0.3, 0.55), 0.06, THORN, THORN_TIP)
        for k in range(0 if LO else 5):
            t = 0.2 + 0.12 * k
            q = int(t * 9)
            base = pts[q]
            ang = k * 2.4 + 0.7
            out = Vector((math.cos(ang), math.sin(ang), 0.35)).normalized()
            pp = [base + out * (0.15 + 0.5 * s / 5.0) + Vector((0, 0, 0.45 * (s / 5.0) ** 2 * 1.4)) for s in range(6)]
            tube(P, "bramble", pp, [0.07 * (1 - s / 6.0) + 0.012 for s in range(6)], sides=4, col=(0.14, 0.08, 0.06, 1), col_tip=(0.2, 0.1, 0.07, 1))
    return P


def build():
    global LO
    reset()
    objs = []
    for nm, seed, tr, lo in (("BriarA", 3301, False, False), ("BriarB", 3302, False, False), ("BriarC", 3303, False, False), ("BriarTrunk", 3304, True, False),
                             ("BriarLoA", 3301, False, True), ("BriarLoB", 3302, False, True), ("BriarLoC", 3303, False, True), ("BriarLoTrunk", 3304, True, True)):
        LO = lo
        P = module(seed, tr)
        o = finish(P, nm)
        for ob in o:
            ob.name = nm
            ob.data.name = nm
        objs += o
    # lay them side by side for the preview only (the glb keeps them at the origin: the game places each)
    off = 0.0
    for ob in objs:
        ob.location.x += off
        off += 3.6
    export(objs, os.path.join(MODELS, "briar_wall.glb"), "briar_wall")
    preview(objs, "briar", [((6, -16, 3.5), (6.5, 0, 2.6), 34), ((1.5, -7, 2.2), (1.5, 0, 2.4), 36), ((12, -9, 7), (12, 0, 3.5), 40)])
    for ob in objs:
        print("TRIS", ob.name, sum(len(p.vertices) - 2 for p in ob.data.polygons))


build()
