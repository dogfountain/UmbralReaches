"""Shared sculpting helpers for the four modelled bosses (Bone Abbot, Ascended Warden, Hierarch,
Anchoress). Nothing here changes boss_kit / grunt_kit / grunt_body; it builds on them.

  Garment    draped cloth as a parametric surface: a silhouette from keyed superellipse sections,
             pleats that start at the shoulders / belt and widen to the hem (rounded ridges, sharp creases,
             folds that branch), a hem that rides the folds and pools on the ground, an open front that
             rolls back into lapels. Evaluated at any resolution, so a dense copy bakes the normal map of
             the low-poly game mesh.
  trim       raised bands (orphreys, hem bands) that follow a garment's surface
  weights    skin weights for cloth over the rig's bones
  posed      renders of the skinned model with the rig bent (arms overhead, kneeling, a stride)
Rig space is Godot's (+Y up, the body faces -Z); Blender space is boss_kit.G(x, y, z).
"""
import bpy
import bmesh
import math
import os
import sys
import numpy as np
from mathutils import Vector, Matrix

sys.path.insert(0, os.path.dirname(__file__))
import boss_kit as K
import grunt_kit as GK
import grunt_body as GB
from boss_kit import G

FRONT = -math.pi * 0.5          # the angle of the front (-Z) in a section's parameter


def sstep(e0, e1, x):
    if e1 - e0 < 1e-9:
        return (np.asarray(x, dtype=np.float64) >= e1).astype(np.float64)
    t = np.clip((np.asarray(x, dtype=np.float64) - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def _cr(keys, y):
    """Catmull-Rom through the keys (y, cx, cz, a, f, b, e) evaluated at y (array)."""
    keys = sorted(keys)
    ys = np.array([k[0] for k in keys])
    out = np.zeros((len(y), 6))
    idx = np.clip(np.searchsorted(ys, y) - 1, 0, len(keys) - 2)
    for n, (yy, i) in enumerate(zip(y, idx)):
        p0 = np.array(keys[max(i - 1, 0)][1:])
        p1 = np.array(keys[i][1:])
        p2 = np.array(keys[i + 1][1:])
        p3 = np.array(keys[min(i + 2, len(keys) - 1)][1:])
        t = (yy - keys[i][0]) / max(keys[i + 1][0] - keys[i][0], 1e-9)
        t = min(max(t, 0.0), 1.0)
        out[n] = 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3)
    return out


class Garment:
    """A draped garment, a surface surf(u, v) -> rig-space points. u runs round the body (0..1), v from the
    top (0) to the hem (1).

    keys      silhouette sections (y, cx, cz, half-width a, front depth f, back depth b, exponent e) from the top
              of the garment down to below the hem (the cloth is cut at `hem`)
    top, hem  y of the first ring; the hem's y (float, or fn of the angle)
    folds     [(k, w_top, w_hem, phase, swirl)]: k pleat pairs round the body (cos(k t / 2)) with that weight at
              the top and at the hem; swirl twists them down the garment
    amp       fold depth in metres (times each layer's weight)
    ramp      (v0, v1): the folds are nil above v0 and full below v1
    gap       half angle of the front opening (radians); gap_from the v where it begins
    lay       how much of the hem's last stretch lies on the floor (fraction of v), lay_r how far it spreads
    flare     extra radius at the opening's edges (a lapel rolling back)
    """

    def __init__(self, keys, top, hem, folds, amp=0.04, ramp=(0.0, 0.5), gap=0.0, gap_from=0.0, lay=0.06, lay_r=0.05,
                 floor=0.012, hem_lift=0.04, flare=0.0, warp=0.55, hem_fn=None, seed=0.0, front=FRONT, thick=0.0,
                 micro=0.0, micro_k=47.0, tongues=None, back_drop=0.0, top_fn=None):
        self.keys = keys
        self.top = top
        self.hem = hem
        self.folds = folds
        self.amp = amp
        self.ramp = ramp
        self.gap = gap
        self.gap_from = gap_from
        self.lay = lay
        self.lay_r = lay_r
        self.floor = floor
        self.hem_lift = hem_lift
        self.flare = flare
        self.warp = warp
        self.hem_fn = hem_fn
        self.seed = seed
        self.front = front
        self.micro = micro
        self.micro_k = micro_k
        self.tongues = tongues
        self.back_drop = back_drop
        self.top_fn = top_fn
        ys = np.linspace(min(k[0] for k in keys), max(k[0] for k in keys), 360)
        self._ys = ys
        self._tab = _cr(keys, ys)

    def sect(self, y):
        out = np.zeros(y.shape + (6,))
        for j in range(6):
            out[..., j] = np.interp(y, self._ys, self._tab[:, j])
        return out

    def pleats(self, t, v):
        out = np.zeros_like(t)
        for (k, w0, w1, ph, sw) in self.folds:
            ph = ph + self.seed
            warp = self.warp * (0.5 * np.sin(2.0 * t + 3.0 * v + ph) + 0.3 * np.sin(5.0 * t - 2.1 * v + ph * 1.7)
                                + 0.2 * np.sin(11.0 * t + 4.0 * v - ph))
            arg = 0.5 * k * (t + sw * v) + warp + ph
            c = np.abs(np.cos(arg))                   # rounded ridges, sharp V creases where cos = 0
            out += (w0 * (1.0 - v) + w1 * v) * (c - 0.64)
        return out

    def hem_y(self, t):
        if self.hem_fn is not None:
            return self.hem_fn(t)
        base = np.full_like(t, float(self.hem))
        h = base + self.hem_lift * self.pleats(t, np.ones_like(t)) * 1.0
        if self.tongues:
            n, depth, sharp = self.tongues
            tt = np.abs(np.cos(0.5 * n * (t + self.seed)))
            h = h + depth * (1.0 - tt ** sharp) * 1.0 - depth * 0.5
        # a train: the back hangs longer
        if self.back_drop:
            h = h - self.back_drop * sstep(0.0, 1.0, 0.5 + 0.5 * np.sin(t - self.front - math.pi * 0.5 + math.pi))
        return h

    def surf(self, u, v):
        """u, v arrays of one shape -> rig-space points (shape + (3,)) and outward directions."""
        u = np.asarray(u, dtype=np.float64)
        v = np.asarray(v, dtype=np.float64)
        closed = self.gap <= 0.0
        g = self.gap * sstep(self.gap_from, self.gap_from + 0.14, v) if not closed else np.zeros_like(v)
        span = 2.0 * math.pi - 2.0 * g
        t = self.front + g + (u * 2.0 * math.pi if closed else u * span)
        yh = self.hem_y(t)
        yt = self.top + (self.top_fn(t) if self.top_fn is not None else 0.0)
        y = yt + (yh - yt) * v
        # the last stretch of cloth lies on the ground, spreading
        wl = sstep(1.0 - self.lay, 1.0, v) if self.lay > 0.0 else np.zeros_like(v)
        y = y * (1.0 - wl) + (self.floor + 0.004 * np.sin(t * 7.0 + self.seed)) * wl
        sec = self.sect(yt + (yh - yt) * v)
        cx, cz, a, f, b, e = [sec[..., j] for j in range(6)]
        c, s = np.cos(t), np.sin(t)
        ex = 2.0 / np.maximum(e, 0.5)
        x = cx + a * np.sign(c) * np.abs(c) ** ex
        d = np.where(s < 0, f, b)
        z = cz + d * np.sign(s) * np.abs(s) ** ex
        rx, rz = x - cx, z - cz
        rl = np.maximum(np.hypot(rx, rz), 1e-6)
        ux, uz = rx / rl, rz / rl
        rr = self.ramp
        r = sstep(rr[0], rr[1], v)
        disp = self.amp * r * self.pleats(t, v)
        if self.micro > 0.0:
            disp = disp + self.micro * r * (np.abs(np.cos(0.5 * self.micro_k * t + 2.0 * np.sin(3.0 * t + 5.0 * v) + 9.0 * v)) - 0.64) \
                + self.micro * 0.5 * np.sin(self.micro_k * 0.37 * t + 61.0 * v)
        if self.flare > 0.0 and not closed:
            edge = np.clip(1.0 - np.minimum(u, 1.0 - u) / 0.08, 0.0, 1.0) * sstep(self.gap_from, self.gap_from + 0.2, v)
            disp = disp + self.flare * edge * edge
        disp = disp + self.lay_r * wl * wl
        x = x + ux * disp
        z = z + uz * disp
        return np.stack([x, y, z], axis=-1), np.stack([ux, np.zeros_like(ux), uz], axis=-1)

    def grid(self, n, m, v0=0.0, v1=1.0, u0=0.0, u1=None, off=0.0):
        """Points of an n x m grid -> ((rows, cols, 3) rig space, wrap). A closed garment's full turn wraps
        (the last column is not repeated); anything else (a part of the turn, an open garment) has n + 1 columns."""
        closed = self.gap <= 0.0
        full = closed and u0 == 0.0 and (u1 is None or u1 == 1.0)
        if u1 is None:
            u1 = 1.0
        us = (u0 + (u1 - u0) * np.arange(n) / n) if full else np.linspace(u0, u1, n + 1)
        vs = np.linspace(v0, v1, m + 1)
        U, V = np.meshgrid(us, vs)
        P, N = self.surf(U, V)
        if off != 0.0:
            P = P + N * off
        return P, full

    def mesh(self, name, n, m, sock, mat, v0=0.0, v1=1.0, u0=0.0, u1=None, off=0.0, smooth=True):
        P, wrap = self.grid(n, m, v0, v1, u0, u1, off)
        return grid_mesh(name, P, wrap, sock, mat, smooth)

    def hem_points(self, n=240, off=0.0):
        P, _ = self.grid(n, 1, 1.0, 1.0, off=off)
        return [Vector(G(*p)) for p in P[0]]


def scale_about(objs, c, k):
    """Scale objects about the Blender point c (applied to the mesh)."""
    for o in objs:
        for v in o.data.vertices:
            v.co = Vector(c) + (v.co - Vector(c)) * k
        o.data.update()


def grid_mesh(name, P, wrap, sock, mat, smooth=True):
    """Quads from a (rows, cols, 3) rig-space grid; wrap joins the last column to the first."""
    rows, cols = P.shape[0], P.shape[1]
    vs = [tuple(G(*p)) for p in P.reshape(-1, 3)]
    faces = []
    nc = cols if wrap else cols - 1
    for i in range(rows - 1):
        for j in range(nc):
            j1 = (j + 1) % cols
            faces.append((i * cols + j, i * cols + j1, (i + 1) * cols + j1, (i + 1) * cols + j))
    me = bpy.data.meshes.new(name)
    me.from_pydata(vs, [], faces)
    me.update()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    ob["sock"] = sock
    if mat is not None:
        me.materials.append(mat.m if hasattr(mat, "m") else mat)
    # outward-facing normals: the garment's rows run top to bottom, columns counter-clockwise from above
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = smooth
    return ob


def tri_count(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


def shell(g, name, sock, mat, tris, hi_res=(300, 190), solid=0.0, ratio_floor=0.02):
    """A garment as (low, high): the high is a dense evaluation with micro folds, the low its decimation
    to about `tris` triangles (solidified when `solid` > 0 for open cloth). Returns (low, high)."""
    n, m = hi_res
    hi = g.mesh(name + "High", n, m, sock, mat)
    hi.hide_render = True
    hi.hide_viewport = True
    lo = hi.copy()
    lo.data = hi.data.copy()
    lo.name = name
    lo.data.name = name
    lo.hide_render = False
    lo.hide_viewport = False
    bpy.context.scene.collection.objects.link(lo)
    nt = tri_count(lo)
    bpy.ops.object.select_all(action='DESELECT')
    lo.select_set(True)
    bpy.context.view_layer.objects.active = lo
    d = lo.modifiers.new("Dec", 'DECIMATE')
    d.ratio = max(ratio_floor, min(1.0, tris / max(nt, 1)))
    d.use_collapse_triangulate = True
    K.apply_mods(lo)
    if solid > 0.0:
        K.solidify(lo, solid)
    for p in lo.data.polygons:
        p.use_smooth = True
    lo["sock"] = sock
    lo["fixed"] = True
    print("SHELL", name, "tris", tri_count(lo), "from", nt)
    return lo, hi


def band(g, name, sock, mat, v0, v1, u0=0.0, u1=1.0, n=160, m=8, off=0.004, raise_to=None):
    """A raised band following the garment's surface between (u0..u1, v0..v1)."""
    P, wrap = g.grid(n, m, v0, v1, u0, u1, off)
    ob = grid_mesh(name, P, wrap, sock, mat)
    if raise_to:
        K.solidify(ob, raise_to)
    return ob


def ribbon(g, name, sock, mat, path, width, n=40, off=0.008, closed_ends=True):
    """A band along a path of (u, v) points on the garment (width in u units): a diagonal orphrey, a Y."""
    pts = np.array(path, dtype=np.float64)
    seg = np.linspace(0.0, 1.0, n)
    idx = np.linspace(0, len(pts) - 1, n)
    uu = np.interp(idx, np.arange(len(pts)), pts[:, 0])
    vv = np.interp(idx, np.arange(len(pts)), pts[:, 1])
    cols = 4
    P = np.zeros((n, cols, 3))
    for c in range(cols):
        w = (c / (cols - 1) - 0.5) * width
        pp, nn = g.surf(uu + w, vv)
        P[:, c, :] = pp + nn * off
    return grid_mesh(name, P, False, sock, mat)


def beads(g, name, sock, mat, v, u0, u1, count, r, off=0.006, sy=1.0):
    """Studs / gems set along a line of the garment's surface."""
    us = np.linspace(u0, u1, count)
    P, N = g.surf(us, np.full_like(us, v))
    out = []
    for p, nn in zip(P, N):
        q = Vector(G(*(p + nn * off)))
        out.append(K.blob(name, q, (r, r, r * sy), sock, mat, 10, 6))
    return out


# --- weights ------------------------------------------------------------------------------------------

BODY_SOCKS = ["pelvis", "chest", "head", "shoulder_l", "elbow_l", "hand_l", "shoulder_r", "elbow_r", "hand_r",
              "hip_l", "knee_l", "foot_l", "hip_r", "knee_r", "foot_r"]


def segs(extra=None):
    """The rig's bones as segments (bone, rig a, rig b) for envelope weights."""
    s = [("pelvis", (0, 0.80, 0), (0, 1.10, 0)), ("chest", (0, 1.10, 0), (0, 1.50, 0.0))]
    for sx, tag in ((-1, "l"), (1, "r")):
        ax = sx * 0.24
        s += [("shoulder_" + tag, (ax, 1.40, 0), (ax, 1.08, 0)), ("elbow_" + tag, (ax, 1.08, 0), (ax, 0.78, 0)),
              ("hand_" + tag, (ax, 0.78, 0), (ax, 0.60, -0.03)), ("chest", (0, 1.44, 0), (sx * 0.2, 1.43, 0)),
              ("hip_" + tag, (sx * 0.11, 0.80, 0), (sx * 0.11, 0.34, 0)), ("knee_" + tag, (sx * 0.11, 0.34, 0), (sx * 0.11, 0.07, 0)),
              ("foot_" + tag, (sx * 0.11, 0.07, 0.02), (sx * 0.11, 0.02, -0.15))]
    return s + (extra or [])


def skirt_weights(waist=1.05, hips=0.9, knee_y=0.42, gain=1.0):
    """A skirt / robe that hangs from the waist: pelvis at the belt, then the nearer leg, then the knee."""
    def fn(p):
        y = p.z
        w = {}
        up = GK._smooth(waist - 0.02, waist + 0.14, y)          # above the belt it follows the chest
        if up > 0.0:
            w["chest"] = up
        body = 1.0 - up
        for tag, sx in (("l", -1.0), ("r", 1.0)):
            side = GK._smooth(-0.06, 0.12, p.x * sx)
            a = GK._smooth(hips, hips - 0.28, y)                 # how far down the hip bone owns it
            b = GK._smooth(knee_y + 0.14, knee_y - 0.12, y)
            if a > 0.0:
                w["hip_" + tag] = body * a * side * (1.0 - b) * gain
                if b > 0.0:
                    w["knee_" + tag] = body * a * side * b * gain
        used = sum(w.values())
        w["pelvis"] = max(body - (used - w.get("chest", 0.0)), 0.0)
        t = sum(w.values()) or 1.0
        return {k: v / t for k, v in w.items() if v / t > 0.004}
    return fn


def sleeve_weights(tag):
    """A sleeve: the chest at the shoulder, the shoulder bone to the elbow, the elbow bone below."""
    sx = -1.0 if tag == "l" else 1.0
    chain = [("chest", G(sx * 0.12, 1.43, 0)), ("shoulder_" + tag, G(sx * 0.24, 1.40, 0)), ("elbow_" + tag, G(sx * 0.24, 1.08, 0)),
             ("hand_" + tag, G(sx * 0.24, 0.78, 0))]
    return lambda p: GK.chain_w(p, chain, [0.04, 0.06, 0.05])


def cape_weights(sleeve_bleed=0.5):
    """A cape / cope hung from the shoulders: the chest owns it, the shoulder bones lend a share toward the
    sides, the head a little at the collar, the pelvis lower down (it hangs behind the legs)."""
    def fn(p):
        y = p.z
        w = {"chest": 1.0}
        for tag, sx in (("l", -1.0), ("r", 1.0)):
            a = GK._smooth(0.12, 0.3, p.x * sx) * sleeve_bleed * GK._smooth(1.0, 1.4, y)
            if a > 0.0:
                w["shoulder_" + tag] = a
        h = GK._smooth(1.50, 1.64, y) * 0.8
        if h > 0.0:
            w["head"] = h
        lo = GK._smooth(1.18, 0.78, y)                           # below the chest it rides the pelvis and hips
        if lo > 0.0:
            w["pelvis"] = lo * 0.7
            for tag, sx in (("l", -1.0), ("r", 1.0)):
                sd = GK._smooth(-0.05, 0.12, p.x * sx)
                kn = GK._smooth(0.7, 0.35, y)
                w["hip_" + tag] = lo * 0.45 * sd * (1.0 - kn) * GK._smooth(0.95, 0.7, y)
        w["chest"] = max(w["chest"] - sum(v for k, v in w.items() if k != "chest") * 0.5, 0.15)
        t = sum(w.values())
        return {k: v / t for k, v in w.items() if v / t > 0.004}
    return fn


def cope_weights(shoulder=0.5):
    """A cope that stays gathered round the body: the chest above; lower down the pelvis, a share of the chest (so the cloth
    leans over with the trunk like a cape on a shoulder line, not swung out on the pelvis's long lever) and the thighs
    (so a kneeling or toppled figure keeps the cloth over its legs); no knee weight, which flung the hem behind the shin."""
    def fn(p):
        y = p.z
        w = {"chest": 1.0}
        for tag, sx in (("l", -1.0), ("r", 1.0)):
            a = GK._smooth(0.12, 0.3, p.x * sx) * shoulder * GK._smooth(1.0, 1.4, y)
            if a > 0.0:
                w["shoulder_" + tag] = a
        h = GK._smooth(1.50, 1.64, y) * 0.8
        if h > 0.0:
            w["head"] = h
        lo = GK._smooth(1.2, 0.7, y)
        if lo > 0.0:
            w["pelvis"] = lo * 1.1
            for tag, sx in (("l", -1.0), ("r", 1.0)):
                sd = GK._smooth(-0.1, 0.2, p.x * sx)
                w["hip_" + tag] = lo * 0.35 * sd * GK._smooth(0.95, 0.55, y)
        # the chest keeps a floor all the way down: the cloth hangs from the shoulders
        w["chest"] = max(w["chest"] - sum(v for k, v in w.items() if k != "chest") * 0.5, 0.35 if lo > 0.0 else 0.05)
        t = sum(w.values())
        return {k: v / t for k, v in w.items() if v / t > 0.004}
    return fn


def rigid(bone):
    return lambda p: {bone: 1.0}


# --- sculpted solid parts (body, skull, mask) ------------------------------------------------------------------

def sculpted(name, sk, root, mat, sock, tris, sculpt_fn, voxel=0.005, bodyonly=True, pairs=None):
    """A Skel -> one fused surface (voxel remesh), sculpted by sculpt_fn(S), then (low, high) for the bake."""
    hi = GB.build_skin(sk, name + "High", root, voxel)
    s = GB.Sculpt(hi)
    sculpt_fn(s)
    s.apply()
    hi.data.materials.append(mat.m if hasattr(mat, "m") else mat)
    hi.hide_render = True
    hi.hide_viewport = True
    lo = GB.make_low(hi, tris, name)
    lo["sock"] = sock
    lo["fixed"] = True
    if bodyonly:
        lo["bodyonly"] = True
    if pairs is not None:
        pairs.append((lo, hi))
    return lo, hi


# --- review renders ---------------------------------------------------------------------------------------------------

def _lights_and_camera(target_z, dist, w=900, h=1200):
    sc = bpy.context.scene
    world = bpy.data.worlds.new("RW")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.02, 0.025, 0.04, 1.0)
    sc.world = world
    tgt = bpy.data.objects.new("__tgt", None)
    tgt.location = (0, 0, target_z)
    sc.collection.objects.link(tgt)
    objs = [tgt]

    def light(name, kind, loc, energy, col, size):
        ld = bpy.data.lights.new(name, kind)
        ld.energy = energy
        ld.color = col
        ld.size = size
        lo = bpy.data.objects.new(name, ld)
        lo.location = loc
        sc.collection.objects.link(lo)
        tr = lo.constraints.new('TRACK_TO')
        tr.target = tgt
        tr.track_axis = 'TRACK_NEGATIVE_Z'
        tr.up_axis = 'UP_Y'
        objs.append(lo)
    light("Key", 'AREA', (-3.0, 3.5, 4.5), 900.0, (0.65, 0.75, 1.0), 2.5)
    light("Fill", 'AREA', (3.0, 2.5, 1.5), 260.0, (1.0, 0.7, 0.42), 2.0)
    light("Rim", 'AREA', (1.0, -4.0, 3.5), 700.0, (0.7, 0.75, 1.0), 2.0)
    floor = bpy.data.meshes.new("RFloor")
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=7.0)
    bm.to_mesh(floor)
    bm.free()
    fo = bpy.data.objects.new("RFloor", floor)
    fo.location = (0, 0, -0.1)
    sc.collection.objects.link(fo)
    fm = bpy.data.materials.new("RFloorM")
    fm.use_nodes = True
    fm.node_tree.nodes["Principled BSDF"].inputs['Base Color'].default_value = (0.1, 0.1, 0.11, 1)
    floor.materials.append(fm)
    objs.append(fo)
    cd = bpy.data.cameras.new("RCam")
    cd.lens = 55
    cam = bpy.data.objects.new("RCam", cd)
    sc.collection.objects.link(cam)
    sc.camera = cam
    tr = cam.constraints.new('TRACK_TO')
    tr.target = tgt
    tr.track_axis = 'TRACK_NEGATIVE_Z'
    tr.up_axis = 'UP_Y'
    objs.append(cam)
    sc.render.resolution_x = w
    sc.render.resolution_y = h
    sc.view_settings.view_transform = 'AgX'
    return cam, objs


def turnarounds(prefix, target_z=1.1, dist=4.6, angles=(("front", 90), ("side", 0), ("three", 45), ("back", -90)), samples=48,
                size=(900, 1200), cam_z=1.4):
    """Cycles stills of the scene as it stands (skinned model in rest pose or posed) from several angles."""
    sc = bpy.context.scene
    sc.cycles.samples = samples
    cam, objs = _lights_and_camera(target_z, dist, *size)
    for nm, ang in angles:
        a = math.radians(ang)
        cam.location = (math.cos(a) * dist, math.sin(a) * dist, cam_z)
        sc.render.filepath = "%s_%s.png" % (prefix, nm)
        bpy.ops.render.render(write_still=True)
        print("RENDER", sc.render.filepath)
    for o in objs:
        bpy.data.objects.remove(o)


# the rig's joint hierarchy (socket -> parent) for posing the bones as the game's sockets do
PARENT = {"chest": "pelvis", "head": "chest", "shoulder_l": "chest", "elbow_l": "shoulder_l", "hand_l": "elbow_l",
          "shoulder_r": "chest", "elbow_r": "shoulder_r", "hand_r": "elbow_r", "hip_l": "pelvis", "knee_l": "hip_l",
          "foot_l": "knee_l", "hip_r": "pelvis", "knee_r": "hip_r", "foot_r": "knee_r"}
ORDER = ["pelvis", "chest", "head", "shoulder_l", "elbow_l", "hand_l", "shoulder_r", "elbow_r", "hand_r",
         "hip_l", "knee_l", "foot_l", "hip_r", "knee_r", "foot_r"]


def pose(arm, rots, shift=None):
    """Bend the flat armature the way the rig's sockets move: rots {socket: (rx, ry, rz) radians in rig space
    (x pitch forward-back, y turn, z roll)} about each joint, composed down the hierarchy."""
    shift = shift or {}
    world = {}
    for nm in ORDER:
        j = Vector(K.SOCKETS[nm])
        rx, ry, rz = rots.get(nm, (0.0, 0.0, 0.0))
        # rig space -> blender: rig x -> x, rig y -> z, rig z -> -y
        e = Matrix.Rotation(rx, 4, 'X') @ Matrix.Rotation(-rz, 4, 'Y') @ Matrix.Rotation(ry, 4, 'Z')
        m = Matrix.Translation(j + Vector(shift.get(nm, (0, 0, 0)))) @ e @ Matrix.Translation(-j)
        par = PARENT.get(nm)
        world[nm] = (world[par] @ m) if par else m
    for pb in arm.pose.bones:
        if pb.name in world:
            pb.matrix = world[pb.name] @ pb.bone.matrix_local
    bpy.context.view_layer.update()


def reset_pose(arm):
    for pb in arm.pose.bones:
        pb.rotation_mode = 'QUATERNION'
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.location = (0, 0, 0)
    bpy.context.view_layer.update()


POSES = {
    # arms thrown overhead for the wind-up (positive pitch swings a limb forward), the chest arched, head back
    "windup": {"shoulder_l": (math.radians(160), 0, math.radians(-8)), "shoulder_r": (math.radians(160), 0, math.radians(8)),
               "elbow_l": (math.radians(25), 0, 0), "elbow_r": (math.radians(25), 0, 0), "chest": (math.radians(12), 0, 0),
               "head": (math.radians(14), 0, 0)},
    # down on both knees, the body folded forward
    "kneel": {"hip_l": (math.radians(85), 0, 0), "hip_r": (math.radians(85), 0, 0), "knee_l": (math.radians(-150), 0, 0),
              "knee_r": (math.radians(-150), 0, 0), "chest": (math.radians(-18), 0, 0), "head": (math.radians(-10), 0, 0),
              "shoulder_l": (math.radians(30), 0, 0), "shoulder_r": (math.radians(30), 0, 0)},
    # the death: down on the knees and pitched over (the rig's collapse, frozen near its end)
    "fall": {"pelvis": (math.radians(55), 0, 0), "hip_l": (math.radians(70), 0, 0), "hip_r": (math.radians(70), 0, 0), "knee_l": (math.radians(-130), 0, 0),
             "knee_r": (math.radians(-130), 0, 0), "chest": (math.radians(35), 0, 0), "head": (math.radians(10), 0, 0)},
    # mid stride, arms swinging
    "stride": {"hip_l": (math.radians(32), 0, 0), "knee_l": (math.radians(-12), 0, 0), "hip_r": (math.radians(-26), 0, 0),
               "knee_r": (math.radians(-50), 0, 0), "shoulder_l": (math.radians(-28), 0, math.radians(-6)),
               "shoulder_r": (math.radians(34), 0, math.radians(6)), "elbow_r": (math.radians(40), 0, 0),
               "chest": (math.radians(5), math.radians(8), 0)},
}


if os.environ.get("BOSS_POSES"):          # pose checks: BOSS_POSES=kneel,fall renders only those
    POSES = {k: v for k, v in POSES.items() if k in os.environ["BOSS_POSES"].split(",")}


def use_atlas(prefix, tex_dir=None):
    """Review: give every mesh the baked atlas as one material (what the engine shows), so posed renders
    show the real maps. Run after the export."""
    if os.environ.get("BOSS_NOBAKE"):
        return                      # pose check without a bake: the procedural materials stay
    tex_dir = tex_dir or os.path.join(os.path.dirname(__file__), "..", "..", "art", "textures")
    m = bpy.data.materials.new("Atlas")
    m.use_nodes = True
    nt = m.node_tree
    bs = nt.nodes["Principled BSDF"]

    def img(key, cs):
        t = nt.nodes.new('ShaderNodeTexImage')
        im = bpy.data.images.load(os.path.join(tex_dir, "%s_%s.png" % (prefix, key)), check_existing=False)
        im.colorspace_settings.name = cs
        t.image = im
        return t
    al, no, orm, em = img("albedo", 'sRGB'), img("normal", 'Non-Color'), img("orm", 'Non-Color'), img("emit", 'sRGB')
    nm = nt.nodes.new('ShaderNodeNormalMap')
    nt.links.new(no.outputs['Color'], nm.inputs['Color'])
    sp = nt.nodes.new('ShaderNodeSeparateColor')
    nt.links.new(orm.outputs['Color'], sp.inputs[0])
    nt.links.new(al.outputs['Color'], bs.inputs['Base Color'])
    nt.links.new(nm.outputs['Normal'], bs.inputs['Normal'])
    nt.links.new(sp.outputs[1], bs.inputs['Roughness'])
    nt.links.new(sp.outputs[2], bs.inputs['Metallic'])
    nt.links.new(em.outputs['Color'], bs.inputs['Emission Color'])
    bs.inputs['Emission Strength'].default_value = 3.0
    for o in bpy.data.objects:
        if o.type == 'MESH' and not o.hide_render:
            o.data.materials.clear()
            o.data.materials.append(m)


def drop_highs(pairs):
    """The dense bake sources are not needed once baked (or for a raw look): free them, the GPU renders run out of memory with them."""
    for _lo, hi in pairs:
        try:
            me = hi.data
            bpy.data.objects.remove(hi)
            bpy.data.meshes.remove(me)
        except ReferenceError:
            pass


def thorn(name, p0, d, length, w0, bend, sock, mat, sides=5, n=7, flat=0.6):
    """A tapering curved thorn / blade from Blender point p0 along direction d, bending toward `bend`
    (a vector, metres of sideways travel at the tip)."""
    d = Vector(d).normalized()
    p0 = Vector(p0)
    pts, rad = [], []
    for k in range(n):
        t = k / (n - 1)
        pts.append(p0 + d * length * t + Vector(bend) * t * t)
        rad.append((max(w0 * (1.0 - t) ** 0.85, 0.0007), max(w0 * flat * (1.0 - t) ** 0.85, 0.0007)))
    return K.loft(name, pts, rad, sock, mat, sides)


def torso_skel(W=1.0, neck=0.04, top=1.62, waist=0.9):
    """The torso and neck as one lofted skin surface (a robe hides the rest): hips to the base of the skull."""
    sk = GB.Skel()
    sk.loft([(0.78, 0, 0.0, 0.06 * W, 0.05, 0.05, 2.0), (0.84, 0, 0.0, 0.1 * W, 0.07, 0.08, 2.2), (0.95, 0, 0.0, 0.125 * W, 0.08, 0.09, 2.2),
             (1.05, 0, 0.0, 0.115 * W * waist, 0.075, 0.085, 2.2), (1.15, 0, 0.0, 0.13 * W, 0.085, 0.09, 2.2),
             (1.26, 0, 0.005, 0.145 * W, 0.095, 0.095, 2.05), (1.36, 0, 0.01, 0.155 * W, 0.1, 0.1, 2.1), (1.43, 0, 0.012, 0.16 * W, 0.092, 0.095, 2.25),
             (1.47, 0, 0.012, 0.15 * W, 0.075, 0.09, 2.2), (1.5, 0, 0.01, 0.12 * W, 0.064, 0.08, 2.0), (1.535, 0, 0.0, 0.085 * W, 0.058, 0.07, 2.0),
             (1.57, 0, -0.01, neck * 1.2, neck * 1.08, neck * 1.2, 2.0), (top, 0, -0.02, neck, neck, neck * 1.05, 2.0)])
    sk.v("pel", (0, 0.9, 0), 0.03)
    sk.v("wst", (0, 1.04, 0), 0.03, "pel")
    return sk


# --- bake + export (copies of grunt_kit's, faster: parts joined per socket, AO in one pass) ----------------------------

def consolidate(objs, pairs):
    """Join the loose parts that share a skin-weight key (the lows of the bake pairs stay as they are), so the
    bake handles tens of objects, not hundreds. Returns the new list."""
    lows = {lo.name for lo, _ in pairs}
    groups = {}
    rest = []
    for o in objs:
        if o.name in lows or o.get("fixed"):
            rest.append(o)
        else:
            groups.setdefault(o["sock"], []).append(o)
    out = list(rest)
    for sock, g in groups.items():
        bpy.ops.object.select_all(action='DESELECT')
        for o in g:
            o.select_set(True)
        bpy.context.view_layer.objects.active = g[0]
        if len(g) > 1:
            bpy.ops.object.join()
        ob = bpy.context.view_layer.objects.active
        ob["sock"] = sock
        out.append(ob)
    return out


def fit_budget(objs, budget):
    """No more triangles than the model it replaces (BOSS_TRIS): collapse-decimate the big parts alike (before the bake unwraps
    and bakes them: the highs carry the detail into the maps, which then fit what is exported); the small parts stay."""
    if budget <= 0:
        return objs
    t = lambda o: sum(len(p.vertices) - 2 for p in o.data.polygons)
    total = sum(t(o) for o in objs)
    if total <= budget:
        print("BUDGET ok", total, "<=", budget)
        return objs
    keep = [k for k in os.environ.get("BOSS_KEEP", "").split(",") if k]     # faces and hands: parts that are not collapsed
    big = [o for o in objs if t(o) >= 1200 and not any(o.name.startswith(k) for k in keep)]
    small = total - sum(t(o) for o in big)
    ratio = max(0.1, (budget - small) / max(total - small, 1))
    for o in big:
        bpy.ops.object.select_all(action='DESELECT')
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
        d = o.modifiers.new("Dec", 'DECIMATE')
        d.ratio = ratio
        bpy.ops.object.modifier_apply(modifier=d.name)
    print("BUDGET", total, "->", sum(t(o) for o in objs), "ratio %.2f" % ratio, "budget", budget)
    return objs


def bake_atlas2(objs, mats, prefix, tex_dir, size, pairs, ao_samples=24):
    import numpy as np
    sc = bpy.context.scene
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.004)
    bpy.ops.uv.pack_islands(margin=0.004)
    bpy.ops.object.mode_set(mode='OBJECT')
    images = {}
    for key, cs in (("albedo", 'sRGB'), ("normal", 'Non-Color'), ("rough", 'Non-Color'), ("metal", 'Non-Color'), ("ao", 'Non-Color'), ("emit", 'sRGB')):
        img = bpy.data.images.new(prefix + "_" + key, size, size, alpha=False, float_buffer=False)
        img.colorspace_settings.name = cs
        images[key] = img
    tex_nodes = []
    for m in mats:
        t = m.nodes.new('ShaderNodeTexImage')
        t.name = "__target"
        m.nodes.active = t
        tex_nodes.append((m, t))
    sc.render.bake.margin = 6
    highs = [h for _, h in pairs]
    for h in highs:
        h.hide_viewport = False
    passes = [("albedo", 'EMIT', "color"), ("rough", 'EMIT', "rough"), ("metal", 'EMIT', "metal"), ("emit", 'EMIT', "emit"),
              ("normal", 'NORMAL', None), ("ao", 'AO', None)]
    import time
    for key, kind, route in passes:
        t0 = time.time()
        for h in highs:
            h.hide_render = True
        for m, t in tex_nodes:
            t.image = images[key]
            m.nodes.active = t
            if route:
                K._route(m, route)
        sc.cycles.samples = ao_samples if kind == 'AO' else 1
        sc.render.bake.use_selected_to_active = False
        bpy.ops.object.select_all(action='DESELECT')
        for o in objs:
            o.select_set(True)
        bpy.context.view_layer.objects.active = objs[0]
        bpy.ops.object.bake(type=kind, use_clear=True, margin=6)
        for m, t in tex_nodes:
            if route:
                K._unroute(m)
        if kind == 'NORMAL':
            for low, high in pairs:
                for h in highs:
                    h.hide_render = (h is not high)
                bpy.ops.object.select_all(action='DESELECT')
                high.select_set(True)
                low.select_set(True)
                bpy.context.view_layer.objects.active = low
                bpy.ops.object.bake(type=kind, use_selected_to_active=True, cage_extrusion=0.02, max_ray_distance=0.06, use_clear=False, margin=6)
        print("BAKED", key, round(time.time() - t0), "s")
        if key == "ao":
            a_ = np.empty(size * size * 4, dtype=np.float32)
            images["ao"].pixels.foreach_get(a_)
            g_ = np.empty(size * size * 4, dtype=np.float32)
            images["rough"].pixels.foreach_get(g_)
            cov_ = g_.reshape(-1, 4)[:, 0] > 0.05
            ao4 = a_.reshape(-1, 4)
            raw = ao4[:, 0]
            black = (raw < 0.05) & cov_
            fb = float(black.sum()) / max(int(cov_.sum()), 1)
            print("AO mean over covered texels", round(float(raw[cov_].mean()) if cov_.any() else 0.0, 3), "pure-black fraction", round(fb, 3))
            if fb > 0.6:
                raise RuntimeError("AO bake is black (%.0f%% of the covered texels are 0): the atlas would render as a black shape" % (fb * 100.0))
            # texels the AO ray started inside other cloth / the back of a solidified shell read 0: those are bake faults, not
            # occlusion, so they go white; and the occlusion that remains is softened (it dims at most 60%)
            ao4[black, 0] = 1.0
            ao4[cov_, 0] = 0.4 + 0.6 * ao4[cov_, 0]
            ao4[cov_, 1] = ao4[cov_, 0]
            ao4[cov_, 2] = ao4[cov_, 0]
            images["ao"].pixels.foreach_set(a_)
            mean_ = float(ao4[cov_, 0].mean()) if cov_.any() else 0.0
            print("AO mean after repair", round(mean_, 3))
            if mean_ < 0.3:
                raise RuntimeError("AO bake is black (mean %.3f): the atlas would render as a black shape" % mean_)
    os.makedirs(tex_dir, exist_ok=True)

    def px(img):
        a = np.empty(size * size * 4, dtype=np.float32)
        img.pixels.foreach_get(a)
        return a.reshape(size, size, 4)
    orm = np.ones((size, size, 4), dtype=np.float32)
    orm[:, :, 0] = px(images["ao"])[:, :, 0]
    orm[:, :, 1] = px(images["rough"])[:, :, 0]
    orm[:, :, 2] = px(images["metal"])[:, :, 0]
    out = bpy.data.images.new(prefix + "_orm", size, size, alpha=False)
    out.colorspace_settings.name = 'Non-Color'
    out.pixels.foreach_set(orm.ravel())
    images["emit"].scale(max(size // 2, 256), max(size // 2, 256))
    for key, img in (("albedo", images["albedo"]), ("normal", images["normal"]), ("orm", out), ("emit", images["emit"])):
        img.filepath_raw = os.path.join(tex_dir, "%s_%s.png" % (prefix, key))
        img.file_format = 'PNG'
        img.save()
        print("SAVED", img.filepath_raw)
    for m, t in tex_nodes:
        m.nodes.remove(t)
    for h in highs:
        h.hide_render = True


def export_skinned2(objs, mats, name, sockets, weights, rigid=None, size=2048, pairs=None):
    """GK.export_skinned with the faster bake: weight every part (weights[o["sock"]] is fn(point) -> {bone: w}), join the
    skinned parts into one "body" on a flat armature, keep `rigid` parts ({sock: (export name, joint)}) separate with their
    origin on the joint, export art/models/<name>.glb."""
    rigid = rigid or {}
    size = min(size, int(os.environ.get("BOSS_SIZE", "2048")))     # no bigger maps than the model it replaces: 2048, the emit map 1024
    tex_dir = os.path.join(os.path.dirname(__file__), "..", "..", "art", "textures")
    blend_dir = os.path.join(os.path.dirname(__file__), "..", "..", "art", "blender")
    objs = consolidate(objs, pairs or [])
    objs = fit_budget(objs, int(os.environ.get("BOSS_TRIS", "0")))
    nobake = bool(os.environ.get("BOSS_NOBAKE"))      # pose / weight checks: no bake, nothing written into art/
    if not nobake:
        bake_atlas2(objs, mats, name, tex_dir, size, pairs or [])
    drop_highs(pairs or [])          # the dense sources are not kept in the .blend
    if not nobake:
        os.makedirs(blend_dir, exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(blend_dir, name + ".blend"))
    arm = GK.armature(sockets)
    skinned, solo = [], {}
    for o in objs:
        if o["sock"] in rigid:
            solo.setdefault(o["sock"], []).append(o)
        else:
            GK.weigh(o, weights[o["sock"]])
            skinned.append(o)
    bpy.ops.object.select_all(action='DESELECT')
    for o in skinned:
        o.select_set(True)
    bpy.context.view_layer.objects.active = skinned[0]
    bpy.ops.object.join()
    body = bpy.context.view_layer.objects.active
    body.name = "body"
    body.data.name = "body"
    body.parent = arm
    md = body.modifiers.new("Armature", 'ARMATURE')
    md.object = arm
    out = [arm, body]
    for sock, group in solo.items():
        bpy.ops.object.select_all(action='DESELECT')
        for o in group:
            o.select_set(True)
        bpy.context.view_layer.objects.active = group[0]
        if len(group) > 1:
            bpy.ops.object.join()
        ob = bpy.context.view_layer.objects.active
        nm, joint = rigid[sock]
        ob.name = nm
        ob.data.name = nm
        bpy.context.scene.cursor.location = joint
        bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
        ob.location = Vector((0, 0, 0))
        out.append(ob)
    bpy.ops.object.select_all(action='DESELECT')
    for o in out:
        o.select_set(True)
    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in out if o.type == 'MESH')
    path = os.path.join(os.path.dirname(__file__), "..", "..", "art", "models", name + ".glb")
    if nobake:
        path = os.path.join(os.environ.get("BOSS_OUT", "/private/tmp"), name + "_nobake.glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True, export_apply=True,
                              export_yup=True, export_materials='NONE', export_normals=True, export_texcoords=True,
                              export_skins=True, export_animations=False, export_all_influences=False)
    print("EXPORTED", path, "tris", tris, "verts", len(body.data.vertices))
