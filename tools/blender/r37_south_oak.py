"""The Grandmother Oak (r37 South): a colossal hollow dead oak, ~40 m, trunk ~10 m across.

Authored in Godot coordinates (origin: the trunk's axis at ground level; the door faces -Z).
  Trunk    the bark shell, outer and inner faces, openings cut on a grid (the door, three limb doors,
           knotholes) with jambs between the faces; a ragged broken crown at ~38 m
  Roots    nine great roots running out into the ground, a gap left on the west for the lair
  Limbs    three great limbs with flat-topped walks (3.3 m wide at the trunk, 1.5 m at the tip), dead
           twigs and broken spikes; each is entered from the stair by a landing and a trunk door
  Stair    a timber helix inside the trunk (170 treads, 26 to a turn), a post-and-rope rail, brackets,
           landings at the limb doors, a crown deck at the top
  OakFar   the silhouette in ~300 triangles
  *Col     collision proxies (never drawn): TrunkCol, StairCol, RailCol, LimbCol, DeckCol
"""
import math
import random
import numpy as np_mod
import bpy
from mathutils import Vector, Matrix

import r37_south_lib as L
from r37_south_lib import B, hash3, G


def sm(x, a, b):
    t = min(max((x - a) / (b - a), 0.0), 1.0)
    return t * t * (3.0 - 2.0 * t)


# trunk grid
NC = 48                  # coarse columns (7.5 deg)
NF = 96                  # fine columns
Y0 = -2.8
DYC = 1.4
KC = 30                  # coarse rows -> y 37.8 on the last ring
DYF = 0.7


def r_out(y):
    if y < 0.0:
        return 6.2 + (-y) * 0.3
    if y < 5.0:
        return 6.2 - 1.0 * (y / 5.0)
    return 5.2 - 0.7 * ((y - 5.0) / 33.0)


def wall_t(y):
    return 1.25 + 0.15 * math.sin(y * 0.35)


def r_in(y):
    return r_out(max(y, 0.0)) - wall_t(y)


STAIR_N = 170
STAIR_TURN = 26
RISE = 0.21
STAIR_Y0 = 0.14
STAIR_W = 1.9
A0 = math.pi + 0.55             # the first tread, just inside the door (a=pi is -Z)
DA = math.tau / STAIR_TURN


def stair_y(s):
    return STAIR_Y0 + RISE * s


def stair_a(s):
    return A0 + DA * s


def sway(y):
    """The trunk leans and wanders: ring centres drift a little with height."""
    return Vector((1.3 * math.sin(y * 0.11 + 0.4) + 0.02 * y, 0, 1.1 * math.cos(y * 0.09 + 1.1)))


def pos(a, r, y):
    return Vector((r * math.sin(a), y, r * math.cos(a))) + sway(y)


def spline(pts, radii, per=8):
    """Catmull-Rom through `pts` with `per` samples a span, radii interpolated: a smooth root, no kinks."""
    pts = [Vector(p) for p in pts]
    out, rad = [], []
    n = len(pts)
    for i in range(n - 1):
        p0, p1, p2, p3 = pts[max(i - 1, 0)], pts[i], pts[i + 1], pts[min(i + 2, n - 1)]
        for k in range(per):
            t = k / per
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3))
            rad.append(radii[i] + (radii[i + 1] - radii[i]) * t)
    out.append(pts[-1])
    rad.append(radii[-1])
    return out, rad


def darken_inside(ob, tone=(0.5, 0.4, 0.31)):
    """Vertices inside the trunk's inner wall (a root, a limb's first reach, the door frame seen from the room):
    no moss, a dark warm tone, so no outer-bark zebra shows in the hollow."""
    me_ = ob.data
    ca_ = me_.color_attributes["Col"]
    nl_ = len(me_.loops)
    lv_ = np_mod.empty(nl_, dtype=np_mod.int32)
    me_.loops.foreach_get("vertex_index", lv_)
    rg_ = np_mod.empty(nl_ * 4, dtype=np_mod.float32)
    ca_.data.foreach_get("color", rg_)
    rg_ = rg_.reshape(-1, 4)
    co_ = np_mod.empty(len(me_.vertices) * 3, dtype=np_mod.float32)
    me_.vertices.foreach_get("co", co_)
    co_ = co_.reshape(-1, 3)
    tn_ = np_mod.array(tone, dtype=np_mod.float32)
    for v_i in range(len(me_.vertices)):
        x_, zg_, yg_ = co_[v_i][0], -co_[v_i][1], co_[v_i][2]
        if yg_ > 40.0:
            continue
        sw_ = sway(max(yg_, 0.0))
        if math.hypot(x_ - sw_.x, zg_ - sw_.z) < r_in(max(yg_, 0.0)) + 1.3:
            rg_[lv_ == v_i, :3] = tn_ * (0.75 + 0.25 * sm(yg_, 0.0, 6.0))
    ca_.data.foreach_set("color", rg_.ravel())


def build(DATA, PREVIEW, objs_out):
    bark = L.pbr("R37_OakBark", L.tex_bark(1024, 3801), 3.6)
    plank = L.pbr("R37_OakPlank", L.tex_planks(512, 3802), 2.4)
    dark = L.flat("R37_OakDark", (0.012, 0.01, 0.01), 1.0)
    rot = L.flat("R37_OakRot", (0.045, 0.03, 0.018), 1.0)
    leaf_mats = {"leafA": L.flat("R37_OakLeafA", (0.22, 0.12, 0.05), 1.0), "leafB": L.flat("R37_OakLeafB", (0.13, 0.08, 0.04), 1.0),
                 "leafC": L.flat("R37_OakLeafC", (0.2, 0.06, 0.035), 1.0), "leafD": L.flat("R37_OakLeafD", (0.16, 0.13, 0.05), 1.0)}
    heart = L.pbr("R37_OakHeart", L.tex_heartwood(512, 3811), 1.6)
    soil = L.pbr("R37_OakSoil", L.tex_soil(512, 3812), 2.4)
    iron = L.flat("R37_OakIron", (0.07, 0.065, 0.06), 0.55, 0.85)
    rope = L.flat("R37_OakRope", (0.19, 0.15, 0.1), 0.95)
    bark.use_backface_culling = False           # the jambs of the openings are single faces
    heart.use_backface_culling = False
    mats = {"bark": bark, "plank": plank, "dark": dark, "iron": iron, "rope": rope, "rot": rot, "heart": heart, "soil": soil}
    objs = []

    # ------------------------------------------------------------------ the stair's landings
    # the limb doors: azimuth wanted, height wanted; the stair is fitted to pass each at that azimuth
    limb_want = [(1.3, 13.4), (3.55, 21.8), (5.55, 29.6)]
    limbs = []
    for (aw, hw) in limb_want:
        best = None
        for s in range(8, STAIR_N - 10):
            da = (stair_a(s) - aw + math.pi) % math.tau - math.pi
            if abs(da) < DA * 0.6:
                d = abs(stair_y(s) - hw)
                if best is None or d < best[0]:
                    best = (d, s)
        s = best[1]
        limbs.append({"s": s, "a": stair_a(s), "y": stair_y(s)})
    # coarse door cells: columns [c0, c0+5), rows [k0, k0+3) -> opening in the trunk
    doors = []
    ent_c0 = NC // 2 - 2           # 22..26 centred a little past -Z
    doors.append({"c0": ent_c0, "k0": 2, "w": 5, "h": 3, "kind": "door"})
    for lm in limbs:
        a = lm["a"] % math.tau
        c_mid = a / math.tau * NC
        c0 = int(round(c_mid - 2.5))
        k0 = int(math.floor((lm["y"] - 0.2 - Y0) / DYC))
        lm["c0"] = c0
        lm["k0"] = k0
        lm["a_door"] = (c0 + 2.5) / NC * math.tau
        doors.append({"c0": c0, "k0": k0, "w": 5, "h": 3, "kind": "limb"})
    # knotholes: little windows lighting the hollow
    for (c0, k0, w, h) in ((8, 8, 1, 1), (14, 16, 1, 2), (33, 12, 2, 1), (38, 22, 1, 2), (3, 25, 1, 1), (29, 27, 1, 1), (44, 17, 1, 1), (18, 24, 1, 1)):
        doors.append({"c0": c0, "k0": k0, "w": w, "h": h, "kind": "hole"})

    def open_coarse(kc, jc):
        jc %= NC
        for d in doors:
            if d["k0"] <= kc < d["k0"] + d["h"]:
                rel = (jc - d["c0"]) % NC
                if rel < d["w"]:
                    # trim the top corners of the big doors into arches
                    if d["kind"] != "hole" and kc == d["k0"] + d["h"] - 1 and (rel == 0 or rel == d["w"] - 1):
                        continue
                    return True
        return False

    ENT_J0 = ent_c0 * 2                 # the entrance's fine columns ENT_J0 .. +9, fine rows 4 .. 9 (y 0 .. 4.2)

    def in_ent(i, j):
        return ENT_J0 <= j % NF < ENT_J0 + 10 and floor_i <= i < floor_i + 6

    def open_fine(i, j):
        j %= NF
        ci, cj = i // 2, j // 2
        if 2 <= ci < 5 and ent_c0 <= cj < ent_c0 + 5:
            return ENT_J0 <= j < ENT_J0 + 10
        return open_coarse(ci, cj)

    HEART_I = list(mats.keys()).index("heart")
    SOIL_I = list(mats.keys()).index("soil")
    NI = (KC - 1) * 2 + 1            # fine rings 0..NI-1  (NI = 59)
    ys = [Y0 + DYF * i for i in range(NI)]
    floor_i = int(round((0.0 - Y0) / DYF))       # y = 0

    def jag(a):
        return 3.8 * (hash3(math.sin(a) * 2.4, 5.0, math.cos(a) * 2.4, 3) * 1.6) + 1.6 * hash3(math.sin(a * 3) * 3.0, 9.0, math.cos(a * 3) * 3.0, 4) + 1.4 * math.sin(a * 5 + 1.0) + 4.6 * max(0.0, math.cos(a - 2.3)) ** 3 + 4.0 * max(0.0, math.cos(a - 5.4)) ** 7

    # root flare azimuths and the lair gap
    root_az = [0.25 + k * math.tau / 9.0 for k in range(9)]
    LAIR_A = 4.35         # west-south-west: the gap between two roots where the Root-Wife keeps her bed
    root_az = [a for a in root_az if abs(((a - LAIR_A + math.pi) % math.tau) - math.pi) > 0.55]
    DOOR_A = (ent_c0 + 2.5) / NC * math.tau
    root_az = [a for a in root_az if abs(((a - DOOR_A + math.pi) % math.tau) - math.pi) > 0.75]    # no buttress in the doorway

    def bulge(a, y):
        # the buttress swell of the root flare (to ~y 6)
        k = 0.0
        for ra in root_az:
            d = ((a - ra + math.pi) % math.tau) - math.pi
            k = max(k, math.exp(-(d / 0.17) ** 2))
        return 1.0 + 0.62 * k * (1.0 - sm(y, 0.0, 10.0)) ** 1.3

    burls = [(0.9, 6.5, 0.34, 1.7), (2.4, 12.5, 0.3, 1.3), (4.0, 17.0, 0.4, 2.0), (5.3, 9.0, 0.28, 1.2), (1.9, 25.0, 0.34, 1.8), (3.3, 29.5, 0.3, 1.4), (0.3, 20.5, 0.32, 1.5), (3.0, 4.0, 0.3, 1.6), (5.8, 24.0, 0.3, 1.6)]

    def surf(a, y, inner):
        base = r_in(y) if inner else r_out(y)
        base *= 1.0 + 0.045 * math.sin(y * 0.21 + a * 2.0)
        if not inner:
            for (ba, by, bk, bs) in burls:
                d = ((a - ba + math.pi) % math.tau) - math.pi
                base *= 1.0 + bk * math.exp(-((d * 5.0 / bs) ** 2) - (((y - by) / (bs * 1.4)) ** 2))
        ridge = 0.085 * math.sin(a * 11.0 + y * 0.045 + 2.4 * hash3(math.sin(a) * 1.7, y * 0.15, math.cos(a) * 1.7, 11)) + 0.045 * math.sin(a * 23.0 - y * 0.08) + 0.07 * hash3(math.sin(a) * 2.2, y * 0.3, math.cos(a) * 2.2, 12)
        if inner:
            pocket = max(0.0, math.sin(a * 3.0 + y * 0.23 + 1.0) * math.sin(a * 2.0 - y * 0.15 + 0.6)) ** 2 * 0.07
            pocket += 0.06 * max(0.0, hash3(math.sin(a * 2.0) * 2.1, y * 0.35, math.cos(a * 2.0) * 2.1, 31) - 0.35)
            for (ka, ky, kr) in ((0.2, 3.0, 1.0), (2.1, 6.5, 1.3), (4.4, 2.2, 0.9), (5.6, 9.0, 1.2), (3.3, 12.0, 1.4)):
                d = ((a - ka + math.pi) % math.tau) - math.pi
                pocket += 0.075 * math.exp(-((d * 4.0 / kr) ** 2) - (((y - ky) / (kr * 1.6)) ** 2))
            return base * (1.0 + pocket + ridge * 0.8)
        return base * bulge(a, y) * (1.0 + ridge)

    def ring_y(i, a):
        y = ys[i]
        if i >= NI - 4:
            y += sum(jag(a + d * 0.045) for d in range(-4, 5)) / 9.0 * sm(i, NI - 5, NI - 1)
        return y

    outer = []
    inner = []
    for i in range(NI):
        ro = []
        ri = []
        for j in range(NF):
            a = math.tau * j / NF
            y = ring_y(i, a)
            r = surf(a, ys[i], False)
            ro.append(pos(a, r, y))
            if i >= floor_i:
                rr = surf(a, ys[i], True)
                ri.append(pos(a, rr, y))
            else:
                ri.append(None)
        outer.append(ro)
        inner.append(ri)

    b = B("Trunk", mats)
    tiles = round(math.tau * 6.2 / 3.0)
    tiles_in = round(math.tau * 5.0 / 1.5)
    v_in = 1.5
    vs_ = [ys[i] / 3.0 for i in range(NI)]

    def uvq(f, j, i):
        u0 = tiles * j / NF
        u1 = tiles * (j + 1) / NF
        j2_ = (j + 1) % NF
        f.loops[0][b.uv].uv = (u0, outer[i][j].y / 3.0)
        f.loops[1][b.uv].uv = (u1, outer[i][j2_].y / 3.0)
        f.loops[2][b.uv].uv = (u1, outer[i + 1][j2_].y / 3.0)
        f.loops[3][b.uv].uv = (u0, outer[i + 1][j].y / 3.0)

    bm = b.bm
    vo = [[bm.verts.new(p) for p in ring] for ring in outer]
    vi = [[(bm.verts.new(p) if p is not None else None) for p in ring] for ring in inner]
    for i in range(NI - 1):
        for j in range(NF):
            j2 = (j + 1) % NF
            if open_fine(i, j):
                continue
            f = bm.faces.new([vo[i][j], vo[i][j2], vo[i + 1][j2], vo[i + 1][j]])
            f.material_index = 0
            f.smooth = True
            uvq(f, j, i)
            if i >= floor_i:
                # the inner face looks inward: reversed winding
                g = bm.faces.new([vi[i][j2], vi[i][j], vi[i + 1][j], vi[i + 1][j2]])
                g.material_index = HEART_I
                g.smooth = True
                j2_ = (j + 1) % NF
                g.loops[0][b.uv].uv = (tiles_in * (j + 1) / NF, inner[i][j2_].y / v_in)
                g.loops[1][b.uv].uv = (tiles_in * j / NF, inner[i][j].y / v_in)
                g.loops[2][b.uv].uv = (tiles_in * j / NF, inner[i + 1][j].y / v_in)
                g.loops[3][b.uv].uv = (tiles_in * (j + 1) / NF, inner[i + 1][j2_].y / v_in)
    # jambs: between the outer and inner faces where an open cell meets a closed one
    def jamb(p0o, p1o, p1i, p0i, rev):
        pts = [p0o, p1o, p1i, p0i]
        if rev:
            pts = list(reversed(pts))
        try:
            f = bm.faces.new(pts)
        except ValueError:
            return
        f.material_index = HEART_I
        f.smooth = False
        e_ = p1o.co - p0o.co
        vertical_ = abs(e_.y) > 0.6 * e_.length
        for l in f.loops:
            c = l.vert.co
            sw_ = sway(c.y)
            rad_ = math.hypot(c.x - sw_.x, c.z - sw_.z)
            ang_ = math.atan2(c.x - sw_.x, c.z - sw_.z) % math.tau
            l[b.uv].uv = (rad_ / 1.5, c.y / 1.5) if vertical_ else (tiles_in * ang_ / math.tau, rad_ / 1.5)

    for i in range(floor_i, NI - 1):
        for j in range(NF):
            if not open_fine(i, j):
                continue
            j2 = (j + 1) % NF
            jm = (j - 1) % NF
            # left neighbour closed: jamb along column j
            ent = in_ent(i, j)
            if not ent and not open_fine(i, jm):
                jamb(vo[i][j], vo[i + 1][j], vi[i + 1][j], vi[i][j], False)
            if not ent and not open_fine(i, j2):
                jamb(vo[i][j2], vo[i + 1][j2], vi[i + 1][j2], vi[i][j2], True)
            if i > floor_i and not open_fine(i - 1, j):
                jamb(vo[i][j], vo[i][j2], vi[i][j2], vi[i][j], True)
            if not ent and i + 1 < NI - 1 and not open_fine(i + 1, j):
                jamb(vo[i + 1][j], vo[i + 1][j2], vi[i + 1][j2], vi[i + 1][j], False)
            if i == floor_i:
                jamb(vo[i][j], vo[i][j2], vi[i][j2], vi[i][j], True)
    # the doorway, cut by a curve and not by the grid: filler panels from the open block's edge to a smooth ragged
    # arch on the outer and the inner face, and a rounded lip of bark wrapping from one face to the other
    def nz(t, k):
        return 0.5 * math.sin(3.0 * t + 1.3 + k) + 0.5 * math.sin(5.1 * t + 0.4 + 2.0 * k)

    a_l = math.tau * ENT_J0 / NF
    a_r = math.tau * (ENT_J0 + 10) / NF
    NA = 44
    SPRING = 1.4                       # the jambs stand straight to here; above it the crown is a half ellipse
    CROWN = 1.95                       # its rise (the doorway is 3.35 m to the crown's top)
    arch_t = []
    arch_p = []
    NSIDE = 7
    NCROWN = NA - 2 * NSIDE
    for k in range(NA + 1):
        if k <= NSIDE:                                  # left jamb, bottom to the springing
            f_ = k / NSIDE
            u, yy = -1.0 + 0.02 * nz(f_ * 3.0, 4), SPRING * f_ * (1.0 + 0.03 * nz(f_ * 5.0, 6))
            th = -math.pi / 2
        elif k >= NA - NSIDE:                           # right jamb, the springing to the bottom
            f_ = (NA - k) / NSIDE
            u, yy = 1.0 - 0.02 * nz(f_ * 3.0, 5), SPRING * f_ * (1.0 + 0.03 * nz(f_ * 5.0, 7))
            th = math.pi / 2
        else:                                           # the crown
            th = -math.pi / 2 + math.pi * (k - NSIDE) / NCROWN
            u = math.sin(th) * (1.0 + 0.02 * nz(th, 0) * math.cos(th)) + 0.03 * math.cos(th)         # a little lopsided
            yy = SPRING + CROWN * math.cos(th) * (1.0 + 0.025 * nz(th, 1)) + 0.02 * nz(th, 2)
        arch_t.append(th)
        arch_p.append((a_l + (a_r - a_l) * (1.0 + u) / 2.0, max(yy, 0.0)))
    arch_t = [min(max(t, -math.pi / 2 + 0.0), math.pi / 2) for t in arch_t]

    def perimeter(ring):
        loop = []
        for i in range(floor_i, floor_i + 7):
            loop.append(ring[i][ENT_J0])
        for j in range(ENT_J0 + 1, ENT_J0 + 11):
            loop.append(ring[floor_i + 6][j])
        for i in range(floor_i + 5, floor_i - 1, -1):
            loop.append(ring[i][ENT_J0 + 10])
        return loop

    def facing(face, toward, c_ref=None):
        face.normal_update()
        n = face.normal
        cen = face.calc_center_median()
        sgn = 1.0
        if c_ref is not None:
            sgn = 1.0 if (n.dot(c_ref - cen) > 0) else -1.0
        else:
            rad = Vector((cen.x - sway(cen.y).x, 0.0, cen.z - sway(cen.y).z))
            sgn = 1.0 if (n.dot(rad) > 0) == toward else -1.0
        if sgn < 0:
            face.normal_flip()

    def new_tri(v0, v1, v2, toward, c_ref=None):
        try:
            f = bm.faces.new([v0, v1, v2])
        except ValueError:
            return
        f.material_index = 0 if toward else HEART_I
        f.smooth = True
        facing(f, toward, c_ref)
        for l in f.loops:
            c = l.vert.co
            ang = math.atan2(c.x - sway(c.y).x, c.z - sway(c.y).z) % math.tau
            l[b.uv].uv = ((tiles if toward else tiles_in) * ang / math.tau, c.y / (3.0 if toward else v_in))

    def strip(P, A, toward):
        def cum(pts):
            out = [0.0]
            for k in range(1, len(pts)):
                out.append(out[-1] + (pts[k].co - pts[k - 1].co).length)
            return [x / out[-1] for x in out]
        cp, ca = cum(P), cum(A)
        i = j = 0
        while i < len(P) - 1 or j < len(A) - 1:
            adv_p = j >= len(A) - 1 or (i < len(P) - 1 and cp[i + 1] <= ca[j + 1])
            if adv_p:
                new_tri(P[i], P[i + 1], A[j], toward)
                i += 1
            else:
                new_tri(P[i], A[j + 1], A[j], toward)
                j += 1

    P_o = perimeter(vo)
    P_i = perimeter(vi)
    A_o = []
    A_i = []
    ad_mid = (a_l + a_r) / 2.0
    for k, (aa, yy) in enumerate(arch_p):
        if k == 0:
            A_o.append(vo[floor_i][ENT_J0])
            A_i.append(vi[floor_i][ENT_J0])
        elif k == NA:
            A_o.append(vo[floor_i][ENT_J0 + 10])
            A_i.append(vi[floor_i][ENT_J0 + 10])
        else:
            A_o.append(bm.verts.new(pos(aa, surf(aa, yy, False), yy)))
            yi_ = yy * r_in(0.0) / r_out(0.0)
            A_i.append(bm.verts.new(pos(aa, surf(aa, yi_, True), yi_)))
    strip(P_o, A_o, True)
    strip(P_i, A_i, False)
    arc_u = [0.0]
    for k in range(1, NA + 1):
        arc_u.append(arc_u[-1] + (A_o[k].co - A_o[k - 1].co).length)
    for curve in (A_o, A_i):
        for _ in range(4):
            cs = [v.co.copy() for v in curve]
            for k in range(2, NA - 1):
                curve[k].co = (cs[k - 1] + cs[k] * 2.0 + cs[k + 1]) / 4.0
    hole_c = pos(ad_mid, (r_out(1.8) + r_in(1.8)) * 0.5, 1.8)
    ring_prev = A_o
    LIP = 8
    lip_faces = []
    for kk in range(1, LIP + 1):
        f_ = kk / LIP
        ring = []
        for k in range(NA + 1):
            if kk == LIP:
                ring.append(A_i[k])
                continue
            if k == 0 or k == NA:
                ring.append(A_o[k].co.lerp(A_i[k].co, f_) and bm.verts.new(A_o[k].co.lerp(A_i[k].co, f_)))
                continue
            po_, pi_ = A_o[k].co, A_i[k].co
            q = po_.lerp(pi_, f_)
            rad = Vector((q.x - sway(q.y).x, 0.0, q.z - sway(q.y).z))
            rad = rad.normalized() if rad.length > 1e-6 else Vector((0, 0, 1))
            d = hole_c - q
            d = d - rad * d.dot(rad)
            d = d.normalized() if d.length > 1e-6 else Vector((0, 1, 0))
            t_ = arch_t[k]
            amp = (0.2 + 0.03 * nz(k * 0.2, 3)) * (0.55 + 0.45 * math.cos(t_)) * min(1.0, k / 3.0, (NA - k) / 3.0)
            q = q + d * amp * math.sin(math.pi * f_) ** 0.85
            ring.append(bm.verts.new(q))
        for k in range(NA):
            try:
                f = bm.faces.new([ring_prev[k], ring_prev[k + 1], ring[k + 1], ring[k]])
            except ValueError:
                continue
            f.material_index = 0
            f.smooth = True
            lip_faces.append(f)
            for l, (kk_, ff_) in zip(f.loops, ((k, f_ - 1.0 / LIP), (k + 1, f_ - 1.0 / LIP), (k + 1, f_), (k, f_))):
                l[b.uv].uv = (arc_u[kk_] / 3.0, ff_ * 1.3 / 3.0 + 0.5)
        ring_prev = ring
    mid_f = lip_faces[len(lip_faces) // 2]
    mid_f.normal_update()
    flip_lip = mid_f.normal.dot(hole_c - mid_f.calc_center_median()) < 0
    for f in lip_faces:
        f.normal_update()
        if flip_lip:
            f.normal_flip()
    # the broken rim: outer top ring to inner top ring
    for j in range(NF):
        j2 = (j + 1) % NF
        f = bm.faces.new([vo[NI - 1][j], vo[NI - 1][j2], vi[NI - 1][j2], vi[NI - 1][j]])
        f.material_index = 0
        f.smooth = False
        f.loops[0][b.uv].uv = (j * 0.4, 0)
        f.loops[1][b.uv].uv = ((j + 1) * 0.4, 0)
        f.loops[2][b.uv].uv = ((j + 1) * 0.4, 1.2)
        f.loops[3][b.uv].uv = (j * 0.4, 1.2)
    # the floor: a dark mould of old leaf and rot, dished and humped, rising to the wall at y 0
    dark_i = SOIL_I
    c0 = sway(0.0)
    prev = [vi[floor_i][j] for j in range(NF)]
    for (fr, dep) in ((0.72, 0.1), (0.45, 0.2), (0.18, 0.12)):
        cur = []
        for j in range(NF):
            q = inner[floor_i][j]
            pq = c0 + Vector((q.x - c0.x, 0.0, q.z - c0.z)) * fr
            pq.y = -dep - 0.1 * hash3(pq.x * 0.9, 1.0, pq.z * 0.9, 51) + 0.07 * math.sin(pq.x * 1.3 + pq.z * 0.9)
            cur.append(bm.verts.new(pq))
        for j in range(NF):
            j2 = (j + 1) % NF
            try:
                f = bm.faces.new([prev[j], prev[j2], cur[j2], cur[j]])
                f.material_index = dark_i
                f.smooth = True
                for l in f.loops:
                    l[b.uv].uv = (l.vert.co.x / 1.0, l.vert.co.z / 1.0)
            except ValueError:
                pass
        prev = cur
    try:
        f = bm.faces.new(list(reversed(prev)))
        f.material_index = dark_i
        for l in f.loops:
            l[b.uv].uv = (l.vert.co.x / 1.0, l.vert.co.z / 1.0)
    except ValueError:
        pass
    # the root flare's skirt below ground: closed so no light shows through the terrain's seams
    trunk = b.finish()
    L.moss_colors(trunk, 3)
    import numpy as np_
    me_ = trunk.data
    ca_ = me_.color_attributes["Col"]
    nl_ = len(me_.loops)
    lv_ = np_.empty(nl_, dtype=np_.int32)
    me_.loops.foreach_get("vertex_index", lv_)
    rgba_ = np_.empty(nl_ * 4, dtype=np_.float32)
    ca_.data.foreach_get("color", rgba_)
    rgba_ = rgba_.reshape(-1, 4)
    co_ = np_.empty(len(me_.vertices) * 3, dtype=np_.float32)
    me_.vertices.foreach_get("co", co_)
    co_ = co_.reshape(-1, 3)
    for v_i in range(len(me_.vertices)):
        x_, zg_, yg_ = co_[v_i][0], -co_[v_i][1], co_[v_i][2]
        if yg_ < -0.5:
            continue
        sw_ = sway(yg_)
        rad_ = math.hypot(x_ - sw_.x, zg_ - sw_.z)
        mid_ = (r_in(yg_) + r_out(yg_)) * 0.5
        if rad_ < mid_ and yg_ < 38.0:
            f_ = 1.0 - 0.4 * sm(yg_, 3.0, 26.0)
            f_ *= 0.75 + 0.25 * sm(yg_, 0.0, 1.0)       # darkest in the rotted bottom corner, then lighter, then falling off
            rot_ = 1.0 - sm(yg_, 0.5, 7.0)
            if yg_ < 0.05:
                f_ *= 0.9
            tint_ = np_.array([1.0 - 0.05 * rot_, 1.0 - 0.1 * rot_, 1.0 - 0.15 * rot_], dtype=np_.float32)
            rgba_[lv_ == v_i, :3] *= f_ * tint_
    ca_.data.foreach_set("color", rgba_.ravel())
    objs.append(trunk)

    # ------------------------------------------------------------------ the litter on the hollow's floor
    lb_ = B("Litter", {"rot": rot, "heart": heart, **leaf_mats})
    lr = random.Random(5150)
    c0_ = sway(0.0)
    for k in range(520):
        ang_ = lr.uniform(0.0, math.tau)
        rr_ = math.sqrt(lr.uniform(0.0, 1.0)) * (r_in(0.0) - 0.35)
        px_ = c0_.x + math.sin(ang_) * rr_
        pz_ = c0_.z + math.cos(ang_) * rr_
        yw_ = lr.uniform(0.0, math.tau)
        ln_ = lr.uniform(0.045, 0.075)                     # half length: a leaf 9 to 15 cm long
        base_y = -0.04 - 0.12 * (1.0 - min(rr_ / 3.5, 1.0)) + 0.03 * math.sin(px_ * 1.3 + pz_ * 0.9) + lr.uniform(0.0, 0.03)
        tilt_x, tilt_z = lr.uniform(-0.25, 0.25), lr.uniform(-0.25, 0.25)
        lobes = lr.choice((5, 6, 7))
        curl_ = lr.uniform(-0.6, 0.9) * 0.04
        poly = []
        for m_ in range(16):
            tt = m_ / 16.0 * math.tau
            lx = math.cos(tt) * ln_
            lz = math.sin(tt) * ln_ * 0.55 * (1.0 + 0.22 * math.sin(tt * lobes * 0.5 + 1.0))       # the lobed oak leaf
            poly.append((lx, lz))
        pts_ = []
        for (qx, qz) in poly:
            wx = qx * math.cos(yw_) - qz * math.sin(yw_)
            wz = qx * math.sin(yw_) + qz * math.cos(yw_)
            pts_.append((px_ + wx, base_y + 0.02 + tilt_x * qx + tilt_z * qz + curl_ * (qz * qz + 0.3 * qx * qx) * 12.0, pz_ + wz))
        lb_.face(pts_, lr.choice(("leafA", "leafA", "leafB", "leafC", "leafD")))
    for k in range(90):
        ang_ = lr.uniform(0.0, math.tau)
        rr_ = math.sqrt(lr.uniform(0.0, 1.0)) * (r_in(0.0) - 0.4)
        px_ = c0_.x + math.sin(ang_) * rr_
        pz_ = c0_.z + math.cos(ang_) * rr_
        d_ = lr.uniform(0.0, math.tau)
        L_ = lr.uniform(0.08, 0.28)
        y_ = -0.06 - 0.1 * (1.0 - min(rr_ / 3.5, 1.0)) + 0.025
        lb_.tube(Vector((px_, y_, pz_)), Vector((px_ + math.sin(d_) * L_, y_ + lr.uniform(0.0, 0.05), pz_ + math.cos(d_) * L_)), 0.012, 0.007, "rot", sides=4, jit=0.0, seed=k)
    # a few roots crossing the floor: smooth, gently undulating, half sunk, tapering into the soil
    for k in range(7):
        ang_ = lr.uniform(0.0, math.tau)
        bend_ = lr.uniform(-0.09, 0.09)
        r0_ = r_in(0.0) - 0.1
        path_ = []
        for j in range(6):
            rr_ = r0_ - j * lr.uniform(0.6, 0.75)
            aj_ = ang_ + bend_ * j + 0.03 * math.sin(j * 1.3 + k)
            path_.append(Vector((c0_.x + math.sin(aj_) * rr_, -0.03 + 0.06 * math.sin(j * 1.1 + k) - 0.03 * j, c0_.z + math.cos(aj_) * rr_)))
        sp_, sr_ = spline(path_, [0.2 - 0.03 * j for j in range(6)])
        lb_.tube_path(sp_, sr_, "heart", sides=8, jit=0.02, seed=k)
    lit_ob = lb_.finish()
    L.moss_colors(lit_ob, 2, 0.0)
    ca3 = lit_ob.data.color_attributes["Col"]
    n3 = len(lit_ob.data.loops)
    c3 = np_mod.ones(n3 * 4, dtype=np_mod.float32).reshape(-1, 4)
    lv3 = np_mod.empty(n3, dtype=np_mod.int32)
    lit_ob.data.loops.foreach_get("vertex_index", lv3)
    rs3 = np_mod.random.RandomState(9)
    pal = np_mod.array([[0.5, 0.26, 0.12], [0.42, 0.2, 0.09], [0.36, 0.25, 0.1], [0.24, 0.14, 0.08], [0.4, 0.11, 0.07], [0.3, 0.17, 0.1]], dtype=np_mod.float32)
    pick = rs3.randint(0, len(pal), len(lit_ob.data.polygons))
    for pi_, poly_ in enumerate(lit_ob.data.polygons):
        for li_ in poly_.loop_indices:
            if poly_.material_index == 1:
                c3[li_, :3] = np_mod.array([0.85, 0.72, 0.6], dtype=np_mod.float32)         # a root: heartwood grain, dark
            else:
                c3[li_, :3] = pal[pick[pi_]] * rs3.uniform(0.6, 1.15) * 0.35
    ca3.data.foreach_set("color", c3.ravel())
    objs.append(lit_ob)

    # ------------------------------------------------------------------ roots
    rb = B("Roots", mats)
    rr = random.Random(77)
    for k, ra in enumerate(root_az + [x + 0.31 for x in root_az[::2]]):
        outer_pt = k >= len(root_az)
        pts = []
        # radial distance, height, sideways wander
        prof = [(7.0, 2.9, 1.9), (8.0, 1.8, 1.8), (9.0, 1.0, 1.6), (12.0, 0.35, 1.2), (15.0, -0.2, 0.9), (18.5, -0.8, 0.6)]
        if outer_pt:
            prof = [(6.7, 1.2, 1.0), (8.0, 0.55, 0.8), (11.5, 0.1, 0.55), (15.5, -0.5, 0.3)]
        wander = rr.uniform(-0.5, 0.5)
        sc = rr.uniform(0.85, 1.2)
        rings = []
        for i, (rad, hy, rw) in enumerate(prof):
            aa = ra + wander * (i / len(prof)) * 0.5
            c = pos(aa, rad * sc if i > 0 else rad, hy)
            rings.append((c, rw * sc))
        rb.tube_path([c for c, _ in rings], [w for _, w in rings], "bark", sides=9, jit=0.14, seed=k * 7)
    # the door's frame: two roots swell up either side and arch over the opening
    ad = (ent_c0 + 2.5) / NC * math.tau
    fp = [(-0.42, -0.5, 0.95, 0.7), (-0.42, 1.2, 0.5, 0.58), (-0.39, 3.0, 0.4, 0.5), (-0.27, 4.4, 0.42, 0.46), (-0.1, 5.2, 0.5, 0.42),
          (0.1, 5.3, 0.5, 0.42), (0.27, 4.4, 0.42, 0.46), (0.39, 3.0, 0.4, 0.5), (0.42, 1.2, 0.5, 0.58), (0.42, -0.5, 0.95, 0.7)]
    rb.tube_path([pos(ad + da, surf(ad + da, max(y, 0.0), False) + off, y) for (da, y, off, _) in fp], [w for (_, _, _, w) in fp], "bark", sides=9, jit=0.1, seed=3, cap_end=False)
    # tendrils: roots curling in over the sill beside the jambs and down into the rotted floor
    for k, (da, sgn) in enumerate(((-0.36, 1.0), (0.34, -1.0))):
        a0 = ad + da
        r0 = surf(a0, 0.3, False)
        path = [pos(a0, r0 + 0.6, 0.05), pos(a0, r0 - 0.3, 0.2), pos(a0 + sgn * 0.06, r0 - 1.3, 0.1), pos(a0 + sgn * 0.14, r0 - 2.3, -0.15), pos(a0 + sgn * 0.2, r0 - 3.0, -0.5)]
        sp_, sr_ = spline(path, [0.36, 0.3, 0.2, 0.11, 0.045])
        rb.tube_path(sp_, sr_, "bark", sides=8, jit=0.03, seed=90 + k)
    robj = rb.finish()
    L.moss_colors(robj, 11)
    darken_inside(robj)
    objs.append(robj)

    # ------------------------------------------------------------------ limbs
    lb = B("Limbs", mats)
    limb_col = []         # [(walk top point, flat walk width)] per limb, for the collision proxy
    limb_tips = []
    # per limb: length past the door, walk fraction, lateral sweep (amp, freq, phase), rise (up, droop), twist at the end
    SPEC = [
        {"L": 21.0, "tw": 0.70, "lat": (4.2, 1.25, 0.4), "up": (3.4, 0.85), "drop": 3.6, "twist": 1.5},
        {"L": 24.0, "tw": 0.66, "lat": (-5.0, 1.15, 2.0), "up": (4.2, 0.8), "drop": 2.6, "twist": -1.9},
        {"L": 17.0, "tw": 0.72, "lat": (3.4, 1.4, 4.1), "up": (2.0, 0.6), "drop": 0.6, "twist": 2.2},
    ]
    N_RING = 40
    SIDES = 18
    twig_r = random.Random(9)

    def grow(start, dirv, length, r0, depth, seed, grav=0.18, lift=0.25):
        """A dead branch: a curving, tapering tube that forks into smaller ones. No straight cylinders: the path
        wanders, rises and droops, and the radius wobbles."""
        rg = random.Random(seed)
        pts = [Vector(start)]
        rad = [r0]
        d = Vector(dirv).normalized()
        n = 5 if length > 5.0 else 3
        seg = length / (n - 1)
        for k in range(1, n):
            s_ = k / (n - 1)
            d = (d + Vector((rg.uniform(-0.38, 0.38), rg.uniform(-0.25, 0.3), rg.uniform(-0.38, 0.38)))).normalized()
            d = (d + Vector((0, lift * math.sin(math.pi * min(1.0, s_ * 1.3)) - grav * s_ * s_ * 2.0, 0)) * 0.55).normalized()
            pts.append(pts[-1] + d * seg)
            rad.append(max(r0 * (1.0 - 0.9 * s_ ** 0.85) * (1.0 + 0.12 * math.sin(k * 2.1 + seed)), 0.03))
        sides = 8 if r0 > 0.7 else (6 if r0 > 0.25 else 4)
        lb.tube_path(pts, rad, "bark", sides=sides, jit=0.06 + 0.05 * min(r0, 1.0), seed=seed)
        if depth <= 0 or length < 2.2:
            return pts
        nk = 3 if depth >= 2 else 2
        for q in range(nk):
            s_ = rg.uniform(0.3, 0.8) if q else rg.uniform(0.28, 0.45)
            i0 = min(int(s_ * (n - 1)), n - 2)
            f = s_ * (n - 1) - i0
            at = pts[i0].lerp(pts[i0 + 1], f)
            tang = (pts[i0 + 1] - pts[i0]).normalized()
            rr0 = rad[i0] * (1.0 - f) + rad[i0 + 1] * f
            ax = tang.cross(Vector((rg.uniform(-1, 1), rg.uniform(0.2, 1.0), rg.uniform(-1, 1)))).normalized()
            ang = rg.uniform(0.45, 0.95) * (1 if (q % 2 == 0) else -1)
            cd = (tang * math.cos(ang) + ax * math.sin(ang) + Vector((0, 0.35, 0))).normalized()
            grow(at - cd * rr0 * 0.5, cd, length * rg.uniform(0.42, 0.66), max(rr0 * 0.66, 0.05), depth - 1, seed * 3 + q + 1, grav, lift)
        return pts

    for li, lm in enumerate(limbs):
        sp = SPEC[li]
        a = lm["a_door"]
        dirv = Vector((math.sin(a), 0, math.cos(a)))
        side = Vector((dirv.z, 0, -dirv.x))
        sill = lm["y"]                                   # the walk's top at the door
        d0 = r_in(sill) + 0.25
        Lm = sp["L"]
        tw_ = sp["tw"]
        la, lf, lph = sp["lat"]
        ru, rf = sp["up"]
        rout = r_out(sill)

        def top_at(t):
            d = d0 + Lm * t
            lat = la * (math.sin(t * math.pi * lf + lph) - math.sin(lph)) * sm(t, 0.0, 0.25)
            rise = ru * math.sin(math.pi * t * rf) - sp["drop"] * t ** 3
            return Vector((0, sill + rise, 0)) + dirv * d + side * lat + sway(sill)

        tops = []
        rings = []
        prof = []
        for k in range(N_RING + 1):
            t = k / N_RING
            top = top_at(t)
            tn = top_at(min(t + 0.01, 1.0)) - top_at(max(t - 0.01, 0.0))
            tang = tn.normalized()
            flat = Vector((tang.x, 0, tang.z)).normalized()
            sd = Vector((flat.z, 0, -flat.x))
            d = d0 + Lm * t
            F = sm(d, rout - 0.5, rout + 0.7) * math.exp(-(((d - rout - 0.6) / 3.0) ** 2))      # the buttress where it leaves the trunk
            taper = 1.0 - 0.62 * sm(t, 0.0, 0.92)
            w = (3.2 * taper + 2.6 * F) * (1.0 - 0.8 * sm(t, 0.94, 1.0))
            rv = (2.0 * taper + 2.0 * F) * (1.0 - 0.85 * sm(t, 0.9, 1.0))
            rv = max(rv, 0.08)
            release = sm(t, tw_, 1.0)
            clamp = 0.72 + 0.28 * release
            phi = sp["twist"] * release
            ring = []
            for q in range(SIDES):
                bb = math.tau * q / SIDES
                horiz = math.cos(bb) * w / 2.0
                vert = min(math.sin(bb) * rv, clamp * rv)
                if math.sin(bb) < 0:
                    bump = 1.0 + 0.1 * math.sin(5.0 * bb + t * 11.0 + li * 2.0) * sm(t, 0.05, 0.3) + 0.06 * math.sin(3.0 * bb - t * 7.0)
                    horiz *= bump
                    vert *= bump
                o = sd * horiz + Vector((0, vert, 0))
                if phi != 0.0:
                    o = o * math.cos(phi) + tang.cross(o) * math.sin(phi) + tang * tang.dot(o) * (1.0 - math.cos(phi))
                c = top - Vector((0, 0.72 * rv, 0))
                p = c + o
                lump = hash3(p.x * 1.3, p.y * 1.3, p.z * 1.3, 21 + li) * (0.16 + 0.22 * sm(t, 0.1, 0.5)) * min(1.0, rv)
                if math.sin(bb) < 0.7 or release > 0.0:
                    p += (p - c).normalized() * lump
                ring.append(p)
            rings.append(ring)
            if t <= tw_:
                tops.append((top, w * 0.66))
        tiles_l = max(1, round(math.tau * 2.6 / 3.0))
        us = [tiles_l * q / SIDES for q in range(SIDES)]
        vs = []
        acc = 0.0
        for k in range(N_RING + 1):
            if k:
                acc += (rings[k][0] - rings[k - 1][0]).length
            vs.append(acc / 3.0)
        lb._loft_cyl(rings, "bark", us, vs, tiles_l)
        # the end of the main limb: splintered into two broken spikes
        tip_c = sum((p for p in rings[-1]), Vector()) / SIDES
        lb.tube_path([tip_c - dirv * 0.4, tip_c + dirv * 0.8 + Vector((0, 0.3, 0)), tip_c + dirv * 1.5 + Vector((0, 2.4, 0))], [0.28, 0.2, 0.03], "bark", sides=5, jit=0.05, seed=li)
        # great forks: leave the limb at different points, rise steeply, fork again and again into twigs
        forks = [(0.30, 1, 7.0, 0.42), (0.50, -1, 9.0, 0.38), (0.66, 1, 7.5, 0.3), (0.82, -1, 6.0, 0.24), (0.9, 1, 4.5, 0.2)]
        for fi, (ft, fs, fl, fr) in enumerate(forks):
            k = int(ft * N_RING)
            ring = rings[k]
            cen = sum((p for p in ring), Vector()) / SIDES
            tn = top_at(ft + 0.02) - top_at(ft - 0.02)
            tg = tn.normalized()
            sd_ = Vector((tg.z, 0, -tg.x)) * fs
            wv = max(abs((ring[0] - ring[SIDES // 2]).length), 0.5) * 0.5
            start = cen + sd_ * wv * 0.55 + Vector((0, 0.5, 0))
            dv = (tg * 0.35 + sd_ * 0.95 + Vector((0, 0.65 + 0.35 * (fi % 2), 0))).normalized()
            if li == 2 and fi in (1, 3):
                dv = (dv + Vector((0, 0.9, 0))).normalized()
            grow(start, dv, fl, min(wv * fr * 2.2, 1.3), 2, 500 + li * 40 + fi * 7, grav=0.1 + 0.1 * (li == 0), lift=0.35)
        # dead stubs hanging underneath and splintered snags on the limb's top edge
        for q in range(7):
            ft = twig_r.uniform(0.2, 0.85)
            k = int(ft * N_RING)
            ring = rings[k]
            cen = sum((p for p in ring), Vector()) / SIDES
            sg = twig_r.choice([-1.0, 1.0])
            tn = top_at(ft + 0.02) - top_at(ft - 0.02)
            tg = tn.normalized()
            sd_ = Vector((tg.z, 0, -tg.x)) * sg
            st = cen + sd_ * 0.9 - Vector((0, 0.5, 0))
            grow(st, (sd_ * 0.7 + Vector((0, -0.55, 0)) + tg * 0.2).normalized(), twig_r.uniform(2.2, 4.8), 0.22, 1, 900 + li * 17 + q, grav=0.5, lift=0.0)
        limb_col.append(tops)
        limb_tips.append(tops[-1][0])
    limbs_ob = lb.finish()
    L.moss_colors(limbs_ob, 5)
    darken_inside(limbs_ob)
    objs.append(limbs_ob)

    # ------------------------------------------------------------------ crown spikes on the broken rim
    cb = B("Crown", mats)
    cr = random.Random(5)
    for k in range(9):
        a = cr.uniform(0, math.tau)
        rad = r_out(36.0) * cr.uniform(0.55, 0.98)
        top_y = 38.0 + jag(a) + 0.5
        h = cr.uniform(3.0, 6.2)
        st = pos(a, rad, top_y - 1.6)
        lean = Vector((math.sin(a), 0, math.cos(a))) * cr.uniform(-0.4, 1.4)
        en = st + Vector((0, h, 0)) + lean
        cb.tube(st, en, cr.uniform(0.7, 1.15), 0.05, "bark", sides=8, jit=0.2, seed=k)
    # long roots that hang from the broken rim down the hollow
    for k in range(6):
        a = cr.uniform(0, math.tau)
        st = pos(a, r_in(33.0) - 0.1, 36.5)
        en = pos(a + cr.uniform(-0.3, 0.3), r_in(33.0) - cr.uniform(0.4, 1.3), 36.5 - cr.uniform(6.0, 13.0))
        cb.tube(st, st.lerp(en, 0.5) + Vector((0, 0, 0)), 0.2, 0.12, "bark", sides=5, jit=0.04, seed=k, cap=False)
        cb.tube(st.lerp(en, 0.5), en, 0.12, 0.03, "bark", sides=5, jit=0.04, seed=k + 1)
    # great snags: thick dead limbs that left the trunk high up and were broken off, reaching up and out
    for k in range(7):
        a = 0.9 + k * 0.9 + cr.uniform(-0.2, 0.2)
        y0 = 22.0 + k * 2.1
        r0 = r_out(y0) * 0.92
        out = Vector((math.sin(a), 0, math.cos(a)))
        p0 = pos(a, r0, y0)
        p1 = p0 + out * cr.uniform(2.5, 4.0) + Vector((0, cr.uniform(1.0, 2.5), 0))
        p2 = p1 + out * cr.uniform(2.0, 4.5) + Vector((0, cr.uniform(2.5, 5.0), 0)) + Vector((cr.uniform(-1.5, 1.5), 0, cr.uniform(-1.5, 1.5)))
        p3 = p2 + out * cr.uniform(0.5, 2.0) + Vector((0, cr.uniform(3.0, 6.0), 0))
        cb.tube_path([p0 - out * 1.0, p0, p1, p2, p3], [1.5, 1.25, 0.85, 0.5, 0.06], "bark", sides=8, jit=0.12, seed=40 + k)
        for j in range(3):
            q = p1.lerp(p2, 0.3 + 0.3 * j)
            d = (out + Vector((cr.uniform(-1, 1), 0.9, cr.uniform(-1, 1)))).normalized()
            cb.tube(q, q + d * cr.uniform(2.0, 4.5), 0.22, 0.03, "bark", sides=5, jit=0.04, seed=60 + k * 3 + j)
    crown_ob = cb.finish()
    L.moss_colors(crown_ob, 7, 0.6)
    objs.append(crown_ob)

    # ------------------------------------------------------------------ the stair
    sb = B("Stair", mats)
    rails = []
    stair_pts = []          # (inner top point, outer top point) per step edge, for the collision ramp
    for s in range(STAIR_N + 1):
        a = stair_a(s)
        y = stair_y(s)
        ro_ = r_in(y) - 0.12
        ri_ = ro_ - STAIR_W
        stair_pts.append((pos(a, ri_, y), pos(a, ro_, y)))
    for s in range(STAIR_N):
        am = stair_a(s) + DA * 0.5
        y = stair_y(s) + RISE * 0.5
        ro_ = r_in(y) - 0.12
        ri_ = ro_ - STAIR_W
        rm = (ro_ + ri_) / 2
        chord = 2.0 * rm * math.sin(DA / 2) * 1.04 + 0.04
        slope = math.atan2(RISE, rm * DA)
        # tread: a plank across the stair, pitched with the flight; the riser below it dark
        sb.box(tuple(pos(am, rm, y - 0.09)), (STAIR_W + 0.1, 0.17, chord), "plank", yaw=am + math.pi / 2, pitch=-slope, cuts=0, scale_uv=0.5)
        if s % 3 == 0:
            # a root arm from the wall, curving down and in under the tread's edge
            rw = r_in(y)
            sb.tube_path([pos(am, rw + 0.25, y - 0.2), pos(am, rw - 0.25, y - 0.62), pos(am, rm + 0.5, y - 0.52), pos(am, rm - 0.2, y - 0.3)],
                         [0.3, 0.24, 0.16, 0.1], "heart", sides=6, jit=0.04, seed=s)
        if s % 6 == 1:
            # a root stub standing at the inner edge
            pp = pos(stair_a(s) + DA * 0.5, ri_ + 0.06, stair_y(s) + RISE * 0.5)
            sb.tube(pp - Vector((0, 0.1, 0)), pp + Vector((0.05, 0.85, 0.03)), 0.085, 0.05, "heart", sides=6, jit=0.02, seed=s)
        if s % 2 == 1:
            pp = pos(stair_a(s) + DA * 0.5, ri_ + 0.06, stair_y(s) + RISE * 0.5)
            rails.append(pp + Vector((0, 0.95, 0)))
    # the stringer: one curved log under the treads, following the flight round the wall
    string_pts = []
    for s in range(0, STAIR_N + 1, 2):
        y_ = stair_y(s)
        rw_ = r_in(y_)
        string_pts.append(pos(stair_a(s), rw_ - 0.12 - STAIR_W * 0.5, y_ - 0.42))
    sb.tube_path(string_pts, [0.34 + 0.05 * math.sin(i * 0.7) for i in range(len(string_pts))], "heart", sides=8, jit=0.03, seed=17)
    # the rail: one gnarled root laid along the helix in runs, broken where the landings are
    run = []
    for k in range(len(rails)):
        if run and (rails[k] - run[-1]).length >= 3.0:
            if len(run) > 2:
                sb.tube_path(run, [0.07 + 0.025 * math.sin(i * 0.9) for i in range(len(run))], "heart", sides=6, jit=0.03, seed=len(run))
            run = []
        run.append(rails[k])
    if len(run) > 2:
        sb.tube_path(run, [0.07 + 0.025 * math.sin(i * 0.9) for i in range(len(run))], "heart", sides=6, jit=0.03, seed=3)
    # landings at the limb doors: a heavy timber platform spanning the door's width
    for lm in limbs:
        a = lm["a_door"]
        y = lm["y"]
        rw = r_in(y)
        ri_ = rw - 0.12 - STAIR_W
        rm = (rw + ri_) / 2 + 0.2
        sb.box(tuple(pos(a, rm, y - 0.45)), (rw - ri_ + 0.6, 0.55, 3.6), "plank", yaw=a + math.pi / 2, scale_uv=0.5)      # zone fit: top 0.175 under the sill, so the treads either side meet it in a step of 0.17 (it stood 0.3 over the treads before it)
        sb.box(tuple(pos(a, rw + 0.6, y - 1.6)), (1.0, 3.0, 3.4), "heart", yaw=a + math.pi / 2, scale_uv=0.4)
    # the crown deck: an annulus of planks at the top of the flight
    y_top = stair_y(STAIR_N)
    a_end = stair_a(STAIR_N)
    deck_pts = []
    for k in range(14):
        a = a_end + k * 0.32
        rwk = r_in(y_top)
        ri_ = 0.9
        rm = (rwk + ri_) / 2 - 0.05
        sb.box(tuple(pos(a, rm, y_top - 0.12)), (rwk - ri_, 0.24, 2.0 * rm * math.sin(0.17) + 0.18), "plank", yaw=a + math.pi / 2, scale_uv=0.5)
    stair_ob = sb.finish()
    L.moss_colors(stair_ob, 5, 0.0)
    ca2 = stair_ob.data.color_attributes["Col"]
    cols2 = np_mod.empty(len(stair_ob.data.loops) * 4, dtype=np_mod.float32)
    ca2.data.foreach_get("color", cols2)
    cols2 = cols2.reshape(-1, 4)
    cols2[:, :3] *= np_mod.array([0.9, 0.8, 0.7], dtype=np_mod.float32)
    ca2.data.foreach_set("color", cols2.ravel())
    objs.append(stair_ob)

    # ------------------------------------------------------------------ collision proxies (never drawn)
    cm = {"dark": dark}
    # trunk: coarse thick shell with the same openings
    tb = B("TrunkCol", cm)
    NCc = NC // 2 * 1
    tbm = tb.bm
    rows = KC
    cvo = []
    cvi = []
    for k in range(rows):
        y = Y0 + DYC * k
        ro = []
        ri = []
        for j in range(NC):
            a = math.tau * j / NC
            ro.append(tbm.verts.new(pos(a, r_out(y) * 0.99, y)))
            ri.append(tbm.verts.new(pos(a, r_in(y) * 1.01, y)) if y >= -0.001 else None)
        cvo.append(ro)
        cvi.append(ri)
    for k in range(rows - 1):
        for j in range(NC):
            if open_coarse(k, j):
                continue
            j2 = (j + 1) % NC
            f = tbm.faces.new([cvo[k][j], cvo[k][j2], cvo[k + 1][j2], cvo[k + 1][j]])
            f.material_index = 0
            if cvi[k][j] is not None:
                g = tbm.faces.new([cvi[k][j2], cvi[k][j], cvi[k + 1][j], cvi[k + 1][j2]])
                g.material_index = 0
    for k in range(rows - 1):
        for j in range(NC):
            if not open_coarse(k, j):
                continue
            j2 = (j + 1) % NC
            jm = (j - 1) % NC
            def jm_(a0, a1, b1, b0, rev=False):
                if a0 is None or b0 is None:
                    return
                pts = [a0, a1, b1, b0]
                if rev:
                    pts.reverse()
                try:
                    tbm.faces.new(pts)
                except ValueError:
                    pass
            if not open_coarse(k, jm):
                jm_(cvo[k][j], cvo[k + 1][j], cvi[k + 1][j], cvi[k][j])
            if not open_coarse(k, j2):
                jm_(cvo[k][j2], cvo[k + 1][j2], cvi[k + 1][j2], cvi[k][j2], True)
            if k > 0 and not open_coarse(k - 1, j) and cvi[k][j] is not None:
                jm_(cvo[k][j], cvo[k][j2], cvi[k][j2], cvi[k][j], True)
            if not open_coarse(k + 1, j):
                jm_(cvo[k + 1][j], cvo[k + 1][j2], cvi[k + 1][j2], cvi[k + 1][j])
    # the floor and the root flare: a solid disc
    fl = [cvi[2][j] for j in range(NC) if cvi[2][j] is not None]
    if len(fl) == NC:
        try:
            tbm.faces.new(fl)
        except ValueError:
            pass
    objs.append(tb.finish(merge=False))

    # the ramp: a helicoid strip along the tread tops (double faced by the game)
    stb = B("StairCol", cm)
    pm = stb.bm
    prev = None
    for s in range(STAIR_N + 1):
        pi_, po_ = stair_pts[s]
        cur = (pm.verts.new(pi_ + Vector((0, 0, 0))), pm.verts.new(po_ + Vector((0, 0, 0))))
        if prev:
            try:
                pm.faces.new([prev[0], prev[1], cur[1], cur[0]])
            except ValueError:
                pass
        prev = cur
    objs.append(stb.finish(merge=False))

    # the rail: a thin wall along the inner edge, 1.0 m high, broken where the landings are
    rcb = B("RailCol", cm)
    rm_ = rcb.bm
    prev = None
    for s in range(STAIR_N + 1):
        pi_, _ = stair_pts[s]
        gap = False
        for lm in limbs:
            if abs(s - lm["s"]) <= 2:
                gap = True
        cur = (rm_.verts.new(pi_ + Vector((0, -0.1, 0))), rm_.verts.new(pi_ + Vector((0, 1.0, 0))))
        if prev and not gap:
            try:
                rm_.faces.new([prev[0], cur[0], cur[1], prev[1]])
            except ValueError:
                pass
        prev = cur
    objs.append(rcb.finish(merge=False))

    # the limb walks: a closed box-section ribbon under the walk top
    lcb = B("LimbCol", cm)
    lm_ = lcb.bm
    for tops in limb_col:
        rings = []
        for (top, w) in tops:
            d = Vector((0, 0, 0))
            rings.append(top)
        for k in range(len(tops) - 1):
            (t0, w0), (t1, w1) = tops[k], tops[k + 1]
            dirv = (t1 - t0)
            dirv.y = 0
            dirv.normalize()
            sd = Vector((dirv.z, 0, -dirv.x))
            vs = [lm_.verts.new(t0 + sd * w0 * 0.5), lm_.verts.new(t0 - sd * w0 * 0.5), lm_.verts.new(t1 - sd * w1 * 0.5), lm_.verts.new(t1 + sd * w1 * 0.5)]
            try:
                lm_.faces.new(vs)
            except ValueError:
                pass
            # edge skirts so the walk has sides
            for sgn, i0 in ((1.0, 0), (-1.0, 1)):
                v0 = lm_.verts.new(t0 + sd * sgn * w0 * 0.5)
                v1 = lm_.verts.new(t1 + sd * sgn * w1 * 0.5)
                v2 = lm_.verts.new(t1 + sd * sgn * w1 * 0.5 - Vector((0, 1.2, 0)))
                v3 = lm_.verts.new(t0 + sd * sgn * w0 * 0.5 - Vector((0, 1.2, 0)))
                try:
                    lm_.faces.new([v0, v1, v2, v3] if sgn > 0 else [v3, v2, v1, v0])
                except ValueError:
                    pass
    objs.append(lcb.finish(merge=False))

    # the landings and the crown deck, as flat plates
    dcb = B("DeckCol", cm)
    dm = dcb.bm
    for lm in limbs:
        a = lm["a_door"]
        y = lm["y"]
        rw = r_in(y)
        ri_ = rw - 0.12 - STAIR_W
        c = pos(a, (rw + ri_) / 2 + 0.2, y - 0.175)
        tang = Vector((math.cos(a), 0, -math.sin(a)))
        rad = Vector((math.sin(a), 0, math.cos(a)))
        hw = (rw - ri_ + 0.6) / 2
        hl = 1.8
        p = [c + rad * hw + tang * hl, c + rad * hw - tang * hl, c - rad * hw - tang * hl, c - rad * hw + tang * hl]
        # extend through the door to the limb's first walk point
        p0 = limb_col[limbs.index(lm)][0][0]
        try:
            dm.faces.new([dm.verts.new(q) for q in p])
        except ValueError:
            pass
        q0 = p0 + tang * 1.7
        q1 = p0 - tang * 1.7
        try:
            dm.faces.new([dm.verts.new(c + rad * hw + tang * 1.7), dm.verts.new(c + rad * hw - tang * 1.7), dm.verts.new(q1), dm.verts.new(q0)])
        except ValueError:
            pass
    for k in range(13):
        a0 = a_end + k * 0.32
        a1 = a0 + 0.32
        rwk = r_in(y_top)
        v = [dm.verts.new(pos(a0, 0.9, y_top)), dm.verts.new(pos(a0, rwk, y_top)), dm.verts.new(pos(a1, rwk, y_top)), dm.verts.new(pos(a1, 0.9, y_top))]
        try:
            dm.faces.new(v)
        except ValueError:
            pass
    objs.append(dcb.finish(merge=False))

    # ------------------------------------------------------------------ the far silhouette
    fb = B("OakFar", {"bark": bark})
    prof = [(r_out(y) * 1.05, y) for y in (-3.0, 0.0, 6.0, 14.0, 24.0, 32.0, 37.0)]
    fb.lathe(prof, "bark", sides=14, bark=6.0)
    for li, lm in enumerate(limbs):
        top = limb_col[li]
        fb.tube(top[0][0] - Vector((0, 1.0, 0)), top[-1][0] - Vector((0, 0.6, 0)), 1.3, 0.35, "bark", sides=5, bark=6.0)
    for k in range(5):
        a = k * 1.3
        fb.tube(pos(a, 3.0, 34.0), pos(a, 2.0, 40.5), 0.9, 0.1, "bark", sides=4, bark=6.0)
    for ra in root_az[::2]:
        fb.tube(pos(ra, 5.0, 2.0), pos(ra, 13.0, -0.3), 1.8, 0.6, "bark", sides=4, bark=6.0)
    objs.append(fb.finish())

    # ------------------------------------------------------------------ numbers for the game
    DATA["OAK_H"] = 40.0
    DATA["OAK_STAIR"] = {"n": STAIR_N, "turn": STAIR_TURN, "rise": RISE, "y0": STAIR_Y0, "a0": A0, "w": STAIR_W,
                         "top": y_top, "a_end": a_end}
    DATA["OAK_DOOR"] = {"a": math.pi + (ent_c0 + 2.5 - NC / 2) / NC * math.tau, "w": 3.3, "h": 4.2, "r": r_out(0.0)}
    DATA["OAK_LIMBS"] = [{"door_a": lm["a_door"], "y": lm["y"], "tip": [round(limb_tips[i].x, 2), round(limb_tips[i].y, 2), round(limb_tips[i].z, 2)],
                          "walk": [[round(t.x, 2), round(t.y, 2), round(t.z, 2), round(w, 2)] for (t, w) in limb_col[i]]} for i, lm in enumerate(limbs)]
    DATA["OAK_LAIR_A"] = LAIR_A
    DATA["OAK_ROUT"] = [round(r_out(y), 2) for y in (0.0, 10.0, 20.0, 30.0, 38.0)]
    DATA["OAK_RIN"] = [round(r_in(y), 2) for y in (0.0, 10.0, 20.0, 30.0, 38.0)]
    objs_out.extend(objs)
    return objs
