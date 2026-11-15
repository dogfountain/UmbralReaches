"""The Thornwarden's skeleton and his authored motion.

boss_thornwarden.py builds and bakes the body (art/blender/boss_thornwarden.blend, mesh `body`). This script opens
that file, throws away the flat socket armature (16 rigid joints posed by formula in the game) and gives him a real
one: a spine of four, neck, head and jaw, a tail of four, and four legs solved by IK from foot controls, so a
planted hoof stays planted while the body moves over it. Then it keys his clips and exports
art/models/boss_thornwarden.glb with the animations in it. core/enemy/clip_rig.gd plays them.

    tools/blender/run.sh boss_thornwarden_anim.py -- [--preview <dir>] [--no-export] [--only walk,strike]

Rig space is the game's: x right, y up, z back, facing -Z, metres at scale 1 (the boss is scaled in game).
Angles are radians about rig axes: pitch about +X (nose up), yaw about +Y (turn left), roll about +Z.
"""
import bpy
import math
import os
import sys
import numpy as np
from mathutils import Matrix, Vector, Quaternion

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
FPS = 30


def arg(name, default=None):
    return ARGS[ARGS.index(name) + 1] if name in ARGS else default


def bl(p):
    return Vector((p[0], -p[2], p[1]))


def V(x, y, z):
    return np.array([x, y, z], dtype=np.float64)


# --- the skeleton (rig space) ---------------------------------------------------------------------------
# name: (head, tail, parent, deform)
BONES = {
    "root": (V(0, 0, 0), V(0, 0, -0.2), None, False),
    "hips": (V(0, 0.80, 0.42), V(0, 0.83, 0.12), "root", True),
    "spine1": (V(0, 0.83, 0.12), V(0, 0.86, -0.16), "hips", True),
    "spine2": (V(0, 0.86, -0.16), V(0, 0.84, -0.42), "spine1", True),
    "chest": (V(0, 0.84, -0.42), V(0, 0.78, -0.62), "spine2", True),
    "neck": (V(0, 0.78, -0.62), V(0, 0.72, -0.80), "chest", True),
    "head": (V(0, 0.72, -0.80), V(0, 0.64, -1.28), "neck", True),
    "jaw": (V(0, 0.60, -0.82), V(0, 0.52, -1.22), "head", True),
    "tail1": (V(0, 0.72, 0.52), V(0, 0.62, 0.72), "hips", True),
    "tail2": (V(0, 0.62, 0.72), V(0, 0.46, 0.90), "tail1", True),
    "tail3": (V(0, 0.46, 0.90), V(0, 0.32, 1.06), "tail2", True),
    "tail4": (V(0, 0.32, 1.06), V(0, 0.22, 1.24), "tail3", True),
}
LEGS = {}          # tag -> dict(upper, lower, hoof, ik, ankle)
for tag, sx, front in (("fl", -1, True), ("fr", 1, True), ("bl", -1, False), ("br", 1, False)):
    if front:
        top, knee, ankle, toe = V(sx * 0.2, 0.62, -0.40), V(sx * 0.2, 0.30, -0.33), V(sx * 0.2, 0.075, -0.41), V(sx * 0.2, 0.0, -0.47)
        par = "chest"
    else:
        top, knee, ankle, toe = V(sx * 0.19, 0.64, 0.36), V(sx * 0.2, 0.31, 0.27), V(sx * 0.2, 0.075, 0.40), V(sx * 0.2, 0.0, 0.34)
        par = "hips"
    BONES["up_" + tag] = (top, knee, par, True)
    BONES["lo_" + tag] = (knee, ankle, "up_" + tag, True)
    BONES["hoof_" + tag] = (ankle, toe, "lo_" + tag, True)
    BONES["ik_" + tag] = (ankle, ankle + V(0, 0, -0.12), "root", False)
    LEGS[tag] = {"sx": sx, "front": front, "ankle": ankle}
DEFORM = [k for k, v in BONES.items() if v[3]]


def build_armature():
    arm_data = bpy.data.armatures.new("ThornRig")
    arm = bpy.data.objects.new("ThornRig", arm_data)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode='EDIT')
    for name, (h, t, par, deform) in BONES.items():
        b = arm_data.edit_bones.new(name)
        b.head, b.tail = bl(h), bl(t)
        b.roll = 0.0
        b.use_deform = deform
    for name, (h, t, par, deform) in BONES.items():
        if par:
            arm_data.edit_bones[name].parent = arm_data.edit_bones[par]
    bpy.ops.object.mode_set(mode='POSE')
    for pb in arm.pose.bones:
        pb.rotation_mode = 'QUATERNION'
    for tag in LEGS:
        ik = arm.pose.bones["lo_" + tag].constraints.new('IK')
        ik.target = arm
        ik.subtarget = "ik_" + tag
        ik.chain_count = 2
        cr = arm.pose.bones["hoof_" + tag].constraints.new('COPY_ROTATION')
        cr.target = arm
        cr.subtarget = "ik_" + tag
        cr.mix_mode = 'ADD'
        cr.target_space = 'LOCAL'
        cr.owner_space = 'LOCAL'
    bpy.ops.object.mode_set(mode='OBJECT')
    return arm


# --- skinning -------------------------------------------------------------------------------------------

def seg_dist(P, a, b):
    ab = b - a
    t = np.clip(((P - a) @ ab) / max(float(ab @ ab), 1e-9), 0.0, 1.0)
    return np.sqrt(((P - (a + t[:, None] * ab)) ** 2).sum(1))


def soft_pick(P, names, band):
    """Weights among `names` for points P: nearest bone segment, blending over `band` to its neighbours."""
    D = np.stack([seg_dist(P, BONES[n][0], BONES[n][1]) for n in names], 1)
    w = np.clip(1.0 - (D - D.min(1, keepdims=True)) / band, 0.0, 1.0) ** 2
    return w / w.sum(1, keepdims=True)


def skin(body, arm):
    me = body.data
    n = len(me.vertices)
    co = np.empty(n * 3)
    me.vertices.foreach_get('co', co)
    co = co.reshape(-1, 3)
    P = np.stack([co[:, 0], co[:, 2], -co[:, 1]], 1)          # mesh is at the origin, unrotated: Blender -> rig
    # the old socket groups say which part of the body a vertex belongs to (the antlers are head, not back)
    old = {g.index: g.name for g in body.vertex_groups}
    label = np.array(["body"] * n, dtype=object)
    best = np.zeros(n)
    for v in me.vertices:
        for g in v.groups:
            if g.weight > best[v.index]:
                best[v.index] = g.weight
                label[v.index] = old[g.group]
    idx = {nm: i for i, nm in enumerate(DEFORM)}
    W = np.zeros((n, len(DEFORM)))

    def put(mask, names, band):
        if mask.any():
            w = soft_pick(P[mask], names, band)
            for j, nm in enumerate(names):
                W[mask, idx[nm]] = w[:, j]

    # antler beams sweep back over the shoulders, where the old body group won them: they are the skull's
    is_head = (label == "head") | ((P[:, 1] > 1.02) & (np.abs(P[:, 0]) > 0.13) & (P[:, 2] < 0.2)) | ((P[:, 1] > 1.4) & (P[:, 2] < 0.2))
    # ...but the mane canes along the withers are the back's, not the skull's (they streaked when the head swung)
    mane = (np.abs(P[:, 0]) < 0.13) & (P[:, 2] > -0.62) & (P[:, 1] > 0.9) & (P[:, 1] < 1.45)
    is_head &= ~mane
    label[mane & (label == "head")] = "body"
    label[is_head] = "head"
    jaw = is_head & (P[:, 1] < 0.605) & (P[:, 2] < -0.80) & (np.abs(P[:, 0]) < 0.22)
    put(is_head & ~jaw, ["head"], 0.1)
    put(jaw, ["jaw"], 0.1)
    put(label == "front", ["chest", "neck", "head"], 0.12)
    put(label == "body", ["hips", "spine1", "spine2", "chest"], 0.22)
    put(label == "tail", ["hips", "tail1", "tail2", "tail3", "tail4"], 0.1)
    for tag in LEGS:
        put(label == "leg_%s_hip" % tag, ["up_" + tag], 0.1)
        put(label == "leg_%s_knee" % tag, ["lo_" + tag], 0.1)
        put(label == "leg_%s_foot" % tag, ["hoof_" + tag], 0.1)
    # blend across the joints: a few passes of neighbour averaging over the mesh
    e = np.empty(len(me.edges) * 2, dtype=np.int32)
    me.edges.foreach_get('vertices', e)
    e = e.reshape(-1, 2)
    cnt = np.maximum(np.bincount(e.ravel(), minlength=n), 1).astype(np.float64)
    hard = is_head & ~jaw & (P[:, 1] > 0.95)                     # antlers stay rigid with the skull
    for _ in range(6):
        s = np.zeros_like(W)
        for k in range(W.shape[1]):
            s[:, k] = np.bincount(e[:, 0], weights=W[e[:, 1], k], minlength=n) + np.bincount(e[:, 1], weights=W[e[:, 0], k], minlength=n)
        W2 = 0.5 * W + 0.5 * s / cnt[:, None]
        W2[hard] = W[hard]
        W = W2
    top = np.argsort(-W, 1)[:, :4]
    mask = np.zeros_like(W)
    np.put_along_axis(mask, top, 1.0, 1)
    W = W * mask
    W = W / np.maximum(W.sum(1, keepdims=True), 1e-9)
    body.vertex_groups.clear()
    for nm in DEFORM:
        g = body.vertex_groups.new(name=nm)
        k = idx[nm]
        sel = np.nonzero(W[:, k] > 0.01)[0]
        wq = np.round(W[sel, k] * 100.0) / 100.0
        for v in np.unique(wq):
            g.add(sel[wq == v].tolist(), float(v), 'REPLACE')
    for m in list(body.modifiers):
        body.modifiers.remove(m)
    body.parent = arm
    body.matrix_parent_inverse = Matrix.Identity(4)
    md = body.modifiers.new("Armature", 'ARMATURE')
    md.object = arm
    print("SKIN", n, "verts,", int(jaw.sum()), "jaw,", int(hard.sum()), "antler")


# --- posing ---------------------------------------------------------------------------------------------

def rig_rot(pitch=0.0, yaw=0.0, roll=0.0):
    """A rotation given about rig axes, as a matrix in Blender (armature) space."""
    return Matrix.Rotation(yaw, 3, 'Z') @ Matrix.Rotation(pitch, 3, 'X') @ Matrix.Rotation(-roll, 3, 'Y')


class Poser:
    def __init__(self, arm):
        self.arm = arm
        self.rest = {b.name: b.bone.matrix_local.to_3x3() for b in arm.pose.bones}

    def set(self, frame, pose):
        """pose: {bone: (pitch, yaw, roll)} and {"hips_at": (x, y, z)}, {"ik_fl": ((x, y, z) offset, toe pitch)}"""
        for pb in self.arm.pose.bones:
            name = pb.name
            B = self.rest[name]
            if name.startswith("ik_"):
                off, toe = pose.get(name, ((0, 0, 0), 0.0))
                pb.location = B.inverted() @ bl(off)
                pb.rotation_quaternion = (B.inverted() @ rig_rot(toe) @ B).to_quaternion()
                pb.keyframe_insert("location", frame=frame)
                pb.keyframe_insert("rotation_quaternion", frame=frame)
                continue
            if name in ("root",) or name.startswith(("up_", "lo_", "hoof_")):
                continue
            r = pose.get(name, (0.0, 0.0, 0.0))
            pb.rotation_quaternion = (B.inverted() @ rig_rot(*r) @ B).to_quaternion()
            pb.keyframe_insert("rotation_quaternion", frame=frame)
            if name == "hips":
                pb.location = B.inverted() @ bl(pose.get("hips_at", (0, 0, 0)))
                pb.keyframe_insert("location", frame=frame)


def sm(a, b, x):
    t = min(max((x - a) / (b - a), 0.0), 1.0)
    return t * t * (3.0 - 2.0 * t)


def lerp(a, b, t):
    return a + (b - a) * t


def mix(p, q, t):
    """Blend two poses."""
    out = {}
    for k in set(p) | set(q):
        a, b = p.get(k), q.get(k)
        if k.startswith("ik_"):
            a = a or ((0, 0, 0), 0.0)
            b = b or ((0, 0, 0), 0.0)
            out[k] = (tuple(lerp(a[0][i], b[0][i], t) for i in range(3)), lerp(a[1], b[1], t))
        else:
            a = a or (0.0, 0.0, 0.0)
            b = b or (0.0, 0.0, 0.0)
            out[k] = tuple(lerp(a[i], b[i], t) for i in range(3))
    return out


TAU = math.tau
TAIL = ["tail1", "tail2", "tail3", "tail4"]


def tail_wave(t, amp, speed=1.0, lag=0.75, droop=0.0, phase=0.0):
    return {b: (droop * (0.5 + 0.25 * i) + 0.4 * amp * math.sin(TAU * speed * 2 * t - i * lag + phase), amp * (1.0 + 0.35 * i) * math.sin(TAU * speed * t - i * lag + phase), 0.0)
            for i, b in enumerate(TAIL)}


def breath(t, rate=1.0):
    return 0.5 - 0.5 * math.cos(TAU * rate * t)


# --- the clips -------------------------------------------------------------------------------------------
# each returns the pose at u in 0..1; loops must return the same pose at 0 and 1

def idle(u):
    b = breath(u, 2.0)                                  # two breaths in the loop
    shift = math.sin(TAU * u)                            # weight rolls from one side to the other, once
    look = math.sin(TAU * u + 0.6) * 0.5 + math.sin(TAU * 2 * u) * 0.2
    p = {"hips_at": (0.03 * shift, -0.012 * b - 0.01, 0.0), "hips": (0.01 * b, 0.02 * shift, 0.035 * shift),
         "spine1": (0.012 * b, -0.015 * shift, -0.01 * shift), "spine2": (0.02 * b, -0.01 * shift, -0.015 * shift),
         "chest": (0.03 * b, 0.05 * look, -0.02 * shift), "neck": (0.02 * b - 0.03, 0.14 * look, 0.03 * look),
         "head": (-0.04 * b + 0.03 * math.sin(TAU * 2 * u + 1.0), 0.2 * look, -0.05 * look), "jaw": (-0.03 - 0.05 * b, 0, 0)}
    p.update(tail_wave(u, 0.16, 1.0, 0.8, droop=0.02 * b))
    # he paws the ground once with the right forefoot
    k = sm(0.58, 0.66, u) * (1.0 - sm(0.72, 0.8, u))
    scrape = math.sin(sm(0.62, 0.78, u) * math.pi)
    p["ik_fr"] = ((0.0, 0.09 * k, -0.05 * k + 0.1 * scrape * k), -0.5 * k)
    return p


def gait(u, phases, duty, half, lift, toe=0.5):
    """Foot controls for a cycle: each leg is on the ground for `duty` of it, sweeping from `half` ahead to `half`
    behind at the body's pace, then swings forward in an arc."""
    out = {}
    for tag, ph in phases.items():
        s = (u - ph) % 1.0
        if s < duty:                                     # stance: straight back under the body
            k = s / duty
            z = lerp(-half, half, k)
            y = 0.0
            pitch = -0.25 * sm(0.8, 1.0, k)              # heel peels off at the end
        else:                                            # swing
            k = (s - duty) / (1.0 - duty)
            e = k * k * (3.0 - 2.0 * k)
            z = lerp(half, -half, e)
            y = lift * math.sin(math.pi * k) ** 0.8
            pitch = -toe * math.sin(math.pi * min(k * 1.6, 1.0)) + 0.3 * sm(0.75, 1.0, k)
        out["ik_" + tag] = ((0.0, y, z), pitch)
    return out


WALK_PH = {"bl": 0.0, "fl": 0.25, "br": 0.5, "fr": 0.75}
WALK_HALF, WALK_DUTY = 0.26, 0.68


def walk(u):
    p = gait(u, WALK_PH, WALK_DUTY, WALK_HALF, 0.11)
    a = TAU * u
    # the weight goes onto each planted pair in turn: two drops and two rolls a cycle, the withers a beat after the hips
    p["hips_at"] = (0.035 * math.sin(a + 0.4), -0.03 - 0.022 * math.cos(2 * a + 0.3), 0.0)
    p["hips"] = (0.018 * math.sin(2 * a), 0.07 * math.sin(a), 0.06 * math.sin(a + 0.4))
    p["spine1"] = (0.01 * math.sin(2 * a + 1.0), -0.05 * math.sin(a), -0.03 * math.sin(a + 0.4))
    p["spine2"] = (0.012 * math.sin(2 * a + 1.6), -0.05 * math.sin(a), -0.04 * math.sin(a + 0.4))
    p["chest"] = (0.03 * math.sin(2 * a + 2.2) - 0.02, -0.06 * math.sin(a + 0.3), -0.06 * math.sin(a + 1.9))
    p["neck"] = (0.05 * math.sin(2 * a + 2.9) - 0.06, 0.04 * math.sin(a + 0.9), 0.03 * math.sin(a + 1.9))
    p["head"] = (0.06 * math.sin(2 * a + 3.6) + 0.02, 0.05 * math.sin(a + 1.3), 0.04 * math.sin(a + 2.2))   # the antlers nod a beat late
    p["jaw"] = (-0.04 - 0.03 * math.sin(2 * a + 4.0), 0, 0)
    p.update(tail_wave(u, 0.2, 1.0, 0.9, droop=0.03 * math.sin(2 * a)))
    return p


RUN_PH = {"bl": 0.0, "br": 0.1, "fl": 0.48, "fr": 0.58}
RUN_HALF, RUN_DUTY = 0.34, 0.36


def run(u):
    p = gait(u, RUN_PH, RUN_DUTY, RUN_HALF, 0.2, toe=0.8)
    a = TAU * u
    gather = math.sin(a - 0.6)                           # +1 gathered under himself, -1 stretched
    p["hips_at"] = (0.0, -0.02 + 0.07 * math.sin(a + 0.9), 0.03 * gather)
    p["hips"] = (0.16 * gather, 0.0, 0.02 * math.sin(a))
    p["spine1"] = (-0.07 * gather, 0, 0)
    p["spine2"] = (-0.09 * gather, 0, 0)
    p["chest"] = (-0.12 * gather - 0.03, 0, 0.02 * math.sin(a + 1.0))
    p["neck"] = (0.1 * math.sin(a + 0.4) + 0.05, 0, 0)
    p["head"] = (0.12 * math.sin(a + 1.2) - 0.04, 0, 0.03 * math.sin(a + 2.0))
    p["jaw"] = (-0.14 - 0.08 * math.sin(a + 2.0), 0, 0)
    for i, b in enumerate(TAIL):
        p[b] = (-0.1 + 0.16 * math.sin(a - 0.9 * i + 2.2), 0.05 * math.sin(a * 0.5 - i), 0.0)
    return p


def coil(k=1.0, tremble=0.0):
    """The gathered tell: haunches down and back, the forehand up, head and antlers hauled high, jaw open."""
    t = tremble
    return {"hips_at": (0.0, -0.16 * k, 0.13 * k), "hips": (0.2 * k, 0.0, 0.012 * t),
            "spine1": (0.05 * k, 0, 0), "spine2": (0.08 * k, 0, 0.01 * t), "chest": (0.12 * k, 0, -0.012 * t),
            "neck": (0.32 * k + 0.02 * t, 0, 0), "head": (-0.22 * k + 0.03 * t, 0.02 * t, 0), "jaw": (-0.42 * k - 0.05 * t, 0, 0),
            "tail1": (-0.3 * k, 0, 0), "tail2": (-0.25 * k, 0.03 * t, 0), "tail3": (-0.2 * k, 0.05 * t, 0), "tail4": (-0.15 * k, 0.08 * t, 0),
            "ik_fl": ((0.0, 0.0, -0.04 * k), 0.0), "ik_fr": ((0.0, 0.05 * k, -0.1 * k), -0.35 * k)}


def windup(u):
    k = 1.0 - (1.0 - sm(0.0, 1.0, u)) ** 2               # fast in, easing into the coil
    dip = math.sin(sm(0.0, 0.3, u) * math.pi) * 0.05     # a small drop forward first: the anticipation of the anticipation
    p = mix(idle(0.0), coil(1.0), k)
    p["hips_at"] = (p["hips_at"][0], p["hips_at"][1] - dip, p["hips_at"][2] - dip)
    return p


def windup_hold(u):
    tr = math.sin(TAU * 6 * u) * 0.7 + math.sin(TAU * 10 * u + 1.3) * 0.3
    return coil(1.0 + 0.06 * breath(u, 1.0), tr)


def strike(u):
    """From the coil: the whole weight thrown forward and down through the skull, a jolt, then he gathers himself."""
    slam = {"hips_at": (0.0, -0.05, -0.26), "hips": (-0.14, 0, 0), "spine1": (-0.08, 0, 0), "spine2": (-0.12, 0, 0),
            "chest": (-0.16, 0, 0), "neck": (-0.2, 0, 0), "head": (-0.12, 0, 0), "jaw": (-0.02, 0, 0),
            "tail1": (0.35, 0, 0), "tail2": (0.3, 0, 0), "tail3": (0.25, 0, 0), "tail4": (0.2, 0, 0),
            "ik_fl": ((0.0, 0.0, -0.2), 0.0), "ik_fr": ((0.0, 0.0, -0.24), 0.0), "ik_bl": ((0.0, 0.0, 0.06), -0.3), "ik_br": ((0.0, 0.0, 0.06), -0.3)}
    if u < 0.14:                                         # the blow: 4 frames
        k = (u / 0.14) ** 2
        p = mix(coil(1.0), slam, k)
        lift = math.sin(k * math.pi) * 0.12              # forefeet leave the ground and come down with it
        for tag in ("fl", "fr"):
            off, toe = p["ik_" + tag]
            p["ik_" + tag] = ((off[0], off[1] + lift, off[2]), toe)
        return p
    if u < 0.4:                                          # the jolt: it rings through him
        k = (u - 0.14) / 0.26
        j = math.exp(-5.0 * k) * math.sin(TAU * 2.5 * k)
        p = dict(slam)
        p["hips_at"] = (0.0, -0.05 - 0.04 * j, -0.26)
        p["neck"] = (-0.2 + 0.1 * j, 0, 0)
        p["head"] = (-0.12 - 0.08 * j, 0.0, 0.05 * j)
        p["jaw"] = (-0.02 - 0.2 * max(j, 0.0), 0, 0)
        for i, b in enumerate(TAIL):
            p[b] = (0.35 - 0.05 * i - 0.25 * math.exp(-3.0 * k) * math.sin(TAU * 2.0 * k - 0.6 * i), 0, 0)
        return p
    k = sm(0.4, 1.0, u)                                  # recovery: the hips come back first, the head last
    p = mix(slam, idle(0.0), k)
    late = sm(0.55, 1.0, u)
    p["neck"] = tuple(lerp(slam["neck"][i], idle(0.0)["neck"][i], late) for i in range(3))
    p["head"] = tuple(lerp(slam["head"][i], idle(0.0)["head"][i], late) for i in range(3))
    for tag in ("fl", "fr", "bl", "br"):                 # each foot steps back under him in turn
        a0 = {"fl": 0.45, "fr": 0.6, "bl": 0.5, "br": 0.68}[tag]
        s = sm(a0, a0 + 0.2, u)
        off, toe = slam["ik_" + tag]
        p["ik_" + tag] = ((0.0, 0.08 * math.sin(s * math.pi), off[2] * (1.0 - s)), toe * (1.0 - s))
    return p


def stagger(u):
    """Knocked off his feet's rhythm: the forehand buckles, the head swings low and shakes, he hauls himself up."""
    hit = math.exp(-6.0 * u)
    down = sm(0.05, 0.22, u) * (1.0 - sm(0.68, 0.98, u))
    shake = math.sin(TAU * 4.5 * u) * sm(0.2, 0.3, u) * (1.0 - sm(0.55, 0.75, u))
    p = {"hips_at": (0.1 * down + 0.05 * hit, -0.1 * down, 0.1 * down + 0.08 * hit), "hips": (-0.07 * down + 0.1 * hit, 0.12 * down, 0.14 * down),
         "spine1": (-0.05 * down, 0.04 * down, 0.03 * down), "spine2": (-0.08 * down, 0.05 * down, 0.05 * down),
         "chest": (-0.12 * down + 0.15 * hit, 0.08 * down, 0.1 * down), "neck": (-0.22 * down + 0.3 * hit, 0.25 * down + 0.2 * shake, 0.1 * shake),
         "head": (-0.16 * down + 0.25 * hit, 0.3 * down + 0.35 * shake, 0.25 * shake), "jaw": (-0.35 * down - 0.1 * hit, 0, 0),
         "ik_fl": ((-0.05 * down, 0.0, 0.1 * down), 0.0), "ik_fr": ((0.1 * down, 0.06 * math.sin(sm(0.05, 0.25, u) * math.pi), 0.02 * down), 0.0),
         "ik_br": ((0.12 * down, 0.05 * math.sin(sm(0.1, 0.3, u) * math.pi), 0.08 * down), 0.0)}
    for i, b in enumerate(TAIL):
        p[b] = (0.2 * down - 0.3 * hit, 0.25 * math.sin(TAU * 2.0 * u - 0.7 * i) * (down + hit), 0.0)
    return mix(p, idle(0.0), sm(0.85, 1.0, u))


def howl(u):
    up = sm(0.0, 0.25, u) * (1.0 - sm(0.8, 1.0, u))
    quake = math.sin(TAU * 9 * u) * sm(0.25, 0.35, u) * (1.0 - sm(0.7, 0.8, u))
    p = {"hips_at": (0.0, -0.06 * up, 0.05 * up), "hips": (0.1 * up, 0, 0), "spine2": (0.06 * up, 0, 0), "chest": (0.14 * up + 0.01 * quake, 0, 0),
         "neck": (0.5 * up, 0.02 * quake, 0), "head": (0.45 * up + 0.02 * quake, 0, 0.03 * quake), "jaw": (-0.6 * sm(0.18, 0.32, u) * (1.0 - sm(0.72, 0.85, u)) - 0.03 * quake, 0, 0)}
    for i, b in enumerate(TAIL):
        p[b] = (-0.25 * up, 0.08 * quake * (i + 1) * 0.5, 0)
    return mix(p, idle(0.0), sm(0.9, 1.0, u))


def air(u):
    f = math.sin(TAU * u) * 0.03
    p = {"hips_at": (0.0, 0.05, 0.0), "hips": (-0.1, 0, 0), "spine1": (0.03, 0, 0), "spine2": (0.05, 0, 0), "chest": (0.1, 0, 0),
         "neck": (0.05 + f, 0, 0), "head": (-0.15, 0, 0), "jaw": (-0.5, 0, 0),
         "ik_fl": ((0.0, 0.22, -0.3 + f), -0.6), "ik_fr": ((0.0, 0.26, -0.36 - f), -0.6), "ik_bl": ((0.0, 0.16, 0.34), -0.9), "ik_br": ((0.0, 0.12, 0.4 + f), -0.9)}
    for i, b in enumerate(TAIL):
        p[b] = (-0.2 + 0.05 * math.sin(TAU * u - i), 0.03 * math.sin(TAU * u - i), 0)
    return p


def land(u):
    crush = math.sin(sm(0.0, 0.35, u) * math.pi * 0.5) * (1.0 - sm(0.35, 1.0, u))
    p = {"hips_at": (0.0, -0.2 * crush, -0.05 * crush), "hips": (-0.08 * crush, 0, 0), "chest": (-0.14 * crush, 0, 0), "neck": (-0.25 * crush, 0, 0),
         "head": (-0.2 * crush, 0, 0), "jaw": (-0.1 - 0.3 * crush, 0, 0)}
    for i, b in enumerate(TAIL):
        p[b] = (0.3 * crush, 0, 0)
    return mix(mix(air(0.0), p, sm(0.0, 0.2, u)), idle(0.0), sm(0.6, 1.0, u))


def death(u):
    """A last heave, the forehand gives, he goes down onto his chest and over onto his flank; the head falls last."""
    heave = math.sin(sm(0.0, 0.18, u) * math.pi)
    front = sm(0.16, 0.36, u)                            # forelegs fold
    back = sm(0.3, 0.52, u)                              # haunches follow
    over = sm(0.42, 0.66, u)                             # onto the flank
    head = sm(0.5, 0.72, u)
    bounce = math.exp(-7.0 * max(u - 0.72, 0.0)) * math.sin(TAU * 5.0 * max(u - 0.72, 0.0)) * (1.0 if u > 0.72 else 0.0)
    settle = sm(0.7, 1.0, u)
    p = {"hips_at": (0.12 * over, -0.25 * back - 0.04 * front + 0.03 * heave, -0.05 * front),
         "hips": (-0.2 * front + 0.17 * back + 0.08 * heave, 0.1 * over, 0.38 * over),
         "spine1": (-0.04 * front, 0.05 * over, 0.08 * over), "spine2": (-0.06 * front, 0.06 * over, 0.1 * over),
         "chest": (-0.1 * front + 0.2 * heave, 0.1 * over, 0.14 * over),
         "neck": (0.35 * heave - 0.12 * head + 0.05 * bounce, 0.25 * head, 0.2 * head),
         "head": (0.3 * heave - 0.1 * head + 0.1 * bounce, 0.3 * head, 0.45 * head), "jaw": (-0.5 * heave - 0.3 * head - 0.1 * bounce, 0, 0),
         "ik_fl": ((-0.1 * front, 0.02 * front, 0.2 * front), 0.5 * front), "ik_fr": ((0.14 * over, 0.05 * over, 0.26 * front), 0.6 * front),
         "ik_bl": ((-0.06 * back, 0.0, -0.16 * back), -0.4 * back), "ik_br": ((0.2 * over, 0.1 * over, -0.2 * back), -0.6 * back)}
    for i, b in enumerate(TAIL):
        p[b] = (-0.3 * heave + 0.5 * back * (0.6 + 0.2 * i) + 0.04 * bounce * (i + 1), 0.3 * over * math.sin(1.0 + i * 0.6) * (1.0 - 0.4 * settle), 0.0)
    return p


# name: (fn, seconds, loops)
CLIPS = {
    "idle": (idle, 5.0, True), "walk": (walk, 1.5, True), "run": (run, 0.72, True),
    "windup": (windup, 0.6, False), "windup_hold": (windup_hold, 1.0, True), "strike": (strike, 1.15, False),
    "stagger": (stagger, 1.7, False), "howl": (howl, 2.2, False), "air": (air, 0.5, True), "land": (land, 0.5, False),
    "death": (death, 2.6, False),
}


def key_clips(arm, poser, only=None):
    arm.animation_data_create()
    made = {}
    for name, (fn, secs, loops) in CLIPS.items():
        if only and name not in only:
            continue
        act = bpy.data.actions.new(name)
        arm.animation_data.action = act
        n = max(2, round(secs * FPS))
        for f in range(n + 1):
            poser.set(f, fn(f / n))
        act.use_fake_user = True
        act.frame_range = (0, n)
        made[name] = (act, n)
    # one NLA track per clip: the exporter writes each as an animation of that name
    arm.animation_data.action = None
    for name, (act, n) in made.items():
        tr = arm.animation_data.nla_tracks.new()
        tr.name = name
        st = tr.strips.new(name, 0, act)
        st.name = name
        tr.mute = True
    return made


def show(arm, made, name, frame):
    for tr in arm.animation_data.nla_tracks:
        tr.mute = tr.name != name
        tr.is_solo = tr.name == name
    bpy.context.scene.frame_set(frame)


def preview(arm, body, made, out_dir):
    """Strips of each clip, side-on and three-quarter, to judge the poses before the game sees them."""
    os.makedirs(out_dir, exist_ok=True)
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_WORKBENCH'
    sc.display.shading.light = 'STUDIO'
    sc.display.shading.color_type = 'SINGLE'
    sc.display.shading.single_color = (0.62, 0.56, 0.48)
    sc.display.shading.show_cavity = True
    sc.display.shading.show_shadows = True
    sc.render.resolution_x, sc.render.resolution_y = 520, 400
    sc.render.film_transparent = False
    cam_d = bpy.data.cameras.new("PCam")
    cam_d.lens = 60
    cam = bpy.data.objects.new("PCam", cam_d)
    sc.collection.objects.link(cam)
    sc.camera = cam
    floor = bpy.ops.mesh.primitive_plane_add(size=12, location=(0, 0, 0))
    for o in bpy.data.objects:
        if o.type == 'MESH' and o is not body and o.name != "Plane":
            o.hide_render = True
    for name, (act, n) in made.items():
        for view, pos in (("side", V(-5.2, 1.0, 0.0)), ("q34", V(-3.6, 1.5, -3.6))):
            cam.location = bl(pos)
            look = bl(V(0, 0.75, 0.0)) - cam.location
            cam.rotation_euler = look.to_track_quat('-Z', 'Y').to_euler()
            paths = []
            cols = 8
            for i in range(cols):
                f = round(i * n / (cols if CLIPS[name][2] else cols - 1))
                show(arm, made, name, f)
                sc.render.filepath = os.path.join(out_dir, "_%s_%s_%02d.png" % (name, view, i))
                bpy.ops.render.render(write_still=True)
                paths.append(sc.render.filepath)
            imgs = [bpy.data.images.load(p) for p in paths]
            w, h = imgs[0].size
            sheet = np.zeros((h, w * cols, 4), dtype=np.float32)
            for i, im in enumerate(imgs):
                px = np.empty(w * h * 4, dtype=np.float32)
                im.pixels.foreach_get(px)
                sheet[:, i * w:(i + 1) * w] = px.reshape(h, w, 4)
            out = bpy.data.images.new("sheet", w * cols, h)
            out.pixels.foreach_set(sheet.ravel())
            out.filepath_raw = os.path.join(out_dir, "%s_%s.png" % (name, view))
            out.file_format = 'PNG'
            out.save()
            for p in paths:
                os.remove(p)
            for im in imgs:
                bpy.data.images.remove(im)
    for tr in arm.animation_data.nla_tracks:
        tr.is_solo = False
        tr.mute = True
    print("PREVIEW", out_dir)


def export(arm, body):
    bpy.ops.object.select_all(action='DESELECT')
    arm.select_set(True)
    body.select_set(True)
    bpy.context.view_layer.objects.active = arm
    for tr in arm.animation_data.nla_tracks:
        tr.mute = False
        tr.is_solo = False
    path = os.path.join(os.environ.get("BOSS_OUT", os.path.join(ROOT, "art", "models")), "boss_thornwarden.glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True, export_apply=False, export_yup=True,
                              export_materials='EXPORT' if "--built" in ARGS else 'NONE', export_vertex_color='ACTIVE' if "--built" in ARGS else 'NONE',
                              export_active_vertex_color_when_no_material=True, export_normals=True, export_tangents=True, export_texcoords=True,
                              export_skins=True, export_def_bones=True, export_animations=True,
                              export_animation_mode='NLA_TRACKS', export_force_sampling=True, export_frame_step=1,
                              export_all_influences=False, export_optimize_animation_size=False)
    print("EXPORTED", path)


def main():
    if "--built" in ARGS:
        # a body BUILT for tiling materials (grunt_build.thornwarden), labelled with his old socket names
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        import grunt_build
        bpy.ops.wm.read_factory_settings(use_empty=True)
        body = grunt_build.thornwarden()[0]
        if "--bake" in ARGS:
            import bake_kind
            bake_kind.bake(body, "thornwarden", size=int(arg("--size", "2048")), prefix="boss")
        old = None
    else:
        bpy.ops.wm.open_mainfile(filepath=os.path.join(ROOT, "art", "blender", "boss_thornwarden.blend"))
        body = bpy.data.objects["body"]
        old = body.parent
    bpy.context.scene.render.fps = FPS
    body.parent = None
    arm = build_armature()
    skin(body, arm)
    if old is not None:
        bpy.data.objects.remove(old)
    poser = Poser(arm)
    only = arg("--only").split(",") if arg("--only") else None
    made = key_clips(arm, poser, only)
    if arg("--preview"):
        preview(arm, body, made, arg("--preview"))
    if "--no-export" not in ARGS:
        export(arm, body)
    # stride lengths for clip_rig.gd: the ground a planted foot covers in one cycle
    print("STRIDE walk %.3f run %.3f" % (2 * WALK_HALF / WALK_DUTY, 2 * RUN_HALF / RUN_DUTY))


main()
