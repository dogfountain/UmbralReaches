"""Lastlight (tools/blender/reach_towns.py): the Order's walled waystation at the road's east end, the last lamp the
pilgrims saw before the road turned to the mountain. Origin on the ground at each piece's middle; for the wall pieces
(walls, towers, gates) x runs along the wall and +z is the TOWN side (the parapet and the batter face -z, outward).

  LL_EastGate    the shut East Gate: twin battered towers with corbelled parapets and roofed stair turrets, a pointed
                 passage, the oak leaves barred three times and chained, a portcullis dropped in front of them, a plaque
  LL_RoadGate    the road gate on the west: a square gatehouse with a room over the arch under a slate roof, its leaves
                 swung open into the town, lamp brackets either side
  LL_Wall        10 m of curtain: a battered footing, a string course, loops, a corbelled parapet facing out
  LL_Postern     the same with a small arched door through it (the Bellfall track)
  LL_WallTower   a round corner tower: a drum with loops and a string course, a corbel ring, a conical slate roof
  LL_LampTower   the lamp tower: an octagonal shaft on a battered base, a stair turret, a corbelled gallery with an iron
                 rail, the great lantern ("lamp_glass": the game lights it), a lead cap and a vane (28 m)
  LL_Inn         the Last Lamp: a stone ground floor, a jettied timber floor over it, a steep slate roof with three
                 dormers, two stacks, a porch with the sign, a kitchen outshot behind
  LL_Stable      a long stable: a stone back wall, an open front of posts and half-doors, stalls, a hay loft with a hoist
  LL_Watch       the watch house: stone under a hipped slate roof, and its timber watch-platform with a brazier basket
  LL_Store       a stone store with a loft door and a hoist beam
  LL_Shrine      a pilgrims' shrine by the East Gate: a niche under a little roof, a kneeling step, candle stubs
  LL_GateFar LL_RoadGateFar LL_WallFar LL_TowerFar LL_InnFar   the silhouettes
"""
import math
from mathutils import Vector
import r37_wall as RW
import reach_town_lib as RL
from reach_town_lib import T, TINT, grouped, lathe_at, far_piece
from r37_wall_lib import lerp, clamp

WALL_LEN = 10.0
WALL_H = 6.4           ## the curtain's top (its walk; the parapet stands over the outer edge)
WALL_OUT = -1.3        ## the outer face's line (at the string course)
WALL_IN = 1.0          ## the inner face
GATE_W = 21.2          ## the East Gate's breadth along the wall
ROAD_GATE_W = 12.0
TOWER_R = 3.6


def curtain(b, x0, x1, seed=0, loops=True, door=None):
    """A run of curtain wall x0..x1 (door = (x, w, h): a passage through it)."""
    T_ = TINT
    pieces = [(x0, x1)] if door is None else [(x0, door[0] - door[1] / 2), (door[0] + door[1] / 2, x1)]
    for (a, c) in pieces:
        if c - a < 0.05:
            continue
        b.rect_solid(a, c, WALL_OUT - 0.6, WALL_IN + 0.15, -1.8, 1.6, bat=(0.0, 0.0, 0.7, 0.0), mat="stone", tint=T_["damp"], jit=0.035, seed=seed + 1)
        b.rect_solid(a, c, WALL_OUT, WALL_IN, 1.5, WALL_H, bat=(0.0, 0.0, 0.18, 0.0), mat="stone", tint=T_["plain"], jit=0.03, seed=seed + 2)
        b.rect_solid(a, c, WALL_OUT - 0.14, WALL_OUT + 0.3, 3.9, 4.2, mat="stone", uv=1.4, tint=T_["pale"], jit=0.01, seed=seed + 3)
    if door is not None:
        dx, dw, dh = door
        b.rect_solid(dx - dw / 2 - 0.05, dx + dw / 2 + 0.05, WALL_OUT + 0.15, WALL_IN, dh + 0.9, WALL_H, mat="stone", tint=T_["plain"], jit=0.02, seed=seed + 4)
        b.arch(dx, dh, dw, 0.42, WALL_OUT - 0.05, WALL_OUT + 0.6, "stone", uv=1.5, n=5, tint=T_["pale"], seed=seed + 5, jit=0.008, alt=0.05)
        b.arch(dx, dh, dw, 0.36, WALL_IN - 0.5, WALL_IN + 0.08, "stone", uv=1.5, n=5, tint=T_["pale"], seed=seed + 6, jit=0.008)
        for sx in (-1, 1):
            b.box((dx + sx * (dw / 2 + 0.18), dh / 2, (WALL_OUT + WALL_IN) / 2), (0.36, dh, WALL_IN - WALL_OUT + 0.1), "stone", uv=1.5, tint=T_["pale"], jit=0.01, cuts=1)
        # the passage's ceiling (a flat vault of slabs over the crown)
        b.box((dx, dh + dw * 0.87 + 0.2, (WALL_OUT + WALL_IN) / 2), (dw + 0.2, 0.4, WALL_IN - WALL_OUT), "stone", uv=1.3, tint=T_["dark"], cuts=0, jit=0.0)
        # its leaf, hung open against the inside of the passage
        b.box((dx - dw / 2 + 0.14, dh * 0.62, WALL_IN - 0.9), (0.12, dh * 1.2, dw * 0.95), "plank", cuts=0, jit=0.0)
    # the parapet on corbels over the outer face, crenels and merlons
    b.battlement([("line", (x0, WALL_OUT), (x1, WALL_OUT))], WALL_H - 1.1, (0.5 * (x0 + x1), 0.0), seed=seed + 7, mw=1.25, pitch=2.2, tint=TINT["plain"],
                 gaps=() if door is None else ())
    # the walk's paving and an inner kerb
    b.box(((x0 + x1) / 2, WALL_H + 0.06, (WALL_OUT + WALL_IN) / 2 + 0.3), (x1 - x0, 0.12, WALL_IN - WALL_OUT - 0.4), "stone", uv=1.3, tint=TINT["pale"], cuts=2, jit=0.005)
    b.box(((x0 + x1) / 2, WALL_H + 0.3, WALL_IN - 0.15), (x1 - x0, 0.5, 0.35), "stone", uv=1.4, tint=TINT["pale"], cuts=1, jit=0.008)
    if loops:
        for k in range(int((x1 - x0) / 3.4)):
            x = x0 + 1.7 + k * 3.4
            if door is not None and abs(x - door[0]) < door[1]:
                continue
            b.box((x, 2.8, WALL_OUT - 0.25 * 0.18 / 4.9), (0.16, 1.4, 0.1), "dark", cuts=0, jit=0.0)
            for q in (-1, 1):
                b.box((x + q * 0.2, 2.8, WALL_OUT - 0.03), (0.24, 1.7, 0.14), "stone", uv=1.6, tint=TINT["pale"], cuts=0, jit=0.008)
            # putlog holes on the inner face
            b.box((x + 0.8, 4.6, WALL_IN + 0.02), (0.22, 0.22, 0.06), "dark", cuts=0, jit=0.0)


def wall_piece(name="LL_Wall", door=None, seed=0):
    b = T(name, seed=10101 + seed, damp=1.1)
    hl = WALL_LEN / 2
    curtain(b, -hl, hl, seed=seed, door=door)
    if door is None:
        b.colbox((0.0, (WALL_H + 1.0) / 2 - 0.5, (WALL_OUT + WALL_IN) / 2), (WALL_LEN, WALL_H + 1.0, WALL_IN - WALL_OUT + 0.3))
    else:
        dx, dw, dh = door
        for (a, c) in ((-hl, dx - dw / 2), (dx + dw / 2, hl)):
            b.colbox(((a + c) / 2, (WALL_H + 1.0) / 2 - 0.5, (WALL_OUT + WALL_IN) / 2), (c - a, WALL_H + 1.0, WALL_IN - WALL_OUT + 0.3))
        b.colbox((dx, (dh + dw * 0.87 + WALL_H) / 2 + 0.3, (WALL_OUT + WALL_IN) / 2), (dw + 0.2, WALL_H - dh - dw * 0.87 + 0.6, WALL_IN - WALL_OUT + 0.3))
    b.colbox((0.0, WALL_H + 0.8, WALL_OUT - 0.1), (WALL_LEN, 1.6, 0.8))
    return b.finish()


def wall_tower():
    b = T("LL_WallTower", seed=10201, damp=1.2)
    R0, H = TOWER_R, 10.4
    lathe_at(b, 0.0, 0.0, -1.8, [(R0 + 0.55, 0.0), (R0 + 0.3, 2.6), (R0, 3.4)], "stone", sides=18, jit=0.02, seed=1)
    lathe_at(b, 0.0, 0.0, 1.5, [(R0, 0.0), (R0 - 0.2, H - 1.5)], "stone", sides=18, jit=0.015, seed=2)
    b.frustum(0.0, 0.0, R0 + 0.06, R0 + 0.02, 4.1, 4.4, "stone", round_n=18, levels=2, jit=0.006, tint=TINT["pale"])
    # a corbel ring and a plain parapet ring under the roof
    for i in range(14):
        a = math.tau * i / 14
        for k, (ya, yb, pr) in enumerate(((0.0, 0.3, 0.2), (0.3, 0.6, 0.38), (0.6, 0.88, 0.55))):
            rr = R0 - 0.2 + pr / 2
            b.box((math.cos(a) * rr, H - 0.9 + (ya + yb) / 2, math.sin(a) * rr), (0.5, yb - ya, pr), "stone", yaw=-a + math.pi / 2, uv=1.5, tint=TINT["pale"], cuts=0, jit=0.008)
    b.frustum(0.0, 0.0, R0 + 0.4, R0 + 0.4, H, H + 1.0, "stone", round_n=18, levels=2, jit=0.01, tint=TINT["plain"])
    for i in range(8):
        a = math.tau * i / 8 + 0.2
        r = R0 - 0.25
        b.box((math.cos(a) * r, 2.6 + (i % 2) * 3.0, math.sin(a) * r), (0.16, 1.4, 0.4), "dark", yaw=-a + math.pi / 2, cuts=0, jit=0.0)
    # the cone of slates over the eaves, a finial
    b.frustum(0.0, 0.0, R0 + 0.9, 0.2, H + 0.8, H + 7.4, "slate", round_n=18, levels=6, jit=0.02, seed=3)
    b.frustum(0.0, 0.0, R0 + 0.95, R0 + 0.7, H + 0.7, H + 1.0, "slate", round_n=18, levels=2, jit=0.01, seed=4)
    b.tube((0.0, H + 7.2, 0.0), (0.0, H + 8.4, 0.0), 0.04, 0.02, "iron", sides=4, bark=1.0)
    lathe_at(b, 0.0, 0.0, H + 7.6, [(0.01, 0.0), (0.09, 0.08), (0.01, 0.16)], "iron", sides=6)
    # a door on the town side
    b.door(0.0, R0 - 0.15, w=1.3, h=2.4, face=1, step=0.3, frame="stone", studs=True)
    b.colbox((0.0, H / 2, 0.0), (2 * R0 + 0.4, H + 1.0, 2 * R0 + 0.4))
    b.colbox((0.0, H + 2.5, 0.0), (2 * R0, 3.0, 2 * R0))
    return b.finish()


def east_gate():
    b = T("LL_EastGate", seed=10301, damp=1.0)
    TW, TH, TD = 8.0, 17.0, 8.6
    GX = 6.6                                         # the towers' centres
    for sx in (-1, 1):
        cx = sx * GX
        b.rect_solid(cx - TW / 2, cx + TW / 2, -TD / 2, TD / 2, -2.0, TH - 1.4, bat=(0.35,) * 4, foot=(0.5,) * 4, mat="stone", tint=TINT["plain"], jit=0.04, seed=3 + sx)
        for yy in (5.5, 11.0):
            b.rect_solid(cx - TW / 2 - 0.25, cx + TW / 2 + 0.25, -TD / 2 - 0.25, TD / 2 + 0.25, yy, yy + 0.35, uv=1.5, mat="stone", tint=TINT["pale"], jit=0.01, seed=7)
        yt = TH - 1.4
        b.battlement([("line", (cx - TW / 2 + 0.3, -TD / 2 + 0.3), (cx + TW / 2 - 0.3, -TD / 2 + 0.3)), ("line", (cx + TW / 2 - 0.3, -TD / 2 + 0.3), (cx + TW / 2 - 0.3, TD / 2 - 0.3)),
                      ("line", (cx + TW / 2 - 0.3, TD / 2 - 0.3), (cx - TW / 2 + 0.3, TD / 2 - 0.3)), ("line", (cx - TW / 2 + 0.3, TD / 2 - 0.3), (cx - TW / 2 + 0.3, -TD / 2 + 0.3))],
                     yt - 0.9, (cx, 0.0), seed=10 + sx, mw=1.1, pitch=1.9, tint=TINT["plain"])
        b.box((cx, yt + 0.4, 0.0), (TW - 0.6, 0.3, TD - 0.6), "stone", uv=1.2, tint=TINT["pale"], cuts=2, jit=0.005)
        for lv in (3.6, 8.4, 13.2):
            for face in (1, -1):
                b.box((cx, lv, face * (TD / 2 - 0.08 * (lv / TH))), (0.16, 1.5, 0.12), "dark", cuts=0, jit=0.0)
                for q in (-1, 1):
                    b.box((cx + q * 0.2, lv, face * (TD / 2 - 0.05 * (lv / TH))), (0.24, 1.9, 0.14), "stone", uv=1.6, tint=TINT["pale"], jit=0.008, cuts=0)
        # a roofed stair turret at the outer corner
        tx, tz = cx + sx * (TW / 2 - 1.2), -TD / 2 + 1.4
        b.frustum(tx, tz, 1.35, 1.25, yt, yt + 3.2, "stone", round_n=10, levels=2, jit=0.01, seed=20 + sx)
        b.frustum(tx, tz, 1.7, 0.08, yt + 3.1, yt + 5.6, "slate", round_n=10, levels=3, jit=0.0, seed=22 + sx)
        b.box((tx, yt + 1.9, tz + 1.2), (0.16, 0.9, 0.12), "dark", cuts=0, jit=0.0)
    # the middle: the passage's block, its faces with the arch rings, the vault, the gallery over it
    PW, SP = 5.2, 4.8
    xi = GX - TW / 2
    b.rect_solid(-xi - 0.1, xi + 0.1, -TD / 2 + 0.8, TD / 2 - 0.8, SP + PW * 0.87 + 0.3, TH - 3.6, mat="stone", tint=TINT["plain"], jit=0.02, seed=31)
    for zf in (TD / 2 - 0.8, -TD / 2 + 0.8):
        sg = 1 if zf > 0 else -1
        left = []
        for i in range(11):
            th = math.pi - (math.pi / 3.0) * i / 10
            left.append((PW / 2 + PW * math.cos(th), SP + PW * math.sin(th)))
        for i in range(10):
            xa, ya = left[i]
            xb, yb = left[i + 1]
            for sx in (-1, 1):
                pts = [(sx * xa, ya), (sx * xa, SP + PW * 0.87 + 0.35), (sx * xb, SP + PW * 0.87 + 0.35), (sx * xb, yb)]
                if sx < 0:
                    pts = list(reversed(pts))
                b.poly_z(pts, min(zf, zf + sg * 0.5), max(zf, zf + sg * 0.5), "stone", uv=1.0)
        b.arch(0.0, SP, PW, 0.55, min(zf, zf + sg * 0.6), max(zf, zf + sg * 0.6), "stone", uv=1.5, n=9, tint=TINT["pale"], seed=34 + sg, jit=0.008, alt=0.07)
        for sx in (-1, 1):
            b.box((sx * (PW / 2 + 0.3), SP / 2, zf + sg * 0.25), (0.6, SP, 0.6), "stone", uv=1.5, tint=TINT["pale"], jit=0.01, cuts=1)
    b.box((0.0, SP + PW * 0.87 + 0.15, 0.0), (PW + 0.3, 0.3, TD - 1.6), "stone", uv=1.2, tint=TINT["dark"], cuts=1, jit=0.0)
    for sx in (-1, 1):
        b.box((sx * (PW / 2 + 0.15), SP / 2 + 1.0, 0.0), (0.3, SP + 2.0, TD - 1.6), "stone", uv=1.2, tint=TINT["dark"], cuts=1, jit=0.01)
    # the oak leaves, shut in the middle of the passage: straps, three bars in brackets, a chain, a lock
    zg = 0.0
    b.poly_z(RW.arch_poly(0.0, SP, PW - 0.1, 0.0), zg - 0.22, zg + 0.22, "plank", uv=1.2)
    for face in (1, -1):
        b.box((0.0, 2.6, zg + face * 0.24), (0.08, 5.2, 0.06), "dark", cuts=0, jit=0.0)
        for yy in (1.1, 2.9, 4.5):
            b.box((0.0, yy, zg + face * 0.28), (PW - 0.3, 0.12, 0.05), "iron", cuts=0, jit=0.0)
    for yy in (1.5, 3.2, 4.7):
        b.box((0.0, yy, zg + 0.6), (PW + 0.6, 0.42, 0.42), "plank", uv=0.8, cuts=0, jit=0.0)
        for sx in (-1, 1):
            b.box((sx * (PW / 2 - 0.1), yy, zg + 0.55), (0.4, 0.8, 0.62), "iron", cuts=0, jit=0.0)
    for a in (-1, 1):
        b.tube((a * 2.2, 4.7, zg + 0.88), (-a * 2.2, 1.5, zg + 0.88), 0.045, 0.045, "iron", sides=5, bark=1.0, cap=False)
    b.box((0.0, 3.1, zg + 0.95), (0.5, 0.6, 0.3), "iron", cuts=0, jit=0.0)
    # the portcullis, down, in the outer mouth (-z)
    zp = -TD / 2 + 1.25
    for i in range(-5, 6):
        b.box((i * 0.48, 2.6, zp), (0.1, 5.2, 0.1), "iron", cuts=0, jit=0.0)
        b.frustum(i * 0.48, zp, 0.06, 0.01, -0.15, 0.05, "iron", round_n=4, levels=2, jit=0.0)
    for yy in (0.5, 1.6, 2.7, 3.8, 4.8):
        b.box((0.0, yy, zp), (PW - 0.2, 0.1, 0.1), "iron", cuts=0, jit=0.0)
    # the gallery on the town face: a corbelled platform, a lamp bracket, the plaque
    gz = TD / 2 - 0.8
    b.rect_solid(-xi, xi, gz - 0.2, gz + 1.3, TH - 4.2, TH - 3.8, mat="stone", uv=1.4, tint=TINT["pale"], jit=0.01, seed=41)
    for x in (-2.4, -0.8, 0.8, 2.4):
        b.box((x, TH - 4.5, gz + 0.6), (0.5, 0.55, 1.0), "stone", uv=1.4, tint=TINT["pale"], jit=0.01, cuts=0)
    for k in range(9):
        x = -xi + 0.3 + k * (2 * xi - 0.6) / 8
        b.log((x, TH - 3.8, gz + 1.15), (x, TH - 2.8, gz + 1.15), 0.035, 0.035, "iron", sides=4, crook=0.0)
    b.box((0.0, TH - 2.85, gz + 1.15), (2 * xi - 0.4, 0.06, 0.06), "iron", cuts=0, jit=0.0)
    b.box((0.0, SP + PW * 0.87 + 1.6, gz + 0.05), (3.6, 1.3, 0.14), "stone", uv=1.6, tint=TINT["pale"], cuts=0, jit=0.0)
    for k in range(5):
        b.box((-1.3 + k * 0.65, SP + PW * 0.87 + 1.6 + (0.2 if k % 2 else -0.15), gz + 0.13), (0.42, 0.06, 0.02), "dark", cuts=0, jit=0.0)
    RL.DATA["east_gate"] = {"plaque": [0.0, SP + PW * 0.87 + 1.6, gz + 0.3], "lamp": [0.0, TH - 3.0, gz + 1.0], "width": GATE_W, "passage": [PW, SP]}
    b.box((0.0, SP + PW * 0.87 + 0.6, gz + 0.3), (0.12, 0.12, 0.7), "iron", cuts=0, jit=0.0)
    # stubs of curtain to each side (the wall pieces join here)
    for sx in (-1, 1):
        b.rect_solid(sx * (GX + TW / 2 - 0.2) if sx > 0 else -GATE_W / 2, GATE_W / 2 if sx > 0 else -(GX + TW / 2 - 0.2), WALL_OUT, WALL_IN, -1.8, WALL_H, mat="stone", tint=TINT["plain"], jit=0.03, seed=50 + sx)
    # collision: both towers whole, the passage shut by the leaves
    for sx in (-1, 1):
        b.colbox((sx * GX, TH / 2 - 0.5, 0.0), (TW + 0.4, TH + 1.0, TD + 0.4))
    b.colbox((0.0, TH / 2, 0.0), (2 * xi + 0.2, TH, 0.8))
    b.colbox((0.0, (SP + PW + TH) / 2, 0.0), (2 * xi + 0.2, TH - SP - PW * 0.7, TD - 1.6))
    return b.finish()


def road_gate():
    b = T("LL_RoadGate", seed=10401, damp=1.0)
    GW, GD, GH = ROAD_GATE_W, 8.0, 10.6
    hw, hd = GW / 2, GD / 2
    PW, SP = 5.0, 3.9
    b.rect_solid(-hw, hw, -hd, hd, -1.8, 1.2, bat=(0.0,) * 4, foot=(0.4, 0.4, 0.4, 0.4), mat="stone", tint=TINT["damp"], jit=0.035, seed=1)
    for sx in (-1, 1):
        b.rect_solid(sx * PW / 2 if sx > 0 else -hw, hw if sx > 0 else -PW / 2, -hd, hd, 1.1, GH, bat=(0.0,) * 4, mat="stone", tint=TINT["plain"], jit=0.03, seed=2 + sx)
    b.rect_solid(-PW / 2 - 0.05, PW / 2 + 0.05, -hd, hd, SP + PW * 0.87 + 0.2, GH, mat="stone", tint=TINT["plain"], jit=0.03, seed=4)
    for zf in (hd, -hd):
        sg = 1 if zf > 0 else -1
        b.arch(0.0, SP, PW, 0.5, min(zf, zf + sg * 0.15), max(zf - sg * 0.5, zf + sg * 0.15), "stone", uv=1.5, n=8, tint=TINT["pale"], seed=6 + sg, jit=0.008, alt=0.06)
        left = []
        for i in range(9):
            th = math.pi - (math.pi / 3.0) * i / 8
            left.append((PW / 2 + PW * math.cos(th), SP + PW * math.sin(th)))
        for i in range(8):
            xa, ya = left[i]
            xb, yb = left[i + 1]
            for sx in (-1, 1):
                pts = [(sx * xa, ya), (sx * xa, SP + PW * 0.87 + 0.25), (sx * xb, SP + PW * 0.87 + 0.25), (sx * xb, yb)]
                if sx < 0:
                    pts = list(reversed(pts))
                b.poly_z(pts, min(zf, zf - sg * 0.6), max(zf, zf - sg * 0.6), "stone", uv=1.0)
    b.box((0.0, SP + PW * 0.87 + 0.1, 0.0), (PW + 0.2, 0.3, GD - 0.4), "stone", uv=1.2, tint=TINT["dark"], cuts=1, jit=0.0)
    # string course, quoins, slit windows in the room over the arch, a window on each face
    b.rect_solid(-hw - 0.15, hw + 0.15, -hd - 0.15, hd + 0.15, 5.6, 5.9, mat="stone", uv=1.4, tint=TINT["pale"], jit=0.01, seed=8)
    for zf, sg in ((hd, 1), (-hd, -1)):
        b.window(0.0, 8.0, zf, w=1.1, h=1.3, face=sg, lit=sg > 0, shutters=False, frame="stone")
        for x in (-hw + 1.6, hw - 1.6):
            b.box((x, 3.0, zf + sg * 0.02), (0.16, 1.4, 0.1), "dark", cuts=0, jit=0.0)
    # the leaves swung open into the town (+z), against the passage's inner sides
    for sx in (-1, 1):
        b.box((sx * (PW / 2 - 0.12), 2.4, hd + 1.15), (0.14, 4.4, 2.4), "plank", cuts=0, jit=0.0)
        for yy in (0.9, 2.4, 3.9):
            b.box((sx * (PW / 2 - 0.2), yy, hd + 1.15), (0.04, 0.12, 2.2), "iron", cuts=0, jit=0.0)
    # lamp brackets either side of the outer arch (the game hangs lamps there)
    for sx in (-1, 1):
        b.box((sx * (PW / 2 + 1.0), 4.4, -hd - 0.35), (0.08, 0.08, 0.7), "iron", cuts=0, jit=0.0)
    RL.DATA["road_gate"] = {"brackets": [[-(PW / 2 + 1.0), 4.2, -hd - 0.65], [PW / 2 + 1.0, 4.2, -hd - 0.65]], "passage": [PW, SP]}
    # the roof: a steep slate gable along the wall, a dormer-louvre, a stack
    b.gable(-hw - 0.2, hw + 0.2, hd, GH, GH + 5.2, mat="slate", over=0.5, thick=0.3, sag=0.06, seed=9, barge=True)
    for sx in (-1, 1):
        x0, x1 = (hw - 0.6, hw) if sx > 0 else (-hw, -hw + 0.6)
        b.prism_x([(-hd, GH), (0.0, GH + 5.2), (hd, GH)], x0, x1, "stone", uv=1.0, jit=0.03, seed=10 + sx, dens=1.2, xstep=0.6)
    b.chimney(hw - 1.6, -1.0, GH + 2.0, GH + 6.2, w=0.9, d=0.8, pots=1)
    for sx in (-1, 1):
        b.colbox((sx * (PW / 2 + (hw - PW / 2) / 2), GH / 2, 0.0), (hw - PW / 2, GH, GD))
    b.colbox((0.0, (SP + PW * 0.87 + GH) / 2 + 0.2, 0.0), (PW + 0.2, GH - SP - PW * 0.87, GD))
    b.colbox((0.0, GH + 2.0, 0.0), (GW, 4.0, GD * 0.6))
    return b.finish()


def lamp_tower():
    b = T("LL_LampTower", seed=10501, damp=1.0)
    n = 8
    H = 20.0
    lathe_at(b, 0.0, 0.0, -1.8, [(5.0, 0.0), (4.7, 2.6), (4.25, 3.5)], "stone", sides=n, jit=0.0, seed=1)
    b.frustum(0.0, 0.0, 4.25 / math.cos(math.pi / n), 3.6 / math.cos(math.pi / n), 1.6, H, "stone", round_n=n, levels=12, jit=0.02, seed=2)
    # four battered buttresses on the diagonals, stepping in twice (the tower stands on the yard like a keep)
    for i in range(4):
        a = math.pi / 4 + i * math.pi / 2
        def butt():
            for (y0, y1, dep, wd) in ((-1.2, 2.6, 1.9, 1.5), (2.6, 5.4, 1.2, 1.2), (5.4, 7.6, 0.6, 0.9)):
                b.rect_solid(-wd / 2, wd / 2, 0.0, dep, y0, y1, bat=(0.05, 0.05, 0.0, 0.35), mat="stone", tint=TINT["plain"], jit=0.02, seed=60 + i)
                b.box((0.0, y1 + 0.1, dep - 0.25), (wd + 0.08, 0.18, 0.6), "stone", pitch=-0.6, uv=1.4, tint=TINT["pale"], cuts=0, jit=0.006)
        grouped(b, butt, a, (math.sin(a) * 3.9, 0.0, math.cos(a) * 3.9))
    for yy in (6.2, 11.4, 16.2):
        r = lerp(4.25, 3.6, (yy - 1.6) / (H - 1.6)) / math.cos(math.pi / n) + 0.15
        b.frustum(0.0, 0.0, r, r - 0.02, yy, yy + 0.32, "stone", round_n=n, levels=2, jit=0.006, tint=TINT["pale"])
    # angle shafts at the corners (the octagon's edges dressed in ashlar of another tone)
    for i in range(n):
        a = math.tau * i / n
        for k in range(14):
            y = 1.6 + k * (H - 1.6) / 14
            r = lerp(4.25, 3.6, (y - 1.6) / (H - 1.6)) / math.cos(math.pi / n)
            b.box((math.cos(a) * (r - 0.12), y + 0.6, math.sin(a) * (r - 0.12)), (0.62 if k % 2 else 0.44, 1.2, 0.44 if k % 2 else 0.62), "stone", yaw=-a, uv=1.5, tint=TINT["pale"], cuts=0, jit=0.01)
    # slit windows climbing round with the stair; a door on the town side (+z)
    for k in range(9):
        a = 0.5 + k * 0.95
        y = 3.5 + k * 1.75
        r = lerp(4.25, 3.6, (y - 1.6) / (H - 1.6)) - 0.02
        b.box((math.cos(a) * r, y, math.sin(a) * r), (0.18, 1.3, 0.3), "dark", yaw=-a + math.pi / 2, cuts=0, jit=0.0)
    b.door(0.0, 4.2, w=1.6, h=2.9, face=1, step=0.5, frame="stone", studs=True)
    # the gallery: a ring of corbels, a slab, an iron rail
    for i in range(16):
        a = math.tau * i / 16
        for (ya, yb, pr) in ((0.0, 0.32, 0.25), (0.32, 0.64, 0.45), (0.64, 0.95, 0.68)):
            rr = 3.55 + pr / 2
            b.box((math.cos(a) * rr, H - 0.95 + (ya + yb) / 2, math.sin(a) * rr), (0.5, yb - ya, pr), "stone", yaw=-a + math.pi / 2, uv=1.5, tint=TINT["pale"], cuts=0, jit=0.008)
    b.frustum(0.0, 0.0, 4.45, 4.45, H, H + 0.4, "stone", round_n=16, levels=2, jit=0.006, tint=TINT["pale"], seed=3)
    for k in range(24):
        a = math.tau * k / 24
        b.tube((math.cos(a) * 4.3, H + 0.4, math.sin(a) * 4.3), (math.cos(a) * 4.3, H + 1.5, math.sin(a) * 4.3), 0.035, 0.035, "iron", sides=4, bark=1.0, cap=False)
    b.frustum(0.0, 0.0, 4.33, 4.33, H + 1.45, H + 1.55, "iron", round_n=24, levels=2, jit=0.0)
    # the lantern room: a stone sill ring, eight iron posts, the glass, a cap of lead with a ball and a vane
    LY = H + 0.4
    LH = 3.6
    b.frustum(0.0, 0.0, 2.6, 2.6, LY, LY + 0.6, "stone", round_n=8, levels=2, jit=0.006, tint=TINT["plain"], seed=4)
    b.frustum(0.0, 0.0, 2.15, 2.15, LY + 0.6, LY + 0.6 + LH, "lamp_glass", round_n=8, levels=2, jit=0.0)
    for k in range(8):
        a = math.tau * (k + 0.5) / 8
        b.tube((math.cos(a) * 2.3, LY + 0.6, math.sin(a) * 2.3), (math.cos(a) * 2.3, LY + 0.6 + LH, math.sin(a) * 2.3), 0.09, 0.09, "iron", sides=5, bark=1.0, cap=False)
    for yy in (LY + 0.6 + LH * 0.5,):
        b.frustum(0.0, 0.0, 2.32, 2.32, yy - 0.04, yy + 0.04, "iron", round_n=8, levels=2, jit=0.0)
    b.frustum(0.0, 0.0, 0.3, 0.12, LY + 1.0, LY + 2.6, "lamp_glass", round_n=6, levels=2, jit=0.0)
    b.frustum(0.0, 0.0, 2.75, 2.65, LY + 0.6 + LH, LY + 0.9 + LH, "iron", round_n=8, levels=2, jit=0.0)
    b.frustum(0.0, 0.0, 2.6, 0.25, LY + 0.9 + LH, LY + 3.2 + LH, "iron", round_n=8, levels=3, jit=0.0)
    lathe_at(b, 0.0, 0.0, LY + 3.15 + LH, [(0.05, 0.0), (0.28, 0.25), (0.05, 0.5)], "iron", sides=8)
    b.tube((0.0, LY + 3.6 + LH, 0.0), (0.0, LY + 5.0 + LH, 0.0), 0.04, 0.02, "iron", sides=4, bark=1.0)
    b.box((0.25, LY + 4.6 + LH, 0.0), (0.7, 0.18, 0.02), "iron", cuts=0, jit=0.0)
    # the stair turret against the east face, its own little cone
    tx, tz = 3.7, -1.5
    b.frustum(tx, tz, 1.5, 1.35, -1.0, H - 2.0, "stone", round_n=10, levels=8, jit=0.02, seed=5)
    b.frustum(tx, tz, 1.9, 0.1, H - 2.1, H + 1.0, "slate", round_n=10, levels=3, jit=0.0, seed=6)
    for k in range(5):
        y = 3.0 + k * 3.3
        b.box((tx + 1.42, y, tz), (0.3, 0.9, 0.16), "dark", cuts=0, jit=0.0)
    RL.DATA["lamp_tower"] = {"lantern": [0.0, LY + 0.6 + LH * 0.5, 0.0], "door": [0.0, 5.4], "gallery": H + 0.4}
    b.colbox((0.0, H / 2, 0.0), (8.6, H + 1.0, 8.6))
    b.colbox((tx, H / 2 - 1.0, tz), (3.0, H - 2.0, 3.0))
    b.colbox((0.0, H + 3.0, 0.0), (5.2, 5.2, 5.2))
    return b.finish()


def inn():
    b = T("LL_Inn", seed=10601, damp=1.0)
    Ln, D = 20.0, 11.0
    hl, hd = Ln / 2, D / 2
    G = 4.2                       # the stone storey
    J = 0.6                       # the jetty
    U = 8.0                       # the wall plate
    R = 14.6                      # the ridge
    b.rect_solid(-hl - 0.3, hl + 0.3, -hd - 0.3, hd + 0.3, -1.6, 0.5, bat=(0.15,) * 4, mat="stone", tint=TINT["damp"], jit=0.03, seed=1)
    b.rect_solid(-hl, hl, -hd, hd, 0.45, G, mat="stone", tint=TINT["plain"], jit=0.03, seed=2)
    b.rect_solid(-hl - 0.1, hl + 0.1, -hd - 0.1, hd + 0.1, G - 0.25, G + 0.05, mat="stone", uv=1.4, tint=TINT["pale"], jit=0.01, seed=3)
    # the jettied storey: joist ends, a bressumer, plaster in close studding
    for k in range(21):
        x = -hl + Ln * k / 20
        for sz in (-1, 1):
            b.box((x, G + 0.12, sz * (hd + J * 0.5)), (0.22, 0.24, J + 0.3), "beam", cuts=0, jit=0.01)
    for sz in (-1, 1):
        b.box((0.0, G + 0.34, sz * (hd + J)), (Ln + 0.4, 0.3, 0.26), "beam", cuts=2, jit=0.01)
    b.rect_solid(-hl, hl, -hd - J, hd + J, G + 0.4, U, mat="plaster", jit=0.015, seed=4)
    for sz in (-1, 1):
        b.frame_face(-hl + 0.1, hl - 0.1, sz * (hd + J), G + 0.4, U, face=sz, bays=12, rails=(0.32,), braces=True)
    for sx in (-1, 1):
        b.frame_side(-hd - J + 0.1, hd + J - 0.1, sx * hl, G + 0.4, U, face=sx, bays=5, rails=(0.32,))
    # ground floor: a wide door under the porch, windows lit (the common room), a cellar flap
    b.door(-2.0, hd, w=2.0, h=3.0, face=1, step=0.45, frame="stone", arch=True, ajar=0.4)
    for x in (-7.4, -4.6, 1.6, 4.4, 7.4):
        b.window(x, 2.25, hd, w=1.4, h=1.6, face=1, lit=x != 7.4, frame="stone", shutters=x in (-7.4, 7.4))
    for x in (-6.0, 0.0, 6.0):
        b.window(x, 2.25, -hd, w=1.2, h=1.4, face=-1, lit=x == 0.0, frame="stone", shutters=False)
    b.box((5.8, 0.55, hd + 0.6), (1.6, 0.18, 1.1), "plank", pitch=0.3, cuts=0, jit=0.0)
    # the upper floor's windows (lit rooms, some dark)
    for x in (-8.0, -4.8, -1.6, 1.6, 4.8, 8.0):
        b.window(x, 6.2, hd + J, w=1.0, h=1.2, face=1, lit=x in (-4.8, 1.6, 8.0), frame="beam", sill="beam", mull=True)
    for x in (-5.0, 3.0):
        b.window(x, 6.2, -hd - J, w=1.0, h=1.2, face=-1, lit=x == 3.0, frame="beam", sill="beam", mull=False, shutters=False)
    # the roof: steep slate, gables of plaster and timber; three dormers on the front; stacks at both ends
    b.gable(-hl - 0.4, hl + 0.4, hd + J, U, R, mat="slate", over=0.55, thick=0.34, sag=0.14, seed=5, barge=True)
    for sx in (-1, 1):
        x0, x1 = (hl - 0.4, hl) if sx > 0 else (-hl, -hl + 0.4)
        b.prism_x([(-hd - J, U - 0.02), (0.0, R), (hd + J, U - 0.02)], x0, x1, "plaster", uv=1.0, jit=0.015, seed=6 + sx, dens=1.2, xstep=0.4)
        def gf(sx=sx):
            b.beam((0.0, U, 0.15), (0.0, R - 0.3, 0.15), 0.24, 0.16, "beam")
            for k in (-1, 1):
                b.beam((k * (hd + J - 0.2), U + 0.1, 0.15), (0.0, R - 0.3, 0.15), 0.2, 0.16, "beam")
                b.beam((k * 1.6, U + 0.1, 0.15), (k * 1.6, U + 3.1, 0.15), 0.16, 0.14, "beam")
            b.window(0.0, U + 1.8, 0.1, w=0.9, h=1.0, face=1, lit=sx > 0, frame="beam", sill="beam", mull=False, shutters=False)
        grouped(b, gf, sx * math.pi / 2, (sx * hl, 0.0, 0.0))
    for dx in (-6.0, 0.0, 6.0):
        b.dormer(dx, hd + J - 0.2, U - 0.15, w=2.1, wall_h=1.9, rise=1.2, depth=3.2, roof="slate", lit=dx != 0.0, seed=7 + int(dx))
    for sx in (-1, 1):
        cx = sx * (hl - 1.5)
        b.rect_solid(cx - 0.6, cx + 0.6, -1.4, -0.2, U + 2.0, R + 2.4, bat=(0.04,) * 4, mat="stone", jit=0.02, seed=8 + sx)
        b.rect_solid(cx - 0.72, cx + 0.72, -1.52, -0.08, R + 2.4, R + 2.62, mat="stone", uv=1.4, tint=TINT["pale"], jit=0.01)
        for pz in (-1.1, -0.5):
            b.frustum(cx, pz, 0.17, 0.13, R + 2.62, R + 3.2, "stone", round_n=7, levels=2, jit=0.0, tint=TINT["warm"])
            b.frustum(cx, pz, 0.1, 0.1, R + 3.19, R + 3.21, "dark", round_n=7, levels=2, jit=0.0)
    # the porch: timber posts on stone pads, a slate gable, the sign hung from a bracket
    def porch():
        for sx in (-1, 1):
            b.box((sx * 1.6, 0.25, 2.4), (0.5, 0.5, 0.5), "stone", cuts=0, jit=0.01)
            b.log((sx * 1.6, 0.5, 2.4), (sx * 1.6, 3.3, 2.4), 0.15, 0.13, "beam", seed=20 + sx, crook=0.02)
            b.beam((sx * 1.6, 2.6, 2.4), (sx * 0.7, 3.35, 2.4), 0.14, 0.14, "beam")
        b.beam((-1.9, 3.35, 2.4), (1.9, 3.35, 2.4), 0.22, 0.26, "beam")
        def pr():
            b.gable(-0.1, 2.9, 1.95, 3.4, 4.8, mat="slate", over=0.3, thick=0.22, sag=0.03, seed=21, barge=True)
        grouped(b, pr, -math.pi / 2, (0.0, 0.0, 0.0))
        for sx in (-1, 1):
            b.box((sx * 1.2, 0.5, 1.2), (1.6, 0.12, 0.45), "plank", yaw=math.pi / 2, cuts=0, jit=0.0)
            b.box((sx * 1.2, 0.25, 1.2), (0.12, 0.5, 0.4), "plank", yaw=math.pi / 2, cuts=0, jit=0.0)
    grouped(b, porch, 0.0, (-2.0, 0.0, hd))
    SX, SZ = 1.9, hd + 1.4
    b.beam((SX, 3.6, hd + 0.05), (SX, 3.6, SZ + 0.6), 0.12, 0.12, "beam")
    b.beam((SX, 2.9, hd + 0.05), (SX, 3.55, SZ - 0.3), 0.08, 0.08, "beam")
    for k in (-1, 1):
        b.tube((SX, 3.55, SZ + 0.2 + k * 0.45), (SX, 3.25, SZ + 0.2 + k * 0.45), 0.012, 0.012, "iron", sides=3, bark=1.0, cap=False)
    b.box((SX, 2.7, SZ + 0.2), (0.08, 1.1, 1.3), "plank", cuts=0, jit=0.0)
    lathe_at(b, SX + 0.06, SZ + 0.2, 2.4, [(0.05, 0.0), (0.18, 0.15), (0.2, 0.4), (0.14, 0.6), (0.04, 0.7)], "lamp_glass", sides=8)
    lathe_at(b, SX - 0.06, SZ + 0.2, 2.4, [(0.05, 0.0), (0.18, 0.15), (0.2, 0.4), (0.14, 0.6), (0.04, 0.7)], "lamp_glass", sides=8)
    RL.DATA["inn"] = {"door": [-2.0, hd + 2.8], "sign": [SX, 2.7, SZ + 0.2], "half": [hl, hd]}
    # the kitchen outshot behind, its own stack and a back door
    OZ = -hd - 4.0
    b.rect_solid(2.0, 9.0, OZ, -hd, 0.45, 3.4, mat="stone", tint=TINT["plain"], jit=0.03, seed=30)
    b.rect_solid(1.8, 9.2, OZ - 0.3, -hd + 0.1, -1.4, 0.5, mat="stone", tint=TINT["damp"], jit=0.03, seed=31)
    def kroof():
        b.gable(-3.7, 3.7, 2.0, 3.4, 5.6, mat="slate", over=0.4, thick=0.25, sag=0.04, seed=32, barge=True)
    grouped(b, kroof, 0.0, (5.5, 0.0, OZ + 2.0))
    b.chimney(8.2, OZ + 2.0, 3.0, 7.6, w=0.9, d=0.8, pots=2)
    b.door(4.0, OZ, w=1.3, h=2.4, face=-1, step=0.45, frame="stone", studs=False)
    b.window(6.6, 1.9, OZ, w=1.0, h=1.0, face=-1, lit=True, frame="stone", shutters=False, mull=False)
    # collision
    b.colbox((0.0, (U - 1.0) / 2, 0.0), (Ln + 0.4, U + 1.0, D + 2 * J + 0.3))
    b.colbox((0.0, (U + R) / 2, 0.0), (Ln, R - U, D * 0.6))
    b.colbox((5.5, 1.7, OZ + 2.0), (7.2, 3.4, 4.2))
    for sx in (-1, 1):
        b.colbox((-2.0 + sx * 1.6, 1.6, hd + 2.4), (0.4, 3.2, 0.4))
    return b.finish()


def stable():
    b = T("LL_Stable", seed=10701, damp=1.0)
    Ln, D = 18.0, 8.0
    hl, hd = Ln / 2, D / 2
    E, R = 4.0, 8.6
    b.rect_solid(-hl - 0.3, hl + 0.3, -hd - 0.3, hd + 0.3, -1.4, 0.35, mat="stone", tint=TINT["damp"], jit=0.03, seed=1)
    b.rect_solid(-hl, hl, -hd, -hd + 0.8, 0.3, E, mat="rubble", jit=0.03, seed=2)
    for sx in (-1, 1):
        x0, x1 = (hl - 0.8, hl) if sx > 0 else (-hl, -hl + 0.8)
        b.rect_solid(x0, x1, -hd, hd, 0.3, E, mat="rubble", jit=0.03, seed=3 + sx)
        b.prism_x([(-hd, E), (0.0, R), (hd, E)], x0, x1, "rubble", uv=1.0, jit=0.03, seed=5 + sx, dens=1.2, xstep=0.8)
    # the open front: posts on stone pads, a plate, braces, stall partitions and half-doors
    nb = 6
    for k in range(nb + 1):
        x = -hl + 0.8 + (Ln - 1.6) * k / nb
        b.box((x, 0.3, hd - 0.2), (0.45, 0.4, 0.45), "stone", cuts=0, jit=0.01)
        b.log((x, 0.4, hd - 0.2), (x, E, hd - 0.2), 0.16, 0.14, "beam", seed=10 + k, crook=0.02)
        if 0 < k < nb:
            for sg in (-1, 1):
                b.beam((x, E - 0.9, hd - 0.2), (x + sg * 0.9, E - 0.1, hd - 0.2), 0.12, 0.12, "beam")
            b.box((x, 1.2, 0.0), (0.14, 1.8, D - 1.4), "plank", cuts=1, jit=0.0)
    b.beam((-hl, E - 0.05, hd - 0.2), (hl, E - 0.05, hd - 0.2), 0.24, 0.3, "beam")
    for k in range(nb):
        x = -hl + 0.8 + (Ln - 1.6) * (k + 0.5) / nb
        if k % 3 == 1:
            continue
        a = 0.0 if k % 2 == 0 else 1.2
        b.box((x - 0.62 + math.cos(a) * 0.62, 0.95, hd - 0.2 + math.sin(a) * 0.62), (1.24, 1.3, 0.08), "plank", yaw=-a, cuts=0, jit=0.0)
    # inside: a back rail with hay racks, a dark rear
    b.box((0.0, 2.0, -hd + 0.85), (Ln - 1.6, 2.4, 0.06), "dark", cuts=0, jit=0.0)
    b.box((0.0, 1.9, -hd + 1.1), (Ln - 1.8, 0.12, 0.5), "beam", cuts=2, jit=0.0)
    for k in range(18):
        b.box((-hl + 1.2 + k * 0.92, 1.7, -hd + 1.1), (0.05, 0.45, 0.05), "beam", cuts=0, jit=0.0)
    # the loft floor and its hay, a loft door in the east gable with a hoist beam
    b.box((0.0, E + 0.05, -0.2), (Ln - 1.6, 0.16, D - 1.0), "plank", cuts=2, jit=0.0)
    for i in range(12):
        x = -hl + 1.6 + i * 1.3
        b.box((x, E + 0.55, -0.6 + (i % 2) * 0.5), (1.2, 0.7, 1.6), "hay", yaw=(i % 3) * 0.2, cuts=1, jit=0.04)
    def loft():
        b.box((0.0, E + 1.4, 0.06), (1.6, 1.8, 0.1), "dark", cuts=0, jit=0.0)
        b.box((0.0, E + 2.4, 0.08), (1.9, 0.2, 0.2), "beam", cuts=0, jit=0.0)
        b.beam((0.0, E + 2.9, -0.2), (0.0, E + 2.9, 1.4), 0.2, 0.22, "beam")
        b.box((0.0, E + 2.55, 1.25), (0.06, 0.5, 0.06), "iron", cuts=0, jit=0.0)
    grouped(b, loft, math.pi / 2, (hl, 0.0, 0.0))
    b.gable(-hl - 0.1, hl + 0.1, hd, E, R, mat="slate", over=0.8, thick=0.3, sag=0.12, seed=20, barge=False)
    # a trough before it, a mounting block
    b.box((4.0, 0.4, hd + 1.4), (2.6, 0.7, 0.7), "plank", cuts=1, jit=0.0)
    b.box((4.0, 0.72, hd + 1.4), (2.4, 0.04, 0.5), "dark", cuts=0, jit=0.0)
    b.box((-6.5, 0.35, hd + 1.2), (1.0, 0.7, 0.9), "stone", cuts=0, jit=0.02)
    RL.DATA["stable"] = {"front": hd + 1.0, "stalls": [-hl + 0.8 + (Ln - 1.6) * (k + 0.5) / nb for k in range(nb)]}
    b.colbox((0.0, E / 2, -hd + 0.4), (Ln, E, 0.8))
    for sx in (-1, 1):
        b.colbox((sx * (hl - 0.4), E / 2, 0.0), (0.8, E, D))
    b.colbox((0.0, (E + R) / 2 + 0.3, 0.0), (Ln, R - E, D * 0.65))
    b.colbox((4.0, 0.4, hd + 1.4), (2.6, 0.8, 0.7))
    return b.finish()


def watch():
    b = T("LL_Watch", seed=10801, damp=1.0)
    Ln, D, E = 10.0, 7.0, 4.2
    hl, hd = Ln / 2, D / 2
    b.rect_solid(-hl - 0.3, hl + 0.3, -hd - 0.3, hd + 0.3, -1.4, 0.45, mat="stone", tint=TINT["damp"], jit=0.03, seed=1)
    b.rect_solid(-hl, hl, -hd, hd, 0.4, E, mat="stone", tint=TINT["plain"], jit=0.03, seed=2)
    b.door(-1.5, hd, w=1.6, h=2.8, face=1, step=0.4, frame="stone", studs=True)
    b.window(2.4, 2.4, hd, w=1.0, h=1.2, face=1, lit=True, frame="stone", shutters=False)
    b.hip(0.0, 0.0, hl + 0.7, hd + 0.7, E, E + 4.0, mat="slate", ridge_k=0.5, lip=0.25, seed=3)
    b.chimney(-2.6, -1.0, E + 1.5, E + 4.4, w=0.9, d=0.8, pots=1)
    # the weapons rack on the wall: spears and a shield
    for k in range(4):
        b.log((3.0 + k * 0.32, 0.6, hd + 0.25), (3.05 + k * 0.32, 3.4, hd + 0.3), 0.03, 0.025, "beam", sides=4, crook=0.0)
        b.frustum(3.05 + k * 0.32, hd + 0.3, 0.05, 0.005, 3.4, 3.75, "iron", round_n=4, levels=2, jit=0.0)
    b.box((3.5, 1.6, hd + 0.2), (1.5, 0.1, 0.25), "beam", cuts=0, jit=0.0)
    # the watch platform beside it: four raking legs, braces, a deck at 8 m, a roof, a brazier basket, a ladder
    PX, PZ, PH = hl + 2.6, 0.0, 8.0
    for sx in (-1, 1):
        for sz in (-1, 1):
            b.log((PX + sx * 2.0, -0.5, PZ + sz * 2.0), (PX + sx * 1.4, PH + 2.8, PZ + sz * 1.4), 0.2, 0.15, "beam", sides=7, seed=40 + sx + sz * 3, crook=0.02)
    for yy in (2.4, 5.2):
        f = 1.0 - (yy / (PH + 2.8)) * 0.3
        pts = [(PX - 1.9 * f, PZ - 1.9 * f), (PX + 1.9 * f, PZ - 1.9 * f), (PX + 1.9 * f, PZ + 1.9 * f), (PX - 1.9 * f, PZ + 1.9 * f)]
        for i in range(4):
            a, c = pts[i], pts[(i + 1) % 4]
            b.beam((a[0], yy, a[1]), (c[0], yy + 0.6, c[1]), 0.12, 0.14, "beam")
    b.box((PX, PH, PZ), (3.8, 0.24, 3.8), "plank", cuts=2, jit=0.0)
    for (a, c) in (((-1.75, -1.75), (1.75, -1.75)), ((1.75, -1.75), (1.75, 1.75)), ((1.75, 1.75), (-1.75, 1.75))):
        b.box((PX + (a[0] + c[0]) / 2, PH + 0.55, PZ + (a[1] + c[1]) / 2), (abs(c[0] - a[0]) + 0.12, 0.9, abs(c[1] - a[1]) + 0.12), "plank", cuts=1, jit=0.0)
    def proof():
        b.gable(-2.2, 2.2, 2.0, PH + 2.8, PH + 4.2, mat="slate", over=0.3, thick=0.2, sag=0.02, seed=41, barge=True)
    grouped(b, proof, 0.0, (PX, 0.0, PZ))
    b.tube((PX - 1.0, PH + 0.1, PZ + 1.0), (PX - 1.0, PH + 1.3, PZ + 1.0), 0.05, 0.04, "iron", sides=5, bark=1.0)
    b.frustum(PX - 1.0, PZ + 1.0, 0.45, 0.32, PH + 1.3, PH + 1.9, "iron", round_n=8, levels=2, jit=0.0)
    lathe_at(b, PX - 1.0, PZ + 1.0, PH + 1.35, [(0.3, 0.0), (0.25, 0.35)], "dark", sides=8)
    for sx in (-1, 1):
        b.log((PX + sx * 0.3, 0.0, PZ - 2.5), (PX + sx * 0.3, PH, PZ - 1.95), 0.06, 0.06, "beam", sides=5, crook=0.0)
    for k in range(14):
        y = 0.45 + k * 0.55
        b.beam((PX - 0.3, y, PZ - 2.5 + 0.55 * y / PH), (PX + 0.3, y, PZ - 2.5 + 0.55 * y / PH), 0.06, 0.06, "beam", jit=0.0)
    RL.DATA["watch"] = {"door": [-1.5, hd + 1.3], "post": [PX, PH, PZ], "brazier": [PX - 1.0, PH + 1.8, PZ + 1.0], "ladder": [PX, PZ - 2.9]}
    b.colbox((0.0, E / 2, 0.0), (Ln + 0.3, E + 0.4, D + 0.3))
    b.colbox((0.0, E + 1.5, 0.0), (Ln, 3.0, D * 0.6))
    for sx in (-1, 1):
        for sz in (-1, 1):
            b.colbox((PX + sx * 1.75, PH / 2, PZ + sz * 1.75), (0.4, PH, 0.4))
    b.colbox((PX, PH - 0.12, PZ), (3.8, 0.24, 3.8))
    return b.finish()


def store():
    b = T("LL_Store", seed=10901, damp=1.0)
    Ln, D, E, R = 7.2, 5.4, 4.6, 8.0
    hl, hd = Ln / 2, D / 2
    b.rect_solid(-hl - 0.25, hl + 0.25, -hd - 0.25, hd + 0.25, -1.4, 0.4, mat="stone", tint=TINT["damp"], jit=0.03, seed=1)
    b.rect_solid(-hl, hl, -hd, hd, 0.35, E, mat="rubble", jit=0.03, seed=2)
    for sx in (-1, 1):
        x0, x1 = (hl - 0.6, hl) if sx > 0 else (-hl, -hl + 0.6)
        b.prism_x([(-hd, E), (0.0, R), (hd, E)], x0, x1, "rubble", uv=1.0, jit=0.03, seed=3 + sx, dens=1.2, xstep=0.6)
    b.gable(-hl + 0.2, hl - 0.2, hd, E, R, mat="slate", over=0.45, thick=0.28, sag=0.06, seed=5, barge=False)
    b.door(0.0, hd, w=1.8, h=2.6, face=1, step=0.35, frame="stone", studs=True)
    b.box((0.0, E - 0.6, hd + 0.04), (1.3, 1.4, 0.08), "plank", cuts=0, jit=0.0)
    b.beam((0.0, E + 0.5, hd - 0.2), (0.0, E + 0.5, hd + 1.3), 0.2, 0.22, "beam")
    b.tube((0.0, E + 0.38, hd + 1.15), (0.0, 1.4, hd + 1.15), 0.015, 0.015, "rope", sides=3, bark=1.0, cap=False)
    b.box((0.0, 1.25, hd + 1.15), (0.18, 0.3, 0.18), "iron", cuts=0, jit=0.0)
    b.colbox((0.0, E / 2, 0.0), (Ln + 0.3, E + 0.4, D + 0.3))
    b.colbox((0.0, E + 1.5, 0.0), (Ln, 3.0, D * 0.6))
    return b.finish()


def shrine():
    b = T("LL_Shrine", seed=11001, damp=1.2)
    b.rect_solid(-0.9, 0.9, -0.5, 0.5, -0.8, 2.8, bat=(0.06,) * 4, mat="stone", tint=TINT["plain"], jit=0.02, seed=1)
    b.box((0.0, 1.55, 0.44), (0.6, 0.9, 0.16), "dark", cuts=0, jit=0.0)
    b.poly_z([(-0.3, 2.0), (0.3, 2.0), (0.0, 2.5)], 0.36, 0.52, "dark")
    b.arch(0.0, 2.0, 0.6, 0.16, 0.38, 0.6, "stone", uv=1.5, n=4, tint=TINT["pale"], jit=0.004)
    b.box((0.0, 1.0, 0.55), (1.2, 0.14, 0.4), "stone", cuts=0, jit=0.004, tint=TINT["pale"])
    for k in range(5):
        x = -0.32 + k * 0.16
        h = 0.08 + 0.1 * ((k * 3) % 4) / 4.0
        b.frustum(x, 0.45 + (k % 2) * 0.06, 0.035, 0.03, 1.07, 1.07 + h, "plaster", round_n=6, levels=2, jit=0.0)
        b.frustum(x, 0.45 + (k % 2) * 0.06, 0.06, 0.05, 1.07, 1.08, "plaster", round_n=6, levels=2, jit=0.0)
    b.gable(-1.1, 1.1, 0.6, 2.8, 3.5, mat="slate", over=0.25, thick=0.16, sag=0.0, seed=2, barge=False)
    b.box((0.0, 3.62, 0.0), (0.18, 0.42, 0.18), "stone", cuts=0, jit=0.004, tint=TINT["pale"])
    b.box((0.0, 0.12, 1.2), (1.6, 0.24, 0.7), "stone", cuts=0, jit=0.01, tint=TINT["damp"])
    RL.DATA["shrine"] = {"niche": [0.0, 1.2, 0.5], "kneel": [0.0, 1.9]}
    b.colbox((0.0, 1.4, 0.0), (1.9, 2.8, 1.1))
    return b.finish()


def fars():
    TW, TH, TD, GX = 8.0, 17.0, 8.6, 6.6
    return [far_piece("LL_GateFar", [("box", (-GX, TH / 2 - 0.5, 0), (TW + 0.6, TH + 1.0, TD + 0.6)), ("box", (GX, TH / 2 - 0.5, 0), (TW + 0.6, TH + 1.0, TD + 0.6)),
                                     ("box", (0, TH / 2 + 2.0, 0), (5.4, TH - 6.0, TD - 1.6))]),
            far_piece("LL_RoadGateFar", [("box", (0, 4.8, 0), (ROAD_GATE_W, 11.6, 8.0)), ("roof", -6.2, 6.2, 4.5, 10.6, 15.8, 0.0)]),
            far_piece("LL_WallFar", [("box", (0, WALL_H / 2, -0.15), (WALL_LEN, WALL_H + 1.0, 2.3)), ("box", (0, WALL_H + 1.4, WALL_OUT + 0.1), (WALL_LEN, 1.6, 0.9))]),
            far_piece("LL_TowerFar", [("drum", 0.0, 0.0, 4.6, 3.9, -0.5, 20.4, 8), ("drum", 0.0, 0.0, 2.4, 2.4, 20.4, 24.6, 8), ("drum", 0.0, 0.0, 2.6, 0.2, 24.6, 27.2, 8)]),
            far_piece("LL_InnFar", [("box", (0, 3.7, 0), (20.6, 8.4, 12.4)), ("roof", -10.4, 10.4, 6.6, 7.6, 14.6, 0.0)])]


def build():
    objs = [east_gate(), road_gate(), wall_piece(), wall_piece("LL_Postern", door=(0.0, 2.8, 2.6), seed=7), wall_tower(), lamp_tower(), inn(), stable(), watch(), store(), shrine()]
    return objs, fars()


VIEWS = {
    "LL_EastGate": ((0.0, 7.0, 0.0), 44.0), "LL_RoadGate": ((0.0, 6.0, 0.0), 32.0), "LL_Wall": ((0.0, 3.5, 0.0), 18.0),
    "LL_Postern": ((0.0, 3.5, 0.0), 18.0), "LL_WallTower": ((0.0, 7.0, 0.0), 28.0), "LL_LampTower": ((0.0, 13.0, 0.0), 52.0),
    "LL_Inn": ((0.0, 6.0, 0.0), 42.0), "LL_Stable": ((0.0, 3.5, 0.0), 30.0), "LL_Watch": ((3.0, 4.5, 0.0), 30.0),
    "LL_Store": ((0.0, 3.5, 0.0), 18.0), "LL_Shrine": ((0.0, 1.6, 0.0), 6.0),
}
