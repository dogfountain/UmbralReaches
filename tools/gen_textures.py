"""Generate tileable, painted-style textures for Umbral Reaches (v0.1).
Usage: python3 tools/gen_textures.py  (writes art/textures/*.png)
       python3 tools/gen_textures.py robe  (1k wanderer cloth only)
Every texture tiles seamlessly: noise lattices and Voronoi cells wrap at the edges."""
import numpy as np, os, sys
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), '..', 'art', 'textures')
rng = np.random.default_rng(1337)

def vnoise(size, nx, ny=None):
    ny = ny or nx
    g = rng.random((ny, nx))
    y, x = np.mgrid[0:size, 0:size].astype(np.float32)
    u, v = x / size * nx, y / size * ny
    i, j = np.floor(u).astype(int), np.floor(v).astype(int)
    fu, fv = u - i, v - j
    fu, fv = fu * fu * (3 - 2 * fu), fv * fv * (3 - 2 * fv)
    a = g[j % ny, i % nx]; b = g[j % ny, (i + 1) % nx]
    c = g[(j + 1) % ny, i % nx]; d = g[(j + 1) % ny, (i + 1) % nx]
    return (a * (1 - fu) + b * fu) * (1 - fv) + (c * (1 - fu) + d * fu) * fv

def fbm(size, nx, octaves=5, ny=None, gain=0.5):
    ny = ny or nx
    v, a, tot = np.zeros((size, size), np.float32), 1.0, 0.0
    for o in range(octaves):
        v += a * vnoise(size, nx * 2 ** o, ny * 2 ** o); tot += a; a *= gain
    return v / tot

def voronoi(size, cells, jitter=0.85):
    pts = rng.random((cells, cells, 2)) * jitter + (1 - jitter) / 2
    ids = rng.random((cells, cells))
    y, x = np.mgrid[0:size, 0:size].astype(np.float32)
    u, v = x / size * cells, y / size * cells
    ci, cj = np.floor(u).astype(int), np.floor(v).astype(int)
    f1 = np.full((size, size), 9.0, np.float32); f2 = f1.copy(); cid = np.zeros((size, size), np.float32)
    for dj in (-1, 0, 1):
        for di in (-1, 0, 1):
            nj, ni = cj + dj, ci + di
            p = pts[nj % cells, ni % cells]
            d = np.hypot(ni + p[..., 0] - u, nj + p[..., 1] - v)
            closer = d < f1
            f2 = np.where(closer, f1, np.minimum(f2, d))
            cid = np.where(closer, ids[nj % cells, ni % cells], cid)
            f1 = np.where(closer, d, f1)
    return f1, f2, cid

def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1); return t * t * (3 - 2 * t)

def normal_map(h, strength):
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5 * strength
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5 * strength
    n = np.dstack([-dx, dy, np.ones_like(h)])   # OpenGL convention (Y+), as Godot expects
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return n * 0.5 + 0.5

def save(name, arr):
    Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8)).save(os.path.join(OUT, name))
    print('wrote', name, arr.shape)

def _maps(prefix, albedo, h, ao, rough, n_str):
    save(prefix + '_albedo.png', albedo)
    save(prefix + '_normal.png', normal_map(h, n_str))
    save(prefix + '_ao.png', np.clip(ao, 0, 1))
    save(prefix + '_rough.png', np.clip(rough, 0, 1))

def stone(size=1024):
    # Crunchy wet cobble: crushed mortar, cyan bevel rims, high-frequency grit.
    f1, f2, cid = voronoi(size, 10, 0.68)
    edge = f2 - f1
    crack = 1 - smooth(0.0, 0.038, edge)
    bevel = smooth(0.0, 0.18, edge)
    grain = fbm(size, 12, 7)
    fine = fbm(size, 64, 5)
    micro = fbm(size, 110, 3)
    chips = smooth(0.58, 0.76, fbm(size, 30, 4))
    lichen = smooth(0.72, 0.90, fbm(size, 7, 4)) * (1 - crack) * 0.28
    pits = smooth(0.76, 0.93, fbm(size, 48, 3))
    wet = smooth(0.70, 0.92, fbm(size, 18, 4))
    # Moss is a TEXTURE: thick in cracks/mortar, patches on damp faces — not props.
    moss = np.clip(crack * 1.05 + smooth(0.48, 0.78, fbm(size, 6, 5)) * (0.55 + crack * 0.6), 0, 1)
    moss = np.clip(moss * (0.55 + fine * 0.9), 0, 1)
    h = bevel * 0.58 + grain * 0.22 + fine * 0.14 + micro * 0.08 - chips * 0.18 - crack * 0.62 - pits * 0.12 - moss * 0.06
    base = 0.28 + (cid - 0.5) * 0.10 + (grain - 0.5) * 0.18 + (fine - 0.5) * 0.08
    ao = 1 - crack * 0.94 - (1 - smooth(0.0, 0.10, edge)) * 0.28 - chips * 0.24 - pits * 0.22
    # Thin cyan rim on brick faces — reads under blue moon without emission.
    hi = smooth(0.04, 0.085, edge) * (1 - smooth(0.085, 0.14, edge))
    lum = np.clip(base * ao + hi * 0.16 + wet * 0.07 + micro * 0.03, 0, 1)
    tint = np.array([0.72, 0.82, 1.18])
    col = lum[..., None] * tint
    col = col + hi[..., None] * np.array([0.10, 0.22, 0.38])
    moss_col = np.dstack([0.05 + fine * 0.05, 0.28 + grain * 0.18 + fine * 0.12, 0.12 + grain * 0.07])
    moss_col = moss_col + (moss * smooth(0.45, 0.9, fine))[..., None] * np.array([0.10, 0.36, 0.16])
    col = col * (1 - moss[..., None] * 0.92) + moss_col * moss[..., None] * 0.92
    col = col * (1 - lichen[..., None]) + lichen[..., None] * np.array([0.10, 0.28, 0.26])
    # Crush shadows into near-black so grade can push remaining midtones electric.
    col = col * (0.55 + 0.45 * ao[..., None])
    rough = 0.38 + crack * 0.48 + chips * 0.14 - wet * 0.32 + fine * 0.10 - hi * 0.12 + moss * 0.18
    _maps('stone', col, h, ao, rough, 20.0)

def cobble_ring(size=1024):
    # Cathedral cobbles: cool wet stone faces, moss packed into mortar joints.
    f1, f2, cid = voronoi(size, 9, 0.72)
    edge = f2 - f1
    mortar = 1 - smooth(0.0, 0.055, edge)
    bevel = smooth(0.0, 0.22, edge)
    grain = fbm(size, 14, 6)
    fine = fbm(size, 70, 5)
    micro = fbm(size, 120, 3)
    wet = smooth(0.68, 0.92, fbm(size, 16, 4))
    chips = smooth(0.60, 0.80, fbm(size, 28, 4))
    moss = np.clip(mortar * 1.1 + smooth(0.45, 0.75, fbm(size, 5, 5)) * (0.35 + mortar * 0.7), 0, 1)
    moss = np.clip(moss * (0.5 + fine * 0.95), 0, 1)
    h = bevel * 0.62 + grain * 0.2 + fine * 0.12 + micro * 0.08 - mortar * 0.7 - chips * 0.16 - moss * 0.08
    ao = 1 - mortar * 0.9 - chips * 0.2 - (1 - smooth(0.0, 0.12, edge)) * 0.22
    base = 0.26 + (cid - 0.5) * 0.12 + (grain - 0.5) * 0.16 + (fine - 0.5) * 0.07
    lum = np.clip(base * ao + wet * 0.08 + micro * 0.03, 0, 1)
    col = lum[..., None] * np.array([0.70, 0.80, 1.12])
    moss_col = np.dstack([0.04 + fine * 0.05, 0.26 + grain * 0.2 + fine * 0.14, 0.10 + grain * 0.06])
    moss_col = moss_col + (moss * smooth(0.4, 0.85, fine))[..., None] * np.array([0.08, 0.32, 0.12])
    col = col * (1 - moss[..., None] * 0.95) + moss_col * moss[..., None] * 0.95
    col = col * (0.55 + 0.45 * ao[..., None])
    rough = 0.42 + mortar * 0.4 + chips * 0.12 - wet * 0.28 + fine * 0.08 + moss * 0.2
    # Summit platform expects cobble_ring.png / cobble_ring_n.png (not *_albedo).
    save('cobble_ring.png', col)
    save('cobble_ring_n.png', normal_map(h, 18.0))
    save('cobble_ring_ao.png', np.clip(ao, 0, 1))
    save('cobble_ring_rough.png', np.clip(rough, 0, 1))

def ground(size=1024):
    # Dark wet earth + saturated cyan-emerald moss + glittery grit.
    moss = smooth(0.42, 0.62, fbm(size, 5, 6))
    dirt = fbm(size, 20, 6)
    grit = fbm(size, 72, 4)
    f1, f2, _ = voronoi(size, 64, 0.88)
    pebble = smooth(0.15, 0.05, f1) * smooth(0.46, 0.72, fbm(size, 10, 3))
    roots = smooth(0.78, 0.92, fbm(size, 36, 3, ny=8)) * (1 - pebble) * 0.40
    wet = smooth(0.74, 0.94, fbm(size, 12, 4))
    c_dirt = np.array([0.18, 0.20, 0.28]) * (0.55 + dirt[..., None] * 0.70 + grit[..., None] * 0.18)
    c_moss = np.array([0.08, 0.38, 0.30]) * (0.55 + fbm(size, 40, 4)[..., None] * 0.90)
    moss_hi = smooth(0.62, 0.88, grit) * moss
    litter = smooth(0.56, 0.80, fbm(size, 32, 5))
    col = c_dirt * (1 - moss[..., None]) + c_moss * moss[..., None]
    col = col + moss_hi[..., None] * np.array([0.06, 0.22, 0.28])
    col = col * (1 - pebble[..., None] * 0.50) + pebble[..., None] * np.array([0.32, 0.38, 0.52])
    col = col * (1 - litter[..., None] * 0.28) + litter[..., None] * np.array([0.06, 0.16, 0.14])
    col = col * (1 - roots[..., None] * 0.40) + roots[..., None] * np.array([0.10, 0.08, 0.06])
    # Specular wet sheen baked as brighter cool flecks.
    col = col + wet[..., None] * (1 - moss[..., None]) * np.array([0.08, 0.12, 0.20])
    h = dirt * 0.36 + pebble * 0.88 + moss * 0.18 + litter * 0.14 + roots * 0.22 + grit * 0.16
    ao = 1 - pebble * 0.22 - litter * 0.24 - (1 - dirt) * 0.16
    col = col * (0.60 + 0.40 * ao[..., None])
    rough = 0.78 - moss * 0.22 - wet * 0.38 + pebble * 0.12 + grit * 0.08
    _maps('ground', col, h, ao, rough, 16.0)

def rock(size=1024):
    # Vertical cliff strata: black fissures, blue ridge catch-lights, moss in cracks.
    strata = fbm(size, 2, 7, ny=32)
    warp = fbm(size, 8, 5)
    fine = fbm(size, 56, 5)
    micro = fbm(size, 120, 3)
    f1, f2, _ = voronoi(size, 7, 0.86)
    crack = 1 - smooth(0.0, 0.035, f2 - f1)
    quartz = smooth(0.84, 0.95, fbm(size, 18, 3)) * (1 - crack) * 0.45
    ridge = smooth(0.55, 0.78, strata) * (1 - crack)
    moss = np.clip(crack * 0.95 + smooth(0.5, 0.8, fbm(size, 6, 5)) * (0.4 + crack * 0.55), 0, 1)
    moss = np.clip(moss * (0.55 + fine * 0.85) * (1 - ridge * 0.35), 0, 1)
    h = strata * 0.55 + warp * 0.22 + fine * 0.14 + micro * 0.10 - crack * 0.58 - moss * 0.05
    lum = (0.18 + (strata - 0.5) * 0.48 + (warp - 0.5) * 0.14 + (fine - 0.5) * 0.08) * (1 - crack * 0.88)
    col = lum[..., None] * np.array([0.78, 0.86, 1.16])
    col = col + ridge[..., None] * np.array([0.08, 0.16, 0.32])
    col = col * (1 - quartz[..., None]) + quartz[..., None] * np.array([0.62, 0.78, 1.05])
    moss_col = np.dstack([0.04 + fine * 0.04, 0.22 + strata * 0.18 + fine * 0.12, 0.12 + warp * 0.06])
    col = col * (1 - moss[..., None] * 0.9) + moss_col * moss[..., None] * 0.9
    ao = 1 - crack * 0.82 - (1 - strata) * 0.16
    col = col * (0.50 + 0.50 * ao[..., None])
    rough = 0.72 + crack * 0.22 - quartz * 0.42 - ridge * 0.15 + fine * 0.08 + moss * 0.16
    _maps('rock', col, h, ao, rough, 18.0)

def bark(size=1024):
    # High-contrast trunk: black clefts, cold blue ridges, cyan-moss pockets.
    fib = fbm(size, 30, 6, ny=2)
    fine = fbm(size, 80, 4, ny=6)
    micro = fbm(size, 140, 3, ny=10)
    knots = smooth(0.68, 0.86, fbm(size, 5, 4))
    moss = smooth(0.70, 0.90, fbm(size, 8, 3)) * (1 - knots) * 0.48
    y = np.mgrid[0:size, 0:size][0].astype(np.float32)
    splits = 1 - smooth(0.0, 0.07, np.abs(np.sin((y / size) * np.pi * 20 + fib * 4.5)))
    h = fib * 0.55 + fine * 0.22 + micro * 0.10 - knots * 0.36 - splits * 0.24
    lum = (0.08 + fib * 0.32 + fine * 0.10) * (1 - knots * 0.55) * (1 - splits * 0.35)
    col = lum[..., None] * np.array([0.72, 0.80, 1.10])
    # Ridge catch-light reads as blue moon on bark.
    ridge = smooth(0.55, 0.85, fib) * (1 - splits) * (1 - knots)
    col = col + ridge[..., None] * np.array([0.06, 0.14, 0.28])
    col = col * (1 - moss[..., None]) + moss[..., None] * np.array([0.05, 0.28, 0.24])
    ao = 1 - knots * 0.42 - splits * 0.38
    col = col * (0.48 + 0.52 * ao[..., None])
    rough = 0.82 + splits * 0.12 - moss * 0.28 + fine * 0.06
    _maps('bark', col, h, ao, rough, 22.0)

def bark_giant(size=1024):
    y, x = np.mgrid[0:size, 0:size].astype(np.float32) / size
    ridges = np.abs(np.sin((x + fbm(size, 6, 4) * 0.08) * np.pi * 30 + fbm(size, 4, 3) * 3.2)) ** 0.38
    plates = fbm(size, 36, 5) * 0.50 + fbm(size, 72, 3) * 0.22 + fbm(size, 140, 2) * 0.12
    moss = np.clip((fbm(size, 6, 4) - 0.46) * 3.8, 0, 1) * (1 - ridges * 0.42)
    h = ridges * 0.78 + plates * 0.22
    lum = 0.05 + h * 0.38
    col = np.dstack([lum * 0.70, lum * 0.82, lum * 1.18])
    col = col + (ridges * 0.12)[..., None] * np.array([0.08, 0.18, 0.36])
    col = col * (1 - moss[..., None]) + moss[..., None] * np.array([0.04, 0.26, 0.22])
    ao = 1 - (1 - ridges) * 0.36 - moss * 0.14
    col = col * (0.50 + 0.50 * ao[..., None])
    rough = 0.84 - moss * 0.28 + ridges * 0.10
    _maps('bark_giant', col, h, ao, rough, 20.0)

def micro(size=512):
    h = fbm(size, 72, 5)
    pits = smooth(0.80, 0.95, fbm(size, 48, 3))
    save('micro_normal.png', normal_map(h - pits * 0.25, 11.0))
    save('micro_rough.png', np.clip(0.42 + (h - 0.5) * 0.42 + pits * 0.18, 0, 1))


def robe(size=1024):
    """Indigo wool with vertical fold streaks + magic veins. Tiles. Not silver."""
    y, x = np.mgrid[0:size, 0:size].astype(np.float32)
    # Vertical fold streaks dominate — matches the hooded silhouette refs.
    folds = 0.5 + 0.5 * np.sin((x / size) * np.pi * 2.0 * 14.0 + fbm(size, 4, 4) * 3.5)
    folds = folds ** 1.35
    warp = 0.5 + 0.5 * np.sin(x / size * np.pi * 2.0 * 110.0)
    weft = 0.5 + 0.5 * np.sin(y / size * np.pi * 2.0 * 64.0)
    nubs = fbm(size, 44, 5)
    thread = fbm(size, 96, 4)
    weave = warp * 0.28 + weft * 0.22 + folds * 0.38 + (nubs - 0.5) * 0.18
    h = weave * 0.62 + thread * 0.28 + folds * 0.18
    lum = 0.028 + h * 0.095 + folds * 0.04 + (nubs - 0.5) * 0.012
    # Deep indigo with cold blue fold highlights — crushed blacks elsewhere.
    albedo = np.dstack([
        lum * 0.72 + folds * 0.018,
        lum * 0.78 + folds * 0.028,
        lum * 1.35 + folds * 0.065,
    ])

    flow = fbm(size, 5, 6)
    flow2 = fbm(size, 9, 5)
    flow3 = fbm(size, 17, 4)
    ridge = np.exp(-((flow - 0.50) ** 2) / (2.0 * 0.011 ** 2))
    ridge2 = np.exp(-((flow2 - 0.48) ** 2) / (2.0 * 0.009 ** 2))
    ridge3 = np.exp(-((flow3 - 0.52) ** 2) / (2.0 * 0.007 ** 2))
    fine = fbm(size, 48, 3)
    sparks = (fine > 0.90).astype(np.float32) * smooth(0.50, 0.68, flow)
    mag = np.clip(ridge * 0.9 + ridge2 * 0.55 + ridge3 * 0.35 + sparks * 1.35, 0, 1)
    glow = np.dstack([
        mag * 0.42 + sparks * 0.28,
        mag * 0.18 + sparks * 0.30,
        mag * 1.05 + sparks * 0.90,
    ])
    save('robe_albedo.png', albedo)
    save('robe_magic.png', glow)
    save('robe_normal.png', normal_map(h, 14.0))
    save('robe_rough.png', np.clip(0.78 + (0.5 - h) * 0.20 - folds * 0.08, 0, 1))


def tavern_wood(size=1024):
    y, x = np.mgrid[0:size, 0:size].astype(np.float32)
    boards = 9.0
    u = x / size * boards
    bid = np.floor(u)
    local = u - bid
    gap = 1.0 - smooth(0.02, 0.0, local) * smooth(0.0, 0.02, 1.0 - local)
    grain = fbm(size, 4, 6, ny=48)
    fine = fbm(size, 20, 4, ny=90)
    knots = smooth(0.78, 0.92, fbm(size, 6, 4))
    h = grain * 0.55 + fine * 0.2 - gap * 0.45 - knots * 0.2
    lum = 0.22 + grain * 0.28 + fine * 0.08 - gap * 0.18 - knots * 0.12
    col = lum[..., None] * np.array([0.62, 0.32, 0.18])
    stain = smooth(0.62, 0.88, fbm(size, 5, 4))
    col = col * (1 - stain[..., None] * 0.25) + stain[..., None] * np.array([0.28, 0.10, 0.08])
    ao = 1 - gap * 0.55 - knots * 0.25
    rough = 0.72 + gap * 0.15 + fine * 0.08 - stain * 0.12
    _maps('tavern_wood', col, h, ao, rough, 11.0)


def tavern_beam(size=1024):
    y, x = np.mgrid[0:size, 0:size].astype(np.float32)
    grain = fbm(size, 6, 6, ny=40)
    splits = 1 - smooth(0.0, 0.07, np.abs(np.sin((x / size) * np.pi * 14 + grain * 3)))
    h = grain * 0.7 - splits * 0.25
    lum = 0.08 + grain * 0.12 - splits * 0.04
    col = lum[..., None] * np.array([0.85, 0.55, 0.38])
    ao = 1 - splits * 0.35
    rough = 0.88 + splits * 0.08
    _maps('tavern_beam', col, h, ao, rough, 12.0)


def tavern_plaster(size=1024):
    grain = fbm(size, 8, 6)
    pits = smooth(0.82, 0.95, fbm(size, 28, 3))
    stain = smooth(0.55, 0.85, fbm(size, 4, 5))
    h = grain * 0.45 - pits * 0.22
    lum = 0.28 + grain * 0.16 - pits * 0.08
    col = lum[..., None] * np.array([0.72, 0.42, 0.32])
    col = col * (1 - stain[..., None] * 0.28) + stain[..., None] * np.array([0.28, 0.12, 0.10])
    ao = 1 - pits * 0.25 - stain * 0.1
    rough = 0.9 + pits * 0.05
    _maps('tavern_plaster', col, h, ao, rough, 8.0)


def tavern_slate(size=1024):
    y, x = np.mgrid[0:size, 0:size].astype(np.float32)
    row = np.floor(y / size * 14.0)
    stagger = (row % 2) * 0.5
    colu = np.floor(x / size * 10.0 + stagger)
    localy = y / size * 14.0 - row
    localx = x / size * 10.0 + stagger - colu
    gap = 1.0 - smooth(0.04, 0.0, localx) * smooth(0.0, 0.04, 1.0 - localx)
    gap *= 1.0 - smooth(0.05, 0.0, localy) * smooth(0.0, 0.05, 1.0 - localy)
    grain = fbm(size, 12, 5)
    h = 0.55 + grain * 0.2 - gap * 0.55
    lum = 0.10 + grain * 0.08 - gap * 0.05
    col = lum[..., None] * np.array([0.55, 0.38, 0.36])
    ao = 1 - gap * 0.45
    rough = 0.55 + gap * 0.2 + grain * 0.1
    _maps('tavern_slate', col, h, ao, rough, 10.0)


def tavern_stone(size=1024):
    f1, f2, cid = voronoi(size, 8, 0.7)
    edge = f2 - f1
    crack = 1 - smooth(0.0, 0.04, edge)
    bevel = smooth(0.0, 0.2, edge)
    grain = fbm(size, 9, 6)
    h = bevel * 0.5 + grain * 0.3 - crack * 0.45
    lum = 0.22 + (cid - 0.5) * 0.08 + grain * 0.12
    col = lum[..., None] * np.array([0.78, 0.48, 0.36])
    ao = 1 - crack * 0.7 - (1 - bevel) * 0.15
    rough = 0.82 + crack * 0.12
    _maps('tavern_stone', col, h, ao, rough, 12.0)


def tavern_iron(size=512):
    grain = fbm(size, 18, 5)
    pits = smooth(0.8, 0.95, fbm(size, 30, 3))
    rust = smooth(0.68, 0.9, fbm(size, 7, 4))
    h = grain * 0.4 - pits * 0.25
    lum = 0.18 + grain * 0.12
    col = lum[..., None] * np.array([0.7, 0.68, 0.64])
    col = col * (1 - rust[..., None] * 0.45) + rust[..., None] * np.array([0.32, 0.12, 0.08])
    ao = 1 - pits * 0.3
    rough = 0.38 + rust * 0.3 + pits * 0.1
    _maps('tavern_iron', col, h, ao, rough, 9.0)


def dwarf_cloth(size=1024):
    y, x = np.mgrid[0:size, 0:size].astype(np.float32)
    warp = 0.5 + 0.5 * np.sin(x / size * np.pi * 2 * 64)
    weft = 0.5 + 0.5 * np.sin(y / size * np.pi * 2 * 48)
    nubs = fbm(size, 28, 5)
    h = warp * 0.35 + weft * 0.35 + nubs * 0.3
    lum = 0.12 + h * 0.1
    col = lum[..., None] * np.array([0.85, 0.22, 0.18])
    ao = 0.9 + nubs * 0.08
    rough = 0.86 + (0.5 - h) * 0.1
    _maps('dwarf_cloth', col, h, ao, rough, 8.0)


def dwarf_leather(size=1024):
    grain = fbm(size, 14, 6)
    pores = fbm(size, 50, 3)
    h = grain * 0.55 + pores * 0.2
    lum = 0.12 + grain * 0.14
    col = lum[..., None] * np.array([0.7, 0.38, 0.22])
    ao = 1 - (1 - grain) * 0.15
    rough = 0.72 + pores * 0.1
    _maps('dwarf_leather', col, h, ao, rough, 9.0)


def dwarf_skin(size=512):
    grain = fbm(size, 10, 5)
    pores = fbm(size, 40, 3)
    h = grain * 0.3 + pores * 0.15
    lum = 0.42 + grain * 0.12
    col = lum[..., None] * np.array([1.05, 0.62, 0.42])
    ao = np.full_like(grain, 0.95)
    rough = 0.52 + pores * 0.12
    _maps('dwarf_skin', col, h, ao, rough, 5.0)


def dwarf_beard(size=512):
    y, x = np.mgrid[0:size, 0:size].astype(np.float32)
    strands = 0.5 + 0.5 * np.sin((x / size + fbm(size, 8, 4) * 0.08) * np.pi * 40)
    h = strands * 0.6 + fbm(size, 20, 4) * 0.3
    lum = 0.12 + h * 0.16
    col = lum[..., None] * np.array([0.7, 0.32, 0.14])
    ao = 0.85 + strands * 0.1
    rough = np.full_like(h, 0.92)
    _maps('dwarf_beard', col, h, ao, rough, 10.0)


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    if len(sys.argv) > 1 and sys.argv[1] == 'robe':
        robe()
    elif len(sys.argv) > 1 and sys.argv[1] == 'tavern':
        tavern_wood(); tavern_beam(); tavern_plaster(); tavern_slate()
        tavern_stone(); tavern_iron(); dwarf_cloth(); dwarf_leather(); dwarf_skin(); dwarf_beard()
    else:
        stone(); cobble_ring(); ground(); rock(); bark(); bark_giant(); micro()
