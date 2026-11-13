"""Shared helpers for the model-pass prop scripts (props_ruins.py, props_works.py), on top of props_stones.py.

props_stones gives the pipeline (Mk: a bmesh with a material-set layer and a tag layer; finish(): one object per set
named `<Part>__<set>` with metric box UVs and a vertex-colour TONE; export(); preview()). This adds the pieces a
built thing is made of: dressed blocks, breaks, bars, turned sections, boards; a harness that builds, counts, exports
and renders each asset; and a contact sheet of the eight preview renders.

Blender is Z up, 1 BU = 1 m. Godot x = Blender x, Godot y = Blender z, Godot z = -Blender y.
"""
import bpy
import bmesh
import math
import os
import sys
from mathutils import Vector, Matrix

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import props_stones as PS  # noqa: E402
from props_stones import Mk, oct_ring  # noqa: E402,F401

# more material sets than the stones use (art/textures/r37_<set>_*): metres per tile before the game's prop_mat (x3)
for _st, _tile in (("hewn", 3.0), ("slate", 3.0), ("thatch", 3.0), ("cloth", 1.5), ("daub", 3.0)):
    if _st not in PS.SETS:
        PS.SETS.append(_st)
        PS.TILE[_st] = _tile

TAG_DARK = PS.TAG_CRACK        # a hole's floor: nearly black
TAG_FLOOR = PS.TAG_FLOOR       # a recess: a little darker
BM = bmesh.types


def sk_of(mk, st=None):
    return PS.SETS.index(st or mk.cur) + 1


def flat(vs):
    """The vertices of a loft's rings as one list."""
    return [v for ring in vs for v in ring]


def geom_of(verts):
    vs = {v for v in verts if v.is_valid}
    es = {e for v in vs for e in v.link_edges if e.other_vert(v) in vs}
    fs = {f for v in vs for f in v.link_faces if all(x in vs for x in f.verts)}
    return list(vs) + list(es) + list(fs)


def move(mk, verts, m):
    bmesh.ops.transform(mk.bm, matrix=m, verts=[v for v in verts if v.is_valid])
    return verts


def trs(loc=(0, 0, 0), rz=0.0, rx=0.0, ry=0.0):
    return Matrix.Translation(Vector(loc)) @ Matrix.Rotation(rz, 4, 'Z') @ Matrix.Rotation(rx, 4, 'X') @ Matrix.Rotation(ry, 4, 'Y')


def block(mk, size, ch=0.03, j=0.006, ease=0.02, chip=0.0, st=None, hull=False, taper=0.0):
    """A dressed block w x d x h standing on z = 0, centred in xy: chamfered arrises, an eased top and foot, a little
    out of true. `taper` narrows the top. Returns (verts, faces) (faces[(ring, side)], side 2 = +Y, 6 = -Y)."""
    w, d, h = size
    e = min(ease, h * 0.25)
    tw, td = w * (1.0 - taper), d * (1.0 - taper)
    spec = [(0.0, w - e * 1.2, d - e * 1.2), (e, w, d), (h - e, tw, td), (h, tw - e * 1.6, td - e * 1.6)]
    rings = [oct_ring(mk.r, 0, 0, z, ww, dd, ch, j, 0.0, None, chip if k >= 2 else 0.0) for k, (z, ww, dd) in enumerate(spec)]
    old = mk.cur
    if st:
        mk.cur = st
    faces, vs = mk.loft(rings, top=True, bot=True, hull=hull)
    mk.cur = old
    return flat(vs), faces


def chop(mk, verts, co, no, rough=0.03, tag=0):
    """Break a piece along a plane (the side `no` points to is lost) and close the wound with a faceted scar. Returns
    the piece's remaining vertices."""
    bm = mk.bm
    live = [v for v in verts if v.is_valid]
    sk = next(iter(live[0].link_faces))[mk.sk]
    no = Vector(no).normalized()
    res = bmesh.ops.bisect_plane(bm, geom=geom_of(live), dist=1e-5, plane_co=Vector(co), plane_no=no, clear_outer=True, clear_inner=False)
    keep = [g for g in res["geom"] if isinstance(g, BM.BMVert) and g.is_valid]
    cut_e = [g for g in res["geom_cut"] if isinstance(g, BM.BMEdge) and g.is_valid]
    if not cut_e:
        return keep
    fill = bmesh.ops.edgeloop_fill(bm, edges=cut_e)
    for f in fill["faces"]:
        f.normal_update()
        if f.normal.dot(no) < 0.0:
            f.normal_flip()
        f[mk.sk] = sk
        f[mk.tag] = tag
        if rough > 0.0 and len(f.verts) >= 4:
            pk = bmesh.ops.poke(bm, faces=[f])
            for v in pk["verts"]:
                side = no.cross(Vector((0.3, 0.5, 0.8))).normalized()
                v.co += -no * rough * mk.r.uniform(0.3, 1.0) + side * rough * mk.r.uniform(-1.5, 1.5)
                keep.append(v)
            for pf in pk["faces"]:
                pf[mk.sk] = sk
                pf[mk.tag] = tag
    return keep


def dish(mk, face, inset, depth, tag=0):
    """Wear a hollow into a face (any way up): inset it and sink the middle."""
    n = face.normal.copy()
    sk = face[mk.sk]
    bmesh.ops.inset_individual(mk.bm, faces=[face], thickness=inset, depth=0.0, use_even_offset=True)
    for v in face.verts:
        v.co -= n * depth
    face[mk.tag] = tag
    for e in face.edges:
        for lf in e.link_faces:
            lf[mk.sk] = sk
    return face


def bar(mk, a, b, w, d=None, st="iron", ch=0.0, j=0.0, hull=False, twist=0.0):
    """A bar of rectangular section w x d from a to b (chamfered if ch). Returns its verts."""
    a, b = Vector(a), Vector(b)
    d = d or w
    ln = (b - a).length
    if ch > 0.0:
        rings = [oct_ring(mk.r, 0, 0, z, w, d, ch, j, twist * k) for k, z in enumerate((0.0, ln))]
    else:                                   # a thin bar: four sides are enough
        rings = [[Vector((sx * w * 0.5, sy * d * 0.5, z)) for sx, sy in ((1, -1), (1, 1), (-1, 1), (-1, -1))] for z in (0.0, ln)]
    old = mk.cur
    mk.cur = st
    _, vs = mk.loft(rings, top=True, bot=True, hull=hull)
    mk.cur = old
    q = Vector((0, 0, 1)).rotation_difference((b - a).normalized()).to_matrix().to_4x4()
    return move(mk, flat(vs), Matrix.Translation(a) @ q)


def crate(mk, size, st=None, j=0.0, taper=0.0):
    """The cheapest block (12 triangles): w x d x h on z = 0, centred in xy, a little out of true. Returns verts."""
    w, d, h = size
    r = mk.r
    rings = []
    for z, k in ((0.0, 1.0), (h, 1.0 - taper)):
        rings.append([Vector((sx * w * 0.5 * k + r.uniform(-j, j), sy * d * 0.5 * k + r.uniform(-j, j), z + r.uniform(-j, j) * 0.5))
                      for sx, sy in ((1, -1), (1, 1), (-1, 1), (-1, -1))])
    old = mk.cur
    if st:
        mk.cur = st
    _, vs = mk.loft(rings, top=True, bot=True, hull=False)
    mk.cur = old
    return flat(vs)


def annulus(mk, r_in, r_out, x0, x1, n=16, st="timber"):
    """A flat ring (a wheel's rim) about the x axis between x0 and x1. Returns verts."""
    old = mk.cur
    mk.cur = st
    rings = []
    for i in range(n + 1):
        a = math.tau * (i % n) / n
        c, sn = math.cos(a), math.sin(a)
        rings.append([Vector((x0, c * r_in, sn * r_in)), Vector((x1, c * r_in, sn * r_in)), Vector((x1, c * r_out, sn * r_out)), Vector((x0, c * r_out, sn * r_out))])
    _, vs = mk.loft(rings, top=False, bot=False, hull=False)
    mk.cur = old
    bmesh.ops.remove_doubles(mk.bm, verts=flat(vs), dist=1e-5)
    return [v for v in flat(vs) if v.is_valid]


def tone_scale(objs, st, k):
    """Multiply the baked tone of one set's objects (darker iron, paler timber) after finish()."""
    for o in objs:
        if not o.name.endswith("__" + st):
            continue
        ca = o.data.color_attributes["Col"]
        for d in ca.data:
            c = d.color
            d.color = (c[0] * k[0], c[1] * k[1], c[2] * k[2], 1.0)


def circle(rad, z, n, phase=0.0, cx=0.0, cy=0.0, sy=1.0):
    return [Vector((cx + math.cos(phase + math.tau * i / n) * rad, cy + math.sin(phase + math.tau * i / n) * rad * sy, z)) for i in range(n)]


def turned(mk, profile, n=10, st=None, top=True, bot=True, hull=False, phase=0.0):
    """A turned (lathed) solid about z: profile = [(radius, z), ...] from the foot up. Returns its verts."""
    old = mk.cur
    if st:
        mk.cur = st
    _, vs = mk.loft([circle(max(r, 0.002), z, n, phase) for r, z in profile], top=top, bot=bot, hull=hull)
    mk.cur = old
    return flat(vs)


def tube(mk, pts, rad, n=6, st="iron", closed=False):
    """A round bar along a polyline (a ring per point, mitred by eye). Returns its verts."""
    old = mk.cur
    mk.cur = st
    pts = [Vector(p) for p in pts]
    rings = []
    m = len(pts)
    for i, p in enumerate(pts):
        if closed:
            t = (pts[(i + 1) % m] - pts[i - 1]).normalized()
        else:
            t = (pts[min(i + 1, m - 1)] - pts[max(i - 1, 0)]).normalized()
        ref = Vector((0, 0, 1)) if abs(t.z) < 0.9 else Vector((1, 0, 0))
        u = t.cross(ref).normalized()
        v = t.cross(u).normalized()
        rings.append([p + (u * math.cos(math.tau * k / n) + v * math.sin(math.tau * k / n)) * rad for k in range(n)])
    if closed:
        rings.append([q.copy() for q in rings[0]])
    _, vs = mk.loft(rings, top=not closed, bot=not closed, hull=False)
    mk.cur = old
    return flat(vs)


def board(mk, size, st="timber", ch=0.008, j=0.004):
    """A sawn board or beam (w along x, d along y, h up) centred in xy on z = 0. Returns verts."""
    vs, _ = block(mk, size, ch=ch, j=j, ease=min(0.01, size[2] * 0.2), st=st)
    return vs


def finish(mk, name, tiles=None, moss_k=1.0, smooth_sets=(), sharp=40.0):
    """props_stones.finish with two changes: the texel density can be set per asset (`tiles` = {set: metres per
    tile}), and timber grain runs along a board's longest REAL edge (the stones' version takes the longest edge of
    each triangle, which on a wide board is the diagonal the triangulation added). One object per set: `<name>__<set>`."""
    tile_of = dict(PS.TILE)
    tile_of.update(tiles or {})
    bm = mk.bm
    orig = bm.edges.layers.int.new("orig")
    for e in bm.edges:
        e[orig] = 1
    bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method='BEAUTY', ngon_method='EAR_CLIP')
    bm.normal_update()
    for e in bm.edges:
        e.smooth = True
        if len(e.link_faces) == 2 and e.link_faces[0].normal.length > 1e-6 and e.link_faces[1].normal.length > 1e-6:
            e.smooth = math.degrees(e.link_faces[0].normal.angle(e.link_faces[1].normal)) < sharp
    bm.loops.layers.uv.new("UVMap")
    bm.loops.layers.color.new("Col")
    objs = []
    for si in sorted({f[mk.sk] for f in bm.faces}):
        st = PS.SETS[si - 1] if si > 0 else mk.cur
        b2 = bm.copy()
        sk2 = b2.faces.layers.int.get("sk")
        tag2 = b2.faces.layers.int.get("tag")
        or2 = b2.edges.layers.int.get("orig")
        b2.faces.ensure_lookup_table()
        bmesh.ops.delete(b2, geom=[f for f in b2.faces if f[sk2] != si], context='FACES')
        uv2 = b2.loops.layers.uv.get("UVMap")
        col2 = b2.loops.layers.color.get("Col")
        tile = tile_of[st]
        sm = st in smooth_sets
        b2.normal_update()
        for f in b2.faces:
            f.smooth = sm
            n = f.normal
            ax = max(range(3), key=lambda i: abs(n[i]))
            grain = None
            if st == "timber":
                real = [e for e in f.edges if e[or2]] or list(f.edges)
                le = max(real, key=lambda e: e.calc_length())
                d = (le.verts[1].co - le.verts[0].co).normalized()
                t1 = n.cross(d)
                if t1.length > 1e-6:
                    grain = (t1.normalized(), d)
            for lp in f.loops:
                co = lp.vert.co
                if grain is not None:
                    lp[uv2].uv = (co.dot(grain[0]) / tile, co.dot(grain[1]) / tile)
                elif ax == 0:
                    lp[uv2].uv = (co.y / tile, co.z / tile)
                elif ax == 1:
                    lp[uv2].uv = (co.x / tile, co.z / tile)
                else:
                    lp[uv2].uv = (co.x / tile, co.y / tile)
                c = PS.tone(st, co, lp.vert.normal if sm else n, f[tag2], mk.seed, moss_k)
                lp[col2] = (c[0], c[1], c[2], 1.0)
        nm = "%s__%s" % (name, st)
        me = bpy.data.meshes.new(nm)
        b2.to_mesh(me)
        b2.free()
        me.materials.append(PS.plain_material(st))
        ob = bpy.data.objects.new(nm, me)
        bpy.context.scene.collection.objects.link(ob)
        me.color_attributes.active_color = me.color_attributes["Col"]
        me.color_attributes.render_color_index = list(me.color_attributes.keys()).index("Col")
        objs.append(ob)
    return objs


def sheet(pdir, label, tile=480):
    """One contact sheet of the eight preview renders (neutral over night; front, three-quarter, side, close)."""
    import numpy as np
    order = [(light, view) for light in ("neutral", "night") for view in ("front", "q3", "side", "close")]
    out = np.zeros((2 * tile, 4 * tile, 4), dtype=np.float32)
    out[..., 3] = 1.0
    for i, (light, view) in enumerate(order):
        path = os.path.join(pdir, "%s_%s_%s.png" % (label, light, view))
        if not os.path.exists(path):
            continue
        im = bpy.data.images.load(path)
        w, h = im.size
        px = np.empty(w * h * 4, dtype=np.float32)
        im.pixels.foreach_get(px)
        px = px.reshape(h, w, 4)
        k = max(1, w // tile)
        small = px[:tile * k, :tile * k].reshape(tile, k, tile, k, 4).mean(axis=(1, 3))
        row = 1 - i // 4                      # images are bottom-up: the neutral row goes on top
        col = i % 4
        out[row * tile:(row + 1) * tile, col * tile:(col + 1) * tile] = small
        bpy.data.images.remove(im)
        os.remove(path)
    img = bpy.data.images.new(label + "_sheet", 4 * tile, 2 * tile, alpha=False)
    img.pixels.foreach_set(out.ravel())
    img.filepath_raw = os.path.join(pdir, label + "_sheet.png")
    img.file_format = "PNG"
    img.save()
    print("SHEET", img.filepath_raw)


def run(assets):
    """assets = {name: fn}; fn() returns dict(path, parts=[(label, [objects])], extra=[objects to export too],
    budget=int, focus=Vector or None). Builds each (or --only), prints triangles, exports with --export and renders a
    contact sheet with --preview DIR. Parts are modelled at the origin and spread along x only for the renders."""
    for nm, fn in assets.items():
        if PS.ONLY and nm not in PS.ONLY:
            continue
        PS.reset()
        b = fn()
        allobjs = [o for _, objs in b["parts"] for o in objs]
        for label, objs in b["parts"]:
            print("TRIS %-22s %-14s %5d  %s" % (nm, label, PS.tri_total(objs), [o.name for o in objs]))
        tot = PS.tri_total(allobjs)
        print("TRIS %-22s %-14s %5d (budget %d)%s" % (nm, "TOTAL", tot, b.get("budget", 0), "" if tot <= b.get("budget", 1e9) else "  OVER"))
        if PS.DO_EXPORT and b.get("path"):
            PS.export(allobjs + b.get("extra", []), b["path"])
        if PS.PREVIEW:
            for o in b.get("extra", []):
                o.hide_render = True
            show = b.get("show")                       # labels to render (default all); the rest are hidden
            shown = [(lb, objs) for lb, objs in b["parts"] if not show or lb in show]
            for lb, objs in b["parts"]:
                for o in objs:
                    o.hide_render = (lb, objs) not in shown
            if len(shown) > 1:                          # a grid, so small parts fill the frame
                cols = int(math.ceil(math.sqrt(len(shown))))
                cell = max(max((Vector(c).x for o in objs for c in o.bound_box)) - min((Vector(c).x for o in objs for c in o.bound_box)) for _, objs in shown)
                cell = max(cell, max(max((Vector(c).y for o in objs for c in o.bound_box)) - min((Vector(c).y for o in objs for c in o.bound_box)) for _, objs in shown)) + 0.12
                for k, (lb, objs) in enumerate(shown):
                    for o in objs:
                        o.location.x = (k % cols - (cols - 1) * 0.5) * cell
                        o.location.y = -(k // cols) * cell
            allobjs = [o for _, objs in shown for o in objs]
            bpy.context.view_layer.update()
            focus = b.get("focus")
            if focus is None:
                pts = [o.matrix_world @ Vector(c) for o in allobjs for c in o.bound_box]
                focus = sum(pts, Vector()) / len(pts)
            PS.preview(nm, allobjs, focus)
            sheet(PS.PREVIEW, nm)
