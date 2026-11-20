"""The Mother Tree (Cinder Orchard): a burned giant, hollow, split open down one side.

  tools/blender/run.sh orchard_mother_tree.py -- [--preview DIR]

Authored in Godot coordinates (origin: the trunk's axis at ground level; the split and the way in face +Z).
  Trunk      the charred shell, outer and inner faces: buttressed and flared at the foot, split from the ground to the
             broken crown on the +Z side (a door 2.2 m clear at the foot: zone fit, it was 1.4, a hand's width at the top), a ragged burned
             rim with two horns left standing
  Roots      six flared roots running out and down into the ground (none across the way in)
  Limbs      five great limbs off the crown, each forked, two broken short, with dead spikes
  MotherFar  the silhouette in about 250 triangles (drawn past 90 m)
  MotherCol  the collision proxy (never drawn): the shell's two faces, the way in left open
Writes art/models/orchard_mother_tree.glb (textures inside). Numbers the game uses are in the docstring only: the
hollow's inner radius is 1.15 m at the foot, the door's half angle 1.35 rad.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
import bpy
import bmesh
from mathutils import Vector

import r37_south_lib as L
from r37_south_lib import B, hash3, smooth, fbm, tint

PREVIEW = None
if "--" in sys.argv:
    a = sys.argv[sys.argv.index("--") + 1:]
    if "--preview" in a:
        PREVIEW = a[a.index("--preview") + 1]

L.TEX_DIR = os.path.join(L.BLEND_DIR, "textures", "orchard")

NC = 40                                   # columns round the trunk
YS = [-0.8, -0.35, 0.1, 0.5, 0.95, 1.4, 1.85, 2.3, 2.75, 3.2, 3.65, 4.1, 4.55, 5.0, 5.45, 5.9, 6.35, 6.8, 7.3, 7.8]
ROOTS = [1.6, 2.1, 2.75, 3.6, 4.35, 4.68]             # azimuths (0 is +Z, the way in)
LIMBS = [(0.95, 1.0), (2.15, 0.55), (3.25, 1.0), (4.35, 1.0), (5.5, 0.62)]   # azimuth, length (1 whole, < 1 broken short)


def lerp(a, b, t):
    return a + (b - a) * t


def sm(x, a, b):
    t = min(max((x - a) / (b - a), 0.0), 1.0)
    return t * t * (3.0 - 2.0 * t)


def interp(tab, y):
    if y <= tab[0][0]:
        return tab[0][1]
    for (y0, r0), (y1, r1) in zip(tab, tab[1:]):
        if y <= y1:
            return lerp(r0, r1, (y - y0) / (y1 - y0))
    return tab[-1][1]


def wrap(a):
    return (a + math.pi) % math.tau - math.pi


BASE = [(-0.8, 1.98), (0.0, 1.82), (0.9, 1.64), (2.4, 1.52), (4.2, 1.47), (5.3, 1.58), (6.2, 1.5), (7.8, 1.3)]


def flare(a, y):
    """The roots' buttresses: ridges that widen toward the ground."""
    k = max(0.0, 1.0 - (y + 0.8) / 3.2)
    f = 0.0
    for ra in ROOTS:
        d = wrap(a - ra)
        f += math.exp(-(d / 0.2) ** 2)
    return f * k * k * 1.0


def r_out(a, y):
    x, z = math.sin(a), math.cos(a)
    n = 0.11 * hash3(x * 2.3, y * 0.55, z * 2.3, 3) + 0.05 * hash3(x * 6.1, y * 1.6, z * 6.1, 5)
    ridge = (0.1 * math.cos(7.0 * a + 0.8 * math.sin(y * 0.5)) + 0.045 * math.cos(17.0 * a + 1.3 * math.sin(y * 0.8 + 1.0))) * (1.0 - 0.45 * sm(y, 3.0, 7.0))
    return interp(BASE, y) * (1.0 + n) + ridge + flare(a, y)


def r_in(a, y):
    x, z = math.sin(a), math.cos(a)
    wall = 0.6 - 0.3 * sm(y, 0.3, 5.0) + 0.07 * hash3(x * 3.0, y * 0.9, z * 3.0, 11)
    n = 0.05 * hash3(x * 2.3, y * 0.55, z * 2.3, 3)
    return max(interp(BASE, y) * (1.0 + n) - wall, 0.55)


def top(a):
    """The burned rim's height at azimuth a: low beside the split, two horns left standing."""
    x, z = math.sin(a), math.cos(a)
    t = 5.75 + 0.75 * hash3(x * 1.9, 0.3, z * 1.9, 9) + 0.3 * hash3(x * 5.0, 1.0, z * 5.0, 12)
    t += 1.5 * math.exp(-(wrap(a - 2.75) / 0.2) ** 2) + 1.1 * math.exp(-(wrap(a - 4.9) / 0.16) ** 2)
    t -= 0.9 * math.exp(-(wrap(a) / 0.55) ** 2)
    return t


def half_gap(y):
    """Half the angle of the split at height y."""
    if y < 1.7:
        return 1.35
    if y < 3.2:
        return lerp(1.35, 0.2, sm(y, 1.7, 3.2))
    return lerp(0.2, 0.1, sm(y, 3.2, 6.0))


def pos(a, r, y):
    return Vector((math.sin(a) * r, y, math.cos(a) * r))


# --- textures ------------------------------------------------------------------------------------

def tex_char_bark(n, seed):
    """Burned bark (a tile is ~3 m): the oak's plates and furrows, black, the plate tops greyed with ash, a few
    scales of charcoal sheen. Strong relief."""
    _alb, height, _r = L.tex_bark(n, seed, dead=True)
    fine = fbm(n, 2.2, seed + 31, aniso=2.0)
    ash = smooth(fbm(n, 2.8, seed + 32), 0.5, 0.8) * smooth(height, 0.35, 0.8)
    scorch = smooth(fbm(n, 3.0, seed + 33), 0.55, 0.8)
    tone = np.clip(height ** 1.4 * (0.75 + 0.5 * (fine - 0.5)), 0.0, 1.0)
    alb = tint(tone, (0.02, 0.018, 0.018), (0.19, 0.175, 0.165))
    alb = alb * (1.0 - 0.6 * ash[..., None]) + np.array([0.42, 0.41, 0.39])[None, None, :] * 0.6 * ash[..., None]
    # what the fire left of the bark's own brown, low on the plates in patches
    brown = (1.0 - scorch) * smooth(height, 0.2, 0.6) * 0.35
    alb = alb * (1.0 - brown[..., None]) + np.array([0.2, 0.13, 0.085])[None, None, :] * brown[..., None]
    sheen = smooth(fbm(n, 2.4, seed + 34), 0.62, 0.8) * smooth(height, 0.5, 0.9) * (1.0 - ash)
    rough = np.clip(0.95 - 0.4 * sheen + 0.05 * (fine - 0.5), 0.45, 1.0)
    return alb, height, rough


def tex_char_heart(n, seed):
    """The hollow's burned inside (a tile is ~1.5 m): alligatored charcoal, square blocks between deep cracks, the
    cracks black, the block faces a dull blue-black with a sheen, ash in the lee."""
    yy = np.arange(n)[:, None].astype(np.float64) * np.ones((1, n))
    xx = np.arange(n)[None, :].astype(np.float64) * np.ones((n, 1))
    w1 = fbm(n, 3.2, seed + 1)
    w2 = fbm(n, 3.0, seed + 2)
    w3 = fbm(n, 2.4, seed + 3)
    # long splits up the grain, close together; the cross-checks few, short and wandering (regular ones read as courses)
    px = np.abs(np.sin(np.pi * ((xx + (w1 - 0.5) * n * 0.07) / (n / 13.0) + (w2 - 0.5) * 1.6)))
    py = np.abs(np.sin(np.pi * ((yy + (w2 - 0.5) * n * 0.3 + (w1 - 0.5) * n * 0.2) / (n / 4.0) + (w3 - 0.5) * 3.2)))
    gate = smooth(fbm(n, 2.6, seed + 7), 0.45, 0.6)                    # where a cross-check opens at all
    block = smooth(np.minimum(px, 1.0 - gate * (1.0 - np.minimum(py * 1.6, 1.0))), 0.06, 0.5)
    fine = fbm(n, 1.6, seed + 4, aniso=6.0)
    dome = np.clip(block * (0.7 + 0.3 * px), 0.0, 1.0)
    height = np.clip(dome * (0.72 + 0.25 * (w3 - 0.5)) + 0.06 * (fine - 0.5), 0.0, 1.0)
    tone = np.clip(dome * (0.6 + 0.5 * (fine - 0.5) + 0.3 * (w1 - 0.5)), 0.0, 1.0)
    alb = tint(tone, (0.012, 0.012, 0.014), (0.12, 0.125, 0.14))
    ash = smooth(fbm(n, 2.6, seed + 5), 0.6, 0.85) * block
    alb = alb * (1.0 - 0.45 * ash[..., None]) + np.array([0.4, 0.39, 0.37])[None, None, :] * 0.45 * ash[..., None]
    rough = np.clip(0.98 - 0.5 * block * (1.0 - ash) + 0.08 * (fine - 0.5), 0.4, 1.0)
    return alb, height, rough


# --- the trunk -----------------------------------------------------------------------------------

def col_angle(j, nc):
    """Signed azimuth of column j (no column on the split's own line)."""
    return -math.pi + (j + 0.5) * math.tau / nc


def shell(bm, uvl, mat_out, mat_in, nc, ys, rim=True, jambs=True, smooth_f=True, inner=True):
    """The trunk's two faces on a grid: columns pulled back to the split's edge, rows pulled down to the rim."""
    def vert_a(j, y):
        a = col_angle(j, nc)
        hg = half_gap(max(y, 0.0))
        return math.copysign(max(abs(a), hg), a)

    grid_o = []
    grid_i = []
    for y in ys:
        ro = []
        ri = []
        for j in range(nc):
            a0 = col_angle(j, nc)
            yy = min(y, top(a0))
            a = vert_a(j, yy)
            ro.append((bm.verts.new(pos(a, r_out(a, yy), yy)), a, yy))
            ri.append((bm.verts.new(pos(a, r_in(a, yy), yy)), a, yy))
        grid_o.append(ro)
        grid_i.append(ri)

    def quad(vs, mat, want, tile, radial=False):
        """A face from four (vert, a, y); `want` = +1 its normal looks away from the axis, -1 toward it, 0 as given."""
        if len({v[0] for v in vs}) < 4:
            return
        pts = [v[0].co for v in vs]
        if (pts[0] - pts[2]).length < 1e-4 or (pts[1] - pts[3]).length < 1e-4:
            return
        try:
            f = bm.faces.new([v[0] for v in vs])
        except ValueError:
            return
        f.material_index = mat
        f.smooth = smooth_f
        f.normal_update()
        if want != 0:
            c = f.calc_center_median()
            rad = Vector((c.x, 0.0, c.z))
            if rad.length > 1e-5 and f.normal.dot(rad) * want < 0.0:
                f.normal_flip()
        for l in f.loops:
            for (v, a, y) in vs:
                if v is l.vert:
                    l[uvl].uv = ((math.hypot(v.co.x, v.co.z) if radial else a * 1.6) / tile, y / tile)
        return f

    mid = nc // 2 - 1                       # the cell between columns mid and mid + 1 spans the split
    for i in range(len(ys) - 1):
        for j in range(nc):
            if j == mid:
                continue
            j2 = (j + 1) % nc
            o = [grid_o[i][j], grid_o[i][j2], grid_o[i + 1][j2], grid_o[i + 1][j]]
            if abs(o[0][2] - o[3][2]) < 1e-4 and abs(o[1][2] - o[2][2]) < 1e-4:
                continue                    # above the rim
            quad(o, mat_out, 1, 3.0)
            if inner:
                quad([grid_i[i][j], grid_i[i][j2], grid_i[i + 1][j2], grid_i[i + 1][j]], mat_in, -1, 1.5)
    if rim:
        # the burned rim: outer to inner along the top row
        last = len(ys) - 1
        for j in range(nc):
            if j == mid:
                continue
            j2 = (j + 1) % nc
            f = quad([grid_o[last][j], grid_o[last][j2], grid_i[last][j2], grid_i[last][j]], mat_in, 0, 1.5)
            if f is not None and f.normal.y < 0.0:
                f.normal_flip()
    if jambs:
        for (j, sgn) in ((mid, 1.0), (mid + 1, -1.0)):
            for i in range(len(ys) - 1):
                f = quad([grid_o[i][j], grid_i[i][j], grid_i[i + 1][j], grid_o[i + 1][j]], mat_in, 0, 1.5, True)
                if f is not None:
                    c = f.calc_center_median()
                    tang = Vector((math.cos(0.0), 0.0, -math.sin(0.0)))        # +X at the split
                    if f.normal.dot(tang) * sgn > 0.0:                          # each jamb looks into the gap
                        f.normal_flip()


def _preview(path, mode, look_at, dist, views, res, lens):
    """L.preview with the shading this script set (L.preview switches to textures)."""
    sc = bpy.context.scene
    sc.render.resolution_x, sc.render.resolution_y = res
    cam = bpy.data.objects.get("Cam")
    if cam is None:
        cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
        sc.collection.objects.link(cam)
    cam.data.lens = lens
    cam.data.clip_start = 0.05
    cam.data.clip_end = 500
    sc.camera = cam
    for i, (az, el) in enumerate(views):
        a = math.radians(az)
        p = Vector((look_at[0] + math.sin(a) * dist * math.cos(el), -(look_at[2] + math.cos(a) * dist * math.cos(el)), look_at[1] + dist * math.sin(el)))
        cam.location = p
        cam.rotation_euler = (L.G(look_at) - p).to_track_quat('-Z', 'Y').to_euler()
        sc.render.filepath = path.replace(".png", "_%d.png" % i)
        bpy.ops.render.render(write_still=True)
        print("PREVIEW", sc.render.filepath)


def build():
    L.reset()
    bark = L.pbr("Mother_CharBark", tex_char_bark(1024, 4101), 4.2)
    heart = L.pbr("Mother_CharHeart", tex_char_heart(512, 4102), 3.4)
    mats = {"bark": bark, "heart": heart}
    objs = []

    tb = B("Trunk", mats)
    shell(tb.bm, tb.uv, 0, 1, NC, YS)
    objs.append(tb.finish())

    # roots: off each buttress, out and down
    rb = B("Roots", mats)
    for k, ra in enumerate(ROOTS):
        bend = 0.3 * hash3(k * 3.1, 0.0, 1.7, 21)
        wig = 0.16 * (1.0 if k % 2 == 0 else -1.0)
        ln = 4.3 + 0.9 * hash3(k * 1.3, 2.0, 0.4, 22)
        pts = [pos(ra, 1.45, 1.8), pos(ra, 1.9, 1.0), pos(ra + wig * 0.25, 2.3, 0.42), pos(ra + bend * 0.5 - wig * 0.3, 3.0, 0.12), pos(ra + bend * 0.8 + wig * 0.35, 3.7, -0.06),
               pos(ra + bend - wig * 0.2, ln, -0.35), pos(ra + bend * 1.2, ln + 0.8, -1.0)]
        rb.tube_path(pts, [0.3, 0.58, 0.5, 0.38, 0.28, 0.18, 0.07], "bark", sides=9, bark=3.0, jit=0.09, seed=30 + k, cap_end=False)
        # a side root off the second bend
        sa = ra + bend + (0.5 if k % 2 == 0 else -0.5)
        rb.tube_path([pos(ra + bend * 0.4, 2.5, 0.2), pos(lerp(ra, sa, 0.55), 3.2, 0.02), pos(sa, 3.9, -0.2), pos(sa + wig, 4.6, -0.9)], [0.26, 0.2, 0.13, 0.04], "bark", sides=7, bark=3.0, jit=0.05, seed=40 + k, cap_end=False)
    objs.append(rb.finish())

    # limbs: off the crown, arching out; forked; two broken short
    lb = B("Limbs", mats)
    limb_paths = []
    for k, (la, full) in enumerate(LIMBS):
        rise = 0.9 * hash3(k * 2.2, 1.0, 0.3, 51)
        sway = 0.3 * hash3(k * 1.7, 0.5, 2.3, 52)
        y0 = min(top(la) - 0.9, 5.3)
        ctl = [pos(la, 0.95, y0 - 0.5), pos(la, 1.75, y0 + 0.35), pos(la + sway * 0.3, 3.1, y0 + 1.35 + rise * 0.3),
               pos(la + sway * 0.7, 4.7, y0 + 1.95 + rise * 0.7), pos(la + sway, 6.1, y0 + 1.8 + rise), pos(la + sway * 1.2, 7.2, y0 + 1.2 + rise * 1.3)]
        for q in range(2, len(ctl)):                 # a dead limb is not a smooth arc: each joint off its line
            ctl[q] = ctl[q] + Vector((hash3(q * 2.1, k, 0.0, 55), 0.6 * hash3(q * 2.1, k, 4.0, 56), hash3(q * 2.1, k, 8.0, 57))) * (0.28 + 0.1 * q)
        rad = [0.6, 0.54, 0.42, 0.3, 0.19, 0.07]
        if full < 1.0:
            cut = 3 if full < 0.6 else 4
            ctl = ctl[:cut]
            rad = rad[:cut]
            rad[-1] *= 0.9
        lb.tube_path(ctl, rad, "bark", sides=10, bark=3.0, jit=0.085, seed=60 + k, cap_end=True)
        limb_paths.append((ctl, rad))
        if full < 1.0:
            # the break: splinters standing off the stump
            end = ctl[-1]
            d = (ctl[-1] - ctl[-2]).normalized()
            for s in range(5):
                off = Vector((hash3(s * 1.9, k, 0.0, 71), hash3(s * 1.9, k, 5.0, 72), hash3(s * 1.9, k, 9.0, 73))) * rad[-1] * 1.5
                lb.tube(end + off * 0.6 - d * 0.1, end + off + d * (0.35 + 0.5 * abs(hash3(s, k, 3.0, 74))), 0.045, 0.008, "heart", sides=4, bark=1.5, cap=False)
            continue
        # a fork two thirds out, and a lesser one nearer the trunk
        for (at, turn, ln, r0) in ((3, 0.5 if k % 2 == 0 else -0.5, 2.6, 0.2), (2, -0.42 if k % 2 == 0 else 0.42, 1.9, 0.16)):
            p0 = ctl[at]
            d = (ctl[at + 1] - ctl[at]).normalized()
            d2 = Vector((d.x * math.cos(turn) + d.z * math.sin(turn), d.y + 0.35, -d.x * math.sin(turn) + d.z * math.cos(turn))).normalized()
            p1 = p0 + d2 * ln * 0.5 + Vector((0, 0.15, 0))
            p2 = p0 + d2 * ln + Vector((0, 0.5 * hash3(k, at, 1.0, 81), 0))
            lb.tube_path([p0 - d * 0.15, p1, p2], [r0, r0 * 0.6, 0.03], "bark", sides=6, bark=3.0, jit=0.02, seed=90 + k + at)
            limb_paths.append(([p0, p2], [r0, 0.03]))
        # dead spikes along the limb
        for s in range(6):
            t = 0.25 + 0.12 * s
            i0 = min(int(t * (len(ctl) - 1)), len(ctl) - 2)
            p = ctl[i0].lerp(ctl[i0 + 1], t * (len(ctl) - 1) - i0)
            dirv = Vector((hash3(s * 2.3, k, 1.0, 101), 0.5 + 0.5 * abs(hash3(s * 2.3, k, 2.0, 102)), hash3(s * 2.3, k, 3.0, 103))).normalized()
            lb.tube(p, p + dirv * (0.5 + 0.5 * abs(hash3(s, k, 7.0, 104))), 0.05, 0.008, "bark", sides=4, bark=1.5, cap=False)
    objs.append(lb.finish())

    # ------------------------------------------------------------------ the far silhouette
    fb = B("MotherFar", {"bark": bark})
    fb.lathe([(2.2, -0.8), (1.75, 0.6), (1.55, 2.6), (1.55, 5.2), (1.2, 6.4)], "bark", sides=8, bark=3.0)
    for (ctl, rad) in limb_paths:
        if len(ctl) < 3:
            continue
        fb.tube(ctl[1], ctl[len(ctl) // 2 + 1], rad[1] * 1.1, rad[len(ctl) // 2 + 1], "bark", sides=4, bark=3.0, cap=False)
        if len(ctl) > 4:
            fb.tube(ctl[len(ctl) // 2 + 1], ctl[-1], rad[len(ctl) // 2 + 1], 0.06, "bark", sides=4, bark=3.0, cap=False)
    for ra in ROOTS:
        fb.tube(pos(ra, 1.5, 0.8), pos(ra, 4.2, -0.5), 0.5, 0.15, "bark", sides=3, bark=3.0, cap=False)
    objs.append(fb.finish())

    # ------------------------------------------------------------------ collision
    cmat = {"bark": L.flat("ColMat", (1.0, 0.0, 1.0)), "heart": L.flat("ColMat2", (1.0, 0.0, 1.0))}
    cb = B("MotherCol", cmat)
    shell(cb.bm, cb.uv, 0, 1, 16, [-0.8, 0.6, 1.9, 3.1, 4.6], rim=False, jambs=True, smooth_f=False)
    objs.append(cb.finish(merge=False))

    path = os.path.join(L.MODEL_DIR, "orchard_mother_tree.glb")
    L.export(path, objs)
    vis = [o for o in objs if not o.name.endswith("Col") and not o.name.endswith("Far")]
    print("TRIS near", sum(L.tris(o) for o in vis), "far", L.tris(objs[3]), "col", L.tris(objs[4]))
    if PREVIEW:
        os.makedirs(PREVIEW, exist_ok=True)
        sc = bpy.context.scene
        w = bpy.data.worlds.new("W")
        w.color = (0.32, 0.34, 0.38)
        sc.world = w
        gm = bpy.data.meshes.new("Ground")
        gbm = bmesh.new()
        bmesh.ops.create_grid(gbm, x_segments=1, y_segments=1, size=30.0)
        gbm.to_mesh(gm)
        ground = bpy.data.objects.new("Ground", gm)
        gm.materials.append(L.flat("GroundMat", (0.2, 0.19, 0.17)))
        sc.collection.objects.link(ground)
        man = bpy.data.meshes.new("Man")                      # a 1.8 m figure for scale, in the way in
        mbm = bmesh.new()
        bmesh.ops.create_cone(mbm, segments=10, radius1=0.3, radius2=0.22, depth=1.8, cap_ends=True)
        mbm.to_mesh(man)
        fig = bpy.data.objects.new("Man", man)
        fig.location = (0.0, -2.6, 0.9)
        man.materials.append(L.flat("ManMat", (0.6, 0.3, 0.15)))
        sc.collection.objects.link(fig)
        for o in objs:
            o.hide_render = o not in vis
        sh = sc.display.shading
        sh.show_cavity = True
        sh.cavity_type = 'BOTH'
        sh.show_shadows = True
        for mode in ("clay", "tex"):
            sh.light = 'STUDIO'
            sh.color_type = 'SINGLE' if mode == "clay" else 'TEXTURE'
            sh.single_color = (0.62, 0.6, 0.57)
            for (nm, kw) in (("around", dict(look_at=(0, 3.6, 0), dist=19.0, views=((8, 0.16), (95, 0.2), (190, 0.14), (290, 0.3)), res=(1000, 760), lens=38)),
                             ("door", dict(look_at=(0, 1.7, 0), dist=7.5, views=((16, 0.08),), res=(900, 820), lens=28)),
                             ("inside", dict(look_at=(0, 3.4, -0.4), dist=1.0, views=((0, -1.15),), res=(820, 820), lens=16))):
                _preview(os.path.join(PREVIEW, "%s_%s.png" % (nm, mode)), mode, **kw)
    os.makedirs(L.BLEND_DIR, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(L.BLEND_DIR, "orchard_mother_tree.blend"))


build()
