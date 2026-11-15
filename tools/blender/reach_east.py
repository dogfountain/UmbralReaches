"""The East Reach's assets, by script: tools/blender/run.sh reach_east.py -- [--only bell|tower|nave|town] [--preview DIR]

  art/models/reach_e_bell.glb     the eighth bell (reach_east_bell.py): Bell, BellFar, BellShards, Ejecta, BellCol
  art/models/reach_e_tower.glb    the Cairn Tower (reach_east_tower.py)
  art/models/reach_e_nave.glb     the Drowned Nave (reach_east_nave.py)
  art/models/reach_e_town.glb     Lastlight: the East Gate, the lamp tower, the inn, the stable, the watch post (reach_east_town.py)
  core/world/realm/reach_east_data.gd   the numbers the game needs, written by the script

Masonry, bronze, rock, bark and plank maps are generated (reach_east_lib.py, r37_south_lib.py); nothing is downloaded.
"""
import sys
import os
import math

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib
import r37_south_lib as L
importlib.reload(L)
import reach_east_lib as E
importlib.reload(E)

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ONLY = ARGS[ARGS.index("--only") + 1] if "--only" in ARGS else "all"
PREVIEW = ARGS[ARGS.index("--preview") + 1] if "--preview" in ARGS else ""
DATA = {}


def run_bell():
    import reach_east_bell as BELL
    importlib.reload(BELL)
    L.reset()
    M = BELL.mats()
    objs = []
    BELL.build_all(objs, M)
    L.export(os.path.join(L.MODEL_DIR, "reach_e_bell.glb"), objs)
    if PREVIEW:
        os.makedirs(PREVIEW, exist_ok=True)
        for o in objs:
            if o.name.endswith("Col") or o.name.endswith("Far"):
                o.hide_render = True
        vis = [o for o in objs if not o.hide_render]
        import r37_wall_lib as WL
        for clay in (False, True):
            WL.clay_preview(os.path.join(PREVIEW, "bell%s.png" % ("_clay" if clay else "")), vis, (6, 4, 4), 46.0, ((20, 0.18), (-40, 0.14), (90, 0.12), (170, 0.2), (-130, 0.25), (0, 1.0, 70.0)), (1300, 900), 35, clay)


def run_module(mod, fname, look, dist, views, res=(1300, 900), spread=0.0):
    m = importlib.import_module(mod)
    importlib.reload(m)
    L.reset()
    objs = []
    m.build_all(objs, DATA)
    L.export(os.path.join(L.MODEL_DIR, fname), objs)
    if PREVIEW:
        os.makedirs(PREVIEW, exist_ok=True)
        for o in objs:
            if o.name.endswith("Col") or o.name.endswith("Far"):
                o.hide_render = True
        vis = [o for o in objs if not o.hide_render]
        if spread:
            for i, o in enumerate(vis):
                o.location = L.G((i * spread, 0, 0))
        import r37_wall_lib as WL
        for clay in (False, True):
            WL.clay_preview(os.path.join(PREVIEW, fname.replace(".glb", "_clay.png" if clay else ".png")), vis, look, dist, views, res, 35, clay)


if ONLY in ("all", "bell"):
    run_bell()
if ONLY in ("all", "tower"):
    run_module("reach_east_tower", "reach_e_tower.glb", (0, 14, 0), 70.0, ((20, 0.15), (110, 0.1), (200, 0.2), (290, 0.12)))
if ONLY in ("all", "nave"):
    run_module("reach_east_nave", "reach_e_nave.glb", (0, 12, 0), 110.0, ((20, 0.2), (90, 0.08), (160, 0.25), (250, 0.12)), (1500, 900))
if ONLY in ("all", "town"):
    run_module("reach_east_town", "reach_e_town.glb", (68, 7, 0), 150.0, ((12, 0.12), (-12, 0.1), (0, 0.1, 60.0)), (2200, 700), spread=34.0)
