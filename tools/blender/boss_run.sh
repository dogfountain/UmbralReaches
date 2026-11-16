#!/bin/sh
# One boss, build to final GLB: tools/blender/boss_run.sh bone_abbot [extra build args]
# 1 the boss script bakes the body (socket-rigged GLB), 2 the body is kept as art/blender/boss_<name>_body.glb,
# 3 boss_humanoid_anim.py gives it the real skeleton and the keyed clips and writes art/models/boss_<name>.glb.
set -e
cd "$(dirname "$0")/../.."
name="$1"; shift
tools/blender/run.sh boss_$name.py -- "$@"
if [ "$name" != "thornwarden" ]; then
  cp art/models/boss_$name.glb art/blender/boss_${name}_body.glb
  tools/blender/run.sh boss_humanoid_anim.py -- --boss $name
fi
