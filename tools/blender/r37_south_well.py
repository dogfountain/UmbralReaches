"""The Well of Echoes' kit and the shepherds' hut and fold (r37 South). Godot coordinates, base at y=0.

  r37_south_well.glb  LedgeSlab (3 m cut stone, kerbed outer edge), LedgeLanding (4 m, kerbs), Corbel (the
                      bracket under a ledge hung from the wall), Pier (a stub pier from the pool), DescentGate
                      (two pillars and a lintel at the rim), CaveMouth (a 7 m arch into the pool wall),
                      Spillway (the stone sluice a stream leaves by), EchoStone, RimPost, Rubble
  r37_south_hut.glb   Hut (dry stone, thatch), FoldWall (A intact, B slumped), Hurdle, Trough, Rack, BellPost,
                      Bench
"""
import math
import random
from mathutils import Vector, Matrix

import r37_south_lib as L
from r37_south_lib import B, hash3, G


def rr(seed):
    return random.Random(seed)


def build_well(DATA, objs):
    chalk = L.pbr("R37_Chalk", L.tex_chalk(1024, 3901), 1.8)
    ash = L.pbr("R37_Ashlar", L.tex_masonry(1024, 3902, rows=6, cold=False), 1.5)
    dark = L.flat("R37_WellDark", (0.008, 0.009, 0.011), 1.0)
    iron = L.flat("R37_WellIron", (0.07, 0.065, 0.06), 0.5, 0.85)
    wood = L.pbr("R37_WellWood", L.tex_planks(512, 3903), 2.4)
    bronze = L.flat("R37_Bronze", (0.22, 0.14, 0.06), 0.45, 0.8)
    mats = {"chalk": chalk, "ash": ash, "dark": dark, "iron": iron, "wood": wood, "bronze": bronze}
    cu = 0.2

    def rubble(b, cx, cz, n, spread, hmax, seed, y0=0.0):
        r = rr(seed)
        for k in range(n):
            a = r.uniform(0, math.tau)
            d = r.uniform(0, spread)
            s = r.uniform(0.35, 1.0) * hmax
            b.box((cx + math.cos(a) * d, y0 + s * 0.3, cz + math.sin(a) * d * 0.7), (s * r.uniform(1.0, 1.7), s * 0.8, s * r.uniform(0.9, 1.4)), "chalk",
                  yaw=r.uniform(0, 3), pitch=r.uniform(-0.3, 0.3), roll=r.uniform(-0.3, 0.3), cuts=1, jit=0.08, seed=seed + k, scale_uv=cu)

    # ---- a cut ledge: the path along the wall. Local +Z is the way along, +X the open (hole) side
    def slab(name, length, kerb, seed):
        b = B(name, mats)
        w = 2.7
        b.box((0, -0.28, 0), (w, 0.56, length), "chalk", cuts=2, jit=0.035, seed=seed, scale_uv=cu)
        b.box((0, -0.78, 0), (w - 0.4, 0.5, length - 0.3), "chalk", cuts=1, jit=0.1, seed=seed + 1, scale_uv=cu, taper=0.8)
        # the worn tread (slightly proud, a darker joint line at each end)
        b.box((0, 0.015, 0), (w - 0.18, 0.05, length - 0.12), "ash", cuts=2, jit=0.012, seed=seed + 2, scale_uv=cu)
        if kerb:
            b.box((w / 2 - 0.2, 0.28, 0), (0.4, 0.6, length), "chalk", cuts=2, jit=0.03, seed=seed + 3, scale_uv=cu)
            b.box((w / 2 - 0.2, 0.62, 0), (0.46, 0.14, length + 0.06), "ash", cuts=1, jit=0.02, seed=seed + 4, scale_uv=cu)
        objs.append(b.finish())

    slab("LedgeSlab", 3.0, True, 10)
    slab("LedgeSlabOpen", 3.0, False, 20)

    # ---- a landing: wider, kerbed all round but the wall side and the way on
    b = B("LedgeLanding", mats)
    b.box((0, -0.3, 0), (4.4, 0.6, 4.2), "chalk", cuts=3, jit=0.04, seed=30, scale_uv=cu)
    b.box((0, -0.9, 0), (3.8, 0.7, 3.6), "chalk", cuts=1, jit=0.12, seed=31, scale_uv=cu, taper=0.8)
    b.box((0, 0.015, 0), (4.2, 0.05, 4.0), "ash", cuts=3, jit=0.012, seed=32, scale_uv=cu)
    b.box((2.05, 0.35, 0), (0.4, 0.7, 4.2), "chalk", cuts=2, jit=0.03, seed=33, scale_uv=cu)
    # the lamp-post stump on the landing: an iron hook for a lantern
    b.box((1.8, 1.1, 1.7), (0.16, 2.2, 0.16), "wood", cuts=1, jit=0.015, seed=34, scale_uv=cu)
    b.box((1.8, 2.12, 1.45), (0.1, 0.1, 0.55), "iron")
    objs.append(b.finish())

    # ---- corbel under a ledge (hung from the wall), a tall one that reaches down into the dark
    b = B("Corbel", mats)
    for i, (y, d) in enumerate(((-0.55, 0.5), (-1.2, 0.8), (-2.0, 1.0), (-3.0, 1.1))):
        b.box((0, y, -0.6 + d * 0.1), (1.4 - i * 0.12, 0.8, 1.3 + d * 0.3), "chalk", cuts=1, jit=0.07, seed=40 + i, scale_uv=cu)
    objs.append(b.finish())

    # ---- a pier: a squared stub standing in the pool
    b = B("Pier", mats)
    b.box((0, 2.0, 0), (1.9, 4.0, 1.9), "ash", cuts=3, jit=0.06, seed=50, scale_uv=cu, taper=0.85)
    b.box((0, 4.15, 0), (2.2, 0.3, 2.2), "ash", cuts=2, jit=0.03, seed=51, scale_uv=cu)
    objs.append(b.finish())

    # ---- the descent gate at the rim: two squared pillars and a lintel, one lantern hook
    b = B("DescentGate", mats)
    for sx in (-1.0, 1.0):
        b.box((sx * 1.9, -0.6, 0), (1.3, 1.6, 1.3), "ash", cuts=1, jit=0.04, seed=60, scale_uv=cu)
        b.box((sx * 1.9, 2.1, 0), (1.0, 4.2, 1.0), "ash", cuts=4, jit=0.04, seed=61 + int(sx), scale_uv=cu, taper=0.92)
        b.box((sx * 1.9, 4.35, 0), (1.35, 0.3, 1.35), "ash", cuts=1, jit=0.03, seed=63, scale_uv=cu)
    b.box((0.25, 4.7, 0), (5.2, 0.7, 1.1), "ash", cuts=3, jit=0.05, seed=64, scale_uv=cu, roll=0.04)
    # the carved word: three rings, one inside the other (the echo)
    for k, rad in enumerate((0.34, 0.22, 0.1)):
        b.box((0.25, 4.7, 0.57), (rad * 2, rad * 2, 0.04), "dark", roll=0.0, scale_uv=cu)
        b.box((0.25, 4.7, 0.585), (rad * 2 - 0.06, rad * 2 - 0.06, 0.03), "ash", scale_uv=cu)
    b.box((-1.2, 3.8, -0.65), (0.07, 0.07, 0.8), "iron")
    objs.append(b.finish())

    # ---- the cave mouth in the pool wall: an arch, a dark throat, the fallen keystone
    b = B("CaveMouth", mats)
    R = 3.3
    n = 15
    for i in range(n):
        a0 = math.pi * i / n
        a1 = math.pi * (i + 1) / n
        am = (a0 + a1) / 2
        rm = R + 0.55
        b.box((math.cos(am) * rm, 1.2 + math.sin(am) * rm, 0), (1.05, 1.05, 2.6), "ash", roll=am - math.pi / 2, cuts=1, jit=0.04, seed=70 + i, scale_uv=cu)
    for sx in (-1.0, 1.0):
        b.box((sx * (R + 0.55), 0.7, 0), (1.05, 2.6, 2.6), "ash", cuts=2, jit=0.04, seed=90, scale_uv=cu)
        b.box((sx * (R + 2.2), 1.9, -0.4), (2.4, 3.8, 2.2), "chalk", cuts=3, jit=0.25, seed=91 + int(sx), scale_uv=cu)
    b.box((0, 0.9, 1.15), (R * 2 + 0.2, 4.2, 0.1), "dark")                 # the black throat
    b.box((0, 0.03, 1.2), (R * 2 - 0.4, 0.06, 2.4), "dark")
    b.box((0.3, 0.45, 2.2), (1.1, 0.9, 0.9), "ash", roll=0.3, yaw=0.5, cuts=1, jit=0.05, seed=95, scale_uv=cu)
    rubble(b, -2.0, 2.4, 9, 1.8, 0.7, 96)
    objs.append(b.finish())

    # ---- the spillway: the stone sluice the stream leaves by, a plank stop-gate raised on its winch
    b = B("Spillway", mats)
    W = 3.2
    b.box((0, -0.5, 0), (W + 2.0, 1.0, 9.0), "chalk", cuts=3, jit=0.05, seed=100, scale_uv=cu)
    for sx in (-1.0, 1.0):
        b.box((sx * (W / 2 + 0.4), 0.5, 0), (0.8, 1.2, 9.0), "ash", cuts=3, jit=0.04, seed=101 + int(sx), scale_uv=cu)
    b.box((0, 0.04, 0), (W - 0.1, 0.1, 9.0), "ash", cuts=3, jit=0.02, seed=103, scale_uv=cu)
    # the lip: a worn notch at the downstream end
    b.box((0, 0.04, 4.55), (W + 1.6, 0.22, 0.5), "ash", cuts=1, jit=0.02, seed=104, scale_uv=cu)
    # the sluice-gate frame: two posts, a cross-beam, a plank stop hauled up
    for sx in (-1.0, 1.0):
        b.box((sx * (W / 2 + 0.2), 1.8, -2.0), (0.28, 3.0, 0.28), "wood", cuts=1, jit=0.015, seed=105, scale_uv=cu)
    b.box((0, 3.2, -2.0), (W + 0.9, 0.28, 0.3), "wood", cuts=1, jit=0.015, seed=106, scale_uv=cu)
    b.box((0, 2.5, -2.0), (W - 0.2, 0.9, 0.12), "wood", cuts=1, jit=0.01, seed=107, scale_uv=cu)
    b.box((0, 3.45, -2.0), (0.14, 0.14, 0.9), "iron")
    objs.append(b.finish())

    # ---- the echo stone: the carved slab at the rim you drop a pebble beside, a bronze listening ring
    b = B("EchoStone", mats)
    b.box((0, 0.2, 0), (1.5, 0.4, 1.2), "ash", cuts=1, jit=0.03, seed=110, scale_uv=cu)
    b.box((0, 1.6, 0), (0.9, 2.5, 0.55), "chalk", cuts=4, jit=0.04, seed=111, scale_uv=cu, taper=0.9)
    for k, rad in enumerate((0.32, 0.22, 0.12)):
        b.box((0, 1.95, 0.282), (rad * 2, rad * 2, 0.03), "dark")
        b.box((0, 1.95, 0.295), (rad * 2 - 0.05, rad * 2 - 0.05, 0.03), "chalk", scale_uv=cu)
    b.box((0, 1.0, 0.3), (0.34, 0.34, 0.05), "bronze")
    b.box((0, 1.0, 0.33), (0.2, 0.2, 0.05), "dark")
    objs.append(b.finish())

    b = B("RimPost", mats)
    b.box((0, 0.7, 0), (0.45, 1.4, 0.4), "chalk", cuts=2, jit=0.03, seed=120, scale_uv=cu, taper=0.85)
    b.box((0, 1.45, 0), (0.55, 0.12, 0.5), "ash", cuts=1, jit=0.02, seed=121, scale_uv=cu)
    objs.append(b.finish())

    b = B("Rubble", mats)
    rubble(b, 0, 0, 16, 2.6, 0.9, 130)
    objs.append(b.finish())

    DATA["WELL_LEDGE_W"] = 2.7
    DATA["WELL_LEDGE_L"] = 3.0
    DATA["WELL_LANDING"] = 4.2
    DATA["WELL_GATE_W"] = 5.2
    DATA["WELL_CAVE_W"] = 7.0
    DATA["WELL_SPILL_L"] = 9.0
    DATA["WELL_SPILL_W"] = 5.2


def build_hut(DATA, objs):
    ston = L.pbr("R37_HutStone", L.tex_masonry(1024, 3951, rows=9, cold=False), 1.5)
    thatch = L.pbr("R37_Thatch", L.tex_thatch(1024, 3952), 1.8)
    wood = L.pbr("R37_HutWood", L.tex_planks(512, 3953), 2.4)
    dark = L.flat("R37_HutDark", (0.01, 0.01, 0.012), 1.0)
    iron = L.flat("R37_HutIron", (0.07, 0.065, 0.06), 0.5, 0.85)
    cu = 0.2
    mats = {"stone": ston, "thatch": thatch, "wood": wood, "dark": dark, "iron": iron}
    thatch.use_backface_culling = False

    b = B("Hut", mats)
    W, D, H = 5.0, 3.8, 2.05
    b.box((0, -0.5, 0), (W + 0.5, 1.0, D + 0.5), "stone", cuts=2, jit=0.06, seed=200, scale_uv=cu)
    b.box((0, H / 2, 0), (W, H, D), "stone", cuts=5, jit=0.07, seed=201, scale_uv=cu)
    # gable ends in stone up to the ridge, the roof beams, a heavy thatch with a ragged hem
    for sx in (-1.0, 1.0):
        pts = [(sx * W / 2, H, -D / 2), (sx * W / 2, H, D / 2), (sx * W / 2, H + 1.5, 0.0)]
        uv = [(0, 0), (D * cu, 0), (D * 0.5 * cu, 1.5 * cu)]
        b.face(pts, "stone", uvs=uv)
        b.face(list(reversed(pts)), "stone", uvs=list(reversed(uv)))
    rise = 1.7
    span = D / 2 + 0.75
    ang = math.atan2(rise + 0.2, D / 2)
    for sz in (-1.0, 1.0):
        b.box((0, H + 0.62, sz * (D / 4 + 0.15)), (W + 1.3, 0.34, span * 1.02), "thatch", pitch=sz * ang, cuts=4, jit=0.05, seed=210 + int(sz), scale_uv=cu * 0.7)
    b.box((0, H + 1.5, 0), (W + 1.4, 0.3, 0.5), "thatch", cuts=2, jit=0.04, seed=215, scale_uv=cu)
    # door (open, dark) with a plank door standing ajar; one small window; the chimney stack
    b.box((-0.9, 0.95, D / 2 + 0.02), (0.95, 1.9, 0.1), "dark")
    b.box((-0.9, 1.95, D / 2 + 0.05), (1.3, 0.3, 0.4), "stone", cuts=1, jit=0.03, seed=216, scale_uv=cu)
    b.box((-0.35, 0.9, D / 2 + 0.55), (0.9, 1.8, 0.07), "wood", yaw=-1.15, cuts=1, jit=0.01, seed=217, scale_uv=cu)
    b.box((1.2, 1.25, D / 2 + 0.02), (0.55, 0.45, 0.1), "dark")
    b.box((W / 2 + 0.12, H + 1.3, -0.4), (1.0, 3.2, 1.0), "stone", cuts=3, jit=0.06, seed=218, scale_uv=cu, taper=0.9)
    b.box((W / 2 + 0.12, H + 3.0, -0.4), (1.2, 0.2, 1.2), "stone", cuts=1, jit=0.03, seed=219, scale_uv=cu)
    # a woodstack and a lean-to board against the back
    for i in range(14):
        b.box((-1.2 + (i % 7) * 0.32, 0.17 + (i // 7) * 0.34, -D / 2 - 0.35), (0.26, 0.26, 0.9), "wood", yaw=0.0, roll=0.0, cuts=0, scale_uv=cu * 2)
    objs.append(b.finish())

    # ---- the fold wall: dry stone, coped, 4 m long, 1.3 m high; B slumped
    for name, slump in (("FoldWall", False), ("FoldWallB", True)):
        b = B(name, mats)
        Lw = 4.0
        b.box((0, -0.3, 0), (Lw + 0.1, 0.8, 0.95), "stone", cuts=2, jit=0.05, seed=300, scale_uv=cu)
        if not slump:
            b.box((0, 0.7, 0), (Lw, 1.1, 0.75), "stone", cuts=4, jit=0.07, seed=301, scale_uv=cu, taper=0.92)
            for k in range(5):
                b.box((-1.6 + k * 0.8, 1.32, 0), (0.78, 0.2, 0.62), "stone", cuts=1, jit=0.05, seed=302 + k, scale_uv=cu, yaw=hash3(k, 1, 2) * 0.1)
        else:
            b.box((-1.0, 0.45, 0), (2.0, 0.7, 0.75), "stone", cuts=3, jit=0.1, seed=301, scale_uv=cu)
            r = rr(310)
            for k in range(9):
                b.box((r.uniform(-0.2, 2.0), 0.2 + r.uniform(0, 0.3), r.uniform(-0.7, 0.9)), (r.uniform(0.4, 0.8), 0.4, r.uniform(0.4, 0.7)), "stone",
                      yaw=r.uniform(0, 3), pitch=r.uniform(-0.2, 0.2), cuts=1, jit=0.06, seed=320 + k, scale_uv=cu)
        objs.append(b.finish())

    # ---- a woven hurdle: 1.8 x 1.0, a frame of rails, willow rods up and down
    b = B("Hurdle", mats)
    for z in (-0.84, 0.84):
        b.box((0, 0.5, z), (0.08, 1.0, 0.08), "wood", cuts=0, scale_uv=cu * 2)
    for y in (0.12, 0.5, 0.88):
        b.box((0, y, 0), (0.06, 0.06, 1.8), "wood", scale_uv=cu * 2)
    r = rr(330)
    for k in range(13):
        z = -0.78 + k * 0.13
        b.box((0.035 * (1 if k % 2 else -1), 0.5, z), (0.035, 0.96, 0.035), "wood", roll=r.uniform(-0.03, 0.03), scale_uv=cu * 2)
    objs.append(b.finish())

    b = B("Trough", mats)
    b.box((0, 0.35, 0), (0.7, 0.7, 2.2), "stone", cuts=2, jit=0.03, seed=340, scale_uv=cu)
    b.box((0, 0.66, 0), (0.46, 0.14, 1.9), "dark")
    objs.append(b.finish())

    b = B("Rack", mats)
    for sz in (-1.0, 1.0):
        b.box((0.45 * sz, 0.8, 0), (0.08, 1.7, 0.08), "wood", roll=0.28 * -sz, scale_uv=cu * 2)
        b.box((0.45 * sz, 0.8, 1.0), (0.08, 1.7, 0.08), "wood", roll=0.28 * -sz, scale_uv=cu * 2)
        b.box((0.45 * sz, 0.8, -1.0), (0.08, 1.7, 0.08), "wood", roll=0.28 * -sz, scale_uv=cu * 2)
    for k in range(5):
        b.box((0, 0.5 + k * 0.28, 0), (0.9 - k * 0.1, 0.05, 2.2), "wood", scale_uv=cu * 2)
    b.box((0, 0.2, 0), (0.7, 0.1, 2.0), "thatch")
    objs.append(b.finish())

    b = B("BellPost", mats)
    b.box((0, 1.15, 0), (0.17, 2.3, 0.17), "wood", cuts=1, jit=0.012, seed=350, scale_uv=cu * 2)
    b.box((0.35, 2.25, 0), (0.8, 0.12, 0.12), "wood", scale_uv=cu * 2)
    b.box((0.7, 1.95, 0), (0.05, 0.5, 0.05), "iron")
    b.box((0.7, 1.62, 0), (0.28, 0.26, 0.28), "iron", taper=0.55)
    objs.append(b.finish())

    b = B("Bench", mats)
    b.box((0, 0.5, 0), (1.9, 0.12, 0.5), "wood", scale_uv=cu * 2)
    for sx in (-0.8, 0.8):
        for sz in (-0.18, 0.18):
            b.box((sx, 0.24, sz), (0.1, 0.5, 0.1), "wood", scale_uv=cu * 2)
    b.box((0.3, 0.6, 0.0), (0.4, 0.1, 0.25), "iron", roll=0.0)
    objs.append(b.finish())

    DATA["HUT_W"] = 5.0
    DATA["HUT_D"] = 3.8
    DATA["HUT_H"] = 3.55
