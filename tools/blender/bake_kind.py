"""Bake a built model the way game characters are finished: a HIGH copy carries the sculpted detail, the game mesh
(LOW) gets its own unwrap, and the high's detail, colour and light are baked down into the kind's four maps
(art/textures/grunt_<kind>_albedo / _normal / _orm / _emit.png), which grunt_pbr.gdshader reads.

The high is the low subdivided and displaced per surface layer (the layer each face carries in its "Layer" UV):
skin wrinkles and pores and lumps, cloth folds running down and a worn weave, bone pitted and cracked, iron dented,
wood grained. Its material paints the colour: the vertex tint, mottled, darkened in its own cavities (AO), rubbed
light on its edges (pointiness), with the glow (vertex alpha 0) as emission.

    import bake_kind; bake_kind.bake(body_object, "gaunt", size=2048)
"""
import bpy
import math
import os
import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
LAYERS = ["wool", "linen", "trim", "leather", "bone", "gilt", "iron", "wood", "stone", "glow", "skin"]
# per layer: roughness, metallic, mottle, edge-wear, [displacements: (texture, size, strength, stretch_z)]
FINISH = {
    "wool":    (0.92, 0.0, 0.06, 0.12, [("CLOUDS", 0.05, 0.009, 5.0), ("STUCCI", 0.005, 0.0025, 1.0)]),
    "linen":   (0.88, 0.0, 0.06, 0.12, [("CLOUDS", 0.04, 0.008, 6.0), ("STUCCI", 0.004, 0.0018, 1.0)]),
    "trim":    (0.6, 0.4, 0.06, 0.35, [("STUCCI", 0.006, 0.0010, 1.0)]),
    "leather": (0.72, 0.0, 0.18, 0.35, [("VORONOI", 0.02, 0.0015, 1.0), ("CLOUDS", 0.04, 0.003, 1.0)]),
    "bone":    (0.7, 0.0, 0.24, 0.5, [("VORONOI", 0.012, 0.004, 1.0), ("STUCCI", 0.006, 0.003, 1.0), ("CLOUDS", 0.04, 0.008, 1.0)]),
    "gilt":    (0.35, 1.0, 0.10, 0.6, [("VORONOI", 0.05, -0.0015, 1.0)]),
    "iron":    (0.45, 0.9, 0.12, 0.6, [("VORONOI", 0.04, -0.0025, 1.0), ("STUCCI", 0.004, 0.0006, 1.0)]),
    "wood":    (0.8, 0.0, 0.15, 0.3, [("WOOD", 0.03, 0.003, 1.0), ("CLOUDS", 0.02, 0.0015, 4.0)]),
    "stone":   (0.85, 0.0, 0.22, 0.4, [("VORONOI", 0.03, 0.003, 1.0), ("STUCCI", 0.01, 0.0025, 1.0)]),
    "glow":    (0.5, 0.0, 0.0, 0.0, []),
    "skin":    (0.82, 0.0, 0.34, 0.3, [("VORONOI", 0.011, 0.0055, 1.0), ("CLOUDS", 0.03, 0.009, 1.0), ("STUCCI", 0.003, 0.0012, 1.0)]),
}


# each layer's tile as the game's tiling materials wore it (core/enemy/boss_look.gd SURFACES): tile, uv scale,
# normal depth, keep the tile's own colour (else the tint's colour with the tile's weave)
SURF = {"wool": ("wool", (2.2, 2.2), 1.0, False), "linen": ("wool", (3.4, 3.4), 0.6, False), "trim": ("trim", (1 / 0.24, 1.0), 1.0, True),
        "leather": ("leather", (2.0, 2.0), 1.0, False), "bone": ("leather", (1.3, 1.3), 0.45, False), "gilt": ("iron", (3.0, 3.0), 0.6, False),
        "iron": ("iron", (2.0, 2.0), 1.0, False), "wood": ("wood", (1.5, 1.5), 1.0, False), "stone": ("iron", (0.8, 0.8), 1.4, False),
        "glow": ("iron", (1.0, 1.0), 0.0, False), "skin": ("leather", (2.6, 2.6), 0.8, False)}
TILES = os.path.join(ROOT, "art", "blender", "tiles")


def _tile(name, normal=False):
    path = os.path.join(TILES, name + ("_n" if normal else "") + ".png")
    im = bpy.data.images.load(path, check_existing=True)
    im.colorspace_settings.name = 'Non-Color' if normal else 'sRGB'
    return im


def _tile_mean(name):
    im = _tile(name)
    px = np.array(im.pixels[:]).reshape(-1, 4)[::97, :3]
    lin = np.where(px <= 0.04045, px / 12.92, ((px + 0.055) / 1.055) ** 2.4)
    return max(float((lin @ np.array([0.3, 0.59, 0.11])).mean()), 0.02)


def wire_tiles(N):
    """The tiling materials' look, painted into the bake: per layer its tile at its scale on the "Tile" UVs (the
    model's own metres), the tint carrying the colour and the tile its weave; and the tile's relief as normals."""
    nt = N["nt"]
    uvt = nt.nodes.new("ShaderNodeUVMap")
    uvt.uv_map = "Tile"
    xl = N["layer_x"]
    col_sum = None
    nrm_sum = None
    means = {}
    for k, nm in enumerate(LAYERS):
        tile, sc, nd, keep = SURF[nm]
        mask = _math(nt, 'COMPARE', xl, k + 0.5, 0.5)
        vm = nt.nodes.new("ShaderNodeVectorMath")
        vm.operation = 'MULTIPLY'
        vm.inputs[1].default_value = (sc[0], sc[1], 1.0)
        nt.links.new(uvt.outputs[0], vm.inputs[0])
        ta = nt.nodes.new("ShaderNodeTexImage")
        ta.image = _tile(tile)
        nt.links.new(vm.outputs[0], ta.inputs[0])
        if keep:
            c = _mix(nt, ta.outputs["Color"], N["col"].outputs["Color"], 1.0, 'MULTIPLY')
        else:
            if tile not in means:
                means[tile] = _tile_mean(tile)
            bw = nt.nodes.new("ShaderNodeRGBToBW")
            nt.links.new(ta.outputs["Color"], bw.inputs[0])
            ratio = _math(nt, 'DIVIDE', bw.outputs[0], means[tile])
            ratio = _math(nt, 'MINIMUM', _math(nt, 'MAXIMUM', ratio, 0.45), 1.7)
            c = _mix(nt, N["col"].outputs["Color"], ratio, 1.0, 'MULTIPLY')
        c = _mix(nt, (0, 0, 0, 1), c, mask, 'MIX')
        col_sum = c if col_sum is None else _mix(nt, col_sum, c, 1.0, 'ADD')
        tn = nt.nodes.new("ShaderNodeTexImage")
        tn.image = _tile(tile, True)
        nt.links.new(vm.outputs[0], tn.inputs[0])
        nm_node = nt.nodes.new("ShaderNodeNormalMap")
        nm_node.space = 'TANGENT'
        nm_node.uv_map = "Tile"
        nm_node.inputs["Strength"].default_value = nd
        nt.links.new(tn.outputs["Color"], nm_node.inputs["Color"])
        sv = nt.nodes.new("ShaderNodeVectorMath")
        sv.operation = 'SCALE'
        nt.links.new(nm_node.outputs[0], sv.inputs[0])
        nt.links.new(mask, sv.inputs["Scale"])
        if nrm_sum is None:
            nrm_sum = sv.outputs[0]
        else:
            ad = nt.nodes.new("ShaderNodeVectorMath")
            ad.operation = 'ADD'
            nt.links.new(nrm_sum, ad.inputs[0])
            nt.links.new(sv.outputs[0], ad.inputs[1])
            nrm_sum = ad.outputs[0]
    nz = nt.nodes.new("ShaderNodeVectorMath")
    nz.operation = 'NORMALIZE'
    nt.links.new(nrm_sum, nz.inputs[0])
    N["tile_col"] = col_sum
    N["tile_nrm"] = nz.outputs[0]


def _layer_of_vertices(me):
    uv2 = me.uv_layers["Layer"].data
    votes = np.zeros((len(me.vertices), len(LAYERS)))
    for poly in me.polygons:
        for li in poly.loop_indices:
            k = min(max(int(uv2[li].uv[0]), 0), len(LAYERS) - 1)
            votes[me.loops[li].vertex_index, k] += 1
    return votes.argmax(1)


def make_high(low, levels=2):
    hi = low.copy()
    hi.data = low.data.copy()
    hi.name = low.name + "_high"
    bpy.context.scene.collection.objects.link(hi)
    for vg in list(hi.vertex_groups):
        hi.vertex_groups.remove(vg)
    lay = _layer_of_vertices(hi.data)
    groups = {}
    for k, nm in enumerate(LAYERS):
        idx = np.nonzero(lay == k)[0].tolist()
        if idx and FINISH[nm][4]:
            g = hi.vertex_groups.new(name="L_" + nm)
            g.add(idx, 1.0, 'REPLACE')
            groups[nm] = g
    sd = hi.modifiers.new("Sub", 'SUBSURF')
    sd.levels = levels
    sd.render_levels = levels
    sd.quality = 3
    for nm, g in groups.items():
        for j, (tt, size, strength, stretch) in enumerate(FINISH[nm][4]):
            tex = bpy.data.textures.new("%s_%d" % (nm, j), type=tt)
            if hasattr(tex, "noise_scale"):
                tex.noise_scale = size
            if tt == "VORONOI":
                tex.distance_metric = 'DISTANCE'
                tex.color_mode = 'INTENSITY'
                tex.weight_1, tex.weight_2 = -1.0, 1.0           # F2 - F1: a network of creases
            if tt == "WOOD":
                tex.wood_type = 'RINGNOISE'
                tex.noise_scale = size
            em = bpy.data.objects.new("tc_%s_%d" % (nm, j), None)
            bpy.context.scene.collection.objects.link(em)
            em.scale = (1.0, 1.0, 1.0 / stretch)                 # folds and grain run down: the noise stretched in z
            d = hi.modifiers.new("D_%s_%d" % (nm, j), 'DISPLACE')
            d.texture = tex
            d.texture_coords = 'OBJECT'
            d.texture_coords_object = em
            d.strength = strength
            d.mid_level = 0.5
            d.vertex_group = g.name
    return hi


def _ramp(nt, values, x_socket):
    """A constant colour ramp over the layer index (x / 11): one value per layer."""
    r = nt.nodes.new("ShaderNodeValToRGB")
    r.color_ramp.interpolation = 'CONSTANT'
    els = r.color_ramp.elements
    while len(els) > 1:
        els.remove(els[-1])
    n = len(LAYERS)
    els[0].position = 0.0
    els[0].color = values[0]
    for k in range(1, n):
        e = els.new(k / n)
        e.color = values[k]
    nt.links.new(x_socket, r.inputs[0])
    return r


def high_material(hi):
    m = bpy.data.materials.new("bake_high")
    m.use_nodes = True
    nt = m.node_tree
    for nd in list(nt.nodes):
        nt.nodes.remove(nd)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    emis = nt.nodes.new("ShaderNodeEmission")
    nt.links.new(emis.outputs[0], out.inputs[0])
    col = nt.nodes.new("ShaderNodeAttribute")
    col.attribute_name = "Color"
    lay = nt.nodes.new("ShaderNodeUVMap")
    lay.uv_map = "Layer"
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(lay.outputs[0], sep.inputs[0])
    div = nt.nodes.new("ShaderNodeMath")
    div.operation = 'DIVIDE'
    div.inputs[1].default_value = len(LAYERS)
    nt.links.new(sep.outputs[0], div.inputs[0])
    x = div.outputs[0]
    layer_x = sep.outputs[0]
    fin = [FINISH[nm] for nm in LAYERS]
    r_rough = _ramp(nt, [(f[0], f[0], f[0], 1) for f in fin], x)
    r_metal = _ramp(nt, [(f[1], f[1], f[1], 1) for f in fin], x)
    r_mott = _ramp(nt, [(f[2], f[2], f[2], 1) for f in fin], x)
    r_wear = _ramp(nt, [(f[3], f[3], f[3], 1) for f in fin], x)
    ao = nt.nodes.new("ShaderNodeAmbientOcclusion")
    ao.samples = 16
    ao.inputs["Distance"].default_value = 0.06
    ao.only_local = True
    ao2 = nt.nodes.new("ShaderNodeAmbientOcclusion")             # the broad occlusion: under a hood, a coat, an arm
    ao2.samples = 16
    ao2.inputs["Distance"].default_value = 0.25
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    noise = nt.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 14.0
    noise.inputs["Detail"].default_value = 6.0
    nt.links.new(tc.outputs["Object"], noise.inputs["Vector"])
    noise2 = nt.nodes.new("ShaderNodeTexNoise")                    # broad blotches: bruising, stain, rust
    noise2.inputs["Scale"].default_value = 3.0
    noise2.inputs["Detail"].default_value = 3.0
    nt.links.new(tc.outputs["Object"], noise2.inputs["Vector"])
    nodes = {"layer_x": layer_x, "col": col, "r_rough": r_rough, "r_metal": r_metal, "r_mott": r_mott, "r_wear": r_wear, "ao": ao, "ao2": ao2,
             "geo": geo, "noise": noise, "noise2": noise2, "emis": emis, "nt": nt, "tc": tc}
    hi.data.materials.clear()
    hi.data.materials.append(m)
    return m, nodes


def _math(nt, op, a, b=None, c=None, clamp=False):
    n = nt.nodes.new("ShaderNodeMath")
    n.operation = op
    n.use_clamp = clamp
    for i, v in enumerate((a, b, c)):
        if v is None:
            continue
        if isinstance(v, (int, float)):
            n.inputs[i].default_value = v
        else:
            nt.links.new(v, n.inputs[i])
    return n.outputs[0]


def _mix(nt, a, b, fac, mode='MULTIPLY'):
    n = nt.nodes.new("ShaderNodeMix")
    n.data_type = 'RGBA'
    n.blend_type = mode
    for sock, v in ((n.inputs[0], fac), (n.inputs[6], a), (n.inputs[7], b)):
        if isinstance(v, (int, float)):
            sock.default_value = v
        elif isinstance(v, tuple):
            sock.default_value = v
        else:
            nt.links.new(v, sock)
    return n.outputs[2]


def wire_albedo(N):
    """The painted colour: tint, mottled per layer, its cavities darkened (both occlusions), its edges rubbed light."""
    nt = N["nt"]
    base = N.get("tile_col") or N["col"].outputs["Color"]
    # mottle: value wobble from two noises, by the layer's mottle amount
    mn = _math(nt, 'MULTIPLY_ADD', N["noise"].outputs["Fac"], 1.0, -0.5)          # fac - 0.5 .. via (fac*1 + -0.5)
    mn2 = _math(nt, 'MULTIPLY_ADD', N["noise2"].outputs["Fac"], 0.8, -0.4)
    m_all = _math(nt, 'ADD', mn, mn2)
    m_k = _math(nt, 'MULTIPLY', m_all, N["r_mott"].outputs["Color"])
    m_f = _math(nt, 'ADD', m_k, 1.0)
    c = _mix(nt, base, m_f, 1.0, 'MULTIPLY')
    # cavity: AO darkens hard (deep creases near black), broad AO softer
    ao_c = _math(nt, 'POWER', N["ao"].outputs["AO"], 1.2)
    ao_k = _math(nt, 'MULTIPLY_ADD', ao_c, 0.55, 0.45)
    c = _mix(nt, c, ao_k, 1.0, 'MULTIPLY')
    ao_b = _math(nt, 'MULTIPLY_ADD', N["ao2"].outputs["AO"], 0.3, 0.7)
    c = _mix(nt, c, ao_b, 1.0, 'MULTIPLY')
    # edges: pointiness above its mean rubs the surface lighter
    pt = _math(nt, 'SUBTRACT', N["geo"].outputs["Pointiness"], 0.56)     # only real edges, not the sculpt's grain
    pt = _math(nt, 'MULTIPLY', pt, 5.0, clamp=True)
    pt = _math(nt, 'MULTIPLY', pt, N["r_wear"].outputs["Color"])
    c = _mix(nt, c, (1.0, 0.96, 0.9, 1.0), pt, 'SCREEN')
    return c


def _image(name, size, data=False):
    im = bpy.data.images.new(name, size, size, alpha=False, float_buffer=False, is_data=data)
    im.colorspace_settings.name = 'Non-Color' if data else 'sRGB'
    return im


def _target(low, im):
    for m in low.data.materials:
        m.use_nodes = True
        nt = m.node_tree
        nd = nt.nodes.get("bake_target") or nt.nodes.new("ShaderNodeTexImage")
        nd.name = "bake_target"
        nd.image = im
        for n2 in nt.nodes:
            n2.select = False
        nd.select = True
        nt.nodes.active = nd


def _save(im, path):
    im.filepath_raw = path
    im.file_format = 'PNG'
    im.save()


# texture space by what is looked at: the face most, skin and hands next, cloth less, crust and hidden linings least
DENSITY = {"skin": 1.5, "bone": 0.9, "iron": 1.0, "gilt": 1.0, "leather": 1.0, "wool": 0.8, "linen": 0.8, "trim": 1.0, "wood": 0.9, "stone": 1.0, "glow": 0.25}


def unwrap(low, margin=0.003, density=None, head_k=2.6):
    bpy.ops.object.select_all(action='DESELECT')
    bpy.context.view_layer.objects.active = low
    low.select_set(True)
    low.data.uv_layers.active = low.data.uv_layers["UVMap"]
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(float(os.environ.get('BAKE_ANGLE','80'))), island_margin=margin, area_weight=0.0, scale_to_bounds=False)
    bpy.ops.object.mode_set(mode='OBJECT')
    # scale each island about its centre by its density (a face's layer; the head's faces by head_k on top), then pack
    me = low.data
    dens = dict(DENSITY, **(density or {}))
    uv = me.uv_layers["UVMap"].data
    lay = me.uv_layers["Layer"].data
    head = low.vertex_groups.get("head")
    hv = set()
    if head is not None:
        for v in me.vertices:
            for gr in v.groups:
                if gr.group == head.index and gr.weight > 0.5:
                    hv.add(v.index)
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(me)
    uvl = bm.loops.layers.uv["UVMap"]
    lyl = bm.loops.layers.uv["Layer"]
    bm.faces.ensure_lookup_table()
    seen = set()
    for f0 in bm.faces:
        if f0.index in seen:
            continue
        # flood the island through shared UV edges
        isl, stack = [], [f0]
        seen.add(f0.index)
        while stack:
            f = stack.pop()
            isl.append(f)
            for l in f.loops:
                e = l.edge
                for lf in e.link_faces:
                    if lf.index in seen:
                        continue
                    # same island if both UVs of the edge match on the two faces
                    a = [lo for lo in lf.loops if lo.edge == e]
                    if not a:
                        continue
                    o = a[0]
                    if (o[uvl].uv - l.link_loop_next[uvl].uv).length < 1e-5 and (o.link_loop_next[uvl].uv - l[uvl].uv).length < 1e-5:
                        seen.add(lf.index)
                        stack.append(lf)
        k_layer = []
        is_head = 0
        for f in isl:
            nm = LAYERS[min(max(int(f.loops[0][lyl].uv[0]), 0), len(LAYERS) - 1)]
            k_layer.append(dens.get(nm, 1.0))
            if all(v.index in hv for v in f.verts):
                is_head += 1
        k = float(np.mean(k_layer)) * (head_k if is_head > len(isl) * 0.5 else 1.0)
        pts = [l[uvl].uv.copy() for f in isl for l in f.loops]
        cx = sum(p.x for p in pts) / len(pts)
        cy = sum(p.y for p in pts) / len(pts)
        for f in isl:
            for l in f.loops:
                l[uvl].uv.x = cx + (l[uvl].uv.x - cx) * k
                l[uvl].uv.y = cy + (l[uvl].uv.y - cy) * k
    bm.to_mesh(me)
    bm.free()
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.pack_islands(margin=margin, rotate=True, scale=True)
    bpy.ops.object.mode_set(mode='OBJECT')


def bake(low, kind, size=2048, levels=3, samples=24, extras=(), prefix="grunt"):
    """Bake the kind's four maps (art/textures/<prefix>_<kind>_*.png) onto `low` and the rigid parts it carries
    (`extras`: a staff, a shield, a lamp), all in one atlas. They are joined into a stand-in for the unwrap and the
    bake (the carried parts set well apart, so nothing occludes across them), and the unwrap is copied back."""
    sc = bpy.context.scene
    work = low.copy()
    work.data = low.data.copy()
    work.name = "bake_work"
    sc.collection.objects.link(work)
    counts = [len(low.data.loops)]
    for i, e in enumerate(extras):
        c = e.copy()
        c.data = e.data.copy()
        sc.collection.objects.link(c)
        c.matrix_world = __import__("mathutils").Matrix.Translation((4.0 + 2.5 * i, 0.0, 0.0)) @ e.matrix_world
        bpy.ops.object.select_all(action='DESELECT')
        c.select_set(True)
        work.select_set(True)
        bpy.context.view_layer.objects.active = work
        bpy.ops.object.join()
        counts.append(len(e.data.loops))
    _bake_one(work, kind, size, levels, samples, prefix)
    uv = np.empty(len(work.data.loops) * 2, dtype=np.float32)
    work.data.uv_layers["UVMap"].data.foreach_get("uv", uv)
    at = 0
    for ob, n in zip([low] + list(extras), counts):
        ob.data.uv_layers["UVMap"].data.foreach_set("uv", uv[at * 2:(at + n) * 2])
        at += n
    bpy.data.objects.remove(work)


def _bake_one(low, kind, size, levels, samples, prefix):
    sc = bpy.context.scene
    me = low.data
    if "Tile" not in me.uv_layers:
        t = me.uv_layers.new(name="Tile")
        uv = np.empty(len(me.loops) * 2, dtype=np.float32)
        me.uv_layers["UVMap"].data.foreach_get("uv", uv)
        t.data.foreach_set("uv", uv)
    sc.render.engine = 'CYCLES'
    sc.cycles.samples = samples
    try:
        sc.cycles.device = 'GPU'
        prefs = bpy.context.preferences.addons["cycles"].preferences
        prefs.compute_device_type = 'METAL'
        prefs.get_devices()
        for d in prefs.devices:
            d.use = True
    except Exception:
        sc.cycles.device = 'CPU'
    unwrap(low)
    hi = make_high(low, levels)
    m, N = high_material(hi)
    wire_tiles(N)
    out = N["nt"].nodes["Material Output"]
    emis = N["emis"]
    nt = N["nt"]
    bk = sc.render.bake
    bk.use_selected_to_active = True
    bk.cage_extrusion = float(os.environ.get("BAKE_EXT", "0.012"))
    bk.max_ray_distance = float(os.environ.get("BAKE_RAY", "0.03"))
    bk.margin = 6
    bk.target = 'IMAGE_TEXTURES'
    for o in sc.objects:
        o.hide_render = o not in (low, hi)
    bpy.ops.object.select_all(action='DESELECT')
    hi.select_set(True)
    low.select_set(True)
    bpy.context.view_layer.objects.active = low
    tex = os.path.join(ROOT, "art", "textures", "%s_%s_%%s.png" % (prefix, kind))

    # albedo: the painted colour as emission
    alb = wire_albedo(N)
    nt.links.new(alb, emis.inputs["Color"])
    im = _image(kind + "_albedo", size)
    _target(low, im)
    bpy.ops.object.bake(type='EMIT')
    _save(im, tex % "albedo")
    # orm: occlusion, roughness (with noise), metallic
    comb = nt.nodes.new("ShaderNodeCombineXYZ")
    ao_k = _math(nt, 'MULTIPLY', _math(nt, 'MULTIPLY_ADD', N["ao"].outputs["AO"], 0.7, 0.3), _math(nt, 'MULTIPLY_ADD', N["ao2"].outputs["AO"], 0.4, 0.6))
    rough = _math(nt, 'ADD', N["r_rough"].outputs["Color"], _math(nt, 'MULTIPLY_ADD', N["noise"].outputs["Fac"], 0.2, -0.1), clamp=True)
    nt.links.new(ao_k, comb.inputs[0])
    nt.links.new(rough, comb.inputs[1])
    nt.links.new(N["r_metal"].outputs["Color"], comb.inputs[2])
    nt.links.new(comb.outputs[0], emis.inputs["Color"])
    im = _image(kind + "_orm", size, data=True)
    _target(low, im)
    bpy.ops.object.bake(type='EMIT')
    _save(im, tex % "orm")
    # emit: the glow, painted where the tint's alpha is 0
    inv = _math(nt, 'SUBTRACT', 1.0, N["col"].outputs["Alpha"], clamp=True)
    gl = _mix(nt, (0, 0, 0, 1), N["col"].outputs["Color"], inv, 'MIX')
    nt.links.new(gl, emis.inputs["Color"])
    im = _image(kind + "_emit", size // 2 if size > 1024 else size)
    _target(low, im)
    bpy.ops.object.bake(type='EMIT')
    _save(im, tex % "emit")
    # normal: the high's surface in the low's tangent space (OpenGL, as grunt_pbr reads it)
    bsdf = nt.nodes.new("ShaderNodeBsdfDiffuse")
    nt.links.new(N["tile_nrm"], bsdf.inputs["Normal"])
    nt.links.new(bsdf.outputs[0], out.inputs[0])
    im = _image(kind + "_normal", size, data=True)
    _target(low, im)
    bk.normal_space = 'TANGENT'
    bpy.ops.object.bake(type='NORMAL')
    _save(im, tex % "normal")
    for o in sc.objects:
        o.hide_render = False
    bpy.data.objects.remove(hi)
    for o in [o for o in sc.objects if o.name.startswith("tc_")]:
        bpy.data.objects.remove(o)
    print("BAKED", kind, size)
