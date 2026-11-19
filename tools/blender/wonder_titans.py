"""The Titan wardens before the raid floors (core/world/realm/wonders/r39/titan_gates.gd), modelled (the map audit's F28: "box
robots with orange slit eyes"). The LOOK only: the game keeps the kit's boxes (visual off) for the collision.

  tools/blender/run.sh wonder_titans.py -- [--only titan,obelisk] [--preview DIR]

  titan_warden_l.glb / _r.glb   a 17 m warden of the Order's stone on its plinth: a long armoured surcoat to its sabatons, a belt,
                                a breastplate over a broad chest, rounded pauldrons, a great helm with an eye slit (the lit eyes are
                                the game's) and a crest fin, a fire bowl on the helm; a kite shield on the arm toward the approach's
                                middle, a spear held upright in the other hand (iron head). _l has the shield on its local -x (the
                                game's s = +1), _r is its mirror.
  titan_obelisk_<h>.glb         the avenue's obelisks (h = 5..9 m): a battered base, a tapering four-sided shaft in courses, a
                                carved band, a pyramidion; titan_kerb.glb the 8 m kerb between the pairs.

Frame: Blender (x, y, z) = the game's (x = side, y = up, z = forward) as (x, -z, y); the statue faces Blender -y (the approach).
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mathutils import Vector
from reach_west_lib import *     # noqa: F401,F403
import reach_west_lib as L

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ONLY = args[args.index("--only") + 1].split(",") if "--only" in args else []


def G(x, y, z):
    return Vector((x, -z, y))


def section(cx, cy, z, hx, hy, n=12, expo=2.6, sq=1.0):
    """A superellipse ring (x half hx, y half hy) at height z, centred (cx, cy)."""
    pts = []
    for k in range(n):
        a = math.tau * k / n
        c, s = math.cos(a), math.sin(a)
        u = hx * math.copysign(abs(c) ** (2.0 / expo), c)
        v = hy * math.copysign(abs(s) ** (2.0 / expo), s) * (sq if s < 0 else 1.0)
        pts.append(Vector((cx + u, cy + v, z)))
    return pts


def loft(P, key, specs, n=12, expo=2.6):
    """specs: [(cx, cy, z, hx, hy), ...] bottom to top."""
    ring_loft(P, key, [section(cx, cy, z, hx, hy, n, expo) for (cx, cy, z, hx, hy) in specs])


def limb(P, key, a, b, r0, r1, n=8):
    """An armoured limb: a tapered prism with a rounded cop (a knob of plate) at its far joint."""
    cyl(P, key, a, b, r0, r1, seg=n)
    d = (b - a).normalized()
    ring_loft(P, key, [section(b.x, b.y, b.z - r1 * 1.1, r1 * 0.9, r1 * 0.9, n, 2.0), section(b.x, b.y, b.z, r1 * 1.12, r1 * 1.12, n, 2.0),
                       section(b.x, b.y, b.z + r1 * 0.9, r1 * 0.75, r1 * 0.75, n, 2.0)])


def titan(mirror):
    """The warden with its shield on the side `-sx` (sx = -1 for _l: shield on local -x; +1 for _r: shield on +x)."""
    sx = -1.0 if not mirror else 1.0         # the shield's side
    reset()
    P = Parts()
    rnd = L.rnd_for(81 if not mirror else 82)
    L.mason_begin(81 if not mirror else 82)
    # the plinth (the kit's 6.4 m block to 1.7 and its 5.4 m slab to 2.05), coursed, with a moulded top
    for (a, b) in (((-2.6, -3.2), (-2.6, 3.2)), ((2.6, 3.2), (2.6, -3.2)), ((3.2, -2.6), (-3.2, -2.6)), ((-3.2, 2.6), (3.2, 2.6))):
        L.wall_run(P, None, "ashlar", a, b, -1.2, 2.9, 1.2, lambda u, v: True, rnd, ch=0.62, col=False, blk=(1.0, 1.9), faces=(1,))
    L.dbox(P, "ashlar", (0.0, 0.0, 1.85), (5.6, 5.6, 0.4), bevel=0.1)
    L.dbox(P, "ashlar", (0.0, 0.0, 1.62), (6.7, 6.7, 0.22), bevel=0.06)
    # sabatons under the hem, the surcoat skirt to the belt (the kit's body box 3.8 x 9 x 3.2 from 2 to 11)
    for fx in (-0.95, 0.95):
        loft(P, "hewn", [(fx, -0.6, 2.05, 0.55, 1.1), (fx, -0.55, 2.4, 0.5, 1.0), (fx, -0.3, 2.8, 0.42, 0.6)], n=10)
    loft(P, "hewn", [(0.0, 0.05, 2.05, 2.05, 1.75), (0.0, 0.05, 3.2, 1.98, 1.66), (0.0, 0.05, 4.8, 1.86, 1.55),
                       (0.0, 0.0, 6.3, 1.72, 1.45), (0.0, 0.0, 6.9, 1.7, 1.42)], n=14)
    # the skirt's front split and its folds: shallow ribs down the front and sides
    for k in range(-3, 4):
        x = k * 0.48
        beam(P, "hewn", (x, -1.62 - abs(k) * -0.02, 2.2), (x * 0.95, -1.42, 6.2), 0.16, 0.12)
    # the belt (kit 4.3 x 0.6 x 3.7 at 6.3 .. 6.9) and its buckle
    loft(P, "hewn", [(0.0, 0.0, 6.3, 2.12, 1.84), (0.0, 0.0, 6.9, 2.12, 1.84)], n=16, expo=3.2)
    L.dbox(P, "hewn", (0.0, -1.88, 6.6), (0.8, 0.22, 0.7), bevel=0.06)
    # the torso and the breastplate up to the shoulders (the kit's chest box 5.8 x 3.4 x 3.6 from 10.5 to 13.9)
    loft(P, "hewn", [(0.0, 0.0, 6.9, 1.72, 1.45), (0.0, -0.05, 8.6, 1.95, 1.6), (0.0, -0.1, 10.3, 2.5, 1.75),
                       (0.0, -0.05, 12.2, 2.75, 1.8), (0.0, 0.0, 13.5, 2.55, 1.6), (0.0, 0.05, 13.95, 1.5, 1.2)], n=16)
    # the breastplate's ridge and its edge
    beam(P, "hewn", (0.0, -1.9, 8.2), (0.0, -1.98, 12.6), 0.22, 0.2)
    # pauldrons: stacked rounded lames over each shoulder
    for side in (-1.0, 1.0):
        for j in range(3):
            loft(P, "hewn", [(side * (2.75 + 0.1 * j), 0.0, 13.4 - j * 0.55, 1.15 - j * 0.05, 1.5 - j * 0.04),
                               (side * (2.85 + 0.1 * j), 0.0, 13.9 - j * 0.55, 1.0 - j * 0.05, 1.35 - j * 0.04),
                               (side * (2.7 + 0.1 * j), 0.0, 14.25 - j * 0.55, 0.55, 0.85)], n=12)
    # the neck and the great helm (kit 2.6 x 2.4 x 2.6 from 13.7 to 16.1; its crown slab 3.0 x 0.5 x 3.0 at 16.05 .. 16.55)
    loft(P, "hewn", [(0.0, 0.0, 13.9, 0.95, 0.9), (0.0, 0.0, 14.2, 0.9, 0.85)], n=10)
    loft(P, "hewn", [(0.0, 0.0, 13.75, 1.32, 1.3), (0.0, -0.02, 14.6, 1.3, 1.32), (0.0, -0.03, 15.6, 1.28, 1.3),
                       (0.0, 0.0, 16.1, 1.18, 1.18), (0.0, 0.0, 16.5, 0.95, 0.95)], n=14, expo=2.2)
    # the eye slit's dark band and the breaths (pierced cross under it), on the approach face (-y)
    box(P, "iron", (0.0, -1.27, 15.36), (1.9, 0.16, 0.44))
    for j in range(5):
        box(P, "iron", ((j - 2) * 0.22, -1.29, 14.55), (0.06, 0.12, 0.5))
    # the crest fin: a ridge of stone over the helm, sweeping back (the kit's crest tube toward -f, i.e. Blender +y)
    for j in range(7):
        t = j / 6.0
        L.dbox(P, "hewn", (0.0, -0.9 + t * 2.4, 16.6 + math.sin(t * math.pi) * 0.9), (0.28, 0.5, 0.75 - 0.3 * t), pitch=-0.4 + t * 0.6, bevel=0.05)
    # the fire bowl on the helm (kit iron 1.5 x 0.4 x 1.5 at 16.8 .. 17.2)
    cyl(P, "iron", (0.0, 0.0, 16.55), (0.0, 0.0, 16.85), 0.35, 0.55, seg=12)
    cyl(P, "iron", (0.0, 0.0, 16.85), (0.0, 0.0, 17.2), 0.55, 0.8, seg=14)
    cyl(P, "stone", (0.0, 0.0, 17.12), (0.0, 0.0, 17.18), 0.72, 0.7, seg=14)
    # the arms (kit boxes at x +-3.7, 5.8 .. 13): the shield arm bent forward to the shield; the spear arm down to the hand
    sh = Vector((sx * 2.95, 0.0, 12.7))
    el_s = Vector((sx * 3.6, -0.6, 9.7))
    wr_s = Vector((sx * 3.55, -1.7, 8.4))
    limb(P, "hewn", sh, el_s, 0.95, 0.8, 10)
    limb(P, "hewn", el_s, wr_s, 0.8, 0.62, 10)
    sp = Vector((-sx * 2.95, 0.0, 12.7))
    el_p = Vector((-sx * 3.75, 0.15, 9.8))
    hand = G(-sx * 3.7, 7.0, 0.6)
    limb(P, "hewn", sp, el_p, 0.95, 0.8, 10)
    limb(P, "hewn", el_p, hand + Vector((0, 0, 0.4)), 0.8, 0.62, 10)
    # the gauntleted fist round the spear
    loft(P, "hewn", [(hand.x, hand.y, hand.z - 0.35, 0.5, 0.48), (hand.x, hand.y, hand.z + 0.35, 0.52, 0.5)], n=10)
    # the spear: a shaft from 4.5 m under the hand to 15.6 over it, an iron collar and a leaf blade (kit iron cone 15.4 .. 17.8)
    cyl(P, "timber", hand - Vector((0, 0, 4.5)), hand + Vector((0, 0, 15.5)), 0.26, 0.2, seg=8)
    for zz in (2.0, 9.0, 15.2):
        cyl(P, "iron", hand + Vector((0, 0, zz)), hand + Vector((0, 0, zz + 0.3)), 0.29, 0.27, seg=8)
    blade = [section(hand.x, hand.y, hand.z + 15.45 + t * 2.4, 0.42 * math.sin(math.pi * (0.15 + 0.85 * t)) + 0.03, 0.1 * (1.0 - t) + 0.02, 8, 2.0)
             for t in (0.0, 0.25, 0.55, 0.85, 1.0)]
    ring_loft(P, "iron", blade)
    # the kite shield on the forearm (kit slab 3.6 x 7.0 x 0.7 at x -3.6 s, z +2.1, 4.7 .. 11.7): curved, a rim, a boss and bands
    sc = Vector((sx * 3.6, -2.1, 8.2))
    rings = []
    for j in range(9):
        t = j / 8.0
        z = sc.z - 3.5 + t * 7.0
        half = 1.8 * (math.sin(min(1.0, t * 1.25) * math.pi * 0.5) if t < 0.8 else 1.0 - (t - 0.8) * 0.6)
        half = max(half, 0.12)
        ring = []
        for k in range(7):
            u = -half + 2.0 * half * k / 6.0
            bulge = 0.35 * (1.0 - (u / max(half, 0.01)) ** 2)
            ring.append(Vector((sc.x + u, sc.y - bulge, z)))
        for k in range(6, -1, -1):
            u = -half + 2.0 * half * k / 6.0
            ring.append(Vector((sc.x + u, sc.y + 0.35, z)))
        rings.append(ring)
    ring_loft(P, "hewn", rings)
    cyl(P, "iron", sc + Vector((0, -0.45, 0.6)), sc + Vector((0, -0.62, 0.6)), 0.55, 0.42, seg=12)
    box(P, "iron", (sc.x, sc.y - 0.42, sc.z + 0.6), (0.18, 0.08, 6.4))
    box(P, "iron", (sc.x, sc.y - 0.42, sc.z + 1.8), (3.2, 0.08, 0.18))
    objs = finish(P, "Titan", smooth_keys=()) + L.mason_end("Titan")
    nm = "titan_warden_r" if mirror else "titan_warden_l"
    export(objs, os.path.join(MODELS, nm + ".glb"), nm)
    preview(objs, nm, [((-16, -26, 12), (0, 0, 9), 30), ((18, -18, 6), (0, 0, 10), 32), ((0, -9, 15), (0, 0, 15), 28), ((14, 18, 14), (0, 0, 10), 34)])


def asset_titan():
    titan(False)
    titan(True)


def asset_obelisk():
    for h in (9, 8, 7, 6, 5):
        reset()
        P = Parts()
        rnd = L.rnd_for(90 + h)
        L.mason_begin(90 + h)
        # the base (kit 2.4 x 1.9 x 2.4 from -1 to 0.9): a battered block with a moulded cap
        L.dbox(P, "ashlar", (0.0, 0.0, -0.1), (2.4, 2.4, 1.9), bevel=0.08)
        L.dbox(P, "ashlar", (0.0, 0.0, 0.9), (2.0, 2.0, 0.2), bevel=0.06)
        # the shaft: courses of four-sided rings tapering from 0.85 (kit tube radius, square at 45 deg) to 0.5
        z = 1.0
        while z < h - 0.05:
            ch = min(rnd.uniform(0.55, 0.85), h - z)
            t0 = (z - 0.9) / (h - 0.9)
            half = (0.85 - 0.35 * t0) * 0.7071 * 2.0 * 0.5
            L.dbox(P, "ashlar", (0.0, 0.0, z + ch * 0.5), (half * 2.0, half * 2.0, ch * 0.97), yaw=rnd.uniform(-0.01, 0.01), bevel=0.04)
            z += ch
        # a carved band of runes (sunk panels) a third of the way up
        bz = 3.0 if h > 6 else 2.4
        for side in range(4):
            a = side * math.pi * 0.5
            box(P, "iron", (math.cos(a) * 0.67, math.sin(a) * 0.67, bz + 1.0), (0.06 if side % 2 == 0 else 0.7, 0.7 if side % 2 == 0 else 0.06, 1.6))
        # the pyramidion
        ring_loft(P, "ashlar", [section(0, 0, h, 0.37, 0.37, 4, 50.0), section(0, 0, h + 0.88, 0.02, 0.02, 4, 50.0)])
        objs = finish(P, "Obelisk") + L.mason_end("Obelisk")
        export(objs, os.path.join(MODELS, "titan_obelisk_%d.glb" % h), "obelisk%d" % h)
        if h == 9:
            preview(objs, "obelisk", [((-6, -8, 4), (0, 0, 4.5), 30)])
    reset()
    P = Parts()
    rnd = L.rnd_for(99)
    L.mason_begin(99)
    y = -4.0
    while y < 3.95:
        ln = min(rnd.uniform(0.9, 1.6), 4.0 - y)
        L.dbox(P, "ashlar", (0.0, y + ln * 0.5, 0.0), (0.7, ln * 0.97, 0.7), bevel=0.06, warp=0.02)
        y += ln
    objs = finish(P, "Kerb") + L.mason_end("Kerb")
    export(objs, os.path.join(MODELS, "titan_kerb.glb"), "kerb")


ASSETS = {"titan": asset_titan, "obelisk": asset_obelisk}
for k, fn in ASSETS.items():
    if not ONLY or k in ONLY:
        fn()
