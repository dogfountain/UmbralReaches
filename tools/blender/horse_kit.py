"""Horse anatomy for Umbral Reaches (art pass: horses). Joints, fused metaball flesh, weights.

Coordinates: G(x, y, z) is a Godot point (+Y up, the horse faces -Z, metres, ground y = 0). Everything
is laid out for a 15-hand palfrey (withers 1.52) and the breed's (sx, sy, sz) squash is applied to the
finished meshes and joints together (horse_build.py).

The flesh is metaball masses fused into ONE surface (torso+neck+head and four legs share a field, so
muscle flows into muscle: no capsule joints). Weights come from per-part meshes found by nearest
distance, so a fused vertex follows the limb whose flesh it came from.
"""
import math
import os
import sys
from mathutils import Vector

sys.path.insert(0, os.path.dirname(__file__))
import boss_kit as K
import grunt_kit as GK
from boss_kit import G
from grunt_kit import Flesh


def joints(P):
    """Bone joints of the rest pose (base space). P: breed parameters."""
    J = {}
    J["root"] = G(0, 0.0, 0.0)
    J["hips"] = G(0, 1.24, 0.46)
    J["barrel"] = G(0, 1.16, 0.0)
    J["chest"] = G(0, 1.18, -0.40)
    J["neck1"] = G(0, 1.30, -0.56)
    J["neck2"] = G(0, 1.48, -0.72)
    J["neck3"] = G(0, 1.63, -0.86)
    J["head"] = G(0, 1.74, -0.96)
    J["head_tip"] = G(0, 1.30, -1.24)
    for sx, s in ((1, "r"), (-1, "l")):
        # front: shoulder joint, knee, fetlock, hoof (ground)
        J["f%s_up" % s] = G(sx * 0.15, 1.16, -0.46)
        J["f%s_low" % s] = G(sx * 0.145, 0.53, -0.47)
        J["f%s_fet" % s] = G(sx * 0.145, 0.20, -0.45)
        J["f%s_toe" % s] = G(sx * 0.14, 0.0, -0.52)
        # hind: hip, hock (point behind), fetlock, hoof
        J["h%s_up" % s] = G(sx * 0.16, 1.22, 0.50)
        J["h%s_low" % s] = G(sx * 0.13, 0.63, 0.71)
        J["h%s_fet" % s] = G(sx * 0.125, 0.21, 0.64)
        J["h%s_toe" % s] = G(sx * 0.12, 0.0, 0.58)
        J["ear_%s" % s] = G(sx * 0.055, 1.80, -0.93)
    J["tail0"] = G(0, 1.44, 0.80)
    J["tail1"] = G(0, 1.36, 0.94)
    J["tail2"] = G(0, 1.02, 1.04)
    J["tail3"] = G(0, 0.70, 1.06)
    J["tail_tip"] = G(0, 0.38, 1.04)
    J["lantern"] = G(0.34, 1.22, 0.14)
    for i, (n, z) in enumerate((("mane1", -0.62), ("mane2", -0.78), ("mane3", -0.92))):
        pass
    return J


PARENT = {
    "root": None, "hips": "root", "barrel": "hips", "chest": "barrel",
    "neck1": "chest", "neck2": "neck1", "neck3": "neck2", "head": "neck3",
    "tail0": "hips", "tail1": "tail0", "tail2": "tail1", "tail3": "tail2",
    "lantern": "barrel", "ear_r": "head", "ear_l": "head",
    "mane1": "neck1", "mane2": "neck2", "mane3": "neck3",
    "fr_up": "chest", "fr_low": "fr_up", "fr_fet": "fr_low",
    "fl_up": "chest", "fl_low": "fl_up", "fl_fet": "fl_low",
    "hr_up": "hips", "hr_low": "hr_up", "hr_fet": "hr_low",
    "hl_up": "hips", "hl_low": "hl_up", "hl_fet": "hl_low",
}


def bone_ends(J):
    """Bone name -> (head, tail)."""
    E = {}
    E["root"] = (J["root"], J["root"] + G(0, 0.3, 0))
    E["hips"] = (J["hips"], J["barrel"])
    E["barrel"] = (J["barrel"], J["chest"])
    E["chest"] = (J["chest"], J["neck1"])
    E["neck1"] = (J["neck1"], J["neck2"])
    E["neck2"] = (J["neck2"], J["neck3"])
    E["neck3"] = (J["neck3"], J["head"])
    E["head"] = (J["head"], J["head_tip"])
    E["ear_r"] = (J["ear_r"], J["ear_r"] + G(0.01, 0.16, 0.03))
    E["ear_l"] = (J["ear_l"], J["ear_l"] + G(-0.01, 0.16, 0.03))
    E["tail0"] = (J["tail0"], J["tail1"])
    E["tail1"] = (J["tail1"], J["tail2"])
    E["tail2"] = (J["tail2"], J["tail3"])
    E["tail3"] = (J["tail3"], J["tail_tip"])
    E["lantern"] = (J["lantern"], J["lantern"] + G(0, -0.25, 0))
    # mane sway bones sit on the crest and hang outward-down (to the right of the neck)
    for n, nk in (("mane1", "neck1"), ("mane2", "neck2"), ("mane3", "neck3")):
        h, t = J[nk], J[{"neck1": "neck2", "neck2": "neck3", "neck3": "head"}[nk]]
        c = (h + t) * 0.5 + G(0, 0.12, 0)
        E[n] = (c, c + G(0.05, -0.2, 0.05))
    for s in ("r", "l"):
        E["f%s_up" % s] = (J["f%s_up" % s], J["f%s_low" % s])
        E["f%s_low" % s] = (J["f%s_low" % s], J["f%s_fet" % s])
        E["f%s_fet" % s] = (J["f%s_fet" % s], J["f%s_toe" % s])
        E["h%s_up" % s] = (J["h%s_up" % s], J["h%s_low" % s])
        E["h%s_low" % s] = (J["h%s_low" % s], J["h%s_fet" % s])
        E["h%s_fet" % s] = (J["h%s_fet" % s], J["h%s_toe" % s])
    return E


# --- flesh --------------------------------------------------------------------------------------------

def _cr(keys, t):
    """Catmull-Rom through keys [(t, v0, v1, ...)] at t."""
    n = len(keys)
    i = 0
    while i < n - 2 and keys[i + 1][0] < t:
        i += 1
    k0, k1 = keys[i], keys[i + 1]
    km = keys[max(i - 1, 0)]
    kp = keys[min(i + 2, n - 1)]
    u = max(0.0, min(1.0, (t - k0[0]) / max(k1[0] - k0[0], 1e-6)))
    out = []
    for j in range(1, len(k0)):
        p0, p1, p2, p3 = km[j], k0[j], k1[j], kp[j]
        out.append(0.5 * ((2 * p1) + (-p0 + p2) * u + (2 * p0 - 5 * p1 + 4 * p2 - p3) * u * u + (-p0 + 3 * p1 - 3 * p2 + p3) * u ** 3))
    return out


def spine_flesh_into(P, f):
    """Barrel, croup, chest, withers, neck."""
    nk = P.get("neck", 1.0)
    wb = P.get("barrel", 1.0)
    # barrel and quarters: sections (z, centre y, half width, half height), smoothly interpolated
    sec = [(-0.66, 1.02, 0.10, 0.20), (-0.58, 1.08, 0.17, 0.32), (-0.46, 1.13, 0.215, 0.39), (-0.30, 1.14, 0.235, 0.385),
           (-0.12, 1.11, 0.25, 0.35), (0.06, 1.12, 0.25, 0.31), (0.22, 1.18, 0.245, 0.29), (0.38, 1.22, 0.25, 0.29),
           (0.54, 1.22, 0.235, 0.28), (0.68, 1.22, 0.19, 0.25), (0.80, 1.22, 0.11, 0.17)]
    z = -0.66
    while z <= 0.80:
        cy, hw, hh = _cr(sec, z)
        f.ball(G(0, cy, z), (hw * wb * 0.93, hh * 0.93, 0.055), 3.0)
        z += 0.035
    f.ball(G(0, 1.41, -0.40), (0.07, 0.10, 0.13), 3.0)                  # withers
    f.ball(G(0, 1.41, 0.52), (0.14, 0.09, 0.16), 3.0)                   # croup top
    for sx in (-1, 1):
        f.ball(G(sx * 0.12, 0.98, -0.58), (0.09, 0.18, 0.11), 3.0)        # pectorals
        f.ball(G(sx * 0.20 * wb, 0.99, 0.38), (0.06, 0.1, 0.09), 3.0)    # flank / stifle fold
    # neck: oriented ellipsoids from the shoulders to the poll; deep at the base, a crest above
    npts = [(0.0, 1.20, -0.34, 0.16, 0.30), (0.34, 1.38, -0.56, 0.135, 0.235), (0.68, 1.57, -0.76, 0.108, 0.175), (1.0, 1.70, -0.90, 0.092, 0.14)]
    nrm = []
    prev = None
    for i in range(3):
        a = G(0, npts[i][1], npts[i][2])
        b = G(0, npts[i + 1][1], npts[i + 1][2])
        steps = 4
        for k in range(steps):
            u0, u1 = k / steps, (k + 1) / steps
            r0 = (npts[i][3] + (npts[i + 1][3] - npts[i][3]) * (u0 + u1) * 0.5) * nk
            d0 = (npts[i][4] + (npts[i + 1][4] - npts[i][4]) * (u0 + u1) * 0.5) * nk
            f.along(a.lerp(b, u0), a.lerp(b, u1), (r0 * 0.9, d0 * 0.9), (b - a).length / steps * 0.9, 3.0)
    f.along(G(0, 1.46, -0.58), G(0, 1.72, -0.86), (0.04 * nk, 0.07 * P.get("crest", 1.0)), None, 3.0)   # crest
    # the dock
    f.along(G(0, 1.44, 0.74), G(0, 1.40, 0.90), (0.055, 0.055), None, 3.0)


def torso_extras(P, J, f):
    """Shoulder and haunch masses (muscle belongs to the body; the leg lofts start inside them)."""
    for sx in (-1, 1):
        f.ball(G(sx * 0.17, 1.14, -0.5), (0.085, 0.2, 0.2), 3.0)
        f.ball(G(sx * 0.12, 1.2, -0.6), (0.07, 0.17, 0.12), 3.0)                # shoulder / triceps
        f.ball(G(sx * 0.18, 1.18, 0.56), (0.10, 0.22, 0.24), 3.0)                 # haunch
        f.ball(G(sx * 0.17, 1.0, 0.50), (0.09, 0.17, 0.18), 3.0)                   # thigh
        f.ball(G(sx * 0.19, 1.0, 0.40), (0.05, 0.08, 0.08), 3.0)                  # stifle


def _ring(c, u, v, rx, fy, by, n, sides):
    """Super-ellipse ring: half-width rx along u, fy toward +v, by toward -v."""
    pts = []
    for i in range(sides):
        a = math.tau * i / sides
        ca, sa = math.cos(a), math.sin(a)
        x = rx * math.copysign(abs(ca) ** (2.0 / n), ca)
        y = math.copysign(abs(sa) ** (2.0 / n), sa) * (fy if sa >= 0 else by)
        pts.append(c + u * x + v * y)
    return pts


def sloft(name, pts, secs, sides=20, cap0=False, cap1=True, mat=None, sock="spine"):
    """Loft a ring through pts (Blender space). secs[i] = (rx, front, back[, n[, fore-aft shift]]):
    rx lateral half width, front/back the half depths toward +v / -v (v = the section's fore-aft
    axis: forward for a leg, toward the face for the head)."""
    import bpy, bmesh
    bm = bmesh.new()
    rings = []
    n = len(pts)
    u_prev = None
    for i, p in enumerate(pts):
        t = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()
        ref = Vector((0, 1, 0)) if abs(t.y) < 0.9 else Vector((0, 0, 1))
        u = Vector((1, 0, 0))
        u = (u - t * u.dot(t)).normalized()
        v = u.cross(t).normalized()
        # v points toward +Blender-Y (forward) for a leg: make it so
        if v.y < 0 or (abs(v.y) < 1e-3 and v.z < 0):
            v = -v
        sec = secs[i]
        rx, fy, by = sec[0], sec[1], sec[2]
        sn = sec[3] if len(sec) > 3 else 2.4
        sh = sec[4] if len(sec) > 4 else 0.0
        ring = [bm.verts.new(q) for q in _ring(p + v * sh, u, v, rx, fy, by, sn, sides)]
        rings.append(ring)
    for i in range(n - 1):
        for k in range(sides):
            a, b = rings[i][k], rings[i][(k + 1) % sides]
            c, d = rings[i + 1][(k + 1) % sides], rings[i + 1][k]
            bm.faces.new((a, b, c, d))
    for end, flag in ((0, cap0), (n - 1, cap1)):
        if flag:
            c = bm.verts.new(sum((vv.co for vv in rings[end]), Vector()) / sides + (pts[end] - pts[end - 1 if end else 1]).normalized() * 0.01)
            for k in range(sides):
                bm.faces.new((rings[end][k], rings[end][(k + 1) % sides], c))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    ob["sock"] = sock
    return ob


def _smooth_pts(keys, steps):
    """Catmull-Rom resample keys [(y, z, ...)] into `steps` points per span."""
    out = []
    for i in range(len(keys) - 1):
        for k in range(steps):
            out.append(_cr([(j,) + tuple(kk) for j, kk in enumerate(keys)], i + k / steps))
    out.append(list(keys[-1]))
    return out


def leg_loft(P, J, s, front):
    sx = 1 if s == "r" else -1
    bn = P.get("bone", 1.0)
    fb = P.get("fetlock", 1.0)
    x = 0.14 * sx
    if front:
        # (y, z, rx, forward, back)
        keys = [(1.22, -0.46, 0.085, 0.12, 0.12), (1.05, -0.465, 0.078, 0.108, 0.10), (0.86, -0.468, 0.064, 0.088, 0.075),
                (0.68, -0.47, 0.05, 0.064, 0.055), (0.56, -0.47, 0.048 * bn, 0.06, 0.05), (0.52, -0.472, 0.052 * bn, 0.068, 0.055),
                (0.45, -0.468, 0.037 * bn, 0.048, 0.044), (0.33, -0.462, 0.031 * bn, 0.042, 0.04), (0.24, -0.455, 0.034 * bn, 0.047, 0.047),
                (0.195, -0.45, 0.041 * bn * fb, 0.052, 0.062 * fb), (0.15, -0.462, 0.034 * bn, 0.041, 0.042), (0.10, -0.485, 0.034 * bn, 0.04, 0.04),
                (0.075, -0.50, 0.036 * bn, 0.04, 0.04)]
    else:
        keys = [(1.28, 0.50, 0.12, 0.2, 0.2), (1.0, 0.56, 0.118, 0.17, 0.2), (0.84, 0.64, 0.088, 0.12, 0.15), (0.72, 0.69, 0.066, 0.08, 0.11),
                (0.64, 0.715, 0.056 * bn, 0.07, 0.12), (0.56, 0.705, 0.047 * bn, 0.055, 0.075), (0.46, 0.685, 0.037 * bn, 0.046, 0.05),
                (0.33, 0.66, 0.032 * bn, 0.042, 0.04), (0.24, 0.648, 0.034 * bn, 0.047, 0.047), (0.2, 0.64, 0.041 * bn * fb, 0.052, 0.062 * fb),
                (0.15, 0.625, 0.034 * bn, 0.041, 0.042), (0.10, 0.60, 0.034 * bn, 0.04, 0.04), (0.075, 0.585, 0.036 * bn, 0.04, 0.04)]
    pts = _smooth_pts([(k[0], k[1], k[2], k[3], k[4]) for k in keys], 3)
    P3 = [G(x, p[0], p[1]) for p in pts]
    secs = [(p[2], p[3], p[4], 2.6) for p in pts]
    return sloft(("f" if front else "h") + s + "_leg", P3, secs, 18, cap0=True, cap1=True, sock=("f" if front else "h") + s)


def head_loft(P, J):
    hl = P.get("head", 1.0)
    hw = P.get("headw", 1.0)
    A = G(0, 1.775, -0.935)
    B = G(0, 1.35, -1.235)
    ax = B - A
    # (t, rx, front, back, n)
    keys = [(-0.1, 0.03, 0.03, 0.03, 2.1), (-0.05, 0.075, 0.075, 0.08, 2.1), (0.04, 0.098, 0.092, 0.11, 2.1), (0.16, 0.112, 0.09, 0.16, 2.2),
            (0.27, 0.115, 0.082, 0.18, 2.2), (0.42, 0.1, 0.072, 0.135, 2.3), (0.58, 0.085, 0.066, 0.09, 2.4), (0.74, 0.08, 0.064, 0.078, 2.4),
            (0.88, 0.078, 0.06, 0.066, 2.3), (1.0, 0.066, 0.052, 0.05, 2.2)]
    ts = []
    for i in range(len(keys) - 1):
        for k in range(4):
            ts.append(keys[i][0] + (keys[i + 1][0] - keys[i][0]) * k / 4.0)
    ts.append(1.0)
    pts, secs = [], []
    hw = P.get("headw", 1.0)
    fs = P.get("faceslim", 1.0)
    for t in ts:
        v = _cr([(kk[0],) + kk[1:] for kk in keys], t)
        pts.append(A + ax * (t * hl))
        secs.append((v[0] * hw * (fs if t > 0.4 else 1.0), v[1], v[2], v[3]))
    ob = sloft("head", pts, secs, 22, cap0=True, cap1=True, sock="head")
    th = ax.normalized()
    vh = Vector((1, 0, 0)).cross(th).normalized()
    if vh.y < 0:
        vh = -vh
    extras = []

    def eb(t, x, off, rx, ra, rp):
        c = A + ax * (t * hl) + vh * (off * hl) + Vector((x * hw, 0, 0))
        extras.append(K.blob("hx", c, (rx * hw, ra * hl, rp * hl), "head", None, 14, 10))
    for sx in (-1, 1):
        eb(0.13, sx * 0.07, 0.03, 0.03, 0.045, 0.035)        # brow ridge
        eb(0.9, sx * 0.05, 0.0, 0.02, 0.028, 0.028)       # nostril flare
    eb(0.97, 0.0, -0.045, 0.036, 0.03, 0.03)                  # chin
    eb(1.0, 0.0, -0.01, 0.048, 0.03, 0.04)                    # lips
    import bpy
    bpy.ops.object.select_all(action='DESELECT')
    for e in extras + [ob]:
        e.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    ob["sock"] = "head"
    return ob


def build_body(P, J, fuse_res=0.008):
    """-> (fused high-poly body, {part: mesh} for the weights). Parts: torso+neck, head, four legs."""
    import bpy
    torso = Flesh("spine")
    spine_flesh_into(P, torso)
    torso_extras(P, J, torso)
    tobj = torso.build("part_spine", _flat(), 0.012, 0.0, 0.0)
    tobj["sock"] = "spine"
    parts = {"spine": tobj, "head": head_loft(P, J)}
    for s in ("r", "l"):
        parts["f" + s] = leg_loft(P, J, s, True)
        parts["h" + s] = leg_loft(P, J, s, False)
    parts["head"]["sock"] = "head"
    return parts


def fuse_parts(parts, voxel=0.008, smooth=3):
    import bpy
    objs = []
    for o in parts.values():
        c = o.copy()
        c.data = o.data.copy()
        bpy.context.scene.collection.objects.link(c)
        objs.append(c)
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    ob.name = "Body"
    r = ob.modifiers.new("Remesh", 'REMESH')
    r.mode = 'VOXEL'
    r.voxel_size = voxel
    r.adaptivity = 0.0
    K.apply_mods(ob)
    sm = ob.modifiers.new("Smooth", 'SMOOTH')
    sm.factor = 0.6
    sm.iterations = smooth * 2
    K.apply_mods(ob)
    for p in ob.data.polygons:
        p.use_smooth = True
    return ob


_FLAT = None


def _flat():
    import bpy
    global _FLAT
    if _FLAT is None:
        _FLAT = bpy.data.materials.new("flat")
    return _FLAT


# --- weights --------------------------------------------------------------------------------------------

def weight_funcs(J):
    """part -> fn(point) -> {bone: weight}."""
    sp = [("hips", J["hips"] + G(0, 0, 0.3)), ("barrel", J["barrel"]), ("chest", J["chest"]), ("neck1", J["neck1"]),
          ("neck2", J["neck2"]), ("neck3", J["neck3"]), ("head", J["head"])]
    W = {"spine": lambda p: GK.chain_w(p, sp[:-1], [0.1, 0.1, 0.08, 0.1, 0.08]),
         "head": lambda p: {"head": 1.0}}
    for s in ("r", "l"):
        W["f" + s] = (lambda s: lambda p: GK.chain_w(p, [("chest", J["f%s_up" % s] + G(0, 0.2, 0)), ("f%s_up" % s, J["f%s_up" % s]),
                                                          ("f%s_low" % s, J["f%s_low" % s]), ("f%s_fet" % s, J["f%s_fet" % s])],
                                                      [0.12, 0.05, 0.035]))(s)
        W["h" + s] = (lambda s: lambda p: GK.chain_w(p, [("hips", J["h%s_up" % s] + G(0, 0.2, 0)), ("h%s_up" % s, J["h%s_up" % s]),
                                                          ("h%s_low" % s, J["h%s_low" % s]), ("h%s_fet" % s, J["h%s_fet" % s])],
                                                      [0.13, 0.05, 0.035]))(s)
    return W


def assign_weights(body, pobjs, funcs, tau=0.018):
    """Vertex groups on the fused body: each part's weights, blended by how near its own mesh is."""
    from mathutils.kdtree import KDTree
    trees = {}
    for n, o in pobjs.items():
        t = KDTree(len(o.data.vertices))
        for v in o.data.vertices:
            t.insert(o.matrix_world @ v.co, v.index)
        t.balance()
        trees[n] = t
    groups = {}
    for v in body.data.vertices:
        p = body.matrix_world @ v.co
        d = {n: t.find(p)[2] for n, t in trees.items()}
        dmin = min(d.values())
        mem = {n: math.exp(-(dd - dmin) / tau) for n, dd in d.items() if dd - dmin < tau * 6}
        tot = sum(mem.values())
        acc = {}
        for n, m in mem.items():
            for b, w in funcs[n](p).items():
                acc[b] = acc.get(b, 0.0) + w * m / tot
        # keep the four strongest (glTF)
        top = sorted(acc.items(), key=lambda kv: -kv[1])[:4]
        s = sum(w for _, w in top) or 1.0
        for b, w in top:
            if w / s < 0.02:
                continue
            if b not in groups:
                groups[b] = body.vertex_groups.get(b) or body.vertex_groups.new(name=b)
            groups[b].add([v.index], w / s, 'REPLACE')


# --- small parts ------------------------------------------------------------------------------------------

def head_frame(P):
    """(A, ax, hl, hw, th, vh): the head loft's axis start, vector, scales and frame (v toward the face)."""
    hl = P.get("head", 1.0)
    hw = P.get("headw", 1.0)
    A = G(0, 1.775, -0.935)
    B = G(0, 1.35, -1.235)
    ax = B - A
    th = ax.normalized()
    vh = Vector((1, 0, 0)).cross(th).normalized()
    if vh.y < 0:
        vh = -vh
    return A, ax, hl, hw, th, vh


def head_pt(P, t, x, off):
    A, ax, hl, hw, th, vh = head_frame(P)
    return A + ax * (t * hl) + vh * (off * hl) + Vector((x * hw, 0, 0))


def ears(P, J):
    out = []
    ea = P.get("ear", 1.0)
    for sx in (-1, 1):
        base = head_pt(P, 0.0, sx * 0.058, 0.07)
        pts = []
        secs = []
        for k in range(8):
            t = k / 7.0
            # a leaf: base to a point, curving in and slightly forward
            up = Vector((sx * (0.012 * t + 0.03 * t * t), 0.012 * t * 0.5 - 0.035 * t * t, 0.105 * ea * t))
            pts.append(base + up)
            w = 0.04 * (1.0 - t) ** 0.6 * (0.8 + 0.5 * math.sin(min(t * 2.2, 1.6))) + 0.004
            secs.append((w * 0.8, 0.012 * (1.0 - t) + 0.003, 0.014 * (1.0 - t) + 0.003, 2.1))
        out.append(sloft("ear%s" % ("r" if sx > 0 else "l"), pts, secs, 10, cap0=True, cap1=True, sock="ear_%s" % ("r" if sx > 0 else "l")))
    return out


def eyes(P, eye_mat):
    out = []
    A, ax, hl, hw, th, vh = head_frame(P)
    for sx in (-1, 1):
        c = head_pt(P, 0.2, sx * 0.112, 0.035)
        ob = K.blob("eye", c, (0.017, 0.021 * hl, 0.02 * hl), "head", eye_mat, 14, 8)
        # tilt a little outward
        out.append(ob)
    return out


def nostrils(P, mat):
    out = []
    for sx in (-1, 1):
        c = head_pt(P, 0.93, sx * 0.034, 0.006)
        ob = K.blob("nostril", c + Vector((0, 0.012 * P.get("head", 1.0), 0)), (0.012, 0.011, 0.02), "head", mat, 8, 6)
        out.append(ob)
    return out


def hooves(P, J, mat):
    out = []
    bn = P.get("bone", 1.0)
    hf = P.get("hoof", 1.0)
    for front in (True, False):
        for s in ("r", "l"):
            sx = 1 if s == "r" else -1
            if front:
                z0 = -0.50
                dz = -0.055
                rx0, rx1 = 0.04 * bn, 0.056 * hf
            else:
                z0 = 0.585
                dz = -0.05
                rx0, rx1 = 0.04 * bn, 0.052 * hf
            x = 0.14 * sx if front else 0.125 * sx
            pts = [G(x, 0.1, z0 + 0.012), G(x, 0.075, z0), G(x, 0.04, z0 + dz * 0.5), G(x, 0.004, z0 + dz)]
            secs = [(rx0 * 1.05, 0.04, 0.042, 2.2), (rx0 * 1.25, 0.048, 0.046, 2.2), (rx1 * 0.95, 0.075 * hf, 0.05, 2.3), (rx1, 0.095 * hf, 0.058, 2.4)]
            out.append(sloft(("f" if front else "h") + s + "_hoof", pts, secs, 16, cap0=True, cap1=True, sock=("f" if front else "h") + s))
    return out


# --- hair -----------------------------------------------------------------------------------------------

def _bez(p0, p1, p2, t):
    return p0 * (1 - t) ** 2 + p1 * 2 * (1 - t) * t + p2 * t * t


def lock(name, p0, p1, p2, width, segs, sock, uv_u, rng, thick=0.0, curl=0.0):
    """A hair lock: a tapering curved ribbon p0 -> p2 (control p1), width w at the root to a point,
    cupped across (a ridge down the middle). Returns a mesh object with UVs at u in [uv_u, uv_u + 1/6]
    of the hair strip (u0 + 0.8 .. 1.0 is chosen later) and v along the length."""
    import bpy, bmesh
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    rows = []
    for i in range(segs + 1):
        t = i / segs
        c = _bez(p0, p1, p2, t)
        tan = (_bez(p0, p1, p2, min(t + 0.02, 1.0)) - _bez(p0, p1, p2, max(t - 0.02, 0.0)))
        tan.normalize()
        side = tan.cross(Vector((0, 0, 1)))
        if side.length < 0.1:
            side = tan.cross(Vector((0, 1, 0)))
        side.normalize()
        # twist a little
        nrm = side.cross(tan).normalized()
        # full through most of its length, then thinning to a fine wisp (a hair tip, not a cut triangle)
        w = width * (1.0 - t ** 2.6) ** 1.4 * (0.55 + 0.45 * math.sin(math.pi * min(1.0, t * 1.5 + 0.18)) )
        w = max(w, 0.0004)
        cup = w * 0.35 + thick
        rows.append((bm.verts.new(c - side * w), bm.verts.new(c + nrm * cup), bm.verts.new(c + side * w)))
    for i in range(segs):
        a, b = rows[i], rows[i + 1]
        for (x0, x1) in ((0, 1), (1, 2)):
            f = bm.faces.new((a[x0], a[x1], b[x1], b[x0]))
            for lp in f.loops:
                vi = i if lp.vert in (a[0], a[1], a[2]) else i + 1
                col = 0 if lp.vert in (a[0], b[0]) else (1 if lp.vert in (a[1], b[1]) else 2)
                lp[uvl].uv = (uv_u + col * (1.0 / 12.0), vi / segs)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    ob["sock"] = sock
    ob["hair"] = 1
    return ob


def neck_crest(P, J, t):
    """Point on the neck's crest at t (0 withers .. 1 poll) and the half width there (base space)."""
    pts = [(1.20, -0.34, 0.16, 0.30), (1.38, -0.56, 0.135, 0.235), (1.57, -0.76, 0.108, 0.175), (1.70, -0.90, 0.092, 0.14)]
    f = t * 3.0
    i = min(int(f), 2)
    u = f - i
    a, b = pts[i], pts[i + 1]
    y = a[0] + (b[0] - a[0]) * u
    z = a[1] + (b[1] - a[1]) * u
    rx = (a[2] + (b[2] - a[2]) * u) * P.get("neck", 1.0)
    rd = (a[3] + (b[3] - a[3]) * u) * P.get("neck", 1.0)
    # crest sits at the top of the neck's depth along the surface normal (neck leans forward)
    d = (G(0, b[0], b[1]) - G(0, a[0], a[1])).normalized()
    up = d.cross(Vector((1, 0, 0)))          # toward the top surface
    if up.z < 0:
        up = -up
    return G(0, y, z) + up * (rd * 0.95 + 0.02), rx, d


def mane(P, J, rng, side=1, count=70):
    out = []
    vol = P.get("mane", 1.0)
    for k in range(count):
        t = (k + rng.uniform(-0.3, 0.3)) / (count - 1)
        t = min(max(t, 0.0), 1.0)
        root, rx, d = neck_crest(P, J, t)
        L = rng.uniform(0.22, 0.34) * (1.15 - 0.3 * t) * vol
        out_x = side * (rx * 1.0 + 0.03)
        p0 = root + Vector((side * 0.004, 0, 0))
        p1 = root + Vector((out_x * 0.75, 0, 0.02)) + Vector((0, 0.0, 0.0))
        p2 = root + Vector((out_x * 1.15 + side * rng.uniform(0.0, 0.05), -d.y * 0.0, -L * 0.95)) + Vector((0, rng.uniform(-0.02, 0.04), 0))
        p1 = (p0 + p2) * 0.5 + Vector((side * rx * 0.55, 0.0, 0.03))
        w = rng.uniform(0.055, 0.08)
        out.append(lock("mane", p0, p1, p2, w, 7, "mane_%d" % (1 + min(2, int(t * 3.0))), rng.randrange(0, 6) / 6.0, rng))
    return out


def forelock(P, J, rng, count=9):
    out = []
    for k in range(count):
        a = (k / (count - 1) - 0.5) * 2.0
        root = head_pt(P, 0.0, a * 0.04, 0.07) + Vector((0, 0.02, 0.01))
        p2 = head_pt(P, 0.09, a * 0.05, 0.1) + Vector((0, 0.04, -0.12 + rng.uniform(-0.03, 0.02)))
        p1 = (root + p2) * 0.5 + Vector((0, 0.05, 0.05))
        out.append(lock("forelock", root, p1, p2, rng.uniform(0.014, 0.022), 4, "head", rng.randrange(0, 6) / 6.0, rng))
    return out


def tail(P, J, rng, count=64):
    out = []
    vol = P.get("tail", 1.0)
    base = J["tail1"] + G(0, 0.02, 0.0)
    for k in range(count):
        a = rng.uniform(0, math.tau)
        r = math.sqrt(rng.random()) * 0.05
        root = base + G(math.cos(a) * r * 1.1, math.sin(a) * r * 0.5, 0.0) + G(0, 0.02, -0.01)
        L = rng.uniform(0.78, 1.15) * vol
        sway = rng.uniform(-0.06, 0.06)
        p2 = root + G(sway + math.cos(a) * 0.06, -L * 0.93 + 0.3 * 0.0, 0.1 + math.sin(a) * 0.06 + rng.uniform(0.0, 0.08))
        p1 = root + G(sway * 0.4 + math.cos(a) * 0.06, -0.12, 0.12 + math.sin(a) * 0.05)
        p2.z = max(p2.z, 0.0) if False else p2.z
        out.append(lock("tail", root, p1, p2, rng.uniform(0.06, 0.09), 6, "tail", rng.randrange(0, 6) / 6.0, rng))
    return out


def feathers(P, J, rng):
    out = []
    amt = P.get("feather", 0.0)
    if amt <= 0.0:
        return out
    for front in (True, False):
        for s in ("r", "l"):
            sx = 1 if s == "r" else -1
            fet = J[("f" if front else "h") + s + "_fet"]
            n = int(11 * min(amt, 1.2) + 4)
            for k in range(n):
                a = math.tau * (k + rng.uniform(-0.3, 0.3)) / n
                r = 0.038
                root = fet + G(math.cos(a) * r, 0.045 + rng.uniform(-0.01, 0.03), math.sin(a) * r)
                L = rng.uniform(0.09, 0.16) * amt
                p2 = root + G(math.cos(a) * 0.035, -L - 0.07, math.sin(a) * 0.035 - 0.015)
                p1 = (root + p2) * 0.5 + G(math.cos(a) * 0.05, 0.0, math.sin(a) * 0.05)
                out.append(lock("feather", root, p1, p2, rng.uniform(0.022, 0.034), 4, ("f" if front else "h") + s + "_fet", rng.randrange(0, 6) / 6.0, rng))
    return out
