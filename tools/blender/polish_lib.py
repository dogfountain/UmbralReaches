"""Shared helpers for the polish pass's models (r39 polish, 20 Nov): canes and thorns, sacks, caps and gills, with the
vertex colour authored per vertex (no tone pass), one object per material set, exported through r37_west.export.

Frame as everywhere: Blender (x, y, z) = the game's local (x, -z, y), 1 BU = 1 m.
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
from r37_west import reset, make_mat, Parts, box, beam, cyl, ring_loft, export, preview, MODELS, BLEND, fbm, smoothstep   # noqa: F401


class CP:
    """Geometry grouped by material set with per-vertex colour (`col` layer written on every vertex we make)."""

    def __init__(self):
        self.bm = {}

    def of(self, key):
        if key not in self.bm:
            b = bmesh.new()
            self.bm[key] = b
        return self.bm[key]


def tube(P, key, pts, radii, sides=5, col=(0.5, 0.5, 0.5, 1.0), col_tip=None, cap_end=True, ref=Vector((0, 0, 1)), twist=0.0):
    """A tapered tube along the points (ring per point), vertex colour lerped base to tip."""
    bm = P.of(key)
    lay = bm.verts.layers.float_color.get("vc") or bm.verts.layers.float_color.new("vc")
    n = len(pts)
    rings = []
    for i, p in enumerate(pts):
        p = Vector(p)
        t = (Vector(pts[min(i + 1, n - 1)]) - Vector(pts[max(i - 1, 0)]))
        if t.length < 1e-6:
            t = Vector((0, 0, 1))
        t.normalize()
        r0 = ref if abs(t.dot(ref)) < 0.95 else Vector((1, 0, 0))
        a = t.cross(r0).normalized()
        b = t.cross(a).normalized()
        k = i / max(n - 1, 1)
        c = tuple(col[j] + ((col_tip or col)[j] - col[j]) * k for j in range(4))
        ring = []
        for s in range(sides):
            ang = math.tau * s / sides + twist * i
            v = bm.verts.new(p + (a * math.cos(ang) + b * math.sin(ang)) * radii[i])
            v[lay] = c
            ring.append(v)
        rings.append(ring)
    for i in range(n - 1):
        for s in range(sides):
            try:
                bm.faces.new((rings[i][s], rings[i][(s + 1) % sides], rings[i + 1][(s + 1) % sides], rings[i + 1][s]))
            except ValueError:
                pass
    if cap_end:
        try:
            bm.faces.new(rings[-1])
        except ValueError:
            pass
    return rings


def thorn(P, key, base, d, ln, r, col, col_tip=None):
    """A three-sided thorn: a pyramid from `base` along d."""
    bm = P.of(key)
    lay = bm.verts.layers.float_color.get("vc") or bm.verts.layers.float_color.new("vc")
    base = Vector(base)
    d = Vector(d).normalized()
    r0 = Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))
    a = d.cross(r0).normalized()
    b = d.cross(a).normalized()
    ring = []
    for s in range(3):
        ang = math.tau * s / 3.0
        v = bm.verts.new(base + (a * math.cos(ang) + b * math.sin(ang)) * r)
        v[lay] = col
        ring.append(v)
    tip = bm.verts.new(base + d * ln)
    tip[lay] = col_tip or col
    for s in range(3):
        try:
            bm.faces.new((ring[s], ring[(s + 1) % 3], tip))
        except ValueError:
            pass


def blob(P, key, c, radii, col, seg=8, rings=5, yaw=0.0, rough=0.0, rnd=None, colfn=None):
    """A UV ellipsoid at c with radii (x, y, z), optional vertex jitter and a colour function colfn(local_unit_vec) -> rgba."""
    bm = P.of(key)
    lay = bm.verts.layers.float_color.get("vc") or bm.verts.layers.float_color.new("vc")
    top = None
    ringv = []
    rot = Matrix.Rotation(yaw, 3, 'Z')
    for i in range(rings + 1):
        phi = math.pi * i / rings
        row = []
        for j in range(seg if 0 < i < rings else 1):
            th = math.tau * j / seg
            u = Vector((math.sin(phi) * math.cos(th), math.sin(phi) * math.sin(th), math.cos(phi)))
            q = Vector((u.x * radii[0], u.y * radii[1], u.z * radii[2]))
            if rough and rnd:
                q *= 1.0 + rnd.uniform(-rough, rough)
            v = bm.verts.new(Vector(c) + rot @ q)
            v[lay] = colfn(u) if colfn else col
            row.append(v)
        ringv.append(row)
    for i in range(rings):
        r0, r1 = ringv[i], ringv[i + 1]
        for j in range(seg):
            a, b = r0[j % len(r0)], r0[(j + 1) % len(r0)]
            c2, d = r1[(j + 1) % len(r1)], r1[j % len(r1)]
            vs = [a, b, c2, d]
            uniq = []
            for v in vs:
                if v not in uniq:
                    uniq.append(v)
            if len(uniq) >= 3:
                try:
                    bm.faces.new(uniq)
                except ValueError:
                    pass


def solid_box(P, key, c, size, col, yaw=0.0, pitch=0.0, roll=0.0, colfn=None):
    """A plain box with a flat vertex colour (or colfn(world co) -> rgba)."""
    bm = P.of(key)
    lay = bm.verts.layers.float_color.get("vc") or bm.verts.layers.float_color.new("vc")
    rot = Matrix.Rotation(yaw, 4, 'Z') @ Matrix.Rotation(pitch, 4, 'X') @ Matrix.Rotation(roll, 4, 'Y')
    M = Matrix.Translation(Vector(c)) @ rot @ Matrix.Diagonal((size[0], size[1], size[2], 1.0))
    r = bmesh.ops.create_cube(bm, size=1.0, matrix=M)
    for v in r["verts"]:
        v[lay] = colfn(v.co) if colfn else col


def finish(P, name, smooth_keys=(), uv_tile=None):
    """One object per key: `<name>__<key>`, UVs by the dominant axis (metric, uv_tile m per tile), the vertex colour layer
    written as the active colour, a material named for the key. Returns the objects."""
    uv_tile = uv_tile or {}
    objs = []
    for key, bm in P.bm.items():
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.normal_update()
        uv = bm.loops.layers.uv.new("UVMap")
        col = bm.loops.layers.float_color.new("Col")
        lay = bm.verts.layers.float_color.get("vc")
        tile = uv_tile.get(key, 2.0)
        sm = key in smooth_keys
        for f in bm.faces:
            f.smooth = sm
            n = f.normal
            ax = max(range(3), key=lambda i: abs(n[i]))
            for l in f.loops:
                co = l.vert.co
                if ax == 0:
                    l[uv].uv = (co.y / tile, co.z / tile)
                elif ax == 1:
                    l[uv].uv = (co.x / tile, co.z / tile)
                else:
                    l[uv].uv = (co.x / tile, co.y / tile)
                c = l.vert[lay] if lay is not None else (1, 1, 1, 1)
                l[col] = (c[0], c[1], c[2], 1.0)
        me = bpy.data.meshes.new("%s__%s" % (name, key))
        bm.to_mesh(me)
        bm.free()
        if "vc" in me.attributes:
            me.attributes.remove(me.attributes["vc"])
        me.materials.append(make_mat(key))
        ob = bpy.data.objects.new("%s__%s" % (name, key), me)
        bpy.context.scene.collection.objects.link(ob)
        if "Col" in me.color_attributes:
            me.color_attributes.active_color = me.color_attributes["Col"]
            me.color_attributes.render_color_index = list(me.color_attributes.keys()).index("Col")
        objs.append(ob)
    return objs


def rnd_for(seed):
    return random.Random(seed)
