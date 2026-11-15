"""Reedholm (tools/blender/reach_towns.py): the fishers' town standing on piles in the Reedmere, where the Sorrow
forgets it was a river. Every piece's origin is the water's surface (or the marsh, for the ones on land) under its
middle; decks are DECK above it. Front is +z (Godot frame; reach_town_lib).

  RH_Hall        the net-hall: a deck on a grid of braced piles, a gallery rail, a long house of daub and plank under a
                 deep reed thatch with the crossed ridge-poles at both ends, a porch, a smoke-hole, steps down to the walk,
                 a ladder to the water behind
  RH_House       a fisher's house on its own deck, thatch and ridge-poles, a lean-to over the door
  RH_HouseLong   a long house whose west end is an open net-loft (posts, the thatch carried over, nets hung to dry)
  RH_Smokehouse  on the bank: a tall plank smokehouse on a stone footing, a reed hood with a louvred ridge, racks of eels
  RH_Walk        a 6 m boardwalk on paired piles (decked at WALK)
  RH_WalkStep    steps from WALK down to the bank (3 m)
  RH_Landing     the landing stage: a low wide deck, mooring posts, the board, the lamp-pole whose lamp the fishers keep
  RH_HeronPole   a tall pole with a carved heron on it, beak turned in to the town (the fishers' mark)
  RH_Rack        a fish rack: A-frames, a ridge pole, strings of split fish and eels
  RH_NetFrame    poles and a rail with a net hung across it
  RH_Punt        a flat-bottomed punt, its pole lying in it
  RH_Trap        a wicker eel-trap
  RH_ReedStack   bundles of cut reed stood in a stook
  RH_Bridge      the ford's footbridge over the Sorrow: plank spans on pile trestles, rope rails, steps at each end (16 m)
  RH_HallFar RH_HouseFar   the silhouettes
"""
import math
from mathutils import Vector
import reach_town_lib as RL
from reach_town_lib import T, TINT, grouped, lathe_at, far_piece
from r37_wall_lib import lerp, clamp

DECK = 1.6           ## a house deck's top over the water
WALK = 1.0           ## a boardwalk's top
LANDING = 0.6        ## the landing stage's top
PILE_FOOT = -2.6     ## piles go this far under the water line (into the mud)
BRIDGE_DECK = 1.3


def piles(b, xs, zs, top, r=0.17, brace=True, seed=0, skip=()):
    """A grid of round piles from the mud to just under a deck at `top`, with cross-bracing between rows."""
    for i, x in enumerate(xs):
        for j, z in enumerate(zs):
            if (i, j) in skip:
                continue
            lean = (RL.hash3(x, 0.0, z, seed) * 0.06, RL.hash3(z, 0.0, x, seed + 1) * 0.06)
            b.log((x + lean[0], PILE_FOOT, z + lean[1]), (x, top - 0.1, z), r * 1.1, r, "beam", sides=7, seed=seed + i * 7 + j, crook=0.03, bark=1.0)
    if brace:
        for j, z in enumerate(zs):
            for i in range(len(xs) - 1):
                if i % 2 == 0:
                    b.beam((xs[i], -0.3, z), (xs[i + 1], top - 0.5, z), 0.1, 0.12, "beam")
                else:
                    b.beam((xs[i], top - 0.5, z), (xs[i + 1], -0.3, z), 0.1, 0.12, "beam")


def deck(b, x0, x1, z0, z1, top, seed=0, joists=True):
    """A plank deck x0..x1 by z0..z1 (planks along z), its top at `top`; bearers under it along x; and its collision."""
    b.box(((x0 + x1) / 2, top - 0.07, (z0 + z1) / 2), (x1 - x0, 0.14, z1 - z0), "plank", cuts=2, jit=0.006, uv=1.0)
    # a few planks proud and loose (the eye reads a deck by its joints)
    for k in range(int((x1 - x0) / 1.7)):
        x = x0 + 0.6 + k * 1.7 + (RL.hash3(k, top, seed) * 0.4)
        b.box((x, top + 0.005, (z0 + z1) / 2 + RL.hash3(k, seed, 1) * (z1 - z0) * 0.3), (0.28, 0.03, (z1 - z0) * 0.5), "plank", cuts=0, jit=0.0)
    if joists:
        for z in (z0 + 0.2, (z0 + z1) / 2, z1 - 0.2):
            b.beam((x0 - 0.15, top - 0.25, z), (x1 + 0.15, top - 0.25, z), 0.22, 0.24, "beam")
    b.colbox(((x0 + x1) / 2, top - 0.2, (z0 + z1) / 2), (x1 - x0, 0.4, z1 - z0))


def rail(b, pts, top, h=1.0, post_every=1.9, seed=0):
    """A gallery rail: posts and a top rail along a polyline at deck height `top`."""
    for i in range(len(pts) - 1):
        a = Vector((pts[i][0], top, pts[i][1]))
        c = Vector((pts[i + 1][0], top, pts[i + 1][1]))
        n = max(1, int((c - a).length / post_every))
        for k in range(n + 1):
            p = a.lerp(c, k / n)
            b.log((p.x, top - 0.1, p.z), (p.x, top + h, p.z), 0.07, 0.06, "beam", sides=5, crook=0.0, seed=seed + k)
        b.log((a.x, top + h - 0.05, a.z), (c.x, top + h - 0.05, c.z), 0.05, 0.05, "beam", sides=5, crook=0.02, seed=seed + 50 + i)
        b.log((a.x, top + h * 0.5, a.z), (c.x, top + h * 0.5, c.z), 0.035, 0.035, "beam", sides=5, crook=0.03, seed=seed + 80 + i)


def house_body(b, w, d, y0, wall_h, seed=0, door_x=0.0, windows=((-1.0, True),), back_windows=((0.6, False),), door_ajar=0.0):
    """A fisher's house on a deck at y0: a sill beam, posts at the corners and between, the walls of daub (plaster)
    over wattle with the lower third in vertical boards, a door, windows with shutters."""
    hw, hd = w / 2, d / 2
    b.box((0.0, y0 + wall_h / 2, 0.0), (w, wall_h, d), "plaster", cuts=2, jit=0.02)
    # the boarded lower walls (splash boards)
    for sz in (-1, 1):
        b.box((0.0, y0 + 0.55, sz * (hd + 0.04)), (w + 0.05, 1.1, 0.08), "plank", cuts=1, jit=0.005)
    for sx in (-1, 1):
        b.box((sx * (hw + 0.04), y0 + 0.55, 0.0), (0.08, 1.1, d + 0.05), "plank", cuts=1, jit=0.005)
    # frame: corner posts, studs, a sill and a plate
    for sz in (-1, 1):
        b.frame_face(-hw, hw, sz * hd, y0, y0 + wall_h, face=sz, bays=max(2, int(w / 1.9)), rails=(0.42,), braces=True, w=0.2)
    for sx in (-1, 1):
        b.frame_side(-hd, hd, sx * hw, y0, y0 + wall_h, face=sx, bays=2, rails=(0.42,), w=0.2)
    b.door(door_x, hd + 0.08, w=1.4, h=2.5, face=1, step=0.0, frame="beam", ajar=door_ajar)
    for (x, lit) in windows:
        b.window(x, y0 + 1.75, hd + 0.08, w=0.9, h=0.9, face=1, lit=lit, frame="beam", sill="beam", mull=False)
    for (x, lit) in back_windows:
        b.window(x, y0 + 1.75, -hd - 0.08, w=0.8, h=0.8, face=-1, lit=lit, frame="beam", sill="beam", mull=False, shutters=False)


def hall():
    b = T("RH_Hall", seed=9301, damp=1.6)
    W_, D_ = 15.0, 11.0                    # the deck
    hw, hd = W_ / 2, D_ / 2
    xs = [lerp(-hw + 0.3, hw - 0.3, i / 6) for i in range(7)]
    zs = [lerp(-hd + 0.3, hd - 0.3, j / 4) for j in range(5)]
    piles(b, xs, zs, DECK, r=0.2, seed=1)
    deck(b, -hw, hw, -hd, hd, DECK, seed=2)
    # the hall on the deck, set back so a wide gallery runs along the front
    HW, HD, WH = 11.0, 7.0, 3.4
    def body():
        house_body(b, HW, HD, DECK, WH, seed=3, door_x=0.0, windows=((-3.4, True), (3.4, True)), back_windows=((-2.0, False), (2.6, True)), door_ajar=0.5)
    grouped(b, body, 0.0, (0.0, 0.0, -1.2))
    # the roof: a deep thatch, the ends swept, crossed ridge-poles both ends (the fishers' way); a smoke-hole
    def roof():
        b.thatch_gable(-HW / 2, HW / 2, HD / 2, DECK + WH, DECK + WH + 5.6, over=0.85, thick=0.6, sag=0.2, seed=4, end_over=0.75, horns=1.6)
    grouped(b, roof, 0.0, (0.0, 0.0, -1.2))
    # the porch over the door: two posts, a little thatch
    def porch():
        for sx in (-1, 1):
            b.log((sx * 1.2, DECK, 1.7), (sx * 1.2, DECK + 2.7, 1.7), 0.12, 0.1, "beam", seed=10 + sx, crook=0.04)
        b.beam((-1.5, DECK + 2.75, 1.7), (1.5, DECK + 2.75, 1.7), 0.18, 0.2, "beam")
        def pr():
            b.thatch_gable(-0.2, 2.1, 1.3, DECK + 2.8, DECK + 3.9, over=0.3, thick=0.35, sag=0.02, seed=11, end_over=0.2)
        grouped(b, pr, -math.pi / 2, (0.0, 0.0, 0.0))
    grouped(b, porch, 0.0, (0.0, 0.0, HD / 2 - 1.2))
    # the gallery rail round the deck (open where the steps come up at the front and the ladder at the back)
    rail(b, [(-hw + 0.15, hd - 0.15), (-1.6, hd - 0.15)], DECK, seed=20)
    rail(b, [(1.6, hd - 0.15), (hw - 0.15, hd - 0.15), (hw - 0.15, -hd + 0.15), (2.0, -hd + 0.15)], DECK, seed=30)
    rail(b, [(-0.4, -hd + 0.15), (-hw + 0.15, -hd + 0.15), (-hw + 0.15, hd - 0.15)], DECK, seed=40)
    # steps down to the walk at the front
    for k in range(3):
        y = DECK - (k + 1) * (DECK - WALK) / 3
        b.box((0.0, y - 0.07, hd + 0.3 + k * 0.38), (3.0, 0.14, 0.4), "plank", cuts=0, jit=0.004)
        b.colbox((0.0, y - 0.1, hd + 0.3 + k * 0.38), (3.0, 0.2, 0.4))
    for sx in (-1, 1):
        b.log((sx * 1.55, PILE_FOOT, hd + 1.2), (sx * 1.55, WALK - 0.05, hd + 1.2), 0.13, 0.12, "beam", seed=50 + sx, crook=0.02)
    # the ladder to the water behind, a mooring ring
    for sx in (-1, 1):
        b.log((0.75 + sx * 0.3, -0.9, -hd - 0.25), (0.75 + sx * 0.3, DECK + 0.9, -hd - 0.12), 0.05, 0.045, "beam", sides=5, crook=0.0)
    for k in range(6):
        b.beam((0.42, -0.6 + k * 0.38, -hd - 0.22), (1.08, -0.6 + k * 0.38, -hd - 0.22), 0.05, 0.05, "beam", jit=0.0)
    # baskets and a net heap on the gallery
    lathe_at(b, -5.8, 3.8, DECK, [(0.35, 0.0), (0.42, 0.45), (0.38, 0.55)], "wattle", sides=10, seed=5)
    lathe_at(b, -5.0, 4.3, DECK, [(0.3, 0.0), (0.36, 0.38), (0.33, 0.46)], "wattle", sides=10, seed=6)
    lathe_at(b, 5.6, 4.0, DECK, [(0.9, 0.0), (0.7, 0.25), (0.2, 0.4)], "net", sides=10, jit=0.15, seed=7)
    # collision: the house, its roof's mass
    b.colbox((0.0, DECK + WH / 2, -1.2), (HW + 0.3, WH, HD + 0.3))
    b.colbox((0.0, DECK + WH + 1.6, -1.2), (HW, 3.2, HD * 0.6))
    RL.DATA["hall"] = {"deck": DECK, "door_z": HD / 2 - 1.2 + 0.9, "front_z": hd, "half": [hw, hd]}
    return b.finish()


def house(name="RH_House", seed=9401, W_=8.4, D_=7.6, HW=6.2, HD=4.8, WH=3.1, rise=4.6):
    b = T(name, seed=seed, damp=1.6)
    hw, hd = W_ / 2, D_ / 2
    xs = [lerp(-hw + 0.3, hw - 0.3, i / 3) for i in range(4)]
    zs = [lerp(-hd + 0.3, hd - 0.3, j / 3) for j in range(4)]
    piles(b, xs, zs, DECK, r=0.18, seed=seed + 1)
    deck(b, -hw, hw, -hd, hd, DECK, seed=seed + 2)
    zc = -hd + HD / 2 + 0.4
    def body():
        house_body(b, HW, HD, DECK, WH, seed=seed + 3, door_x=-1.0, windows=((1.5, True),), back_windows=((0.0, False),))
        b.thatch_gable(-HW / 2, HW / 2, HD / 2, DECK + WH, DECK + WH + rise, over=0.75, thick=0.55, sag=0.12, seed=seed + 4, end_over=0.6, horns=1.3)
    grouped(b, body, 0.0, (0.0, 0.0, zc))
    # a lean-to over the door: two posts, a pent of reed on poles
    zf = zc + HD / 2
    for x in (-2.4, 0.4):
        b.log((x, DECK, zf + 1.6), (x, DECK + 2.3, zf + 1.6), 0.09, 0.08, "beam", sides=6, seed=seed + int(x * 10), crook=0.03)
    b.log((-2.7, DECK + 2.32, zf + 1.6), (0.7, DECK + 2.32, zf + 1.6), 0.07, 0.07, "beam", sides=6, crook=0.02)
    n0 = len(b.bm.verts)
    b.box((0.0, 0.0, 0.0), (3.6, 0.26, 2.1), "thatch", cuts=1, jit=0.04)
    b.bm.verts.ensure_lookup_table()
    from mathutils import Matrix
    Rm = Matrix.Rotation(math.atan2(0.5, 1.8), 3, 'X')
    for v in list(b.bm.verts)[n0:]:
        v.co = Rm @ Vector(v.co) + Vector((-1.0, DECK + 2.6, zf + 0.85))
    rail(b, [(hw - 0.15, hd - 0.15), (hw - 0.15, -hd + 0.15)], DECK, seed=seed + 20)
    rail(b, [(-hw + 0.15, -hd + 0.15), (-hw + 0.15, hd - 0.15)], DECK, seed=seed + 30)
    for k in range(3):
        y = DECK - (k + 1) * (DECK - WALK) / 3
        b.box((-1.0, y - 0.07, hd + 0.3 + k * 0.38), (2.2, 0.14, 0.4), "plank", cuts=0, jit=0.004)
        b.colbox((-1.0, y - 0.1, hd + 0.3 + k * 0.38), (2.2, 0.2, 0.4))
    lathe_at(b, 2.6, hd - 0.8, DECK, [(0.3, 0.0), (0.36, 0.4), (0.33, 0.48)], "wattle", sides=10, seed=seed + 5)
    b.colbox((0.0, DECK + WH / 2, zc), (HW + 0.3, WH, HD + 0.3))
    b.colbox((0.0, DECK + WH + 1.4, zc), (HW, 2.8, HD * 0.6))
    RL.DATA[name.lower()] = {"deck": DECK, "door": [-1.0, zf + 0.6], "front_z": hd}
    return b.finish()


def house_long():
    b = T("RH_HouseLong", seed=9501, damp=1.6)
    W_, D_ = 13.0, 6.8
    hw, hd = W_ / 2, D_ / 2
    xs = [lerp(-hw + 0.3, hw - 0.3, i / 5) for i in range(6)]
    zs = [lerp(-hd + 0.3, hd - 0.3, j / 2) for j in range(3)]
    piles(b, xs, zs, DECK, r=0.18, seed=9502)
    deck(b, -hw, hw, -hd, hd, DECK, seed=9503)
    HD, WH = 5.0, 3.2
    def body():
        house_body(b, 6.6, HD, DECK, WH, seed=9504, door_x=1.2, windows=((-1.6, False),), back_windows=((0.0, True),))
    grouped(b, body, 0.0, (2.4, 0.0, -0.4))
    # the net-loft: the west end open, posts and a plate under the same thatch
    for x in (-5.8, -3.1):
        for z in (-0.4 - HD / 2 + 0.15, -0.4 + HD / 2 - 0.15):
            b.log((x, DECK, z), (x, DECK + WH, z), 0.13, 0.11, "beam", sides=7, seed=int(x * 10 + z), crook=0.03)
    for z in (-0.4 - HD / 2 + 0.15, -0.4 + HD / 2 - 0.15):
        b.beam((-6.0, DECK + WH - 0.1, z), (-0.9, DECK + WH - 0.1, z), 0.2, 0.22, "beam")
    for x in (-5.8, -3.1):
        b.beam((x, DECK + WH - 0.1, -0.4 - HD / 2), (x, DECK + WH - 0.1, -0.4 + HD / 2), 0.18, 0.2, "beam")
    # nets hung from the loft's beams: dark sheets in folds
    for k, x in enumerate((-5.2, -4.4, -3.7)):
        for f in range(3):
            z = -0.4 - 1.2 + f * 1.2
            b.box((x + 0.05 * f, DECK + WH - 1.1, z), (0.04, 1.9 - 0.2 * ((k + f) % 3), 1.1), "net", yaw=0.25 * ((k + f) % 3 - 1), cuts=1, jit=0.03)
    b.thatch_gable(-6.2, 5.7, HD / 2, DECK + WH, DECK + WH + 4.6, over=0.8, thick=0.55, sag=0.22, seed=9505, end_over=0.7, horns=1.3, cz=-0.4)
    rail(b, [(-hw + 0.15, hd - 0.15), (-2.0, hd - 0.15)], DECK, seed=9520)
    rail(b, [(hw - 0.15, hd - 0.15), (hw - 0.15, -hd + 0.15)], DECK, seed=9530)
    for k in range(3):
        y = DECK - (k + 1) * (DECK - WALK) / 3
        b.box((0.4, y - 0.07, hd + 0.3 + k * 0.38), (2.2, 0.14, 0.4), "plank", cuts=0, jit=0.004)
        b.colbox((0.4, y - 0.1, hd + 0.3 + k * 0.38), (2.2, 0.2, 0.4))
    b.colbox((2.4, DECK + WH / 2, -0.4), (6.9, WH, HD + 0.3))
    b.colbox((-0.3, DECK + WH + 1.4, -0.4), (12.0, 2.8, HD * 0.6))
    for x in (-5.8, -3.1):
        for z in (-0.4 - HD / 2 + 0.15, -0.4 + HD / 2 - 0.15):
            b.colbox((x, DECK + WH / 2, z), (0.3, WH, 0.3))
    RL.DATA["rh_houselong"] = {"deck": DECK, "door": [3.6, -0.4 + HD / 2 + 0.6], "front_z": hd, "loft": [-4.4, -0.4]}
    return b.finish()


def smokehouse():
    b = T("RH_Smokehouse", seed=9601, damp=1.4)
    w, d, H = 4.2, 4.2, 4.6
    b.rect_solid(-w / 2 - 0.3, w / 2 + 0.3, -d / 2 - 0.3, d / 2 + 0.3, -1.2, 0.5, bat=(0.12,) * 4, mat="rubble", tint=TINT["damp"], jit=0.04, seed=1)
    b.box((0.0, 0.5 + H / 2, 0.0), (w, H, d), "plank", cuts=2, jit=0.01, uv=1.0)
    # battens over the board joints, corner posts black with smoke
    for sz in (-1, 1):
        for k in range(8):
            x = -w / 2 + 0.25 + k * (w - 0.5) / 7
            b.box((x, 0.5 + H / 2, sz * (d / 2 + 0.03)), (0.08, H, 0.05), "beam", cuts=0, jit=0.004)
    for sx in (-1, 1):
        for sz in (-1, 1):
            b.box((sx * (w / 2 + 0.02), 0.5 + H / 2, sz * (d / 2 + 0.02)), (0.22, H + 0.1, 0.22), "beam", cuts=0, jit=0.01)
    b.door(0.0, d / 2 + 0.05, w=1.2, h=2.3, face=1, step=0.5, frame="beam", ajar=0.6)
    # the glow of the smoking fire through the door (the game keeps it low: window_glass)
    b.box((0.0, 0.9, d / 2 - 0.3), (0.9, 0.5, 0.1), "window_glass", cuts=0, jit=0.0)
    # the hood: steep reed, a louvred gap at the ridge with its own little roof over it
    b.thatch_gable(-w / 2, w / 2, d / 2, 0.5 + H, 0.5 + H + 3.4, over=0.55, thick=0.45, sag=0.05, seed=2, end_over=0.45)
    for k in range(4):
        x = -w * 0.3 + k * w * 0.2
        b.box((x, 0.5 + H + 3.6, 0.0), (0.12, 0.45, 0.7), "beam", cuts=0, jit=0.0)
    b.box((0.0, 0.5 + H + 3.38, 0.0), (w * 0.72, 0.1, 0.7), "dark", cuts=0, jit=0.0)
    b.gable(-w * 0.38, w * 0.38, 0.4, 0.5 + H + 3.8, 0.5 + H + 4.3, mat="thatch", over=0.25, thick=0.18, sag=0.0, seed=3, ridge=False, barge=False)
    # eel racks against the side: poles with strings of eels
    for z in (-1.4, 0.0, 1.4):
        b.log((w / 2 + 0.6, 0.0, z), (w / 2 + 0.6, 2.3, z), 0.06, 0.05, "beam", sides=5, crook=0.02, seed=int(z * 10))
    b.log((w / 2 + 0.6, 2.25, -1.6), (w / 2 + 0.6, 2.25, 1.6), 0.05, 0.05, "beam", sides=5, crook=0.02)
    for k in range(9):
        z = -1.4 + k * 0.35
        ln = 0.9 + 0.3 * ((k * 3) % 4) / 4.0
        b.tube((w / 2 + 0.6, 2.2, z), (w / 2 + 0.62, 2.2 - ln, z + 0.04), 0.035, 0.015, "fish", sides=5, bark=0.5)
    b.colbox((0.0, (H + 0.5) / 2, 0.0), (w + 0.3, H + 0.5, d + 0.3))
    b.colbox((0.0, H + 2.0, 0.0), (w, 3.0, d * 0.6))
    return b.finish()


def walk():
    b = T("RH_Walk", seed=9701, damp=1.6)
    L_, Wd = 6.0, 2.0
    for x in (-2.0, 0.0, 2.0):
        for z in (-0.75, 0.75):
            b.log((x, PILE_FOOT, z), (x, WALK - 0.12, z), 0.12, 0.11, "beam", sides=6, seed=int(x * 10 + z * 3), crook=0.03, bark=1.0)
        b.beam((x, WALK - 0.2, -0.95), (x, WALK - 0.2, 0.95), 0.16, 0.18, "beam")
    for z in (-0.6, 0.6):
        b.beam((-L_ / 2, WALK - 0.32, z), (L_ / 2, WALK - 0.32, z), 0.16, 0.18, "beam")
    # planks across, each a little different
    n = int(L_ / 0.3)
    for k in range(n):
        x = -L_ / 2 + 0.15 + k * 0.3
        ww = Wd - 0.1 + RL.hash3(k, 1.0, 2.0) * 0.2
        b.box((x, WALK - 0.06 + RL.hash3(k, 3.0, 1.0) * 0.015, RL.hash3(k, 5.0, 1.0) * 0.05), (0.27, 0.09, ww), "plank", yaw=RL.hash3(k, 7.0, 1.0) * 0.04, cuts=0, jit=0.0)
    b.colbox((0.0, WALK - 0.2, 0.0), (L_, 0.4, Wd))
    return b.finish()


def walk_step():
    b = T("RH_WalkStep", seed=9711, damp=1.6)
    # from WALK at x = 0 down to the bank at x = 3 (y 0): four treads on a stringer each side, set in the mud
    for z in (-0.75, 0.75):
        b.beam((-0.1, WALK - 0.15, z), (3.1, -0.25, z), 0.12, 0.26, "beam")
    for k in range(5):
        x = 0.25 + k * 0.62
        y = WALK - (k + 1) * WALK / 5.0
        b.box((x, y - 0.03, 0.0), (0.5, 0.1, 1.8), "plank", cuts=0, jit=0.006)
        b.colbox((x, (y - 1.0) / 2, 0.0), (0.62, y + 1.0, 1.8))
    b.log((0.0, PILE_FOOT, -0.75), (0.0, WALK - 0.12, -0.75), 0.12, 0.11, "beam", sides=6, seed=3, crook=0.02, bark=1.0)
    b.log((0.0, PILE_FOOT, 0.75), (0.0, WALK - 0.12, 0.75), 0.12, 0.11, "beam", sides=6, seed=4, crook=0.02, bark=1.0)
    return b.finish()


def landing():
    b = T("RH_Landing", seed=9801, damp=1.8)
    W_, D_ = 10.0, 6.4
    hw, hd = W_ / 2, D_ / 2
    xs = [lerp(-hw + 0.3, hw - 0.3, i / 4) for i in range(5)]
    zs = [lerp(-hd + 0.3, hd - 0.3, j / 2) for j in range(3)]
    piles(b, xs, zs, LANDING, r=0.2, brace=False, seed=1)
    deck(b, -hw, hw, -hd, hd, LANDING, seed=2)
    # mooring posts standing up through the deck's water side, rope coiled on one
    for x in (-hw + 0.3, -1.5, 2.0, hw - 0.3):
        b.log((x, PILE_FOOT, -hd - 0.15), (x + 0.05, LANDING + 1.1, -hd - 0.15), 0.17, 0.14, "beam", sides=7, seed=int(x * 9), crook=0.03, bark=1.0)
    lathe_at(b, 2.0, -hd - 0.15, LANDING + 0.55, [(0.22, 0.0), (0.24, 0.1), (0.22, 0.2)], "rope", sides=10)
    # the lamp-pole: tall and crooked, an iron crook curling out from its head (the game hangs the kept lamp on it),
    # a fish-weather vane of tin on top
    LX, LZ = hw - 1.0, hd - 0.7
    b.log((LX, LANDING - 0.2, LZ), (LX + 0.08, LANDING + 5.2, LZ), 0.15, 0.11, "beam", sides=8, crook=0.02, seed=7)
    for yy in (LANDING + 1.0, LANDING + 2.6):
        lathe_at(b, LX + (yy - LANDING) * 0.015, LZ, yy, [(0.18, 0.0), (0.19, 0.07), (0.18, 0.14)], "rope", sides=9)
    crook = [(LX + 0.06, LANDING + 4.6, LZ), (LX - 0.4, LANDING + 5.2, LZ), (LX - 1.0, LANDING + 5.25, LZ), (LX - 1.35, LANDING + 4.95, LZ), (LX - 1.35, LANDING + 4.7, LZ)]
    b.tube_path(crook, [0.045, 0.04, 0.035, 0.03, 0.03], "iron", sides=6, bark=1.0)
    b.tube((LX + 0.08, LANDING + 5.15, LZ), (LX + 0.08, LANDING + 5.9, LZ), 0.025, 0.02, "iron", sides=4, bark=1.0)
    b.box((LX + 0.32, LANDING + 5.75, LZ), (0.5, 0.14, 0.02), "iron", cuts=0, jit=0.0)
    b.box((LX + 0.62, LANDING + 5.75, LZ), (0.14, 0.2, 0.02), "iron", roll=0.785, cuts=0, jit=0.0)
    RL.DATA["landing"] = {"top": LANDING, "lamp": [LX - 1.35, LANDING + 4.5, LZ], "half": [hw, hd]}
    # the landing-board on two posts at the shore end
    BX, BZ = -hw + 1.6, hd - 0.4
    for sx in (-1, 1):
        b.beam((BX + sx * 0.75, LANDING - 0.1, BZ), (BX + sx * 0.75, LANDING + 2.2, BZ), 0.14, 0.14, "beam")
    b.box((BX, LANDING + 1.55, BZ + 0.08), (1.7, 1.0, 0.08), "plank", cuts=0, jit=0.0)
    b.box((BX, LANDING + 2.15, BZ + 0.1), (1.9, 0.14, 0.3), "beam", cuts=0, jit=0.0)
    for k in range(4):
        b.box((BX - 0.55 + k * 0.32, LANDING + 1.6 + (k % 2) * 0.15, BZ + 0.13), (0.22, 0.03, 0.01), "dark", cuts=0, jit=0.0)
    RL.DATA["landing"]["board"] = [BX, LANDING + 1.5, BZ + 0.2]
    # creels and an upturned punt on the stage
    lathe_at(b, -1.2, 1.4, LANDING, [(0.32, 0.0), (0.4, 0.42), (0.36, 0.5)], "wattle", sides=10, seed=8)
    lathe_at(b, -0.6, 1.8, LANDING, [(0.28, 0.0), (0.34, 0.36), (0.31, 0.43)], "wattle", sides=10, seed=9)
    b.colbox((BX, LANDING + 1.1, BZ), (1.9, 2.2, 0.3))
    b.colbox((LX, LANDING + 2.5, LZ), (0.4, 5.0, 0.4))
    return b.finish()


def heron_pole():
    b = T("RH_HeronPole", seed=9901, damp=1.0)
    b.log((0.0, -0.8, 0.0), (0.06, 5.6, 0.0), 0.2, 0.15, "beam", sides=9, crook=0.02, seed=1)
    for yy in (1.2, 2.6, 4.0):
        lathe_at(b, 0.0 + yy * 0.01, 0.0, yy, [(0.22, 0.0), (0.24, 0.08), (0.22, 0.16)], "rope", sides=9)
    # the heron: a long body, an S neck, the beak turned in, two legs onto the pole's top
    y0 = 5.6
    b.tube_path([(0.0, y0 + 0.9, -0.55), (0.0, y0 + 1.05, -0.1), (0.0, y0 + 1.0, 0.35)], [0.05, 0.24, 0.12], "beam", sides=8, bark=0.8, seed=2)
    b.tube_path([(0.0, y0 + 1.05, 0.35), (0.0, y0 + 1.5, 0.45), (0.0, y0 + 1.8, 0.3), (0.0, y0 + 2.0, 0.45)], [0.1, 0.07, 0.07, 0.08], "beam", sides=7, bark=0.8, seed=3)
    b.tube((0.0, y0 + 2.02, 0.5), (0.0, y0 + 1.92, 1.05), 0.05, 0.005, "beam", sides=5, bark=0.5)
    for sx in (-1, 1):
        b.tube((sx * 0.1, y0 + 0.85, 0.0), (sx * 0.05, y0, 0.03), 0.03, 0.025, "beam", sides=4, bark=0.5)
        b.tube_path([(sx * 0.18, y0 + 1.1, 0.25), (sx * 0.32, y0 + 1.0, -0.2), (sx * 0.2, y0 + 0.85, -0.7)], [0.09, 0.1, 0.02], "beam", sides=5, bark=0.6, seed=4 + sx)
    b.colbox((0.0, 2.5, 0.0), (0.4, 5.0, 0.4))
    return b.finish()


def rack():
    b = T("RH_Rack", seed=9911, damp=0.8)
    L_ = 4.0
    for x in (-L_ / 2, L_ / 2):
        for sz in (-1, 1):
            b.log((x, -0.3, sz * 0.9), (x, 2.4, sz * 0.05), 0.07, 0.06, "beam", sides=5, crook=0.03, seed=int(x * 5 + sz))
    b.log((-L_ / 2 - 0.3, 2.35, 0.0), (L_ / 2 + 0.3, 2.35, 0.0), 0.06, 0.06, "beam", sides=5, crook=0.02, seed=9)
    for sz in (-1, 1):
        b.log((-L_ / 2, 1.5, sz * 0.38), (L_ / 2, 1.5, sz * 0.38), 0.045, 0.045, "beam", sides=5, crook=0.02, seed=10 + sz)
    for k in range(22):
        x = -L_ / 2 + 0.2 + (k % 11) * (L_ - 0.4) / 10
        z = 0.38 if k < 11 else -0.38
        yt = 1.48
        ln = 0.55 + 0.25 * ((k * 7) % 5) / 5.0
        b.box((x, yt - ln / 2, z), (0.12, ln, 0.02), "fish", cuts=1, jit=0.01, yaw=0.2 * ((k % 3) - 1))
    for k in range(9):
        x = -L_ / 2 + 0.3 + k * (L_ - 0.6) / 8
        ln = 1.1 + 0.4 * ((k * 3) % 4) / 4.0
        b.tube((x, 2.32, 0.0), (x + 0.03, 2.32 - ln, 0.02), 0.04, 0.012, "fish", sides=5, bark=0.5)
    b.colbox((0.0, 1.2, 0.0), (L_ + 0.4, 2.4, 1.8))
    return b.finish()


def net_frame():
    b = T("RH_NetFrame", seed=9921, damp=0.8)
    for x in (-1.9, 1.9):
        b.log((x, -0.4, 0.0), (x, 2.5, 0.0), 0.07, 0.06, "beam", sides=5, crook=0.03, seed=int(x * 7))
    b.log((-2.1, 2.4, 0.0), (2.1, 2.4, 0.0), 0.05, 0.05, "beam", sides=5, crook=0.02, seed=3)
    # the net: a sagging mesh of cords (a coarse grid of thin strands), floats along its top
    for i in range(15):
        x = -1.75 + i * 0.25
        sag = 0.15 * math.sin((i / 14) * math.pi)
        b.tube((x, 2.38, 0.0), (x + 0.02, 0.5 + sag * 0.5, 0.02), 0.009, 0.009, "net", sides=3, bark=1.0, cap=False)
    for j in range(9):
        y = 0.6 + j * 0.2
        pts = [(-1.75 + i * 0.5, y - 0.12 * math.sin((i / 7) * math.pi) * (1.0 - j / 9), 0.01) for i in range(8)]
        for k in range(7):
            b.tube(pts[k], pts[k + 1], 0.008, 0.008, "net", sides=3, bark=1.0, cap=False)
    for i in range(7):
        b.frustum(-1.5 + i * 0.5, 0.0, 0.07, 0.07, 2.25, 2.35, "plank", round_n=6, levels=2, jit=0.0)
    b.colbox((0.0, 1.2, 0.0), (4.0, 2.4, 0.3))
    return b.finish()


def punt():
    b = T("RH_Punt", seed=9931, damp=1.4)
    L_, Wd = 5.4, 1.25
    # the bottom and the sides (planks), raked ends
    b.box((0.0, 0.05, 0.0), (L_ - 1.0, 0.08, Wd - 0.1), "plank", cuts=1, jit=0.004)
    for sz in (-1, 1):
        b.prism_x([(sz * (Wd / 2 - 0.04), 0.0), (sz * (Wd / 2), 0.42), (sz * (Wd / 2 - 0.06), 0.42), (sz * (Wd / 2 - 0.1), 0.02)], -L_ / 2 + 0.5, L_ / 2 - 0.5, "plank", jit=0.0, dens=99.0, xstep=1.5)
    for sx in (-1, 1):
        x0 = sx * (L_ / 2 - 0.5)
        b.beam((x0, 0.05, 0.0), (sx * (L_ / 2), 0.4, 0.0), Wd, 0.06, "plank", jit=0.0)
        for sz in (-1, 1):
            b.beam((x0, 0.06, sz * (Wd / 2 - 0.03)), (sx * (L_ / 2), 0.42, sz * (Wd / 2 - 0.05)), 0.06, 0.4, "plank", jit=0.0)
    for x in (-1.2, 0.3, 1.5):
        b.box((x, 0.36, 0.0), (0.26, 0.06, Wd - 0.15), "beam", cuts=0, jit=0.0)
    b.log((-2.6, 0.45, 0.25), (3.6, 0.55, -0.1), 0.035, 0.03, "beam", sides=5, crook=0.0)
    lathe_at(b, 0.9, -0.15, 0.1, [(0.22, 0.0), (0.27, 0.32), (0.24, 0.38)], "wattle", sides=9, seed=4)
    return b.finish()


def trap():
    b = T("RH_Trap", seed=9941, damp=1.4)
    n0 = len(b.bm.verts)
    lathe_at(b, 0.0, 0.0, 0.0, [(0.02, 0.0), (0.22, 0.25), (0.32, 0.7), (0.3, 1.2), (0.26, 1.35)], "wattle", sides=10, seed=1)
    b.bm.verts.ensure_lookup_table()
    from mathutils import Matrix
    Rm = Matrix.Rotation(math.pi / 2, 3, 'Z')
    for v in list(b.bm.verts)[n0:]:
        v.co = Rm @ Vector(v.co) + Vector((0.7, 0.3, 0.0))
    return b.finish()


def reed_stack():
    b = T("RH_ReedStack", seed=9951, damp=1.0)
    for i in range(9):
        a = math.tau * i / 9
        r = 0.55
        bx, bz = math.cos(a) * r, math.sin(a) * r
        b.tube((bx, -0.1, bz), (bx * 0.18, 2.4 + 0.2 * (i % 3), bz * 0.18), 0.2, 0.1, "thatch", sides=7, bark=1.2, jit=0.03, seed=i)
        b.tube((bx * 0.18, 2.4 + 0.2 * (i % 3), bz * 0.18), (bx * -0.1, 2.9 + 0.25 * (i % 3), bz * -0.1), 0.1, 0.02, "thatch", sides=6, bark=1.0, seed=i + 20)
    lathe_at(b, 0.0, 0.0, 0.9, [(0.48, 0.0), (0.48, 0.1)], "rope", sides=12)
    lathe_at(b, 0.0, 0.0, 1.7, [(0.32, 0.0), (0.32, 0.1)], "rope", sides=12)
    b.colbox((0.0, 1.0, 0.0), (1.4, 2.0, 1.4))
    return b.finish()


def bridge():
    b = T("RH_Bridge", seed=9961, damp=1.8)
    L_ = 16.0
    hl = L_ / 2
    Y = BRIDGE_DECK
    # trestles every 4 m: pairs of piles, a cap beam, diagonal braces
    for x in (-hl + 2.0, -2.0, 2.0, hl - 2.0):
        for z in (-1.0, 1.0):
            b.log((x, PILE_FOOT, z), (x, Y - 0.15, z * 0.92), 0.16, 0.14, "beam", sides=7, seed=int(x * 3 + z), crook=0.03, bark=1.0)
        b.beam((x, Y - 0.3, -1.25), (x, Y - 0.3, 1.25), 0.24, 0.26, "beam")
        b.beam((x, -0.5, -1.0), (x, Y - 0.45, 0.92), 0.1, 0.12, "beam")
    for z in (-0.65, 0.65):
        b.beam((-hl + 0.6, Y - 0.43, z), (hl - 0.6, Y - 0.43, z), 0.2, 0.22, "beam")
    n = int((L_ - 1.2) / 0.32)
    for k in range(n):
        x = -hl + 0.75 + k * 0.32
        b.box((x, Y - 0.07 + RL.hash3(k, 1.0, 9.0) * 0.015, 0.0), (0.29, 0.1, 1.95 + RL.hash3(k, 2.0, 9.0) * 0.15), "plank", yaw=RL.hash3(k, 4.0, 9.0) * 0.03, cuts=0, jit=0.0)
    # rope rails on posts both sides, sagging between
    for z in (-1.05, 1.05):
        posts = [-hl + 0.7, -hl + 4.5, 0.0, hl - 4.5, hl - 0.7]
        for x in posts:
            b.log((x, Y - 0.4, z), (x, Y + 1.15, z), 0.07, 0.06, "beam", sides=5, crook=0.0, seed=int(x * 7 + z))
        for i in range(len(posts) - 1):
            pa = Vector((posts[i], Y + 1.05, z))
            pb = Vector((posts[i + 1], Y + 1.05, z))
            mid = (pa + pb) * 0.5 - Vector((0.0, 0.18, 0.0))
            b.tube_path([pa, mid, pb], [0.025, 0.025, 0.025], "rope", sides=5, bark=1.0, cap_end=False)
    # the steps at each end down to the banks
    for sx in (-1, 1):
        for k in range(4):
            y = Y - (k + 1) * Y / 4.5
            x = sx * (hl - 0.35 + (k + 0.5) * 0.45)
            b.box((x, y - 0.05, 0.0), (0.42, 0.12, 2.0), "plank", cuts=0, jit=0.005)
            b.colbox((x, (y - 1.2) / 2, 0.0), (0.46, y + 1.2, 2.0))
        b.beam((sx * (hl - 0.3), Y - 0.2, -0.95), (sx * (hl + 1.6), -0.4, -0.95), 0.1, 0.22, "beam")
        b.beam((sx * (hl - 0.3), Y - 0.2, 0.95), (sx * (hl + 1.6), -0.4, 0.95), 0.1, 0.22, "beam")
    b.colbox((0.0, Y - 0.2, 0.0), (L_ - 0.6, 0.4, 2.0))
    for z in (-1.1, 1.1):
        b.colbox((0.0, Y + 0.6, z), (L_ - 1.2, 1.2, 0.12))
    RL.DATA["bridge"] = {"deck": Y, "len": L_}
    return b.finish()


def fars():
    return [far_piece("RH_HallFar", [("box", (0, DECK / 2 - 0.5, 0), (15.0, DECK + 1.0, 11.0)), ("box", (0, DECK + 1.7, -1.2), (11.0, 3.4, 7.0)),
                                     ("roof", -6.3, 6.3, 4.4, DECK + 3.0, DECK + 9.0, -1.2)]),
            far_piece("RH_HouseFar", [("box", (0, DECK / 2 - 0.5, 0), (8.4, DECK + 1.0, 7.6)), ("box", (0, DECK + 1.55, -0.6), (6.2, 3.1, 4.8)),
                                      ("roof", -3.7, 3.7, 3.2, DECK + 2.7, DECK + 7.7, -0.6)])]


def build():
    objs = [hall(), house(), house("RH_HouseB", seed=9451, W_=7.6, D_=7.0, HW=5.4, HD=4.4, WH=3.0, rise=4.3), house_long(), smokehouse(), walk(), walk_step(),
            landing(), heron_pole(), rack(), net_frame(), punt(), trap(), reed_stack(), bridge()]
    return objs, fars()


VIEWS = {
    "RH_Hall": ((0.0, 4.0, 0.0), 34.0), "RH_House": ((0.0, 3.5, 0.0), 22.0), "RH_HouseB": ((0.0, 3.5, 0.0), 20.0),
    "RH_HouseLong": ((0.0, 3.5, 0.0), 26.0), "RH_Smokehouse": ((0.0, 3.5, 0.0), 16.0), "RH_Walk": ((0.0, 0.5, 0.0), 9.0),
    "RH_WalkStep": ((1.5, 0.5, 0.0), 7.0), "RH_Landing": ((0.0, 2.0, 0.0), 18.0), "RH_HeronPole": ((0.0, 4.0, 0.0), 12.0),
    "RH_Rack": ((0.0, 1.3, 0.0), 8.0), "RH_NetFrame": ((0.0, 1.3, 0.0), 7.0), "RH_Punt": ((0.0, 0.3, 0.0), 7.0),
    "RH_Trap": ((0.0, 0.3, 0.0), 3.0), "RH_ReedStack": ((0.0, 1.4, 0.0), 6.0), "RH_Bridge": ((0.0, 1.0, 0.0), 20.0),
}
