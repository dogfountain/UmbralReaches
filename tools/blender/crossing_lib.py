"""The Crossing's kit (library): coursed, hand-cut masonry for the ruined pilgrims' viaduct (art/models/crossing.glb).

Everything is authored in the GAME's frame (x east, y up, z south: the Crossing's own coordinates, the chasm's centreline on x 0) and
converted to Blender's (x, -z, y) on the way in, so the GLB is placed at the origin and each stone stands where the plan says.

  blk()      one dressed block: a bevelled, slightly warped box in a frame (along, up, across) turned to face `d` (a plan direction);
             the vertex colour is the rift's tone (no moss: ash, soot, damp near the water and the lava) times a per-stone tint
  core()     the dark mortared fill behind the facing (nothing see-through)
  arch_ring  a pointed arch of voussoirs in three layers (two proud faces, the barrel between) and its spandrels
  Col        the collision twin: boxes and quads, joined to one `<name>-colonly` mesh
Sets: hewn (dressed ashlar, each stone its own geometry), slate (paving), stone (the fill, rubble), iron.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import bmesh
from mathutils import Vector, Matrix
import r37_west as W
from r37_west import reset, make_mat, export, preview, MODELS, BLEND, fbm, smoothstep   # noqa: F401
from polish_lib import CP, finish, rnd_for                                                  # noqa: F401

LAVA = -15.5
BED = -17.5
UV_TILE = {"hewn": 1.9, "slate": 2.0, "stone": 3.0, "iron": 2.0}


def bl(p):
    """Game (x, y, z) to Blender."""
    return Vector((p[0], -p[2], p[1]))


def yaw_of(d):
    """Blender yaw that turns a block's `along` axis to the game plan direction d = (dx, dz)."""
    return math.atan2(-d[1], d[0])


def unit(a, b):
    """Plan direction a -> b (game xz) as a unit tuple."""
    dx, dz = b[0] - a[0], b[1] - a[1]
    n = math.hypot(dx, dz)
    return (dx / n, dz / n)


def at(o, d, u=0.0, v=0.0, w=0.0):
    """Game point: origin o (x, y, z), `u` along d (plan), `v` up, `w` across (to the right of d, seen from above: game x for d = north)."""
    sx, sz = -d[1], d[0]
    # right of (dx, dz) in the game plan (x east, z south): (-dz, dx) is the right-hand perpendicular for z pointing south
    return (o[0] + d[0] * u + sx * w, o[1] + v, o[2] + d[1] * u + sz * w)


# ---------------------------------------------------------------------------------------------- tone
def tone(key, co, n):
    z = co.z
    if key == "iron":
        return (0.16, 0.15, 0.15)
    v = 0.78 + 0.24 * fbm(co * 0.19 + Vector((1, 9, 4)), 3)
    low = 1.0 - 0.34 * (1.0 - smoothstep(-16.0, -1.0, z))               # the water's damp, the lava's soot
    nz = max(n.z, 0.0)
    streak = smoothstep(0.1, 0.62, fbm(Vector((co.x * 0.9, co.y * 0.9, co.z * 0.06)), 2)) * (1.0 - nz) * 0.26
    ash = 0.1 * nz * (1.0 - smoothstep(10.0, 28.0, z))
    k = v * low * (1.0 - streak) + ash
    if key == "slate":
        k *= 0.86
        return (k * 0.96, k * 0.97, k * 1.05)
    if key == "stone":
        k *= 0.62
    return (k * 0.98, k * 0.97, k * 1.04)


def _layer(bm):
    return bm.verts.layers.float_color.get("vc") or bm.verts.layers.float_color.new("vc")


def _paint(bm, verts, key, mul=1.0):
    lay = _layer(bm)
    bm.normal_update()
    for v in verts:
        t = tone(key, v.co, v.normal)
        v[lay] = (min(t[0] * mul, 1.4), min(t[1] * mul, 1.4), min(t[2] * mul, 1.4), 1.0)


def blk(P, key, c, size, d, rnd, bevel=0.05, warp=0.012, roll=0.0, pitch=0.0, tint=True, mul=1.0):
    """A dressed block at game point c, size (along, up, across), `along` turned to plan direction d (a tuple). roll turns it about its
    across axis (voussoirs), pitch about its along axis."""
    bm = P.of(key)
    _layer(bm)
    before = set(bm.verts)
    rot = Matrix.Rotation(yaw_of(d), 4, 'Z') @ Matrix.Rotation(pitch, 4, 'X') @ Matrix.Rotation(roll, 4, 'Y')
    M = Matrix.Translation(bl(c)) @ rot @ Matrix.Diagonal((size[0], size[2], size[1], 1.0))
    r = bmesh.ops.create_cube(bm, size=1.0, matrix=M)
    w = min(bevel, min(size) * 0.3)
    if w > 0.004:
        geom = list({e for v in r["verts"] for e in v.link_edges})
        bmesh.ops.bevel(bm, geom=geom, offset=w, segments=1, affect='EDGES')
    mine = set(bm.verts) - before
    if warp:
        for v in mine:
            v.co += Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-1, 1))) * warp
    _paint(bm, mine, key, mul * (rnd.uniform(0.9, 1.08) if tint else 1.0))


def core(P, c, size, d, key="stone", mul=1.0):
    """Plain fill (no bevel, no warp): the mortared core behind the facing."""
    bm = P.of(key)
    _layer(bm)
    before = set(bm.verts)
    M = Matrix.Translation(bl(c)) @ Matrix.Rotation(yaw_of(d), 4, 'Z') @ Matrix.Diagonal((size[0], size[2], size[1], 1.0))
    bmesh.ops.create_cube(bm, size=1.0, matrix=M)
    _paint(bm, set(bm.verts) - before, key, mul)


def hexa(P, key, pts, mul=1.0, bevel=0.0):
    """A hexahedron from 8 game points: the bottom four then the top four, each counter-clockwise seen from above (game frame), the same
    corner order in both. Used for wedge treads and the helix's courses."""
    bm = P.of(key)
    _layer(bm)
    vs = [bm.verts.new(bl(p)) for p in pts]
    # game-frame ccw-from-above is clockwise in Blender (z flipped in the plan): recalc_face_normals fixes the winding afterwards
    q = lambda a, b, c, e: bm.faces.new((vs[a], vs[b], vs[c], vs[e]))
    q(0, 1, 2, 3)
    q(4, 7, 6, 5)
    q(0, 4, 5, 1)
    q(1, 5, 6, 2)
    q(2, 6, 7, 3)
    q(3, 7, 4, 0)
    bmesh.ops.recalc_face_normals(bm, faces=list({f for v in vs for f in v.link_faces}))
    if bevel > 0.004:
        geom = list({e for v in vs for e in v.link_edges})
        bmesh.ops.bevel(bm, geom=geom, offset=bevel, segments=1, affect='EDGES')
    bm.normal_update()
    lay = _layer(bm)
    for v in bm.verts:
        if v[lay][3] == 0.0:
            t = tone(key, v.co, v.normal)
            v[lay] = (min(t[0] * mul, 1.4), min(t[1] * mul, 1.4), min(t[2] * mul, 1.4), 1.0)


def seg_runs(rnd, a, b, lmin, lmax):
    """Cut [a, b] into stone lengths lmin..lmax (a running bond)."""
    out = []
    x = a
    while x < b - 0.04:
        ln = rnd.uniform(lmin, lmax)
        if b - x - ln < lmin * 0.55:
            ln = b - x
        out.append((x, min(x + ln, b)))
        x += ln
    return out


def rows(rnd, y0, y1, hmin=0.46, hmax=0.62):
    out = []
    y = y0
    while y < y1 - 0.05:
        h = rnd.uniform(hmin, hmax)
        if y1 - y - h < hmin * 0.55:
            h = y1 - y
        out.append((y, y + h))
        y += h
    return out


# ---------------------------------------------------------------------------------------------- collision
class Col:
    """Collision twin: boxes and quads in the game frame, one joined mesh."""

    def __init__(self):
        self.bm = bmesh.new()

    def box(self, c, size, d=(1.0, 0.0), pitch=0.0):
        M = Matrix.Translation(bl(c)) @ Matrix.Rotation(yaw_of(d), 4, 'Z') @ Matrix.Rotation(pitch, 4, 'X') @ Matrix.Diagonal((size[0], size[2], size[1], 1.0))
        bmesh.ops.create_cube(self.bm, size=1.0, matrix=M)

    def quad(self, p0, p1, p2, p3):
        vs = [self.bm.verts.new(bl(p)) for p in (p0, p1, p2, p3)]
        try:
            self.bm.faces.new(vs)
            self.bm.faces.new(vs[::-1])        # both sides: a ramp is walked from above, rayed from below
        except ValueError:
            pass

    def prism(self, pts, y0, y1):
        """A convex plan polygon (game xz points, ccw or cw) extruded from y0 to y1."""
        bm = self.bm
        lo = [bm.verts.new(bl((x, y0, z))) for (x, z) in pts]
        hi = [bm.verts.new(bl((x, y1, z))) for (x, z) in pts]
        n = len(pts)
        try:
            bm.faces.new(lo)
            bm.faces.new(hi[::-1])
            for i in range(n):
                j = (i + 1) % n
                bm.faces.new((lo[i], lo[j], hi[j], hi[i]))
        except ValueError:
            pass

    def finish(self, name):
        bm = self.bm
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        me = bpy.data.meshes.new(name + "-colonly")
        bm.to_mesh(me)
        bm.free()
        ob = bpy.data.objects.new(name + "-colonly", me)
        bpy.context.scene.collection.objects.link(ob)
        return ob


# ---------------------------------------------------------------------------------------------- arches
def pointed(w, rise):
    """Radius and centre offset of a pointed arch of opening w and rise `rise` above the springing line: two arcs whose centres lie on
    the springing line at the far jambs' sides. Returns (R, offset of each arc's centre from the middle, phi at the apex)."""
    hw = w * 0.5
    R = (rise * rise + hw * hw) / (2.0 * hw)
    off = R - hw
    return R, off, math.acos(max(-1.0, min(1.0, off / R)))


def arch_ring(P, rnd, o, d, w, rise, depth, t=0.62, layers=True, mul=1.0):
    """A pointed arch's voussoirs: o = game point at the middle of the opening on the springing line, d the plan direction across the
    opening (the bay's run), `depth` the arch's length along its barrel (across the route). Three layers: two proud faces (0.8 deep) and the
    barrel. Returns the apex height above o."""
    R, off, phi_max = pointed(w, rise)
    half = max(3, int(round(R * phi_max / 0.6)))          # voussoirs a side (about 0.6 m of intrados each), and a keystone
    face_d = 0.8
    lay_ = [(-1, face_d, 0.07), (0, depth - 2 * face_d, 0.0), (1, face_d, 0.07)] if layers else [(0, depth, 0.0)]
    dphi = phi_max / (half + 0.5)
    for lay, ld, proud in lay_:
        wcen = 0.0 if lay == 0 else lay * (depth - ld) * 0.5
        for i in range(half):
            phi = dphi * (i + 0.5)
            rc = R + t * 0.5
            u = -off + rc * math.cos(phi)
            v = rc * math.sin(phi)
            long_ = i % 2 == 0
            size = (rc * dphi * 0.97, t * (1.0 if long_ else 0.86), ld + 2 * proud)
            for sgn in (1, -1):
                roll = (math.pi * 0.5 - phi) * sgn
                blk(P, "hewn", at(o, d, sgn * u, v, wcen), size, d, rnd, bevel=0.04, warp=0.008, roll=roll, mul=mul)
        # the keystone, a little taller than the ring
        blk(P, "hewn", at(o, d, 0.0, R * math.sin(phi_max) + t * 0.5 + 0.05, wcen), (0.5, t + 0.14, ld + 2 * proud), d, rnd, bevel=0.05, warp=0.006, mul=mul)
    return R * math.sin(phi_max)


def arch_extent_u(w, rise, v, t=0.62):
    """Half width (u) of the arch ring's outer edge at height v over the springing line; None above the extrados apex."""
    R, off, phi_max = pointed(w, rise)
    ro = R + t
    if v <= 0.0:
        return w * 0.5 + t
    apex = ro * math.sin(phi_max) + 0.0
    if v >= apex:
        return None
    return -off + math.sqrt(max(ro * ro - v * v, 0.0))


def facing(P, rnd, o, d, u0, u1, v0, v1, w_face, depth_face=0.34, lmin=0.9, lmax=1.55, excl=None, rowh=(0.46, 0.62), skip=0.0):
    """Coursed face blocks on the wall at across offset w_face (the face plane), over u0..u1, v0..v1 (over o); `excl(va, vb)` gives the
    u-intervals still to fill in that row (the rest is arch ring or opening). `skip` leaves that fraction of stones out (a ruin)."""
    for (va, vb) in rows(rnd, v0, v1, *rowh):
        spans = excl(va, vb) if excl else [(u0, u1)]
        for (a, b) in spans:
            a = max(a, u0)
            b = min(b, u1)
            if b - a < 0.15:
                continue
            off = rnd.uniform(0.0, 0.5)
            for (xa, xb) in seg_runs(rnd, a + (off if b - a > 2.0 else 0.0) * 0.0, b, lmin, lmax):
                if skip and rnd.random() < skip:
                    continue
                c = at(o, d, 0.5 * (xa + xb), 0.5 * (va + vb), w_face)
                blk(P, "hewn", c, (xb - xa - 0.025, vb - va - 0.025, depth_face), d, rnd, bevel=0.035, warp=0.01)


def spandrel(P, rnd, o, d, half_len, w, rise, v_top, depth, t=0.62, face=0.34):
    """The walling over one arch: from the springing line up to v_top, facing both sides, the fill between. o is the middle of the opening on the
    springing line, `half_len` half the pier-to-pier distance."""
    def excl(va, vb):
        ue = arch_extent_u(w, rise, va, t)
        if ue is None:
            return [(-half_len, half_len)]
        # a row whose bottom is below the ring's outer edge at its top: take the edge at the row's top (blocks stay clear of the ring)
        ue2 = arch_extent_u(w, rise, vb, t)
        ue = max(ue, ue2) if ue2 is not None else ue
        return [(-half_len, -ue), (ue, half_len)] if ue < half_len else []
    for sgn in (-1, 1):
        facing(P, rnd, o, d, -half_len, half_len, 0.0, v_top, sgn * (depth * 0.5 - face * 0.5), face, excl=excl)
    # the fill between the faces, row by row (nothing see-through)
    for (va, vb) in rows(rnd, 0.0, v_top, 1.2, 1.2):
        ue = arch_extent_u(w, rise, va, t)
        ue2 = arch_extent_u(w, rise, vb, t)
        ue = max(ue, ue2) if (ue is not None and ue2 is not None) else (ue if ue2 is None else ue2)
        if ue is None:
            core(P, at(o, d, 0.0, 0.5 * (va + vb), 0.0), (2 * half_len, vb - va, depth - 2 * face + 0.02), d)
        elif ue < half_len:
            for sg in (-1, 1):
                core(P, at(o, d, sg * 0.5 * (ue + half_len), 0.5 * (va + vb), 0.0), (half_len - ue, vb - va, depth - 2 * face + 0.02), d)
