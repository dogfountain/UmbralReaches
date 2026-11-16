"""A rag wound round a skull by Blender's cloth simulation: a long strip laid in 2-3 turns that cross and overlap
(each turn a little further out so the layers start apart), a free tail, the head as the collision object, gravity and
self-collision for a few dozen frames until it settles into real folds and sags. Returns the shell (thickness added)
as rig-space vertices and faces, ready for Geo.mesh().

    P, F, tail_tip = rag_cloth.wind(head_P, head_F, centre, brow_y)
"""
import bpy
import math
import numpy as np


def _bl(p):                       # rig (x right, y up, z back) -> blender (x, -z, y)
    p = np.asarray(p, dtype=np.float64)
    return np.stack([p[..., 0], -p[..., 2], p[..., 1]], -1)


def _rig(p):
    p = np.asarray(p, dtype=np.float64)
    return np.stack([p[..., 0], p[..., 2], -p[..., 1]], -1)


def _radius(hv, c, y, ang, band=0.02):
    """How far the skull reaches from its axis at height y in the direction ang (rig xz plane)."""
    m = np.abs(hv[:, 1] - y) < band
    if not m.any():
        return 0.09
    d = hv[m] - c
    a = np.arctan2(d[:, 0], -d[:, 2])
    k = np.abs(((a - ang + math.pi) % (2 * math.pi)) - math.pi) < 0.35
    if not k.any():
        return float(np.hypot(d[:, 0], d[:, 2]).max())
    return float((np.hypot(d[:, 0], d[:, 2]) * np.cos(((a - ang + math.pi) % (2 * math.pi)) - math.pi))[k].max())


def wind(head_P, head_F, c, brow_y, turns=2.5, width=0.07, nu=64, nv=6, tail=0.0, frames=72, thick=0.0035, seed=1):
    sc = bpy.context.scene
    hv = np.asarray(head_P)
    c = np.asarray(c, dtype=np.float64)
    # --- the collision body: the head (and the neck) as a mesh ----------------------------------------
    me = bpy.data.meshes.new("rag_head")
    me.from_pydata(_bl(hv).tolist(), [], [list(f) for f in head_F])
    me.update()
    head = bpy.data.objects.new("rag_head", me)
    sc.collection.objects.link(head)
    head.modifiers.new("Collision", 'COLLISION')
    cs = head.collision
    cs.thickness_outer = 0.004
    cs.use_culling = False
    cs.cloth_friction = 12.0
    # --- the strip, laid round the head in crossing turns ------------------------------------------------
    nl = int(nu * (1.0 + tail / (turns * 2 * math.pi * 0.1)))
    pts = np.zeros((nl + 1, nv + 1, 3))
    rng = np.random.RandomState(seed)
    nturn = nu
    for i in range(nl + 1):
        s = i / nu                                                  # turns fraction along the wrapped part, >1 in the tail
        th = min(s, 1.0) * turns * 2 * math.pi
        turn = int(th / (2 * math.pi))
        ph = th + (0.5 * turn) * math.pi
        for j in range(nv + 1):
            t = j / nv - 0.5
            if s <= 1.0:
                yc = brow_y + 0.013 * turn + 0.02 * math.sin(ph + 0.9) + 0.005 * math.sin(th * 3.1)
                ang = th + math.radians(200)                           # begin at the back
                y = yc + t * width
                R = _radius(hv, c, y, ang) + 0.004 + 0.0045 * turn + 0.002 * abs(t) * 0.0
                pts[i, j] = [c[0] + math.sin(ang) * R, y, c[2] - math.cos(ang) * R]
            else:                                                  # the free tail: down the back of the neck
                th2 = turns * 2 * math.pi
                ang = th2 + math.radians(200)
                turn2 = int(th2 / (2 * math.pi))
                yc = brow_y + 0.013 * turn2 + 0.02 * math.sin(th2 + 0.5 * turn2 * math.pi + 0.9)
                y0 = yc + t * width
                R = _radius(hv, c, y0, ang) + 0.004 + 0.0045 * turn2
                drop = (s - 1.0) * (nu / nu) * tail / max((nl / nu - 1.0), 1e-6)
                pts[i, j] = [c[0] + math.sin(ang) * (R + 0.01 + 0.5 * drop), y0 - drop, c[2] - math.cos(ang) * (R + 0.01 + 0.5 * drop)]
    V = _bl(pts.reshape(-1, 3))
    faces = []
    for i in range(nl):
        for j in range(nv):
            a = i * (nv + 1) + j
            faces.append([a, a + nv + 1, a + nv + 2, a + 1])
    sm = bpy.data.meshes.new("rag_strip")
    sm.from_pydata(V.tolist(), [], faces)
    sm.update()
    strip = bpy.data.objects.new("rag_strip", sm)
    sc.collection.objects.link(strip)
    pin = strip.vertex_groups.new(name="pin")
    for i in range(0, int(nu) + 1):                         # the wrapped part is held at its top edge and loosens toward the lower edge
        for j in range(nv + 1):
            w_ = (j / nv) ** 1.6
            if i < 3:
                w_ = 1.0
            if w_ > 0.02:
                pin.add([i * (nv + 1) + j], w_, 'REPLACE')
    cl = strip.modifiers.new("Cloth", 'CLOTH')
    st = cl.settings
    st.quality = 6
    st.mass = 0.25
    st.tension_stiffness = 5.0
    st.compression_stiffness = 5.0
    st.shear_stiffness = 2.5
    st.bending_stiffness = 0.15
    st.air_damping = 2.0
    st.vertex_group_mass = "pin"
    st.pin_stiffness = 1.0
    cl.collision_settings.use_collision = True
    cl.collision_settings.distance_min = 0.004
    cl.collision_settings.collision_quality = 4
    cl.collision_settings.use_self_collision = True
    cl.collision_settings.self_distance_min = 0.0035
    cl.collision_settings.self_friction = 8.0
    cl.point_cache.frame_start = 1
    cl.point_cache.frame_end = frames
    sc.frame_start = 1
    sc.frame_end = frames
    for f in range(1, frames + 1):
        sc.frame_set(f)
    dg = bpy.context.evaluated_depsgraph_get()
    ev = strip.evaluated_get(dg)
    E = np.array([v.co[:] for v in ev.data.vertices])
    sc.frame_set(1)
    # --- thickness: a shell either side along the smooth normals ---------------------------------------
    N = np.zeros_like(E)
    for f in faces:
        n = np.cross(E[f[1]] - E[f[0]], E[f[2]] - E[f[0]]) + np.cross(E[f[2]] - E[f[0]], E[f[3]] - E[f[0]])
        for k in f:
            N[k] += n
    N /= np.maximum(np.linalg.norm(N, axis=1, keepdims=True), 1e-12)
    # sheet normals must face away from the head: flip those that point inward
    cc = _bl(c)
    inward = np.sum(N * (E - cc), axis=1) < 0
    if inward.mean() > 0.5:
        N = -N
    nv_ = len(E)
    Po = E + N * thick * 0.5
    Pi = E - N * thick * 0.5
    PP = np.concatenate([Po, Pi])
    FF = [list(f) for f in faces] + [[k + nv_ for k in f[::-1]] for f in faces]
    # rims: the shell's four borders
    def border(a, b):
        FF.append([a, b, b + nv_, a + nv_])
    for i in range(nl):
        border(i * (nv + 1), (i + 1) * (nv + 1))
        border((i + 1) * (nv + 1) + nv, i * (nv + 1) + nv)
    for j in range(nv):
        border(j + 1, j)
        border(nl * (nv + 1) + j, nl * (nv + 1) + j + 1)
    bpy.data.objects.remove(strip)
    bpy.data.objects.remove(head)
    return _rig(PP), FF, _rig(E[nl * (nv + 1) + nv // 2])
