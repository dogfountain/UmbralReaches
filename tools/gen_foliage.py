"""Alpha-cutout foliage cards for Umbral Reaches: grass, fern, leaf clusters (RGBA, premultiplied-free).
Usage: python3 tools/gen_foliage.py"""
import math, os, random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), '..', 'art', 'textures')
R = random.Random(7)

def lerp(a, b, t): return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))

def grass(size=512):
    im = Image.new('RGBA', (size, size), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    base, tip = (16, 38, 34), (88, 170, 134)
    tip_glow = (160, 220, 198)        # cool highlight catching light down a blade's centerline
    violet_tip = (126, 112, 196)      # a minority of blades lean toward the gloom's violet cast
    for _ in range(140):
        x0 = R.uniform(0.04, 0.96) * size; h = R.uniform(0.38, 1.0) * size; w = R.uniform(2.2, 10)
        bend = R.uniform(-0.45, 0.45) * size; steps = 22
        left, right = [], []
        for s in range(steps + 1):
            t = s / steps
            x = x0 + bend * t * t; y = size - t * h; ww = w * (1 - t) ** 0.85
            left.append((x - ww, y)); right.append((x + ww, y))
        tip_c = violet_tip if R.random() < 0.16 else tip
        col = lerp(base, tip_c, R.uniform(0.3, 1.0)) + (255,)
        d.polygon(left + right[::-1], fill=col)
        # a thin brighter centerline on about half the blades -- catches light, breaks up flatness
        if R.random() < 0.5:
            centerline = [((lp[0] + rp[0]) / 2, lp[1]) for lp, rp in zip(left, right)]
            glow_col = lerp(col[:3], tip_glow, 0.6) + (170,)
            d.line(centerline, fill=glow_col, width=max(1, int(w * 0.18)))
    # vertical gradient: dark roots so the clump grounds itself
    a = np.asarray(im).astype(np.float32)
    shade = 0.35 + 0.65 * (1 - np.linspace(0, 1, size)[::-1][:, None])
    a[..., :3] *= shade
    Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)).save(os.path.join(OUT, 'grass_card.png'))

def fern(size=512):
    im = Image.new('RGBA', (size, size), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    stem = [(size * 0.5 + math.sin(t * 2.2) * size * 0.08 * t, size - t * size * 0.95) for t in np.linspace(0, 1, 56)]
    d.line(stem, fill=(20, 60, 45, 255), width=5)
    for i in range(1, 54):
        x, y = stem[i]; t = i / 56
        L = size * 0.34 * math.sin(math.pi * min(1, t * 1.1)) * (1 - t * 0.55)
        for side in (-1, 1):
            ang = math.radians(22 + 34 * t)
            ex, ey = x + side * L * math.cos(ang), y - L * math.sin(ang) * 0.5
            col = lerp((28, 80, 60), (80, 190, 130), R.uniform(0.4, 1.0)) + (255,)
            mx, my = (x + ex) / 2, (y + ey) / 2; nx, ny = -(ey - y), (ex - x); n = math.hypot(nx, ny) + 1e-6
            wv = 0.14 * L
            notch = 0.55
            d.polygon([
                (x, y),
                (mx + nx / n * wv, my + ny / n * wv),
                ((x * (1 - notch) + ex * notch) + nx / n * wv * 0.35, (y * (1 - notch) + ey * notch) + ny / n * wv * 0.35),
                (ex, ey),
                ((x * (1 - notch) + ex * notch) - nx / n * wv * 0.35, (y * (1 - notch) + ey * notch) - ny / n * wv * 0.35),
                (mx - nx / n * wv, my - ny / n * wv),
            ], fill=col)
            if R.random() < 0.55:
                d.line([(x, y), (ex, ey)], fill=lerp(col[:3], (16, 40, 32), 0.45) + (220,), width=1)
    im.save(os.path.join(OUT, 'fern_card.png'))

def _leaf_poly(d, cx, cy, length, width, ang, dark, mid, lit):
    ca, sa = math.cos(ang), math.sin(ang)
    def rot(x, y):
        return (cx + x * ca - y * sa, cy + x * sa + y * ca)
    pts = [
        rot(length, 0.0),
        rot(length * 0.62, width * 0.72),
        rot(length * 0.22, width),
        rot(-length * 0.12, 0.0),
        rot(length * 0.22, -width),
        rot(length * 0.62, -width * 0.72),
    ]
    col = lerp(dark, lit if R.random() < 0.22 else mid, R.uniform(0.55, 1.0)) + (255,)
    d.polygon(pts, fill=col)
    vein = lerp(col[:3], dark, 0.55) + (255,)
    d.line([rot(-length * 0.08, 0.0), rot(length * 0.92, 0.0)], fill=vein, width=1)
    if R.random() < 0.6:
        side_v = lerp(col[:3], dark, 0.35) + (200,)
        d.line([rot(length * 0.15, 0.0), rot(length * 0.55, width * 0.55)], fill=side_v, width=1)
        d.line([rot(length * 0.15, 0.0), rot(length * 0.55, -width * 0.55)], fill=side_v, width=1)


def leaves(size=1024):
    # Branch skeleton first, then dense leaf clusters along twigs — silhouette reads as a canopy card.
    im = Image.new('RGBA', (size, size), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    dark, mid, lit = (10, 24, 22), (24, 68, 52), (62, 132, 100)
    bark = (18, 14, 16)
    bark_lit = (42, 38, 48)
    cx0 = cy0 = size * 0.52
    # Primary + secondary branches from a trunk stub at the bottom-centre.
    trunk = [(cx0, size * 0.92)]
    tips = []
    for bi in range(7):
        ang = -math.pi * 0.5 + R.uniform(-0.85, 0.85)
        x, y = trunk[0]
        segs = R.randint(5, 8)
        path = [(x, y)]
        for s in range(segs):
            t = (s + 1) / segs
            step = size * R.uniform(0.045, 0.078)
            ang += R.uniform(-0.28, 0.28)
            x += math.cos(ang) * step
            y += math.sin(ang) * step * (0.85 + 0.2 * t)
            path.append((x, y))
        tips.append(path[-1])
        for i in range(len(path) - 1):
            w = max(2, int(7 * (1 - i / len(path))))
            d.line([path[i], path[i + 1]], fill=bark + (255,), width=w)
            if R.random() < 0.35:
                d.line([path[i], path[i + 1]], fill=bark_lit + (180,), width=max(1, w - 2))
        # Twigs off the primary.
        for _ in range(R.randint(3, 6)):
            si = R.randint(1, len(path) - 1)
            bx, by = path[si]
            ta = ang + R.uniform(-1.1, 1.1)
            tw = [(bx, by)]
            for _k in range(R.randint(3, 5)):
                bx += math.cos(ta) * size * R.uniform(0.02, 0.038)
                by += math.sin(ta) * size * R.uniform(0.02, 0.038)
                ta += R.uniform(-0.35, 0.35)
                tw.append((bx, by))
            tips.append(tw[-1])
            for i in range(len(tw) - 1):
                d.line([tw[i], tw[i + 1]], fill=bark + (255,), width=max(1, 3 - i))
    # Leaf clusters weighted toward tips and along the crown.
    for _ in range(820):
        if R.random() < 0.55 and tips:
            tx, ty = tips[R.randint(0, len(tips) - 1)]
            cx = tx + R.uniform(-size * 0.04, size * 0.04)
            cy = ty + R.uniform(-size * 0.04, size * 0.04)
        else:
            rad = R.uniform(0.0, size * 0.36)
            ang = R.uniform(0, math.tau)
            cx = cx0 + math.cos(ang) * rad
            cy = cy0 - size * 0.08 + math.sin(ang) * rad * 0.85
        length = R.uniform(18, 54)
        width = length * R.uniform(0.24, 0.42)
        a = R.uniform(0, math.tau)
        _leaf_poly(d, cx, cy, length, width, a, dark, mid, lit)
    im.save(os.path.join(OUT, 'leaves_card.png'))


def branch_card(size=512):
    # Bare twig silhouette for dead-branch scatter / canopy under-structure.
    im = Image.new('RGBA', (size, size), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    bark = (52, 48, 62)
    bark_hi = (88, 96, 120)
    cx, cy = size * 0.5, size * 0.94
    for _ in range(7):
        ang = -math.pi * 0.5 + R.uniform(-0.85, 0.85)
        x, y = cx + R.uniform(-size * 0.1, size * 0.1), cy
        for s in range(R.randint(7, 12)):
            nx = x + math.cos(ang) * size * R.uniform(0.045, 0.085)
            ny = y + math.sin(ang) * size * R.uniform(0.045, 0.085)
            w = max(2, int(7 * (1 - s / 12)))
            d.line([(x, y), (nx, ny)], fill=bark + (255,), width=w)
            d.line([(x, y), (nx, ny)], fill=bark_hi + (200,), width=max(1, w - 2))
            if R.random() < 0.55:
                sa = ang + R.choice([-1, 1]) * R.uniform(0.55, 1.25)
                sx, sy = nx, ny
                for k in range(4):
                    sx2 = sx + math.cos(sa) * size * 0.04
                    sy2 = sy + math.sin(sa) * size * 0.04
                    d.line([(sx, sy), (sx2, sy2)], fill=bark + (255,), width=max(1, 3 - k))
                    sx, sy = sx2, sy2
                    sa += R.uniform(-0.35, 0.35)
            x, y = nx, ny
            ang += R.uniform(-0.28, 0.28)
    im.save(os.path.join(OUT, 'branch_card.png'))


def moss_hang(size=512):
    # Hanging moss tendrils — vertical strands with soft tips for trunk dressing.
    im = Image.new('RGBA', (size, size), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    base, tip = (10, 28, 22), (36, 88, 62)
    tip_glow = (70, 140, 110)
    for _ in range(48):
        x0 = R.uniform(0.08, 0.92) * size
        h = R.uniform(0.35, 0.95) * size
        w = R.uniform(1.4, 4.5)
        bend = R.uniform(-0.12, 0.12) * size
        steps = 18
        left, right = [], []
        for s in range(steps + 1):
            t = s / steps
            x = x0 + bend * t * t
            y = t * h
            ww = w * (1.0 - t * 0.7)
            left.append((x - ww, y)); right.append((x + ww, y))
        col = lerp(base, tip, R.uniform(0.35, 1.0)) + (255,)
        d.polygon(left + right[::-1], fill=col)
        if R.random() < 0.4:
            mid = [((lp[0] + rp[0]) * 0.5, lp[1]) for lp, rp in zip(left, right)]
            d.line(mid, fill=lerp(col[:3], tip_glow, 0.5) + (150,), width=1)
    im.save(os.path.join(OUT, 'moss_hang.png'))

def bark_giant(size=1024):
    rng = np.random.default_rng(3)
    y, x = np.mgrid[0:size, 0:size].astype(np.float32) / size
    def vn(nx, ny):
        g = rng.random((ny, nx)); u, v = x * nx, y * ny; i, j = np.floor(u).astype(int), np.floor(v).astype(int)
        fu, fv = u - i, v - j; fu, fv = fu*fu*(3-2*fu), fv*fv*(3-2*fv)
        a=g[j%ny,i%nx]; b=g[j%ny,(i+1)%nx]; c=g[(j+1)%ny,i%nx]; e=g[(j+1)%ny,(i+1)%nx]
        return (a*(1-fu)+b*fu)*(1-fv)+(c*(1-fu)+e*fu)*fv
    warp = vn(6, 3) * 0.08
    ridges = np.abs(np.sin((x + warp) * math.pi * 26 + vn(4, 2) * 3.0))
    ridges = ridges ** 0.45
    plates = vn(30, 6) * 0.5 + vn(60, 12) * 0.25
    h = ridges * 0.75 + plates * 0.25
    moss = np.clip((vn(5, 5) - 0.5) * 4.2, 0, 1) * (1 - ridges * 0.45)
    lum = 0.09 + h * 0.34
    col = np.dstack([lum * 0.88, lum * 0.92, lum * 1.02])
    col = col * (1 - moss[..., None]) + moss[..., None] * np.array([0.08, 0.20, 0.16])
    Image.fromarray((np.clip(col, 0, 1) * 255).astype(np.uint8)).save(os.path.join(OUT, 'bark_giant_albedo.png'))
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 7.5; dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 7.5
    n = np.dstack([-dx, dy, np.ones_like(h)]); n /= np.linalg.norm(n, axis=2, keepdims=True)
    Image.fromarray(((n * 0.5 + 0.5) * 255).astype(np.uint8)).save(os.path.join(OUT, 'bark_giant_normal.png'))

if __name__ == '__main__':
    grass(); fern(); leaves(); branch_card(); moss_hang(); bark_giant(); print('foliage textures written')
