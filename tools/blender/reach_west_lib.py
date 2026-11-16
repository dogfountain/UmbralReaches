"""Far Reaches, West Reach: masonry and timber helpers shared by reach_west*.py (Blender, run through run.sh).

Built on the house helpers in r37_west.py (Parts, box, beam, cyl, finish, make_collision, export, preview). Walls are
laid course by course, block by block, from a mask (`solid(u, v)`: is there wall at distance u along it and v up it),
so a breach, a window or an arch is the mask's shape and the break is ragged stone by stone. The same mask makes the
collision (columns merged to boxes), so what you walk on is what is drawn.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import bmesh
from mathutils import Vector, Matrix
import r37_west as W

Parts, box, beam, cyl, fbm, smoothstep, ring_loft = W.Parts, W.box, W.beam, W.cyl, W.fbm, W.smoothstep, W.ring_loft
finish, make_collision, export, preview, reset = W.finish, W.make_collision, W.export, W.preview, W.reset
MODELS = W.MODELS
BLEND = W.BLEND
tris = W.tris


def rnd_for(seed):
    return random.Random(seed)


def merged_intervals(fn, v0, v1, step=0.25):
    """Where fn(v) is true on [v0, v1], as [a, b] intervals."""
    out = []
    a = None
    n = int(round((v1 - v0) / step))
    for i in range(n + 1):
        v = v0 + i * step
        s = fn(v)
        if s and a is None:
            a = v
        if not s and a is not None:
            out.append([a, v])
            a = None
    if a is not None:
        out.append([a, v1])
    return out


def wall_run(P, Pc, key, a, b, z0, h, thick, solid, rnd, ch=0.5, ext=None, col=True, blk=(0.8, 1.7), gap=0.0):
    """A wall from plan point a to b (Vector2/3 xy), laid in courses. solid(u, v) says where stone is.
    ext(j) -> (e0, e1): metres the course runs past a and b (corner bonding)."""
    a = Vector((a[0], a[1], 0.0))
    b = Vector((b[0], b[1], 0.0))
    d = b - a
    L = d.length
    d.normalize()
    yaw = math.atan2(d.y, d.x)
    n = Vector((-d.y, d.x, 0.0))
    ncourse = int(h / ch + 0.999)
    cheights = [ch * rnd.uniform(0.86, 1.18) for _ in range(ncourse + 6)]
    # normalise so the courses fill h
    sc = h / sum(cheights[:ncourse])
    v = 0.0
    for j in range(ncourse):
        chj = cheights[j] * sc
        vm = v + chj * 0.5
        e0, e1 = ext(j) if ext else (0.0, 0.0)
        u = -e0 + rnd.uniform(0.0, 0.6) * (1 if j % 2 else 0)
        while u < L + e1 - 0.05:
            ln = rnd.uniform(*blk)
            if u + ln > L + e1:
                ln = L + e1 - u
            if ln < 0.3:
                break
            uc = u + ln * 0.5
            ok = True
            for t in (-0.42, 0.0, 0.42):
                if not solid(min(max(uc + t * ln, 0.0), L), vm):
                    ok = False
                    break
            if ok and solid(min(max(uc, 0.0), L), v + chj * 0.92):
                depth = thick * rnd.uniform(0.995, 1.02)
                off = rnd.uniform(-0.012, 0.012)
                c = a + d * uc + n * off
                size = (max(ln - gap - 0.03, 0.2), depth, chj * 0.94)
                box(P, key, (c.x, c.y, z0 + vm), size, yaw=yaw + rnd.uniform(-0.004, 0.004), pitch=rnd.uniform(-0.002, 0.002))
            u += ln
        v += chj
    if col:
        wall_collision(Pc, a, d, L, z0, h, thick, solid)


def wall_collision(Pc, a, d, L, z0, h, thick, solid, cw=1.2):
    n = Vector((-d.y, d.x, 0.0))
    yaw = math.atan2(d.y, d.x)
    k = 0
    u = 0.0
    while u < L - 1e-4:
        w = min(cw, L - u)
        uc = u + w * 0.5
        for (v0, v1) in merged_intervals(lambda v: solid(uc, v), 0.0, h, 0.25):
            if v1 - v0 < 0.3:
                continue
            c = a + d * uc
            box(Pc, "stone", (c.x, c.y, z0 + (v0 + v1) * 0.5), (w, thick, v1 - v0), yaw=yaw)
        u += w


def ring_wall(P, Pc, key, c, r, z0, h, thick, solid, rnd, ch=0.5, blk=(0.8, 1.5), col=True, arc=(0.0, math.tau)):
    """A round wall about centre c, radius r (to the centre of the thickness). solid(theta, v), theta from +x."""
    ncourse = int(h / ch + 0.999)
    cheights = [ch * rnd.uniform(0.86, 1.18) for _ in range(ncourse + 6)]
    sc = h / sum(cheights[:ncourse])
    v = 0.0
    span = arc[1] - arc[0]
    for j in range(ncourse):
        chj = cheights[j] * sc
        vm = v + chj * 0.5
        nb = max(int(r * span / 1.15), 6)
        off = rnd.uniform(0, 1) if j % 2 else 0.0
        for i in range(nb):
            th = arc[0] + span * (i + 0.5 + off * 0.5) / nb
            dth = span / nb
            if th > arc[1] + 1e-6:
                continue
            if solid(th, vm) and solid(th - dth * 0.4, vm) and solid(th + dth * 0.4, vm) and solid(th, v + chj * 0.92):
                depth = thick * rnd.uniform(0.995, 1.02)
                ln = r * dth * 1.02
                px = c[0] + math.cos(th) * (r + rnd.uniform(-0.012, 0.012))
                py = c[1] + math.sin(th) * (r + rnd.uniform(-0.012, 0.012))
                box(P, key, (px, py, z0 + vm), (ln, depth, chj * 0.94), yaw=th + math.pi * 0.5 + rnd.uniform(-0.004, 0.004))
        v += chj
    if col:
        nb = max(int(r * span / 1.3), 6)
        for i in range(nb):
            th = arc[0] + span * (i + 0.5) / nb
            for (v0, v1) in merged_intervals(lambda vv: solid(th, vv), 0.0, h, 0.25):
                if v1 - v0 < 0.3:
                    continue
                px, py = c[0] + math.cos(th) * r, c[1] + math.sin(th) * r
                box(Pc, "stone", (px, py, z0 + (v0 + v1) * 0.5), (r * span / nb * 1.04, thick, v1 - v0), yaw=th + math.pi * 0.5)


def ragged_top(seed, h, amp, scale=0.35, base_u=0.0):
    """A top edge: solid(u, v) is false above h - amp*breakage(u)."""
    def top(u):
        t = fbm(Vector((u * scale + base_u, seed * 3.1, 0.7)), 3) * 0.5 + 0.5
        return h - amp * max(0.0, t * 1.5 - 0.25)
    return top


def arch_hole(u, v, cu, w, sill, spring, top_pad=0.0):
    """True inside an arched opening: centred cu, width w, from sill, round head springing at `spring`."""
    du = abs(u - cu)
    if du > w * 0.5 or v < sill:
        return False
    if v <= spring:
        return True
    r = w * 0.5
    return (v - spring) <= math.sqrt(max(r * r - du * du, 0.0)) + top_pad


def rect_hole(u, v, cu, w, v0, v1):
    return abs(u - cu) <= w * 0.5 and v0 <= v <= v1


def voussoirs(P, key, centre, yaw, w, spring, depth, ring=0.5, n=13, Pc=None):
    """A stone ring over a round-headed opening in a wall whose normal is the model's local y (yaw about z).
    centre: (x, y, z of the sill); w the opening's width."""
    r_in = w * 0.5
    base = Vector(centre)
    M = Matrix.Rotation(yaw, 4, 'Z')
    for k in range(n):
        am = math.pi * (k + 0.5) / n
        lu = -math.cos(am) * (r_in + ring * 0.5)
        lv = spring + math.sin(am) * (r_in + ring * 0.5)
        p = base + (M @ Vector((lu, 0.0, lv)))
        ln = math.pi * (r_in + ring * 0.5) / n * 1.04
        box(P, key, p, (ln, depth, ring), yaw=yaw, roll=am - math.pi * 0.5)
        if Pc is not None:
            box(Pc, "stone", p, (ln, depth, ring), yaw=yaw, roll=am - math.pi * 0.5)


def course_ring_block(P, key, c, th, r, ln, depth, ch, yaw):
    box(P, key, (c[0] + math.cos(th) * r, c[1] + math.sin(th) * r, c[2]), (ln, depth, ch), yaw=yaw)


def rubble(P, Pc, key, rnd, area, n, smin=0.4, smax=1.5, ground=0.0, rect_excl=None):
    """Fallen blocks scattered over `area` (x0, y0, x1, y1)."""
    for _ in range(n):
        x = rnd.uniform(area[0], area[2])
        y = rnd.uniform(area[1], area[3])
        if rect_excl and rect_excl(x, y):
            continue
        s = rnd.uniform(smin, smax)
        box(P, key, (x, y, ground + s * 0.22), (s * rnd.uniform(0.9, 1.7), s * rnd.uniform(0.6, 1.1), s * rnd.uniform(0.45, 0.8)),
            yaw=rnd.random() * 6.28, pitch=rnd.uniform(-0.3, 0.3), roll=rnd.uniform(-0.3, 0.3))


def rock_lump(P, key, c, size, rnd, seg=(7, 5)):
    """A rough rock: a squashed UV sphere with its vertices displaced by noise (boulder, tor, scree)."""
    bm = P.of(key)
    geo = bmesh.ops.create_uvsphere(bm, u_segments=seg[0] + 2, v_segments=seg[1] + 2, radius=1.0)
    s0 = rnd.random() * 50
    for vtx in geo["verts"]:
        u = vtx.co.copy()
        k = 1.0 + 0.32 * fbm(u * 1.7 + Vector((s0, 0, 0)), 3)
        vtx.co = Vector((u.x * size[0] * k, u.y * size[1] * k, u.z * size[2] * k)) + Vector(c)


def stair_flight(P, Pc, key, p0, p1, width, rise, z0, steps, thick=0.5, solid_down=None, wall_side=1):
    """Cantilevered stone steps from plan point p0 towards p1 (steps of equal tread), rising `rise` each from z0.
    solid_down: when set, each step is solid down to that z."""
    p0 = Vector((p0[0], p0[1], 0.0))
    p1 = Vector((p1[0], p1[1], 0.0))
    d = p1 - p0
    L = d.length
    d.normalize()
    yaw = math.atan2(d.y, d.x)
    tread = L / steps
    for i in range(steps):
        zt = z0 + rise * (i + 1)
        c = p0 + d * (tread * (i + 0.5))
        if solid_down is None:
            box(P, key, (c.x, c.y, zt - thick * 0.5), (tread * 1.02, width, thick), yaw=yaw)
            box(Pc, "stone", (c.x, c.y, zt - thick * 0.5), (tread * 1.02, width, thick), yaw=yaw)
        else:
            hh = zt - solid_down
            box(P, key, (c.x, c.y, solid_down + hh * 0.5), (tread * 1.02, width, hh), yaw=yaw)
            box(Pc, "stone", (c.x, c.y, solid_down + hh * 0.5), (tread * 1.02, width, hh), yaw=yaw)


def crenels(P, Pc, key, a, b, z, rnd, w=1.0, gap=0.9, hgt=1.1, thick=0.7, off=0.0, broken=None):
    """Merlons along a wall's top from a to b at height z (their bottom), centred `off` metres off the wall's line."""
    a = Vector((a[0], a[1], 0.0))
    b = Vector((b[0], b[1], 0.0))
    d = b - a
    L = d.length
    d.normalize()
    n = Vector((-d.y, d.x, 0.0))
    yaw = math.atan2(d.y, d.x)
    u = 0.3
    while u + w < L - 0.2:
        if broken is None or not broken(u):
            hh = hgt * rnd.uniform(0.85, 1.05)
            c = a + d * (u + w * 0.5) + n * off
            box(P, key, (c.x, c.y, z + hh * 0.5), (w, thick, hh), yaw=yaw)
            box(P, key, (c.x, c.y, z + hh + 0.04), (w + 0.1, thick + 0.1, 0.1), yaw=yaw)
            box(Pc, "stone", (c.x, c.y, z + hh * 0.5), (w, thick, hh), yaw=yaw)
        u += w + gap


def bake_blend(name):
    os.makedirs(BLEND, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(BLEND, name + ".blend"))
