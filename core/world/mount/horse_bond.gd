extends RefCounted
## A horse you have ridden is a horse that knows you. Each breed you own gets a name when bought (kept in the save) and a
## bond that grows with the metres ridden: Strange (0), Known (2 km), Trusted (6 km), Bonded (15 km). Each level is 4% more
## speed at every gait and a short saying from the horse's own side of it when it comes. The bond is per breed, saved in
## Travel.system_state("stable")["bond"] (metres) and ["names"]. Pure and static; the Horse node feeds it.
## Load by path (no class_name): const HorseBond := preload("res://core/world/mount/horse_bond.gd")

const LEVELS := [0.0, 2000.0, 6000.0, 15000.0]
const TITLES := ["Strange", "Known", "Trusted", "Bonded"]
const NAMES := ["Brindle", "Ember", "Hob", "Tansy", "Rook", "Nettle", "Cinder", "Moss", "Pilgrim", "Dapple", "Wick", "Marrow", "Sorrel", "Bracken", "Lark", "Soot"]
const SAYINGS := [
	"",
	"%s knows your step now and lifts her head when you whistle.",
	"%s answers the whistle from further off, and stops where you stop.",
	"%s would carry you to the summit's foot and stand there. You are bonded.",
]


static func _st() -> Dictionary:
	var st := Travel.system_state("stable")
	if not (st.get("bond") is Dictionary):
		st["bond"] = {}
	if not (st.get("names") is Dictionary):
		st["names"] = {}
	return st


static func metres(breed: String) -> float:
	return float((_st().bond as Dictionary).get(breed, 0.0))


static func level(breed: String) -> int:
	var m := metres(breed)
	var l := 0
	for i in LEVELS.size():
		if m >= float(LEVELS[i]):
			l = i
	return l


static func title(breed: String) -> String:
	return String(TITLES[level(breed)])


static func mult(breed: String) -> float:
	return 1.0 + 0.04 * float(level(breed))


## The horse's own name: chosen (stably) the first time it is asked for and kept.
static func name_of(breed: String) -> String:
	var names: Dictionary = _st().names
	if not names.has(breed):
		var used := names.values()
		var h := absi(hash("horse#" + breed + str(Travel.bosses_slain.size())))
		var pick := String(NAMES[h % NAMES.size()])
		var tries := 0
		while pick in used and tries < NAMES.size():
			h += 1
			pick = String(NAMES[h % NAMES.size()])
			tries += 1
		names[breed] = pick
	return String(names[breed])


## Add metres ridden; returns the new level when one was crossed, else -1.
static func add(breed: String, m: float) -> int:
	var b: Dictionary = _st().bond
	var before := level(breed)
	b[breed] = metres(breed) + m
	var after := level(breed)
	return after if after > before else -1


static func saying(breed: String) -> String:
	var l := level(breed)
	return String(SAYINGS[l]) % name_of(breed) if l > 0 else ""
