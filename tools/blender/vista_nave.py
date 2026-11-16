"""THE DROWNED NAVE: the Order's unfinished cathedral standing in its flooded basin (the East Reach). The nave went up
first and the floor was to be laid last; the water came in before the floor did. Remodelled stone by stone on
masonry_lib (the Broken Keep's dressed masonry): every wall a rubble core faced with coursed ashlar, the piers
clustered drums on moulded bases under bell capitals, pointed arcades of voussoirs, window tracery (lights, sub-arches,
an oculus), stepped buttresses with weatherings and pinnacles, flyers to the clerestory, quadripartite vault ribs
standing open to the sky over the west bays, a west front of three recessed portals under a ragged gable, a tower stump
in its scaffold and the twin's footings with the masons' crane still rigged; the apse broken round the altar.

  tools/blender/run.sh vista_nave.py -- [--preview DIR]

Exports art/models/reach_e_nave.glb:
  Nave__hewn, NaveCore__stone, Nave__timber, Nave__iron   the standing fabric (the game sets each set's tiling material)
  NaveFar__stone                                          the silhouette (the game swaps to it from 160 m)
  NaveCol__stone                                          collision primitives (the game makes it a trimesh body)

Frame: Blender Z up, 1 BU = 1 m; Blender +Y is Godot -Z. The origin is the nave's middle on the basin floor (the water
stands 0.6 m over it). The nave runs along Y: the west front at y +28.5 (facing +y, Godot -z, the way nave_track comes),
the apse round (0, -20), the altar at y -26.5. Modelled by script; nothing is downloaded.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bmesh
import bpy
from mathutils import Vector, Matrix, noise

import r37_west as W
import masonry_lib as ML

Parts, beam, cyl, finish, export, preview, reset = W.Parts, W.beam, W.cyl, W.finish, W.export, W.preview, W.reset
box = W.box

PX = 5.2                                    # the arcade lines
PY = [22.0 - 6.0 * k for k in range(8)]     # the pier pairs, west to east
SPRING = 9.0                                # the arcade springs
ARC = (2.15, 2.15 * 1.72)                   # the arcade's opening (half-span, rise)
CLR = (1.2, 2.1)                            # a clerestory window
AIS = (0.9, 1.6)                            # an aisle window
APS = (0.95, 1.65)                          # an apse window
VAULT = 17.5                                # the vault springs
AISLE_X = 10.8
FRONT_Y = 28.5
APSE_C = (0.0, -20.0)
APSE_R = 10.8
ALTAR_Y = -26.5
rnd = random.Random(1717)
M = None                                    # the Mason


# ============================================================================================ arches
def pointed(a, H):
    """A two-centred arch of half-span a and rise H: (c, R): the centres sit c to the far side of the axis, radius R."""
    c = (H * H - a * a) / (2.0 * a)
    return c, a + c


def concentric(o, t):
    """The arch t outside arch o = (a, H), on the same centres (its extrados): (a + t, H')."""
    a, H = o
    c, R = pointed(a, H)
    return (a + t, math.sqrt((R + t) ** 2 - c * c))


def hole(u, v, cu, o, t, sill, spring):
    """Inside the opening o = (a, H) together with its ring of depth t (the wall's own mask round a dressed opening)."""
    a, H = concentric(o, t)
    return pointed_hole(u, v, cu, a, H, sill, spring)


def dress(F, cu, o, t, sill, spring, half, n=6, tone=0.86, jambs=True):
    """The dressed stones of an opening in wall F: its ring of voussoirs and, below the springing, its jambs."""
    ring(F.p(cu, spring, 0.0), F.T, F.N, o[0], o[1], t, -half - 0.02, half + 0.02, n=n, tone=tone)
    if not jambs:
        return
    yaw = math.atan2(F.T.y, F.T.x)
    for sd in (1, -1):
        v = sill
        j = 0
        while v < spring - 0.05:
            hh = min(rnd.uniform(0.36, 0.52), spring - v)
            M.block(F.p(cu + sd * (o[0] + t * 0.5), v + hh * 0.5, 0.0), (t - 0.02, half * 2 + (0.06 if j % 2 else 0.0), hh - 0.02), yaw=yaw,
                    bevel=0.04, tone=rnd.uniform(0.8, 0.92))
            v += hh
            j += 1


def pointed_hole(u, v, cu, a, H, sill, spring):
    du = abs(u - cu)
    if du > a or v < sill:
        return False
    if v <= spring:
        return True
    c, R = pointed(a, H)
    return (du + c) ** 2 + (v - spring) ** 2 <= R * R


def arch_pts(a, H, ring, n):
    """Voussoir outlines of a pointed arch (u across, v up from the springing): [(in0, in1, out1, out0)] per stone,
    n a side, the joints radial to each half's centre; a keystone closes the crown."""
    c, R = pointed(a, H)
    th_c = math.acos(max(-1.0, min(1.0, c / R)))
    th_o = math.acos(max(-1.0, min(1.0, c / (R + ring))))       # the extrados meets the axis further round
    out = []
    for side in (1, -1):
        for i in range(n):
            f0, f1 = i / n, (i + 1) / n

            def P(f, r, th):
                t = th * f
                return (side * (-c + r * math.cos(t)), r * math.sin(t))
            out.append((P(f0, R, th_c), P(f1, R, th_c), P(f1, R + ring, th_o), P(f0, R + ring, th_o)))
    return out


def ring(org, ex, ny, a, H, ring_w, d0, d1, n=7, tone=None, bevel=0.05):
    """A pointed arch ring of voussoirs in the vertical plane through org (ex across, z up), from depth d0 to d1 along ny."""
    ez = Vector((0, 0, 1))
    for q in arch_pts(a, H, ring_w, n):
        pts = [org + ex * u + ez * v for (u, v) in q]
        M.hexa([p + ny * d0 for p in pts] + [p + ny * d1 for p in pts], bevel=bevel, tone=tone)


# ============================================================================================ piers
def clustered(n=28):
    """The pier's section: a drum with four major shafts on the axes and four minor ones on the diagonals."""
    lobes = [(0.0, 0.0, 0.84)] + [(0.86, math.pi * 0.5 * k, 0.27) for k in range(4)] + \
            [(0.86, math.pi * 0.25 + math.pi * 0.5 * k, 0.15) for k in range(4)]
    pts = []
    for i in range(n):
        th = math.tau * i / n
        best = 0.0
        for (d, phi, rho) in lobes:
            s = math.sin(th - phi)
            disc = rho * rho - d * d * s * s
            if disc >= 0.0:
                best = max(best, d * math.cos(th - phi) + math.sqrt(disc))
        pts.append((math.cos(th) * best, math.sin(th) * best))
    return pts


def octagon(r, rot=math.pi / 8):
    return [(math.cos(rot + math.tau * i / 8) * r, math.sin(rot + math.tau * i / 8) * r) for i in range(8)]


def loft(c, rings, tone, cap_top=True, cap_bot=False, smooth=False):
    """Rings of (z, scale or [pts]) about plan centre c, joined; each ring a list of (x, y) offsets."""
    bm = M.stone
    vr = []
    for (z, pts) in rings:
        vr.append([Vector((c[0] + x, c[1] + y, z)) for (x, y) in pts])
    inside = Vector((c[0], c[1], (rings[0][0] + rings[-1][0]) * 0.5))
    base = tone
    tint = (1.02, 1.0, 0.95)
    uvo = (rnd.random(), rnd.random())
    for a, b in zip(vr[:-1], vr[1:]):
        n = len(a)
        for i in range(n):
            q = [a[i], a[(i + 1) % n], b[(i + 1) % n], b[i]]
            ctr = Vector((c[0], c[1], q[0].z))
            M.face(bm, q, ctr if abs(q[0].z - q[3].z) > 1e-4 else inside,
                   [M.tone(p, (p - ctr).normalized() if (p - ctr).length > 1e-6 else Vector((0, 0, 1)), base, tint) for p in q], uvo, smooth=smooth)
    if cap_top:
        q = vr[-1]
        M.face(bm, list(q), q[0] - Vector((0, 0, 1.0)) + (Vector((c[0], c[1], q[0].z)) - q[0]),
               [M.tone(p, Vector((0, 0, 1)), base, tint) for p in q], uvo)
    if cap_bot:
        q = vr[0]
        M.face(bm, list(q), Vector((c[0], c[1], q[0].z + 1.0)), [M.tone(p, Vector((0, 0, -1)), base, tint) for p in q], uvo)


def scaled(pts, k, dx=0.0):
    return [(x * k, y * k) for (x, y) in pts]


def pier(c, top, shaft_side):
    sec = clustered()
    # the base: a square plinth, an octagonal sub-base and a moulded base (two rolls)
    M.block((c[0], c[1], -0.4), (2.7, 2.7, 1.6), bevel=0.08, tone=0.66)
    o = octagon(1.36)
    loft(c, [(0.4, o), (0.75, o), (0.82, octagon(1.28))], 0.8, cap_top=True)
    loft(c, [(0.82, scaled(sec, 1.2)), (0.98, scaled(sec, 1.24)), (1.1, scaled(sec, 1.14)), (1.22, scaled(sec, 1.06)),
             (1.32, scaled(sec, 1.1)), (1.42, scaled(sec, 1.0))], 0.84, cap_top=False, smooth=True)
    # the shaft: drums, each its own stone with a small chamfer at the joint
    z = 1.42
    while z < SPRING - 0.85 - 0.3:
        hh = min(rnd.uniform(0.62, 0.86), SPRING - 0.85 - z)
        t = rnd.uniform(0.74, 0.92)
        loft(c, [(z, scaled(sec, 0.955)), (z + 0.04, sec), (z + hh, sec)], t, cap_top=False, smooth=True)
        z += hh
    # the capital: necking, a bell flaring to the abacus
    loft(c, [(z, sec), (z + 0.1, scaled(sec, 1.04)), (z + 0.16, scaled(sec, 0.98))], 0.84, cap_top=False, smooth=True)
    zc = z + 0.16
    bell = [(zc + 0.16 * k, [(x * (1.0 + 0.09 * k * k * 0.3), y * (1.0 + 0.09 * k * k * 0.3)) for (x, y) in sec]) for k in range(5)]
    loft(c, bell, 0.86, cap_top=False, smooth=True)
    za = zc + 0.64
    loft(c, [(za, octagon(1.38)), (za + 0.18, octagon(1.38)), (za + 0.3, octagon(1.3))], 0.88, cap_top=True)
    # a wall-shaft on the nave side up to the vault springing, where the vault stood
    if top > SPRING + 1.0:
        sx = c[0] + shaft_side * (-0.95)
        sc = (sx, c[1])
        r = [(math.cos(math.tau * i / 10) * 0.24, math.sin(math.tau * i / 10) * 0.24) for i in range(10)]
        z = za + 0.3
        while z < top - 0.1:
            hh = min(rnd.uniform(0.7, 1.0), top - z)
            loft(sc, [(z, scaled(r, 0.92)), (z + 0.03, r), (z + hh - 0.03, r), (z + hh, scaled(r, 0.92))], rnd.uniform(0.78, 0.9), cap_top=False)
            z += hh
        if top >= VAULT - 0.05:
            loft(sc, [(top, scaled(r, 1.1)), (top + 0.3, scaled(r, 1.9)), (top + 0.45, scaled(r, 1.9))], 0.86, cap_top=True)
    box(Pc, "stone", (c[0], c[1], SPRING * 0.5 - 1.0), (2.0, 2.0, SPRING + 1.4))


# ============================================================================================ tracery
def bar(pts, w, d, ny, tone=0.86):
    """A stone bar along the polyline pts (in a vertical plane with normal ny), w wide in the plane, d deep."""
    for p0, p1 in zip(pts[:-1], pts[1:]):
        t = (p1 - p0)
        ln = t.length
        if ln < 1e-4:
            continue
        t.normalize()
        side = ny.cross(t).normalized()
        cs = [p0 + side * (w * 0.5), p0 - side * (w * 0.5), p1 - side * (w * 0.5), p1 + side * (w * 0.5)]
        # overlap the joints a touch so the bends close
        cs = [cs[0] - t * 0.02, cs[1] - t * 0.02, cs[2] + t * 0.02, cs[3] + t * 0.02]
        M.hexa([p - ny * (d * 0.5) for p in cs] + [p + ny * (d * 0.5) for p in cs], bevel=0.0, tone=tone)


def arc_pts(org, ex, cx, cz, R, t0, t1, n):
    ez = Vector((0, 0, 1))
    return [org + ex * (cx + R * math.cos(t0 + (t1 - t0) * i / n)) + ez * (cz + R * math.sin(t0 + (t1 - t0) * i / n)) for i in range(n + 1)]


def pointed_bar(org, ex, ny, cu, a, H, spring, w, d, tone=0.86, n=7):
    c, R = pointed(a, H)
    th = math.acos(max(-1.0, min(1.0, c / R)))
    right = arc_pts(org, ex, cu - c, spring, R, 0.0, th, n)
    left = arc_pts(org, ex, cu + c, spring, R, math.pi, math.pi - th, n)
    bar(right, w, d, ny, tone)
    bar(left, w, d, ny, tone)


def tracery(org, ex, ny, cu, w, sill, spring, lights, broken=0.0):
    """Tracery in a pointed window (the opening's own half-span w/2, rise = w * 0.866): mullions, sub-arches and an
    oculus with a cusped quatrefoil, the bars set in the wall's middle. broken: the chance a piece has fallen."""
    a = w * 0.5
    H = w * 0.866
    mw = 0.17
    lw = (w - mw * (lights - 1)) / lights
    for k in range(1, lights):
        u = cu - a + k * lw + (k - 0.5) * mw
        if rnd.random() >= broken:
            bar([org + ex * u + Vector((0, 0, sill)), org + ex * u + Vector((0, 0, spring + lw * 0.2))], mw, 0.3, ny)
    if rnd.random() < broken * 1.4:
        return
    for k in range(lights):
        u0 = cu - a + k * (lw + mw)
        pointed_bar(org, ex, ny, u0 + lw * 0.5, lw * 0.5 + mw * 0.5, (lw + mw) * 0.8, spring, mw * 0.9, 0.26, n=5)
    # the oculus: a ring between the lights' heads and the arch's crown, a quatrefoil of cusps inside
    top = spring + H - 0.12
    sub = spring + (lw + mw) * 0.8
    r = min((top - sub) * 0.5 - 0.06, a * 0.5)
    if r > 0.22 and rnd.random() >= broken:
        cz = (top + sub) * 0.5
        bar(arc_pts(org, ex, cu, cz, r, 0.0, math.tau, 14), mw * 0.85, 0.26, ny)
        for k in range(4):
            ang = math.pi * 0.25 + math.pi * 0.5 * k
            ccx, ccz = cu + math.cos(ang) * r * 0.48, cz + math.sin(ang) * r * 0.48
            bar(arc_pts(org, ex, ccx, ccz, r * 0.42, ang + 1.9, ang + math.tau - 1.9, 5), 0.07, 0.2, ny)


# ============================================================================================ walls
def wall(a, b, z0, h, half, solid, ends=(0.0, 0.0), ch=0.68, blk=(1.05, 2.2), faces=(1, -1), dress_ends=False, col=True):
    F = ML.Flat(a, b, z0)
    M.wall(F, half, h, solid, rnd, u_range=(-ends[0], F.L + ends[1]), ch=ch, blk=blk, skip_below=0.7, faces=faces,
           dress_ends=dress_ends)
    if col:
        # collision: columns of the mask, merged to boxes (as the keep's)
        u = -ends[0]
        while u < F.L + ends[1] - 1e-3:
            wdt = min(1.0, F.L + ends[1] - u)
            uc = u + wdt * 0.5
            v0 = None
            k = 0
            nv = int(h / 0.25)
            for i in range(nv + 1):
                v = min(i * 0.25, h)
                s = solid(min(max(uc, 0.0), F.L), v) and i < nv
                if s and v0 is None:
                    v0 = v
                if (not s) and v0 is not None:
                    if v - v0 > 0.3:
                        cc = F.p(uc, (v0 + v) * 0.5, 0.0)
                        box(Pc, "stone", cc, (wdt, half * 2.0, v - v0), yaw=math.atan2(F.T.y, F.T.x))
                    v0 = None
            u += wdt
    return F


def ragged(seed, h, amp, scale=0.3):
    def top(u):
        t = ML.fbm(Vector((u * scale, seed * 3.1, 0.7))) * 0.5 + 0.5
        return h - amp * max(0.0, t * 1.5 - 0.25)
    return top


def course(F, u0, u1, v, hh, dd, tone=0.88, side=1):
    """A moulded string course of stones along wall frame F at height v, standing dd proud of the face."""
    n = max(1, int((u1 - u0) / 1.2))
    for k in range(n):
        if rnd.random() < 0.06:
            continue
        a, b_ = u0 + (u1 - u0) * k / n, u0 + (u1 - u0) * (k + 1) / n
        p = F.p((a + b_) * 0.5, v, side * (F_half(F) + dd * 0.5 - 0.05))
        M.block(p, ((b_ - a) - 0.025, dd + 0.1, hh), yaw=math.atan2(F.T.y, F.T.x), bevel=0.06, tone=tone)


_halves = {}


def F_half(F):
    return _halves.get(id(F), 0.6)


# ============================================================================================ the nave
def bay_top(k):
    """How high the arcade wall stands over bay k (k -1 is the half-bay at the west front; 7 is the last)."""
    return {-1: 26.6, 0: 26.0, 1: 23.8, 2: 20.6, 3: 14.6}.get(k, 11.4 + 1.6 * (k % 2))


def arcade_side(xs):
    """The arcade wall on one side: sits on the capitals, the arches cut from it, the clerestory above."""
    x = xs * PX
    us = [FRONT_Y - y for y in PY]                     # pier stations along the run (u from the front)
    tops = []
    for k in range(-1, 8):
        u0 = 0.0 if k == -1 else us[k]
        u1 = us[k + 1] if k + 1 < 8 else us[-1] + 0.6
        tops.append((u0, u1, k))
    rag = ragged(40 + xs, 1.0, 1.0, 0.35)

    def top(u):
        for (u0, u1, k) in tops:
            if u0 <= u <= u1:
                h = bay_top(k)
                # the break: each bay's top eases into the next, ragged
                kn = k + 1 if k < 7 else k
                t = ML.sstep(u1 - 2.2, u1 + 0.6, u)
                h = h * (1 - t) + bay_top(kn) * t
                if k >= 1:
                    h -= 1.6 * (rag(u) - 0.0) * (1.0 if k >= 2 else 0.4)
                return h
        return 10.0

    def solid(u, v):
        if v > top(u):
            return False
        if v < SPRING + 0.6:
            return False
        for k in range(-1, 7):
            u0 = 0.0 if k == -1 else us[k]
            u1 = us[k + 1]
            cu = (u0 + u1) * 0.5 if k >= 0 else u1 - 3.0
            if hole(u, v, cu, ARC, 0.78, 0.0, SPRING + 0.6):
                return False
            # the clerestory windows over the standing bays
            if k <= 2 and hole(u, v, cu, CLR, 0.3, 15.6, 19.0):
                return False
        return True
    F = wall((x, FRONT_Y - 0.8), (x, PY[-1] - 0.6), 0.0, 27.0, 0.6, solid, ends=(0.0, 0.0))
    _halves[id(F)] = 0.6
    ex = F.T
    ny = F.N
    # the arcade's voussoirs (two orders) and its hood-mould, each bay
    for k in range(-1, 7):
        u0 = 0.0 if k == -1 else us[k]
        u1 = us[k + 1]
        cu = (u0 + u1) * 0.5 if k >= 0 else u1 - 3.0
        org = F.p(cu, SPRING + 0.6, 0.0)
        ring(org, ex, ny, ARC[0], ARC[1], 0.42, -0.62, 0.62, n=6, tone=0.86)
        o2 = concentric(ARC, 0.42)
        ring(org, ex, ny, o2[0], o2[1], 0.36, -0.5, 0.5, n=7, tone=0.8)          # the outer order, stepped back
        o3 = concentric(o2, 0.36)
        if bay_top(k) > SPRING + 5.0:
            for sd in (1, -1):
                ring(org, ex, ny, o3[0], o3[1], 0.16, sd * 0.6, sd * 0.78, n=7, tone=0.9, bevel=0.03)
        if k <= 2:
            dress(F, cu, CLR, 0.3, 15.6, 19.0, 0.6, n=5, tone=0.88)
            tracery(F.p(0.0, 0.0, 0.0), ex, ny, cu, CLR[0] * 2, 15.6, 19.0, 2, broken=0.25 if k == 2 else 0.05)
            sill = F.p(cu, 15.5, 0.0)
            M.block(sill, (2.7, 1.4, 0.2), yaw=math.atan2(ex.y, ex.x), bevel=0.05, tone=0.86)
    # string courses: over the arcade (the triforium line) and under the clerestory, where the wall stands
    for (v, hh) in ((SPRING + 5.2, 0.32), (15.0, 0.28)):
        for side in (1, -1):
            u = 0.0
            while u < F.L:
                if top(u) > v + 0.7:
                    u1 = u
                    while u1 < F.L and top(u1) > v + 0.7:
                        u1 += 0.3
                    if u1 - u > 1.0:
                        course(F, u, u1, v, hh, 0.22, side=side)
                    u = u1
                u += 0.3
    return F


def ribs():
    """Quadripartite ribs over the two west bays, transverse ribs over the next two (the last one half fallen),
    bosses at the crowns, the ridge rib where it stands."""
    xs = PX - 0.95
    for k in range(4):
        y = PY[k]
        org = Vector((0.0, y, VAULT + 0.45))
        ex = Vector((1.0, 0, 0))
        ny = Vector((0, 1.0, 0))
        stones = arch_pts(xs, 8.0, 0.5, 9)
        for i, q in enumerate(stones):
            if k == 3 and q[0][0] < -0.2 and i > 12:
                continue                                     # half of the last one is down in the water
            pts = [org + ex * u + Vector((0, 0, v)) for (u, v) in q]
            M.hexa([p - ny * 0.22 for p in pts] + [p + ny * 0.22 for p in pts], bevel=0.05, tone=0.86)
    for k in range(2):
        y0, y1 = PY[k], PY[k + 1]
        for (xa, ya, xb, yb) in ((-xs, y0, xs, y1), (xs, y0, -xs, y1)):
            a = Vector((xa, ya, VAULT + 0.45))
            b_ = Vector((xb, yb, VAULT + 0.45))
            mid = (a + b_) * 0.5
            ex = (b_ - a).normalized()
            ny = Vector((0, 0, 1)).cross(ex).normalized()
            half = (b_ - a).length * 0.5
            for q in arch_pts(half, 8.0, 0.42, 10):
                pts = [mid + ex * u + Vector((0, 0, v)) for (u, v) in q]
                M.hexa([p - ny * 0.19 for p in pts] + [p + ny * 0.19 for p in pts], bevel=0.045, tone=0.84)
        # the boss where the diagonals cross, and a ridge rib along the crown
        cy = (y0 + y1) * 0.5
        M.block((0.0, cy, VAULT + 0.45 + 8.0 + 0.2), (0.85, 0.85, 0.7), yaw=math.pi / 4, bevel=0.14, tone=0.9)
        M.block((0.0, cy, VAULT + 0.45 + 8.0 + 0.2), (0.6, 0.6, 0.95), bevel=0.12, tone=0.84)
        n = 5
        for i in range(n):
            ya = y0 - (y0 - y1) * i / n
            yb = y0 - (y0 - y1) * (i + 1) / n
            M.block((0.0, (ya + yb) * 0.5, VAULT + 0.45 + 8.0 + 0.2), (0.32, abs(yb - ya) - 0.03, 0.42), bevel=0.04, tone=0.86)
    # a patch of web still hung between the ribs of the first bay: courses of thin stones on the cells' curve
    y0, y1 = PY[0], PY[1]
    for j in range(9):
        t = j / 9.0
        z = VAULT + 0.45 + 8.0 * math.sin(t * math.pi * 0.5) ** 0.7
        w = (1.0 - t) * 2.6 + 0.6
        for sx in (-1, 1):
            if rnd.random() < 0.25 and j > 3:
                continue
            xc = sx * (xs - w * 0.5 - t * (xs - w * 0.5)) * 0.92
            M.block((xc, y0 - 0.5 - t * 2.4, z - 0.1), (w, 0.9, 0.18), pitch=0.0, roll=sx * (0.6 - 0.6 * t), bevel=0.03, tone=0.8)


# ============================================================================================ aisles, buttresses
def aisle_side(xs):
    x = xs * AISLE_X
    stations = [FRONT_Y - (25.0 - 6.0 * k) for k in range(-1, 8)]   # u of the window centres (y 25 .. -17 and the front half)
    stations = [u for u in stations if 0.5 < u < 49.0]
    h_of = {}
    for k, u in enumerate(stations):
        h_of[k] = 10.0 if k <= 4 else (7.8 if k == 5 else 4.6)
    tp = ragged(70 + xs, 0.0, 1.4, 0.4)

    def top(u):
        k = min(range(len(stations)), key=lambda i: abs(stations[i] - u))
        h = h_of[k]
        if k >= 3:
            h += tp(u)
        return h

    def solid(u, v):
        if v - 1.2 > top(u):
            return False
        for k, cu in enumerate(stations):
            if hole(u, v, cu, AIS, 0.3, 3.4 + 1.2, 7.4 + 1.2):
                return False
        return True
    F = wall((x, FRONT_Y - 0.6), (x, -20.0), -1.2, 12.0, 0.7, solid, ends=(0.0, 0.0))
    _halves[id(F)] = 0.7
    ex, ny = F.T, F.N
    for k, cu in enumerate(stations):
        top_k = h_of[k] + (tp(cu) if k >= 3 else 0.0)
        dress(F, cu, AIS, 0.3, 3.4 + 1.2, 7.4 + 1.2, 0.7, n=5, jambs=top_k > 4.0)
        if top_k >= 8.6:
            tracery(F.p(0.0, 1.2, 0.0), ex, ny, cu, AIS[0] * 2, 3.4, 7.4, 2, broken=0.15 if k >= 3 else 0.0)
        M.block(F.p(cu, 3.4 + 1.2 - 0.06, 0.0), (2.2, 1.6, 0.18), yaw=math.atan2(ex.y, ex.x), bevel=0.05, tone=0.84)
    # the buttresses at each pier line
    for k, y in enumerate(PY):
        hh = 10.8 if k <= 5 else 6.4
        buttress((x + xs * 0.7, y), (xs, 0.0), hh, pinnacle=k <= 3, seed=k + (0 if xs > 0 else 20))
    # flyers over the aisle to the clerestory on the standing bays
    for k in (0, 1, 2):
        flyer(xs, PY[k])
    return F


def buttress(foot, out, hh, pinnacle=False, seed=0, width=1.5, depth=2.8):
    """A stepped buttress standing out along `out` (a unit plan vector) from foot (on the wall's face): courses of
    dressed stones, two weatherings, a gabled cap and a pinnacle."""
    o = Vector((out[0], out[1], 0.0))
    s = Vector((-o.y, o.x, 0.0))
    yaw = math.atan2(o.y, o.x)
    steps = [(-9.0, depth), (3.4, depth - 0.6), (6.6, depth - 1.2)]
    z = -1.0
    j = 0
    r = random.Random(seed)
    while z < hh - 0.05:
        ch = min(r.uniform(0.62, 0.82), hh - z)
        d = [dd for (z0, dd) in steps if z >= z0 - 1e-6][-1]
        cuts = [0.0, d] if (j % 2) else [0.0, d * r.uniform(0.4, 0.6), d]
        for i in range(len(cuts) - 1):
            a0, a1 = cuts[i], cuts[i + 1]
            c = Vector((foot[0], foot[1], 0.0)) + o * ((a0 + a1) * 0.5 - 0.15) + Vector((0, 0, z + ch * 0.5))
            M.block(c, (a1 - a0 - 0.02, width, ch - 0.02), yaw=yaw, bevel=0.05, tone=r.uniform(0.74, 0.9), rnd=r)
        z += ch
        j += 1
        # a weathering: a sloped cap where the buttress steps in
        for (z0, dd) in steps[1:]:
            if abs(z - z0) < 0.33 and z < hh - 0.3:
                d_prev = [d2 for (z1, d2) in steps if z1 < z0][-1]
                c = Vector((foot[0], foot[1], 0.0)) + o * (dd + (d_prev - dd) * 0.5 - 0.15) + Vector((0, 0, z + 0.14))
                M.block(c, (d_prev - dd + 0.1, width + 0.08, 0.26), yaw=yaw, pitch=0.0, roll=0.42, bevel=0.04, tone=0.88, rnd=r)
    dtop = [dd for (z0, dd) in steps if hh >= z0][-1]
    c = Vector((foot[0], foot[1], hh)) + o * (dtop * 0.5 - 0.15)
    box(Pc, "stone", (foot[0] + o.x * (depth * 0.5 - 0.15), foot[1] + o.y * (depth * 0.5 - 0.15), (hh - 1.0) * 0.5 - 0.5),
        (depth, width, hh + 1.0), yaw=yaw)
    # the cap: two sloped stones meeting in a ridge
    for sd in (1, -1):
        M.block(c + s * (sd * width * 0.24) + Vector((0, 0, 0.22)), (dtop + 0.1, width * 0.56, 0.24), yaw=yaw, pitch=-sd * 0.55, bevel=0.03, tone=0.88, rnd=r)
    if pinnacle:
        pc = c + Vector((0, 0, 0.45))
        z = pc.z
        sq = [(math.cos(math.pi / 4 + math.tau * i / 4) * 0.5, math.sin(math.pi / 4 + math.tau * i / 4) * 0.5) for i in range(4)]
        loft((pc.x, pc.y), [(z, scaled(sq, 1.1)), (z + 0.2, scaled(sq, 1.1)), (z + 0.2, sq), (z + 1.6, sq), (z + 1.7, scaled(sq, 1.15)),
                            (z + 1.85, scaled(sq, 1.15))], 0.86, cap_top=False)
        z += 1.85
        sp = octagon(0.42)
        loft((pc.x, pc.y), [(z, sp), (z + 2.2, scaled(sp, 0.08))], 0.84, cap_top=True)
        for i in range(3):                                      # crockets up the spire
            zz = z + 0.5 + i * 0.6
            for k in range(4):
                a = math.pi / 4 + math.tau * k / 4
                rr = 0.42 * (1.0 - (zz - z) / 2.2) + 0.08
                M.block((pc.x + math.cos(a) * rr, pc.y + math.sin(a) * rr, zz), (0.16, 0.16, 0.12), yaw=a, pitch=0.5, bevel=0.03, tone=0.86, rnd=r)
        M.block((pc.x, pc.y, z + 2.3), (0.22, 0.22, 0.22), yaw=math.pi / 4, bevel=0.06, tone=0.9, rnd=r)


def flyer(xs, y):
    """A flying buttress from the aisle buttress's top to the clerestory wall: a half arch of voussoirs under a sloped
    coping."""
    xb, zb = xs * (AISLE_X + 2.3), 10.95
    xw, zw = xs * (PX + 0.62), 15.0
    n = 9
    ny = Vector((0, 1.0, 0))
    for i in range(n):
        t0, t1 = i / n, (i + 1) / n

        def low(t):
            # the soffit: a quarter ellipse from the buttress up to the wall
            x = xb + (xw - xb) * math.sin(t * math.pi * 0.5)
            z = zb - 0.7 + (zw - (zb - 0.7)) * (1.0 - math.cos(t * math.pi * 0.5)) ** 0.8
            return Vector((x, y, z))

        def high(t):
            return Vector((xb + (xw - xb) * t, y, zb + 0.5 + (zw + 0.9 - zb - 0.5) * t))
        a0, a1 = low(t0), low(t1)
        b0, b1 = high(t0), high(t1)
        pts = [a0, a1, b1, b0]
        M.hexa([p - ny * 0.32 for p in pts] + [p + ny * 0.32 for p in pts], bevel=0.04, tone=rnd.uniform(0.76, 0.9))
    for i in range(6):                                            # the coping
        t0, t1 = i / 6, (i + 1) / 6
        p0 = Vector((xb + (xw - xb) * t0, y, zb + 0.5 + (zw + 0.9 - zb - 0.5) * t0))
        p1 = Vector((xb + (xw - xb) * t1, y, zb + 0.5 + (zw + 0.9 - zb - 0.5) * t1))
        mid = (p0 + p1) * 0.5 + Vector((0, 0, 0.1))
        ang = math.atan2(p1.z - p0.z, abs(p1.x - p0.x)) * xs
        M.block(mid, ((p1 - p0).length + 0.04, 0.8, 0.18), roll=-ang, bevel=0.04, tone=0.9)
    box(Pc, "stone", ((xb + xw) * 0.5, y, (zb + zw) * 0.5), (abs(xw - xb), 0.8, 1.8), roll=-math.atan2(zw - zb, abs(xw - xb)) * xs)


# ============================================================================================ the west front
def portal(F, cu, w, spring, orders, porch):
    """A recessed portal: orders of pointed rings stepping back from the porch face to the wall face, a jamb shaft with
    a capital in each re-entrant angle, the door leaves (one fallen), a gablet over it all."""
    ex, ny = F.T, F.N
    half = F_half(F)
    a0 = w * 0.5
    H0 = w * 0.866 * 1.05
    zbase = spring - (F.a.z if False else 0.0)
    base = (a0, a0 * 1.72)
    for i in range(orders + 1):
        ai = a0 + 0.42 * i
        d0 = -half
        d1 = half + porch * (i / orders) if i > 0 else half
        if i > 0:
            org = F.p(cu, spring, 0.0)
            oi = concentric(base, 0.42 * (i - 1))
            ring(org, ex, ny, oi[0], oi[1], 0.42, d0 - 0.02, d1, n=6 + i, tone=0.88 - 0.03 * i)
            # the jambs of this order, coursed up to the springing
            for sd in (1, -1):
                v = 0.0
                j = 0
                while v < spring - 0.05:
                    hh = min(0.5, spring - v)
                    uu = cu + sd * (ai - 0.21)
                    p = F.p(uu, v + hh * 0.5, (d0 + d1) * 0.5)
                    M.block(p, (0.42, d1 - d0 + 0.02, hh - 0.02), yaw=math.atan2(ex.y, ex.x), bevel=0.04, tone=rnd.uniform(0.78, 0.9))
                    v += hh
                    j += 1
                # a shaft and its capital in the angle in front of the order
                if i < orders:
                    sc = F.p(cu + sd * (ai + 0.02), 0.0, d1 + 0.12)
                    r = [(math.cos(math.tau * k / 8) * 0.13, math.sin(math.tau * k / 8) * 0.13) for k in range(8)]
                    loft((sc.x, sc.y), [(sc.z + 0.2, r), (sc.z + spring - 0.5, r)], 0.9, cap_top=False, smooth=True)
                    M.block(F.p(cu + sd * (ai + 0.02), spring - 0.3, d1 + 0.12), (0.42, 0.42, 0.42), yaw=math.atan2(ex.y, ex.x),
                            bevel=0.08, tone=0.9)
    # the porch's flanks and the gablet over the outermost order
    ao = a0 + 0.42 * orders
    for sd in (1, -1):
        u = cu + sd * (ao + 0.35)
        v = 0.0
        while v < spring + 1.0:
            hh = 0.55
            M.block(F.p(u, v + hh * 0.5, half + porch * 0.5), (0.7, porch + 0.02, hh - 0.02), yaw=math.atan2(ex.y, ex.x), bevel=0.05,
                    tone=rnd.uniform(0.76, 0.9))
            v += hh
    gh = (ao + 0.7) * 0.9
    for sd in (1, -1):
        for k in range(5):
            t0, t1 = k / 5, (k + 1) / 5
            p0 = F.p(cu + sd * (ao + 0.7) * (1 - t0), spring + 1.0 + gh * t0, half + porch * 0.5)
            p1 = F.p(cu + sd * (ao + 0.7) * (1 - t1), spring + 1.0 + gh * t1, half + porch * 0.5)
            mid = (p0 + p1) * 0.5
            M.block(mid, ((p1 - p0).length + 0.03, porch + 0.1, 0.34), yaw=math.atan2(ex.y, ex.x), roll=sd * math.atan2(gh, ao + 0.7) * -1.0,
                    bevel=0.04, tone=0.9)
    # the door: one leaf swung back flat against the reveal, the other off its hinges and lying in the water inside;
    # each leaf boards on two ledges, iron straps
    dw = w * 0.5 - 0.05
    dh = spring + w * 0.5 * 0.9
    hinge = F.p(cu + w * 0.5 - 0.06, 0.0, half - 0.1)
    for k in range(int(dw / 0.24)):
        p0 = hinge - ny * (0.12 + k * 0.24) + Vector((0, 0, 0.1))
        beam(P, "timber", p0, p0 + Vector((0, 0, dh - 0.3 - 0.4 * (k / max(1, dw / 0.24)) ** 2)), 0.06, 0.22, up=ex)
    for z in (0.8, dh - 1.1):
        beam(P, "timber", hinge + Vector((0, 0, z)) - ex * 0.08, hinge - ny * dw + Vector((0, 0, z)) - ex * 0.08, 0.08, 0.2)
        beam(P, "iron", hinge + Vector((0, 0, z + 0.25)) + ex * 0.04, hinge - ny * dw * 0.8 + Vector((0, 0, z + 0.25)) + ex * 0.04, 0.03, 0.08)
    base = F.p(cu - w * 0.25, -0.15, -half - 1.4 - dh * 0.5)
    for k in range(int(dw / 0.24)):
        p0 = base + ex * (k * 0.24 - dw * 0.5) - ny * (dh * 0.5)
        beam(P, "timber", p0, p0 + ny * (dh - 0.2) + Vector((0, 0, 0.35)), 0.22, 0.06)


def west_front():
    y = FRONT_Y
    half = 0.8
    rag = ragged(1100, 0.0, 2.6, 0.22)

    def top(u):
        x = u - 12.2
        gable = 26.4 - abs(x) * 0.85
        return min(gable, 25.0 + rag(u) * 0.0 - 2.6 * max(0.0, ML.fbm(Vector((u * 0.18, 4.0, 1.0))) * 1.4 + 0.2))

    def solid(u, v):
        z = v - 1.2
        x = u - 12.2
        if z > top(u):
            return False
        if hole(x, z, 0.0, (2.2, 2.2 * 1.72), 0.42 * 3, -1.2, 5.0):
            return False
        for sx in (-1, 1):
            if hole(x, z, sx * 8.0, (1.3, 1.3 * 1.72), 0.42 * 2, -1.2, 3.6):
                return False
            if hole(x, z, sx * 8.4, (0.8, 1.4), 0.3, 11.6, 15.6):
                return False
        if hole(x, z, 0.0, (3.3, 5.7), 0.45, 10.8, 15.2):
            return False
        return True
    F = wall((-12.2, y), (12.2, y), -1.2, 28.5, half, solid, ends=(0.0, 0.0), dress_ends=True)
    _halves[id(F)] = half
    ex, ny = F.T, F.N
    portal(F, 12.2, 4.4, 5.0 + 1.2, 3, 1.3)
    for sx in (-1, 1):
        portal(F, 12.2 + sx * 8.0, 2.6, 3.6 + 1.2, 2, 0.85)
    # the great window: its rings, three lights and a rose; the lancets either side
    org = F.p(12.2, 15.2 + 1.2, 0.0)
    dress(F, 12.2, (3.3, 5.7), 0.45, 10.8 + 1.2, 15.2 + 1.2, half, n=10, tone=0.88)
    hm = concentric((3.3, 5.7), 0.45)
    ring(org, ex, ny, hm[0], hm[1], 0.18, 0.8, 0.98, n=10, tone=0.9, bevel=0.03)
    tracery(F.p(0.0, 1.2, 0.0), ex, ny, 12.2, 6.6, 10.8, 15.2, 3, broken=0.12)
    M.block(F.p(12.2, 10.7 + 1.2, 0.2), (7.4, 1.9, 0.22), yaw=math.atan2(ex.y, ex.x), bevel=0.05, tone=0.86)
    for sx in (-1, 1):
        dress(F, 12.2 + sx * 8.4, (0.8, 1.4), 0.3, 11.6 + 1.2, 15.6 + 1.2, half, n=5)
        tracery(F.p(0.0, 1.2, 0.0), ex, ny, 12.2 + sx * 8.4, 1.6, 11.6, 15.6, 1, broken=0.0)
    # a string course over the portals and blind arcading on the face between them
    course(F, 0.4, F.L - 0.4, 10.0, 0.36, 0.3, side=1)
    for i in range(-5, 6):
        x = i * 2.0
        if abs(x) < 4.3 or abs(abs(x) - 8.0) < 2.4:
            continue
        org = F.p(12.2 + x, 7.8 + 1.2, half + 0.04)
        ring(org, ex, ny, 0.7, 1.15, 0.14, 0.0, 0.16, n=3, tone=0.9, bevel=0.025)
        for sd in (1, -1):
            loft(tuple(F.p(12.2 + x + sd * 0.77, 0.0, half + 0.1)[:2]), [(5.0 + 1.2 - 1.2, octagon(0.08)), (7.8, octagon(0.08))], 0.88, cap_top=False)
    # the front's corner buttresses (angle pairs) up to the gable foot
    for sx in (-1, 1):
        buttress((sx * 12.2, y + 0.8), (0.0, 1.0), 18.0, pinnacle=False, seed=300 + sx, width=1.6, depth=2.2)
        buttress((sx * (12.2 + 0.6), y - 0.6), (sx, 0.0), 14.0, pinnacle=False, seed=310 + sx, width=1.6, depth=1.6)
    return F


def tower_stump():
    """The north-west tower: four coursed walls on a battered plinth, lancet slots, string courses, angle buttresses,
    a ragged top; putlog holes and the scaffold against its face."""
    cx, cy = -16.4, FRONT_Y - 0.2
    w = 8.2
    hw = w * 0.5
    t = 1.3
    faces = [((cx - hw, cy + hw), (cx + hw, cy + hw)), ((cx + hw, cy + hw), (cx + hw, cy - hw)),
             ((cx + hw, cy - hw), (cx - hw, cy - hw)), ((cx - hw, cy - hw), (cx - hw, cy + hw))]
    for k, (a, b_) in enumerate(faces):
        tp = ragged(1150 + k, 26.5, 3.2, 0.4)

        def solid(u, v, k=k, tp=tp):
            z = v - 1.2
            if z > tp(u):
                return False
            for zz in (7.5, 13.5, 19.5):
                if pointed_hole(u, z, w * 0.5, 0.2, 0.35, zz, zz + 1.6):
                    return False
            if k == 1 and pointed_hole(u, z, w * 0.5, 0.9, 1.6, -1.2, 2.6):
                return False
            return True
        F = wall(a, b_, -1.2, 29.0, t * 0.5, solid, ends=(t * 0.49, t * 0.49), faces=(1,))
        _halves[id(F)] = t * 0.5
        for z in (6.0, 12.0, 18.0):
            course(F, -t * 0.5, F.L + t * 0.5, z + 1.2, 0.3, 0.22, side=1)
    for (sx, sy) in ((-1, 1), (1, 1), (-1, -1)):
        buttress((cx + sx * hw, cy + sy * (hw - 0.8)), (sx, 0.0), 16.0, seed=1160 + sx * 3 + sy, width=1.3, depth=1.4)
    # the scaffold on the west face (Blender -x): standards, ledgers, putlogs into the holes, boards, a ladder
    fx = cx - hw - 1.5
    for dy in (-3.4, 0.0, 3.4):
        cyl(P, "timber", (fx, cy + dy, -1.0), (fx, cy + dy, 22.0), 0.11, 0.09, seg=6)
    for z in (3.0, 8.0, 13.0, 18.0):
        beam(P, "timber", (fx, cy - 3.8, z), (fx, cy + 3.8, z), 0.15)
        for dy in (-2.8, 0.0, 2.8):
            beam(P, "timber", (fx - 0.2, cy + dy, z + 0.12), (cx - hw + 0.4, cy + dy, z + 0.12), 0.13)
        if rnd.random() < 0.8:
            for b_ in range(5):
                box(P, "timber", (fx + 0.75, cy - 3.0 + b_ * 1.5, z + 0.24), (1.4, 0.3, 0.06), yaw=0.0)
    for s in (-1, 1):
        cyl(P, "timber", (fx - 0.8 + s * 0.25, cy + 2.0, -0.6), (fx - 0.1 + s * 0.25, cy + 2.0, 8.6), 0.05, seg=5)
    for k in range(14):
        z = -0.2 + k * 0.62
        f = z / 9.2
        beam(P, "timber", (fx - 0.8 + 0.7 * f - 0.25, cy + 2.0, z), (fx - 0.8 + 0.7 * f + 0.25, cy + 2.0, z), 0.05)
    box(Pc, "stone", (cx, cy, 12.0), (w + 0.6, w + 0.6, 26.0))


def twin_footings():
    """The south-west tower never rose past its footings: a coursed square to 4.8 m, blocks stacked on it ready, and
    the masons' crane still rigged with a block in the sling."""
    cx, cy = 16.4, FRONT_Y - 0.2
    w = 8.2
    hw = w * 0.5
    t = 1.6
    faces = [((cx - hw, cy + hw), (cx + hw, cy + hw)), ((cx + hw, cy + hw), (cx + hw, cy - hw)),
             ((cx + hw, cy - hw), (cx - hw, cy - hw)), ((cx - hw, cy - hw), (cx - hw, cy + hw))]
    for k, (a, b_) in enumerate(faces):
        tp = ragged(1170 + k, 6.0, 1.2, 0.5)
        F = wall(a, b_, -1.2, 7.2, t * 0.5, lambda u, v, tp=tp: v - 1.2 <= tp(u), ends=(t * 0.49, t * 0.49))
    box(P, "stone", (cx, cy, 4.2), (w - 2.6, w - 2.6, 1.0))
    r = random.Random(1180)
    for i in range(10):
        a = r.uniform(0, math.tau)
        rad = r.uniform(0.0, 2.6)
        M.block((cx + math.cos(a) * rad, cy + math.sin(a) * rad, 5.0 + r.uniform(0, 0.4)), (r.uniform(0.9, 1.5), r.uniform(0.6, 0.9), r.uniform(0.5, 0.7)),
                yaw=r.uniform(0, 3), bevel=0.06, rnd=r)
    # the crane: a mast, a jib, braces, a treadwheel's frame, the rope and the block
    mx, my = cx + 0.5, cy + 5.6
    cyl(P, "timber", (mx, my, 0.0), (mx, my, 13.0), 0.3, 0.22, seg=8)
    beam(P, "timber", (mx, my, 12.4), (mx - 7.0, my + 2.5, 11.2), 0.28)
    beam(P, "timber", (mx, my, 12.4), (mx + 3.5, my - 0.6, 10.8), 0.24)
    beam(P, "timber", (mx, my, 7.0), (mx - 4.0, my + 1.4, 11.7), 0.18)
    cyl(P, "iron", (mx - 7.0, my + 2.5, 11.1), (mx - 7.0, my + 2.5, 6.0), 0.025, seg=4)
    M.block((mx - 7.0, my + 2.5, 5.4), (1.0, 0.9, 1.0), bevel=0.06, tone=0.84)
    for sx in (-1, 1):
        for sy in (-1, 1):
            beam(P, "timber", (mx, my, 0.4), (mx + sx * 2.8, my + sy * 2.8, 0.1), 0.24)
            beam(P, "timber", (mx, my, 5.0), (mx + sx * 2.8, my + sy * 2.8, 0.1), 0.16)
    for k in range(16):                                        # the treadwheel's rim
        a0 = math.tau * k / 16
        a1 = math.tau * (k + 1) / 16
        beam(P, "timber", (mx + 2.0, my + math.cos(a0) * 2.2, 2.4 + math.sin(a0) * 2.2), (mx + 2.0, my + math.cos(a1) * 2.2, 2.4 + math.sin(a1) * 2.2), 0.14)
    for k in range(4):
        a0 = math.pi * k / 4
        beam(P, "timber", (mx + 2.0, my + math.cos(a0) * 2.2, 2.4 + math.sin(a0) * 2.2), (mx + 2.0, my - math.cos(a0) * 2.2, 2.4 - math.sin(a0) * 2.2), 0.12)
    cyl(P, "timber", (mx + 0.4, my, 2.4), (mx + 2.6, my, 2.4), 0.12, seg=6)
    box(Pc, "stone", (cx, cy, 2.0), (w + 0.4, w + 0.4, 6.4))


# ============================================================================================ the apse
def apse():
    segs = 6
    cx, cy = APSE_C
    pts = [(cx + APSE_R * math.cos(math.pi * i / segs), cy - APSE_R * math.sin(math.pi * i / segs)) for i in range(segs + 1)]
    for i in range(segs):
        a, b_ = pts[i], pts[i + 1]
        L = math.hypot(b_[0] - a[0], b_[1] - a[1])
        low = i in (0, 1)
        tp = ragged(1300 + i, 6.2 if low else 12.4, 3.2 if low else 1.6, 0.4)

        def solid(u, v, L=L, tp=tp, low=low):
            z = v - 1.2
            if z > tp(u):
                return False
            if hole(u, z, L * 0.5, APS, 0.3, 3.4, 7.6):
                return False
            return True
        F = wall(a, b_, -1.2, 14.0, 0.7, solid, ends=(0.4, 0.4))
        _halves[id(F)] = 0.7
        dress(F, L * 0.5, APS, 0.3, 3.4 + 1.2, 7.6 + 1.2, 0.7, n=5, jambs=True)
        if not low:
            tracery(F.p(0.0, 1.2, 0.0), F.T, F.N, L * 0.5, APS[0] * 2, 3.4, 7.6, 2, broken=0.1)
        M.block(F.p(L * 0.5, 3.4 + 1.2 - 0.06, 0.0), (2.3, 1.6, 0.18), yaw=math.atan2(F.T.y, F.T.x), bevel=0.05, tone=0.84)
    for i in range(1, segs):
        x, y = pts[i]
        a = math.pi * i / segs
        out = (math.cos(a), -math.sin(a))
        buttress((x + out[0] * 0.7, y + out[1] * 0.7), out, 11.6 if i not in (1,) else 6.0, pinnacle=i in (2, 3, 4), seed=1320 + i,
                 width=1.4, depth=2.4)
    # the altar on its dais of three steps, the reredos of blind arches behind it
    ay = ALTAR_Y
    for k, (w, d, hh) in enumerate(((7.4, 5.6, 0.55), (6.2, 4.6, 1.05), (5.0, 3.6, 1.5))):
        n = max(2, int(w / 1.3))
        for i in range(n):
            x0 = -w * 0.5 + w * i / n
            for side in (-1, 1):
                yy = ay + 0.3 + side * (d * 0.5 - 0.25)
                M.block((x0 + w / n * 0.5, yy, hh - 0.2), (w / n - 0.03, 0.5, 0.4), bevel=0.04, tone=0.82)
        box(P, "stone", (0, ay + 0.3, hh * 0.5 - 0.4), (w - 0.1, d - 0.1, hh + 0.4))
        box(Pc, "stone", (0, ay + 0.3, hh * 0.5 - 0.2), (w, d, hh + 0.4))
    M.block((0, ay + 0.2, 2.05), (2.6, 1.1, 1.1), bevel=0.06, tone=0.9)
    M.block((0, ay + 0.2, 2.68), (2.9, 1.3, 0.18), bevel=0.04, tone=0.92)
    for sx in (-0.8, 0.0, 0.8):
        ring(Vector((sx, ay + 0.78, 2.6)), Vector((1, 0, 0)), Vector((0, -1, 0)), 0.31, 0.5, 0.08, 0.0, 0.1, n=3, tone=0.9, bevel=0.02)
    cyl(P, "iron", (-2.2, ay + 1.2, 1.5), (-2.2, ay + 1.2, 3.6), 0.04, seg=5)
    cyl(P, "iron", (2.4, ay + 1.0, 1.5), (3.6, ay - 0.3, 1.6), 0.04, seg=5)
    box(P, "iron", (1.6, ay - 0.6, 1.62), (0.14, 1.9, 0.1), yaw=0.3)
    box(P, "iron", (1.55, ay - 0.35, 1.62), (0.9, 0.14, 0.1), yaw=0.3)


# ============================================================================================ fallen stone, scaffold
def fallen():
    r = random.Random(1400)
    for i in range(48):
        x = r.uniform(-9.0, 9.0)
        y = r.uniform(-24.0, 25.0)
        if abs(abs(x) - PX) < 1.6 and min(abs(y - p) for p in PY) < 1.6:
            continue
        if abs(x) < 3.0 and y < -22.0:
            continue
        k = r.random()
        if k < 0.45:
            s = r.uniform(0.5, 1.2)
            M.block((x, y, -0.2 + s * 0.2), (s * r.uniform(1.0, 1.8), s * r.uniform(0.7, 1.1), s * 0.6), yaw=r.uniform(0, 3),
                    pitch=r.uniform(-0.25, 0.25), roll=r.uniform(-0.25, 0.25), bevel=0.06, warp=0.03, rnd=r)
        elif k < 0.75:
            # a fallen drum on its side
            a = r.uniform(0, math.pi)
            sec = clustered(24)
            c = Vector((x, y, 0.5))
            d = Vector((math.cos(a), math.sin(a), 0.0))
            side = Vector((-d.y, d.x, 0.0))
            ln = r.uniform(0.6, 0.85)
            rings = []
            for (t, kk) in ((-0.5, 0.96), (-0.47, 1.0), (0.47, 1.0), (0.5, 0.96)):
                rings.append([c + d * (ln * t) + side * (px * kk) + Vector((0, 0, py * kk)) for (px, py) in sec])
            for ra, rb in zip(rings[:-1], rings[1:]):
                for j in range(len(sec)):
                    q = [ra[j], ra[(j + 1) % len(sec)], rb[(j + 1) % len(sec)], rb[j]]
                    M.face(M.stone, q, c + d * ((q[0] - c).dot(d)), [M.tone(p, Vector((0, 0, 1)), 0.82, (1.0, 1.0, 0.95)) for p in q])
            for ring_ in (rings[0], rings[-1]):
                M.face(M.stone, list(ring_), c, [M.tone(p, Vector((0, 0, 1)), 0.82, (1.0, 1.0, 0.95)) for p in ring_])
        else:
            M.lump((x, y, -0.1), (r.uniform(0.4, 0.8), r.uniform(0.4, 0.7), r.uniform(0.25, 0.4)), r)
    # a rib's voussoirs lying in a row where it fell across the nave
    for i in range(9):
        a = i / 9.0
        M.block((-3.0 + a * 6.0, -1.0 + r.uniform(-0.8, 0.8), -0.25), (0.5, 1.1, 0.42), yaw=r.uniform(-0.6, 0.6), bevel=0.06, rnd=r)


def scaffold():
    """Abandoned scaffolding against the unfinished arcade bays: standards, putlogs, boards, a ladder."""
    for xs in (-1, 1):
        for k in range(4, 7):
            y = PY[k]
            x = xs * (PX - 1.6)
            cyl(P, "timber", (x, y + 1.4, -1.0), (x, y + 1.4, 13.5), 0.1, 0.08, seg=6)
            cyl(P, "timber", (x, y - 1.4, -1.0), (x, y - 1.4, 13.0), 0.1, 0.08, seg=6)
            for z in (3.0, 7.5, 12.0):
                beam(P, "timber", (x, y - 1.5, z), (x, y + 1.5, z), 0.15)
                for b_ in range(3):
                    box(P, "timber", (x + xs * 0.9, y - 0.9 + b_ * 0.9, z + 0.1), (1.8, 0.28, 0.06))
            beam(P, "timber", (x + xs * 0.7, y + 1.4, 0.0), (x + xs * 0.7, y + 1.4, 12.0), 0.1, 0.4)


# ============================================================================================ far mesh
def far():
    Pf = Parts()
    for xs in (-1, 1):
        box(Pf, "stone", (xs * AISLE_X, 2.0, 4.0), (1.8, 48.0, 10.4))
        box(Pf, "stone", (xs * PX, 12.0, 8.2 + 2.0), (1.6, 21.0, 22.0))
        box(Pf, "stone", (xs * PX, -8.0, 6.4), (1.6, 14.0, 14.0))
        for k in range(6):
            box(Pf, "stone", (xs * (AISLE_X + 1.9), PY[k], 5.0), (2.8, 1.5, 12.0))
    box(Pf, "stone", (0, FRONT_Y, 11.0), (24.4, 2.4, 24.0))
    box(Pf, "stone", (-16.4, FRONT_Y - 0.2, 12.0), (8.6, 8.6, 27.0))
    box(Pf, "stone", (16.4, FRONT_Y - 0.2, 2.4), (8.6, 8.6, 6.4))
    box(Pf, "stone", (0, -26.0, 4.8), (22.0, 12.0, 11.0))
    objs = finish(Pf, "NaveFar")
    return objs


# ============================================================================================
def build():
    global M, P, Pc
    reset()
    M = ML.Mason(1717)
    P = Parts()
    Pc = Parts()
    def piers():
        for xs in (-1, 1):
            for k, y in enumerate(PY):
                top = VAULT if k <= 3 else (13.6 if k == 4 else SPRING + 0.5)
                pier((xs * PX, y), top, xs)
    for fn in (piers, lambda: arcade_side(1), lambda: arcade_side(-1), ribs, lambda: aisle_side(1), lambda: aisle_side(-1),
               west_front, tower_stump, twin_footings, apse, fallen, scaffold):
        n0 = sum(len(f.verts) - 2 for f in M.stone.faces)
        fn()
        print("PART %-12s %7d stone tris" % (getattr(fn, "__name__", "?"), sum(len(f.verts) - 2 for f in M.stone.faces) - n0))
    near = finish(P, "Nave") + M.objects("Nave")
    col = finish(Pc, "NaveCol")
    farm = far()
    for o in farm:
        o.hide_render = True
    for o in col:
        o.hide_render = True
    out = os.path.join(W.MODELS, "reach_e_nave.glb")
    export(near + col + farm, out, "nave")
    preview(near, "nave", [((70, 70, 40), (0, 0, 10), 30), ((-60, -50, 30), (0, -5, 10), 30), ((0, 60, 8), (0, 28, 12), 30),
                           ((3, 18, 3), (-2, -10, 14), 22), ((0, 33, 6), (0, 28.5, 6), 28), ((22, 10, 9), (11, 13, 8), 30),
                           ((-6, 0, 2.5), (-5.2, 4, 7), 26), ((0, 8, 4), (0, 16, 22), 20)])


if __name__ == "__main__":
    build()
