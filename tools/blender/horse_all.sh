#!/bin/sh
# Build every breed: tools/blender/horse_all.sh [preview-dir]
cd "$(dirname "$0")/../.." || exit 1
for b in palfrey garron fenpony draught; do
	if [ -n "$1" ]; then
		sh tools/blender/run.sh horse_build.py -- --breed "$b" --preview "$1/$b.png" > "/tmp/horse_$b.log" 2>&1
	else
		sh tools/blender/run.sh horse_build.py -- --breed "$b" > "/tmp/horse_$b.log" 2>&1
	fi
	grep "INFO $b\|FINAL\|Traceback" "/tmp/horse_$b.log"
done
