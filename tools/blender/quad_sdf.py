"""Signed-distance modelling for the quadruped enemies (r38d). Pure numpy, no bpy.

A creature is a Field: an ordered list of primitives (ellipsoids, round cones, boxes) joined by SMOOTH
union (a per-primitive blend radius k: a wide one at a shoulder, a hair-fine one at a claw root) with
smooth carves for sockets and mouths. The Field is sampled on a sparse voxel grid and meshed with
surface nets (one watertight quad surface: no seams, no sausages, nothing stuck on), the vertices are
relaxed onto the iso-surface. Everything is in RIG space (Godot: +Y up, the body faces -Z).

    F = Field()
    F.add(RoundCone(a, b, ra, rb), k=0.04, tag="hide")
    F.add(Ell(c, r), 0.03, "bone")
    verts, quads = mesh(F, voxel=0.005)
"""
import math
import numpy as np


def _n(v):
    return np.asarray(v, dtype=np.float32)


def smin(a, b, k):
    if k <= 1e-9:
        return np.minimum(a, b)
    h = np.maximum(k - np.abs(a - b), 0.0) / k
    return np.minimum(a, b) - h * h * k * 0.25


def smax(a, b, k):
    if k <= 1e-9:
        return np.maximum(a, b)
    h = np.maximum(k - np.abs(a - b), 0.0) / k
    return np.maximum(a, b) + h * h * k * 0.25


def rotmat(rx=0.0, ry=0.0, rz=0.0):
    cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
    Rx = np.array([[1, 0, 0], [0, cx, -sx], [0, sx, cx]], dtype=np.float32)
    Ry = np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]], dtype=np.float32)
    Rz = np.array([[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]], dtype=np.float32)
    return Rz @ Ry @ Rx


class Prim:
    lo = hi = None

    def __call__(self, P):
        raise NotImplementedError


class Ell(Prim):
    """Ellipsoid, centre c, radii r, optional Euler rotation (radians, rig space)."""

    def __init__(self, c, r, rot=(0, 0, 0)):
        self.c = _n(c)
        self.r = _n(r if hasattr(r, "__len__") else (r, r, r))
        self.R = rotmat(*rot)
        ext = np.abs(self.R) @ self.r
        self.lo, self.hi = self.c - ext, self.c + ext

    def __call__(self, P):
        q = (P - self.c) @ self.R                # rotate into the local frame (R orthonormal: p @ R = R^T p)
        k0 = np.sqrt(((q / self.r) ** 2).sum(1))
        k1 = np.sqrt(((q / (self.r * self.r)) ** 2).sum(1))
        return k0 * (k0 - 1.0) / np.maximum(k1, 1e-6)


class RoundCone(Prim):
    """A tapering capsule a->b, radius ra at a, rb at b (exact SDF). `flat` squeezes it along the unit
    vector `n` (a muscle belly that is slab-sided: flat=0.6 -> 60% as thick along n)."""

    def __init__(self, a, b, ra, rb, flat=1.0, n=(1, 0, 0)):
        self.a, self.b = _n(a), _n(b)
        self.ra, self.rb = float(ra), float(rb)
        self.flat = float(flat)
        n = _n(n)
        self.n = n / max(float(np.linalg.norm(n)), 1e-9)
        r = max(ra, rb)
        self.lo = np.minimum(self.a, self.b) - r
        self.hi = np.maximum(self.a, self.b) + r

    def __call__(self, P):
        a, b = self.a, self.b
        p = P
        if self.flat != 1.0:
            # stretch space along n by 1/flat about the axis midpoint (the shape shrinks by flat)
            c = (a + b) * 0.5
            q = p - c
            qn = (q @ self.n)[:, None] * self.n
            p = c + q + qn * (1.0 / self.flat - 1.0)
        ba = b - a
        l2 = float(ba @ ba)
        rr = self.ra - self.rb
        a2 = l2 - rr * rr
        il2 = 1.0 / l2
        pa = p - a
        y = pa @ ba
        z = y - l2
        t = pa * l2 - ba[None, :] * y[:, None]
        x2 = (t * t).sum(1)
        y2 = y * y * l2
        z2 = z * z * l2
        k = math.copysign(1.0, rr) * rr * rr * x2
        d_end = np.sqrt(x2 + z2) * il2 - self.rb
        d_start = np.sqrt(x2 + y2) * il2 - self.ra
        d_mid = (np.sqrt(np.maximum(x2 * a2 * il2, 0.0)) + y * rr) * il2 - self.ra
        d = np.where(np.sign(z) * a2 * z2 > k, d_end, np.where(np.sign(y) * a2 * y2 < k, d_start, d_mid))
        return d * self.flat if self.flat < 1.0 else d


class Box(Prim):
    """Rounded box, centre c, half extents h, corner radius rd, Euler rotation."""

    def __init__(self, c, h, rd=0.0, rot=(0, 0, 0)):
        self.c = _n(c)
        self.h = _n(h)
        self.rd = float(rd)
        self.R = rotmat(*rot)
        ext = np.abs(self.R) @ (self.h + rd)
        self.lo, self.hi = self.c - ext, self.c + ext

    def __call__(self, P):
        q = np.abs((P - self.c) @ self.R) - (self.h - self.rd)
        out = np.sqrt((np.maximum(q, 0.0) ** 2).sum(1))
        ins = np.minimum(q.max(1), 0.0)
        return out + ins - self.rd


class Loft(Prim):
    """A body swept along Z: cross-section keys (z, cx, cy, half-width, up, down) interpolated with a
    Catmull-Rom spline into an elliptical section (the torso, a neck, a tail root). The ends close
    where the section shrinks to nothing, so give the first and last key a small radius."""

    def __init__(self, keys, step=0.002, ex=2.0):
        keys = sorted(keys)
        zs = np.arange(keys[0][0], keys[-1][0] + step, step, dtype=np.float32)
        K = np.array(keys, dtype=np.float32)
        n = len(K)
        tab = np.empty((len(zs), 5), dtype=np.float32)
        seg = np.clip(np.searchsorted(K[:, 0], zs, side="right") - 1, 0, n - 2)
        for j in range(5):
            p0 = K[np.maximum(seg - 1, 0), j + 1]
            p1 = K[seg, j + 1]
            p2 = K[seg + 1, j + 1]
            p3 = K[np.minimum(seg + 2, n - 1), j + 1]
            t = (zs - K[seg, 0]) / np.maximum(K[seg + 1, 0] - K[seg, 0], 1e-9)
            t2, t3 = t * t, t * t * t
            tab[:, j] = 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
        self.zs, self.tab = zs, np.maximum(tab, 0.004)
        self.z0, self.z1 = float(zs[0]), float(zs[-1])
        self.lo = _n((-K[:, 3].max() + K[:, 1].min(), K[:, 2].min() - K[:, 5].max(), self.z0))
        self.hi = _n((K[:, 3].max() + K[:, 1].max(), K[:, 2].max() + K[:, 4].max(), self.z1))
        self.ex = ex

    def __call__(self, P):
        z = np.clip(P[:, 2], self.z0, self.z1)
        cx = np.interp(z, self.zs, self.tab[:, 0])
        cy = np.interp(z, self.zs, self.tab[:, 1])
        a = np.interp(z, self.zs, self.tab[:, 2])
        up = np.interp(z, self.zs, self.tab[:, 3])
        dn = np.interp(z, self.zs, self.tab[:, 4])
        x = P[:, 0] - cx
        y = P[:, 1] - cy
        b = np.where(y > 0, up, dn)
        qx, qy = x / a, y / b
        k0 = np.sqrt(qx * qx + qy * qy)
        k1 = np.sqrt((qx / a) ** 2 + (qy / b) ** 2)
        d = k0 * (k0 - 1.0) / np.maximum(k1, 1e-6)
        dz = np.maximum(self.z0 - P[:, 2], P[:, 2] - self.z1)
        return np.where(dz > 0, np.sqrt(np.maximum(d, 0) ** 2 + dz * dz) * np.where(d > 0, 1, 1) + np.minimum(d, 0), d)


class Op:
    __slots__ = ("kind", "prim", "k", "tag", "part")

    def __init__(self, kind, prim, k, tag, part):
        self.kind, self.prim, self.k, self.tag, self.part = kind, prim, k, tag, part


class Field:
    def __init__(self):
        self.ops = []

    def add(self, prim, k=0.02, tag="body", part=None):
        self.ops.append(Op("add", prim, k, tag, part))
        return prim

    def sub(self, prim, k=0.01, tag="cut"):
        self.ops.append(Op("sub", prim, k, tag, None))
        return prim

    def bounds(self, pad=0.05):
        lo = np.min([o.prim.lo - o.k for o in self.ops if o.kind == "add"], axis=0) - pad
        hi = np.max([o.prim.hi + o.k for o in self.ops if o.kind == "add"], axis=0) + pad
        return lo, hi

    def _sel(self, lo, hi, pad):
        return [o for o in self.ops if np.all(o.prim.hi + o.k * 0.5 + pad >= lo) and np.all(o.prim.lo - o.k * 0.5 - pad <= hi)]

    def eval(self, P, ops=None):
        d = np.full(len(P), 1e3, dtype=np.float32)
        for o in (self.ops if ops is None else ops):
            dd = o.prim(P)
            d = smin(d, dd, o.k) if o.kind == "add" else smax(d, -dd, o.k)
        return d

    def eval_culled(self, P, pad=0.05):
        """Evaluate at an arbitrary point cloud in chunks, each with only the primitives near it."""
        out = np.empty(len(P), dtype=np.float32)
        order = np.argsort(P[:, 0] // 0.12 * 1000 + P[:, 2] // 0.12)       # spatially coherent chunks
        for i in range(0, len(P), 20000):
            idx = order[i:i + 20000]
            Q = P[idx]
            ops = self._sel(Q.min(0), Q.max(0), pad)
            out[idx] = self.eval(Q, ops) if ops else 1e3
        return out

    def tag_dist(self, P, tag, pad=0.1):
        """Smooth-union distance of the primitives carrying `tag` only (for regions / materials)."""
        ops = [o for o in self.ops if o.kind == "add" and o.tag == tag]
        d = np.full(len(P), 1e3, dtype=np.float32)
        order = np.argsort(P[:, 0] // 0.12 * 1000 + P[:, 2] // 0.12)
        for i in range(0, len(P), 20000):
            idx = order[i:i + 20000]
            Q = P[idx]
            sel = [o for o in ops if np.all(o.prim.hi + pad >= Q.min(0)) and np.all(o.prim.lo - pad <= Q.max(0))]
            dd = np.full(len(Q), 1e3, dtype=np.float32)
            for o in sel:
                dd = smin(dd, o.prim(Q), min(o.k, 0.01))
            d[idx] = dd
        return d


# --- meshing -------------------------------------------------------------------------------------------

def sample(F, h, B=16, pad=0.03, log=print):
    """Sparse-sample the Field on a grid of spacing h. Returns (D, origin): a dense float32 corner grid
    that is exact near the surface and +/-1 sign-filled elsewhere."""
    lo, hi = F.bounds(pad)
    n = np.ceil((hi - lo) / h).astype(int) + 2
    nb = np.ceil(n / B).astype(int)
    n = nb * B
    D = np.ones(n + 1, dtype=np.float32)
    half = B * h * math.sqrt(3.0) * 0.5
    cen = np.stack(np.meshgrid(*[lo[a] + (np.arange(nb[a]) + 0.5) * B * h for a in range(3)], indexing="ij"), -1).reshape(-1, 3).astype(np.float32)
    dc = np.empty(len(cen), dtype=np.float32)
    for i in range(0, len(cen), 4000):
        dc[i:i + 4000] = F.eval_culled(cen[i:i + 4000], pad=half * 1.4 + 0.05)
    dc = dc.reshape(nb)
    inside = dc < -half * 1.35
    surf = np.abs(dc) <= half * 1.35
    log("SDF grid", tuple(n), "blocks", int(np.prod(nb)), "surface", int(surf.sum()))
    ii = np.argwhere(inside)
    for b in ii:
        D[b[0] * B:(b[0] + 1) * B + 1, b[1] * B:(b[1] + 1) * B + 1, b[2] * B:(b[2] + 1) * B + 1] = -1.0
    ar = np.arange(B + 1, dtype=np.float32) * h
    for b in np.argwhere(surf):
        o0 = lo + b * B * h
        X, Y, Z = np.meshgrid(o0[0] + ar, o0[1] + ar, o0[2] + ar, indexing="ij")
        P = np.stack([X.ravel(), Y.ravel(), Z.ravel()], 1).astype(np.float32)
        ops = F._sel(P.min(0), P.max(0), 0.04)
        d = F.eval(P, ops) if ops else np.full(len(P), 1e3, dtype=np.float32)
        D[b[0] * B:(b[0] + 1) * B + 1, b[1] * B:(b[1] + 1) * B + 1, b[2] * B:(b[2] + 1) * B + 1] = d.reshape(B + 1, B + 1, B + 1)
    return D, lo.astype(np.float32)


def _trilinear(D, g):
    """Value and gradient of the corner grid at fractional grid points g (N,3)."""
    n = np.array(D.shape) - 2
    g = np.clip(g, 0.0, n.astype(np.float32) + 0.999)
    i = np.floor(g).astype(np.int64)
    f = (g - i).astype(np.float32)
    x, y, z = i[:, 0], i[:, 1], i[:, 2]
    c000, c100, c010, c110 = D[x, y, z], D[x + 1, y, z], D[x, y + 1, z], D[x + 1, y + 1, z]
    c001, c101, c011, c111 = D[x, y, z + 1], D[x + 1, y, z + 1], D[x, y + 1, z + 1], D[x + 1, y + 1, z + 1]
    fx, fy, fz = f[:, 0], f[:, 1], f[:, 2]
    c00 = c000 * (1 - fx) + c100 * fx
    c10 = c010 * (1 - fx) + c110 * fx
    c01 = c001 * (1 - fx) + c101 * fx
    c11 = c011 * (1 - fx) + c111 * fx
    c0 = c00 * (1 - fy) + c10 * fy
    c1 = c01 * (1 - fy) + c11 * fy
    v = c0 * (1 - fz) + c1 * fz
    gx = ((c100 - c000) * (1 - fy) + (c110 - c010) * fy) * (1 - fz) + ((c101 - c001) * (1 - fy) + (c111 - c011) * fy) * fz
    gy = (c10 - c00) * (1 - fz) + (c11 - c01) * fz
    gz = c1 - c0
    return v, np.stack([gx, gy, gz], 1)


def surface_nets(D, origin, h, relax=3, log=print):
    """Quads (N,4) and vertices (M,3) of the D==0 surface. Vertices are cell means of the edge
    crossings, then projected onto the iso-surface (trilinear) a few times."""
    s = D < 0.0
    cells = np.array(D.shape) - 1
    cs = [cells[1] * cells[2], cells[2], 1]
    ids, offs, crossings = [], [], []
    edges = []
    for a in range(3):
        sl0 = [slice(None)] * 3
        sl1 = [slice(None)] * 3
        sl0[a] = slice(0, -1)
        sl1[a] = slice(1, None)
        m = s[tuple(sl0)] != s[tuple(sl1)]
        # restrict to edges whose 4 cells exist
        idx = np.argwhere(m)
        u, v = (a + 1) % 3, (a + 2) % 3
        ok = (idx[:, u] >= 1) & (idx[:, u] < cells[u]) & (idx[:, v] >= 1) & (idx[:, v] < cells[v]) & (idx[:, a] < cells[a])
        idx = idx[ok]
        d0 = D[tuple(idx.T)]
        i1 = idx.copy()
        i1[:, a] += 1
        d1 = D[tuple(i1.T)]
        t = d0 / (d0 - d1)
        pt = idx.astype(np.float32)
        pt[:, a] += t
        edges.append((a, idx, pt, d0 < 0.0))
    acc = {}
    lin_all, pt_all = [], []
    for a, idx, pt, neg in edges:
        u, v = (a + 1) % 3, (a + 2) % 3
        for du in (-1, 0):
            for dv in (-1, 0):
                c = idx.copy()
                c[:, u] += du
                c[:, v] += dv
                lin_all.append(c @ np.array(cs))
                pt_all.append(pt)
    lin = np.concatenate(lin_all)
    pts = np.concatenate(pt_all)
    uniq, inv = np.unique(lin, return_inverse=True)
    cnt = np.bincount(inv, minlength=len(uniq)).astype(np.float32)
    V = np.stack([np.bincount(inv, weights=pts[:, k], minlength=len(uniq)) for k in range(3)], 1).astype(np.float32) / cnt[:, None]
    quads = []
    for a, idx, pt, neg in edges:
        u, v = (a + 1) % 3, (a + 2) % 3
        cl = []
        for du, dv in ((-1, -1), (0, -1), (0, 0), (-1, 0)):
            c = idx.copy()
            c[:, u] += du
            c[:, v] += dv
            cl.append(np.searchsorted(uniq, c @ np.array(cs)))
        q = np.stack(cl, 1)
        # orient: normal toward outside (positive D)
        q = np.where(neg[:, None], q, q[:, ::-1])
        # axis parity of the (a,u,v) frame is always cyclic, so one flip rule suffices
        quads.append(q)
    quads = np.concatenate(quads).astype(np.int64)
    for _ in range(relax):
        val, gr = _trilinear(D, V)
        gl = (gr * gr).sum(1) + 1e-12
        V = V - (val / gl)[:, None] * gr * 0.9
    P = origin + V * h
    log("surface nets: verts", len(P), "quads", len(quads))
    return P.astype(np.float32), quads


def mesh(F, voxel=0.005, B=16, relax=3, log=print):
    D, origin = sample(F, voxel, B, log=log)
    return surface_nets(D, origin, voxel, relax, log)


# --- noise ---------------------------------------------------------------------------------------------

def _hash3(i, j, k, seed=0):
    h = (i * 374761393 + j * 668265263 + k * 2147483647 + seed * 1274126177) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    h = h ^ (h >> 16)
    return (h & 0xFFFFFF).astype(np.float32) / 16777215.0


def vnoise(P, freq=1.0, seed=0):
    """Value noise in [0,1]."""
    q = P * freq
    i = np.floor(q).astype(np.int64)
    f = (q - i).astype(np.float32)
    f = f * f * (3.0 - 2.0 * f)
    out = 0.0
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                w = (f[:, 0] if dx else 1 - f[:, 0]) * (f[:, 1] if dy else 1 - f[:, 1]) * (f[:, 2] if dz else 1 - f[:, 2])
                out = out + w * _hash3(i[:, 0] + dx, i[:, 1] + dy, i[:, 2] + dz, seed)
    return out


def fbm(P, freq=1.0, octaves=4, seed=0, gain=0.5):
    out = np.zeros(len(P), dtype=np.float32)
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        out += amp * vnoise(P, freq * (2 ** o), seed + o * 17)
        tot += amp
        amp *= gain
    return out / tot


def voronoi(P, freq=1.0, seed=0, chunk=120000):
    """F1, F2 distances (in cell units) of a 3D cellular noise, vectorised over 27 neighbours."""
    f1 = np.empty(len(P), dtype=np.float32)
    f2 = np.empty(len(P), dtype=np.float32)
    for s0 in range(0, len(P), chunk):
        q = P[s0:s0 + chunk] * freq
        i = np.floor(q).astype(np.int64)
        d1 = np.full(len(q), 9.0, dtype=np.float32)
        d2 = np.full(len(q), 9.0, dtype=np.float32)
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                for dz in (-1, 0, 1):
                    c = i + np.array([dx, dy, dz])
                    jit = np.stack([_hash3(c[:, 0], c[:, 1], c[:, 2], seed + 31 * k) for k in range(3)], 1)
                    dd = np.sqrt(((c + jit - q) ** 2).sum(1))
                    m1 = dd < d1
                    d2 = np.where(m1, d1, np.minimum(d2, dd))
                    d1 = np.where(m1, dd, d1)
        f1[s0:s0 + chunk], f2[s0:s0 + chunk] = d1, d2
    return f1, f2
