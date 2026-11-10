"""r38c: one continuous surface per body, built to be sculpted and baked (high to low).

  1. A vertex skeleton that follows the rig's joints (Skel), more vertices along every limb so it tapers:
     a thick muscle belly, a thin wrist and ankle, a bony narrow joint. Blender's Skin modifier turns it
     into one quad surface (torso masses are elliptical), Subdivision, then a VOXEL REMESH fuses it all:
     body, head, fingers and toes are one skin, nothing is a primitive stuck on a joint.
  2. A sculpt pass in numpy on the high-poly: displacement along the vertex normal driven by gaussian
     bumps / ridges placed in rig space (ribs, sternum, collarbones and the hollow above them, tendon
     cords, brow, eye sockets cut in, sunken cheeks, a lipless mouth, kneecap, shin edge, Achilles...)
     plus skin-fold noise at two scales.
  3. A decimated copy is the game mesh; its normal map and AO are baked from the high-poly
     (grunt_kit.bake_atlas_hl), and it is skinned by envelope weights from the rig's bone segments.
Rig space is Godot's: +Y up, the body faces -Z. Blender space is G(x, y, z).
"""
import bpy
import math
import os
import sys
import numpy as np
from mathutils import Vector

sys.path.insert(0, os.path.dirname(__file__))
import boss_kit as K
from boss_kit import G


# --- skeleton ---------------------------------------------------------------------------------------

class Skel:
    """Vertices (rig space) with a Skin radius each (float or (across, depth)) and parent edges."""

    def __init__(self):
        self.p, self.r, self.e, self.idx = [], [], [], {}
        self.masses = []          # ellipsoids (centre, radii) in rig space, unioned in at the voxel remesh
        self.lofts = []           # closed lofts: a list of rings (each a list of rig-space points), capped

    def mass(self, c, rr):
        self.masses.append((tuple(c), tuple(rr)))

    def loft(self, keys, step=0.008, n=40, axis="y"):
        """A smooth torso / neck from cross-section keys (y, cx, cz, half-width, front, back, flat): a
        superellipse ring at each key, Catmull-Rom between them every `step` metres. One surface, no
        scallops (a stack of ellipsoids leaves a ring at every seam)."""
        keys = sorted(keys)

        def at(y):
            for i in range(len(keys) - 1):
                if keys[i][0] <= y <= keys[i + 1][0]:
                    p0 = keys[max(i - 1, 0)]
                    p1, p2 = keys[i], keys[i + 1]
                    p3 = keys[min(i + 2, len(keys) - 1)]
                    t = (y - p1[0]) / max(p2[0] - p1[0], 1e-9)
                    t2, t3 = t * t, t * t * t
                    return [0.5 * ((2 * p1[j]) + (-p0[j] + p2[j]) * t + (2 * p0[j] - 5 * p1[j] + 4 * p2[j] - p3[j]) * t2
                                   + (-p0[j] + 3 * p1[j] - 3 * p2[j] + p3[j]) * t3) for j in range(1, 7)]
            return list(keys[-1][1:7])
        rings = []
        y = keys[0][0]
        while y <= keys[-1][0] + 1e-6:
            cx, cz, a, f, b, e = at(y)
            ring = []
            for k in range(n):
                th = math.tau * k / n
                c, s = math.cos(th), math.sin(th)
                ex = 2.0 / max(e, 0.5)
                x = cx + a * math.copysign(abs(c) ** ex, c)
                d = f if s < 0 else b          # -z is the front (axis y); below (axis z)
                z = cz + d * math.copysign(abs(s) ** ex, s)
                ring.append((x, y, z) if axis == "y" else (x, z, y))
            rings.append(ring)
            y += step
        self.lofts.append(rings)

    def v(self, name, pos, r, parent=None):
        i = len(self.p)
        self.p.append(tuple(G(*pos)))
        self.r.append(r if isinstance(r, tuple) else (r, r))
        self.idx[name] = i
        if parent is not None:
            self.e.append((self.idx[parent], i))
        return name

    def chain(self, parent, prefix, items):
        """items: [(pos, r)] hanging in a line from `parent`; names prefix0, prefix1, ..."""
        cur = parent
        for k, (pos, r) in enumerate(items):
            cur = self.v("%s%d" % (prefix, k), pos, r, cur)
        return cur


def build_skin(sk, name, root, voxel=0.005, sub=1, smooth=0.7):
    """Skin modifier + subsurf + voxel remesh -> one closed surface, smooth shaded."""
    me = bpy.data.meshes.new(name)
    me.from_pydata(sk.p, sk.e, [])
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    bpy.ops.object.select_all(action='DESELECT')
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.modifier_add(type='SKIN')
    sv = me.skin_vertices[0].data
    for i, r in enumerate(sk.r):
        sv[i].radius = r
    for rt in (root if isinstance(root, (list, tuple)) else [root]):
        sv[sk.idx[rt]].use_root = True
    md = ob.modifiers["Skin"]
    md.branch_smoothing = smooth
    md.use_smooth_shade = True
    sm = ob.modifiers.new("Sub", 'SUBSURF')
    sm.levels = sub
    sm.render_levels = sub
    K.apply_mods(ob)
    if sk.masses or sk.lofts:
        import bmesh
        parts = [ob]
        for rings in sk.lofts:
            bm = bmesh.new()
            vr = [[bm.verts.new(Vector(G(*p))) for p in ring] for ring in rings]
            n = len(vr[0])
            for r0, r1 in zip(vr, vr[1:]):
                for k in range(n):
                    bm.faces.new((r0[k], r0[(k + 1) % n], r1[(k + 1) % n], r1[k]))
            bm.faces.new(list(reversed(vr[0])))
            bm.faces.new(vr[-1])
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
            me2 = bpy.data.meshes.new(name + "l")
            bm.to_mesh(me2)
            bm.free()
            o2 = bpy.data.objects.new(name + "l", me2)
            bpy.context.scene.collection.objects.link(o2)
            parts.append(o2)
        for c, rr in sk.masses:
            bm = bmesh.new()
            bmesh.ops.create_uvsphere(bm, u_segments=40, v_segments=22, radius=1.0)
            for v in bm.verts:
                v.co = Vector((v.co.x * rr[0], v.co.y * rr[2], v.co.z * rr[1])) + Vector(G(*c))
            me2 = bpy.data.meshes.new(name + "m")
            bm.to_mesh(me2)
            bm.free()
            o2 = bpy.data.objects.new(name + "m", me2)
            bpy.context.scene.collection.objects.link(o2)
            parts.append(o2)
        bpy.ops.object.select_all(action='DESELECT')
        for o2 in parts:
            o2.select_set(True)
        bpy.context.view_layer.objects.active = ob
        bpy.ops.object.join()
        ob = bpy.context.view_layer.objects.active
    r = ob.modifiers.new("Vox", 'REMESH')
    r.mode = 'VOXEL'
    r.voxel_size = voxel
    r.adaptivity = 0.0
    K.apply_mods(ob)
    cs = ob.modifiers.new("Smooth", 'CORRECTIVE_SMOOTH')      # dissolves the voxel stair-steps, keeps the volume
    cs.factor = 0.7
    cs.iterations = 16
    K.apply_mods(ob)
    for p in ob.data.polygons:
        p.use_smooth = True
    print("SKIN", name, "verts", len(me.vertices), "tris", sum(len(p.vertices) - 2 for p in me.polygons))
    return ob


# --- sculpt (numpy) ---------------------------------------------------------------------------------

def _coords(ob):
    n = len(ob.data.vertices)
    co = np.empty(n * 3, dtype=np.float32)
    ob.data.vertices.foreach_get('co', co)
    nr = np.empty(n * 3, dtype=np.float32)
    ob.data.vertex_normals.foreach_get('vector', nr)
    return co.reshape(n, 3), nr.reshape(n, 3)


def to_rig(a):
    return np.stack([a[:, 0], a[:, 2], -a[:, 1]], axis=1)


class Sculpt:
    """Collects displacement terms (metres along the normal) in rig space, applies them once."""

    def __init__(self, ob):
        self.ob = ob
        co, nr = _coords(ob)
        self.co = co
        self.P = to_rig(co)
        self.N = to_rig(nr)
        self.d = np.zeros(len(co), dtype=np.float32)

    def _w(self, r):
        return r * r

    def bump(self, c, r, amp, facing=None, sx=(1,)):
        """A gaussian bump (amp>0) or pit (amp<0) at rig point c; `facing` = unit vector the surface must
        face (dot > 0.15), so a socket cut on the front does not also dent the back of the head."""
        for s in sx:
            cc = np.array([c[0] * s, c[1], c[2]], dtype=np.float32)
            d2 = ((self.P - cc) ** 2).sum(1)
            f = np.exp(-d2 / (r * r))
            if facing is not None:
                fc = np.array([facing[0] * s, facing[1], facing[2]], dtype=np.float32)
                f = f * np.clip((self.N @ fc) * 2.0, 0.0, 1.0)
            self.d += amp * f

    def ridge(self, a, b, w, amp, facing=None, sx=(1,)):
        for s in sx:
            A = np.array([a[0] * s, a[1], a[2]], dtype=np.float32)
            B = np.array([b[0] * s, b[1], b[2]], dtype=np.float32)
            ab = B - A
            t = np.clip(((self.P - A) @ ab) / max(float(ab @ ab), 1e-9), 0.0, 1.0)
            q = A + t[:, None] * ab
            f = np.exp(-((self.P - q) ** 2).sum(1) / (w * w))
            if facing is not None:
                fc = np.array([facing[0] * s, facing[1], facing[2]], dtype=np.float32)
                f = f * np.clip((self.N @ fc) * 2.0, 0.0, 1.0)
            self.d += amp * f

    def band(self, y, w, amp, xmax, slope=0.0, facing=(0, 0, -1), sx=None, xmin=0.0):
        """A horizontal ridge round the front/sides of the torso (a rib): gaussian in y, tilted by `slope`
        toward the midline, limited to xmin < |x| < xmax (soft edges) and the surface facing `facing`."""
        ax = np.abs(self.P[:, 0])
        yy = self.P[:, 1] - slope * (1.0 - np.minimum(ax / xmax, 1.0))
        f = np.exp(-((yy - y) ** 2) / (w * w))
        f = f * np.clip((xmax - ax) / 0.02, 0.0, 1.0) * np.clip((ax - xmin) / 0.02, 0.0, 1.0)
        fc = np.array(facing, dtype=np.float32)
        f = f * np.clip(self.N @ fc + 0.35, 0.0, 1.0)
        self.d += amp * f

    def noise(self, scale, amp, mask=None):
        q = self.P * scale
        n = (np.sin(q[:, 0] * 1.7 + np.sin(q[:, 1] * 2.3) * 1.5) * np.sin(q[:, 1] * 1.3 + np.cos(q[:, 2] * 1.9) * 1.4)
             + np.sin(q[:, 2] * 2.1 + q[:, 0] * 0.7) * np.cos(q[:, 1] * 2.9 + q[:, 0] * 0.4)) * 0.5
        self.d += amp * n * (1.0 if mask is None else mask)

    def folds(self, scale, amp, mask=None):
        """Creases: |noise| ridges (skin folds), sharper than plain noise."""
        q = self.P * scale
        n = np.abs(np.sin(q[:, 0] * 1.3 + np.sin(q[:, 1] * 1.9 + q[:, 2] * 0.8) * 1.7)) - 0.5
        self.d += amp * n * (1.0 if mask is None else mask)

    def apply(self):
        co = self.co + self.d[:, None] * to_blender_normals(self.N)
        self.ob.data.vertices.foreach_set('co', co.astype(np.float32).ravel())
        self.ob.data.update()
        print("SCULPT", self.ob.name, "disp range", float(self.d.min()), float(self.d.max()))


def to_blender_normals(N):
    # rig (x, y, z) -> blender (x, -z, y)
    return np.stack([N[:, 0], -N[:, 2], N[:, 1]], axis=1)


# --- low-poly + envelope weights ------------------------------------------------------------------

def make_low(high, tris, name):
    low = high.copy()
    low.data = high.data.copy()
    low.name = name
    low.data.name = name
    low.hide_render = False
    low.hide_viewport = False
    bpy.context.scene.collection.objects.link(low)
    n = sum(len(p.vertices) - 2 for p in low.data.polygons)
    bpy.ops.object.select_all(action='DESELECT')
    low.select_set(True)
    bpy.context.view_layer.objects.active = low
    d = low.modifiers.new("Dec", 'DECIMATE')
    d.ratio = min(1.0, tris / max(1, n))
    d.use_collapse_triangulate = True
    K.apply_mods(low)
    for p in low.data.polygons:
        p.use_smooth = True
    print("LOW", name, sum(len(p.vertices) - 2 for p in low.data.polygons), "tris from", n)
    return low


def envelope_weights(segments, band=0.05, power=2.0):
    """fn(blender point) -> {bone: weight}: a vertex belongs to the rig-bone segments (bone, rigA, rigB) it
    is near; weight falls off over `band` metres beyond the nearest one, so joints blend smoothly."""
    A = np.array([G(*s[1]) for s in segments], dtype=np.float32)
    B = np.array([G(*s[2]) for s in segments], dtype=np.float32)
    AB = B - A
    L2 = np.maximum((AB * AB).sum(1), 1e-9)
    names = [s[0] for s in segments]

    def fn(p):
        P = np.array([p.x, p.y, p.z], dtype=np.float32)
        t = np.clip(((P - A) * AB).sum(1) / L2, 0.0, 1.0)
        q = A + t[:, None] * AB
        d = np.sqrt(((P - q) ** 2).sum(1))
        w = np.clip(1.0 - (d - d.min()) / band, 0.0, 1.0) ** power
        out = {}
        for nm, wv in zip(names, w):
            if wv > 0.01:
                out[nm] = max(out.get(nm, 0.0), float(wv))
        tot = sum(out.values()) or 1.0
        return {k: v / tot for k, v in out.items()}
    return fn


# --- the humanoid anatomy ----------------------------------------------------------------------------

def head_masses(sk, o, hcy):
    hc = o.get("hc", (0.0, 1.7, -0.035))
    hw = o.get("head_w", 0.078)
    if not o.get("skull"):
        # a skull-shaped loft: a wide cranium, temples pinched at the eyes, cheekbones, a narrower jaw
        # that juts forward (jaw_out), a small chin. Front depth (f) carries the brow and the muzzle.
        s = hw / 0.078
        jo = o.get("jaw_out", 0.0) + o.get("muzzle", 0.0)
        cz = hc[2]
        prof = [(0.105, 0.012, 0.02, 0.02, 0.0), (0.095, 0.042, 0.05, 0.058, 0.004), (0.075, 0.066, 0.074, 0.084, 0.008),
                (0.045, 0.078, 0.084, 0.092, 0.01), (0.015, 0.074, 0.092, 0.088, 0.008), (-0.01, 0.064, 0.088, 0.078, 0.004),
                (-0.032, 0.066, 0.09, 0.066, 0.0), (-0.055, 0.052, 0.093 + jo, 0.056, -0.006), (-0.078, 0.044, 0.09 + jo, 0.046, -0.01),
                (-0.098, 0.032, 0.078 + jo * 0.8, 0.032, -0.012), (-0.11, 0.014, 0.058 + jo * 0.5, 0.016, -0.012)]
        hh = o.get("head_h", 1.0)
        sk.loft([(hcy + dy * hh, hc[0], cz + dz, a * s, f, b, 2.0) for dy, a, f, b, dz in prof], step=0.005, n=48)
        return
    sk.mass((hc[0], hcy + 0.012, hc[2] + 0.012), (hw, 0.092, 0.09))                                   # cranium
    sk.mass((hc[0], hcy - 0.012, hc[2] - 0.035), (hw * 0.78, 0.075, 0.062))                           # face
    sk.mass((hc[0], hcy - 0.055, hc[2] - 0.045 - o.get("jaw_out", 0.0)), (o.get("jaw_w", 0.048) + 0.005, 0.045, 0.055))   # jaw


def skull_part(o, Y):
    """A bare skull (own surface, bone material): cranium, cheekbones, deep sockets, nasal cavity."""
    sk = Skel()
    hc = o.get("hc", (0.0, 1.7, -0.035))
    hcy = Y(hc[1])
    sk.v("a", (hc[0], hcy, hc[2]), 0.02)
    sk.v("b", (hc[0], hcy - 0.03, hc[2] - 0.03), 0.02, "a")
    head_masses(sk, o, hcy)
    return sk


def head_sculpt(S, o, Y):
    hc = o.get("hc", (0.0, 1.7, -0.035))
    hy = Y(hc[1])
    hh = o.get("head_h", 1.0)
    hz = hc[2]
    front = (0, 0, -1)
    both = (-1, 1)
    sk_ = o.get("skull", False)
    eyer, eyeamp, cheek = (0.03, -0.045, -0.024) if sk_ else (0.024, -0.03, -0.016)
    jo = 0.0 if sk_ else o.get("jaw_out", 0.0) + o.get("muzzle", 0.0)
    fz = hz - 0.088
    S.bump((0.034, hy + hh * 0.014, fz), eyer, eyeamp, facing=front, sx=both)                                         # sockets cut in
    S.ridge((-0.056, hy + hh * 0.04, fz + 0.005), (0.056, hy + hh * 0.04, fz + 0.005), 0.014, o.get("brow", 0.011), facing=front)
    S.ridge((0, hy + hh * 0.03, fz - 0.002), (0, hy - hh * 0.022, fz - 0.012), 0.011, o.get("nose", 0.01), facing=front)
    S.bump((0, hy - hh * 0.012, fz - 0.01), 0.011, -0.02 if sk_ else -0.006, facing=front)
    S.bump((0.05, hy - hh * 0.038, hz - 0.066), 0.03, cheek, facing=(0.4, 0, -1), sx=both)                           # sunken cheeks
    S.bump((0.055, hy - hh * 0.012, hz - 0.068), 0.02, 0.011 if sk_ else 0.009, facing=(0.5, 0, -1), sx=both)       # cheekbones
    S.ridge((-0.035, hy - hh * 0.064, hz - 0.082 - (0.015 + jo if not sk_ else 0.0)), (0.035, hy - hh * 0.064, hz - 0.082 - (0.015 + jo if not sk_ else 0.0)), 0.007, -0.02 if sk_ else -0.013, facing=front)
    S.bump((0, hy - hh * 0.092, hz - 0.07 - (0.02 + jo if not sk_ else 0.0)), 0.02, 0.006, facing=front)                                                # chin
    S.bump((0.082, hy, hz), 0.02, 0.007, facing=(1, 0, 0), sx=both)                                              # ears


def humanoid(o):
    """Skeleton, segments and the squat shift for a humanoid body. `o` (all optional):
    W torso width, L limb thickness, nk neck forward, squat (metres the upper body is lowered), hc head
    centre (rig), waist, finger (length m), knee_out, wrist (y of the wrist), hand_r (palm width)."""
    W, L = o.get("W", 1.0), o.get("L", 1.0)
    nk = o.get("nk", 0.0)
    sq = o.get("squat", 0.0)
    fl = o.get("finger", 0.1)
    wy = o.get("wrist", 0.74)
    ko = o.get("knee_out", 0.0)
    hw = o.get("head_w", 0.078)
    nkr = o.get("neck_r", 0.045)
    dp = o.get("depth", 1.0)

    def Y(y):
        return y - sq * min(max((y - 0.7) / 0.9, 0.0), 1.0)

    def Pt(x, y, z):
        return (x, Y(y), z)
    hc = o.get("hc", (0.0, 1.7, -0.035 - nk))
    hcy = Y(hc[1])
    sk = Skel()
    ska = Skel()                 # the arms: their own surfaces (fused to the torso they tore into webs when posed)
    sk.arms = ska
    sk.v("pel", Pt(0, 0.90, 0), 0.04)
    sk.v("wst", Pt(0, 1.04, 0), 0.04, "pel")
    sk.v("rib", Pt(0, 1.20, 0), 0.04, "wst")
    sk.v("chs", Pt(0, 1.34, 0), 0.04, "rib")
    sk.v("upc", Pt(0, 1.44, 0.02), 0.04, "chs")
    wa = o.get("waist", 1.0)
    hump = o.get("hump", 0.0)
    # the torso and neck: one lofted surface (y, cx, cz, half-width, front, back, squareness)
    keys = o.get("torso") or [
        (0.775, 0, 0.0, 0.06 * W, 0.05, 0.05, 2.0),
        (0.81, 0, 0.0, 0.11 * W, 0.075, 0.09, 2.2),
        (0.88, 0, 0.005, 0.145 * W, 0.088, 0.115, 2.3),                   # hips, the seat behind
        (0.97, 0, 0.0, 0.135 * W, 0.085, 0.1, 2.2),
        (1.05, 0, 0.0, 0.118 * W * wa, 0.078, 0.085, 2.2),                 # waist
        (1.14, 0, 0.0, 0.13 * W, 0.09 * dp, 0.09, 2.2),
        (1.24, 0, 0.005, 0.145 * W, 0.105 * dp, 0.095 + 0.3 * hump, 2.05),  # ribcage
        (1.33, 0, 0.01, 0.155 * W, 0.11 * dp, 0.10 + 0.7 * hump, 2.1),
        (1.41, 0, 0.012, 0.16 * W, 0.1 * dp, 0.10 + hump, 2.25),           # armpits
        (1.465, 0, 0.014 - nk * 0.1, 0.15 * W, 0.078, 0.092 + 0.8 * hump, 2.2),   # top of the shoulders
        (1.495, 0, 0.012 - nk * 0.2, 0.122 * W, 0.066, 0.085 + 0.6 * hump, 2.0),  # trapezius slope
        (1.525, 0, -nk * 0.35, 0.085 * W, 0.058, 0.074 + 0.35 * hump, 2.0),
        (1.56, 0, -nk * 0.6, nkr * 1.2, nkr * 1.08, nkr * 1.3, 2.0),
        (1.62, 0, -nk * 0.9, nkr * 1.05, nkr, nkr * 1.1, 2.0),
    ]
    sk.loft([(Y(k[0]),) + tuple(k[1:]) for k in keys])
    sk.v("nkb", Pt(0, 1.53, -nk * 0.4), (nkr * 0.8, nkr * 0.8), "upc")
    sk.v("nkt", Pt(0, 1.62, -nk * 0.8), (nkr * 0.7, nkr * 0.7), "nkb")
    if not o.get("nohead"):
        sk.v("hd", (hc[0], hcy, hc[2]), 0.03, "nkt")
        head_masses(sk, o, hcy)
    segs = [("pelvis", (0, 0.80, 0), (0, 1.10, 0)), ("chest", (0, 1.10, 0), (0, 1.50, 0.0)),
            ("head", (0, 1.52, -nk * 0.5), (hc[0], hcy + 0.09, hc[2]))]
    for sx, tag in ((-1, "l"), (1, "r")):
        ax = sx * 0.248
        ska.v("trp" + tag, Pt(sx * 0.09, 1.435, 0.012), 0.045 * L)
        ska.v("dlt" + tag, Pt(sx * 0.195, 1.405, 0.0), 0.06 * L, "trp" + tag)
        ska.v("sh" + tag, Pt(ax, 1.37, 0), 0.056 * L, "dlt" + tag)
        ska.v("ua1" + tag, Pt(ax, 1.28, 0.0), 0.054 * L, "sh" + tag)
        ska.v("ua2" + tag, Pt(ax, 1.18, 0.0), 0.046 * L, "ua1" + tag)
        ska.v("elb" + tag, Pt(ax, 1.08, 0.008), 0.03 * L, "ua2" + tag)
        ska.v("fa1" + tag, Pt(ax, 1.0, 0.0), 0.046 * L, "elb" + tag)
        ska.v("fa2" + tag, (ax, (1.0 + wy) * 0.5 + 0.02, 0.0), 0.031 * L, "fa1" + tag)
        ska.v("wr" + tag, (ax, wy, -0.008), 0.021 * L, "fa2" + tag)
        ska.v("plm" + tag, (ax, wy - 0.055, -0.012), (0.034 * o.get("hand_r", 1.0), 0.013), "wr" + tag)
        for k in range(4):
            fx = ax + (k - 1.5) * 0.02 * o.get("hand_r", 1.0)
            ln = fl * (1.0 - 0.12 * abs(k - 1.5) + 0.06 * (k == 1))
            base = wy - 0.1
            pts = [((fx, base, -0.015), 0.0095), ((fx + sx * 0.002 * k, base - 0.38 * ln, -0.026), 0.0078),
                   ((fx + sx * 0.003 * k, base - 0.72 * ln, -0.04), 0.0062), ((fx + sx * 0.004 * k, base - ln, -0.05), 0.0045)]
            ska.chain("plm" + tag, "f%d%s" % (k, tag), pts)
        tp = [((ax - sx * 0.03, wy - 0.07, -0.025), 0.0105), ((ax - sx * 0.045, wy - 0.07 - 0.35 * fl * 0.8, -0.045), 0.0085),
              ((ax - sx * 0.05, wy - 0.07 - 0.7 * fl * 0.8, -0.06), 0.0065)]
        ska.chain("plm" + tag, "th%s" % tag, tp)
        segs += [("shoulder_" + tag, (ax, 1.40, 0), (ax, 1.08, 0)), ("elbow_" + tag, (ax, 1.08, 0), (ax, wy, 0)),
                 ("hand_" + tag, (ax, wy, 0), (ax, wy - 0.1 - fl, -0.04)),
                 ("chest", (0, 1.44, 0), (sx * 0.2, 1.43, 0))]
        lx = sx * 0.11
        sk.v("hip" + tag, Pt(sx * 0.1, 0.88, 0), min(0.08 * L, 0.09), "pel")
        sk.v("th1" + tag, Pt(lx + sx * ko * 0.2, 0.76, 0), min(0.078 * L, 0.086), "hip" + tag)
        sk.v("th2" + tag, (lx + sx * ko * 0.45, 0.6, -0.004 - ko * 0.2), min(0.07 * L, 0.078), "th1" + tag)
        sk.v("th3" + tag, (lx + sx * ko * 0.85, 0.46, -0.012 - ko * 0.45), 0.056 * L, "th2" + tag)
        kx, kz = lx + sx * ko, -0.01 - ko * 0.5
        sk.v("kn" + tag, (kx, 0.34, kz), 0.041 * L, "th3" + tag)
        sk.v("c1" + tag, (lx + sx * ko * 0.6, 0.255, 0.018 - ko * 0.3), (0.046 * L, 0.054 * L), "kn" + tag)
        sk.v("c2" + tag, (lx + sx * ko * 0.2, 0.16, 0.014), (0.032 * L, 0.036 * L), "c1" + tag)
        sk.v("an" + tag, (lx, 0.07, 0.01), 0.0225 * L, "c2" + tag)
        sk.v("hl" + tag, (lx, 0.035, 0.045), 0.026, "an" + tag)
        sk.v("ft" + tag, (lx, 0.03, -0.055), (0.032, 0.022), "an" + tag)
        for k in range(4):
            tx = lx + (k - 1.5) * 0.019
            e = 1.5 - abs(k - 1.5)
            sk.chain("ft" + tag, "t%d%s" % (k, tag), [((tx, 0.022, -0.115 - 0.006 * e), 0.0115), ((tx * 1.03 - sx * 0.002, 0.013, -0.15 - 0.008 * e), 0.0085)])
        segs += [("hip_" + tag, (lx, 0.80, 0), (lx, 0.34, 0)), ("knee_" + tag, (lx, 0.34, 0), (lx, 0.07, 0)),
                 ("foot_" + tag, (lx, 0.07, 0.02), (lx, 0.02, -0.15))]
    return sk, segs, Y


def humanoid_sculpt(S, o, Y):
    """Anatomy on the fused surface. o as for humanoid() plus: ribs, belly (+ bloat, - sunken), collar,
    skull, brow, nose, tendon."""
    W, L = o.get("W", 1.0), o.get("L", 1.0)
    both = (-1, 1)
    hc = o.get("hc", (0.0, 1.7, -0.035))
    hy = Y(hc[1])
    hz = hc[2]
    front = (0, 0, -1)
    xm = 0.17 * W + 0.03
    ribs = o.get("ribs", 0.0)
    if ribs > 0.0:
        for i in range(6):          # rib ridges with the hollows between them, a gap at the sternum
            S.band(Y(1.36 - 0.042 * i), 0.0085, ribs * (1.0 - 0.08 * i), xm, slope=-0.03, xmin=0.035 + 0.012 * i)
            S.band(Y(1.36 - 0.042 * i - 0.021), 0.009, -ribs * 0.5, xm, slope=-0.03, xmin=0.035 + 0.012 * i)
        S.ridge((0, Y(1.46), -0.12), (0, Y(1.2), -0.125), 0.013, ribs * 0.55, facing=front)               # sternum
    if o.get("cavity", 0.0) != 0.0:
        S.bump((0, Y(1.3), -0.11), 0.1, -o["cavity"], facing=front)                  # an open chest: ribs stand proud of a dark hollow
    bel = o.get("belly", 0.0)
    if bel != 0.0:
        S.bump((0, Y(1.06), -0.12), 0.085 * W, 0.04 * bel, facing=front)       # + bloated, - sunken
    if o.get("warts", 0):
        rng = np.random.RandomState(7)
        for k in range(o["warts"]):                      # warts and pustules: back, shoulders, upper arms
            if k % 3 == 0:
                c = (rng.uniform(-0.26, 0.26), rng.uniform(1.0, 1.45), 0.0)
                S.bump((c[0] * 0.8 * W, Y(c[1]), 0.12), rng.uniform(0.012, 0.024), rng.uniform(0.008, 0.016), facing=(0, 0, 1))
            elif k % 3 == 1:
                sxk = 1 if k % 2 else -1
                S.bump((sxk * 0.29, Y(rng.uniform(1.1, 1.4)), rng.uniform(-0.04, 0.04)), rng.uniform(0.012, 0.02), rng.uniform(0.008, 0.015), facing=(sxk, 0, 0))
            else:
                S.bump((rng.uniform(-0.2, 0.2), Y(rng.uniform(0.95, 1.2)), -0.12), rng.uniform(0.012, 0.02), rng.uniform(0.007, 0.012), facing=front)
        for k in range(7):                               # swollen glands up the spine
            S.bump((0.0 + 0.045 * (k % 2) * (1 if k % 4 < 2 else -1), Y(1.0 + 0.07 * k), 0.12), 0.035 + 0.006 * k, 0.02 + 0.003 * k, facing=(0, 0, 1))
    cl = o.get("collar", 1.0)
    S.ridge((0.02, Y(1.47), -0.075), (0.2 * W, Y(1.455), -0.03), 0.011, 0.009 * cl, facing=(0, 0.3, -1), sx=both)    # clavicles
    S.bump((0.055, Y(1.5), -0.065), 0.03, -0.013 * cl, facing=(0, 0.4, -1), sx=both)                               # the hollow above them
    S.bump((0.12 * W, Y(0.985), -0.07), 0.026, 0.009, facing=(0.5, 0, -1), sx=both)                                  # hip points
    for i in range(11):                                                                                              # the spine
        S.bump((0, Y(0.98 + 0.046 * i), 0.1 + 0.015 * math.sin(i * 0.3)), 0.016, 0.007 * (1.0 if ribs > 0.0 else 0.4), facing=(0, 0, 1))
    S.bump((0.09 * W, Y(1.37), 0.095), 0.04, 0.007, facing=(0, 0, 1), sx=both)                                      # shoulder blades
    for sx in both:                                                                                                  # neck cords
        S.ridge((sx * 0.034, Y(1.62), hz + 0.02), (sx * 0.018, Y(1.465), -0.07), 0.009, 0.008 * cl, facing=(sx, 0, -0.6))
    wy = o.get("wrist", 0.74)
    for sx in both:
        ax = sx * 0.248
        for k in (-1, 0, 1):
            S.ridge((ax + k * 0.011, 0.97, -0.022), (ax + k * 0.008, wy + 0.01, -0.016), 0.0055, 0.0055 * o.get("tendon", 1.0), facing=(0, 0, -1))
        S.bump((ax, 1.08, 0.032), 0.02 * L, 0.011, facing=(0, 0, 1))
        S.bump((ax + sx * 0.012, wy + 0.012, -0.002), 0.014, 0.006, facing=(sx, 0, 0))
        S.ridge((ax + sx * 0.02, 1.2, -0.02), (ax + sx * 0.02, 1.05, -0.015), 0.012, 0.005, facing=(sx, 0, -0.5))
    ko = o.get("knee_out", 0.0)
    for sx in both:
        lx = sx * 0.11
        kx = lx + sx * ko
        S.bump((kx, 0.345, -0.045 - ko * 0.5), 0.028 * L, 0.014, facing=(0, 0, -1))
        S.ridge((kx, 0.31, -0.04 - ko * 0.4), (lx, 0.1, -0.03), 0.011, 0.009, facing=(0, 0, -1))
        S.ridge((lx, 0.3, 0.03), (lx, 0.055, 0.05), 0.0085, 0.008, facing=(0, 0, 1))
        for k in (-1, 1):
            S.ridge((kx + k * 0.022, 0.4, 0.03), (kx + k * 0.026, 0.3, 0.025), 0.007, 0.006, facing=(0, 0, 1))
        S.bump((lx + sx * 0.022, 0.065, 0.0), 0.016, 0.007)
        S.bump((lx - sx * 0.022, 0.065, 0.0), 0.016, 0.006)
    if not o.get("nohead"):
        head_sculpt(S, o, Y)
    S.noise(22.0, 0.0022)
    S.noise(61.0, 0.0008)
    S.folds(47.0, 0.0005)
