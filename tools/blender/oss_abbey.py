"""The Charnel Abbey, by script: tools/blender/run.sh oss_abbey.py -- [--preview DIR]

  art/models/oss_abbey.glb   the Order of the Count's abbey church, which stands on the quarry's south bank and
                             is the Ossuary's skyline (r39 redesign, 21 Nov): AbbeyBay (a lit lancet bay of the
                             nave's north wall), AbbeyBayBlind (the same with its lancet bricked and a tally cut in
                             it), AbbeyButtress, AbbeyRoof (one bay of slate roof), AbbeyGable (the east end: the
                             charnel door and the great rose), AbbeyTower (the bell tower, 46 m: belfry, lantern and
                             spire), AbbeyTurret (a stair turret), AbbeyPierHead (the pinnacle that crowns a buttress)
  core/world/realm/oss_abbey_data.gd   the numbers the game needs (bay width, wall height, the tower's belfry)

House style (oss_ground.py / r37_south_lib.py): authored in GODOT coordinates (x right, y up, z back; a piece's
front faces -z, its origin on the ground in the middle of its footprint), chunky hand-built masonry (thick walls, big
battered buttresses, oversize roofs, a few large forms rather than much detail), tileable procedural maps baked into
the glb. Every lit pane is a "Oss_Glow" surface: the game gives it the kit's glow shader (oss_glow.gdshader).
"""
import sys
import os
import math

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib
import r37_south_lib as L
import oss_ground as OG
importlib.reload(L)
from r37_south_lib import B, G, Vector, Matrix, np, hash3
from oss_ground import pointed, frame_panel, oface, lathe, open_door

L.TEX_DIR = os.path.join(L.BLEND_DIR, "textures", "oss_abbey")
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
PREVIEW = ARGS[ARGS.index("--preview") + 1] if "--preview" in ARGS else ""
DATA = {}

# --- the church's numbers (Godot metres) -----------------------------------------------------------------
W = 6.4                  ## one bay's width
T = 1.6                  ## the wall's thickness (front face at z = -T/2)
WALL_H = 16.0            ## the north wall to its eaves
DEPTH = 9.6              ## the roof's span (front face to the back wall; the tower's width)
RIDGE = 6.6              ## the ridge over the eaves
LOW_H = 10.0             ## the lower stage (to the string course)
PLINTH = 1.7
FZ = -T / 2


def mats():
    """OG.mats() at half the texture size (the abbey is seen from afar, in the dark: 512 maps per 3.2 m tile)."""
    m = {}
    alb, h, r = L.tex_ashlar(512, 7301, 7, -0.03)
    m["stone"] = L.pbr("Oss_Ashlar", (np.clip(alb * 1.32 + 0.03, 0.0, 1.0), h, r), 1.2)
    m["stone"]["uv_mul"] = 1.95
    alb, h, r = L.tex_masonry(512, 7302, rows=8, cold=True)
    m["rubble"] = L.pbr("Oss_Rubble", (np.clip(alb * 1.38 + 0.02, 0.0, 1.0), h, r), 1.8)
    m["rubble"]["uv_mul"] = 1.0
    m["slate"] = L.pbr("Oss_Slate", OG.tex_slates(512, 7303), 2.0)
    alb, h, r = L.tex_planks(256, 7304)
    m["oak"] = L.pbr("Oss_Oak", (np.clip(alb * 1.25, 0.0, 1.0), h, r), 2.4)
    m["bone"] = L.pbr("Oss_Bone", OG.tex_bone(256, 7305), 1.4)
    m["iron"] = L.flat("Oss_Iron", (0.07, 0.065, 0.06), 0.55, 0.85)
    m["dark"] = L.flat("Oss_Dark", (0.012, 0.011, 0.011), 1.0)
    g = L.flat("Oss_Glow", (1.0, 0.62, 0.26), 0.6)
    bs = g.node_tree.nodes["Principled BSDF"]
    bs.inputs["Emission Color"].default_value = (1.0, 0.55, 0.2, 1.0)
    bs.inputs["Emission Strength"].default_value = 4.0
    m["glow"] = g
    return m


# =================================================================================================
# helpers
# =================================================================================================

def lancet(cx, sill, w, h):
    """A pointed opening's outline in panel coordinates: its sill at `sill`, w wide, h tall to the apex."""
    rise = w * 0.95
    arch = pointed(w, rise, 10)
    spring = sill + h - rise
    pts = [(cx + x, spring + y) for x, y in arch]
    pts += [(cx + w / 2, sill), (cx - w / 2, sill)]
    return pts


def reveal(b, origin, u, v, nrm, hole, depth, mat, glow_at, glow_mat="glow", mullion=None):
    """The opening's jambs: the outline lofted back `depth` along -nrm in dressed stone, the lit pane at `glow_at`
    (m back from the face), and an optional mullion [(x, y0, y1, w)] in panel coordinates."""
    O = Vector(origin)
    U = Vector(u)
    Vv = Vector(v)
    N = Vector(nrm)
    P = lambda q, d: O + U * q[0] + Vv * q[1] - N * d
    ring_f = [P(q, 0.0) for q in hole]
    ring_b = [P(q, depth) for q in hole]
    cx = sum(q[0] for q in hole) / len(hole)
    cy = sum(q[1] for q in hole) / len(hole)
    cen = P((cx, cy), depth * 0.5)
    fs = b.loft([ring_f, ring_b], mat, closed=True, smooth=False, box_uv=0.3)
    for f in fs:
        f.normal_update()
        if f.normal.dot(cen - f.calc_center_median()) < 0:
            f.normal_flip()
    pane = [P(q, glow_at) for q in hole]
    oface(b, pane, glow_mat, N)
    # the dark behind the pane (a lit pane seen at a slant never shows the sky through the wall)
    oface(b, [P(q, depth) for q in reversed(hole)], "dark", N)
    if mullion:
        for (mx, y0, y1, mw) in mullion:
            c = P((mx, (y0 + y1) / 2), glow_at * 0.45)
            b.box(tuple(c), (mw, y1 - y0, 0.34), mat, scale_uv=0.3)


def wall_panel(b, origin, u, v, nrm, w, h, hole, mat="rubble", uv=1.0):
    fs = frame_panel(b, origin, u, v, nrm, w, h, hole, mat)
    return fs


def solid_face(b, pts, mat, nrm, uvs=0.16):
    f = oface(b, pts, mat, nrm)
    if f:
        b._box_uv([f], uvs * float(b.mats[mat].get("uv_mul", 1.0)))
    return f


def skull_row(b, y, xs, z, face=-1.0, s=1.4):
    for x in xs:
        OG.skull(b, (x, y, z), (0, 0, face), (0, 1, 0), s=s)


def merlons(b, y, x0, x1, z, n, depth=0.9, h=1.3, mat="stone", seed=0, face=-1):
    span = x1 - x0
    mw = span / (2 * n - 1)
    for i in range(n):
        cx = x0 + mw * (2 * i + 0.5)
        b.box((cx, y + h / 2, z), (mw, h, depth), mat, jit=0.012, seed=seed + i)


def corbel_table(b, y, x0, x1, z_front, t, mat="stone", seed=0):
    """A band of stepped corbels under a cornice: three courses jutting further each, then the cornice slab."""
    L_ = x1 - x0
    xc = (x0 + x1) / 2
    for k, (dy, pj) in enumerate(((0.0, 0.12), (0.34, 0.26), (0.68, 0.42))):
        b.box((xc, y + dy + 0.17, z_front - pj / 2 + t * 0.0), (L_ + 0.1, 0.34, pj * 2 + 0.1), mat, jit=0.006, seed=seed + k)
    b.box((xc, y + 1.2, z_front - 0.2), (L_ + 0.3, 0.5, 0.9), mat, jit=0.008, seed=seed + 9)
    n = max(3, int(L_ / 0.8))
    for i in range(n):
        cx = x0 + (i + 0.5) * L_ / n
        b.box((cx, y - 0.18, z_front - 0.24), (0.34, 0.5, 0.5), mat, taper=0.6, jit=0.01, seed=seed + 20 + i)


def pyramid(b, cx, cz, y, r, h, mat, sides=4, off=math.pi / 4):
    lathe(b, [(r, y), (0.03, y + h)], mat, sides, off, 3.2)


# =================================================================================================
# the buttress, the pinnacle
# =================================================================================================

def buttress_into(b, x, z_face, h=WALL_H + 1.6, proj=2.6, w=1.8, front=-1.0):
    """A stepped, weathered buttress against a wall whose face stands at z_face (front = -1: it juts toward -z)."""
    def at(y0, y1, w_, p_, tap=0.97):
        zc = z_face + front * (p_ / 2 - 0.4)
        b.box((x, (y0 + y1) / 2, zc), (w_, y1 - y0, p_ + 0.4), "stone", taper=tap, jit=0.014, seed=int(y0 * 7 + 3), scale_uv=0.16)
    s1, s2 = h * 0.36, h * 0.7
    at(0.0, s1, w, proj)
    b.box((x, s1 + 0.12, z_face + front * (proj * 0.5 - 0.4)), (w + 0.16, 0.26, proj + 0.46), "stone", taper=0.78, jit=0.01, seed=3)
    at(s1, s2, w * 0.82, proj * 0.66)
    b.box((x, s2 + 0.12, z_face + front * (proj * 0.33 - 0.4)), (w * 0.82 + 0.16, 0.26, proj * 0.66 + 0.46), "stone", taper=0.78, jit=0.01, seed=4)
    at(s2, h, w * 0.66, proj * 0.36)
    # the cap: a weathered slope
    b.box((x, h + 0.2, z_face + front * (proj * 0.18 - 0.4)), (w * 0.66 + 0.2, 0.4, proj * 0.36 + 0.5), "stone", taper=0.5, jit=0.01, seed=5)


def pinnacle_at(b, x, y, z, w=0.9, shaft=1.5, spike=2.6):
    b.box((x, y + shaft / 2, z), (w, shaft, w), "stone", jit=0.01, seed=int(x * 3 + y))
    b.box((x, y + shaft + 0.12, z), (w + 0.26, 0.24, w + 0.26), "stone", taper=0.8)
    pyramid(b, x, z, y + shaft + 0.24, w * 0.62, spike, "stone")
    for sx, sz in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
        b.box((x + sx * w * 0.62, y + shaft + 0.45, z + sz * w * 0.62), (0.2, 0.55, 0.2), "stone", taper=0.5)


# =================================================================================================
# the bay: a stage of the nave's north wall between two buttresses
# =================================================================================================

def build_bay(m, objs, blind=False):
    mt = {"stone": m["stone"], "rubble": m["rubble"], "dark": m["dark"], "glow": m["glow"], "bone": m["bone"], "iron": m["iron"]}
    b = B("AbbeyBayBlind" if blind else "AbbeyBay", mt)
    x0 = -W / 2
    N = (0, 0, -1)
    U = (1, 0, 0)
    V = (0, 1, 0)
    # the plinth: a battered course of big blocks
    b.box((0, PLINTH / 2, 0), (W + 0.1, PLINTH, T + 0.9), "stone", taper=0.94, cuts=1, jit=0.02, seed=1)
    # the lower stage: coursed rubble with the big lancet
    y0 = PLINTH
    hole = lancet(W / 2, 1.9, 2.7, 6.8) if not blind else [(W / 2 - 0.9, 3.4), (W / 2 + 0.9, 3.4), (W / 2 + 0.9, 3.5), (W / 2 - 0.9, 3.5)]
    if not blind:
        wall_panel(b, (x0, y0, FZ), U, V, N, W, LOW_H - y0, [(px, py) for px, py in hole])
        reveal(b, (x0, y0, FZ), U, V, N, hole, 0.9, "stone", 0.62, mullion=[(W / 2, 1.9, 1.9 + 6.8 - 2.4, 0.26)])
        # the sill and the head moulding (dressed stone proud of the face)
        b.box((W / 2, y0 + 1.9 - 0.12, FZ - 0.16), (3.4, 0.28, 0.5), "stone", jit=0.01, seed=11)
    else:
        solid_face(b, [(x0, y0, FZ), (x0 + W, y0, FZ), (x0 + W, LOW_H, FZ), (x0, LOW_H, FZ)], "rubble", N, 0.16 * 1.0)
        # a bricked lancet: a recessed blind arch in dressed stone and the Count's tally cut under it
        arch = lancet(W / 2, 1.9, 2.7, 6.8)
        ring_f = [(x0 + q[0], q[1] + y0, FZ - 0.02) for q in arch]
        ring_b = [(x0 + q[0], q[1] + y0, FZ + 0.34) for q in arch]
        fs = b.loft([ring_f, ring_b], "stone", closed=True, smooth=False, box_uv=0.3)
        cen = Vector((x0 + W / 2, y0 + 5.0, FZ + 0.17))
        for f in fs:
            f.normal_update()
            if f.normal.dot(cen - f.calc_center_median()) < 0:
                f.normal_flip()
        oface(b, [Vector(p) for p in reversed(ring_b)], "stone", N)
        for i in range(4):
            for j in range(5):
                xx = x0 + W / 2 - 0.95 + 0.5 * i + 0.075 * j
                if j == 4:
                    b.box((xx - 0.17, y0 + 2.6, FZ - 0.05), (0.62, 0.05, 0.05), "dark", roll=0.5)
                else:
                    b.box((xx, y0 + 2.6, FZ - 0.05), (0.05, 0.42, 0.05), "dark")
    # the string course
    b.box((0, LOW_H + 0.17, FZ - 0.12), (W + 0.04, 0.34, 0.4), "stone", jit=0.006, seed=2)
    # the upper stage: a smaller lancet
    uy0 = LOW_H + 0.34
    uh = WALL_H - 2.0 - uy0
    uhole = lancet(W / 2, 0.8, 1.5, 3.6)
    wall_panel(b, (x0, uy0, FZ), U, V, N, W, uh, uhole)
    reveal(b, (x0, uy0, FZ), U, V, N, uhole, 0.9, "stone", 0.6)
    b.box((W / 2, uy0 + 0.7, FZ - 0.12), (2.0, 0.22, 0.4), "stone", jit=0.01, seed=12)
    # the corbel table, the parapet
    corbel_table(b, WALL_H - 1.8, x0, x0 + W, FZ, T, seed=30)
    skull_row(b, WALL_H - 0.85, [x0 + W * (i + 0.5) / 4 for i in range(4)], FZ - 0.5, s=1.9)
    merlons(b, WALL_H + 0.0, x0, x0 + W, FZ - 0.18, 3, 0.9, 1.4, seed=40)
    # the back and the ends (a bay's closed body)
    solid_face(b, [(x0, 0, T / 2), (x0 + W, 0, T / 2), (x0 + W, WALL_H, T / 2), (x0, WALL_H, T / 2)], "rubble", (0, 0, 1))
    for sx in (-1.0, 1.0):
        solid_face(b, [(sx * W / 2, 0, FZ), (sx * W / 2, 0, T / 2), (sx * W / 2, WALL_H, T / 2), (sx * W / 2, WALL_H, FZ)], "rubble", (sx, 0, 0))
    ob = b.finish()
    L.moss_colors(ob, seed=101 if not blind else 102, amount=0.35, tint=(0.5, 0.58, 0.4))
    objs.append(ob)


def build_buttress(m, objs):
    b = B("AbbeyButtress", {"stone": m["stone"], "dark": m["dark"]})
    buttress_into(b, 0.0, FZ, WALL_H + 1.2, 2.7, 1.9)
    pinnacle_at(b, 0.0, WALL_H + 1.5, FZ - 1.2, 1.0, 1.4, 2.8)
    ob = b.finish()
    L.moss_colors(ob, seed=103, amount=0.3, tint=(0.5, 0.58, 0.4))
    objs.append(ob)


# =================================================================================================
# the roof (one bay of it) and the gable
# =================================================================================================

def slab(b, p0, p1, p2, p3, thick, mat, up):
    """A slab with the quad p0 p1 p2 p3 as its top face (up = the way its top looks), thick under it."""
    up = Vector(up).normalized()
    top = [Vector(p) for p in (p0, p1, p2, p3)]
    bot = [p - up * thick for p in top]
    cen = sum(top, Vector()) / 4.0 - up * thick * 0.5
    oface(b, top, mat, up)
    oface(b, list(reversed(bot)), "dark", -up)
    for i in range(4):
        j = (i + 1) % 4
        mid = (top[i] + top[j] + bot[i] + bot[j]) * 0.25
        oface(b, [top[i], top[j], bot[j], bot[i]], mat, mid - cen)
    b._box_uv([f for f in b.bm.faces if f.material_index == b.keys.index(mat)], 0.16 * float(b.mats[mat].get("uv_mul", 1.0)) * 1.4)


def build_roof(m, objs):
    """One bay of the nave's roof: ridge along x, the front pitch toward -z. Origin: the wall's front face
    (z = FZ) at the eaves height (y 0 here)."""
    b = B("AbbeyRoof", {"slate": m["slate"], "stone": m["stone"], "oak": m["oak"], "dark": m["dark"]})
    run = DEPTH
    half = run / 2
    over = 1.0
    xl, xr = -W / 2, W / 2
    zf = FZ - over
    zm = FZ + half                       # ridge line
    zb = FZ + run + over
    ey = -0.35                           # the drip edge a little under the wall's top
    ry = RIDGE
    # pitch rises from (zf, ey) to (zm, ry); the lower slate tilts
    slab(b, (xl, ey, zf), (xr, ey, zf), (xr, ry, zm), (xl, ry, zm), 0.5, "slate", (0, 1, -(ry - ey) / (zm - zf)))
    slab(b, (xr, ey, zb), (xl, ey, zb), (xl, ry, zm), (xr, ry, zm), 0.5, "slate", (0, 1, (ry - ey) / (zb - zm)))
    # ridge cap: a chunky stone roll
    b.box((0, ry + 0.2, zm), (W + 0.02, 0.62, 0.95), "stone", jit=0.01, seed=7)
    # eaves: rafter ends and a fascia
    n = 7
    for i in range(n):
        x = xl + (i + 0.5) * W / n
        b.box((x, ey - 0.18, zf + 0.3), (0.3, 0.3, 0.9), "oak", jit=0.01, seed=60 + i)
    b.box((0, ey + 0.05, zf), (W + 0.02, 0.28, 0.16), "oak", jit=0.006, seed=50)
    ob = b.finish()
    L.moss_colors(ob, seed=104, amount=0.2, tint=(0.5, 0.58, 0.4))
    objs.append(ob)


def ring_pts(cx, cy, r, n=16, a0=0.0):
    return [(cx + math.cos(a0 + math.tau * i / n) * r, cy + math.sin(a0 + math.tau * i / n) * r) for i in range(n)]


def build_gable(m, objs):
    """The east end: a gable wall DEPTH wide (matching the roof's span), with the charnel door, two lancets, the great
    rose over the door, the stepped barge and an apex of skulls. Front toward -z; the origin in the middle of the foot."""
    mt = {"stone": m["stone"], "rubble": m["rubble"], "dark": m["dark"], "glow": m["glow"], "bone": m["bone"], "iron": m["iron"], "slate": m["slate"], "oak": m["oak"]}
    b = B("AbbeyGable", mt)
    Wd = DEPTH
    x0 = -Wd / 2
    N = (0, 0, -1)
    U = (1, 0, 0)
    V = (0, 1, 0)
    eaves = WALL_H
    apex = WALL_H + RIDGE + 0.6
    b.box((0, PLINTH / 2, 0), (Wd + 0.1, PLINTH, T + 0.9), "stone", taper=0.95, cuts=2, jit=0.02, seed=21)
    y0 = PLINTH
    # three columns: [lancet | door + rose | lancet]
    cols = [(x0, 3.0), (x0 + 3.0, Wd - 6.0), (x0 + Wd - 3.0, 3.0)]
    for i, (cx0, cw) in enumerate(cols):
        if i == 1:
            continue
        hole = lancet(cw / 2, 1.8, 1.8, 6.4)
        wall_panel(b, (cx0, y0, FZ), U, V, N, cw, eaves - y0, hole)
        reveal(b, (cx0, y0, FZ), U, V, N, hole, 0.9, "stone", 0.6)
    # centre: the charnel door below, the rose above
    cx0, cw = cols[1]
    door_h = 6.8
    door = lancet(cw / 2, 0.0, 2.8, door_h)
    wall_panel(b, (cx0, y0, FZ), U, V, N, cw, 9.0 - y0, door)
    reveal(b, (cx0, y0, FZ), U, V, N, door, 1.1, "stone", 1.0, glow_mat="dark")
    # a threshold of steps is the game's (the door opens on the bank); the door's own jamb shafts and head
    for sx in (-1.0, 1.0):
        b.box((cx0 + cw / 2 + sx * 1.6, y0 + 2.6, FZ - 0.3), (0.5, 5.2, 0.7), "stone", jit=0.01, seed=22)
    rose_r = 1.75
    rc = (cw / 2, 3.5)
    rose = ring_pts(rc[0], rc[1], rose_r, 20)
    wall_panel(b, (cx0, 9.0, FZ), U, V, N, cw, eaves - 9.0, rose)
    reveal(b, (cx0, 9.0, FZ), U, V, N, rose, 0.8, "stone", 0.5)
    rcw = Vector((cx0 + rc[0], 9.0 + rc[1], FZ - 0.14))
    # the great rose: a stone ring, eight spokes, a hub
    for k in range(8):
        a = math.tau * k / 8 + math.pi / 8
        c = rcw + Vector((math.cos(a) * rose_r * 0.5, math.sin(a) * rose_r * 0.5, 0.0))
        b.box(tuple(c), (rose_r, 0.2, 0.34), "stone", roll=a, scale_uv=0.3)
    pts = [(rcw.x + math.cos(math.tau * i / 16) * rose_r * 1.02, rcw.y + math.sin(math.tau * i / 16) * rose_r * 1.02, rcw.z) for i in range(17)]
    b.tube_path(pts, [0.2] * len(pts), "stone", sides=5, bark=1.0, cap_end=False)
    b.box(tuple(rcw), (0.7, 0.7, 0.4), "stone", roll=math.pi / 4)
    # the gable: a triangle of rubble above the eaves with an oculus, stepped barge stones along both slopes
    gl, gr = x0 - 0.3, x0 + Wd + 0.3
    solid_face(b, [(gl, eaves, FZ), (gr, eaves, FZ), (0, apex, FZ)], "rubble", N, 0.16)
    steps = 5
    for side in (-1.0, 1.0):
        for i in range(steps):
            t = (i + 0.5) / steps
            x = side * (Wd / 2 + 0.3) * (1.0 - t)
            y = eaves + (apex - eaves) * t
            b.box((x, y + 0.2, FZ - 0.18), (1.7, 0.62, 0.8), "stone", yaw=0.0, roll=side * 0.78, jit=0.012, seed=70 + i + int(side))
    # skulls laid in the gable's field, a tally beneath
    for (sx, sy) in ((-1.2, eaves + 1.2), (0.0, eaves + 2.0), (1.2, eaves + 1.2), (0.0, eaves + 3.4)):
        OG.skull(b, (sx, sy, FZ - 0.05), (0, 0, -1), (0, 1, 0), s=2.3)
    # the cornice under the barge
    corbel_table(b, eaves - 1.8, x0, x0 + Wd, FZ, T, seed=80)
    b.box((0, eaves + 0.15, FZ - 0.1), (Wd + 0.5, 0.3, 0.5), "stone", jit=0.008, seed=26)
    # the finial: the Order's Open Door at the apex
    b.box((0, apex + 0.3, FZ), (0.8, 0.9, 0.8), "stone", taper=0.7)
    open_door(b, (0.0, apex + 0.7, FZ), 0.9, 1.5, 0.08, "iron", 1.0)
    # the body behind
    solid_face(b, [(x0, 0, T / 2), (x0 + Wd, 0, T / 2), (x0 + Wd, eaves, T / 2), (0, apex, T / 2)], "rubble", (0, 0, 1))
    for sx in (-1.0, 1.0):
        solid_face(b, [(sx * Wd / 2, 0, FZ), (sx * Wd / 2, 0, T / 2), (sx * Wd / 2, eaves, T / 2), (sx * Wd / 2, eaves, FZ)], "rubble", (sx, 0, 0))
    ob = b.finish()
    L.moss_colors(ob, seed=105, amount=0.35, tint=(0.5, 0.58, 0.4))
    objs.append(ob)
    DATA["GABLE"] = {"w": Wd, "eaves": eaves, "apex": apex, "door_w": 2.8, "door_h": door_h}


# =================================================================================================
# the stair turret
# =================================================================================================

def build_turret(m, objs):
    mt = {"stone": m["stone"], "rubble": m["rubble"], "slate": m["slate"], "glow": m["glow"], "dark": m["dark"], "iron": m["iron"]}
    b = B("AbbeyTurret", mt)
    R = 1.75
    H = WALL_H + 3.2
    sides = 10
    prof = [(R + 0.55, -0.5), (R + 0.55, 0.6), (R + 0.3, 1.5), (R + 0.04, 2.0), (R, H - 2.4)]
    lathe(b, prof, "rubble", sides, 0.0, 3.2)
    # belts of dressed stone
    for y in (4.5, 9.5, 14.0):
        lathe(b, [(R + 0.02, y), (R + 0.2, y + 0.12), (R + 0.2, y + 0.38), (R + 0.02, y + 0.5)], "stone", sides, 0.0, 3.2)
    # the corbelled head: a swelling ring under the cap
    y = H - 2.4
    lathe(b, [(R, y), (R + 0.24, y + 0.18), (R + 0.52, y + 0.5), (R + 0.84, y + 0.86), (R + 0.84, y + 1.7), (R + 0.5, y + 1.9)], "stone", sides, 0.0, 3.2)
    for k in range(sides):
        a = -math.tau * k / sides + math.pi / sides
        b.box((math.cos(a) * (R + 0.9), y + 1.2, math.sin(a) * (R + 0.9)), (0.4, 1.1, 0.4), "stone", yaw=-a, taper=0.8)
    # the conical cap
    lathe(b, [(R + 0.58, y + 1.9), (R + 0.4, y + 3.4), (R * 0.45, y + 6.2), (0.05, y + 8.2)], "slate", sides, 0.0, 3.2)
    b.box((0, y + 8.6, 0), (0.12, 1.0, 0.12), "iron")
    b.box((0, y + 8.9, 0), (0.55, 0.1, 0.1), "iron")
    # the lit slits (three on the front)
    for sy in (5.8, 10.6, 15.2):
        a = math.pi / 2  # toward -z
        px, pz = 0.0, -(R + 0.02)
        for sx in (-0.2, 0.2):
            pass
        b.box((px, sy + 0.8, pz - 0.06), (0.62, 1.9, 0.18), "stone", jit=0.006, seed=int(sy))
        oface(b, [(px - 0.12, sy, pz - 0.2), (px + 0.12, sy, pz - 0.2), (px + 0.12, sy + 1.5, pz - 0.2), (px - 0.12, sy + 1.5, pz - 0.2)], "glow", (0, 0, -1))
    ob = b.finish()
    L.moss_colors(ob, seed=106, amount=0.3, tint=(0.5, 0.58, 0.4))
    objs.append(ob)


# =================================================================================================
# the bell tower
# =================================================================================================

TW = 9.6                 ## the shaft's width
TH = [(3.2, 20.0), (20.0, 28.0)]      ## the shaft, the belfry (y ranges)
BW = 8.6                 ## the belfry's width
PARAPET = 31.0
LANT = (31.0, 36.0)
SPIRE_TOP = 46.0


def side_basis(k):
    """The k-th face of a square tower: (normal, u, yaw) with k = 0 the front (-z), turning clockwise from above."""
    a = k * math.pi / 2
    n = Vector((math.sin(a) * -1.0 * -1.0, 0.0, -math.cos(a)))
    n = Vector((math.sin(a), 0.0, -math.cos(a)))
    u = Vector((math.cos(a), 0.0, math.sin(a)))
    return n, u, a


def tower_faces(b, half, y0, y1, holes_fn, mat="rubble", depth=1.0, mullions=None):
    for k in range(4):
        n, u, a = side_basis(k)
        o = Vector((0, y0, 0)) + n * half - u * half
        hole = holes_fn(k)
        if hole is None:
            f = b.face([o, o + u * (2 * half), o + u * (2 * half) + Vector((0, y1 - y0, 0)), o + Vector((0, y1 - y0, 0))], mat)
            if f:
                f.normal_update()
                if f.normal.dot(n) < 0:
                    f.normal_flip()
                b._box_uv([f], 0.16 * float(b.mats[mat].get("uv_mul", 1.0)))
            continue
        wall_panel(b, tuple(o), tuple(u), (0, 1, 0), tuple(n), 2 * half, y1 - y0, hole, mat)
        reveal(b, tuple(o), tuple(u), (0, 1, 0), tuple(n), hole, depth, "stone", depth * 0.6, mullion=mullions)


def build_tower(m, objs):
    mt = {"stone": m["stone"], "rubble": m["rubble"], "slate": m["slate"], "glow": m["glow"], "dark": m["dark"], "iron": m["iron"], "bone": m["bone"], "oak": m["oak"]}
    b = B("AbbeyTower", mt)
    h1 = TW / 2
    h2 = BW / 2
    # the plinth: a battered podium of great blocks
    for i, (hh, y0, y1) in enumerate(((h1 + 1.3, 0.0, 1.2), (h1 + 0.8, 1.2, 2.2), (h1 + 0.3, 2.2, 3.2))):
        b.box((0, (y0 + y1) / 2 - 0.1, 0), (hh * 2, y1 - y0 + 0.2, hh * 2), "stone", cuts=2, jit=0.02, seed=31 + i, taper=0.97)
    b.box((0, 9.0, 0), (TW - 0.5, 20.0, TW - 0.5), "dark")            # the core: nothing shows through a window
    # the shaft: a slit and a lancet per stage on every face, three stages
    def shaft_hole(k):
        return None
    for (y0, y1, sill, hh) in ((3.2, 9.0, 1.6, 3.6), (9.0, 14.6, 1.3, 3.2), (14.6, 20.0, 1.2, 3.0)):
        def holes(k, sill=sill, hh=hh):
            return lancet(h1, sill, 1.3, hh)
        tower_faces(b, h1, y0, y1, holes, "rubble", 1.0)
        b.box((0, y1, 0), (TW + 0.5, 0.34, TW + 0.5), "stone", jit=0.01, seed=int(y1))        # the string course
    # the corner buttresses: great stepped piers up to the second string course
    for sx, sz in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
        cx, cz = sx * (h1 + 0.4), sz * (h1 + 0.4)
        b.box((cx, 6.0, cz), (2.6, 12.0, 2.6), "stone", taper=0.94, jit=0.014, seed=40 + sx * 3 + sz)
        b.box((cx, 12.3, cz), (2.9, 0.4, 2.9), "stone", taper=0.7)
        b.box((cx, 15.0, cz), (2.1, 5.2, 2.1), "stone", taper=0.95, jit=0.01, seed=44 + sx * 3 + sz)
        b.box((cx, 17.8, cz), (2.4, 0.4, 2.4), "stone", taper=0.7)
        b.box((cx, 19.6, cz), (1.6, 3.4, 1.6), "stone", taper=0.92, jit=0.01, seed=48)
    # the belfry: a pair of louvred lancets on every face, the whole stage lit from inside
    b.box((0, 24.0, 0), (BW - 0.5, 8.0, BW - 0.5), "dark")
    def bel_holes(k):
        return lancet(h2 - 1.9, 1.2, 1.9, 6.2)
    for k in range(4):
        n, u, a = side_basis(k)
        o = Vector((0, 20.0, 0)) + n * h2 - u * h2
        holes = [lancet(1.95, 1.2, 1.9, 6.0), lancet(BW - 1.95, 1.2, 1.9, 6.0)]
        # two holes in one panel: three columns (the panel code takes one)
        for (c0, cw) in ((0.0, BW / 2), (BW / 2, BW / 2)):
            hole = lancet(BW / 4, 1.2, 1.9, 6.2)
            O = o + u * c0
            wall_panel(b, tuple(O), tuple(u), (0, 1, 0), tuple(n), cw, 8.0, hole, "rubble")
            reveal(b, tuple(O), tuple(u), (0, 1, 0), tuple(n), hole, 1.0, "stone", 0.6, mullion=[(BW / 4, 1.2, 5.0, 0.18)])
        # the bell, a dark swell seen in the middle of the pair? (kept to the louvres)
        # sill and a skull belt at the foot of the belfry
        for i in range(7):
            x = -h2 + 0.6 + i * (BW - 1.2) / 6.0
            c = n * (h2 + 0.02) + u * x
            OG.skull(b, (c.x, 20.55, c.z), tuple(n), (0, 1, 0), s=1.7)
    b.box((0, 20.0, 0), (BW + 0.6, 0.5, BW + 0.6), "stone", jit=0.008, seed=52)
    # corner turrets of the belfry (pinnacles with a lit lantern each would be too much: four stone ones)
    for sx, sz in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
        cx, cz = sx * (h2 + 0.1), sz * (h2 + 0.1)
        b.box((cx, 24.0, cz), (1.7, 8.0, 1.7), "stone", taper=0.95, jit=0.012, seed=54)
    # the corbel table and the parapet with merlons
    for kk, pj in enumerate((0.15, 0.3, 0.5)):
        sz = BW + 0.6 + 2 * pj
        b.box((0, 28.17 + 0.34 * kk, 0), (sz, 0.34, sz), "stone", jit=0.006, seed=60 + kk)
    b.box((0, 29.4, 0), (BW + 1.9, 1.0, BW + 1.9), "stone", jit=0.01, seed=62)
    b.box((0, 29.9, 0), (BW + 0.7, 2.0, BW + 0.7), "stone", taper=0.99)
    ph = BW / 2 + 0.7
    for k in range(4):
        n, u, a = side_basis(k)
        for i in range(5):
            x = -ph + 0.75 + i * (2 * ph - 1.5) / 4.0
            c = n * (ph - 0.1) + u * x
            b.box((c.x, 31.55, c.z), (1.2 if k % 2 == 0 else 0.9, 1.3, 0.9 if k % 2 == 0 else 1.2), "stone", jit=0.012, seed=63 + i)
    # the lantern: eight posts round a lit core, a ring over it
    ly0, ly1 = 31.0, 36.0
    lathe(b, [(2.7, ly0), (2.7, ly1 - 0.1)], "glow", 8, math.pi / 8, 3.2)            # the lit core (glows through the posts)
    for k in range(8):
        a = math.tau * k / 8
        b.box((math.cos(a) * 3.35, (ly0 + ly1) / 2, math.sin(a) * 3.35), (0.62, ly1 - ly0, 0.62), "stone", yaw=-a, taper=0.94, jit=0.01, seed=70 + k)
    lathe(b, [(3.9, ly1 - 0.1), (3.9, ly1 + 0.35), (3.5, ly1 + 0.6)], "stone", 8, math.pi / 8, 3.2)
    lathe(b, [(3.9, ly0 - 0.4), (3.9, ly0 + 0.0)], "stone", 8, math.pi / 8, 3.2)
    # the spire: eight sides of slate, crockets up every ridge, four lucarnes lit
    sp = [(3.9, ly1 + 0.6), (3.7, ly1 + 1.2), (2.9, ly1 + 3.8), (1.9, ly1 + 6.4), (1.05, ly1 + 8.4), (0.35, SPIRE_TOP - 0.4)]
    lathe(b, sp, "slate", 8, math.pi / 8, 3.2)
    for k in range(8):
        a = -math.tau * k / 8
        for j in range(5):
            t = (j + 0.5) / 5.0
            r = 3.55 - 3.0 * t
            y = ly1 + 1.5 + 8.2 * t
            sz = 0.5 - 0.28 * t
            b.box((math.cos(a) * r, y, math.sin(a) * r), (sz, sz * 1.5, sz), "stone", yaw=-a + 0.78, roll=0.0, taper=0.4)
    for k in range(4):
        a = k * math.pi / 2 + math.pi / 8
        n = Vector((math.sin(a), 0, -math.cos(a)))
        r = 3.0
        c = n * r + Vector((0, ly1 + 2.9, 0))
        b.box(tuple(c + Vector((0, -0.3, 0))), (1.3, 1.7, 0.9), "stone", yaw=-(a), jit=0.01, seed=80 + k)
        gp = tuple(c + n * 0.46 + Vector((0, -0.3, 0)))
        u = Vector((-n.z, 0, n.x))
        oface(b, [Vector(gp) - u * 0.38, Vector(gp) + u * 0.38, Vector(gp) + u * 0.38 + Vector((0, 1.1, 0)), Vector(gp) - u * 0.38 + Vector((0, 1.1, 0))], "glow", n)
        b.box(tuple(c + n * 0.1 + Vector((0, 0.95, 0))), (1.5, 0.28, 1.1), "stone", yaw=-a, taper=0.5)
    b.box((0, SPIRE_TOP - 0.2, 0), (0.2, 1.3, 0.2), "iron")
    open_door(b, (0.0, SPIRE_TOP + 0.5, 0.0), 1.0, 1.5, 0.08, "iron", 1.0)
    ob = b.finish()
    L.moss_colors(ob, seed=107, amount=0.3, tint=(0.5, 0.58, 0.4))
    objs.append(ob)
    DATA["TOWER"] = {"w": TW, "belfry_y": 24.0, "lantern_y": 33.5, "top": SPIRE_TOP + 2.0}



# =================================================================================================
# the piers that carry the tiers (the same pier under every floor of the pit)
# =================================================================================================

PIER_W = 2.0
PIER_SEG = 4.0
PIER_FOOT = 1.8
PIER_CAP = 2.0


def _chamfered(b, c, w, h, mat, ch=0.14, seed=0, taper=1.0):
    """A square pier body with its four vertical arrises cut (an octagon in section), w across, h tall, base at c."""
    b.box((c[0], c[1] + h / 2, c[2]), (w, h, w - 2 * ch), mat, jit=0.01, seed=seed, taper=taper, scale_uv=0.16)
    b.box((c[0], c[1] + h / 2, c[2]), (w - 2 * ch, h, w), mat, jit=0.01, seed=seed + 1, taper=taper, scale_uv=0.16)


def build_pier(m, objs):
    mt = {"stone": m["stone"], "rubble": m["rubble"], "dark": m["dark"]}
    # the footing: two great stepped blocks and a water-table slope, standing in the pool
    b = B("OssPierFoot", mt)
    b.box((0, 0.5, 0), (PIER_W + 1.0, 1.0, PIER_W + 1.0), "stone", cuts=1, jit=0.02, seed=1)
    b.box((0, 1.15, 0), (PIER_W + 0.55, 0.5, PIER_W + 0.55), "stone", jit=0.012, seed=2, taper=0.96)
    b.box((0, 1.55, 0), (PIER_W + 0.3, 0.3, PIER_W + 0.3), "stone", taper=0.82, jit=0.01, seed=3)
    ob = b.finish()
    L.moss_colors(ob, seed=111, amount=0.5, tint=(0.4, 0.55, 0.45))
    objs.append(ob)
    # a shaft segment: a battered octagonal pier with a course line every metre and a pilaster rib on two faces
    b = B("OssPierShaft", mt)
    _chamfered(b, (0, 0, 0), PIER_W - 0.3, PIER_SEG, "rubble", 0.2, seed=5, taper=0.985)
    for k in range(4):
        y = k * PIER_SEG / 4
        b.box((0, y + 0.03, 0), (PIER_W - 0.12, 0.14, PIER_W - 0.12), "stone", taper=0.97, jit=0.006, seed=7 + k)
    for sz in (-1.0, 1.0):
        b.box((0, PIER_SEG / 2, sz * (PIER_W / 2 - 0.1)), (0.5, PIER_SEG, 0.22), "stone", jit=0.008, seed=15)
    ob = b.finish()
    L.moss_colors(ob, seed=112, amount=0.4, tint=(0.4, 0.55, 0.45))
    objs.append(ob)
    # the capital: three corbel steps and a thick abacus: the arch springs from it, the floor sits on it
    b = B("OssPierCap", mt)
    y = 0.0
    for i, (wd, ht) in enumerate(((PIER_W + 0.15, 0.3), (PIER_W + 0.55, 0.34), (PIER_W + 0.95, 0.38), (PIER_W + 1.3, 0.5))):
        b.box((0, y + ht / 2, 0), (wd, ht, wd), "stone", taper=0.9 if i < 3 else 1.0, jit=0.01, seed=20 + i)
        y += ht
    b.box((0, y + 0.24, 0), (PIER_W + 1.2, 0.48, PIER_W + 1.2), "stone", jit=0.008, seed=26)
    y += 0.48
    # skull bosses at the corners: the Order counts in its stone
    ob = b.finish()
    L.moss_colors(ob, seed=113, amount=0.3, tint=(0.4, 0.55, 0.45))
    objs.append(ob)
    DATA["PIER"] = {"w": PIER_W, "seg": PIER_SEG, "foot": PIER_FOOT, "cap": y}


# =================================================================================================
# the Pilgrims' Bridge: a stone bridge of pointed arches in the abbey's masonry (it replaced the bone bridge)
# =================================================================================================

BR_L = 6.5               ## one span's length (along x); the end spans are stretched to fit
BR_W = 4.0               ## deck width (z)
BR_D = 3.0               ## depth of the arch barrel under the deck's top (the pier capitals stand at -BR_D)


def build_bridge(m, objs):
    mt = {"stone": m["stone"], "rubble": m["rubble"], "dark": m["dark"], "bone": m["bone"]}
    b = B("OssBridgeSpan", mt)
    hw = BR_W / 2
    arch = pointed(BR_L - 1.7, BR_L * 0.27, 12)
    hole = [(BR_L / 2 + x, 0.01 + y) for x, y in arch]
    hole = [(BR_L / 2 - (BR_L - 1.7) / 2, 0.01)] + hole[1:-1] + [(BR_L / 2 + (BR_L - 1.7) / 2, 0.01)]
    for sz in (-1.0, 1.0):
        nrm = (0, 0, sz)
        # the spandrel wall of each face, an arched opening in it
        frame_panel(b, (-BR_L / 2, -BR_D, sz * hw), (1, 0, 0), (0, 1, 0), nrm, BR_L, BR_D, hole, "rubble")
        # the string course under the parapet
        b.box((0, -0.12, sz * (hw + 0.06)), (BR_L, 0.24, 0.16), "stone", jit=0.006, seed=int(40 + sz))
        # the parapet: a wall with a coping
        b.box((0, 0.55, sz * (hw - 0.3)), (BR_L, 1.1, 0.5), "rubble", jit=0.008, seed=int(50 + sz))
        b.box((0, 1.17, sz * (hw - 0.3)), (BR_L, 0.2, 0.72), "stone", jit=0.006, seed=int(60 + sz))
        # the keystone: a skull in the crown of the arch, the Order's only ornament here
        OG.skull(b, (0, -BR_D + 0.01 + BR_L * 0.27 + 0.0, sz * (hw + 0.02)), (0, 0, sz), (0, 1, 0), s=1.9)
    # the soffit: the arch's barrel, from face to face
    ring_f = [Vector((x - BR_L / 2, y - BR_D, -hw)) for x, y in hole]
    ring_b = [Vector((x - BR_L / 2, y - BR_D, hw)) for x, y in hole]
    fs = b.loft([ring_f, ring_b], "stone", closed=True, smooth=False, box_uv=0.3)
    cen = Vector((0, -BR_D + 1.2, 0))
    for f in fs:
        f.normal_update()
        if f.normal.dot(cen - f.calc_center_median()) < 0:
            f.normal_flip()
    # the deck: paving between the parapets
    b.box((0, -0.35, 0), (BR_L, 0.7, BR_W - 0.02), "stone", jit=0.004, seed=71)
    ob = b.finish()
    L.moss_colors(ob, seed=114, amount=0.3, tint=(0.4, 0.55, 0.45))
    objs.append(ob)
    DATA["BRIDGE"] = {"l": BR_L, "w": BR_W, "d": BR_D}

# =================================================================================================
# main
# =================================================================================================

def place_row(objs, order, step_fn):
    x = 0.0
    for name in order:
        for o in objs:
            if o.name == name:
                o.location = G((x, 0, 0))
                x += step_fn(name)
                break


def write_data():
    out = ["extends RefCounted", "## GENERATED by tools/blender/oss_abbey.py: the numbers the game needs from the Charnel Abbey kit.",
           "## Do not edit by hand; rerun the script.", ""]
    DATA["BAY"] = {"w": W, "t": T, "wall_h": WALL_H, "depth": DEPTH, "ridge": RIDGE, "plinth": PLINTH}
    for k in sorted(DATA):
        out.append("const %s := %s" % (k, L.gd_lit(DATA[k])))
    L.write_gd(os.path.join(L.ROOT, "core", "world", "realm", "oss_abbey_data.gd"), "\n".join(out) + "\n")


def main():
    L.reset()
    m = mats()
    objs = []
    build_bay(m, objs)
    build_bay(m, objs, blind=True)
    build_buttress(m, objs)
    build_roof(m, objs)
    build_gable(m, objs)
    build_turret(m, objs)
    build_tower(m, objs)
    build_pier(m, objs)
    build_bridge(m, objs)
    L.export(os.path.join(L.MODEL_DIR, "oss_abbey.glb"), objs)
    write_data()
    if PREVIEW:
        os.makedirs(PREVIEW, exist_ok=True)
        # the pieces side by side, then the assembled front
        def show(names):
            for o in objs:
                o.hide_render = o.name not in names
        show(["AbbeyTower"])
        L.preview(os.path.join(PREVIEW, "tower.png"), objs, look_at=(0, 22, 0), dist=70.0, views=((190, 0.12), (235, 0.08)), res=(900, 1300), lens=40)
        L.preview(os.path.join(PREVIEW, "tower_top.png"), objs, look_at=(0, 33, 0), dist=24.0, views=((195, 0.1),), res=(1000, 1000), lens=40)
        show(["AbbeyBay", "AbbeyBayBlind", "AbbeyButtress", "AbbeyRoof"])
        for o in objs:
            if o.name == "AbbeyBay":
                o.location = G((0, 0, 0))
            elif o.name == "AbbeyBayBlind":
                o.location = G((W, 0, 0))
            elif o.name == "AbbeyButtress":
                o.location = G((-W / 2, 0, 0))
            elif o.name == "AbbeyRoof":
                o.location = G((0, WALL_H, 0))
        L.preview(os.path.join(PREVIEW, "bays.png"), objs, look_at=(W / 2, 11, 0), dist=40.0, views=((172, 0.1), (215, 0.2), (150, 0.3)), res=(1200, 900), lens=40)
        show(["OssPierFoot", "OssPierShaft", "OssPierCap"])
        for o in objs:
            if o.name == "OssPierFoot":
                o.location = G((0, 0, 0))
            elif o.name == "OssPierShaft":
                o.location = G((0, PIER_FOOT, 0))
            elif o.name == "OssPierCap":
                o.location = G((0, PIER_FOOT + PIER_SEG, 0))
        L.preview(os.path.join(PREVIEW, "pier.png"), objs, look_at=(0, 4, 0), dist=16.0, views=((200, 0.15), (235, 0.3)), res=(800, 1000), lens=40)
        show(["OssBridgeSpan"])
        for o in objs:
            if o.name == "OssBridgeSpan":
                o.location = G((0, 0, 0))
        L.preview(os.path.join(PREVIEW, "bridge.png"), objs, look_at=(0, -1, 0), dist=13.0, views=((200, 0.15), (235, 0.2), (160, -0.15)), res=(1200, 800), lens=35)
        show(["AbbeyGable", "AbbeyTurret"])
        for o in objs:
            if o.name == "AbbeyGable":
                o.location = G((0, 0, 0))
            elif o.name == "AbbeyTurret":
                o.location = G((DEPTH / 2 + 3.0, 0, FZ - 0.5))
        L.preview(os.path.join(PREVIEW, "gable.png"), objs, look_at=(0, 12, 0), dist=40.0, views=((172, 0.08), (210, 0.2)), res=(1200, 1000), lens=40)


if __name__ == "__main__":
    main()
