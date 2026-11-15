"""The Castellum: the aqueduct's water tower at its west end (art/models/reach_s_castellum.glb).

Frame: origin at the middle of the tower on the floor of its top chamber (z = 0, where the channel's walkway arrives
through the east wall); the ground floor and the door are at z = -15. A square tower 9 m wide, walls 1.5 m thick,
a cantilevered stair winding three turns up inside it (SW corner to SW corner, counter-clockwise from above), a top
chamber with a cistern basin and arcaded lights, a cornice on corbels, a hipped slate roof half fallen in.
Parts: Tower (+ colonly), Roof, TowerFar, Foot (the buried footing, to put under the tower on any ground),
FootCourse (one rusticated course to stack under the foot when the ground falls away).
"""
import math
import random

import reach_south_lib as L
import reach_south_masonry as M
from reach_south_lib import bpy, bmesh, Vector, Matrix, noise, Parts, stone, wedge, quad_strip_box, prism_polygon

HW = 4.5
WT = 1.5
INT = HW - WT          # 3.0
Z_BASE = -15.5
Z_GROUND = -15.0
Z_WALL = 5.2
RISE = 0.25


def walls(P, r, coll):
    ops_n = [{"xc": 0.0, "w": 2.4, "z0": Z_GROUND, "h": 3.7, "arch": True}]
    ops_s = []
    ops_e = [{"xc": 0.0, "w": 2.6, "z0": 0.0, "h": 3.8, "arch": True}]
    ops_w = []
    # slit windows up the shaft (splayed, narrow), one a turn on each side, staggered
    for zc, side in ((-12.2, "n"), (-9.0, "s"), (-6.0, "w"), (-2.8, "n"), (-0.8, "s"), (-13.4, "w"), (-3.5, "e"), (-10.5, "e")):
        op = {"xc": 1.2 if side in ("n", "w") else -1.2, "w": 0.56, "z0": zc, "h": 1.6, "arch": True}
        {"n": ops_n, "s": ops_s, "w": ops_w, "e": ops_e}[side].append(op)
    # the cistern chamber's arcaded lights
    for xc in (-2.0, 2.0):
        for lst in (ops_n, ops_s):
            lst.append({"xc": xc, "w": 1.9, "z0": 0.7, "h": 3.7, "arch": True, "sill": True})
    ops_w.append({"xc": 0.0, "w": 2.2, "z0": 0.7, "h": 3.7, "arch": True, "sill": True})
    faces = [("n", ops_n, 0.0, 0.0, HW - WT * 0.5, -HW, HW, 4, 11), ("s", ops_s, math.pi, 0.0, -(HW - WT * 0.5), -HW, HW, 4, 12),
             ("e", ops_e, -math.pi * 0.5, HW - WT * 0.5, 0.0, -INT, INT, 0, 13), ("w", ops_w, math.pi * 0.5, -(HW - WT * 0.5), 0.0, -INT, INT, 0, 14)]
    for (nm, ops, yaw, px, py, xa, xb, ivn, sd) in faces:
        S = Parts()
        rr = random.Random(sd)
        M.masonry_wall(S, rr, xa, xb, Z_BASE, Z_WALL, WT, ops, rust_h=6.0, ivy_n=0, quoins=nm in ("n", "s"), coll=coll,
                       sides=(0, 1) if True else (1, 1), top_jag=0.0)
        # the inner face too (the interior is seen): blocks on the -y side as well
        if not coll:
            S2 = Parts()
            M.masonry_wall(S2, random.Random(sd + 40), xa, xb, Z_BASE, Z_WALL, WT, ops, sides=(1, 0), quoins=False, rust_h=0.0, row_h=(0.5, 0.7), lens=(0.9, 1.7))
            for k, bm in S2.bm.items():
                if k == "stone":
                    continue
            # only the inner blocks of the second pass are kept (its core and rings duplicate the first's): drop them
            for k in list(S2.bm.keys()):
                if k in ("stone", "stone_ivy"):
                    S2.bm[k].free()
                    del S2.bm[k]
            M.merge(P, S2, M.xf(yaw, px, py, 0.0))
        M.merge(P, S, M.xf(yaw, px, py, 0.0))
    # string courses round the shaft: over the rustication, then every ~6 m, and the great cornice under the eaves
    for z in (-9.1, -3.6):
        for (yaw, off, ln) in ((0.0, HW - WT * 0.5, HW + 0.2), (math.pi, -(HW - WT * 0.5), HW + 0.2)):
            S = Parts()
            M.cornice(S, random.Random(int(z * 10)), -ln, ln, 0.0, WT, h=0.36, proj=0.5, dentils=False)
            M.merge(P, S, M.xf(yaw, 0.0, off, z))
        for (yaw, off) in ((-math.pi * 0.5, HW - WT * 0.5), (math.pi * 0.5, -(HW - WT * 0.5))):
            S = Parts()
            M.cornice(S, random.Random(int(z * 10) + 1), -HW, HW, 0.0, WT, h=0.36, proj=0.5, dentils=False)
            M.merge(P, S, M.xf(yaw, off, 0.0, z))
    r2 = random.Random(5)
    for (yaw, px, py, ln) in ((0.0, 0.0, HW - WT * 0.5, HW + 0.5), (math.pi, 0.0, -(HW - WT * 0.5), HW + 0.5), (-math.pi * 0.5, HW - WT * 0.5, 0.0, HW + 0.5), (math.pi * 0.5, -(HW - WT * 0.5), 0.0, HW + 0.5)):
        S = Parts()
        M.cornice(S, r2, -ln, ln, 0.0, WT, h=0.7, proj=0.9)
        # corbels under it
        if not coll:
            n = int(2 * ln / 0.9)
            for i in range(n):
                x = -ln + (i + 0.5) * 2 * ln / n
                stone(S, "ashlar", (x, WT * 0.5 + 0.2, -0.28), (0.34, 0.6, 0.5), r=r2, j=0.01)
                stone(S, "ashlar", (x, WT * 0.5 + 0.1, -0.66), (0.3, 0.38, 0.3), r=r2, j=0.01)
        M.merge(P, S, M.xf(yaw, px, py, Z_WALL))


def stair(P, r, coll):
    """Floors and the cantilevered stair."""
    # the ground floor
    stone(P, "ashlar", (0, 0, Z_BASE + 0.25), (2 * INT + 1.0, 2 * INT + 1.0, 0.5), r=r, j=0.0)
    if not coll:
        for i in range(-2, 3):
            for k in range(-2, 3):
                stone(P, "ashlar", (i * 1.2, k * 1.2, Z_GROUND + 0.005), (1.16, 1.16, 0.02), r=r, j=0.01)
    c = INT - 0.7                      # the landings' centres
    corners = [(-c, -c), (c, -c), (c, c), (-c, c)]      # SW, SE, NE, NW (counter-clockwise from above)
    h = Z_GROUND
    sides = [(0, 1), (1, 2), (2, 3), (3, 0)]
    for turn in range(3):
        for (a, b) in sides:
            pa = Vector(corners[a])
            pb = Vector(corners[b])
            d = (pb - pa).normalized()
            n = (pb - pa).length
            # the corner landing at the start of the run, then four steps along it
            stone(P, "ashlar", (pa.x, pa.y, h - 0.25), (1.4 + 0.3, 1.4 + 0.3, 0.5), r=r, j=0.008)
            for i in range(4):
                hh = h + RISE * (i + 1)
                p = pa + d * (1.4 * 0.5 + (n - 1.4) * (i + 0.5) / 4.0 + 0.05)
                w = (n - 1.4) / 4.0
                sx = w if abs(d.x) > 0.5 else 1.6
                sy = w if abs(d.y) > 0.5 else 1.6
                stone(P, "ashlar", (p.x, p.y, hh - 0.25), (sx - 0.02, sy - 0.02, 0.5), r=r, j=0.008)
            h += RISE * 5
    # the last landing (SW, z = 0) and the top floor: the inside minus the north and west strips the last runs climb in
    stone(P, "ashlar", (corners[0][0], corners[0][1], -0.25), (1.7, 1.7, 0.5), r=r, j=0.0)
    stone(P, "ashlar", (0.7, -0.7 - 0.0, -0.25), (2 * INT - 1.6 + 0.1, 2 * INT - 1.6 + 1.5, 0.5), r=r, j=0.0)
    stone(P, "ashlar", (0.7, -INT + 0.7 + 0.0, -0.25), (2 * INT - 1.6 + 0.1, 1.4, 0.5), r=r, j=0.0)
    if not coll:
        # the cistern basin: a low stone trough with a lead-lined, sinter-crusted bed
        for (x, y, sx, sy) in ((0.9, -0.7, 2.3, 0.3), (0.9, 0.7 - 0.0, 2.3, 0.3), (-0.2, 0.0, 0.3, 1.4), (2.0, 0.0, 0.3, 1.4)):
            stone(P, "ashlar", (x, y, 0.35), (sx, sy, 0.7), r=r, j=0.01, chamfer=0.02)
        stone(P, "stone", (0.9, 0.0, 0.08), (1.9, 1.1, 0.12), r=r, j=0.02)


def door(P, r):
    """The ground door's leaf, ajar: planks, iron straps (north wall, local frame of the tower)."""
    hy = HW - WT * 0.5
    hinge = Vector((-1.2, hy + 0.15, Z_GROUND))
    ang = 1.15
    for i in range(6):
        t = i / 6.0
        pos = hinge + Vector((math.cos(ang) * (0.2 * i + 0.1), math.sin(ang) * (0.2 * i + 0.1), 1.65))
        stone(P, "timber", (pos.x, pos.y, Z_GROUND + 1.7), (0.19, 0.1, 3.3), yaw=ang, r=r, j=0.012)
    for zc in (0.7, 2.6):
        stone(P, "iron", (hinge.x + math.cos(ang) * 1.2 * 0.5, hinge.y + math.sin(ang) * 1.2 * 0.5, Z_GROUND + zc), (1.25, 0.14, 0.16), yaw=ang, r=r, j=0.0)


def roof(P, r):
    """A hipped slate roof on rafters, half fallen in: the south-east slope is open to the rafters."""
    zb = Z_WALL + 1.6
    ov = 1.0
    half = HW + ov
    apex = Vector((0.0, 0.0, zb + 4.6))
    # a timber wall plate and the rafters
    for k in range(-5, 6):
        for sgn in (-1, 1):
            t = k / 5.0
            for axis in (0, 1):
                a = Vector((half * t if axis == 0 else sgn * half, sgn * half if axis == 0 else half * t, zb))
                b = apex + Vector((0.0, 0.0, 0.0))
                if abs(t) > 0.85 and False:
                    continue
                L.W.beam(P, "timber", a, a.lerp(b, 0.96), 0.17, 0.26)
    for (yaw_i, sd) in enumerate((1, 2, 3, 4)):
        yaw = yaw_i * math.pi * 0.5
        # one slope: eaves z, rows of slates courses, each a thin slab
        rows = 18
        for i in range(rows):
            t0 = i / rows
            t1 = (i + 1) / rows
            w0 = half * (1.0 - t0)
            w1 = half * (1.0 - t1)
            z0 = zb + (apex.z - zb) * t0
            z1 = zb + (apex.z - zb) * t1
            ro = half - (half - 0.0) * t0
            n = max(2, int(w0 * 2.2 / 0.7))
            for j in range(n):
                xa = -w0 + j * 2 * w0 / n
                xb = -w0 + (j + 1) * 2 * w0 / n
                xm = 0.5 * (xa + xb)
                # the south-east slope: holes
                gx = Vector((0, 0, 0))
                world = Matrix.Rotation(yaw, 4, 'Z') @ Vector((xm, (half - (half) * t0), 0.0))
                if (world.x > 0.5 and world.y < 1.0 and i > 2 and noise.noise(Vector((world.x * 0.7, world.y * 0.7, 3.0))) > -0.1) or r.random() < 0.05:
                    continue
                zm = 0.5 * (z0 + z1)
                ym = half * (1.0 - 0.5 * (t0 + t1))
                p = Matrix.Rotation(yaw, 4, 'Z') @ Vector((xm, ym, zm))
                ang = math.atan2(apex.z - zb, half)
                stone(P, "slate", (p.x, p.y, p.z + 0.06), ((xb - xa) * (1 - (t0 + t1) * 0.5 * 0.0) - 0.03, (half / math.cos(ang)) / rows * 1.15, 0.07), yaw=yaw + math.pi, pitch=ang, r=r, j=0.012)
    stone(P, "stone", (0, 0, apex.z + 0.2), (0.7, 0.7, 0.7), r=r, j=0.03)
    L.W.cyl(P, "iron", (0, 0, apex.z + 0.5), (0, 0, apex.z + 1.8), 0.05, seg=6)


def foot(P, r, coll):
    """The footing under the tower: a flared plinth down 3 m, rubble round it."""
    steps = 3
    for i in range(steps):
        z0 = Z_BASE - 3.0 + 3.0 * i / steps
        z1 = Z_BASE - 3.0 + 3.0 * (i + 1) / steps
        e = 0.5 * (steps - 1 - i) + 0.1
        stone(P, "stone", (0, 0, 0.5 * (z0 + z1)), (2 * HW + 2 * e, 2 * HW + 2 * e, z1 - z0 + 0.05), r=r, j=0.04)
    if coll:
        return
    for k in range(14):
        a = r.uniform(0, math.tau)
        d = HW * r.uniform(1.15, 1.6)
        stone(P, "stone", (math.cos(a) * d, math.sin(a) * d, Z_BASE - 2.4), (r.uniform(0.7, 1.4), r.uniform(0.7, 1.4), r.uniform(0.5, 1.0)), yaw=r.uniform(0, 3), pitch=r.uniform(-0.3, 0.3), r=r, j=0.08)


def foot_course(P, r, coll):
    stone(P, "stone", (0, 0, 1.0), (2 * HW + 1.0, 2 * HW + 1.0, 2.0), r=r, j=0.0)
    if coll:
        return
    n = 8
    for side in range(4):
        for i in range(n):
            u = -HW - 0.5 + (i + 0.5) * (2 * HW + 1.0) / n
            for (a, b) in ((u, HW + 0.5), (u, -HW - 0.5)):
                pass
            for sg in (-1, 1):
                if side % 2 == 0:
                    stone(P, "ashlar", (u, sg * (HW + 0.5), 1.0), ((2 * HW + 1.0) / n - 0.05, 0.16, 1.95), r=r, j=0.02, chamfer=0.035)
                else:
                    stone(P, "ashlar", (sg * (HW + 0.5), u, 1.0), (0.16, (2 * HW + 1.0) / n - 0.05, 1.95), r=r, j=0.02, chamfer=0.035)
            break


def far(P):
    stone(P, "stone", (0, 0, -5.0), (2 * HW, 2 * HW, 20.4), j=0.0)
    L.W.cyl(P, "stone", (0, 0, 5.2), (0, 0, 5.2), 0.1, seg=4)
    # the roof: a four-sided pyramid
    zb = Z_WALL + 1.6
    h = HW + 1.0
    bm = P.of("slate")
    v = [bm.verts.new(p) for p in ((-h, -h, zb), (h, -h, zb), (h, h, zb), (-h, h, zb), (0, 0, zb + 4.6))]
    for i in range(4):
        bm.faces.new((v[i], v[(i + 1) % 4], v[4]))
    stone(P, "stone", (0, 0, Z_WALL + 0.8), (2 * HW + 1.8, 2 * HW + 1.8, 1.6), j=0.0)


def build_all():
    L.fresh()
    L.OPT.update({"moss": 1.0, "soot": 0.0, "damp": 3.0, "ivy": 0.5})
    objs = []
    for (name, fn, zoff, seed) in (("Tower", None, 0.0, 31),):
        P = Parts()
        L.ZOFF[0] = 20.0
        walls(P, random.Random(seed), False)
        stair(P, random.Random(seed + 1), False)
        door(P, random.Random(seed + 2))
        objs.extend(L.finish_set(P, "Tower"))
        P = Parts()
        walls(P, random.Random(seed), True)
        stair(P, random.Random(seed + 1), True)
        c = L.finish_set(P, "TowerC")
        for ob in c:
            ob.name = "Tower-colonly"
            ob.data.name = ob.name
            ob.data.materials.clear()
        if len(c) > 1:
            bpy.ops.object.select_all(action='DESELECT')
            for ob in c:
                ob.select_set(True)
            bpy.context.view_layer.objects.active = c[0]
            bpy.ops.object.join()
            c = [bpy.context.view_layer.objects.active]
            c[0].name = "Tower-colonly"
            c[0].data.name = "Tower-colonly"
        objs.extend(c)
    P = Parts()
    L.ZOFF[0] = 26.0
    roof(P, random.Random(41))
    objs.extend(L.finish_set(P, "Roof"))
    P = Parts()
    far(P)
    objs.extend(L.finish_set(P, "Tower_Far"))
    P = Parts()
    L.ZOFF[0] = 0.0
    foot(P, random.Random(51), False)
    objs.extend(L.finish_set(P, "Foot"))
    P = Parts()
    foot(P, random.Random(51), True)
    c = L.finish_set(P, "FootC")
    for ob in c:
        ob.name = "Foot-colonly"
        ob.data.name = ob.name
        ob.data.materials.clear()
    objs.extend(c)
    P = Parts()
    foot_course(P, random.Random(52), False)
    objs.extend(L.finish_set(P, "FootCourse"))
    P = Parts()
    foot_course(P, random.Random(52), True)
    c = L.finish_set(P, "FootCourseC")
    for ob in c:
        ob.name = "FootCourse-colonly"
        ob.data.name = ob.name
        ob.data.materials.clear()
    objs.extend(c)
    return objs
