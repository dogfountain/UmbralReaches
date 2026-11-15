"""The Cairn Tower (tools/blender/reach_east.py): a round tower of dry-laid fieldstone, 24 m high, built by pilgrims who
turned back and could not go further: every one of them carried a stone up, so every stone is a different one. Its
walls are battered, bristling with proud stones and chinked with small ones; a ramp of laid slabs winds twice round it
on cairn-piers to a lookout under the sky, a parapet of piled stones, a prayer-pole hung with rags and a cairn at its
middle. A sealed door at the foot, a heaped apron round it.

Local frame: origin on the ground at the tower's axis, the door facing +z.
  Tower     the shaft, lookout, parapet, pole, door, apron, proud stones
  Ramp      the winding ramp and its piers
  TowerFar  silhouette (shaft, lookout, a wedge for the ramp)
  TowerCol  shaft and lookout (collision); RampCol  the ramp's own surface
"""
import math
import random
import bmesh
from mathutils import Vector
import r37_south_lib as L
from r37_south_lib import B, hash3
import reach_east_lib as E

H = 24.0
TURNS = 1.75
RAMP_W = 1.9
RAMP_Y0 = 0.7
A0 = 0.6


def R(y):
    return 5.8 - 0.06 * y


def ramp_pt(t):
    y = RAMP_Y0 + (H - 1.4 - RAMP_Y0) * t
    a = A0 + TURNS * math.tau * t
    return y, a


def lump(b, c, size, seed, mat="stone", roll=0.0):
    """A rounded stone: an icosphere pulled out of true."""
    res = bmesh.ops.create_icosphere(b.bm, subdivisions=1, radius=1.0)
    vs = res["verts"]
    rr = random.Random(seed)
    sx, sy, sz = size
    yaw = rr.uniform(0, math.tau)
    cy, sn = math.cos(yaw), math.sin(yaw)
    for v in vs:
        p = Vector(v.co)
        k = 1.0 + 0.22 * hash3(p.x * 2.1, p.y * 2.1, p.z * 2.1, seed)
        x, y, z = p.x * sx * k, p.y * sy * k, p.z * sz * k
        v.co = Vector((c[0] + x * cy - z * sn, c[1] + y, c[2] + x * sn + z * cy))
    faces = list({f for v in vs for f in v.link_faces})
    for f in faces:
        f.material_index = b.keys.index(mat)
        f.smooth = False
    b._box_uv(faces, 0.17)
    return faces


def stone_mats():
    return {"stone": E.drystone(), "dark": L.flat("E_Dark", (0.01, 0.01, 0.012), 1.0),
            "wood": L.pbr("E_PoleWood", L.tex_planks(512, 7720), 2.0), "cloth": L.flat("E_Rag", (0.34, 0.2, 0.17), 0.95),
            "iron": L.flat("E_Iron2", (0.08, 0.075, 0.07), 0.6, 0.8)}


def shaft(b, seed):
    rr = random.Random(seed)
    rings = []
    ny, na = 44, 56
    for i in range(ny + 1):
        y = -1.2 + (H + 0.2) * i / ny
        ring = []
        for j in range(na):
            a = math.tau * j / na
            k = 1.0 + 0.022 * hash3(math.cos(a) * 3, y * 0.7, math.sin(a) * 3, seed) + 0.012 * hash3(a * 9, y * 2.3, 0.0, seed + 1)
            ring.append(Vector((math.cos(a) * R(max(y, 0)) * k, y, math.sin(a) * R(max(y, 0)) * k)))
        rings.append(ring)
    fs = b.loft(rings, "stone", closed=True, smooth=True, box_uv=0.16)
    # the corbelled lookout: three courses stepping out, then the deck
    prof = [(R(H) + 0.0, H - 0.1), (R(H) + 0.7, H + 0.0), (R(H) + 1.3, H + 0.4), (R(H) + 1.65, H + 0.9), (R(H) + 1.65, H + 1.3), (0.0, H + 1.3)]
    rings = []
    for (r, y) in prof:
        rings.append([Vector((math.cos(math.tau * j / 40) * r, y, math.sin(math.tau * j / 40) * r)) for j in range(40)])
    b.loft(rings, "stone", closed=True, smooth=False, box_uv=0.16, cap_end=True)
    # proud stones on the shaft: courses of them, the outer face bristling
    n_proud = 0
    for i in range(60):
        y = 0.25 + (H - 0.6) * i / 59.0
        nj = int(math.tau * R(y) / 1.15)
        off = rr.random() * math.tau
        for j in range(nj):
            if rr.random() < 0.16:
                continue
            a = off + math.tau * (j + rr.uniform(-0.3, 0.3)) / nj
            sz = rr.uniform(0.5, 0.85)
            r = R(y) + 0.04 + sz * 0.1
            lump(b, (math.cos(a) * r, y, math.sin(a) * r), (sz * rr.uniform(0.85, 1.4), sz * rr.uniform(0.5, 0.75), sz * 0.7), seed * 5 + n_proud)
            n_proud += 1
    return n_proud


def lookout(b, seed):
    rr = random.Random(seed)
    top = H + 1.3
    rim = R(H) + 1.65
    # parapet: a ring of piled stones with a gap on the ramp's side and three more, a cairn at the middle
    gaps = [A0 + TURNS * math.tau, A0 + TURNS * math.tau + math.pi * 0.5 + 0.0]
    for k in range(70):
        a = math.tau * k / 70.0
        if any(abs(((a - g + math.pi) % math.tau) - math.pi) < 0.2 for g in gaps[:1]):
            continue
        for lv in range(3):
            sz = rr.uniform(0.38, 0.6)
            r = rim - 0.3 + rr.uniform(-0.12, 0.12) - lv * 0.03
            lump(b, (math.cos(a) * r, top + 0.22 + lv * 0.3, math.sin(a) * r), (sz * 1.2, sz * 0.62, sz * 0.8), 300 + k * 3 + lv)
    for lv in range(9):
        rad = 1.9 - lv * 0.18
        nn = max(4, int(rad * 6))
        for k in range(nn):
            a = math.tau * (k + 0.3 * lv) / nn
            sz = rr.uniform(0.36, 0.6) * (1.0 - lv * 0.05)
            lump(b, (math.cos(a) * rad * 0.8, top + 0.2 + lv * 0.36, math.sin(a) * rad * 0.8), (sz * 1.1, sz * 0.65, sz * 0.9), 700 + lv * 20 + k)
    lump(b, (0, top + 3.55, 0), (0.55, 0.4, 0.5), 999)
    # the prayer-pole: a mast leaning with the wind, stayed with ropes to the parapet, hung with rags
    px, pz = 1.0, 1.0
    b.tube((px, top + 1.5, pz), (px + 0.9, top + 7.2, pz + 0.6), 0.16, 0.1, "wood", sides=8, bark=1.6)
    for i in range(18):
        a = math.tau * i / 18 + 0.3
        t = rr.uniform(0.25, 0.95)
        ptop = Vector((px + 0.9 * t, top + 1.5 + 5.7 * t, pz + 0.6 * t))
        end = Vector((math.cos(a) * (rim - 0.5), top + 0.8, math.sin(a) * (rim - 0.5)))
        if i % 3 == 0:
            b.tube(ptop, end, 0.025, 0.025, "iron", sides=4, bark=1.0, cap=False)
        # a rag: a tattered strip hanging off the pole or the stay
        d = (end - ptop)
        c = ptop + d * rr.uniform(0.1, 0.5)
        w, h = rr.uniform(0.14, 0.26), rr.uniform(0.5, 1.4)
        b.box((c.x, c.y - h / 2, c.z), (w, h, 0.02), "cloth", yaw=a, pitch=rr.uniform(-0.15, 0.15), cuts=0, jit=0.0, scale_uv=1.0)


def door(b):
    """A sealed door at the foot facing +z: jambs, lintel and a dark recess, the stones round it laid proud."""
    z0 = R(0.0)
    b.box((0, 1.15, z0 + 0.02), (1.35, 2.3, 0.2), "dark", cuts=0)
    for sx in (-1, 1):
        b.box((sx * 0.95, 1.2, z0 + 0.12), (0.5, 2.5, 0.65), "stone", cuts=1, jit=0.04)
    b.box((0, 2.55, z0 + 0.14), (2.7, 0.5, 0.7), "stone", cuts=1, jit=0.03)
    b.box((0, 2.9, z0 + 0.1), (1.5, 0.4, 0.55), "stone", cuts=0, jit=0.03)
    # the door itself: planks, shut, a bar across it
    b.box((0, 1.15, z0 + 0.05), (1.3, 2.2, 0.12), "wood", cuts=0, jit=0.0, scale_uv=0.5)
    b.box((0, 1.0, z0 + 0.13), (1.6, 0.14, 0.1), "iron", cuts=0, jit=0.0)


def apron(b, seed):
    rr = random.Random(seed)
    for ring, (r0, r1, n, hh) in enumerate([(R(0) + 0.2, R(0) + 1.6, 36, 0.9), (R(0) + 1.4, R(0) + 3.2, 52, 0.55), (R(0) + 3.0, R(0) + 5.4, 60, 0.3)]):
        for k in range(n):
            a = math.tau * (k + rr.random()) / n
            r = rr.uniform(r0, r1)
            sz = rr.uniform(0.5, 1.2) * (1.0 + 0.3 * (2 - ring))
            if abs(((a - math.pi / 2 + math.pi) % math.tau) - math.pi) < 0.28 and r < R(0) + 3.4:
                continue                                       # the doorstep
            lump(b, (math.cos(a) * r, hh * 0.45 * rr.uniform(0.6, 1.0) - 0.2, math.sin(a) * r), (sz, sz * 0.62, sz * 0.9), 1500 + ring * 100 + k)


def build_tower(M):
    b = B("Tower", M)
    shaft(b, 11)
    lookout(b, 12)
    door(b)
    apron(b, 13)
    return b.finish()


PIER_EVERY = 11


def pier_near(i):
    d = abs(((i - 6) % PIER_EVERY) - PIER_EVERY / 2.0) / (PIER_EVERY / 2.0)      # 0 at a pier, 1 mid-span
    return (1.0 - d) ** 0.6


def build_ramp(M):
    b = B("Ramp", {"stone": M["stone"], "wood": M["wood"]})
    N = 150
    rings = []
    for i in range(N + 1):
        t = i / N
        y, a = ramp_pt(t)
        ri = R(y) - 0.3
        ro = R(y) + RAMP_W
        ca, sa = math.cos(a), math.sin(a)
        sc = 0.5 + 0.95 * pier_near(i)
        prof = [(ri, y), (ro, y), (ro + 0.12, y - 0.3 - 0.3 * sc), (ro - 0.1, y - sc - 0.45), (ri, y - sc - 0.5)]
        rings.append([Vector((ca * r, yy, sa * r)) for r, yy in prof])
    fs = b.loft(rings, "stone", closed=True, smooth=False, cap_start=True, cap_end=True, box_uv=0.16)
    bmesh.ops.recalc_face_normals(b.bm, faces=fs)
    rr = random.Random(21)
    # slabs and proud stones on the top surface's edge, a kerb of piled stones on the outside
    for i in range(0, N, 1):
        t = i / N
        y, a = ramp_pt(t)
        r = R(y) + RAMP_W + 0.05
        sz = rr.uniform(0.3, 0.52)
        lump(b, (math.cos(a) * r, y + 0.1, math.sin(a) * r), (sz * 0.9, sz * 0.5, sz * 1.3), 4000 + i, roll=a)
        if rr.random() < 0.5:
            lump(b, (math.cos(a) * (r - 0.35), y + 0.04, math.sin(a) * (r - 0.35)), (sz * 0.6, sz * 0.3, sz * 0.8), 5000 + i)
    # the cairn-piers the ramp stands on
    for i in range(6, N, PIER_EVERY):
        t = i / N
        y, a = ramp_pt(t)
        if y < 3.0:
            continue
        r = R(y) + RAMP_W - 0.5
        base = Vector((math.cos(a) * (r + 0.6), -0.4, math.sin(a) * (r + 0.6)))
        topv = Vector((math.cos(a) * r, y - 1.0, math.sin(a) * r))
        b.tube(base, topv, 0.6, 0.42, "stone", sides=7, bark=3.0, jit=0.1, seed=i, cap=False)
        steps = max(2, int((y - 1.0) / 0.62))
        for k in range(steps):
            f = k / steps
            p = base.lerp(topv, f)
            rad = (1.0 + (0.7 - 1.0) * f) * 0.95
            for q in range(3):
                aa = math.tau * (q + rr.random()) / 3
                sz = rr.uniform(0.5, 0.8)
                lump(b, (p.x + math.cos(aa) * rad, p.y, p.z + math.sin(aa) * rad), (sz, sz * 0.85, sz), 6000 + i * 31 + k * 7 + q)
    return b.finish()


def build_far(M):
    b = B("TowerFar", {"stone": M["stone"]})
    rings = []
    for i in range(11):
        y = -1.0 + (H + 0.5) * i / 10
        rings.append([Vector((math.cos(math.tau * j / 18) * R(max(y, 0)), y, math.sin(math.tau * j / 18) * R(max(y, 0)))) for j in range(18)])
    b.loft(rings, "stone", closed=True, smooth=False, cap_end=True, box_uv=0.1)
    rings = []
    for (r, y) in [(R(H), H - 0.1), (R(H) + 1.65, H + 0.9), (R(H) + 1.65, H + 1.9), (R(H) + 0.3, H + 1.9)]:
        rings.append([Vector((math.cos(math.tau * j / 18) * r, y, math.sin(math.tau * j / 18) * r)) for j in range(18)])
    b.loft(rings, "stone", closed=True, smooth=False, cap_end=True, box_uv=0.1)
    # the ramp as a wedge of the same stone hugging the shaft
    N = 40
    rings = []
    for i in range(N + 1):
        y, a = ramp_pt(i / N)
        rings.append([Vector((math.cos(a) * r, yy, math.sin(a) * r)) for r, yy in [(R(y) - 0.3, y), (R(y) + RAMP_W, y), (R(y) + RAMP_W * 0.6, y - 1.4), (R(y) - 0.3, y - 1.4)]])
    fs = b.loft(rings, "stone", closed=True, smooth=False, cap_start=True, cap_end=True, box_uv=0.1)
    bmesh.ops.recalc_face_normals(b.bm, faces=fs)
    return b.finish()


def build_col(M):
    b = B("TowerCol", {"stone": M["stone"]})
    rings = []
    for i in range(9):
        y = -1.0 + (H + 2.3) * i / 8
        r = R(max(y, 0)) if y < H else R(H) + 1.6
        rings.append([Vector((math.cos(math.tau * j / 20) * r, y, math.sin(math.tau * j / 20) * r)) for j in range(20)])
    b.loft(rings, "stone", closed=True, smooth=False, cap_end=True, box_uv=0.1)
    return b.finish()


def build_ramp_col(M):
    b = B("RampCol", {"stone": M["stone"]})
    N = 150
    rings = []
    for i in range(N + 1):
        y, a = ramp_pt(i / N)
        ri, ro = R(y) - 0.3, R(y) + RAMP_W + 0.3
        ca, sa = math.cos(a), math.sin(a)
        rings.append([Vector((ca * r, yy, sa * r)) for r, yy in [(ri, y), (ro, y), (ro, y - 1.0), (ri, y - 1.0)]])
    fs = b.loft(rings, "stone", closed=True, smooth=False, cap_start=True, cap_end=True, box_uv=0.1)
    bmesh.ops.recalc_face_normals(b.bm, faces=fs)
    return b.finish()


def build_all(objs, DATA):
    M = stone_mats()
    objs.append(build_tower(M))
    objs.append(build_ramp(M))
    objs.append(build_far(M))
    objs.append(build_col(M))
    objs.append(build_ramp_col(M))
    DATA["TOWER_H"] = H + 1.3
    DATA["TOWER_TOP_R"] = R(H) + 1.65
    DATA["RAMP_TOP_A"] = ramp_pt(1.0)[1]
    DATA["RAMP_TOP_Y"] = ramp_pt(1.0)[0]
    DATA["RAMP_START_A"] = ramp_pt(0.0)[1]
