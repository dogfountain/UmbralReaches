"""The common enemies built the way the wanderer and the bosses are now: clean garment and plate geometry in tiling
materials (boss_look.gd), vertex-colour tints, glow painted in, faces as hoods, masks and helms with lit eyes.
No sculpted blobs, no baked atlas. Each kind is skinned to the flat socket armature its procedural rig drives
(HunchRig for the two-legged ones), so the game's animation carries it unchanged (grunt_skin.gd).

    tools/blender/run.sh grunt_build.py -- [--only wretch,husk] [--look <dir>]

Writes art/models/grunt_<kind>.glb. Rig space: x right, y up, z back, facing -Z, metres.
"""
import bpy
import math
import os
import sys
import numpy as np
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import boss_build as B
from boss_build import Geo, V, TAU

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(name, default=None):
    return ARGS[ARGS.index(name) + 1] if name in ARGS else default


def bl(p):
    return Vector((p[0], -p[2], p[1]))


SOCK = {"pelvis": V(0, 0.94, 0), "chest": V(0, 1.28, 0), "head": V(0, 1.64, 0)}
for _t, _sx in (("l", -1), ("r", 1)):
    SOCK.update({"shoulder_" + _t: V(_sx * 0.24, 1.40, 0), "elbow_" + _t: V(_sx * 0.24, 1.08, 0), "hand_" + _t: V(_sx * 0.24, 0.78, 0),
                 "hip_" + _t: V(_sx * 0.11, 0.75, 0), "knee_" + _t: V(_sx * 0.11, 0.33, 0), "foot_" + _t: V(_sx * 0.11, -0.09, 0)})


def side(sx):
    return "l" if sx < 0 else "r"


# --- shared parts --------------------------------------------------------------------------------------

def legs(g, col, mat="wool", boot=(0.16, 0.12, 0.1), boot_mat="leather", r=(0.075, 0.06, 0.05)):
    for sx in (-1, 1):
        t = side(sx)
        g.tube([V(sx * 0.11, 0.98, 0.0), V(sx * 0.11, 0.75, 0.0), V(sx * 0.11, 0.55, -0.01)], [r[0] * 1.15, r[0], r[0] * 0.92], col, mat, "hip_" + t, n=12)
        g.tube([V(sx * 0.11, 0.55, -0.01), V(sx * 0.11, 0.33, -0.02), V(sx * 0.11, 0.06, 0.0)], [r[1] * 1.08, r[1], r[2]], col, mat, "knee_" + t, n=12)
        g.box(V(sx * 0.11, -0.035, -0.04), (0.055, 0.045, 0.1), boot, boot_mat, "foot_" + t)
        g.lathe([(r[2] * 1.4, 0.0), (r[2] * 1.5, 0.05), (r[2] * 1.25, 0.12)], V(sx * 0.11, 0.02, 0.0), boot, boot_mat, "foot_" + t, n=12)


def arms(g, col, mat="wool", r=(0.055, 0.045, 0.035)):
    for sx in (-1, 1):
        t = side(sx)
        g.tube([V(sx * 0.2, 1.43, 0.0), V(sx * 0.24, 1.36, 0.0), V(sx * 0.24, 1.2, 0.0), V(sx * 0.24, 1.08, 0.0)], [r[0] * 1.3, r[0] * 1.1, r[0], r[0] * 0.9], col, mat, "shoulder_" + t, n=12)
        g.tube([V(sx * 0.24, 1.08, 0.0), V(sx * 0.24, 0.92, -0.01), V(sx * 0.24, 0.8, 0.0)], [r[1], r[1] * 0.95, r[2]], col, mat, "elbow_" + t, n=12)


def hood(g, col, dark=(0.015, 0.015, 0.02), eye=(1.0, 0.6, 0.25, 0.0), peak=0.0, open_=38, low=1.48, eye_r=0.015, face_y=1.7, face=True):
    if getattr(g, "_fit", None) is not None:
        return cowl(g, g._fit[0], col, peak=peak, open_w=0.065 + 0.0006 * (open_ - 38))
    rings = [(low, 0.2, 0.17, 0.02), (low + 0.1, 0.18, 0.16, 0.015), (1.7, 0.165, 0.17, 0.0), (1.82, 0.15, 0.165, 0.008), (1.9, 0.11, 0.13, 0.025),
             (1.95 + peak * 0.5, 0.05, 0.07, 0.04 + peak * 0.3), (1.97 + peak, 0.01, 0.015, 0.05 + peak * 0.6)]
    g.robe(rings, col, "wool", lambda p: "head" if p[1] > 1.58 else "chest", n=40, t0=math.radians(open_), t1=TAU - math.radians(open_), pleats=6, pleat_amp=0.04)
    if face:                                                             # no body under it: a void with two coals
        g.ball(V(0.0, face_y, 0.0), 0.128, dark, "iron", "head", n=10, sy=1.12)
        B.eyes(g, face_y + 0.015, -0.115, 0.045, eye_r, eye)


def mantle(g, col, trim=None, y0=1.56, y1=1.16, r1=0.36, tatter=0.04):
    if getattr(g, "_fit", None) is not None:          # a body to lay it on: a shawl over the shoulders, closed, torn at the hem
        O = shawl(g, g._fit[0], col, y_low=y1, gap=(0.0, 0.0), seed=r1 * 10.0, tatter=max(tatter, 0.02), flare=0.05 + (r1 - 0.28) * 0.4)
        return
    rings = [(y0, 0.2, 0.15, 0.01), (y0 - 0.06, 0.28, 0.19, 0.01), (y0 - 0.16, 0.32, 0.22, 0.02), ((y0 + y1) * 0.5 - 0.1, r1 * 0.95, r1 * 0.7, 0.03), (y1, r1, r1 * 0.75, 0.03)]
    g.robe(rings, col, "wool", "chest", n=60, pleats=8, pleat_amp=0.05, pleat_from=y0 - 0.06, tatter=tatter)
    if trim:
        g.ring_band(y1 + 0.02, y1 + 0.07, r1 * 1.01, r1 * 0.76, 0.03, trim, "trim", "chest", n=60)


def robe_body(g, col, hem=0.05, waist=1.0, flare=0.4, pleats=16, amp=0.07, tatter=0.0, belt=None, trim=None):
    rings = [(1.5, 0.2, 0.14, 0.0), (1.38, 0.22, 0.155, 0.0), (1.22, 0.215, 0.16, 0.0), (waist + 0.04, 0.19, 0.15, 0.0), (waist, 0.19, 0.145, 0.0),
             (waist - 0.15, 0.2 + flare * 0.1, 0.16 + flare * 0.1, 0.0), (0.55, 0.22 + flare * 0.3, 0.19 + flare * 0.3, 0.01), (hem + 0.15, 0.25 + flare * 0.45, 0.22 + flare * 0.45, 0.02),
             (hem, 0.26 + flare * 0.5, 0.23 + flare * 0.5, 0.02)]
    g.robe(rings, col, "wool", B.waist_split(waist - 0.02), n=96, pleats=pleats, pleat_amp=amp, pleat_from=waist, tatter=tatter, hem_break=0.02 if hem < 0.06 else 0.0)
    if belt:
        g.ring_band(waist - 0.02, waist + 0.05, 0.178, 0.138, 0.0, belt, "leather", "chest", n=48)
    if trim:
        r = rings[-2]
        g.ring_band(hem + 0.04, hem + 0.12, r[1] * 1.03, r[2] * 1.03, r[3], trim, "trim", "pelvis", n=96)
    return rings


_BODY = None                       # the last human() built: straps lie on it and garments are kept off its skin (fit)
FIT_MATS = ("wool", "linen", "leather", "trim", "rope", "fur", "cloth")


def _body_tree(b):
    if getattr(b, "_kd", None) is None:
        from mathutils.kdtree import KDTree
        kd = KDTree(len(b.P))
        for i, q in enumerate(b.P):
            kd.insert(Vector((float(q[0]), float(q[1]), float(q[2]))), i)
        kd.balance()
        b._kd = kd
    return b._kd


def strap(g, pts, col, lab="chest", w=0.035, thick=0.007, off=0.006):
    """A leather strap with thickness, laid on the skin: the path is walked every 2 cm and each point that comes
    within 12 cm of the body is set on its surface (lifted off + half the thickness), so it cuts into the shoulder
    instead of standing off it as a card. Where it leaves the body (to a sack, a lid) it keeps the given path."""
    path, ups = [], []
    for a, c in zip(pts, pts[1:]):
        k = max(int(float(np.linalg.norm(c - a)) / 0.02), 1)
        for j in range(k):
            path.append(a + (c - a) * (j / k))
    path.append(pts[-1])
    b = _BODY
    if b is not None and getattr(b, "_kd_nohead", None) is None:
        from mathutils.kdtree import KDTree
        ids = [i for i in range(len(b.P)) if b.L[i] != "head"]
        kd = KDTree(len(ids))
        for i in ids:
            kd.insert(Vector((float(b.P[i][0]), float(b.P[i][1]), float(b.P[i][2]))), i)
        kd.balance()
        b._kd_nohead = kd
    for i, p in enumerate(path):
        up = V(0, 0, -1) if p[2] < 0 else V(0, 0, 1)
        if b is not None:
            _, idx, d = b._kd_nohead.find(Vector((float(p[0]), float(p[1]), float(p[2]))))   # never onto the face
            if d < 0.19:
                up = b.N[idx]
                path[i] = b.P[idx] + up * (off + thick * 0.5)
        ups.append(np.asarray(up, dtype=np.float64))
    # relax the walk (nearest-vertex steps are lumpy), ends held
    for _ in range(3):
        path = [path[0]] + [path[k - 1] * 0.25 + path[k] * 0.5 + path[k + 1] * 0.25 for k in range(1, len(path) - 1)] + [path[-1]]
    rings = []
    for k in range(len(path)):
        t = path[min(k + 1, len(path) - 1)] - path[max(k - 1, 0)]
        t /= max(np.linalg.norm(t), 1e-9)
        nrm = ups[k] - t * float(t @ ups[k])
        nrm /= max(np.linalg.norm(nrm), 1e-9)
        acr = np.cross(t, nrm)
        hw, ht = w * 0.5, thick * 0.5
        rings.append([path[k] + acr * hw + nrm * ht, path[k] - acr * hw + nrm * ht, path[k] - acr * (hw + ht * 0.6),
                      path[k] - acr * hw - nrm * ht, path[k] + acr * hw - nrm * ht, path[k] + acr * (hw + ht * 0.6)][::-1])
    us = [0.0]
    for k in range(1, len(path)):
        us.append(us[-1] + float(np.linalg.norm(path[k] - path[k - 1])))
    g.grid(rings, col, "leather", lab, lambda i, j, p: (j * w / 6.0, us[i]), wrap=True)


def _bvh(b, labels):
    key = tuple(sorted(labels))
    cache = b.__dict__.setdefault("_bvhs", {})
    if key not in cache:
        from mathutils.bvhtree import BVHTree
        F = [f for f in b.F if all(b.L[v] in labels for v in f)]
        cache[key] = BVHTree.FromPolygons([Vector((float(q[0]), float(q[1]), float(q[2]))) for q in b.P], F, all_triangles=False)
    return cache[key]


def shrink(g, b, labels, rows, off, col, mat, lab, thick=0.008, edge=None, reach=0.6, cut=None, relax=2, fill=False, balls=(), ridges=None, wobble=None, clip=None):
    """Cloth as a clean quad sheet laid on the body: rows[i][j] = (origin, direction) rays cast from inside the
    part (BVH of the faces whose corners are all in `labels`); each lands `off` along the surface normal. The sheet
    keeps its own even grid, so its rims are clean lines (a hem, a slit) instead of the body's triangle saw.
    edge(i, j) -> False drops a quad (a tear, an eye slit). Given thickness with a rolled rim like wear()."""
    tree = _bvh(b, labels)
    # each sheet point lives on its ray: t = distance out from the origin. Land on the skin (t >= hit + off), then
    # drape: smooth t toward the neighbours a few times, never below the skin, so the cloth bridges a nose, lips and
    # the hollows between ribs the way stretched cloth does instead of tracing them
    T, Tmin, Nn, O3, D3 = [], [], [], [], []
    under = []
    for row in rows:
        tr, mr, nr, orow, drow = [], [], [], [], []
        for o, d in row:
            o3 = Vector((float(o[0]), float(o[1]), float(o[2])))
            d3 = Vector((float(d[0]), float(d[1]), float(d[2]))).normalized()
            hit, nrm, _, dist = tree.ray_cast(o3 + d3 * reach, -d3, reach)   # outside in (from inside, a head's mouth bag is hit first)
            orow.append(np.array(o3[:]))
            drow.append(np.array(d3[:]))
            if hit is None:
                tr.append(None)
                mr.append(None)
                nr.append(None)
                continue
            n = np.array(nrm[:]) if nrm.dot(d3) > 0 else -np.array(nrm[:])
            n = n * 0.35 + np.array(d3[:]) * 0.65
            n /= max(np.linalg.norm(n), 1e-9)
            t = reach - dist + (off(o, d) if callable(off) else off)
            if t - (reach - dist) < 0.03:
                under.append(hit)
            for bc, br in balls:                    # things on the skin the cloth must also clear (the eye coals)
                oc = np.array(o3[:]) - bc
                dd = np.array(d3[:])
                bq = float(oc @ dd)
                disc = bq * bq - (float(oc @ oc) - br * br)
                if disc > 0.0:
                    t = max(t, -bq + math.sqrt(disc) + (off(o, d) if callable(off) else off))
            tr.append(t)
            mr.append(t)
            nr.append(n)
        T.append(tr)
        Tmin.append(mr)
        Nn.append(nr)
        O3.append(orow)
        D3.append(drow)
    ni, nj = len(T), len(T[0])
    if fill:
        # a band round the trunk: where a ray found no trunk (the armpit, between the arm and the ribs) the cloth
        # bridges from its neighbours along the row
        for i in range(ni):
            ok = [j for j in range(nj) if T[i][j] is not None]
            if not ok:
                continue
            for j in range(nj):
                if T[i][j] is not None:
                    continue
                a = max([k for k in ok if k < j], default=ok[-1] - nj)
                c = min([k for k in ok if k > j], default=ok[0] + nj)
                ta, tc = T[i][a % nj], T[i][c % nj]
                w = (j - a) / max(c - a, 1)
                T[i][j] = Tmin[i][j] = ta + (tc - ta) * w
                Nn[i][j] = D3[i][j]
    for _ in range(relax):
        T2 = [r[:] for r in T]
        for i in range(ni):
            for j in range(nj):
                if T[i][j] is None:
                    continue
                nb = [T[a][k] for a, k in ((i - 1, j), (i + 1, j), (i, j - 1), (i, j + 1)) if 0 <= a < ni and 0 <= k < nj and T[a][k] is not None]
                if nb:
                    T2[i][j] = max(T[i][j] * 0.4 + sum(nb) / len(nb) * 0.6, Tmin[i][j])
        T = T2
    if ridges:
        # wound cloth: bands of rows stand proud of the ones they overlap (after the drape, so they stay crisp),
        # each band's lower rows lifted most, as one turn laps over the next; the bands drift round the head
        per, amp = ridges
        for i in range(ni):
            for j in range(nj):
                if T[i][j] is not None:
                    k = (i + j * 0.12) % per
                    T[i][j] += amp * (k / per) ** 1.5
    if wobble:
        for i in range(ni):
            for j in range(nj):
                if T[i][j] is not None:
                    T[i][j] += wobble(i, j, ni, nj)
    P = [[(O3[i][j] + D3[i][j] * T[i][j]) if T[i][j] is not None else None for j in range(nj)] for i in range(ni)]
    if clip is not None:
        # a hem as a line: each column ends where it crosses clip(point) (its own torn height), the crossing point set
        # exactly on it and the rest of the column dropped; dropping whole quads gave a stair
        for j in range(nj):
            for i in range(1, ni):
                a, c = P[i - 1][j], P[i][j]
                if a is None or c is None:
                    continue
                ya, yc = clip(a), clip(c)
                if a[1] >= ya and c[1] < yc:
                    t = (a[1] - ya) / max(a[1] - ya - (c[1] - yc), 1e-9)
                    P[i][j] = a + (c - a) * t
                    for k in range(i + 1, ni):
                        P[k][j] = None
                    break
    vid, VO, VN = {}, [], []
    F, FU = [], []
    for i in range(ni - 1):
        for j in range(nj - 1):
            c = [(i, j), (i, j + 1), (i + 1, j + 1), (i + 1, j)]
            if any(P[a][k] is None for a, k in c) or (edge is not None and not edge(i, j)):
                continue
            if cut is not None and cut(sum(P[a][k] for a, k in c) * 0.25):
                continue
            f = []
            for a, k in c:
                if (a, k) not in vid:
                    vid[(a, k)] = len(VO)
                    VO.append(P[a][k])
                    VN.append(Nn[a][k])
                f.append(vid[(a, k)])
            F.append(f[::-1])
            FU.append([(k * 0.02, a * 0.02) for a, k in c][::-1])
    if not F:
        return
    O = np.array(VO)
    In = O - np.array(VN) * thick
    n = len(O)
    cnt = {}
    for f in F:
        for a, c in zip(f, f[1:] + f[:1]):
            cnt[(a, c)] = cnt.get((a, c), 0) + 1
    F2 = F + [[v + n for v in f[::-1]] for f in F]
    FU2 = FU + [list(u[::-1]) for u in FU]
    for (a, c) in list(cnt):
        if (c, a) not in cnt:
            F2.append([c, a, a + n, c + n])
            FU2.append([(0.0, 0.0), (thick * 4, 0.0), (thick * 4, thick * 4), (0.0, thick * 4)])
    if under and cut is None:                       # (a garment with an opening shows what is under it: leave that be)
        kd = _body_tree(b)
        tuck(g, b, {kd.find(h)[1] for h in under}, depth=0.01)
    k0 = len(g.v)
    g.mesh(np.concatenate([O, In]), F2, col, mat, lab, FU2)
    g.__dict__.setdefault("_laid", []).append((k0, len(g.v)))     # already on the skin: fit() leaves it be
    return O


def tuck(g, b, idx, depth=0.012):
    """Draw the body in under its clothes: the body vertices `idx` move `depth` inward along the skin's normal, so a
    tight garment is not pierced by the skin when the two are posed (the skin moves with more joints than the cloth)."""
    if getattr(g, "_fit", None) is None or g._fit[0] is not b:
        return
    n0 = g._fit[1] - len(b.P)
    done = g.__dict__.setdefault("_tucked", set())
    for k in idx:
        if k not in done:
            done.add(k)
            g.v[n0 + k] = g.v[n0 + k] - b.N[k] * depth


def _centre(b, y, labels, band=0.02):
    pts = [b.P[i] for i in range(len(b.P)) if b.L[i] in labels and abs(b.P[i][1] - y) < band]
    if not pts:
        return None
    return np.array([float(np.mean([q[0] for q in pts])), y, float(np.mean([q[2] for q in pts]))])


def dome_rays(c, nu, nv, v0, v1):
    """Rays from c over a sphere: u round (0 at the back, +x), v from v0 (0 = crown) to v1 (pi = under the chin)."""
    rows = []
    for i in range(nv + 1):
        v = v0 + (v1 - v0) * i / nv
        rows.append([(c, V(math.sin(v) * math.sin(TAU * j / nu), math.cos(v), math.sin(v) * math.cos(TAU * j / nu))) for j in range(nu + 1)])
    return rows


def band_rays(b, labels, y0, y1, nu, nv, t0=0.0, t1=TAU, hem=None):
    """Horizontal rays round one vertical axis (the part's mean over y0..y1: one axis, so rows drape together).
    hem(angle) -> dy: each column starts that much above y0 (a torn hem as a clean line, not dropped quads)."""
    pts = [b.P[i] for i in range(len(b.P)) if b.L[i] in labels and y0 - 0.02 < b.P[i][1] < y1 + 0.02]
    if not pts:
        return []
    cx, cz = float(np.mean([q[0] for q in pts])), float(np.mean([q[2] for q in pts]))
    rows = []
    for i in range(nv + 1):
        row = []
        for j in range(nu + 1):
            a = t0 + (t1 - t0) * j / nu
            ya = y0 + (hem(a) if hem else 0.0)
            y = ya + (y1 - ya) * i / nv
            row.append((np.array([cx, y, cz]), V(math.sin(a), 0.0, math.cos(a))))
        rows.append(row)
    return rows


def fit(g, off=0.004, reach=0.12):
    """Keep the garments off the skin: any cloth or leather vertex added after the body that lies under the skin
    (or within `off` of it) is pushed out along the skin's normal. Hand-placed robes and belts were ellipses that cut
    into a MakeHuman body here and stood off it there; the inside half is what showed as torn cloth."""
    fb = getattr(g, "_fit", None)
    if fb is None:
        return
    b, start = fb
    kd = _body_tree(b)
    vm = {}
    for f, m in zip(g.faces, g.fmat):
        for v in f:
            vm[v] = m
    cen = {}
    for l in set(b.L):
        q = b.P[[i for i in range(len(b.P)) if b.L[i] == l]]
        cen[l] = q.mean(axis=0)
    moved = 0
    laid = getattr(g, "_laid", [])
    for i in range(start, len(g.v)):
        if vm.get(i) not in FIT_MATS or any(a <= i < c for a, c in laid):
            continue
        p = g.v[i]
        _, idx, d = kd.find(Vector((float(p[0]), float(p[1]), float(p[2]))))
        if d > reach:
            continue
        if float(b.N[idx] @ (b.P[idx] - cen[b.L[idx]])) <= 0.0:
            continue                             # an inward normal (an eye socket, the mouth): it would pull cloth in
        s = float((p - b.P[idx]) @ b.N[idx])
        if s < off:
            g.v[i] = p + b.N[idx] * (off - s)
            moved += 1
    print("FIT %d garment vertices lifted off the skin" % moved)


_to_object = Geo.to_object


def _fit_to_object(self, name, *a, **kw):
    fit(self)
    return _to_object(self, name, *a, **kw)


Geo.to_object = _fit_to_object


# --- an organic body (Skin modifier base mesh), skinned to the HunchRig sockets -------------------------

SEGS = [("pelvis", V(0, 0.9, 0), V(0, 1.12, 0)), ("chest", V(0, 1.12, 0), V(0, 1.56, 0)), ("head", V(0, 1.56, 0), V(0, 1.95, 0))]
for _t, _sx in (("l", -1), ("r", 1)):
    SEGS += [("hip_" + _t, V(_sx * 0.11, 0.8, 0), V(_sx * 0.11, 0.36, 0)), ("knee_" + _t, V(_sx * 0.11, 0.36, 0), V(_sx * 0.11, -0.05, 0)),
             ("foot_" + _t, V(_sx * 0.11, -0.05, 0), V(_sx * 0.11, -0.08, -0.16)), ("shoulder_" + _t, V(_sx * 0.18, 1.42, 0), V(_sx * 0.24, 1.08, 0)),
             ("elbow_" + _t, V(_sx * 0.24, 1.08, 0), V(_sx * 0.24, 0.8, 0)), ("hand_" + _t, V(_sx * 0.24, 0.8, 0), V(_sx * 0.24, 0.62, 0))]


def body_label(p):
    best, bd = "chest", 9.0
    for nm, a, b in SEGS:
        ab = b - a
        t = min(max(float((p - a) @ ab) / max(float(ab @ ab), 1e-9), 0.0), 1.0)
        d = float(np.linalg.norm(p - (a + ab * t)))
        if d < bd:
            best, bd = nm, d
    return best


def body(g, col, mat="leather", girth=1.0, belly=0.0, limb=1.0, head=1.0, neck=1.0, ribs=0.0, hands=True, feet=True):
    """A whole body in one surface: pelvis, spine, ribcage, neck, skull, arms to the wrists and legs to the ankles,
    at the rig's rest sockets. girth scales the trunk, limb the arms and legs, belly pushes the gut out."""
    N, E = [], []

    def n(p, rx, ry):
        N.append((p, rx, ry))
        return len(N) - 1

    def chain(pts, a=None):
        prev = a
        for (p, rx, ry) in pts:
            i = n(p, rx, ry)
            if prev is not None:
                E.append((prev, i))
            prev = i
        return prev

    pel = n(V(0, 0.92, 0.0), 0.15 * girth, 0.11 * girth)
    sp = chain([(V(0, 1.06, -0.03 * belly), (0.14 + 0.1 * belly) * girth, (0.11 + 0.12 * belly) * girth), (V(0, 1.22, -0.01), (0.15 + 0.04 * belly) * girth, (0.1 + 0.05 * belly) * girth),
                (V(0, 1.38, 0.0), 0.17 * girth, 0.11 * girth), (V(0, 1.48, 0.01), 0.15 * girth, 0.095 * girth)], pel)
    nk = chain([(V(0, 1.57, 0.0), 0.05 * neck, 0.05 * neck), (V(0, 1.62, -0.01), 0.055 * neck, 0.055 * neck)], sp)
    chain([(V(0, 1.7, -0.02), 0.085 * head, 0.1 * head), (V(0, 1.78, -0.01), 0.09 * head, 0.105 * head), (V(0, 1.84, 0.0), 0.06 * head, 0.075 * head)], nk)
    chain([(V(0, 1.63, -0.07), 0.04 * head, 0.03 * head), (V(0, 1.66, -0.12 * head), 0.03 * head, 0.025 * head)], nk)      # the jaw and muzzle
    for sx in (-1, 1):
        sh = n(V(sx * 0.13, 1.47, 0.01), 0.07 * girth, 0.06 * girth)
        E.append((sp, sh))
        chain([(V(sx * 0.22, 1.43, 0.0), 0.06 * limb, 0.055 * limb), (V(sx * 0.24, 1.26, 0.0), 0.045 * limb, 0.045 * limb), (V(sx * 0.24, 1.08, 0.0), 0.035 * limb, 0.035 * limb),
               (V(sx * 0.24, 0.94, -0.01), 0.038 * limb, 0.034 * limb), (V(sx * 0.24, 0.8, 0.0), 0.026 * limb, 0.022 * limb)], sh)
        hp = n(V(sx * 0.1, 0.84, 0.0), 0.08 * girth, 0.08 * girth)
        E.append((pel, hp))
        chain([(V(sx * 0.11, 0.62, -0.01), 0.07 * limb, 0.07 * limb), (V(sx * 0.11, 0.36, -0.02), 0.045 * limb, 0.05 * limb), (V(sx * 0.11, 0.18, 0.01), 0.05 * limb, 0.05 * limb),
               (V(sx * 0.11, 0.0, 0.0), 0.03 * limb, 0.032 * limb)] + ([(V(sx * 0.11, -0.06, -0.06), 0.035, 0.022), (V(sx * 0.11, -0.07, -0.14), 0.032, 0.016)] if feet else []), hp)
    g.skin(N, E, col, mat, body_label, subdiv=2, smooth=0.6)
    if ribs > 0.0:                                                       # ribs standing out under the skin
        for k in range(6):
            y = 1.18 + 0.055 * k
            for sx in (-1, 1):
                g.tube([V(sx * 0.03, y, -0.115 * girth), V(sx * 0.13 * girth, y - 0.02, -0.085 * girth), V(sx * 0.16 * girth, y - 0.05, 0.0)], 0.009 * ribs, col, mat, "chest", n=5)
    if hands:
        for sx in (-1, 1):
            B.hand(g, sx, col, "hand_" + side(sx), closed=0.5)


def human(g, col, eye, macro=None, girth=1.0, limb=1.0, head=1.15, tris=9000, eye_r=0.011, mat="skin", shoulder_y=1.40, skull=0.0):
    """A MakeHuman body (mh_body.py), shaped by `macro` (gender, age, muscle, weight, proportions, height: 0..1),
    retargeted to the rig, with coals in the eyes. skull 0..1: the face wasted toward the bone beneath (cheeks and
    temples hollowed, lips drawn back off the teeth, the eyes sunk), with the teeth bared."""
    import mh_body
    P, F, eyes, FUV, L = mh_body.human(macro=macro, girth=girth, limb=limb, head=head, tris=tris, shoulder_y=shoulder_y)
    bd = Body(P, F, FUV, L)
    E = [e for e in eyes if e is not None]
    if skull > 0.0 and len(E) == 2:
        ey = (E[0][1] + E[1][1]) * 0.5
        ez = min(E[0][2], E[1][2])
        hw = abs(E[0][0] - E[1][0]) * 0.5
        mouth_y = ey - hw * 2.4
        Q = bd.P.copy()
        for i in range(len(Q)):
            if bd.L[i] != "head":
                continue
            p = Q[i]
            if p[2] > ez + 0.07:
                continue
            fwd = min(max((ez + 0.07 - p[2]) / 0.07, 0.0), 1.0)
            # cheeks and temples: in, between cheekbone and jaw, and beside the brow
            cheek = math.exp(-((p[1] - (ey - hw * 1.3)) / (hw * 0.9)) ** 2) * min(max((abs(p[0]) - hw * 0.5) / hw, 0.0), 1.0)
            temple = math.exp(-((p[1] - (ey + hw * 0.4)) / (hw * 0.7)) ** 2) * min(max((abs(p[0]) - hw * 1.3) / hw, 0.0), 1.0)
            # lips: drawn back off the teeth
            lip = math.exp(-((p[1] - mouth_y) / (hw * 0.45)) ** 2) * math.exp(-(p[0] / (hw * 1.1)) ** 2)
            # the sockets: sunk round each eye
            sock = sum(math.exp(-(np.linalg.norm((p - e)[:2]) / (hw * 0.55)) ** 2) for e in E)
            d = skull * fwd * (0.009 * cheek + 0.006 * temple + 0.004 * lip + 0.006 * sock)
            Q[i] = p - bd.N[i] * d
        bd.P = Q
        P = Q
        TOOTH = (0.72, 0.66, 0.5)
        front = {}
        for i in range(len(Q)):
            if bd.L[i] == "head" and abs(Q[i][1] - mouth_y) < 0.006 and abs(Q[i][0]) < hw:
                kx = int(round(Q[i][0] / (hw / 3.0)))
                if kx not in front or Q[i][2] < front[kx][2]:
                    front[kx] = Q[i]
        mz = min((q[2] for q in front.values()), default=ez - 0.02)
        lipz = lambda x: mz + abs(x / hw) ** 2 * hw * 0.5
        for row, dy in ((0, 0.005), (1, -0.007)):
            for k in range(7):
                a = (k - 3.0) / 3.0
                x = a * hw * 0.95
                z = lipz(x) - 0.002
                y = mouth_y + dy
                h = (0.009 if row == 0 else -0.008) * (1.0 - 0.3 * abs(a))
                g.tube([V(x, y, z), V(x, y - h * 1.3, z - 0.003)], [0.006 * skull, 0.0035 * skull], TOOTH, "bone", "head", n=5)
    g.mesh(P, F, col, mat, L, FUV)
    global _BODY
    _BODY = bd
    g._fit = (bd, len(g.v))
    for e in eyes:
        if e is not None:
            g.ball(e + V(0, 0, -0.004), eye_r, eye, "glow", "head", n=6)
    bd.eyes = [e for e in eyes if e is not None]
    return bd


class Body:
    """A built human kept for dressing: garments and armour are cut from its own surface (wear()), so they fit."""

    def __init__(self, P, F, FUV, L):
        self.P = np.asarray(P, dtype=np.float64)
        self.F = F
        self.FUV = FUV
        N = np.zeros_like(self.P)
        for f in F:
            for k in range(1, len(f) - 1):
                a, b, c = self.P[f[0]], self.P[f[k]], self.P[f[k + 1]]
                n = np.cross(b - a, c - a)
                N[f[0]] += n
                N[f[k]] += n
                N[f[k + 1]] += n
        N /= np.maximum(np.linalg.norm(N, axis=1, keepdims=True), 1e-12)
        ax = self.P.copy()
        ax[:, 0] = np.where(np.abs(self.P[:, 0]) > 0.19, np.sign(self.P[:, 0]) * 0.24, 0.0)    # limbs' own axes, roughly
        ax[:, 2] = 0.0
        if float(np.sum(N * (self.P - ax), axis=1).mean()) < 0.0:
            N = -N
        self.N = N
        self.L = list(L)


def contour(b, y, labels=("chest",), off=0.02, bins=32, band=0.025):
    """The body's cross-section at height y as a loop of points lifted `off` off the skin: [(angle, point)], angle
    0 at the back, +-pi at the front (atan2(x, z)). For ribs and straps that hug the torso instead of an ellipse."""
    pts = [(b.P[i], b.N[i]) for i in range(len(b.P)) if b.L[i] in labels and abs(b.P[i][1] - y) < band]
    if not pts:
        return []
    cz = float(np.mean([p[2] for p, _ in pts]))
    cx = float(np.mean([p[0] for p, _ in pts]))
    best = {}
    for p, nrm in pts:
        a = math.atan2(p[0] - cx, p[2] - cz)
        k = int((a + math.pi) / TAU * bins) % bins
        r = math.hypot(p[0] - cx, p[2] - cz)
        if k not in best or r > best[k][0]:
            best[k] = (r, p, nrm)
    out = []
    for k in sorted(best):
        r, p, nrm = best[k]
        q = p + nrm * off
        q = np.array([q[0], y, q[2]])
        out.append((math.atan2(q[0] - cx, q[2] - cz), q))
    return out


def line(b, labels, ys, ang, off=0.02):
    """A line down a limb's surface: at each height the contour point nearest the angle `ang` (0 back, pi front,
    + toward the rig's +x). For a bone laid along a shin or a strap down the chest."""
    out = []
    for y in ys:
        loop = contour(b, y, labels, off=off, band=0.03)
        if loop:
            out.append(min(loop, key=lambda t: abs(math.remainder(t[0] - ang, TAU)))[1])
    return out


def crust(g, b, sel, n, col, mat="bone", size=(0.02, 0.05), seed=1, lift=0.004, glow=None):
    """Growths that have taken the body over, the way the Shroud's take the Fell: a low mound fused into the skin
    (melted masses), and out of it a dense ruff of thin curled leaves standing off the body, dark at the root and
    pale at the lip, a few lit from beneath where they root (glow: an (r, g, b, 0) tint)."""
    rng = np.random.default_rng(seed)
    idx = [i for i in range(len(b.P)) if sel(b.P[i], b.L[i])]
    if not idx:
        return
    root = tuple(c * 0.45 for c in col)
    M = []
    for i in rng.choice(idx, size=min(max(n // 3, 4), len(idx)), replace=False):
        p, nrm = b.P[i], b.N[i]
        r = rng.uniform(*size) * 0.8
        M.append(("e", p + nrm * r * 0.1, (r, r * 0.35, r * 0.9), False, nrm))
    lab_pts = np.array([b.P[i] for i in idx])
    lab_names = [b.L[i] for i in idx]
    lab_of = lambda q: lab_names[int(np.argmin(np.linalg.norm(lab_pts - q, axis=1)))]
    g.meta(M, root, mat, lab_of, res=0.006, tris=max(1200, n * 12), smooth=1)
    for i in rng.choice(idx, size=min(n, len(idx)), replace=False):
        p, nrm, lab = b.P[i], b.N[i], b.L[i]
        r = rng.uniform(*size)
        t = np.cross(nrm, rng.normal(0, 1, 3))
        t /= np.linalg.norm(t)
        axis = t * 0.85 + nrm * 0.35                                   # the leaf stands off the skin, its cup sideways
        axis /= np.linalg.norm(axis)
        centre = p + nrm * (lift + r * 0.55) - axis * r * 0.8
        m = 3
        shade = lambda ii, jj, q, m=m: tuple(root[c] + (col[c] - root[c]) * min(ii / m, 1.0) for c in range(3))
        dome(g, centre, axis, r, math.radians(rng.uniform(20, 32)), math.radians(rng.uniform(48, 64)), shade, mat, lab, n=8, m=m,
             thick=0.0025, arc=math.radians(rng.uniform(110, 170)), phi0=rng.uniform(0, TAU), rim=False)
        if glow is not None and rng.random() < 0.2:
            g.ball(p + nrm * (lift + 0.004), r * 0.18, glow, "glow", lab, n=5)


def wraps(g, b, prefixes, y0, y1, col, mat="linen", pitch=0.034, width=0.024, off=0.007, seed=0):
    """Bandage wound round a limb from y0 to y1: strips cut from the limb's own surface, a little uneven, a few
    missing where they have rotted through."""
    y = y0
    k = seed
    while y < y1:
        w = width * (0.8 + 0.4 * ((k * 7919) % 11) / 11)
        if (k * 31) % 9 != 4:
            a, c = y, min(y + w, y1)
            wear(g, b, lambda p, l, a=a, c=c: l.startswith(prefixes) and a < p[1] < c, off + 0.002 * (k % 2), col, mat, thick=0.006, cuts=[a, c])
        y += pitch
        k += 1


def girdle(g, b, y, drop, labels, off, flare, col, mat, lab, bins=40, thick=0.012, rows=3, rim=True):
    """A band hung round the body from its own cross-section at height y: fauld lames, a skirt, a belt. It falls
    `drop` metres and flares `flare` outward as it goes, closed round, with thickness and a rolled hem."""
    loop = sorted(contour(b, y, labels, off=off, bins=bins), key=lambda t: t[0])
    if len(loop) < 8:
        return
    Q = [q for _, q in loop]
    cx = float(np.mean([q[0] for q in Q]))
    cz = float(np.mean([q[2] for q in Q]))
    def ringat(t, inset):
        out = []
        for q in Q:
            rd = np.array([q[0] - cx, 0.0, q[2] - cz])
            rd /= max(np.linalg.norm(rd), 1e-9)
            out.append(q + rd * (flare * t - inset) + V(0, -drop * t, 0))
        return out
    n = len(Q)
    for inset, flip in ((0.0, False), (thick, True)):
        g.grid([ringat(i / rows, inset) for i in range(rows + 1)], col, mat, lab,
               lambda i, j, p: (j / n * 1.2, i / rows * drop), wrap=True, flip=flip)
    if rim:
        hem = ringat(1.0, thick * 0.5)
        g.tube(hem + hem[:1], thick * 0.8, col, mat, lab, n=6)


def dome(g, at, axis, r, a0, a1, col, mat, lab, n=20, m=5, thick=0.014, arc=TAU, phi0=0.0, rim=True):
    """A spherical zone about `axis` through `at`, polar angles a0..a1 (0 at the pole): a pauldron, a lame, a cap.
    Given thickness and a rolled rim, so it reads as plate and not paper."""
    ax = np.asarray(axis, dtype=np.float64)
    ax /= np.linalg.norm(ax)
    e1 = np.cross(ax, V(0, 0, 1.0))
    if np.linalg.norm(e1) < 1e-3:
        e1 = np.cross(ax, V(1.0, 0, 0))
    e1 /= np.linalg.norm(e1)
    e2 = np.cross(ax, e1)

    def pt(u, v, rr):
        ph = phi0 + arc * u
        th = a0 + (a1 - a0) * v
        return at + rr * (math.cos(th) * ax + math.sin(th) * (math.cos(ph) * e1 + math.sin(ph) * e2))
    closed = arc >= TAU - 1e-6
    nu = n if closed else n + 1
    for rr, flip in ((r, False), (r - thick, True)):
        P = [[pt(j / n, i / m, rr) for j in range(nu)] for i in range(m + 1)]
        g.grid(P, col, mat, lab, lambda i, j, p: (j / n * r * arc, i / m * r * (a1 - a0)), wrap=closed, flip=flip)
    if rim:
        ring = [pt(j / n, 1.0, r - thick * 0.5) for j in range(n + (1 if closed else 1))]
        g.tube(ring, thick * 0.9, col, mat, lab, n=6)


def wear(g, b, sel, off, col, mat, thick=0.012, lab=None, cuts=None, smooth=0):
    """A garment or a plate cut from the body's own surface: the faces whose every corner passes sel(p, label) are
    lifted `off` metres along the body's normals (off may be fn(p, label)) and given `thick`ness with a rolled edge,
    so a cuirass follows the ribs it covers and a wrap follows the shin. Keeps the body's unwrap for the tile."""
    keep = [i for i, f in enumerate(b.F) if all(sel(b.P[v], b.L[v]) for v in f)]
    if not keep:
        return
    idx = sorted({v for i in keep for v in b.F[i]})
    rm = {v: k for k, v in enumerate(idx)}
    O = np.array([b.P[v] + b.N[v] * (off(b.P[v], b.L[v]) if callable(off) else off) for v in idx])
    Nn = b.N[idx]
    F = [[rm[v] for v in b.F[i]] for i in keep]
    FU = [b.FUV[i] for i in keep]
    cnt = {}
    for f in F:
        for a, c in zip(f, f[1:] + f[:1]):
            cnt[(a, c)] = cnt.get((a, c), 0) + 1
    if cuts:
        # a cut by height runs along the triangles' edges, a saw; its rim is laid on the height it was cut at
        rim = {v for (a, c) in cnt if (c, a) not in cnt for v in (a, c)}
        for v in rim:
            ys = [c for c in cuts if abs(O[v][1] - c) < 0.045]
            if ys:
                O[v][1] = min(ys, key=lambda c: abs(O[v][1] - c))
    if smooth:
        # hammered plate does not follow a nose or a lip: relax the shell (its rim held) toward its neighbours
        nb = [set() for _ in range(len(O))]
        for (a, c) in cnt:
            nb[a].add(c)
            nb[c].add(a)
        rimset = {v for (a, c) in cnt if (c, a) not in cnt for v in (a, c)}
        for _ in range(smooth):
            O2 = O.copy()
            for v in range(len(O)):
                if v not in rimset and nb[v]:
                    O2[v] = O[v] * 0.4 + np.mean([O[u] for u in nb[v]], axis=0) * 0.6
            O = O2
    n = len(O)
    In = O - Nn * thick
    P2 = np.concatenate([O, In])
    F2 = F + [[v + n for v in f[::-1]] for f in F]
    FU2 = FU + [list(u[::-1]) for u in FU]
    for (a, c) in list(cnt):
        if (c, a) not in cnt:                                    # an open edge: roll it over to the inner skin
            F2.append([c, a, a + n, c + n])
            FU2.append([(0.0, 0.0), (thick * 4, 0.0), (thick * 4, thick * 4), (0.0, thick * 4)])
    g.mesh(P2, F2, col, mat, lab or ([b.L[v] for v in idx] * 2), FU2)


def skull_face(g, col, eye, mat="bone", y=1.75, z=-0.09, w=1.0):
    """A face read at a distance: deep sockets with coals in them under a heavy brow, cheekbones, a hard jaw."""
    for sx in (-1, 1):
        g.ball(V(sx * 0.033 * w, y, z - 0.002), 0.016 * w, (0.02, 0.02, 0.02), "iron", "head", n=6)
        g.ball(V(sx * 0.033 * w, y, z - 0.012), 0.008 * w, eye, "glow", "head", n=5)
    g.tube([V(-0.07 * w, y + 0.03, z + 0.01), V(0.0, y + 0.035, z - 0.012), V(0.07 * w, y + 0.03, z + 0.01)], 0.016 * w, col, mat, "head", n=6)


# --- the kinds -----------------------------------------------------------------------------------------
# Each reads in silhouette at 15 m, and by what it carries says what it does.

def seed_i(x):
    return int(x * 7) % 13


def _rag_edge(p, seed=0.0, amp=0.035):
    """A torn hem: a height offset that wanders round the body (a few long tongues, some short bites)."""
    a = math.atan2(p[0], p[2])
    return amp * (0.55 * math.sin(a * 5.0 + seed) + 0.3 * math.sin(a * 11.0 + seed * 2.3) + 0.15 * math.sin(a * 23.0 + seed * 4.1))


def coat(g, b, col, mat="leather", y_top=1.45, y_hem=0.4, flare=0.12, seed=0.4, tatter=0.05, folds=8, thick=0.012, nu=72, nv=26):
    """A long coat laid on the body from under the arms to the hem: tight over the chest, flaring with depth past the
    hips and the legs (the gap between the legs bridged), broad folds deepening toward a torn hem. Returns the outer
    points (for placing things on its front)."""
    labs = tuple(sorted({l for l in b.L if not l.startswith(("elbow_", "hand_", "foot_", "head"))} - {"head"}))
    hem = lambda a: _rag_edge(V(math.sin(a), 0, math.cos(a)), seed, tatter) + tatter
    rows = band_rays(b, ("chest", "pelvis"), y_hem, y_top, nu, nv, hem=hem)

    def off(o, d):
        k = min(max((0.95 - float(o[1])) / 0.55, 0.0), 1.0)
        return 0.014 + flare * k ** 1.3

    def wob(i, j, ni, nj):
        v = 1.0 - i / (ni - 1)                        # 1 at the hem
        u = j / (nj - 1) * TAU
        k = min(max((v - 0.35) / 0.65, 0.0), 1.0)
        return 0.02 * k * (0.65 * math.sin(u * folds + seed) + 0.35 * math.sin(u * folds * 2.3 + seed * 3.0))
    return shrink(g, b, labs, rows, off, col, mat, B.waist_split(0.92), thick=thick, fill=True, relax=14, wobble=wob)


def sleeve(g, b, sx, col, trim=None, y_top=1.43, y_cuff=0.8, flare=0.02, bell=0.0, seed=0.3, mat="wool"):
    """A sleeve laid on the arm (shoulder to wrist), easing wider toward the cuff; bell > 0 opens it over the hand
    the way a robe's sleeve hangs. A rolled cuff in the trim colour."""
    t = side(sx)
    arm = ("shoulder_" + t, "elbow_" + t)
    rows = band_rays(b, arm, y_cuff, y_top, 28, 18)
    if not rows:
        return
    span = y_top - y_cuff

    def off(o, d):
        k = min(max((y_top - float(o[1])) / span, 0.0), 1.0)
        return 0.011 + flare * k + bell * k ** 3

    def wob(i, j, ni, nj):
        v = 1.0 - i / (ni - 1)
        u = j / (nj - 1) * TAU
        return 0.006 * v * math.sin(u * 4.0 + seed + v * 3.0)
    O = shrink(g, b, arm + ("hand_" + t,), rows, off, col, mat, lambda p: ("shoulder_" if p[1] > 1.1 else "elbow_") + t,
               thick=0.008, fill=True, relax=8, wobble=wob)
    if trim is not None and O is not None and len(O):
        low = O[O[:, 1] < float(O[:, 1].min()) + 0.012]
        if len(low) > 6:
            cx, cz = float(low[:, 0].mean()), float(low[:, 2].mean())
            ring = sorted(low.tolist(), key=lambda q: math.atan2(q[0] - cx, q[2] - cz))
            ring = [V(*q) for q in ring]
            g.tube(ring + [ring[0]], 0.009, trim, "trim" if trim != col else mat, "elbow_" + t, n=6, flat=0.6)


def shawl(g, b, col, mat="wool", y_low=1.05, gap=(math.radians(-25), math.radians(40)), seed=0.5, tatter=0.05, flare=0.04):
    """A shawl or a mantle laid over the shoulders and the upper arms from one point inside the chest: it falls from
    the neck over the shoulder caps and down the arms and the back to a torn hem at y_low, open down the front
    between the angles `gap` (around pi, the front; uneven, as a shawl is worn), with folds where it hangs."""
    hd = [b.P[i] for i in range(len(b.P)) if b.L[i] == "chest" and b.P[i][1] > 1.2]
    c = np.array([float(np.mean([q[0] for q in hd])), 1.36, float(np.mean([q[2] for q in hd]))])
    labs = tuple(sorted({l for l in b.L if not l.startswith(("hand_", "hip_", "knee_", "foot_"))}))
    NU, NV = 72, 24
    rows = dome_rays(c, NU, NV, math.radians(8), math.radians(122))

    def off(o, d):
        down = max(-float(d[1]), 0.0)
        return 0.014 + flare * down

    def edge(i, j):
        a = TAU * (j + 0.5) / NU                         # 0 at the back
        return not (math.pi + gap[0] < a < math.pi + gap[1])

    def hem(p):
        a = math.atan2(p[0] - c[0], p[2] - c[2])
        return y_low + _rag_edge(V(math.sin(a), 0, math.cos(a)), seed, tatter) + tatter

    def folds(i, j, ni, nj):
        v = i / (ni - 1)
        u = j / (nj - 1) * TAU
        return 0.012 * max(v - 0.35, 0.0) * (math.sin(u * 9.0 + seed) * 0.7 + math.sin(u * 17.0 + seed * 2.0) * 0.3)
    return shrink(g, b, labs, rows, off, col, mat, lambda p: "chest" if p[1] > 1.1 or abs(p[0]) < 0.18 else ("shoulder_l" if p[0] < 0 else "shoulder_r"),
                  thick=0.01, reach=0.55, relax=16, edge=edge, clip=hem, wobble=folds, fill=True)


def cowl(g, b, col, peak=0.0, open_w=0.065, seed=0.7, shade=True, mat="wool", open_h=0.085):
    """A hood laid on the body: cloth draped loose over the skull (air under it at the crown, the brim standing off
    the brow), falling onto the shoulders, an oval opening at the face; the face inside goes to shadow so only the
    eyes' coals show, the way the Fell's hoods read. peak lifts and draws the crown back into a point."""
    E = b.eyes
    ey = (E[0][1] + E[1][1]) * 0.5 if len(E) == 2 else 1.72
    hd = [b.P[i] for i in range(len(b.P)) if b.L[i] == "head"]
    c = np.array([float(np.mean([q[0] for q in hd])), ey + 0.005, float(np.mean([q[2] for q in hd])) + 0.012])
    trunk = tuple(sorted({l for l in b.L if not l.startswith(("elbow_", "hand_", "hip_", "knee_", "foot_"))}))
    NU, NV, V1 = 60, 32, math.radians(170)
    rows = dome_rays(c, NU, NV, 0.0, V1)

    def loose(o, d):
        up = max(float(d[1]), 0.0)
        return 0.02 + 0.03 * up + peak * 0.25 * up ** 6 + 0.012 * max(-float(d[2]), 0.0)   # crown air; brim off the brow

    zf = min(float(q[2]) for q in hd)

    oy = ey - 0.02

    def ow(y):                                          # the opening's half width at height y: a pointed arch at the brow
        t = (y - oy) / open_h
        if abs(t) >= 1.0:
            return 0.0
        return open_w * math.sqrt(1.0 - t * t) * (1.0 - 0.45 * max(t, 0.0) ** 1.5)

    def opening(p):
        return p[2] < c[2] - 0.03 and abs(p[0]) < ow(p[1])

    def folds(i, j, ni, nj):
        # cloth hangs: broad folds that deepen from the cheek down over the shoulders, a few at the crown's back
        v = i / (ni - 1)
        u = j / (nj - 1) * TAU
        hang = min(max((v - 0.5) / 0.4, 0.0), 1.0)
        f = math.sin(u * 7.0 + seed) * 0.6 + math.sin(u * 13.0 + seed * 2.0) * 0.4
        return 0.009 * hang * f + 0.004 * hang
    O = shrink(g, b, trunk, rows, loose, col, mat, lambda p: "head" if p[1] > ey - 0.12 else "chest", thick=0.012, reach=0.36,
               relax=30, cut=opening, balls=[(e, 0.02) for e in E], wobble=folds)
    if O is not None and len(O):
        # a rolled hem round the opening, on the oval itself (the cut follows the grid, a stair)
        front = O[O[:, 2] < c[2] - 0.02]
        hem = []
        for k in range(41):
            a = TAU * k / 40
            y = oy + math.cos(a) * open_h * 0.995
            x = math.copysign(ow(y) * 1.03, math.sin(a)) if abs(math.sin(a)) > 1e-6 else 0.0
            d2 = (front[:, 0] - x) ** 2 + (front[:, 1] - y) ** 2
            near = front[np.argsort(d2)[:3]]
            hem.append(V(x, y, float(near[:, 2].mean()) - 0.002))
        g.tube(hem, 0.009, col, mat, "head", n=6, flat=0.45)
    if peak > 0.0:                                     # the point drawn back off the crown
        top = c + V(0.0, 0.16, 0.05)
        g.tube([top, top + V(0.0, 0.03 + peak * 0.2, 0.06 + peak * 0.2)], [0.03, 0.004], col, "wool", "head", n=8)
    if not shade:
        return
    # the face in shadow under the brim: its features smoothed away and taken near black, so only the eyes' coals
    # (glow, left where they were) read in the hood
    start = g._fit[1]
    n0 = start - len(b.P)
    face = [k for k in range(len(b.P)) if b.L[k] == "head" and b.P[k][2] < c[2] - 0.01]
    fset = set(face)
    nb = {k: set() for k in face}
    for f in b.F:
        for a, d in zip(f, f[1:] + f[:1]):
            if a in fset:
                nb[a].add(d)
            if d in fset:
                nb[d].add(a)
    for _ in range(12):
        new = {}
        for k in face:
            if nb[k]:
                m = np.mean([g.v[n0 + u] for u in nb[k]], axis=0)
                new[k] = g.v[n0 + k] * 0.4 + m * 0.6
        for k, q in new.items():
            g.v[n0 + k] = q
    for k in face:
        t = min(max((c[2] - b.P[k][2]) / 0.05, 0.0), 1.0)
        cc = g.col[n0 + k]
        g.col[n0 + k] = (cc[0] * (1 - 0.94 * t), cc[1] * (1 - 0.94 * t), cc[2] * (1 - 0.94 * t), cc[3])


def rags(g, b, cloth, wrap, cord, vest=(1.02, 1.42), seed=1.3, v1=150, tails=True):
    """A scavenger's layers, laid on its own body so they fit: a head wrap wound over the scalp and the lower face with
    only an uneven eye slit left (a bare MakeHuman face read as a mannequin's), two wrap tails down the nape, and a
    torn sleeveless vest over the ribs with a ragged hem and cord lacing at the breast."""
    E = b.eyes
    ey = (E[0][1] + E[1][1]) * 0.5 if len(E) == 2 else 1.72
    hd = [b.P[i] for i in range(len(b.P)) if b.L[i] == "head"]
    top = max(float(q[1]) for q in hd)
    c = np.array([float(np.mean([q[0] for q in hd])), ey + 0.01, float(np.mean([q[2] for q in hd])) + 0.01])
    NU, NV = 56, 26
    trunk = tuple(sorted({l for l in b.L if not l.startswith(("elbow_", "hand_", "hip_", "knee_", "foot_"))}))
    rows = dome_rays(c, NU, NV, 0.0, math.radians(v1))
    # the slit: the rows that pass the eyes, only at the front (-z: u near pi), ragged at its ends
    def vang(i):
        return math.radians(150) * i / NV
    def edge(i, j):
        u = TAU * j / NU
        front = math.cos(u - math.pi)                      # 1 at the face
        y_mid = c[1] + math.cos(vang(i) + math.radians(150) / NV * 0.5) * 0.1
        return not (front > 0.6 and abs(y_mid - ey) < 0.017)
    # wound: alternate rows stand a little prouder, so the layers read
    shrink(g, b, trunk, rows, 0.011,
           wrap, "linen", "head", thick=0.007, ridges=(4.0, 0.006), reach=0.2, relax=20, balls=[(e + V(0, 0, -0.004), 0.016) for e in E] if v1 < 130 else (),
           cut=(lambda p: p[2] < c[2] - 0.04 and abs(p[1] - ey) < 0.0135 and abs(p[0]) < 0.07) if v1 >= 130 else None)
    start = g._fit[1] if getattr(g, "_fit", None) else 0
    n0 = start - len(b.P)
    for k in (range(len(b.P)) if v1 >= 130 else ()):
        q = b.P[k]
        if b.L[k] == "head" and q[2] < c[2] - 0.03 and abs(q[1] - ey) < 0.03:
            t = 1.0 - min(abs(q[1] - ey) / 0.03, 1.0)
            cc = g.col[n0 + k]
            g.col[n0 + k] = (cc[0] * (1 - 0.92 * t), cc[1] * (1 - 0.92 * t), cc[2] * (1 - 0.92 * t), cc[3])
    back = c + V(0.0, -0.03, 0.09)
    for sx, ln in (((-1, 0.34), (1, 0.26)) if tails else ()):
        a = back + V(sx * 0.02, 0.0, 0.0)
        pts = [a, a + V(sx * 0.03, -0.1, 0.04), a + V(sx * 0.05, -0.2, 0.05), a + V(sx * 0.07, -ln, 0.04)]
        g.tube(pts, [0.02, 0.022, 0.018, 0.01], wrap, "linen", "chest", n=6, flat=0.22)
    # the vest: a clean band round the trunk (arms not in the BVH, so the rays go past them), its hem torn
    if vest is None:
        return
    NUv, NVv = 72, 14
    hem = lambda a: _rag_edge(V(math.sin(a), 0, math.cos(a)), seed) + 0.035
    rows = band_rays(b, ("chest", "pelvis"), vest[0], vest[1], NUv, NVv, hem=hem)
    shrink(g, b, ("chest", "pelvis"), rows, 0.011, cloth, "wool", "chest", thick=0.008, fill=True)
    fr = [q for i, q in enumerate(b.P) if b.L[i] == "chest" and abs(q[0]) < 0.02 and 1.2 < q[1] < 1.4]
    if fr:
        zf = min(q[2] for q in fr)
        for k in range(5):
            y = 1.37 - 0.035 * k
            g.tube([V(-0.03, y, zf - 0.016), V(0.0, y - 0.012, zf - 0.02), V(0.03, y, zf - 0.016)], 0.004, cord, "leather", "chest", n=4)


def wretch():
    """A starved scavenger bent under what it carries: bare grey skin over ribs, a loin of rags and wrappings, a hairless
    skull with coals sunk in it, a stuffed sack hung from straps that cut into the shoulders, a gaff in its fist."""
    g = Geo()
    SKIN, RAG, SACK, BELT = (0.46, 0.46, 0.43), (0.17, 0.13, 0.1), (0.5, 0.43, 0.3), (0.1, 0.075, 0.06)
    b = human(g, SKIN, (1.0, 0.45, 0.15, 0.0), macro={"gender": 1.0, "age": 0.85, "muscle": 0.25, "weight": 0.0, "proportions": 0.3}, girth=0.92, head=1.15, tris=12000)
    wraps(g, b, ("knee_",), 0.07, 0.3, RAG)
    wraps(g, b, ("elbow_", "hand_"), 0.8, 0.92, RAG, seed=2)
    g.robe([(0.98, 0.16, 0.12, 0.0), (0.9, 0.17, 0.13, 0.0), (0.7, 0.2, 0.16, 0.0), (0.56, 0.21, 0.17, 0.0)], RAG, "wool", B.waist_split(0.9), n=48, pleats=8, pleat_amp=0.1, tatter=0.14)
    g.ring_band(0.93, 0.99, 0.162, 0.122, 0.0, BELT, "leather", "pelvis", n=40)
    for sx in (-1, 1):
        t = side(sx)
        g.lathe([(0.03, 0.0), (0.033, 0.03), (0.03, 0.06)], V(sx * 0.24, 0.82, 0.0), RAG, "wool", "elbow_" + t, n=10)
    S = V(0.0, 1.24, 0.24)
    g.ball(S, 0.22, SACK, "linen", "chest", n=12, sx=1.05, sy=1.2, sz=0.75)
    g.lathe([(0.08, 0.0), (0.05, 0.05), (0.08, 0.12)], S + V(0, 0.25, -0.02), SACK, "linen", "chest", n=12)
    g.tube([S + V(-0.05, 0.3, 0.0), S + V(-0.12, 0.62, 0.05)], 0.018, (0.3, 0.22, 0.14), "wood", "chest", n=6)
    g.tube([S + V(0.06, 0.28, 0.0), S + V(0.14, 0.52, 0.02)], 0.014, (0.3, 0.22, 0.14), "wood", "chest", n=6)
    g.ball(S + V(0.14, 0.05, 0.14), 0.07, (0.18, 0.16, 0.15), "iron", "chest", n=8)
    for sx in (-1, 1):
        strap(g, [V(sx * 0.11, 1.5, -0.1), V(sx * 0.13, 1.4, -0.13), V(sx * 0.12, 1.16, -0.12), V(sx * 0.14, 1.05, 0.0), V(sx * 0.13, 1.14, 0.17)], BELT)
    rags(g, b, RAG, (0.6, 0.55, 0.44), BELT)
    gf = Geo()
    gf.tube([V(0, -0.5, -0.03), V(0, 0.9, -0.03)], 0.016, (0.28, 0.2, 0.13), "wood", "hand_r", n=8)
    gf.tube([V(0, 0.9, -0.03), V(0, 1.0, -0.06), V(0, 1.02, -0.14), V(0, 0.96, -0.2), V(0, 0.9, -0.19)], [0.014, 0.012, 0.01, 0.008, 0.002], (0.35, 0.33, 0.32), "iron", "hand_r", n=8)
    return g.to_object("body"), [gf.to_object("staff_hand_r")]


def husk():
    """A gravedigger grown huge: a long stained coat strained over a barrel of a body, an ember split where it is torn,
    a sacking cowl with two coals in it, a coffin lid strapped on the back."""
    g = Geo()
    COAT, SACK, SKIN, LID, BELT = (0.2, 0.15, 0.11), (0.36, 0.3, 0.22), (0.42, 0.36, 0.32), (0.22, 0.16, 0.11), (0.12, 0.09, 0.07)
    b = human(g, SKIN, (1.0, 0.5, 0.15, 0.0), macro={"gender": 1.0, "age": 0.7, "muscle": 0.7, "weight": 1.0, "proportions": 0.2}, girth=1.12, limb=1.08, head=1.0)
    O = coat(g, b, COAT, y_top=1.47, y_hem=0.38, flare=0.1, seed=0.9, tatter=0.06)
    def front_z(y):
        near = O[(np.abs(O[:, 1] - y) < 0.03) & (np.abs(O[:, 0]) < 0.04)]
        return float(near[:, 2].min()) if len(near) else -0.3
    belt = contour(b, 0.96, ("chest", "pelvis"), off=0.03, bins=40, band=0.03)
    if belt:
        g.tube([q for _, q in belt] + [belt[0][1]], 0.022, BELT, "leather", "pelvis", n=6, flat=0.4)
    zf = front_z(1.12)
    g.tube([V(0.0, 1.0, zf - 0.004), V(0.0, 1.24, front_z(1.24) - 0.004)], 0.018, (1.0, 0.45, 0.12, 0.0), "glow", "chest", n=6)   # the split
    for k in range(4):
        y = 1.03 + 0.06 * k
        z = front_z(y) - 0.008
        g.tube([V(-0.05, y, z), V(0.05, y + 0.01, z)], 0.007, (0.1, 0.08, 0.06), "leather", "chest", n=4)
    for sx in (-1, 1):
        sleeve(g, b, sx, COAT, BELT, flare=0.02, mat="leather")
    hood(g, SACK, eye=(1.0, 0.5, 0.15, 0.0), low=1.5, face_y=1.66, eye_r=0.017, open_=48)
    def lid(u, v):
        w = 0.26 * (1.0 - 0.35 * abs(v - 0.7))
        return V((u - 0.5) * 2.0 * w, 0.75 + 0.95 * v, 0.36 + 0.03 * math.sin(u * math.pi))
    g.plate(lid, 5, 7, LID, "wood", "chest")
    g.tube([V(-0.12, 1.4, 0.39), V(0.12, 1.4, 0.39)], 0.014, (0.45, 0.4, 0.38), "iron", "chest", n=5)
    g.tube([V(0.0, 1.27, 0.39), V(0.0, 1.55, 0.39)], 0.014, (0.45, 0.4, 0.38), "iron", "chest", n=5)
    return g.to_object("body"), []


def hooded(robe_col, mantle_col, eye, trim=None, belt=(0.16, 0.11, 0.08), peak=0.0, hem=0.05, flare=0.4, tatter=0.04, arms_col=(0.42, 0.38, 0.34), hands=True, macro=None):
    """A robed figure on a MakeHuman body: the face is seen inside the hood, the hands out of the sleeves."""
    g = Geo()
    human(g, arms_col, eye, macro=macro or {"gender": 0.8, "age": 0.8, "muscle": 0.3, "weight": 0.2}, girth=0.92, head=1.05)
    hands = False
    robe_body(g, robe_col, hem=hem, flare=flare, tatter=tatter, belt=belt, trim=trim)
    for sx in (-1, 1):
        sleeve(g, g._fit[0], sx, robe_col, trim or belt, flare=0.03, bell=0.07, y_cuff=0.74)
        if hands:
            B.hand(g, sx, arms_col, "hand_" + side(sx), closed=0.5)
    mantle(g, mantle_col, trim, tatter=tatter)
    hood(g, mantle_col, eye=eye, peak=peak, face=False)
    return g


def chanter():
    """A tall hooded caster in green-black, bone charms on cords, a caged corpse-light raised on a staff."""
    G1, G2, BONE = (0.13, 0.16, 0.11), (0.08, 0.1, 0.07), (0.8, 0.75, 0.62)
    g = hooded(G1, G2, (0.6, 1.0, 0.4, 0.0), trim=(0.55, 0.62, 0.3), peak=0.12, arms_col=(0.4, 0.42, 0.36), macro={"gender": 0.3, "age": 0.95, "muscle": 0.1, "weight": 0.0, "height": 1.0})
    for k, x in enumerate((-0.12, -0.04, 0.05, 0.13)):
        y = 1.02 - 0.06 * (k % 2)
        g.tube([V(x, 1.0, -0.15), V(x, y - 0.12, -0.17)], 0.003, (0.3, 0.25, 0.18), "leather", "pelvis", n=4)
        g.box(V(x, y - 0.16, -0.17), (0.012, 0.03, 0.006), BONE, "bone", "pelvis")
    st = Geo()
    st.tube([V(0, -0.78, -0.03), V(0, 1.0, -0.03)], 0.016, (0.2, 0.16, 0.12), "wood", "hand_r", n=8)
    C = V(0, 1.14, -0.03)
    st.ball(C, 0.05, (0.6, 1.0, 0.45, 0.0), "glow", "hand_r", n=8)
    for k in range(6):
        a = TAU * k / 6
        st.tube([C + V(math.cos(a) * 0.075 * math.sin(p), -0.1 * math.cos(p), math.sin(a) * 0.075 * math.sin(p)) for p in np.linspace(0.1, math.pi - 0.1, 7)], 0.005, (0.3, 0.3, 0.25), "iron", "hand_r", n=4)
    return g.to_object("body"), [st.to_object("staff_hand_r")]


def tollman():
    """Broad and stooped in a black coat with a yoke, a deep cowl, the toll-rope at the belt, the iron bell in hand."""
    COAT, CAPE, ROPE = (0.08, 0.075, 0.075), (0.11, 0.1, 0.1), (0.5, 0.42, 0.3)
    g = hooded(COAT, CAPE, (1.0, 0.65, 0.3, 0.0), trim=(0.5, 0.35, 0.2), hem=0.1, flare=0.55, macro={"gender": 1.0, "age": 0.9, "muscle": 0.5, "weight": 0.85})
    g.tube([V(0.17, 1.0, -0.08), V(0.22, 0.85, -0.12), V(0.2, 0.62, -0.1), V(0.24, 0.4, -0.06)], 0.012, ROPE, "leather", "pelvis", n=6)
    b = Geo()
    b.tube([V(0, 0.06, -0.03), V(0, -0.1, -0.03)], 0.014, (0.25, 0.18, 0.12), "wood", "hand_r", n=6)
    b.lathe([(0.0, -0.14), (0.05, -0.15), (0.07, -0.22), (0.1, -0.33), (0.115, -0.37), (0.105, -0.36)], V(0, 0.0, -0.03), (0.16, 0.15, 0.15), "iron", "hand_r", n=18)
    return g.to_object("body"), [b.to_object("bell_hand_r")]


def pilgrim():
    """A bent pilgrim in a travelling cloak with a scallop at the breast, a pack and bedroll, a crooked staff."""
    CLOAK, ROBE, PACK = (0.32, 0.27, 0.2), (0.24, 0.2, 0.16), (0.3, 0.22, 0.15)
    g = hooded(ROBE, CLOAK, (1.0, 0.75, 0.4, 0.0), belt=(0.2, 0.14, 0.1), hem=0.12, tatter=0.08, macro={"gender": 0.6, "age": 0.75, "muscle": 0.35, "weight": 0.35})
    g.lathe([(0.0, 0.0), (0.05, 0.004), (0.045, 0.012)], V(0.0, 1.36, -0.18), (0.85, 0.8, 0.7), "bone", "chest", n=12, axis="z")
    g.box(V(0.0, 1.2, 0.24), (0.17, 0.2, 0.08), PACK, "leather", "chest")
    g.tube([V(-0.2, 1.43, 0.26), V(0.2, 1.43, 0.26)], 0.07, (0.4, 0.33, 0.24), "wool", "chest", n=12)
    st = Geo()
    st.tube([V(0, -0.8, -0.03), V(0, 0.4, -0.03), V(0.02, 0.9, -0.04), V(0.0, 1.05, -0.02), V(-0.06, 1.1, -0.04)], [0.02, 0.019, 0.018, 0.016, 0.01], (0.3, 0.22, 0.14), "wood", "hand_r", n=8)
    st.ball(V(0.03, 0.7, -0.07), 0.05, (0.5, 0.42, 0.25), "leather", "hand_r", n=8, sy=1.3)
    return g.to_object("body"), [st.to_object("staff_hand_r")]


def gaunt():
    """Too tall and too thin, and the Shroud has grown into it: wiry dead flesh gone grey-blue, a torn shroud fitted
    over the skull and shoulders, and shelves of pale crust bursting from one shoulder, the crown of the head and
    the breastbone, lit from beneath where they root. Wrappings on the forearms and shins."""
    g = Geo()
    SHROUD, SKIN, CRUST, GL = (0.25, 0.27, 0.31), (0.34, 0.37, 0.42), (0.62, 0.68, 0.76), (0.55, 0.78, 1.0, 0.0)
    b = human(g, SKIN, (0.75, 0.85, 1.0, 0.0), macro={"gender": 0.9, "age": 0.9, "muscle": 0.75, "weight": 0.0, "proportions": 1.0, "height": 1.0},
              girth=0.9, limb=0.95, head=1.05, tris=12000, skull=1.0)
    wraps(g, b, ("elbow_",), 0.82, 1.04, SHROUD)
    wraps(g, b, ("knee_",), 0.06, 0.3, SHROUD, seed=3)
    # the shroud: cut from the skull, the back of the neck and the shoulders, torn along its edge; the face left bare
    # the shroud: a hood fitted over the skull and the shoulders, the face left bare (the skull is what is seen)
    cowl(g, b, SHROUD, open_w=0.075, open_h=0.1, shade=False, mat="linen", seed=1.9)
    # a burial wrap from the ribs to the shins, torn to ribbons at the hem
    coat(g, b, SHROUD, mat="linen", y_top=1.02, y_hem=0.42, flare=0.05, seed=2.6, tatter=0.12, folds=9, thick=0.008, nu=60, nv=18)
    # the crust: a great mass on the left shoulder spilling to the neck, a crown on the skull, a seam down the breast
    crust(g, b, lambda p, l: (l == "shoulder_l" and p[1] > 1.2) or (l == "chest" and p[0] < -0.06 and p[1] > 1.3), 150, CRUST, size=(0.025, 0.055), seed=2, glow=GL, lift=0.008)
    crust(g, b, lambda p, l: l == "head" and p[1] > 1.76, 80, CRUST, size=(0.025, 0.06), seed=9, glow=GL, lift=0.045)   # through the hood
    crust(g, b, lambda p, l: l == "chest" and 1.08 < p[1] < 1.36 and abs(p[0]) < 0.06 and p[2] < 0.0, 40, CRUST, size=(0.015, 0.04), seed=5, glow=GL)
    return g.to_object("body"), []


def quiller():
    """A marksman: lean, in a leather jerkin and wrapped legs, a short hood and mantle, bound forearms, a quiver of long
    rib-darts on the back."""
    SH, RAG = (0.27, 0.29, 0.3), (0.2, 0.2, 0.2)
    g = Geo()
    b = human(g, (0.4, 0.36, 0.33), (0.7, 0.85, 1.0, 0.0), macro={"gender": 0.7, "age": 0.55, "muscle": 0.65, "weight": 0.25}, girth=0.95, head=1.05)
    coat(g, b, (0.22, 0.16, 0.11), mat="leather", y_top=1.46, y_hem=0.68, flare=0.05, seed=1.7, tatter=0.04, folds=6, thick=0.01, nu=60, nv=20)   # the jerkin
    for sx in (-1, 1):
        for k in range(3):
            g.lathe([(0.03, 0.0), (0.033, 0.03), (0.03, 0.06)], V(sx * 0.24, 0.82 + 0.06 * k, 0.0), RAG, "wool", "elbow_" + side(sx), n=10)
    mantle(g, SH, y1=1.26, r1=0.28, tatter=0.1)
    hood(g, SH, eye=(0.7, 0.85, 1.0, 0.0), open_=40)
    g.lathe([(0.07, 0.0), (0.075, 0.5), (0.065, 0.52)], V(0.1, 1.0, 0.22), (0.22, 0.16, 0.11), "leather", "chest", n=12)
    for k in range(6):
        a = TAU * k / 6
        g.tube([V(0.1 + math.cos(a) * 0.035, 1.45, 0.22 + math.sin(a) * 0.035), V(0.1 + math.cos(a) * 0.045, 1.72, 0.25 + math.sin(a) * 0.04)], [0.007, 0.002], (0.85, 0.8, 0.7), "bone", "chest", n=4)
    strap(g, [V(-0.14, 1.5, -0.13), V(0.0, 1.25, -0.17), V(0.16, 1.02, -0.13)], (0.16, 0.11, 0.08))
    d = Geo()
    d.tube([V(0, 0.02, -0.03), V(0, 0.42, -0.03)], [0.008, 0.002], (0.85, 0.8, 0.7), "bone", "hand_r", n=5)
    return g.to_object("body"), [d.to_object("staff_hand_r")]


def ossuant():
    """A walking reliquary: a starved body bound in its own bones worn outside, ribs laid over the ribs, plates of
    femur on the thighs, a skull helm over the skull with the coals showing through its sockets, a crest of ribs."""
    g = Geo()
    BONE, OLD, SINEW = (0.8, 0.74, 0.6), (0.58, 0.52, 0.42), (0.16, 0.11, 0.1)
    eye = (1.0, 0.8, 0.45, 0.0)
    b = human(g, SINEW, eye, macro={"gender": 1.0, "age": 1.0, "muscle": 0.0, "weight": 0.0, "proportions": 0.2, "height": 1.0},
              girth=0.88, limb=1.0, head=1.0, tris=12000)
    front = lambda p: p[2] < 0.0
    # the ribcage: each rib a bar from the spine round the body's own cross-section to the sternum, falling forward
    for k in range(8):
        y = 1.40 - 0.052 * k
        loop = contour(b, y, ("chest",), off=0.02)
        for sx in (-1, 1):
            arc = sorted([(abs(a), q) for a, q in loop if a * sx > 0 and 0.25 < abs(a) < 2.85], key=lambda t: t[0])
            if len(arc) < 4:
                continue
            path = [q + V(0, -0.06 * (t - 0.25) / 2.6, 0) for t, q in arc]
            r = 0.016 - 0.0008 * k
            g.tube(path, [r * 0.8] + [r] * (len(path) - 2) + [r * 0.7], BONE, "bone", "chest", n=7)
    wear(g, b, lambda p, l: l == "chest" and 1.0 < p[1] < 1.44 and abs(p[0]) < 0.032 and front(p), 0.04, OLD, "bone", thick=0.016, cuts=[1.0, 1.44])
    for k in range(13):                                                   # the spine, a knuckle a hand's width
        y = 0.9 + 0.052 * k
        loop = contour(b, y, ("chest", "pelvis"), off=0.022)
        back = [q for a, q in loop if abs(a) < 0.25]
        if back:
            g.ball(back[0], 0.022, OLD if k % 2 else BONE, "bone", "pelvis" if y < 0.95 else "chest", n=7, sy=0.7)
    # collar bones and the girdle
    wear(g, b, lambda p, l: l == "chest" and 1.44 < p[1] < 1.5 and abs(p[0]) > 0.04, 0.03, BONE, "bone", cuts=[1.44, 1.5])
    wear(g, b, lambda p, l: l == "pelvis" and 0.84 < p[1] < 0.97, 0.03, OLD, "bone", thick=0.016, cuts=[0.84, 0.97])
    for sx in (-1, 1):
        t = side(sx)
        # a shoulder blade of bone, a femur down the front of the thigh, a shin bone, the two bones of the forearm
        dome(g, V(sx * 0.2, 1.36, 0.0), V(sx * 0.5, 1.0, 0.0), 0.12, 0.0, math.radians(62), BONE, "bone", "shoulder_" + t, n=16, m=5, thick=0.012)
        fem = line(b, ("hip_" + t,), np.linspace(0.72, 0.4, 7), math.pi, off=0.016)
        if len(fem) > 2:
            g.tube(fem, [0.022] + [0.017] * (len(fem) - 2) + [0.024], BONE, "bone", "hip_" + t, n=8)
            g.ball(fem[0], 0.03, OLD, "bone", "hip_" + t, n=8)
            g.ball(fem[-1], 0.032, OLD, "bone", "knee_" + t, n=8)
        tib = line(b, ("knee_" + t,), np.linspace(0.32, 0.1, 6), math.pi, off=0.012)
        if len(tib) > 2:
            g.tube(tib, [0.02] + [0.014] * (len(tib) - 2) + [0.018], BONE, "bone", "knee_" + t, n=8)
        for ang in (math.pi - 0.9 * sx, math.pi + 0.9 * sx):
            fa = line(b, ("elbow_" + t,), np.linspace(1.04, 0.83, 6), ang, off=0.01)
            if len(fa) > 2:
                g.tube(fa, [0.013] + [0.009] * (len(fa) - 2) + [0.012], BONE, "bone", "elbow_" + t, n=6)
        wear(g, b, lambda p, l, t=t: l == "hand_" + t and p[2] < 0.01, 0.008, OLD, "bone")
    # the skull helm over the whole head; its sockets sunk dark over the eyes, the coals burning in them
    helm = lambda p, l: l == "head" and p[1] > 1.6
    for e in b.eyes:
        g.ball(e + V(0, 0.002, -0.026), 0.024, (0.02, 0.015, 0.012), "iron", "head", n=8, sz=0.6)
        g.ball(e + V(0, 0, -0.04), 0.01, eye, "glow", "head", n=6)
    wear(g, b, helm, 0.026, BONE, "bone", thick=0.016, smooth=3)
    for k in range(7):
        a = (k - 3) * 0.14
        g.tube([V(math.sin(a) * 0.07, 1.76, 0.02 + math.cos(a) * 0.03), V(math.sin(a) * 0.15, 2.0 - abs(k - 3) * 0.04, 0.12 + math.cos(a) * 0.05)], [0.014, 0.003], BONE, "bone", "head", n=5)
    return g.to_object("body"), []


def bulwark():
    """Plate over quilting, all of it fitted to the man inside: a gambeson, a cuirass on the chest it covers, three lames
    at each shoulder, bracers and gauntlets, a great helm over the skull with a lit slit, a tower of planks as a shield."""
    g = Geo()
    IRON, DARKI, QUILT, WOOD, BAND, LEATH = (0.3, 0.3, 0.32), (0.2, 0.2, 0.22), (0.3, 0.24, 0.18), (0.32, 0.22, 0.14), (0.2, 0.2, 0.22), (0.18, 0.13, 0.09)
    b = human(g, (0.38, 0.33, 0.3), (1.0, 0.55, 0.2, 0.0), macro={"gender": 1.0, "age": 0.5, "muscle": 1.0, "weight": 0.7}, girth=1.05, head=1.0, tris=10000)
    # the gambeson under it all, and its skirt
    wear(g, b, lambda p, l: l in ("chest", "pelvis") or (l.startswith("shoulder_")) or (l.startswith("elbow_") and p[1] > 1.0), 0.016, QUILT, "wool")
    girdle(g, b, 0.94, 0.42, ("pelvis",), 0.03, 0.12, QUILT, "wool", "pelvis", rows=4)
    # cuirass, breast and back
    wear(g, b, lambda p, l: l == "chest" and 0.98 < p[1] < 1.5, 0.05, IRON, "iron", thick=0.016, cuts=[0.98, 1.5])
    for k in range(3):                                                    # faulds: lames hung from the waist, each over the next
        girdle(g, b, 0.98 - 0.075 * k, 0.1, ("pelvis", "chest"), 0.055 + 0.014 * k, 0.025, IRON if k % 2 == 0 else DARKI, "iron", "pelvis", rows=1)
    girdle(g, b, 1.02, 0.05, ("chest", "pelvis"), 0.058, 0.0, LEATH, "leather", "chest", rows=1, rim=False)
    # pauldrons: a domed cop over each shoulder and two lames below it, each overlapping the next
    for sx in (-1, 1):
        t = side(sx)
        c = V(sx * 0.21, 1.33, 0.0)
        axis = V(sx * 1.0, 0.9, 0.0)
        dome(g, c, axis, 0.135, 0.0, math.radians(72), IRON, "iron", "shoulder_" + t, n=22, m=6)
        dome(g, c, axis, 0.143, math.radians(64), math.radians(84), DARKI, "iron", "shoulder_" + t, n=22, m=2)
        dome(g, c, axis, 0.151, math.radians(77), math.radians(96), IRON, "iron", "shoulder_" + t, n=22, m=2)
        g.ball(c + axis / np.linalg.norm(axis) * 0.137, 0.014, DARKI, "iron", "shoulder_" + t, n=6, sy=0.6)
    # vambraces, couters, gauntlets
    wear(g, b, lambda p, l: l.startswith("elbow_") and 0.83 < p[1] < 1.02, 0.03, IRON, "iron", thick=0.014, cuts=[0.83, 1.02])
    wear(g, b, lambda p, l: l.startswith(("elbow_", "shoulder_")) and 1.02 < p[1] < 1.12, 0.045, DARKI, "iron", thick=0.014, cuts=[1.02, 1.12])
    wear(g, b, lambda p, l: l.startswith("hand_"), 0.016, DARKI, "iron", thick=0.01)
    # knee cops, greaves, sabatons
    wear(g, b, lambda p, l: l.startswith(("knee_", "hip_")) and 0.28 < p[1] < 0.42, 0.045, IRON, "iron", thick=0.014, cuts=[0.28, 0.42])
    wear(g, b, lambda p, l: l.startswith("knee_") and 0.06 < p[1] < 0.29, 0.03, IRON, "iron", thick=0.014, cuts=[0.06, 0.29])
    wear(g, b, lambda p, l: l.startswith("foot_"), 0.022, DARKI, "iron", thick=0.012)
    # a mail aventail round the neck, the great helm over the skull, its slit lit from inside
    ey = float(np.mean([e[1] for e in b.eyes])) if b.eyes else 1.69
    hd = [b.P[i] for i in range(len(b.P)) if b.L[i] == "head"]
    hc = np.array([float(np.mean([q[0] for q in hd])), ey, float(np.mean([q[2] for q in hd])) + 0.01])
    trunk = tuple(sorted({l for l in b.L if not l.startswith(("elbow_", "hand_", "hip_", "knee_", "foot_"))}))
    # the mail aventail: hung from the helm's rim over the neck and the top of the shoulders, falling in folds
    shrink(g, b, trunk, dome_rays(hc, 48, 10, math.radians(118), math.radians(168)), 0.03, DARKI, "iron",
           lambda p: "head" if p[1] > ey - 0.14 else "chest", thick=0.01, reach=0.34, relax=20,
           wobble=lambda i, j, ni, nj: 0.006 * math.sin(j / (nj - 1) * TAU * 14.0) * i / (ni - 1))
    # the great helm: one smooth shell over the skull to the jaw (plate does not follow a face), a visor slit at the
    # eyes with the coals behind it, a ridge down the crown, breaths punched in the cheek
    O = shrink(g, b, trunk, dome_rays(hc, 56, 26, 0.0, math.radians(122)), 0.04, IRON, "iron", "head", thick=0.014,
               reach=0.22, relax=60, cut=lambda p: p[2] < hc[2] - 0.05 and abs(p[1] - ey) < 0.009 and abs(p[0]) < 0.075)
    if O is not None and len(O):
        fr = O[O[:, 2] < hc[2] - 0.05]
        def at(x, y):
            d2 = (fr[:, 0] - x) ** 2 + (fr[:, 1] - y) ** 2
            return fr[np.argsort(d2)[:3]].mean(axis=0)
        g.tube([at(x, ey) + V(0, 0, 0.022) for x in np.linspace(-0.07, 0.07, 9)], 0.009, (1.0, 0.55, 0.2, 0.0), "glow", "head", n=6)   # lit inside
        for sy in (1, -1):                                 # the slit's lips
            g.tube([at(x, ey + sy * 0.013) + V(0, 0, -0.003) for x in np.linspace(-0.08, 0.08, 11)], 0.006, DARKI, "iron", "head", n=5)
        crown = O[np.abs(O[:, 0]) < 0.006]
        crown = crown[np.argsort(np.arctan2(crown[:, 1] - hc[1], -(crown[:, 2] - hc[2])))]
        if len(crown) > 4:
            g.tube([V(*q) + (V(*q) - hc) / np.linalg.norm(V(*q) - hc) * 0.006 for q in crown], 0.009, DARKI, "iron", "head", n=5, flat=0.6)
        for sx in (-1, 1):
            for k in range(4):
                q = at(sx * 0.045, ey - 0.05 - 0.016 * k)
                g.ball(q + V(0, 0, -0.002), 0.005, (0.03, 0.03, 0.03), "iron", "head", n=5, sz=0.4)
    top = float(max(q[1] for q, l in zip(b.P, b.L) if l == "head")) + 0.045
    for k in range(5):
        g.tube([V(0.0, top - 0.01, -0.05 + 0.035 * k), V(0.0, top + 0.13 - 0.02 * abs(k - 2), -0.04 + 0.04 * k)], [0.012, 0.002], IRON, "iron", "head", n=4)
    sh = Geo()
    def board(u, v):
        return V(-0.12 + (u - 0.5) * 0.72, 0.15 + v * 1.15, -0.2 - 0.06 * math.cos((u - 0.5) * math.pi))
    sh.plate(board, 9, 8, WOOD, "wood", "chest")
    for y in (0.3, 0.75, 1.15):
        sh.band([board(u, (y - 0.15) / 1.15) + V(0, 0, -0.012) for u in np.linspace(0.0, 1.0, 9)], 0.07, BAND, "iron", "chest", out=0.0, up=[V(0, 0, -1)] * 9)
    sh.lathe([(0.0, 0.0), (0.09, 0.0), (0.07, 0.05), (0.0, 0.1)], V(-0.12, 0.75, -0.27), IRON, "iron", "chest", n=14, axis="z")
    return g.to_object("body"), [sh.to_object("shield_chest")]


def spitter():
    """Thin and pale in a leather harness, a long neck, and a glowing sac in a cage at the throat."""
    g = Geo()
    SKIN, HARN = (0.5, 0.52, 0.46), (0.12, 0.09, 0.07)
    b = human(g, SKIN, (0.4, 1.0, 0.7, 0.0), macro={"gender": 0.4, "age": 0.9, "muscle": 0.1, "weight": 0.05, "proportions": 0.2}, girth=0.9, head=1.1, tris=12000)
    wraps(g, b, ("elbow_",), 0.84, 1.04, (0.3, 0.27, 0.22), seed=1)
    wraps(g, b, ("knee_",), 0.08, 0.26, (0.3, 0.27, 0.22), seed=4)
    g.robe([(0.98, 0.15, 0.11, 0.0), (0.9, 0.16, 0.12, 0.0), (0.62, 0.19, 0.15, 0.0)], (0.22, 0.2, 0.16), "wool", "pelvis", n=40, pleats=8, pleat_amp=0.08, tatter=0.12)
    for sx in (-1, 1):
        strap(g, [V(sx * 0.12, 1.48, -0.1), V(-sx * 0.05, 1.2, -0.17), V(-sx * 0.15, 1.0, -0.12)], HARN)
    g.ball(V(0.0, 1.5, -0.13), 0.09, (0.4, 1.0, 0.7, 0.0), "glow", "head", n=10)
    for k in range(5):
        a = TAU * k / 5
        g.tube([V(math.cos(a) * 0.1 * math.sin(p), 1.5 - 0.1 * math.cos(p), -0.13 + math.sin(a) * 0.1 * math.sin(p)) for p in np.linspace(0.2, math.pi - 0.2, 6)], 0.007, HARN, "leather", "head", n=4)
    # a wrap over the scalp and the eyes down to the cheekbone; the jaw is left bare (it spits)
    rags(g, b, None, (0.34, 0.36, 0.3), HARN, vest=None, seed=2.1, v1=118)
    return g.to_object("body"), []


def cinder_caster():
    """A smith of the dead: bare scorched arms, a heavy leather apron, slag crusted on the skin, goggles in a scorched
    hood, a ladle of slag that glows."""
    COAT, APRON, IRON = (0.17, 0.13, 0.11), (0.3, 0.2, 0.12), (0.2, 0.19, 0.19)
    g = Geo()
    b = human(g, (0.36, 0.3, 0.27), (1.0, 0.5, 0.15, 0.0), macro={"gender": 1.0, "age": 0.6, "muscle": 0.95, "weight": 0.65}, girth=1.05, head=1.05)
    g.robe([(0.98, 0.17, 0.13, 0.0), (0.9, 0.18, 0.14, 0.0), (0.5, 0.2, 0.16, 0.0), (0.3, 0.21, 0.17, 0.0)], COAT, "wool", "pelvis", n=40, pleats=6, pleat_amp=0.05, tatter=0.05)
    belt = contour(b, 0.96, ("chest", "pelvis"), off=0.03, bins=40, band=0.03)
    if belt:
        g.tube([q for _, q in belt] + [belt[0][1]], 0.02, (0.16, 0.11, 0.08), "leather", "pelvis", n=6, flat=0.45)
    hood(g, COAT, eye=(1.0, 0.5, 0.15, 0.0), open_=44)
    # the apron: a heavy hide laid down the front from the breast to the shins, its edges curling off the body
    W = math.radians(46)
    rows = band_rays(b, ("chest", "pelvis"), 0.42, 1.36, 26, 24, t0=math.pi - W, t1=math.pi + W,
                     hem=lambda a: _rag_edge(V(math.sin(a * 3.0), 0, math.cos(a * 3.0)), 1.7, 0.03) + 0.03)
    def bib(i, j):                                     # the bib narrows over the breast: a rounded top, not a slab
        u = abs(j / 26.0 * 2.0 - 1.0)
        v = i / 24.0
        return not (v > 0.62 and u > 0.55 + 0.45 * (1.0 - (v - 0.62) / 0.38) ** 0.5)
    labs = tuple(sorted({l for l in b.L if not l.startswith(("elbow_", "hand_", "foot_", "head"))} - {"head"}))
    shrink(g, b, labs, rows, lambda o, d: 0.02 + 0.05 * min(max((0.95 - float(o[1])) / 0.5, 0.0), 1.0), APRON, "leather",
           B.waist_split(0.92), thick=0.012, fill=True, relax=12, edge=bib,
           wobble=lambda i, j, ni, nj: 0.012 * abs((j / (nj - 1)) * 2.0 - 1.0) ** 3)
    # goggles on the eyes, inside the hood
    for e in b.eyes:
        g.lathe([(0.0, 0.0), (0.024, 0.0), (0.024, 0.016)], e + V(0, 0, -0.01), IRON, "iron", "head", n=12, axis="z")
        g.ball(e + V(0, 0, -0.024), 0.02, (1.0, 0.55, 0.2, 0.0), "glow", "head", n=8, sz=0.35)
    if len(b.eyes) == 2:
        a, c2 = b.eyes[0], b.eyes[1]
        g.tube([a + V(0, 0, -0.018), (a + c2) * 0.5 + V(0, 0.004, -0.03), c2 + V(0, 0, -0.018)], 0.005, IRON, "iron", "head", n=5)
    l = Geo()
    l.tube([V(0, 0.05, -0.03), V(0, -0.3, -0.03), V(0, -0.5, -0.1)], 0.014, IRON, "iron", "hand_r", n=6)
    l.lathe([(0.0, -0.08), (0.07, -0.06), (0.08, 0.0), (0.075, 0.01)], V(0, -0.55, -0.16), IRON, "iron", "hand_r", n=14)
    l.ball(V(0, -0.555, -0.16), 0.06, (1.0, 0.45, 0.1, 0.0), "glow", "hand_r", n=8, sy=0.3)
    return g.to_object("body"), [l.to_object("staff_hand_r")]


# --- the four-legged kinds (QuadRig) -------------------------------------------------------------------

def quad_sockets(BH, BL, HSP, UL, upright):
    """Rest sockets of a QuadRig (core/enemy/quad_rig.gd), as the rig builds them."""
    s = {"body": V(0, BH, 0)}
    s["front"] = s["body"] + V(0, 0.04, -BL * 0.45)
    s["head"] = s["front"] + V(0, 0.03, -0.16)
    s["tail"] = s["body"] + V(0, 0.02, BL * 0.45)
    for tag, sx, front in (("fl", -1, True), ("fr", 1, True), ("bl", -1, False), ("br", 1, False)):
        z = -BL * 0.36 if front else BL * 0.34
        hip = s["body"] + V(sx * HSP, -0.02, z)
        if upright:
            seg = (BH - 0.05) * 0.5
            knee = hip + V(0, -seg, 0.06 if front else -0.08)
            foot = knee + V(0, -seg, -0.04 if front else 0.1)
        else:
            knee = hip + V(sx * UL, 0.1, 0.0)
            foot = knee + V(sx * 0.07, -(BH + 0.08), 0.0)
        s["leg_%s_hip" % tag], s["leg_%s_knee" % tag], s["leg_%s_foot" % tag] = hip, knee, foot
    return s


QSOCK = {"crawler": (0.34, 0.72, 0.14, 0.24, False), "mite": (0.34, 0.72, 0.14, 0.24, False),
         "burrower": (0.36, 1.05, 0.22, 0.24, False), "leaper": (0.56, 1.15, 0.2, 0.32, True)}


def quad_leg(g, S, tag, col, mat="bone", r=(0.035, 0.028, 0.012), spikes=0, spike_col=None, claw_col=None, extra=None):
    """A leg from hip to knee to foot, labelled in three, a claw at the foot; `extra` = (dz) adds a second leg beside it
    (spiders have eight: the extra pair rides the same bones)."""
    hip, knee, foot = S["leg_%s_hip" % tag], S["leg_%s_knee" % tag], S["leg_%s_foot" % tag]
    for dz in [0.0] + ([extra] if extra else []):
        o = V(0, 0, dz)
        g.tube([hip + o, (hip + knee) * 0.5 + o + V(0, 0.02, 0), knee + o], [r[0], r[0] * 0.95, r[1] * 1.1], col, mat, "leg_%s_hip" % tag, n=10)
        g.tube([knee + o, (knee + foot) * 0.5 + o, foot + o + V(0, 0.03, 0)], [r[1] * 1.1, r[1], r[2] * 1.4], col, mat, "leg_%s_knee" % tag, n=10)
        g.tube([foot + o + V(0, 0.03, 0), foot + o + V(0, -0.0, -0.03), foot + o + V(0, -0.01, -0.07)], [r[2] * 1.4, r[2], 0.002], claw_col or col, mat, "leg_%s_foot" % tag, n=6)
        g.ball(knee + o, r[1] * 1.35, col, mat, "leg_%s_knee" % tag, n=6)
        for k in range(spikes):
            p = knee + o + (foot - knee) * (0.2 + 0.25 * k)
            g.tube([p, p + V(0.03 * np.sign(p[0]), 0.035, 0.0)], [0.009, 0.001], spike_col or col, mat, "leg_%s_knee" % tag, n=4)


def limb_masses(M, pts, radii, steps=4):
    """A limb as masses: along each segment a run of capsules whose radius swells a third of the way and narrows to
    the joint, a knuckle at each joint. pts: joints; radii: (joint, swell) per segment."""
    for i in range(len(pts) - 1):
        a, b = np.asarray(pts[i]), np.asarray(pts[i + 1])
        r0, sw = radii[i]
        r1 = radii[i + 1][0] if i + 1 < len(radii) else r0 * 0.4
        prev = a
        for k in range(1, steps + 1):
            t = k / steps
            q = a + (b - a) * t
            r = r0 + (r1 - r0) * t + (sw - r0) * math.sin(math.pi * min(t * 1.5, 1.0)) * (1.0 - t * 0.5)
            M.append(("c", prev, q, max(r, 0.004)))
            prev = q
        if i > 0:
            M.append(("e", a, (r0 * 1.25, r0 * 1.25, r0 * 1.25)))


def spider_legs(g, S, col, mat, r=(0.016, 0.024, 0.012), extra=0.1, claw_col=None, spikes=0):
    """Eight jointed legs as one modelled piece: a swollen femur arching up to the knee, a long tibia down to a hooked
    tip, knuckled joints; the second pair of each side rides the same bones."""
    for tag in ("fl", "fr", "bl", "br"):
        hip, knee, foot = S["leg_%s_hip" % tag], S["leg_%s_knee" % tag], S["leg_%s_foot" % tag]
        dz = extra if tag[0] == "f" else -extra
        for o in (V(0, 0, 0), V(0, 0, dz)):
            M = []
            limb_masses(M, [hip + o, knee + o + V(0, 0.02, 0)], [(r[0], r[1])], steps=5)
            limb_masses(M, [knee + o + V(0, 0.02, 0), foot + o + V(0, 0.03, 0)], [(r[0] * 0.9, r[0] * 1.15)], steps=5)
            g.meta(M, col, mat, lambda p, tag=tag: "leg_%s_hip" % tag if np.linalg.norm(p - S["leg_%s_hip" % tag]) < np.linalg.norm(p - S["leg_%s_knee" % tag]) * 0.9 else "leg_%s_knee" % tag,
                   res=0.006, tris=500, smooth=1)
            g.tube([foot + o + V(0, 0.035, 0), foot + o + V(0, 0.005, -0.02), foot + o + V(0, -0.005, -0.05)], [r[2], r[2] * 0.7, 0.002], claw_col or col, "iron", "leg_%s_foot" % tag, n=6)
            for k in range(spikes):
                p = knee + o + (foot - knee) * (0.25 + 0.25 * k)
                g.tube([p, p + V(0.025 * np.sign(p[0]), 0.03, 0.0)], [0.007, 0.001], col, mat, "leg_%s_knee" % tag, n=4)


def shell(g, c, rx, ry, rz, col, mat, lab, bands=6, gap=0.012, flare=0.0, front=-1.0):
    """A segmented carapace: overlapping bands along z, each a half-shell with a lifted back edge."""
    for k in range(bands):
        z0 = -rz + 2.0 * rz * k / bands
        z1 = -rz + 2.0 * rz * (k + 1) / bands + gap * 2.0
        def band(u, v, z0=z0, z1=z1):
            th = (u - 0.5) * math.pi * 1.15
            z = z0 + (z1 - z0) * v
            t = z / rz
            prof = max(0.0, 1.0 - t * t) ** 0.5
            lift = 1.0 + 0.06 * v + flare * v
            return c + V(math.sin(th) * rx * prof * lift, math.cos(th) * ry * prof * lift - 0.0, z)
        g.plate(band, 15, 4, col, mat, lab)


def quad_part_label(S, keys):
    def f(p):
        return min(keys, key=lambda k: float(np.linalg.norm(p - S[k])))
    return f


def crawler():
    """A bone spider: a skull for a head, a banded carapace, a lit sac in a cage of ribs behind, eight jointed legs."""
    S = quad_sockets(*QSOCK["crawler"])
    g = Geo()
    BONE, CHIT, DARK = (0.78, 0.72, 0.6), (0.24, 0.2, 0.18), (0.03, 0.025, 0.03)
    lab = quad_part_label(S, ["front", "body", "tail"])
    shell(g, S["body"] + V(0, 0.04, -0.05), 0.17, 0.1, 0.2, CHIT, "iron", lab, bands=5)
    g.ball(S["body"] + V(0, 0.0, -0.05), 0.15, DARK, "iron", lab, n=10, sy=0.6, sz=1.4)
    sac = S["tail"] + V(0, 0.05, 0.06)
    g.ball(sac, 0.15, (1.0, 0.4, 0.15, 0.0), "glow", "tail", n=10, sy=0.85, sz=1.1)
    for k in range(5):
        a = -0.5 + k * 0.25
        g.tube([sac + V(math.sin(a) * 0.17 * math.sin(p), 0.17 * math.cos(p) * 0.85, math.cos(a) * 0.0 + (p - 1.57) * 0.1) for p in np.linspace(0.3, 2.9, 8)], 0.012, BONE, "bone", "tail", n=5)
    for k in range(6):
        p = sac + V(0, 0.0, -0.18 + 0.07 * k)
        g.tube([p + V(-0.18, -0.02, 0), p + V(-0.05, 0.16, 0), p + V(0.05, 0.16, 0), p + V(0.18, -0.02, 0)], 0.011, BONE, "bone", "tail", n=5)
    H = S["head"]
    skull(g, H + V(0, 0.0, 0.03), BONE, (0.6, 0.55, 0.45), DARK, (1.0, 0.3, 0.15, 0.0), s=0.95, horns=False, muzzle=0.75)
    for sx in (-1, 1):
        g.tube([H + V(sx * 0.03, -0.05, -0.09), H + V(sx * 0.05, -0.09, -0.13), H + V(sx * 0.02, -0.12, -0.16)], [0.012, 0.008, 0.002], BONE, "bone", "head", n=5)
        g.tube([H + V(sx * 0.05, 0.05, 0.0), H + V(sx * 0.08, 0.12, 0.03), H + V(sx * 0.07, 0.16, 0.08)], [0.012, 0.007, 0.001], BONE, "bone", "head", n=5)
    spider_legs(g, S, BONE, "bone", r=(0.018, 0.028, 0.012), claw_col=DARK, spikes=2)
    return g.to_object("body"), [], S


def mite():
    """A blood-tick: a round cracked shell over a cyan sac that glows through its seams, a small armoured head, eight legs."""
    S = quad_sockets(*QSOCK["mite"])
    g = Geo()
    CHIT, DARK, GLOW = (0.32, 0.3, 0.34), (0.03, 0.03, 0.035), (0.3, 1.0, 0.85, 0.0)
    lab = quad_part_label(S, ["front", "body", "tail"])
    c = S["body"] + V(0, 0.03, 0.04)
    g.ball(c, 0.25, GLOW, "glow", lab, n=12, sy=0.7, sz=1.1)
    for k in range(8):                                                   # the shell: meridian plates with gaps of light
        a0 = TAU * k / 8 + 0.05
        def pl(u, v, a0=a0):
            a = a0 + u * (TAU / 8 - 0.12)
            ph = 0.15 + v * 1.25
            return c + V(math.cos(a) * math.sin(ph) * 0.27, math.cos(ph) * 0.2 + 0.0, math.sin(a) * math.sin(ph) * 0.29)
        g.plate(pl, 4, 7, CHIT, "iron", lab)
    H = S["head"] + V(0, -0.04, 0.06)
    g.ball(H, 0.075, CHIT, "iron", "head", n=8, sx=1.1, sy=0.75)
    for sx in (-1, 1):
        for k in (0, 1):
            g.ball(H + V(sx * (0.025 + 0.025 * k), 0.035, -0.055 + 0.015 * k), 0.012, GLOW, "glow", "head", n=5)
        g.tube([H + V(sx * 0.02, -0.03, -0.06), H + V(sx * 0.03, -0.06, -0.12)], [0.012, 0.002], DARK, "iron", "head", n=5)
    spider_legs(g, S, CHIT, "iron", r=(0.014, 0.022, 0.009), claw_col=DARK)
    return g.to_object("body"), [], S


def burrower():
    """A digger in banded stone-plate, like an armadillo of slate: a blunt shovel snout, amber deep in the seams,
    forelimbs ending in broad digging claws."""
    S = quad_sockets(*QSOCK["burrower"])
    g = Geo()
    PLATE, DARK, CLAW = (0.4, 0.38, 0.34), (0.03, 0.025, 0.02), (0.2, 0.19, 0.18)
    lab = quad_part_label(S, ["front", "body", "tail"])
    g.ball(S["body"] + V(0, -0.02, 0.0), 0.26, (1.0, 0.55, 0.2, 0.0), "glow", lab, n=10, sy=0.5, sz=2.0)
    shell(g, S["body"] + V(0, 0.0, 0.0), 0.3, 0.22, 0.5, PLATE, "stone", lab, bands=8, gap=0.015, flare=0.05)
    H = S["head"] + V(0, -0.05, 0.0)
    g.lathe([(0.0, 0.0), (0.1, 0.02), (0.13, 0.1), (0.11, 0.2), (0.06, 0.27), (0.0, 0.28)], H + V(0, 0, 0.12), PLATE, "stone", "head", n=14, axis="z", squash=0.7)
    for sx in (-1, 1):
        g.ball(H + V(sx * 0.06, 0.04, -0.06), 0.016, (1.0, 0.55, 0.2, 0.0), "glow", "head", n=5)
    g.lathe([(0.0, 0.0), (0.035, 0.0), (0.03, 0.06)], H + V(0, -0.02, -0.15), DARK, "iron", "head", n=10, axis="z")
    lab = quad_label(S, torso_r=0.2)
    M = [("e", S["body"] + V(0, -0.05, 0.0), (0.24, 0.15, 0.46)), ("e", S["head"] + V(0, -0.06, 0.12), (0.11, 0.1, 0.12))]
    for tag in ("fl", "fr", "bl", "br"):                                  # sprawled limbs: a heavy upper limb, a thick forearm
        h, k, f = S["leg_%s_hip" % tag], S["leg_%s_knee" % tag], S["leg_%s_foot" % tag]
        M += [("e", h + (k - h) * 0.35, (0.1, 0.075, 0.08)), ("c", h, k, 0.055), ("c", k, f + V(0, 0.04, 0.0), 0.045),
              ("e", k + (f - k) * 0.3, (0.055, 0.07, 0.055)), ("e", f + V(0, 0.025, -0.03), (0.06, 0.03, 0.065))]
    g.meta(M, (0.2, 0.17, 0.15), "skin", lab, res=0.014, tris=6000)
    for tag in ("fl", "fr", "bl", "br"):                                  # the limbs plated too: overlapping scutes, each lapping the next
        h, k, f = S["leg_%s_hip" % tag], S["leg_%s_knee" % tag], S["leg_%s_foot" % tag]
        for a, b2, R, lb in ((h, k, 0.092, "leg_%s_hip" % tag), (k, f + V(0, 0.04, 0.0), 0.062, "leg_%s_knee" % tag)):
            ax = b2 - a
            for t in range(4):
                p0 = a + ax * (0.04 + 0.23 * t)
                p1 = a + ax * (0.04 + 0.23 * t + 0.27)
                shade = 1.0 - 0.08 * (t % 2)
                g.tube([p0, p0 + (p1 - p0) * 0.5, p1], [R * 1.02, R * 1.12, R * 1.18], tuple(c * shade for c in PLATE), "stone", lb, n=12, flat=0.85)
        if tag[0] == "f":
            foot = S["leg_%s_foot" % tag]
            for k in range(3):
                g.tube([foot + V((k - 1) * 0.03, 0.03, -0.02), foot + V((k - 1) * 0.04, 0.0, -0.1), foot + V((k - 1) * 0.045, -0.02, -0.16)], [0.016, 0.012, 0.002], CLAW, "iron", "leg_%s_foot" % tag, n=6)
    tl = [S["tail"] + V(0, -0.02 - 0.03 * k, 0.08 * k) for k in range(5)]
    g.tube(tl, [0.1, 0.085, 0.065, 0.045, 0.01], PLATE, "stone", "tail", n=10)
    return g.to_object("body"), [], S


def quad_label(S, torso_r=0.12):
    """Skinning labels for a quad by segment, as body_label does for the biped: the spine in three, the head, and
    each leg in three (hip->knee is the thigh's bone, knee->foot the shin's). Torso distances count from its skin."""
    segs = [("tail", S["tail"], S["tail"] + V(0, -0.15, 0.7), 0.0), ("body", S["body"] + V(0, 0, 0.35), S["body"] + V(0, 0, -0.25), torso_r),
            ("front", S["front"] + V(0, 0, 0.25), S["front"], torso_r), ("head", S["front"] + V(0, 0.02, -0.08), S["head"] + V(0, 0, -0.25), 0.0)]
    for tag in ("fl", "fr", "bl", "br"):
        h, k, f = S["leg_%s_hip" % tag], S["leg_%s_knee" % tag], S["leg_%s_foot" % tag]
        segs += [("leg_%s_hip" % tag, h, k, 0.0), ("leg_%s_knee" % tag, k, f, 0.0), ("leg_%s_foot" % tag, f, f + V(0, -0.02, -0.1), 0.0)]

    def lab(p):
        best, bd = "body", 9.0
        for nm, a, c, r in segs:
            ab = c - a
            t = min(max(float((p - a) @ ab) / max(float(ab @ ab), 1e-9), 0.0), 1.0)
            d = float(np.linalg.norm(p - (a + ab * t))) - r
            if d < bd:
                best, bd = nm, d
        return best
    return lab


def skull(g, H, BONE, OLD, DARK, eye, s=1.0, lab="head", horns=True, muzzle=1.0):
    """A beast's skull, modelled in bone masses: a vaulted cranium, a long muzzle, cheek arches, a brow, the sockets
    sunk into it with coals in them, a lower jaw hung open a little, teeth along both, horns swept back."""
    o = lambda x, y, z: H + V(x, y, z) * s
    g.meta([("e", o(0, 0.04, 0.03), (0.065 * s, 0.058 * s, 0.075 * s)),
            ("c", o(0, 0.025, -0.03), o(0, 0.0, -0.165 * muzzle), 0.036 * s),
            ("e", o(0, -0.002, -0.17 * muzzle), (0.03 * s, 0.024 * s, 0.03 * s)),
            ("e", o(0.052, 0.008, -0.03), (0.022 * s, 0.022 * s, 0.05 * s)), ("e", o(-0.052, 0.008, -0.03), (0.022 * s, 0.022 * s, 0.05 * s)),
            ("e", o(0, 0.062, -0.035), (0.058 * s, 0.018 * s, 0.03 * s)),
            ("e", o(0.043, 0.034, -0.058), (0.021 * s, 0.019 * s, 0.022 * s), True), ("e", o(-0.043, 0.034, -0.058), (0.021 * s, 0.019 * s, 0.022 * s), True),
            ("e", o(0, -0.02, -0.12), (0.022 * s, 0.012 * s, 0.05 * s), True)],
           BONE, "bone", lab, res=0.006 * s, tris=2400, smooth=1)
    for sx in (-1, 1):
        g.tube([o(sx * 0.045, -0.025, 0.02), o(sx * 0.035, -0.05, -0.06), o(sx * 0.012, -0.055, -0.15)], [0.016 * s, 0.013 * s, 0.01 * s], OLD, "bone", lab, n=7)
        g.ball(o(sx * 0.043, 0.034, -0.05), 0.011 * s, eye, "glow", lab, n=5)
        g.ball(o(sx * 0.043, 0.034, -0.044), 0.019 * s, DARK, "iron", lab, n=6)
        if horns:
            g.tube([o(sx * 0.05, 0.08, 0.04), o(sx * 0.09, 0.14, 0.13), o(sx * 0.1, 0.13, 0.25)], [0.018 * s, 0.012 * s, 0.002 * s], OLD, "bone", lab, n=7)
    for k in range(7):
        x = (k - 3) * 0.011
        z = -0.17 * muzzle + abs(k - 3) * 0.022
        g.tube([o(x * 1.5, -0.015, z), o(x * 1.5, -0.045, z - 0.004)], [0.0055 * s, 0.001], BONE, "bone", lab, n=4)
        g.tube([o(x * 1.4, -0.05, z + 0.012), o(x * 1.4, -0.025, z + 0.01)], [0.005 * s, 0.001], BONE, "bone", lab, n=4)


def fur(g, k0, k1, sel, count, col, lab, length=(0.06, 0.11), width=0.012, seed=3, lie=V(0.0, 0.0, 1.0), droop=0.5, rise=0.45):
    """Coarse fur as geometry (the creatures' shader has no alpha cards): `count` locks planted on the skin built in
    g.v[k0:k1] where sel(p, n) passes, each a flat tapered strand of 5 segments that leaves the skin along its normal,
    lies back along `lie` and droops; dark at the root, lighter at the tip, a few broken short."""
    rng = np.random.RandomState(seed)
    P = np.array(g.v[k0:k1])
    N = np.zeros_like(P)
    for f in g.faces:
        if f[0] < k0 or f[0] >= k1:
            continue
        a, b2, c = (g.v[f[0]], g.v[f[1]], g.v[f[2]])
        n = np.cross(b2 - a, c - a)
        for v in f:
            if k0 <= v < k1:
                N[v - k0] += n
    N /= np.maximum(np.linalg.norm(N, axis=1, keepdims=True), 1e-12)
    cen = P.mean(axis=0)
    if float(np.sum(N * (P - cen), axis=1).mean()) < 0.0:
        N = -N
    ok = [i for i in range(len(P)) if sel(P[i], N[i])]
    if not ok:
        return
    lie = np.asarray(lie, dtype=np.float64) / max(np.linalg.norm(lie), 1e-9)
    for _ in range(count):
        i = ok[rng.randint(len(ok))]
        p, n = P[i], N[i]
        ln = rng.uniform(*length) * (0.45 if rng.rand() < 0.12 else 1.0)
        d = n * rise + lie * 0.9
        d /= max(np.linalg.norm(d), 1e-9)
        pts, ws = [], []
        q = p - n * 0.004
        for k in range(6):
            t = k / 5.0
            pts.append(q.copy())
            ws.append(width * (1.0 - t ** 1.6) + 0.0008)
            step = d * (ln / 5.0)
            step[1] -= droop * ln / 5.0 * t
            q = q + step
        dark = 0.75 + 0.35 * rng.rand()
        cc = tuple(min(c * dark, 1.0) for c in col)
        g.tube(pts, ws, cc, "wool", lab(p) if callable(lab) else lab, n=3, flat=0.3)


def leaper():
    """A bone-plated hound, built as an animal is blocked out: one skin over a spine of radii (a deep keel of a chest,
    a tucked waist, a heavy rump), muscled thighs and forearms down to paws, a skull for a face with coals in it,
    plates down the spine and over the shoulders and haunches, a lash of a tail."""
    S = quad_sockets(*QSOCK["leaper"])
    g = Geo()
    HIDE, BONE, DARK, OLD = (0.27, 0.21, 0.18), (0.8, 0.74, 0.62), (0.02, 0.02, 0.02), (0.6, 0.55, 0.45)
    lab = quad_label(S)
    B0, F0, T0 = S["body"], S["front"], S["tail"]
    M = [("e", V(0, 0.5, -0.28), (0.15, 0.22, 0.24)),                     # the keel: a deep ribcage
         ("e", V(0, 0.62, -0.33), (0.12, 0.08, 0.2)),                     # its back, up to the withers
         ("c", V(0, 0.6, -0.12), V(0, 0.61, 0.2), 0.095),                 # the waist, tucked
         ("e", V(0, 0.43, 0.04), (0.13, 0.08, 0.17), True),               # the tuck under it
         ("e", V(0, 0.6, 0.36), (0.14, 0.13, 0.17)),                      # the rump
         ("c", V(0, 0.6, -0.44), V(0, 0.68, -0.64), 0.085),               # the neck
         ("e", S["head"] + V(0, 0.0, 0.03), (0.065, 0.065, 0.08))]
    for tag in ("fl", "fr", "bl", "br"):
        h, k, f = S["leg_%s_hip" % tag], S["leg_%s_knee" % tag], S["leg_%s_foot" % tag]
        sx = -1.0 if tag[1] == "l" else 1.0
        if tag[0] == "f":
            M += [("e", h + V(-sx * 0.05, 0.06, -0.02), (0.07, 0.13, 0.09)),         # the shoulder and its blade
                  ("c", h + V(-sx * 0.02, 0.0, 0.0), k, 0.05),                       # upper arm to the elbow
                  ("c", k, f + V(0, 0.045, 0.0), 0.032),                             # forearm
                  ("e", k + (f - k) * 0.25 + V(0, 0.0, -0.01), (0.038, 0.06, 0.04)),  # the forearm's muscle
                  ("c", f + V(0, 0.045, 0.0), f + V(0, 0.02, -0.03), 0.026),
                  ("e", f + V(0, 0.02, -0.04), (0.035, 0.022, 0.045))]               # the paw
        else:
            hock = f + V(0, 0.085, 0.045)
            M += [("e", h + V(-sx * 0.03, 0.03, 0.0), (0.08, 0.15, 0.12)),            # the haunch
                  ("c", h, k, 0.055),
                  ("e", (h + k) * 0.5 + V(0, 0.0, 0.03), (0.06, 0.1, 0.075)),        # the thigh's muscle
                  ("c", k, hock, 0.034),
                  ("c", hock, f + V(0, 0.02, -0.02), 0.024),
                  ("e", f + V(0, 0.02, -0.04), (0.035, 0.022, 0.045))]
    tail = [T0 + V(0, -0.02 - 0.008 * k * k, 0.11 * (k + 1)) for k in range(6)]
    pts = [T0 + V(0, 0.0, -0.05)] + tail
    for k in range(len(pts) - 1):
        M.append(("c", pts[k], pts[k + 1], 0.05 - 0.007 * k))
    k0 = len(g.v)
    g.meta(M, HIDE, "skin", lab, res=0.012, tris=9000)
    k1 = len(g.v)
    # a coarse ruff over the neck and the withers, and a crest down the back to the rump, lying back toward the tail
    fur(g, k0, k1, lambda p, n: abs(p[0]) < 0.085 and n[1] > 0.35 and p[1] > 0.58 and p[2] < 0.42,
        420, (0.22, 0.18, 0.15), lab, length=(0.06, 0.13), width=0.012, seed=7, lie=V(0.0, 0.2, 1.0), droop=0.3, rise=0.4)
    fur(g, k0, k1, lambda p, n: p[2] < -0.3 and p[1] > 0.45 and n[1] > -0.4,                                  # the ruff at the throat
        200, (0.3, 0.25, 0.21), lab, length=(0.05, 0.09), width=0.011, seed=11, lie=V(0.0, -0.6, 0.6), droop=0.5, rise=0.35)
    spine = [(V(0, 0.71, z), 0.0, 0.0) for z in (0.45, 0.3, 0.15)] + [(V(0, 0.71, 0.0), 0.0, 0.0), (V(0, 0.72, -0.2), 0.0, 0.0), (V(0, 0.72, -0.38), 0.0, 0.0)]
    # plates down the spine, on the shoulders and the haunches
    for k in range(11):
        t = k / 10
        z = (T0[2] - 0.05) * (1 - t) + (F0[2] - 0.05) * t
        top = max((n[0][1] + n[2] for n in spine if abs(n[0][2] - z) < 0.16), default=B0[1] + 0.12)
        p = V(0, top + 0.005, z)
        g.tube([p + V(0, -0.03, 0.05), p + V(0, 0.05 + 0.02 * math.sin(t * math.pi), -0.02)], [0.026, 0.004], BONE if k % 2 else OLD, "bone", lab(p), n=5)
    skull(g, S["head"] + V(0, 0.0, -0.03), BONE, OLD, DARK, (1.0, 0.45, 0.15, 0.0), s=1.4)
    for tag in ("fl", "fr", "bl", "br"):                                   # claws
        f = S["leg_%s_foot" % tag]
        for k in range(3):
            g.tube([f + V((k - 1) * 0.018, 0.02, -0.05), f + V((k - 1) * 0.02, 0.0, -0.075)], [0.007, 0.001], BONE, "bone", "leg_%s_foot" % tag, n=4)
    g.tube([tail[-1], tail[-1] + V(0, 0.02, 0.12)], [0.012, 0.002], BONE, "bone", "tail", n=6)
    return g.to_object("body"), [], S


def thornwarden():
    """The Thornwarden, a walking thicket: a long body plated in bark with ember in the cracks, thorns down the spine,
    a deer's skull with coals deep in the sockets under a crown of branching antlers, root-gripped hooves, a heavy
    bramble tail. Labelled with his old socket names so boss_thornwarden_anim.py's skeleton and clips carry it."""
    S = quad_sockets(0.56, 1.15, 0.2, 0.32, True)
    g = Geo()
    BARK, DARKB, BONE, EMBER, DARK = (0.42, 0.32, 0.21), (0.3, 0.22, 0.15), (0.8, 0.74, 0.62), (1.0, 0.42, 0.1, 0.0), (0.02, 0.015, 0.012)
    lab = quad_label(S, torso_r=0.15)
    B0, F0, T0 = S["body"], S["front"], S["tail"]
    M = [("e", V(0, 0.52, -0.28), (0.17, 0.24, 0.27)), ("e", V(0, 0.66, -0.34), (0.14, 0.09, 0.2)),
         ("c", V(0, 0.62, -0.1), V(0, 0.64, 0.2), 0.12), ("e", V(0, 0.44, 0.04), (0.13, 0.08, 0.17), True),
         ("e", V(0, 0.63, 0.36), (0.16, 0.15, 0.19)), ("c", V(0, 0.62, -0.44), V(0, 0.74, -0.62), 0.1)]
    for tag in ("fl", "fr", "bl", "br"):
        h, k, f = S["leg_%s_hip" % tag], S["leg_%s_knee" % tag], S["leg_%s_foot" % tag]
        sx = -1.0 if tag[1] == "l" else 1.0
        if tag[0] == "f":
            M += [("e", h + V(-sx * 0.05, 0.06, -0.02), (0.08, 0.15, 0.1)), ("c", h + V(-sx * 0.02, 0.0, 0.0), k, 0.058),
                  ("c", k, f + V(0, 0.06, 0.0), 0.036), ("e", k + (f - k) * 0.25, (0.045, 0.07, 0.045))]
            ank = f + V(0, 0.06, 0.0)
        else:
            ank = f + V(0, 0.1, 0.05)
            M += [("e", h + V(-sx * 0.03, 0.03, 0.0), (0.09, 0.17, 0.13)), ("c", h, k, 0.062), ("e", (h + k) * 0.5 + V(0, 0, 0.03), (0.07, 0.11, 0.085)),
                  ("c", k, ank, 0.036), ("c", ank, f + V(0, 0.05, -0.01), 0.03)]
        M += [("c", ank, f + V(0, 0.035, -0.015), 0.03)]
    tail = [T0 + V(0, -0.02 - 0.05 * k * k * 0.1, 0.13 * k) for k in range(6)]
    for k in range(5):
        M.append(("c", tail[k], tail[k + 1], 0.1 - 0.016 * k))
    P = g.meta(M, DARKB, "wood", lab, res=0.014, tris=10000)
    P = np.array(P)

    def surf(p, d):
        """The body's surface from p looking along d: the vertex furthest along d within a slab round p."""
        d = d / np.linalg.norm(d)
        near = P[np.abs(P[:, 2] - p[2]) < 0.035]
        if len(near) == 0:
            return p
        return near[int(np.argmax((near - p) @ d))]
    crack = []                                                           # the heart, a burning split down the breast
    for yy in np.linspace(0.62, 0.36, 7):
        near = P[(np.abs(P[:, 1] - yy) < 0.025) & (np.abs(P[:, 0]) < 0.05) & (P[:, 2] < F0[2] + 0.25)]
        if len(near):
            q = near[int(np.argmin(near[:, 2]))]
            crack.append(V(0.012 * math.sin(yy * 60.0), q[1], q[2] + 0.004))
    if len(crack) > 2:
        g.tube(crack, [0.008] + [0.02] * (len(crack) - 2) + [0.006], EMBER, "glow", "front", n=6, flat=0.45)
    for k in range(13):                                                  # bark plates in rows down both flanks and the back
        t = k / 12
        z = (T0[2] + 0.02) * (1 - t) + (F0[2] - 0.08) * t
        axis = V(0, 0.6 if t > 0.3 else 0.62, z)
        for sx, ang in ((-1, 0.35), (1, 0.35)):
            c = surf(axis, V(sx * math.sin(ang), math.cos(ang), 0.0)) - V(0, 0.01, 0)
            def pl(u, v, c=c, sx=sx, ang=ang):
                th = (u - 0.5) * 0.9 + sx * ang
                return c + V(math.sin(th) * 0.055, (math.cos(th) - 1.0) * 0.055 - v * 0.08 + 0.012, (v - 0.5) * 0.12 + 0.02 * u)
            g.plate(pl, 4, 3, BARK if (k + sx) % 2 else DARKB, "wood", lab(c))
    for k in range(11):                                                  # thorns down the spine
        t = 0.08 + k / 12
        z = (T0[2]) * (1 - t) + (F0[2] - 0.1) * t
        p = surf(V(0, 0.6, z), V(0, 1.0, 0.0)) + V(0, 0.01, 0)
        h = 0.14 + 0.08 * math.sin(t * math.pi)
        g.tube([p, p + V(0.0, h * 0.6, 0.04), p + V(0.0, h, 0.1)], [0.022, 0.012, 0.001], DARKB, "wood", lab(p), n=5)
    H = S["head"] + V(0, 0.05, -0.02)
    skull(g, H, BONE, (0.62, 0.56, 0.46), DARK, EMBER, s=1.55, horns=False, muzzle=1.15)
    for sx in (-1, 1):
        base = H + V(sx * 0.06, 0.12, 0.06)
        beam = [base, base + V(sx * 0.08, 0.16, 0.04), base + V(sx * 0.16, 0.34, 0.0), base + V(sx * 0.2, 0.5, 0.06), base + V(sx * 0.18, 0.66, 0.14)]
        g.tube(beam, [0.03, 0.026, 0.02, 0.014, 0.004], BONE, "bone", "head", n=8)
        g.ball(base, 0.036, (0.62, 0.56, 0.46), "bone", "head", n=7, sy=0.6)       # the burr where the antler grows
        for k, (i, d) in enumerate(((1, V(sx * 0.1, 0.08, -0.08)), (2, V(sx * 0.02, 0.14, -0.1)), (3, V(sx * 0.1, 0.1, 0.06)), (2, V(sx * 0.12, -0.02, 0.1)))):
            b = beam[i]
            g.tube([b, b + d * 0.5, b + d], [0.016, 0.01, 0.002], BONE, "bone", "head", n=6)
    for tag in ("fl", "fr", "bl", "br"):
        for sx in (-1, 1):                                               # cloven hooves
            g.ball(S["leg_%s_foot" % tag] + V(sx * 0.018, 0.022, -0.03), 0.03, DARK, "iron", "leg_%s_foot" % tag, n=7, sx=0.7, sz=1.3)
        foot = S["leg_%s_foot" % tag]
        for k in range(4):                                               # roots gripping the ground
            a = TAU * k / 4 + 0.4
            g.tube([foot + V(0, 0.04, 0), foot + V(math.cos(a) * 0.08, 0.0, math.sin(a) * 0.08), foot + V(math.cos(a) * 0.14, -0.01, math.sin(a) * 0.14)], [0.022, 0.014, 0.002], DARKB, "wood", "leg_%s_foot" % tag, n=5)
    for k in range(8):
        a = TAU * k / 8
        p = tail[-1]
        g.tube([p, p + V(math.cos(a) * 0.1, math.sin(a) * 0.1, 0.06)], [0.012, 0.001], DARKB, "wood", "tail", n=4)
    return g.to_object("body"), [], S


KINDS = {"wretch": wretch, "husk": husk, "chanter": chanter, "tollman": tollman, "pilgrim": pilgrim, "gaunt": gaunt, "quiller": quiller,
         "ossuant": ossuant, "bulwark": bulwark, "spitter": spitter, "cinder_caster": cinder_caster,
         "crawler": crawler, "mite": mite, "burrower": burrower, "leaper": leaper}


# --- skin and export -----------------------------------------------------------------------------------

def soften(ob, iters=3):
    """Blend the rigid part weights a little across the seams between parts, so a joint bends instead of tearing."""
    me = ob.data
    n = len(me.vertices)
    names = [g.name for g in ob.vertex_groups]
    W = np.zeros((n, len(names)))
    for v in me.vertices:
        for gr in v.groups:
            W[v.index, gr.group] = gr.weight
    e = np.empty(len(me.edges) * 2, dtype=np.int32)
    me.edges.foreach_get('vertices', e)
    e = e.reshape(-1, 2)
    cnt = np.maximum(np.bincount(e.ravel(), minlength=n), 1).astype(np.float64)
    for _ in range(iters):
        s = np.zeros_like(W)
        for k in range(W.shape[1]):
            s[:, k] = np.bincount(e[:, 0], weights=W[e[:, 1], k], minlength=n) + np.bincount(e[:, 1], weights=W[e[:, 0], k], minlength=n)
        W = 0.5 * W + 0.5 * s / cnt[:, None]
    W = W / np.maximum(W.sum(1, keepdims=True), 1e-9)
    for k, nm in enumerate(names):
        g = ob.vertex_groups[nm]
        g.remove(list(range(n)))
        sel = np.nonzero(W[:, k] > 0.02)[0]
        wq = np.round(W[sel, k] * 50.0) / 50.0
        for v in np.unique(wq):
            g.add(sel[wq == v].tolist(), float(v), 'REPLACE')


def armature(sock):
    data = bpy.data.armatures.new("Armature")
    ob = bpy.data.objects.new("Armature", data)
    bpy.context.scene.collection.objects.link(ob)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode='EDIT')
    for nm, at in sock.items():
        b = data.edit_bones.new(nm)
        b.head = bl(at)
        b.tail = bl(at) + Vector((0, 0, 0.06))
        b.roll = 0.0
    bpy.ops.object.mode_set(mode='OBJECT')
    return ob


def build_kind(kind):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    out = KINDS[kind]()
    body, held = out[0], out[1]
    sock = out[2] if len(out) > 2 else SOCK
    soften(body)
    if "--bake" in ARGS:                                                  # the finished way: a high copy baked into four maps
        import bake_kind
        bake_kind.bake(body, kind, size=int(arg("--size", "2048")), extras=held)
    arm = armature(sock)
    body.parent = arm
    md = body.modifiers.new("Armature", 'ARMATURE')
    md.object = arm
    for h in held:                                                            # held things: origin on their socket's joint
        if h.name.startswith("shield_"):                                     # (the shield is drawn in rig space)
            h.data.transform(__import__("mathutils").Matrix.Translation(-bl(sock[h.name.split("_", 1)[1]])))
    if arg("--look") and (sock is SOCK or not held):
        look(kind, [body] + held, arg("--look"))
    bpy.ops.object.select_all(action='DESELECT')
    for o in [arm, body] + held:
        o.select_set(True)
    bpy.context.view_layer.objects.active = arm
    path = os.path.join(ROOT, "art", "models", "grunt_%s.glb" % kind)
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True, export_apply=True, export_yup=True,
                              export_materials='EXPORT', export_vertex_color='ACTIVE', export_active_vertex_color_when_no_material=True,
                              export_normals=True, export_tangents=True, export_texcoords=True, export_skins=True, export_animations=False,
                              export_all_influences=False)
    tris = sum(len(p.vertices) - 2 for p in body.data.polygons)
    print("EXPORTED", kind, tris, "tris")


def look(kind, obs, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_WORKBENCH'
    sc.display.shading.light = 'STUDIO'
    sc.display.shading.color_type = 'VERTEX'
    sc.display.shading.show_cavity = True
    sc.display.shading.show_backface_culling = False
    sc.render.resolution_x, sc.render.resolution_y = 500, 760
    cam = bpy.data.objects.new("C", bpy.data.cameras.new("C"))
    cam.data.lens = 70
    sc.collection.objects.link(cam)
    sc.camera = cam
    held_sock = {}
    for o in obs[1:]:
        o.location = bl(SOCK[o.name.split("_", 1)[1]])
    z = float(arg("--look-zoom", "1.0"))                                  # 0.3: head and chest
    aim = V(0, float(arg("--look-y", "1.0")) + 0.55 * (1.0 - z), 0)
    for name, ang in (("front", 0.0), ("q34", 0.75), ("side", 1.57), ("back", 2.6)):
        cam.location = bl(aim + V(math.sin(ang) * 6.0 * z, 0.3 * z, -math.cos(ang) * 6.0 * z))
        cam.rotation_euler = (bl(aim) - cam.location).to_track_quat('-Z', 'Y').to_euler()
        sc.render.filepath = os.path.join(out_dir, "%s_%s.png" % (kind, name))
        bpy.ops.render.render(write_still=True)
    for o in obs[1:]:
        o.location = (0, 0, 0)
    bpy.data.objects.remove(cam)


def main():
    only = arg("--only")
    for k in (only.split(",") if only else KINDS):
        build_kind(k)


if __name__ == "__main__":
    main()
