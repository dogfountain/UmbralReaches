"""Skeletons and authored motion for the robed bosses (the Bone Abbot first).

Their bodies are built and baked by boss_<name>.py as one skinned mesh on a flat armature (a bone per rig socket,
posed by formula in the game). This script takes that body, gives it a real skeleton (spine, neck, head, arms with
hands, legs solved by IK from foot controls, and a ring of two-segment skirt bones so the robes swing and settle
instead of standing as a column), keys the clips and exports art/models/boss_<name>.glb with the animations in it.
core/enemy/clip_rig.gd plays them.

    tools/blender/run.sh boss_humanoid_anim.py -- --boss bone_abbot [--preview <dir>] [--no-export] [--only walk,strike]

The first run keeps the socket-rigged body as art/blender/boss_<name>_body.glb and always builds from that copy.
Rig space is the game's: x right, y up, z back, facing -Z, metres at scale 1. Angles are radians about rig axes:
pitch about +X, yaw about +Y, roll about +Z. For a limb hanging down, +pitch swings it forward and +roll swings it
toward +X (the right arm out, the left arm in).
"""
import bpy
import math
import os
import shutil
import sys
import numpy as np
from mathutils import Matrix, Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
FPS = 30
TAU = math.tau


def arg(name, default=None):
    return ARGS[ARGS.index(name) + 1] if name in ARGS else default


BOSS = arg("--boss", "bone_abbot")


def bl(p):
    return Vector((p[0], -p[2], p[1]))


def V(x, y, z):
    return np.array([x, y, z], dtype=np.float64)


# --- the skeleton ---------------------------------------------------------------------------------------
SKIRT_N = 8                       # chains round the waist
SKIRT_TOP, SKIRT_MID, SKIRT_HEM = 0.9, 0.46, 0.02


def skirt_r(y, th):
    """Radius of the robe at height y in direction th (0 = front, the cope stands wider at the sides and back)."""
    wide = 1.0 + 0.25 * abs(math.sin(th)) + 0.15 * max(0.0, -math.cos(th))
    return (0.17 + (SKIRT_TOP - y) * 0.46) * wide


def skirt_pt(i, y):
    th = TAU * i / SKIRT_N
    r = skirt_r(y, th)
    return V(math.sin(th) * r, y, -math.cos(th) * r)


BONES = {
    "root": (V(0, 0, 0), V(0, 0, -0.2), None, False),
    "hips": (V(0, 0.94, 0), V(0, 1.10, 0), "root", True),
    "spine": (V(0, 1.10, 0), V(0, 1.28, 0), "hips", True),
    "chest": (V(0, 1.28, 0), V(0, 1.52, 0), "spine", True),
    "neck": (V(0, 1.52, 0), V(0, 1.64, 0), "chest", True),
    "head": (V(0, 1.64, 0), V(0, 1.92, 0), "neck", True),
}
for tag, sx in (("l", -1), ("r", 1)):
    BONES["upper_" + tag] = (V(sx * 0.24, 1.40, 0), V(sx * 0.24, 1.08, 0), "chest", True)
    BONES["fore_" + tag] = (V(sx * 0.24, 1.08, 0), V(sx * 0.24, 0.78, 0), "upper_" + tag, True)
    BONES["hand_" + tag] = (V(sx * 0.24, 0.78, 0), V(sx * 0.24, 0.62, 0), "fore_" + tag, True)
    BONES["thigh_" + tag] = (V(sx * 0.11, 0.75, 0), V(sx * 0.11, 0.33, -0.02), "hips", True)
    BONES["shin_" + tag] = (V(sx * 0.11, 0.33, -0.02), V(sx * 0.11, -0.09, 0), "thigh_" + tag, True)
    BONES["foot_" + tag] = (V(sx * 0.11, -0.09, 0), V(sx * 0.11, -0.09, -0.16), "shin_" + tag, True)
    BONES["ik_" + tag] = (V(sx * 0.11, -0.09, 0), V(sx * 0.11, -0.09, -0.12), "root", False)
for i in range(SKIRT_N):
    BONES["skirt%d_a" % i] = (skirt_pt(i, SKIRT_TOP), skirt_pt(i, SKIRT_MID), "hips", True)
    BONES["skirt%d_b" % i] = (skirt_pt(i, SKIRT_MID), skirt_pt(i, SKIRT_HEM), "skirt%d_a" % i, True)
DEFORM = [k for k, v in BONES.items() if v[3]]
# the game's socket name for each old bone, and the new bones its vertices may follow
REGION = {
    "pelvis": None, "chest": ["spine", "chest"], "head": ["neck", "head"],
    "shoulder_l": ["upper_l"], "elbow_l": ["fore_l"], "hand_l": ["hand_l"],
    "shoulder_r": ["upper_r"], "elbow_r": ["fore_r"], "hand_r": ["hand_r"],
    "hip_l": ["thigh_l"], "knee_l": ["shin_l"], "foot_l": ["foot_l"],
    "hip_r": ["thigh_r"], "knee_r": ["shin_r"], "foot_r": ["foot_r"],
}


def build_armature():
    arm_data = bpy.data.armatures.new("BossRig")
    arm = bpy.data.objects.new("BossRig", arm_data)
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
    for tag in ("l", "r"):
        ik = arm.pose.bones["shin_" + tag].constraints.new('IK')
        ik.target = arm
        ik.subtarget = "ik_" + tag
        ik.chain_count = 2
    bpy.ops.object.mode_set(mode='OBJECT')
    return arm


def seg_dist(P, a, b):
    ab = b - a
    t = np.clip(((P - a) @ ab) / max(float(ab @ ab), 1e-9), 0.0, 1.0)
    return np.sqrt(((P - (a + t[:, None] * ab)) ** 2).sum(1))


def soft_pick(P, names, band):
    D = np.stack([seg_dist(P, BONES[n][0], BONES[n][1]) for n in names], 1)
    w = np.clip(1.0 - (D - D.min(1, keepdims=True)) / band, 0.0, 1.0) ** 2
    return w / w.sum(1, keepdims=True)


def skin(body, arm):
    me = body.data
    n = len(me.vertices)
    co = np.empty(n * 3)
    me.vertices.foreach_get('co', co)
    co = co.reshape(-1, 3)
    M = np.array(body.matrix_world)
    co = co @ M[:3, :3].T + M[:3, 3]
    P = np.stack([co[:, 0], co[:, 2], -co[:, 1]], 1)
    old = {g.index: g.name for g in body.vertex_groups}
    label = np.array(["chest"] * n, dtype=object)
    best = np.zeros(n)
    for v in me.vertices:
        for g in v.groups:
            if g.weight > best[v.index]:
                best[v.index] = g.weight
                label[v.index] = old[g.group]
    idx = {nm: i for i, nm in enumerate(DEFORM)}
    W = np.zeros((n, len(DEFORM)))
    for reg, names in REGION.items():
        m = label == reg
        if names is None or not m.any():
            continue
        w = soft_pick(P[m], names, 0.12)
        for j, nm in enumerate(names):
            W[m, idx[nm]] = w[:, j]
    # the robes: everything the old pelvis carried. Above the waist it is the hips'; below, each vertex follows the
    # two skirt chains it hangs between, the upper segment down to mid-height and the lower one to the hem.
    m = label == "pelvis"
    Pm = P[m]
    th = np.arctan2(Pm[:, 0], -Pm[:, 2]) % TAU
    f = th / (TAU / SKIRT_N)
    i0 = np.floor(f).astype(int) % SKIRT_N
    i1 = (i0 + 1) % SKIRT_N
    a = f - np.floor(f)
    a = a * a * (3.0 - 2.0 * a)
    y = Pm[:, 1]
    hip_w = np.clip((y - (SKIRT_TOP - 0.1)) / 0.2, 0.0, 1.0)
    low_w = np.clip((SKIRT_MID + 0.12 - y) / 0.24, 0.0, 1.0)
    rows = np.nonzero(m)[0]
    W[rows, idx["hips"]] = hip_w
    for k in range(SKIRT_N):
        for sel, wa in ((i0 == k, 1.0 - a), (i1 == k, a)):
            if sel.any():
                W[rows[sel], idx["skirt%d_a" % k]] += ((1.0 - hip_w) * (1.0 - low_w) * wa)[sel]
                W[rows[sel], idx["skirt%d_b" % k]] += ((1.0 - hip_w) * low_w * wa)[sel]
    e = np.empty(len(me.edges) * 2, dtype=np.int32)
    me.edges.foreach_get('vertices', e)
    e = e.reshape(-1, 2)
    cnt = np.maximum(np.bincount(e.ravel(), minlength=n), 1).astype(np.float64)
    for _ in range(5):
        s = np.zeros_like(W)
        for k in range(W.shape[1]):
            s[:, k] = np.bincount(e[:, 0], weights=W[e[:, 1], k], minlength=n) + np.bincount(e[:, 1], weights=W[e[:, 0], k], minlength=n)
        W = 0.5 * W + 0.5 * s / cnt[:, None]
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
    for md in list(body.modifiers):
        body.modifiers.remove(md)
    body.parent = arm
    body.matrix_parent_inverse = Matrix.Identity(4)
    md = body.modifiers.new("Armature", 'ARMATURE')
    md.object = arm
    print("SKIN", n, "verts,", int(m.sum()), "robe")


# --- posing ---------------------------------------------------------------------------------------------

def rig_rot(pitch=0.0, yaw=0.0, roll=0.0):
    return Matrix.Rotation(yaw, 3, 'Z') @ Matrix.Rotation(pitch, 3, 'X') @ Matrix.Rotation(-roll, 3, 'Y')


class Poser:
    def __init__(self, arm):
        self.arm = arm
        self.rest = {b.name: b.bone.matrix_local.to_3x3() for b in arm.pose.bones}

    def set(self, frame, pose):
        for pb in self.arm.pose.bones:
            name = pb.name
            B = self.rest[name]
            if name.startswith("ik_"):
                off = pose.get(name, (0.0, 0.0, 0.0))
                pb.location = B.inverted() @ bl(off)
                pb.keyframe_insert("location", frame=frame)
                continue
            if name == "root" or name.startswith(("thigh_", "shin_")):
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
    out = {}
    for k in set(p) | set(q):
        a = p.get(k) or (0.0, 0.0, 0.0)
        b = q.get(k) or (0.0, 0.0, 0.0)
        out[k] = tuple(lerp(a[i], b[i], t) for i in range(3))
    return out


def add(p, q):
    out = dict(p)
    for k, v in q.items():
        a = out.get(k, (0.0, 0.0, 0.0))
        out[k] = tuple(a[i] + v[i] for i in range(3))
    return out


def breath(t, rate=1.0):
    return 0.5 - 0.5 * math.cos(TAU * rate * t)


# --- the Bone Abbot: a tall dead priest who carries his crozier upright in the right hand and a lit reliquary
# under his ribs. He does not hurry; when he strikes, the whole height of him comes down behind the staff. -----

def staff_arm(lift=0.0, out=0.0, tilt=0.0):
    """The right arm carrying the crozier: `lift` raises the hand in front, and the hand is turned back so the
    staff stays near upright (plus `tilt`, forward)."""
    up, el = 0.42 + lift, 0.5 + 0.35 * lift
    return {"upper_r": (up, 0, 0.12 + out), "fore_r": (el, 0, 0), "hand_r": (-(up + el) + tilt, 0, -(0.12 + out))}


def stance(b=0.0, sway=0.0):
    """Standing: the weight a little back, the left hand held at the reliquary, the crozier upright."""
    p = {"hips_at": (0.02 * sway, -0.02 - 0.008 * b, 0.0), "hips": (0.02, 0.0, 0.02 * sway), "spine": (0.03 + 0.012 * b, 0, -0.012 * sway),
         "chest": (-0.06 + 0.02 * b, 0, -0.012 * sway), "neck": (-0.08, 0, 0), "head": (-0.06, 0, 0),
         "upper_l": (0.5, 0, -0.1), "fore_l": (1.1, 0, 0), "hand_l": (0.2, 0, 0.3)}
    p.update(staff_arm(0.02 * b))
    return p


def idle(u):
    b = breath(u, 2.0)
    sway = math.sin(TAU * u)
    look = math.sin(TAU * u + 0.8) * 0.6 + math.sin(TAU * 2 * u) * 0.25
    p = stance(b, sway)
    p["neck"] = (-0.08, 0.1 * look, 0.02 * look)
    p["head"] = (-0.06 + 0.03 * math.sin(TAU * 2 * u + 1.0), 0.16 * look, -0.05 * look)
    # the count: his left hand lifts from the reliquary and a finger marks one, twice in the loop
    k = sm(0.3, 0.38, u) * (1.0 - sm(0.5, 0.58, u))
    tick = math.sin(sm(0.36, 0.5, u) * math.pi * 2.0) * 0.12
    p["upper_l"] = (0.5 + 0.25 * k, 0, -0.1 - 0.1 * k)
    p["fore_l"] = (1.1 + 0.25 * k + tick * k, 0, 0)
    p["hand_l"] = (0.2 - 0.3 * k + tick * k, 0, 0.3)
    return p


def step_feet(u, half, lift, duty=0.62):
    out = {}
    for tag, ph in (("l", 0.0), ("r", 0.5)):
        s = (u - ph) % 1.0
        if s < duty:
            z = lerp(-half, half, s / duty)
            y = 0.0
        else:
            k = (s - duty) / (1.0 - duty)
            e = k * k * (3.0 - 2.0 * k)
            z = lerp(half, -half, e)
            y = lift * math.sin(math.pi * k)
        out["ik_" + tag] = (0.0, y, z)
    return out


WALK_HALF, WALK_DUTY = 0.2, 0.62


def walk(u):
    """A procession, not a march: he drops onto each foot, the staff is carried forward and set down on the left
    foot's fall, and the head stays level over it all."""
    a = TAU * u
    p = stance(0.5, 0.0)
    p.update(step_feet(u, WALK_HALF, 0.07, WALK_DUTY))
    p["hips_at"] = (0.03 * math.sin(a - 0.5), -0.035 - 0.022 * math.cos(2 * a + 0.2), 0.0)
    p["hips"] = (0.03 + 0.012 * math.sin(2 * a), 0.07 * math.sin(a), 0.04 * math.sin(a - 0.5))
    p["spine"] = (0.03, -0.05 * math.sin(a), -0.025 * math.sin(a - 0.5))
    p["chest"] = (-0.06 + 0.015 * math.sin(2 * a + 1.2), -0.05 * math.sin(a), -0.02 * math.sin(a - 0.5))
    p["neck"] = (-0.07 + 0.012 * math.sin(2 * a + 2.0), 0.03 * math.sin(a), 0.0)
    p["head"] = (-0.05 + 0.02 * math.sin(2 * a + 2.6), 0.0, 0.0)
    plant = 0.5 - 0.5 * math.cos(a + 0.9)                 # 0 planted beside him, 1 swung forward
    p.update(staff_arm(0.16 * plant, 0.0, 0.1 * (plant - 0.5)))
    p["upper_l"] = (0.5 - 0.06 * math.sin(a), 0, -0.1)
    return p


def raised(k=1.0, tr=0.0):
    """The tell: he draws up to his whole height, the crozier hauled high and back in both hands."""
    p = {"hips_at": (0.0, 0.01 * k, 0.06 * k), "hips": (0.1 * k, 0, 0), "spine": (0.12 * k, 0, 0.01 * tr), "chest": (0.16 * k, 0, -0.01 * tr),
         "neck": (-0.05 * k, 0, 0), "head": (-0.16 * k, 0, 0),
         "upper_r": (2.55 * k + 0.02 * tr, 0, 0.18), "fore_r": (0.55 * k, 0, 0), "hand_r": (-0.5 * k + 0.02 * tr, 0, -0.1),
         "upper_l": (2.3 * k, 0, 0.35 * k), "fore_l": (0.8 * k, 0, 0), "hand_l": (-0.3 * k, 0, 0),
         "ik_r": (0.0, 0.0, 0.1 * k)}
    return p


def windup(u):
    k = 1.0 - (1.0 - sm(0.0, 1.0, u)) ** 2
    dip = math.sin(sm(0.0, 0.3, u) * math.pi) * 0.06
    p = mix(stance(), raised(1.0), k)
    p["hips_at"] = (0.0, p["hips_at"][1] - dip, p["hips_at"][2])
    p["chest"] = (p["chest"][0] - 2.0 * dip, 0, 0)
    return p


def windup_hold(u):
    tr = math.sin(TAU * 6 * u) * 0.7 + math.sin(TAU * 9 * u + 1.1) * 0.3
    return raised(1.0 + 0.04 * breath(u), tr)


DOWN = {"hips_at": (0.0, -0.2, -0.16), "hips": (-0.32, 0, 0), "spine": (-0.3, 0, 0), "chest": (-0.32, 0, 0), "neck": (0.2, 0, 0), "head": (0.22, 0, 0),
        "upper_r": (1.05, 0, 0.1), "fore_r": (0.2, 0, 0), "hand_r": (0.1, 0, 0), "upper_l": (0.9, 0, 0.22), "fore_l": (0.55, 0, 0), "hand_l": (0.0, 0, 0),
        "ik_r": (0.0, 0.0, -0.3), "ik_l": (0.0, 0.0, 0.1)}


def strike(u):
    if u < 0.13:                                          # the blow
        k = (u / 0.13) ** 2
        p = mix(raised(1.0), DOWN, k)
        p["ik_r"] = (0.0, 0.1 * math.sin(k * math.pi), lerp(0.1, -0.3, k))
        return p
    if u < 0.42:                                          # it rings up the staff and through his bones
        k = (u - 0.13) / 0.29
        j = math.exp(-5.0 * k) * math.sin(TAU * 2.6 * k)
        p = dict(DOWN)
        p["hips_at"] = (0.0, -0.2 - 0.04 * j, -0.16)
        p["chest"] = (-0.32 + 0.06 * j, 0, 0)
        p["head"] = (0.22 - 0.16 * j, 0, 0.05 * j)
        p["fore_r"] = (0.2 + 0.12 * j, 0, 0)
        return p
    k = sm(0.42, 1.0, u)
    late = sm(0.6, 1.0, u)
    p = mix(DOWN, stance(), k)
    for b in ("neck", "head", "upper_r", "fore_r", "hand_r"):   # the staff is hauled upright last
        p[b] = tuple(lerp(DOWN.get(b, (0, 0, 0))[i], stance()[b][i], late) for i in range(3))
    s = sm(0.5, 0.75, u)
    p["ik_r"] = (0.0, 0.07 * math.sin(s * math.pi), -0.3 * (1.0 - s))
    p["ik_l"] = (0.0, 0.0, 0.1 * (1.0 - sm(0.7, 0.9, u)))
    return p


def stagger(u):
    """The count is broken: thrown back off the blow, he folds forward over the staff, head hanging, and rights
    himself a joint at a time."""
    hit = math.exp(-5.0 * u)
    fold = sm(0.1, 0.3, u) * (1.0 - sm(0.66, 0.96, u))
    loll = math.sin(TAU * 1.6 * u + 0.5) * fold
    p = {"hips_at": (0.05 * loll, -0.16 * fold, 0.14 * hit + 0.04 * fold), "hips": (0.25 * hit - 0.2 * fold, 0.0, 0.05 * loll),
         "spine": (0.3 * hit - 0.25 * fold, 0, 0.06 * loll), "chest": (0.3 * hit - 0.3 * fold, 0.1 * loll, 0.08 * loll),
         "neck": (-0.3 * hit + 0.3 * fold, 0.15 * loll, 0), "head": (-0.4 * hit + 0.45 * fold, 0.2 * loll, 0.25 * loll),
         "upper_r": (0.9 * fold - 0.5 * hit, 0, 0.25 * hit + 0.1), "fore_r": (0.5 * fold + 0.3, 0, 0), "hand_r": (-0.6 * fold, 0, 0),
         "upper_l": (0.2 * fold - 0.7 * hit, 0, -0.9 * hit - 0.15 * fold), "fore_l": (0.4 + 0.3 * fold, 0, 0),
         "ik_l": (0.0, 0.06 * math.sin(sm(0.02, 0.2, u) * math.pi), 0.2 * sm(0.02, 0.2, u) * (1.0 - sm(0.75, 0.95, u))),
         "ik_r": (0.05 * fold, 0.0, 0.05 * fold)}
    return mix(p, stance(), sm(0.82, 1.0, u))


def howl(u):
    """A rite: the arms open wide and the skull goes back, the crozier lifted from the ground."""
    up = sm(0.0, 0.28, u) * (1.0 - sm(0.78, 1.0, u))
    q = math.sin(TAU * 7 * u) * sm(0.28, 0.38, u) * (1.0 - sm(0.68, 0.78, u))
    p = {"hips_at": (0.0, 0.015 * up, 0.03 * up), "hips": (0.06 * up, 0, 0), "spine": (0.1 * up, 0, 0), "chest": (0.16 * up + 0.01 * q, 0, 0),
         "neck": (0.2 * up, 0, 0), "head": (0.42 * up + 0.02 * q, 0, 0.02 * q),
         "upper_r": (0.5 + 0.5 * up, 0, 0.12 + 1.0 * up), "fore_r": (0.5 - 0.2 * up, 0, 0), "hand_r": (-0.9 - 0.2 * up + 0.02 * q, 0, -0.8 * up),
         "upper_l": (0.5 + 0.4 * up, 0, -0.1 - 1.05 * up), "fore_l": (1.1 - 0.8 * up, 0, 0), "hand_l": (0.2 - 0.5 * up + 0.03 * q, 0, 0.3)}
    return mix(p, stance(), sm(0.9, 1.0, u))


def death(u):
    """He comes down the way a tall thing does: the knees, a long moment kneeling on the staff, then forward."""
    heave = math.sin(sm(0.0, 0.16, u) * math.pi)
    kneel = sm(0.12, 0.34, u)
    hang = sm(0.3, 0.5, u)
    over = sm(0.5, 0.76, u)
    thud = (math.exp(-7.0 * (u - 0.76)) * math.sin(TAU * 4.0 * (u - 0.76))) if u > 0.76 else 0.0
    p = {"hips_at": (0.0, -0.52 * kneel - 0.2 * over + 0.02 * heave, -0.1 * kneel - 0.35 * over),
         "hips": (0.14 * heave - 0.1 * hang - 1.15 * over, 0.0, 0.05 * hang),
         "spine": (0.16 * heave - 0.18 * hang - 0.08 * over, 0, 0.04 * hang), "chest": (0.18 * heave - 0.25 * hang + 0.02 * thud, 0, 0.05 * hang),
         "neck": (-0.2 * heave + 0.3 * hang - 0.3 * over, 0.2 * over, 0), "head": (-0.3 * heave + 0.5 * hang - 0.4 * over + 0.1 * thud, 0.35 * over, 0.3 * over),
         "upper_r": (0.42 + 0.5 * kneel - 0.5 * over, 0, 0.12 + 0.3 * over), "fore_r": (0.5 + 0.3 * kneel - 0.6 * over, 0, 0), "hand_r": (-0.9 * (1.0 - over), 0, 0),
         "upper_l": (0.5 - 0.3 * hang + 0.9 * over, 0, -0.1 - 0.4 * over), "fore_l": (1.1 - 0.8 * hang, 0, 0),
         "ik_l": (-0.02, 0.0, 0.34 * kneel), "ik_r": (0.03, 0.0, 0.28 * kneel)}
    return p


CLIPS = {
    "idle": (idle, 6.0, True, 0.0), "walk": (walk, 1.7, True, 2 * WALK_HALF / WALK_DUTY / 1.7),
    "windup": (windup, 0.7, False, 0.0), "windup_hold": (windup_hold, 1.0, True, 0.0), "strike": (strike, 1.3, False, 0.0),
    "stagger": (stagger, 1.8, False, 0.0), "howl": (howl, 2.4, False, 0.0), "death": (death, 3.0, False, 0.0),
}


# --- the robes: a pendulum per skirt chain, driven by how the hips move ---------------------------------

def skirt_sim(fn, n, loops, fwd_speed):
    """Poses for frames 0..n with the skirt bones added. Each chain hangs from the hips: when the hips tilt it
    stays hanging, when they move it trails, and it rings on a little after they stop."""
    dt = 1.0 / FPS
    base = [fn(f / n) for f in range(n + 1)]

    def hips(f):
        p = base[f % n if loops else min(max(f, 0), n)]
        return np.array(p.get("hips_at", (0, 0, 0))), np.array(p.get("hips", (0, 0, 0)))

    out = [dict(p) for p in base]
    passes = 3 if loops else 1
    st = {i: [np.zeros(2), np.zeros(2), np.zeros(2), np.zeros(2)] for i in range(SKIRT_N)}     # a ang, a vel, b ang, b vel
    for ps in range(passes):
        for f in range(n + 1):
            at, rot = hips(f)
            at0, _ = hips(f - 1)
            vel = (at - at0) / dt
            if f == 0 and not loops:
                vel = np.zeros(3)
            ground = min(max((0.94 + at[1] - 0.3) / 0.4, 0.0), 1.0)        # near the ground the cloth lies, it does not hang
            # the angle that keeps the chain hanging (pitch, roll), plus the trail from travel and from being carried
            want = np.array([-rot[0], -rot[2]]) * 0.85 * ground + np.array([-(vel[2] - fwd_speed) * 0.16, vel[0] * 0.16])
            for i in range(SKIRT_N):
                a, av, b, bv = st[i]
                th = TAU * i / SKIRT_N
                flare = max(-vel[1], 0.0) * 0.1                                      # a drop throws the hem out
                rad = np.array([math.cos(th), math.sin(th)]) * flare               # outward, as (pitch, roll)
                for (ang, v, k, c, tgt) in ((a, av, 70.0, 7.0, want + rad), (b, bv, 45.0, 5.0, 0.8 * (a - want) + 0.6 * rad)):
                    acc = (tgt - ang) * k - v * c
                    v += acc * dt
                    ang += v * dt
                    np.clip(ang, -0.9, 0.9, out=ang)
                if ps == passes - 1:
                    out[f]["skirt%d_a" % i] = (float(a[0]), 0.0, float(a[1]))
                    out[f]["skirt%d_b" % i] = (float(b[0]), 0.0, float(b[1]))
    return out


def key_clips(arm, poser, only=None):
    arm.animation_data_create()
    made = {}
    for name, (fn, secs, loops, speed) in CLIPS.items():
        if only and name not in only:
            continue
        act = bpy.data.actions.new(name)
        arm.animation_data.action = act
        n = max(2, round(secs * FPS))
        for f, pose in enumerate(skirt_sim(fn, n, loops, speed)):
            poser.set(f, pose)
        act.use_fake_user = True
        act.frame_range = (0, n)
        made[name] = (act, n)
    arm.animation_data.action = None
    for name, (act, n) in made.items():
        tr = arm.animation_data.nla_tracks.new()
        tr.name = name
        tr.strips.new(name, 0, act).name = name
        tr.mute = True
    return made


def show(arm, name, frame):
    for tr in arm.animation_data.nla_tracks:
        tr.mute = tr.name != name
        tr.is_solo = tr.name == name
    bpy.context.scene.frame_set(frame)


def preview(arm, meshes, made, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_WORKBENCH'
    sc.display.shading.light = 'STUDIO'
    sc.display.shading.color_type = 'SINGLE'
    sc.display.shading.single_color = (0.62, 0.56, 0.48)
    sc.display.shading.show_cavity = True
    sc.display.shading.show_shadows = True
    sc.render.resolution_x, sc.render.resolution_y = 420, 560
    cam_d = bpy.data.cameras.new("PCam")
    cam_d.lens = 60
    cam = bpy.data.objects.new("PCam", cam_d)
    sc.collection.objects.link(cam)
    sc.camera = cam
    bpy.ops.mesh.primitive_plane_add(size=14, location=(0, 0, 0))
    for name, (act, n) in made.items():
        for view, pos in (("side", V(-6.4, 1.3, 0.0)), ("q34", V(-4.4, 1.7, -4.6))):
            cam.location = bl(pos)
            cam.rotation_euler = (bl(V(0, 1.15, 0.0)) - cam.location).to_track_quat('-Z', 'Y').to_euler()
            cols = 8
            paths = []
            for i in range(cols):
                show(arm, name, round(i * n / (cols if CLIPS[name][2] else cols - 1)))
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


def main():
    model = os.path.join(ROOT, "art", "models", "boss_%s.glb" % BOSS)
    src = os.path.join(ROOT, "art", "blender", "boss_%s_body.glb" % BOSS)
    if not os.path.exists(src):
        shutil.copyfile(model, src)                       # the socket-rigged body, kept as this script's source
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=src)
    bpy.context.scene.render.fps = FPS
    old = [o for o in bpy.data.objects if o.type == 'ARMATURE'][0]
    sockets = {b.name: np.array([(old.matrix_world @ b.head_local).x, (old.matrix_world @ b.head_local).z, -(old.matrix_world @ b.head_local).y]) for b in old.data.bones}
    body = bpy.data.objects["body"]
    held = [o for o in bpy.data.objects if o.type == 'MESH' and o is not body and "_" in o.name and o.name.split("_", 1)[1] in sockets]
    for o in [o for o in bpy.data.objects if o.type == 'MESH' and o is not body and o not in held]:
        bpy.data.objects.remove(o)
    bpy.ops.object.select_all(action='DESELECT')
    body.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.parent_clear(type='CLEAR_KEEP_TRANSFORM')
    arm = build_armature()
    skin(body, arm)
    # things carried: a mesh whose origin is the old socket's joint follows the bone that replaced it
    bone_of = {"hand_r": "hand_r", "hand_l": "hand_l", "chest": "chest", "head": "head", "pelvis": "hips"}
    for o in held:
        sock = o.name.split("_", 1)[1]
        o.parent = arm
        o.parent_type = 'BONE'
        o.parent_bone = bone_of.get(sock, "chest")
        o.matrix_world = Matrix.Translation(bl(sockets[sock]))
        print("HELD", o.name, "->", o.parent_bone)
    bpy.data.objects.remove(old)
    poser = Poser(arm)
    made = key_clips(arm, poser, arg("--only").split(",") if arg("--only") else None)
    if arg("--preview"):
        preview(arm, [body] + held, made, arg("--preview"))
    if "--no-export" not in ARGS:
        bpy.ops.object.select_all(action='DESELECT')
        for o in [arm, body] + held:
            o.select_set(True)
        bpy.context.view_layer.objects.active = arm
        for tr in arm.animation_data.nla_tracks:
            tr.mute = False
            tr.is_solo = False
        bpy.ops.export_scene.gltf(filepath=model, export_format='GLB', use_selection=True, export_apply=False, export_yup=True,
                                  export_materials='NONE', export_normals=True, export_tangents=True, export_texcoords=True,
                                  export_skins=True, export_def_bones=True, export_animations=True,
                                  export_animation_mode='NLA_TRACKS', export_force_sampling=True, export_frame_step=1,
                                  export_all_influences=False, export_optimize_animation_size=False)
        print("EXPORTED", model)
    print("STRIDE walk %.3f" % (2 * WALK_HALF / WALK_DUTY))


main()
