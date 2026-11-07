"""Map and compass medallions (category "mark"): a small painted coin per kind of place or thing, with a bronze
rim and a dark outline, RGBA and stored at 64 px so they stay crisp and legible on the parchment map and the
dark minimap at 16 to 28 px. The colour of each field keeps the old glyph's meaning (gold for tasks, violet for
travel, green for gathering ...). The same medal() / finish_mark() are used by lore.py for the codex and task marks."""
import numpy as np

from motifs import *  # noqa: F401,F403
from registry import recipe


def M(name):
    return recipe("mark", name)


INK = "#0a0604"


def medal(a, b, seed=0, glow=None):
    """The enamel field of a coin (top colour a, bottom colour b), a touch darker toward the rim."""
    r = np.hypot(x, y)
    img = mix(C(a), C(b), ss(-0.7, 0.7, y))
    img = img * (0.92 + 0.16 * nz(18, seed, octaves=3))[..., None]
    img = img * (1.0 - 0.38 * ss(0.4, 0.74, r))[..., None]
    if glow is not None:
        img = add(img, C(glow), np.exp(-(r / 0.5) ** 2) * 0.35)
    return img


def finish_mark(img, rim="#b08a48"):
    """Rim, dark outer ring, and the alpha: returns RGBA."""
    r = np.hypot(x, y)
    ring = np.abs(r - 0.8) - 0.07
    d, sp, h = bevel(ring, 0.07, relief=0.9)
    rimc = mix(C(rim) * 0.35, C(rim) * 1.2, d) + C("#fff0c0") * sp[..., None] * 0.5
    img = over(img, C(INK), smooth(r - 0.73 - 0.0) * 0.0)
    img = over(img, C(INK), smooth(np.abs(r - 0.735) - 0.02) * 0.9)
    img = over(img, rimc, smooth(ring))
    img = over(img, C(INK), smooth(np.abs(r - 0.925) - 0.05) * 0.97)
    a = smooth(r - 0.975)
    img = np.clip(img + (nz(300, 9, octaves=1) - 0.5)[..., None] * 0.02, 0, 1)
    return np.dstack([img, a])


def o(img, sd, dark, light, spec="#ffffff", width=0.07, outline=0.055, **kw):
    """A subject: lit, with a thick dark outline (the legibility at 20 px)."""
    return obj(img, sd, dark, light, spec, width, outline=outline, **kw)


def _fire_mark(img, cx, cy, h, w, seed, col_out=None):
    sd = flame_sd(cx, cy, h, w)
    img = over(img, C(INK), smooth(sd - 0.06) * 0.95)
    return fire(img, cx, cy, h, w, seed)


@M("fire")
def fire_m():
    img = medal("#2a1008", "#4a1c08", 701, glow="#ff6a20")
    img = _fire_mark(img, 0.0, 0.34, 0.95, 0.34, 702)
    for sx in (-1, 1):
        img = o(img, stadium(0.0, 0.0, 0.5, 0.075, *rot(0.0, 0.52, sx * 0.4, x, y)), "#2a1608", "#8a5a2a", "#ffd090", 0.07, outline=0.045)
    return finish_mark(img, "#c09050")


@M("ash")
def ash_m():
    img = medal("#1c1a1c", "#34302e", 703)
    for sx in (-1, 1):
        img = o(img, stadium(0.0, 0.0, 0.5, 0.075, *rot(0.0, 0.5, sx * 0.4, x, y)), "#1a1410", "#5a4a3a", "#c0a890", 0.07, outline=0.045)
    heap = ellipse(0, 0.42, 0.42, 0.16)
    img = o(img, heap, "#3a3638", "#a8a2a4", "#e0dcdc", 0.14, outline=0.045)
    img = over(img, C("#ff5a20"), np.exp(-np.hypot(x + 0.1, y - 0.42) / 0.05) * 0.8)
    smoke = polyline([(0.0, 0.3), (-0.12, 0.0), (0.1, -0.25), (-0.06, -0.55)]) - 0.05
    img = over(img, C(INK), smooth(smoke - 0.03) * 0.9)
    img = over(img, mix(C("#6a6668"), C("#b8b2b4"), np.clip(-y + 0.5, 0, 1)), smooth(smoke))
    return finish_mark(img, "#7a6a58")


@M("lamp")
def lamp_m():
    img = medal("#1a1008", "#3a2410", 704, glow="#ffb040")
    img = o(img, np.abs(circle(0, -0.5, 0.15)) - 0.04, "#4a3010", "#c89850", outline=0.04)
    img = o(img, poly([(-0.34, -0.3), (0.34, -0.3), (0.22, -0.46), (-0.22, -0.46)]), "#3a2410", "#b88a48")
    body = box(0, 0.08, 0.3, 0.38)
    img = o(img, body, "#2a1a0a", "#8a6030", "#e0b070", 0.07)
    glass = box(0, 0.08, 0.2, 0.28)
    img = over(img, mix(C("#ffe090"), C("#ff9a30"), ss(-0.3, 0.4, y)), smooth(glass))
    img = add(img, C("#fff6c0"), np.exp(-np.hypot(x, y - 0.1) / 0.1) * 0.8 * smooth(glass))
    img = o(img, box(0, 0.5, 0.36, 0.06), "#2a1a0a", "#8a6030")
    return finish_mark(img, "#c09050")


def _skull(img, cy, col=("#6a6258", "#f0e8d8"), eye="#0a0408"):
    cr = smin(ellipse(0, cy - 0.12, 0.38, 0.34), box(0, cy + 0.2, 0.22, 0.17) - 0.04, 0.1)
    img = o(img, cr, col[0], col[1], "#ffffff", 0.2)
    for sx in (-0.15, 0.15):
        img = over(img, C(eye), smooth(ellipse(sx, cy - 0.06, 0.1, 0.12)))
    img = over(img, C(eye), smooth(poly([(0, cy + 0.07), (-0.05, cy + 0.17), (0.05, cy + 0.17)])))
    for tx in (-0.1, 0.0, 0.1):
        img = over(img, C(eye), smooth(box(tx, cy + 0.33, 0.012, 0.07)))
    return img


@M("boss")
def boss():
    img = medal("#2a0808", "#541414", 705, glow="#ff4030")
    img = _skull(img, 0.1)
    crown = poly([(-0.34, -0.3), (-0.34, -0.62), (-0.17, -0.45), (0.0, -0.7), (0.17, -0.45), (0.34, -0.62), (0.34, -0.3)])
    img = o(img, crown, "#7a5010", "#ffd870", "#fff6c0", 0.1, outline=0.045)
    return finish_mark(img, "#c04030")


@M("boss_down")
def boss_down():
    img = medal("#1e1c1c", "#383434", 706)
    img = _skull(img, 0.08, ("#3a3632", "#9a948a"))
    sl = segment(-0.55, 0.55, 0.55, -0.55) - 0.05
    img = over(img, C(INK), smooth(sl - 0.03))
    img = over(img, C("#8a8278"), smooth(sl))
    return finish_mark(img, "#6a645c")


@M("watch")
def watch():
    img = medal("#0c1c24", "#1c3a46", 707, glow="#5aa0b8")
    img = o(img, segment(-0.1, -0.1, -0.1, -0.74) - 0.025, "#3a2a10", "#a07a40", outline=0.04)
    img = o(img, poly([(-0.08, -0.72), (0.34, -0.6), (-0.08, -0.44)]), "#1a5a78", "#6ad0f0", "#ffffff", 0.08, outline=0.04)
    tower = poly([(-0.28, 0.62), (-0.2, -0.12), (-0.3, -0.12), (-0.3, -0.26), (-0.2, -0.26), (-0.2, -0.22),
                  (-0.05, -0.22), (-0.05, -0.26), (0.05, -0.26), (0.05, -0.22), (0.2, -0.22), (0.2, -0.26), (0.3, -0.26), (0.3, -0.12), (0.2, -0.12), (0.28, 0.62)])
    img = o(img, tower, "#2a2c30", "#9aa0a8", "#e0e8f0", 0.14, texture=0.3, seed=708)
    img = over(img, C(INK), smooth(box(0, 0.12, 0.05, 0.12)))
    img = over(img, C("#ffb040"), smooth(box(0, 0.12, 0.028, 0.08)))
    return finish_mark(img, "#7ab0c0")


@M("horse")
def horse():
    img = medal("#241408", "#46280f", 709)
    ring = np.maximum(np.abs(circle(0, -0.12, 0.36)) - 0.12, -box(0, 0.55, 0.2, 0.28))
    img = o(img, ring, "#3a3a40", "#b8bcc8", "#ffffff", 0.12, outline=0.05, shine=14)
    for px_, py_ in ((-0.42, 0.1), (-0.37, -0.22), (-0.2, -0.42), (0.0, -0.49), (0.2, -0.42), (0.37, -0.22), (0.42, 0.1)):
        img = over(img, C("#1a1a20"), smooth(circle(px_, py_, 0.035)))
    return finish_mark(img, "#a07a40")


def _gold_field(seed):
    return medal("#6a4a10", "#b88a28", seed, glow="#ffe090")


@M("quest_available")
def quest_available():
    img = _gold_field(710)
    bar = poly([(-0.11, -0.62), (0.11, -0.62), (0.07, 0.14), (-0.07, 0.14)]) - 0.03
    img = o(img, bar, "#2a1204", "#6a3a14", "#c89050", 0.1, outline=0.05)
    img = o(img, circle(0, 0.44, 0.1), "#2a1204", "#6a3a14", "#c89050", 0.1, outline=0.05)
    return finish_mark(img, "#e8b040")


@M("quest_turnin")
def quest_turnin():
    img = _gold_field(711)
    arc = []
    for t in np.linspace(-2.5, 1.5, 24):
        arc.append((0.0 + 0.28 * np.cos(t), -0.28 + 0.28 * np.sin(t)))
    hook = arc + [(0.0, 0.14), (0.0, 0.22)]
    img = o(img, polyline(hook) - 0.075, "#2a1204", "#6a3a14", "#c89050", 0.09, outline=0.05)
    img = o(img, circle(0, 0.52, 0.09), "#2a1204", "#6a3a14", "#c89050", 0.09, outline=0.05)
    return finish_mark(img, "#e8b040")


@M("quest_target")
def quest_target():
    img = medal("#4a3008", "#8a6414", 712, glow="#ffe090")
    for rr, wd in ((0.52, 0.06), (0.3, 0.06)):
        img = o(img, np.abs(circle(0, 0, rr)) - wd, "#6a3a0a", "#ffd870", "#fff6c0", 0.06, outline=0.045)
    img = o(img, circle(0, 0, 0.11), "#6a3a0a", "#ffd870", "#fff6c0", 0.11, outline=0.045)
    return finish_mark(img, "#f0c050")


@M("rare")
def rare():
    img = medal("#101828", "#243450", 713, glow="#a0c8ff")
    gem = poly([(0.0, -0.64), (0.42, -0.14), (0.0, 0.64), (-0.42, -0.14)])
    img = o(img, gem, "#3a5a98", "#e0f0ff", "#ffffff", 0.2, outline=0.055, halo="#a0d0ff", halo_amt=0.4)
    img = over(img, C("#ffffff"), smooth(polyline([(-0.42, -0.14), (0.42, -0.14)]) - 0.014) * smooth(gem + 0.01) * 0.8)
    img = over(img, C("#ffffff"), smooth(polyline([(0.0, -0.64), (-0.15, -0.14), (0.0, 0.64), (0.15, -0.14), (0.0, -0.64)]) - 0.012) * smooth(gem + 0.01) * 0.55)
    return finish_mark(img, "#a0b8d8")


@M("travel")
def travel():
    img = medal("#1a1038", "#3a1c70", 714, glow="#a070ff")
    arch = np.maximum(box(0, 0.12, 0.42, 0.56), -circle(0, -0.1, 0.42) * 0 + 0)
    arch = smin(box(0, 0.2, 0.42, 0.45), circle(0, -0.12, 0.42), 0.0)
    img = o(img, arch, "#2a2430", "#9a94a8", "#e8e4f0", 0.14, texture=0.3, seed=715)
    inner = smin(box(0, 0.26, 0.26, 0.4), circle(0, -0.08, 0.26), 0.0)
    img = over(img, mix(C("#d8b8ff"), C("#6a30d0"), ss(-0.4, 0.6, y)), smooth(inner))
    img = add(img, C("#ffffff"), np.exp(-np.hypot(x, y - 0.0) / 0.12) * 0.7 * smooth(inner))
    return finish_mark(img, "#a080e0")


@M("gather")
def gather():
    img = medal("#0e2410", "#1c4a1c", 716, glow="#70d060")
    img = o(img, polyline([(0.0, 0.62), (0.02, 0.1), (0.0, -0.4)]) - 0.035, "#1a4a18", "#60b848", outline=0.045)
    for sx, ang in ((-1, 0.0), (1, 0.0)):
        qx, qy = xf(x, y, 0, 0, sx * -0.7, sx * 0.04, 0.1)
        leaf = ellipse(sx * 0.2, 0.1, 0.24, 0.1, qx, qy)
        img = o(img, leaf, "#1a5a18", "#8ae060", "#e8ffd0", 0.1, outline=0.05)
    for sx in (-1, 1):
        qx, qy = xf(x, y, 0, 0, sx * -0.55, sx * 0.02, -0.28)
        img = o(img, ellipse(sx * 0.17, -0.28, 0.2, 0.085, qx, qy), "#1a5a18", "#9af070", "#f0ffe0", 0.08, outline=0.05)
    img = o(img, circle(0, -0.5, 0.1), "#7a4a8a", "#e0a8ff", outline=0.05)
    return finish_mark(img, "#70b060")


@M("vendor")
def vendor():
    img = medal("#3a2606", "#6a460c", 717, glow="#ffd070")
    bag = smin(circle(0, 0.2, 0.4), poly([(-0.13, -0.36), (0.13, -0.36), (0.28, 0.1), (-0.28, 0.1)]), 0.12)
    img = o(img, poly([(-0.24, -0.62), (0.24, -0.62), (0.13, -0.34), (-0.13, -0.34)]), "#4a2a0a", "#c8903a", outline=0.05)
    img = o(img, bag, "#5a3410", "#d8a050", "#fff0c0", 0.3, texture=0.3, seed=718)
    img = o(img, box(0, -0.3, 0.17, 0.045), "#2a1204", "#8a3a14", outline=0.035)
    img = o(img, circle(0, 0.26, 0.19), "#a07010", "#ffe080", "#ffffff", 0.19, outline=0.035)
    img = over(img, C("#7a5008"), smooth(np.abs(circle(0, 0.26, 0.11)) - 0.02))
    return finish_mark(img, "#e0b050")


@M("trainer")
def trainer():
    img = medal("#1c1432", "#382a60", 719, glow="#c0a8ff")
    for sgn in (-1, 1):
        page = poly([(0.0, -0.3), (sgn * 0.5, -0.4), (sgn * 0.5, 0.36), (0.0, 0.46)])
        img = o(img, page, "#8a7a98" if sgn < 0 else "#a090b0", "#f0e8ff", "#ffffff", 0.12, outline=0.05)
        for k in range(4):
            yy = -0.18 + k * 0.14
            img = over(img, C("#4a3a68"), smooth(segment(sgn * 0.08, yy, sgn * 0.4, yy - 0.06) - 0.014) * 0.8)
    img = over(img, C(INK), smooth(segment(0, -0.3, 0, 0.46) - 0.025))
    img = add(img, C("#e8d8ff"), sparks(6, 720, (-0.3, -0.7, 0.3, -0.45), (0.005, 0.01)))
    return finish_mark(img, "#a090d0")


@M("seal")
def seal():
    img = medal("#1a1c22", "#30343e", 721)
    arch = smin(box(0, 0.2, 0.46, 0.46), circle(0, -0.1, 0.46), 0.0)
    img = o(img, arch, "#2a2c34", "#8a909c", "#e0e8f0", 0.16, texture=0.3, seed=722)
    for bx in (-0.28, -0.093, 0.093, 0.28):
        img = over(img, C("#101216"), smooth(box(bx, 0.1, 0.035, 0.52)) * smooth(arch + 0.03))
    for by in (0.0, 0.4):
        img = over(img, C("#101216"), smooth(box(0, by, 0.5, 0.03)) * smooth(arch + 0.03))
    return finish_mark(img, "#7a808c")


@M("beacon")
def beacon():
    img = medal("#2a1408", "#4a240c", 723, glow="#ff8a30")
    img = o(img, poly([(-0.1, 0.62), (0.1, 0.62), (0.07, 0.1), (-0.07, 0.1)]), "#2a2420", "#8a8078", "#e0d8d0", 0.06, outline=0.045)
    bowl = poly([(-0.34, 0.0), (0.34, 0.0), (0.22, 0.2), (-0.22, 0.2)])
    img = o(img, bowl, "#2a1608", "#9a6a30", "#ffd090", 0.1, outline=0.05)
    img = _fire_mark(img, 0.0, -0.02, 0.78, 0.3, 724)
    return finish_mark(img, "#c09050")


@M("cold")
def cold():
    img = medal("#1a1a1e", "#30303a", 725)
    img = o(img, poly([(-0.1, 0.62), (0.1, 0.62), (0.07, 0.1), (-0.07, 0.1)]), "#222024", "#6a6870", "#c0c0c8", 0.06, outline=0.045)
    bowl = poly([(-0.34, 0.0), (0.34, 0.0), (0.22, 0.2), (-0.22, 0.2)])
    img = o(img, bowl, "#222024", "#7a7880", "#d0d0d8", 0.1, outline=0.05)
    img = over(img, C("#4a484c"), smooth(ellipse(0, -0.02, 0.3, 0.07)))
    return finish_mark(img, "#7a7880")


@M("chest")
def chest():
    img = medal("#2a1a0a", "#4a2c10", 726, glow="#ffc060")
    img = o(img, box(0, 0.22, 0.46, 0.26), "#3a2008", "#a06a30", "#ffd8a0", 0.12, texture=0.3, seed=727)
    lid = np.maximum(ellipse(0, -0.02, 0.46, 0.3), -(y + 0.02))
    img = o(img, lid, "#4a2a0c", "#b87a38", "#ffe0b0", 0.14, texture=0.3, seed=728)
    img = over(img, C("#e0b050"), smooth(box(0, 0.12, 0.46, 0.035)) * smooth(box(0, 0.22, 0.46, 0.26)) * 0.9)
    img = o(img, box(0, 0.12, 0.07, 0.1), "#8a6010", "#ffe080", outline=0.045)
    return finish_mark(img, "#c09050")


@M("bell")
def bell():
    img = medal("#2a1c06", "#503408", 729, glow="#ffd070")
    body = poly([(-0.14, -0.44), (0.14, -0.44), (0.22, -0.2), (0.28, 0.1), (0.4, 0.3), (0.44, 0.38), (-0.44, 0.38), (-0.4, 0.3), (-0.28, 0.1), (-0.22, -0.2)]) - 0.03
    img = o(img, np.abs(circle(0, -0.56, 0.1)) - 0.035, "#6a4a10", "#e0b050", outline=0.045)
    img = o(img, body, "#7a5010", "#ffd870", "#fff6c0", 0.22, shine=14)
    img = o(img, circle(0, 0.5, 0.075), "#5a3a08", "#e0b050", outline=0.04)
    return finish_mark(img, "#d0a040")


@M("door")
def door_m():
    img = medal("#101826", "#1c2c44", 730, glow="#ffb050")
    arch = smin(box(0, 0.2, 0.36, 0.5), circle(0, -0.1, 0.36), 0.0)
    img = o(img, arch, "#2a2420", "#8a7a68", "#e0d0b8", 0.12, texture=0.3, seed=731)
    inner = smin(box(0, 0.26, 0.23, 0.42), circle(0, -0.04, 0.23), 0.0)
    img = over(img, mix(C("#ffe090"), C("#ff9a30"), ss(-0.3, 0.6, y)), smooth(inner))
    leaf = poly([(-0.23, 0.68), (-0.23, -0.06), (-0.02, 0.02), (-0.02, 0.6)])
    img = o(img, leaf, "#2a1a0c", "#7a5a38", "#d8b890", 0.1, outline=0.04)
    return finish_mark(img, "#a0825a")


@M("keg")
def keg():
    img = medal("#2a1608", "#4a2a10", 732, glow="#ffb050")
    qx = np.abs(x) / 0.44
    body = np.maximum(np.abs(y) - 0.52, (np.abs(x) - 0.42 * (1 - 0.16 * (y / 0.52) ** 2)))
    img = o(img, body, "#4a2a0c", "#b0743a", "#ffd8a0", 0.16, texture=0.4, seed=733)
    for hy in (-0.34, 0.34):
        img = over(img, C("#2a1c14"), smooth(box(0, hy, 0.5, 0.05) * 1.0) * smooth(body + 0.01))
    img = over(img, C(INK), smooth(circle(0, 0.0, 0.07)))
    img = over(img, C("#c8c0b8"), smooth(circle(0, 0.0, 0.04)))
    return finish_mark(img, "#c09050")
