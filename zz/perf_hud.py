#!/usr/bin/env python3
"""GPU time per perf_tour window on Metal, where Godot's own GPU timer reads 0.

Run the tour with the Metal performance HUD logging every frame to stderr:
    MTL_HUD_ENABLED=1 MTL_HUD_LOG_ENABLED=1 godot --path . res://zz/perf_tour.tscn -- [options] > tour.log 2>&1
    python3 zz/perf_hud.py tour.log
The HUD prints "metal-HUD: <frame count>,<mem>,<mem>,<interval ms>,<gpu ms>,<interval ms>,<gpu ms>,..."
about every 100 frames (the pairs are the frames up to <frame count>); perf_tour prints
"PERFWIN <name> <first frame> <last frame>" per window. Output per window: mean / p95 / max GPU ms
and the mean presented interval. (The HUD draws itself too: compare runs that both had it on.)
"""
import re
import sys


def main(path: str) -> None:
    gpu = {}
    interval = {}
    wins = []
    cal = None
    for line in open(path, errors="replace"):
        m = re.search(r"metal-HUD: ([0-9.,]+)", line)
        if m:
            f = m.group(1).strip(",").split(",")
            end = int(float(f[0]))
            pairs = f[3:]
            n = len(pairs) // 2
            for k in range(n):
                fr = end - n + 1 + k
                interval[fr] = float(pairs[2 * k])
                gpu[fr] = float(pairs[2 * k + 1])
            continue
        m = re.match(r"PERFWIN (\S+) (\d+) (\d+)", line)
        if m:
            wins.append((m.group(1), int(m.group(2)), int(m.group(3))))
        m = re.match(r"PERFCAL (\d+) (\d+)", line)
        if m:
            cal = (int(m.group(1)), int(m.group(2)))
    if not gpu:
        print("no metal-HUD lines (run with MTL_HUD_ENABLED=1 MTL_HUD_LOG_ENABLED=1)")
        return
    # frame offset between the HUD counter and Godot's: where the calibration block (90 frames at
    # 4x pixels) sits in the HUD log
    off = 0
    if cal:
        best = -1.0
        a, b = cal
        for o in range(-600, 601):
            g = [gpu[i + o] for i in range(a, b) if i + o in gpu]
            if len(g) > (b - a) * 0.8:
                m = sum(g) / len(g)
                if m > best:
                    best, off = m, o
        print("calibration: HUD frame = Godot frame %+d (block at %.2f ms)" % (off, best))
    wins = [(n, a + off, b + off) for n, a, b in wins]
    # --attrib windows "<point>|<feature>|on/off": GPU cost of each feature (on minus off)
    att = {}
    for name, a, b in wins:
        if name.count("|") == 2:
            g = [gpu[i] for i in range(a, b + 1) if i in gpu]
            if g:
                att.setdefault(tuple(name.split("|")[:2]), {}).setdefault(name.split("|")[2], []).append(sum(g) / len(g))
    for (pt, feat), d in att.items():
        on = sum(d.get("on", [0])) / max(1, len(d.get("on", [])))
        off = sum(d.get("off", [0])) / max(1, len(d.get("off", [])))
        print("ATTRIB-GPU %-14s %-28s on %6.2f  off %6.2f  cost %+6.2f ms" % (pt, feat, on, off, on - off))
    wins = [w for w in wins if w[0].count("|") != 2]
    print("%-16s %6s %8s %8s %8s %9s" % ("window", "frames", "gpu ms", "p95", "max", "interval"))
    for name, a, b in wins:
        g = sorted(gpu[i] for i in range(a, b + 1) if i in gpu)
        iv = [interval[i] for i in range(a, b + 1) if i in interval]
        if not g:
            print("%-16s no HUD frames" % name)
            continue
        print("%-16s %6d %8.2f %8.2f %8.2f %9.2f" % (name, len(g), sum(g) / len(g), g[int(len(g) * 0.95)], g[-1], sum(iv) / len(iv)))


if __name__ == "__main__":
    main(sys.argv[1])
