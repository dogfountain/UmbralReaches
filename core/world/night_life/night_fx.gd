extends RefCounted
## Every particle burst the living night throws, as a NAMED PRESET (one place), so that
##   1  the game never builds an emitter or compiles a particle material mid-play for them: NightWarm replays `warm_list()` behind the loading
##      cover, one burst of each preset in each colour it is ever used in (Vfx pools emitters by colour and options; the first burst of a kind is a
##      node built and a particle shader specialised, a hitch in a fight);
##   2  a count that varies with a stack or a size is the preset's `ratio` (Vfx emits that share of the preset without making a new one);
##   3  zz/night_life_test.tscn can fail when a system throws a burst that is not here.
## Systems call `NightFx.burst(at, colour, id, dir, ratio)`; nothing else under core/world/night_life calls Vfx.burst. Static.

const PRESETS := {
	"arena_mark": {"count": 40, "life": 1.2, "speed": Vector2(2.0, 7.0), "size": 0.07, "gravity": -1.0, "spread": 180.0, "damping": 1.5},
	"crit": {"count": 22, "life": 0.55, "speed": Vector2(3.0, 8.0), "size": 0.06, "gravity": -9.0, "trail": 0.12, "spread": 70.0, "damping": 2.0},
	"hurt": {"count": 12, "life": 0.35, "speed": Vector2(2.0, 6.0), "size": 0.045, "gravity": 4.0, "spread": 60.0, "damping": 2.0},
	"kill": {"count": 18, "life": 1.5, "speed": Vector2(0.8, 2.6), "size": 0.07, "gravity": 0.9, "spread": 40.0, "damping": 1.2},
	"kindle": {"count": 40, "life": 1.8, "speed": Vector2(1.5, 6.0), "size": 0.08, "gravity": 0.5, "spread": 60.0, "damping": 1.1},
	"mote": {"count": 6, "life": 2.6, "speed": Vector2(0.15, 0.5), "size": 0.07, "gravity": 0.25, "spread": 80.0, "damping": 0.8},
	"found": {"count": 34, "life": 1.3, "speed": Vector2(1.5, 5.0), "size": 0.09, "gravity": 0.6, "spread": 180.0, "damping": 1.6},
	"snap": {"count": 20, "life": 0.4, "speed": Vector2(3.0, 8.0), "size": 0.06, "gravity": -4.0, "trail": 0.1, "spread": 180.0, "damping": 3.0},
	"cast_done": {"count": 14, "life": 0.4, "speed": Vector2(2.0, 5.0), "size": 0.05, "gravity": -3.0, "spread": 180.0, "damping": 2.0},
	"fizzle": {"count": 10, "life": 0.3, "speed": Vector2(1.0, 3.0), "size": 0.04, "gravity": 4.0, "spread": 180.0, "damping": 2.5},
	"scar": {"count": 10, "life": 1.0, "speed": Vector2(0.3, 1.0), "size": 0.05, "gravity": -1.2, "spread": 35.0},
	"shard": {"count": 4, "life": 0.7, "speed": Vector2(0.2, 0.8), "size": 0.045, "gravity": 3.0, "spread": 180.0},
	"shaken": {"count": 3, "life": 0.4, "speed": Vector2(1.0, 2.5), "size": 0.04, "gravity": 0.0, "spread": 180.0, "damping": 2.0},
	"reson": {"count": 6, "life": 1.2, "speed": Vector2(0.2, 0.6), "size": 0.045, "gravity": -0.5, "spread": 60.0},
	"surge": {"count": 5, "life": 0.5, "speed": Vector2(1.0, 3.0), "size": 0.04, "gravity": -2.0, "spread": 120.0},
	"mark": {"count": 2, "life": 1.0, "speed": Vector2(0.3, 0.8), "size": 0.045, "gravity": -0.4, "spread": 180.0},
	"pickup": {"count": 8, "life": 0.9, "speed": Vector2(0.4, 1.4), "size": 0.045, "gravity": -1.0, "spread": 50.0},
	"level": {"count": 60, "life": 1.8, "speed": Vector2(1.0, 4.5), "size": 0.06, "gravity": -1.5, "spread": 25.0},
	"reach": {"count": 5, "life": 1.2, "speed": Vector2(0.6, 1.8), "size": 0.05, "gravity": 0.7, "spread": 25.0, "damping": 0.6},
	"drip": {"count": 2, "life": 0.6, "speed": Vector2(0.05, 0.3), "size": 0.025, "gravity": 9.0, "spread": 10.0},
	"dust": {"count": 14, "life": 0.9, "speed": Vector2(0.6, 2.2), "size": 0.28, "gravity": -0.3, "spread": 160.0, "damping": 1.6},
	"steam": {"count": 8, "life": 1.4, "speed": Vector2(0.3, 0.9), "size": 0.22, "gravity": -0.6, "spread": 40.0},
}

## The colours each preset is thrown in (what NightWarm replays); arena colours come from the arena palettes.
const GOLD := Color(1.9, 1.35, 0.55)
const SCHOOLS := [Color(1.1, 0.55, 2.0), Color(2.2, 0.85, 0.22), Color(1.2, 1.6, 2.2), Color(1.9, 1.6, 1.1)]
const SKILLS := [Color(2.4, 0.9, 0.25), Color(1.3, 1.7, 2.4), Color(1.4, 0.6, 2.6)]
const FIXED := {
	"crit": [GOLD], "hurt": [Color(2.2, 0.45, 0.4)], "kindle": [Color(2.2, 1.0, 0.3)], "mote": [Color(0.5, 0.9, 1.6)],
	"found": [Color(0.5, 0.9, 1.7)], "snap": [Color(1.6, 1.9, 2.4)], "fizzle": [Color(2.0, 0.4, 0.3)],
	"scar": [Color(2.6, 0.9, 0.3)], "shard": [Color(1.1, 0.7, 1.6)], "shaken": [Color(1.6, 0.4, 0.35)], "reson": [Color(1.2, 0.6, 2.6)],
	"surge": [Color(2.4, 1.6, 0.8)], "mark": [Color(1.4, 0.6, 3.0)], "pickup": [Color(2.2, 1.7, 0.7)], "level": [Color(2.4, 1.8, 0.7)],
	"reach": [Color(2.0, 0.9, 0.3)], "drip": [Color(0.7, 0.82, 1.0, 0.8)], "steam": [Color(0.8, 0.82, 0.88, 0.45)], "dust": [Color(0.4, 0.36, 0.32, 0.55)],
}


## Throw preset `id` at `at` in `colour`; `dir` (ZERO: the preset's own) turns the emitter; `ratio` (0..1) is the share of its count to emit.
static func burst(at: Vector3, colour: Color, id: String, dir := Vector3.ZERO, ratio := 1.0) -> void:
	var o: Dictionary = PRESETS[id]
	if dir != Vector3.ZERO or ratio < 0.999:
		o = o.duplicate()
		if dir != Vector3.ZERO:
			o["dir"] = dir
		if ratio < 0.999:
			o["ratio"] = clampf(ratio, 0.05, 1.0)
	Vfx.burst(at, colour, o)


## Every (id, colour) pair the night throws, for the warm-up (arena palette colours included).
static func warm_list(arena_palettes: Dictionary) -> Array:
	var out: Array = []
	for id: String in FIXED:
		for c: Color in FIXED[id]:
			out.append([id, c])
	for c: Color in SCHOOLS:
		out.append(["kill", c])
	for c: Color in SKILLS:
		out.append(["cast_done", c])
	for key: String in arena_palettes:
		for row: Array in arena_palettes[key]:
			var lc: Color = row[2]
			out.append(["arena_mark", Color(lc.r * 2.2, lc.g * 2.2, lc.b * 2.2)])
			var sig := Color(lc.r * 2.0, lc.g * 2.0, lc.b * 2.0)               # the boss's own gesture at a phase change (arena_light.gd _mark)
			out.append(["kindle" if (key == "thorn" or key == "crown") else ("mote" if key != "warden" else "dust"), sig])
	return out
