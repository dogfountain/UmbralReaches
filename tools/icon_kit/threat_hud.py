"""The off-screen threat cues (category "hud", ids "threat_melee" and "threat_ranged"): a small painted coin the HUD
holds at the edge of the view, turned to point at a foe that is winding up on the wanderer out of sight (ui/threat_cues.gd).
Painted pointing up; the HUD turns it. Ember for a blow coming in (a rake, a pounce, a charge), sea-green for a shot or a
working cast at you, the colours of the ground's own tells, so the edge and the floor say the same thing."""
import numpy as np

from marks import medal, finish_mark, o, INK  # noqa: F401
from motifs import *  # noqa: F401,F403
from registry import recipe


def _head(img, dark, light, spec):
    """A broad barbed arrowhead, tip up, cut deep at the back, with a dark outline that holds at 28 px."""
    tip = poly([(0.0, -0.64), (0.5, 0.16), (0.17, 0.02), (0.0, 0.4), (-0.17, 0.02), (-0.5, 0.16)])
    img = over(img, C(INK), smooth(tip - 0.06) * 0.95)
    return o(img, tip, dark, light, spec, 0.12, outline=0.05)


@recipe("hud", "threat_melee")
def threat_melee():
    img = medal("#2c0a04", "#4c1606", 911, glow="#ff5a18")
    for sx in (-0.2, 0.0, 0.2):                  # three claw rakes behind the head: a blow, not a shot
        rake = segment(sx - 0.05, 0.62, sx + 0.05, 0.36) - 0.028
        img = over(img, C(INK), smooth(rake - 0.025) * 0.9)
        img = over(img, C("#ff9a50"), smooth(rake))
    img = _head(img, "#5c1a06", "#ff8c3c", "#fff2c4")
    return finish_mark(img, "#c0682e")


@recipe("hud", "threat_ranged")
def threat_ranged():
    img = medal("#04201c", "#083630", 913, glow="#30e0c0")
    img = orb(img, 0.0, 0.5, 0.13, "#0c4a40", "#8ff8e0", halo="#40f0c8", halo_amt=0.6, seed=914)   # the shot behind it
    img = _head(img, "#0a3c34", "#62f2d2", "#eafff8")
    return finish_mark(img, "#5aa694")
