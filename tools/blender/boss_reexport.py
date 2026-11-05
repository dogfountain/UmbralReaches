"""Re-export a baked boss from its saved scene (art/blender/boss_*.blend) with the meshes decimated
to a triangle budget. Decimation (collapse) keeps the UVs, so the baked atlas still fits.
  tools/blender/run.sh boss_reexport.py -- boss_bone_abbot 90000
"""
import bpy
import os
import sys
sys.path.insert(0, os.path.dirname(__file__))
import boss_kit as K

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
args = sys.argv[sys.argv.index("--") + 1:]
name, budget = args[0], int(args[1])
bpy.ops.wm.open_mainfile(filepath=os.path.join(ROOT, "art", "blender", name + ".blend"))
objs = [o for o in bpy.data.objects if o.type == 'MESH' and "sock" in o]
tri = lambda o: sum(len(p.vertices) - 2 for p in o.data.polygons)
total = sum(tri(o) for o in objs)
small = sum(tri(o) for o in objs if tri(o) < 1500)
ratio = max(0.05, min(1.0, (budget - small) / max(total - small, 1)))
for o in objs:
    if tri(o) >= 1500 and ratio < 1.0:
        d = o.modifiers.new("Dec", 'DECIMATE')
        d.ratio = ratio
        K.apply_mods(o)
print("DECIMATE", name, total, "->", sum(tri(o) for o in objs), "ratio %.2f" % ratio)
sockets = K.quad_sockets(0.56, 1.15, 0.2, 0.32) if name == "boss_thornwarden" else None
K.split_and_export(objs, os.path.join(ROOT, "art", "models", name + ".glb"), {"crozier": "boss_hand_r"}, sockets)
