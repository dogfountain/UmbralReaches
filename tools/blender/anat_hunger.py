"""Hunger sculpted along the anatomy, as a displacement field over a standing body in rig space (x right, y up, z back,
face -z). Position-only, so it works on the bake's dense high-poly copy: ribs as ridges following the cage's slope with
the sternum flat, collarbones, shoulder blades and their spines, spine knuckles, hip crests, a hollow belly, joint knobs.
field(P, N, skin) -> metres along the normal (zero where `skin` is False)."""
import math
import numpy as np


def field(P, N, skin, amp=1.0, ribs=1.0, belly=1.0):
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    ax = np.abs(x)
    d = np.zeros(len(P))
    torso = (ax < 0.205) & (y > 0.86) & (y < 1.5)
    ang = np.arctan2(x, -z)                                    # 0 straight ahead, +-pi/2 the flanks, pi the back
    cage = np.exp(-((y - 1.27) / 0.125) ** 4) * torso
    around = np.clip((2.35 - np.abs(ang)) / 0.5, 0.0, 1.0)
    flat = np.clip((ax - 0.02) / 0.035, 0.0, 1.0)                # the sternum stays flat
    tilt = -0.045 * np.clip(np.abs(ang) / 1.6, 0.0, 1.0) + 0.03 * np.cos(np.abs(ang))
    ph = (y + tilt - 1.40) / 0.037
    rib = np.cos(ph * 2 * math.pi)
    d += ribs * 0.0095 * (np.clip(rib, -1, 1) ** 1) * cage * around * flat * (1.0 + 0.5 * np.clip(ax / 0.15, 0, 1))
    d -= belly * 0.014 * np.exp(-((y - 1.05) / 0.075) ** 2) * torso * np.clip(1.0 - ax / 0.2, 0.0, 1.0) * (z < 0)
    for sx in (-1, 1):
        t = np.clip((ax - 0.02) / 0.17, 0.0, 1.0)
        yc = 1.405 + 0.012 * t
        on = (x * sx > 0) & (z < 0.03) & (ax > 0.02) & (ax < 0.21) & (y > 1.34) & (y < 1.46)
        d += 0.011 * np.exp(-((y - yc) / 0.0105) ** 2) * on
        d -= 0.008 * np.exp(-((y - (yc - 0.032)) / 0.014) ** 2) * on
        d += 0.011 * np.exp(-(((x - sx * 0.1) / 0.05) ** 2 + ((y - 1.27) / 0.075) ** 2)) * (z > 0) * torso
        d += 0.0045 * np.exp(-((y - (1.37 - 0.03 * np.clip((ax - 0.04) / 0.1, 0, 1))) / 0.011) ** 2) * (np.abs(x - sx * 0.09) < 0.07) * (z > 0.0) * torso
        d += 0.016 * np.exp(-(((x - sx * 0.155) / 0.032) ** 2 + ((y - 0.99) / 0.027) ** 2)) * (z < 0.04) * torso
    sp = np.exp(-(x / 0.012) ** 2) * (z > 0) * torso
    d += 0.009 * sp * np.clip(np.cos((y - 1.0) / 0.043 * 2 * math.pi), 0.0, 1.0) * (y > 0.98) * (y < 1.42)
    d -= 0.004 * np.exp(-((ax - 0.04) / 0.02) ** 2) * (z > 0) * torso * (y > 1.0) * (y < 1.4)
    # joints stand proud of thin limbs: knees and elbows, wrists, ankles
    limb = ax > 0.05
    for y0, r, h, sel in ((0.345, 0.05, 0.011, (ax < 0.2)), (1.09, 0.045, 0.009, (ax > 0.17)), (0.80, 0.035, 0.008, (ax > 0.17)), (0.09, 0.04, 0.007, (ax < 0.2))):
        d += h * np.exp(-((y - y0) / r) ** 2) * sel * limb
    d = np.where(skin, d * amp, 0.0)
    return d


def folds(P, N, mask, amp=1.0, belt=0.97, hem=0.38):
    """Long folds hanging from the belt of a coat or robe, deeper toward the hem, pinched where the belt gathers them,
    drifting as they fall instead of a uniform noise. mask: the cloth's vertices."""
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    ang = np.arctan2(x, -z)
    fall = np.clip((belt + 0.1 - y) / (belt - hem + 0.1), 0.0, 1.0)
    drift = 1.4 * np.sin(y * 6.5 + ang * 2.0) * fall
    f1 = np.sin(ang * 11.0 + drift)
    f2 = np.sin(ang * 5.0 - 0.8 * drift + 1.3)
    a = (0.004 + 0.016 * fall ** 1.2)
    d = a * (0.7 * f1 + 0.5 * f2)
    d -= 0.006 * np.exp(-((y - belt) / 0.04) ** 2)                # the belt's pinch
    return np.where(mask, d * amp, 0.0)
