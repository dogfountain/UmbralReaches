"""Plates that follow the flow of the body (r38d): bark shingles, chitin scutes, scales laid in rows round a
limb, the trunk or the neck. Each vertex is assigned to its nearest AXIS (a segment with a radius); plates
are then laid in that axis' own coordinates (distance along it, angle round it), staggered row on row, each
row's lip overlapping the next, so the pattern follows the form instead of being a texture draped on it.

    axes = [Axis(a, b, up, radius, row_h, col_w, amp)]
    disp, crev, pid = plates(P, N, axes, mask)
disp  displacement along the normal (metres), crev 1 in the grooves and under each lip, pid a random 0..1
per plate (colour variation).
"""
import math
import numpy as np

import quad_sdf as Q


class Axis:
    def __init__(self, a, b, up=(0, 1, 0), radius=0.1, row_h=0.07, col_w=0.1, amp=0.015, rows=None, tag=0):
        self.a = np.asarray(a, dtype=np.float32)
        self.b = np.asarray(b, dtype=np.float32)
        ax = self.b - self.a
        self.L = float(np.linalg.norm(ax))
        self.ax = ax / max(self.L, 1e-9)
        up = np.asarray(up, dtype=np.float32)
        u = up - self.ax * float(up @ self.ax)
        if np.linalg.norm(u) < 1e-4:
            u = np.array([1, 0, 0], dtype=np.float32) - self.ax * float(self.ax[0])
        self.u = u / np.linalg.norm(u)
        self.w = np.cross(self.ax, self.u).astype(np.float32)
        self.r = radius
        self.row_h, self.col_w, self.amp = row_h, col_w, amp
        self.nrow = rows or max(4, 2 * int(round(math.pi * 2 * radius / row_h / 2)))
        self.tag = tag

    def dist(self, P):
        t = np.clip(((P - self.a) @ self.ax), 0.0, self.L)
        q = self.a + t[:, None] * self.ax
        return np.sqrt(((P - q) ** 2).sum(1)) - self.r


def _hash(i, j, seed=0):
    h = (i.astype(np.int64) * 73856093 ^ j.astype(np.int64) * 19349663 ^ (seed * 83492791)) & 0xFFFFFF
    return (h % 100003).astype(np.float32) / 100003.0


def plates(P, N, axes, mask, seed=1, warp=0.25, lip=0.82):
    n = len(P)
    D = np.stack([ax.dist(P) for ax in axes], 1)
    which = D.argmin(1)
    disp = np.zeros(n, dtype=np.float32)
    crev = np.zeros(n, dtype=np.float32)
    pid = np.zeros(n, dtype=np.float32)
    for k, ax in enumerate(axes):
        sel = np.nonzero((which == k) & (mask > 0.02))[0]
        if len(sel) == 0:
            continue
        p = P[sel]
        q = p - ax.a
        s = q @ ax.ax
        rel = q - s[:, None] * ax.ax
        x, y = rel @ ax.u, rel @ ax.w
        th = np.arctan2(y, x)
        gs = s / ax.col_w
        ga = th / (2 * math.pi) * ax.nrow
        wn = Q.fbm(p, 9.0, 2, seed + k) - 0.5
        wn2 = Q.fbm(p, 9.0, 2, seed + 40 + k) - 0.5
        ga = ga + wn * warp * 2.0
        row = np.floor(ga)
        gs = gs + wn2 * warp * 2.0 + 0.5 * (row % 2)
        rowf = ga - row
        colf = gs - np.floor(gs)
        edge = np.minimum(colf, 1.0 - colf)
        ss = lambda lo, hi, v: (lambda t: t * t * (3 - 2 * t))(np.clip((v - lo) / (hi - lo), 0.0, 1.0))
        pidv = _hash(np.floor(gs), row, seed + k)
        slab = ss(0.0, 0.16, edge) * ss(0.0, 0.12, rowf)
        lipdrop = 1.0 - ss(lip, 1.0, rowf)
        h = slab * (0.45 + 0.55 * rowf) * (0.35 + 0.65 * lipdrop) * (0.55 + 0.9 * pidv)
        groove = slab
        m = np.clip(mask[sel], 0.0, 1.0)
        disp[sel] = ax.amp * h * m
        crev[sel] = np.clip((1.0 - groove) * 1.1 + (1.0 - lipdrop) * 0.7, 0, 1) * m
        pid[sel] = pidv
    return disp, crev, pid
