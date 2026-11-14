"""r37 East Marches, the salt works at building scale (docs/ARCH_REVIEW.md "for the next round" 4 and 7).

  tools/blender/run.sh r37_east_works.py                         (writes art/models/r37e_works.glb and the box tables)
  tools/blender/run.sh r37_east_works.py -- --preview /tmp/r37w  (also renders stills for review)

Builds on r37_east.py: its materials, MB mesh builder and helpers are run in this script's namespace (without its
main(), so the Spire, cells, hall and hamlet GLBs it wrote stay as they are). Everything here is modelled at its
final size (World-of-Warcraft proportions, Luke 13 Nov: "you should feel very small in it"): a salt shed 10 x 15 m
with a 4.6 m door, a pump tower 28 m tall, a drying rack 12 m long, flumes on trestles a person walks under, sluices,
carts, sledges and heaps the size of a cart-house. Units: 1 BU = 1 m, +Z is the front, origin on the ground.
Writes art/models/r37e_works.glb and core/world/realm/east_works_boxes.gd (collision boxes from the same numbers).
"""
import os
import sys
import math

_here = os.path.dirname(os.path.abspath(__file__))
_src = open(os.path.join(_here, "r37_east.py")).read().rstrip()
assert _src.endswith("\nmain()")
exec(compile(_src[:-len("main()")], os.path.join(_here, "r37_east.py"), "exec"), globals())


def wheel(mb, c, r, plane, spokes=8, rim=14, tw=0.14, th=0.16, mat="timber", hub=0.3):
    """A spoked wheel centred at c in plane 'xy' (axis along z) or 'zy' (axis along x)."""
    def p(a, rr):
        if plane == 'xy':
            return (c[0] + math.cos(a) * rr, c[1] + math.sin(a) * rr, c[2])
        return (c[0], c[1] + math.sin(a) * rr, c[2] + math.cos(a) * rr)
    for i in range(rim):
        a0, a1 = math.tau * i / rim, math.tau * (i + 1) / rim
        beam(mb, p(a0, r), p(a1, r), tw, th, mat)
    for i in range(spokes):
        a = math.tau * i / spokes
        beam(mb, p(a, hub), p(a, r), tw * 0.8, th * 0.8, mat)
    mb.box(c, (hub * 1.4, hub * 1.4, hub * 1.4), "iron")


def lean(mb, a, b, tw, th, mat):
    beam(mb, a, b, tw, th, mat)


# ================================================================== the pump tower
def pump_tower():
    """A brine pump: an ashlar pump house (9 m square) carrying a lattice tower of battered timber legs to 28 m, two
    working platforms, a brine tank hooped in iron, a great windlass wheel at the head with its cheek posts, a
    hoist beam, a ladder, and a penstock down to the flume. The door and the wheel face +z."""
    CURRENT[0] = "pump_tower"
    mb = MB("Pump_Tower")
    B, BH = 9.0, 4.8
    mb.box((0, 0.3, 0), (B + 1.0, 0.6, B + 1.0), "stone_dark")
    wall(mb, 'x', (0, B / 2), B, 0.9, 0.6, BH, "stone", holes=[(0, 2.9, 0.6, 3.7)], col=False)
    wall(mb, 'x', (0, -B / 2), B, 0.9, 0.6, BH, "stone", col=False)
    wall(mb, 'z', (B / 2, 0), B, 0.9, 0.6, BH, "stone", col=False)
    wall(mb, 'z', (-B / 2, 0), B, 0.9, 0.6, BH, "stone", col=False)
    mb.box((0, BH / 2, 0), (B - 0.9, BH, B - 0.9), "void")
    mb.box((0, BH + 0.12, 0), (B + 0.7, 0.3, B + 0.7), "stone")                       # string course
    mb.box((0, BH + 0.45, 0), (B + 0.2, 0.36, B + 0.2), "timber_old")                  # the roof deck
    for sgn in (-1, 1):                                                                  # the door: jambs, lintel, leaves ajar
        mb.box((sgn * 1.55, 2.2, B / 2 + 0.25), (0.28, 3.1, 0.5), "timber")
    mb.box((0, 3.85, B / 2 + 0.25), (3.4, 0.3, 0.5), "timber")
    mb.box((-1.0, 2.1, B / 2 + 0.7), (1.3, 3.0, 0.1), "timber_old", rot=(0, 0.8, 0))
    for yy in (1.1, 2.9):
        mb.box((-1.0, yy, B / 2 + 0.78), (1.3, 0.14, 0.05), "iron", rot=(0, 0.8, 0))
    mb.box((0, 0.3, B / 2 + 1.4), (4.2, 0.4, 1.8), "stone")                             # worn step
    for x in (-3.0, 3.0):                                                                # slit windows
        mb.box((x, 2.9, B / 2 + 0.46), (0.3, 1.2, 0.1), "void")
    for sx in (-1, 1):                                                                   # buttress piers at the corners
        for sz in (-1, 1):
            mb.box((sx * (B / 2 + 0.3), 1.9, sz * (B / 2 + 0.3)), (0.9, 3.8, 0.9), "stone")
    base_y = BH + 0.65
    top_y = 27.0
    w0, w1 = 3.7, 1.3
    def hw(y):
        return w0 + (w1 - w0) * (y - base_y) / (top_y - base_y)
    for (sx, sz) in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
        beam(mb, (sx * w0, base_y, sz * w0), (sx * w1, top_y, sz * w1), 0.55, 0.55, "timber")
        mb.box((sx * w0, base_y + 0.2, sz * w0), (1.1, 0.4, 1.1), "stone")
    levels = [base_y + 0.3, 11.0, 15.5, 20.0, 24.4]
    for k, yy in enumerate(levels):
        w = hw(yy)
        for (c, s) in (((0, yy, w), (2 * w, 0.3, 0.3)), ((0, yy, -w), (2 * w, 0.3, 0.3)), ((w, yy, 0), (0.3, 0.3, 2 * w)), ((-w, yy, 0), (0.3, 0.3, 2 * w))):
            mb.box(c, s, "timber")
        for sx in (-1, 1):
            for sz in (-1, 1):
                mb.box((sx * w, yy, sz * w), (0.5, 0.2, 0.5), "iron")
        if k < len(levels) - 1:
            y2 = levels[k + 1]
            w2 = hw(y2)
            for sgn in (-1, 1):
                beam(mb, (-w, yy, sgn * w), (w2, y2, sgn * w2), 0.2, 0.24, "timber")
                beam(mb, (w, yy, sgn * w), (-w2, y2, sgn * w2), 0.2, 0.24, "timber")
                beam(mb, (sgn * w, yy, -w), (sgn * w2, y2, w2), 0.2, 0.24, "timber")
                beam(mb, (sgn * w, yy, w), (sgn * w2, y2, -w2), 0.2, 0.24, "timber")
    # the working platform at 15.5 with a rail, and the brine tank on its own cradle
    wp = hw(15.5) + 0.6
    mb.box((0, 15.65, 0), (2 * wp, 0.22, 2 * wp), "timber_old")
    for i in range(9):
        mb.box((-wp + 0.25 + i * (2 * wp - 0.5) / 8, 15.8, 0), (0.4, 0.05, 2 * wp), "timber")
    for sx in (-1, 1):
        for sz in (-1, 1):
            mb.box((sx * (wp - 0.1), 16.2, sz * (wp - 0.1)), (0.16, 1.1, 0.16), "timber")
    for sgn in (-1, 1):
        mb.box((0, 16.75, sgn * (wp - 0.1)), (2 * wp, 0.16, 0.16), "timber")
        mb.box((sgn * (wp - 0.1), 16.75, 0), (0.16, 0.16, 2 * wp), "timber")
    mb.cyl((0, 15.8, 0), 2.1, 2.1, 3.0, 16, "timber_old")                                # the tank
    for yy in (16.3, 17.5, 18.5):
        mb.cyl((0, yy, 0), 2.18, 2.18, 0.14, 16, "iron")
    mb.cyl((0, 18.8, 0), 2.1, 2.1, 0.1, 16, "brine")
    # the windlass at the head: cheek posts, an axle along z, a great wheel on +z, a drum
    mb.box((0, 27.4, 0), (hw(27.0) * 2 + 1.2, 0.5, hw(27.0) * 2 + 1.2), "timber_old")
    for sx in (-1, 1):
        mb.box((sx * 1.4, 29.6, 0.0), (0.4, 4.4, 1.2), "timber")
    mb.box((0, 31.0, 0.0), (3.6, 0.4, 1.4), "timber")
    mb.box((0, 29.0, 0.0), (3.2, 0.34, 0.34), "iron")                                    # the axle ... drawn across the cheeks
    wheel(mb, (0, 29.0, 1.25), 3.0, 'xy', spokes=10, rim=18, tw=0.3, th=0.28, hub=0.5)
    mb.cyl((0, 28.55, -0.3), 0.7, 0.7, 0.9, 10, "timber_old")
    mb.wedge((0, 31.2, 0), 4.2, 3.4, 1.4, "slate", ry=math.pi / 2)                       # a little roof on the cheeks
    beam(mb, (0, 27.8, -0.2), (0, 27.4, 4.6), 0.3, 0.34, "timber")                      # hoist beam
    mb.box((0, 25.0, 4.6), (0.05, 5.0, 0.05), "iron")
    mb.box((0, 22.3, 4.6), (0.5, 0.4, 0.5), "iron")
    # penstock (a sloped iron pipe from the tank's foot to the flume mouth) and a stand pipe on the house
    beam(mb, (0, 16.2, wp + 0.1), (0, 3.9, 8.4), 0.42, 0.42, "iron")
    mb.box((0, 3.4, 8.8), (1.6, 0.5, 1.6), "stone")
    mb.cyl((2.6, BH + 0.65, 2.0), 0.28, 0.28, 8.0, 8, "iron")
    # a ladder up one face
    xl = 0.0
    beam(mb, (xl - 0.4, base_y, w0 + 0.6), (xl - 0.4, 26.0, w1 + 0.4), 0.1, 0.1, "timber")
    beam(mb, (xl + 0.4, base_y, w0 + 0.6), (xl + 0.4, 26.0, w1 + 0.4), 0.1, 0.1, "timber")
    for i in range(int((26.0 - base_y) / 0.55)):
        yy = base_y + 0.3 + i * 0.55
        zz = w0 + 0.6 + (w1 + 0.4 - w0 - 0.6) * (yy - base_y) / (26.0 - base_y)
        mb.box((xl, yy, zz), (0.8, 0.07, 0.07), "timber")
    COL["pump_tower"] = [[0, BH / 2 + 0.3, 0, B + 1.0, BH + 0.6, B + 1.0, 0, 0, 0]] + \
        [[sx * 3.2, 9.0, sz * 3.2, 0.9, 8.0, 0.9, 0, 0, 0] for sx in (-1, 1) for sz in (-1, 1)] + \
        [[0, 21.0, 0, 3.6, 12.0, 3.6, 0, 0, 0]]
    return mb.build()


# ================================================================== the salt shed
def salt_shed():
    """A salt store at building scale: 10 x 15 m on a stone plinth, plank walls 4.8 m to the eaves, a slate gable to
    8.4 m, a 4.6 m double door in the gable end under a hoist beam, hatches along the long walls, a salt bin
    inside, a deep canopy on two posts over the door. Front is +z."""
    CURRENT[0] = "salt_shed"
    mb = MB("Salt_Shed")
    W, D, EH, PL = 10.0, 15.0, 4.8, 0.7
    mb.box((0, PL / 2 - 0.6, 0), (W + 0.9, PL + 1.2, D + 0.9), "stone")
    DW, DH = 4.6, 4.0
    wall(mb, 'x', (0, D / 2), W, 0.4, PL, EH, "timber_old", holes=[(0, DW, PL, DH)], col=False)
    wall(mb, 'x', (0, -D / 2), W, 0.4, PL, EH, "timber_old", col=False)
    hatch = [(u, 1.5, 1.7, 3.0) for u in (-4.5, 0.0, 4.5)]
    wall(mb, 'z', (W / 2, 0), D, 0.4, PL, EH, "timber_old", holes=hatch, col=False)
    wall(mb, 'z', (-W / 2, 0), D, 0.4, PL, EH, "timber_old", holes=hatch, col=False)
    mb.box((0, PL + 0.04, 0), (W - 0.4, 0.08, D - 0.4), "salt")
    # the frame outside the boards: posts every 2.5 m, plate and a sill rail, door lintel, knee braces at the door
    for face in (1, -1):
        zf = face * (D / 2 + 0.26)
        for i in range(5):
            x = -W / 2 + 0.1 + i * (W - 0.2) / 4
            if face == 1 and abs(x) < DW / 2 - 0.2:
                continue
            mb.box((x, (PL + EH) / 2, zf), (0.3, EH - PL, 0.2), "timber")
        mb.box((0, EH - 0.1, zf), (W + 0.6, 0.34, 0.24), "timber")
        mb.box((0, PL + 0.9, zf), (W + 0.4, 0.2, 0.2), "timber")
    for face in (1, -1):
        xf = face * (W / 2 + 0.26)
        for i in range(6):
            z = -D / 2 + 0.1 + i * (D - 0.2) / 5
            mb.box((xf, (PL + EH) / 2, z), (0.2, EH - PL, 0.3), "timber")
        mb.box((xf, EH - 0.1, 0), (0.24, 0.34, D + 0.6), "timber")
        mb.box((xf, PL + 0.9, 0), (0.2, 0.2, D + 0.4), "timber")
        for (u, w, v0, v1) in hatch:                                                    # a hatch: sill, lintel, a leaf hung open
            mb.box((xf, v0 - 0.08, u), (0.3, 0.14, w + 0.4), "timber")
            mb.box((xf, v1 + 0.1, u), (0.3, 0.2, w + 0.5), "timber")
            mb.box((xf + face * 0.3, (v0 + v1) / 2, u + w * 0.6), (0.06, v1 - v0, w * 0.5), "timber", rot=(0, 0, 0))
    for sgn in (-1, 1):
        mb.box((sgn * (DW / 2 + 0.25), (PL + DH) / 2 + 0.2, D / 2 + 0.28), (0.5, DH - PL + 0.4, 0.5), "timber")
        beam(mb, (sgn * (DW / 2 + 0.25), DH - 0.7, D / 2 + 0.28), (sgn * (DW / 2 - 0.9), DH + 0.05, D / 2 + 0.28), 0.2, 0.26, "timber")
    mb.box((0, DH + 0.3, D / 2 + 0.28), (DW + 1.2, 0.5, 0.5), "timber")
    mb.box((-1.15, 2.1, D / 2 + 0.55), (2.1, DH - 0.5, 0.12), "timber_old", rot=(0, 0.85, 0))      # the leaves, ajar
    mb.box((2.0, 2.1, D / 2 + 0.38), (2.1, DH - 0.5, 0.12), "timber_old", rot=(0, -0.2, 0))
    for yy in (1.2, 2.9):
        mb.box((-1.15, yy, D / 2 + 0.64), (2.1, 0.14, 0.05), "iron", rot=(0, 0.85, 0))
        mb.box((2.0, yy, D / 2 + 0.46), (2.1, 0.14, 0.05), "iron", rot=(0, -0.2, 0))
    # the roof: a deep gable with eaves, rafter ends and a ridge cap; a canopy over the door on two posts; a hoist
    ov = 1.0
    mb.wedge((0, EH, 0), W + 2 * ov, D + 1.4, 3.6, "slate", ry=0.0)
    mb.box((0, EH + 3.6 + 0.04, 0), (0.36, 0.2, D + 1.5), "timber")
    for i in range(int(D // 0.9) + 1):
        z = -D / 2 - 0.3 + i * (D + 0.6) / int(D // 0.9)
        for sgn in (-1, 1):
            beam(mb, (sgn * (W / 2 + 0.1), EH - 0.05, z), (sgn * (W / 2 + ov - 0.05), EH + 0.12, z), 0.12, 0.12, "timber")
    mb.wedge((0, 5.2, D / 2 + 3.3), W - 2.0, 5.4, 2.0, "slate", ry=0.0)
    for sgn in (-1, 1):
        mb.box((sgn * 3.4, 2.5, D / 2 + 4.9), (0.4, 5.0, 0.4), "timber")
        mb.box((sgn * 3.4, 0.2, D / 2 + 4.9), (0.9, 0.4, 0.9), "stone", col=False)
    mb.box((0, 4.9, D / 2 + 4.9), (7.4, 0.4, 0.4), "timber")
    beam(mb, (0, EH + 4.3, D / 2 + 0.3), (0, EH + 4.0, D / 2 + 2.5), 0.2, 0.2, "timber")
    mb.box((0, EH + 2.6, D / 2 + 2.5), (0.04, 2.8, 0.04), "iron")
    mb.box((0, EH + 1.1, D / 2 + 2.5), (0.5, 0.35, 0.5), "iron")
    # a bin of salt inside, seen through the door
    mb.blob((0, PL, -1.0), (3.9, 2.6, 4.6), "salt", seed=7)
    COL["salt_shed"] = [[0, PL / 2 - 0.2, 0, W + 0.9, PL + 0.4, D + 0.9, 0, 0, 0],
                        [-(DW / 2 + (W - DW) / 4), EH / 2, D / 2, (W - DW) / 2, EH, 0.6, 0, 0, 0], [(DW / 2 + (W - DW) / 4), EH / 2, D / 2, (W - DW) / 2, EH, 0.6, 0, 0, 0],
                        [0, EH / 2, -D / 2, W, EH, 0.6, 0, 0, 0], [-W / 2, EH / 2, 0, 0.6, EH, D, 0, 0, 0], [W / 2, EH / 2, 0, 0.6, EH, D, 0, 0, 0],
                        [-3.4, 2.5, D / 2 + 4.9, 0.5, 5.0, 0.5, 0, 0, 0], [3.4, 2.5, D / 2 + 4.9, 0.5, 5.0, 0.5, 0, 0, 0]]
    return mb.build()


# ================================================================== the drying rack
def drying_rack():
    """A long rack: two rows of posts, three tiers of rails hung with salt-crusted cloth and rope, a low shingled
    hat. 12 m long (x), 2.4 m deep, 4.2 m high."""
    CURRENT[0] = "drying_rack"
    mb = MB("Drying_Rack")
    L, Dp, H = 12.0, 2.4, 4.2
    n = 5
    xs = [-L / 2 + 0.3 + i * (L - 0.6) / n for i in range(n + 1)]
    for x in xs:
        for z in (-Dp / 2, Dp / 2):
            mb.box((x, H / 2, z), (0.28, H, 0.28), "timber")
            mb.box((x, 0.2, z), (0.6, 0.4, 0.6), "stone", col=False)
        mb.box((x, H - 0.1, 0), (0.24, 0.24, Dp + 0.3), "timber")
        for sz in (-1, 1):
            beam(mb, (x, H - 0.9, sz * Dp / 2), (x, H - 0.1, sz * (Dp / 2 - 0.9)), 0.14, 0.16, "timber")
    for z in (-Dp / 2, Dp / 2):
        mb.box((0, H - 0.1, z), (L + 0.4, 0.26, 0.24), "timber")
        for yy in (1.5, 2.45, 3.4):
            mb.box((0, yy, z), (L, 0.12, 0.12), "timber")
            for i in range(int(L / 0.62)):
                x = -L / 2 + 0.4 + i * 0.62
                hgt = 0.7 + 0.35 * ((i * 7 + int(yy * 10)) % 3)
                mb.box((x, yy - hgt / 2 - 0.05, z + 0.05 * ((i % 2) * 2 - 1)), (0.3, hgt, 0.07), "salt")
    mb.wedge((0, H, 0), Dp + 1.6, L + 0.8, 0.8, "slate", ry=math.pi / 2)
    COL["drying_rack"] = [[x, H / 2, z, 0.34, H, 0.34, 0, 0, 0] for x in xs for z in (-Dp / 2, Dp / 2)]
    return mb.build()


# ================================================================== flumes, channels, sluices
FL_H = 3.2          # the flume's underside above the ground: a man walks under it


def trough(mb, L, y0, with_ties=True):
    mb.box((0, y0 + 0.1, 0), (L, 0.2, 1.7), "timber_old")
    for sz in (-1, 1):
        mb.box((0, y0 + 0.55, sz * 0.78), (L, 0.7, 0.18), "timber")
        mb.box((0, y0 + 0.92, sz * 0.78), (L, 0.1, 0.3), "timber_old")
    mb.box((0, y0 + 0.5, 0), (L - 0.06, 0.04, 1.4), "brine")
    if with_ties:
        n = max(2, int(L / 1.25))
        for i in range(n + 1):
            mb.box((-L / 2 + i * L / n, y0 + 0.2, 0), (0.18, 0.16, 2.1), "timber")


def flume(L, name):
    CURRENT[0] = name.lower()
    mb = MB(name)
    trough(mb, L, FL_H)
    if L > 7:                                                                            # an underslung truss: two king posts
        for sz in (-1, 1):
            beam(mb, (-L / 2 + 0.3, FL_H, sz * 0.85), (0, FL_H - 1.5, sz * 0.85), 0.22, 0.26, "timber")
            beam(mb, (L / 2 - 0.3, FL_H, sz * 0.85), (0, FL_H - 1.5, sz * 0.85), 0.22, 0.26, "timber")
            mb.box((0, FL_H - 0.75, sz * 0.85), (0.2, 1.5, 0.2), "iron")
    return mb.build()


def flume_bent():
    """A trestle bent for a flume running along x: two splayed legs on stone feet, a cap, knee braces."""
    CURRENT[0] = "flume_bent"
    mb = MB("Flume_Bent")
    for sz in (-1, 1):
        beam(mb, (0, 0.0, sz * 1.6), (0, FL_H, sz * 0.95), 0.34, 0.34, "timber")
        mb.box((0, 0.22, sz * 1.62), (0.9, 0.44, 0.9), "stone")
        beam(mb, (0, 1.0, sz * 1.45), (0, FL_H - 0.2, sz * 0.2), 0.14, 0.16, "timber")
    mb.box((0, FL_H - 0.1, 0), (0.4, 0.3, 2.6), "timber")
    mb.box((0, 1.4, 0), (0.2, 0.2, 2.9), "timber")
    for sz in (-1, 1):
        mb.box((0, FL_H - 0.1, sz * 0.95), (0.5, 0.22, 0.5), "iron")
    COL["flume_bent"] = [[0, 1.6, sz * 1.3, 0.5, 3.2, 0.5, 0, 0, 0] for sz in (-1, 1)]
    return mb.build()


def flume_end():
    """The flume's mouth: a stone cistern 3.6 x 3.6 x 1.5 with a lip, brine in it, steps up the side. The spill is +x."""
    CURRENT[0] = "flume_end"
    mb = MB("Flume_End")
    mb.box((0, 0.7, 0), (3.8, 1.4, 3.8), "stone", col=True)
    mb.box((0, 1.45, 0), (4.1, 0.2, 4.1), "stone_dark")
    mb.box((0, 1.5, 0), (3.2, 0.06, 3.2), "brine")
    return mb.build()


def channel(L, name):
    CURRENT[0] = name.lower()
    mb = MB(name)
    mb.box((0, 0.22, 0), (L, 0.44, 1.8), "stone_dark")
    for sz in (-1, 1):
        mb.box((0, 0.33, sz * 0.82), (L, 0.44, 0.34), "stone")
    mb.box((0, 0.3, 0), (L, 0.04, 1.2), "brine")
    return mb.build()


def sluice():
    """A gate across a channel: two stone cheeks, a timber frame 2.6 m high, a lifted board, an iron hand wheel and a rack."""
    CURRENT[0] = "sluice"
    mb = MB("Sluice_Gate")
    L = 3.0
    mb.box((0, 0.22, 0), (L, 0.44, 1.8), "stone_dark")
    for sz in (-1, 1):
        mb.box((0, 0.33, sz * 0.82), (L, 0.44, 0.34), "stone")
        mb.box((0, 1.1, sz * 0.9), (0.4, 2.2, 0.36), "timber")
    mb.box((0, 2.3, 0), (0.44, 0.3, 2.3), "timber")
    mb.box((0, 1.25, 0), (0.1, 1.4, 1.2), "timber_old")
    mb.box((0, 1.9, 0.0), (0.06, 0.8, 0.14), "iron")
    wheel(mb, (0.36, 2.9, 0.0), 0.5, 'zy', spokes=6, rim=10, tw=0.07, th=0.07, mat="iron", hub=0.12)
    mb.box((0, 0.3, 0), (L, 0.04, 1.2), "brine")
    COL["sluice"] = [[0, 1.1, sz * 0.9, 0.4, 2.2, 0.36, 0, 0, 0] for sz in (-1, 1)]
    return mb.build()


def kerb():
    """A causeway kerb: 3 m of cut stone, a chamfered cap, set in the ground; the road is on its +x side."""
    CURRENT[0] = "kerb"
    mb = MB("Kerb_3")
    mb.box((0, 0.2, 0), (3.0, 0.5, 0.5), "stone")
    mb.box((0, 0.46, 0), (3.04, 0.08, 0.58), "stone_dark")
    for i in (-1, 1):
        mb.box((i * 1.5, 0.35, 0), (0.08, 0.7, 0.62), "stone_dark")
    return mb.build()


# ================================================================== carts, sledges, heaps
def salt_cart():
    """A two-wheeled salt cart with shafts, side boards and a load of cut blocks under a cloth. Shafts point +z."""
    CURRENT[0] = "salt_cart"
    mb = MB("Salt_Cart")
    mb.box((0, 1.25, -0.2), (1.9, 0.14, 3.2), "timber_old")
    for sx in (-1, 1):
        mb.box((sx * 0.9, 1.65, -0.2), (0.1, 0.8, 3.2), "timber")
        wheel(mb, (sx * 1.15, 1.0, -0.2), 1.0, 'zy', spokes=10, rim=14, tw=0.14, th=0.2, hub=0.2)
        mb.box((sx * 1.0, 1.0, -0.2), (0.4, 0.2, 0.2), "iron")
    for sz in (-1, 1):
        mb.box((0, 1.65, -0.2 + sz * 1.55), (1.9, 0.8, 0.1), "timber")
    mb.box((0, 1.0, -0.2), (2.2, 0.12, 0.12), "iron")
    for sx in (-1, 1):
        beam(mb, (sx * 0.55, 1.2, 0.8), (sx * 0.5, 0.95, 3.6), 0.14, 0.16, "timber")
    mb.box((0, 0.95, 3.6), (1.1, 0.1, 0.1), "timber")
    for r in range(2):
        for i in range(4):
            mb.box((-0.6 + i * 0.4 + 0.2 * (r % 2), 1.6 + r * 0.38, -0.7 + r * 0.25), (0.34, 0.34, 0.5), "salt")
    mb.blob((0, 1.35, 0.2), (0.8, 0.5, 1.2), "salt", seed=3)
    COL["salt_cart"] = [[0, 1.1, -0.2, 2.4, 1.2, 3.3, 0, 0, 0]]
    return mb.build()


def sledge():
    """A salt sledge: two curved runners, cross bearers, a deck stacked with blocks, a rope bridle. Pulled toward +z."""
    CURRENT[0] = "sledge"
    mb = MB("Sledge")
    for sx in (-1, 1):
        mb.box((sx * 0.8, 0.2, 0), (0.22, 0.34, 3.0), "timber_old")
        mb.box((sx * 0.8, 0.12, 0), (0.12, 0.08, 3.1), "iron")
        beam(mb, (sx * 0.8, 0.2, 1.5), (sx * 0.8, 0.55, 1.95), 0.2, 0.24, "timber_old")
    for z in (-1.2, -0.4, 0.4, 1.2):
        mb.box((0, 0.5, z), (2.0, 0.14, 0.24), "timber")
    mb.box((0, 0.64, 0), (1.8, 0.1, 2.8), "timber_old")
    for r in range(3):
        for c in range(3):
            mb.box((-0.55 + c * 0.55, 0.9 + r * 0.38, -0.6 + 0.1 * r), (0.5, 0.34, 0.9), "salt")
    beam(mb, (-0.8, 0.5, 1.9), (0.0, 0.5, 3.0), 0.05, 0.05, "iron")
    beam(mb, (0.8, 0.5, 1.9), (0.0, 0.5, 3.0), 0.05, 0.05, "iron")
    COL["sledge"] = [[0, 0.9, 0, 2.0, 1.4, 3.0, 0, 0, 0]]
    return mb.build()


def block_stack():
    """A stack of cut salt blocks, laid in courses and stepped back, a plank on top: 3.2 x 1.6, 2.0 m high."""
    CURRENT[0] = "block_stack"
    mb = MB("Block_Stack")
    for r in range(5):
        nx = 6 - r
        for i in range(nx):
            for j in (-1, 1):
                mb.box((-(nx - 1) * 0.27 + i * 0.54, 0.2 + r * 0.38, j * 0.4 + (0.03 if (i + r) % 2 else -0.03)), (0.5, 0.36, 0.76), "salt")
    mb.box((0, 2.0, 0), (2.0, 0.08, 1.7), "timber_old")
    COL["block_stack"] = [[0, 1.0, 0, 3.2, 2.0, 1.7, 0, 0, 0]]
    return mb.build()


def salt_bin():
    """A plank-walled bin on a stone sill with a heaped mound of salt well over the walls: 7 x 5.5 m, 4 m high.
    Open to +z."""
    CURRENT[0] = "salt_bin"
    mb = MB("Salt_Bin")
    mb.box((0, 0.15, 0), (7.4, 0.3, 5.9), "stone_dark")
    for (c, s) in (((0, 1.2, -2.7), (7.0, 2.2, 0.22)), ((-3.4, 1.2, 0), (0.22, 2.2, 5.4)), ((3.4, 1.2, 0), (0.22, 2.2, 5.4))):
        mb.box(c, s, "timber_old")
    for x in (-3.4, 0, 3.4):
        mb.box((x, 1.3, -2.7), (0.3, 2.6, 0.3), "timber")
    for z in (-2.7, 0.0, 2.7):
        for sx in (-1, 1):
            mb.box((sx * 3.4, 1.3, z), (0.3, 2.6, 0.3), "timber")
    for yy in (0.5, 1.0):
        mb.box((0, yy, 2.78), (6.6, 0.2, 0.18), "timber")                                # the dropped boards at the front
    mb.blob((0, 0.3, -0.2), (3.5, 3.6, 2.7), "salt", seed=5)
    mb.blob((-1.6, 0.3, 1.2), (1.6, 1.3, 1.3), "salt", seed=8)
    COL["salt_bin"] = [[0, 1.2, -2.7, 7.0, 2.4, 0.4, 0, 0, 0], [-3.4, 1.2, 0, 0.4, 2.4, 5.6, 0, 0, 0], [3.4, 1.2, 0, 0.4, 2.4, 5.6, 0, 0, 0], [0, 1.6, -0.4, 5.6, 3.2, 4.0, 0, 0, 0]]
    return mb.build()


def salt_mound():
    """A heaped mound as big as a cart house: 8 x 6 m, 3.6 m high, with two smaller heaps against it and a shovel left in."""
    CURRENT[0] = "salt_mound"
    mb = MB("Salt_Mound")
    mb.blob((0, 0, 0), (4.0, 3.6, 3.2), "salt", seed=11)
    mb.blob((2.6, 0, 1.4), (2.2, 1.7, 1.9), "salt", seed=14)
    mb.blob((-2.4, 0, -1.4), (2.0, 1.5, 1.7), "salt", seed=17)
    beam(mb, (1.0, 2.6, 1.5), (1.7, 4.3, 2.8), 0.07, 0.07, "timber")
    mb.box((1.0, 2.5, 1.45), (0.5, 0.05, 0.4), "iron", rot=(0.5, 0, 0))
    COL["salt_mound"] = [[0, 1.5, 0, 6.6, 3.0, 5.4, 0, 0, 0]]
    return mb.build()


def write_boxes_works():
    def fmt(v):
        if len(v) == 9:
            q = Euler((v[6], v[7], v[8]), 'XYZ').to_quaternion()
            v = list(v[:6]) + [q.x, q.y, q.z, q.w]
        return "[" + ", ".join(("%g" % x) for x in v) + "]"
    lines = ["extends RefCounted", "## GENERATED by tools/blender/r37_east_works.py: collision boxes [cx, cy, cz, sx, sy, sz, qx, qy, qz, qw]",
             "## taken from the meshes' own numbers (local to each asset's origin). Do not edit.", ""]
    for nm, rows in sorted(COL.items()):
        lines.append("const %s := [" % (nm.upper() + "_BOXES"))
        for r in rows:
            lines.append("\t" + fmt(r) + ",")
        lines.append("]")
    lines.append("")
    open(os.path.join(ROOT, "core/world/realm/east_works_boxes.gd"), "w").write("\n".join(lines))


def main_works():
    wipe()
    build_materials()
    pt = pump_tower()
    objs = [pt, salt_shed(), drying_rack(), flume(5.0, "Flume_5"), flume(10.0, "Flume_10"), flume_bent(), flume_end(), channel(6.0, "Channel_6"),
            sluice(), kerb(), salt_cart(), sledge(), block_stack(), salt_bin(), salt_mound()]
    export(objs, os.path.join(ROOT, "art/models/r37e_works.glb"))
    write_boxes_works()
    if PREVIEW:
        render_works(PREVIEW)


def render_works(prefix):
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_WORKBENCH'
    sc.display.shading.color_type = 'TEXTURE'
    sc.display.shading.light = 'STUDIO'
    sc.display.shading.show_cavity = False
    sc.render.resolution_x, sc.render.resolution_y = 1000, 1000
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", 'SUN'))
    sun.rotation_euler = (0.9, 0.2, 0.6)
    sc.world = bpy.data.worlds.new('w')
    sc.world.color = (0.5, 0.5, 0.55)
    sun.data.energy = 3.0
    sc.collection.objects.link(sun)
    cam.data.clip_end = 400
    shots = {"Pump_Tower": [((38, 22, 46), (0, 14, 0), "tower"), ((9, 3, 14), (0, 2.5, 4), "tower_door"), ((14, 29, 16), (0, 27, 0), "tower_head")],
             "Salt_Shed": [((22, 6, 30), (0, 3.4, 0), "shed"), ((-20, 9, -12), (0, 3, 0), "shed_back")],
             "Drying_Rack": [((10, 4, 11), (0, 2, 0), "rack")],
             "Flume_10": [((10, 3.5, 12), (0, 3.6, 0), "flume")],
             "Flume_Bent": [((6, 2.5, 7), (0, 1.8, 0), "bent")],
             "Sluice_Gate": [((5, 3, 6), (0, 1.4, 0), "sluice")],
             "Salt_Cart": [((6, 2.5, 7), (0, 1.1, 1), "cart")],
             "Sledge": [((5, 2.5, 6), (0, 0.7, 0.5), "sledge")],
             "Block_Stack": [((5, 2.5, 6), (0, 1.0, 0), "stack")],
             "Salt_Bin": [((11, 5, 12), (0, 1.6, 0), "bin")],
             "Salt_Mound": [((12, 5, 12), (0, 1.8, 0), "mound")],
             "Flume_End": [((6, 3, 6), (0, 0.8, 0), "cistern")],
             "Channel_6": [((6, 2, 6), (0, 0.3, 0), "channel")],
             "Kerb_3": [((4, 2, 4), (0, 0.3, 0), "kerb")]}
    for o in bpy.data.objects:
        if o.type == 'MESH':
            o.hide_render = True
    for o in list(bpy.data.objects):
        if o.name in shots:
            for (loc, tgt, name) in shots[o.name]:
                for q in bpy.data.objects:
                    if q.type == 'MESH':
                        q.hide_render = q is not o
                loc = (loc[0], -loc[2], loc[1])
                tgt = (tgt[0], -tgt[2], tgt[1])
                cam.location = loc
                cam.rotation_euler = (Vector(tgt) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
                sc.render.filepath = prefix + "_" + name + ".png"
                bpy.ops.render.render(write_still=True)


main_works()
