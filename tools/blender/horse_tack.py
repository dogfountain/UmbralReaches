"""Horse tack, draped on the fused body by ray casts (blanket, saddle, girth, breast strap, bridle,
reins, stirrups, a hanging lantern). Base space (the palfrey layout); everything is built from what the
body's surface really is, so cloth and leather lie ON the horse, not over it.
"""
import math
import os
import sys
import bpy
import bmesh
from mathutils import Vector

sys.path.insert(0, os.path.dirname(__file__))
import boss_kit as K
import horse_kit as HK
from boss_kit import G


class Surf:
    """Ray casts against an object's mesh through one BVH (Object.ray_cast rebuilds it every call)."""

    def __init__(self, ob):
        from mathutils.bvhtree import BVHTree
        dg = bpy.context.evaluated_depsgraph_get()
        self.bvh = BVHTree.FromObject(ob, dg)

    def ray_cast(self, o, d, distance=2.0):
        loc, nrm, idx, dist = self.bvh.ray_cast(o, d, distance)
        return (loc is not None), loc, nrm, idx


def _hit(body, o, d, far=2.0):
    ok, loc, nrm, _ = body.ray_cast(o, d.normalized(), distance=far)
    return (loc, nrm) if ok else (None, None)


def barrel_axis(z):
    sec = [(-0.66, 1.02), (-0.46, 1.13), (-0.3, 1.14), (-0.12, 1.13), (0.06, 1.14), (0.22, 1.18), (0.38, 1.22), (0.54, 1.22), (0.68, 1.22)]
    for i in range(len(sec) - 1):
        if sec[i][0] <= z <= sec[i + 1][0]:
            u = (z - sec[i][0]) / (sec[i + 1][0] - sec[i][0])
            return sec[i][1] + (sec[i + 1][1] - sec[i][1]) * u
    return 1.15


def drape_pt(body, z, theta, off):
    """Surface point round the barrel at z, angle theta (radians from the top, + toward +x), pushed `off` out."""
    o = G(0, barrel_axis(z), z)
    d = Vector((math.sin(theta), 0.0, math.cos(theta)))
    loc, nrm = _hit(body, o, d)
    if loc is None:
        return o + d * 0.3, d
    return loc + nrm * off, nrm


def grid_mesh(name, grid, mat, sock, thick=0.006, closed_u=False, uvscale=(1.0, 1.0)):
    """A sheet from grid[i][j] (rows along u, columns along v) with thickness via solidify."""
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    rows = [[bm.verts.new(p) for p in r] for r in grid]
    ni, nj = len(rows), len(rows[0])
    for i in range(ni - 1):
        for j in range(nj - 1):
            f = bm.faces.new((rows[i][j], rows[i + 1][j], rows[i + 1][j + 1], rows[i][j + 1]))
            for lp in f.loops:
                ii = [i, i + 1, i + 1, i][list(f.loops).index(lp)]
                jj = [j, j, j + 1, j + 1][list(f.loops).index(lp)]
                lp[uvl].uv = (ii / (ni - 1) * uvscale[0], jj / (nj - 1) * uvscale[1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    ob["sock"] = sock
    if mat is not None:
        ob.data.materials.append(mat.m if hasattr(mat, "m") else mat)
    if thick > 0:
        K.solidify(ob, thick)
    return ob


def drape(body, name, z0, z1, t0, t1, off, mat, sock="barrel", nz=14, nt=18, thick=0.006, rim=None):
    grid = []
    for i in range(nt + 1):
        th = math.radians(t0 + (t1 - t0) * i / nt)
        row = []
        for j in range(nz + 1):
            z = z0 + (z1 - z0) * j / nz
            # a scalloped hem: the lower edge rides up and down a little
            tt = th
            if rim:
                tt = th + rim(i / nt, j / nz)
            p, n = drape_pt(body, z, tt, off)
            row.append(p)
        grid.append(row)
    return grid_mesh(name, grid, mat, sock, thick)


def ribbon(name, pts, nrms, width, off, mat, sock, thick=0.005):
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    rows = []
    n = len(pts)
    for i, (p, nr) in enumerate(zip(pts, nrms)):
        t = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()
        side = nr.cross(t).normalized()
        c = p + nr * off
        rows.append((bm.verts.new(c - side * width * 0.5), bm.verts.new(c + side * width * 0.5)))
    for i in range(n - 1):
        f = bm.faces.new((rows[i][0], rows[i][1], rows[i + 1][1], rows[i + 1][0]))
        for k, lp in enumerate(f.loops):
            lp[uvl].uv = ([0, 1, 1, 0][k], [i, i, i + 1, i + 1][k] / (n - 1))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    ob["sock"] = sock
    ob.data.materials.append(mat.m if hasattr(mat, "m") else mat)
    if thick > 0:
        K.solidify(ob, thick)
    return ob


def surface_path(body, keys, off, nsub=6):
    """keys [(z, theta_deg)] -> points/normals along the barrel."""
    pts, nrm = [], []
    for a, b in zip(keys, keys[1:]):
        for k in range(nsub):
            u = k / nsub
            z = a[0] + (b[0] - a[0]) * u
            th = math.radians(a[1] + (b[1] - a[1]) * u)
            p, n = drape_pt(body, z, th, 0.0)
            pts.append(p)
            nrm.append(n)
    p, n = drape_pt(body, keys[-1][0], math.radians(keys[-1][1]), 0.0)
    pts.append(p)
    nrm.append(n)
    return pts, nrm


def tube(name, pts, r, mat, sock, sides=6, closed=False):
    ob = K.curve_tube(name, pts, r, sock, mat, None, closed, 2)
    return ob


def cyl(name, a, b, r0, r1, mat, sock, sides=10):
    d = b - a
    pts = [a, a + d * 0.5, b]
    return K.loft(name, pts, [r0, (r0 + r1) * 0.5, r1], sock, mat, sides, cap0=True, cap1=True)


def build(P, body, mats):
    """-> (list of objects, info dict with seat/stirrup numbers). mats: leather, dark (leather), metal, cloth, trim, glow, glass."""
    out = []
    info = {}
    L, DK, MT, CL, TR = mats["leather"], mats["dark"], mats["metal"], mats["cloth"], mats["trim"]
    wb = P.get("barrel", 1.0)

    # blanket: trim underlay larger, the cloth over it
    def hem(u, v):
        return 0.0
    out.append(drape(body, "blanket_trim", -0.38, 0.3, -128, 128, 0.010, TR, nz=7, nt=12, thick=0.008))
    out.append(drape(body, "blanket", -0.355, 0.275, -121, 121, 0.017, CL, nz=7, nt=12, thick=0.012))
    # saddle: panels, flaps, the seat tree with pommel and cantle
    for sgn in (-1, 1):
        a, b = (12, 70) if sgn > 0 else (-12, -70)
        out.append(drape(body, "panel", -0.27, 0.13, a, b, 0.032, DK, nz=6, nt=5, thick=0.014))
        a2, b2 = (28, 82) if sgn > 0 else (-28, -82)
        out.append(drape(body, "flap", -0.255, 0.04, a2, b2, 0.05, L, nz=5, nt=5, thick=0.007))
    # seat: height from the back's top, a dip, a pommel arch and a cantle
    xs = [-0.1, -0.05, 0.0, 0.05, 0.1]
    zs = [-0.29 + 0.46 * k / 22.0 for k in range(23)]
    grid = []
    for x in xs:
        row = []
        for z in zs:
            xw = x * (1.0 - 0.28 * math.exp(-((z + 0.05) / 0.12) ** 2))
            o = G(xw, 2.2, z)
            loc, nrm = _hit(body, o, Vector((0, 0, -1)), 2.0)
            ytop = loc.z if loc is not None else 1.45
            prof = 0.05 + 0.065 * math.exp(-((z + 0.255) / 0.035) ** 2) + 0.055 * math.exp(-((z - 0.145) / 0.04) ** 2) - 0.012 * math.exp(-((z + 0.03) / 0.1) ** 2)
            prof += 0.012 * (abs(x) / 0.1) ** 2 * 0.0
            row.append(Vector((xw, -z, ytop + prof - 0.012 * (abs(x) / 0.1) ** 2)))
        grid.append(row)
    seat = grid_mesh("seat", grid, L, "barrel", 0.016)
    out.append(seat)
    o = G(0, 2.2, -0.04)
    loc, _ = _hit(body, o, Vector((0, 0, -1)), 2.0)
    info["back_y"] = loc.z if loc is not None else 0.0
    info["seat_y"] = info["back_y"] + 0.05 - 0.012 + 0.008
    ax = barrel_axis(-0.04)
    loc, _n = _hit(body, G(0, ax, -0.04), Vector((1, 0, 0)), 1.0)
    info["bw"] = loc.x if loc is not None else 0.25
    info["bc"] = ax
    # girth
    pts, nr = surface_path(body, [(-0.2, 100), (-0.2, 150), (-0.2, 180), (-0.2, 210), (-0.2, 260)], 0.012, 6)
    out.append(ribbon("girth", pts, nr, 0.07, 0.012, DK, "barrel", 0.008))
    # breast strap: from each side of the pommel, along the shoulder, to a brass ring at the chest
    for sgn in (-1, 1):
        keys = [(-0.25, 52 * sgn), (-0.4, 70 * sgn), (-0.55, 95 * sgn), (-0.63, 125 * sgn)]
        pts, nr = surface_path(body, keys, 0.01, 5)
        out.append(ribbon("breast", pts, nr, 0.032, 0.012, L, "chest", 0.006))
    rp, rn = drape_pt(body, -0.665, math.radians(180), 0.015)
    out.append(K.curve_tube("ring", [rp + Vector((0.025 * math.cos(a), 0, 0.025 * math.sin(a))) for a in [i * math.tau / 10 for i in range(10)]], 0.0055, "chest", MT, None, True, 0))
    # stirrups: leather down from the bar, an iron with a wide tread
    sy = info["seat_y"]
    drop = P.get("stirrup_drop", 0.54)
    for sgn in (-1, 1):
        bar = G(sgn * 0.215 * wb, sy - 0.085, -0.06)
        tread = G(sgn * 0.31 * wb, sy - drop, -0.06)
        out.append(ribbon("leather", [bar, bar.lerp(tread, 0.5) + Vector((sgn * 0.01, 0, 0)), tread + Vector((0, 0, 0.1))],
                          [Vector((sgn, 0, 0))] * 3, 0.024, 0.0, DK, "barrel", 0.007))
        ring = [tread + Vector((0, 0.045 * math.cos(a), -0.04 * (1 - math.sin(a)) - 0.0)) for a in [math.tau * i / 14 for i in range(15)]]
        ring = [tread + Vector((0, 0.05 * math.cos(a), -0.012 + 0.052 * math.sin(a))) for a in [math.tau * i / 16 for i in range(16)]]
        out.append(K.curve_tube("iron", ring, 0.0062, "barrel", MT, None, True, 0))
        out.append(cyl("tread", tread + Vector((0, -0.05, -0.058)), tread + Vector((0, 0.05, -0.058)), 0.011, 0.011, MT, "barrel", 6))
    info["stirrup_y"] = sy - drop
    info["stirrup_x"] = 0.31 * wb
    # lantern: a dee ring at the cantle, a short chain, an iron lantern with a lit glass
    piv = G(0.30 * wb, 1.34, 0.15)
    out.append(K.curve_tube("dee", [piv + Vector((0.012 * math.cos(a), 0, 0.012 * math.sin(a))) for a in [math.tau * i / 8 for i in range(8)]], 0.004, "barrel", MT, None, True, 0))
    top = piv + Vector((0.03, 0, -0.1))
    out.append(K.curve_tube("chain", [piv, piv + (top - piv) * 0.5 + Vector((0.01, 0, 0)), top], 0.004, "lantern", MT, None, False, 0))
    lc = top + Vector((0, 0, -0.012))
    out.append(cyl("lan_cap", lc, lc + Vector((0, 0, -0.045)), 0.012, 0.058, MT, "lantern", 12))
    out.append(cyl("lan_glass", lc + Vector((0, 0, -0.045)), lc + Vector((0, 0, -0.17)), 0.044, 0.042, mats["glass"], "lantern", 12))
    out.append(cyl("lan_base", lc + Vector((0, 0, -0.17)), lc + Vector((0, 0, -0.182)), 0.05, 0.036, MT, "lantern", 12))
    for k in range(4):
        a = math.tau * k / 4 + math.pi / 4
        c0 = lc + Vector((0.05 * math.cos(a), 0.05 * math.sin(a), -0.045))
        c1 = lc + Vector((0.046 * math.cos(a), 0.046 * math.sin(a), -0.17))
        out.append(cyl("lan_post", c0, c1, 0.0035, 0.0035, MT, "lantern", 5))
    out.append(K.curve_tube("lan_handle", [lc + Vector((0.025 * math.cos(a), 0, 0.01 + 0.04 * math.sin(a))) for a in [math.pi * i / 8 for i in range(9)]], 0.0035, "lantern", MT, None, False, 0))
    info["lantern_pivot"] = (piv.x, piv.z, -piv.y)       # Godot space
    info["lantern_glass"] = (lc.x, lc.z - 0.11, -lc.y)
    return out, info


def bridle(P, body, mats):
    out = []
    DK, MT = mats["dark"], mats["metal"]
    A, ax, hl, hw, th, vh = HK.head_frame(P)

    def hpt(t, phi, extra=0.0):
        o = A + ax * (t * hl)
        d = vh * math.cos(phi) + Vector((1, 0, 0)) * math.sin(phi)
        loc, nrm = _hit(body, o, d, 0.5)
        if loc is None:
            return o + d * 0.1, d
        return loc + nrm * extra, nrm

    def ring_strap(name, t, p0, p1, width, n=14, mat=DK, off=0.008):
        pts, nr = [], []
        for i in range(n + 1):
            phi = math.radians(p0 + (p1 - p0) * i / n)
            p, nn = hpt(t, phi)
            pts.append(p)
            nr.append(nn)
        return ribbon(name, pts, nr, width, off, mat, "head", 0.006)
    out.append(ring_strap("browband", 0.1, -112, 112, 0.022))
    out.append(ring_strap("noseband", 0.63, -165, 165, 0.032, 18))
    out.append(ring_strap("throat", 0.26, 112, 248, 0.02, 12))
    for sgn in (-1, 1):
        pts, nr = [], []
        for i in range(9):
            t = 0.1 + (0.63 - 0.1) * i / 8.0
            phi = math.radians(sgn * (96 + 12 * math.sin(math.pi * i / 8)))
            p, nn = hpt(t, phi)
            pts.append(p)
            nr.append(nn)
        out.append(ribbon("cheek", pts, nr, 0.02, 0.008, DK, "head", 0.005))
        bit_c, _ = hpt(0.86, math.radians(sgn * 92))
        out.append(K.curve_tube("bitring", [bit_c + Vector((0.022 * math.cos(a), 0, 0.022 * math.sin(a))) for a in [math.tau * i / 10 for i in range(10)]], 0.0045, "head", MT, None, True, 0))
        # reins: sag along the neck to the saddle pommel
        r0 = bit_c + Vector((sgn * 0.01, 0.0, -0.02))
        pts = [r0, G(sgn * 0.13, 1.3, -1.05), G(sgn * 0.19, 1.26, -0.78), G(sgn * 0.2, 1.31, -0.52), G(sgn * 0.13, 1.5, -0.3), G(sgn * 0.04, 1.55, -0.26)]
        out.append(K.curve_tube("rein", _chain_smooth(pts), 0.0055, "neck_rein", DK, None, False, 0))
    out.append(K.curve_tube("bit", [hpt(0.86, math.radians(-92))[0], hpt(0.86, math.radians(92))[0]], 0.0042, "head", MT, None, False, 0))
    return out


def _chain_smooth(pts, n=5):
    out = []
    for i in range(len(pts) - 1):
        p0 = pts[max(i - 1, 0)]
        p1, p2 = pts[i], pts[i + 1]
        p3 = pts[min(i + 2, len(pts) - 1)]
        for k in range(n):
            u = k / n
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * u + (2 * p0 - 5 * p1 + 4 * p2 - p3) * u * u + (-p0 + 3 * p1 - 3 * p2 + p3) * u ** 3))
    out.append(pts[-1])
    return out
