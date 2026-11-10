"""Hearthward's five cottages (core/world/realm/lore/cottage.gd), modelled by script. Modular: one generator, five specs.

  art/models/cottages/cottage_<name>.glb       near mesh: Body (stone / daub / timber / iron, vertex colour), Roof
                                               (thatch or slate), WindowGlow (lived-in only; the game makes it emissive),
                                               and <name>-colonly (wall boxes with the door gap, roof slabs).
  art/models/cottages/cottage_<name>_far.glb   far mesh (< 400 tris): FarBody, FarRoof, FarGlow.

  tools/blender/run.sh cottage_kit.py -- [--only maud,harrow,reed,cobb,south] [--preview DIR] [--no-export]

Frame: the cottage's own frame as in cottage.gd. Origin = footprint centre at floor level, local -z (front, door) is
Godot -z. Blender is Z up and the glTF exporter maps Blender (x, y, z) -> Godot (x, z, -y), so the front (Godot -z) is
Blender +y. The footprint, eave height (2.6), ridge (eave + d/2 * 0.95), wall thickness (0.5), door (1.1 x 2.05 at 0.36 w
from the -x end), windows (0.8 x 0.9, sill 0.95) and the chimney on the +x gable are exactly the code's.

Materials (three at most): CotBody, CotRoof, CotGlow. All colour is vertex colour (stone with moss, damp and soot;
whitewashed daub; hewn timber; blackened iron; thatch or slate) so the meshes MultiMesh.
"""
import bpy
import bmesh
import math
import os
import sys
import random
from mathutils import Vector, Matrix, noise

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art", "models", "cottages")
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ONLY = args[args.index("--only") + 1].split(",") if "--only" in args else []
PREVIEW = args[args.index("--preview") + 1] if "--preview" in args else ""
NOEXPORT = "--no-export" in args

T = 0.5            # wall thickness (cottage.gd)
H = 2.6            # eave height
SLOPE = 0.95       # ridge rise per metre of half-depth
CD = 0.07          # depth of the core's outer plane behind the block ring
Z = Vector((0, 0, 1))

SPECS = {
    "maud":   dict(w=6.6, d=5.0, walls="daub",  roof="thatch", state="lived",     seed=11),
    "harrow": dict(w=6.2, d=4.8, walls="stone", roof="slate",  state="ruined",    seed=23, collapse="east"),
    "reed":   dict(w=6.4, d=5.0, walls="stone", roof="slate",  state="shuttered", seed=37),
    "cobb":   dict(w=7.0, d=5.4, walls="stone", roof="thatch", state="burned",    seed=41, collapse="east"),
    "south":  dict(w=6.0, d=4.8, walls="daub",  roof="thatch", state="shuttered", seed=53),
}

TONES = ["stone", "daub", "wood", "iron", "thatch", "slate", "char", "dark", "floor", "glow", "rubble", "inner", "deck", "sootstone"]
TID = {n: i for i, n in enumerate(TONES)}
SETOF = {"stone": "stone", "rubble": "stone", "sootstone": "stone", "daub": "daub", "inner": "daub", "wood": "timber", "char": "timber",
         "deck": "timber", "dark": "timber", "floor": "timber", "iron": "iron", "thatch": "thatch", "slate": "slate", "glow": "glow"}
TILE = {"stone": 6.0, "timber": 2.0, "iron": 2.0, "daub": 2.0, "thatch": 2.0, "slate": 1.5, "glow": 1.0}
# the set albedo's mean colour, so the vertex colour (which the game multiplies on the set) is a tone, not an albedo
REF = {"stone": (0.5, 0.47, 0.42), "daub": (0.72, 0.66, 0.54), "timber": (0.32, 0.23, 0.16), "iron": (0.2, 0.17, 0.15),
       "thatch": (0.46, 0.36, 0.2), "slate": (0.2, 0.21, 0.25), "glow": (1.0, 1.0, 1.0)}
SETS_ALL = ["stone", "daub", "timber", "iron", "thatch", "slate", "glow"]


def clamp(x, a=0.0, b=1.0):
    return max(a, min(b, x))


def smooth(a, b, x):
    t = clamp((x - a) / (b - a + 1e-9))
    return t * t * (3 - 2 * t)


def fbm(p, octaves=3):
    a, f, s, n = 1.0, 1.0, 0.0, 0.0
    for _ in range(octaves):
        s += a * noise.noise(Vector(p) * f)
        n += a
        a *= 0.5
        f *= 2.0
    return s / n


# =====================================================================================================================
# mesh container
# =====================================================================================================================
class Mesh:
    def __init__(self, seed, state, walls):
        self.bm = {}
        self.rng = random.Random(seed)
        self.seed = seed
        self.state = state
        self.walls = walls
        self.off = Vector((seed * 3.7, seed * 1.3, seed * 5.1))

    def get(self, key):
        if key not in self.bm:
            bm = bmesh.new()
            bm.faces.layers.int.new("tone")
            bm.faces.layers.float.new("tint")
            bm.verts.layers.float.new("ao")
            self.bm[key] = bm
        return self.bm[key]

    def face(self, key, pts, tone, normal=None, away=None, ao=None, tint=None):
        key = SETOF[tone]
        bm = self.get(key)
        pts = [Vector(p) for p in pts]
        # drop degenerate faces
        n = Vector((0, 0, 0))
        for i in range(1, len(pts) - 1):
            n += (pts[i] - pts[0]).cross(pts[i + 1] - pts[0])
        if n.length < 1e-7:
            return None
        n.normalize()
        flip = False
        if normal is not None:
            flip = n.dot(normal) < 0
        elif away is not None:
            c = sum(pts, Vector()) / len(pts)
            flip = n.dot(c - away) < 0
        if flip:
            pts = pts[::-1]
            if ao:
                ao = ao[::-1]
        vs = [bm.verts.new(p) for p in pts]
        try:
            f = bm.faces.new(vs)
        except ValueError:
            return None
        f[bm.faces.layers.int["tone"]] = TID[tone]
        f[bm.faces.layers.float["tint"]] = tint if tint is not None else 0.88 + 0.24 * self.rng.random()
        if ao:
            al = bm.verts.layers.float["ao"]
            for v, a in zip(vs, ao):
                v[al] = a
        return f

    def jit(self, amt):
        r = self.rng
        return Vector((r.uniform(-amt, amt), r.uniform(-amt, amt), r.uniform(-amt, amt)))

    def hexa(self, key, tone, c, skip=(), jit=0.0, ao=None):
        """c: 8 corners, bit0 = x, bit1 = y, bit2 = z of a box frame. Faces auto-orient away from the centre."""
        if jit:
            c = [p + self.jit(jit) for p in c]
        ctr = sum(c, Vector()) / 8
        F = {"-x": (0, 2, 6, 4), "+x": (1, 3, 7, 5), "-y": (0, 1, 5, 4), "+y": (2, 3, 7, 6), "-z": (0, 1, 3, 2), "+z": (4, 5, 7, 6)}
        for nm, idx in F.items():
            if nm in skip:
                continue
            self.face(key, [c[i] for i in idx], tone, away=ctr, ao=ao)

    def box(self, key, tone, centre, size, rotz=0.0, skip=(), jit=0.0, ao=None):
        sx, sy, sz = size
        M = Matrix.Rotation(rotz, 3, 'Z')
        cs = []
        for i in range(8):
            p = Vector(((sx if i & 1 else -sx) * 0.5, (sy if i & 2 else -sy) * 0.5, (sz if i & 4 else -sz) * 0.5))
            cs.append(Vector(centre) + M @ p)
        self.hexa(key, tone, cs, skip, jit, ao)

    def beam(self, key, tone, a, b, w, h, up=Z, skip=(), jit=0.0):
        a, b = Vector(a), Vector(b)
        f = (b - a).normalized()
        s = f.cross(up)
        if s.length < 1e-4:
            s = f.cross(Vector((1, 0, 0)))
        s.normalize()
        u = s.cross(f).normalized()
        cs = []
        for i in range(8):
            base = b if i & 1 else a
            cs.append(base + s * (w * 0.5 if i & 2 else -w * 0.5) + u * (h * 0.5 if i & 4 else -h * 0.5))
        self.hexa(key, tone, cs, skip, jit)

    def rock(self, key, tone, centre, r, squash=0.6, seed=None):
        bm = bmesh.new()
        bmesh.ops.create_icosphere(bm, subdivisions=1, radius=1.0)
        rot = Matrix.Rotation(self.rng.random() * 6.28, 3, 'Z')
        pts = []
        for v in bm.verts:
            q = v.co.copy()
            q = Vector((q.x * (0.8 + 0.5 * self.rng.random()), q.y * (0.8 + 0.5 * self.rng.random()), q.z * squash * (0.7 + 0.5 * self.rng.random())))
            v.co = Vector(centre) + rot @ (q * r)
        for f in bm.faces:
            ps = [v.co.copy() for v in f.verts]
            if all(p.z < Vector(centre).z - r * squash * 0.5 for p in ps):
                continue
            self.face(key, ps, tone, away=Vector(centre))
        bm.free()


# =====================================================================================================================
# colour
# =====================================================================================================================
def tone_albedo(M, name, co, nrm, ao, tint):
    p = co + M.off
    burned = M.state == "burned"
    low = 1.0 - smooth(0.0, 1.4, co.z)
    up = clamp(nrm.z)
    if name in ("stone", "rubble", "sootstone"):
        n1 = fbm(p * 0.9, 3)
        base = Vector((0.47, 0.44, 0.39)) * (0.88 + 0.4 * n1)
        warm = fbm(p * 0.25 + Vector((5, 1, 2)), 2)
        base += Vector((0.05, 0.02, -0.03)) * warm
        moss = smooth(0.0, 0.45, fbm(p * 1.4 + Vector((7, 3, 1)), 3)) * (0.35 + 0.65 * low) * (0.4 + 0.6 * up)
        moss *= 0.8 if M.state != "burned" else 0.1
        damp = 1.0 - 0.28 * low
        c = base * damp
        c = c.lerp(Vector((0.16, 0.22, 0.085)), 0.75 * moss)
        # soot: a stain above the chimney side and over lit windows, everything when burned
        if burned or name == "sootstone":
            c = (c + Vector((0.05, 0.02, 0.0))) * (0.62 + 0.5 * smooth(-0.25, 0.5, fbm(p * 0.7, 2)) * (0.55 + 0.45 * (1.0 - smooth(0.3, 2.6, co.z))))
        else:
            soot = smooth(3.6, 6.0, co.z) * smooth(M.chim_x - 1.0, M.chim_x, co.x) * 0.4 if hasattr(M, "chim_x") else 0.0
            c *= 1.0 - soot
        c *= tint
    elif name == "daub":
        n1 = fbm(p * 1.3, 3)
        base = Vector((0.66, 0.60, 0.48)) * (0.9 + 0.2 * n1)
        streak = smooth(0.0, 0.7, fbm(Vector((p.x * 3.5, p.y * 3.5, p.z * 0.3)), 2)) * 0.22
        c = base * (1.0 - streak)
        c = c.lerp(Vector((0.30, 0.31, 0.2)), 0.45 * smooth(0.0, 0.6, fbm(p * 1.2 + Vector((3, 3, 3)), 2)) * low)
        c *= tint * (0.9 if M.state == "shuttered" else 1.0)
    elif name == "inner":
        c = Vector((0.28, 0.23, 0.18)) * (0.8 + 0.4 * fbm(p * 1.2, 2))
        if burned:
            c *= 0.3
    elif name == "wood":
        g = 0.5 + 0.5 * fbm(Vector((p.x * 2.5, p.y * 2.5, p.z * 12.0)), 3)
        c = Vector((0.27, 0.185, 0.115)) * (0.7 + 0.5 * g) * tint
        c = c.lerp(Vector((0.12, 0.17, 0.08)), 0.35 * smooth(0.1, 0.5, fbm(p * 1.5, 2)) * low)
        if burned:
            c = Vector((0.045, 0.04, 0.036)) * (0.7 + 0.6 * g)
    elif name == "char":
        c = Vector((0.04, 0.035, 0.03)) * (0.6 + 0.8 * fbm(p * 3.0, 2)) * tint
    elif name == "iron":
        r = smooth(0.1, 0.7, fbm(p * 2.0, 3) + 0.15)
        c = Vector((0.11, 0.105, 0.115)).lerp(Vector((0.32, 0.16, 0.07)), r * 0.7) * tint
    elif name == "thatch":
        streak = fbm(Vector((p.x * 7.0, p.y * 1.5, p.z * 1.5)), 3)
        c = Vector((0.5, 0.385, 0.2)) * (0.8 + 0.4 * streak) * tint
        age = smooth(0.05, 0.6, fbm(p * 0.6 + Vector((2, 8, 1)), 2))
        c = c.lerp(Vector((0.3, 0.27, 0.17)), 0.5 * age)
        mo = smooth(0.1, 0.6, fbm(p * 1.1 + Vector((9, 1, 4)), 3)) * (1.0 - smooth(2.0, 4.4, co.z) * 0.4)
        c = c.lerp(Vector((0.17, 0.23, 0.08)), 0.5 * mo)
    elif name == "slate":
        n1 = fbm(p * 2.0, 3)
        c = Vector((0.19, 0.205, 0.25)) * (0.8 + 0.5 * n1) * tint
        li = smooth(0.15, 0.6, fbm(p * 1.4 + Vector((4, 4, 4)), 3))
        c = c.lerp(Vector((0.2, 0.27, 0.11)), 0.45 * li)
    elif name == "deck":
        c = Vector((0.05, 0.04, 0.035))
    elif name == "floor":
        c = Vector((0.17, 0.14, 0.11)) * (0.7 + 0.5 * fbm(p * 2, 2))
        if burned:
            c *= 0.3
    elif name == "glow":
        return (1.0, 0.58, 0.22)
    else:
        c = Vector((0.04, 0.035, 0.035))
    if ao and ao > 0.0:
        c *= ao
    return (clamp(c.x), clamp(c.y), clamp(c.z))


def tone_color(M, name, co, nrm, ao, tint):
    c = tone_albedo(M, name, co, nrm, ao, tint)
    if name == "glow":
        return c
    ref = REF[SETOF[name]]
    return tuple(min(1.0, c[i] / ref[i] * 0.92) for i in range(3))


SLOPE_N = math.sqrt(1 + SLOPE * SLOPE)


def finish(M, prefix, names, smooth_tones=("thatch", "daub"), rz=0.0):
    """One object per set, named `<prefix>__<set>` (glow: names['glow']); box UVs in metres (timber grain along each
    board's longest edge, roof sets laid down the slope); vertex colour = tone multiplier. Returns {set: obj}."""
    out = {}
    for key, bm in M.bm.items():
        bm.normal_update()
        tl = bm.faces.layers.int["tone"]
        tn = bm.faces.layers.float["tint"]
        al = bm.verts.layers.float["ao"]
        uv = bm.loops.layers.uv.new("UVMap")
        col = bm.loops.layers.color.new("Col")
        tile = TILE[key]
        for f in bm.faces:
            name = TONES[f[tl]]
            f.smooth = name in smooth_tones
            nrm = f.normal
            ax = max(range(3), key=lambda i: abs(nrm[i]))
            grain = None
            if key == "timber":
                le = max(f.edges, key=lambda e: e.calc_length())
                d = (le.verts[1].co - le.verts[0].co).normalized()
                t1 = nrm.cross(d)
                if t1.length > 1e-6:
                    grain = (t1.normalized(), d)
            slope_face = key in ("thatch", "slate") and abs(nrm.y) > 0.3 and nrm.z > 0.2
            for l in f.loops:
                co = l.vert.co
                if slope_face:
                    ds = (abs(co.y) + (rz - co.z) * SLOPE) / SLOPE_N
                    l[uv].uv = (co.x / tile, ds / tile)
                elif grain is not None:
                    l[uv].uv = (co.dot(grain[0]) / tile, co.dot(grain[1]) / tile)
                elif ax == 0:
                    l[uv].uv = (co.y / tile, co.z / tile)
                elif ax == 1:
                    l[uv].uv = (co.x / tile, co.z / tile)
                else:
                    l[uv].uv = (co.x / tile, co.y / tile)
                n = l.vert.normal if f.smooth else nrm
                c = tone_color(M, name, co, n, l.vert[al], f[tn])
                l[col] = (c[0], c[1], c[2], 1.0)
        nm = names["glow"] if key == "glow" else "%s__%s" % (prefix, key)
        me = bpy.data.meshes.new(nm)
        bm.to_mesh(me)
        bm.free()
        me.color_attributes.active_color = me.color_attributes["Col"]
        me.color_attributes.render_color_index = me.color_attributes.find("Col")
        me.materials.append(plain_mat(key))
        ob = bpy.data.objects.new(nm, me)
        bpy.context.scene.collection.objects.link(ob)
        out[key] = ob
    return out


def plain_mat(key):
    m = bpy.data.materials.get(key)
    if m:
        return m
    m = bpy.data.materials.new(key)
    m.use_nodes = True
    return m


def texture_mats():
    """Preview only: each set's material built from the game's r37_<set> PBR PNGs (albedo x vertex tone, normal, ORM)."""
    tex = os.path.join(ROOT, "art", "textures")
    for key in SETS_ALL:
        m = plain_mat(key)
        nt = m.node_tree
        for n in list(nt.nodes):
            if n.type != 'OUTPUT_MATERIAL':
                nt.nodes.remove(n)
        out = [n for n in nt.nodes if n.type == 'OUTPUT_MATERIAL'][0]
        bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
        nt.links.new(bsdf.outputs[0], out.inputs[0])
        vc = nt.nodes.new("ShaderNodeVertexColor")
        vc.layer_name = "Col"
        if key == "glow":
            nt.links.new(vc.outputs[0], bsdf.inputs["Base Color"])
            nt.links.new(vc.outputs[0], bsdf.inputs["Emission Color"])
            bsdf.inputs["Emission Strength"].default_value = 3.0
            continue

        def img(suffix, cs):
            n = nt.nodes.new("ShaderNodeTexImage")
            im = bpy.data.images.load(os.path.join(tex, "r37_%s_%s.png" % (key, suffix)), check_existing=True)
            im.colorspace_settings.name = cs
            n.image = im
            return n
        a, nm, orm = img("albedo", "sRGB"), img("normal", "Non-Color"), img("orm", "Non-Color")
        mul = nt.nodes.new("ShaderNodeMix")
        mul.data_type = 'RGBA'
        mul.blend_type = 'MULTIPLY'
        mul.inputs[0].default_value = 1.0
        nt.links.new(a.outputs[0], mul.inputs[6])
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
        nmn = nt.nodes.new("ShaderNodeNormalMap")
        nt.links.new(nm.outputs[0], nmn.inputs[1])
        nt.links.new(nmn.outputs[0], bsdf.inputs["Normal"])


# =====================================================================================================================
# wall frame
# =====================================================================================================================
class Wall:
    """P(u, v, d): u along the wall, v up, d inward from the outer face (negative = outward)."""

    def __init__(self, O, du, n, L, name):
        self.O, self.du, self.n, self.L, self.name = Vector(O), Vector(du), Vector(n), L, name
        self.ops = []

    def P(self, u, v, d=0.0):
        return self.O + self.du * u + Z * v - self.n * d

    def inner(self):
        w = Wall(self.O - self.n * T, self.du, -self.n, self.L, self.name + "_in")
        w.ops = self.ops
        return w


def op(at, w, sill, top, door=False):
    return dict(u0=at - w * 0.5, u1=at + w * 0.5, v0=sill, v1=top, at=at, w=w, door=door)


def wbox(M, key, tone, W, u0, u1, v0, v1, d0, d1, jit=0.0, skip=(), ao=None):
    cs = []
    for i in range(8):
        u = u1 if i & 1 else u0
        d = d1 if i & 2 else d0
        v = v1 if i & 4 else v0
        cs.append(W.P(u, v, d))
    M.hexa(key, tone, cs, skip, jit, ao)


def wbeam(M, key, tone, W, ua, va, ub, vb, d, w, h):
    """Diagonal beam in the wall plane from (ua,va) to (ub,vb) at depth d; w across the plane, h out of it."""
    a, b = W.P(ua, va, d), W.P(ub, vb, d)
    M.beam(key, tone, a, b, w, h, up=W.n)


def leaf(M, key, tone, W, hu, v0, v1, d, length, thick, ang, jit=0.0):
    """A shutter / door leaf hinged on the vertical line at wall position (hu, d); angle 0 lies along +du, positive
    swings it outward."""
    a = W.du * math.cos(ang) + W.n * math.sin(ang)
    t = a.cross(Z).normalized() * thick
    base = W.P(hu, v0, d)
    cs = []
    for i in range(8):
        cs.append(base + a * (length if i & 1 else 0.0) + t * (0.5 if i & 2 else -0.5) + Z * ((v1 - v0) if i & 4 else 0.0))
    M.hexa(key, tone, cs, (), jit)


# ---------------------------------------------------------------------------------------------------------------------
def course_bounds(rng, v0, v1, ch):
    n = max(1, round((v1 - v0) / ch))
    hs = [ch * (0.82 + 0.36 * rng.random()) for _ in range(n)]
    s = sum(hs)
    hs = [h * (v1 - v0) / s for h in hs]
    b = [v0]
    for h in hs:
        b.append(b[-1] + h)
    return b


def free_spans(L, forb):
    forb = sorted(forb)
    out, cur = [], 0.0
    for a, b in forb:
        if a > cur + 1e-4:
            out.append((cur, min(a, L)))
        cur = max(cur, b)
    if cur < L - 1e-4:
        out.append((cur, L))
    return out


def blocks(M, W, bounds, topf, prot, bwr, tone="stone", miss=0.0, ops=None, ring_ao=0.5, rounding=0.035, inside=False, clip=False):
    """Coursed stone blocks on a wall face: each a chamfered pillow (ring at the plane, face proud by `prot`)."""
    rng = M.rng
    ops = W.ops if ops is None else ops
    L = W.L
    nrm = W.n
    for r in range(len(bounds) - 1):
        va, vb = bounds[r], bounds[r + 1]
        forb = [(o["u0"], o["u1"]) for o in ops if o["v0"] < vb - 1e-4 and o["v1"] > va + 1e-4]
        for a, b in free_spans(L, forb):
            cur = a
            first = True
            while cur < b - 0.05:
                if first and r % 2 == 1:
                    wd = rng.uniform(0.25, 0.5)
                else:
                    wd = rng.uniform(*bwr)
                first = False
                if b - (cur + wd) < 0.3:
                    wd = b - cur
                ua, ub = cur, cur + wd
                cur = ub
                if wd < 0.06:
                    continue
                vbA = vbB = vb
                if topf is not None:
                    if clip:
                        vbA, vbB = min(vb, topf(ua)), min(vb, topf(ub))
                        if min(vbA, vbB) < va + 0.14:
                            continue
                    elif vb > min(topf(ua), topf(ub), topf((ua + ub) * 0.5)) + 0.01:
                        continue
                if miss and rng.random() < miss:
                    continue
                pr = prot * rng.uniform(0.5, 1.4)
                g = min(rounding, wd * 0.2, (vb - va) * 0.2)
                jt = lambda: rng.uniform(-0.012, 0.012)
                ring = [W.P(ua, va, 0), W.P(ub, va, 0), W.P(ub, vbB, 0), W.P(ua, vbA, 0)]
                inn = [W.P(ua + g, va + g, -pr) + Vector((jt(), jt(), jt())), W.P(ub - g, va + g, -pr) + Vector((jt(), jt(), jt())),
                       W.P(ub - g, vbB - g, -pr) + Vector((jt(), jt(), jt())), W.P(ua + g, vbA - g, -pr) + Vector((jt(), jt(), jt()))]
                tint = 0.82 + 0.34 * rng.random()
                for i in range(4):
                    j = (i + 1) % 4
                    M.face("body", [ring[i], ring[j], inn[j], inn[i]], tone, normal=nrm, ao=[ring_ao, ring_ao, 1.0, 1.0], tint=tint)
                M.face("body", inn, tone, normal=nrm, tint=tint)


def pieces(L, ops, topf, ruin_cols=False):
    """Core pieces (u0, u1, v0, v1a, v1b) of the wall with openings cut out."""
    br = {0.0, L}
    for o in ops:
        br.add(o["u0"]); br.add(o["u1"])
    br.add(L * 0.5)
    if ruin_cols:
        x = 0.0
        while x < L:
            br.add(x)
            x += 0.5
    br = sorted(br)
    out = []
    for a, b in zip(br[:-1], br[1:]):
        if b - a < 1e-3:
            continue
        ta, tb = (topf((a + b) * 0.5),) * 2 if ruin_cols else (topf(a), topf(b))
        cov = [o for o in ops if o["u0"] <= a + 1e-4 and o["u1"] >= b - 1e-4]
        if not cov:
            out.append((a, b, 0.0, ta, tb))
        else:
            o = cov[0]
            if o["v0"] > 0.01:
                out.append((a, b, 0.0, min(o["v0"], ta), min(o["v0"], tb)))
            if min(ta, tb) > o["v1"] + 0.02:
                out.append((a, b, o["v1"], ta, tb))
    return out


def core(M, W, topf, ruin_cols, outer_tone, inner_tone, sides=False):
    for (a, b, v0, va, vb) in pieces(W.L, W.ops, topf, ruin_cols):
        M.face("body", [W.P(a, v0, CD), W.P(b, v0, CD), W.P(b, vb, CD), W.P(a, va, CD)], outer_tone, normal=W.n, ao=[0.45] * 4, tint=0.8)
        M.face("body", [W.P(a, v0, T), W.P(b, v0, T), W.P(b, vb, T), W.P(a, va, T)], inner_tone, normal=-W.n)
        M.face("body", [W.P(a, va, CD), W.P(b, vb, CD), W.P(b, vb, T), W.P(a, va, T)], outer_tone, normal=Z, tint=0.9)
        if sides and (ruin_cols):
            M.face("body", [W.P(a, v0, CD), W.P(a, va, CD), W.P(a, va, T), W.P(a, v0, T)], outer_tone, normal=-W.du)
            M.face("body", [W.P(b, v0, CD), W.P(b, vb, CD), W.P(b, vb, T), W.P(b, v0, T)], outer_tone, normal=W.du)
    # reveals
    for o in W.ops:
        d0 = 0.0
        M.face("body", [W.P(o["u0"], o["v0"], d0), W.P(o["u0"], o["v1"], d0), W.P(o["u0"], o["v1"], T), W.P(o["u0"], o["v0"], T)], outer_tone, normal=W.du, ao=[0.6, 0.6, 0.45, 0.45])
        M.face("body", [W.P(o["u1"], o["v0"], d0), W.P(o["u1"], o["v1"], d0), W.P(o["u1"], o["v1"], T), W.P(o["u1"], o["v0"], T)], outer_tone, normal=-W.du, ao=[0.6, 0.6, 0.45, 0.45])
        M.face("body", [W.P(o["u0"], o["v1"], d0), W.P(o["u1"], o["v1"], d0), W.P(o["u1"], o["v1"], T), W.P(o["u0"], o["v1"], T)], outer_tone, normal=-Z, ao=[0.6, 0.6, 0.4, 0.4])
        if o["v0"] > 0.01:
            M.face("body", [W.P(o["u0"], o["v0"], d0), W.P(o["u1"], o["v0"], d0), W.P(o["u1"], o["v0"], T), W.P(o["u0"], o["v0"], T)], outer_tone, normal=Z, ao=[0.8, 0.8, 0.5, 0.5])


# =====================================================================================================================
# openings: doors, windows, shutters
# =====================================================================================================================
def door_fit(M, W, o, st, wall_h):
    rng = M.rng
    at, w = o["at"], o["w"]
    burned = st == "burned"
    wood = "char" if burned else "wood"
    # jamb posts and a heavy lintel
    for sg in (-1, 1):
        uc = at + sg * (w * 0.5 + 0.07)
        wbox(M, "body", wood, W, uc - 0.08, uc + 0.08, 0.0, o["v1"] + 0.05, -0.07, 0.12, jit=0.01)
    wbox(M, "body", wood, W, at - w * 0.5 - 0.32, at + w * 0.5 + 0.32, o["v1"] + 0.04, o["v1"] + 0.3, -0.1, 0.2, jit=0.015)
    # threshold + step
    wbox(M, "body", "stone", W, at - w * 0.5 - 0.1, at + w * 0.5 + 0.1, 0.0, 0.07, -0.55, 0.4, jit=0.015, ao=None)
    for i in range(6):          # the doorstep and five steps down (the village ground falls away from the floor)
        top = 0.06 - 0.24 * i
        wbox(M, "body", "stone", W, at - 0.75 + 0.04 * i, at + 0.75 - 0.04 * i, -1.6, top, -0.4 - 0.45 * (i + 1), -0.4 - 0.45 * i, jit=0.015, skip=("+y", "-z"))
    if st in ("lived", "shuttered"):
        # plank door in the reveal, iron straps and hinges, a latch
        pw = (w - 0.02) / 5.0
        dd0, dd1 = 0.14, 0.23
        for i in range(5):
            u0 = at - w * 0.5 + 0.01 + i * pw
            wbox(M, "body", "wood", W, u0 + 0.004, u0 + pw - 0.004, 0.0, o["v1"] - 0.02 - rng.uniform(0, 0.03), dd0 + rng.uniform(-0.01, 0.01), dd1, jit=0.004)
        for vy in (0.42, 1.6):
            wbox(M, "body", "iron", W, at - w * 0.5 - 0.02, at + w * 0.28, vy - 0.045, vy + 0.045, dd0 - 0.03, dd0, jit=0.003)
            for sgn in (-1, 1):
                pass
            wbox(M, "body", "iron", W, at - w * 0.5 - 0.04, at - w * 0.5 + 0.05, vy - 0.07, vy + 0.07, dd0 - 0.06, dd0 - 0.01)   # pintle eye
            tip = at + w * 0.28
            wbeam(M, "body", "iron", W, tip, vy, tip + 0.1, vy, dd0 - 0.035, 0.1, 0.012)
        wbox(M, "body", "iron", W, at + w * 0.3 - 0.02, at + w * 0.3 + 0.18, 1.0 - 0.02, 1.0 + 0.02, dd0 - 0.04, dd0 - 0.005)     # latch bar
        wbox(M, "body", "iron", W, at + w * 0.3 + 0.12, at + w * 0.3 + 0.16, 0.95, 1.07, dd0 - 0.05, dd0 - 0.01)
        if st == "shuttered":
            # barred across with a beam on iron brackets
            wbox(M, "body", "wood", W, at - w * 0.5 - 0.35, at + w * 0.5 + 0.35, 1.18, 1.34, -0.14, -0.04, jit=0.015)
            for sg in (-1, 1):
                wbox(M, "body", "iron", W, at + sg * (w * 0.5 + 0.12) - 0.04, at + sg * (w * 0.5 + 0.12) + 0.04, 1.1, 1.42, -0.2, -0.02)
    elif st == "ruined":
        # the door hangs from one hinge, open
        leaf(M, "body", "wood", W, at - w * 0.5 + 0.02, 0.05, o["v1"] - 0.3, -0.04, w - 0.06, 0.08, 1.2 + 0.1 * rng.random(), jit=0.01)
        wbox(M, "body", "iron", W, at - w * 0.5 - 0.02, at - w * 0.5 + 0.08, 1.55, 1.62, -0.1, 0.0)
    else:
        # burned: the door is gone, a charred plank leans on the jamb
        leaf(M, "body", "char", W, at + w * 0.5 - 0.02, 0.05, 1.5, -0.3, 0.35, 0.07, 2.6, jit=0.01)


def shutter(M, W, o, side, mode, wood, ang=0.0):
    """One shutter leaf of window `o`: mode 'closed' covers half the opening; 'open' lies back against the wall."""
    rng = M.rng
    w, at = o["w"], o["at"]
    hh = o["v1"] - o["v0"]
    lw = w * 0.5 + 0.02
    if mode == "closed":
        hu = at + side * (w * 0.5 + 0.005)       # hinge on the jamb
        # leaf runs toward the centre: angle 0 along +du for the left hinge, along -du for the right
        a = 0.0
        L = lw
        u0 = at - w * 0.5 - 0.03 if side < 0 else at + 0.0
        # two planks and two cleats
        for i in range(2):
            pu0 = u0 + i * (L * 0.5)
            wbox(M, "body", wood, W, pu0 + 0.005, pu0 + L * 0.5 - 0.005, o["v0"] - 0.02, o["v1"] + 0.02, -0.075 + rng.uniform(-0.005, 0.005), -0.01, jit=0.004)
        for vy in (o["v0"] + 0.14, o["v1"] - 0.14):
            wbox(M, "body", wood, W, u0 + 0.02, u0 + L - 0.02, vy - 0.04, vy + 0.04, -0.115, -0.07, jit=0.004)
        # strap + hinge pin on the outer edge
        edge = u0 + (0.04 if side < 0 else L - 0.04)
        wbox(M, "body", "iron", W, edge - 0.025, edge + 0.025, o["v0"] + 0.05, o["v1"] - 0.05, -0.13, -0.075)
        wbox(M, "body", "iron", W, (u0 if side < 0 else u0 + L * 0.4), (u0 + L * 0.6 if side < 0 else u0 + L), o["v0"] + 0.1 - 0.025, o["v0"] + 0.1 + 0.025, -0.13, -0.075)
    else:
        # swung back flat against the wall beside the window
        hu = at + side * (w * 0.5 + 0.04)
        ang_ = (math.pi - 0.12 + ang) if side < 0 else (0.12 + ang)
        # a leaf along -du for the left hinge: rotate by pi about the hinge, tilted off the wall a touch
        if side < 0:
            leaf(M, "body", wood, W, hu, o["v0"], o["v1"], -0.13, lw, 0.05, math.pi - 0.1 + ang, jit=0.006)
        else:
            leaf(M, "body", wood, W, hu, o["v0"], o["v1"], -0.13, lw, 0.05, 0.1 + ang, jit=0.006)
        for vy in (o["v0"] + 0.14, o["v1"] - 0.14):
            leaf(M, "body", "wood", W, hu, vy - 0.04, vy + 0.04, -0.17, lw - 0.04, 0.04, (math.pi - 0.1 + ang) if side < 0 else (0.1 + ang))


def window_fit(M, W, o, st, wall_stone):
    rng = M.rng
    at, w = o["at"], o["w"]
    burned = st == "burned"
    wood = "char" if burned else "wood"
    hh = o["v1"] - o["v0"]
    if wall_stone:
        wbox(M, "body", wood, W, at - w * 0.5 - 0.22, at + w * 0.5 + 0.22, o["v1"], o["v1"] + 0.2, -0.08, 0.3, jit=0.012)
    else:
        # the daub frame's posts/rails already surround it: add a stout sill board
        pass
    wbox(M, "body", "stone" if wall_stone or True else wood, W, at - w * 0.5 - 0.12, at + w * 0.5 + 0.12, o["v0"] - 0.1, o["v0"] + 0.02, -0.14, 0.32, jit=0.012)
    if st == "lived":
        # leaded panes: iron cross-bars in front of four glow panes set into the reveal
        d = 0.2
        for sx in (-0.5, 0.5):
            for sy in (-0.5, 0.5):
                cu = at + sx * (w * 0.25) * 1.0
                cv = (o["v0"] + o["v1"]) * 0.5 + sy * (hh * 0.25) * 1.0
                hu, hv = w * 0.5 * 0.5 * 0.92, hh * 0.5 * 0.5 * 0.92
                M.face("glow", [W.P(cu - hu, cv - hv, d), W.P(cu + hu, cv - hv, d), W.P(cu + hu, cv + hv, d), W.P(cu - hu, cv + hv, d)], "glow", normal=W.n)
        wbox(M, "body", "iron", W, at - 0.02, at + 0.02, o["v0"], o["v1"], 0.14, 0.18)
        wbox(M, "body", "iron", W, at - w * 0.5, at + w * 0.5, (o["v0"] + o["v1"]) * 0.5 - 0.02, (o["v0"] + o["v1"]) * 0.5 + 0.02, 0.14, 0.18)
        wbox(M, "body", wood, W, at - w * 0.5, at + w * 0.5, o["v0"], o["v0"] + 0.05, 0.1, 0.2)
        wbox(M, "body", wood, W, at - w * 0.5, at + w * 0.5, o["v1"] - 0.05, o["v1"], 0.1, 0.2)
        for sg in (-1, 1):
            wbox(M, "body", wood, W, at + sg * w * 0.5 - 0.03 - (0.02 if sg < 0 else -0.02), at + sg * w * 0.5 + 0.03 - (0.02 if sg < 0 else -0.02), o["v0"], o["v1"], 0.1, 0.2)
        shutter(M, W, o, -1, "open", wood)
        shutter(M, W, o, 1, "open", wood, ang=0.55)
    elif st == "shuttered":
        shutter(M, W, o, -1, "closed", wood)
        shutter(M, W, o, 1, "closed", wood)
    else:
        # ruined / burned: bare frame, a broken leaf hanging
        if o.get("keep_head", True):
            for sg in (-1, 1):
                wbox(M, "body", wood, W, at + sg * (w * 0.5 - 0.05) - 0.03, at + sg * (w * 0.5 - 0.05) + 0.03, o["v0"], o["v1"] - 0.02, 0.12, 0.22, jit=0.006)
        if st == "ruined" and rng.random() < 0.8:
            leaf(M, "body", wood, W, at - w * 0.5 - 0.04, o["v0"] + 0.1, o["v1"] - 0.1, -0.12, w * 0.5 - 0.1, 0.05, 0.9, jit=0.01)


# =====================================================================================================================
# daub framing
# =====================================================================================================================
def daub_wall(M, W, topf_h, st):
    rng = M.rng
    L = W.L
    burned = st == "burned"
    wood = "wood"
    pl = 0.5                                   # plinth top
    posts = [0.1, L - 0.1]
    for o in W.ops:
        posts += [o["u0"] - 0.08, o["u1"] + 0.08]
    posts = sorted(set(round(p, 4) for p in posts))
    # an extra post in long blind panels
    ext = []
    for a, b in zip(posts[:-1], posts[1:]):
        if any(o["u0"] - 0.08 <= a + 1e-3 and o["u1"] + 0.08 >= b - 1e-3 for o in W.ops):
            continue
        if b - a > 2.1:
            ext.append((a + b) * 0.5)
    posts = sorted(posts + ext)
    ptop = topf_h - 0.1
    # head plate and sole rail run the whole length
    wbox(M, "body", wood, W, 0.0, L, topf_h - 0.15, topf_h + 0.02, -0.1, 0.25, jit=0.012)
    wbox(M, "body", wood, W, 0.0, L, pl - 0.02, pl + 0.13, -0.075, 0.3, jit=0.01)
    for p in posts:
        wbox(M, "body", wood, W, p - 0.07, p + 0.07, pl, ptop, -0.085, 0.3, jit=0.01)
    for a, b in zip(posts[:-1], posts[1:]):
        ua, ub = a + 0.07, b - 0.07
        cov = [o for o in W.ops if o["u0"] - 0.08 <= a + 1e-3 and o["u1"] + 0.08 >= b - 1e-3]
        if cov:
            o = cov[0]
            segs = []
            if o["v0"] > pl + 0.2:
                segs.append((pl + 0.13, o["v0"] - 0.05))
                wbox(M, "body", wood, W, ua, ub, o["v0"] - 0.05, o["v0"] + 0.02, -0.085, 0.3, jit=0.008)
            segs.append((o["v1"] + 0.05, ptop - 0.08))
            wbox(M, "body", wood, W, ua, ub, o["v1"], o["v1"] + 0.07, -0.085, 0.3, jit=0.008)
        else:
            mid = 1.45 + rng.uniform(-0.05, 0.05)
            wbox(M, "body", wood, W, ua, ub, mid - 0.05, mid + 0.06, -0.075, 0.3, jit=0.008)
            segs = [(pl + 0.13, mid - 0.05), (mid + 0.06, ptop - 0.08)]
            # one diagonal brace across the lower panel, another across the upper in alternate panels
            if ub - ua > 0.6:
                flip = rng.random() < 0.5
                lo, hi = (pl + 0.15, mid - 0.06)
                if flip:
                    wbeam(M, "body", wood, W, ua + 0.02, lo, ub - 0.02, hi, -0.06, 0.12, 0.07)
                else:
                    wbeam(M, "body", wood, W, ua + 0.02, hi, ub - 0.02, lo, -0.06, 0.12, 0.07)
        for (v0, v1) in segs:
            if v1 - v0 < 0.08:
                continue
            panel(M, W, ua, ub, v0, v1)


def panel(M, W, u0, u1, v0, v1):
    """Wattle-and-daub panel: recessed at the timbers, bellied and lumpy in the middle, a 3x3 grid of quads."""
    rng = M.rng
    n = 3
    us = [u0 + (u1 - u0) * i / n for i in range(n + 1)]
    vs = [v0 + (v1 - v0) * j / n for j in range(n + 1)]
    belly = -0.03 - 0.02 * rng.random()
    dm = []
    for i in range(n + 1):
        row = []
        for j in range(n + 1):
            edge = i in (0, n) or j in (0, n)
            row.append(0.035 if edge else belly + rng.uniform(-0.012, 0.012))
        dm.append(row)
    for i in range(n):
        for j in range(n):
            q = [W.P(us[i], vs[j], dm[i][j]), W.P(us[i + 1], vs[j], dm[i + 1][j]), W.P(us[i + 1], vs[j + 1], dm[i + 1][j + 1]), W.P(us[i], vs[j + 1], dm[i][j + 1])]
            M.face("body", q, "daub", normal=W.n, tint=0.95 + 0.1 * rng.random())


def daub_gable(M, W, st):
    """Timbered gable above the eave: tie beam, king post, two braces, a bellied daub triangle."""
    rng = M.rng
    L = W.L
    ap = H + SLOPE * L * 0.5
    wood = "wood"
    wbox(M, "body", wood, W, 0.0, L, H - 0.05, H + 0.1, -0.09, 0.25, jit=0.01)
    wbox(M, "body", wood, W, L * 0.5 - 0.08, L * 0.5 + 0.08, H, ap - 0.1, -0.09, 0.3, jit=0.01)
    for sg in (-1, 1):
        ua = L * 0.5 + sg * (L * 0.5 - 0.15)
        ub = L * 0.5 + sg * 0.1
        wbeam(M, "body", wood, W, ua, H + 0.12, ub, H + 0.62 * (ap - H), -0.075, 0.13, 0.08)
        # rafter-line barge (a diagonal following the slope) as a frame member
        wbeam(M, "body", wood, W, L * 0.5 + sg * (L * 0.5 - 0.02), H + 0.03 + 0.02, L * 0.5, ap - 0.02, -0.1, 0.13, 0.12)
    # daub triangle with a belly
    a, b, c = W.P(0.1, H + 0.1, 0.02), W.P(L - 0.1, H + 0.1, 0.02), W.P(L * 0.5, ap - 0.1, 0.02)
    m = (a + b + c) / 3 - W.n * 0.035
    for p, q in ((a, b), (b, c), (c, a)):
        M.face("body", [p, q, m], "daub", normal=W.n)
    # inner triangle of the gable (roof space), a dark deck
    M.face("body", [W.P(0, H, T), W.P(L, H, T), W.P(L * 0.5, ap, T)], "inner", normal=-W.n)
    M.face("body", [W.P(0, H, CD), W.P(L, H, CD), W.P(L * 0.5, ap, CD)], "daub", normal=W.n, ao=[0.5] * 3)


# =====================================================================================================================
# roofs
# =====================================================================================================================
def slope_frame(hd, ov, side):
    """Rafter-plane geometry for the +y (side=1) or -y (side=-1) slope: (ridge point, unit down-slope d, normal N, length)."""
    ap = H + SLOPE * hd
    y1, z1 = side * (hd + ov), ap - SLOPE * (hd + ov)
    d = Vector((0, y1, z1 - ap))
    ln = d.length
    d /= ln
    N = Vector((0, side * SLOPE, 1.0)).normalized()
    return Vector((0, 0, ap)), d, N, ln


def thatch_roof(M, w, d, st):
    rng = M.rng
    hd = d * 0.5
    ov = 0.45
    ext = 0.38
    L = w + 2 * ext
    nx = max(8, round(L / 0.2))
    prof = [(0.0, 0.2), (0.3, 0.25), (0.58, 0.28), (0.6, 0.34), (0.84, 0.37), (0.86, 0.43), (1.0, 0.46)]
    for side in (1, -1):
        R, dv, N, ln = slope_frame(hd, ov, side)
        top = []
        under = []
        for j, (s, th) in enumerate(prof):
            row, urow = [], []
            for i in range(nx + 1):
                x = -L * 0.5 + L * i / nx
                bund = rng.uniform(-0.035, 0.035) * (1.0 if 0 < j else 0.0)
                bundle_n = 0.025 * fbm(Vector((x * 1.6, side * 3.0, s * 4.0)) + M.off, 2)
                edge = 1.0 - 0.0
                t = th + bund + bundle_n
                if i in (0, nx):
                    t -= 0.04
                p = R + Vector((x, 0, 0)) + dv * (s * ln) + N * t
                if j == len(prof) - 1:
                    # a ragged, shaggy eave edge
                    p += dv * rng.uniform(-0.06, 0.04)
                row.append(p)
                u = R + Vector((x, 0, 0)) + dv * (s * ln)
                urow.append(u)
            top.append(row)
            under.append(urow)
        for j in range(len(prof) - 1):
            for i in range(nx):
                M.face("roof", [top[j][i], top[j][i + 1], top[j + 1][i + 1], top[j + 1][i]], "thatch", normal=N, tint=0.85 + 0.3 * rng.random())
        # eave edge: a thick shaggy lip, bottom ragged
        for i in range(nx):
            lo0 = top[-1][i] - N * (0.42 + rng.uniform(-0.05, 0.06))
            lo1 = top[-1][i + 1] - N * (0.42 + rng.uniform(-0.05, 0.06))
            M.face("roof", [top[-1][i], top[-1][i + 1], lo1, lo0], "thatch", normal=dv, ao=[1.0, 1.0, 0.55, 0.55], tint=0.7 + 0.3 * rng.random())
            M.face("roof", [lo0, lo1, under[-1][i + 1] - N * 0.0, under[-1][i]], "deck", normal=-N)
        # underside deck
        M.face("roof", [under[0][0], under[0][nx], under[-1][nx], under[-1][0]], "deck", normal=-N)
        # gable verges
        for ii, sgn in ((0, -1), (nx, 1)):
            for j in range(len(prof) - 1):
                M.face("roof", [top[j][ii], top[j + 1][ii], under[j + 1][ii], under[j][ii]], "thatch", normal=Vector((sgn, 0, 0)), ao=[1.0, 1.0, 0.6, 0.6])
    # ridge roll: half-round bundle with ties
    segs = max(8, round(L / 0.55))
    rr = 0.26
    for k in range(segs):
        x0 = -L * 0.5 + L * k / segs
        x1 = -L * 0.5 + L * (k + 1) / segs
        r0 = rr * (1.0 + 0.08 * rng.random())
        r1 = rr * (1.0 + 0.08 * rng.random())
        cz = H + SLOPE * hd + 0.06
        arc = []
        for a in range(7):
            ang = math.radians(-100 + a * (200.0 / 6))
            arc.append((math.sin(ang), math.cos(ang)))
        for a in range(6):
            (sy0, cz0), (sy1, cz1) = arc[a], arc[a + 1]
            M.face("roof", [Vector((x0, sy0 * r0 * 1.35, cz + cz0 * r0 - 0.04)), Vector((x1, sy0 * r1 * 1.35, cz + cz0 * r1 - 0.04)),
                            Vector((x1, sy1 * r1 * 1.35, cz + cz1 * r1 - 0.04)), Vector((x0, sy1 * r0 * 1.35, cz + cz1 * r0 - 0.04))], "thatch", normal=Vector((0, sy0 + sy1, cz0 + cz1)),
                   tint=0.9 + 0.25 * rng.random())
    # plug the ridge ends
    for sg, xe in ((-1, -L * 0.5), (1, L * 0.5)):
        cz = H + SLOPE * hd + 0.06
        pts = [Vector((xe, math.sin(math.radians(-100 + a * (200.0 / 6))) * rr * 1.35, cz + math.cos(math.radians(-100 + a * (200.0 / 6))) * rr - 0.04)) for a in range(7)]
        M.face("roof", pts, "thatch", normal=Vector((sg, 0, 0)))
    # rafter tails under the eave
    for side in (1, -1):
        R, dv, N, ln = slope_frame(hd, ov, side)
        for i in range(0, 8):
            x = -w * 0.5 + 0.2 + i * (w - 0.4) / 7
            a = R + dv * (ln * 0.8)
            b = R + dv * (ln * 1.0 + 0.12)
            M.beam("body", "wood", a - N * 0.08, b - N * 0.08, 0.08, 0.1, up=N, jit=0.005) if False else None


def slate_roof(M, w, d, st):
    rng = M.rng
    hd = d * 0.5
    ov = 0.45
    ext = 0.34
    L = w + 2 * ext
    rows = 10
    sw = 0.56
    miss = 0.08 if st == "shuttered" else 0.0
    for side in (1, -1):
        R, dv, N, ln = slope_frame(hd, ov, side)
        # deck (the gaps between slates show it)
        M.face("roof", [R - N * 0.0 + Vector((-L * 0.5, 0, 0)), R + Vector((L * 0.5, 0, 0)), R + dv * ln + Vector((L * 0.5, 0, 0)), R + dv * ln + Vector((-L * 0.5, 0, 0))], "deck", normal=N)
        M.face("roof", [R + Vector((-L * 0.5, 0, 0)) - N * 0.04, R + dv * ln + Vector((-L * 0.5, 0, 0)) - N * 0.04, R + dv * ln + Vector((L * 0.5, 0, 0)) - N * 0.04, R + Vector((L * 0.5, 0, 0)) - N * 0.04], "deck", normal=-N)
        for r in range(rows):
            s0, s1 = r / rows, (r + 1) / rows
            n = int(L / sw) + 1
            off = (r % 2) * sw * 0.5 - sw * 0.5
            for i in range(n + 1):
                xa = -L * 0.5 + off + i * sw
                xb = xa + sw * 0.94
                xa, xb = max(xa, -L * 0.5), min(xb, L * 0.5)
                if xb - xa < 0.08:
                    continue
                if miss and rng.random() < miss:
                    continue
                slip = 0.0
                if miss and rng.random() < 0.06:
                    slip = rng.uniform(0.02, 0.05)
                # the slate lies from its tuck (s0) with the lower edge proud and ragged
                tuck = R + dv * (s0 * ln - 0.02) + N * 0.025
                lo = R + dv * (s1 * ln + 0.015 + rng.uniform(-0.012, 0.012) + slip) + N * (0.075 + slip)
                tuck2 = lambda x: Vector((x, tuck.y, tuck.z))
                lo2 = lambda x: Vector((x, lo.y, lo.z))
                tt = 0.78 + 0.4 * rng.random()
                M.face("roof", [tuck2(xa), tuck2(xb), lo2(xb), lo2(xa)], "slate", normal=N, tint=tt, ao=[0.6, 0.6, 1.0, 1.0])
                th = 0.032
                M.face("roof", [lo2(xa), lo2(xb), lo2(xb) - N * th, lo2(xa) - N * th], "slate", normal=dv, tint=tt * 0.7, ao=[1, 1, 0.5, 0.5])
    # ridge cap: a run of clay-grey capping tiles
    cz = H + SLOPE * hd
    nseg = max(6, round(L / 0.6))
    for k in range(nseg):
        x0 = -L * 0.5 + L * k / nseg
        x1 = -L * 0.5 + L * (k + 1) / nseg - 0.02
        pts = [(-0.3, cz - 0.15), (-0.12, cz + 0.12), (0.12, cz + 0.12), (0.3, cz - 0.15)]
        for a in range(3):
            (y0, z0), (y1, z1) = pts[a], pts[a + 1]
            M.face("roof", [Vector((x0, y0, z0)), Vector((x1, y0, z0)), Vector((x1, y1, z1)), Vector((x0, y1, z1))], "slate", normal=Vector((0, (y0 + y1), 1.0)), tint=0.7 + 0.3 * rng.random())
        M.face("roof", [Vector((x0, pts[0][0], pts[0][1])), Vector((x0, pts[1][0], pts[1][1])), Vector((x0, pts[2][0], pts[2][1])), Vector((x0, pts[3][0], pts[3][1]))], "slate", normal=Vector((-1, 0, 0)), ao=[0.5] * 4)
    # barge boards along the verges
    for side in (1, -1):
        R, dv, N, ln = slope_frame(hd, ov, side)
        for sx in (-1, 1):
            a = R + Vector((sx * (L * 0.5), 0, 0)) - N * 0.02
            b = a + dv * (ln + 0.02)
            M.beam("body", "wood", a, b, 0.05, 0.2, up=Vector((1, 0, 0)), jit=0.004)
    # dark underside deck of the gable ends
    for sx in (-1, 1):
        pass


def chimney(M, w, d, roof, st, ruin_top=None):
    """External breast on the +x gable: three tapering sections, each a rubble core faced with coursed blocks on all
    four sides (the -x face above the roof only), set-off ledges, a drip cap and a clay pot. `ruin_top` breaks it off."""
    hw, hd = w * 0.5, d * 0.5
    cy = -hd * 0.25
    ridge = H + SLOPE * hd
    rng = M.rng
    top = ridge + (1.55 if roof == "thatch" else 1.05) if ruin_top is None else ruin_top
    x_out = hw + 0.2
    secs = [(0.4, 2.35, 0.7, 0.9), (2.35, 3.55, 0.62, 0.8), (3.55, top - 0.12, 0.54, 0.7)]
    for (z0, z1, wx, wy) in secs:
        z1 = min(z1, top)
        if z1 - z0 < 0.2:
            continue
        cx = x_out - wx * 0.5
        M.box("body", "stone", (cx, cy, (z0 + z1) * 0.5), (wx - 0.03, wy - 0.03, z1 - z0), skip=("-z",), jit=0.008)
        faces = [
            (Wall((cx + wx * 0.5, cy - wy * 0.5, 0), (0, 1, 0), (1, 0, 0), wy, "px"), z0),
            (Wall((cx - wx * 0.5, cy + wy * 0.5, 0), (0, -1, 0), (-1, 0, 0), wy, "nx"), max(z0, ridge - 0.25)),
            (Wall((cx + wx * 0.5, cy + wy * 0.5, 0), (-1, 0, 0), (0, 1, 0), wx, "py"), z0),
            (Wall((cx - wx * 0.5, cy - wy * 0.5, 0), (1, 0, 0), (0, -1, 0), wx, "ny"), z0),
        ]
        for Wf, zs in faces:
            if z1 - zs < 0.2:
                continue
            blocks(M, Wf, course_bounds(rng, zs, z1, 0.36), None, 0.035, (0.42, 0.8), tone="stone", ops=[], rounding=0.025)
        if z1 < top - 0.2:
            # set-off ledge where the stack steps in
            M.box("body", "stone", (x_out - wx * 0.5 - 0.01, cy, z1 + 0.02), (wx + 0.14, wy + 0.14, 0.08), jit=0.01, skip=("-z",))
    cx, cyy = x_out - 0.3, cy
    if ruin_top is not None:
        # broken off: a ragged top and the stack's blocks in the rubble
        for _ in range(3):
            M.box("body", "stone", (x_out - 0.3 + rng.uniform(-0.15, 0.15), cy + rng.uniform(-0.25, 0.25), top + 0.06), (rng.uniform(0.2, 0.35), rng.uniform(0.2, 0.3), 0.14), rotz=rng.random() * 6.28, jit=0.012)
        return top
    M.box("body", "stone", (x_out - 0.3, cy, top + 0.06), (0.68, 0.84, 0.14), jit=0.012)
    M.box("body", "sootstone", (x_out - 0.3, cy, top + 0.17), (0.42, 0.58, 0.08), jit=0.01)
    for a in range(6):
        a0, a1 = a * math.pi / 3, (a + 1) * math.pi / 3
        r = 0.15
        zb, zt = top + 0.2, top + 0.58
        pp = [Vector((cx + math.cos(a0) * r, cyy + math.sin(a0) * r, zb)), Vector((cx + math.cos(a1) * r, cyy + math.sin(a1) * r, zb)),
              Vector((cx + math.cos(a1) * r * 0.82, cyy + math.sin(a1) * r * 0.82, zt)), Vector((cx + math.cos(a0) * r * 0.82, cyy + math.sin(a0) * r * 0.82, zt))]
        M.face("body", pp, "sootstone" if a % 2 else "stone", away=Vector((cx, cyy, zb)), tint=1.1)
    M.face("body", [Vector((cx + math.cos(a * math.pi / 3) * 0.12, cyy + math.sin(a * math.pi / 3) * 0.12, top + 0.57)) for a in range(6)], "dark", normal=Z)
    return top


# =====================================================================================================================
# ruin dressing
# =====================================================================================================================
def rubble(M, centre, r, n, tone="rubble", spread=1.0):
    rng = M.rng
    for _ in range(n):
        a = rng.random() * math.tau
        dd = rng.random() * r * spread
        rr = rng.uniform(0.12, 0.3) * (1.4 - 0.7 * dd / max(r, 0.01))
        M.rock("body", tone, (centre[0] + math.cos(a) * dd, centre[1] + math.sin(a) * dd, centre[2] + rr * 0.15), rr, 0.65)


def hearth(M, w, d, ruined_state):
    hw, hd = w * 0.5, d * 0.5
    cy = -hd * 0.25
    # breast of the fireplace against the east gable inside
    x1 = hw - T
    M.box("body", "stone", (x1 - 0.3, cy, 0.5), (0.6, 1.3, 1.0), jit=0.015)
    M.box("body", "dark", (x1 - 0.605, cy, 0.38), (0.02, 0.8, 0.56), jit=0.0)
    M.box("body", "wood", (x1 - 0.62, cy, 1.55), (0.14, 1.5, 0.16), jit=0.01)
    if ruined_state == "burned":
        M.box("body", "char", (x1 - 0.8, cy, 0.05), (0.7, 0.9, 0.1), jit=0.01)


def trusses(M, spec, frames, st):
    """What stands of the roof frame: charred or silvered rafter pairs rising from the wall tops, a tie beam, a ridge stub."""
    rng = M.rng
    w, d = spec["w"], spec["d"]
    hw, hd = w * 0.5, d * 0.5
    wood = "char" if st == "burned" else "wood"
    n = 3
    for i in range(n):
        x = -hw + (i + 0.5) * w / n + rng.uniform(-0.25, 0.25)
        for side in (1, -1):
            Wf = frames["front"] if side == 1 else frames["back"]
            u = (x + hw) if side == 1 else (hw - x)
            zf = Wf.topf(u) - 0.02
            if rng.random() < 0.22:
                continue
            ln = rng.uniform(1.0, 3.3) if i != 1 else rng.uniform(0.7, 2.0)
            dirv = Vector((rng.uniform(-0.04, 0.04), -side, SLOPE)).normalized()
            a = Vector((x, side * (hd - 0.1), zf))
            M.beam("body", wood, a, a + dirv * ln, 0.16, 0.13, up=Z, jit=0.014)
        if rng.random() < 0.7:
            zt = min(frames["front"].topf(x + hw), frames["back"].topf(hw - x)) + 0.05
            y0, y1 = rng.uniform(-hd + 0.3, -0.5), rng.uniform(0.5, hd - 0.3)
            M.beam("body", wood, Vector((x, y0, zt)), Vector((x, y1, zt + rng.uniform(-0.05, 0.1))), 0.17, 0.15, up=Z, jit=0.014)
    # a broken ridge purlin lying across two rafters' ends
    zr = H + SLOPE * hd
    M.beam("body", wood, Vector((-hw + 1.0, 0, zr - 0.0)), Vector((-hw + 1.0 + rng.uniform(1.2, 2.2), 0.1, zr - 0.05)), 0.2, 0.2, up=Z, jit=0.012) if False else None


def ruin_extras(M, spec, walls_by_name, st):
    rng = M.rng
    w, d = spec["w"], spec["d"]
    hw, hd = w * 0.5, d * 0.5
    wood = "char" if st == "burned" else "wood"
    # fallen rafters and a tie beam
    nraf = 8 if (spec.get('collapse') and st == 'ruined') else 4
    for i in range(nraf):
        x = -hw + 0.9 + i * (w - 1.8) / max(1, nraf - 1) + rng.uniform(-0.3, 0.3)
        y0 = rng.uniform(-hd * 0.45, hd * 0.3)
        ang = rng.uniform(0.2, 0.7)
        yaw = rng.uniform(-0.35, 0.35) + (math.pi / 2)
        ln = rng.uniform(2.2, 3.4)
        a = Vector((x, y0, 0.14))
        dirv = Vector((math.cos(yaw) * math.cos(ang), math.sin(yaw) * math.cos(ang), math.sin(ang)))
        M.beam("body", wood, a, a + dirv * ln, 0.17, 0.16, up=Z, jit=0.012)
    if st == "ruined":
        # slates and a few roof bones scattered over the floor and out the broken door
        for _ in range(26):
            p = Vector((rng.uniform(-hw + 0.6, hw - 0.6), rng.uniform(-hd + 0.6, hd - 0.6), 0.1))
            M.box("body", "slate", p, (rng.uniform(0.22, 0.32), rng.uniform(0.3, 0.4), 0.025), rotz=rng.random() * 6.28, skip=("-z",), jit=0.01)
        # fallen wall blocks
        for _ in range(6):
            p = Vector((rng.uniform(-hw + 0.5, hw - 0.5), rng.uniform(-hd + 0.5, hd - 0.5), 0.12))
            M.box("body", "stone", p, (rng.uniform(0.4, 0.7), rng.uniform(0.25, 0.4), 0.28), rotz=rng.random() * 6.28, jit=0.02)
        # the collapsed gable's spill, out across the yard
        rubble(M, (hw + 0.9, 0.2, 0.0), 1.7, 11, spread=1.0)
        rubble(M, (hw - 1.2, -hd * 0.3, 0.0), 1.1, 7)
        for _ in range(6):
            p = Vector((hw + rng.uniform(0.2, 2.2), rng.uniform(-1.8, 1.8), 0.14))
            M.box("body", "stone", p, (rng.uniform(0.4, 0.7), rng.uniform(0.25, 0.4), 0.28), rotz=rng.random() * 6.28, jit=0.02)
    if st == "burned":
        for _ in range(6):
            p = Vector((rng.uniform(-hw + 0.7, hw - 0.7), rng.uniform(-hd + 0.7, hd - 0.7), 0.06))
            M.box("body", "char", p, (rng.uniform(0.6, 1.6), 0.12, 0.1), rotz=rng.random() * 6.28, skip=("-z",), jit=0.01)
    rubble(M, (hw * 0.3, -hd * 0.1, 0.0), 1.5, 9)
    rubble(M, (-hw * 0.4, hd * 0.25, 0.0), 1.0, 5)
    # tumble outside the walls
    for (x, y, rr, n) in ((-hw - 0.5, -hd * 0.3, 0.9, 4), (hw + 0.6, hd * 0.4, 1.0, 5), (0.0, -hd - 0.6, 1.4, 6), (-hw * 0.2, hd + 0.5, 0.8, 4)):
        rubble(M, (x, y, 0.0), rr, n)


# =====================================================================================================================
# the cottage
# =====================================================================================================================
def ruin_topf(rng, L, kind, bounds):
    """Piecewise-constant ragged wall top (0.5 m columns) snapped to course boundaries."""
    amt = 0.55 if kind == "ruined" else 0.4
    ph = rng.random() * 10
    cols = int(math.ceil(L / 0.5))
    hs = []
    for i in range(cols):
        u = (i + 0.5) / cols
        dip = clamp(0.5 + 0.5 * math.sin(u * 5.0 + ph) + rng.uniform(-0.25, 0.25))
        edge = 1.0 - 0.6 * min(u, 1.0 - u) * 2.0
        hh = H * (1.0 - amt * dip * (1.0 - edge * 0.45))
        k = max(i for i, b in enumerate(bounds) if b <= hh + 1e-6)
        hs.append(bounds[k])

    def f(u):
        i = min(cols - 1, max(0, int(u / 0.5)))
        return hs[i]
    return f


def build_near(name, spec):
    st, walls, roof = spec["state"], spec["walls"], spec["roof"]
    w, d = spec["w"], spec["d"]
    hw, hd = w * 0.5, d * 0.5
    M = Mesh(spec["seed"], st, walls)
    M.chim_x = hw - 0.4
    rng = M.rng
    ruined = st in ("ruined", "burned")
    stone = walls == "stone"
    gh = H + SLOPE * hd
    # --- wall frames and openings -----------------------------------------------------------------------------
    door = op(w * 0.36, 1.1, 0.0, 2.05, door=True)
    def win(at):
        return op(at, 0.8, 0.95, 1.85)
    front = Wall((-hw, hd, 0), (1, 0, 0), (0, 1, 0), w, "front")
    front.ops = [door, win(w * 0.72)]
    back = Wall((hw, -hd, 0), (-1, 0, 0), (0, -1, 0), w, "back")
    back.ops = [win(w * 0.3), win(w * 0.7)]
    west = Wall((-hw, -hd, 0), (0, 1, 0), (-1, 0, 0), d, "west")
    west.ops = [win(d * 0.5)]
    east = Wall((hw, hd, 0), (0, -1, 0), (1, 0, 0), d, "east")
    east.ops = []
    allw = [front, back, west, east]
    glen = lambda L: (lambda u: H + SLOPE * min(u, L - u))
    plinth_h = 0.46 if not stone else 0.5
    ring_col = None
    for W in allw:
        gable = W.name in ("west", "east")
        L = W.L
        if ruined:
            bounds = course_bounds(rng, plinth_h, H + (SLOPE * L * 0.5 if gable else 0.0) + 0.3, 0.31)
            bounds = [0.0] + bounds if False else bounds
            base = ruin_topf(rng, L, st, bounds)
            if gable:
                tf = (lambda b, g: (lambda u: min(b(u), H + SLOPE * min(u, L - u))))(base, gable)
                if spec.get("collapse") == W.name:
                    def snap(h, bounds=bounds):
                        return max(b_ for b_ in bounds if b_ <= h + 1e-6)

                    def tf(u, base=base, L=L, snap=snap):
                        lift = 3.2 * (1.0 - smooth(0.0, 0.42, abs(u / L - 0.62)))
                        return snap(min(H + SLOPE * min(u, L - u), base(u) + lift))
            else:
                tf = base
            W.topf = tf
        else:
            W.topf = glen(L) if gable else (lambda u: H)
        W.ruin_cols = ruined
        # plinth: coursed stone round the foot
        pb = course_bounds(rng, 0.0, plinth_h, 0.5 if not stone else 0.5)
        # --- stone-faced walls ---
        if stone:
            sb = course_bounds(rng, plinth_h, H + (SLOPE * L * 0.5 if gable else 0.0), 0.32)
            if ruined:
                sb = bounds
            core(M, W, W.topf, ruined, "stone", "inner", sides=ruined)
            blocks(M, W, [0.0, plinth_h], None, 0.1, (0.7, 1.1))
            blocks(M, W, sb, W.topf, 0.045, (0.62, 1.15) if ruined else (0.5, 0.95), miss=0.12 if ruined else 0.0, clip=(gable and not ruined))
            if ruined:
                Wi = W.inner()
                blocks(M, Wi, [0.0] + (sb if sb[0] > 0 else sb[1:]), W.topf, 0.04, (1.0, 1.6), miss=0.0, ops=[dict(o) for o in W.ops])
        else:
            core(M, W, W.topf, False, "daub", "inner")
            blocks(M, W, [0.0, plinth_h], None, 0.1, (0.6, 1.0), ops=W.ops)
            daub_wall(M, W, H, st)
            if gable:
                daub_gable(M, W, st)
        # openings
        for o in W.ops:
            if o["door"]:
                door_fit(M, W, o, st, H)
            else:
                topv = W.topf((o["u0"] + o["u1"]) * 0.5)
                o["keep_head"] = topv > o["v1"] + 0.25
                window_fit(M, W, o, st, stone)
    # foundation skirt and floor
    M.box("body", "stone", (0, 0, -0.35), (w + 0.3, d + 0.3, 0.7), skip=("+z", "-z"), ao=None)
    M.box("body", "floor", (0, 0, -0.04), (w - 2 * T, d - 2 * T, 0.08), skip=("-z",))
    # corner posts / quoins
    for sx in (-1, 1):
        for sy in (-1, 1):
            cx, cy = sx * hw, sy * hd
            if stone:
                z = plinth_h
                i = 0
                top = (H - 0.15) if not ruined else H * rng.uniform(0.45, 0.85)
                while z < top:
                    ch = 0.34 if i % 2 == 0 else 0.3
                    lx, ly = (0.62, 0.42) if i % 2 == 0 else (0.42, 0.62)
                    M.box("body", "stone", (cx - sx * (lx * 0.5 - 0.05), cy - sy * (ly * 0.5 - 0.05), z + ch * 0.5), (lx, ly, ch - 0.02), jit=0.012, skip=("-z",))
                    z += ch
                    i += 1
            else:
                M.box("body", "wood", (cx - sx * 0.06, cy - sy * 0.06, (plinth_h + H) * 0.5 - 0.0), (0.24, 0.24, H - plinth_h + 0.1), jit=0.01)
    # --- roof or ruin ----------------------------------------------------------------------------------------
    if not ruined:
        # stone gable triangles are covered by the blocks + core; closed roof space
        if roof == "thatch":
            thatch_roof(M, w, d, st)
        else:
            slate_roof(M, w, d, st)
        chimney(M, w, d, roof, st)
    else:
        hearth(M, w, d, st)
        if spec.get("collapse"):
            chimney(M, w, d, roof, st, ruin_top=4.3 if st == "ruined" else 5.0)
        ruin_extras(M, spec, {x.name: x for x in allw}, st)
        trusses(M, spec, {x.name: x for x in allw}, st)
    # --- per-cottage dressing ---------------------------------------------------------------------------------
    if st == "lived":
        # a planter under the front window with herbs, a rain-gutter-less drip stone
        W = front
        o = front.ops[1]
        wbox(M, "body", "wood", W, o["at"] - 0.45, o["at"] + 0.45, o["v0"] - 0.38, o["v0"] - 0.1, -0.34, -0.12, jit=0.01)
        for i in range(7):
            u = o["at"] - 0.38 + i * 0.127
            M.rock("body", "rubble", W.P(u, o["v0"] - 0.08, -0.23) , 0.1, 0.9) if False else None
        # a bundle of herbs/leaves as little green fans
        for i in range(6):
            u = o["at"] - 0.36 + i * 0.145
            p0 = W.P(u, o["v0"] - 0.1, -0.23)
            for k in range(3):
                a = rng.random() * 6.28
                tip = p0 + Vector((math.cos(a) * 0.08, math.sin(a) * 0.08, rng.uniform(0.12, 0.24)))
                M.face("body", [p0 + Vector((0.025, 0, 0)), p0 - Vector((0.025, 0, 0)), tip], "inner", normal=Vector((0, 1, 0)) if False else None, away=p0 - Vector((0, 0, 1)), tint=1.0) if False else None
        # a hanging iron lantern bracket by the door
        o = front.ops[0]
        wbox(M, "body", "iron", W, o["at"] - o["w"] * 0.5 - 0.4, o["at"] - o["w"] * 0.5 - 0.34, 2.05, 2.12, -0.5, -0.05)
        wbox(M, "body", "iron", W, o["at"] - o["w"] * 0.5 - 0.4, o["at"] - o["w"] * 0.5 - 0.34, 1.95, 2.12, -0.5, -0.45)
    if st == "shuttered" and walls == "stone":
        # slumped, mossy lean-to firewood stack against the west gable
        for row in range(2):
            for i in range(5 - row):
                y = -hd + 0.9 + 0.22 * i + 0.11 * row
                M.box("body", "wood", (-hw - 0.35, y + 0.2, 0.12 + 0.2 * row), (0.16, 1.0, 0.16), jit=0.015) if False else None
    return M, dict(front=front, back=back, west=west, east=east, gh=gh)


# ---------------------------------------------------------------------------------------------------------------------
def build_col(spec, frames, M2):
    """Collision: walls as boxes with the door left open and sills under windows, plus roof slabs."""
    w, d = spec["w"], spec["d"]
    hw, hd = w * 0.5, d * 0.5
    ruined = spec["state"] in ("ruined", "burned")
    for key in ("front", "back", "west", "east"):
        W = frames[key]
        for (a, b, v0, va, vb) in pieces(W.L, W.ops, W.topf, False):
            if ruined:
                va = vb = min(va, vb)
            if b - a < 0.02 or min(va, vb) - v0 < 0.02:
                continue
            wbox(M2, "body", "dark", W, a, b, v0, min(va, vb) if not ruined else min(va, vb), 0.0, T)
    M2.box("body", "dark", (0, 0, -0.35), (w + 0.3, d + 0.3, 0.7))
    o = frames["front"].ops[0]
    Wf = frames["front"]      # a walkable ramp under the doorstep and steps (collision only)
    ra, rb = o["at"] - 0.75, o["at"] + 0.75
    M2.hexa("body", "dark", [Wf.P(ra, -1.9, -0.4), Wf.P(rb, -1.9, -0.4), Wf.P(ra, -1.9, -3.6), Wf.P(rb, -1.9, -3.6),
                             Wf.P(ra, 0.06, -0.4), Wf.P(rb, 0.06, -0.4), Wf.P(ra, -1.7, -3.6), Wf.P(rb, -1.7, -3.6)])
    if spec["state"] in ("lived", "shuttered"):
        o = frames["front"].ops[0]          # the shut door is solid (cottage.gd's was)
        wbox(M2, "body", "dark", frames["front"], o["u0"], o["u1"], 0.0, o["v1"], 0.1, 0.25)
    if not ruined:
        ov = 0.45
        for side in (1, -1):
            R, dv, N, ln = slope_frame(hd, ov, side)
            c = R + dv * (ln * 0.5) + N * 0.15
            M2.beam("body", "dark", c - Vector((w * 0.5 + 0.35, 0, 0)), c + Vector((w * 0.5 + 0.35, 0, 0)), ln, 0.3, up=N) if False else None
            a = R + dv * (ln * 0.0) + N * 0.15
            b = R + dv * ln + N * 0.15
            slab = [a + Vector((-w * 0.5 - 0.35, 0, 0)), a + Vector((w * 0.5 + 0.35, 0, 0)), b + Vector((w * 0.5 + 0.35, 0, 0)), b + Vector((-w * 0.5 - 0.35, 0, 0))]
            cs = []
            for i in range(8):
                base = slab[[0, 1, 3, 2][i & 3]] if False else None
            # box from the slab corners
            p = [slab[0], slab[1], slab[3], slab[2]]
            cs = [p[0] - N * 0.15, p[1] - N * 0.15, p[2] - N * 0.15, p[3] - N * 0.15, p[0] + N * 0.15, p[1] + N * 0.15, p[2] + N * 0.15, p[3] + N * 0.15]
            M2.hexa("body", "dark", cs)


def build_far(name, spec, frames):
    st, walls, roof = spec["state"], spec["walls"], spec["roof"]
    w, d = spec["w"], spec["d"]
    hw, hd = w * 0.5, d * 0.5
    M = Mesh(spec["seed"] + 100, st, walls)
    M.chim_x = hw - 0.4
    rng = M.rng
    wall_tone = "stone" if walls == "stone" else "daub"
    ruined = st in ("ruined", "burned")
    # foot
    M.box("body", "stone", (0, 0, -0.3), (w + 0.2, d + 0.2, 0.9), skip=("-z",))
    if not ruined:
        # walls + gable prism (pentagonal) in one go
        gh = H + SLOPE * hd
        pts_front = [(-hw, hd, 0.0), (hw, hd, 0.0), (hw, hd, H), (-hw, hd, H)]
        M.box("body", wall_tone, (0, 0, H * 0.5), (w, d, H), skip=("-z", "+z"))
        # gable triangles
        for sx in (-1, 1):
            M.face("body", [Vector((sx * hw, -hd, H)), Vector((sx * hw, hd, H)), Vector((sx * hw, 0, gh))], wall_tone, normal=Vector((sx, 0, 0)))
        # roof: two slabs with eave overhang
        ov = 0.45
        ext = 0.36
        rt = "thatch" if roof == "thatch" else "slate"
        th = 0.4 if roof == "thatch" else 0.1
        for side in (1, -1):
            R, dv, N, ln = slope_frame(hd, ov, side)
            a = R + dv * 0.0
            b = R + dv * ln
            xs = w * 0.5 + ext
            pts = [Vector((-xs, a.y, a.z)), Vector((xs, a.y, a.z)), Vector((xs, b.y, b.z)), Vector((-xs, b.y, b.z))]
            cs = [pts[0], pts[1], pts[3], pts[2], pts[0] + N * th, pts[1] + N * th, pts[3] + N * th, pts[2] + N * th]
            M.hexa("roof", rt, cs, skip=("-z",))
        # chimney
        top = gh + (1.55 if roof == "thatch" else 1.05)
        cy = -hd * 0.25
        M.box("body", "stone", (hw + 0.2 - 0.35, cy, (top + 0.4) * 0.5), (0.7, 0.85, top - 0.4), skip=("-z",))
        # door and windows as dark / glowing patches
        for W in (frames["front"], frames["back"], frames["west"]):
            for o in W.ops:
                dd = -0.03
                tone = "dark" if o["door"] else ("glow" if st == "lived" else "dark")
                key = "glow" if tone == "glow" else "body"
                M.face(key, [W.P(o["u0"], o["v0"], dd), W.P(o["u1"], o["v0"], dd), W.P(o["u1"], o["v1"], dd), W.P(o["u0"], o["v1"], dd)], tone, normal=W.n)
    else:
        # broken wall stubs
        for W in (frames["front"], frames["back"], frames["west"], frames["east"]):
            for (a, b, v0, va, vb) in pieces(W.L, W.ops, W.topf, True):
                if min(va, vb) - v0 < 0.1 or b - a < 0.4:
                    continue
                pass
            # merge by 1 m runs
            n = max(2, int(W.L / 1.3))
            for i in range(n):
                a, b = W.L * i / n, W.L * (i + 1) / n
                hv = W.topf((a + b) * 0.5)
                if any(o["u0"] < b and o["u1"] > a and o["v0"] < 0.2 for o in W.ops):
                    hv = 0.0
                if hv < 0.2:
                    continue
                wbox(M, "body", wall_tone if st != "burned" else "sootstone", W, a, b, 0.0, hv, 0.0, T)
        for _ in range(4):
            M.rock("body", "rubble", (rng.uniform(-hw, hw), rng.uniform(-hd, hd), 0.0), 0.5, 0.7)
        hearth_top = 1.6
        M.box("body", "stone", (hw - T - 0.3, -hd * 0.25, 0.55), (0.6, 1.3, 1.1), skip=("-z",))
    return M


# =====================================================================================================================
# output
# =====================================================================================================================
def tri_count(objs):
    return sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objs)


def export(objs, path):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    kw = dict(filepath=path, export_format='GLB', use_selection=True, export_apply=True, export_yup=True,
              export_materials='EXPORT', export_image_format='NONE', export_normals=True, export_texcoords=True)
    try:
        bpy.ops.export_scene.gltf(export_vertex_color='ACTIVE', export_active_vertex_color_when_no_material=True, **kw)
    except TypeError:
        try:
            bpy.ops.export_scene.gltf(export_vertex_color='ACTIVE', **kw)
        except TypeError:
            bpy.ops.export_scene.gltf(**kw)
    print("EXPORTED", path, tri_count(objs), "tris")


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def build_one(name):
    spec = SPECS[name]
    reset()
    M, frames = build_near(name, spec)
    rz = H + SLOPE * spec["d"] * 0.5
    Mc = Mesh(1, spec["state"], spec["walls"])
    build_col(spec, frames, Mc)
    near = finish(M, name, {"glow": "WindowGlow"}, rz=rz)
    col = finish(Mc, name + "-colonly", {})
    colobjs = list(col.values())
    for o in colobjs:
        o.data.materials.clear()
        o.data.color_attributes.remove(o.data.color_attributes["Col"])
        o.data.uv_layers.remove(o.data.uv_layers[0])
    if len(colobjs) > 1:
        bpy.ops.object.select_all(action='DESELECT')
        for o in colobjs:
            o.select_set(True)
        bpy.context.view_layer.objects.active = colobjs[0]
        bpy.ops.object.join()
        colobjs = [bpy.context.view_layer.objects.active]
    colobjs[0].name = colobjs[0].data.name = name + "-colonly"
    nobjs = list(near.values())
    print(name, "near tris", {k: tri_count([v]) for k, v in near.items()}, "total", tri_count(nobjs), "col", tri_count(colobjs))
    far_M = build_far(name, spec, frames)
    far = finish(far_M, name + "_far", {"glow": "FarGlow"}, rz=rz)
    print(name, "far tris", tri_count(list(far.values())))
    if not NOEXPORT:
        export(nobjs + colobjs, os.path.join(OUT, "cottage_%s.glb" % name))
        export(list(far.values()), os.path.join(OUT, "cottage_%s_far.glb" % name))
    if PREVIEW:
        for o in far.values():
            o.hide_render = True
            o.hide_viewport = True
        for o in colobjs:
            o.hide_render = True
        texture_mats()
        preview(name, spec, frames)
    return near, far, colobjs


# ---------------------------------------------------------------------------------------------------------------------
def preview(name, spec, frames):
    os.makedirs(PREVIEW, exist_ok=True)
    sc = bpy.context.scene
    try:
        sc.render.engine = 'BLENDER_EEVEE'
    except TypeError:
        sc.render.engine = 'BLENDER_WORKBENCH'
    sc.render.resolution_x = sc.render.resolution_y = 960
    sc.view_settings.view_transform = 'Standard'
    w, d = spec["w"], spec["d"]
    # ground disc
    bpy.ops.mesh.primitive_circle_add(vertices=48, radius=26, fill_type='NGON', location=(0, 0, -0.02))
    gr = bpy.context.object
    gm = bpy.data.materials.new("ground")
    gm.use_nodes = True
    gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.035, 0.045, 0.03, 1)
    gm.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 1.0
    gr.data.materials.append(gm)
    cam_d = bpy.data.cameras.new("cam")
    cam = bpy.data.objects.new("cam", cam_d)
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam_d.clip_end = 400
    hw, hd = w * 0.5, d * 0.5
    door_x = -hw + w * 0.36
    views = [
        ("front", (0.5, hd + 11.5, 2.2), (0.3, 0, 2.0), 36),
        ("three", (hw + 7.5, hd + 8.5, 3.6), (0, 0, 2.2), 36),
        ("side", (hw + 12.5, -2.5, 2.6), (0, -0.4, 2.7), 40),
        ("close", (door_x + 2.4, hd + 4.4, 1.7), (door_x + 0.7, hd, 1.4), 38),
    ]

    def lights(mode):
        for o in [o for o in bpy.data.objects if o.type == 'LIGHT']:
            bpy.data.objects.remove(o)
        w_ = bpy.data.worlds.new("w")
        w_.use_nodes = True
        bg = w_.node_tree.nodes["Background"]
        sc.world = w_
        if mode == "neutral":
            bg.inputs[0].default_value = (0.7, 0.72, 0.75, 1)
            bg.inputs[1].default_value = 0.8
            ld = bpy.data.lights.new("sun", 'SUN')
            ld.energy = 3.2
            ld.color = (1.0, 0.97, 0.9)
            lo = bpy.data.objects.new("sun", ld)
            sc.collection.objects.link(lo)
            lo.rotation_euler = (math.radians(50), 0, math.radians(35))
        else:
            bg.inputs[0].default_value = (0.03, 0.045, 0.12, 1)
            bg.inputs[1].default_value = 1.0
            ld = bpy.data.lights.new("moon", 'SUN')
            ld.energy = 1.5
            ld.color = (0.55, 0.65, 1.0)
            lo = bpy.data.objects.new("moon", ld)
            sc.collection.objects.link(lo)
            lo.rotation_euler = (math.radians(58), 0, math.radians(30))
            # warm fire fill from the village brazier, low in front
            fl = bpy.data.lights.new("fire", 'POINT')
            fl.energy = 1500
            fl.color = (1.0, 0.55, 0.25)
            fl.shadow_soft_size = 0.4
            fo = bpy.data.objects.new("fire", fl)
            sc.collection.objects.link(fo)
            fo.location = (hw * 0.5 + 3.0, hd + 7.5, 1.1)
            if spec["state"] == "lived":
                f = frames["front"]
                for o in f.ops[1:]:
                    wl = bpy.data.lights.new("win", 'POINT')
                    wl.energy = 160
                    wl.color = (1.0, 0.6, 0.28)
                    wl.shadow_soft_size = 0.15
                    wo = bpy.data.objects.new("win", wl)
                    sc.collection.objects.link(wo)
                    wo.location = f.P(o["at"], 1.4, -0.6)
        for o in bpy.data.objects:
            if o.type == 'MESH' and o.name == "WindowGlow":
                for m in o.data.materials:
                    m.node_tree.nodes["Principled BSDF"].inputs["Emission Strength"].default_value = 6.0 if mode == "night" else 1.0

    for mode in ("neutral", "night"):
        lights(mode)
        for nm, loc, tgt, lens in views:
            cam.location = loc
            cam.rotation_euler = (Vector(tgt) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
            cam_d.lens = lens
            sc.render.filepath = os.path.join(PREVIEW, "%s_%s_%s.png" % (name, mode, nm))
            bpy.ops.render.render(write_still=True)
        if mode == "night" and spec["state"] == "lived":
            loc, tgt, lens = (-5.5, hd + 7.0, 1.7), (-0.5, 0, 1.9), 30
            cam.location = loc
            cam.rotation_euler = (Vector(tgt) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
            cam_d.lens = lens
            sc.render.filepath = os.path.join(PREVIEW, "%s_night_hero.png" % name)
            bpy.ops.render.render(write_still=True)


def main():
    names = ONLY or list(SPECS)
    for n in names:
        build_one(n)


main()
