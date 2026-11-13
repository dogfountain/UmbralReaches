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


# --- iron lanterns -----------------------------------------------------------------------------------------
def lantern_head(mk, c, half=0.125, h=0.34):
    """A square lantern's cage about centre c (Blender coords): a foot plate, four bars, glazing rails, a hood with a
    ring. The glass and flame are the game's (a Lamp's pane look fits inside: radius 0.105, 0.3 tall)."""
    c = Vector(c)
    z0, z1 = c.z - h * 0.5, c.z + h * 0.5
    for vs in (crate(mk, (half * 2 + 0.03, half * 2 + 0.03, 0.02), st="iron"),):
        move(mk, vs, trs((c.x, c.y, z0 - 0.02)))
    drip = L.turned(mk, [(0.05, z0 - 0.06), (0.03, z0 - 0.02)], n=4, st="iron")
    move(mk, drip, trs((c.x, c.y, 0.0)))
    for sx in (-1, 1):
        for sy in (-1, 1):
            bar(mk, (c.x + sx * half, c.y + sy * half, z0), (c.x + sx * half, c.y + sy * half, z1), 0.018)
    for k in range(4):
        a = math.pi * 0.5 * k
        cs, sn = math.cos(a), math.sin(a)
        for z in (z0 + 0.012, z1 - 0.012):
            bar(mk, (c.x + (cs - sn) * half, c.y + (sn + cs) * half, z), (c.x + (cs + sn) * half, c.y + (sn - cs) * half, z), 0.014)
    hood = L.turned(mk, [(half * 1.62, 0.0), (half * 1.5, 0.02), (half * 0.75, 0.075), (0.03, 0.12), (0.022, 0.14)], n=4, st="iron", phase=math.pi / 4)
    move(mk, hood, trs((c.x, c.y, z1)))
    return z1 + 0.14


def street_lantern():
    """Weirford's street lantern: a cast foot, a round post with a collar, a scrolled bracket to the front (Blender -Y
    = Godot +Z) and the cage hung from it. The cage's centre is at Godot (0, 2.8, 0.6): where the game puts the glass."""
    mk = Mk(3470, "iron")
    L.turned(mk, [(0.17, -0.25), (0.17, 0.05), (0.13, 0.1), (0.09, 0.3), (0.075, 0.34), (0.06, 0.36)], n=8, st="iron")
    L.turned(mk, [(0.05, 0.36), (0.044, 1.0), (0.062, 1.02), (0.062, 1.07), (0.042, 1.09), (0.036, 3.3), (0.06, 3.33), (0.06, 3.37), (0.02, 3.46)], n=6, st="iron")
    arc = [G(0, 3.0 + 0.24 * math.sin(t), 0.04 + 0.6 * (1 - math.cos(t)) / 1.0) for t in [math.pi * 0.5 * q / 5 for q in range(6)]]
    L.tube(mk, arc + [G(0, 3.24, 0.72)], 0.02, n=4)
    scroll = [G(0, 2.55 + 0.42 * q / 5 + 0.05 * math.sin(q * 1.2), 0.04 + 0.36 * (q / 5) ** 1.6) for q in range(6)]
    L.tube(mk, scroll, 0.014, n=4)
    top = lantern_head(mk, G(0, 2.8, 0.6))
    L.tube(mk, [G(0, top + 0.045 + math.sin(t) * 0.035, 0.6 + math.cos(t) * 0.035) for t in [math.tau * q / 6 for q in range(6)]], 0.008, n=4, closed=True)
    bar(mk, G(0, top + 0.08, 0.6), G(0, 3.24, 0.6), 0.012)
    return mk


def post_lantern():
    """A lantern on a short iron post (Aldith's last lamp): a spiked foot, a post with a knop, the cage on its head.
    The cage's centre is 1.7 m up: the game's lit glass goes there."""
    mk = Mk(3471, "iron")
    L.turned(mk, [(0.02, -0.3), (0.05, -0.02), (0.07, 0.0), (0.07, 0.03), (0.035, 0.06), (0.03, 0.8), (0.05, 0.82), (0.05, 0.86), (0.028, 0.88), (0.026, 1.46), (0.07, 1.5)], n=6, st="iron")
    lantern_head(mk, (0, 0, 1.7), half=0.1, h=0.32)
    return mk


def lamp_street():
    parts = [("Street", L.finish(street_lantern(), "Street", sharp=50.0)), ("PostLantern", L.finish(post_lantern(), "PostLantern", sharp=50.0))]
    for _, objs in parts:
        L.tone_scale(objs, "iron", (0.55, 0.6, 0.66))
    return dict(path=os.path.join(PROPS, "lamp_street.glb"), parts=parts, budget=1100, focus=Vector((0.0, -0.5, 2.8)))


# --- the smithy --------------------------------------------------------------------------------------------
def smith_anvil():
    """An anvil on an oak stump: face 0.8 m up (the old box's top), 0.9 long along x, the horn to +x."""
    mk = Mk(3472, "iron")
    L.turned(mk, [(0.31, -0.05), (0.32, 0.03), (0.29, 0.46), (0.27, 0.5)], n=9, st="timber")
    for size, c in (((0.5, 0.3, 0.07), (0, 0, 0.5)), ((0.4, 0.24, 0.05), (0, 0, 0.57)), ((0.26, 0.17, 0.1), (0, 0, 0.62))):
        vs, _ = block(mk, size, ch=0.02, j=0.0, ease=0.012, st="iron")
        move(mk, vs, trs(c))
    vs, _ = block(mk, (0.54, 0.2, 0.09), ch=0.012, j=0.0, ease=0.008, st="iron")
    move(mk, vs, trs((-0.04, 0, 0.71)))
    horn = L.turned(mk, [(0.085, 0.0), (0.075, 0.08), (0.045, 0.18), (0.012, 0.25)], n=7, st="iron")
    move(mk, horn, Matrix.Translation((0.22, 0, 0.745)) @ Matrix.Rotation(math.pi / 2 - 0.08, 4, 'Y'))
    vs = crate(mk, (0.12, 0.2, 0.06), st="iron")
    move(mk, vs, trs((-0.36, 0, 0.74)))
    bar(mk, (-0.2, 0.33, 0.52), (0.16, 0.24, 0.53), 0.03, 0.03, st="timber")           # a hammer left across the stump
    vs, _ = block(mk, (0.1, 0.05, 0.05), ch=0.01, j=0.0, ease=0.006, st="iron")
    move(mk, vs, trs((0.17, 0.24, 0.505), 0.25))
    return mk


def smith_hearth():
    """The forge's hearth: two courses of blocks under a rim of stones round a sunk fire bed (the game's coals glow in
    it), an ash arch in the front (Blender -Y). 1.4 x 1.1, 1.0 high (the old box)."""
    mk = Mk(3473, "hewn")
    r = mk.r
    for z, h, cuts in ((-0.2, 0.68, (0.0,)), (0.48, 0.42, (-0.22, 0.26))):
        xs = [-0.7] + list(cuts) + [0.7]
        for i in range(len(xs) - 1):
            w = xs[i + 1] - xs[i]
            vs, faces = block(mk, (w - 0.012, 1.09, h - 0.01), ch=0.03, j=0.006, ease=0.02, chip=0.015)
            move(mk, vs, trs(((xs[i] + xs[i + 1]) * 0.5, 0, z)))
            if z < 0 and i == 0:
                arch = [(0.15, -0.2), (0.15, 0.02)] + [(math.cos(a) * 0.15, 0.02 + math.sin(a) * 0.15) for a in (math.pi / 4, math.pi / 2, 3 * math.pi / 4)] + [(-0.15, 0.02), (-0.15, -0.2)]
                mk.cut(faces[(1, 6)], [[(u + 0.05, v + 0.12) for u, v in arch]], 0.3, floor_tag=L.TAG_DARK)
    for c, size in (((0, -0.44, 0.9), (1.4, 0.22, 0.1)), ((0, 0.44, 0.9), (1.4, 0.22, 0.1)), ((-0.57, 0, 0.9), (0.26, 0.64, 0.1)), ((0.57, 0, 0.9), (0.26, 0.64, 0.1))):
        vs, _ = block(mk, (size[0] - 0.01, size[1] - 0.01, size[2] + r.uniform(0.0, 0.02)), ch=0.025, j=0.006, ease=0.02, chip=0.015)
        move(mk, vs, trs(c))
    bed = crate(mk, (0.9, 0.68, 0.04), st="hewn")
    move(mk, bed, trs((0, 0, 0.895)))
    for f in {f for v in bed for f in v.link_faces}:
        f[mk.tag] = L.TAG_DARK
    return mk


def works_smithy():
    parts = [("Anvil", L.finish(smith_anvil(), "Anvil", sharp=50.0)), ("Hearth", L.finish(smith_hearth(), "Hearth", sharp=50.0, moss_k=0.0))]
    for _, objs in parts:
        L.tone_scale(objs, "iron", (0.5, 0.54, 0.6))
        L.tone_scale(objs, "timber", (0.72, 0.7, 0.68))
        L.tone_scale(objs, "hewn", (0.7, 0.66, 0.64))          # soot
    return dict(path=os.path.join(PROPS, "works_smithy.glb"), parts=parts, budget=1100)


# --- the Rooted Holds' houses ------------------------------------------------------------------------------
def _sweep(mk, section, angles, closed):
    """Revolve a closed cross-section [(radius, z)] about z through `angles` (the door is at angle 0 = Blender -Y)."""
    rings = [[Vector((math.sin(a) * max(r, 0.02), -math.cos(a) * max(r, 0.02), z)) for r, z in section] for a in angles]
    _, vs = mk.loft(rings, top=not closed, bot=not closed, hull=False)
    return L.flat(vs)


def holds_house(part):
    """A turf house of the Holds: a ring wall of five sod courses leaning in to a low crown, a gap for the door under
    the fifth course (headroom 2.17). Hollow: the wanderer goes in. The old kit's rings of boxes are still its collider,
    and the wall keeps inside them. Parts: Dome (turf: the builder dresses it with the kit's earth), Door (two upright
    stones and a lintel), Leaf (a shut plank door), Rack (the drying rack by the fire-ring)."""
    mk = Mk(3480 + ["Dome", "Door", "Leaf", "Rack"].index(part), "daub")
    r = mk.r
    if part == "Dome":
        outer = [(3.0, -0.5), (2.97, 0.02)]
        for t in range(4):
            rt = 2.91 - 0.25 * t
            outer += [(rt + 0.04, 0.55 * t + 0.08), (rt + 0.03, 0.55 * t + 0.32), (rt - 0.08, 0.55 * t + 0.53)]
        inner = [(1.37, 2.17), (1.6, 1.67), (1.85, 1.12), (2.1, 0.57), (2.35, 0.03), (2.35, -0.5)]
        half = 0.42
        angs = [half + (math.tau - 2 * half) * i / 15 for i in range(16)]
        low = _sweep(mk, outer + inner, angs, False)
        up_out = [(2.12, 2.17), (1.95, 2.26), (1.94, 2.5), (1.84, 2.72), (1.58, 2.86), (1.18, 3.05), (0.68, 3.2), (0.03, 3.26)]
        up_in = [(0.03, 2.7), (0.9, 2.68), (1.3, 2.6), (1.37, 2.17)]
        top = _sweep(mk, up_out + up_in, [math.tau * i / 16 for i in range(17)], True)
        import bmesh as _bm
        _bm.ops.remove_doubles(mk.bm, verts=top, dist=1e-4)
        for v in [v for v in low + top if v.is_valid]:            # lumpy sods: out a little here and there, never in past the collider
            rad = math.hypot(v.co.x, v.co.y)
            if rad < 0.1:
                continue
            n = PS.fbm(v.co * 1.4 + Vector((7.0, 3.0, 1.0)), 3)
            v.co.x += v.co.x / rad * 0.07 * abs(n)
            v.co.y += v.co.y / rad * 0.07 * abs(n)
            v.co.z += 0.03 * n
        _bm.ops.recalc_face_normals(mk.bm, faces=mk.bm.faces[:])
    elif part == "Door":
        for sx in (-1, 1):
            vs, _ = block(mk, (0.32, 0.44, 2.3), ch=0.05, j=0.01, ease=0.04, chip=0.03, taper=0.08, st="hewn")
            move(mk, vs, trs((sx * 0.78, -2.55, -0.3), r.uniform(-0.06, 0.06), 0.0, sx * 0.02))
        vs, _ = block(mk, (1.98, 0.54, 0.31), ch=0.05, j=0.012, ease=0.04, chip=0.03, st="hewn")
        move(mk, vs, trs((0, -2.55, 1.97), 0.02, 0.0, 0.012))
    elif part == "Leaf":
        x = -0.65
        for i in range(5):
            w = 0.26 + r.uniform(-0.03, 0.03) if i < 4 else 0.65 - x
            vs = crate(mk, (w - 0.012, 0.055, 1.93 + r.uniform(-0.03, 0.0)), st="timber", j=0.004)
            move(mk, vs, trs((x + w * 0.5, -2.6, 0.02)))
            x += w
        for z in (0.45, 1.5):
            vs = crate(mk, (1.24, 0.045, 0.14), st="timber", j=0.004)
            move(mk, vs, trs((0, -2.655, z)))
        L.tube(mk, [Vector((0.42 + math.cos(t) * 0.06, -2.69, 1.02 + math.sin(t) * 0.06)) for t in [math.tau * q / 6 for q in range(6)]], 0.012, n=4, closed=True)
    else:
        for sx in (-1, 1):
            L.tube(mk, [(sx * 1.2, 0, -0.3), (sx * 1.21, 0.01, 0.9), (sx * 1.19, 0, 1.72)], 0.05, n=5, st="timber")
            L.tube(mk, [(sx * 1.19, 0, 1.6), (sx * 1.19, 0.1, 1.9)], 0.03, n=4, st="timber")
            L.tube(mk, [(sx * 1.19, 0, 1.6), (sx * 1.19, -0.1, 1.9)], 0.03, n=4, st="timber")
        L.tube(mk, [(-1.38, 0, 1.76), (0, 0.01, 1.74), (1.38, 0, 1.77)], 0.032, n=5, st="timber")
        for j in range(4):                                   # what was left drying: stiff strips on thongs
            cx = -0.9 + 0.6 * j
            vs = crate(mk, (0.2 + r.uniform(-0.03, 0.05), 0.02, 0.62 + r.uniform(-0.1, 0.05)), st="timber", j=0.01, taper=0.35)
            move(mk, vs, trs((cx, 0, 1.72), r.uniform(-0.3, 0.3), math.pi + r.uniform(-0.06, 0.06)))
    return mk


def works_holds():
    parts = []
    for nm in ("Dome", "Door", "Leaf", "Rack"):
        parts.append((nm, L.finish(holds_house(nm), nm, tiles={"daub": 6.0}, sharp=62.0 if nm == "Dome" else 50.0, moss_k=1.3,
                               smooth_sets=("daub",) if nm == "Dome" else ())))
    for _, objs in parts:
        L.tone_scale(objs, "timber", (0.7, 0.68, 0.66))
        L.tone_scale(objs, "iron", (0.5, 0.55, 0.6))
    return dict(path=os.path.join(PROPS, "works_holds.glb"), parts=parts, budget=1800)


# --- Weirford's well ---------------------------------------------------------------------------------------
def well_head():
    """The covered well in the square: a curb of ten dressed stones (the old ring of boxes: 1.0 high, out to 1.25), two
    posts in it carrying a windlass with its crank and rope, a bucket on the curb, and a little boarded roof on a
    tie beam (ridge along x)."""
    mk = Mk(3490, "hewn")
    r = mk.r
    n = 10
    for i in range(n):
        a0 = math.tau * i / n + 0.012
        a1 = math.tau * (i + 1) / n - 0.012
        h = 0.98 + r.uniform(-0.03, 0.04)
        ri, ro = 0.66 + r.uniform(-0.01, 0.01), 1.14 + r.uniform(-0.03, 0.03)
        rings = []
        for z, k in ((-0.3, 1.0), (h - 0.03, 1.0), (h, 0.985)):
            rings.append([Vector((math.cos(a) * rad, math.sin(a) * rad, z)) for a, rad in ((a0, ro * k), (a1, ro * k), (a1, ri / k), (a0, ri / k))])       # counter-clockwise from above: faces look out
        mk.loft(rings, top=True, bot=True, hull=False)
    water = L.turned(mk, [(0.7, 0.28), (0.02, 0.28)], n=10, st="hewn", top=False, bot=False)
    for f in {f for v in water for f in v.link_faces}:
        f[mk.tag] = L.TAG_DARK
    for sx in (-1, 1):
        vs, _ = block(mk, (0.15, 0.15, 2.5), ch=0.03, j=0.004, ease=0.015, st="timber")
        move(mk, vs, trs((sx * 0.98, 0, 0.35)))
        bar(mk, (sx * 0.98, 0, 2.1), (sx * 0.55, 0, 2.72), 0.08, 0.07, st="timber")
    roller = L.turned(mk, [(0.05, -1.12), (0.05, -0.9), (0.085, -0.88), (0.085, -0.4), (0.11, -0.38), (0.11, 0.3), (0.085, 0.32), (0.085, 0.88), (0.05, 0.9), (0.05, 1.12)], n=8, st="timber")
    move(mk, roller, Matrix.Translation((0, 0, 1.72)) @ Matrix.Rotation(math.pi / 2, 4, 'Y'))
    L.tube(mk, [(1.1, 0, 1.72), (1.22, 0, 1.72), (1.22, 0.0, 1.44), (1.42, 0.0, 1.44)], 0.016, n=4, st="iron")      # the crank
    L.tube(mk, [(0.15, -0.105, 1.72), (0.16, -0.5, 1.2), (0.1, -0.86, 1.02)], 0.014, n=4, st="timber")              # the rope to the bucket
    bucket = L.turned(mk, [(0.13, 0.0), (0.17, 0.3), (0.15, 0.3), (0.115, 0.03)], n=8, st="timber")
    move(mk, bucket, trs((0.1, -0.88, 0.98), 0.3, 0.05))
    L.tube(mk, [(0.1 + math.cos(t) * 0.16, -0.88 + math.sin(t) * 0.16, 1.2) for t in [math.tau * q / 8 for q in range(8)]], 0.012, n=4, st="iron", closed=True)
    vs, _ = block(mk, (2.3, 0.2, 0.13), ch=0.02, j=0.004, ease=0.012, st="timber")              # the tie beam
    move(mk, vs, trs((0, 0, 2.74)))
    for sx in (-1, 1):
        for sy in (-1, 1):
            bar(mk, (sx * 1.05, sy * 0.8, 2.8), (sx * 1.05, 0, 3.24), 0.07, 0.09, st="timber")
    vs = crate(mk, (2.6, 0.08, 0.08), st="timber", j=0.004)
    move(mk, vs, trs((0, 0, 3.22)))
    for sy in (-1, 1):                                        # the roof: boards down each slope, lapped
        for k in range(6):
            w = 2.5 / 6
            vs = crate(mk, (w - 0.01, 0.95 + r.uniform(-0.04, 0.03), 0.035), st="timber", j=0.006)
            move(mk, vs, Matrix.Translation((-1.25 + w * (k + 0.5), sy * 0.44, 3.03 + (0.012 if k % 2 else 0.0))) @ Matrix.Rotation(-sy * 0.5, 4, 'X'))
    return mk


def works_well():
    parts = [("Well", L.finish(well_head(), "Well", sharp=50.0, moss_k=1.3))]
    for _, objs in parts:
        L.tone_scale(objs, "timber", (0.68, 0.66, 0.64))
        L.tone_scale(objs, "iron", (0.5, 0.55, 0.6))
    return dict(path=os.path.join(PROPS, "works_well.glb"), parts=parts, budget=900)


# --- the Quarry's squared blocks ---------------------------------------------------------------------------
def quarry_block(kind):
    """A squared block waiting for a cart: 1.7 x 1.0, 0.9 high (the old box), pivot under its middle. A = dressed, a row
    of wedge slots along one edge where it was split off; B = one face left rough and a corner gone; C = cracked through."""
    mk = Mk(3495 + "ABC".index(kind), "hewn")
    if kind == "C":
        a, _ = block(mk, (0.98, 1.0, 0.9), ch=0.03, j=0.008, ease=0.025, chip=0.02)
        a = L.chop(mk, a, (0.38, 0, 0.45), (1.0, 0.25, 0.12), rough=0.05)
        move(mk, a, trs((-0.4, 0, -0.03), 0.0, 0.0, -0.012))
        b, _ = block(mk, (0.98, 1.0, 0.9), ch=0.03, j=0.008, ease=0.025, chip=0.02)
        b = L.chop(mk, b, (-0.3, 0, 0.45), (-1.0, -0.25, -0.12), rough=0.05)
        move(mk, b, trs((0.43, 0.02, -0.05), 0.03, 0.0, 0.035))
        return mk
    vs, faces = block(mk, (1.7, 1.0, 0.93), ch=0.03, j=0.008, ease=0.025, chip=0.02)
    if kind == "A":
        mk.cut(faces[(1, 2)], [PS.rect(0.045, 0.06, -0.6 + 0.3 * i, 0.36) for i in range(5)], 0.07, floor_tag=L.TAG_DARK)
    else:
        vs = L.chop(mk, vs, (0.0, -0.44, 0.45), (0.06, -1.0, 0.1), rough=0.07)
        vs = L.chop(mk, vs, (0.62, 0.3, 0.75), (0.7, 0.45, 0.6), rough=0.05)
    move(mk, L.island(vs), trs((0, 0, -0.03)))
    return mk


def works_quarry():
    parts = [("Block" + k, L.finish(quarry_block(k), "Block" + k, sharp=50.0, moss_k=0.9)) for k in "ABC"]
    return dict(path=os.path.join(PROPS, "works_quarry.glb"), parts=parts, budget=500)


ASSETS = {"works_winch": works_winch, "winch_wheel": winch_wheel, "lamp_street": lamp_street, "works_smithy": works_smithy,
          "works_holds": works_holds, "works_well": works_well, "works_quarry": works_quarry}

if __name__ == "__main__":
    L.run(ASSETS)
