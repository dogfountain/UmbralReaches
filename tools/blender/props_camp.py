"""The camps' own props (r39 camps and villages look): what a camp is built from, so a fire is not a bare patch of grass.

  tools/blender/run.sh props_camp.py -- [--only camp_tent,camp_rack,...] [--preview DIR]

Same pipeline and the same measures as props_square.py (it is loaded from there: metric box UVs per set, vertex tone, the
game's tiling PBR sets timber / iron / cloth / stone, a `-colonly` box). Godot metres, pivot at the base centre, y up; the
open side of a thing that faces a fire is +z (the placing code turns +z toward the fire).

  camp_tent      lean-to of canvas on a ridge pole and two forked posts, 3.1 x 2.2 m, 1.6 m at the open front (+z)
  camp_bedroll   a mat, a folded blanket and a rolled pillow, 0.75 x 1.9 m
  camp_rack      weapon rack: two A-frames, a high and a low bar, five spears, two round shields; 2.1 m wide, 1.9 m high
  camp_spit      the cooking place: a ring of nine stones round the ash, a lashed tripod, a chain and an iron pot; 2.0 m high
  camp_watch     the lookout: four splayed legs braced, a railed platform at 3.6 m, a ladder, a pitched roof (5.8 m)
  camp_stakes    a palisade bay: seven sharpened stakes lashed to two rails, 3.1 m wide, about 2.1 m high
  camp_hides     a drying frame with two stretched hides, 1.8 x 1.6 m
  camp_den       a beasts' den: a ring of leaning branches and ribs over a hollow, 2.8 m across, 1.1 m high
  camp_log       a sitting log, 1.4 m
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
_src = open(os.path.join(HERE, "props_square.py")).read().rsplit("\nmain()", 1)[0]
exec(compile(_src, os.path.join(HERE, "props_square.py"), "exec"), globals())

STONE = 7
KEY[STONE] = 'stone'
TILE['stone'] = 2.0

CANVAS = [(0.64, 0.63, 0.60), (0.56, 0.56, 0.55), (0.5, 0.5, 0.5)]      # the cloth set is a warm burlap: kept cool so a tent reads as weathered canvas, not hay
OCHRE = (0.66, 0.42, 0.28)
SLATE = (0.38, 0.42, 0.52)
HIDE = (0.55, 0.42, 0.32)


def beam(p, a, b, w, kind=WOOD, tone="mid", d2=None, jit=0.0, col=None, omit=()):
    a, b = Vector(a), Vector(b)
    d = b - a
    L = d.length
    R = Vector((0, 1, 0)).rotation_difference(d.normalized()).to_matrix()
    return box(p, (a + b) / 2, (w, L, d2 or w), R, kind=kind, tone=tone, jit=jit, col=col, omit=omit)


def sheet(p, a, b, c, thick=0.018, col=None, kind=CLOTH):
    """A thin slab from corner a: edge u to b, edge v to c (a canvas, a hide)."""
    a, b, c = Vector(a), Vector(b), Vector(c)
    u, v = b - a, c - a
    n = u.cross(v).normalized()
    R = Matrix((u.normalized(), n, v.normalized())).transposed()
    return box(p, a + u / 2 + v / 2, (u.length, thick, v.length), R, kind=kind, col=col or CANVAS[0])


def ring_x(cx, cy, cz, r, n=8, rz=None):
    return [V(cx, cy + r * math.cos(2 * math.pi * i / n), cz + (rz or r) * math.sin(2 * math.pi * i / n)) for i in range(n)]


def stone_box(p, c, s, yaw=0.0, col=None):
    col = col or (0.58, 0.57, 0.55)
    return box(p, c, s, rotm(yaw), kind=STONE, col=col, jit=0.012)


def lash(p, c, r=0.07, h=0.05):
    box(p, c, (r * 2, h, r * 2), kind=CLOTH, col=(0.5, 0.42, 0.3))


# ---------------------------------------------------------------------------------------------------------
def build_tent():
    p = P(101)
    rng = p.rng
    FZ, FY, BZ = 0.95, 1.58, -1.1
    for sx in (-1.5, 1.5):                               # the forked posts
        beam(p, V(sx, 0.0, FZ), V(sx, FY + 0.08, FZ), 0.1, tone="dark", jit=0.004)
        beam(p, V(sx, FY, FZ), V(sx + 0.1, FY + 0.28, FZ), 0.05, tone="dark")
        beam(p, V(sx, FY, FZ), V(sx - 0.1, FY + 0.28, FZ), 0.05, tone="dark")
    beam(p, V(-1.75, FY + 0.06, FZ), V(1.75, FY + 0.1, FZ), 0.09, tone="grey", jit=0.003)          # the ridge pole
    # the canvas: from the front pole down to the ground behind, sagging in the middle, a hem on the ground
    sheet(p, V(-1.62, FY + 0.12, FZ), V(1.62, FY + 0.12, FZ), V(-1.62, 1.02, -0.1), col=CANVAS[0])
    sheet(p, V(-1.62, 1.02, -0.1), V(1.62, 1.02, -0.1), V(-1.62, 0.1, BZ), col=CANVAS[1])
    sheet(p, V(-1.62, 0.1, BZ), V(1.62, 0.1, BZ), V(-1.62, 0.0, BZ - 0.28), col=CANVAS[2])
    # the closed end (east): a triangle of canvas; the west end is tied back
    for sx, closed in ((1.56, True), (-1.56, False)):
        if closed:
            ext(p, [(BZ, 0.0), (FZ - 0.1, 0.0), (FZ - 0.1, FY - 0.05), (-0.1, 0.98)], 0.03, V(sx, 0.0, 0.0), axis='x', kind=CLOTH, col=CANVAS[1])
        else:
            ext(p, [(0.3, 0.0), (FZ - 0.1, 0.0), (FZ - 0.1, 1.05)], 0.03, V(sx, 0.0, 0.0), axis='x', kind=CLOTH, col=CANVAS[2])
    for sx in (-1.7, 1.7):                               # guys to pegs, the pegs
        beam(p, V(sx * 0.92, FY + 0.1, FZ), V(sx * 1.08, 0.03, FZ + 0.95), 0.014, kind=CLOTH, col=(0.5, 0.42, 0.3))
        beam(p, V(sx * 1.08, 0.0, FZ + 0.95), V(sx * 1.08 - 0.03 * sx, 0.3, FZ + 0.9), 0.04, tone="pale")
    for x in (-1.2, -0.4, 0.4, 1.2):                     # lashed ties along the front edge
        lash(p, V(x, FY + 0.1, FZ), 0.05, 0.05)
    box(p, V(0, 0.015, 0.0), (2.7, 0.02, 1.7), kind=CLOTH, col=(0.4, 0.34, 0.26))                  # a ground cloth
    return finish(p, "camp_tent", (V(0, 0.8, -0.1), (3.2, 1.6, 2.3)))


def build_bedroll():
    p = P(111)
    box(p, V(0, 0.018, 0.0), (0.74, 0.036, 1.88), kind=CLOTH, col=(0.45, 0.38, 0.3), jit=0.004)      # the mat
    box(p, V(0.02, 0.06, 0.22), (0.62, 0.05, 1.12), kind=CLOTH, col=OCHRE, jit=0.01)                  # the blanket, laid over
    box(p, V(0.02, 0.095, 0.6), (0.64, 0.025, 0.2), kind=CLOTH, col=(0.62, 0.61, 0.58), jit=0.004)    # its turned-back hem
    rings = [ring_x(x, 0.12, -0.72, 0.1 if 0.04 < abs(x - 0.0) < 0.3 else 0.085, 9, 0.1) for x in (-0.3, -0.26, -0.1, 0.1, 0.26, 0.3)]
    loft(p, rings, (0.52, 0.52, 0.5), CLOTH, True, True, True)                                       # the rolled pillow
    lash(p, V(-0.12, 0.12, -0.72), 0.11, 0.025)
    lash(p, V(0.12, 0.12, -0.72), 0.11, 0.025)
    return finish(p, "camp_bedroll", (V(0, 0.07, 0), (0.78, 0.15, 1.9)))


def build_rack():
    p = P(121)
    rng = p.rng
    for sx in (-0.95, 0.95):                             # two A-frames
        beam(p, V(sx, 0.0, 0.34), V(sx, 1.5, 0.02), 0.08, tone="dark", jit=0.003)
        beam(p, V(sx, 0.0, -0.34), V(sx, 1.5, -0.02), 0.08, tone="dark", jit=0.003)
        lash(p, V(sx, 1.5, 0.0), 0.07, 0.07)
    beam(p, V(-1.1, 1.18, 0.0), V(1.1, 1.18, 0.0), 0.07, tone="grey")
    beam(p, V(-1.05, 0.5, 0.2), V(1.05, 0.5, 0.2), 0.06, tone="grey")
    for i, x in enumerate((-0.7, -0.35, 0.0, 0.35, 0.7)):                                           # spears leaning on the high bar
        top = V(x + rng.uniform(-0.04, 0.04), 1.92 + rng.uniform(-0.08, 0.05), -0.08)
        beam(p, V(x, 0.0, 0.42), top, 0.035, tone="pale")
        hd = top + V(0, 0.2, -0.02)
        ext(p, [(-0.04, 0.0), (0.04, 0.0), (0.0, 0.26)], 0.012, top + V(0, 0.0, -0.02), axis='z', kind=IRON)
    for sx, col in ((-0.78, (0.46, 0.34, 0.26)), (0.62, (0.36, 0.38, 0.45))):                      # two round shields on the low bar
        rings = [[V(sx + 0.33 * math.cos(a) * k, 0.5 + 0.33 * math.sin(a) * k + 0.3, 0.3 - 0.08 * k * math.sin(a)) for a in [2 * math.pi * i / 12 for i in range(12)]] for k in (1.0, 0.9)]
        loft(p, rings, col, WOOD, True, True, True)
        box(p, V(sx, 0.8, 0.36), (0.13, 0.13, 0.05), kind=IRON)
    return finish(p, "camp_rack", (V(0, 0.95, 0.0), (2.2, 1.9, 0.9)))


def build_spit():
    p = P(131)
    rng = p.rng
    for i in range(9):                                   # the ring
        a = 2 * math.pi * i / 9 + rng.uniform(-0.1, 0.1)
        stone_box(p, V(0.62 * math.cos(a), 0.11, 0.62 * math.sin(a)), (0.3 + rng.uniform(-0.03, 0.05), 0.22 + rng.uniform(-0.03, 0.04), 0.26), a)
    loft(p, [[V(0.7 * math.cos(2 * math.pi * i / 10), 0.0, 0.7 * math.sin(2 * math.pi * i / 10)) for i in range(10)],
             [V(0.5 * math.cos(2 * math.pi * i / 10), 0.04, 0.5 * math.sin(2 * math.pi * i / 10)) for i in range(10)]], (0.1, 0.09, 0.08), DARK, False, False, True)   # the ash
    top = V(0, 1.95, 0)
    for k in range(3):                                   # the tripod
        a = math.pi / 2 + 2 * math.pi * k / 3
        beam(p, V(1.05 * math.cos(a), 0.0, 1.05 * math.sin(a)), top + V(0.04 * math.cos(a), 0, 0.04 * math.sin(a)), 0.075, tone="dark", jit=0.003)
        lash(p, V(0.18 * math.cos(a), 1.77, 0.18 * math.sin(a)), 0.065, 0.06)
    box(p, V(0, 1.95, 0), (0.16, 0.09, 0.16), kind=IRON)
    beam(p, V(0, 1.92, 0), V(0, 1.22, 0), 0.016, kind=IRON)                                       # the chain
    prof = [(0.0, 0.0), (0.2, 0.02), (0.31, 0.1), (0.35, 0.22), (0.31, 0.34), (0.26, 0.38)]       # the pot
    rings = [[V(r * math.cos(2 * math.pi * i / 12), 0.95 + h, r * math.sin(2 * math.pi * i / 12)) for i in range(12)] for r, h in prof[1:]]
    loft(p, rings, (0.45, 0.42, 0.4), IRON, True, True, True)
    box(p, V(0, 1.2, 0), (0.5, 0.02, 0.02), kind=IRON)                                              # the bail
    box(p, V(0.0, 1.33, 0), (0.02, 0.22, 0.02), kind=IRON)
    return finish(p, "camp_spit", (V(0, 1.0, 0), (2.1, 2.0, 2.1)))


def build_watch():
    p = P(141)
    rng = p.rng
    TY = 3.6
    corners = [(-1, -1), (1, -1), (1, 1), (-1, 1)]
    for sx, sz in corners:                               # legs, splayed
        beam(p, V(sx * 1.15, 0.0, sz * 1.15), V(sx * 0.8, TY + 0.05, sz * 0.8), 0.17, tone="dark", jit=0.004)
    for lvl, (y0, y1) in enumerate(((0.7, 2.2), (2.2, 3.4))):                                         # braces: crossed on every face
        f0, f1 = 1.15 - 0.35 * y0 / TY, 1.15 - 0.35 * y1 / TY
        for i in range(4):
            (ax, az), (bx, bz) = corners[i], corners[(i + 1) % 4]
            beam(p, V(ax * f0, y0, az * f0), V(bx * f1, y1, bz * f1), 0.065, tone="grey")
            beam(p, V(bx * f0, y0, bz * f0), V(ax * f1, y1, az * f1), 0.065, tone="grey")
            ring_a = V((ax + bx) * 0.5 * f1, y1, (az + bz) * 0.5 * f1)
            lash(p, ring_a, 0.06, 0.05)
        for i in range(4):
            (ax, az), (bx, bz) = corners[i], corners[(i + 1) % 4]
            beam(p, V(ax * f1, y1, az * f1), V(bx * f1, y1, bz * f1), 0.1, tone="mid")                # the ring beams
    for i in range(10):                                  # deck boards
        box(p, V(-0.9 + 0.2 * i, TY + 0.1, 0.0), (0.19, 0.06, 2.1), tone=["mid", "pale", "grey"][i % 3], jit=0.003)
    for z in (-0.9, 0.0, 0.9):
        beam(p, V(-1.05, TY + 0.04, z), V(1.05, TY + 0.04, z), 0.1, tone="dark")
    for sx, sz in corners:                               # rail posts and roof posts
        beam(p, V(sx * 0.95, TY + 0.1, sz * 0.95), V(sx * 0.95, TY + 1.9, sz * 0.95), 0.09, tone="dark")
    for y in (TY + 0.55, TY + 1.05):
        for i in range(4):
            (ax, az), (bx, bz) = corners[i], corners[(i + 1) % 4]
            if i == 3 and y == TY + 0.55:
                continue                                  # the way up
            beam(p, V(ax * 0.95, y, az * 0.95), V(bx * 0.95, y, bz * 0.95), 0.06, tone="grey")
    for sx in (-1, 1):                                    # the roof: two canvas pitches and a ridge
        sheet(p, V(sx * 1.2, TY + 1.78, -1.15), V(sx * 1.2, TY + 1.78, 1.15), V(sx * 0.0, TY + 2.35, -1.15), col=CANVAS[1 if sx < 0 else 0], thick=0.03)
    beam(p, V(0, TY + 2.35, -1.2), V(0, TY + 2.35, 1.2), 0.1, tone="dark")
    for sx, sz in corners:
        beam(p, V(sx * 0.95, TY + 1.9, sz * 0.95), V(sx * 1.1, TY + 1.8, sz * 1.1), 0.07, tone="dark")
    for sx in (-0.26, 0.26):                              # the ladder
        beam(p, V(sx, 0.0, 1.55), V(sx, TY + 0.2, 0.98), 0.07, tone="grey")
    for i in range(10):
        t = (i + 0.7) / 10.4
        box(p, V(0.0, t * (TY + 0.2), 1.55 + (0.98 - 1.55) * t), (0.5, 0.045, 0.055), tone="pale")
    beam(p, V(0.0, TY + 1.78, 1.05), V(0.0, TY + 1.55, 1.05), 0.014, kind=IRON)                    # a hook for a lantern
    box(p, V(0.0, TY + 1.5, 1.05), (0.2, 0.05, 0.2), kind=IRON)
    return finish(p, "camp_watch", (V(0, 2.9, 0), (2.5, 5.8, 2.5)))


def build_stakes():
    p = P(151)
    rng = p.rng
    for i in range(7):
        x = -1.5 + 0.5 * i + rng.uniform(-0.04, 0.04)
        h = 2.0 + rng.uniform(-0.2, 0.3)
        a = V(x, 0.0, rng.uniform(-0.03, 0.03))
        lean = rng.uniform(-0.05, 0.05)
        tp = V(x + lean, h, a.z)
        beam(p, a, tp - V(0, 0.28, 0), 0.17, tone=["dark", "grey", "mid"][i % 3], jit=0.006)
        box(p, tp - V(0, 0.14, 0), (0.15, 0.3, 0.15), taper=(0.05, 0.05), tone="pale", jit=0.004)  # the point
    for y in (0.65, 1.4):
        beam(p, V(-1.6, y, 0.14), V(1.6, y + rng.uniform(-0.03, 0.03), 0.14), 0.08, tone="grey")
        for x in (-1.25, 0.0, 1.25):
            lash(p, V(x, y, 0.12), 0.09, 0.08)
    for sx in (-1.5, 1.5):                                # a brace behind the end stakes
        beam(p, V(sx, 0.0, 0.9), V(sx, 1.3, 0.1), 0.09, tone="dark")
    return finish(p, "camp_stakes", (V(0, 1.0, 0.4), (3.3, 2.1, 1.1)))


def build_hides():
    p = P(161)
    for sx in (-0.85, 0.85):
        beam(p, V(sx, 0.0, 0.0), V(sx, 1.65, 0.0), 0.1, tone="dark")
    beam(p, V(-1.0, 1.55, 0.0), V(1.0, 1.55, 0.0), 0.08, tone="grey")
    beam(p, V(-0.95, 0.25, 0.0), V(0.95, 0.25, 0.0), 0.07, tone="grey")
    for k, (x0, x1, col) in enumerate(((-0.8, -0.05, HIDE), (0.05, 0.8, (0.4, 0.3, 0.24)))):
        sheet(p, V(x0, 1.45, 0.05), V(x1, 1.4, 0.05), V(x0 + 0.03, 0.34, 0.07), thick=0.03, col=col)
        for x in (x0 + 0.02, x1 - 0.02):
            beam(p, V(x, 1.42, 0.05), V(x, 1.55, 0.0), 0.014, kind=CLOTH, col=(0.5, 0.42, 0.3))
            beam(p, V(x, 0.36, 0.07), V(x, 0.25, 0.0), 0.014, kind=CLOTH, col=(0.5, 0.42, 0.3))
    return finish(p, "camp_hides", (V(0, 0.85, 0), (2.0, 1.7, 0.3)))


def build_den():
    p = P(171)
    rng = p.rng
    loft(p, [[V(1.2 * math.cos(2 * math.pi * i / 10), 0.0, 1.2 * math.sin(2 * math.pi * i / 10)) for i in range(10)],
             [V(1.1 * math.cos(2 * math.pi * i / 10), 0.045, 1.1 * math.sin(2 * math.pi * i / 10)) for i in range(10)]], (0.1, 0.08, 0.07), DARK, False, False, True)
    n = 13
    for i in range(n):
        a = 2 * math.pi * i / n
        if 0.3 < (a % (2 * math.pi)) < 0.85:
            continue                                      # the way in
        r0 = 1.3 + rng.uniform(-0.1, 0.12)
        h = 0.85 + rng.uniform(-0.15, 0.3)
        a2 = a + rng.uniform(-0.25, 0.25)
        beam(p, V(r0 * math.cos(a), 0.0, r0 * math.sin(a)), V(0.35 * math.cos(a2), h, 0.35 * math.sin(a2)), 0.075 + rng.uniform(0.0, 0.03), tone=["dark", "grey", "mid"][i % 3], jit=0.006)
    for i in range(9):                                    # cross-woven sticks, rib bones
        a = rng.uniform(0, 2 * math.pi)
        r = rng.uniform(0.7, 1.1)
        h = rng.uniform(0.2, 0.7)
        d = rng.uniform(0, 2 * math.pi)
        c = V(r * math.cos(a), h, r * math.sin(a))
        beam(p, c - V(0.5 * math.cos(d), -0.05, 0.5 * math.sin(d)), c + V(0.5 * math.cos(d), 0.1, 0.5 * math.sin(d)), 0.045, tone="pale" if i % 2 else "grey")
    for i in range(6):                                    # bones on the floor
        a = rng.uniform(0, 2 * math.pi)
        r = rng.uniform(0.1, 0.8)
        box(p, V(r * math.cos(a), 0.06, r * math.sin(a)), (0.32, 0.06, 0.07), rotm(rng.uniform(0, 3.14)), kind=CLAY, col=(0.82, 0.78, 0.68), jit=0.01)
    return finish(p, "camp_den", (V(0, 0.55, 0), (2.8, 1.1, 2.8)))


def build_log():
    p = P(181)
    rng = p.rng
    rings = [ring_x(x, 0.19, 0.0, 0.18 + rng.uniform(-0.012, 0.012), 8) for x in (-0.7, -0.35, 0.0, 0.35, 0.7)]
    loft(p, rings, p.wood("mid"), WOOD, True, True, True)
    box(p, V(0, 0.325, 0), (1.3, 0.03, 0.2), tone="pale")                                           # worn flat by sitting
    beam(p, V(0.2, 0.2, 0.12), V(0.45, 0.3, 0.34), 0.06, tone="dark")
    return finish(p, "camp_log", (V(0, 0.19, 0), (1.45, 0.38, 0.4)))


MODELS = [
    ("camp_tent", build_tent, V(0, 0.7, 0.4)),
    ("camp_bedroll", build_bedroll, V(0, 0.1, 0)),
    ("camp_rack", build_rack, V(0, 1.0, 0)),
    ("camp_spit", build_spit, V(0, 1.0, 0)),
    ("camp_watch", build_watch, V(0, 3.0, 0)),
    ("camp_stakes", build_stakes, V(0, 1.0, 0)),
    ("camp_hides", build_hides, V(0, 0.9, 0)),
    ("camp_den", build_den, V(0, 0.5, 0)),
    ("camp_log", build_log, V(0, 0.2, 0)),
]


def main_camp():
    for name, fn, focus in MODELS:
        if ONLY and name not in ONLY:
            continue
        reset()
        MERGE.clear()
        global INDOOR
        INDOOR = False
        if name in ("camp_bedroll", "camp_hides", "camp_tent"):
            MERGE["timber"] = "timber"
        vis, col = fn()
        near = tri_count(vis)
        export(vis + [col], os.path.join(OUT, name + ".glb"))
        lo, hi = bounds(vis)
        print("PROP %-14s tris %4d  size x %.2f..%.2f  y %.2f..%.2f  z %.2f..%.2f" % (
            name, near, lo.x, hi.x, lo.y, hi.y, lo.z, hi.z))
        if PREVIEW:
            col.hide_render = True
            render_set(vis, name, focus)


main_camp()
