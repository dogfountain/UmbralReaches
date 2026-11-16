"""Far Reaches, West Reach landmark assets (tools/blender/run.sh reach_west.py -- [--only keep,shrine,caps,barrow,stilt,mile,herons,bridge] [--preview DIR]).

  the Greyfell     reach_w_keep.glb    the Order's Broken Keep: curtain wall with towers, a gatehouse, a tall broken donjon with a
                                       spiral stair inside it, a ruined hall, a wall stair (+ a far silhouette node)
                   reach_w_shrine.glb  the fell shrine under the Crowns
  the Lanternwood  reach_w_caps.glb    the ring of giant glowing caps (three giants, a spread of small ones)
                   reach_w_mile.glb    the Last Milestone and the toll-house ruin
  the Barrows      reach_w_barrow.glb  the King's Barrow: a mound with kerbstones and an open passage chamber; small barrows
  the Reedmere     reach_w_stilt.glb   Reedholm's stilt houses, jetties, racks, boats; reach_w_herons.glb the heron stones;
                   reach_w_bridge.glb  the reed-ford footbridge

House style as r37_west.py: one mesh per set, named <part>__<set>, metric UVs, baked vertex tone, a -colonly collision mesh.
Authored in Blender coordinates (z up; Blender +y is Godot -z: a keep's gate faces -y in Blender = +z in the game, towards the track).
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from reach_west_lib import *     # noqa: F401,F403
import reach_west_lib as L

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ONLY = args[args.index("--only") + 1].split(",") if "--only" in args else []


def col_collision(Pc, name):
    """Finish the collision parts into one -colonly mesh (no materials)."""
    objs = finish(Pc, name + "Col")
    col = make_collision(objs, name, 1.0)
    for o in objs:
        bpy.data.objects.remove(o)
    return col


# ============================================================================================
# THE BROKEN KEEP
# ============================================================================================
WALL_H = 8.0
WALL_T = 2.2
DJ = (0.0, 14.5, 13.0)               # donjon centre x, y; outer size
DJ_T = 2.2
DJ_H = 30.0


def keep_solid_top(seed, h, amp, scale=0.3):
    top = L.ragged_top(seed, h, amp, scale)
    return lambda u, v: v <= top(u)


def build_curtain(P, Pc, rnd):
    # (a, b, seed, top amplitude) -- south wall halves leave the gatehouse (x -6.5..6.5) between them
    runs = [
        ((-17.0, -14.0), (-6.5, -15.0), 11, 0.6, (-3.15, 0.3)),          # S west
        ((6.5, -15.0), (17.0, -14.0), 12, 0.4, (0.3, -2.6)),             # S east
        ((17.0, -14.0), (20.0, 8.0), 13, 1.0, (-2.6, -3.45)),            # E (stair side)
        ((20.0, 8.0), (6.5, 13.5), 14, 4.5, (-3.45, 0.0)),               # NE, down to the donjon (breached)
        ((-20.0, 8.0), (-6.5, 13.5), 15, 3.0, (-3.15, 0.0)),             # NW
        ((-17.0, -14.0), (-20.0, 8.0), 16, 2.2, (-3.15, -3.15)),         # W
    ]
    # (ends: metres each run reaches past its corner points; negative stops it inside a tower's wall)
    for (a, b, seed, amp, ends) in runs:
        top = L.ragged_top(seed, WALL_H, amp, 0.13)
        Ln = (Vector(b) - Vector(a)).length
        breach = None
        if seed == 14:
            breach = (Ln * 0.45, 3.4)
        elif seed == 16:
            breach = (Ln * 0.62, 2.0)

        def solid(u, v, top=top, breach=breach, Ln=Ln):
            if v > top(u):
                return False
            if breach and abs(u - breach[0]) < breach[1] * (0.5 + 0.5 * (1.0 - v / WALL_H)):
                return v < 1.2 + 1.8 * abs(math.sin(u * 2.1))
            return True
        L.wall_run(P, Pc, "ashlar", a, b, -2.5, WALL_H + 2.5, WALL_T, lambda u, v, s=solid: s(u, v - 2.5) if v >= 2.5 else True, rnd, ch=0.52,
                   ext=lambda j: (0.8, 0.8) if j % 2 else (0.0, 0.0), ends=ends)
        # merlons along the intact stretches of the outer side
        a3, b3 = Vector(a), Vector(b)
        d = (b3 - a3).normalized()
        n = Vector((-d.y, d.x))
        L.crenels(P, Pc, "ashlar", a3 + n * 0, b3 + n * 0, WALL_H, rnd, off=-WALL_T * 0.5 + 0.38 if False else WALL_T * 0.5 - 0.4,
                  broken=lambda u, top=top, Ln=Ln, ends=ends: top(u) < WALL_H - 0.05 or (breach is not None and abs(u - breach[0]) < breach[1] + 1.0)
                  or u < -ends[0] or u + 1.0 > Ln + ends[1])


def build_gatehouse(P, Pc, rnd):
    # passage along y; the south (outer) face at y = -17.5, north at y = -12.5; the arch 3.6 wide, springing at 3.2, crown at 5.0
    x0, x1, y0, y1 = -6.5, 6.5, -17.5, -12.5
    # front and back faces: laid as two walls along x with the gate cut in them
    gw, spring = 3.8, 3.4

    def solid_face(topfn):
        def f(u, v):
            vv = v - 2.5 if v >= 2.5 else 99.0
            if v < 2.5:
                return True
            if L.arch_hole(u, v - 2.5, 6.5, gw, 0.0, spring):
                return False
            return v - 2.5 <= topfn(u)
        return f
    topf = L.ragged_top(21, 14.5, 3.0, 0.2)
    topb = L.ragged_top(22, 14.5, 4.5, 0.2)
    sf = solid_face(topf)
    sb = solid_face(topb)

    # windows above the gate: a pair of arrow slits and a murder-hole slot; arch ring voussoirs
    def with_slots(f):
        def g(u, v):
            if not f(u, v):
                return False
            if L.rect_hole(u, v, 2.0, 0.34, 8.6, 10.4) or L.rect_hole(u, v, 11.0, 0.34, 8.6, 10.4):
                return False
            if L.rect_hole(u, v, 6.5, 0.4, 7.9, 9.2):
                return False
            return True
        return g
    L.wall_run(P, Pc, "ashlar", (x0, y0 + 0.8), (x1, y0 + 0.8), -2.5, 17.0, 1.6, with_slots(sf), rnd, ch=0.52, ext=lambda j: (0.9, 0.9) if j % 2 else (0.0, 0.0), ends=(0.0, 0.0),
               dress_ends=True)
    L.wall_run(P, Pc, "ashlar", (x0, y1 - 0.8), (x1, y1 - 0.8), -2.5, 17.0, 1.6, with_slots(sb), rnd, ch=0.52, ext=lambda j: (0.9, 0.9) if j % 2 else (0.0, 0.0), ends=(0.0, 0.0),
               dress_ends=True)
    # the two flanks: solid walls with the passage between them (the passage stays open)
    for sx, sgn in ((x0, -1), (x1, 1)):
        for (xa, xb) in ((x0, x0 + 4.4), (x1 - 4.4, x1)):
            pass
    L.wall_run(P, Pc, "ashlar", (x0 + 2.3, y0 + 1.6), (x0 + 2.3, y1 - 1.6), -2.5, 16.0, 4.6, lambda u, v: v <= 2.5 + 11.5 * 1.0 - 3.0 * (0.5 + 0.5 * math.sin(u * 1.7)) , rnd, ch=0.52, blk=(0.9, 1.6))
    L.wall_run(P, Pc, "ashlar", (x1 - 2.3, y0 + 1.6), (x1 - 2.3, y1 - 1.6), -2.5, 16.0, 4.6, lambda u, v: v <= 2.5 + 8.0 + 3.0 * (0.5 + 0.5 * math.sin(u * 1.1 + 2)), rnd, ch=0.52, blk=(0.9, 1.6))
    # the vault over the passage: a stone slab at 5.4..6.4 and a timber ceiling stub; voussoir rings on both faces
    L.dbox(P, "ashlar", (0.0, (y0 + y1) * 0.5, 6.6), (3.6, 5.0, 1.2))
    box(Pc, "stone", (0.0, (y0 + y1) * 0.5, 6.6), (3.6, 5.0, 1.2))
    for yy in (y0 + 0.8 - 0.0, y1 - 0.8):
        L.voussoirs(P, "ashlar", (0.0, yy, 0.0), 0.0, gw, spring, 1.9, ring=0.55, n=15, Pc=None)
    # portcullis drawn up into the arch: iron bars, teeth showing; the doors hang open
    for i in range(9):
        x = -1.5 + i * 0.375
        cyl(P, "iron", (x, -16.0, 2.2), (x, -16.0, 6.3), 0.045, seg=6)
    for k in range(5):
        beam(P, "iron", (-1.6, -16.0, 2.4 + k * 0.85), (1.6, -16.0, 2.4 + k * 0.85), 0.07, 0.07)
    for i in range(9):
        x = -1.5 + i * 0.375
        P.of("iron")
        box(P, "iron", (x, -16.0, 2.1), (0.05, 0.05, 0.4), pitch=0.0)
    for sgn in (-1, 1):
        box(P, "timber", (sgn * 1.85, -17.2 - sgn * 0.0, 1.9), (0.22, 0.12, 3.6), yaw=0.0)
        L.box(P, "timber", (sgn * 2.6, -18.7, 1.8), (2.2, 0.22, 3.5), yaw=sgn * 1.15)
        for k in range(4):
            box(P, "iron", (sgn * 2.6 + math.cos(sgn * 1.15) * 0.0, -18.7, 0.7 + k * 0.9), (2.2, 0.26, 0.09), yaw=sgn * 1.15)
    # a second storey: the guard room, narrower, taller, ragged
    topg = L.ragged_top(31, 6.5, 5.0, 0.25)
    L.wall_run(P, Pc, "ashlar", (-4.8, y0 + 1.0), (4.8, y0 + 1.0), 11.5, 6.5, 1.4, lambda u, v: v <= topg(u) and not L.rect_hole(u, v, 4.8, 0.9, 2.0, 4.4), rnd, ch=0.52)
    L.wall_run(P, Pc, "ashlar", (-4.8, y1 - 1.0), (4.8, y1 - 1.0), 11.5, 6.5, 1.4, lambda u, v: v <= topg(u + 7) and not L.rect_hole(u, v, 3.0, 0.9, 2.0, 4.4), rnd, ch=0.52)
    L.wall_run(P, Pc, "ashlar", (-4.9, y0 + 1.7), (-4.9, y1 - 1.7), 11.5, 6.5, 1.4, lambda u, v: v <= 5.0 - 3 * abs(math.sin(u * 2)), rnd, ch=0.52,
               ends=(0.68, 0.68))
    # timber floor of the guard room, half fallen, joists out of the walls
    for k in range(7):
        beam(P, "timber", (-6.0, -17.0 + k * 0.7, 11.2), (6.0, -17.0 + k * 0.7, 11.2), 0.3, 0.34)
    for k in range(6):
        box(P, "timber", (-3.0 + k * 1.0, -15.0, 11.55), (0.9, 4.3, 0.12), yaw=0.0)
    box(Pc, "stone", (-1.5, -15.0, 11.35), (9.0, 4.4, 0.45))


def build_tower_round(P, Pc, rnd, c, r, h, seed, topamp, floor_z=None, slots=2):
    top = L.ragged_top(seed, h, topamp, 0.3)

    def solid(th, v):
        u = th * r
        if v > top(u):
            return False
        for k in range(slots):
            ang = 1.0 + k * 2.6 + seed
            if abs(((th - ang + math.pi) % math.tau) - math.pi) < 0.07 and 3.5 + k * 2.4 <= v <= 5.6 + k * 2.4:
                return False
        return True
    L.ring_wall(P, Pc, "ashlar", c, r, -2.5, h + 2.5, 1.5, lambda th, v: solid(th, v - 2.5) if v >= 2.5 else True, rnd, ch=0.52)
    # a corbelled string course and the floor timbers
    L.ring_wall(P, Pc, "ashlar", c, r + 0.12, 5.2, 0.35, 1.7, lambda th, v: top(th * r) > 5.4, rnd, ch=0.35, col=False)
    # inner floor of timber (broken)
    for k in range(9):
        a0 = k * math.tau / 9 + seed
        x = c[0] + math.cos(a0) * (r - 1.0) * 0.5
        y = c[1] + math.sin(a0) * (r - 1.0) * 0.5
        if rnd.random() < 0.72 and floor_z is not None:
            beam(P, "timber", (c[0] + math.cos(a0) * (r - 0.7), c[1] + math.sin(a0) * (r - 0.7), floor_z),
                 (c[0] - math.cos(a0) * (r - 0.7), c[1] - math.sin(a0) * (r - 0.7), floor_z), 0.28, 0.32)
    if floor_z is not None:
        box(Pc, "stone", (c[0], c[1], floor_z - 0.1), (r * 1.6, r * 1.6, 0.4))


def build_tower_square(P, Pc, rnd, c, w, h, seed):
    hw = w * 0.5
    top = L.ragged_top(seed, h, 1.0, 0.3)
    t = 1.4
    for k, ((xa, ya), (xb, yb)) in enumerate([((c[0] - hw, c[1] - hw), (c[0] + hw, c[1] - hw)), ((c[0] + hw, c[1] - hw), (c[0] + hw, c[1] + hw)),
                                              ((c[0] + hw, c[1] + hw), (c[0] - hw, c[1] + hw)), ((c[0] - hw, c[1] + hw), (c[0] - hw, c[1] - hw))]):
        def solid(u, v, k=k):
            vv = v - 2.5
            if v < 2.5:
                return True
            if vv > top(u + k * 5):
                return False
            if L.rect_hole(u, vv, w * 0.5, 0.36, 3.6, 5.4) or L.rect_hole(u, vv, w * 0.5, 0.36, 8.4, 10.2):
                return False
            if k == 0 and L.arch_hole(u, vv, w * 0.3, 1.3, 0.0, 1.7):
                return False
            return True
        L.wall_run(P, Pc, "ashlar", (xa, ya), (xb, yb), -2.5, h + 2.5, t, solid, rnd, ch=0.52, ext=lambda j: (t * 0.5, t * 0.5) if j % 2 else (-t * 0.5, -t * 0.5),
                   ends=(t * 0.49, t * 0.49))
        # merlons
        L.crenels(P, Pc, "ashlar", (xa, ya), (xb, yb), h, rnd, w=1.0, gap=0.8, off=0.0, thick=t - 0.5)
    # timber hoarding stubs at the top and a banner pole
    beam(P, "timber", (c[0] - hw, c[1] - hw - 0.4, h + 0.2), (c[0] + hw, c[1] - hw - 0.4, h + 0.2), 0.28)
    cyl(P, "timber", (c[0], c[1], h), (c[0], c[1], h + 5.0), 0.1, seg=6)
    box(P, "cloth", (c[0] + 0.9, c[1], h + 4.0), (1.7, 0.04, 1.4), pitch=0.0, yaw=0.0)


def build_donjon(P, Pc, rnd):
    cx, cy, w = DJ
    hw = w * 0.5
    t = DJ_T
    faces = [("S", (cx - hw, cy - hw), (cx + hw, cy - hw)), ("E", (cx + hw, cy - hw), (cx + hw, cy + hw)),
             ("N", (cx + hw, cy + hw), (cx - hw, cy + hw)), ("W", (cx - hw, cy + hw), (cx - hw, cy - hw))]
    amps = {"S": 4.0, "E": 10.0, "N": 3.0, "W": 7.0}
    for k, (nm, a, b) in enumerate(faces):
        top = L.ragged_top(40 + k, DJ_H, amps[nm], 0.15)
        wallside = nm

        def solid(u, v, nm=nm, top=top, k=k):
            if v < 2.5:
                return True
            vv = v - 2.5
            if vv > top(u + k * 3.0):
                return False
            # the door on the south face (arched, 2.4 wide, 3.6 high), arrow slits and larger windows on every face
            if nm == "S" and L.arch_hole(u, vv, w * 0.5, 2.5, 0.0, 2.4):
                return False
            for (lv, hv, uc, ww) in ((3.5, 5.2, 0.28, 0.34), (3.5, 5.2, 0.72, 0.34), (10.0, 12.6, 0.5, 1.1), (16.5, 19.2, 0.3, 1.1), (16.5, 19.2, 0.72, 1.1),
                                     (22.0, 24.8, 0.5, 1.2)):
                if nm == "N" and lv == 3.5:
                    continue
                if L.arch_hole(u, vv, w * uc + (k * 0.9 - 1.3), ww, lv, hv - 0.55):
                    return False
            if nm == "E" and 3.0 < u < 9.0 and 8.5 < vv < 21.0:                       # the great breach, its edge a stair of stones
                e = 3.0 + 3.0 * math.sin(vv * 0.9) * 0.2
                if abs(u - 6.0) < 2.5 + 0.18 * (vv - 8.5) * (1.0 - (vv - 8.5) / 12.5) * 1.6 + e * 0.1:
                    return False
            return True
        ext = (lambda j: (t, t) if j % 2 else (0.0, 0.0)) if nm in ("S", "N") else (lambda j: (-t, -t) if j % 2 == 0 else (0.0, 0.0))
        # S/N run the whole outer width on odd courses, E/W on even ones (the corners are bonded)
        L.wall_run(P, Pc, "ashlar", a, b, -2.5, DJ_H + 2.5, t, solid, rnd, ch=0.55,
                   ext=(lambda j: (0.0, 0.0) if j % 2 else (-t, -t)) if nm in ("S", "N") else (lambda j: (-t, -t) if j % 2 else (0.0, 0.0)), blk=(0.9, 1.9),
                   ends=(t * 0.49, t * 0.49))
        if nm == "S":
            L.voussoirs(P, "ashlar", (cx, cy - hw + 0.0, 0.0), 0.0, 2.5, 2.4, t + 0.2, ring=0.5, n=13)
    # corner turrets: round, taller and more broken than the walls between them
    for (tx, ty, th_, seed, amp) in ((cx + hw, cy + hw, 31.5, 71, 8.0), (cx - hw, cy - hw, 27.0, 72, 6.0), (cx + hw, cy - hw, 29.0, 73, 9.0), (cx - hw, cy + hw, 22.0, 74, 7.0)):
        topt = L.ragged_top(seed, th_, amp, 0.2)
        L.ring_wall(P, Pc, "ashlar", (tx, ty), 1.9, -2.5, th_ + 2.5, 1.2, lambda th, v, topt=topt: (v - 2.5 <= topt(th * 1.9)) if v >= 2.5 else True, rnd, ch=0.55, blk=(0.8, 1.2),
                    faces=(1,))
        # a stepped plinth under the turret and the walls: the batter
    for (nm, a, b) in faces:
        a3, b3 = Vector(a), Vector(b)
        d = (b3 - a3).normalized()
        n = Vector((d.y, -d.x))
        m = (a3 + b3) * 0.5 + n * (t * 0.5 + 0.28)
        yaw = math.atan2(d.y, d.x)
        for (span, dep, zc, hh, k_len) in ((w + t + 1.0, 0.7, 0.7, 1.6, 1.4), (w + t + 0.6, 0.45, 1.55, 0.3, 1.0)):
            k_n = max(1, int(span / k_len))
            for k in range(k_n):
                o = -span * 0.5 + span * (k + 0.5) / k_n
                if nm == "S" and abs(o) < 1.3 + span / k_n * 0.5:
                    continue                                   # the way in: no plinth across the door
                L.dbox(P, "stone", (m.x + d.x * o, m.y + d.y * o, zc), (span / k_n - 0.03, dep, hh), yaw=yaw, bevel=0.07)
    # string courses on the faces
    for zc in (7.0, 14.5, 21.5):
        for (nm, a, b) in faces:
            a3, b3 = Vector(a), Vector(b)
            d = (b3 - a3).normalized()
            n = Vector((d.y, -d.x))                    # outward for a clockwise loop
            m = (a3 + b3) * 0.5 + n * (t * 0.5 + 0.04)
            yaw = math.atan2(d.y, d.x)
            if rnd.random() < 0.85:                    # the course in stones of a metre or so, a few lost
                span = w + t * 0.4
                k_n = int(span / 1.1)
                for k in range(k_n):
                    if rnd.random() < 0.08:
                        continue
                    o = -span * 0.5 + span * (k + 0.5) / k_n
                    L.dbox(P, "ashlar", (m.x + d.x * o, m.y + d.y * o, zc), (span / k_n - 0.03, 0.42, 0.36), yaw=yaw, bevel=0.06)
    # the spiral stair inside: loops of cantilevered steps round the inner walls
    ix0, ix1 = cx - hw + t, cx + hw - t
    iy0, iy1 = cy - hw + t, cy + hw - t
    sw = 1.6
    rise = 0.25
    z = 0.0
    corner = 1.7
    steps_f = []
    for loop in range(2):
        # F: west wall going north
        L.stair_flight(P, Pc, "ashlar", (ix0 + sw * 0.5, iy0), (ix0 + sw * 0.5, iy1 - corner), sw, rise, z, 15, thick=0.55)
        z += 15 * rise
        L.dbox(P, "ashlar", (ix0 + corner * 0.5, iy1 - corner * 0.5, z - 0.3), (corner, corner, 0.55)); box(Pc, "stone", (ix0 + corner * 0.5, iy1 - corner * 0.5, z - 0.3), (corner, corner, 0.55))
        if loop == 1:
            break
        L.stair_flight(P, Pc, "ashlar", (ix0 + corner, iy1 - sw * 0.5), (ix1 - corner, iy1 - sw * 0.5), sw, rise, z, 12, thick=0.55)
        z += 12 * rise
        L.dbox(P, "ashlar", (ix1 - corner * 0.5, iy1 - corner * 0.5, z - 0.3), (corner, corner, 0.55)); box(Pc, "stone", (ix1 - corner * 0.5, iy1 - corner * 0.5, z - 0.3), (corner, corner, 0.55))
        L.stair_flight(P, Pc, "ashlar", (ix1 - sw * 0.5, iy1 - corner), (ix1 - sw * 0.5, iy0 + corner), sw, rise, z, 12, thick=0.55)
        z += 12 * rise
        L.dbox(P, "ashlar", (ix1 - corner * 0.5, iy0 + corner * 0.5, z - 0.3), (corner, corner, 0.55)); box(Pc, "stone", (ix1 - corner * 0.5, iy0 + corner * 0.5, z - 0.3), (corner, corner, 0.55))
        L.stair_flight(P, Pc, "ashlar", (ix1 - corner, iy0 + sw * 0.5), (ix0 + corner, iy0 + sw * 0.5), sw, rise, z, 12, thick=0.55)
        z += 12 * rise
        L.dbox(P, "ashlar", (ix0 + corner * 0.5, iy0 + corner * 0.5, z - 0.3), (corner, corner, 0.55)); box(Pc, "stone", (ix0 + corner * 0.5, iy0 + corner * 0.5, z - 0.3), (corner, corner, 0.55))
        # F5 starts over the first flight (the next loop)
    # the landing the chest stands on is the NW corner at z (loop 1's end); a broken run continues from it
    landing = Vector((ix0 + corner * 0.5, iy1 - corner * 0.5, z))
    print("DONJON landing z=%.2f at %s" % (z, landing))
    # the broken start of the third loop, steps ending in air
    L.stair_flight(P, Pc, "ashlar", (ix0 + corner, iy1 - sw * 0.5), (ix0 + corner + 2.2, iy1 - sw * 0.5), sw, rise, z, 4, thick=0.55)
    # timber joists out of the walls and a half floor in the NE corner at 8.0 m and 17 m
    for zc, ox in ((8.0, 0.0), (17.5, 0.0)):
        for k in range(8):
            y = iy0 + 0.5 + k * 1.05
            if rnd.random() < 0.8:
                beam(P, "timber", (ix0 - 0.3, y, zc), (ix0 + rnd.uniform(1.2, 2.6), y, zc), 0.3, 0.36)
            if rnd.random() < 0.8:
                beam(P, "timber", (ix1 + 0.3, y, zc + 0.05), (ix1 - rnd.uniform(1.0, 2.2), y, zc + 0.05), 0.3, 0.36)
    # a chain hanging from a beam and the chimney breast on the north wall's inside
    # banners hung on the south face
    for k, x in enumerate((-3.2, 3.2)):
        yb = cy - hw - t * 0.5 - 0.35
        box(P, "cloth", (cx + x, yb, 13.5), (1.5, 0.05, 6.0 - k * 1.5), pitch=0.04)
        beam(P, "timber", (cx + x - 1.0, yb - 0.05, 16.6), (cx + x + 1.0, yb - 0.05, 16.6), 0.14)
    # iron brackets with rings for the tether on the top-most standing corner (placed by code; a visible bracket here)
    return landing


def build_hall(P, Pc, rnd):
    """The ruined great hall on the bailey's west side."""
    x0, x1, y0, y1 = -15.5, -7.0, -8.0, 1.5
    t = 0.95
    topS = L.ragged_top(51, 3.0, 2.2, 0.25)
    topN = L.ragged_top(52, 7.2, 4.0, 0.25)
    topW = L.ragged_top(53, 5.5, 3.2, 0.25)
    topE = L.ragged_top(54, 3.4, 2.4, 0.25)

    def mk(top, door=None, win=None):
        def f(u, v):
            if v < 1.5:
                return not (door and L.arch_hole(u, v, door[0], door[1], 0.0, door[2])) or v < 0.0
            if v > top(u):
                return False
            if win and L.arch_hole(u, v, win[0], win[1], 2.0, 3.3):
                return False
            return True
        return f
    L.wall_run(P, Pc, "ashlar", (x0, y0), (x1, y0), -0.5, 6.0, t, mk(topS, (4.2, 1.6, 2.0)), rnd, ch=0.45, ext=lambda j: (t, t) if j % 2 else (0, 0), ends=(t * 0.49, t * 0.49))
    L.wall_run(P, Pc, "ashlar", (x1, y0), (x1, y1), -0.5, 6.0, t, mk(topE), rnd, ch=0.45, ext=lambda j: (0, 0) if j % 2 else (-t, -t), ends=(t * 0.49, t * 0.49))
    L.wall_run(P, Pc, "ashlar", (x1, y1), (x0, y1), -0.5, 8.5, t, mk(topN, None, (4.2, 1.1)), rnd, ch=0.45, ext=lambda j: (t, t) if j % 2 else (0, 0), ends=(t * 0.49, t * 0.49))
    L.wall_run(P, Pc, "ashlar", (x0, y1), (x0, y0), -0.5, 7.0, t, mk(topW, None, (4.7, 1.1)), rnd, ch=0.45, ext=lambda j: (0, 0) if j % 2 else (-t, -t), ends=(t * 0.49, t * 0.49))
    # a hearth block on the north wall, rafters of the fallen roof, trestles
    L.dbox(P, "ashlar", (-11.2, y1 - 1.4, 0.9), (2.4, 1.4, 1.8))
    box(Pc, "stone", (-11.2, y1 - 1.4, 0.9), (2.4, 1.4, 1.8))
    for k in range(5):
        a = (x0 + 1.0 + k * 1.9, y0 + 0.6, 4.4)
        b = (x0 + 1.0 + k * 1.9 + rnd.uniform(-0.6, 0.6), (y0 + y1) * 0.5 + rnd.uniform(0, 1.5), 5.7 - rnd.uniform(0, 2.4))
        beam(P, "timber", a, b, 0.24, 0.3)
    for k in range(3):
        c = (rnd.uniform(x0 + 2, x1 - 2), rnd.uniform(y0 + 2, y1 - 2), 0.18)
        beam(P, "timber", (c[0] - 2.0, c[1], c[2]), (c[0] + 2.0, c[1] + 0.6, c[2] + 0.1), 0.22, 0.25)


def build_bailey_bits(P, Pc, rnd):
    # the well (stone ring and a timber windlass frame), a stable lean-to on the east wall, a few barrels as blocks
    for k in range(14):
        a = k * math.tau / 14
        L.dbox(P, "ashlar", (5.0 + math.cos(a) * 1.0, -4.0 + math.sin(a) * 1.0, 0.45), (0.8, 0.5, 0.9), yaw=a + 1.57)
    cyl(Pc, "stone", (5.0, -4.0, 0.0), (5.0, -4.0, 0.95), 1.2, seg=10)
    for sx in (-1.3, 1.3):
        beam(P, "timber", (5.0 + sx, -4.0, 0.0), (5.0 + sx, -4.0, 2.5), 0.16)
    beam(P, "timber", (3.7, -4.0, 2.4), (6.3, -4.0, 2.4), 0.16)
    cyl(P, "timber", (3.8, -4.0, 1.6), (6.2, -4.0, 1.6), 0.17, seg=8)
    # lean-to
    for k in range(5):
        x = 14.0
        y = -9.0 + k * 3.0
        beam(P, "timber", (x, y, 0.0), (x, y, 3.0), 0.24)
        beam(P, "timber", (x + 2.2, y, 0.0), (x + 2.2, y, 2.2), 0.24)
        beam(P, "timber", (x - 0.2, y, 3.0), (x + 2.4, y, 2.3), 0.2, 0.2)
    for k in range(3):
        box(P, "timber", (15.0 + 0.1, -7.5 + k * 3.2, 2.9 - k * 0.25), (2.6, 2.6, 0.12), pitch=0.12, yaw=0.0)


def build_wall_stair(P, Pc, rnd):
    """A solid stone stair up the inside of the east wall to the wall-walk (z 8.0)."""
    a = Vector((17.0, -14.0))
    b = Vector((20.0, 8.0))
    d = (b - a).normalized()
    n_in = Vector((d.y, -d.x)) * -1.0                       # inward (west)
    n_in = Vector((-d.y, d.x)) * -1.0
    # inward normal: the wall runs north-ish; inward = -x
    n_in = Vector((-1.0, 0.0))
    off = WALL_T * 0.5 + 0.8
    p0 = a + d * 3.0 + n_in * off + (d * 0.0)
    steps = 27
    tread = 0.5
    rise = 8.0 / steps
    for i in range(steps):
        c = p0 + d * (tread * (i + 0.5))
        hh = rise * (i + 1)
        L.dbox(P, "ashlar", (c.x, c.y, hh * 0.5 - 1.0 + 0.5), (tread * 1.02, 1.6, hh + 1.0), yaw=math.atan2(d.y, d.x))
        box(Pc, "stone", (c.x, c.y, hh * 0.5 - 1.0 + 0.5), (tread * 1.02, 1.6, hh + 1.0), yaw=math.atan2(d.y, d.x))
    # landing slab to the wall-walk
    c = p0 + d * (tread * steps + 0.5)
    L.dbox(P, "ashlar", (c.x, c.y, 3.5), (1.4, 1.6, 9.0), yaw=math.atan2(d.y, d.x))
    box(Pc, "stone", (c.x, c.y, 3.5), (1.4, 1.6, 9.0), yaw=math.atan2(d.y, d.x))


def asset_keep():
    reset()
    P = Parts()
    Pc = Parts()
    rnd = L.rnd_for(5)
    L.mason_begin(5)
    # the crag: a rough skirt of boulders under the compound so the walls don't float on the cut (the game's terrace is level)
    build_curtain(P, Pc, rnd)
    build_gatehouse(P, Pc, rnd)
    build_tower_round(P, Pc, rnd, (-17.0, -14.0), 3.9, 12.5, 61, 4.5, floor_z=7.0)
    build_tower_square(P, Pc, rnd, (17.0, -14.0), 7.0, 14.0, 62)
    build_tower_round(P, Pc, rnd, (20.0, 8.0), 4.2, 17.0, 63, 9.0, floor_z=8.0)
    build_tower_round(P, Pc, rnd, (-20.0, 8.0), 3.9, 11.5, 64, 4.0, floor_z=7.0)
    land = build_donjon(P, Pc, rnd)
    build_hall(P, Pc, rnd)
    build_bailey_bits(P, Pc, rnd)
    build_wall_stair(P, Pc, rnd)
    L.rubble(P, Pc, "ashlar", rnd, (-16, -12, 16, 9), 40, 0.4, 1.3)
    L.rubble(P, Pc, "ashlar", rnd, (-9, -12, 9, -2), 16, 0.4, 1.0, ground=0.0)
    keep = finish(P, "Keep", smooth_keys=()) + L.mason_end("Keep")
    col = col_collision(Pc, "Keep")
    far = keep_far()
    export(keep + [col] + far, os.path.join(MODELS, "reach_w_keep.glb"), "keep")
    preview(keep, "keep", [((-70, -85, 30), (0, 2, 12), 34), ((60, -50, 18), (0, 4, 10), 38), ((0, -62, 6), (0, 0, 8), 42),
                           ((34, 22, 36), (0, 6, 8), 40), ((0, -10, 62), (0, 2, 0), 40), ((-2, -22, 5), (-2, 12, 6), 40)])
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(BLEND, "reach_w_keep.blend"))


def keep_far():
    """A ~300-triangle silhouette of the compound: the game swaps to it beyond ~140 m."""
    Pf = Parts()
    cx, cy, w = DJ
    box(Pf, "stone", (cx, cy, DJ_H * 0.42), (w, w, DJ_H * 0.84))
    box(Pf, "stone", (cx + 3.0, cy + 1.0, DJ_H * 0.5), (w * 0.4, w * 0.5, DJ_H))
    for c, r, h in (((-17.0, -14.0), 4.4, 12.0), ((20.0, 8.0), 4.7, 15.0), ((-20.0, 8.0), 4.4, 10.5)):
        cyl(Pf, "stone", (c[0], c[1], -2.0), (c[0], c[1], h), r, seg=8)
    box(Pf, "stone", (17.0, -14.0, 6.0), (7.4, 7.4, 14.0))
    box(Pf, "stone", (0.0, -15.0, 8.0), (13.0, 5.0, 16.0))
    box(Pf, "stone", (0.0, -15.0, 13.0), (9.0, 4.0, 12.0))
    for (a, b) in (((-17, -14), (-6.5, -15)), ((6.5, -15), (17, -14)), ((17, -14), (20, 8)), ((20, 8), (6.5, 13.5)), ((-20, 8), (-6.5, 13.5)), ((-17, -14), (-20, 8))):
        am = Vector(a)
        bm = Vector(b)
        beam(Pf, "stone", (am.x, am.y, 3.0), (bm.x, bm.y, 3.0), 2.2, 8.0)
    objs = finish(Pf, "KeepFar")
    for o in objs:
        o.name = "KeepFar__far"
        o.hide_render = True
    return objs


# ============================================================================================
ASSETS = {"keep": asset_keep}


def register_more():
    for name in ("reach_west_shrine", "reach_west_wood", "reach_west_earth"):
        try:
            mod = __import__(name)
        except ImportError:
            continue
        ASSETS.update(mod.ASSETS)


if __name__ == "__main__":
    os.makedirs(MODELS, exist_ok=True)
    register_more()
    for k, fn in ASSETS.items():
        if ONLY and k not in ONLY:
            continue
        print("=== ", k)
        fn()
