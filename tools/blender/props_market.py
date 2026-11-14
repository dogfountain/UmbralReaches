"""Hearthward's market and gate, modelled by script (r37 expansion, the square's second pass).

  tools/blender/run.sh props_market.py -- [--only market_stall_a,...] [--preview DIR]

The same house style as props_square.py (this script runs that file's helpers, minus its main): `<part>__<set>`
meshes with metric UVs, vertex colour as a TONE multiplier only on the tiling r37 sets (timber, iron, cloth, stone,
ashlar, slate), pivot at the base centre, Godot metres, y up, the front of a stall on +z.

  market_stall_a/b/c.glb   3.0 x 1.9 x 2.9   an awninged stall: plank back, counter, striped cloth awning with a
                           scalloped valance; a = produce crates and sacks (madder and cream), b = hung pots and a
                           barrel (indigo and ochre), c = cloth bolts and herb bundles under a lantern hook (moss)
  market_cross.glb         r 2.1 x 4.9 tall   an octagonal three-step plinth, a tapering shaft, a carved capital and a
                           ringed cross head (stone, ashlar)
  village_gate.glb         7.6 x 3.6 x 5.7    a roofed timber gate on stone footings, the road passes under it: four
                           posts, tie beams, braces, a slate gable, side rails with seats, a hung lantern cage
  wall_low.glb             3.0 x 0.6 x 1.2    a coursed stone wall bay with a coping; wall_pier.glb 0.8 x 0.8 x 1.9
  hitch_rail.glb           2.4 x 0.3 x 1.25   two posts, a rail, iron rings
  washing_line.glb         5.0 x 0.1 x 2.6    two poles, a line, sheets and shirts (cloth)
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
src = open(os.path.join(HERE, "props_square.py")).read()
head, _, _tail = src.rpartition("\nmain()")
ns = {"__name__": "props_square_lib", "__file__": os.path.join(HERE, "props_square.py")}
exec(compile(head, os.path.join(HERE, "props_square.py"), "exec"), ns)

bpy = ns["bpy"]
P, box, ext, nail, finish, export, reset, bounds, tri_count = (ns[k] for k in ("P", "box", "ext", "nail", "finish", "export", "reset", "bounds", "tri_count"))
V, B, G, rotm, render_set = ns["V"], ns["B"], ns["G"], ns["rotm"], ns["render_set"]
WOOD, IRON, CLOTH, GRAIN, DARK, CLAY = ns["WOOD"], ns["IRON"], ns["CLOTH"], ns["GRAIN"], ns["DARK"], ns["CLAY"]
Vector, Matrix = ns["Vector"], ns["Matrix"]
OUT, PREVIEW, ONLY = ns["OUT"], ns["PREVIEW"], ns["ONLY"]

STONE, ASHLAR, SLATE = 7, 8, 9
ns["KEY"].update({STONE: "stone", ASHLAR: "ashlar", SLATE: "slate"})
ns["TILE"].update({"stone": 2.0, "ashlar": 2.0, "slate": 2.0})
_orig_tone = ns["tone"]


def _tone(kind, co, n, c):
    if kind in (STONE, ASHLAR, SLATE):
        return _orig_tone(WOOD if kind != SLATE else GRAIN, co, n, c)     # the same foot AO, damp and moss
    return _orig_tone(kind, co, n, c)


ns["tone"] = _tone


# --- little helpers ---------------------------------------------------------------------------------------
def quad(p, pts, col, kind, out=None):
    return p.fc([p.vt(V(*q)) for q in pts], col, kind, False, out=None if out is None else V(*out))


def stone_col(p, tone="mid"):
    v = p.rng.uniform(0.82, 1.0)
    base = {"mid": (0.9, 0.88, 0.84), "pale": (1.0, 0.97, 0.9), "dark": (0.66, 0.64, 0.62)}[tone]
    return (base[0] * v, base[1] * v, base[2] * v)


def prism(p, n, r, y0, y1, c=(0.0, 0.0), kind=STONE, rot=0.0, r1=None, col=None, cols=None, caps=(True, True), tone="mid"):
    """An n-gon prism or frustum (radius r at y0, r1 at y1) about c (x, z)."""
    r1 = r if r1 is None else r1
    col = col or (stone_col(p, tone) if kind in (STONE, ASHLAR, SLATE) else p.wood(tone))
    a = [rot + 2 * math.pi * i / n for i in range(n)]
    lo = [p.vt(V(c[0] + r * math.cos(t), y0, c[1] + r * math.sin(t))) for t in a]
    hi = [p.vt(V(c[0] + r1 * math.cos(t), y1, c[1] + r1 * math.sin(t))) for t in a]
    mid = V(c[0], (y0 + y1) / 2, c[1])
    for i in range(n):
        j = (i + 1) % n
        m = p.rng.uniform(0.93, 1.06)
        cc = (cols[i % len(cols)] if cols else (col[0] * m, col[1] * m, col[2] * m))
        p.fc([lo[i], lo[j], hi[j], hi[i]], cc, kind, False, out=mid)
    if caps[0]:
        p.fc(lo, col, kind, False, out=mid)
    if caps[1]:
        p.fc(hi, (col[0] * 1.05, col[1] * 1.05, col[2] * 1.05), kind, False, out=mid)


def blob(p, c, rad, col, kind, n=7, m=5, cols=None):
    """A UV sphere squashed to rad (x, y, z)."""
    rings = []
    for k in range(1, m):
        v = math.pi * k / m
        rings.append([p.vt(V(c[0] + rad[0] * math.sin(v) * math.cos(2 * math.pi * i / n),
                              c[1] + rad[1] * math.cos(v),
                              c[2] + rad[2] * math.sin(v) * math.sin(2 * math.pi * i / n))) for i in range(n)])
    top = p.vt(V(c[0], c[1] + rad[1], c[2]))
    bot = p.vt(V(c[0], c[1] - rad[1], c[2]))
    ctr = V(*c)
    for i in range(n):
        j = (i + 1) % n
        cc = col
        p.fc([rings[0][i], rings[0][j], top], cc, kind, True, out=ctr)
        for k in range(len(rings) - 1):
            p.fc([rings[k][i], rings[k][j], rings[k + 1][j], rings[k + 1][i]], cc, kind, True, out=ctr)
        p.fc([rings[-1][j], rings[-1][i], bot], cc, kind, True, out=ctr)


def beam_between(p, a, b, w, kind=WOOD, tone="mid", jit=0.0, col=None):
    """A square beam from a to b (Godot points)."""
    a, b = Vector(a), Vector(b)
    d = b - a
    ln = d.length
    z = d.normalized()
    x = Vector((0, 1, 0)).cross(z)
    if x.length < 1e-3:
        x = Vector((1, 0, 0))
    x.normalize()
    y = z.cross(x)
    R = Matrix(((x.x, y.x, z.x), (x.y, y.y, z.y), (x.z, y.z, z.z)))
    box(p, (a + b) / 2, (w, w, ln), R, kind=kind, tone=tone, jit=jit, col=col)


# --- the stalls ------------------------------------------------------------------------------------------
AWN = [((0.82, 0.2, 0.16), (1.0, 0.92, 0.74)), ((0.2, 0.3, 0.72), (0.98, 0.78, 0.3)), ((0.26, 0.52, 0.28), (1.0, 0.93, 0.78))]


def crate_of(p, c, yaw, fruit):
    R = rotm(yaw)
    for sx, sz in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
        box(p, Vector(c) + R @ V(sx * 0.2, 0.12, sz * 0.15), (0.04, 0.24, 0.04), tone="dark")
    for row in (0.07, 0.19):
        for sz in (-1, 1):
            box(p, Vector(c) + R @ V(0, row, sz * 0.165), (0.44, 0.095, 0.025), R, tone="pale" if row > 0.1 else "mid", jit=0.002)
        for sx in (-1, 1):
            box(p, Vector(c) + R @ V(sx * 0.215, row, 0), (0.025, 0.095, 0.3), R, tone="grey", jit=0.002)
    box(p, Vector(c) + R @ V(0, 0.03, 0), (0.4, 0.03, 0.3), R, tone="dark")
    for i in range(10):
        a = p.rng.uniform(0, 6.28)
        rr = p.rng.uniform(0.0, 0.12)
        blob(p, Vector(c) + R @ V(math.cos(a) * rr * 1.2, 0.25 + 0.03 * (i % 3), math.sin(a) * rr), (0.07, 0.065, 0.07),
             fruit[i % len(fruit)], CLOTH, 6, 4)


def sack_at(p, c, s, yaw=0.0):
    col = (1.0, 0.88, 0.66)
    R = rotm(yaw)
    blob(p, Vector(c) + R @ V(0, 0.34 * s, 0), (0.3 * s, 0.36 * s, 0.26 * s), col, CLOTH, 8, 5)
    blob(p, Vector(c) + R @ V(0.02, 0.72 * s, 0), (0.1 * s, 0.09 * s, 0.1 * s), (0.7, 0.58, 0.42), CLOTH, 6, 4)


def awning(p, variant, w=3.4, z0=-1.05, y0=3.04, z1=1.3, y1=2.3):
    cA, cB = AWN[variant]
    nS, nL = 10, 4
    xs = [-w / 2 + w * i / nS for i in range(nS + 1)]

    def pt(i, k):
        t = k / nL
        sag = 0.05 * math.sin(math.pi * t) + 0.035 * math.sin(math.pi * (xs[i] + w / 2) / w * 5) * (0.4 + t)
        return (xs[i], y0 + (y1 - y0) * t - sag, z0 + (z1 - z0) * t)
    for i in range(nS):
        col = cA if i % 2 == 0 else cB
        for k in range(nL):
            a, b, c, d = pt(i, k), pt(i + 1, k), pt(i + 1, k + 1), pt(i, k + 1)
            cen = ((a[0] + c[0]) / 2, (a[1] + c[1]) / 2 - 0.4, (a[2] + c[2]) / 2)
            quad(p, [a, b, c, d], col, CLOTH, out=cen)
            under = [(q[0], q[1] - 0.012, q[2]) for q in (a, b, c, d)]
            cen2 = (cen[0], cen[1] + 0.8, cen[2])
            quad(p, under, (col[0] * 0.6, col[1] * 0.6, col[2] * 0.6), CLOTH, out=cen2)
    # the scalloped valance along the front edge, in the same stripes
    for i in range(nS):
        col = cA if i % 2 == 0 else cB
        a, b = pt(i, nL), pt(i + 1, nL)
        xm = (a[0] + b[0]) / 2
        dz = 0.03
        poly = [(a[0], a[1], a[2]), (b[0], b[1], b[2]), (b[0], b[1] - 0.16, b[2] + dz), (xm, a[1] - 0.3, a[2] + dz * 1.6), (a[0], a[1] - 0.16, a[2] + dz)]
        quad(p, poly, col, CLOTH, out=(xm, a[1] - 0.1, a[2] - 0.6))
        quad(p, [q for q in poly[::-1]], (col[0] * 0.6, col[1] * 0.6, col[2] * 0.6), CLOTH, out=(xm, a[1] - 0.1, a[2] + 0.6))
    # the ribs: poles under the cloth
    for x in (-1.45, 0.0, 1.45):
        beam_between(p, V(x, y0 - 0.3, z0 + 0.1), V(x, y1 - 0.3, z1 - 0.3), 0.04, tone="grey")


def build_stall(variant):
    p = P(70 + variant)
    rng = p.rng
    for sx in (-1.42, 1.42):
        box(p, V(sx, 1.08, 0.86), (0.1, 2.16, 0.1), tone="dark", jit=0.003, omit=('-y',))
        box(p, V(sx, 1.38, -0.86), (0.1, 2.76, 0.1), tone="dark", jit=0.003, omit=('-y',))
        beam_between(p, V(sx, 2.78, -0.86), V(sx, 2.18, 0.86), 0.075, tone="grey", jit=0.002)
        beam_between(p, V(sx, 1.95, 0.86), V(sx, 2.2, 0.55), 0.05, tone="grey")        # a bracket at the front post
    box(p, V(0, 2.14, 0.86), (2.95, 0.09, 0.1), tone="grey", jit=0.003)
    box(p, V(0, 2.76, -0.86), (2.95, 0.09, 0.1), tone="grey", jit=0.003)
    # the plank back
    for i in range(15):
        x = -1.4 + 0.2 * i
        h = 2.0 + rng.uniform(-0.05, 0.1)
        box(p, V(x, h / 2 + 0.04, -0.86), (0.19, h, 0.035), tone="grey" if i % 3 else "pale", jit=0.003, omit=('-y',))
    for y in (0.55, 1.45):
        box(p, V(0, y, -0.82), (2.95, 0.08, 0.04), tone="dark", jit=0.002)
    # the counter: a front of boards, a top that overhangs, a lower shelf
    box(p, V(0, 0.92, 0.5), (3.02, 0.06, 0.82), tone="pale", jit=0.003)
    box(p, V(0, 0.07, 0.5), (2.9, 0.05, 0.68), tone="dark")
    for i in range(9):
        x = -1.28 + 0.32 * i
        box(p, V(x, 0.46, 0.9), (0.31, 0.86, 0.04), tone="mid" if i % 2 else "grey", jit=0.003, omit=('-y',))
    for sx in (-1, 1):
        box(p, V(sx * 1.46, 0.46, 0.55), (0.04, 0.86, 0.72), tone="dark")
    box(p, V(0, 0.32, 0.5), (2.9, 0.04, 0.7), tone="grey")
    for sx in (-1.0, 1.0):
        nail(p, V(sx * 1.2, 0.95, 0.9), V(0, 0, 1))
    box(p, V(0, 1.18, -0.64), (2.9, 0.05, 0.4), tone="mid", jit=0.002)                # a shelf along the back
    for sx in (-1.3, 0.0, 1.3):
        beam_between(p, V(sx, 1.0, -0.84), V(sx, 1.16, -0.5), 0.04, tone="dark")
    awning(p, variant)
    if variant == 0:                                              # produce
        fruit = [(0.9, 0.22, 0.14), (0.95, 0.5, 0.16), (0.55, 0.75, 0.25), (0.9, 0.3, 0.2)]
        for i, x in enumerate((-1.0, -0.35, 0.3)):
            crate_of(p, V(x, 0.95, 0.5), rng.uniform(-0.2, 0.2), [fruit[(i + j) % 4] for j in range(3)])
        crate_of(p, V(0.95, 0.95, 0.5), 0.15, [fruit[2], fruit[3]])
        sack_at(p, V(-1.1, 0.0, -0.45), 1.0, 0.3)
        sack_at(p, V(-0.65, 0.0, -0.55), 0.9, -0.2)
        sack_at(p, V(1.05, 0.0, -0.4), 1.0, 0.6)
        for i in range(5):                                        # plaited garlic on the front beam
            x = -0.5 + 0.25 * i
            beam_between(p, V(x, 2.1, 0.86), V(x, 1.66, 0.86), 0.012, tone="dark")
            blob(p, V(x, 1.58, 0.86), (0.07, 0.09, 0.07), (1.0, 0.96, 0.84), CLOTH, 6, 4)
    elif variant == 1:                                            # pots
        beam_between(p, V(-1.4, 2.3, 0.0), V(1.4, 2.3, 0.0), 0.04, tone="dark")
        for i in range(7):
            x = -1.2 + 0.4 * i
            hh = 0.22 + 0.1 * (i % 3)
            beam_between(p, V(x, 2.3, 0.0), V(x, 2.3 - hh, 0.0), 0.014, kind=IRON)
            blob(p, V(x, 2.3 - hh - 0.12, 0.0), (0.13, 0.11, 0.13), (0.45, 0.4, 0.38) if i % 2 else (0.7, 0.45, 0.28), IRON, 8, 5)
            box(p, V(x, 2.3 - hh - 0.01, 0.0), (0.17, 0.02, 0.17), kind=IRON)
        for i, x in enumerate((-1.1, -0.55)):                     # jugs
            blob(p, V(x, 1.08, 0.5), (0.13, 0.16, 0.13), (1.0, 0.9, 0.78), CLOTH, 8, 5)
            prism(p, 8, 0.05, 1.2, 1.31, (x, 0.5), kind=WOOD, col=(0.7, 0.55, 0.42))
        for i, x in enumerate((0.0, 0.5)):
            blob(p, V(x, 1.04, 0.45), (0.2, 0.1, 0.2), (0.75, 0.42, 0.26), IRON, 8, 4)
        # a barrel on the right of the counter, on the ground
        prism(p, 10, 0.27, 0.0, 0.5, (1.1, 0.35), kind=WOOD, r1=0.33, col=p.wood("mid"), caps=(True, False))
        prism(p, 10, 0.33, 0.5, 0.95, (1.1, 0.35), kind=WOOD, r1=0.27, col=p.wood("mid"), caps=(False, True))
        for y in (0.15, 0.8):
            prism(p, 10, 0.3 if y < 0.5 else 0.3, y, y + 0.05, (1.1, 0.35), kind=IRON, r1=0.3, caps=(False, False))
        crate_of(p, V(-1.0, 0.0, 0.45), 0.3, [(0.55, 0.45, 0.2)])
    else:                                                         # cloth and herbs
        cols = [(0.7, 0.18, 0.2), (0.2, 0.32, 0.55), (0.9, 0.78, 0.4), (0.3, 0.5, 0.3), (0.55, 0.3, 0.5)]
        for i in range(5):
            x = -1.15 + 0.5 * i
            yy = 0.97 if i < 3 else 1.3
            zz = 0.5 if i < 3 else -0.62
            ln = 0.6
            n = 8
            for k in range(n):
                a0, a1 = 2 * math.pi * k / n, 2 * math.pi * (k + 1) / n
                r = 0.1
                pts = [(x - ln / 2, yy + 0.1 + r * math.sin(a0), zz + r * math.cos(a0)), (x + ln / 2, yy + 0.1 + r * math.sin(a0), zz + r * math.cos(a0)),
                       (x + ln / 2, yy + 0.1 + r * math.sin(a1), zz + r * math.cos(a1)), (x - ln / 2, yy + 0.1 + r * math.sin(a1), zz + r * math.cos(a1))]
                quad(p, pts, cols[i], CLOTH, out=(x, yy + 0.1, zz))
            for cap in (-1, 1):
                pp = [(x + cap * ln / 2, yy + 0.1 + 0.1 * math.sin(2 * math.pi * k / n), zz + 0.1 * math.cos(2 * math.pi * k / n)) for k in range(n)]
                quad(p, pp, (cols[i][0] * 0.8, cols[i][1] * 0.8, cols[i][2] * 0.8), CLOTH, out=(x, yy + 0.1, zz))
        for i in range(3):                                        # folded cloth stacks on the counter
            for j in range(4):
                box(p, V(0.9 + 0.0, 0.97 + 0.06 * j, 0.45 + 0.0), (0.6 - 0.02 * j, 0.055, 0.38), R=rotm(0.1 * j), kind=CLOTH, col=cols[(j + 1) % 5], jit=0.003)
        for i in range(6):                                        # herb bundles drying on the front beam
            x = -1.2 + 0.4 * i
            beam_between(p, V(x, 2.12, 0.86), V(x, 1.72, 0.86), 0.012, tone="dark")
            for k in range(4):
                prism(p, 5, 0.025, 1.4 + 0.0, 1.72, (x + (k - 1.5) * 0.015, 0.86), kind=CLOTH, r1=0.09 + 0.02 * k, col=(0.4, 0.6, 0.3) if i % 2 else (0.55, 0.4, 0.55), caps=(False, False))
        # a lantern cage hung from the front-left bracket
        beam_between(p, V(-1.42, 2.0, 0.9), V(-1.18, 2.0, 1.12), 0.035, tone="dark")
        beam_between(p, V(-1.18, 2.0, 1.12), V(-1.18, 1.82, 1.12), 0.012, kind=IRON)
        for sx, sz in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
            beam_between(p, V(-1.18 + sx * 0.055, 1.56, 1.12 + sz * 0.055), V(-1.18 + sx * 0.055, 1.82, 1.12 + sz * 0.055), 0.012, kind=IRON)
        box(p, V(-1.18, 1.52, 1.12), (0.14, 0.02, 0.14), kind=IRON)
        prism(p, 4, 0.1, 1.82, 1.88, (-1.18, 1.12), kind=IRON, r1=0.02, rot=math.pi / 4, col=p.iron())
    return finish(p, "market_stall_" + "abc"[variant], (V(0, 0.5, 0.5), (3.0, 1.0, 0.85)))


# --- the market cross -------------------------------------------------------------------------------------
def build_cross():
    p = P(81)
    rot = math.pi / 8
    h = 0.0
    for i, (r, t) in enumerate(((2.15, 0.27), (1.72, 0.27), (1.32, 0.27))):
        prism(p, 8, r, h, h + t, kind=STONE, rot=rot, tone="mid" if i != 1 else "pale")
        h += t
    # the pedestal: an octagonal block with a chamfered foot and shoulder
    prism(p, 8, 0.82, h, h + 0.16, kind=ASHLAR, rot=rot, r1=0.66)
    prism(p, 8, 0.66, h + 0.16, h + 0.95, kind=ASHLAR, rot=rot, tone="pale")
    prism(p, 8, 0.66, h + 0.95, h + 1.08, kind=ASHLAR, rot=rot, r1=0.76)
    base = h + 1.08
    # the shaft: eight faces, tapering, with a banded middle
    prism(p, 8, 0.4, base, base + 0.35, kind=ASHLAR, rot=rot, r1=0.34)
    prism(p, 8, 0.34, base + 0.35, base + 1.9, kind=ASHLAR, rot=rot, r1=0.27, tone="pale")
    prism(p, 8, 0.38, base + 1.1, base + 1.22, kind=ASHLAR, rot=rot, r1=0.38)           # a banded ring
    prism(p, 8, 0.27, base + 1.9, base + 2.05, kind=ASHLAR, rot=rot, r1=0.36)
    top = base + 2.05
    # the capital: a knop with four little brackets
    prism(p, 8, 0.36, top, top + 0.22, kind=ASHLAR, rot=rot, r1=0.4, tone="pale")
    for k in range(4):
        a = k * math.pi / 2
        beam_between(p, V(0.4 * math.cos(a), top + 0.04, 0.4 * math.sin(a)), V(0.5 * math.cos(a), top + 0.3, 0.5 * math.sin(a)), 0.1, kind=ASHLAR, col=stone_col(p))
    prism(p, 8, 0.44, top + 0.22, top + 0.34, kind=ASHLAR, rot=rot)
    # the head: a ringed cross, set square on the capital
    cy = top + 0.34
    for sx in (-1, 1):
        box(p, V(0, cy + 0.5, 0), (0.2, 1.0, 0.2), kind=ASHLAR, col=stone_col(p), omit=('-y',))
    box(p, V(0, cy + 0.62, 0), (0.2, 0.2, 0.2), kind=ASHLAR, col=stone_col(p, "pale"))
    box(p, V(0, cy + 0.98, 0), (0.2, 0.54, 0.2), kind=ASHLAR, col=stone_col(p))
    box(p, V(0, cy + 0.74, 0), (1.0, 0.2, 0.2), kind=ASHLAR, col=stone_col(p))
    n = 20
    c = V(0, cy + 0.74, 0)
    for i in range(n):                                            # the ring through the arms: short square-section beams
        a0, a1 = 2 * math.pi * i / n, 2 * math.pi * (i + 1) / n
        beam_between(p, c + V(0.4 * math.cos(a0), 0.4 * math.sin(a0), 0), c + V(0.4 * math.cos(a1), 0.4 * math.sin(a1), 0), 0.13,
                     kind=ASHLAR, col=stone_col(p, "pale"))
    # an iron hoop for a lantern, under the capital
    return finish(p, "market_cross", (V(0, 1.2, 0), (4.0, 2.4, 4.0)))


# --- the gate ---------------------------------------------------------------------------------------------
def build_gate():
    p = P(91)
    rng = p.rng
    px, pz, ph = 2.7, 1.45, 3.75                                   # post line, post depth line, wall plate height
    for sx in (-px, px):
        for sz in (-pz, pz):
            prism(p, 4, 0.62, 0.0, 0.42, (sx, sz), kind=STONE, rot=math.pi / 4, r1=0.55, tone="dark")      # footing
            box(p, V(sx, ph / 2 + 0.2, sz), (0.46, ph - 0.0, 0.46), tone="dark", jit=0.004, omit=('-y',))
            box(p, V(sx, 0.9, sz), (0.52, 0.12, 0.52), tone="grey")                                         # a ring of iron at the foot
            box(p, V(sx, ph - 0.1, sz), (0.54, 0.16, 0.54), tone="grey")                                    # a cap block
    # tie beams across the road at each end, a plate along each side
    for sz in (-pz, pz):
        box(p, V(0, ph + 0.12, sz), (2 * px + 0.9, 0.34, 0.4), tone="dark", jit=0.004)
        # curved-ish braces: straight diagonals from the posts to the tie beam
        for sx in (-1, 1):
            beam_between(p, V(sx * px, ph - 1.1, sz + (-0.1 if sz > 0 else 0.1) * 0), V(sx * (px - 1.15), ph - 0.06, sz), 0.2, tone="mid", jit=0.003)
    for sx in (-px, px):
        box(p, V(sx, ph + 0.12, 0), (0.4, 0.34, 2 * pz + 0.9), tone="dark", jit=0.004)
        # the side rail and the seat inside it, between the posts
        box(p, V(sx, 1.08, 0), (0.12, 0.14, 2 * pz - 0.46), tone="mid")
        box(p, V(sx, 0.52, 0), (0.12, 0.12, 2 * pz - 0.46), tone="grey")
        for z in (-0.7, 0.0, 0.7):
            box(p, V(sx, 0.8, z), (0.1, 0.62, 0.1), tone="dark")
        sd = 1 if sx < 0 else -1                                   # the seat reaches inward
        box(p, V(sx + sd * 0.3, 0.5, 0), (0.55, 0.07, 2 * pz - 0.5), tone="pale", jit=0.003)
        for z in (-1.0, 1.0):
            box(p, V(sx + sd * 0.3, 0.24, z), (0.5, 0.48, 0.09), tone="dark")
    # the roof frame: a king post and rafters over each end truss, purlins between
    ridge = ph + 1.75
    ex_, ey_ = px + 0.95, ph
    for sz in (-pz, pz):
        box(p, V(0, ph + 0.6, sz), (0.2, 1.3, 0.2), tone="dark")                          # king post
        for sx in (-1, 1):
            beam_between(p, V(sx * (ex_ - 0.1), ey_ - 0.2, sz), V(0, ridge - 0.2, sz), 0.15, tone="mid", jit=0.003)
            beam_between(p, V(sx * 1.4, ph + 0.15, sz), V(0, ph + 0.78, sz), 0.1, tone="grey")
    box(p, V(0, ridge, 0), (0.22, 0.2, 2 * pz + 1.8), tone="dark")                          # ridge pole
    # the slate roof: two slopes, with courses, overhanging the ends and sides
    zo = pz + 0.9
    ex = px + 0.95
    ey = ph + 0.0
    ncs = 9
    for sx in (-1, 1):
        for c in range(ncs):
            t0, t1 = c / ncs, (c + 1) / ncs
            xa, ya = sx * (ex - (ex) * t0), ey + (ridge + 0.06 - ey) * t0
            xb, yb = sx * (ex - (ex) * t1), ey + (ridge + 0.06 - ey) * t1
            for k in range(6):
                z0, z1 = -zo + 2 * zo * k / 6, -zo + 2 * zo * (k + 1) / 6
                col = stone_col(p, "dark")
                col = (col[0] * 0.8, col[1] * 0.8, col[2] * 0.85)
                a, b, cc, d = (xa, ya, z0), (xa, ya, z1), (xb, yb, z1), (xb, yb, z0)
                quad(p, [a, b, cc, d], col, SLATE, out=((xa + xb) / 2, (ya + yb) / 2 - 0.6, (z0 + z1) / 2))
                under = [(q[0], q[1] - 0.045, q[2]) for q in (a, b, cc, d)]
                quad(p, under, (0.25, 0.22, 0.2), DARK, out=((xa + xb) / 2, (ya + yb) / 2 + 0.6, (z0 + z1) / 2))
        # a slate edge board along the eave
        box(p, V(sx * ex, ey - 0.02, 0), (0.05, 0.12, 2 * zo), tone="dark")
        for z in (-zo, zo):                                       # barge boards on the gable ends
            beam_between(p, V(sx * ex, ey - 0.02, z), V(0, ridge + 0.04, z), 0.1, tone="grey", jit=0.002)
    # a lantern cage hung in the middle of the vault, on a chain
    beam_between(p, V(0, ph + 0.78, 0), V(0, ph - 0.28, 0), 0.02, kind=IRON)
    for sx, sz in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
        beam_between(p, V(sx * 0.13, ph - 0.78, sz * 0.13), V(sx * 0.13, ph - 0.3, sz * 0.13), 0.025, kind=IRON)
        beam_between(p, V(sx * 0.13, ph - 0.78, sz * 0.13), V(0, ph - 0.28, 0), 0.015, kind=IRON)
    box(p, V(0, ph - 0.82, 0), (0.34, 0.04, 0.34), kind=IRON)
    box(p, V(0, ph - 0.75, 0), (0.1, 0.1, 0.1), kind=IRON)
    return finish(p, "village_gate", (V(0, 2.0, 0), (2 * px + 0.5, 4.0, 2 * pz + 0.5)))


# --- the walls, rails and lines ----------------------------------------------------------------------------
def build_wall(pier=False):
    p = P(101 if not pier else 102)
    rng = p.rng
    if pier:
        box(p, V(0, 0.15, 0), (0.92, 0.3, 0.92), kind=STONE, col=stone_col(p, "dark"), jit=0.006)
        h = 0.3
        for i, (w, t) in enumerate(((0.8, 0.32), (0.78, 0.3), (0.8, 0.32), (0.76, 0.3))):
            box(p, V(rng.uniform(-0.01, 0.01), h + t / 2, rng.uniform(-0.01, 0.01)), (w, t, w), R=rotm(rng.uniform(-0.04, 0.04)), kind=STONE, col=stone_col(p), jit=0.008)
            h += t
        box(p, V(0, h + 0.07, 0), (0.98, 0.14, 0.98), kind=ASHLAR, col=stone_col(p, "pale"), jit=0.004)
        prism(p, 4, 0.36, h + 0.14, h + 0.5, (0, 0), kind=ASHLAR, rot=math.pi / 4, r1=0.04, col=stone_col(p, "pale"))
        return finish(p, "wall_pier", (V(0, 0.95, 0), (0.95, 1.9, 0.95)))
    h = 0.0
    courses = [0.34, 0.3, 0.28, 0.26]
    for ci, ch in enumerate(courses):
        x = -1.5
        while x < 1.5 - 0.05:
            ln = min(rng.uniform(0.5, 0.95), 1.5 - x)
            if 1.5 - (x + ln) < 0.3:
                ln = 1.5 - x
            tk = 0.56 - 0.04 * ci + rng.uniform(-0.012, 0.012)
            box(p, V(x + ln / 2, h + ch / 2 - 0.0, rng.uniform(-0.012, 0.012)), (ln - 0.03, ch - 0.02 + rng.uniform(-0.01, 0.01), tk),
                kind=STONE, col=stone_col(p, "dark" if ci == 0 else "mid"), jit=0.007)
            x += ln
        h += ch
    # the coping: long flat slabs
    x = -1.5
    while x < 1.5 - 0.05:
        ln = min(rng.uniform(0.8, 1.1), 1.5 - x) if 1.5 - x > 1.2 else 1.5 - x
        box(p, V(x + ln / 2, h + 0.06, 0), (ln - 0.025, 0.12, 0.66), kind=ASHLAR, col=stone_col(p, "pale"), jit=0.004, R=rotm(0, 0, rng.uniform(-0.01, 0.01)))
        x += ln
    return finish(p, "wall_low", (V(0, 0.6, 0), (3.0, 1.2, 0.62)))


def build_hitch():
    p = P(111)
    for sx in (-1.0, 1.0):
        box(p, V(sx, 0.62, 0), (0.17, 1.25, 0.17), tone="dark", jit=0.006, omit=('-y',), R=rotm(0, 0, -sx * 0.02))
        box(p, V(sx, 1.26, 0), (0.2, 0.06, 0.2), tone="grey", jit=0.003)
    box(p, V(0, 1.02, 0), (2.18, 0.11, 0.1), tone="mid", jit=0.004)
    box(p, V(0, 0.62, 0), (2.05, 0.08, 0.09), tone="grey", jit=0.004)
    for x in (-0.55, 0.15, 0.7):
        prism(p, 8, 0.07, 0.86, 0.9, (x, 0.07), kind=IRON, caps=(True, True), col=p.iron())
        beam_between(p, V(x, 1.0, 0.04), V(x, 0.9, 0.07), 0.015, kind=IRON)
    return finish(p, "hitch_rail", (V(0, 0.62, 0), (2.4, 1.25, 0.3)))


def line_y(x):
    """The line's height at x: a rope between two hooks, sagging in the middle."""
    return 2.34 - 0.21 * (1.0 - (x / 2.4) ** 2)


def cloth_hang(p, x0, x1, drop, col, kind=CLOTH, folds=4.0, phase=0.0, amp=0.07, sway=0.0, thick=0.012, hem=0.05,
               narrow=0.05, z0=0.0, shade=0.18):
    """A piece of cloth hung over the line: a front and a back layer meeting over the rope, a hem and
    side edges that close its thickness. Folds run down it (sines across the width, deeper toward the hem), the hem
    is uneven and the piece narrows and sways as it hangs. Metres, line along x."""
    nx, ny = 14, 8
    xc = (x0 + x1) / 2

    def pt(u, v, side, sd):
        x = x0 + (x1 - x0) * u
        top = line_y(x) + 0.026
        lowest = 1.0 + hem * math.sin(5.1 * u + phase * 2.0) + 0.5 * hem * math.sin(11.0 * u + phase)
        y = top - drop * v * lowest
        x = xc + (x - xc) * (1.0 - narrow * v) + sway * v * v
        fold = amp * math.sin(2 * math.pi * folds * u + phase + 1.3 * v) * (0.25 + 0.75 * v) \
            + 0.5 * amp * math.sin(2 * math.pi * folds * 1.9 * u + 2.0 * phase) * v * v
        z = z0 + side * (thick + 0.012 * v) * min(1.0, v * 6.0) + fold * (1.0 if side > 0 else 0.85) + sd * v ** 1.6 * 0.04
        return (x, y, z)

    def tone_of(u, v, side):
        f = math.sin(2 * math.pi * folds * u + phase + 1.3 * v) * (0.25 + 0.75 * v)
        k = 1.0 - shade * (0.5 - 0.5 * f) - 0.05 * v * (0.5 if side > 0 else 1.0)
        return (col[0] * k, col[1] * k, col[2] * k)

    grid = {}
    for side in (1, -1):
        for ix in range(nx + 1):
            for iy in range(ny + 1):
                u, v = ix / nx, iy / ny
                if side < 0 and iy == 0:
                    grid[(side, ix, iy)] = grid[(1, ix, 0)]          # the two layers meet at the crown, over the rope
                    continue
                grid[(side, ix, iy)] = (p.vt(V(*pt(u, v, side, 0.0))), tone_of(u, v, side))
    mid = V(xc, line_y(xc) - drop * 0.5, z0)
    for side in (1, -1):
        for ix in range(nx):
            for iy in range(ny):
                q = [grid[(side, ix, iy)], grid[(side, ix + 1, iy)], grid[(side, ix + 1, iy + 1)], grid[(side, ix, iy + 1)]]
                p.fc([c[0] for c in q], [c[1] for c in q], kind, True, out=mid)
    # the hem, the two side edges
    for ix in range(nx):
        q = [grid[(1, ix, ny)], grid[(1, ix + 1, ny)], grid[(-1, ix + 1, ny)], grid[(-1, ix, ny)]]
        p.fc([c[0] for c in q], [c[1] for c in q], kind, False, out=mid)
    for ix in (0, nx):
        for iy in range(ny):
            q = [grid[(1, ix, iy)], grid[(1, ix, iy + 1)], grid[(-1, ix, iy + 1)], grid[(-1, ix, iy)]]
            if iy == 0:
                q = q[:3]                                   # the crown is one row: a triangle
            p.fc([c[0] for c in q], [c[1] for c in q], kind, False, out=mid)


def peg(p, x, side_x=0.0):
    box(p, V(x, line_y(x) - 0.02, 0.0), (0.03, 0.09, 0.06), tone="pale")


def build_line():
    p = P(121)
    # two poles: tapering, one leaning, each with a notched top and a hook; a forked prop propping the line
    for sx, lean in ((-2.4, 0.03), (2.4, -0.015)):
        box(p, V(sx, 1.25, 0), (0.12, 2.5, 0.12), tone="dark", jit=0.006, omit=('-y',), taper=(0.78, 0.78), R=rotm(0, 0, -lean))
        box(p, V(sx, 2.46, 0), (0.17, 0.06, 0.09), tone="grey")
        box(p, V(sx + (0.05 if sx < 0 else -0.05), 2.38, 0.0), (0.03, 0.12, 0.03), kind=IRON, col=p.iron())
    beam_between(p, V(0.35, 0.0, 0.1), V(0.12, 2.04, 0.012), 0.05, tone="mid", jit=0.004)
    for sg in (-1.0, 1.0):
        beam_between(p, V(0.12, 1.98, 0.012), V(0.12 + sg * 0.1, 2.17, 0.012), 0.032, tone="mid")
    # the rope: a sagging curve in short runs, with a knot at each pole
    n = 24
    pts = [(-2.4 + 4.8 * i / n, line_y(-2.4 + 4.8 * i / n)) for i in range(n + 1)]
    for i in range(n):
        beam_between(p, V(pts[i][0], pts[i][1], 0), V(pts[i + 1][0], pts[i + 1][1], 0), 0.018, kind=IRON, col=(0.72, 0.62, 0.5))
    # laundry (a pale linen sheet on the pale daub set (the tiled cloth set is mustard: a cream tone on it read mustard in the night, since the grade warms a cream); madder shirt, indigo trousers, a faded sage sheet, a small linen cloth)
    cloth_hang(p, -2.05, -0.82, 1.28, (0.8, 0.84, 0.9), kind=CLAY, folds=3.0, phase=0.4, amp=0.08, sway=-0.03)
    cloth_hang(p, -0.64, -0.06, 0.82, (0.82, 0.36, 0.32), folds=2.0, phase=1.7, amp=0.06, narrow=0.10, z0=0.01)
    for sg in (-1.0, 1.0):                           # the shirt's sleeves: hung from its shoulders, cuffs out
        xs = -0.35 + sg * 0.36
        cloth_hang(p, xs - 0.08, xs + 0.08, 0.5, (0.8, 0.34, 0.3), folds=1.0, phase=0.6 + sg, amp=0.02, sway=sg * 0.07, narrow=0.05, z0=0.02, shade=0.14)
    for xs in (0.18, 0.40):                          # trousers: two legs on one peg
        cloth_hang(p, xs - 0.09, xs + 0.09, 0.95, (0.42, 0.5, 0.68), folds=1.0, phase=0.3 + xs * 3, amp=0.025, narrow=0.18, z0=0.0, shade=0.14)
    cloth_hang(p, 0.78, 2.0, 1.05, (0.6, 0.72, 0.62), folds=3.0, phase=2.4, amp=0.085, sway=0.05, narrow=0.06, z0=-0.01)
    cloth_hang(p, 2.12, 2.36, 0.42, (0.78, 0.82, 0.88), kind=CLAY, folds=1.0, phase=0.2, amp=0.025, narrow=0.1, z0=0.0)
    for x in (-2.05, -0.82, -0.64, -0.06, 0.09, 0.27, 0.78, 2.0, 2.12, 2.36):
        peg(p, x)
    # a basket under the line, with folded laundry piled in it
    prism(p, 10, 0.26, 0.0, 0.3, (-0.2, 0.7), kind=WOOD, r1=0.32, col=p.wood("pale"), caps=(True, False))
    cols = [(1.0, 0.96, 0.88), (0.82, 0.4, 0.34), (0.5, 0.58, 0.72), (0.9, 0.82, 0.62)]
    for k in range(4):
        blob(p, V(-0.2 + 0.1 * (k - 1.5), 0.31, 0.7 + 0.03 * (k % 2)), (0.11, 0.07, 0.1), cols[k], CLOTH, 6, 3)
    return finish(p, "washing_line", (V(0, 1.3, 0), (5.0, 2.6, 0.4)))


MODELS = [
    ("market_stall_a", lambda: build_stall(0), V(0, 1.2, 0.7)),
    ("market_stall_b", lambda: build_stall(1), V(0, 1.2, 0.7)),
    ("market_stall_c", lambda: build_stall(2), V(0, 1.2, 0.7)),
    ("market_cross", build_cross, V(0, 2.4, 0)),
    ("village_gate", build_gate, V(0, 3.6, 0)),
    ("wall_low", lambda: build_wall(False), V(0, 0.6, 0)),
    ("wall_pier", lambda: build_wall(True), V(0, 1.0, 0)),
    ("hitch_rail", build_hitch, V(0, 0.8, 0)),
    ("washing_line", build_line, V(0, 1.6, 0)),
]

for name, fn, focus in MODELS:
    if ONLY and name not in ONLY:
        continue
    reset()
    ns["MERGE"].clear()
    ns["INDOOR"] = False
    if name in ("hitch_rail", "wall_low", "wall_pier", "village_gate"):
        ns["MERGE"]["iron"] = "timber" if name != "village_gate" else "iron"
    vis, col = fn()
    export(vis + [col], os.path.join(OUT, name + ".glb"))
    lo, hi = bounds(vis)
    print("PROP %-16s tris %5d  size x %.2f..%.2f  y %.2f..%.2f  z %.2f..%.2f" % (name, tri_count(vis), lo.x, hi.x, lo.y, hi.y, lo.z, hi.z))
    if PREVIEW:
        col.hide_render = True
        render_set(vis, name, focus)
