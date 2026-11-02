"""Gothic arcade bay kit for Umbral Reaches (hard surface, metres, Y up in Blender -> exported Y up for glTF).
Matches the reference: moulded pointed archivolt on clustered piers with foliate capitals, coursed ashlar,
lancet window with tracery in a back wall, flagstone floor.  Run: python3 gothic_bay.py [--render]"""
import bpy, bmesh, math, random, sys, addon_utils
from mathutils import Vector

random.seed(7)
S = 3.0                    # arch span between springing points
Y0 = 3.4                   # springing height
PIER_X = S / 2 + 0.28
H = math.sqrt(3) / 2

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    addon_utils.enable('cycles')

def new_obj(name, bm, mat=None):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    if mat: ob.data.materials.append(mat)
    return ob

def fix(bm):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])

# ---------- profiles ----------
def rrect(r0, r1, d0, d1, c=0.03, seg=3):
    pts = []
    corners = [(r1, d0, -90, 0), (r1, d1, 0, 90), (r0, d1, 90, 180), (r0, d0, 180, 270)]
    for (cr, cd, a0, a1) in corners:
        sx = -c if cr == r1 else c
        sy = c if cd == d0 else -c
        ccr, ccd = cr + sx, cd + sy
        for k in range(seg + 1):
            a = math.radians(a0 + (a1 - a0) * k / seg)
            pts.append((ccr + c * math.cos(a), ccd + c * math.sin(a)))
    return pts

def circle(cr, cd, rad, seg=10):
    return [(cr + rad * math.cos(2 * math.pi * k / seg), cd + rad * math.sin(2 * math.pi * k / seg)) for k in range(seg)]

# ---------- arch path ----------
def arch_path(span, y0, cx=0.0, n=14):
    pts, nor = [], []
    for k in range(n):
        th = math.pi - (math.pi / 3) * k / n          # 180 -> 120 deg, left arc, centre at right springing
        pts.append(Vector((cx + span / 2 + span * math.cos(th), y0 + span * math.sin(th), 0)))
        nor.append(Vector((math.cos(th), math.sin(th), 0)))
    pts.append(Vector((cx, y0 + span * H, 0))); nor.append(Vector((0, 1 / H * 0.5 * 1.0, 0)) * 1.0)
    nor[-1] = Vector((0, 1.1547, 0))                  # mitred apex
    for k in range(1, n + 1):
        th = (math.pi / 3) * (1 - k / n)               # 60 -> 0 deg, right arc, centre at left springing
        pts.append(Vector((cx - span / 2 + span * math.cos(th), y0 + span * math.sin(th), 0)))
        nor.append(Vector((math.cos(th), math.sin(th), 0)))
    return pts, nor

def sweep(path, normals, profile, name):
    bm = bmesh.new()
    M = len(profile)
    rings = []
    for P, n in zip(path, normals):
        rings.append([bm.verts.new(P + n * r + Vector((0, 0, d))) for (r, d) in profile])
    for i in range(len(rings) - 1):
        for j in range(M):
            bm.faces.new((rings[i][j], rings[i][(j + 1) % M], rings[i + 1][(j + 1) % M], rings[i + 1][j]))
    bm.faces.new(rings[0]); bm.faces.new(rings[-1][::-1])
    fix(bm)
    return bm

# ---------- primitives into a shared bmesh ----------
def add_box(bm, c, size, rot_y=0.0):
    r = bmesh.ops.create_cube(bm, size=1.0)
    vs = r['verts']
    bmesh.ops.scale(bm, vec=Vector(size), verts=vs)
    if rot_y: bmesh.ops.rotate(bm, cent=(0, 0, 0), matrix=__import__('mathutils').Matrix.Rotation(rot_y, 3, 'Y'), verts=vs)
    bmesh.ops.translate(bm, vec=Vector(c), verts=vs)
    return vs

def add_cyl(bm, c, r1, r2, h, seg=16):
    r = bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=r1, radius2=r2, depth=h)
    vs = r['verts']
    bmesh.ops.rotate(bm, cent=(0, 0, 0), matrix=__import__('mathutils').Matrix.Rotation(math.pi / 2, 3, 'X'), verts=vs)  # Z axis -> Y axis
    bmesh.ops.translate(bm, vec=Vector(c), verts=vs)
    return vs

def add_leaf(bm, c, scale, rot_z, tilt):
    from mathutils import Matrix
    r = bmesh.ops.create_uvsphere(bm, u_segments=8, v_segments=6, radius=1.0)
    vs = r['verts']
    # leaf points outward along local +X, bends upward
    for v in vs:
        v.co.x = v.co.x * scale[0] + 0.5 * scale[0]
        v.co.y = v.co.y * scale[1]
        v.co.z = v.co.z * scale[2]
        v.co.y += 0.35 * (v.co.x ** 2) / max(scale[0], 1e-3)   # curl upward
    bmesh.ops.rotate(bm, cent=(0, 0, 0), matrix=Matrix.Rotation(tilt, 3, 'Z'), verts=vs)
    bmesh.ops.rotate(bm, cent=(0, 0, 0), matrix=Matrix.Rotation(rot_z, 3, 'Y'), verts=vs)
    bmesh.ops.translate(bm, vec=Vector(c), verts=vs)

def pier(x, z=0.0):
    bm = bmesh.new()
    y_cap = Y0 - 0.46
    add_box(bm, (x, 0.13, z), (1.25, 0.26, 1.25))                       # plinth
    add_cyl(bm, (x, 0.34, z), 0.64, 0.58, 0.16, 24)                      # base roll
    add_cyl(bm, (x, 0.50, z), 0.56, 0.52, 0.16, 24)
    add_cyl(bm, (x, (y_cap + 0.5) / 2 + 0.2, z), 0.40, 0.40, y_cap - 0.5, 20)   # core
    for k in range(8):                                                   # attached shafts
        a = 2 * math.pi * k / 8
        sx, sz = x + 0.40 * math.cos(a), z + 0.40 * math.sin(a)
        add_cyl(bm, (sx, (y_cap + 0.5) / 2 + 0.2, sz), 0.12, 0.12, y_cap - 0.5, 10)
        for yb in (1.35, 2.35):                                          # astragal rings
            add_cyl(bm, (sx, yb, sz), 0.15, 0.15, 0.07, 10)
    # capital: bell + foliage + abacus
    add_cyl(bm, (x, y_cap + 0.12, z), 0.50, 0.70, 0.30, 24)
    add_cyl(bm, (x, y_cap - 0.04, z), 0.54, 0.54, 0.06, 24)
    for k in range(16):
        a = 2 * math.pi * k / 16
        add_leaf(bm, (x + 0.64 * math.cos(a), y_cap + 0.02 + 0.03 * (k % 2), z + 0.64 * math.sin(a)),
                 (0.20, 0.07, 0.10), -a, random.uniform(-0.15, 0.15))
    for k in range(8):
        a = 2 * math.pi * (k + 0.5) / 8
        add_leaf(bm, (x + 0.66 * math.cos(a), y_cap + 0.20, z + 0.66 * math.sin(a)),
                 (0.16, 0.06, 0.09), -a, random.uniform(-0.2, 0.2))
    add_box(bm, (x, y_cap + 0.38, z), (1.40, 0.14, 1.40))                # abacus
    add_box(bm, (x, y_cap + 0.46, z), (1.34, 0.04, 1.34))
    fix(bm)
    return bm

# ---------- coursed ashlar ----------
def ashlar(x0, x1, y0, y1, z_front, depth, reject, name, row_h=(0.30, 0.42), w=(0.5, 0.95)):
    bm = bmesh.new()
    y = y0
    while y < y1 - 0.05:
        h = min(random.uniform(*row_h), y1 - y)
        x = x0 - random.uniform(0, 0.4)
        while x < x1:
            bw = random.uniform(*w)
            xe = min(x + bw, x1); xs = max(x, x0)
            if xe - xs > 0.12:
                cx, cy = (xs + xe) / 2, y + h / 2
                corners = [(xs, y), (xe, y), (xs, y + h), (xe, y + h)]
                if not any(reject(px, py) for px, py in corners) and not reject(cx, cy):
                    inset = random.uniform(0.0, 0.035)
                    add_box(bm, (cx, cy, z_front - depth / 2 + inset / 2), (xe - xs - 0.02, h - 0.02, depth - inset))
            x += bw
        y += h
    fix(bm)
    return bm

def in_arch(px, py, cx, y0, span, off=0.0):
    """inside the pointed arch whose intrados has this span, grown outward by off (metres)."""
    if py < y0: return abs(px - cx) < span / 2 + off
    r = span + off
    return math.hypot(px - (cx + span / 2), py - y0) < r and math.hypot(px - (cx - span / 2), py - y0) < r

def in_pointed(px, py, cx, y0, span):
    """inside a two-centred equilateral-style arch of the given span (opening above springing line y0)."""
    if py < y0: return abs(px - cx) < span / 2
    return math.hypot(px - (cx + span / 2), py - y0) < span and math.hypot(px - (cx - span / 2), py - y0) < span

# ---------- window ----------
def window(zf, W=1.3, sill=1.5, spring=3.7):
    objs = []
    # surround arch (moulded) + jambs
    path, nor = arch_path(W, spring)
    prof = rrect(0.0, 0.42, -0.20, 0.10, 0.03)
    bm = sweep(path, nor, prof, 'win_surround')
    bmesh.ops.translate(bm, vec=Vector((0, 0, zf)), verts=bm.verts[:])
    bead = sweep(path, nor, circle(0.02, 0.10, 0.045), 'bead')
    bmesh.ops.translate(bead, vec=Vector((0, 0, zf)), verts=bead.verts[:])
    tmp = bpy.data.meshes.new('t'); bead.to_mesh(tmp); bead.free(); bm.from_mesh(tmp); bpy.data.meshes.remove(tmp)
    for s in (-1, 1):                                                  # jambs
        add_box(bm, (s * (W / 2 + 0.21), (sill + spring) / 2, zf - 0.05), (0.42, spring - sill, 0.30))
        add_box(bm, (s * (W / 2 - 0.01), (sill + spring) / 2, zf + 0.02), (0.05, spring - sill, 0.09))
    add_box(bm, (0, sill - 0.07, zf - 0.02), (W + 0.7, 0.14, 0.42))   # sill
    fix(bm)
    surround = new_obj('Window_Surround', bm)
    # tracery + glazing bars
    t = bmesh.new()
    mull = W / 2
    add_box(t, (0, (sill + spring + 0.55) / 2, zf - 0.12), (0.07, spring + 0.55 - sill, 0.09))   # centre mullion
    for yb in [sill + 0.32 * k for k in range(1, int((spring - sill) / 0.32) + 1)]:                 # transoms
        add_box(t, (0, yb, zf - 0.13), (W, 0.035, 0.05))
    for xb in (-W / 4, W / 4):
        add_box(t, (xb, (sill + spring) / 2, zf - 0.13), (0.03, spring - sill, 0.05))
    for sx in (-1, 1):                                                  # sub-lights
        p2, n2 = arch_path(W / 2, spring, cx=sx * W / 4, n=8)
        sw = sweep(p2, n2, circle(0.0, 0.0, 0.032), 'sub')
        bmesh.ops.translate(sw, vec=Vector((0, 0, zf - 0.12)), verts=sw.verts[:])
        tmp = bpy.data.meshes.new('t'); sw.to_mesh(tmp); sw.free(); t.from_mesh(tmp); bpy.data.meshes.remove(tmp)
    # oculus ring
    ring = bmesh.new()
    bmesh.ops.create_circle  # (kept simple: sweep a circle path)
    cp = [Vector((0.17 * math.cos(2 * math.pi * k / 20), spring + 0.62 + 0.17 * math.sin(2 * math.pi * k / 20), zf - 0.12)) for k in range(21)]
    cn = [Vector((math.cos(2 * math.pi * k / 20), math.sin(2 * math.pi * k / 20), 0)) for k in range(21)]
    ring = sweep(cp, cn, circle(0, 0, 0.03), 'oculus')
    tmp = bpy.data.meshes.new('t'); ring.to_mesh(tmp); ring.free(); t.from_mesh(tmp); bpy.data.meshes.remove(tmp)
    fix(t)
    tracery = new_obj('Window_Tracery', t)
    # glass: fan polygon following the pointed head
    g = bmesh.new()
    gp, gn = arch_path(W, spring)
    outline = [Vector((-W / 2, sill, 0))] + [p for p in gp] + [Vector((W / 2, sill, 0))]
    vs = [g.verts.new(p + Vector((0, 0, zf - 0.22))) for p in outline]
    g.faces.new(vs)
    fix(g)
    glass = new_obj('Window_Glass', g)
    return surround, tracery, glass

# ---------- floor ----------
def floor(x0, x1, z0, z1):
    bm = bmesh.new()
    z = z0
    while z < z1:
        dz = random.uniform(0.7, 1.2)
        x = x0
        while x < x1:
            dx = random.uniform(0.7, 1.3)
            add_box(bm, (x + dx / 2, -0.04 + random.uniform(-0.012, 0.012), z + dz / 2), (dx - 0.04, 0.12, dz - 0.04))
            x += dx
        z += dz
    fix(bm)
    return bm

def mat(name, base, rough=0.85, emission=None, strength=0.0):
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = (*base, 1)
    b.inputs['Roughness'].default_value = rough
    if emission:
        b.inputs['Emission Color'].default_value = (*emission, 1)
        b.inputs['Emission Strength'].default_value = strength
    if name == 'Stone':
        nt = m.node_tree
        noise = nt.nodes.new('ShaderNodeTexNoise'); noise.inputs['Scale'].default_value = 18; noise.inputs['Detail'].default_value = 10
        bump = nt.nodes.new('ShaderNodeBump'); bump.inputs['Strength'].default_value = 0.35; bump.inputs['Distance'].default_value = 0.03
        tc = nt.nodes.new('ShaderNodeTexCoord')
        nt.links.new(tc.outputs['Object'], noise.inputs['Vector'])
        nt.links.new(noise.outputs['Fac'], bump.inputs['Height'])
        nt.links.new(bump.outputs['Normal'], b.inputs['Normal'])
        ramp = nt.nodes.new('ShaderNodeValToRGB')
        ramp.color_ramp.elements[0].color = (0.10, 0.12, 0.24, 1); ramp.color_ramp.elements[1].color = (0.30, 0.34, 0.50, 1)
        nt.links.new(noise.outputs['Fac'], ramp.inputs['Fac'])
        nt.links.new(ramp.outputs['Color'], b.inputs['Base Color'])
    return m

def bevel_apply(ob, width=0.012, seg=2):
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    md = ob.modifiers.new('bev', 'BEVEL')
    md.width = width; md.segments = seg; md.limit_method = 'ANGLE'; md.angle_limit = math.radians(35)
    bpy.ops.object.modifier_apply(modifier='bev')
    ob.select_set(False)

def build():
    reset()
    stone = mat('Stone', (0.20, 0.23, 0.34), 0.85)
    glassm = mat('Glass', (0.05, 0.9, 0.8), 0.2, emission=(0.1, 1.0, 0.85), strength=4.0)
    objs = []
    for sx in (-1, 1):
        objs.append(new_obj('Pier_%s' % ('L' if sx < 0 else 'R'), pier(sx * PIER_X), stone))
    # archivolt orders (front = +z)
    path, nor = arch_path(S, Y0)
    orders = []
    for k in range(4):
        d0 = -0.40 + 0.20 * k
        orders.append(sweep(path, nor, rrect(0.075 * k, 0.56, d0, d0 + 0.20, 0.03), 'order'))
        orders.append(sweep(path, nor, circle(0.075 * k + 0.012, d0 + 0.20, 0.04), 'bead'))
    orders.append(sweep(path, nor, rrect(0.56, 0.72, -0.30, 0.34, 0.04), 'hood'))
    big = bmesh.new()
    for b in orders:
        tmp = bpy.data.meshes.new('t'); b.to_mesh(tmp); b.free(); big.from_mesh(tmp); bpy.data.meshes.remove(tmp)
    objs.append(new_obj('Archivolt', big, stone))
    # spandrel masonry above the arch (front of the arcade)
    sp = ashlar(-PIER_X - 0.7, PIER_X + 0.7, Y0 - 0.1, 6.2, 0.25, 0.9,
                lambda x, y: in_arch(x, y, 0.0, Y0, S, 0.78), 'Spandrel')
    objs.append(new_obj('Spandrel', sp, stone))
    # back wall with lancet window
    WZ = -3.4
    W, SILL, SPR = 1.3, 1.5, 3.7
    wall = ashlar(-5.0, 5.0, 0.0, 7.0, WZ, 0.6,
                  lambda x, y: y >= SPR - 0.05 and in_arch(x, y, 0.0, SPR, W, 0.02) or (SILL - 0.1 < y < SPR and abs(x) < W / 2 + 0.02),
                  'Wall')
    objs.append(new_obj('Wall', wall, stone))
    su, tr, gl = window(WZ + 0.30)
    su.data.materials.append(stone); tr.data.materials.append(stone); gl.data.materials.append(glassm)
    objs += [su, tr]
    fl = new_obj('Floor', floor(-6, 6, -3.2, 4.8), stone)
    objs.append(fl)
    for ob in objs: bevel_apply(ob)
    objs.append(gl)
    # Blender is Z-up; the kit was authored Y-up. Rotate +90 deg about X and apply so the glTF exporter (Y-up) is correct.
    bpy.ops.object.select_all(action='DESELECT')
    for ob in objs: ob.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.transform.rotate(value=math.pi / 2, orient_axis='X')
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    bpy.ops.object.select_all(action='DESELECT')
    for ob in objs:
        bpy.context.view_layer.objects.active = ob
        try: bpy.ops.object.shade_smooth_by_angle(angle=math.radians(40))
        except Exception as e: print('smooth skipped', e)
    return objs

def preview(objs, out, cam_loc, cam_target, lens=28, res=(720, 900), samples=48):
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'; sc.cycles.samples = samples
    sc.cycles.use_denoising = True
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.view_settings.view_transform = 'AgX'
    w = bpy.data.worlds.new('w'); w.use_nodes = True
    w.node_tree.nodes['Background'].inputs['Color'].default_value = (0.02, 0.03, 0.10, 1)
    w.node_tree.nodes['Background'].inputs['Strength'].default_value = 1.0
    sc.world = w
    bpy.ops.object.light_add(type='SUN', rotation=(math.radians(55), 0, math.radians(30)))
    bpy.context.object.data.energy = 0.6; bpy.context.object.data.color = (0.45, 0.5, 1.0)
    bpy.ops.object.light_add(type='AREA', location=(0, 3.0, 3.0))     # window glow stand-in (Z-up: y=-z_old, z=y_old)
    L = bpy.context.object; L.data.energy = 900; L.data.color = (0.1, 1.0, 0.85); L.data.size = 1.2; L.rotation_euler = (math.radians(90), 0, 0)
    cam_loc = (cam_loc[0], -cam_loc[2], cam_loc[1]); cam_target = (cam_target[0], -cam_target[2], cam_target[1])
    bpy.ops.object.camera_add(location=cam_loc); cam = bpy.context.object
    d = Vector(cam_target) - Vector(cam_loc)
    cam.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
    cam.data.lens = lens; sc.camera = cam
    sc.render.filepath = out
    bpy.ops.render.render(write_still=True)

def export_glb(objs, path):
    bpy.ops.object.select_all(action='DESELECT')
    for ob in objs: ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, use_selection=True, export_format='GLB', export_yup=True,
                              export_apply=False, export_materials='EXPORT', export_normals=True)

if __name__ == '__main__':
    objs = build()
    tris = sum(len(o.data.polygons) for o in objs)
    print('faces', tris, 'objs', len(objs))
    if '--export' in sys.argv:
        export_glb(objs, '/home/claude/blend/gothic_bay.glb')
    if '--render' in sys.argv:
        preview(objs, '/home/claude/blend/view_through_arch.png', (0.2, 1.55, 6.2), (0.0, 2.6, -3.0))
        if '--oblique' in sys.argv:
            for o in [o for o in bpy.data.objects if o.type == 'CAMERA']: bpy.data.objects.remove(o)
            preview.__defaults__  # keep signature
            sc = bpy.context.scene
            bpy.ops.object.camera_add(location=(5.5, -6.5, 2.4)); cam = bpy.context.object
            d = Vector((-0.5, 0.0, 2.8)) - Vector(cam.location)
            cam.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler(); cam.data.lens = 30; sc.camera = cam
            sc.render.resolution_x, sc.render.resolution_y = 900, 700
            sc.render.filepath = '/home/claude/blend/view_oblique.png'
            bpy.ops.render.render(write_still=True)
