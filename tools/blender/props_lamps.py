"""The lamps and posts the wanderer passes constantly, modelled by script (replaces the code boxes in
core/world/realm/lamps/lamp.gd _mesh_for and core/world/ember_post.gd _build). No scans, no downloads.

  art/models/props/lamp_hang.glb      hanging lamp on a wall bracket (origin: the wall plane, +z out of the wall)
  art/models/props/lamp_niche.glb     candle niche, stone, wax drips (origin: wall plane at the sill; Plinth = the free-standing base)
  art/models/props/lamp_post.glb      standing lantern post (origin: ground)
  art/models/props/lamp_pane.glb      pane lantern, glazed iron frame (origin: the flame, as lamp.gd's "pane" look)
  art/models/props/lamp_cresset.glb   tower cresset, iron basket on a tripod (origin: ground)
  art/models/props/ember_post.glb     the post beside every brazier (origin: ground, arm and cage toward +x)

Every glb holds: Body (stone / iron / wood / wax as vertex colour, ONE material), Glass and Flame (own material each, so the game keeps
its emissive materials on them), empties FlamePoint / LightPoint (/ SparkPoint), and a *-colonly collider where the old look had one.
The flame mesh is authored in model space with its base at FlamePoint, so the game places it at the origin, not at flame_at.

  tools/blender/run.sh props_lamps.py -- [--only hang,niche,post,pane,cresset,ember] [--export] [--preview DIR]
"""
import bpy
import bmesh
import math
import os
import sys
import random
from mathutils import Vector, Matrix, noise

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
MODELS = os.path.join(ROOT, "art", "models", "props")
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ONLY = args[args.index("--only") + 1].split(",") if "--only" in args else []
PREVIEW = args[args.index("--preview") + 1] if "--preview" in args else ""
EXPORT = "--export" in args


TILE = {"stone": 2.0, "ashlar": 1.3333, "timber": 2.0, "iron": 0.6667, "wax": 0.1333}     # metres per texture tile: the sets at 3x density on small props (timber unchanged)
SETOF = {"wood": "timber", "iron": "iron", "stone": "stone", "dark": "stone", "moss": "stone", "ashlar": "ashlar", "wax": "wax"}


def B(g):
    """Godot (x, y, z) -> Blender (x, -z, y)."""
    return Vector((g[0], -g[2], g[1]))


def smooth(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a + 1e-9)))
    return t * t * (3 - 2 * t)


def fbm(p, octaves=3):
    a, f, s, n = 1.0, 1.0, 0.0, 0.0
    for _ in range(octaves):
        s += a * noise.noise(Vector(p) * f)
        n += a
        a *= 0.5
        f *= 2.0
    return s / n


# ---------------------------------------------------------------------------------------------------------
# geometry containers and primitives (all positions are Godot coordinates)
# ---------------------------------------------------------------------------------------------------------
class Parts:
    def __init__(self, seed=1):
        self.bm = {}
        self.rng = random.Random(seed)
        self.flame = Vector((0, 0, 0))      # Godot point; soot is darkest above it

    def of(self, key):
        if key not in self.bm:
            self.bm[key] = bmesh.new()
        return self.bm[key]


def box(P, key, c, size, yaw=0.0, taper=1.0, jitter=0.0, cuts=0, tilt=0.0, bevel=0.0):
    """A chunky block: centre c, size (x, y, z), `taper` scales the top face, `jitter` shoves the verts about (hand-hewn),
    `cuts` subdivides each face so the jitter has something to bend."""
    bm = P.of(key)
    # the verts already in the mesh are tagged, so this box's own are the untagged ones (a set of the earlier verts
    # went stale across the subdivide: an earlier box was then shaped again as this one, and the free niche's
    # plinth block folded into its cap slab)
    for v in bm.verts:
        v.tag = True
    res = bmesh.ops.create_cube(bm, size=1.0)
    verts = res["verts"]
    for v in verts:
        v.tag = False
    if cuts > 0:
        edges = list({e for v in verts for e in v.link_edges})
        bmesh.ops.subdivide_edges(bm, edges=edges, cuts=cuts, use_grid_fill=True)
    verts = [v for v in bm.verts if not v.tag]
    rg = P.rng
    M = Matrix.Translation(B(c)) @ Matrix.Rotation(-yaw, 4, 'Z') @ Matrix.Rotation(tilt, 4, 'X')
    for v in verts:
        k = v.co.z + 0.5                           # 0 at the foot, 1 at the top (Blender z = Godot y)
        s = 1.0 + (taper - 1.0) * k
        x, y, z = v.co.x * s * size[0], v.co.y * s * size[2], v.co.z * size[1]
        if jitter > 0:
            x += rg.uniform(-jitter, jitter)
            y += rg.uniform(-jitter, jitter)
            z += rg.uniform(-jitter, jitter) * 0.6
        v.co = M @ Vector((x, y, z))
    if bevel > 0 and cuts == 0:
        bmesh.ops.bevel(bm, geom=list({e for v in verts for e in v.link_edges}), offset=bevel, segments=1, affect='EDGES')
    return res


def bar(P, key, a, b, w, h=None, taper=1.0, jitter=0.0):
    """A square bar from a to b."""
    a, b = B(a), B(b)
    d = b - a
    q = d.to_track_quat('Y', 'Z')
    M = Matrix.Translation((a + b) * 0.5) @ q.to_matrix().to_4x4()
    bm = P.of(key)
    res = bmesh.ops.create_cube(bm, size=1.0)
    for v in res["verts"]:
        s = 1.0 + (taper - 1.0) * (v.co.y + 0.5)
        co = Vector((v.co.x * w * s, v.co.y * d.length, v.co.z * (h or w) * s))
        if jitter > 0:
            co += Vector((P.rng.uniform(-jitter, jitter), 0, P.rng.uniform(-jitter, jitter)))
        v.co = M @ co
    return res


def lathe(P, key, c, profile, seg, rot=0.0, cap_top=True, cap_bot=False, lean=0.0, wob=0.0, smooth=None):
    """A surface of revolution about the vertical axis through c. profile: [(radius, height)] foot to top.
    `lean` bends the upper rings toward +x (a flame); `wob` jitters the radius (an irregular lump)."""
    bm = P.of(key)
    sm = (seg >= 6) if smooth is None else smooth
    rg = P.rng
    ht = max(profile[-1][1] - profile[0][1], 1e-4)
    rings = []
    for (r, y) in profile:
        f = (y - profile[0][1]) / ht
        ring = []
        for k in range(seg):
            th = rot + math.tau * k / seg
            rr = r * (1.0 + (rg.uniform(-wob, wob) if r > 1e-5 else 0.0))
            ring.append(bm.verts.new(B((c[0] + rr * math.cos(th) + lean * f * f, c[1] + y, c[2] + rr * math.sin(th)))))
        rings.append(ring)
    # Godot (x, z) -> Blender (x, -z): the angle runs the other way, so wind the quads to face outward by test
    ctr = B((c[0], c[1], c[2]))
    for i in range(len(rings) - 1):
        for k in range(seg):
            k2 = (k + 1) % seg
            f = (rings[i][k], rings[i][k2], rings[i + 1][k2], rings[i + 1][k])
            if len({id(v) for v in f}) < 4:
                f = tuple(dict.fromkeys(f))
                if len(f) < 3:
                    continue
            mid = sum((v.co for v in f), Vector()) / len(f)
            n = (f[1].co - f[0].co).cross(f[2].co - f[0].co)
            out = Vector((mid.x - ctr.x, mid.y - ctr.y, 0))
            if n.dot(out) == 0:
                n = Vector((0, 0, 1))
                out = Vector((0, 0, 1)) if profile[i + 1][1] > profile[i][1] else Vector((0, 0, -1))
                if profile[i + 1][1] == profile[i][1]:
                    out = Vector((0, 0, 1)) if profile[i + 1][0] < profile[i][0] else Vector((0, 0, -1))
            try:
                bm.faces.new(f if n.dot(out) > 0 else f[::-1]).smooth = sm
            except ValueError:
                pass
    for ring, top in ((rings[-1], True), (rings[0], False)):
        if (top and not cap_top) or (not top and not cap_bot):
            continue
        cv = bm.verts.new(B((c[0] + (ring[0].co.x - ctr.x) * 0 + (lean if top else 0.0), c[1] + (profile[-1][1] if top else profile[0][1]), c[2])))
        for k in range(seg):
            k2 = (k + 1) % seg
            f = (ring[k], ring[k2], cv)
            n = (f[1].co - f[0].co).cross(f[2].co - f[0].co)
            want = 1.0 if top else -1.0
            try:
                bm.faces.new(f if n.z * want > 0 else f[::-1])
            except ValueError:
                pass


def torus(P, key, c, R, r, nmaj=6, nmin=4, yaw=0.0):
    """A ring standing in the XY plane (faces the viewer at +z), turned `yaw` about y."""
    bm = P.of(key)
    rows = []
    for i in range(nmaj):
        th = math.tau * i / nmaj
        row = []
        for j in range(nmin):
            ph = math.tau * j / nmin
            rr = R + r * math.cos(ph)
            p = Vector((rr * math.cos(th), rr * math.sin(th), r * math.sin(ph)))
            p = Matrix.Rotation(yaw, 3, 'Y') @ p
            row.append(bm.verts.new(B((c[0] + p.x, c[1] + p.y, c[2] + p.z))))
        rows.append(row)
    for i in range(nmaj):
        i2 = (i + 1) % nmaj
        th = math.tau * (i + 0.5) / nmaj
        for j in range(nmin):
            j2 = (j + 1) % nmin
            f = (rows[i][j], rows[i2][j], rows[i2][j2], rows[i][j2])
            tube_c = Matrix.Rotation(yaw, 3, 'Y') @ Vector((R * math.cos(th), R * math.sin(th), 0))
            tube_c = B((c[0] + tube_c.x, c[1] + tube_c.y, c[2] + tube_c.z))
            mid = sum((v.co for v in f), Vector()) / 4
            n = (f[1].co - f[0].co).cross(f[2].co - f[0].co)
            bm.faces.new(f if n.dot(mid - tube_c) > 0 else f[::-1]).smooth = True


def prism(P, key, poly, z0, z1, jitter=0.0):
    """A polygon (x, y) in Godot coordinates extruded from z0 to z1 (z1 toward the viewer)."""
    bm = P.of(key)
    rg = P.rng
    pts = [(x + rg.uniform(-jitter, jitter), y + rg.uniform(-jitter, jitter)) for x, y in poly]
    fr = [bm.verts.new(B((x, y, z1 + rg.uniform(-jitter, jitter) * 0.5))) for x, y in pts]
    bk = [bm.verts.new(B((x, y, z0))) for x, y in pts]
    n = len(pts)
    cx = sum(p[0] for p in pts) / n
    cy = sum(p[1] for p in pts) / n
    cen = B((cx, cy, (z0 + z1) * 0.5))

    def add(vs):
        nn = (vs[1].co - vs[0].co).cross(vs[2].co - vs[0].co)
        mid = sum((v.co for v in vs), Vector()) / len(vs)
        bm.faces.new(vs if nn.dot(mid - cen) > 0 else vs[::-1])
    add(fr)
    add(bk)
    for i in range(n):
        j = (i + 1) % n
        add((fr[i], fr[j], bk[j], bk[i]))


def quad(P, key, a, b, c, d):
    bm = P.of(key)
    bm.faces.new([bm.verts.new(B(p)) for p in (a, b, c, d)])


# ---------------------------------------------------------------------------------------------------------
# shared looks
# ---------------------------------------------------------------------------------------------------------
def flame_mesh(P, at, h=0.2, r=0.05, seg=6, lean=0.01):
    """A teardrop flame, base at `at`; vertex colour pale at the root, red at the tip (set in finish)."""
    lathe(P, "flame", at, [(0.0, 0.0), (r * 0.85, h * 0.14), (r, h * 0.34), (r * 0.62, h * 0.6), (r * 0.3, h * 0.8), (r * 0.08, h * 0.95), (0.0, h)], seg, lean=lean, wob=0.1)


def lantern(P, ring, glass_r=0.092):
    """The iron lantern the hanging lamp and the post share: ring at `ring`, hat, four posts, a foot, a candle, a hex belly of
    glass. Returns the flame point (ring - 0.28, the centre of the glass)."""
    x, y, z = ring
    rg = P.rng
    # the carrying ring (a forged eye)
    torus(P, "iron", (x, y + 0.035, z), 0.03, 0.0085, 6, 3)
    # hat: eave plate, stepped pyramid, finial nub
    lathe(P, "iron", (x, y, z), [(0.17, -0.1), (0.175, -0.075), (0.09, -0.03), (0.03, 0.0)], 4, rot=math.pi / 4, cap_bot=True)
    # four corner posts, each a little out of true, a cross-band between them
    for sx in (-1, 1):
        for sz in (-1, 1):
            bar(P, "iron", (x + sx * 0.098, y - 0.4, z + sz * 0.098), (x + sx * 0.104 + rg.uniform(-0.004, 0.004), y - 0.105, z + sz * 0.104), 0.028, 0.028, 1.0)
    lathe(P, "iron", (x, y - 0.27, z), [(0.152, -0.009), (0.152, 0.009)], 4, rot=math.pi / 4, cap_top=False)
    # foot: a plate, a cup beneath, three little feet
    lathe(P, "iron", (x, y, z), [(0.08, -0.485), (0.15, -0.44), (0.15, -0.415), (0.0, -0.415)], 4, rot=math.pi / 4, cap_top=False, cap_bot=True)
    # candle on a pricket, wax with a drip
    lathe(P, "wax", (x, y, z), [(0.03, -0.405), (0.025, -0.35), (0.0, -0.345)], 8)
    # glass: six-sided belly, centre at the flame point
    fp = (x, y - 0.28, z)
    s = glass_r / 0.092
    lathe(P, "glass", (x, y - 0.28, z), [(0.065 * s, -0.135), (0.095 * s, -0.03), (0.07 * s, 0.1), (0.03 * s, 0.135)], 6, cap_top=True, cap_bot=False)
    flame_mesh(P, (x, y - 0.345, z), h=0.19, r=0.034, seg=5, lean=0.0)
    return fp


def lantern_pane(P, fp):
    """The glazed square lantern: four flat panes in an iron frame. Origin is the flame."""
    x, y, z = fp
    rg = P.rng
    W = 0.105
    top, bot = y + 0.2, y - 0.22
    for sx in (-1, 1):
        for sz in (-1, 1):
            bar(P, "iron", (x + sx * W, bot, z + sz * W), (x + sx * W, top, z + sz * W), 0.03, 0.03, 0.92)
    # top and bottom rails and the glazing bar: bands that wrap all four faces
    for yy, h in ((top - 0.012, 0.013), (bot + 0.012, 0.013), (y - 0.01, 0.008)):
        lathe(P, "iron", (x, yy, z), [(W * 1.4142 + 0.006, -h), (W * 1.4142 + 0.006, h)], 4, rot=math.pi / 4, cap_top=False)
    for sg in (-1, 1):
        bar(P, "iron", (x, bot, z + sg * (W + 0.002)), (x, top, z + sg * (W + 0.002)), 0.012, 0.012)
    # hat: a deep eave, a steep pyramid, a vent cap and the bail handle
    lathe(P, "iron", (x, top, z), [(0.205, 0.0), (0.2, 0.025), (0.09, 0.09), (0.04, 0.13), (0.0, 0.15)], 4, rot=math.pi / 4, cap_bot=True)
    # bail handle: an arch of three bars over the hat
    p0, p1, p2, p3 = (x - 0.085, top + 0.035, z), (x - 0.05, top + 0.2, z), (x + 0.05, top + 0.2, z), (x + 0.085, top + 0.035, z)
    for a, b in ((p0, p1), (p1, p2), (p2, p3)):
        bar(P, "iron", a, b, 0.016, 0.016)
    torus(P, "iron", (x, top + 0.22, z), 0.022, 0.007, 6, 3)
    # base: tray with a lip, three feet
    lathe(P, "iron", (x, bot, z), [(0.13, -0.032), (0.195, 0.0), (0.145, 0.016)], 4, rot=math.pi / 4, cap_top=False, cap_bot=True)
    for a in (0.5, 2.6, 4.7):
        lathe(P, "iron", (x + 0.09 * math.cos(a), bot - 0.05, z + 0.09 * math.sin(a)), [(0.022, 0.0), (0.008, 0.045)], 4, cap_top=True)
    # candle and its dish
    lathe(P, "wax", (x, bot, z), [(0.034, 0.016), (0.028, 0.12), (0.0, 0.126)], 8)
    lathe(P, "iron", (x, bot, z), [(0.07, 0.018), (0.075, 0.032)], 6, cap_top=False, cap_bot=False)
    # four flat panes, a slight pillow so the facets catch light differently
    for k, (nx, nz) in enumerate(((0, 1), (1, 0), (0, -1), (-1, 0))):
        tx, tz = nz, nx          # tangent
        o = W - 0.018
        zc = [(x + nx * (W - 0.012) + tx * u, yy, z + nz * (W - 0.012) + tz * u) for u in (-o, o) for yy in (bot + 0.028, top - 0.028)]
        mid = (x + nx * (W - 0.002), (bot + top) / 2, z + nz * (W - 0.002))
        a, b, c, d = zc[0], zc[2], zc[3], zc[1]
        lo_m = ((a[0] + b[0]) / 2 + nx * 0.008, zc[0][1], (a[2] + b[2]) / 2 + nz * 0.008)
        hi_m = ((a[0] + b[0]) / 2 + nx * 0.008, zc[1][1], (a[2] + b[2]) / 2 + nz * 0.008)
        quad(P, "glass", a, lo_m, hi_m, d)
        quad(P, "glass", lo_m, b, c, hi_m)
        # sealing back-face (so it reads from inside); the game's material is double-sided anyway
    flame_mesh(P, (x, bot + 0.145, z), h=0.2, r=0.042, seg=5, lean=0.006)


# ---------------------------------------------------------------------------------------------------------
# the props
# ---------------------------------------------------------------------------------------------------------
def build_hang():
    P = Parts(11)
    # wall plate with rivets (origin: wall plane z = 0, +z out)
    box(P, "iron", (0, 0.0, 0.02), (0.14, 0.34, 0.04), jitter=0.002)
    for sy in (-0.13, 0.13):
        for sx in (-0.045, 0.045):
            lathe(P, "iron", (sx, sy, 0.04), [(0.016, 0.0), (0.0, 0.013)], 4, rot=0.4)
    # arm: a flat bar with a drooping tip, a rake strut and a scrolled curl by the wall
    bar(P, "iron", (0, 0.1, 0.03), (0, 0.1, 0.66), 0.045, 0.034, 0.85)
    bar(P, "iron", (0, -0.12, 0.04), (0, 0.085, 0.5), 0.034, 0.026, 0.9)
    prev = None
    for i in range(5):
        a = 0.4 + i * 1.2
        r = 0.075 - i * 0.011
        pt = (0, 0.0 + 0.06 + r * math.sin(a) * 0.9, 0.17 + r * math.cos(a) * 0.9)
        if prev:
            bar(P, "iron", prev, pt, 0.02, 0.02)
        prev = pt
    box(P, "iron", (0, 0.1, 0.67), (0.05, 0.05, 0.04), taper=0.7)
    bar(P, "iron", (0, 0.095, 0.64), (0, 0.0, 0.64), 0.02, 0.02)
    ring = (0, -0.035, 0.64)
    fp = lantern(P, ring)
    P.flame = Vector(fp)
    return P, {"FlamePoint": fp, "LightPoint": fp}, None


def arch_frame(P, key, outer, inner, z_back, z_out, z_front, z_in_back, chamfer=0.3, jitter=0.005):
    """A stone frame: `outer` and `inner` are equal-length (x, y) loops (ccw from the front). Five rings: the outer back, the outer face
    edge, a chamfer, the reveal's front edge and the reveal's back; quads between them, wound to face outward / forward / inward."""
    bm = P.of(key)
    rg = P.rng
    n = len(outer)
    cen = (sum(p[0] for p in inner) / n, sum(p[1] for p in inner) / n)
    mid = [(o[0] + (i[0] - o[0]) * chamfer, o[1] + (i[1] - o[1]) * chamfer) for o, i in zip(outer, inner)]
    rings = []
    raw = []
    for loop, z in ((outer, z_back), (outer, z_out), (mid, z_front), (inner, z_front), (inner, z_in_back)):
        pts = [(x + rg.uniform(-jitter, jitter), y + rg.uniform(-jitter, jitter), z + rg.uniform(-jitter, jitter) * 0.6) for (x, y) in loop]
        raw.append(pts)
        rings.append([bm.verts.new(B(p)) for p in pts])
    wants = ("out", "out", "front", "in")
    for r in range(4):
        for k in range(n):
            k2 = (k + 1) % n
            f = (rings[r][k], rings[r][k2], rings[r + 1][k2], rings[r + 1][k])
            p = [raw[r][k], raw[r][k2], raw[r + 1][k2], raw[r + 1][k]]
            e1 = Vector(p[1]) - Vector(p[0])
            e2 = Vector(p[2]) - Vector(p[0])
            nn = e1.cross(e2)
            if nn.length < 1e-9:
                e2 = Vector(p[3]) - Vector(p[0])
                nn = e1.cross(e2)
            m = [(p[0][i] + p[1][i] + p[2][i] + p[3][i]) / 4 for i in range(3)]
            if wants[r] == "out":
                want = Vector((m[0] - cen[0], m[1] - cen[1], 0.0))
                if r == 0:
                    pass
            elif wants[r] == "in":
                want = Vector((cen[0] - m[0], cen[1] - m[1], 0.0))
            else:
                want = Vector((0, 0, 1))
            bm.faces.new(f if nn.dot(want) > 0 else f[::-1])


def build_niche():
    P = Parts(21)
    outer = [(-0.34, 0.0), (0.34, 0.0), (0.34, 0.58), (0.32, 0.75), (0.2, 0.87), (0.0, 0.94), (-0.2, 0.87), (-0.32, 0.75), (-0.34, 0.58)]
    inner = [(-0.2, 0.07), (0.2, 0.07), (0.2, 0.5), (0.17, 0.62), (0.09, 0.71), (0.0, 0.76), (-0.09, 0.71), (-0.17, 0.62), (-0.2, 0.5)]
    arch_frame(P, "ashlar", outer, inner, 0.0, 0.21, 0.25, 0.04)
    # the sooted back of the recess
    bm = P.of("dark")
    bk = [bm.verts.new(B((x, y, 0.045))) for (x, y) in inner]
    bm.faces.new(bk)
    # a keystone and a corbelled sill lip, a chipped corner, a fallen chip
    box(P, "ashlar", (0, 0.9, 0.2), (0.15, 0.09, 0.12), jitter=0.004, taper=0.8)
    box(P, "ashlar", (0, 0.03, 0.22), (0.7, 0.06, 0.12), jitter=0.005, bevel=0.01)
    box(P, "ashlar", (0.31, 0.04, 0.31), (0.07, 0.06, 0.07), yaw=0.5, jitter=0.012)
    box(P, "ashlar", (-0.22, 0.02, 0.33), (0.06, 0.04, 0.05), yaw=0.2, jitter=0.01)
    # moss tufts clinging to the lip
    for mx in (-0.27, 0.24):
        lathe(P, "moss", (mx, 0.05, 0.3), [(0.032, 0.0), (0.02, 0.025), (0.0, 0.035)], 5, wob=0.2)
    # wax: the burning candle on a puddle, its drips, and a stub beside it
    lathe(P, "wax", (0, 0.07, 0.12), [(0.075, 0.0), (0.04, 0.016)], 8, cap_top=False)
    lathe(P, "wax", (0, 0.07, 0.12), [(0.034, 0.0), (0.027, 0.12), (0.0, 0.118)], 8)
    lathe(P, "wax", (0.13, 0.07, 0.16), [(0.028, 0.0), (0.025, 0.05), (0.0, 0.055)], 8)
    for ang, ln in ((0.5, 0.08), (4.3, 0.09)):
        ax, az = 0.0265 * math.cos(ang), 0.0265 * math.sin(ang)
        bar(P, "wax", (ax, 0.07 + 0.115, 0.12 + az), (ax * 1.02, 0.07 + 0.115 - ln, 0.12 + az * 1.02), 0.012, 0.009, 0.5)
    fp = (0, 0.2, 0.12)
    flame_mesh(P, fp, h=0.23, r=0.04, seg=5, lean=0.012)
    P.flame = Vector(fp)
    # Plinth (free-standing niche): sits under the niche in niche-local coords (niche shifted up .66, back .14)
    Q = Parts(22)
    box(Q, "ashlar", (0, -0.36, 0.14), (0.74, 0.6, 0.5), jitter=0.008, cuts=1, taper=0.96)
    box(Q, "ashlar", (0, -0.045, 0.14), (0.82, 0.07, 0.58), jitter=0.006, cuts=1)
    col = Parts(23)
    box(col, "col", (0, 0.45, 0.12), (0.7, 0.9, 0.26))
    return P, {"FlamePoint": fp, "LightPoint": (0, 0.3, 0.37)}, col, Q


def build_post():
    P = Parts(31)
    stone_j = 0.006
    # a stepped plinth
    box(P, "ashlar", (0, 0.05, 0), (0.42, 0.1, 0.42), yaw=0.1, jitter=stone_j, bevel=0.012)
    box(P, "ashlar", (0, 0.17, 0), (0.32, 0.14, 0.32), yaw=-0.08, jitter=stone_j, bevel=0.01)
    box(P, "ashlar", (0, 0.25, 0), (0.36, 0.035, 0.36), yaw=0.05, jitter=0.004)
    # an octagonal post, slightly tapered, with three iron bands and a spiral of nail heads
    lathe(P, "wood", (0, 0, 0), [(0.058, 0.26), (0.048, 1.88)], 8, rot=math.pi / 8, smooth=False)
    for by in (0.5, 1.2, 1.76):
        lathe(P, "iron", (0, by, 0), [(0.074, -0.022), (0.074, 0.022)], 8, rot=math.pi / 8, cap_top=False)
    for i in range(3):
        a = i * 2.1
        y = 0.7 + i * 0.25
        box(P, "iron", (0.054 * math.cos(a), y, 0.054 * math.sin(a)), (0.016, 0.016, 0.016), yaw=a, taper=0.5)
    # top plate the lantern stands on, with a lip
    lathe(P, "iron", (0, 1.84, 0), [(0.135, 0.0), (0.135, 0.032), (0.1, 0.038)], 8, rot=math.pi / 8, cap_top=False, cap_bot=True)
    # two scrolled brackets
    for sg in (-1, 1):
        bar(P, "iron", (sg * 0.05, 1.56, 0), (sg * 0.13, 1.84, 0), 0.026, 0.026, 0.9)
    fp = lantern(P, (0, 2.34, 0))
    P.flame = Vector(fp)
    col = Parts(33)
    box(col, "col", (0, 1.0, 0), (0.3, 2.0, 0.3))
    return P, {"FlamePoint": fp, "LightPoint": (fp[0], fp[1] + 0.05, fp[2])}, col


def build_pane():
    P = Parts(41)
    fp = (0.0, 0.0, 0.0)
    lantern_pane(P, fp)
    P.flame = Vector(fp)
    return P, {"FlamePoint": fp, "LightPoint": fp}, None


def build_cresset():
    P = Parts(51)
    rg = P.rng
    # three forged legs, splayed, each ending in a small foot; a ring brace bound at a third of the height
    for i in range(3):
        a = math.tau * i / 3 + 0.3
        lo = (math.cos(a) * 0.31, 0.0, math.sin(a) * 0.31)
        hi = (math.cos(a) * 0.1, 0.9, math.sin(a) * 0.1)
        bar(P, "iron", lo, hi, 0.052, 0.052, 0.82, jitter=0.0015)
        box(P, "iron", (lo[0] * 1.06, 0.015, lo[2] * 1.06), (0.09, 0.03, 0.09), yaw=-a, jitter=0.004, taper=0.8)
        a2 = a + math.tau / 3
        mid1 = (math.cos(a) * 0.19, 0.38, math.sin(a) * 0.19)
        mid2 = (math.cos(a2) * 0.19, 0.38, math.sin(a2) * 0.19)
        bar(P, "iron", mid1, mid2, 0.028, 0.028)
        box(P, "iron", mid1, (0.058, 0.05, 0.058), yaw=-a)                          # a wrapped collar
    # the basket: a floor, a rim and a hoop with slats bowing outward, a coal bed and charred logs inside
    lathe(P, "iron", (0, 0.84, 0), [(0.06, 0.0), (0.14, 0.03), (0.14, 0.05)], 8, cap_top=False, cap_bot=True)
    lathe(P, "iron", (0, 1.1, 0), [(0.29, -0.03), (0.335, 0.0), (0.29, 0.035)], 8, rot=0.15, cap_top=False)
    lathe(P, "iron", (0, 0.97, 0), [(0.205, -0.014), (0.205, 0.014)], 8, cap_top=False)
    for i in range(8):
        a = math.tau * i / 8 + 0.2
        bar(P, "iron", (math.cos(a) * 0.1, 0.86, math.sin(a) * 0.1), (math.cos(a) * 0.31, 1.1, math.sin(a) * 0.31), 0.028, 0.022)
    lathe(P, "dark", (0, 0.98, 0), [(0.24, 0.0), (0.0, 0.06)], 8, cap_top=False, cap_bot=True)
    for a, yaw in ((0.1, 0.5), (2.3, 1.6), (4.2, 0.2)):
        box(P, "dark", (0.1 * math.cos(a), 1.03, 0.1 * math.sin(a)), (0.22, 0.05, 0.05), yaw=yaw, jitter=0.006)
    for sg in (-1, 1):                                                        # two carrying rings on the rim
        torus(P, "iron", (sg * 0.345, 1.1, 0), 0.032, 0.008, 6, 3, yaw=math.pi / 2)
    fp = (0, 1.02, 0)
    flame_mesh(P, fp, h=0.54, r=0.13, seg=7, lean=0.05)
    P.flame = Vector(fp)
    col = Parts(53)
    box(col, "col", (0, 0.55, 0), (0.5, 1.1, 0.5))
    return P, {"FlamePoint": fp, "LightPoint": (0, 1.45, 0)}, col


def build_ember():
    P = Parts(61)
    rg = P.rng
    # hewn footing (two stones) on the ground
    box(P, "ashlar", (0, 0.1, 0), (0.6, 0.3, 0.6), yaw=0.12, jitter=0.01, cuts=1, taper=0.95)
    box(P, "ashlar", (0, 0.3, 0), (0.42, 0.14, 0.42), yaw=-0.2, jitter=0.008, bevel=0.012)
    # the post: octagonal timber, collars, nails
    lathe(P, "wood", (0, 0, 0), [(0.07, 0.36), (0.055, 2.6)], 12)
    lathe(P, "iron", (0, 0.45, 0), [(0.094, -0.035), (0.094, 0.035)], 8, rot=math.pi / 8, cap_top=False)
    lathe(P, "iron", (0, 2.2, 0), [(0.078, -0.028), (0.078, 0.028)], 8, rot=math.pi / 8, cap_top=False)
    for i in range(3):
        a = i * 1.9
        box(P, "iron", (0.062 * math.cos(a), 0.9 + i * 0.4, 0.062 * math.sin(a)), (0.018, 0.018, 0.018), yaw=a, taper=0.5)
    # the arm, its iron brace and cap
    bar(P, "wood", (-0.04, 2.5, 0), (0.68, 2.5, 0), 0.05, 0.05, 0.85, jitter=0.002)
    bar(P, "iron", (0.04, 2.2, 0), (0.42, 2.47, 0), 0.036, 0.026)
    box(P, "iron", (0.0, 2.64, 0), (0.1, 0.07, 0.1), yaw=0.3, taper=0.5)             # post cap
    box(P, "iron", (0.68, 2.5, 0), (0.07, 0.07, 0.07), taper=0.7)                    # arm end ferrule
    # chain of two links and the hook down to the cage
    torus(P, "iron", (0.62, 2.43, 0), 0.026, 0.007, 6, 3)
    torus(P, "iron", (0.62, 2.385, 0), 0.026, 0.007, 6, 3, yaw=math.pi / 2)
    # the cage: top ring, bowl ring, six slim bars, a little cap
    cx, cy = 0.62, 2.05
    lathe(P, "iron", (cx, cy + 0.19, 0), [(0.13, -0.012), (0.13, 0.012)], 8, cap_top=False)
    lathe(P, "iron", (cx, cy - 0.19, 0), [(0.07, -0.03), (0.13, 0.015)], 8, cap_top=False, cap_bot=True)
    for i in range(4):
        a = math.tau * i / 4 + 0.2
        bar(P, "iron", (cx + math.cos(a) * 0.12, cy - 0.17, math.sin(a) * 0.12), (cx + math.cos(a) * 0.12, cy + 0.19, math.sin(a) * 0.12), 0.014, 0.014)
    lathe(P, "iron", (cx, cy + 0.2, 0), [(0.14, 0.0), (0.05, 0.075), (0.0, 0.09)], 8, cap_top=False)
    # the coal: an irregular lump, its own mesh (Flame) so the game keeps toggling its material
    lathe(P, "flame", (cx, cy - 0.15, 0), [(0.0, 0.0), (0.085, 0.06), (0.06, 0.125), (0.0, 0.155)], 6, wob=0.18, cap_bot=True)
    bar(P, "wood", (0.03, 2.16, 0), (0.4, 2.47, 0), 0.04, 0.036, 0.9)
    for nx in (0.2, 0.34, 0.5):
        box(P, "iron", (nx, 2.527, 0.0), (0.016, 0.016, 0.016), taper=0.5)
    fp = (cx, cy - 0.08, 0)
    P.flame = Vector(fp)
    P.coal = True
    col = Parts(63)
    lathe(col, "col", (0, 0, 0), [(0.22, 0.0), (0.22, 2.3)], 8, cap_bot=True)
    return P, {"FlamePoint": fp, "LightPoint": fp, "SparkPoint": (cx, cy + 0.3, 0)}, col


# ---------------------------------------------------------------------------------------------------------
# finishing: vertex colours, objects, materials, export
# ---------------------------------------------------------------------------------------------------------
def tone(P, key, co, n, zlo, zhi):
    """Vertex colour for a Blender-space vertex. For the textured sets (stone / timber / iron / wax) it is a TONE multiplier on the
    set's albedo (about 1.0: grime, moss at the foot, soot, rust, worn edges); flame and glass carry their own colour."""
    up = max(n.z, 0.0)
    g = B_inv(co)                           # Godot point
    d = (g - P.flame)
    soot = math.exp(-(d.length_squared) / 0.5) * 0.55 if key not in ("flame", "glass") else 0.0
    if key in ("stone", "ashlar"):
        v = 1.0 + 0.22 * fbm(co * 5.0 + Vector((3, 1, 7))) + 0.05 * noise.noise(co * 23.0)
        moss = smooth(-0.2, 0.25, fbm(co * 7.0 + Vector((1, 8, 2)))) * (1.0 - smooth(0.0, 0.45, g.y - zlo_g(P))) * (0.4 + 0.6 * up)
        c = Vector((v * 1.02, v, v * 0.95)).lerp(Vector((0.55, 0.85, 0.45)), 0.7 * moss)
        return c * (1.0 - soot * 0.8)
    if key == "iron":
        rs = smooth(0.0, 0.5, fbm(co * 11.0 + Vector((2, 2, 9))) + 0.22)
        c = Vector((1.0, 1.0, 1.0)).lerp(Vector((1.15, 0.85, 0.7)), rs * 0.6)
        c = c * (1.0 + 0.3 * up * (1.0 - rs))                                   # worn tops
        return c * (1.0 - soot * 0.8)
    if key == "wood":
        gr = 0.9 + 0.2 * (0.5 + 0.5 * fbm(Vector((co.x * 20, co.y * 20, co.z * 3))))
        return Vector((gr, gr, gr)) * (1.0 - soot * 0.9)
    if key == "moss":
        return Vector((0.5, 0.85, 0.35)) * (0.8 + 0.4 * (0.5 + fbm(co * 30.0)))
    if key == "wax":
        return Vector((1.0, 0.98, 0.92)) * (0.88 + 0.12 * up) * (1.0 - soot * 0.5)
    if key == "dark":
        return Vector((0.22, 0.22, 0.22)) * (0.6 + 0.8 * smooth(0.0, 0.8, g.y - zlo_g(P)))
    if key == "flame" and getattr(P, "coal", False):
        t = (co.z - zlo) / max(zhi - zlo, 1e-4)
        hot = smooth(0.0, 1.0, 0.5 + 0.9 * fbm(co * 38.0))
        return Vector((0.25, 0.07, 0.03)).lerp(Vector((1.0, 0.5, 0.14)), hot * (0.4 + 0.6 * (1 - t)))
    if key == "flame":
        t = (co.z - zlo) / max(zhi - zlo, 1e-4)
        return Vector((1.0, 0.74, 0.34)).lerp(Vector((0.88, 0.28, 0.07)), smooth(0.1, 0.95, t))
    return Vector((0.5, 0.5, 0.5))


def zlo_g(P):
    return getattr(P, "ground_y", 0.0)


def B_inv(co):
    return Vector((co.x, co.z, -co.y))


def finish(P, name, prefix="Body"):
    """Objects: <prefix>__<set> for each textured set (timber / iron / stone / wax: metric box UVs, tone vertex colours),
    Glass, Flame, Col-colonly. Returns {object name: obj}."""
    out = {}
    sets = {}
    for key, bm in P.bm.items():
        if key in ("glass",):
            bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces) if key in ("stone", "dark", "moss") and False else None
        bm.normal_update()
        zs = [v.co.z for v in bm.verts] or [0.0]
        zlo, zhi = min(zs), max(zs)
        st = SETOF.get(key)
        tile = TILE.get(st, 4.0)
        uv = bm.loops.layers.uv.new("UVMap")
        col = bm.loops.layers.color.new("Col")
        for fi, f in enumerate(bm.faces):
            if key in ("flame", "glass"):
                f.smooth = True
            fv = random.Random(fi * 13 + 5).uniform(0.9, 1.08) if key == "stone" else 1.0
            fr = random.Random(fi * 7 + 3).uniform(0.82, 1.08) if key == "glass" else 1.0
            n = f.normal
            ax = max(range(3), key=lambda i: abs(n[i]))
            grain = None
            if key == "wood":
                le = max(f.edges, key=lambda e: e.calc_length())
                d = (le.verts[1].co - le.verts[0].co).normalized()
                t1 = n.cross(d)
                if t1.length > 1e-6:
                    grain = (t1.normalized(), d)
            for l in f.loops:
                co = l.vert.co
                if grain is not None:
                    l[uv].uv = (co.dot(grain[0]) / tile, co.dot(grain[1]) / tile)
                elif ax == 0:
                    l[uv].uv = (co.y / tile, co.z / tile)
                elif ax == 1:
                    l[uv].uv = (co.x / tile, co.z / tile)
                else:
                    l[uv].uv = (co.x / tile, co.y / tile)
                if key == "glass":
                    t = (co.z - zlo) / max(zhi - zlo, 1e-4)
                    c = Vector((0.62, 0.38, 0.16)).lerp(Vector((0.3, 0.2, 0.1)), smooth(0.3, 1.0, t)) * fr
                else:
                    c = tone(P, key, co, l.vert.normal, zlo, zhi) * fv
                l[col] = (min(c.x, 1.5), min(c.y, 1.5), min(c.z, 1.5), 1.0)
        if key in ("glass", "flame"):
            me = bpy.data.meshes.new("%s_%s" % (name, key))
            bm.to_mesh(me)
            bm.free()
            ob = bpy.data.objects.new(key.capitalize(), me)
            bpy.context.scene.collection.objects.link(ob)
            me.color_attributes.active_color = me.color_attributes["Col"]
            out[key.capitalize()] = ob
        elif key == "col":
            me = bpy.data.meshes.new("%s_col" % name)
            bm.to_mesh(me)
            bm.free()
            ob = bpy.data.objects.new("Col-colonly", me)
            bpy.context.scene.collection.objects.link(ob)
            out["Col-colonly"] = ob
        else:
            tmp = bpy.data.meshes.new("t")
            bm.to_mesh(tmp)
            bm.free()
            sets.setdefault(st, bmesh.new()).from_mesh(tmp)
            bpy.data.meshes.remove(tmp)
    for st, bm in sets.items():
        me = bpy.data.meshes.new("%s_%s_%s" % (name, prefix, st))
        bm.to_mesh(me)
        bm.free()
        ob = bpy.data.objects.new("%s__%s" % (prefix, st), me)
        bpy.context.scene.collection.objects.link(ob)
        me.color_attributes.active_color = me.color_attributes["Col"]
        out[ob.name] = ob
    return out


def is_body(n):
    return n.startswith("Body__") or n.startswith("Plinth__")


def tris(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


def set_mat(st, textured):
    """Per-set material: bare (export, as r37_west.py) or built from the game's PNGs (preview: albedo * tone, normal, ORM)."""
    nm = st + ("_tex" if textured else "")
    if nm in bpy.data.materials:
        return bpy.data.materials[nm]
    m = bpy.data.materials.new(st if not textured else nm)
    m.use_nodes = True
    if not textured:
        return m
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]

    def img(kind, cs):
        n = nt.nodes.new("ShaderNodeTexImage")
        n.image = bpy.data.images.load(os.path.join(ROOT, "art", "textures", "r37_%s_%s.png" % (st, kind)), check_existing=True)
        n.image.colorspace_settings.name = cs
        return n
    alb, nrm, orm = img("albedo", "sRGB"), img("normal", "Non-Color"), img("orm", "Non-Color")
    vc = nt.nodes.new("ShaderNodeVertexColor")
    vc.layer_name = "Col"
    mul = nt.nodes.new("ShaderNodeMix")
    mul.data_type = 'RGBA'
    mul.blend_type = 'MULTIPLY'
    mul.inputs[0].default_value = 1.0
    nt.links.new(alb.outputs[0], mul.inputs[6])
    nt.links.new(vc.outputs[0], mul.inputs[7])
    sep = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(orm.outputs[0], sep.inputs[0])
    ao = nt.nodes.new("ShaderNodeMix")
    ao.data_type = 'RGBA'
    ao.blend_type = 'MULTIPLY'
    ao.inputs[0].default_value = 1.0
    nt.links.new(mul.outputs[2], ao.inputs[6])
    nt.links.new(sep.outputs[0], ao.inputs[7])
    nt.links.new(ao.outputs[2], bsdf.inputs["Base Color"])
    nt.links.new(sep.outputs[1], bsdf.inputs["Roughness"])
    nt.links.new(sep.outputs[2], bsdf.inputs["Metallic"])
    nm_ = nt.nodes.new("ShaderNodeNormalMap")
    nm_.inputs[0].default_value = 1.0
    nt.links.new(nrm.outputs[0], nm_.inputs[1])
    nt.links.new(nm_.outputs[0], bsdf.inputs["Normal"])
    return m


def mat_for(name, mode):
    """mode: 'export' (plain, vertex colour), 'cold', 'lit'."""
    key = "%s_%s" % (name, mode)
    nm = name if mode == "export" else key
    if nm in bpy.data.materials:
        return bpy.data.materials[nm]
    m = bpy.data.materials.new(name if mode == "export" else key)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    vc = nt.nodes.new("ShaderNodeVertexColor")
    vc.layer_name = "Col"
    nt.links.new(vc.outputs[0], bsdf.inputs["Base Color"])
    if name == "Body":
        bsdf.inputs["Roughness"].default_value = 0.8
        bsdf.inputs["Metallic"].default_value = 0.0
    elif name == "Glass":
        bsdf.inputs["Roughness"].default_value = 0.25
        if mode == "lit":
            bsdf.inputs["Base Color"].default_value = (0.5, 0.2, 0.05, 1)
            nt.links.remove(vc.outputs[0].links[0])
            bsdf.inputs["Emission Color"].default_value = (1.0, 0.42, 0.12, 1)
            bsdf.inputs["Emission Strength"].default_value = 0.9
            bsdf.inputs["Alpha"].default_value = 0.55
            m.surface_render_method = 'BLENDED'
            m.use_backface_culling = False
        elif mode == "cold":
            bsdf.inputs["Roughness"].default_value = 0.2
            nt.links.remove(vc.outputs[0].links[0])
            bsdf.inputs["Base Color"].default_value = (0.05, 0.06, 0.08, 1)
            bsdf.inputs["Emission Color"].default_value = (0.5, 0.64, 0.95, 1)
            bsdf.inputs["Emission Strength"].default_value = 0.05
            bsdf.inputs["Alpha"].default_value = 0.6
            m.surface_render_method = 'BLENDED'
        else:
            bsdf.inputs["Emission Color"].default_value = (0.95, 0.46, 0.16, 1)
            bsdf.inputs["Emission Strength"].default_value = 0.0
    elif name == "Flame":
        bsdf.inputs["Roughness"].default_value = 1.0
        nt.links.new(vc.outputs[0], bsdf.inputs["Emission Color"])
        bsdf.inputs["Base Color"].default_value = (0.02, 0.01, 0.0, 1)
        bsdf.inputs["Emission Strength"].default_value = 1.5 if mode == "lit" else 0.4
    return m


def add_empty(name, g):
    e = bpy.data.objects.new(name, None)
    e.empty_display_type = 'PLAIN_AXES'
    e.empty_display_size = 0.04
    e.location = B(g)
    bpy.context.scene.collection.objects.link(e)
    return e


def export(objs, path):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    kw = dict(filepath=path, export_format='GLB', use_selection=True, export_apply=True, export_yup=True,
              export_materials='EXPORT', export_image_format='NONE', export_normals=True, export_texcoords=True)
    try:
        bpy.ops.export_scene.gltf(export_vertex_color='ACTIVE', export_active_vertex_color_when_no_material=True, **kw)
    except TypeError:
        try:
            bpy.ops.export_scene.gltf(export_vertex_color='ACTIVE', **kw)
        except TypeError:
            bpy.ops.export_scene.gltf(**kw)


# ---------------------------------------------------------------------------------------------------------
# preview: neutral and night light, lit and unlit; four views + (niche) a free-standing view
# ---------------------------------------------------------------------------------------------------------
def setup_render():
    sc = bpy.context.scene
    for eng in ('BLENDER_EEVEE', 'BLENDER_EEVEE_NEXT', 'BLENDER_WORKBENCH'):
        try:
            sc.render.engine = eng
            break
        except TypeError:
            continue
    sc.render.resolution_x = sc.render.resolution_y = 960
    try:
        sc.eevee.taa_render_samples = 48
    except Exception:
        pass
    try:
        sc.view_settings.view_transform = 'Standard'
    except Exception:
        pass
    return sc


def clear_lights():
    for o in list(bpy.data.objects):
        if o.type in ('LIGHT',) or o.name.startswith("_bg"):
            bpy.data.objects.remove(o, do_unlink=True)


def render_set(spec, objs, folder, tag, mode, lit):
    """mode 'neutral' | 'night'."""
    sc = setup_render()
    clear_lights()
    w = bpy.data.worlds.get("w") or bpy.data.worlds.new("w")
    w.use_nodes = True
    bg = w.node_tree.nodes["Background"]
    sc.world = w
    if mode == "neutral":
        bg.inputs[0].default_value = (0.42, 0.43, 0.46, 1)
        bg.inputs[1].default_value = 0.8
        sun = bpy.data.lights.new("_bgsun", 'SUN')
        sun.energy = 3.0
        so = bpy.data.objects.new("_bgsun", sun)
        sc.collection.objects.link(so)
        so.rotation_euler = (math.radians(55), 0, math.radians(30))
        sun2 = bpy.data.lights.new("_bgfill", 'SUN')
        sun2.energy = 1.0
        so2 = bpy.data.objects.new("_bgfill", sun2)
        sc.collection.objects.link(so2)
        so2.rotation_euler = (math.radians(80), 0, math.radians(-120))
    else:
        bg.inputs[0].default_value = (0.03, 0.045, 0.14, 1)
        bg.inputs[1].default_value = 0.8
        sun = bpy.data.lights.new("_bgmoon", 'SUN')
        sun.energy = 1.6
        sun.color = (0.52, 0.62, 1.0)
        so = bpy.data.objects.new("_bgmoon", sun)
        sc.collection.objects.link(so)
        so.rotation_euler = (math.radians(55), 0, math.radians(-35))
        if lit:
            wl = bpy.data.lights.new("_bgfire", 'POINT')
            wl.energy = spec.get("watts", 25)
            wl.color = (1.0, 0.6, 0.3)
            wl.shadow_soft_size = 0.05
            wl.use_shadow = False
            wo = bpy.data.objects.new("_bgfire", wl)
            sc.collection.objects.link(wo)
            wo.location = B(spec["light"])
    # materials
    for n, o in objs.items():
        if n == "Col-colonly":
            o.hide_render = True
            continue
        if o.type != 'MESH':
            continue
        o.data.materials.clear()
        mm = mode_mat(n, lit)
        o.data.materials.append(mm)
        if n == "Flame":
            o.hide_render = not lit
        if n == "Col-colonly":
            o.hide_render = True
    cam_d = bpy.data.cameras.get("cam") or bpy.data.cameras.new("cam")
    cam = bpy.data.objects.get("cam") or bpy.data.objects.new("cam", cam_d)
    if "cam" not in sc.collection.objects:
        sc.collection.objects.link(cam)
    sc.camera = cam
    cam_d.clip_end = 100
    cam_d.lens = 55
    for i, (yaw, el, dist_k, target, extra) in enumerate(spec["views"]):
        bg_set(spec, extra)
        t = Vector(target)
        dist = spec["size"] * dist_k
        cx = t.x + dist * math.cos(el) * math.sin(yaw)
        cy = t.y + dist * math.sin(el)
        cz = t.z + dist * math.cos(el) * math.cos(yaw)
        cam.location = B((cx, cy, cz))
        cam.rotation_euler = (B(t) - B((cx, cy, cz))).to_track_quat('-Z', 'Y').to_euler()
        sc.render.filepath = os.path.join(folder, "%s_%s_%d.png" % (tag, mode, i))
        bpy.ops.render.render(write_still=True)


def mode_mat(n, lit):
    if n == "Glass":
        return mat_for("Glass", "lit" if lit else "cold")
    if n == "Flame":
        return mat_for("Flame", "lit")
    return set_mat(n.split("__")[1], True)


BACKDROP = {}


def bg_set(spec, extra):
    """The wall (wall props) or the ground (post props); `extra` 'free' shows the plinth and the ground instead of the wall."""
    sc = bpy.context.scene
    for o in list(bpy.data.objects):
        if o.name.startswith("_bg_"):
            bpy.data.objects.remove(o, do_unlink=True)
    kind = spec["backdrop"]
    if extra == "free":
        kind = "ground_low"
    if kind == "none":
        pass
    elif kind == "wall":
        me = bpy.data.meshes.new("_bg_w")
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Diagonal((4, 0.3, 3, 1)))
        bm.to_mesh(me)
        bm.free()
        ob = bpy.data.objects.new("_bg_wall", me)
        ob.location = B((0, 0.4, -0.15))
        sc.collection.objects.link(ob)
        m = bpy.data.materials.get("_bgwall") or bpy.data.materials.new("_bgwall")
        m.use_nodes = True
        m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.12, 0.115, 0.11, 1)
        m.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.9
        ob.data.materials.append(m)
    else:
        y = -0.66 if kind == "ground_low" else spec.get("ground", 0.0)
        me = bpy.data.meshes.new("_bg_g")
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=True, segments=48, radius1=2.5, radius2=2.5, depth=0.2)
        bm.to_mesh(me)
        bm.free()
        ob = bpy.data.objects.new("_bg_ground", me)
        ob.location = B((0, y - 0.1, 0.0 if extra != "free" else 0.14))
        sc.collection.objects.link(ob)
        m = bpy.data.materials.get("_bgground") or bpy.data.materials.new("_bgground")
        m.use_nodes = True
        m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.07, 0.085, 0.055, 1)
        m.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.95
        ob.data.materials.append(m)
    # the free niche: show / hide the plinth
    for pl in bpy.data.objects:
        if pl.name.startswith("Plinth__"):
            pl.hide_render = extra != "free"


def views_for(c, h, fl, free=False, wall=False):
    """(yaw, elevation, distance factor, target, extra): front, three-quarter, side, close-up on the flame (Godot coordinates)."""
    mid = (c[0], c[1], c[2])
    v = [(0.0, 0.12, 2.0, mid, None), (math.radians(40), 0.25, 2.0, mid, None), (math.radians(90), 0.1, 2.0, mid, None),
         (math.radians(25), 0.3, 0.8, fl, None)]
    if wall:
        v[2] = (math.radians(70), 0.1, 2.0, mid, None)
    if free:
        v.append((math.radians(35), 0.2, 2.6, (0, 0.0, 0.1), "free"))
    return v


def run(label, build, spec_in):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    res = build()
    P, pts, col = res[0], res[1], res[2]
    Q = res[3] if len(res) > 3 else None
    objs = finish(P, label)
    if col is not None:
        objs.update({k: v for k, v in finish(col, label + "c").items() if k == "Col-colonly"})
        for k in [k for k in list(bpy.data.objects.keys()) if k == "Body" or k == "Glass" or k == "Flame"]:
            pass
    if Q is not None:
        objs.update(finish(Q, label + "q", prefix="Plinth"))
    # `finish` of the collider made an empty extra Body; drop strays by name collision
    for ob in list(bpy.data.objects):
        if ob.type == 'MESH' and ob.name.startswith("Body.") or (ob.type == 'MESH' and len(ob.data.polygons) == 0):
            bpy.data.objects.remove(ob, do_unlink=True)
    empties = {n: add_empty(n, g) for n, g in pts.items()}
    # export materials
    for n, o in objs.items():
        if is_body(n):
            o.data.materials.clear()
            o.data.materials.append(set_mat(n.split("__")[1], False))
        elif n in ("Glass", "Flame"):
            o.data.materials.clear()
            o.data.materials.append(mat_for(n, "export"))
    # report
    near = {n: tris(o) for n, o in objs.items() if is_body(n) or n in ("Glass", "Flame")}
    allbb = [o for n, o in objs.items() if n.startswith("Body__") or n in ("Glass", "Flame")]
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for o in allbb:
        for v in o.data.vertices:
            g = B_inv(v.co)
            for i in range(3):
                lo[i] = min(lo[i], g[i])
                hi[i] = max(hi[i], g[i])
    size = hi - lo
    total = sum(near[n] for n in near if not n.startswith("Plinth"))
    print("RESULT %s tris %s total(near, no plinth) %d size %.3f x %.3f x %.3f  y %.3f..%.3f  x %.3f..%.3f z %.3f..%.3f" % (
        label, near, total, size.x, size.y, size.z, lo.y, hi.y, lo.x, hi.x, lo.z, hi.z))
    objs_all = dict(objs)
    if EXPORT:
        os.makedirs(MODELS, exist_ok=True)
        sel = [o for n, o in objs.items()] + list(empties.values())
        export(sel, os.path.join(MODELS, "%s.glb" % label))
        print("EXPORTED", label)
    if PREVIEW:
        os.makedirs(PREVIEW, exist_ok=True)
        c = (lo + hi) * 0.5
        spec = dict(spec_in)
        spec["size"] = max(size.x, size.y, size.z, 0.5)
        spec["light"] = pts["LightPoint"]
        spec["views"] = views_for((c.x, c.y, c.z), size.y, pts["FlamePoint"], free=spec_in.get("free", False), wall=spec_in["backdrop"] == "wall")
        for mode, lit, tag in (("neutral", False, "a_unlit"), ("night", False, "b_unlit"), ("night", True, "c_lit")):
            render_set(spec, objs_all, PREVIEW, "%s_%s" % (label, tag), mode, lit)


ASSETS = {
    "hang": ("lamp_hang", build_hang, {"backdrop": "wall", "watts": 14}),
    "niche": ("lamp_niche", build_niche, {"backdrop": "wall", "watts": 6, "free": True}),
    "post": ("lamp_post", build_post, {"backdrop": "ground", "watts": 30}),
    "pane": ("lamp_pane", build_pane, {"backdrop": "none", "watts": 14}),
    "cresset": ("lamp_cresset", build_cresset, {"backdrop": "ground", "watts": 180}),
    "ember": ("ember_post", build_ember, {"backdrop": "ground", "watts": 40, "ground": -0.05}),
}

if __name__ == "__main__":
    for k, (label, fn, spec) in ASSETS.items():
        if ONLY and k not in ONLY:
            continue
        print("=== ", k)
        run(label, fn, spec)
