"""Architecture texture sets: real masonry scale, procedural, tileable.
Run with the numpy that ships in Blender (no PIL needed):
    tools/blender/run.sh arch_textures.py -- brick plaster ashlar ruin floor wood beam
Scale (metres per tile = 1 / uv1_scale in the materials):
  oss_brick   2.0 m   brick 0.25 x 0.083 m course, 11 mm mortar
  oss_plaster 2.0 m   lime plaster over that brick, patches lost
  oss_ashlar  3.125 m courses 0.44-0.59 m, blocks 0.5-1.1 m, 12 mm joints
  oss_floor   4.5 m   flags 0.55-0.95 m
  oss_ruin    2.5 m   hewn, weathered ruin stone, dry joints, big chips
  tavern_wood / tavern_beam   weathered timber with checking and silvering
Colours keep the existing night values (these only add scale, chips, grime, mortar).
"""
import os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_textures as G
from gen_textures import fbm, voronoi, smooth, _maps

S = 1024
Y, X = np.mgrid[0:S, 0:S].astype(np.float32)


def courses(tile, heights, lens, seed, stagger=True):
    """Coursed masonry on a tile of `tile` metres. heights: course heights (fractions, any sum).
    lens: (min, max) block length in metres. Returns joint distance (m) and a block id."""
    r = np.random.default_rng(seed)
    hs = np.array(heights, np.float64)
    hs = hs / hs.sum()
    edges = np.concatenate([[0.0], np.cumsum(hs)])
    row = np.clip(np.searchsorted(edges, Y / S, side='right') - 1, 0, len(hs) - 1)
    jd = np.zeros((S, S), np.float32)
    cid = np.zeros((S, S), np.float32)
    for k in range(len(hs)):
        m = row == k
        n_tot, ls = 0.0, []
        while n_tot < tile - 1e-6:
            ls.append(r.uniform(*lens))
            n_tot += ls[-1]
        ls = np.array(ls) * (tile / n_tot)
        cuts = np.concatenate([[0.0], np.cumsum(ls) / tile])
        cuts[-1] = 1.0
        off = r.random() if stagger else 0.0
        if lens[0] == lens[1]:
            off = (k % 2) * 0.5 * lens[0] / tile      # running bond
        uu = (X[m] / S + off) % 1.0
        idx = np.clip(np.searchsorted(cuts, uu, side='right') - 1, 0, len(ls) - 1)
        du = np.minimum(uu - cuts[idx], cuts[idx + 1] - uu) * tile
        top = edges[k] * S
        bot = edges[k + 1] * S
        dv = np.minimum(Y[m] - top, bot - Y[m]) / S * tile
        jd[m] = np.minimum(du, dv)
        cid[m] = (np.sin((k * 17.3 + idx * 7.7 + seed) * 12.9898) * 43758.5453) % 1.0
    return jd, cid


def masonry(tile, heights, lens, seed, rgb, lum0, mortar_rgb, mortar_lum, jit, hue,
            mortar_w, bevel, chip, grime, soot, algae, stagger=True):
    jd, cid = courses(tile, heights, lens, seed, stagger)

    def f(cells, o=4):
        return fbm(S, max(2, int(round(cells))), o)

    wob = (f(tile * 16, 3) - 0.5) * mortar_w * 1.4       # joints wander: hand-laid, not CNC
    j = jd + wob
    mortar = 1 - smooth(mortar_w * 0.55, mortar_w * 1.1, j)
    edge = smooth(mortar_w, mortar_w + bevel, j)          # rounded arris, small and uneven
    ebreak = f(tile * 9, 3)
    chips = smooth(0.62, 0.78, f(tile * 11, 4)) * (1 - smooth(mortar_w, mortar_w + bevel * 2.6, j)) * chip
    grain = f(tile * 3, 6)
    fine = f(tile * 26, 4)
    pits = smooth(0.8, 0.93, f(tile * 20, 3))
    streak = smooth(0.45, 0.9, fbm(S, max(3, int(tile * 8)), 4, ny=max(2, int(tile))))
    h = edge * 0.45 + grain * 0.2 + fine * 0.07 - mortar * 0.38 - chips * 0.3 - pits * 0.08 + (ebreak - 0.5) * 0.12 * (1 - edge)
    lum = lum0 + (cid - 0.5) * jit + (grain - 0.5) * 0.2 + (fine - 0.5) * 0.06 - pits * 0.05
    tintv = np.array(rgb)[None, None, :] * (1 + (cid[..., None] - 0.5) * np.array(hue)[None, None, :])
    col = lum[..., None] * tintv
    # grime pools in joints and arrises, soot runs down, algae in cool damp patches
    gr = (1 - edge) * grime + smooth(0.5, 0.85, f(tile * 2.5, 5)) * grime * 0.7
    col = col * (1 - gr[..., None])
    col = col * (1 - streak[..., None] * soot)
    al = smooth(0.58, 0.82, f(tile * 3.2, 5)) * algae
    col = col * (1 - al[..., None] * 0.35) + al[..., None] * np.array([0.05, 0.075, 0.04]) * 0.9
    col = col * (1 - chips[..., None] * 0.18)
    mcol = (mortar_lum + (fine[..., None] - 0.5) * 0.08) * np.array(mortar_rgb)[None, None, :]
    col = col * (1 - mortar[..., None]) + mcol * mortar[..., None]
    ao = 1 - mortar * 0.55 - (1 - edge) * 0.2 - pits * 0.2 - chips * 0.15
    return col, h, ao, mortar, fine, pits


def brick():
    col, h, ao, mortar, fine, pits = masonry(
        2.0, [1] * 24, (0.25, 0.25), 5, (0.78, 0.5, 0.42), 0.32, (0.7, 0.67, 0.62), 0.46,
        0.2, (0.18, 0.35, 0.3), 0.011, 0.012, 0.8, 0.22, 0.25, 0.6)
    _maps('oss_brick', col, h, ao, 0.84 + mortar * 0.12 - fine * 0.05 + pits * 0.05, 11.0)


def plaster():
    bcol, bh, bao, bm, bf, bp = masonry(
        2.0, [1] * 24, (0.25, 0.25), 9, (0.74, 0.5, 0.4), 0.30, (0.7, 0.67, 0.62), 0.42,
        0.2, (0.2, 0.4, 0.35), 0.011, 0.012, 0.9, 0.3, 0.2, 0.4)
    grain = fbm(S, 8, 6)
    fine = fbm(S, 60, 4)
    lossn = fbm(S, 5, 5) * 0.8 + fbm(S, 14, 3) * 0.2
    fallen = smooth(0.57, 0.585, lossn)                  # ragged, hard-edged loss
    lip = smooth(0.53, 0.57, lossn) * (1 - fallen)       # thickened chipped lip round each loss
    f1, f2, _ = voronoi(S, 7, 0.9)
    crack = (1 - smooth(0.0, 0.008, f2 - f1)) * smooth(0.62, 0.75, fbm(S, 6, 4)) * 0.7
    stain = smooth(0.5, 0.85, fbm(S, 4, 5))
    damp = smooth(0.6, 0.8, fbm(S, 3, 4))
    hp = 0.62 + grain * 0.3 + fbm(S, 3, 4, ny=14) * 0.08 + fine * 0.07 - crack * 0.35 + lip * 0.1
    h = hp * (1 - fallen) + (bh * 0.8) * fallen
    pc = (0.6 + (grain - 0.5) * 0.24 + (fine - 0.5) * 0.06 - crack * 0.25 - stain * 0.08 - damp * 0.06 - lip * 0.05)[..., None] * np.array([0.93, 0.9, 0.82])
    col = pc * (1 - fallen[..., None]) + bcol * fallen[..., None]
    ao = (1 - crack * 0.4 - lip * 0.1) * (1 - fallen) + bao * fallen
    rough = 0.9 * (1 - fallen) + (0.85 + bm * 0.12 - bf * 0.05) * fallen
    _maps('oss_plaster', col, h, ao, rough, 11.0)


def ashlar():
    col, h, ao, mortar, fine, pits = masonry(
        3.125, [0.17, 0.14, 0.19, 0.15, 0.16, 0.19], (0.5, 1.1), 11, (0.92, 0.88, 0.8), 0.42,
        (0.7, 0.67, 0.62), 0.5, 0.24, (0.06, 0.1, 0.12), 0.012, 0.03, 1.3, 0.28, 0.3, 0.6)
    _maps('oss_ashlar', col, h, ao, 0.78 + mortar * 0.12 - fine * 0.06, 13.0)


def ruin():
    col, h, ao, mortar, fine, pits = masonry(
        2.5, [0.22, 0.17, 0.25, 0.2, 0.16], (0.35, 0.9), 31, (0.86, 0.85, 0.82), 0.33,
        (0.1, 0.1, 0.1), 0.1, 0.16, (0.04, 0.07, 0.08), 0.016, 0.035, 1.5, 0.28, 0.35, 0.9)
    _maps('oss_ruin', col, h, ao, 0.88 + mortar * 0.08 - fine * 0.06 + pits * 0.06, 14.0)


def hewn():
    """Monolithic weathered limestone (headstones, waystones, steles): strata, pits, hairline cracks,
    chipped lichen crusts. No joints, so it never reads as a wall on a 30 cm stone."""
    grain = fbm(S, 6, 6)
    fine = fbm(S, 64, 4)
    strata = fbm(S, 3, 4, ny=18)
    f1, f2, _ = voronoi(S, 6, 0.9)
    crack = (1 - smooth(0.0, 0.006, f2 - f1)) * smooth(0.55, 0.7, fbm(S, 5, 4))
    pits = smooth(0.74, 0.9, fbm(S, 40, 3))
    chips = smooth(0.7, 0.82, fbm(S, 16, 4))
    lichen = smooth(0.66, 0.8, fbm(S, 12, 4))
    soot = smooth(0.45, 0.9, fbm(S, 10, 4, ny=2))
    h = grain * 0.4 + strata * 0.15 + fine * 0.1 - crack * 0.3 - pits * 0.14 - chips * 0.25
    lum = 0.36 + (grain - 0.5) * 0.18 + (strata - 0.5) * 0.12 + (fine - 0.5) * 0.06 - pits * 0.08 - chips * 0.06 - soot * 0.06
    col = lum[..., None] * np.array([0.9, 0.87, 0.82])
    col = col * (1 - lichen[..., None] * 0.3) + lichen[..., None] * np.array([0.14, 0.17, 0.11]) * 0.8
    col = col * (1 - crack[..., None] * 0.5)
    _maps('oss_hewn', col, h, 1 - pits * 0.3 - crack * 0.4 - chips * 0.1, 0.84 + pits * 0.08 + lichen * 0.08 - fine * 0.05, 14.0)


def floor():
    col, h, ao, mortar, fine, pits = masonry(
        4.5, [0.13, 0.15, 0.14, 0.16, 0.13, 0.15, 0.14], (0.55, 0.95), 23, (0.86, 0.84, 0.8), 0.36,
        (0.2, 0.19, 0.18), 0.2, 0.14, (0.04, 0.06, 0.08), 0.016, 0.02, 0.6, 0.2, 0.1, 0.3)
    wear = smooth(0.4, 0.75, fbm(S, 5, 4))                # foot-polished lanes
    _maps('oss_floor', col, h, ao, 0.82 - wear * 0.22 + mortar * 0.12 + fine * 0.05, 12.0)


def timber(name, board_n, base, lum0, rough0, nstr, silver, gaps=True):
    """Weathered timber: long vertical grain, checking along it, silvered face, stains."""
    u = X / S * board_n
    bid = np.floor(u)
    local = u - bid
    if gaps:
        gap = 1.0 - smooth(0.0, 0.03, np.minimum(local, 1 - local))
    else:
        gap = np.zeros((S, S), np.float32)
    bsh = ((np.sin((bid * 12.9898 + 3.1) * 43758.5453) % 1.0)).astype(np.float32)
    wob = fbm(S, 3, 3, ny=6) * 0.6
    grain = fbm(S, max(3, board_n * 3), 6, ny=70)
    rings = 0.5 + 0.5 * np.sin((local * 9 + grain * 4 + wob + bsh * 6) * np.pi)
    fine = fbm(S, 24, 4, ny=140)
    checks = (1 - smooth(0.0, 0.18, np.abs(fbm(S, max(6, board_n * 5), 3, ny=24) - 0.55))) * smooth(0.5, 0.7, fbm(S, 5, 3, ny=2))
    knots = smooth(0.8, 0.93, fbm(S, 5, 4))
    stain = smooth(0.62, 0.88, fbm(S, 5, 4))
    h = grain * 0.4 + rings * 0.12 + fine * 0.08 - gap * 0.5 - checks * 0.35 - knots * 0.15
    lum = lum0 + (bsh - 0.5) * 0.08 + (grain - 0.5) * 0.22 + (rings - 0.5) * 0.06 - checks * 0.12 - gap * 0.14 - knots * 0.08
    col = lum[..., None] * np.array(base)[None, None, :]
    sv = smooth(0.4, 0.8, fbm(S, 4, 4)) * silver
    grey = lum[..., None] * np.array([0.78, 0.76, 0.72]) * 1.15
    col = col * (1 - sv[..., None]) + grey * sv[..., None]
    col = col * (1 - stain[..., None] * 0.25)
    ao = 1 - gap * 0.55 - checks * 0.4 - knots * 0.2
    rough = rough0 + gap * 0.1 + fine * 0.08 - stain * 0.1
    _maps(name, col, h, ao, rough, nstr)


def tavern_wood():
    timber('tavern_wood', 9, (0.62, 0.32, 0.18), 0.22, 0.74, 11.0, 0.45)


def tavern_beam():
    timber('tavern_beam', 2, (0.85, 0.55, 0.38), 0.085, 0.88, 12.0, 0.3, gaps=False)


SETS = {'brick': brick, 'plaster': plaster, 'ashlar': ashlar, 'ruin': ruin, 'hewn': hewn, 'floor': floor,
        'wood': tavern_wood, 'beam': tavern_beam}

if __name__ == '__main__':
    os.makedirs(G.OUT, exist_ok=True)
    want = [a for a in sys.argv[1:] if a in SETS] or list(SETS)
    for k in want:
        SETS[k]()
