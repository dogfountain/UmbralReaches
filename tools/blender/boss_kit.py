"""Shared helpers for the boss models (r30): rig-space placement, meshes, cloth simulation,
procedural PBR materials, atlas baking and per-socket export.

The enemies animate as rigid parts, one per CharacterRig socket (core/player/character_rig.gd).
A boss model is built in the rig's rest pose (arms and legs hanging straight down, facing -Z in
Godot), baked into one texture atlas, then split into one mesh per socket with its origin on that
joint and exported as a GLB. EnemyBody loads it in place of the procedural body.

Coordinates: G(x, y, z) takes a Godot rig-space point to Blender (glTF export with +Y up maps
Blender (x, y, z) to (x, z, -y), so Blender +Y is the body's front, Godot -Z).
"""
import bpy
import bmesh
import math
import os
from mathutils import Vector, Matrix, noise


def G(x, y, z):
    return Vector((x, -z, y))


# rest positions of the sockets (Godot rig space, unscaled: the boss scale is applied in game)
SOCKETS = {
    "pelvis": G(0, 0.94, 0), "chest": G(0, 1.28, 0), "head": G(0, 1.64, 0),
    "hip_l": G(-0.11, 0.75, 0), "knee_l": G(-0.11, 0.33, 0), "foot_l": G(-0.11, -0.09, 0),
    "hip_r": G(0.11, 0.75, 0), "knee_r": G(0.11, 0.33, 0), "foot_r": G(0.11, -0.09, 0),
    "shoulder_l": G(-0.24, 1.40, 0), "elbow_l": G(-0.24, 1.08, 0), "hand_l": G(-0.24, 0.78, 0),
    "shoulder_r": G(0.24, 1.40, 0), "elbow_r": G(0.24, 1.08, 0), "hand_r": G(0.24, 0.78, 0),
}


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.unit_settings.system = 'METRIC'
    sc.render.engine = 'CYCLES'
    # GPU (Metal). Background runs segfaulted in Cycles' kernel compile thread while it serialized a
    # binary archive (MetalKernelPipeline::compile -> airntSerializeToURL, 2026-11-04): run with
    # CYCLES_METAL_DISABLE_BINARY_ARCHIVES=1 (tools/blender/run.sh sets it) and no background kernel
    # specialization. BOSS_BAKE_CPU=1 falls back to the CPU.
    sc.cycles.device = 'CPU'
    if os.environ.get("BOSS_BAKE_CPU", "") != "1":
        try:
            prefs = bpy.context.preferences.addons["cycles"].preferences
            prefs.compute_device_type = 'METAL'
            if hasattr(prefs, "kernel_optimization_level"):
                prefs.kernel_optimization_level = 'OFF'
            if hasattr(prefs, "use_metalrt"):
                prefs.use_metalrt = False
            prefs.get_devices()
            for d in prefs.devices:
                d.use = d.type != 'CPU'
            sc.cycles.device = 'GPU'
            print("CYCLES device GPU:", [d.name for d in prefs.devices if d.use])
        except Exception as e:
            print("CYCLES GPU unavailable, CPU:", e)


def link(obj, sock, mat):
    bpy.context.scene.collection.objects.link(obj)
    obj["sock"] = sock
    if mat is not None:
        obj.data.materials.append(mat.m if hasattr(mat, "m") else mat)
    return obj


def mesh_from_bm(name, bm, sock, mat, smooth=True):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    if smooth:
        for p in me.polygons:
            p.use_smooth = True
    return link(bpy.data.objects.new(name, me), sock, mat)


def frame_from(t):
    t = t.normalized()
    ref = Vector((0, 0, 1)) if abs(t.z) < 0.9 else Vector((0, 1, 0))
    u = t.cross(ref).normalized()
    v = t.cross(u).normalized()
    return u, v


def loft(name, pts, radii, sock, mat, sides=12, squash=(1.0, 1.0), cap0=True, cap1=True, wobble=0.0, seed=0.0):
    """Sweep a ring of `sides` along `pts` (Blender space) with per-point radii (or (rx, ry))."""
    bm = bmesh.new()
    rings = []
    n = len(pts)
    u_prev = None
    for i, p in enumerate(pts):
        t = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()
        if u_prev is None:
            u, v = frame_from(t)
        else:
            u = (u_prev - t * u_prev.dot(t)).normalized()
            v = t.cross(u).normalized()
        u_prev = u
        r = radii[i]
        rx, ry = (r, r) if not isinstance(r, tuple) else r
        ring = []
        for s in range(sides):
            a = math.tau * s / sides
            d = u * math.cos(a) * rx * squash[0] + v * math.sin(a) * ry * squash[1]
            if wobble > 0.0:
                d *= 1.0 + wobble * noise.noise(Vector((p.x * 9 + seed, p.y * 9 + a, p.z * 9)))
            ring.append(bm.verts.new(p + d))
        rings.append(ring)
    for i in range(n - 1):
        for s in range(sides):
            a, b = rings[i][s], rings[i][(s + 1) % sides]
            c, d = rings[i + 1][(s + 1) % sides], rings[i + 1][s]
            bm.faces.new((a, b, c, d))
    for end, flag in ((0, cap0), (n - 1, cap1)):
        r = radii[end]
        if flag and (r if not isinstance(r, tuple) else r[0]) > 1e-4:
            tip = pts[end] + (pts[end] - pts[end - 1 if end else 1]).normalized() * ((r if not isinstance(r, tuple) else r[0]) * 0.6)
            vt = bm.verts.new(tip)
            ring = rings[end]
            for s in range(sides):
                bm.faces.new((ring[s], ring[(s + 1) % sides], vt))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return mesh_from_bm(name, bm, sock, mat)


def bone(name, a, b, r, sock, mat, knob=1.6, sides=12, segs=12, seed=0.0):
    """A long bone from a to b: a shaft with flared, knobbed ends (epiphyses)."""
    pts, radii = [], []
    for k in range(segs + 1):
        t = k / segs
        flare = 1.0 + (knob - 1.0) * (math.exp(-(t / 0.13) ** 2) + math.exp(-((1 - t) / 0.13) ** 2))
        pts.append(a.lerp(b, t))
        radii.append(r * flare * (0.92 + 0.08 * math.sin(t * 9.0 + seed)))
    return loft(name, pts, radii, sock, mat, sides, wobble=0.08, seed=seed)


def blob(name, center, radii, sock, mat, segs=32, rings=16, deform=None):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=1.0)
    for v in bm.verts:
        if deform:
            v.co = deform(v.co)                 # sculpt in unit-sphere space, then size it
        v.co = Vector((v.co.x * radii[0], v.co.y * radii[1], v.co.z * radii[2]))
        v.co += center
    return mesh_from_bm(name, bm, sock, mat)


def curve_tube(name, pts, radius, sock, mat, taper=None, closed=False, res=4):
    cu = bpy.data.curves.new(name, 'CURVE')
    cu.dimensions = '3D'
    cu.bevel_depth = radius
    cu.bevel_resolution = res
    cu.use_fill_caps = True
    sp = cu.splines.new('POLY')
    sp.points.add(len(pts) - 1)
    for i, p in enumerate(pts):
        w = 1.0 if taper is None else taper[i]
        sp.points[i].co = (p.x, p.y, p.z, 1.0)
        sp.points[i].radius = w
    sp.use_cyclic_u = closed
    ob = bpy.data.objects.new(name, cu)
    bpy.context.scene.collection.objects.link(ob)
    with bpy.context.temp_override(selected_editable_objects=[ob], selected_objects=[ob], active_object=ob, object=ob):
        bpy.ops.object.select_all(action='DESELECT')
        ob.select_set(True)
        bpy.context.view_layer.objects.active = ob
        bpy.ops.object.convert(target='MESH')
    ob = bpy.context.view_layer.objects.active
    ob["sock"] = sock
    ob.data.materials.clear()
    ob.data.materials.append(mat.m if hasattr(mat, "m") else mat)
    for p in ob.data.polygons:
        p.use_smooth = True
    return ob


def apply_mods(ob):
    bpy.ops.object.select_all(action='DESELECT')
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    for m in list(ob.modifiers):
        bpy.ops.object.modifier_apply(modifier=m.name)


def subsurf(ob, levels=1, apply=True):
    m = ob.modifiers.new("Subsurf", 'SUBSURF')
    m.levels = levels
    m.render_levels = levels
    if apply:
        apply_mods(ob)


def solidify(ob, th, apply=True):
    m = ob.modifiers.new("Solid", 'SOLIDIFY')
    m.thickness = th
    m.offset = 0.0
    if apply:
        apply_mods(ob)


# --- cloth ------------------------------------------------------------------------------------

def hanging_cone(name, top, rx, ry, length, flare, sock, mat, segs=64, rings=30, open_front=0.0, drop=0.0):
    """A cone of cloth hanging from an ellipse at `top`, flared out by `flare` at the hem (the sim
    lets it fall in and buckle into folds). `open_front` (radians half-width) leaves the front open.
    The top ring is the vertex group "pin"."""
    bm = bmesh.new()
    front = math.pi * 0.5                    # +Y is the front in Blender
    a0, span, closed = 0.0, math.tau, True
    if open_front > 0.0:
        a0, span, closed = front + open_front, math.tau - open_front * 2.0, False
    nc = segs if closed else segs + 1
    grid = []
    for i in range(rings + 1):
        t = i / rings
        row = []
        for j in range(nc):
            th = a0 + span * j / segs
            r = 1.0 + flare * t
            p = top + Vector((math.cos(th) * rx * r, math.sin(th) * ry * r, -length * t * (1.0 - drop * 0.0)))
            row.append(bm.verts.new(p))
        grid.append(row)
    for i in range(rings):
        for j in range(segs):
            j1 = (j + 1) % nc if closed else j + 1
            bm.faces.new((grid[i][j], grid[i][j1], grid[i + 1][j1], grid[i + 1][j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = mesh_from_bm(name, bm, sock, mat)
    vg = ob.vertex_groups.new(name="pin")
    vg.add(list(range(nc)), 1.0, 'REPLACE')
    return ob


def collider(ob, thickness=0.012):
    m = ob.modifiers.new("Coll", 'COLLISION')
    ob.collision.thickness_outer = thickness
    ob.collision.cloth_friction = 8.0
    return ob


def simulate(cloths, frames=70, stiff=12.0, bend=0.3):
    sc = bpy.context.scene
    sc.frame_start = 1
    sc.frame_end = frames
    for c in cloths:
        m = c.modifiers.new("Cloth", 'CLOTH')
        s = m.settings
        s.quality = 8
        s.mass = 0.25
        s.tension_stiffness = stiff
        s.compression_stiffness = stiff
        s.shear_stiffness = stiff
        s.bending_stiffness = bend
        s.air_damping = 2.0
        s.vertex_group_mass = "pin"
        m.collision_settings.distance_min = 0.012
        m.collision_settings.use_self_collision = False
        m.point_cache.frame_start = 1
        m.point_cache.frame_end = frames
    for f in range(1, frames + 1):
        sc.frame_set(f)
    for c in cloths:
        bpy.ops.object.select_all(action='DESELECT')
        c.select_set(True)
        bpy.context.view_layer.objects.active = c
        bpy.ops.object.modifier_apply(modifier="Cloth")
    sc.frame_set(1)


# --- materials ----------------------------------------------------------------------------------

class Mat:
    """A Principled material whose colour / roughness / metallic / emission sockets are kept, so the
    baker can route each into an emission pass."""
    def __init__(self, name):
        self.m = bpy.data.materials.new(name)
        self.m.use_nodes = True
        self.nt = self.m.node_tree
        self.nodes = self.nt.nodes
        self.links = self.nt.links
        for n in list(self.nodes):
            self.nodes.remove(n)
        self.out = self.nodes.new('ShaderNodeOutputMaterial')
        self.bsdf = self.nodes.new('ShaderNodeBsdfPrincipled')
        self.links.new(self.bsdf.outputs[0], self.out.inputs[0])
        self.color = None      # output socket feeding Base Color
        self.rough = None
        self.metal = None
        self.emit = None       # output socket feeding the emission colour (pre-multiplied)
        self.coord = self.nodes.new('ShaderNodeTexCoord')

    def n(self, kind, **kw):
        node = self.nodes.new(kind)
        for k, v in kw.items():
            if k in node.inputs:
                node.inputs[k].default_value = v
            else:
                setattr(node, k, v)
        return node

    def noise(self, scale, detail=6.0, rough=0.55, coord="Object", dist=0.0):
        tex = self.n('ShaderNodeTexNoise')
        tex.inputs['Scale'].default_value = scale
        tex.inputs['Detail'].default_value = detail
        tex.inputs['Roughness'].default_value = rough
        if 'Distortion' in tex.inputs:
            tex.inputs['Distortion'].default_value = dist
        self.links.new(self.coord.outputs[coord], tex.inputs['Vector'])
        return tex.outputs['Fac']

    def voronoi(self, scale, feature='F1', coord="Object", out='Distance'):
        tex = self.n('ShaderNodeTexVoronoi')
        tex.feature = feature
        tex.inputs['Scale'].default_value = scale
        self.links.new(self.coord.outputs[coord], tex.inputs['Vector'])
        return tex.outputs[out]

    def ramp(self, fac, stops):
        r = self.n('ShaderNodeValToRGB')
        cr = r.color_ramp
        while len(cr.elements) < len(stops):
            cr.elements.new(0.5)
        for i, (pos, col) in enumerate(stops):
            cr.elements[i].position = pos
            cr.elements[i].color = (col[0], col[1], col[2], 1.0)
        self.links.new(fac, r.inputs['Fac'])
        return r.outputs['Color']

    def math(self, op, a, b=None, clamp=False):
        m = self.n('ShaderNodeMath')
        m.operation = op
        m.use_clamp = clamp
        for i, v in enumerate((a, b)):
            if v is None:
                continue
            if isinstance(v, (int, float)):
                m.inputs[i].default_value = v
            else:
                self.links.new(v, m.inputs[i])
        return m.outputs[0]

    def mix(self, fac, a, b):
        m = self.n('ShaderNodeMix')
        m.data_type = 'RGBA'
        for sock, v in ((m.inputs[0], fac), (m.inputs[6], a), (m.inputs[7], b)):
            if isinstance(v, (int, float)):
                sock.default_value = v
            elif isinstance(v, tuple):
                sock.default_value = (v[0], v[1], v[2], 1.0)
            else:
                self.links.new(v, sock)
        return m.outputs[2]

    def scan(self, name, scale=4.0, blend=0.3):
        """A CC0 scan set (art/blender/textures/<name>_<map>_2k.jpg) box-projected in object space at
        `scale` repeats per metre: returns {"color", "rough", "ao", "disp"} output sockets."""
        tex_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "art", "blender", "textures")
        mp = self.n('ShaderNodeMapping')
        mp.inputs['Scale'].default_value = (scale, scale, scale)
        self.links.new(self.coord.outputs['Object'], mp.inputs['Vector'])
        out = {}
        for key, names, cs in (("color", ("diff", "albedo"), 'sRGB'), ("rough", ("rough",), 'Non-Color'),
                               ("ao", ("ao",), 'Non-Color'), ("disp", ("disp",), 'Non-Color')):
            path = None
            for nm in names:
                cand = os.path.join(tex_dir, "%s_%s_2k.jpg" % (name, nm))
                if os.path.exists(cand):
                    path = cand
            if path is None:
                continue
            img = bpy.data.images.load(path, check_existing=True)
            img.colorspace_settings.name = cs
            t = self.n('ShaderNodeTexImage')
            t.image = img
            t.projection = 'BOX'
            t.projection_blend = blend
            self.links.new(mp.outputs['Vector'], t.inputs['Vector'])
            out[key] = t.outputs['Color']
        return out

    def mul(self, color, by):
        """Colour times a constant colour (darkens a scan into the palette and keeps its detail)."""
        m = self.n('ShaderNodeMix')
        m.data_type = 'RGBA'
        m.blend_type = 'MULTIPLY'
        m.inputs[0].default_value = 1.0
        self.links.new(color, m.inputs[6])
        m.inputs[7].default_value = (by[0], by[1], by[2], 1.0)
        return m.outputs[2]

    def mono(self, color):
        """A scan's brightness only (its own hue -- a camel coat, a tan wall -- would fight the palette)."""
        bw = self.n('ShaderNodeRGBToBW')
        self.links.new(color, bw.inputs[0])
        return bw.outputs[0]

    def tint(self, color, toward, amount):
        """Shift a scan's colour toward a palette colour (keeps its value detail)."""
        return self.mix(amount, color, toward)

    def zpos(self):
        sep = self.n('ShaderNodeSeparateXYZ')
        geo = self.n('ShaderNodeNewGeometry')
        self.links.new(geo.outputs['Position'], sep.inputs[0])
        return sep.outputs['Z']

    def finish(self, color, rough, metal=0.0, height=None, bump=0.5, bump_dist=0.004, emit=None, emit_strength=0.0):
        def put(sock, v):
            if isinstance(v, (int, float)):
                sock.default_value = v
            elif isinstance(v, tuple):
                sock.default_value = (v[0], v[1], v[2], 1.0)
            else:
                self.links.new(v, sock)
        put(self.bsdf.inputs['Base Color'], color)
        put(self.bsdf.inputs['Roughness'], rough)
        put(self.bsdf.inputs['Metallic'], metal)
        self.color, self.rough, self.metal = color, rough, metal
        if height is not None:
            b = self.n('ShaderNodeBump')
            b.inputs['Strength'].default_value = bump
            b.inputs['Distance'].default_value = bump_dist
            self.links.new(height, b.inputs['Height'])
            self.links.new(b.outputs['Normal'], self.bsdf.inputs['Normal'])
        if emit is not None:
            put(self.bsdf.inputs['Emission Color'], emit)
            self.bsdf.inputs['Emission Strength'].default_value = emit_strength
        self.emit = emit
        self.emit_strength = emit_strength
        return self


# --- bake + split + export ------------------------------------------------------------------------

def _route(mat, what):
    """Point the material output at an emission pass of `what` (color/rough/metal/emit)."""
    em = mat.nodes.new('ShaderNodeEmission')
    em.name = "__bake"
    v = {"color": mat.color, "rough": mat.rough, "metal": mat.metal, "emit": mat.emit}[what]
    if what == "emit" and v is None:
        v = (0.0, 0.0, 0.0)
    if isinstance(v, (int, float)):
        em.inputs['Color'].default_value = (v, v, v, 1.0)
    elif isinstance(v, tuple):
        em.inputs['Color'].default_value = (v[0], v[1], v[2], 1.0)
    else:
        mat.links.new(v, em.inputs['Color'])
    if what == "emit":
        em.inputs['Strength'].default_value = min(mat.emit_strength / 8.0, 1.0) if mat.emit is not None else 0.0
    mat.links.new(em.outputs[0], mat.out.inputs[0])


def _unroute(mat):
    n = mat.nodes.get("__bake")
    if n:
        mat.nodes.remove(n)
    mat.links.new(mat.bsdf.outputs[0], mat.out.inputs[0])


def bake_atlas(objs, mats, prefix, tex_dir, size=2048):
    sc = bpy.context.scene
    # UVs: one atlas across every part
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.003)
    bpy.ops.uv.pack_islands(margin=0.003)
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
    sc.cycles.samples = 1
    sc.render.bake.margin = 6
    passes = [("albedo", 'EMIT', "color"), ("rough", 'EMIT', "rough"), ("metal", 'EMIT', "metal"), ("emit", 'EMIT', "emit"),
              ("normal", 'NORMAL', None), ("ao", 'AO', None)]
    for key, kind, route in passes:
        for m, t in tex_nodes:
            t.image = images[key]
            m.nodes.active = t
            if route:
                _route(m, route)
        sc.cycles.samples = 48 if kind == 'AO' else 1
        bpy.ops.object.bake(type=kind, use_clear=True, margin=6)
        for m, t in tex_nodes:
            if route:
                _unroute(m)
        print("BAKED", key)
    os.makedirs(tex_dir, exist_ok=True)
    # pack ORM (AO, roughness, metallic) like glTF
    import numpy as np
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
    for key, img in (("albedo", images["albedo"]), ("normal", images["normal"]), ("orm", out), ("emit", images["emit"])):
        img.filepath_raw = os.path.join(tex_dir, "%s_%s.png" % (prefix, key))
        img.file_format = 'PNG'
        img.save()
        print("SAVED", img.filepath_raw)
    for m, t in tex_nodes:
        m.nodes.remove(t)


def split_and_export(objs, glb_path, rename=None, sockets=None):
    """Join the parts per socket, put each origin on its joint, export a GLB of named meshes."""
    rename = rename or {}
    by = {}
    for o in objs:
        by.setdefault(o["sock"], []).append(o)
    parts = []
    for sock, group in by.items():
        bpy.ops.object.select_all(action='DESELECT')
        for o in group:
            o.select_set(True)
        bpy.context.view_layer.objects.active = group[0]
        if len(group) > 1:
            bpy.ops.object.join()
        ob = bpy.context.view_layer.objects.active
        ob.name = rename.get(sock, sock)
        ob.data.name = ob.name
        # a held thing ("crozier" -> "boss_hand_r") sits on the socket its export name ends with
        table = sockets or SOCKETS
        key = sock if sock in table else rename.get(sock, sock).replace("boss_", "", 1)
        joint = table[key]
        bpy.context.scene.cursor.location = joint
        bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
        ob.location = Vector((0, 0, 0))       # the rig places it: local space is joint space
        for m in list(ob.data.materials):
            pass
        parts.append(ob)
    bpy.ops.object.select_all(action='DESELECT')
    for o in parts:
        o.select_set(True)
    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in parts)
    bpy.ops.export_scene.gltf(filepath=glb_path, export_format='GLB', use_selection=True, export_apply=True,
                              export_yup=True, export_materials='NONE', export_normals=True, export_texcoords=True)
    print("EXPORTED", glb_path, "parts", [o.name for o in parts], "tris", tris)


def preview(path, target_z=1.1, dist=4.2, views=((35, 1.35), (95, 1.25))):
    """Cycles stills of the whole model (before the split), moonlit with a warm fill."""
    sc = bpy.context.scene
    world = bpy.data.worlds.new("W")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.012, 0.016, 0.03, 1.0)
    sc.world = world
    def light(name, kind, loc, energy, col, size=1.0):
        ld = bpy.data.lights.new(name, kind)
        ld.energy = energy
        ld.color = col
        if kind == 'AREA':
            ld.size = size
        lo = bpy.data.objects.new(name, ld)
        lo.location = loc
        sc.collection.objects.link(lo)
        tr = lo.constraints.new('TRACK_TO')
        tr.track_axis = 'TRACK_NEGATIVE_Z'
        tr.up_axis = 'UP_Y'
        tgt = bpy.data.objects.get("__tgt")
        tr.target = tgt
        return lo
    tgt = bpy.data.objects.new("__tgt", None)
    tgt.location = (0, 0, target_z)
    sc.collection.objects.link(tgt)
    light("Key", 'AREA', (-3.0, 3.5, 4.5), 900.0, (0.6, 0.72, 1.0), 2.5)
    light("Fill", 'AREA', (3.0, 2.0, 1.5), 220.0, (1.0, 0.68, 0.4), 2.0)
    light("Rim", 'AREA', (1.0, -4.0, 3.5), 700.0, (0.7, 0.75, 1.0), 2.0)
    floor = bpy.data.meshes.new("Floor")
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=6.0)
    bm.to_mesh(floor)
    bm.free()
    fo = bpy.data.objects.new("Floor", floor)
    fo.location = (0, 0, -0.1)
    sc.collection.objects.link(fo)
    fm = bpy.data.materials.new("FloorM")
    fm.use_nodes = True
    fm.node_tree.nodes["Principled BSDF"].inputs['Base Color'].default_value = (0.05, 0.05, 0.06, 1)
    floor.materials.append(fm)
    cam_d = bpy.data.cameras.new("Cam")
    cam_d.lens = 50
    cam = bpy.data.objects.new("Cam", cam_d)
    sc.collection.objects.link(cam)
    sc.camera = cam
    tr = cam.constraints.new('TRACK_TO')
    tr.target = tgt
    tr.track_axis = 'TRACK_NEGATIVE_Z'
    tr.up_axis = 'UP_Y'
    sc.render.resolution_x = 900
    sc.render.resolution_y = 1200
    sc.cycles.samples = 64
    sc.view_settings.view_transform = 'AgX'
    base, ext = os.path.splitext(path)
    for i, (ang, h) in enumerate(views):
        a = math.radians(ang)
        cam.location = (math.cos(a) * dist, math.sin(a) * dist, h)
        sc.render.filepath = "%s_%d%s" % (base, i, ext)
        bpy.ops.render.render(write_still=True)
        print("PREVIEW", sc.render.filepath)
    for ob in (cam, tgt, fo):
        bpy.data.objects.remove(ob)
    for n in ("Key", "Fill", "Rim"):
        o = bpy.data.objects.get(n)
        if o:
            bpy.data.objects.remove(o)


def quad_sockets(body_height, body_len, hip_spread, upper_len):
    """Rest sockets of a QuadRig (core/enemy/quad_rig.gd) with these proportions."""
    out = {"body": G(0, body_height, 0)}
    out["front"] = out["body"] + G(0, 0.04, -body_len * 0.45)
    out["head"] = out["front"] + G(0, 0.03, -0.16)
    out["tail"] = out["body"] + G(0, 0.02, body_len * 0.45)
    for tag, sx, front in (("fl", -1, True), ("fr", 1, True), ("bl", -1, False), ("br", 1, False)):
        z = -body_len * 0.36 if front else body_len * 0.34
        hip = out["body"] + G(sx * hip_spread, -0.02, z)
        knee = hip + G(sx * upper_len, 0.1, 0.0)
        foot = knee + G(sx * 0.07, -(body_height + 0.08), 0.0)
        out["leg_%s_hip" % tag] = hip
        out["leg_%s_knee" % tag] = knee
        out["leg_%s_foot" % tag] = foot
    return out


def meta_body(name, elements, sock, mat, res=0.018, rough=0.0, seed=0.0):
    """One smooth organic mass from metaball ellipsoids [(center, (sx, sy, sz), stiffness)] -- the
    forms blend into each other (separate spheres read as balls glued together)."""
    mb = bpy.data.metaballs.new(name)
    mb.resolution = res
    mb.render_resolution = res
    for c, size, stiff in elements:
        e = mb.elements.new(type='ELLIPSOID')
        e.co = c
        e.radius = 1.0
        e.size_x, e.size_y, e.size_z = size
        e.stiffness = stiff
    ob = bpy.data.objects.new(name, mb)
    bpy.context.scene.collection.objects.link(ob)
    bpy.ops.object.select_all(action='DESELECT')
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.convert(target='MESH')
    ob = bpy.context.view_layer.objects.active
    ob.name = name
    ob["sock"] = sock
    ob.data.materials.clear()
    ob.data.materials.append(mat.m if hasattr(mat, "m") else mat)
    if rough > 0.0:
        me = ob.data
        me.calc_loop_triangles()
        for v in me.vertices:
            n = v.normal
            v.co += n * rough * (noise.noise(v.co * 9.0 + Vector((seed, 0, 0))) + 0.5 * noise.noise(v.co * 23.0))
    for p in ob.data.polygons:
        p.use_smooth = True
    return ob


def fuse(objs, voxel=0.0035, keep=None, sculpt=0.0, sculpt_scale=0.05, decimate=0.0):
    """Fuse each (socket, material) group of solid parts into one continuous surface: join, voxel
    remesh (no seams, no intersecting primitives), then sculpt it -- a real displacement of the
    surface by two noise layers (`sculpt` metres) -- and optionally decimate. Parts whose material
    is in `keep` (glows, thin gilt work, cloth) are left as they are. Returns the new object list."""
    keep = keep or set()
    groups = {}
    rest = []
    for o in objs:
        m = o.data.materials[0].name if o.data.materials else ""
        if m in keep or o.type != 'MESH':
            rest.append(o)
            continue
        groups.setdefault((o["sock"], m), []).append(o)
    out = list(rest)
    for (sock, m), group in groups.items():
        bpy.ops.object.select_all(action='DESELECT')
        for o in group:
            o.select_set(True)
        bpy.context.view_layer.objects.active = group[0]
        if len(group) > 1:
            bpy.ops.object.join()
        ob = bpy.context.view_layer.objects.active
        mat = ob.data.materials[0]
        r = ob.modifiers.new("Remesh", 'REMESH')
        r.mode = 'VOXEL'
        r.voxel_size = voxel
        r.adaptivity = 0.0
        apply_mods(ob)
        if sculpt > 0.0:
            for nm, kind, size, st in (("S1", 'VORONOI', sculpt_scale, sculpt), ("S2", 'CLOUDS', sculpt_scale * 0.35, sculpt * 0.4)):
                tex = bpy.data.textures.new(ob.name + nm, kind)
                tex.noise_scale = size
                if kind == 'VORONOI':
                    tex.distance_metric = 'DISTANCE'
                    tex.weight_1 = 1.0
                    tex.weight_2 = -0.6
                d = ob.modifiers.new(nm, 'DISPLACE')
                d.texture = tex
                d.texture_coords = 'GLOBAL'
                d.strength = st
                d.mid_level = 0.5
            sm = ob.modifiers.new("Smooth", 'CORRECTIVE_SMOOTH')
            sm.factor = 0.3
            sm.iterations = 2
            apply_mods(ob)
        if decimate > 0.0:
            dm = ob.modifiers.new("Dec", 'DECIMATE')
            dm.ratio = decimate
            apply_mods(ob)
        ob.data.materials.clear()
        ob.data.materials.append(mat)
        for p in ob.data.polygons:
            p.use_smooth = True
        ob["sock"] = sock
        ob.name = "%s_%s" % (sock, mat.name)
        out.append(ob)
    print("FUSED", len(objs), "parts into", len(out), "tris", sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in out))
    return out
