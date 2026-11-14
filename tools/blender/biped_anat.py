"""Anatomy for the remodelled bipeds: sculpt terms added to the fused body surface (biped_body.body(extra=...)) so the limbs
between the clothes are not smooth tubes: muscle bellies with the creases between them, knotted joints (elbow, knee, wrist,
ankle, knuckles, collarbone ends), tendon cords, and skin damage (scars, pits, boils, welts) scattered where a life would have
put them. All in rig space, via grunt_body.Sculpt (bump / ridge)."""
import math
import numpy as np


def muscles(sc, Y, nm, k=1.0, lean=1.0):
    """Muscle on the frame. k scales the amplitude (a starved body 0.7, a brute 1.5)."""
    both = (-1, 1)
    if nm == "Arms":
        sc.bump((0.262, Y(1.385), 0.0), 0.062, 0.015 * k, facing=(1, 0.4, 0), sx=both)           # deltoid
        sc.bump((0.255, Y(1.23), -0.032), 0.052, 0.014 * k, facing=(0.3, 0, -1), sx=both)       # biceps
        sc.bump((0.258, Y(1.2), 0.036), 0.055, 0.013 * k, facing=(0.3, 0, 1), sx=both)          # triceps (long head)
        sc.ridge((0.25, Y(1.3), -0.03), (0.25, Y(1.14), -0.03), 0.006, -0.005 * k, facing=(0, 0, -1), sx=both)   # the groove between them
        sc.bump((0.26, Y(0.98), -0.014), 0.052, 0.015 * k, facing=(0.5, 0, -1), sx=both)        # forearm flexors
        sc.bump((0.272, Y(0.95), 0.016), 0.04, 0.01 * k, facing=(1, 0, 0.4), sx=both)           # brachioradialis
        sc.ridge((0.255, Y(1.0), 0.0), (0.262, Y(0.82), 0.0), 0.005, -0.004 * k, facing=(1, 0, 0), sx=both)
    else:
        sc.bump((0.12, 0.58, -0.035), 0.09, 0.017 * k, facing=(0.3, 0, -1), sx=both)             # quadriceps
        sc.ridge((0.14, 0.7, -0.04), (0.125, 0.44, -0.045), 0.006, -0.005 * k, facing=(0.4, 0, -1), sx=both)    # the groove down the thigh
        sc.bump((0.125, 0.6, 0.04), 0.085, 0.012 * k, facing=(0.3, 0, 1), sx=both)              # hamstrings
        sc.bump((0.115, 0.23, 0.032), 0.068, 0.022 * k, facing=(0.2, 0, 1), sx=both)            # calf
        sc.ridge((0.115, 0.3, 0.03), (0.115, 0.14, 0.04), 0.006, -0.005 * k, facing=(0, 0, 1), sx=both)       # the split between the calf heads
        sc.bump((0.1, 0.84, 0.075), 0.075, 0.015 * k, facing=(0, 0, 1), sx=both)                # glutes
        sc.bump((0.0, Y(1.46), 0.07), 0.13, 0.016 * lean, facing=(0, 0.3, 1))                    # trapezius / hump
        sc.bump((0.1, Y(1.36), -0.088), 0.075, 0.009 * k, facing=(0, 0, -1), sx=both)            # pectoral
        sc.bump((0.15, Y(1.2), 0.075), 0.08, 0.009 * k, facing=(0.5, 0, 1), sx=both)            # latissimus
        sc.ridge((0.0, Y(1.3), -0.115), (0.0, Y(1.0), -0.12), 0.005, -0.004 * k, facing=(0, 0, -1))           # the line down the belly


def joints(sc, Y, nm, hand_r=1.0, wy=0.74, k=1.0):
    """Knotted joints: bone showing through where it should."""
    both = (-1, 1)
    if nm == "Arms":
        sc.bump((0.252, Y(1.08), 0.03), 0.026, 0.016 * k, facing=(0, 0, 1), sx=both)           # the point of the elbow
        sc.bump((0.252, Y(1.08), -0.02), 0.022, -0.006 * k, facing=(0, 0, -1), sx=both)         # the hollow in front of it
        sc.bump((0.262, wy + 0.012, 0.0), 0.016, 0.01 * k, facing=(1, 0, 0), sx=both)           # the ulnar knob
        sc.bump((0.26, Y(1.405), 0.0), 0.03, 0.012 * k, facing=(1, 0.5, 0), sx=both)            # the point of the shoulder
        sc.ridge((0.06, Y(1.455), -0.075), (0.22, Y(1.435), -0.04), 0.011, 0.01 * k, facing=(0, 0.3, -1), sx=both)      # the collarbone, proud
        for kk in range(4):                                                                       # knuckles: knotted hands
            fx = 0.248 + (kk - 1.5) * 0.02 * hand_r
            sc.bump((fx, wy - 0.095, -0.016), 0.013 * hand_r, 0.011 * k, facing=(0, 0, -1), sx=both)
            sc.bump((fx, wy - 0.095, 0.0), 0.012 * hand_r, 0.005 * k, facing=(0, 0, 1), sx=both)
    else:
        sc.bump((0.11, 0.345, -0.05), 0.03, 0.018 * k, facing=(0, 0, -1), sx=both)              # the knee cap
        sc.bump((0.11, 0.345, 0.04), 0.03, -0.012 * k, facing=(0, 0, 1), sx=both)               # the hollow behind it
        sc.bump((0.135, 0.085, 0.0), 0.016, 0.01 * k, facing=(1, 0, 0), sx=both)                # ankle bones
        sc.bump((0.087, 0.085, 0.0), 0.016, 0.009 * k, facing=(-1, 0, 0), sx=both)
        sc.ridge((0.11, 0.3, -0.045), (0.11, 0.1, -0.035), 0.01, 0.01 * k, facing=(0, 0, -1), sx=both)          # the shin edge
        sc.bump((0.135, 0.985, -0.07), 0.028, 0.014 * k, facing=(0.5, 0, -1), sx=both)          # hip points
        sc.bump((0.0, 0.935, 0.095), 0.04, 0.009 * k, facing=(0, 0, 1))                          # the sacrum


def damage(sc, seed, count=40, amp=0.005, boils=0):
    """Scars (groove with a raised lip either side), pits and boils, placed on random points of the surface."""
    rng = np.random.RandomState(seed)
    P, N = sc.P, sc.N
    for i in rng.randint(0, len(P), count):
        p, n = P[i], N[i]
        r = rng.normal(size=3)
        t = np.cross(n, r)
        t = t / (np.linalg.norm(t) + 1e-9)
        ln = rng.uniform(0.03, 0.08)
        a, b = p - t * ln, p + t * ln
        kind = rng.rand()
        if kind < 0.55:
            s = np.cross(n, t) * 0.006
            sc.ridge(a, b, 0.0032, -amp)
            sc.ridge(a + s, b + s, 0.003, amp * 0.5)
            sc.ridge(a - s, b - s, 0.003, amp * 0.5)
        elif kind < 0.8:
            sc.bump(tuple(p), 0.009, -amp * 1.2)
        else:
            sc.ridge(a, b, 0.006, amp * 0.8)
    for i in rng.randint(0, len(P), boils):
        sc.bump(tuple(P[i]), rng.uniform(0.012, 0.024), rng.uniform(0.008, 0.016))
