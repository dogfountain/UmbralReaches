"""The March Gatehouse (r37_wall.py build()): twin drum towers round a deep pointed passage.

Local frame: x along the wall, +z the outer (March) side, the origin on the ground at the middle of the passage.
  passage      5.6 m clear, pointed (two-centred) vault of voussoirs from the springing at y 3.4 to the crown at 8.25 m,
               z -4.1 (the Realm's side) .. +1.9; three ribs, a portcullis in its groove, both leaves of the gate swung
               back against the passage walls
  drums        r 3.6 round towers (centres x = +-6.4, z 0.6) with a rear block, battered plinths, loops, string courses,
               a corbelled parapet round their outline, a stair turret with a roof on each
  gate room    over the arch between the drums: a machicolated front (dense corbels), a crest, its own lower parapet
"""
import math
from mathutils import Vector
import r37_wall as RW
from r37_wall_lib import W, rng, lerp, clamp

PW = 5.6                      # clear width of the passage
SPRING = 3.4                  # the springing line
RISE = math.sqrt(PW * PW - (PW / 2) ** 2)
CROWN = SPRING + RISE         # the vault's crown (8.25)
ZB = -4.1                     # the Realm side face of the shafts (the plinth stands a little further out)
ZF = 1.9                      # the gate room's front face, between the drums
DC = 6.4                      # drum centre x
DZ = 0.6                      # drum centre z
DR = 3.6                      # drum radius at the top
SHAFT_TOP = 13.0              # the corbels start here
DECK = SHAFT_TOP + 1.2        # the towers' deck
ROOM0 = 11.6                  # the gate room's corbels start here
ROOM_WALK = ROOM0 + 1.2
T_PL = 2.6                    # plinth height


def drum_runs(s):
    """The outline of one tower's face line at the corbel base (the drum and the rear block), for the battlement."""
    x1 = s * (DC + DR)
    x0 = s * (DC - DR)
    runs = [("line", (x0, ZB), (x1, ZB)), ("line", (x1, ZB), (x1, DZ))]
    if s > 0:
        runs.append(("arc", (s * DC, DZ), DR, 0.0, math.pi))
    else:
        runs.append(("arc", (s * DC, DZ), DR, math.pi, 0.0))
    runs.append(("line", (x0, DZ), (x0, ZB)))
    return runs


def radial_loop(b, T, cx, cz, r, ang, y, h=1.3):
    """An arrow loop on a drum at angle ang (radians, x = cos, z = sin) and height y."""
    p = (cx + math.cos(ang) * (r + 0.02), y, cz + math.sin(ang) * (r + 0.02))
    yaw = math.pi / 2 - ang
    b.box(p, (0.15, h, 0.14), "dark", yaw=yaw, cuts=0)
    q = (cx + math.cos(ang) * (r + 0.05), y, cz + math.sin(ang) * (r + 0.05))
    b.box(q, (0.52, h + 0.55, 0.14), "stone", uv=1.6, tint=T["pale"], yaw=yaw, cuts=0, jit=0.008)
    q2 = (cx + math.cos(ang) * (r + 0.1), y, cz + math.sin(ang) * (r + 0.1))
    b.box(q2, (0.15, h, 0.07), "dark", yaw=yaw, cuts=0)


def quoin_column(b, T, x, z, sx, sz, y0, y1, seed):
    """A column of alternating long and short blocks at the corner (x, z); sx, sz point out of the corner."""
    n = int((y1 - y0) / 0.62)
    for i in range(n):
        y = y0 + 0.31 + i * 0.62
        long_x = i % 2 == 0
        lx, lz = (1.0, 0.5) if long_x else (0.5, 1.0)
        b.box((x - sx * (lx / 2 - 0.07), y, z - sz * (lz / 2 - 0.07)), (lx, 0.58, lz), "stone", uv=1.4, tint=T["pale"], jit=0.012, cuts=0)


def shield(b, T, cx, cy, z, seed):
    """The crest on the gate room's face: a heater shield, a rim, a roundel and a chevron."""
    pts = [(-0.55, 0.62), (0.55, 0.62), (0.55, 0.1), (0.42, -0.3), (0.15, -0.58), (0.0, -0.66), (-0.15, -0.58), (-0.42, -0.3), (-0.55, 0.1)]
    big = [(x * 1.14, y * 1.14 - 0.02) for x, y in pts]
    b.poly_z([(cx + x, cy + y) for x, y in big], z - 0.02, z + 0.16, "stone", uv=1.6, tint=T["pale"], jit=0.0)
    b.poly_z([(cx + x, cy + y) for x, y in pts], z + 0.14, z + 0.26, "stone", uv=1.2, tint=T["dark"], jit=0.0)
    ring = [(0.2 * math.cos(a), 0.2 * math.sin(a) + 0.2) for a in [math.tau * k / 10 for k in range(10)]]
    b.poly_z([(cx + x, cy + y) for x, y in ring], z + 0.24, z + 0.38, "stone", uv=1.6, tint=T["pale"], jit=0.0)
    for sgn in (-1, 1):
        b.box((cx + sgn * 0.2, cy - 0.28, z + 0.32), (0.09, 0.5, 0.1), "stone", uv=1.6, tint=T["pale"], roll=sgn * 0.5, cuts=0)


def gatehouse(mats, seed):
    T = RW.tints()
    b = W("Gatehouse", mats, seed)
    spring = SPRING
    w = PW
    # ---- the foundation
    for s in (-1, 1):
        b.box((s * 6.6, -2.1, -0.1), (8.0, 3.9, 9.2), "stone", uv=0.6, tint=T["damp"], cuts=3, jit=0.03)
    b.box((0, -2.1, -1.1), (6.8, 3.9, 6.4), "stone", uv=0.6, tint=T["damp"], cuts=2, jit=0.03)
    # ---- the two towers: a rear block (square, the Realm side) and a drum (round, the March side)
    for s in (-1, 1):
        x0, x1 = (DC - DR, DC + DR + 0.2)
        if s < 0:
            x0, x1 = -x1, -x0
        bat = (0.0, 0.2, 0.0, 0.0) if s > 0 else (0.2, 0.0, 0.0, 0.0)
        foot = (0.0, 0.7, 0.7, 0.0) if s > 0 else (0.7, 0.0, 0.7, 0.0)
        # plinth: coarse stone, battered
        b.rect_solid(x0, x1, ZB - 0.2, DZ, 0.0, T_PL, bat=(0.0, 0.5, 0.45, 0.0) if s > 0 else (0.5, 0.0, 0.45, 0.0), foot=(0.0, 0.5, 0.45, 0.0) if s > 0 else (0.5, 0.0, 0.45, 0.0), uv=0.6, tint=T["damp"], jit=0.05, seed=seed + s)
        # the shaft
        b.rect_solid(x0, x1 - 0.0, ZB - 0.2 + 0.0, DZ, T_PL, SHAFT_TOP, bat=(0.0, 0.2, 0.2, 0.0) if s > 0 else (0.2, 0.0, 0.2, 0.0), uv=1.0, tint=T["plain"], jit=0.04, seed=seed + 3 + s)
        # the drum: its passage side stays on x = 2.8 at every height (the ring's centre moves out as the plinth flares)
        r0, r1, r2 = 4.1, 3.75, 3.6
        b.frustum(s * (2.8 + r0), DZ, r0, r1, 0.0, T_PL, "stone", uv=0.6, tint=T["damp"], jit=0.05, seed=seed + 5 + s, round_n=22, levels=3, cx1=s * (2.8 + r1))
        b.frustum(s * (2.8 + 3.9), DZ, 3.9, 3.9, T_PL, T_PL + 0.3, "stone", uv=1.4, tint=T["pale"], jit=0.01, seed=seed + 6, round_n=22, levels=2)
        b.frustum(s * (2.8 + r1), DZ, r1, r2, T_PL + 0.3, SHAFT_TOP, "stone", uv=1.0, tint=T["plain"], jit=0.04, seed=seed + 7 + s, round_n=22, cx1=s * (2.8 + r2))
        # string courses on the drum
        for ys in (RW.WALK - 0.6, SHAFT_TOP - 0.7):
            rr = lerp(r1, r2, (ys - T_PL) / (SHAFT_TOP - T_PL))
            b.frustum(s * (2.8 + rr + 0.1), DZ, rr + 0.18, rr + 0.18, ys, ys + 0.3, "stone", uv=1.6, tint=T["pale"], jit=0.008, seed=seed + 8, round_n=22, levels=2)
        # quoins up the rear block's two outer corners
        xo = s * (DC + DR)
        quoin_column(b, T, xo + (-0.1 if s > 0 else 0.1), ZB - 0.02, s, -1, T_PL + 0.3, SHAFT_TOP - 0.3, seed)
        quoin_column(b, T, s * (DC - DR), ZB - 0.02, -s, -1, T_PL + 0.3, SHAFT_TOP - 0.3, seed)
        # the parapet: the whole outline, on corbels
        walk = b.battlement(drum_runs(s), SHAFT_TOP, (s * DC, DZ - 1.0), seed + 10 + s, tint=T["dark"], mer_tint=T["plain"], pitch=2.2)
        # the deck
        b.box((s * DC, walk - 0.1, ZB / 2 + DZ / 2), (7.0, 0.3, DZ - ZB - 0.6), "stone", uv=1.3, tint=T["plain"], cuts=2, jit=0.01)
        b.frustum(s * DC, DZ, DR - 0.2, DR - 0.2, walk - 0.25, walk + 0.05, "stone", uv=1.3, tint=T["plain"], jit=0.0, round_n=22, levels=2)
        # a stair turret in the rear outer corner, with a roof
        tx, tz = s * (DC + DR - 1.7), ZB + 1.7
        b.box((tx, walk + 1.7, tz), (2.6, 3.4, 2.6), "stone", uv=1.2, tint=T["plain"], cuts=2, jit=0.03)
        b.box((tx, walk + 3.6, tz), (3.0, 0.4, 3.0), "stone", uv=1.5, tint=T["pale"], jit=0.015)
        b.frustum(tx, tz, (1.7, 1.7), (0.1, 0.1), walk + 3.8, walk + 6.2, "wood", uv=1.0, tint=(0.85, 0.85, 0.88), jit=0.0, levels=2)
        b.box((tx, walk + 6.7, tz), (0.08, 1.0, 0.08), "iron")
        b.box((tx - s * 0.25, walk + 7.0, tz), (0.5, 0.3, 0.04), "iron")
        # loops
        for ang, lv in ((math.pi / 2, 4.7), (math.pi / 2 - 0.62, 8.4), (math.pi / 2 + 0.62, 8.4), (math.pi / 2, 11.3), (0.3, 5.8), (math.pi - 0.3, 5.8)):
            radial_loop(b, T, s * (2.8 + lerp(3.75, 3.6, (lv - T_PL) / (SHAFT_TOP - T_PL))), DZ, lerp(3.75, 3.6, (lv - T_PL) / (SHAFT_TOP - T_PL)), ang, lv)
        for lv in (4.7, 8.4, 11.3):                       # the Realm side face
            for dx in (4.9, 8.0):
                b.box((s * dx, lv, ZB - 0.17 + 0.0), (0.15, 1.3, 0.12), "dark", cuts=0)
                b.box((s * dx, lv, ZB - 0.15), (0.5, 1.85, 0.12), "stone", uv=1.6, tint=T["pale"], cuts=0, jit=0.008)
                b.box((s * dx, lv, ZB - 0.2), (0.15, 1.3, 0.06), "dark", cuts=0)
        # the walk's door in the outer side face (the curtain's walk comes to it), at the walk's height

        def door(s=s):
            RW.pointed_door(b, 0.0, RW.WALK, 1.5, 1.7, T, seed + 11, depth=0.5, steps=False)
        RW.grouped(b, door, math.atan2(s, 0.0), (s * 10.1, 0.0, -0.4))
    # ---- the passage: the vault from the springing, ribs, portcullis groove
    t = 0.5
    zr0, zr1 = ZB - 0.3, ZF            # the rings run through the whole depth
    groove = (-1.2, -0.7)
    b.arch(0.0, spring, w, t, zr0, groove[0], "stone", uv=1.3, n=7, tint=T["plain"], seed=seed + 20, alt=0.04)
    b.arch(0.0, spring, w, t, groove[1], zr1, "stone", uv=1.3, n=7, tint=T["plain"], seed=seed + 21, alt=0.04)
    # the groove: a dark slot behind its rim
    b.arch(0.0, spring, w + 0.25, t - 0.25, groove[0], groove[1], "dark", uv=1.0, n=5, jit=0.0, seed=seed + 22, span=w)
    # ribs
    for rz in (-3.2, -2.0, 0.5):
        b.arch(0.0, spring, w - 0.22, 0.22, rz - 0.17, rz + 0.17, "stone", uv=1.6, n=5, tint=T["pale"], seed=seed + 30, jit=0.006, span=w)
    # the arch faces: a moulded archivolt ring proud of the face, and a keystone
    for (zc, dirn) in ((ZF, 1.0), (ZB, -1.0)):
        za, zb = (zc - 0.05, zc + 0.16) if dirn > 0 else (zc - 0.16, zc + 0.05)
        b.arch(0.0, spring, w + 0.5, 0.42, za, zb, "stone", uv=1.6, n=8, tint=T["pale"], seed=seed + 40, jit=0.008, span=w)
        # the crown stone, taller than the ring
        zk0, zk1 = (zc - 0.05, zc + 0.26) if dirn > 0 else (zc - 0.26, zc + 0.05)
        cy = CROWN + 0.5 + 0.1
        b.poly_z([(0.0, CROWN + 0.55), (0.28, CROWN + 0.95), (0.22, CROWN + 1.55), (-0.22, CROWN + 1.55), (-0.28, CROWN + 0.95)], zk0, zk1, "stone", uv=1.6, tint=T["pale"], jit=0.0)
        # springers: a moulded impost under each side of the arch
        for sx in (-1, 1):
            b.box((sx * (w / 2 + 0.12), spring - 0.12, zc + dirn * 0.06), (0.8, 0.24, 0.46 + 0.0), "stone", uv=1.6, tint=T["pale"], jit=0.008, cuts=0)
    # the spandrels and the gate room's body: from the extrados up to the room's walk, full depth
    th_end = math.acos(-(w / 2) / (w + t))
    n = 7
    ex = []
    for i in range(n + 1):
        th = math.pi - (math.pi - th_end) * i / n
        ex.append((w / 2 + (w + t) * math.cos(th), spring + (w + t) * math.sin(th)))   # left half, springer to crown
    TOPY = ROOM_WALK
    xl = -3.4
    left = [(xl, spring), (ex[0][0], spring)] + ex[1:] + [(0.0, ex[-1][1]), (0.0, TOPY), (xl, TOPY)]
    right = [(-x, y) for (x, y) in reversed(left)]
    b.poly_z(left, ZB, ZF, "stone", uv=1.0, tint=T["plain"], jit=0.0, seed=seed)
    b.poly_z(right, ZB, ZF, "stone", uv=1.0, tint=T["plain"], jit=0.0, seed=seed)
    # the plain piers up to the springing between the drums' faces and the passage (the passage walls, a face on the front)
    for s in (-1, 1):
        b.box((s * 3.1, spring / 2, (ZF + DZ) / 2), (0.7, spring, ZF - DZ), "stone", uv=1.0, tint=T["plain"], cuts=1, jit=0.01)
    # the gate room's front: dense machicolation corbels and its parapet; the Realm side a plain parapet
    csteps = ((0.0, 0.4, 0.3), (0.4, 0.8, 0.62), (0.8, 1.2, 0.9))
    b.battlement([("line", (-3.0, ZF), (3.0, ZF))], ROOM0 - 0.2, (0, -2), seed + 50, tint=T["dark"], mer_tint=T["plain"], oversail=0.9, csteps=csteps, cspace=0.9, pitch=1.8)
    b.battlement([("line", (-2.8, ZB), (2.8, ZB))], ROOM0, (0, 0), seed + 51, tint=T["dark"], mer_tint=T["plain"], pitch=2.0)
    # a string course under the machicolation, and the crest
    b.box((0, ROOM0 - 0.55, ZF + 0.08), (6.2, 0.3, 0.3), "stone", uv=1.6, tint=T["pale"], jit=0.01, cuts=2)
    shield(b, T, 0.0, CROWN + 2.0, ZF + 0.02, seed)
    # the Realm side: a lamp bracket plate, relieving arch shadow
    # ---- the gate leaves, open against the passage walls, and the portcullis raised in its groove
    for sx in (-1, 1):
        b.box((sx * (w / 2 - 0.12), 2.45, 0.15), (0.2, 4.8, 2.8), "wood", uv=1.0, jit=0.0, cuts=0)
        for hy in (0.9, 2.45, 4.0):
            b.box((sx * (w / 2 - 0.2), hy, 0.15), (0.06, 0.16, 2.6), "iron")
        for zz in (-0.7, 0.95):
            b.box((sx * (w / 2 - 0.2), 2.45, zz), (0.06, 4.6, 0.12), "iron")
        b.box((sx * (w / 2 - 0.22), 4.0, 1.55), (0.14, 0.24, 0.24), "iron")                   # a hinge strap
    zg = (groove[0] + groove[1]) / 2
    bars = [-2.0 + k * 0.5 for k in range(9)]
    for xb in bars:
        # the bars hang from the groove down to a spiked end, cut where the arch closes over them
        cxr = w / 2 if xb < 0 else -w / 2
        h_arch = spring + math.sqrt(max(w * w - (xb - cxr) ** 2, 0.0))
        y_top = h_arch + 0.15
        y_bot = 5.7 + (0.25 if abs(xb) < 0.1 else 0.0)
        b.box((xb, (y_top + y_bot) / 2, zg), (0.1, y_top - y_bot, 0.1), "iron")
        b.box((xb, y_bot - 0.14, zg), (0.07, 0.28, 0.07), "iron", taper=0.15)
    for yb in (6.0, 7.0, 7.9):
        wd = 2.0 * (w / 2 - 0.15 - max(0.0, (yb - 6.0) * 0.45))
        b.box((0, yb, zg), (min(wd, 4.6), 0.1, 0.1), "iron")
    # a ring for the vault lantern, at the crown between the ribs
    b.box((0.0, CROWN - 0.04, -2.6), (0.2, 0.08, 0.2), "iron")
    b.box((0.0, CROWN - 0.16, -2.6), (0.05, 0.2, 0.05), "iron")
    # the road's sill
    b.box((0, 0.04, (ZF + ZB) / 2), (w - 0.2, 0.14, ZF - ZB), "stone", uv=1.2, tint=T["pale"], cuts=3, jit=0.02)
    return b.finish()
