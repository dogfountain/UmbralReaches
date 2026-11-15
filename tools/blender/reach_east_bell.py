"""The eighth bell (tools/blender/reach_east.py): the Founder's last casting, fallen from the sky into the Bellfall's
crater and lying on its side, half sunk in scorched rock. A cast-bronze shell 12 m from crown to lip and 13 m across the
mouth, thick at the sound bow, with its crown loops, its yoke torn out and splintered, a great wedge of the lip broken
away, a crack run up from the break to the shoulder, the lip's shards scattered across the crater floor, and cold runes
along the cracks. The floor round it is heaped with ejecta (a walkable ramp up its east flank to the lip's top).

Local frame (Godot): the origin is on the crater floor under the bell's middle. The mouth faces +z (the south lip,
where bell_track comes in) and tilts up 28 degrees; the crown is buried toward the north wall (-z).

  Bell        the shell, crown loops, yoke stubs, runes (near)
  BellFar     the silhouette (a coarse outer shell)
  BellShards  the lip's scattered pieces
  Ejecta      the heap of scorched rock round the bell, with the ramp up to the lip (walkable)
  BellCol     the shell (outer and inner), for collision
  EjectaCol   the heap's own mesh, for collision
"""
import math
import random
import numpy as np
from mathutils import Vector
import r37_south_lib as L
from r37_south_lib import B, hash3
import reach_east_lib as E

LB = 12.0                                   # crown to lip
PSI = math.radians(62.0)                    # the bell's axis lies 28 degrees above the horizon (rotation about x)
ORIGIN = Vector((0.0, -0.7, -6.4))          # where the crown lands in the frame


def catmull(pts, x):
    xs = [p[0] for p in pts]
    n = len(pts)
    i = max(0, min(n - 2, np.searchsorted(xs, x) - 1))
    p0, p1, p2, p3 = pts[max(i - 1, 0)], pts[i], pts[i + 1], pts[min(i + 2, n - 1)]
    t = (x - p1[0]) / (p2[0] - p1[0])
    t2, t3 = t * t, t * t * t
    return 0.5 * ((2 * p1[1]) + (-p0[1] + p2[1]) * t + (2 * p0[1] - 5 * p1[1] + 4 * p2[1] - p3[1]) * t2 + (-p0[1] + 3 * p1[1] - 3 * p2[1] + p3[1]) * t3)


PROFILE = [(-0.3, 1.5), (0.0, 1.7), (0.6, 2.3), (1.5, 2.65), (2.8, 2.9), (4.4, 3.35), (6.2, 3.95), (8.0, 4.7), (9.8, 5.55), (11.2, 6.2), (12.0, 6.5), (12.4, 6.5)]
BANDS = [(1.9, 0.15, 0.2), (3.1, 0.12, 0.16), (6.4, 0.10, 0.22), (10.3, 0.16, 0.24), (11.5, 0.2, 0.2)]      # centre, height, half width


def r_out(s):
    r = catmull(PROFILE, s)
    for c, h, w in BANDS:
        d = abs(s - c) / w
        if d < 1.0:
            r += h * (1.0 - d * d) ** 2
    return r


def thick(s):
    return 0.26 + 0.74 * E.smoothstep(5.5, 12.0, s) + 0.1 * E.smoothstep(0.0, 1.5, 1.5 - s)


def s_in(s):
    return s + 0.34 * (1.0 - E.smoothstep(0.0, 3.0, s))


def r_in(s):
    return max(r_out(s) - thick(s), 0.2)


# the damage: which cells of the (row, column) grid are gone, and which wall faces glow
NOTCH_TH = 4.05
CRACK_TH = 4.05


def crack_th(s):
    return NOTCH_TH + 0.1 * math.sin(s * 1.35) + 0.05 * math.sin(s * 3.4 + 1.0)


def notch(th, s):
    d = abs(th - NOTCH_TH)
    edge = 8.1 + 3.4 * (d / 0.62) ** 1.2 + 0.28 * math.sin(th * 23.0) + 0.2 * math.sin(th * 51.0 + s)
    return d < 0.62 and s > edge


def crack(th, s, ncol):
    cw = math.tau / ncol
    if 1.7 < s < 8.4:
        w = cw * (0.45 + 0.6 * E.smoothstep(2.0, 8.4, s))
        if abs(th - crack_th(s)) < w:
            return True
    # a second, narrower crack on the east flank from the lip to the shoulder
    if 5.6 < s < 12.0:
        c2 = 0.32 + 0.09 * math.sin(s * 1.9) + 0.03 * math.sin(s * 5.0)
        if abs(th - c2) < cw * (0.35 + 0.35 * E.smoothstep(5.6, 12.0, s)):
            return True
    return False


def surf(s, th, off=0.0, inner=False):
    if inner:
        r = r_in(s) - off
        return Vector((math.cos(th) * r, s_in(s), math.sin(th) * r))
    r = r_out(s) + off
    return Vector((math.cos(th) * r, s, math.sin(th) * r))


def orient(f, toward):
    f.normal_update()
    c = f.calc_center_median()
    if f.normal.dot(toward - c) < 0:
        f.normal_flip()


def shell(b, nrow, ncol, th0=0.0, th1=math.tau, s0=0.0, s1=LB, keep=None, jag=0.05, seed=3, caps=True, inner=True, glow_walls=True, tiles=6):
    """The bell's wall as a grid. Faces for each kept cell, the thickness wall where the neighbour is gone (glowing if
    near a crack), the crown cap. Returns the set of boundary vertices' positions (unused)."""
    bm = b.bm
    full = abs((th1 - th0) - math.tau) < 1e-6
    nc = ncol
    ss = [s0 + (s1 - s0) * i / nrow for i in range(nrow + 1)]
    ths = [th0 + (th1 - th0) * j / ncol for j in range(ncol + 1)]

    def present(i, j):
        if i < 0 or i >= nrow:
            return False
        if full:
            j %= ncol
        elif j < 0 or j >= ncol:
            return False
        if keep is None:
            return True
        return keep((ss[i] + ss[i + 1]) / 2, (ths[j] + ths[j + 1]) / 2 if j + 1 <= ncol else ths[j])
    pres = {}
    for i in range(nrow):
        for j in range(ncol):
            pres[(i, j)] = present(i, j)

    def P(i, j):
        return pres.get((i, j % ncol if full else j), False)
    # boundary vertices get a jitter
    bad = set()
    for i in range(nrow):
        for j in range(ncol):
            if pres[(i, j)]:
                if not (P(i - 1, j) and P(i + 1, j) and P(i, j - 1) and P(i, j + 1)):
                    for a in (0, 1):
                        for c in (0, 1):
                            bad.add((i + a, (j + c) % ncol if full else j + c))
    vo, vi = {}, {}

    def jit(i, j, v, inn):
        if (i, j) in bad and jag > 0.0 and 0 < i < nrow:
            k = hash3(i * 1.3, j * 0.9, 0.0, seed) * jag
            k2 = hash3(i * 0.7, j * 1.9, 3.0, seed + 1) * jag
            v = v + Vector((k, k2, hash3(i, j, 9.0, seed + 2) * jag))
        return v

    def VO(i, j):
        jj = j % ncol if full else j
        if (i, jj) not in vo:
            vo[(i, jj)] = bm.verts.new(jit(i, jj, surf(ss[i], ths[jj]), False))
        return vo[(i, jj)]

    def VI(i, j):
        jj = j % ncol if full else j
        if (i, jj) not in vi:
            vi[(i, jj)] = bm.verts.new(jit(i, jj, surf(ss[i], ths[jj], 0.0, True), True))
        return vi[(i, jj)]

    def uv_of(i, j, mat_scale=1.0):
        return (j / ncol * tiles * ((th1 - th0) / math.tau if not full else 1.0) * 1.0, ss[i] / 3.4)
    midpt = Vector((0, 0, 0))
    matk = b.keys.index("bronze")
    runek = b.keys.index("rune")
    for (i, j), ok in pres.items():
        if not ok:
            continue
        o = [VO(i, j), VO(i, j + 1), VO(i + 1, j + 1), VO(i + 1, j)]
        try:
            f = bm.faces.new(o)
        except ValueError:
            continue
        f.material_index = matk
        f.smooth = True
        f.normal_update()
        cen = f.calc_center_median()
        radial = Vector((cen.x, 0.0, cen.z))
        if f.normal.dot(radial) < 0:
            f.normal_flip()
        for l, (ii, jj) in zip(f.loops, [(i, j), (i, j + 1), (i + 1, j + 1), (i + 1, j)]):
            l[b.uv].uv = uv_of(ii, jj)
        if inner:
            q = [VI(i, j), VI(i, j + 1), VI(i + 1, j + 1), VI(i + 1, j)]
            try:
                g = bm.faces.new(q)
            except ValueError:
                continue
            g.material_index = matk
            g.smooth = True
            g.normal_update()
            cn = g.calc_center_median()
            if g.normal.dot(Vector((cn.x, 0.0, cn.z))) > 0:
                g.normal_flip()
            for l, (ii, jj) in zip(g.loops, [(i, j), (i, j + 1), (i + 1, j + 1), (i + 1, j)]):
                l[b.uv].uv = (uv_of(ii, jj)[0] * 0.8, ss[ii] / 3.4)
    # walls
    if inner:
        for (i, j), ok in pres.items():
            if not ok:
                continue
            for (di, dj, e0, e1) in ((-1, 0, (0, 0), (0, 1)), (1, 0, (1, 0), (1, 1)), (0, -1, (0, 0), (1, 0)), (0, 1, (0, 1), (1, 1))):
                if P(i + di, j + dj):
                    continue
                a0 = (i + e0[0], j + e0[1])
                a1 = (i + e1[0], j + e1[1])
                if i + di < 0 or i + di >= nrow:
                    if not (di == 1 and s1 < LB - 0.01 or di == -1 and s0 > 0.01 or di == 1):
                        continue
                if (di in (-1, 1)) and (i + di < 0):
                    continue                          # the crown is capped, not walled
                try:
                    f = bm.faces.new([VO(*a0), VO(*a1), VI(*a1), VI(*a0)])
                except ValueError:
                    continue
                sm = (ss[i] + ss[i + 1]) / 2
                tm = (ths[j] + ths[(j + 1)]) / 2 if j < ncol else ths[j]
                near_crack = glow_walls and (crack(tm, sm, ncol) or crack(tm + dj * math.tau / ncol * 1.2, sm, ncol) or (notch(tm + dj * 0.1, sm + di * 0.3) is False and notch(tm + dj * 0.1, sm - di * 0.3) and sm < 10.5))
                f.material_index = runek if (near_crack and sm < 11.0) else matk
                f.smooth = False
                # the wall faces away from the kept cell
                kc = Vector((math.cos(tm) * r_out(sm), sm, math.sin(tm) * r_out(sm)))
                gone = kc + Vector((math.cos(tm + dj * 0.03), 0, math.sin(tm + dj * 0.03))) * 0.0
                f.normal_update()
                cn = f.calc_center_median()
                tgt = Vector((math.cos(tm + dj * 0.04) * r_out(sm), sm + di * 0.12, math.sin(tm + dj * 0.04) * r_out(sm)))
                if dj != 0:
                    tgt = Vector((cn.x, cn.y, cn.z)) + Vector((-math.sin(tm), 0, math.cos(tm))) * dj
                else:
                    tgt = Vector((cn.x, cn.y + di, cn.z))
                if f.normal.dot(tgt - cn) < 0:
                    f.normal_flip()
                for l in f.loops:
                    l[b.uv].uv = (0.0, 0.0) if False else (l.vert.co.x * 0.3, l.vert.co.y * 0.3)
    if caps and s0 <= 0.0 and full:
        ring_o = [VO(0, j) for j in range(ncol)]
        c = bm.verts.new(Vector((0, -0.18, 0)))
        for j in range(ncol):
            try:
                f = bm.faces.new([c, ring_o[(j + 1) % ncol], ring_o[j]])
            except ValueError:
                continue
            f.material_index = matk
            f.smooth = True
            f.normal_update()
            if f.normal.y > 0:
                f.normal_flip()
            for l in f.loops:
                l[b.uv].uv = (l.vert.co.x * 0.3, l.vert.co.z * 0.3)
        if inner:
            ring_i = [VI(0, j) for j in range(ncol)]
            c2 = bm.verts.new(Vector((0, s_in(0) + 0.05, 0)))
            for j in range(ncol):
                try:
                    f = bm.faces.new([c2, ring_i[j], ring_i[(j + 1) % ncol]])
                except ValueError:
                    continue
                f.material_index = matk
                f.smooth = True
                f.normal_update()
                if f.normal.y < 0:
                    f.normal_flip()
                for l in f.loops:
                    l[b.uv].uv = (l.vert.co.x * 0.3, l.vert.co.z * 0.3)


def keep_whole(ncol):
    def k(s, th):
        th = th % math.tau
        return not (notch(th, s) or crack(th, s, ncol))
    return k


def runes(b, ncol, seed=11):
    """Cold runes: strokes laid on the shell along the cracks and in a faint band at the waist."""
    rr = random.Random(seed)
    k = b.keys.index("rune")
    bm = b.bm

    def stroke(a, c, w, off=0.05):
        # a, c = (s, th) ends; w = width in metres across the stroke
        pa = surf(a[0], a[1], off)
        pc = surf(c[0], c[1], off)
        d = pc - pa
        side = Vector((-math.sin((a[1] + c[1]) / 2), 0, math.cos((a[1] + c[1]) / 2))).normalized() if abs(d.y) > abs(d.x) + abs(d.z) else Vector((0, 1, 0))
        n = side * (w / 2)
        try:
            f = bm.faces.new([bm.verts.new(pa - n), bm.verts.new(pa + n), bm.verts.new(pc + n), bm.verts.new(pc - n)])
        except ValueError:
            return
        f.material_index = k
        f.normal_update()
        cn = f.calc_center_median()
        if f.normal.dot(Vector((cn.x, 0, cn.z))) < 0:
            f.normal_flip()
        for l in f.loops:
            l[b.uv].uv = (0.5, 0.5)

    def glyph(s, th, size):
        # one rune: a stem, a bar, a hook, set on the shell at (s, th); size in metres
        r = r_out(s)
        du = size / r
        stem = (rr.random() - 0.5) * 0.3
        stroke((s - size * 0.5, th + stem * du), (s + size * 0.5, th - stem * du), size * 0.09)
        y = s + rr.uniform(-0.2, 0.25) * size
        stroke((y, th - du * 0.4), (y + rr.uniform(-0.2, 0.2) * size, th + du * 0.4), size * 0.08)
        if rr.random() < 0.7:
            stroke((s + size * 0.4, th + du * 0.05), (s + size * 0.15, th + du * 0.45), size * 0.075)
        if rr.random() < 0.4:
            stroke((s - size * 0.4, th - du * 0.45), (s - size * 0.05, th - du * 0.15), size * 0.07)
    # a band of them at the waist, faint ones skipped where the shell is gone
    for j in range(46):
        th = math.tau * j / 46.0 + rr.uniform(-0.03, 0.03)
        s = 4.35 + rr.uniform(-0.12, 0.12)
        if notch(th % math.tau, s) or crack(th % math.tau, s, ncol) or crack((th + 0.05) % math.tau, s, ncol) or crack((th - 0.05) % math.tau, s, ncol):
            continue
        if rr.random() < 0.58:
            glyph(s, th, rr.uniform(0.5, 0.75))
    # clustered along the long crack, either side
    for t in range(14):
        s = 2.4 + t * 0.42
        for side in (-1, 1):
            if rr.random() < 0.6:
                glyph(s + rr.uniform(-0.1, 0.1), crack_th(s) + side * (0.1 + 0.03 * rr.random()) * (1.0 - 0.0 * s) / (r_out(s) / 3.0), rr.uniform(0.28, 0.5))


def crown(b):
    """Six loops from the crown's rim to a central boss, and the iron the yoke was bolted with."""
    b.tube((0, -0.1, 0), (0, -1.0, 0), 0.95, 0.8, "bronze", sides=14, bark=3.0)
    for k in range(6):
        a = math.tau * k / 6.0 + 0.2
        ca, sa = math.cos(a), math.sin(a)
        pts = [Vector((1.55 * ca, 0.05, 1.55 * sa)), Vector((1.45 * ca, -0.55, 1.45 * sa)), Vector((0.95 * ca, -1.05, 0.95 * sa)), Vector((0.5 * ca, -1.25, 0.5 * sa))]
        b.tube_path(pts, [0.3, 0.27, 0.25, 0.23], "bronze", sides=10, bark=2.4, cap_end=False)
    # the yoke: the headstock's stump, charred and splintered, strapped in iron; the beam ran along x
    b.box((-1.0, -2.0, 0.0), (4.4, 0.85, 0.85), "wood", yaw=0.0, scale_uv=0.5)
    for x in (-2.4, -0.5, 1.0):
        b.box((x, -2.0, 0.0), (0.22, 1.05, 1.05), "iron", scale_uv=1.0)
    for sx, ln in ((-3.5, 0.7), (-3.9, 0.45)):
        b.box((sx, -2.0 + (sx + 3.5) * 0.4, 0.15 * (sx + 3.5)), (ln, 0.5, 0.45), "wood", yaw=0.4, pitch=0.2, scale_uv=0.5)
    b.box((0.9, -1.4, 0.0), (0.55, 0.9, 0.5), "iron", scale_uv=1.0)          # the pintle's stub


def transform(b, shift=ORIGIN, extra=None):
    cs, sn = math.cos(PSI), math.sin(PSI)
    for v in b.bm.verts:
        x, y, z = v.co
        y2 = y * cs - z * sn
        z2 = y * sn + z * cs
        p = Vector((x, y2, z2)) + shift
        if extra is not None:
            p = extra(p)
        v.co = p


def mats():
    return {"bronze": E.bronze(), "rune": E.emissive("E_Rune", (0.45, 0.85, 1.0), 4.0), "iron": L.flat("E_Iron", (0.07, 0.065, 0.06), 0.6, 0.8),
            "wood": L.pbr("E_CharWood", L.tex_planks(512, 7710), 2.0), "rock": E.scorch()}


def build_bell(M):
    NC = 208
    b = B("Bell", {k: M[k] for k in ("bronze", "rune", "iron", "wood")})
    shell(b, 120, NC, keep=keep_whole(NC), jag=0.07, seed=5)
    runes(b, NC)
    crown(b)
    transform(b)
    return b.finish()


def build_far(M):
    b = B("BellFar", {"bronze": M["bronze"], "rune": M["rune"], "iron": M["iron"], "wood": M["wood"]})
    shell(b, 22, 40, keep=lambda s, th: not notch(th % math.tau, s), jag=0.0, inner=False, caps=True)
    transform(b)
    return b.finish()


def build_col(M):
    b = B("BellCol", {"bronze": M["bronze"], "rune": M["rune"]})
    shell(b, 28, 56, keep=lambda s, th: not notch(th % math.tau, s), jag=0.0, glow_walls=False)
    transform(b)
    return b.finish()


def build_shards(M):
    rr = random.Random(41)
    b = B("BellShards", {"bronze": M["bronze"], "rune": M["rune"]})
    spots = [(7.0, 2.0, 0.4, 0.8, 11.0, 0.9), (3.0, 3.0, -0.5, 0.6, 10.0, 0.7), (-9.0, 7.5, 1.2, 0.7, 10.6, 0.8), (-5.0, 10.0, 2.0, 0.9, 11.0, 0.6),
             (11.5, 9.0, 0.2, 0.55, 9.5, 0.9), (-13.0, 2.0, 0.5, 0.7, 10.2, 0.6)]
    for k, (px, pz, yaw, span, s_lo, lean) in enumerate(spots):
        tmp = B("sh", {"bronze": M["bronze"], "rune": M["rune"]})
        th0 = rr.uniform(0, math.tau)
        sh_len = rr.uniform(1.2, 1.9) if k else 2.6
        shell(tmp, 7, 8, th0, th0 + span, s_lo, s_lo + sh_len, jag=0.14, seed=60 + k, caps=False, glow_walls=False, tiles=2)
        # centre it and lay it down convex-up, leaning
        vs = [v.co for v in tmp.bm.verts]
        c = sum(vs, Vector((0, 0, 0))) / len(vs)
        m = Vector((math.cos(th0 + span / 2), 0, math.sin(th0 + span / 2)))
        ang = math.atan2(m.z, m.x)
        # rotate so the shard's outward normal (m) points up (+y): about the z-axis, then lean
        for v in tmp.bm.verts:
            p = v.co - c
            # rotate p about y so m -> +x, then about z by 90 degrees so +x -> +y
            ca, sa = math.cos(ang), math.sin(ang)
            x, z = p.x * ca + p.z * sa, -p.x * sa + p.z * ca
            y = p.y
            q = Vector((-y, x, z))              # +x -> +y
            lt = lean * 0.5
            q = Vector((q.x * math.cos(lt) - q.y * math.sin(lt) * 0.0, q.y, q.z))
            yw = yaw
            qx = q.x * math.cos(yw) + q.z * math.sin(yw)
            qz = -q.x * math.sin(yw) + q.z * math.cos(yw)
            v.co = Vector((qx + px, q.y * 0.0 + q.y + 0.2, qz + pz))
        # merge into b
        verts = {}
        tmp.bm.verts.index_update()
        for v in tmp.bm.verts:
            verts[v.index] = b.bm.verts.new(v.co)
        tmp.bm.verts.ensure_lookup_table()
        for f in tmp.bm.faces:
            try:
                nf = b.bm.faces.new([verts[v.index] for v in f.verts])
            except ValueError:
                continue
            nf.material_index = f.material_index
            nf.smooth = f.smooth
            for l, l0 in zip(nf.loops, f.loops):
                l[b.uv].uv = l0[tmp.uv].uv
        tmp.bm.free()
    return b.finish()


RAMP = [(29.0, 21.0, 7.5), (24.0, 16.5, 7.6), (18.5, 11.0, 7.5), (13.0, 6.6, 7.3), (6.4, 3.2, 7.1)]


def _ramp_at(x, z):
    """(distance to the ramp's crest line, the crest's height there)."""
    best = (1e9, 0.0)
    for k in range(len(RAMP) - 1):
        ax, az, ay = RAMP[k]
        bx, bz, by = RAMP[k + 1]
        dx, dz = bx - ax, bz - az
        t = max(0.0, min(1.0, ((x - ax) * dx + (z - az) * dz) / (dx * dx + dz * dz)))
        px, pz = ax + dx * t, az + dz * t
        d = math.hypot(x - px, z - pz)
        if d < best[0]:
            best = (d, ay + (by - ay) * t)
    return best


def heap_height(x, z):
    """The ejecta: scorched rock thrown out of the impact, heaped on the east flank where it ramps up to the bell's
    ledge (a crest 2.8 m wide that does not climb past 17 degrees, its sides at the angle of repose)."""
    d, cy = _ramp_at(x, z)
    h = cy - max(0.0, d - 1.6) * 0.74
    # slag lumps and a rough crest
    n = hash3(x * 0.6, 0.0, z * 0.6, 3) * 0.9 + hash3(x * 1.7, 1.0, z * 1.7, 5) * 0.45 + hash3(x * 4.1, 2.0, z * 4.1, 7) * 0.12
    h += n * (0.4 + 0.6 * min(1.0, max(0.0, (d - 1.0) / 3.0)))
    # the heap's foot, a skirt round the bell on the south side
    sk = 1.8 * max(0.0, 1.0 - math.hypot(x * 0.8, z - 9.0) / 15.0)
    return max(h, sk * (0.5 + 0.5 * n) - 0.3, -0.9)


def build_ejecta(M):
    b = B("Ejecta", {"rock": M["rock"]})
    x0, x1, z0, z1 = 2.0, 34.0, -6.0, 28.0
    nx, nz = 96, 100
    rows = []
    for i in range(nz + 1):
        row = []
        for j in range(nx + 1):
            x = x0 + (x1 - x0) * j / nx
            z = z0 + (z1 - z0) * i / nz
            h = heap_height(x, z)
            edge = min(j, nx - j, i, nz - i)
            if edge < 4:
                h = min(h, -0.9 + edge * 0.1)
            row.append(Vector((x, h, z)))
        rows.append(row)
    b.loft(rows, "rock", closed=False, smooth=True, box_uv=0.12)
    return b.finish()


def build_all(objs, M):
    objs.append(build_bell(M))
    objs.append(build_far(M))
    objs.append(build_shards(M))
    objs.append(build_ejecta(M))
    objs.append(build_col(M))
