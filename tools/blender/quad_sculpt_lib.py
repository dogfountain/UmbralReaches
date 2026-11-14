"""r38d quadruped pipeline: one continuous sculpted skin per creature (crawler, leaper, burrower, mite,
Thornwarden). quad_sdf.py meshes a smooth-union signed-distance model into one watertight surface; this
file puts that surface through Blender: subdivide, displace (creases, plates, bark), paint region weights
and colour attributes, decimate a low, bake albedo / normal / AO / roughness / emission from the HIGH onto
the low's atlas, skin the low to the rig's bones with smooth envelope weights, export one GLB.

Rig space is Godot's (+Y up, the body faces -Z); Blender space is G(x, y, z) = (x, -z, y).
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
import grunt_kit as GK
import quad_sdf as Q

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.environ.get("GRUNT_OUT", "")


def to_bl(P):
    return np.stack([P[:, 0], -P[:, 2], P[:, 1]], 1)


def to_rig(A):
    return np.stack([A[:, 0], A[:, 2], -A[:, 1]], 1)


# --- the high-poly ------------------------------------------------------------------------------------

def object_from_quads(name, P, quads):
    me = bpy.data.meshes.new(name)
    me.from_pydata(to_bl(P).tolist(), [], quads.tolist())
    me.update()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    # a closed surface must enclose positive volume: if the recalc left the whole skin inside out, flip it
    vol = sum(f.calc_area() * f.normal.dot(f.calc_center_median()) for f in bm.faces) / 3.0
    if vol < 0:
        bmesh.ops.reverse_faces(bm, faces=bm.faces)
        print("WARNING: skin was inside out (volume %.4f), flipped" % vol)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    return ob


def subdivide(ob, levels=1):
    bpy.context.view_layer.objects.active = ob
    m = ob.modifiers.new("Sub", 'SUBSURF')
    m.levels = levels
    m.render_levels = levels
    m.quality = 3
    K.apply_mods(ob)
    for p in ob.data.polygons:
        p.use_smooth = True


def rig_verts(ob):
    n = len(ob.data.vertices)
    co = np.empty(n * 3, dtype=np.float32)
    ob.data.vertices.foreach_get('co', co)
    nr = np.empty(n * 3, dtype=np.float32)
    ob.data.vertex_normals.foreach_get('vector', nr)
    return to_rig(co.reshape(n, 3)), to_rig(nr.reshape(n, 3))


def set_rig_verts(ob, P):
    ob.data.vertices.foreach_set('co', to_bl(P).astype(np.float32).ravel())
    ob.data.update()


def displace(ob, d, P=None, N=None):
    if P is None:
        P, N = rig_verts(ob)
    set_rig_verts(ob, P + N * d[:, None])


def smooth_verts(ob, iters=2, factor=0.5):
    """Laplacian relax on the high (kills the surface-net ripple before detail is cut in)."""
    n = len(ob.data.vertices)
    ne = len(ob.data.edges)
    e = np.empty(ne * 2, dtype=np.int32)
    ob.data.edges.foreach_get('vertices', e)
    e = e.reshape(-1, 2)
    P, _ = rig_verts(ob)
    cnt = np.bincount(e.ravel(), minlength=n).astype(np.float32)
    for _ in range(iters):
        s = np.zeros_like(P)
        for k in range(3):
            s[:, k] = np.bincount(e[:, 0], weights=P[e[:, 1], k], minlength=n) + np.bincount(e[:, 1], weights=P[e[:, 0], k], minlength=n)
        P = P + (s / np.maximum(cnt, 1)[:, None] - P) * factor
    set_rig_verts(ob, P)


def set_attr(ob, name, arr):
    """A float colour attribute per vertex from an (N,) / (N,3) / (N,4) array (materials read it by name)."""
    a = np.asarray(arr, dtype=np.float32)
    if a.ndim == 1:
        a = np.stack([a, a, a, np.ones_like(a)], 1)
    elif a.shape[1] == 3:
        a = np.concatenate([a, np.ones((len(a), 1), dtype=np.float32)], 1)
    at = ob.data.color_attributes.get(name) or ob.data.color_attributes.new(name, 'FLOAT_COLOR', 'POINT')
    at.data.foreach_set('color', a.ravel())


def face_verts(ob):
    nl = len(ob.data.loops)
    vi = np.empty(nl, dtype=np.int32)
    ob.data.loops.foreach_get('vertex_index', vi)
    return vi.reshape(-1, 4)


def assign_materials(ob, mats, vert_idx):
    """Slot the materials, each face the material most of its vertices carry."""
    for m in mats:
        ob.data.materials.append(m.m if hasattr(m, "m") else m)
    fv = face_verts(ob)
    votes = np.stack([(vert_idx[fv] == k).sum(1) for k in range(len(mats))], 1)
    idx = votes.argmax(1).astype(np.int32)
    ob.data.polygons.foreach_set('material_index', idx)


def region_idx(F, P, tags, tau=0.004):
    """Index into `tags` of the nearest tagged group of primitives at each point (and the raw distances)."""
    D = np.stack([F.tag_dist(P, t) for t in tags], 1)
    return D.argmin(1), D


# --- the low and its weights -----------------------------------------------------------------------

def make_low(src, tris, name, method="decimate"):
    low = src.copy()
    low.data = src.data.copy()
    low.name = name
    low.data.name = name
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


def envelope(P, segs, band=0.05, power=2.0, bias=None):
    """Weights {bone: (N,)} for rig-space points P: a vertex follows the bone segments (bone, a, b[, band])
    it is nearest to, blending over `band` beyond the nearest one."""
    P = np.asarray(P, dtype=np.float32)
    names = sorted({s[0] for s in segs})
    N = len(P)
    W = np.zeros((N, len(names)), dtype=np.float32)
    D = np.empty((N, len(segs)), dtype=np.float32)
    BW = np.empty(len(segs), dtype=np.float32)
    for j, s in enumerate(segs):
        a = np.asarray(s[1], dtype=np.float32)
        b = np.asarray(s[2], dtype=np.float32)
        ab = b - a
        t = np.clip(((P - a) @ ab) / max(float(ab @ ab), 1e-9), 0.0, 1.0)
        q = a + t[:, None] * ab
        D[:, j] = np.sqrt(((P - q) ** 2).sum(1))
        BW[j] = s[3] if len(s) > 3 else band
    dmin = D.min(1, keepdims=True)
    w = np.clip(1.0 - (D - dmin) / BW[None, :], 0.0, 1.0) ** power
    for j, s in enumerate(segs):
        k = names.index(s[0])
        W[:, k] = np.maximum(W[:, k], w[:, j])
    return names, W


def smooth_weights(ob, W, iters=4):
    n = len(ob.data.vertices)
    e = np.empty(len(ob.data.edges) * 2, dtype=np.int32)
    ob.data.edges.foreach_get('vertices', e)
    e = e.reshape(-1, 2)
    cnt = np.bincount(e.ravel(), minlength=n).astype(np.float32)
    for _ in range(iters):
        s = np.zeros_like(W)
        for k in range(W.shape[1]):
            s[:, k] = np.bincount(e[:, 0], weights=W[e[:, 1], k], minlength=n) + np.bincount(e[:, 1], weights=W[e[:, 0], k], minlength=n)
        W = 0.5 * W + 0.5 * s / np.maximum(cnt, 1)[:, None]
    return W


def write_weights(ob, names, W, keep=4):
    top = np.argsort(-W, 1)[:, :keep]
    mask = np.zeros_like(W)
    np.put_along_axis(mask, top, 1.0, 1)
    W = W * mask
    W = W / np.maximum(W.sum(1, keepdims=True), 1e-9)
    groups = [ob.vertex_groups.new(name=nm) for nm in names]
    for k, g in enumerate(groups):
        idx = np.nonzero(W[:, k] > 0.01)[0]
        if len(idx) == 0:
            continue
        # one add() per distinct weight bucket keeps the python loop short
        wq = np.round(W[idx, k] * 200.0) / 200.0
        for v in np.unique(wq):
            g.add(idx[wq == v].tolist(), float(v), 'REPLACE')


# --- bake ---------------------------------------------------------------------------------------------

def bake(low, high, mats, prefix, size, tex_dir=None, extrude=0.02, ray=0.06, ao_samples=64):
    """UV the low, then bake albedo, roughness, metal, emission (from the HIGH's materials), normal and AO
    (high to low) into one atlas; save <prefix>_{albedo,normal,orm,emit}.png."""
    sc = bpy.context.scene
    tex_dir = tex_dir or OUT or os.path.join(ROOT, "art", "textures")
    bpy.ops.object.select_all(action='DESELECT')
    low.select_set(True)
    bpy.context.view_layer.objects.active = low
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.004)
    bpy.ops.uv.pack_islands(margin=0.004)
    bpy.ops.object.mode_set(mode='OBJECT')
    images = {}
    for key, cs in (("albedo", 'sRGB'), ("normal", 'Non-Color'), ("rough", 'Non-Color'), ("metal", 'Non-Color'), ("ao", 'Non-Color'), ("emit", 'sRGB')):
        img = bpy.data.images.new(prefix + "_" + key, size, size, alpha=False, float_buffer=False)
        img.colorspace_settings.name = cs
        images[key] = img
    # the low carries every material too, each with the target image node (the bake writes where it is active)
    for m in mats:
        if m.m.name not in [x.name for x in low.data.materials if x]:
            low.data.materials.append(m.m)
    tex_nodes = []
    for m in mats:
        t = m.nodes.new('ShaderNodeTexImage')
        t.name = "__target"
        tex_nodes.append((m, t))
    sc.cycles.samples = 1
    sc.render.bake.margin = 8
    high.hide_viewport = False
    passes = [("albedo", 'EMIT', "color"), ("rough", 'EMIT', "rough"), ("metal", 'EMIT', "metal"), ("emit", 'EMIT', "emit"),
              ("normal", 'NORMAL', None), ("ao", 'AO', None)]
    for key, kind, route in passes:
        for m, t in tex_nodes:
            t.image = images[key]
            m.nodes.active = t
            if route:
                K._route(m, route)
        sc.cycles.samples = ao_samples if kind == 'AO' else 1
        bpy.ops.object.select_all(action='DESELECT')
        high.select_set(True)
        low.select_set(True)
        bpy.context.view_layer.objects.active = low
        bpy.ops.object.bake(type=kind, use_selected_to_active=True, cage_extrusion=extrude, max_ray_distance=ray, use_clear=True, margin=8,
                            normal_space='TANGENT')
        for m, t in tex_nodes:
            if route:
                K._unroute(m)
        print("BAKED", key)
        if key == "ao":
            a_ = np.empty(size * size * 4, dtype=np.float32)
            images["ao"].pixels.foreach_get(a_)
            r_ = a_.reshape(-1, 4)[:, 0]
            g_ = np.empty(size * size * 4, dtype=np.float32)
            images["rough"].pixels.foreach_get(g_)
            cov_ = g_.reshape(-1, 4)[:, 0] > 0.05
            mean_ = float(r_[cov_].mean()) if cov_.any() else 0.0
            print("AO mean over covered texels", round(mean_, 3))
            if mean_ < 0.3:
                raise RuntimeError("AO bake is black (mean %.3f): the atlas would render as a black shape" % mean_)
    os.makedirs(tex_dir, exist_ok=True)

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


# --- export -------------------------------------------------------------------------------------------

def export_glb(low, name, sockets, extra=()):
    """One skinned mesh `body` on a flat armature (a bone per rig socket), art/models/<name>.glb."""
    arm = GK.armature(sockets)
    low.parent = arm
    md = low.modifiers.new("Armature", 'ARMATURE')
    md.object = arm
    low.name = "body"
    low.data.name = "body"
    bpy.ops.object.select_all(action='DESELECT')
    for o in [arm, low] + list(extra):
        o.select_set(True)
    path = os.path.join(OUT, name + ".glb") if OUT else os.path.join(ROOT, "art", "models", name + ".glb")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True, export_apply=True, export_yup=True,
                              export_materials='NONE', export_normals=True, export_texcoords=True, export_skins=True,
                              export_animations=False, export_all_influences=False)
    tris = sum(len(p.vertices) - 2 for p in low.data.polygons)
    print("EXPORTED", path, "tris", tris, "verts", len(low.data.vertices))
    return path


# --- previews -----------------------------------------------------------------------------------------

def shape_preview(obs, path, target, dist, views=((0, 0.15), (90, 0.15), (45, 0.35), (180, 0.15)), res=720, color=(0.62, 0.58, 0.52)):
    """Fast Workbench stills (clay, cavity shading) of the high-poly for form iteration. views: (azimuth deg
    from +X in blender space where 90 is the creature's front, elevation fraction)."""
    sc = bpy.context.scene
    old = sc.render.engine
    sc.render.engine = 'BLENDER_WORKBENCH'
    sh = sc.display.shading
    sh.light = 'STUDIO'
    sh.color_type = 'SINGLE'
    sh.single_color = color
    sh.show_cavity = True
    sh.cavity_type = 'BOTH'
    sh.show_shadows = True
    sc.display.render_aa = '8'
    sc.render.resolution_x = res
    sc.render.resolution_y = res
    sc.render.film_transparent = False
    world = bpy.data.worlds.new("PW")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.2, 0.22, 0.27, 1.0)
    sc.world = world
    tgt = Vector(K.G(*target))
    cd = bpy.data.cameras.new("PC")
    cd.lens = 55
    cam = bpy.data.objects.new("PC", cd)
    sc.collection.objects.link(cam)
    sc.camera = cam
    tr = cam.constraints.new('TRACK_TO')
    tobj = bpy.data.objects.new("PT", None)
    tobj.location = tgt
    sc.collection.objects.link(tobj)
    tr.target = tobj
    tr.track_axis = 'TRACK_NEGATIVE_Z'
    tr.up_axis = 'UP_Y'
    base, ext = os.path.splitext(path)
    for i, (ang, el) in enumerate(views):
        a = math.radians(ang)
        cam.location = (tgt.x + math.cos(a) * dist, tgt.y + math.sin(a) * dist, tgt.z + dist * el)
        sc.render.filepath = "%s_%d%s" % (base, i, ext)
        bpy.ops.render.render(write_still=True)
        print("PREVIEW", sc.render.filepath)
    bpy.data.objects.remove(cam)
    bpy.data.objects.remove(tobj)
    sc.render.engine = old
    montage(["%s_%d%s" % (base, i, ext) for i in range(len(views))], "%s_sheet%s" % (base, ext), cols=2)


def montage(paths, out, cols=2, scale=None):
    """Tile stills into one sheet (Blender's own image scaler, no PIL)."""
    ims = [bpy.data.images.load(p, check_existing=False) for p in paths]
    w, h = ims[0].size
    if scale:
        for im in ims:
            im.scale(int(w * scale), int(h * scale))
        w, h = ims[0].size
    rows = (len(ims) + cols - 1) // cols
    sheet = np.zeros((h * rows, w * cols, 4), dtype=np.float32)
    for i, im in enumerate(ims):
        a = np.empty(w * h * 4, dtype=np.float32)
        im.pixels.foreach_get(a)
        r, c = i // cols, i % cols
        sheet[(rows - 1 - r) * h:(rows - r) * h, c * w:(c + 1) * w] = a.reshape(h, w, 4)
    o = bpy.data.images.new("sheet", w * cols, h * rows, alpha=False)
    o.colorspace_settings.name = 'sRGB'
    o.pixels.foreach_set(sheet.ravel())
    o.filepath_raw = out
    o.file_format = 'PNG'
    o.save()
    print("SHEET", out)
