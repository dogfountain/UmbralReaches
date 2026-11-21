"""THE CROSSING (core/world/realm/rift/crossing.gd), redesigned (r39, 21 Nov): one legible route from the rim's forecourt to the ward landing.

  tools/blender/run.sh crossing_kit.py -- [--only gate,causeway,tower,spindle,ward] [--preview DIR]

  art/models/crossing.glb   one mesh per section and set (`<Section>__hewn|slate|stone|iron|rune|ember`) and a `<Section>-colonly` body each,
                            in the Crossing's own game coordinates (chasm on x 0, origin at the rim; the game places it at the origin)
  art/models/crossing_layout.json   what the game reads: lanes, flights, sites, fires, lamp points

The route (docs/r39/crossing_redesign.md): forecourt and its gate -> the Causeway (three bays of a two-tier stair-viaduct over the
starwater, rising 5 m) -> the Pilgrims' Gate tower T3 (the junction: the Pilgrims' Stair goes down its east side to the chapel) ->
a flight north into the Spindle Gate -> one clean helix of steps round the basalt Spindle with three rest landings -> the Gate's roof
-> a single flying arch over the lava -> the ward landing.
"""
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from crossing_spindle import *      # noqa: F401,F403

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ONLY = ARGS[ARGS.index("--only") + 1].split(",") if "--only" in ARGS else []
PREVIEW_DIR = ARGS[ARGS.index("--preview") + 1] if "--preview" in ARGS else ""

# ---------------------------------------------------------------- the plan (game frame)
FORE = (-4.5, -14.0, 4.5, -7.0)            # forecourt x0, z0, x1, z1 (y 0.6)
FORE_Y = 0.6
G0 = (0.0, -14.0)                           # the causeway's first point (the gate line)
T3 = (-1.8, -40.0)                          # the Pilgrims' Gate: centre
T3_R = 3.5
T3_TOP = 5.6
SPIN = (-8.3, -50.0)
SPIN_R = 6.5
SPIN_Y0 = 8.0
SPIN_Y1 = 21.2
LAND = (-4.0, -71.15, 4.0, -62.0)           # ward landing x0, z0, x1, z1
LAND_Y = 25.2
AX = -1.8                                   # the north-south axis of the last stretch
GATE_Z = (-52.0, -50.2)                     # the Spindle Gate block's z range (the top landing over the stair's first turn)
GATE_X = (-5.3, 1.3)
GATE_C = -2.0                               # its passage's centre x
AXB = -1.4                                  # the bridge's axis

LAYOUT = {"lanes": {}, "flights": [], "sites": [], "fires": [], "points": {}}


def new_section():
    return CP(), Col()


def emit(objs, P, C, name, smooth=()):
    o = finish(P, name, uv_tile=UV_TILE)
    objs.extend(o)
    objs.append(C.finish(name))
    for ob in o:
        print("TRIS", ob.name, sum(len(p.vertices) - 2 for p in ob.data.polygons))


# ---------------------------------------------------------------- the causeway
CAUSEWAY_PIECES = [
    [("flat", 1.8), ("steps", 6, 0.72), ("flat", 1.4)],
    [("flat", 1.4), ("steps", 6, 0.72), ("flat", 1.8)],
    [("flat", 1.8), ("steps", 7, 0.72), ("flat", 0.68)],
]


def causeway(objs):
    P, C = new_section()
    rnd = rnd_for(4101)
    d = unit(G0, T3)
    s_end = math.hypot(T3[0] - G0[0], T3[1] - G0[1]) - T3_R
    L = s_end / 3.0
    o = (G0[0], 0.0, G0[1])
    y = FORE_Y
    lamps_all = []
    ridx = []
    for k in range(3):
        ok = at(o, d, L * k, 0.0, 0.0)
        pr = Prof(y, CAUSEWAY_PIECES[k], riser=(5.0 / 19.0))
        # stretch the pieces to the bay's length: the last flat takes up what is left
        pr.pieces[-1]["u1"] += max(0.0, L - pr.length)
        pr.length = max(pr.length, L)
        under = y - 0.9
        arcade(P, C, rnd, ok, d, L, 2.0, under, BED)
        lamps = [(0.0, 1), (0.0, -1)] if k == 1 else []
        deck(P, C, rnd, ok, d, pr, under, lamps=[(pr.length, 1)] if k == 1 else [])
        y = pr.y1
        LAYOUT["flights"].append({"name": "rift_c%d" % k, "a": at(ok, d, 0.0, pr.y0, 0.0), "b": at(ok, d, L, pr.y1, 0.0), "hw": 2.5})
    LAYOUT["lanes"]["rift_crossing"] = [list(G0), list(T3)]
    emit(objs, P, C, "Causeway")



# ---------------------------------------------------------------- the Pilgrims' Gate (T3) and the flight north
def tower3(objs, Pi, Pe):
    P, C = new_section()
    rnd = rnd_for(4202)
    a_s = math.atan2(G0[1] - T3[1], G0[0] - T3[0])           # towards the causeway (south)
    a_n = -math.pi * 0.5
    a_e = math.radians(-35.0)                                  # the Pilgrims' Stair (rift/tower_stair.gd: A0)
    drum(P, C, rnd, T3, T3_R, T3_TOP, BED + 1.0, [a_s, a_n, a_e], [0.72, 0.72, 0.36])
    # the Pilgrims' arch over the stair's head: a freestanding pointed gate with a violet lantern, so the way down to the light reads
    ca = (T3[0] + math.cos(a_e) * 2.9, T3_TOP, T3[1] + math.sin(a_e) * 2.9)
    tang = (-math.sin(a_e), math.cos(a_e))
    pointed_gate(P, rnd, ca, tang, 2.0, 2.3, 1.7, 0.9)
    lay_lantern(P, Pi, ca, tang, 2.3 + 1.7 + 0.55 - 1.15)
    # the two fire posts at the north way on, and a lit one at the causeway's mouth
    fires = []
    for sgn in (-1, 1):
        pt = (T3[0] + sgn * 2.55, T3_TOP, T3[1] - 2.2)
        fires.append(lamp_with_fire(P, Pi, Pe, rnd, pt, (1.0, 0.0), h=2.0, big=True))
    LAYOUT["fires"] += [{"p": list(f), "lit": True, "big": True, "tag": "t3_north"} for f in fires]
    pt = (T3[0] + 2.7, T3_TOP, T3[1] + 1.2)
    f = lamp_with_fire(P, Pi, Pe, rnd, pt, (1.0, 0.0), h=1.9)
    LAYOUT["fires"].append({"p": list(f), "lit": False, "big": False, "tag": "t3_south"})
    LAYOUT["sites"].append({"name": "rift_tower_3", "rect": [T3[0] - T3_R, T3[1] - T3_R, T3_R * 2, T3_R * 2], "y": T3_TOP})
    emit(objs, P, C, "Tower3")


def lay_lantern(P, Pi, c, d, y_off):
    """The violet lantern hung in the Pilgrims' arch: an iron cage round a glowing core (`rune` set)."""
    p = (c[0], c[1] + y_off, c[2])
    blk(Pi, "iron", (p[0], p[1] + 0.34, p[2]), (0.34, 0.06, 0.34), d, rnd_for(1), bevel=0.01, warp=0)
    blk(Pi, "iron", (p[0], p[1] - 0.34, p[2]), (0.3, 0.06, 0.3), d, rnd_for(2), bevel=0.01, warp=0)
    for dx, dz in ((0.14, 0.14), (-0.14, 0.14), (0.14, -0.14), (-0.14, -0.14)):
        blk(Pi, "iron", (p[0] + dx, p[1], p[2] + dz), (0.04, 0.7, 0.04), d, rnd_for(3), bevel=0.0, warp=0)
    blk(Pi, "rune", p, (0.2, 0.46, 0.2), d, rnd_for(4), bevel=0.0, warp=0, tint=False)
    LAYOUT["points"]["pilgrim_lantern"] = list(p)


def flight_north(objs):
    P, C = new_section()
    rnd = rnd_for(4303)
    d = (0.0, -1.0)
    z0 = T3[1] - T3_R
    L = z0 - GATE_Z[1]
    L = abs(L)
    o = (AX, 0.0, z0)
    pr = Prof(T3_TOP, [("steps", 9, L / 9.0)], riser=2.4 / 9.0)
    under = T3_TOP - 0.9
    arcade(P, C, rnd, o, d, L, 2.0, under, BED)
    deck(P, C, rnd, o, d, pr, under)
    LAYOUT["flights"].append({"name": "rift_l4", "a": [AX, T3_TOP, z0], "b": [AX, T3_TOP + 2.4, z0 - L], "hw": 2.5})
    LAYOUT["lanes"]["rift_crossing_l4"] = [[AX, z0], [AX, z0 - L]]
    emit(objs, P, C, "FlightNorth")



# ---------------------------------------------------------------- the helix round the Spindle
def top_at(rec, th):
    best = rec[0]
    for r_ in rec:
        if r_[1] - 1e-6 <= th <= r_[0] + 1e-6:
            return r_[2]
        if abs(r_[0] - th) < abs(best[0] - th):
            best = r_
    return best[2]


def spindle(objs, Pi, Pe):
    P, C = new_section()
    rnd = rnd_for(4404)
    fires, benches = [], []
    rec, da, ry = helix(P, C, Pi, Pe, rnd, SPIN, SPIN_R, 2.2, SPIN_Y0, SPIN_Y1, 49, 25.0, fires=fires, benches=benches)
    r_out = SPIN_R + 2.2
    rp = r_out - 0.95
    skipped = []
    angs = [-50, -80, -110, -140, -170, -200, -230, -260]
    for ad in angs:
        th = math.radians(ad)
        c = polar(SPIN, rp, th, 0.0)
        if math.hypot(c[0] - T3[0], c[2] - T3[1]) < 7.6:
            skipped.append(ad)
            continue
        bottom = top_at(rec, th) - 1.5
        tang = (-math.sin(th), math.cos(th))
        support_pier(P, C, rnd, (c[0], c[2]), tang, 1.5, 1.9, BED, bottom)
    # the east buttress: carries the stair's last quarter where it hangs over the flight north
    th_e = math.radians(-325.0)
    bottom = top_at(rec, th_e) - 1.5
    support_pier(P, C, rnd, (1.8, -46.6), (0.0, -1.0), 2.0, 1.9, BED, bottom - 0.4)
    for k in range(3):                                         # corbels carrying the slab's edge
        w_ = 1.9 + 0.5 * k
        blk(P, "hewn", (1.8 - 0.9 - 0.35 * k * 0 - (0.5 * k), bottom - 0.4 + 0.25 * k + 0.12, -46.6), (w_ + 0.3, 0.3, 2.2), (0.0, -1.0), rnd, bevel=0.04)
    LAYOUT["fires"] += [{"p": list(f), "lit": True, "big": True, "tag": "spindle_landing"} for f in fires]
    LAYOUT["points"]["spindle_landings"] = [list(f) for f in fires]
    LAYOUT["points"]["spindle_skipped_piers"] = skipped
    LAYOUT["sites"].append({"name": "rift_spindle", "rect": [SPIN[0] - SPIN_R - 2.2, SPIN[1] - SPIN_R - 2.2, (SPIN_R + 2.2) * 2, (SPIN_R + 2.2) * 2], "y": SPIN_Y0})
    lane = []
    for i in range(1, 24):
        th = -math.tau * i / 24.0
        lane.append([SPIN[0] + math.cos(th) * SPIN_R, SPIN[1] + math.sin(th) * SPIN_R])
    LAYOUT["lanes"]["rift_crossing_turn"] = lane
    emit(objs, P, C, "Helix")


def support_pier(P, C, rnd, c2, d, along, across, foot, bottom):
    """A tall tapering-free pier of coursed faces with a corbelled capital, tangent `d`, centre (x, z)."""
    c = (c2[0], 0.0, c2[1])
    fc = 0.34
    for (va, vb) in rows(rnd, foot, bottom - 0.7, 0.9, 1.15):
        for sgn in (-1, 1):
            blk(P, "hewn", at(c, d, 0.0, 0.5 * (va + vb), sgn * (across * 0.5 - fc * 0.5)), (along - 0.03, vb - va - 0.03, fc), d, rnd, bevel=0.04, warp=0.01)
            blk(P, "hewn", at(c, d, sgn * (along * 0.5 - fc * 0.5), 0.5 * (va + vb), 0.0), (fc, vb - va - 0.03, across - 2 * fc - 0.03), d, rnd, bevel=0.04, warp=0.01)
    core(P, at(c, d, 0.0, 0.5 * (foot + bottom), 0.0), (along - 2 * fc + 0.02, bottom - foot, across - 2 * fc + 0.02), d)
    for k, (wa, wh) in enumerate(((0.3, 0.35), (0.55, 0.35))):
        blk(P, "hewn", at(c, d, 0.0, bottom - 0.7 + 0.35 * k + 0.18, 0.0), (along + wa * 1.4, wh, across + wa), d, rnd, bevel=0.05)
    C.box(at(c, d, 0.0, 0.5 * (foot + bottom), 0.0), (along, bottom - foot, across), d)


# ---------------------------------------------------------------- the Spindle Gate and the bridge
def gate(objs, Pi, Pe):
    P, C = new_section()
    rnd = rnd_for(4505)
    x0, x1 = GATE_X
    z0, z1 = GATE_Z                                 # z0 north (-52.0), z1 south (-50.2)
    top = SPIN_Y1
    foot = BED + 1.0
    hw, spring, rise = 2.4, 12.0, 3.4
    lap_floor = 7.4
    w_ = x1 - x0
    # the south face (d east, outward +z) and the north face (d west, outward -z), the passage through both
    for (o, d, uc) in (((x0, 0.0, z1), (1.0, 0.0), GATE_C - x0), ((x1, 0.0, z0), (-1.0, 0.0), x1 - GATE_C)):
        def ex_low(va, vb, _uc=uc):
            return [(0.0, w_)]
        def ex_pass(va, vb, _uc=uc):
            return [(0.0, _uc - hw), (_uc + hw, w_)]
        facing(P, rnd, o, d, 0.0, w_, foot, lap_floor, -0.17, excl=ex_low)
        facing(P, rnd, o, d, 0.0, w_, lap_floor, spring, -0.17, excl=ex_pass)
    # the arch rings and the fill above them (spandrel does both faces and the core), once for the passage's axis (barrel along z)
    mid = (GATE_C, spring, (z0 + z1) * 0.5)
    arch_ring(P, rnd, mid, (1.0, 0.0), hw * 2.0, rise, z1 - z0)
    spandrel(P, rnd, mid, (1.0, 0.0), w_ * 0.5, hw * 2.0, rise, top - 0.24 - spring, z1 - z0, face=0.34)
    # side piers' core and the lower mass
    core(P, ((x0 + x1) * 0.5, (foot + lap_floor) * 0.5, (z0 + z1) * 0.5), (w_ - 0.6, lap_floor - foot, (z1 - z0) - 0.6), (1.0, 0.0))
    for (xa, xb) in ((x0 + 0.3, GATE_C - hw), (GATE_C + hw, x1 - 0.3)):
        core(P, ((xa + xb) * 0.5, (lap_floor + spring) * 0.5, (z0 + z1) * 0.5), (xb - xa, spring - lap_floor, (z1 - z0) - 0.6), (1.0, 0.0))
    # west and east faces
    for (o, d) in (((x0, 0.0, z0), (0.0, 1.0)), ((x1, 0.0, z1), (0.0, -1.0))):
        facing(P, rnd, o, d, 0.0, z1 - z0, foot, top - 0.24, -0.17)
    # string course under the roof, a cornice
    for (o, d, ln) in (((x0, 0.0, z1), (1.0, 0.0), w_), ((x1, 0.0, z0), (-1.0, 0.0), w_)):
        for (a, b) in seg_runs(rnd, 0.0, ln, 1.2, 1.8):
            blk(P, "hewn", at(o, d, 0.5 * (a + b), top - 0.45, 0.1), (b - a - 0.03, 0.3, 0.5), d, rnd, bevel=0.05)
    # the roof: slate flags
    for (a, b) in seg_runs(rnd, x0, x1, 1.0, 1.5):
        blk(P, "slate", ((a + b) * 0.5, top - 0.12, (z0 + z1) * 0.5), (b - a - 0.03, 0.24, z1 - z0 - 0.03), (1.0, 0.0), rnd, bevel=0.03, warp=0.006)
    # parapets: the east and west ends, and the north and south edges outside the walk (the walk is x -4.0 .. 0.4)
    for sx in (x0 + RAIL_T * 0.5, x1 - RAIL_T * 0.5):
        blk(P, "hewn", (sx, top + RAIL_H * 0.5, (z0 + z1) * 0.5), (RAIL_T, RAIL_H, z1 - z0), (0.0, 1.0), rnd, bevel=0.04)
        blk(P, "hewn", (sx, top + RAIL_H + 0.06, (z0 + z1) * 0.5), (RAIL_T + 0.16, 0.13, z1 - z0 + 0.1), (0.0, 1.0), rnd, bevel=0.03)
        C.box((sx, top + 0.6, (z0 + z1) * 0.5), (RAIL_T, 1.2, z1 - z0), (0.0, 1.0))
    fires = []
    for fx in (x0 + 0.7, x1 - 0.5):
        fires.append(lamp_with_fire(P, Pi, Pe, rnd, (fx, top, (z0 + z1) * 0.5), (1.0, 0.0), h=1.9, big=True))
    LAYOUT["fires"] += [{"p": list(f), "lit": True, "big": True, "tag": "spindle_gate"} for f in fires]
    # collision: the lower mass, the side piers, the lintel and the roof slab
    C.box(((x0 + x1) * 0.5, (BED + lap_floor) * 0.5, (z0 + z1) * 0.5), (w_, lap_floor - BED, z1 - z0))
    for (xa, xb) in ((x0, GATE_C - hw), (GATE_C + hw, x1)):
        C.box(((xa + xb) * 0.5, (lap_floor + 17.0) * 0.5, (z0 + z1) * 0.5), (xb - xa, 17.0 - lap_floor, z1 - z0))
    C.box(((x0 + x1) * 0.5, (15.9 + top) * 0.5 - 0.25, (z0 + z1) * 0.5), (w_, top - 15.9 - 0.5, z1 - z0))
    C.box(((x0 + x1) * 0.5, top - 0.25, (z0 + z1) * 0.5), (w_, 0.5, z1 - z0))
    LAYOUT["sites"].append({"name": "rift_spindle_gate", "rect": [x0, z0, w_, z1 - z0], "y": top})
    emit(objs, P, C, "Gate")


def bridge(objs, Pi, Pe):
    P, C = new_section()
    rnd = rnd_for(4606)
    d = (0.0, -1.0)
    zs = GATE_Z[0]                                  # the block's north face
    treads = 0.714
    risers = 4.0 / 14.0
    parts = [(8, 21.2, 17.0, 3.0, "A"), (3, None, None, None, "P"), (3, None, None, None, "B")]
    y = SPIN_Y1
    u = 0.0
    # bay A: 8 steps over an arch (springing 17.0), the pier P2 (3 steps), bay B: 3 steps over a small arch (springing 20.4)
    secs = []
    for (n, kind) in ((8, "A"), (3, "P"), (3, "B")):
        secs.append((n, kind, y, u))
        y += n * risers
        u += n * treads
    for (n, kind, y0, u0) in secs:
        o = (AXB, 0.0, zs - u0)
        L = n * treads
        pr = Prof(y0, [("steps", n, treads)], riser=risers)
        under = y0 - 0.9
        if kind == "A":
            under = 20.7
            mid = (AXB, 17.0, zs - u0 - L * 0.5)
            arch_ring(P, rnd, mid, d, L, 3.0, W_DECK)
            spandrel(P, rnd, mid, d, L * 0.5, L, 3.0, under - 17.0, W_DECK, face=0.34)
        elif kind == "B":
            spring = under - 0.62 - 2.2 - 0.2
            mid = (AXB, spring, zs - u0 - L * 0.5)
            arch_ring(P, rnd, mid, d, L, 2.2, W_DECK)
            spandrel(P, rnd, mid, d, L * 0.5, L, 2.2, under - spring, W_DECK, face=0.34)
        else:
            # P2: the pier in the lava, faced both sides and ends, from the foot to under
            c = (AXB, 0.0, zs - u0 - L * 0.5)
            fc = 0.34
            for (va, vb) in rows(rnd, BED + 1.0, under, 0.8, 1.1):
                for sgn in (-1, 1):
                    blk(P, "hewn", at(c, d, 0.0, 0.5 * (va + vb), sgn * (W_DECK * 0.5 - fc * 0.5)), (L - 0.03, vb - va - 0.03, fc), d, rnd, bevel=0.04, warp=0.01)
                    blk(P, "hewn", at(c, d, sgn * (L * 0.5 - fc * 0.5), 0.5 * (va + vb), 0.0), (fc, vb - va - 0.03, W_DECK - 2 * fc - 0.03), d, rnd, bevel=0.04, warp=0.01)
            core(P, at(c, d, 0.0, 0.5 * (BED + 1.0 + under), 0.0), (L - 2 * fc + 0.02, under - BED - 1.0, W_DECK - 2 * fc + 0.02), d)
            C.box(at(c, d, 0.0, 0.5 * (BED + under), 0.0), (L, under - BED, W_DECK), d)
        deck(P, C, rnd, o, d, pr, under, lamps=[])
        LAYOUT["flights"].append({"name": "rift_b%s" % kind, "a": [AXB, y0, zs - u0], "b": [AXB, y0 + n * risers, zs - u0 - L], "hw": 2.5})
    LAYOUT["lanes"]["rift_crossing_top"] = [[AXB, zs], [AXB, LAND[3]], [0.0, LAND[1] + 1.0]]
    emit(objs, P, C, "Bridge")



# ---------------------------------------------------------------- the ward landing
def ward(objs, Pi, Pe):
    P, C = new_section()
    rnd = rnd_for(4707)
    x0, z0, x1, z1 = LAND
    y = LAND_Y
    foot = BED + 1.0
    w, l = x1 - x0, z1 - z0
    for (o, d, ln) in (((x0, 0.0, z1), (1.0, 0.0), w), ((x1, 0.0, z0), (-1.0, 0.0), w), ((x0, 0.0, z0), (0.0, 1.0), l), ((x1, 0.0, z1), (0.0, -1.0), l)):
        facing(P, rnd, o, d, 0.0, ln, foot, y - 0.55, -0.17)
        for yy in (5.0, 14.5):
            for (a, b) in seg_runs(rnd, 0.0, ln, 1.2, 1.8):
                blk(P, "hewn", at(o, d, 0.5 * (a + b), yy, 0.02), (b - a - 0.03, 0.34, 0.6), d, rnd, bevel=0.05)
        for (a, b) in seg_runs(rnd, 0.0, ln, 1.1, 1.7):
            blk(P, "hewn", at(o, d, 0.5 * (a + b), y - 0.4, 0.14), (b - a - 0.03, 0.36, 0.7), d, rnd, bevel=0.05)
    core(P, ((x0 + x1) * 0.5, (foot + y - 0.55) * 0.5, (z0 + z1) * 0.5), (w - 0.68, y - 0.55 - foot, l - 0.68), (1.0, 0.0))
    # blind pointed arches on the west and east faces, two tiers of two
    for (xf, d) in ((x0, (0.0, 1.0)), (x1, (0.0, 1.0))):
        for sp in (6.5, 16.0):
            for fz in (0.3, 0.7):
                arch_ring(P, rnd, (xf + (-0.1 if xf == x0 else 0.1), sp, z0 + l * fz), d, 3.0, 2.8, 0.5, t=0.5, layers=False)
                for sgn in (-1, 1):
                    blk(P, "hewn", at((xf + (-0.1 if xf == x0 else 0.1), 0.0, z0 + l * fz), d, sgn * 1.75, sp - 1.4, 0.0), (0.5, 2.8, 0.5), d, rnd, bevel=0.04)
    # the paved top
    for (a, b) in seg_runs(rnd, x0, x1, 1.1, 1.6):
        for (c_, e_) in seg_runs(rnd, z0, z1, 1.0, 1.5):
            blk(P, "slate", ((a + b) * 0.5, y - 0.12, (c_ + e_) * 0.5), (b - a - 0.03, 0.24, e_ - c_ - 0.03), (1.0, 0.0), rnd, bevel=0.03, warp=0.006)
    # parapets
    def rail(xa, za, xb, zb):
        dd = unit((xa, za), (xb, zb))
        ln = math.hypot(xb - xa, zb - za)
        mid = ((xa + xb) * 0.5, (za + zb) * 0.5)
        for (a, b) in seg_runs(rnd, 0.0, ln, 1.2, 1.7):
            p_ = (xa + dd[0] * 0.5 * (a + b), y + RAIL_H * 0.5, za + dd[1] * 0.5 * (a + b))
            blk(P, "hewn", p_, (b - a - 0.03, RAIL_H, RAIL_T), dd, rnd, bevel=0.04, warp=0.006)
        blk(P, "hewn", (mid[0], y + RAIL_H + 0.06, mid[1]), (ln + 0.06, 0.13, RAIL_T + 0.16), dd, rnd, bevel=0.03)
        C.box((mid[0], y + 0.6, mid[1]), (ln, 1.2, RAIL_T), dd)
        post(P, rnd, (xa, y, za), dd)
        post(P, rnd, (xb, y, zb), dd)
    t = RAIL_T * 0.5
    rail(x0 + t, z1 - 0.3, x0 + t, z0 + 0.5)
    rail(x1 - t, z1 - 0.3, x1 - t, z0 + 0.5)
    rail(x0 + 0.5, z1 - t, AXB - 2.2 - 0.25, z1 - t)
    rail(AXB + 2.2 + 0.25, z1 - t, x1 - 0.5, z1 - t)
    rail(x0 + 0.5, z0 + t, -2.95, z0 + t)
    rail(2.95, z0 + t, x1 - 0.5, z0 + t)
    # pinnacles at the north corners, the beacon at the south-east, fire posts at the north corners
    for sx in (x0 + 0.45, x1 - 0.45):
        blk(P, "hewn", (sx, y + 1.1, z0 + 0.45), (0.7, 2.2, 0.7), (1.0, 0.0), rnd, bevel=0.06)
        blk(P, "hewn", (sx, y + 2.35, z0 + 0.45), (0.9, 0.3, 0.9), (1.0, 0.0), rnd, bevel=0.05)
        blk(P, "hewn", (sx, y + 2.75, z0 + 0.45), (0.5, 0.5, 0.5), (1.0, 0.0), rnd, bevel=0.1, pitch=0.78, roll=0.78)
    fires = []
    fires.append(beacon(P, Pi, Pe, rnd, (x1 - 1.35, y, z1 - 1.5), (1.0, 0.0)))
    for sx in (x0 + 1.0, x1 - 1.0):
        fires.append(lamp_with_fire(P, Pi, Pe, rnd, (sx, y, z0 + 1.2), (1.0, 0.0), h=1.9, big=True))
    LAYOUT["fires"] += [{"p": list(f), "lit": True, "big": True, "tag": "ward"} for f in fires]
    C.box(((x0 + x1) * 0.5, (BED + y) * 0.5 - 0.25, (z0 + z1) * 0.5), (w, y - BED - 0.5, l))
    C.box(((x0 + x1) * 0.5, y - 0.25, (z0 + z1) * 0.5), (w, 0.5, l))
    LAYOUT["sites"].append({"name": "rift_ward_landing", "rect": [x0, z0 + 0.8, w, l - 0.8], "y": y})
    emit(objs, P, C, "Ward")



# ---------------------------------------------------------------- the forecourt and its gate
def forecourt(objs, Pi, Pe):
    P, C = new_section()
    rnd = rnd_for(4808)
    x0, z0, x1, z1 = FORE
    wd = x1 - x0
    d = (0.0, -1.0)
    # the platform over the starwater: one bay on a two-tier arcade from the lip (z -7) to the causeway's first pier (z -14)
    o = (0.0, 0.0, z1)
    L = z1 - z0
    under = FORE_Y - 0.9
    arcade(P, C, rnd, o, d, L, 2.0, under, BED, width=wd)
    pr = Prof(FORE_Y, [("flat", L)])
    deck(P, C, rnd, o, d, pr, under, width=wd, rail=(True, True), posts=True)
    # the landing carried on towards the rim, and the three steps down to the rim path
    o2 = (0.0, 0.0, z1 + 2.4)
    deck(P, C, rnd, (0.0, 0.0, z1 + 0.0), (0.0, 1.0), Prof(FORE_Y, [("flat", 2.4)]), -1.6, width=wd, rail=(True, True))
    deck(P, C, rnd, (0.0, 0.0, z1 + 2.4), (0.0, 1.0), Prof(FORE_Y - 0.7, [("steps", 3, 0.6)], riser=0.7 / 3.0), -1.4, width=6.0, rail=(True, True))
    # the gate over the first flight: a pointed arch between two jamb piers, a lamp post at each
    top = pointed_gate(P, rnd, (0.0, FORE_Y, z0 + 0.7), (1.0, 0.0), 4.4, 3.3, 3.3, 1.2, pier=1.1)
    # the stretches of north wall either side of the gate
    for sgn in (-1, 1):
        xa, xb = sgn * (2.2 + 1.1), sgn * (x1 - 0.23)
        pm = ((xa + xb) * 0.5, FORE_Y + RAIL_H * 0.5, z0 + 0.23)
        blk(P, "hewn", pm, (abs(xb - xa), RAIL_H, RAIL_T), (1.0, 0.0), rnd, bevel=0.04)
        blk(P, "hewn", (pm[0], FORE_Y + RAIL_H + 0.06, pm[2]), (abs(xb - xa) + 0.06, 0.13, RAIL_T + 0.16), (1.0, 0.0), rnd, bevel=0.03)
        C.box((pm[0], FORE_Y + 0.6, pm[2]), (abs(xb - xa), 1.2, RAIL_T), (1.0, 0.0))
    # the newels at the apron's corners
    for sx in (x0 + 0.45, x1 - 0.45):
        blk(P, "hewn", (sx, FORE_Y + 0.95, z1 + 2.0), (0.7, 1.9, 0.7), (1.0, 0.0), rnd, bevel=0.06)
        blk(P, "hewn", (sx, FORE_Y + 2.05, z1 + 2.0), (0.9, 0.3, 0.9), (1.0, 0.0), rnd, bevel=0.05)
        blk(P, "hewn", (sx, FORE_Y + 2.45, z1 + 2.0), (0.5, 0.5, 0.5), (1.0, 0.0), rnd, bevel=0.1, pitch=0.78, roll=0.78)
    fires = []
    for k, sx in enumerate((-3.6, 3.6)):
        fires.append(lamp_with_fire(P, Pi, Pe, rnd, (sx, FORE_Y, z0 + 1.8), (1.0, 0.0), h=1.9, big=True))
    LAYOUT["fires"] += [{"p": list(f), "lit": i == 0, "big": True, "tag": "forecourt"} for i, f in enumerate(fires)]
    LAYOUT["sites"].append({"name": "rift_forecourt", "rect": [x0 - 0.4, z0 - 0.4, wd + 0.8, (z1 - z0) + 2.4 + 1.8 + 0.8], "y": FORE_Y, "hard": True})
    LAYOUT["flights"].append({"name": "rift_crossing_approach", "a": [0.0, FORE_Y - 0.7, z1 + 4.2], "b": [0.0, FORE_Y, z1 + 2.4], "hw": 3.2})
    LAYOUT["lanes"]["rift_crossing"] = [[0.0, z1], [0.0, z0], list(T3)]
    emit(objs, P, C, "Forecourt")


# ---------------------------------------------------------------- build
def build():
    reset()
    objs = []
    todo = ONLY or ["forecourt", "causeway", "tower3", "north", "spindle", "gate", "bridge", "ward"]
    Pi, Pe = CP(), CP()
    if "forecourt" in todo:
        forecourt(objs, Pi, Pe)
    if "causeway" in todo:
        causeway(objs)
    if "tower3" in todo:
        tower3(objs, Pi, Pe)
    if "north" in todo:
        flight_north(objs)
    if "spindle" in todo:
        spindle(objs, Pi, Pe)
    if "gate" in todo:
        gate(objs, Pi, Pe)
    if "bridge" in todo:
        bridge(objs, Pi, Pe)
    if "ward" in todo:
        ward(objs, Pi, Pe)
    if Pi.bm or Pe.bm:
        o = finish(Pi, "Fires", uv_tile=UV_TILE) + finish(Pe, "Fires", uv_tile=UV_TILE)
        objs.extend(o)
    out = os.path.join(MODELS, "crossing_test.glb") if ONLY else os.path.join(MODELS, "crossing.glb")
    if not PREVIEW_DIR or "--export" in ARGS:
        export(objs, out, "crossing")
        if not ONLY:
            with open(os.path.join(MODELS, "crossing_layout.json"), "w") as f:
                json.dump(LAYOUT, f, indent=1)
    if PREVIEW_DIR:
        W.PREVIEW = PREVIEW_DIR
        os.makedirs(PREVIEW_DIR, exist_ok=True)
        views = []
        for i, a_ in enumerate(ARGS):
            if a_ == "--cam":
                v = [float(x) for x in ARGS[i + 1].split(",")]
                views.append(((v[0], v[1], v[2]), (v[3], v[4], v[5]), v[6]))
        if not views:
            views = [((22, 2, -24), (0, -4, -26), 38)]
        preview(objs, "causeway", [(bl(a), bl(b), l) for (a, b, l) in views], size=(1280, 720))


build()
