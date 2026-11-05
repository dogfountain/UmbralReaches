"""The Ascended Warden (r30): the last priest, floating over the dais in a bell robe of pale linen
(no legs), a white-gold mask with slit eyes and a hairline crack, a veil, a mandorla of light,
long open hands in gilt bracers. Modelled in the rig's rest pose, cloth simulated, baked, split.

  tools/blender/run.sh boss_ascended_warden.py -- [--preview /tmp/warden.png] [--no-export]
Writes art/models/boss_ascended_warden.glb and art/textures/boss_ascended_warden_*.png
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


def linen_mat():
    m = K.Mat("Linen")
    sc = m.scan("rough_linen", 7.0)
    weave = sc["disp"]
    blot = m.noise(4.0, 6.0, 0.6)
    col = m.mul(m.mono(sc["color"]), (1.2, 1.15, 1.04))
    col = m.mix(m.math('MULTIPLY', blot, 0.3), col, (0.5, 0.47, 0.41))
    z = m.zpos()
    # grime rising from the hem, and a gilt band of runes above it
    grime = m.math('SUBTRACT', 1.0, m.math('MULTIPLY', m.math('SUBTRACT', z, 0.28), 2.2), True)
    col = m.mix(m.math('MULTIPLY', grime, 0.55), col, (0.22, 0.2, 0.17))
    band = m.math('MULTIPLY', m.math('GREATER_THAN', z, 0.34), m.math('LESS_THAN', z, 0.46))
    rules = m.math('ADD', m.math('MULTIPLY', m.math('GREATER_THAN', z, 0.34), m.math('LESS_THAN', z, 0.352)),
                   m.math('MULTIPLY', m.math('GREATER_THAN', z, 0.448), m.math('LESS_THAN', z, 0.46)))
    brick = m.n('ShaderNodeTexBrick')
    brick.inputs['Scale'].default_value = 26.0
    brick.inputs['Mortar Size'].default_value = 0.08
    m.links.new(m.coord.outputs['Object'], brick.inputs['Vector'])
    runes = m.math('MULTIPLY', m.math('GREATER_THAN', m.voronoi(70.0, 'DISTANCE_TO_EDGE'), 0.06),
                   m.math('LESS_THAN', brick.outputs['Fac'], 0.5))
    inner = m.math('MULTIPLY', m.math('GREATER_THAN', z, 0.36), m.math('LESS_THAN', z, 0.44))
    gilt = m.math('MAXIMUM', rules, m.math('MULTIPLY', m.math('SUBTRACT', 1.0, runes), inner), True)
    gilt = m.math('MULTIPLY', gilt, band)
    col = m.mix(gilt, col, (0.72, 0.5, 0.18))
    h = m.math('ADD', m.math('MULTIPLY', weave, 0.45), m.math('MULTIPLY', gilt, 0.5))
    rough = m.math('SUBTRACT', 0.9, m.math('MULTIPLY', gilt, 0.5))
    return m.finish(col, rough, m.math('MULTIPLY', gilt, 0.9), h, 0.45, 0.002)


def gold_mat(name="Gold", base=(0.8, 0.58, 0.24)):
    m = K.Mat(name)
    wear = m.noise(16.0, 6.0, 0.6)
    col = m.ramp(wear, [(0.3, (0.34, 0.22, 0.08)), (0.62, base), (0.9, (0.96, 0.8, 0.46))])
    rough = m.math('ADD', 0.2, m.math('MULTIPLY', m.math('SUBTRACT', 1.0, wear), 0.35))
    return m.finish(col, rough, 0.95, m.noise(110.0, 3.0, 0.5), 0.2, 0.002)


def mask_mat():
    m = K.Mat("Mask")
    scr = m.noise(240.0, 2.0, 0.5)
    tone = m.noise(6.0, 4.0, 0.5)
    col = m.ramp(tone, [(0.3, (0.82, 0.72, 0.5)), (0.8, (0.98, 0.92, 0.76))])
    crack = m.math('LESS_THAN', m.voronoi(9.0, 'DISTANCE_TO_EDGE'), 0.01)
    crack = m.math('MULTIPLY', crack, m.math('GREATER_THAN', m.noise(4.0, 2.0, 0.5), 0.58))
    col = m.mix(crack, col, (0.08, 0.05, 0.02))
    h = m.math('ADD', m.math('MULTIPLY', scr, 0.15), m.math('MULTIPLY', crack, -0.8))
    return m.finish(col, m.math('ADD', 0.18, m.math('MULTIPLY', scr, 0.15)), 0.55, h, 0.4, 0.002)


def ash_mat():
    m = K.Mat("Ash")
    sc = m.scan("beige_wall_001", 9.0)
    col = m.mul(m.mono(sc["color"]), (0.6, 0.58, 0.57))
    return m.finish(col, m.math('ADD', m.math('MULTIPLY', sc["rough"], 0.5), 0.35), 0.0, sc["disp"], 0.8, 0.002)


def glow_mat(name, col, strength):
    m = K.Mat(name)
    return m.finish((0.08, 0.07, 0.05), 0.5, 0.0, None, emit=col, emit_strength=strength)


LINEN = linen_mat()
GOLD = gold_mat()
MASK = mask_mat()
ASH = ash_mat()
HALO = glow_mat("Halo", (1.0, 0.86, 0.6), 8.0)
EYE = glow_mat("Eye", (1.0, 0.9, 0.7), 8.0)
MATS = [LINEN, GOLD, MASK, ASH, HALO, EYE]
objs = []


def add(o):
    objs.append(o)
    return o


C = K.SOCKETS["chest"]
P = K.SOCKETS["pelvis"]
HD = K.SOCKETS["head"]

# --- the mask: an oval of white gold, a calm face sculpted in low relief, slit eyes, a crack -------------
FC = HD + G(0, 0.075, -0.07)


def face(c):
    p = Vector(c)
    n = p.normalized()
    def bump(at, r, h):
        return h * math.exp(-((p - at).length / r) ** 2)
    push = 0.0
    push += bump(Vector((0.0, 1.0, -0.05)), 0.14, 0.22)          # nose ridge
    push += bump(Vector((0.0, 0.93, 0.3)), 0.28, 0.12)           # brow
    for sx in (-1, 1):
        push -= bump(Vector((sx * 0.36, 0.9, 0.12)), 0.17, 0.2)  # eye hollows
        push += bump(Vector((sx * 0.5, 0.78, -0.25)), 0.22, 0.1) # cheeks
        push -= bump(Vector((sx * 0.42, 0.85, -0.45)), 0.18, 0.08)
    push -= bump(Vector((0.0, 0.95, -0.48)), 0.1, 0.07)          # the closed mouth line
    push += bump(Vector((0.0, 0.9, -0.62)), 0.2, 0.06)           # chin
    if p.y < -0.1:
        p.y *= 0.35                                               # a mask, not a head: flat behind
    return p + n * push


mask = add(K.blob("Mask", FC, (0.09, 0.07, 0.125), "head", MASK, 64, 32, face))
K.subsurf(mask, 1)
for sx in (-1, 1):
    add(K.blob("Slit", FC + G(sx * 0.033, 0.016, -0.058), (0.03, 0.006, 0.008), "head", EYE, 16, 6))
# the skull behind the mask, wrapped (only the back and crown show under the veil)
add(K.blob("Crown", HD + G(0, 0.08, 0.02), (0.085, 0.1, 0.095), "head", ASH, 32, 16))
# the mandorla: a solid ring, a hairline inner ring, sixteen blades, and a boss at each quarter
HC = HD + G(0, 0.14, 0.2)
ring = [HC + Vector((math.cos(a) * 0.34, 0.0, math.sin(a) * 0.34)) for a in [math.tau * i / 64 for i in range(65)]]
add(K.curve_tube("Halo", ring, 0.016, "head", HALO))
ring2 = [HC + Vector((math.cos(a) * 0.27, 0.0, math.sin(a) * 0.27)) for a in [math.tau * i / 48 for i in range(49)]]
add(K.curve_tube("Halo2", ring2, 0.006, "head", HALO))
for k in range(16):
    a = math.tau * k / 16.0
    d = Vector((math.cos(a), 0.0, math.sin(a)))
    ln = 0.13 if k % 2 == 0 else 0.07
    add(K.loft("Blade", [HC + d * 0.275, HC + d * (0.34 + ln * 0.4), HC + d * (0.35 + ln)], [(0.012, 0.004), (0.02, 0.005), (0.0, 0.0)], "head", HALO, 8))
for k in range(4):
    a = math.tau * k / 4.0 + math.pi * 0.25
    add(K.blob("HaloBoss", HC + Vector((math.cos(a) * 0.34, 0.0, math.sin(a) * 0.34)), (0.028, 0.02, 0.028), "head", GOLD, 16, 8))

# --- the body under the robe: a gaunt ashen torso, collarbones (only the throat shows) ---------------------
add(K.blob("Torso", C + G(0, -0.02, 0.0), (0.14, 0.11, 0.2), "chest", LINEN, 32, 16))
add(K.blob("Pectoral", C + G(0, 0.04, -0.115), (0.07, 0.012, 0.07), "chest", GOLD, 32, 10))
ring = [C + G(0, 0.04, -0.125) + Vector((math.cos(a) * 0.06, 0.0, math.sin(a) * 0.06)) for a in [math.tau * i / 40 for i in range(41)]]
add(K.curve_tube("PectoralRim", ring, 0.005, "chest", GOLD))
add(K.blob("PectoralEye", C + G(0, 0.04, -0.128), (0.016, 0.006, 0.016), "chest", EYE, 16, 8))
add(K.loft("Neck", [C + G(0, 0.14, 0.01), HD + G(0, 0.02, 0.0)], [0.045, 0.04], "chest", ASH, 16))

# --- arms: long forearms in gilt bracers, long open hands, four fingers and a thumb -----------------------
for tag, sx in (("l", -1), ("r", 1)):
    S, E, H = K.SOCKETS["shoulder_" + tag], K.SOCKETS["elbow_" + tag], K.SOCKETS["hand_" + tag]
    add(K.loft("Upper", [S, E], [0.04, 0.032], "shoulder_" + tag, ASH, 16, wobble=0.05))
    add(K.loft("Fore", [E, H], [0.03, 0.022], "elbow_" + tag, ASH, 16, wobble=0.05))
    br = [E + (H - E) * t + G(0, 0, 0) for t in (0.35, 0.5, 0.65, 0.8, 0.95)]
    add(K.loft("Bracer", br, [0.034, 0.033, 0.031, 0.028, 0.026], "elbow_" + tag, GOLD, 18))
    for k, t in enumerate((0.38, 0.62, 0.9)):
        ringp = [E + (H - E) * t + Vector((math.cos(a) * 0.036, math.sin(a) * 0.036, 0)) for a in [math.tau * i / 24 for i in range(25)]]
        add(K.curve_tube("Bracer rim", ringp, 0.004, "elbow_" + tag, GOLD))
    add(K.blob("Palm", H + G(0, -0.04, -0.005), (0.032, 0.05, 0.014), "hand_" + tag, ASH, 20, 12))
    for f in range(4):
        fx = (f - 1.5) * 0.017
        a = H + G(fx, -0.085, -0.004)
        pts = [a, a + G(fx * 0.15, -0.06, -0.006), a + G(fx * 0.25, -0.11, -0.014), a + G(fx * 0.3, -0.15, -0.026)]
        add(K.loft("Finger", pts, [0.0075, 0.0066, 0.0055, 0.0035], "hand_" + tag, ASH, 10, wobble=0.06))
        if f == 1:
            r = [a + G(fx * 0.15, -0.035, -0.006) + Vector((math.cos(q) * 0.009, math.sin(q) * 0.009, 0)) for q in [math.tau * i / 16 for i in range(17)]]
            add(K.curve_tube("Ring", r, 0.0025, "hand_" + tag, GOLD))
    tb = H + G(-sx * 0.03, -0.04, -0.012)
    add(K.loft("Thumb", [tb, tb + G(-sx * 0.025, -0.05, -0.02), tb + G(-sx * 0.03, -0.085, -0.035)], [0.008, 0.0065, 0.004], "hand_" + tag, ASH, 10))

# --- cloth: the bell robe (pelvis), a mantle (chest), the veil (head), bell sleeves -----------------------
coll = [K.blob("ColBody", P + G(0, 0.0, 0), (0.17, 0.14, 0.2), "pelvis", None, 24, 12),
        K.blob("ColTorso", C + G(0, -0.02, 0.0), (0.16, 0.13, 0.24), "chest", None, 24, 12),
        K.blob("ColHead", HD + G(0, 0.08, 0.0), (0.1, 0.1, 0.13), "head", None, 24, 12)]
for tag in ("l", "r"):
    coll.append(K.blob("ColSh", K.SOCKETS["shoulder_" + tag], (0.06, 0.06, 0.06), "chest", None, 16, 8))
    coll.append(K.loft("ColArm", [K.SOCKETS["shoulder_" + tag], K.SOCKETS["elbow_" + tag]], [0.045, 0.04], "chest", None, 10))
for o in coll:
    K.collider(o)
robe = add(K.hanging_cone("Robe", P + G(0, 0.02, 0), 0.19, 0.17, 0.7, 2.2, "pelvis", LINEN, 80, 34))
mantle = add(K.hanging_cone("Mantle", C + G(0, 0.15, 0.02), 0.24, 0.2, 0.5, 1.0, "chest", LINEN, 64, 22, open_front=0.38))
veil = add(K.hanging_cone("Veil", HD + G(0, 0.2, 0.03), 0.07, 0.07, 0.62, 1.8, "head", LINEN, 40, 22, open_front=1.2))
sleeves = [add(K.hanging_cone("Sleeve", K.SOCKETS["shoulder_" + tag] + G(0, -0.04, 0), 0.065, 0.065, 0.46, 2.0, "shoulder_" + tag, LINEN, 36, 18)) for tag in ("l", "r")]
K.simulate([robe, mantle, veil] + sleeves, 80, 9.0, 0.2)
for o in [robe, mantle, veil] + sleeves:
    K.solidify(o, 0.007)
for o in coll:
    bpy.data.objects.remove(o)
# the gilt stole
for sx in (-1, 1):
    pts = [C + G(sx * 0.09, 0.16, -0.15) + G(sx * 0.02 * t, -0.7 * t, -0.04 * t) for t in [i / 12.0 for i in range(13)]]
    add(K.loft("Stole", pts, [(0.024, 0.004)] * 13, "chest", GOLD, 8))

objs[:] = K.fuse(objs, 0.0028, keep={"Gold", "Halo", "Eye", "Linen", "Mask"}, sculpt=0.001, sculpt_scale=0.02, decimate=0.35)
print("WARDEN parts", len(objs))
if PREVIEW:
    K.preview(PREVIEW, 1.15, 4.4)
if EXPORT:
    K.bake_atlas(objs, MATS, "boss_ascended_warden", os.path.join(ROOT, "art", "textures"), 4096)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "art", "blender", "boss_ascended_warden.blend"))
    K.split_and_export(objs, os.path.join(ROOT, "art", "models", "boss_ascended_warden.glb"))
