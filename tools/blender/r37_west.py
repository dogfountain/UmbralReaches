"""r37 West Marches landmark assets, modelled by script (no scans, no downloads):

  the Fallen Hierarch   r37_statue.glb (+ r37_statue_far.glb): a toppled colossus lying on its back, its
                        skull a hollow bowl split open round the boss's floor, a broken tiara of tines, a robed
                        torso, one sleeved arm with the hand open palm-up, rubble
  Weirford              r37_mill.glb (the mill, its wheel as its own node, the weir) and r37_bridge.glb
  the Siege Lines       r37_palisade.glb (three variants), r37_trebuchet.glb (standing / fallen),
                        r37_siege_tower.glb (a four-storey tower with its flights)

  tools/blender/run.sh r37_west.py -- [--only statue,mill,bridge,palisade,trebuchet,tower] [--preview DIR]

Conventions (Blender Z up -> Godot Y up, Blender +Y -> Godot -Z; 1 BU = 1 m). Every asset: one mesh object per
material, named <part>__<set> (the set is stone / ashlar / timber / iron: Godot dresses them with the tiling
r37_<set>_* PBR sets from r37_west_textures.py), metric box UVs (a tile is TILE[set] metres), vertex colours
baked as macro tone (moss on the tops, damp at the foot, soot), and a <asset>-colonly mesh for collision.
"""
import bpy
import bmesh
import math
import os
import sys
from mathutils import Vector, Matrix, Quaternion, noise

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
MODELS = os.path.join(ROOT, "art", "models")
BLEND = os.path.join(ROOT, "art", "blender")
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ONLY = args[args.index("--only") + 1].split(",") if "--only" in args else []
PREVIEW = args[args.index("--preview") + 1] if "--preview" in args else ""
TILE = {"stone": 6.0, "ashlar": 4.0, "timber": 2.0, "iron": 2.0}


# --- noise ----------------------------------------------------------------------------------------
def fbm(p, octaves=4, lac=2.0, gain=0.5):
    a, f, s, n = 1.0, 1.0, 0.0, 0.0
    for _ in range(octaves):
        s += a * noise.noise(p * f)
        n += a
        a *= gain
        f *= lac
    return s / n


def smoothstep(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a + 1e-9)))
    return t * t * (3 - 2 * t)


# --- scene + materials ----------------------------------------------------------------------------
def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.unit_settings.system = 'METRIC'


def make_mat(name):
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    return m


class Parts:
    """Geometry grouped by material set: one bmesh each."""

    def __init__(self):
        self.bm = {}

    def of(self, key):
        if key not in self.bm:
            self.bm[key] = bmesh.new()
        return self.bm[key]


def box(P, key, c, size, yaw=0.0, pitch=0.0, roll=0.0, bevel=0.0):
    """A box centred at c, size (x, y, z), rotated (yaw about Z, pitch about X, roll about Y)."""
    rot = Matrix.Rotation(yaw, 4, 'Z') @ Matrix.Rotation(pitch, 4, 'X') @ Matrix.Rotation(roll, 4, 'Y')
    M = Matrix.Translation(Vector(c)) @ rot @ Matrix.Diagonal((size[0], size[1], size[2], 1.0))
    bmesh.ops.create_cube(P.of(key), size=1.0, matrix=M)


def beam(P, key, a, b, w, h=None, up=Vector((0, 0, 1))):
    """A square-section beam from a to b (w across, h up, default w)."""
    a, b = Vector(a), Vector(b)
    d = b - a
    L = d.length
    if L < 1e-5:
        return
    q = d.to_track_quat('Y', 'Z')
    M = Matrix.Translation((a + b) * 0.5) @ q.to_matrix().to_4x4() @ Matrix.Diagonal((w, L, h or w, 1.0))
    bmesh.ops.create_cube(P.of(key), size=1.0, matrix=M)


def cyl(P, key, a, b, r0, r1=None, seg=10, cap=True):
    a, b = Vector(a), Vector(b)
    d = b - a
    L = d.length
    if L < 1e-5:
        return
    q = d.to_track_quat('Z', 'Y')
    M = Matrix.Translation((a + b) * 0.5) @ q.to_matrix().to_4x4()
    bmesh.ops.create_cone(P.of(key), cap_ends=cap, cap_tris=False, segments=seg, radius1=r0,
                          radius2=(r0 if r1 is None else r1), depth=L, matrix=M)


def ring_loft(P, key, rings, close_ends=True):
    """rings: list of lists of Vector (same count each), consecutive rings joined by quads."""
    bm = P.of(key)
    vr = [[bm.verts.new(p) for p in ring] for ring in rings]
    n = len(vr[0])
    for i in range(len(vr) - 1):
        for j in range(n):
            bm.faces.new((vr[i][j], vr[i][(j + 1) % n], vr[i + 1][(j + 1) % n], vr[i + 1][j]))
    if close_ends:
        for ring in (vr[0], vr[-1]):
            bm.faces.new(ring[::-1] if ring is vr[0] else ring)
    return vr


def superellipse(hx, hz_up, hz_dn, n_seg, expo=2.4):
    pts = []
    for k in range(n_seg):
        a = math.tau * k / n_seg
        c, s = math.cos(a), math.sin(a)
        u = hx * math.copysign(abs(c) ** (2.0 / expo), c)
        v = (hz_up if s >= 0 else hz_dn) * math.copysign(abs(s) ** (2.0 / expo), s)
        pts.append((u, v))
    return pts


# --- finishing: UVs, vertex colours, export ------------------------------------------------------
def tone_for(key, co, n, flat):
    """Macro tone baked into the vertex colour (multiplied on the tiling albedo)."""
    z = co.z
    damp = 1.0 - 0.45 * (1.0 - smoothstep(0.0, 3.0, z))                        # darker at the foot
    nz = max(n.z, 0.0)
    if key in ("stone", "ashlar"):
        moss_n = fbm(co * 0.21 + Vector((7, 3, 1)), 3)
        moss = smoothstep(-0.05, 0.35, moss_n) * (0.25 + 0.75 * nz) * (1.0 - smoothstep(18.0, 40.0, z) * 0.6)
        moss = moss * (0.55 + 0.45 * (1.0 - smoothstep(0.0, 4.0, z)))           # thicker low down
        v = 0.78 + 0.28 * fbm(co * 0.11 + Vector((1, 9, 4)), 3)
        r, g, b = v * damp, v * damp, v * damp
        r, g, b = r * (1 - moss) + 0.5 * moss, g * (1 - moss) + 0.78 * moss, b * (1 - moss) + 0.36 * moss
        streak = smoothstep(0.1, 0.6, fbm(Vector((co.x * 0.9, co.y * 0.9, co.z * 0.05)), 2)) * (1.0 - nz) * 0.3
        return (r * (1 - streak), g * (1 - streak), b * (1 - streak))
    if key == "timber":
        v = (0.85 + 0.2 * fbm(co * 0.5, 2)) * (0.65 + 0.35 * damp)
        rot = smoothstep(0.35, 0.75, fbm(co * 0.35 + Vector((2, 2, 2)), 2)) * 0.25
        return (v * (1 - rot * 0.4), v * (1 - rot * 0.1), v * (1 - rot * 0.5))
    return (0.9 * damp, 0.85 * damp, 0.8 * damp)


def finish(P, name, flat=True, smooth_keys=(), col_from=None, col_decimate=0.0, origin_parts=None):
    """Turn each bmesh into an object `<name>__<key>` (UVs, colours, material); returns objects."""
    objs = []
    for key, bm in P.bm.items():
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.normal_update()
        uv = bm.loops.layers.uv.new("UVMap")
        col = bm.loops.layers.color.new("Col")
        tile = TILE.get(key, 4.0)
        sm = key in smooth_keys
        for f in bm.faces:
            f.smooth = sm
            n = f.normal
            ax = max(range(3), key=lambda i: abs(n[i]))
            for l in f.loops:
                co = l.vert.co
                if ax == 0:
                    l[uv].uv = (co.y / tile, co.z / tile)
                elif ax == 1:
                    l[uv].uv = (co.x / tile, co.z / tile)
                else:
                    l[uv].uv = (co.x / tile, co.y / tile)
                nn = l.vert.normal if sm else n
                c = tone_for(key, co, nn, not sm)
                l[col] = (c[0], c[1], c[2], 1.0)
        me = bpy.data.meshes.new("%s__%s" % (name, key))
        bm.to_mesh(me)
        bm.free()
        me.materials.append(make_mat(key))
        ob = bpy.data.objects.new("%s__%s" % (name, key), me)
        bpy.context.scene.collection.objects.link(ob)
        if "Col" in me.color_attributes:
            me.color_attributes.active_color = me.color_attributes["Col"]
            me.color_attributes.render_color_index = list(me.color_attributes.keys()).index("Col")
        objs.append(ob)
    return objs


def make_collision(objs, name, ratio=1.0):
    """A joined copy of `objs` (no materials) named <name>-colonly; decimated to `ratio` of the tris."""
    copies = []
    for o in objs:
        c = o.copy()
        c.data = o.data.copy()
        c.data.materials.clear()
        bpy.context.scene.collection.objects.link(c)
        copies.append(c)
    bpy.ops.object.select_all(action='DESELECT')
    for c in copies:
        c.select_set(True)
    bpy.context.view_layer.objects.active = copies[0]
    bpy.ops.object.join()
    col = bpy.context.view_layer.objects.active
    col.name = name + "-colonly"
    col.data.name = col.name
    while col.data.color_attributes:
        col.data.color_attributes.remove(col.data.color_attributes[0])
    while col.data.uv_layers:
        col.data.uv_layers.remove(col.data.uv_layers[0])
    if ratio < 1.0:
        md = col.modifiers.new("dec", 'DECIMATE')
        md.ratio = ratio
        bpy.ops.object.modifier_apply(modifier=md.name)
    return col


def tris(o):
    me = o.data
    return sum(len(p.vertices) - 2 for p in me.polygons)


def export(objs, path, label):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    total = sum(tris(o) for o in objs if not o.name.endswith("-colonly"))
    kw = dict(filepath=path, export_format='GLB', use_selection=True, export_apply=True, export_yup=True,
              export_materials='EXPORT', export_image_format='NONE', export_normals=True, export_texcoords=True)
    try:
        bpy.ops.export_scene.gltf(export_vertex_color='ACTIVE', **kw)
    except TypeError:
        try:
            bpy.ops.export_scene.gltf(export_active_vertex_color_when_no_material=True, **kw)
        except TypeError:
            bpy.ops.export_scene.gltf(**kw)
    print("EXPORTED %s -> %s: %d tris (render), objects %s" % (label, path, total, [o.name for o in objs]))


def preview(objs, label, views, size=(960, 540)):
    """Solid-mode vertex-colour renders (Workbench) to PREVIEW/<label>_<i>.png."""
    if not PREVIEW:
        return
    os.makedirs(PREVIEW, exist_ok=True)
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_WORKBENCH'
    sc.render.resolution_x, sc.render.resolution_y = size
    sc.display.shading.color_type = 'VERTEX'
    sc.display.shading.light = 'STUDIO'
    sc.display.shading.show_cavity = True
    sc.display.shading.show_shadows = True
    sc.world = bpy.data.worlds.new("pv")
    sc.world.color = (0.18, 0.2, 0.24)
    cam_d = bpy.data.cameras.new("cam")
    cam = bpy.data.objects.new("cam", cam_d)
    bpy.context.scene.collection.objects.link(cam)
    sc.camera = cam
    cam_d.clip_end = 600
    for o in list(bpy.data.objects):
        if o.name.endswith("-colonly"):
            o.hide_render = True
    for i, (loc, target, lens) in enumerate(views):
        cam.location = Vector(loc)
        cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
        cam_d.lens = lens
        sc.render.filepath = os.path.join(PREVIEW, "%s_%d.png" % (label, i))
        bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(cam)


# ============================================================================================
# THE FALLEN HIERARCH
# ============================================================================================
# Frame: the head's centre is the origin, the crown towards -X, the neck and body towards +X, the floor of the
# bowl at z = 0 (the boss's raid floor). The gate (where the weir track arrives) lies at azimuth GATE_PHI.
HEAD_R = (27.0, 25.5, 19.0)         # outer ellipsoid radii
SHELL_T = 4.2
GATE_PHI = 0.93                      # azimuth of the arena's mouth (Blender atan2(y, x))
NECK_PHI = 0.0
FACE_DIR = Vector((0.0, 0.55, 0.83)).normalized()    # the face looks up and a little to the gate
CUT_DIR = Vector((-0.24, -0.43, 0.87)).normalized()  # the split: opens the skull on the far side
CROWN_DIR = Vector((-1.0, 0.0, 0.0))


def build_head(P):
    """The skull: an ellipsoid shell, cut open (the split), notched (the gate, the neck), carved (a face)."""
    bm = bmesh.new()
    res_u, res_v = 208, 104
    bmesh.ops.create_uvsphere(bm, u_segments=res_u, v_segments=res_v, radius=1.0)
    rx, ry, rz = HEAD_R
    side = FACE_DIR.cross(CROWN_DIR).normalized()
    crown = side.cross(FACE_DIR).normalized()                                   # the face frame
    kill = []
    for v in bm.verts:
        u = v.co.normalized()
        if u.z < 0.04:
            kill.append(v)
            continue
        phi = math.atan2(u.y, u.x)
        ang = math.acos(max(-1.0, min(1.0, u.dot(CUT_DIR))))
        jag = 0.2 * fbm(Vector((phi * 2.2, u.z * 3.0, 3.0)), 3) + 0.1 * noise.noise(Vector((phi * 9.0, u.z * 8.0, 1.0)))
        if ang < 0.74 + jag:                                                     # the split
            kill.append(v)
            continue
        h = u.z * rz
        for tgt, half, top in ((GATE_PHI, 0.3, 8.5), (NECK_PHI, 0.3, 7.5)):
            d = abs((phi - tgt + math.pi) % math.tau - math.pi)
            if d < half and h < top * (1.0 - 0.5 * (d / half) ** 2) + 2.2 * noise.noise(Vector((phi * 7, u.z * 5, 2.0))):
                kill.append(v)
                break
    bmesh.ops.delete(bm, geom=list(set(kill)), context='VERTS')
    # sculpt the outside: the carved face, drapery of the crown band, weathering, cracks
    for v in bm.verts:
        u = Vector((v.co.x, v.co.y, v.co.z)).normalized()
        r_, c_, f_ = u.dot(side), u.dot(crown), u.dot(FACE_DIR)
        push = 0.0
        if f_ > 0.25:
            def bump(r0, c0, rr, hh):
                return hh * math.exp(-(((r_ - r0) ** 2 + (c_ - c0) ** 2) / (rr * rr)))
            push += bump(0.0, -0.05, 0.11, 0.17)                 # the nose's ridge
            push += bump(0.0, 0.3, 0.17, 0.09)                 # the brow
            push += bump(0.0, 0.34, 0.5, 0.06)
            for s in (-1, 1):
                push -= bump(s * 0.29, 0.14, 0.1, 0.12)        # the closed eyes' hollows
                push += bump(s * 0.29, 0.14, 0.12, 0.02)
                push += bump(s * 0.5, -0.12, 0.19, 0.09)       # cheekbones
                push += bump(s * 0.3, -0.34, 0.1, 0.012)
            push -= 0.1 * math.exp(-(((c_ + 0.4) / 0.03) ** 2)) * math.exp(-((r_ / 0.3) ** 2))   # the mouth's line
            push += bump(0.0, -0.62, 0.16, 0.1)                # the chin
        # the crown band round the brow's far side: a ridge of lozenges
        band = math.exp(-(((c_ - 0.62) / 0.05) ** 2)) * (0.5 + 0.5 * math.sin(math.atan2(r_, f_) * 26.0))
        push += 0.018 * band
        w = fbm(v.co * 0.16, 4) * 0.012 + 0.0045 * noise.noise(v.co * 1.4)
        ridge = abs(noise.noise(v.co * 0.07 + Vector((5, 5, 5))))
        crack = (1.0 - smoothstep(0.0, 0.03, ridge)) * 0.012
        p = (1.0 + push + w - crack)
        v.co = Vector((u.x * rx * p, u.y * ry * p, u.z * rz * p))
    bm.normal_update()
    # the inside surface, offset in along the normals; the rim joined between
    inner = {}
    for v in bm.verts:
        t = SHELL_T * (0.8 + 0.4 * (0.5 + 0.5 * fbm(v.co * 0.08, 2)))
        n = v.normal
        inner[v] = bm.verts.new(v.co - n * t + n * 0.0)
    faces = list(bm.faces)
    for f in faces:
        bm.faces.new([inner[v] for v in f.verts][::-1])
    for e in list(bm.edges):
        if len(e.link_faces) == 1 and e.verts[0] in inner and e.verts[1] in inner:
            a, b = e.verts
            try:
                bm.faces.new((a, b, inner[b], inner[a]))
            except ValueError:
                pass
    # chisel the inside: carved panels and the damage of the fall
    for v in inner.values():
        v.co += (Vector((0, 0, 0)) - v.co).normalized() * 0.5 * fbm(v.co * 0.2, 3)
    out = P.of("stone")
    # copy into the part bmesh
    idx = {}
    for v in bm.verts:
        idx[v] = out.verts.new(v.co)
    for f in bm.faces:
        try:
            out.faces.new([idx[v] for v in f.verts])
        except ValueError:
            pass
    bm.free()
    return out


def build_tines(P, rng_seed=5):
    """The broken tiara: tines along the high edge of the split, leaning out, several snapped."""
    import random
    rnd = random.Random(rng_seed)
    side = FACE_DIR.cross(CROWN_DIR).normalized()
    # a ring of seats on the outside of the shell round the crown's side, between the split and the face
    n = 15
    for i in range(n):
        a = math.tau * i / n
        # a circle on the unit sphere about CROWN_DIR*0.35 + UP*0.5 : the band the tiara sat on
        axis = (CROWN_DIR * 0.6 + Vector((0, 0, 0.8))).normalized()
        t1 = axis.cross(Vector((0, 1, 0))).normalized()
        t2 = axis.cross(t1).normalized()
        u = (axis * math.cos(0.62) + (t1 * math.cos(a) + t2 * math.sin(a)) * math.sin(0.62)).normalized()
        if u.z < 0.25:
            continue
        # skip seats inside the split
        if math.acos(max(-1, min(1, u.dot(CUT_DIR)))) < 0.9:
            continue
        base = Vector((u.x * HEAD_R[0], u.y * HEAD_R[1], u.z * HEAD_R[2])) * 0.985
        nrm = Vector((u.x / HEAD_R[0], u.y / HEAD_R[1], u.z / HEAD_R[2])).normalized()
        h = rnd.uniform(7.0, 12.0)
        broken = rnd.random() < 0.4
        if broken:
            h *= rnd.uniform(0.25, 0.5)
        lean = (nrm * 0.6 + Vector((rnd.uniform(-0.3, 0.3), rnd.uniform(-0.3, 0.3), 0.7))).normalized()
        tip = base + lean * h
        w = rnd.uniform(1.6, 2.4)
        beam(P, "stone", base - nrm * 0.8, tip, w, w * 0.8)
        # a tapered upper half
        if not broken:
            mid = base + lean * h * 0.55
            beam(P, "stone", mid, tip + lean * 1.2, w * 0.55, w * 0.45)
            if rnd.random() < 0.5:
                box(P, "stone", tip + lean * 1.4, (0.7, 0.7, 0.7), yaw=rnd.random() * 3, pitch=0.5)


def build_torso(P):
    """Robe and shoulders: x 22..56, the break at the waist; drapery ridges along its length."""
    segs = 96
    ring_n = 80
    rings = []
    for i in range(segs + 1):
        t = i / segs
        x = 24.5 + 31.5 * t
        # shoulders wide at x ~ 36, narrowing to the waist
        w = 9.0 + 6.0 * math.exp(-(((x - 35.0) / 9.0) ** 2)) + 2.0 * (1 - t)
        if x < 29.0:
            w = 9.5 + 3.5 * smoothstep(24.5, 29.0, x)                    # the neck
        hz = 5.4 + 1.8 * math.exp(-(((x - 36.0) / 10.0) ** 2))
        if x < 29.0:
            hz = 4.4 + 1.6 * smoothstep(24.5, 29.0, x)
        pts = superellipse(w, hz, 9.0, ring_n, 2.5)
        ring = []
        for k, (u, v) in enumerate(pts):
            a = math.tau * k / ring_n
            fold = 0.55 * math.sin(a * 11.0 + x * 0.35 + 1.3 * noise.noise(Vector((x * 0.08, a, 1.0)))) * (v > -1.0)
            fold += 0.3 * noise.noise(Vector((x * 0.3, a * 2.0, 0.0)))
            r = 1.0 + 0.018 * fold + 0.02 * fbm(Vector((x * 0.12, u * 0.12, v * 0.12)), 3)
            ring.append(Vector((x, u * r, v * r + (1.0 if v > 0 else 0.0))))
        rings.append(ring)
    # the waist's break: the last ring ragged, dropped, and a rough plug behind it
    last = rings[-1]
    for k, p in enumerate(last):
        p.x += 1.8 * noise.noise(Vector((k * 0.4, 1.0, 3.0)))
    ring_loft(P, "stone", rings, close_ends=True)
    # neck: the collar (a stone torus of folds) where it meets the head's chin
    for k in range(18):
        a = math.tau * k / 18
        box(P, "stone", (24.0, math.cos(a) * 9.0, 5.0 + math.sin(a) * 4.2 * (1 if math.sin(a) > 0 else 0.2)),
            (2.6, 2.4, 2.4), yaw=a, pitch=0.3 * math.sin(a * 3))


def sleeve(P, pts, radii, ring_n=44, squash=0.72, floor=-8.0):
    rings = []
    n = len(pts)
    for i, p in enumerate(pts):
        t = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()
        side = t.cross(Vector((0, 0, 1))).normalized()
        up = side.cross(t).normalized()
        r = radii[i]
        ring = []
        for k in range(ring_n):
            a = math.tau * k / ring_n
            c, s = math.cos(a), math.sin(a)
            du = r * math.copysign(abs(c) ** 0.85, c)
            dv = (r * squash * math.copysign(abs(s) ** 0.85, s)) if s >= 0 else (r * 1.5 * math.copysign(abs(s) ** 0.85, s))
            fold = 0.04 * r * math.sin(a * 7 + i * 0.5)
            q = p + side * (du + fold) + up * (dv + fold)
            q.z = max(q.z, floor + 4.0 + 4.0 * 0.0)
            ring.append(q)
        rings.append(ring)
    ring_loft(P, "stone", rings, close_ends=True)


def build_arm(P):
    S = Vector((36.0, -11.5, 5.0))
    E = Vector((47.0, -22.0, 2.8))
    W = Vector((40.5, -33.5, 1.9))
    pts = []
    for i in range(30):
        t = i / 29.0
        a = S.lerp(E, t)
        pts.append(a + Vector((0, 0, 1.2 * math.sin(t * math.pi))))
    for i in range(1, 26):
        t = i / 25.0
        pts.append(E.lerp(W, t))
    radii = [3.4 - 0.5 * (i / 29.0) for i in range(30)] + [2.9 - 0.5 * (i / 25.0) + 0.5 * smoothstep(0.7, 1.0, i / 25.0) for i in range(1, 26)]
    sleeve(P, pts, radii)
    # the hand: palm up, fingers curled a little, thumb out
    H = Vector((38.0, -37.5, 1.2))                            # the palm's centre
    box(P, "stone", H + Vector((0, 0, 0.6)), (6.6, 7.4, 3.0))                                  # the palm (its top about z 2.7)
    box(P, "stone", H + Vector((0.0, 3.0, 1.1)), (5.8, 1.6, 0.9), pitch=0.1)                  # the heel's pad
    for f in range(4):
        fx = -2.4 + 1.6 * f
        length = (6.2, 7.0, 6.6, 5.2)[f]
        prev = H + Vector((fx, -3.6, 1.6))
        d = Vector((0.1 * (f - 1.5), -1.0, 0.0)).normalized()
        for seg in range(3):
            ln = length / 3.0 * (1.0 - 0.1 * seg)
            curl = 0.12 + 0.26 * seg
            nxt = prev + Vector((d.x * ln, d.y * ln, math.sin(curl) * ln * 0.9))
            beam(P, "stone", prev, nxt, 1.35 - 0.12 * seg, 1.15 - 0.1 * seg)
            prev = nxt
    # the thumb
    t0 = H + Vector((-3.2, -1.6, 1.6))
    t1 = t0 + Vector((-2.2, -2.8, 0.7))
    t2 = t1 + Vector((-0.6, -2.4, 1.2))
    beam(P, "stone", t0, t1, 1.5, 1.3)
    beam(P, "stone", t1, t2, 1.3, 1.1)
    # a ring on the third finger, worn and cracked: a thin torus of stone blocks
    for k in range(10):
        a = math.tau * k / 10
        box(P, "stone", H + Vector((-0.8 + 0.0, -6.0, 2.7 + 0.0)) + Vector((math.cos(a) * 0.75, 0.0, math.sin(a) * 0.75)), (0.45, 0.5, 0.45), pitch=a)
    return H


def build_debris(P, seed=8):
    import random
    rnd = random.Random(seed)
    spots = [(-44, 12), (-40, -22), (-18, -40), (14, -38), (30, 30), (-10, 38), (-48, -4), (8, 40), (-30, 36), (52, 10), (56, -14), (22, -48),
             (50, 24), (-24, -36), (62, -4)]
    for (x, y) in spots:
        s = rnd.uniform(1.8, 5.0)
        for part in range(rnd.randint(1, 3)):
            ox, oy = rnd.uniform(-2, 2), rnd.uniform(-2, 2)
            box(P, "stone", (x + ox, y + oy, s * 0.3), (s * rnd.uniform(0.8, 1.6), s * rnd.uniform(0.7, 1.4), s * rnd.uniform(0.5, 1.0)),
                yaw=rnd.random() * 6.28, pitch=rnd.uniform(-0.3, 0.3), roll=rnd.uniform(-0.3, 0.3))


def asset_statue():
    reset()
    P_head, P_body, P_deb = Parts(), Parts(), Parts()
    build_head(P_head)
    build_tines(P_head)
    build_torso(P_body)
    hand = build_arm(P_body)
    build_debris(P_deb)
    head = finish(P_head, "StatueHead", smooth_keys=("stone",))
    body = finish(P_body, "StatueBody", smooth_keys=("stone",))
    deb = finish(P_deb, "StatueDebris", smooth_keys=())
    col_h = make_collision(head, "StatueHead", 0.2)
    col_b = make_collision(body, "StatueBody", 0.2)
    col_d = make_collision(deb, "StatueDebris", 1.0)
    allo = head + body + deb + [col_h, col_b, col_d]
    for o in allo:
        pass
    export(allo, os.path.join(MODELS, "r37_statue.glb"), "statue")
    print("STATUE hand centre (model, Blender coords)", tuple(hand))
    preview(head + body + deb, "statue", [((-95, -80, 55), (5, 5, 5), 24), ((70, 90, 60), (10, -10, 5), 28),
                                         ((0, 0, 120), (20, -10, 0), 40), ((30, -75, 20), (38, -37, 2), 34),
                                         ((-30, 55, 22), (0, 0, 8), 28)])
    # the far mesh: a few thousand triangles, the whole silhouette
    far = []
    for o in head + body + deb:
        c = o.copy()
        c.data = o.data.copy()
        bpy.context.scene.collection.objects.link(c)
        c.name = c.name.replace("Statue", "StatueFar")
        c.data.name = c.name
        far.append(c)
    for c in far:
        md = c.modifiers.new("dec", 'DECIMATE')
        md.ratio = 0.035 if "Debris" not in c.name else 0.5
        bpy.context.view_layer.objects.active = c
        bpy.ops.object.modifier_apply(modifier=md.name)
    export(far, os.path.join(MODELS, "r37_statue_far.glb"), "statue far")
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(BLEND, "r37_statue.blend"))


# ============================================================================================
# WEIRFORD: the mill, the weir, the bridge
# ============================================================================================
def asset_mill():
    reset()
    P = Parts()
    W = Parts()                           # the wheel, its own node (turns about its axle)
    # model frame: z 0 = the bank, the mill's footprint x -19..-10, y -3.6..3.6; the weir runs along X
    # (the river across it, flow towards -Y), its crest at z 0.2, the wheel at x -8.2 on the mill's east wall
    # --- the mill: a dressed stone ground floor, a timbered upper floor, a steep plank roof
    box(P, "ashlar", (-14.5, 0, 1.7), (9.0, 7.2, 3.4))
    for k in range(8):                                                   # quoins
        box(P, "ashlar", (-19.0 + (k % 2) * 9.0, -3.6 + (k // 2 % 2) * 7.2, 0.5 + 0.7 * (k // 4) * 2.0), (0.7, 0.7, 0.45))
    box(P, "timber", (-14.5, 0, 4.9), (9.6, 7.8, 3.0))
    for x in (-18.4, -14.5, -10.6):
        box(P, "timber", (x, 0, 4.9), (0.28, 8.0, 3.1))                  # the frame's studs
    for y in (-3.8, 3.8):
        box(P, "timber", (-14.5, y, 6.3), (9.8, 0.28, 0.28))
        box(P, "timber", (-14.5, y, 3.5), (9.8, 0.28, 0.28))
    # roof (ridge along X): two slabs, a ridge beam, gable boards
    pitch = math.radians(40)
    for s in (-1, 1):
        box(P, "timber", (-14.5, s * 2.75, 8.1), (10.8, 5.6, 0.25), pitch=-s * pitch)
    box(P, "timber", (-14.5, 0, 9.85), (11.0, 0.45, 0.45))
    for x in (-19.9, -9.1):
        box(P, "timber", (x, 0, 7.6), (0.3, 7.5, 2.6))
    # chimney of stone
    box(P, "ashlar", (-17.5, -1.8, 8.5), (1.3, 1.3, 4.0))
    # doors and a hoist: a beam out of the north gable with a pulley
    box(P, "timber", (-14.5, -3.85, 1.2), (1.7, 0.2, 2.3))
    beam(P, "timber", (-14.5, -3.0, 7.6), (-14.5, -6.4, 7.6), 0.35)
    beam(P, "timber", (-14.5, -5.4, 7.6), (-14.5, -3.2, 6.0), 0.2)
    cyl(P, "iron", (-14.7, -6.2, 7.0), (-14.3, -6.2, 7.0), 0.25, seg=8)
    # shutters
    for (x, y) in ((-17.0, 3.9), (-12.0, 3.9), (-17.0, -3.9), (-12.0, -3.9)):
        box(P, "timber", (x, y, 5.0), (1.1, 0.12, 1.3))
    # sluice flume: a trough on trestles from the weir's pond over the wheel's top
    for k in range(4):
        x = -8.0 + 0.0
        beam(P, "timber", (-8.2, 3.2 + 1.7 * k, 0.0), (-8.2, 3.2 + 1.7 * k, 4.6 - 0.1 * k), 0.3)
    box(P, "timber", (-8.2, 6.6, 4.9), (1.6, 7.6, 0.2))
    for s in (-1, 1):
        box(P, "timber", (-8.2 + s * 0.8, 6.6, 5.35), (0.15, 7.6, 0.75))
    # the wheel's housing: the race below, stone walls
    for s in (-1, 1):
        box(P, "ashlar", (-8.2, s * 1.0, 0.7), (0.5, 0.6, 1.4)) if False else None
    box(P, "ashlar", (-8.2, -2.2, -0.6), (4.6, 0.8, 2.6))
    box(P, "ashlar", (-8.2, 2.2, -0.6), (4.6, 0.8, 2.6))
    # the weir: a stone spillway across the river (x -8 .. 8), a timber apron, wing walls
    box(P, "ashlar", (0.0, 0.0, -0.9), (17.0, 3.6, 2.2))
    box(P, "ashlar", (0.0, 0.2, 0.05), (17.0, 1.2, 0.25), pitch=0.0)
    box(P, "ashlar", (0.0, -2.6, -1.5), (17.0, 2.4, 1.0))
    for k in range(9):
        beam(P, "timber", (-8 + 2 * k, 1.9, -0.2), (-8 + 2 * k, 1.9, 1.6), 0.3)       # the stop-log posts
    box(P, "ashlar", (-9.4, 0, 0.6), (2.0, 5.0, 2.6))
    box(P, "ashlar", (9.4, 0, 0.6), (2.0, 5.0, 2.6))
    # wheel: rim rings, spokes, buckets (an overshot wheel, 6.4 m across, 1.5 m wide), axle along Y
    R = 3.2
    c = Vector((-8.2, 0.0, 3.4))
    for yy in (-0.7, 0.7):
        for k in range(24):
            a0, a1 = math.tau * k / 24, math.tau * (k + 1) / 24
            p0 = c + Vector((math.cos(a0) * R, yy, math.sin(a0) * R))
            p1 = c + Vector((math.cos(a1) * R, yy, math.sin(a1) * R))
            beam(W, "timber", p0, p1, 0.22, 0.34)
        for k in range(8):
            a = math.tau * k / 8 + 0.2
            beam(W, "timber", c + Vector((0, yy, 0)), c + Vector((math.cos(a) * R, yy, math.sin(a) * R)), 0.2, 0.2)
    for k in range(24):
        a = math.tau * (k + 0.5) / 24
        bpos = c + Vector((math.cos(a) * (R - 0.1), 0, math.sin(a) * (R - 0.1)))
        box(W, "timber", bpos, (0.12, 1.45, 0.7), pitch=0.0, yaw=0.0) if False else None
        beam(W, "timber", c + Vector((math.cos(a) * (R - 0.55), 0, math.sin(a) * (R - 0.55))), c + Vector((math.cos(a + 0.25) * R, 0, math.sin(a + 0.25) * R)), 1.45, 0.07)
    cyl(W, "iron", c + Vector((0, -1.4, 0)), c + Vector((0, 1.4, 0)), 0.3, seg=12)
    cyl(W, "timber", c + Vector((0, -0.6, 0)), c + Vector((0, 0.6, 0)), 0.6, seg=12)
    bpy.ops.object.select_all(action='DESELECT')
    mill = finish(P, "Mill")
    wheel = finish(W, "Wheel")
    # the wheel's origin on its axle (so it turns about it)
    for o in wheel:
        o.data.transform(Matrix.Translation(-c))
        o.location = c
    col = make_collision(mill, "Mill", 1.0)
    export(mill + wheel + [col], os.path.join(MODELS, "r37_mill.glb"), "mill")
    preview(mill + wheel, "mill", [((-30, -24, 14), (-11, 0, 3), 32), ((-4, 24, 12), (-12, 0, 3), 30)])


def asset_bridge():
    reset()
    P = Parts()
    # model frame: along X, x -14..14; the deck's top at z 0, 4.4 m wide (y -2.2..2.2); two arches (centres +-6.3,
    # span 11.2) meeting on a pier at 0; the springline at z -4.6, the arch crowns at about -1.0
    span, rise, Z0, T = 11.2, 3.6, -4.6, 1.0
    cxs = (-6.3, 6.3)
    for cx in cxs:
        n = 15
        for k in range(n):
            am = math.pi * (k + 0.5) / n
            r_in, r_out = span / 2, span / 2 + T
            m_in = Vector((cx - math.cos(am) * r_in, 0, Z0 + math.sin(am) * rise))
            m_out = Vector((cx - math.cos(am) * r_out, 0, Z0 + math.sin(am) * (rise + T * rise / (span / 2))))
            d = m_out - m_in
            ang = math.atan2(d.z, d.x)
            M = Matrix.Translation((m_in + m_out) * 0.5) @ Matrix.Rotation(-ang, 4, 'Y') @ Matrix.Diagonal((d.length * 1.04, 4.4, 1.25, 1.0))
            bmesh.ops.create_cube(P.of("ashlar"), size=1.0, matrix=M)
    # spandrel fill in columns, from the arch's outer ring up to the deck's underside; solid at the pier and abutments
    xi = -13.6
    while xi < 13.6:
        zb = -7.0
        for cx in cxs:
            dx = abs(xi - cx)
            ro = span / 2 + T
            if dx < ro:
                zb = max(zb, Z0 + (rise + T * rise / (span / 2)) * math.sqrt(max(0.0, 1.0 - (dx / ro) ** 2)))
        if zb < -0.4:
            box(P, "ashlar", (xi, 0.0, (zb - 0.4) * 0.5), (0.72, 4.4, -0.4 - zb))
        xi += 0.7
    box(P, "ashlar", (0.0, 0.0, -0.2), (28.0, 4.4, 0.4))                    # the deck's stones
    for s in (-1, 1):
        box(P, "ashlar", (0.0, s * 2.0, 0.55), (28.0, 0.5, 0.95))            # parapets
        box(P, "ashlar", (0.0, s * 2.0, 1.1), (28.2, 0.7, 0.18))             # coping
    for s in (-1, 1):
        box(P, "ashlar", (0.0, s * 2.2, -5.0), (2.6, 1.0, 5.0))              # the pier's cutwaters
    box(P, "ashlar", (0.0, 0.0, -5.0), (2.2, 4.0, 5.0))
    for k in range(5):                                                       # a few coping stones fallen onto the deck
        box(P, "ashlar", (-9.0 + 4.6 * k, 1.5 - 0.5 * (k % 2), 0.15), (0.6, 0.5, 0.3), yaw=k)
    for s in (-1, 1):
        cyl(P, "iron", (s * 12.6, -2.2, 1.2), (s * 12.6, -2.2, 3.0), 0.07, seg=6)
        beam(P, "iron", (s * 12.6, -2.2, 3.0), (s * 12.6, -1.6, 3.1), 0.06)
    bridge = finish(P, "Bridge")
    PC = Parts()
    box(PC, "ashlar", (0.0, 0.0, -0.45), (28.0, 4.4, 0.9))
    for s in (-1, 1):
        box(PC, "ashlar", (0.0, s * 2.0, 0.7), (28.0, 0.5, 1.4))
    box(PC, "ashlar", (0.0, 0.0, -5.0), (2.2, 4.0, 5.0))
    colo = finish(PC, "BridgeCol")
    for o in colo:
        o.name = "Bridge-colonly"
        o.data.name = o.name
        o.data.materials.clear()
    export(bridge + colo, os.path.join(MODELS, "r37_bridge.glb"), "bridge")
    preview(bridge, "bridge", [((-24, -16, 6), (0, 0, -3), 34), ((20, 14, -2), (0, 0, -3), 34)])


# ============================================================================================
# THE SIEGE LINES
# ============================================================================================
def palisade_run(P, x0, broken=0, lean=0.0, rnd=None):
    """A 4.2 m run of sharpened logs on two rails."""
    n = 9
    for k in range(n):
        x = x0 + (k + 0.5) * 4.2 / n
        h = 3.5 + 0.35 * noise.noise(Vector((x * 3.1, 1.0, 0)))
        r = 0.2 + 0.03 * noise.noise(Vector((x * 5, 2.0, 0)))
        if broken and k in (broken, broken + 1, broken + 4):
            h *= 0.32 if k != broken + 4 else 0.0
        if h <= 0.01:
            continue
        top = Vector((x + lean * h, 0.0, h))
        cyl(P, "timber", (x, 0.0, -0.4), top - Vector((lean * 0.2, 0, 0.9)), r, r * 0.95, seg=8)
        if h > 1.5:
            cyl(P, "timber", top - Vector((lean * 0.2, 0, 0.9)), top + Vector((0, 0, 0.3)), r * 0.95, r * 0.12, seg=8)
    for z in (1.0, 2.4):
        beam(P, "timber", (x0, 0.28, z), (x0 + 4.2, 0.28, z + 0.05), 0.14, 0.2)
        cyl(P, "iron", (x0 + 0.3, 0.38, z), (x0 + 0.3, 0.36, z), 0.05, seg=6)


def asset_palisade():
    reset()
    outs = []
    # variant A: whole; B: broken and leaning; C: down, logs on the ground; D: the gate-tower
    P = Parts()
    palisade_run(P, -2.1)
    v = finish(P, "PalA")
    outs += v + [make_collision(v, "PalA")]
    P = Parts()
    palisade_run(P, -2.1, broken=2, lean=0.09)
    v = finish(P, "PalB")
    outs += v + [make_collision(v, "PalB")]
    P = Parts()
    import random
    rnd = random.Random(3)
    for k in range(9):
        x = -2.0 + 0.47 * k
        if k in (1, 2, 6):
            cyl(P, "timber", (x, 0, -0.4), (x + 0.1, 0, 3.2), 0.2, 0.18, seg=8)
        else:
            cyl(P, "timber", (x - 0.6, 0.4 + rnd.uniform(-0.3, 1.4), 0.2), (x + 1.2, 1.4 + rnd.uniform(-0.2, 1.0), 0.28), 0.2, 0.19, seg=8)
    beam(P, "timber", (-2.1, 0.28, 1.0), (0.4, 0.28, 0.1), 0.14, 0.2)
    v = finish(P, "PalC")
    outs += v + [make_collision(v, "PalC")]
    P = Parts()
    # the gate: two tower posts, a walk across at 3.6 m, a hanging door leaf, the stair up
    for sx in (-3.2, 3.2):
        for sy in (-0.9, 0.9):
            cyl(P, "timber", (sx, sy, -0.5), (sx, sy, 5.4), 0.28, 0.24, seg=8)
        beam(P, "timber", (sx, -0.9, 3.6), (sx, 0.9, 3.6), 0.25)
        beam(P, "timber", (sx, -0.9, 5.2), (sx, 0.9, 5.2), 0.25)
    box(P, "timber", (0.0, 0.0, 3.75), (7.4, 2.2, 0.22))
    for k in range(9):
        x = -3.2 + 0.8 * k
        cyl(P, "timber", (x, -0.95, 3.8), (x, -0.95, 4.9), 0.14, 0.1, seg=6)
    beam(P, "timber", (-3.4, -1.0, 4.9), (3.4, -1.0, 4.9), 0.16, 0.2)
    box(P, "timber", (2.2, -0.1, 1.6), (0.18, 1.8, 3.0), yaw=0.0, roll=0.22)        # a door leaf, hanging by one hinge
    for k in range(10):                                                              # the stair up the east post
        box(P, "timber", (3.9 + 0.0, -1.7 + 0.0, 0.18 * k + 0.1), (1.0, 0.4, 0.14)) if False else None
        box(P, "timber", (3.2 + 0.65, 1.55 - 0.0 * k, 0.37 * k + 0.2), (0.6, 0.9, 0.12))
    for z in (3.4, 5.1):
        beam(P, "timber", (-3.4, 0.0, z), (3.4, 0.0, z + 0.1), 0.16, 0.2)
    v = finish(P, "PalGate")
    outs += v + [make_collision(v, "PalGate")]
    # variants sit apart in the file: A at 0, B at +8, C at +16, gate at +26 (Godot picks them by name and recentres)
    for o in outs:
        if o.name.startswith("PalB"):
            o.location.x = 8
        elif o.name.startswith("PalC"):
            o.location.x = 16
        elif o.name.startswith("PalGate"):
            o.location.x = 26
    export(outs, os.path.join(MODELS, "r37_palisade.glb"), "palisade")
    preview([o for o in outs if not o.name.endswith("-colonly")], "palisade", [((12, -14, 5), (13, 0, 2.5), 30)])


def trebuchet(P, fallen):
    """A counterweight trebuchet, about 13 m to the axle's top. Rotted: gaps, a snapped arm, a loose counterweight."""
    # base frame: two long sills with cross-members
    for s in (-1, 1):
        beam(P, "timber", (-5.5, s * 2.2, 0.35), (5.5, s * 2.2, 0.35), 0.5, 0.6)
    for x in (-5.0, -1.6, 1.6, 5.0):
        beam(P, "timber", (x, -2.2, 0.35), (x, 2.2, 0.35), 0.4, 0.5)
    # A-frame towers (leaning): two uprights each side meeting at the axle block (z ~ 9.5)
    for s in (-1, 1):
        for sx in (-2.4, 2.4):
            beam(P, "timber", (sx, s * 2.2, 0.5), (0.0, s * 1.5, 9.6), 0.5, 0.55)
        beam(P, "timber", (-1.9, s * 2.0, 2.5), (1.9, s * 2.0, 2.5), 0.3)
        beam(P, "timber", (-1.3, s * 1.8, 5.2), (1.3, s * 1.8, 5.2), 0.28)
        box(P, "timber", (0, s * 1.5, 9.7), (0.8, 0.6, 0.7))
    cyl(P, "iron", (0, -2.2, 9.7), (0, 2.2, 9.7), 0.22, seg=10)                       # the axle
    # the arm: long end (sling side) -X, short end (counterweight) +X, pivoting at the axle
    if not fallen:
        tilt = math.radians(-12)
        a_long = Vector((-9.0, 0, 9.7 - 5.0))
        a_short = Vector((3.0, 0, 9.7 + 1.8))
        beam(P, "timber", a_long, Vector((0, 0, 9.7)), 0.55, 0.7)
        beam(P, "timber", Vector((0, 0, 9.7)), a_short, 0.7, 0.8)
        # the counterweight box, hung askew and half empty (a few stones visible)
        cw = a_short + Vector((0.2, 0, -1.3))
        box(P, "timber", cw, (2.4, 2.8, 2.2), roll=0.25)
        for k in range(5):
            box(P, "ashlar", cw + Vector((-0.4 + 0.2 * k, 0.8 - 0.5 * k, 0.5)), (0.9, 0.8, 0.7), yaw=k)
        # the sling's ropes and a stone's cradle trailing from the long end
        for k in range(6):
            beam(P, "timber", a_long + Vector((-0.2 * k, 0.0, -0.5 * k)), a_long + Vector((-0.2 * (k + 1), 0.0, -0.5 * (k + 1))), 0.07)
        box(P, "timber", a_long + Vector((-1.4, 0, -3.3)), (1.0, 0.9, 0.4))
    else:
        # the arm snapped and fallen across the frame; the counterweight box on the ground
        beam(P, "timber", Vector((-12.0, -3.5, 0.5)), Vector((0.0, 0.8, 4.6)), 0.55, 0.7)
        beam(P, "timber", Vector((0.0, 0.8, 4.6)), Vector((2.6, 1.6, 6.8)), 0.7, 0.8)
        box(P, "timber", (6.5, -4.5, 1.2), (2.4, 2.8, 2.2), yaw=0.8)
        for k in range(6):
            box(P, "ashlar", (5.0 + 1.1 * k % 4, -2.5 - 0.9 * k, 0.4), (0.9, 0.8, 0.7), yaw=k * 1.1)
    # wheels (treadwheel remains) at the foot, iron tires
    for s in (-1, 1):
        cyl(P, "timber", (-6.5, s * 2.9, 1.0), (-6.5, s * 3.3, 1.0), 0.95, seg=12)
        cyl(P, "iron", (-6.5, s * 2.8, 1.0), (-6.5, s * 3.0, 1.0), 1.02, 0.98, seg=12)


def asset_trebuchet():
    reset()
    outs = []
    P = Parts()
    trebuchet(P, False)
    v = finish(P, "TrebA")
    outs += v + [make_collision(v, "TrebA")]
    P = Parts()
    trebuchet(P, True)
    v = finish(P, "TrebB")
    outs += v + [make_collision(v, "TrebB")]
    for o in outs:
        if o.name.startswith("TrebB"):
            o.location.x = 30
    export(outs, os.path.join(MODELS, "r37_trebuchet.glb"), "trebuchet")
    preview([o for o in outs if not o.name.endswith("-colonly")], "trebuchet", [((-22, -20, 9), (0, 0, 5), 32), ((12, -18, 8), (30, 0, 3), 32)])


def asset_tower():
    reset()
    P = Parts()
    # a four-storey siege tower on wheels, 6 x 6 m, 15.5 m to the platform; the near (+Y) face open, a switchback of
    # stairs up the inside (steps 0.28 high, 0.34 deep, 1.2 wide); floors at 3.6, 7.2, 10.8, platform 14.4
    H = 14.4
    for sx in (-3.0, 3.0):
        for sy in (-3.0, 3.0):
            beam(P, "timber", (sx, sy, 0.3), (sx * 0.86, sy * 0.86, H + 1.2), 0.5, 0.5)
    for z in (1.4, 3.6, 7.2, 10.8, 14.4):
        zi = z
        k = 1.0 - 0.14 * (z / H)
        for s in (-1, 1):
            beam(P, "timber", (-3.0 * k, s * 3.0 * k, zi), (3.0 * k, s * 3.0 * k, zi), 0.36, 0.4)
            beam(P, "timber", (s * 3.0 * k, -3.0 * k, zi), (s * 3.0 * k, 3.0 * k, zi), 0.36, 0.4)
    # cross-bracing on three faces, rotted: some bays open
    for (a, b) in (((-3.0, -3.0, 0.4), (3.0, -3.0, 3.6)), ((3.0, -3.0, 3.6), (-3.0, -3.0, 7.2)), ((-3.0, -3.0, 7.2), (3.0, -3.0, 10.8)),
                   ((-3.0, 3.0, 0.4), (-3.0, -3.0, 3.6)), ((-3.0, -3.0, 3.6), (-3.0, 3.0, 7.2)), ((3.0, 3.0, 3.6), (3.0, -3.0, 7.2)),
                   ((3.0, -3.0, 7.2), (3.0, 3.0, 10.8))):
        beam(P, "timber", a, b, 0.26, 0.3)
    # plank skin on the back and sides, with holes
    for z0 in (0.4, 3.6, 7.2, 10.8):
        k = 1.0 - 0.14 * ((z0 + 1.8) / H)
        box(P, "timber", (0.0, -3.05 * k, z0 + 1.8), (6.1 * k, 0.18, 3.4))
        if z0 != 3.6:
            box(P, "timber", (-3.05 * k, 0.0, z0 + 1.8), (0.18, 6.1 * k, 3.4))
        if z0 != 7.2:
            box(P, "timber", (3.05 * k, 0.0, z0 + 1.8), (0.18, 6.1 * k, 3.4))
    # floors (planks); each has a stair-shaft slot, 1.5 m wide along the wall where the flight below arrives
    for i, z in enumerate((3.6, 7.2, 10.8, 14.4)):
        k = 1.0 - 0.14 * (z / H)
        w = 6.0 * k + (0.6 if i == 3 else 0.0)
        gap = 1.5
        sgn = 1 if i % 2 == 0 else -1
        box(P, "timber", (-sgn * gap * 0.5, 0.0, z), (w - gap, w, 0.2))
    # stair flights: rising 3.6 m in 13 steps (0.277 rise, 0.4 run, 1.3 wide) along the shaft; they alternate ends
    for i, z0 in enumerate((0.0, 3.6, 7.2, 10.8)):
        k = 1.0 - 0.14 * (z0 / H)
        w = 6.0 * k
        sgn = 1 if i % 2 == 0 else -1
        up = 1 if i % 2 == 0 else -1                       # even flights climb towards +y, odd towards -y
        n = 13
        xc = sgn * (w * 0.5 - 0.75)
        for s in range(n):
            y = up * (-2.6 * k + 5.2 * k * (s / n))
            box(P, "timber", (xc, y + up * 0.2, z0 + 0.277 * (s + 1) - 0.12), (1.3, 0.42, 0.22))
        for e in (-1, 1):
            beam(P, "timber", (xc + e * 0.65, up * -2.6 * k, z0 - 0.2), (xc + e * 0.65, up * 2.6 * k, z0 + 3.5), 0.12, 0.22)
        box(P, "timber", (xc, up * 3.0 * k, z0 + 3.5), (1.4, 0.9, 0.2))
    # the top platform's parapet (partly gone) and a ram's beam hanging below the first floor
    for s in (-1, 1):
        for k in range(5):
            if (k + (s > 0)) % 3 == 0:
                continue
            beam(P, "timber", (-2.7 + 1.35 * k, s * 3.0 * 0.86, 14.5), (-2.7 + 1.35 * k, s * 3.0 * 0.86, 15.5), 0.18)
        beam(P, "timber", (-2.9, s * 2.6, 15.45), (2.9, s * 2.6, 15.45), 0.2, 0.18)
    # wheels
    for sx in (-3.2, 3.2):
        for sy in (-2.6, 2.6):
            cyl(P, "timber", (sx - 0.18, sy, 0.7), (sx + 0.18, sy, 0.7), 0.85, seg=14)
            cyl(P, "iron", (sx - 0.12, sy, 0.7), (sx + 0.12, sy, 0.7), 0.92, 0.9, seg=14)
    # the drawbridge (the +Y face): a plank ramp from the second floor down to the ground, 12 m long (a walkable 26 degrees)
    beam(P, "timber", (-2.0, 3.0, 6.9), (-2.0, 15.0, 0.2), 0.3, 0.25)
    beam(P, "timber", (2.0, 3.0, 6.9), (2.0, 15.0, 0.2), 0.3, 0.25)
    n = 30
    for k in range(n):
        t = (k + 0.5) / n
        box(P, "timber", (0.0, 3.0 + 12.0 * t, 7.0 - 6.8 * t), (4.4, 12.0 / n * 1.1, 0.16), pitch=-math.atan2(6.8, 12.0))
    outs = finish(P, "SiegeTower")
    col = make_collision(outs, "SiegeTower", 1.0)
    export(outs + [col], os.path.join(MODELS, "r37_siege_tower.glb"), "siege tower")
    preview(outs, "tower", [((-16, 17, 9), (0, 0, 7), 34), ((16, 17, 18), (0, 0, 8), 36)])


ASSETS = {"statue": asset_statue, "mill": asset_mill, "bridge": asset_bridge, "palisade": asset_palisade,
          "trebuchet": asset_trebuchet, "tower": asset_tower}

if __name__ == "__main__":
    os.makedirs(MODELS, exist_ok=True)
    os.makedirs(BLEND, exist_ok=True)
    for k, fn in ASSETS.items():
        if ONLY and k not in ONLY:
            continue
        print("=== ", k)
        fn()
