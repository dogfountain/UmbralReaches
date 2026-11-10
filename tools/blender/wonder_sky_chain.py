"""The Sky Chain (a wonder, core/world/realm/wonders/sky_chain.gd), modelled by script. No scans, no downloads.

  sky_chain_anchor.glb   the bastion the Order cut into the Crowns' foot: a pilgrims' stair rising along its front to
                         a paved deck, the cradle the first links lie in, the open door, the carved frieze, the
                         bitter-end pylon with its iron ring; one mesh per material set (ashlar / iron / dark),
                         with a simplified -colonly mesh for collision. The model is in WORLD coordinates (Godot
                         metres, the node stays at the origin): the site is fixed (x 56..96, z -139..-122, deck y 17).
  sky_chain_link.glb     the forged link (hi / mid / lo detail as separate meshes) and a small link for the stays.

  tools/blender/run.sh wonder_sky_chain.py -- [--only anchor,link] [--preview DIR]

Blender is Z up, Godot Y up: a Godot point (x, y, z) is the Blender point (x, -z, y), so every builder below takes
Godot coordinates and converts at the vertex. Surfaces are real geometry: the walls are height-field ashlar (coursed
blocks, recessed joints, pillowed faces, chipped corners, erosion), not boxes; detail the game's tiling PBR set
(r37_ashlar / r37_iron) adds on top. Vertex colour is the macro tone (moss on the ledges, damp at the foot, soot
under the cornice, rust under the iron).
"""
import bpy
import bmesh
import math
import os
import sys
import random
from bisect import bisect_right
from mathutils import Vector, Matrix, noise

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
MODELS = os.path.join(ROOT, "art", "models", "wonders")
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ONLY = args[args.index("--only") + 1].split(",") if "--only" in args else []
PREVIEW = args[args.index("--preview") + 1] if "--preview" in args else ""
TILE = {"ashlar": 4.0, "stone": 6.0, "iron": 2.0, "timber": 2.0, "dark": 4.0}

# --- the site (Godot metres) --------------------------------------------------------------------------
XT = 88.0          # the stair's last tread; the landing runs east to X1
X1 = 94.0
ZN, ZW, ZS = -144.0, -127.0, -122.5     # deck's north edge / deck's south edge (wall foot) / stair's south face
DECK = 17.0
ZC = -133.2        # the chain's line
RUN, RISE_MAX = 0.30, 0.215
LAND1, LAND2 = 4.4, 3.4
BASE_Y = -1.2      # the walls go down to here (under the ground)

# the ground as probed (3 m grid), x 48..102 step 3, for rows z -128, -126, -124, -122
GX = [48 + 3 * i for i in range(19)]
GROW = {
    -128: [1, 1, 2, 2, 3, 5, 7, 9, 10, 10, 10, 12, 12, 11, 10, 9, 10, 10, 10],
    -126: [0, 1, 1, 1, 2, 3, 5, 7, 7, 8, 7, 9, 9, 9, 7, 6, 7, 7, 8],
    -124: [0, 0, 0, 1, 1, 2, 3, 4, 5, 6, 6, 6, 6, 6, 5, 4, 4, 5, 5],
    -122: [0, 0, 0, 0, 1, 1, 2, 3, 4, 4, 4, 4, 4, 4, 3, 3, 3, 3, 3],
}


def ground(x, z):
    """Probed ground at (x, z) (bilinear on the table; clamps outside)."""
    zs = sorted(GROW.keys())
    z = max(zs[0], min(zs[-1], z))
    i = max(0, min(len(zs) - 2, bisect_right(zs, z) - 1))
    t = (z - zs[i]) / (zs[i + 1] - zs[i])
    fx = (max(GX[0], min(GX[-1], x)) - GX[0]) / 3.0
    j = min(int(fx), len(GX) - 2)
    u = fx - j

    def row(r):
        return GROW[r][j] * (1 - u) + GROW[r][j + 1] * u
    return row(zs[i]) * (1 - t) + row(zs[i + 1]) * t


# --- noise and small helpers -------------------------------------------------------------------------
def fbm(p, octaves=3, lac=2.0, gain=0.5):
    a, f, s, n = 1.0, 1.0, 0.0, 0.0
    for _ in range(octaves):
        s += a * noise.noise(Vector(p) * f)
        n += a
        a *= gain
        f *= lac
    return s / n


def smooth(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a + 1e-9)))
    return t * t * (3 - 2 * t)


def B(g):
    """Godot (x, y, z) -> Blender."""
    return Vector((g[0], -g[2], g[1]))


# --- plan the stair so every tread clears the hill at the wall's foot -------------------------------------
def plan_stair():
    best = None
    for n_all in range(70, 84):
        rise = (DECK - 0.0) / n_all
        for n1 in range(8, 42):
            for n2 in range(10, 44):
                n3 = n_all - n1 - n2
                if n3 < 8 or n3 > 40:
                    continue
                xs = XT - n_all * RUN - LAND1 - LAND2
                y0 = ground(xs, -126.6) + 0.15
                rise = (DECK - y0) / n_all
                if rise > RISE_MAX or rise < 0.17:
                    continue
                segs = []
                x, y = xs, y0
                for kind, n in (("up", n1), ("flat", LAND1), ("up", n2), ("flat", LAND2), ("up", n3)):
                    if kind == "up":
                        segs.append(dict(up=True, x0=x, x1=x + n * RUN, y0=y, y1=y + n * rise, n=n))
                        x += n * RUN
                        y += n * rise
                    else:
                        segs.append(dict(up=False, x0=x, x1=x + n, y0=y, y1=y, n=0))
                        x += n
                # worst clearance over the hill (north edge of the treads), by sampling
                worst = 1e9
                for sg in segs:
                    m = 12
                    for i in range(m + 1):
                        xx = sg["x0"] + (sg["x1"] - sg["x0"]) * i / m
                        yy = sg["y0"] + (sg["y1"] - sg["y0"]) * i / m
                        worst = min(worst, yy - ground(xx, -126.7))
                score = worst - 0.02 * n_all - 0.01 * abs(n1 - 22) - 0.01 * abs(n2 - 28)
                if best is None or score > best[0]:
                    best = (score, xs, y0, rise, segs, n_all, worst)
    return best


_, XS, Y0, RISE, SEGS, N_ALL, WORST = plan_stair()
DOOR_X = 0.5 * (SEGS[1]["x0"] + SEGS[1]["x1"])
DOOR_Y = SEGS[1]["y0"]


def stair_top(x):
    """The tread surface at x."""
    if x <= XS:
        return Y0
    for sg in SEGS:
        if x <= sg["x1"] + 1e-4:
            if not sg["up"]:
                return sg["y0"]
            i = max(1, min(sg["n"], math.floor((x - sg["x0"]) / RUN - 1e-4) + 1))
            return sg["y0"] + i * RISE
    return DECK


# --- geometry containers ---------------------------------------------------------------------------
class Parts:
    def __init__(self):
        self.bm = {}

    def of(self, key):
        if key not in self.bm:
            self.bm[key] = bmesh.new()
        return self.bm[key]


def quad(P, key, a, b, c, d, out):
    """A quad a-b-c-d in Godot coordinates facing `out` (Godot)."""
    bm = P.of(key)
    va = [bm.verts.new(B(p)) for p in (a, b, c, d)]
    n = (va[1].co - va[0].co).cross(va[2].co - va[0].co)
    if n.dot(B(out) - B((0, 0, 0))) < 0:
        va.reverse()
    bm.faces.new(va)


def bev_box(P, key, c, size, bevel=0.04, seg=1, yaw=0.0, jitter=0.0, rnd=None, tilt=(0.0, 0.0)):
    """A chunky stone/iron block: centre c (Godot), size (x, y, z), eased edges, a little jitter."""
    bm = P.of(key)
    r = rnd or random
    M = (Matrix.Translation(B(c)) @ Matrix.Rotation(-yaw, 4, 'Z') @ Matrix.Rotation(tilt[0], 4, 'X')
         @ Matrix.Rotation(tilt[1], 4, 'Y') @ Matrix.Diagonal((size[0], size[2], size[1], 1.0)))
    res = bmesh.ops.create_cube(bm, size=1.0, matrix=M)
    verts = res["verts"]
    if bevel > 0:
        edges = {e for v in verts for e in v.link_edges}
        bmesh.ops.bevel(bm, geom=list(edges), offset=bevel, segments=seg, affect='EDGES', profile=0.6)
    if jitter > 0:
        for v in {vv for f in bm.faces for vv in f.verts}:
            pass
    return res


def beam(P, key, a, b, w, h=None, up=Vector((0, 0, 1))):
    a, b = B(a), B(b)
    d = b - a
    L = d.length
    q = d.to_track_quat('Y', 'Z')
    M = Matrix.Translation((a + b) * 0.5) @ q.to_matrix().to_4x4() @ Matrix.Diagonal((w, L, h or w, 1.0))
    bmesh.ops.create_cube(P.of(key), size=1.0, matrix=M)


# --- the height-field ashlar wall -------------------------------------------------------------------
class Coursing:
    """A global block pattern for one wall: rows (heights 0.7-1.15) each cut into blocks (1.0-2.7), staggered."""

    def __init__(self, seed, u0, u1, v0, v1, hmin=0.7, hmax=1.15, wmin=1.0, wmax=2.7):
        r = random.Random(seed)
        self.rows = []
        v = v0 - r.uniform(0.0, 0.6)
        ri = 0
        while v < v1 + 1.5:
            h = r.uniform(hmin, hmax)
            cuts = []
            u = u0 - r.uniform(0.0, wmax) - (0.5 * wmax if ri % 2 else 0.0)
            blocks = []
            while u < u1 + wmax:
                w = r.uniform(wmin, wmax)
                blocks.append(dict(u0=u, u1=u + w, bulge=r.uniform(0.015, 0.075), off=r.uniform(-0.035, 0.035),
                                   tu=r.uniform(-0.012, 0.012), tv=r.uniform(-0.012, 0.012), tone=r.uniform(0.82, 1.05),
                                   chip=r.random()))
                u += w
            self.rows.append(dict(v0=v, v1=v + h, blocks=blocks, starts=[b["u0"] for b in blocks]))
            v += h
            ri += 1
        self.starts = [row["v0"] for row in self.rows]

    def at(self, U, V):
        ri = max(0, min(len(self.rows) - 1, bisect_right(self.starts, V) - 1))
        row = self.rows[ri]
        bi = max(0, min(len(row["blocks"]) - 1, bisect_right(row["starts"], U) - 1))
        return row, row["blocks"][bi]


LAST_GROOVE = 0.0
JW = 0.12       # the joint's width (m)
JD = 0.10       # its depth


def block_depth(co, U, V, row, blk, rough=1.0):
    """Offset along the wall's normal at (U, V): grooved joints, rounded blocks, pillowed faces, erosion, chips."""
    du = min(U - blk["u0"], blk["u1"] - U)
    dv = min(V - row["v0"], row["v1"] - V)
    e = min(du, dv)
    groove = 1.0 - smooth(0.0, JW, e)
    global LAST_GROOVE
    LAST_GROOVE = groove
    d = -JD * groove ** 1.15
    d += blk["bulge"] * smooth(0.04, 0.55, e)
    d += blk["off"] + blk["tu"] * (U - (blk["u0"] + blk["u1"]) * 0.5) + blk["tv"] * (V - (row["v0"] + row["v1"]) * 0.5)
    d += rough * 0.022 * fbm(co * 1.7 + Vector((3.1, 1.3, 7.7)), 3)
    d += rough * 0.008 * fbm(co * 6.5, 2)
    # a chipped corner: where a block's corner is near, bite it away on some blocks
    cd = math.hypot(min(du, 0.35), min(dv, 0.35))
    if blk["chip"] > 0.72 and cd < 0.3:
        bite = smooth(0.0, 0.3, 0.3 - cd) * (0.5 + 0.5 * noise.noise(co * 4.0))
        d -= 0.07 * bite * smooth(-0.1, 0.4, noise.noise(co * 2.3))
    return d


def rock_depth(co, U, V, rough=1.0):
    """Living rock, hewn: strata ledges, chisel facets, tool marks, fractures."""
    global LAST_GROOVE
    led = math.sin(V * 2.1 + 3.0 * fbm(co * 0.3, 2) + U * 0.15)
    ledge = 0.22 * smooth(-0.2, 0.2, led) - 0.1
    d = rough * (0.75 * fbm(co * 0.28 + Vector((5, 2, 9)), 3) + ledge + 0.07 * noise.noise(co * 2.6))
    d += 0.02 * math.sin(U * 13.0 + 4.0 * noise.noise(co * 0.9))
    crack = abs(noise.noise(co * 0.55 + Vector((9, 4, 1))))
    if crack < 0.035:
        d -= 0.14 * (1.0 - crack / 0.035)
    LAST_GROOVE = max(0.0, min(1.0, 0.5 - d * 0.9))
    return d


def wall(P, key, o, u, v, n, u0, u1, vlo, vhi, cour, cell=0.14, vlo_fine=None, rough=1.0, skew=None):
    """A height-field wall panel. o + u*U + v*V is the plane (Godot, unit u v n); U in [u0, u1], V from vlo to vhi (each may be
    a number or a function of U); `cell` the grid step; below vlo_fine (a function of U) the grid is coarse (buried).
    `skew`: (U) -> extra offset along n (a batter or an entasis)."""
    nu = max(1, int(round((u1 - u0) / cell)))
    us = [u0 + (u1 - u0) * i / nu for i in range(nu + 1)]
    bm = P.of(key)
    ao_l = bm.verts.layers.float.get("ao") or bm.verts.layers.float.new("ao")
    cols = []
    for U in us:
        lo = vlo(U) if callable(vlo) else vlo
        hi = vhi(U) if callable(vhi) else vhi
        if hi <= lo + 0.02:
            cols.append(None)
            continue
        vf = vlo_fine(U) if vlo_fine else lo
        vs = []
        if vf > lo + 0.3:
            nc = max(1, int(round((vf - lo) / 0.7)))
            vs += [lo + (vf - lo) * i / nc for i in range(nc)]
            lo = vf
        nv = max(1, int(round((hi - lo) / cell)))
        vs += [lo + (hi - lo) * i / nv for i in range(nv + 1)]
        col = []
        for V in vs:
            gpos = o + u * U + v * V
            if cour is None:
                d = rock_depth(gpos, U, V, rough)
            else:
                row, blk = cour.at(U, V)
                d = block_depth(gpos, U, V, row, blk, rough)
            if skew:
                d += skew(U, V)
            if V <= vf - 0.01 and vlo_fine and V < vf - 0.3:
                d = skew(U, V) if skew else 0.0       # buried: flat
            gpos = gpos + n * d
            nv_ = bm.verts.new(B(gpos))
            nv_[ao_l] = 1.0 - 0.55 * LAST_GROOVE
            col.append(nv_)
        cols.append(col)
    nb = B(n) - B((0, 0, 0))
    for i in range(nu):
        a, b = cols[i], cols[i + 1]
        if a is None or b is None:
            continue
        # match by index from the top (the top edge is the panel's silhouette); lower rows may differ in count
        ka, kb = len(a), len(b)
        m = min(ka, kb)
        for j in range(m - 1):
            ia, ib = ka - 1 - j, kb - 1 - j
            f = (a[ia], b[ib], b[ib - 1], a[ia - 1])
            if len({id(x) for x in f}) < 4:
                continue
            nn = (f[1].co - f[0].co).cross(f[2].co - f[0].co)
            try:
                bm.faces.new(f if nn.dot(nb) > 0 else f[::-1])
            except ValueError:
                pass


# ============================================================================================
# THE ANCHOR
# ============================================================================================
def stair_line(x):
    """The stair's nosing line at x (continuous: a slope on the flights, flat on the landings)."""
    if x <= XS:
        return Y0
    for sg in SEGS:
        if x <= sg["x1"] + 1e-4:
            if not sg["up"]:
                return sg["y0"]
            return sg["y0"] + (x - sg["x0"]) * RISE / RUN
    return DECK


# --------------------------------------------------------------------------------------------
# primitives: bevelled bars, extruded polygons, rough blocks, lathes
# --------------------------------------------------------------------------------------------
def bev_box(P, key, c, size, bevel=0.04, seg=1, yaw=0.0, tilt=(0.0, 0.0), rough=0.0, cuts=0):
    """A chunky block: centre c (Godot), size (x, y, z), eased edges. `cuts` subdivides it and `rough` pushes the
    new vertices about (a hewn, not milled, stone)."""
    bm = P.of(key)
    M = (Matrix.Translation(B(c)) @ Matrix.Rotation(-yaw, 4, 'Z') @ Matrix.Rotation(tilt[0], 4, 'X')
         @ Matrix.Rotation(tilt[1], 4, 'Y') @ Matrix.Diagonal((size[0], size[2], size[1], 1.0)))
    res = bmesh.ops.create_cube(bm, size=1.0, matrix=M)
    geom = res["verts"]
    if cuts > 0:
        edges = list({e for v in geom for e in v.link_edges})
        sub = bmesh.ops.subdivide_edges(bm, edges=edges, cuts=cuts, use_grid_fill=True)
        geom = [g for g in sub["geom"] if isinstance(g, bmesh.types.BMVert)] + list(geom)
        geom = list({v for v in geom})
    if bevel > 0 and cuts == 0:
        edges = {e for v in geom for e in v.link_edges}
        bmesh.ops.bevel(bm, geom=list(edges), offset=bevel, segments=seg, affect='EDGES', profile=0.6)
    if rough > 0:
        c0 = B(c)
        for v in geom:
            if not v.is_valid:
                continue
            q = v.co - c0
            v.co += q.normalized() * rough * fbm(v.co * 0.9 + Vector((3, 1, 5)), 3)
    return res


def bbeam(P, key, a, b, w, h, bevel=0.04, seg=2):
    a, b = B(a), B(b)
    d = b - a
    q = d.to_track_quat('Y', 'Z')
    M = Matrix.Translation((a + b) * 0.5) @ q.to_matrix().to_4x4() @ Matrix.Diagonal((w, d.length, h, 1.0))
    bm = P.of(key)
    res = bmesh.ops.create_cube(bm, size=1.0, matrix=M)
    edges = {e for v in res["verts"] for e in v.link_edges}
    bmesh.ops.bevel(bm, geom=list(edges), offset=bevel, segments=seg, affect='EDGES', profile=0.6)


def prism(P, key, poly, z0, z1, shrink=0.015):
    bm = P.of(key)
    cx = sum(p[0] for p in poly) / len(poly)
    cy = sum(p[1] for p in poly) / len(poly)
    pts = []
    for (x, y) in poly:
        dx, dy = x - cx, y - cy
        L = math.hypot(dx, dy) + 1e-6
        pts.append((x - dx / L * shrink, y - dy / L * shrink))
    front = [bm.verts.new(B((x, y, z1))) for x, y in pts]
    back = [bm.verts.new(B((x, y, z0))) for x, y in pts]
    n = len(pts)
    bm.faces.new(front)
    bm.faces.new(back[::-1])
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((front[i], back[i], back[j], front[j]))


def lancet(cx, ys, half, k=1.15, n=8):
    r = half * 2.0 * k
    th = math.acos((half - r) / r)
    cl = cx - half + r
    cr = cx + half - r
    pts = []
    for i in range(n + 1):
        t = math.pi - (math.pi - th) * i / n
        pts.append((cl + r * math.cos(t), ys + r * math.sin(t)))
    for i in range(1, n + 1):
        t = (math.pi - th) * (1 - i / n)
        pts.append((cr + r * math.cos(t), ys + r * math.sin(t)))
    return pts


def lathe(P, key, cx, cz, ys, rfun, seg, dfun=None, cap_top=True, groove_fn=None):
    """A surface of revolution about the vertical axis through (cx, cz): rings at heights ys, radius rfun(y) + dfun(angle, y)."""
    bm = P.of(key)
    ao_l = bm.verts.layers.float.get("ao") or bm.verts.layers.float.new("ao")
    rings = []
    for y in ys:
        ring = []
        for k in range(seg):
            th = math.tau * k / seg
            d = dfun(th, y) if dfun else 0.0
            r = rfun(y) + d
            v = bm.verts.new(B((cx + r * math.cos(th), y, cz + r * math.sin(th))))
            v[ao_l] = max(0.4, 1.0 - 0.7 * (groove_fn(th, y) if groove_fn else 0.0))
            ring.append(v)
        rings.append(ring)
    for i in range(len(rings) - 1):
        for k in range(seg):
            k2 = (k + 1) % seg
            f = (rings[i][k], rings[i][k2], rings[i + 1][k2], rings[i + 1][k])
            nn = (f[1].co - f[0].co).cross(f[2].co - f[0].co)
            out = Vector((rings[i][k].co.x - B((cx, 0, cz)).x, rings[i][k].co.y - B((cx, 0, cz)).y, 0))
            bm.faces.new(f if nn.dot(out) > 0 else f[::-1])
    if cap_top:
        c = bm.verts.new(B((cx, ys[-1] + 0.0, cz)))
        c[ao_l] = 1.0
        for k in range(seg):
            k2 = (k + 1) % seg
            f = (rings[-1][k], rings[-1][k2], c)
            nn = (f[1].co - f[0].co).cross(f[2].co - f[0].co)
            bm.faces.new(f if nn.z > 0 else f[::-1])


def annulus(P, key, cx, cz, r0, r1, y0, y1, seg=48):
    """An iron band: a ring of rectangular section (outer wall r1, inner r0, from y0 to y1)."""
    bm = P.of(key)
    ao_l = bm.verts.layers.float.get("ao") or bm.verts.layers.float.new("ao")
    sets = []
    for (r, y) in ((r1, y0), (r1, y1), (r0, y1), (r0, y0)):
        ring = []
        for k in range(seg):
            th = math.tau * k / seg
            v = bm.verts.new(B((cx + r * math.cos(th), y, cz + r * math.sin(th))))
            v[ao_l] = 1.0
            ring.append(v)
        sets.append(ring)
    c = B((cx, 0, cz))
    for i in range(4):
        a, b = sets[i], sets[(i + 1) % 4]
        for k in range(seg):
            k2 = (k + 1) % seg
            f = (a[k], a[k2], b[k2], b[k])
            nn = (f[1].co - f[0].co).cross(f[2].co - f[0].co)
            mid = sum((v.co for v in f), Vector()) / 4
            out = mid - Vector((c.x, c.y, mid.z))
            if i == 0:
                want = out
            elif i == 1:
                want = Vector((0, 0, 1))
            elif i == 2:
                want = -out
            else:
                want = Vector((0, 0, -1))
            bm.faces.new(f if nn.dot(want) > 0 else f[::-1])


# --------------------------------------------------------------------------------------------
# the mooring
# --------------------------------------------------------------------------------------------
DC = (76.0, -135.6)                 # the capstan's axis (x, z)
Y_A, Y_B = 20.6, 26.9               # the chain's first turn and where it leaves the drum's head
TURNS = 1.25
HEAD_Y = 30.0
LIP_Y = HEAD_Y - 1.4
RING_Z = -142.6                     # the ring hangs from a pin out of the north wall
RING_CY = 22.8


def drum_r(y):
    """The capstan drum's surface radius at height y: a flared foot, a waisted body, a lipped head."""
    if y < DECK + 1.3:
        return 6.5 - 0.7 * (y - DECK) / 1.3
    if y < LIP_Y:
        t = (y - (DECK + 1.3)) / (LIP_Y - (DECK + 1.3))
        return 5.8 - 0.55 * math.sin(math.pi * t)
    t = min(1.0, (y - LIP_Y) / (HEAD_Y - LIP_Y))
    return 5.8 + 0.5 * smooth(0.0, 0.6, t)


def helix_depth(th, y):
    """How deep the chain's groove is cut at (angle, y): the helix the chain lies in, worn into the drum."""
    best = 0.0
    for k in range(-1, 3):
        tt = th + math.tau * k
        if tt < -0.2 or tt > math.tau * TURNS + 0.2:
            continue
        ye = Y_A + (Y_B - Y_A) * tt / (math.tau * TURNS)
        d = abs(y - ye)
        w = 0.62
        if d < w:
            best = max(best, (1.0 - (d / w) ** 2) * smooth(-0.2, 0.4, tt) * (1.0 - smooth(math.tau * TURNS - 0.3, math.tau * TURNS + 0.2, tt)))
    return best


def drum_disp(th, y):
    p = Vector((math.cos(th) * 5.0, y * 1.0, math.sin(th) * 5.0))
    led = math.sin(y * 3.1 + 2.5 * fbm(p * 0.3, 2))
    d = 0.5 * fbm(p * 0.33 + Vector((2, 6, 1)), 3) * 0.7 + 0.07 * smooth(-0.3, 0.3, led) - 0.04
    d += 0.04 * noise.noise(p * 3.1)
    ph = (y * 0.9) % 1.0                       # courses: shallow joints between the drum's built-up rings
    d -= 0.05 * (1.0 - smooth(0.0, 0.07, min(ph, 1.0 - ph)))
    d -= 0.34 * helix_depth(th, y)
    return d


def build_drum(P):
    ys = [DECK - 1.2 + i * 0.4 for i in range(int((HEAD_Y - DECK + 1.2) / 0.4) + 1)]
    ys.append(HEAD_Y)
    lathe(P, "stone", DC[0], DC[1], ys, drum_r, 52, drum_disp, True, lambda th, y: helix_depth(th, y))
    # a rim of socket-holes' stubs: eight capstan bars' sockets (stone lugs) on the head
    for k in range(8):
        a = math.tau * k / 8
        r = 4.3
        bev_box(P, "stone", (DC[0] + r * math.cos(a), HEAD_Y + 0.18, DC[1] + r * math.sin(a)), (1.1, 0.4, 0.85), bevel=0.08, seg=2, yaw=-a, rough=0.12, cuts=1)
    bev_box(P, "iron", (DC[0], HEAD_Y + 0.3, DC[1]), (1.6, 0.25, 1.6), bevel=0.05, seg=2, yaw=0.4)
    # iron: the foot band, the head band (with a bright worn lip), straps up the body, rivets
    annulus(P, "iron", DC[0], DC[1], drum_r(DECK + 1.9) - 0.5, drum_r(DECK + 1.9) + 0.16, DECK + 1.6, DECK + 2.3)
    annulus(P, "iron", DC[0], DC[1], drum_r(LIP_Y + 0.5) - 0.5, drum_r(LIP_Y + 0.5) + 0.2, LIP_Y + 0.25, LIP_Y + 0.95)
    annulus(P, "iron", DC[0], DC[1], drum_r(LIP_Y) - 0.5, drum_r(LIP_Y) + 0.16, LIP_Y - 0.05, LIP_Y + 0.2)
    for band_y in (DECK + 1.95, LIP_Y + 0.6):
        for k in range(32):
            a = math.tau * k / 32 + 0.05
            r = drum_r(band_y) + 0.22
            bev_box(P, "iron", (DC[0] + r * math.cos(a), band_y, DC[1] + r * math.sin(a)), (0.2, 0.2, 0.2), bevel=0.04, seg=2, yaw=-a)
    for k in range(10):
        a = math.tau * (k + 0.5) / 10
        # leave the chain's side clear: straps only where the helix is shallow? straps run under the chain, bound over it
        for (y0, y1) in ((DECK + 2.3, 20.1), (LIP_Y, LIP_Y + 0.3)):
            ym = (y0 + y1) / 2
            r = drum_r(ym) + 0.1
            bev_box(P, "iron", (DC[0] + r * math.cos(a), ym, DC[1] + r * math.sin(a)), (0.34, y1 - y0, 0.1), bevel=0.02, seg=1, yaw=-a + math.pi / 2)


def build_mooring_wall(P):
    """The living rock behind the capstan: the cut face of the bay, hewn, with the ring's boss, pin and wedges."""
    wall(P, "stone", Vector((0, 0, ZN - 0.2)), Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)),
         XS, X1, DECK - 0.4, lambda U: DECK + 14.0 + 3.0 * fbm(Vector((U * 0.12, 3, 1)), 2), None, cell=0.45, rough=1.4)
    xr = DC[0] + drum_r(Y_A) + 0.12
    # the boss: a huge hewn block the ring's pin is driven through
    bev_box(P, "stone", (xr, RING_CY + 0.4, ZN + 0.9), (6.4, 6.2, 2.6), bevel=0.0, rough=0.35, cuts=7)
    bev_box(P, "iron", (xr, RING_CY + 1.5, RING_Z - 1.3 + 0.0), (3.4, 2.4, 0.18), bevel=0.04, seg=1)
    for sx in (-1.3, 1.3):
        for sy in (0.6, 2.4):
            bev_box(P, "iron", (xr + sx, RING_CY + sy, RING_Z - 1.25), (0.5, 0.5, 0.22), bevel=0.08, seg=2)
    # the pin: man-sized, with a head and a key through its tip
    pin_y = RING_CY + 1.45
    a, b = (xr, pin_y, ZN + 1.2), (xr, pin_y, RING_Z + 1.55)
    bbeam(P, "iron", a, b, 0.62, 0.62, 0.12, 2)
    bev_box(P, "iron", (xr, pin_y, ZN + 2.0), (1.0, 1.0, 0.3), bevel=0.1, seg=2)
    bev_box(P, "iron", (xr, pin_y, RING_Z + 1.35), (0.18, 1.3, 0.34), bevel=0.04, seg=1)
    # the ring itself hangs on the pin
    bm = P.of("iron")
    M = Matrix.Translation(B((xr, RING_CY, RING_Z)))
    sweep_link(bm, 5.6, 4.4, 1.0, 20, 5, 16, 41, M=M, hammer=0.1, weld=0.2, variant=1)
    # wedges the size of a man, driven between the boss and the wall, and iron dogs staple the boss to the rock
    for k, (sx, sy, rot) in enumerate(((-3.6, 0.3, 0.1), (3.6, 0.3, -0.1), (-3.1, 3.2, 0.7), (3.1, 3.2, -0.7), (0.0, -3.0, 0.0), (-3.4, -1.9, 0.5), (3.4, -1.9, -0.5))):
        bev_box(P, "iron" if k % 2 else "stone", (xr + sx, RING_CY + sy, ZN + 0.55), (0.95, 1.9, 0.9), bevel=0.06, seg=1, yaw=rot * 0.0, tilt=(0.0, rot * 0.9), rough=0.05, cuts=0)
    # the wall's own reinforcement: iron straps over the boss, bolted
    for sx in (-2.4, 2.4):
        bev_box(P, "iron", (xr + sx, RING_CY + 0.4, ZN + 2.16), (0.5, 6.2, 0.16), bevel=0.03, seg=1)
    # scrape marks: the chain has moved here; a bright, scored patch on the boss under the ring
    bev_box(P, "stone", (xr, RING_CY - 2.6, ZN + 2.0), (1.6, 0.2, 0.5), bevel=0.04, seg=1, rough=0.08, cuts=2)


def deck_extra(xr):
    """The court's wear: the two grooves the chain has dragged between the ring and the drum, scuffs about the drum's foot."""
    def f(U, V):
        d = 0.0
        # grooves along the line the chain takes (x = xr, z from the ring to the drum)
        for off in (-0.55, 0.55):
            dd = abs(U - (xr + off))
            if RING_Z - 0.3 < V < DC[1] + 0.2 and dd < 0.45:
                d -= 0.2 * (1.0 - (dd / 0.45) ** 2) * smooth(RING_Z - 0.3, RING_Z + 1.5, V)
        r = math.hypot(U - DC[0], V - DC[1])
        if 6.2 < r < 8.4:
            d -= 0.05 * smooth(0.0, 1.0, abs(noise.noise(Vector((U * 0.8, V * 0.8, 3)))) * 2)
        return d
    return f


# --------------------------------------------------------------------------------------------
# the lodge, the door, the frieze, the tally
# --------------------------------------------------------------------------------------------
LODGE = (85.0, 94.0, -143.2, -132.0)     # x0, x1, z0 (north), z1 (south face)
LODGE_H = 4.7
ROOF_A = math.radians(36.0)


def build_lodge(P):
    x0, x1, z0, z1 = LODGE
    y0, y1 = DECK, DECK + LODGE_H
    zm = (z0 + z1) / 2
    hz = (z1 - z0) / 2
    rise = math.tan(ROOF_A) * (hz + 0.5)
    cour = Coursing(51, x0 - 2, x1 + 2, y0 - 1, y1 + 8, hmin=0.8, hmax=1.4, wmin=1.2, wmax=3.0)
    # the south face (the door) and the west gable face; the east and north are against the cliff and the neighbour
    wall(P, "ashlar", Vector((0, 0, z1)), Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)), x0, x1, y0, y1, cour, cell=0.34)
    czw = Coursing(53, z0 - 2, z1 + 2, y0 - 1, y1 + 8, hmin=0.8, hmax=1.4, wmin=1.2, wmax=3.0)
    wall(P, "ashlar", Vector((x0, 0, 0)), Vector((0, 0, 1)), Vector((0, 1, 0)), Vector((-1, 0, 0)), z0, z1, y0,
         lambda U: y1 + max(0.0, (1.0 - abs(U - zm) / (hz + 0.05))) * rise, czw, cell=0.34)
    cze = Coursing(54, -z1 - 2, -z0 + 2, y0 - 1, y1 + 8, hmin=0.8, hmax=1.4, wmin=1.2, wmax=3.0)
    wall(P, "ashlar", Vector((x1, 0, 0)), Vector((0, 0, -1)), Vector((0, 1, 0)), Vector((1, 0, 0)), -z1, -z0, y0,
         lambda U: y1 + max(0.0, (1.0 - abs(-U - zm) / (hz + 0.05))) * rise, cze, cell=0.34)
    # the gable's south end: the south wall carries on up to the ridge as a gable too
    # the roof: slate courses on two planes, overhanging
    global JW, JD
    jw, jd = JW, JD
    JW, JD = 0.07, 0.05
    slope = (math.cos(ROOF_A), math.sin(ROOF_A))
    for side in (1, -1):
        zedge = zm + side * (hz + 0.5)
        n = Vector((0, math.cos(ROOF_A), side * math.sin(ROOF_A)))
        v = Vector((0, math.sin(ROOF_A), -side * math.cos(ROOF_A)))
        rl = (hz + 0.5) / math.cos(ROOF_A)
        cs = Coursing(61 + side, x0 - 2, x1 + 2, -1, rl + 2, hmin=0.34, hmax=0.46, wmin=0.45, wmax=0.8)
        o = Vector((0, y1 - math.sin(ROOF_A) * 0.5 - 0.1, zedge))
        wall(P, "ashlar", o, Vector((1, 0, 0)), v, n, x0 - 0.5, x1 + 0.5, 0.0, rl, cs, cell=0.3, rough=0.5)
    JW, JD = jw, jd
    bbeam(P, "ashlar", (x0 - 0.5, y1 + rise + 0.22 - 0.1, zm), (x1 + 0.5, y1 + rise + 0.22 - 0.1, zm), 0.55, 0.4, 0.07, 2)
    # the chimney on the west gable and its pots
    bev_box(P, "ashlar", (x0 + 1.2, y1 + rise + 0.5, zm - 0.0), (1.1, 2.4, 1.1), bevel=0.06, seg=2)
    bev_box(P, "ashlar", (x0 + 1.2, y1 + rise + 1.85, zm), (1.4, 0.3, 1.4), bevel=0.06, seg=2)
    # the door: a lancet arch of voussoirs, dark, iron straps across it; a lancet window each side
    dx = (x0 + x1) / 2
    arch(P, dx, y0, z1 + 0.02, 0.9, 2.5, 0.85)
    for k in (0, 1, 2):
        bev_box(P, "iron", (dx, y0 + 0.55 + k * 0.85, z1 + 0.22), (1.75, 0.2, 0.08), bevel=0.02, seg=1)
    for sx in (-1, 1):
        arch(P, dx + sx * 3.2, y0 + 1.5, z1 + 0.02, 0.38, 1.6, 0.4, dark=True)
    # the eaves' corbels
    for k in range(7):
        xx = x0 + 0.5 + k * (x1 - x0 - 1.0) / 6.0
        bev_box(P, "ashlar", (xx, y1 - 0.25, z1 + 0.2), (0.4, 0.5, 0.5), bevel=0.05, seg=1)


def arch(P, cx, y, z, half, spring, ring_w, dark=True, jamb=True):
    """A pointed arch in a wall (face at z, facing +z): voussoirs, jambs, a dark opening."""
    intr = lancet(cx, y + spring, half)
    ext = lancet(cx, y + spring, half + ring_w)
    for i in range(0, len(intr) - 2, 2):
        prism(P, "ashlar", [intr[i], intr[i + 2], ext[i + 2], ext[i]], z - 0.15, z + 0.55, shrink=0.02)
    if jamb:
        for sgn in (-1, 1):
            yy = y
            i = 0
            while yy < y + spring - 0.05:
                hh = min(0.8 if i % 2 == 0 else 0.55, y + spring - yy)
                wj = ring_w * (1.0 if i % 2 == 0 else 0.74)
                bev_box(P, "ashlar", (cx + sgn * (half + wj / 2), yy + hh / 2, z + 0.2), (wj - 0.03, hh - 0.03, 0.75), bevel=0.04, seg=1)
                yy += hh
                i += 1
    prism(P, "dark", [(cx - half, y), (cx + half, y)] + intr[::-1], z - 0.05, z + 0.12, shrink=0.0)


def door(P):
    """The open door in the stair's north wall at the lower landing, with its worn threshold."""
    cx, y, z = DOOR_X, DOOR_Y, ZW + 0.42
    arch(P, cx, y, z, 1.3, 3.3, 0.75)
    bbeam(P, "ashlar", (cx - 2.6, y + 3.3 + 2.95, z + 0.42), (cx + 2.6, y + 3.3 + 2.95, z + 0.42), 0.4, 0.28, 0.05, 2)
    bev_box(P, "ashlar", (cx, y + 0.1, z + 0.85), (5.2, 0.22, 1.0), bevel=0.05, seg=2)
    bev_box(P, "ashlar", (cx, y + 0.02, z + 1.45), (6.0, 0.14, 0.45), bevel=0.04, seg=1)


GLYPHS = [
    [((0, -1), (0, 1))],
    [((0, -1), (0, 1)), ((-0.5, 0.35), (0.5, 0.35))],
    [((-0.35, -1), (-0.35, 1)), ((0.35, -1), (0.35, 1)), ((-0.35, -0.2), (0.35, -0.2))],
    [((0, -1), (0.7, -1)), ((0.35, -1), (0.35, 1))],
    [((-0.4, 0.9), (0.4, 0.9)), ((0, 0.9), (0, -1))],
    [((-0.5, -1), (0.0, 1)), ((0.0, 1), (0.5, -1))],
]


def frieze(P, xa, xb, y1, z, rows=2, seed=21):
    bev_box(P, "ashlar", ((xa + xb) / 2, y1 - 0.46 * (rows - 1) - 0.0, z + 0.03), (xb - xa + 0.5, 0.95 * rows + 0.25, 0.12), bevel=0.03, seg=1)
    rg = random.Random(seed)
    for row in range(rows):
        y = y1 - row * 0.95
        for ys in (y + 0.45, y - 0.45):
            bev_box(P, "ashlar", ((xa + xb) / 2, ys, z + 0.1), (xb - xa, 0.05, 0.06), bevel=0.01, seg=1)
        n = int((xb - xa) / 0.5)
        for i in range(n):
            gx = xa + 0.35 + i * (xb - xa - 0.7) / n
            if rg.random() < 0.12:
                continue
            for (p0, p1) in rg.choice(GLYPHS):
                a = (gx + p0[0] * 0.14, y + p0[1] * 0.3, z + 0.1)
                b = (gx + p1[0] * 0.14, y + p1[1] * 0.3, z + 0.1)
                if (Vector(b) - Vector(a)).length > 0.05:
                    bbeam(P, "ashlar", a, b, 0.045, 0.05, 0.008, 1)


TALLY = (86.6, DECK, -130.4)             # the tally stone's foot (the secret's marker)


def build_tally(P):
    tx, ty, tz = TALLY
    bev_box(P, "stone", (tx, ty + 0.85, tz), (1.3, 1.7, 0.4), bevel=0.0, rough=0.06, cuts=4)
    bev_box(P, "stone", (tx, ty + 1.75, tz), (1.5, 0.2, 0.6), bevel=0.0, rough=0.05, cuts=3)
    for i in range(5):
        for t in range(4):
            bbeam(P, "dark", (tx - 0.5 + i * 0.22 + t * 0.035, ty + 0.55, tz + 0.21), (tx - 0.5 + i * 0.22 + t * 0.035, ty + 1.5, tz + 0.21), 0.03, 0.03, 0.004, 1)
        bbeam(P, "dark", (tx - 0.52 + i * 0.22, ty + 0.62, tz + 0.21), (tx - 0.42 + i * 0.22 + 0.1, ty + 1.42, tz + 0.21), 0.03, 0.03, 0.004, 1)
    bev_box(P, "stone", (tx - 1.5, ty + 0.2, tz + 0.5), (1.0, 0.4, 1.1), bevel=0.0, rough=0.06, cuts=3)      # the kneeling stone


# --------------------------------------------------------------------------------------------
# the bay: court, stair, walls, ribs
# --------------------------------------------------------------------------------------------
def rib(P, x, seed, top_s):
    """A buttress that grows out of the wall: cyclopean hewn blocks stacked in a concave batter, wide and deep at the foot,
    each block rough from the chisel, set a little out of true; an iron strap bolted up its face."""
    rg = random.Random(seed)
    gl = ground(x, -122.0)
    y = gl - 1.4
    top = top_s(x) - 0.25
    total = top - y
    i = 0
    while y < top - 0.35:
        t = (y - (gl - 1.4)) / total
        hh = min(rg.uniform(0.95, 1.5), top - y)
        w = 1.9 + 3.0 * (1.0 - t) ** 1.2
        proj = 0.6 + 5.0 * (1.0 - t) ** 1.8
        nb = 1 if w < 2.6 else 2
        for j in range(nb):
            bw = w / nb
            cx = x - w / 2 + bw * (j + 0.5) + rg.uniform(-0.12, 0.12)
            bev_box(P, "stone", (cx, y + hh / 2, ZS + proj / 2 + 0.3 + rg.uniform(-0.1, 0.1)), (bw - 0.08, hh - 0.06, proj),
                    bevel=0.0, tilt=(rg.uniform(-0.03, 0.03), rg.uniform(-0.03, 0.03)), rough=0.16, cuts=2)
        y += hh
        i += 1
    bev_box(P, "stone", (x, top + 0.1, ZS + 0.7), (1.7, 0.3, 1.5), bevel=0.0, rough=0.08, cuts=3)
    ym = (gl + top) / 2
    bev_box(P, "iron", (x, ym + 0.4, ZS + 0.5), (0.3, top - gl - 1.2, 0.07), bevel=0.02, seg=1)


def build_anchor():
    P = Parts()
    zin, zout = ZW + 0.4, ZS - 0.9
    # --- the south face: heavy rusticated ashlar the stair's outer wall, growing out of the hill in ribs ---
    cour_s = Coursing(3, XS - 2, X1 + 2, BASE_Y, DECK + 3, hmin=0.9, hmax=1.7, wmin=1.6, wmax=4.2)

    def top_s(U):
        return stair_line(U) + 0.95 if U < XT else DECK + 0.95

    def lo_s(U):
        return ground(U, -122.5) - 0.6

    global JW, JD
    jw, jd = JW, JD
    JW, JD = 0.16, 0.14
    wall(P, "ashlar", Vector((0, 0, ZS)), Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)),
         XS, X1, lo_s, top_s, cour_s, cell=0.34, rough=1.6)
    JW, JD = jw, jd
    pts = [(XS, top_s(XS))]
    for sg in SEGS:
        pts.append((sg["x1"], top_s(sg["x1"] - 0.01)))
    pts.append((X1, DECK + 0.95))
    for (xa, ya), (xb, yb) in zip(pts[:-1], pts[1:]):
        bbeam(P, "ashlar", (xa, ya + 0.12, ZS - 0.4), (xb, yb + 0.12, ZS - 0.4), 1.3, 0.26, 0.06, 2)
    for xn in [SEGS[0]["x1"], SEGS[1]["x1"], SEGS[2]["x1"], SEGS[3]["x1"], XT, X1 - 0.5]:
        yt = top_s(xn - 0.01) + 0.2
        bev_box(P, "ashlar", (xn, yt + 0.55, ZS - 0.4), (0.62, 1.1, 0.62), bevel=0.05, seg=2)
        bev_box(P, "ashlar", (xn, yt + 1.2, ZS - 0.4), (0.82, 0.18, 0.82), bevel=0.05, seg=2)
        bev_box(P, "ashlar", (xn, yt + 1.4, ZS - 0.4), (0.5, 0.22, 0.5), bevel=0.05, seg=2)
    for i, xp in enumerate([XS + 4.0, XS + 12.0, XS + 20.0, XS + 28.0, X1 - 2.0]):
        rib(P, xp, 100 + i, top_s)
    # --- the stair's north wall (the court's south wall) -----------------------------------------------------
    cour_n = Coursing(5, XS - 2, XT + 2, 0.0, DECK + 2, hmin=0.9, hmax=1.6, wmin=1.4, wmax=3.6)
    JW, JD = 0.14, 0.12
    wall(P, "ashlar", Vector((0, 0, ZW + 0.4)), Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)),
         XS, XT, lambda U: stair_line(U) - 0.3, DECK - 0.45, cour_n, cell=0.34, rough=1.3)
    JW, JD = jw, jd
    bbeam(P, "ashlar", (XS - 0.1, DECK - 0.22, ZW + 0.5), (XT + 0.2, DECK - 0.22, ZW + 0.5), 0.9, 0.46, 0.06, 2)
    frieze(P, XS + 3.4, XT - 6.0, DECK - 1.2, ZW + 0.5)
    door(P)
    # --- the court: paving worn by the chain, the parapet over the stair, the east landing's rail -------------
    xr = DC[0] + drum_r(Y_A) + 0.12
    cour_d = Coursing(7, XS - 2, X1 + 2, ZN - 2, ZS + 2, hmin=2.6, hmax=3.6, wmin=2.8, wmax=4.4)
    wall(P, "ashlar", Vector((0, DECK, 0)), Vector((1, 0, 0)), Vector((0, 0, 1)), Vector((0, 1, 0)),
         XS, X1, ZN, ZW, cour_d, cell=0.45, rough=0.7, skew=deck_extra(xr))
    wall(P, "ashlar", Vector((0, DECK, 0)), Vector((1, 0, 0)), Vector((0, 0, 1)), Vector((0, 1, 0)),
         XT, X1, ZW, ZS - 0.9, cour_d, cell=0.45, rough=0.7)
    bev_box(P, "ashlar", ((XS + XT) / 2, DECK + 0.5, ZW - 0.3), (XT - XS, 1.0, 0.5), bevel=0.05, seg=2)
    bbeam(P, "ashlar", (XS - 0.05, DECK + 1.07, ZW - 0.3), (XT + 0.05, DECK + 1.07, ZW - 0.3), 0.75, 0.16, 0.05, 2)
    bev_box(P, "ashlar", (X1 - 0.25, DECK + 0.5, (ZS - 0.9 + ZW) / 2), (0.5, 1.0, ZS - 0.9 - ZW), bevel=0.05, seg=2)
    bbeam(P, "ashlar", (X1 - 0.2, DECK + 1.07, ZW), (X1 - 0.2, DECK + 1.07, ZS - 0.9), 0.75, 0.16, 0.05, 2)
    # --- the stair treads (deep blocks so the risers close) -------------------------------------------------------
    for sg in SEGS:
        if sg["up"]:
            for i in range(sg["n"]):
                x0 = sg["x0"] + i * RUN
                top = sg["y0"] + (i + 1) * RISE
                bev_box(P, "ashlar", (x0 + RUN / 2, top - 0.35, (zin + zout) / 2), (RUN + 0.02, 0.7, zout - zin), bevel=0.03, seg=1)
        else:
            bev_box(P, "ashlar", ((sg["x0"] + sg["x1"]) / 2, sg["y0"] - 0.3, (zin + zout) / 2), (sg["x1"] - sg["x0"], 0.6, zout - zin), bevel=0.04, seg=1)
    # the foot of the stair: four lower treads so the first is not a wall to the road (the ground there is a metre under it)
    for k in range(1, FOOT_STEPS + 1):
        top = Y0 + RISE * (1 - k)
        bev_box(P, "ashlar", (XS - k * RUN + RUN / 2, top - 0.35, (zin + zout) / 2), (RUN + 0.02, 0.7, zout - zin), bevel=0.03, seg=1)
    # --- the cheeks: the bay's west and east sides, hewn rock ---------------------------------------------------------
    wall(P, "stone", Vector((XS, 0, 0)), Vector((0, 0, 1)), Vector((0, 1, 0)), Vector((-1, 0, 0)),
         ZN, ZW, lambda U: ground(XS, U) - 0.8, DECK + 0.1, None, cell=0.45, rough=1.2)
    wall(P, "stone", Vector((X1, 0, 0)), Vector((0, 0, -1)), Vector((0, 1, 0)), Vector((1, 0, 0)),
         -ZS, -ZN, lambda U: ground(X1, -U) - 0.8, DECK + 0.1, None, cell=0.45, rough=1.2)
    build_mooring_wall(P)
    build_drum(P)
    build_lodge(P)
    build_tally(P)
    return P


# --------------------------------------------------------------------------------------------
# links: forged iron
# --------------------------------------------------------------------------------------------
LINK_LO, LINK_W, LINK_D = 5.6, 3.8, 0.78
FOOT_STEPS = 4


def sweep_link(bm, lo, wo, d, arc_n, str_n, ring_n, seed, M=None, hammer=0.0, weld=0.0, variant=0):
    """A forged link: a stadium swept with a squared, hammered wire. Authored in Blender coordinates with the width along X,
    the length along Z (Godot Y) and the wire's thickness along Y: the frame the game's chain placement uses.
    variant 0 plain, 1 with iron collars, 2 bent out of true, 3 cracked. Wear (bright where links bear) and rust are stored
    per vertex (layers "wear", "rustv")."""
    r = d / 2
    R = wo / 2 - r
    h = lo / 2 - R - r
    wear_l = bm.verts.layers.float.get("wear") or bm.verts.layers.float.new("wear")
    rust_l = bm.verts.layers.float.get("rustv") or bm.verts.layers.float.new("rustv")
    path = []
    for i in range(arc_n + 1):
        a = math.pi * i / arc_n
        path.append(((R * math.cos(a), h + R * math.sin(a)), (math.cos(a), math.sin(a)), "ta", i))
    for j in range(1, str_n):
        path.append(((-R, h - 2 * h * j / str_n), (-1, 0), "l", j))
    for i in range(arc_n + 1):
        a = math.pi + math.pi * i / arc_n
        path.append(((R * math.cos(a), -h + R * math.sin(a)), (math.cos(a), math.sin(a)), "ba", i))
    for j in range(1, str_n):
        path.append(((R, -h + 2 * h * j / str_n), (1, 0), "r", j))
    rg = random.Random(seed)
    nrn = len(path)
    crack_i = rg.randrange(nrn)
    bend = rg.uniform(0.25, 0.45) * R if variant == 2 else 0.0
    rings = []
    for i, ((px, pz), (nx, nz), seg, si) in enumerate(path):
        base = 1.0 + 0.05 * math.sin(i * 1.3 + seed) + 0.035 * math.sin(i * 0.5 + 2.0)
        near_weld = math.exp(-((i - arc_n * 0.5) ** 2) / (arc_n * 0.12 + 0.6))
        s = base * (1.0 + weld * near_weld)
        collar = variant == 1 and seg in ("l", "r") and abs(si - str_n / 2) < max(1.0, str_n * 0.18)
        if collar:
            s *= 1.25
        if variant == 3 and min(abs(i - crack_i), nrn - abs(i - crack_i)) <= 1:
            s *= 0.62 if min(abs(i - crack_i), nrn - abs(i - crack_i)) == 0 else 0.86
        # a bent link: the straights lean and one end sags
        bx = bend * (pz / max(h + R, 1e-3)) ** 2 * (1 if variant == 2 else 0) + (bend * 0.5 * px / R if variant == 2 else 0)
        ring = []
        wear_peak = 0.0
        if seg in ("ta", "ba") and abs(si - arc_n * 0.5) <= max(1.0, arc_n * 0.2):
            wear_peak = 1.0
        for k in range(ring_n):
            th = math.tau * k / ring_n + 0.2 * math.sin(i * 0.37)
            c, sn = math.cos(th), math.sin(th)
            f = (abs(c) ** 3 + abs(sn) ** 3) ** (-1 / 3)
            dr = r * f * s * (1.0 + hammer * (rg.random() - 0.5))
            dr *= 1.0 + 0.03 * math.cos(8 * th + i)                      # hammer facets round the wire
            v0 = Vector((px + nx * c * dr + bx, sn * dr, pz + nz * c * dr))
            pit = noise.noise(v0 * (9.0 / max(d, 0.3)) + Vector((seed, 2, 5)))
            if pit > 0.38:
                dr *= 1.0 - 0.14 * (pit - 0.38) / 0.62                       # pitting
                v0 = Vector((px + nx * c * dr + bx, sn * dr, pz + nz * c * dr))
            v = Vector(v0)
            if M is not None:
                v = M @ v
            bv = bm.verts.new(v)
            inner = max(0.0, -c)
            bv[wear_l] = wear_peak * smooth(0.55, 1.0, inner) * (0.7 + 0.3 * noise.noise(v0 * 3.0)) + (0.9 if collar and abs(sn) < 0.5 else 0.0)
            rn = fbm(v0 * (0.8 / max(d, 0.3)) + Vector((seed, 7, 1)), 3)
            bv[rust_l] = max(0.0, min(1.0, rn * 1.5 + 0.35 + (0.4 if variant == 3 and min(abs(i - crack_i), nrn - abs(i - crack_i)) <= 1 else 0.0)))
            ring.append(bv)
        rings.append(ring)
    for i in range(nrn):
        a, b = rings[i], rings[(i + 1) % nrn]
        for k in range(ring_n):
            k2 = (k + 1) % ring_n
            try:
                bm.faces.new((a[k], b[k], b[k2], a[k2]))
            except ValueError:
                pass


# --------------------------------------------------------------------------------------------
# the chain's path and links (Godot coordinates)
# --------------------------------------------------------------------------------------------
LEAN = Vector((-0.34, 0.85, -0.40)).normalized()


def chain_path():
    """Points every 0.5 m from the ring, along the pulled-taut line to the drum, up the helix, off the drum's head, up
    (vertical until the mountain is cleared, then leaning towards the vortex) with a long slow sway. Also the helix's range."""
    pts = []
    xr = DC[0] + drum_r(Y_A) + 0.12
    z = RING_Z
    while z < DC[1]:
        pts.append(Vector((xr, Y_A, z)))
        z += 0.5
    n_straight = len(pts)
    th = 0.0
    while th < math.tau * TURNS:
        y = Y_A + (Y_B - Y_A) * th / (math.tau * TURNS)
        r = drum_r(y) + 0.12
        pts.append(Vector((DC[0] + r * math.cos(th), y, DC[1] + r * math.sin(th))))
        th += 0.5 / r
    n_helix_end = len(pts)
    th_e = th
    t_exit = Vector((-math.sin(th_e), 0.12, math.cos(th_e))).normalized()
    p = pts[-1].copy()
    u = 0.0
    total_u = CHAIN_LEN
    while u < total_u:
        w1 = smooth(0.0, 20.0, u)
        t = t_exit.lerp(Vector((0, 1, 0)), w1)
        w2 = smooth(70.0, 360.0, u)
        t = t.lerp(Vector((0, 1, 0)).lerp(LEAN, w2), smooth(10.0, 30.0, u)).normalized()
        p = p + t * 0.5
        sway = smooth(40.0, 200.0, u)
        pts.append(p + Vector((9.0 * math.sin(u * 0.0125 + 0.6) * sway, 0.0, 4.0 * math.sin(u * 0.009 + 1.9) * sway)))
        u += 0.5
    return pts, n_straight, n_helix_end


CHAIN_LEN = 430.0
VAR_HI, VAR_MID = 4, 2


def chain_frames():
    """[(origin, width dir, tangent, thickness dir, scale, helix?)] by arc length with the link's pitch growing with height."""
    pts, ns, nh = chain_path()

    def at(sv):
        f = max(0.0, min(len(pts) - 1.0, sv / 0.5))
        i = min(int(f), len(pts) - 2)
        return pts[i].lerp(pts[i + 1], f - i)
    total = (len(pts) - 1) * 0.5
    out = []
    pitch0 = LINK_LO - 3 * LINK_D
    sv = (LINK_LO / 2 - LINK_D / 2)              # the first link's centre: its end loops on the ring's bottom wire
    i = 0
    prev_w = Vector((0, 1, 0))
    s_head = nh * 0.5
    while sv < total - 8.0:
        h_above = max(0.0, sv - s_head)
        sc = 1.0 + 6.0 * smooth(10.0, 260.0, h_above)
        pos = at(sv)
        t = (at(sv + pitch0 * sc * 0.5) - at(max(sv - pitch0 * sc * 0.5, 0.0))).normalized()
        on_helix = ns * 0.5 - 1.0 <= sv <= s_head + 1.0
        if on_helix:
            rad = Vector((pos.x - DC[0], 0.0, pos.z - DC[1])).normalized()
            wa = (rad - t * rad.dot(t)).normalized()
        else:
            wa = (prev_w - t * prev_w.dot(t))
            wa = wa.normalized() if wa.length > 1e-4 else Vector((1, 0, 0))
        prev_w = wa
        wid = wa if i % 2 == 0 else t.cross(wa).normalized()
        thk = wid.cross(t).normalized()
        out.append((pos, wid, t, thk, sc, on_helix))
        sv += pitch0 * sc
        i += 1
    return out


def link_mats(frames):
    for (pos, wid, t, thk, sc, _h) in frames:
        M = Matrix((B(wid) * sc, -B(thk) * sc, B(t) * sc)).transposed().to_4x4()
        M.translation = B(pos)
        yield M


def build_links(bm, frames, hi_count=16):
    for k, M in enumerate(link_mats(frames)):
        if k < hi_count:
            sweep_link(bm, LINK_LO, LINK_W, LINK_D, 12, 3, 10, 11 + k, M=M, hammer=0.07, weld=0.2, variant=k % 4)
        elif k < 36:
            sweep_link(bm, LINK_LO, LINK_W, LINK_D, 8, 2, 8, 11 + k, M=M)
        else:
            sweep_link(bm, LINK_LO, LINK_W, LINK_D, 5, 1, 6, 11 + k, M=M)


# --------------------------------------------------------------------------------------------
# the wardens' chest
# --------------------------------------------------------------------------------------------
def build_chest():
    """An iron-bound strongbox of oak planks, a domed lid on a hinge (its own object, pivot at the hinge), a hasp and lock."""
    P = Parts()
    L = Parts()
    rg = random.Random(77)
    W, Dp, H = 1.0, 0.62, 0.55
    # body: planks stood on end, the corner posts, a skirt
    for i in range(8):
        x = -W / 2 + (i + 0.5) * W / 8
        bev_box(P, "timber", (x, H / 2, Dp / 2 - 0.02), (W / 8 - 0.012, H, 0.06), bevel=0.008, seg=1, rough=0.0)
        bev_box(P, "timber", (x, H / 2, -Dp / 2 + 0.02), (W / 8 - 0.012, H, 0.06), bevel=0.008, seg=1)
    for sx in (-1, 1):
        for i in range(5):
            z = -Dp / 2 + (i + 0.5) * Dp / 5
            bev_box(P, "timber", (sx * (W / 2 - 0.02), H / 2, z), (0.06, H, Dp / 5 - 0.012), bevel=0.008, seg=1)
    bev_box(P, "timber", (0, 0.02, 0), (W - 0.04, 0.04, Dp - 0.04), bevel=0.01, seg=1)
    for sx in (-1, 1):
        for sz in (-1, 1):
            bev_box(P, "timber", (sx * (W / 2 - 0.035), H / 2, sz * (Dp / 2 - 0.035)), (0.09, H + 0.02, 0.09), bevel=0.012, seg=1)
            bev_box(P, "iron", (sx * (W / 2 - 0.01), 0.1, sz * (Dp / 2 - 0.01)), (0.1, 0.2, 0.1), bevel=0.015, seg=1)
    # iron straps round the body, each with rivets, and corner plates
    for x in (-0.3, 0.3):
        bev_box(P, "iron", (x, H / 2, Dp / 2 + 0.005), (0.07, H + 0.01, 0.02), bevel=0.004, seg=1)
        bev_box(P, "iron", (x, H / 2, -Dp / 2 - 0.005), (0.07, H + 0.01, 0.02), bevel=0.004, seg=1)
        for y in (0.08, 0.27, 0.47):
            bev_box(P, "iron", (x, y, Dp / 2 + 0.018), (0.032, 0.032, 0.02), bevel=0.006, seg=1)
    for sx in (-1, 1):
        bev_box(P, "iron", (sx * (W / 2 + 0.005), H / 2, 0), (0.02, H + 0.01, 0.07), bevel=0.004, seg=1)
    bev_box(P, "iron", (0, H - 0.04, Dp / 2 + 0.005), (W + 0.02, 0.07, 0.02), bevel=0.004, seg=1)
    # the lid: a half-barrel (planks along the curve), hinge at the back top edge
    n = 12
    rad = Dp / 2
    for i in range(n):
        a0 = math.pi * i / n
        a1 = math.pi * (i + 1) / n
        poly = [(math.cos(a0) * rad, math.sin(a0) * rad * 0.62), (math.cos(a1) * rad, math.sin(a1) * rad * 0.62),
                (math.cos(a1) * (rad - 0.05), math.sin(a1) * (rad - 0.05) * 0.62), (math.cos(a0) * (rad - 0.05), math.sin(a0) * (rad - 0.05) * 0.62)]
        # extrude along the box's x, in the lid's local frame (y up from the hinge, z forward = -hinge at +z... built then moved)
        bm = L.of("timber")
        pts_f = [bm.verts.new(B((-W / 2 + 0.01, py, -px + rad))) for (px, py) in poly]
        pts_b = [bm.verts.new(B((W / 2 - 0.01, py, -px + rad))) for (px, py) in poly]
        bm.faces.new(pts_f[::-1])
        bm.faces.new(pts_b)
        for j in range(4):
            k2 = (j + 1) % 4
            bm.faces.new((pts_f[j], pts_f[k2], pts_b[k2], pts_b[j])) if False else bm.faces.new((pts_f[k2], pts_f[j], pts_b[j], pts_b[k2]))
    for x in (-0.38, 0.0, 0.38):
        # a strap over the lid's curve
        prev = None
        for i in range(n + 1):
            a = math.pi * i / n
            cur = (x, math.sin(a) * (rad + 0.012) * 0.62, -math.cos(a) * (rad + 0.012) + rad)
            if prev is not None:
                bbeam(L, "iron", prev, cur, 0.07, 0.022, 0.004, 1)
            prev = cur
    bev_box(L, "iron", (0, 0.0, 0.0), (W + 0.03, 0.04, 0.04), bevel=0.006, seg=1)
    # hasp, lock plate and ring on the front
    bev_box(P, "iron", (0, H - 0.17, Dp / 2 + 0.02), (0.11, 0.22, 0.02), bevel=0.004, seg=1)
    bev_box(P, "iron", (0, H - 0.21, Dp / 2 + 0.035), (0.07, 0.09, 0.025), bevel=0.006, seg=1)
    bev_box(L, "iron", (0, 0.1, Dp + 0.01), (0.09, 0.16, 0.02), bevel=0.004, seg=1)
    return P, L


# --------------------------------------------------------------------------------------------
# finishing, export, preview
# --------------------------------------------------------------------------------------------
def tone(key, co, n, wear=0.0, rust=None):
    z = co.z
    nz = max(n.z, 0.0)
    if key in ("ashlar", "stone"):
        v = (1.0 if key == "ashlar" else 0.9) + 0.28 * fbm(co * 0.17 + Vector((1, 9, 4)), 3)
        damp = 1.0 - 0.3 * (1.0 - smooth(-1.0, 6.0, z))
        moss = smooth(-0.1, 0.4, fbm(co * 0.23 + Vector((7, 3, 1)), 3)) * (0.2 + 0.8 * nz) * (0.5 + 0.5 * (1.0 - smooth(0.0, 9.0, z)))
        soot = smooth(0.1, 0.6, fbm(Vector((co.x * 0.7, co.y * 0.7, co.z * 0.06)), 2)) * (1.0 - nz) * 0.25
        m = v * damp
        r, g, b = m * (1 - 0.5 * moss) + 0.3 * moss, m * (1 - 0.5 * moss) + 0.34 * moss, m * (1 - 0.5 * moss) + 0.28 * moss
        if key == "stone":
            r, g, b = r * 1.04, g * 0.98, b * 0.92
        return (min(1.0, r * (1 - soot)), min(1.0, g * (1 - soot)), min(1.0, b * (1 - soot * 0.8)))
    if key == "iron":
        rs = rust if rust is not None else smooth(0.0, 0.5, fbm(co * 0.6, 3) + 0.2)
        base = (0.42, 0.42, 0.48)                                           # blackened iron
        rusty = (0.5, 0.26, 0.13)
        patina = (0.18, 0.24, 0.22)
        flake = smooth(0.62, 0.85, rs)
        c = tuple(base[i] * (1 - rs * 0.75) + rusty[i] * rs * 0.75 for i in range(3))
        c = tuple(c[i] * (1 - 0.35 * smooth(0.2, 0.5, rs) * (1 - flake)) + patina[i] * 0.35 * smooth(0.2, 0.5, rs) * (1 - flake) for i in range(3))
        bright = (0.62, 0.58, 0.55)
        return tuple(c[i] * (1 - wear) + bright[i] * wear for i in range(3))
    if key == "timber":
        g = 0.34 + 0.12 * fbm(Vector((co.x * 2.0, co.y * 14.0, co.z * 2.0)), 3)
        return (g * 1.05, g * 0.78, g * 0.55)
    return (0.05, 0.05, 0.06)


def finish(P, name, flat_keys=()):
    objs = []
    for key, bm in P.bm.items():
        if key == "iron":
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces)      # the swept links are closed tubes: make them face out
        bm.normal_update()
        for f in bm.faces:
            f.smooth = key not in flat_keys
        ao_l = bm.verts.layers.float.get("ao")
        wear_l = bm.verts.layers.float.get("wear")
        rust_l = bm.verts.layers.float.get("rustv")
        uv = bm.loops.layers.uv.new("UVMap")
        col = bm.loops.layers.color.new("Col")
        tile = TILE.get(key, 4.0)
        for f in bm.faces:
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
                wv = l.vert[wear_l] if wear_l is not None else 0.0
                rv = l.vert[rust_l] if rust_l is not None else None
                c = tone(key, co, l.vert.normal, wv, rv)
                if ao_l is not None:
                    av = l.vert[ao_l]
                    c = tuple(x_ * (av if av > 0.0 else 1.0) for x_ in c)
                l[col] = (c[0], c[1], c[2], 1.0)
        me = bpy.data.meshes.new("%s__%s" % (name, key))
        bm.to_mesh(me)
        bm.free()
        ob = bpy.data.objects.new("%s__%s" % (name, key), me)
        bpy.context.scene.collection.objects.link(ob)
        me.color_attributes.active_color = me.color_attributes["Col"]
        objs.append(ob)
    return objs


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def tri_count(objs):
    return sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objs)


def preview(label, views, size=(1280, 720)):
    if not PREVIEW:
        return
    os.makedirs(PREVIEW, exist_ok=True)
    sc = bpy.context.scene
    try:
        sc.render.engine = 'BLENDER_EEVEE'
    except TypeError:
        sc.render.engine = 'BLENDER_WORKBENCH'
    sc.render.resolution_x, sc.render.resolution_y = size
    w = bpy.data.worlds.new("night")
    w.use_nodes = True
    bg = w.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.05, 0.07, 0.2, 1)
    bg.inputs[1].default_value = 0.9
    sc.world = w
    moon = bpy.data.lights.new("moon", 'SUN')
    moon.energy = 2.2
    moon.color = (0.62, 0.7, 1.0)
    mo = bpy.data.objects.new("moon", moon)
    sc.collection.objects.link(mo)
    mo.rotation_euler = (math.radians(55), 0, math.radians(-35))
    warm = bpy.data.lights.new("candles", 'POINT')
    warm.energy = 4000
    warm.color = (1.0, 0.62, 0.32)
    wo = bpy.data.objects.new("candles", warm)
    sc.collection.objects.link(wo)
    wo.location = B((DOOR_X, DOOR_Y + 1.5, ZW + 2.2))
    for o in list(bpy.data.objects):
        if o.type == 'MESH':
            m = bpy.data.materials.new("pv_" + o.name)
            m.use_nodes = True
            nt = m.node_tree
            bsdf = nt.nodes["Principled BSDF"]
            vc = nt.nodes.new("ShaderNodeVertexColor")
            vc.layer_name = "Col"
            nt.links.new(vc.outputs[0], bsdf.inputs["Base Color"])
            iron = o.name.split("__")[-1] == "iron"
            bsdf.inputs["Roughness"].default_value = 0.5 if iron else 0.85
            bsdf.inputs["Metallic"].default_value = 0.55 if iron else 0.0
            o.data.materials.clear()
            o.data.materials.append(m)
    cam_d = bpy.data.cameras.new("cam")
    cam = bpy.data.objects.new("cam", cam_d)
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam_d.clip_end = 2000
    for i, (loc, target, lens) in enumerate(views):
        cam.location = B(loc)
        cam.rotation_euler = (B(target) - B(loc)).to_track_quat('-Z', 'Y').to_euler()
        cam_d.lens = lens
        sc.render.filepath = os.path.join(PREVIEW, "%s_%d.png" % (label, i))
        bpy.ops.render.render(write_still=True)


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
    print("EXPORTED", path, tri_count(objs), "tris")


def write_frames(frames):
    import json
    out = []
    for (pos, wid, t, thk, sc, hx) in frames:
        out.append({"p": [round(pos.x, 3), round(pos.y, 3), round(pos.z, 3)], "w": [round(wid.x, 4), round(wid.y, 4), round(wid.z, 4)],
                    "t": [round(t.x, 4), round(t.y, 4), round(t.z, 4)], "s": round(sc, 3), "h": hx})
    os.makedirs(MODELS, exist_ok=True)
    with open(os.path.join(MODELS, "sky_chain_chain.json"), "w") as fh:
        json.dump({"link": [LINK_LO, LINK_W, LINK_D], "links": out,
                   "geo": {"xs": XS, "y0": Y0, "rise": RISE, "run": RUN, "xt": XT, "x1": X1, "zn": ZN, "zw": ZW, "zs": ZS, "deck": DECK,
                           "foot_steps": FOOT_STEPS, "segs": SEGS, "drum": [DC[0], DC[1], HEAD_Y], "ring": [DC[0] + drum_r(Y_A) + 0.12, RING_CY, RING_Z],
                           "lodge": list(LODGE), "lodge_h": LODGE_H, "tally": list(TALLY), "door": [DOOR_X, DOOR_Y]}}, fh)


def asset_anchor():
    reset()
    P = build_anchor()
    objs = finish(P, "SkyChainAnchor")
    export_objs = list(objs)
    frames = chain_frames()
    PC = Parts()
    build_links(PC.of("iron"), frames, 16)
    finish(PC, "PreviewChain")
    print("anchor tris", tri_count(export_objs), "links", len(frames), "stair xs %.2f y0 %.2f rise %.3f clearance %.2f" % (XS, Y0, RISE, WORST))
    top = max(f[0].y for f in frames)
    print("chain top y %.0f" % top)
    views = [((70, 3, 60), (74, 40, -135), 22),          # from the road
             ((6, 3, 38), (66, 46, -135), 22),            # from Hearthward
             ((64, 4, -60), (74, 26, -135), 30),          # mid distance
             ((50, 6, -108), (74, 18, -132), 30),         # the stair's foot
             ((74, 8, -116), (70, 9, -126), 42),          # the door
             ((90, 21, -122), (80, 22, -138), 34),        # the court from the stair head
             ((58, 21, -132), (76, 24, -138), 36),        # the drum from the west
             ((90, 20, -130), (86, 19, -133), 40),        # the tally and the lodge door
             ((84.3, 21.5, -127.5), (81.9, 22.6, -142.6), 30)]        # the ring and the pin
    preview("anchor", views)
    if "--export" in args:
        os.makedirs(MODELS, exist_ok=True)
        export(export_objs, os.path.join(MODELS, "sky_chain_anchor.glb"))
        write_frames(frames)


def asset_link():
    reset()
    objs = []
    for v in range(VAR_HI):
        P = Parts()
        sweep_link(P.of("iron"), LINK_LO, LINK_W, LINK_D, 12, 3, 10, 3 + v * 7, hammer=0.07, weld=0.2, variant=v)
        objs += finish(P, "SkyChainLinkHi%d" % v)
    for v in range(VAR_MID):
        P = Parts()
        sweep_link(P.of("iron"), LINK_LO, LINK_W, LINK_D, 8, 2, 8, 4 + v, variant=v)
        objs += finish(P, "SkyChainLinkMid%d" % v)
    P = Parts()
    sweep_link(P.of("iron"), LINK_LO, LINK_W, LINK_D, 5, 1, 6, 5)
    objs += finish(P, "SkyChainLinkLo")
    P = Parts()
    sweep_link(P.of("iron"), 1.5, 1.0, 0.24, 6, 1, 6, 6, hammer=0.1)
    objs += finish(P, "SkyChainLinkSmall")
    print("link tris", tri_count(objs))
    # a run of the first links, laid out as the game places them
    PR = Parts()
    build_links(PR.of("iron"), chain_frames()[:10], 10)
    show = finish(PR, "Run")
    for o in objs:
        o.hide_render = True
    preview("links", [((70, 24, -140), (80, 21, -139), 38), ((70, 29, -143), (76, 23, -136), 50)])
    if "--export" in args:
        export(objs, os.path.join(MODELS, "sky_chain_link.glb"))


def asset_chest():
    reset()
    P, L = build_chest()
    body = finish(P, "WardensChest")
    lid = finish(L, "WardensChestLid")
    for o in lid:
        o.location = B((0, 0.55, -0.31))
    print("chest tris", tri_count(body + lid))
    if PREVIEW:
        preview("chest", [((0.0, 0.9, 1.6), (0, 0.3, 0), 50), ((1.4, 1.2, 1.0), (0, 0.3, 0), 50)])
    if "--export" in args:
        export(body + lid, os.path.join(MODELS, "sky_chain_chest.glb"))


ASSETS = {"anchor": asset_anchor, "link": asset_link, "chest": asset_chest}

if __name__ == "__main__":
    for k, fn in ASSETS.items():
        if ONLY and k not in ONLY:
            continue
        print("=== ", k)
        fn()
