"""Human bodies from MakeHuman's base mesh (MPFB, CC0 output), shaped per kind and retargeted to the game's rig.

The game's humanoid rig (CharacterRig/HunchRig) stands arms hanging straight down with its joints at fixed sockets
(hips 0.75, knees 0.33, shoulders 1.40, elbows 1.08, wrists 0.78). MakeHuman stands in an A-pose with its own
proportions. Each MakeHuman bone gets an affine map from its segment to the rig's (rotation onto the rig's bone,
stretch along it, a girth factor across it), and every vertex is carried by its own skin weights, so the body arrives
continuous, anatomical and in the rig's rest pose. A sculpted base, not tubes and balls.

    import mh_body; P, F, eyes = mh_body.human(macro={...}, girth=1.0, head=1.15, tris=9000)
P: rig-space vertices, F: faces (vertex indices), eyes: [left, right] eye centres in rig space.
"""
import bpy
import math
import numpy as np

from bl_ext.blender_org.mpfb.services.humanservice import HumanService
from bl_ext.blender_org.mpfb.services.targetservice import TargetService


def to_rig(A):
    """MakeHuman/Blender (X, Y, Z), facing -Y, character's left at +X  ->  rig (x right, y up, z back), facing -Z."""
    A = np.asarray(A, dtype=np.float64)
    return np.stack([-A[..., 0], A[..., 2], A[..., 1]], -1)


def _rot_onto(a, b):
    a = a / max(np.linalg.norm(a), 1e-9)
    b = b / max(np.linalg.norm(b), 1e-9)
    v = np.cross(a, b)
    c = float(a @ b)
    if np.linalg.norm(v) < 1e-8:
        if c > 0:
            return np.eye(3)
        p = np.array([1.0, 0, 0]) if abs(a[0]) < 0.9 else np.array([0, 1.0, 0])
        v = np.cross(a, p)
        v /= np.linalg.norm(v)
        return 2.0 * np.outer(v, v) - np.eye(3)
    vx = np.array([[0, -v[2], v[1]], [v[2], 0, -v[0]], [-v[1], v[0], 0]])
    return np.eye(3) + vx + vx @ vx * (1.0 / (1.0 + c))


class Seg:
    """An affine taking a source segment h->t onto a target h2->t2: rotate, stretch along, girth across."""

    def __init__(self, h, t, h2, t2, girth=1.0, along=None):
        self.h, self.h2 = h, h2
        a = t - h
        b = t2 - h2
        self.ax = a / max(np.linalg.norm(a), 1e-9)
        self.R = _rot_onto(a, b)
        self.s = (np.linalg.norm(b) / max(np.linalg.norm(a), 1e-9)) if along is None else along
        self.g = girth

    def __call__(self, P):
        d = P - self.h
        al = (d @ self.ax)[:, None] * self.ax
        pe = d - al
        return self.h2 + (self.s * al + self.g * pe) @ self.R.T


def human(macro=None, girth=1.0, limb=1.0, head=1.15, tris=9000, hunch=0.0, shoulder_y=1.40):
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o)
    md = TargetService.get_default_macro_info_dict()
    md.update(macro or {})
    h = HumanService.create_human(macro_detail_dict=md)
    TargetService.bake_targets(h)
    rig = HumanService.add_builtin_rig(h, "default")
    J = {b.name: (to_rig(rig.matrix_world @ b.head_local), to_rig(rig.matrix_world @ b.tail_local)) for b in rig.data.bones}
    me = h.data
    n = len(me.vertices)
    co = np.empty(n * 3)
    me.vertices.foreach_get('co', co)
    P = to_rig(co.reshape(-1, 3) @ np.array(h.matrix_world)[:3, :3].T + np.array(h.matrix_world)[:3, 3])
    gi = {g.index: g.name for g in h.vertex_groups}
    bodyg = h.vertex_groups["body"].index
    eye_groups = {h.vertex_groups["joint-l-eye"].index: 0, h.vertex_groups["joint-r-eye"].index: 1}
    keep = np.zeros(n, bool)
    eye_pts = [[], []]
    W = {}
    for v in me.vertices:
        for g in v.groups:
            if g.group == bodyg:
                keep[v.index] = True
            elif g.group in eye_groups:
                eye_pts[eye_groups[g.group]].append(P[v.index])
            nm = gi[g.group]
            if nm in J and g.weight > 0.0:
                W.setdefault(nm, ([], []))
                W[nm][0].append(v.index)
                W[nm][1].append(g.weight)
    # --- the target skeleton: the rig's sockets ---------------------------------------------------------
    segs = {}
    hipc = (J["pelvis.L"][0] + J["pelvis.R"][0]) * 0.5
    neck = J["neck01"][0] if "neck01" in J else J["head"][0]
    torso = Seg(hipc, neck, np.array([0.0, 0.8, 0.0]), np.array([0.0, shoulder_y + 0.12, -0.02 + hunch * 0.1]), girth)
    headseg = Seg(J["head"][0], J["head"][1], np.array([0.0, shoulder_y + 0.2, -0.02]), np.array([0.0, shoulder_y + 0.2 + 0.15 * head, -0.03]), head, along=head)
    for side, sx in (("L", -1.0), ("R", 1.0)):
        up_h, lo_h, wr_h = J["upperarm01." + side][0], J["lowerarm01." + side][0], J["wrist." + side][0]
        th_h, kn_h, an_h = J["upperleg01." + side][0], J["lowerleg01." + side][0], J["foot." + side][0]
        S_SH, S_EL, S_WR = np.array([sx * 0.22, shoulder_y + 0.02, 0.0]), np.array([sx * 0.24, 1.08, 0.0]), np.array([sx * 0.24, 0.79, 0.0])
        S_HIP, S_KN, S_AN = np.array([sx * 0.11, 0.75, 0.0]), np.array([sx * 0.11, 0.33, -0.02]), np.array([sx * 0.11, 0.075, 0.0])
        ua = Seg(up_h, lo_h, S_SH, S_EL, limb)
        la = Seg(lo_h, wr_h, S_EL, S_WR, limb)
        hand = Seg(wr_h, wr_h + (wr_h - lo_h), S_WR, S_WR + (S_WR - S_EL) * 0.5, limb, along=1.0)
        ul = Seg(th_h, kn_h, S_HIP, S_KN, limb)
        ll = Seg(kn_h, an_h, S_KN, S_AN, limb)
        ft = Seg(an_h, J["toe3-1." + side][0] if ("toe3-1." + side) in J else an_h + np.array([0, -0.07, -0.12]),
                 S_AN, S_AN + np.array([0.0, -0.065, -0.13]), limb, along=1.0)
        cl = Seg(J["clavicle." + side][0], up_h, np.array([sx * 0.04, shoulder_y + 0.04, 0.0]), S_SH, girth)
        for nm in J:
            if not nm.endswith("." + side):
                continue
            if nm.startswith(("upperarm",)):
                segs[nm] = ua
            elif nm.startswith(("lowerarm",)):
                segs[nm] = la
            elif nm.startswith(("wrist", "finger", "metacarpal", "thumb")):
                segs[nm] = hand
            elif nm.startswith(("upperleg", "pelvis")):
                segs[nm] = ul if nm.startswith("upperleg") else torso
            elif nm.startswith(("lowerleg",)):
                segs[nm] = ll
            elif nm.startswith(("foot", "toe")):
                segs[nm] = ft
            elif nm.startswith(("clavicle", "shoulder")):
                segs[nm] = cl
            else:
                segs[nm] = torso
    for nm in J:
        if nm not in segs:
            low = nm.lower()
            segs[nm] = headseg if any(k in low for k in ("head", "jaw", "eye", "tongue", "teeth", "levator", "oris", "risorius", "nose", "temporalis", "cheek", "brow", "lip")) else torso
    # --- carry every vertex by its weights ------------------------------------------------------------
    out = np.zeros_like(P)
    wsum = np.zeros(n)
    for nm, (idx, ws) in W.items():
        idx = np.asarray(idx)
        ws = np.asarray(ws)
        out[idx] += segs[nm](P[idx]) * ws[:, None]
        wsum[idx] += ws
    lone = wsum < 1e-6
    out[lone] = torso(P[lone])
    wsum[lone] = 1.0
    out /= wsum[:, None]
    eyes = [headseg(np.asarray(e).mean(0)[None, :])[0] if e else None for e in eye_pts]
    # --- the body only, decimated to the budget --------------------------------------------------------
    for v, p in zip(me.vertices, out):
        v.co = (p[0], -p[2], p[1])            # back to Blender axes as the rig's own (x, -z, y)
    h.matrix_world = __import__("mathutils").Matrix.Identity(4)
    bpy.ops.object.select_all(action='DESELECT')
    for o in list(bpy.data.objects):
        if o is not h:
            bpy.data.objects.remove(o)
    bpy.context.view_layer.objects.active = h
    h.select_set(True)
    if h.data.shape_keys:
        h.shape_key_clear()
    for m in list(h.modifiers):
        h.modifiers.remove(m)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='DESELECT')
    bpy.ops.object.mode_set(mode='OBJECT')
    for i, v in enumerate(h.data.vertices):
        v.select = not keep[i]
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.delete(type='VERT')
    bpy.ops.object.mode_set(mode='OBJECT')
    jg = {}
    gnames = {g.index: g.name for g in h.vertex_groups}
    for v in h.data.vertices:
        best, bw = None, 0.0
        for gr in v.groups:
            nm = gnames.get(gr.group)
            if nm in J and gr.weight > bw:
                best, bw = nm, gr.weight
        jt = joint_of(best)
        if jt not in jg:
            jg[jt] = h.vertex_groups.new(name="J_" + jt)
        jg[jt].add([v.index], 1.0, 'REPLACE')
    cur = sum(len(p.vertices) - 2 for p in h.data.polygons)
    if cur > tris:
        d = h.modifiers.new("Dec", 'DECIMATE')
        d.ratio = max(tris / cur, 0.4)                 # the head is spared, so the body pays: never thin it to a wire
        if "J_head" in h.vertex_groups:                  # the face keeps the detail it was sculpted with: thin the body only
            d.vertex_group = "J_head"
            d.invert_vertex_group = True
            d.vertex_group_factor = 1.0
        bpy.ops.object.modifier_apply(modifier=d.name)
    me = h.data
    Q = np.array([(v.co.x, v.co.z, -v.co.y) for v in me.vertices])
    F = [list(p.vertices) for p in me.polygons]
    # MakeHuman's own unwrap (the skin layout its textures are painted on), scaled to metres so a tile laid on
    # it keeps the same grain everywhere: metres per UV unit from the mean edge ratio
    uvd = me.uv_layers.active.data
    L3, L2 = 0.0, 0.0
    for p in me.polygons:
        li = list(p.loop_indices)
        for a, b in zip(li, li[1:] + li[:1]):
            L3 += (me.vertices[me.loops[a].vertex_index].co - me.vertices[me.loops[b].vertex_index].co).length
            L2 += (uvd[a].uv - uvd[b].uv).length
    k = L3 / max(L2, 1e-9)
    FUV = [[(uvd[li].uv[0] * k, uvd[li].uv[1] * k) for li in p.loop_indices] for p in me.polygons]
    jname = {g.index: g.name[2:] for g in h.vertex_groups if g.name.startswith("J_")}
    L = []
    for v in me.vertices:
        best, bw = "chest", 0.0
        for gr in v.groups:
            if gr.group in jname and gr.weight > bw:
                best, bw = jname[gr.group], gr.weight
        L.append(best)
    bpy.data.objects.remove(h)
    return Q, F, eyes, FUV, L


def joint_of(bone):
    """MakeHuman's bone -> the rig joint (socket) that carries it. .L is the character's left: rig x < 0, '_l'."""
    if bone is None:
        return "chest"
    b = bone.lower()
    t = "l" if b.endswith(".l") else ("r" if b.endswith(".r") else "")
    if b.startswith("upperarm") or b.startswith("shoulder"):
        return "shoulder_" + t
    if b.startswith("lowerarm"):
        return "elbow_" + t
    if b.startswith(("wrist", "finger", "metacarpal", "thumb")):
        return "hand_" + t
    if b.startswith("upperleg"):
        return "hip_" + t
    if b.startswith("lowerleg"):
        return "knee_" + t
    if b.startswith(("foot", "toe")):
        return "foot_" + t
    if b.startswith(("root", "pelvis", "spine05", "spine04")):
        return "pelvis"
    if b.startswith(("neck02", "neck03", "head", "jaw", "eye", "tongue", "teeth")) or t == "" and b not in ("spine01", "spine02", "spine03", "neck01"):
        return "head" if not b.startswith(("spine", "breast", "clavicle")) else "chest"
    if any(k in b for k in ("levator", "oris", "risorius", "nose", "temporalis", "cheek", "brow", "lip", "ear", "orbicularis")):
        return "head"
    return "chest"
