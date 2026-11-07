"""Learned spell icons: tether, well, familiar, peal."""
import numpy as np

from paint import *  # noqa: F401,F403
from registry import recipe

C = hex_rgb


def metal(sd, width, dark, light, spec, glowc=None, glowamt=0.0, lightdir=(-0.55, -0.65)):
    d, sp, h = bevel(sd, width, light=lightdir)
    col = mix(np.asarray(dark), np.asarray(light), d) + np.asarray(spec) * sp[..., None] * 0.9
    if glowc is not None:
        col = col + np.asarray(glowc) * (glowamt * (1 - h))[..., None]
    return col


@recipe("spell", "tether")
def tether():
    img = backdrop(C("#03090c"), C("#071c1d"), 70, cloud=C("#0f5a58"), cloud_amt=0.55, scale=2.4,
                   centre=(0.55, -0.55), centre_col=C("#2ad0c0") * 0.7, centre_r=0.65)
    img = add(img, C("#9ff5e8"), stars(8, 30, 0.35))
    # the rift at the far end: a swirling teal eye the chain is hauled into
    rc = (0.58, -0.58)
    r = np.hypot(x - rc[0], y - rc[1])
    a = np.arctan2(y - rc[1], x - rc[0])
    sw = nz(4, 71, px=r * np.cos(a + r * 7) * 2 + 3, py=r * np.sin(a + r * 7) * 2 + 3)
    img = add(img, C("#27d6c4"), np.exp(-r / 0.2) * 0.9)
    img = over(img, mix(C("#021a1a"), C("#8ff7e8"), np.clip(sw * 1.6 - 0.35 + (1 - r / 0.3) * 0.5, 0, 1)), smooth(r - 0.27))
    img = add(img, C("#e8fffa"), np.exp(-np.abs(r - 0.27) / 0.014) * 0.9)
    # chain along the diagonal, links alternating face-on and edge-on
    ang = -np.pi / 4
    cx0, cy0 = -0.62, 0.62
    step_ = 0.215
    for k in range(7):
        cx = cx0 + k * step_ * np.cos(ang)
        cy = cy0 + k * step_ * np.sin(ang)
        u, v = rot(cx, cy, ang)
        if k % 2 == 0:
            sd = np.abs(stadium(0, 0, 0.17, 0.095, u, v)) - 0.03
        else:
            sd = stadium(0, 0, 0.17, 0.03, u, v)
        dd = metal(sd, 0.035, C("#06201e"), C("#3c8f88"), C("#c8fff6"), C("#27d6c4"), 0.35)
        img = add(img, C("#27d6c4"), np.exp(-np.maximum(sd, 0) / 0.05) * 0.35)
        img = over(img, dd, smooth(sd))
    # energy running through the chain
    d = segment(cx0, cy0, rc[0], rc[1])
    img = add(img, C("#6ff0e0"), np.exp(-d / 0.02) * 0.3 * (0.6 + 0.8 * nz(9, 72)))
    # the hook at the near end
    hu, hv = rot(-0.74, 0.74, ang)
    hook = np.abs(circle(-0.74, 0.74, 0.0)) * 0
    hsd = np.abs(circle(-0.84, 0.64, 0.13)) - 0.034
    hsd = np.where(((x + 0.84) > 0.02) | ((y - 0.64) < -0.0), hsd, 9.0)
    img = over(img, metal(hsd, 0.036, C("#06201e"), C("#4aa59c"), C("#d8fff8")), smooth(hsd))
    img = add(img, C("#8ff7e8"), sparks(40, 73, (-0.9, -0.9, 0.9, 0.9), (0.003, 0.008)) * 0.8)
    return finish(img, 7, grade=(0.95, 1.03, 1.02))


@recipe("spell", "well")
def well():
    img = backdrop(C("#05030c"), C("#0d0620"), 80, cloud=C("#2a1566"), cloud_amt=0.45, scale=2.2)
    r = np.hypot(x, y)
    a = np.arctan2(y, x)
    ro, ri = 0.84, 0.42
    # the stone kerb, bricks by angular + radial cells
    cell_a = a * 9 / (2 * np.pi) * 2
    row = np.floor((r - ri) / 0.14)
    off = (row % 2) * 0.5
    fa = (cell_a + off) % 1.0
    fr = ((r - ri) / 0.14) % 1.0
    mortar = np.maximum(ss(0.9, 1.0, fa) + ss(0.1, 0.0, fa), ss(0.9, 1.0, fr) + ss(0.1, 0.0, fr))
    brick_id = np.floor(cell_a + off) * 7.3 + row * 3.1
    tone = 0.55 + 0.45 * _hash2(brick_id)
    ring_sd = np.maximum(r - ro, ri - r)
    d, sp, h = bevel(ring_sd, 0.12, light=(-0.5, -0.6), relief=0.6)
    lit_in = np.exp(-(r - ri) / 0.3)  # lit from the hole's glow
    stone = C("#2b2635") * (0.5 + 0.9 * tone[..., None]) * (0.5 + 0.9 * d[..., None])
    stone = stone * (1 - 0.65 * np.clip(mortar, 0, 1)[..., None]) * (0.8 + 0.4 * nz(40, 81)[..., None])
    stone = stone + C("#8a5cff") * (lit_in * 0.75 * (1 - 0.7 * np.clip(mortar, 0, 1)))[..., None]
    img = over(img, stone, smooth(ring_sd))
    img = add(img, C("#6a3cff"), np.exp(-np.maximum(r - ro, 0) / 0.08) * 0.35)
    # the shaft: a spiral falling down to a bright violet floor
    sp_ = fbm(a * 2.0 + r * 9.0 + 3, r * 4.0, 82, 3)
    spiral = 0.5 + 0.5 * np.sin(a * 3 - r * 17)
    depth = np.clip(r / ri, 0, 1)
    hole = mix(C("#020006"), C("#4a1fc8"), np.clip(spiral * (0.3 + 0.8 * depth ** 1.5) * sp_ * 1.6, 0, 1))
    hole = hole + C("#a98bff") * (np.exp(-r / 0.07) * 0.9)[..., None]
    hole = hole * (0.55 + 0.65 * ss(0.0, 0.2, r))[..., None]
    img = over(img, hole, smooth(r - ri + 0.01))
    img = add(img, C("#caa8ff"), np.exp(-np.abs(r - ri + 0.01) / 0.012) * 0.55)
    # wisps rising out of it, and motes
    for k in range(5):
        t = np.linspace(0, 1, 12)
        ph = k * 1.3
        pts = [(0.06 * np.sin(ph + s * 4) * (1 + 3 * s) + (k - 2) * 0.08, 0.1 - s * 0.9) for s in t]
        dd = polyline(pts)
        img = add(img, C("#b79bff"), np.exp(-dd / 0.025) * 0.28 * ss(1, 0.1, t[0] + 0.0))
    img = add(img, C("#cdb8ff"), sparks(34, 83, (-0.5, -0.9, 0.5, 0.5), (0.003, 0.008)) * 0.8)
    return finish(img, 8, grade=(1.0, 0.95, 1.06))


def _hash2(a):
    return (np.sin(a * 12.9898) * 43758.5453) % 1.0


@recipe("spell", "familiar")
def familiar():
    img = backdrop(C("#06060f"), C("#14102a"), 90, cloud=C("#40308a"), cloud_amt=0.55, scale=2.3,
                   centre=(0.0, -0.15), centre_col=C("#6a58d0") * 0.6, centre_r=0.6)
    img = add(img, C("#e0d8ff"), stars(9, 45, 0.5))
    wx, wy = warp(0.025, 4, 92)
    # hooded wisp: dome head, a cloak that tapers into a curling tail
    head = circle(0.0, -0.2, 0.36, wx, wy)
    tail_x = 0.05 * np.sin((y + 0.8) * 5) + 0.35 * np.clip((y - 0.25), 0, 2) ** 1.6
    wid = 0.36 * (1 - ss(0.0, 0.95, y)) ** 0.9 + 0.02
    cloak = np.maximum(np.abs(wx - tail_x * 0.8) - wid, np.maximum(-0.2 - y, y - 0.85))
    cloak = np.where(wy > -0.2, cloak, 9.0)
    body = np.minimum(head, cloak)
    d, sp, h = bevel(body, 0.3, relief=0.7)
    edge = 1 - ss(0.0, 0.8, h)  # fresnel: bright rim, translucent middle
    inner = mix(C("#2b2470"), C("#7e6de0"), np.clip(1 - np.hypot(x, y + 0.2) / 0.7, 0, 1))
    shade = inner * 0.9 + C("#e0d6ff") * (edge * 0.9 + 0.2)[..., None] + C("#ffffff") * sp[..., None] * 0.3
    img = add(img, C("#8a78ff"), np.exp(-np.maximum(body, 0) / 0.1) * 0.45)
    img = over(img, shade, smooth(body) * (0.82 + 0.18 * nz(8, 93)))
    # the hood's void and two eyes
    face = ellipse(0.0, -0.17, 0.2, 0.22, wx, wy)
    img = over(img, C("#050310"), smooth(face))
    img = add(img, C("#6a58d0"), np.exp(-np.abs(face) / 0.02) * 0.35)
    for ex in (-0.085, 0.085):
        e = np.hypot(x - ex, (y + 0.15) * 0.7) - 0.03
        img = add(img, C("#cfc4ff"), np.exp(-np.maximum(e, 0) / 0.04) * 0.9)
        img = over(img, C("#ffffff"), smooth(e))
    # trailing wisps
    for k in range(3):
        pts = [(0.25 + 0.05 * k + 0.1 * np.sin(t * 5 + k), 0.2 + t * 0.65) for t in np.linspace(0, 1, 10)]
        dd = polyline(pts)
        img = add(img, C("#a99cff"), np.exp(-dd / 0.02) * 0.4 * ss(1.0, 0.0, y * 0.7))
    img = add(img, C("#cfc4ff"), sparks(30, 94, (-0.8, -0.9, 0.8, 0.9), (0.003, 0.008)) * 0.8)
    return finish(img, 9, grade=(1.0, 0.97, 1.05))


@recipe("spell", "peal")
def peal():
    img = backdrop(C("#0c0805"), C("#241608"), 100, cloud=C("#5a3a16"), cloud_amt=0.5, scale=2.2,
                   centre=(0.0, 0.0), centre_col=C("#c4801a") * 0.7, centre_r=0.7)
    img = add(img, C("#ffe0a0"), stars(10, 25, 0.35))
    # sound rings going out either side
    ctr = (0.0, 0.1)
    rr = np.hypot(x - ctr[0], y - ctr[1])
    ang = np.arctan2(y - ctr[1], x - ctr[0])
    side = ss(0.75, 0.2, np.abs(np.sin(ang)))
    for k, rad in enumerate((0.62, 0.78, 0.94)):
        w = rad + (nz(5, 101 + k, px=ang * 2 + 5, py=k * 3.0) - 0.5) * 0.025
        img = add(img, C("#ffc766"), np.exp(-np.abs(rr - w) / 0.016) * side * (0.9 - 0.25 * k))
    # the bell: profile half-width by height
    t = np.clip((y + 0.52) / 0.98, 0, 1)
    hw = 0.1 + 0.3 * ss(0.0, 0.7, t) ** 0.8 + 0.12 * ss(0.8, 1.0, t) ** 2
    sd = np.maximum(np.abs(x) - hw, np.maximum(-0.52 - y, y - 0.46))
    nx = np.clip(x / (hw + 1e-6), -1, 1)
    cyl = np.sqrt(1 - nx * nx)
    light = np.clip(0.45 - nx * 0.9, 0, 1) * 0.8 + 0.2
    bronze = mix(C("#3a1c06"), C("#d99a3a"), np.clip(light * (0.45 + 0.6 * cyl), 0, 1))
    bronze = bronze + C("#fff0b8") * (np.exp(-((nx + 0.42) / 0.09) ** 2) * (0.7 + 0.3 * cyl))[..., None] * 0.85
    bronze = bronze + C("#ff9a3a") * (np.exp(-((nx - 0.72) / 0.14) ** 2) * 0.35)[..., None]
    for by in (0.15, 0.23, 0.38):
        band = np.exp(-((y - by) / 0.012) ** 2)
        bronze = bronze * (1 - 0.55 * band[..., None]) + C("#ffd27a") * (np.exp(-((y - by + 0.025) / 0.01) ** 2) * 0.35)[..., None]
    bronze = bronze * (0.85 + 0.3 * nz(60, 102)[..., None])
    img = add(img, C("#ffb44a"), np.exp(-np.maximum(sd, 0) / 0.1) * 0.4)
    img = over(img, bronze, smooth(sd))
    # lip shadow, clapper, crown loop and yoke
    lip = np.abs(y - 0.46) < 0.018
    img = add(img, C("#ffe9b0"), np.exp(-np.abs(sd) / 0.012) * 0.3)
    clap = circle(0.0, 0.54, 0.075)
    img = over(img, metal(clap, 0.075, C("#2a1204"), C("#c98a30"), C("#fff0c0")), smooth(clap))
    loop = np.abs(circle(0.0, -0.66, 0.1)) - 0.03
    img = over(img, metal(loop, 0.03, C("#2a1204"), C("#d09838"), C("#fff0c0")), smooth(loop))
    beam = box(0.0, -0.8, 0.5, 0.035)
    img = over(img, metal(beam, 0.035, C("#1a0e06"), C("#6a4420"), C("#c8a070")), smooth(beam))
    img = add(img, C("#ffd28a"), sparks(30, 103, (-0.8, -0.8, 0.8, 0.8), (0.003, 0.008)) * 0.75)
    return finish(img, 10, grade=(1.06, 0.98, 0.9))
