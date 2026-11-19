"""The regions' signature props (core/world/realm/wonders/r39/region_dressing.gd), modelled (the map audit's F28: haystack domes,
lamp-post boxes, notice boards, stepped cairns and the rest were OssKit boxes and prisms). The LOOK only: the game keeps the
kit's colliders for the solid ones (OssKit.visual off) and its own lit lanterns, banners, ropes and strands.

  tools/blender/run.sh signature_props.py -- [--only haystack,lamp_post,...] [--preview DIR]

One glb per kind, art/models/props/sig_<kind>.glb, the house style of props_square.py (<part>__<set> meshes, metric UVs, baked
vertex tone; sets timber / iron / stone / ashlar / cloth / thatch / slate), origin at the prop's foot, in the game's frame as
the builder lays it: Blender (x, y, z) = the game's local (x, -z, y) (the builder's `b * Vector3(x, y, z)`).
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mathutils import Vector
from reach_west_lib import *     # noqa: F401,F403
import reach_west_lib as L
import r37_west as W

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ONLY = args[args.index("--only") + 1].split(",") if "--only" in args else []
OUT = os.path.join(MODELS, "props")
SHOTS = []


def G(x, y, z):
    return Vector((x, -z, y))


def post(P, a, b, r0, r1=None, seg=7, key="timber"):
    cyl(P, key, Vector(a), Vector(b), r0, r1 if r1 is not None else r0 * 0.85, seg=seg)


def stones_ring(P, rnd, c, r, z, n, size):
    for q in range(n):
        a = math.tau * q / n + rnd.uniform(-0.1, 0.1)
        L.dbox(P, "ashlar", (c[0] + math.cos(a) * r, c[1] + math.sin(a) * r, z), (size[0], size[1], size[2]), yaw=a + rnd.uniform(-0.3, 0.3),
               bevel=0.04, warp=0.02)


# ------------------------------------------------------------------------------------------------- shape helpers
DARK = {}          # set key -> tone multiplier for the kind being built (a charred post, a turf-and-ash clamp)


def frame_of(d):
    d = d.normalized()
    u = d.cross(Vector((0, 0, 1)) if abs(d.z) < 0.97 else Vector((1, 0, 0))).normalized()
    return u, d.cross(u).normalized()


def shell(P, key, rows, t):
    """A thick sheet: rows (a grid of points, no wrap), an inner face `t` behind it along the grid normal, the four edges
    closed (a manifold, so the normals come out right). A bell's wall, a hull's planks, a shard."""
    bm = P.of(key)
    nr, nc = len(rows), len(rows[0])
    rows = [[Vector(p) for p in r] for r in rows]

    def nrm(i, j):
        a = rows[i][min(j + 1, nc - 1)] - rows[i][max(j - 1, 0)]
        b = rows[min(i + 1, nr - 1)][j] - rows[max(i - 1, 0)][j]
        n = a.cross(b)
        return n.normalized() if n.length > 1e-9 else Vector((0, 0, 1))
    vo = [[bm.verts.new(rows[i][j]) for j in range(nc)] for i in range(nr)]
    vi = [[bm.verts.new(rows[i][j] - nrm(i, j) * t) for j in range(nc)] for i in range(nr)]
    for i in range(nr - 1):
        for j in range(nc - 1):
            bm.faces.new((vo[i][j], vo[i][j + 1], vo[i + 1][j + 1], vo[i + 1][j]))
            bm.faces.new((vi[i][j], vi[i + 1][j], vi[i + 1][j + 1], vi[i][j + 1]))
    for i in range(nr - 1):
        for j in (0, nc - 1):
            bm.faces.new((vo[i][j], vo[i + 1][j], vi[i + 1][j], vi[i][j]))
    for j in range(nc - 1):
        for i in (0, nr - 1):
            bm.faces.new((vo[i][j], vi[i][j], vi[i][j + 1], vo[i][j + 1]))


def fluted(P, key, a, b, r0, r1, flutes=10, drums=3, broken=0.0, rnd=None):
    """A fluted shaft from a to b laid in drums (a groove at each joint); with `broken` the top drum's top is snapped."""
    a, b = Vector(a), Vector(b)
    d = b - a
    Ln = d.length
    u, v = frame_of(d)
    ax = d.normalized()
    n = flutes * 2
    for k in range(drums):
        z0 = Ln * k / drums
        z1 = Ln * (k + 1) / drums - 0.015
        rings = []
        for (z, shrink) in ((z0, 0.95), (z0 + 0.03, 1.0), (z1 - 0.03, 1.0), (z1, 0.95)):
            r = (r0 + (r1 - r0) * z / Ln) * shrink
            ring = []
            for i in range(n):
                ang = math.pi * i / flutes
                rr = r * (1.0 if i % 2 == 0 else 0.9)
                zz = z
                if broken > 0.0 and k == drums - 1 and z >= z1 - 0.001:
                    zz = z - broken * (0.5 + 0.5 * math.sin(ang * 2.0 + 1.3)) * rnd.uniform(0.6, 1.0)
                ring.append(a + ax * zz + (u * math.cos(ang) + v * math.sin(ang)) * rr)
            rings.append(ring)
        ring_loft(P, key, rings)


def bell_rows(a0, a1, n, prof, jag, rnd, xf):
    """The bell's wall over angles a0..a1 (n steps), its profile [(r, z)], each row's ends jittered by `jag` (a broken edge)."""
    rows = []
    for (r, z) in prof:
        j0 = a0 + rnd.uniform(-jag, jag)
        j1 = a1 + rnd.uniform(-jag, jag)
        rows.append([xf(Vector((math.cos(j0 + (j1 - j0) * q / (n - 1)) * r, math.sin(j0 + (j1 - j0) * q / (n - 1)) * r, z))) for q in range(n)])
    return rows


BELL = [(1.26, -0.3), (1.28, -0.05), (1.22, 0.12), (1.06, 0.34), (0.88, 0.62), (0.76, 0.92), (0.7, 1.18), (0.62, 1.38), (0.44, 1.52),
        (0.2, 1.6), (0.04, 1.62)]


# ------------------------------------------------------------------------------------------------- builders
def b_haystack(P, rnd):
    # a stack of hay on a stone stand, thatched cone: layered tiers of straw (thatch set), a rope net and pegs
    rings = []
    for (z, r) in ((0.0, 1.55), (0.35, 1.68), (0.9, 1.62), (1.5, 1.38), (2.0, 1.0), (2.4, 0.55), (2.65, 0.15)):
        ring = []
        for k in range(14):
            a = math.tau * k / 14
            rr = r * (1.0 + rnd.uniform(-0.05, 0.05))
            ring.append(Vector((math.cos(a) * rr, math.sin(a) * rr, z + rnd.uniform(-0.03, 0.03))))
        rings.append(ring)
    ring_loft(P, "thatch", rings)
    # straw skirt flicks at the foot and the net's ropes over it, weighted with stones
    for k in range(8):
        a = math.tau * k / 8 + 0.2
        beam(P, "timber", (math.cos(a) * 1.62, math.sin(a) * 1.62, 0.35), (math.cos(a) * 0.3, math.sin(a) * 0.3, 2.62), 0.025, 0.025)
        L.dbox(P, "ashlar", (math.cos(a) * 1.75, math.sin(a) * 1.75, 0.32), (0.26, 0.22, 0.2), yaw=a, bevel=0.05, warp=0.03)
    post(P, (0, 0, 2.4), (0, 0, 3.0), 0.05, 0.03)


def b_lamp_post(P, rnd, h=3.2):
    # a dressed stone foot, a wrought-iron post with a twisted collar, a scrolled bracket (the lit lantern is the game's)
    L.dbox(P, "ashlar", (0, 0, 0.18), (0.55, 0.55, 0.42), bevel=0.05)
    L.dbox(P, "ashlar", (0, 0, 0.44), (0.42, 0.42, 0.12), bevel=0.03)
    cyl(P, "iron", (0, 0, 0.45), (0, 0, h - 0.05), 0.07, 0.05, seg=8)
    for z in (0.75, h * 0.55):
        cyl(P, "iron", (0, 0, z), (0, 0, z + 0.1), 0.1, 0.1, seg=8)
    cyl(P, "iron", (0, 0, h - 0.05), (0, 0, h + 0.05), 0.12, 0.09, seg=8)
    for s in (-1.0, 1.0):
        beam(P, "iron", (0, 0, h - 0.35), (s * 0.18, 0, h - 0.05), 0.02, 0.02)


def b_signal_pole(P, rnd):
    b_lamp_post(P, rnd, 5.0)
    beam(P, "iron", (-0.6, 0, 4.4), (0.6, 0, 4.4), 0.04, 0.04)


def b_notice_board(P, rnd):
    # two posts, a shingled hood, the board with pinned notices (the kit's chalk quad is replaced by paper)
    for s in (-1.0, 1.0):
        post(P, G(s * 0.7, -0.3, 0.0), G(s * 0.7, 2.05, 0.0), 0.06, 0.05)
    box(P, "timber", G(0.0, 1.5, 0.0), (1.6, 0.06, 1.0))
    box(P, "timber", G(0.0, 1.02, 0.03), (1.66, 0.08, 0.08))
    box(P, "timber", G(0.0, 1.98, 0.03), (1.66, 0.08, 0.08))
    for s in (-1.0, 1.0):
        box(P, "slate", (0.0, -s * 0.2, 2.12), (1.95, 0.5, 0.045), pitch=s * 0.55)
    box(P, "timber", (0.0, 0.0, 2.24), (1.98, 0.08, 0.08))
    for (x, y, w, h) in ((-0.42, 1.55, 0.36, 0.5), (0.05, 1.62, 0.3, 0.4), (0.42, 1.48, 0.32, 0.36), (-0.05, 1.22, 0.42, 0.2)):
        box(P, "cloth", G(x, y, -0.04), (w, 0.012, h), roll=rnd.uniform(-0.08, 0.08))


def b_cairn_stack(P, rnd):
    # a waymark cairn: stones piled in courses, a long one standing on top (the kit's five stepped blocks are its collider)
    for i in range(5):
        r = (1.3 - 0.22 * i) * 0.5
        n = max(4, int(math.tau * r / 0.32))
        z = 0.2 + 0.36 * i
        for q in range(n):
            a = math.tau * q / n + i * 0.7 + rnd.uniform(-0.15, 0.15)
            L.dbox(P, "ashlar", (math.cos(a) * r * 0.75, math.sin(a) * r * 0.65, z), (r * math.tau / n * 1.1, 0.26, 0.3), yaw=a + 1.57,
                   bevel=0.06, warp=0.03)
        L.dbox(P, "ashlar", (0, 0, z), (r * 1.2, r * 1.0, 0.32), yaw=rnd.random(), bevel=0.08, warp=0.04)
    L.dbox(P, "ashlar", (0, 0, 2.15), (0.22, 0.2, 0.6), yaw=0.3, roll=0.08, bevel=0.05, warp=0.03)


def b_grave_mound(P, rnd):
    # a long turf mound over a kerb of stones, a headstone at its head (the kit's glow candle stays the game's)
    rings = []
    for k in range(9):
        t = k / 8.0
        y = -1.4 + t * 2.8
        hh = 0.62 * math.sin(math.pi * min(1.0, max(0.0, 0.08 + t * 0.84))) + 0.05
        ring = []
        for j in range(9):
            u = j / 8.0
            x = -0.8 + u * 1.6
            z = hh * math.sin(math.pi * u) * (1.0 + rnd.uniform(-0.05, 0.05))
            ring.append(Vector((x, y, z)))
        rings.append(ring)
    ring_loft(P, "stone", rings, close_ends=False)
    for j in range(10):
        t = j / 9.0
        for s in (-1.0, 1.0):
            L.dbox(P, "ashlar", (s * 0.86, -1.4 + t * 2.8, 0.08), (0.2, 0.28, 0.18), yaw=rnd.uniform(-0.3, 0.3), bevel=0.04, warp=0.02)
    L.dbox(P, "ashlar", G(0.0, 0.8, -0.95), (0.7, 0.2, 1.45), roll=rnd.uniform(-0.08, 0.08), bevel=0.06, warp=0.02)
    box(P, "iron", G(0.0, 1.1, -1.06), (0.35, 0.01, 0.06))


def b_wreath_stake(P, rnd):
    post(P, (0, 0, -0.2), (0, 0, 2.2), 0.06, 0.05)
    ring = []
    for k in range(12):
        a = math.tau * k / 12
        ring.append((math.cos(a) * 0.38, math.sin(a) * 0.38))
    for k in range(12):
        a0 = math.tau * k / 12
        a1 = math.tau * (k + 1) / 12
        cyl(P, "thatch", (math.cos(a0) * 0.38, math.sin(a0) * 0.38, 1.92), (math.cos(a1) * 0.38, math.sin(a1) * 0.38, 1.92), 0.07, 0.07, seg=5)


def b_reed_fence(P, rnd):
    for i in range(6):
        x = i * 0.6 - 1.5
        post(P, G(x, -0.2, 0.0), G(x + rnd.uniform(-0.03, 0.03), 1.25 + 0.2 * rnd.random(), 0.0), 0.045, 0.04, seg=5)
    for y in (0.5, 1.0):
        beam(P, "timber", G(-1.55, y, 0.0), G(1.55, y, 0.0), 0.05, 0.05)
    for i in range(40):
        x = -1.45 + i * 0.075
        beam(P, "thatch", G(x, -0.05, 0.03), G(x + rnd.uniform(-0.04, 0.04), 1.05 + rnd.uniform(0.0, 0.35), 0.03), 0.03, 0.02)


def b_bark_rack(P, rnd):
    for i in range(4):
        beam(P, "timber", G(-1.2 + 0.8 * i, 0.0, 0.0), G(-1.0 + 0.8 * i, 1.9, 0.5), 0.12, 0.06)
    beam(P, "timber", G(-1.4, 1.7, 0.45), G(1.4, 1.7, 0.45), 0.06, 0.06)
    for i in range(7):
        x = -1.2 + i * 0.38
        box(P, "timber", G(x, 1.05, 0.25), (0.32, 0.03, 1.4), pitch=0.3, yaw=rnd.uniform(-0.1, 0.1))


def b_snare(P, rnd):
    post(P, (0, 0, -0.2), (0, 0, 1.4), 0.04, 0.035, seg=5)
    post(P, G(1.0, -0.1, 0.0), G(1.0, 0.25, 0.0), 0.03, 0.025, seg=5)


def b_wood_stack(P, rnd):
    for i in range(3):
        for j in range(4 - i):
            x = -1.2 + 0.6 * j + 0.3 * i
            y = 0.2 + 0.35 * i
            cyl(P, "timber", G(x, y, -0.5 + rnd.uniform(-0.05, 0.05)), G(x, y, 0.9 + rnd.uniform(-0.05, 0.05)), 0.17, 0.165, seg=8)
    for s in (-1.0, 1.0):
        post(P, G(s * 1.25, -0.2, 0.2), G(s * 1.25, 1.1, 0.2), 0.05, 0.045, seg=5)


def b_pews(P, rnd):
    for i in range(4):
        z = i * 1.0 - 1.5
        box(P, "timber", G(0.0, 0.45, z), (2.6, 0.38, 0.07))
        box(P, "timber", G(0.0, 0.85, z + 0.17), (2.6, 0.05, 0.5))
        for x in (-1.15, 1.15):
            box(P, "timber", G(x, 0.45, z + 0.08), (0.07, 0.6, 0.9))


def b_fallen_arch(P, rnd):
    for i in range(5):
        a3 = math.pi * i / 4.0
        L.dbox(P, "ashlar", G(math.cos(a3) * 1.6, 0.3 + math.sin(a3) * 0.5, (i % 2) * 0.4), (0.9, 1.0, 0.5),
               roll=a3 - math.pi * 0.5, bevel=0.07, warp=0.03)


def b_pipe(P, rnd):
    for k in range(4):
        cyl(P, "ashlar", G(-1.6 + k * 0.8, 0.4 + k * 0.025, 0.0), G(-0.82 + k * 0.8, 0.42 + k * 0.025, 0.0), 0.45, 0.45, seg=12)
    cyl(P, "iron", G(-1.62, 0.4, 0.0), G(-1.5, 0.4, 0.0), 0.5, 0.5, seg=12)


def b_sluice_wheel(P, rnd):
    c = Vector((0, 0, 1.4))
    for k in range(16):
        a = math.tau * k / 16
        p = c + Vector((math.cos(a) * 1.35, 0.0, math.sin(a) * 1.35))
        box(P, "timber", (p.x, 0.0, p.z), (0.1, 0.36, 0.42), roll=math.pi * 0.5 - a)
        q = c + Vector((math.cos(a + math.tau / 16) * 1.35, 0.0, math.sin(a + math.tau / 16) * 1.35))
        for s in (-0.15, 0.15):
            beam(P, "timber", (p.x, s, p.z), (q.x, s, q.z), 0.08, 0.06)
    for k in range(4):
        a = math.pi * k / 4
        beam(P, "timber", c + Vector((math.cos(a) * 1.3, 0, math.sin(a) * 1.3)), c - Vector((math.cos(a) * 1.3, 0, math.sin(a) * 1.3)), 0.08, 0.08)
    cyl(P, "iron", c + Vector((0, -0.25, 0)), c + Vector((0, 0.25, 0)), 0.1, 0.1, seg=8)
    L.dbox(P, "ashlar", (0, 0, 0.4), (0.5, 0.5, 0.8), bevel=0.05)


def b_shield_pole(P, rnd):
    post(P, (0, 0, -0.3), (0, 0, 4.2), 0.1, 0.07)
    ring_loft(P, "timber", [[G(math.cos(a) * 0.4, 3.2 + math.sin(a) * 0.48, -0.12) for a in [math.tau * k / 12 for k in range(12)]],
                            [G(math.cos(a) * 0.4, 3.2 + math.sin(a) * 0.48, -0.18) for a in [math.tau * k / 12 for k in range(12)]]])
    cyl(P, "iron", G(0, 3.2, -0.18), G(0, 3.2, -0.27), 0.12, 0.08, seg=8)


def b_pikes(P, rnd):
    for i in range(5):
        x = i * 0.9 - 1.8
        z = rnd.uniform(-0.2, 0.2)
        top = G(x + rnd.uniform(-0.15, 0.15), 3.0 - 0.4 * (i % 3), z)
        cyl(P, "timber", G(x, -0.2, z), top, 0.05, 0.04, seg=5)
        cyl(P, "iron", top - Vector((0, 0, 0.4)), top + Vector((0, 0, 0.05)), 0.06, 0.01, seg=4)


def b_fungus_ring(P, rnd):
    for i in range(9):
        a2 = math.tau * i / 9
        p2 = Vector((math.cos(a2) * 2.0, -math.sin(a2) * 2.0, 0.0))
        h = 0.3 + 0.2 * rnd.random()
        cyl(P, "stone", p2, p2 + Vector((0, 0, h)), 0.05, 0.04, seg=6)
        ring_loft(P, "stone", [[p2 + Vector((math.cos(t) * 0.16, math.sin(t) * 0.16, h)) for t in [math.tau * k / 8 for k in range(8)]],
                               [p2 + Vector((math.cos(t) * 0.12, math.sin(t) * 0.12, h + 0.08)) for t in [math.tau * k / 8 for k in range(8)]]])


def b_wind_flag(P, rnd):
    post(P, (0, 0, -0.3), (0, 0, 4.2), 0.1, 0.07)
    stones_ring(P, rnd, (0.0, 0.0), 0.35, 0.12, 6, (0.28, 0.22, 0.24))


def b_windbreak(P, rnd):
    L.wall_run(P, None, "ashlar", (-2.25, 0.0), (2.25, 0.0), -0.2, 1.4, 0.55, lambda u, v: v < 1.15 + 0.22 * math.sin(u * 1.9), rnd,
               ch=0.28, col=False, blk=(0.35, 0.75), dress_ends=True)



# ------------------------------------------------------------------------------------------------- second pass (render review, 19 Nov)
def b_ballista(P, rnd):
    # a siege bolt-thrower on its trestle: A-frame legs and feet, the stock with its groove and a bolt in it, a composite bow of
    # tapering limbs bound in iron at the bow's root, the winch drum and its spokes at the back (the string is the game's rope)
    for s in (-1.0, 1.0):
        beam(P, "timber", G(s * 1.2, 0.0, 0.0), G(s * 0.55, 1.42, 0.0), 0.18, 0.18)
        beam(P, "timber", G(s * 1.2, 0.0, -0.9), G(s * 0.55, 1.42, -0.3), 0.14, 0.14)
        beam(P, "timber", G(s * 1.35, 0.08, 0.3), G(s * 1.35, 0.08, -1.2), 0.2, 0.16)
        beam(P, "timber", G(s * 0.95, 0.75, 0.0), G(s * 0.95, 0.75, -0.6), 0.08, 0.08)
    beam(P, "timber", G(-1.0, 0.75, -0.3), G(1.0, 0.75, -0.3), 0.1, 0.1)
    cyl(P, "iron", G(-0.62, 1.42, -0.15), G(0.62, 1.42, -0.15), 0.07, 0.07, seg=8)
    for s in (-1.0, 1.0):
        beam(P, "timber", G(s * 0.14, 1.4, -1.6), G(s * 0.14, 1.6, 1.5), 0.1, 0.24)
    beam(P, "timber", G(0.0, 1.32, -1.6), G(0.0, 1.52, 1.5), 0.2, 0.08)
    cyl(P, "timber", G(0.0, 1.6, -1.2), G(0.0, 1.72, 1.15), 0.035, 0.03, seg=6)
    ring_loft(P, "iron", [[G(0.0, 1.72, 1.15) + Vector((math.cos(t) * 0.05, 0, math.sin(t) * 0.05)) for t in [math.tau * q / 6 for q in range(6)]],
                          [G(0.0, 1.735, 1.45) + Vector((math.cos(t) * 0.006, 0, math.sin(t) * 0.006)) for t in [math.tau * q / 6 for q in range(6)]]])
    for s in (-1.0, 1.0):
        tip = 1.7 if s > 0 else 1.5
        pts = [G(s * (0.16 + 1.44 * q / 4.0), 1.57 + (tip - 1.57) * q / 4.0,
                 1.2 + 0.25 * math.sin(math.pi * (0.3 + 0.7 * q / 4.0)) * (1.0 - 0.6 * q / 4.0)) for q in range(5)]
        for q in range(4):
            w = 0.16 - 0.025 * q
            beam(P, "timber", pts[q], pts[q + 1], w * 0.7, w)
        box(P, "iron", tuple(pts[4]), (0.06, 0.08, 0.1))
    for z in (1.05, 1.42):
        box(P, "iron", tuple(G(0.0, 1.5, z)), (0.46, 0.06, 0.32))
    cyl(P, "timber", G(-0.42, 1.48, -1.4), G(0.42, 1.48, -1.4), 0.16, 0.16, seg=10)
    for s in (-1.0, 1.0):
        for q in range(4):
            a = math.tau * q / 4 + 0.4
            beam(P, "timber", G(s * 0.46, 1.48, -1.4), G(s * 0.46, 1.48 + math.sin(a) * 0.42, -1.4 + math.cos(a) * 0.42), 0.04, 0.04)


def b_bell_half(P, rnd):
    # a great bell fallen and sunk to its waist, a shard broken out of its side (the gap the game's kit leaves at 0.6 .. 1.8
    # rad): the wall a thick bronze shell with the sound-bow's swell at the lip, the crown and its hanging loop, the shard
    # lying by it (the kit's iron block at (1.4, 0.2, 0.3)); the edges of the break ragged
    rows = bell_rows(1.86, 0.54 + math.tau, 22, BELL[:-1], 0.07, rnd, lambda q: q)
    shell(P, "iron", rows, 0.11)
    cap = [[Vector((math.cos(math.tau * q / 21) * r, math.sin(math.tau * q / 21) * r, z)) for q in range(22)] for (r, z) in BELL[7:]]
    shell(P, "iron", cap, 0.1)
    for s in (-1.0, 1.0):
        cyl(P, "iron", (s * 0.12, 0.0, 1.58), (s * 0.12, 0.0, 1.9), 0.06, 0.05, seg=6)
    beam(P, "iron", (-0.16, 0.0, 1.9), (0.16, 0.0, 1.9), 0.09, 0.09)
    for z in (0.18, 0.3, 1.3):
        r = 1.2 if z < 0.5 else 0.66
        ring = [Vector((math.cos(a) * (r + 0.025), math.sin(a) * (r + 0.025), z)) for a in [1.95 + (math.tau - 1.5) * q / 23 for q in range(24)]]
        for q in range(23):
            beam(P, "iron", ring[q], ring[q + 1], 0.03, 0.035)

    c = Vector((math.cos(1.15) * 1.05, math.sin(1.15) * 1.05, 0.36))
    rot = Vector((math.cos(1.15), math.sin(1.15), 0.35)).normalized().rotation_difference(Vector((0.2, -0.1, 1.0)).normalized())

    def lie(q):
        return rot @ (q - c) + Vector((1.45, -0.3, 0.16))
    rows = bell_rows(0.75, 1.55, 6, [(1.2, 0.14), (1.06, 0.34), (0.88, 0.62)], 0.08, rnd, lie)
    shell(P, "iron", rows, 0.1)
    L.rubble(P, None, "ashlar", rnd, (-1.7, -1.5, 1.6, -1.1), 4, 0.15, 0.35)


def b_carved_stone(P, rnd):
    # a tall standing stone, tapering and faceted, its head bevelled, a band of carving proud round it at 2.0 .. 2.4 m and
    # a column of runes on the face the kit's band looked out of (-z, Blender +y)
    rings = []
    for (z, sx, sy) in ((-0.3, 0.5, 0.29), (0.4, 0.49, 0.28), (1.4, 0.46, 0.27), (2.4, 0.42, 0.25), (2.95, 0.37, 0.22), (3.2, 0.2, 0.15)):
        ring = []
        for q in range(9):
            a = math.tau * q / 9 + 0.2
            k = 1.0 + 0.07 * math.sin(q * 2.3 + z)
            ring.append(Vector((math.cos(a) * sx * k * 1.2, math.sin(a) * sy * k * 1.2, z + (0.06 * math.sin(a * 2.0) if z > 3.0 else 0.0))))
        rings.append(ring)
    ring_loft(P, "stone", rings)
    for z in (2.02, 2.42):
        ring = [Vector((math.cos(math.tau * q / 9 + 0.2) * 0.42 * 1.25, math.sin(math.tau * q / 9 + 0.2) * 0.25 * 1.25, z)) for q in range(9)]
        ring_loft(P, "stone", [[p + Vector((0, 0, -0.04)) for p in ring], [p + Vector((0, 0, 0.04)) for p in ring]])
    for q in range(4):
        x = -0.22 + q * 0.15
        box(P, "stone", (x, 0.3, 2.22), (0.05, 0.05, 0.22), roll=0.3 if q % 2 else -0.3)
    for q in range(5):
        box(P, "stone", (0.0, 0.31, 1.0 + q * 0.2), (0.16 if q % 2 else 0.1, 0.04, 0.05), yaw=0.0, roll=0.5 * (q % 3 - 1))
    L.rubble(P, None, "ashlar", rnd, (-0.9, -0.8, 0.9, 0.8), 3, 0.15, 0.3)


def b_column_stub(P, rnd):
    # a drowned colonnade's stub: a moulded base on its plinth, three fluted drums, the top one snapped, a fallen drum and
    # chips by it (the game scales it to the kit's height)
    L.dbox(P, "ashlar", (0, 0, -0.05), (1.45, 1.45, 0.4), bevel=0.05)
    cyl(P, "ashlar", (0, 0, 0.15), (0, 0, 0.27), 0.7, 0.68, seg=20)
    cyl(P, "ashlar", (0, 0, 0.27), (0, 0, 0.36), 0.64, 0.6, seg=20)
    fluted(P, "ashlar", (0, 0, 0.36), (0, 0, 2.5), 0.56, 0.52, flutes=12, drums=3, broken=0.32, rnd=rnd)
    fluted(P, "ashlar", (1.0, -0.9, 0.3), (1.65, -0.35, 0.36), 0.3, 0.3, flutes=12, drums=1)
    L.rubble(P, None, "ashlar", rnd, (0.6, -0.5, 1.8, 0.8), 5, 0.15, 0.4)


def b_leaning_pillar(P, rnd):
    # a pillar heeled over on its sinking plinth (the kit's tube from the foot to (1.8, 3.6, 0)), fluted, its capital broken
    L.dbox(P, "ashlar", (0.1, 0, -0.1), (1.5, 1.5, 0.45), roll=0.12, bevel=0.05)
    a = G(0.0, 0.05, 0.0)
    b = G(1.8, 3.6, 0.0)
    fluted(P, "ashlar", a, b, 0.55, 0.5, flutes=12, drums=5, broken=0.0, rnd=rnd)
    d = (b - a).normalized()
    u, v = frame_of(d)
    rings = []
    for (z, r) in ((0.0, 0.52), (0.12, 0.62), (0.32, 0.72), (0.42, 0.74)):
        rings.append([b + d * z + (u * math.cos(math.tau * q / 12) + v * math.sin(math.tau * q / 12)) * r * (1.0 if q % 3 else 0.8)
                      for q in range(12)])
    ring_loft(P, "ashlar", rings)
    L.rubble(P, None, "ashlar", rnd, (1.5, -0.8, 2.6, 0.8), 4, 0.2, 0.45)


def b_scarecrow(P, rnd):
    # a scarecrow on its cross: a tattered coat (a ragged hem, sleeves to straw cuffs), a sacking head tied at the neck,
    # a floppy brimmed hat; straw fans out of the cuffs and the hem
    post(P, (0, 0, -0.3), (0, 0, 2.45), 0.06, 0.05)
    beam(P, "timber", G(-0.95, 1.8, 0.0), G(0.95, 1.8, 0.0), 0.06, 0.06)
    rings = []
    for (z, rx, ry, jag) in ((0.95, 0.36, 0.26, 0.12), (1.2, 0.33, 0.24, 0.0), (1.55, 0.3, 0.22, 0.0), (1.8, 0.3, 0.2, 0.0), (1.92, 0.12, 0.1, 0.0)):
        rings.append([Vector((math.cos(a) * rx, math.sin(a) * ry, z + (rnd.uniform(-jag, jag * 0.3) if jag else 0.0)))
                      for a in [math.tau * q / 12 for q in range(12)]])
    ring_loft(P, "cloth", rings)
    for s in (-1.0, 1.0):
        rings = []
        for (x, r) in ((0.22, 0.13), (0.5, 0.11), (0.8, 0.12)):
            rings.append([G(s * x, 1.8, 0.0) + Vector((0, math.cos(a) * r, math.sin(a) * r)) for a in [math.tau * q / 8 for q in range(8)]])
        ring_loft(P, "cloth", rings)
        for q in range(7):
            a = math.tau * q / 7
            beam(P, "thatch", G(s * 0.78, 1.8, 0.0), G(s * (0.98 + rnd.uniform(0, 0.08)), 1.8 + math.sin(a) * 0.12, math.cos(a) * 0.12), 0.025, 0.02)
    for q in range(10):
        a = math.tau * q / 10
        beam(P, "thatch", (math.cos(a) * 0.3, math.sin(a) * 0.22, 1.0), (math.cos(a) * 0.36, math.sin(a) * 0.27, 0.78 + rnd.uniform(0, 0.08)), 0.03, 0.02)
    head = []
    for (z, r) in ((2.08, 0.06), (2.14, 0.16), (2.28, 0.19), (2.44, 0.17), (2.56, 0.1)):
        head.append([Vector((math.cos(a) * r, math.sin(a) * r * 0.92, z)) for a in [math.tau * q / 10 for q in range(10)]])
    ring_loft(P, "cloth", head)
    cyl(P, "thatch", (0, 0, 2.08), (0, 0, 2.13), 0.09, 0.09, seg=8)
    brim = [[Vector((math.cos(a) * r, math.sin(a) * r, z - (0.06 * (0.5 + 0.5 * math.sin(a * 2.0 + 0.7)) if r > 0.3 else 0.0)))
             for a in [math.tau * q / 14 for q in range(15)]] for (r, z) in ((0.17, 2.57), (0.3, 2.56), (0.44, 2.53))]
    shell(P, "thatch", brim, 0.03)
    ring_loft(P, "thatch", [[Vector((math.cos(a) * 0.19, math.sin(a) * 0.19, 2.54)) for a in [math.tau * q / 10 for q in range(10)]],
                            [Vector((math.cos(a) * 0.15, math.sin(a) * 0.14, 2.78)) for a in [math.tau * q / 10 for q in range(10)]]])


def b_plough(P, rnd):
    # an old mouldboard plough left in the furrow: the beam (the kit's), the coulter knife, an iron share on a timber sole,
    # the curved mouldboard turning the sod to +x, two stilts (handles) up to a rung, the hitch ring at the beam's nose
    beam(P, "timber", G(0.0, 0.5, -1.0), G(0.0, 0.9, 1.6), 0.13, 0.15)
    beam(P, "timber", G(0.0, 0.04, -0.85), G(0.0, 0.06, 0.5), 0.12, 0.1)
    beam(P, "iron", G(0.0, 0.62, -0.62), G(0.0, 0.0, -0.95), 0.03, 0.12)
    ring_loft(P, "iron", [[G(-0.06, 0.0, -0.55), G(0.18, 0.0, -0.55), G(0.04, 0.0, -1.18)],
                          [G(-0.06, 0.06, -0.55), G(0.2, 0.08, -0.55), G(0.04, 0.05, -1.18)]])
    rows = []
    for q in range(5):
        t = q / 4.0
        rows.append([G(0.02 + 0.32 * t * (0.3 + 0.7 * h) + 0.06 * h, 0.05 + 0.42 * h, -0.62 + 0.62 * t - 0.12 * h) for h in (0.0, 0.33, 0.66, 1.0)])
    shell(P, "iron", rows, 0.025)
    for s in (-1.0, 1.0):
        beam(P, "timber", G(s * 0.06, 0.06, 0.3), G(s * 0.42, 1.15, 1.9), 0.07, 0.07)
    beam(P, "timber", G(-0.36, 1.0, 1.72), G(0.36, 1.0, 1.72), 0.045, 0.045)
    beam(P, "timber", G(-0.1, 0.62, 0.95), G(0.1, 0.62, 0.95), 0.06, 0.06)
    ring = [G(0.0, 0.5, -1.06) + Vector((math.cos(a) * 0.08, 0.0, math.sin(a) * 0.08)) for a in [math.tau * q / 8 for q in range(9)]]
    for q in range(8):
        beam(P, "iron", ring[q], ring[q + 1], 0.02, 0.02)


def b_helmet_cairn(P, rnd):
    # a heap of dressed stones (the kit's four) crowned with the fallen's helms: nasal helms and a kettle hat, tipped over,
    # a sword driven in among them
    for i in range(4):
        L.dbox(P, "ashlar", (0, 0, 0.25 + 0.4 * i), (1.4 - 0.25 * i, 1.2 - 0.2 * i, 0.4), yaw=i * 1.0 + rnd.uniform(-0.2, 0.2), bevel=0.07, warp=0.04)
    spots = [(0.0, 0.0, 1.85, 0.0, 0.0), (0.42, 0.3, 1.47, 0.5, 0.35), (-0.45, -0.25, 1.47, -0.6, 2.0), (0.35, -0.4, 1.07, 1.1, 4.0), (-0.5, 0.42, 1.07, 0.4, 1.0)]
    for n, (x, y, z, tilt, yaw) in enumerate(spots):
        c = Vector((x, y, z))
        if n % 2 == 0:
            prof = [(0.17, -0.02), (0.175, 0.06), (0.16, 0.14), (0.12, 0.22), (0.05, 0.29), (0.01, 0.31)]
        else:
            prof = [(0.28, -0.02), (0.27, 0.02), (0.15, 0.04), (0.15, 0.14), (0.1, 0.22), (0.02, 0.25)]
        rings = []
        for (r, zz) in prof:
            ring = []
            for q in range(10):
                a = math.tau * q / 10
                p = Vector((math.cos(a) * r, math.sin(a) * r * 0.92, zz))
                p = Vector((p.x, p.y * math.cos(tilt) - p.z * math.sin(tilt), p.y * math.sin(tilt) + p.z * math.cos(tilt)))
                p = Vector((p.x * math.cos(yaw) - p.y * math.sin(yaw), p.x * math.sin(yaw) + p.y * math.cos(yaw), p.z))
                ring.append(c + p)
            rings.append(ring)
        ring_loft(P, "iron", rings)
        if n % 2 == 0:
            nb = Vector((0.0, -0.17, 0.12))
            nb = Vector((nb.x, nb.y * math.cos(tilt) - nb.z * math.sin(tilt), nb.y * math.sin(tilt) + nb.z * math.cos(tilt)))
            nb = Vector((nb.x * math.cos(yaw) - nb.y * math.sin(yaw), nb.x * math.sin(yaw) + nb.y * math.cos(yaw), nb.z))
            box(P, "iron", tuple(c + nb), (0.04, 0.03, 0.2), yaw=yaw, pitch=tilt)
    beam(P, "iron", (0.25, -0.1, 0.9), (0.33, -0.05, 2.0), 0.08, 0.012)
    beam(P, "iron", (0.31, -0.06, 1.85), (0.31, -0.06, 1.86), 0.3, 0.04)
    cyl(P, "timber", (0.335, -0.045, 2.02), (0.345, -0.04, 2.22), 0.025, 0.025, seg=6)


def b_fish_rack(P, rnd):
    # a drying rack on the reed shore: two forked posts with braces, the ridge pole (the kit's) and a lower rail, lashings
    # (the hung fish are the game's strands)
    for s in (-1.0, 1.0):
        post(P, G(s * 1.4, -0.3, 0.0), G(s * 1.4, 1.75, 0.0), 0.075, 0.06)
        beam(P, "timber", G(s * 1.4, 1.62, 0.0), G(s * 1.48, 1.95, 0.0), 0.05, 0.05)
        beam(P, "timber", G(s * 1.4, 1.62, 0.0), G(s * 1.32, 1.95, 0.0), 0.05, 0.05)
        beam(P, "timber", G(s * 1.4, 0.0, -0.55), G(s * 1.4, 1.35, 0.0), 0.05, 0.05)
        beam(P, "timber", G(s * 1.4, 0.0, 0.55), G(s * 1.4, 1.35, 0.0), 0.05, 0.05)
        cyl(P, "thatch", G(s * 1.4, 1.66, 0.0) + Vector((0, 0, 0.0)), G(s * 1.4, 1.74, 0.0), 0.085, 0.085, seg=8)
    cyl(P, "timber", G(-1.55, 1.7, 0.0), G(1.55, 1.7, 0.0), 0.05, 0.045, seg=7)
    cyl(P, "timber", G(-1.45, 1.05, 0.0), G(1.45, 1.05, 0.0), 0.035, 0.035, seg=6)


def b_eel_basket(P, rnd):
    # a wicker eel trap on its side-stake: a bottle of willow with hoops, the funnel mouth sunk in its neck, a weighting stone
    prof = [(0.3, 0.0), (0.36, 0.2), (0.34, 0.45), (0.28, 0.65), (0.19, 0.82), (0.16, 0.9)]
    rings = [[Vector((math.cos(a) * r, math.sin(a) * r, z)) for a in [math.tau * q / 16 for q in range(16)]] for (r, z) in prof]
    ring_loft(P, "thatch", rings)
    ring_loft(P, "thatch", [[Vector((math.cos(a) * 0.15, math.sin(a) * 0.15, 0.9)) for a in [math.tau * q / 12 for q in range(12)]],
                            [Vector((math.cos(a) * 0.06, math.sin(a) * 0.06, 0.62)) for a in [math.tau * q / 12 for q in range(12)]]], close_ends=False)
    for (r, z) in ((0.31, 0.04), (0.365, 0.22), (0.3, 0.6), (0.17, 0.88)):
        ring = [Vector((math.cos(a) * (r + 0.015), math.sin(a) * (r + 0.015), z)) for a in [math.tau * q / 16 for q in range(17)]]
        for q in range(16):
            beam(P, "timber", ring[q], ring[q + 1], 0.025, 0.03)
    for k in range(10):
        a = math.tau * k / 10
        beam(P, "timber", (math.cos(a) * 0.315, math.sin(a) * 0.315, 0.02), (math.cos(a) * 0.17, math.sin(a) * 0.17, 0.88), 0.018, 0.018)
    post(P, G(0.55, -0.2, 0.2), G(0.55, 0.75, 0.2), 0.035, 0.03, seg=5)
    L.dbox(P, "ashlar", G(-0.45, 0.08, -0.3), (0.3, 0.24, 0.16), yaw=0.4, bevel=0.04, warp=0.03)


def b_boat_hull(P, rnd):
    # a clinker boat half-sunk in the mud: overlapping strakes lofted stem to stern, the stems rising at each end, ribs and
    # a gunwale inside, two thwarts, one strake sprung (a gap where the reeds get in)
    def sec(u, t):
        w = 0.74 * max(0.0, 1.0 - u * u) ** 0.55 + 0.03
        dep = 0.62 * max(0.0, 1.0 - u ** 4) ** 0.5 + 0.06
        gun = 0.78 + 0.14 * u * u
        return G(w * math.sin(t * math.pi * 0.5), gun - dep * math.cos(t * math.pi * 0.5), u * 1.9)
    edges = [-1.0, -0.62, -0.25, 0.0, 0.25, 0.62, 1.0]
    for k in range(len(edges) - 1):
        if k == 4:
            continue                                      # the sprung strake (one side's second plank): the gap
        rows = []
        for q in range(11):
            u = -0.98 + 1.96 * q / 10
            rows.append([sec(u, t) + (Vector((math.copysign(0.02, t), 0, 0)) if j == 0 and t != 0 else Vector()) for j, t in
                         enumerate((edges[k], (edges[k] + edges[k + 1]) * 0.5, edges[k + 1]))])
        shell(P, "timber", rows, 0.035)
    for s in (-1.0, 1.0):
        beam(P, "timber", G(0.0, 0.1, s * 1.75), G(0.0, 1.12, s * 2.0), 0.1, 0.12)
    for q in range(6):
        u = -0.75 + 0.3 * q
        pts = [sec(u, t) for t in [-1.0 + 2.0 * j / 6 for j in range(7)]]
        for j in range(6):
            beam(P, "timber", pts[j], pts[j + 1], 0.05, 0.06)
    for s in (-1.0, 1.0):
        pts = [sec(-0.95 + 1.9 * q / 10, s) for q in range(11)]
        for q in range(10):
            beam(P, "timber", pts[q] + Vector((0, 0, 0.02)), pts[q + 1] + Vector((0, 0, 0.02)), 0.06, 0.06)
    for u in (-0.3, 0.35):
        beam(P, "timber", sec(u, -1.0) + Vector((0, 0, -0.12)), sec(u, 1.0) + Vector((0, 0, -0.12)), 0.24, 0.05)


def b_scorch_post(P, rnd):
    # a charred post, split at its burnt top into two splintered prongs, its foot flared
    rings = []
    for (z, r) in ((-0.2, 0.17), (0.1, 0.15), (0.8, 0.12), (1.6, 0.11), (1.95, 0.1)):
        rings.append([Vector((math.cos(a) * r * (1 + 0.15 * math.sin(a * 3 + z * 5)), math.sin(a) * r * (1 + 0.12 * math.cos(a * 2 + z * 3)), z))
                      for a in [math.tau * q / 7 for q in range(7)]])
    ring_loft(P, "timber", rings)
    beam(P, "timber", (0.03, 0.0, 1.9), (0.1, 0.02, 2.22), 0.08, 0.1)
    beam(P, "timber", (-0.04, 0.01, 1.9), (-0.08, -0.02, 2.08), 0.07, 0.08)


def b_lantern_pole(P, rnd):
    # a tall lantern pole: the shaft wedged in a cairn of stones, iron bands, the arm with its brace and a hook for the lantern
    post(P, (0, 0, -0.3), (0, 0, 5.2), 0.13, 0.1)
    for z in (0.9, 2.6, 4.2):
        cyl(P, "iron", (0, 0, z), (0, 0, z + 0.07), 0.135 - z * 0.006, 0.135 - z * 0.006, seg=8)
    beam(P, "timber", G(-0.1, 5.0, 0.0), G(1.1, 5.0, 0.0), 0.09, 0.09)
    beam(P, "timber", G(0.0, 4.35, 0.0), G(0.7, 4.98, 0.0), 0.06, 0.06)
    beam(P, "iron", G(1.0, 4.96, 0.0), G(1.0, 4.8, 0.0), 0.02, 0.02)
    for q in range(6):
        a = math.tau * q / 6 + 0.3
        L.dbox(P, "ashlar", (math.cos(a) * 0.32, math.sin(a) * 0.32, 0.1), (0.3, 0.24, 0.24), yaw=a, bevel=0.05, warp=0.03)


def b_string_poles(P, rnd):
    # the two poles the lantern string hangs between (seven metres apart along +x), each wedged in stones, a hook at the top
    for x in (0.0, 7.0):
        post(P, G(x, -0.3, 0.0), G(x, 4.45, 0.0), 0.1, 0.08)
        cyl(P, "iron", G(x, 4.25, 0.0), G(x, 4.32, 0.0), 0.1, 0.1, seg=8)
        beam(P, "iron", G(x, 4.3, 0.0), G(x + (0.18 if x == 0.0 else -0.18), 4.4, 0.0), 0.025, 0.025)
        for q in range(5):
            a = math.tau * q / 5 + x
            L.dbox(P, "ashlar", G(x + math.cos(a) * 0.26, 0.08, math.sin(a) * 0.26), (0.24, 0.2, 0.2), yaw=a, bevel=0.05, warp=0.03)


def b_charcoal_clamp(P, rnd):
    # a charcoal clamp: a low dome of turf and ash over the stacked wood, a ring of stakes holding the skirt, the vents
    # (the smoke is the game's); toned dark (DARK)
    rings = []
    for (z, r) in ((-0.05, 1.62), (0.35, 1.54), (0.75, 1.27), (1.1, 0.82), (1.32, 0.36), (1.38, 0.05)):
        rings.append([Vector((math.cos(a) * r * (1 + rnd.uniform(-0.05, 0.05)), math.sin(a) * r * (1 + rnd.uniform(-0.05, 0.05)), z + rnd.uniform(-0.03, 0.03)))
                      for a in [math.tau * k / 16 for k in range(16)]])
    ring_loft(P, "stone", rings)
    for k in range(12):
        a = math.tau * k / 12
        post(P, (math.cos(a) * 1.7, math.sin(a) * 1.7, -0.2), (math.cos(a) * 1.72, math.sin(a) * 1.72, 0.55 + 0.1 * (k % 2)), 0.05, 0.04, seg=5)
    for k in range(4):
        a = math.tau * k / 4 + 0.4
        cyl(P, "timber", (math.cos(a) * 0.95, math.sin(a) * 0.95, 0.98), (math.cos(a) * 1.0, math.sin(a) * 1.0, 1.1), 0.1, 0.08, seg=6)
    for k in range(5):
        a = math.tau * k / 5 + 0.9
        cyl(P, "timber", (math.cos(a) * 1.95, math.sin(a) * 1.95, 0.1), (math.cos(a + 0.2) * 2.05, math.sin(a + 0.2) * 2.05, 0.15), 0.08, 0.08, seg=6)


DARK_OF = {"scorch_post": {"timber": 0.28}, "charcoal_clamp": {"stone": 0.42, "timber": 0.35}}


BUILD = {"haystack": b_haystack, "scarecrow": b_scarecrow, "plough": b_plough, "lamp_post": b_lamp_post,
         "signal_pole": b_signal_pole, "notice_board": b_notice_board, "cairn_stack": b_cairn_stack, "helmet_cairn": b_helmet_cairn,
         "grave_mound": b_grave_mound, "carved_stone": b_carved_stone, "wreath_stake": b_wreath_stake, "fish_rack": b_fish_rack,
         "eel_basket": b_eel_basket, "boat_hull": b_boat_hull, "reed_fence": b_reed_fence, "charcoal_clamp": b_charcoal_clamp,
         "bark_rack": b_bark_rack, "snare": b_snare, "wood_stack": b_wood_stack, "bell_half": b_bell_half, "scorch_post": b_scorch_post,
         "column_stub": b_column_stub, "leaning_pillar": b_leaning_pillar, "pews": b_pews, "fallen_arch": b_fallen_arch, "pipe": b_pipe,
         "sluice_wheel": b_sluice_wheel, "ballista": b_ballista, "shield_pole": b_shield_pole, "pikes": b_pikes,
         "lantern_pole": b_lantern_pole, "string_poles": b_string_poles, "fungus_ring": b_fungus_ring, "wind_flag": b_wind_flag,
         "windbreak": b_windbreak}

_tone_base = W.tone_for


def _tone_dark(key, co, n, flat):
    c = _tone_base(key, co, n, flat)
    k = DARK.get(key, 1.0)
    return (c[0] * k, c[1] * k, c[2] * k)


W.tone_for = _tone_dark
os.makedirs(OUT, exist_ok=True)
done = []
for kind, fn in BUILD.items():
    if ONLY and kind not in ONLY:
        continue
    reset()
    DARK.clear()
    DARK.update(DARK_OF.get(kind, {}))
    P = Parts()
    seed = sum(ord(ch) * (i + 1) for i, ch in enumerate(kind)) % 997
    rnd = L.rnd_for(seed)
    L.mason_begin(seed)
    fn(P, rnd)
    objs = finish(P, "Sig") + L.mason_end("Sig")
    export(objs, os.path.join(OUT, "sig_%s.glb" % kind), kind)
    lo = Vector((1e9, 1e9, 1e9))
    hi = -lo
    for o in objs:
        for v in o.data.vertices:
            lo = Vector((min(lo.x, v.co.x), min(lo.y, v.co.y), min(lo.z, v.co.z)))
            hi = Vector((max(hi.x, v.co.x), max(hi.y, v.co.y), max(hi.z, v.co.z)))
    c = (lo + hi) * 0.5
    r = max((hi - lo).length * 0.5, 0.8)
    d = Vector((-0.62, -0.72, 0.32)).normalized() * r * 2.7
    preview(objs, "sig_" + kind, [(tuple(c + d), tuple(c), 35), (tuple(c + Vector((-d.x, -d.y, d.z))), tuple(c), 35)], size=(560, 360))
    print("SIG %s: %d tris" % (kind, sum(tris(o) for o in objs)))
    done.append(kind)
print("SIG done", len(done))
