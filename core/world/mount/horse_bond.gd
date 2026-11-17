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


## Every gait's multiplier: the bond (4% a level), the horse's spirit (92% worn out, 100% fresh), iron shoes (+6%).
static func mult(breed: String) -> float:
	return (1.0 + 0.04 * float(level(breed))) * (0.92 + 0.08 * spirit(breed) / 100.0) * (1.06 if has_tack(breed, "shoes") else 1.0)


# --- care: spirit, feeding, grooming, tack (the stable panel: ui/horse_panel.gd) --------------------

const TACK := {
	"shoes": {"name": "Iron shoes", "cost": {"grave_iron": 6}, "text": "Six percent faster at every gait."},
	"barding": {"name": "Barding", "cost": {"grave_iron": 8, "relic_fragment": 3}, "text": "It tires half as fast, and its warmth closes your Wounds a little while you ride."},
	"lamp": {"name": "Saddle lantern", "cost": {"ember_shard": 5, "grave_iron": 2}, "text": "A small fire at the pommel: the Gloom gathers a third slower while you ride."},
	"bags": {"name": "Larger saddlebags", "cost": {"grave_iron": 4, "ash_bloom": 3}, "text": "The bags hold 60 more."},
	"bags2": {"name": "Deep saddlebags", "cost": {"grave_iron": 6, "relic_fragment": 2}, "text": "The bags hold 120 more again."},
}
const FEED_COST := 1                          ## ash-bloom
const BAG_BASE := 60


static func spirit(breed: String) -> float:
	var sp: Dictionary = _st().get("spirit", {}) if _st().get("spirit") is Dictionary else {}
	return float(sp.get(breed, 60.0))


static func set_spirit(breed: String, v: float) -> void:
	var st := _st()
	if not (st.get("spirit") is Dictionary):
		st["spirit"] = {}
	(st.spirit as Dictionary)[breed] = clampf(v, 0.0, 100.0)


static func has_tack(breed: String, id: String) -> bool:
	var t: Variant = _st().get("tack", {})
	return t is Dictionary and bool(((t as Dictionary).get(breed, {}) as Dictionary).get(id, false))


static func buy_tack(breed: String, id: String) -> void:
	var st := _st()
	if not (st.get("tack") is Dictionary):
		st["tack"] = {}
	var all: Dictionary = st.tack
	if not (all.get(breed) is Dictionary):
		all[breed] = {}
	(all[breed] as Dictionary)[id] = true


## Why tack `id` cannot be bought now ("" = it can).
static func why_not_tack(breed: String, id: String) -> String:
	if has_tack(breed, id):
		return "Already on."
	if id == "bags2" and not has_tack(breed, "bags"):
		return "Needs the larger bags first."
	for item: String in TACK[id].cost:
		if Travel.count(item) < int(TACK[id].cost[item]):
			return "Needs %d %s (you carry %d)." % [int(TACK[id].cost[item]), String(ItemDB.def(item).name), Travel.count(item)]
	return ""


static func pay_tack(breed: String, id: String) -> void:
	for item: String in TACK[id].cost:
		Travel.items[item] = Travel.count(item) - int(TACK[id].cost[item])
	buy_tack(breed, id)
	Travel.save_soon()


## A horse is groomed once a night (the night counter, core/story/days.gd).
static func groomed_tonight(breed: String) -> bool:
	var g: Variant = _st().get("groomed", {})
	return g is Dictionary and int((g as Dictionary).get(breed, -1)) == int(Travel.story.get("night_no", 0))


static func mark_groomed(breed: String) -> void:
	var st := _st()
	if not (st.get("groomed") is Dictionary):
		st["groomed"] = {}
	(st.groomed as Dictionary)[breed] = int(Travel.story.get("night_no", 0))


# --- saddlebags: materials, shared between the post's panel and the road ---------------------------

static func bag(breed: String) -> Dictionary:
	var st := _st()
	if not (st.get("bags") is Dictionary):
		st["bags"] = {}
	var all: Dictionary = st.bags
	if not (all.get(breed) is Dictionary):
		all[breed] = {}
	return all[breed] as Dictionary


static func bag_capacity(breed: String) -> int:
	return BAG_BASE + (60 if has_tack(breed, "bags") else 0) + (120 if has_tack(breed, "bags2") else 0)


static func bag_total(breed: String) -> int:
	var n := 0
	for k: String in bag(breed):
		n += int(bag(breed)[k])
	return n


## Move `n` of `item` into the bag (negative: out). Returns how many moved.
static func move_item(breed: String, item: String, n: int) -> int:
	var b := bag(breed)
	if n > 0:
		n = mini(n, mini(Travel.count(item), bag_capacity(breed) - bag_total(breed)))
		if n <= 0:
			return 0
		Travel.items[item] = Travel.count(item) - n
		b[item] = int(b.get(item, 0)) + n
		return n
	var out := mini(-n, int(b.get(item, 0)))
	if out <= 0:
		return 0
	b[item] = int(b.get(item, 0)) - out
	if int(b[item]) <= 0:
		b.erase(item)
	Travel.items[item] = Travel.count(item) + out
	return -out


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
	b[breed] = metres(breed) + m * (1.5 if spirit(breed) >= 60.0 else 1.0)
	set_spirit(breed, spirit(breed) - m / (300.0 if has_tack(breed, "barding") else 150.0))
	var after := level(breed)
	return after if after > before else -1


static func saying(breed: String) -> String:
	var l := level(breed)
	return String(SAYINGS[l]) % name_of(breed) if l > 0 else ""
