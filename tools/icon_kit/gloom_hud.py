"""The Gloom's own mark (category "hud", id "gloom"): the player frame's clock. A coin of night-violet enamel with a
crescent of pale lilac eating a darker disc, a few cold sparks. The HUD tints it as the Gloom climbs (lilac, then
ember), so the one painting serves every state."""
import numpy as np

from marks import medal, finish_mark, o  # noqa: F401
from motifs import *  # noqa: F401,F403
from registry import recipe


@recipe("hud", "gloom")
def gloom():
    img = medal("#140a2a", "#2c1250", 861, glow="#9a70ff")
    disc = circle(0.04, 0.02, 0.5)
    cut = circle(0.26, -0.08, 0.44)
    moon = np.maximum(disc, -cut)
    img = o(img, moon, "#6a4ab8", "#e6d8ff", "#ffffff", 0.16, outline=0.05, halo="#a080ff", halo_amt=0.55)
    for (sx, sy, r) in ((0.42, -0.34, 0.045), (0.5, 0.18, 0.03), (0.22, 0.46, 0.035)):
        img = over(img, C("#f0e8ff"), smooth(circle(sx, sy, r)) * 0.95)
    return finish_mark(img, "#a88adc")
