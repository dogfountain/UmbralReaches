"""The Ossuary's own ground, by script: tools/blender/run.sh oss_ground.py -- [--preview DIR]

  art/models/oss_ground.glb   the Lantern of the Dead (Lantern, LanternLamp, LanternFlame, LanternTable, LanternFar),
                              the lych gate (LychGate, LychBell), the coffin stones (CoffinStone, CoffinStoneB),
                              the charnel walls of the Lych Way (NicheWall, NicheWallLow, NichePier) and the
                              wayside cross at its head (LychCross)
  core/world/realm/oss_ground_data.gd   the numbers the game needs (niche cells, the lamp's height, the gate's posts)

House style (r37_south_lib.py): authored in GODOT coordinates and mapped to Blender when a mesh is finished; tileable
procedural maps (ashlar, rubble, slate, oak, bone) baked into the glb with the mesh. No downloads.

The Lantern of the Dead (a lanterne des morts): the Order raised one at the head of every charnel ground so the dead
could find their count by night. A stepped octagonal base with the bearers' table at its foot, a hollow shaft with a
keeper's door, belts of skulls mortared into the courses, an open lantern of six bays under a crocketed spire and the
Open Sky's ring at the top. About 23 m: it reads on the horizon from Hearthward and the downs.
"""
import sys
import os
import math

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib
import r37_south_lib as L
importlib.reload(L)
from r37_south_lib import B, G, Vector, Matrix, np, hash3

L.TEX_DIR = os.path.join(L.BLEND_DIR, "textures", "oss_ground")
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
PREVIEW = ARGS[ARGS.index("--preview") + 1] if "--preview" in ARGS else ""
DATA = {}

# --- the lantern's numbers (Godot metres; origin on the ground at the centre) ----------------------------------------
STEP_R = [3.2, 2.7, 2.2]          ## the three octagonal steps (circumradius)
STEP_H = 0.34
BASE_R = 1.62                     ## the base block (octagonal) and its cornice
BASE_Y = (STEP_H * 3, 3.3)
SHAFT_R = (0.98, 0.9)             ## the shaft, base -> top (a little entasis)
SHAFT_Y = (3.3, 15.3)
CHAMBER_Y = (15.3, 17.9)          ## the open lantern (six bays)
RING_Y = (17.9, 18.75)            ## the cornice over the bays
SPIRE_TOP = 22.3
LAMP_Y = 16.25                    ## the lamp's flame stands here (the light's height)
OCT = math.pi / 8.0               ## octagons with a flat face to the front (-z)


# =================================================================================================
# textures
# =================================================================================================

def tex_slates(n, seed, rows=9):
    """Stone slates laid in courses (a tile is ~2.4 m): each slate thick at its tail, joints staggered, a dark
    shadow under every course, lichen and soot. -> albedo, height, rough."""
    rng = np.random.default_rng(seed)
    yy = np.arange(n)[:, None] * np.ones((1, n))
    xx = np.arange(n)[None, :] * np.ones((n, 1))
    rh = n / rows
    row = np.floor(yy / rh).astype(int)
    fy = (yy - row * rh) / rh                         # 0 at the course's top, 1 at its lower edge
    w = fbm_warp = L.fbm(n, 3.0, seed + 1)
    widths = rng.uniform(0.45, 0.9, (rows, 64)) * rh * 2.2
    edges = np.cumsum(widths, axis=1)
    off = rng.uniform(0.0, n, rows)
    ids = np.zeros((n, n), dtype=np.int32)
    dx = np.zeros((n, n))
    for r in range(rows):
        sel = row == r
        x = (xx[sel] + off[r]) % n
        k = np.searchsorted(edges[r], x)
        lo = np.where(k > 0, edges[r][np.maximum(k - 1, 0)], 0.0)
        hi = edges[r][k]
        ids[sel] = r * 64 + k
        dx[sel] = np.minimum(x - lo, hi - x)
    jt = 1.0 - L.smooth(dx, 0.0, n * 0.006)
    tail = L.smooth(fy, 0.0, 1.0)
    edge = L.smooth(fy, 0.86, 1.0)
    btone = rng.uniform(-1.0, 1.0, rows * 64 + 1)[ids]
    mid = L.fbm(n, 1.8, seed + 2)
    fine = L.fbm(n, 2.2, seed + 3)
    height = np.clip(0.25 + 0.55 * tail - 0.5 * edge - 0.35 * jt + 0.1 * (mid - 0.5) + 0.06 * (fine - 0.5) + 0.05 * (w - 0.5), 0.0, 1.0)
    tone = np.clip(0.5 + 0.3 * btone + 0.2 * (mid - 0.5) + 0.08 * (fine - 0.5), 0.0, 1.0)
    alb = L.tint(tone, (0.075, 0.08, 0.085), (0.25, 0.255, 0.26))
    alb *= (1.0 - 0.6 * edge - 0.5 * jt)[..., None]
    lich = L.smooth(L.fbm(n, 2.2, seed + 4), 0.66, 0.86) * (1.0 - edge)
    alb = alb * (1.0 - 0.6 * lich[..., None]) + np.array([0.42, 0.44, 0.34])[None, None, :] * 0.6 * lich[..., None]
    rough = np.clip(0.8 + 0.12 * (fine - 0.5) - 0.1 * lich, 0.5, 1.0)
    return alb, height, rough


def tex_bone(n, seed):
    """Old bone (a tile is ~0.4 m): ivory gone yellow-grey, fine crazing, grime in the hollows, brown stains."""
    mid = L.fbm(n, 1.8, seed)
    fine = L.fbm(n, 1.4, seed + 1)
    big = L.fbm(n, 2.8, seed + 2)
    craze = 1.0 - np.abs(L.fbm(n, 2.2, seed + 3, aniso_u=1.6) * 2.0 - 1.0)
    cracks = L.smooth(craze, 0.9, 0.98)
    height = np.clip(0.55 + 0.2 * (mid - 0.5) + 0.12 * (fine - 0.5) - 0.4 * cracks, 0.0, 1.0)
    tone = np.clip(0.55 + 0.3 * (big - 0.5) + 0.2 * (mid - 0.5), 0.0, 1.0)
    alb = L.tint(tone, (0.42, 0.38, 0.3), (0.82, 0.78, 0.68))
    stain = L.smooth(L.fbm(n, 2.4, seed + 4), 0.6, 0.85)
    alb = alb * (1.0 - 0.45 * stain[..., None]) + np.array([0.36, 0.27, 0.16])[None, None, :] * 0.45 * stain[..., None]
    alb *= (1.0 - 0.55 * cracks)[..., None]
    rough = np.clip(0.68 + 0.14 * (fine - 0.5) + 0.2 * cracks, 0.4, 1.0)
    return alb, height, rough


def mats():
    m = {}
    alb, h, r = L.tex_ashlar(1024, 7301, 7, -0.03)
    m["stone"] = L.pbr("Oss_Ashlar", (np.clip(alb * 1.32 + 0.03, 0.0, 1.0), h, r), 1.2)      # pale cold limestone
    m["stone"]["uv_mul"] = 1.95
    alb, h, r = L.tex_masonry(1024, 7302, rows=8, cold=True)
    m["rubble"] = L.pbr("Oss_Rubble", (np.clip(alb * 1.38 + 0.02, 0.0, 1.0), h, r), 1.8)
    m["rubble"]["uv_mul"] = 1.0
    m["slate"] = L.pbr("Oss_Slate", tex_slates(1024, 7303), 2.0)
    alb, h, r = L.tex_planks(512, 7304)
    m["oak"] = L.pbr("Oss_Oak", (np.clip(alb * 1.25, 0.0, 1.0), h, r), 2.4)
    m["bone"] = L.pbr("Oss_Bone", tex_bone(512, 7305), 1.4)
    m["iron"] = L.flat("Oss_Iron", (0.07, 0.065, 0.06), 0.55, 0.85)
    m["dark"] = L.flat("Oss_Dark", (0.012, 0.011, 0.011), 1.0)
    m["flame"] = L.flat("Oss_FlameCold", (0.9, 0.95, 1.0), 0.5)
    m["flame"].node_tree.nodes["Principled BSDF"].inputs["Emission Color"].default_value = (0.75, 0.9, 1.0, 1.0)
    m["flame"].node_tree.nodes["Principled BSDF"].inputs["Emission Strength"].default_value = 3.0
    return m


# =================================================================================================
# helpers
# =================================================================================================

def lathe(b, profile, mat, sides=8, off=0.0, tile=3.2, cap_top=False, jit=None):
    """A solid of revolution about +y (Godot) with an angular offset: profile [(r, y)] bottom to top. Cylindrical
    UVs: one tile is `tile` metres both ways."""
    rings = []
    for (r, y) in profile:
        ring = []
        for j in range(sides):
            an = off - math.tau * j / sides
            k = jit(an, y) if jit else 1.0
            ring.append(Vector((math.cos(an) * r * k, y, math.sin(an) * r * k)))
        rings.append(ring)
    circ = math.tau * max(r for r, _ in profile)
    tiles = max(1, round(circ / tile))
    us = [tiles * j / sides for j in range(sides)]
    acc = 0.0
    vs = [0.0]
    for i in range(1, len(profile)):
        acc += math.hypot(profile[i][0] - profile[i - 1][0], profile[i][1] - profile[i - 1][1])
        vs.append(acc / tile)
    b._loft_cyl(rings, mat, us, vs, tiles, smooth=sides > 8)
    if cap_top:
        f = b.face(rings[-1], mat)
        if f:
            b._box_uv([f], 1.0 / tile)


def pointed(w, rise, n=9):
    """A pointed (two-centred) arch's outline from the left springer over the apex to the right, as (x, y) with y 0
    at the springing and `rise` at the apex."""
    rr = w * 0.85                                     # each half's radius (> w/2: pointed)
    cx = -w / 2 + rr                                  # the left half's centre
    apex_a = math.acos((w / 2 - rr) / rr)
    half = []
    m = max(2, n // 2)
    for i in range(m + 1):
        a = math.pi - (math.pi - apex_a) * i / m
        half.append((cx + rr * math.cos(a), rr * math.sin(a)))
    top = half[-1][1]
    k = rise / top if top > 0 else 1.0
    left = [(x, y * k) for x, y in half]
    left[-1] = (0.0, rise)
    right = [(-x, y) for x, y in reversed(left[:-1])]
    return left + right


def open_door(b, base, w, h, r, mat, swing, leaf_t=0.02):
    """The Order's sign: a pointed door frame standing on `base` (its sill's middle), w wide and h tall, and its
    leaf hung on the left jamb swung `swing` radians out toward -z."""
    bx, by, bz = base
    spring = h - w * 0.62
    arch = pointed(w, w * 0.62, 10)
    pts = [(bx - w / 2, by, bz), (bx - w / 2, by + spring, bz)] + [(bx + x, by + spring + y, bz) for x, y in arch[1:-1]] + \
          [(bx + w / 2, by + spring, bz), (bx + w / 2, by, bz)]
    b.tube_path(pts, [r] * len(pts), mat, sides=5, bark=1.0, cap_end=True)
    b.tube((bx - w / 2 - r, by, bz), (bx + w / 2 + r, by, bz), r, r, mat, sides=5)
    lw = w - 2.2 * r
    lh = spring + w * 0.3
    c = Vector((bx - w / 2 + r, by + lh / 2 + r * 0.5, bz)) + Vector((math.cos(swing), 0.0, -math.sin(swing))) * (lw / 2)
    b.box(tuple(c), (lw, lh, leaf_t), mat, yaw=swing)


def oface(b, pts, mat, nrm):
    """A face whose normal looks along `nrm`."""
    f = b.face(pts, mat)
    if f is None:
        return None
    f.normal_update()
    if f.normal.dot(Vector(nrm)) < 0:
        f.normal_flip()
    return f


def frame_panel(b, origin, u, v, nrm, w, h, hole, mat, n_side=None):
    """A flat panel w x h (origin = its lower-left corner; u along, v up; nrm faces out) with an opening: `hole` is a
    closed outline [(x, y)] in panel coordinates. Built as quads between the panel's rim and the opening, both
    sampled at the same bearings round the opening's centre (no holes for the fill to get wrong)."""
    cx = sum(p[0] for p in hole) / len(hole)
    cy = sum(p[1] for p in hole) / len(hole)
    out = []
    for (x, y) in hole:
        a = math.atan2(y - cy, x - cx)
        dx, dy = math.cos(a), math.sin(a)
        ts = []
        if abs(dx) > 1e-6:
            ts += [(-cx) / dx, (w - cx) / dx]
        if abs(dy) > 1e-6:
            ts += [(-cy) / dy, (h - cy) / dy]
        t = min(t for t in ts if t > 0)
        out.append((cx + dx * t, cy + dy * t))
    P = lambda q: Vector(origin) + Vector(u) * q[0] + Vector(v) * q[1]
    faces = []
    n = len(hole)
    for i in range(n):
        j = (i + 1) % n
        f = b.face([P(out[i]), P(out[j]), P(hole[j]), P(hole[i])], mat)
        if f is None:
            continue
        f.normal_update()
        if f.normal.dot(Vector(nrm)) < 0:
            f.normal_flip()
        faces.append(f)
    # the rim corners the bearings skip
    corners = [(0, 0), (w, 0), (w, h), (0, h)]
    for c in corners:
        a = math.atan2(c[1] - cy, c[0] - cx)
        best = None
        for i in range(n):
            j = (i + 1) % n
            a0 = math.atan2(out[i][1] - cy, out[i][0] - cx)
            a1 = math.atan2(out[j][1] - cy, out[j][0] - cx)
            if _between(a, a0, a1):
                best = (i, j)
                break
        if best:
            i, j = best
            f = b.face([P(out[i]), P(c), P(out[j])], mat)
            if f is not None:
                f.normal_update()
                if f.normal.dot(Vector(nrm)) < 0:
                    f.normal_flip()
                faces.append(f)
    b._box_uv(faces, 0.16 * float(b.mats[mat].get("uv_mul", 1.0)))
    return faces


def _between(a, a0, a1):
    """Is bearing a inside the shorter arc from a0 to a1 (either way round)?"""
    d = (a1 - a0) % math.tau
    if d <= math.pi:
        return 0.0 < (a - a0) % math.tau < d
    return 0.0 < (a0 - a) % math.tau < (a0 - a1) % math.tau


def skull(b, at, out, up, s=1.0, mat="bone", dark="dark"):
    """A skull set in a wall, its face to `out` (only the front two thirds are built): cranium, brow, cheekbones,
    upper jaw and teeth; the sockets, the nose and the jaw's shadow in the dark material."""
    out = Vector(out).normalized()
    up = Vector(up).normalized()
    rt = up.cross(out).normalized()
    up = out.cross(rt).normalized()
    at = Vector(at)
    M = lambda x, y, z: at + (rt * x + up * y + out * z) * s

    def blob(c, r, seg=8, ring=6, back=0.4, m=mat):
        ret = []
        for i in range(ring + 1):
            th = math.pi * i / ring                     # 0 = top
            row = []
            for j in range(seg):
                ph = math.tau * j / seg
                x = math.sin(th) * math.cos(ph)
                z = math.sin(th) * math.sin(ph)
                y = math.cos(th)
                if z < -back:
                    z = -back
                row.append(M(c[0] + x * r[0], c[1] + y * r[1], c[2] + z * r[2]))
            ret.append(row)
        fs = []
        for i in range(ring):
            for j in range(seg):
                j2 = (j + 1) % seg
                f = b.face([ret[i][j], ret[i][j2], ret[i + 1][j2], ret[i + 1][j]], m)
                if f is not None:
                    fs.append(f)
        for f in fs:
            f.smooth = True
        b._box_uv(fs, 2.4)
        return fs

    blob((0.0, 0.03, -0.01), (0.1, 0.105, 0.1))                      # cranium
    blob((0.0, -0.045, 0.0), (0.088, 0.075, 0.085), 8, 5)            # the face's mass, cheekbones in it
    blob((0.0, -0.095, 0.03), (0.055, 0.035, 0.045), 8, 4)            # maxilla
    # the sockets: dark cups sunk into the face
    for sx in (-1.0, 1.0):
        c = Vector((sx * 0.036, -0.032, 0.0))
        rim = []
        for j in range(8):
            a = math.tau * j / 8
            p = c + Vector((math.cos(a) * 0.03, math.sin(a) * 0.028, 0.0))
            rim.append(M(p.x, p.y, 0.084 - 0.55 * (p.x * p.x + (p.y + 0.02) ** 2)))
        bottom = M(c.x, c.y, 0.04)
        for j in range(8):
            oface(b, [rim[j], rim[(j + 1) % 8], bottom], dark, out)
    oface(b, [M(-0.015, -0.078, 0.082), M(0.015, -0.078, 0.082), M(0.0, -0.05, 0.086)], dark, out)
    for k in range(6):
        x = (k - 2.5) * 0.013
        b.box(M(x, -0.128, 0.058 - abs(x) * 0.5), (0.009 * s, 0.016 * s, 0.01 * s), mat, scale_uv=2.0)
    # the shadow under the teeth (no jaw: these are the Order's counted, jaw-less)
    b.box(M(0.0, -0.142, 0.045), (0.07 * s, 0.012 * s, 0.03 * s), dark, scale_uv=1.0)


# =================================================================================================
# the Lantern of the Dead
# =================================================================================================

def build_lantern(m, objs):
    mt = {"stone": m["stone"], "slate": m["slate"], "bone": m["bone"], "dark": m["dark"], "iron": m["iron"], "oak": m["oak"]}
    b = B("Lantern", mt)
    # --- the steps and the base block (octagonal, a face to the front)
    prof = [(STEP_R[0], -0.7), (STEP_R[0], 0.0)]
    y = 0.0
    for i, r in enumerate(STEP_R):
        prof += [(r, y + STEP_H)]
        y += STEP_H
        nr = STEP_R[i + 1] if i + 1 < len(STEP_R) else BASE_R + 0.12
        prof += [(nr, y)]
    lathe(b, prof, "stone", 8, OCT, 3.2)
    y0, y1 = BASE_Y
    base = [(BASE_R + 0.12, y0), (BASE_R + 0.12, y0 + 0.22), (BASE_R, y0 + 0.32), (BASE_R - 0.04, y1 - 0.42),
            (BASE_R + 0.1, y1 - 0.34), (BASE_R + 0.16, y1 - 0.18), (BASE_R + 0.16, y1), (SHAFT_R[0] + 0.1, y1),
            (SHAFT_R[0] + 0.1, y1 + 0.18), (SHAFT_R[0], y1 + 0.26)]
    lathe(b, base, "stone", 8, OCT, 3.2)
    # the keeper's door in the front face (-z): jambs, a pointed head, the dark within, the door leaf ajar
    fz = -(BASE_R - 0.04) * math.cos(OCT)
    dw, dh = 0.8, 1.55
    for sx in (-1.0, 1.0):
        b.box((sx * (dw / 2 + 0.09), y0 + 0.32 + dh / 2, fz - 0.07), (0.18, dh, 0.16), "stone", jit=0.006, seed=11)
    arch = pointed(dw + 0.18, 0.55, 10)
    pts = [Vector((x, y0 + 0.32 + dh + yy, fz - 0.07)) for x, yy in arch]
    b.tube_path([tuple(p) for p in pts], [0.1] * len(pts), "stone", sides=6, bark=1.2, cap_end=False)
    hole = [(x + dw / 2, dh + yy * 0.9) for x, yy in pointed(dw, 0.5, 8)] + [(dw, 0.0), (0.0, 0.0)]
    door = [Vector((x - dw / 2, y0 + 0.32 + yy, fz + 0.012)) for x, yy in hole]
    f = b.face(door, "dark")
    if f:
        f.normal_update()
        if f.normal.z > 0:
            f.normal_flip()
    lv = [Vector((-dw / 2 + 0.04, y0 + 0.34, fz - 0.02)), Vector((-dw / 2 + 0.04, y0 + 0.34 + dh, fz - 0.02))]
    b.box((-dw / 2 + 0.2, y0 + 0.32 + dh / 2, fz - 0.28), (0.06, dh - 0.04, 0.62), "oak", yaw=-1.15, scale_uv=0.5)
    for k in (0.35, 1.2):
        b.box((-dw / 2 + 0.21, y0 + 0.32 + k, fz - 0.28), (0.075, 0.06, 0.6), "iron", yaw=-1.15)
    for k in range(8):
        a = OCT - math.tau * k / 8 + OCT              # the middle of face k
        o = Vector((math.cos(a), 0.0, math.sin(a)))
        if o.z < -0.9:
            continue                                  # the door's face
        rt = Vector((-o.z, 0.0, o.x))
        c = o * ((BASE_R - 0.02) * math.cos(OCT) + 0.04) + Vector((0, (y0 + y1) / 2 + 0.05, 0))
        for sgn in (-1.0, 1.0):
            d = (rt * 0.62 + Vector((0, sgn * 0.62, 0)))
            p0 = c - d
            p1 = c + d
            b.tube(tuple(p0 + (p1 - p0) * 0.12), tuple(p1 - (p1 - p0) * 0.12), 0.05, 0.05, "bone", sides=6, bark=0.4)
            for p, q in ((p0, p1), (p1, p0)):
                e = p + (q - p) * 0.1
                side = (q - p).normalized().cross(o).normalized()
                for sd in (-1.0, 1.0):
                    cc = e + side * sd * 0.045
                    b.tube(tuple(cc - (q - p).normalized() * 0.07), tuple(cc + (q - p).normalized() * 0.05), 0.048, 0.04, "bone", sides=6, bark=0.4)
        skull(b, c + o * 0.02, o, (0, 1, 0), 1.6)
    # --- the shaft: belts of moulding, two belts of skulls, slit lights
    sy0, sy1 = SHAFT_Y
    def sr(yy):
        t = (yy - sy0) / (sy1 - sy0)
        return SHAFT_R[0] + (SHAFT_R[1] - SHAFT_R[0]) * t - 0.02 * math.sin(math.pi * t)
    belts = [6.2, 9.7, 12.9]
    prof = [(sr(sy0 + 0.26), sy0 + 0.26)]
    for by in belts:
        prof += [(sr(by - 0.08), by - 0.08), (sr(by) + 0.1, by), (sr(by) + 0.1, by + 0.16), (sr(by + 0.24), by + 0.24)]
    prof += [(sr(sy1), sy1)]
    lathe(b, prof, "stone", 16, 0.0, 3.2)
    rows = [(4.0, 12, 0.0), (4.42, 12, 0.5), (10.85, 11, 0.25)]
    for ri, (yb, n, ph) in enumerate(rows):
        for k in range(n):
            a = math.tau * (k + ph) / n + 0.13
            if ri < 2 and abs(((a + math.pi / 2) + math.pi) % math.tau - math.pi) < 0.36:
                continue                                                       # over the door
            o = Vector((math.cos(a), 0.0, math.sin(a)))
            r = sr(yb) - 0.04
            if (k * 7 + ri * 3) % 11 == 4:                                    # one is gone: the hole it was mortared in
                rt = Vector((-o.z, 0, o.x))
                ring = [o * (sr(yb) + 0.006) + rt * (math.cos(math.tau * j / 8) * 0.1) + Vector((0, yb + math.sin(math.tau * j / 8) * 0.12, 0)) for j in range(8)]
                oface(b, ring, "dark", o)
                continue
            skull(b, o * r + Vector((0, yb, 0)), o, (0, 1, 0), 1.55)
    # the mouldings that frame the belts
    for yy in (3.72, 4.72, 10.55, 11.18):
        lathe(b, [(sr(yy) - 0.01, yy - 0.06), (sr(yy) + 0.09, yy - 0.02), (sr(yy) + 0.09, yy + 0.04), (sr(yy) - 0.01, yy + 0.08)], "stone", 16, 0.0, 3.2)
    for k, yy in ((0, 7.6), (2, 7.6), (1, 11.6), (3, 11.6)):
        a = math.tau * k / 4
        o = Vector((math.cos(a), 0.0, math.sin(a)))
        c = o * (sr(yy) + 0.004)
        b.box(tuple(c + Vector((0, yy, 0))), (0.1, 0.95, 0.02), "dark", yaw=-a + math.pi / 2)
        b.box(tuple(o * (sr(yy) + 0.02) + Vector((0, yy + 0.52, 0))), (0.26, 0.1, 0.06), "stone", yaw=-a + math.pi / 2)
    # --- the lantern: a corbelled sill, six piers, pointed heads with spandrels, the cornice ring
    cy0, cy1 = CHAMBER_Y
    sill = [(sr(sy1), sy1), (sr(sy1) + 0.06, sy1 + 0.1), (1.12, sy1 + 0.3), (1.12, cy0 + 0.25), (0.62, cy0 + 0.25)]
    lathe(b, sill, "stone", 12, 0.0, 3.2, cap_top=False)
    f = b.face([Vector((math.cos(-math.tau * j / 12) * 0.62, cy0 + 0.25, math.sin(-math.tau * j / 12) * 0.62)) for j in range(12)], "stone")
    for k in range(12):                                                         # corbels under the sill
        a = math.tau * k / 12 + math.pi / 12
        o = Vector((math.cos(a), 0.0, math.sin(a)))
        b.box(tuple(o * (sr(sy1) + 0.09) + Vector((0, sy1 - 0.12, 0))), (0.16, 0.28, 0.2), "stone", yaw=-a, taper=1.3)
    ph = cy1 - (cy0 + 0.25) - 0.7                                               # the piers' height to the springing
    pr = 0.9
    for k in range(6):
        a = math.tau * k / 6
        o = Vector((math.cos(a), 0.0, math.sin(a)))
        c = o * pr
        b.box(tuple(c + Vector((0, cy0 + 0.25 + ph / 2, 0))), (0.34, ph, 0.3), "stone", yaw=-a + math.pi / 2, jit=0.004, seed=k)
        b.box(tuple(c + Vector((0, cy0 + 0.25 + ph + 0.06, 0))), (0.42, 0.12, 0.38), "stone", yaw=-a + math.pi / 2)
        b.box(tuple(c + Vector((0, cy0 + 0.31, 0))), (0.42, 0.12, 0.38), "stone", yaw=-a + math.pi / 2)
    spring = cy0 + 0.25 + ph + 0.12
    for k in range(6):
        a0 = math.tau * k / 6
        a1 = math.tau * (k + 1) / 6
        am = (a0 + a1) / 2
        p0 = Vector((math.cos(a0), 0, math.sin(a0))) * pr
        p1 = Vector((math.cos(a1), 0, math.sin(a1))) * pr
        tang = (p1 - p0).normalized()
        nrm = Vector((math.cos(am), 0, math.sin(am)))
        w = (p1 - p0).length - 0.3
        mid = (p0 + p1) / 2
        arch = pointed(w, 0.55, 10)
        apts = [mid + tang * x + Vector((0, spring + yy, 0)) + nrm * 0.02 for x, yy in arch]
        b.tube_path([tuple(p) for p in apts], [0.07] * len(apts), "stone", sides=5, bark=1.2, cap_end=False)
        # the spandrels: the wall between the head and the cornice, a face out and a face in
        top = cy1
        for side, dz in ((1.0, 0.14), (-1.0, -0.14)):
            P = [mid + tang * x + Vector((0, spring + yy, 0)) + nrm * dz for x, yy in arch]
            lft = mid - tang * (w / 2 + 0.15) + Vector((0, top, 0)) + nrm * dz
            rgt = mid + tang * (w / 2 + 0.15) + Vector((0, top, 0)) + nrm * dz
            lb = mid - tang * (w / 2 + 0.15) + Vector((0, spring, 0)) + nrm * dz
            rb = mid + tang * (w / 2 + 0.15) + Vector((0, spring, 0)) + nrm * dz
            poly = [lb] + P + [rb, rgt, lft]
            half = len(arch) // 2
            fs = []
            fa = b.face([lb, P[0], P[1], lft], "stone")
            fs.append(fa)
            for i in range(1, half):
                fs.append(b.face([P[i], P[i + 1], lft], "stone") if True else None)
            fs.append(b.face([P[half], rgt, lft], "stone"))
            for i in range(half, len(P) - 1):
                fs.append(b.face([P[i], P[i + 1], rgt], "stone"))
            fs.append(b.face([P[-1], rb, rgt], "stone"))
            fs = [f for f in fs if f is not None]
            for f in fs:
                f.normal_update()
                if f.normal.dot(nrm * side) < 0:
                    f.normal_flip()
            b._box_uv(fs, 0.16 * 1.95)
    ring = [(0.82, RING_Y[0]), (1.14, RING_Y[0]), (1.14, RING_Y[0] + 0.3), (1.24, RING_Y[0] + 0.42), (1.24, RING_Y[1]),
            (1.3, RING_Y[1]), (1.3, RING_Y[1] + 0.12)]
    lathe(b, ring, "stone", 12, 0.0, 3.2)
    lathe(b, [(0.82, RING_Y[0] - 0.01), (0.82, cy1 - 0.02)], "stone", 12, 0.0, 3.2)
    for k in range(18):                                                         # a corbel table under the cornice
        a = math.tau * k / 18
        o = Vector((math.cos(a), 0.0, math.sin(a)))
        b.box(tuple(o * 1.2 + Vector((0, RING_Y[0] + 0.52, 0))), (0.12, 0.16, 0.14), "stone", yaw=-a)
    # --- the spire: eight faces of slate, crockets up the hips, the Open Sky's ring on an iron rod
    s0 = RING_Y[1] + 0.12
    spire = [(1.22, s0), (1.0, s0 + 0.35), (0.04, SPIRE_TOP)]
    lathe(b, spire, "slate", 8, OCT, 2.4)
    for k in range(8):
        a = OCT - math.tau * k / 8
        o = Vector((math.cos(a), 0.0, math.sin(a)))
        for i in range(5):
            t = (i + 0.7) / 6.0
            yy = s0 + 0.35 + (SPIRE_TOP - s0 - 0.35) * t
            r = 1.0 + (0.04 - 1.0) * t
            base = o * (r * 0.97) + Vector((0, yy, 0))
            hk = [tuple(base), tuple(base + o * 0.14 + Vector((0, 0.08, 0))), tuple(base + o * 0.2 + Vector((0, -0.02, 0)))]
            b.tube_path(hk, [0.06, 0.045, 0.02], "stone", sides=4, bark=1.0)
    # the Order's sign on an iron rod: the Open Door, a pointed frame with its leaf swung out
    b.tube((0, SPIRE_TOP - 0.3, 0), (0, SPIRE_TOP + 0.75, 0), 0.035, 0.03, "iron", sides=6)
    open_door(b, (0.0, SPIRE_TOP + 0.75, 0.0), 0.5, 0.82, 0.028, "iron", 1.15)
    ob = b.finish()
    L.moss_colors(ob, seed=3, amount=0.55, tint=(0.62, 0.66, 0.52))
    objs.append(ob)
    DATA["LANTERN"] = {"lamp_y": LAMP_Y, "door": [0.0, y0 + 0.32, round(fz, 3)], "base_r": STEP_R[0], "height": SPIRE_TOP + 1.6,
                       "shaft_r": SHAFT_R[0], "chamber": [CHAMBER_Y[0], CHAMBER_Y[1]], "step_h": STEP_H}

    # --- the lamp in the lantern: a pricket and a cresset of iron straps; the flame apart (its own material)
    lb = B("LanternLamp", {"iron": m["iron"]})
    lb.tube((0, cy0 + 0.25, 0), (0, LAMP_Y - 0.25, 0), 0.04, 0.03, "iron", sides=6)
    for k in range(6):
        a = math.tau * k / 6
        o = Vector((math.cos(a), 0, math.sin(a)))
        lb.tube_path([(0, LAMP_Y - 0.28, 0), tuple(o * 0.2 + Vector((0, LAMP_Y - 0.2, 0))), tuple(o * 0.3 + Vector((0, LAMP_Y + 0.05, 0)))],
                     [0.02, 0.018, 0.015], "iron", sides=4)
    ring2 = [(math.cos(math.tau * j / 12) * 0.3, LAMP_Y + 0.05, math.sin(math.tau * j / 12) * 0.3) for j in range(13)]
    lb.tube_path(ring2, [0.016] * 13, "iron", sides=4, cap_end=False)
    objs.append(lb.finish())
    fb = B("LanternFlame", {"flame": m["flame"]})
    for k, (dx, dz, h) in enumerate(((0.0, 0.0, 0.9), (0.12, 0.05, 0.6), (-0.1, 0.08, 0.55), (0.02, -0.12, 0.62))):
        prof = [(0.001, 0.0), (0.09, 0.08), (0.11, 0.2), (0.07, h * 0.6), (0.001, h)]
        rings = []
        for (r, yy) in prof:
            rings.append([Vector((dx + math.cos(math.tau * j / 7) * r, LAMP_Y - 0.12 + yy, dz + math.sin(math.tau * j / 7) * r)) for j in range(7)])
        fb.loft(rings, "flame", closed=True)
    objs.append(fb.finish(recalc=True))

    # --- the bearers' table at the foot (a slab on two piers; placed apart so it faces the way in)
    tb = B("LanternTable", {"stone": m["stone"]})
    tb.box((0, 0.84, 0), (2.1, 0.16, 0.95), "stone", jit=0.012, seed=21)
    tb.box((0, 0.96, 0), (1.9, 0.08, 0.8), "stone", jit=0.008, seed=22)
    for sx in (-0.72, 0.72):
        tb.box((sx, 0.38, 0), (0.34, 1.0, 0.6), "stone", jit=0.01, seed=23, taper=0.9)
    ob = tb.finish()
    L.moss_colors(ob, seed=5, amount=0.6, tint=(0.62, 0.66, 0.52))
    objs.append(ob)

    # --- the far mesh: the same silhouette in ~150 triangles (FarDetail draws it from 100 m out)
    far = B("LanternFar", {"stone": L.flat("Oss_Far", (0.2, 0.2, 0.21), 1.0)})
    prof = [(STEP_R[0], -0.5), (STEP_R[1], STEP_H * 2), (BASE_R + 0.1, BASE_Y[0]), (BASE_R + 0.12, BASE_Y[1]), (SHAFT_R[0], BASE_Y[1] + 0.2),
            (SHAFT_R[1], SHAFT_Y[1]), (1.12, SHAFT_Y[1] + 0.3), (1.0, CHAMBER_Y[1]), (1.28, RING_Y[1]), (0.04, SPIRE_TOP + 0.6)]
    lathe(far, prof, "stone", 8, OCT, 3.2)
    objs.append(far.finish())


# =================================================================================================
# the lych gate
# =================================================================================================

GATE_W = 3.0           ## the passage's clear width (along x)
GATE_L = 4.2           ## along the way (z)
WALL_H = 0.95


def build_gate(m, objs):
    mt = {"rubble": m["rubble"], "stone": m["stone"], "oak": m["oak"], "slate": m["slate"], "iron": m["iron"]}
    b = B("LychGate", mt)
    hx = GATE_W / 2 + 0.25
    for sx in (-1.0, 1.0):
        b.box((sx * hx, (WALL_H - 0.45) / 2, 0.0), (0.5, WALL_H + 0.45, GATE_L), "rubble", jit=0.012, seed=31 + int(sx))
        b.box((sx * hx, WALL_H + 0.05, 0.0), (0.62, 0.1, GATE_L + 0.12), "stone", jit=0.006, seed=33 + int(sx))
        # sole plate, posts, wall plate
        b.box((sx * hx, WALL_H + 0.16, 0.0), (0.22, 0.12, GATE_L - 0.1), "oak", scale_uv=0.5)
        for z in (-GATE_L / 2 + 0.22, 0.0, GATE_L / 2 - 0.22):
            b.box((sx * hx, WALL_H + 0.22 + 0.86, z), (0.2, 1.72, 0.2), "oak", scale_uv=0.5, jit=0.004, seed=int(z * 10) + 40)
        b.box((sx * hx, WALL_H + 2.02, 0.0), (0.24, 0.2, GATE_L + 0.3), "oak", scale_uv=0.5)
    top = WALL_H + 2.12
    ridge = top + 1.95
    for z in (-GATE_L / 2 + 0.22, GATE_L / 2 - 0.22):
        b.box((0.0, top - 0.06, z), (2 * hx + 0.3, 0.24, 0.22), "oak", scale_uv=0.5)              # tie beam
        b.box((0.0, (top + ridge) / 2 + 0.02, z), (0.18, ridge - top - 0.1, 0.18), "oak", scale_uv=0.5)   # king post
        for sx in (-1.0, 1.0):                                                                     # arch braces, squared oak
            pts = []
            for i in range(7):
                t = i / 6
                a = math.pi * 0.5 * t
                pts.append(Vector((sx * (hx - 0.1 - 0.75 * (1 - math.cos(a))), top - 0.95 + 0.85 * math.sin(a), z)))
            for i in range(6):
                c = (pts[i] + pts[i + 1]) / 2
                d = pts[i + 1] - pts[i]
                b.box(tuple(c), (d.length + 0.04, 0.13, 0.12), "oak", roll=math.atan2(d.y, d.x), scale_uv=0.5)
            # struts from the tie beam up to the rafters
            d = Vector((sx * 0.4, top + 1.2, z)) - Vector((sx * 0.85, top + 0.05, z))
            b.box(tuple(Vector((sx * 0.625, top + 0.625, z))), (d.length, 0.12, 0.12), "oak", roll=math.atan2(d.y, d.x), scale_uv=0.5)
    # the roof: two pitches of stone slate on rafters and barge boards; the gables are open
    eave = hx + 0.55
    oh = GATE_L / 2 + 0.5
    for sx in (-1.0, 1.0):
        lo = Vector((sx * eave, top - 0.25, 0.0))
        hi = Vector((0.0, ridge, 0.0))
        d = hi - lo
        L_ = d.length
        c = (lo + hi) / 2
        pitch = math.atan2(d.y, abs(d.x))
        b.box(tuple(c + Vector((0, 0.07, 0))), (L_ + 0.1, 0.13, 2 * oh), "slate", roll=sx * -pitch, scale_uv=0.16 / 0.75)
        for z in (-oh + 0.04, oh - 0.04):
            b.box(tuple(c + Vector((0, -0.06, z))), (L_ + 0.05, 0.22, 0.06), "oak", roll=sx * -pitch, scale_uv=0.5)
        for z in (-1.4, -0.47, 0.47, 1.4):
            b.box(tuple(c + Vector((0, -0.07, z))), (L_, 0.09, 0.08), "oak", roll=sx * -pitch, scale_uv=0.5)
    b.box((0.0, ridge + 0.04, 0.0), (0.24, 0.12, 2 * oh + 0.06), "slate", scale_uv=0.3)
    ob = b.finish()
    L.moss_colors(ob, seed=7, amount=0.7, tint=(0.5, 0.58, 0.38))
    objs.append(ob)
    # the lych bell, hung in the front gable from the king post
    bb = B("LychBell", {"iron": m["iron"]})
    by = top + 0.95
    prof = [(0.02, by + 0.26), (0.1, by + 0.24), (0.12, by + 0.12), (0.14, by - 0.02), (0.19, by - 0.1), (0.2, by - 0.13)]
    rings = [[Vector((math.cos(math.tau * j / 12) * r, yy, math.sin(math.tau * j / 12) * r - GATE_L / 2 + 0.22)) for j in range(12)] for r, yy in prof]
    bb.loft(rings, "iron")
    bb.box((0.0, by + 0.3, -GATE_L / 2 + 0.22), (0.24, 0.06, 0.06), "iron")
    bb.tube((0, by - 0.05, -GATE_L / 2 + 0.22), (0, by - 0.16, -GATE_L / 2 + 0.22), 0.025, 0.035, "iron", sides=5)
    objs.append(bb.finish(recalc=True))
    DATA["GATE"] = {"w": GATE_W, "l": GATE_L, "wall_x": round(hx, 3), "wall_h": WALL_H, "top": round(top, 3), "ridge": round(ridge, 3),
                    "eave": round(eave, 3), "overhang": round(oh, 3)}


# =================================================================================================
# coffin stones, the charnel walls, the wayside cross
# =================================================================================================

def build_stones(m, objs):
    for name, seed, broken in (("CoffinStone", 51, False), ("CoffinStoneB", 52, True)):
        b = B(name, {"stone": m["stone"], "dark": m["dark"]})
        L_ = 2.15
        b.box((0, -0.05, 0), (L_, 0.62, 0.72), "stone", cuts=3, jit=0.03, seed=seed, taper=0.92)
        b.box((0, -0.28, 0), (L_ + 0.24, 0.3, 0.96), "stone", cuts=2, jit=0.04, seed=seed + 1)
        # the Order's ring cut in its head
        ring = [(L_ / 2 - 0.02, 0.0 + math.sin(math.tau * j / 14) * 0.17 - 0.02, math.cos(math.tau * j / 14) * 0.17) for j in range(15)]
        b.tube_path([(x + 0.012, y, z) for x, y, z in ring], [0.022] * 15, "stone", sides=4, cap_end=False)
        if broken:
            b.box((-L_ / 2 + 0.28, 0.25, 0.12), (0.5, 0.22, 0.4), "stone", yaw=0.4, pitch=0.3, jit=0.03, seed=seed + 2)
        ob = b.finish()
        L.moss_colors(ob, seed=seed, amount=0.85, tint=(0.56, 0.62, 0.44))
        objs.append(ob)


NW_L = 4.0
NW_T = 0.72
NICHE_X = (-1.25, 0.0, 1.25)
NICHE_W = 0.66


def _niche_wall(b, h, rows, broken=-1):
    """A battered rubble wall NW_L long, its face to -z (the lane), its back sunk in the bank, with arched niches
    in `rows` (each (sill, height)): a stone frame round every niche, the niche cut back into the wall. The face
    leans back `batter` over its height (every panel sheared alike, so no seam opens between them)."""
    zf = -NW_T / 2
    batter = 0.12
    zat = lambda y: zf + batter * max(y, 0.0) / h
    shear = Vector((0.0, 1.0, batter / h))
    cells = []
    col_w = NW_L / 3
    for ci, cx in enumerate(NICHE_X):
        x0 = cx - col_w / 2
        last = -0.5
        for ri, (sill, nh) in enumerate(rows):
            if sill - last > 0.01:
                oface(b, [Vector((x0, last, zat(last))), Vector((x0 + col_w, last, zat(last))),
                          Vector((x0 + col_w, sill, zat(sill))), Vector((x0, sill, zat(sill)))], "rubble", (0, 0, -1))
            top = sill + nh + 0.18
            arch = pointed(NICHE_W, 0.3, 8)
            hole = [((x + NICHE_W / 2) + (col_w - NICHE_W) / 2, (nh - 0.3) + yy) for x, yy in arch] + \
                   [((col_w + NICHE_W) / 2, 0.02), ((col_w - NICHE_W) / 2, 0.02)]
            frame_panel(b, (x0, sill, zat(sill)), (1, 0, 0), tuple(shear), (0, 0, -1), col_w, top - sill, hole, "rubble")
            # the niche cut back into the wall: jambs, head and floor in dressed stone, the back in shadow
            depth = 0.48
            ring_f = [Vector((x0 + hx_, sill + hy_, zat(sill + hy_))) for hx_, hy_ in hole]
            ring_b = [Vector((x0 + (hx_ - col_w / 2) * 0.92 + col_w / 2, sill + 0.02 + (hy_ - 0.02) * 0.94, zat(sill + hy_) + depth)) for hx_, hy_ in hole]
            fs = b.loft([ring_f, ring_b], "stone", closed=True, smooth=False, box_uv=0.3)
            cen = Vector((x0 + col_w / 2, sill + nh / 2, zat(sill + nh / 2) + depth * 0.5))
            for f in fs:
                f.normal_update()
                if f.normal.dot(cen - f.calc_center_median()) < 0:
                    f.normal_flip()
            oface(b, list(reversed(ring_b)), "stone" if broken != ci * 10 + ri else "rubble", (0, 0, -1))
            cells.append([round(x0 + col_w / 2, 3), round(sill + 0.02, 3), round(zat(sill) + depth * 0.55, 3), round(nh, 3)])
            last = top
        oface(b, [Vector((x0, last, zat(last))), Vector((x0 + col_w, last, zat(last))),
                  Vector((x0 + col_w, h, zat(h))), Vector((x0, h, zat(h)))], "rubble", (0, 0, -1))
    # the back, the ends and the coping
    zb = NW_T / 2
    oface(b, [Vector((-NW_L / 2, -0.5, zb)), Vector((-NW_L / 2, h, zb)), Vector((NW_L / 2, h, zb)), Vector((NW_L / 2, -0.5, zb))], "rubble", (0, 0, 1))
    for sx in (-1.0, 1.0):
        oface(b, [Vector((sx * NW_L / 2, -0.5, zat(-0.5))), Vector((sx * NW_L / 2, -0.5, zb)), Vector((sx * NW_L / 2, h, zb)),
                  Vector((sx * NW_L / 2, h, zat(h)))], "rubble", (sx, 0, 0))
    for k in range(5):
        x = -NW_L / 2 + 0.4 + k * 0.8
        b.box((x, h + 0.08, (zat(h) + zb) / 2 + 0.01), (0.78, 0.17, zb - zat(h) + 0.18), "stone", jit=0.012, seed=60 + k, yaw=0.02 * (k - 2))
    allf = [f for f in b.bm.faces if f.material_index == b.keys.index("rubble")]
    b._box_uv(allf, 0.16 * float(b.mats["rubble"].get("uv_mul", 1.0)) * 2.6)          # ~0.3 m courses: coursed rubble, not ashlar
    return cells


def build_walls(m, objs):
    mt = {"rubble": m["rubble"], "stone": m["stone"], "dark": m["dark"]}
    b = B("NicheWall", mt)
    cells = _niche_wall(b, 2.9, [(0.42, 0.78), (1.62, 0.74)])
    ob = b.finish()
    L.moss_colors(ob, seed=61, amount=0.8, tint=(0.5, 0.58, 0.4))
    objs.append(ob)
    b = B("NicheWallLow", mt)
    cells_low = _niche_wall(b, 1.75, [(0.42, 0.8)])
    ob = b.finish()
    L.moss_colors(ob, seed=62, amount=0.9, tint=(0.5, 0.58, 0.4))
    objs.append(ob)
    b = B("NichePier", mt)
    b.box((0, 1.15, 0), (0.92, 3.3, 0.92), "rubble", cuts=2, jit=0.015, seed=70, taper=0.9)
    b.box((0, 2.9, 0), (1.04, 0.16, 1.04), "stone", jit=0.008, seed=71)
    b.box((0, 3.1, 0), (0.8, 0.26, 0.8), "stone", taper=0.15)
    ob = b.finish()
    L.moss_colors(ob, seed=72, amount=0.8, tint=(0.5, 0.58, 0.4))
    objs.append(ob)
    DATA["NICHE_CELLS"] = cells
    DATA["NICHE_CELLS_LOW"] = cells_low
    DATA["NICHE_WALL"] = {"l": NW_L, "t": NW_T, "h": 2.9, "h_low": 1.75}


def build_cross(m, objs):
    b = B("LychCross", {"stone": m["stone"], "iron": m["iron"]})
    b.box((0, -0.15, 0), (1.7, 0.6, 1.7), "stone", cuts=1, jit=0.02, seed=81)
    b.box((0, 0.3, 0), (1.15, 0.3, 1.15), "stone", cuts=1, jit=0.015, seed=82)
    b.box((0, 0.6, 0), (0.62, 0.3, 0.62), "stone", jit=0.01, seed=83)
    b.box((0, 2.2, 0), (0.3, 2.95, 0.3), "stone", taper=0.82, jit=0.006, seed=84)
    # the head: the Order's sign, the Open Door, cut in stone (a pointed frame, the leaf standing ajar)
    b.box((0, 3.72, 0), (0.42, 0.12, 0.34), "stone", jit=0.006, seed=86)
    open_door(b, (0.0, 3.78, 0.0), 0.78, 1.05, 0.075, "stone", 1.0, leaf_t=0.07)
    ob = b.finish()
    L.moss_colors(ob, seed=85, amount=0.8, tint=(0.56, 0.62, 0.44))
    objs.append(ob)


# =================================================================================================
# main
# =================================================================================================

def place_row(objs, order, step):
    x = 0.0
    for name in order:
        for o in objs:
            if o.name == name:
                o.location = G((x, 0, 0))
                x += step
                break


def write_data():
    out = ["extends RefCounted", "## GENERATED by tools/blender/oss_ground.py: the numbers the game needs from the Ossuary's ground kit.",
           "## Do not edit by hand; rerun the script.", ""]
    for k in sorted(DATA):
        out.append("const %s := %s" % (k, L.gd_lit(DATA[k])))
    L.write_gd(os.path.join(L.ROOT, "core", "world", "realm", "oss_ground_data.gd"), "\n".join(out) + "\n")


def main():
    L.reset()
    m = mats()
    objs = []
    build_lantern(m, objs)
    build_gate(m, objs)
    build_stones(m, objs)
    build_walls(m, objs)
    build_cross(m, objs)
    L.export(os.path.join(L.MODEL_DIR, "oss_ground.glb"), objs)
    write_data()
    if PREVIEW:
        os.makedirs(PREVIEW, exist_ok=True)
        keep = {o.name: o for o in objs}
        for o in objs:
            o.hide_render = o.name not in ("Lantern", "LanternLamp", "LanternFlame")
        L.preview(os.path.join(PREVIEW, "lantern.png"), objs, look_at=(0, 11, 0), dist=34.0, views=((20, 0.12), (200, 0.35), (70, -0.05)), res=(900, 1200), lens=45)
        L.preview(os.path.join(PREVIEW, "lantern_top.png"), objs, look_at=(0, 18.5, 0), dist=6.5, views=((30, 0.15),), res=(1000, 1000), lens=40)
        L.preview(os.path.join(PREVIEW, "lantern_foot.png"), objs, look_at=(0, 3.5, 0), dist=8.0, views=((15, 0.2),), res=(1000, 1000), lens=40)
        for o in objs:
            o.hide_render = o.name not in ("LychGate", "LychBell")
        L.preview(os.path.join(PREVIEW, "gate.png"), objs, look_at=(0, 2.2, 0), dist=11.0, views=((30, 0.2), (150, 0.12)), res=(1200, 900), lens=35)
        for o in objs:
            o.hide_render = o.name not in ("NicheWall", "NicheWallLow", "NichePier", "CoffinStone", "CoffinStoneB", "LychCross")
        place_row(objs, ["NicheWall", "NichePier", "NicheWallLow", "CoffinStone", "CoffinStoneB", "LychCross"], 4.6)
        L.preview(os.path.join(PREVIEW, "walls.png"), objs, look_at=(11.5, 1.5, 0), dist=22.0, views=((172, 0.12), (150, 0.3)), res=(1600, 700), lens=35)
        L.preview(os.path.join(PREVIEW, "niche.png"), objs, look_at=(0, 1.4, 0), dist=5.5, views=((165, 0.1),), res=(1000, 800), lens=35)


main()
