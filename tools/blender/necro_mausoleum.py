"""The First Pilgrims' Tomb in the Waiting Field (core/world/realm/realm_pois_doubled_realm.gd _necro_mausoleum), modelled: the
map audit's F28 ("the mausoleum": kit boxes). The LOOK only: the game keeps the kit's boxes with its visual off for the
colliders, and its own vault floor, both stairs, candles, chest, lore and light.

  tools/blender/run.sh necro_mausoleum.py -- [--preview DIR]

  necro_mausoleum.glb   the podium (10.6 x 8.8, 2.8 high) in coursed masonry on a moulded plinth under a cornice, the
                        burial vault inside it (its inner faces dressed, the stair's well open in its deck), three stone
                        coffins with lids; the tomb house on the podium (8.4 x 6.2, 4 m walls) with corner pilasters, the
                        door under a carved lintel and a tympanum with a cross, the flat stone roof on a cornice, its stepped attic
                        at the back; the porch's two columns (bases, shafts, capitals) under the roof's front; the fallen
                        ashlar blocks the climb uses on the west side.

Frame: the tomb's own (x across, y up, z toward the door, +z), origin at its floor; Blender (x, y, z) = (x, -z, y).
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mathutils import Vector
from reach_west_lib import *     # noqa: F401,F403
import reach_west_lib as L

POD_H = 2.8
TOMB_H = 4.0
PX, PZ0, PZ1, T = 5.2, -6.0, 2.6, 0.6
TX, TZ0, TZ1 = 4.2, -5.6, 0.6


def G(x, y, z):
    return Vector((x, -z, y))


def wallz(P, rnd, x, z0, z1, y0, h, t, solid=lambda u, v: True, faces=(1, -1)):
    """A wall along the game's z at x (plan a -> b in Blender: (x, -z0) -> (x, -z1))."""
    L.wall_run(P, None, "ashlar", (x, -z0), (x, -z1), y0, h, t, solid, rnd, ch=0.5, col=False, blk=(0.7, 1.4), dress_ends=True, faces=faces)


def wallx(P, rnd, z, x0, x1, y0, h, t, solid=lambda u, v: True, faces=(1, -1)):
    L.wall_run(P, None, "ashlar", (x0, -z), (x1, -z), y0, h, t, solid, rnd, ch=0.5, col=False, blk=(0.7, 1.4), dress_ends=True, faces=faces)


def moulding(P, key, x0, x1, z0, z1, y, h, out):
    """A moulded band round a rectangle (a plinth, a cornice): a box proud by `out` all round."""
    box(P, key, G((x0 + x1) * 0.5, y + h * 0.5, (z0 + z1) * 0.5), (x1 - x0 + 2 * out, z1 - z0 + 2 * out, h))


def asset():
    reset()
    P = Parts()
    rnd = L.rnd_for(34011)
    L.mason_begin(34011)
    # the podium: a plinth course proud of the walls, the four walls (outer and inner faces: the vault), a cornice
    moulding(P, "hewn", -PX, PX, PZ0, PZ1, -0.6, 0.85, 0.22)
    moulding(P, "hewn", -PX, PX, PZ0, PZ1, 0.25, 0.14, 0.1)
    wallz(P, rnd, -PX + T * 0.5, PZ0, PZ1, 0.0, POD_H, T)
    wallz(P, rnd, PX - T * 0.5, PZ0, PZ1, 0.0, POD_H, T)
    wallx(P, rnd, PZ0 + T * 0.5, -PX + T, PX - T, 0.0, POD_H, T)
    wallx(P, rnd, PZ1 - T * 0.5, -PX + T, PX - T, 0.0, POD_H, T)
    moulding(P, "hewn", -PX, PX, PZ0, PZ1, POD_H - 0.05, 0.22, 0.16)
    # the vault's deck: great slabs, the stair's well (x 1.9 .. 3.5, z -4.6 .. 0) left open
    iz0, iz1 = PZ0 + T, PZ1 - T
    for (x0, x1, z0, z1) in ((-PX + T, 1.9, iz0, iz1), (3.5, PX - T, iz0, iz1), (1.9, 3.5, iz0, -4.6), (1.9, 3.5, 0.0, iz1)):
        nx = max(1, int((x1 - x0) / 2.2 + 0.5))
        for i in range(nx):
            a0 = x0 + (x1 - x0) * i / nx
            a1 = x0 + (x1 - x0) * (i + 1) / nx
            L.dbox(P, "ashlar", tuple(G((a0 + a1) * 0.5, POD_H - 0.15, (z0 + z1) * 0.5)), (a1 - a0 - 0.03, z1 - z0 - 0.03, 0.3), bevel=0.04)
    # three coffins of the first pilgrims, feet to the mountain, their lids carved with a cross
    for i in range(3):
        cz = -4.4 + 1.9 * i
        L.dbox(P, "ashlar", tuple(G(-1.4, 0.45, cz)), (2.4, 1.0, 0.8), bevel=0.05, warp=0.01)
        L.dbox(P, "ashlar", tuple(G(-1.4, 0.92, cz)), (2.5, 1.1, 0.14), yaw=0.03 * (i - 1), bevel=0.03)
        box(P, "hewn", G(-1.4, 1.0, cz), (1.6, 0.12, 0.04))
        box(P, "hewn", G(-1.85, 1.0, cz), (0.1, 0.6, 0.04))
    # the tomb house: the side and back walls, the front with its door (x +-0.8, to 2.8 over the deck)
    hy = POD_H
    wallz(P, rnd, -TX + T * 0.5, TZ0, TZ1, hy, TOMB_H, T)
    wallz(P, rnd, TX - T * 0.5, TZ0, TZ1, hy, TOMB_H, T)
    wallx(P, rnd, TZ0 + T * 0.5, -TX + T, TX - T, hy, TOMB_H, T)
    wallx(P, rnd, TZ1 - T * 0.5, -TX, TX, hy, TOMB_H, T, solid=lambda u, v: not (L.rect_hole(u, v, TX, 1.6, 0.0, 2.8)))
    # corner pilasters, a carved lintel over the door and a relieving arch of voussoirs over it
    for sx in (-1.0, 1.0):
        for z in (TZ0 + 0.3, TZ1 - 0.3):
            L.dbox(P, "ashlar", tuple(G(sx * (TX - 0.05), hy + TOMB_H * 0.5, z)), (0.7, 0.7, TOMB_H), bevel=0.05)
    box(P, "hewn", G(0.0, hy + 2.95, TZ1 + 0.02), (2.2, 0.66, 0.4))
    for j in range(5):
        box(P, "hewn", G(-0.8 + 0.4 * j, hy + 2.95, TZ1 + 0.24), (0.06, 0.06, 0.4))
    box(P, "hewn", G(0.0, hy + 3.62, TZ1 + 0.04), (1.8, 0.7, 0.16))          # the tympanum over it, a cross in relief
    box(P, "hewn", G(0.0, hy + 3.62, TZ1 + 0.14), (0.12, 0.56, 0.06))
    box(P, "hewn", G(0.0, hy + 3.7, TZ1 + 0.14), (0.5, 0.12, 0.06))
    for sx in (-1.0, 1.0):                                       # the door's jambs
        L.dbox(P, "ashlar", tuple(G(sx * 0.92, hy + 1.4, TZ1 - 0.25)), (0.26, 0.72, 2.8), bevel=0.03)
    # the roof: a cornice on the walls, the flat stone roof (the kit's slab to 7.16), its stepped attic at the back
    ry = hy + TOMB_H
    moulding(P, "hewn", -TX, TX, TZ0, TZ1, ry - 0.3, 0.3, 0.2)
    zf = (TZ0 + TZ1) * 0.5 + 0.55 + (TZ1 - TZ0 + 1.7) * 0.5
    zb = (TZ0 + TZ1) * 0.5 + 0.55 - (TZ1 - TZ0 + 1.7) * 0.5
    nx = 4
    for i in range(nx):
        a0 = -TX + 2 * TX * i / nx
        a1 = -TX + 2 * TX * (i + 1) / nx
        L.dbox(P, "ashlar", tuple(G((a0 + a1) * 0.5, ry + 0.18, (zf + zb) * 0.5)), (a1 - a0 - 0.03, zf - zb, 0.36), bevel=0.05)
    box(P, "slate", G(0.0, ry + 0.37, (zf + zb) * 0.5), (2 * TX - 0.3, zf - zb - 0.3, 0.02))
    for row in range(3):
        w = (TX * 2.0) * (1.0 - row / 3.4)
        L.dbox(P, "ashlar", tuple(G(0.0, ry + 0.36 + 0.22 + 0.36 * row, TZ0 + 0.4)), (w, 0.5, 0.36), bevel=0.04)
    # the porch: two columns before the door holding the roof's front edge (kit r 0.32 .. 0.28 at x +-2.4, z 1.7)
    for sx in (-1.0, 1.0):
        c = (sx * 2.4, TZ1 + 1.1)
        L.dbox(P, "ashlar", tuple(G(c[0], hy + 0.15, c[1])), (0.8, 0.8, 0.3), bevel=0.04)
        cyl(P, "hewn", G(c[0], hy + 0.3, c[1]), G(c[0], hy + 0.42, c[1]), 0.38, 0.34, seg=14)
        cyl(P, "hewn", G(c[0], hy + 0.42, c[1]), G(c[0], ry - 0.45, c[1]), 0.31, 0.27, seg=14)
        cyl(P, "hewn", G(c[0], ry - 0.45, c[1]), G(c[0], ry - 0.3, c[1]), 0.3, 0.38, seg=14)
        L.dbox(P, "ashlar", tuple(G(c[0], ry - 0.15, c[1])), (0.82, 0.82, 0.3), bevel=0.03)
    box(P, "hewn", G(0.0, ry - 0.15, TZ1 + 1.1), (5.6, 0.5, 0.3))
    # the fallen ashlar the climb uses on the west (kit [-6.4, 0.6, 1.6], [-6.4, -0.9, 3.2], [-6.4, -2.4, 4.8], [-4.7, -2.4, 6.0])
    for (x, z, top, sx, sz) in ((-PX - 1.2, 0.6, 1.6, 2.2, 1.5), (-PX - 1.2, -0.9, 3.2, 2.2, 1.5), (-PX - 1.2, -2.4, 4.8, 2.2, 1.5)):
        hgt = top + 1.2
        L.dbox(P, "ashlar", tuple(G(x, top - hgt * 0.5, z)), (sx, sz, hgt), yaw=rnd.uniform(-0.04, 0.04), bevel=0.07, warp=0.03)
    L.dbox(P, "ashlar", tuple(G(-PX + 0.5, (6.0 + POD_H) * 0.5, -2.4)), (1.0, 1.5, 6.0 - POD_H), bevel=0.06, warp=0.02)
    objs = finish(P, "Tomb") + L.mason_end("TombMasonry")
    print("TOMB %d tris" % sum(tris(o) for o in objs))
    export(objs, os.path.join(MODELS, "necro_mausoleum.glb"), "mausoleum")
    preview(objs, "mausoleum", [((14, -16, 9), (0, 1, 3), 30), ((-15, 12, 10), (0, 1, 3), 30), ((3, -9, 4.2), (0, 0, 4.2), 30)], size=(800, 500))


asset()
