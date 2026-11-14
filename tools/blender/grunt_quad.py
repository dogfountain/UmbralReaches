"""Quadruped grunts (r38d): crawler, leaper, burrower, mite. Each is ONE continuous sculpted skin on its QuadRig
(core/enemy/quad_rig.gd): a signed-distance model (quad_sdf.py: smooth-union limbs, torso lofts, skulls, claws,
spurs, no seams) meshed with surface nets, subdivided, cut with anatomy and plates (quad_run.Sculpt,
quad_bark.plates), a ~10k-triangle low decimated from it, albedo / roughness / emission baked from the high's
materials and normal + AO high to low (quad_sculpt_lib.bake), skinned to the rig's bones by smooth envelope
weights, exported as one GLB on a flat armature (a bone per rig socket) that GruntSkin poses.

  tools/blender/run.sh grunt_quad.py -- --kind leaper [--no-bake] [--preview /tmp/l.png] [--voxel 0.005]
Writes art/models/grunt_<kind>.glb and art/textures/grunt_<kind>_{albedo,normal,orm,emit}.png  (GRUNT_OUT=<dir>
redirects them). The kinds live in quad_<kind>.py. Review renders: quad_review.py.
"""
import importlib
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import quad_run as R

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
KIND = args[args.index("--kind") + 1] if "--kind" in args else "leaper"
R.run(importlib.import_module("quad_" + KIND))
