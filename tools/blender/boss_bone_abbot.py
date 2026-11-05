"""The Bone Abbot (r30): a skeletal priest in a cassock and cope, a closed mitre with gilt bands,
a caged reliquary candle at the breast, a crozier of fused vertebrae. Modelled in the rig's rest
pose, cloth simulated, baked into one atlas, split per socket.

  blender -b -P tools/blender/boss_bone_abbot.py -- [--preview /tmp/abbot.png] [--no-export]
Writes art/models/boss_bone_abbot.glb and art/textures/boss_bone_abbot_{albedo,normal,orm,emit}.png
"""
import bpy
import bmesh
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

# --- materials --------------------------------------------------------------------------------
def bone_mat(name="Bone", base=(0.78, 0.71, 0.58)):
    m = K.Mat(name)
    sc = m.scan("beige_wall_001", 7.0)
    dirt = m.noise(7.0, 8.0, 0.6)
    cracks = m.voronoi(34.0, 'DISTANCE_TO_EDGE')
    gate = m.math('GREATER_THAN', m.noise(9.0, 3.0, 0.5), 0.52)
    crack = m.math('MULTIPLY', m.math('LESS_THAN', cracks, 0.016), gate)
    col = m.mul(m.mono(sc["color"]), (1.25, 1.12, 0.9))
    col = m.mix(m.math('MULTIPLY', m.math('SUBTRACT', 1.0, dirt), 0.55), col, (0.42, 0.33, 0.21))
    col = m.mix(m.math('MULTIPLY', crack, 0.85), col, (0.13, 0.1, 0.07))
    col = m.mul(col, (1.0, 1.0, 1.0))
    h = m.math('ADD', m.math('MULTIPLY', sc["disp"], 0.7), m.math('MULTIPLY', crack, -0.7))
    h = m.math('ADD', h, m.math('MULTIPLY', m.noise(70.0, 4.0, 0.5), 0.25))
    rough = m.math('ADD', m.math('MULTIPLY', sc["rough"], 0.6), 0.25)
    return m.finish(col, rough, 0.0, h, 0.8, 0.0025)


def cloth_mat():
    m = K.Mat("Cloth")
    sc = m.scan("caban", 9.0)
    blot = m.noise(5.0, 6.0, 0.6)
    col = m.mul(m.mono(sc["color"]), (0.16, 0.14, 0.16))
    col = m.mix(m.math('MULTIPLY', blot, 0.35), col, (0.012, 0.01, 0.012))
    # two gilt rules with a running zig-zag between them, the band above the hem
    z = m.zpos()
    rule = m.math('ADD', m.math('MULTIPLY', m.math('GREATER_THAN', z, 0.015), m.math('LESS_THAN', z, 0.028)),
                  m.math('MULTIPLY', m.math('GREATER_THAN', z, 0.11), m.math('LESS_THAN', z, 0.123)))
    wave = m.n('ShaderNodeTexWave')
    wave.wave_type = 'BANDS'
    wave.bands_direction = 'X'
    wave.wave_profile = 'TRI'
    wave.inputs['Scale'].default_value = 3.0
    m.links.new(m.coord.outputs['Object'], wave.inputs['Vector'])
    zig = m.math('LESS_THAN', m.math('ABSOLUTE', m.math('SUBTRACT', m.math('MULTIPLY', m.math('SUBTRACT', z, 0.04), 13.0), wave.outputs['Fac'])), 0.12)
    inside = m.math('MULTIPLY', m.math('GREATER_THAN', z, 0.035), m.math('LESS_THAN', z, 0.105))
    gilt = m.math('MAXIMUM', rule, m.math('MULTIPLY', zig, inside), True)
    col = m.mix(gilt, col, (0.62, 0.42, 0.14))
    h = m.math('ADD', m.math('MULTIPLY', sc["disp"], 0.9), m.math('MULTIPLY', gilt, 0.5))
    rough = m.math('SUBTRACT', m.math('ADD', m.math('MULTIPLY', sc["rough"], 0.3), 0.68), m.math('MULTIPLY', gilt, 0.55))
    metal = m.math('MULTIPLY', gilt, 0.9)
    return m.finish(col, rough, metal, h, 0.7, 0.0018)


def gold_mat():
    m = K.Mat("Gold")
    wear = m.noise(18.0, 6.0, 0.6)
    col = m.ramp(wear, [(0.3, (0.32, 0.2, 0.07)), (0.62, (0.78, 0.55, 0.22)), (0.9, (0.95, 0.76, 0.4))])
    rough = m.math('ADD', 0.22, m.math('MULTIPLY', m.math('SUBTRACT', 1.0, wear), 0.4))
    h = m.noise(90.0, 3.0, 0.5)
    return m.finish(col, rough, 0.95, h, 0.25, 0.002)


def wax_mat():
    m = K.Mat("Wax")
    v = m.noise(30.0, 4.0, 0.5)
    col = m.ramp(v, [(0.3, (0.66, 0.6, 0.48)), (0.8, (0.85, 0.8, 0.66))])
    return m.finish(col, 0.42, 0.0, v, 0.3, 0.003)


def glow_mat(name, col, strength):
    m = K.Mat(name)
    return m.finish((0.05, 0.03, 0.01), 0.6, 0.0, None, emit=col, emit_strength=strength)


def sinew_mat():
    m = K.Mat("Sinew")
    v = m.noise(40.0, 6.0, 0.6)
    col = m.ramp(v, [(0.3, (0.08, 0.04, 0.035)), (0.8, (0.22, 0.12, 0.09))])
    return m.finish(col, 0.5, 0.0, v, 0.6, 0.002)


BONE = bone_mat()
CLOTH = cloth_mat()
GOLD = gold_mat()
WAX = wax_mat()
FLAME = glow_mat("Flame", (1.0, 0.62, 0.22), 8.0)
EYE = glow_mat("Eye", (1.0, 0.66, 0.25), 8.0)
SINEW = sinew_mat()
MATS = [BONE, CLOTH, GOLD, WAX, FLAME, EYE, SINEW]
objs = []


def add(o):
    objs.append(o)
    return o


# --- skull + mitre (head) -------------------------------------------------------------------------
HC = K.SOCKETS["head"] + G(0, 0.07, -0.02)


def skull_shape(c):
    p = Vector(c)
    # Blender: +Y front, +Z up. eye sockets, nose, cheeks, a narrower lower face, brow ridge
    def dent(at, r, depth):
        d = (p - at).length
        return depth * math.exp(-(d / r) ** 2)
    n = p.normalized()
    push = 0.0
    for sx in (-1, 1):
        push -= dent(Vector((sx * 0.38, 0.92, 0.05)), 0.26, 0.24)      # orbits
        push += dent(Vector((sx * 0.62, 0.62, -0.28)), 0.25, 0.1)      # cheekbones
    push -= dent(Vector((0.0, 0.97, -0.3)), 0.14, 0.2)                 # nasal cavity
    push += dent(Vector((0.0, 0.85, 0.32)), 0.32, 0.07)                # brow ridge
    if p.z < -0.2 and p.y > 0.0:
        p.x *= 0.82                                                     # narrow muzzle
    p += n * push
    p += n * 0.03 * noise.noise(p * 6.0)
    return p


sk = add(K.blob("Skull", HC, (0.096, 0.132, 0.112), "head", BONE, 64, 32, skull_shape))
K.subsurf(sk, 1)
# eyes burning in the orbits
for sx in (-1, 1):
    add(K.blob("Eye", HC + Vector((sx * 0.032, 0.088, 0.006)), (0.016, 0.01, 0.012), "head", EYE, 12, 8))
# the jaw (a horseshoe) and two rows of teeth
jp = []
for k in range(11):
    a = math.pi * (k / 10.0)
    jp.append(HC + Vector((math.cos(a) * 0.066, 0.02 + math.sin(a) * 0.09, -0.085 - math.sin(a) * 0.012)))
add(K.loft("Jaw", jp, [0.016] * 11, "head", BONE, 10, wobble=0.1))
for row, z, sgn in ((0, -0.05, -1), (1, -0.08, 1)):
    for k in range(10):
        a = math.pi * (0.12 + 0.76 * k / 9.0)
        base = HC + Vector((math.cos(a) * 0.052, 0.012 + math.sin(a) * 0.088, z))
        add(K.loft("Tooth", [base, base + Vector((0, 0.002, sgn * 0.022))], [0.0065, 0.0], "head", BONE, 6, cap0=False))
# mitre: one closed shield-section crown converging to a peak, gilt circlet and orphreys, sigil
MB = K.SOCKETS["head"] + G(0, 0.15, 0.0)
rings = []
for k in range(16):
    t = k / 15.0
    h = t * 0.36
    rx = 0.13 * (1.0 - t ** 1.9) + 0.002
    ry = 0.09 * (1.0 - t ** 0.9) + 0.002
    rings.append((MB + Vector((0, -0.01 * t, h)), (rx, ry)))
mi = add(K.loft("Mitre", [r[0] for r in rings], [r[1] for r in rings], "head", BONE, 40))
K.subsurf(mi, 1)
circ = [MB + Vector((math.cos(a) * 0.133, math.sin(a) * 0.093, 0.012)) for a in [math.tau * i / 48 for i in range(49)]]
add(K.curve_tube("Circlet", circ, 0.011, "head", GOLD))
for sy in (-1, 1):
    pts = []
    for k in range(12):
        t = k / 11.0
        pts.append(MB + Vector((0, sy * (0.092 * (1.0 - t ** 0.9) + 0.004), t * 0.355)))
    add(K.curve_tube("Orphrey", pts, 0.008, "head", GOLD))
    for k in range(3):
        t = 0.18 + 0.2 * k
        y = sy * (0.092 * (1.0 - t ** 0.9) + 0.008)
        add(K.blob("Boss", MB + Vector((0, y, t * 0.355)), (0.011, 0.006, 0.011), "head", GOLD, 16, 8))
add(K.blob("Sigil", MB + Vector((0, 0.098, 0.09)), (0.012, 0.004, 0.016), "head", EYE, 12, 8))
# lappets: two embroidered bands falling behind
for sx in (-1, 1):
    pts = [MB + Vector((sx * 0.05, -0.08, 0.01)) + Vector((sx * 0.03 * t, -0.06 * t, -0.42 * t)) + Vector((0, -0.015 * math.sin(t * 6.0), 0)) for t in [i / 10.0 for i in range(11)]]
    add(K.loft("Lappet", pts[:8], [(0.02, 0.004)] * 8, "head", GOLD, 8))

# --- ribcage, spine, collarbones, scapulae (chest) ---------------------------------------------------
SP = []
for k in range(15):
    t = k / 14.0
    SP.append(G(0, 0.98 + t * 0.62, 0.075 - 0.05 * math.sin(t * math.pi)))
for k, p in enumerate(SP):
    s = 1.0 - 0.35 * (k / 14.0)
    sock = "chest" if p.z > K.SOCKETS["chest"].z - 0.2 else "pelvis"
    add(K.blob("Vert", p, (0.028 * s, 0.024 * s, 0.017), sock, BONE, 16, 8))
    add(K.loft("Spinous", [p + Vector((0, -0.015, 0)), p + Vector((0, -0.05 * s, -0.012))], [0.009 * s, 0.003], sock, BONE, 6))
    for sx in (-1, 1):
        add(K.loft("Transverse", [p, p + Vector((sx * 0.038 * s, -0.008, 0.004))], [0.007 * s, 0.004], sock, BONE, 6))
C = K.SOCKETS["chest"]
for i in range(7):
    y = 0.12 - 0.055 * i
    w = 0.15 + 0.025 * math.sin(i / 6.0 * math.pi)
    for sx in (-1, 1):
        pts = []
        for k in range(13):
            a = math.pi * k / 12.0
            pts.append(C + G(sx * math.sin(a) * w, y - 0.07 * math.sin(a * 0.5) - 0.02 * (k / 12.0), 0.06 - math.cos(a) * 0.0 - (1 - math.cos(a)) * 0.075))
        add(K.loft("Rib", pts, [0.009 + 0.003 * math.sin(math.pi * k / 12.0) for k in range(13)], "chest", BONE, 8, squash=(1.0, 0.55)))
stern = [C + G(0, 0.15, -0.095), C + G(0, -0.05, -0.11), C + G(0, -0.2, -0.1)]
add(K.loft("Sternum", stern, [(0.028, 0.009), (0.024, 0.009), (0.014, 0.008)], "chest", BONE, 10))
for sx in (-1, 1):
    add(K.bone("Clavicle", C + G(sx * 0.02, 0.15, -0.085), C + G(sx * 0.21, 0.13, -0.01), 0.012, "chest", BONE, 1.4, 10, 10, sx))
    sc = K.blob("Scapula", C + G(sx * 0.12, 0.05, 0.11), (0.075, 0.012, 0.1), "chest", BONE, 24, 10)
    sc.rotation_euler = (0.0, 0.0, sx * 0.25)
    add(sc)
# a dried cord of sinew down the spine, inside the ribs
add(K.loft("Cord", [p + Vector((0, 0.03, 0)) for p in SP[2:13]], [0.012] * 11, "chest", SINEW, 8, wobble=0.25))

# the reliquary: a gilt cage of curved bars, a candle burning in it, on a chain from the neck
RQ = C + G(0, -0.12, -0.27)
for k in range(6):
    a = math.tau * k / 6.0
    pts = []
    for j in range(9):
        t = j / 8.0
        r = 0.02 + 0.05 * math.sin(t * math.pi)
        pts.append(RQ + G(math.cos(a) * r, 0.08 - t * 0.18, math.sin(a) * r))
    add(K.curve_tube("Bar", pts, 0.006, "chest", GOLD))
for y, r in ((0.085, 0.03), (-0.1, 0.028)):
    add(K.blob("Cap", RQ + G(0, y, 0), (r, r, 0.016), "chest", GOLD, 24, 10))
add(K.loft("Finial", [RQ + G(0, 0.09, 0), RQ + G(0, 0.15, 0)], [0.01, 0.0], "chest", GOLD, 8))
add(K.loft("Candle", [RQ + G(0, -0.09, 0), RQ + G(0, -0.01, 0)], [0.018, 0.017], "chest", WAX, 14))
add(K.blob("Flame", RQ + G(0, 0.02, 0), (0.011, 0.011, 0.026), "chest", FLAME, 12, 8))
chain = [C + G(sx * 0.1, 0.2, -0.06) for sx in (-1,)] + [RQ + G(0, 0.15, 0)] + [C + G(0.1, 0.2, -0.06)]
add(K.curve_tube("Chain", chain, 0.005, "chest", GOLD))

# --- arms: humerus, radius + ulna, a skeletal hand with long claws -------------------------------------
for tag, sx in (("l", -1), ("r", 1)):
    S, E, H = K.SOCKETS["shoulder_" + tag], K.SOCKETS["elbow_" + tag], K.SOCKETS["hand_" + tag]
    add(K.blob("Humeral head", S, (0.032, 0.032, 0.03), "shoulder_" + tag, BONE, 20, 10))
    add(K.bone("Humerus", S + G(0, -0.02, 0), E + G(0, 0.015, 0), 0.016, "shoulder_" + tag, BONE, 1.7, 12, 12, sx))
    for dz in (-0.011, 0.011):
        add(K.bone("Forearm", E + G(sx * 0.004, -0.01, dz), H + G(sx * 0.004, 0.02, dz * 0.6), 0.008, "elbow_" + tag, BONE, 1.6, 10, 12, dz))
    add(K.blob("Carpals", H + G(0, -0.015, 0), (0.026, 0.02, 0.03), "hand_" + tag, BONE, 16, 10))
    for f in range(4):
        fx = (f - 1.5) * 0.017
        a = H + G(fx * 0.6, -0.025, -0.008)
        b = a + G(fx * 0.25, -0.06, -0.006)
        c = b + G(fx * 0.12, -0.05, -0.012)
        d = c + G(0, -0.04, -0.016)
        for p, q, r in ((a, b, 0.0058), (b, c, 0.005), (c, d, 0.0043)):
            add(K.bone("Phalanx", p, q, r, "hand_" + tag, BONE, 1.4, 8, 6, f))
        add(K.loft("Claw", [d, d + G(0, -0.025, -0.012), d + G(0, -0.045, -0.035)], [0.0045, 0.003, 0.0], "hand_" + tag, BONE, 6))
    t0 = H + G(-sx * 0.02, -0.02, -0.012)
    add(K.bone("Thumb", t0, t0 + G(-sx * 0.025, -0.045, -0.02), 0.005, "hand_" + tag, BONE, 1.4, 8, 6))

# --- legs (mostly under the cassock): femur, tibia, foot bones ------------------------------------------
for tag, sx in (("l", -1), ("r", 1)):
    Hp, Kn, Ft = K.SOCKETS["hip_" + tag], K.SOCKETS["knee_" + tag], K.SOCKETS["foot_" + tag]
    add(K.bone("Femur", Hp, Kn + G(0, 0.02, 0), 0.02, "hip_" + tag, BONE, 1.6, 12, 12, sx))
    add(K.bone("Tibia", Kn, Ft + G(0, 0.03, 0), 0.016, "knee_" + tag, BONE, 1.6, 12, 12, sx))
    add(K.blob("Heel", Ft + G(0, -0.01, 0.02), (0.022, 0.028, 0.022), "foot_" + tag, BONE, 16, 8))
    for t in range(4):
        tx = (t - 1.5) * 0.016
        add(K.bone("Toe", Ft + G(tx * 0.5, -0.02, -0.01), Ft + G(tx, -0.04, -0.11), 0.006, "foot_" + tag, BONE, 1.4, 8, 8, t))

# --- the crozier: a staff of fused vertebrae, a gilt knop, a spiral crook with a skull and a flame -----------
HR = K.SOCKETS["hand_r"]
shaft = [HR + G(0.0, -0.75 + 1.9 * t, -0.04) for t in [i / 20.0 for i in range(21)]]
add(K.loft("Shaft", shaft, [0.015] * 21, "crozier", BONE, 10, wobble=0.05))
for k in range(26):
    p = HR + G(0.0, -0.72 + 0.072 * k, -0.04)
    add(K.blob("Bead", p, (0.022, 0.022, 0.013), "crozier", BONE, 14, 6))
add(K.blob("Knop", HR + G(0, 1.13, -0.04), (0.035, 0.035, 0.03), "crozier", GOLD, 24, 12))
crook = []
for k in range(26):
    a = k / 25.0 * math.pi * 1.6
    r = 0.13 * (1.0 - 0.32 * k / 25.0)
    crook.append(HR + G(0.0, 1.15 + math.sin(a) * r, -0.04 - (1.0 - math.cos(a)) * r))
add(K.loft("Crook", crook, [0.016 * (1.0 - 0.6 * k / 25.0) for k in range(26)], "crozier", BONE, 10))
for k in range(1, 25, 3):
    add(K.blob("CrookBead", crook[k], (0.019, 0.019, 0.019), "crozier", BONE, 12, 6))
add(K.blob("CrookSkull", HR + G(0, 1.2, -0.12), (0.03, 0.035, 0.032), "crozier", BONE, 20, 12, skull_shape))
add(K.blob("CrookFlame", HR + G(0, 1.27, -0.17), (0.012, 0.012, 0.03), "crozier", FLAME, 12, 8))

# --- cloth: cassock (pelvis), cope (chest), sleeves (shoulders) -----------------------------------------
P = K.SOCKETS["pelvis"]
coll = []
hips = K.blob("ColHips", P + G(0, -0.06, 0), (0.18, 0.15, 0.2), "pelvis", None, 24, 12)
coll.append(hips)
for tag in ("l", "r"):
    leg = K.loft("ColLeg", [K.SOCKETS["hip_" + tag], K.SOCKETS["foot_" + tag]], [0.075, 0.06], "pelvis", None, 12)
    coll.append(leg)
torso = K.blob("ColTorso", C + G(0, 0.02, 0), (0.2, 0.16, 0.24), "chest", None, 24, 12)
coll.append(torso)
for tag in ("l", "r"):
    coll.append(K.blob("ColShoulder", K.SOCKETS["shoulder_" + tag], (0.07, 0.07, 0.07), "chest", None, 16, 8))
    coll.append(K.loft("ColArm", [K.SOCKETS["shoulder_" + tag], K.SOCKETS["hand_" + tag]], [0.045, 0.035], "chest", None, 10))
for o in coll:
    K.collider(o)
cassock = add(K.hanging_cone("Cassock", P + G(0, -0.02, 0), 0.19, 0.16, 1.02, 1.1, "pelvis", CLOTH, 72, 34))
cope = add(K.hanging_cone("Cope", C + G(0, 0.15, 0.02), 0.25, 0.2, 0.6, 0.9, "chest", CLOTH, 64, 22, open_front=0.42))
sleeves = []
for tag in ("l", "r"):
    sleeves.append(add(K.hanging_cone("Sleeve", K.SOCKETS["shoulder_" + tag] + G(0, -0.03, 0), 0.07, 0.07, 0.42, 1.4, "shoulder_" + tag, CLOTH, 32, 16)))
K.simulate([cassock, cope] + sleeves, 80, 10.0, 0.25)
for o in [cassock, cope] + sleeves:
    K.solidify(o, 0.008)
for o in coll:
    bpy.data.objects.remove(o)
# the stole: two embroidered bands down the front over the cope
for sx in (-1, 1):
    pts = [C + G(sx * 0.1, 0.16, -0.14) + G(sx * 0.03 * t, -0.62 * t, -0.03 * t) for t in [i / 12.0 for i in range(13)]]
    add(K.loft("Stole", pts, [(0.024, 0.004)] * 13, "chest", GOLD, 8))

# fuse the bone of each socket into one continuous sculpted surface (no primitives meeting)
objs[:] = K.fuse(objs, 0.0028, keep={"Gold", "Flame", "Eye", "Wax", "Cloth", "Sinew"}, sculpt=0.0012, sculpt_scale=0.02, decimate=0.35)
print("ABBOT parts", len(objs))
if PREVIEW:
    K.preview(PREVIEW, 1.1, 4.0)
if EXPORT:
    K.bake_atlas(objs, MATS, "boss_bone_abbot", os.path.join(ROOT, "art", "textures"), 4096)
    # keep the baked scene (UVs included: packing is not repeatable run to run) for re-exports
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "art", "blender", "boss_bone_abbot.blend"))
    K.split_and_export(objs, os.path.join(ROOT, "art", "models", "boss_bone_abbot.glb"), {"crozier": "boss_hand_r"})
