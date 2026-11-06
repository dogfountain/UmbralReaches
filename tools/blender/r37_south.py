"""r37 South assets, by script: tools/blender/run.sh r37_south.py -- [--only wall|oak|well|hut] [--preview DIR]

  art/models/r37_south_wall.glb   the March Wall kit: WallSeg_A/B/C, Tower, TowerRuin, Gatehouse, BreachStub,
                                  Rubble, and the far meshes WallFar, TowerFar, GateFar
  art/models/r37_south_oak.glb    the Grandmother Oak: Trunk (hollow, bark), Roots, Limbs, Stair, Crown, OakFar
  art/models/r37_south_well.glb   the Well of Echoes: LedgeSlab, LedgeStep, Pier, DescentGate, CaveMouth,
                                  Spillway, EchoStone, RimPost
  art/models/r37_south_hut.glb    the shepherds' hut and fold: Hut, FoldWall, Hurdle, Trough, Rack, BellPost
  core/world/realm/r37_south_data.gd   the numbers the game needs (collision, stair, limbs), written by the script

Masonry, bark, chalk, thatch and plank maps are generated in r37_south_lib.py (no downloads).
"""
import sys
import os
import math

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib
import r37_south_lib as L
importlib.reload(L)
from r37_south_lib import B, V, G, Vector, Matrix, np, hash3

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ONLY = ARGS[ARGS.index("--only") + 1] if "--only" in ARGS else "all"
PREVIEW = ARGS[ARGS.index("--preview") + 1] if "--preview" in ARGS else ""
DATA = {}          # name -> python literal, written to r37_south_data.gd

STONE_UV = 0.16


def rng_for(seed):
    import random
    r = random.Random(seed)
    return r


# =================================================================================================
# THE MARCH WALL
# =================================================================================================

def build_wall():
    stone = L.ashlar("R37_WallStone", 4101)
    dark = L.flat("R37_Dark", (0.01, 0.01, 0.012), 1.0)
    wood = L.pbr("R37_GateWood", L.tex_planks(512, 3702), 2.4)
    iron = L.flat("R37_Iron", (0.08, 0.075, 0.07), 0.55, 0.85)
    mats = {"stone": stone, "dark": dark, "wood": wood, "iron": iron}
    objs = []

    def merlons(b, x0, x1, y, z, step, mw, mh, mt, seed, skip=(), tall=0.0, mat="stone"):
        i = 0
        x = x0
        while x + mw <= x1 + 1e-6:
            if i not in skip:
                b.box((x + mw / 2, y + mh / 2, z), (mw, mh, mt), mat, cuts=1, jit=0.035, seed=seed + i, yaw=(hash3(i, 0, seed) * 0.03))
            x += step
            i += 1

    def rubble(b, cx, cz, n, spread, hmax, seed, y0=0.0):
        r = rng_for(seed)
        for k in range(n):
            a = r.uniform(0, math.tau)
            d = r.uniform(0, spread)
            s = r.uniform(0.35, 1.0) * hmax
            b.box((cx + math.cos(a) * d, y0 + s * 0.3, cz + math.sin(a) * d * 0.7), (s * r.uniform(1.0, 1.7), s * 0.8, s * r.uniform(0.9, 1.4)), "stone",
                  yaw=r.uniform(0, 3), pitch=r.uniform(-0.3, 0.3), roll=r.uniform(-0.3, 0.3), cuts=1, jit=0.07, seed=seed + k)

    def wall_body(b, length, h, seed, ruin=0.0):
        # the battered curtain (outer face +Z): a footing skirt, the body, the walk, the parapet's footing
        b.box((0, -1.6, 0), (length + 0.4, 3.6, 3.5), "stone", cuts=3, jit=0.06, seed=seed)
        b.box((0, h / 2, 0), (length, h, 2.9), "stone", cuts=5, jit=0.055, seed=seed + 1, taper=0.82)
        # the walkway (inner side), a drip course below the parapet
        b.box((0, h + 0.1, -0.35), (length, 0.35, 2.2), "stone", cuts=2, jit=0.03, seed=seed + 2)
        b.box((0, h - 0.5, 1.2), (length, 0.3, 0.6), "stone", cuts=1, jit=0.03, seed=seed + 3)

    # ---- intact segment
    def seg(name, kind, seed):
        b = B(name, mats)
        Lx = 12.0
        H = 6.4
        wall_body(b, Lx, H, seed)
        if kind == "A":
            merlons(b, -5.9, 5.9, H + 0.28, 1.0, 2.0, 1.3, 1.15, 0.7, seed + 10)
            b.box((0, H + 0.45, 1.0), (Lx, 0.5, 0.65), "stone", cuts=1, jit=0.04, seed=seed + 11)    # the parapet's low course
            b.box((0, H + 0.5, -1.3), (Lx, 0.45, 0.4), "stone", cuts=1, jit=0.03, seed=seed + 12)     # inner lip
        elif kind == "B":
            merlons(b, -5.9, 5.9, H + 0.28, 1.0, 2.0, 1.3, 1.15, 0.7, seed + 10, skip=(2, 3))
            b.box((-4.0, H + 0.45, 1.0), (3.9, 0.5, 0.65), "stone", cuts=1, jit=0.04, seed=seed + 11)
            b.box((4.2, H + 0.45, 1.0), (3.6, 0.5, 0.65), "stone", cuts=1, jit=0.04, seed=seed + 12)
            rubble(b, 0.5, 2.6, 7, 2.0, 0.9, seed + 13)
        else:
            # C: the upper wall is down for half its length; the top ragged, the rubble at the foot
            b.box((-3.6, H + 0.28, 0.6), (4.8, 1.2, 1.4), "stone", cuts=2, jit=0.18, seed=seed + 11)
            merlons(b, -5.9, -2.0, H + 0.28, 1.0, 2.0, 1.3, 1.15, 0.7, seed + 10)
            b.box((3.2, H - 1.4, 0.5), (5.0, 1.6, 2.3), "stone", cuts=2, jit=0.22, seed=seed + 14)
            rubble(b, 3.0, 2.8, 12, 3.0, 1.1, seed + 13)
        # arrow slits and weathering
        for i in (-3.6, 0.0, 3.6):
            if kind != "C" or i < 0:
                b.box((i, 3.4, 1.38), (0.2, 1.0, 0.1), "dark")
        # buttresses on the outer face at the joints
        for sx in (-5.5, 5.5):
            b.box((sx, 2.3, 1.95), (1.3, 4.6, 1.1), "stone", cuts=2, jit=0.05, seed=seed + 15, taper=0.7)
        ob = b.finish()
        objs.append(ob)
        return ob

    seg("WallSeg_A", "A", 100)
    seg("WallSeg_B", "B", 200)
    seg("WallSeg_C", "C", 300)

    # ---- tower (local origin: base centre; door on the inner side -Z)
    def tower(name, ruin, seed):
        b = B(name, mats)
        S = 7.2
        H = 13.6 if not ruin else 8.8
        b.box((0, -1.8, 0), (S + 1.0, 4.0, S + 1.0), "stone", cuts=3, jit=0.07, seed=seed)
        b.box((0, H / 2, 0), (S, H, S), "stone", cuts=7, jit=0.065, seed=seed + 1, taper=0.86)
        top = H * 0.86 + 0.0
        if not ruin:
            # corbel course, an overhanging parapet, merlons all round, a roof deck
            b.box((0, H - 1.0, 0), (S * 0.86 + 1.1, 0.7, S * 0.86 + 1.1), "stone", cuts=3, jit=0.04, seed=seed + 2)
            b.box((0, H + 0.1, 0), (S * 0.86 + 0.9, 0.45, S * 0.86 + 0.9), "stone", cuts=3, jit=0.03, seed=seed + 3)
            W = S * 0.86 + 0.7
            for side in range(4):
                yaw = side * math.pi / 2
                for k in range(5):
                    x = -W / 2 + 0.3 + k * (W - 0.9) / 4
                    pos = Matrix.Rotation(yaw, 3, 'Y') @ Vector((x, 0, W / 2 - 0.2))
                    b.box((pos.x, H + 0.88, pos.z), (1.05, 1.2, 0.6), "stone", yaw=yaw, cuts=1, jit=0.03, seed=seed + 20 + side * 5 + k)
            # a lookout turret stub in one corner, roof beams burned
            b.box((W / 2 - 1.4, H + 1.9, -W / 2 + 1.4), (2.4, 2.6, 2.4), "stone", cuts=2, jit=0.07, seed=seed + 5)
        else:
            # broken: one corner stands a storey higher, the rest jagged
            b.box((1.3, H + 1.2, 1.3), (3.8, 3.2, 3.6), "stone", cuts=3, jit=0.2, seed=seed + 6)
            b.box((-1.6, H + 0.4, -0.6), (3.2, 1.5, 4.6), "stone", cuts=3, jit=0.22, seed=seed + 7)
            r = rng_for(seed)
            for k in range(14):
                a = r.uniform(0, math.tau)
                d = r.uniform(S * 0.6, S * 1.15)
                s = r.uniform(0.5, 1.2)
                b.box((math.cos(a) * d, s * 0.3, math.sin(a) * d), (s * 1.4, s * 0.8, s * 1.1), "stone", yaw=r.uniform(0, 3), pitch=r.uniform(-.3, .3), cuts=1, jit=0.08, seed=seed + k)
        # slits on three faces, two levels; the door on -Z at wall-walk height with a stone lintel
        for lv in (4.0, 8.0):
            if lv < H - 1.0:
                for yaw in (0.0, math.pi / 2, -math.pi / 2):
                    p = Matrix.Rotation(yaw, 3, 'Y') @ Vector((0, lv, S * 0.5 * (1.0 - (lv / H) * 0.14) + 0.02))
                    b.box((p.x, p.y, p.z), (0.22, 1.1, 0.1), "dark", yaw=yaw)
        db = 6.4
        b.box((0, db + 1.2, -S * 0.5 * (1.0 - (db / H) * 0.14) - 0.02), (1.6, 2.4, 0.2), "dark")
        b.box((0, db + 2.6, -S * 0.5 * (1.0 - (db / H) * 0.14) - 0.05), (2.2, 0.4, 0.4), "stone", cuts=1, jit=0.03, seed=seed + 9)
        for sx in (-1.0, 1.0):
            b.box((sx * 0.95, db + 1.2, -S * 0.5 * (1.0 - (db / H) * 0.14) - 0.05), (0.35, 2.6, 0.4), "stone", cuts=1, jit=0.03, seed=seed + 10)
        ob = b.finish()
        objs.append(ob)
        return ob

    tower("Tower", False, 400)
    tower("TowerRuin", True, 500)

    # ---- gatehouse: the wall along X, the road through it along Z; twin towers and the arch
    def gatehouse(seed):
        b = B("Gatehouse", mats)
        TW = 7.4            # tower width (x)
        TD = 8.6            # depth (z)
        H = 13.0
        PX = 6.5            # tower centre x
        PW = 5.6            # passage clear width
        for sx in (-1.0, 1.0):
            cx = sx * PX
            b.box((cx, -1.8, 0), (TW + 1.0, 4.0, TD + 1.0), "stone", cuts=3, jit=0.07, seed=seed + int(sx))
            b.box((cx, H / 2, 0), (TW, H, TD), "stone", cuts=7, jit=0.06, seed=seed + 2 + int(sx), taper=0.9)
            b.box((cx, H - 0.9, 0), (TW * 0.9 + 1.0, 0.7, TD * 0.9 + 1.0), "stone", cuts=3, jit=0.04, seed=seed + 3)
            b.box((cx, H + 0.1, 0), (TW * 0.9 + 0.8, 0.45, TD * 0.9 + 0.8), "stone", cuts=3, jit=0.03, seed=seed + 4)
            Wx = TW * 0.9 + 0.6
            Wz = TD * 0.9 + 0.6
            for k in range(4):
                for zz in (-1.0, 1.0):
                    b.box((cx - Wx / 2 + 0.7 + k * (Wx - 1.4) / 3, H + 0.9, zz * (Wz / 2 - 0.2)), (1.1, 1.2, 0.6), "stone", cuts=1, jit=0.03, seed=seed + 30 + k)
            for k in range(3):
                for xx in (-1.0, 1.0):
                    b.box((cx + xx * (Wx / 2 - 0.2), H + 0.9, -Wz / 2 + 0.9 + k * (Wz - 1.8) / 2), (0.6, 1.2, 1.05), "stone", cuts=1, jit=0.03, seed=seed + 40 + k)
            for zz in (-1.0, 1.0):          # slits on the field faces
                for lv in (4.2, 8.4):
                    b.box((cx, lv, zz * (TD * 0.5 * 0.95 + 0.02)), (0.22, 1.1, 0.1), "dark")
        # the vault: a semicircular arch of voussoirs over the passage, the room above, a broken parapet
        R = PW / 2
        ay = 5.0
        n = 13
        for i in range(n):
            a0 = math.pi * i / n
            a1 = math.pi * (i + 1) / n
            am = (a0 + a1) / 2
            rm = R + 0.45
            b.box((math.cos(am) * rm, ay + math.sin(am) * rm, 0), (0.95, 0.9, TD * 0.96), "stone", roll=am - math.pi / 2, cuts=1, jit=0.03, seed=seed + 60 + i)
        # (voussoirs are boxes set on the radius; the jitter makes them read as cut stone)
        b.box((0, ay + R + 0.9, 0), (PW + 2.4, 1.4, TD * 0.96), "stone", cuts=3, jit=0.04, seed=seed + 70)
        b.box((0, ay + R + 2.6, 0), (PW + 2.2, 2.0, TD * 0.9), "stone", cuts=3, jit=0.05, seed=seed + 71)      # the room over the gate
        b.box((0, 10.65, 0), (PW + 3.2, 0.45, TD * 0.96), "stone", cuts=3, jit=0.03, seed=seed + 72)
        for k in range(3):
            for zz in (-1.0, 1.0):
                if not (zz > 0 and k == 1):
                    b.box((-2.2 + k * 2.2, 11.4, zz * (TD * 0.46)), (1.2, 1.15, 0.6), "stone", cuts=1, jit=0.03, seed=seed + 80 + k)
        # the gate leaves: one hangs from its top hinge, split, one lies against the tower foot
        b.box((-R + 0.05, 2.2, TD / 2 - 0.9), (2.6, 4.4, 0.2), "wood", roll=-0.16, yaw=0.0, cuts=2, jit=0.03, seed=seed + 90)
        b.box((-R + 0.02, 2.2, TD / 2 - 0.82), (0.24, 4.5, 0.06), "iron")
        b.box((-R + 0.02, 1.0, TD / 2 - 0.82), (2.6, 0.12, 0.06), "iron")
        b.box((-R + 0.02, 3.4, TD / 2 - 0.82), (2.6, 0.12, 0.06), "iron")
        b.box((R + 0.2, 0.55, TD / 2 - 2.2), (2.5, 0.2, 4.2), "wood", pitch=0.0, roll=0.3, yaw=0.9 + 3.14159 * 0, cuts=2, jit=0.03, seed=seed + 91)
        # a portcullis stub: the iron teeth hanging in the groove
        for i in range(7):
            b.box((-R + 0.4 + i * 0.7, ay + R * 0.55, -TD / 2 + 1.6), (0.07, 2.8, 0.07), "iron")
        # the road's sill: the threshold stones
        b.box((0, 0.04, 0), (PW - 0.2, 0.14, TD * 0.9), "stone", cuts=3, jit=0.02, seed=seed + 95)
        ob = b.finish()
        objs.append(ob)
        return ob

    gatehouse(600)

    # ---- the stub where a track passes through a breach, left and right ends of the gap (mirror by yaw)
    def stub(seed):
        b = B("BreachStub", mats)
        b.box((0, -1.6, 0), (6.4, 3.6, 3.5), "stone", cuts=3, jit=0.06, seed=seed)
        # the standing end, sloping down into the gap (+X end is the gap)
        steps = [(-2.8, 6.4), (-1.5, 6.0), (-0.3, 4.6), (0.9, 3.0), (1.9, 1.6), (2.7, 0.6)]
        for i, (x, h) in enumerate(steps):
            b.box((x, h / 2, 0), (1.35, h, 2.9 - 0.12 * i), "stone", cuts=2, jit=0.1, seed=seed + i, taper=0.9)
        merlons(b, -3.0, -1.8, 6.68, 1.0, 2.0, 1.3, 1.1, 0.7, seed + 20)
        rubble(b, 3.5, 0.0, 14, 3.4, 1.2, seed + 30)
        ob = b.finish()
        objs.append(ob)

    stub(700)

    def rubble_mound(seed):
        b = B("Rubble", mats)
        rubble(b, 0, 0, 22, 4.2, 1.0, seed)
        b.box((0, 0.3, 0), (7.0, 0.6, 5.0), "stone", cuts=3, jit=0.2, seed=seed + 1)
        objs.append(b.finish())

    rubble_mound(800)

    # ---- far meshes: the silhouette only (a few dozen triangles; the same stone map)
    def far():
        for name, kind in (("WallFar", "wall"), ("TowerFar", "tower"), ("GateFar", "gate")):
            b = B(name, {"stone": stone})
            if kind == "wall":
                b.box((0, 3.4, 0), (12.0, 6.8, 2.6), "stone", taper=0.82, scale_uv=STONE_UV)
                b.box((0, 7.0, 0.8), (12.0, 0.9, 0.7), "stone", scale_uv=STONE_UV)
            elif kind == "tower":
                b.box((0, 6.8, 0), (7.2, 13.6, 7.2), "stone", taper=0.86, scale_uv=STONE_UV)
                b.box((0, 14.0, 0), (7.4, 1.6, 7.4), "stone", scale_uv=STONE_UV)
            else:
                for sx in (-1.0, 1.0):
                    b.box((sx * 6.5, 6.5, 0), (7.4, 13.0, 8.6), "stone", taper=0.9, scale_uv=STONE_UV)
                b.box((0, 9.6, 0), (6.0, 6.4, 8.2), "stone", scale_uv=STONE_UV)
            objs.append(b.finish())

    far()

    DATA["WALL_LEN"] = 12.0
    DATA["WALL_H"] = 7.2
    DATA["WALL_T"] = 2.6
    DATA["TOWER_S"] = 7.2
    DATA["TOWER_H"] = 13.6
    DATA["GATE_TW"] = 7.4
    DATA["GATE_TD"] = 8.6
    DATA["GATE_PX"] = 6.5
    DATA["GATE_PW"] = 5.6
    DATA["GATE_H"] = 13.0

    path = os.path.join(L.MODEL_DIR, "r37_south_wall.glb")
    L.export(path, objs)
    if PREVIEW:
        os.makedirs(PREVIEW, exist_ok=True)
        # lay the kit out in a row for the still
        x = 0.0
        for o in objs:
            pass
        place_row(objs, ["WallSeg_A", "WallSeg_B", "WallSeg_C", "Tower", "TowerRuin", "Gatehouse", "BreachStub", "Rubble"], 14.0)
        L.preview(os.path.join(PREVIEW, "wall.png"), objs, look_at=(46, 5, 0), dist=95.0, views=((18, 0.3),), res=(1500, 560), lens=35)
        L.preview(os.path.join(PREVIEW, "gate.png"), objs, look_at=(70, 5, 0), dist=30.0, views=((20, 0.18), (150, 0.25)), res=(1100, 700), lens=35)


def place_row(objs, order, step):
    x = 0.0
    for name in order:
        for o in objs:
            if o.name == name:
                o.location = G((x, 0, 0))
                x += step
                break


# =================================================================================================
# main
# =================================================================================================

def build_oak():
    import r37_south_oak as O
    importlib.reload(O)
    objs = []
    O.build(DATA, PREVIEW, objs)
    vis = [o for o in objs if not o.name.endswith("Col")]
    path = os.path.join(L.MODEL_DIR, "r37_south_oak.glb")
    L.export(path, objs)
    if PREVIEW:
        os.makedirs(PREVIEW, exist_ok=True)
        for o in objs:
            if o.name.endswith("Col") or o.name == "OakFar":
                o.hide_render = True
        L.preview(os.path.join(PREVIEW, "oak.png"), vis, look_at=(0, 18, 0), dist=95.0, views=((200, 0.12), (110, 0.2)), res=(900, 1100), lens=40)


def build_well():
    import r37_south_well as W
    importlib.reload(W)
    objs = []
    W.build_well(DATA, objs)
    L.export(os.path.join(L.MODEL_DIR, "r37_south_well.glb"), objs)
    if PREVIEW:
        os.makedirs(PREVIEW, exist_ok=True)
        place_row(objs, ["LedgeSlab", "LedgeSlabOpen", "LedgeLanding", "Corbel", "Pier", "DescentGate", "CaveMouth", "Spillway", "EchoStone", "RimPost", "Rubble"], 9.0)
        L.preview(os.path.join(PREVIEW, "well.png"), objs, look_at=(45, 3, 0), dist=70.0, views=((14, 0.25),), res=(1500, 600), lens=35)


def build_hut():
    import r37_south_well as W
    importlib.reload(W)
    objs = []
    W.build_hut(DATA, objs)
    L.export(os.path.join(L.MODEL_DIR, "r37_south_hut.glb"), objs)
    if PREVIEW:
        os.makedirs(PREVIEW, exist_ok=True)
        place_row(objs, ["Hut", "FoldWall", "FoldWallB", "Hurdle", "Trough", "Rack", "BellPost", "Bench"], 7.0)
        L.preview(os.path.join(PREVIEW, "hut.png"), objs, look_at=(24, 2, 0), dist=40.0, views=((20, 0.28),), res=(1500, 600), lens=35)


def write_data():
    import json
    jp = os.path.join(L.TEX_DIR, "data.json")
    cur = {}
    if os.path.exists(jp):
        cur = json.load(open(jp))
    cur.update(DATA)
    os.makedirs(L.TEX_DIR, exist_ok=True)
    json.dump(cur, open(jp, "w"))
    out = ["extends RefCounted", "## GENERATED by tools/blender/r37_south.py (south marches): the numbers the game needs from the Blender kits.", "## Do not edit by hand; rerun the script.", ""]
    for k in sorted(cur):
        out.append("const %s := %s" % (k, L.gd_lit(cur[k])))
    L.write_gd(os.path.join(L.ROOT, "core", "world", "realm", "r37_south_data.gd"), "\n".join(out) + "\n")


def main():
    L.reset()
    if ONLY in ("all", "wall"):
        build_wall()
        L.reset() if ONLY == "all" else None
    if ONLY in ("all", "oak"):
        build_oak()
        L.reset() if ONLY == "all" else None
    if ONLY in ("all", "well"):
        build_well()
        L.reset() if ONLY == "all" else None
    if ONLY in ("all", "hut"):
        build_hut()
    write_data()


main()
