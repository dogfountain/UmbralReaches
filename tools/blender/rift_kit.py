"""THE ASHEN RIFT, from scratch (r39, 21 Nov): the Cinder Way, the one route from the rift's south rim to the summit ward, modelled in place.
Plan and reasons: docs/r39/rift_from_scratch.md. Placed by core/world/realm/rift/crossing.gd.

  tools/blender/run.sh rift_kit.py -- [--preview DIR]

  art/models/rift_way.glb          one mesh per section and set (`<Section>__stone|hewn|iron|ember|basalt|ash`) and a `<Section>-colonly`
                                   body each, in the rift's own game coordinates (chasm on x 0, z south; the game places it at the origin)
  art/models/rift_way_layout.json  what the game reads: lanes, flights, sites, fires, the lavafall sources, named points

The route, low over the lava, then one climb:
  the LIP (the rim terrace at CROSSING_FOOT, 0.6) -> the DESCENT, three flights on a basalt ledge built against the south-west corner
  (39 steps, two landings) -> the FOOT (-12.4; the chapel branch leaves it) -> the CINDER WAY, a causeway on basalt islands across the
  crust plain with two low bridges and the Cinder Isle -> F, the forecourt before the Ward Crag's door -> the WARD STAIR, wound up
  inside the crag: a round shaft cut down through the rock, 114 steps two and a half turns round its wall about an open well, three
  windows out through the south face -> the WARD LANDING on the crag's top (25.2, fixed).
Risers 0.33 m, treads 0.68 m (0.66 m at the shaft stair's middle), 3.6 m between parapets (3.1 m on the shaft stair).
"""
import json
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import rift_lib as R
from rift_lib import bl

OUT = os.path.join(R.MODELS, "rift_way.glb")
LAYOUT_OUT = os.path.join(R.MODELS, "rift_way_layout.json")
L = R.LAVA
BED = -19.5                  # rock feet, sunk under the lava
TREAD = 0.68
HW = 1.8                     # half the clear width (3.6 m between parapets)
PW = 0.6                     # a parapet's strip
PAR_H = 0.95                 # parapet height over the walk
LAYOUT = {"lanes": {}, "flights": [], "sites": [], "fires": [], "sources": [], "points": {}}
RND = random.Random(3907)


# ============================================================================================ flights
class Flight:
    """A straight flight from its low end `a` (x, y, z: the walk height of the landing it leaves, on its centreline at the first riser)
    rising along unit `d` (dx, dz): `groups` of risers separated by mid landings of `mids` metres. Every group's last riser lands on the
    next flat (a mid landing or the landing at the top)."""

    def __init__(self, name, a, d, groups, mids, rise):
        self.name, self.a, self.groups, self.mids = name, a, groups, mids
        ln = math.hypot(d[0], d[1])
        self.d = (d[0] / ln, d[1] / ln)
        self.n = sum(groups)
        self.r = rise / self.n
        self.treads = []                  # (s0, s1, top y)
        self.flats = []                   # (s0, s1, y): mid landings
        s = 0.0
        y = a[1]
        for gi, n in enumerate(groups):
            for k in range(n - 1):
                y += self.r
                self.treads.append((s, s + TREAD, y))
                s += TREAD
            y += self.r                   # the group's last riser lands on a flat
            if gi < len(mids):
                self.flats.append((s, s + mids[gi], y))
                s += mids[gi]
        self.run = s
        self.top = y

    def pt(self, s, off=0.0, y=None):
        """Game point at `s` along, `off` to the left of the ascent (left = d turned a quarter towards -x for d = +z ... a fixed side)."""
        nx, nz = -self.d[1], self.d[0]
        return (self.a[0] + self.d[0] * s + nx * off, self.walk(s) if y is None else y, self.a[2] + self.d[1] * s + nz * off)

    def walk(self, s):
        """The walk height at s (tread tops, mid landings; the landing below before the first riser, the top beyond the run)."""
        if s < 0.0:
            return self.a[1]
        if s >= self.run:
            return self.top
        for s0, s1, y in self.treads + self.flats:
            if s0 <= s < s1:
                return y
        return self.top

    def yaw(self):
        return math.degrees(math.atan2(-self.d[1], self.d[0]))

    def high(self):
        return self.pt(self.run)


def flight_build(M, F, sides=(1, -1), rock=None, rock_out=(1.0, 1.0), wall=()):
    """Steps (2-3 stones across each tread), the mid landings' flags, parapets on `sides` (+1 left, -1 right), the collision (a ramp
    through the tread middles, flats at the ends and the mid landings) and, with `rock`, the support blocks under it (out to the parapet
    strips and `rock_out` beyond on each side). `wall`: sides where the rock rises over the walk instead (blocks to walk + 3.2)."""
    yaw = F.yaw()
    M.keeps += _keeps([F])
    for s0, s1, y in F.treads:
        _across(M, F, s0 - 0.04, s1 + 0.04, y, y - 0.9, "hewn")
    for s0, s1, y in F.flats:
        _flags(M, F, s0, s1, y)
    # parapets: blocks along the edge, each topped at the highest walk it guards
    for side in sides:
        s = -0.2
        while s < F.run + 0.1:
            ln = RND.uniform(1.0, 1.5)
            s1 = min(s + ln, F.run + 0.25)
            top = max(F.walk(s), F.walk(s1 - 0.01)) + PAR_H + RND.uniform(-0.05, 0.06)
            bot = min(F.walk(s), F.walk(s1 - 0.01)) - 0.9
            c = F.pt((s + s1) * 0.5, side * (HW + PW * 0.5))
            M.block("stone", (c[0], (top + bot) * 0.5, c[2]), (s1 - s - 0.06, top - bot, PW), yaw, shade=RND.uniform(0.74, 0.92))
            M.col_box((c[0], top - 0.5, c[2]), (s1 - s, 1.0, PW), yaw)
            s = s1 + RND.uniform(0.0, 0.03)
    # collision: one ramp through the tread middles, from half a tread before the first riser at the landing's height to half a tread
    # onto the top landing, flat across the mid landings: no lip anywhere (nothing waits on the step-up)
    pts = [(-TREAD * 0.5, F.a[1])]
    for s0, s1, y in F.treads:
        pts.append(((s0 + s1) * 0.5, y))
    for s0, s1, y in F.flats:
        pts += [(s0 + TREAD * 0.5, y), (max(s1 - TREAD * 0.5, s0 + TREAD * 0.5 + 0.06), y)]
    pts.append((F.run + TREAD * 0.5, F.top))
    pts.sort()
    # keep the profile monotonic and simple: one slab per straight run (the tread middles of a group lie on one line), flats as their own:
    # every joint inside a run was an edge the capsule could catch on, and it went down the flights off the floor
    prof = [pts[0]]
    for p in pts[1:]:
        if p[0] - prof[-1][0] > 0.05:
            prof.append(p)
    k = 1
    while k < len(prof) - 1:
        (s0, y0), (s1, y1), (s2, y2) = prof[k - 1], prof[k], prof[k + 1]
        if abs((y1 - y0) / (s1 - s0) - (y2 - y1) / (s2 - s1)) < 0.01:
            prof.pop(k)
        else:
            k += 1
    for (sa, ya), (sb, yb) in zip(prof, prof[1:]):
        ln = sb - sa
        if ln < 0.05:
            continue
        pitch = math.degrees(math.atan2(yb - ya, ln))
        mid = F.pt((sa + sb) * 0.5, 0.0, (ya + yb) * 0.5 - 0.2)
        M.col_box(mid, (math.hypot(ln, yb - ya) + 0.02, 0.4, HW * 2.0 + 0.1), yaw, pitch=pitch)
    if rock is not None:
        s = 0.0
        lo_w = HW + PW + rock_out[1]
        hi_w = HW + PW + rock_out[0]
        while s < F.run:
            s1 = min(s + 1.6, F.run)
            y = min(F.walk(s), F.walk(s1 - 0.01)) - 0.5
            c = F.pt((s + s1) * 0.5, (hi_w - lo_w) * 0.5)
            rock.append(((c[0], (y + BED) * 0.5, c[2]), _half(F, s1 - s + 0.4, y - BED, hi_w + lo_w), _yaw_b(F)))
            for side in wall:
                cw = F.pt((s + s1) * 0.5, side * (HW + 1.4))
                rock.append(((cw[0], (y + 4.2 + BED) * 0.5, cw[2]), _half(F, s1 - s + 0.4, y + 4.2 - BED, 2.2), _yaw_b(F)))
            s = s1


def _half(F, along, up, across):
    """Half sizes (game x across?, up, game z) of a block lying along the flight: for rift_lib.blocks_obj, which takes (x, y, z) halves and
    a yaw about up: we give (along/2, up/2, across/2) and the flight's yaw."""
    return (along * 0.5, up * 0.5, across * 0.5)


def _yaw_b(F):
    return F.yaw()


def _across(M, F, s0, s1, top, bot, key):
    """One tread as two or three stones across, from `bot` to `top`."""
    w = HW * 2.0 + 0.12
    n = RND.choice((2, 3, 3))
    cuts = sorted(RND.uniform(0.25, 0.75) * w for _ in range(n - 1))
    edges = [0.0] + cuts + [w]
    for e0, e1 in zip(edges, edges[1:]):
        off = -w * 0.5 + (e0 + e1) * 0.5
        c = F.pt((s0 + s1) * 0.5, off, (top + bot) * 0.5)
        M.block(key, c, (s1 - s0, top - bot, e1 - e0 - 0.03), F.yaw(), bevel=0.06, shade=RND.uniform(0.82, 1.0))


def _flags(M, F, s0, s1, y):
    s = s0
    while s < s1 - 0.05:
        ln = min(RND.uniform(0.9, 1.4), s1 - s)
        _across(M, F, s, s + ln, y, y - 0.35, "hewn")
        s += ln


# ============================================================================================ flats (landings, decks, the Lip)
def paving(M, x0, z0, x1, z1, y, key="hewn", depth=0.35):
    """Flagstones over a rectangle, top at y."""
    z = z0
    while z < z1 - 0.05:
        dz = min(RND.uniform(1.0, 1.6), z1 - z)
        x = x0
        while x < x1 - 0.05:
            dx = min(RND.uniform(1.0, 1.8), x1 - x)
            M.block(key, ((x + x + dx) * 0.5, y - depth * 0.5, (z + z + dz) * 0.5), (dx - 0.03, depth, dz - 0.03), RND.uniform(-1.2, 1.2), bevel=0.05, warp=0.015,
                    shade=RND.uniform(0.8, 1.0))
            x += dx
        z += dz
    M.col_box(((x0 + x1) * 0.5, y - 0.2, (z0 + z1) * 0.5), (x1 - x0, 0.4, z1 - z0))
    M.keeps.append(((x0 - PW, y - depth - 0.1, z0 - PW), (x1 + PW, y + 3.2, z1 + PW)))


def wall_run(M, a, b, y, gaps=(), h=PAR_H, key="stone"):
    """A parapet from game point a to b (xz) on a walk at y (a number, or a function of the fraction along), leaving `gaps` [(t0, t1)]."""
    ax, az = a
    bx, bz = b
    ln = math.hypot(bx - ax, bz - az)
    if ln < 0.2:
        return
    yaw = math.degrees(math.atan2(-(bz - az), bx - ax))
    t = 0.0
    while t < ln - 0.1:
        seg = min(RND.uniform(1.0, 1.5), ln - t)
        f0, f1 = t / ln, (t + seg) / ln
        if any(g0 < f1 and f0 < g1 for g0, g1 in gaps):
            t += seg
            continue
        fm = (f0 + f1) * 0.5
        wy = y(fm) if callable(y) else y
        top = wy + h + RND.uniform(-0.05, 0.06)
        c = (ax + (bx - ax) * fm, (top + wy - 0.9) * 0.5, az + (bz - az) * fm)
        M.block(key, c, (seg - 0.06, top - wy + 0.9, PW), yaw, shade=RND.uniform(0.74, 0.92))
        M.col_box((c[0], top - 0.5, c[2]), (seg, 1.0, PW), yaw)
        t += seg + RND.uniform(0.0, 0.03)


def fire(M, name, p, big=False, lit=True, tag=""):
    """A fire basket on a squat stone plinth at game point p (on the walk): stone, an iron basket of bars and hoops, coals; recorded for the
    game's flames and lights."""
    x, y, z = p
    k = 1.0 if big else 0.8
    M.block("stone", (x, y + 0.45 * k, z), (0.95 * k, 0.9 * k, 0.95 * k), RND.uniform(0, 90), bevel=0.08)
    M.block("stone", (x, y + 0.97 * k, z), (1.15 * k, 0.14, 1.15 * k), RND.uniform(0, 90), bevel=0.04)
    top = y + 1.04 * k
    for i in range(6):                                   # bars, splayed outward
        a = i / 6.0 * math.tau
        r0, r1 = 0.3 * k, 0.5 * k
        c = (x + math.cos(a) * (r0 + r1) * 0.5, top + 0.28 * k, z + math.sin(a) * (r0 + r1) * 0.5)
        M.block("iron", c, (0.07, 0.6 * k, 0.07), math.degrees(-a), roll=0.0, pitch=0.0, bevel=0.0, warp=0.0, shade=0.45)
    for h, r in ((0.06, 0.3), (0.5, 0.5)):               # hoops (eight short bars round)
        for i in range(8):
            a = (i + 0.5) / 8.0 * math.tau
            c = (x + math.cos(a) * r * k, top + h * k, z + math.sin(a) * r * k)
            M.block("iron", c, (2.0 * math.pi * r * k / 8.0 + 0.03, 0.06, 0.06), math.degrees(-a) - 90.0, bevel=0.0, warp=0.0, shade=0.45)
    M.block("ember", (x, top + 0.14 * k, z), (0.56 * k, 0.2, 0.56 * k), RND.uniform(0, 90), bevel=0.06, warp=0.04, shade=1.0)
    LAYOUT["fires"].append({"p": [round(x, 3), round(top + 0.45 * k, 3), round(z, 3)], "big": big, "lit": lit, "tag": tag or name})


# ============================================================================================ the plan
LIP = (-6.5, -3.2, 5.5, -10.2)          # x0, z0 (south), x1, z1 (north) of the Lip's walk
LIP_Y = 0.6
R_D = 13.0 / 39.0
D1 = Flight("rift_d1", (-6.5 - 13 * TREAD, LIP_Y - 14 * R_D, -8.4), (1.0, 0.0), [14], [], 14 * R_D)       # low end at L1, rising east to the Lip
L1 = (-21.0, -6.6, D1.a[0], -12.4)       # x0, z0, x1, z1 (walk) at D1.a[1]
D2 = Flight("rift_d2", (-18.6, D1.a[1] - 14 * R_D, -12.4 - 13 * TREAD), (0.0, 1.0), [14], [], 14 * R_D)      # low end at L2, rising south to L1
L2 = (-21.2, D2.a[2], -16.8, D2.a[2] - 2.0 * HW)
D3 = Flight("rift_d3", (-16.8 + 10 * TREAD, D2.a[1] - 11 * R_D, D2.a[2] - HW), (-1.0, 0.0), [11], [], 11 * R_D)    # low end at the Foot, rising west to L2
FOOT_Y = D3.a[1]                          # -12.4
FOOT = (D3.a[0], -20.6, -3.0, -28.0)      # x0 (west, D3's foot), z0, x1, z1
WAY_Y = FOOT_Y
I1 = (4.0, -28.6)                         # isle centres (xz)
I2 = (9.6, -37.2)                         # the Cinder Isle
F0 = (3.6, -44.6, 9.6, -48.3)             # the foot of the climb before the crag's door (x0, z0 south, x1, z1 north: the crag's face)
FACE_Z = F0[3]
WARD_Y = 25.2
## THE WARD STAIR, inside the Ward Crag (Luke, 21 Nov: "why are there stairs going back and forth so high"): a door in the crag's south
## face, a round shaft cut down through the rock, and a stair wound up its wall two and a half turns round an open well, lit through
## three windows in the face; out at the top onto the ward landing. Outside the crag shows a door, three lit windows and the well-head.
SH = (6.0, -57.7)                         # the shaft's axis (xz)
SH_R = 6.55                               # its wall
SH_RI = 3.45                              # the walk's inner edge (the inner parapet stands inside it, the open well inside that)
SH_RC = (SH_RI + SH_R) * 0.5              # the walk's middle (5.0: treads 0.66 m there)
SH_N = 114                                # risers, the shaft's floor to the ward landing
SH_RISE = (WARD_Y - WAY_Y) / SH_N
SH_A0 = 0.4                               # the first riser, this far round from due south (the door): the stair climbs by the east,
SH_A1 = 5.0 * math.pi - 0.35              # north and west; the last riser, and the top flat runs on through due north (2.5 turns up)
SH_DA = (SH_A1 - SH_A0) / (SH_N - 1)
SH_TOP = 5.0 * math.pi + 0.6              # the top flat's end, walled across (past it the well drops to the turn below)
DOOR_H = 4.6
## The windows (angle round the shaft): low to the door's west and east, and high over it; every one a lit fire in its embrasure.
WINDOWS = [2.0 * math.pi - 0.55, 2.0 * math.pi + 0.55, 4.0 * math.pi]
WARD = (-4.0, -64.6, 9.6, -71.15)         # the ward landing (x0, z0 south, x1, z1 north): the stair's top flat meets its south edge
## Kept clear of the crag's rough foot: the west Watcher's plinth (rift/threshold.gd WATCHERS) and the Pilgrims' Chapel (rift/chapel.gd).
WATCHERS_AVOID = [(-2.0, -43.2, 6.8), (-17.0, -38.0, 4.5)]


def sh_p(a, r, y):
    """Game point at angle a round the shaft (0 due south, then east, north, west, on round), radius r, height y."""
    return (SH[0] + r * math.sin(a), y, SH[1] + r * math.cos(a))


def sh_yaw(a):
    """M.block's yaw (deg) for a block lying along the radius at angle a."""
    return math.degrees(math.atan2(-math.cos(a), math.sin(a)))


def sh_walk(a):
    """The tread height at angle a (the floor before the first riser, the ward landing's height past the last)."""
    if a < SH_A0:
        return WAY_Y
    if a >= SH_A1:
        return WARD_Y
    return WAY_Y + (int((a - SH_A0) / SH_DA) + 1) * SH_RISE


def sh_ramp(a):
    """The collision's height at angle a: one helical ramp through the tread middles (no lip anywhere)."""
    return max(WAY_Y, min(WARD_Y, WAY_Y + ((a - SH_A0) / SH_DA + 0.5) * SH_RISE))


def report():
    for F in (D1, D2, D3):
        lo, hi = F.pt(0), F.high()
        print("FLIGHT %s: %d risers of %.3f, run %.2f, from (%.2f, %.2f, %.2f) to (%.2f, %.2f, %.2f)" % (F.name, F.n, F.r, F.run, lo[0], lo[1], lo[2], hi[0], hi[1], hi[2]))
        LAYOUT["flights"].append({"name": F.name, "a": [round(v, 3) for v in lo], "b": [round(v, 3) for v in hi], "hw": HW})
    print("SHAFT stair: %d risers of %.3f, treads %.3f m at the middle (%.3f rad), %.2f turns, windows at %s" % (
        SH_N, SH_RISE, SH_RC * SH_DA, SH_DA, (SH_A1 - SH_A0) / math.tau, ", ".join("%.2f" % sh_walk(a) for a in WINDOWS)))


def site(name, rect, y, hard=False):
    x0, z0, x1, z1 = rect
    LAYOUT["sites"].append({"name": name, "rect": [round(min(x0, x1), 2), round(min(z0, z1), 2), round(abs(x1 - x0), 2), round(abs(z1 - z0), 2)], "y": round(y, 3), "hard": hard})


# ============================================================================================ sections
def sec_descent(objs):
    """The Lip on the rim, the three flights down the basalt ledge against the south-west corner, L1, L2, the Foot."""
    M = R.Mas(4201)
    rock = []
    # the Lip: flags on the rock, a balustrade along the north and east edges (the view), steps down to the rim road at the south
    x0, z0, x1, z1 = LIP
    paving(M, x0, z1, x1, z0, LIP_Y)
    wall_run(M, (x0, z1 - PW * 0.5), (x1 + PW * 0.5, z1 - PW * 0.5), LIP_Y)                       # north: the view
    wall_run(M, (x1 + PW * 0.5, z1 - PW * 0.5), (x1 + PW * 0.5, z0 + 0.6), LIP_Y)
    for k in range(2):                                                                              # down to the rim road's end (y 0.0 at z -1.5)
        yk = LIP_Y - (k + 1) * 0.2
        M.block("hewn", (-0.5, yk - 0.4, z0 + 0.43 + k * 0.86), (5.0, 0.8, 0.9), 0.0, bevel=0.05)
    M.col_box((-0.5, 0.1, z0 + 0.86), (2.66, 0.4, 5.0), 90.0, pitch=13.1)                            # one ramp under them (rising north): no lip

    M.keeps.append(((-3.8, -1.2, z0 - 0.4), (2.8, LIP_Y + 3.2, z0 + 2.4)))                          # the steps and the road's end: no rock grows over them
    rock.append((((x0 + x1) * 0.5, (LIP_Y - 0.35 + BED) * 0.5, (z1 - PW - 0.6 + z0 - 0.2) * 0.5), ((x1 - x0) * 0.5 + 1.2, (LIP_Y - 0.35 - BED) * 0.5, (z0 - 0.2 - z1 + PW + 0.6) * 0.5), 0.0))
    fire(M, "lip_w", (x0 + 1.0, LIP_Y, z1 + 1.0), tag="the Lip")
    fire(M, "lip_e", (x1 - 1.0, LIP_Y, z1 + 1.0), lit=False, tag="the Lip")
    site("rift_lip", (x0, z0, x1, z1), LIP_Y)
    LAYOUT["points"]["lip"] = [0.0, LIP_Y, -7.0]
    # D1 (west, the rim slope rising south of it), L1, D2 (north, the west wall), L2, D3 (east, a spur of rock into the plain)
    flight_build(M, D1, sides=(-1,), rock=rock, rock_out=(0.4, 0.8), wall=(1,))
    lx0, lz0, lx1, lz1 = L1
    paving(M, lx0, lz1, lx1, lz0, D1.a[1])
    wall_run(M, (lx1, lz1 - PW * 0.5), (D2.a[0] + HW + PW, lz1 - PW * 0.5), D1.a[1])               # the north edge east of D2's head
    rock.append((((lx0 + lx1) * 0.5, (D1.a[1] - 0.35 + BED) * 0.5, (lz0 + lz1) * 0.5 - 0.3), ((lx1 - lx0) * 0.5 + 0.4, (D1.a[1] - 0.35 - BED) * 0.5, (lz0 - lz1) * 0.5 + 0.9), 0.0))
    rock.append(((lx0 - 2.3, (D1.a[1] + 3.6 + BED) * 0.5, (lz0 + lz1) * 0.5 + 1.0), (2.2, (D1.a[1] + 3.6 - BED) * 0.5, (lz0 - lz1) * 0.5 + 2.0), 0.0))   # the corner rock behind
    fire(M, "l1", (lx0 + 1.0, D1.a[1], lz0 - 1.2), tag="the first landing")
    site("rift_l1", L1, D1.a[1])
    flight_build(M, D2, sides=(-1,), rock=rock, rock_out=(0.4, 0.4), wall=(1,))
    lx0, lz0, lx1, lz1 = L2
    paving(M, lx0, lz1, lx1, lz0, D2.a[1])
    wall_run(M, (lx0, lz1 - PW * 0.5), (D3.high()[0], lz1 - PW * 0.5), D2.a[1])                    # its north edge (the plain below)
    rock.append((((lx0 + lx1) * 0.5, (D2.a[1] - 0.35 + BED) * 0.5, (lz0 + lz1) * 0.5), ((lx1 - lx0) * 0.5 + 0.5, (D2.a[1] - 0.35 - BED) * 0.5, (lz0 - lz1) * 0.5 + 0.7), 0.0))
    rock.append(((lx0 - 2.4, (D2.a[1] + 3.8 + BED) * 0.5, (lz0 + lz1) * 0.5), (2.3, (D2.a[1] + 3.8 - BED) * 0.5, (lz0 - lz1) * 0.5 + 1.6), 0.0))
    fire(M, "l2", (lx0 + 0.9, D2.a[1], lz0 - 0.9), lit=False, tag="the second landing")
    site("rift_l2", L2, D2.a[1])
    flight_build(M, D3, sides=(1, -1), rock=rock, rock_out=(0.5, 0.5))
    # the Foot: a shelf of basalt with flags, the fork (east: the Cinder Way; north: the chapel)
    fx0, fz0, fx1, fz1 = FOOT
    paving(M, fx0, fz1, fx1, fz0, FOOT_Y)
    wall_run(M, (fx0, fz0 + PW * 0.5), (fx1, fz0 + PW * 0.5), FOOT_Y)                                # south edge (the plain to the Lip)
    wall_run(M, (fx1 + PW * 0.5, fz0), (fx1 + PW * 0.5, fz1), FOOT_Y, gaps=[(0.24, 0.8)])           # east: the Cinder Way leaves through the gap
    wall_run(M, (fx0, fz1 - PW * 0.5), (fx1, fz1 - PW * 0.5), FOOT_Y, gaps=[(0.22, 0.82)])          # north: the chapel branch leaves
    wall_run(M, (fx0 - PW * 0.5, D3.a[2] - HW - PW), (fx0 - PW * 0.5, fz1), FOOT_Y)                  # west, north of D3
    rock.append((((fx0 + fx1) * 0.5, (FOOT_Y - 0.35 + BED) * 0.5, (fz0 + fz1) * 0.5), ((fx1 - fx0) * 0.5 + 0.9, (FOOT_Y - 0.35 - BED) * 0.5, (fz0 - fz1) * 0.5 + 0.9), 12.0))
    fire(M, "foot", (fx1 - 1.0, FOOT_Y, fz0 - 1.0), tag="the Foot")
    site("rift_foot", FOOT, FOOT_Y)
    LAYOUT["points"]["foot"] = [round((fx0 + fx1) * 0.5, 2), FOOT_Y, round((fz0 + fz1) * 0.5, 2)]
    # the chapel branch: a low causeway north-west along the wall's foot to the chapel's forecourt (its threshold at -11.97)
    # (it meets the forecourt on its east side, where the old quay did: the forecourt's south end is walled)
    br = [((-6.4, fz1 + 0.2)), (-8.4, -32.6), (-9.9, -37.4), (-11.5, -40.0)]
    _causeway(M, rock, br, FOOT_Y, -12.05, sides=(1, -1), name="branch")                            # rising to (just under) the chapel's forecourt
    LAYOUT["lanes"]["rift_crossing_chapel"] = [[round(p[0], 2), round(p[1], 2)] for p in [((fx0 + fx1) * 0.5, (fz0 + fz1) * 0.5)] + br + [(-13.1, -40.0), (-13.1, -36.85)]]
    fire(M, "branch", (-10.6, FOOT_Y + 0.2, -30.4), lit=False, tag="the chapel's lamp")
    # the ledge: the rock under it all, fused, roughened away from the walks
    n = massing(rock, M.keeps, 401, 10, (-15.0, 6.0), (-10.8, -13.5), (L + 1.0, -2.0), w=(1.2, 2.6))           # under the Lip and D1: ribs to the lava
    n += massing(rock, M.keeps, 402, 10, (-25.0, -21.5), (-4.0, -27.0), (-3.0, 2.0), w=(1.2, 2.4))             # the west wall's face behind
    n += massing(rock, M.keeps, 403, 8, (-17.0, -9.5), (-18.0, -20.6), (L + 0.6, -10.0), w=(1.0, 2.2))         # D3's spur, south side
    n += massing(rock, M.keeps, 404, 6, (-17.0, -9.5), (-25.6, -28.5), (L + 0.6, -10.0), w=(1.0, 2.2))         # D3's spur, north side
    print("DESCENT massing blocks", n)
    ob = R.rock_mass("Descent", rock, voxel=0.42, keep=M.keeps, seed=11, tris=18000, calm=_waterline)
    objs += R.rock_finish(ob, "DescentRock", "basalt", col_ratio=0.3)
    objs += M.finish("Descent")
    objs.append(M.col_finish("Descent"))


def _waterline(p):
    """rock_mass `calm`: at the lava's surface a rock moves no more than 0.45 m (its roughening bulged the masses' feet 2-3 m out
    into the lake, and with the plinths and the isles they covered most of it)."""
    return 0.45 if p[1] < L + 1.5 else None


def _keeps(flights):
    """The walk volumes the rock may not grow into (per flight, in short pieces so a sloped flight's box stays tight)."""
    out = []
    for F in flights:
        s = 0.0
        while s < F.run:
            s1 = min(s + 2.0, F.run)
            p0 = F.pt(s, -HW - PW)
            p1 = F.pt(s1, HW + PW)
            y0 = min(F.walk(s), F.walk(s1 - 0.01)) - 0.5
            y1 = max(F.walk(s), F.walk(s1 - 0.01)) + 3.2
            out.append(((min(p0[0], p1[0]), y0, min(p0[2], p1[2])), (max(p0[0], p1[0]), y1, max(p0[2], p1[2]))))
            s = s1
    return out


def _causeway(M, rock, pts, y0, y1, sides=(1, -1), name="", rock_too=True):
    """A walled causeway along the polyline `pts` (xz), its deck rising evenly from y0 to y1: flags across, parapets, a solid rock base."""
    segs = list(zip(pts, pts[1:]))
    total = sum(math.hypot(b[0] - a[0], b[1] - a[1]) for a, b in segs)
    done = 0.0
    for a, b in segs:
        ln = math.hypot(b[0] - a[0], b[1] - a[1])
        F = Flight(name, (a[0], y0 + (y1 - y0) * done / max(total, 0.01), a[1]), (b[0] - a[0], b[1] - a[1]), [1], [], 0.0)
        F.treads, F.flats, F.run, F.top = [], [(0.0, ln, F.a[1])], ln, F.a[1]
        ya = y0 + (y1 - y0) * done / max(total, 0.01)
        yb = y0 + (y1 - y0) * (done + ln) / max(total, 0.01)
        s = 0.0
        while s < ln - 0.05:
            sl = min(RND.uniform(0.9, 1.4), ln - s)
            yy = ya + (yb - ya) * (s + sl * 0.5) / ln
            _across(M, F, s - 0.02, s + sl + 0.02, yy, yy - 0.4, "hewn")
            s += sl
        for side in sides:
            pa, pb = F.pt(0.0, side * (HW + PW * 0.5)), F.pt(ln, side * (HW + PW * 0.5))
            wall_run(M, (pa[0], pa[2]), (pb[0], pb[2]), lambda f, ya=ya, yb=yb: ya + (yb - ya) * f, h=0.85)
        mid = F.pt(ln * 0.5, 0.0, (ya + yb) * 0.5 - 0.2)
        M.col_box(mid, (ln + 0.3, 0.4, HW * 2.0), F.yaw(), pitch=math.degrees(math.atan2(yb - ya, ln)))
        M.keeps += _keeps([F])
        if rock_too:
            c = F.pt(ln * 0.5)
            rock.append(((c[0], (min(ya, yb) - 0.45 + BED) * 0.5, c[2]), (ln * 0.5 + 0.6, (min(ya, yb) - 0.45 - BED) * 0.5, HW + PW + 0.5), F.yaw()))
        done += ln


def bridge(M, a, b, y, name):
    """A low bridge from a to b (xz): one segmental arch of big voussoirs over the channel, solid spandrels, a deck at y, parapets."""
    ln = math.hypot(b[0] - a[0], b[1] - a[1])
    F = Flight(name, (a[0], y, a[1]), (b[0] - a[0], b[1] - a[1]), [1], [], 0.0)
    F.treads, F.flats, F.run, F.top = [], [(0.0, ln, y)], ln, y
    yaw = F.yaw()
    span = ln - 0.6
    rise = 1.2
    spring = L + 0.4
    rad = (span * span / 4.0 + rise * rise) / (2.0 * rise)
    cy = spring + rise - rad
    n = max(7, int(span / 0.55))
    w = HW * 2.0 + PW * 2.0
    for k in range(n):
        t0, t1 = k / n, (k + 1) / n
        a0 = math.asin(max(-1.0, min(1.0, (t0 - 0.5) * span / rad)))
        a1 = math.asin(max(-1.0, min(1.0, (t1 - 0.5) * span / rad)))
        am = (a0 + a1) * 0.5
        sm = 0.3 + span * 0.5 + math.sin(am) * rad
        ym = cy + math.cos(am) * rad + 0.35
        c = F.pt(sm, 0.0, ym)
        M.block("stone", c, ((a1 - a0) * rad - 0.04, 0.7, w), yaw, pitch=-math.degrees(am), bevel=0.06, shade=RND.uniform(0.7, 0.86))
    # spandrel and deck fill: big blocks from the arch's back up to under the deck
    s = 0.0
    while s < ln - 0.05:
        sl = min(RND.uniform(0.8, 1.2), ln - s)
        sm = s + sl * 0.5 - 0.3 - span * 0.5
        under = cy + math.sqrt(max(rad * rad - sm * sm, 0.0)) + 0.7 if abs(sm) < span * 0.5 else L - 0.5
        top = y - 0.4
        if top - under > 0.1:
            c = F.pt(s + sl * 0.5, 0.0, (top + under) * 0.5)
            M.block("stone", c, (sl - 0.03, top - under, w - 0.1), yaw, shade=RND.uniform(0.74, 0.9))
        _across(M, F, s - 0.02, s + sl + 0.02, y, y - 0.4, "hewn")
        s += sl
    for side in (1, -1):
        pa, pb = F.pt(-0.3, side * (HW + PW * 0.5)), F.pt(ln + 0.3, side * (HW + PW * 0.5))
        wall_run(M, (pa[0], pa[2]), (pb[0], pb[2]), y, h=0.9)
    M.col_box(F.pt(ln * 0.5, 0.0, y - 0.2), (ln + 0.6, 0.4, HW * 2.0), yaw)
    M.keeps += _keeps([F])
    # the abutments (rock-founded piers at each end)
    for s0 in (0.0, ln):
        c = F.pt(s0, 0.0, (y - 0.4 + BED) * 0.5)
        M.block("stone", c, (1.2, y - 0.4 - BED, w), yaw, shade=0.78)
    return ln


def _hits_keep(c, h, keeps, pad=0.6):
    """True when a block (centre, half sizes, game) reaches into a walk volume (its upright box, padded)."""
    r = max(h[0], h[2])
    lo = (c[0] - r - pad, c[1] - h[1], c[2] - r - pad)
    hi = (c[0] + r + pad, c[1] + h[1], c[2] + r + pad)
    for a, b in keeps:
        if lo[0] < b[0] and hi[0] > a[0] and lo[1] < b[1] and hi[1] > a[1] and lo[2] < b[2] and hi[2] > a[2]:
            return True
    return False


def massing(rock, keeps, seed, n, x, z, top, w=(1.2, 3.2), lean=8.0, avoid=()):
    """`n` rough blocks scattered over x (x0, x1), z (z0, z1) with tops in `top` (lo, hi): the buttresses, ribs, spalls and spires that
    break a big face into rock. A block that would reach a walk is lowered under it or dropped; none within `avoid` [(x, z, r)]."""
    rnd = random.Random(seed)
    put = 0
    for i in range(n * 3):
        if put >= n:
            break
        cx, cz = rnd.uniform(*x), rnd.uniform(*z)
        if any(math.hypot(cx - ax, cz - az) < ar + 3.2 for ax, az, ar in avoid):
            continue
        t = rnd.uniform(*top)
        hx, hz = rnd.uniform(*w), rnd.uniform(*w)
        for k in range(4):
            c = (cx, (t + BED) * 0.5, cz)
            h = (hx, (t - BED) * 0.5, hz)
            if not _hits_keep(c, h, keeps):
                rock.append((c, h, rnd.uniform(0, 90), rnd.uniform(-lean, lean), rnd.uniform(-lean, lean)))
                put += 1
                break
            t -= 3.0
            if t < L + 0.5:
                break
    return put


def isle(rock, keep, c, r, top, seed):
    """A natural basalt island (overlapping blocks) with its top at `top` round centre c (xz), half-extent r (x, z)."""
    rnd = random.Random(seed)
    rock.append(((c[0], (top + BED) * 0.5, c[1]), (r[0], (top - BED) * 0.5, r[1]), rnd.uniform(-10, 10)))
    for k in range(5):
        a = rnd.uniform(0, math.tau)
        d = rnd.uniform(0.5, 0.9)
        t = top - rnd.uniform(0.6, 1.8)
        rock.append(((c[0] + math.cos(a) * r[0] * d, (t + BED) * 0.5, c[1] + math.sin(a) * r[1] * d),
                     (r[0] * rnd.uniform(0.35, 0.6), (t - BED) * 0.5, r[1] * rnd.uniform(0.35, 0.6)), rnd.uniform(-40, 40), rnd.uniform(-6, 6), rnd.uniform(-6, 6)))


def sec_way(objs):
    """The Cinder Way: the causeway from the Foot to isle I1, bridge B1, the Cinder Isle (the camp), bridge B2, the climb's foot F."""
    M = R.Mas(4301)
    rock = []
    keep = []
    y = WAY_Y
    # isle I1 and the Cinder Isle: basalt, a flagged way across each, parapets on the open sides
    isle(rock, keep, I1, (3.6, 3.2), y - 0.45, 71)
    isle(rock, keep, I2, (4.8, 4.6), y - 0.45, 72)
    c1 = [(FOOT[2] - 0.2, -24.4), (0.4, -26.6), (I1[0], I1[1])]
    _causeway(M, rock, c1, y, y)
    b1a, b1b = (5.8, -31.2), (8.0, -33.9)
    _causeway(M, rock, [(I1[0], I1[1]), b1a], y, y, rock_too=False)
    bridge(M, b1a, b1b, y, "rift_b1")
    _causeway(M, rock, [b1b, (I2[0], I2[1])], y, y, rock_too=False)
    # the Cinder Isle's square: flags, a fire, the camp
    paving(M, I2[0] - 3.2, I2[1] - 3.4, I2[0] + 3.4, I2[1] + 3.0, y)
    wall_run(M, (I2[0] + 3.4 + PW * 0.5, I2[1] + 3.0), (I2[0] + 3.4 + PW * 0.5, I2[1] - 3.4), y, gaps=[(0.0, 0.0)])
    wall_run(M, (I2[0] - 3.2 - PW * 0.5, I2[1] - 0.6), (I2[0] - 3.2 - PW * 0.5, I2[1] - 3.4), y)
    fire(M, "cinder", (I2[0] + 2.4, y, I2[1] - 2.4), big=True, tag="the Cinder Isle")
    site("rift_cinder", (I2[0] - 3.2, I2[1] + 3.0, I2[0] + 3.4, I2[1] - 3.4), y)
    site("rift_isle", (I1[0] - 2.2, I1[1] + 2.2, I1[0] + 2.2, I1[1] - 2.2), y)
    LAYOUT["points"]["camp"] = [round(I2[0] + 1.0, 2), y, round(I2[1] - 0.6, 2)]
    b2a, b2b = (I2[0] - 0.6, I2[1] - 4.0), (7.6, F0[1] - 0.2)
    _causeway(M, rock, [(I2[0], I2[1]), b2a], y, y, rock_too=False)
    bridge(M, b2a, b2b, y, "rift_b2")
    LAYOUT["lanes"]["rift_crossing"] = [[0.0, -3.2], [0.0, -7.0], [D1.high()[0], -8.4], [D1.pt(0)[0], -8.4], [D2.a[0], -9.6], [D2.high()[0], D2.high()[2]],
                                        [D2.a[0], D2.a[2] - 1.8], [D3.high()[0], D3.a[2]], [D3.a[0], D3.a[2]], [FOOT[2] - 0.2, -24.4], [0.4, -26.6], [I1[0], I1[1]],
                                        list(b1a), list(b1b), [I2[0], I2[1]], list(b2a), list(b2b), [6.6, -46.4]]
    ob = R.rock_mass("Isles", rock, voxel=0.4, keep=M.keeps, seed=21, tris=9000, disp=0.32, calm=_waterline)   # compact: the lake stays open
    objs += R.rock_finish(ob, "WayRock", "ash", col_ratio=0.3)
    objs += M.finish("Way")
    objs.append(M.col_finish("Way"))


def _wedge(M, a0, a1, top, bot_min=None, key="hewn", r0=SH_RI - 0.15, r1=SH_R + 0.35, depth=1.1):
    """One tread of the shaft's stair (or a piece of its top flat) between angles a0 and a1: three stones across, each as wide as the
    wedge at its outer end (so no gap opens at the wall), let 0.35 m into the wall and under the inner parapet."""
    cuts = sorted((RND.uniform(4.2, 4.7), RND.uniform(5.5, 6.0)))
    edges = [r0] + cuts + [r1]
    bot = top - depth
    if bot_min is not None:
        bot = min(bot, bot_min)
    am = (a0 + a1) * 0.5
    for e0, e1 in zip(edges, edges[1:]):
        c = sh_p(am, (e0 + e1) * 0.5, (top + bot) * 0.5)
        M.block(key, c, (e1 - e0 - 0.03, top - bot, e1 * (a1 - a0) + 0.04), sh_yaw(am), bevel=0.06, shade=RND.uniform(0.82, 1.0))


def _helix_col(objs):
    """The stair's collision: one helical ramp through the tread middles (then flat over the top flat), a body per turn (the trail's ray
    sees every turn, not only the topmost one: quest_trail.gd _seat skips a body once it is hit)."""
    import bmesh
    a_s = SH_A0 - SH_DA * 0.5
    a_e = SH_TOP + 0.05
    n = int(math.ceil((a_e - a_s) / (SH_DA * 0.5)))
    radii = [SH_RI - 0.05, SH_RC, SH_R + 0.3]
    turns = {}
    for i in range(n):
        aa, ab = a_s + (a_e - a_s) * i / n, a_s + (a_e - a_s) * (i + 1) / n
        t = int((aa - a_s) / math.tau)
        bm = turns.setdefault(t, bmesh.new())
        for ra, rb in zip(radii, radii[1:]):
            vs = [bm.verts.new(bl(sh_p(a, r, sh_ramp(a)))) for a, r in ((aa, ra), (aa, rb), (ab, rb), (ab, ra))]
            f = bm.faces.new(vs)
            f.normal_update()
            if f.normal.z < 0.0:
                f.normal_flip()
    for t, bm in sorted(turns.items()):
        me = bpy.data.meshes.new("ShaftTurn%d-colonly" % t)
        bm.to_mesh(me)
        bm.free()
        ob = bpy.data.objects.new("ShaftTurn%d-colonly" % t, me)
        bpy.context.scene.collection.objects.link(ob)
        objs.append(ob)


def sec_crag(objs):
    """The Ward Crag and the Ward Stair inside it: the climb's foot F before the door in the south face, the door's passage, the round
    shaft cut down through the rock with its stair wound round the wall (an open well in the middle, a fire at its foot), three windows
    in the face, the well-head and the ward landing on the crag's top; the lavafall's cleft at the south-east corner stays open."""
    M = R.Mas(4401)
    rock = []
    cuts = []
    y = WAY_Y
    # F: the forecourt before the door (the bridge from the Cinder Isle lands on its south edge)
    fx0, fz0, fx1, fz1 = F0
    paving(M, fx0, fz1, fx1, fz0, y)
    wall_run(M, (fx1 + PW * 0.5, fz0), (fx1 + PW * 0.5, fz1 - 0.4), y)                              # east (the fall's pool)
    wall_run(M, (fx0 - PW * 0.5, fz0), (fx0 - PW * 0.5, fz1 - 0.4), y)                              # west (the Watcher's pool)
    wall_run(M, (fx0 - PW, fz0 + PW * 0.5), (5.1, fz0 + PW * 0.5), y)                                # south, west of the bridge
    rock.append((((fx0 + fx1) * 0.5, (y - 0.35 + BED) * 0.5, (fz0 + fz1) * 0.5), ((fx1 - fx0) * 0.5 + 0.7, (y - 0.35 - BED) * 0.5, (fz0 - fz1) * 0.5 + 0.6), 0.0))
    fire(M, "door_e", (fx1 - 0.9, y, fz1 + 0.9), tag="the crag's door")
    fire(M, "door_w", (fx0 + 0.9, y, fz1 + 0.9), lit=False, tag="the crag's door")
    site("rift_f", F0, y)
    LAYOUT["points"]["f"] = [round((fx0 + fx1) * 0.5, 2), y, round((fz0 + fz1) * 0.5, 2)]
    # the door: a passage through the face into the shaft, flagged, framed in dressed stone (jambs and a lintel of big blocks)
    dz_in = SH[1] + SH_R - 0.4
    cuts.append(((SH[0], y - 0.4 + (DOOR_H + 0.4) * 0.5, (FACE_Z + 2.0 + dz_in) * 0.5), (HW, (DOOR_H + 0.4) * 0.5, (FACE_Z + 2.0 - dz_in) * 0.5), 0.0))
    paving(M, SH[0] - HW, dz_in, SH[0] + HW, FACE_Z, y)
    for side in (-1.0, 1.0):
        for k, (h0, h1) in enumerate(((y - 0.2, y + 1.7), (y + 1.7, y + 3.4), (y + 3.4, y + DOOR_H))):
            M.block("hewn", (SH[0] + side * (HW + 0.45), (h0 + h1) * 0.5, FACE_Z - 0.7 + (0.08 if k == 1 else 0.0)), (0.9, h1 - h0 - 0.03, 2.2), 0.0, bevel=0.07)
        M.col_box((SH[0] + side * (HW + 0.45), y + DOOR_H * 0.5, FACE_Z - 0.7), (0.9, DOOR_H, 2.2))
    M.block("hewn", (SH[0], y + DOOR_H + 0.45, FACE_Z - 0.7), (2.0 * HW + 1.8, 0.9, 2.3), 0.0, bevel=0.08)
    M.block("stone", (SH[0], y + DOOR_H + 1.25, FACE_Z - 0.8), (2.0 * HW + 2.4, 0.7, 2.0), 0.0, bevel=0.08, shade=0.8)
    site("rift_door", (SH[0] - HW, FACE_Z, SH[0] + HW, dz_in), y)
    LAYOUT["points"]["door"] = [SH[0], y, round(FACE_Z - 1.2, 2)]
    # the shaft: cut round, floored with flags; a big fire at the foot of the open well (seen from the well-head, 37 m down)
    z = SH[1] - SH_R - 0.2
    while z < SH[1] + SH_R + 0.2:
        dz = RND.uniform(1.0, 1.5)
        x = SH[0] - SH_R - 0.2
        while x < SH[0] + SH_R + 0.2:
            dx = RND.uniform(1.0, 1.6)
            if math.hypot(x + dx * 0.5 - SH[0], z + dz * 0.5 - SH[1]) < SH_R + 0.25:
                M.block("hewn", (x + dx * 0.5, y - 0.175, z + dz * 0.5), (dx - 0.03, 0.35, dz - 0.03), RND.uniform(-1.2, 1.2), bevel=0.05, warp=0.015, shade=RND.uniform(0.8, 1.0))
            x += dx
        z += dz
    M.col_box((SH[0], y - 0.2, SH[1]), (2.0 * SH_R + 0.8, 0.4, 2.0 * SH_R + 0.8))
    M.keeps.append(((SH[0] - SH_R, y - 0.45, SH[1] - SH_R), (SH[0] + SH_R, y + 3.2, SH[1] + SH_R)))
    fire(M, "well", (SH[0], y, SH[1]), big=True, tag="the foot of the well")
    site("rift_shaft", (SH[0] - SH_R, SH[1] + SH_R, SH[0] + SH_R, SH[1] - SH_R), y)
    LAYOUT["points"]["well"] = [SH[0], y, SH[1]]
    # the stair: 113 treads round the wall (the first turn's treads stand on solid masonry down to the floor while the gap under them
    # would be a crawl space), then the top flat
    for k in range(1, SH_N):
        a0 = SH_A0 + (k - 1) * SH_DA
        top = WAY_Y + k * SH_RISE
        _wedge(M, a0, a0 + SH_DA, top, bot_min=(y - 0.3) if top - y < 3.7 else None)
    a = SH_A1
    while a < SH_TOP - 0.02:
        a1 = min(a + 0.22, SH_TOP)
        _wedge(M, a, a1, WARD_Y, depth=1.2)
        a = a1
    # the walk's keeps (the shaft's wall only sinks back from it, and calmly: see `calm` below)
    a = SH_A0 - SH_DA
    while a < SH_TOP:
        a1 = min(a + 0.35, SH_TOP)
        ps = [sh_p(t, r, 0.0) for t in (a, (a + a1) * 0.5, a1) for r in (SH_RI, SH_R)]
        lo, hi = min(sh_ramp(a), sh_ramp(a1)) - 0.5, max(sh_ramp(a), sh_ramp(a1)) + 3.2
        M.keeps.append(((min(p[0] for p in ps), lo, min(p[2] for p in ps)), (max(p[0] for p in ps), hi, max(p[2] for p in ps))))
        a = a1
    # the inner parapet round the open well (a stone to every two treads, its foot on the floor along the first steps), walled across the
    # top flat's end
    a = SH_A0 - 0.01
    while a < SH_TOP - 0.01:
        a1 = min(a + 2.0 * SH_DA, SH_TOP)
        hi = max(sh_walk(a), sh_walk(a1 - 1e-4))
        lo = min(sh_walk(a), sh_walk(a1 - 1e-4))
        top = hi + PAR_H + RND.uniform(-0.05, 0.06)
        bot = (y - 0.3) if lo - y < 3.7 else lo - 1.1
        am = (a + a1) * 0.5
        rm = SH_RI - PW * 0.5
        ln = SH_RI * (a1 - a) + 0.03
        M.block("stone", sh_p(am, rm, (top + bot) * 0.5), (PW, top - bot, ln), sh_yaw(am), shade=RND.uniform(0.74, 0.92))
        M.col_box(sh_p(am, rm, top - 0.8), (PW, 1.6, ln), sh_yaw(am))
        a = a1
    ln = SH_R + 0.35 - (SH_RI - PW)
    c = sh_p(SH_TOP + 0.05, SH_RI - PW + ln * 0.5, WARD_Y + (PAR_H - 1.2) * 0.5)
    M.block("stone", c, (ln, PAR_H + 1.2, PW), sh_yaw(SH_TOP + 0.05), shade=0.82)
    M.col_box((c[0], WARD_Y + PAR_H - 0.8, c[2]), (ln, 1.6, PW), sh_yaw(SH_TOP + 0.05))
    # the windows: an embrasure cut out through the face at each, a sill, jambs and a lintel at the shaft's side, a lit fire in it
    for i, wa in enumerate(WINDOWS):
        wy = sh_walk(wa)
        sill, wtop = wy + 0.9, wy + 4.5
        rc = SH_R + 3.85
        cuts.append((sh_p(wa, rc, (sill + wtop) * 0.5), (4.15, (wtop - sill) * 0.5, 1.3), sh_yaw(wa)))
        ps = [sh_p(wa + s * 1.5 / rr, rr, 0.0) for rr in (SH_R - 0.3, SH_R + 8.0) for s in (-1.0, 1.0)]
        M.keeps.append(((min(p[0] for p in ps), sill - 0.3, min(p[2] for p in ps)), (max(p[0] for p in ps), wtop + 0.3, max(p[2] for p in ps))))
        M.block("hewn", sh_p(wa, SH_R + 0.45, sill - 0.16), (1.2, 0.32, 3.1), sh_yaw(wa), bevel=0.05)
        for s in (-1.0, 1.0):
            M.block("hewn", sh_p(wa + s * 1.65 / SH_R, SH_R + 0.35, (sill + wtop) * 0.5), (1.0, wtop - sill + 0.3, 0.7), sh_yaw(wa), bevel=0.06)
        M.block("hewn", sh_p(wa, SH_R + 0.35, wtop + 0.35), (1.0, 0.7, 4.1), sh_yaw(wa), bevel=0.07)
        fire(M, "window%d" % i, sh_p(wa + 0.55 / (SH_R + 1.7), SH_R + 1.7, sill), tag="a window in the crag")
    # the well-head: a parapet round the shaft's mouth on the crag's top, open to the north where the stair comes out on the landing
    gap = (HW + 0.05) / (SH_R + 0.35)
    a = 0.0
    while a < math.tau - 0.01:
        da = RND.uniform(1.0, 1.4) / (SH_R + 0.35)
        a1 = min(a + da, math.tau)
        am = (a + a1) * 0.5
        if abs(am - math.pi) > gap + da * 0.5:
            c = sh_p(am, SH_R + 0.35, WARD_Y + (PAR_H - 1.0) * 0.5)
            M.block("stone", c, (PW, PAR_H + 1.0 + RND.uniform(-0.05, 0.06), (SH_R + 0.65) * (a1 - a) + 0.02), sh_yaw(am), shade=RND.uniform(0.74, 0.9))
            M.col_box((c[0], WARD_Y + PAR_H - 0.5, c[2]), (PW, 1.0, (SH_R + 0.65) * (a1 - a)), sh_yaw(am))
        a = a1
    # the ward landing on the crag's top: flags, a masonry skirt down the east edge, a parapet along it (the vent's basin below)
    x0, z0, x1, z1 = WARD
    paving(M, x0, z1, x1, z0, WARD_Y, depth=0.6)
    for k in range(4):
        M.block("stone", (x1 - 0.3, WARD_Y - 1.4, z0 - 0.9 - k * 1.65), (0.6, 1.6, 1.6), 0.0, shade=RND.uniform(0.72, 0.86))
    wall_run(M, (x1 + PW * 0.5, z0 - 0.4), (x1 + PW * 0.5, z1 + 0.6), WARD_Y)
    fire(M, "ward_w", (x0 + 0.9, WARD_Y, z0 - 1.2), lit=False, tag="the ward landing")
    fire(M, "ward_beacon", (x1 - 1.0, WARD_Y, z0 - 1.6), big=True, tag="the ward beacon")
    site("rift_ward_landing", WARD, WARD_Y, hard=True)
    LAYOUT["points"]["ward"] = [0.0, WARD_Y, -66.5]
    # the lanes: through the door, round the stair (a point every 0.3 rad at the walk's middle), out across the landing; the landing's
    # lane starts more than the trail's join reach (5 m) from every turn, so no route jumps a turn
    turn = [[6.6, -46.4], [SH[0], FACE_Z - 1.0], [SH[0], SH[1] + SH_R - 1.2], list(sh_p(SH_A0 - 0.35, SH_RC, 0.0)[::2])]
    a = SH_A0
    while a < 5.0 * math.pi:
        turn.append(list(sh_p(a, SH_RC, 0.0)[::2]))
        a += 0.3
    turn += [list(sh_p(5.0 * math.pi, SH_RC, 0.0)[::2]), [SH[0], z0 - 0.6], [4.0, -66.4], [2.0, -67.6]]
    LAYOUT["lanes"]["rift_crossing_turn"] = [[round(p[0], 2), round(p[1], 2)] for p in turn]
    LAYOUT["lanes"]["rift_crossing_top"] = [[2.0, -67.6], [0.0, -69.0], [0.0, -71.0]]
    LAYOUT["stair"] = {"centre": list(SH), "r_in": SH_RI, "r_out": SH_R, "a0": SH_A0, "a1": SH_A1, "top": SH_TOP, "risers": SH_N,
                       "rise": round(SH_RISE, 4), "from": WAY_Y, "to": WARD_Y}
    _helix_col(objs)
    # the rock: the keep round the shaft (its top the crag's top at the well-head and under the landing), the lower west body behind the
    # chapel's pool, the crest behind the landing, the north-east body behind the vent, the west shoulder into the wall
    top = WARD_Y - 0.2
    rock.append(((5.0, (top + BED) * 0.5, -60.0), (10.0, (top - BED) * 0.5, 11.7), 0.0))                               # x -5..15, z -48.3..-71.7
    rock.append(((-14.5, (20.5 + BED) * 0.5, -62.3), (9.6, (20.5 - BED) * 0.5, 11.6), 0.0))                            # x -24..-5, z -50.7..-73.9
    rock.append(((-9.3, (26.6 + BED) * 0.5, -68.7), (4.7, (26.6 - BED) * 0.5, 3.3), 0.0))                              # the crest
    rock.append(((18.3, (23.0 + BED) * 0.5, -69.4), (3.3, (23.0 - BED) * 0.5, 4.8), 0.0))                              # behind the vent
    rock.append(((-25.0, (8.0 + BED) * 0.5, -60.0), (2.4, (8.0 - BED) * 0.5, 12.0), 0.0))                              # the west shoulder
    # the skyline: broken teeth along the keep's south rim (clear of the windows' and the door's line, over the high window's top) and
    # knuckles on the west body, so the crag never reads as a cut block
    trnd = random.Random(507)
    for tx, tz in ((-4.0, -49.6), (-1.6, -50.4), (2.4, -49.2), (9.6, -49.4), (12.6, -50.2), (14.2, -52.6), (14.0, -57.0), (14.4, -61.5),
                   (-4.4, -55.0), (-4.2, -60.5)):
        t = trnd.uniform(26.5, 30.0)
        rock.append(((tx, (t + 22.5) * 0.5, tz), (trnd.uniform(1.0, 1.7), (t - 22.5) * 0.5, trnd.uniform(0.9, 1.5)), trnd.uniform(0, 90),
                     trnd.uniform(-6, 6), trnd.uniform(-6, 6)))
    for k in range(9):
        tx, tz = trnd.uniform(-22.0, -7.0), trnd.uniform(-52.0, -64.0)
        t = trnd.uniform(21.5, 25.5)
        rock.append(((tx, (t + 18.0) * 0.5, tz), (trnd.uniform(1.4, 2.6), (t - 18.0) * 0.5, trnd.uniform(1.2, 2.2)), trnd.uniform(0, 90),
                     trnd.uniform(-8, 8), trnd.uniform(-8, 8)))
    # the lavafall's cleft at the crag's south-east corner stays open (sec_fall builds it): no rough rock in its channel
    M.keeps.append(((FALL_X - 1.9, L - 1.0, -64.5), (FALL_X + 1.9, 21.0, -46.6)))
    fall_avoid = [(FALL_X, -48.5, 3.0), (FALL_X, -53.0, 3.2), (FALL_X, -58.0, 3.2), (FALL_X, -62.5, 3.0)]
    n = massing(rock, M.keeps, 501, 9, (-24.0, 15.0), (-47.4, -50.4), (L + 0.8, L + 5.0), w=(1.2, 2.0),
                avoid=WATCHERS_AVOID + fall_avoid)                                                       # the foot in the pool, close in
    n += massing(rock, M.keeps, 502, 14, (-24.0, 15.0), (-47.8, -51.2), (2.0, 20.0), w=(1.3, 2.4), lean=4.0,
                 avoid=WATCHERS_AVOID + fall_avoid)                                                      # buttresses up the south face
    n += massing(rock, M.keeps, 503, 10, (-27.0, -5.5), (-66.8, -72.5), (26.5, 31.5), w=(1.0, 2.4), lean=5.0)   # the crest's broken spires
    n += massing(rock, M.keeps, 504, 8, (-30.0, -25.0), (-46.0, -72.0), (2.0, 22.0), w=(1.5, 3.0))              # the west shoulder
    n += massing(rock, M.keeps, 505, 12, (-22.0, 20.0), (-71.0, -75.5), (2.0, 21.0), w=(1.5, 3.0))              # the north face
    print("CRAG massing blocks", n)
    CRAG_KEEPS[:] = M.keeps[:-1]
    sh = (SH[0], SH[1])

    def calm(p):                       # the shaft's wall: the steps are let 0.35 m into it, so it moves no more than 0.18 m
        if p[1] > WAY_Y - 1.0 and math.hypot(p[0] - sh[0], p[2] - sh[1]) < SH_R + 0.9:
            return 0.18
        return _waterline(p)
    ob = R.rock_mass("Crag", rock, voxel=0.5, cuts=cuts, cut_cyls=[(sh, SH_R + 0.05, WAY_Y - 0.45, 45.0)], keep=M.keeps, seed=31,
                     tris=46000, disp=0.75, calm=calm)
    objs += R.rock_finish(ob, "CragRock", "basalt", col_ratio=0.25)
    objs += M.finish("Crag")
    objs.append(M.col_finish("Crag"))


# ============================================================================================ the lavafall
FALL_X = 17.5
CRAG_KEEPS = []           # the crag's walk volumes (sec_crag), so the cleft's rock keeps off the climb's foot and the windows
## The source: lava wells up in a basin on the crag's south-east shoulder, runs a short channel to the lip and pours down a chute cut in
## the corner, between two cheeks of basalt, into the pool by the climb's foot. Game points, the vent first; FALL_LIP is the lip's index.
FALL = [(FALL_X, 19.35, -63.4), (FALL_X, 19.25, -60.9), (FALL_X, 18.5, -60.15), (FALL_X, 10.0, -57.5), (FALL_X, 0.0, -54.1),
        (FALL_X, -10.0, -50.5), (FALL_X, -15.95, -48.2)]
FALL_LIP = 1


def _fall_frame(i):
    """Along (down the fall) and the outward normal (south and up) at path point i, game vectors."""
    from mathutils import Vector
    a = Vector(FALL[max(i - 1, 0)])
    b = Vector(FALL[min(i + 1, len(FALL) - 1)])
    d = (b - a).normalized()
    n = Vector((0.0, d.z, -d.y))
    if n.y < 0.0 and n.z < 0.0:
        n = -n
    return d, n.normalized()


def sec_fall(objs):
    """The cleft: a chute of basalt cut down the corner with a cheek either side and a basin at the top, in the "ash" rock that glows in its
    cracks along the fall; and the falling sheet itself (`Fall__fall`, UV x across, UV y metres from the vent: LavaWorks' fall shader)."""
    import bmesh
    from mathutils import Vector
    rock = []
    lines = []
    for i in range(FALL_LIP, len(FALL) - 1):
        a, b = Vector(FALL[i]), Vector(FALL[i + 1])
        ln = (b - a).length
        d = (b - a).normalized()
        n = Vector((0.0, -d.z, d.y)) if d.y < 0.0 else Vector((0.0, d.z, -d.y))
        if n.z < 0.0:
            n = -n
        pitch = math.degrees(math.atan2(a.y - b.y, abs(a.z - b.z)))          # raised at its north (upper) end
        mid = (a + b) * 0.5
        floor = mid - n * (2.0 + 0.14)                                          # the chute's bed, 0.14 m behind the sheet
        rock.append(((floor.x, floor.y, floor.z), (ln * 0.5 + 0.6, 2.0, 1.9), 90.0, pitch, 0.0))
        for side in (-1.0, 1.0):                                                # the cheeks, standing 2.2 m proud of the bed
            ch = mid + Vector((side * 2.55, 0.0, 0.0)) - n * 0.6
            rock.append(((ch.x, ch.y, ch.z), (ln * 0.5 + 0.8, 2.8, 0.75), 90.0, pitch, 0.0))
        lines.append(((a.x, a.y, a.z), (b.x, b.y, b.z), 3.2))
    v0, v1 = Vector(FALL[0]), Vector(FALL[FALL_LIP])
    rock.append(((FALL_X, v1.y - 1.4, (v0.z + v1.z) * 0.5), (2.3, 1.25, 2.0), 0.0))                 # the basin under the channel
    rock.append(((FALL_X, (v1.y + 4.5 + BED) * 0.5, v0.z - 2.2), (2.8, (v1.y + 4.5 - BED) * 0.5, 1.6), 0.0))   # the rock behind the vent
    for side in (-1.0, 1.0):
        rock.append(((FALL_X + side * 2.55, v1.y + 0.6, (v0.z + v1.z) * 0.5), (0.75, 1.4, 2.2), 0.0))
    lines.append(((v0.x, v0.y, v0.z), (v1.x, v1.y, v1.z), 2.6))
    keep = CRAG_KEEPS + [((FALL_X - 1.6, L - 1.0, -64.0), (FALL_X + 1.6, 21.0, -47.0))]      # the sheet's channel, the foot: the rock only sinks back
    ob = R.rock_mass("Cleft", rock, voxel=0.3, keep=keep, seed=41, tris=5000, disp=0.45)
    objs += R.rock_finish(ob, "Cleft", "ash", col_ratio=0.3, ember_lines=lines)
    # the sheet: rows every half metre down the path, 1.6 m wide at the vent, 2.6 at the lip, 3.0 at the foot
    pts = []
    for i in range(len(FALL) - 1):
        a, b = Vector(FALL[i]), Vector(FALL[i + 1])
        k = max(1, int((b - a).length / 0.5))
        for j in range(k):
            pts.append((a + (b - a) * (j / k), i + j / k))
    pts.append((Vector(FALL[-1]), float(len(FALL) - 1)))
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    m = 0.0
    rows = []
    lip_m = 0.0
    for idx, (p, f) in enumerate(pts):
        if idx > 0:
            m += (p - pts[idx - 1][0]).length
        if f <= FALL_LIP + 1e-6:
            lip_m = m
        w = 1.6 + (2.6 - 1.6) * min(f / FALL_LIP, 1.0) if f <= FALL_LIP else 2.6 + 0.4 * (f - FALL_LIP) / (len(FALL) - 1 - FALL_LIP)
        rows.append((bm.verts.new(bl((p.x - w * 0.5, p.y, p.z))), bm.verts.new(bl((p.x + w * 0.5, p.y, p.z))), m))
    for (a0, a1, ma), (b0, b1, mb) in zip(rows, rows[1:]):
        f = bm.faces.new((a0, a1, b1, b0))
        for l, (u, vv) in zip(f.loops, ((0.0, ma), (1.0, ma), (1.0, mb), (0.0, mb))):
            l[uv].uv = (u, 1.0 - vv)                     # (glTF flips V: the game reads UV.y = metres from the vent)
    me = bpy.data.meshes.new("Fall__fall")
    bm.to_mesh(me)
    bm.free()
    me.materials.append(R.make_mat("fall"))
    fo = bpy.data.objects.new("Fall__fall", me)
    bpy.context.scene.collection.objects.link(fo)
    objs.append(fo)
    LAYOUT["lavafall"] = {"vent": list(FALL[0]), "lip": list(FALL[FALL_LIP]), "foot": list(FALL[-1]), "lip_m": round(lip_m, 3), "total_m": round(m, 3)}
    print("FALL sheet %.1f m (lip at %.1f m), %d rows" % (m, lip_m, len(rows)))


# ============================================================================================ main
def build():
    R.reset()
    report()
    objs = []
    sec_descent(objs)
    sec_way(objs)
    sec_crag(objs)
    sec_fall(objs)
    LAYOUT["points"]["crossing_foot"] = [0.0, LIP_Y, -8.0]
    LAYOUT["points"]["summit_ward"] = [0.0, WARD_Y, -70.9]
    R.export_clean(objs, OUT, "rift_way")
    with open(LAYOUT_OUT, "w") as f:
        json.dump(LAYOUT, f, indent=1)
    vis = [o for o in objs if not o.name.endswith("-colonly")]
    views = [((0, 2.5, -2), (-4, 0, -60), 30),                   # from the Lip (game coordinates)
             ((48, 42, -10), (-2, -6, -40), 30),                  # the air, south-east
             ((2, 110, -36), (0, -10, -37), 32),                  # from above
             ((30, 4, -36), (-8, 4, -58), 30),                    # the crag from the east, low
             ((-4, -11, -38), (6, 2, -52), 32),                   # the door and the windows from the pool
             ((-4, 3, -30), (-16, -6, -14), 32),                  # the descent from the plain
             ((6, 60, -57.7), (6, -12, -57.6), 24),               # down the well
             ((6.0, -11.0, -52.2), (6.0, 8.0, -60.5), 14),       # up the well from its foot
             ((10.2, 0.6, -56.0), (2.0, 4.0, -61.0), 14),         # on the stair, first turn (inside)
             ((14, 32, -46), (-2, 22, -66), 32),                  # the well-head and the landing
             ((30, 4, -34), (16, 2, -56), 30),                    # the lavafall's cleft from the south-east
             ((0, 2.5, -2), (12, 4, -56), 45)]                    # the crag from the Lip
    R.review(vis, "rift_way", [(tuple(bl(p)), tuple(bl(t)), lens) for p, t, lens in views])


build()
