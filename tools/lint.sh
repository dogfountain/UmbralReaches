#!/usr/bin/env bash
# Ratchet lint over shipping code (core ui world autoload, *.gd; not zz/ or tools/).
#
#   tools/lint.sh            # compare against tools/lint_baseline.txt; exit 1 on any rise
#   tools/lint.sh --update   # rewrite the baseline from the current tree
#
# Per file it counts:
#   calls   .call("x") / .call_deferred("x") by string name
#   hasm    has_method(
#   priv    .get("_x") private reads
#   round   lines with a comment naming a round tag (r12, r35 ...)
# A file may not exceed its baseline count in any measure; a file missing from the baseline may have
# none. Lower counts pass (with a hint to tighten). Files over 1000 lines are also recorded by line
# count and may not grow by more than 50 lines against it (a new file over 1000 lines has no room).
# Baseline format, one file per line: "path calls hasm priv round lines" (lines = 0 at or under 1000).
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASE="$ROOT/tools/lint_baseline.txt"
GROW=50
BIG=1000

current() {
	cd "$ROOT" || exit 2
	find core ui world autoload -name '*.gd' 2>/dev/null | LC_ALL=C sort | while IFS= read -r f; do
		awk -v f="$f" -v big="$BIG" '
			{ n++ }
			/\.call(_deferred)?\("/ { c += gsub(/\.call(_deferred)?\("/, "&") }
			/has_method\(/ { h += gsub(/has_method\(/, "&") }
			/\.get\("_/ { p += gsub(/\.get\("_/, "&") }
			/#.*(^|[^A-Za-z0-9_])r[0-9][0-9]([^A-Za-z0-9_]|$)/ { r++ }
			END { if (c + h + p + r > 0 || n > big) printf "%s %d %d %d %d %d\n", f, c, h, p, r, (n > big ? n : 0) }
		' "$f"
	done
}

if [ "${1:-}" = "--update" ]; then
	current > "$BASE"
	echo "lint: baseline rewritten ($(wc -l < "$BASE" | tr -d ' ') files)"
	exit 0
fi
[ -f "$BASE" ] || { echo "lint: no baseline (run tools/lint.sh --update)"; exit 1; }

current | awk -v base="$BASE" -v grow="$GROW" '
	BEGIN {
		split("calls has_method private_get round_comments", M, " ")
		while ((getline line < base) > 0) {
			split(line, a, " "); b[a[1]] = 1
			for (i = 1; i <= 4; i++) B[a[1], i] = a[i + 1]
			BL[a[1]] = a[6]
		}
	}
	NF == 6 {
		f = $1; seen[f] = 1
		for (i = 1; i <= 4; i++) {
			allow = (f in b) ? B[f, i] : 0
			tot[i] += $(i + 1)
			if ($(i + 1) > allow) { printf "LINT %s: %s %d > baseline %d\n", f, M[i], $(i + 1), allow; bad = 1 }
			else if ($(i + 1) < allow) lower++
		}
		if ($6 > 0) {
			lim = (f in b && BL[f] > 0) ? BL[f] + grow : 1000
			if ($6 > lim) { printf "LINT %s: %d lines (over 1000), baseline %d, +%d allowed\n", f, $6, BL[f], grow; bad = 1 }
		}
	}
	END {
		for (f in b) if (!(f in seen)) lower++
		printf "lint: calls=%d has_method=%d private_get=%d round_comments=%d\n", tot[1], tot[2], tot[3], tot[4]
		if (lower > 0) print "lint: counts are below baseline in " lower " place(s); run tools/lint.sh --update to tighten"
		exit bad
	}'
