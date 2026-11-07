"""Codex, quest-task, reward and HUD marks (categories "lore", "task", "reward", "hud"): painted medallions like marks.py,
64 px with a dark outline, used on the codex lists, the quest log and offer, and the small HUD readouts."""
import numpy as np

from marks import medal, finish_mark, o, INK, _skull  # noqa: F401
from motifs import *  # noqa: F401,F403
from registry import recipe


def L(name):
    return recipe("lore", name)


def T(name):
    return recipe("task", name)


def R(name):
    return recipe("reward", name)


def H(name):
    return recipe("hud", name)


def _stone(img, sd, seed, light="#b0a898"):
    return o(img, sd, "#2a2824", light, "#f0ece4", 0.14, texture=0.35, seed=seed)


def _lines(img, n, x0, x1, y0, dy, col="#3a2a1a", slant=0.0, w=0.014):
    for k in range(n):
        yy = y0 + k * dy
        img = over(img, C(col), smooth(segment(x0, yy, x1 - (0.12 if k == n - 1 else 0.0), yy + slant) - w) * 0.85)
    return img


def _arch(w, y0, y1, r=None):
    """A round-topped slab: half-width w, from y0 (top of the dome) to y1 (foot)."""
    r = w if r is None else r
    return smin(box(0, (y0 + r + y1) * 0.5, w, (y1 - y0 - r) * 0.5), circle(0, y0 + r, r), 0.0)


# --- the codex's kinds of writing --------------------------------------------------------------

@L("grave")
def grave():
    img = medal("#1a1c1a", "#323830", 801)
    img = _stone(img, _arch(0.32, -0.55, 0.55), 802)
    img = over(img, C("#14161a"), smooth(box(0, -0.12, 0.035, 0.2)))
    img = over(img, C("#14161a"), smooth(box(0, -0.14, 0.13, 0.035)))
    img = over(img, C("#4a6a3a"), smooth(ellipse(0, 0.6, 0.5, 0.09)) * 0.9)
    return finish_mark(img, "#8a8a7a")


@L("waystone")
def waystone():
    img = medal("#1a1830", "#2c2850", 803, glow="#80a0ff")
    stone = poly([(-0.22, 0.62), (-0.3, -0.1), (-0.14, -0.62), (0.16, -0.58), (0.3, -0.08), (0.24, 0.62)])
    img = _stone(img, stone, 804)
    glyph = polyline([(0.0, -0.36), (0.0, 0.24)]) - 0.03
    img = add(img, C("#80a8ff"), np.exp(-np.maximum(glyph, 0) / 0.05) * 0.9)
    img = over(img, C("#e0ecff"), smooth(glyph))
    img = over(img, C("#e0ecff"), smooth(polyline([(-0.14, -0.14), (0.0, -0.3), (0.14, -0.14)]) - 0.025))
    return finish_mark(img, "#8090c0")


@L("rune")
def rune():
    img = medal("#14181a", "#262e30", 805, glow="#70d0c0")
    stone = poly([(-0.4, 0.4), (-0.44, -0.2), (-0.2, -0.5), (0.3, -0.46), (0.46, -0.1), (0.4, 0.42)])
    img = _stone(img, stone, 806, "#a0a8a0")
    sp = []
    for t in np.linspace(0, 3.2 * np.pi, 40):
        r = 0.05 + 0.055 * t
        sp.append((0.02 + r * np.cos(t), -0.04 + r * np.sin(t)))
    g = polyline(sp) - 0.022
    img = add(img, C("#60e0c8"), np.exp(-np.maximum(g, 0) / 0.04) * 0.8)
    img = over(img, C("#c8fff0"), smooth(g))
    return finish_mark(img, "#709088")


@L("page")
def page():
    img = medal("#2a2012", "#4a3a20", 807)
    sheet = poly([(-0.36, -0.58), (0.2, -0.6), (0.38, -0.4), (0.36, 0.58), (-0.34, 0.6)])
    img = o(img, sheet, "#a89060", "#f4e8c8", "#ffffff", 0.1, texture=0.2, seed=808)
    img = over(img, C("#c0a878"), smooth(poly([(0.2, -0.6), (0.38, -0.4), (0.18, -0.38)])))
    img = _lines(img, 6, -0.24, 0.26, -0.28, 0.17, slant=-0.02)
    return finish_mark(img, "#b09060")


@L("notice")
def notice():
    img = medal("#2a1c10", "#4a3018", 809)
    img = o(img, box(0, 0.0, 0.5, 0.52), "#3a2008", "#9a6a38", "#ffd8a0", 0.12, texture=0.5, seed=810)
    sheet = poly([(-0.3, -0.34), (0.3, -0.38), (0.32, 0.34), (-0.28, 0.38)])
    img = o(img, sheet, "#a89060", "#f4e8c8", "#ffffff", 0.08, outline=0.04)
    img = _lines(img, 4, -0.18, 0.2, -0.1, 0.16)
    img = o(img, circle(0.0, -0.3, 0.07), "#6a1010", "#ff6a50", outline=0.035)
    return finish_mark(img, "#b08a50")


@L("plaque")
def plaque():
    img = medal("#2a2010", "#4a3a18", 811, glow="#ffd070")
    img = o(img, box(0, 0.0, 0.5, 0.36) - 0.04, "#5a3c0c", "#e0b050", "#fff0b0", 0.12, shine=14)
    img = over(img, C("#4a3008"), smooth(np.abs(box(0, 0, 0.4, 0.27)) - 0.014))
    img = _lines(img, 3, -0.3, 0.3, -0.1, 0.12, col="#4a3008")
    for sx in (-1, 1):
        for sy in (-1, 1):
            img = over(img, C("#2a1804"), smooth(circle(sx * 0.42, sy * 0.28, 0.035)))
    return finish_mark(img, "#d0a040")


@L("lectern")
def lectern():
    img = medal("#1c1a30", "#30284a", 812)
    img = o(img, poly([(-0.1, 0.62), (0.1, 0.62), (0.08, 0.1), (-0.08, 0.1)]), "#2a1a0a", "#7a5a30", outline=0.045)
    img = o(img, box(0, 0.64, 0.26, 0.045), "#2a1a0a", "#7a5a30", outline=0.04)
    desk = poly([(-0.46, 0.18), (0.46, 0.18), (0.4, -0.06), (-0.4, -0.06)])
    img = o(img, desk, "#3a2008", "#8a5a30", "#ffd8a0", 0.08, texture=0.3, seed=813)
    for sgn in (-1, 1):
        pg = poly([(0.0, -0.06), (sgn * 0.4, -0.12), (sgn * 0.4, -0.5), (0.0, -0.42)])
        img = o(img, pg, "#a89060", "#f4e8c8", "#ffffff", 0.08, outline=0.045)
        for k in range(3):
            yy = -0.36 + k * 0.09
            img = over(img, C("#3a2a1a"), smooth(segment(sgn * 0.06, yy, sgn * 0.33, yy - 0.02) - 0.012) * 0.85)
    return finish_mark(img, "#a090c0")


@L("letter")
def letter():
    img = medal("#2a1c14", "#4a3020", 814)
    img = o(img, box(0, 0.03, 0.5, 0.33), "#a89060", "#f4e8c8", "#ffffff", 0.1)
    flap = poly([(-0.5, -0.3), (0.5, -0.3), (0.0, 0.12)])
    img = o(img, flap, "#8a7448", "#e4d4aa", "#ffffff", 0.08, outline=0.04)
    img = o(img, circle(0.0, 0.1, 0.12), "#6a0e0e", "#e0503a", "#ffd0c0", 0.12, outline=0.04)
    return finish_mark(img, "#b09060")


@L("ledger")
def ledger():
    img = medal("#20180c", "#3a2c14", 815)
    img = o(img, box(0, 0.0, 0.36, 0.5), "#2a1208", "#7a3a20", "#e0a080", 0.14, texture=0.3, seed=816)
    img = over(img, C("#e0b050"), smooth(np.abs(box(0, 0.0, 0.27, 0.4)) - 0.012) * 0.9)
    img = _lines(img, 4, -0.2, 0.2, -0.18, 0.12, col="#e8d090", w=0.016)
    img = over(img, C("#a02a1a"), smooth(box(0.18, 0.48, 0.05, 0.2)))
    return finish_mark(img, "#b09060")


@L("tablet")
def tablet():
    img = medal("#18201c", "#2c3a30", 817)
    img = _stone(img, _arch(0.36, -0.58, 0.6), 818, "#a8b0a0")
    img = _lines(img, 4, -0.22, 0.22, -0.12, 0.15, col="#1a1c18", w=0.02)
    img = over(img, C("#1a1c18"), smooth(np.abs(circle(0, -0.3, 0.1)) - 0.02))
    return finish_mark(img, "#80907a")


# --- quest task kinds ---------------------------------------------------------------------------

def _gold(seed):
    return medal("#5a3c0c", "#9a6c18", seed, glow="#ffe090")


@T("find")
def find():
    img = _gold(820)
    img = o(img, segment(0.16, 0.16, 0.54, 0.54) - 0.08, "#2a1204", "#7a4a20", outline=0.05)
    lens = circle(-0.1, -0.1, 0.34)
    img = o(img, np.abs(lens) - 0.06, "#6a4a10", "#ffe080", "#ffffff", 0.06, outline=0.05)
    img = over(img, mix(C("#a0d0e0"), C("#e8f8ff"), ss(0.3, -0.3, y + x)), smooth(lens + 0.05) * 0.55)
    img = over(img, C("#ffffff"), smooth(circle(-0.22, -0.22, 0.06)) * 0.8)
    return finish_mark(img, "#e8b040")


@T("reach")
def reach():
    img = _gold(821)
    img = o(img, segment(-0.2, 0.6, -0.2, -0.6) - 0.04, "#3a2008", "#a07040", outline=0.05)
    img = o(img, poly([(-0.18, -0.58), (0.5, -0.36), (-0.18, -0.12)]), "#7a1810", "#ff6a50", "#ffd0c0", 0.1, outline=0.05)
    img = o(img, ellipse(-0.2, 0.62, 0.28, 0.08), "#3a2008", "#a07040", outline=0.045)
    return finish_mark(img, "#e8b040")


@T("talk")
def talk():
    img = _gold(822)
    bub = smin(ellipse(0, -0.08, 0.5, 0.36), poly([(-0.26, 0.1), (-0.02, 0.1), (-0.36, 0.52)]), 0.04)
    img = o(img, bub, "#8a7a50", "#fff4d8", "#ffffff", 0.14, outline=0.055)
    for sx in (-0.24, 0.0, 0.24):
        img = over(img, C("#3a2a10"), smooth(circle(sx, -0.08, 0.055)))
    return finish_mark(img, "#e8b040")


@T("place")
def place():
    img = _gold(823)
    img = o(img, poly([(-0.46, 0.62), (-0.36, 0.28), (0.36, 0.28), (0.46, 0.62)]), "#2a2824", "#a8a090", "#ece4d4", 0.1, texture=0.3, seed=824)
    gem = poly([(0.0, -0.26), (0.18, 0.0), (0.0, 0.24), (-0.18, 0.0)])
    img = o(img, gem, "#a03010", "#ff9a50", "#fff0c0", 0.14, halo="#ffb060", halo_amt=0.5, outline=0.05)
    arrow = poly([(-0.09, -0.62), (0.09, -0.62), (0.09, -0.46), (0.2, -0.46), (0.0, -0.32), (-0.2, -0.46), (-0.09, -0.46)])
    img = o(img, arrow, "#2a1204", "#7a4a20", "#c89050", 0.05, outline=0.04)
    return finish_mark(img, "#e8b040")


@T("escort")
def escort():
    img = _gold(825)
    img = o(img, segment(-0.3, 0.64, -0.3, -0.5) - 0.045, "#3a2008", "#a07040", outline=0.05)
    img = o(img, np.abs(circle(-0.18, -0.58, 0.1)) - 0.03, "#4a3010", "#c89850", outline=0.04)
    img = o(img, box(0.14, -0.2, 0.2, 0.3), "#2a1a0a", "#8a6030", "#e0b070", 0.07, outline=0.05, halo="#ffb040", halo_amt=0.4)
    img = over(img, mix(C("#ffe090"), C("#ff9a30"), ss(-0.4, 0.1, y)), smooth(box(0.14, -0.2, 0.12, 0.22)))
    img = o(img, box(0.14, 0.18, 0.18, 0.04), "#2a1a0a", "#8a6030", outline=0.035)
    return finish_mark(img, "#e8b040")


@T("gather")
def gather_t():
    img = _gold(826)
    basket = poly([(-0.4, -0.06), (0.4, -0.06), (0.3, 0.5), (-0.3, 0.5)])
    for sx, tilt in ((-0.14, -0.3), (0.06, 0.1), (0.2, 0.4)):
        qx, qy = xf(x, y, 0, 0, tilt, sx, -0.1)
        img = o(img, ellipse(sx, -0.3, 0.07, 0.24, qx, qy), "#1a5a18", "#8ae060", outline=0.04)
    img = o(img, basket, "#3a2008", "#a87038", "#ffd8a0", 0.12, texture=0.5, seed=827)
    for yy in (0.08, 0.26):
        img = over(img, C("#2a1204"), smooth(segment(-0.36 + (yy - 0.08) * 0.2, yy, 0.36 - (yy - 0.08) * 0.2, yy) - 0.02) * 0.8)
    return finish_mark(img, "#e8b040")


@T("kill")
def kill():
    img = _gold(828)
    blade = poly([(0.0, -0.66), (0.09, -0.5), (0.09, 0.14), (-0.09, 0.14), (-0.09, -0.5)])
    img = o(img, blade, "#4a5078", "#e8ecf8", "#ffffff", 0.09, outline=0.05, shine=16)
    img = o(img, box(0, 0.2, 0.3, 0.05), "#5a3a10", "#e8c060", "#fff0b0", 0.05, outline=0.04)
    img = o(img, segment(0, 0.24, 0, 0.5) - 0.045, "#2a1a0a", "#8a6030", outline=0.04)
    img = o(img, circle(0, 0.58, 0.07), "#5a3a10", "#e8c060", outline=0.04)
    return finish_mark(img, "#e8b040")


@T("collect")
def collect():
    img = _gold(829)
    bag = smin(circle(0, 0.2, 0.4), poly([(-0.13, -0.3), (0.13, -0.3), (0.28, 0.1), (-0.28, 0.1)]), 0.12)
    img = o(img, bag, "#3a3a40", "#9a98a0", "#e0dce0", 0.3, texture=0.3, seed=830)
    img = o(img, box(0, -0.3, 0.17, 0.045), "#2a1204", "#8a3a14", outline=0.035)
    img = o(img, poly([(-0.22, -0.56), (0.22, -0.56), (0.13, -0.32), (-0.13, -0.32)]), "#3a3a40", "#9a98a0", outline=0.045)
    for px_, py_ in ((-0.08, 0.1), (0.12, 0.28), (-0.15, 0.36)):
        img = over(img, C("#ff7a30"), smooth(circle(px_, py_, 0.045)))
    return finish_mark(img, "#e8b040")


@T("turnin")
def turnin():
    img = _gold(831)
    for sx in (-1, 1):
        img = o(img, box(sx * 0.4, 0.0, 0.07, 0.4) - 0.03, "#7a5a28", "#d8b068", outline=0.045)
    img = o(img, box(0, 0.0, 0.36, 0.3), "#a89060", "#f4e8c8", "#ffffff", 0.1, outline=0.05)
    img = _lines(img, 3, -0.24, 0.24, -0.12, 0.12)
    img = o(img, circle(0, 0.24, 0.11), "#6a0e0e", "#e0503a", "#ffd0c0", 0.11, outline=0.04)
    return finish_mark(img, "#e8b040")


@T("slay")
def slay():
    img = _gold(832)
    img = _skull(img, 0.0, ("#5a5248", "#f0e8d8"))
    return finish_mark(img, "#e8b040")


@T("carry")
def carry():
    img = _gold(833)
    img = o(img, segment(-0.3, 0.6, 0.06, 0.02) - 0.06, "#2a1a0a", "#8a6030", "#e0b070", 0.06, outline=0.05)
    sd = flame_sd(0.14, -0.04, 0.8, 0.28)
    img = over(img, C(INK), smooth(sd - 0.06) * 0.95)
    img = fire(img, 0.14, -0.04, 0.8, 0.28, 834)
    return finish_mark(img, "#e8b040")


@T("visit")
def visit():
    img = _gold(835)
    img = o(img, segment(0, 0.64, 0, -0.5) - 0.06, "#2a1a0a", "#8a6030", outline=0.05)
    for yy, sg in ((-0.42, 1), (-0.12, -1)):
        pts = [(0.0, yy - 0.1), (sg * 0.46, yy - 0.1), (sg * 0.6, yy), (sg * 0.46, yy + 0.1), (0.0, yy + 0.1)]
        img = o(img, poly(pts), "#6a4418", "#e0b068", "#fff0c0", 0.08, outline=0.045)
        img = over(img, C("#3a2408"), smooth(segment(sg * 0.1, yy, sg * 0.36, yy) - 0.014) * 0.8)
    return finish_mark(img, "#e8b040")


@T("seal")
def seal_t():
    img = medal("#3a1058", "#5a1c88", 836, glow="#c070ff")
    img = o(img, np.abs(circle(0, 0, 0.46)) - 0.06, "#4a1a80", "#e0b0ff", "#ffffff", 0.06, outline=0.05)
    star = None
    for k in range(5):
        a0 = -np.pi / 2 + k * 4 * np.pi / 5
        a1 = -np.pi / 2 + (k + 1) * 4 * np.pi / 5
        sg = segment(0.42 * np.cos(a0), 0.42 * np.sin(a0), 0.42 * np.cos(a1), 0.42 * np.sin(a1)) - 0.035
        star = sg if star is None else np.minimum(star, sg)
    img = o(img, star, "#4a1a80", "#f0d8ff", "#ffffff", 0.04, outline=0.03)
    return finish_mark(img, "#b080e0")


# --- rewards --------------------------------------------------------------------------------------

@R("ash")
def ash_r():
    img = medal("#1e1c1e", "#38343a", 840)
    heap = poly([(-0.5, 0.4), (-0.3, 0.04), (-0.08, -0.16), (0.1, -0.1), (0.32, 0.1), (0.5, 0.4)]) - 0.05
    img = o(img, heap, "#3a3638", "#b0aaac", "#f0ecec", 0.2, texture=0.5, seed=841)
    img = add(img, C("#ff5a20"), sparks(8, 842, (-0.3, -0.1, 0.3, 0.3), (0.012, 0.022)) * 0.8)
    img = add(img, C("#ff7a30"), sparks(5, 843, (-0.3, -0.5, 0.3, -0.2), (0.008, 0.014)))
    return finish_mark(img, "#8a8284")


@R("item")
def item_r():
    img = medal("#2a1c0a", "#4a3010", 844)
    sack = smin(circle(0, 0.2, 0.4), poly([(-0.2, -0.3), (0.2, -0.3), (0.28, 0.1), (-0.28, 0.1)]), 0.1)
    img = o(img, sack, "#4a3410", "#b89058", "#f0d8a8", 0.3, texture=0.5, seed=845)
    img = o(img, box(0, -0.28, 0.2, 0.04), "#2a1204", "#8a3a14", outline=0.035)
    img = o(img, poly([(-0.24, -0.5), (0.24, -0.5), (0.2, -0.3), (-0.2, -0.3)]), "#4a3410", "#b89058", outline=0.045)
    return finish_mark(img, "#b08a48")


@R("charm")
def charm_r():
    img = medal("#1a1432", "#32286a", 846, glow="#a888ff")
    chain = np.abs(ellipse(0, -0.2, 0.34, 0.5)) - 0.025
    img = over(img, C(INK), smooth(chain - 0.03) * (y < -0.1))
    img = over(img, C("#d0d4e0"), smooth(chain) * (y < -0.1))
    img = o(img, circle(0, 0.32, 0.26), "#6a4a10", "#ffe080", "#ffffff", 0.2, outline=0.05, halo="#ffd070", halo_amt=0.4)
    gem = poly([(0.0, 0.14), (0.12, 0.32), (0.0, 0.5), (-0.12, 0.32)])
    img = o(img, gem, "#3a1a98", "#c0a0ff", "#ffffff", 0.1, outline=0.03)
    return finish_mark(img, "#c09a48")


@R("gear")
def gear_r():
    img = medal("#1c202c", "#303a4c", 847)
    helm = np.maximum(ellipse(0, -0.04, 0.42, 0.5), y - 0.46)
    img = o(img, poly([(-0.07, -0.44), (0.07, -0.44), (0.1, -0.64), (0.0, -0.72), (-0.1, -0.64)]), "#7a1810", "#ff6a50", outline=0.045)
    img = o(img, helm, "#2a3040", "#a8b4cc", "#ffffff", 0.2, shine=14)
    img = over(img, C(INK), smooth(box(0, 0.0, 0.3, 0.05)))
    img = over(img, C(INK), smooth(box(0, 0.22, 0.04, 0.22)))
    return finish_mark(img, "#8a9ab8")


# --- the quest log's own marks and the HUD ---------------------------------------------------------

@L("tracked")
def tracked():
    img = _gold(850)
    img = o(img, circle(0, -0.22, 0.34), "#7a1810", "#ff6a50", "#ffd0c0", 0.3, outline=0.055)
    img = o(img, poly([(-0.2, -0.04), (0.2, -0.04), (0.0, 0.62)]), "#3a3a40", "#c0c4d0", outline=0.045)
    img = over(img, C("#ffd0c0"), smooth(circle(-0.1, -0.32, 0.07)) * 0.8)
    return finish_mark(img, "#e8b040")


@L("done")
def done():
    img = medal("#0e2a14", "#1c4a22", 851, glow="#70e080")
    chk = polyline([(-0.36, 0.02), (-0.1, 0.3), (0.4, -0.36)]) - 0.085
    img = o(img, chk, "#1a6a28", "#a0f0a0", "#ffffff", 0.09, outline=0.055)
    return finish_mark(img, "#70b070")


@L("ready")
def ready():
    img = _gold(852)
    img = o(img, box(0, 0.0, 0.4, 0.3), "#a89060", "#f4e8c8", "#ffffff", 0.1, outline=0.05)
    img = o(img, poly([(-0.4, -0.3), (0.4, -0.3), (0.0, 0.06)]), "#8a7448", "#e4d4aa", outline=0.04)
    img = o(img, circle(0, 0.06, 0.12), "#a02a10", "#ffb060", outline=0.04, halo="#ffd070", halo_amt=0.5)
    return finish_mark(img, "#e8b040")


@H("breath")
def breath():
    img = medal("#101c2c", "#1c3450", 853, glow="#8ac0e8")
    for sx in (-1, 1):
        px = x * sx
        lobe = ellipse(0.26, 0.14, 0.24, 0.44, *xf(px, y, 0, 0, -0.1, 0.26, 0.14))
        img = o(img, lobe, "#3a5a78", "#c8e4f4", "#ffffff", 0.2, outline=0.05)
    img = o(img, box(0, -0.38, 0.045, 0.22), "#3a5a78", "#d8ecf8", outline=0.04)
    return finish_mark(img, "#80b0d0")


@H("combo")
def combo():
    img = medal("#2a1030", "#501a58", 854, glow="#ff80ff")
    star = []
    for k in range(10):
        a = -np.pi / 2 + k * np.pi / 5
        rr = 0.62 if k % 2 == 0 else 0.26
        star.append((rr * np.cos(a), rr * np.sin(a)))
    img = o(img, poly(star), "#8a2a90", "#ffd0ff", "#ffffff", 0.14, outline=0.055, halo="#ff90ff", halo_amt=0.5)
    return finish_mark(img, "#d080e0")


@H("core_gem")
def core_gem():
    """The staff core on the Bolt slot: a pale faceted gem the hotbar tints with the core's colour (16 px)."""
    gem = poly([(-0.42, -0.62), (0.42, -0.62), (0.78, -0.16), (0.0, 0.8), (-0.78, -0.16)])
    img = np.zeros((x.shape[0], x.shape[1], 3)) + C(INK)
    lit = np.clip(0.62 + 0.3 * ss(-0.62, -0.16, -y) * 0 + 0.28 * ((-x * 0.6 - y * 0.5)), 0.35, 1.0)
    face = np.where(y < -0.16, 0.92 - 0.25 * (np.abs(x) > 0.42), np.where(x < 0, 0.55, 0.78))
    face = face * (0.9 + 0.2 * ss(0.4, -0.4, x + y * 0.5))
    col = np.dstack([face, face, face])
    img = over(img, col, smooth(gem + 0.0))
    for pts in ([(-0.78, -0.16), (0.78, -0.16)], [(-0.42, -0.62), (-0.2, -0.16), (0.0, 0.8)], [(0.42, -0.62), (0.2, -0.16), (0.0, 0.8)], [(-0.2, -0.16), (0.0, -0.62), (0.2, -0.16)]):
        img = over(img, C("#1a1a22"), smooth(polyline(pts) - 0.03) * smooth(gem + 0.02) * 0.7)
    img = add(img, C("#ffffff"), np.exp(-np.hypot(x + 0.22, y + 0.42) / 0.08) * 0.8 * smooth(gem))
    alpha = smooth(gem - 0.1)
    return np.dstack([np.clip(img, 0, 1), alpha])
