"""Ground models for dropped loot, by script: tools/blender/run.sh loot_props.py

  art/models/loot_props.glb   one mesh per thing lying on the ground, resting on y=0 (Godot metres):
    gear     OrbFocus (a glass orb in a metal cradle), Vestment (a folded stole with a hem and clasp),
             Lantern (a small horn-glass lantern, unlit), Girdle (a coiled belt with a buckle and cord)
    kinds    Pouch (materials), Reliquary (relics), Crystal (cores), Ring (charms)
    trophies Fist, Tablet, Branch, Stone, Mask, Crown, Sigil

Materials are named so the game can dress them (core/items/loot_model.gd): LP_Trim is recoloured to the
drop's quality, LP_Gem is the glass or jewel (quality coloured, a faint glow for the rare), LP_Tint*
take the item's own tint (trophies). Everything else keeps its baked colour. Textures are generated
here (256 px tiles, no downloads): albedo, a normal map from a height field, and ORM.
"""
import sys
import os
import math

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import bmesh
import r37_south_lib as L
from r37_south_lib import B, Matrix, Vector, np, fbm, smooth, tint, hash3

N = 256


def tex_cloth(seed, lo, hi, weave=48, contrast=0.55):
    yy, xx = np.mgrid[0:N, 0:N]
    cx = np.floor(xx / N * weave)
    cy = np.floor(yy / N * weave)
    warp = 0.5 + 0.5 * np.sin(xx / N * math.tau * weave)
    weft = 0.5 + 0.5 * np.sin(yy / N * math.tau * weave)
    h = np.where((cx + cy) % 2 == 0, warp, weft) * 0.55 + 0.45 * fbm(N, 2.2, seed)
    tone = np.clip(0.5 + contrast * (h - 0.5) + 0.35 * (fbm(N, 2.0, seed + 1) - 0.5), 0, 1)
    return tint(tone, lo, hi), h, np.clip(0.88 + 0.1 * (fbm(N, 1.8, seed + 2) - 0.5), 0.6, 1.0)


def tex_leather(seed, lo, hi):
    f = fbm(N, 2.3, seed)
    h = 0.6 * (1.0 - np.abs(2.0 * f - 1.0)) + 0.4 * fbm(N, 1.6, seed + 1)
    tone = np.clip(0.45 + 0.7 * (h - 0.5) + 0.3 * (fbm(N, 2.6, seed + 2) - 0.5), 0, 1)
    scuff = smooth(fbm(N, 2.0, seed + 3), 0.62, 0.85)
    alb = np.clip(tint(tone, lo, hi) * (1.0 + 0.2 * scuff[..., None]), 0, 1)
    return alb, h, np.clip(0.62 + 0.25 * scuff + 0.1 * (h - 0.5), 0.4, 1.0)


def tex_metal(seed, lo, hi):
    pit = smooth(fbm(N, 1.4, seed), 0.72, 0.9)
    scratch = smooth(fbm(N, 2.0, seed + 1, aniso=14.0), 0.62, 0.85)
    h = np.clip(0.6 - 0.35 * pit - 0.1 * scratch + 0.15 * (fbm(N, 2.6, seed + 2) - 0.5), 0, 1)
    tone = np.clip(0.55 + 0.35 * (fbm(N, 2.4, seed + 3) - 0.5) + 0.25 * scratch - 0.3 * pit, 0, 1)
    rough = np.clip(0.38 + 0.3 * pit + 0.1 * (fbm(N, 2.0, seed + 4) - 0.5) - 0.12 * scratch, 0.2, 0.9)
    return tint(tone, lo, hi), h, rough


def tex_bone(seed, lo, hi):
    veins = 1.0 - np.abs(2.0 * fbm(N, 2.6, seed, aniso=3.0) - 1.0)
    f = fbm(N, 2.0, seed + 1)
    tone = np.clip(0.55 + 0.4 * (f - 0.5) - 0.25 * smooth(veins, 0.85, 1.0), 0, 1)
    return tint(tone, lo, hi), 0.5 * veins + 0.5 * f, np.clip(0.55 + 0.2 * (f - 0.5), 0.3, 1.0)


def tex_wood(seed, lo, hi):
    g = fbm(N, 2.6, seed, aniso=12.0)
    yy = np.arange(N)[:, None] * np.ones((1, N))
    rings = 0.5 + 0.5 * np.sin((yy / N * 9.0 + 2.5 * g) * math.tau)
    tone = np.clip(0.35 + 0.5 * (rings - 0.5) + 0.3 * (g - 0.5), 0, 1)
    return tint(tone, lo, hi), 0.5 * rings + 0.5 * g, np.clip(0.8 + 0.1 * (g - 0.5), 0.5, 1.0)


def tex_stone(seed, lo, hi):
    a = fbm(N, 2.6, seed)
    b = fbm(N, 1.5, seed + 1)
    pit = smooth(fbm(N, 1.3, seed + 2), 0.7, 0.9)
    tone = np.clip(0.5 + 0.5 * (b - 0.5) + 0.3 * (a - 0.5) - 0.3 * pit, 0, 1)
    return tint(tone, lo, hi), np.clip(0.55 * a + 0.35 * b - 0.3 * pit, 0, 1), np.clip(0.8 + 0.15 * (a - 0.5), 0.5, 1.0)


def mats():
    P = L.pbr
    m = {}
    m["wool"] = P("LP_Wool", tex_cloth(11, (0.10, 0.095, 0.095), (0.27, 0.25, 0.24), 96, 0.22), 0.9)
    m["thread"] = P("LP_Thread", tex_cloth(15, (0.55, 0.55, 0.55), (1.0, 1.0, 1.0), 96, 0.3), 1.0)
    m["leather"] = P("LP_Leather", tex_leather(21, (0.07, 0.045, 0.03), (0.30, 0.19, 0.11)), 1.5)
    m["iron"] = P("LP_Iron", tex_metal(31, (0.05, 0.05, 0.055), (0.2, 0.2, 0.21)), 1.6, 0.85)
    m["trim"] = P("LP_Trim", tex_metal(41, (0.5, 0.5, 0.5), (0.95, 0.95, 0.95)), 1.4, 0.9)
    m["bone"] = P("LP_Bone", tex_bone(51, (0.5, 0.46, 0.38), (0.88, 0.83, 0.72)), 1.2)
    m["tstone"] = P("LP_TintStone", tex_stone(61, (0.45, 0.45, 0.45), (1.0, 1.0, 1.0)), 2.6)
    m["twood"] = P("LP_TintWood", tex_wood(71, (0.5, 0.5, 0.5), (1.0, 1.0, 1.0)), 2.0)
    m["tmetal"] = P("LP_TintMetal", tex_metal(81, (0.55, 0.55, 0.55), (1.0, 1.0, 1.0)), 1.6, 0.85)
    m["tcloth"] = P("LP_TintCloth", tex_cloth(91, (0.5, 0.5, 0.5), (1.0, 1.0, 1.0), 32), 2.2)
    m["gem"] = L.flat("LP_Gem", (0.55, 0.7, 0.85), 0.06, 0.0)
    m["dark"] = L.flat("LP_Dark", (0.012, 0.011, 0.013), 0.9)
    return m


# --- geometry helpers (Godot coordinates: y up) -----------------------------------------------------

def rot(yaw=0.0, pitch=0.0, roll=0.0):
    return Matrix.Rotation(yaw, 3, 'Y') @ Matrix.Rotation(pitch, 3, 'X') @ Matrix.Rotation(roll, 3, 'Z')


def xf(R, c, p):
    return R @ Vector(p) + Vector(c)


def settle(b, R):
    """Turn the whole mesh by R about the origin, then drop it to rest on y = 0."""
    for v in b.bm.verts:
        v.co = R @ v.co
    lo = min(v.co.y for v in b.bm.verts)
    for v in b.bm.verts:
        v.co.y -= lo


def pillow(b, c, w, d, h, mat, R=None, n=20, expo=3.2, uv=3.0, prof=((0.0, 0.9), (0.15, 0.99), (0.5, 1.0), (0.85, 0.99), (1.0, 0.9))):
    """A soft slab: a superellipse outline lofted through a rounded profile, y from c.y up by h."""
    R = R or Matrix.Identity(3)
    rings = []
    for (t, s) in prof:
        ring = []
        for j in range(n):
            a = -math.tau * j / n
            ca, sa = math.cos(a), math.sin(a)
            x = math.copysign(abs(ca) ** (2.0 / expo), ca) * w * 0.5 * s
            z = math.copysign(abs(sa) ** (2.0 / expo), sa) * d * 0.5 * s
            ring.append(xf(R, c, (x, t * h, z)))
        rings.append(ring)
    b.loft(rings, mat, closed=True, cap_start=True, cap_end=True, smooth=True, box_uv=uv)


def torus(b, c, big, small, mat, R=None, seg=22, sides=8, uv=3.0):
    R = R or Matrix.Identity(3)
    rings = []
    for i in range(seg + 1):
        a = math.tau * (i % seg) / seg
        ring = []
        for j in range(sides):
            t = -math.tau * j / sides
            rr = big + math.cos(t) * small
            ring.append(xf(R, c, (math.cos(a) * rr, math.sin(t) * small, math.sin(a) * rr)))
        rings.append(ring)
    b.loft(rings, mat, closed=True, smooth=True, box_uv=uv)


def sphere(b, c, r, mat, sides=14, rings_n=9, sy=1.0, uv=3.0):
    rings = []
    for i in range(1, rings_n):
        t = math.pi * i / rings_n
        ring = []
        for j in range(sides):
            a = -math.tau * j / sides
            ring.append(Vector(c) + Vector((math.sin(t) * math.cos(a) * r, math.cos(t) * r * sy, math.sin(t) * math.sin(a) * r)))
        rings.append(ring)
    b.loft(rings, mat, closed=True, cap_start=True, cap_end=True, smooth=True, box_uv=uv)


def band(b, path, width, thick, mat, uv=3.0):
    """A flat strap along a list of (x, y, z) points: `width` across the way in the ground plane, `thick` up."""
    rings = []
    n = len(path)
    for i, p in enumerate(path):
        p = Vector(p)
        t = Vector(path[min(i + 1, n - 1)]) - Vector(path[max(i - 1, 0)])
        t.y = 0.0
        t.normalize()
        side = Vector((-t.z, 0.0, t.x))
        hw = width * 0.5
        ht = thick * 0.5
        rings.append([p + side * hw + Vector((0, -ht, 0)), p + side * hw * 0.96 + Vector((0, ht, 0)), p - side * hw * 0.96 + Vector((0, ht, 0)), p - side * hw + Vector((0, -ht, 0))])
    b.loft(rings, mat, closed=True, cap_start=True, cap_end=True, smooth=False, box_uv=uv)


def finish(b):
    return b.finish(recalc=True)


# --- the four gear slots -----------------------------------------------------------------------------

def orb_focus(M):
    b = B("OrbFocus", M)
    # a footed cup, three claws that close over the orb, a band round its shoulder; lying on its side
    b.lathe([(0.001, 0.0), (0.060, 0.0), (0.066, 0.012), (0.046, 0.026), (0.030, 0.034), (0.052, 0.062), (0.060, 0.078)], "iron", sides=16, bark=0.4)
    b.lathe([(0.062, 0.074), (0.068, 0.082), (0.060, 0.090)], "trim", sides=16, bark=0.4)
    for k in range(3):
        a = math.tau * k / 3 + 0.3
        ca, sa = math.cos(a), math.sin(a)
        pts = [(ca * 0.058, 0.08, sa * 0.058), (ca * 0.088, 0.13, sa * 0.088), (ca * 0.094, 0.19, sa * 0.094), (ca * 0.058, 0.255, sa * 0.058)]
        b.tube_path(pts, [0.009, 0.0075, 0.0075, 0.005], "iron", sides=6, bark=0.3)
        b.tube((ca * 0.058, 0.255, sa * 0.058), (ca * 0.050, 0.268, sa * 0.050), 0.007, 0.011, "trim", sides=6, bark=0.3)
    torus(b, (0, 0.205, 0), 0.097, 0.006, "trim", seg=22, sides=6, uv=2.0)
    sphere(b, (0, 0.165, 0), 0.098, "gem", sides=18, rings_n=11)
    settle(b, rot(0.3, 0.0, 0.42))
    return finish(b)


def vestment(M):
    b = B("Vestment", M)
    layers = [(0.56, 0.38, 0.030, 0.0, 0.0), (0.52, 0.36, 0.030, 0.05, 0.012), (0.54, 0.34, 0.030, -0.04, -0.01), (0.46, 0.32, 0.034, 0.07, 0.01)]
    y = 0.0
    for (w, d, h, yaw, ox) in layers:
        R = rot(yaw)
        pillow(b, (ox, y, 0.0), w, d, h, "wool", R, n=24, expo=4.0, uv=2.2)
        # the hem: a woven band round the front edge of each fold, in the quality colour
        b.box(tuple(xf(R, (ox, y + h * 0.5, 0), (0, 0, d * 0.5 - 0.002))), (w * 0.78, h * 0.7, 0.009), "thread", yaw=R.to_euler('XYZ').y, scale_uv=6.0)
        y += h * 0.92
    top = y
    # the collar rolled along the back
    b.tube((-0.19, top + 0.032, -0.10), (0.19, top + 0.034, -0.10), 0.034, 0.034, "wool", sides=10, bark=0.3)
    # the clasp: a disc with a jewel, and a short chain to its pin
    b.lathe([(0.001, top + 0.034), (0.048, top + 0.034), (0.052, top + 0.042), (0.038, top + 0.054), (0.001, top + 0.058)], "trim", sides=16, bark=0.4)
    sphere(b, (0, top + 0.062, 0), 0.022, "gem", sides=10, rings_n=6)
    b.tube((0.048, top + 0.042, 0.0), (0.150, top + 0.036, 0.018), 0.006, 0.006, "iron", sides=5, bark=0.3)
    b.lathe([(0.001, top + 0.030), (0.036, top + 0.030), (0.038, top + 0.037), (0.001, top + 0.042)], "trim", sides=12, bark=0.4)
    # the loose end of the stole trailing onto the ground, with a hem and tassels
    band(b, [(0.20, 0.016, 0.16), (0.30, 0.012, 0.26), (0.34, 0.010, 0.38), (0.30, 0.009, 0.50)], 0.10, 0.018, "wool")
    band(b, [(0.26, 0.0095, 0.495), (0.34, 0.0095, 0.51)], 0.03, 0.019, "thread")
    for k in range(4):
        x = 0.27 + 0.02 * k
        b.tube((x, 0.011, 0.52), (x + 0.01 * (k - 1.5), 0.008, 0.60 + 0.01 * (k % 2)), 0.008, 0.005, "thread", sides=5, bark=0.3)
    settle(b, rot(0.0))
    return finish(b)


def lantern(M):
    b = B("Lantern", M)
    # base, hex glass, six posts, a cap with a ring handle, a candle stub inside; unlit, on its side
    b.lathe([(0.001, 0.0), (0.070, 0.0), (0.074, 0.012), (0.062, 0.026), (0.001, 0.026)], "iron", sides=6, bark=0.4)
    b.lathe([(0.001, 0.026), (0.052, 0.026), (0.047, 0.19), (0.001, 0.19)], "gem", sides=6, bark=0.4)
    for k in range(6):
        a = math.tau * k / 6
        ca, sa = math.cos(a), math.sin(a)
        b.tube((ca * 0.064, 0.02, sa * 0.064), (ca * 0.055, 0.206, sa * 0.055), 0.0075, 0.0065, "iron", sides=5, bark=0.3)
    b.lathe([(0.001, 0.19), (0.062, 0.19), (0.066, 0.202), (0.040, 0.230), (0.016, 0.246), (0.001, 0.248)], "iron", sides=6, bark=0.4)
    b.lathe([(0.012, 0.246), (0.016, 0.254), (0.012, 0.262)], "trim", sides=8, bark=0.4)
    torus(b, (0, 0.285, 0), 0.036, 0.0065, "iron", rot(0, 1.5708, 0), seg=16, sides=5, uv=2.0)
    b.lathe([(0.001, 0.026), (0.017, 0.026), (0.015, 0.100), (0.001, 0.104)], "bone", sides=8, bark=0.3)
    # a bright strap round the drum, so the quality shows from the side
    b.lathe([(0.0555, 0.098), (0.0575, 0.100), (0.0575, 0.116), (0.0555, 0.118)], "trim", sides=6, bark=0.4)
    settle(b, rot(0.6, 0.0, 1.5708 + 0.12))
    return finish(b)


def girdle(M):
    b = B("Girdle", M)
    # a belt in a flat coil: the buckle on the outer end, the tail turned inside
    pts = []
    turns = 1.6
    steps = 56
    for i in range(steps + 1):
        t = i / steps
        a = -math.tau * turns * t + 0.4
        r = 0.19 - 0.075 * t
        pts.append((math.cos(a) * r, 0.008 + 0.022 * turns * t, math.sin(a) * r))
    band(b, pts, 0.052, 0.014, "leather", uv=3.4)
    for i in range(3, 26, 4):
        x, y, z = pts[i]
        b.tube((x, y + 0.004, z), (x, y + 0.0125, z), 0.0085, 0.0075, "trim", sides=8, bark=0.3)
    # the buckle at the start: a frame, a bar and the tongue, in the belt's own frame
    x, y, z = pts[0]
    t = (Vector(pts[1]) - Vector(pts[0]))
    t.y = 0.0
    t.normalize()
    c = Vector((x, y, z)) - t * 0.04
    ang = math.atan2(t.x, t.z)
    Rb = rot(ang)
    for (dx, dz, sx, sz) in ((0.0, -0.038, 0.080, 0.013), (0.0, 0.038, 0.080, 0.013), (0.038, 0.0, 0.013, 0.076), (-0.038, 0.0, 0.013, 0.076)):
        b.box(tuple(xf(Rb, c, (dx, 0.015, dz))), (sx, 0.016, sz), "trim", yaw=ang, scale_uv=3.0)
    b.box(tuple(xf(Rb, c, (0.0, 0.019, -0.002))), (0.008, 0.010, 0.068), "trim", yaw=ang, scale_uv=3.0)
    # the cord, knotted, with a tassel pair, lying out on the ground
    ox, oy, oz = pts[-1]
    b.tube_path([(ox, 0.03, oz), (0.10, 0.012, 0.26), (0.20, 0.010, 0.30), (0.30, 0.009, 0.25)], [0.011, 0.010, 0.010, 0.009], "thread", sides=6, bark=0.3)
    sphere(b, (0.20, 0.016, 0.30), 0.024, "thread", sides=8, rings_n=5)
    b.tube((0.30, 0.009, 0.25), (0.40, 0.008, 0.20), 0.011, 0.006, "thread", sides=5, bark=0.3)
    b.tube((0.30, 0.009, 0.25), (0.39, 0.008, 0.29), 0.011, 0.006, "thread", sides=5, bark=0.3)
    settle(b, rot(0.0, 0.05, 0.03))
    return finish(b)


# --- kinds and trophy shapes ---------------------------------------------------------------------------

def pouch(M):
    b = B("Pouch", M)
    prof = [(0.001, 0.0), (0.09, 0.012), (0.128, 0.06), (0.105, 0.115), (0.056, 0.15), (0.030, 0.168), (0.058, 0.205), (0.050, 0.235)]
    b.lathe(prof, "tcloth", sides=16, bark=0.35, jit=lambda an, y: 1.0 + 0.07 * hash3(math.cos(an) * 2, y * 9, math.sin(an) * 2, 5))
    torus(b, (0, 0.168, 0), 0.036, 0.007, "trim", seg=14, sides=5, uv=2.0)
    b.tube_path([(0.034, 0.165, 0.0), (0.09, 0.07, 0.07), (0.15, 0.012, 0.12), (0.20, 0.008, 0.13)], [0.005, 0.005, 0.005, 0.004], "thread", sides=5, bark=0.3)
    settle(b, rot(0.0, 0.0, 1.0))
    return finish(b)


def reliquary(M):
    b = B("Reliquary", M)
    w, d, h = 0.30, 0.17, 0.11
    b.box((0, h * 0.5, 0), (w, h, d), "twood", cuts=1, scale_uv=2.4)
    # a pitched lid: two sloped planes and two gable ends
    hx, hz = w * 0.5 + 0.008, d * 0.5 + 0.008
    ix, iz = w * 0.5 - 0.02, d * 0.5 * 0.62 + 0.008
    pk = h + 0.05
    uvs = [(0, 0), (1, 0), (1, 1), (0, 1)]
    b.face([(-hx, h, -hz), (-hx, h, hz), (-ix, pk, iz), (-ix, pk, -iz)], "twood", uvs=uvs)
    b.face([(hx, h, hz), (hx, h, -hz), (ix, pk, -iz), (ix, pk, iz)], "twood", uvs=uvs)
    b.face([(-hx, h, -hz), (-ix, pk, -iz), (ix, pk, -iz), (hx, h, -hz)], "twood", uvs=uvs)
    b.face([(hx, h, hz), (ix, pk, iz), (-ix, pk, iz), (-hx, h, hz)], "twood", uvs=uvs)
    b.face([(-ix, pk, -iz), (-ix, pk, iz), (ix, pk, iz), (ix, pk, -iz)], "twood", uvs=uvs)
    for sx in (-0.095, 0.095):
        b.box((sx, h * 0.5 + 0.02, 0), (0.016, h + 0.05, d + 0.02), "iron", scale_uv=3.0)
    for sx in (-w * 0.5, w * 0.5):
        for sz in (-d * 0.5, d * 0.5):
            sphere(b, (sx, h + 0.002, sz), 0.014, "trim", sides=8, rings_n=5)
            sphere(b, (sx, 0.01, sz), 0.012, "trim", sides=8, rings_n=5)
    sphere(b, (0, pk + 0.02, 0), 0.026, "gem", sides=12, rings_n=7, sy=1.1)
    b.lathe([(0.032, pk + 0.004), (0.038, pk + 0.010), (0.030, pk + 0.016)], "trim", sides=12, bark=0.4)
    settle(b, rot(0.4))
    return finish(b)


def crystal(M):
    b = B("Crystal", M)
    b.lathe([(0.001, 0.0), (0.052, 0.050), (0.056, 0.130), (0.001, 0.205)], "gem", sides=6, bark=0.4)
    b.lathe([(0.001, 0.0), (0.030, 0.030), (0.034, 0.075), (0.001, 0.112)], "gem", sides=6, bark=0.4)
    # a collar, so it reads as a fitted core and not a loose stone
    b.lathe([(0.052, 0.062), (0.058, 0.066), (0.058, 0.082), (0.054, 0.086)], "trim", sides=6, bark=0.4)
    settle(b, rot(0.5, 0.0, 1.35))
    return finish(b)


def ring_(M):
    b = B("Ring", M)
    torus(b, (0, 0.022, 0), 0.075, 0.019, "tmetal", seg=26, sides=10, uv=3.0)
    b.tube_path([(0.075, 0.02, 0.0), (0.16, 0.008, 0.07), (0.25, 0.007, 0.03), (0.30, 0.007, -0.06)], [0.005, 0.005, 0.005, 0.004], "leather", sides=5, bark=0.3)
    settle(b, rot(0.0))
    return finish(b)


def fist(M):
    b = B("Fist", M)
    for k in range(4):
        torus(b, ((k - 1.5) * 0.058, 0.016, 0), 0.026, 0.0085, "tmetal", seg=14, sides=6, uv=3.0)
    b.box((0, 0.020, -0.034), (0.250, 0.016, 0.022), "tmetal", cuts=1, scale_uv=3.0)
    b.box((0, 0.020, 0.040), (0.240, 0.012, 0.016), "tmetal", cuts=1, scale_uv=3.0)
    for k in range(4):
        x = (k - 1.5) * 0.058
        b.box((x, 0.020, 0.0), (0.016, 0.014, 0.075), "tmetal", scale_uv=3.0)
        sphere(b, (x, 0.03, -0.047), 0.010, "tmetal", sides=6, rings_n=4)
    torus(b, (0.15, 0.016, 0.07), 0.021, 0.008, "tmetal", seg=12, sides=6, uv=3.0)
    settle(b, rot(0.35, 0.0, 0.05))
    return finish(b)


def tablet(M):
    b = B("Tablet", M)
    b.box((0, 0.020, 0), (0.30, 0.040, 0.20), "twood", cuts=2, jit=0.003, scale_uv=2.4)
    for i in range(4):
        for k in range(4):
            b.box((-0.105 + i * 0.062 + k * 0.011, 0.0415, -0.02), (0.005, 0.004, 0.09), "dark", scale_uv=3.0)
        b.box((-0.105 + i * 0.062 + 0.017, 0.0425, -0.02), (0.07, 0.004, 0.005), "dark", yaw=0.9, scale_uv=3.0)
    for k in range(3):
        b.box((-0.105 + k * 0.011, 0.0415, 0.06), (0.005, 0.004, 0.06), "dark", scale_uv=3.0)
    b.box((0.125, 0.042, 0.06), (0.006, 0.004, 0.05), "dark", yaw=0.4, scale_uv=3.0)
    b.box((0, 0.020, -0.103), (0.31, 0.044, 0.014), "iron", scale_uv=3.0)
    b.box((0, 0.020, 0.103), (0.31, 0.044, 0.014), "iron", scale_uv=3.0)
    settle(b, rot(0.5, 0.0, 0.04))
    return finish(b)


def branch(M):
    b = B("Branch", M)
    b.tube_path([(0.0, 0.026, -0.17), (0.02, 0.040, -0.08), (-0.02, 0.050, 0.04), (0.03, 0.060, 0.17), (0.0, 0.070, 0.27)], [0.030, 0.026, 0.022, 0.016, 0.006], "twood", sides=8, bark=0.3, jit=0.004, seed=3)
    for (at, to, r) in (((0.02, 0.040, -0.08), (0.12, 0.085, -0.02), 0.014), ((-0.02, 0.050, 0.04), (-0.12, 0.100, 0.10), 0.012), ((0.03, 0.060, 0.17), (0.10, 0.10, 0.22), 0.010)):
        mid = ((at[0] + to[0]) * 0.5, (at[1] + to[1]) * 0.5 + 0.02, (at[2] + to[2]) * 0.5)
        b.tube_path([at, mid, to], [r, r * 0.7, 0.004], "twood", sides=6, bark=0.3)
    b.tube((0.0, 0.026, -0.17), (0.0, 0.02, -0.215), 0.032, 0.04, "twood", sides=8, bark=0.3)
    settle(b, rot(0.4))
    return finish(b)


def stone(M):
    b = B("Stone", M)
    b.lathe([(0.001, 0.0), (0.095, 0.01), (0.125, 0.07), (0.105, 0.14), (0.06, 0.185), (0.001, 0.200)], "tstone", sides=14, bark=0.45,
            jit=lambda an, y: 1.0 + 0.16 * hash3(math.cos(an) * 1.7, y * 9, math.sin(an) * 1.7, 2))
    torus(b, (0, 0.105, 0), 0.113, 0.008, "iron", seg=18, sides=5, uv=2.0)
    settle(b, rot(0.0))
    return finish(b)


def mask(M):
    b = B("Mask", M)
    rows, cols = 9, 11
    vs = []
    for i in range(rows):
        t = i / (rows - 1)
        hw = 0.075 * (0.78 + 0.22 * math.sin(math.pi * (0.08 + 0.92 * t))) * (1.0 - 0.38 * t ** 2.2)
        row = []
        for j in range(cols):
            u = j / (cols - 1) * 2.0 - 1.0
            row.append(b.bm.verts.new(Vector((u * hw, 0.22 - t * 0.21, 0.05 * (1.0 - u * u) * (1.0 - 0.3 * t) + 0.012 * math.sin(t * math.pi)))))
        vs.append(row)
    faces = []
    for i in range(rows - 1):
        for j in range(cols - 1):
            f = b.bm.faces.new([vs[i][j], vs[i + 1][j], vs[i + 1][j + 1], vs[i][j + 1]])
            f.material_index = b.keys.index("tmetal")
            f.smooth = True
            faces.append(f)
    b._box_uv(faces, 3.0)
    bmesh.ops.solidify(b.bm, geom=faces, thickness=0.008)
    for sx in (-0.03, 0.03):
        b.box((sx, 0.155, 0.056), (0.030, 0.008, 0.006), "dark", scale_uv=3.0)
    b.box((0, 0.07, 0.050), (0.012, 0.075, 0.012), "tmetal", scale_uv=3.0)
    b.box((0, 0.045, 0.045), (0.040, 0.007, 0.006), "dark", scale_uv=3.0)
    b.box((0, 0.185, 0.054), (0.115, 0.010, 0.008), "tmetal", scale_uv=3.0)
    settle(b, rot(0.4, -1.25, 0.0))
    return finish(b)


def crown(M):
    b = B("Crown", M)
    b.lathe([(0.100, 0.0), (0.104, 0.012), (0.104, 0.046), (0.098, 0.052), (0.090, 0.046), (0.092, 0.012), (0.090, 0.0)], "tmetal", sides=22, bark=0.4)
    n = 7
    for k in range(n):
        a = math.tau * k / n
        ca, sa = math.cos(a), math.sin(a)
        h = 0.085 if k % 2 == 0 else 0.062
        b.tube((ca * 0.098, 0.046, sa * 0.098), (ca * 0.104, 0.046 + h, sa * 0.104), 0.016, 0.003, "tmetal", sides=5, bark=0.3)
        a2 = math.tau * (k + 0.5) / n
        sphere(b, (math.cos(a2) * 0.1, 0.03, math.sin(a2) * 0.1), 0.0085, "gem", sides=6, rings_n=4)
    torus(b, (0, 0.018, 0), 0.101, 0.0045, "trim", seg=22, sides=5, uv=2.0)
    settle(b, rot(0.3, 0.0, 0.5))
    return finish(b)


def sigil(M):
    b = B("Sigil", M)
    b.lathe([(0.001, 0.0), (0.108, 0.0), (0.112, 0.010), (0.108, 0.020), (0.001, 0.020)], "tmetal", sides=26, bark=0.4)
    torus(b, (0, 0.021, 0), 0.092, 0.004, "trim", seg=26, sides=5, uv=2.0)
    for k in range(4):
        b.box((0, 0.024, 0), (0.150, 0.006, 0.010), "dark", yaw=math.pi * k / 4, scale_uv=3.0)
    sphere(b, (0, 0.028, 0), 0.020, "gem", sides=12, rings_n=7, sy=0.7)
    settle(b, rot(0.0))
    return finish(b)


def build():
    L.reset()
    L.TEX_DIR = os.path.join(L.BLEND_DIR, "textures", "loot_props")
    M = mats()
    makers = [orb_focus, vestment, lantern, girdle, pouch, reliquary, crystal, ring_, fist, tablet, branch, stone, mask, crown, sigil]
    objs = [m(M) for m in makers]
    L.export(os.path.join(L.MODEL_DIR, "loot_props.glb"), objs)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(L.BLEND_DIR, "loot_props.blend"))


build()
