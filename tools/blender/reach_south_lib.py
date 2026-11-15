"""Shared builders for the Deep South's models (reach_south.py): masonry, timber, thatch, trees.

Everything is made of the r37 sets (stone / ashlar / timber / iron / wax / cloth / thatch / daub / slate / hewn):
one mesh per set, named <part>__<set>, with metric UVs and macro tone in the vertex colour; r37_west.py's finish()
does the export work. This module only adds the shapes (voussoirs, coursed blocks, rafters, bark) and a tone
function that knows about the weather (moss on tops, damp at the foot, soot, ivy) and about height over the valley.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import r37_west as W
from r37_west import bpy, bmesh, Vector, Matrix, noise, Parts, fbm, smoothstep, make_collision, reset, tris

ROOT = W.ROOT
MODELS = W.MODELS
BLEND = W.BLEND

W.TILE.update({"stone_ivy": 6.0, "thatch": 3.0, "daub": 3.0, "slate": 3.0, "cloth": 2.0, "hewn": 3.0, "wax": 1.0})

# world height of the piece's z = 0 (set by the asset before finish(): the weather follows the real height over the floor)
ZOFF = [0.0]
# per-asset tone options (the finish() tone function reads them): moss amount, soot amount, damp foot height
OPT = {"moss": 1.0, "soot": 0.0, "damp": 3.0, "ivy": 0.0, "warm": 0.0}


def tone(key, co, n, flat):
    z = co.z + ZOFF[0]
    damp = 1.0 - 0.42 * (1.0 - smoothstep(0.0, OPT["damp"], z))
    nz = max(n.z, 0.0)
    if key == "stone_ivy":
        v = 0.7 + 0.5 * fbm(co * 1.3 + Vector((2, 7, 1)), 3)
        return (0.2 * v, 0.42 * v, 0.14 * v)
    if key in ("stone", "ashlar", "hewn"):
        moss_n = fbm(co * 0.23 + Vector((7, 3, 1)), 3)
        moss = smoothstep(-0.02, 0.36, moss_n) * (0.2 + 0.8 * nz) * OPT["moss"]
        moss = moss * (0.5 + 0.5 * (1.0 - smoothstep(0.0, 6.0, z)))
        v = 0.8 + 0.26 * fbm(co * 0.13 + Vector((1, 9, 4)), 3)
        r, g, b = v * damp, v * damp, v * damp
        # ivy: dense dark green patches climbing the faces (not the tops), thicker toward the foot
        iv = smoothstep(0.1, 0.45, fbm(co * 0.17 + Vector((3, 5, 8)), 3)) * OPT["ivy"] * (1.0 - nz) * (1.0 - smoothstep(4.0, 22.0, z) * 0.75)
        r, g, b = r * (1 - moss) + 0.5 * moss, g * (1 - moss) + 0.78 * moss, b * (1 - moss) + 0.36 * moss
        r, g, b = r * (1 - iv) + 0.18 * iv, g * (1 - iv) + 0.34 * iv, b * (1 - iv) + 0.12 * iv
        streak = smoothstep(0.1, 0.6, fbm(Vector((co.x * 0.9, co.y * 0.9, co.z * 0.05)), 2)) * (1.0 - nz) * 0.34
        soot = OPT["soot"] * (0.45 + 0.55 * smoothstep(-0.2, 0.5, fbm(co * 0.3, 2)))
        k = (1 - streak) * (1 - soot * 0.8)
        return (r * k, g * k, b * k)
    if key == "timber":
        v = (0.86 + 0.2 * fbm(co * 0.5, 2)) * (0.62 + 0.38 * damp)
        rot = smoothstep(0.35, 0.75, fbm(co * 0.35 + Vector((2, 2, 2)), 2)) * 0.25
        grey = 0.18 + 0.18 * smoothstep(0.0, 0.6, fbm(co * 0.2 + Vector((4, 1, 6)), 2))
        s = 1.0 - OPT["soot"] * 0.85
        return (v * (1 - rot * 0.4) * (1 - grey * 0.2) * s, v * (1 - rot * 0.1) * s, v * (1 - rot * 0.5) * (1 + grey * 0.15) * s)
    if key == "thatch":
        v = 0.78 + 0.3 * fbm(co * 0.6, 3)
        mo = smoothstep(0.0, 0.4, fbm(co * 0.3 + Vector((5, 5, 1)), 2)) * (0.3 + 0.7 * nz)
        return (v * (1 - mo * 0.5) * (1 - OPT["soot"] * 0.7), v * (1 - mo * 0.1) * (1 - OPT["soot"] * 0.7), v * (1 - mo * 0.5) * (1 - OPT["soot"] * 0.7))
    if key == "daub":
        v = 0.86 + 0.16 * fbm(co * 0.4, 3)
        return (v * damp * (1 - OPT["soot"] * 0.7), v * damp * (1 - OPT["soot"] * 0.7), v * damp * 0.97 * (1 - OPT["soot"] * 0.7))
    if key == "slate":
        v = 0.8 + 0.25 * fbm(co * 0.5, 2)
        return (v * damp, v * damp, v * damp * 1.05)
    return (0.9 * damp, 0.86 * damp, 0.8 * damp)


W.tone_for = tone


def rnd(seed):
    return random.Random(seed)


# --- primitives ---------------------------------------------------------------------------------------
def quad_strip_box(P, key, x0, x1, y0, y1, z0, z1, j=0.0, r=None):
    """An axis-aligned box with corner jitter j (an uneven hand-cut stone)."""
    bm = P.of(key)
    r = r or random
    vs = []
    for x in (x0, x1):
        for y in (y0, y1):
            for z in (z0, z1):
                vs.append(bm.verts.new((x + r.uniform(-j, j), y + r.uniform(-j, j), z + r.uniform(-j, j))))
    # vs index: (xi, yi, zi) -> xi*4 + yi*2 + zi
    f = lambda a, b, c, d: bm.faces.new((vs[a], vs[b], vs[c], vs[d]))
    f(0, 1, 3, 2)
    f(4, 6, 7, 5)
    f(0, 4, 5, 1)
    f(2, 3, 7, 6)
    f(0, 2, 6, 4)
    f(1, 5, 7, 3)


def stone(P, key, c, size, yaw=0.0, pitch=0.0, roll=0.0, j=0.012, r=None, chamfer=0.0):
    """A hand-cut block: a box, each corner nudged, optionally chamfered."""
    r = r or random
    rot = Matrix.Rotation(yaw, 4, 'Z') @ Matrix.Rotation(pitch, 4, 'X') @ Matrix.Rotation(roll, 4, 'Y')
    bm = P.of(key)
    M = Matrix.Translation(Vector(c)) @ rot @ Matrix.Diagonal((size[0], size[1], size[2], 1.0))
    res = bmesh.ops.create_cube(bm, size=1.0, matrix=M)
    vs = res["verts"]
    if j > 0:
        for v in vs:
            v.co += Vector((r.uniform(-j, j), r.uniform(-j, j), r.uniform(-j, j)))
    if chamfer > 0:
        bmesh.ops.bevel(bm, geom=list(set(vs + [e for v in vs for e in v.link_edges])), offset=chamfer, segments=1, affect='EDGES')


def wedge(P, key, cx, cz, r0, r1, a0, a1, y0, y1, inset=0.012, jr=0.012, r=None, ypush=0.0):
    """A voussoir: the arch's ring between radii r0 and r1, angles a0..a1 (rad, 0 = +x, pi = -x), depth y0..y1.
    The sides draw in by `inset` (a joint), the radii wander by jr."""
    r = r or random
    bm = P.of(key)
    d0 = r.uniform(-jr, jr)
    d1 = r.uniform(-jr, jr)
    pts = []
    for yy in (y0, y1):
        for rad, dr in ((r0, d0 * 0.5), (r1, d1)):
            for a in (a0, a1):
                am = (a0 + a1) * 0.5
                ae = a + (am - a) * (inset / max(rad, 0.1))
                rr = rad + dr + (inset if rad == r0 else -inset * 0.0)
                pts.append(bm.verts.new((cx + math.cos(ae) * rr, yy + ypush * (1 if yy == y1 else -1) * 0.0, cz + math.sin(ae) * rr)))
    # order: yy(2) x rad(2) x a(2): idx = yi*4 + ri*2 + ai
    v = pts
    q = lambda a, b, c, d: bm.faces.new((v[a], v[b], v[c], v[d]))
    q(0, 1, 3, 2)      # y0 face
    q(4, 6, 7, 5)      # y1 face
    q(0, 4, 5, 1)      # inner (r0)
    q(2, 3, 7, 6)      # outer (r1)
    q(0, 2, 6, 4)      # a0 side
    q(1, 5, 7, 3)      # a1 side


def prism_polygon(P, key, pts, y0, y1):
    """The polygon `pts` (x, z), in the x-z plane, extruded from y0 to y1 (concave allowed)."""
    bm = P.of(key)
    f0 = [bm.verts.new((x, y0, z)) for x, z in pts]
    f1 = [bm.verts.new((x, y1, z)) for x, z in pts]
    n = len(pts)
    bm.faces.new(f0[::-1])
    bm.faces.new(f1)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((f0[i], f0[j], f1[j], f1[i]))


def sloped_roof_plane(P, key, p0, p1, p2, p3, t=0.0):
    """A quad (with optional thickness t along its normal), p0..p3 counter-clockwise seen from outside."""
    bm = P.of(key)
    v = [bm.verts.new(p) for p in (p0, p1, p2, p3)]
    bm.faces.new(v)
    if t > 0:
        n = (Vector(p1) - Vector(p0)).cross(Vector(p3) - Vector(p0)).normalized() * -t
        w = [bm.verts.new(Vector(p) + n) for p in (p0, p1, p2, p3)]
        bm.faces.new(w[::-1])
        for i in range(4):
            j = (i + 1) % 4
            bm.faces.new((v[j], v[i], w[i], w[j]))


def arc_pts(cx, cz, rad, a0, a1, n):
    return [(cx + math.cos(a0 + (a1 - a0) * k / n) * rad, cz + math.sin(a0 + (a1 - a0) * k / n) * rad) for k in range(n + 1)]


def collision_from(objs, name):
    return make_collision(objs, name, 1.0)


def finish_set(P, name, smooth=()):
    return W.finish(P, name, smooth_keys=smooth)


def export(objs, path, label):
    W.export(objs, path, label)


def fresh():
    reset()
    for k in OPT:
        OPT[k] = {"moss": 1.0, "soot": 0.0, "damp": 3.0, "ivy": 0.0, "warm": 0.0}[k]
    ZOFF[0] = 0.0


def preview(objs, label, views, size=(1280, 720)):
    W.PREVIEW = PREVIEW_DIR[0]
    W.preview(objs, label, views, size)


PREVIEW_DIR = [""]

HIDE = []
