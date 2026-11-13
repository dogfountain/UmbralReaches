"""r37 West Marches: tiling PBR texture sets, generated procedurally (numpy, no scans, no downloads).

  tools/blender/run.sh r37_west_textures.py            (Blender's own Python has numpy)
Writes art/textures/r37_<set>_{albedo,normal,orm}.png, 1024 px, seamless. orm = AO (R), roughness (G),
metal (B), the glTF packing the rest of the repo uses.

Sets
  stone    carved, weathered granite for the Fallen Hierarch: pitting, hairline cracks, lichen, rain streaks
  ashlar   coursed dressed masonry (the mill, the bridge piers, the hold walls): mortar, per-block tone, moss in the joints
  timber   weathered boards: grain, silvering, nail heads, gaps
  iron     rusted iron: pitting, scale, orange bloom
  thatch   (cottages) weathered reed thatch: strands running down the image (v), bundle bands, silvering, moss
  daub     (cottages) limewashed wattle-and-daub: lumpy plaster, hairline cracks, straw flecks, damp and rain streaks
  slate    (cottages) riven roof slate: laminated grain, plate-to-plate tone, chips, lichen
  cloth    burlap: a visible over-under weave, uneven threads, a few darns, dust (sacks; used on props at 3x)
  wax      (lamps) tallow candle wax
  hewn     (props) one hand-dressed block seen close: punched tooling in diagonal runs, a drafted grain, pits, quartz
           flecks, lichen rosettes. No joints and no cracks (a prop's joints and breaks are modelled); 1 tile = 1 m on props

  run.sh r37_west_textures.py -- --only cloth   writes just the named sets
"""
import bpy
import math
import os
import sys
import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art", "textures")
N = 1024


def tnoise(n, beta, seed, aniso=(1.0, 1.0)):
    """Seamless 1/f^beta noise in 0..1 (FFT-filtered white noise is periodic by construction)."""
    rng = np.random.default_rng(seed)
    f = np.fft.fft2(rng.standard_normal((n, n)))
    fy = np.fft.fftfreq(n)[:, None] * aniso[1]
    fx = np.fft.fftfreq(n)[None, :] * aniso[0]
    r = np.sqrt(fx ** 2 + fy ** 2)
    r[0, 0] = 1.0
    f = f / (r ** beta)
    f[0, 0] = 0.0
    a = np.real(np.fft.ifft2(f))
    a = (a - a.min()) / (a.max() - a.min() + 1e-9)
    return a


def rnoise(n, beta, seed, angle, stretch):
    """Seamless 1/f^beta noise whose features run long along `angle` (stretch times longer than wide)."""
    rng = np.random.default_rng(seed)
    f = np.fft.fft2(rng.standard_normal((n, n)))
    fy = np.fft.fftfreq(n)[:, None]
    fx = np.fft.fftfreq(n)[None, :]
    ca, sa = math.cos(angle), math.sin(angle)
    along = fx * ca + fy * sa
    across = -fx * sa + fy * ca
    r = np.sqrt((along * stretch) ** 2 + across ** 2)
    r[0, 0] = 1.0
    f = f / (r ** beta) * np.exp(-(r * 9.0) ** 2) * (1.0 - np.exp(-(r * 55.0) ** 2))     # band-passed: short strokes a few pixels wide, no fizz and no long drifts
    f[0, 0] = 0.0
    a = np.real(np.fft.ifft2(f))
    return (a - a.min()) / (a.max() - a.min() + 1e-9)


def voronoi(n, count, seed):
    """Seamless Worley: (F1, F2, cell id) on an n x n torus."""
    rng = np.random.default_rng(seed)
    pts = rng.random((count, 2))
    ys, xs = np.mgrid[0:n, 0:n]
    u = xs / n
    v = ys / n
    f1 = np.full((n, n), 9.0)
    f2 = np.full((n, n), 9.0)
    ids = np.zeros((n, n), dtype=np.int32)
    for i, (px, py) in enumerate(pts):
        for ox in (-1, 0, 1):
            for oy in (-1, 0, 1):
                d = np.sqrt((u - (px + ox)) ** 2 + (v - (py + oy)) ** 2)
                m = d < f1
                f2 = np.where(m, f1, np.minimum(f2, d))
                ids = np.where(m, i, ids)
                f1 = np.where(m, d, f1)
    return f1, f2, ids


def smooth(a, lo, hi):
    t = np.clip((a - lo) / (hi - lo + 1e-9), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def normal_from(h, strength):
    gx = (np.roll(h, -1, axis=1) - np.roll(h, 1, axis=1)) * 0.5 * N
    gr = (np.roll(h, -1, axis=0) - np.roll(h, 1, axis=0)) * 0.5 * N
    nx = -gx * strength
    ny = gr * strength
    nz = np.ones_like(h)
    ln = np.sqrt(nx * nx + ny * ny + nz * nz)
    return np.stack([nx / ln * 0.5 + 0.5, ny / ln * 0.5 + 0.5, nz / ln * 0.5 + 0.5], axis=-1)


def save(name, rgb, is_color):
    img = bpy.data.images.new(name, N, N, alpha=False)
    img.colorspace_settings.name = "sRGB" if is_color else "Non-Color"
    px = np.ones((N, N, 4), dtype=np.float32)
    px[:, :, :3] = np.clip(rgb, 0.0, 1.0)
    px = px[::-1]          # Blender images are bottom-up
    img.pixels.foreach_set(px.ravel())
    img.filepath_raw = os.path.join(OUT, name + ".png")
    img.file_format = "PNG"
    img.save()
    print("SAVED", img.filepath_raw)


def finish(name, albedo, height, rough, ao, normal_strength, metal=0.0):
    save("r37_%s_albedo" % name, albedo, True)
    save("r37_%s_normal" % name, normal_from(height, normal_strength), False)
    orm = np.stack([ao, rough, np.full_like(ao, metal) if np.isscalar(metal) else metal], axis=-1)
    save("r37_%s_orm" % name, orm, False)


def mix(a, b, t):
    t = t[..., None]
    return a * (1.0 - t) + b * t


def col(r, g, b):
    return np.array([r, g, b], dtype=np.float32)


def make_stone():
    big = tnoise(N, 2.4, 11)
    mid = tnoise(N, 1.6, 12)
    fine = tnoise(N, 0.9, 13)
    pits = smooth(fine, 0.62, 0.8) * smooth(mid, 0.3, 0.7)
    f1, f2, ids = voronoi(N, 70, 14)
    edge = 1.0 - smooth(f2 - f1, 0.0, 0.006)
    crack = edge * smooth(tnoise(N, 2.0, 15), 0.62, 0.74)          # only some cell edges are cracks
    streak = tnoise(N, 2.2, 16, aniso=(0.4, 3.0))                  # rain runs down the image (v)
    tone = 0.6 + 0.5 * big
    base = mix(np.broadcast_to(col(0.46, 0.44, 0.41), (N, N, 3)), np.broadcast_to(col(0.62, 0.59, 0.54), (N, N, 3)), tone - 0.4)
    base = base * (0.82 + 0.3 * mid)[..., None]
    base = mix(base, np.broadcast_to(col(0.2, 0.18, 0.16), (N, N, 3)), np.clip(smooth(streak, 0.6, 0.85) * 0.35, 0, 1))
    lichen = smooth(tnoise(N, 1.4, 17), 0.62, 0.75) * smooth(tnoise(N, 0.8, 18), 0.45, 0.6)
    base = mix(base, np.broadcast_to(col(0.55, 0.58, 0.33), (N, N, 3)), lichen * 0.75)
    base = mix(base, np.broadcast_to(col(0.7, 0.55, 0.28), (N, N, 3)), smooth(tnoise(N, 1.0, 19), 0.72, 0.8) * lichen * 0.6)
    base = mix(base, np.broadcast_to(col(0.07, 0.065, 0.06), (N, N, 3)), np.clip(pits * 0.5 + crack * 0.55, 0, 1))
    h = 0.5 + 0.18 * (mid - 0.5) + 0.12 * (fine - 0.5) - 0.3 * pits - 0.5 * crack + 0.2 * lichen
    rough = np.clip(0.78 + 0.18 * fine - 0.1 * lichen + 0.1 * crack, 0.3, 1.0)
    ao = np.clip(1.0 - 0.7 * crack - 0.5 * pits, 0.2, 1.0)
    finish("stone", base, h, rough, ao, 2.4)


def make_ashlar():
    rng = np.random.default_rng(21)
    rows = 8
    rh = N // rows
    ys, xs = np.mgrid[0:N, 0:N]
    block = np.zeros((N, N), dtype=np.int32)
    edge_x = np.zeros((N, N))
    nid = 0
    for r in range(rows):
        cuts = [0.0]
        while cuts[-1] < 1.0:
            cuts.append(cuts[-1] + rng.uniform(0.17, 0.33))
        cuts[-1] = 1.0
        # make the row wrap: scale the cuts to land exactly on 1
        for i in range(len(cuts) - 1):
            x0, x1 = int(cuts[i] * N), int(cuts[i + 1] * N)
            block[r * rh:(r + 1) * rh, x0:x1] = nid
            edge_x[r * rh:(r + 1) * rh, x0:x1] = np.minimum(np.arange(x0, x1) - x0, x1 - 1 - np.arange(x0, x1))[None, :]
            nid += 1
    ey = np.zeros((N, N))
    for r in range(rows):
        yy = np.arange(r * rh, (r + 1) * rh)
        ey[r * rh:(r + 1) * rh, :] = np.minimum(yy - r * rh, (r + 1) * rh - 1 - yy)[:, None]
    d = np.minimum(edge_x, ey)
    mortar = 1.0 - smooth(d, 3.0, 8.0)
    tone = rng.random(nid)[block]
    mid = tnoise(N, 1.7, 22)
    fine = tnoise(N, 0.9, 23)
    base = mix(np.broadcast_to(col(0.42, 0.40, 0.37), (N, N, 3)), np.broadcast_to(col(0.62, 0.57, 0.5), (N, N, 3)), tone)
    base = base * (0.8 + 0.35 * mid)[..., None]
    base = mix(base, np.broadcast_to(col(0.3, 0.29, 0.26), (N, N, 3)), mortar * 0.8)
    moss = smooth(tnoise(N, 1.5, 24), 0.55, 0.72) * (0.35 + 0.65 * mortar)
    base = mix(base, np.broadcast_to(col(0.25, 0.34, 0.16), (N, N, 3)), moss * 0.7)
    pit = smooth(fine, 0.64, 0.8)
    base = mix(base, np.broadcast_to(col(0.1, 0.09, 0.08), (N, N, 3)), pit * 0.4)
    h = 0.55 - 0.35 * mortar + 0.12 * (mid - 0.5) + 0.08 * (fine - 0.5) - 0.12 * pit + 0.03 * tone
    rough = np.clip(0.8 + 0.15 * fine - 0.1 * moss, 0.4, 1.0)
    ao = np.clip(1.0 - 0.6 * mortar - 0.3 * pit, 0.2, 1.0)
    finish("ashlar", base, h, rough, ao, 3.0)


def make_timber():
    rng = np.random.default_rng(31)
    boards = 8
    bw = N // boards
    ys, xs = np.mgrid[0:N, 0:N]
    bid = xs // bw
    inb = (xs % bw)
    gap = 1.0 - smooth(np.minimum(inb, bw - 1 - inb).astype(np.float32), 1.0, 4.0)
    btone = rng.random(boards)[bid]
    grain = tnoise(N, 1.8, 32, aniso=(0.5, 14.0))
    ring = 0.5 + 0.5 * np.sin((grain * 38.0 + btone * 6.0) * 2.0)
    weather = tnoise(N, 2.0, 33)
    fine = tnoise(N, 0.9, 34)
    warm = col(0.36, 0.25, 0.16)
    silver = col(0.46, 0.43, 0.39)
    base = mix(np.broadcast_to(warm, (N, N, 3)), np.broadcast_to(silver, (N, N, 3)), np.clip(weather * 1.1 + btone * 0.25 - 0.15, 0, 1))
    base = base * (0.78 + 0.3 * ring + 0.12 * btone)[..., None]
    base = mix(base, np.broadcast_to(col(0.05, 0.04, 0.035), (N, N, 3)), gap * 0.9)
    nails = np.zeros((N, N))
    for b in range(boards):
        for y in (60, 540):
            cx = b * bw + bw // 2
            nails[max(y - 4, 0):y + 4, cx - 4:cx + 4] = 1.0
    base = mix(base, np.broadcast_to(col(0.08, 0.06, 0.05), (N, N, 3)), nails * 0.8)
    mold = smooth(tnoise(N, 1.4, 35), 0.66, 0.8) * 0.5
    base = mix(base, np.broadcast_to(col(0.24, 0.3, 0.16), (N, N, 3)), mold)
    h = 0.55 + 0.2 * (ring - 0.5) + 0.08 * (fine - 0.5) - 0.5 * gap + 0.1 * nails
    rough = np.clip(0.82 + 0.12 * fine - 0.15 * ring, 0.4, 1.0)
    ao = np.clip(1.0 - 0.8 * gap, 0.15, 1.0)
    finish("timber", base, h, rough, ao, 2.0)


def make_iron():
    mid = tnoise(N, 1.8, 41)
    fine = tnoise(N, 0.9, 42)
    rust = smooth(tnoise(N, 1.5, 43), 0.45, 0.7)
    scale = smooth(fine, 0.55, 0.8)
    base = mix(np.broadcast_to(col(0.13, 0.125, 0.13), (N, N, 3)), np.broadcast_to(col(0.44, 0.2, 0.08), (N, N, 3)), rust)
    base = base * (0.75 + 0.5 * mid)[..., None]
    base = mix(base, np.broadcast_to(col(0.05, 0.04, 0.035), (N, N, 3)), scale * 0.4)
    h = 0.5 + 0.25 * (mid - 0.5) - 0.3 * scale + 0.1 * rust
    rough = np.clip(0.55 + 0.35 * rust + 0.1 * fine, 0.3, 1.0)
    metal = np.clip(0.9 - 0.8 * rust, 0.0, 1.0)
    ao = np.clip(1.0 - 0.5 * scale, 0.3, 1.0)
    finish("iron", base, h, rough, ao, 2.0, metal)


def make_wax():
    """wax (lamps kit): tallow candle wax, warm cream, soft mottling, faint vertical drip streaks, soot specks, gentle sheen."""
    mid = tnoise(N, 2.0, 51)
    fine = tnoise(N, 1.0, 52)
    streak = tnoise(N, 1.6, 53, aniso=(0.5, 12.0))
    soot = smooth(tnoise(N, 1.2, 54), 0.68, 0.82)
    base = mix(np.broadcast_to(col(0.80, 0.74, 0.56), (N, N, 3)), np.broadcast_to(col(0.66, 0.58, 0.40), (N, N, 3)), np.clip(mid * 1.2 - 0.1, 0, 1))
    base = base * (0.9 + 0.2 * streak)[..., None]
    base = mix(base, np.broadcast_to(col(0.18, 0.15, 0.11), (N, N, 3)), soot * 0.5)
    h = 0.5 + 0.1 * (streak - 0.5) + 0.04 * (fine - 0.5)
    rough = np.clip(0.5 + 0.15 * fine, 0.35, 0.8)
    ao = np.clip(1.0 - 0.25 * soot, 0.5, 1.0)
    finish("wax", base, h, rough, ao, 1.0)


def make_cloth():
    """Burlap: a plain weave (64 threads a tile), thread-thickness noise, darned patches, dust."""
    rng = np.random.default_rng(51)
    th = 112
    ys, xs = np.mgrid[0:N, 0:N]
    u = xs / N * th
    v = ys / N * th
    # the threads wobble a little off true
    u = u + 0.35 * (tnoise(N, 2.0, 52) - 0.5)
    v = v + 0.35 * (tnoise(N, 2.0, 53) - 0.5)
    fu, fv = u - np.floor(u), v - np.floor(v)
    warp = 0.5 + 0.5 * np.sin(fu * math.pi)          # a thread running up, bulging mid-cell
    weft = 0.5 + 0.5 * np.sin(fv * math.pi)
    over = ((np.floor(u) + np.floor(v)) % 2) == 0
    h = np.where(over, warp, weft)
    gapw = 1.0 - np.maximum(warp, weft) * 0 - np.minimum(warp, weft) * 0
    thick = 0.8 + 0.4 * tnoise(N, 1.2, 54)
    h = h * thick
    # darns: tighter diagonal stitching in three patches
    darn = np.zeros((N, N))
    for (cx, cy, w, hh) in ((200, 250, 150, 110), (700, 640, 120, 160), (420, 880, 170, 90)):
        m = (xs > cx) & (xs < cx + w) & (ys > cy) & (ys < cy + hh)
        darn = np.where(m, 1.0, darn)
        st = 0.5 + 0.5 * np.sin((xs + ys) * 0.55)
        h = np.where(m, 0.45 + 0.4 * st * thick, h)
    dust = smooth(tnoise(N, 1.6, 55), 0.5, 0.8)
    soil = smooth(tnoise(N, 1.3, 56), 0.6, 0.8)
    lo = col(0.29, 0.23, 0.16)
    hi = col(0.54, 0.46, 0.33)
    base = mix(np.broadcast_to(lo, (N, N, 3)), np.broadcast_to(hi, (N, N, 3)), np.clip(h * 1.05, 0, 1))
    base = base * (0.85 + 0.3 * tnoise(N, 1.8, 57))[..., None]
    base = mix(base, np.broadcast_to(col(0.43, 0.37, 0.3), (N, N, 3)), darn * 0.7)
    base = mix(base, np.broadcast_to(col(0.66, 0.6, 0.48), (N, N, 3)), dust * 0.35)
    base = mix(base, np.broadcast_to(col(0.2, 0.15, 0.1), (N, N, 3)), soil * 0.35)
    rough = np.clip(0.93 + 0.05 * (h - 0.5), 0.8, 1.0)
    ao = np.clip(0.55 + 0.5 * h, 0.4, 1.0)
    finish("cloth", base, h, rough, ao, 2.2)


def make_thatch():
    rng = np.random.default_rng(51)
    strand = tnoise(N, 1.2, 52, aniso=(0.35, 16.0))              # long strands running down v
    strand2 = tnoise(N, 1.6, 53, aniso=(0.6, 9.0))
    mid = tnoise(N, 2.0, 54)
    fine = tnoise(N, 0.9, 55)
    bands = 0.5 + 0.5 * np.sin(np.arange(N)[:, None] / N * 2 * np.pi * 6 + 3.0 * tnoise(N, 2.2, 56))   # bundle courses
    gold = col(0.62, 0.47, 0.22)
    grey = col(0.42, 0.37, 0.28)
    dark = col(0.17, 0.12, 0.07)
    base = mix(np.broadcast_to(gold, (N, N, 3)), np.broadcast_to(grey, (N, N, 3)), np.clip(mid * 1.1 + 0.25 * strand2 - 0.2, 0, 1))
    base = base * (0.62 + 0.7 * strand)[..., None]
    gaps = smooth(strand2, 0.18, 0.05)
    base = mix(base, np.broadcast_to(dark, (N, N, 3)), np.clip(gaps * 0.8 + 0.35 * smooth(bands, 0.85, 1.0), 0, 1))
    moss = smooth(tnoise(N, 1.5, 57), 0.6, 0.76) * (0.5 + 0.5 * mid)
    base = mix(base, np.broadcast_to(col(0.22, 0.27, 0.1), (N, N, 3)), moss * 0.6)
    h = 0.5 + 0.35 * (strand - 0.5) + 0.15 * (strand2 - 0.5) - 0.25 * gaps - 0.1 * smooth(bands, 0.85, 1.0) + 0.04 * (fine - 0.5)
    rough = np.clip(0.9 + 0.1 * fine - 0.1 * strand, 0.5, 1.0)
    ao = np.clip(1.0 - 0.7 * gaps - 0.3 * smooth(bands, 0.85, 1.0), 0.15, 1.0)
    finish("thatch", base, h, rough, ao, 2.6)


def make_daub():
    big = tnoise(N, 2.4, 61)
    mid = tnoise(N, 1.6, 62)
    fine = tnoise(N, 0.9, 63)
    lump = tnoise(N, 2.0, 64)
    f1, f2, ids = voronoi(N, 40, 65)
    edge = 1.0 - smooth(f2 - f1, 0.0, 0.004)
    crack = edge * smooth(tnoise(N, 2.0, 66), 0.6, 0.72)
    streak = tnoise(N, 2.2, 67, aniso=(0.4, 3.5))
    wash = col(0.76, 0.71, 0.6)
    base = np.broadcast_to(wash, (N, N, 3)) * (0.86 + 0.22 * mid)[..., None]
    base = mix(base, np.broadcast_to(col(0.45, 0.4, 0.31), (N, N, 3)), np.clip(smooth(streak, 0.55, 0.85) * 0.45, 0, 1))
    # bare daub showing through the limewash where it has flaked
    flake = smooth(tnoise(N, 1.5, 68), 0.68, 0.78) * smooth(fine, 0.4, 0.6)
    base = mix(base, np.broadcast_to(col(0.46, 0.34, 0.22), (N, N, 3)), flake * 0.8)
    rng = np.random.default_rng(69)
    fl = np.zeros((N, N))
    for _ in range(220):          # chopped straw flecks
        x, y = rng.integers(0, N - 20), rng.integers(0, N - 4)
        ln = rng.integers(6, 18)
        fl[y:y + 2, x:x + ln] = 1.0
    base = mix(base, np.broadcast_to(col(0.5, 0.4, 0.2), (N, N, 3)), fl * 0.5)
    base = mix(base, np.broadcast_to(col(0.14, 0.12, 0.1), (N, N, 3)), crack * 0.55)
    mold = smooth(tnoise(N, 1.4, 70), 0.68, 0.8) * 0.4
    base = mix(base, np.broadcast_to(col(0.3, 0.34, 0.2), (N, N, 3)), mold)
    h = 0.5 + 0.3 * (lump - 0.5) + 0.1 * (fine - 0.5) - 0.4 * crack - 0.15 * flake - 0.1 * fl
    rough = np.clip(0.85 + 0.12 * fine, 0.4, 1.0)
    ao = np.clip(1.0 - 0.6 * crack - 0.2 * fl, 0.25, 1.0)
    finish("daub", base, h, rough, ao, 2.2)


def make_slate():
    lam = tnoise(N, 1.4, 81, aniso=(10.0, 0.6))                # laminated grain across the slab
    mid = tnoise(N, 1.8, 82)
    fine = tnoise(N, 0.9, 83)
    f1, f2, ids = voronoi(N, 36, 84)
    rng = np.random.default_rng(85)
    tone = rng.random(36)[ids]
    edge = 1.0 - smooth(f2 - f1, 0.0, 0.008)
    base = mix(np.broadcast_to(col(0.17, 0.185, 0.23), (N, N, 3)), np.broadcast_to(col(0.3, 0.31, 0.35), (N, N, 3)), tone * 0.8)
    base = base * (0.72 + 0.5 * lam + 0.2 * mid)[..., None]
    chips = smooth(fine, 0.66, 0.8)
    base = mix(base, np.broadcast_to(col(0.45, 0.45, 0.46), (N, N, 3)), chips * 0.35)
    lichen = smooth(tnoise(N, 1.4, 86), 0.62, 0.76) * smooth(tnoise(N, 0.8, 87), 0.45, 0.6)
    base = mix(base, np.broadcast_to(col(0.5, 0.55, 0.3), (N, N, 3)), lichen * 0.55)
    base = mix(base, np.broadcast_to(col(0.05, 0.05, 0.06), (N, N, 3)), edge * 0.5)
    h = 0.5 + 0.2 * (lam - 0.5) + 0.1 * (mid - 0.5) - 0.3 * edge - 0.12 * chips + 0.06 * tone
    rough = np.clip(0.6 + 0.3 * fine + 0.15 * lichen, 0.35, 1.0)
    ao = np.clip(1.0 - 0.6 * edge, 0.25, 1.0)
    finish("slate", base, h, rough, ao, 2.4)


def make_hewn():
    big = tnoise(N, 2.6, 71)
    mid = tnoise(N, 1.7, 72)
    fine = tnoise(N, 0.7, 73)
    grit = tnoise(N, 0.25, 74)
    # the mason's punch: short, uneven strokes lying mostly one way (a second, fainter pass across them), gone where the face wore
    worn = smooth(big, 0.35, 0.7)
    pa = rnoise(N, 0.4, 76, math.radians(34.0), 4.0)
    pb = rnoise(N, 0.4, 77, math.radians(-52.0), 3.5)
    tool = (smooth(pa, 0.6, 0.72) * 0.8 + smooth(pb, 0.64, 0.76) * 0.5) * (1.0 - 0.7 * worn) * smooth(mid, 0.2, 0.55)
    pits = smooth(fine, 0.66, 0.8) * smooth(mid, 0.35, 0.7)
    f1, f2, ids = voronoi(N, 46, 78)
    spall = smooth(tnoise(N, 1.3, 79), 0.66, 0.72) * smooth(0.05 - f1, 0.0, 0.03)       # a few shallow flaked scars
    strata = tnoise(N, 2.0, 80, aniso=(0.25, 2.6))
    tone = 0.55 + 0.5 * big
    base = mix(np.broadcast_to(col(0.44, 0.42, 0.39), (N, N, 3)), np.broadcast_to(col(0.63, 0.6, 0.55), (N, N, 3)), np.clip(tone - 0.3, 0, 1))
    base = base * (0.78 + 0.34 * mid + 0.14 * (strata - 0.5))[..., None]
    base = base * (0.86 + 0.28 * grit)[..., None] * (0.9 + 0.2 * fine)[..., None]
    base = mix(base, np.broadcast_to(col(0.82, 0.8, 0.76), (N, N, 3)), smooth(grit, 0.8, 0.9) * 0.35)      # quartz flecks
    base = mix(base, np.broadcast_to(col(0.25, 0.23, 0.21), (N, N, 3)), np.clip(tool * 0.16 + pits * 0.6, 0, 1))
    base = mix(base, np.broadcast_to(col(0.7, 0.67, 0.61), (N, N, 3)), spall * 0.5)                         # a fresh scar is paler
    lich = smooth(0.035 - f1, 0.0, 0.02) * smooth(tnoise(N, 0.9, 81), 0.4, 0.6) * smooth(tnoise(N, 1.6, 82), 0.55, 0.7)
    ring = lich * (0.6 + 0.4 * np.sin(f1 * 900.0))
    base = mix(base, np.broadcast_to(col(0.58, 0.6, 0.4), (N, N, 3)), ring * 0.7)
    base = mix(base, np.broadcast_to(col(0.72, 0.6, 0.3), (N, N, 3)), lich * smooth(tnoise(N, 1.0, 83), 0.6, 0.75) * 0.6)
    h = 0.5 + 0.16 * (mid - 0.5) + 0.1 * (fine - 0.5) + 0.05 * (grit - 0.5) - 0.24 * tool - 0.3 * pits - 0.16 * spall + 0.08 * lich
    rough = np.clip(0.8 + 0.15 * fine - 0.12 * spall - 0.06 * lich, 0.35, 1.0)
    ao = np.clip(1.0 - 0.3 * tool - 0.5 * pits, 0.25, 1.0)
    finish("hewn", base, h, rough, ao, 3.0)


if __name__ == "__main__":
    import sys
    os.makedirs(OUT, exist_ok=True)
    argv = sys.argv
    only = argv[argv.index("--only") + 1].split(",") if "--only" in argv else []
    for nm in ("stone", "ashlar", "timber", "iron", "wax", "cloth", "thatch", "daub", "slate", "hewn"):
        fn = globals().get("make_" + nm)
        if fn is not None and (not only or nm in only):
            fn()
