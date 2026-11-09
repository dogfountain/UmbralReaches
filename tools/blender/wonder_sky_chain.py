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
TILE = {"ashlar": 4.0, "iron": 2.0, "dark": 4.0}

# --- the site (Godot metres) --------------------------------------------------------------------------
XT = 88.0          # the stair's last tread; the landing runs east to X1
X1 = 96.0
ZN, ZW, ZS = -139.0, -127.0, -122.5     # deck's north edge / deck's south edge (wall foot) / stair's south face
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


def bbeam(P, key, a, b, w, h, bevel=0.04, seg=2):
    """A bevelled bar from a to b (Godot points), w across, h tall (up stays up)."""
    a, b = B(a), B(b)
    d = b - a
    q = d.to_track_quat('Y', 'Z')
    M = Matrix.Translation((a + b) * 0.5) @ q.to_matrix().to_4x4() @ Matrix.Diagonal((w, d.length, h, 1.0))
    bm = P.of(key)
    res = bmesh.ops.create_cube(bm, size=1.0, matrix=M)
    edges = {e for v in res["verts"] for e in v.link_edges}
    bmesh.ops.bevel(bm, geom=list(edges), offset=bevel, segments=seg, affect='EDGES', profile=0.6)


def prism(P, key, poly, z0, z1, shrink=0.015):
    """A polygon (x, y pairs in Godot's x-y plane, counter-clockwise seen from +z) extruded from Godot z0 to z1."""
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
    """Points along a pointed arch from the left springing over the apex to the right springing (Godot x, y)."""
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


def build_anchor():
    P = Parts()
    zin, zout = ZW + 0.4, ZS - 0.9
    rnd = random.Random(5)
    # --- the south wall: height-field ashlar, its top the stair's own slope + a rail's height ---------------
    cour_s = Coursing(3, XS - 2, X1 + 2, BASE_Y, DECK + 3, hmin=0.75, hmax=1.35, wmin=1.1, wmax=3.2)

    def top_s(U):
        return stair_line(U) + 0.95 if U < XT else DECK + 0.95

    def lo_s(U):
        return ground(U, -122.5) - 0.6

    wall(P, "ashlar", Vector((0, 0, ZS)), Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)),
         XS, X1, lo_s, top_s, cour_s, cell=0.14)
    # the coping follows the slope: a bar along each flight, level on the landings
    pts = [(XS, top_s(XS))]
    for sg in SEGS:
        pts.append((sg["x1"], top_s(sg["x1"] - 0.01)))
    pts.append((X1, DECK + 0.95))
    for (xa, ya), (xb, yb) in zip(pts[:-1], pts[1:]):
        bbeam(P, "ashlar", (xa, ya + 0.12, ZS - 0.4), (xb, yb + 0.12, ZS - 0.4), 1.3, 0.26, 0.06, 2)
    # newels where the flights meet the landings and at the top, each with a moulded cap
    for xn in [SEGS[0]["x1"], SEGS[1]["x1"], SEGS[2]["x1"], SEGS[3]["x1"], XT, X1 - 0.5]:
        yt = top_s(xn - 0.01) + 0.2
        bev_box(P, "ashlar", (xn, yt + 0.55, ZS - 0.4), (0.62, 1.1, 0.62), bevel=0.05, seg=2)
        bev_box(P, "ashlar", (xn, yt + 1.2, ZS - 0.4), (0.82, 0.18, 0.82), bevel=0.05, seg=2)
        bev_box(P, "ashlar", (xn, yt + 1.4, ZS - 0.4), (0.5, 0.22, 0.5), bevel=0.05, seg=2)
    # --- the plinth: a projecting foot with a chamfered top all along the south face ---------------------
    x = XS
    while x < X1 - 1e-3:
        xb = min(x + 3.6, X1)
        gl = min(ground(x, -122.0), ground(xb, -122.0))
        bev_box(P, "ashlar", ((x + xb) / 2, gl + 0.55, ZS + 0.28), (xb - x - 0.04, 1.5, 0.6), bevel=0.07, seg=2)
        x = xb
    # --- the piers: stepped buttresses on the south face ----------------------------------------------------
    for i, xp in enumerate([XS + 3.4, XS + 10.0, XS + 17.0, XS + 24.0, XS + 31.0, X1 - 1.6]):
        pier(P, xp, 100 + i, top_s)
    # --- north wall (above the stair, to the deck) -------------------------------------------------------
    cour_n = Coursing(5, XS - 2, XT + 2, 0.0, DECK + 2, hmin=0.75, hmax=1.3, wmin=1.2, wmax=3.0)
    wall(P, "ashlar", Vector((0, 0, ZW + 0.4)), Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)),
         XS, XT, lambda U: stair_line(U) - 0.3, DECK - 0.45, cour_n, cell=0.14)
    bbeam(P, "ashlar", (XS - 0.1, DECK - 0.22, ZW + 0.5), (XT + 0.2, DECK - 0.22, ZW + 0.5), 0.9, 0.46, 0.06, 2)
    # a string course half-way up
    bbeam(P, "ashlar", (XS + 6.0, stair_line(XS + 6.0) + 3.0, ZW + 0.46), (XT - 0.5, stair_line(XT - 0.5) + 3.0, ZW + 0.46), 0.3, 0.22, 0.04, 1)
    # --- the deck: paving, parapets, the cradle ------------------------------------------------------------
    cour_d = Coursing(7, XS - 2, X1 + 2, ZN - 2, ZS + 2, hmin=2.6, hmax=3.6, wmin=2.8, wmax=4.4)
    wall(P, "ashlar", Vector((0, DECK, 0)), Vector((1, 0, 0)), Vector((0, 0, 1)), Vector((0, 1, 0)),
         XS, X1, ZN, ZW, cour_d, cell=0.2, rough=0.6)
    wall(P, "ashlar", Vector((0, DECK, 0)), Vector((1, 0, 0)), Vector((0, 0, 1)), Vector((0, 1, 0)),
         XT, X1, ZW, ZS - 0.9, cour_d, cell=0.2, rough=0.6)
    # the parapet over the stair's north wall (the deck's south edge)
    bev_box(P, "ashlar", ((XS + XT) / 2, DECK + 0.5, ZW - 0.3), (XT - XS, 1.0, 0.5), bevel=0.05, seg=2)
    bbeam(P, "ashlar", (XS - 0.05, DECK + 1.07, ZW - 0.3), (XT + 0.05, DECK + 1.07, ZW - 0.3), 0.75, 0.16, 0.05, 2)
    # the east end: a parapet round the landing and the deck's east edge
    bev_box(P, "ashlar", (X1 - 0.25, DECK + 0.5, (ZS - 0.9 + ZN) / 2 + 0.0), (0.5, 1.0, ZS - 0.9 - ZN), bevel=0.05, seg=2)
    bbeam(P, "ashlar", (X1 - 0.2, DECK + 1.07, ZN), (X1 - 0.2, DECK + 1.07, ZS - 0.9), 0.75, 0.16, 0.05, 2)
    # the cradle: curbs either side of the chain's line, chocks under the links
    for sgn in (-1, 1):
        zc = ZC + sgn * 3.5
        bbeam(P, "ashlar", (XS + 2.0, DECK + 0.3, zc), (XT + 6.5, DECK + 0.3, zc), 0.8, 0.6, 0.07, 2)
    for i in range(7):
        xc = XT + 3.5 - i * 4.6
        for sgn in (-1, 1):
            bev_box(P, "ashlar", (xc, DECK + 0.22, ZC + sgn * 2.15), (1.3, 0.46, 0.9), bevel=0.06, seg=1, yaw=0.2 * sgn)
    # --- the stair treads: each a deep block so the risers close ------------------------------------------
    for sg in SEGS:
        if sg["up"]:
            for i in range(sg["n"]):
                x0 = sg["x0"] + i * RUN
                top = sg["y0"] + (i + 1) * RISE
                bev_box(P, "ashlar", (x0 + RUN / 2, top - 0.35, (zin + zout) / 2), (RUN + 0.02, 0.7, zout - zin), bevel=0.03, seg=1)
        else:
            bev_box(P, "ashlar", ((sg["x0"] + sg["x1"]) / 2, sg["y0"] - 0.3, (zin + zout) / 2), (sg["x1"] - sg["x0"], 0.6, zout - zin), bevel=0.04, seg=1)
    # --- end walls -------------------------------------------------------------------------------------------
    cour_e = Coursing(9, ZN - 2, ZS + 2, BASE_Y, DECK + 2)
    cour_e2 = Coursing(10, -ZS - 2, -ZN + 2, BASE_Y, DECK + 2)
    wall(P, "ashlar", Vector((XS, 0, 0)), Vector((0, 0, 1)), Vector((0, 1, 0)), Vector((-1, 0, 0)),
         ZN, ZW, lambda U: ground(XS, U) - 0.6, DECK, cour_e, cell=0.14)
    wall(P, "ashlar", Vector((X1, 0, 0)), Vector((0, 0, -1)), Vector((0, 1, 0)), Vector((1, 0, 0)),
         -ZS, -ZN, lambda U: ground(X1, -U) - 0.6, DECK, cour_e2, cell=0.14)
    gate_tower(P)
    door(P)
    frieze(P)
    bitter_end(P)
    return P


def pier(P, xp, seed, top_s):
    """A battered buttress on the south wall: ashlar courses stepping in as they rise (a stretcher and a header on
    alternate courses, each block eased and a little out of true), a weathered cap, an iron strap bolted to its face."""
    rg = random.Random(seed)
    gl = ground(xp, -122.0)
    top = top_s(xp) - 0.15
    y = gl - 0.7
    h_total = top - y
    i = 0
    while y < top - 0.3:
        hh = min(rg.uniform(0.7, 1.0), top - y)
        t = (y - (gl - 0.7)) / max(h_total, 1.0)
        w = 2.1 - 0.7 * t
        proj = 1.75 - 1.1 * t
        if i % 2 == 0:
            bev_box(P, "ashlar", (xp + rg.uniform(-0.04, 0.04), y + hh / 2, ZS + proj / 2 + 0.02), (w, hh - 0.03, proj), bevel=0.055, seg=2)
        else:
            bev_box(P, "ashlar", (xp - w * 0.2, y + hh / 2, ZS + proj / 2 + 0.05), (w * 0.62, hh - 0.03, proj), bevel=0.055, seg=2)
            bev_box(P, "ashlar", (xp + w * 0.31, y + hh / 2, ZS + proj / 2 - 0.02), (w * 0.38 - 0.03, hh - 0.03, proj - 0.1), bevel=0.055, seg=2)
        y += hh
        i += 1
    bev_box(P, "ashlar", (xp, top + 0.1, ZS + 0.5), (1.5, 0.26, 1.1), bevel=0.07, seg=2)
    sy0 = gl + 0.4
    bev_box(P, "iron", (xp, (sy0 + top) / 2, ZS + 0.58), (0.3, top - sy0 - 0.5, 0.06), bevel=0.02, seg=1)
    yb = sy0 + 0.6
    while yb < top - 0.6:
        bev_box(P, "iron", (xp, yb, ZS + 0.62), (0.2, 0.2, 0.08), bevel=0.035, seg=2)
        yb += 1.6


def gate_tower(P):
    """The gate tower at the stair's head: a square tower on the landing's south-east corner, arrow slits, a corbelled
    parapet with merlons, a pyramid roof. Height-field ashlar on every face."""
    x0, x1, z0, z1 = X1 - 4.6, X1, ZW + 0.2, ZS
    y0, y1 = DECK, DECK + 7.2
    cour = Coursing(41, x0 - 2, x1 + 2, y0 - 1, y1 + 2, hmin=0.7, hmax=1.15, wmin=1.0, wmax=2.6)
    cz = Coursing(43, -z1 - 2, -z0 + 2, y0 - 1, y1 + 2, hmin=0.7, hmax=1.15, wmin=1.0, wmax=2.6)
    czw = Coursing(44, z0 - 2, z1 + 2, y0 - 1, y1 + 2, hmin=0.7, hmax=1.15, wmin=1.0, wmax=2.6)
    cn = Coursing(45, -x1 - 2, -x0 + 2, y0 - 1, y1 + 2, hmin=0.7, hmax=1.15, wmin=1.0, wmax=2.6)
    wall(P, "ashlar", Vector((0, 0, z1)), Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)), x0, x1, y0, y1, cour, cell=0.14)
    wall(P, "ashlar", Vector((0, 0, z0)), Vector((-1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, -1)), -x1, -x0, y0, y1, cn, cell=0.14)
    wall(P, "ashlar", Vector((x1, 0, 0)), Vector((0, 0, -1)), Vector((0, 1, 0)), Vector((1, 0, 0)), -z1, -z0, y0, y1, cz, cell=0.14)
    wall(P, "ashlar", Vector((x0, 0, 0)), Vector((0, 0, 1)), Vector((0, 1, 0)), Vector((-1, 0, 0)), z0, z1, y0, y1, czw, cell=0.14)
    # a corbelled course and the parapet with merlons
    bev_box(P, "ashlar", ((x0 + x1) / 2, y1 + 0.15, (z0 + z1) / 2), (x1 - x0 + 0.8, 0.4, z1 - z0 + 0.8), bevel=0.07, seg=2)
    nm = 5
    for side in range(4):
        for i in range(nm):
            t = (i + 0.5) / nm
            if side == 0:
                c = (x0 - 0.4 + (x1 - x0 + 0.8) * t, z1 + 0.4)
            elif side == 1:
                c = (x0 - 0.4 + (x1 - x0 + 0.8) * t, z0 - 0.4)
            elif side == 2:
                c = (x1 + 0.4, z0 - 0.4 + (z1 - z0 + 0.8) * t)
            else:
                c = (x0 - 0.4, z0 - 0.4 + (z1 - z0 + 0.8) * t)
            bev_box(P, "ashlar", (c[0], y1 + 0.34 + 0.55, c[1]), (0.62, 1.1, 0.62), bevel=0.05, seg=1)
    # the roof: a low pyramid
    cx, cz_ = (x0 + x1) / 2, (z0 + z1) / 2
    base = y1 + 0.4
    hx, hz = (x1 - x0) / 2 + 0.2, (z1 - z0) / 2 + 0.2
    apex = (cx, base + 3.2, cz_)
    corners = [(cx - hx, base, cz_ - hz), (cx + hx, base, cz_ - hz), (cx + hx, base, cz_ + hz), (cx - hx, base, cz_ + hz)]
    bm = P.of("ashlar")
    for i in range(4):
        a, b = corners[i], corners[(i + 1) % 4]
        mid = ((a[0] + b[0]) / 2 - cx, 1.0, (a[2] + b[2]) / 2 - cz_)
        quad(P, "ashlar", a, b, apex, apex, mid)
    # arrow slits: dark, set into each face
    for yy in (y0 + 2.6, y0 + 5.0):
        for xx in (x0 + 1.2, x1 - 1.2):
            prism(P, "dark", [(xx - 0.09, yy - 0.5), (xx + 0.09, yy - 0.5), (xx + 0.09, yy + 0.5), (xx - 0.09, yy + 0.5)], z1 - 0.05, z1 + 0.1, shrink=0.0)
    # the door onto the deck (north face): a lancet, dark
    cxd = (x0 + x1) / 2
    intr = lancet(cxd, y0 + 1.7, 0.7)
    prism(P, "dark", [(cxd - 0.7, y0), (cxd + 0.7, y0)] + intr[::-1], z0 - 0.1, z0 + 0.05, shrink=0.0)


def door(P):
    """The open door: a pointed arch of voussoirs in the north wall at the lower landing, a black doorway, a threshold."""
    cx, y, z = DOOR_X, DOOR_Y, ZW + 0.42
    half = 1.3
    spring = 3.3
    intr = lancet(cx, y + spring, half)
    ext = lancet(cx, y + spring, half + 0.75)
    for i in range(0, len(intr) - 2, 2):
        poly = [intr[i], intr[i + 2], ext[i + 2], ext[i]]
        prism(P, "ashlar", poly, z - 0.15, z + 0.55, shrink=0.02)
    # the jambs: tall blocks of alternating length either side
    for sgn in (-1, 1):
        yy = y
        i = 0
        while yy < y + spring - 0.05:
            hh = 0.8 if i % 2 == 0 else 0.55
            hh = min(hh, y + spring - yy)
            wj = 0.75 + (0.28 if i % 2 == 0 else 0.0)
            xc = cx + sgn * (half + wj / 2)
            bev_box(P, "ashlar", (xc, yy + hh / 2, z + 0.2), (wj - 0.03, hh - 0.03, 0.75), bevel=0.04, seg=1)
            yy += hh
            i += 1
    # a hood over it: a moulded course that runs out beyond the voussoirs
    bbeam(P, "ashlar", (cx - half - 1.3, y + spring + 2.05 + 0.9, z + 0.42), (cx + half + 1.3, y + spring + 2.05 + 0.9, z + 0.42), 0.4, 0.28, 0.05, 2)
    # the dark within: a filled arch set deep in the wall
    prism(P, "dark", [(cx - half, y), (cx + half, y)] + intr[::-1], z - 0.05, z + 0.12, shrink=0.0)
    # the threshold: a long worn step
    bev_box(P, "ashlar", (cx, y + 0.1, z + 0.85), (half * 2 + 2.0, 0.22, 1.0), bevel=0.05, seg=2)
    bev_box(P, "ashlar", (cx, y + 0.02, z + 1.45), (half * 2 + 2.8, 0.14, 0.45), bevel=0.04, seg=1)


GLYPHS = [
    [((0, -1), (0, 1))],
    [((0, -1), (0, 1)), ((-0.5, 0.35), (0.5, 0.35))],
    [((-0.35, -1), (-0.35, 1)), ((0.35, -1), (0.35, 1)), ((-0.35, -0.2), (0.35, -0.2))],
    [((0, -1), (0.7, -1)), ((0.35, -1), (0.35, 1))],
    [((-0.4, 0.9), (0.4, 0.9)), ((0, 0.9), (0, -1))],
    [((-0.5, -1), (0.0, 1)), ((0.0, 1), (0.5, -1))],
]


def frieze(P):
    """The Order's inscription: a dressed band under the cornice with two rows of cut glyphs, in raised relief (not paint)."""
    y1 = DECK - 1.2
    xa, xb = XS + 3.4, XT - 6.0
    z = ZW + 0.5
    bev_box(P, "ashlar", ((xa + xb) / 2, y1 - 0.46, z + 0.03), (xb - xa + 0.5, 2.15, 0.12), bevel=0.03, seg=1)
    rg = random.Random(21)
    for row in range(2):
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


def sweep_link(bm, lo, wo, d, arc_n, str_n, ring_n, seed, M=None, hammer=0.0, weld=0.0):
    """A forged link: a stadium swept with a squared wire. Authored in Blender coordinates with the width along X, the
    length along Z (Godot Y) and the wire's thickness along Y: the frame the game's chain placement uses."""
    r = d / 2
    R = wo / 2 - r
    h = lo / 2 - R - r
    path = []
    for i in range(arc_n + 1):
        a = math.pi * i / arc_n
        path.append(((R * math.cos(a), h + R * math.sin(a)), (math.cos(a), math.sin(a))))
    for j in range(1, str_n):
        path.append(((-R, h - 2 * h * j / str_n), (-1, 0)))
    for i in range(arc_n + 1):
        a = math.pi + math.pi * i / arc_n
        path.append(((R * math.cos(a), -h + R * math.sin(a)), (math.cos(a), math.sin(a))))
    for j in range(1, str_n):
        path.append(((R, -h + 2 * h * j / str_n), (1, 0)))
    rg = random.Random(seed)
    nrn = len(path)
    rings = []
    for i, ((px, pz), (nx, nz)) in enumerate(path):
        # the wire: a squared section that wobbles, thickens at the weld (near the top of the link)
        base = 1.0 + 0.045 * math.sin(i * 1.3 + seed) + 0.03 * math.sin(i * 0.5)
        near_weld = math.exp(-((i - arc_n * 0.5) ** 2) / (arc_n * 0.15 + 0.5))
        s = base * (1.0 + weld * near_weld)
        ring = []
        for k in range(ring_n):
            th = math.tau * k / ring_n + 0.2 * math.sin(i * 0.37)
            c, sn = math.cos(th), math.sin(th)
            f = (abs(c) ** 3 + abs(sn) ** 3) ** (-1 / 3)
            dr = r * f * s * (1.0 + hammer * (rg.random() - 0.5))
            v = Vector((px + nx * c * dr, sn * dr, pz + nz * c * dr))
            if M is not None:
                v = M @ v
            ring.append(bm.verts.new(v))
        rings.append(ring)
    for i in range(nrn):
        a, b = rings[i], rings[(i + 1) % nrn]
        for k in range(ring_n):
            k2 = (k + 1) % ring_n
            try:
                bm.faces.new((a[k], b[k], b[k2], a[k2]))
            except ValueError:
                pass


def bitter_end(P):
    """The pylon the first link is shackled to: a stone block with a worn cap, an iron plate and bolts, the great ring
    (horizontal, threaded through the first link's end), the tally stone and the kneeling stone south of it."""
    ring_x = XE_L + LINK_LO / 2 - LINK_D / 2
    ring_y = DECK + 0.5 + (LINK_W / 2 - 0.5) * math.cos(0.66) + 0.03
    cour = Coursing(31, ring_x, ring_x + 5, DECK - 1, DECK + 4, hmin=0.5, hmax=0.8, wmin=0.8, wmax=1.6)
    px0, px1 = ring_x + 0.8, ring_x + 4.0
    top = ring_y - 0.3
    for (face, o, u, n, u0, u1) in (
            ("s", Vector((0, 0, ZC + 1.7)), Vector((1, 0, 0)), Vector((0, 0, 1)), px0, px1),
            ("n", Vector((0, 0, ZC - 1.7)), Vector((-1, 0, 0)), Vector((0, 0, -1)), -px1, -px0),
            ("e", Vector((px1, 0, 0)), Vector((0, 0, -1)), Vector((1, 0, 0)), -ZC - 1.7, -ZC + 1.7)):
        wall(P, "ashlar", o, u, Vector((0, 1, 0)), n, u0, u1, DECK - 0.1, top, cour, cell=0.1)
    bev_box(P, "ashlar", ((px0 + px1) / 2, top - 0.05, ZC), (px1 - px0 + 0.2, 0.2, 3.6), bevel=0.05, seg=2)
    bev_box(P, "iron", (ring_x + 1.4, top + 0.06, ZC), (1.8, 0.1, 2.3), bevel=0.02, seg=1)
    for sz in (-1, 1):
        for sx in (0.5, 2.1):
            bev_box(P, "iron", (ring_x + sx + 0.6, top + 0.14, ZC + sz * 0.95), (0.3, 0.14, 0.3), bevel=0.04, seg=2)
    # the ring: lying flat, its far arc on the plate
    bm = P.of("iron")
    M = Matrix.Translation(B((ring_x, ring_y, ZC))) @ Matrix.Rotation(math.pi / 2, 4, 'Y')
    sweep_link(bm, 3.6, 2.8, 0.6, 12, 3, 12, 7, M=M, hammer=0.05, weld=0.18)
    # the tally stone and the kneeling stone
    tx = ring_x + 1.8
    bev_box(P, "ashlar", (tx, DECK + 0.75, ZC + 4.07), (1.1, 1.5, 0.35), bevel=0.06, seg=2)
    bev_box(P, "ashlar", (tx, DECK + 1.58, ZC + 4.07), (1.3, 0.16, 0.55), bevel=0.05, seg=2)
    for i in range(5):                                                         # the tally, in fives
        for t in range(4):
            bbeam(P, "ashlar", (tx - 0.42 + i * 0.2 + t * 0.03, DECK + 0.5, ZC + 4.26), (tx - 0.42 + i * 0.2 + t * 0.03, DECK + 1.35, ZC + 4.26), 0.025, 0.03, 0.004, 1)
    bev_box(P, "ashlar", (tx - 1.35, DECK + 0.21, ZC + 4.05), (0.95, 0.42, 1.1), bevel=0.06, seg=2)


XE_L = 87.5
LINK_LO, LINK_W, LINK_D = 7.6, 5.0, 1.0


# ============================================================================================
# finishing, export, preview
# ============================================================================================
def tone(key, co, n):
    """Macro tone in vertex colour (Blender z is Godot height)."""
    z = co.z
    nz = max(n.z, 0.0)
    if key == "ashlar":
        v = 0.74 + 0.30 * fbm(co * 0.17 + Vector((1, 9, 4)), 3)
        damp = 1.0 - 0.4 * (1.0 - smooth(-1.0, 6.0, z))
        moss = smooth(-0.1, 0.4, fbm(co * 0.23 + Vector((7, 3, 1)), 3)) * (0.2 + 0.8 * nz) * (0.5 + 0.5 * (1.0 - smooth(0.0, 9.0, z)))
        soot = smooth(0.1, 0.6, fbm(Vector((co.x * 0.7, co.y * 0.7, co.z * 0.06)), 2)) * (1.0 - nz) * 0.25
        r, g, b = v * damp * (1 - moss) + 0.42 * moss, v * damp * (1 - moss) + 0.62 * moss, v * damp * (1 - moss) + 0.32 * moss
        return (r * (1 - soot), g * (1 - soot), b * (1 - soot * 0.8))
    if key == "iron":
        rust = smooth(0.0, 0.5, fbm(co * 0.6, 3) + 0.2)
        return (0.26 + 0.10 * rust, 0.26 - 0.01 * rust, 0.30 - 0.08 * rust)
    return (0.05, 0.05, 0.06)


def finish(P, name, flat_keys=()):
    objs = []
    for key, bm in P.bm.items():
        bm.normal_update()
        for f in bm.faces:
            f.smooth = key not in flat_keys
        ao_l = bm.verts.layers.float.get("ao")
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
                c = tone(key, co, l.vert.normal)
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
            bsdf.inputs["Roughness"].default_value = 0.45 if iron else 0.85
            bsdf.inputs["Metallic"].default_value = 0.6 if iron else 0.0
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
        bpy.ops.export_scene.gltf(export_vertex_color='ACTIVE', **kw)
    except TypeError:
        bpy.ops.export_scene.gltf(**kw)
    print("EXPORTED", path, tri_count(objs), "tris")


# ============================================================================================
# THE CHAIN
# ============================================================================================
LEAN = Vector((-0.30, 0.86, -0.40)).normalized()
ROLL0 = 0.66
CHAIN_LEN = 450.0


def chain_frames(limit_h=1e9):
    """The links' placement (Godot): [(origin, width dir, length dir (tangent), thickness dir, scale)]. On the deck the
    chain lies rolled on its low wire, at the deck's west edge it bends up (radius 13) and climbs, leaning towards the vortex,
    each link larger than the last so the high chain still reads from the village."""
    xb = XS + 3.0
    rb = 13.0
    l1 = XE_L - xb
    l2 = rb * math.pi / 2
    y0 = DECK + 1.9
    pts = []
    p = Vector((XE_L, y0, ZC))
    s = 0.0
    total = l1 + l2 + CHAIN_LEN
    while s <= total:
        pts.append(p.copy())
        if s < l1:
            t = Vector((-1, 0, 0))
        elif s < l1 + l2:
            ph = (s - l1) / rb
            t = Vector((-math.cos(ph), math.sin(ph), 0))
        else:
            w = smooth(0.0, 220.0, s - l1 - l2)
            t = (Vector((0, 1, 0)).lerp(LEAN, w)).normalized()
        p = p + t * 0.5
        s += 0.5

    def at(sv):
        f = max(0.0, min(len(pts) - 1.0, sv / 0.5))
        i = min(int(f), len(pts) - 2)
        return pts[i].lerp(pts[i + 1], f - i)
    pitch = LINK_LO - 3 * LINK_D
    out = []
    sv, i = 0.0, 0
    rr = LINK_W / 2 - LINK_D / 2
    while sv < total - 6.0:
        sc = 1.0 + 1.6 * smooth(40.0, 430.0, sv)
        pos = at(sv)
        if pos.y > limit_h:
            break
        t = (at(sv + pitch * sc) - at(max(sv - pitch * sc, 0.0))).normalized()
        lam = ROLL0 * (1.0 - smooth(l1 - 4.0, l1 + l2, sv))
        n0 = t.cross(Vector((0, 0, 1))).normalized()
        from mathutils import Quaternion
        wid = Quaternion(t, lam + (math.pi / 2 if i % 2 else 0.0)) @ n0
        thk = wid.cross(t).normalized()
        rest_y = DECK + LINK_D / 2 * sc + rr * sc * abs(wid.y) + 0.03
        wgt = 1.0 - smooth(l1 - 3.0, l1 + 4.0, sv)
        if sv < l1 + 4.0:
            pos.y = pos.y * (1 - wgt) + rest_y * wgt
        out.append((pos, wid, t, thk, sc))
        sv += pitch * sc
        i += 1
    return out


def link_mats(frames, near=14):
    for (pos, wid, t, thk, sc) in frames:
        cols = (B(wid) * sc, -B(thk) * sc, B(t) * sc)
        M = Matrix((cols[0], cols[1], cols[2])).transposed().to_4x4()
        M.translation = B(pos)
        yield M


def build_links(P_iron_bm, frames, hi_count=12):
    n = 0
    for k, M in enumerate(link_mats(frames)):
        if k < hi_count:
            sweep_link(P_iron_bm, LINK_LO, LINK_W, LINK_D, 16, 4, 14, 11 + k, M=M, hammer=0.06, weld=0.2)
        elif k < 40:
            sweep_link(P_iron_bm, LINK_LO, LINK_W, LINK_D, 8, 2, 8, 11 + k, M=M)
        else:
            sweep_link(P_iron_bm, LINK_LO, LINK_W, LINK_D, 4, 1, 6, 11 + k, M=M)
        n += 1
    return n


def asset_link():
    reset()
    P = Parts()
    bm = P.of("iron")
    sweep_link(bm, LINK_LO, LINK_W, LINK_D, 16, 4, 14, 3, hammer=0.06, weld=0.2)
    objs = finish(P, "SkyChainLinkHi", flat_keys=())
    P2 = Parts()
    sweep_link(P2.of("iron"), LINK_LO, LINK_W, LINK_D, 8, 2, 8, 4)
    objs += finish(P2, "SkyChainLinkMid", flat_keys=())
    P3 = Parts()
    sweep_link(P3.of("iron"), LINK_LO, LINK_W, LINK_D, 4, 1, 6, 5)
    objs += finish(P3, "SkyChainLinkLo", flat_keys=())
    P4 = Parts()
    sweep_link(P4.of("iron"), 1.5, 1.0, 0.24, 5, 1, 6, 6, hammer=0.1)
    objs += finish(P4, "SkyChainLinkSmall", flat_keys=())
    print("link tris", tri_count(objs))
    # a lying run of links on the deck, for the eye
    P5 = Parts()
    build_links(P5.of("iron"), chain_frames(DECK + 30.0), 12)
    show = finish(P5, "Run", flat_keys=())
    for o in objs:
        o.hide_render = True
    preview("links", [((70, 30, -112), (74, 22, -133), 40), ((66, 24, -122), (66, 22, -134), 55)])
    if "--export" in args:
        os.makedirs(MODELS, exist_ok=True)
        export(objs, os.path.join(MODELS, "sky_chain_link.glb"))


def asset_anchor():
    reset()
    P = build_anchor()
    objs = finish(P, "SkyChainAnchor")
    export_objs = list(objs)
    PC = Parts()
    build_links(PC.of("iron"), chain_frames(), 12)
    chain_objs = finish(PC, "PreviewChain", flat_keys=())
    print("anchor tris", tri_count(objs), "stair xs %.2f y0 %.2f rise %.3f worst clearance %.2f" % (XS, Y0, RISE, WORST))
    views = [((70, 3, 60), (72, 44, -135), 22),          # from the road
             ((6, 3, 38), (66, 40, -135), 22),            # from Hearthward
             ((64, 4, -60), (74, 26, -135), 30),          # mid distance
             ((50, 6, -108), (72, 14, -128), 30),         # the stair's foot
             ((74, 8, -116), (70, 9, -126), 42),          # the door
             ((82, 21, -118), (88, 19, -132), 34),        # the stair head, the tower
             ((57, 24, -128), (82, 19, -134), 36),        # the deck, the chain's cradle
             ((100, 22, -126), (88, 22, -134), 34)]       # the bitter end
    preview("anchor", views)
    if "--export" in args:
        os.makedirs(MODELS, exist_ok=True)
        export(export_objs, os.path.join(MODELS, "sky_chain_anchor.glb"))


ASSETS = {"anchor": asset_anchor, "link": asset_link}

if __name__ == "__main__":
    for k, fn in ASSETS.items():
        if ONLY and k not in ONLY:
            continue
        print("=== ", k)
        fn()
