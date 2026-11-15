"""The Choir House on the Ashen Rift's east rim, modelled by script (no scans, no downloads).

  rift_choir_house.glb   the hall where the Stair's choir lodged and practised, overrun by the first lava flow the night
                         the rift brimmed: a roofless nave of coursed ashlar (7.4 x 14 m), the west gable whole with its
                         pointed door and an empty bell-cote, the side walls buttressed and lit by lancets, the north
                         wall's middle fallen in, the east gable burst open where the flow broke out towards the fen.
                         Inside, the crust stands to the window sills (the terrain's flow is the floor: core/world/
                         realm/rift/scorch.gd lifts it there); the choir's stall ends and the cantor's lectern stand out
                         of it; the roof's charred rafters lie across it; two tongues of lava froze where they spilled
                         over the south sills.

  tools/blender/run.sh rift_choir_house.py -- [--preview DIR]

Frame: 1 BU = 1 m, Blender Z up -> Godot Y up, Blender +Y -> Godot -Z. Origin: the middle of the west doorway's threshold
on the hall's old floor (z 0); +Y runs into the hall towards the east gable, +X to the south wall (the placement turns
+Y down the flow). Parts are named <part>__<set>: ashlar (the r37 coursed set), char (rafters and stalls burned black:
dressed in Godot as charred timber), crust (frozen lava: the scorch's crust with warm seams), iron. Choir-colonly: the
walls, buttresses and lectern as boxes; the doorways and the breach are open.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import bmesh
from mathutils import Vector, Matrix
import r37_west as W
import wonder_threshold_chapel as C

MODELS = W.MODELS
BLEND = W.BLEND
C.TILE.update({"char": 2.0, "crust": 3.0})

X_ = Vector((1, 0, 0))
Y_ = Vector((0, 1, 0))
Z_ = Vector((0, 0, 1))
HW = 3.7             # half width, outer face
T = 0.75             # wall thickness
L = 14.0             # length, outer (y 0 .. L)
EAVE = 5.4
APEX = 9.0
FOOT = -1.0          # the walls go down this far (the flow rose round them; nothing floats)
DOOR_A, DOOR_ZS = 0.95, 2.6          # the west door: half width, springing
WIN_A, WIN_ZS, WIN_SILL = 0.42, 3.3, 1.55
WIN_Y = (3.6, 7.0, 10.4)
CRUST = 1.35         # where the flow stands inside (the terrain's lift, scorch.gd F1)


def gable_top(x):
    """Height of a gable's raking edge above x."""
    return EAVE + (APEX - EAVE) * max(0.0, 1.0 - abs(x) / HW)


def west_hole(u, z):
    """The west gable's openings (u across the wall from -HW to HW): the door and a lancet over it."""
    x = u - HW
    if C.pointed(DOOR_A, DOOR_ZS, x, z, 0.04) and z > FOOT:
        return True
    if z > 5.2 and C.pointed(0.32, 6.6, x, z, 0.03) and z > 5.6:
        return True
    return z > gable_top(x) - 0.02


def east_hole(u, z, rng_top):
    """The east gable: burst from the floor up in a ragged breach, its upper part fallen on the north side."""
    x = u - HW
    if z > gable_top(x) - 0.02:
        return True
    breach = 1.8 + 0.35 * math.sin(z * 2.3 + 1.0) + 0.25 * math.sin(z * 5.1)
    if z < 3.4 + 0.5 * math.cos(x * 1.7) and -1.6 < x + 0.2 * math.sin(z * 3.0) < breach:
        return True
    # above the eaves the gable is gone but for a stub on the south corner; the north corner fell lower still
    if z > EAVE - 0.3 + rng_top(x) and x < 2.0:
        return True
    if x < -1.8 and z > EAVE - 1.4 + (x + HW) * 0.6 + rng_top(x):
        return True
    return False


def side_hole(u, z, north):
    """A side wall (u along y): the lancets; on the north wall the middle reach is fallen to ~2 m with a ragged top."""
    if z > EAVE - 0.01:
        return True
    for wy in WIN_Y:
        if C.pointed(WIN_A, WIN_ZS, u - wy, z, 0.03) and z > WIN_SILL:
            return True
    if north:
        if 4.4 < u < 10.6:
            top = 2.1 + 0.9 * abs(math.sin(u * 1.3)) + 0.5 * math.sin(u * 3.7 + 0.4)
            top += 2.6 * (1.0 - min(1.0, min(u - 4.4, 10.6 - u) / 1.6))       # the break's ends stand higher
            if z > top:
                return True
    return False


def buttress(B, base, out, rng, h=4.6):
    """A stepped buttress: three stages, each set back, a weathered slope on top."""
    ex = out.cross(Z_).normalized()
    ey = out
    stages = [(FOOT, 2.3, 0.95, 0.85), (2.3, 3.8, 0.85, 0.65), (3.8, h, 0.75, 0.45)]
    for (z0, z1, w, d) in stages:
        c = base + out * (d * 0.5) + Z_ * ((z0 + z1) * 0.5)
        B.blk("ashlar", c, (w, d, z1 - z0), ex, ey, Z_, bevel=0.03, jit=0.008, sub=1, tone=rng.uniform(0.86, 0.98))
        # the set-off: a sloped weathering course
        c2 = base + out * (d * 0.5) + Z_ * (z1 + 0.08)
        B.blk("ashlar", c2, (w + 0.06, d + 0.04, 0.16), ex, ey, Z_, bevel=0.02, jit=0.004, tone=1.02, taper=(1.0, 1.0))
    B.colbox(base + out * 0.45 + Z_ * ((FOOT + h) * 0.5), (0.95, 0.9, h - FOOT), ex, ey, Z_)


def build():
    B = C.Build(9091)
    rng = B.rng
    rough_top = lambda x: 0.35 * math.sin(x * 4.1) + 0.2 * math.sin(x * 9.3 + 1.0)
    # --- the walls ---------------------------------------------------------------------------------
    # west gable (y 0 .. T): runs along +X
    C.course_wall(B, Vector((-HW, T * 0.5, 0.0)), X_, T, -1, HW * 2.0, FOOT, APEX + 0.1,
                  hole=west_hole, tone=(0.82, 1.0), rough=0.004, sub=0)
    # east gable (y L-T .. L)
    C.course_wall(B, Vector((-HW, L - T * 0.5, 0.0)), X_, T, -1, HW * 2.0, FOOT, APEX + 0.1,
                  hole=lambda u, z: east_hole(u, z, rough_top), tone=(0.74, 0.96), rough=0.012, sub=0)
    # side walls between the gables (u along +Y from y = T to L - T)
    for side in (1, -1):
        x = side * (HW - T * 0.5)
        C.course_wall(B, Vector((x, T, 0.0)), Y_, T, 1, L - 2.0 * T, FOOT, EAVE,
                      hole=lambda u, z, n=(side < 0): side_hole(u + T, z, n), tone=(0.8, 1.0), rough=0.006 if side > 0 else 0.014, sub=0)
    # the rakes: a band of walling under each raking edge (the coursed blocks stop in steps below it) and a coping on it
    def rake(y, x0, x1, broken=False):
        z0, z1 = gable_top(x0), gable_top(x1)
        a = Vector((x0, y, z0))
        b = Vector((x1, y, z1))
        d = b - a
        ln = d.length
        ey = d / ln
        ez = Vector((-ey.z, 0.0, ey.x)) if ey.x > 0 else Vector((ey.z, 0.0, -ey.x))
        if ez.z < 0:
            ez = -ez
        ex = Y_
        n = max(2, int(ln / 0.85))
        for i in range(n):
            if broken and i > n * 0.45:
                break
            t0, t1 = i / n, (i + 1) / n
            c = a + d * ((t0 + t1) * 0.5)
            B.blk("ashlar", c - ez * 0.32, (T - 0.02, ln / n - 0.02, 0.62), ex, ey, ez, bevel=0.02, jit=0.004, tone=rng.uniform(0.86, 0.98))
            B.blk("ashlar", c + ez * 0.1, (T + 0.16, ln / n - 0.03, 0.22), ex, ey, ez, bevel=0.03, jit=0.004, tone=1.06)
    rake(T * 0.5, -HW, 0.0)
    rake(T * 0.5, HW, 0.0)
    # (the east gable keeps no coping: what stands of it ends in broken courses)
    # the apex stone the bell-cote stands on
    B.blk("ashlar", Vector((0.0, T * 0.5, APEX + 0.05)), (1.5, T + 0.16, 0.3), X_, Y_, Z_, bevel=0.03, jit=0.004, tone=1.05)
    # dressings: the door's voussoir ring and hood, the lancets' jambs, a corbel table under the south eaves
    for i in range(13):
        a0 = math.pi * i / 13.0
        a1 = math.pi * (i + 1) / 13.0
        # two-centred: each half on its own circle
        def arc(a):
            if a <= math.pi * 0.5:
                th = a / (math.pi * 0.5) * math.acos(0.5)
                return Vector((-DOOR_A + 2.0 * DOOR_A * math.cos(th) - 0.0, 0, DOOR_ZS + 2.0 * DOOR_A * math.sin(th)))
            th = (math.pi - a) / (math.pi * 0.5) * math.acos(0.5)
            return Vector((DOOR_A - 2.0 * DOOR_A * math.cos(th), 0, DOOR_ZS + 2.0 * DOOR_A * math.sin(th)))
        p0, p1 = arc(a0), arc(a1)
        mid = (p0 + p1) * 0.5
        tang = (p1 - p0).normalized()
        outn = Y_.cross(tang).normalized() * -1.0
        if outn.z < -0.2:
            outn = -outn
        B.blk("ashlar", Vector((mid.x, -0.06, mid.z)) + outn * 0.2, ((p1 - p0).length + 0.04, T + 0.12, 0.36), tang, Y_, tang.cross(Y_) * -1, bevel=0.03, jit=0.004, tone=1.05)
    for sx in (-1, 1):
        for k in range(6):
            z = 0.2 + k * 0.42
            B.blk("ashlar", Vector((sx * (DOOR_A + 0.2), -0.05, z + 0.2)), (0.42 if k % 2 else 0.3, T + 0.12, 0.4), X_, Y_, Z_, bevel=0.03, jit=0.004, tone=1.05)
    for wy in WIN_Y:
        for sx in (-1, 1):
            for k in range(4):
                z = WIN_SILL + k * 0.44
                B.blk("ashlar", Vector((HW - T * 0.5, wy + sx * (WIN_A + 0.12), z + 0.22)), (T + 0.1, 0.26, 0.42), X_, Y_, Z_, bevel=0.025, jit=0.003, tone=1.04)
        B.blk("ashlar", Vector((HW - T * 0.5 + 0.05, wy, WIN_SILL - 0.08)), (T + 0.22, WIN_A * 2.0 + 0.5, 0.16), X_, Y_, Z_, bevel=0.025, jit=0.003, tone=1.06)
    y = T + 0.4
    while y < L - T - 0.3:
        B.blk("ashlar", Vector((HW + 0.12, y, EAVE - 0.25)), (0.3, 0.32, 0.26), X_, Y_, Z_, bevel=0.03, jit=0.004, tone=1.0, taper=(0.5, 1.0))
        y += 0.9
    B.blk("ashlar", Vector((HW + 0.05, L * 0.5, EAVE + 0.04)), (0.3, L - 2.0 * T, 0.18), X_, Y_, Z_, bevel=0.03, jit=0.004, tone=1.04)
    # --- buttresses ---------------------------------------------------------------------------------
    for (bx, by, out) in ((HW, 0.0, Vector((0.7, -0.7, 0)).normalized()), (-HW, 0.0, Vector((-0.7, -0.7, 0)).normalized()),
                          (HW, L, Vector((0.7, 0.7, 0)).normalized()), (-HW, L, Vector((-0.7, 0.7, 0)).normalized())):
        buttress(B, Vector((bx, by, 0.0)), out, rng, 4.8)
    for by in (5.3, 8.7):
        buttress(B, Vector((HW, by, 0.0)), X_, rng, 4.4)
        buttress(B, Vector((-HW, by, 0.0)), -X_, rng, 2.6 + rng.uniform(0.0, 0.8))         # the north side's stand broken
    # --- the bell-cote on the west gable's apex: two piers, a pointed cap; the bell gone, its yoke snapped ----------------
    for sx in (-1, 1):
        B.blk("ashlar", Vector((sx * 0.5, T * 0.5, APEX + 0.95)), (0.34, 0.6, 1.5), X_, Y_, Z_, bevel=0.03, jit=0.004, tone=1.02)
    B.blk("ashlar", Vector((0.0, T * 0.5, APEX + 1.82)), (1.44, 0.72, 0.24), X_, Y_, Z_, bevel=0.03, jit=0.004, tone=1.04)
    B.cone("ashlar", Vector((0.0, T * 0.5, APEX + 2.3)), 0.62, 0.02, 0.76, tone=1.0, seg=4, squash=(1.0, 0.62))
    B.blk("iron", Vector((-0.14, T * 0.5, APEX + 1.5)), (0.62, 0.07, 0.07), X_, Y_, Z_, bevel=0.0, jit=0.0, tone=0.8)
    B.blk("iron", Vector((0.27, T * 0.5 + 0.05, APEX + 1.33)), (0.36, 0.06, 0.06), Vector((0.8, 0, -0.6)), Y_, Vector((0.6, 0, 0.8)), bevel=0.0, jit=0.0, tone=0.8)
    # --- the roof's charred timbers -----------------------------------------------------------------------
    def rafter(a, b, w, h, tone):
        a, b = Vector(a), Vector(b)
        d = b - a
        ln = d.length
        ey = d / ln
        ex = ey.cross(Z_)
        if ex.length < 1e-3:
            ex = X_
        ex = ex.normalized()
        ez = ex.cross(ey).normalized()
        B.blk("char", (a + b) * 0.5, (w, ln, h), ex, ey, ez, bevel=0.03, jit=0.025, sub=1, rough=0.02, tone=tone)
    rafter((-3.1, 1.3, 5.0), (0.2, 1.1, 8.3), 0.24, 0.3, 0.9)           # a couple still pitched against the west gable
    rafter((3.0, 1.2, 4.9), (-0.1, 1.0, 8.2), 0.24, 0.3, 0.85)
    rafter((-2.9, 4.0, 1.5), (2.4, 9.6, 4.7), 0.26, 0.32, 0.8)          # one fallen across the nave, its foot in the crust
    rafter((2.8, 6.2, 1.4), (3.1, 12.6, 3.3), 0.22, 0.28, 0.82)
    rafter((-3.0, 11.0, 1.45), (1.0, 12.9, 1.7), 0.3, 0.32, 0.75)       # the tie-beam's half, lying in it
    rafter((-1.9, 2.4, 1.4), (-0.4, 6.2, 1.55), 0.3, 0.3, 0.78)
    for k in range(7):                                                  # charred battens and purlins scattered on the crust
        c = Vector((rng.uniform(-2.4, 2.4), rng.uniform(2.0, 12.0), CRUST + 0.05))
        a = rng.uniform(0, math.pi)
        d = Vector((math.cos(a), math.sin(a), rng.uniform(-0.05, 0.12)))
        rafter(c - d * 0.9, c + d * 0.9, 0.12, 0.08, 0.8)
    # --- the choir: stall ends standing out of the crust in two rows, the cantor's lectern at the east end ------------
    for side in (1, -1):
        for k in range(5):
            yy = 2.6 + k * 1.75
            if side < 0 and 4.6 < yy < 10.4 and k % 2 == 0:
                continue                                                # some went with the north wall
            x = side * (HW - T - 0.75)
            lean = rng.uniform(-0.12, 0.12)
            ez = Vector((0, lean, 1)).normalized()
            B.blk("char", Vector((x, yy, 1.05)), (1.1, 0.12, 2.1), X_, Y_, ez, bevel=0.02, jit=0.01, sub=1, rough=0.012, tone=rng.uniform(0.75, 0.9))
            # the carved finial (a poppy-head) burned to a knot
            B.sphere("char", (x - side * 0.25, yy, 2.2), 0.16, (1.0, 0.7, 1.2), tone=0.8, sub=1)
            # the bench's back rail, mostly under the crust
            B.blk("char", Vector((x + side * 0.3, yy + 0.85, 1.55)), (0.1, 1.6, 0.22), X_, Y_, Z_, bevel=0.015, jit=0.01, tone=0.78)
    # the lectern: a stepped base, a shaft, a sloped desk (stone, so it stood)
    lc = Vector((0.0, 11.2, 0.0))
    for k, (w, h) in enumerate(((1.3, 0.45), (1.0, 0.45), (0.8, 0.4))):
        B.blk("ashlar", lc + Z_ * (0.22 + k * 0.45), (w, w, h), X_, Y_, Z_, bevel=0.03, jit=0.004, tone=1.0)
    B.blk("ashlar", lc + Z_ * 1.75, (0.36, 0.36, 1.2), X_, Y_, Z_, bevel=0.04, jit=0.004, sub=1, tone=1.04)
    desk_n = Vector((0, -0.55, 0.84)).normalized()
    B.blk("ashlar", lc + Z_ * 2.42, (0.9, 0.62, 0.12), X_, desk_n.cross(X_) * -1, desk_n, bevel=0.03, jit=0.003, tone=1.06)
    B.blk("ashlar", lc + Vector((0, -0.26, 2.3)), (0.92, 0.08, 0.1), X_, Y_, Z_, bevel=0.02, jit=0.002, tone=1.04)
    B.colbox(lc + Z_ * 1.3, (1.0, 1.0, 2.6), X_, Y_, Z_)
    # --- the frozen lava: two tongues spilled over the south sills and down the wall; a lip over the west threshold -------
    def lobe(path, widths, thick, side, up=Z_):
        """A lobe of crust laid along `path` (points), `widths` across `side`, a lumpy domed section `thick` high
        above its base, the base sunk a little so it never shows an edge; a swollen, rounded toe at the end."""
        rings = []
        for i, c in enumerate(path):
            c = Vector(c)
            w = widths[i]
            ring = []
            nseg = 12
            for j in range(nseg):
                a = math.pi * j / (nseg - 1)
                ca, sa = math.cos(a), math.sin(a)
                bump = 1.0 + 0.18 * math.sin(i * 1.9 + j * 1.3) + 0.1 * math.sin(i * 3.7 - j * 2.1)
                ring.append(c + side * (ca * w * 0.5) + up * (sa ** 0.7 * thick * bump - 0.12))
            for j in range(nseg - 2, 0, -1):
                a = math.pi * j / (nseg - 1)
                ring.append(c + side * (math.cos(a) * w * 0.48) - up * 0.3)
            rings.append(ring)
        B.loft("crust_s", rings, tone=0.9)
    # two tongues that spilled over the south sills: out over the sill, down the wall's face, a swollen toe at its foot
    for wy in (WIN_Y[0], WIN_Y[2]):
        x0 = HW - T * 0.5
        path = [(x0 - 0.2, wy, WIN_SILL + 0.02), (x0 + 0.42, wy, WIN_SILL - 0.02), (HW + 0.32, wy + 0.05, WIN_SILL - 0.45),
                (HW + 0.38, wy + 0.1, 0.9), (HW + 0.55, wy + 0.12, 0.25), (HW + 1.05, wy + 0.1, -0.15), (HW + 1.55, wy + 0.05, -0.25)]
        widths = [0.7, 0.78, 0.72, 0.66, 0.9, 1.15, 0.6]
        rings_up = [Vector((0, 0, 1)), Vector((0, 0, 1)), Vector((1, 0, 0.3)).normalized(), Vector((1, 0, 0.1)).normalized(),
                    Vector((1, 0, 0.6)).normalized(), Vector((0.3, 0, 1)).normalized(), Vector((0, 0, 1))]
        # each ring domed along its own "up" (the face it lies on)
        rings = []
        for i, c in enumerate(path):
            c = Vector(c)
            upv = rings_up[i]
            w = widths[i]
            ring = []
            nseg = 12
            for j in range(nseg):
                a = math.pi * j / (nseg - 1)
                bump = 1.0 + 0.2 * math.sin(i * 1.9 + j * 1.3)
                ring.append(c + Y_ * (math.cos(a) * w * 0.5) + upv * (math.sin(a) ** 0.7 * 0.26 * bump))
            for j in range(nseg - 2, 0, -1):
                a = math.pi * j / (nseg - 1)
                ring.append(c + Y_ * (math.cos(a) * w * 0.46) - upv * 0.08)
            rings.append(ring)
        B.loft("crust_s", rings, tone=0.9)
    # the crust standing in the window bays, level with the sills (it filled to there)
    for wy in WIN_Y:
        B.blk("crust_s", Vector((HW - T * 0.5, wy, WIN_SILL - 0.05)), (T - 0.1, WIN_A * 1.9, 0.2), X_, Y_, Z_, bevel=0.06, jit=0.03, sub=2, rough=0.02, tone=0.9)
    # the west threshold: the flow came in here; a lip of it lies over the sill, sloping to the outside crust
    lobe([(0.0, -1.2, CRUST - 0.35), (0.05, -0.2, CRUST - 0.05), (0.0, T * 0.5, CRUST + 0.05), (-0.05, T + 0.6, CRUST)],
         [DOOR_A * 2.6, DOOR_A * 2.1, DOOR_A * 1.95, DOOR_A * 2.3], 0.3, X_)
    # the east breach: the crust broke out in a frozen cascade, folding down to the ground outside
    lobe([(0.2, L - T - 0.8, CRUST + 0.05), (0.15, L - T * 0.5, CRUST - 0.05), (0.25, L + 0.6, CRUST - 0.55), (0.1, L + 1.6, CRUST - 1.15),
          (0.3, L + 2.7, CRUST - 1.5), (0.2, L + 3.6, CRUST - 1.65)], [3.0, 3.2, 3.4, 3.6, 3.9, 3.0], 0.55, X_)
    # --- collision: the walls as boxes, open at the door and the breach -----------------------------------------
    def cb(c, s):
        B.colbox(Vector(c), s, X_, Y_, Z_)
    cb((-(HW + DOOR_A) * 0.5 - 0.02, T * 0.5, (FOOT + APEX) * 0.5 - 0.6), (HW - DOOR_A, T, APEX - FOOT - 1.2))
    cb(((HW + DOOR_A) * 0.5 + 0.02, T * 0.5, (FOOT + APEX) * 0.5 - 0.6), (HW - DOOR_A, T, APEX - FOOT - 1.2))
    cb((0.0, T * 0.5, (4.5 + APEX) * 0.5), (DOOR_A * 2.0, T, APEX - 4.5))
    cb((-(HW + 1.6) * 0.5 - 0.1, L - T * 0.5, (FOOT + 6.0) * 0.5), (HW - 1.6, T, 6.0 - FOOT))
    cb(((HW + 2.1) * 0.5 + 0.1, L - T * 0.5, (FOOT + 7.5) * 0.5), (HW - 2.1, T, 7.5 - FOOT))
    cb((HW - T * 0.5, L * 0.5, (FOOT + EAVE) * 0.5), (T, L - 2.0 * T, EAVE - FOOT))
    cb((-HW + T * 0.5, 2.6, (FOOT + EAVE) * 0.5), (T, 3.8, EAVE - FOOT))
    cb((-HW + T * 0.5, 12.0, (FOOT + EAVE) * 0.5), (T, 3.0, EAVE - FOOT))
    cb((-HW + T * 0.5, 7.5, (FOOT + 2.4) * 0.5), (T, 6.2, 2.4 - FOOT))
    return B


def asset_choir():
    W.reset()
    B = build()
    objs, col = C.finish(B, "Choir")
    far = C.far_copy(objs, "Choir", 0.14)
    W.export(objs + far + [col], os.path.join(MODELS, "rift_choir_house.glb"), "choir")
    W.preview(objs, "choir", [
        ((-14.0, -12.0, 7.0), (0.0, 6.0, 3.5), 30), ((15.0, -6.0, 5.0), (0.0, 7.0, 3.0), 30), ((14.0, 22.0, 9.0), (0.0, 7.0, 2.5), 30),
        ((-13.0, 18.0, 6.0), (0.0, 7.0, 3.0), 30), ((0.0, -2.0, 2.4), (0.0, 9.0, 1.8), 24), ((0.0, 7.0, 26.0), (0.0, 7.0, 0.0), 30),
        ((5.5, 3.0, 2.0), (2.0, 10.0, 2.5), 26)])
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(BLEND, "rift_choir_house.blend"))


if __name__ == "__main__":
    os.makedirs(MODELS, exist_ok=True)
    asset_choir()
