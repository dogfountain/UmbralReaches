extends RefCounted
## Gear (docs/enshrouded/equipment.md): what the wanderer wears beside the charms. Pure data and
## pure functions; the runtime is gear_runtime.gd, the numbers reach play through gear_stats.gd,
## the menu is ui/gear_panel.gd. Load by path (no class_name):
##   const GearDB := preload("res://core/items/gear_db.gd")
##
## Four slots, each fitted to something the wanderer already carries (nothing new is modelled):
##   focus     a fitting bound under the staff's orb          base: spell power
##   vestment  a stole or scapular worn over the coat          base: Gloom held
##   lantern   the horn-glass of the hand lantern              base: Lantern Ward / Umbral Well hold
##   girdle    the cord or belt the satchel hangs from         base: every spell recovers sooner
## A piece is a Dictionary (stored in Travel.system_state("gear").bag):
##   {uid, slot, base, rarity 0..4, level, aff: [[affix id, value], ...], set: "" | set id,
##    legend: "" | legend id, name}
## Rarity sets how many affixes a piece rolls and how far it can be raised at a fire. Sets are
## four named pieces (one per slot): two worn wake the first bonus, four the second. Umbral pieces
## are four uniques, each carrying a legend that turns on a behaviour the spells already know.
## No durability: gear does not wear out (see the doc).

const SLOTS := ["focus", "vestment", "lantern", "girdle"]
const SLOT_NAMES := {"focus": "Orb Focus", "vestment": "Vestment", "lantern": "Lantern Glass", "girdle": "Girdle"}
const SLOT_GLYPH := {"focus": "prism", "vestment": "hollow", "lantern": "lantern", "girdle": "cord"}
const SLOT_WHERE := {
	"focus": "Bound under the staff's orb.",
	"vestment": "Worn over the coat, under the mantle.",
	"lantern": "Set in the hand lantern's drum.",
	"girdle": "Knotted round the waist; the satchel hangs from it.",
}

## [name, colour, affixes, max level, strength]
const RARITY := [
	["Worn", Color("#B4AEBE"), 0, 2, 1.0],
	["Kindled", Color("#F0B45E"), 1, 3, 1.25],
	["Hallowed", Color("#9CCBFF"), 2, 4, 1.5],
	["Reliquary", Color("#C38CFF"), 3, 5, 1.8],
	["Umbral", Color("#FF6E9A"), 3, 6, 2.1],
]

## Base stat per slot: [mod key, at level 0, per level] (scaled by rarity strength).
const BASE := {
	"focus": ["power", 0.03, 0.01],
	"vestment": ["gloom_add", 5.0, 2.0],
	"lantern": ["ward_life", 0.5, 0.2],
	"girdle": ["cd", -0.02, -0.007],
}

## Affixes: mod key, how it combines ("add" or "mul": the value is added to 1.0 and multiplied),
## [min, max] for a Worn roll (scaled by rarity strength, +10% a level), the line, a name suffix.
const AFFIX := {
	"power": {"key": "power", "op": "add", "roll": [0.02, 0.04], "fmt": "+%d%% spell power", "pct": true, "of": "of Fervour"},
	"cd": {"key": "cd", "op": "add", "roll": [-0.03, -0.015], "fmt": "Spells recover %d%% sooner", "pct": true, "of": "of Haste"},
	"gloom_add": {"key": "gloom_add", "op": "add", "roll": [4.0, 8.0], "fmt": "+%d Gloom held", "of": "of the Deep Breath"},
	"dark_mult": {"key": "dark_mult", "op": "mul", "roll": [-0.05, -0.025], "fmt": "Gloom gathers %d%% slower", "pct": true, "of": "of the Shuttered Eye"},
	"lit_mult": {"key": "lit_mult", "op": "mul", "roll": [0.06, 0.12], "fmt": "Fire takes Gloom off %d%% faster, and mends the plate", "pct": true, "of": "of the Hearth"},
	"kill_relief": {"key": "kill_relief", "op": "add", "roll": [0.5, 1.0], "fmt": "Every kill within 28 m mends %.1f Wounds", "of": "of the Reaper"},
	"step_range": {"key": "step_range", "op": "add", "roll": [0.3, 0.6], "fmt": "Rift Step reaches %.1f m further", "of": "of the Long Road"},
	"step_cd": {"key": "step_cd", "op": "mul", "roll": [-0.07, -0.035], "fmt": "Rift Step recovers %d%% sooner", "pct": true, "of": "of Swift Feet"},
	"lash_power": {"key": "lash_power", "op": "add", "roll": [0.06, 0.12], "fmt": "The Lash hits %d%% harder", "pct": true, "of": "of the Lash"},
	"mark_dmg": {"key": "mark_dmg", "op": "add", "roll": [0.05, 0.1], "fmt": "+%.2f damage per Mark detonated", "of": "of the Tally"},
	"lance_charge": {"key": "lance_charge", "op": "mul", "roll": [-0.06, -0.03], "fmt": "Ember Lance charges %d%% faster", "pct": true, "of": "of the Quick Coal"},
	"lance_blast": {"key": "lance_blast", "op": "add", "roll": [0.15, 0.3], "fmt": "Ember Lance bursts %.2f m wider", "of": "of the Wide Flame"},
	"ward_life": {"key": "ward_life", "op": "add", "roll": [0.4, 0.8], "fmt": "Lantern Ward burns %.1f s longer", "of": "of the Long Wick"},
	"well_life": {"key": "well_life", "op": "add", "roll": [0.4, 0.8], "fmt": "Umbral Well holds %.1f s longer", "of": "of the Deep Well"},
	# r36: the learned spells and the Peal get lines of their own
	"shade_life": {"key": "shade_life", "op": "add", "roll": [0.8, 1.6], "fmt": "A Bound Shade stays %.1f s longer", "of": "of the Kept Shade"},
	"tether_reach": {"key": "tether_reach", "op": "add", "roll": [1.0, 2.0], "fmt": "Rift Tether reaches %.1f m further", "of": "of the Long Chain"},
	"peal_reach": {"key": "peal_reach", "op": "add", "roll": [0.5, 1.0], "fmt": "The Founder's Peal carries %.1f m further", "of": "of the Carrying Note"},
	"ash_find": {"key": "ash_find", "op": "add", "roll": [0.04, 0.08], "fmt": "About %d kills in a hundred leave one more pinch of grave ash (a kill beside you, within 28 m; a great one does not pay)", "pct": true, "of": "of the Gleaner"},
}
## Which affixes each slot can roll: every slot leans toward a way of fighting.
const SLOT_AFFIX := {
	"focus": ["power", "lash_power", "mark_dmg", "lance_charge", "lance_blast", "peal_reach"],
	"vestment": ["gloom_add", "dark_mult", "lit_mult", "kill_relief", "power", "ash_find"],
	"lantern": ["ward_life", "well_life", "lit_mult", "kill_relief", "mark_dmg", "shade_life"],
	"girdle": ["cd", "step_range", "step_cd", "kill_relief", "lash_power", "tether_reach"],
}

## Plain pieces: the base name by slot, the better ones further down (picked by rarity).
const BASES := {
	"focus": ["Ash-wood Orb-Cup", "Bronze Orb-Cradle", "Bell-metal Collar", "Saint's-bone Collar", "Starless Orb-Cage"],
	"vestment": ["Pilgrim's Stole", "Mended Scapular", "Choir Stole", "Reliquary Pall", "Rift-hem Stole"],
	"lantern": ["Smoked Horn-Glass", "Leaded Lamp-Glass", "Chapel Lamp-Glass", "Vigil Glass", "Glass of the Last Lamp"],
	"girdle": ["Hempen Cord", "Pilgrim's Belt", "Knotted Cincture", "Penitent's Girdle", "Girdle of Nine Knots"],
}

## Sets: four named pieces; 2 and 4 worn wake their bonuses. "mods" add / multiply like affixes
## ([key, op, value]); "flags" switch on behaviours the spells already have (upgrade_db.gd mods).
const SETS := {
	"kindler": {"name": "Kindler's Regalia", "tint": Color("#FF8A4A"),
		"pieces": {"focus": "Kindler's Coal-Cup", "vestment": "Kindler's Soot Stole", "lantern": "Kindler's Hearth-Glass", "girdle": "Kindler's Bellows-Cord"},
		"lore": "The Kindlers swept the chapel at dawn in these, and fed the First Hearth what they swept.",
		"two": {"text": "Ember Lance charges 10% faster.", "mods": [["lance_charge", "mul", -0.1]]},
		"four": {"text": "Ember Lance bursts 0.6 m wider, and a burning foe takes a Mark for every second it burns (as the Ember Rosary).",
			"mods": [["lance_blast", "add", 0.6]], "flags": ["rosary"]}},
	"ferryman": {"name": "Ferryman's Weeds", "tint": Color("#5FE3D0"),
		"pieces": {"focus": "Ferryman's Hook-Ring", "vestment": "Ferryman's Fen-Cloak", "lantern": "Ferryman's Bow-Lamp Glass", "girdle": "Ferryman's Tow-Rope"},
		"lore": "Fen clothes, oiled against the water and the dead in it. The ferrymen never lost a passenger. Some came back to argue.",
		"two": {"text": "+0.15 damage for every Mark detonated.", "mods": [["mark_dmg", "add", 0.15]]},
		"four": {"text": "Rift Tether Marks everything along its chain and recovers 2 s sooner, and the hook and a Bound Shade's darts lay 2 Marks, not 1.",
			"flags": ["hook", "chalk"]}},
	"tally": {"name": "Lay Brother's Tally", "tint": Color("#E8DCC0"),
		"pieces": {"focus": "Tally-Bead Collar", "vestment": "Lay Brother's Scapular", "lantern": "Charnel Lamp-Horn", "girdle": "Counted Cincture"},
		"lore": "Brother Lisle's order counted the dead into the Ossuary. They wore their count on everything.",
		"two": {"text": "+15 Gloom held.", "mods": [["gloom_add", "add", 15.0]]},
		"four": {"text": "Umbral Nova deals 1.5 damage for every Mark it detonates (as the Oath of the Tally), and every kill within 28 m mends 2 Wounds.",
			"mods": [["kill_relief", "add", 2.0]], "flags": ["tally"]}},
	"bell": {"name": "Bellwright's Garb", "tint": Color("#D79A52"),
		"pieces": {"focus": "Clapper-Ring", "vestment": "Bellwright's Apron", "lantern": "Belfry Lamp-Glass", "girdle": "Bell-Rope Girdle"},
		"lore": "The bellwrights cast the Last Bell and the twelve below it. Their leathers still ring when struck.",
		"two": {"text": "The Lash hits 20% harder.", "mods": [["lash_power", "add", 0.2]]},
		"four": {"text": "Rift Bolt's Lash comes every 2nd bolt in a chain (as the Oath of the Lash), and spells recover 5% sooner.",
			"mods": [["cd", "add", -0.05], ["lash_every", "set", 2]]}},
}
const SET_ORDER := ["kindler", "ferryman", "tally", "bell"]

## Umbral uniques: one per slot. A legend switches on a behaviour (upgrade_db.gd mods flags).
const LEGENDS := {
	"door_splinter": {"slot": "focus", "name": "Splinter of the Door", "flags": ["door"],
		"text": "Legend: Rift Step recovers twice as fast, and every step mends 3 Wounds.",
		"lore": "A sliver of the door in the sky, prised off the frame. It still wants to open."},
	"sunk_shroud": {"slot": "vestment", "name": "Shroud of the Sunk", "flags": ["bramble"],
		"text": "Legend: Lantern Ward roots what crosses its light in brambles: slowed hard, and Marked once.",
		"lore": "Winding-cloth from the fen graves. Roots grew through it before you pulled it free."},
	"unlit_lamp": {"slot": "lantern", "name": "Glass of the Unlit Lamp", "flags": ["jar"],
		"text": "Legend: a Bound Shade stays 6 s longer, and its darts burst on a Marked foe.",
		"lore": "A lamp-glass that was never lit. Something lives in it instead of a flame."},
	"stair_rope": {"slot": "girdle", "name": "Rope of the Stair", "flags": ["ferrule", "step_briar"],
		"text": "Legend: every foe within 2 m of where Rift Step lands takes a Mark, and the step slows what it passes (within about a metre and a half of the line) to a little under half speed for 2 s.",
		"lore": "The pilgrims roped themselves together on the Stair. This length was cut."},
}
const LEGEND_ORDER := ["door_splinter", "sunk_shroud", "unlit_lamp", "stair_rope"]

## r36 traits: one line on a Hallowed piece (half the time) or better (always) that changes how you
## play, not a number. Most switch on a behaviour the spells already have (the legends' and sets'
## flags); kill_spark, ash_hunger and peal_echo are new (kindling.gd _on_killed, skill_peal.gd).
const TRAITS := {
	"rosary": {"flags": ["rosary"], "slots": ["focus", "lantern"], "text": "Trait: a burning foe takes a Mark for every second it burns."},
	"hook": {"flags": ["hook"], "slots": ["focus", "girdle"], "text": "Trait: Rift Tether Marks everything along its chain and recovers 2 s sooner."},
	"chalk": {"flags": ["chalk"], "slots": ["focus", "lantern"], "text": "Trait: the Tether's hook and a Shade's darts lay 2 Marks."},
	"ferrule": {"flags": ["ferrule"], "slots": ["girdle"], "text": "Trait: every foe within 2 m of where Rift Step lands takes a Mark."},
	"step_briar": {"flags": ["step_briar"], "slots": ["girdle", "vestment"], "text": "Trait: Rift Step slows what it passes to a little under half speed for 2 s, within about a metre and a half of the line."},
	"bramble": {"flags": ["bramble"], "slots": ["vestment", "lantern"], "text": "Trait: Lantern Ward roots what crosses its light in brambles."},
	"kill_spark": {"flags": ["kill_spark"], "slots": ["vestment", "girdle"], "text": "Trait: a kill beside you, within 28 m, takes 1 s off every spell's recovery, one time in four; a great one does not pay."},
	"ash_hunger": {"flags": ["ash_hunger"], "slots": ["vestment", "lantern"], "text": "Trait: every kill beside you, within 28 m, gives one more pinch of grave ash; a great one does not pay."},
	"peal_echo": {"flags": ["peal_echo"], "slots": ["focus"], "text": "Trait: the Founder's Peal rings twice, the second at half strength."},
}


## r36: a trait for a fresh piece of `rarity` in `slot` ("" when it rolls none).
static func roll_trait(rng: RandomNumberGenerator, slot: String, rarity: int) -> String:
	if rarity < 2 or (rarity == 2 and rng.randf() >= 0.5):
		return ""
	var pool: Array = []
	for t: String in TRAITS:
		if t == "kill_spark" and not Slice.full():     # 1 s off recovery, one kill in four: invisible, cut from the slice
			continue
		if (TRAITS[t].slots as Array).has(slot):
			pool.append(t)
	return String(pool[rng.randi_range(0, pool.size() - 1)]) if not pool.is_empty() else ""


static func trait_line(p: Dictionary) -> String:
	var t := String(p.get("trait", ""))
	return String(TRAITS[t].text) if TRAITS.has(t) else ""

const BAG_CAP := 30
## Salvage: ember shards back for a piece (by rarity), plus its level.
const SALVAGE := [1, 2, 4, 7, 12]


static func rarity_name(r: int) -> String:
	return String(RARITY[clampi(r, 0, 4)][0])


static func rarity_color(r: int) -> Color:
	return RARITY[clampi(r, 0, 4)][1]


static func max_level(piece: Dictionary) -> int:
	return int(RARITY[clampi(int(piece.get("rarity", 0)), 0, 4)][3])


static func strength(piece: Dictionary) -> float:
	return float(RARITY[clampi(int(piece.get("rarity", 0)), 0, 4)][4])


## A fresh piece. `opts`: slot (else random), rarity (else 0), set (a set id: that set's piece for
## the slot), legend (a legend id: forces its slot and Umbral), uid.
static func make(rng: RandomNumberGenerator, opts := {}) -> Dictionary:
	var legend := String(opts.get("legend", ""))
	var slot := String(opts.get("slot", ""))
	if legend != "" and LEGENDS.has(legend):
		slot = String(LEGENDS[legend].slot)
	if not SLOTS.has(slot):
		slot = String(SLOTS[rng.randi_range(0, SLOTS.size() - 1)])
	var rarity := clampi(int(opts.get("rarity", 0)), 0, 4)
	if legend != "":
		rarity = 4
	var set_id := String(opts.get("set", ""))
	if not SETS.has(set_id):
		set_id = ""
	var p := {"uid": int(opts.get("uid", 0)), "slot": slot, "rarity": rarity, "level": 0, "aff": [], "set": set_id, "legend": legend}
	var bases: Array = BASES[slot]
	p["base"] = String(bases[mini(rarity, bases.size() - 1)])
	# r33 loot: a named piece (a boss's or a rare's table, NAMED) has a fixed slot, rarity and lines
	var named := String(opts.get("named", ""))
	if named != "" and NAMED.has(named) and legend == "":
		var nd: Dictionary = NAMED[named]
		p["slot"] = String(nd.slot)
		p["rarity"] = int(nd.rarity)
		p["named"] = named
		p["set"] = ""
		p["base"] = String((BASES[String(nd.slot)] as Array)[mini(int(nd.rarity), 4)])
		for a: String in nd.aff:
			(p.aff as Array).append([a, roll_value(rng, a)])
		p["name"] = name_of(p)
		return p
	var n := int(RARITY[rarity][2]) - (1 if legend != "" else 0)
	var pool: Array = (SLOT_AFFIX[slot] as Array).duplicate()
	for i in n:
		if pool.is_empty():
			break
		var a := String(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
		(p.aff as Array).append([a, roll_value(rng, a)])
	if legend == "":
		var tr := roll_trait(rng, slot, rarity)
		if tr != "":
			p["trait"] = tr
	p["name"] = name_of(p)
	return p


## A Worn-strength roll for affix `a` (rarity and level scale it when read: affix_value).
static func roll_value(rng: RandomNumberGenerator, a: String) -> float:
	var r: Array = AFFIX[a].roll
	return snappedf(lerpf(float(r[0]), float(r[1]), rng.randf()), 0.001)


static func name_of(p: Dictionary) -> String:
	var nm0 := String(p.get("named", ""))
	if nm0 != "" and NAMED.has(nm0):
		return String(NAMED[nm0].name)
	var lg := String(p.get("legend", ""))
	if lg != "" and LEGENDS.has(lg):
		return String(LEGENDS[lg].name)
	var st := String(p.get("set", ""))
	if st != "" and SETS.has(st):
		return String(SETS[st].pieces[String(p.slot)])
	var nm := String(p.get("base", SLOT_NAMES.get(String(p.get("slot", "")), "Gear")))
	var aff: Array = p.get("aff", [])
	if not aff.is_empty():
		nm += " " + String(AFFIX[String(aff[0][0])].of)
	return nm


## What one affix of `p` gives now: its roll scaled by rarity and +10% a level.
static func affix_value(p: Dictionary, roll: float) -> float:
	return roll * strength(p) * (1.0 + 0.1 * float(p.get("level", 0)))


## The slot's base stat for `p`: [mod key, value].
static func base_value(p: Dictionary) -> Array:
	var b: Array = BASE[String(p.slot)]
	return [String(b[0]), (float(b[1]) + float(b[2]) * float(p.get("level", 0))) * strength(p)]


static func base_line(p: Dictionary) -> String:
	var bv := base_value(p)
	match String(bv[0]):
		"power":
			return "+%d%% spell power" % roundi(float(bv[1]) * 100.0)
		"gloom_add":
			return "+%d Gloom held" % roundi(float(bv[1]))
		"ward_life":
			return "Lantern Ward and Umbral Well hold %.1f s longer" % float(bv[1])
		"cd":
			return "Spells recover %d%% sooner" % roundi(-float(bv[1]) * 100.0)
	return ""


static func affix_line(p: Dictionary, a: Array) -> String:
	var d: Dictionary = AFFIX.get(String(a[0]), {})
	if d.is_empty():
		return ""
	var v := affix_value(p, float(a[1]))
	if bool(d.get("pct", false)):
		return String(d.fmt) % roundi(absf(v) * 100.0)
	if String(d.fmt).contains("%d"):
		return String(d.fmt) % roundi(v)
	return String(d.fmt) % v


## How good an affix roll is inside its range, as a tier 1..TIERS (TIERS is the best). `a` is the
## [affix id, roll] pair stored on the piece; the roll is read against the affix's Worn range.
const TIERS := 5


static func affix_tier(a: Array) -> int:
	var d: Dictionary = AFFIX.get(String(a[0]), {})
	if d.is_empty():
		return 1
	var r: Array = d.roll
	var span := float(r[1]) - float(r[0])
	if is_zero_approx(span):
		return TIERS
	var f := clampf((float(a[1]) - float(r[0])) / span, 0.0, 1.0)
	return clampi(int(f * float(TIERS)) + 1, 1, TIERS)


## What a reforge of line `idx` can become: the slot's affixes this piece does not already hold
## on another line (the same list gear_runtime.gd reforge() draws from), by their name suffix.
static func reforge_pool(p: Dictionary, idx: int) -> PackedStringArray:
	var out := PackedStringArray()
	var aff: Array = p.get("aff", [])
	for a: String in SLOT_AFFIX.get(String(p.get("slot", "")), []):
		var held := false
		for i in aff.size():
			if i != idx and String(aff[i][0]) == a:
				held = true
		if not held:
			out.append(String(AFFIX[a].of))
	return out


## Cost to raise `p` one level: {ash, shards}, or {} at its cap.
static func upgrade_cost(p: Dictionary) -> Dictionary:
	var lv := int(p.get("level", 0))
	if lv >= max_level(p):
		return {}
	var r := int(p.get("rarity", 0))
	return {"ash": 4 + 4 * (lv + 1) + 3 * r, "shards": (lv + 1) * (1 + r)}


## Cost to reroll one affix: {shards, frag}. Worn pieces have nothing to reroll.
static func reforge_cost(p: Dictionary) -> Dictionary:
	if (p.get("aff", []) as Array).is_empty():
		return {}
	var r := int(p.get("rarity", 0))
	return {"shards": 3 * (1 + r), "frag": 1 if r >= 2 else 0}


static func salvage_value(p: Dictionary) -> int:
	return int(SALVAGE[clampi(int(p.get("rarity", 0)), 0, 4)]) + int(p.get("level", 0))


## A drop's rarity for a source: "kill" (a common foe), "tough" (a variant / tier foe), "elite",
## "umbral" (a Deeper Night elite), "reliquary" (a reliquary chest), "boss". A roll in [0,1) picks it.
static func drop_rarity(source: String, roll: float) -> int:
	var w: Array
	match source:
		"boss":
			w = [0.0, 0.0, 0.55, 0.35, 0.10]
		"umbral":
			w = [0.0, 0.1, 0.35, 0.4, 0.15]
		"reliquary":
			w = [0.0, 0.15, 0.4, 0.3, 0.15]       # a reliquary chest: Umbral at a Deeper Night elite's odds
		"elite":
			w = [0.0, 0.45, 0.4, 0.13, 0.02]
		"tough":
			w = [0.45, 0.4, 0.13, 0.02, 0.0]
		_:
			w = [0.7, 0.25, 0.05, 0.0, 0.0]
	var acc := 0.0
	for i in w.size():
		acc += float(w[i])
		if roll < acc:
			return i
	return 0


## Chance a foe drops anything at all (before the pity that builds between drops).
static func drop_chance(source: String) -> float:
	match source:
		"boss", "umbral", "elite", "reliquary":
			return 1.0
		"tough":
			return 0.08
	return 0.025



# --- r33 loot: item level, flavour, named pieces ----------------------------------------------------
# (WoW's item level and flavour text, adapted: one number that says how strong a piece is, and a
# line of gold italic lore on every tooltip. Old saves: every key read here has a default.)

## Item level: how strong a piece is at a glance (rarity, how far it was raised, set / named /
## legend). It is what the tooltips compare; it changes nothing by itself.
static func item_level(p: Dictionary) -> int:
	var r := clampi(int(p.get("rarity", 0)), 0, 4)
	var il := 8 + 7 * r + 3 * int(p.get("level", 0))
	if String(p.get("set", "")) != "":
		il += 3
	if String(p.get("named", "")) != "":
		il += 4
	if String(p.get("legend", "")) != "":
		il += 6
	return il


## Plain pieces' flavour, by slot and base (BASES index = rarity).
const FLAVOUR := {
	"focus": ["Turned from a branch the Kindlers burned for warmth, and kept for the shape.", "Cast in a bell-mould, from what was left after the bell.",
		"It hums when the orb is full. It hums louder when it is not.", "The saint is not named. The bone is.", "Nothing shines through it. Everything shines out."],
	"vestment": ["Every pilgrim had one. Most were buried in it.", "Patched with three other people's prayers.",
		"The choir sang in these until there was no choir.", "It covered a reliquary once. Now it covers you, which is the same thing.", "The hem is wet with something that is not water, and never dries."],
	"lantern": ["Horn shaved thin enough to read through. Nobody reads any more.", "Lead lines it like a church window, small.",
		"A chapel lamp sees a great deal and says nothing.", "Kept lit for a vigil nobody finished.", "The last lamp on the Stair. The pilgrims climbed toward it."],
	"girdle": ["Hemp, knotted once for every mile.", "The buckle is a pilgrim's token, worn flat.",
		"Three knots: poverty, obedience, and the one nobody will name.", "Penance, pulled tight.", "Nine knots. Undo one and something else comes undone."],
}


static func flavour(p: Dictionary) -> String:
	var nm := String(p.get("named", ""))
	if nm != "" and NAMED.has(nm):
		return String(NAMED[nm].lore)
	var lg := String(p.get("legend", ""))
	if LEGENDS.has(lg):
		return String(LEGENDS[lg].lore)
	var st := String(p.get("set", ""))
	if SETS.has(st):
		return String(SETS[st].lore)
	var arr: Array = FLAVOUR.get(String(p.get("slot", "")), [])
	if arr.is_empty():
		return ""
	return String(arr[clampi(int(p.get("rarity", 0)), 0, arr.size() - 1)])


## Named pieces: fixed slot, rarity and affix lines (the rolls still vary). Bosses carry three each
## (LootDB.BOSS_TABLE); rares share a pool (LootDB.RARE_TABLE).
const NAMED := {
	# the Thornwarden (Thorn Henge)
	"heartwood_cup": {"name": "Heartwood Orb-Cup", "slot": "focus", "rarity": 3, "aff": ["lash_power", "power", "mark_dmg"],
		"lore": "Cut from the oak the thorn grew through. The rings count backward."},
	"henge_mantle": {"name": "Henge-Moss Mantle", "slot": "vestment", "rarity": 3, "aff": ["dark_mult", "gloom_add", "kill_relief"],
		"lore": "Moss off the standing stones. It still faces north when you lay it down."},
	"briarwick_glass": {"name": "Briarwick Glass", "slot": "lantern", "rarity": 3, "aff": ["ward_life", "kill_relief", "lit_mult"],
		"lore": "A briar grew round this glass and drank the light. You cut it free. It is still thirsty."},
	# the Bone Abbot (the Ossuary)
	"counting_cord": {"name": "Osric's Counting-Cord", "slot": "girdle", "rarity": 3, "aff": ["cd", "kill_relief", "step_cd"],
		"lore": "One knot for every brother. The Abbot ran out of cord before he ran out of brothers."},
	"charnel_glass": {"name": "Charnel Censer-Glass", "slot": "lantern", "rarity": 3, "aff": ["well_life", "mark_dmg", "ward_life"],
		"lore": "The light through it is the colour of old teeth."},
	"bone_collar": {"name": "Abbot's Knuckle-Collar", "slot": "focus", "rarity": 3, "aff": ["mark_dmg", "power", "lance_blast"],
		"lore": "He wore the first brothers at his throat, so that they would hear him pray."},
	# the Ascended Warden (the summit)
	"edict_stole": {"name": "Stole of the Third Edict", "slot": "vestment", "rarity": 3, "aff": ["gloom_add", "lit_mult", "power"],
		"lore": "Hierarch Aurel's edicts are stitched into the lining. The third is unpicked."},
	"latch_cord": {"name": "Latchkeeper's Cord", "slot": "girdle", "rarity": 3, "aff": ["step_range", "step_cd", "cd"],
		"lore": "It tied the latch to his wrist. His wrist is gone. The knot held."},
	"sky_cage": {"name": "Orb-Cage of the Turning Sky", "slot": "focus", "rarity": 3, "aff": ["power", "lance_charge", "lash_power"],
		"lore": "Set the orb in it and the light turns inward, as the sky did."},
	# rares: the night's named wanderers (any rare's first fall)
	"digger_glass": {"name": "Gravedigger's Lamp-Glass", "slot": "lantern", "rarity": 2, "aff": ["ward_life", "lit_mult"],
		"lore": "Soot on the inside. Earth on the outside. A thumbprint in both."},
	"bone_cincture": {"name": "Pilgrim-Bone Cincture", "slot": "girdle", "rarity": 2, "aff": ["step_range", "kill_relief"],
		"lore": "Finger bones strung like beads. The pilgrims gave them freely. Mostly."},
	"mirewick_stole": {"name": "Mire-Wick Stole", "slot": "vestment", "rarity": 2, "aff": ["dark_mult", "gloom_add"],
		"lore": "Woven from fen-rush and lamp-wick. It smoulders a little when the Gloom is close."},
	"corpse_cradle": {"name": "Corpse-Candle Cradle", "slot": "focus", "rarity": 2, "aff": ["lance_charge", "power"],
		"lore": "The fen lights that lead walkers astray sat in this, once, and were carried home."},
	"tollmans_ring": {"name": "Tollman's Iron Cup", "slot": "focus", "rarity": 3, "aff": ["power", "mark_dmg", "lash_power"],
		"lore": "Every soul on the Stair paid the toll. He kept one coin from each, and melted them."},
	"widow_veil": {"name": "Widow's Ash-Veil", "slot": "vestment", "rarity": 3, "aff": ["gloom_add", "kill_relief", "lit_mult"],
		"lore": "She wore it at every burial in the valley. Then nobody was left to bury her."},
	# --- the east marches: the Anchoress (the Anchorholds)
	"anchor_chain": {"name": "Anchor-Chain Girdle", "slot": "girdle", "rarity": 3, "aff": ["cd", "kill_relief", "step_cd"],
		"lore": "Nine winters of her weight on it. It still hangs a little to the left."},
	"cell_lantern": {"name": "Cell-Door Lantern", "slot": "lantern", "rarity": 3, "aff": ["ward_life", "well_life", "lit_mult"],
		"lore": "Lit once a day through a slot in a wall, to show a hermit her own hands."},
	"hermit_shawl": {"name": "Hermit's Salt-Shawl", "slot": "vestment", "rarity": 3, "aff": ["dark_mult", "gloom_add", "ward_life"],
		"lore": "Grey wool, stiff with sea-breath from nowhere near the sea. It keeps the cold out and the prayers in."},
	# --- the Fallen Hierarch (the Speaking Crown's skull)
	"horn_collar": {"name": "Speaking-Horn Collar", "slot": "focus", "rarity": 3, "aff": ["peal_reach", "power", "lance_blast"],
		"lore": "Cut from the lip of the great horn. Hold it to the orb and the orb says, very quietly, what it was told to say."},
	"cantor_hush": {"name": "Cantor's Hush-Stole", "slot": "vestment", "rarity": 3, "aff": ["dark_mult", "gloom_add", "ash_find"],
		"lore": "The boy in the skull wore it to hold the note. It is stitched shut at the throat, and has never come undone."},
	"held_note": {"name": "Lamp of the Held Note", "slot": "lantern", "rarity": 3, "aff": ["shade_life", "ward_life", "kill_relief"],
		"lore": "A lamp that burns only while something is being held. It was never going to be put down."},
	# --- rares of the Marches (LootDB.RARE_OWN: the piece each gives on its first fall)
	"reeve_tally": {"name": "Reeve's Toll-Stick Cup", "slot": "focus", "rarity": 2, "aff": ["mark_dmg", "lash_power"],
		"lore": "Notched for every toll he took, and nobody owed. The notches are still wet."},
	"mason_girdle": {"name": "Moss-Mason's Plumb-Cord", "slot": "girdle", "rarity": 2, "aff": ["cd", "step_range"],
		"lore": "A plumb-line, green to the bob. Whatever hangs from it is straight, and does not care for you."},
	"breaker_cinch": {"name": "Gate-Breaker's Cinch", "slot": "girdle", "rarity": 2, "aff": ["lash_power", "kill_relief"],
		"lore": "Off a harness that bore a ram. The leather remembers the weight."},
	"widow_salt": {"name": "Salt-Widow's Brine-Glass", "slot": "lantern", "rarity": 3, "aff": ["well_life", "lit_mult", "ward_life"],
		"lore": "Crusted white inside. Whatever light you put in it comes out tasting of tears."},
	"lamplighter_wick": {"name": "Lamplighter's Last Wick", "slot": "lantern", "rarity": 3, "aff": ["ward_life", "lit_mult", "shade_life"],
		"lore": "Trimmed by a hand that is not there. It never gutters. It does not like to be watched."},
	# --- the shared rare pool, widened: more first falls give something new
	"shepherd_crook": {"name": "Shepherd's Crook-Ring", "slot": "focus", "rarity": 2, "aff": ["lance_charge", "peal_reach"],
		"lore": "Bent to hook a lamb out of a ditch. It hooks other things now."},
	"ringer_gloves": {"name": "Ringer's Rope-Wraps", "slot": "girdle", "rarity": 2, "aff": ["tether_reach", "cd"],
		"lore": "Wound twice round the wrist, for a bell that was rung one hour too long."},
	"slag_cowl": {"name": "Slag-Crust Scapular", "slot": "vestment", "rarity": 2, "aff": ["lit_mult", "gloom_add"],
		"lore": "Cooled on the shoulders of something that never stopped pouring."},
	"fog_lantern": {"name": "Fog-Shepherd's Horn-Glass", "slot": "lantern", "rarity": 2, "aff": ["shade_life", "ward_life"],
		"lore": "It shows you the shape in the fog, and how far it is, and which way it is walking."},
	"cinder_scapular": {"name": "Cinder-Sower's Scapular", "slot": "vestment", "rarity": 2, "aff": ["ash_find", "dark_mult"],
		"lore": "Seed-pockets sewn in the lining, every one full of ash and one of something that is not."},
	"pilgrim_orb": {"name": "Last Pilgrim's Orb-Cup", "slot": "focus", "rarity": 3, "aff": ["power", "lance_charge", "peal_reach"],
		"lore": "He never reached the top. He carried this the whole way up, empty, to have something to set down."},
	# --- the bells' keepers: each gives its own piece on its first fall (LootDB.RARE_OWN)
	"kin_bell_ring": {"name": "Kin-Bell Rope-Ring", "slot": "focus", "rarity": 3, "aff": ["peal_reach", "lash_power", "power"],
		"lore": "The rope the Kin-Caller pulled until it called the wrong names. Knotted into a ring, it still hums the first of them."},
	"hewer_apron": {"name": "Bell-Hewer's Dust Apron", "slot": "vestment", "rarity": 3, "aff": ["dark_mult", "gloom_add", "kill_relief"],
		"lore": "Stone-dust to the hem, and under the dust a bell-founder's mark. He was hewing the bell's mould, not its stone, and nobody told him."},
	"shepherd_strap": {"name": "Fog-Shepherd's Bell-Strap", "slot": "girdle", "rarity": 3, "aff": ["step_range", "tether_reach", "cd"],
		"lore": "The wether's collar, cut down to a belt. The bell is gone from it. The sound is not."},
	"slag_glass": {"name": "Slag-Born's Cooling Glass", "slot": "lantern", "rarity": 3, "aff": ["lit_mult", "ward_life", "kill_relief"],
		"lore": "Cast in the pour that never stopped, and cracked when it did. The light comes through the crack, orange, and warms the hand."},
	"sower_cloak": {"name": "Ash-Sower's Seed-Cloak", "slot": "vestment", "rarity": 3, "aff": ["ash_find", "gloom_add", "lit_mult"],
		"lore": "Every pocket holds a pinch of grey seed. Plant one in ash and something comes up, slowly, that is not a tree."},
	"ringer_clapper": {"name": "Passing-Ringer's Muffled Clapper", "slot": "focus", "rarity": 3, "aff": ["mark_dmg", "lance_charge", "power"],
		"lore": "Wrapped in wool so it would strike once, softly, for each of the dead. It struck a great many times."},
	"fare_lamp": {"name": "Fare-Caller's Coin-Lamp", "slot": "lantern", "rarity": 3, "aff": ["well_life", "shade_life", "mark_dmg"],
		"lore": "A lamp with a slot cut in the lid for a coin, and a coin in it that has never once come out."},
}
