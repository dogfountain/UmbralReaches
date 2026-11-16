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
    # shoulders: the acromion a point, the deltoid hollow beneath, the cap not a box
    for sx in (-1, 1):
        d += 0.009 * np.exp(-(((x - sx * 0.215) / 0.03) ** 2 + ((y - 1.425) / 0.02) ** 2 + (z / 0.05) ** 2))
        d -= 0.009 * np.exp(-(((x - sx * 0.235) / 0.03) ** 2 + ((y - 1.36) / 0.04) ** 2))
        d -= 0.006 * np.exp(-(((x - sx * 0.2) / 0.04) ** 2 + ((y - 1.46) / 0.02) ** 2))
    # joints stand proud of thin limbs: knees and elbows, wrists, ankles
    limb = ax > 0.05
    for y0, r, h, sel in ((0.345, 0.05, 0.011, (ax < 0.2)), (1.09, 0.045, 0.009, (ax > 0.17)), (0.80, 0.035, 0.008, (ax > 0.17)), (0.09, 0.04, 0.007, (ax < 0.2))):
        d += h * np.exp(-((y - y0) / r) ** 2) * sel * limb
    # the shin's crest down the front of each lower leg, calves hollow behind, tendons at the ankle, knuckles on the hands
    leg = (ax < 0.2) & (y > 0.08) & (y < 0.33)
    d += 0.007 * np.exp(-(((ax - 0.11) / 0.016) ** 2)) * (z < 0.0) * leg * np.clip((y - 0.08) / 0.1, 0, 1)
    d -= 0.005 * np.exp(-((ax - 0.11) / 0.04) ** 2) * (z > 0.01) * leg
    hand = (ax > 0.2) & (y < 0.8) & (y > 0.6)
    d += 0.006 * np.exp(-((y - 0.7) / 0.012) ** 2) * hand * (np.cos((ax - 0.24) / 0.017 * 2 * math.pi) > 0.3)
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


def rag(P, N, mask, amp=1.0):
    """A rag wound round the skull: turns crossing diagonally both ways, uneven, rolled where they lap, with a slow
    drape across them; mask: the rag's vertices."""
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    ang = np.arctan2(x, -z)
    f1 = np.sin(2 * math.pi * (y / 0.032 + ang * 0.85))
    f2 = np.sin(2 * math.pi * (y / 0.046 - ang * 0.55 + 0.3))
    f3 = np.sin(ang * 3.0 + y * 40.0)
    d = 0.0034 * (0.6 * f1 + 0.45 * f2) + 0.0018 * f3 + 0.0012
    d *= 1.0 - 0.6 * np.clip((1.66 - y) / 0.05, 0.0, 1.0)                   # calmer toward the lower edge
    return np.where(mask, d * amp, 0.0)
