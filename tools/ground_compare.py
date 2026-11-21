#!/usr/bin/env python3
"""Before / after counts of zz/ground_probe.gd's findings per placing system and kind.  usage: ground_compare.py before.tsv after.tsv [--sys-depth 2]
Rows are matched by system only (positions move a little when ground is fixed), so the numbers are counts per finding, with the worst gap each side."""
import sys, os, collections
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ground_rank as g

KINDS = ("float", "sky", "sink", "tilt", "road", "water", "under", "buried", "lone")


def tally(path, depth):
    rows = g.load(path)
    out = collections.defaultdict(lambda: collections.Counter())
    worst = collections.defaultdict(float)
    for r in rows:
        fl = g.flags(r, False)
        s = g.system(r, depth)
        out[s]["items"] += 1
        for k in fl:
            out[s][k] += 1
            if k == "float":
                worst[s] = max(worst[s], r["fl"])
    return out, worst, rows


def main():
    b, a = sys.argv[1], sys.argv[2]
    depth = int(sys.argv[sys.argv.index("--sys-depth") + 1]) if "--sys-depth" in sys.argv else 2
    tb, wb, rb = tally(b, depth)
    ta, wa, ra = tally(a, depth)
    tot_b = collections.Counter()
    tot_a = collections.Counter()
    for s in tb:
        tot_b.update({k: v for k, v in tb[s].items() if k != "items"})
    for s in ta:
        tot_a.update({k: v for k, v in ta[s].items() if k != "items"})
    print("TOTAL before", dict(tot_b), len(rb), "items")
    print("TOTAL after ", dict(tot_a), len(ra), "items")
    print("\n%-44s %-26s %-26s worst float (m) before -> after" % ("system", "float/sink/tilt before", "after"))
    for s in sorted(set(tb) | set(ta), key=lambda s: -(tb[s]["float"] + tb[s]["sink"] + tb[s]["tilt"])):
        bb = tb[s]
        aa = ta[s]
        if bb["float"] + bb["sink"] + bb["tilt"] + aa["float"] + aa["sink"] + aa["tilt"] == 0:
            continue
        print("%-44s %4d/%4d/%4d            %4d/%4d/%4d            %.2f -> %.2f" % (s[:44], bb["float"], bb["sink"], bb["tilt"], aa["float"], aa["sink"], aa["tilt"], wb[s], wa[s]))


if __name__ == "__main__":
    main()
