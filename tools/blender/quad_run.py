"""r38d: sculpt terms, rig sockets and the shared build driver for the quadruped creatures
(grunt_quad.py, boss_thornwarden.py). See quad_sculpt_lib.py for the pieces."""
import bpy
import math
import os
import sys
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import boss_kit as K
import quad_sdf as Q
import quad_sculpt_lib as L


class Sculpt:
    """Displacement terms (metres along the normal) in rig space, collected and applied once."""

    def __init__(self, P, N):
        self.P, self.N = P, N
        self.d = np.zeros(len(P), dtype=np.float32)

    @staticmethod
    def _face(f, s):
        return np.array([f[0] * s, f[1], f[2]], dtype=np.float32)

    def bump(self, c, r, amp, facing=None, sx=(1,)):
        for s in sx:
            cc = np.array([c[0] * s, c[1], c[2]], dtype=np.float32)
            f = np.exp(-((self.P - cc) ** 2).sum(1) / (r * r))
            if facing is not None:
                f = f * np.clip((self.N @ self._face(facing, s)) * 2.0, 0.0, 1.0)
            self.d += amp * f

    def ridge(self, a, b, w, amp, facing=None, sx=(1,)):
        for s in sx:
            A = np.array([a[0] * s, a[1], a[2]], dtype=np.float32)
            B = np.array([b[0] * s, b[1], b[2]], dtype=np.float32)
            ab = B - A
            t = np.clip(((self.P - A) @ ab) / max(float(ab @ ab), 1e-9), 0.0, 1.0)
            f = np.exp(-((self.P - (A + t[:, None] * ab)) ** 2).sum(1) / (w * w))
            if facing is not None:
                f = f * np.clip((self.N @ self._face(facing, s)) * 2.0, 0.0, 1.0)
            self.d += amp * f

    def noise(self, freq, amp, mask=None, seed=0):
        n = Q.fbm(self.P, freq, 3, seed) - 0.5
        self.d += amp * 2.0 * n * (1.0 if mask is None else mask)

    def folds(self, freq, amp, mask=None, seed=3):
        n = np.abs(Q.fbm(self.P, freq, 2, seed) - 0.5) * 2.0 - 0.5
        self.d += amp * n * (1.0 if mask is None else mask)


def rig_sockets(BH, BL, HSP, UL, upright):
    """Rest sockets of a QuadRig (core/enemy/quad_rig.gd), rig space, as {name: np.array}."""
    s = {"body": np.array([0, BH, 0.0])}
    s["front"] = s["body"] + [0, 0.04, -BL * 0.45]
    s["head"] = s["front"] + [0, 0.03, -0.16]
    s["tail"] = s["body"] + [0, 0.02, BL * 0.45]
    for tag, sx, front in (("fl", -1, True), ("fr", 1, True), ("bl", -1, False), ("br", 1, False)):
        z = -BL * 0.36 if front else BL * 0.34
        hip = s["body"] + [sx * HSP, -0.02, z]
        if upright:
            seg = (BH - 0.05) * 0.5
            knee = hip + [0, -seg, 0.06 if front else -0.08]
            foot = knee + [0, -seg, -0.04 if front else 0.1]
        else:
            knee = hip + [sx * UL, 0.1, 0.0]
            foot = knee + [sx * 0.07, -(BH + 0.08), 0.0]
        s["leg_%s_hip" % tag], s["leg_%s_knee" % tag], s["leg_%s_foot" % tag] = hip, knee, foot
    return s


def bl_sockets(S):
    return {k: K.G(*v) for k, v in S.items()}


def rig_bones(S, tail_len=0.4, head_len=0.25):
    segs = [("body", S["body"], S["front"]), ("front", S["front"], S["head"]), ("head", S["head"], S["head"] + [0, -0.02, -head_len]),
            ("tail", S["tail"], S["tail"] + [0, 0, tail_len]), ("body", S["body"], S["tail"])]
    for t in ("fl", "fr", "bl", "br"):
        h, k, f = S["leg_%s_hip" % t], S["leg_%s_knee" % t], S["leg_%s_foot" % t]
        segs += [("leg_%s_hip" % t, h, k), ("leg_%s_knee" % t, k, f), ("leg_%s_foot" % t, f, f + [0, -0.02, -0.08])]
    return segs


class Ctx:
    """What a creature's detail pass sees: the field, the high's vertices, helpers."""

    def __init__(self, F, P, N):
        self.F, self.P, self.N = F, P, N
        self.sc = Sculpt(P, N)
        self.attrs = {}
        self._tag = {}

    def tag(self, t):
        if t not in self._tag:
            self._tag[t] = self.F.tag_dist(self.P, t)
        return self._tag[t]

    def region(self, tags, bias=None):
        D = np.stack([self.tag(t) - (bias or {}).get(t, 0.0) for t in tags], 1)
        return D.argmin(1)

    def near(self, c, r):
        d = np.sqrt(((self.P - np.asarray(c, dtype=np.float32)) ** 2).sum(1))
        t = np.clip(1.0 - d / r, 0.0, 1.0)
        return t * t * (3 - 2 * t)


def run(spec, argv=None):
    """Build a creature from a spec module. Flags (after --): --no-bake --no-export --preview <png>
    --voxel <m> --sub <n> --size <px> --tris <n>."""
    import time
    args = argv if argv is not None else (sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])

    def arg(n, d=None):
        return args[args.index(n) + 1] if n in args else d
    t0 = time.time()
    K.reset()
    voxel = float(arg("--voxel", spec.VOXEL))
    sub = int(arg("--sub", spec.SUB))
    F = spec.field()
    P, quads = Q.mesh(F, voxel)
    print("T mesh", round(time.time() - t0, 1))
    base = L.object_from_quads(spec.NAME + "Base", P, quads)
    L.smooth_verts(base, 2, 0.5)
    hi = base.copy()
    hi.data = base.data.copy()
    hi.name = spec.NAME + "High"
    bpy.context.scene.collection.objects.link(hi)
    L.subdivide(hi, sub)
    print("T subdiv", round(time.time() - t0, 1), len(hi.data.vertices), "verts")
    P, N = L.rig_verts(hi)
    ctx = Ctx(F, P, N)
    mats, vidx = spec.detail(ctx)
    L.displace(hi, ctx.sc.d, P, N)
    for k, v in ctx.attrs.items():
        L.set_attr(hi, k, v)
    L.assign_materials(hi, mats, vidx)
    hi.data.update()
    print("T detail", round(time.time() - t0, 1))
    if arg("--preview"):
        base.hide_viewport = base.hide_render = True
        tgt, dist = spec.PREVIEW
        if arg("--ptarget"):
            tgt = tuple(float(x) for x in arg("--ptarget").split(","))
            dist = float(arg("--pdist", dist))
        L.shape_preview([hi], arg("--preview"), tgt, dist, views=((60, 0.1), (90, 0.1), (20, 0.25), (150, 0.15)) if arg("--ptarget") else ((0, 0.15), (90, 0.15), (45, 0.35), (180, 0.15)))
        base.hide_viewport = base.hide_render = False
    if "--no-bake" in args:
        return F, hi
    low = L.make_low(base, int(arg("--tris", spec.TRIS)), spec.NAME + "Low")
    S = spec.sockets()
    P2, _ = L.rig_verts(low)
    names, W = L.envelope(P2, spec.segments(S), spec.BAND)
    W = L.smooth_weights(low, W, getattr(spec, "WSMOOTH", 3))
    L.write_weights(low, names, W)
    hi.hide_render = True
    hi.hide_viewport = False
    base.hide_render = base.hide_viewport = True
    size = int(arg("--size", spec.SIZE))
    L.bake(low, hi, mats, spec.PREFIX, size, extrude=getattr(spec, "EXTRUDE", 0.02), ray=getattr(spec, "RAY", 0.06))
    print("T bake", round(time.time() - t0, 1))
    if "--no-export" not in args:
        L.export_glb(low, spec.PREFIX, bl_sockets(S))
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(L.OUT or os.path.join(L.ROOT, "art", "blender"), spec.PREFIX + ".blend"))
    print("T done", round(time.time() - t0, 1))
    return F, hi
