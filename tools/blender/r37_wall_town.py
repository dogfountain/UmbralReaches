"""What a town grows against the March Wall (r37_wall.py build()): Weirford's stair up the face of the wall and a lean-to shed.

WallStair   in the frame of WallSeg_D (x along the wall, +z the outer face, y up from the ground): the stair's top step meets the
            landing of the stair bay at x = 2.3 and it falls away to +x on a solid stone stair with an outer wall and piers
WallShed    a timber lean-to against the wall's foot, local origin on the wall's outer face line (z = 0 at the face), x along the wall
"""
import math
import r37_wall as RW
from r37_wall_lib import W, rng, lerp


STAIR_N = 28              # steps
STAIR_RUN = 0.24
STAIR_W = 2.6             # between the side walls
STAIR_EDGE = 3.7          # in the frame of WallSeg_D: where the landing's outer edge is (the stair's top step meets it)


def stair(mats):
    """In its own frame: the flight runs along +x from its top step at x = 0 (height WALK) down to the foot at x = N * run, its
    width along z (centred), the two side walls outside it. Place with +x turned to the bay's +z, at z = STAIR_EDGE."""
    T = RW.tints()
    b = W("WallStair", mats, 900, damp=1.2)
    H = RW.WALK
    n = STAIR_N
    rise = H / n
    run = STAIR_RUN
    L = n * run
    hw = STAIR_W / 2
    pts = [(0.0, -1.5), (0.0, H)]
    for i in range(n):
        y = H - i * rise
        pts.append((i * run, y))
        pts.append(((i + 1) * run, y))
        if i < n - 1:
            pts.append(((i + 1) * run, y - rise))
    pts.append((L, -1.5))
    b.poly_z(_dedupe(pts), -hw, hw, "stone", uv=1.2, tint=T["plain"], jit=0.0)
    for sg in (-1, 1):
        z0, z1 = (hw, hw + 0.5) if sg > 0 else (-hw - 0.5, -hw)
        # the side walls: a parapet whose top steps down with the treads (so the flight reads), on a solid body
        ow = [(0.0, -1.5), (0.0, H + 0.95)]
        for i in range(n):
            y = H - i * rise + 0.95
            ow.append((i * run, y))
            ow.append(((i + 1) * run, y))
            if i < n - 1:
                ow.append(((i + 1) * run, y - rise))
        ow += [(L, -1.5)]
        b.poly_z(_dedupe(ow), z0, z1, "stone", uv=1.1, tint=T["plain"], jit=0.0)
        zf = z1 if sg > 0 else z0
        # blind arches in the outer faces: the flight rides on an arcade, bigger where it is high
        for (xa, wa, sa) in ((1.3, 1.9, 2.3), (3.6, 1.6, 1.7), (5.4, 1.2, 0.9)):
            def arcade(xa=xa, wa=wa, sa=sa, sg=sg):
                b.poly_z(RW.arch_poly(0.0, sa, wa, 0.0), -0.03, 0.04, "dark", uv=1.0)
                b.arch(0.0, sa, wa, 0.3, -0.03, 0.12, "stone", uv=1.6, n=5, tint=T["pale"], seed=7, jit=0.006, alt=0.03)
                for sx in (-1, 1):
                    b.box((sx * (wa / 2 + 0.15), sa / 2, 0.045), (0.3, sa, 0.15), "stone", uv=1.6, tint=T["pale"], jit=0.006, cuts=0)
            # built facing +z at the origin; turned to face the side wall's outer face and put at x = xa
            _face(b, arcade, sg, xa, zf)
        # piers and a ball at the foot
        for xp in (2.4, 4.5, 6.2):
            top = H + 0.95 - xp * (H / L)
            b.box((xp, (top - 1.5) / 2, zf + sg * 0.17), (0.7, top + 1.5, 0.34), "stone", uv=1.2, tint=T["pale"], jit=0.01, cuts=1)
            b.box((xp, top + 0.05, zf + sg * 0.17), (0.86, 0.2, 0.5), "stone", uv=1.6, tint=T["pale"], jit=0.0)
        b.box((L + 0.2, 0.7, sg * (hw + 0.25)), (0.8, 1.4, 0.8), "stone", uv=1.4, tint=T["pale"], jit=0.01, cuts=1)
        b.box((L + 0.2, 1.5, sg * (hw + 0.25)), (0.98, 0.2, 0.98), "stone", uv=1.6, tint=T["pale"], jit=0.0)
        b.box((L + 0.2, 1.75, sg * (hw + 0.25)), (0.5, 0.3, 0.5), "stone", uv=1.6, tint=T["pale"], jit=0.0, yaw=0.0)
    # a lantern bracket at the middle of the flight on the right wall (iron, the lamp's hook)
    b.box((L * 0.5, H * 0.5 + 0.95 + 0.3, hw + 0.25), (0.06, 0.06, 0.6), "iron")
    return b.finish()


def _face(b, fn, sg, x, z):
    """Build fn (facing +z at the origin) on the side wall's outer face: facing +z for sg > 0, -z for sg < 0, at x."""
    RW.grouped(b, fn, 0.0 if sg > 0 else math.pi, (x, 0.0, z))


def _dedupe(pts):
    out = []
    for p in pts:
        if not out or abs(out[-1][0] - p[0]) > 1e-6 or abs(out[-1][1] - p[1]) > 1e-6:
            out.append(p)
    return out


SHED_L = 7.4              # along the wall
SHED_D = 3.3              # out from the wall's face
SHED_HB = 4.1             # the roof meets the wall here
SHED_HF = 2.75            # the front eave


def shed(mats):
    T = RW.tints()
    b = W("WallShed", mats, 950, damp=0.6)
    L = SHED_L
    z_back = 0.0
    z_front = SHED_D
    r = rng(950)
    # footings under the posts, a plank floor
    b.box((0, 0.05, z_front / 2 + 0.1), (L, 0.12, z_front), "wood", uv=1.2, jit=0.0, cuts=0, tint=(0.8, 0.8, 0.8))
    posts = [-3.4, -1.7, 0.0, 1.7, 3.4]
    for x in posts:
        b.box((x, -0.3, z_front), (0.5, 1.4, 0.5), "stone", uv=1.0, tint=T["damp"], jit=0.02, cuts=0)
        b.box((x, SHED_HF / 2 + 0.4, z_front), (0.24, SHED_HF, 0.24), "wood", uv=1.0, jit=0.01, cuts=0)
    b.box((0, SHED_HF + 0.4 + 0.13, z_front), (L + 0.5, 0.26, 0.32), "wood", uv=1.0, jit=0.01, cuts=0)       # front plate
    b.box((0, SHED_HB + 0.15, z_back + 0.13), (L + 0.5, 0.3, 0.26), "wood", uv=1.0, jit=0.01, cuts=0)       # back plate, spiked to the wall
    # rafters and the roof's boards
    hy = SHED_HB + 0.1 - (SHED_HF + 0.55)
    dz = z_front + 0.55 - 0.0
    ln = math.hypot(hy, dz)
    pitch = math.atan2(hy, dz)
    for k in range(9):
        x = -L / 2 - 0.1 + k * (L + 0.2) / 8
        b.box((x, (SHED_HB + 0.1 + SHED_HF + 0.55) / 2 + 0.1, dz / 2), (0.14, 0.18, ln + 0.1), "wood", uv=1.0, pitch=pitch, jit=0.0, cuts=0)
    b.box((0, (SHED_HB + 0.1 + SHED_HF + 0.55) / 2 + 0.24, dz / 2 + 0.05), (L + 0.8, 0.1, ln + 0.5), "wood", uv=1.1, pitch=pitch, jit=0.0, cuts=0, tint=(0.9, 0.9, 0.9))
    # battens down the slope
    for k in range(10):
        x = -L / 2 - 0.2 + k * (L + 0.4) / 9
        b.box((x, (SHED_HB + 0.1 + SHED_HF + 0.55) / 2 + 0.3, dz / 2 + 0.05), (0.09, 0.07, ln + 0.55), "wood", uv=1.0, pitch=pitch, jit=0.0, cuts=0, tint=(0.75, 0.75, 0.75))
    # lead flashing where the roof meets the wall
    b.box((0, SHED_HB + 0.34, z_back + 0.05), (L + 0.8, 0.07, 0.5), "iron", pitch=pitch)
    # the left end closed with planks, the right end open
    prof = [(z_back, 0.0), (z_front + 0.2, 0.0), (z_front + 0.2, SHED_HF + 0.4), (z_back, SHED_HB)]
    b.prism_x(prof, -L / 2 - 0.05, -L / 2 + 0.1, "wood", uv=1.1, tint=(0.85, 0.85, 0.85), jit=0.0, dens=3.0, xstep=1.0)
    # what the shed keeps: a woodpile, crates, a bench, a coil of rope on a peg
    for row in range(4):
        for k in range(5 - row):
            b.box((-L / 2 + 0.9 + k * 0.34 + row * 0.17, 0.2 + row * 0.3, 0.55), (0.3, 0.3, 1.5), "wood", uv=0.9, jit=0.01, cuts=0, yaw=r.uniform(-0.05, 0.05), tint=(0.8, 0.78, 0.75))
    b.box((1.9, 0.4, 0.7), (0.9, 0.8, 0.8), "wood", uv=1.1, jit=0.01, cuts=0, yaw=0.15)
    b.box((2.9, 0.3, 0.7), (0.7, 0.6, 0.7), "wood", uv=1.1, jit=0.01, cuts=0, yaw=-0.2)
    b.box((2.2, 1.0, 0.65), (0.6, 0.45, 0.6), "wood", uv=1.1, jit=0.01, cuts=0, yaw=0.5)
    b.box((0.6, 0.45, 2.3), (2.0, 0.1, 0.5), "wood", uv=1.1, jit=0.01, cuts=0)
    for xs in (-0.3, 1.5):
        b.box((xs, 0.22, 2.3), (0.12, 0.44, 0.4), "wood", uv=1.0, jit=0.0, cuts=0)
    return b.finish()
