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
        return 6.2 + (-y) * 0.95
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
    return Vector((0.7 * math.sin(y * 0.11 + 0.4) + 0.012 * y, 0, 0.6 * math.cos(y * 0.09 + 1.1)))


def pos(a, r, y):
    return Vector((r * math.sin(a), y, r * math.cos(a))) + sway(y)


def build(DATA, PREVIEW, objs_out):
    bark = L.pbr_files("R37_OakBark", "bark_giant")
    plank = L.pbr("R37_OakPlank", L.tex_planks(512, 3802), 2.4)
    dark = L.flat("R37_OakDark", (0.012, 0.01, 0.01), 1.0)
    iron = L.flat("R37_OakIron", (0.07, 0.065, 0.06), 0.55, 0.85)
    rope = L.flat("R37_OakRope", (0.19, 0.15, 0.1), 0.95)
    bark.use_backface_culling = False           # the jambs of the openings are single faces
    mats = {"bark": bark, "plank": plank, "dark": dark, "iron": iron, "rope": rope}
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

    def open_fine(i, j):
        return open_coarse(i // 2, (j % NF) // 2)

    NI = (KC - 1) * 2 + 1            # fine rings 0..NI-1  (NI = 59)
    ys = [Y0 + DYF * i for i in range(NI)]
    floor_i = int(round((0.0 - Y0) / DYF))       # y = 0

    def jag(a):
        return 3.8 * (hash3(math.sin(a) * 2.4, 5.0, math.cos(a) * 2.4, 3) * 1.6) + 1.6 * hash3(math.sin(a * 3) * 3.0, 9.0, math.cos(a * 3) * 3.0, 4) + 1.4 * math.sin(a * 5 + 1.0)

    # root flare azimuths and the lair gap
    root_az = [0.25 + k * math.tau / 9.0 for k in range(9)]
    LAIR_A = 4.35         # west-south-west: the gap between two roots where the Root-Wife keeps her bed
    root_az = [a for a in root_az if abs(((a - LAIR_A + math.pi) % math.tau) - math.pi) > 0.55]

    def bulge(a, y):
        # the buttress swell of the root flare (to ~y 6)
        k = 0.0
        for ra in root_az:
            d = ((a - ra + math.pi) % math.tau) - math.pi
            k = max(k, math.exp(-(d / 0.2) ** 2))
        return 1.0 + 0.3 * k * (1.0 - sm(y, 0.0, 6.5))

    burls = [(0.9, 6.5, 0.26, 1.7), (2.4, 12.5, 0.22, 1.3), (4.0, 17.0, 0.3, 2.0), (5.3, 9.0, 0.2, 1.2), (1.9, 25.0, 0.25, 1.8), (3.3, 29.5, 0.2, 1.4), (0.3, 20.5, 0.24, 1.5)]

    def surf(a, y, inner):
        base = r_in(y) if inner else r_out(y)
        base *= 1.0 + 0.045 * math.sin(y * 0.21 + a * 2.0)
        if not inner:
            for (ba, by, bk, bs) in burls:
                d = ((a - ba + math.pi) % math.tau) - math.pi
                base *= 1.0 + bk * math.exp(-((d * 5.0 / bs) ** 2) - (((y - by) / (bs * 1.4)) ** 2))
        ridge = 0.05 * math.sin(a * 13.0 + 2.2 * hash3(math.sin(a) * 1.7, y * 0.2, math.cos(a) * 1.7, 11)) + 0.06 * hash3(math.sin(a) * 2.2, y * 0.3, math.cos(a) * 2.2, 12)
        if inner:
            return base * (1.0 + ridge * 0.8)
        return base * bulge(a, y) * (1.0 + ridge)

    def ring_y(i, a):
        y = ys[i]
        if i >= NI - 4:
            y += jag(a) * sm(i, NI - 5, NI - 1)
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
    tiles = round(math.tau * 5.2 / 3.0)
    vs_ = [ys[i] / 3.0 for i in range(NI)]

    def uvq(f, j, i):
        u0 = tiles * j / NF
        u1 = tiles * (j + 1) / NF
        f.loops[0][b.uv].uv = (u0, vs_[i])
        f.loops[1][b.uv].uv = (u1, vs_[i])
        f.loops[2][b.uv].uv = (u1, vs_[i + 1])
        f.loops[3][b.uv].uv = (u0, vs_[i + 1])

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
                g.material_index = 0
                g.smooth = True
                g.loops[0][b.uv].uv = (tiles * (j + 1) / NF, vs_[i])
                g.loops[1][b.uv].uv = (tiles * j / NF, vs_[i])
                g.loops[2][b.uv].uv = (tiles * j / NF, vs_[i + 1])
                g.loops[3][b.uv].uv = (tiles * (j + 1) / NF, vs_[i + 1])
    # jambs: between the outer and inner faces where an open cell meets a closed one
    def jamb(p0o, p1o, p1i, p0i, rev):
        pts = [p0o, p1o, p1i, p0i]
        if rev:
            pts = list(reversed(pts))
        try:
            f = bm.faces.new(pts)
        except ValueError:
            return
        f.material_index = 0
        f.smooth = False
        L_ = (p1o.co - p0o.co).length
        h_ = (p0i.co - p0o.co).length
        f.loops[0][b.uv].uv = (0, 0)
        f.loops[1][b.uv].uv = (L_ / 3.0, 0)
        f.loops[2][b.uv].uv = (L_ / 3.0, h_ / 3.0)
        f.loops[3][b.uv].uv = (0, h_ / 3.0)

    for i in range(floor_i, NI - 1):
        for j in range(NF):
            if not open_fine(i, j):
                continue
            j2 = (j + 1) % NF
            jm = (j - 1) % NF
            # left neighbour closed: jamb along column j
            if not open_fine(i, jm):
                jamb(vo[i][j], vo[i + 1][j], vi[i + 1][j], vi[i][j], False)
            if not open_fine(i, j2):
                jamb(vo[i][j2], vo[i + 1][j2], vi[i + 1][j2], vi[i][j2], True)
            if i > floor_i and not open_fine(i - 1, j):
                jamb(vo[i][j], vo[i][j2], vi[i][j2], vi[i][j], True)
            if i + 1 < NI - 1 and not open_fine(i + 1, j):
                jamb(vo[i + 1][j], vo[i + 1][j2], vi[i + 1][j2], vi[i + 1][j], False)
            if i == floor_i:
                jamb(vo[i][j], vo[i][j2], vi[i][j2], vi[i][j], True)
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
    # the floor (a dark mould of old leaf and rot)
    fl = [vi[floor_i][j] for j in range(NF)]
    try:
        f = bm.faces.new(fl)
        f.material_index = 4 if False else 1
        # plank map is wrong for earth: use the dark flat
        f.material_index = list(mats.keys()).index("dark")
        for l in f.loops:
            l[b.uv].uv = (0, 0)
    except ValueError:
        pass
    # the root flare's skirt below ground: closed so no light shows through the terrain's seams
    trunk = b.finish()
    objs.append(trunk)

    # ------------------------------------------------------------------ roots
    rb = B("Roots", mats)
    rr = random.Random(77)
    for k, ra in enumerate(root_az + [x + 0.31 for x in root_az[::2]]):
        outer_pt = k >= len(root_az)
        pts = []
        # radial distance, height, sideways wander
        prof = [(4.6, 3.4, 1.9), (6.8, 1.7, 1.5), (9.8, 0.75, 1.1), (14.0, 0.15, 0.8), (19.0, -0.5, 0.5), (24.0, -1.1, 0.3)]
        if outer_pt:
            prof = [(5.6, 1.2, 1.1), (8.0, 0.55, 0.8), (11.5, 0.1, 0.55), (15.5, -0.5, 0.3)]
        wander = rr.uniform(-0.5, 0.5)
        sc = rr.uniform(0.85, 1.2)
        rings = []
        for i, (rad, hy, rw) in enumerate(prof):
            aa = ra + wander * (i / len(prof)) * 0.5
            c = pos(aa, rad * sc if i > 0 else rad, hy)
            rings.append((c, rw * sc))
        rb.tube_path([c for c, _ in rings], [w for _, w in rings], "bark", sides=9, jit=0.14, seed=k * 7)
    objs.append(rb.finish())

    # ------------------------------------------------------------------ limbs
    lb = B("Limbs", mats)
    limb_col = []         # [(walk centre top points, widths)] for the collision proxy
    limb_tips = []
    twig_r = random.Random(9)
    for li, lm in enumerate(limbs):
        a = lm["a_door"]
        dirv = Vector((math.sin(a), 0, math.cos(a)))
        side = Vector((dirv.z, 0, -dirv.x))
        sill = lm["y"]                                   # the walk's top at the door
        d0 = r_in(sill) + 0.25
        Lm = [15.0, 18.0, 13.5][li]
        phase = [0.4, 2.0, 4.1][li]
        n = 14
        rings = []
        tops = []
        for k in range(n + 1):
            t = k / n
            d = d0 + (Lm + 1.3) * t
            lat = 3.6 * math.sin(t * math.pi * 1.1 + phase) - 3.6 * math.sin(phase)
            rise = 2.2 * math.sin(math.pi * t * 0.55) - 3.2 * t ** 3
            if li == 2:
                rise = 1.6 * math.sin(math.pi * t * 0.5) - 1.0 * t ** 2
            w = 3.0 - 1.5 * t ** 0.8
            rv = 2.0 - 1.15 * t
            top = Vector((0, sill + rise, 0)) + dirv * d + side * lat + sway(sill)
            tops.append((top, w))
            c = top - Vector((0, 0.72 * rv, 0))
            tang = (dirv + side * (3.6 * math.cos(t * math.pi * 1.1 + phase) * math.pi * 1.1 / (Lm + 1.3))).normalized()
            sd = Vector((tang.z, 0, -tang.x))
            ring = []
            sides = 12
            for q in range(sides):
                bb = math.tau * q / sides
                horiz = math.cos(bb) * w / 2.0 * (1.0 + 0.25 * (1.0 - t))
                vert = math.sin(bb) * rv
                vert = min(vert, 0.72 * rv)
                p = c + sd * horiz + Vector((0, vert, 0))
                p += (p - c).normalized() * (hash3(p.x, p.y, p.z, 21 + li) * 0.28 + 0.12 * math.sin(t * 9.0 + q * 0.7 + li))
                ring.append(p)
            rings.append(ring)
        tiles_l = max(1, round(math.tau * 1.9 / 3.0))
        us = [tiles_l * q / 12 for q in range(12)]
        vs = [(d0 + (Lm + 1.3) * k / n) / 3.0 for k in range(n + 1)]
        lb._loft_cyl(rings, "bark", us, vs, tiles_l)
        # the tip: broken off in a splinter spike
        tip_c = tops[-1][0] - Vector((0, 0.5, 0))
        lb.tube(tip_c, tip_c + dirv * 2.4 + Vector((0, 2.6, 0)), 0.75, 0.05, "bark", sides=6, jit=0.1, seed=li)
        # dead twigs and snapped stubs from the limb
        for q in range(9):
            t = twig_r.uniform(0.18, 0.95)
            idx = min(n, int(t * n))
            base, wd = tops[idx]
            sgn = twig_r.choice([-1.0, 1.0])
            ang = twig_r.uniform(0.3, 0.8)
            dv = (dirv * twig_r.uniform(0.1, 0.7) + side * sgn + Vector((0, ang * 1.2, 0))).normalized()
            ln = twig_r.uniform(2.5, 6.5) * (1.0 - 0.4 * t)
            st = base + side * sgn * (wd * 0.4) - Vector((0, 0.4, 0))
            en = st + dv * ln
            mid = st.lerp(en, 0.55) + Vector((0, twig_r.uniform(0.2, 0.7), 0)) + side * sgn * 0.3
            r0 = 0.32 * (1.0 - 0.5 * t) + 0.05
            lb.tube(st, mid, r0, r0 * 0.55, "bark", sides=5, jit=0.05, seed=q + li * 10, cap=False)
            lb.tube(mid, en, r0 * 0.55, 0.03, "bark", sides=5, jit=0.05, seed=q + li * 10 + 1)
            if twig_r.random() < 0.6:
                s2 = mid
                e2 = s2 + (dv + Vector((twig_r.uniform(-.7, .7), 0.3, twig_r.uniform(-.7, .7)))).normalized() * ln * 0.45
                lb.tube(s2, e2, r0 * 0.4, 0.02, "bark", sides=4, jit=0.03, seed=q + 99)
        limb_col.append(tops)
        limb_tips.append(tops[-1][0])
    objs.append(lb.finish())

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
    objs.append(cb.finish())

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
        if s % 4 == 0:
            # a bracket from the wall down to the tread's underside
            rw = r_in(y)
            sb.box(tuple(pos(am, (rw + rm) / 2 + 0.3, y - 0.55)), (0.28, 0.32, rw - rm + 0.6), "bark", yaw=am + math.pi / 2 + math.pi / 2, pitch=0.0, scale_uv=0.5)
        if s % 3 == 1:
            # a post at the inner edge, a rope between posts
            pp = pos(stair_a(s) + DA * 0.5, ri_ + 0.06, stair_y(s) + RISE * 0.5)
            sb.box(tuple(pp + Vector((0, 0.52, 0))), (0.09, 1.04, 0.09), "bark", scale_uv=0.5)
            rails.append(pp + Vector((0, 0.95, 0)))
    for k in range(len(rails) - 1):
        a_, b_ = rails[k], rails[k + 1]
        mid = (a_ + b_) / 2 - Vector((0, 0.04, 0))
        ln = (b_ - a_).length
        if ln < 3.0:
            d = (b_ - a_)
            yaw = math.atan2(d.x, d.z)
            pitch = -math.atan2(d.y, math.hypot(d.x, d.z))
            sb.box(tuple(mid), (0.05, 0.05, ln), "rope", yaw=yaw, pitch=pitch)
    # landings at the limb doors: a heavy timber platform spanning the door's width
    for lm in limbs:
        a = lm["a_door"]
        y = lm["y"]
        rw = r_in(y)
        ri_ = rw - 0.12 - STAIR_W
        rm = (rw + ri_) / 2 + 0.2
        sb.box(tuple(pos(a, rm, y - 0.3)), (rw - ri_ + 0.6, 0.55, 3.6), "plank", yaw=a + math.pi / 2, scale_uv=0.5)
        sb.box(tuple(pos(a, rw + 0.6, y - 1.6)), (1.0, 3.0, 3.4), "bark", yaw=a + math.pi / 2, scale_uv=0.4)
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
    objs.append(sb.finish())

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
        c = pos(a, (rw + ri_) / 2 + 0.2, y)
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
