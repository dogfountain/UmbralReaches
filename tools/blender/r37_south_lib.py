"""r37 South: shared helpers for the March Wall kit, the Grandmother Oak, the Well of Echoes and the
shepherds' hut (tools/blender/r37_south.py).

Everything is authored in GODOT coordinates (x right, y up, z back) and mapped to Blender (x, -z, y)
when a mesh is finished, so numbers here are the numbers the game uses. 1 unit = 1 m.

Textures are made here, not downloaded: tileable spectral noise (FFT) shaped into masonry, bark,
chalk strata, thatch and planks, each with an albedo, a normal map derived from its height field and
an ORM map (occlusion / roughness / metal). They are baked into the glb with the mesh.
"""
import bpy
import bmesh
import math
import os
import json
import random
import numpy as np
from mathutils import Vector, Matrix, noise

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MODEL_DIR = os.path.join(ROOT, "art", "models")
BLEND_DIR = os.path.join(ROOT, "art", "blender")
TEX_DIR = os.path.join(BLEND_DIR, "textures", "r37_south")


def G(v):
    """Godot point -> Blender point."""
    return Vector((v[0], -v[2], v[1]))


def V(x, y, z):
    return Vector((x, y, z))


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.unit_settings.system = 'METRIC'
    sc.render.engine = 'BLENDER_WORKBENCH'


# --- textures ------------------------------------------------------------------------------------

def fbm(n, beta=2.0, seed=0, aniso=1.0, aniso_u=1.0):
    """Tileable noise in 0..1. beta ~2 is cloudy, ~3 smooth; aniso > 1 stretches features along v
    (image rows), aniso_u > 1 along u."""
    rng = np.random.default_rng(seed)
    f = np.fft.fftfreq(n)
    fx, fy = np.meshgrid(f * aniso_u, f * aniso)
    r = np.sqrt(fx * fx + fy * fy)
    r[0, 0] = 1.0
    amp = 1.0 / np.power(r, beta * 0.5)
    amp[0, 0] = 0.0
    spec = np.fft.fft2(rng.standard_normal((n, n))) * amp
    img = np.real(np.fft.ifft2(spec))
    lo, hi = np.percentile(img, 1.0), np.percentile(img, 99.0)
    return np.clip((img - lo) / max(hi - lo, 1e-9), 0.0, 1.0)


def smooth(a, lo, hi):
    t = np.clip((a - lo) / max(hi - lo, 1e-9), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def normal_from_height(h, strength):
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5 * strength * h.shape[1]
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5 * strength * h.shape[0]
    nx, ny, nz = -dx, dy, np.ones_like(h)
    ln = np.sqrt(nx * nx + ny * ny + nz * nz)
    return np.stack([nx / ln * 0.5 + 0.5, ny / ln * 0.5 + 0.5, nz / ln * 0.5 + 0.5], axis=-1)


def ao_from_height(h, k=1.6):
    blur = h.copy()
    for s in (1, 2, 4, 8):
        blur = (blur + np.roll(blur, s, 0) + np.roll(blur, -s, 0) + np.roll(blur, s, 1) + np.roll(blur, -s, 1)) / 5.0
    return np.clip(1.0 - np.clip(blur - h, 0.0, 1.0) * k, 0.25, 1.0)


def tint(h, lo, hi):
    lo = np.array(lo, dtype=np.float64)
    hi = np.array(hi, dtype=np.float64)
    return lo[None, None, :] * (1.0 - h[..., None]) + hi[None, None, :] * h[..., None]


def tex_masonry(n, seed, rows=7, cold=True):
    """Coursed dry masonry: blocks of varied size, mortar gaps, lichen, grime streaks. -> albedo, height, rough."""
    rng = np.random.default_rng(seed)
    ids = np.zeros((n, n), dtype=np.int32)
    x0m = np.zeros((n, n))
    x1m = np.zeros((n, n))
    y0m = np.zeros((n, n))
    y1m = np.zeros((n, n))
    hs = rng.uniform(0.7, 1.3, rows)
    hs = np.round(hs / hs.sum() * n).astype(int)
    hs[-1] = n - hs[:-1].sum()
    y = 0
    bid = 1
    for ri in range(rows):
        h = int(hs[ri])
        widths = []
        tot = 0
        while tot < n:
            w = int(rng.uniform(0.9, 2.2) * h)
            widths.append(w)
            tot += w
        widths[-1] -= tot - n
        if widths[-1] < h * 0.5 and len(widths) > 1:
            widths[-2] += widths[-1]
            widths.pop()
        x = int(rng.integers(0, n))
        xs = np.arange(n)
        for w in widths:
            # block spans x..x+w (wrapping)
            cols = (np.arange(w) + x) % n
            ids[y:y + h][:, cols] = bid
            x0m[y:y + h][:, cols] = np.arange(w)[None, :]
            x1m[y:y + h][:, cols] = (w - 1 - np.arange(w))[None, :]
            y0m[y:y + h, :][:, cols] = np.arange(h)[:, None]
            y1m[y:y + h, :][:, cols] = (h - 1 - np.arange(h))[:, None]
            x += w
            bid += 1
        y += h
    d = np.minimum(np.minimum(x0m, x1m), np.minimum(y0m, y1m))
    gap = n * 0.0045
    face = smooth(d, gap, gap + n * 0.018)                       # 0 in mortar, 1 on the block face
    block_rand = rng.uniform(0.0, 1.0, bid + 1)[ids]
    block_tone = rng.uniform(-1.0, 1.0, bid + 1)[ids]
    big = fbm(n, 2.4, seed + 1)
    mid = fbm(n, 1.6, seed + 2)
    fine = fbm(n, 1.0, seed + 3)
    height = face * (0.55 + 0.25 * block_rand + 0.35 * (big - 0.5)) + 0.12 * (mid - 0.5) + 0.05 * (fine - 0.5)
    height = np.clip(height, 0.0, 1.0)
    base_lo = (0.17, 0.165, 0.16) if cold else (0.2, 0.17, 0.14)
    base_hi = (0.40, 0.385, 0.36) if cold else (0.44, 0.38, 0.31)
    tone = np.clip(0.5 + 0.28 * block_tone + 0.35 * (mid - 0.5) + 0.12 * (fine - 0.5), 0.0, 1.0)
    alb = tint(tone, base_lo, base_hi)
    alb *= (0.55 + 0.45 * face)[..., None]                                 # mortar and joints are dark
    # lichen: pale yellow-green on the upper-left of blocks, stronger in patches
    lich = smooth(fbm(n, 2.0, seed + 4) * (0.7 + 0.3 * fine), 0.58, 0.8) * face
    alb = alb * (1.0 - 0.7 * lich[..., None]) + np.array([0.43, 0.46, 0.27])[None, None, :] * 0.5 * lich[..., None]
    # damp, dark streaks running down
    streak = smooth(fbm(n, 2.4, seed + 5, aniso=8.0), 0.6, 0.9)
    alb *= (1.0 - 0.35 * streak)[..., None]
    rough = np.clip(0.78 + 0.2 * (fine - 0.5) - 0.12 * lich + 0.1 * (1.0 - face), 0.5, 1.0)
    return alb, height, rough


def tex_bark(n, seed, dead=True):
    """Weathered oak bark: deep vertical fissures, scaly plates, grey-silver where the tree is dead."""
    rid = fbm(n, 2.6, seed, aniso=5.0)
    ridge = 1.0 - np.abs(rid * 2.0 - 1.0)
    ridge = ridge ** 1.4
    fine = fbm(n, 1.6, seed + 1, aniso=3.0)
    scale = fbm(n, 1.2, seed + 2, aniso=1.4)
    plates = smooth(scale, 0.3, 0.7)
    height = np.clip(0.62 * ridge + 0.26 * fine + 0.14 * plates, 0.0, 1.0)
    fis = smooth(height, 0.18, 0.42)                                     # 0 in the fissure floor
    lo = (0.045, 0.036, 0.03)
    hi = (0.30, 0.255, 0.215) if dead else (0.22, 0.17, 0.12)
    tone = np.clip(0.2 + 0.7 * height + 0.18 * (fine - 0.5), 0.0, 1.0)
    alb = tint(tone, lo, hi)
    if dead:
        silver = smooth(fbm(n, 2.2, seed + 3, aniso=3.0), 0.5, 0.85)
        alb = alb * (1.0 - 0.45 * silver[..., None]) + np.array([0.36, 0.34, 0.31])[None, None, :] * 0.45 * silver[..., None] * fis[..., None]
    moss = smooth(fbm(n, 2.8, seed + 4), 0.64, 0.86) * fis
    lichen = smooth(fbm(n, 2.2, seed + 5), 0.7, 0.9) * fis
    alb = alb * (1.0 - 0.6 * moss[..., None]) + np.array([0.09, 0.14, 0.05])[None, None, :] * 0.6 * moss[..., None]
    alb = alb * (1.0 - 0.5 * lichen[..., None]) + np.array([0.4, 0.42, 0.3])[None, None, :] * 0.5 * lichen[..., None]
    rough = np.clip(0.9 + 0.1 * (fine - 0.5) - 0.12 * moss, 0.55, 1.0)
    return alb, height, rough


def tex_chalk(n, seed):
    """Pale limestone / chalk rock: horizontal strata, fractures, flint nodules, damp lower stain."""
    warp = fbm(n, 3.0, seed)
    yy = (np.arange(n)[:, None] / n) * np.ones((1, n))
    strata = 0.5 + 0.5 * np.sin((yy * 17.0 + warp * 2.2) * math.pi * 2.0 / 1.0)
    strata2 = 0.5 + 0.5 * np.sin((yy * 5.0 + warp * 1.4 + 0.3) * math.pi * 2.0)
    mid = fbm(n, 1.8, seed + 1)
    fine = fbm(n, 1.0, seed + 2)
    cr = 1.0 - np.abs(fbm(n, 2.4, seed + 3, aniso_u=2.2) * 2.0 - 1.0)
    cracks = smooth(cr, 0.88, 0.97)
    height = np.clip(0.35 * strata + 0.25 * strata2 + 0.3 * mid + 0.1 * fine - 0.35 * cracks, 0.0, 1.0)
    tone = np.clip(0.55 + 0.25 * (mid - 0.5) + 0.15 * (strata - 0.5) + 0.08 * (fine - 0.5), 0.0, 1.0)
    alb = tint(tone, (0.3, 0.285, 0.255), (0.62, 0.6, 0.55))
    alb *= (1.0 - 0.6 * cracks)[..., None]
    flint = smooth(fbm(n, 0.8, seed + 4), 0.86, 0.93)
    alb = alb * (1.0 - flint[..., None]) + np.array([0.06, 0.06, 0.07])[None, None, :] * flint[..., None]
    moss = smooth(fbm(n, 2.4, seed + 5), 0.66, 0.85)
    alb = alb * (1.0 - 0.5 * moss[..., None]) + np.array([0.12, 0.16, 0.07])[None, None, :] * 0.5 * moss[..., None]
    streak = smooth(fbm(n, 2.4, seed + 6, aniso=8.0), 0.55, 0.9)
    alb *= (1.0 - 0.3 * streak)[..., None]
    rough = np.clip(0.86 + 0.12 * (fine - 0.5), 0.6, 1.0)
    return alb, height, rough


def tex_thatch(n, seed):
    """Old reed thatch: combed vertical straw, layered courses, black with weather, green with moss."""
    straw = fbm(n, 1.0, seed, aniso=14.0)
    course = 0.5 + 0.5 * np.sin((np.arange(n)[:, None] / n) * math.pi * 2.0 * 6.0 + fbm(n, 3.0, seed + 1) * 2.0)
    mid = fbm(n, 2.0, seed + 2)
    height = np.clip(0.55 * straw + 0.3 * course + 0.15 * mid, 0.0, 1.0)
    tone = np.clip(0.3 + 0.55 * straw + 0.2 * (mid - 0.5), 0.0, 1.0)
    alb = tint(tone, (0.09, 0.07, 0.045), (0.36, 0.29, 0.17))
    moss = smooth(fbm(n, 2.6, seed + 3), 0.6, 0.84)
    alb = alb * (1.0 - 0.6 * moss[..., None]) + np.array([0.08, 0.13, 0.05])[None, None, :] * 0.6 * moss[..., None]
    rough = np.clip(0.9 + 0.1 * (straw - 0.5), 0.6, 1.0)
    return alb, height, rough


def tex_planks(n, seed):
    """Weathered grey oak planks, six to the tile, with grain, knots, nail rows and gaps."""
    cols = 6
    w = n // cols
    px = np.arange(n)[None, :] % w
    gap = smooth(np.minimum(px, w - 1 - px).astype(float), 1.0, n * 0.012) * np.ones((n, 1))
    grain = fbm(n, 1.4, seed, aniso=16.0)
    fine = fbm(n, 1.0, seed + 1, aniso=10.0)
    pid = (np.arange(n)[None, :] // w) * np.ones((n, 1), dtype=int)
    rr = np.random.default_rng(seed).uniform(-1, 1, cols + 1)[np.clip(pid, 0, cols)]
    height = np.clip(gap * (0.5 + 0.3 * grain + 0.15 * fine + 0.05 * rr), 0.0, 1.0)
    tone = np.clip(0.45 + 0.4 * (grain - 0.5) + 0.15 * rr + 0.1 * (fine - 0.5), 0.0, 1.0)
    alb = tint(tone, (0.08, 0.07, 0.06), (0.34, 0.31, 0.27))
    alb *= (0.45 + 0.55 * gap)[..., None]
    silver = smooth(fbm(n, 2.0, seed + 2, aniso=6.0), 0.55, 0.85)
    alb = alb * (1.0 - 0.3 * silver[..., None]) + 0.3 * silver[..., None] * np.array([0.3, 0.3, 0.29])[None, None, :]
    rough = np.clip(0.88 + 0.1 * (fine - 0.5), 0.6, 1.0)
    return alb, height, rough


# --- materials -----------------------------------------------------------------------------------

def _img(name, arr, srgb):
    h, w = arr.shape[0], arr.shape[1]
    rgba = np.ones((h, w, 4), dtype=np.float32)
    rgba[..., :3] = np.clip(arr, 0.0, 1.0)
    rgba = np.flipud(rgba)
    im = bpy.data.images.new(name, w, h, alpha=False)
    im.colorspace_settings.name = 'sRGB' if srgb else 'Non-Color'
    im.pixels.foreach_set(np.ascontiguousarray(rgba, dtype=np.float32).ravel())
    im.update()
    return im


def pbr(name, maps, normal_strength=3.0, metal=0.0, save=True):
    """A Principled material from (albedo, height, rough)."""
    alb, height, rough = maps
    ao = ao_from_height(height)
    orm = np.stack([ao, rough, np.full_like(rough, metal)], axis=-1)
    nrm = normal_from_height(height, normal_strength)
    imgs = {"alb": _img(name + "_albedo", alb, True), "nrm": _img(name + "_normal", nrm, False), "orm": _img(name + "_orm", orm, False)}
    if save:
        os.makedirs(TEX_DIR, exist_ok=True)
        for k, im in imgs.items():
            jpg = k != "nrm"                      # normals stay lossless; albedo and ORM take JPEG (a third of the size)
            im.filepath_raw = os.path.join(TEX_DIR, im.name + (".jpg" if jpg else ".png"))
            im.file_format = 'JPEG' if jpg else 'PNG'
            im.save(quality=92) if jpg else im.save()
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    ta = nt.nodes.new("ShaderNodeTexImage")
    ta.image = imgs["alb"]
    tn = nt.nodes.new("ShaderNodeTexImage")
    tn.image = imgs["nrm"]
    to = nt.nodes.new("ShaderNodeTexImage")
    to.image = imgs["orm"]
    nm = nt.nodes.new("ShaderNodeNormalMap")
    sep = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(ta.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(tn.outputs["Color"], nm.inputs["Color"])
    nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    nt.links.new(to.outputs["Color"], sep.inputs["Color"])
    nt.links.new(sep.outputs["Green"], bsdf.inputs["Roughness"])
    nt.links.new(sep.outputs["Blue"], bsdf.inputs["Metallic"])
    # glTF occlusion: a custom group the exporter understands
    grp = bpy.data.node_groups.get("glTF Material Output")
    if grp is None:
        grp = bpy.data.node_groups.new("glTF Material Output", 'ShaderNodeTree')
        grp.interface.new_socket("Occlusion", in_out='INPUT', socket_type='NodeSocketFloat')
    go = nt.nodes.new("ShaderNodeGroup")
    go.node_tree = grp
    nt.links.new(sep.outputs["Red"], go.inputs["Occlusion"])
    return m


def flat(name, color, rough=0.9, metal=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1.0)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    return m


# --- geometry ------------------------------------------------------------------------------------

def hash3(x, y, z, seed=0):
    return noise.noise(Vector((x * 0.37 + seed * 7.1, y * 0.37 - seed * 3.3, z * 0.37 + seed * 1.7)))


class B:
    """One mesh being built, in Godot coordinates, with one material slot per `mat` key used."""

    def __init__(self, name, mats):
        self.name = name
        self.mats = mats                    # key -> bpy material
        self.keys = list(mats.keys())
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")

    # -- primitives -----------------------------------------------------------------------------
    def face(self, pts, mat, uvs=None):
        vs = [self.bm.verts.new(Vector(p)) for p in pts]
        try:
            f = self.bm.faces.new(vs)
        except ValueError:
            return None
        f.material_index = self.keys.index(mat)
        f.smooth = False
        if uvs:
            for l, uv in zip(f.loops, uvs):
                l[self.uv].uv = uv
        return f

    def box(self, c, size, mat, yaw=0.0, pitch=0.0, roll=0.0, scale_uv=0.22, cuts=0, jit=0.0, seed=0, taper=1.0):
        """A box centred on c. taper < 1 narrows the top face (a battered wall)."""
        res = bmesh.ops.create_cube(self.bm, size=1.0)
        verts = res["verts"]
        rot = Matrix.Rotation(yaw, 3, 'Y') @ Matrix.Rotation(pitch, 3, 'X') @ Matrix.Rotation(roll, 3, 'Z')
        sx, sy, sz = size
        for v in verts:
            p = Vector(v.co)
            t = 1.0 if p.y < 0 else taper
            v.co = Vector((p.x * sx * t, p.y * sy, p.z * sz * t))
        if cuts > 0:
            geo = bmesh.ops.subdivide_edges(self.bm, edges=list({e for v in verts for e in v.link_edges}), cuts=cuts, use_grid_fill=True)
            vs = set()
            for g in geo["geom"]:
                if isinstance(g, bmesh.types.BMVert):
                    vs.add(g)
                elif isinstance(g, bmesh.types.BMEdge):
                    vs.update(g.verts)
                elif isinstance(g, bmesh.types.BMFace):
                    vs.update(g.verts)
            verts = list(vs)
        seen = set()
        for v in list(verts):
            if v in seen:
                continue
            seen.add(v)
            p = rot @ v.co + Vector(c)
            if jit > 0.0:
                p += Vector((hash3(p.x, p.y, p.z, seed), hash3(p.x + 9, p.y, p.z, seed), hash3(p.x, p.y + 9, p.z, seed))) * jit
            v.co = p
        faces = {f for v in seen for f in v.link_faces}
        for f in faces:
            f.material_index = self.keys.index(mat)
            f.smooth = False
        self._box_uv(faces, scale_uv)
        return faces

    def _box_uv(self, faces, s):
        for f in faces:
            f.normal_update()
            n = f.normal
            ax = max(range(3), key=lambda i: abs(n[i]))
            for l in f.loops:
                p = l.vert.co
                if ax == 0:
                    uv = (p.z * s, p.y * s)
                elif ax == 1:
                    uv = (p.x * s, p.z * s)
                else:
                    uv = (p.x * s, p.y * s)
                l[self.uv].uv = uv

    def loft(self, rings, mat, closed=True, cap_start=False, cap_end=False, smooth=True, box_uv=0.5):
        """Faces between consecutive rings (equal vertex counts), box-projected UVs."""
        bm = self.bm
        vr = [[bm.verts.new(Vector(p)) for p in ring] for ring in rings]
        n = len(rings[0])
        faces = []
        for i in range(len(rings) - 1):
            for j in range(n if closed else n - 1):
                j2 = (j + 1) % n
                try:
                    f = bm.faces.new([vr[i][j], vr[i][j2], vr[i + 1][j2], vr[i + 1][j]])
                except ValueError:
                    continue
                f.material_index = self.keys.index(mat)
                f.smooth = smooth
                faces.append(f)
        if cap_start:
            try:
                f = bm.faces.new(list(reversed(vr[0])))
                f.material_index = self.keys.index(mat)
                faces.append(f)
            except ValueError:
                pass
        if cap_end:
            try:
                f = bm.faces.new(vr[-1])
                f.material_index = self.keys.index(mat)
                faces.append(f)
            except ValueError:
                pass
        self._box_uv(faces, box_uv)
        return faces

    def tube(self, a, b, r0, r1, mat, sides=7, bark=3.0, jit=0.0, seed=0, cap=True):
        """A tapering round beam from a to b (Godot points) with cylindrical UVs (bark tile = `bark` m)."""
        a = Vector(a)
        b = Vector(b)
        d = (b - a)
        L = d.length
        up = d.normalized()
        ref = Vector((0, 1, 0)) if abs(up.y) < 0.9 else Vector((1, 0, 0))
        side = up.cross(ref).normalized()
        fwd = up.cross(side).normalized()
        rings = []
        segs = max(1, int(L / 1.6))
        for i in range(segs + 1):
            t = i / segs
            c = a.lerp(b, t)
            r = r0 + (r1 - r0) * t
            ring = []
            for j in range(sides):
                an = math.tau * j / sides
                p = c + side * math.cos(an) * r + fwd * math.sin(an) * r
                if jit > 0.0:
                    p += (p - c).normalized() * hash3(p.x, p.y, p.z, seed) * jit
                ring.append(p)
            rings.append(ring)
        circ = math.tau * max(r0, r1)
        tiles = max(1, round(circ / bark))
        us = [tiles * j / sides for j in range(sides)]
        vs = [L * i / segs / bark for i in range(segs + 1)]
        self._loft_cyl(rings, mat, us, vs, tiles)
        if cap:
            try:
                f = self.bm.faces.new([self.bm.verts.new(p) for p in reversed(rings[0])])
                f.material_index = self.keys.index(mat)
                f2 = self.bm.faces.new([self.bm.verts.new(p) for p in rings[-1]])
                f2.material_index = self.keys.index(mat)
                self._box_uv([f, f2], 0.4)
            except ValueError:
                pass

    def tube_path(self, pts, radii, mat, sides=8, bark=3.0, jit=0.0, seed=0, cap_end=True, flat=None):
        """A smooth round beam along a Catmull-Rom path through `pts` (Godot points) with radii at each point."""
        pts = [Vector(p) for p in pts]
        n = len(pts)
        samp = []
        rad = []
        for i in range(n - 1):
            p0 = pts[max(i - 1, 0)]
            p1 = pts[i]
            p2 = pts[i + 1]
            p3 = pts[min(i + 2, n - 1)]
            seg = max(2, int((p2 - p1).length / 1.1))
            for k in range(seg):
                t = k / seg
                t2, t3 = t * t, t * t * t
                q = 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
                samp.append(q)
                rad.append(radii[i] + (radii[i + 1] - radii[i]) * t)
        samp.append(pts[-1])
        rad.append(radii[-1])
        rings = []
        prev_side = None
        for i, c in enumerate(samp):
            t_ = (samp[min(i + 1, len(samp) - 1)] - samp[max(i - 1, 0)]).normalized()
            ref = Vector((0, 1, 0)) if abs(t_.y) < 0.9 else Vector((1, 0, 0))
            sd = t_.cross(ref).normalized()
            if prev_side is not None and sd.dot(prev_side) < 0:
                sd = -sd
            prev_side = sd
            fw = t_.cross(sd).normalized()
            ring = []
            for j in range(sides):
                an = math.tau * j / sides
                p = c + sd * math.cos(an) * rad[i] + fw * math.sin(an) * rad[i]
                if jit > 0.0:
                    p += (p - c).normalized() * hash3(p.x, p.y, p.z, seed) * jit
                ring.append(p)
            rings.append(ring)
        circ = math.tau * max(rad)
        tiles = max(1, round(circ / bark))
        us = [tiles * j / sides for j in range(sides)]
        acc = 0.0
        vs = [0.0]
        for i in range(1, len(samp)):
            acc += (samp[i] - samp[i - 1]).length
            vs.append(acc / bark)
        self._loft_cyl(rings, mat, us, vs, tiles)
        if cap_end:
            try:
                f = self.bm.faces.new([self.bm.verts.new(p) for p in rings[-1]])
                f.material_index = self.keys.index(mat)
                self._box_uv([f], 0.4)
            except ValueError:
                pass

    def _loft_cyl(self, rings, mat, us, vs, tiles, smooth=True):
        bm = self.bm
        n = len(rings[0])
        vr = [[bm.verts.new(Vector(p)) for p in ring] for ring in rings]
        for i in range(len(rings) - 1):
            for j in range(n):
                j2 = (j + 1) % n
                try:
                    f = bm.faces.new([vr[i][j], vr[i][j2], vr[i + 1][j2], vr[i + 1][j]])
                except ValueError:
                    continue
                f.material_index = self.keys.index(mat)
                f.smooth = smooth
                u0 = us[j]
                u1 = us[j2] if j2 != 0 else float(tiles)
                f.loops[0][self.uv].uv = (u0, vs[i])
                f.loops[1][self.uv].uv = (u1, vs[i])
                f.loops[2][self.uv].uv = (u1, vs[i + 1])
                f.loops[3][self.uv].uv = (u0, vs[i + 1])

    def lathe(self, profile, mat, sides=24, bark=3.0, jit=None, cap_top=False, wobble=None):
        """A solid of revolution about the Y axis (Godot): profile is [(radius, y)] bottom to top.
        `jit(angle, y) -> radius multiplier` roughens the outline."""
        rings = []
        for (r, y) in profile:
            ring = []
            for j in range(sides):
                an = -math.tau * j / sides
                k = jit(an, y) if jit else 1.0
                ring.append(Vector((math.cos(an) * r * k, y, math.sin(an) * r * k)))
            rings.append(ring)
        circ = math.tau * max(r for r, _ in profile)
        tiles = max(1, round(circ / bark))
        us = [tiles * j / sides for j in range(sides)]
        vs = [(profile[i][1]) / bark for i in range(len(profile))]
        self._loft_cyl(rings, mat, us, vs, tiles)

    # -- finishing ------------------------------------------------------------------------------
    def finish(self, collection=None, merge=True, recalc=False):
        bm = self.bm
        if merge:
            bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
        if recalc:
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        for v in bm.verts:
            v.co = G(v.co)
        me = bpy.data.meshes.new(self.name)
        bm.to_mesh(me)
        bm.free()
        for k in self.keys:
            me.materials.append(self.mats[k])
        ob = bpy.data.objects.new(self.name, me)
        (collection or bpy.context.scene.collection).objects.link(ob)
        for p in me.polygons:
            p.use_smooth = p.use_smooth
        return ob


def tris(ob):
    me = ob.data
    me.calc_loop_triangles()
    return len(me.loop_triangles)


def export(path, objs, extra=None):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True, export_apply=True,
                              export_yup=True, export_materials='EXPORT', export_normals=True,
                              export_texcoords=True, export_tangents=False, export_image_format='AUTO',
                              export_cameras=False, export_lights=False)
    print("EXPORTED", path, os.path.getsize(path) // 1024, "KB", {o.name: tris(o) for o in objs})


def preview(path, objs, look_at=(0, 3, 0), dist=24.0, views=((35, 0.35), (160, 0.3)), res=(960, 720), lens=40):
    """Workbench stills with textures (no GPU lighting needed)."""
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_WORKBENCH'
    sc.display.shading.light = 'STUDIO'
    sc.display.shading.color_type = 'TEXTURE'
    sc.render.resolution_x, sc.render.resolution_y = res
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    cam.data.lens = lens
    cam.data.clip_end = 2000
    sc.collection.objects.link(cam)
    sc.camera = cam
    for i, (az, el) in enumerate(views):
        a = math.radians(az)
        pos = Vector((look_at[0] + math.sin(a) * dist * math.cos(el), -(look_at[2] + math.cos(a) * dist * math.cos(el)), look_at[1] + dist * math.sin(el)))
        tgt = G(look_at)
        cam.location = pos
        direction = tgt - pos
        cam.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()
        sc.render.filepath = path.replace(".png", "_%d.png" % i)
        bpy.ops.render.render(write_still=True)
        print("PREVIEW", sc.render.filepath)


def gd_lit(v, ind=0):
    """A Python literal as GDScript."""
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, float):
        return repr(round(v, 4))
    if isinstance(v, int):
        return str(v)
    if isinstance(v, str):
        return '"%s"' % v
    if isinstance(v, (list, tuple)):
        if v and all(isinstance(x, (int, float)) for x in v):
            return "[" + ", ".join(gd_lit(x) for x in v) + "]"
        return "[" + ", ".join(gd_lit(x) for x in v) + "]"
    if isinstance(v, dict):
        return "{" + ", ".join('"%s": %s' % (k, gd_lit(x)) for k, x in v.items()) + "}"
    raise TypeError(type(v))


def write_gd(path, text):
    with open(path, "w") as f:
        f.write(text)
    print("WROTE", path)
