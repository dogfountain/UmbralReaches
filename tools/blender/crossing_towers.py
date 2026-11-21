"""The Crossing's towers (crossing_deck's walkways, crossing_lib's stones): the round Pilgrims' Gate (T3) with the Pilgrims' arch, the iron
fire baskets, square towers (the Spindle Gate, the ward landing) and the blind arcades. Game frame throughout.
"""
import math

from crossing_deck import *      # noqa: F401,F403


# ---------------------------------------------------------------------------------------------- fires
def basket(P_iron, P_ember, c, r=0.46, deep=0.5, legs=True, big=False):
    """An iron fire basket seated at game point c (the post cap's top): a flared bowl with a rolled rim, hoops, a coal bed (ember set)."""
    sc = 1.0 if not big else 1.3
    prof = [(0.0, 0.0), (0.16 * sc, 0.0), (0.24 * sc, 0.12 * sc), (r * sc * 0.9, deep * sc * 0.8), (r * sc, deep * sc), (r * sc + 0.05, deep * sc + 0.03), (r * sc - 0.04, deep * sc + 0.03)]
    bm = P_iron.of("iron")
    cb = bl(c)
    lay = bm.verts.layers.float_color.get("vc") or bm.verts.layers.float_color.new("vc")
    rings = []
    seg = 12
    for (rr, z) in prof:
        ring = []
        for s in range(seg):
            a = math.tau * s / seg
            v = bm.verts.new((cb.x + math.cos(a) * rr, cb.y + math.sin(a) * rr, cb.z + z))
            v[lay] = (0.36, 0.33, 0.31, 1.0)
            ring.append(v)
        rings.append(ring)
    for i in range(len(rings) - 1):
        for s in range(seg):
            try:
                bm.faces.new((rings[i][s], rings[i][(s + 1) % seg], rings[i + 1][(s + 1) % seg], rings[i + 1][s]))
            except ValueError:
                pass
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    # coal bed
    be = P_ember.of("ember")
    lay2 = be.verts.layers.float_color.get("vc") or be.verts.layers.float_color.new("vc")
    top = [be.verts.new((cb.x + math.cos(math.tau * s / seg) * r * sc * 0.82, cb.y + math.sin(math.tau * s / seg) * r * sc * 0.82, cb.z + deep * sc * 0.78)) for s in range(seg)]
    apex = be.verts.new((cb.x, cb.y, cb.z + deep * sc * 0.98))
    for v in top + [apex]:
        v[lay2] = (1.0, 0.45, 0.12, 1.0)
    for s in range(seg):
        try:
            be.faces.new((top[s], top[(s + 1) % seg], apex))
        except ValueError:
            pass
    bmesh.ops.recalc_face_normals(be, faces=be.faces)
    # three hoops
    if legs:
        for k in range(3):
            a = math.tau * k / 3.0
            for (z0, z1, rr0, rr1) in ((0.02, deep * sc * 0.55, 0.16 * sc, r * sc * 0.7),):
                pass


def lamp_with_fire(P, Pi, Pe, rnd, c, d, h=1.9, big=False):
    """A post with its fire basket on top; returns the fire's game point (the flame's seat)."""
    lamp_post(P, rnd, c, d, h)
    if SINK[0] is not None:
        SINK[0].box((c[0], c[1] + h * 0.5, c[2]), (0.62, h, 0.62), d)
    top = (c[0], c[1] + h + 0.17, c[2])
    basket(Pi, Pe, top, big=big)
    return (top[0], top[1] + 0.62, top[2])


def beacon(P, Pi, Pe, rnd, c, d):
    """A great fire on a stone pedestal 1.5 m high (the landings' landmark fires)."""
    for k, (w, h) in enumerate(((1.5, 0.4), (1.2, 0.6), (1.35, 0.22))):
        y = c[1] + sum(hh for (_, hh) in ((1.5, 0.4), (1.2, 0.6), (1.35, 0.22))[:k]) + h * 0.5
        blk(P, "hewn", (c[0], y, c[2]), (w, h, w), d, rnd, bevel=0.05)
    top = (c[0], c[1] + 1.22, c[2])
    if SINK[0] is not None:
        SINK[0].box((c[0], c[1] + 0.61, c[2]), (1.4, 1.22, 1.4), d)
    basket(Pi, Pe, top, r=0.5, deep=0.55, big=True)
    return (top[0], top[1] + 1.0, top[2])


# ---------------------------------------------------------------------------------------------- round towers
def polar(c, r, a, y):
    return (c[0] + math.cos(a) * r, y, c[1] + math.sin(a) * r)


def ring_blocks(P, rnd, c, r_in, r_out, y0, y1, n, off=0.0, key="hewn", bevel=0.035, grow=0.0, mul=1.0):
    """A course of n wedge blocks round c between radii, y0..y1 (the game's plan angle a: x = cos, z = sin)."""
    for i in range(n):
        a0 = math.tau * (i + off) / n
        a1 = math.tau * (i + off + 1) / n
        g = 0.012
        a0 += g / max(r_out, 0.5)
        a1 -= g / max(r_out, 0.5)
        pts = [polar(c, r_in, a0, y0), polar(c, r_in, a1, y0), polar(c, r_out + grow, a1, y0), polar(c, r_out + grow, a0, y0),
               polar(c, r_in, a0, y1), polar(c, r_in, a1, y1), polar(c, r_out + grow, a1, y1), polar(c, r_out + grow, a0, y1)]
        # the hexahedron's winding: bottom ccw seen from above in the game's x/z frame, the same order on top
        hexa(P, key, [pts[0], pts[3], pts[2], pts[1], pts[4], pts[7], pts[6], pts[5]], mul * rnd.uniform(0.9, 1.08), bevel=bevel)


def drum(P, C, rnd, c, r, top, foot, opens, halfs, deck=0.55, lamps=(), n_par=None):
    """A round tower: courses of wedge ashlar from `foot` to under the deck, string courses, a corbel table, the paved top, the parapet ring
    open across the walkways that join (`opens` plan angles, `halfs` half widths in radians). Collision: the drum, the top, the parapet."""
    nb = max(14, int(round(math.tau * (r - 0.4) / 1.25)))
    y = foot
    k = 0
    batter = 0.0
    while y < top - deck - 0.05:
        low = y < 4.0
        h = rnd.uniform(0.85, 1.05) if low else rnd.uniform(0.52, 0.66)
        if top - deck - y - h < 0.4:
            h = top - deck - y
        grow = 0.32 * max(0.0, 1.0 - (y - foot) / 4.0) + (0.0 if (y - foot) > 4.0 else 0.0)
        ring_blocks(P, rnd, c, r - 0.9, r, y, y + h - 0.012, nb if not low else max(12, nb * 2 // 3), off=0.5 * (k % 2), grow=grow, bevel=0.0 if low else 0.035)
        y += h
        k += 1
    # core (a polygon prism, dark): the fill behind the facing
    poly = [(c[0] + math.cos(math.tau * i / 24) * (r - 0.85), c[1] + math.sin(math.tau * i / 24) * (r - 0.85)) for i in range(24)]
    _prism(P, "stone", poly, foot, top - deck)
    # string courses: one at the middle, one under the corbels
    for yy in ([foot + (top - foot) * 0.5] if top - foot > 8.0 else []) + [top - deck - 0.55]:
        ring_blocks(P, rnd, c, r - 0.1, r, yy - 0.15, yy + 0.15, nb, off=0.25, grow=0.16, mul=1.04)
    # corbels under the deck's edge
    for i in range(nb):
        a = math.tau * (i + 0.5) / nb
        pt = polar(c, r + 0.12, a, top - deck - 0.2)
        blk(P, "hewn", pt, (0.4, 0.5, 0.5), (-math.sin(a), math.cos(a)), rnd, bevel=0.04, roll=0.0)
    ring_blocks(P, rnd, c, r - 0.1, r + 0.35, top - deck, top - deck + 0.14, nb, off=0.0, grow=0.0, mul=1.06)
    # paving: rings of slate tiles (the inlaid ring)
    rings = [0.0, r * 0.42, r * 0.5, r - 0.45, r + 0.02]
    keys = ["slate", "hewn", "slate", "slate"]
    for ri in range(len(rings) - 1):
        ra, rb = rings[ri], rings[ri + 1]
        n = max(8, int(round(math.tau * (ra + rb) * 0.5 / 1.1)))
        if ri == 0:
            n = 12
        for i in range(n):
            a0 = math.tau * i / n
            a1 = math.tau * (i + 1) / n
            pts = [polar(c, ra, a0, top - 0.22), polar(c, ra, a1, top - 0.22), polar(c, rb, a1, top - 0.22), polar(c, rb, a0, top - 0.22),
                   polar(c, ra, a0, top), polar(c, ra, a1, top), polar(c, rb, a1, top), polar(c, rb, a0, top)]
            if ri == 0:
                pts[0] = pts[1] = pts[2] = pts[3] = None
            hexa_safe(P, keys[ri], pts, rnd.uniform(0.92, 1.06))
    # parapet ring: runs between the openings
    rr = r - RAIL_T * 0.5 - 0.04
    m = n_par or int(round(math.tau * rr / 1.25))
    closed = []
    for i in range(m):
        a = math.tau * (i + 0.5) / m
        closed.append(not any(abs(angdiff(a, opens[j])) < halfs[j] for j in range(len(opens))))
    for i in range(m):
        if not closed[i]:
            continue
        a0 = math.tau * i / m
        a1 = math.tau * (i + 1) / m
        am = (a0 + a1) * 0.5
        pm = polar(c, rr, am, top + RAIL_H * 0.5)
        tang = (-math.sin(am), math.cos(am))
        ln = 2.0 * rr * math.sin((a1 - a0) * 0.5)
        blk(P, "hewn", pm, (ln - 0.02, RAIL_H, RAIL_T), tang, rnd, bevel=0.04, warp=0.006)
        blk(P, "hewn", polar(c, rr, am, top + RAIL_H + 0.06), (ln + 0.05, 0.13, RAIL_T + 0.16), tang, rnd, bevel=0.03, warp=0.004)
        C.box(polar(c, rr, am, top + 0.6), (ln, 1.2, RAIL_T), tang)
        prev_open = not closed[i - 1]
        nxt_open = not closed[(i + 1) % m]
        if prev_open:
            post(P, rnd, polar(c, rr, a0, top), tang)
        if nxt_open:
            post(P, rnd, polar(c, rr, a1, top), tang)
    # collision: the drum (a prism) with its top at the deck
    poly2 = [(c[0] + math.cos(math.tau * i / 20) * (r - 0.12), c[1] + math.sin(math.tau * i / 20) * (r - 0.12)) for i in range(20)]   # a hand inside the face: the Pilgrims' Stair's landing slab starts at r 3.55 and must clear it
    C.prism(poly2, foot, top)


def angdiff(a, b):
    d = (a - b + math.pi) % math.tau - math.pi
    return d


def hexa_safe(P, key, pts, mul=1.0):
    if pts[0] is None:
        # a fan wedge to the centre: a pentagon prism of the outer ring segment
        bm = P.of(key)
        lay = bm.verts.layers.float_color.get("vc") or bm.verts.layers.float_color.new("vc")
        lo = [bm.verts.new(bl(p)) for p in (pts[4], pts[5], pts[6], pts[7])][:0]
        c_top = bl(pts[4])
        v_c = bm.verts.new(c_top)
        v1 = bm.verts.new(bl(pts[5]))
        v2 = bm.verts.new(bl(pts[6]))
        v3 = bm.verts.new(bl(pts[7]))
        try:
            bm.faces.new((v_c, v3, v2, v1))
        except ValueError:
            pass
        bm.normal_update()
        for v in (v_c, v1, v2, v3):
            t = tone(key, v.co, v.normal)
            v[lay] = (t[0] * mul, t[1] * mul, t[2] * mul, 1.0)
        return
    hexa(P, key, pts, mul, bevel=0.0)


def _prism(P, key, poly, y0, y1):
    """A dark polygon prism (plan points game xz)."""
    bm = P.of(key)
    lay = bm.verts.layers.float_color.get("vc") or bm.verts.layers.float_color.new("vc")
    lo = [bm.verts.new(bl((x, y0, z))) for (x, z) in poly]
    hi = [bm.verts.new(bl((x, y1, z))) for (x, z) in poly]
    n = len(poly)
    try:
        bm.faces.new(lo)
        bm.faces.new(hi[::-1])
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((lo[i], lo[j], hi[j], hi[i]))
    except ValueError:
        pass
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.normal_update()
    for v in lo + hi:
        t = tone(key, v.co, v.normal)
        v[lay] = (t[0], t[1], t[2], 1.0)


def pointed_gate(P, rnd, c, d, w, h_jamb, rise, depth, pier=0.8):
    """A freestanding pointed gate: two jamb piers and a ring over them. c = game point at the middle of the opening on the floor, d the plan
    direction across the opening, `depth` the barrel's length. Returns the ring's apex height over c."""
    for sgn in (-1, 1):
        for (va, vb) in rows(rnd, 0.0, h_jamb, 0.5, 0.65):
            blk(P, "hewn", at(c, d, sgn * (w * 0.5 + pier * 0.5), 0.5 * (va + vb), 0.0), (pier - 0.02, vb - va - 0.02, depth), d, rnd, bevel=0.04)
    if SINK[0] is not None:
        for sgn in (-1, 1):
            SINK[0].box(at(c, d, sgn * (w * 0.5 + pier * 0.5), h_jamb * 0.5, 0.0), (pier, h_jamb, depth), d)
    top = arch_ring(P, rnd, (c[0], c[1] + h_jamb, c[2]), d, w, rise, depth, t=0.5, layers=False)
    # a capped finial on each jamb
    for sgn in (-1, 1):
        blk(P, "hewn", at(c, d, sgn * (w * 0.5 + pier * 0.5), h_jamb + 0.12, 0.0), (pier + 0.14, 0.24, depth + 0.14), d, rnd, bevel=0.04)
    return h_jamb + top
