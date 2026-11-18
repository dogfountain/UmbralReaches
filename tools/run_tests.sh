#!/usr/bin/env bash
# Headless test gate for Umbral Reaches.
#
#   tools/run_tests.sh                 # every zz/*_test.tscn
#   tools/run_tests.sh quest skill     # only zz/quest_test.tscn, zz/skill_test.tscn
#   tools/run_tests.sh --quick         # only the world-free tier (tools/fast_tests.txt): for every change
#   (the full run, for a merge, shares one Realm cache across tests: .godot/realm_cache_tests)
#   JOBS=2 TEST_TIMEOUT=300 tools/run_tests.sh   # JOBS defaults to the performance cores; longest tests run first
#
# Each test runs in its own scratch HOME, so user:// (savegame.cfg, settings.cfg, codex.cfg)
# is never the owner's real profile. A test FAILS when any of these is true:
#   - the process exits nonzero, or is killed by the timeout;
#   - the log has "SCRIPT ERROR", "SHADER ERROR", "Parse Error" or "Failed to load script" (a parse error in
#     one script cascades silently otherwise; the tests' own PASS lines do not catch it);
#   - the log has a word-boundary, upper-case "FAIL" (every zz test prints FAIL on a failed check,
#     but several still quit(0)); "0 FAIL" / "FAIL 0" counts are ignored.
#   - (whole run) the static lint finds a Node/Callable-typed `static var` that
#     core/world/session_state.gd does not list (it would dangle after the night is freed).
#   - (whole run) the ratchet lint (tools/lint.sh, baseline tools/lint_baseline.txt) finds a file with
#     more string .call("..."), has_method(, .get("_x") or round-tag comments than its baseline, or a
#     file over 1,000 lines that grew by more than 50 lines. Lower counts pass; tighten with
#     `tools/lint.sh --update`. It runs once per invocation, however many tests are named.
# Exit status is the number of failing tests (0 = all green). Logs are kept in $OUT_DIR.
#
# Run folders (SCRATCH/umbral_tests.*): a passing run deletes its own run folder; a failing run
# keeps it so its logs can be read (the summary prints the path). KEEP_LOGS=1 keeps a passing
# run's folder too. Run folders older than a day are removed when a run starts.
#
# Run it before every pack (see .cursor/skills/umbral-pack).
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-$(command -v godot || echo /opt/homebrew/bin/godot)}"
TEST_TIMEOUT="${TEST_TIMEOUT:-300}"   # the doubled Realm builds in ~20 s more
JOBS="${JOBS:-$(( $(sysctl -n hw.perflevel0.physicalcpu 2>/dev/null || nproc 2>/dev/null || echo 4) ))}"   # one per performance core
SCRATCH="${SCRATCH:-${TMPDIR:-/tmp}}"
mkdir -p "$SCRATCH"
find "${SCRATCH%/}" -maxdepth 1 -type d -name 'umbral_tests.*' -mtime +1 -exec rm -rf {} + 2>/dev/null
RUN_DIR="$(mktemp -d "${SCRATCH%/}/umbral_tests.XXXXXX")" || { echo "cannot make a run dir under $SCRATCH" >&2; exit 99; }
OUT_DIR="$RUN_DIR/logs"
mkdir -p "$OUT_DIR"

BAD_RE='SCRIPT ERROR|SHADER ERROR|Parse Error|Failed to load script|Instance index out of bounds|p_count > instance_count'
FAIL_RE='(^|[^A-Za-z_])FAIL([^A-Za-z_]|$)'
ZERO_RE='(^|[^0-9])0 FAIL([^A-Za-z_]|$)|FAIL 0([^0-9]|$)'   # "DIAG 0 FAIL ok" is a count, not a failure

fail_lines() { grep -nE "$FAIL_RE" "$1" | grep -vE "$ZERO_RE"; }

# One generator cache for every test (core/world/realm/gen_cache.gd user_dir()): each test has its own
# HOME, so user://realm_cache/ started empty for every test and each rebuilt the whole Realm (flora,
# rocks, trees: about 40 s of the doubled world's ~55 s boot). It lives under .godot/ (not in git) and
# survives between runs; a generator edit retires its own entries by salt. UMBRAL_CACHE_DIR= (empty)
# turns the shared cache off.
export UMBRAL_CACHE_DIR="${UMBRAL_CACHE_DIR-$ROOT/.godot/realm_cache_tests}"
[ -n "$UMBRAL_CACHE_DIR" ] && mkdir -p "$UMBRAL_CACHE_DIR"

# --quick: only the world-free tier (tools/fast_tests.txt), a couple of minutes; the full run before a merge
QUICK=""
if [ "${1:-}" = "--quick" ]; then
	shift
	TESTS_FILE="$ROOT/tools/fast_tests.txt"
	QUICK=1
fi

tests=()
if [ "$#" -gt 0 ]; then
	for n in "$@"; do
		n="${n%.tscn}"; n="${n#zz/}"; n="${n%_test}"
		tests+=("zz/${n}_test.tscn")
	done
elif [ -n "${TESTS_FILE:-}" ]; then
	# TESTS_FILE=tools/fast_tests.txt: one test name per line (CI's world-free tier)
	while IFS= read -r n || [ -n "$n" ]; do
		n="${n%$'\r'}"; [ -z "$n" ] && continue
		case "$n" in \#*) continue ;; esac
		n="${n%.tscn}"; n="${n#zz/}"; n="${n%_test}"
		tests+=("zz/${n}_test.tscn")
	done < "$TESTS_FILE"
else
	for f in "$ROOT"/zz/*_test.tscn; do tests+=("zz/$(basename "$f")"); done
fi

# Run one test with an isolated HOME and a watchdog; write <name>.log and <name>.status.
run_one() {
	local scene="$1" name home log pid rc=0 waited=0
	name="$(basename "$scene" .tscn)"
	home="$RUN_DIR/home_$name"
	log="$OUT_DIR/$name.log"
	mkdir -p "$home"
	if [ ! -f "$ROOT/$scene" ]; then
		echo "missing scene $scene" > "$log"; echo "MISSING" > "$OUT_DIR/$name.status"; return
	fi
	# HOME isolates user:// on Mac/Linux. On Windows Godot still writes under AppData, so also set
	# UMBRAL_SAVE_DIR (core/util/save_dir.gd) into this test's scratch home.
	# Only there: Mac/Linux tests read user://savegame.cfg directly (slots_test), so the seam stays off.
	local save_env=()
	case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) mkdir -p "$home/saves"; save_env=(UMBRAL_SAVE_DIR="$home/saves") ;; esac
	env HOME="$home" ${save_env[@]+"${save_env[@]}"} "$GODOT" --headless --path "$ROOT" "res://$scene" > "$log" 2>&1 &
	pid=$!
	while kill -0 "$pid" 2>/dev/null; do
		if [ "$waited" -ge "$TEST_TIMEOUT" ]; then
			kill -TERM "$pid" 2>/dev/null; sleep 2; kill -KILL "$pid" 2>/dev/null
			echo "RUNNER TIMEOUT after ${TEST_TIMEOUT}s" >> "$log"
			echo "TIMEOUT" > "$OUT_DIR/$name.status"
			wait "$pid" 2>/dev/null
			return
		fi
		sleep 1; waited=$((waited + 1))
	done
	wait "$pid"; rc=$?
	if grep -qE "$BAD_RE" "$log"; then
		echo "SCRIPT_ERROR" > "$OUT_DIR/$name.status"
	elif fail_lines "$log" > /dev/null; then
		echo "FAIL" > "$OUT_DIR/$name.status"
	elif [ "$rc" -eq 137 ] && tail -n 3 "$log" | grep -qE '(^|[^A-Za-z_])PASS([^A-Za-z_]|$)'; then
		# secrets tests print their PASS line, then OS.kill() themselves (exit 137) on purpose
		echo "PASS ${waited}s (self-kill after PASS)" > "$OUT_DIR/$name.status"
	elif [ "$rc" -ne 0 ]; then
		echo "EXIT_$rc" > "$OUT_DIR/$name.status"
	else
		echo "PASS ${waited}s" > "$OUT_DIR/$name.status"
	fi
}

# Static lint: a static var typed Node / Callable outlives the
# night that set it. Every one must be listed in core/world/session_state.gd NODE_REFS (which
# reset_night() clears). Also reports the static var total so growth is visible.
lint_fail=0
REG="$ROOT/core/world/session_state.gd"
while IFS= read -r hit; do
	[ -z "$hit" ] && continue
	file="${hit%%:*}"; rest="${hit#*:}"; rest="${rest#*:}"
	var="$(echo "$rest" | sed -E 's/^static var ([A-Za-z_0-9]+).*/\1/')"
	if ! grep -qF "\"$file: $var\"" "$REG"; then
		echo "LINT static Node/Callable not in session_state.gd NODE_REFS: $file: $var"
		lint_fail=1
	fi
done <<EOF2
$(cd "$ROOT" && grep -rnE '^static var [A-Za-z_0-9]+ *: *(Node|Node2D|Node3D|Control|CanvasLayer|Object|Callable)( |=|$)' core ui world autoload --include='*.gd' 2>/dev/null)
EOF2
static_total="$(cd "$ROOT" && grep -rhE '^static var ' core ui world autoload --include='*.gd' 2>/dev/null | wc -l | tr -d ' ')"
echo "lint: $static_total static vars in shipping code"

# Ratchet lint (grep/awk only, about a second): counts may fall, never rise. See tools/lint.sh.
ratchet_fail=0
ratchet_out="$("$ROOT/tools/lint.sh" 2>&1)" || ratchet_fail=1
echo "$ratchet_out"

echo "Umbral tests: ${#tests[@]} scene(s), jobs=$JOBS, timeout=${TEST_TIMEOUT}s, logs in $OUT_DIR"
# Longest first (durations from the last run; a test never timed counts as long), so the 2-minute
# tests are not the tail. Then a real pool: macOS bash 3.2 has no `wait -n`, and the old fallback ran
# lockstep batches that each waited for their slowest test while the other slots sat idle.
TIMES="$ROOT/.godot/umbral_test_times"
ordered=()
while IFS= read -r line; do ordered+=("${line#* }"); done <<EOF3
$(for t in "${tests[@]}"; do
	n="$(basename "$t" .tscn)"
	s="$(awk -v n="$n" '$1 == n {print $2}' "$TIMES" 2>/dev/null)"
	echo "${s:-999} $t"
done | sort -rn)
EOF3
# Warm the shared cache: the first (longest) test runs alone, so it builds the Realm once and every
# test after it adopts the cached flora, rocks and trees instead of all of them building it at once.
if [ -z "$QUICK" ] && [ "${#ordered[@]}" -gt 1 ] && [ -n "$UMBRAL_CACHE_DIR" ]; then
	echo "warming the shared cache with ${ordered[0]} ..."
	run_one "${ordered[0]}"
	ordered=("${ordered[@]:1}")
fi
pids=()
live() {
	local n=0 p
	for p in "${pids[@]-}"; do
		[ -n "$p" ] && kill -0 "$p" 2>/dev/null && n=$((n + 1))
	done
	echo "$n"
}
for t in "${ordered[@]}"; do
	while [ "$(live)" -ge "$JOBS" ]; do sleep 0.5; done
	run_one "$t" &
	pids+=($!)
done
wait

# remember each passing test's time for the next run's order
{
	for t in "${tests[@]}"; do
		n="$(basename "$t" .tscn)"
		s="$(grep -oE '^PASS [0-9]+' "$OUT_DIR/$n.status" 2>/dev/null | awk '{print $2}')"
		[ -n "$s" ] && echo "$n $s"
	done
	awk 'NR==FNR {seen[$1]=1; next} !($1 in seen)' <(for t in "${tests[@]}"; do basename "$t" .tscn; done) "$TIMES" 2>/dev/null
} > "$TIMES.new" && mv "$TIMES.new" "$TIMES"

failed=0
for t in "${tests[@]}"; do
	name="$(basename "$t" .tscn)"
	st="$(cat "$OUT_DIR/$name.status" 2>/dev/null || echo NO_STATUS)"
	printf '%-28s %s\n' "$name" "$st"
	case "$st" in
		PASS*) ;;
		*)
			failed=$((failed + 1))
			{ grep -nE "$BAD_RE|RUNNER TIMEOUT" "$OUT_DIR/$name.log"; fail_lines "$OUT_DIR/$name.log"; } | head -8 | sed 's/^/    /'
			;;
	esac
done
if [ "$lint_fail" -ne 0 ]; then echo "static lint                  FAIL"; failed=$((failed + 1)); fi
if [ "$ratchet_fail" -ne 0 ]; then echo "ratchet lint                 FAIL (tools/lint.sh; --update only when counts fell)"; failed=$((failed + 1)); fi
echo "----"
if [ "$failed" -eq 0 ]; then echo "ALL ${#tests[@]} PASS"; else echo "$failed of ${#tests[@]} FAILED (logs: $OUT_DIR)"; fi
if [ "$failed" -eq 0 ]; then
	if [ -z "${KEEP_LOGS:-}" ]; then rm -rf "$RUN_DIR"; else echo "logs kept in $OUT_DIR"; fi
fi
exit "$failed"
