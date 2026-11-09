"""THE WATCHERS: two colossal hooded pilgrim-mages carved in weathered stone, standing in the starwater either side
of the Threshold's gate, facing the village. One hand is raised open over the gate (blessing or warning), the other
grips a tall staff whose head is an iron cage round a burning violet orb. Modelled by script (no scans, no downloads).

  tools/blender/run.sh wonder_watchers.py -- [--preview DIR] [--no-bake] [--parts figure,base] [--hi 0.07]

Exports (art/models/wonders/):
  watchers_west.glb / watchers_east.glb   near mesh: objects Watcher_fig (stone figure, baked UVs), Watcher_base (the
                                          stepped pedestal with pilgrim reliefs), Watcher_iron (staff, cage, belt
                                          fittings), Watcher_orb (the emissive orb), Watcher_rubble (tiled stone set),
                                          Watcher_* -convcolonly hulls (collision)
  watchers_west_far.glb / ..._east_far    ~1.5k triangle far mesh
  watchers_{fig,base}_{albedo,normal,orm}.png   baked maps (shared by west and east: east is the mirrored mesh)

Frame: Blender Z up -> Godot Y up, Blender +Y -> Godot -Z (the figure faces Blender +Y, Godot -Z). 1 BU = 1 m. The
origin is the centre of the pedestal's bottom face; the figure's feet stand on the plinth at z = PED_H.
The west watcher (x < 0 in the world) raises its LEFT hand (model -X) over the gate; its staff is in the right.
"""
import bpy
import bmesh
import math
import os
import sys
import random
from mathutils import Vector, Matrix, noise

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art", "models", "wonders")
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(name, default=""):
    return args[args.index(name) + 1] if name in args else default


PREVIEW = arg("--preview")
NOBAKE = "--no-bake" in args
PARTS = arg("--parts", "figure,base").split(",")
HI_STEP = float(arg("--hi", "0.07"))
TEX = int(arg("--tex", "2048"))

PED_H = 5.6                       # top of the cornice: the figure's feet
STAFF = Vector((5.2, 2.7, 0.0))   # the staff's axis (x, y) in the figure frame; z unused


# --- small maths ----------------------------------------------------------------------------------
def lerp(a, b, t):
    return a + (b - a) * t


def sstep(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a + 1e-9)))
    return t * t * (3 - 2 * t)


def fbm(p, octaves=3, lac=2.0, gain=0.5):
    a, f, s, n = 1.0, 1.0, 0.0, 0.0
    for _ in range(octaves):
        s += a * noise.noise(p * f)
        n += a
        a *= gain
        f *= lac
    return s / n


def prof(tab, x):
    """Piecewise smooth interpolation of rows (x, a, b, ...) at x -> tuple of the other columns."""
    if x <= tab[0][0]:
        return tab[0][1:]
    for i in range(len(tab) - 1):
        if x <= tab[i + 1][0]:
            t = sstep(tab[i][0], tab[i + 1][0], x)
            return tuple(lerp(a, b, t) for a, b in zip(tab[i][1:], tab[i + 1][1:]))
    return tab[-1][1:]


def catmull(pts, t):
    """Catmull-Rom through pts at t in [0, 1]."""
    n = len(pts) - 1
    x = max(0.0, min(0.9999999, t)) * n
    i = int(x)
    u = x - i
    p0 = pts[max(i - 1, 0)]
    p1 = pts[i]
    p2 = pts[i + 1]
    p3 = pts[min(i + 2, n)]
    return 0.5 * ((2 * p1) + (-p0 + p2) * u + (2 * p0 - 5 * p1 + 4 * p2 - p3) * u * u + (-p0 + 3 * p1 - 3 * p2 + p3) * u ** 3)


# --- bmesh primitives -----------------------------------------------------------------------------
class Parts:
    def __init__(self):
        self.bm = {}

    def of(self, key):
        if key not in self.bm:
            self.bm[key] = bmesh.new()
        return self.bm[key]


def loft(bm, rings, cap0=True, cap1=True):
    """rings: lists of Vectors (equal count), consecutive rings joined by quads (outward for CCW rings going up)."""
    vr = [[bm.verts.new(p) for p in ring] for ring in rings]
    n = len(vr[0])
    for i in range(len(vr) - 1):
        for j in range(n):
            bm.faces.new((vr[i][j], vr[i][(j + 1) % n], vr[i + 1][(j + 1) % n], vr[i + 1][j]))
    if cap0:
        bm.faces.new(vr[0][::-1])
    if cap1:
        bm.faces.new(vr[-1])
    # UV seams: down the first column, and round each capped end
    for i in range(len(vr) - 1):
        e = bm.edges.get((vr[i][0], vr[i + 1][0]))
        if e:
            e.seam = True
    for ring, capped in ((vr[0], cap0), (vr[-1], cap1)):
        if capped:
            for j in range(n):
                e = bm.edges.get((ring[j], ring[(j + 1) % n]))
                if e:
                    e.seam = True
    return vr


def frame_at(pts, k, prev_u=None):
    """A rotation-minimising frame (u, v, T) with u x v = T along a polyline of centres."""
    a = pts[max(k - 1, 0)]
    b = pts[min(k + 1, len(pts) - 1)]
    T = (b - a).normalized()
    if prev_u is None:
        ref = Vector((0, 1, 0)) if abs(T.y) < 0.9 else Vector((1, 0, 0))
        u = (ref - T * ref.dot(T)).normalized()
    else:
        u = (prev_u - T * prev_u.dot(T)).normalized()
    v = T.cross(u)
    return u, v, T


def tube(bm, centres, radii, seg=8, cap0=True, cap1=True, squash=None, twist=0.0, ring_fn=None):
    """A lofted tube along a list of centres with a radius per centre. ring_fn(k, phi, c, u, v, r) -> point."""
    rings = []
    u = None
    for k, c in enumerate(centres):
        u, v, T = frame_at(centres, k, u)
        r = radii[k]
        ring = []
        for j in range(seg):
            phi = math.tau * j / seg + twist * k
            if ring_fn:
                ring.append(ring_fn(k, phi, c, u, v, r))
            else:
                sq = squash[k] if squash else 1.0
                ring.append(c + u * (math.cos(phi) * r) + v * (math.sin(phi) * r * sq))
        rings.append(ring)
    return loft(bm, rings, cap0, cap1)


def seg_tube(bm, a, b, r0, r1=None, seg=8, cap0=True, cap1=True):
    a, b = Vector(a), Vector(b)
    tube(bm, [a, (a + b) * 0.5, b], [r0, (r0 + (r0 if r1 is None else r1)) * 0.5, r0 if r1 is None else r1], seg, cap0, cap1)


def sphere(bm, c, r, seg=8, rings=5, scale=(1, 1, 1)):
    M = Matrix.Translation(Vector(c)) @ Matrix.Diagonal((scale[0], scale[1], scale[2], 1.0))
    res = bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=r, matrix=M)
    cc = Vector(c)
    for e in {ed for v in res["verts"] for ed in v.link_edges}:
        a, b = e.verts
        if abs(a.co.y - cc.y) < 1e-5 and abs(b.co.y - cc.y) < 1e-5 and a.co.x >= cc.x - 1e-5 and b.co.x >= cc.x - 1e-5:
            e.seam = True


def box(bm, c, size, yaw=0.0, pitch=0.0, roll=0.0):
    rot = Matrix.Rotation(yaw, 4, 'Z') @ Matrix.Rotation(pitch, 4, 'X') @ Matrix.Rotation(roll, 4, 'Y')
    M = Matrix.Translation(Vector(c)) @ rot @ Matrix.Diagonal((size[0], size[1], size[2], 1.0))
    res = bmesh.ops.create_cube(bm, size=1.0, matrix=M)
    for v in res["verts"]:
        for e in v.link_edges:
            e.seam = True


def torus(bm, c, R, r, seg=24, tseg=6, axis='Z'):
    pts = []
    for k in range(seg + 1):
        a = math.tau * k / seg
        pts.append(Vector(c) + (Vector((math.cos(a) * R, math.sin(a) * R, 0)) if axis == 'Z' else Vector((math.cos(a) * R, 0, math.sin(a) * R))))
    # a closed ring: loft the circle sections by hand
    rings = []
    for k in range(seg):
        a = math.tau * k / seg
        ctr = Vector(c) + (Vector((math.cos(a) * R, math.sin(a) * R, 0)) if axis == 'Z' else Vector((math.cos(a) * R, 0, math.sin(a) * R)))
        radial = (ctr - Vector(c)).normalized()
        up = Vector((0, 0, 1)) if axis == 'Z' else Vector((0, 1, 0))
        ring = []
        for j in range(tseg):
            p = math.tau * j / tseg
            ring.append(ctr + radial * (math.cos(p) * r) + up * (math.sin(p) * r))
        rings.append(ring)
    vr = [[bm.verts.new(p) for p in ring] for ring in rings]
    for i in range(seg):
        i2 = (i + 1) % seg
        for j in range(tseg):
            j2 = (j + 1) % tseg
            bm.faces.new((vr[i][j], vr[i][j2], vr[i2][j2], vr[i2][j]))


def translate(bm, v):
    bmesh.ops.translate(bm, vec=Vector(v), verts=bm.verts)


# --- cloth ----------------------------------------------------------------------------------------
def fd(phi, z, amp, tw, seeds, seed=0.0):
    """Drapery as a radial offset in metres: deep V valleys, rounded ridges, bundles of deep and shallow folds."""
    warp = 0.8 * fbm(Vector((math.cos(phi) * 1.1 + seed, math.sin(phi) * 1.1, z * 0.18)), 2)
    f = 0.0
    for n, ph, w in seeds:
        s = math.sin(n * phi + ph + tw * z + warp * 1.0)
        f += w * (0.5 - abs(s) ** 0.8)
    mod = 0.5 + 1.0 * (0.5 + 0.5 * noise.noise(Vector((math.cos(phi) * 0.9 + seed * 1.7, math.sin(phi) * 0.9, z * 0.1 + 3.0))))
    return amp * f * mod


def gauss(x, w):
    return math.exp(-((x / w) ** 2))


# ============================================================================================
# THE FIGURE: a man under the robe (broad shoulders, the weight on one leg), a deep rounded cowl bowed a little,
# a heavy mantle with depth, both hands resting one over the other on a tall staff held upright before him.
# Cloth is built in raw heights, then stretched by STR; hands and the staff are not.
# ============================================================================================
STR = 1.45
WID = 1.0
SX, SY = 3.7, 4.4                                  # the staff's axis
STAFF = Vector((SX, SY, 0.0))
ROBE = [(0.0, 3.5, 3.4), (0.8, 3.1, 3.0), (2.5, 2.7, 2.6), (4.5, 2.4, 2.3), (6.5, 2.3, 2.1), (8.5, 2.7, 2.1),
        (10.5, 3.2, 2.3), (12.4, 3.0, 2.2)]
ROBE_SEEDS = ((9, 0.3, 1.0), (14, 1.7, 0.5), (5, 2.2, 0.9), (23, 0.9, 0.2), (3, 0.5, 0.7))
BACK = -math.pi / 2                                  # the seam of every loft runs down the back


def robe_xy(z, phi, seed=0.0):
    rx, ry = prof(ROBE, z)
    amp = lerp(0.85, 0.26, sstep(0.0, 9.0, z))
    d = fd(phi, z, amp, 0.14, ROBE_SEEDS, seed)
    sway = 0.45 * sstep(0.0, 9.0, z) * (1.0 - 0.6 * sstep(9.0, 12.0, z))
    # the weight on the right leg: the left knee comes forward under the cloth, the hip drops on the other side
    leg = 0.6 * gauss(phi - 1.95, 0.5) * gauss(z - 3.6, 2.3) - 0.28 * gauss(phi - 1.15, 0.5) * gauss(z - 3.6, 2.3)
    # the cloth pools and breaks at the feet
    pool = 0.45 * gauss(z - 0.2, 0.7) * (0.5 + 0.5 * math.sin(7 * phi + 1.0))
    c, s = math.cos(phi), math.sin(phi)
    return Vector((c * (rx * WID + d + leg + pool) - sway, s * (ry * WID + d + leg + pool), z))


def build_robe(P):
    bm = P.of("fig")
    N = 120
    zs = [0.0, 0.2, 0.55, 1.1, 1.8, 2.6, 3.5, 4.5, 5.5, 6.5, 7.5, 8.5, 9.5, 10.5, 11.5, 12.6]
    rings = []
    for i, z in enumerate(zs):
        ring = []
        for j in range(N):
            phi = BACK + math.tau * j / N
            p = robe_xy(z, phi)
            if i < 4:                                     # the hem: lower on the ridges, lifting between
                w = 1.0 - i / 4.0
                p.z = -0.15 + (z + 0.15) * 1.0 + 0.55 * w * (0.5 - abs(math.sin(9 * phi + 0.3 + 0.9 * fbm(Vector((phi, 0, 0)), 2)))) + 0.25 * w * noise.noise(Vector((phi * 2, 4, 0)))
            ring.append(p)
        rings.append(ring)
    loft(bm, rings, True, True)


def mantle_hem(phi):
    back = max(0.0, -math.sin(phi))
    return 10.9 - 5.3 * back ** 1.1 - 1.2 * max(0.0, math.cos(phi)) ** 2 * 0 + 0.35 * math.sin(3 * phi + 1.0) + 0.6 * math.sin(5 * phi) * back


MANTLE = [(0.0, 2.5, 2.2), (0.12, 3.8, 2.8), (0.3, 4.7, 3.3), (0.6, 5.0, 3.6), (1.0, 5.1, 3.7)]
MSEEDS = ((7, 0.6, 1.0), (11, 2.0, 0.6), (4, 0.2, 0.95), (17, 1.1, 0.25), (2, 1.0, 0.6))
# shoulder, elbow, wrist (raw heights): the right hand lower on the staff, the left over it
ZC_LOW, ZC_UP = 12.6, 14.7                          # the hands' heights on the staff (stretched space)
RF = 0.23                                           # a finger's radius
RFC = 0.54 + RF * 0.9                               # the fingers' circle round the shaft
ARM_R = [Vector((2.7, 0.1, 10.6)), Vector((4.9, 0.0, 7.7)), Vector((SX, SY - RFC - 2.1, ZC_LOW / STR - 0.2))]
ARM_L = [Vector((-2.7, 0.1, 10.6)), Vector((-3.1, 1.0, 9.0)), Vector((SX - RFC - 2.1, SY - 0.2, ZC_UP / STR - 0.2))]


def build_mantle(P):
    bm = P.of("fig")
    N, T = 120, 36
    rings = []
    zt = 13.1
    for i in range(T + 1):
        t = i / T
        ring = []
        for j in range(N):
            phi = BACK + math.tau * j / N
            zh = mantle_hem(phi)
            rx, ry = prof(MANTLE, t)
            back = max(0.0, -math.sin(phi))
            z = lerp(zt, zh, t ** 0.85)
            amp = lerp(0.1, 1.1, sstep(0.12, 0.7, t)) * (1.0 + 1.3 * back)
            d = fd(phi, z, amp, -0.1, MSEEDS, 5.0)
            d += 0.35 * back * math.sin(z * 1.1 + 3 * phi) * sstep(0.3, 0.8, t)
            if t > 0.88:                                 # the heavy rolled hem lifts and falls with the folds
                z += 0.4 * (0.5 - math.sin(3.5 * phi + 1.0 + 0.8 * fbm(Vector((phi, 1, 0)), 2)) ** 2) * sstep(0.88, 1.0, t)
            ryk = ry * (1.0 + 0.1 * back) + 0.5 * back * t * t               # depth in profile: the cloak falls fuller behind
            p = Vector((math.cos(phi) * (rx * WID + d), math.sin(phi) * (ryk * WID + d) + 0.0 - 0.3 * back, z))
            for arm, rr in ((ARM_L, 1.15), (ARM_R, 1.15)):
                a = arm[0]
                b = arm[0] + (arm[1] - arm[0]) * 0.45
                ab = b - a
                s = max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))
                q = a + ab * s
                dd = p - q
                if dd.length < rr * 1.7 and dd.length > 1e-4:
                    f = sstep(rr * 1.7, rr * 0.9, dd.length)       # a smooth swell: the cloth rides over the arm
                    p = p + (dd.normalized() * rr * 1.15 - dd) * f
            ring.append(p)
        rings.append(ring)
    last = rings[-1]
    for dz, dr in ((-0.32, 0.0), (-0.45, -0.25), (-0.2, -0.6)):
        ring = []
        for p in last:
            r = Vector((p.x, p.y, 0.0)).normalized()
            ring.append(Vector((p.x + r.x * dr, p.y + r.y * dr, p.z + dz)))
        rings.append(ring)
    loft(bm, rings[::-1], True, True)


# the cowl: a rounded dome following the skull, falling onto the shoulders in heavy folds
HOOD = [(0.0, 11.6, 3.6, 3.2, 0.0), (0.1, 12.5, 2.9, 2.9, 0.1), (0.25, 13.8, 2.55, 2.75, 0.3), (0.45, 15.3, 2.5, 2.8, 0.5),
        (0.65, 16.7, 2.35, 2.65, 0.5), (0.82, 17.8, 1.9, 2.2, 0.4), (0.93, 18.55, 1.3, 1.5, 0.3), (0.985, 18.95, 0.6, 0.7, 0.2),
        (1.0, 19.05, 0.35, 0.4, 0.2)]
FACE_Z, FACE_HZ, FACE_HP = 14.2, 0.8, 0.6
HSEEDS = ((6, 0.4, 1.0), (10, 1.3, 0.6), (3, 2.0, 0.9), (15, 0.7, 0.25))
BOW = -0.32
PIVOT = Vector((0.0, 0.3, 12.0))


def hood_point(t, phi):
    z, rx, ry, cy = prof(HOOD, t)
    amp = lerp(0.25, 0.6, sstep(0.0, 0.4, t)) * (1.0 - 0.8 * sstep(0.8, 1.0, t))
    d = fd(phi, z, amp, 0.15, HSEEDS, 9.0)
    dphi = phi - math.pi / 2
    y = (z - FACE_Z) / FACE_HZ
    inside = max(0.0, 1.0 - y * y) ** 0.5 if abs(y) < 1.0 else 0.0
    hw = FACE_HP * inside ** 0.7
    edge = abs(dphi) - hw
    pocket = (1.0 - sstep(-0.35, 0.06, edge)) * (1.0 if abs(y) < 1.0 else 0.0)
    d *= 1.0 - 0.85 * gauss(dphi, 0.9) * sstep(12.8, 13.6, z) * (1.0 - sstep(16.8, 17.6, z))
    k = 1.0
    # the cowl's lip: a thick roll of cloth round the opening, overhanging above (the face is lost under it)
    lip = math.exp(-(((edge - 0.1) / 0.12) ** 2)) * (1.0 if -1.15 < y < 1.2 else 0.0)
    brow = gauss(z - (FACE_Z + FACE_HZ * 1.15), 0.7) * gauss(dphi, 1.0)
    k *= 1.0 + 0.12 * lip + 0.42 * brow
    bowl = pocket * (1.0 - 0.3 * (dphi / max(hw, 0.2)) ** 2) * (1.0 - 0.3 * y * y)
    p = Vector((math.cos(phi) * (rx * WID * k + d * k), math.sin(phi) * (ry * WID * k + d * k) + cy + 0.12 - 3.2 * bowl, z))
    q = p - PIVOT
    c, s = math.cos(BOW), math.sin(BOW)                  # the head bowed: the cowl tips forward over the chest
    return PIVOT + Vector((q.x, q.y * c - q.z * s, q.y * s + q.z * c))


def build_hood(P):
    bm = P.of("fig")
    N, T = 108, 60
    rings = []
    for i in range(T + 1):
        t = i / T
        rings.append([hood_point(t, BACK + math.tau * j / N) for j in range(N)])
    loft(bm, rings, False, True)


def sleeve(P, arm, wrist_r, sag, flare, seed):
    bm = P.of("fig")
    pts = [catmull(arm, i / 28.0) for i in range(29)]
    rings = []
    u = None
    for k, c in enumerate(pts):
        t = k / 28.0
        u, v, T = frame_at(pts, k, u)
        r = lerp(1.05, 1.15, sstep(0.0, 0.4, t))
        r = lerp(r, wrist_r + flare, sstep(0.5, 1.0, t) ** 1.3) if t > 0.5 else r
        sg = sag * sstep(0.2, 1.0, t) ** 1.4
        ring = []
        for j in range(24):
            phi = math.tau * j / 24
            d = u * math.cos(phi) + v * math.sin(phi)
            rr = r + 0.5 * (1.0 - sstep(0.6, 0.95, t)) * fd(phi + seed, t * 6.0, 0.7, 0.0, ((5, 0.2, 1.0), (8, 1.0, 0.5), (3, 2.0, 0.6)), seed)
            p = c + d * rr
            down = max(0.0, -d.z)
            p.z -= sg * down ** 1.3
            ring.append(p)
        rings.append(ring)
    last = rings[-1]
    cen = sum(last, Vector()) / len(last)
    T = (pts[-1] - pts[-2]).normalized()
    cuff = [[cen + (p - cen) * 1.07 + T * 0.04 for p in last], [cen + (p - cen) * 1.02 + T * 0.14 for p in last],
            [cen + (p - cen) * 0.88 + T * 0.14 for p in last], [cen + (p - cen) * 0.8 - T * 0.8 for p in last]]
    loft(bm, rings + cuff, True, True)
    return pts


def ring3(bm, c, axis, R, r, seg=14, tseg=5):
    """A torus about an arbitrary axis."""
    axis = Vector(axis).normalized()
    u = axis.cross(Vector((0, 0, 1)) if abs(axis.z) < 0.9 else Vector((1, 0, 0))).normalized()
    v = axis.cross(u)
    rings = []
    for k in range(seg):
        a = math.tau * k / seg
        ctr = Vector(c) + (u * math.cos(a) + v * math.sin(a)) * R
        rad = (u * math.cos(a) + v * math.sin(a))
        ring = []
        for j in range(tseg):
            p = math.tau * j / tseg
            ring.append(ctr + rad * (math.cos(p) * r) + axis * (math.sin(p) * r))
        rings.append(ring)
    vr = [[bm.verts.new(p) for p in ring] for ring in rings]
    for i in range(seg):
        i2 = (i + 1) % seg
        for j in range(tseg):
            bm.faces.new((vr[i][j], vr[i][(j + 1) % tseg], vr[i2][(j + 1) % tseg], vr[i2][j]))


def fist(P, side, zc, ring=False):
    """A hand closed on the staff: a wedge of back-of-hand with its tendons, four fingers laid side by side round the
    shaft with knuckles and joints, a thumb over them, a ring. side 'R' knuckles on the body side of the shaft, 'L' on its
    inner side. Returns the wrist end."""
    bm = P.of("fig")
    sp = RF * 2.0
    Z = Vector((0, 0, 1))
    ang0, ang1 = (-180.0, 60.0) if side == 'R' else (-100.0, 150.0)
    D = Vector((0, 1, 0)) if side == 'R' else Vector((1, 0, 0))
    W = Z.cross(D).normalized()
    kc = Vector((SX + math.sin(math.radians(ang0)) * RFC, SY + math.cos(math.radians(ang0)) * RFC, zc))
    wc = kc - D * 2.2
    rings = []
    for t, hw, hh in ((0.0, 0.5, 0.62), (0.3, 0.7, 0.85), (0.7, 0.84, 0.98), (1.0, 0.86, 1.0)):
        c = wc + (kc - wc) * t
        ring = []
        for j in range(14):
            a = math.tau * j / 14
            cx, cy = math.cos(a), math.sin(a)
            ring.append(c + W * (math.copysign(abs(cx) ** 0.9, cx) * hw) + Z * (math.copysign(abs(cy) ** 0.9, cy) * hh))
        rings.append(ring)
    loft(bm, rings, True, True)
    back = W * (-1.0 if side == 'R' else 1.0)
    for k in range(4):
        zk = (1.5 - k) * sp * 0.82
        a0 = wc + D * 0.25 + Z * zk * 0.7 + back * 0.55
        a1 = kc - D * 0.1 + Z * zk + back * 0.82
        tube(bm, [a0, (a0 + a1) * 0.5 + back * 0.06, a1], [0.07, 0.085, 0.075], 5, True, True)
    for k in range(4):
        zk = (1.5 - k) * sp
        pts, rad = [], []
        for s_ in range(14):
            ang = math.radians(lerp(ang0, ang1, s_ / 13.0))
            pts.append(Vector((SX + math.sin(ang) * RFC, SY + math.cos(ang) * RFC, zc + zk - 0.04 * s_)))
            t = s_ / 13.0
            rad.append(RF * (1.0 - 0.3 * t) * (1.0 + 0.09 * math.cos(t * 3 * math.tau)) * (0.9 if k == 3 else 1.0))
        tube(bm, pts, rad, 8, True, True)
        sphere(bm, pts[0], RF * 1.28, 8, 6)
        sphere(bm, pts[-1], rad[-1] * 1.05, 8, 5, (1, 1, 1.1))
        if ring and k == 2:
            ring3(bm, pts[3], (pts[4] - pts[2]), rad[3] * 1.12, 0.06)
    tz = zc + 2.0 * sp + 0.05
    ts = [kc - D * 1.1 + Z * (1.5 * sp * 0.6) - back * 0.1]
    for s_ in range(1, 9):
        ang = math.radians(lerp(ang0 + 6, ang0 + 110, s_ / 8.0))
        ts.append(Vector((SX + math.sin(ang) * (RFC + 0.02), SY + math.cos(ang) * (RFC + 0.02), tz - 0.05 * s_)))
    tube(bm, [catmull(ts, i / 11.0) for i in range(12)], [0.26 * (1 - 0.3 * i / 11.0) for i in range(12)], 8, True, True)
    return wc


def stretched(v):
    return Vector((v.x, v.y, v.z * STR))


def append_bm(dst, src):
    mp = {}
    for v in src.verts:
        mp[v] = dst.verts.new(v.co)
    for f in src.faces:
        dst.faces.new([mp[v] for v in f.verts])
    for e in src.edges:
        if e.seam:
            de = dst.edges.get((mp[e.verts[0]], mp[e.verts[1]]))
            if de:
                de.seam = True


def build_figure(P):
    C = Parts()
    build_robe(C)
    build_mantle(C)
    build_hood(C)
    pr = sleeve(C, ARM_R, 0.6, 0.5, 0.35, 1.7)
    pl = sleeve(C, ARM_L, 0.6, 0.5, 0.35, 0.4)
    build_trim(C)
    bmesh.ops.scale(C.of("fig"), vec=Vector((1, 1, STR)), verts=C.of("fig").verts)
    append_bm(P.of("fig"), C.of("fig"))
    bm = P.of("fig")
    # the wrists run from the cuffs into the hands on the staff
    for pts, sd, zc, rg in ((pr, 'R', ZC_LOW, False), (pl, 'L', ZC_UP, True)):
        w = stretched(pts[-1])
        d = stretched(pts[-1] - pts[-3]).normalized()
        wc = fist(P, sd, zc, rg)
        tube(bm, [w - d * 0.7, w + d * 0.3, (w + wc) * 0.5, wc], [0.62, 0.58, 0.55, 0.6], 10)
    # shoes under the hem: the forward foot and the one set back
    for sx, sy in ((-1.0, 3.3), (1.0, 2.4)):
        c = Vector((sx - 0.2, sy, 0.38))
        tube(bm, [c + Vector((0, -0.9, 0.1)), c, c + Vector((0, 1.0, -0.12))], [0.6, 0.72, 0.42], 10)
        sphere(bm, c + Vector((0, 0.95, -0.05)), 0.5, 8, 6, (1.0, 1.1, 0.8))


def build_trim(P):
    """The rope belt with its tassels and a string of stone beads (raw heights)."""
    bm = P.of("fig")
    pts = [robe_xy(7.55, BACK + math.tau * j / 72) for j in range(73)]
    rings = []
    for k, c in enumerate(pts[:-1]):
        radial = Vector((c.x + 0.45, c.y, 0)).normalized()
        ring = []
        for j in range(7):
            a = math.tau * j / 7 + k * 0.5
            ring.append(c + radial * (0.14 + math.cos(a) * 0.19) + Vector((0, 0, 1)) * (math.sin(a) * 0.19))
        rings.append(ring)
    vr = [[bm.verts.new(p) for p in ring] for ring in rings]
    for i in range(len(vr)):
        i2 = (i + 1) % len(vr)
        for j in range(7):
            bm.faces.new((vr[i][j], vr[i][(j + 1) % 7], vr[i2][(j + 1) % 7], vr[i2][j]))
    kc = robe_xy(7.55, math.pi / 2 + 0.3)
    sphere(bm, kc + Vector((0, 0.3, 0)), 0.42, 8, 6)
    for sgn, ln in ((1, 3.4), (-1, 2.6)):
        a = kc + Vector((0.1 * sgn, 0.4, -0.1))
        path = [a, a + Vector((0.12 * sgn, 0.1, -ln * 0.35)), a + Vector((0.3 * sgn, 0.08, -ln * 0.7)), a + Vector((0.35 * sgn, 0.08, -ln))]
        out = []
        for p in path:
            r = robe_xy(p.z, math.atan2(p.y, p.x + 0.45))
            out.append(Vector((p.x, max(p.y, r.y + 0.22), p.z)))
        tube(bm, out, [0.17, 0.16, 0.15, 0.14], 6)
        sphere(bm, out[-1] + Vector((0, 0, -0.35)), 0.3, 7, 5, (1, 1, 1.5))
    n = 15
    for i in range(n):
        t = i / (n - 1)
        ang = math.pi / 2 + 1.0 + 0.9 * t
        zz = 7.55 - 4.2 * math.sin(t * math.pi * 0.5)
        p = robe_xy(zz, ang)
        radial = Vector((p.x + 0.45, p.y, 0)).normalized()
        sphere(bm, p + radial * 0.3, 0.2 + 0.05 * (i % 3 == 0), 6, 4)


# --- the staff ------------------------------------------------------------------------------------
LANT0, LANT1 = 28.0, 33.4         # the lantern's floor and its cap's rim
ORB_Z = 30.6


def link(bm, c, axis, n=0):
    ring3(bm, c, axis, 0.22, 0.06, 10, 4)


def build_staff(P):
    """A heavy iron-shod shaft, collars, a socket, and a forged lantern: eight square bars, three rings, a cap with a
    finial, swags of chain round the rim, the burning orb inside; one bar snapped. Returns the orb centre."""
    st = P.of("iron")
    sx, sy = SX, SY
    top = LANT0 + 0.2
    pts = [Vector((sx + 0.03 * math.sin(z * 0.4), sy, z)) for z in [x * 1.1 for x in range(0, 27)]]
    pts = [p for p in pts if p.z < top]
    tube(st, pts, [0.6 - 0.1 * (c.z / 28.0) for c in pts], 10, True, True)
    # the iron shoe: a stepped cone with straps and a blunt spike
    tube(st, [Vector((sx, sy, -0.3)), Vector((sx, sy, 0.1)), Vector((sx, sy, 1.4)), Vector((sx, sy, 2.4))], [0.35, 0.95, 0.85, 0.72], 10, True, True)
    for k in range(6):
        a = math.tau * k / 6
        seg_tube(st, Vector((sx + math.cos(a) * 0.62, sy + math.sin(a) * 0.62, 0.8)), Vector((sx + math.cos(a) * 0.7, sy + math.sin(a) * 0.7, 3.6)), 0.12, 0.1, 4)
    for z, rr in ((2.5, 0.78), (3.7, 0.7), (8.3, 0.66), (16.5, 0.62), (22.5, 0.6), (27.2, 0.66)):
        ring3(st, (sx, sy, z), (0, 0, 1), rr, 0.17, 16, 5)
    # a wound band of iron wire up the upper shaft
    hp = []
    for k in range(70):
        t = k / 69.0
        z = lerp(17.2, 27.0, t)
        a = t * math.tau * 6.0
        r0 = 0.6 - 0.1 * z / 28 + 0.08
        hp.append(Vector((sx + math.cos(a) * r0, sy + math.sin(a) * r0, z)))
    tube(st, hp, [0.07] * 70, 4, True, True)
    # the socket under the lantern
    tube(st, [Vector((sx, sy, LANT0 - 1.2)), Vector((sx, sy, LANT0 - 0.4)), Vector((sx, sy, LANT0 + 0.1))], [0.6, 0.95, 1.5], 12, True, True)
    # the floor plate and its spikes
    tube(st, [Vector((sx, sy, LANT0)), Vector((sx, sy, LANT0 + 0.2)), Vector((sx, sy, LANT0 + 0.5))], [2.3, 2.35, 2.05], 16, True, True)
    for k in range(8):
        a = math.tau * k / 8
        seg_tube(st, Vector((sx + math.cos(a) * 2.2, sy + math.sin(a) * 2.2, LANT0 + 0.1)), Vector((sx + math.cos(a) * 2.5, sy + math.sin(a) * 2.5, LANT0 - 0.9)), 0.17, 0.02, 4)
    # eight forged square bars, bellying out round the orb; one has snapped
    n = 8
    for i in range(n):
        a = math.tau * i / n + 0.2
        pp, rr = [], []
        for k in range(14):
            t = k / 13.0
            r = 2.0 + 0.45 * math.sin(math.pi * t) - 0.3 * t
            pp.append(Vector((sx + math.cos(a) * r, sy + math.sin(a) * r, lerp(LANT0 + 0.5, LANT1, t))))
        cut = 9 if i == 5 else 14
        tube(st, pp[:cut], [0.27] * cut, 4, True, True, twist=0.0)
    for z, r in ((LANT0 + 0.6, 2.15), (ORB_Z, 2.5), (LANT1 - 0.2, 2.0)):
        ring3(st, (sx, sy, z), (0, 0, 1), r, 0.17, 32, 5)
    # the cap: a pitched roof with a rim, an upturned finial and a loop
    tube(st, [Vector((sx, sy, LANT1 - 0.3)), Vector((sx, sy, LANT1 + 0.1)), Vector((sx, sy, LANT1 + 0.55))], [2.6, 2.75, 2.2], 16, True, True)
    tube(st, [Vector((sx, sy, LANT1 + 0.5)), Vector((sx, sy, LANT1 + 1.4)), Vector((sx, sy, LANT1 + 2.2))], [2.1, 1.2, 0.5], 16, True, False)
    sphere(st, (sx, sy, LANT1 + 2.5), 0.45, 10, 7)
    tube(st, [Vector((sx, sy, LANT1 + 2.7)), Vector((sx, sy, LANT1 + 3.4)), Vector((sx, sy, LANT1 + 4.2))], [0.2, 0.14, 0.02], 6, True, True)
    ring3(st, (sx, sy + 0.0, LANT1 + 3.0), (1, 0, 0), 0.5, 0.09, 12, 4)
    # four chains hanging from the cap's rim down the outside of the cage to the floor plate
    for k in range(4):
        a = math.tau * (k + 0.5) / 4
        zz = LANT1 - 0.1
        i = 0
        while zz > LANT0 + 1.0:
            c = Vector((sx + math.cos(a) * 3.0, sy + math.sin(a) * 3.0, zz))
            tang = Vector((-math.sin(a), math.cos(a), 0.0))
            rad = Vector((math.cos(a), math.sin(a), 0.0))
            ring3(st, c, tang if i % 2 == 0 else rad, 0.3, 0.075, 10, 4)
            zz -= 0.5
            i += 1
        seg_tube(st, Vector((sx + math.cos(a) * 3.0, sy + math.sin(a) * 3.0, LANT1 + 0.1)), Vector((sx + math.cos(a) * 2.4, sy + math.sin(a) * 2.4, LANT1 + 0.45)), 0.14, 0.14, 5)
    ob = P.of("orb")
    sphere(ob, (sx, sy, ORB_Z), 1.55, 20, 12)
    return Vector((sx, sy, ORB_Z))


def build_pennant(P):
    """Two stone streamers tied under the lantern, falling and curling down the shaft."""
    sx, sy = SX, SY
    for sgn, ph, ln in ((1, 0.3, 8.0), (-1, 1.7, 6.0)):
        tmp = bmesh.new()
        path = []
        for i in range(26):
            t = i / 25.0
            path.append(Vector((sx + sgn * (0.75 + 1.3 * math.sin(t * 3.2 + ph) * t), sy + 0.8 * math.sin(t * 2.6 + ph * 2) * t + 0.4, LANT0 - 0.4 - ln * t)))
        rings = []
        for i, c in enumerate(path):
            t = i / 25.0
            w = 0.34 * (1 - 0.5 * t)
            ang = 0.9 * math.sin(t * 5 + ph)
            ux = Vector((math.cos(ang), math.sin(ang) * 0.6, 0.0))
            rings.append([c + ux * w + Vector((0, 0.06, 0)), c - ux * w + Vector((0, 0.06, 0)), c - ux * w - Vector((0, 0.06, 0)), c + ux * w - Vector((0, 0.06, 0))])
        loft(tmp, rings, True, True)
        bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces)
        append_bm(P.of("iron"), tmp)
        tmp.free()


# ============================================================================================
# THE PEDESTAL
# ============================================================================================
TIERS = [  # (name, half x, half y, z0, z1)
    ("foot", 7.4, 7.2, 0.0, 0.9),
    ("step", 6.6, 6.3, 0.9, 1.8),
    ("plinth", 5.6, 5.3, 1.8, 5.0),
    ("cornice", 6.1, 5.8, 5.0, 5.6),
]
FACES = {"+y": (Vector((0, 1, 0)), Vector((1, 0, 0))), "-y": (Vector((0, -1, 0)), Vector((-1, 0, 0))),
         "+x": (Vector((1, 0, 0)), Vector((0, -1, 0))), "-x": (Vector((-1, 0, 0)), Vector((0, 1, 0)))}


def pilgrim(bm, org, uax, nax, h=1.5, depth=0.9, lean=0.12, pack=False, rnd=None, raised=False):
    """A relief pilgrim climbing toward +uax: a sloped robe, a mantle's shoulders, a pointed hood, a staff, a pack."""
    rnd = rnd or random
    up = Vector((0, 0, 1))
    rows = [(0.0, 0.42), (0.1, 0.4), (0.4, 0.27), (0.6, 0.3), (0.7, 0.46), (0.76, 0.3), (0.8, 0.12), (0.85, 0.2), (0.95, 0.3), (1.05, 0.22), (1.2, 0.0)]
    rings = []
    for k, (f, rr) in enumerate(rows):
        zz = f * h
        sh = lean * zz + (0.06 * h if f > 0.84 else 0.0)
        ring = []
        for j in range(12):
            a = math.tau * j / 12
            out = math.sin(a) * rr * depth * (1.0 + 0.06 * math.sin(5 * a + k))
            ring.append(org + uax * (sh + math.cos(a) * rr * (0.8 if f > 0.8 else 1.0)) + nax * max(0.0, out) + up * zz)
        rings.append(ring)
    loft(bm, rings, True, True)
    sx = org + uax * (0.52 + lean * 1.2 * h) + nax * 0.09
    seg_tube(bm, sx, sx + up * (h * 1.45), 0.055, 0.05, 5)
    sphere(bm, sx + up * (h * 1.45), 0.1, 5, 4)
    if pack:
        box(bm, org + uax * (-0.3) + nax * 0.16 + up * (0.6 * h), (0.36, 0.26, 0.55))
    seg_tube(bm, org + uax * 0.18 + nax * 0.2 + up * (0.66 * h), sx + nax * 0.05 + up * (0.8 * h - 0.4 * h * (0.0 if raised else 0.4)), 0.1, 0.08, 5)


def panel(bm, face, half_u, v0, v1, count, seed, climb=0.6):
    """A relief panel on a plinth face: a frame, a long stair, and a procession of pilgrims climbing it left to right."""
    n, u = FACES[face]
    rnd = random.Random(seed)
    t = [x for x in TIERS if x[0] == "plinth"][0]
    off = (t[2] if face[1] == 'y' else t[1])
    up = Vector((0, 0, 1))
    c = n * off
    W = 2 * half_u
    ph = v1 - v0
    pc = (v0 + v1) * 0.5

    def B(uc, vc, w, h, d, extra=0.0):
        ctr = c + u * uc + up * vc + n * (d * 0.5 + extra)
        box(bm, ctr, (d, w, h) if abs(n.x) > 0.5 else (w, d, h))
    B(0, v1 - 0.09, W, 0.18, 0.24)
    B(0, v0 + 0.09, W, 0.18, 0.24)
    B(-half_u + 0.09, pc, 0.18, ph, 0.24)
    B(half_u - 0.09, pc, 0.18, ph, 0.24)
    B(0, pc, W - 0.3, ph - 0.3, 0.05)                         # the set-back field
    run = W - 1.4
    steps = count
    sw = run / steps
    for i in range(steps):
        uu = -run / 2 + sw * (i + 0.5)
        hh = 0.12 + climb * (i / max(1, steps - 1))
        B(uu, v0 + 0.18 + hh * 0.5, sw * 0.99, hh, 0.2)
        org = c + u * (uu - sw * 0.1) + up * (v0 + 0.18 + hh) + n * 0.2
        pilgrim(bm, org, u, n, h=1.45 + 0.08 * rnd.random(), depth=0.85, lean=0.08 + 0.05 * rnd.random(), pack=(i % 3 == 1), rnd=rnd, raised=(i == count - 1))
    top = c + u * (run / 2 + 0.4) + up * (v0 + 0.18 + 0.12 + climb + 0.95) + n * 0.12
    for k in range(4):
        a = math.pi / 4 * k
        d = u * math.cos(a) + up * math.sin(a)
        seg_tube(bm, top - d * 0.34, top + d * 0.34, 0.05, 0.02, 4)


BOXES = []


def build_base(P):
    """Low pedestal: plain boxes (the baked normal map carries the masonry), cornice, corner posts, reliefs, runes."""
    bm = P.of("base")
    tb = P.of("tier")
    BOXES.clear()

    def tbox(c, size):
        BOXES.append((Vector(c), tuple(size)))
        box(tb, c, size)
    for name, hx, hy, z0, z1 in TIERS:
        tbox((0, 0, (z0 + z1) / 2), (2 * hx, 2 * hy, z1 - z0))
    # a stepped cornice: a second, lower moulding under the top slab, and the corner posts
    tbox((0, 0, 4.85), (2 * 5.9, 2 * 5.6, 0.3))
    for sx in (-1, 1):
        for sy in (-1, 1):
            tbox((sx * 5.4, sy * 5.1, 3.4), (0.7, 0.7, 3.2))
            tbox((sx * 5.4, sy * 5.1, 5.15), (0.95, 0.95, 0.3))
    panel(bm, "+y", 4.3, 2.1, 4.7, 8, 1)
    panel(bm, "-y", 4.3, 2.1, 4.7, 8, 2)
    panel(bm, "+x", 3.5, 2.1, 4.7, 6, 3)
    panel(bm, "-x", 3.5, 2.1, 4.7, 6, 4)
    # runes round the step tier
    rnd = random.Random(9)
    for face, (n, u) in FACES.items():
        t = [x for x in TIERS if x[0] == "step"][0]
        off = t[2] if face[1] == 'y' else t[1]
        span = (t[1] if face[1] == 'y' else t[2]) - 0.8
        for i in range(34):
            uu = -span + 2 * span * i / 33
            w, h = 0.1, rnd.uniform(0.18, 0.36)
            ctr = n * (off + 0.03) + u * uu + Vector((0, 0, 1.5))
            if abs(n.x) > 0.5:
                box(bm, ctr, (0.07, w, h))
            else:
                box(bm, ctr, (w, 0.07, h))
            if rnd.random() < 0.4:
                ctr2 = ctr + Vector((0, 0, rnd.choice((-1, 1)) * 0.24))
                if abs(n.x) > 0.5:
                    box(bm, ctr2, (0.07, 0.2, 0.06))
                else:
                    box(bm, ctr2, (0.2, 0.07, 0.06))
    # the foot tier is a ring of laid blocks: skirts
    return bm


# ============================================================================================
# DRIVER (geometry stage)
# ============================================================================================
def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def preview(objs, tag="g", views=None, size=(1280, 960)):
    """Workbench renders (flat material colours, studio light) to PREVIEW/<tag>_<view>.png."""
    os.makedirs(PREVIEW, exist_ok=True)
    cols = {"stone": (0.62, 0.6, 0.57, 1), "iron": (0.12, 0.12, 0.14, 1), "orb": (0.7, 0.5, 1.0, 1)}
    for m in bpy.data.materials:
        m.diffuse_color = cols.get(m.name, (0.6, 0.6, 0.6, 1))
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_WORKBENCH'
    sc.render.resolution_x, sc.render.resolution_y = size
    sh = sc.display.shading
    sh.color_type = 'MATERIAL'
    sh.light = 'STUDIO'
    sh.show_cavity = True
    sh.cavity_type = 'BOTH'
    sh.show_shadows = True
    sc.world = bpy.data.worlds.new("pv")
    sc.world.color = (0.2, 0.22, 0.28)
    cd = bpy.data.cameras.new("cam")
    cam = bpy.data.objects.new("cam", cd)
    sc.collection.objects.link(cam)
    sc.camera = cam
    cd.clip_end = 800
    views = views or [("front", (0, 105, 20), (0, 0, 17), 70), ("q3", (74, 70, 28), (0, 0, 16), 65), ("side", (105, 0, 20), (0, 0, 17), 70),
                      ("head", (-6, 40, 27), (-1.5, 1.5, 24), 45), ("hand", (-16, 26, 22), (-7, 2.6, 21), 45), ("base", (0, 30, 6), (0, 0, 4), 40)]
    for name, loc, tgt, lens in views:
        cam.location = Vector(loc)
        cam.rotation_euler = (Vector(tgt) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
        cd.lens = lens
        sc.render.filepath = os.path.join(PREVIEW, "%s_%s.png" % (tag, name))
        bpy.ops.render.render(write_still=True)



def masonry(P, rnd):
    """Laid courses of dressed blocks on the tiers (real geometry: the joints, the chips, a few cracked and shifted)."""
    bm = P.of("mason")
    thick = 0.09
    bands = {"foot": [(0.0, 0.9)], "step": [(0.9, 1.8)], "plinth": [(1.8, 2.1), (4.7, 5.0)], "cornice": [(5.0, 5.6)]}
    for name, hx, hy, z0, z1 in TIERS:
        for face, (n, u) in FACES.items():
            half = hy if face[1] == 'y' else hx
            span = (hx if face[1] == 'y' else hy - thick)
            for za, zb in bands[name]:
                x = -span
                while x < span - 0.1:
                    w = rnd.uniform(1.9, 2.8)
                    if span - (x + w) < 1.1:
                        w = span - x
                    h = zb - za
                    ctr = n * (half + thick / 2 - 0.02) + u * (x + w / 2) + Vector((0, 0, (za + zb) / 2))
                    sz = (w - 0.07, thick, h - 0.07)
                    sz = (thick, w - 0.07, h - 0.07) if abs(n.x) > 0.5 else sz
                    yaw = rnd.uniform(-0.006, 0.006)
                    if rnd.random() < 0.13:                  # cracked through and shifted
                        f = rnd.uniform(0.35, 0.65)
                        for part, (a0, a1) in enumerate(((0.0, f), (f, 1.0))):
                            c2 = ctr + u * ((a0 + a1) / 2 - 0.5) * w + Vector((0, 0, -0.03 * part)) + n * (0.015 * part)
                            ww = (a1 - a0) * w - 0.07
                            sz2 = (ww, thick, h - 0.07) if abs(n.x) < 0.5 else (thick, ww, h - 0.07)
                            box(bm, c2, sz2, yaw=yaw + 0.01 * part)
                    else:
                        box(bm, ctr, sz, yaw=yaw)
                    x += w
    # the treads: paving on the foot and step tops, and on the cornice's top
    for name, ho, hi_, z in (("foot", (7.4, 7.2), (6.6, 6.3), 0.9), ("step", (6.6, 6.3), (5.6, 5.3), 1.8), ("cornice", (6.1, 5.8), (0.0, 0.0), 5.6)):
        rects = []
        if name == "cornice":
            rects.append((-ho[0], ho[0], -ho[1], ho[1]))
        else:
            rects += [(-ho[0], ho[0], hi_[1], ho[1]), (-ho[0], ho[0], -ho[1], -hi_[1]), (hi_[0], ho[0], -hi_[1], hi_[1]), (-ho[0], -hi_[0], -hi_[1], hi_[1])]
        for x0, x1, y0, y1 in rects:
            xs = [x0]
            while xs[-1] < x1 - 0.05:
                xs.append(min(x1, xs[-1] + rnd.uniform(2.0, 3.0)))
            ys = [y0]
            while ys[-1] < y1 - 0.05:
                ys.append(min(y1, ys[-1] + rnd.uniform(1.6, 2.4)))
            for i in range(len(xs) - 1):
                for j in range(len(ys) - 1):
                    if xs[i + 1] - xs[i] < 0.2 or ys[j + 1] - ys[j] < 0.2:
                        continue
                    box(bm, ((xs[i] + xs[i + 1]) / 2, (ys[j] + ys[j + 1]) / 2, z + 0.03), (xs[i + 1] - xs[i] - 0.07, ys[j + 1] - ys[j] - 0.07, 0.09), yaw=rnd.uniform(-0.005, 0.005))


def box_uv_and_paint(bm, seed, tile=4.0, smooth=False, paint=True):
    """Metric box UVs (a tile is `tile` metres) and the baked albedo as vertex colours."""
    bm.normal_update()
    uv = bm.loops.layers.uv.new("UVMap")
    col = bm.loops.layers.color.new("Col")
    co = np.array([v.co[:] for v in bm.verts])
    nr = np.array([v.normal[:] for v in bm.verts])
    cc = stone_color(co, nr, np.ones(len(co)), seed=seed) if paint else np.full((len(co), 3), 0.85)
    for f in bm.faces:
        n = f.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        for l in f.loops:
            c = l.vert.co
            l[uv].uv = ((c.y, c.z) if ax == 0 else (c.x, c.z) if ax == 1 else (c.x, c.y))
            l[uv].uv = (l[uv].uv[0] / tile, l[uv].uv[1] / tile)
            k = cc[l.vert.index]
            l[col] = (k[0], k[1], k[2], 1.0)


# ============================================================================================
# DRIVER: scene, high-res detail, bake, collision, far mesh, export
# ============================================================================================
import numpy as np

FS = 0.72                         # the final scale of the whole monument (metres in Godot)
WATER_Z = 1.7                     # the pool's surface above the pedestal's foot (-15.5 vs -17.2)


def vnoise(P, f, seed):
    q = P * f + seed * 17.123
    fl = np.floor(q)
    u = q - fl
    i = fl.astype(np.int64)
    u = u * u * (3.0 - 2.0 * u)

    def h(dx, dy, dz):
        n = ((i[:, 0] + dx) * 73856093) ^ ((i[:, 1] + dy) * 19349663) ^ ((i[:, 2] + dz) * 83492791) ^ (seed * 2654435)
        n &= 0x7fffffff
        n = ((n ^ (n >> 13)) * 1274126177) & 0x7fffffff
        n ^= n >> 16
        return (n & 0xffff) / 65535.0
    ux, uy, uz = u[:, 0], u[:, 1], u[:, 2]
    c00 = h(0, 0, 0) * (1 - ux) + h(1, 0, 0) * ux
    c10 = h(0, 1, 0) * (1 - ux) + h(1, 1, 0) * ux
    c01 = h(0, 0, 1) * (1 - ux) + h(1, 0, 1) * ux
    c11 = h(0, 1, 1) * (1 - ux) + h(1, 1, 1) * ux
    return (c00 * (1 - uy) + c10 * uy) * (1 - uz) + (c01 * (1 - uy) + c11 * uy) * uz


def fbm_np(P, f, octaves, seed):
    s, a, n = 0.0, 1.0, 0.0
    for o in range(octaves):
        s = s + a * vnoise(P, f * (2.0 ** o), seed + o)
        n += a
        a *= 0.5
    return s / n


def sstep_np(a, b, x):
    t = np.clip((x - a) / (b - a + 1e-9), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def stone_detail(P, kind, seed=1):
    """Chisel marks, hairline cracks and, on the masonry, course joints and chipped arrises: metres along the normal."""
    chisel = (fbm_np(P, 2.2, 3, seed) - 0.5) * 0.06 + (fbm_np(P, 9.0, 3, seed + 3) - 0.5) * 0.03 + (vnoise(P, 30.0, seed + 5) - 0.5) * 0.012
    c = np.abs(vnoise(P, 0.42, seed + 7) - 0.5)
    crack = -0.1 * np.clip(1 - c / 0.014, 0, 1) ** 1.5
    c2 = np.abs(vnoise(P, 1.3, seed + 9) - 0.5)
    crack += -0.04 * np.clip(1 - c2 / 0.02, 0, 1) ** 1.5
    d = chisel + crack
    if kind == "tier":
        course = 0.9
        row = np.floor(P[:, 2] / course)
        along = P[:, 0] + P[:, 1] + row * 1.37
        bw = 2.3
        fr = np.abs(((along / bw) % 1.0) - 0.5) * 2.0                  # 0 at the block's middle, 1 at a joint
        fz = np.abs(((P[:, 2] / course) % 1.0) - 0.5) * 2.0
        joint = np.maximum(sstep_np(0.965, 1.0, fr), sstep_np(0.95, 1.0, fz))
        d = d - 0.055 * joint
        # chipped edges: noise that bites the lower corners and the blocks' arrises
        chip = sstep_np(0.62, 0.8, fbm_np(P, 1.4, 3, seed + 11)) * (joint * 0.8 + 0.2)
        d = d - 0.12 * chip * sstep_np(0.0, 0.3, 1.0 - fz * 0.0)
    return crack, d, c


def stone_color(P, N, crack_mask, z_foot_damp=True, seed=1):
    """Albedo for the high mesh: weathered grey stone, hairline cracks, lichen, moss, the waterline and its crust."""
    z = P[:, 2]
    base = 0.28 + 0.14 * fbm_np(P, 0.33, 4, seed + 20) + 0.07 * (fbm_np(P, 1.6, 3, seed + 21) - 0.5)
    col = np.stack([base * 1.02, base * 1.0, base * 0.97], axis=1)
    col *= (1.0 - 0.5 * np.clip(1 - crack_mask / 0.012, 0, 1))[:, None]
    nz = np.clip(N[:, 2], 0, 1)
    low = 1.0 - sstep_np(1.8, 9.0, z) * 0.75
    lich = sstep_np(0.55, 0.66, fbm_np(P, 0.62, 3, seed + 30)) * (0.2 + 0.8 * nz) * (0.25 + 0.75 * low)
    moss = sstep_np(0.6, 0.72, fbm_np(P, 1.7, 3, seed + 32)) * (0.1 + 0.9 * nz) * low
    col = col * (1 - 0.7 * lich[:, None]) + 0.7 * lich[:, None] * np.array([0.28, 0.35, 0.14])
    col = col * (1 - 0.6 * moss[:, None]) + 0.6 * moss[:, None] * np.array([0.34, 0.4, 0.16])
    # the waterline: damp and dark below it, a pale mineral crust band just above
    wl = WATER_Z + 0.25 * (fbm_np(P, 1.2, 3, seed + 40) - 0.5)
    damp = 1.0 - sstep_np(wl - 0.1, wl + 0.1, z)
    col *= (1.0 - 0.45 * damp)[:, None]
    crust = np.exp(-(((z - (wl + 0.35)) / 0.3) ** 2)) * sstep_np(0.4, 0.6, fbm_np(P, 2.0, 3, seed + 41))
    col = col * (1 - 0.55 * crust[:, None]) + 0.55 * crust[:, None] * np.array([0.58, 0.58, 0.66])
    # rain streaks running down the faces
    q = P * np.array([2.0, 2.0, 0.18])
    st = sstep_np(0.6, 0.8, fbm_np(q, 1.0, 3, seed + 50)) * (1 - nz)
    col *= (1.0 - 0.3 * st)[:, None]
    return np.clip(col, 0.02, 1.0)


def vertex_ao(P, N, polys, nrays=14, dist=6.0):
    """Ambient occlusion per vertex by ray casting against the mesh itself (BVH): cosine-weighted hemisphere."""
    from mathutils.bvhtree import BVHTree
    bvh = BVHTree.FromPolygons([tuple(v) for v in P.tolist()], polys)
    golden = 2.399963
    dirs = []
    for k in range(nrays):
        r = math.sqrt((k + 0.5) / nrays)
        a = k * golden
        dirs.append((r * math.cos(a), r * math.sin(a), math.sqrt(max(0.0, 1 - r * r))))
    out = np.ones(len(P))
    rnd = random.Random(4)
    for i in range(len(P)):
        n = Vector(N[i])
        t = n.cross(Vector((0, 0, 1)) if abs(n.z) < 0.9 else Vector((1, 0, 0)))
        if t.length < 1e-6:
            continue
        t.normalize()
        b = n.cross(t)
        sp = rnd.random() * 6.283
        cs, sn = math.cos(sp), math.sin(sp)
        o = Vector(P[i]) + n * 0.03
        hit = 0.0
        for lx, ly, lz in dirs:
            x, y = lx * cs - ly * sn, lx * sn + ly * cs
            h = bvh.ray_cast(o, t * x + b * y + n * lz, dist)
            if h[0] is not None:
                hit += 1.0 - 0.55 * h[3] / dist
        out[i] = max(0.0, 1.0 - hit / nrays)
    return out


def mesh_np(me):
    n = len(me.vertices)
    co = np.empty(n * 3, dtype=np.float32)
    me.vertices.foreach_get("co", co)
    nr = np.empty(n * 3, dtype=np.float32)
    me.vertex_normals.foreach_get("vector", nr)
    return co.reshape(-1, 3).astype(np.float64), nr.reshape(-1, 3).astype(np.float64)


def grid_boxes(boxes, step):
    """The masonry boxes as gridded quads (six faces each) for displacement: returns a Mesh."""
    verts, faces, edge = [], [], []
    for c, size in boxes:
        hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
        for axis in range(3):
            for sgn in (-1, 1):
                a1, a2 = [(1, 2), (0, 2), (0, 1)][axis]
                h = (hx, hy, hz)
                n1 = max(2, int(round(2 * h[a1] / step)))
                n2 = max(2, int(round(2 * h[a2] / step)))
                base = len(verts)
                for i in range(n1 + 1):
                    for j in range(n2 + 1):
                        p = [0.0, 0.0, 0.0]
                        p[axis] = sgn * h[axis]
                        p[a1] = -h[a1] + 2 * h[a1] * i / n1
                        p[a2] = -h[a2] + 2 * h[a2] * j / n2
                        verts.append((c[0] + p[0], c[1] + p[1], c[2] + p[2]))
                        edge.append(min(h[a1] - abs(p[a1]), h[a2] - abs(p[a2])))
                for i in range(n1):
                    for j in range(n2):
                        v0 = base + i * (n2 + 1) + j
                        q = (v0, v0 + 1, v0 + n2 + 2, v0 + n2 + 1)
                        faces.append(q if -sgn * (1, -1, 1)[axis] > 0 else q[::-1])
    me = bpy.data.meshes.new("grid")
    me.from_pydata(verts, [], faces)
    return me, np.array(edge)


def detailed(low_me, name, kind, mat_key, seed, boxes=None, extra_me=None):
    """The high-poly twin of a low mesh: subdivided, chiselled, cracked, coloured (vertex colour 'Col')."""
    if kind == "tier":
        me, edge_d = grid_boxes(boxes, HI_STEP)
        # pilgrims, frames, runes at their own resolution
        if extra_me is not None:
            tmp = bmesh.new()
            tmp.from_mesh(me)
            tmp.from_mesh(extra_me)
            tmp.to_mesh(me)
            tmp.free()
    else:
        ob0 = bpy.data.objects.new("tmp_low", low_me)
        bpy.context.scene.collection.objects.link(ob0)
        md = ob0.modifiers.new("sub", 'SUBSURF')
        md.levels = 2
        md.render_levels = 2
        dg = bpy.context.evaluated_depsgraph_get()
        me = bpy.data.meshes.new_from_object(ob0.evaluated_get(dg))
        bpy.data.objects.remove(ob0)
    P, N = mesh_np(me)
    n_t = len(P)
    if kind == "tier":
        # the extra (relief) vertices are kept unmodified: displace only the gridded boxes
        ng = len(P) - (len(extra_me.vertices) if extra_me is not None else 0)
    else:
        ng = n_t
    crack, d, craw = stone_detail(P[:ng], kind if kind == "tier" else "fig", seed)
    P2 = P.copy()
    if kind == "tier":
        d = d * sstep_np(0.0, 0.12, edge_d)
    P2[:ng] += N[:ng] * d[:, None]
    col = np.ones((n_t, 4))
    col[:, :3] = stone_color(P2, N, craw if True else crack, seed=seed) if kind != "tier" else stone_color(P2, N, np.concatenate([craw, np.ones(n_t - ng)]), seed=seed)
    me.vertices.foreach_set("co", P2.astype(np.float32).ravel())
    me.update()
    ca = me.color_attributes.new("Col", 'FLOAT_COLOR', 'POINT')
    ca.data.foreach_set("color", col.astype(np.float32).ravel())
    if kind != "tier":
        polys = [tuple(p_.vertices) for p_ in me.polygons]
        ao = vertex_ao(P2, N, polys)
        aoc = np.ones((n_t, 4))
        aoc[:, 0] = aoc[:, 1] = aoc[:, 2] = np.clip(ao ** 1.2, 0.22, 1.0)
        a2 = me.color_attributes.new("AO", 'FLOAT_COLOR', 'POINT')
        a2.data.foreach_set("color", aoc.astype(np.float32).ravel())
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    for p_ in me.polygons:
        p_.use_smooth = True
    emit = bpy.data.materials.new(name + "_emit")
    emit.use_nodes = True
    nt = emit.node_tree
    nt.nodes.clear()
    a = nt.nodes.new('ShaderNodeAttribute')
    a.attribute_name = "Col"
    e = nt.nodes.new('ShaderNodeEmission')
    o = nt.nodes.new('ShaderNodeOutputMaterial')
    nt.links.new(a.outputs['Color'], e.inputs['Color'])
    nt.links.new(e.outputs['Emission'], o.inputs['Surface'])
    me.materials.clear()
    me.materials.append(emit)
    return ob


def unwrap(ob, margin=0.003):
    bpy.ops.object.select_all(action='DESELECT')
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.unwrap(method='CONFORMAL', margin=margin)
    bpy.ops.uv.average_islands_scale()
    bpy.ops.uv.pack_islands(margin=margin)
    bpy.ops.object.mode_set(mode='OBJECT')


def write_png(path, rgb):
    """A minimal RGB PNG writer (rows top to bottom)."""
    import zlib
    import struct
    h, w, _ = rgb.shape
    raw = b"".join(b"\x00" + rgb[y].tobytes() for y in range(h))

    def chunk(t, d):
        c = struct.pack(">I", len(d)) + t + d
        return c + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw, 6)) + chunk(b"IEND", b""))


def bake_pair(low, high, tag, size):
    """normal, ao, albedo from `high` onto `low`'s UVs -> PNGs; returns the written paths."""
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.device = 'CPU'
    sc.cycles.use_denoising = False
    bk = sc.render.bake
    bk.use_selected_to_active = True
    bk.cage_extrusion = 0.4
    bk.max_ray_distance = 1.2
    bk.margin = 12
    bk.target = 'IMAGE_TEXTURES'
    paths = {}
    mat = bpy.data.materials.new("bake_" + tag)
    mat.use_nodes = True
    low.data.materials.clear()
    low.data.materials.append(mat)
    nt = mat.node_tree
    img_node = nt.nodes.new('ShaderNodeTexImage')
    hmat = high.data.materials[0]
    himg = hmat.node_tree.nodes.new('ShaderNodeTexImage')
    for kind, btype, samples in (("normal", 'NORMAL', 8), ("ao", 'AO', 48), ("albedo", 'EMIT', 1)):
        img = bpy.data.images.new("%s_%s" % (tag, kind), size, size, alpha=False, float_buffer=False)
        img.generated_color = {"normal": (0.5, 0.5, 1.0, 1.0), "ao": (1, 1, 1, 1), "albedo": (0.3, 0.3, 0.3, 1)}[kind]
        img.colorspace_settings.name = 'sRGB' if kind == "albedo" else 'Non-Color'
        sc.cycles.samples = samples
        bpy.ops.object.select_all(action='DESELECT')
        if kind == "normal":
            img_node.image = img
            nt.nodes.active = img_node
            bk.use_selected_to_active = True
            high.select_set(True)
            low.select_set(True)
            bpy.context.view_layer.objects.active = low
            bpy.ops.object.bake(type='NORMAL', normal_space='TANGENT')
        else:
            # self bake on the high mesh (it carries the low mesh's UVs): the low mesh is out of the scene
            himg.image = img
            hmat.node_tree.nodes.active = himg
            bk.use_selected_to_active = False
            low.hide_render = True
            high.select_set(True)
            bpy.context.view_layer.objects.active = high
            for nd in hmat.node_tree.nodes:
                if nd.bl_idname == 'ShaderNodeAttribute':
                    nd.attribute_name = "AO" if kind == "ao" else "Col"
            bpy.ops.object.bake(type='EMIT')
            low.hide_render = False
        if kind == "ao":
            a = np.empty(size * size * 4, dtype=np.float32)
            img.pixels.foreach_get(a)
            a = a.reshape(-1, 4)
            print("AO mean", float(a[:, 0].mean()))
            orm = np.ones_like(a)
            orm[:, 0] = a[:, 0]
            orm[:, 1] = 0.78 + 0.2 * (1.0 - a[:, 0])
            orm[:, 2] = 0.0
            write_png(os.path.join(OUT, "watchers_%s_orm.png" % tag), (np.clip(orm[:, :3], 0, 1) * 255).astype(np.uint8).reshape(size, size, 3)[::-1])
        path = os.path.join(OUT, "watchers_%s_%s.png" % (tag, kind))
        img.filepath_raw = path
        img.file_format = 'PNG'
        img.save()
        paths[kind] = path
        print("BAKED", path)
    return paths


def make_orm(tag):
    """Pack R = ambient occlusion, G = roughness (a little lower on the lit faces), B = 0 into one PNG."""
    ao = bpy.data.images.load(os.path.join(OUT, "watchers_%s_ao.png" % tag), check_existing=False)
    w, h = ao.size
    a = np.empty(w * h * 4, dtype=np.float32)
    ao.pixels.foreach_get(a)
    a = a.reshape(-1, 4)
    orm = np.ones_like(a)
    orm[:, 0] = a[:, 0]
    orm[:, 1] = 0.78 + 0.2 * (1.0 - a[:, 0])
    orm[:, 2] = 0.0
    img = bpy.data.images.new("orm_" + tag, w, h, alpha=False)
    img.pixels.foreach_set(orm.ravel())
    img.colorspace_settings.name = 'Non-Color'
    img.filepath_raw = os.path.join(OUT, "watchers_%s_orm.png" % tag)
    img.file_format = 'PNG'
    img.save()


def mk_object(bm, name, smooth, mat):
    for f in bm.faces:
        f.smooth = smooth
    bm.normal_update()
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    m = bpy.data.materials.get(mat) or bpy.data.materials.new(mat)
    me.materials.append(m)
    return ob


def tris(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


def build_all():
    P = Parts()
    build_figure(P)
    build_staff(P)
    build_pennant(P)
    for key in ("fig", "iron", "orb"):
        translate(P.of(key), (0, 0, PED_H))
    build_base(P)
    return P


def rubble(seed, mirror):
    """Fallen pieces in the pool: worn blocks, a snapped hood tip, a broken finger: one tiled-stone mesh."""
    rnd = random.Random(seed)
    bm = bmesh.new()
    spots = [(-9.8, 4.0, 0.8), (-8.6, -6.9, 0.6), (9.4, 6.2, 0.7), (8.9, -7.4, 0.9), (0.5, 8.9, 0.6), (-4.2, 8.6, 0.5), (5.6, 9.5, 0.7), (-10.4, -1.2, 0.5), (10.6, -1.5, 0.6),
             (2.0, -9.0, 0.7), (-6.5, 9.7, 0.4), (7.5, -9.6, 0.5)]
    for (x, y, r) in spots:
        r *= rnd.uniform(0.9, 1.6)
        sub = bmesh.new()
        pts = []
        sx, sy, sz = rnd.uniform(0.8, 1.6), rnd.uniform(0.7, 1.3), rnd.uniform(0.5, 0.9)
        for _ in range(16):
            v = Vector((rnd.choice((-1, 1)) * rnd.uniform(0.75, 1.0) * sx, rnd.choice((-1, 1)) * rnd.uniform(0.75, 1.0) * sy, rnd.choice((-1, 1)) * rnd.uniform(0.7, 1.0) * sz)) * r
            pts.append(v)
        for v in pts:
            sub.verts.new(v)
        bmesh.ops.convex_hull(sub, input=sub.verts)
        rot = Matrix.Rotation(rnd.uniform(0, 3), 4, 'Z') @ Matrix.Rotation(rnd.uniform(-0.4, 0.4), 4, 'X')
        zbase = rnd.uniform(-0.1, 0.3)
        mp = {v: bm.verts.new(rot @ v.co + Vector((x, y, zbase + r * 0.4))) for v in sub.verts}
        for f in sub.faces:
            bm.faces.new([mp[v] for v in f.verts])
        sub.free()
    # the snapped hood tip: a cone lying on its side
    tip = Vector((-7.5, -3.5, 0.9))
    tube(bm, [tip, tip + Vector((2.4, 1.2, 0.2)), tip + Vector((4.6, 2.2, 0.5))], [0.1, 0.9, 1.25], 9)
    # the broken finger: a stone cylinder
    fp = Vector((8.2, 3.6, 0.55))
    tube(bm, [fp, fp + Vector((-1.1, 0.5, 0.0)), fp + Vector((-2.2, 0.9, 0.05))], [0.4, 0.42, 0.4], 8)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if mirror:
        for v in bm.verts:
            v.co.x = -v.co.x
        bmesh.ops.reverse_faces(bm, faces=bm.faces)
    box_uv_and_paint(bm, seed)
    return bm


def hull_obj(name, verts):
    bm = bmesh.new()
    for v in verts:
        bm.verts.new(v)
    bmesh.ops.convex_hull(bm, input=bm.verts)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def collision_hulls(fig_low, boxes):
    """A few convex hulls: the masonry's tiers, the robe and mantle, the hood, the raised arm, the staff hand's arm, the staff."""
    objs = []
    for i, (c, size) in enumerate(boxes[:4]):
        hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
        objs.append(hull_obj("Watcher_tier%d-convcolonly" % i, [Vector((c.x + sx * hx, c.y + sy * hy, c.z + sz * hz)) for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)]))
    vs = [v.co.copy() for v in fig_low.data.vertices]
    body = [v for v in vs if v.z < PED_H + 13.2 * STR and v.z > PED_H - 0.2 and abs(v.x) < 5.3 and v.y < 4.2]
    objs.append(hull_obj("Watcher_robe-convcolonly", body[::3]))
    hood = [v for v in vs if v.z > PED_H + 12.3 * STR and abs(v.x) < 3.8 and -3.6 < v.y < 4.4 and v.z < PED_H + 20.2 * STR]
    objs.append(hull_obj("Watcher_hood-convcolonly", hood[::2]))
    hands = [v for v in vs if abs(v.x) < 3.4 and v.y > 3.0 and PED_H + 9.0 < v.z < PED_H + 17.5]
    objs.append(hull_obj("Watcher_hands-convcolonly", hands[::2]))
    # the staff
    st = []
    for z in (0.0, 28.0):
        for k in range(8):
            a = math.tau * k / 8
            st.append(Vector((STAFF.x + math.cos(a) * 0.62, STAFF.y + math.sin(a) * 0.62, PED_H + z)))
    objs.append(hull_obj("Watcher_staff-convcolonly", st))
    lan = []
    for z in (LANT0, LANT1 + 2.4):
        for k in range(10):
            a = math.tau * k / 10
            lan.append(Vector((STAFF.x + math.cos(a) * 2.2, STAFF.y + math.sin(a) * 2.2, PED_H + z)))
    objs.append(hull_obj("Watcher_lantern-convcolonly", lan))
    return objs


def far_set(fig, base_boxes):
    """The far mesh (>150 m): the figure decimated, a low masonry stack, a thin staff, the cage as a rhombus."""
    f = fig.copy()
    f.data = fig.data.copy()
    f.name = "Watcher_fig_far"
    bpy.context.scene.collection.objects.link(f)
    bpy.context.view_layer.objects.active = f
    md = f.modifiers.new("d", 'DECIMATE')
    md.ratio = 1100.0 / max(1, tris(f))
    bpy.ops.object.modifier_apply(modifier=md.name)
    bm = bmesh.new()
    for c, size in base_boxes[:3]:
        box(bm, c, size)
    me = bpy.data.meshes.new("Watcher_base_far")
    bm.to_mesh(me)
    b = bpy.data.objects.new("Watcher_base_far", me)
    bpy.context.scene.collection.objects.link(b)
    bm2 = bmesh.new()
    sx, sy = STAFF.x, STAFF.y
    tube(bm2, [Vector((sx, sy, PED_H)), Vector((sx, sy, PED_H + LANT0)), Vector((sx, sy, PED_H + LANT1)), Vector((sx, sy, PED_H + LANT1 + 4.2))], [0.6, 0.5, 2.0, 0.05], 6, True, True)
    ring3(bm2, (sx, sy, PED_H + ORB_Z), (0, 0, 1), 1.9, 0.2, 12, 4)
    ring3(bm2, (sx, sy, PED_H + ORB_Z), (1, 0, 0), 1.9, 0.2, 12, 4)
    ring3(bm2, (sx, sy, PED_H + ORB_Z), (0, 1, 0), 1.9, 0.2, 12, 4)
    me2 = bpy.data.meshes.new("Watcher_iron_far")
    bm2.to_mesh(me2)
    i = bpy.data.objects.new("Watcher_iron_far", me2)
    bpy.context.scene.collection.objects.link(i)
    for ob, k in ((b, "stone"), (i, "iron")):
        ob.data.materials.append(bpy.data.materials.get(k) or bpy.data.materials.new(k))
    f.data.materials.clear()
    f.data.materials.append(bpy.data.materials.get("stone"))
    return [f, b, i]


def scale_objs(objs, s):
    for o in objs:
        for v in o.data.vertices:
            v.co *= s
        o.data.update()


def mirror_objs(objs):
    for o in objs:
        for v in o.data.vertices:
            v.co.x = -v.co.x
        o.data.flip_normals()
        o.data.update()


def export_glb(objs, path):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    kw = dict(filepath=path, export_format='GLB', use_selection=True, export_apply=True, export_yup=True,
              export_materials='EXPORT', export_image_format='NONE', export_normals=True, export_texcoords=True, export_tangents=True)
    try:
        bpy.ops.export_scene.gltf(export_vertex_color='ACTIVE', **kw)
    except TypeError:
        bpy.ops.export_scene.gltf(**kw)
    print("EXPORTED", path, "%d tris" % sum(tris(o) for o in objs if "colonly" not in o.name))


def lit_render(objs_hide, tag, views, size=(1280, 960), samples=48):
    """Cycles stills with the baked maps on the figure, a violet pool light below and a cold moon behind."""
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.device = 'CPU'
    sc.cycles.samples = samples
    sc.cycles.use_denoising = True
    sc.render.resolution_x, sc.render.resolution_y = size
    sc.world = bpy.data.worlds.new("w")
    sc.world.use_nodes = True
    sc.world.node_tree.nodes["Background"].inputs[0].default_value = (0.03, 0.04, 0.09, 1)
    sc.world.node_tree.nodes["Background"].inputs[1].default_value = 1.0
    for o in objs_hide:
        o.hide_render = True
    lights = [("moon", 'SUN', (0, 0, 0), (math.radians(50), 0, math.radians(200)), 3.0, (0.55, 0.65, 1.0)),
              ("pool", 'AREA', (0, 22, -2), (math.radians(105), 0, 0), 26000.0, (0.55, 0.38, 1.0)),
              ("fire", 'AREA', (-30, 30, 8), (math.radians(80), 0, math.radians(-40)), 2500.0, (1.0, 0.6, 0.3))]
    for n, t, loc, rot, e, c in lights:
        ld = bpy.data.lights.new(n, t)
        ld.energy = e
        ld.color = c
        if t == 'AREA':
            ld.size = 14.0
        lo = bpy.data.objects.new(n, ld)
        lo.location = loc
        lo.rotation_euler = rot
        sc.collection.objects.link(lo)
    cd = bpy.data.cameras.new("cam")
    cam = bpy.data.objects.new("cam", cd)
    sc.collection.objects.link(cam)
    sc.camera = cam
    cd.clip_end = 900
    for name, loc, tgt, lens in views:
        cam.location = Vector(loc)
        cam.rotation_euler = (Vector(tgt) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
        cd.lens = lens
        sc.render.filepath = os.path.join(PREVIEW, "%s_%s.png" % (tag, name))
        bpy.ops.render.render(write_still=True)


def textured_materials(tag_by_obj):
    """Principled materials using the baked maps: for the Blender-side review renders."""
    for ob, tag in tag_by_obj:
        m = bpy.data.materials.new("pv_" + tag)
        m.use_nodes = True
        nt = m.node_tree
        bs = nt.nodes["Principled BSDF"]
        al = nt.nodes.new('ShaderNodeTexImage')
        al.image = bpy.data.images.load(os.path.join(OUT, "watchers_%s_albedo.png" % tag))
        nm = nt.nodes.new('ShaderNodeTexImage')
        nm.image = bpy.data.images.load(os.path.join(OUT, "watchers_%s_normal.png" % tag))
        nm.image.colorspace_settings.name = 'Non-Color'
        orm = nt.nodes.new('ShaderNodeTexImage')
        orm.image = bpy.data.images.load(os.path.join(OUT, "watchers_%s_orm.png" % tag))
        orm.image.colorspace_settings.name = 'Non-Color'
        nmap = nt.nodes.new('ShaderNodeNormalMap')
        mul = nt.nodes.new('ShaderNodeMix')
        mul.data_type = 'RGBA'
        mul.blend_type = 'MULTIPLY'
        mul.inputs[0].default_value = 1.0
        sep = nt.nodes.new('ShaderNodeSeparateColor')
        if arg("--dbg") == "albedo":
            nt.links.new(al.outputs['Color'], bs.inputs['Base Color'])
            ob.data.materials.clear()
            ob.data.materials.append(m)
            continue
        nt.links.new(al.outputs['Color'], mul.inputs[6])
        nt.links.new(orm.outputs['Color'], sep.inputs[0])
        nt.links.new(sep.outputs[0], mul.inputs[7])
        nt.links.new(mul.outputs[2], bs.inputs['Base Color'])
        nt.links.new(sep.outputs[1], bs.inputs['Roughness'])
        nt.links.new(nm.outputs['Color'], nmap.inputs['Color'])
        if arg('--dbg') != 'nonormal':
            nt.links.new(nmap.outputs['Normal'], bs.inputs['Normal'])
        ob.data.materials.clear()
        ob.data.materials.append(m)


def main():
    os.makedirs(OUT, exist_ok=True)
    reset()
    P = build_all()
    bm_fig, bm_base, bm_tier = P.bm["fig"], P.bm["base"], P.bm["tier"]
    boxes = list(BOXES)
    fig = mk_object(bm_fig, "Watcher_fig", True, "stone")
    # the pedestal: the masonry core, the laid blocks (one subdivision, for the colour) and the reliefs, one mesh
    masonry(P, random.Random(5))
    bm_m = P.of("mason")
    bmesh.ops.subdivide_edges(bm_m, edges=bm_m.edges[:], cuts=1, use_grid_fill=True)
    bm_low_base = bmesh.new()
    for src in (bm_tier, bm_m, bm_base):
        tmp = bpy.data.meshes.new("tmp")
        src.to_mesh(tmp)
        bm_low_base.from_mesh(tmp)
    box_uv_and_paint(bm_low_base, 2)
    base = mk_object(bm_low_base, "Watcher_base", False, "stone")
    box_uv_and_paint(P.bm["iron"], 3, 2.0, paint=False)
    iron = mk_object(P.bm["iron"], "Watcher_iron", True, "iron")
    orb = mk_object(P.bm["orb"], "Watcher_orb", True, "orb")
    print("TRIS fig %d base %d iron %d orb %d" % (tris(fig), tris(base), tris(iron), tris(orb)))
    if "nobake" in args or NOBAKE:
        if PREVIEW:
            preview([fig, base, iron, orb])
        return
    do_fig = "figure" in PARTS
    do_base = False
    reuse = "--reuse" in args
    if do_fig:
        unwrap(fig)
        if not reuse:
            hi_fig = detailed(fig.data, "hi_fig", "fig", "stone", 1)
            print("HI fig verts", len(hi_fig.data.vertices))
    if do_base:
        unwrap(base)
        hi_base = detailed(None, "hi_base", "tier", "stone", 2, boxes=boxes, extra_me=mp_extra)
        print("HI base verts", len(hi_base.data.vertices))
    if do_fig and not reuse:
        bake_pair(fig, hi_fig, "fig", TEX)
        bpy.data.objects.remove(hi_fig)
    if do_base:
        bake_pair(base, hi_base, "base", TEX)
        make_orm("base")
        bpy.data.objects.remove(hi_base)
    # export west and east
    objs = [fig, base, iron, orb]
    collisions = collision_hulls(fig, boxes)
    far = far_set(fig, boxes)
    rub_w = mk_object(rubble(3, False), "Watcher_rubble", False, "stone")
    for o in objs + collisions + far + [rub_w]:
        for v in o.data.vertices:
            v.co *= FS
        o.data.update()
    orb.data.materials.clear()
    orb.data.materials.append(bpy.data.materials.get("orb") or bpy.data.materials.new("orb"))
    near_w = objs + [rub_w] + collisions
    export_glb(near_w, os.path.join(OUT, "watchers_west.glb"))
    export_glb(far, os.path.join(OUT, "watchers_west_far.glb"))
    if PREVIEW:
        textured_materials([(fig, "fig")])
        vc = bpy.data.materials.new("pv_base")
        vc.use_nodes = True
        an = vc.node_tree.nodes.new('ShaderNodeAttribute')
        an.attribute_name = "Col"
        vc.node_tree.links.new(an.outputs['Color'], vc.node_tree.nodes['Principled BSDF'].inputs['Base Color'])
        vc.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value = 0.85
        base.data.materials.clear()
        base.data.materials.append(vc)
        hide = collisions + far
        s = FS
        lit_render(hide, "lit", [
            ("front", (0, 130 * s, 24 * s), (0, 0, 20 * s), 65),
            ("q3", (92 * s, 88 * s, 34 * s), (0, 0, 20 * s), 62),
            ("side", (130 * s, 0, 24 * s), (0, 0, 20 * s), 65),
            ("head", (-8 * s, 52 * s, 34 * s), (0, 3 * s, 30 * s), 48),
            ("hands", (-10 * s, 40 * s, 26 * s), (0, 4.5 * s, 22 * s), 52),
            ("base", (0, 34 * s, 6 * s), (0, 0, 4 * s), 40)])
    # east: the mirrored mesh (the same maps), its own rubble
    mirror_objs(objs + collisions + far)
    rub_e = mk_object(rubble(7, True), "Watcher_rubble_e", False, "stone")
    for v in rub_e.data.vertices:
        v.co *= FS
    rub_w.name = "old_rubble"
    rub_e.name = "Watcher_rubble"
    rub_e.data.update()
    rub_w.hide_viewport = True
    export_glb([o for o in objs + collisions] + [rub_e], os.path.join(OUT, "watchers_east.glb"))
    export_glb(far, os.path.join(OUT, "watchers_east_far.glb"))


if __name__ == "__main__":
    main()
