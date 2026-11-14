"""Hearthward's four old code-built pieces, modelled at the village's scale (r38, critique finding 15).

  tools/blender/run.sh props_hearth.py -- [--only hw_well,hw_notice,hw_shrine,hw_forge] [--preview DIR]

The house style of props_market.py (this runs that file's helpers, minus its model loop): `<part>__<set>` meshes
with metric UVs, vertex colour as a TONE multiplier only, pivot at the base centre, Godot metres, y up. The
pieces are drawn at the size they stand at (the cottages round them are 1.4-1.45x), so they are placed at scale 1.

  hw_well.glb     r 1.25 curb, 3.2 tall   a coursed stone curb with a coping and a plaque, two posts, a windlass with
                                          a crank, a gabled slate roof; no rope or bucket (the village mends those:
                                          core/life/village/village_props.gd well)
  hw_notice.glb   2.9 x 3.6 x 0.9         two posts on stone footings, a plank board in a frame with a little slate
                                          gable over it and a shelf; the front is -z
  hw_shrine.glb   4.2 x 4.6 x 3.0         a stepped plinth, two piers, a back slab and a gabled stone hood; the saint
                                          stands in it (lore_kit.gd saint), the front is -z
  hw_forge.glb    8.6 x 6.4 (6.4 tall)    Edda's lean-to: a stone plinth, a back wall, low side walls, front posts and a
                                          plate, a slate roof falling to the road, the hearth with its hood and chimney,
                                          bellows, an anvil on a stump, a quench trough, a grindstone, tool rack and bins;
                                          the open side is -z
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
src = open(os.path.join(HERE, "props_market.py")).read()
head, _, _tail = src.partition("MODELS = [")
lib = {"__name__": "props_market_lib", "__file__": os.path.join(HERE, "props_market.py")}
exec(compile(head, os.path.join(HERE, "props_market.py"), "exec"), lib)
ns = lib["ns"]                                      # props_square's namespace (tone tables, MERGE, INDOOR)

bpy = lib["bpy"]
P, box, ext, finish, export, reset, bounds, tri_count, nail = (lib[k] for k in ("P", "box", "ext", "finish", "export", "reset", "bounds", "tri_count", "nail"))
V, rotm, render_set = lib["V"], lib["rotm"], lib["render_set"]
quad, prism, stone_col, beam_between, blob = lib["quad"], lib["prism"], lib["stone_col"], lib["beam_between"], lib["blob"]
WOOD, IRON, GRAIN, DARK, STONE, ASHLAR, SLATE, CLOTH = (lib[k] for k in ("WOOD", "IRON", "GRAIN", "DARK", "STONE", "ASHLAR", "SLATE", "CLOTH"))
Vector = lib["Vector"]
OUT, PREVIEW, ONLY = lib["OUT"], lib["PREVIEW"], lib["ONLY"]


# --- helpers ---------------------------------------------------------------------------------------------
def lerp3(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def slate_plane(p, e0, e1, r0, r1, rows=8, cols=6, thick=0.06, dark=True, kind=SLATE, tone="dark"):
    """A slate slope: eave edge e0-e1 (low), ridge edge r0-r1 (high), laid in courses of slate with an underside."""
    mid = tuple((e0[i] + e1[i] + r0[i] + r1[i]) / 4 for i in range(3))
    u = Vector(e1) - Vector(e0)
    w = Vector(r0) - Vector(e0)
    nrm = u.cross(w).normalized()
    if nrm.y < 0:
        nrm = -nrm
    for r in range(rows):
        t0, t1 = r / rows, (r + 1) / rows
        a0, b0 = lerp3(e0, r0, t0), lerp3(e1, r1, t0)
        a1, b1 = lerp3(e0, r0, t1), lerp3(e1, r1, t1)
        for c in range(cols):
            s0, s1 = c / cols, (c + 1) / cols
            q = [lerp3(a0, b0, s0), lerp3(a0, b0, s1), lerp3(a1, b1, s1), lerp3(a1, b1, s0)]
            col = stone_col(p, tone)
            if kind == SLATE:
                col = (col[0] * 0.8, col[1] * 0.8, col[2] * 0.85)
            cen = tuple(sum(v[i] for v in q) / 4 for i in range(3))
            below = tuple(cen[i] - nrm[i] * 0.6 for i in range(3))
            quad(p, q, col, kind, out=below)
            if dark:
                under = [tuple(v[i] - nrm[i] * thick for i in range(3)) for v in q]
                quad(p, under, (0.25, 0.22, 0.2), DARK, out=tuple(cen[i] + nrm[i] * 0.6 for i in range(3)))


def wall_run(p, a, b, y0, y1, c, thick, course=0.3, kind=STONE, tone="mid", axis="x", jit=0.008):
    """Coursed rubble: blocks of random length from a to b along `axis` at c across, from y0 to y1, thick."""
    rng = p.rng
    y = y0
    ci = 0
    while y < y1 - 0.02:
        ch = min(course * rng.uniform(0.9, 1.1), y1 - y)
        x = a + (rng.uniform(0.0, 0.4) if ci % 2 else 0.0)
        first = True
        while x < b - 0.04:
            ln = min(rng.uniform(0.5, 1.0), b - x)
            if b - (x + ln) < 0.3:
                ln = b - x
            tk = thick * rng.uniform(0.94, 1.0)
            cx = x + ln / 2
            s = (ln - 0.03, ch - 0.02, tk) if axis == "x" else (tk, ch - 0.02, ln - 0.03)
            ctr = V(cx, y + ch / 2, c + rng.uniform(-0.012, 0.012)) if axis == "x" else V(c + rng.uniform(-0.012, 0.012), y + ch / 2, cx)
            box(p, ctr, s, kind=kind, col=stone_col(p, "dark" if ci == 0 else tone), jit=jit)
            x += ln
            first = False
        y += ch
        ci += 1


def curb_ring(p, r_out, r_in, y0, y1, n=14, course=0.3, rot=0.0):
    """A ring of dressed stones: n blocks a course, joints staggered, y0..y1."""
    rng = p.rng
    y = y0
    ci = 0
    step = 2 * math.pi / n
    while y < y1 - 0.02:
        ch = min(course, y1 - y)
        for i in range(n):
            a = rot + step * (i + (0.5 if ci % 2 else 0.0))
            rm = (r_out + r_in) / 2
            ctr = V(rm * math.cos(a), y + ch / 2, rm * math.sin(a))
            w = 2 * r_out * math.sin(step / 2) * 0.99
            box(p, ctr, (w, ch - 0.02, r_out - r_in), R=rotm(-a + math.pi / 2), kind=STONE, col=stone_col(p, "dark" if ci == 0 else "mid"), jit=0.008)
        y += ch
        ci += 1


def gable_roof(p, x0, x1, ze, ye, yr, ov=0.0, rows=7):
    """A gable along x: eaves at z = ±ze, y = ye; ridge y = yr, slate courses, ridge pole, barge boards."""
    for sg in (-1, 1):
        slate_plane(p, (x0, ye, sg * (ze + ov)), (x1, ye, sg * (ze + ov)), (x0, yr + 0.05, 0.0), (x1, yr + 0.05, 0.0), rows=rows, cols=max(4, int((x1 - x0) / 0.55)))
        box(p, V((x0 + x1) / 2, ye - 0.05, sg * (ze + ov)), (x1 - x0, 0.1, 0.07), tone="dark")
    box(p, V((x0 + x1) / 2, yr + 0.08, 0), (x1 - x0 + 0.1, 0.12, 0.2), kind=STONE, col=stone_col(p, "dark"), jit=0.004)
    for x in (x0, x1):
        for sg in (-1, 1):
            beam_between(p, V(x, ye - 0.04, sg * (ze + ov)), V(x, yr + 0.04, 0), 0.1, tone="grey", jit=0.002)


# --- the well ----------------------------------------------------------------------------------------------
def build_well():
    p = P(131)
    curb_ring(p, 1.26, 0.86, 0.0, 0.84, n=14, course=0.28)
    # the coping: a ring of long flat slabs
    n = 14
    for i in range(n):
        a = 2 * math.pi * (i + 0.5) / n
        rm = 1.08
        box(p, V(rm * math.cos(a), 0.9, rm * math.sin(a)), (0.62, 0.12, 0.62), R=rotm(-a + math.pi / 2), kind=ASHLAR, col=stone_col(p, "pale"), jit=0.005)
    # the dark of the shaft
    prism(p, 14, 0.9, 0.5, 0.52, (0, 0), kind=DARK, col=(0.05, 0.05, 0.05), caps=(True, True))
    # a plaque set into the curb's front (the village's inscription is laid over it)
    box(p, V(0, 0.64, -1.31), (0.78, 0.46, 0.08), kind=ASHLAR, col=stone_col(p, "pale"), jit=0.002)
    # posts on stone feet, a brace each way, the windlass between
    for sx in (-1.4, 1.4):
        box(p, V(sx, 0.12, 0), (0.5, 0.24, 0.5), kind=STONE, col=stone_col(p, "dark"), jit=0.004)
        box(p, V(sx, 1.35, 0), (0.22, 2.5, 0.22), tone="dark", jit=0.004, omit=('-y',))
        beam_between(p, V(sx, 1.55, 0.0), V(sx * 0.62, 2.45, 0.0), 0.12, tone="mid", jit=0.003)
        box(p, V(sx, 2.6, 0), (0.3, 0.14, 0.34), tone="grey")
    # the windlass: a drum with end collars and a crank on the east end
    for i in range(10):
        a0, a1 = 2 * math.pi * i / 10, 2 * math.pi * (i + 1) / 10
        for (xa, xb) in ((-1.38, 1.5),):
            ya0, za0 = 1.72 + 0.17 * math.sin(a0), 0.17 * math.cos(a0)
            ya1, za1 = 1.72 + 0.17 * math.sin(a1), 0.17 * math.cos(a1)
            quad(p, [(xa, ya0, za0), (xa, ya1, za1), (xb, ya1, za1), (xb, ya0, za0)], p.wood("mid"), WOOD, out=(0, 1.72, 0))
    for xc in (-0.5, 0.5):
        box(p, V(xc, 1.72, 0), (0.1, 0.46, 0.46), tone="grey", R=rotm(0, 0, 0))
    box(p, V(1.62, 1.72, 0.0), (0.14, 0.1, 0.1), kind=IRON, col=p.iron())
    beam_between(p, V(1.66, 1.72, 0.0), V(1.66, 1.72, 0.52), 0.07, kind=IRON, col=p.iron())
    beam_between(p, V(1.66, 1.72, 0.52), V(1.7, 1.72, 0.72), 0.09, tone="dark")
    # the roof: a gable over the well, along x, on a wall plate; tie beams and rafters under it
    for sz in (-1, 1):
        box(p, V(0, 2.56, sz * 1.0), (3.4, 0.18, 0.2), tone="dark", jit=0.004)
    for x in (-1.4, 0.0, 1.4):
        for sz in (-1, 1):
            beam_between(p, V(x, 2.55, sz * 1.0), V(x, 3.18, 0.0), 0.1, tone="mid", jit=0.003)
        box(p, V(x, 2.62, 0), (0.1, 0.12, 2.0), tone="dark")
    gable_roof(p, -1.95, 1.95, 1.25, 2.52, 3.35, ov=0.2, rows=7)
    return finish(p, "hw_well", (V(0, 1.6, 0), (3.2, 3.4, 2.6)))


# --- the notice board ---------------------------------------------------------------------------------------
def build_notice():
    p = P(141)
    for sx in (-1.15, 1.15):
        box(p, V(sx, 0.16, 0), (0.46, 0.32, 0.46), kind=STONE, col=stone_col(p, "dark"), jit=0.005)
        box(p, V(sx, 1.78, 0), (0.2, 3.0, 0.2), tone="dark", jit=0.004, omit=('-y',))
        box(p, V(sx, 3.3, 0), (0.28, 0.1, 0.28), tone="grey")
    # the board: planks in a frame, a lower shelf, a cross brace behind
    w, h, yc = 2.1, 1.5, 1.95
    for i in range(7):
        pw = w / 7
        box(p, V(-w / 2 + pw * (i + 0.5), yc, 0.0), (pw - 0.012, h, 0.07), tone=("dark" if i % 3 == 0 else "mid"), jit=0.004)
    for sy in (-1, 1):
        box(p, V(0, yc + sy * (h / 2 + 0.05), -0.03), (w + 0.24, 0.12, 0.12), tone="dark", jit=0.003)
    for sx in (-1, 1):
        box(p, V(sx * (w / 2 + 0.06), yc, -0.03), (0.12, h + 0.22, 0.12), tone="dark", jit=0.003)
    box(p, V(0, 1.1, -0.18), (1.9, 0.07, 0.34), tone="mid", jit=0.003)
    for sx in (-0.8, 0.8):
        beam_between(p, V(sx, 1.1, -0.34), V(sx * 1.2, 0.5, -0.02), 0.06, tone="dark")
    beam_between(p, V(-1.15, 0.6, 0.18), V(1.15, 1.35, 0.18), 0.09, tone="dark")
    # nails and a stray scrap of cord
    for (nx, ny) in ((-0.8, 2.45), (0.2, 2.5), (0.85, 2.4), (-0.3, 1.5), (0.6, 1.4)):
        nail(p, (nx, ny, -0.045), (0, 0, -1))
    # the little gable roof: a king post, two slopes, a ridge
    gable_roof(p, -1.7, 1.7, 0.62, 3.05, 3.62, ov=0.12, rows=4)
    for sx in (-1.15, 1.15):
        beam_between(p, V(sx, 3.0, -0.2), V(sx, 3.45, 0.0), 0.1, tone="mid")
        beam_between(p, V(sx, 3.0, 0.2), V(sx, 3.45, 0.0), 0.1, tone="mid")
    return finish(p, "hw_notice", (V(0, 1.8, 0), (2.9, 3.6, 0.9)))


# --- the shrine ---------------------------------------------------------------------------------------------
def build_shrine():
    p = P(151)
    # stepped plinth: two steps, the upper deeper toward the niche (front is -z)
    box(p, V(0, 0.25, 0), (3.5, 0.5, 2.9), kind=STONE, col=stone_col(p, "dark"), jit=0.006)
    box(p, V(0, 0.62, 0.15), (2.8, 0.24, 2.3), kind=ASHLAR, col=stone_col(p, "mid"), jit=0.004)
    box(p, V(0, 0.76, 0.15), (2.95, 0.07, 2.45), kind=ASHLAR, col=stone_col(p, "pale"), jit=0.002)
    wall_run(p, -1.25, 1.25, 0.8, 3.4, 1.0, 0.5, course=0.34, kind=STONE, tone="mid")        # the back slab, coursed
    for sx in (-1.12, 1.12):                                                                 # the piers
        wall_run(p, 0.2, 1.25, 0.8, 3.45, sx, 0.36, course=0.32, kind=STONE, tone="mid", axis="z")
        box(p, V(sx, 3.52, 0.72), (0.5, 0.12, 1.2), kind=ASHLAR, col=stone_col(p, "pale"), jit=0.003)
    # an arch over the niche: voussoirs between the piers
    n = 9
    rad_o, rad_i, cy = 1.1, 0.78, 3.5
    for i in range(n):
        a = math.pi * (i + 0.5) / n
        cx, cyy = -math.cos(a) * (rad_o + rad_i) / 2, cy + math.sin(a) * (rad_o + rad_i) / 2 * 0.62
        box(p, V(cx, cyy, 0.52), (0.34, 0.5, 0.5), R=rotm(0, 0, a - math.pi / 2), kind=ASHLAR, col=stone_col(p, "pale"), jit=0.004)
    # the hood: a stone gable over everything (ridge along z), a pediment on its front, a cornice
    for sg in (-1, 1):
        slate_plane(p, (sg * 1.55, 3.7, -0.55), (sg * 1.55, 3.7, 1.5), (0.0, 4.72, -0.55), (0.0, 4.72, 1.5), rows=5, cols=5, kind=ASHLAR, tone="mid", thick=0.14)
        box(p, V(sg * 1.5, 3.62, 0.48), (0.2, 0.16, 2.2), kind=ASHLAR, col=stone_col(p, "pale"), jit=0.003)
    box(p, V(0, 4.76, 0.48), (0.3, 0.14, 2.15), kind=ASHLAR, col=stone_col(p, "pale"), jit=0.003)
    ext(p, [(-1.4, 3.62), (1.4, 3.62), (0.0, 4.62)], 0.22, V(0, 0, -0.42), kind=ASHLAR, col=stone_col(p, "mid"), jit=0.002)
    box(p, V(0, 3.52, -0.4), (3.1, 0.2, 0.34), kind=ASHLAR, col=stone_col(p, "pale"), jit=0.003)
    # a cross cut over the niche, an offering shelf and ledge, iron candle spikes
    box(p, V(0, 4.1, -0.1), (0.1, 0.5, 0.06), kind=ASHLAR, col=stone_col(p, "dark"))
    box(p, V(0, 4.2, -0.1), (0.34, 0.09, 0.06), kind=ASHLAR, col=stone_col(p, "dark"))
    box(p, V(-1.15, 1.0, -0.38), (0.5, 0.1, 0.55), kind=ASHLAR, col=stone_col(p, "pale"), jit=0.003)
    box(p, V(1.15, 1.0, -0.38), (0.5, 0.1, 0.55), kind=ASHLAR, col=stone_col(p, "pale"), jit=0.003)
    for sx in (-1.15, 1.15):
        beam_between(p, V(sx, 1.06, -0.38), V(sx, 1.28, -0.38), 0.05, kind=IRON, col=p.iron())
    return finish(p, "hw_shrine", (V(0, 2.3, 0.2), (3.5, 4.6, 2.9)))


# --- Edda's forge -------------------------------------------------------------------------------------------
def build_forge():
    p = P(161)
    # the plinth: a stone slab that goes well below the ground on the low side
    box(p, V(0, -0.3, 0.0), (8.5, 0.8, 6.4), kind=STONE, col=stone_col(p, "dark"), jit=0.006)
    box(p, V(0, 0.03, 0.0), (8.3, 0.14, 6.2), kind=ASHLAR, col=stone_col(p, "mid"), jit=0.003, omit=('-y',))
    # the back (south) wall, coursed rubble to the roof's back edge, and the low side walls
    wall_run(p, -4.0, 4.0, 0.1, 4.9, 2.85, 0.62, course=0.34, kind=STONE, tone="mid")
    for sx in (-3.85, 3.85):
        wall_run(p, -0.4, 2.55, 0.1, 1.55, sx, 0.52, course=0.3, kind=STONE, tone="mid", axis="z")
        box(p, V(sx, 1.62, 1.07), (0.64, 0.1, 3.05), kind=ASHLAR, col=stone_col(p, "pale"), jit=0.003)
    # the front posts (on stone feet), tie beams to the back wall and the plate across
    for sx in (-3.85, -1.3, 1.3, 3.85):
        box(p, V(sx, 0.17, -2.75), (0.5, 0.3, 0.5), kind=STONE, col=stone_col(p, "dark"), jit=0.004)
        box(p, V(sx, 1.7, -2.75), (0.3, 3.2, 0.3), tone="dark", jit=0.004, omit=('-y',))
    for sx in (-3.85, 3.85):
        beam_between(p, V(sx, 2.0, -2.75), V(sx, 2.95, -1.6), 0.16, tone="mid", jit=0.003)
        beam_between(p, V(sx, 3.2, -2.75), V(sx, 4.6, 2.6), 0.2, tone="dark", jit=0.003)     # the side rafter, front to back
    box(p, V(0, 3.38, -2.75), (8.5, 0.32, 0.36), tone="dark", jit=0.004)                      # the plate
    for sx in (-2.6, 0.0, 2.6):
        beam_between(p, V(sx, 3.35, -2.75), V(sx, 4.75, 2.55), 0.16, tone="mid", jit=0.003)
    for sx in (-2.55, 2.55):
        beam_between(p, V(sx, 2.25, -2.75), V(sx * 0.95, 3.2, -2.2), 0.14, tone="mid")
    # the lean-to roof: slates falling toward the road (front), a facing board along the eave
    slate_plane(p, (-4.4, 3.48, -3.55), (4.4, 3.48, -3.55), (-4.4, 4.98, 3.1), (4.4, 4.98, 3.1), rows=11, cols=14, thick=0.07)
    box(p, V(0, 3.4, -3.55), (8.8, 0.16, 0.08), tone="dark")
    for sx in (-4.4, 4.4):
        beam_between(p, V(sx, 3.42, -3.55), V(sx, 5.0, 3.1), 0.1, tone="grey", jit=0.002)
    # the hearth against the back wall: masonry, a hood on two piers, the chimney through the roof
    hx, hz = -1.75, 1.75
    box(p, V(hx, 0.58, hz), (2.3, 1.1, 1.6), kind=STONE, col=stone_col(p, "mid"), jit=0.008)
    box(p, V(hx, 1.14, hz - 0.02), (2.4, 0.1, 1.7), kind=ASHLAR, col=stone_col(p, "pale"), jit=0.003)
    box(p, V(hx, 1.2, hz + 0.1), (1.3, 0.02, 0.9), kind=DARK, col=(0.08, 0.07, 0.07))                 # the coal bed is laid over this
    for sx in (-1.0, 1.0):
        box(p, V(hx + sx, 2.0, hz + 0.32), (0.38, 1.7, 0.9), kind=STONE, col=stone_col(p, "mid"), jit=0.008)
    box(p, V(hx, 2.95, hz + 0.28), (2.5, 0.42, 1.0), kind=ASHLAR, col=stone_col(p, "pale"), jit=0.004)
    prism(p, 4, 1.05, 3.16, 5.1, (hx, hz + 0.55), kind=STONE, rot=math.pi / 4, r1=0.55, tone="mid")   # the hood narrows
    prism(p, 4, 0.58, 5.1, 7.0, (hx, hz + 0.58), kind=STONE, rot=math.pi / 4, r1=0.52, tone="dark")  # the chimney
    prism(p, 4, 0.72, 7.0, 7.16, (hx, hz + 0.58), kind=ASHLAR, rot=math.pi / 4, col=stone_col(p, "pale"))
    # the tool rack on the back wall: a plank, hooks, tongs, hammers and a rasp
    box(p, V(1.5, 2.2, 2.5), (2.6, 0.22, 0.08), tone="dark", jit=0.003)
    for i, ln in enumerate((0.9, 0.7, 0.8, 0.55, 0.65)):
        x = 0.6 + 0.4 * i
        beam_between(p, V(x, 2.16, 2.46), V(x + 0.02, 2.16 - ln, 2.46), 0.04, kind=IRON, col=p.iron())
        beam_between(p, V(x, 2.16 - ln, 2.46), V(x + 0.07, 2.16 - ln - 0.1, 2.46), 0.07, kind=IRON, col=p.iron())
    # bellows on a frame beside the hearth: leather folds and a nozzle toward the fire
    bx, bz = -3.0, 0.6
    for sx in (-0.4, 0.4):
        box(p, V(bx + sx, 0.4, bz), (0.12, 0.8, 0.9), tone="dark")
    box(p, V(bx, 0.85, bz), (0.9, 0.12, 1.3), tone="mid", R=rotm(0.35, 0, 0))
    for k in range(5):
        t = k / 4
        blob(p, V(bx, 1.02 + 0.1 * (1 - t), bz + 0.5 - 0.7 * t), (0.46 - 0.12 * t, 0.16, 0.12), (0.5, 0.34, 0.26), CLOTH, 7, 4)
    beam_between(p, V(bx + 0.1, 1.05, bz + 0.55), V(hx - 0.65, 1.05, hz - 0.5), 0.1, kind=IRON, col=p.iron())
    # the anvil on its stump
    ax, az = 1.0, 0.25
    prism(p, 10, 0.43, 0.0, 0.78, (ax, az), kind=WOOD, col=p.wood("dark"), r1=0.4, caps=(False, True))
    box(p, V(ax, 0.84, az), (0.52, 0.1, 0.9), kind=IRON, col=p.iron())
    box(p, V(ax, 0.98, az), (0.3, 0.2, 0.62), kind=IRON, col=p.iron())
    box(p, V(ax, 1.15, az), (0.36, 0.13, 0.82), kind=IRON, col=(0.95, 0.92, 0.9))
    box(p, V(ax, 1.08, az - 0.62), (0.2, 0.1, 0.42), kind=IRON, col=p.iron(), taper=(0.35, 0.5))     # the horn
    # the quench trough: a stone box, dark water, a timber rim, an iron strap
    tx, tz = 2.75, 1.15
    box(p, V(tx, 0.4, tz), (0.96, 0.8, 2.0), kind=STONE, col=stone_col(p, "mid"), jit=0.006)
    box(p, V(tx, 0.74, tz), (0.74, 0.04, 1.78), kind=DARK, col=(0.04, 0.05, 0.06))
    box(p, V(tx, 0.84, tz), (1.04, 0.1, 2.08), kind=ASHLAR, col=stone_col(p, "pale"), jit=0.003)
    # the grindstone: two posts, a wheel on an axle, a crank, a water trough under it
    gx, gz = 3.0, -1.9
    for sz in (-0.3, 0.3):
        box(p, V(gx, 0.5, gz + sz), (0.1, 1.0, 0.1), tone="dark")
        box(p, V(gx, 0.14, gz + sz), (0.7, 0.1, 0.08), tone="dark")
    wh = []
    for i in range(16):
        a0 = 2 * math.pi * i / 16
        a1 = 2 * math.pi * (i + 1) / 16
        r = 0.46
        y0, y1 = 0.72, 0.72
        for (zz0, zz1) in ((-0.1, 0.1),):
            q = [(gx - 0.1, y0 + r * math.sin(a0), gz + r * math.cos(a0)), (gx - 0.1, y1 + r * math.sin(a1), gz + r * math.cos(a1)),
                 (gx + 0.1, y1 + r * math.sin(a1), gz + r * math.cos(a1)), (gx + 0.1, y0 + r * math.sin(a0), gz + r * math.cos(a0))]
            quad(p, q, stone_col(p, "pale"), STONE, out=(gx, 0.72, gz))
        for sx in (-0.1, 0.1):
            c = (gx + sx, 0.72, gz)
            q = [c, (gx + sx, 0.72 + r * math.sin(a0), gz + r * math.cos(a0)), (gx + sx, 0.72 + r * math.sin(a1), gz + r * math.cos(a1))]
            quad(p, q, stone_col(p, "pale"), STONE, out=(gx + sx * 3, 0.72, gz))
    beam_between(p, V(gx + 0.12, 0.72, gz), V(gx + 0.4, 0.72, gz), 0.05, kind=IRON, col=p.iron())
    beam_between(p, V(gx + 0.4, 0.72, gz), V(gx + 0.4, 0.45, gz + 0.3), 0.04, kind=IRON, col=p.iron())
    # a charcoal bin, a barrel and a stack of billets
    box(p, V(-3.2, 0.5, -1.0), (0.9, 0.9, 1.2), tone="dark", jit=0.004)
    for k in range(9):
        blob(p, V(-3.2 + p.rng.uniform(-0.3, 0.3), 1.0 + p.rng.uniform(0.0, 0.07), -1.0 + p.rng.uniform(-0.45, 0.45)), (0.11, 0.08, 0.1), (0.12, 0.11, 0.11), DARK, 5, 3)
    prism(p, 12, 0.36, 0.0, 1.05, (-3.4, -2.4), kind=WOOD, col=p.wood("mid"), r1=0.34)
    for yy in (0.2, 0.55, 0.9):
        prism(p, 12, 0.375, yy, yy + 0.06, (-3.4, -2.4), kind=IRON, caps=(False, False), col=p.iron())
    for k in range(4):
        box(p, V(0.2 + 0.0, 0.1 + 0.09 * k, -2.0), (1.0, 0.08, 0.14), kind=IRON, col=p.iron(), R=rotm(0.04 * (k % 2)))
    return finish(p, "hw_forge", (V(0, 2.2, 0.0), (8.6, 4.4, 6.4)))


MODELS = [
    ("hw_well", build_well, V(0, 1.4, 0)),
    ("hw_notice", build_notice, V(0, 1.9, 0)),
    ("hw_shrine", build_shrine, V(0, 2.2, 0)),
    ("hw_forge", build_forge, V(0, 2.0, 0)),
]

for name, fn, focus in MODELS:
    if ONLY and name not in ONLY:
        continue
    reset()
    ns["MERGE"].clear()
    ns["INDOOR"] = False
    vis, col = fn()
    export(vis + [col], os.path.join(OUT, name + ".glb"))
    lo, hi = bounds(vis)
    print("PROP %-16s tris %5d  size x %.2f..%.2f  y %.2f..%.2f  z %.2f..%.2f" % (name, tri_count(vis), lo.x, hi.x, lo.y, hi.y, lo.z, hi.z))
    if PREVIEW:
        col.hide_render = True
        for o in vis:                                   # the preview looks from +z: turn the piece so its front (-z) faces the camera
            o.rotation_euler = (0.0, 0.0, math.pi)
        bpy.context.view_layer.update()
        render_set(vis, name, V(-focus.x, focus.y, -focus.z))
