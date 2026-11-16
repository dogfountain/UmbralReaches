"""West Reach stonework: the fell shrine, the Last Milestone and toll-house ruin, the heron stones, the King's Barrow.
Called from reach_west.py (ASSETS). See that file for the conventions."""
import math
import os
from reach_west_lib import *     # noqa: F401,F403
import reach_west_lib as L

R = L.rnd_for


def _finish(P, Pc, name, glb, views, extra=()):
    objs = finish(P, name)
    col = make_collision(finish(Pc, name + "Col"), name, 1.0)
    for o in [o for o in bpy.data.objects if o.name.startswith(name + "Col")]:
        bpy.data.objects.remove(o)
    export(objs + [col] + list(extra), os.path.join(MODELS, glb), name)
    preview(objs, name.lower(), views)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(BLEND, glb.replace(".glb", ".blend")))


# ============================================================================================
# THE FELL SHRINE: a roofless chapel the Crowns lean on
# ============================================================================================
def asset_shrine():
    reset()
    P, Pc = Parts(), Parts()
    rnd = R(21)
    w, d = 8.0, 11.0                  # x, y; the door in the south (-y) wall, the altar at the north end
    t = 0.9
    tops = {"S": L.ragged_top(1, 5.5, 3.0, 0.22), "N": L.ragged_top(2, 8.5, 3.5, 0.2), "E": L.ragged_top(3, 6.0, 4.0, 0.2), "W": L.ragged_top(4, 6.5, 3.2, 0.2)}

    def wall(a, b, name, door=None, wins=(), h=8.5):
        top = tops[name]

        def solid(u, v):
            if v < 0.0 or v > top(u):
                return False if v > 0.0 else True
            if door and L.arch_hole(u, v, door[0], door[1], 0.0, door[2]):
                return False
            for uc in wins:
                if L.arch_hole(u, v, uc, 1.3, 2.4, 4.1):
                    return False
            return True
        ln = (Vector(b) - Vector(a)).length
        L.wall_run(P, Pc, "ashlar", a, b, -0.8, h + 0.8, t, lambda u, v: solid(u, v - 0.8) if v >= 0.8 else True, rnd, ch=0.5,
                   ext=lambda j: (t, t) if j % 2 else (0.0, 0.0))
    wall((-w / 2, -d / 2), (w / 2, -d / 2), "S", door=(w * 0.5, 2.0, 2.7), wins=(1.4, w - 1.4))
    wall((w / 2, -d / 2), (w / 2, d / 2), "E", wins=(2.2, 5.2, 8.5))
    wall((w / 2, d / 2), (-w / 2, d / 2), "N", wins=(w * 0.5,))
    wall((-w / 2, d / 2), (-w / 2, -d / 2), "W", wins=(2.2, 5.5, 8.8))
    L.voussoirs(P, "ashlar", (0.0, -d / 2, 0.0), 0.0, 2.0, 2.7, t + 0.15, ring=0.45, n=11)
    # the altar, a saint with her hands out holding up nothing, the lamp niche
    box(P, "ashlar", (0, d / 2 - 1.6, 0.55), (2.6, 1.0, 1.1)); box(Pc, "stone", (0, d / 2 - 1.6, 0.55), (2.6, 1.0, 1.1))
    box(P, "stone", (0, d / 2 - 1.6, 1.15), (2.8, 1.2, 0.12))
    box(P, "ashlar", (0, d / 2 - 2.2, 1.0), (1.0, 0.8, 2.0)); box(Pc, "stone", (0, d / 2 - 2.2, 1.0), (1.0, 0.8, 2.0))
    box(P, "stone", (0, d / 2 - 2.2, 2.35), (0.7, 0.55, 1.2)); box(P, "stone", (0, d / 2 - 2.2, 3.15), (0.5, 0.5, 0.5))
    for sx in (-1, 1):
        box(P, "stone", (sx * 0.8, d / 2 - 2.35, 2.5), (0.9, 0.2, 0.2), yaw=0.0, pitch=0.0, roll=sx * 0.25)
    # fallen bell-gable stones, benches, rubble
    for k in range(5):
        box(P, "ashlar", (rnd.uniform(-2.5, 2.5), -1.5 + k * 1.6, 0.3), (2.4, 0.5, 0.45), yaw=rnd.uniform(-0.1, 0.1));
        box(Pc, "stone", (-2.0 + (k % 2) * 4.0, -1.5 + k * 1.6, 0.25), (1.8, 0.45, 0.5))
    L.rubble(P, Pc, "ashlar", rnd, (-6, -8, 6, 8), 26, 0.4, 1.4)
    # leaning buttresses on the east side: the Crowns' scree has pushed the wall
    for k in range(3):
        box(P, "stone", (w / 2 + 1.0, -3.0 + k * 3.4, 1.3), (1.6, 1.0, 2.6), yaw=0.0, roll=-0.16); box(Pc, "stone", (w / 2 + 1.0, -3.0 + k * 3.4, 1.3), (1.6, 1.0, 2.6))
    _finish(P, Pc, "Shrine", "reach_w_shrine.glb", [((-16, -20, 8), (0, 0, 3), 36), ((14, -8, 4), (0, 2, 3), 40), ((0, 0, 24), (0, 0, 0), 40)])


# ============================================================================================
# THE LAST MILESTONE and the toll-house ruin
# ============================================================================================
def asset_mile():
    reset()
    P, Pc = Parts(), Parts()
    rnd = R(31)
    # the milestone: a stepped base and a great tapering stone, 6 m tall, notched along one edge, a lamp hook on top
    for k, (s, h) in enumerate(((5.0, 0.4), (3.8, 0.4), (2.8, 0.4))):
        box(P, "ashlar", (0, 0, 0.2 + k * 0.4), (s, s, h)); box(Pc, "stone", (0, 0, 0.2 + k * 0.4), (s, s, h))
    stone = bmesh_prism = None
    rings = []
    for z, hw in ((1.2, 0.95), (3.0, 0.85), (5.0, 0.72), (6.4, 0.6)):
        rings.append([Vector((-hw, -hw * 0.8, z)), Vector((hw, -hw * 0.8, z)), Vector((hw, hw * 0.8, z)), Vector((-hw, hw * 0.8, z))])
    ring_loft(P, "stone", rings)
    ring_loft(Pc, "stone", rings)
    box(P, "stone", (0, 0, 6.55), (0.9, 0.7, 0.3), yaw=0.3)
    for k in range(12):                                     # the miles cut in the face: a notch for each
        box(P, "iron", (0.0, -0.78 + 0.0, 1.6 + k * 0.36), (0.9, 0.04, 0.06))
    cyl(P, "iron", (0.0, -0.2, 6.6), (0.0, -0.2, 7.6), 0.05, seg=6); beam(P, "iron", (0.0, -0.2, 7.6), (0.9, -0.2, 7.5), 0.06)
    # the toll-house, roofless: 7 x 5, a hearth, a counter, a barrier pole fallen across the road
    t = 0.8
    tx, ty = 8.5, 0.0
    tops = [L.ragged_top(5 + i, 5.0, 3.0, 0.25) for i in range(4)]
    wd, dp = 7.0, 5.0
    pts = [((tx - wd / 2, ty - dp / 2), (tx + wd / 2, ty - dp / 2)), ((tx + wd / 2, ty - dp / 2), (tx + wd / 2, ty + dp / 2)),
           ((tx + wd / 2, ty + dp / 2), (tx - wd / 2, ty + dp / 2)), ((tx - wd / 2, ty + dp / 2), (tx - wd / 2, ty - dp / 2))]
    for i, (a, b) in enumerate(pts):
        top = tops[i]

        def solid(u, v, i=i, top=top):
            if v < 0.8:
                return True
            vv = v - 0.8
            if vv > top(u):
                return False
            if i == 3 and L.arch_hole(u, vv, 2.5, 1.2, 0.0, 1.9):
                return False
            if i == 0 and L.rect_hole(u, vv, 2.0, 1.4, 1.1, 2.3):
                return False
            if i == 1 and L.rect_hole(u, vv, 2.5, 1.4, 1.1, 2.3):
                return False
            return True
        L.wall_run(P, Pc, "ashlar", a, b, -0.8, 5.8, t, solid, rnd, ch=0.48, ext=lambda j: (t, t) if j % 2 else (0, 0))
    box(P, "ashlar", (tx + 2.4, ty + dp / 2 - 1.2, 1.1), (2.2, 1.1, 2.2)); box(Pc, "stone", (tx + 2.4, ty + dp / 2 - 1.2, 1.1), (2.2, 1.1, 2.2))   # chimney breast
    box(P, "timber", (tx - 1.5, ty - 0.5, 0.55), (3.0, 0.7, 0.9)); box(Pc, "stone", (tx - 1.5, ty - 0.5, 0.55), (3.0, 0.7, 0.9))                    # counter
    beam(P, "timber", (tx - 7.0, ty - 5.0, 0.2), (tx - 1.0, ty - 3.0, 0.4), 0.2)                                                                       # the barrier pole
    for k in range(4):
        beam(P, "timber", (tx - 3.0 + k * 1.8, ty - 2.2, 4.6), (tx - 2.4 + k * 1.7, ty + 1.8, 3.4 - k * 0.4), 0.2, 0.26)                              # joists fallen in
    L.rubble(P, Pc, "ashlar", rnd, (tx - 6, ty - 6, tx + 6, ty + 6), 20, 0.4, 1.3)
    _finish(P, Pc, "Mile", "reach_w_mile.glb", [((-12, -14, 6), (4, 0, 3), 40), ((8, -16, 5), (8, 0, 2), 40), ((0, -6, 3), (0, 0, 4), 50)])


# ============================================================================================
# THE HERON STONES: seven slabs standing in the mere, each topped with a long bird, the beak turned in
# ============================================================================================
def asset_herons():
    reset()
    P, Pc = Parts(), Parts()
    rnd = R(41)
    n = 7
    R0 = 7.0
    for i in range(n):
        a = math.tau * i / n + 0.2
        cx, cy = math.cos(a) * R0, math.sin(a) * R0
        hgt = rnd.uniform(3.4, 4.6)
        hw = rnd.uniform(0.55, 0.75)
        face = a + math.pi                               # looking at the centre
        # the slab: tapered, leaning a little, buried 3 m (the water's depth)
        rings = []
        for z, k in ((-3.0, 1.05), (0.0, 1.0), (hgt * 0.55, 0.9), (hgt, 0.7)):
            ww, dd = hw * k, 0.32 * k
            lean = (z + 3.0) * 0.012 * (1 if i % 2 else -1)
            loc = [(-ww, -dd), (ww, -dd), (ww, dd), (-ww, dd)]
            rings.append([Vector((cx + math.cos(face + math.pi / 2) * (px + lean) + math.cos(face) * py, cy + math.sin(face + math.pi / 2) * (px + lean) + math.sin(face) * py, z)) for px, py in loc])
        ring_loft(P, "stone", rings); ring_loft(Pc, "stone", rings)
        # the heron: a neck rising from the slab's top, a head, a long beak pointing at the ring's middle, a crest
        top = Vector((cx, cy, hgt))
        inward = Vector((math.cos(face), math.sin(face), 0.0))
        p0 = top
        p1 = top + Vector((0, 0, 1.1)) - inward * 0.25
        p2 = top + Vector((0, 0, 2.0)) + inward * 0.1
        p3 = top + Vector((0, 0, 2.6)) + inward * 0.35
        for a_, b_, w_ in ((p0, p1, 0.34), (p1, p2, 0.26), (p2, p3, 0.2)):
            beam(P, "stone", a_, b_, w_)
        box(P, "stone", p3 + inward * 0.25, (0.5, 0.3, 0.3), yaw=face)
        beam(P, "stone", p3 + inward * 0.3, p3 + inward * 1.8 - Vector((0, 0, 0.35)), 0.12)
        beam(P, "stone", p3, p3 - inward * 0.9 + Vector((0, 0, 0.3)), 0.07)
        beam(Pc, "stone", p0, p2, 0.34)
        # a weathered notch course, and three cut lines on the face
        for j in range(3):
            box(P, "iron", (cx + inward.x * 0.33, cy + inward.y * 0.33, 1.0 + j * 0.5), (hw * 1.2, 0.03, 0.05), yaw=face + math.pi / 2)
    # a low stone in the middle: the one a seventh heron never took
    rock_lump(P, "stone", (0, 0, 0.1), (1.0, 0.9, 0.55), rnd)
    rock_lump(Pc, "stone", (0, 0, 0.1), (1.0, 0.9, 0.55), rnd)
    _finish(P, Pc, "Herons", "reach_w_herons.glb", [((16, -18, 5), (0, 0, 2), 38), ((-12, 6, 2.5), (0, 0, 3), 42), ((0, 0, 28), (0, 0, 0), 40)])


# ============================================================================================
# THE KING'S BARREN: a mound with kerbstones, a dry-stone forecourt and a passage into a corbelled chamber
# ============================================================================================
BR = 16.0
BH = 6.5


def mound_h(r):
    return BH * max(0.0, 1.0 - (r / BR) ** 2.6) ** 0.9


def asset_barrow():
    reset()
    P, Pc = Parts(), Parts()
    rnd = R(51)
    # the mound: a loft of rings, hollow where the passage comes out (west, -x)
    nth, nr = 56, 12
    bm_t = P.of("turf")
    bm_c = Pc.of("stone")
    grid = []
    for ir in range(nr + 1):
        r = BR * (ir / nr) * 1.02
        ring = []
        for it in range(nth):
            th = math.tau * it / nth
            n1 = fbm(Vector((math.cos(th) * 1.4 + 3, math.sin(th) * 1.4, r * 0.15)), 3) * 0.35
            z = mound_h(r) + n1 * (0.4 if ir < nr else 0.0) - (0.0 if ir < nr else 0.8)
            ring.append(Vector((math.cos(th) * r, math.sin(th) * r, z)))
        grid.append(ring)
    for target in (bm_t, bm_c):
        vr = [[target.verts.new(p) for p in ring] for ring in grid]
        for i in range(nr):
            for j in range(nth):
                j1 = (j + 1) % nth
                pm = (grid[i][j] + grid[i + 1][j1]) * 0.5
                # the passage mouth: west of the middle, within 1.7 m either side, outside radius 11
                if pm.x < -10.5 and abs(pm.y) < 1.9 and pm.z < 2.6:
                    continue
                target.faces.new((vr[i][j], vr[i][j1], vr[i + 1][j1], vr[i + 1][j]))
        target.faces.new([v for v in vr[0]][::-1]) if False else None
    # kerbstones round the foot, a gap at the door, each a standing slab leaning outward, a hollow forecourt either side
    nk = 34
    for k in range(nk):
        th = math.tau * (k + 0.5) / nk
        if abs(((th - math.pi) + math.pi) % math.tau - math.pi) < 0.26:
            continue
        r = BR * 0.99
        hh = rnd.uniform(1.3, 2.0)
        ww = rnd.uniform(1.4, 2.2)
        hh *= 1.25
        c = (math.cos(th) * r, math.sin(th) * r, hh * 0.5 - 0.5)
        rock_lump(P, "stone", c, (ww * 0.5, 0.55, hh * 0.55), rnd, seg=(8, 6))
        rock_lump(Pc, "stone", c, (ww * 0.5, 0.55, hh * 0.55), rnd, seg=(5, 4))
    # a cairn of fitted stones on the crown
    for k in range(9):
        a = rnd.uniform(0, math.tau)
        dd = rnd.uniform(0.0, 2.2)
        rock_lump(P, "stone", (math.cos(a) * dd, math.sin(a) * dd, BH - 0.2 + (1.2 - dd * 0.35)), (rnd.uniform(0.7, 1.2), rnd.uniform(0.7, 1.2), rnd.uniform(0.5, 0.8)), rnd)
    rock_lump(Pc, "stone", (0, 0, BH + 0.6), (2.4, 2.4, 1.3), rnd)
    # the forecourt: two horns of dry-stone wall curving out from the door, and the great lintel stone
    door_x = -BR * 0.99
    for sy in (-1, 1):
        for k in range(7):
            a = k / 6.0
            x = door_x - 0.4 - a * 4.5
            y = sy * (1.9 + a * a * 3.6)
            box(P, "ashlar", (x, y, 0.9), (1.3, 0.9, 1.9 - 0.15 * k), yaw=math.atan2(sy * 2.0 * a * 3.6, -1.0) * 0.0 + sy * a * 0.7)
            box(Pc, "stone", (x, y, 0.9), (1.3, 0.9, 1.9 - 0.15 * k), yaw=sy * a * 0.7)
        box(P, "stone", (door_x + 0.2, sy * 1.25, 1.35), (0.9, 0.8, 2.7)); box(Pc, "stone", (door_x + 0.2, sy * 1.25, 1.35), (0.9, 0.8, 2.7))   # door jambs
    box(P, "stone", (door_x + 0.2, 0, 2.95), (1.3, 3.6, 0.7)); box(Pc, "stone", (door_x + 0.2, 0, 2.95), (1.3, 3.6, 0.7))                    # lintel
    box(P, "stone", (door_x + 0.2, 0, 3.55), (1.1, 4.2, 0.6), roll=0.0)
    # the passage: slab orthostats and capstones, floor, 1.7 m wide, 2.2 m high, from the door to the chamber
    x0, x1 = door_x + 0.6, -2.6
    k = 0
    x = x0
    while x < x1:
        ln = rnd.uniform(1.4, 2.0)
        hh = rnd.uniform(2.1, 2.35)
        for sy in (-1, 1):
            box(P, "stone", (x + ln / 2, sy * 1.0, hh / 2), (ln, 0.3, hh), yaw=0.0, pitch=rnd.uniform(-0.01, 0.01))
            box(Pc, "stone", (x + ln / 2, sy * 1.0, hh / 2), (ln, 0.3, hh))
        box(P, "stone", (x + ln / 2, 0, 2.35), (ln + 0.1, 2.5, 0.38)); box(Pc, "stone", (x + ln / 2, 0, 2.35), (ln + 0.1, 2.5, 0.38))
        x += ln
    box(P, "stone", (x0 + (x1 - x0) / 2, 0, -0.1), (x1 - x0, 2.0, 0.3)); box(Pc, "stone", ((x0 + x1) / 2, 0, -0.1), (x1 - x0, 2.0, 0.3))
    # the chamber: 5 x 5, walls of stacked slabs corbelling in, a flat capstone at 3.8, a cist and a rune slab
    cw = 2.6
    for sx, sy, yw in ((cw, 0, math.pi / 2), (-cw, 0, math.pi / 2), (0, cw, 0.0), (0, -cw, 0.0)):
        for lv in range(5):
            inset = lv * 0.18
            ln = 5.4 - lv * 0.5
            c = (sx * (1.0 - inset / cw * 0.7), sy * (1.0 - inset / cw * 0.7), 0.4 + lv * 0.62)
            if sx == -cw and abs(sy) < 1.0 and lv < 4:
                continue           # the passage comes in on the west side
            box(P, "stone", c, (0.5, ln, 0.64) if sx != 0 else (ln, 0.5, 0.64), yaw=0.0)
            box(Pc, "stone", c, (0.5, ln, 0.64) if sx != 0 else (ln, 0.5, 0.64), yaw=0.0)
    box(P, "stone", (0, 0, 3.7), (3.6, 3.6, 0.5)); box(Pc, "stone", (0, 0, 3.7), (3.6, 3.6, 0.5))
    box(P, "stone", (0.4, 0.0, 0.2), (2.0, 1.0, 0.5)); box(Pc, "stone", (0.4, 0.0, 0.2), (2.0, 1.0, 0.5))      # the king's cist, lid pushed aside
    box(P, "stone", (0.9, 0.5, 0.52), (1.4, 0.7, 0.14), yaw=0.35)
    box(P, "stone", (0.0, 2.4, 1.0), (0.1, 1.8, 1.4))                                                           # the inscription slab on the north wall (the game reads it)
    box(P, "glow", (0.02, 2.33, 1.0), (0.05, 1.5, 1.1))                                                         # its cut letters, a dim cold shine
    # a few fallen kerbstones and cairn heaps at the foot
    L.rubble(P, Pc, "stone", rnd, (-22, -9, -14, 9), 8, 0.6, 1.4)
    objs = finish(P, "Barrow")
    col = make_collision(finish(Pc, "BarrowCol"), "Barrow", 1.0)
    for o in [o for o in bpy.data.objects if o.name.startswith("BarrowCol")]:
        bpy.data.objects.remove(o)
    export(objs + [col], os.path.join(MODELS, "reach_w_barrow.glb"), "barrow")
    preview(objs, "barrow", [((-40, -26, 14), (-6, 0, 2), 36), ((-26, 0, 3.0), (-8, 0, 1.8), 50), ((0, 0, 60), (0, 0, 0), 36), ((-12, -2, 2.0), (2, 0, 1.4), 60)])
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(BLEND, "reach_w_barrow.blend"))


ASSETS = {"shrine": asset_shrine, "mile": asset_mile, "herons": asset_herons, "barrow": asset_barrow}
