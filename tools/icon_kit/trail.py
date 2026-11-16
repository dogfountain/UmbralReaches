"""The tracked task's marks: the painted waymark the trail lays on the ground (category "trail", a decal: RGBA, 128 px),
the pin the followed task wears on the waypoint, the compass and the objective line (mark/followed, a medallion), and
the story's own row in the ledger (lore/story). Same painter and look as the rest of the kit (marks.py, lore.py)."""
import numpy as np

from marks import medal, finish_mark, o, INK  # noqa: F401
from motifs import *  # noqa: F401,F403
from registry import recipe


@recipe("trail", "step")
def trail_step():
    """A pilgrim's waymark cut into a flagstone: a worn dark lozenge with an ember line inlaid in its face. Dark enough to
    be nothing by day or by a bright fire; the ember line is all that is found in the dark (the decal's emission is this
    same picture, so only the inlay glows, and well under the bloom's threshold)."""
    d = (np.abs(x) + np.abs(y)) * 0.92 - 0.8                       # the lozenge, a touch taller than wide
    worn = (nz(9, 31, octaves=4) - 0.5) * 0.2 + (nz(40, 32, octaves=2) - 0.5) * 0.05
    sd = d + worn
    stone = mix(C("#262321"), C("#4a443b"), np.clip(nz(11, 33, octaves=4) * 1.2, 0, 1))
    stone = stone * (0.85 + 0.3 * nz(70, 34, octaves=2))[..., None]
    # a chiselled bevel: lit from the upper left, dark under the lower right
    lit = np.clip(0.5 + (-x - y) * 0.35, 0.0, 1.0)
    img = stone * (0.7 + 0.5 * lit)[..., None]
    rim = np.abs(sd + 0.07) - 0.022
    img = over(img, C("#14110f"), smooth(rim) * 0.9)
    # the inlay: an inner lozenge line and a centre stud, hot in the middle of the stroke
    inner = np.abs((np.abs(x) + np.abs(y)) * 0.92 - 0.46 + worn * 0.3) - 0.026
    stud = circle(0.0, 0.0, 0.085)
    ember = np.minimum(inner, stud)
    img = add(img, C("#8a3a10"), np.exp(-np.maximum(ember, 0.0) / 0.05) * 0.42)      # the warm spill on the stone
    img = over(img, C("#a8501a"), smooth(ember + 0.012))
    img = over(img, C("#f0a048"), smooth(ember + 0.034))
    # chips and a crack through the face
    crack = polyline([(-0.5, 0.12), (-0.28, 0.05), (-0.18, 0.18), (0.02, 0.22)]) - 0.012
    img = over(img, C("#0e0c0a"), smooth(crack) * 0.8)
    a = smooth(sd) * np.clip(0.72 + 0.6 * nz(16, 35, octaves=3), 0.0, 1.0) ** 0.3
    img = np.clip(img, 0, 1) * (a > 0.01)[..., None]
    return np.dstack([img, np.clip(a, 0, 1)])


@recipe("mark", "followed")
def followed():
    """The pin of the followed task: a gold pennant on a staff, planted at a lozenge (the trail's own mark)."""
    img = medal("#2a1c08", "#4a3410", 861, glow="#ffc060")
    img = o(img, poly([(-0.34, 0.5), (0.0, 0.62), (0.34, 0.5), (0.0, 0.38)]), "#3a2a10", "#a88048", outline=0.04)
    img = o(img, segment(-0.1, -0.58, -0.1, 0.56) - 0.05, "#3a2610", "#b8905a", "#fff0c0", 0.06, outline=0.04)
    flag = poly([(-0.06, -0.58), (0.52, -0.38), (0.2, -0.28), (0.52, -0.16), (-0.06, 0.02)])
    img = o(img, flag, "#8a4a08", "#ffc060", "#fff6c0", 0.1, outline=0.045, halo="#ffd070", halo_amt=0.45)
    return finish_mark(img, "#e8b040")


@recipe("lore", "story")
def story():
    """The story's own way in the ledger: a road running to a star."""
    img = medal("#14182c", "#2a2650", 862, glow="#c0b0ff")
    road = poly([(-0.46, 0.64), (0.46, 0.64), (0.08, -0.28), (-0.08, -0.28)])
    img = o(img, road, "#4a4034", "#c8b890", "#f0e4c0", 0.12, outline=0.045)
    for k, (cy, hy, hx) in enumerate([(0.5, 0.07, 0.04), (0.22, 0.06, 0.03), (-0.02, 0.05, 0.022)]):
        img = over(img, C("#1a1410"), smooth(box(0.0, cy, hx, hy)) * 0.85)
    star = []
    for k in range(10):
        a = -np.pi / 2 + k * np.pi / 5
        rr = 0.3 if k % 2 == 0 else 0.12
        star.append((rr * np.cos(a), -0.52 + rr * np.sin(a)))
    img = o(img, poly(star), "#8a5a10", "#ffe080", "#ffffff", 0.1, outline=0.04, halo="#ffd070", halo_amt=0.6)
    return finish_mark(img, "#b0a0e0")
