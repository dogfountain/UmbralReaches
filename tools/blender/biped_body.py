"""The sculpted body shared by the remodelled bipeds (r38 remodel): grunt_body.py's fused skin + sculpt, as one
call. Returns a Ctx with the two high-poly surfaces (torso+legs+head, arms+hands) for garments to be cut from,
their decimated game copies, the bake pairs, nails / teeth / eyes, and the rig-space helper SP().

  ctx = body(OPT, SKIN, CLAW, EYE, claw=0.06, teeth=True, nails=True, eyes=True)
"""
import bpy
import math
import os
import sys
from mathutils import Vector

sys.path.insert(0, os.path.dirname(__file__))
import boss_kit as K
import grunt_kit as GK
import grunt_body as GB
from boss_kit import G


class Ctx:
    pass


def body(OPT, SKIN, CLAW, EYE, claw=0.06, teeth=True, nails=True, eyes=True, body_tris=4600, arm_tris=1800, face=None, voxel=0.005, extra=None, toe_claws=True, skel=None, mouth=0.0):
    c = Ctx()
    c.OPT = OPT
    c.objs, c.pairs = [], []
    sk, segs, Y = GB.humanoid(OPT)
    if skel is not None:
        skel(sk)
    c.sk, c.segs, c.Y = sk, segs, Y
    c.hi = {}
    for skx, nm, root, tr in ((sk, "Body", "pel", body_tris), (sk.arms, "Arms", ["trpl", "trpr"], arm_tris)):
        hi = GB.build_skin(skx, nm + "High", root, voxel)
        sc = GB.Sculpt(hi)
        GB.humanoid_sculpt(sc, OPT, Y)
        if extra is not None:
            extra(sc, Y, nm)
        sc.apply()
        hi.data.materials.append(SKIN.m)
        hi.hide_render = True
        hi.hide_viewport = True
        lo = GB.make_low(hi, tr, nm + "Low")
        lo["sock"] = "bodyskin" if nm == "Body" else "armskin"
        lo["fixed"] = True
        c.pairs.append((lo, hi))
        c.objs.append(lo)
        c.hi[nm] = hi

    def SP(nm):
        return sk.p[sk.idx[nm]] if nm in sk.idx else sk.arms.p[sk.arms.idx[nm]]
    c.SP = SP
    if nails:
        for tag, sx in (("l", -1), ("r", 1)):
            for k in range(4):
                tip = Vector(SP("f%d%s3" % (k, tag)))
                prev = Vector(SP("f%d%s2" % (k, tag)))
                d = (tip - prev).normalized() + Vector(G(0, -0.25, -0.3))
                c.objs.append(GK.claw("Claw", tip - (tip - prev).normalized() * 0.005, d, claw * 1.1 + 0.02, 0.0042, "arm_" + tag, CLAW, 0.5))
            tt = Vector(SP("th%s2" % tag))
            tp = Vector(SP("th%s1" % tag))
            c.objs.append(GK.claw("Claw", tt, (tt - tp).normalized() + Vector(G(0, -0.2, -0.3)), claw * 0.9 + 0.015, 0.0045, "arm_" + tag, CLAW, 0.5))
            for k in range(4 if toe_claws else 0):
                tt = Vector(SP("t%d%s1" % (k, tag)))
                c.objs.append(GK.claw("Claw", tt, Vector(G(0, -0.3, -1.0)), 0.025, 0.0045, "leg_" + tag, CLAW, 0.7))
    hy = Y(OPT["hc"][1])
    hz = OPT["hc"][2]
    hw = OPT["head_w"] / 0.078
    c.hy, c.hz, c.hw = hy, hz, hw
    if not OPT.get("nohead"):
        if teeth:
            for row, (dy, sgn) in enumerate(((-0.058, -1), (-0.07 - mouth, 1))):
                for k in range(9):
                    a = math.pi * (0.18 + 0.64 * k / 8.0)
                    base = Vector(G(math.cos(a) * 0.034 * hw, hy + dy, hz - 0.058 - math.sin(a) * 0.026))
                    c.objs.append(K.loft("Tooth", [base, base + Vector(G(0, -sgn * 0.016, 0))], [0.0045, 0.0], "head", CLAW, 5, cap0=False))
        if eyes:
            for sx in (-1, 1):
                c.objs.append(K.blob("Eye", Vector(G(sx * 0.034 * hw, hy + 0.012, hz - 0.075)), (0.0115, 0.007, 0.0115), "head", EYE, 12, 8))
    return c


def fast_ao(samples=16):
    """The shared high-to-low bake spends 48 AO samples a pair; a remodel bakes many pairs, so run it with fewer
    (the AO is soft and smooth; 16 is clean enough at 2048). Patches only this process's copy."""
    import inspect
    src = inspect.getsource(GK.bake_atlas_hl).replace("48 if kind == 'AO' else 1", "%d if kind == 'AO' else 1" % samples)
    ns = dict(GK.__dict__)
    exec(src, ns)
    GK.bake_atlas_hl = ns["bake_atlas_hl"]


def lean(max_sides=6, small=0.085):
    """The accessories (ropes, charms, rivets, cords) were built at full-size resolution; a pawn is seen at metres, so this
    process-wide cap thins the small primitives: loft sections to `max_sides`, curve tubes to 2 bevel steps, blobs under
    `small` metres to ~60% of their segments. Big shapes (skulls, sacks) are untouched."""
    blob0, loft0, tube0 = K.blob, K.loft, K.curve_tube

    def blob(name, center, radii, sock, mat, segs=32, rings=16, deform=None):
        if max(radii) < small:
            segs, rings = max(8, int(segs * 0.6)), max(6, int(rings * 0.6))
        return blob0(name, center, radii, sock, mat, segs, rings, deform)

    def loft(name, pts, radii, sock, mat, sides=12, squash=(1.0, 1.0), cap0=True, cap1=True, wobble=0.0, seed=0.0):
        return loft0(name, pts, radii, sock, mat, min(sides, max_sides) if len(pts) < 40 else sides, squash, cap0, cap1, wobble, seed)

    def tube(name, pts, radius, sock, mat, taper=None, closed=False, res=4):
        return tube0(name, pts, radius, sock, mat, taper, closed, min(res, 2))
    K.blob, K.loft, K.curve_tube = blob, loft, tube
