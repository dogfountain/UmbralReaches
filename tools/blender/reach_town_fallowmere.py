"""Fallowmere (tools/blender/reach_towns.py): the farming hamlet in the low fields, where the Order's bread was grown.
Every piece stands at the origin on the ground, its front +z (Godot frame; reach_town_lib).

  FM_TitheBarn   the Order's tithe barn: rubble walls on a battered plinth, seven buttresses a side, ventilation slits,
                 parapet gables with crosses and owl holes, a tall wagon porch with a pointed arch and its doors (one
                 swung open), a winnowing door behind, a steep stone-slate roof sagging on old timbers, one bay stripped
                 to its rafters
  FM_Farmhouse   the longhouse: rubble ground storey with quoins, a jettied plaster half-storey, a deep reed thatch with
                 two eyebrow dormers, an end stack, a slate-roofed porch, an outshot behind
  FM_Cottage     a cob cottage under thatch, a stack at one end, a woodshed lean-to
  FM_Dovecote    a round rubble dovecote, a conical slate roof and a timber glover on top, ledges for the birds
  FM_Rick        a haystack under a thatched cap, its rope weights hanging
  FM_Stook       sheaves leaned together in a stook
  FM_Scarecrow   a post, a cross-arm, a sack head under a hat, a ragged coat, straw out of the sleeves
  FM_Well        a stone well-head under a pentice roof, a windlass, a bucket
  FM_Wain        a hay wain: a plank bed with raves, two great wheels behind and two small before, the shafts down
  FM_Hurdle      a woven wattle hurdle on its stakes (folds, field edges)
  FM_Gate        a five-bar field gate between its posts
  FM_BarnFar FM_HouseFar FM_DoveFar   the silhouettes
"""
import math
from mathutils import Vector
import reach_town_lib as RL
from reach_town_lib import T, TINT, grouped, lathe_at, far_piece
from r37_wall_lib import lerp, clamp

BARN_L = 28.0
BARN_D = 11.0
BARN_EAVE = 6.4
BARN_RIDGE = 14.4


def tithe_barn():
    b = T("FM_TitheBarn", seed=8201, damp=1.1)
    hl, hd = BARN_L / 2, BARN_D / 2
    E, R = BARN_EAVE, BARN_RIDGE
    # plinth (buried: a slope never shows a gap) and the walls
    b.rect_solid(-hl - 0.4, hl + 0.4, -hd - 0.4, hd + 0.4, -1.8, 0.4, bat=(0.2,) * 4, mat="stone", tint=TINT["damp"], jit=0.03, seed=1)
    b.rect_solid(-hl, hl, -hd, hd, 0.35, E, mat="rubble", jit=0.035, seed=2)
    # ashlar quoins at the four corners and a string course at the eaves
    for sx in (-1, 1):
        for sz in (-1, 1):
            y = 0.7
            k = 0
            while y < E - 0.2:
                hh = 0.42 + 0.08 * ((k * 7) % 3)
                lx = 0.95 if k % 2 == 0 else 0.55
                lz = 0.55 if k % 2 == 0 else 0.95
                b.box((sx * (hl - lx / 2 + 0.05), y + hh / 2, sz * (hd - lz / 2 + 0.05)), (lx + 0.1, hh, lz + 0.1), "stone", uv=1.4, tint=TINT["pale"], jit=0.012, cuts=0)
                y += hh
                k += 1
    b.rect_solid(-hl - 0.12, hl + 0.12, -hd - 0.12, hd + 0.12, E - 0.25, E + 0.05, mat="stone", uv=1.4, tint=TINT["pale"], jit=0.01, seed=3)
    # the gables: stone triangles to the ridge, coped, a cross at each apex, an owl hole high in each
    for sx in (-1, 1):
        x0, x1 = (hl - 0.9, hl) if sx > 0 else (-hl, -hl + 0.9)
        b.prism_x([(-hd, E), (0.0, R + 0.25), (hd, E)], x0, x1, "rubble", uv=1.0, jit=0.03, seed=4 + sx, dens=1.2, xstep=0.9)
        xf = sx * (hl + 0.02)
        for sz in (-1, 1):
            b.beam((sx * (hl - 0.45), E + 0.15, sz * (hd + 0.25)), (sx * (hl - 0.45), R + 0.45, 0.0), 1.2, 0.4, "stone", jit=0.008)
            # a kneeler at the gable's foot
            b.box((sx * (hl - 0.45), E + 0.25, sz * (hd + 0.1)), (1.25, 0.55, 0.9), "stone", uv=1.4, tint=TINT["pale"], jit=0.01, cuts=0)
        b.box((sx * (hl - 0.45), R + 0.75, 0.0), (0.7, 0.9, 0.7), "stone", uv=1.6, tint=TINT["pale"], jit=0.005, cuts=0)
        b.frustum(sx * (hl - 0.45), 0.0, (0.42, 0.42), (0.04, 0.04), R + 1.2, R + 2.5, "stone", levels=2, jit=0.0, tint=TINT["pale"])
        # owl hole: a dark round in a ring of stones, on the gable face
        def owl(sx=sx):
            n = 10
            for i in range(n):
                a0 = math.tau * i / n
                a1 = math.tau * (i + 1) / n
                pts = [(math.cos(a0) * 0.42, math.sin(a0) * 0.42), (math.cos(a0) * 0.72, math.sin(a0) * 0.72), (math.cos(a1) * 0.72, math.sin(a1) * 0.72), (math.cos(a1) * 0.42, math.sin(a1) * 0.42)]
                b.poly_z([(p[0], p[1] + R - 3.3) for p in pts], -0.05, 0.12, "stone", uv=1.5, tint=TINT["pale"], jit=0.004)
            b.poly_z([(math.cos(math.tau * i / 12) * 0.43, R - 3.3 + math.sin(math.tau * i / 12) * 0.43) for i in range(12)], -0.06, 0.02, "dark")
        grouped(b, owl, sx * math.pi / 2, (sx * hl, 0.0, 0.0))
        # two slits low in the end wall
        def slits():
            for xx in (-2.6, 2.6):
                b.box((xx, 3.4, 0.02), (0.2, 1.7, 0.1), "dark", cuts=0, jit=0.0)
                for s2 in (-1, 1):
                    b.box((xx + s2 * 0.22, 3.4, 0.06), (0.24, 2.0, 0.16), "stone", uv=1.5, tint=TINT["pale"], cuts=0, jit=0.006)
                b.box((xx, 4.5, 0.06), (0.7, 0.24, 0.18), "stone", uv=1.5, tint=TINT["pale"], cuts=0, jit=0.006)
                b.box((xx, 2.3, 0.06), (0.7, 0.24, 0.18), "stone", uv=1.5, tint=TINT["pale"], cuts=0, jit=0.006)
        grouped(b, slits, sx * math.pi / 2, (sx * hl, 0.0, 0.0))
    # buttresses: seven a side, stepping in twice, weathered caps
    nb = 6
    for k in range(nb + 1):
        x = -hl + BARN_L * k / nb
        for sz in (-1, 1):
            if sz > 0 and abs(x) < 4.5:
                continue                                         # the porch stands there
            xa = max(x - 0.55, -hl - 0.6)
            xb = min(x + 0.55, hl + 0.6)
            if abs(abs(x) - hl) < 0.1:
                xa, xb = (x - 1.0, x) if x > 0 else (x, x + 1.0)
            for (y0, y1, dep) in ((0.0, 2.4, 1.35), (2.4, 4.4, 1.0), (4.4, 5.8, 0.6)):
                za, zb = (hd - 0.1, hd + dep) if sz > 0 else (-hd - dep, -hd + 0.1)
                b.rect_solid(xa, xb, za, zb, y0 - (0.6 if y0 == 0.0 else 0.0), y1, mat="stone", jit=0.025, seed=10 + k, tint=TINT["plain"])
                # the weathering: a sloped stone over each step
                zc = sz * (hd + dep - 0.22)
                b.box(((xa + xb) / 2, y1 + 0.12, zc), (xb - xa + 0.08, 0.2, 0.62), "stone", pitch=sz * -0.6, uv=1.4, tint=TINT["pale"], cuts=0, jit=0.006)
            b.colbox(((xa + xb) / 2, 2.0, sz * (hd + 0.6)), (xb - xa, 4.4, 1.3))
        # ventilation slits between the buttresses
        if k < nb:
            xm = -hl + BARN_L * (k + 0.5) / nb
            for sz in (-1, 1):
                if sz > 0 and abs(xm) < 5.0:
                    continue
                def slit(xm=xm):
                    for yy in (3.1,):
                        b.box((0.0, yy, 0.02), (0.2, 2.0, 0.1), "dark", cuts=0, jit=0.0)
                        for s2 in (-1, 1):
                            b.box((s2 * 0.22, yy, 0.06), (0.24, 2.3, 0.16), "stone", uv=1.5, tint=TINT["pale"], cuts=0, jit=0.006)
                        b.box((0.0, yy + 1.25, 0.06), (0.8, 0.26, 0.18), "stone", uv=1.5, tint=TINT["pale"], cuts=0, jit=0.006)
                        b.box((0.0, yy - 1.25, 0.08), (0.8, 0.22, 0.24), "stone", uv=1.5, tint=TINT["pale"], cuts=0, jit=0.006)
                grouped(b, slit, 0.0 if sz > 0 else math.pi, (xm, 0.0, sz * hd))
    # the roof: stone slates on old timbers, between the parapet gables; one bay at the back stripped to its rafters
    GX0, GX1 = 6.2, 9.4
    b.gable(-hl + 0.6, hl - 0.6, hd, E + 0.05, R, mat="slate", over=0.55, thick=0.36, sag=0.18, seed=21, barge=False, gap=(GX0, GX1))
    run = hd + 0.55
    rise = R - E
    ang = math.atan2(rise, hd)
    drop = rise * 0.55 / hd
    def on_slope(t, up=0.0):
        """A point on the back slope's top surface, t = 0 at the eave edge, 1 at the ridge."""
        return (lerp(-run, 0.0, t), lerp(E + 0.05 - drop, R, t) + up)
    # the bay stripped to its timbers: the dark of the barn under the rafters, battens across, broken slates hanging on
    z0, y0 = on_slope(0.08, -0.5)
    z1, y1 = on_slope(0.96, -0.5)
    b.beam(((GX0 + GX1) / 2, y0, z0), ((GX0 + GX1) / 2, y1, z1), GX1 - GX0 + 0.1, 0.06, "dark", jit=0.0)
    for i in range(5):
        x = lerp(GX0 + 0.15, GX1 - 0.15, i / 4)
        za, ya = on_slope(0.0, -0.2)
        zb, yb = on_slope(0.98, -0.2)
        b.beam((x, ya, za), (x, yb, zb), 0.2, 0.26, "beam")
    for j in range(7):
        if j in (2, 5):
            continue
        zz, yy = on_slope(0.1 + j * 0.13, -0.02)
        b.box(((GX0 + GX1) / 2, yy, zz), (GX1 - GX0 + 0.25, 0.07, 0.11), "beam", pitch=-ang, cuts=0, jit=0.01)
    for i in range(9):
        t = 0.06 + (i % 3) * 0.06
        zz, yy = on_slope(t, 0.06)
        x = GX0 + 0.3 + (i * 0.41) % (GX1 - GX0 - 0.6)
        b.box((x, yy, zz), (0.5, 0.04, 0.34), "slate", yaw=(i - 4) * 0.12, pitch=-ang * (0.9 + 0.05 * (i % 2)), cuts=0, jit=0.0)
    for i in range(6):
        zz, yy = on_slope(0.86 + (i % 2) * 0.05, 0.06)
        b.box((GX0 + 0.3 + i * 0.55, yy, zz), (0.5, 0.04, 0.34), "slate", yaw=(i - 3) * 0.1, pitch=-ang, cuts=0, jit=0.0)
    # the wagon porch: walls, a pointed arch, its own gable, the great doors (one leaf swung out)
    PW, PD, PE, PR = 8.0, 5.0, 5.8, 11.6
    zf = hd + PD
    b.rect_solid(-PW / 2, -PW / 2 + 1.1, hd - 0.4, zf, 0.6, PE, mat="rubble", jit=0.03, seed=31)
    b.rect_solid(PW / 2 - 1.1, PW / 2, hd - 0.4, zf, 0.6, PE, mat="rubble", jit=0.03, seed=32)
    b.rect_solid(-PW / 2 - 0.3, PW / 2 + 0.3, hd - 0.4, zf + 0.3, -1.6, 0.3, bat=(0.15,) * 4, mat="stone", tint=TINT["damp"], jit=0.03, seed=33)
    # the porch's front: a stone screen with the arch through it
    AW = 5.2
    spring = 3.6
    import r37_wall as RW
    for sx in (-1, 1):
        b.rect_solid(sx * AW / 2 if sx > 0 else -PW / 2, PW / 2 if sx > 0 else -AW / 2, zf - 0.9, zf, 0.6, PE, mat="rubble", jit=0.03, seed=34 + sx)
    # the spandrels over the arch up to the gable
    crown = spring + AW * math.sqrt(1 - 0.25)
    left = []
    for i in range(9):
        th = math.pi - (math.pi / 3.0) * i / 8
        left.append((AW / 2 + AW * math.cos(th), spring + AW * math.sin(th)))
    # fill above the arch to the eave line (one solid made of thin slices following the arch)
    for i in range(8):
        xa, ya = left[i]
        xb, yb = left[i + 1]
        for sx in (-1, 1):
            pts = [(sx * xa, ya), (sx * xa, PE + 0.02), (sx * xb, PE + 0.02), (sx * xb, yb)]
            if sx < 0:
                pts = list(reversed(pts))
            b.poly_z(pts, zf - 0.9, zf, "rubble", uv=1.0, jit=0.0)
    b.arch(0.0, spring, AW, 0.45, zf - 0.95, zf + 0.12, "stone", uv=1.5, n=6, tint=TINT["pale"], seed=35, jit=0.008, alt=0.06)
    b.arch(0.0, spring, AW, 0.3, zf - 2.2, zf - 0.9, "stone", uv=1.5, n=6, tint=TINT["plain"], seed=36, jit=0.006)
    for sx in (-1, 1):
        b.box((sx * (AW / 2 + 0.25), spring / 2 + 0.3, zf - 0.4), (0.5, spring - 0.6, 1.2), "stone", uv=1.4, tint=TINT["pale"], jit=0.01, cuts=1)
    # the dark of the barn through the arch, the inner doors
    b.poly_z(RW.arch_poly(0.0, spring, AW, 0.6), hd - 0.2, hd - 0.1, "dark", uv=1.0)
    # leaves: the left shut, the right swung out into the porch
    b.box((-AW / 4, 2.4, hd + 0.1), (AW / 2 - 0.1, 3.6, 0.14), "plank", cuts=0, jit=0.0)
    for yy in (1.2, 2.4, 3.6):
        b.box((-AW / 4, yy, hd + 0.2), (AW / 2 - 0.2, 0.12, 0.05), "iron", cuts=0, jit=0.0)
    a = 1.15
    cx = AW / 2 - math.cos(a) * AW / 4
    cz = hd + 0.1 + math.sin(a) * AW / 4
    b.box((cx, 2.4, cz), (AW / 2 - 0.1, 3.6, 0.14), "plank", yaw=a, cuts=0, jit=0.0)
    # the threshold: worn stone and a cart's ruts in the porch floor
    b.box((0.0, 0.33, hd + PD / 2), (AW - 0.2, 0.1, PD + 0.6), "stone", uv=1.2, tint=TINT["damp"], cuts=2, jit=0.02)
    # the porch's roof (its ridge runs out along z, meeting the main roof)
    def proof():
        b.gable(-0.6, PD + 0.5, PW / 2, PE, PR, mat="slate", over=0.45, thick=0.3, sag=0.08, seed=37, barge=False, ridge=True)
    grouped(b, proof, -math.pi / 2, (0.0, 0.0, hd - 0.6))
    # the porch gable: a stone triangle over the arch, coped, a cross
    def pgable():
        b.prism_x([(-PW / 2, PE), (0.0, PR + 0.2), (PW / 2, PE)], -0.9, 0.0, "rubble", uv=1.0, jit=0.03, seed=38, dens=1.2, xstep=0.9)
        for sz in (-1, 1):
            b.beam((-0.45, PE + 0.15, sz * (PW / 2 + 0.2)), (-0.45, PR + 0.4, 0.0), 1.1, 0.36, "stone", jit=0.008)
        b.box((-0.45, PR + 0.65, 0.0), (0.6, 0.8, 0.6), "stone", uv=1.6, tint=TINT["pale"], cuts=0, jit=0.004)
        b.frustum(-0.45, 0.0, (0.36, 0.36), (0.04, 0.04), PR + 1.05, PR + 2.1, "stone", levels=2, jit=0.0, tint=TINT["pale"])
        # the Order's mark over the arch: a carved sun in a roundel (dark relief on pale)
    grouped(b, pgable, -math.pi / 2, (0.0, 0.0, zf))
    def roundel():
        n = 12
        for i in range(n):
            a0 = math.tau * i / n
            a1 = math.tau * (i + 1) / n
            b.poly_z([(math.cos(a0) * 0.5, math.sin(a0) * 0.5 + PE + 1.7), (math.cos(a0) * 0.75, math.sin(a0) * 0.75 + PE + 1.7),
                      (math.cos(a1) * 0.75, math.sin(a1) * 0.75 + PE + 1.7), (math.cos(a1) * 0.5, math.sin(a1) * 0.5 + PE + 1.7)], 0.0, 0.14, "stone", uv=1.6, tint=TINT["pale"])
        b.poly_z([(math.cos(math.tau * i / 12) * 0.5, PE + 1.7 + math.sin(math.tau * i / 12) * 0.5) for i in range(12)], -0.02, 0.06, "stone", tint=TINT["dark"])
        for i in range(8):
            a0 = math.tau * i / 8
            b.box((math.cos(a0) * 0.28, PE + 1.7 + math.sin(a0) * 0.28, 0.08), (0.08, 0.3, 0.05), "stone", roll=a0 - math.pi / 2, tint=TINT["pale"], cuts=0, jit=0.0)
    grouped(b, roundel, 0.0, (0.0, 0.0, zf + 0.02))
    # the winnowing door behind: plank leaves under a timber lintel, a stone step
    b.door(BARN_L / 12, -hd, w=3.0, h=3.4, face=-1, step=0.35, frame="beam", studs=False)
    # collision: the body, the roof's mass, the porch's walls (the arch stays open to the doors)
    b.colbox((0.0, (E - 1.0) / 2, 0.0), (BARN_L + 0.3, E + 1.0, BARN_D + 0.3))
    b.colbox((0.0, (E + R) / 2, 0.0), (BARN_L - 1.0, R - E, BARN_D * 0.55))
    for sx in (-1, 1):
        b.colbox((sx * (PW / 2 - 0.55 + (0.0 if sx > 0 else 0.0)), PE / 2, hd + PD / 2), (1.3, PE, PD + 0.2))
        b.colbox((sx * (AW / 2 + 0.6), PE / 2, zf - 0.45), (1.6, PE, 0.95))
    b.colbox((0.0, (PE + PR) / 2 + 0.5, hd + PD / 2), (PW, PR - PE, PD + 0.4))
    RL.DATA["barn"] = {"porch_z": zf, "door_z": hd + 0.4, "len": BARN_L, "depth": BARN_D}
    return b.finish()


def farmhouse():
    b = T("FM_Farmhouse", seed=8301, damp=1.0)
    Ln, D = 16.0, 7.6
    hl, hd = Ln / 2, D / 2
    G = 4.0                         # the wall plate: one and a half storeys, the upper rooms in the roof
    b.rect_solid(-hl - 0.3, hl + 0.3, -hd - 0.3, hd + 0.3, -1.6, 0.45, bat=(0.15,) * 4, mat="stone", tint=TINT["damp"], jit=0.03, seed=1)
    b.rect_solid(-hl, hl, -hd, hd, 0.4, G, mat="rubble", jit=0.035, seed=2)
    for sx in (-1, 1):
        for sz in (-1, 1):
            y = 0.45
            k = 0
            while y < G - 0.1:
                hh = 0.38 + 0.06 * (k % 3)
                lx = 0.8 if k % 2 == 0 else 0.45
                lz = 0.45 if k % 2 == 0 else 0.8
                b.box((sx * (hl - lx / 2 + 0.05), y + hh / 2, sz * (hd - lz / 2 + 0.05)), (lx + 0.1, hh, lz + 0.1), "stone", uv=1.4, tint=TINT["pale"], jit=0.012, cuts=0)
                y += hh
                k += 1
    # the wall plate showing under the eaves
    for sz in (-1, 1):
        b.box((0.0, G - 0.12, sz * (hd + 0.08)), (Ln + 0.3, 0.26, 0.22), "beam", cuts=2, jit=0.01)
    # the door (left of middle) under its porch, windows with shutters; the end walls rise to gables of rubble
    b.door(-2.2, hd, w=1.7, h=2.8, face=1, step=0.45, frame="stone", arch=True)
    for x in (-6.0, 2.0, 5.6):
        b.window(x, 2.0, hd, w=1.2, h=1.3, face=1, lit=x != 5.6, frame="stone")
    for x in (-4.0, 4.4):
        b.window(x, 2.0, -hd, w=1.0, h=1.1, face=-1, lit=False, frame="stone", shutters=False)
    RISE = 5.4
    for sx in (-1, 1):
        x0, x1 = (hl - 0.7, hl) if sx > 0 else (-hl, -hl + 0.7)
        b.prism_x([(-hd, G), (0.0, G + RISE - 0.4), (hd, G)], x0, x1, "rubble", uv=1.0, jit=0.03, seed=5 + sx, dens=1.2, xstep=0.7)
        def gw(sx=sx):
            b.window(0.0, G + 1.4, 0.0, w=0.8, h=0.9, face=1, lit=sx < 0, frame="stone", shutters=False, mull=False)
        grouped(b, gw, sx * math.pi / 2, (sx * hl, 0.0, 0.0))
    def porch():
        for sx in (-1, 1):
            b.log((sx * 1.3, -0.3, 2.0), (sx * 1.3, 2.9, 2.0), 0.13, 0.11, "beam", seed=40 + sx, crook=0.03)
        b.beam((-1.6, 2.95, 2.0), (1.6, 2.95, 2.0), 0.2, 0.24, "beam")
        b.beam((-1.6, 2.95, 0.1), (-1.6, 2.95, 2.1), 0.18, 0.2, "beam")
        b.beam((1.6, 2.95, 0.1), (1.6, 2.95, 2.1), 0.18, 0.2, "beam")
        for sx in (-1, 1):
            b.beam((sx * 1.3, 2.2, 2.0), (sx * 1.3 * 0.4, 2.95, 2.0), 0.12, 0.12, "beam")
        def pr():
            b.gable(-0.1, 2.5, 1.55, 3.0, 4.15, mat="slate", over=0.3, thick=0.2, sag=0.03, seed=41, barge=True)
        grouped(b, pr, -math.pi / 2, (0.0, 0.0, 0.0))
        b.box((-1.3, 0.25, 1.6), (0.4, 0.5, 1.6), "plank", cuts=0, jit=0.0)            # a bench under it
    grouped(b, porch, 0.0, (-2.2, 0.0, hd))
    # the thatch: deep, swept over the gables' coping, two dormers on the front and one behind
    b.thatch_gable(-hl - 0.1, hl + 0.1, hd, G, G + RISE, over=0.6, thick=0.62, sag=0.16, seed=42, end_over=0.55)
    for dx in (-5.4, 4.0):
        b.dormer(dx, hd - 0.15, G - 0.9, w=2.3, wall_h=1.8, rise=1.3, depth=3.2, roof="thatch", lit=dx > 0, seed=43 + int(dx))
    def back_dormer():
        b.dormer(0.0, 0.0, G - 0.9, w=2.0, wall_h=1.6, rise=1.1, depth=3.0, roof="thatch", lit=False, seed=47)
    grouped(b, back_dormer, math.pi, (1.5, 0.0, -hd + 0.15))
    # the end stack (on the east gable, rising through the thatch) and a smaller one at the west
    b.rect_solid(hl - 0.2, hl + 0.9, -1.0, 0.6, 0.0, G + RISE + 1.6, bat=(0.0, 0.15, 0.08, 0.08), mat="stone", jit=0.025, seed=44)
    b.rect_solid(hl - 0.3, hl + 1.0, -1.1, 0.7, G + RISE + 1.6, G + RISE + 1.8, mat="stone", uv=1.4, tint=TINT["pale"], jit=0.01)
    for pz in (-0.55, 0.15):
        b.frustum(hl + 0.35, pz, 0.17, 0.13, G + RISE + 1.8, G + RISE + 2.35, "stone", round_n=7, levels=2, jit=0.0, tint=TINT["warm"])
        b.frustum(hl + 0.35, pz, 0.1, 0.1, G + RISE + 2.34, G + RISE + 2.36, "dark", round_n=7, levels=2, jit=0.0)
    b.chimney(-hl + 0.4, 0.0, G + RISE - 1.0, G + RISE + 1.2, w=0.9, d=0.8, mat="stone", pots=1)
    # the outshot behind: a lean-to under a slate pent, a plank door
    OZ = -hd - 3.0
    b.rect_solid(-hl + 1.0, -hl + 7.0, OZ, -hd, 0.4, 2.6, mat="rubble", jit=0.03, seed=45)
    b.rect_solid(-hl + 0.8, -hl + 7.2, OZ - 0.3, -hd + 0.1, -1.2, 0.45, mat="stone", tint=TINT["damp"], jit=0.03, seed=46)
    n0 = len(b.bm.verts)
    b.box((0.0, 0.0, 0.0), (6.6, 0.18, 3.8), "slate", cuts=2, jit=0.02)
    b.bm.verts.ensure_lookup_table()
    from mathutils import Matrix
    Rm = Matrix.Rotation(math.atan2(1.6, 3.4), 3, 'X')
    for v in list(b.bm.verts)[n0:]:
        v.co = Rm @ Vector(v.co) + Vector((-hl + 4.0, 3.45, OZ + 1.5))
    b.door(-hl + 5.4, OZ, w=1.2, h=2.0, face=-1, step=0.4, frame="beam", studs=False)
    # collision
    b.colbox((0.0, (G - 1.0) / 2, 0.0), (Ln + 0.5, G + 1.0, D + 0.6))
    b.colbox((0.0, G + 1.6, 0.0), (Ln, 3.2, D * 0.7))
    b.colbox((-hl + 4.0, 1.3, OZ + 1.5), (6.2, 2.6, 3.0))
    b.colbox((hl + 0.35, G, -0.2), (1.1, 2 * G, 1.6))
    RL.DATA["farmhouse"] = {"door": [-2.2, hd + 1.6]}
    return b.finish()


def cottage():
    b = T("FM_Cottage", seed=8401, damp=1.0)
    Ln, D = 9.6, 6.2
    hl, hd = Ln / 2, D / 2
    U = 3.9
    b.rect_solid(-hl - 0.25, hl + 0.25, -hd - 0.25, hd + 0.25, -1.5, 0.6, bat=(0.12,) * 4, mat="rubble", tint=TINT["damp"], jit=0.03, seed=1)
    # cob walls, thick and soft-cornered, lime-washed
    b.rect_solid(-hl, hl, -hd, hd, 0.55, U, bat=(0.1,) * 4, mat="plaster", jit=0.05, seed=2)
    b.door(-1.4, hd, w=1.4, h=2.6, face=1, step=0.5, frame="beam")
    b.window(1.8, 2.0, hd, w=1.1, h=1.2, face=1, lit=True, frame="beam")
    b.window(-3.4, 2.0, hd, w=0.8, h=1.0, face=1, lit=False, frame="beam", mull=False)
    b.window(1.0, 2.0, -hd, w=0.9, h=1.0, face=-1, lit=False, frame="beam", shutters=False)
    for sx in (-1, 1):
        x0, x1 = (hl - 0.5, hl) if sx > 0 else (-hl, -hl + 0.5)
        b.prism_x([(-hd, U - 0.05), (0.0, U + 4.2), (hd, U - 0.05)], x0, x1, "plaster", uv=1.0, jit=0.04, seed=6 + sx, dens=1.0, xstep=0.5)
    b.window(hl + 0.02, U + 1.3, 0.0, w=0.7, h=0.8, face=1, lit=False, frame="beam", shutters=False, mull=False, yaw=math.pi / 2)
    b.thatch_gable(-hl, hl, hd, U, U + 4.4, over=0.8, thick=0.55, sag=0.14, seed=4, end_over=0.65)
    b.rect_solid(-hl - 0.15, -hl + 0.95, -0.7, 0.5, 0.0, U + 5.6, bat=(0.12, 0.0, 0.05, 0.05), mat="rubble", jit=0.03, seed=5)
    b.rect_solid(-hl - 0.25, -hl + 1.05, -0.8, 0.6, U + 5.6, U + 5.8, mat="stone", uv=1.4, tint=TINT["pale"], jit=0.01)
    b.frustum(-hl + 0.4, -0.1, 0.16, 0.12, U + 5.8, U + 6.3, "stone", round_n=7, levels=2, jit=0.0, tint=TINT["warm"])
    b.frustum(-hl + 0.4, -0.1, 0.09, 0.09, U + 6.29, U + 6.31, "dark", round_n=7, levels=2, jit=0.0)
    # the woodshed lean-to on the east end: posts, a pent of planks, split logs stacked under it
    for z in (-hd + 0.4, hd - 0.4):
        b.log((hl + 2.1, -0.3, z), (hl + 2.1, 2.2, z), 0.1, 0.09, "beam", seed=int(z * 10), crook=0.04)
    b.box((hl + 1.15, 2.55, 0.0), (2.6, 0.12, D + 0.4), "plank", roll=0.35, cuts=1, jit=0.0)
    for i in range(5):
        for j in range(7):
            y = 0.25 + i * 0.27
            z = -hd + 0.6 + j * 0.72 + (0.36 if i % 2 else 0.0)
            if z > hd - 0.4:
                continue
            b.tube((hl + 0.25, y, z), (hl + 1.65, y, z), 0.13, 0.13, "beam", sides=6, bark=0.6)
    b.colbox((0.0, (U - 1.0) / 2, 0.0), (Ln + 0.4, U + 1.0, D + 0.4))
    b.colbox((0.0, U + 1.5, 0.0), (Ln, 3.0, D * 0.6))
    b.colbox((hl + 1.0, 0.8, 0.0), (1.9, 1.6, D - 0.6))
    return b.finish()


def dovecote():
    b = T("FM_Dovecote", seed=8501, damp=1.0)
    R0, H = 3.0, 6.6
    lathe_at(b, 0.0, 0.0, -1.4, [(R0 + 0.35, 0.0), (R0 + 0.3, 1.9)], "stone", sides=20, jit=0.02, seed=1)
    lathe_at(b, 0.0, 0.0, 0.4, [(R0, 0.0), (R0 - 0.15, H - 0.4)], "rubble", sides=20, jit=0.02, seed=2)
    # string courses (the birds' ledges) and a cornice
    for yy in (2.4, 4.5):
        b.frustum(0.0, 0.0, R0 + 0.12, R0 + 0.1, yy, yy + 0.18, "stone", round_n=20, levels=2, jit=0.006, tint=TINT["pale"])
    b.frustum(0.0, 0.0, R0 + 0.2, R0 + 0.28, H - 0.05, H + 0.3, "stone", round_n=20, levels=2, jit=0.006, tint=TINT["pale"])
    # flight holes: little dark arches in a row over each ledge
    for yy, n, off in ((2.75, 6, 0.0), (4.85, 8, 0.3)):
        for i in range(n):
            a = math.tau * i / n + off
            r = R0 - 0.06 * (yy / H)
            b.box((math.cos(a) * r, yy + 0.18, math.sin(a) * r), (0.24, 0.34, 0.12), "dark", yaw=-a + math.pi / 2, cuts=0, jit=0.0)
    # the door on the front, low, a step
    b.door(0.0, R0 - 0.1, w=1.1, h=2.0, face=1, step=0.4, frame="stone", studs=False)
    # the roof: a cone of slates, a ring of eaves, the glover (a small timber lantern) on top with its own cap
    b.frustum(0.0, 0.0, R0 + 0.75, 0.55, H + 0.25, H + 4.2, "slate", round_n=20, levels=5, jit=0.02, seed=3)
    b.frustum(0.0, 0.0, R0 + 0.8, R0 + 0.6, H + 0.15, H + 0.4, "slate", round_n=20, levels=2, jit=0.01, seed=4)
    G = H + 4.05
    for i in range(6):
        a = math.tau * i / 6
        b.box((math.cos(a) * 0.62, G + 0.5, math.sin(a) * 0.62), (0.14, 1.0, 0.14), "beam", cuts=0, jit=0.0)
    b.frustum(0.0, 0.0, 0.66, 0.66, G - 0.05, G + 0.1, "beam", round_n=6, levels=2, jit=0.0)
    b.frustum(0.0, 0.0, 0.5, 0.5, G + 0.1, G + 0.95, "dark", round_n=6, levels=2, jit=0.0)
    for k in range(3):
        b.frustum(0.0, 0.0, 0.7, 0.68, G + 0.25 + k * 0.25, G + 0.31 + k * 0.25, "plank", round_n=6, levels=2, jit=0.0)
    b.frustum(0.0, 0.0, 0.95, 0.06, G + 0.95, G + 2.0, "slate", round_n=6, levels=3, jit=0.0)
    b.tube((0.0, G + 1.9, 0.0), (0.0, G + 2.9, 0.0), 0.035, 0.02, "iron", sides=4, bark=1.0)
    b.box((0.18, G + 2.55, 0.0), (0.5, 0.03, 0.03), "iron", cuts=0, jit=0.0)
    b.box((0.36, G + 2.62, 0.0), (0.16, 0.16, 0.02), "iron", cuts=0, jit=0.0)
    b.box((-0.06, G + 2.55, 0.0), (0.1, 0.12, 0.02), "iron", roll=0.785, cuts=0, jit=0.0)
    b.colbox((0.0, H / 2, 0.0), (2 * R0 + 0.3, H + 1.0, 2 * R0 + 0.3))
    b.colbox((0.0, H + 1.6, 0.0), (2 * R0, 2.8, 2 * R0))
    return b.finish()


def rick():
    b = T("FM_Rick", seed=8601, damp=0.4)
    lathe_at(b, 0.0, 0.0, -0.3, [(2.45, 0.0), (2.7, 0.8), (2.85, 1.7), (2.8, 2.5), (2.55, 2.95)], "hay", sides=18, jit=0.04, seed=1, bark=1.5)
    lathe_at(b, 0.0, 0.0, 2.35, [(3.1, 0.0), (3.0, 0.25), (2.3, 1.05), (1.3, 1.75), (0.25, 2.25)], "thatch", sides=18, jit=0.03, seed=2, bark=1.4)
    b.log((0.0, 3.8, 0.0), (0.05, 5.4, 0.0), 0.07, 0.05, "beam", sides=5, crook=0.02)
    for i in range(10):
        a = math.tau * i / 10 + 0.2
        p0 = Vector((math.cos(a) * 1.4, 4.0, math.sin(a) * 1.4))
        p1 = Vector((math.cos(a) * 3.15, 2.45, math.sin(a) * 3.15))
        b.tube(p0, p1, 0.022, 0.022, "rope", sides=4, bark=1.0, cap=False)
        p2 = p1 + Vector((math.cos(a) * 0.02, -0.55, math.sin(a) * 0.02))
        b.tube(p1, p2, 0.02, 0.02, "rope", sides=4, bark=1.0, cap=False)
        b.box((p2.x, p2.y - 0.14, p2.z), (0.26, 0.28, 0.22), "rubble", yaw=a, cuts=0, jit=0.04)
    b.colbox((0.0, 1.6, 0.0), (5.4, 3.2, 5.4))
    return b.finish()


def stook():
    b = T("FM_Stook", seed=8701, damp=0.3)
    for i in range(6):
        a = math.tau * i / 6
        bx, bz = math.cos(a) * 0.45, math.sin(a) * 0.45
        b.tube((bx, 0.0, bz), (bx * 0.2, 1.5, bz * 0.2), 0.24, 0.18, "hay", sides=7, bark=0.8, jit=0.03, seed=i)
        b.frustum(bx * 0.12, bz * 0.12, 0.2, 0.32, 1.45, 1.85, "hay", round_n=7, levels=2, jit=0.04, seed=i + 5) if i % 2 == 0 else None
    b.tube((0.0, 1.2, 0.0), (0.0, 1.3, 0.0), 0.28, 0.28, "rope", sides=8, bark=1.0)
    return b.finish()


def scarecrow():
    b = T("FM_Scarecrow", seed=8801, damp=0.2)
    b.log((0.0, -0.6, 0.0), (0.04, 2.9, 0.02), 0.07, 0.06, "beam", sides=6, crook=0.04, seed=1)
    b.log((-1.1, 2.12, 0.0), (1.1, 2.24, 0.04), 0.05, 0.045, "beam", sides=5, crook=0.05, seed=2)
    # the coat: a sagging body of sacking hung on the cross, sleeves drooping along the arms, a torn hem
    lathe_at(b, 0.0, 0.02, 1.2, [(0.36, 0.0), (0.3, 0.3), (0.27, 0.7), (0.3, 0.92), (0.16, 1.02)], "cloth", sides=9, jit=0.12, seed=3)
    for sx in (-1, 1):
        b.tube_path([(sx * 0.18, 2.12, 0.02), (sx * 0.55, 2.08, 0.03), (sx * 0.92, 2.1, 0.0)], [0.15, 0.13, 0.11], "cloth", sides=7, bark=0.8, jit=0.03, seed=4 + sx)
        b.tube_path([(sx * 0.6, 2.02, 0.02), (sx * 0.62, 1.8, 0.05), (sx * 0.66, 1.6, 0.04)], [0.06, 0.04, 0.02], "cloth", sides=5, bark=0.8, jit=0.02, seed=6 + sx)
        for k in range(4):
            a = k * 1.4 + sx
            b.tube((sx * 0.98, 2.1, 0.0), (sx * (1.05 + 0.08 * math.cos(a)), 2.0 + 0.1 * math.sin(a), 0.1 * math.sin(a * 1.7)), 0.03, 0.005, "hay", sides=4, bark=0.5)
    for i in range(9):
        a = math.tau * i / 9
        hh = 0.25 + 0.22 * ((i * 37) % 5) / 5.0
        r = 0.34
        b.tube((math.cos(a) * r, 1.22, 0.02 + math.sin(a) * r), (math.cos(a) * (r + 0.06), 1.22 - hh, 0.02 + math.sin(a) * (r + 0.06)), 0.07, 0.02, "cloth", sides=4, bark=0.6)
    lathe_at(b, 0.0, 0.02, 1.48, [(0.3, 0.0), (0.3, 0.06)], "rope", sides=9)
    # the head: a stuffed sack tied at the neck, stitched eyes and mouth, a slouch hat
    lathe_at(b, 0.0, 0.03, 2.3, [(0.06, 0.0), (0.19, 0.08), (0.25, 0.24), (0.23, 0.42), (0.1, 0.52), (0.02, 0.55)], "cloth", sides=10, jit=0.07, seed=8)
    lathe_at(b, 0.0, 0.03, 2.3, [(0.1, 0.0), (0.1, 0.06)], "rope", sides=8)
    for k in range(5):
        a = -0.5 + k * 0.25
        b.box((math.sin(a) * 0.22, 2.48, 0.03 + math.cos(a) * 0.22), (0.06, 0.012, 0.012), "dark", yaw=a, cuts=0, jit=0.0)
    for sx in (-1, 1):
        b.box((sx * 0.09, 2.6, 0.26), (0.06, 0.012, 0.012), "dark", yaw=0.6 * sx, cuts=0, jit=0.0)
        b.box((sx * 0.09, 2.6, 0.26), (0.06, 0.012, 0.012), "dark", yaw=-0.6 * sx, cuts=0, jit=0.0)
    lathe_at(b, 0.0, 0.03, 2.74, [(0.48, -0.06), (0.44, 0.0), (0.22, 0.04), (0.2, 0.22), (0.12, 0.3)], "cloth", sides=12, jit=0.1, seed=9)
    b.colbox((0.0, 1.0, 0.0), (0.3, 2.0, 0.3))
    return b.finish()


def well():
    b = T("FM_Well", seed=8901, damp=1.2)
    lathe_at(b, 0.0, 0.0, -0.8, [(1.05, 0.0), (1.0, 1.75)], "rubble", sides=16, jit=0.02, seed=1)
    b.frustum(0.0, 0.0, 1.12, 1.1, 0.92, 1.1, "stone", round_n=16, levels=2, jit=0.006, tint=TINT["pale"])
    b.frustum(0.0, 0.0, 0.72, 0.72, 0.6, 1.11, "dark", round_n=16, levels=2, jit=0.0)
    for sx in (-1, 1):
        b.beam((sx * 0.95, -0.3, 0.0), (sx * 0.95, 2.6, 0.0), 0.2, 0.2, "beam")
    b.tube((-1.2, 1.85, 0.0), (1.2, 1.85, 0.0), 0.11, 0.11, "beam", sides=8, bark=0.8)
    b.box((1.25, 1.7, 0.12), (0.06, 0.4, 0.06), "iron", cuts=0, jit=0.0)
    b.box((1.25, 1.52, 0.25), (0.06, 0.06, 0.3), "iron", cuts=0, jit=0.0)
    b.tube((0.0, 1.78, 0.0), (0.0, 1.15, 0.0), 0.02, 0.02, "rope", sides=4, bark=1.0, cap=False)
    lathe_at(b, 0.0, 0.0, 0.95, [(0.16, 0.0), (0.2, 0.3)], "plank", sides=10)
    b.gable(-1.2, 1.2, 0.95, 2.55, 3.3, mat="slate", over=0.35, thick=0.16, sag=0.0, seed=2, barge=True)
    b.colbox((0.0, 0.5, 0.0), (2.2, 1.1, 2.2))
    return b.finish()


def wain():
    b = T("FM_Wain", seed=9001, damp=0.5)
    # the bed: planks along x, raves (side rails) on stakes
    b.box((0.0, 1.05, 0.0), (4.4, 0.12, 1.7), "plank", cuts=2, jit=0.01)
    for sz in (-1, 1):
        b.beam((-2.3, 1.0, sz * 0.8), (2.3, 1.0, sz * 0.8), 0.14, 0.18, "beam")
        for i in range(7):
            x = -2.0 + i * 0.66
            b.beam((x, 1.05, sz * 0.86), (x, 1.75, sz * 1.0), 0.07, 0.07, "beam", jit=0.0)
        b.beam((-2.3, 1.75, sz * 1.0), (2.3, 1.75, sz * 1.0), 0.09, 0.09, "beam")
    # wheels: hubs, spokes, rims (front small, back big)
    for (x, r) in ((1.5, 0.55), (-1.3, 0.82)):
        for sz in (-1, 1):
            z = sz * 1.08
            y = r
            n = 16
            for i in range(n):
                a0 = math.tau * i / n
                a1 = math.tau * (i + 1) / n
                p0 = Vector((x + math.cos(a0) * r, y + math.sin(a0) * r, z))
                p1 = Vector((x + math.cos(a1) * r, y + math.sin(a1) * r, z))
                b.beam(p0, p1, 0.1, 0.1, "beam", jit=0.0)
            for i in range(10):
                a = math.tau * i / 10
                b.tube((x, y, z), (x + math.cos(a) * (r - 0.05), y + math.sin(a) * (r - 0.05), z), 0.025, 0.022, "beam", sides=4, bark=1.0, cap=False)
            b.tube((x, y, z - 0.18), (x, y, z + 0.18), 0.1, 0.1, "beam", sides=8, bark=1.0)
        b.tube((x, r, -1.15), (x, r, 1.15), 0.05, 0.05, "iron", sides=5, bark=1.0)
    # the shafts down on the ground, forward
    for sz in (-1, 1):
        b.beam((2.2, 0.95, sz * 0.55), (4.6, 0.12, sz * 0.62), 0.09, 0.09, "beam")
    # a last load: a slumped heap of hay and two sheaves
    lathe_at(b, -0.3, 0.0, 1.05, [(0.85, 0.0), (0.7, 0.35), (0.25, 0.6)], "hay", sides=10, jit=0.1, seed=3)
    b.colbox((0.0, 0.9, 0.0), (4.6, 1.8, 2.3))
    return b.finish()


def hurdle():
    b = T("FM_Hurdle", seed=9101, damp=0.6)
    b.box((0.0, 0.65, 0.0), (2.6, 1.0, 0.1), "wattle", cuts=1, jit=0.02)
    for i in range(5):
        x = -1.2 + i * 0.6
        b.log((x, -0.3, 0.0), (x, 1.2, 0.0), 0.045, 0.04, "beam", sides=5, crook=0.02, seed=i)
    b.colbox((0.0, 0.6, 0.0), (2.6, 1.2, 0.25))
    return b.finish()


def field_gate():
    b = T("FM_Gate", seed=9201, damp=0.6)
    for sx in (-1, 1):
        b.beam((sx * 1.75, -0.6, 0.0), (sx * 1.75, 1.55, 0.0), 0.24, 0.24, "beam")
    for i in range(5):
        y = 0.25 + i * 0.25
        b.beam((-1.55, y, 0.0), (1.55, y, 0.0), 0.06, 0.12, "beam")
    b.beam((-1.55, 0.2, 0.0), (1.55, 1.25, 0.0), 0.06, 0.12, "beam")
    b.beam((-1.55, 0.2, 0.05), (-1.55, 1.3, 0.05), 0.12, 0.12, "beam")
    b.beam((1.55, 0.2, 0.05), (1.55, 1.3, 0.05), 0.12, 0.12, "beam")
    b.colbox((0.0, 0.7, 0.0), (3.8, 1.4, 0.3))
    return b.finish()


def fars():
    hl, hd = BARN_L / 2, BARN_D / 2
    out = [far_piece("FM_BarnFar", [("box", (0, BARN_EAVE / 2 - 0.5, 0), (BARN_L + 0.6, BARN_EAVE + 1.0, BARN_D + 1.6)),
                                    ("roof", -hl, hl, hd + 0.5, BARN_EAVE, BARN_RIDGE, 0.0),
                                    ("box", (0, 3.0, hd + 2.5), (8.0, 6.2, 5.0))]),
           far_piece("FM_HouseFar", [("box", (0, 2.2, 0), (16.6, 5.6, 8.0)), ("roof", -8.6, 8.6, 4.9, 4.6, 11.0, 0.0), ("box", (8.35, 6.0, -0.2), (1.1, 12.0, 1.6))]),
           far_piece("FM_DoveFar", [("drum", 0.0, 0.0, 3.2, 3.0, -0.5, 6.8, 10), ("drum", 0.0, 0.0, 3.8, 0.3, 6.8, 12.0, 10)])]
    return out


def build():
    objs = [tithe_barn(), farmhouse(), cottage(), dovecote(), rick(), stook(), scarecrow(), well(), wain(), hurdle(), field_gate()]
    return objs, fars()


VIEWS = {  # piece -> (look, dist)
    "FM_TitheBarn": ((0.0, 6.0, 1.5), 46.0), "FM_Farmhouse": ((0.0, 4.5, 0.0), 30.0), "FM_Cottage": ((0.0, 3.5, 0.0), 21.0),
    "FM_Dovecote": ((0.0, 5.5, 0.0), 24.0), "FM_Rick": ((0.0, 2.5, 0.0), 13.0), "FM_Stook": ((0.0, 0.9, 0.0), 5.0),
    "FM_Scarecrow": ((0.0, 1.8, 0.0), 6.0), "FM_Well": ((0.0, 1.6, 0.0), 8.0), "FM_Wain": ((0.0, 1.2, 0.0), 10.0),
    "FM_Hurdle": ((0.0, 0.6, 0.0), 5.0), "FM_Gate": ((0.0, 0.7, 0.0), 6.0),
}
