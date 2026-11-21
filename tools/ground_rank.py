#!/usr/bin/env python3
"""Rank zz/ground_probe.gd's TSV: findings per placing system and kind, the worst spots, a spots file for zz/ground_shots.gd.
usage: ground_rank.py probe.tsv [--spots spots.json --n 60] [--sys-depth 2]"""
import sys, csv, json, re, math, collections

ALLOW_ROAD = re.compile(r"lamp|sign|post|bridge|stair|step|path|road|stone|cairn|edge|kerb|curb|paver|wayfind|gate|arch|lantern|marker|ford|plank|deck|brazier|well|bench|hitch|mile", re.I)
ELEV = re.compile(r"roof|beam|rafter|eave|gable|chimney|lintel|floor|deck|arch|bridge|span|ceil|balcon|walkway|stair|loft|tower|gantry|canopy|awning|shutter|window|banner|flag|chain|bell|sign|hang|lantern|lamp|glass|truss|upper|top|crown|spire|pinnacle|crenel|merlon|parapet|wall|storey|story", re.I)


def load(path):
    rows = []
    with open(path) as f:
        for r in csv.DictReader(f, delimiter="\t"):
            for k in ("x", "y", "z", "sx", "sy", "sz", "fl", "sk", "mean", "slope", "tilt", "way", "wd", "sup", "ovl"):
                r[k] = float(r[k])
            r["flora"] = int(r["flora"])
            rows.append(r)
    return rows


def system(r, depth):
    parts = r["sys"].split("/")
    s = "/".join(parts[:depth])
    return s


def flags(r, lone):
    out = {}
    size = max(r["sx"], r["sz"], 0.3)
    flora = r["flora"] == 1
    kind = r["kind"]
    elev = bool(ELEV.search(kind)) or bool(ELEV.search(r["meshpath"].split("#")[0]))
    # a base point near/below ground while another hovers: a slope float; the whole base up: a hover
    if r["fl"] > 0.08 and r["sup"] <= 0 and not (r["sk"] > 1.2 and elev):
        if r["sk"] > 3.0 and not flora and size < 3.0:
            out["sky"] = r["sk"] * min(size, 3.0)
        elif r["sk"] <= 3.0:
            out["float"] = r["fl"] * min(size, 8.0) * (0.4 if flora else 1.0)
    if r["fl"] < -0.28 and not flora and size < 3.0 and not (r["sk"] < -2.5):
        out["sink"] = -r["fl"] * min(size, 8.0)
    if r["slope"] > 0.30 and r["tilt"] < 8.0 and size > 1.6 and not flora and r["fl"] > 0.12:
        out["tilt"] = r["slope"] * size
    if r["way"] < -0.2 and not flora and size > 0.4 and not ALLOW_ROAD.search(kind) and r["sy"] > 0.25:
        out["road"] = size * min(r["sy"], 3.0)
    if r["wd"] > 0.35 and not flora and size > 0.4 and r["sy"] > 0.3:
        out["water"] = r["wd"] * size
    if r["over"] and not flora and r["sy"] > 0.25 and r["y"] > -50:
        out["under"] = size
    if r["ovl"] > 0.55 and not flora:
        out["buried"] = r["ovl"] * size
    if lone and not flora and size > 0.35:
        out["lone"] = size
    return out


def main():
    path = sys.argv[1]
    depth = 2
    n = 60
    spots_out = None
    argv = sys.argv[2:]
    while argv:
        a = argv.pop(0)
        if a == "--spots":
            spots_out = argv.pop(0)
        elif a == "--n":
            n = int(argv.pop(0))
        elif a == "--sys-depth":
            depth = int(argv.pop(0))
    rows = load(path)
    # lone: no other non-flora object within 9 m, no site, a long way from any way
    cells = collections.defaultdict(list)
    for i, r in enumerate(rows):
        if r["flora"] == 0 and max(r["sx"], r["sz"]) > 0.35:
            cells[(int(r["x"] // 9), int(r["z"] // 9))].append(i)
    lone = set()
    for i, r in enumerate(rows):
        if r["flora"] or max(r["sx"], r["sz"]) <= 0.35 or r["site"] or r["way"] < 14.0:
            continue
        cx, cz = int(r["x"] // 9), int(r["z"] // 9)
        near = 0
        for dx in (-1, 0, 1):
            for dz in (-1, 0, 1):
                for j in cells.get((cx + dx, cz + dz), []):
                    if j != i and (rows[j]["x"] - r["x"]) ** 2 + (rows[j]["z"] - r["z"]) ** 2 < 81.0:
                        near += 1
        if near == 0:
            lone.add(i)
    per_region = collections.defaultdict(lambda: collections.Counter())
    per_sys = collections.defaultdict(lambda: collections.Counter())
    per_kind = collections.defaultdict(lambda: collections.Counter())
    worst = collections.defaultdict(float)
    cases = []
    totals = collections.Counter()
    for i, r in enumerate(rows):
        fl = flags(r, i in lone)
        sy = system(r, depth)
        per_sys[sy]["items"] += 1
        per_region[r["region"]]["items"] += 1
        for k, v in fl.items():
            per_region[r["region"]][k] += 1
            per_sys[sy][k] += 1
            kk = (sy, r["kind"].split("|")[0], k)
            per_kind[kk]["n"] += 1
            totals[k] += 1
            cases.append((v, k, r, i))
            worst[(sy, k)] = max(worst[(sy, k)], r["fl"] if k in ("float", "sky", "tilt") else -r["fl"] if k == "sink" else v)
    print("TOTAL items %d  %s" % (len(rows), dict(totals)))
    print("\nPER SYSTEM (items, float, sky, sink, tilt, road, water, under, buried, lone) worst-gap-by-kind")
    order = sorted(per_sys, key=lambda s: -sum(v for k, v in per_sys[s].items() if k != "items"))
    for s in order:
        c = per_sys[s]
        tot = sum(v for k, v in c.items() if k != "items")
        if tot == 0:
            continue
        print("%-46s %5d | %s | worst %s" % (s[:46], c["items"], " ".join("%s=%d" % (k, c[k]) for k in ("float", "sky", "sink", "tilt", "road", "water", "under", "buried", "lone") if c[k]),
              " ".join("%s:%.2f" % (k, worst[(s, k)]) for k in ("float", "sink") if (s, k) in worst)))
    print("\nPER REGION")
    for rg, c in sorted(per_region.items(), key=lambda a: -sum(v for k, v in a[1].items() if k != "items")):
        print("%-12s %6d | %s" % (rg, c["items"], " ".join("%s=%d" % (k, c[k]) for k in ("float", "sky", "sink", "tilt", "road", "water", "under", "buried", "lone") if c[k])))
    print("\nTOP KINDS per finding")
    for k in ("float", "sky", "sink", "tilt", "road", "water", "under", "buried", "lone"):
        ks = [(kk, c["n"]) for kk, c in per_kind.items() if kk[2] == k]
        ks.sort(key=lambda a: -a[1])
        print("  %s: %s" % (k, "; ".join("%s %s x%d" % (kk[0].split("/")[-1][:18] if False else kk[0][:30], kk[1][:26], c) for kk, c in ks[:12])))
    # the worst spots by quota per finding, at least 10 m apart; the Rift, the Summit and the Ossuary are counted above but not shot (other agents' areas)
    SKIP_SYS = re.compile(r"^(RealmRift|RealmPois/RiftScorch|SummitAltar|Area_ossuary|RealmPois/OssuaryGround)")
    QUOTA = {"float": 22, "tilt": 8, "sink": 7, "road": 6, "under": 6, "water": 4, "buried": 4, "sky": 3, "lone": 3}
    by_kind = collections.defaultdict(list)
    for v, k, r, i in cases:
        if SKIP_SYS.match(r["sys"]) or r["region"] in ("rift", "summit", "ossuary"):
            continue
        if -150 < r["x"] < 110 and 60 < r["z"] < 270:      # beside the Ossuary's streamed area: the wanderer walking in loads it (not shot)
            continue
        if r["kind"].startswith("col:RealmBounds") or r["sys"] == "Zone":
            continue
        near = 1.0 + (0.5 if r["way"] < 25.0 else 0.0) + (0.3 if r["site"] else 0.0)
        by_kind[k].append((v * near, k, r, i))
    picked = []
    for k, q in QUOTA.items():
        lst = sorted(by_kind[k], key=lambda a: -a[0])
        got = 0
        for v, kk, r, i in lst:
            if got >= q:
                break
            if any((p["x"] - r["x"]) ** 2 + (p["z"] - r["z"]) ** 2 < 100.0 for p in picked):
                continue
            picked.append({"x": r["x"], "y": r["y"], "z": r["z"], "size": max(r["sx"], r["sz"]), "h": r["sy"], "kind": r["kind"], "sys": r["sys"], "why": k, "score": round(v, 2),
                           "fl": r["fl"], "sk": r["sk"], "region": r["region"], "mesh": r["meshpath"]})
            got += 1
    picked.sort(key=lambda p: -p["score"])
    print("\nWORST SPOTS")
    for p in picked[:n]:
        print("%-6s %6.2f  %-8s (%7.1f,%7.1f) fl %.2f sk %.2f  %s  %s" % (p["why"], p["score"], p["region"], p["x"], p["z"], p["fl"], p["sk"], p["kind"][:32], p["sys"][:50]))
    if spots_out:
        json.dump(picked, open(spots_out, "w"), indent=1)


main()
