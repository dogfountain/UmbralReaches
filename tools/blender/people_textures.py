"""People detail maps (villagers, Keg dwarves): ten tileable 512 px PBR layers baked with numpy.

  tools/blender/run.sh people_textures.py
Writes art/textures/people/people_<layer>_albedo.png  (rgb = tint variation, 0.5 neutral, multiplied x2
in dwarf.gdshader; a = roughness variation, 0.5 neutral) and people_<layer>_normal.png (tangent-space,
OpenGL, baked from the height field). Layer order = DwarfMesh.MAT_*:
skin cloth linen leather hair metal wood foam eye fur.
No downloads: everything is generated here (periodic filtered noise, tileable Voronoi, weave maths).
"""
import os
import numpy as np
import bpy

N = 512
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "art", "textures", "people")
os.makedirs(OUT, exist_ok=True)
G = np.mgrid[0:N, 0:N].astype(np.float32) / N        # [y, x] in 0..1
Y, X = G[0], G[1]


def rng(seed):
    return np.random.default_rng(seed)


def pnoise(seed, cells, octaves=1, gain=0.5):
    """Tileable fractal value noise 0..1 (periodic Fourier-filtered white noise)."""
    out = np.zeros((N, N), np.float32)
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        r = rng(seed * 31 + o)
        f = r.standard_normal((N, N)).astype(np.float32)
        F = np.fft.fft2(f)
        fy = np.fft.fftfreq(N)[:, None] * N
        fx = np.fft.fftfreq(N)[None, :] * N
        k = np.sqrt(fx * fx + fy * fy)
        c = cells * (2 ** o)
        F *= np.exp(-(k / c) ** 2)
        g = np.real(np.fft.ifft2(F)).astype(np.float32)
        g = (g - g.mean()) / (g.std() + 1e-6)
        out += g * amp
        tot += amp
        amp *= gain
    out /= tot
    return np.clip(out * 0.25 + 0.5, 0, 1)


def stretch_noise(seed, cu, cv, octaves=1):
    """Anisotropic tileable noise (cu cycles across, cv cycles down)."""
    r = rng(seed)
    f = r.standard_normal((N, N)).astype(np.float32)
    F = np.fft.fft2(f)
    fy = np.fft.fftfreq(N)[:, None] * N
    fx = np.fft.fftfreq(N)[None, :] * N
    F *= np.exp(-((fx / cu) ** 2 + (fy / cv) ** 2))
    g = np.real(np.fft.ifft2(F)).astype(np.float32)
    g = (g - g.mean()) / (g.std() + 1e-6)
    return np.clip(g * 0.25 + 0.5, 0, 1)


def voronoi(seed, n, jitter=0.9, sx=1.0, sy=1.0):
    """Tileable cellular noise: returns (F1 distance, F2 - F1, cell id value 0..1), distances in cell units."""
    r = rng(seed)
    nx, ny = int(n * sx), int(n * sy)
    jx = r.random((ny, nx)).astype(np.float32)
    jy = r.random((ny, nx)).astype(np.float32)
    ids = r.random((ny, nx)).astype(np.float32)
    px = (np.arange(nx)[None, :] + 0.5 + (jx - 0.5) * jitter) / nx
    py = (np.arange(ny)[:, None] + 0.5 + (jy - 0.5) * jitter) / ny
    d1 = np.full((N, N), 9.0, np.float32)
    d2 = np.full((N, N), 9.0, np.float32)
    cid = np.zeros((N, N), np.float32)
    # direct loop over cells in the neighbourhood of each pixel's cell
    cy_i = np.minimum((Y * ny).astype(int), ny - 1)
    cx_i = np.minimum((X * nx).astype(int), nx - 1)
    for oy in (-1, 0, 1):
        for ox in (-1, 0, 1):
            iy = (cy_i + oy) % ny
            ix = (cx_i + ox) % nx
            qx = px[iy, ix] + np.where(cx_i + ox < 0, -1.0, np.where(cx_i + ox >= nx, 1.0, 0.0))
            qy = py[iy, ix] + np.where(cy_i + oy < 0, -1.0, np.where(cy_i + oy >= ny, 1.0, 0.0))
            d = np.sqrt(((X - qx) * nx) ** 2 + ((Y - qy) * ny) ** 2)
            closer = d < d1
            d2 = np.where(closer, d1, np.minimum(d2, d))
            cid = np.where(closer, ids[iy, ix], cid)
            d1 = np.where(closer, d, d1)
    return d1, d2 - d1, cid


def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def normal_from_height(h, strength):
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5 * N
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5 * N
    nx = -dx * strength
    ny = dy * strength          # image y runs down, OpenGL +Y up
    nz = np.ones_like(h)
    L = np.sqrt(nx * nx + ny * ny + nz * nz)
    return np.stack([nx / L * 0.5 + 0.5, ny / L * 0.5 + 0.5, nz / L * 0.5 + 0.5], -1)


def save(name, rgba, suffix):
    img = bpy.data.images.new(name + suffix, N, N, alpha=True, float_buffer=False)
    img.colorspace_settings.name = "Non-Color"
    a = np.clip(rgba, 0, 1)
    if a.shape[-1] == 3:
        a = np.concatenate([a, np.ones((N, N, 1), np.float32)], -1)
    img.pixels.foreach_set(np.ascontiguousarray(a[::-1]).ravel().astype(np.float32))   # image rows start at the bottom
    img.filepath_raw = os.path.join(OUT, name + suffix + ".png")
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)


def emit(name, tint, rough, height, nstrength):
    """tint: (N,N,3) around 0.5; rough: (N,N) around 0.5; height 0..1."""
    save(name, np.concatenate([tint, rough[..., None]], -1), "_albedo")
    save(name, normal_from_height(height, nstrength), "_normal")
    print("wrote", name)


# --- layers ---------------------------------------------------------------------------------------

def skin():
    """Cool-neutral value variation: broad mottling, redder blotches in the low spots, sun-spotted
    freckle specks, pores as dips, a diamond micro-crease network. Hue stays near neutral (the tint
    is the vertex colour); no pink bias."""
    broad = pnoise(11, 3, 3)
    mid = pnoise(12, 14, 2)
    fine = pnoise(13, 90, 1)
    d1, edge, cid = voronoi(14, 64, 0.95)            # micro-creases (diamond network)
    p1, _, pid = voronoi(15, 120, 1.0)               # pores
    crease = 1.0 - smooth(0.0, 0.09, edge)
    pore = (1.0 - smooth(0.0, 0.2, p1)) * (pid > 0.35)
    pore_b = (1.0 - smooth(0.0, 0.45, voronoi(16, 40, 1.0)[0])) * 0.5
    lum = 0.5 + (broad - 0.5) * 0.12 + (mid - 0.5) * 0.08 + (fine - 0.5) * 0.08 - pore * 0.12 - crease * 0.05
    red = (pnoise(17, 5, 2) - 0.5)
    spots = smooth(0.8, 0.9, pnoise(18, 55, 1)) * smooth(0.45, 0.6, pnoise(19, 4, 1))
    r = lum + red * 0.035 - spots * 0.06
    g = lum - red * 0.02 - spots * 0.055
    b = lum - red * 0.025 - spots * 0.05
    tint = np.stack([r, g, b], -1)
    oily = smooth(0.55, 0.8, pnoise(20, 6, 2))
    rough = 0.5 + pore * 0.18 + crease * 0.1 - oily * 0.16 + (fine - 0.5) * 0.1
    h = 0.5 + (fine - 0.5) * 0.18 - pore * 0.55 - crease * 0.22 + (mid - 0.5) * 0.1
    emit("people_skin", tint, rough, h, 1.1)


def weave(seed, threads, twill, slub, fuzz, depth):
    u, v = X * threads, Y * threads
    iu, iv = np.floor(u).astype(int), np.floor(v).astype(int)
    over = (((iu + iv) // twill) % 2) == 0
    fu, fv = u - np.floor(u), v - np.floor(v)
    tu, tv = np.sin(fu * np.pi), np.sin(fv * np.pi)
    th = np.where(over, tv, tu)
    # per-thread slub (varies along the thread, differs thread to thread)
    sl = stretch_noise(seed + 1, threads * 0.9, 6, 1)
    sl2 = stretch_noise(seed + 2, 6, threads * 0.9, 1)
    slubv = np.where(over, sl2, sl) - 0.5
    fz = (pnoise(seed + 3, 170, 1) - 0.5) * fuzz
    h = 0.18 + 0.62 * th * (1 + slubv * slub) + fz
    shade = 0.86 + 0.16 * th + slubv * 0.2 * slub + (pnoise(seed + 4, 5, 2) - 0.5) * 0.22   # cloth dirt / wear blotches
    tint = np.stack([shade * 0.5] * 3, -1)
    rough = 0.5 + (1 - th) * 0.18 + fz * 0.4
    return tint, rough, h


def wool():
    t, r, h = weave(30, 24, 2, 1.0, 0.25, 1)
    emit("people_cloth", t, r, h, 2.4)


def linen():
    t, r, h = weave(40, 40, 1, 1.6, 0.2, 1)
    emit("people_linen", t, r, h, 1.8)


def leather():
    d1, edge, cid = voronoi(50, 34, 0.9)
    grain = smooth(0.0, 0.5, edge) ** 0.6
    wr = pnoise(51, 9, 3)
    crease = (1.0 - np.abs(wr - 0.5) * 2) ** 8
    scuff = smooth(0.62, 0.75, pnoise(52, 14, 2))
    h = 0.5 + grain * 0.28 - crease * 0.3 + (pnoise(53, 120, 1) - 0.5) * 0.06
    k = 0.88 + grain * 0.14 - crease * 0.2 + scuff * 0.16
    tint = np.stack([0.5 * k, 0.49 * k, 0.47 * k], -1)
    rough = 0.5 + scuff * 0.2 - grain * 0.08 + crease * 0.1
    emit("people_leather", tint, rough, h, 2.0)


def hair():
    """Strands run down the image (v); the shader stretches the tile along the lock (UV 10 x 3)."""
    # ~140 strands across, grouped into clumps of 5-12
    st = np.sin(X * 140 * 2 * np.pi + pnoise(62, 30, 1) * 7.0) * 0.5 + 0.5
    st2 = np.sin(X * 63 * 2 * np.pi + pnoise(63, 24, 1) * 5.0) * 0.5 + 0.5
    drift = stretch_noise(64, 60, 2, 1)
    clumpm = stretch_noise(65, 18, 1.2, 1)
    lum = 0.5 + (st - 0.5) * 0.22 + (st2 - 0.5) * 0.14 + (clumpm - 0.5) * 0.4 + (drift - 0.5) * 0.15
    tint = np.stack([lum, lum, lum * 0.98], -1)
    rough = 0.5 - (st - 0.5) * 0.3 + (clumpm - 0.5) * 0.3
    h = 0.4 + st * 0.35 + st2 * 0.2 + (clumpm - 0.5) * 0.3
    emit("people_hair", tint, rough, h, 2.2)


def metal():
    d1, edge, cid = voronoi(70, 10, 0.9)
    dent = smooth(0.0, 0.7, d1)
    scr = smooth(0.94, 1.0, np.sin((X * 3 + Y * 17 + pnoise(71, 5, 2) * 4) * 2 * np.pi) * 0.5 + 0.5) * 0.6
    low = pnoise(72, 4, 3)
    rust = smooth(0.58, 0.75, low) * (1 - dent)
    h = 0.3 + dent * 0.45 + scr * 0.15 + (pnoise(73, 80, 1) - 0.5) * 0.05
    k = 0.9 + dent * 0.15 + scr * 0.3
    tint = np.stack([0.5 * k + rust * 0.08, 0.5 * k - rust * 0.04, 0.5 * k - rust * 0.12], -1)
    rough = 0.5 - scr * 0.25 + rust * 0.3 + (pnoise(74, 30, 1) - 0.5) * 0.15
    emit("people_metal", tint, rough, h, 2.0)


def wood():
    ring = np.sin((X * 9 + pnoise(80, 5, 2) * 1.6 + pnoise(81, 60, 1) * 0.1) * 2 * np.pi) * 0.5 + 0.5
    stave = smooth(0.0, 0.02, np.abs(((X * 4) % 1.0))) * smooth(0.0, 0.02, np.abs(1.0 - ((X * 4) % 1.0)))
    h = 0.35 + ring * 0.25 + (pnoise(82, 100, 1) - 0.5) * 0.1 - (1 - stave) * 0.35
    k = 0.82 + ring * 0.28 - (1 - stave) * 0.4
    tint = np.stack([0.52 * k, 0.5 * k, 0.46 * k], -1)
    emit("people_wood", tint, 0.5 + (1 - ring) * 0.2, h, 2.0)


def foam():
    d1, e, c = voronoi(90, 36, 0.9)
    b = smooth(0.0, 0.5, d1)
    h = 0.3 + b * 0.6
    tint = np.stack([0.5 - (1 - b) * 0.06, 0.5 - (1 - b) * 0.06, 0.5 - (1 - b) * 0.08], -1)
    emit("people_foam", tint, np.full((N, N), 0.5, np.float32), h, 1.5)


def eye():
    emit("people_eye", np.full((N, N, 3), 0.5, np.float32), np.full((N, N), 0.5, np.float32), np.full((N, N), 0.5, np.float32), 0.0)


def fur():
    d1, e, c = voronoi(100, 24, 0.95)
    st = np.sin((X * 36 + c * 5 + pnoise(101, 5, 2) * 3) * 2 * np.pi) * 0.5 + 0.5
    h = 0.2 + st * 0.45 + smooth(0.0, 0.6, d1) * 0.3
    k = 0.7 + st * 0.3 + (c - 0.5) * 0.4
    tint = np.stack([0.5 * k] * 3, -1)
    emit("people_fur", tint, np.full((N, N), 0.6, np.float32), h, 2.5)


for fn in (skin, wool, linen, leather, hair, metal, wood, foam, eye, fur):
    fn()
