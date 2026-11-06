"""r37 East Marches assets, built by script (docs/r37_expansion.md; umbral-blender skill). Nothing
downloaded: the stone, timber, salt crust, plaster, slate and iron are generated here with numpy
(Blender's own) as tileable albedo / normal / ORM maps and embedded in the GLBs.

  tools/blender/run.sh r37_east.py            (writes the GLBs, the box tables, a preview if asked)
  tools/blender/run.sh r37_east.py -- --preview /tmp/r37e   (also renders stills)

Writes art/models/r37e_{spire,cells,saltworks,hamlet}.glb and core/world/realm/r37_east_boxes.gd
(collision boxes and ramps taken from the same numbers as the meshes, so they cannot drift).
Units: 1 BU = 1 m, +Z is the front of every piece (the way it faces), origin on the ground.
"""
import bpy
import bmesh
import math
import os
import sys
import json
import numpy as np
from mathutils import Vector, Euler, Matrix

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
PREVIEW = args[args.index("--preview") + 1] if "--preview" in args else ""

# ================================================================== textures
N = 1024


def vnoise(n, cells, seed):
    rng = np.random.default_rng(seed)
    g = rng.random((cells, cells)).astype(np.float32)
    xs = np.linspace(0, cells, n, endpoint=False)
    i = xs.astype(int)
    f = (xs - i).astype(np.float32)
    f = f * f * (3 - 2 * f)
    i1 = (i + 1) % cells
    a = g[np.ix_(i, i)]
    b = g[np.ix_(i, i1)]
    c = g[np.ix_(i1, i)]
    d = g[np.ix_(i1, i1)]
    fx = f[None, :]
    fy = f[:, None]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def fbm(n, cells, seed, octs=5, gain=0.5):
    out = np.zeros((n, n), np.float32)
    amp = 1.0
    tot = 0.0
    for o in range(octs):
        out += amp * vnoise(n, cells * (2 ** o), seed + o * 17)
        tot += amp
        amp *= gain
    return out / tot


def stretch_noise(n, cx, cy, seed, octs=3):
    """Noise stretched along x (wood grain): cx cells across, cy cells down."""
    out = np.zeros((n, n), np.float32)
    amp, tot = 1.0, 0.0
    for o in range(octs):
        rng = np.random.default_rng(seed + o)
        gx, gy = cx * 2 ** o, cy * 2 ** o
        g = rng.random((gy, gx)).astype(np.float32)
        xs = np.linspace(0, gx, n, endpoint=False)
        ys = np.linspace(0, gy, n, endpoint=False)
        ix, iy = xs.astype(int), ys.astype(int)
        fx = xs - ix
        fy = ys - iy
        fx = (fx * fx * (3 - 2 * fx))[None, :]
        fy = (fy * fy * (3 - 2 * fy))[:, None]
        ix1, iy1 = (ix + 1) % gx, (iy + 1) % gy
        a, b, c, d = g[np.ix_(iy, ix)], g[np.ix_(iy, ix1)], g[np.ix_(iy1, ix)], g[np.ix_(iy1, ix1)]
        out += amp * (((a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy))
        tot += amp
        amp *= 0.5
    return out / tot


def blocks(n, rows, bw, seed, mortar_px, jitter=0.0):
    """Coursed masonry on an n x n tile. Returns (block id, edge distance in px, row) per pixel."""
    rng = np.random.default_rng(seed)
    rh = n / rows
    ids = np.zeros((n, n), np.int32)
    edge = np.full((n, n), 1e3, np.float32)
    yy = np.arange(n)[:, None]
    xx = np.arange(n)[None, :]
    nid = 1
    for r in range(rows):
        y0, y1 = int(round(r * rh)), int(round((r + 1) * rh))
        widths = []
        tot = 0.0
        while tot < n:
            w = rng.uniform(bw[0], bw[1]) * n
            widths.append(w)
            tot += w
        widths[-1] -= tot - n
        x = rng.uniform(0, widths[0])
        xs = [x]
        k = 0
        while xs[-1] < n + widths[0]:
            xs.append(xs[-1] + widths[k % len(widths)])
            k += 1
        for a, b in zip(xs[:-1], xs[1:]):
            x0, x1 = a, b
            for off in (-n, 0, n):
                xa, xb = int(round(x0 + off)), int(round(x1 + off))
                if xb <= 0 or xa >= n:
                    continue
                xa2, xb2 = max(xa, 0), min(xb, n)
                sub = ids[y0:y1, xa2:xb2]
                sub[:] = nid
                ey = np.minimum(np.arange(y0, y1) - y0, y1 - 1 - np.arange(y0, y1))[:, None]
                ex = np.minimum(np.arange(xa2, xb2) - xa, xb - 1 - np.arange(xa2, xb2))[None, :]
                edge[y0:y1, xa2:xb2] = np.minimum(ey, ex)
            nid += 1
    return ids, edge, rng


def finish(name, albedo, height, rough, metal=0.0, ao=None, nstrength=3.0, size=N):
    """Make the three images (albedo sRGB, normal, ORM) as packed Blender images."""
    h = height.astype(np.float32)
    dx = np.roll(h, -1, 1) - np.roll(h, 1, 1)
    dy = np.roll(h, -1, 0) - np.roll(h, 1, 0)
    nx, ny, nz = -dx * nstrength, dy * nstrength, np.ones_like(h)
    ln = np.sqrt(nx * nx + ny * ny + nz * nz)
    normal = np.stack([nx / ln * 0.5 + 0.5, ny / ln * 0.5 + 0.5, nz / ln * 0.5 + 0.5], -1)
    if ao is None:
        ao = np.clip(0.6 + 0.4 * (h - h.min()) / max(h.max() - h.min(), 1e-4), 0, 1)
    orm = np.stack([ao, np.clip(rough, 0.04, 1.0), np.full_like(h, metal) if np.isscalar(metal) else metal], -1)
    out = {}
    for suf, arr, cs in (("albedo", np.clip(albedo, 0, 1), "sRGB"), ("normal", normal, "Non-Color"), ("orm", orm, "Non-Color")):
        img = bpy.data.images.new("r37e_%s_%s" % (name, suf), size, size, alpha=False)
        rgba = np.ones((size, size, 4), np.float32)
        rgba[..., :3] = arr
        img.pixels.foreach_set(rgba[::-1].ravel())
        img.colorspace_settings.name = cs
        img.pack()
        out[suf] = img
    return out


def tex_stone(seed=1, rows=6, bw=(0.22, 0.4), base=(0.40, 0.40, 0.39), warm=0.0, moss=0.0):
    ids, edge, rng = blocks(N, rows, bw, seed, 3)
    tint = rng.uniform(0.78, 1.18, ids.max() + 2).astype(np.float32)
    tilt = rng.uniform(-0.05, 0.05, (ids.max() + 2, 3)).astype(np.float32)
    g1 = fbm(N, 6, seed + 3)
    g2 = fbm(N, 48, seed + 4, 3)
    mortar = np.clip(1.0 - edge / 4.0, 0, 1)
    face = np.clip(edge / 14.0, 0, 1)
    height = face * 0.5 + (g1 * 0.25 + g2 * 0.35) * (0.5 + 0.5 * face) - mortar * 0.3
    col = np.zeros((N, N, 3), np.float32)
    for c in range(3):
        col[..., c] = base[c] * tint[ids] * (1 + tilt[ids][..., c]) * (0.8 + 0.4 * g1) * (0.9 + 0.2 * g2)
    col[..., 0] *= 1 + warm
    col[..., 2] *= 1 - warm * 0.6
    col = col * (1 - mortar[..., None] * 0.55) + mortar[..., None] * 0.55 * np.array([0.22, 0.2, 0.19])
    if moss > 0:
        m = np.clip((fbm(N, 5, seed + 9) - (0.62 - moss)) * 6.0, 0, 1) * (1 - face * 0.4)
        col = col * (1 - m[..., None]) + m[..., None] * np.array([0.14, 0.19, 0.1])
    rough = 0.88 - 0.12 * g2 + mortar * 0.08
    return finish("stone%d" % seed, col, height, rough, nstrength=4.0)


def tex_timber(seed=2, planks=6, base=(0.36, 0.26, 0.17), silver=0.0):
    pw = N // planks
    g = stretch_noise(N, 3, 40, seed)
    g2 = stretch_noise(N, 10, 120, seed + 5, 2)
    rng = np.random.default_rng(seed)
    pid = (np.arange(N)[None, :] // pw) * np.ones((N, 1), np.int32)
    tone = rng.uniform(0.78, 1.15, planks + 2)[pid]
    local = (np.arange(N)[None, :] % pw) / pw
    gap = np.clip(1.0 - np.minimum(local, 1 - local) / 0.025, 0, 1) * np.ones((N, 1))
    ring = 0.5 + 0.5 * np.sin((g * 9.0 + local * 2.0) * 6.28)
    height = g2 * 0.3 + ring * 0.12 - gap * 0.6
    col = np.zeros((N, N, 3), np.float32)
    for c in range(3):
        v = base[c] * tone * (0.75 + 0.5 * g) * (0.92 + 0.16 * ring)
        col[..., c] = v * (1 - silver) + silver * 0.5 * (0.5 + 0.5 * g)
    col *= 1 - gap[..., None] * 0.7
    return finish("timber%d" % seed, col, height, 0.78 - 0.2 * g2 + gap * 0.2, nstrength=3.0)


def tex_salt(seed=3):
    """Cracked salt crust: polygonal plates, pale, with brine-dark seams and a glittering grain."""
    n = 512
    rng = np.random.default_rng(seed)
    pts = rng.random((46, 2)) * n
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    d1 = np.full((n, n), 1e9, np.float32)
    d2 = np.full((n, n), 1e9, np.float32)
    for (px, py) in pts:
        for ox in (-n, 0, n):
            for oy in (-n, 0, n):
                d = np.sqrt((xx - px - ox) ** 2 + (yy - py - oy) ** 2)
                m = d < d1
                d2 = np.where(m, d1, np.minimum(d2, d))
                d1 = np.minimum(d1, d)
    seam = np.clip(1.0 - (d2 - d1) / 6.0, 0, 1)
    plate = np.clip((d2 - d1) / 40.0, 0, 1)
    f = np.array(Image_resize(fbm(N, 8, seed + 1), n))
    grain = np.array(Image_resize(fbm(N, 64, seed + 2, 3), n))
    height = plate * 0.5 + f * 0.3 + grain * 0.15 - seam * 0.5
    col = np.zeros((n, n, 3), np.float32)
    base = np.array([0.86, 0.87, 0.84])
    for c in range(3):
        col[..., c] = base[c] * (0.88 + 0.16 * f) * (0.94 + 0.08 * grain)
    col = col * (1 - seam[..., None] * 0.45) + seam[..., None] * 0.45 * np.array([0.5, 0.52, 0.5])
    stain = np.clip((np.array(Image_resize(fbm(N, 4, seed + 7), n)) - 0.58) * 4.0, 0, 1)
    col = col * (1 - stain[..., None] * 0.35) + stain[..., None] * 0.35 * np.array([0.6, 0.55, 0.45])
    return finish("salt", col, height, 0.55 + 0.3 * grain + seam * 0.1, nstrength=3.5, size=n)


def Image_resize(a, n):
    k = a.shape[0] // n
    if k <= 1:
        return a
    return a.reshape(n, k, n, k).mean((1, 3))


def tex_plaster(seed=4):
    g = fbm(N, 4, seed)
    g2 = fbm(N, 32, seed + 1, 4)
    stain = np.clip((fbm(N, 3, seed + 2) - 0.5) * 3.0, 0, 1)
    crack = np.clip(1.0 - np.abs(fbm(N, 7, seed + 3) - 0.5) / 0.012, 0, 1) * (fbm(N, 3, seed + 4) > 0.5)
    col = np.zeros((N, N, 3), np.float32)
    base = np.array([0.66, 0.63, 0.57])
    for c in range(3):
        col[..., c] = base[c] * (0.86 + 0.28 * g) * (0.94 + 0.12 * g2)
    col = col * (1 - stain[..., None] * 0.4) + stain[..., None] * 0.4 * np.array([0.3, 0.27, 0.22])
    col = col * (1 - crack[..., None] * 0.7)
    height = g2 * 0.4 + g * 0.2 - crack * 0.5
    return finish("plaster", col, height, 0.9 - 0.1 * g2, nstrength=2.5)


def tex_slate(seed=5):
    ids, edge, rng = blocks(N, 12, (0.14, 0.22), seed, 2)
    tint = rng.uniform(0.7, 1.2, ids.max() + 2).astype(np.float32)
    g = fbm(N, 20, seed + 1, 4)
    sh = np.clip(edge / 10.0, 0, 1)
    col = np.zeros((N, N, 3), np.float32)
    base = np.array([0.23, 0.25, 0.27])
    for c in range(3):
        col[..., c] = base[c] * tint[ids] * (0.8 + 0.4 * g) * (0.55 + 0.45 * sh)
    return finish("slate", col, sh * 0.6 + g * 0.2, 0.7 - 0.2 * g, nstrength=3.5)


def tex_iron(seed=6):
    g = fbm(N, 10, seed)
    g2 = fbm(N, 80, seed + 1, 3)
    rust = np.clip((fbm(N, 5, seed + 2) - 0.5) * 3.5, 0, 1)
    col = np.zeros((N, N, 3), np.float32)
    base = np.array([0.17, 0.17, 0.18])
    for c in range(3):
        col[..., c] = base[c] * (0.7 + 0.6 * g2)
    col = col * (1 - rust[..., None]) + rust[..., None] * np.array([0.34, 0.16, 0.07]) * (0.7 + 0.5 * g)[..., None]
    metal = (1 - rust) * 0.85
    return finish("iron", col, g2 * 0.4 + g * 0.2 + rust * 0.2, 0.55 + rust * 0.35 + 0.1 * g2, metal=metal, nstrength=2.5)


# ================================================================== materials
TILE = {}   # material name -> tile size in metres
MATS = {}


def mk_mat(name, tex, tile, emit=None, emit_strength=0.0, color=None, rough=0.5, alpha=None):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    for nd in list(nt.nodes):
        if nd.type != 'OUTPUT_MATERIAL':
            nt.nodes.remove(nd)
    out = nt.nodes['Material Output']
    bsdf = nt.nodes.new('ShaderNodeBsdfPrincipled')
    nt.links.new(bsdf.outputs['BSDF'], out.inputs['Surface'])
    if tex is not None:
        a = nt.nodes.new('ShaderNodeTexImage')
        a.image = tex['albedo']
        nt.links.new(a.outputs['Color'], bsdf.inputs['Base Color'])
        nrm = nt.nodes.new('ShaderNodeTexImage')
        nrm.image = tex['normal']
        nm = nt.nodes.new('ShaderNodeNormalMap')
        nt.links.new(nrm.outputs['Color'], nm.inputs['Color'])
        nt.links.new(nm.outputs['Normal'], bsdf.inputs['Normal'])
        o = nt.nodes.new('ShaderNodeTexImage')
        o.image = tex['orm']
        sep = nt.nodes.new('ShaderNodeSeparateColor')
        nt.links.new(o.outputs['Color'], sep.inputs['Color'])
        nt.links.new(sep.outputs['Green'], bsdf.inputs['Roughness'])
        nt.links.new(sep.outputs['Blue'], bsdf.inputs['Metallic'])
    else:
        bsdf.inputs['Base Color'].default_value = (*color, 1.0)
        bsdf.inputs['Roughness'].default_value = rough
    if emit is not None:
        bsdf.inputs['Emission Color'].default_value = (*emit, 1.0)
        bsdf.inputs['Emission Strength'].default_value = emit_strength
    if alpha is not None:
        bsdf.inputs['Alpha'].default_value = alpha
        m.blend_method = 'BLEND' if hasattr(m, 'blend_method') else None
    TILE[name] = tile
    MATS[name] = m
    return m


def build_materials():
    mk_mat("stone", tex_stone(11, 6, (0.2, 0.38), (0.42, 0.42, 0.4), 0.02, 0.0), 2.4)
    mk_mat("stone_dark", tex_stone(12, 7, (0.18, 0.32), (0.27, 0.27, 0.27), 0.0, 0.25), 2.4)
    mk_mat("timber", tex_timber(21, 6, (0.34, 0.25, 0.17), 0.1), 1.6)
    mk_mat("timber_old", tex_timber(22, 5, (0.3, 0.27, 0.22), 0.55), 1.6)
    mk_mat("salt", tex_salt(31), 3.0)
    mk_mat("plaster", tex_plaster(41), 2.4)
    mk_mat("slate", tex_slate(51), 2.0)
    mk_mat("iron", tex_iron(61), 1.0)
    mk_mat("glass_dark", None, 1.0, color=(0.02, 0.025, 0.03), rough=0.1)
    mk_mat("lamp_glass", None, 1.0, color=(0.55, 0.38, 0.18), rough=0.25, emit=(1.0, 0.55, 0.2), emit_strength=0.0)
    mk_mat("void", None, 1.0, color=(0.008, 0.008, 0.01), rough=1.0)
    mk_mat("brine", None, 1.0, color=(0.66, 0.7, 0.68), rough=0.12)
    mk_mat("copper", tex_iron(62), 1.0)


# ================================================================== geometry
COL = {}        # asset -> list of [cx, cy, cz, sx, sy, sz, rx, ry, rz]  (world-of-the-asset boxes)
RAMPS = {}      # asset -> list of [lo xyz, hi xyz, width]
CURRENT = ["x"]


class MB:
    """A mesh under construction: solids added as boxes / wedges / cylinders, one bmesh."""

    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.mi = {}

    def _mi(self, mat):
        if mat not in self.mi:
            self.mi[mat] = len(self.mi)
        return self.mi[mat]

    def _face(self, vs, mat):
        try:
            f = self.bm.faces.new(vs)
            f.material_index = self._mi(mat)
            f.smooth = False
            return f
        except ValueError:
            return None

    def box(self, c, s, mat, rot=(0, 0, 0), col=False, skip=()):
        hx, hy, hz = s[0] / 2, s[1] / 2, s[2] / 2
        M = Euler(rot, 'XYZ').to_matrix()
        pts = []
        for sx in (-1, 1):
            for sy in (-1, 1):
                for sz in (-1, 1):
                    p = M @ Vector((sx * hx, sy * hy, sz * hz)) + Vector(c)
                    pts.append(self.bm.verts.new(p))
        # index = (sx+1)/2*4 + (sy+1)/2*2 + (sz+1)/2
        idx = lambda sx, sy, sz: ((sx + 1) // 2) * 4 + ((sy + 1) // 2) * 2 + ((sz + 1) // 2)
        faces = [((1, -1, -1), (1, 1, -1), (1, 1, 1), (1, -1, 1)), ((-1, -1, 1), (-1, 1, 1), (-1, 1, -1), (-1, -1, -1)),
                 ((-1, 1, -1), (-1, 1, 1), (1, 1, 1), (1, 1, -1)), ((-1, -1, 1), (-1, -1, -1), (1, -1, -1), (1, -1, 1)),
                 ((-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1)), ((1, -1, -1), (-1, -1, -1), (-1, 1, -1), (1, 1, -1))]
        for k, fc in enumerate(faces):
            if k in skip:
                continue
            self._face([pts[idx(*q)] for q in fc], mat)
        if col:
            COL.setdefault(CURRENT[0], []).append([round(v, 3) for v in (*c, *s, *rot)])
        return self

    def wedge(self, c, w, d, h, mat, ry=0.0, col=False):
        """Gable block: width w (x), depth d (z, the ridge runs along z), height h; base at c.y."""
        M = Euler((0, ry, 0), 'XYZ').to_matrix()
        pl = [(-w / 2, 0, -d / 2), (w / 2, 0, -d / 2), (w / 2, 0, d / 2), (-w / 2, 0, d / 2), (0, h, -d / 2), (0, h, d / 2)]
        v = [self.bm.verts.new(M @ Vector(p) + Vector(c)) for p in pl]
        for fc in ((0, 3, 2, 1), (0, 1, 4), (3, 5, 2), (0, 4, 5, 3), (1, 2, 5, 4)):
            self._face([v[i] for i in fc], mat)
        return self

    def cyl(self, c, r0, r1, h, n, mat, cap=True, ry=0.0, col=False):
        """Frustum along +y from c (r0 at the bottom, r1 at the top)."""
        bot = [self.bm.verts.new(Vector(c) + Vector((math.cos(a + ry) * r0, 0, math.sin(a + ry) * r0))) for a in [math.tau * i / n for i in range(n)]]
        top = [self.bm.verts.new(Vector(c) + Vector((math.cos(a + ry) * r1, h, math.sin(a + ry) * r1))) for a in [math.tau * i / n for i in range(n)]]
        for i in range(n):
            j = (i + 1) % n
            self._face([bot[i], bot[j], top[j], top[i]], mat)
        if cap:
            self._face(list(reversed(bot)), mat)
            if r1 > 0.001:
                self._face(top, mat)
        else:
            pass
        if col:
            r = max(r0, r1)
            COL.setdefault(CURRENT[0], []).append([round(v, 3) for v in (c[0], c[1] + h / 2, c[2], 2 * r, h, 2 * r, 0, 0, 0)])
        return self

    def cone(self, c, r, h, n, mat):
        apex = self.bm.verts.new(Vector(c) + Vector((0, h, 0)))
        ring = [self.bm.verts.new(Vector(c) + Vector((math.cos(math.tau * i / n) * r, 0, math.sin(math.tau * i / n) * r))) for i in range(n)]
        for i in range(n):
            self._face([ring[i], ring[(i + 1) % n], apex], mat)
        self._face(list(reversed(ring)), mat)
        return self

    def build(self, ob_name=None):
        bm = self.bm
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        uv = bm.loops.layers.uv.new("UVMap")
        names = {i: m for m, i in self.mi.items()}
        for f in bm.faces:
            nrm = f.normal
            t = TILE.get(names[f.material_index], 1.0)
            ax = max(range(3), key=lambda k: abs(nrm[k]))
            for lp in f.loops:
                p = lp.vert.co
                if ax == 1:
                    u, v = p.x, p.z
                elif ax == 0:
                    u, v = p.z, p.y
                else:
                    u, v = p.x, p.y
                lp[uv].uv = (u / t, v / t)
        for v in bm.verts:                       # built Y-up; Blender is Z-up (the glTF exporter turns it back)
            v.co = Vector((v.co.x, -v.co.z, v.co.y))
        me = bpy.data.meshes.new(ob_name or self.name)
        bm.to_mesh(me)
        bm.free()
        for m in sorted(self.mi, key=lambda k: self.mi[k]):
            me.materials.append(MATS[m])
        ob = bpy.data.objects.new(ob_name or self.name, me)
        bpy.context.scene.collection.objects.link(ob)
        return ob


def decimate_to(src, ratio, name):
    ob = src.copy()
    ob.data = src.data.copy()
    ob.name = name
    bpy.context.scene.collection.objects.link(ob)
    md = ob.modifiers.new("dec", 'DECIMATE')
    md.ratio = ratio
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.modifier_apply(modifier="dec")
    return ob


def wall(mb, axis, c, length, thick, y0, y1, mat, holes=(), col=True):
    """A wall slab along x (axis 'x') or z ('z') centred at c (x,z) with holes: (u, width, v0, v1), u along the wall."""
    cx, cz = c
    u0, u1 = -length / 2, length / 2
    pieces = []
    cur = u0
    for (u, w, v0, v1) in sorted(holes, key=lambda h: h[0]):
        a, b = u - w / 2, u + w / 2
        if a > cur:
            pieces.append((cur, a, y0, y1))
        if v0 > y0:
            pieces.append((a, b, y0, v0))
        if v1 < y1:
            pieces.append((a, b, v1, y1))
        cur = b
    if cur < u1:
        pieces.append((cur, u1, y0, y1))
    for (a, b, ya, yb) in pieces:
        mid = (a + b) / 2
        if axis == 'x':
            mb.box((cx + mid, (ya + yb) / 2, cz), (b - a, yb - ya, thick), mat, col=col)
        else:
            mb.box((cx, (ya + yb) / 2, cz + mid), (thick, yb - ya, b - a), mat, col=col)


def ring_walls(mb, y0, y1, ow, iw, mat, holes=None, col=True):
    """A hollow square tube: outer width ow, inner iw, N/S walls full width, E/W between. holes: side -> list."""
    t = (ow - iw) / 2
    holes = holes or {}
    wall(mb, 'x', (0, ow / 2 - t / 2), ow, t, y0, y1, mat, holes.get('S', ()), col)       # +z
    wall(mb, 'x', (0, -ow / 2 + t / 2), ow, t, y0, y1, mat, holes.get('N', ()), col)      # -z
    wall(mb, 'z', (ow / 2 - t / 2, 0), iw, t, y0, y1, mat, holes.get('E', ()), col)       # +x
    wall(mb, 'z', (-ow / 2 + t / 2, 0), iw, t, y0, y1, mat, holes.get('W', ()), col)      # -x


def ring_slab(mb, y, h, ow, iw, mat, col=True):
    ring_walls(mb, y, y + h, ow, iw, mat, None, col)


def steps(mb, lo, hi, width, mat, rise=0.2, asset=None, rail=True):
    """A flight from lo to hi (x,y,z): tread boxes plus a stringer slab; records the ramp."""
    lo, hi = Vector(lo), Vector(hi)
    d = hi - lo
    run = Vector((d.x, 0, d.z))
    n = max(2, int(math.ceil(d.y / rise)))
    ang = math.atan2(run.x, run.z)
    for i in range(n):
        t = (i + 0.5) / n
        p = lo + d * t
        top = lo.y + d.y * (i + 1) / n
        ln = run.length / n
        mb.box((p.x, top - 0.09, p.z), (width, 0.18, ln * 1.02), mat, rot=(0, ang, 0))
    sl = math.atan2(d.y, run.length)
    mid = (lo + hi) / 2
    # stringer slab under the treads
    mb.box((mid.x, mid.y - 0.3, mid.z), (width, 0.22, math.hypot(run.length, d.y)), mat, rot=(0, 0, 0))
    RAMPS.setdefault(CURRENT[0] if asset is None else asset, []).append([round(v, 3) for v in (lo.x, lo.y, lo.z, hi.x, hi.y, hi.z, width)])


# ================================================================== the Spire
SEC = [(1.0, 6.2, 8.4), (6.2, 11.4, 7.9), (11.4, 16.6, 7.4), (16.6, 21.8, 6.9), (21.8, 27.0, 6.4)]
IW = 5.0
FLOOR = 1.2
DECK = 27.0
RISE = (DECK - FLOOR) / 14.0


def spire(lod):
    """lod 0 = everything, 1 = the shell outside (no interior), 2 = far mesh."""
    CURRENT[0] = "spire" if lod == 0 else "x"
    mb = MB("Spire_LOD%d" % lod if lod < 2 else "Spire_Far")
    if lod == 2:
        for (y0, y1, ow) in SEC:
            mb.box((0, (y0 + y1) / 2, 0), (ow, y1 - y0, ow), "stone")
        mb.box((0, 0.5, 0), (10.4, 1.0, 10.4), "stone")
        mb.box((0, 27.2, 0), (8.6, 0.5, 8.6), "stone")
        mb.box((0, 28.8, 0), (6.4, 2.6, 6.4), "stone_dark")
        mb.cyl((0, 30.1, 0), 4.1, 0.0, 3.2, 8, "copper")
        return mb.build()
    # plinth, door steps
    mb.box((0, 0.5, 0), (10.4, 1.0, 10.4), "stone", col=(lod == 0))
    mb.box((0, 0.175, 6.6), (3.6, 0.35, 1.2), "stone", col=(lod == 0))        # two steps up to the plinth
    mb.box((0, 0.35, 5.8), (3.6, 0.7, 1.0), "stone", col=(lod == 0))
    # the tower sections
    for k, (y0, y1, ow) in enumerate(SEC):
        holes = {}
        wy = (y0 + y1) / 2
        if k == 0:
            holes['S'] = [(0.0, 1.7, FLOOR, 3.7)]
        else:
            holes['S'] = [(0.0, 0.5, wy - 0.7, wy + 0.9)]
        holes['E'] = [(0.0, 0.5, wy - 0.7, wy + 0.9)] if k > 0 else []
        holes['W'] = [(0.0, 0.5, wy - 0.7, wy + 0.9)] if k > 0 else []
        holes['N'] = [(1.0, 0.5, wy - 0.7, wy + 0.9)] if k > 1 else []
        if lod == 1:
            mb.box((0, (y0 + y1) / 2, 0), (ow, y1 - y0, ow), "stone", col=False)
        else:
            ring_walls(mb, y0, y1, ow, IW, "stone" if k < 3 else "stone_dark", holes)
        # belt course
        ring_slab(mb, y1 - 0.18, 0.3, ow + 0.5, IW + (0 if lod == 0 else 0), "stone", col=(lod == 0)) if lod == 0 else mb.box((0, y1 - 0.03, 0), (ow + 0.5, 0.3, ow + 0.5), "stone")
        # quoins up each corner
        if lod == 0:
            for sx in (-1, 1):
                for sz in (-1, 1):
                    q = y0 + 0.2
                    while q < y1 - 0.3:
                        ln = 0.7 if int((q - y0) / 0.5) % 2 == 0 else 0.45
                        mb.box((sx * (ow / 2 + 0.03), q + 0.2, sz * (ow / 2 - ln / 2 + 0.05)), (0.12, 0.38, ln), "stone")
                        mb.box((sx * (ow / 2 - ln / 2 + 0.05), q + 0.2, sz * (ow / 2 + 0.03)), (ln, 0.38, 0.12), "stone")
                        q += 0.5
        # window surrounds (iron-barred slits get a lintel and sill proud of the wall)
        if k > 0 and lod == 0:
            for (nx, nz, ax) in ((0, 1, 'S'), (1, 0, 'E'), (-1, 0, 'W')):
                p = (nx * (ow / 2 + 0.06), wy + 1.0, nz * (ow / 2 + 0.06))
                mb.box((p[0], wy - 0.78, p[2]), (0.9 if nz else 0.2, 0.14, 0.9 if nx else 0.2), "stone")
                mb.box((p[0], wy + 1.0, p[2]), (0.9 if nz else 0.2, 0.18, 0.9 if nx else 0.2), "stone")
                mb.box((nx * (ow / 2 - 0.05), wy + 0.1, nz * (ow / 2 - 0.05)), (0.06 if nx else 0.06, 1.5, 0.06) if nx else (0.06, 1.5, 0.06), "iron")
    if lod == 1:
        pass
    # the door: oak leaves open inward, iron straps, a stone lintel with a carved star
    if lod == 0:
        mb.box((-0.55, 2.4, 3.95), (0.12, 2.4, 0.9), "timber", rot=(0, 0.9, 0))
        mb.box((0.55, 2.4, 3.95), (0.12, 2.4, 0.9), "timber", rot=(0, -0.9, 0))
        mb.box((0, 3.85, 4.28), (2.4, 0.3, 0.5), "stone")
        for sx in (-1, 1):
            mb.box((sx * 1.05, 2.4, 4.22), (0.35, 2.5, 0.4), "stone")
    # the interior floor, stair landings and flights, rails (interior is lod 0 only)
    if lod == 0:
        mb.box((0, FLOOR - 0.15, 0), (IW, 0.3, IW), "stone", col=True)
        cx = [(-1.95, 1.95), (-1.95, -1.95), (1.95, -1.95), (1.95, 1.95)]      # SW, NW, NE, SE  (x, z)
        for k in range(15):
            ch = FLOOR + RISE * k
            x, z = cx[k % 4]
            if k > 0 and k < 14:
                mb.box((x, ch - 0.12, z), (1.1, 0.24, 1.1), "timber", col=True)
            if k == 0:
                pass
            if k < 14:
                x2, z2 = cx[(k + 1) % 4]
                dx = x2 - x
                dz = z2 - z
                ln = math.hypot(dx, dz)
                ux, uz = dx / ln, dz / ln
                lo = (x + ux * 0.55, ch, z + uz * 0.55)
                hi = (x2 - ux * 0.55, ch + RISE, z2 - uz * 0.55)
                steps(mb, lo, hi, 1.1, "timber", rise=RISE / 9.0, asset="spire")
                # an inner handrail along the open side
                inx, inz = -uz * -0.0, 0.0
                ox, oz = (-uz, ux)
                # the open side is the one facing the centre: pick the sign pointing to (0,0)
                if (x * ox + z * oz) > 0:
                    ox, oz = -ox, -oz
                rl = math.hypot(ln - 1.1, RISE)
                ang_y = math.atan2(ux, uz)
                mid = ((lo[0] + hi[0]) / 2 + ox * 0.55, (lo[1] + hi[1]) / 2 + 0.55, (lo[2] + hi[2]) / 2 + oz * 0.55)
                pitch = -math.atan2(RISE, ln - 1.1)
                M = Euler((0, ang_y, 0), 'XYZ').to_matrix() @ Euler((pitch, 0, 0), 'XYZ').to_matrix()
                eul = M.to_euler('XYZ')
                mb.box(mid, (0.07, 0.07, rl), "iron", rot=tuple(eul), col=False)
                COL.setdefault("spire", []).append([round(v, 3) for v in (*mid, 0.1, 1.1, rl, *eul)])
                for tt in (0.0, 0.5, 1.0):
                    pp = (lo[0] + (hi[0] - lo[0]) * tt + ox * 0.55, lo[1] + (hi[1] - lo[1]) * tt + 0.3, lo[2] + (hi[2] - lo[2]) * tt + oz * 0.55)
                    mb.box(pp, (0.06, 0.6, 0.06), "iron")
        # the deck: whole interior but the stairwell strip along the north wall
        mb.box((0, DECK - 0.2, 0.55), (IW, 0.4, IW - 1.1), "timber", col=True)
        mb.box((1.95, DECK - 0.2, -1.95), (1.1, 0.4, 1.1), "timber", col=True)
    else:
        mb.box((0, DECK - 0.2, 0), (IW + 0.2, 0.4, IW + 0.2), "timber")
    # corbelled gallery (machicolation)
    gy = DECK
    for sx in (-1, 1):
        for sz in (-1, 1):
            pass
    if lod == 0:
        n = 9
        for i in range(n):
            u = -3.2 + 6.4 * i / (n - 1)
            for (px, pz, w, d) in ((u, 3.4, 0.4, 0.8), (u, -3.4, 0.4, 0.8), (3.4, u, 0.8, 0.4), (-3.4, u, 0.8, 0.4)):
                mb.box((px, gy - 0.45, pz), (w, 0.9, d), "stone")
    ring_slab(mb, gy, 0.3, 8.8, 6.4, "stone", col=(lod == 0))
    if lod == 1:
        mb.box((0, gy + 0.15, 0), (8.8, 0.3, 8.8), "stone")
    # railing round the gallery (posts, rails; the collision is four thin boxes)
    rail_h = 1.1
    for i in range(13):
        u = -4.2 + 8.4 * i / 12
        for (px, pz) in ((u, 4.25), (u, -4.25), (4.25, u), (-4.25, u)):
            mb.box((px, gy + 0.3 + rail_h / 2, pz), (0.08, rail_h, 0.08), "iron")
    for (c, s) in (((0, gy + 1.35, 4.25), (8.6, 0.08, 0.1)), ((0, gy + 1.35, -4.25), (8.6, 0.08, 0.1)),
                   ((4.25, gy + 1.35, 0), (0.1, 0.08, 8.6)), ((-4.25, gy + 1.35, 0), (0.1, 0.08, 8.6))):
        mb.box(c, s, "iron")
        mb.box((c[0], c[1] - 0.5, c[2]), s, "iron")
    if lod == 0:
        for (c, s) in (((0, gy + 0.85, 4.25), (8.6, 1.1, 0.1)), ((0, gy + 0.85, -4.25), (8.6, 1.1, 0.1)),
                       ((4.25, gy + 0.85, 0), (0.1, 1.1, 8.6)), ((-4.25, gy + 0.85, 0), (0.1, 1.1, 8.6))):
            COL.setdefault("spire", []).append([round(v, 3) for v in (*c, *s, 0, 0, 0)])
    # the lamp room: sill walls, four corner piers, mullions, glazing, the cone roof
    ly = DECK + 0.3
    for (px, pz) in ((-2.85, -2.85), (2.85, -2.85), (-2.85, 2.85), (2.85, 2.85)):
        mb.box((px, ly + 1.9, pz), (0.7, 3.8, 0.7), "stone_dark", col=(lod == 0))
    sillh = 1.0
    for (axis, c, ln) in (('x', (0, -2.85), 5.0), ('z', (-2.85, 0), 5.0), ('z', (2.85, 0), 5.0)):
        wall(mb, axis, c, ln, 0.7, ly, ly + sillh, "stone_dark", col=(lod == 0))
    wall(mb, 'x', (0, 2.85), 5.0, 0.7, ly, ly + sillh, "stone_dark", holes=[(0.0, 1.4, ly, ly + sillh)], col=(lod == 0))   # the door out to the gallery
    # head beam, glazing and mullions
    for (c, s) in (((0, ly + 3.65, 2.85), (6.4, 0.3, 0.7)), ((0, ly + 3.65, -2.85), (6.4, 0.3, 0.7)),
                   ((2.85, ly + 3.65, 0), (0.7, 0.3, 6.4)), ((-2.85, ly + 3.65, 0), (0.7, 0.3, 6.4))):
        mb.box(c, s, "stone_dark")
    if lod == 0:
        for u in (-1.7, 0.0, 1.7):
            for (px, pz, sx2, sz2) in ((u, 2.85, 0.1, 0.2), (u, -2.85, 0.1, 0.2), (2.85, u, 0.2, 0.1), (-2.85, u, 0.2, 0.1)):
                mb.box((px, ly + 2.4, pz), (sx2, 2.4, sz2), "iron")
        for (px, pz, sx2, sz2) in ((0, -2.75, 5.0, 0.04), (-2.75, 0, 0.04, 5.0), (2.75, 0, 0.04, 5.0)):
            mb.box((px, ly + 2.4, pz), (sx2, 2.4, sz2), "lamp_glass")      # the glazing; Godot lights it
    # the great lamp: a pedestal, a bronze basin, a wick-cage of iron ribs
    if lod == 0:
        mb.cyl((0, ly, 0), 0.8, 0.55, 0.9, 10, "stone_dark", col=True)
        mb.cyl((0, ly + 0.9, 0), 0.55, 0.95, 0.5, 12, "copper")
        mb.cyl((0, ly + 1.35, 0), 0.9, 0.9, 0.12, 12, "iron")
        for i in range(8):
            a = math.tau * i / 8
            mb.box((math.cos(a) * 0.7, ly + 1.85, math.sin(a) * 0.7), (0.05, 0.9, 0.05), "iron", rot=(0, 0, 0))
        mb.cyl((0, ly + 2.3, 0), 0.75, 0.15, 0.4, 12, "copper")
    # the roof: a low cone on a drum, a finial
    mb.cyl((0, ly + 3.8, 0), 4.7, 4.0, 0.35, 8, "slate")
    mb.cyl((0, ly + 4.15, 0), 4.0, 0.25, 2.9, 8, "copper" if lod == 0 else "slate", cap=False)
    if lod == 0:
        mb.cyl((0, ly + 7.0, 0), 0.25, 0.1, 0.5, 8, "iron")
        mb.box((0, ly + 7.7, 0), (0.05, 1.0, 0.05), "iron")
        mb.box((0.35, ly + 7.9, 0), (0.7, 0.04, 0.04), "iron")
    ob = mb.build()
    return ob


# ================================================================== the cells and chapel kit
def cell_portal():
    CURRENT[0] = "cell_portal"
    mb = MB("Cell_Portal")
    for sx in (-1, 1):
        mb.box((sx * 1.15, 1.6, 0.35), (0.7, 3.2, 0.9), "stone_dark", col=True)
    mb.box((0, 3.45, 0.35), (3.0, 0.5, 1.0), "stone_dark", col=True)
    mb.box((0, 0.1, 0.45), (3.0, 0.2, 1.1), "stone_dark", col=True)                    # the sill step
    mb.box((0, 1.6, -0.35), (1.6, 3.0, 0.5), "void")                                     # the dark reveal
    mb.box((0, 1.4, 0.18), (1.5, 2.5, 0.06), "timber_old")                                # a plank door, half open
    for y in (0.7, 1.6, 2.5):
        mb.box((0, y, 0.22), (1.5, 0.08, 0.04), "iron")
    mb.box((0.55, 1.3, 0.25), (0.1, 0.1, 0.1), "iron")
    mb.box((0, 3.95, 0.3), (2.2, 0.5, 0.8), "stone_dark")                                 # a hood-mould over it
    return mb.build()


def cell_slit():
    CURRENT[0] = "cell_slit"
    mb = MB("Cell_Slit")
    mb.box((0, 0.9, 0.25), (1.2, 1.8, 0.7), "stone_dark")
    mb.box((0, 0.9, 0.62), (0.35, 1.2, 0.1), "void")
    mb.box((0, 0.35, 0.65), (0.8, 0.12, 0.2), "stone_dark")
    return mb.build()


def walk_span():
    """A timber walkway bay, 3 m long (along z), 1.6 wide, deck top at y 0, posts hung below, rails."""
    CURRENT[0] = "walk_span"
    mb = MB("Walk_Span")
    for i in range(8):
        mb.box((0, -0.06, -1.5 + 0.375 + i * 0.375), (1.6, 0.12, 0.34), "timber_old")
    for sx in (-1, 1):
        mb.box((sx * 0.6, -0.3, 0), (0.18, 0.3, 3.1), "timber")
        mb.box((sx * 0.8, 0.55, -1.45), (0.14, 1.1, 0.14), "timber")
        mb.box((sx * 0.8, 0.55, 1.45), (0.14, 1.1, 0.14), "timber")
        mb.box((sx * 0.8, 1.05, 0), (0.08, 0.1, 3.0), "timber")
        mb.box((sx * 0.8, 0.55, 0), (0.06, 0.06, 3.0), "timber")
    mb.box((0, -0.62, -1.45), (1.0, 0.1, 0.1), "iron", rot=(0, 0, 0.0))
    COL["walk_span"] = [[0, -0.06, 0, 1.6, 0.12, 3.0, 0, 0, 0], [-0.8, 0.5, 0, 0.1, 1.0, 3.0, 0, 0, 0], [0.8, 0.5, 0, 0.1, 1.0, 3.0, 0, 0, 0]]
    return mb.build()


def walk_stair():
    """A timber stair 1.5 wide: 4 m of run climbing 2.4 m, rails each side (start at the origin, rising toward -z... +z)."""
    CURRENT[0] = "walk_stair"
    mb = MB("Walk_Stair")
    steps(mb, (0, 0, -2.0), (0, 2.4, 2.0), 1.5, "timber_old", rise=0.2, asset="walk_stair")
    for sx in (-1, 1):
        for t in (0.0, 0.5, 1.0):
            mb.box((sx * 0.8, 1.2 * t * 2 + 0.55, -2.0 + 4.0 * t), (0.12, 1.1, 0.12), "timber")
        mb.box((sx * 0.8, 1.7, 0), (0.07, 0.07, math.hypot(4.0, 2.4)), "timber", rot=(-math.atan2(2.4, 4.0), 0, 0))
    COL["walk_stair"] = []
    for sx in (-1, 1):
        COL["walk_stair"].append([round(v, 3) for v in (sx * 0.8, 1.7, 0, 0.1, 1.0, math.hypot(4.0, 2.4), -math.atan2(2.4, 4.0), 0, 0)])
    return mb.build()


def ladder():
    CURRENT[0] = "ladder"
    mb = MB("Ladder_4m")
    for sx in (-1, 1):
        mb.box((sx * 0.32, 2.0, 0), (0.07, 4.2, 0.09), "timber")
    for i in range(14):
        mb.box((0, 0.25 + i * 0.29, 0), (0.64, 0.05, 0.07), "timber")
    return mb.build()


def chapel_front():
    CURRENT[0] = "chapel"
    mb = MB("Chapel_Front")
    W = 7.4
    # the plinth and the front steps
    mb.box((0, 0.2, 0.8), (W + 1.0, 0.4, 2.2), "stone_dark", col=True)
    mb.box((0, 0.5, 0.4), (W + 0.2, 0.2, 1.4), "stone_dark", col=True)
    # the facade walls, a pointed doorway cut in them (pieces), buttresses
    wall(mb, 'x', (0, 0), W, 1.0, 0.6, 7.6, "stone", holes=[(0.0, 2.2, 0.6, 4.4)])
    for sx in (-1, 1):
        mb.box((sx * 3.95, 3.6, 0.35), (0.9, 6.4, 1.7), "stone", col=True)
        mb.box((sx * 3.95, 7.0, 0.1), (0.9, 0.6, 1.2), "stone")
    # pointed arch: two leaning voussoir courses meeting at the apex
    for sx in (-1, 1):
        for i in range(6):
            t = i / 5
            mb.box((sx * (1.1 - 0.9 * t * t), 4.4 + 1.05 * t, 0.55), (0.45, 0.4, 0.5), "stone_dark", rot=(0, 0, sx * (0.4 + 0.9 * t)))
    mb.box((0, 5.6, 0.55), (0.35, 0.55, 0.5), "stone_dark")
    # the oculus: a ring of stones over the door and a dark glazing
    for i in range(12):
        a = math.tau * i / 12
        mb.box((math.cos(a) * 1.15, 6.4 + math.sin(a) * 1.15, 0.55), (0.42, 0.3, 0.3), "stone_dark", rot=(0, 0, a))
    mb.cyl((0, 6.4, 0.5), 0.0, 0.0, 0.0, 3, "void") if False else mb.box((0, 6.4, 0.2), (1.6, 1.6, 0.1), "glass_dark")
    # the door leaves
    mb.box((0, 2.4, -0.3), (2.0, 3.6, 0.08), "timber_old")
    # the bell-cote: a gable with an open arch and a bell
    mb.box((0, 8.1, 0.0), (2.6, 1.0, 0.9), "stone_dark", col=True)
    mb.wedge((0, 8.6, 0.0), 2.8, 1.0, 1.1, "slate", col=False)
    for sx in (-1, 1):
        mb.box((sx * 0.9, 9.1, 0.0), (0.4, 1.4, 0.8), "stone_dark")
    mb.cyl((0, 8.9, 0), 0.3, 0.45, 0.12, 8, "copper") if False else mb.cyl((0, 8.75, 0.0), 0.42, 0.18, 0.55, 10, "copper")
    mb.box((0, 9.45, 0.0), (1.4, 0.2, 0.8), "stone_dark")
    # a gabled hood on the front over the steps, on two posts
    mb.wedge((0, 4.6, 1.6), 5.6, 2.0, 1.2, "slate", col=False) if False else None
    return mb.build()


# ================================================================== the salt-works
def works_hall():
    CURRENT[0] = "works_hall"
    mb = MB("Works_Hall")
    L, Wd = 14.0, 8.0
    mb.box((0, 0.3, 0), (L + 0.6, 0.6, Wd + 0.6), "stone", col=False)
    # stone footings walls to 1.6, timber-framed plaster above with doors
    wall(mb, 'x', (0, Wd / 2), L, 0.6, 0.6, 4.6, "plaster", holes=[(-3.0, 3.2, 0.6, 3.6), (4.0, 1.4, 1.6, 3.0)])
    wall(mb, 'x', (0, -Wd / 2), L, 0.6, 0.6, 4.6, "plaster", holes=[(-4.0, 1.4, 1.6, 3.0), (3.0, 1.4, 1.6, 3.0)])
    wall(mb, 'z', (L / 2, 0), Wd, 0.6, 0.6, 4.6, "plaster")
    wall(mb, 'z', (-L / 2, 0), Wd, 0.6, 0.6, 4.6, "plaster")
    mb.box((0, 0.2, 0), (L - 0.5, 0.4, Wd - 0.5), "salt")
    # timber frame: posts and a wall plate
    for i in range(8):
        x = -L / 2 + L * i / 7
        mb.box((x, 2.6, Wd / 2 + 0.34), (0.22, 4.0, 0.14), "timber")
        mb.box((x, 2.6, -Wd / 2 - 0.34), (0.22, 4.0, 0.14), "timber")
    mb.box((0, 4.65, Wd / 2 + 0.34), (L + 0.4, 0.3, 0.18), "timber")
    mb.box((0, 4.65, -Wd / 2 - 0.34), (L + 0.4, 0.3, 0.18), "timber")
    mb.box((-3.0, 3.75, Wd / 2 + 0.4), (3.6, 0.22, 0.22), "timber")
    # the roof: a big slate gable, a louvred cupola on the ridge
    mb.wedge((0, 4.7, 0), Wd + 1.8, L + 1.2, 3.4, "slate", ry=math.pi / 2)
    mb.box((0, 8.4, 0), (1.4, 0.9, 3.0), "timber_old")
    mb.wedge((0, 9.25, 0), 1.9, 3.4, 0.8, "slate", ry=math.pi / 2)
    for i in range(5):
        mb.box((0, 8.2 + i * 0.1, 1.55), (1.2, 0.05, 0.05), "timber")
    # the boiling-house chimney
    mb.box((5.0, 6.0, -1.0), (1.8, 10.0, 1.8), "stone", col=True)
    mb.box((5.0, 11.1, -1.0), (2.1, 0.3, 2.1), "stone")
    mb.box((5.0, 11.0, -1.0), (1.2, 0.04, 1.2), "void")
    # pan irons inside by the door, a big salt heap, barrels
    mb.box((-1.0, 0.7, -1.0), (5.0, 0.3, 2.4), "iron")
    mb.cone((3.5, 0.0, 1.6), 1.6, 1.5, 10, "salt") if False else mb.cyl((-5.0, 0.4, 1.5), 1.6, 0.2, 1.4, 10, "salt", cap=False)
    for i in range(4):
        mb.cyl((-5.8 + i * 0.7, 0.4, -2.8), 0.32, 0.32, 0.85, 10, "timber_old")
    # a hoist beam jutting from the gable with a rope and hook
    mb.box((0, 5.6, L / 2 + 1.0), (0.22, 0.22, 2.4), "timber")
    mb.box((0, 4.9, L / 2 + 1.9), (0.04, 1.4, 0.04), "iron")
    return mb.build()


def derrick():
    CURRENT[0] = "derrick"
    mb = MB("Derrick")
    H = 9.0
    for (sx, sz) in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
        # legs lean in toward the top
        a = Vector((sx * 2.0, 0, sz * 2.0))
        b = Vector((sx * 0.5, H, sz * 0.5))
        d = b - a
        mid = (a + b) / 2
        pitch = math.atan2(math.hypot(d.x, d.z), d.y)
        yaw = math.atan2(d.x, d.z)
        M = Euler((0, yaw, 0), 'XYZ').to_matrix() @ Euler((math.pi / 2 - (math.pi / 2 - pitch) * 0 - math.atan2(d.y, math.hypot(d.x, d.z)) * 0 + 0, 0, 0), 'XYZ').to_matrix()
        # build the leg as a box along the vector with a look-at basis
        z = d.normalized()
        x = Vector((0, 1, 0)).cross(z).normalized() if abs(z.y) < 0.99 else Vector((1, 0, 0))
        y = z.cross(x)
        R = Matrix(((x.x, y.x, z.x), (x.y, y.y, z.y), (x.z, y.z, z.z)))
        mb.box(tuple(mid), (0.28, 0.28, d.length), "timber", rot=tuple(R.to_euler('XYZ')))
    for yy in (2.5, 5.2, 7.4):
        w = 2.0 - (yy / H) * 1.5
        for (c, s) in (((0, yy, w), (2 * w, 0.14, 0.14)), ((0, yy, -w), (2 * w, 0.14, 0.14)), ((w, yy, 0), (0.14, 0.14, 2 * w)), ((-w, yy, 0), (0.14, 0.14, 2 * w))):
            mb.box(c, s, "timber")
    mb.box((0, 5.0, 0), (2.4, 0.14, 2.4), "timber_old", col=True)                       # the working floor
    mb.box((0, H + 0.1, 0), (1.4, 0.3, 1.4), "timber")
    # the boom: a long beam out over the pan with a pulley, a counterweight of stones in a crate
    mb.box((0, H + 0.6, 2.6), (0.3, 0.3, 7.0), "timber")
    mb.box((0, H + 0.6, -2.4), (0.9, 0.9, 0.9), "stone_dark")
    mb.box((0, H - 1.2, 5.6), (0.03, 4.0, 0.03), "iron")
    mb.cyl((0, H - 3.6, 5.6), 0.5, 0.4, 0.55, 10, "timber_old")
    mb.box((0, H + 1.3, 0), (0.3, 1.6, 0.3), "timber")
    COL["derrick"] = [[round(v, 3) for v in (sx * 1.25, 4.5, sz * 1.25, 0.4, 9.0, 0.4, 0, 0, 0)] for sx in (-1, 1) for sz in (-1, 1)]
    return mb.build()


def pan_unit():
    CURRENT[0] = "pan"
    mb = MB("Pan_Unit")
    for (c, s) in (((0, 0.2, 2.4), (7.0, 0.4, 0.3)), ((0, 0.2, -2.4), (7.0, 0.4, 0.3)), ((3.35, 0.2, 0), (0.3, 0.4, 4.5)), ((-3.35, 0.2, 0), (0.3, 0.4, 4.5))):
        mb.box(c, s, "timber_old")
    mb.box((0, 0.12, 0), (6.4, 0.06, 4.5), "brine")
    mb.box((0, 0.1, 0), (6.4, 0.04, 4.5), "salt")
    COL["pan"] = [[0, 0.2, 2.4, 7.0, 0.4, 0.3, 0, 0, 0], [0, 0.2, -2.4, 7.0, 0.4, 0.3, 0, 0, 0], [3.35, 0.2, 0, 0.3, 0.4, 4.5, 0, 0, 0], [-3.35, 0.2, 0, 0.3, 0.4, 4.5, 0, 0, 0]]
    return mb.build()


def crystal(name, seed):
    CURRENT[0] = "crystal"
    mb = MB(name)
    rng = np.random.default_rng(seed)
    for i in range(7):
        a = rng.uniform(0, math.tau)
        r = rng.uniform(0.0, 0.6)
        h = rng.uniform(0.7, 2.2) * (1.4 if i == 0 else 1.0)
        w = rng.uniform(0.12, 0.28)
        lean = rng.uniform(0.0, 0.35)
        mb.cyl((math.cos(a) * r, 0, math.sin(a) * r), w, w * 0.8, h, 6, "salt")
        mb.cone((math.cos(a) * r, h, math.sin(a) * r), w * 0.8, w * 1.8, 6, "salt")
    return mb.build()


def salt_heap():
    CURRENT[0] = "heap"
    mb = MB("Salt_Heap")
    mb.cyl((0, 0, 0), 1.8, 0.5, 1.5, 9, "salt", cap=False)
    mb.cone((0, 1.5, 0), 0.5, 0.35, 9, "salt")
    return mb.build()


# ================================================================== the hamlet
def house(name, w, d, wall_h, roof_h, door_x=0.0):
    CURRENT[0] = name.lower()
    mb = MB(name)
    mb.box((0, 0.2, 0), (w + 0.4, 0.4, d + 0.4), "stone", col=False)
    wall(mb, 'x', (0, d / 2), w, 0.5, 0.4, wall_h, "plaster", holes=[(door_x, 1.1, 0.4, 2.2), (-w / 3, 0.8, 1.2, 2.0)])
    wall(mb, 'x', (0, -d / 2), w, 0.5, 0.4, wall_h, "plaster", holes=[(w / 4, 0.8, 1.2, 2.0)])
    wall(mb, 'z', (w / 2, 0), d, 0.5, 0.4, wall_h, "plaster")
    wall(mb, 'z', (-w / 2, 0), d, 0.5, 0.4, wall_h, "plaster", holes=[(0.5, 0.8, 1.2, 2.0)])
    mb.box((0, wall_h * 0.5 + 0.2, 0), (w - 0.6, wall_h, d - 0.6), "void")
    mb.box((0, 0.35, 0), (w - 0.5, 0.1, d - 0.5), "timber_old")
    # exposed timbers
    for i in range(int(w // 1.6) + 1):
        x = -w / 2 + 0.25 + i * (w - 0.5) / max(int(w // 1.6), 1)
        mb.box((x, wall_h / 2 + 0.2, d / 2 + 0.29), (0.16, wall_h - 0.4, 0.1), "timber")
    mb.box((0, wall_h - 0.05, d / 2 + 0.29), (w + 0.2, 0.2, 0.12), "timber")
    # door and shutters
    mb.box((door_x, 1.3, d / 2 + 0.1), (1.0, 1.9, 0.08), "timber_old", rot=(0, 0.5, 0))
    mb.wedge((0, wall_h, 0), d + 1.0, w + 0.9, roof_h, "slate", ry=math.pi / 2, col=False)
    COL[name.lower()] = [[0, wall_h / 2 + 0.2, 0, w + 0.2, wall_h, d + 0.2, 0, 0, 0], [0, wall_h + roof_h * 0.35, 0, w, roof_h * 0.7, d, 0, 0, 0]]
    # chimney
    mb.box((w / 2 - 0.9, wall_h + roof_h * 0.7, 0.0), (0.7, roof_h * 1.6, 0.7), "stone")
    return mb.build()


def drying_shed():
    CURRENT[0] = "drying_shed"
    mb = MB("Drying_Shed")
    for (x, z) in ((-3.4, -1.6), (-3.4, 1.6), (0, -1.6), (0, 1.6), (3.4, -1.6), (3.4, 1.6)):
        mb.box((x, 1.6, z), (0.22, 3.2, 0.22), "timber")
    for z in (-1.6, 1.6):
        mb.box((0, 3.2, z), (7.4, 0.2, 0.22), "timber")
    for i in range(4):
        mb.box((0, 1.4 + i * 0.45, 0), (7.0, 0.05, 0.05), "timber")
        for j in range(9):
            mb.box((-3.2 + j * 0.8, 1.2 + i * 0.45, 0.0), (0.18, 0.4, 0.04), "salt")
    mb.wedge((0, 3.2, 0), 4.2, 8.0, 1.0, "timber_old", ry=0.0)
    COL["drying_shed"] = [[x, 1.6, z, 0.3, 3.2, 0.3, 0, 0, 0] for x in (-3.4, 0, 3.4) for z in (-1.6, 1.6)]
    return mb.build()


def stall():
    CURRENT[0] = "stall"
    mb = MB("Stall")
    for (x, z) in ((-1.4, -0.8), (1.4, -0.8)):
        mb.box((x, 1.3, z), (0.14, 2.6, 0.14), "timber")
    for x in (-1.4, 1.4):
        mb.box((x, 1.0, 0.9), (0.14, 2.0, 0.14), "timber")
    mb.box((0, 1.0, 0.55), (3.2, 0.1, 1.0), "timber_old", col=False)
    mb.box((0, 0.5, 0.55), (3.0, 1.0, 0.9), "timber", col=False)
    mb.wedge((0, 2.4, 0.0), 3.6, 3.0, 0.5, "plaster", ry=math.pi / 2)
    for i in range(5):
        mb.cyl((-1.1 + i * 0.55, 1.05, 0.5), 0.2, 0.12, 0.34, 8, "salt")
    COL["stall"] = [[0, 0.5, 0.55, 3.2, 1.0, 1.0, 0, 0, 0]]
    return mb.build()


# ================================================================== export
def export(objs, path):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True, export_apply=True, export_yup=True,
                              export_image_format='AUTO', export_materials='EXPORT', export_cameras=False, export_lights=False)
    tris = sum(len(o.data.polygons) for o in objs)
    print("R37E export", os.path.basename(path), [(o.name, len(o.data.polygons)) for o in objs])


def wipe():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o)


def write_boxes():
    def fmt(v):
        if len(v) == 9:       # euler (Y-up space, mathutils XYZ) -> quaternion x y z w, which Godot reads as is
            q = Euler((v[6], v[7], v[8]), 'XYZ').to_quaternion()
            v = list(v[:6]) + [q.x, q.y, q.z, q.w]
        return "[" + ", ".join(("%g" % x) for x in v) + "]"
    lines = ["extends RefCounted", "## GENERATED by tools/blender/r37_east.py: collision boxes [cx, cy, cz, sx, sy, sz, qx, qy, qz, qw] and ramps",
             "## [lo xyz, hi xyz, width] taken from the meshes' own numbers (local to each asset's origin). Do not edit.", ""]
    for nm, rows in sorted(COL.items()):
        lines.append("const %s := [" % (nm.upper() + "_BOXES"))
        for r in rows:
            lines.append("\t" + fmt(r) + ",")
        lines.append("]")
    for nm, rows in sorted(RAMPS.items()):
        lines.append("const %s := [" % (nm.upper() + "_RAMPS"))
        for r in rows:
            lines.append("\t" + fmt(r) + ",")
        lines.append("]")
    lines.append("")
    open(os.path.join(ROOT, "core/world/realm/r37_east_boxes.gd"), "w").write("\n".join(lines))


def main():
    wipe()
    build_materials()
    models = os.path.join(ROOT, "art/models")
    s0 = spire(0)
    s1 = spire(1)
    s2 = spire(2)
    export([s0, s1, s2], os.path.join(models, "r37e_spire.glb"))
    wipe_keep = [s0, s1, s2]
    cells = [cell_portal(), cell_slit(), walk_span(), walk_stair(), ladder(), chapel_front()]
    # lay the kit out apart so one scene holds them (names are what Godot reads)
    export(cells, os.path.join(models, "r37e_cells.glb"))
    sw = [works_hall(), derrick(), pan_unit(), crystal("Crystal_A", 3), crystal("Crystal_B", 9), salt_heap()]
    export(sw, os.path.join(models, "r37e_saltworks.glb"))
    ham = [house("House_A", 7.0, 5.0, 3.0, 2.4, 0.6), house("House_B", 6.0, 4.6, 2.8, 2.1, -0.8), house("House_C", 8.0, 5.6, 3.2, 2.7, 0.0),
           drying_shed(), stall()]
    export(ham, os.path.join(models, "r37e_hamlet.glb"))
    write_boxes()
    if PREVIEW:
        render(PREVIEW)


def render(prefix):
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_WORKBENCH'
    sc.display.shading.color_type = 'TEXTURE'
    sc.display.shading.light = 'STUDIO'
    sc.display.shading.show_cavity = False
    sc.render.resolution_x, sc.render.resolution_y = 900, 1200
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", 'SUN'))
    sun.rotation_euler = (0.9, 0.2, 0.6)
    sc.world = bpy.data.worlds.new('w')
    sc.world.color = (0.5, 0.5, 0.55)
    sun.data.energy = 3.0
    sc.collection.objects.link(sun)
    for o in bpy.data.objects:
        if o.type == 'MESH':
            o.hide_render = True
    def shot(ob, loc, tgt, name):
        for o in bpy.data.objects:
            if o.type == 'MESH':
                o.hide_render = o is not ob
        loc = (loc[0], -loc[2], loc[1])
        tgt = (tgt[0], -tgt[2], tgt[1])
        cam.location = loc
        d = Vector(tgt) - Vector(loc)
        cam.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
        sc.render.filepath = prefix + "_" + name + ".png"
        bpy.ops.render.render(write_still=True)
    for o in bpy.data.objects:
        if o.name == "Spire_LOD0":
            shot(o, (50, 20, 58), (0, 15, 0), "spire")
        if o.name == "Chapel_Front":
            shot(o, (9, 5, 14), (0, 4, 0), "chapel")
        if o.name == "Works_Hall":
            shot(o, (18, 8, 20), (0, 4, 0), "works")
        if o.name == "Derrick":
            shot(o, (16, 7, 16), (0, 5, 2), "derrick")
        if o.name == "House_A":
            shot(o, (10, 5, 11), (0, 2, 0), "house")


main()
