"""Ruin set pieces for the places the Realm's kits used to build out of boxes. Modelled by script; no scans, no downloads.

-> art/models/props/ruin_*.glb. Each file holds parts named `<Part>__<set>` (hewn = one dressed block seen close,
iron, timber), modelled at the origin with the pivot on the ground; core/world/realm/prop_models.gd merges the parts
a place uses into one mesh per set. Collision is not in the file: the builder keeps the boxes it always had.

  ruin_shrine    the Lanternless Shrine (Lanternless Moor): Obelisk (a stepped base of nine stones, a tapered
                 shaft with the offering niche and two lettered panels, four iron arms with the lantern hooks struck
                 off), kneeling stones BlockA..D (worn, broken, split, sunk), Cap (a fallen capstone), LanternA/B
                 (cold lanterns left on the ground, one crushed)

A part's front looks along Blender -Y = Godot +Z (the way the builders face things).

  tools/blender/run.sh props_ruins.py -- [--only ruin_shrine] [--preview DIR] [--export]
"""
import bmesh
import math
import os
import sys
from mathutils import Vector, Matrix

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import props_stones as PS  # noqa: E402
import mp_lib as L  # noqa: E402
from mp_lib import Mk, oct_ring, block, chop, bar, trs, move, flat  # noqa: E402

PROPS = PS.PROPS


def top_face(verts):
    fs = {f for v in verts if v.is_valid for f in v.link_faces}
    return max(fs, key=lambda f: (f.normal.z > 0.7, f.calc_center_median().z, len(f.verts)))


# --- the Lanternless Shrine ----------------------------------------------------------------------------
def shrine_obelisk():
    mk = Mk(3401, "hewn")
    r = mk.r
    gap = 0.014
    # the lower course: four long stones laid pinwheel round a core, z -0.3 .. 0.4 (the old box: 3.2 x 3.2 x 0.6)
    lay = [(-0.5, -1.1, 2.2, 1.0), (1.1, -0.5, 1.0, 2.2), (0.5, 1.1, 2.2, 1.0), (-1.1, 0.5, 1.0, 2.2), (0.0, 0.0, 1.2, 1.2)]
    for i, (cx, cy, w, d) in enumerate(lay):
        h = 0.7 + r.uniform(-0.012, 0.016)
        vs, _ = block(mk, (w - gap, d - gap, h), ch=0.04, j=0.008, ease=0.035, chip=0.02)
        m = trs((cx, cy, -0.3), 0.0, r.uniform(-0.006, 0.006), r.uniform(-0.006, 0.006))
        if i == 1:                                   # one stone has settled outward
            m = trs((cx + 0.035, cy - 0.01, -0.36), 0.014, 0.0, 0.04)
        move(mk, vs, m)
        if i == 0:                                   # a corner broken off, the piece lying by it
            chop(mk, vs, (-1.12, -1.6, 0.22), (-1.0, -0.75, 0.45), rough=0.05)
        if i == 2:
            chop(mk, vs, (1.6, 1.3, 0.3), (0.7, 0.5, 0.9), rough=0.03)
    mk.pebble(Vector((-1.72, -1.68, 0.02)), (0.2, 0.15, 0.13), 0.6, 9, hull=False, flat=0.2)
    # the footing the course stands on: rough, wider, going down into the moor (it shows where the ground falls away)
    vs, _ = block(mk, (3.36, 3.36, 1.0), ch=0.12, j=0.02, ease=0.05, chip=0.03)
    move(mk, vs, trs((0, 0, -1.27)))
    # the upper course: one whole slab and one that has cracked through, z 0.35 .. 0.65
    for cx, cy, w, d, rz in [(0.0, -0.55, 2.2, 1.1, 0.0), (-0.47, 0.55, 1.26, 1.1, 0.004), (0.63, 0.555, 0.94, 1.1, -0.012)]:
        vs, _ = block(mk, (w - gap, d - gap, 0.31 + r.uniform(-0.008, 0.008)), ch=0.03, j=0.006, ease=0.03, chip=0.015)
        move(mk, vs, trs((cx, cy, 0.35), rz))
    # the shaft's foot block, then the shaft: one stone, tapering, with a belt where the arms spring and a pointed cap
    vs, _ = block(mk, (1.0, 1.0, 0.25), ch=0.06, j=0.004, ease=0.03, taper=0.07)
    move(mk, vs, trs((0, 0, 0.64)))

    def w_at(z):
        return 0.8 - 0.14 * (z - 0.6) / 4.0

    # three drums with open joints; the upper two have turned a little on their beds
    drums = [([(0.86, 0.0), (0.92, 0.0), (1.62, 0.0), (1.95, 0.0), (2.84, 0.0)], 0.0, (0.0, 0.0)),
             ([(2.86, 0.0), (3.05, 0.0), (3.6, 0.0), (3.74, 0.0), (3.77, 0.09), (4.05, 0.09), (4.08, 0.0), (4.3, 0.0)], 0.035, (0.012, -0.008)),
             ([(4.32, 0.0), (4.5, 0.0), (4.54, 0.1), (4.63, 0.1), (4.67, 0.0)], -0.05, (-0.015, 0.012))]
    faces = {}
    for di, (spec, rz, off) in enumerate(drums):
        rings = [oct_ring(r, 0, 0, z, w_at(z) + grow, w_at(z) + grow, 0.05, 0.006, 0.0, None, 0.022 if z > 1.8 else 0.0) for z, grow in spec]
        if di == 2:
            rings.append(oct_ring(r, 0, 0, 5.08, 0.05, 0.05, 0.01, 0.0))
        fc, vs = mk.loft(rings, top=True, bot=True)
        faces[di] = fc
        move(mk, flat(vs), trs((off[0], off[1], 0.0), rz))
    niche = mk.panel(faces[0][(1, 6)], 0.1, 0.13)       # the offering niche: deep and dark
    niche[mk.tag] = L.TAG_DARK
    mk.panel(faces[0][(3, 6)], 0.07, 0.022)              # the lettered panels (the game writes on them)
    mk.panel(faces[1][(1, 6)], 0.07, 0.022)
    # an iron collar round the belt and four arms; every hook struck off at the root, one arm beaten down
    wb = w_at(3.9) + 0.09
    col = [oct_ring(r, 0, 0, z, wb + 0.035, wb + 0.035, 0.05, 0.0) for z in (3.85, 3.97)]
    mk.cur = "iron"
    mk.loft(col, top=True, bot=True, hull=False)
    mk.cur = "hewn"
    for i in range(4):
        a = math.pi * 0.5 * i
        d = Vector((math.sin(a), -math.cos(a), 0.0))
        arm = []
        arm += bar(mk, d * (wb * 0.5) + Vector((0, 0, 3.91)), d * 1.1 + Vector((0, 0, 3.91)), 0.07, 0.07)
        arm += bar(mk, d * (w_at(3.5) * 0.5 - 0.01) + Vector((0, 0, 3.46)), d * 0.82 + Vector((0, 0, 3.885)), 0.045, 0.045)
        stub = bar(mk, d * 1.075 + Vector((0, 0, 3.93)), d * 1.075 + Vector((0, 0, 3.74)), 0.055, 0.055)
        stub = chop(mk, stub, d * 1.075 + Vector((0, 0, 3.79)), (d.x * 0.5, d.y * 0.5, -1.0), rough=0.0)
        arm += stub
        if i == 1:
            pivot = d * (wb * 0.5) + Vector((0, 0, 3.91))
            ax = d.cross(Vector((0, 0, 1)))
            move(mk, arm, Matrix.Translation(pivot) @ Matrix.Rotation(0.2, 4, ax) @ Matrix.Translation(-pivot))
    return mk


DEEP = 0.4          # how far a ground stone goes on under the turf (the moor slopes: no stone may show its underside)


def kneel_block(kind):
    """A kneeling stone of the ring: ~0.7 wide (x), 0.5 deep, 0.5 out of the ground (the old box), pivot on the ground."""
    mk = Mk(3410 + "ABCD".index(kind), "hewn")
    r = mk.r
    if kind == "A":            # whole, its top worn to a hollow by knees
        vs, _ = block(mk, (0.7, 0.5, 0.62 + DEEP), ch=0.045, j=0.008, ease=0.035, chip=0.02)
        L.dish(mk, top_face(vs), 0.1, 0.035)
        move(mk, vs, trs((0, 0, -0.12 - DEEP), 0.0, 0.02, -0.015))
    elif kind == "B":          # broken: a corner and an edge gone, leaning
        vs, _ = block(mk, (0.7, 0.5, 0.64 + DEEP), ch=0.04, j=0.008, ease=0.03, chip=0.02)
        vs = chop(mk, vs, (0.2, -0.25, 0.42 + DEEP), (0.75, -0.55, 0.6), rough=0.045)
        vs = chop(mk, vs, (-0.35, 0.1, 0.56 + DEEP), (-0.6, 0.2, 0.9), rough=0.03)
        move(mk, vs, trs((0, 0, -0.14 - DEEP), 0.0, -0.05, 0.07))
        mk.pebble(Vector((0.37, -0.3, 0.02)), (0.13, 0.1, 0.09), 0.4, 8, hull=False, flat=0.2)
    elif kind == "C":          # split through: two halves, one fallen away from the other
        a, _ = block(mk, (0.4, 0.5, 0.6 + DEEP), ch=0.04, j=0.008, ease=0.03, chip=0.02)
        a = chop(mk, a, (0.13, 0.0, 0.3 + DEEP), (1.0, 0.12, 0.2), rough=0.04)
        move(mk, a, trs((-0.17, 0, -0.12 - DEEP), 0.03, 0.0, -0.03))
        b, _ = block(mk, (0.4, 0.5, 0.6 + DEEP), ch=0.04, j=0.008, ease=0.03, chip=0.02)
        b = chop(mk, b, (-0.1, 0.0, 0.3 + DEEP), (-1.0, -0.1, 0.25), rough=0.04)
        move(mk, b, trs((0.36, 0.02, -0.3 - DEEP), -0.12, 0.05, 0.42))
    else:                      # sunk and rounded by weather, lower than the rest
        vs, _ = block(mk, (0.74, 0.52, 0.5 + DEEP), ch=0.09, j=0.012, ease=0.07, chip=0.03, taper=0.08)
        vs = chop(mk, vs, (0.0, 0.2, 0.44 + DEEP), (0.1, 0.5, 0.9), rough=0.02)
        move(mk, vs, trs((0, 0, -0.16 - DEEP), 0.0, 0.05, 0.04))
    return mk


def fallen_cap():
    """The capstone that crowned the shrine before the Edict: a moulded square coping under a low pyramid, thrown down,
    lying on an edge and half sunk."""
    mk = Mk(3420, "hewn")
    r = mk.r
    spec = [(0.0, 0.62), (0.05, 0.7), (0.09, 0.86), (0.2, 0.88), (0.24, 0.76), (0.3, 0.74)]
    rings = [oct_ring(r, 0, 0, z, w, w, 0.05, 0.006, 0.0, None, 0.02) for z, w in spec]
    rings.append(oct_ring(r, 0, 0, 0.62, 0.16, 0.16, 0.03, 0.0))
    rings.append(oct_ring(r, 0, 0, 0.66, 0.2, 0.2, 0.04, 0.0))       # the stump of the finial
    rings.append(oct_ring(r, 0, 0, 0.71, 0.12, 0.12, 0.03, 0.0))
    _, vs = mk.loft(rings, top=True, bot=True, hull=False)
    vs = flat(vs)
    vs = chop(mk, vs, (0.3, 0.3, 0.15), (0.7, 0.6, 0.2), rough=0.05)
    move(mk, vs, trs((0.02, 0.0, 0.02), 0.5, 1.02, 0.0))
    return mk


def cold_lantern(crushed):
    """A hand lantern left on the ground, its glass gone: a square iron frame with a pyramid hood and a carrying ring.
    Pivot at the middle of its body (the builder stands it up or lays it on its side)."""
    mk = Mk(3430 + int(crushed), "iron")
    s = 0.088
    block(mk, (0.21, 0.21, 0.022), ch=0.01, j=0.0, ease=0.004, st="iron")
    move(mk, list(mk.bm.verts), trs((0, 0, -0.15)))
    top, _ = block(mk, (0.2, 0.2, 0.018), ch=0.01, j=0.0, ease=0.004, st="iron")
    move(mk, top, trs((0, 0, 0.07)))
    for sx in (-1, 1):
        for sy in (-1, 1):
            bar(mk, (sx * s, sy * s, -0.13), (sx * s, sy * s, 0.075), 0.016)
    for k in range(4):                                  # the glazing rail on each side; one door hangs open
        a = math.pi * 0.5 * k
        c, sn = math.cos(a), math.sin(a)
        p0 = Vector((c * s - sn * s, sn * s + c * s, -0.03))
        p1 = Vector((c * s + sn * s, sn * s - c * s, -0.03))
        if k == 0 and not crushed:
            p1 = p0 + Matrix.Rotation(0.9, 3, 'Z') @ (p1 - p0)
        bar(mk, p0, p1, 0.01)
    hood = L.turned(mk, [(0.165, 0.086), (0.15, 0.1), (0.045, 0.165), (0.03, 0.18)], n=4, st="iron", phase=math.pi / 4)
    ring = L.tube(mk, [Vector((math.cos(t) * 0.032, 0.0, 0.2 + math.sin(t) * 0.032)) for t in [math.tau * q / 6 for q in range(6)]], 0.006, n=4, closed=True)
    stub, _ = block(mk, (0.05, 0.05, 0.05), ch=0.012, j=0.0, ease=0.006, st="timber")     # the candle's block, burnt down
    move(mk, stub, trs((0, 0, -0.128)))
    if crushed:
        sh = Matrix.Identity(4)
        sh[0][2] = 0.42
        sh[1][2] = -0.18
        sh[2][2] = 0.8
        for v in mk.bm.verts:
            z = v.co.z + 0.15
            v.co = Vector((v.co.x + sh[0][2] * z, v.co.y + sh[1][2] * z, -0.15 + z * sh[2][2]))
        _ = hood, ring
    return mk


def ruin_shrine():
    parts = [("Obelisk", L.finish(shrine_obelisk(), "Obelisk", sharp=50.0, moss_k=1.5))]
    for kind in "ABCD":
        parts.append(("Block" + kind, L.finish(kneel_block(kind), "Block" + kind, sharp=50.0, moss_k=1.2)))
    parts.append(("Cap", L.finish(fallen_cap(), "Cap", sharp=50.0, moss_k=1.2)))
    parts.append(("LanternA", L.finish(cold_lantern(False), "LanternA", sharp=50.0)))
    parts.append(("LanternB", L.finish(cold_lantern(True), "LanternB", sharp=50.0)))
    for _, objs in parts:
        L.tone_scale(objs, "iron", (0.5, 0.56, 0.62))        # cold black iron with rust in it, not a red lantern
    return dict(path=os.path.join(PROPS, "ruin_shrine.glb"), parts=parts, budget=3200, focus=Vector((0.0, -0.4, 1.4)), show=["Obelisk"])


# --- reading stones (the south marches' steles) -----------------------------------------------------------
def stele_stone(kind):
    """A carved stone with a reading: a slab in a rough footing, a sunk lettered field with the Open Door cut over
    it. A = round-headed, B = gabled with a shoulder broken away. Front = Blender +Y (Godot -Z: the builders' reading
    side). The old boxes: footing 0.9 x 0.3 x 0.6, slab 0.62 x 1.3 x 0.2 from 0.3 up."""
    mk = Mk(3450 + "AB".index(kind), "hewn")
    r = mk.r
    vs, _ = block(mk, (0.95, 0.62, 0.55), ch=0.08, j=0.012, ease=0.05, chip=0.03, taper=0.07)
    move(mk, vs, trs((0, 0, -0.27), r.uniform(-0.06, 0.06)))
    W, D = 0.62, 0.2
    head = [(1.4, 0.6), (1.52, 0.52), (1.6, 0.38), (1.65, 0.16)] if kind == "A" else [(1.36, 0.6), (1.52, 0.34), (1.66, 0.05)]
    zs = [(0.2, W + 0.02), (0.34, W), (0.5, W - 0.01), (1.3, W - 0.04)] + head
    rings = [oct_ring(r, 0, 0, z, w, D * (0.9 if z > 1.0 else 1.0), 0.022, 0.006, r.uniform(-0.01, 0.01), None, 0.02 if z > 0.6 else 0.0) for z, w in zs]
    faces, vs = mk.loft(rings, top=True, bot=True)
    floor = mk.panel(faces[(2, 2)], 0.055, 0.016)
    fr = mk.frame(floor)
    arch = [(0.065, -0.03), (0.065, 0.06)] + [(math.cos(a) * 0.065, 0.06 + math.sin(a) * 0.065) for a in (math.pi / 4, math.pi / 2, 3 * math.pi / 4)] + [(-0.065, 0.06), (-0.065, -0.03)]
    mk.cut(floor, [[(u, v + fr["hh"] - 0.17) for u, v in arch]], 0.02, floor_tag=L.TAG_DARK)
    slab = L.island(flat(vs))
    if kind == "B":
        slab = chop(mk, slab, (0.2, 0.0, 1.4), (0.75, 0.1, 0.65), rough=0.02)
    move(mk, slab, trs((0, 0, 0), 0.0, 0.035 if kind == "A" else -0.02, 0.025 if kind == "A" else -0.05))
    return mk


def ruin_marker():
    parts = [("Stele" + k, L.finish(stele_stone(k), "Stele" + k, sharp=50.0, moss_k=1.2)) for k in "AB"]
    return dict(path=os.path.join(PROPS, "ruin_marker.glb"), parts=parts, budget=700)


# --- the Drowned Shrine (the Sorrow's Banks) ---------------------------------------------------------------
def drowned_plinth():
    """The island the shrine stands on: battered masonry out of the river bed, a paving of nine great flags. Top at
    z = 0 (the builder's plinth top), 6.6 m square."""
    mk = Mk(3460, "ashlar")
    r = mk.r
    vs, _ = block(mk, (6.78, 6.78, 3.1), ch=0.06, j=0.012, ease=0.05, taper=0.04, chip=0.02)
    move(mk, vs, trs((0, 0, -3.22)))
    for ix in range(3):
        for iy in range(3):
            h = 0.15 + r.uniform(-0.01, 0.012)
            vs, _ = block(mk, (2.22, 2.22, h), ch=0.035, j=0.008, ease=0.025, chip=0.02, st="hewn")
            move(mk, vs, trs(((ix - 1) * 2.235, (iy - 1) * 2.235, -0.15), r.uniform(-0.006, 0.006), r.uniform(-0.006, 0.006), r.uniform(-0.006, 0.006)))
            if (ix, iy) == (2, 0):
                chop(mk, vs, (2.7, -3.0, -0.05), (0.6, -0.75, 0.2), rough=0.04)
            if (ix, iy) == (0, 2):
                chop(mk, vs, (-3.1, 2.5, -0.05), (-0.8, 0.5, 0.25), rough=0.04)
    return mk


def drowned_pier(kind):
    """A pier of the shrine: a base, four drums that have turned on their beds, an impost. z 0 .. 3.6, 0.8 square (the
    old box). B has lost a corner of its head."""
    mk = Mk(3462 + "AB".index(kind), "hewn")
    r = mk.r
    vs, _ = block(mk, (1.02, 1.02, 0.34), ch=0.06, j=0.006, ease=0.03, taper=0.1, chip=0.02)
    z = 0.33
    top = []
    for i in range(4):
        h = 0.725
        vs, _ = block(mk, (0.8, 0.8, h - 0.012), ch=0.07, j=0.006, ease=0.025, chip=0.025)
        move(mk, vs, trs((r.uniform(-0.015, 0.015), r.uniform(-0.015, 0.015), z), r.uniform(-0.05, 0.05)))
        z += h
        top = vs
    cap, _ = block(mk, (1.04, 1.04, 0.36), ch=0.06, j=0.006, ease=0.035, chip=0.03)
    move(mk, cap, trs((0, 0, 3.23), r.uniform(-0.03, 0.03)))
    if kind == "B":
        chop(mk, cap, (0.3, 0.3, 3.4), (0.7, 0.6, 0.35), rough=0.05)
        chop(mk, top, (0.36, 0.3, 3.2), (0.8, 0.5, 0.4), rough=0.03)
    return mk


ARCH_A, ARCH_RISE, ARCH_D = 2.3, 1.25, 0.5          # intrados half-span, rise, ring depth; springing at z 3.56


def drowned_arch(stub):
    """The arch between two piers 5.2 m apart (centres at x +-2.6), springing from their heads at z 3.56: nine
    voussoirs, the keystone a little proud. `stub` = the broken front arch: its first three stones, the last snapped."""
    mk = Mk(3464 + int(stub), "hewn")
    r = mk.r
    rin = (ARCH_A ** 2 + ARCH_RISE ** 2) / (2 * ARCH_RISE)
    z0 = 3.56 + ARCH_RISE - rin
    half = math.asin(ARCH_A / rin)
    n = 9
    da = 2 * half / n
    last = []
    for i in range(3 if stub else n):
        a0 = -half + i * da + 0.004
        a1 = -half + (i + 1) * da - 0.004
        key = (i == n // 2)
        ri = rin - (0.03 if key else 0.0)
        ro = rin + ARCH_D + (0.07 if key else r.uniform(-0.02, 0.03))
        quad = [(math.sin(a0) * ri, z0 + math.cos(a0) * ri), (math.sin(a1) * ri, z0 + math.cos(a1) * ri),
                (math.sin(a1) * ro, z0 + math.cos(a1) * ro), (math.sin(a0) * ro, z0 + math.cos(a0) * ro)]
        t = 0.39 + (0.03 if key else r.uniform(-0.012, 0.012))
        last = L.prism(mk, quad, -t, t, j=0.008)
    if stub:
        a = -half + 2.55 * da
        chop(mk, last, (math.sin(a) * (rin + 0.25), 0.0, z0 + math.cos(a) * (rin + 0.25)), (math.cos(a), 0.25, -math.sin(a) * 0.6), rough=0.06)
    else:                                       # what is left of the wall over one haunch
        for x, z, w, h in [(-2.25, 4.42, 0.9, 0.42), (-1.5, 4.86, 0.8, 0.36), (-2.3, 4.84, 0.7, 0.4)]:
            vs = L.crate(mk, (w, 0.74, h), j=0.012)
            move(mk, vs, trs((x, r.uniform(-0.02, 0.02), z), 0.0, 0.0, r.uniform(-0.03, 0.03)))
    return mk


def drowned_altar():
    """The altar: a step, a body with the Open Door cut in a sunk panel on its front (Blender -Y = Godot +Z, toward
    the shrine's open side), a mensa with a corner gone. 2.0 x 1.0, top at z 1.35 (the old box's top)."""
    mk = Mk(3466, "hewn")
    vs, _ = block(mk, (2.36, 1.36, 0.18), ch=0.04, j=0.006, ease=0.03, chip=0.02)
    body, faces = block(mk, (1.84, 0.86, 0.98), ch=0.045, j=0.005, ease=0.03)
    move(mk, body, trs((0, 0, 0.17)))
    floor = mk.panel(faces[(1, 6)], 0.13, 0.035)
    arch = [(0.16, -0.24), (0.16, 0.04)] + [(math.cos(a) * 0.16, 0.04 + math.sin(a) * 0.16) for a in (math.pi / 6, math.pi / 3, math.pi / 2, 2 * math.pi / 3, 5 * math.pi / 6)] + [(-0.16, 0.04), (-0.16, -0.24)]
    mk.cut(floor, [arch], 0.05, floor_tag=L.TAG_DARK)
    top, _ = block(mk, (2.08, 1.08, 0.21), ch=0.035, j=0.006, ease=0.03, chip=0.02)
    move(mk, top, trs((0, 0, 1.14)))
    chop(mk, top, (0.8, -0.54, 1.3), (0.7, -0.6, 0.3), rough=0.04)
    return mk


def drowned_saint(part):
    """The saint that stood on the altar: a robed figure with its hands together, the head struck off (part "Head"
    lies apart). Pivot under its feet; ~1.2 tall, 0.7 wide, 0.5 deep (the old box). Front = Blender -Y."""
    mk = Mk(3467 + (part == "Head"), "hewn")
    r = mk.r
    if part == "Head":
        prof = [(0.03, 0.0), (0.1, 0.03), (0.14, 0.12), (0.13, 0.22), (0.07, 0.29), (0.02, 0.31)]
        _, vs = mk.loft([L.circle(rad, z, 7, 0.3, sy=1.1) for rad, z in prof], top=True, bot=True, hull=False)
        move(mk, flat(vs), trs((0, 0, 0.1), 0.4, 1.35, 0.0))
        return mk
    prof = [(0.33, 0.0), (0.34, 0.06), (0.3, 0.3), (0.25, 0.62), (0.27, 0.84), (0.33, 0.97), (0.3, 1.05), (0.16, 1.12), (0.12, 1.17)]
    rings = [[Vector((p.x * (1.0 + 0.05 * math.sin(i * 2.4 + k)), p.y, p.z)) for i, p in enumerate(L.circle(rad, z, 10, 0.0, sy=0.68))] for k, (rad, z) in enumerate(prof)]
    _, vs = mk.loft(rings, top=True, bot=True, hull=False)
    body = chop(mk, flat(vs), (0.0, 0.0, 1.14), (0.35, 0.1, 1.0), rough=0.02)
    for sx in (-1, 1):                                   # the arms, brought to the breast
        bar(mk, (sx * 0.27, -0.04, 0.96), (sx * 0.2, -0.17, 0.74), 0.11, 0.1, st="hewn", ch=0.03)
        bar(mk, (sx * 0.2, -0.17, 0.74), (sx * 0.03, -0.25, 0.86), 0.09, 0.085, st="hewn", ch=0.025)
    hands, _ = block(mk, (0.12, 0.09, 0.14), ch=0.03, j=0.004, ease=0.02)
    move(mk, hands, trs((0, -0.26, 0.82), 0.0, 0.3))
    for x in (-0.14, 0.0, 0.15):                         # the robe's folds down the front
        bar(mk, (x, -0.2 - 0.02 * abs(x) * 0, 0.02), (x * 0.8, -0.185, 0.6), 0.05, 0.035, st="hewn", ch=0.012)
    _ = body, r
    return mk


def ruin_drowned():
    parts = [("Plinth", L.finish(drowned_plinth(), "Plinth", tiles={"ashlar": 12.0}, sharp=50.0, moss_k=1.5))]
    for k in "AB":
        parts.append(("Pier" + k, L.finish(drowned_pier(k), "Pier" + k, sharp=50.0, moss_k=1.3)))
    parts.append(("Arch", L.finish(drowned_arch(False), "Arch", sharp=50.0, moss_k=1.3)))
    parts.append(("ArchStub", L.finish(drowned_arch(True), "ArchStub", sharp=50.0, moss_k=1.3)))
    parts.append(("Altar", L.finish(drowned_altar(), "Altar", sharp=50.0, moss_k=1.2)))
    parts.append(("Saint", L.finish(drowned_saint("Body"), "Saint", sharp=62.0, moss_k=1.2)))
    parts.append(("SaintHead", L.finish(drowned_saint("Head"), "SaintHead", sharp=62.0, moss_k=1.2)))
    return dict(path=os.path.join(PROPS, "ruin_drowned.glb"), parts=parts, budget=4200, show=["PierA", "PierB", "Arch", "ArchStub", "Altar", "Saint", "SaintHead"])


def shrine_small():
    """Preview only: the shrine's small parts without the obelisk, so the renders show them close."""
    d = ruin_shrine()
    return dict(path=None, parts=d["parts"], budget=9999, show=[lb for lb, _ in d["parts"][1:]])


ASSETS = {"ruin_shrine": ruin_shrine, "shrine_small": shrine_small, "ruin_marker": ruin_marker, "ruin_drowned": ruin_drowned}

if __name__ == "__main__":
    L.run(ASSETS)
