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
import math
import numpy as np
from mathutils import Vector

TAU = math.tau


def V(x, y, z):
    return np.array([x, y, z], dtype=np.float64)


class Geo:
    """Vertices, faces, colours, UVs and skin labels gathered part by part, then made one mesh."""

    def __init__(self):
        self.v, self.col, self.uv, self.lab, self.faces, self.fmat = [], [], [], [], [], []

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
        mats = sorted(set(self.fmat))
        me = bpy.data.meshes.new(name)
        me.from_pydata([(p[0], -p[2], p[1]) for p in self.v], [], self.faces)
        for m in mats:
            mt = bpy.data.materials.get(m) or bpy.data.materials.new(m)
            me.materials.append(mt)
        for poly, m in zip(me.polygons, self.fmat):
            poly.material_index = mats.index(m)
            poly.use_smooth = True
        uvl = me.uv_layers.new(name="UVMap")
        ca = me.color_attributes.new(name="Color", type='FLOAT_COLOR', domain='CORNER')
        for li, loop in enumerate(me.loops):
            vi = loop.vertex_index
            uvl.data[li].uv = self.uv[vi]
            c = self.col[vi]                                              # tints are written as seen (sRGB); the file wants linear
            ca.data[li].color = (c[0] ** 2.2, c[1] ** 2.2, c[2] ** 2.2, c[3])
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
        ob.select_set(False)
        return ob


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
    # cassock: fitted to the breast, belted, falling in pleats that break on the floor
    cass = [(1.50, 0.185, 0.125, 0.0), (1.40, 0.205, 0.14, 0.0), (1.26, 0.2, 0.145, 0.0), (1.08, 0.175, 0.135, 0.0), (1.02, 0.17, 0.13, 0.0),
            (0.9, 0.2, 0.16, 0.0), (0.7, 0.26, 0.22, 0.0), (0.45, 0.33, 0.29, 0.01), (0.2, 0.4, 0.36, 0.02), (0.04, 0.45, 0.41, 0.02), (0.0, 0.47, 0.43, 0.02)]
    g.robe(cass, WINE, "wool", lab, n=112, pleats=22, pleat_amp=0.085, pleat_from=1.0, hem_break=0.03)
    pleat = lambda th: 1.0 + 0.085 * ((1.0 - abs(math.sin(th * 11)) ** 0.7) * 2.0 - 1.0 + 0.35 * math.sin(th * 22 * 1.37 + 1.3))
    g.ring_band(0.035, 0.15, 0.452, 0.412, 0.02, GOLD, "trim", "pelvis", n=112, fn=lambda th: pleat(th) * 1.012)
    g.ring_band(0.995, 1.065, 0.18, 0.14, 0.0, GOLD, "trim", "chest", n=48)                    # the cincture
    # the orphrey down the front of the cassock
    path, ups = [], []
    for (y, rx, rz, cz) in cass:
        path.append(V(0.0, y, -rz * (1.0 + (0.02 if y > 1.0 else 0.03)) + cz))
        ups.append(V(0, 0, -1))
    g.band(path, 0.085, GOLD, "trim", lab, out=0.008, up=ups)
    # the cope: from the shoulders to the floor, open 70 degrees down the front, a standing collar behind the head
    gap = math.radians(52)
    cope = [(1.56, 0.24, 0.17, 0.02), (1.5, 0.31, 0.2, 0.02), (1.4, 0.335, 0.225, 0.03), (1.2, 0.36, 0.26, 0.03), (0.95, 0.42, 0.33, 0.04),
            (0.65, 0.52, 0.44, 0.05), (0.35, 0.62, 0.55, 0.06), (0.1, 0.7, 0.63, 0.07), (0.0, 0.73, 0.66, 0.07)]
    Pc = g.robe(cope, BLACK, "wool", lab, n=112, t0=gap, t1=TAU - gap, pleats=14, pleat_amp=0.13, pleat_from=1.42, hem_break=0.04)
    for edge in (0, -1):                                                   # orphreys down both front edges
        pth = [row[edge] for row in Pc]
        nr = [V(math.sin(gap) * (1 if edge == 0 else -1) * 0.5, 0.0, -math.cos(gap)) for _ in pth]
        g.band(pth, 0.11, GOLD, "trim", lab, out=0.006, up=nr)
    g.band(Pc[-2], 0.1, GOLD, "trim", "pelvis", out=0.006, up=[V(p[0], 0.0, p[2] - 0.07) / max(np.linalg.norm(V(p[0], 0.0, p[2] - 0.07)), 1e-9) for p in Pc[-2]])
    coll = [(1.56, 0.24, 0.17, 0.02), (1.66, 0.22, 0.17, 0.05), (1.76, 0.235, 0.19, 0.08), (1.8, 0.25, 0.2, 0.09)]
    g.robe(coll, BLACK, "wool", "chest", n=40, t0=math.radians(70), t1=TAU - math.radians(70))
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
    # sleeves and hands
    for sx in (-1, 1):
        sleeve(g, sx, WINE, GOLD)
        hand(g, sx, BONE, "hand_" + ("l" if sx < 0 else "r"), closed=1.0 if sx > 0 else 0.3)
        g.tube([V(sx * 0.24, 0.98, 0), V(sx * 0.24, 0.8, 0)], [0.022, 0.018], BONE, "bone", "elbow_" + ("l" if sx < 0 else "r"), n=6)
    # the head: a cowl full of dark, two candle eyes, a bone brow and a bone jaw-plate with teeth, the mitre over all
    H = V(0.0, 1.64, 0.0)
    cowl = [(1.5, 0.19, 0.16, 0.02), (1.58, 0.17, 0.155, 0.01), (1.7, 0.165, 0.17, 0.0), (1.82, 0.15, 0.165, 0.005), (1.9, 0.11, 0.13, 0.02), (1.94, 0.03, 0.04, 0.03)]
    g.robe(cowl, BLACK, "wool", lambda p: "head" if p[1] > 1.6 else "chest", n=40, t0=math.radians(38), t1=TAU - math.radians(38))
    g.ball(H + V(0, 0.09, 0.0), 0.125, DARK, "iron", "head", n=10, sy=1.15)
    eyes(g, 1.735, -0.116, 0.047, 0.017, (1.0, 0.72, 0.36, 0.0))

    def brow(u, v):
        th = (u - 0.5) * math.radians(120)
        y = 1.765 + 0.06 * v - 0.012 * math.cos(th * 3.0) * (1.0 - v)
        r = 0.135 - 0.012 * v
        return V(math.sin(th) * r, y, -math.cos(th) * r * 1.02)
    g.plate(brow, 15, 4, BONE, "bone", "head")

    def jaw(u, v):
        th = (u - 0.5) * math.radians(88)
        tooth = abs(((u * 9.0) % 1.0) - 0.5) * 2.0                       # 0 at a tooth's tip, 1 in the gap
        top = 1.705 - 0.022 * tooth * (1.0 - abs(u - 0.5) * 1.2)
        y = top - (top - 1.585 - 0.02 * abs(u - 0.5)) * v
        r = 0.134 - 0.05 * v ** 1.6
        return V(math.sin(th) * r, y, -math.cos(th) * r * 1.04)
    g.plate(jaw, 37, 6, BONE, "bone", "head")
    for sx in (-1, 1):                                                    # cheek plates up to the brow
        def cheek(u, v, sx=sx):
            th = sx * (math.radians(46) + u * math.radians(34))
            y = 1.6 + 0.18 * v
            r = 0.136
            return V(math.sin(th) * r, y, -math.cos(th) * r * 1.03)
        g.plate(cheek, 5, 5, BONE, "bone", "head", flip=sx > 0)
    g.tube([V(0.0, 1.765, -0.14), V(0.0, 1.72, -0.15), V(0.0, 1.7, -0.139)], [0.012, 0.01, 0.006], BONE, "bone", "head", n=6)      # the nasal bar
    # the mitre: two peaked plates with a cleft, an orphrey up each, a circlet, lappets behind
    for s in (-1, 1):
        def horn(u, v, s=s):
            th = (u - 0.5) * math.radians(170)
            w = (1.0 + 0.1 * v / 0.5) if v < 0.5 else 1.1 * (1.0 - (v - 0.5) / 0.5) ** 0.9       # straight sides, then the peak
            r = 0.16
            return V(math.sin(th) * r * w, 1.83 + 0.5 * v, s * (-math.cos(th) * r * (0.55 + 0.45 * min(w, 1.0)) * 0.8) + 0.01)
        g.plate(horn, 13, 9, BONE, "bone", "head", flip=s > 0)
        g.band([V(0.0, 1.83 + 0.5 * v, s * -0.128 * (0.55 + 0.45 * min((1.0 + 0.2 * v) if v < 0.5 else 1.1 * (1.0 - (v - 0.5) / 0.5) ** 0.9, 1.0)) + 0.01) for v in np.linspace(0.02, 0.95, 9)],
               0.055, GOLD, "trim", "head", out=0.005, up=[V(0, 0, -s)] * 9)
    g.ring_band(1.81, 1.875, 0.156, 0.13, 0.01, GOLD, "trim", "head", n=40)
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
    c.tube(crook, [0.016] * 3 + [0.016 - 0.008 * k / 39 for k in range(40)], GOLD, "gilt", "hand_r", n=10)
    c.ball(crook[-1], 0.02, (1.0, 0.75, 0.4, 0.0), "glow", "hand_r", n=6)
    for k in range(4):
        c.lathe([(0.02, 0.0), (0.024, 0.012), (0.02, 0.024)], V(0, -0.3 + 0.33 * k, -0.035), GOLD, "gilt", "hand_r", n=10)
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
        t = "l" if sx < 0 else "r"
        sleeve(g, sx, LINEN, GOLD, r_top=0.08, r_cuff=0.15, drop=0.2)
        g.tube([V(sx * 0.24, 0.98, 0), V(sx * 0.24, 0.8, 0)], [0.026, 0.021], ASH, "bone", "elbow_" + t, n=6)
        g.lathe([(0.03, 0.0), (0.034, 0.02), (0.03, 0.08), (0.034, 0.1)], V(sx * 0.24, 0.82, 0), GOLD, "gilt", "elbow_" + t, n=10)
        hand(g, sx, ASH, "hand_" + t, closed=0.1)
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


BUILDERS = {"bone_abbot": bone_abbot, "ascended_warden": ascended_warden}


def build(name):
    return BUILDERS[name]()
