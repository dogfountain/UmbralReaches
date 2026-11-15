"""Walls and dressings shared by the Deep South's stone buildings (the Castellum, the barn's footings, the byre, the dovecote)."""
import math

import reach_south_lib as L
from reach_south_lib import bpy, bmesh, Vector, Matrix, noise, Parts, smoothstep, fbm, stone, wedge, prism_polygon, quad_strip_box, arc_pts


def merge(P, S, M):
    """Everything in Parts S copied into P under the matrix M (a mirrored M flips the faces back)."""
    flip = M.determinant() < 0
    for key, bm in S.bm.items():
        dst = P.of(key)
        mp = {}
        for v in bm.verts:
            mp[v] = dst.verts.new(M @ v.co)
        for f in bm.faces:
            vs = [mp[v] for v in f.verts]
            try:
                dst.faces.new(vs[::-1] if flip else vs)
            except ValueError:
                pass
        bm.free()
    S.bm = {}


def xf(yaw=0.0, x=0.0, y=0.0, z=0.0):
    return Matrix.Translation((x, y, z)) @ Matrix.Rotation(yaw, 4, 'Z')


def _top(op, x):
    if op.get("arch"):
        R = op["w"] * 0.5
        zs = op["z0"] + op["h"] - R
        d = x - op["xc"]
        return zs + math.sqrt(max(R * R - d * d, 0.0)) if abs(d) < R else zs
    return op["z0"] + op["h"]


def masonry_wall(P, r, x0, x1, z0, z1, thick, openings=(), key="ashlar", face_t=0.14, row_h=(0.42, 0.6), lens=(0.7, 1.5),
                 ring_T=0.42, rust_h=0.0, ivy_n=0, quoins=True, coll=False, sides=(1, 1), top_jag=0.0, col_w=0.24):
    """A wall in the plane x0..x1 (along x), z0..z1, centred on y = 0, `thick` deep. Openings: dicts xc, w, z0, h,
    arch (a semi-circular head), sill. Coursed faces on the sides listed in `sides` (-y, +y), a core between."""
    Y = thick * 0.5
    ft = 0.0 if coll else face_t
    x = x0
    while x < x1 - 0.03:
        xe = min(x + col_w, x1)
        spans = [(z0, z1)]
        for op in openings:
            ox0 = op["xc"] - op["w"] * 0.5
            ox1 = op["xc"] + op["w"] * 0.5
            if xe <= ox0 + 0.01 or x >= ox1 - 0.01:
                continue
            tmax = max(_top(op, max(x, ox0)), _top(op, min(xe, ox1)), _top(op, min(max(0.5 * (x + xe), ox0), ox1)))
            new = []
            for (a, b) in spans:
                if a < op["z0"]:
                    new.append((a, min(b, op["z0"])))
                if b > tmax:
                    new.append((max(a, tmax), b))
            spans = [(a, b) for (a, b) in new if b - a > 0.02]
        for (a, b) in spans:
            top = b - (r.uniform(0, top_jag) if (top_jag > 0 and b >= z1 - 0.01) else 0.0)
            quad_strip_box(P, "stone", x, xe, -Y + ft, Y - ft, a, top, j=0.0, r=r)
        x = xe
    for op in openings:
        R = op["w"] * 0.5
        if op.get("arch"):
            zs = op["z0"] + op["h"] - R
            n = max(7, int(R * 6))
            for k in range(n):
                a0 = math.pi * k / n
                a1 = math.pi * (k + 1) / n
                rr = R + ring_T * (1.0 if k % 2 == 0 else 0.86) + (0.16 if k == n // 2 else 0.0)
                wedge(P, "ashlar", op["xc"], zs, R, rr, a0, a1, -Y - 0.04, Y + 0.04, inset=0.014, jr=0.012, r=r)
            for sgn in (-1, 1):
                zz = op["z0"]
                kq = 0
                while zz < zs - 0.05:
                    hq = min(r.uniform(0.45, 0.6), zs - zz)
                    stone(P, "ashlar", (op["xc"] + sgn * (R + ring_T * 0.5), 0, zz + hq * 0.5), (ring_T - 0.02 + (0.2 if kq % 2 else 0.0), thick + 0.06, hq - 0.02), r=r, j=0.01)
                    zz += hq
                    kq += 1
        else:
            for sgn in (-1, 1):
                stone(P, "ashlar", (op["xc"] + sgn * (R + ring_T * 0.5), 0, op["z0"] + op["h"] * 0.5 + 0.2), (ring_T, thick + 0.06, op["h"] + 0.5), r=r, j=0.01)
            stone(P, "ashlar", (op["xc"], 0, op["z0"] + op["h"] + ring_T * 0.5), (op["w"] + ring_T * 2 + 0.2, thick + 0.1, ring_T), r=r, j=0.01)
        if op.get("sill"):
            stone(P, "ashlar", (op["xc"], 0, op["z0"] - 0.07), (op["w"] + 0.5, thick + 0.4, 0.16), r=r, j=0.01)
    if coll:
        return

    def blocked(xa, xb, zb, zt):
        for op in openings:
            ox0 = op["xc"] - op["w"] * 0.5 - ring_T
            ox1 = op["xc"] + op["w"] * 0.5 + ring_T
            if xb <= ox0 or xa >= ox1:
                continue
            tm = max(_top(op, op["xc"]), op["z0"] + op["h"]) + ring_T
            if zt > op["z0"] - 0.05 and zb < tm:
                return True
        return False
    z = z0
    row = 0
    while z < z1 - 0.15:
        rusty = z < z0 + rust_h
        h = r.uniform(0.7, 0.9) if rusty else r.uniform(*row_h)
        zt = min(z + h, z1)
        if z1 - zt < 0.2:
            zt = z1
        lmin, lmax = ((1.1, 1.9) if rusty else lens)
        for side in (-1, 1):
            if (side < 0 and not sides[0]) or (side > 0 and not sides[1]):
                continue
            ys = side * Y
            xx = x0
            while xx < x1 - 0.05:
                ln = r.uniform(lmin, lmax)
                if row % 2 and xx == x0:
                    ln = r.uniform(lmin * 0.4, lmin * 0.9)
                if x1 - xx - ln < lmin * 0.5:
                    ln = x1 - xx
                xe = min(xx + ln, x1)
                if blocked(xx, xe, z, zt):
                    xx = xe
                    continue
                prot = r.uniform(0.0, 0.03) + (0.05 if rusty else 0.0)
                ya, yb = ((ys - ft, ys + prot) if side > 0 else (ys - prot, ys + ft))
                if rusty:
                    stone(P, key, (0.5 * (xx + xe), 0.5 * (ya + yb), 0.5 * (z + zt)), (xe - xx - 0.03, abs(yb - ya), zt - z - 0.03), r=r, j=0.02, chamfer=0.04)
                else:
                    quad_strip_box(P, key, xx + 0.014, xe - 0.014, min(ya, yb), max(ya, yb), z + 0.014, zt - 0.014, j=0.012, r=r)
                xx = xe
        z = zt
        row += 1
    if quoins:
        for sgn in (-1, 1):
            zq = z0
            kq = 0
            xq = x0 + 0.4 if sgn < 0 else x1 - 0.4
            while zq < z1 - 0.3:
                hq = r.uniform(0.5, 0.7)
                lq = 0.9 if kq % 2 == 0 else 0.6
                for side in (-1, 1):
                    if (side < 0 and not sides[0]) or (side > 0 and not sides[1]):
                        continue
                    stone(P, key, (xq + (lq * 0.5 - 0.4) * (1 if sgn < 0 else -1), side * (Y - ft * 0.5 + 0.02), zq + hq * 0.5), (lq, ft + 0.08, hq - 0.03), r=r, j=0.01)
                zq += hq
                kq += 1
    for i in range(ivy_n):
        xx = r.uniform(x0 + 0.4, x1 - 0.4)
        zz = r.uniform(z0 + 0.3, z0 + (z1 - z0) * 0.7)
        side = -1 if r.random() < 0.5 else 1
        sz = r.uniform(0.5, 1.3)
        stone(P, "stone_ivy", (xx, side * (Y + sz * 0.12), zz), (sz * 1.3, sz * 0.5, sz * 1.1), yaw=r.uniform(-0.4, 0.4), r=r, j=sz * 0.18)


def cornice(P, r, x0, x1, z, depth, key="ashlar", h=0.5, proj=0.5, dentils=True):
    """A projecting cornice (slab + overhang + dentils) along x at height z, centred on y = 0 over `depth`."""
    n = max(1, int((x1 - x0) / 1.5))
    for i in range(n):
        xa = x0 + i * (x1 - x0) / n
        xb = x0 + (i + 1) * (x1 - x0) / n
        stone(P, key, (0.5 * (xa + xb), 0, z + h * 0.33), ((xb - xa) - 0.03, depth + proj * 0.5, h * 0.66), r=r, j=0.008)
        stone(P, key, (0.5 * (xa + xb), 0, z + h * 0.83), ((xb - xa) - 0.03, depth + proj, h * 0.34), r=r, j=0.008)
        if dentils:
            nd = int((xb - xa) / 0.5)
            for d in range(nd):
                xd = xa + (d + 0.5) * (xb - xa) / nd
                for ys in (-1, 1):
                    stone(P, key, (xd, ys * (depth * 0.5 + proj * 0.25 + 0.04), z - 0.05), (0.2, 0.2, 0.16), r=r, j=0.006)
