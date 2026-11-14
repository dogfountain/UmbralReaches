"""The March Wall kit's masonry helpers (tools/blender/r37_wall.py): one mesh builder that knows how a wall is made.

Everything is in GODOT coordinates (x right, y up, z towards the viewer), 1 unit = 1 m, like r37_south_lib.

  W            a B (r37_south_lib) with per-stone tints and a weathering pass written as vertex colours at finish
  W.prism_x    a closed profile (z, y) pulled along x: battered footings, string courses, buttresses
  W.frustum    a rectangular or round tower shaft whose faces slope in
  W.poly_z     a convex outline (x, y) pulled along z: voussoirs, keystones, shields
  W.battlement a parapet that oversails on stepped corbels, with crenels and merlons, along any run of lines and arcs
  W.arch       a pointed (two-centred) arch of voussoirs
"""
import math
import bmesh
from mathutils import Vector, Matrix
import r37_south_lib as L
from r37_south_lib import B, hash3


def rng(seed):
    import random
    return random.Random(seed)


def clamp(v, lo, hi):
    return lo if v < lo else (hi if v > hi else v)


def lerp(a, b, t):
    return a + (b - a) * t


def smooth(t):
    t = clamp(t, 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


# ---- the weathering written into vertex colours (the engine multiplies them into the albedo) ------------------------

def weather(p, seed, damp=1.0):
    """A tint for a point of the wall: damp, green stone at the foot, soot under the corbels, warm repaired patches
    wandering over the face, pale rain streaks. Values stay under 1 (the engine cannot brighten with a vertex colour)."""
    x, y, z = p
    n1 = hash3(x * 0.55, y * 0.6, z * 0.55, seed)                 # broad patches
    n2 = hash3(x * 2.3, y * 0.15, z * 2.3, seed + 5)              # vertical streaks
    n3 = hash3(x * 1.4, y * 1.4, z * 1.4, seed + 9)               # blocks
    r = g = b = 0.93 + 0.07 * n3
    # damp at the foot
    d = clamp(1.0 - y / 2.1, 0.0, 1.0) * damp
    k = 1.0 - 0.34 * d * (0.7 + 0.5 * n3)
    r *= k * (1.0 - 0.07 * d)
    g *= k
    b *= k * (1.0 - 0.14 * d)
    # moss in the lowest joints
    m = clamp(1.0 - y / 0.9, 0.0, 1.0) * damp * smooth(0.5 + n1 * 1.6)
    r *= 1.0 - 0.2 * m
    b *= 1.0 - 0.38 * m
    # warm repaired patches (a different quarry)
    w = smooth((n1 - 0.12) * 3.2)
    r *= 1.0 - 0.0 * w
    g *= 1.0 - 0.05 * w
    b *= 1.0 - 0.17 * w
    # rain streaks
    s = smooth((n2 - 0.1) * 3.0)
    k = 1.0 - 0.13 * s
    return (r * k, g * k, b * k)


class W(B):
    def __init__(self, name, mats, seed=0, weather_seed=None, damp=1.0):
        super().__init__(name, mats)
        self.ft = {}
        self.wseed = seed if weather_seed is None else weather_seed
        self.damp = damp
        self.tint0 = None

    # -- boxes ------------------------------------------------------------------------------------------------------
    def box(self, c, size, mat="stone", uv=1.0, tint=None, cuts=None, jit=None, **kw):
        m = max(size)
        if cuts is None:
            cuts = 0 if m < 0.9 else min(4, int(m / 1.25))
        if jit is None:
            jit = 0.0 if mat in ("dark", "iron") else min(0.04, 0.012 + 0.008 * m)
        faces = B.box(self, c, size, mat, scale_uv=0.16 * uv, cuts=cuts, jit=jit, **kw)
        if tint is not None:
            for f in faces:
                self.ft[f] = tint
        return faces

    # -- solids made from rings ---------------------------------------------------------------------------------------
    def _solid(self, rings, mat, uv, tint, jit, seed, fixed=()):
        bm = self.bm
        n0 = len(bm.verts)
        faces = self.loft(rings, mat, closed=True, cap_start=True, cap_end=True, smooth=False, box_uv=0.16 * uv * float(self.mats[mat].get("uv_mul", 1.0)))
        bm.verts.ensure_lookup_table()
        new = bm.verts[n0:]
        bmesh.ops.recalc_face_normals(bm, faces=faces)
        if jit > 0.0:
            ends = set()
            for ri in (0, len(rings) - 1):
                for p in rings[ri]:
                    ends.add((round(p[0], 4), round(p[1], 4), round(p[2], 4)))
            for v in new:
                key = (round(v.co.x, 4), round(v.co.y, 4), round(v.co.z, 4))
                if key in ends:
                    continue
                co = Vector(v.co)
                v.co = co + Vector((hash3(co.x, co.y, co.z, seed), hash3(co.x + 9, co.y, co.z, seed), hash3(co.x, co.y + 9, co.z, seed))) * jit
        if tint is not None:
            for f in faces:
                self.ft[f] = tint
        return faces

    def prism_x(self, prof, x0, x1, mat="stone", uv=1.0, tint=None, jit=0.04, seed=0, dens=1.3, xstep=1.5):
        """A closed profile of (z, y) points pulled along x from x0 to x1."""
        dense = []
        n = len(prof)
        for i in range(n):
            a = Vector(prof[i])
            b = Vector(prof[(i + 1) % n])
            m = max(1, int(math.ceil((b - a).length / dens)))
            for k in range(m):
                dense.append(a.lerp(b, k / m))
        nx = max(1, int(math.ceil(abs(x1 - x0) / xstep)))
        rings = [[Vector((x0 + (x1 - x0) * i / nx, p.y, p.x)) for p in dense] for i in range(nx + 1)]
        return self._solid(rings, mat, uv, tint, jit, seed)

    def frustum(self, cx, cz, h0, h1, y0, y1, mat="stone", uv=1.0, tint=None, jit=0.04, seed=0, levels=None, round_n=0, edge=1.25, cx1=None):
        """A tower shaft from y0 to y1. h0 / h1 = half sizes (hx, hz) at the foot and the top, or a radius for
        round_n > 0 (a drum with that many sides). levels = how many rings."""
        if not isinstance(h0, (tuple, list)):
            h0 = (h0, h0)
            h1 = (h1, h1)
        nlev = levels if levels else max(2, int(math.ceil((y1 - y0) / 1.5)) + 1)
        rings = []
        nn = max(2, int(math.ceil(2 * max(h0[0], h0[1], h1[0], h1[1]) / edge)))
        for i in range(nlev):
            t = i / (nlev - 1)
            y = lerp(y0, y1, t)
            hx = lerp(h0[0], h1[0], t)
            hz = lerp(h0[1], h1[1], t)
            ring = []
            cxl = cx if cx1 is None else lerp(cx, cx1, t)
            if round_n:
                for j in range(round_n):
                    a = -math.tau * j / round_n
                    ring.append(Vector((cxl + math.cos(a) * hx, y, cz + math.sin(a) * hz)))
            else:
                for i2 in range(nn):
                    ring.append(Vector((cx - hx + 2 * hx * i2 / nn, y, cz - hz)))
                for i2 in range(nn):
                    ring.append(Vector((cx + hx, y, cz - hz + 2 * hz * i2 / nn)))
                for i2 in range(nn):
                    ring.append(Vector((cx + hx - 2 * hx * i2 / nn, y, cz + hz)))
                for i2 in range(nn):
                    ring.append(Vector((cx - hx, y, cz + hz - 2 * hz * i2 / nn)))
            rings.append(ring)
        return self._solid(rings, mat, uv, tint, jit, seed)

    def rect_solid(self, x0, x1, z0, z1, y0, y1, bat=(0.0, 0.0, 0.0, 0.0), foot=None, mat="stone", uv=1.0, tint=None, jit=0.04, seed=0, edge=1.25):
        """A block from y0 to y1 whose sides lean in towards the top by bat = (-x, +x, -z, +z) metres in all; foot = extra metres
        out at the bottom on the same four sides (a battered plinth: foot > 0 and bat > 0)."""
        foot = foot or (0.0, 0.0, 0.0, 0.0)
        nlev = max(2, int(math.ceil((y1 - y0) / 1.5)) + 1)
        nx = max(2, int(math.ceil((x1 - x0) / edge)))
        nz = max(2, int(math.ceil((z1 - z0) / edge)))
        rings = []
        for i in range(nlev):
            t = i / (nlev - 1)
            y = lerp(y0, y1, t)
            xa = x0 - foot[0] * (1 - t) + bat[0] * t
            xb = x1 + foot[1] * (1 - t) - bat[1] * t
            za = z0 - foot[2] * (1 - t) + bat[2] * t
            zb = z1 + foot[3] * (1 - t) - bat[3] * t
            ring = []
            for k in range(nx):
                ring.append(Vector((xa + (xb - xa) * k / nx, y, za)))
            for k in range(nz):
                ring.append(Vector((xb, y, za + (zb - za) * k / nz)))
            for k in range(nx):
                ring.append(Vector((xb - (xb - xa) * k / nx, y, zb)))
            for k in range(nz):
                ring.append(Vector((xa, y, zb - (zb - za) * k / nz)))
            rings.append(ring)
        return self._solid(rings, mat, uv, tint, jit, seed)

    def poly_z(self, pts, z0, z1, mat="stone", uv=1.0, tint=None, jit=0.0, seed=0):
        """A closed outline of (x, y) points pulled along z from z0 to z1 (a voussoir, a keystone, a shield)."""
        bm = self.bm
        fr = [bm.verts.new(Vector((p[0], p[1], z1))) for p in pts]
        bk = [bm.verts.new(Vector((p[0], p[1], z0))) for p in pts]
        n = len(pts)
        faces = []
        for i in range(n):
            j = (i + 1) % n
            try:
                faces.append(bm.faces.new([fr[i], bk[i], bk[j], fr[j]]))
            except ValueError:
                pass
        for loop in (fr, list(reversed(bk))):
            try:
                faces.append(bm.faces.new(loop))
            except ValueError:
                pass
        bmesh.ops.recalc_face_normals(bm, faces=faces)
        if jit > 0.0:
            for v in fr + bk:
                co = Vector(v.co)
                v.co = co + Vector((hash3(co.x, co.y, co.z, seed), hash3(co.x + 9, co.y, co.z, seed), hash3(co.x, co.y + 9, co.z, seed))) * jit
        for f in faces:
            f.material_index = self.keys.index(mat)
            f.smooth = False
        self._box_uv(faces, 0.16 * uv * float(self.mats[mat].get("uv_mul", 1.0)), ((z0 * 3.1 + pts[0][0] * 5.7) % 1.0, (pts[0][1] * 2.3) % 1.0))
        if tint is not None:
            for f in faces:
                self.ft[f] = tint
        return faces

    # -- a pointed arch of voussoirs ---------------------------------------------------------------------------------
    def arch(self, cx, y0, w, t, z0, z1, mat="stone", uv=1.0, n=7, tint=None, seed=0, jit=0.012, alt=0.0, span=None, fill=False):
        """Voussoirs of thickness t round a pointed opening about the springing line y0: two arcs of radius w whose centres
        stand span (default w) apart, so a rib (smaller w, the same span) rises inside the vault it hugs. Over z0..z1.
        alt = every other stone a little deeper (a bonded ring). Returns the crown (x, y) of the intrados."""
        span = w if span is None else span
        th_end = math.acos(-(span / 2) / w)
        for side in (0, 1):
            for i in range(n):
                th0 = math.pi - (math.pi - th_end) * i / n
                th1 = math.pi - (math.pi - th_end) * (i + 1) / n
                sg = 1.0 if side == 0 else -1.0
                ctr = cx + sg * span / 2
                def P(r, th, ctr=ctr, sg=sg):
                    return (ctr + sg * r * math.cos(th), y0 + r * math.sin(th))
                if side == 0:
                    pts = [P(w, th0), P(w + t, th0), P(w + t, th1), P(w, th1)]
                else:
                    pts = [P(w, th0), P(w, th1), P(w + t, th1), P(w + t, th0)]
                dz = alt if (i % 2 == 1) else 0.0
                self.poly_z(pts, z0 - dz, z1 + dz, mat, uv, tint, jit, seed + i + side * 20)
        return (cx, y0 + math.sqrt(w * w - (span / 2) ** 2))

    # -- a parapet on corbels along a run ----------------------------------------------------------------------------
    def battlement(self, runs, y0, centre, seed=0, skip=(), oversail=0.58, sill=1.05, mh=0.95, mw=1.3, tint=None, corbels=True, pitch=2.1,
                   gaps=(), mer_tint=None, ends_merlon=False, csteps=None, cspace=1.3):
        """A corbel table, an oversailing parapet and its merlons along runs of the wall's face line at y0 (the corbels' base).
        A run is ("line", (x0, z0), (x1, z1)) or ("arc", (cx, cz), r, a0, a1) (angles in radians, x = cx + r cos a, z = cz + r sin a).
        centre = a point inside the wall (the side the corbels do not project to). Returns the walk's height.
        gaps = ((run index, s0, s1), ...) stretches along a run (metres) left without parapet or corbels (a door)."""
        walk = y0 + 1.2
        mi = 0
        for ri, run in enumerate(runs):
            if run[0] == "line":
                p0 = Vector((run[1][0], run[1][1]))
                p1 = Vector((run[2][0], run[2][1]))
                Lr = (p1 - p0).length

                def at(s, p0=p0, p1=p1, Lr=Lr):
                    d = (p1 - p0) / Lr
                    return p0 + d * s, d
            else:
                c = Vector(run[1])
                r = run[2]
                a0 = run[3]
                a1 = run[4]
                Lr = abs(a1 - a0) * r

                def at(s, c=c, r=r, a0=a0, a1=a1, Lr=Lr):
                    a = a0 + (a1 - a0) * (s / Lr)
                    sg = 1.0 if a1 > a0 else -1.0
                    return c + Vector((math.cos(a), math.sin(a))) * r, Vector((-math.sin(a) * sg, math.cos(a) * sg))
            gs = [(g[1], g[2]) for g in gaps if g[0] == ri]

            def in_gap(s, w=0.0, gs=gs):
                for a, b in gs:
                    if s + w > a and s - w < b:
                        return True
                return False

            def place(s, d_unused=None, run_at=at):
                p, d = run_at(s)
                n = Vector((-d.y, d.x))
                if n.dot(p - Vector(centre)) < 0:
                    n = -n
                yaw = math.atan2(-d.y, d.x)
                return p, d, n, yaw

            def put(s, along, off, ya, yb, wdt, thick, mat="stone", t=None, uvm=1.2, jitm=0.012, run_place=place):
                p, d, n, yaw = run_place(s)
                c = p + d * along + n * off
                self.box((c.x, (ya + yb) / 2, c.y), (wdt, yb - ya, thick), mat, uv=uvm, tint=t if t is not None else tint, yaw=yaw, cuts=0, jit=jitm, seed=seed + mi)

            # corbels: three steps, evenly along the run
            if corbels:
                m = max(1, int(round((Lr - 0.3) / cspace)))
                for i in range(m):
                    s = (i + 0.5) * Lr / m
                    if in_gap(s, 0.4):
                        continue
                    for (ya, yb, pr) in (csteps or ((0.0, 0.32, 0.2), (0.32, 0.62, 0.38), (0.62, 0.9, 0.56))):
                        put(s, 0.0, pr / 2, y0 + ya, y0 + yb, 0.56 - pr * 0.18, pr, uvm=1.5, jitm=0.01)
            # the table, a slab, then the parapet
            segs = max(1, int(math.ceil(Lr / (1.6 if run[0] == 'line' else 0.9))))
            for i in range(segs):
                s0 = Lr * i / segs
                s1 = Lr * (i + 1) / segs
                sm = (s0 + s1) / 2
                if in_gap(sm, (s1 - s0) / 2 - 0.01):
                    continue
                ext = 0.0
                if run[0] == "arc":
                    ext = 0.0
                put(sm, 0.0, oversail / 2 - 0.02, y0 + 0.9, walk, (s1 - s0) + 0.06, oversail + 0.02, uvm=1.4, t=tint)
                put(sm, 0.0, oversail - 0.3, walk, walk + sill, (s1 - s0) + 0.05, 0.6, uvm=1.2)
            # merlons
            if run[0] == "line":
                nm = max(1, int(round(Lr / pitch)))
                if ends_merlon:
                    nm = max(2, int((Lr - mw) / (mw + 0.7)) + 1)
                for i in range(nm):
                    s = (i + 0.5) * Lr / nm if not ends_merlon else mw / 2 + i * (Lr - mw) / max(nm - 1, 1)
                    if mi in skip or in_gap(s, mw / 2):
                        mi += 1
                        continue
                    w_ = mw if not ends_merlon else mw
                    put(s, 0.0, oversail - 0.3, walk + sill, walk + sill + mh, w_, 0.6, uvm=1.3, t=mer_tint, jitm=0.014)
                    put(s, 0.0, oversail - 0.3, walk + sill + mh, walk + sill + mh + 0.12, w_ + 0.14, 0.72, uvm=1.5, t=mer_tint, jitm=0.01)
                    mi += 1
            else:
                nm = max(2, int(round(Lr / pitch)))
                for i in range(nm):
                    s = (i + 0.5) * Lr / nm
                    if mi in skip or in_gap(s, mw / 2):
                        mi += 1
                        continue
                    put(s, 0.0, oversail - 0.3, walk + sill, walk + sill + mh, mw * 0.92, 0.6, uvm=1.3, t=mer_tint, jitm=0.014)
                    put(s, 0.0, oversail - 0.3, walk + sill + mh, walk + sill + mh + 0.12, mw * 0.92 + 0.14, 0.72, uvm=1.5, t=mer_tint, jitm=0.01)
                    mi += 1
        return walk

    # -- finishing: the weathering pass ------------------------------------------------------------------------------
    def finish(self, collection=None, merge=True, recalc=False):
        bm = self.bm
        lay = bm.loops.layers.float_color.new("Col")
        for f in bm.faces:
            base = self.ft.get(f)
            if base is None:
                base = (1.0, 1.0, 1.0)
            for lp in f.loops:
                co = lp.vert.co
                w = weather((co.x, co.y, co.z), self.wseed, self.damp)
                lp[lay] = (base[0] * w[0], base[1] * w[1], base[2] * w[2], 1.0)
        ob = B.finish(self, collection, merge, recalc)
        try:
            ob.data.color_attributes.active_color = ob.data.color_attributes["Col"]
        except Exception:
            pass
        return ob


def clay_preview(path, objs, look_at, dist, views, res=(1200, 800), lens=35, clay=False, hide=()):
    import bpy
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_WORKBENCH'
    sc.display.shading.light = 'STUDIO'
    sc.display.shading.color_type = 'SINGLE' if clay else 'TEXTURE'
    sc.display.shading.single_color = (0.62, 0.6, 0.56)
    sc.render.resolution_x, sc.render.resolution_y = res
    cam = bpy.data.objects.get("Cam")
    if cam is None:
        cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
        sc.collection.objects.link(cam)
    cam.data.lens = lens
    cam.data.clip_end = 2000
    sc.camera = cam
    for i, v in enumerate(views):
        az, el = v[0], v[1]
        tgt_d = v[2] if len(v) > 2 else dist
        a = math.radians(az)
        pos = Vector((look_at[0] + math.sin(a) * tgt_d * math.cos(el), -(look_at[2] + math.cos(a) * tgt_d * math.cos(el)), look_at[1] + tgt_d * math.sin(el)))
        tgt = L.G(look_at)
        cam.location = pos
        cam.rotation_euler = (tgt - pos).to_track_quat('-Z', 'Y').to_euler()
        sc.render.filepath = path.replace(".png", "_%d.png" % i)
        bpy.ops.render.render(write_still=True)
        print("PREVIEW", sc.render.filepath)
