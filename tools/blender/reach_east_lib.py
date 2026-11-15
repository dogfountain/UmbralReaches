"""The East Reach's shared helpers (tools/blender/reach_east.py): the materials its four landmarks are made of and the
grid shell the great bell is cut from. Godot coordinates (x right, y up, z towards the viewer), 1 unit = 1 m, like
r37_south_lib. Textures are made here (spectral noise), nothing is downloaded.

  bronze()      the Founder's bronze, gone green in the hollows and black with soot on the weather side
  scorch()      rock a fire has been through: black glass, red-brown crust, ash
  drystone()    pilgrims' dry-laid fieldstone (the Cairn Tower), no mortar, lichen
  nave_stone()  the cathedral's pale ashlar, water-stained at the foot
"""
import math
import numpy as np
import r37_south_lib as L
from r37_south_lib import fbm, smooth, tint


def tex_bronze(n, seed):
    big = fbm(n, 2.6, seed)
    mid = fbm(n, 1.7, seed + 1)
    fine = fbm(n, 1.2, seed + 2)
    pit = smooth(fbm(n, 2.2, seed + 3), 0.62, 0.82)
    streak = smooth(fbm(n, 2.4, seed + 4, aniso=10.0), 0.5, 0.85)
    height = np.clip(0.55 + 0.22 * (mid - 0.5) + 0.12 * (fine - 0.5) - 0.3 * pit, 0.0, 1.0)
    tone = np.clip(0.5 + 0.4 * (big - 0.5) + 0.2 * (mid - 0.5), 0.0, 1.0)
    alb = tint(tone, (0.13, 0.085, 0.045), (0.46, 0.31, 0.15))
    green = smooth(big * 0.6 + 0.5 * pit + 0.4 * streak, 0.62, 0.95)                # verdigris in the pits and runs
    alb = alb * (1.0 - 0.85 * green[..., None]) + np.array([0.15, 0.34, 0.29])[None, None, :] * 0.85 * green[..., None]
    soot = smooth(fbm(n, 2.0, seed + 5), 0.55, 0.85)
    alb *= (1.0 - 0.55 * soot)[..., None]
    rough = np.clip(0.52 + 0.3 * green + 0.18 * (fine - 0.5), 0.3, 0.95)
    return alb, height, rough


def tex_scorch(n, seed):
    big = fbm(n, 2.8, seed)
    mid = fbm(n, 1.8, seed + 1)
    fine = fbm(n, 1.1, seed + 2)
    crack = smooth(np.abs(fbm(n, 2.2, seed + 3) - 0.5), 0.0, 0.045)                    # 0 on a crack line
    ash = smooth(fbm(n, 2.4, seed + 4), 0.58, 0.82)
    height = np.clip(0.5 + 0.3 * (big - 0.5) + 0.2 * (mid - 0.5) + 0.1 * (fine - 0.5), 0.0, 1.0) * (0.55 + 0.45 * crack)
    tone = np.clip(0.4 + 0.5 * (big - 0.5) + 0.25 * (mid - 0.5), 0.0, 1.0)
    alb = tint(tone, (0.035, 0.03, 0.03), (0.2, 0.15, 0.12))
    rust = smooth(mid * 0.7 + 0.4 * (fine - 0.5), 0.55, 0.85)
    alb = alb * (1.0 - 0.5 * rust[..., None]) + np.array([0.3, 0.14, 0.07])[None, None, :] * 0.5 * rust[..., None]
    alb = alb * (1.0 - 0.7 * ash[..., None]) + np.array([0.3, 0.29, 0.28])[None, None, :] * 0.7 * ash[..., None]
    alb *= (0.4 + 0.6 * crack)[..., None]
    rough = np.clip(0.86 + 0.12 * (fine - 0.5) - 0.2 * (1.0 - rust), 0.5, 1.0)
    return alb, height, rough


def tex_drystone(n, seed):
    """Dry-laid fieldstone: rounded stones of every size jammed together, dark gaps, lichen, moss at the foot."""
    rng = np.random.default_rng(seed)
    # voronoi-ish cells from jittered points
    k = 16
    pts = rng.uniform(0, n, (k * k, 2))
    gx = (np.arange(k * k) % k + 0.5) * n / k + rng.uniform(-0.38, 0.38, k * k) * n / k
    gy = (np.arange(k * k) // k + 0.5) * n / k + rng.uniform(-0.38, 0.38, k * k) * n / k
    ys, xs = np.mgrid[0:n, 0:n]
    best = np.full((n, n), 1e9)
    second = np.full((n, n), 1e9)
    bid = np.zeros((n, n), dtype=np.int32)
    for i in range(k * k):
        for ox in (-n, 0, n):
            for oy in (-n, 0, n):
                if abs(gx[i] + ox - n / 2) > n * 0.75 and abs(gy[i] + oy - n / 2) > n * 0.75:
                    continue
                d = (xs - (gx[i] + ox)) ** 2 + ((ys - (gy[i] + oy)) * 1.35) ** 2
                m = d < best
                second = np.where(m, best, np.minimum(second, d))
                bid = np.where(m, i, bid)
                best = np.where(m, d, best)
    edge = np.sqrt(second) - np.sqrt(best)
    face = smooth(edge, n * 0.004, n * 0.03)
    rr = rng.uniform(0, 1, k * k)[bid]
    big = fbm(n, 2.6, seed + 1)
    mid = fbm(n, 1.6, seed + 2)
    fine = fbm(n, 1.9, seed + 3)
    height = np.clip(face * (0.55 + 0.2 * rr + 0.15 * (mid - 0.5)) + 0.05 * (fine - 0.5), 0.0, 1.0)
    tone = np.clip(0.45 + 0.35 * (rr - 0.5) + 0.25 * (big - 0.5), 0.0, 1.0)
    alb = tint(tone, (0.17, 0.165, 0.155), (0.5, 0.48, 0.44))
    alb *= (0.32 + 0.68 * face)[..., None]
    lich = smooth(fbm(n, 2.2, seed + 4) * (0.7 + 0.3 * fine), 0.58, 0.8) * face
    alb = alb * (1.0 - 0.55 * lich[..., None]) + np.array([0.46, 0.5, 0.3])[None, None, :] * 0.55 * lich[..., None]
    rust = smooth(fbm(n, 2.4, seed + 5), 0.66, 0.85) * face
    alb = alb * (1.0 - 0.4 * rust[..., None]) + np.array([0.34, 0.22, 0.12])[None, None, :] * 0.4 * rust[..., None]
    rough = np.clip(0.88 + 0.1 * (fine - 0.5), 0.6, 1.0)
    return alb, height, rough


def bronze(name="E_Bronze", seed=7701):
    return L.pbr(name, tex_bronze(1024, seed), 1.4, metal=0.5)


def scorch(name="E_Scorch", seed=7702):
    m = L.pbr(name, tex_scorch(1024, seed), 2.4)
    m["uv_mul"] = 1.0
    return m


def drystone(name="E_Drystone", seed=7703):
    m = L.pbr(name, tex_drystone(1024, seed), 2.4)
    m["uv_mul"] = 1.0
    return m


def nave_stone(name="E_NaveStone", seed=7704):
    return L.ashlar(name, seed, rows=8, warm=0.02)


def emissive(name, color, strength):
    m = L.flat(name, (0.02, 0.03, 0.04), 0.5)
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Emission Color"].default_value = (*color, 1.0)
    b.inputs["Emission Strength"].default_value = strength
    return m


def smoothstep(a, b, x):
    t = min(max((x - a) / (b - a), 0.0), 1.0)
    return t * t * (3.0 - 2.0 * t)
