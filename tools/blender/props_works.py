"""Working buildings and machines for the places the Realm's kits used to build out of boxes. Modelled by script.

-> art/models/props/works_*.glb; parts named `<Part>__<set>` at the origin in the builder's own frame (Godot x = Blender
x, Godot y = Blender z, Godot z = -Blender y), merged per set by core/world/realm/prop_models.gd. No collision in the
file: the builder keeps the boxes it always had, so what was walkable or blocking stays so.

  works_winch    the Quarry's winch hut (Slate Rise): Hut (coursed walls on a battered footing, quoins, a framed door with
                 a timber lintel, slit windows, beam ends under a roof of big flags, the tether post, the gangway, the
                 winding drum on its trestles, the wheel's bearing frame) and Wheel (the tread-wheel: two felloe rims,
                 sixteen treads, spokes, a banded hub; its axle is local x, the builder spins it)

  tools/blender/run.sh props_works.py -- [--only works_winch] [--preview DIR] [--export]
"""
import math
import os
import sys
from mathutils import Vector, Matrix

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import props_stones as PS  # noqa: E402
import mp_lib as L  # noqa: E402
from mp_lib import Mk, block, bar, trs, move, crate  # noqa: E402

PROPS = PS.PROPS
BIG = {"ashlar": 12.0, "timber": 3.0, "hewn": 3.6}     # a building's texel density under the props' material (x3)


def gbox(mk, c, s, st=None, cheap=False, **kw):
    """A block given the way the builders give boxes: centre c and size s in Godot axes. Returns (verts, faces)."""
    if cheap:
        vs, faces = crate(mk, (s[0], s[2], s[1]), st=st, j=kw.get("j", 0.0)), None
    else:
        vs, faces = block(mk, (s[0], s[2], s[1]), st=st, **kw)
    move(mk, vs, trs((c[0], -c[2], c[1] - s[1] * 0.5)))
    return vs, faces


def G(x, y, z):
    return Vector((x, -z, y))


# --- the Quarry's winch hut -------------------------------------------------------------------------------
HX, HZ, T, WH = 3.0, 2.3, 0.5, 3.4
WC = (HX + 0.9, 2.3, -0.2)            # the wheel's centre (the builder's `wc`)


def winch_hut():
    mk = Mk(3440, "ashlar")
    r = mk.r
    # the footing: a battered course going down into the pit's spoil
    gbox(mk, (0, -0.5, 0), (HX * 2 + 0.36, 1.4, HZ * 2 + 0.36), ch=0.06, j=0.012, ease=0.05, taper=0.035, chip=0.02)
    # walls (the side walls stand between the long ones)
    _, back = gbox(mk, (0, WH * 0.5, -HZ + T * 0.5), (HX * 2, WH, T), ch=0.02, j=0.006, ease=0.02)
    _, west = gbox(mk, (-HX + T * 0.5, WH * 0.5, 0), (T, WH, HZ * 2 - T * 2), ch=0.02, j=0.006, ease=0.02)
    gbox(mk, (HX - T * 0.5, WH * 0.5, 0), (T, WH, HZ * 2 - T * 2), ch=0.02, j=0.006, ease=0.02)
    for sx in (-1, 1):
        gbox(mk, (sx * 1.85, WH * 0.5, HZ - T * 0.5), (2.3, WH, T), ch=0.02, j=0.006, ease=0.02)
    gbox(mk, (0, WH - 0.5, HZ - T * 0.5), (1.4, 1.0, T - 0.02), ch=0.02, j=0.004, ease=0.02)
    # slit windows: one in the back wall, one in the west
    mk.cut(back[(1, 2)], [PS.rect(0.09, 0.42, 1.3, 0.35)], 0.3, floor_tag=L.TAG_DARK)
    mk.cut(west[(1, 4)], [PS.rect(0.09, 0.42, 0.2, 0.35)], 0.3, floor_tag=L.TAG_DARK)
    # quoins: long and short stones turn about at each corner, a finger proud of the wall
    for sx in (-1, 1):
        for sz in (-1, 1):
            y = 0.02
            i = 0
            while y < WH - 0.2:
                h = min(r.uniform(0.44, 0.6), WH - y)
                lx, lz = (0.74, 0.5) if i % 2 == 0 else (0.5, 0.74)
                gbox(mk, (sx * (HX + 0.035 - lx * 0.5), y + h * 0.5, sz * (HZ + 0.035 - lz * 0.5)), (lx, h - 0.014, lz), st="hewn", cheap=True, j=0.006)
                y += h
                i += 1
    # the door: stone jambs, a threshold, a heavy timber lintel over
    for sx in (-1, 1):
        gbox(mk, (sx * 0.82, 1.2, HZ - T * 0.5), (0.26, 2.4, T + 0.07), st="hewn", ch=0.03, j=0.005, ease=0.02)
    gbox(mk, (0, 0.045, HZ - T * 0.5 + 0.06), (1.42, 0.17, T + 0.3), st="hewn", ch=0.03, j=0.004, ease=0.02)
    gbox(mk, (0, 2.56, HZ - T * 0.5), (2.3, 0.32, T + 0.1), st="timber", ch=0.03, j=0.006, ease=0.015)
    for sx in (-1, 1):                                   # the pintles the door hung on
        bar(mk, G(sx * 0.69, 0.7, HZ - 0.08), G(sx * 0.6, 0.7, HZ - 0.08), 0.035)
        bar(mk, G(sx * 0.69, 1.9, HZ - 0.08), G(sx * 0.6, 1.9, HZ - 0.08), 0.035)
    # the floor: big flags
    for ix in range(3):
        for iz in range(2):
            gbox(mk, (-1.67 + ix * 1.67, 0.03, -0.9 + iz * 1.8), (1.65, 0.2, 1.78), st="hewn", cheap=True, j=0.005)
    # the roof: beams on the wall heads, their ends out under the eaves; a boarded deck; eight great flags (top y 3.7)
    for x in (-2.5, -1.5, -0.5, 0.5, 1.5, 2.5):
        gbox(mk, (x, WH + 0.06, 0), (0.2, 0.2, HZ * 2 + 0.5), st="timber", ch=0.02, j=0.006, ease=0.01)
    gbox(mk, (0, WH + 0.185, 0), (HX * 2 + 0.1, 0.05, HZ * 2 + 0.1), st="timber", cheap=True)
    fw = (HX * 2 + 0.24) / 4.0
    fd = (HZ * 2 + 0.24) / 2.0
    for ix in range(4):
        for iz in range(2):
            h = 0.5 - 0.21 + r.uniform(-0.012, 0.0)        # from the deck (3.61) to the walk surface (3.7)
            vs, _ = gbox(mk, ((ix - 1.5) * fw + r.uniform(-0.01, 0.01), WH + 0.21 + 0.045, (iz - 0.5) * fd), (fw - 0.025, 0.09 + r.uniform(-0.008, 0.0), fd - 0.025),
                         st="hewn", ch=0.03, j=0.006, ease=0.02, chip=0.02)
            _ = h
            if ix == 3 and iz == 0:
                L.chop(mk, vs, G(HX + 0.02, WH + 0.25, -HZ + 0.4), (0.8, -0.7, 0.05), rough=0.02)
    # the tether post on the roof: a stout post in a stone shoe, an iron band and ring at its head
    gbox(mk, (1.6, WH + 1.0, -1.2), (0.2, 1.7, 0.2), st="timber", ch=0.035, j=0.004, ease=0.02)
    gbox(mk, (1.6, WH + 0.42, -1.2), (0.42, 0.24, 0.42), st="hewn", ch=0.06, j=0.004, ease=0.03, taper=0.2)
    gbox(mk, (1.6, WH + 1.72, -1.2), (0.235, 0.07, 0.235), st="iron", ch=0.04, j=0.0, ease=0.004)
    L.tube(mk, [G(1.6 + math.cos(t) * 0.07, WH + 1.62 + math.sin(t) * 0.07, -1.2 + 0.125) for t in [math.tau * q / 8 for q in range(8)]], 0.012, n=4, closed=True)
    # the gangway from the stair's head onto the roof: three boards on two battens
    for i in range(3):
        gbox(mk, (-HX - 0.3, WH + 0.295, 0.6 + i * 0.4), (2.0, 0.05, 0.37), st="timber", cheap=True, j=0.006)
    for x in (-HX - 0.9, -HX + 0.2):
        gbox(mk, (x, WH + 0.24, 1.0), (0.1, 0.07, 1.2), st="timber", cheap=True)
    # inside: the winding drum on two trestles, rope on the barrel
    drum = L.turned(mk, [(0.2, -1.75), (0.2, -1.62), (0.56, -1.6), (0.56, -1.53), (0.4, -1.51), (0.4, 2.11), (0.56, 2.13), (0.56, 2.2), (0.2, 2.22), (0.2, 2.36)], n=10, st="timber")
    rope = L.turned(mk, [(0.4, -0.7), (0.47, -0.66), (0.48, 0.2), (0.455, 0.9), (0.4, 0.95)], n=10, st="timber", top=False, bot=False)
    move(mk, drum + rope, Matrix.Translation(G(0, 1.1, -1.2)) @ Matrix.Rotation(math.pi / 2, 4, 'Y'))
    for x in (-1.4, 1.9):
        for sz in (-1, 1):
            bar(mk, G(x, -0.05, -1.2 + sz * 0.5), G(x, 0.98, -1.2 + sz * 0.1), 0.14, 0.16, st="timber")
        gbox(mk, (x, 0.3, -1.2), (0.1, 0.12, 0.8), st="timber", cheap=True)
        gbox(mk, (x, 1.0, -1.2), (0.2, 0.3, 0.5), st="timber", ch=0.03, j=0.004, ease=0.015)
    # outside the east wall: the wheel's axle, its wall plate, and the bearing frame (two posts, a head beam, braces)
    ax = L.turned(mk, [(0.15, 0.0), (0.16, 0.05), (0.16, 1.95), (0.12, 2.0)], n=8, st="timber")
    move(mk, ax, Matrix.Translation(G(WC[0] - 1.2, WC[1], WC[2])) @ Matrix.Rotation(math.pi / 2, 4, 'Y'))
    gbox(mk, (HX + 0.03, WC[1], WC[2]), (0.06, 0.62, 0.62), st="iron", cheap=True)
    px = WC[0] + 0.75
    for z in (WC[2] - 2.1, WC[2] + 1.7):
        gbox(mk, (px, 1.0, z), (0.22, 3.2, 0.22), st="timber", ch=0.03, j=0.006, ease=0.02)
        gbox(mk, (px, -0.1, z), (0.5, 0.4, 0.5), st="hewn", ch=0.07, j=0.006, ease=0.04, taper=0.15)
    gbox(mk, (px, 2.6, WC[2] - 0.2), (0.22, 0.24, 4.4), st="timber", ch=0.03, j=0.006, ease=0.015)
    for z0, z1 in ((WC[2] - 2.1, WC[2] - 1.2), (WC[2] + 1.7, WC[2] + 0.9)):
        bar(mk, G(px, 1.5, z0), G(px, 2.5, z1), 0.12, 0.14, st="timber")
    gbox(mk, (px, 2.3, WC[2]), (0.28, 0.42, 0.42), st="iron", ch=0.05, j=0.0, ease=0.01)     # the bearing strap under the beam
    return mk


def tread_wheel():
    """Axle along x through the origin; 4 m across, 1.3 wide."""
    mk = Mk(3441, "timber")
    r = mk.r
    for sx in (-1, 1):
        L.annulus(mk, 1.8, 2.0, sx * 0.56 - 0.05, sx * 0.56 + 0.05, n=16)
        for i in range(4):                                  # four diameters a side, halved over the hub
            a = math.pi * i / 4 + (0.0 if sx < 0 else 0.0)
            vs = crate(mk, (0.09, 0.13, 3.7), st="timber", j=0.004)
            move(mk, vs, Matrix.Rotation(a, 4, 'X') @ trs((sx * (0.56 + (0.1 if i % 2 else 0.0) * 0.0), 0, -1.85)))
    for i in range(16):                                     # the treads the walkers climbed
        a = math.tau * i / 16 + 0.1
        vs = crate(mk, (1.26, 0.5 + r.uniform(-0.04, 0.02), 0.055), st="timber", j=0.008)
        move(mk, vs, Matrix.Rotation(a, 4, 'X') @ trs((r.uniform(-0.02, 0.02), 0, -1.83), r.uniform(-0.02, 0.02)))
    hub = L.turned(mk, [(0.17, -0.82), (0.17, -0.7), (0.27, -0.68), (0.27, 0.68), (0.17, 0.7), (0.17, 0.82)], n=10, st="timber")
    bands = []
    for x in (-0.6, 0.6):
        bands += L.turned(mk, [(0.29, x - 0.045), (0.29, x + 0.045)], n=10, st="iron")
    move(mk, hub + bands, Matrix.Rotation(math.pi / 2, 4, 'Y'))
    return mk


def works_winch():
    hut = L.finish(winch_hut(), "Hut", tiles=BIG, sharp=50.0, moss_k=0.7)
    wheel = L.finish(tread_wheel(), "Wheel", tiles=BIG, sharp=50.0)
    for objs in (hut, wheel):
        L.tone_scale(objs, "iron", (0.5, 0.56, 0.62))
        L.tone_scale(objs, "timber", (0.72, 0.7, 0.68))       # old weathered oak, not new deal
    return dict(path=os.path.join(PROPS, "works_winch.glb"), parts=[("Hut", hut), ("Wheel", wheel)], budget=5200, show=["Hut"])


def winch_wheel():
    """Preview only: the wheel alone."""
    d = works_winch()
    return dict(path=None, parts=d["parts"], budget=9999, show=["Wheel"])


ASSETS = {"works_winch": works_winch, "winch_wheel": winch_wheel}

if __name__ == "__main__":
    L.run(ASSETS)
