"""Bosses built the way the wanderer is built: clean garment geometry and hard shapes, laid out for TILING
materials (the wanderer's own wool, embroidered band, leather, iron and wood), tinted by vertex colour, with glow
painted into the mesh. No sculpted blobs, no baked atlas. Faces are masks, plates and voids with lit eyes.

boss_humanoid_anim.py imports this (--built) in place of the baked body: build(name) returns the body object,
labelled with the old socket names so the same skinning and the same authored clips carry it, and the things held.

Rig space: x right, y up, z back, facing -Z, metres at scale 1. Surfaces are named by material (boss_look.gd):
wool, linen, trim, leather, bone, gilt, iron, wood, glow.  Vertex colour = tint; alpha 0 = glows.
UV: metres (u round or along, v up), except trim bands: u metres along, v 0..1 across.
"""
import bpy
import os
import math
import numpy as np
from mathutils import Vector

TAU = math.tau
## surface layers, in the order core/enemy/boss_look.gd reads them
LAYERS = ["wool", "linen", "trim", "leather", "bone", "gilt", "iron", "wood", "stone", "glow", "skin"]


def V(x, y, z):
    return np.array([x, y, z], dtype=np.float64)


class Geo:
    """Vertices, faces, colours, UVs and skin labels gathered part by part, then made one mesh."""

    def __init__(self):
        self.v, self.col, self.uv, self.lab, self.faces, self.fmat = [], [], [], [], [], []
        self.fuv = {}                      # face index -> per-corner UVs (a finished mesh's own unwrap, seams kept)

    def vert(self, p, col, uv, lab):
        self.v.append(np.asarray(p, dtype=np.float64))
        self.col.append(col if len(col) == 4 else (col[0], col[1], col[2], 1.0))
        self.uv.append(uv)
        self.lab.append(lab)
        return len(self.v) - 1

    def grid(self, P, col, mat, lab, uv=None, wrap=False, flip=False):
        """P[i][j] points; quads between rows i and columns j. lab: name or fn(point). uv: fn(i, j, point)."""
        ni, nj = len(P), len(P[0])
        ids = [[0] * nj for _ in range(ni)]
        for i in range(ni):
            for j in range(nj):
                p = P[i][j]
                c = col(i, j, p) if callable(col) else col
                ids[i][j] = self.vert(p, c, uv(i, j, p) if uv else (float(j), float(i)), lab(p) if callable(lab) else lab)
        for i in range(ni - 1):
            for j in range(nj if wrap else nj - 1):
                j2 = (j + 1) % nj
                q = [ids[i][j], ids[i][j2], ids[i + 1][j2], ids[i + 1][j]]
                self.faces.append(q[::-1] if flip else q)
                self.fmat.append(mat)
        return ids

    # --- shapes ---------------------------------------------------------------------------------------
    def robe(self, rings, col, mat, lab, n=96, t0=0.0, t1=TAU, pleats=0, pleat_amp=0.0, pleat_from=None, hem_break=0.0, flip=False, tatter=0.0):
        """A hanging garment: rings = [(y, rx, rz, cz)] top to bottom (rx across, rz deep, cz centre z).
        Open between t0..t1 (0 = front, clockwise from above) or closed all round. Pleats deepen from
        `pleat_from` (y) down to the hem; `hem_break` throws the last ring's folds onto the floor."""
        closed = abs((t1 - t0) - TAU) < 1e-6
        nj = n if closed else n + 1
        P = []
        top_y = rings[0][0]
        bot_y = rings[-1][0]
        pf = top_y if pleat_from is None else pleat_from
        arc = [0.0]
        for i, (y, rx, rz, cz) in enumerate(rings):
            row = []
            depth = min(max((pf - y) / max(pf - bot_y, 1e-6), 0.0), 1.0)
            for j in range(nj):
                th = t0 + (t1 - t0) * j / n
                fold = 0.0
                if pleats:
                    s = math.sin(th * pleats * 0.5)
                    fold = (1.0 - abs(s) ** 0.7) * 2.0 - 1.0          # sharp valleys, rounded crests
                    fold += 0.35 * math.sin(th * pleats * 1.37 + 1.3)   # no two folds the same
                k = 1.0 + pleat_amp * depth * fold
                x = math.sin(th) * rx * k
                z = -math.cos(th) * rz * k + cz
                yy = y
                if i == len(rings) - 1 and hem_break > 0.0:
                    yy = y + hem_break * max(0.0, fold) * 0.5
                if i == len(rings) - 1 and tatter > 0.0:                   # a torn hem: long rags and short, none alike
                    h = math.sin(j * 12.9898) * 43758.5453
                    h = h - math.floor(h)
                    yy = y + tatter * (h ** 2.0) * (1.0 if j % 3 else 0.25)
                row.append(V(x, yy, z))
            P.append(row)
        mean_r = [0.5 * (r[1] + r[2]) for r in rings]

        def uv(i, j, p):
            return ((t0 + (t1 - t0) * j / n) * mean_r[min(i, len(mean_r) - 1)] * 0.9 + 0.31 * i * 0.0, p[1])
        self.grid(P, col, mat, lab, uv, wrap=closed, flip=flip)
        return P

    def chain(self, path, col, mat, lab, link=0.045, wire=0.0065):
        """A chain along a path: links of round wire, each turned a quarter to the last, as forged links hang."""
        pts = [np.asarray(p, dtype=np.float64) for p in path]
        L = [0.0]
        for a, b in zip(pts, pts[1:]):
            L.append(L[-1] + float(np.linalg.norm(b - a)))
        k = 0
        d = 0.0
        while d < L[-1]:
            i = max(j for j in range(len(L)) if L[j] <= d)
            i = min(i, len(pts) - 2)
            t = (d - L[i]) / max(L[i + 1] - L[i], 1e-9)
            c = pts[i] + (pts[i + 1] - pts[i]) * t
            ax = pts[i + 1] - pts[i]
            ax /= max(np.linalg.norm(ax), 1e-9)
            up = V(0, 1.0, 0) if abs(ax[1]) < 0.9 else V(1.0, 0, 0)
            n1 = np.cross(ax, up)
            n1 /= np.linalg.norm(n1)
            if k % 2:
                n1 = np.cross(ax, n1)
            ring = [c + ax * math.cos(TAU * j / 10) * link * 0.62 + n1 * math.sin(TAU * j / 10) * link * 0.34 for j in range(11)]
            self.tube(ring, wire, col, mat, lab(c) if callable(lab) else lab, n=5)
            d += link * 0.82
            k += 1

    def band(self, path, width, col, mat, lab, out=0.006, up=None):
        """A trim strip along `path` (points on a surface), `width` across, lifted `out` along `up` normals."""
        P = []
        n = len(path)
        ln = 0.0
        us = []
        for k in range(n):
            if k:
                ln += float(np.linalg.norm(path[k] - path[k - 1]))
            us.append(ln)
        for side in (0, 1):
            row = []
            for k in range(n):
                a = path[max(k - 1, 0)]
                b = path[min(k + 1, n - 1)]
                tan = b - a
                tan /= max(np.linalg.norm(tan), 1e-9)
                nrm = up[k] if up is not None else V(0, 0, -1)
                acr = np.cross(tan, nrm)
                acr /= max(np.linalg.norm(acr), 1e-9)
                row.append(path[k] + nrm * out + acr * width * (side - 0.5))
            P.append(row)
        self.grid(P, col, mat, lab, lambda i, j, p: (us[j], float(i)))

    def ring_band(self, y0, y1, rx, rz, cz, col, mat, lab, n=96, t0=0.0, t1=TAU, fn=None):
        """A band round a garment between two heights; fn(th) scales the radius (to follow pleats)."""
        closed = abs((t1 - t0) - TAU) < 1e-6
        nj = n if closed else n + 1
        P = []
        for y in (y1, y0):
            row = []
            for j in range(nj):
                th = t0 + (t1 - t0) * j / n
                k = fn(th) if fn else 1.0
                row.append(V(math.sin(th) * rx * k, y, -math.cos(th) * rz * k + cz))
            P.append(row)
        r = 0.5 * (rx + rz)
        self.grid(P, col, mat, lab, lambda i, j, p: ((t0 + (t1 - t0) * j / n) * r, 1.0 - float(i)), wrap=closed)

    def lathe(self, prof, at, col, mat, lab, n=24, axis="y", squash=1.0, cap=True):
        """Turned shapes: prof = [(r, h)] along the axis from `at`."""
        P = []
        for (r, h) in prof:
            row = []
            for j in range(n):
                a = TAU * j / n
                if axis == "y":
                    row.append(at + V(math.cos(a) * r, h, math.sin(a) * r * squash))
                else:                                                     # along -Z (forward)
                    row.append(at + V(math.cos(a) * r, math.sin(a) * r * squash, -h))
            P.append(row)
        ids = self.grid(P, col, mat, lab, lambda i, j, p: (TAU * j / n * max(prof[i][0], 0.02), prof[i][1]), wrap=True, flip=(axis != "y"))
        return ids

    def tube(self, path, radii, col, mat, lab, n=10, flat=1.0):
        """A tube along a path (arms, fingers, a crook, a rope); its frame is carried along without twisting."""
        P = []
        ln = 0.0
        us = []
        u_prev = None
        for k, c in enumerate(path):
            a = path[max(k - 1, 0)]
            b = path[min(k + 1, len(path) - 1)]
            t = b - a
            t /= max(np.linalg.norm(t), 1e-9)
            if u_prev is None:
                ref = V(0, 0, 1) if abs(t[2]) < 0.9 else V(1, 0, 0)
                u = np.cross(t, ref)
            else:
                u = u_prev - t * float(t @ u_prev)
                if np.linalg.norm(u) < 1e-6:
                    u = np.cross(t, V(1, 0, 0))
            u /= max(np.linalg.norm(u), 1e-9)
            w = np.cross(t, u)
            u_prev = u
            r = radii[k] if hasattr(radii, "__len__") else radii
            P.append([c + (u * math.cos(TAU * j / n) + w * math.sin(TAU * j / n) * flat) * r for j in range(n)])
            if k:
                ln += float(np.linalg.norm(c - path[k - 1]))
            us.append(ln)
        rm = radii[0] if hasattr(radii, "__len__") else radii
        self.grid(P, col, mat, lab, lambda i, j, p: (TAU * j / n * rm, us[i]), wrap=True)

    def skin(self, nodes, edges, col, mat, lab, subdiv=2, smooth=0.5, crease=None):
        """An organic body as an artist blocks one out: a skeleton of points with radii, wrapped by Blender's Skin
        modifier into one quad mesh with clean loops, then subdivided (the base-mesh step of blockout -> sculpt ->
        retopology). nodes: [(point, rx, ry)] (rx across, ry deep); edges: [(i, j)]. lab: name or fn(point)."""
        me = bpy.data.meshes.new("skin")
        me.from_pydata([(p[0], -p[2], p[1]) for (p, rx, ry) in nodes], edges, [])
        ob = bpy.data.objects.new("skin", me)
        bpy.context.scene.collection.objects.link(ob)
        md = ob.modifiers.new("Skin", 'SKIN')
        md.use_smooth_shade = True
        md.branch_smoothing = smooth
        for i, (p, rx, ry) in enumerate(nodes):
            me.skin_vertices[0].data[i].radius = (rx, ry)
        me.skin_vertices[0].data[0].use_root = True
        sd = ob.modifiers.new("Sub", 'SUBSURF')
        sd.levels = subdiv
        sd.render_levels = subdiv
        dg = bpy.context.evaluated_depsgraph_get()
        ev = ob.evaluated_get(dg)
        m2 = ev.to_mesh()
        base = len(self.v)
        for v in m2.vertices:
            q = V(v.co.x, v.co.z, -v.co.y)
            c = col(0, 0, q) if callable(col) else col
            self.vert(q, c, (q[0] + q[2], q[1]), lab(q) if callable(lab) else lab)
        for poly in m2.polygons:
            self.faces.append([base + i for i in poly.vertices])
            self.fmat.append(mat)
        ev.to_mesh_clear()
        bpy.data.objects.remove(ob)

    def meta(self, elems, col, mat, lab, res=0.014, tris=8000, smooth=2):
        """A creature blocked out the way sculptors start one: muscle masses as metaballs that melt into each other
        (a keel of a chest, haunches, a neck), limbs as capsules, carved by negative masses; meshed, relaxed and
        decimated to `tris`. elems: ("e", centre, (rx, ry, rz)[, neg]) ellipsoids; ("c", a, b, r[, neg]) capsules.
        Sizes are the surface's own (metres). UVs are boxed per face so a tile lies flat on every side."""
        K = 1.0 / 0.57                                   # at threshold 0.6, stiffness 2: surface ~0.57 of the radius
        mb = bpy.data.metaballs.new("meta")
        mb.resolution = res
        mb.render_resolution = res
        mb.threshold = 0.6
        ob = bpy.data.objects.new("meta", mb)
        bpy.context.scene.collection.objects.link(ob)
        bl = lambda p: Vector((float(p[0]), float(-p[2]), float(p[1])))
        for e in elems:
            if e[0] == "e":
                el = mb.elements.new(type='ELLIPSOID')
                el.co = bl(e[1])
                rx, ry, rz = e[2]
                m = min(rx, ry, rz)
                el.radius = m * K
                el.size_x, el.size_y, el.size_z = rx / m, rz / m, ry / m
                neg = len(e) > 3 and e[3]
                if len(e) > 4 and e[4] is not None:                  # a turned mass: e[4] = the axis its ry (thin) lies along
                    el.rotation = Vector((0.0, 0.0, 1.0)).rotation_difference(bl(e[4]).normalized())
            else:
                a, b, r = np.asarray(e[1], dtype=np.float64), np.asarray(e[2], dtype=np.float64), e[3]
                el = mb.elements.new(type='CAPSULE')
                el.co = bl((a + b) * 0.5)
                el.radius = r * K
                el.size_x = float(np.linalg.norm(b - a)) * 0.5
                el.rotation = Vector((1.0, 0.0, 0.0)).rotation_difference((bl(b) - bl(a)).normalized())
                neg = len(e) > 4 and e[4]
            el.stiffness = 2.0
            el.use_negative = bool(neg)
        dg = bpy.context.evaluated_depsgraph_get()
        me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
        bpy.data.objects.remove(ob)
        o2 = bpy.data.objects.new("metamesh", me)
        bpy.context.scene.collection.objects.link(o2)
        if smooth:
            sm = o2.modifiers.new("Smooth", 'SMOOTH')
            sm.factor = 0.5
            sm.iterations = smooth
        cur = len(me.polygons) * 2
        if tris and cur > tris:
            d = o2.modifiers.new("Dec", 'DECIMATE')
            d.ratio = tris / cur
        dg = bpy.context.evaluated_depsgraph_get()
        m2 = o2.evaluated_get(dg).to_mesh()
        base = len(self.v)
        P = [V(v.co.x, v.co.z, -v.co.y) for v in m2.vertices]
        for q in P:
            self.vert(q, col(0, 0, q) if callable(col) else col, (q[0] + q[2], q[1]), lab(q) if callable(lab) else lab)
        for poly in m2.polygons:
            vs = list(poly.vertices)
            nrm = np.abs(np.array([poly.normal.x, poly.normal.z, -poly.normal.y]))
            ax = int(np.argmax(nrm))
            uv = [((P[i][2], P[i][1]) if ax == 0 else ((P[i][0], P[i][2]) if ax == 1 else (P[i][0], P[i][1]))) for i in vs]
            self.fuv[len(self.faces)] = uv
            self.faces.append([base + i for i in vs])
            self.fmat.append(mat)
        o2.evaluated_get(dg).to_mesh_clear()
        bpy.data.objects.remove(o2)
        return P

    def mesh(self, P, F, col, mat, lab, FUV=None):
        """A finished surface (vertices in rig space, faces as index lists), e.g. a retargeted MakeHuman body.
        FUV: per-face lists of corner UVs (metres), the mesh's own unwrap; without it a flat projection."""
        base = len(self.v)
        for q in P:
            q = np.asarray(q)
            k = len(self.v) - base
            self.vert(q, col(0, 0, q) if callable(col) else col, (q[0] + q[2], q[1]), lab[k] if isinstance(lab, list) else (lab(q) if callable(lab) else lab))
        for i, f in enumerate(F):
            if FUV is not None:
                self.fuv[len(self.faces)] = FUV[i]
            self.faces.append([base + i for i in f])
            self.fmat.append(mat)

    def ball(self, at, r, col, mat, lab, n=14, sx=1.0, sy=1.0, sz=1.0):
        P = []
        for i in range(n + 1):
            ph = math.pi * i / n
            P.append([at + V(math.sin(ph) * math.cos(TAU * j / (2 * n)) * r * sx, math.cos(ph) * r * sy, math.sin(ph) * math.sin(TAU * j / (2 * n)) * r * sz) for j in range(2 * n)])
        self.grid(P, col, mat, lab, lambda i, j, p: (float(j) / n * r * 3.0, float(i) / n * r * 3.0), wrap=True, flip=True)

    def plate(self, pts_fn, nu, nv, col, mat, lab, thick=0.0, flip=False):
        """A curved plate: pts_fn(u, v) for u, v in 0..1."""
        P = [[pts_fn(j / (nu - 1), i / (nv - 1)) for j in range(nu)] for i in range(nv)]
        self.grid(P, col, mat, lab, lambda i, j, p: (j / (nu - 1) * 0.4, i / (nv - 1) * 0.4), flip=flip)

    def box(self, c, half, col, mat, lab):
        c = np.asarray(c)
        hx, hy, hz = half
        for ax in range(3):
            for s in (-1, 1):
                a1, a2 = (ax + 1) % 3, (ax + 2) % 3
                q = []
                for (u, w) in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                    p = np.zeros(3)
                    p[ax] = s * half[ax]
                    p[a1] = u * half[a1]
                    p[a2] = w * half[a2]
                    q.append(self.vert(c + p, col, ((u + 1) * half[a1], (w + 1) * half[a2]), lab))
                self.faces.append(q if s > 0 else q[::-1])
                self.fmat.append(mat)

    # --- to Blender -----------------------------------------------------------------------------------
    def to_object(self, name, split_deg=42.0):
        # ONE material for the whole model (one draw call): which surface a face is rides in UV2.x, and the shader
        # picks that surface's tile and finish (boss_look.gd LAYERS); a material per surface cost ~400 draws a fight
        me = bpy.data.meshes.new(name)
        me.from_pydata([(p[0], -p[2], p[1]) for p in self.v], [], self.faces)
        mt = bpy.data.materials.get("atlas") or bpy.data.materials.new("atlas")
        me.materials.append(mt)
        for poly in me.polygons:
            poly.use_smooth = True
        uvl = me.uv_layers.new(name="UVMap")
        uv2 = me.uv_layers.new(name="Layer")
        me.uv_layers.active = uvl
        fl = {}
        for poly, m in zip(me.polygons, self.fmat):
            fl[poly.index] = float(LAYERS.index(m)) + 0.5 if m in LAYERS else 0.5
        for poly in me.polygons:
            for li in poly.loop_indices:
                uv2.data[li].uv = (fl[poly.index], 1.0)            # y: AO, open until baked (bake_ao)
        ca = me.color_attributes.new(name="Color", type='FLOAT_COLOR', domain='CORNER')
        for li, loop in enumerate(me.loops):
            vi = loop.vertex_index
            uvl.data[li].uv = self.uv[vi]
            c = self.col[vi]                                              # tints are written as seen (sRGB); the file wants linear
            ca.data[li].color = (c[0] ** 2.2, c[1] ** 2.2, c[2] ** 2.2, c[3])
        for fi, cs in self.fuv.items():
            for k, li in enumerate(me.polygons[fi].loop_indices):
                uvl.data[li].uv = cs[k]
        me.color_attributes.active_color = ca
        me.color_attributes.render_color_index = 0
        ob = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(ob)
        groups = {}
        for vi, lab in enumerate(self.lab):
            groups.setdefault(lab, []).append(vi)
        for lab, idx in groups.items():
            ob.vertex_groups.new(name=lab).add(idx, 1.0, 'REPLACE')
        me.update()
        bpy.context.view_layer.objects.active = ob
        ob.select_set(True)
        bpy.ops.object.mode_set(mode='EDIT')
        bpy.ops.mesh.select_all(action='SELECT')
        bpy.ops.mesh.normals_make_consistent(inside=False)
        bpy.ops.object.mode_set(mode='OBJECT')
        md = ob.modifiers.new("Split", 'EDGE_SPLIT')
        md.split_angle = math.radians(split_deg)
        bpy.ops.object.modifier_apply(modifier=md.name)
        bake_ao(ob, "Layer")
        ob.select_set(False)
        return ob


def bake_ao(ob, layer_uv="Layer", dist=0.22, samples=48):
    if os.environ.get("NO_AO"):
        return
    """DEPTH: Cycles ambient occlusion baked per corner into UV2.y (the layer UV's free channel), 1 open .. 0 deep.
    The shader darkens the albedo by it (painted cavity, as the old baked atlases had), occludes ambient and
    specular with it and finds worn edges against it. Only this object occludes itself: a hood over a face,
    a coat over the ribs, the armpit, the gap between the fingers. Short rays, so only local creases count."""
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.device = 'CPU'
    sc.cycles.samples = samples
    if sc.world is None:
        sc.world = bpy.data.worlds.new("World")
    sc.world.light_settings.distance = dist
    hidden = []
    for o in sc.objects:
        if o is not ob and not o.hide_render:
            o.hide_render = True
            hidden.append(o)
    me = ob.data
    ca = me.color_attributes["Color"]
    n = len(me.loops)
    saved = np.empty(n * 4, dtype=np.float32)
    ca.data.foreach_get("color", saved)                # the tints: the bake paints over the active colours
    me.color_attributes.active_color = ca
    bpy.ops.object.select_all(action='DESELECT')
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    sc.render.bake.target = 'VERTEX_COLORS'
    sc.render.bake.margin = 0
    try:
        bpy.ops.object.bake(type='AO')
        got = np.empty(n * 4, dtype=np.float32)
        ca.data.foreach_get("color", got)
        ao = np.clip(got.reshape(-1, 4)[:, 0], 0.02, 1.0)
        print("AO", ob.name, "p10 %.2f p50 %.2f mean %.2f" % (np.percentile(ao, 10), np.percentile(ao, 50), ao.mean()))
        uv2 = me.uv_layers[layer_uv]
        u = np.empty(n * 2, dtype=np.float32)
        uv2.data.foreach_get("uv", u)
        u = u.reshape(-1, 2)
        u[:, 1] = ao
        uv2.data.foreach_set("uv", u.ravel())
    except RuntimeError as e:
        print("bake_ao failed on", ob.name, e)
    ca.data.foreach_set("color", saved)
    me.color_attributes.render_color_index = 0
    for o in hidden:
        o.hide_render = False


def waist_split(y_split=0.95):
    return lambda p: "pelvis" if p[1] < y_split else "chest"


def hand(g, sx, col, lab, closed=0.0):
    """A bone hand at the rest wrist (x sx*0.24, y 0.78): a palm and four fingers and a thumb, lightly curled."""
    w = V(sx * 0.24, 0.78, 0.0)
    g.ball(w + V(0, -0.055, -0.005), 0.05, col, "bone", lab, n=8, sx=0.75, sy=1.25, sz=0.5)
    for k in range(4):
        fx = (k - 1.5) * 0.02
        base = w + V(fx, -0.105, -0.008)
        mid = base + V(0, -0.05, -0.012 - 0.02 * closed)
        tip = mid + V(0, -0.045, 0.004 - 0.03 * closed)
        g.tube([base, mid, tip, tip + V(0, -0.02, 0.006)], [0.0095, 0.0085, 0.007, 0.002], col, "bone", lab, n=6)
    b = w + V(-sx * 0.035, -0.05, -0.012)
    g.tube([b, b + V(-sx * 0.03, -0.035, -0.02), b + V(-sx * 0.035, -0.07, -0.03)], [0.011, 0.009, 0.003], col, "bone", lab, n=6)


def sleeve(g, sx, col, trim_col, r_top=0.085, r_cuff=0.15, drop=0.16):
    """A bell sleeve down the rest arm (shoulder y 1.40 to wrist y 0.80), the cuff hanging open below the hand."""
    sh = V(sx * 0.24, 1.44, 0.0)
    P = []
    ys = [1.44, 1.36, 1.24, 1.08, 0.96, 0.86, 0.80 - drop * 0.4, 0.80 - drop]
    n = 20
    for i, y in enumerate(ys):
        t = i / (len(ys) - 1)
        r = r_top + (r_cuff - r_top) * t ** 1.6
        hang = 0.5 * drop * max(0.0, t - 0.55) / 0.45                     # the bell hangs behind the wrist
        row = []
        for j in range(n):
            a = TAU * j / n
            fold = 1.0 + 0.07 * t * math.sin(a * 5 + 0.7)
            row.append(V(sx * 0.24 + math.cos(a) * r * fold, y - hang * (0.5 + 0.5 * math.sin(a)), math.sin(a) * r * fold * 0.9))
        P.append(row)
    lab = lambda p: "shoulder_" + ("l" if sx < 0 else "r") if p[1] > 1.09 else "elbow_" + ("l" if sx < 0 else "r")
    g.grid(P, col, "wool", lab, lambda i, j, p: (TAU * j / n * 0.11, p[1]), wrap=True, flip=sx > 0)
    cuff = [P[-1][j] for j in range(n)] + [P[-1][0]]
    ups = []
    for j in range(n + 1):
        a = TAU * (j % n) / n
        ups.append(V(math.cos(a), 0.0, math.sin(a) * 0.9))
    g.band([c + V(0, 0.03, 0) for c in cuff], 0.06, trim_col, "trim", "elbow_" + ("l" if sx < 0 else "r"), out=0.004, up=ups)


def eyes(g, y, z, gap, r, col=(1.0, 0.8, 0.5, 0.0)):
    for sx in (-1, 1):
        g.ball(V(sx * gap, y, z), r, col, "glow", "head", n=6, sx=1.25, sy=0.8, sz=0.6)


# --- the Bone Abbot -------------------------------------------------------------------------------------
# A tall dead priest: wine cassock, a black cope open down the front with gold orphreys, a bone mitre over a cowl
# whose shadow holds two candle eyes between a bone brow and a bone jaw-plate, the reliquary lit on his breast,
# skeleton hands out of bell sleeves, the crozier in the right.

def bone_abbot():
    g = Geo()
    WINE, BLACK, GOLD, BONE, DARK = (0.38, 0.065, 0.075), (0.09, 0.075, 0.085), (0.95, 0.72, 0.3), (0.86, 0.8, 0.66), (0.02, 0.02, 0.025)
    lab = waist_split(0.98)
    import grunt_build as GB                     # a gaunt old man's body under the vestments (its head is lost in the cowl's dark)
    bd = GB.human(g, BONE, (1.0, 0.72, 0.36, 0.0), macro={"gender": 1.0, "age": 1.0, "muscle": 0.0, "weight": 0.0, "height": 0.9}, girth=0.95, head=1.0, mat="bone", eye_r=0.014, skull=0.6)
    def ring_at(O, y, out=0.0):
        band = O[np.abs(O[:, 1] - y) < 0.025]
        if len(band) < 12:
            return []
        cx, cz = float(band[:, 0].mean()), float(band[:, 2].mean())
        ang = np.arctan2(band[:, 0] - cx, band[:, 2] - cz)
        pts = []
        for a in np.linspace(-math.pi, math.pi, 73):
            q = band[np.argmin(np.abs(np.remainder(ang - a + math.pi, TAU) - math.pi))]
            rr = math.hypot(q[0] - cx, q[2] - cz) + out
            pts.append((a, rr, float(q[1])))
        k = 5                                                            # a belt or a hem rides the folds' crests, smoothly
        out_pts = []
        for i2 in range(len(pts)):
            win = [pts[(i2 + d) % len(pts)] for d in range(-k, k + 1)]
            rr = max(w[1] for w in win)
            yy = sum(w[2] for w in win) / len(win)
            a = pts[i2][0]
            out_pts.append(V(cx + math.sin(a) * rr, yy, cz + math.cos(a) * rr))
        return out_pts
    # the cassock: laid on him from the breast, belted, falling wide to the floor in deep folds
    Oc = GB.coat(g, bd, WINE, mat="wool", y_top=1.5, y_hem=0.02, flare=0.3, seed=0.8, tatter=0.05, folds=13, thick=0.012, nu=128, nv=44, amp=0.075, crease=0.6)
    hem = ring_at(Oc, 0.06, 0.006)
    belt = ring_at(Oc, 1.03, 0.008)
    if belt:
        g.tube(belt, 0.028, GOLD, "trim", "chest", n=6, flat=0.5)
    front = Oc[(np.abs(Oc[:, 0]) < 0.012) & (Oc[:, 2] < float(Oc[:, 2].mean()))]
    front = front[np.argsort(-front[:, 1])]
    if len(front) > 4:                                                   # the orphrey down the front, smoothed over the folds
        ys = np.linspace(float(front[:, 1].max()) - 0.01, float(front[:, 1].min()) + 0.02, 24)
        zs = [float(front[np.argsort(np.abs(front[:, 1] - y))[:5]][:, 2].min()) for y in ys]
        zs = [min(zs[max(i2 - 2, 0):i2 + 3]) for i2 in range(len(zs))]
        g.band([V(0.0, float(y), z - 0.006) for y, z in zip(ys, zs)], 0.085, GOLD, "trim", lab, out=0.004, up=[V(0, 0, -1)] * len(ys))
    # the cope: from the shoulders to the floor over everything, open down the front, gilt at its edges
    gap = math.radians(52)
    Op = GB.shawl(g, bd, BLACK, mat="wool", y_low=0.03, gap=(-gap, gap), seed=1.1, tatter=0.04, flare=0.34, amp=0.05)
    # the morse: a gilt clasp across the breast, and the reliquary hung under it, lit
    g.box(V(0.0, 1.43, -0.2), (0.075, 0.045, 0.012), GOLD, "gilt", "chest")
    g.ball(V(0.0, 1.43, -0.214), 0.022, (1.0, 0.6, 0.25, 0.0), "glow", "chest", n=6)
    R = V(0.0, 1.2, -0.215)
    g.ball(R, 0.05, (1.0, 0.72, 0.4, 0.0), "glow", "chest", n=8, sy=1.25)
    for k in range(6):                                                    # its cage: six gilt ribs
        a = TAU * k / 6
        g.tube([R + V(math.cos(a) * 0.06 * math.sin(ph), 0.085 * math.cos(ph), math.sin(a) * 0.06 * math.sin(ph)) for ph in np.linspace(0.12, math.pi - 0.12, 9)], 0.006, GOLD, "gilt", "chest", n=5)
    g.lathe([(0.0, 0.1), (0.022, 0.092), (0.012, 0.085)], R, GOLD, "gilt", "chest", n=10)
    g.lathe([(0.012, -0.085), (0.03, -0.1), (0.0, -0.12)], R, GOLD, "gilt", "chest", n=10)
    g.tube([R + V(0, 0.1, 0), V(-0.05, 1.4, -0.19), V(-0.09, 1.5, -0.1)], 0.004, GOLD, "gilt", "chest", n=4)
    g.tube([R + V(0, 0.1, 0), V(0.05, 1.4, -0.19), V(0.09, 1.5, -0.1)], 0.004, GOLD, "gilt", "chest", n=4)
    # sleeves laid on his arms, wide at the cuff
    for sx in (-1, 1):
        GB.sleeve(g, bd, sx, WINE, GOLD, flare=0.03, bell=0.06, y_cuff=0.76)
    # the head: a cowl full of dark, two candle eyes, a bone brow and a bone jaw-plate with teeth, the mitre over all
    H = V(0.0, 1.64, 0.0)
    cowl = [(1.5, 0.19, 0.16, 0.02), (1.58, 0.17, 0.155, 0.01), (1.7, 0.165, 0.17, 0.0), (1.82, 0.15, 0.165, 0.005), (1.9, 0.11, 0.13, 0.02), (1.94, 0.03, 0.04, 0.03)]
    g.robe(cowl, BLACK, "wool", lambda p: "head" if p[1] > 1.6 else "chest", n=40, t0=math.radians(75), t1=TAU - math.radians(75))
    # the mitre: two peaked plates with a cleft, an orphrey up each, a circlet, lappets behind
    # a closed ogee mitre: panels stitched at eight seams (shallow ridges), a swelling shoulder then a peak, bone with gilt orphreys front and back
    def mw(v):
        return 0.138 * (1.0 - v ** 1.7) ** 1.05 * (1.0 + 0.1 * math.sin(v * math.pi)) + 0.004

    def md(v):
        return 0.098 * (1.0 - v ** 1.35) * (1.0 + 0.08 * math.sin(v * math.pi)) + 0.004
    rings = [(1.78 + 0.4 * v, mw(v), md(v), 0.012) for v in np.linspace(1.0, 0.0, 22)]
    g.robe(rings, BONE, "bone", "head", n=64, pleats=16, pleat_amp=0.012, pleat_from=2.18)
    for s in (-1, 1):
        vs = np.linspace(0.03, 0.95, 12)
        g.band([V(0.0, 1.78 + 0.4 * v, 0.012 + s * (md(v) + 0.004)) for v in vs], 0.05, GOLD, "trim", "head", out=0.004, up=[V(0, 0, s)] * len(vs))
    g.ring_band(1.78, 1.84, 0.14, 0.12, 0.01, GOLD, "trim", "head", n=40)
    for sx in (-1, 1):
        g.band([V(sx * 0.06, 1.82, 0.135), V(sx * 0.065, 1.66, 0.19), V(sx * 0.07, 1.48, 0.22), V(sx * 0.072, 1.3, 0.235)], 0.06, GOLD, "trim",
               lambda p: "head" if p[1] > 1.6 else "chest", out=0.004, up=[V(0, 0, 1)] * 4)
    body = g.to_object("body")
    # the crozier, in the right hand's own space (origin at the wrist joint)
    c = Geo()
    c.lathe([(0.0, -0.78), (0.022, -0.76), (0.016, -0.7), (0.016, 0.9), (0.03, 0.93), (0.036, 0.98), (0.03, 1.03), (0.018, 1.06), (0.016, 1.12)],
            V(0, 0, -0.035), (0.2, 0.15, 0.12), "wood", "hand_r", n=10)
    crook = [V(0.0, 1.12 + 0.02 * k if k < 3 else 1.18 + 0.105 * (1.0 - math.cos((k - 3) / 15 * 4.4)), -0.035) for k in range(3)]
    for k in range(40):
        a = k / 39 * 4.6
        rr = 0.12 * (1.0 - 0.72 * k / 39)
        crook.append(V(0.0, 1.3 + math.sin(a) * rr, -0.035 - 0.12 + math.cos(a) * rr))
    c.tube(crook, [0.024] * 3 + [0.024 - 0.015 * (k / 39) ** 0.8 for k in range(40)], GOLD, "gilt", "hand_r", n=10)
    c.ball(crook[-1], 0.02, (1.0, 0.75, 0.4, 0.0), "glow", "hand_r", n=6)
    for k in range(4):
        c.lathe([(0.02, 0.0), (0.024, 0.012), (0.02, 0.024)], V(0, -0.3 + 0.33 * k, -0.035), GOLD, "gilt", "hand_r", n=10)
    for k in range(9):                                                   # a cord wound up the grip, worn
        c.lathe([(0.017, 0.0), (0.022, 0.006), (0.017, 0.012)], V(0, 0.1 + 0.035 * k, -0.035), (0.35, 0.27, 0.16), "leather", "hand_r", n=10)
    c.lathe([(0.0, 0.0), (0.03, 0.0), (0.042, 0.03), (0.034, 0.07), (0.022, 0.1), (0.0, 0.11)], V(0, 0.93, -0.035), (0.8, 0.74, 0.6), "bone", "hand_r", n=12)   # a bone knop under the crook
    staff = c.to_object("staff_hand_r")
    return body, [staff]


# --- the Ascended Warden ------------------------------------------------------------------------------
# What is left of a priest who went up: a white bell of linen hanging in the air with nothing under it, a mantle,
# a long gilt-edged tabard, ashen hands held out of wide sleeves, a smooth white-gold mask with two slits of light
# inside a veil, and behind the head a wheel of thorns that burns.

def ascended_warden():
    g = Geo()
    LINEN, PALE, GOLD, ASH, DARK, MASK = (0.82, 0.8, 0.74), (0.93, 0.9, 0.82), (0.95, 0.78, 0.4), (0.42, 0.42, 0.45), (0.015, 0.015, 0.02), (0.95, 0.9, 0.76)
    lab = waist_split(0.98)
    import grunt_build as GB                                             # the ashen body under the linen, first: the linen is kept off it
    bd = GB.human(g, ASH, (1.0, 0.95, 0.7, 0.0), macro={"gender": 0.5, "age": 0.6, "muscle": 0.2, "weight": 0.0, "height": 1.0}, girth=0.9, head=1.0)
    # nothing is under the mask: the body's head drawn in small behind it (it stood through the mask and the veil)
    n0 = g._fit[1] - len(bd.P)
    hi = [k for k in range(len(bd.P)) if bd.L[k] == "head"]
    hc = np.mean([g.v[n0 + k] for k in hi], axis=0)
    HC = V(0.0, 1.72, 0.01)                                              # the middle of the mask's dark (below)
    for k in range(len(bd.P)):
        y = float(g.v[n0 + k][1])
        if bd.L[k] == "head" or y > 1.52:              # the jaw and the neck too (they carry the chest's label)
            w = 1.0 if bd.L[k] == "head" else min((y - 1.52) / 0.08, 1.0)
            g.v[n0 + k] = g.v[n0 + k] + (HC + (g.v[n0 + k] - hc) * 0.55 - g.v[n0 + k]) * w
    for k in range(g._fit[1], len(g.v)):                                 # its eye coals too
        if g.lab[k] == "head":
            g.v[k] = HC + (g.v[k] - hc) * 0.55
    bell = [(1.5, 0.17, 0.12, 0.0), (1.38, 0.19, 0.135, 0.0), (1.2, 0.185, 0.14, 0.0), (1.04, 0.2, 0.16, 0.0), (0.86, 0.3, 0.26, 0.0), (0.66, 0.44, 0.4, 0.01),
            (0.46, 0.56, 0.52, 0.02), (0.3, 0.63, 0.59, 0.03), (0.18, 0.66, 0.62, 0.03)]
    g.robe(bell, LINEN, "linen", lab, n=120, pleats=18, pleat_amp=0.1, pleat_from=1.02, tatter=0.14)
    inner = [(y, rx * 0.94, rz * 0.94, cz) for (y, rx, rz, cz) in bell[3:]]
    g.robe(inner, DARK, "iron", "pelvis", n=60, pleats=18, pleat_amp=0.1, pleat_from=1.02, flip=True)
    pleat = lambda th: 1.0 + 0.1 * 0.45 * ((1.0 - abs(math.sin(th * 9)) ** 0.7) * 2.0 - 1.0)
    g.ring_band(0.42, 0.5, 0.572, 0.532, 0.02, GOLD, "trim", "pelvis", n=120, fn=pleat)
    g.ring_band(1.0, 1.06, 0.205, 0.165, 0.0, GOLD, "trim", "chest", n=48)
    # the tabard: a long panel down the front, gilt edged
    tab = [V(0.0, y, -(rz * 1.035) + cz - 0.006) for (y, rx, rz, cz) in bell[:8]]
    g.band(tab, 0.2, PALE, "linen", lab, out=0.012, up=[V(0, 0, -1)] * len(tab))
    for sx in (-1, 1):
        g.band([p + V(sx * 0.105, 0, 0) for p in tab], 0.035, GOLD, "trim", lab, out=0.018, up=[V(0, 0, -1)] * len(tab))
    g.band([tab[-1] + V(-0.12, -0.03, 0), tab[-1] + V(0.0, -0.09, -0.01), tab[-1] + V(0.12, -0.03, 0)], 0.04, GOLD, "trim", "pelvis", out=0.018, up=[V(0, 0, -1)] * 3)
    # the mantle over the shoulders
    mant = [(1.58, 0.2, 0.15, 0.01), (1.52, 0.3, 0.2, 0.01), (1.4, 0.36, 0.25, 0.02), (1.24, 0.42, 0.31, 0.03), (1.14, 0.45, 0.34, 0.03)]
    Pm = g.robe(mant, PALE, "linen", "chest", n=72, pleats=10, pleat_amp=0.05, pleat_from=1.5, tatter=0.05)
    g.ring_band(1.15, 1.2, 0.452, 0.342, 0.03, GOLD, "trim", "chest", n=72)
    # the sun on the breast
    g.lathe([(0.0, 0.0), (0.07, 0.004), (0.085, 0.012), (0.07, 0.02), (0.0, 0.024)], V(0.0, 1.32, -0.2), GOLD, "gilt", "chest", n=20, axis="z")
    g.ball(V(0.0, 1.32, -0.228), 0.032, (1.0, 0.9, 0.6, 0.0), "glow", "chest", n=8, sz=0.5)
    for k in range(12):
        a = TAU * k / 12
        g.tube([V(math.cos(a) * 0.085, 1.32 + math.sin(a) * 0.085, -0.212), V(math.cos(a) * (0.13 + 0.03 * (k % 2)), 1.32 + math.sin(a) * (0.13 + 0.03 * (k % 2)), -0.208)], [0.008, 0.001], GOLD, "gilt", "chest", n=5)
    # wide sleeves, gilt bracers, ashen hands
    for sx in (-1, 1):
        GB.sleeve(g, bd, sx, LINEN, GOLD, flare=0.03, bell=0.08, y_cuff=0.74, mat="linen")
    # the head: a veil, the dark inside it, the mask
    veil = [(1.5, 0.2, 0.17, 0.02), (1.6, 0.175, 0.165, 0.015), (1.72, 0.17, 0.18, 0.01), (1.84, 0.15, 0.17, 0.015), (1.92, 0.1, 0.12, 0.03), (1.95, 0.02, 0.03, 0.04)]
    g.robe(veil, PALE, "linen", lambda p: "head" if p[1] > 1.6 else "chest", n=44, t0=math.radians(42), t1=TAU - math.radians(42))
    g.ball(V(0.0, 1.73, 0.0), 0.125, DARK, "iron", "head", n=10, sy=1.15)

    def mask(u, v):
        th = (u - 0.5) * math.radians(118)
        ph = v
        y = 1.6 + 0.26 * ph
        r = 0.132 * (0.8 + 0.2 * math.sin(ph * math.pi) ** 0.6) * (1.0 - 0.18 * (1.0 - ph) ** 2)
        nose = 0.012 * math.exp(-((u - 0.5) / 0.07) ** 2) * math.exp(-((ph - 0.4) / 0.22) ** 2)
        brow = 0.006 * math.exp(-((ph - 0.66) / 0.06) ** 2)
        return V(math.sin(th) * r, y, -math.cos(th) * (r * 1.06 + nose + brow))
    g.plate(mask, 25, 15, MASK, "bone", "head")
    for sx in (-1, 1):                                                    # the eyes: two slits of light
        g.ball(V(sx * 0.05, 1.752, -0.128), 0.02, (1.0, 0.95, 0.7, 0.0), "glow", "head", n=6, sx=1.5, sy=0.32, sz=0.4)
    g.tube([V(0.012, 1.86, -0.118), V(0.02, 1.8, -0.137), V(0.006, 1.74, -0.146), V(0.022, 1.68, -0.14), V(0.014, 1.62, -0.118)], 0.0028, DARK, "iron", "head", n=4)   # the crack
    g.ring_band(1.845, 1.875, 0.158, 0.15, 0.012, GOLD, "trim", "head", n=44, t0=math.radians(-70), t1=math.radians(70))                        # a circlet over the brow
    # the wheel of thorns behind the head
    C = V(0.0, 1.8, 0.16)
    for (rr, tr, mat, col) in ((0.36, 0.016, "gilt", GOLD), (0.27, 0.009, "glow", (1.0, 0.9, 0.6, 0.0)), (0.46, 0.008, "gilt", GOLD)):
        g.tube([C + V(math.cos(a) * rr, math.sin(a) * rr, 0.0) for a in np.linspace(0, TAU, 49)], tr, col, mat, "head", n=6)
    for k in range(16):
        a = TAU * k / 16 + 0.1
        ln = 0.3 if k % 2 == 0 else 0.16
        bend = 0.05 * (1 if k % 4 < 2 else -1)
        g.tube([C + V(math.cos(a) * 0.36, math.sin(a) * 0.36, 0.0), C + V(math.cos(a + 0.06) * (0.36 + ln * 0.6), math.sin(a + 0.06) * (0.36 + ln * 0.6), bend),
                C + V(math.cos(a) * (0.36 + ln), math.sin(a) * (0.36 + ln), bend * 2.0)], [0.014, 0.008, 0.001], GOLD, "gilt", "head", n=5)
    for k in range(8):                                                    # spokes from the ring of light
        a = TAU * k / 8
        g.tube([C + V(math.cos(a) * 0.27, math.sin(a) * 0.27, 0.0), C + V(math.cos(a) * 0.36, math.sin(a) * 0.36, 0.0)], 0.006, GOLD, "gilt", "head", n=4)
    g.tube([C + V(-0.1, -0.2, 0.0), V(-0.08, 1.62, 0.12)], 0.01, GOLD, "gilt", "head", n=5)
    g.tube([C + V(0.1, -0.2, 0.0), V(0.08, 1.62, 0.12)], 0.01, GOLD, "gilt", "head", n=5)
    return g.to_object("body"), []


# --- the Hierarch's Voice -------------------------------------------------------------------------------
# A cathedral statue that walks: a stone cope carved in heavy folds over a stone robe, a broken crown, a carved face
# whose jaw has split open into a great speaking-horn with the ember deep in its throat, moulded pauldrons (one
# broken), block gauntlets. Weathered grey stone with gilt worn to the ground.

def hierarch():
    g = Geo()
    STONE, PALE, DARK, GILT, MOSS = (0.5, 0.48, 0.44), (0.62, 0.6, 0.55), (0.02, 0.02, 0.02), (0.75, 0.6, 0.32), (0.3, 0.34, 0.24)
    lab = waist_split(0.98)
    import grunt_build as GB                     # the statue's body is carved from a man's: an old, heavy king's face and hands
    bd = GB.human(g, PALE, (1.0, 0.55, 0.2, 0.0), macro={"gender": 1.0, "age": 1.0, "muscle": 0.5, "weight": 0.9, "proportions": 0.4},
                  girth=1.15, head=1.7, mat="stone", shoulder_y=1.5)
    robe = [(1.5, 0.2, 0.15, 0.0), (1.3, 0.22, 0.17, 0.0), (1.05, 0.21, 0.17, 0.0), (0.8, 0.27, 0.23, 0.0), (0.45, 0.36, 0.32, 0.01), (0.1, 0.43, 0.39, 0.02), (0.0, 0.45, 0.41, 0.02)]
    g.robe(robe, STONE, "stone", lab, n=128, pleats=16, pleat_amp=0.1, pleat_from=1.1)
    g.ring_band(0.04, 0.14, 0.452, 0.412, 0.02, GILT, "trim", "pelvis", n=96)
    cope = [(1.6, 0.26, 0.2, 0.03), (1.5, 0.36, 0.25, 0.03), (1.3, 0.42, 0.31, 0.04), (0.9, 0.5, 0.4, 0.05), (0.45, 0.6, 0.5, 0.06), (0.06, 0.67, 0.57, 0.07)]
    Pc = g.robe(cope, PALE, "stone", lab, n=128, t0=math.radians(48), t1=TAU - math.radians(48), pleats=11, pleat_amp=0.17, pleat_from=1.5, tatter=0.1)
    for edge in (0, -1):
        g.band([row[edge] for row in Pc], 0.1, GILT, "trim", lab, out=0.008, up=[V(0.6 * (1 if edge == 0 else -1), 0, -0.8)] * len(Pc))
    for k in range(5):                                                    # moss in the folds near the ground
        a = 0.9 + k * 1.05
        g.ball(V(math.sin(a) * 0.6, 0.06, -math.cos(a) * 0.52 + 0.06), 0.07, MOSS, "wool", "pelvis", n=6, sy=0.4)
    for sx in (-1, 1):
        t = "l" if sx < 0 else "r"
        GB.sleeve(g, bd, sx, STONE, GILT, flare=0.03, mat="stone")
        g.lathe([(0.0, 0.0), (0.15, 0.0), (0.16, 0.05), (0.14, 0.1), (0.08, 0.14), (0.0, 0.15)], V(sx * 0.27, 1.38, 0.0), PALE, "stone", "shoulder_" + t, n=20)
        if sx < 0:
            g.box(V(-0.36, 1.46, 0.04), (0.04, 0.03, 0.06), PALE, "stone", "shoulder_l")        # the broken edge
    # the crown on the carved head, the crack down the face, the horn breaking out of the jaw
    top = float(max(q[1] for q, l in zip(bd.P, bd.L) if l == "head"))
    cy = top - 0.07
    ring = GB.contour(bd, cy, ("head",), off=0.012, band=0.02)
    cr = float(np.mean([math.hypot(q[0], q[2]) for _, q in ring])) if ring else 0.14
    cz = float(np.mean([q[2] for _, q in ring])) if ring else 0.0
    g.tube([V(0.06, top - 0.02, -0.13), V(0.04, top - 0.1, -0.15), V(0.07, top - 0.18, -0.15)], 0.003, DARK, "iron", "head", n=4)
    g.ring_band(cy - 0.03, cy + 0.03, cr, cr, cz, GILT, "trim", "head", n=36)
    for k in range(9):
        a = TAU * k / 9
        h = 0.13 if k not in (2, 6) else 0.05                              # two tines broken
        g.tube([V(math.sin(a) * cr, cy + 0.03, cz - math.cos(a) * cr), V(math.sin(a) * (cr + 0.01), cy + 0.03 + h, cz - math.cos(a) * (cr + 0.01))], [0.022, 0.004 if h > 0.1 else 0.016], GILT, "gilt", "head", n=5)
    horn = [(0.07, 0.0), (0.06, 0.08), (0.06, 0.2), (0.07, 0.32), (0.09, 0.44), (0.13, 0.53), (0.19, 0.59), (0.21, 0.62), (0.19, 0.62)]
    path_at = V(0.0, 1.62, -0.13)
    P = []
    for i, (r, d) in enumerate(horn):
        t = d / 0.62
        c = path_at + V(0.0, -0.32 * t * t, -0.62 * t)
        P.append([c + V(math.cos(TAU * j / 24) * r, math.sin(TAU * j / 24) * r * 0.92 * math.cos(0.45 * t), math.sin(TAU * j / 24) * r * math.sin(0.45 * t) * 0.3) for j in range(24)])
    g.grid(P, STONE, "stone", "head", lambda i, j, p: (TAU * j / 24 * 0.15, i * 0.1), wrap=True, flip=True)
    g.grid(P[::-1][1:], DARK, "iron", "head", lambda i, j, p: (TAU * j / 24 * 0.15, i * 0.1), wrap=True) if False else None
    g.ball(path_at + V(0.0, -0.06, -0.22), 0.07, (1.0, 0.5, 0.15, 0.0), "glow", "head", n=8)
    for k in range(4):
        a = 0.4 + k * 1.5
        g.tube([path_at + V(math.cos(a) * 0.07, -0.05 + math.sin(a) * 0.06, -0.2), path_at + V(math.cos(a) * 0.2, -0.22 + math.sin(a) * 0.18, -0.5)], 0.006, (1.0, 0.5, 0.15, 0.0), "glow", "head", n=4)
    g.lathe([(0.2, 0.0), (0.225, 0.015), (0.21, 0.035)], path_at + V(0.0, -0.32, -0.6), GILT, "gilt", "head", n=24, axis="z")
    return g.to_object("body"), []


# --- the Anchoress ----------------------------------------------------------------------------------------
# Walled in to pray: a hooded, gagged woman in a long salt-stiffened dress and a torn shawl, a lamp held up to her
# face in the left fist, an anchor-stone dragged on a chain from the right.

def anchoress():
    g = Geo()
    DRESS, SHAWL, SALT, SKIN, IRON, ROPE = (0.22, 0.2, 0.2), (0.3, 0.27, 0.24), (0.8, 0.78, 0.72), (0.62, 0.55, 0.5), (0.18, 0.17, 0.17), (0.45, 0.36, 0.26)
    lab = waist_split(0.98)
    import grunt_build as GB                                             # a MakeHuman body first: what she wears is laid on it
    bd = GB.human(g, SKIN, (1.0, 0.8, 0.5, 0.0), macro={"gender": 0.0, "age": 0.9, "muscle": 0.15, "weight": 0.05, "proportions": 0.3}, girth=0.92, head=1.0)
    dress = [(1.5, 0.17, 0.12, 0.0), (1.36, 0.18, 0.13, 0.0), (1.2, 0.17, 0.13, 0.0), (1.02, 0.16, 0.125, 0.0), (0.8, 0.21, 0.18, 0.0), (0.45, 0.29, 0.26, 0.01), (0.12, 0.35, 0.32, 0.02), (0.0, 0.37, 0.34, 0.02)]
    def salted(i, j, p):                                                 # salt dried up the hem in a crusted tide line
        tide = 0.22 + 0.06 * math.sin(p[0] * 31.0) + 0.04 * math.sin(p[2] * 47.0 + 1.3)
        k = min(max((tide - p[1]) / 0.08, 0.0), 1.0)
        return tuple(DRESS[c] * (1 - k) + SALT[c] * k for c in range(3))
    Od = GB.coat(g, bd, lambda i, j, p: salted(i, j, p), mat="wool", y_top=1.48, y_hem=0.02, flare=0.2, seed=2.2, tatter=0.05, folds=11, thick=0.01, nu=88, nv=34)
    for k in range(5):                                                   # prayer strips hung from the rope belt, written and torn
        a = math.radians(-62 + k * 31 + 9 * math.sin(k * 2.1))
        top = V(math.sin(a) * 0.17, 1.0, -math.cos(a) * 0.135)
        ln = 0.22 + 0.16 * ((k * 37) % 5) / 5
        g.band([top + V(math.sin(a) * 0.05 * t, -ln * t, -math.cos(a) * 0.05 * t + 0.012 * math.sin(t * 6 + k)) for t in np.linspace(0, 1, 6)],
               0.04, SALT, "linen", lambda p: "pelvis" if p[1] < 0.95 else "chest", out=0.012, up=[V(math.sin(a), 0, -math.cos(a))] * 6)
    for k in range(2):                                                   # the chain wound twice round her skirt, on it
        y = 0.6 - 0.22 * k
        band = Od[np.abs(Od[:, 1] - y) < 0.02]
        if len(band) > 12:
            cx, cz = float(band[:, 0].mean()), float(band[:, 2].mean())
            ring = []
            for a in np.linspace(0, TAU, 41):
                ang = np.arctan2(band[:, 0] - cx, band[:, 2] - cz)
                q = band[np.argmin(np.abs(np.remainder(ang - a + math.pi, TAU) - math.pi))]
                rr = math.hypot(q[0] - cx, q[2] - cz) + 0.012
                ring.append(V(cx + math.sin(a) * rr, y - 0.04 * math.sin(a) ** 2, cz + math.cos(a) * rr))
            g.chain(ring, IRON, "iron", "pelvis")
    g.ring_band(0.99, 1.05, 0.165, 0.13, 0.0, ROPE, "leather", "chest", n=40)
    bind = GB.contour(bd, 1.14, tuple(sorted({l for l in bd.L if l == "chest" or l.startswith(("shoulder_", "elbow_"))})), off=0.045, bins=36, band=0.03)
    if len(bind) > 8:                                                    # bound over the shawl and her arms
        pts = [q + V(0, -0.02 * math.sin(a) ** 2, 0) for a, q in bind]
        g.chain(pts + [pts[0]], IRON, "iron", "chest")
    # under the dress and the shawl (hand cut, close at the breast): the body drawn in, so it never shows through
    GB.tuck(g, bd, [k for k in range(len(bd.P)) if bd.L[k] in ("chest", "pelvis") or (bd.L[k].startswith(("shoulder_", "hip_")) and bd.P[k][1] > 0.7)], 0.022)
    for sx in (-1, 1):
        GB.sleeve(g, bd, sx, DRESS, ROPE, flare=0.015)
    GB.shawl(g, bd, SHAWL, y_low=1.02, gap=(math.radians(-30), math.radians(50)), seed=1.4, tatter=0.06)
    # the head: a deep hood laid on her, her gaunt face seen in it, the rope gag biting into the mouth
    GB.cowl(g, bd, SHAWL, open_w=0.07, open_h=0.095, seed=3.1)
    E = bd.eyes
    if len(E) == 2:
        ey = (E[0][1] + E[1][1]) * 0.5
        hw = abs(E[0][0] - E[1][0]) * 0.5
        my = ey - hw * 2.35
        loop = GB.contour(bd, my, ("head",), off=0.006, bins=36, band=0.012)
        front = sorted([(a, q) for a, q in loop if abs(math.remainder(a - math.pi, TAU)) < 1.5], key=lambda t: math.remainder(t[0] - math.pi, TAU))
        if len(front) > 3:
            g.tube([q for _, q in front], 0.011, ROPE, "leather", "head", n=6)
    # the lamp, up at her face in the left fist (in the hand's own space)
    lp = Geo()
    lp.tube([V(0, 0.0, -0.02), V(0, -0.06, -0.02)], 0.006, IRON, "iron", "hand_l", n=4)
    lp.lathe([(0.0, -0.06), (0.05, -0.08), (0.055, -0.1), (0.05, -0.12)], V(0, 0, -0.02), IRON, "iron", "hand_l", n=12)
    lp.ball(V(0, -0.17, -0.02), 0.045, (1.0, 0.75, 0.4, 0.0), "glow", "hand_l", n=8, sy=1.2)
    for k in range(4):
        a = TAU * k / 4
        lp.tube([V(math.cos(a) * 0.05, -0.12, -0.02 + math.sin(a) * 0.05), V(math.cos(a) * 0.05, -0.22, -0.02 + math.sin(a) * 0.05)], 0.005, IRON, "iron", "hand_l", n=4)
    lp.lathe([(0.055, -0.22), (0.06, -0.24), (0.0, -0.25)], V(0, 0, -0.02), IRON, "iron", "hand_l", n=12)
    # the chain from the right fist to the stone on the floor (in the hand's own space: the floor is 0.78 below)
    ch = Geo()
    links = [V(0.0, -0.03 - 0.06 * k, -0.03 + 0.04 * k ** 1.3) for k in range(13)]
    ch.chain(links, IRON, "iron", "hand_r", link=0.05, wire=0.008)
    st = links[-1] + V(0.0, -0.06, 0.08)
    ch.ball(st + V(0.0, -0.04, 0.0), 0.15, (0.45, 0.43, 0.4), "stone", "hand_r", n=10, sy=0.6)
    ch.ball(st + V(0.0, 0.03, 0.0), 0.1, SALT, "linen", "hand_r", n=8, sy=0.4)
    return g.to_object("body"), [lp.to_object("lamp_hand_l"), ch.to_object("chain_hand_r")]


BUILDERS = {"bone_abbot": bone_abbot, "ascended_warden": ascended_warden, "hierarch": hierarch, "anchoress": anchoress}


def build(name):
    return BUILDERS[name]()
