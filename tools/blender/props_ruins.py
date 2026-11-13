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


def shrine_small():
    """Preview only: the shrine's small parts without the obelisk, so the renders show them close."""
    d = ruin_shrine()
    return dict(path=None, parts=d["parts"], budget=9999, show=[lb for lb, _ in d["parts"][1:]])


ASSETS = {"ruin_shrine": ruin_shrine, "shrine_small": shrine_small}

if __name__ == "__main__":
    L.run(ASSETS)
