"""The Crossing's walkways (crossing_lib's primitives): a deck profile (flats and flights), the paving, the stepped parapets, the posts,
the lamp-posts, and the arcade under a bay (tiers of pointed arches on piers). All in the game frame.

A bay runs from `o` (a game point at the first pier's centre, y ignored) along the plan direction `d` for L metres to the next pier. Its walk
profile is a list of pieces, ("flat", length) or ("steps", n, tread): the first piece's top is y0 and each step rises `riser`.
"""
import math

from crossing_lib import *      # noqa: F401,F403

RISER_STD = 0.2667
W_DECK = 4.4
RAIL_T = 0.46
RAIL_H = 1.0
SLAB = 0.24


class Prof:
    """A deck profile: pieces with their u range and heights."""

    def __init__(self, y0, pieces, riser=RISER_STD):
        self.y0 = y0
        self.riser = riser
        self.pieces = []            # dicts: kind, u0, u1, y0, y1, n, tread
        u = 0.0
        y = y0
        for p in pieces:
            if p[0] == "flat":
                self.pieces.append({"kind": "flat", "u0": u, "u1": u + p[1], "y0": y, "y1": y, "n": 0, "tread": 0.0})
                u += p[1]
            else:
                n, tr = p[1], p[2]
                self.pieces.append({"kind": "steps", "u0": u, "u1": u + n * tr, "y0": y, "y1": y + n * riser, "n": n, "tread": tr})
                u += n * tr
                y += n * riser
        self.length = u
        self.y1 = y

    def y(self, u):
        for p in self.pieces:
            if u <= p["u1"] + 1e-6:
                if p["kind"] == "flat":
                    return p["y0"]
                i = min(p["n"] - 1, max(0, int((u - p["u0"]) / p["tread"])))
                return p["y0"] + (i + 1) * self.riser
        return self.y1

    def under_min(self):
        return self.y0


def lamp_post(P, rnd, c, d, h=1.9):
    """A taller post with a dished stone cap, the iron basket's seat (the fire's flame is added by the game)."""
    blk(P, "hewn", (c[0], c[1] + h * 0.5, c[2]), (0.62, h, 0.62), d, rnd, bevel=0.05)
    blk(P, "hewn", (c[0], c[1] + h + 0.08, c[2]), (0.8, 0.18, 0.8), d, rnd, bevel=0.04)


def post(P, rnd, c, d, h=1.3):
    blk(P, "hewn", (c[0], c[1] + h * 0.5, c[2]), (0.6, h, 0.6), d, rnd, bevel=0.05)
    blk(P, "hewn", (c[0], c[1] + h + 0.07, c[2]), (0.74, 0.14, 0.74), d, rnd, bevel=0.04)


def deck(P, C, rnd, o, d, prof, under, width=W_DECK, rail=(True, True), posts=True, lamps=(), face=0.34, pave_key="slate", collide=True):
    """The paving, the stair body to `under` (the top of the arcade's spandrel), and the parapets. Returns the lamp positions (game points)."""
    hw = width * 0.5
    lamp_pts = []
    for pc in prof.pieces:
        u0, u1 = pc["u0"], pc["u1"]
        if pc["kind"] == "flat":
            y = pc["y0"]
            for (a, b) in seg_runs(rnd, u0, u1, 1.1, 1.7):
                for half in (-1, 1):
                    blk(P, pave_key, at(o, d, 0.5 * (a + b), y - SLAB * 0.5, half * hw * 0.5), (b - a - 0.03, SLAB, hw - 0.03), d, rnd, bevel=0.03, warp=0.008)
            top = y
            # the body under the flat
            if top - SLAB - under > 0.05:
                for sgn in (-1, 1):
                    for (va, vb) in rows(rnd, under, top - SLAB, 0.5, 0.7):
                        for (a, b) in seg_runs(rnd, u0, u1, 1.0, 1.6):
                            blk(P, "hewn", at(o, d, 0.5 * (a + b), 0.5 * (va + vb), sgn * (hw - face * 0.5)), (b - a - 0.025, vb - va - 0.025, face), d, rnd, bevel=0.035, warp=0.01)
                core(P, at(o, d, 0.5 * (u0 + u1), 0.5 * (under + top - SLAB), 0.0), (u1 - u0, top - SLAB - under, width - 2 * face + 0.02), d)
            if collide:
                C.box(at(o, d, 0.5 * (u0 + u1), y - 0.25, 0.0), (u1 - u0, 0.5, width), d)
        else:
            tr = pc["tread"]
            for i in range(pc["n"]):
                a = u0 + i * tr
                top = pc["y0"] + (i + 1) * prof.riser
                for half in (-1, 1):
                    blk(P, pave_key, at(o, d, a + tr * 0.5, top - SLAB * 0.5, half * hw * 0.5), (tr - 0.03, SLAB, hw - 0.03), d, rnd, bevel=0.03, warp=0.008)
                body_top = top - SLAB
                if body_top - under > 0.05:
                    for sgn in (-1, 1):
                        for (va, vb) in rows(rnd, under, body_top, 0.5, 0.75):
                            blk(P, "hewn", at(o, d, a + tr * 0.5, 0.5 * (va + vb), sgn * (hw - face * 0.5)), (tr - 0.02, vb - va - 0.02, face), d, rnd, bevel=0.03, warp=0.008)
                    core(P, at(o, d, a + tr * 0.5, 0.5 * (under + body_top), 0.0), (tr, body_top - under, width - 2 * face + 0.02), d)
            if collide:
                # the walk's collision: a ramp through the tread middles (the kit's way), half a tread back
                ya = pc["y0"] + prof.riser * 0.5 - prof.riser * 0.5        # first tread's top is y0 + riser; the ramp meets y0 at the flight's foot
                p0 = (u0 - tr * 0.5, pc["y0"] + prof.riser * 0.0)
                p1 = (u0 + (pc["n"] - 0.5) * tr, pc["y1"])
                for half in (-1, 1):
                    q = [at(o, d, p0[0], p0[1], half * hw), at(o, d, p0[0], p0[1], 0.0), at(o, d, p1[0], p1[1], 0.0), at(o, d, p1[0], p1[1], half * hw)]
                    C.quad(*q)
                    # level from the last half tread on to the flight's end (the next piece's floor takes over there)
                    q2 = [at(o, d, p1[0], p1[1], half * hw), at(o, d, p1[0], p1[1], 0.0), at(o, d, u1 + 0.05, p1[1], 0.0), at(o, d, u1 + 0.05, p1[1], half * hw)]
                    C.quad(*q2)
                # what is under the ramp (the pier-less flight) is closed by the stair body: a slab so the ramp never floats
    # parapets and posts
    if rail[0] or rail[1]:
        _rails(P, C, rnd, o, d, prof, hw, rail, posts, lamps, lamp_pts, collide)
    return lamp_pts


def _rails(P, C, rnd, o, d, prof, hw, rail, posts, lamps, lamp_pts, collide):
    for si, sgn in enumerate((-1, 1)):
        if not rail[si]:
            continue
        wo = sgn * (hw - RAIL_T * 0.5)
        for pc in prof.pieces:
            u0, u1 = pc["u0"], pc["u1"]
            if pc["kind"] == "flat":
                y = pc["y0"]
                for (a, b) in seg_runs(rnd, u0 + 0.0, u1, 1.2, 1.7):
                    blk(P, "hewn", at(o, d, 0.5 * (a + b), y + RAIL_H * 0.5, wo), (b - a - 0.03, RAIL_H, RAIL_T), d, rnd, bevel=0.04, warp=0.008)
                blk(P, "hewn", at(o, d, 0.5 * (u0 + u1), y + RAIL_H + 0.06, wo), (u1 - u0 + 0.06, 0.13, RAIL_T + 0.16), d, rnd, bevel=0.03, warp=0.004)
                if collide:
                    C.box(at(o, d, 0.5 * (u0 + u1), y + 0.6, wo), (u1 - u0, 1.2, RAIL_T), d)
            else:
                tr = pc["tread"]
                i = 0
                while i < pc["n"]:
                    k = min(2, pc["n"] - i)
                    a = u0 + i * tr
                    b = a + k * tr
                    ytop = pc["y0"] + (i + 1) * prof.riser          # the first tread of the group
                    blk(P, "hewn", at(o, d, 0.5 * (a + b), ytop + (RAIL_H - 0.3) * 0.5, wo), (b - a - 0.03, RAIL_H + 0.3, RAIL_T), d, rnd, bevel=0.04, warp=0.006)
                    blk(P, "hewn", at(o, d, 0.5 * (a + b), ytop + RAIL_H + 0.06, wo), (b - a + 0.04, 0.13, RAIL_T + 0.16), d, rnd, bevel=0.03, warp=0.004)
                    if collide:
                        C.box(at(o, d, 0.5 * (a + b), ytop + 0.6, wo), (b - a, 1.4, RAIL_T), d)
                    i += k
        # posts at the profile's ends and where a flight begins and ends
        if posts:
            for u in sorted({0.0, prof.length} | {p["u0"] for p in prof.pieces if p["kind"] == "steps"} | {p["u1"] for p in prof.pieces if p["kind"] == "steps"}):
                u = min(max(u, 0.3), prof.length - 0.3)
                y = prof.y(u - 0.05) if u > 0.31 else prof.y0
                pt = at(o, d, u, y, wo)
                if any(abs(u - l[0]) < 0.4 and l[1] == sgn for l in lamps):
                    lamp_post(P, rnd, pt, d)
                    lamp_pts.append((pt[0], pt[1] + 2.05, pt[2]))
                else:
                    post(P, rnd, pt, d)
        for (lu, ls) in lamps:
            if ls == sgn and not any(abs(lu - u) < 0.4 for u in {0.0, prof.length}):
                y = prof.y(lu)
                pt = at(o, d, lu, y, wo)
                lamp_post(P, rnd, pt, d)
                lamp_pts.append((pt[0], pt[1] + 2.05, pt[2]))


def arcade(P, C, rnd, o, d, L, pw, under, foot, width=W_DECK, spring0=LAVA + 1.0, face=0.34, w_open=None, collide=True, tiers=None):
    """The bay's piers and arches from the foot (game y) to `under`: half piers at both ends (pw/2 each, the neighbour's makes the rest), tiers
    of pointed arches (clear opening L - pw) with string courses between. Returns the arches' top (extrados) for the caller's deck."""
    w = w_open or (L - pw)
    half_len = L * 0.5
    H = under - spring0
    n = tiers or max(1, int(round(H / 5.8)))
    U = H / n
    mid = at(o, d, half_len, 0.0, 0.0)
    # the piers below the first springing: both halves, faced on both sides
    if spring0 - foot > 0.1:
        for (ua, ub) in ((0.0, pw * 0.5), (L - pw * 0.5, L)):
            for sgn in (-1, 1):
                for (va, vb) in rows(rnd, foot, spring0, 0.9, 1.1):
                    blk(P, "hewn", at(o, d, 0.5 * (ua + ub), 0.5 * (va + vb), sgn * (width * 0.5 - face * 0.5)), (ub - ua - 0.03, vb - va - 0.03, face), d, rnd, bevel=0.0, warp=0.01)
            core(P, at(o, d, 0.5 * (ua + ub), 0.5 * (foot + spring0), 0.0), (ub - ua, spring0 - foot, width - 2 * face + 0.02), d)
    for j in range(n):
        sj = spring0 + j * U
        v_top = under - sj if j == n - 1 else U
        rise = max(2.4, min(U - 1.5, w * 0.5 * 1.7)) if j < n - 1 else max(2.4, min(v_top - 1.0 - 0.62, w * 0.5 * 1.7))
        oj = (mid[0], sj, mid[2])
        arch_ring(P, rnd, oj, d, w, rise, width)
        spandrel(P, rnd, oj, d, half_len, w, rise, v_top, width, face=face)
        if j < n - 1:
            # the string course between tiers: a moulded band across the faces, a hand proud
            for (a, b) in seg_runs(rnd, 0.0, L, 1.3, 2.0):
                blk(P, "hewn", at(o, d, 0.5 * (a + b), sj + U - 0.16, 0.0), (b - a - 0.03, 0.3, width + 0.16), d, rnd, bevel=0.05, warp=0.008)
    if collide:
        for (ua, ub) in ((0.0, pw * 0.5), (L - pw * 0.5, L)):
            C.box(at(o, d, 0.5 * (ua + ub), 0.5 * (foot + under), 0.0), (ub - ua, under - foot, width), d)
    return under
