"""The climb round the Spindle (the basalt stack): the helix of steps with its three rest landings, the Spindle Gate, the two-bay bridge and the ward
landing. Imported by crossing_kit.py (which owns the plan constants). Game frame.
"""
import math

from crossing_towers import *      # noqa: F401,F403


def _wedge(P, key, c, ra, rb, ta, tb, y0, y1, mul=1.0, bevel=0.0, gap=0.008):
    ta2 = ta - gap / max(rb, 1.0)
    tb2 = tb + gap / max(rb, 1.0)
    pts = [polar(c, ra, ta2, y0), polar(c, rb, ta2, y0), polar(c, rb, tb2, y0), polar(c, ra, tb2, y0),
           polar(c, ra, ta2, y1), polar(c, rb, ta2, y1), polar(c, rb, tb2, y1), polar(c, ra, tb2, y1)]
    hexa(P, key, pts, mul, bevel=bevel)


def helix(P, C, Pi, Pe, rnd, S, R, hw, y0, y1, n_steps, land_deg, thickness=1.5, fires=None, benches=None):
    """One helix of steps from angle 0, decreasing (clockwise on the map: east, north, west, south, east), n_steps steps in four runs with three
    rest landings of land_deg between. Returns the records [(ta, tb, top, kind)] for the supports."""
    r_in, r_out = R - hw, R + hw
    da = math.radians((360.0 - 3 * land_deg) / n_steps)
    ry = (y1 - y0) / n_steps
    runs = [12, 12, 12, n_steps - 36]
    th = 0.0
    y = y0
    rec = []
    land_rad = math.radians(land_deg)
    rr = r_out - RAIL_T * 0.5
    group = []
    for ri, cnt in enumerate(runs):
        # --- a run of steps
        for i in range(cnt):
            ta, tb = th, th - da
            top = y + ry
            _wedge(P, "slate", S, r_in, r_out, ta, tb, top - 0.24, top, rnd.uniform(0.92, 1.06), bevel=0.02)
            _wedge(P, "hewn", S, r_out - 0.34, r_out, ta, tb, top - thickness, top - 0.24, rnd.uniform(0.92, 1.06), bevel=0.03)
            _wedge(P, "stone", S, r_in, r_out - 0.34, ta, tb, top - thickness, top - 0.24, 1.0)
            rec.append((ta, tb, top, "step"))
            group.append((ta, tb, top))
            if len(group) == 2 or i == cnt - 1:
                _rail_group(P, C, rnd, S, rr, group, False)
                group = []
            th, y = tb, top
        # collision ramp for the run (through the tread middles, half a tread back)
        _ramp(C, S, r_in - 0.3, r_out, th + da * cnt, da, cnt, y - ry * cnt, y, R)
        if ri < 3:
            # --- a landing
            ta, tb = th, th - land_rad
            nw = 2
            for k in range(nw):
                a0 = ta - land_rad * k / nw
                a1 = ta - land_rad * (k + 1) / nw
                _wedge(P, "slate", S, r_in, r_out, a0, a1, y - 0.24, y, rnd.uniform(0.92, 1.06), bevel=0.02)
                _wedge(P, "hewn", S, r_out - 0.34, r_out, a0, a1, y - thickness, y - 0.24, 1.0, bevel=0.03)
                _wedge(P, "stone", S, r_in, r_out - 0.34, a0, a1, y - thickness, y - 0.24, 1.0)
                _rail_group(P, C, rnd, S, rr, [(a0, a1, y)], True)
            rec.append((ta, tb, y, "land"))
            # the landing's floor collision: a flat fan
            _flat(C, S, r_in - 0.3, r_out, ta, tb, y)
            mid = (ta + tb) * 0.5
            if fires is not None:
                pt = polar(S, rr - 0.2, mid, y)
                fires.append(lamp_with_fire(P, Pi, Pe, rnd, pt, (-math.sin(mid), math.cos(mid)), h=1.9, big=True))
            if benches is not None:
                pb = polar(S, r_in + 0.45, mid, y + 0.25)
                tang = (-math.sin(mid), math.cos(mid))
                blk(P, "hewn", pb, (2.2, 0.5, 0.55), tang, rnd, bevel=0.05)
                C.box(pb, (2.2, 0.5, 0.55), tang)
                benches.append(list(pb))
            th = tb
    return rec, da, ry


def _rail_group(P, C, rnd, S, rr, group, landing):
    ta = group[0][0]
    tb = group[-1][1]
    mid = (ta + tb) * 0.5
    a = polar(S, rr, ta, 0.0)
    b = polar(S, rr, tb, 0.0)
    chord = math.hypot(b[0] - a[0], b[2] - a[2])
    d = ((b[0] - a[0]) / chord, (b[2] - a[2]) / chord)
    top = group[0][2]
    cp = polar(S, rr * math.cos((ta - tb) * 0.5) / 1.0 * 1.0, mid, top)
    # centred on the arc's chord, but pushed out to the outer face so adjacent groups meet
    cp = ((a[0] + b[0]) * 0.5, top, (a[2] + b[2]) * 0.5)
    if landing:
        blk(P, "hewn", (cp[0], top + RAIL_H * 0.5, cp[2]), (chord - 0.03, RAIL_H, RAIL_T), d, rnd, bevel=0.04, warp=0.006)
        blk(P, "hewn", (cp[0], top + RAIL_H + 0.06, cp[2]), (chord + 0.06, 0.13, RAIL_T + 0.16), d, rnd, bevel=0.03, warp=0.004)
        C.box((cp[0], top + 0.6, cp[2]), (chord, 1.2, RAIL_T), d)
    else:
        blk(P, "hewn", (cp[0], top + (RAIL_H - 0.3) * 0.5, cp[2]), (chord - 0.03, RAIL_H + 0.3, RAIL_T), d, rnd, bevel=0.04, warp=0.006)
        blk(P, "hewn", (cp[0], top + RAIL_H + 0.06, cp[2]), (chord + 0.06, 0.13, RAIL_T + 0.16), d, rnd, bevel=0.03, warp=0.004)
        C.box((cp[0], top + 0.7, cp[2]), (chord, 1.4, RAIL_T), d)
    # a post at the group's start
    post(P, rnd, (a[0], top, a[2]), d)


def _ramp(C, S, ri, ro, th_first, da, cnt, y_start, y_end, R):
    """Collision ramp for a run of `cnt` steps of da radians each from angle th_first, the angle running down: strips from the inner to the outer
    edge, height from y_start (half a tread before the first nosing) to y_end, flat for the last half tread."""
    arc = da * cnt * R
    tread = arc / cnt
    n = max(4, int(math.ceil(arc / 0.35)))
    for i in range(n):
        sa = arc * i / n
        sb = arc * (i + 1) / n
        ta = th_first - sa / R
        tb = th_first - sb / R
        ya = _yat(sa, arc, tread, y_start, y_end)
        yb = _yat(sb, arc, tread, y_start, y_end)
        C.quad(polar(S, ri, ta, ya), polar(S, ro, ta, ya), polar(S, ro, tb, yb), polar(S, ri, tb, yb))


def _yat(s, arc, tread, y0, y1):
    if s >= arc - tread * 0.5:
        return y1
    return y0 + (y1 - y0) * min(1.0, (s + tread * 0.5) / arc)


def _flat(C, S, ri, ro, ta, tb, y):
    n = 4
    for k in range(n):
        a0 = ta + (tb - ta) * k / n
        a1 = ta + (tb - ta) * (k + 1) / n
        C.quad(polar(S, ri, a0, y), polar(S, ro, a0, y), polar(S, ro, a1, y), polar(S, ri, a1, y))
