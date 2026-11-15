"""The Long Arches: the Order's two-tier aqueduct as a kit (art/models/reach_s_arches.glb).

Frame of every piece: x along the line, y across it (Blender +y is Godot -z), z up. A piece's origin is the middle of
its span at its own datum:
  ArchL   a lower bay (12 m pier to pier, clear span 9, depth 5): origin at the springing line; its top (the string
          course) is 7.5 m up. The pier stack under it is PierL courses (1.5 m each) on a PierFoot.
  ArchU   an upper bay (6 m, span 4.5, depth 4.6): origin at its springing; pier stubs 1.6 m under it, top 3.85 up.
  Chan    the channel over one lower bay (12 m): origin at the walkway; a central trough with cover slabs, parapets.
  *Broken the fallen span's remains (haunches, half arches, ragged channel stubs), Rubble the span on the floor.
  Castellum  the water tower at the line's west end.
Each has a `_Far` low-poly twin (the silhouette: openings kept) and a `-colonly` collision body.
"""
import math
import os
import random

import reach_south_lib as L
from reach_south_lib import bpy, bmesh, Vector, Matrix, noise, Parts, smoothstep, fbm, stone, wedge, prism_polygon, quad_strip_box, arc_pts

DEPTH_L = 5.0
DEPTH_U = 4.6
PITCH_L = 12.0
PITCH_U = 6.0
H_ARCH_L = 7.5        # springing to the top of its string course
H_ARCH_U = 3.85
U_BELOW = 1.6         # the upper pier stub under its springing
H_CHAN_BASE = 1.0


def seg_rows(r, z0, z1, hmin, hmax):
    rows = []
    z = z0
    while z < z1 - 0.2:
        h = r.uniform(hmin, hmax)
        if z + h > z1 - 0.2:
            h = z1 - z
        rows.append((z, z + h))
        z += h
    return rows


def face_blocks(P, r, key, x0, x1, ys, ybk, rows, excl, lmin, lmax, gap=0.014, depth=0.15, lim=None, jag=0.012):
    """Coursed blocks on one face: `rows` [(z0, z1)], `excl(zb, zt) -> [(xa, xb)]` the spans open to masonry in that
    row, block lengths lmin..lmax, the face at y = ys (the block's outer side), thickness `depth` toward ybk."""
    for (zb, zt) in rows:
        for (xa, xb) in excl(zb, zt):
            x = xa
            alt = r.random() < 0.5
            while x < xb - 0.05:
                ln = r.uniform(lmin, lmax)
                if xb - x - ln < lmin * 0.55:
                    ln = xb - x
                xe = min(x + ln, xb)
                if lim is not None and not lim(0.5 * (x + xe), zt):
                    x = xe
                    continue
                prot = r.uniform(0.0, 0.025)
                ya, yb = (ys - depth - prot * 0, ys + prot) if ys > 0 else (ys - prot, ys + depth + prot * 0)
                quad_strip_box(P, key, x + gap, xe - gap, min(ya, yb), max(ya, yb), zb + gap, zt - gap, j=jag, r=r)
                x = xe


def arcade(P, r, pitch, r_in, T, depth, n, z_bot, z_top, cornice, broken=None, face_t=0.14, row_h=(0.46, 0.64), key="ashlar", ring_key="ashlar", lens=(0.7, 1.5), coll=False):
    """One bay of an arcade (see the module doc). `broken`: None, 'both' (haunches only), 'E' (the east side gone),
    'W' (the west side gone)."""
    half = pitch / 2.0
    r_out = r_in + T
    Y = depth / 2.0
    zs_top = z_top - cornice          # top of the walling under the string course
    # ---- how much is left (broken): cut(x) is the height the masonry stands to at x (None = all)
    def cut(x):
        if broken is None:
            return 99.0
        if broken == "both":
            e = half - abs(x)                                   # distance in from the nearest pier
            if e > 3.2:
                return -9.0
            return 0.9 + 2.2 * e + 0.8 * noise.noise(Vector((x * 1.7, 4.0, 1.0)))
        e = (half * 0.15 - x) if broken == "E" else (x + half * 0.15)
        return -9.0 if e < -0.4 else 1.6 + 3.3 * e + 1.0 * noise.noise(Vector((x * 1.9, 6.0, 2.0)))
    def ring_keep(k, side, first):
        if broken is None:
            return True
        ang = (k + 0.5) / n                                     # 0 east .. 1 west
        if broken == "E":
            return ang > 0.6 - 0.12 * noise.noise(Vector((k * 3.1, side, 1.0))) + (0.0 if first else 0.04)
        if broken == "W":
            return ang < 0.4 + 0.12 * noise.noise(Vector((k * 3.1, side, 1.0))) - (0.0 if first else 0.04)
        return ang < 0.2 + 0.07 * noise.noise(Vector((k * 3.1, side, 1.0))) or ang > 0.8 - 0.07 * noise.noise(Vector((k * 2.1, side, 1.0)))
    # ---- the ring: voussoirs in three layers of depth (two proud faces, the barrel between)
    layers = [(-Y - 0.07, -Y + 0.88, T + 0.12, 0.12), (-Y + 0.88, Y - 0.88, T - 0.1, 0.0), (Y - 0.88, Y + 0.07, T + 0.12, 0.12)]
    for side, (y0, y1, tt, proud) in enumerate(layers):
        for k in range(n):
            if not ring_keep(k, side, side == 1):
                continue
            a0 = math.pi * k / n
            a1 = math.pi * (k + 1) / n
            tk = tt + (0.28 if k == n // 2 and side != 1 else 0.0)
            # a long stone and a short one alternate round the ring
            rad1 = r_in + tk * (1.0 if k % 2 == 0 else 0.9)
            wedge(P, ring_key, 0.0, 0.0, r_in - (0.0 if side == 1 else 0.0), rad1, a0, a1, y0, y1, inset=0.016, jr=0.014, r=r)
    # ---- impost blocks at the springing
    for sgn in (-1, 1):
        if broken == "E" and sgn > 0 and cut(sgn * r_in) < 0:
            continue
        if broken == "W" and sgn < 0 and cut(sgn * r_in) < 0:
            continue
        stone(P, ring_key, (sgn * (r_in + 0.18), 0.0, -0.17), (0.86, depth + 0.16, 0.34), r=r, j=0.01)
    # ---- the walling: the core behind (columns) and coursed faces over it
    cols = []
    x = -half
    while x < half - 0.05:
        w = min(0.5, half - x)
        cols.append((x, x + w))
        x += w
    for (xa, xb) in cols:
        xm = 0.5 * (xa + xb)
        top = min(zs_top, cut(xm)) if broken else zs_top
        # which z-spans of the column are solid: above the extrados, and the pier stub below the springing
        spans = []
        ax = max(abs(xa), abs(xb))
        mn = min(abs(xa), abs(xb))
        ext = math.sqrt(max(r_out * r_out - mn * mn, 0.0)) if mn < r_out else 0.0
        if mn < r_in:
            lo = ext
            spans.append((lo, top))
        else:
            spans.append((z_bot, min(top, 0.0)))
            if ext > 0.0:
                spans.append((ext, top))
            else:
                spans.append((0.0, top)) if top > 0.0 else None
        if mn < r_in and z_bot < 0.0:
            pass
        for (za, zb) in spans:
            if zb - za < 0.08:
                continue
            ft = 0.0 if coll else face_t
            quad_strip_box(P, "stone", xa, xb, -Y + ft, Y - ft, za, zb, j=0.0, r=r)
    # coursed faces
    rows_up = seg_rows(r, 0.0, zs_top, *row_h)
    rows_dn = [(-b, -a) for (a, b) in seg_rows(r, 0.0, -z_bot, *row_h)] if z_bot < 0 else []
    def excl(zb, zt):
        if zt <= 0.0:                                          # the pier stubs under the springing
            return [(-half, -r_in), (r_in, half)]
        xe = math.sqrt(max(r_out * r_out - zb * zb, 0.0)) if zb < r_out else 0.0
        if xe <= 0.0:
            return [(-half, half)]
        return [(-half, -xe), (xe, half)]
    lim = (lambda xm, zt: zt <= cut(xm) + 0.3) if broken else None
    for ys in (-Y, Y):
        if not coll:
            face_blocks(P, r, key, -half, half, ys, ys, rows_up + rows_dn, excl, lens[0], lens[1], depth=face_t, lim=lim)
    # ---- quoins: tall long-and-short stones up the pier edges (proud)
    if not coll:
        for sgn in (-1, 1):
            xq = sgn * (half - 0.4)
            zq = z_bot
            kq = 0
            while zq < zs_top - 0.3:
                hq = r.uniform(0.55, 0.75)
                lq = 0.8 if kq % 2 == 0 else 0.55
                if broken is None or zq + hq <= cut(xq) + 0.3:
                    for ys in (-Y, Y):
                        y0 = ys - 0.02 if ys < 0 else ys - face_t
                        stone(P, key, (xq + sgn * (0.4 - lq * 0.5) * 0.0, ys + (-0.05 if ys < 0 else 0.05) * 0.0, zq + hq * 0.5),
                              (lq, face_t + 0.1, hq - 0.03), r=r, j=0.01)
                zq += hq
                kq += 1
    # ---- the string course (an intact bay: a slab, a cornice, dentils)
    if broken is None or True:
        xs0, xs1 = -half, half
        steps = int((xs1 - xs0) / 1.5) + 1
        for i in range(steps):
            xa = xs0 + i * 1.5
            xb = min(xa + 1.5, xs1)
            if xb - xa < 0.1:
                continue
            xm = 0.5 * (xa + xb)
            if broken and cut(xm) < zs_top - 0.1:
                continue
            stone(P, key, (xm, 0.0, zs_top + cornice * 0.33), ((xb - xa) - 0.03, depth + 0.3, cornice * 0.66), r=r, j=0.008)
            stone(P, key, (xm, 0.0, zs_top + cornice * 0.83), ((xb - xa) - 0.03, depth + 0.62, cornice * 0.34), r=r, j=0.008)
            nd = 0 if coll else int((xb - xa) / 0.5)
            for d in range(nd):
                xd = xa + (d + 0.5) * (xb - xa) / nd
                for ys in (-1, 1):
                    stone(P, key, (xd, ys * (Y + 0.11), zs_top - 0.05), (0.2, 0.2, 0.16), r=r, j=0.006)
    return None


def pier_courses(P, r, width, depth, h, variant, coll=False):
    """One course of the lower pier: large rusticated blocks, joints in two layers; origin at the course's foot centre."""
    if coll:
        stone(P, "stone", (0, 0, h * 0.5), (width, depth, h), j=0.0)
        return
    n = 3 if variant == 0 else 2
    xs = [(-width / 2 + width * i / n, -width / 2 + width * (i + 1) / n) for i in range(n)]
    off = 0.0 if variant == 0 else 0.45
    stone(P, "stone", (0, 0, h * 0.5), (width - 0.12, depth - 0.2, h - 0.02), r=r, j=0.0)
    for (xa, xb) in xs:
        for ys in (-1, 1):
            stone(P, "ashlar", ((xa + xb) * 0.5 + (off if ys > 0 else -off * 0.5), ys * (depth / 2 - 0.12), h * 0.5), ((xb - xa) - 0.05, 0.26, h - 0.05), r=r, j=0.025, chamfer=0.035)
    for ys in (-1, 1):
        stone(P, "ashlar", (0, ys * (depth / 2 - 0.12), h * 0.5), (0.0001, 0.0001, 0.0001), r=r, j=0.0)
    for xs_ in (-1, 1):
        stone(P, "ashlar", (xs_ * (width / 2 - 0.12), 0, h * 0.5 + (0.0 if variant == 0 else 0.0)), (0.26, depth - 0.1, h - 0.05), r=r, j=0.02, chamfer=0.03)


def pier_foot(P, r, width, depth, h, coll=False):
    """The footing: a stepped plinth that flares, a rubble apron round it; origin at its top centre, z from -h to 0."""
    if coll:
        stone(P, "stone", (0, 0, -h * 0.5), (width + 0.8, depth + 0.8, h), j=0.0)
        return
    steps = 3
    for i in range(steps):
        z0 = -h + h * i / steps
        z1 = -h + h * (i + 1) / steps
        e = 0.28 * (steps - 1 - i) + 0.06
        stone(P, "stone", (0, 0, (z0 + z1) * 0.5), (width + 2 * e, depth + 2 * e, z1 - z0 + 0.04), r=r, j=0.03)
        for ys in (-1, 1):
            n = int((width + 2 * e) / 0.9)
            for k in range(n):
                xm = -(width + 2 * e) / 2 + (k + 0.5) * (width + 2 * e) / n
                stone(P, "ashlar", (xm, ys * (depth / 2 + e - 0.04), (z0 + z1) * 0.5), ((width + 2 * e) / n - 0.05, 0.14, z1 - z0 - 0.04), r=r, j=0.025, chamfer=0.02)
    for k in range(9):
        a = r.uniform(0, math.tau)
        stone(P, "stone", (math.cos(a) * (width / 2 + 0.7) * r.uniform(0.8, 1.4), math.sin(a) * (depth / 2 + 0.6) * r.uniform(0.8, 1.3), -h + 0.35),
              (r.uniform(0.5, 1.1), r.uniform(0.5, 1.1), r.uniform(0.4, 0.8)), yaw=r.uniform(0, 3), pitch=r.uniform(-0.2, 0.2), r=r, j=0.07)


def channel(P, r, length, broken=False, coll=False):
    """The channel on top of one lower bay: a body 4.6 m wide, a trough with sinter, cover slabs, parapets, coping.
    z = 0 is the walkway. Origin at the middle of the span."""
    half = length / 2.0
    key = "ashlar"
    def cutx(x):                                  # ragged ends of the broken span: how far the stub stands
        return 99.0
    stub = 3.3
    xr = [(-half, half)]
    if broken:
        xr = [(-half, -half + stub), (half - stub, half)]
    for (xa, xb) in xr:
        # the body under the walkway
        rr = lambda: r.uniform(0, 1)
        ragged = []
        if broken:
            # ragged end: step the body back
            pass
        x = xa
        while x < xb - 0.05:
            w = min(r.uniform(0.9, 1.5), xb - x)
            ex = 0.0
            if broken and ((xa < 0 and xb - (x + w) < 1.6) or (xa > 0 and x - xa < 1.6)):
                ex = -r.uniform(0.0, 0.7)
            # walkway slabs
            for sy in (-1, 1):
                stone(P, key, (x + w * 0.5, sy * 1.55, -0.2), (w - 0.03, 1.3, 0.4), r=r, j=0.012)
                stone(P, key, (x + w * 0.5, sy * 2.12, 0.3), (w - 0.03, 0.5, 0.6 + r.uniform(-0.02, 0.05)), r=r, j=0.012)  # coping/parapet
                stone(P, key, (x + w * 0.5, sy * 2.15, -0.75), (w - 0.03, 0.62, 0.7), r=r, j=0.012)
            x += w
        # the trough: walls with the sinter band, a floor
        stone(P, "stone", (0.5 * (xa + xb), 0, -0.95), (xb - xa, 2.1, 0.12), r=r, j=0.0)
        for sy in (-1, 1):
            stone(P, "stone", (0.5 * (xa + xb), sy * 1.0, -0.5), (xb - xa, 0.18, 0.9), r=r, j=0.0)
        # the body's sides: ashlar courses
        for sy in (-1, 1) if not coll else ():
            rows = seg_rows(r, -1.0, -0.4, 0.3, 0.3)
            x = xa
            while x < xb - 0.05:
                w = min(r.uniform(0.9, 1.6), xb - x)
                for (zb, zt) in [(-1.0, -0.5), (-0.5, -0.05)]:
                    stone(P, key, (x + w * 0.5, sy * 2.32, 0.5 * (zb + zt)), (w - 0.04, 0.12, zt - zb - 0.03), r=r, j=0.01)
                x += w
    # cover slabs on the trough ledges: most laid, some tilted, one gone
    ns = int(length / 1.8)
    for i in range(ns):
        xm = -half + (i + 0.5) * length / ns
        if broken and (abs(xm) < half - stub):
            continue
        if r.random() < 0.28:
            continue
        tilt = r.uniform(-0.5, 0.5) if r.random() < 0.25 else 0.0
        stone(P, "stone", (xm, 0, -0.1 if tilt == 0 else 0.0), (length / ns - 0.06, 2.3, 0.22), roll=tilt * 0.3, pitch=tilt * 0.12, r=r, j=0.012)
    # a sinter crust in the trough
    for i in range(0 if coll else 14):
        x = r.uniform(-half + 0.4, half - 0.4)
        if broken and abs(x) < half - stub:
            continue
        stone(P, "stone", (x, r.uniform(-0.6, 0.6), -0.84), (r.uniform(0.3, 0.9), r.uniform(0.3, 0.8), 0.1), yaw=r.uniform(0, 3), r=r, j=0.03)
    # corbels under the cornice of the walkway, every 1.2 m
    for sy in (-1, 1):
        for i in range(0 if coll else int(length / 1.2)):
            xm = -half + 0.6 + i * 1.2
            if broken and abs(xm) < half - stub:
                continue
            stone(P, key, (xm, sy * 2.45, -0.62), (0.3, 0.3, 0.22), r=r, j=0.008)


def far_arcade(P, pitch, r_in, T, depth, z_bot, z_top, n=7):
    half = pitch / 2.0
    Y = depth / 2.0
    pts = [(-half, z_bot), (-r_in, z_bot), (-r_in, 0.0)] + arc_pts(0.0, 0.0, r_in, math.pi, 0.0, n)[1:-1] + [(r_in, 0.0), (r_in, z_bot), (half, z_bot), (half, z_top), (-half, z_top)]
    prism_polygon(P, "stone", pts, -Y, Y)


def far_channel(P, length):
    stone(P, "stone", (0, 0, -0.25), (length, 4.7, 1.5), j=0.0)
    for sy in (-1, 1):
        stone(P, "stone", (0, sy * 2.12, 0.3), (length, 0.5, 0.6), j=0.0)


def ivy(P, r, n, region, size=(0.5, 1.3)):
    """Mossy clumps pressed to a wall: region (x0, x1, y_face, z0, z1) (the face at y = +-y_face)."""
    x0, x1, yf, z0, z1 = region
    return                                   # (clumps read as floating cubes: the ivy is in the vertex tone instead)
    for i in range(n):
        x = r.uniform(x0, x1)
        z = r.uniform(z0, z1)
        sy = -1 if r.random() < 0.5 else 1
        sz = r.uniform(*size)
        stone(P, "stone_ivy", (x, sy * (yf + sz * 0.12), z), (sz * 1.3, sz * 0.5, sz * 1.1), yaw=r.uniform(-0.4, 0.4), r=r, j=sz * 0.18)


def build_all(preview_dir):
    L.fresh()
    L.OPT.update({"moss": 1.0, "soot": 0.0, "damp": 3.0, "ivy": 0.55})
    objs = []

    def emit(name, builder, zoff, seed, far=None):
        r = random.Random(seed)
        P = Parts()
        L.ZOFF[0] = zoff
        builder(P, r, False)
        o = L.finish_set(P, name)
        objs.extend(o)
        P = Parts()
        builder(P, random.Random(seed), True)
        c = L.finish_set(P, name + "C")
        for ob in c:
            ob.name = name + "-colonly"
            ob.data.name = ob.name
            ob.data.materials.clear()
        if len(c) > 1:
            bpy.ops.object.select_all(action='DESELECT')
            for ob in c:
                ob.select_set(True)
            bpy.context.view_layer.objects.active = c[0]
            bpy.ops.object.join()
            c = [bpy.context.view_layer.objects.active]
            c[0].name = name + "-colonly"
            c[0].data.name = c[0].name
        objs.extend(c)
        if far is not None:
            P = Parts()
            far(P)
            f = L.finish_set(P, name + "_Far")
            objs.extend(f)
        return o

    zU = H_ARCH_L + U_BELOW
    zc = zU + H_ARCH_U + H_CHAN_BASE
    zz = 9.0
    def al(P, r, c, broken=None):
        arcade(P, r, PITCH_L, 4.5, 1.15, DEPTH_L, 21, 0.0, H_ARCH_L, 0.6, broken=broken, coll=c)
        if not c:
            ivy(P, r, 7, (-6.0, 6.0, DEPTH_L / 2, 0.5, 6.5))
    def au(P, r, c, broken=None):
        arcade(P, r, PITCH_U, 2.25, 0.8, DEPTH_U, 13, -U_BELOW, H_ARCH_U, 0.5, broken=broken, face_t=0.12, row_h=(0.38, 0.5), lens=(0.6, 1.2), coll=c)
    emit("ArchL", lambda P, r, c: al(P, r, c), zz, 11, lambda P: far_arcade(P, PITCH_L, 4.5, 1.15, DEPTH_L, 0.0, H_ARCH_L))
    emit("ArchU", lambda P, r, c: au(P, r, c), zz + zU, 12, lambda P: far_arcade(P, PITCH_U, 2.25, 0.8, DEPTH_U, -U_BELOW, H_ARCH_U, 6))
    emit("Chan", lambda P, r, c: channel(P, r, PITCH_L, False, c), zz + zc, 13, lambda P: far_channel(P, PITCH_L))
    emit("PierL0", lambda P, r, c: pier_courses(P, r, 3.0, DEPTH_L, 1.5, 0, c), 4.0, 14)
    emit("PierL1", lambda P, r, c: pier_courses(P, r, 3.0, DEPTH_L, 1.5, 1, c), 4.0, 15)
    emit("PierFoot", lambda P, r, c: pier_foot(P, r, 3.0, DEPTH_L, 3.0, c), 0.0, 16)
    emit("ArchLBroken", lambda P, r, c: al(P, r, c, "both"), zz, 17)
    emit("ArchUBrokenW", lambda P, r, c: au(P, r, c, "W"), zz + zU, 18)
    emit("ArchUBrokenE", lambda P, r, c: au(P, r, c, "E"), zz + zU, 19)
    emit("ChanBroken", lambda P, r, c: channel(P, r, PITCH_L, True, c), zz + zc, 20)
    return objs
