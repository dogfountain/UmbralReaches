"""Painter toolkit for the icon art: noise, SDF shapes, bevel lighting, glows, a painted finish.
Pure numpy + zlib (no PIL). Run through Blender's bundled Python: see tools/gen_icons.py."""
import struct
import zlib

import numpy as np

N = 256
_Y, _X = np.mgrid[0:N, 0:N]
x = ((_X + 0.5) / N * 2.0 - 1.0).astype(np.float64)
y = ((_Y + 0.5) / N * 2.0 - 1.0).astype(np.float64)
PX = 2.0 / N


def hex_rgb(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])


# --- noise ------------------------------------------------------------------------------------

def _hash(ix, iy, seed):
    h = (ix.astype(np.int64) * 374761393 + iy.astype(np.int64) * 668265263 + seed * 1442695041) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    h = h ^ (h >> 16)
    return (h & 0xFFFF) / 65535.0


def vnoise(px, py, seed=0):
    ix = np.floor(px)
    iy = np.floor(py)
    fx = px - ix
    fy = py - iy
    fx = fx * fx * (3 - 2 * fx)
    fy = fy * fy * (3 - 2 * fy)
    a = _hash(ix, iy, seed)
    b = _hash(ix + 1, iy, seed)
    c = _hash(ix, iy + 1, seed)
    d = _hash(ix + 1, iy + 1, seed)
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def fbm(px, py, seed=0, octaves=5, gain=0.5):
    s = 0.0
    amp = 1.0
    tot = 0.0
    for o in range(octaves):
        s = s + amp * vnoise(px, py, seed + o * 17)
        tot += amp
        px = px * 2.03 + 11.7
        py = py * 2.03 + 3.1
        amp *= gain
    return s / tot


def nz(scale, seed=0, ox=0.0, oy=0.0, octaves=5, px=None, py=None):
    px = x if px is None else px
    py = y if py is None else py
    return fbm(px * scale + ox, py * scale + oy, seed, octaves)


def warp(amp, scale, seed=0):
    """Domain-warped coordinates: shapes evaluated on them get hand-painted wobbly edges."""
    return x + (nz(scale, seed) - 0.5) * 2 * amp, y + (nz(scale, seed + 91) - 0.5) * 2 * amp


# --- filters ----------------------------------------------------------------------------------

def blur(a, sigma):
    """Gaussian blur by FFT. sigma in pixels."""
    if sigma <= 0.01:
        return a
    k = np.fft.fftfreq(N)
    g = np.exp(-2 * (np.pi ** 2) * (sigma ** 2) * (k[:, None] ** 2 + k[None, :] ** 2))
    if a.ndim == 2:
        return np.real(np.fft.ifft2(np.fft.fft2(a) * g))
    return np.stack([blur(a[..., i], sigma) for i in range(a.shape[2])], axis=2)


def smooth(sd, aa=1.2):
    return np.clip(0.5 - sd / (aa * PX), 0.0, 1.0)


def glow(sd, radius, power=1.0):
    return np.exp(-np.maximum(sd, 0.0) / radius) ** power


def ss(a, b, v):
    t = np.clip((v - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def mix(a, b, t):
    t = np.asarray(t)
    if t.ndim == 2:
        t = t[..., None]
    return a * (1 - t) + b * t


# --- shapes (signed distance, in the -1..1 square) --------------------------------------------

def circle(cx, cy, r, px=None, py=None):
    px = x if px is None else px
    py = y if py is None else py
    return np.hypot(px - cx, py - cy) - r


def ellipse(cx, cy, rx, ry, px=None, py=None):
    px = x if px is None else px
    py = y if py is None else py
    return (np.hypot((px - cx) / rx, (py - cy) / ry) - 1.0) * min(rx, ry)


def segment(ax, ay, bx, by, px=None, py=None):
    px = x if px is None else px
    py = y if py is None else py
    dx, dy = bx - ax, by - ay
    t = np.clip(((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy + 1e-9), 0, 1)
    return np.hypot(px - ax - dx * t, py - ay - dy * t)


def polyline(pts, px=None, py=None):
    d = None
    for i in range(len(pts) - 1):
        s = segment(pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1], px, py)
        d = s if d is None else np.minimum(d, s)
    return d


def box(cx, cy, hx, hy, px=None, py=None):
    px = x if px is None else px
    py = y if py is None else py
    qx = np.abs(px - cx) - hx
    qy = np.abs(py - cy) - hy
    return np.hypot(np.maximum(qx, 0), np.maximum(qy, 0)) + np.minimum(np.maximum(qx, qy), 0)


def stadium(cx, cy, hx, hy, px=None, py=None):
    """A rounded bar: half-extents hx > hy, fully round ends."""
    px = x if px is None else px
    py = y if py is None else py
    qx = np.maximum(np.abs(px - cx) - (hx - hy), 0)
    return np.hypot(qx, py - cy) - hy


def rot(cx, cy, ang, px=None, py=None):
    """Local (u, v) coordinates about (cx, cy), u along angle ang."""
    px = x if px is None else px
    py = y if py is None else py
    c, s = np.cos(ang), np.sin(ang)
    dx, dy = px - cx, py - cy
    return dx * c + dy * s, -dx * s + dy * c


# --- compositing ------------------------------------------------------------------------------

def over(img, col, a):
    a = np.clip(a, 0, 1)[..., None]
    return img * (1 - a) + np.asarray(col) * a


def add(img, col, a):
    return img + np.asarray(col) * np.asarray(a)[..., None]


def bevel(sd, width, relief=0.9, light=(-0.55, -0.65), shine=24.0):
    """Pseudo-3D from a mask's distance field: (diffuse 0..1, specular 0..1, height 0..1)."""
    h = np.clip(-sd / width, 0, 1)
    h = h * (2 - h)
    h = blur(h, 0.8)
    gy, gx = np.gradient(h)
    k = width * N / 2.0 * relief
    nx, ny = -gx * k, -gy * k
    nz_ = 1.0 / np.sqrt(nx * nx + ny * ny + 1.0)
    nx, ny = nx * nz_, ny * nz_
    lx, ly = light
    lz = 0.62
    ln = np.sqrt(lx * lx + ly * ly + lz * lz)
    d = np.clip((nx * lx + ny * ly + nz_ * lz) / ln, 0, 1)
    hv = np.array([lx, ly, lz + 0.8]) / np.linalg.norm([lx, ly, lz + 0.8])
    sp = np.clip(nx * hv[0] + ny * hv[1] + nz_ * hv[2], 0, 1) ** shine
    return d, sp, h


def sparks(n, seed, region, size=(0.004, 0.012), halo=2.6):
    """Scattered glowing points. region = (x0, y0, x1, y1)."""
    rng = np.random.default_rng(seed)
    out = np.zeros((N, N))
    for _ in range(n):
        cx = rng.uniform(region[0], region[2])
        cy = rng.uniform(region[1], region[3])
        r = rng.uniform(*size)
        d = np.hypot(x - cx, y - cy)
        out += np.exp(-(d / r) ** 2) * rng.uniform(0.5, 1.0) + 0.18 * np.exp(-d / (r * halo * 2.2)) * rng.uniform(0.3, 1)
    return out


def stars(seed, n=60, bright=0.8):
    rng = np.random.default_rng(seed)
    out = np.zeros((N, N))
    for _ in range(n):
        cx, cy = rng.uniform(-1, 1, 2)
        r = rng.uniform(0.003, 0.008)
        out += np.exp(-(np.hypot(x - cx, y - cy) / r) ** 2) * rng.uniform(0.2, 1) * bright
    return out


def backdrop(top, bottom, seed=0, cloud=None, cloud_amt=0.25, scale=3.0, centre=(0.0, 0.0), centre_col=None, centre_r=0.8):
    """Painted ground: vertical gradient, soft cloud mottling, an optional light pool."""
    t = ss(-1, 1, y)
    img = mix(np.asarray(top), np.asarray(bottom), t)
    if cloud is not None:
        c = nz(scale, seed, octaves=5)
        c2 = nz(scale * 2.3, seed + 3, octaves=3)
        img = img + np.asarray(cloud) * (ss(0.35, 0.8, c * 0.7 + c2 * 0.3) * cloud_amt)[..., None]
    if centre_col is not None:
        d = np.hypot(x - centre[0], y - centre[1])
        img = img + np.asarray(centre_col) * (np.exp(-(d / centre_r) ** 2))[..., None]
    return img


# --- the painted finish -----------------------------------------------------------------------

def finish(img, seed=0, vignette=0.62, bloom=0.5, grade=(1.0, 0.97, 1.02), exposure=1.5):
    img = np.maximum(img, 0)
    glowing = np.maximum(img - 0.6, 0)
    img = img + blur(glowing, 7) * bloom + blur(glowing, 18) * bloom * 0.8
    tex = nz(110, seed + 5, octaves=3) * 0.5 + nz(34, seed + 6, octaves=2) * 0.5
    streak = fbm(x * 9 + y * 2.0, y * 150 + x * 10, seed + 7, 3)
    img = img * (0.93 + 0.14 * tex[..., None]) * (0.96 + 0.08 * streak[..., None])
    img = 1.0 - np.exp(-img * exposure)
    img = img * np.asarray(grade)
    r = np.hypot(x * 0.92, y * 0.92)
    v = 1.0 - vignette * ss(0.55, 1.35, r) ** 1.3
    edge = ss(0.84, 1.0, np.maximum(np.abs(x), np.abs(y)))
    img = img * v[..., None] * (1 - 0.55 * edge[..., None])
    img = img + (nz(300, seed + 9, octaves=1) - 0.5)[..., None] * 0.03
    return np.clip(img, 0, 1)


def save_png(path, img):
    a = (np.clip(img, 0, 1) * 255 + 0.5).astype(np.uint8)
    h, w, _ = a.shape
    raw = b"".join(b"\x00" + a[i].tobytes() for i in range(h))

    def chunk(t, d):
        c = struct.pack(">I", len(d)) + t + d
        return c + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)) \
        + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


def save_png_rgba(path, rgba, size=64):
    """RGBA out, box-filtered down to size x size (premultiplied, so the medallion's edge stays clean)."""
    k = rgba.shape[0] // size
    a = np.clip(rgba[..., 3], 0, 1)
    pre = np.clip(rgba[..., :3], 0, 1) * a[..., None]
    if k > 1:
        pre = pre.reshape(size, k, size, k, 3).mean(axis=(1, 3))
        a = a.reshape(size, k, size, k).mean(axis=(1, 3))
    rgb = np.where(a[..., None] > 1e-4, pre / np.maximum(a[..., None], 1e-4), 0.0)
    out = (np.dstack([np.clip(rgb, 0, 1), a]) * 255 + 0.5).astype(np.uint8)
    h, w, _ = out.shape
    raw = b"".join(b"\x00" + out[i].tobytes() for i in range(h))

    def chunk(t, d):
        c = struct.pack(">I", len(d)) + t + d
        return c + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)) \
        + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)
