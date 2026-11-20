"""THE SLEEPER (core/world/realm/wonders/r39/the_sleeper.gd), modelled: the map audit's F28 ("a 'Sleeper' that is a stepped
block tower"). An 80 m colossus of the Order's stone lying on its back, armoured, its face looking up. The LOOK only: the
game keeps the kit's blocks with its visual off for every collider, stair ramp and solid, and keeps its own interior (the
hall's floor, the two flights, the landing, the ribs, the dais and its furnace), lights, fires, lit slits, chests, rubble,
banners, chains and strands.

  tools/blender/run.sh wonder_sleeper.py -- [--preview DIR]

  wonder_sleeper.glb   sabatons toe-up, greaves with a band, knee cops, cuisses, the hips' lames and the studded belt; the
                       breastplate: the heart-hall's flanks in coursed masonry (the lit slits, the wound in the east flank
                       with its ragged edge), ribs of plate over them, a rolled edge, the waist and shoulder walls, the deck
                       of great slabs with its three oculi and the stair's well; the left arm folded on the flank to its
                       fist; the right pauldron (the shoulder deck), the upper arm, the vambrace (the forearm bridge with
                       its rails), the gauntlet's palm, thumb and four fingers curled up round the fire basin (a bronze
                       bowl on three feet); the gorget; the great helm face-up: its rim, the visor's brow and nose ridge,
                       the eye sockets round the lit eyes, the breaths, the mouth's grille; the crown of nine spikes and
                       the two horns.

Frame: the builder's body frame (x across, toward the outstretched arm; z along, feet at -42, head at 52; y up from the
datum y0). Blender (x, y, z) = the game's (x, -z, y). Every form runs 6 m under the datum (the ground under the body lies
0.4 .. ~4 m below it; the kit's own footings go to the lowest ground), so the land closes on stone everywhere.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mathutils import Vector
from reach_west_lib import *     # noqa: F401,F403
import reach_west_lib as L

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
BOT = -6.0                       # every form's foot under the datum


def G(x, y, z):
    return Vector((x, -z, y))


def prof(cx, hw, top, rh, n=12, expo=3.0, bot=BOT):
    """A tombstone section in the game's (x, y): vertical sides from `bot`, a rounded top (`rh` high) at `top`.
    Returned as [(x, y), ...] from the right foot, up and over to the left foot."""
    rh = min(rh, top - bot - 0.2)
    mid = top - rh
    pts = [(cx + hw, bot)]
    for i in range(n + 1):
        a = math.pi * i / n
        c, s = math.cos(a), math.sin(a)
        pts.append((cx + hw * math.copysign(abs(c) ** (2.0 / expo), c), mid + rh * abs(s) ** (2.0 / expo)))
    pts.append((cx - hw, bot))
    return pts


def run_z(P, key, x0, x1, z0, z1, top, rh, ends=(0.6, 0.6), n=12, expo=3.0, stations=8, bot=BOT):
    """A long carved form along the game's z (a shin, a thigh, the neck): the section `prof` swept z0 -> z1, its ends rounded
    in by `ends` metres (the top drops and the sides draw in)."""
    cx, hw = (x0 + x1) * 0.5, (x1 - x0) * 0.5
    rings = []
    zs = [z0 + (z1 - z0) * i / stations for i in range(stations + 1)]
    for i, z in enumerate(zs):
        t = i / stations
        e = 0.0
        if ends[0] > 0.0 and z - z0 < ends[0]:
            e = 1.0 - math.sqrt(max(0.0, 1.0 - ((ends[0] - (z - z0)) / ends[0]) ** 2))
        if ends[1] > 0.0 and z1 - z < ends[1]:
            e = max(e, 1.0 - math.sqrt(max(0.0, 1.0 - ((ends[1] - (z1 - z)) / ends[1]) ** 2)))
        k = 1.0 - 0.28 * e
        tp = top - (top - bot) * 0.22 * e
        pts = prof(cx, hw * k, tp, rh * (1.0 - 0.3 * e), n, expo, bot)
        rings.append([G(x, y, z) for (x, y) in pts])
    ring_loft(P, key, rings)


def run_x(P, key, x0, x1, z0, z1, top, rh, ends=(0.6, 0.6), n=12, expo=3.0, stations=8, bot=BOT):
    """The same along the game's x (the outstretched arm)."""
    cz, hw = (z0 + z1) * 0.5, (z1 - z0) * 0.5
    rings = []
    for i in range(stations + 1):
        x = x0 + (x1 - x0) * i / stations
        e = 0.0
        if ends[0] > 0.0 and x - x0 < ends[0]:
            e = 1.0 - math.sqrt(max(0.0, 1.0 - ((ends[0] - (x - x0)) / ends[0]) ** 2))
        if ends[1] > 0.0 and x1 - x < ends[1]:
            e = max(e, 1.0 - math.sqrt(max(0.0, 1.0 - ((ends[1] - (x1 - x)) / ends[1]) ** 2)))
        k = 1.0 - 0.28 * e
        pts = prof(cz, hw * k, top - (top - bot) * 0.22 * e, rh * (1.0 - 0.3 * e), n, expo, bot)
        rings.append([G(x, y, z) for (z, y) in pts][::-1])
    ring_loft(P, key, rings)


def band_z(P, key, x0, x1, z, top, w=0.5, out=0.18, rh=1.2, n=12):
    """A raised band of plate round a form along z (a greave's band, a lame's edge): a thin loft just proud of it."""
    cx, hw = (x0 + x1) * 0.5, (x1 - x0) * 0.5
    rings = []
    for zz in (z - w * 0.5, z + w * 0.5):
        rings.append([G(x, y, zz) for (x, y) in prof(cx, hw + out, top + out, rh, n, 3.0)])
    ring_loft(P, key, rings)


def band_x(P, key, z0, z1, x, top, w=0.5, out=0.18, rh=1.2, n=12):
    cz, hw = (z0 + z1) * 0.5, (z1 - z0) * 0.5
    rings = []
    for xx in (x - w * 0.5, x + w * 0.5):
        rings.append([G(xx, y, z) for (z, y) in prof(cz, hw + out, top + out, rh, n, 3.0)][::-1])
    ring_loft(P, key, rings)


def dome(P, key, c, rx, rz, h, n=14, rings=6, bot=0.0):
    """A cop of plate (a knee, a pauldron's crown): a half superellipsoid over the game's point c, rx across, rz along."""
    rs = []
    for j in range(rings + 1):
        t = j / rings
        y = c[1] + bot + h * math.sin(t * math.pi * 0.5)
        s = math.cos(t * math.pi * 0.5) ** 0.7
        rs.append([G(c[0] + math.cos(math.tau * i / n) * rx * max(s, 0.04), y, c[2] + math.sin(math.tau * i / n) * rz * max(s, 0.04))
                   for i in range(n)])
    ring_loft(P, key, rs)


def tube_path(P, key, pts, radii, n=8, squash=1.0):
    """A lofted tube through game points (a finger, a horn, a rib), its radius per point."""
    rings = []
    for i, p in enumerate(pts):
        a = pts[max(i - 1, 0)]
        b = pts[min(i + 1, len(pts) - 1)]
        d = (G(*b) - G(*a)).normalized()
        u = d.cross(Vector((0, 0, 1)))
        if u.length < 1e-4:
            u = d.cross(Vector((1, 0, 0)))
        u.normalize()
        v = d.cross(u).normalized()
        r = radii[i]
        c = G(*p)
        rings.append([c + (u * math.cos(math.tau * k / n) + v * math.sin(math.tau * k / n) * squash) * r for k in range(n)])
    ring_loft(P, key, rings)


def stud(P, c, r=0.32, h=0.3):
    cyl(P, "iron", G(c[0], c[1], c[2]), G(c[0], c[1] + h, c[2]), r, r * 0.7, seg=8)


# ------------------------------------------------------------------------------------------------- the legs and hips
def legs(P, rnd):
    for s in (-1.0, 1.0):
        x0, x1 = min(s * 1.4, s * 9.2), max(s * 1.4, s * 9.2)
        cx = (x0 + x1) * 0.5
        # the sabaton, toe up: a tall rounded foot (kit 6.4, its toe block to 7.6), the sole's edge at the feet's end
        run_z(P, "hewn", x0, x1, -42.0, -35.0, 7.6, 3.2, ends=(1.2, 0.4), n=14, expo=2.6)
        for j in range(4):                                   # the sabaton's lames across the instep
            band_z(P, "hewn", x0 + 0.3, x1 - 0.3, -39.6 + j * 1.05, 7.0 - 0.3 * j, w=0.4, out=0.14, rh=2.6)
        box(P, "hewn", G(cx, 1.0, -42.25), (x1 - x0 + 0.3, 0.6, 14.0))          # the sole's welt, standing on end
        # the greave over the shin (kit 4.6, its band 5.0 at -29 .. -27), the ankle's roll, a ridge down the shin
        run_z(P, "hewn", x0 + 0.2, x1 - 0.2, -35.2, -21.8, 4.6, 2.8, ends=(0.3, 0.0), n=14, expo=2.4)
        band_z(P, "hewn", x0, x1, -28.0, 4.7, w=2.0, out=0.3, rh=2.8)
        band_z(P, "hewn", x0 + 0.1, x1 - 0.1, -34.6, 4.5, w=0.5, out=0.22, rh=2.6)
        tube_path(P, "hewn", [(cx, 4.55, -34.5), (cx, 4.75, -30.0), (cx, 4.85, -25.0), (cx, 4.7, -22.4)], [0.28, 0.32, 0.3, 0.26], n=6)
        # the knee's cop (between the shin's 4.6 and the thigh's 7.4) with its side wings
        dome(P, "hewn", (cx, 3.0, -22.0), (x1 - x0) * 0.5 + 0.35, 2.4, 4.7, n=16, rings=6)
        for w in (-1.0, 1.0):
            dome(P, "hewn", (cx + w * ((x1 - x0) * 0.5 + 0.1), 2.5, -22.0), 0.5, 1.7, 2.6, n=10, rings=4)
        # the cuisse over the thigh (kit 6.8 and its slab to 7.4), lames at its top edge by the hip
        run_z(P, "hewn", x0 - 0.4, x1 + 0.4, -21.0, -9.8, 7.4, 3.0, ends=(0.8, 0.0), n=14, expo=2.6)
        for j in range(3):
            band_z(P, "hewn", x0 - 0.45, x1 + 0.45, -12.6 + j * 0.9, 7.42, w=0.45, out=0.12, rh=3.0)
    # the hips (kit 8.0 over x +-10.5) and their lames, the belt (8 .. 9) with its buckle and studs
    run_z(P, "hewn", -10.5, 10.5, -10.2, 0.2, 8.0, 3.0, ends=(0.0, 0.0), n=16, expo=3.0, stations=6)
    for j in range(3):
        band_z(P, "hewn", -10.6, 10.6, -9.4 + j * 1.15, 8.02, w=0.5, out=0.12, rh=3.0)
    run_z(P, "hewn", -11.0, 11.0, -6.05, -1.95, 9.0, 1.6, ends=(0.0, 0.0), n=16, expo=4.0, stations=2)
    for z in (-5.9, -2.1):
        band_z(P, "iron", -11.05, 11.05, z, 9.0, w=0.22, out=0.08, rh=1.6)
    for i in range(7):
        stud(P, (-9.0 + 3.0 * i, 9.0, -4.0), r=0.42, h=0.35)
    box(P, "iron", G(0.0, 9.15, -4.0), (2.4, 2.2, 0.35))
    box(P, "hewn", G(0.0, 9.3, -4.0), (1.4, 1.2, 0.3))


# ------------------------------------------------------------------------------------------------- the breastplate (the heart-hall)
def torso(P, rnd):
    fl = 0.3

    def flank_mask(east):
        wins = [3.0, 9.5, 16.0, 22.5] if not east else [3.0, 16.0, 22.5]

        def solid(u, v):
            for wz in wins:
                if L.rect_hole(u, v, wz, 1.3, 3.7 + 3.0, 6.0 + 3.0) or L.arch_hole(u, v, wz, 1.3, 6.0 + 3.0, 6.0 + 3.0):
                    return False
            if east:
                # the wound: z 6 .. 11, y 0.3 .. 4.6, its upper edge torn (stone by stone)
                rag = 0.55 * math.sin(u * 2.3) + 0.35 * math.sin(u * 5.1 + 1.0)
                if 6.0 < u < 11.0 and fl + 3.0 < v < 4.6 + 3.0 + rag:
                    return False
            return True
        return solid
    # the flanks (kit x 9..11 each side, 0 .. 26, top 11): coursed masonry, the slits and the wound cut in it
    for s, east in ((-1.0, False), (1.0, True)):
        L.wall_run(P, None, "ashlar", (s * 10.0, 0.0), (s * 10.0, -26.0), -3.0, 14.0, 2.0, flank_mask(east), rnd, ch=0.9, col=False,
                   blk=(1.4, 2.6), dress_ends=True)
    # the waist wall (kit z -0.5 .. 1) and the shoulder wall (26 .. 28), the full width
    L.wall_run(P, None, "ashlar", (-11.0, -0.25), (11.0, -0.25), -3.0, 14.0, 1.5, lambda u, v: True, rnd, ch=0.9, col=False,
               blk=(1.4, 2.6), dress_ends=True)
    L.wall_run(P, None, "ashlar", (-11.0, -27.0), (11.0, -27.0), -3.0, 14.0, 2.0, lambda u, v: True, rnd, ch=0.9, col=False,
               blk=(1.4, 2.6), dress_ends=True)
    # the wound's jambs (kit 5.6 .. 6 and 11 .. 11.4): broken plate edges, curled outward
    for z in (5.8, 11.2):
        tube_path(P, "hewn", [(11.1, 0.0, z), (11.4, 2.0, z), (11.3, 3.6, z + (0.3 if z < 8 else -0.3)), (10.9, 4.8, z)], [0.4, 0.42, 0.36, 0.3], n=7)
    # the deck: the kit's slabs y 10 .. 11 as great dressed slabs, the oculi and the stair's well left open
    slabs = [(-11.0, 11.0, 1.0, 3.0), (-11.0, -7.0, 3.0, 12.0), (-2.0, 11.0, 3.0, 12.0), (9.0, 11.0, 12.0, 26.0)]
    holes = [(1, 1), (3, 2), (2, 4)]
    for ci in range(5):
        for cj in range(5):
            if (ci, cj) in holes:
                continue
            hx = -9.0 + 4.0 * ci
            hz = 12.0 + 3.0 * cj
            slabs.append((hx - 2.0, hx + 2.0, hz, hz + 3.0))
    for (x0, x1, z0, z1) in slabs:
        # big slabs in a few pieces each so the deck reads as laid stone, not one sheet
        nx = max(1, int((x1 - x0) / 4.2 + 0.5))
        nz = max(1, int((z1 - z0) / 3.2 + 0.5))
        for i in range(nx):
            for j in range(nz):
                ax0 = x0 + (x1 - x0) * i / nx
                ax1 = x0 + (x1 - x0) * (i + 1) / nx
                az0 = z0 + (z1 - z0) * j / nz
                az1 = z0 + (z1 - z0) * (j + 1) / nz
                L.dbox(P, "ashlar", tuple(G((ax0 + ax1) * 0.5, 10.5, (az0 + az1) * 0.5)), (ax1 - ax0 - 0.04, az1 - az0 - 0.04, 1.0),
                       bevel=0.06, warp=0.02)
    # the oculi's rims: a raised ring of plate round each hole
    for (ci, cj) in holes:
        hx = -9.0 + 4.0 * ci
        hz = 12.0 + 3.0 * cj
        for (a, b) in (((hx - 2.0, hz), (hx + 2.0, hz)), ((hx + 2.0, hz), (hx + 2.0, hz + 3.0)), ((hx + 2.0, hz + 3.0), (hx - 2.0, hz + 3.0)),
                       ((hx - 2.0, hz + 3.0), (hx - 2.0, hz))):
            beam(P, "iron", G(a[0], 11.12, a[1]), G(b[0], 11.12, b[1]), 0.24, 0.24)
    # the breastplate's plate over the flanks: the rolled edge along the deck and the ribs (between the slits) down to the
    # ground, the plinth's roll at the foot
    for s in (-1.0, 1.0):
        tube_path(P, "hewn", [(s * 11.05, 10.85, z) for z in (-0.6, 6.0, 13.0, 20.0, 27.4)], [0.55] * 5, n=8)
        for z in (0.2, 6.2, 12.75, 19.25, 25.8):
            if s > 0 and 5.0 < z < 12.0:
                continue                     # the wound
            tube_path(P, "hewn", [(s * 11.0, 10.4, z), (s * 11.6, 8.0, z), (s * 11.85, 4.5, z), (s * 11.6, 1.0, z), (s * 11.2, -2.0, z)],
                      [0.5, 0.58, 0.62, 0.58, 0.5], n=7, squash=0.8)
    # the sill of the wound: dressed steps' landing stone outside (the kit's stair is the game's)
    L.dbox(P, "ashlar", tuple(G(10.0, -1.2, 8.5)), (2.0, 5.2, 3.0), bevel=0.05)


# ------------------------------------------------------------------------------------------------- the arms
def arms(P, rnd):
    # the left arm folded along the flank (kit x -17 .. -11, z 2 .. 20, top 7; the fist 18 .. 25 to 8.2)
    run_z(P, "hewn", -17.0, -11.0, 1.8, 19.0, 7.0, 3.0, ends=(1.4, 0.2), n=14, expo=2.6)
    dome(P, "hewn", (-14.0, 3.2, 2.6), 3.3, 2.0, 4.2, n=14)                  # the elbow's cop
    for z in (6.0, 13.0):
        band_z(P, "hewn", -17.05, -10.95, z, 7.0, w=0.6, out=0.16, rh=3.0)
    run_z(P, "hewn", -17.5, -10.5, 17.6, 25.2, 8.2, 2.4, ends=(0.6, 1.0), n=14, expo=3.0)      # the gauntlet's fist
    for i in range(4):                                                     # knuckles across its top
        dome(P, "hewn", (-16.6 + 1.75 * i, 7.7, 23.4), 0.8, 1.1, 0.9, n=10, rings=4)
    tube_path(P, "hewn", [(-10.6, 6.0, 19.0), (-10.0, 7.2, 21.5), (-10.4, 7.6, 24.0)], [0.9, 0.85, 0.7], n=8)   # its thumb
    # the right pauldron: the shoulder deck (kit 11 .. 18, z 17 .. 27, top 11) under three lames falling outward
    run_z(P, "hewn", 11.0, 18.0, 16.8, 27.2, 11.0, 2.6, ends=(0.4, 0.4), n=14, expo=3.4)
    for j in range(3):
        band_x(P, "hewn", 16.8 - 0.1 * j, 27.2 + 0.1 * j, 15.2 + 0.9 * j, 10.4 - 0.9 * j, w=0.8, out=0.2 + 0.1 * j, rh=2.6)
    # the upper arm (kit 18 .. 23, z 18.5 .. 26, top 8) and the elbow's cop
    run_x(P, "hewn", 17.8, 23.2, 18.5, 26.0, 8.0, 2.6, ends=(0.0, 0.0), n=12, expo=2.6)
    dome(P, "hewn", (23.0, 4.2, 22.25), 2.0, 4.2, 4.6, n=14)
    # the vambrace: the forearm bridge (kit 23 .. 34, top 9) and its rails along both edges (9 .. 9.9)
    run_x(P, "hewn", 23.0, 34.2, 18.5, 26.0, 9.0, 1.4, ends=(0.0, 0.0), n=12, expo=4.0)
    for z in (18.85, 25.65):
        tube_path(P, "hewn", [(x, 9.45, z) for x in (23.0, 26.0, 30.0, 34.2)], [0.42] * 4, n=7)
    for x in (25.0, 29.0, 33.0):
        band_x(P, "iron", 18.5, 26.0, x, 9.0, w=0.3, out=0.08, rh=1.4)
    # the gauntlet: the palm (kit 34 .. 46, z 14 .. 30, top 9), the thumb (34 .. 40, z 10 .. 14, 9.6)
    run_x(P, "hewn", 34.0, 46.2, 14.0, 30.0, 9.0, 1.8, ends=(0.0, 1.2), n=14, expo=3.2)
    run_x(P, "hewn", 34.0, 40.4, 9.8, 14.2, 9.6, 1.6, ends=(0.4, 1.4), n=10, expo=2.6)
    tube_path(P, "hewn", [(38.5, 8.6, 12.0), (41.0, 9.6, 11.6), (43.0, 10.6, 12.6)], [1.6, 1.3, 1.0], n=9)
    # four fingers curled up round the fire (kit 46 .. 53, each 3.2 wide, to 10.4/10.9; their tips to 12/11.6)
    for i in range(4):
        fz = 14.5 + 4.4 * i + 1.6
        tip = 12.0 - 0.4 * (i % 2)
        pts = [(45.0, 8.2, fz), (48.0, 9.0, fz), (50.5, 10.0, fz), (52.4, tip - 0.6, fz), (52.6, tip + 0.5, fz), (51.4, tip + 1.0, fz)]
        tube_path(P, "hewn", pts, [1.55, 1.55, 1.5, 1.4, 1.25, 0.9], n=10)
        for j in (1, 3):                                    # the knuckle joints: a lip of plate at each
            q = pts[j]
            d = (Vector(pts[j + 1]) - Vector(pts[j - 1])).normalized()
            tube_path(P, "hewn", [tuple(Vector(q) - d * 0.25), tuple(Vector(q) + d * 0.25)], [1.68, 1.62], n=10)
    # the fire basin on the palm (kit iron 3.4 x 0.9 at 41, 9, 22): a bronze bowl on three feet, its rim rolled
    bc = (41.0, 9.0, 22.0)
    rings = []
    for (r, y) in ((0.9, 0.25), (1.5, 0.45), (1.95, 0.85), (2.05, 1.1), (1.85, 1.12), (1.7, 0.75), (0.0, 0.7)):
        rings.append([G(bc[0] + math.cos(math.tau * k / 16) * r, bc[1] + y, bc[2] + math.sin(math.tau * k / 16) * r) for k in range(16)])
    ring_loft(P, "iron", rings)
    for k in range(3):
        a = math.tau * k / 3 + 0.4
        tube_path(P, "iron", [(bc[0] + math.cos(a) * 1.2, 9.5, bc[2] + math.sin(a) * 1.2), (bc[0] + math.cos(a) * 1.7, 9.05, bc[2] + math.sin(a) * 1.7)],
                  [0.18, 0.22], n=6)


# ------------------------------------------------------------------------------------------------- the neck and the great helm
def head(P, rnd):
    # the gorget: the neck (kit x +-5, z 28 .. 36, top 11) in rings of plate
    run_z(P, "hewn", -5.0, 5.0, 27.8, 36.2, 11.0, 2.8, ends=(0.0, 0.0), n=14, expo=2.6, stations=4)
    for j in range(4):
        band_z(P, "hewn", -5.1, 5.1, 29.0 + 2.0 * j, 11.0, w=0.6, out=0.18, rh=2.8)
    # the great helm lying face-up (kit x +-8, z 36 .. 52, top 14.2): a rounded skull, the face plate its top
    run_z(P, "hewn", -8.0, 8.0, 35.8, 52.2, 14.2, 4.0, ends=(0.6, 3.0), n=18, expo=2.8, stations=10)
    # the rim round the back and the sides (kit 14.2 .. 14.9), the front (the neck's side) open for the stair
    for s in (-1.0, 1.0):
        tube_path(P, "hewn", [(s * 8.05, 14.45, z) for z in (36.6, 42.0, 47.0, 50.5)] + [(s * 6.8, 14.45, 51.7)], [0.42] * 5, n=7)
    tube_path(P, "hewn", [(x, 14.45, 51.7) for x in (-6.8, -3.0, 0.0, 3.0, 6.8)], [0.42] * 5, n=7)
    # the visor: the nose ridge (kit 14.2 .. 15.6, x +-0.9, z 40 .. 46), the brows over the eyes, the cheek plates
    tube_path(P, "hewn", [(0.0, 14.4, 39.6), (0.0, 15.2, 41.5), (0.0, 15.55, 44.0), (0.0, 15.3, 46.4)], [0.75, 0.85, 0.8, 0.6], n=8, squash=0.7)
    for s in (-1.0, 1.0):
        tube_path(P, "hewn", [(s * 1.3, 14.85, 46.2), (s * 3.6, 15.05, 46.4), (s * 6.0, 14.75, 45.6)], [0.42, 0.45, 0.35], n=7)  # the brow
        tube_path(P, "hewn", [(s * 1.4, 14.5, 42.3), (s * 3.6, 14.6, 42.0), (s * 5.9, 14.45, 42.6)], [0.3, 0.32, 0.26], n=6)    # under the eye
        tube_path(P, "hewn", [(s * 6.2, 14.4, 39.0), (s * 7.4, 14.3, 43.0), (s * 6.6, 14.35, 47.5)], [0.3, 0.32, 0.28], n=6)    # the cheek
        for j in range(4):                                                    # the breaths: pierced slots in the cheek
            box(P, "iron", G(s * (4.3 + 0.5 * j), 14.22, 39.6), (0.18, 1.1, 0.06))
    # the mouth's grille (the kit's dark slab at z 37.2 .. 38, x +-3.5)
    box(P, "iron", G(0.0, 14.18, 37.6), (7.0, 0.8, 0.12))
    for j in range(9):
        box(P, "hewn", G(-3.2 + 0.8 * j, 14.32, 37.6), (0.22, 1.0, 0.3))
    # the crown: nine spikes from the helm's far end, faceted and leaning out (the kit's tubes)
    for i in range(9):
        a = math.pi * (0.12 + 0.76 * i / 8.0)
        base = (math.cos(a) * 6.6, 14.2, 50.0 - math.sin(a) * 3.0)
        hgt = 5.0 + 3.0 * abs(math.sin(i * 1.7)) + (3.0 if i % 2 == 0 else 0.0)
        tip = (base[0] + math.cos(a) * 1.2, base[1] + hgt, base[2])
        mid = (base[0] + math.cos(a) * 0.45, base[1] + hgt * 0.5, base[2] - 0.2)
        tube_path(P, "hewn", [(base[0], base[1] - 0.6, base[2]), base, mid, tip], [1.0, 0.92, 0.6, 0.06], n=5)
    # the two horns, sweeping out and up from the helm's sides (the kit's tubes from (+-8.4, 13, 41))
    for s in (-1.0, 1.0):
        hb = (s * 8.2, 13.0, 41.0)
        pts = [hb, (hb[0] + s * 2.2, hb[1] + 1.2, hb[2] + 0.6), (hb[0] + s * 4.4, hb[1] + 3.6, hb[2] + 1.6),
               (hb[0] + s * 5.8, hb[1] + 6.4, hb[2] + 2.6), (hb[0] + s * 6.4, hb[1] + 9.0, hb[2] + 3.0)]
        tube_path(P, "hewn", pts, [1.6, 1.35, 1.0, 0.6, 0.18], n=9)


# ------------------------------------------------------------------------------------------------- the ember seams and the flue
def embers(P, rnd):
    """(the polish pass, 20 Nov: from the road the colossus read as grey slabs and a brick box) Seams of ember laid in the plate:
    bands of lit lames (the `wax` set, drawn as the Sleeper's own embers in the game) round the shins, the cuisses and the arms, the
    gorget, and a great flue stacked on the deck over the heart so its chimney burns above the body: a silhouette and a light
    that read from the road."""
    for s in (-1.0, 1.0):
        x0, x1 = min(s * 1.4, s * 9.2), max(s * 1.4, s * 9.2)
        for z in (-33.4, -31.0, -25.6, -23.4):
            band_z(P, "wax", x0 + 0.05, x1 - 0.05, z, 4.6, w=0.3, out=0.26, rh=2.8)
        for z in (-19.4, -16.8, -14.2, -11.6):
            band_z(P, "wax", x0 - 0.45, x1 + 0.45, z, 7.4, w=0.3, out=0.18, rh=3.0)
    for z in (-8.6, -0.7):
        band_z(P, "wax", -10.55, 10.55, z, 8.0, w=0.3, out=0.2, rh=3.0)
    for z in (3.0, 9.5, 16.0):
        band_z(P, "wax", -17.05, -10.95, z, 7.0, w=0.3, out=0.22, rh=3.0)
    for x in (27.0, 31.0):
        band_x(P, "wax", 18.5, 26.0, x, 9.0, w=0.3, out=0.12, rh=1.4)
    for z in (29.9, 33.9):
        band_z(P, "wax", -5.1, 5.1, z, 11.0, w=0.3, out=0.2, rh=2.8)
    # the flue: a stack of dressed courses on the deck's solid slabs (x 3 .. 7, z 12 .. 15 in the game's frame), tapering from
    # 3.4 to 2.3 m over 13 m, with a corbelled collar, a lit band and a flared crown
    cx, cz = 5.0, 13.5
    y0, courses, ch = 11.0, 12, 1.1
    for i in range(courses):
        t = i / (courses - 1)
        w = 3.4 - 1.1 * t
        L.dbox(P, "ashlar", tuple(G(cx, y0 + ch * (i + 0.5), cz)), (w, w, ch - 0.04), bevel=0.08, warp=0.03)
    ytop = y0 + ch * courses
    yy = ytop
    for (w, h) in ((2.9, 0.4), (3.3, 0.4), (3.7, 0.5)):
        L.dbox(P, "ashlar", tuple(G(cx, yy + h * 0.5, cz)), (w, w, h), bevel=0.05)
        yy += h
    for yb in (y0 + 3.2, y0 + 7.4):
        wb = 3.4 - 1.1 * (yb - y0) / (courses * ch) + 0.5
        box(P, "iron", G(cx, yb, cz), (wb, wb, 0.35))
    # the lit mouth: a band of ember under the crown on all four faces and a glowing slot down each
    wm = 2.3 + 0.55
    for sx, sz in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        box(P, "wax", G(cx + sx * (wm * 0.5), ytop - 0.55, cz + sz * (wm * 0.5)), (0.12 if sx else 1.5, 1.5 if sx else 0.12, 0.9))
        box(P, "wax", G(cx + sx * (wm * 0.5 + 0.02), ytop - 3.2, cz + sz * (wm * 0.5 + 0.02)), (0.1 if sx else 0.5, 0.5 if sx else 0.1, 3.4))


def asset():
    reset()
    P = Parts()
    rnd = L.rnd_for(3901)
    L.mason_begin(3901)
    legs(P, rnd)
    torso(P, rnd)
    arms(P, rnd)
    head(P, rnd)
    embers(P, rnd)
    objs = finish(P, "Sleeper", smooth_keys=("hewn",)) + L.mason_end("SleeperMasonry")
    print("SLEEPER %d tris" % sum(tris(o) for o in objs))
    export(objs, os.path.join(MODELS, "wonder_sleeper.glb"), "sleeper")
    preview(objs, "sleeper", [((70, 40, 45), (12, -5, 6), 28), ((-60, -70, 40), (10, -5, 6), 28), ((40, -95, 30), (10, -20, 8), 30),
                              ((14, -62, 22), (0, -44, 12), 30), ((-30, 30, 30), (0, -15, 8), 30), ((30, -10, 26), (0, -14, 10), 26)])
    L.bake_blend("wonder_sleeper")


asset()
