"""The Thornwarden (r30): a stag-boar of the hedge on the Leaper's QuadRig -- a humped bark-shingled
body with moss in the seams and an ember heart splitting the chest, a bramble mane, a bone-white
deer-skull mask with embers in the sockets, a great branching antler crown wound with bramble,
heavy haunches, thick legs on splayed root feet. Baked into one atlas and split per socket.

  tools/blender/run.sh boss_thornwarden.py -- [--preview /tmp/thorn.png] [--no-export]
Writes art/models/boss_thornwarden.glb and art/textures/boss_thornwarden_*.png
"""
import bpy
import math
import os
import random
import sys
from mathutils import Vector, noise

sys.path.insert(0, os.path.dirname(__file__))
import boss_kit as K
import grunt_kit as GK
from boss_kit import G

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
PREVIEW = args[args.index("--preview") + 1] if "--preview" in args else ""
EXPORT = "--no-export" not in args
S = K.quad_sockets(0.56, 1.15, 0.2, 0.32)           # thornwarden.gd extends Leaper (leaper.gd _build)
rnd = random.Random(4417)

K.reset()


def bark_mat():
    m = K.Mat("Bark")
    sc = m.scan("bark_brown_02", 3.5)
    moss_n = m.noise(5.0, 6.0, 0.6)
    crev = m.math('LESS_THAN', sc["disp"], 0.35)
    moss = m.math('MULTIPLY', m.math('GREATER_THAN', moss_n, 0.55), m.math('ADD', crev, 0.25), True)
    col = m.mul(sc["color"], (0.5, 0.42, 0.37))
    col = m.mix(moss, col, (0.08, 0.14, 0.04))
    # r37: split bark chars black in its deepest fissures, and the heart's ember shows through them
    deep = m.math('LESS_THAN', sc["disp"], 0.2)
    char = m.math('MULTIPLY', deep, m.math('ADD', 0.35, m.noise(4.0, 3.0, 0.5)), True)
    col = m.mix(m.math('MULTIPLY', char, 0.8), col, (0.012, 0.008, 0.006))
    h = m.math('ADD', m.math('MULTIPLY', sc["disp"], 1.0), m.math('MULTIPLY', moss, 0.15))
    seam = m.math('MULTIPLY', m.math('LESS_THAN', sc["disp"], 0.09), m.math('GREATER_THAN', m.noise(3.0, 2.0, 0.5), 0.52))
    ember = m.mix(seam, (0.0, 0.0, 0.0), (1.0, 0.3, 0.05))
    return m.finish(col, m.math('ADD', m.math('MULTIPLY', sc["rough"], 0.4), 0.55), 0.0, h, 1.0, 0.008, emit=ember, emit_strength=2.4)


def bone_mat():
    m = K.Mat("Bone")
    sc = m.scan("beige_wall_001", 8.0)
    dirt = m.noise(8.0, 8.0, 0.6)
    crack = m.math('LESS_THAN', m.voronoi(30.0, 'DISTANCE_TO_EDGE'), 0.018)
    crack = m.math('MULTIPLY', crack, m.math('GREATER_THAN', m.noise(7.0, 3.0, 0.5), 0.5))
    col = m.mul(m.mono(sc["color"]), (1.25, 1.12, 0.9))
    col = m.mix(m.math('MULTIPLY', m.math('SUBTRACT', 1.0, dirt), 0.5), col, (0.4, 0.3, 0.2))
    col = m.mix(crack, col, (0.13, 0.09, 0.06))
    h = m.math('ADD', m.math('MULTIPLY', sc["disp"], 0.7), m.math('MULTIPLY', crack, -0.7))
    return m.finish(col, m.math('ADD', m.math('MULTIPLY', sc["rough"], 0.5), 0.3), 0.0, h, 0.8, 0.0025)


def hide_mat():
    m = K.Mat("Hide")
    sc = m.scan("brown_leather", 5.0)
    v = m.noise(6.0, 6.0, 0.6)
    col = m.mul(sc["color"], (0.26, 0.2, 0.17))
    moss = m.math('MULTIPLY', m.math('GREATER_THAN', m.noise(4.0, 6.0, 0.6), 0.62), m.math('GREATER_THAN', m.zpos(), 0.75))
    col = m.mix(moss, col, (0.08, 0.13, 0.04))
    col = m.mix(m.math('MULTIPLY', v, 0.3), col, (0.02, 0.012, 0.01))
    h = m.math('ADD', m.math('MULTIPLY', sc["disp"], 1.0), m.math('MULTIPLY', v, 0.2))
    return m.finish(col, m.math('ADD', m.math('MULTIPLY', sc["rough"], 0.5), 0.35), 0.0, h, 0.9, 0.005)


def ember_mat():
    m = K.Mat("Ember")
    v = m.noise(24.0, 4.0, 0.5)
    col = m.ramp(v, [(0.3, (1.0, 0.3, 0.05)), (0.8, (1.0, 0.65, 0.2))])
    return m.finish((0.05, 0.02, 0.01), 0.6, 0.0, None, emit=col, emit_strength=8.0)


BARK = bark_mat()
BONE = bone_mat()
HIDE = hide_mat()
EMBER = ember_mat()
MATS = [BARK, BONE, HIDE, EMBER]
objs = []


def add(o):
    objs.append(o)
    return o


B = S["body"]
# --- body: a deep chest and a hump at the withers, haunches, belly; bark shingles, an ember heart -------
# one blended mass (metaballs): deep chest and withers hump forward, a tucked barrel, heavy haunches
els = [(B + G(0, 0.05, -0.3), (0.3, 0.36, 0.28), 2.0), (B + G(0, 0.24, -0.32), (0.18, 0.24, 0.2), 2.0),
       (B + G(0, 0.02, 0.02), (0.24, 0.3, 0.23), 2.0), (B + G(0, 0.06, 0.32), (0.25, 0.24, 0.22), 2.0),
       (B + G(0, -0.12, -0.15), (0.17, 0.3, 0.12), 1.5)]
for tag, sx, z in (("fl", -1, -0.414), ("fr", 1, -0.414), ("bl", -1, 0.391), ("br", 1, 0.391)):
    els.append((B + G(sx * 0.2, 0.05, z), (0.15, 0.2, 0.2), 2.0))
add(K.meta_body("Body", els, "body", HIDE, 0.016, 0.012, 1.0))
# bark shingles, roof-tile rows from the spine down the flanks
for row in range(5):
    n = 16 - row * 2
    a = 0.12 + 0.3 * row
    for k in range(n):
        z = -0.55 + 1.05 * (k + 0.5 * (row % 2)) / n
        for sx in (-1, 1):
            hump = 0.15 * math.exp(-((z + 0.3) / 0.25) ** 2)
            base = B + G(sx * math.sin(a) * 0.27, 0.27 + hump - (1 - math.cos(a)) * 0.3, z)
            sz = (rnd.uniform(0.07, 0.11), rnd.uniform(0.08, 0.13), rnd.uniform(0.012, 0.02))
            from mathutils import Euler
            rot = Euler((0.25, sx * a * 1.1, rnd.uniform(-0.2, 0.2))).to_matrix()
            def warp(c, rot=rot, sz=sz):
                c = Vector((c.x, c.y, c.z + 0.5 * c.x * c.x))        # curved like a shingle
                c = Vector((c.x * sz[0], c.y * sz[1], c.z * sz[2]))
                return rot @ c
            add(K.blob("Shingle", base, (1.0, 1.0, 1.0), "body", BARK, 16, 8, warp))
# the bramble mane along the spine: twisted pairs of canes, barbed
for k in range(14):
    t = k / 13.0
    z = -0.6 + 1.0 * t
    hump = 0.15 * math.exp(-((z + 0.3) / 0.25) ** 2)
    root = B + G(0, 0.36 + hump, z)
    for side in (-1, 1):
        tip = root + G(side * 0.06, 0.16 + 0.06 * math.sin(t * 7), 0.12)
        add(K.loft("Cane", [root, root.lerp(tip, 0.5) + G(side * 0.02, 0.02, 0), tip], [0.016, 0.011, 0.0], "body", BARK, 8))
        add(K.loft("Barb", [root.lerp(tip, 0.4), root.lerp(tip, 0.4) + G(side * 0.04, 0.02, -0.02)], [0.005, 0.0], "body", BONE, 5))
# the ember heart: a split down the sternum between bark plates, lit inside
heart = [B + G(0, 0.25 - 0.06 * k, -0.6 - 0.02 * math.sin(k)) for k in range(7)]
add(K.loft("Heart", heart, [(0.018, 0.04)] * 7, "body", EMBER, 10))
for sx in (-1, 1):
    add(K.blob("Lip", B + G(sx * 0.07, 0.07, -0.6), (0.06, 0.16, 0.05), "body", BARK, 24, 12))

# --- neck (front) and tail ----------------------------------------------------------------------------
F = S["front"]
add(K.loft("Neck", [B + G(0, 0.15, -0.45), F + G(0, 0.05, -0.02), S["head"] + G(0, -0.02, 0.04)], [0.2, 0.15, 0.1], "front", HIDE, 24, wobble=0.06))
for k in range(8):
    p = F + G(0, 0.17 - 0.02 * k, 0.1 - 0.04 * k)
    for side in (-1, 1):
        add(K.loft("ManeCane", [p, p + G(side * 0.08, 0.12, 0.08)], [0.014, 0.0], "front", BARK, 7))
T = S["tail"]
tail = [T + G(0, 0.0 - 0.03 * t * t, 0.4 * t) for t in [i / 8.0 for i in range(9)]]
add(K.loft("Tail", tail, [0.08 * (1.0 - t) + 0.005 for t in [i / 8.0 for i in range(9)]], "tail", BARK, 12, wobble=0.15))

# --- head: a long deer skull worn over the snout, embers in the sockets, the antler crown --------------------
Hd = S["head"]


def deer_skull(c):
    p = Vector(c)
    n = p.normalized()
    def dent(at, r, d):
        return d * math.exp(-((p - at).length / r) ** 2)
    push = 0.0
    for sx in (-1, 1):
        push -= dent(Vector((sx * 0.6, 0.2, 0.35)), 0.24, 0.45)    # orbits
        push += dent(Vector((sx * 0.7, 0.05, 0.1)), 0.25, 0.15)    # zygomatic arches
        push -= dent(Vector((sx * 0.3, 0.85, 0.15)), 0.18, 0.2)    # nasal hollows
        push -= dent(Vector((sx * 0.62, -0.55, 0.0)), 0.22, 0.2)   # temporal fossae
    push += dent(Vector((0.0, -0.3, 0.75)), 0.4, 0.12)             # the crown
    if p.y > 0.2:
        p.x *= 1.0 - 0.45 * (p.y - 0.2)                            # the long muzzle narrows
    return p + n * push + n * 0.025 * noise.noise(p * 7.0)


add(K.blob("Skull", Hd + G(0, 0.06, -0.14), (0.1, 0.26, 0.09), "head", BONE, 64, 32, deer_skull))
add(K.blob("Jaw", Hd + G(0, -0.03, -0.12), (0.065, 0.22, 0.035), "head", BONE, 32, 16))
for sx in (-1, 1):
    add(K.blob("Ember eye", Hd + G(sx * 0.04, 0.05, -0.06), (0.016, 0.012, 0.014), "head", EMBER, 12, 8))
for k in range(6):
    x = (k - 2.5) * 0.012
    add(K.loft("Tooth", [Hd + G(x, -0.025, -0.27 + abs(x)), Hd + G(x, -0.05, -0.27 + abs(x))], [0.005, 0.0], "head", BONE, 6))


def antler(root, d, length, radius, depth, side):
    pts, radii = [], []
    bend = G(side * 0.25, -0.05, 0.12)
    for k in range(7):
        t = k / 6.0
        pts.append(root + d * length * t + bend * length * t * t + Vector((0, 0, 0.03 * length * math.sin(t * 5.0))))
        radii.append(radius * (1.0 - 0.55 * t) if depth > 1 else radius * (1.0 - t))
    add(K.loft("Tine", pts, radii, "head", BONE if depth == 1 else BARK, 10, wobble=0.15, seed=depth))
    if depth <= 1:
        return
    if depth == 3:
        coil = [pts[0].lerp(pts[3], t) + Vector((math.cos(t * 18) * radius * 1.3, math.sin(t * 18) * radius * 1.3, 0)) for t in [i / 30.0 for i in range(31)]]
        add(K.curve_tube("Bramble", coil, radius * 0.25, "head", BARK))
    for f, i in enumerate((2, 4)):
        tan = (pts[i + 1] - pts[i - 1]).normalized()
        out = (tan + Vector((0, 0, 0.9)) + G(side * 0.25, 0, 0.5 if f == 0 else -0.4)).normalized()
        antler(pts[i], out, length * 0.55, radii[i] * 0.72, depth - 1, side)
    antler(pts[6], (pts[6] - pts[5]).normalized(), length * 0.45, radii[6] * 0.9, depth - 1, side)


for side in (-1, 1):
    antler(Hd + G(side * 0.05, 0.08, 0.0), G(side * 0.55, 1.0, 0.2).normalized(), 0.62, 0.035, 3, side)

# --- legs: heavy upper legs (out from the hip), thick lower legs, splayed root feet ------------------------
for tag in ("fl", "fr", "bl", "br"):
    hip, knee, foot = S["leg_%s_hip" % tag], S["leg_%s_knee" % tag], S["leg_%s_foot" % tag]
    add(K.loft("Thigh", [hip, hip.lerp(knee, 0.5) + G(0, 0.05, 0), knee], [0.11, 0.1, 0.07], "leg_%s_hip" % tag, HIDE, 18, wobble=0.12))
    hock = knee.lerp(foot, 0.45) + G(0, 0, 0.05 if tag.startswith("b") else -0.03)
    add(K.loft("Shin", [knee, hock, foot + G(0, 0.06, 0)], [0.075, 0.055, 0.05], "leg_%s_knee" % tag, HIDE, 16, wobble=0.12))
    for k in range(5):
        z = knee.z - 0.1 - k * 0.09
        p = knee.lerp(foot, (knee.z - z) / max(knee.z - foot.z, 0.01))
        add(K.blob("LegPlate", p + G(0, 0, -0.06), (0.06, 0.03, 0.08), "leg_%s_knee" % tag, BARK, 16, 8))
    add(K.blob("Pad", foot + G(0, 0.03, 0), (0.07, 0.07, 0.045), "leg_%s_foot" % tag, BARK, 20, 10))
    for t in range(5):
        a = (t - 2) * 0.55
        d = G(math.sin(a), -0.15, -math.cos(a)).normalized() if t < 4 else G(0, -0.2, 1).normalized()
        if t == 4:
            d = G(0.3, -0.2, 1.0).normalized()
        root = foot + G(0, 0.03, 0)
        add(K.loft("Root", [root, root + d * 0.07 + G(0, -0.02, 0), root + d * 0.15 + G(0, -0.03, 0), root + d * 0.2 + G(0, -0.025, 0)], [0.025, 0.02, 0.012, 0.0], "leg_%s_foot" % tag, BARK, 10, wobble=0.2))

# fuse: one continuous hide per socket, the bark shingles into one carapace, sculpted
objs[:] = K.fuse(objs, 0.004, keep={"Ember", "Bone"}, sculpt=0.003, sculpt_scale=0.035, decimate=0.3)
print("THORN parts", len(objs))
if PREVIEW:
    K.preview(PREVIEW, 0.8, 4.8, ((25, 1.6), (95, 1.2)))
if EXPORT:
    K.bake_atlas(objs, MATS, "boss_thornwarden", os.path.join(ROOT, "art", "textures"), 4096)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "art", "blender", "boss_thornwarden.blend"))
    K.split_and_export(objs, os.path.join(ROOT, "art", "models", "boss_thornwarden.glb"), None, S)
