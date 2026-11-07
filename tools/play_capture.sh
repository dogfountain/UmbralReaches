#!/usr/bin/env bash
# Runs the play-through capture harness (zz/play_capture.tscn), one godot process per section, each with a
# hard watchdog, and folds the engine's own errors into <out>/<section>/errors.txt.
#
#   tools/play_capture.sh                       # every section, windowed
#   tools/play_capture.sh horse wanderer        # just these
#   HEADLESS=1 tools/play_capture.sh horse      # the "runs clean" check: no window, no images
#   OUT=/some/dir TIMEOUT=170 tools/play_capture.sh ui
#   EXTRA=--lightlog tools/play_capture.sh bosses_a     # extra harness flags (--nolit, --lightlog)
#
# Sections: horse wanderer spells enemies_a enemies_b enemies_c enemies_d bosses_a bosses_b bosses_c villagers
#           regions_a regions_b places ui.
# Windowed runs open a window on the screen for the length of the section (about 1-3 minutes). The save is
# never touched (Travel._busy, and UMBRAL_SAVE_DIR points at a scratch folder).
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-$(command -v godot || echo /opt/homebrew/bin/godot)}"
OUT="${OUT:-/private/tmp/claude-501/-Users-luke-UmbralReaches/968888c4-6238-49b1-a0f8-2ba292b49c0a/scratchpad/play}"
TIMEOUT="${TIMEOUT:-170}"
HEADLESS="${HEADLESS:-0}"
ALL="horse wanderer spells enemies_a enemies_b enemies_c enemies_d bosses_a bosses_b bosses_c villagers regions_a regions_b places ui"
SECTIONS="${*:-$ALL}"
mkdir -p "$OUT"
SAVES="$(mktemp -d "${TMPDIR:-/tmp}/play_capture_saves.XXXXXX")"
trap 'rm -rf "$SAVES"' EXIT

for s in $SECTIONS; do
	mkdir -p "$OUT/$s"
	LOG="$OUT/$s/run.log"
	echo "== $s"
	args=(--path "$ROOT")
	[ "$HEADLESS" = "1" ] && args+=(--headless)
	args+=(res://zz/play_capture.tscn -- "--out=$OUT" "--only=$s" "--timeout=$TIMEOUT" ${EXTRA:-})
	UMBRAL_SAVE_DIR="$SAVES" "$GODOT" "${args[@]}" > "$LOG" 2>&1 &
	pid=$!
	# a second, outer watchdog: the harness has its own, this one catches a hung engine
	( sleep $((TIMEOUT + 150)); kill -9 "$pid" 2>/dev/null ) >/dev/null 2>&1 &
	wd=$!
	wait "$pid" 2>/dev/null
	rc=$?
	pkill -P "$wd" 2>/dev/null       # the watchdog's own sleep (not an engine process)
	kill "$wd" 2>/dev/null
	wait "$wd" 2>/dev/null
	# fold the engine's errors and warnings into errors.txt (counted, so a flood reads as one line)
	{
		echo
		echo "# engine log lines (run.log) for section $s, exit code $rc"
		grep -E "SCRIPT ERROR|Parse Error|Failed to load script|^ERROR:|^WARNING:|PLAYCAP FAIL|USER ERROR|USER WARNING" "$LOG" \
			| sed -E 's/[0-9]+(\.[0-9]+)?/N/g' | sort | uniq -c | sort -rn | head -60
		echo "# built-in timings"
		grep -E "REALM built in|PLAYCAP realm built|PLAYCAP studio|PLAYCAP runway" "$LOG"
	} >> "$OUT/$s/errors.txt"
	if [ -f "$OUT/$s/perf.txt" ]; then
		grep -E "REALM built in" "$LOG" | head -1 | sed 's/^/engine: /' >> "$OUT/$s/perf.txt"
	fi
	nerr=$(grep -cE "SCRIPT ERROR|Parse Error|Failed to load script" "$LOG")
	echo "   exit $rc, script errors: $nerr, files: $(ls "$OUT/$s" | grep -c '\.png$')"
done
# make sure nothing of ours is left running
jobs -p | xargs kill 2>/dev/null
exit 0
