"""Spell icon recipes: one function per icon, registered as ("spell", id)."""
import numpy as np

from paint import *  # noqa: F401,F403
from registry import recipe

C = hex_rgb


def jag(p0, p1, n, amp, seed):
    """A jagged lightning path from p0 to p1."""
    rng = np.random.default_rng(seed)
    pts = [p0]
    d = np.array(p1) - np.array(p0)
    nrm = np.array([-d[1], d[0]]) / (np.linalg.norm(d) + 1e-9)
    for i in range(1, n):
        t = i / n
        pts.append(tuple(np.array(p0) + d * t + nrm * rng.uniform(-amp, amp) * (1 - 0.3 * t)))
    pts.append(p1)
    return pts


@recipe("spell", "bolt")
def bolt():
    img = backdrop(C("#0b0818"), C("#1c1236"), 3, cloud=C("#3a2670"), cloud_amt=0.55, scale=2.6,
                   centre=(0.3, -0.25), centre_col=C("#4b2a9a") * 0.6, centre_r=0.7)
    img = add(img, C("#cdbfff"), stars(5, 40, 0.45))
    head = (0.34, -0.3)
    wx, wy = warp(0.03, 5, 4)
    for k, (w, col, amp) in enumerate([(0.07, "#5a36d6", 0.1), (0.032, "#a98bff", 0.07), (0.014, "#efe6ff", 0.05)]):
        d = polyline(jag((-0.82, 0.78), head, 7, amp, 12 + k), wx, wy)
        img = add(img, C(col), np.exp(-d / (w * 2.2)) * 0.5 / (1 + k * 0.2))
        img = add(img, C(col), smooth(d - w * 0.4) * (0.4 + 0.3 * k))
    for s in range(3):
        a = jag((-0.35 - s * 0.1, 0.35 + s * 0.12), (-0.65 - s * 0.1, 0.05 + s * 0.05), 4, 0.07, 40 + s)
        d = polyline(a, wx, wy)
        img = add(img, C("#b8a0ff"), np.exp(-d / 0.03) * 0.55)
    # the orb: layered radial light, swirling inner texture, rim
    dist = np.hypot(x - head[0], y - head[1])
    img = add(img, C("#6a42f0"), np.exp(-dist / 0.18) * 0.9)
    r = 0.2
    sw = nz(7, 8, px=(x - head[0]) * 1.4 + (y - head[1]) * 0.6, py=(y - head[1]) * 1.4 - (x - head[0]) * 0.6)
    body = smooth(dist - r)
    sph = np.sqrt(np.clip(1 - (dist / r) ** 2, 0, 1))
    orb = mix(C("#3a1aa8"), C("#a98bff"), np.clip(sph * 0.9 + (sw - 0.5) * 0.9, 0, 1))
    orb = orb + C("#ffffff") * (np.exp(-np.hypot(x - head[0] + 0.03, y - head[1] + 0.04) / 0.035) * 0.9)[..., None]
    rim = ss(0.6, 1.0, dist / r) * body
    orb = orb + C("#9d7bff") * rim[..., None] * 0.7
    img = over(img, orb, body)
    ang = np.arctan2(y - head[1], x - head[0])
    spikes = (np.abs(np.cos(ang * 4 + 0.4)) ** 24) * np.exp(-dist / 0.22)
    img = add(img, C("#e5dcff"), spikes * 0.45)
    img = add(img, C("#c7b6ff"), sparks(26, 31, (-0.8, -0.8, 0.8, 0.8), (0.004, 0.009)) * 0.8)
    return finish(img, 1, grade=(1.02, 0.97, 1.05))


@recipe("spell", "lance")
def lance():
    img = backdrop(C("#0d0605"), C("#2a0d06"), 6, cloud=C("#4a1608"), cloud_amt=0.4, scale=2.2,
                   centre=(0.45, -0.5), centre_col=C("#a8340c") * 0.5, centre_r=0.6)
    ang = -np.pi / 4
    u, v = rot(-0.12, 0.12, ang)
    tip = 0.74
    # backwards fire stream
    wu = u + (nz(6, 9, px=u * 1.0, py=v * 2.0) - 0.5) * 0.25
    wv = v + (nz(5, 10, px=u * 1.4, py=v * 1.0) - 0.5) * 0.3 * ss(tip, -0.6, u)
    flame = np.exp(-(wv / (0.24 * (1 + 0.5 * ss(0.6, -0.8, u)))) ** 2) * ss(-0.95, tip - 0.1, u) * (nz(9, 11, px=wu * 1.2, py=wv * 3) * 0.6 + 0.5)
    img = add(img, C("#ff5a14"), flame * 1.6)
    core = np.exp(-(wv / 0.1) ** 2) * ss(-0.5, tip, u)
    img = add(img, C("#ffb04a"), core * 0.9)
    img = add(img, C("#fff0c0"), core ** 2 * 0.6)
    # steel shaft + leaf blade, lit by the flame from behind and the glow ahead
    bt = np.clip((u - 0.05) / (tip - 0.05), 0, 1)
    prof = np.where(bt < 0.3, 0.55 + 0.45 * bt / 0.3, ((1 - bt) / 0.7) ** 0.85)
    hw = np.where(u < 0.05, 0.046, 0.046 + 0.15 * prof * ss(0.0, 0.08, bt))
    hw = np.where(u > tip - 0.03, np.maximum(0, (tip - u)) * 1.2, hw)
    sd_ = np.maximum(np.abs(v) - hw, np.maximum(-0.9 - u, u - tip))
    m = smooth(sd_)
    d, sp, h = bevel(sd_, 0.045, light=(-0.6, -0.6))
    ridge = 1 - ss(0.0, 0.03, np.abs(v)) * (u > 0.28)
    heat = ss(0.0, tip, u)
    steel = mix(C("#2a2420"), C("#7d746a"), d) + C("#ffc890") * sp[..., None] * 0.9
    steel = steel + C("#ff6a20") * (heat ** 1.5 * (0.6 + 0.5 * h))[..., None] + C("#ffe9a8") * (ss(0.55, tip, u) ** 2)[..., None] * 0.8
    steel = steel + C("#ffb070") * (ridge * 0.25 * (u > 0.28))[..., None]
    img = over(img, steel, m)
    # binding cloth and ring
    for bu in (-0.25, -0.18, -0.11):
        bd = np.maximum(np.abs(u - bu) - 0.02, np.abs(v) - 0.05)
        img = over(img, C("#5a2c14") * (0.8 + 0.4 * nz(30, 3)[..., None]), smooth(bd))
    # tip bloom
    tu = np.hypot(u - tip, v)
    img = add(img, C("#ffc680"), np.exp(-tu / 0.07) * 0.9)
    img = add(img, C("#ff7a2a"), np.exp(-tu / 0.2) * 0.45)
    # embers
    img = add(img, C("#ffb14a"), sparks(46, 21, (-0.9, -0.2, 0.7, 0.9), (0.003, 0.008)) * 0.9)
    img = add(img, C("#ff7a2a"), sparks(24, 22, (-0.2, -0.9, 0.9, 0.3), (0.003, 0.007)) * 0.7)
    return finish(img, 2, grade=(1.05, 0.97, 0.94), exposure=1.45)


@recipe("spell", "nova")
def nova():
    img = backdrop(C("#06030d"), C("#14061f"), 12, cloud=C("#3d0f66"), cloud_amt=0.6, scale=2.4)
    r = np.hypot(x, y)
    a = np.arctan2(y, x)
    # radial rays: angular noise falling off with distance
    rays = nz(1, 14, px=np.cos(a) * 3.2 + 5, py=np.sin(a) * 3.2 + 5, octaves=3)
    rays2 = fbm(a * 5.0 + 7, r * 3.0, 15, 3)
    ray = ss(0.35, 0.8, rays * 0.6 + rays2 * 0.5) * np.exp(-r / 0.55)
    img = add(img, C("#a03af0"), ray * 1.5)
    # the shock ring, warped like a brushed stroke
    rw = r + (nz(4, 16, px=np.cos(a) * 1.3 + 3, py=np.sin(a) * 1.3 + 3) - 0.5) * 0.06
    for rad, wid, col, amt in [(0.58, 0.05, "#e98bff", 1.0), (0.78, 0.03, "#a24dff", 0.6), (0.38, 0.025, "#7a2cd0", 0.5)]:
        d = np.abs(rw - rad) - wid
        img = add(img, C(col), np.exp(-np.maximum(d, 0) / (wid * 2.8)) * amt * 0.7)
        img = add(img, C("#fff0ff"), smooth(d + wid * 0.5) * amt * 0.5)
    # dark heart: a void with a bright rim light
    vd = r - 0.27
    img = over(img, C("#03000a"), smooth(vd))
    rim = np.exp(-np.abs(vd) / 0.03)
    img = add(img, C("#d38dff"), rim * (0.5 + 0.5 * np.clip(-(x * 0.4 + y * 0.6) + 0.6, 0, 1)) * 0.95)
    img = add(img, C("#c04dff"), np.exp(-np.maximum(vd, 0) / 0.16) * 0.55 * (1 - smooth(vd)))
    # spike flares
    spk = (np.abs(np.cos(a * 4)) ** 40) * np.exp(-r / 0.5) * ss(0.25, 0.4, r)
    img = add(img, C("#f0c6ff"), spk * 0.5)
    img = add(img, C("#e5b0ff"), sparks(40, 33, (-0.9, -0.9, 0.9, 0.9), (0.003, 0.008)) * 0.7)
    return finish(img, 3, grade=(1.03, 0.94, 1.06), bloom=0.55)


@recipe("spell", "ward")
def ward():
    img = backdrop(C("#05070f"), C("#12100f"), 20, cloud=C("#3a2a16"), cloud_amt=0.3, scale=2.2,
                   centre=(0.0, -0.05), centre_col=C("#c46a12") * 0.85, centre_r=0.65)
    # warm ward-circle on the ground, an ellipse in perspective
    e = ellipse(0.0, 0.72, 0.8, 0.17)
    img = add(img, C("#ff9a2a"), np.exp(-np.abs(e) / 0.03) * 0.9)
    img = add(img, C("#ffe0a0"), smooth(np.abs(e) - 0.008) * 0.9)
    e2 = ellipse(0.0, 0.72, 0.62, 0.12)
    img = add(img, C("#e08a20"), np.exp(-np.abs(e2) / 0.02) * 0.45)
    ang = np.arctan2((y - 0.72) / 0.17, x / 0.8)
    ticks = (np.abs(np.sin(ang * 8)) > 0.97) * smooth(np.abs(e) - 0.06) * (np.abs(e) > 0.012)
    img = add(img, C("#ffcf70"), ticks * 0.6)
    img = add(img, C("#ffb347"), np.exp(-np.maximum(e, 0) / 0.12) * 0.25 * (y > 0.5))
    # lantern, iron frame
    iron = C("#2b1d14")
    lw, top, bot = 0.3, -0.2, 0.46
    body_sd = np.maximum(np.abs(x) - lw * (1 - 0.06 * ss(top, bot, y)), np.maximum(top - y, y - bot))
    # inside glow
    fl_c = (0.0, 0.14)
    fd = np.hypot((x - fl_c[0]) / 0.1, (y - fl_c[1]) / 0.22)
    glass = C("#ffb54a") * (0.7 + 0.8 * np.exp(-np.hypot(x, y - 0.12) / 0.3))[..., None]
    glass = glass + C("#fff1c0") * (np.exp(-fd ** 2) * 1.1)[..., None]
    img = over(img, glass, smooth(body_sd))
    flame_sd = (np.hypot(x / 0.11, (y - 0.17) / 0.24) - 1) * 0.1 + np.where(y < 0.17, np.abs(x) * (0.17 - y) * 0.6, 0)
    img = over(img, C("#fffbe0"), smooth(flame_sd) * 0.95)
    # bars
    for bx in (-lw, -lw / 3, lw / 3, lw):
        sd = np.maximum(np.abs(x - bx * (1 - 0.06 * ss(top, bot, y))) - 0.018, np.maximum(top - y - 0.01, y - bot - 0.01))
        dd, spp, _ = bevel(sd, 0.02)
        img = over(img, iron * (0.7 + 0.8 * dd[..., None]) + C("#ffa940") * (0.3 + 0.6 * np.exp(-np.abs(x - bx) / 0.2))[..., None] * 0.35 * dd[..., None], smooth(sd))
    for yy in (top, bot):
        sd = box(0, yy, lw + 0.03, 0.025)
        dd, spp, _ = bevel(sd, 0.025)
        img = over(img, iron * (0.7 + dd[..., None]) + C("#ffcf80") * spp[..., None] * 0.6, smooth(sd))
    # roof and base
    roof = np.maximum(np.abs(x) - (0.1 + (y - (-0.52)) / (top - (-0.52)) * (lw + 0.1 - 0.1)), np.maximum(-0.52 - y, y - top + 0.0))
    dd, spp, hh = bevel(roof, 0.05)
    img = over(img, iron * (0.5 + 1.0 * dd[..., None]) + C("#ffb060") * (spp * 0.8 + 0.25 * hh * ss(0.2, 0, y))[..., None], smooth(roof))
    base = box(0, bot + 0.07, lw * 0.82, 0.05)
    dd, spp, _ = bevel(base, 0.05)
    img = over(img, iron * (0.6 + dd[..., None]) + C("#ffc070") * spp[..., None] * 0.5, smooth(base))
    # handle ring
    ring = np.abs(circle(0, -0.66, 0.1)) - 0.018
    dd, spp, _ = bevel(ring, 0.02)
    img = over(img, iron * (0.7 + 1.3 * dd[..., None]) + C("#ffcf80") * spp[..., None] * 0.7, smooth(ring))
    # light spilling across the ward dome
    dome = np.abs(ellipse(0, 0.25, 0.78, 0.82)) - 0.012
    arc = smooth(dome) * (y < 0.55) * (np.abs(x) > 0.3)
    img = add(img, C("#ffc566"), arc * 0.45 * ss(0.55, 0.1, y))
    img = add(img, C("#ffd9a0"), sparks(34, 41, (-0.75, -0.7, 0.75, 0.65), (0.003, 0.007)) * 0.8)
    return finish(img, 4, grade=(1.06, 0.98, 0.9), exposure=1.5)


@recipe("spell", "step")
def step():
    img = backdrop(C("#04080f"), C("#0b1424"), 30, cloud=C("#18407a"), cloud_amt=0.5, scale=2.5,
                   centre=(0.35, 0.0), centre_col=C("#2060d0") * 0.6, centre_r=0.7)
    img = add(img, C("#bfd8ff"), stars(7, 40, 0.4))
    # motion streaks, leaning into the door
    rng = np.random.default_rng(50)
    for _ in range(26):
        yy = rng.uniform(-0.85, 0.85)
        x0 = rng.uniform(-1.0, -0.2)
        ln = rng.uniform(0.25, 0.7)
        d = segment(x0, yy, x0 + ln, yy * 0.88)
        w = rng.uniform(0.004, 0.011)
        fade = ss(x0, x0 + ln, x) * ss(0.2, -0.2, x)
        img = add(img, C("#7fa8ff"), np.exp(-d / w) * fade * rng.uniform(0.3, 0.9))
    # after-image chevrons
    for k, (ox, amt) in enumerate([(-0.52, 0.28), (-0.28, 0.5), (-0.04, 0.85)]):
        pts = [(ox - 0.14, -0.38), (ox + 0.1, 0.0), (ox - 0.14, 0.38)]
        d = polyline(pts) - 0.045
        dd, sp, _ = bevel(d, 0.05)
        img = add(img, C("#4a82ff"), np.exp(-np.maximum(d, 0) / 0.05) * amt * 0.55)
        img = over(img, mix(C("#2e56c8"), C("#bfdcff"), dd) , smooth(d) * amt)
    # the rift doorway: a bright oval, swirling depth
    px_, py_ = x - 0.46, y
    ed = ellipse(0.46, 0.0, 0.2, 0.62)
    ang = np.arctan2(py_ / 0.62, px_ / 0.2)
    rr = np.hypot(px_ / 0.2, py_ / 0.62)
    swirl = nz(3.2, 61, px=rr * np.cos(ang + rr * 3.2) * 1.4 + 4, py=rr * np.sin(ang + rr * 3.2) * 1.4 + 4)
    inner = mix(C("#0a1a4a"), C("#bfe0ff"), np.clip(swirl * 1.4 - 0.2 + (1 - rr) * 0.4, 0, 1))
    inner = inner + C("#ffffff") * (np.exp(-rr ** 2 * 5) * 0.55)[..., None]
    img = add(img, C("#4c8cff"), np.exp(-np.maximum(ed, 0) / 0.12) * 0.85)
    img = over(img, inner, smooth(ed))
    rim = np.exp(-np.abs(ed + 0.012) / 0.014) * (0.7 + 0.5 * nz(7, 62, px=ang * 1.5 + 5, py=ang * 0.7))
    img = add(img, C("#e6f2ff"), rim * 0.95)
    img = add(img, C("#a8cdff"), sparks(40, 63, (-0.9, -0.9, 0.9, 0.9), (0.003, 0.008)) * 0.75)
    return finish(img, 5, grade=(0.96, 0.99, 1.07))
