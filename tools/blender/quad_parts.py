"""Small modelling helpers for the quadruped fields (rig space, numpy): limbs, claws, spines, teeth."""
import math
import numpy as np

import quad_sdf as Q


def V(*a):
    return np.array(a, dtype=np.float32)


def unit(v):
    v = np.asarray(v, dtype=np.float32)
    return v / max(float(np.linalg.norm(v)), 1e-9)


def chain(F, pts, rads, k=0.03, tag="hide", flat=1.0, n=(1, 0, 0), part=None):
    """A tapering limb through the points: one round cone per span, radii per point. k may be a list."""
    for i in range(len(pts) - 1):
        kk = k[i] if isinstance(k, (list, tuple)) else k
        F.add(Q.RoundCone(pts[i], pts[i + 1], rads[i], rads[i + 1], flat, n), kk, tag, part)


def arc(p0, p1, bend, n=6):
    """Points from p0 to p1 bowed by `bend` at the middle (quadratic)."""
    p0, p1, bend = V(*p0), V(*p1), V(*bend)
    return [p0 + (p1 - p0) * (i / n) + bend * 4.0 * (i / n) * (1 - i / n) for i in range(n + 1)]


def claw(F, base, d, length, r, curl=(0, -1, 0), k=0.006, tag="claw", n=4, part=None):
    """A hooked claw / thorn / tusk from `base` along d, curling toward `curl`. Returns the tip."""
    d = unit(d)
    cu = V(*curl)
    p = V(*base)
    pts = []
    for i in range(n + 1):
        t = i / n
        pts.append(p.copy())
        p = p + (d * (1 - 0.55 * t) + cu * (0.95 * t * t)) * (length / n)
    rads = [r * (1.0 - 0.88 * (i / n) ** 0.85) for i in range(n + 1)]
    chain(F, pts, rads, [k] + [min(k, 0.005)] * (n - 1), tag, part=part)
    return pts[-1]


def tooth(F, base, d, length, r, tag="tooth", k=0.004):
    d = unit(d)
    F.add(Q.RoundCone(base, V(*base) + d * length, r, r * 0.18), k, tag)


def reflect(p):
    return V(-p[0], p[1], p[2])
