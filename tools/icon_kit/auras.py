"""HUD buff / debuff icons kept from the first pass (category "aura"): flame, hollow, rested. The rest are in aura_art.py."""
import numpy as np

from motifs import *  # noqa: F401,F403
from registry import recipe


def A(name):
    return recipe("aura", name)


def _dark(top, bottom, seed, glow, glow_col):
    return scene(top, bottom, seed, glow, 0.5, (0, 0), glow_col, 0.7)


@A("flame")
def flame():
    img = _dark("#080403", "#1a0905", 500, "#4a1a0a", "#d0501a")
    img = fire(img, 0.0, 0.5, 1.15, 0.42, 501, strength=1.3)
    return finish(img, 50, grade=(1.06, 0.97, 0.9))


@A("hollow")
def hollow():
    img = _dark("#04030a", "#0e0a1c", 570, "#2a2058", "#4a3aa0")
    head = ellipse(0, -0.05, 0.46, 0.58)
    img = add(img, C("#6a5ad0"), np.exp(-np.maximum(head, 0) / 0.1) * 0.5)
    img = over(img, mix(C("#08060f"), C("#3a3470"), bevel(head, 0.35)[0]), smooth(head))
    face = ellipse(0, 0.0, 0.27, 0.36)
    img = over(img, C("#010005"), smooth(face))
    for ex in (-0.11, 0.11):
        e = np.hypot(x - ex, (y + 0.06) / 1.5) - 0.05
        img = add(img, C("#b8a8ff"), np.exp(-np.maximum(e, 0) / 0.05) * 0.9)
        img = over(img, C("#ffffff"), smooth(e))
    return finish(img, 57, grade=(1.0, 0.97, 1.06))


@A("rested")
def rested():
    img = _dark("#05050c", "#0c0c20", 690, "#242a5a", "#6a70d0")
    moon = circle(-0.05, 0.0, 0.5)
    cut = circle(0.2, -0.1, 0.42)
    sd = np.maximum(moon, -cut)
    img = add(img, C("#a8b0ff"), np.exp(-np.maximum(sd, 0) / 0.1) * 0.6)
    img = solid(img, sd, "#6a70c0", "#f0f0ff", "#ffffff", 0.15)
    img = add(img, C("#e8e8ff"), sparks(10, 691, (0.0, -0.8, 0.8, 0.6), (0.004, 0.01)))
    return finish(img, 69, grade=(0.98, 0.98, 1.06))
