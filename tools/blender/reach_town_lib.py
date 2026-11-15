"""The Far Reaches' towns (tools/blender/reach_towns.py): the materials they are made of and the joinery they share.

Godot coordinates throughout (x right, y up, +z the front of a piece), 1 unit = 1 m, origin on the ground at the
middle of the piece, like r37_south_lib / r37_wall_lib. Textures are made here from spectral noise (nothing is
downloaded): lime plaster over daub, split stone slates, hewn oak, river-reed thatch, woven wattle, dry-laid
fieldstone, hay. Buildings are at World-of-Warcraft proportions (scale_pilot.gd): doors 2.6-3.2 m, storeys 3.6-4.2 m.

  T(name, mats)       a W (r37_wall_lib: per-face tints, weathering in vertex colour) that also keeps collision boxes
  T.colbox            a collision box in the piece's frame (written to core/world/realm/reach_towns_boxes.gd)
  T.gable / T.thatch_gable / T.hip   roofs with real thickness, eaves and a ridge
  T.frame_face        posts, rails and braces laid on a plastered face
  T.window / T.door   openings with frames, sills, shutters, lit glass ("window_glass": the game swaps its glow)
  T.log               a round, slightly crooked pole (piles, stilts, rails, rafters)
  far_piece           a low silhouette for FarDetail (walls and roof only, one material)
  turnaround          Workbench stills of a piece from four sides (the review the hero-asset bar asks for)
"""
import math
import os
import numpy as np
import bpy
from mathutils import Vector, Matrix
import r37_south_lib as L
from r37_south_lib import fbm, smooth, tint, hash3
from r37_wall_lib import W, rng, lerp, clamp

L.TEX_DIR = os.path.join(L.BLEND_DIR, "textures", "reach_towns")

TINT = {"damp": (0.82, 0.86, 0.86), "pale": (1.0, 0.98, 0.94), "warm": (1.0, 0.9, 0.78), "dark": (0.7, 0.72, 0.74),
        "plain": (0.92, 0.92, 0.92), "old": (0.78, 0.76, 0.72), "sun": (1.0, 0.95, 0.85)}


# ==================================================================================================================
# textures
# ==================================================================================================================

def tex_plaster(n, seed):
    """Lime plaster over daub, many coats: a soft trowelled relief, blotches where a coat came away and the brown daub
    shows, hairline cracks, grey with weather. -> albedo, height, rough."""
    big = fbm(n, 2.8, seed)
    mid = fbm(n, 1.9, seed + 1)
    fine = fbm(n, 1.4, seed + 2)
    trowel = fbm(n, 2.2, seed + 3, aniso_u=3.5)
    lost = smooth(fbm(n, 2.6, seed + 4) + 0.25 * (fine - 0.5), 0.77, 0.83)          # coat gone: the daub shows
    cr = 1.0 - np.abs(fbm(n, 2.3, seed + 5, aniso=1.6) * 2.0 - 1.0)
    crack = smooth(cr, 0.9, 0.975) * (1.0 - lost)
    height = np.clip(0.6 + 0.12 * (trowel - 0.5) + 0.1 * (mid - 0.5) + 0.05 * (fine - 0.5) - 0.3 * lost - 0.25 * crack, 0.0, 1.0)
    tone = np.clip(0.55 + 0.3 * (big - 0.5) + 0.18 * (mid - 0.5) + 0.08 * (fine - 0.5), 0.0, 1.0)
    alb = tint(tone, (0.34, 0.32, 0.29), (0.6, 0.57, 0.51))
    daub = tint(np.clip(0.5 + 0.5 * (fine - 0.5), 0, 1), (0.2, 0.15, 0.1), (0.36, 0.28, 0.19))
    alb = alb * (1.0 - lost[..., None]) + daub * lost[..., None]
    alb *= (1.0 - 0.45 * crack)[..., None]
    streak = smooth(fbm(n, 2.4, seed + 6, aniso=9.0), 0.6, 0.92)
    alb *= (1.0 - 0.22 * streak)[..., None]
    rough = np.clip(0.9 + 0.08 * (fine - 0.5), 0.7, 1.0)
    return alb, height, rough


def tex_slate(n, seed, rows=12):
    """Split stone slates laid in courses (a tile is ~2.4 m: courses ~0.2 m), each row half a slate over, the lower edge
    of each slate thick and shadowed, chipped corners, lichen. Rows run along u (the eaves); v runs up the slope."""
    rng_ = np.random.default_rng(seed)
    out_h = np.zeros((n, n))
    sid = np.zeros((n, n), dtype=np.int32)
    rh = n // rows
    bid = 1
    for r in range(rows):
        y0 = r * rh
        y1 = n if r == rows - 1 else y0 + rh
        x = int(rng_.integers(0, n))
        tot = 0
        while tot < n:
            w = int(rng_.uniform(0.9, 1.6) * rh)
            cols = (np.arange(w) + x + tot) % n
            t = (np.arange(y1 - y0) / max(y1 - y0 - 1, 1))[:, None]           # 0 at the slate's lower edge, 1 under the row above
            ramp = 0.85 - 0.45 * t
            edge = np.minimum(np.arange(w), w - 1 - np.arange(w))[None, :]
            side = smooth(edge.astype(float), 0.0, n * 0.006)
            out_h[y0:y1][:, cols] = ramp * (0.6 + 0.4 * side) + rng_.uniform(-0.06, 0.06)
            sid[y0:y1][:, cols] = bid
            bid += 1
            tot += w
    # the lower edge's shadow line (the course over it)
    yy = (np.arange(n) % rh)[:, None] * np.ones((1, n))
    shadow = smooth(yy, 0.0, rh * 0.18)
    tone_r = rng_.uniform(-1.0, 1.0, bid + 1)[sid]
    mid = fbm(n, 1.8, seed + 2)
    fine = fbm(n, 1.4, seed + 3)
    height = np.clip(out_h + 0.08 * (mid - 0.5) + 0.04 * (fine - 0.5), 0.0, 1.0)
    tone = np.clip(0.5 + 0.22 * tone_r + 0.2 * (mid - 0.5) + 0.08 * (fine - 0.5), 0.0, 1.0)
    alb = tint(tone, (0.16, 0.165, 0.17), (0.40, 0.40, 0.40))
    alb *= (0.45 + 0.55 * shadow)[..., None]
    lich = smooth(fbm(n, 2.2, seed + 4) * (0.7 + 0.3 * fine), 0.6, 0.8)
    alb = alb * (1.0 - 0.6 * lich[..., None]) + np.array([0.44, 0.45, 0.32])[None, None, :] * 0.6 * lich[..., None]
    moss = smooth(fbm(n, 2.5, seed + 5), 0.7, 0.86) * (1.0 - shadow * 0.6)
    alb = alb * (1.0 - 0.6 * moss[..., None]) + np.array([0.12, 0.16, 0.07])[None, None, :] * 0.6 * moss[..., None]
    rough = np.clip(0.8 + 0.15 * (fine - 0.5) - 0.1 * lich, 0.55, 1.0)
    return alb, height, rough


def tex_beam(n, seed):
    """Hewn oak gone silver-brown: grain along u, adze scallops across it, deep checks, dark end grain in the cracks."""
    grain = fbm(n, 1.3, seed, aniso_u=18.0)
    fine = fbm(n, 1.0, seed + 1, aniso_u=10.0)
    adze = 0.5 + 0.5 * np.sin((np.arange(n)[None, :] / n) * math.pi * 2.0 * 9.0 + fbm(n, 2.5, seed + 2) * 5.0)
    adze = adze * np.ones((n, 1))
    ck = 1.0 - np.abs(fbm(n, 2.0, seed + 3, aniso_u=12.0) * 2.0 - 1.0)
    check = smooth(ck, 0.92, 0.985)
    big = fbm(n, 2.6, seed + 4)
    height = np.clip(0.55 + 0.2 * (grain - 0.5) + 0.12 * (adze - 0.5) + 0.06 * (fine - 0.5) - 0.45 * check, 0.0, 1.0)
    tone = np.clip(0.5 + 0.35 * (grain - 0.5) + 0.25 * (big - 0.5) + 0.1 * (adze - 0.5), 0.0, 1.0)
    alb = tint(tone, (0.12, 0.09, 0.065), (0.42, 0.34, 0.25))
    silver = smooth(fbm(n, 2.2, seed + 5, aniso_u=4.0), 0.5, 0.82)
    alb = alb * (1.0 - 0.35 * silver[..., None]) + np.array([0.36, 0.35, 0.33])[None, None, :] * 0.35 * silver[..., None]
    alb *= (1.0 - 0.7 * check)[..., None]
    rough = np.clip(0.86 + 0.1 * (fine - 0.5), 0.6, 1.0)
    return alb, height, rough


def tex_reed(n, seed):
    """River-reed thatch, combed and weathered: long stems down the slope (v), soft irregular courses (each a bundle's
    butts), grey-gold, darker and greener in the hollows, rain-streaked."""
    straw = fbm(n, 1.0, seed, aniso=18.0)
    stems = fbm(n, 0.7, seed + 6, aniso=30.0)
    warp = fbm(n, 2.4, seed + 1)
    cw = (np.arange(n)[:, None] / n) * 7.0 + warp * 1.6
    course = np.abs((cw % 1.0) - 0.5) * 2.0                      # 0 at a course's butt line, 1 between
    course = smooth(course, 0.0, 0.35)
    mid = fbm(n, 2.2, seed + 2)
    clump = fbm(n, 1.6, seed + 8, aniso=3.0)
    height = np.clip(0.45 * straw + 0.2 * stems + 0.12 * course + 0.15 * clump + 0.08 * mid, 0.0, 1.0)
    tone = np.clip(0.32 + 0.4 * straw + 0.22 * stems + 0.14 * (mid - 0.5) + 0.12 * (clump - 0.5), 0.0, 1.0)
    alb = tint(tone, (0.13, 0.11, 0.075), (0.48, 0.42, 0.29))
    grey = smooth(fbm(n, 2.0, seed + 7), 0.45, 0.8)
    alb = alb * (1.0 - 0.3 * grey[..., None]) + np.array([0.33, 0.32, 0.29])[None, None, :] * 0.3 * grey[..., None]
    moss = smooth(fbm(n, 2.0, seed + 3), 0.68, 0.86)
    alb = alb * (1.0 - 0.4 * moss[..., None]) + np.array([0.09, 0.12, 0.05])[None, None, :] * 0.4 * moss[..., None]
    streak = smooth(fbm(n, 1.7, seed + 9, aniso=10.0), 0.55, 0.9)
    alb *= (1.0 - 0.12 * streak)[..., None]
    alb *= (0.88 + 0.12 * course)[..., None]
    rough = np.clip(0.92 + 0.08 * (straw - 0.5), 0.7, 1.0)
    return alb, height, rough


def tex_wattle(n, seed):
    """Woven wattle: hazel rods round upright stakes, over and under, grey bark, gaps dark."""
    rows = 16
    cols = 6
    y = (np.arange(n)[:, None] / n) * rows
    x = (np.arange(n)[None, :] / n) * cols
    rod = 0.5 + 0.5 * np.cos((y % 1.0 - 0.5) * math.pi * 2.0)
    weave = np.sin(x * math.pi + np.floor(y) * math.pi) * 0.5 + 0.5
    stake = smooth(1.0 - np.abs((x % 1.0) - 0.5) * 2.0, 0.85, 0.97)
    fine = fbm(n, 1.2, seed, aniso_u=6.0)
    big = fbm(n, 2.5, seed + 1)
    height = np.clip(0.5 * rod * (0.6 + 0.4 * weave) + 0.25 * stake + 0.1 * (fine - 0.5), 0.0, 1.0)
    gap = smooth(rod, 0.08, 0.3)
    tone = np.clip(0.45 + 0.3 * (fine - 0.5) + 0.25 * (big - 0.5) + 0.15 * weave, 0.0, 1.0)
    alb = tint(tone, (0.11, 0.09, 0.07), (0.42, 0.37, 0.3))
    alb *= (0.25 + 0.75 * gap)[..., None]
    rough = np.clip(0.9 + 0.08 * (fine - 0.5), 0.7, 1.0)
    return alb, height, rough


def tex_drystone(n, seed):
    """Dry-laid fieldstone: rounded stones of every size jammed together, dark gaps, lichen, rust stains."""
    rg = np.random.default_rng(seed)
    k = 18
    gx = (np.arange(k * k) % k + 0.5) * n / k + rg.uniform(-0.38, 0.38, k * k) * n / k
    gy = (np.arange(k * k) // k + 0.5) * n / k + rg.uniform(-0.38, 0.38, k * k) * n / k
    ys, xs = np.mgrid[0:n, 0:n]
    best = np.full((n, n), 1e9)
    second = np.full((n, n), 1e9)
    bid = np.zeros((n, n), dtype=np.int32)
    for i in range(k * k):
        for ox in (-n, 0, n):
            for oy in (-n, 0, n):
                cx = gx[i] + ox
                cy = gy[i] + oy
                if cx < -n * 0.2 or cx > n * 1.2 or cy < -n * 0.2 or cy > n * 1.2:
                    continue
                d = (xs - cx) ** 2 + ((ys - cy) * 1.9) ** 2
                m = d < best
                second = np.where(m, best, np.minimum(second, d))
                bid = np.where(m, i, bid)
                best = np.where(m, d, best)
    edge = np.sqrt(second) - np.sqrt(best)
    face = smooth(edge, n * 0.0025, n * 0.016)
    rr = rg.uniform(0, 1, k * k)[bid]
    big = fbm(n, 2.6, seed + 1)
    mid = fbm(n, 1.6, seed + 2)
    fine = fbm(n, 1.9, seed + 3)
    height = np.clip(face * (0.55 + 0.2 * rr + 0.15 * (mid - 0.5)) + 0.05 * (fine - 0.5), 0.0, 1.0)
    tone = np.clip(0.45 + 0.35 * (rr - 0.5) + 0.25 * (big - 0.5), 0.0, 1.0)
    alb = tint(tone, (0.19, 0.18, 0.165), (0.52, 0.5, 0.45))
    alb *= (0.42 + 0.58 * face)[..., None]
    lich = smooth(fbm(n, 2.2, seed + 4) * (0.7 + 0.3 * fine), 0.58, 0.8) * face
    alb = alb * (1.0 - 0.55 * lich[..., None]) + np.array([0.46, 0.5, 0.3])[None, None, :] * 0.55 * lich[..., None]
    rough = np.clip(0.88 + 0.1 * (fine - 0.5), 0.6, 1.0)
    return alb, height, rough


def tex_hay(n, seed):
    """Hay and straw in a rick: loose crossing stalks, pale gold gone grey on top."""
    a = fbm(n, 0.9, seed, aniso=7.0)
    b = fbm(n, 0.9, seed + 1, aniso_u=7.0)
    mid = fbm(n, 2.0, seed + 2)
    height = np.clip(0.5 * np.maximum(a, b) + 0.3 * mid, 0.0, 1.0)
    tone = np.clip(0.35 + 0.4 * np.maximum(a, b) + 0.3 * (mid - 0.5), 0.0, 1.0)
    alb = tint(tone, (0.2, 0.16, 0.08), (0.62, 0.52, 0.3))
    rot = smooth(fbm(n, 2.4, seed + 3), 0.6, 0.85)
    alb = alb * (1.0 - 0.5 * rot[..., None]) + np.array([0.18, 0.17, 0.14])[None, None, :] * 0.5 * rot[..., None]
    rough = np.full_like(mid, 0.95)
    return alb, height, rough


def tex_sacking(n, seed):
    """Coarse sacking and homespun gone to rags: a loose weave, darns, stains, mould at the folds."""
    t = np.arange(n) / n
    wx = 0.5 + 0.5 * np.sin(t[None, :] * math.pi * 2.0 * 90.0)
    wy = 0.5 + 0.5 * np.sin(t[:, None] * math.pi * 2.0 * 90.0)
    weave = (wx * 0.5 + wy * 0.5) * np.ones((n, n))
    big = fbm(n, 2.6, seed)
    mid = fbm(n, 1.8, seed + 1)
    stain = smooth(fbm(n, 2.4, seed + 2), 0.6, 0.85)
    height = np.clip(0.5 + 0.25 * (weave - 0.5) + 0.2 * (mid - 0.5), 0.0, 1.0)
    tone = np.clip(0.5 + 0.3 * (big - 0.5) + 0.2 * (mid - 0.5) + 0.08 * (weave - 0.5), 0.0, 1.0)
    alb = tint(tone, (0.07, 0.06, 0.045), (0.27, 0.22, 0.16))
    alb *= (1.0 - 0.45 * stain)[..., None]
    rough = np.full_like(big, 0.97)
    return alb, height, rough


def emissive(name, color, strength):
    m = L.flat(name, (0.02, 0.03, 0.04), 0.5)
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Emission Color"].default_value = (*color, 1.0)
    b.inputs["Emission Strength"].default_value = strength
    return m


_MATS = {}


def mats():
    """Every town material, made once. Keys are what the builders name; the glb carries the material names."""
    if _MATS:
        return _MATS
    st = L.ashlar("RT_Stone", 8101, rows=7, warm=0.03)
    rub = L.pbr("RT_Rubble", tex_drystone(512, 8102), 2.4)
    rub["uv_mul"] = 1.7
    pl = L.pbr("RT_Plaster", tex_plaster(512, 8103), 1.0)
    pl["uv_mul"] = 0.7
    bm = L.pbr("RT_Beam", tex_beam(512, 8104), 2.2)
    bm["uv_mul"] = 1.6
    pk = L.pbr("RT_Plank", L.tex_planks(512, 8105), 2.4)
    pk["uv_mul"] = 1.4
    sl = L.pbr("RT_Slate", tex_slate(1024, 8106), 2.2)
    sl["uv_mul"] = 2.0
    th = L.pbr("RT_Thatch", tex_reed(1024, 8107), 3.0)
    th["uv_mul"] = 1.7
    wa = L.pbr("RT_Wattle", tex_wattle(512, 8108), 3.0)
    wa["uv_mul"] = 4.5
    hy = L.pbr("RT_Hay", tex_hay(512, 8109), 2.0)
    hy["uv_mul"] = 3.0
    cl = L.pbr("RT_Cloth", tex_sacking(512, 8110), 1.5)
    cl["uv_mul"] = 2.5
    _MATS.update({
        "stone": st, "rubble": rub, "plaster": pl, "beam": bm, "plank": pk, "slate": sl, "thatch": th, "wattle": wa,
        "hay": hy,
        "iron": L.flat("RT_Iron", (0.075, 0.07, 0.065), 0.55, 0.85),
        "dark": L.flat("RT_Dark", (0.008, 0.008, 0.01), 1.0),
        "rope": L.flat("RT_Rope", (0.11, 0.085, 0.055), 0.95),
        "cloth": cl,
        "net": L.flat("RT_Net", (0.035, 0.034, 0.03), 0.95),
        "fish": L.flat("RT_Fish", (0.11, 0.11, 0.1), 0.45, 0.2),
        "window_glass": emissive("window_glass", (1.0, 0.62, 0.3), 1.1),
        "lamp_glass": emissive("lamp_glass", (1.0, 0.72, 0.4), 2.2),
        "far": L.flat("RT_Far", (0.16, 0.17, 0.2), 1.0),
    })
    return _MATS


# ==================================================================================================================
# the builder
# ==================================================================================================================

COLS = {}          # piece name -> [[cx, cy, cz, sx, sy, sz, yaw]] collision boxes in its frame
DATA = {}          # numbers the game reads (written beside the boxes)


class T(W):
    def __init__(self, name, seed=0, damp=1.0):
        super().__init__(name, mats(), seed, damp=damp)
        self.cols = COLS.setdefault(name, [])

    # -- collision ---------------------------------------------------------------------------------------------------
    def colbox(self, c, size, yaw=0.0):
        self.cols.append([round(c[0], 3), round(c[1], 3), round(c[2], 3), round(size[0], 3), round(size[1], 3), round(size[2], 3), round(yaw, 4)])

    # -- poles -------------------------------------------------------------------------------------------------------
    def log(self, a, b, r0, r1=None, mat="beam", sides=7, seed=0, crook=0.06, bark=1.4):
        """A round pole from a to b, slightly crooked (a bent midpoint), tapering r0 -> r1."""
        r1 = r0 * 0.85 if r1 is None else r1
        a = Vector(a)
        b = Vector(b)
        m = (a + b) * 0.5
        off = Vector((hash3(m.x, m.y, m.z, seed), 0.0, hash3(m.z, m.x, m.y, seed + 3))) * crook * (b - a).length
        if crook > 0.0 and (b - a).length > 1.5:
            self.tube_path([a, m + off, b], [r0, (r0 + r1) * 0.5, r1], mat, sides=sides, bark=bark, jit=r0 * 0.12, seed=seed)
        else:
            self.tube(a, b, r0, r1, mat, sides=sides, bark=bark, jit=r0 * 0.12, seed=seed)

    def beam(self, a, b, w, h, mat="beam", jit=0.012):
        """A squared timber from a to b (w across, h deep; h is vertical for a level beam)."""
        a = Vector(a)
        b = Vector(b)
        d = b - a
        Ln = d.length
        yaw = math.atan2(d.x, d.z)
        pitch = -math.asin(clamp(d.y / max(Ln, 1e-6), -1.0, 1.0))
        c = (a + b) * 0.5
        self.box((c.x, c.y, c.z), (w, h, Ln), mat, yaw=yaw, pitch=pitch, cuts=0, jit=jit, uv=1.0)

    # -- roofs -------------------------------------------------------------------------------------------------------
    def gable(self, x0, x1, hd, y_eave, y_ridge, mat="slate", over=0.6, thick=0.32, sag=0.08, seed=0, ridge=True, barge=True, cz=0.0, gap=None):
        """A pitched roof along x (ridge at z = cz) from x0 to x1 over walls hd either side of cz: a thick shell, the eaves
        `over` past the walls, the ridge sagging `sag` in the middle (old timbers), a ridge roll and barge boards.
        gap = (xa, xb): the back slope (-z) is left off there (stripped to its rafters by the caller)."""
        run = hd + over
        rise = y_ridge - y_eave
        drop = rise * over / hd                                        # the eaves fall below the wall plate
        ye = y_eave - drop
        k = thick / math.cos(math.atan2(rise, hd))
        prof = [(cz - run, ye), (cz, y_ridge), (cz + run, ye), (cz + run, ye - thick), (cz, y_ridge - k), (cz - run, ye - thick)]
        front = [(cz, y_ridge), (cz + run, ye), (cz + run, ye - thick), (cz, y_ridge - k)]
        spans = [(x0, x1, prof)] if gap is None else [(x0, gap[0], prof), (gap[0], gap[1], front), (gap[1], x1, prof)]
        faces = []
        for (xa, xb, pr) in spans:
            nx = max(1, int(math.ceil((xb - xa) / 1.2)))
            faces += self.prism_x(pr, xa, xb, mat, uv=1.0, jit=0.0, seed=seed, dens=1.0, xstep=(xb - xa) / nx)
        if sag > 0.0:
            done = set()
            for f in faces:
                for v in f.verts:
                    if v in done:
                        continue
                    done.add(v)
                    t = (v.co.x - x0) / max(x1 - x0, 1e-6)
                    s = math.sin(clamp(t, 0.0, 1.0) * math.pi)
                    hz = 1.0 - min(abs(v.co.z - cz) / run, 1.0)
                    v.co.y -= sag * s * (0.35 + 0.65 * hz)
                    v.co += Vector((hash3(v.co.x, v.co.y, v.co.z, seed + 11) * 0.03, hash3(v.co.z, v.co.x, v.co.y, seed + 12) * 0.05, 0.0))
        if ridge:
            nseg = max(1, int((x1 - x0) / 1.4))
            for i in range(nseg):
                xa = x0 + (x1 - x0) * i / nseg
                xb = x0 + (x1 - x0) * (i + 1) / nseg
                t = ((xa + xb) * 0.5 - x0) / max(x1 - x0, 1e-6)
                yy = y_ridge + 0.06 - sag * math.sin(t * math.pi)
                self.box(((xa + xb) * 0.5, yy, cz), (xb - xa + 0.04, 0.22, 0.42), mat, cuts=0, jit=0.01, uv=1.0, pitch=0.0)
        if barge:
            for xe in (x0 - 0.02, x1 + 0.02):
                for sg in (-1, 1):
                    self.beam((xe, ye + 0.1, cz + sg * run), (xe, y_ridge + 0.1, cz), 0.14, 0.32, "beam")
        return ye

    def thatch_gable(self, x0, x1, hd, y_eave, y_ridge, over=0.9, thick=0.55, sag=0.12, seed=0, cz=0.0, end_over=0.7, horns=0.0):
        """A reed thatch along x: a deep rounded eave (the bundles' butts), a thick body, the gable ends swept over,
        a rolled ridge, optional crossed ridge-poles at both ends (`horns` metres long, the fishers' way)."""
        run = hd + over
        rise = y_ridge - y_eave
        drop = rise * over / hd
        ye = y_eave - drop
        k = thick / math.cos(math.atan2(rise, hd))
        prof = [(cz - run - 0.08, ye + 0.12), (cz - run + 0.15, ye + 0.42), (cz, y_ridge + 0.2), (cz + run - 0.15, ye + 0.42), (cz + run + 0.08, ye + 0.12),
                (cz + run, ye - 0.12), (cz + run - 0.35, ye - thick * 0.55), (cz, y_ridge - k), (cz - run + 0.35, ye - thick * 0.55), (cz - run, ye - 0.12)]
        xa = x0 - end_over
        xb = x1 + end_over
        faces = self.prism_x(prof, xa, xb, "thatch", uv=1.0, jit=0.0, seed=seed, dens=0.9, xstep=1.0)
        done = set()
        for f in faces:
            for v in f.verts:
                if v in done:
                    continue
                done.add(v)
                t = (v.co.x - xa) / max(xb - xa, 1e-6)
                s = math.sin(clamp(t, 0.0, 1.0) * math.pi)
                v.co.y -= sag * s
                # the ends swept down: the gable's top is pulled in and rounded (a thatch never ends in a knife edge)
                e = max(0.0, 1.0 - min(v.co.x - xa, xb - v.co.x) / 1.1)
                hgt = clamp((v.co.y - ye) / max(rise, 0.1), 0.0, 1.0)
                v.co.x += (1.0 if v.co.x < (xa + xb) * 0.5 else -1.0) * e * e * 0.45 * hgt
                v.co.y -= e * e * 0.25 * hgt
                n1 = hash3(v.co.x * 0.7, v.co.y, v.co.z * 0.7, seed + 21)
                v.co += Vector((0.0, n1 * 0.08, hash3(v.co.z, v.co.x, v.co.y, seed + 22) * 0.06))
        # the ridge roll: a rounded log of thatch with liggers (split hazel) pinned across it
        self.tube_path([(xa + 0.4, y_ridge + 0.12 - sag * 0.2, cz), ((xa + xb) * 0.5, y_ridge + 0.14 - sag, cz), (xb - 0.4, y_ridge + 0.12 - sag * 0.2, cz)],
                       [0.34, 0.38, 0.34], "thatch", sides=8, bark=1.2, jit=0.03, seed=seed + 5)
        n = max(2, int((xb - xa) / 0.55))
        for i in range(n):
            x = xa + 0.5 + (xb - xa - 1.0) * i / (n - 1)
            t = (x - xa) / (xb - xa)
            y = y_ridge + 0.14 - sag * math.sin(t * math.pi)
            for sg in (-1, 1):
                self.beam((x, y + 0.2, cz), (x, y - 0.25, cz + sg * 0.42), 0.04, 0.04, "beam", jit=0.0)
        for sg in (-1, 1):
            self.beam((xa + 0.3, y_ridge - 0.12 - sag * 0.4, cz + sg * 0.36), (xb - 0.3, y_ridge - 0.12 - sag * 0.4, cz + sg * 0.36), 0.05, 0.05, "beam", jit=0.004)
        if horns > 0.0:
            for xe, sg in ((xa + 0.25, -1.0), (xb - 0.25, 1.0)):
                for side in (-1, 1):
                    a = (xe, y_ridge - 0.9, cz - side * 0.9)
                    b = (xe + sg * 0.2, y_ridge + horns, cz + side * horns * 0.55)
                    self.log(a, b, 0.09, 0.05, "beam", sides=6, seed=seed + int(xe) + side, crook=0.08)
        return ye

    def hip(self, cx, cz, hx, hz, y0, y1, mat="thatch", ridge_k=0.42, lip=0.3, seed=0):
        """A hipped roof: a rectangle hx x hz (half sizes) at y0 drawn up to a ridge along x of half length
        hx - hz * (1 - ridge_k) at y1. lip = the eave's thickness (a ring under the slope)."""
        rx = max(0.15, hx - hz * (1.0 - ridge_k))
        self.frustum(cx, cz, (hx, hz), (rx, 0.12), y0, y1, mat, uv=1.0, jit=0.05 if mat == "thatch" else 0.02, seed=seed, levels=5)
        if lip > 0.0:
            self.frustum(cx, cz, (hx + 0.06, hz + 0.06), (hx - 0.08, hz - 0.08), y0 - lip, y0 + 0.05, mat, uv=1.0, jit=0.02, seed=seed + 1, levels=2)

    def dormer(self, x, zf, y0, w=2.2, wall_h=1.7, rise=1.2, depth=3.0, roof="thatch", lit=True, seed=0):
        """A dormer through a roof whose wall plane is zf (it looks +z): a framed front with a window from y0, cheeks
        running back into the roof, and a little roof of its own (ridge along z) `depth` metres back."""
        hw = w / 2
        self.box((x, y0 + wall_h / 2, zf - depth / 2 + 0.1), (w, wall_h, depth), "plaster", cuts=1, jit=0.01)
        self.frame_face(x - hw + 0.08, x + hw - 0.08, zf + 0.1, y0, y0 + wall_h, face=1, bays=2, rails=(), braces=False, w=0.16)
        self.window(x, y0 + wall_h * 0.5, zf + 0.12, w=w * 0.48, h=wall_h * 0.55, face=1, lit=lit, frame="beam", sill="beam", mull=False, shutters=False)
        ye = y0 + wall_h

        def rf():
            if roof == "thatch":
                self.thatch_gable(-depth + 0.2, 0.45, hw, ye, ye + rise, over=0.35, thick=0.32, sag=0.02, seed=seed, end_over=0.2)
            else:
                self.gable(-depth + 0.2, 0.55, hw, ye, ye + rise, mat=roof, over=0.25, thick=0.18, sag=0.0, seed=seed, barge=True)
        grouped(self, rf, -math.pi / 2, (x, 0.0, zf))

    # -- walls, frames, openings ---------------------------------------------------------------------------------------
    def frame_face(self, x0, x1, z, y0, y1, face=1, bays=3, rails=(0.5,), braces=True, w=0.22, mat="beam", proud=0.07):
        """Close-studded framing laid on a face at z (face = +1 front, -1 back) between x0 and x1, y0 to y1."""
        zf = z + face * proud
        nb = max(1, bays)
        for i in range(nb + 1):
            x = x0 + (x1 - x0) * i / nb
            self.box((x, (y0 + y1) / 2, zf), (w, y1 - y0, 0.16), mat, cuts=0, jit=0.012)
        self.box(((x0 + x1) / 2, y0 + 0.1, zf), (x1 - x0 + w, 0.22, 0.17), mat, cuts=0, jit=0.01)
        self.box(((x0 + x1) / 2, y1 - 0.1, zf), (x1 - x0 + w, 0.26, 0.18), mat, cuts=0, jit=0.01)
        for r in rails:
            self.box(((x0 + x1) / 2, lerp(y0, y1, r), zf), (x1 - x0, 0.18, 0.15), mat, cuts=0, jit=0.01)
        if braces and nb >= 2:
            bw = (x1 - x0) / nb
            self.beam((x0 + 0.1, y1 - 0.2, zf), (x0 + bw - 0.1, lerp(y0, y1, rails[0] if rails else 0.5) + 0.1, zf), 0.16, 0.14, mat)
            self.beam((x1 - 0.1, y1 - 0.2, zf), (x1 - bw + 0.1, lerp(y0, y1, rails[0] if rails else 0.5) + 0.1, zf), 0.16, 0.14, mat)

    def frame_side(self, z0, z1, x, y0, y1, face=1, bays=2, rails=(0.5,), w=0.22, mat="beam", proud=0.07):
        """frame_face on an end wall at x (face = +1 east, -1 west), between z0 and z1."""
        xf = x + face * proud
        nb = max(1, bays)
        for i in range(nb + 1):
            zz = z0 + (z1 - z0) * i / nb
            self.box((xf, (y0 + y1) / 2, zz), (0.16, y1 - y0, w), mat, cuts=0, jit=0.012)
        self.box((xf, y0 + 0.1, (z0 + z1) / 2), (0.17, 0.22, z1 - z0 + w), mat, cuts=0, jit=0.01)
        self.box((xf, y1 - 0.1, (z0 + z1) / 2), (0.18, 0.26, z1 - z0 + w), mat, cuts=0, jit=0.01)
        for r in rails:
            self.box((xf, lerp(y0, y1, r), (z0 + z1) / 2), (0.15, 0.18, z1 - z0), mat, cuts=0, jit=0.01)

    def window(self, x, y, z, w=1.0, h=1.2, face=1, lit=True, shutters=True, frame="beam", sill="stone", yaw=0.0, mull=True, open_=0.9):
        """A window on a wall face whose plane is z (face +1 looks +z): glass set back, a frame, a mullion, a sill,
        shutters opened out. yaw turns the whole thing about its centre (for windows on end walls)."""
        def g(lx, ly, lz):
            ca, sa = math.cos(yaw), math.sin(yaw)
            return (x + lx * ca + lz * sa, ly, z + (-lx * sa + lz * ca))
        s = face
        self.box(g(0, y, -s * 0.08), (w, h, 0.05), "window_glass" if lit else "dark", yaw=yaw, cuts=0, jit=0.0)
        for sx in (-1, 1):
            self.box(g(sx * (w / 2 + 0.07), y, s * 0.04), (0.15, h + 0.2, 0.2), frame, yaw=yaw, cuts=0, jit=0.006)
        self.box(g(0, y + h / 2 + 0.1, s * 0.05), (w + 0.4, 0.2, 0.24), frame, yaw=yaw, cuts=0, jit=0.006)
        self.box(g(0, y - h / 2 - 0.08, s * 0.1), (w + 0.36, 0.14, 0.34), sill, yaw=yaw, cuts=0, jit=0.006)
        if mull:
            self.box(g(0, y, -s * 0.02), (0.08, h, 0.08), frame, yaw=yaw, cuts=0, jit=0.0)
            self.box(g(0, y + h * 0.1, -s * 0.02), (w, 0.07, 0.07), frame, yaw=yaw, cuts=0, jit=0.0)
        if shutters:
            for sx in (-1, 1):
                hw = w / 2
                a = sx * open_
                cx = sx * (w / 2 + 0.12) + sx * math.cos(a) * hw * 0.5
                cz = s * (0.14 + math.sin(abs(a)) * hw * 0.5)
                self.box(g(cx, y, cz), (hw, h, 0.06), "plank", yaw=yaw - sx * s * a, cuts=0, jit=0.0)
                self.box(g(cx, y + h * 0.3, cz + s * 0.04), (hw * 0.9, 0.06, 0.03), "iron", yaw=yaw - sx * s * a, cuts=0, jit=0.0)
                self.box(g(cx, y - h * 0.3, cz + s * 0.04), (hw * 0.9, 0.06, 0.03), "iron", yaw=yaw - sx * s * a, cuts=0, jit=0.0)

    def door(self, x, z, w=1.6, h=2.8, face=1, arch=False, step=0.0, ajar=0.0, frame="beam", yaw=0.0, studs=True):
        """A plank door in a wall plane z: a heavy frame (or a stone arch), the leaves, straps, a latch ring, a step."""
        def g(lx, ly, lz):
            ca, sa = math.cos(yaw), math.sin(yaw)
            return (x + lx * ca + lz * sa, ly, z + (-lx * sa + lz * ca))
        s = face
        self.box(g(0, step + h / 2, -s * 0.1), (w + 0.1, h, 0.12), "dark", yaw=yaw, cuts=0, jit=0.0)
        if ajar > 0.0:
            hw = w
            self.box(g(-w / 2 + math.cos(ajar) * hw / 2, step + h / 2 - 0.05, s * (-0.02 + math.sin(ajar) * hw / 2)), (hw, h - 0.1, 0.09), "plank", yaw=yaw + s * ajar, cuts=0, jit=0.0)
        else:
            self.box(g(0, step + h / 2 - 0.05, -s * 0.02), (w, h - 0.1, 0.1), "plank", yaw=yaw, cuts=0, jit=0.0)
            for yy in (0.25, 0.75):
                self.box(g(-w * 0.12, step + h * yy, s * 0.05), (w * 0.72, 0.09, 0.04), "iron", yaw=yaw, cuts=0, jit=0.0)
            self.box(g(w * 0.32, step + h * 0.48, s * 0.07), (0.1, 0.16, 0.05), "iron", yaw=yaw, cuts=0, jit=0.0)
            if studs:
                for i in range(4):
                    for j in range(2):
                        self.box(g(-w * 0.3 + i * w * 0.2, step + h * (0.35 + j * 0.3), s * 0.05), (0.05, 0.05, 0.04), "iron", yaw=yaw, cuts=0, jit=0.0)
        if arch and yaw == 0.0:
            # a relieving arch of voussoirs over the head (its spring at the frame's top)
            self.arch(x, step + h + 0.28, w * 0.75, 0.34, z - 0.2, z + s * 0.32, "stone", uv=1.5, n=4, tint=TINT["pale"], jit=0.006)
        for sx in (-1, 1):
            self.box(g(sx * (w / 2 + 0.11), step + h / 2, s * 0.05), (0.22, h + 0.05, 0.3), frame, yaw=yaw, cuts=0, jit=0.008)
        self.box(g(0, step + h + 0.14, s * 0.06), (w + 0.7, 0.3, 0.34), frame, yaw=yaw, cuts=0, jit=0.008)
        if step > 0.05:
            for k in range(int(round(step / 0.22))):
                hh = step - k * 0.22
                self.box(g(0, hh / 2, s * (0.35 + k * 0.32)), (w + 0.5 - k * 0.1, hh, 0.36), "stone", yaw=yaw, cuts=0, jit=0.012, tint=TINT["damp"])

    def chimney(self, x, z, y0, y1, w=1.1, d=0.9, mat="stone", pots=1):
        self.rect_solid(x - w / 2, x + w / 2, z - d / 2, z + d / 2, y0, y1, bat=(0.04,) * 4, uv=1.0, mat=mat, jit=0.02, seed=int(x * 7 + z * 3))
        self.rect_solid(x - w / 2 - 0.1, x + w / 2 + 0.1, z - d / 2 - 0.1, z + d / 2 + 0.1, y1, y1 + 0.18, uv=1.4, mat=mat, jit=0.01, tint=TINT["pale"])
        for i in range(pots):
            px = x + (i - (pots - 1) / 2) * 0.45
            self.frustum(px, z, 0.17, 0.13, y1 + 0.18, y1 + 0.7, "stone", round_n=7, levels=2, jit=0.0, tint=TINT["warm"])
            self.frustum(px, z, 0.1, 0.1, y1 + 0.69, y1 + 0.71, "dark", round_n=7, levels=2, jit=0.0)

    def steps(self, x, z0, y_top, w, run=0.32, rise=0.2, face=1, mat="stone", yaw=0.0, col=True):
        """A flight of solid steps from y_top down towards face (+z), starting at z0 (the top step's back edge)."""
        n = max(1, int(round(y_top / rise)))
        rr = y_top / n
        for i in range(n):
            yt = y_top - i * rr
            zc = z0 + face * (i + 0.5) * run
            self.box((x, (yt - 0.6) / 2, zc), (w, yt + 0.6, run + 0.02), mat, cuts=0, jit=0.01, tint=TINT["damp"] if mat in ("stone", "rubble") else None, yaw=yaw)
        if col:
            # a ramp of boxes for the body (each step its own box, so the player climbs it)
            for i in range(n):
                yt = y_top - i * rr
                zc = z0 + face * (i + 0.5) * run
                self.colbox((x, yt / 2, zc), (w, yt, run + 0.02), yaw)


def grouped(b, fn, yaw, at):
    """Run fn (which builds at the origin, facing +z) and then turn what it made by yaw about y and move it to `at`.
    Collision boxes it added are carried the same way."""
    n0 = len(b.bm.verts)
    c0 = len(b.cols)
    fn()
    b.bm.verts.ensure_lookup_table()
    R = Matrix.Rotation(yaw, 3, 'Y')
    for v in list(b.bm.verts)[n0:]:
        v.co = R @ Vector(v.co) + Vector(at)
    for r in b.cols[c0:]:
        p = R @ Vector((r[0], r[1], r[2])) + Vector(at)
        r[0], r[1], r[2] = round(p.x, 3), round(p.y, 3), round(p.z, 3)
        r[6] = round(r[6] + yaw, 4)


def lathe_at(b, cx, cz, y0, profile, mat, sides=16, jit=0.0, seed=0, bark=2.0):
    """A solid of revolution (profile [(radius, y)] from the bottom) standing at (cx, y0, cz)."""
    n0 = len(b.bm.verts)
    jf = (lambda an, y: 1.0 + jit * hash3(math.cos(an) * 3.0, y * 2.0, math.sin(an) * 3.0, seed)) if jit > 0.0 else None
    b.lathe(profile, mat, sides=sides, bark=bark, jit=jf)
    b.bm.verts.ensure_lookup_table()
    for v in list(b.bm.verts)[n0:]:
        v.co = Vector((v.co.x + cx, v.co.y + y0, v.co.z + cz))
    # caps
    for (r, y) in (profile[0], profile[-1]):
        if r > 0.02:
            b.frustum(cx, cz, r, r, y0 + y - 0.005, y0 + y + 0.005, mat, round_n=sides, levels=2, jit=0.0)


def far_piece(name, parts):
    """A far silhouette: `parts` is a list of ("box", c, size) / ("roof", x0, x1, hd, y_eave, y_ridge, cz) /
    ("drum", cx, cz, r0, r1, y0, y1, n) / ("hip", cx, cz, hx, hz, y0, y1). One matte material."""
    b = W(name, {"far": mats()["far"]}, 1, damp=0.0)
    for p in parts:
        if p[0] == "box":
            b.box(p[1], p[2], "far", cuts=0, jit=0.0)
        elif p[0] == "roof":
            _, x0, x1, hd, ye, yr, cz = p
            b.prism_x([(cz - hd, ye), (cz, yr), (cz + hd, ye)], x0, x1, "far", jit=0.0, dens=99.0, xstep=99.0)
        elif p[0] == "drum":
            _, cx, cz, r0, r1, y0, y1, n = p
            b.frustum(cx, cz, r0, r1, y0, y1, "far", round_n=n, levels=2, jit=0.0)
        elif p[0] == "hip":
            _, cx, cz, hx, hz, y0, y1 = p
            b.frustum(cx, cz, (hx, hz), (max(0.15, hx - hz * 0.6), 0.1), y0, y1, "far", levels=2, jit=0.0)
    return b.finish()


# ==================================================================================================================
# output
# ==================================================================================================================

def export(path, objs):
    L.export(path, objs)


def write_boxes(path, header):
    lines = ["extends RefCounted", "## GENERATED by %s: collision boxes [cx, cy, cz, sx, sy, sz, yaw] in each piece's frame, and the" % header,
             "## numbers the game reads (DATA). Do not edit.", ""]
    for nm in sorted(COLS):
        rows = COLS[nm]
        if not rows:
            continue
        lines.append("const %s := [" % (nm.upper() + "_BOXES"))
        for r in rows:
            lines.append("\t[" + ", ".join("%g" % v for v in r) + "],")
        lines.append("]")
    lines.append("const DATA := " + L.gd_lit(DATA))
    lines.append("")
    with open(path, "w") as f:
        f.write("\n".join(lines))
    print("WROTE", path)


def turnaround(prefix, obj, look=(0.0, 3.0, 0.0), dist=22.0, el=0.28, views=(30, 120, 210, 300), res=(1400, 1000), lens=38, extra=()):
    """Stills of one piece (and `extra` objects with it) from around it: EEVEE, a low sun, a dim sky, a ground plane."""
    sc = bpy.context.scene
    for eng in ('BLENDER_EEVEE', 'BLENDER_EEVEE_NEXT'):
        try:
            sc.render.engine = eng
            break
        except TypeError:
            continue
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.film_transparent = False
    try:
        sc.view_settings.view_transform = 'AgX'
    except TypeError:
        pass
    if sc.world is None:
        sc.world = bpy.data.worlds.new("RW")
    sc.world.use_nodes = True
    bg = sc.world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs[0].default_value = (0.32, 0.36, 0.42, 1.0)
        bg.inputs[1].default_value = 0.9
    sun = bpy.data.objects.get("RSun")
    if sun is None:
        sun = bpy.data.objects.new("RSun", bpy.data.lights.new("RSun", 'SUN'))
        sc.collection.objects.link(sun)
        sun.data.energy = 3.2
        sun.data.angle = 0.06
    ground = bpy.data.objects.get("RGround")
    if ground is None:
        me = bpy.data.meshes.new("RGround")
        s = 120.0
        me.from_pydata([(-s, -s, 0), (s, -s, 0), (s, s, 0), (-s, s, 0)], [], [(0, 1, 2, 3)])
        ground = bpy.data.objects.new("RGround", me)
        sc.collection.objects.link(ground)
        gm = L.flat("RGroundMat", (0.13, 0.15, 0.1), 0.95)
        me.materials.append(gm)
    cam = bpy.data.objects.get("RCam")
    if cam is None:
        cam = bpy.data.objects.new("RCam", bpy.data.cameras.new("RCam"))
        sc.collection.objects.link(cam)
    cam.data.lens = lens
    cam.data.clip_end = 3000
    sc.camera = cam
    keep = {obj.name, "RGround"} | {o.name for o in extra}
    for o in bpy.data.objects:
        if o.type == 'MESH':
            o.hide_render = o.name not in keep
    tgt = L.G(look)
    for i, az in enumerate(views):
        a = math.radians(az)
        pos = Vector((look[0] + math.sin(a) * dist * math.cos(el), -(look[2] + math.cos(a) * dist * math.cos(el)), look[1] + dist * math.sin(el)))
        cam.location = pos
        cam.rotation_euler = (tgt - pos).to_track_quat('-Z', 'Y').to_euler()
        # the sun over the camera's left shoulder, low
        sa = a + math.radians(55)
        sun.rotation_euler = Vector((math.radians(55), 0.0, -sa + math.pi)) 
        sc.render.filepath = "%s_%s_%d.png" % (prefix, obj.name, i)
        bpy.ops.render.render(write_still=True)
    for o in bpy.data.objects:
        if o.type == 'MESH':
            o.hide_render = False
