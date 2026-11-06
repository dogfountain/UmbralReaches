"""The Speaking Crown (r37, the Fallen Hierarch's boss): the Hierarch's voice, kept in his head after the fall.
A tall hollowed cantor fused with the colossus's stone: a cope of cracked masonry to the ground, broad stone
pauldrons, gauntlets of fitted blocks, and for a head a great stone speaking-horn, its mouth ringed with the
broken tines of the tiara and an ember in its throat. Modelled in the Husk rig's rest pose over the same
sockets as the Ascended Warden, baked into one atlas, split per socket. Procedural materials only (no scans).

  tools/blender/run.sh boss_hierarch.py -- [--preview /tmp/hierarch.png] [--no-export]
Writes art/models/boss_hierarch.glb and art/textures/boss_hierarch_*.png
"""
import bpy
import math
import os
import sys
from mathutils import Vector, noise

sys.path.insert(0, os.path.dirname(__file__))
import boss_kit as K
from boss_kit import G

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
PREVIEW = args[args.index("--preview") + 1] if "--preview" in args else ""
EXPORT = "--no-export" not in args

K.reset()


def stone_mat(name, base, light, moss=0.0, soot=0.0, scale=7.0):
    m = K.Mat(name)
    n1 = m.noise(scale, 7.0, 0.6)
    n2 = m.noise(scale * 4.0, 5.0, 0.55)
    col = m.ramp(n1, [(0.3, base), (0.8, light)])
    # hairline cracks along the cell edges, darker
    edge = m.voronoi(scale * 0.9, 'F1', out='Distance')
    crack = m.math('LESS_THAN', m.voronoi(scale * 1.1, 'DISTANCE_TO_EDGE'), 0.018)
    crack = m.math('MULTIPLY', crack, m.math('GREATER_THAN', m.noise(3.0, 2.0, 0.5), 0.5))
    col = m.mix(crack, col, (0.05, 0.045, 0.04))
    if moss > 0.0:
        z = m.zpos()
        mo = m.math('MULTIPLY', m.math('GREATER_THAN', m.noise(5.0, 4.0, 0.55), 0.55), moss)
        col = m.mix(mo, col, (0.27, 0.36, 0.17))
    if soot > 0.0:
        col = m.mix(m.math('MULTIPLY', m.math('GREATER_THAN', n2, 0.62), soot), col, (0.07, 0.06, 0.055))
    h = m.math('SUBTRACT', m.math('ADD', m.math('MULTIPLY', n2, 0.5), m.math('MULTIPLY', n1, 0.5)), m.math('MULTIPLY', crack, 0.8))
    return m.finish(col, m.math('ADD', 0.62, m.math('MULTIPLY', n2, 0.3)), 0.0, h, 0.6, 0.003)


def gilt_mat():
    m = K.Mat("Gilt")
    wear = m.noise(18.0, 6.0, 0.6)
    col = m.ramp(wear, [(0.3, (0.3, 0.2, 0.08)), (0.65, (0.68, 0.48, 0.2)), (0.9, (0.9, 0.72, 0.4))])
    return m.finish(col, m.math('ADD', 0.28, m.math('MULTIPLY', wear, 0.3)), 0.9, m.noise(90.0, 3.0, 0.5), 0.15, 0.002)


def ember_mat():
    m = K.Mat("Ember")
    pulse = m.noise(9.0, 3.0, 0.5)
    col = m.ramp(pulse, [(0.3, (1.0, 0.35, 0.08)), (0.8, (1.0, 0.72, 0.3))])
    return m.finish((0.08, 0.05, 0.04), 0.5, 0.0, None, emit=col, emit_strength=7.0)


STONE = stone_mat("Stone", (0.12, 0.115, 0.1), (0.33, 0.31, 0.27), moss=0.45, soot=0.25)
DARK = stone_mat("DarkStone", (0.07, 0.065, 0.06), (0.2, 0.19, 0.17), moss=0.0, soot=0.5, scale=9.0)
PALE = stone_mat("PaleStone", (0.24, 0.22, 0.19), (0.5, 0.47, 0.41), moss=0.15, soot=0.1, scale=6.0)
GILT = gilt_mat()
EMBER = ember_mat()
MATS = [STONE, DARK, PALE, GILT, EMBER]
objs = []


def add(o):
    objs.append(o)
    return o


C, P, HD = K.SOCKETS["chest"], K.SOCKETS["pelvis"], K.SOCKETS["head"]

# --- the head: a speaking-horn of stone (the mouth of the colossus), tilted a little forward ----------------
axis = [HD + G(0, -0.04, 0.0), HD + G(0, 0.03, -0.01), HD + G(0, 0.12, -0.04), HD + G(0, 0.22, -0.09), HD + G(0, 0.30, -0.15)]
rad = [0.055, 0.075, 0.115, 0.17, 0.235]
horn = add(K.loft("Horn", axis, rad, "head", STONE, 28, wobble=0.045, seed=2.0, cap1=False))
rim = [axis[-1] + Vector((math.cos(a) * 0.235, 0.0, math.sin(a) * 0.235)) for a in [math.tau * i / 40 for i in range(41)]]
add(K.curve_tube("HornRim", rim, 0.014, "head", PALE))
add(K.blob("Throat", axis[-2] + G(0, 0.005, -0.02), (0.14, 0.01, 0.14), "head", EMBER, 24, 6))   # the ember deep in the mouth
# a jaw-block under the horn and the carved mouth-bands on its outside
for k in range(3):
    t = 0.45 + 0.2 * k
    ring = [axis[1].lerp(axis[-1], t) + Vector((math.cos(a) * (rad[1] + (rad[-1] - rad[1]) * t * t + 0.004), 0.0, math.sin(a) * (rad[1] + (rad[-1] - rad[1]) * t * t + 0.004))) for a in [math.tau * i / 32 for i in range(33)]]
    add(K.curve_tube("Band", ring, 0.006, "head", GILT))
# the broken tiara: tines round the horn's rim, leaning out, a few snapped
for k in range(9):
    a = math.tau * k / 9 + 0.2
    d = Vector((math.cos(a), 0.0, math.sin(a)))
    base = axis[-1] + d * 0.225
    ln = 0.2 + 0.1 * noise.noise(Vector((k * 1.7, 2.0, 0.0)))
    if k % 4 == 1:
        ln *= 0.35
    tip = base + d * ln * 0.45 + Vector((0, ln, -ln * 0.2))
    add(K.loft("Tine", [base, base.lerp(tip, 0.5) + d * 0.01, tip], [(0.02, 0.012), (0.014, 0.009), (0.0, 0.0) if k % 4 != 1 else (0.008, 0.006)], "head", PALE, 8))
# a hollowed face's remnant far inside the neck: two pale eyes in a skull cap beneath the horn
add(K.blob("Skull", HD + G(0, -0.08, 0.02), (0.07, 0.07, 0.08), "head", DARK, 16, 10))
for sx in (-1, 1):
    add(K.blob("Eye", HD + G(sx * 0.03, -0.075, -0.05), (0.011, 0.007, 0.009), "head", EMBER, 8, 6))

# --- the body: a broad cope of cracked stone ---------------------------------------------------------------
add(K.blob("Chest", C + G(0, 0.0, 0.0), (0.22, 0.18, 0.15), "chest", STONE, 32, 16))
add(K.loft("Collar", [C + G(0, 0.12, 0.0), HD + G(0, -0.04, 0.0)], [0.12, 0.06], "chest", DARK, 16))
# the breastplate: a gilt lozenge with an ember at its heart, and a band of carved edict-lines
add(K.blob("Plate", C + G(0, 0.03, -0.135), (0.085, 0.1, 0.02), "chest", GILT, 20, 10))
add(K.blob("PlateEmber", C + G(0, 0.03, -0.157), (0.025, 0.035, 0.01), "chest", EMBER, 12, 8))
for k in range(5):
    a = math.tau * k / 5
    add(K.blob("Rib", C + G(math.cos(a) * 0.15, -0.06 + math.sin(a) * 0.02, -0.07 - abs(math.sin(a)) * 0.05), (0.014, 0.12, 0.016), "chest", PALE, 8, 6))
for sx, tag in ((-1, "l"), (1, "r")):
    S, E, H = K.SOCKETS["shoulder_" + tag], K.SOCKETS["elbow_" + tag], K.SOCKETS["hand_" + tag]
    # pauldron: stacked stone plates
    for j in range(3):
        add(K.blob("Pauldron", S + G(sx * 0.03, 0.05 - 0.04 * j, 0.0), (0.12 - 0.012 * j, 0.05, 0.12 - 0.012 * j), "chest", STONE if j != 1 else PALE, 20, 8))
    add(K.loft("Upper", [S, E], [0.065, 0.055], "shoulder_" + tag, STONE, 18, wobble=0.06, seed=1.0 + sx))
    add(K.loft("Fore", [E, H + G(0, 0.06, 0)], [0.055, 0.05], "elbow_" + tag, DARK, 18, wobble=0.05, seed=3.0 + sx))
    # the gauntlet: fitted blocks (rings of pale stone), a heavy fist
    for k, t in enumerate((0.15, 0.4, 0.65, 0.88)):
        c = E + (H - E) * t
        r = 0.066 - 0.004 * k
        ringp = [c + Vector((math.cos(a) * r, math.sin(a) * r, 0)) for a in [math.tau * i / 24 for i in range(25)]]
        add(K.curve_tube("Cuff", ringp, 0.011, "elbow_" + tag, PALE if k % 2 == 0 else GILT))
    add(K.blob("Fist", H + G(0, -0.03, 0), (0.07, 0.075, 0.065), "hand_" + tag, STONE, 20, 12))
    for f in range(3):
        fx = (f - 1.0) * 0.036
        a = H + G(fx, -0.08, -0.012)
        add(K.loft("Finger", [a, a + G(fx * 0.2, -0.05, -0.03), a + G(fx * 0.3, -0.085, -0.075)], [0.016, 0.014, 0.008], "hand_" + tag, PALE, 8))

# --- the cope: a floor-length mantle of stone folds, from the pelvis; split at the front by a broken hem ---------
folds = []
for i, (ry, flare) in enumerate(((0.19, 0.5), (0.2, 1.0))):
    cope = K.hanging_cone("Cope%d" % i, P + G(0, 0.02, 0), 0.2 + 0.015 * i, ry, 0.98, flare + 0.5 * i, "pelvis", STONE if i == 0 else DARK, 72, 26)
    # ripple the folds into the cone: a stone drape, sculpted rather than simulated
    me = cope.data
    for v in me.vertices:
        r = Vector((v.co.x - (P.x), v.co.y - P.y, 0.0))
        ang = math.atan2(r.y, r.x)
        depth = (P.z - v.co.z) / 0.98
        amp = 0.018 * depth * (1.0 + 0.5 * math.sin(ang * 3.0))
        k = math.sin(ang * 9.0 + depth * 2.0) * amp
        v.co.x += math.cos(ang) * k
        v.co.y += math.sin(ang) * k
        v.co.z += 0.05 * noise.noise(Vector((v.co.x * 9, v.co.y * 9, 1.0))) * depth
    K.solidify(cope, 0.02)
    add(cope)
add(K.curve_tube("HemBand", [P + G(math.cos(a) * 0.52, 0.0 + 0.0, 0.0) + Vector((0, math.sin(a) * 0.52, -0.9)) for a in [math.tau * i / 48 for i in range(49)]], 0.01, "pelvis", GILT))
add(K.blob("Belt", P + G(0, 0.12, 0), (0.2, 0.05, 0.15), "pelvis", DARK, 24, 8))
# a loop of broken chain and two hanging bell-clappers from the belt: the Order's tolling-gear
for sx in (-1, 1):
    pts = [P + G(sx * 0.14, 0.1 - 0.12 * t, -0.12 - 0.01 * t) for t in [i / 8.0 for i in range(9)]]
    add(K.curve_tube("Chain", pts, 0.005, "pelvis", DARK))
    add(K.blob("Clapper", pts[-1] + G(0, -0.04, 0), (0.03, 0.05, 0.03), "pelvis", GILT, 12, 8))

print("HIERARCH parts", len(objs))
if PREVIEW:
    K.preview(PREVIEW, 1.3, 5.0)
if EXPORT:
    K.bake_atlas(objs, MATS, "boss_hierarch", os.path.join(ROOT, "art", "textures"), 2048)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "art", "blender", "boss_hierarch.blend"))
    K.split_and_export(objs, os.path.join(ROOT, "art", "models", "boss_hierarch.glb"))
