"""The Deep South's models, by script: tools/blender/run.sh reach_south.py -- [--only arches,...] [--preview DIR]

  art/models/reach_s_arches.glb   the Long Arches kit (reach_south_arches.py)
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import reach_south_lib as L
from reach_south_lib import bpy, Vector, Matrix

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ONLY = args[args.index("--only") + 1].split(",") if "--only" in args else []
L.PREVIEW_DIR[0] = args[args.index("--preview") + 1] if "--preview" in args else ""
L.HIDE.extend(args[args.index("--hide") + 1].split(",") if "--hide" in args else [])


def assemble(objs, placements):
    """Copies of the objects whose names start with a piece name, placed: [(piece, x, y, z, yaw, mirror)]."""
    out = []
    for (piece, x, y, z, yaw, mir) in placements:
        for o in objs:
            if not o.name.startswith(piece + "__"):
                continue
            c = o.copy()
            c.hide_render = False
            bpy.context.scene.collection.objects.link(c)
            sx = -1.0 if mir else 1.0
            c.matrix_world = Matrix.Translation((x, y, z)) @ Matrix.Rotation(yaw, 4, 'Z') @ Matrix.Diagonal((sx, 1, 1, 1))
            out.append(c)
    return out


def do_arches():
    import reach_south_arches as A
    objs = A.build_all(L.PREVIEW_DIR[0])
    L.export(objs, os.path.join(L.MODELS, "reach_s_arches.glb"), "arches")
    if not L.PREVIEW_DIR[0]:
        return
    for o in objs:
        o.hide_render = True
    pl = [("ArchL", -12, 0, 9, 0, False), ("ArchL", 0, 0, 9, 0, False), ("ArchL", 12, 0, 9, 0, False)]
    for x in (-18, -6, 6, 18):
        for i in range(6):
            pl.append(("PierL%d" % (i % 2), x, 0, 9 - 1.5 * (i + 1), 0, False))
        pl.append(("PierFoot", x, 0, 9 - 1.5 * 6, 0, False))
    zu = 9.0 + A.H_ARCH_L + A.U_BELOW
    for x in (-15, -9, -3, 3, 9, 15):
        pl.append(("ArchU", x, 0, zu, 0, False))
    zc = zu + A.H_ARCH_U + A.H_CHAN_BASE
    for x in (-12, 0, 12):
        pl.append(("Chan", x, 0, zc, 0, False))
    pieces = assemble(objs, pl)
    pl2 = [("ArchLBroken", 36, 0, 9, 0, False), ("ArchL", 24, 0, 9, 0, False), ("ArchL", 48, 0, 9, 0, False),
           ("ArchUBrokenE", 33, 0, zu, 0, False), ("ArchUBrokenW", 39, 0, zu, 0, False), ("ChanBroken", 36, 0, zc, 0, False)]
    for x in (30, 42, 54, 18):
        for i in range(6):
            pl2.append(("PierL%d" % (i % 2), x, 0, 9 - 1.5 * (i + 1), 0, False))
        pl2.append(("PierFoot", x, 0, 9 - 1.5 * 6, 0, False))
    for x in (21, 27, 45, 51):
        pl2.append(("ArchU", x, 0, zu, 0, False))
    for x in (24, 48):
        pl2.append(("Chan", x, 0, zc, 0, False))
    pieces += assemble(objs, pl2)
    bpy.ops.mesh.primitive_plane_add(size=300, location=(20, 0, -1.0))
    L.preview(pieces, "arches", [((-34, -58, 14), (8, 0, 11), 34), ((8, -42, 3), (4, 0, 12), 36), ((60, -26, 9), (36, 0, 11), 30),
                                  ((-10, -25, 22), (6, 0, 17), 40), ((40, 50, 14), (36, 0, 11), 34)])


def do_castellum():
    import reach_south_castellum as C
    objs = C.build_all()
    L.export(objs, os.path.join(L.MODELS, "reach_s_castellum.glb"), "castellum")
    if not L.PREVIEW_DIR[0]:
        return
    if "--far" in args:                  # the far hull (Tower_Far): a look from where it is seen (190 m out), polish pass
        vis = [o for o in objs if o.name.startswith("Tower_Far__")]
        for o in objs:
            if o not in vis:
                o.hide_render = True
        bpy.ops.mesh.primitive_plane_add(size=600, location=(0, 0, -15.0))
        L.preview(vis, "castellum_far", [((-60, -80, 6), (0, 0, -3), 34), ((70, 60, 12), (0, 0, -2), 34), ((0, -90, 25), (0, 0, 0), 30)])
        return
    vis = [o for o in objs if o.name.startswith(("Tower__", "Roof__")) and not any(k in o.name for k in L.HIDE)]
    bpy.ops.mesh.primitive_plane_add(size=300, location=(0, 0, -15.0))
    L.preview(vis, "castellum", [((-26, -34, 2), (0, 0, -3), 34), ((22, 30, -6), (0, 0, -2), 36), ((0, -16, -9), (0, 0, -7), 50)])


JOBS = {"arches": do_arches, "castellum": do_castellum}

if __name__ == "__main__":
    for k, fn in JOBS.items():
        if ONLY and k not in ONLY:
            continue
        print("=== ", k)
        fn()
