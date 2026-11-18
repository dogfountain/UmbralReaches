"""Shared kit for the bosses modelled in Blender in the villagers' style (Luke, 18 Nov: every model in the game is
authored in Blender; the bosses keep the villagers' look). A boss script (vb_<name>.py) builds its body from the
parts here, gives it a skeleton, keys its clips and exports one GLB.

The mesh carries what the villagers' shader reads (core/npc/dwarf.gdshader), so in game the boss is painted exactly
like Hearthward's people (DwarfLook.material_boss):
  COLOR_0      rgb: the part's tint (sRGB); a: baked ambient occlusion (1 open, 0 deep crevice)
  TEXCOORD_0   metres round / along the part (the detail maps tile in metres)
  TEXCOORD_1   x: the material layer (LAYER below), y unused
Glowing parts (eyes, the heart, flames) go on a second material, "glow", rendered emissive.

Rig space (as the game's rigs): x right, y up, z back, the body facing -Z, metres, feet on y = 0.
Blender space is converted with bl() (x, -z, y), so a GLB exported +Y up faces -Z in Godot.

Clips are AUTHORED: key poses at chosen times with Bezier easing (anticipation, overshoot, settle drawn by the key
times), set as rotations about the ARMATURE's axes (rot_world), not by formula. The cloth chains (robe, mantle,
cord) are given follow-through after the keys: each link lags the body's motion by a delay that grows down the
chain, plus a slow ripple, sampled per frame.
"""
import bpy
import bmesh
import math
import os
import numpy as np
from mathutils import Vector, Matrix, Quaternion, Euler

TAU = math.tau
FPS = 30
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
LAYER = {"skin": 0, "cloth": 1, "linen": 2, "leather": 3, "hair": 4, "metal": 5, "wood": 6, "foam": 7, "eye": 8, "fur": 9}


def bl(p):
    return Vector((float(p[0]), -float(p[2]), float(p[1])))


def V(x, y, z):
    return np.array([x, y, z], dtype=np.float64)


def srgb(c):
    return tuple(float(x) for x in c)


def smooth(a, b, x):
    t = min(1.0, max(0.0, (x - a) / (b - a))) if b != a else (1.0 if x >= b else 0.0)
    return t * t * (3.0 - 2.0 * t)


# --- geometry -----------------------------------------------------------------------------------------------

class Geo:
    """Vertices (rig space), quads/tris, and per-vertex tint, layer, uv, glow flag and bone weights, gathered part
    by part and made one skinned mesh."""

    def __init__(self):
        self.v = []
        self.f = []
        self.col = []
        self.lay = []
        self.uv = []
        self.glow = []
        self.w = []        # list of {bone: weight}

    def add(self, verts, faces, col, layer, uvs, weights, glow=False):
        base = len(self.v)
        n = len(verts)
        self.v.extend([np.asarray(p, dtype=np.float64) for p in verts])
        self.f.extend([[base + i for i in fc] for fc in faces])
        cols = col if (isinstance(col, list) and len(col) == n and isinstance(col[0], (tuple, list, np.ndarray))) else [col] * n
        self.col.extend([srgb(c) for c in cols])
        self.lay.extend([LAYER[layer] if isinstance(layer, str) else int(layer)] * n)
        self.uv.extend(uvs)
        self.glow.extend([glow] * n)
        if callable(weights):
            self.w.extend([weights(np.asarray(p)) for p in verts])
        elif isinstance(weights, list) and len(weights) == n:
            self.w.extend(weights)
        else:
            self.w.extend([{weights: 1.0}] * n)
        return base


def _frame(t, ref=V(0, 0, -1)):
    t = t / (np.linalg.norm(t) + 1e-12)
    r = np.asarray(ref, dtype=np.float64)
    if abs(np.dot(t, r)) > 0.95:
        r = V(1, 0, 0) if abs(t[0]) < 0.9 else V(0, 1, 0)
    a = np.cross(r, t)
    a /= np.linalg.norm(a) + 1e-12
    b = np.cross(t, a)
    return a, b


def lathe(g, prof, segs, col, layer, weights, a0=0.0, a1=TAU, centre=V(0, 0, 0), fold=None, zscale=1.0, cap_top=False,
          cap_bot=False, glow=False, hem=None):
    """A surface of revolution round the y axis through `centre`: prof = [(y, r), ...] bottom to top.
    fold(theta, y, r) -> dr shapes folds; hem(theta) -> dy lifts the bottom ring (a ragged hem); zscale squashes
    front-back. Partial arcs (a0..a1) are open shells. Angle 0 is the front (-Z), increasing toward +X."""
    full = abs((a1 - a0) - TAU) < 1e-6
    n_a = segs if full else segs + 1
    rows = len(prof)
    verts, uvs, cols = [], [], []
    for j, (y, r) in enumerate(prof):
        for i in range(n_a):
            th = a0 + (a1 - a0) * i / segs
            dr = fold(th, y, r) if fold else 0.0
            rr = r + dr
            yy = y + (hem(th) if (hem and j == 0) else 0.0)
            p = centre + V(math.sin(th) * rr, yy, -math.cos(th) * rr * zscale)
            verts.append(p)
            uvs.append((th * max(r, 0.02), yy))
            cols.append(col(th, yy, dr) if callable(col) else col)
    faces = []
    for j in range(rows - 1):
        for i in range(segs):
            i2 = (i + 1) % n_a if full else i + 1
            a = j * n_a + i
            b = j * n_a + i2
            faces.append([a, b, b + n_a, a + n_a])
    if cap_top:
        c = len(verts)
        verts.append(centre + V(0, prof[-1][0], 0))
        uvs.append((0.0, prof[-1][0]))
        cols.append(cols[-1])
        top = (rows - 1) * n_a
        for i in range(segs):
            i2 = (i + 1) % n_a if full else i + 1
            faces.append([top + i, top + i2, c])
    if cap_bot:
        c = len(verts)
        verts.append(centre + V(0, prof[0][0], 0))
        uvs.append((0.0, prof[0][0]))
        cols.append(cols[0])
        for i in range(segs):
            i2 = (i + 1) % n_a if full else i + 1
            faces.append([i2, i, c])
    return g.add(verts, faces, cols, layer, uvs, weights, glow)


def loft(g, rows, segs, col, layer, weights, a0=0.0, a1=TAU, fold=None, hem=None, glow=False, cap_top=False, skip=None):
    """Rings (centre, rx, rz) bottom to top: a body whose middle moves (a hunched torso, a cowl, a mantle). Angle 0
    is the front (-Z). fold(th, k, j) -> dr; hem(th) -> dy on the first ring. col may be callable(th, j, dr, p)."""
    full = abs((a1 - a0) - TAU) < 1e-6
    n_a = segs if full else segs + 1
    verts, uvs, cols = [], [], []
    for j, (c, rx, rz) in enumerate(rows):
        c = np.asarray(c, dtype=np.float64)
        for i in range(n_a):
            th = a0 + (a1 - a0) * i / segs
            dr = fold(th, j, len(rows)) if fold else 0.0
            p = c + V(math.sin(th) * (rx + dr), (hem(th) if (hem and j == 0) else 0.0), -math.cos(th) * (rz + dr))
            verts.append(p)
            uvs.append((th * max(rx, 0.02), float(c[1])))
            cols.append(col(th, j, dr, p) if callable(col) else col)
    faces = []
    for j in range(len(rows) - 1):
        for i in range(segs):
            if skip and skip(a0 + (a1 - a0) * (i + 0.5) / segs, j + 0.5):
                continue                                     # an opening (a face in a hood)
            i2 = (i + 1) % n_a if full else i + 1
            a = j * n_a + i
            b = j * n_a + i2
            faces.append([a, b, b + n_a, a + n_a])
    if cap_top:
        c = len(verts)
        verts.append(np.asarray(rows[-1][0], dtype=np.float64))
        uvs.append((0.0, 0.0))
        cols.append(cols[-1])
        top = (len(rows) - 1) * n_a
        for i in range(segs):
            i2 = (i + 1) % n_a if full else i + 1
            faces.append([top + i, top + i2, c])
    return g.add(verts, faces, cols, layer, uvs, weights, glow)


def tube(g, path, radii, segs, col, layer, weights, squash=(1.0, 1.0), ref=V(0, 0, -1), caps=True, glow=False, twist=0.0):
    """A tube along `path` (rig space), radius per point, cross-section squashed (side, front)."""
    path = [np.asarray(p, dtype=np.float64) for p in path]
    n = len(path)
    verts, uvs = [], []
    along = 0.0
    for k in range(n):
        t = path[min(k + 1, n - 1)] - path[max(k - 1, 0)]
        a, b = _frame(t, ref)
        if k > 0:
            along += float(np.linalg.norm(path[k] - path[k - 1]))
        for i in range(segs):
            th = TAU * i / segs + twist * k
            p = path[k] + a * math.cos(th) * radii[k] * squash[0] + b * math.sin(th) * radii[k] * squash[1]
            verts.append(p)
            uvs.append((th * radii[k], along))
    faces = []
    for k in range(n - 1):
        for i in range(segs):
            a = k * segs + i
            b = k * segs + (i + 1) % segs
            faces.append([a, b, b + segs, a + segs])
    if caps:
        for k, rev in ((0, True), (n - 1, False)):
            c = len(verts)
            verts.append(path[k])
            uvs.append((0.0, 0.0))
            for i in range(segs):
                a = k * segs + i
                b = k * segs + (i + 1) % segs
                faces.append([b, a, c] if rev else [a, b, c])
    return g.add(verts, faces, col, layer, uvs, weights, glow)


def blob(g, c, radii, col, layer, weights, basis=None, rings=8, segs=12, lumps=0.0, seed=1, glow=False, phi=(0.0, 1.0), power=1.0):
    """An ellipsoid (radii x, y, z) at c, optional basis (3x3) and lumpy surface; phi limits latitude (0 top..1 bottom).
    power < 1 squares it off toward a box (0.3: a dressed stone with soft arrises)."""
    rng = np.random.default_rng(seed)
    bump = rng.uniform(-1, 1, (rings + 1, segs)) * lumps
    B = np.eye(3) if basis is None else np.asarray(basis, dtype=np.float64)
    verts, uvs = [], []
    for j in range(rings + 1):
        la = math.pi * (phi[0] + (phi[1] - phi[0]) * j / rings)
        for i in range(segs):
            lo = TAU * i / segs
            d = V(math.sin(la) * math.sin(lo), math.cos(la), -math.sin(la) * math.cos(lo))
            if power != 1.0:
                d = np.sign(d) * np.abs(d) ** power
            s = 1.0 + bump[j, i] * math.sin(la)
            p = c + B @ (d * np.asarray(radii) * s)
            verts.append(p)
            uvs.append((lo * max(radii), la * max(radii)))
    faces = []
    for j in range(rings):
        for i in range(segs):
            a = j * segs + i
            b = j * segs + (i + 1) % segs
            faces.append([a, a + segs, b + segs, b])
    return g.add(verts, faces, col, layer, uvs, weights, glow)


def rot_y(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])


def rot_x(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])


def rot_z(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])


# --- the mesh object ---------------------------------------------------------------------------------------

def make_object(g, name, subdiv=0):
    me = bpy.data.meshes.new(name)
    me.from_pydata([bl(p) for p in g.v], [], g.f)
    me.validate()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    n_loops = len(me.loops)
    lv = np.zeros(n_loops, dtype=np.int64)
    me.loops.foreach_get("vertex_index", lv)
    col = np.array([(c[0], c[1], c[2], 1.0) for c in g.col], dtype=np.float32)
    ca = me.color_attributes.new("Col", 'FLOAT_COLOR', 'CORNER')
    ca.data.foreach_set("color", col[lv].ravel())
    me.color_attributes.active_color = ca
    uv0 = me.uv_layers.new(name="UV")
    uv1 = me.uv_layers.new(name="Layer")
    uvs = np.array(g.uv, dtype=np.float32)
    uv0.data.foreach_set("uv", uvs[lv].ravel())
    lay = np.array([(float(x), 0.0) for x in g.lay], dtype=np.float32)
    uv1.data.foreach_set("uv", lay[lv].ravel())
    # materials: body (0) and glow (1)
    body = bpy.data.materials.get("body") or bpy.data.materials.new("body")
    glow = bpy.data.materials.get("glow") or bpy.data.materials.new("glow")
    _preview_body(body)
    _preview_glow(glow)
    me.materials.append(body)
    me.materials.append(glow)
    gl = np.array(g.glow, dtype=bool)
    mi = np.zeros(len(me.polygons), dtype=np.int32)
    for k, poly in enumerate(me.polygons):
        if gl[poly.vertices[0]]:
            mi[k] = 1
    me.polygons.foreach_set("material_index", mi)
    for poly in me.polygons:
        poly.use_smooth = True
    me.update()
    # vertex groups (weights)
    groups = {}
    for i, wd in enumerate(g.w):
        tot = sum(wd.values()) or 1.0
        for bname, w in wd.items():
            if w <= 1e-4:
                continue
            if bname not in groups:
                groups[bname] = ob.vertex_groups.new(name=bname)
            groups[bname].add([i], w / tot, 'REPLACE')
    if subdiv:
        m = ob.modifiers.new("Subd", 'SUBSURF')
        m.levels = subdiv
        m.render_levels = subdiv
    return ob


def _preview_body(mat):
    """A Principled material reading the vertex tint, for the turnaround renders only (in game the villagers' shader
    replaces it). Roughness high, a touch of sheen."""
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    attr = nt.nodes.new("ShaderNodeVertexColor")
    attr.layer_name = "Col"
    gam = nt.nodes.new("ShaderNodeGamma")
    gam.inputs["Gamma"].default_value = 2.2
    nt.links.new(attr.outputs["Color"], gam.inputs["Color"])
    nt.links.new(gam.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.85
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])


def _preview_glow(mat):
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    attr = nt.nodes.new("ShaderNodeVertexColor")
    attr.layer_name = "Col"
    nt.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(attr.outputs["Color"], bsdf.inputs["Emission Color"])
    bsdf.inputs["Emission Strength"].default_value = 4.0
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])


def bake_ao_alpha(ob, samples=24, dist=0.25):
    """Ambient occlusion into the tint's alpha (the villagers' shader reads COLOR.a as AO): Cycles bake to the colour
    attribute, then the AO's value copied into alpha and the tint restored."""
    me = ob.data
    ca = me.color_attributes["Col"]
    keep = np.zeros(len(ca.data) * 4, dtype=np.float32)
    ca.data.foreach_get("color", keep)
    scn = bpy.context.scene
    scn.render.engine = 'CYCLES'
    scn.cycles.samples = samples
    scn.cycles.device = 'CPU'
    scn.world = scn.world or bpy.data.worlds.new("W")
    scn.world.light_settings.distance = dist
    for o in scn.objects:
        o.select_set(False)
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    scn.render.bake.target = 'VERTEX_COLORS'
    bpy.ops.object.bake(type='AO')
    ao = np.zeros(len(ca.data) * 4, dtype=np.float32)
    ca.data.foreach_get("color", ao)
    keep = keep.reshape(-1, 4)
    ao = ao.reshape(-1, 4)
    keep[:, 3] = np.clip(ao[:, 0], 0.0, 1.0)
    ca.data.foreach_set("color", keep.ravel())


# --- the skeleton ------------------------------------------------------------------------------------------

def build_armature(bones, name="BossRig"):
    """bones: {name: (head, tail, parent, deform)} in rig space."""
    data = bpy.data.armatures.new(name)
    arm = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    for o in bpy.context.scene.objects:
        o.select_set(False)
    arm.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    for nm, (h, t, par, deform) in bones.items():
        b = data.edit_bones.new(nm)
        b.head, b.tail = bl(h), bl(t)
        b.roll = 0.0
        b.use_deform = deform
    for nm, (h, t, par, deform) in bones.items():
        if par:
            data.edit_bones[nm].parent = data.edit_bones[par]
    bpy.ops.object.mode_set(mode='POSE')
    for pb in arm.pose.bones:
        pb.rotation_mode = 'QUATERNION'
    bpy.ops.object.mode_set(mode='OBJECT')
    return arm


def bind(ob, arm):
    ob.parent = arm
    m = ob.modifiers.new("Armature", 'ARMATURE')
    m.object = arm
    # the subdivision (if any) after the armature
    if "Subd" in ob.modifiers:
        bpy.context.view_layer.objects.active = ob
        while ob.modifiers[-1].name != "Subd":
            bpy.ops.object.modifier_move_down(modifier="Subd")


# --- posing ------------------------------------------------------------------------------------------------

def rig_axis(v):
    """A rig-space axis as an armature-space (Blender) vector."""
    return bl(v).normalized()


def rot_world(arm, bone, axis_rig, deg):
    """The pose quaternion that turns `bone` by `deg` about a rig-space axis (as seen in the armature's rest frame,
    i.e. before its parents move). Composing children over parents gives the familiar FK feel."""
    rest = arm.data.bones[bone].matrix_local.to_quaternion()
    qw = Quaternion(rig_axis(axis_rig), math.radians(deg))
    return rest.inverted() @ qw @ rest


def pose_q(arm, pose):
    """pose: {bone: [(axis, deg), ...]} -> {bone: Quaternion}."""
    out = {}
    for b, rots in pose.items():
        q = Quaternion()
        for ax, deg in rots:
            q = rot_world(arm, b, ax, deg) @ q
        out[b] = q
    return out


def blend_pose(a, b, t):
    """Two pose dicts (bone -> [(axis, deg)]) mixed: degrees lerped per (bone, axis)."""
    out = {}
    for bone in set(a) | set(b):
        da = {tuple(ax): d for ax, d in a.get(bone, [])}
        db = {tuple(ax): d for ax, d in b.get(bone, [])}
        out[bone] = [(list(ax), da.get(ax, 0.0) * (1.0 - t) + db.get(ax, 0.0) * t) for ax in set(da) | set(db)]
    return out


def key_clip(arm, name, keys, length, loop=False, chains=None, ripple=0.0, root_keys=None):
    """keys: [(time s, pose dict, [ease])]; each bone gets every key it is named in (missing = rest). chains: list of
    [bone, bone, ...] cloth chains that lag the body (delay per link) and ripple. root_keys: [(t, (x, y, z))] root
    translation in rig space. Pushes an action to an NLA track named `name`."""
    act = bpy.data.actions.new(name)
    arm.animation_data_create()
    arm.animation_data.action = act
    nf = max(2, int(round(length * FPS)))
    # every bone is keyed at every key (missing = rest), so nothing keeps a pose left over from the clip keyed before;
    # the cloth chains that the follow-through drives on its own are left to it
    driven = set()
    for ch in (chains or []):
        if not (isinstance(ch, dict) and ch.get("add")):
            driven |= set(ch["bones"] if isinstance(ch, dict) else ch)
    allb = set(pb.name for pb in arm.pose.bones) - driven
    qkeys = [(t, pose_q(arm, p)) for t, p, *_ in keys]
    # keep each bone's keys on one quaternion hemisphere so the per-channel curves never take the long way round
    for i in range(1, len(qkeys)):
        for b, q in qkeys[i][1].items():
            prev = qkeys[i - 1][1].get(b, Quaternion())
            if prev.dot(q) < 0.0:
                qkeys[i][1][b] = -q
    # main bones: keys at the given times, Bezier-eased
    for b in allb:
        pb = arm.pose.bones[b]
        for t, qd in qkeys:
            pb.rotation_quaternion = qd.get(b, Quaternion())
            pb.keyframe_insert("rotation_quaternion", frame=1 + t * FPS)
    if True:
        pb = arm.pose.bones["root"]
        for t, xyz in (root_keys or [(t, (0.0, 0.0, 0.0)) for t, *_ in keys]):
            pb.location = arm.data.bones["root"].matrix_local.inverted().to_3x3() @ bl(xyz)
            pb.keyframe_insert("location", frame=1 + t * FPS)
    # Blender 5: the action's curves live in a layered action; set every key's interpolation by walking fcurves
    for fc in _fcurves(act):
        for kp in fc.keyframe_points:
            kp.interpolation = 'BEZIER'
            kp.handle_left_type = 'AUTO_CLAMPED'
            kp.handle_right_type = 'AUTO_CLAMPED'
        if loop:
            m = fc.modifiers.new('CYCLES')
    # cloth chains: follow-through, sampled per frame
    if chains:
        _key_chains(arm, act, chains, nf, length, ripple, loop)
    act.use_fake_user = True
    track = arm.animation_data.nla_tracks.new()
    track.name = name
    strip = track.strips.new(name, 1, act)
    strip.name = name
    arm.animation_data.action = None
    return act


def _fcurves(act):
    """Every F-curve of an action (Blender 5 layered actions keep them under layers / strips / channelbags)."""
    out = []
    try:
        for layer in act.layers:
            for strip in layer.strips:
                for cb in strip.channelbags:
                    out.extend(cb.fcurves)
    except AttributeError:
        out = list(act.fcurves)
    return out


def _key_chains(arm, act, chains, nf, length, ripple, loop):
    """Each chain link copies its driver's motion a little late: the driver's world rotation (the pelvis, or the hand
    a chain hangs from), sampled from the evaluated pose `delay` seconds earlier, damped down the chain, plus a slow
    sideways ripple. A chain is a list of bones, or {"bones": [...], "drive": bone, "gain": k, "add": True}: an
    additive chain keeps its own keys (an anchor's chain aimed per pose) and lags on top of them."""
    scn = bpy.context.scene
    arm.animation_data.action = act
    specs = []
    for ch in chains:
        if isinstance(ch, dict):
            specs.append((list(ch["bones"]), ch.get("drive"), float(ch.get("gain", 1.0)), bool(ch.get("add", False)), float(ch.get("ripple", 1.0))))
        else:
            specs.append((list(ch), None, 1.0, False, 1.0))
    default = "pelvis" if "pelvis" in arm.pose.bones else "root"
    drives = sorted(set((d or default) for _, d, *_ in specs))
    adds = sorted(set(b for bones, _, _, add, _ in specs if add for b in bones))
    samples = {d: [] for d in drives}
    base = {b: [] for b in adds}
    for f in range(nf + 1):
        scn.frame_set(1 + f)
        for d in drives:
            samples[d].append(arm.pose.bones[d].matrix.to_quaternion())
        for b in adds:
            base[b].append(arm.pose.bones[b].rotation_quaternion.copy())
    for ci, (bones, drv, gk, add, rk) in enumerate(specs):
        smp = samples[drv or default]
        for li, b in enumerate(bones):
            pb = arm.pose.bones[b]
            delay = 0.12 + 0.1 * li
            gain = (0.55 + 0.25 * li) * gk
            restb = arm.data.bones[b].matrix_local.to_quaternion()
            for f in range(nf + 1):
                t = f / FPS
                tl = t - delay
                if loop:
                    tl = tl % length
                fi = max(0, min(nf, int(round(tl * FPS))))
                fn = max(0, min(nf, int(round(t * FPS))))
                # the driver's turn since then, opposed (the cloth trails it)
                d = smp[fi].inverted() @ smp[fn]
                ang = d.angle if d.angle < math.pi else d.angle - TAU
                ax = d.axis
                lag = Quaternion(ax, -ang * gain) if abs(ang) > 1e-5 else Quaternion()
                ph = TAU * (t / max(length, 0.1)) * (1.0 if loop else 0.5) + ci * 1.7 + li * 0.6
                rip = Quaternion(rig_axis(V(0, 0, 1)), ripple * rk * math.sin(ph) * (0.4 + 0.6 * li))
                q = restb.inverted() @ (lag @ rip) @ restb
                if add:
                    q = q @ base[b][f]
                pb.rotation_quaternion = q
                pb.keyframe_insert("rotation_quaternion", frame=1 + f)
    arm.animation_data.action = None


# --- export and review -------------------------------------------------------------------------------------

def export_glb(arm, ob, path):
    for o in bpy.context.scene.objects:
        o.select_set(False)
    arm.select_set(True)
    ob.select_set(True)
    bpy.context.view_layer.objects.active = arm
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True, export_apply=True, export_yup=True,
                              export_materials='EXPORT', export_vertex_color='ACTIVE',
                              export_active_vertex_color_when_no_material=True, export_normals=True, export_tangents=False,
                              export_texcoords=True, export_skins=True, export_def_bones=True, export_animations=True,
                              export_animation_mode='NLA_TRACKS', export_force_sampling=True, export_frame_step=1,
                              export_all_influences=False, export_optimize_animation_size=False)
    print("VB EXPORTED", path)


def review_renders(arm, ob, out_dir, prefix, height, poses=None, res=(1600, 1000)):
    """Turnaround (front, 3/4, side, back) plus posed frames (clip name, time s) to PNG with EEVEE: a night key light,
    a warm fire from one side and a cool rim, on a dark ground."""
    scn = bpy.context.scene
    scn.render.engine = 'BLENDER_EEVEE'
    scn.render.resolution_x, scn.render.resolution_y = res
    scn.render.film_transparent = False
    w = scn.world or bpy.data.worlds.new("W")
    scn.world = w
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.012, 0.015, 0.03, 1.0)
    w.node_tree.nodes["Background"].inputs[1].default_value = 1.0
    if "Ground" not in bpy.data.objects:
        bpy.ops.mesh.primitive_plane_add(size=40)
        gp = bpy.context.active_object
        gp.name = "Ground"
        gm = bpy.data.materials.new("ground")
        gm.use_nodes = True
        gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.09, 0.09, 0.1, 1)
        gp.data.materials.append(gm)
    def light(nm, typ, loc, energy, col, size=2.0):
        if nm in bpy.data.objects:
            return
        ld = bpy.data.lights.new(nm, typ)
        ld.energy = energy
        ld.color = col
        if typ == 'AREA':
            ld.size = size
        lo = bpy.data.objects.new(nm, ld)
        scn.collection.objects.link(lo)
        lo.location = loc
        lo.rotation_euler = (Vector((0, 0, height * 0.5)) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
    light("Key", 'AREA', (-height * 1.2, height * 1.6, height * 1.4), 60.0 * height * height, (0.75, 0.82, 1.0), height)
    light("Fire", 'AREA', (height * 1.3, height * 0.6, height * 0.4), 40.0 * height * height, (1.0, 0.6, 0.3), height * 0.5)
    light("Rim", 'AREA', (0.0, -height * 1.8, height * 1.2), 70.0 * height * height, (0.6, 0.7, 1.0), height)
    cam_d = bpy.data.cameras.new("Cam")
    cam_d.lens = 50
    cam = bpy.data.objects.new("Cam", cam_d)
    scn.collection.objects.link(cam)
    scn.camera = cam
    os.makedirs(out_dir, exist_ok=True)
    shots = [("front", 0.0), ("q34", 35.0), ("side", 90.0), ("back", 180.0)]
    files = []
    arm.animation_data_create()
    def place(deg, d, hgt, look_h):
        a = math.radians(deg)
        cam.location = (math.sin(a) * d, math.cos(a) * d, hgt)          # rig front (-Z) is Blender +Y
        cam.rotation_euler = (Vector((0, 0, look_h)) - cam.location).to_track_quat('-Z', 'Y').to_euler()
    for nm, deg in shots:
        arm.animation_data.action = bpy.data.actions.get("idle")
        scn.frame_set(1)
        place(deg, height * 2.6, height * 0.62, height * 0.5)
        f = os.path.join(out_dir, "%s_%s.png" % (prefix, nm))
        scn.render.filepath = f
        bpy.ops.render.render(write_still=True)
        files.append(f)
    # close-up of the head and hands
    place(20.0, height * 1.0, height * 0.9, height * 0.82)
    f = os.path.join(out_dir, "%s_head.png" % prefix)
    scn.render.filepath = f
    bpy.ops.render.render(write_still=True)
    files.append(f)
    for clip, t, deg in (poses or []):
        act = bpy.data.actions.get(clip)
        if act is None:
            continue
        arm.animation_data.action = act
        scn.frame_set(1 + int(round(t * FPS)))
        place(deg, height * 3.4, height * 0.72, height * 0.62)       # wider: raised arms and a swung staff stay in frame
        f = os.path.join(out_dir, "%s_%s_%03d.png" % (prefix, clip, int(t * 100)))
        scn.render.filepath = f
        bpy.ops.render.render(write_still=True)
        files.append(f)
    arm.animation_data.action = None
    print("VB RENDERS", " ".join(files))
    return files


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
