extends RefCounted
## The Paths (progression; docs/enshrouded/progression.md): the wanderer's skill tree, bought with
## Remembrances, not ash. Pure and static; preload it.
##
## The wanderer came down from the door half-taken (docs/LORE.md, "Powers"). Walking the valley
## gives some of it back: every kill, kindled fire, broken seal, settled task, homecoming in
## Hearthward and keepsake found is MEMORY. Memory fills Remembrances (levels); each Remembrance,
## and each of the three who hold the valley put down, is one point to spend on a Path.
##
## Three Paths, one column each, read top to bottom. A step needs the one above it on its own Path.
##   HEARTH   the Kindlers' way: hold more Gloom, mend faster at fires, rest longer, eat more
##   RIFT     the sky's splinter in the orb: spell power, recovery, Marks and Lash
##   ROAD     the pilgrim's way: speed, the Step, gleaning ash from the hollowed
## Points are taken back ("Unremember") only at Hearthward's fire, for ash (hearth.gd).
##
## State (Travel.system_state("progression")):
##   memory  int               memory gathered, all time
##   paths   {node id -> 1}    steps taken

const PATHS: Array[Dictionary] = [
	{"id": "hearth", "name": "The Hearth", "glyph": "hearth", "tint": Color(1.0, 0.62, 0.32),
		"text": "The Kindlers' way. Stay by the fire; carry it with you when you cannot."},
	{"id": "rift", "name": "The Rift", "glyph": "bolt", "tint": Color(0.68, 0.54, 1.0),
		"text": "What the door left in the orb. Spend it hard; it does not run out, only you do."},
	{"id": "road", "name": "The Road", "glyph": "step", "tint": Color(0.5, 0.8, 0.95),
		"text": "Pilgrims measured the valley in waystones. You measure it in steps you did not have to take."},
]

## Each node: path, depth (0 = top), cost (points), name, text, lore, fx {mod key -> amount}.
## fx keys are added to UpgradeDB.mods (multipliers *_mult multiply; everything else adds).
const NODES: Array[Dictionary] = [
	# --- the Hearth -------------------------------------------------------------------------
	{"id": "h_hands", "path": "hearth", "depth": 0, "cost": 1, "glyph": "hearth", "name": "Warm Hands",
		"text": "+10 Gloom held.", "fx": {"gloom_add": 10.0},
		"lore": "Edda's first lesson: keep your hands warm and the rest follows."},
	{"id": "h_breath", "path": "hearth", "depth": 1, "cost": 1, "glyph": "coals", "name": "Slow Breath",
		"text": "Gloom gathers 6% slower in the dark and by the Rift.", "fx": {"dark_mult": 0.94},
		"lore": "Breathe as the banked coals do: seldom, and all the way down."},
	{"id": "h_carrier", "path": "hearth", "depth": 2, "cost": 1, "glyph": "lantern", "name": "Coal-Carrier",
		"text": "Fire takes the Gloom off you and mends you 20% faster.", "fx": {"lit_mult": 1.2},
		"lore": "She carried them in her tongs, then in her apron. You carry them closer still."},
	{"id": "h_rest", "path": "hearth", "depth": 3, "cost": 2, "glyph": "candle", "name": "Long Rest",
		"text": "Rested lasts 50% longer.", "fx": {"rest_add": 0.5},
		"lore": "The Keg's beds are lumpy. Sleep in one anyway; the dark will still be there."},
	{"id": "h_appetite", "path": "hearth", "depth": 4, "cost": 2, "glyph": "heart", "name": "Pilgrim's Appetite",
		"text": "Room for a third meal: three of the Keg's or Bet's dishes at once, one of each kind.", "fx": {"belly": 1.0},
		"lore": "Last bread, last bed, last fire before the Stair. Eat the bread twice."},
	{"id": "h_ember", "path": "hearth", "depth": 5, "cost": 1, "glyph": "will", "name": "Ember Heart",
		"text": "A kill beside you, within 28 m, mends 1 Wound.", "fx": {"kill_relief": 1.0},
		"lore": "Ash to ember. Some of what they give back is warmth."},
	{"id": "h_reach", "path": "hearth", "depth": 6, "cost": 2, "glyph": "hearth", "name": "Wide Hearth",
		"text": "Every kindled fire's sanctuary reaches 1.5 m further.", "fx": {"reach_add": 1.5},
		"lore": "A fire you have sat by remembers the shape of you, and makes room."},
	{"id": "h_edda", "path": "hearth", "depth": 7, "cost": 3, "glyph": "ward", "name": "Edda's Hands",
		"text": "+20 Gloom held, and Lantern Ward burns 2 s longer.", "fx": {"gloom_add": 20.0, "ward_life": 2.0},
		"lore": "Burned to the bone, and she did not put the coals down."},
	# --- the Rift ---------------------------------------------------------------------------
	{"id": "r_will", "path": "rift", "depth": 0, "cost": 1, "glyph": "will", "name": "Splinter of Sky",
		"text": "+5% damage from every spell.", "fx": {"power": 0.05},
		"lore": "Something in the orb is the same violet as the vortex. It does not mind being used."},
	{"id": "r_quick", "path": "rift", "depth": 1, "cost": 1, "glyph": "quick", "name": "Quick Hands",
		"text": "Every spell recovers 4% sooner.", "fx": {"cd": -0.04},
		"lore": "The sky turns fast. Turn with it."},
	{"id": "r_marks", "path": "rift", "depth": 2, "cost": 1, "glyph": "tally", "name": "Deep Marks",
		"text": "Umbral Nova deals 0.15 more for every Mark it detonates.", "fx": {"mark_dmg": 0.15},
		"lore": "Count them, as the Abbot did, but only the ones that matter."},
	{"id": "r_lash", "path": "rift", "depth": 3, "cost": 2, "glyph": "bolt", "name": "Heavy Lash",
		"text": "Rift Bolt's Lash hits 15% harder.", "fx": {"lash_power": 0.15},
		"lore": "Every third word the sky says is louder."},
	{"id": "r_charge", "path": "rift", "depth": 4, "cost": 1, "glyph": "lance", "name": "Short Fuse",
		"text": "Ember Lance charges 10% faster.", "fx": {"lance_charge_mult": 0.9},
		"lore": "Dry tinder. You learned to be dry tinder."},
	{"id": "r_ember", "path": "rift", "depth": 5, "cost": 2, "glyph": "lance", "name": "Wide Ember",
		"text": "Ember Lance bursts 0.4 m wider.", "fx": {"lance_blast": 0.4},
		"lore": "Where it lands, it spreads. So did the Night."},
	{"id": "r_power", "path": "rift", "depth": 6, "cost": 2, "glyph": "nova", "name": "Open Hand",
		"text": "+8% damage from every spell.", "fx": {"power": 0.08},
		"lore": "Aurel held the door with one hand. You have two."},
	{"id": "r_door", "path": "rift", "depth": 7, "cost": 3, "glyph": "sigil", "name": "What the Door Kept",
		"text": "Every spell recovers 8% sooner, and +5% damage.", "fx": {"cd": -0.08, "power": 0.05},
		"lore": "It half-took you. You half-took it back."},
	# --- the Road ---------------------------------------------------------------------------
	{"id": "w_feet", "path": "road", "depth": 0, "cost": 1, "glyph": "step", "name": "Light Feet",
		"text": "Walk and run 5% faster.", "fx": {"move_mult": 1.05},
		"lore": "Pilgrims went barefoot so the road would know them. It knows you."},
	{"id": "w_stride", "path": "road", "depth": 1, "cost": 1, "glyph": "step", "name": "Long Stride",
		"text": "Rift Step reaches 1 m further.", "fx": {"step_range": 1.0},
		"lore": "Measure the valley in steps you did not take."},
	{"id": "w_glean", "path": "road", "depth": 2, "cost": 1, "glyph": "mound", "name": "Ash-Gleaner",
		"text": "Every 5th kill leaves a second pinch of grave ash.", "fx": {"glean": 1.0},
		"lore": "Grisel sifts what others sweep away. You learned it from watching her cart."},
	{"id": "w_slip", "path": "road", "depth": 3, "cost": 2, "glyph": "door", "name": "Slip the Hand",
		"text": "Untouchable 0.1 s longer after a Rift Step.", "fx": {"step_evade_add": 0.1},
		"lore": "The door reached for you once. It missed by this much."},
	{"id": "w_weave", "path": "road", "depth": 4, "cost": 1, "glyph": "quick", "name": "Step-Weaver",
		"text": "Rift Step recovers 10% sooner.", "fx": {"step_cd_mult": 0.9},
		"lore": "Through, and back, and through."},
	{"id": "w_hardened", "path": "road", "depth": 5, "cost": 2, "glyph": "waystone", "name": "Road-Hardened",
		"text": "Gloom gathers 8% slower in the dark and by the Rift.", "fx": {"dark_mult": 0.92},
		"lore": "Forty waystones from the West Gate to the Stair. You have walked them in the dark."},
	{"id": "w_spring", "path": "road", "depth": 6, "cost": 1, "glyph": "step", "name": "High Spring",
		"text": "Jump 6% higher; walk and run 4% faster.", "fx": {"jump_mult": 1.0296, "move_mult": 1.04},
		"lore": "The Stair has three thousand steps and some of them are missing."},
	{"id": "w_first", "path": "road", "depth": 7, "cost": 3, "glyph": "waystone", "name": "The Forty-First Stone",
		"text": "Rift Step reaches 1.5 m further and recovers 15% sooner; Gloom gathers 6% slower in the dark and by the Rift.",
		"fx": {"step_range": 1.5, "step_cd_mult": 0.85, "dark_mult": 0.94},
		"lore": "Oswin wanted the forty-first before he went up. You are past it."},
]

## Memory per deed lives in one table: level.gd `XP` (hearth.gd give_memory reads it via LevelDB.xp_for).
const MAX_LEVEL := 30


static func node(id: String) -> Dictionary:
	for n: Dictionary in NODES:
		if n.id == id:
			return n
	return {}


static func path(id: String) -> Dictionary:
	for p: Dictionary in PATHS:
		if p.id == id:
			return p
	return {}


static func on_path(path_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for n: Dictionary in NODES:
		if n.path == path_id:
			out.append(n)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.depth) < int(b.depth))
	return out


## Memory needed to go from Remembrance `lv` to `lv + 1`. 60 + 20 L: the thirty levels cost 10,500 in all, about
## three quarters of what a full night pays (the tally is in docs/DECISIONS.md), so the cap lands in the last third, at the Warden's door.
static func need(lv: int) -> int:
	return 60 + 20 * lv


## {level, into (memory into the current level), need (for the next)} for `memory`.
static func level_of(memory: int) -> Dictionary:
	var lv := 0
	var left := maxi(0, memory)
	while lv < MAX_LEVEL and left >= need(lv):
		left -= need(lv)
		lv += 1
	return {"level": lv, "into": left, "need": need(lv)}


static func taken(st: Dictionary) -> Dictionary:
	var p: Variant = st.get("paths", {})
	return p if p is Dictionary else {}


static func has(st: Dictionary, id: String) -> bool:
	return taken(st).has(id)


static func spent(st: Dictionary) -> int:
	var n := 0
	for id: String in taken(st):
		n += int(node(id).get("cost", 0))
	return n


## Points earned: a Remembrance each, and one for each of the three put down.
static func earned(st: Dictionary, bosses: int) -> int:
	return int(level_of(int(st.get("memory", 0))).level) + bosses


static func free_pts(st: Dictionary, bosses: int) -> int:
	return earned(st, bosses) - spent(st)


## Why node `id` can't be taken ("" = it can). The fire is not needed: a memory comes back anywhere.
static func why_not(st: Dictionary, id: String, bosses: int) -> String:
	var n := node(id)
	if n.is_empty():
		return "?"
	if has(st, id):
		return "Remembered."
	var d := int(n.depth)
	if d > 0:
		for o: Dictionary in on_path(String(n.path)):
			if int(o.depth) == d - 1 and not has(st, String(o.id)):
				return "Remember %s first." % String(o.name)
	var f := free_pts(st, bosses)
	if f < int(n.cost):
		return "Needs %d Path point%s (you have %d to spend)." % [int(n.cost), "" if int(n.cost) == 1 else "s", maxi(f, 0)]
	return ""


## Add every taken node's fx to the mods table `m` (UpgradeDB.mods calls this).
static func apply(m: Dictionary, st: Dictionary) -> void:
	for id: String in taken(st):
		var fx: Dictionary = node(id).get("fx", {})
		for key: String in fx:
			add_fx(m, key, float(fx[key]))
		m["bent"] = true


## One fx entry onto `m`: *_mult and dark_mult/lit_mult multiply, the rest add.
static func add_fx(m: Dictionary, key: String, v: float) -> void:
	if key.ends_with("_mult") and key != "lance_charge_mult" and key != "step_cd_mult":
		m[key] = float(m.get(key, 1.0)) * v
	elif key == "lance_charge_mult":
		m["lance_charge"] = float(m.get("lance_charge", 1.0)) * v
	elif key == "step_cd_mult":
		m["step_cd"] = float(m.get("step_cd", 1.0)) * v
	else:
		m[key] = float(m.get(key, 0.0)) + v
