"""Dressed masonry for the ruined landmarks (the Broken Keep, the Drowned Nave): Blender helpers, run through run.sh.

A wall is two things, as a real one is: a rubble CORE (the mortared fill, shaped by the wall's mask, its broken top
following the break smoothly) and FACING STONES laid in courses on each face, each its own pillowed, chamfered block
standing proud of the core so the joints read as dark mortar lines. Where the facing has fallen (the stones whose rect
is not wholly solid, a few at random) the core shows, as on any ruin: no stepped block stacks, no see-through gaps.

  core   -> <name>Core__stone (the cracked fill set, toned dark)
  stones -> <name>__hewn      (the tiling dressed-grain set, each stone its own tone, moss and streaks baked in)

Faces are wound explicitly (outward from a point inside), so nothing here needs recalc_face_normals.
A wall's frame maps (u along it, v up it, d out of its face) to Blender space; flat runs and round towers share it.
"""
import math
import random

import bmesh
import bpy
from mathutils import Vector, Matrix, noise

UV_TILE = 1.9           # metres per tile of the hewn grain (the beacon's 3 m at its 1.6 uv scale)


def fbm(p, octaves=3):
    a, s, n = 1.0, 0.0, 0.0
    f = 1.0
    for _ in range(octaves):
        s += a * noise.noise(p * f)
        n += a
        a *= 0.5
        f *= 2.0
    return s / n


def sstep(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a + 1e-9)))
    return t * t * (3 - 2 * t)


# ============================================================================================ frames
class Flat:
    """A straight wall from plan point a towards b, its foot at z0."""

    def __init__(self, a, b, z0):
        self.a = Vector((a[0], a[1], z0))
        d = Vector((b[0] - a[0], b[1] - a[1], 0.0))
        self.L = d.length
        self.T = d.normalized()
        self.N = Vector((-self.T.y, self.T.x, 0.0))
        self.U = Vector((0.0, 0.0, 1.0))

    def p(self, u, v, d):
        return self.a + self.T * u + self.U * v + self.N * d

    def n(self, u):
        return self.N

    def t(self, u):
        return self.T


class Ring:
    """A round wall about plan centre c, radius r (to the middle of its thickness); u is arc length at r from +x."""

    def __init__(self, c, r, z0):
        self.c = Vector((c[0], c[1], z0))
        self.r = r
        self.L = math.tau * r

    def p(self, u, v, d):
        th = u / self.r
        return self.c + Vector((math.cos(th) * (self.r + d), math.sin(th) * (self.r + d), v))

    def n(self, u):
        th = u / self.r
        return Vector((math.cos(th), math.sin(th), 0.0))

    def t(self, u):
        th = u / self.r
        return Vector((-math.sin(th), math.cos(th), 0.0))


class JambFrame:
    """The reveal of an opening (or a wall's free end) at u on frame F, facing dirn along F's run: s across the
    thickness (0 at the back face), v up, d out of the reveal."""

    def __init__(self, F, u, half, dirn):
        self.F, self.u, self.half, self.dirn = F, u, half, dirn
        self.L = 2 * half

    def p(self, s, v, d):
        return self.F.p(self.u, v, -self.half + s) + self.F.t(self.u) * (self.dirn * d)

    def n(self, s):
        return self.F.t(self.u) * self.dirn

    def t(self, s):
        return self.F.n(self.u)


# ============================================================================================ the builder
class Mason:
    """Collects the core and the stones of one model (two bmeshes with colour and UV layers)."""

    def __init__(self, seed=1):
        self.rnd = random.Random(seed)
        self.stone = bmesh.new()
        self.core = bmesh.new()
        self.layers = {}
        for bm in (self.stone, self.core):
            self.layers[id(bm)] = (bm.loops.layers.color.new("Col"), bm.loops.layers.uv.new("UVMap"))
        self.n_stones = 0
        self.jamb_stones = 0

    # ---------------------------------------------------------------- tones
    @staticmethod
    def weather(co, n):
        """The macro weathering every stone and the core share: damp foot, moss on tops and low on the north side,
        rain streaks down the faces. Returns (multiplier rgb, moss amount)."""
        z = co.z
        damp = 1.0 - 0.4 * (1.0 - sstep(-0.5, 3.0, z))
        nz = max(n.z, 0.0)
        north = max(0.0, n.y) * 0.5
        mn = fbm(co * 0.23 + Vector((7, 3, 1)))
        moss = sstep(0.0, 0.38, mn) * (0.18 + 0.82 * nz + north) * (1.0 - 0.6 * sstep(14.0, 32.0, z))
        moss = min(1.0, moss * (0.55 + 0.45 * (1.0 - sstep(0.0, 3.5, z))))
        streak = sstep(0.12, 0.6, fbm(Vector((co.x * 0.8, co.y * 0.8, co.z * 0.04)) + Vector((3, 1, 2)))) * (1.0 - nz) * 0.28
        k = damp * (1.0 - streak)
        return k, moss

    def tone(self, co, n, base, tint):
        k, moss = self.weather(co, n)
        r, g, b = base * tint[0] * k, base * tint[1] * k, base * tint[2] * k
        mc = (0.42, 0.55, 0.27)
        return (r + (mc[0] - r) * moss, g + (mc[1] - g) * moss, b + (mc[2] - b) * moss, 1.0)

    # ---------------------------------------------------------------- faces
    def face(self, bm, cos, inside, cols, uvoff=(0.0, 0.0), smooth=False):
        """A face through `cos`, wound so its normal points away from `inside`; per-corner colours."""
        vs = [bm.verts.new(c) for c in cos]
        n = (cos[1] - cos[0]).cross(cos[2] - cos[1])
        if n.length < 1e-9 and len(cos) > 3:
            n = (cos[2] - cos[0]).cross(cos[3] - cos[0])
        cen = sum(cos, Vector()) / len(cos)
        if n.dot(cen - inside) < 0.0:
            vs.reverse()
            cols = list(reversed(cols))
            n = -n
        try:
            f = bm.faces.new(vs)
        except ValueError:
            return None
        f.smooth = smooth
        col, uv = self.layers[id(bm)]
        n = n.normalized() if n.length > 1e-9 else Vector((0, 0, 1))
        ax = max(range(3), key=lambda i: abs(n[i]))
        for l, c in zip(f.loops, cols):
            w = l.vert.co
            pu, pv = ((w.y, w.z) if ax == 0 else (w.x, w.z) if ax == 1 else (w.x, w.y))
            l[uv].uv = (pu / UV_TILE + uvoff[0], pv / UV_TILE + uvoff[1])
            l[col] = c
        return f

    # ---------------------------------------------------------------- one facing stone
    def tile(self, F, u0, u1, v0, v1, side, d0, rnd, proud=None, tone=None):
        """A facing stone on wall frame F over [u0,u1] x [v0,v1], on the face at depth side*d0 (side +1 / -1)."""
        w = u1 - u0
        h = v1 - v0
        if w < 0.12 or h < 0.08:
            return
        pr = proud if proud is not None else rnd.uniform(0.045, 0.1)
        ch = min(0.075, w * 0.22, h * 0.26) * rnd.uniform(0.75, 1.15)
        base = tone if tone is not None else rnd.uniform(0.74, 0.95)
        warm = rnd.uniform(0.0, 0.06)
        tint = (1.0 + warm, 1.0, 0.94 - warm * 1.2)
        uvo = (rnd.random(), rnd.random())
        tilt_u = rnd.uniform(-0.02, 0.02)                      # a stone sits a little out of plane
        tilt_v = rnd.uniform(-0.02, 0.02)
        nu = max(1, int(math.ceil(w / 0.55))) if isinstance(F, Ring) else 1
        dback = side * (d0 - 0.035)

        def P(u, v, dd):
            tu = (u - (u0 + u1) * 0.5) / max(w, 1e-6)
            tv = (v - (v0 + v1) * 0.5) / max(h, 1e-6)
            return F.p(u, v, side * (d0 + dd + tilt_u * tu * w * 0.5 + tilt_v * tv * h * 0.5))

        # the outer rim (on the core, its corners off square: hand-cut) and the proud face, its corners at different
        # depths so the face is a shallow twisted plane (hewn, not sawn); nu columns follow a round wall's curve
        us_out = [u0 + w * i / nu for i in range(nu + 1)]
        us_in = [u0 + ch + (w - 2 * ch) * i / nu for i in range(nu + 1)]
        cj = min(0.035, w * 0.06, h * 0.08)
        jb = [rnd.uniform(-cj, cj) for _ in range(nu + 1)]
        jt = [rnd.uniform(-cj, cj) for _ in range(nu + 1)]
        jb[0] = jt[0] = 0.0 if nu > 1 else jb[0]
        rim_b = [F.p(u + (jb[i] if 0 < i < nu or nu == 1 else 0.0), v0 + rnd.uniform(-cj, cj) * 0.5, dback) for i, u in enumerate(us_out)]
        rim_t = [F.p(u + (jt[i] if 0 < i < nu or nu == 1 else 0.0), v1 + rnd.uniform(-cj, cj) * 0.5, dback) for i, u in enumerate(us_out)]
        dz = [rnd.uniform(-0.022, 0.022) for _ in range(2 * (nu + 1))]
        in_b = [P(u + rnd.uniform(-cj, cj), v0 + ch * rnd.uniform(0.7, 1.3), pr * 0.9 + dz[i] + (0.015 if 0 < i < nu else 0.0))
                for i, u in enumerate(us_in)]
        in_t = [P(u + rnd.uniform(-cj, cj), v1 - ch * rnd.uniform(0.7, 1.3), pr + dz[nu + 1 + i] + (0.015 if 0 < i < nu else 0.0))
                for i, u in enumerate(us_in)]
        um = (u0 + u1) * 0.5
        inside = F.p(um, (v0 + v1) * 0.5, side * (d0 - 0.25))
        bm = self.stone

        def c(p):
            return self.tone(p, F.n(um) * side, base, tint)
        for i in range(nu):
            for quad in ((in_b[i], in_b[i + 1], in_t[i + 1], in_t[i]),
                         (rim_b[i], rim_b[i + 1], in_b[i + 1], in_b[i]), (in_t[i], in_t[i + 1], rim_t[i + 1], rim_t[i])):
                self.face(bm, list(quad), inside, [c(p) for p in quad], uvo, smooth=False)
        for (rb, rt, ib, it) in ((rim_b[0], rim_t[0], in_b[0], in_t[0]), (rim_b[-1], rim_t[-1], in_b[-1], in_t[-1])):
            quad = [rb, ib, it, rt]
            self.face(bm, quad, inside, [c(p) for p in quad], uvo, smooth=False)
        self.n_stones += 1

    # ---------------------------------------------------------------- a dressed block (voussoirs, merlons, steps, rubble)
    def block(self, c, size, yaw=0.0, pitch=0.0, roll=0.0, bevel=0.05, warp=0.0, tone=None, rnd=None):
        rnd = rnd or self.rnd
        tmp = bmesh.new()
        bmesh.ops.create_cube(tmp, size=1.0)
        for v in tmp.verts:
            v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
        bv = min(bevel, min(size) * 0.3)
        if bv > 0.004:
            bmesh.ops.bevel(tmp, geom=list(tmp.edges), offset=bv, segments=1, affect='EDGES')
        if warp > 0.0:
            s = rnd.random() * 40.0
            for v in tmp.verts:
                v.co += Vector((noise.noise(v.co * 2.1 + Vector((s, 0, 0))), noise.noise(v.co * 2.1 + Vector((0, s, 0))),
                                noise.noise(v.co * 2.1 + Vector((0, 0, s))))) * warp
        M = Matrix.Translation(Vector(c)) @ Matrix.Rotation(yaw, 4, 'Z') @ Matrix.Rotation(pitch, 4, 'X') @ Matrix.Rotation(roll, 4, 'Y')
        base = tone if tone is not None else rnd.uniform(0.72, 1.0)
        warm = rnd.uniform(-0.05, 0.05)
        tint = (1.0 + warm, 1.0, 1.0 - warm * 1.4)
        uvo = (rnd.random(), rnd.random())
        tmp.normal_update()
        R = M.to_3x3()
        ctr = Vector(c)
        for f in tmp.faces:
            cos = [M @ v.co for v in f.verts]
            n = (R @ f.normal).normalized()
            self.face(self.stone, cos, ctr, [self.tone(p, n, base, tint) for p in cos], uvo, smooth=False)
        tmp.free()
        self.n_stones += 1

    def hexa(self, corners, bevel=0.04, tone=None, rnd=None):
        """A dressed stone of any six-sided shape (a voussoir, a wedge of a flyer): corners = the front four then the
        back four in the same order; chamfered edges, its own tone."""
        rnd = rnd or self.rnd
        tmp = bmesh.new()
        vs = [tmp.verts.new(Vector(c)) for c in corners]
        for idx in ((0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)):
            try:
                tmp.faces.new([vs[i] for i in idx])
            except ValueError:
                pass
        bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces)
        if bevel > 0.004:
            short = min(e.calc_length() for e in tmp.edges)
            bv = min(bevel, short * 0.3)
            if bv > 0.004:
                bmesh.ops.bevel(tmp, geom=list(tmp.edges), offset=bv, segments=1, affect='EDGES')
        ctr = sum((Vector(c) for c in corners), Vector()) / 8.0
        base = tone if tone is not None else rnd.uniform(0.74, 0.95)
        warm = rnd.uniform(0.0, 0.06)
        tint = (1.0 + warm, 1.0, 0.94 - warm * 1.2)
        uvo = (rnd.random(), rnd.random())
        tmp.normal_update()
        for f in tmp.faces:
            cos = [v.co.copy() for v in f.verts]
            n = f.normal.copy()
            self.face(self.stone, cos, ctr, [self.tone(p, n, base, tint) for p in cos], uvo)
        tmp.free()
        self.n_stones += 1

    def lump(self, c, size, rnd=None, tone=0.62):
        """A fallen chunk of core: a squashed, noise-displaced ball (rubble on the breaks and the floors)."""
        rnd = rnd or self.rnd
        tmp = bmesh.new()
        bmesh.ops.create_icosphere(tmp, subdivisions=1, radius=1.0)
        s = rnd.random() * 50.0
        for v in tmp.verts:
            k = 1.0 + 0.35 * noise.noise(v.co * 1.8 + Vector((s, 0, 0)))
            v.co = Vector((v.co.x * size[0] * k, v.co.y * size[1] * k, v.co.z * size[2] * k))
        M = Matrix.Translation(Vector(c)) @ Matrix.Rotation(rnd.random() * 6.28, 4, 'Z')
        ctr = Vector(c)
        for f in tmp.faces:
            cos = [M @ v.co for v in f.verts]
            self.face(self.core, cos, ctr, [self.tone(p, Vector((0, 0, 1)), tone, (1.0, 0.98, 0.95)) for p in cos])
        tmp.free()

    # ---------------------------------------------------------------- a whole wall
    def wall(self, F, half, h, solid, rnd, u_range=None, ch=0.55, blk=(0.8, 1.7), skip_below=0.0, faces=(1, -1),
             lose=0.012, cw=0.5, dress_ends=False):
        """Core and facing for a wall on frame F: thickness 2*half, height h (v from 0 at F's foot), solid(u, v) the mask
        (u in F's own [0, L], clamped). u_range: (us, ue) to lay over (ends past the frame extend into the next wall).
        Facing below v = skip_below (buried) is left out; `faces` which sides get stones."""
        us, ue = u_range if u_range else (0.0, F.L)

        def S(u, v):
            return solid(min(max(u, 0.0), F.L), v)
        jambs = self.core_wall(F, half, h, S, us, ue, cw)
        # courses: shared by both faces (a wall's courses run through), stones laid independently per face
        n = max(1, int(h / ch + 0.5))
        hs = [ch * rnd.uniform(0.82, 1.2) for _ in range(n)]
        if rnd.random() < 0.6 and n > 4:
            for k in range(rnd.randint(1, max(1, n // 6))):
                j = rnd.randrange(1, n - 1)
                hs[j] *= 0.45                                   # a thin levelling course here and there
        sc = h / sum(hs)
        hs = [x * sc for x in hs]
        gap = 0.012

        def col_ok(u, va, vb):
            return S(u, va + (vb - va) * 0.12) and S(u, (va + vb) * 0.5) and S(u, vb - 0.02)

        def fit(a0, a1, va, vb):
            """The solid runs of [a0, a1] at this course (a stone cut to an opening's or a break's edge)."""
            m = max(2, int((a1 - a0) / 0.08))
            runs, st = [], None
            for i in range(m + 1):
                u = a0 + (a1 - a0) * i / m
                ok = col_ok(u, va, vb)
                if ok and st is None:
                    st = u
                if (not ok or i == m) and st is not None:
                    e = u if ok else a0 + (a1 - a0) * (i - 0.5) / m
                    if e - st >= 0.22:
                        runs.append((st, e))
                    st = None
            return runs
        for side in faces:
            v = 0.0
            for j, chj in enumerate(hs):
                va, vb = v, v + chj
                v = vb
                if vb <= skip_below:
                    continue
                u = us - rnd.uniform(0.0, blk[0])
                while u < ue - 0.05:
                    ln = rnd.uniform(*blk)
                    if rnd.random() < 0.12:
                        ln *= 0.5                                # a closer: a short stone
                    a0, a1 = max(u, us), min(u + ln, ue)
                    u += ln
                    if a1 - a0 < 0.22:
                        continue
                    runs = fit(a0, a1, va, vb)
                    if not runs:
                        vm = va + chj * 0.55                     # the top course of a break: a stone of half height
                        for (r0, r1) in fit(a0, a1, va, vm):
                            self.tile(F, r0 + gap, r1 - gap, va + gap, vm - gap, side, half, rnd)
                        continue
                    if rnd.random() < lose and vb < h - 0.3 and len(runs) == 1 and runs[0] == (a0, a1):
                        continue                                 # a stone fallen from the face
                    for (r0, r1) in runs:
                        self.tile(F, r0 + gap, r1 - gap, va + gap, vb - gap, side, half, rnd)
        # the reveals of openings and the wall's free ends: dressed stones across the thickness, course by course
        bounds = [0.0]
        for x in hs:
            bounds.append(bounds[-1] + x)
        n0 = self.n_stones
        for (u, x0, x1, dirn) in jambs:
            if (abs(u - us) < 1e-6 or abs(u - ue) < 1e-6) and not dress_ends:
                continue
            if x1 - x0 < 0.3:
                continue                                         # a step in a broken top: the core's own edge
            J = JambFrame(F, u, half, dirn)
            for j in range(len(hs)):
                va, vb = max(bounds[j], x0), min(bounds[j + 1], x1)
                if vb - va < 0.12 or vb <= skip_below:
                    continue
                cuts = [0.0, 2 * half] if 2 * half < 1.25 else ([0.0, half * (0.8 if j % 2 else 1.2), 2 * half])
                for k in range(len(cuts) - 1):
                    self.tile(J, cuts[k] + gap, cuts[k + 1] - gap, va + gap, vb - gap, 1, 0.0, rnd)
        self.jamb_stones += self.n_stones - n0

    def core_wall(self, F, half, h, S, us, ue, cw):
        """The core: columns cw wide, each an extruded strip per solid interval, jambs where neighbours differ."""
        ncol = max(1, int(math.ceil((ue - us) / cw)))
        edges = [us + (ue - us) * i / ncol for i in range(ncol + 1)]
        dv = 0.08
        nv = int(math.ceil(h / dv))

        def intervals(u):
            out = []
            a = None
            for i in range(nv + 1):
                v = min(i * dv, h)
                s = S(u, v)
                if s and a is None:
                    a = v
                if not s and a is not None:
                    out.append([a, v - dv * 0.5])
                    a = None
            if a is not None:
                out.append([a, h])
            return [iv for iv in out if iv[1] - iv[0] > 0.05]

        def refine(u, v, want_top, window=0.9):
            """The nearest boundary to v at u of the same kind (a top: solid below, empty above), else v."""
            best = None
            k = 0
            while k * 0.04 <= window:
                for vv in ((v + k * 0.04, v - k * 0.04) if k else (v,)):
                    if vv < 0.0 or vv > h:
                        continue
                    lo, hi = S(u, vv - 0.02), S(u, vv + 0.02)
                    if (want_top and lo and not hi) or (not want_top and hi and not lo):
                        best = vv
                        break
                if best is not None:
                    break
                k += 1
            return v if best is None else best

        cols = []
        for i in range(ncol):
            ul, ur = edges[i], edges[i + 1]
            ivs = intervals((ul + ur) * 0.5)
            spans = []
            for (a, b) in ivs:
                al = 0.0 if a <= 0.0 else refine(ul, a, False)
                ar = 0.0 if a <= 0.0 else refine(ur, a, False)
                bl = h if b >= h else refine(ul, b, True)
                br = h if b >= h else refine(ur, b, True)
                spans.append((al, ar, max(bl, al + 0.02), max(br, ar + 0.02)))
            cols.append(spans)
        bm = self.core

        def ct(p, n):
            k, moss = self.weather(p, n)
            g = 0.6 + 0.1 * noise.noise(p * 1.7)
            r, gg, b = g * k, g * 0.97 * k, g * 0.93 * k
            return (r + (0.4 - r) * moss * 0.7, gg + (0.5 - gg) * moss * 0.7, b + (0.26 - b) * moss * 0.7, 1.0)

        def rough(p, amt):
            return p + Vector((noise.noise(p * 2.3), noise.noise(p * 2.3 + Vector((5, 0, 0))), noise.noise(p * 2.3 + Vector((0, 5, 0))))) * amt

        for i, spans in enumerate(cols):
            ul, ur = edges[i], edges[i + 1]
            um = (ul + ur) * 0.5
            for (al, ar, bl, br) in spans:
                mid = F.p(um, (al + ar + bl + br) * 0.25, 0.0)
                for side in (1, -1):
                    q = [F.p(ul, al, side * half), F.p(ur, ar, side * half), F.p(ur, br, side * half), F.p(ul, bl, side * half)]
                    self.face(bm, q, mid, [ct(p, F.n(um) * side) for p in q])
                # the top: broken fill, a ridge of rubble along its middle
                if bl < h - 0.01 or br < h - 0.01:
                    tl, tr = F.p(ul, bl, half), F.p(ur, br, half)
                    bl_, br_ = F.p(ul, bl, -half), F.p(ur, br, -half)
                    ml = rough(F.p(ul, bl + 0.12, 0.0), 0.08)
                    mr = rough(F.p(ur, br + 0.12, 0.0), 0.08)
                    for q in ((tl, tr, mr, ml), (ml, mr, br_, bl_)):
                        self.face(bm, list(q), mid, [ct(p, Vector((0, 0, 1))) for p in q])
                    if self.rnd.random() < 0.3 and 2 * half > 0.9:      # loose fill on the break
                        sz = self.rnd.uniform(0.18, 0.38)
                        tp = F.p(um, (bl + br) * 0.5 + sz * 0.3, self.rnd.uniform(-half, half) * 0.5)
                        self.lump(tp, (sz * 1.3, sz, sz * 0.7))
                else:
                    q = [F.p(ul, bl, half), F.p(ur, br, half), F.p(ur, br, -half), F.p(ul, bl, -half)]
                    self.face(bm, q, mid, [ct(p, Vector((0, 0, 1))) for p in q])
                if al > 0.01 or ar > 0.01:
                    q = [F.p(ul, al, half), F.p(ur, ar, half), F.p(ur, ar, -half), F.p(ul, al, -half)]
                    self.face(bm, q, mid, [ct(p, Vector((0, 0, -1))) for p in q])
        # jambs: on each column edge, where one side is solid and the other is not
        jambs = []
        for i in range(ncol + 1):
            u = edges[i]
            left = [(s[1], s[3]) for s in cols[i - 1]] if i > 0 else []
            right = [(s[0], s[2]) for s in cols[i]] if i < ncol else []
            for (A, B, dirn) in ((left, right, 1.0), (right, left, -1.0)):
                for (a, b) in A:
                    segs = [(a, b)]
                    for (c0, c1) in B:
                        nxt = []
                        for (x0, x1) in segs:
                            if c1 <= x0 or c0 >= x1:
                                nxt.append((x0, x1))
                                continue
                            if c0 > x0:
                                nxt.append((x0, c0))
                            if c1 < x1:
                                nxt.append((c1, x1))
                        segs = nxt
                    for (x0, x1) in segs:
                        if x1 - x0 < 0.02:
                            continue
                        q = [F.p(u, x0, half), F.p(u, x0, -half), F.p(u, x1, -half), F.p(u, x1, half)]
                        inside = F.p(u, (x0 + x1) * 0.5, 0.0) - F.t(u) * dirn
                        self.face(bm, q, inside, [ct(p, F.t(u) * dirn) for p in q])
                        jambs.append((u, x0, x1, dirn))
        return jambs

    # ---------------------------------------------------------------- objects
    def objects(self, name):
        """The two meshes as objects: <name>__hewn and <name>Core__stone."""
        out = []
        for bm, nm in ((self.stone, name + "__hewn"), (self.core, name + "Core__stone")):
            if len(bm.faces) == 0:
                bm.free()
                continue
            me = bpy.data.meshes.new(nm)
            bm.to_mesh(me)
            bm.free()
            m = bpy.data.materials.get(nm.split("__")[1]) or bpy.data.materials.new(nm.split("__")[1])
            me.materials.append(m)
            ob = bpy.data.objects.new(nm, me)
            bpy.context.scene.collection.objects.link(ob)
            if "Col" in me.color_attributes:
                me.color_attributes.active_color = me.color_attributes["Col"]
                me.color_attributes.render_color_index = list(me.color_attributes.keys()).index("Col")
            out.append(ob)
        print("MASON %s: %d stones (%d in reveals)" % (name, self.n_stones, self.jamb_stones))
        return out
