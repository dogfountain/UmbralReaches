"""The Far Reaches' towns, modelled by script (docs/far_reaches.md; umbral-blender skill; hero-asset bar: each piece
reviewed from a turnaround before it goes in the game). Nothing downloaded: the materials are made in reach_town_lib.

  tools/blender/run.sh reach_towns.py                                  writes art/models/reach_towns.glb and the boxes
  tools/blender/run.sh reach_towns.py -- --preview DIR [--only A,B]    and turnaround stills of the pieces (all, or A, B)
  tools/blender/run.sh reach_towns.py -- --preview DIR --no-export     stills only

  Fallowmere   reach_town_fallowmere.py   FM_*   the tithe barn, the farmhouse, cottages, the dovecote, ricks, the fold
  Reedholm     reach_town_reedholm.py     RH_*   stilt houses on the mere, boardwalks, the landing, racks, boats
  Lastlight    reach_town_lastlight.py    LL_*   the walls and gates, the lamp tower, the inn, the stable, the watch

Writes art/models/reach_towns.glb (every piece by name, far silhouettes *Far) and core/world/realm/reach_towns_boxes.gd
(collision boxes per piece, and the numbers the game places by).
"""
import os
import sys
import importlib

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import r37_south_lib as L
import reach_town_lib as RL

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
PREVIEW = args[args.index("--preview") + 1] if "--preview" in args else ""
ONLY = args[args.index("--only") + 1].split(",") if "--only" in args else []
TOWNS = args[args.index("--towns") + 1].split(",") if "--towns" in args else ["fallowmere", "reedholm", "lastlight"]
EXPORT = "--no-export" not in args


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.unit_settings.system = 'METRIC'
    objs = []
    fars = []
    views = {}
    for t in TOWNS:
        path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "reach_town_%s.py" % t)
        if not os.path.exists(path):
            continue
        mod = importlib.import_module("reach_town_%s" % t)
        o, f = mod.build()
        objs += o
        fars += f
        views.update(mod.VIEWS)
    for o in objs + fars:
        print("PIECE %-18s %7d tris" % (o.name, L.tris(o)))
    if EXPORT and set(TOWNS) == {"fallowmere", "reedholm", "lastlight"}:
        L.export(os.path.join(L.MODEL_DIR, "reach_towns.glb"), objs + fars)
        RL.write_boxes(os.path.join(L.ROOT, "core", "world", "realm", "reach_towns_boxes.gd"), "tools/blender/reach_towns.py")
    elif EXPORT:
        print("NOT EXPORTED: only some towns were built (--towns)")
    if PREVIEW:
        os.makedirs(PREVIEW, exist_ok=True)
        for o in objs + fars:
            if ONLY and o.name not in ONLY:
                continue
            look, dist = views.get(o.name, ((0.0, 3.0, 0.0), 20.0))
            RL.turnaround(os.path.join(PREVIEW, "rt"), o, look=look, dist=dist)


main()
