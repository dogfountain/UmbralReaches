"""Helpers for the two-legged enemies (r38 remodel): garments and armour that are FITTED to a sculpted body
instead of stuck on it. Everything works on numpy arrays in rig space (Godot's: +Y up, the body faces -Z)
and makes Blender meshes from them.

  shell()      armour / cloth cut out of the body's own high-poly surface (a region), pushed outwards by a
               thickness field, creased, solidified: a cuirass, a vambrace, a tunic that follows the ribs
  Drape        a loft round the body (tunic -> skirt -> hem) with pleats that hang from the belt and grow
               towards the hem, a torn or scalloped hem cut clean (no stair-steps), thickness
  hood()       a deep cowl with a rolled lip, an opening for the face and a peak, folded
  lathe()      a surface of revolution (bell, helm, pot, cap) with a profile and an optional wobble
  sleeve()     a loose sleeve along an arm (shoulder -> wrist), pleated, hem cut ragged
  hi_lo()      a high-poly part and its decimated game copy (the bake pairs them)
Nothing here changes grunt_kit.py / boss_kit.py: it only calls them.
"""
import bpy
import bmesh
import math
import os
import sys
import numpy as np
from mathutils import Vector

sys.path.insert(0, os.path.dirname(__file__))
import boss_kit as K
from boss_kit import G


# --- numpy <-> blender -------------------------------------------------------------------------------

def to_rig(a):
    return np.stack([a[..., 0], a[..., 2], -a[..., 1]], axis=-1)


def to_bl(a):
    return np.stack([a[..., 0], -a[..., 2], a[..., 1]], axis=-1)


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def hash_noise(P, scale, seed=0.0):
    """Cheap smooth 3D value-ish noise in [-1, 1] (sums of sines): deterministic, no mathutils loop."""
    q = P * scale
    s = seed
    return (np.sin(q[..., 0] * 1.7 + np.sin(q[..., 1] * 2.3 + s) * 1.5) * np.sin(q[..., 1] * 1.3 + np.cos(q[..., 2] * 1.9 + s) * 1.4)
            + np.sin(q[..., 2] * 2.1 + q[..., 0] * 0.7 + s) * np.cos(q[..., 1] * 2.9 + q[..., 0] * 0.4)) * 0.5


def mesh_arrays(ob):
    me = ob.data
    n = len(me.vertices)
    co = np.empty(n * 3, dtype=np.float32)
    me.vertices.foreach_get('co', co)
    nr = np.empty(n * 3, dtype=np.float32)
    me.vertex_normals.foreach_get('vector', nr)
    return co.reshape(n, 3), nr.reshape(n, 3)


def poly_arrays(me):
    npoly = len(me.polygons)
    lt = np.empty(npoly, dtype=np.int32)
    me.polygons.foreach_get('loop_total', lt)
    nl = len(me.loops)
    vi = np.empty(nl, dtype=np.int32)
    me.loops.foreach_get('vertex_index', vi)
    return lt, vi


def link_new(name, me, sock, mat):
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    ob["sock"] = sock
    if mat is not None:
        ob.data.materials.append(mat.m if hasattr(mat, "m") else mat)
    for p in me.polygons:
        p.use_smooth = True
    return ob


def tri_count(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


def mods(ob, *specs):
    """specs: (type, {attr: value}) applied in order, then applied to the mesh."""
    for typ, kw in specs:
        m = ob.modifiers.new(typ.title(), typ)
        for k, v in kw.items():
            setattr(m, k, v)
    K.apply_mods(ob)


def smooth_shade(ob):
    for p in ob.data.polygons:
        p.use_smooth = True


# --- a region of the body, as a garment ----------------------------------------------------------------

def shell(src, name, sel, off, thick, mat, sock, folds=None, smooth_iter=6, edge=0.0, bevel=0.0, inward=True, keep_normals=False, bev_seg=2):
    """Cut the faces of `src` (a Blender mesh object, the sculpted high-poly) where sel(P, N) > 0 (P, N rig
    space per vertex), push every kept vertex out along its normal by off(P, N) metres (+ folds(P, N)),
    smooth, solidify `thick` metres inwards. Returns a new object (not yet decimated)."""
    co, nr = mesh_arrays(src)
    P, N = to_rig(co), to_rig(nr)
    f = sel(P, N)
    ok = f > 0.0
    lt, vi = poly_arrays(src.data)
    start = np.concatenate(([0], np.cumsum(lt)[:-1]))
    good = np.logical_and.reduceat(ok[vi], start)
    pl = np.nonzero(good)[0]
    if len(pl) == 0:
        raise RuntimeError("shell %s: nothing selected" % name)
    used = np.unique(np.concatenate([vi[start[i]:start[i] + lt[i]] for i in pl]))
    remap = -np.ones(len(co), dtype=np.int64)
    remap[used] = np.arange(len(used))
    d = off(P[used], N[used]) if callable(off) else np.full(len(used), off, dtype=np.float32)
    d = np.broadcast_to(np.asarray(d, dtype=np.float32), (len(used),)).copy()
    if folds is not None:
        d = d + folds(P[used], N[used])
    newco = co[used] + to_bl(N[used]) * d[:, None]
    faces = [tuple(int(remap[v]) for v in vi[start[i]:start[i] + lt[i]]) for i in pl]
    me = bpy.data.meshes.new(name)
    me.from_pydata(newco.tolist(), [], faces)
    me.update()
    ob = link_new(name, me, sock, mat)
    if smooth_iter:
        mods(ob, ("CORRECTIVE_SMOOTH", dict(factor=0.6, iterations=smooth_iter)))
    if thick > 0.0:
        mods(ob, ("SOLIDIFY", dict(thickness=thick, offset=-1.0 if inward else 1.0, use_rim=True)))
    if bevel > 0.0:
        mods(ob, ("BEVEL", dict(width=bevel, segments=bev_seg, limit_method='ANGLE', angle_limit=math.radians(40))))
    smooth_shade(ob)
    return ob


def hi_lo(high, tris, name, sock, pairs, objs, hide=True):
    """Register `high` as the bake source and add its decimated copy to objs (the game mesh)."""
    import grunt_body as GB
    high.hide_render = hide
    high.hide_viewport = hide
    low = GB.make_low(high, tris, name)
    low["sock"] = sock
    low["fixed"] = True
    pairs.append((low, high))
    objs.append(low)
    return low


# --- a drape: tunic -> skirt, one loft with pleats ------------------------------------------------------

def catmull(keys, y, cols):
    """Catmull-Rom through keys (sorted by key[0]) evaluated at array y; returns (len(y), cols)."""
    ks = np.array(keys, dtype=np.float64)
    ys = ks[:, 0]
    out = np.zeros((len(y), cols))
    for n, yy in enumerate(y):
        i = int(np.clip(np.searchsorted(ys, yy) - 1, 0, len(ys) - 2))
        p0 = ks[max(i - 1, 0)]
        p1, p2 = ks[i], ks[i + 1]
        p3 = ks[min(i + 2, len(ks) - 1)]
        t = (yy - p1[0]) / max(p2[0] - p1[0], 1e-9)
        t = min(max(t, 0.0), 1.0)
        t2, t3 = t * t, t * t * t
        v = 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
        out[n] = v[1:1 + cols]
    return out


class Waves:
    """A set of pleat waves round a garment: each has a count, a strength, a phase and a lean (how the fold
    slants as it falls), so the folds are not a regular corrugation."""

    def __init__(self, seed=1, counts=(5, 9, 15, 23), amps=(1.0, 0.55, 0.3, 0.14)):
        rng = np.random.RandomState(seed)
        self.w = [(c + rng.randint(-1, 2), a, rng.uniform(0, math.tau), rng.uniform(-1.2, 1.2)) for c, a in zip(counts, amps)]
        self.seed = seed

    def __call__(self, th, y):
        f = 0.0
        for k, (m, a, ph, lean) in enumerate(self.w):
            arg = m * th + ph + lean * y + 0.9 * np.sin(2.0 * th + y * 3.0 + k)
            if k == 0:
                f = f + a * np.sin(arg)
            else:
                # sharper valleys, soft crests: a cloth fold, not a sine
                f = f + a * (np.abs(np.sin(arg * 0.5)) ** 0.8 * 2.0 - 1.0)
        return f / 1.8


class Drape:
    """rings of the garment: keys = [(y, cx, cz, half_width, front, back, squareness)], y high to low or any
    order. hem(th) -> y of the hem at angle th. pleat strength grows from `y_fold0` (the belt) down to the hem."""

    def __init__(self, keys, y_top, hem, y_fold0, y_hem_ref, amp=0.03, waves=None, nth=200, dy=0.01, flare=0.0, seed=1.0, grab=None):
        self.keys = sorted(keys)
        self.y_top = y_top
        self.hem = hem
        self.y_fold0 = y_fold0
        self.y_hem_ref = y_hem_ref
        self.amp = amp
        self.waves = waves or Waves(int(seed))
        self.nth = nth
        self.dy = dy
        self.flare = flare
        self.seed = seed
        self.grab = grab

    def points(self):
        """(nv, nth, 3) rig-space grid, row 0 at the top."""
        ymin = self.hem(np.linspace(0, math.tau, 64)).min() - 0.02
        ys = np.arange(self.y_top, ymin - 1e-6, -self.dy)
        v = catmull(self.keys, ys[::-1], 6)[::-1]           # catmull wants ascending y
        th = np.linspace(0.0, math.tau, self.nth, endpoint=False)
        TH, Y = np.meshgrid(th, ys)
        cx, cz, a, fr, bk, e = [v[:, i][:, None] for i in range(6)]
        c, s = np.cos(TH), np.sin(TH)
        ex = 2.0 / np.maximum(e, 0.5)
        X = cx + a * np.sign(c) * np.abs(c) ** ex
        Z = cz + np.where(s < 0, fr, bk) * np.sign(s) * np.abs(s) ** ex
        # pleats: radial offset, zero at the belt, growing to the hem
        t = smooth(self.y_fold0, self.y_hem_ref, Y)
        F = self.waves(TH, Y) * self.amp * (0.18 + 0.82 * t)
        F = F + self.flare * t * t
        # push out radially from the garment axis
        dx, dz = X - cx, Z - cz
        L = np.sqrt(dx * dx + dz * dz) + 1e-6
        X = X + dx / L * F
        Z = Z + dz / L * F
        if self.grab is not None:
            X, Z = self.grab(X, Y, Z, TH)
        # clamp every vertex below its column's hem onto the hem line (cut clean, no stair-steps)
        hm = self.hem(TH)
        Y2 = np.maximum(Y, hm)
        self.ys, self.th = ys, th
        return np.stack([X, Y2, Z], axis=-1)


def grid_surface(name, Pg, sock, mat, wrap=True, thick=0.006, sub=0, close_top=False, flip=None):
    """Quad grid (nv, nu, 3) rig space -> mesh: duplicate (collapsed) points merged, outward normals (axis = the grid's
    own centroid), optional solidify inwards."""
    nv, nu, _ = Pg.shape
    V = to_bl(Pg.reshape(-1, 3))
    faces = []
    for i in range(nv - 1):
        for j in range(nu if wrap else nu - 1):
            a = i * nu + j
            b = i * nu + (j + 1) % nu
            c = (i + 1) * nu + (j + 1) % nu
            d = (i + 1) * nu + j
            faces.append((a, b, c, d))
    me = bpy.data.meshes.new(name)
    me.from_pydata(V.tolist(), [], faces)
    me.update()
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    deg = [f for f in bm.faces if len(set(f.verts)) < 3 or f.calc_area() < 1e-9]
    if deg:
        bmesh.ops.delete(bm, geom=deg, context='FACES')
    bm.to_mesh(me)
    bm.free()
    me.update()
    # orientation: outward from the vertical axis through the centroid
    ctr = np.mean(Pg.reshape(-1, 3), axis=0)
    tot = 0.0
    for p in me.polygons:
        cc = to_rig(np.array(p.center))
        nn = to_rig(np.array(p.normal))
        tot += (cc[0] - ctr[0]) * nn[0] + (cc[2] - ctr[2]) * nn[2]
    if (tot < 0.0) if flip is None else flip:
        bm = bmesh.new()
        bm.from_mesh(me)
        bmesh.ops.reverse_faces(bm, faces=bm.faces)
        bm.to_mesh(me)
        bm.free()
    ob = link_new(name, me, sock, mat)
    if thick > 0.0:
        mods(ob, ("SOLIDIFY", dict(thickness=thick, offset=-1.0, use_rim=True)))
    if sub:
        mods(ob, ("SUBSURF", dict(levels=sub, render_levels=sub)))
    smooth_shade(ob)
    return ob


def ragged_hem(base, amp, seed=1.0, cuts=0.0, scallop=0.0, nscal=14):
    """hem(th) -> y. base y, noise `amp` (a jagged torn edge), `cuts` deep tears, `scallop` rounded points."""
    rng = np.random.RandomState(int(seed * 13) % 9999)
    ph = rng.uniform(0, math.tau, 6)
    tears = rng.uniform(0, math.tau, 5)

    def f(th):
        h = base + amp * (0.55 * np.sin(th * 5 + ph[0]) + 0.3 * np.sin(th * 11 + ph[1]) + 0.22 * np.sin(th * 23 + ph[2]) + 0.12 * np.sin(th * 47 + ph[3]))
        if scallop:
            h = h + scallop * (np.abs(np.sin(th * nscal * 0.5)) - 0.5)
        for t in tears:
            d = np.abs(((th - t + math.pi) % math.tau) - math.pi)
            h = h + cuts * np.exp(-(d / 0.05) ** 2)
        return h
    return f


def sleeve(name, p0, p1, r0, r1, mat, sock, hem_amp=0.03, droop=0.0, seed=1.0, amp=0.02, nth=72, rows=34, thick=0.005, drop_len=0.0):
    """A loose sleeve from rig points p0 (shoulder) to p1 (wrist), radius r0 -> r1. `drop_len` lets the cuff hang
    past p1 (a bell sleeve, flaring), pleated, the end torn ragged (every column cut clean at its own length)."""
    p0, p1 = np.array(p0, dtype=np.float64), np.array(p1, dtype=np.float64)
    ax = p1 - p0
    L = float(np.linalg.norm(ax))
    ax /= L
    u = np.cross(ax, [0, 0, -1.0])
    u /= np.linalg.norm(u)
    w = np.cross(ax, u)
    tend = 1.0 + drop_len / L
    cap = r0 / L                                         # a rounded shoulder cap above p0, so the top is never an open ring
    t = np.concatenate([np.linspace(-cap, 0.0, 7, endpoint=False), np.linspace(0, tend, rows)])
    th = np.linspace(0, math.tau, nth, endpoint=False)
    T, TH = np.meshgrid(t, th, indexing='ij')
    rng = np.random.RandomState(int(seed * 5))
    ph = rng.uniform(0, math.tau, 3)
    cut = tend - (hem_amp / L) * (0.5 + 0.3 * np.sin(TH * 5 + ph[0]) + 0.2 * np.sin(TH * 13 + ph[1]) + 0.1 * np.sin(TH * 29 + ph[2]))
    Tc = np.minimum(T, cut)
    extra = np.maximum(Tc - 1.0, 0.0) / max(drop_len / L, 1e-6) if drop_len > 0 else 0.0
    R = r0 + (r1 - r0) * np.minimum(Tc, 1.0) + r1 * 0.55 * extra
    R = np.where(Tc < 0.0, r0 * np.sqrt(np.clip(1.0 - (Tc / cap) ** 2, 0.0, 1.0)), R)
    wv = Waves(int(seed) + 7, counts=(4, 8, 13, 21), amps=(1.0, 0.5, 0.28, 0.12))
    R = R + wv(TH, Tc * 3.0) * amp * (0.2 + 0.8 * smooth(0.3, 1.2, Tc))
    cen = p0[None, None, :] + Tc[..., None] * L * ax[None, None, :]
    cen = cen + np.array([0, -1.0, 0])[None, None, :] * droop * (smooth(1.0, tend, Tc) if drop_len > 0 else np.zeros_like(Tc))[..., None]
    pts = cen + (np.cos(TH)[..., None] * u + np.sin(TH)[..., None] * w) * R[..., None]
    return grid_surface(name, pts, sock, mat, wrap=True, thick=thick, flip=None)


# --- hood ------------------------------------------------------------------------------------------------

def hood(name, c, mat, sock, size=(0.115, 0.135, 0.125), face_r=(0.062, 0.078), face_dy=-0.012, peak=0.06, back_drop=0.18,
         lip=0.012, seed=3.0, amp=0.008, segs=112, rings=64, open_z=-0.02):
    """A cowl over a head at rig point c: a squashed sphere, peaked and pulled down into a cape at the back,
    an elliptical opening cut in the front with a thickened rolled lip, folded. Returns the object."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=1.0)
    rng = np.random.RandomState(int(seed))
    ph = rng.uniform(0, math.tau, 4)
    for v in bm.verts:
        x, y, z = v.co.x, v.co.z, -v.co.y        # sphere in blender axes -> rig (x, up, front=-z): blender +y front
        # rig coords: x, up = z_bl, fz = -y_bl  (front is negative rig z)
        p = np.array([v.co.x, v.co.z, -v.co.y])
        sx, sy, sz = size
        px, py, pz = p[0] * sx, p[1] * sy, p[2] * sz
        back = max(pz, 0.0) / sz                # 0..1 toward the back
        low = max(-p[1], 0.0)                   # lower hemisphere
        # the back and lower half drag down into a cape over the shoulders
        py -= back_drop * (back ** 1.5) * (0.4 + 0.6 * low) + 0.55 * back_drop * low * low * (0.5 + 0.5 * back)
        pz += 0.02 * low * back
        # the peak: the crown pulls up and back to a point
        top = max(p[1], 0.0)
        py += peak * (top ** 3) * (0.5 + 0.5 * back)
        pz += 0.5 * peak * (top ** 3) * back
        # folds
        fa = amp * (np.sin(5.0 * math.atan2(p[0], pz) + ph[0] + 3 * p[1]) + 0.5 * np.sin(11.0 * math.atan2(p[0], pz) + ph[1] + 5 * p[1]))
        k = 1.0 + fa / max(sx, 0.05)
        v.co = Vector((px * k, -pz * k, py * k)) + Vector(G(*c)) - Vector((0, 0, 0))
    # cut the opening in the front
    kill = []
    fc = Vector(G(c[0], c[1] + face_dy, c[2] + open_z))
    for f in bm.faces:
        q = f.calc_center_median() - Vector(G(*c))
        # blender +y is the front
        if q.y > 0.0:
            ex = q.x / face_r[0]
            ey = (q.z - face_dy) / face_r[1]
            if ex * ex + ey * ey < 1.0:
                kill.append(f)
    bmesh.ops.delete(bm, geom=kill, context='FACES_ONLY')
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = link_new(name, me, sock, mat)
    mods(ob, ("SOLIDIFY", dict(thickness=lip, offset=-1.0, use_rim=True)), ("SUBSURF", dict(levels=1, render_levels=1)))
    smooth_shade(ob)
    return ob


# --- a surface of revolution ---------------------------------------------------------------------------------

def lathe(name, prof, c, mat, sock, nth=48, wobble=0.0, seed=0.0, closed_top=True, axis_y=True, thick=0.0, ellip=(1.0, 1.0), fold=0.0, fold_n=7, rows=0):
    """prof = [(radius, height)] from the bottom up (rig space); c = centre (rig). Returns the object. Radius 0 at an
    end closes it. wobble = noise on the radius; fold = ribs round the circumference (fold_n of them)."""
    if rows and rows > len(prof):                       # a smooth profile: Catmull-Rom through the keys (heights must rise)
        hs = np.linspace(prof[0][1], prof[-1][1], rows)
        rr = catmull([(h, r) for r, h in prof], hs, 1)[:, 0]
        prof = [(float(r), float(h)) for r, h in zip(rr, hs)]
    rows = len(prof)
    th = np.linspace(0, math.tau, nth, endpoint=False)
    P = np.zeros((rows, nth, 3))
    for i, (r, h) in enumerate(prof):
        rr = r * (1.0 + wobble * np.sin(th * 3 + i * 1.3 + seed) * 0.5 + fold * np.sin(th * fold_n + seed))
        P[i, :, 0] = c[0] + np.cos(th) * rr * ellip[0]
        P[i, :, 1] = c[1] + h
        P[i, :, 2] = c[2] + np.sin(th) * rr * ellip[1]
    ob = grid_surface(name, P, sock, mat, wrap=True, thick=thick)
    return ob


def tube(name, pts, radii, mat, sock, sides=8, cap=True):
    return K.loft(name, [Vector(G(*p)) for p in pts], radii, sock, mat, sides, cap0=cap, cap1=cap)


def band_loop(name, centre, rx, rz, r, mat, sock, y_fn=None, n=36, sides=6, squash=1.0, sag=0.0):
    pts = []
    for i in range(n + 1):
        a = math.tau * i / n
        y = centre[1] + (y_fn(a) if y_fn else 0.0)
        pts.append(Vector(G(centre[0] + math.cos(a) * rx, y, centre[2] + math.sin(a) * rz)))
    return K.loft(name, pts, [(r, r * squash)] * len(pts), sock, mat, sides)


def gauss(P, c, r):
    return np.exp(-((P - np.array(c)) ** 2).sum(-1) / (r * r))


def preview_sheet(path, target_z=0.95, dist=3.2, views=((90, 1.2), (48, 1.3), (0, 1.2), (270, 1.3)), tile=(450, 600)):
    """K.preview from four angles (front, three-quarter, side, back) and a contact sheet at `path`."""
    K.preview(path, target_z, dist, views)
    base, ext = os.path.splitext(path)
    tw, th = tile
    sheet = np.zeros((th, tw * len(views), 4), dtype=np.float32)
    for i in range(len(views)):
        im = bpy.data.images.load("%s_%d%s" % (base, i, ext))
        im.scale(tw, th)
        a = np.empty(tw * th * 4, dtype=np.float32)
        im.pixels.foreach_get(a)
        sheet[:, i * tw:(i + 1) * tw] = a.reshape(th, tw, 4)
    out = bpy.data.images.new("sheet", tw * len(views), th, alpha=False)
    out.pixels.foreach_set(sheet.ravel())
    out.filepath_raw = path
    out.file_format = 'PNG'
    out.save()


def surf_pt(Pg, drape, y, th):
    """The point of a Drape's grid at height y and angle th (rig space), and the outward direction there."""
    i = int(np.argmin(np.abs(drape.ys - y)))
    j = int(round((th % math.tau) / math.tau * drape.nth)) % drape.nth
    p = Pg[i, j]
    q = Pg[i, (j + 1) % drape.nth] - Pg[i, (j - 1) % drape.nth]
    n = np.array([q[2], 0.0, -q[0]])
    n /= (np.linalg.norm(n) + 1e-9)
    # outward = away from the garment axis
    c = np.array([0.0, p[1], 0.0])
    if np.dot(n, p - c) < 0:
        n = -n
    return p, n


def patch(src, name, c, r, mat, sock, off=0.005, thick=0.004, seed=1.0, ragged=0.28, axis=(0.0, 0.0)):
    """A patch of cloth sewn on: the faces of `src` within a ragged disc round rig point c (outer faces only), lifted."""
    cc = np.array(c, dtype=np.float32)

    def sel(P, N):
        d = np.linalg.norm(P - cc, axis=1)
        out = (N[:, 0] * (P[:, 0] - axis[0]) + N[:, 2] * (P[:, 2] - axis[1])) > 0.0
        edge = r * (1.0 + ragged * hash_noise(P, 14.0, seed)) - d
        return np.where(out, edge, -1.0)
    return shell(src, name, sel, off, thick, mat, sock, smooth_iter=2)


def displace(ob, fn):
    """Push every vertex of ob along its normal by fn(P, N) metres (rig space P, N)."""
    co, nr = mesh_arrays(ob)
    P, N = to_rig(co), to_rig(nr)
    d = np.asarray(fn(P, N), dtype=np.float32)
    ob.data.vertices.foreach_set('co', (co + to_bl(N) * d[:, None]).astype(np.float32).ravel())
    ob.data.update()


class Plates:
    """Plates / bone shells cut from the body: keep(sel, off, thick) adds a high shell (for the bake) and a game shell cut from a
    coarse copy (or, fine=True, from the fine surface); finish(tris, ...) joins them, thins the game set to `tris` and registers
    the (low, high) pairs. Plates on the torso and on the arms are joined APART (sock "bodystiff" / "armstiff"): a plate that
    wraps a flank must follow the chest, never the arm bone beside it."""

    def __init__(self, hi_src, lo_src, arm_hi=None, arm_lo=None, fine=False):
        self.fine = fine
        self.src = {"body": (hi_src, lo_src), "arms": (arm_hi, arm_lo)}
        self.hi = {"body": [], "arms": []}
        self.lo = {"body": [], "arms": []}

    def keep(self, sel, off, thick=0.01, on="body", name="Plate", mat=None, folds=None, bevel=0.003, smooth_iter=5, sock="stiff"):
        h, l = self.src[on]
        if self.fine:
            l = h
        hi = shell(h, name, sel, off, thick, mat, sock, folds=folds, smooth_iter=smooth_iter, bevel=bevel)
        self.hi[on].append(hi)
        try:
            self.lo[on].append(shell(l, name + "Lo", sel, off, 0.0, mat, sock, folds=folds, smooth_iter=max(2, smooth_iter - 2), bevel=0.0))
        except RuntimeError:
            lo = hi.copy()
            lo.data = hi.data.copy()
            lo.name = name + "Lo"
            bpy.context.scene.collection.objects.link(lo)
            n = max(tri_count(lo), 1)
            mods(lo, ("DECIMATE", dict(ratio=min(1.0, 120.0 / n), use_collapse_triangulate=True)))
            self.lo[on].append(lo)

    def _join(self, lst, name):
        bpy.ops.object.select_all(action='DESELECT')
        for o in lst:
            o.select_set(True)
        bpy.context.view_layer.objects.active = lst[0]
        bpy.ops.object.join()
        ob = bpy.context.view_layer.objects.active
        ob.name = name
        return ob

    def finish(self, tris, sock, pairs, objs, name="Plates"):
        allo = self.lo["body"] + self.lo["arms"]
        n = sum(tri_count(o) for o in allo)
        ratio = min(1.0, float(tris) / max(n, 1))
        print("PLATES", name, "lo tris", n, "ratio", ratio)
        for o in allo:
            if self.fine:
                mods(o, ("SMOOTH", dict(factor=0.7, iterations=14)))
            if ratio < 1.0:
                mods(o, ("DECIMATE", dict(ratio=ratio, use_collapse_triangulate=True)))
        out = []
        for on, sk in (("body", "bodystiff"), ("arms", "armstiff")):
            if not self.hi[on]:
                continue
            hi = self._join(self.hi[on], name + on.title() + "High")
            lo = self._join(self.lo[on], name + on.title() + "Low")
            hi.hide_render = True
            hi.hide_viewport = True
            lo["sock"] = sk
            lo["fixed"] = True
            smooth_shade(lo)
            pairs.append((lo, hi))
            objs.append(lo)
            out.append(lo)
        return out


def wrap_shell(src, name, y0, y1, side, off, mat, sock, tris, pairs, objs, turns=7.0, cx=0.0, xs=0.0, thick=0.004, amp=0.0035):
    """A bandage wound round a limb between heights y0 and y1 (on x*side > xs): the band's surface carries a spiral ridge."""
    def sel(P, N):
        return np.where(P[:, 0] * side > xs, np.minimum(P[:, 1] - y0, y1 - P[:, 1]), -1.0)

    def fold(P, N):
        ph = (P[:, 1] - y0) / (y1 - y0) * turns * math.tau + np.arctan2(P[:, 2], P[:, 0] - cx)
        return amp * (np.abs(np.sin(ph * 0.5)) - 0.5) + 0.0012 * hash_noise(P, 40.0, 2.0)
    hi = shell(src, name + "High", sel, off, thick, mat, sock, folds=fold, smooth_iter=2)
    return hi_lo(hi, tris, name + "Low", sock, pairs, objs)


def report(objs, n=40):
    """Print the heaviest parts (triangles), so the budget can be spent where it shows."""
    rows = sorted(((tri_count(o), o.name, o.get("sock", "")) for o in objs if o.type == 'MESH'), reverse=True)
    print("TRIS total", sum(r[0] for r in rows), "parts", len(rows))
    for r in rows[:n]:
        print("  TRIS", r)


def soften(mat, f=0.5):
    """Scale the bump of a procedural material (a K.Mat): the cloth scan bump is fine grain that bakes to fuzz."""
    for n in (mat.nodes if hasattr(mat, "nodes") else mat.m.node_tree.nodes):
        if n.bl_idname == 'ShaderNodeBump':
            n.inputs['Strength'].default_value *= f
            n.inputs['Distance'].default_value *= f
