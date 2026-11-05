#!/bin/sh
# Run a boss build with the Metal workaround: tools/blender/run.sh boss_bone_abbot.py [-- args]
export CYCLES_METAL_DISABLE_BINARY_ARCHIVES=1
script="$1"; shift
exec blender -b -P "$(dirname "$0")/$script" "$@"
