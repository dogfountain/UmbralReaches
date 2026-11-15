"""The Drowned Nave (tools/blender/reach_east.py): an unfinished Gothic cathedral standing in a flooded basin, the Order's
last great work. The nave was raised first and the floor was to be laid last; the water came in before the floor did.
Eight pairs of clustered piers carry pointed arcades; the first three bays have their clerestory and ribs standing, the
rest stop at the arcade with wall-shafts and abandoned scaffolding; the aisles are walled and open to the sky; the west
front has three portals, a great window and a ragged gable, a tall tower stump on one side and only the footings of
its twin (with the masons' crane still rigged) on the other; the apse stands broken round the altar.

Local frame (Godot): origin at the nave's middle on the basin floor (the water stands 0.6 m above it); the nave runs
along z, the west front at z -28.5 (facing -z, the way nave_track comes from), the altar at z +26.5.
  Nave      everything standing (near), NaveFar the silhouette, NaveCol the collision (primitives)
"""
import math
import random
import bmesh
from mathutils import Vector
import r37_south_lib as L
import r37_wall as RW
from r37_wall_lib import W, rng
import reach_east_lib as E

T = RW.tints()
PX = 5.2
PZ = [-22.0 + 6.0 * k for k in range(8)]
SPRING = 9.0
CLERE = 12.55
RIB_Y = 17.0
AISLE_X = 10.8
FRONT_Z = -28.5
APSE_C = Vector((0.0, 0.0, 20.0))
APSE_R = 10.8
ALTAR_Z = 26.5


def mats():
    return {"stone": E.nave_stone(), "dark": L.flat("E_NDark", (0.008, 0.008, 0.01), 1.0),
            "wood": L.pbr("E_NWood", L.tex_planks(512, 7730), 2.0), "iron": L.flat("E_NIron", (0.08, 0.075, 0.07), 0.6, 0.8)}


def pier(b, x, z, top, seed, shafts=True):
    b.rect_solid(x - 1.25, x + 1.25, z - 1.25, z + 1.25, -1.2, 0.8, bat=(0.2,) * 4, foot=(0.0,) * 4, uv=1.0, tint=T["damp"], jit=0.02, seed=seed)
    b.frustum(x, z, 0.92, 0.84, 0.8, SPRING - 0.5, "stone", uv=1.2, tint=T["plain"], jit=0.02, seed=seed + 1, round_n=16, levels=8)
    # four attached shafts
    if shafts:
        for a in range(4):
            ang = math.tau * a / 4 + math.pi / 4
            sx, sz = x + math.cos(ang) * 0.95, z + math.sin(ang) * 0.95
            b.frustum(sx, sz, 0.2, 0.2, 0.8, SPRING - 0.5, "stone", uv=1.4, tint=T["pale"], jit=0.01, seed=seed + 2 + a, round_n=8, levels=4)
    # capital: stepped drums and an abacus
    b.frustum(x, z, 0.95, 1.18, SPRING - 0.5, SPRING + 0.1, "stone", uv=1.5, tint=T["pale"], jit=0.01, seed=seed + 7, round_n=16, levels=3)
    b.box((x, SPRING + 0.28, z), (2.5, 0.3, 2.5), "stone", uv=1.5, tint=T["pale"], jit=0.01, cuts=1)
    if top > SPRING + 0.5:
        # wall-shaft: a clustered stalk rising to a vault springing, ragged at the break
        b.frustum(x, z, 0.46, 0.42, SPRING + 0.4, top, "stone", uv=1.4, tint=T["plain"], jit=0.02, seed=seed + 11, round_n=10, levels=max(2, int((top - SPRING) / 1.4)))
        for sz_ in (-0.55, 0.55):
            b.box((x, (top + SPRING) / 2 + 0.2, z + sz_), (0.55, top - SPRING - 0.4, 0.3), "stone", uv=1.3, tint=T["plain"], jit=0.02, cuts=1)


def arch_head(b, wopen, yspring, ytop, hw, thick, ragged=None, seed=0):
    """The wall above a pointed opening: a polygon with the pointed notch, over z -thick/2..thick/2."""
    n = 9
    left = []                      # the opening's left edge, rising from the springing to the crown
    for i in range(n + 1):
        th = math.pi - (math.pi / 3.0) * i / n
        left.append((wopen / 2 + wopen * math.cos(th), yspring + wopen * math.sin(th)))     # arc centred at the right springing: this is the LEFT edge
    # left[0] = (-wopen/2, yspring), left[-1] = crown (0, yspring + 0.866 wopen)
    right = [(-x, y) for (x, y) in reversed(left[:-1])]        # the right edge falling from the crown
    notch = left + right                                       # from the left springing over the crown to the right springing
    top = []
    if ragged:
        k = len(ragged)
        for i in range(k):
            xa = -hw + 2 * hw * i / k
            xb = -hw + 2 * hw * (i + 1) / k
            top.append((xa, ragged[i]))
            top.append((xb, ragged[i]))
    else:
        top = [(-hw, ytop), (hw, ytop)]
    poly = [(-hw, yspring)] + notch + [(hw, yspring)] + list(reversed(top))
    # the poly runs: left foot -> over the notch -> right foot -> up the right side -> across the top right to left -> down the left side
    b.poly_z(poly, -thick / 2, thick / 2, "stone", uv=1.0, tint=T["plain"], jit=0.0, seed=seed)
    # the arch's own voussoirs hugging the opening
    b.arch(0.0, yspring, wopen, 0.38, -thick / 2 - 0.05, thick / 2 + 0.05, "stone", uv=1.5, n=6, tint=T["pale"], seed=seed, jit=0.008, alt=0.04)


def bay(b, width, y0, ysill, yspring, ytop, wopen, thick, seed, ragged=None, sill_only=False):
    hw = width / 2
    b.box((0, (y0 + ysill) / 2, 0), (width, ysill - y0, thick), "stone", uv=1.0, tint=T["damp"], jit=0.015, cuts=2)
    if sill_only:
        return
    pw = hw - wopen / 2
    for sx in (-1, 1):
        b.box((sx * (hw - pw / 2), (ysill + yspring) / 2, 0), (pw, yspring - ysill, thick), "stone", uv=1.0, tint=T["plain"], jit=0.02, cuts=2)
    arch_head(b, wopen, yspring, ytop, hw, thick, ragged, seed)
    # the sill's ledge
    b.box((0, ysill + 0.05, thick / 2 + 0.06), (wopen + 0.5, 0.18, 0.3), "stone", uv=1.5, tint=T["pale"], jit=0.01, cuts=0)


def ragged_top(r, k, lo, hi, step=0.45):
    out = []
    h = r.uniform(lo, hi)
    for i in range(k):
        h = max(lo, min(hi, h + r.choice([-1.0, 0.0, 0.0, 1.0]) * step * r.uniform(0.5, 2.0)))
        out.append(h)
    return out


def at(b, fn, yaw, pos):
    RW.grouped(b, fn, yaw, pos)


def buttress(b, x, z, side, h, seed):
    """A stepped buttress stood out from a wall at (x, z); `side` = +1 / -1 (the way it projects along x)."""
    x0, x1 = (x, x + side * 2.8) if side > 0 else (x + side * 2.8, x)
    b.rect_solid(x0, x1, z - 0.75, z + 0.75, -1.2, h, bat=(0.0, 0.0, 0.0, 0.0), foot=(0.0, 0.0, 0.0, 0.0), uv=1.0, tint=T["plain"], jit=0.03, seed=seed)
    xs = x + side * 2.8
    for (dh, ins) in ((2.6, 0.55), (5.2, 1.1), (7.6, 1.6)):
        if dh < h - 1.0:
            pass
    # set-offs (weatherings) cut in as slanted caps
    for k, (hh, ins) in enumerate(((3.2, 0.5), (6.0, 1.0))):
        if hh < h - 0.5:
            b.box((x + side * (2.8 - ins * 0.5 + 0.0), hh, z), (ins + 0.1, 0.3, 1.7), "stone", uv=1.4, tint=T["pale"], jit=0.01, cuts=0, pitch=0.0)
    b.box((x + side * 1.4, h + 0.15, z), (2.9, 0.3, 1.7), "stone", uv=1.4, tint=T["pale"], jit=0.01, cuts=0)


def arcade(b):
    for xs in (-1, 1):
        x = xs * PX
        for k, z in enumerate(PZ):
            top = SPRING + 0.4 if k >= 4 else RIB_Y - 0.1
            if k in (4,):
                top = 13.2
            if k in (5, 6):
                top = 11.8 + 0.7 * (k % 2)
            if k == 7:
                top = SPRING + 0.4
            pier(b, x, z, top, 100 + k * 7 + (0 if xs > 0 else 3))
        for k in range(7):
            zc = (PZ[k] + PZ[k + 1]) / 2

            def one(k=k):
                b.arch(0.0, SPRING + 0.1, 4.3, 0.55, -0.65, 0.65, "stone", uv=1.5, n=8, tint=T["pale"], seed=k, jit=0.01, alt=0.06)
                # spandrel between this arch and the next pier's: a wall with the arch's extrados
                b.poly_z([(-2.15, SPRING + 0.1), (2.15, SPRING + 0.1), (2.15, SPRING + 0.1 + 3.6), (-2.15, SPRING + 0.1 + 3.6)], -0.6, 0.6, "dark", uv=1.0)
            # the arch ring in the x-y plane rotated to run along z; its wall above is built per bay below
            at(b, one, math.pi / 2, (x, 0.0, zc))
    # the wall over the arcade and the clerestory: bays 0..2 stand, 3..4 half, the rest only the arches
    for xs in (-1, 1):
        x = xs * PX
        for k in range(7):
            zc = (PZ[k] + PZ[k + 1]) / 2
            r = rng(500 + k + (0 if xs > 0 else 40))
            if k <= 2:
                def one(k=k, r=r):
                    # a wall from the crown of the arcade arch to the clerestory: spandrels, then the window bay
                    b.box((0, SPRING + 0.1 + 3.7 + 0.2, 0), (6.0, 0.5, 1.2), "stone", uv=1.3, tint=T["pale"], jit=0.01, cuts=1)           # a string course
                    bay(b, 6.0, SPRING + 4.0, 14.6, 16.9, 20.4, 2.0, 1.2, 600 + k, ragged=ragged_top(r, 6, 19.4, 20.6) if k == 2 else None)
                    # spandrels between the arches are filled (the wall under the string course)
                    b.box((0, SPRING + 2.7, 0), (6.0, 2.1, 1.2), "stone", uv=1.0, tint=T["plain"], jit=0.015, cuts=2)
                at(b, one, math.pi / 2 * xs, (x, 0.0, zc))
            elif k == 3:
                def one(k=k, r=r):
                    b.box((0, SPRING + 2.7, 0), (6.0, 2.1, 1.2), "stone", uv=1.0, tint=T["plain"], jit=0.015, cuts=2)
                    b.box((0, SPRING + 4.0, 0), (6.0, 1.4, 1.2), "stone", uv=1.0, tint=T["plain"], jit=0.02, cuts=2)
                    b.box((-1.5, SPRING + 5.2, 0), (2.4, 1.0, 1.2), "stone", uv=1.0, tint=T["plain"], jit=0.04, cuts=1)
                at(b, one, math.pi / 2 * xs, (x, 0.0, zc))
            else:
                def one(k=k, r=r):
                    h = 1.5 + r.uniform(0.0, 2.2)
                    b.box((r.uniform(-1, 1), SPRING + 1.0 + h / 2, 0), (r.uniform(2.4, 5.0), h, 1.2), "stone", uv=1.0, tint=T["plain"], jit=0.06, cuts=2)
                at(b, one, math.pi / 2 * xs, (x, 0.0, zc))


def ribs(b):
    """Transverse ribs across the nave over the first bays (the last one half down), a ridge rib, a web in one bay."""
    for k in range(4):
        z = PZ[k]
        n0 = len(b.bm.verts)

        def one(z=z):
            b.arch(0.0, RIB_Y, 10.4, 0.5, z - 0.3, z + 0.3, "stone", uv=1.4, n=14, tint=T["pale"], seed=20 + k, jit=0.01, alt=0.05)
        at(b, one, 0.0, (0.0, 0.0, 0.0))
        if k == 3:
            b.bm.verts.ensure_lookup_table()
            dead = [v for v in list(b.bm.verts)[n0:] if v.co.x > -0.4 and v.co.y > RIB_Y + 4.5]
            bmesh.ops.delete(b.bm, geom=dead, context='VERTS')
    # ridge rib: a beam of stone along the crown over bays 0..2, with bosses
    for k in range(3):
        z0, z1 = PZ[k], PZ[k + 1]
        b.box((0, RIB_Y + 9.0 - 0.22, (z0 + z1) / 2), (0.34, 0.5, z1 - z0 - 0.3), "stone", uv=1.4, tint=T["pale"], jit=0.01, cuts=1)
    for k in range(3):
        b.box((0, RIB_Y + 8.7, (PZ[k] + PZ[k + 1]) / 2), (0.7, 0.4, 0.7), "stone", uv=1.4, tint=T["pale"], jit=0.01, cuts=0)


def aisle_walls(b):
    for xs in (-1, 1):
        for k in range(8):
            zc = -25.0 + 6.0 * k
            if zc > 21.0:
                continue
            r = rng(700 + k + (0 if xs > 0 else 30))
            standing = 9.6 if k <= 4 else (7.6 if k == 5 else 4.0)

            def one(k=k, r=r, standing=standing):
                if standing >= 9.0:
                    bay(b, 6.0, -1.2, 3.4, 7.2, 9.6, 1.7, 1.4, 800 + k, ragged=ragged_top(r, 6, 8.8, 9.6) if k >= 3 else None)
                elif standing >= 7.0:
                    bay(b, 6.0, -1.2, 3.4, 7.2, 7.6, 1.7, 1.4, 800 + k, sill_only=True)
                    b.box((-2.0, 5.6, 0), (2.0, 4.4, 1.4), "stone", uv=1.0, tint=T["plain"], jit=0.05, cuts=2)
                else:
                    bay(b, 6.0, -1.2, standing - 1.0 + r.uniform(0, 1.0), 7.2, 7.6, 1.7, 1.4, 800 + k, sill_only=True)
            at(b, one, math.pi / 2 * xs, (xs * AISLE_X, 0.0, zc))
        # buttresses outside, one per pier line
        for k, z in enumerate(PZ):
            hh = 10.6 if k <= 5 else 6.2
            buttress(b, xs * (AISLE_X + 0.7), z, xs, hh, 900 + k + (0 if xs > 0 else 50))
    # flying buttresses over the aisle roof line on the three finished bays
    for xs in (-1, 1):
        for k in range(1, 4):
            z = PZ[k]
            x0, x1 = xs * (AISLE_X + 2.2), xs * (PX + 0.8)
            y0, y1 = 10.9, 15.3
            ln = math.hypot(x1 - x0, y1 - y0)
            ang = math.atan2(y1 - y0, abs(x1 - x0)) * (-xs)
            b.box(((x0 + x1) / 2, (y0 + y1) / 2 + 0.3, z), (ln, 0.65, 0.9), "stone", uv=1.4, tint=T["pale"], jit=0.015, cuts=2, roll=ang)
            b.box((x0 + xs * -0.1, y0 + 0.4, z), (1.1, 1.2, 1.1), "stone", uv=1.4, tint=T["plain"], jit=0.015, cuts=1)
    # a pinnacle on each finished buttress
    for xs in (-1, 1):
        for k in range(0, 4):
            x = xs * (AISLE_X + 2.1)
            b.frustum(x, PZ[k], 0.5, 0.12, 10.7, 13.4, "stone", uv=1.4, tint=T["pale"], jit=0.01, seed=k, levels=3, round_n=6)


def west_front(b):
    r = rng(1100)
    z = FRONT_Z
    # the facade: a block across the nave and aisles, pierced by three portals, a great window above
    def front():
        # lower storey with portals: segments between the portal openings, to y 9.4
        for (x0, x1) in ((-11.4, -9.3), (-6.7, -2.2), (2.2, 6.7), (9.3, 11.4)):
            b.rect_solid(x0, x1, -0.8, 0.8, -1.2, 9.4, uv=1.0, tint=T["plain"], jit=0.025, seed=int(x0 * 3))
        for cx, w in ((0.0, 4.4), (-8.0, 2.6), (8.0, 2.6)):
            hs = 5.0 if cx == 0.0 else 3.6
            RW.pointed_door(b, cx, -0.4, w, hs, T, int(cx) + 5, depth=0.8, steps=False, wood=False)
            top = -0.4 + hs + 0.87 * w
            b.poly_z([(cx - w / 2 - 1.0, -0.4 + hs), (cx + w / 2 + 1.0, -0.4 + hs), (cx + w / 2 + 1.0, 9.4), (cx - w / 2 - 1.0, 9.4)] if False else [(cx - w / 2 - 0.4, top - 0.3), (cx + w / 2 + 0.4, top - 0.3), (cx + w / 2 + 0.4, 9.4), (cx - w / 2 - 0.4, 9.4)], -0.8, 0.8, "stone", uv=1.0, tint=T["plain"], jit=0.0)
        # the portals' orders: an outer ring of voussoirs, jamb shafts
        b.arch(0.0, 4.6, 5.6, 0.5, -0.9, 0.5, "stone", uv=1.5, n=8, tint=T["pale"], seed=3, jit=0.008, alt=0.06)
        for sx in (-1, 1):
            for dx in (2.55, 2.95):
                b.frustum(sx * dx, 0.55, 0.14, 0.14, -0.4, 4.6, "stone", uv=1.5, tint=T["pale"], jit=0.005, seed=5, round_n=8, levels=3)
        # the great window's storey: three bays, the middle one a great pointed window with a transom and two mullions, the
        # flanking ones lancets, the gable left ragged where the masons stopped
        b.box((0, 9.6, 0), (22.8, 0.4, 1.8), "stone", uv=1.4, tint=T["pale"], jit=0.01, cuts=3)

        def cbay():
            bay(b, 11.4, 9.8, 10.8, 15.2, 24.4, 6.6, 1.6, 1200, ragged=ragged_top(r, 9, 21.5, 24.4, 0.9))
        at(b, cbay, 0.0, (0.0, 0.0, 0.0))
        for sx in (-1, 1):
            def sbay(sx=sx):
                bay(b, 5.7, 9.8, 11.6, 15.6, 20.0 + 0.8 * (sx + 1), 1.5, 1.6, 1210 + sx, ragged=ragged_top(r, 4, 18.6, 20.6, 0.8))
            at(b, sbay, 0.0, (sx * 8.55, 0.0, 0.0))
        for sx in (-1, 0, 1):
            b.box((sx * 1.6, 13.0, 0.12), (0.24, 5.6, 0.42), "stone", uv=1.5, tint=T["pale"], jit=0.01, cuts=1)
        b.box((0, 12.9, 0.12), (6.8, 0.26, 0.42), "stone", uv=1.5, tint=T["pale"], jit=0.01, cuts=1)
        b.box((0, 16.6, 0.1), (2.0, 0.24, 0.42), "stone", uv=1.5, tint=T["pale"], jit=0.01, cuts=1)
        # blind arcading over the portals, a string course, and pilasters up the face
        for i in range(-5, 6):
            x = i * 2.0
            if abs(x) < 4.5 and False:
                continue
            b.poly_z(RW.arch_poly(x, 8.2, 0.9, 6.7), 0.78, 0.9, "dark", uv=1.0)
            b.arch(x, 8.2, 0.9, 0.16, 0.76, 0.95, "stone", uv=1.5, n=4, tint=T["pale"], seed=i + 20, jit=0.004)
        for x in (-4.4, 4.4):
            b.box((x, 12.0, 0.9), (0.7, 24.0, 0.5), "stone", uv=1.3, tint=T["plain"], jit=0.02, cuts=2)
    at(b, front, math.pi, (0.0, 0.0, z))          # faces -z
    # the wall's thick core between the faces is the box inside the facade pieces; buttresses at the corners
    for sx in (-1, 1):
        b.rect_solid(sx * 11.4 - 0.8, sx * 11.4 + 0.8, z - 1.8, z + 1.8, -1.2, 21.0, uv=1.0, tint=T["plain"], jit=0.03, seed=7)
    # the tower stump (x -) and the footings of its twin (x +)
    tx, tz = -15.2, z + 0.2
    b.frustum(tx, tz, (4.2, 4.2), (3.7, 3.7), -1.2, 25.0, "stone", uv=1.0, tint=T["plain"], jit=0.04, seed=31, edge=1.3, levels=22)
    for yy in (6.0, 12.0, 18.0):
        h = 4.2 - 0.5 * (yy + 1.2) / 26.2
        b.frustum(tx, tz, (h + 0.18, h + 0.18), (h + 0.18, h + 0.18), yy, yy + 0.35, "stone", uv=1.5, tint=T["pale"], jit=0.01, seed=32, levels=2)
    for yy in (8.0, 14.5, 20.0):
        for fx in (-1, 1):
            b.box((tx + fx * 0.0, yy, tz - 3.9), (0.35, 1.8, 0.2), "dark", cuts=0)
    rr = rng(1150)
    for i in range(14):
        a = math.tau * i / 14
        hh = 25.0 + rr.uniform(0.0, 2.4) * (0.4 + 0.6 * abs(math.sin(a * 1.5)))
        b.box((tx + math.cos(a) * 3.3, (25.0 + hh) / 2, tz + math.sin(a) * 3.3), (1.3, hh - 25.0 + 0.2, 1.3), "stone", uv=1.2, tint=T["plain"], jit=0.05, cuts=1)
    # putlog holes up the tower, and the scaffold left standing against it
    for yy in (7.0, 11.0, 15.0, 19.0, 23.0):
        for xx in (-2.8, 0.0, 2.8):
            b.box((tx + xx, yy, tz - 3.95), (0.3, 0.3, 0.2), "dark", cuts=0)
    for xx in (-3.6, 3.6):
        b.tube((tx + xx, -1.0, tz - 5.3), (tx + xx, 21.0, tz - 5.3), 0.12, 0.1, "wood", sides=6, bark=1.2)
    for yy in (3.0, 8.0, 13.0, 18.0):
        b.box((tx, yy, tz - 5.3), (7.6, 0.14, 0.18), "wood", uv=1.0, cuts=0)
        b.box((tx, yy + 0.02, tz - 4.6), (7.6, 0.08, 1.2), "wood", uv=1.0, cuts=0)
        for sx in (-1, 1):
            b.tube((tx + sx * 3.6, yy, tz - 5.3), (tx + sx * 3.6, yy + 0.1, tz - 4.0), 0.07, 0.07, "wood", sides=5, bark=1.0)
    # the twin: footings only, with the masons' crane still rigged
    ux = 15.2
    b.rect_solid(ux - 4.2, ux + 4.2, tz - 4.2, tz + 4.2, -1.2, 4.8, bat=(0.1,) * 4, uv=1.0, tint=T["damp"], jit=0.05, seed=41)
    for i in range(12):
        a = rr.uniform(0, math.tau)
        rad = rr.uniform(0.0, 3.4)
        b.box((ux + math.cos(a) * rad, 5.1, tz + math.sin(a) * rad), (rr.uniform(0.9, 1.6), rr.uniform(0.5, 0.9), rr.uniform(0.9, 1.6)), "stone", uv=1.2, tint=T["plain"], jit=0.04, cuts=1, yaw=rr.uniform(0, 3))
    # the crane: a post, a jib and the tackle, a block still hanging in the rope
    cx, cz = ux + 0.5, tz - 5.5
    b.tube((cx, 0.0, cz), (cx, 13.0, cz), 0.3, 0.22, "wood", sides=8, bark=1.4)
    b.tube((cx, 12.4, cz), (cx - 7.0, 11.2, cz - 2.5), 0.2, 0.14, "wood", sides=8, bark=1.4)
    b.tube((cx, 12.4, cz), (cx + 3.5, 10.8, cz + 0.6), 0.18, 0.14, "wood", sides=8, bark=1.4)
    b.tube((cx - 7.0, 11.2, cz - 2.5), (cx - 7.0, 6.0, cz - 2.5), 0.025, 0.025, "iron", sides=4, bark=1.0, cap=False)
    b.box((cx - 7.0, 5.4, cz - 2.5), (1.0, 1.0, 1.0), "stone", uv=1.2, tint=T["plain"], jit=0.02, cuts=1)
    for sx in (-1, 1):
        b.tube((cx, 0.0, cz), (cx + sx * 2.8, 5.0, cz + 2.8), 0.14, 0.12, "wood", sides=6, bark=1.4)
        b.tube((cx, 0.0, cz), (cx + sx * 2.8, 5.0, cz - 2.8), 0.14, 0.12, "wood", sides=6, bark=1.4)
    b.box((cx + 0.0, 0.1, cz), (4.4, 0.25, 5.4), "wood", uv=1.0, cuts=0)


def apse(b):
    r = rng(1300)
    segs = 6
    pts = [(APSE_C.x + APSE_R * math.cos(math.pi * i / segs), APSE_C.z + APSE_R * math.sin(math.pi * i / segs)) for i in range(segs + 1)]
    for i in range(segs):
        (x0, z0), (x1, z1) = pts[i], pts[i + 1]
        mx, mz = (x0 + x1) / 2, (z0 + z1) / 2
        ln = math.hypot(x1 - x0, z1 - z0)
        mid = math.pi * (i + 0.5) / segs
        yaw = math.atan2(math.cos(mid), math.sin(mid))
        broken = i in (0, 1)

        def one(i=i, ln=ln, broken=broken):
            if broken:
                bay(b, ln, -1.2, 3.4, 7.0, 8.6, 1.7, 1.4, 1300 + i, sill_only=True)
                b.box((ln * 0.2, 5.0 + 0.5 * i, 0), (ln * 0.4, 3.4, 1.4), "stone", uv=1.0, tint=T["plain"], jit=0.06, cuts=2)
            else:
                bay(b, ln, -1.2, 3.4, 7.4, 10.6, 1.9, 1.4, 1300 + i, ragged=ragged_top(r, 5, 9.6, 10.6) if i == 2 else None)
        at(b, one, yaw, (mx, 0.0, mz))
    for i in range(segs + 1):
        x, z = pts[i]
        hh = 11.4 if i not in (0, 1) else 5.6
        a = math.pi * i / segs
        bx, bz = x + math.cos(a) * 1.1, z + math.sin(a) * 1.1
        b.rect_solid(bx - 0.8, bx + 0.8, bz - 0.8, bz + 0.8, -1.2, hh, bat=(0.0,) * 4, uv=1.0, tint=T["plain"], jit=0.03, seed=60 + i)
    # the altar on a dais of three steps, a reredos of blind arches behind it
    az = ALTAR_Z
    for k, (w, d, hh) in enumerate(((7.4, 5.6, 0.55), (6.2, 4.6, 1.05), (5.0, 3.6, 1.5))):
        b.box((0, hh / 2 - 0.2, az - 0.3), (w, hh + 0.4, d), "stone", uv=1.2, tint=T["plain"], jit=0.015, cuts=3)
    b.box((0, 2.05, az - 0.2), (2.6, 1.1, 1.1), "stone", uv=1.4, tint=T["pale"], jit=0.01, cuts=2)
    b.box((0, 2.64, az - 0.2), (2.9, 0.2, 1.3), "stone", uv=1.5, tint=T["pale"], jit=0.01, cuts=1)
    for sx in (-0.8, 0.0, 0.8):
        b.poly_z(RW.arch_poly(sx, 1.65, 0.62, 1.55), az - 0.78, az - 0.72, "dark", uv=1.0)
    # candle-stands of iron, one fallen
    b.tube((-2.2, 1.5, az - 1.2), (-2.2, 3.6, az - 1.2), 0.04, 0.035, "iron", sides=5, bark=1.0)
    b.tube((2.4, 1.5, az - 1.0), (3.6, 1.6, az + 0.3), 0.04, 0.035, "iron", sides=5, bark=1.0)
    # a great iron cross fallen on the dais
    b.box((1.6, 1.62, az + 0.6), (0.14, 0.1, 1.9), "iron", yaw=0.3)
    b.box((1.55, 1.62, az + 0.35), (0.9, 0.1, 0.14), "iron", yaw=0.3)


def rubble(b):
    r = rng(1400)
    for i in range(44):
        x = r.uniform(-8.5, 8.5)
        z = r.uniform(-24.0, 24.0)
        if abs(x) > 4.4 and abs(x) < 6.0 and (z + 22.0) % 6.0 < 1.6:
            continue
        if abs(x) < 1.8 and z > 22.0:
            continue
        kind = r.random()
        if kind < 0.55:
            s = r.uniform(0.5, 1.4)
            b.box((x, -0.8 + s * 0.2, z), (s * r.uniform(1.0, 2.0), s * 0.7, s * r.uniform(0.8, 1.4)), "stone", uv=1.2, tint=T["damp"], jit=0.04, cuts=1, yaw=r.uniform(0, 3), pitch=r.uniform(-0.25, 0.25), roll=r.uniform(-0.25, 0.25))
        elif kind < 0.8:
            b.frustum(x, z, 0.8, 0.8, -1.0, -1.0 + r.uniform(0.6, 1.4), "stone", uv=1.2, tint=T["damp"], jit=0.04, seed=i, round_n=10, levels=2)
        else:
            # a fallen drum on its side
            b.tube((x, -0.3, z), (x + r.uniform(-1.6, 1.6), -0.3, z + r.uniform(-1.6, 1.6)), 0.8, 0.8, "stone", sides=10, bark=3.0, jit=0.03, seed=i)
    # voussoirs lying in a row where a rib fell across the nave
    for i in range(9):
        a = i / 9.0
        b.box((-3.0 + a * 6.0, -0.55, -3.0 + r.uniform(-0.8, 0.8)), (0.55, 0.45, 1.1), "stone", uv=1.5, tint=T["pale"], jit=0.02, cuts=1, yaw=r.uniform(-0.6, 0.6))


def scaffold(b):
    """Abandoned masons' scaffolding against the unfinished arcade bays: poles, putlogs, a ladder, a trestle."""
    for xs in (-1, 1):
        for k in range(4, 7):
            z = PZ[k]
            x = xs * (PX - 1.6)
            b.tube((x, -1.0, z - 1.4), (x, 13.5, z - 1.4), 0.1, 0.08, "wood", sides=6, bark=1.2)
            b.tube((x, -1.0, z + 1.4), (x, 13.0, z + 1.4), 0.1, 0.08, "wood", sides=6, bark=1.2)
            for yy in (3.0, 7.5, 12.0):
                b.box((x, yy, z), (0.15, 0.15, 3.0), "wood", uv=1.0, cuts=0)
                b.box((x + xs * 0.9, yy + 0.05, z), (1.8, 0.07, 2.8), "wood", uv=1.0, cuts=0)
            b.box((x + xs * 0.7, 6.0, z + 1.4), (0.1, 12.0, 0.4), "wood", uv=1.0, cuts=0, roll=-xs * 0.12)


def build_near(M):
    b = W("Nave", M, 777, damp=1.2)
    # the water-line foundation: a mat of footings under the whole fabric (hidden on the mud)
    arcade(b)
    ribs(b)
    aisle_walls(b)
    west_front(b)
    apse(b)
    rubble(b)
    scaffold(b)
    ob = b.finish()
    return ob


def build_far(M):
    b = W("NaveFar", {"stone": M["stone"]}, 1)
    for xs in (-1, 1):
        b.box((xs * AISLE_X, 4.0, 0.0), (1.8, 10.4, 48.0), "stone", cuts=0, jit=0.0, uv=0.6)
        b.box((xs * PX, 8.2, -12.0), (1.6, 19.0, 21.0), "stone", cuts=0, jit=0.0, uv=0.6)
        b.box((xs * PX, 6.4, 8.0), (1.6, 14.0, 14.0), "stone", cuts=0, jit=0.0, uv=0.6)
    b.box((0, 10.4, FRONT_Z), (23.0, 22.0, 2.4), "stone", cuts=0, jit=0.0, uv=0.6)
    b.box((-15.2, 12.0, FRONT_Z + 0.2), (8.2, 26.0, 8.2), "stone", cuts=0, jit=0.0, uv=0.6, taper=0.9)
    b.box((15.2, 2.0, FRONT_Z + 0.2), (8.4, 6.0, 8.4), "stone", cuts=0, jit=0.0, uv=0.6)
    b.box((0, 4.4, 26.0), (22.0, 8.0, 12.0), "stone", cuts=0, jit=0.0, uv=0.6)
    return b.finish()


def build_col(M):
    b = W("NaveCol", {"stone": M["stone"]}, 2)
    for xs in (-1, 1):
        for z in PZ:
            b.frustum(xs * PX, z, 1.0, 1.0, -1.5, 13.0 if z < -3.0 else 10.0, "stone", jit=0.0, round_n=8, levels=2)
        # aisle wall (solid; its windows are not walked through), buttresses
        b.box((xs * AISLE_X, 3.8, -2.5), (1.5, 10.0, 49.0), "stone", cuts=0, jit=0.0)
        for z in PZ:
            b.box((xs * (AISLE_X + 2.0), 4.0, z), (3.0, 9.0, 1.6), "stone", cuts=0, jit=0.0)
        # the walls over the arcade on the finished bays
        b.box((xs * PX, 17.0, -13.0), (1.2, 7.0, 18.0), "stone", cuts=0, jit=0.0)
    # west front: segments between portals, the wall above them
    for (x0, x1) in ((-11.6, -9.3), (-6.7, -2.2), (2.2, 6.7), (9.3, 11.6)):
        b.box(((x0 + x1) / 2, 4.5, FRONT_Z), (x1 - x0, 12.0, 1.7), "stone", cuts=0, jit=0.0)
    b.box((0, 15.0, FRONT_Z), (23.0, 12.0, 1.7), "stone", cuts=0, jit=0.0)
    b.box((-15.2, 12.0, FRONT_Z + 0.2), (8.4, 26.0, 8.4), "stone", cuts=0, jit=0.0)
    b.box((15.2, 1.8, FRONT_Z + 0.2), (8.4, 6.0, 8.4), "stone", cuts=0, jit=0.0)
    # apse walls and the dais
    segs = 6
    for i in range(segs):
        a0, a1 = math.pi * i / segs, math.pi * (i + 1) / segs
        x0, z0 = APSE_C.x + APSE_R * math.cos(a0), APSE_C.z + APSE_R * math.sin(a0)
        x1, z1 = APSE_C.x + APSE_R * math.cos(a1), APSE_C.z + APSE_R * math.sin(a1)
        mid = (a0 + a1) / 2
        ln = math.hypot(x1 - x0, z1 - z0)
        b.box(((x0 + x1) / 2, 4.0, (z0 + z1) / 2), (ln + 0.6, 10.0, 1.5), "stone", cuts=0, jit=0.0, yaw=math.atan2(math.cos(mid), math.sin(mid)))
    for k, (w, d, hh) in enumerate(((7.4, 5.6, 0.55), (6.2, 4.6, 1.05), (5.0, 3.6, 1.5))):
        b.box((0, hh / 2 - 0.2, ALTAR_Z - 0.3), (w, hh + 0.4, d), "stone", cuts=0, jit=0.0)
    b.box((0, 2.05, ALTAR_Z - 0.2), (2.6, 1.1, 1.1), "stone", cuts=0, jit=0.0)
    return b.finish()


def build_all(objs, DATA):
    M = mats()
    objs.append(build_near(M))
    objs.append(build_far(M))
    objs.append(build_col(M))
    DATA["NAVE_ALTAR_Z"] = ALTAR_Z
    DATA["NAVE_FRONT_Z"] = FRONT_Z
    DATA["NAVE_PIERS"] = PZ
