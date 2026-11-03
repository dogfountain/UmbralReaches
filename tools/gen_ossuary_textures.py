"""Ossuary Terrace texture sets (procedural, tileable, CC0 by construction).
Usage: python3 tools/gen_ossuary_textures.py   -> art/textures/oss_*_{albedo,normal,ao,rough}.png
Builds on the noise kit in gen_textures.py. Palette: cool limestone and old ivory, so the
candlelight (warm) and the night (violet) both read against it, instead of the tavern reds."""
import os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(__file__))
import gen_textures as G
from gen_textures import fbm, voronoi, smooth, _maps

S = 1024
Y, X = np.mgrid[0:S, 0:S].astype(np.float32)


def _blocks(rows, base_cols, jitter, seed):
    """Coursed masonry: per-row random block lengths, tileable. Returns local u,v in block,
    block id, and distance to the nearest joint (in block-height units)."""
    r = np.random.default_rng(seed)
    row = np.floor(Y / S * rows).astype(int)
    v = Y / S * rows - row
    u_abs = X / S
    cid = np.zeros((S, S), np.float32)
    du = np.zeros((S, S), np.float32)
    for k in range(rows):
        n = base_cols + int(r.integers(-1, 2))
        cuts = np.sort(r.random(n - 1) * (1 - jitter) + np.linspace(0, 1, n + 1)[1:-1] * jitter + (r.random() * 0.5 / n))
        cuts = np.concatenate([[0.0], np.clip(cuts, 0.02, 0.98), [1.0]])
        off = r.random()
        m = row == k
        uu = (u_abs[m] + off) % 1.0
        idx = np.searchsorted(cuts, uu, side='right') - 1
        lo, hi = cuts[idx], cuts[idx + 1]
        du[m] = np.minimum(uu - lo, hi - uu) * rows      # in row-height units
        cid[m] = (k * 31 + idx * 7 + r.random()) % 1.0
    dv = np.minimum(v, 1 - v)
    return np.minimum(du, dv), cid, v


def ashlar():
    joint, cid, v = _blocks(9, 5, 0.6, 11)
    mortar = 1 - smooth(0.0, 0.05, joint)
    bevel = smooth(0.02, 0.16, joint)
    grain = fbm(S, 10, 6)
    fine = fbm(S, 70, 4)
    chips = smooth(0.62, 0.8, fbm(S, 26, 4)) * (1 - smooth(0.05, 0.2, joint))
    pits = smooth(0.8, 0.94, fbm(S, 56, 3))
    streak = smooth(0.45, 0.9, fbm(S, 24, 4, ny=3)) * 0.5        # vertical soot runs
    h = bevel * 0.55 + grain * 0.22 + fine * 0.08 - mortar * 0.5 - chips * 0.25 - pits * 0.1
    lum = 0.42 + (cid - 0.5) * 0.12 + grain * 0.14 + fine * 0.05 - mortar * 0.18 - chips * 0.06 - streak * 0.12
    col = lum[..., None] * np.array([0.92, 0.88, 0.8])
    col = col * (1 - streak[..., None] * 0.25)
    ao = 1 - mortar * 0.6 - (1 - bevel) * 0.18 - pits * 0.2
    rough = 0.78 + mortar * 0.15 - fine * 0.06
    _maps('oss_ashlar', col, h, ao, rough, 13.0)


def plaster():
    grain = fbm(S, 9, 6)
    f1, f2, _ = voronoi(S, 7, 0.9)
    crack = (1 - smooth(0.0, 0.012, f2 - f1)) * smooth(0.45, 0.6, fbm(S, 6, 4))
    fallen = smooth(0.73, 0.76, fbm(S, 9, 5))                      # plaster gone, brick shows (small, rare)
    joint, bid, _ = _blocks(22, 9, 0.85, 5)
    brick_m = 1 - smooth(0.0, 0.08, joint)
    stain = smooth(0.5, 0.85, fbm(S, 4, 5))
    h_pl = 0.6 + grain * 0.25 - crack * 0.4
    h_br = 0.25 + (1 - brick_m) * 0.15 - brick_m * 0.15 + grain * 0.1
    h = h_pl * (1 - fallen) + h_br * fallen
    pl = (0.6 + grain * 0.1 - crack * 0.3 - stain * 0.07)[..., None] * np.array([0.93, 0.9, 0.82])
    br = (0.3 + (bid - 0.5) * 0.12 + grain * 0.08 - brick_m * 0.12)[..., None] * np.array([0.72, 0.5, 0.4])
    edge = smooth(0.71, 0.73, fbm(S, 9, 5)) * (1 - fallen)            # chipped lip round each loss
    col = pl * (1 - fallen[..., None]) + br * fallen[..., None] - edge[..., None] * 0.08
    ao = 1 - crack * 0.4 - fallen * 0.25 - brick_m * fallen * 0.3
    rough = 0.9 - fallen * 0.05
    _maps('oss_plaster', col, h, ao, rough, 10.0)


def floor():
    joint, cid, _ = _blocks(5, 3, 0.5, 23)
    seam = 1 - smooth(0.0, 0.035, joint)
    bevel = smooth(0.0, 0.07, joint)
    wear = smooth(0.4, 0.75, fbm(S, 5, 4))                          # foot-polished lanes
    grain = fbm(S, 8, 6)
    fine = fbm(S, 64, 4)
    f1, f2, _ = voronoi(S, 9, 0.9)
    crack = (1 - smooth(0.0, 0.01, f2 - f1)) * smooth(0.55, 0.7, fbm(S, 5, 4))
    grime = smooth(0.55, 0.85, fbm(S, 6, 4)) * 0.5 + (1 - bevel) * 0.3
    h = 0.5 + bevel * 0.2 + grain * 0.18 + fine * 0.06 - seam * 0.6 - crack * 0.25
    lum = 0.36 + (cid - 0.5) * 0.14 + grain * 0.12 - grime * 0.12 - seam * 0.16 - crack * 0.1
    col = lum[..., None] * np.array([0.86, 0.84, 0.8])
    ao = 1 - seam * 0.6 - crack * 0.3 - grime * 0.1
    rough = 0.82 - wear * 0.22 + seam * 0.12 + fine * 0.05            # polished by feet
    _maps('oss_floor', col, h, ao, rough, 12.0)


def bone():
    grain = fbm(S, 10, 6)
    pores = smooth(0.7, 0.9, fbm(S, 90, 3))
    fibre = 0.5 + 0.5 * np.sin((Y / S + fbm(S, 6, 4) * 0.15) * np.pi * 60)
    f1, f2, _ = voronoi(S, 12, 0.9)
    crack = (1 - smooth(0.0, 0.008, f2 - f1)) * smooth(0.5, 0.7, fbm(S, 7, 4))
    stain = smooth(0.5, 0.9, fbm(S, 9, 5)) * 0.5
    h = 0.5 + grain * 0.2 + fibre * 0.05 - pores * 0.25 - crack * 0.35
    lum = 0.78 + grain * 0.06 + fibre * 0.03 - pores * 0.1 - crack * 0.25 - stain * 0.15
    col = lum[..., None] * np.array([0.95, 0.88, 0.74])
    col = col * (1 - stain[..., None] * np.array([0.0, 0.12, 0.3]))
    ao = 1 - pores * 0.3 - crack * 0.4
    rough = 0.62 + pores * 0.2 - stain * 0.05
    _maps('oss_bone', col, h, ao, rough, 7.0)


def slate():
    rows = 16
    row = np.floor(Y / S * rows)
    v = Y / S * rows - row
    cols = 12
    u = X / S * cols + (row % 2) * 0.5
    cu = np.floor(u)
    lu = u - cu
    # fish-scale: each shingle's lower edge is a semicircle
    d = np.hypot((lu - 0.5) * 1.6, np.clip(v - 0.35, 0, None) * 1.6)
    inside = 1 - smooth(0.78, 0.82, d)
    shade = smooth(0.0, 0.9, v)
    rid = (np.sin(cu * 12.9898 + row * 78.233) * 43758.5453) % 1.0
    grain = fbm(S, 14, 5)
    moss = smooth(0.62, 0.85, fbm(S, 8, 4)) * (1 - inside * 0.5)
    h = inside * (0.4 + shade * 0.4) + grain * 0.15
    lum = 0.14 + inside * 0.06 + (rid - 0.5) * 0.05 + grain * 0.06 - (1 - inside) * 0.06
    col = lum[..., None] * np.array([0.72, 0.74, 0.85])
    col = col * (1 - moss[..., None] * 0.4) + moss[..., None] * np.array([0.06, 0.08, 0.05])
    ao = 1 - (1 - inside) * 0.55 - (1 - shade) * 0.15
    rough = 0.5 + (1 - inside) * 0.3 + moss * 0.3
    _maps('oss_slate', col, h, ao, rough, 11.0)


def statue():
    """Weathered carved limestone: smooth worked surface, dark rain streaks, lichen in hollows."""
    grain = fbm(S, 7, 6)
    fine = fbm(S, 48, 4)
    pits = smooth(0.8, 0.95, fbm(S, 80, 3))
    streak = smooth(0.5, 0.92, fbm(S, 30, 4, ny=2)) * 0.6
    lichen = smooth(0.66, 0.84, fbm(S, 9, 5))
    h = 0.5 + grain * 0.15 + fine * 0.05 - pits * 0.2
    lum = 0.5 + grain * 0.1 + fine * 0.04 - pits * 0.1 - streak * 0.16
    col = lum[..., None] * np.array([0.86, 0.86, 0.84])
    col = col * (1 - lichen[..., None] * 0.35) + lichen[..., None] * np.array([0.16, 0.2, 0.13])
    ao = 1 - pits * 0.3 - lichen * 0.1
    rough = 0.72 + pits * 0.15 + lichen * 0.1 - fine * 0.05
    _maps('oss_statue', col, h, ao, rough, 6.0)


if __name__ == '__main__':
    os.makedirs(G.OUT, exist_ok=True)
    ashlar(); plaster(); floor(); bone(); slate(); statue()
