extends Node
## Dev tool: build a "god save" in the current slot, through the game's own functions.
##   HOME=<scratch> godot --headless --path . res://zz/god_save.tscn
## -> <user dir>/slot_1/savegame.cfg. Copy that into a real slot by hand.
## Everything unlocked and done EXCEPT the three great ones: they stand (no bosses slain), so every
## fight can be had. The seals are broken so their rooms are open. Act III and the ending wait on
## the Warden, as they must.

const Chains := preload("res://core/story/quest_chains.gd")
const Book := preload("res://core/story/quest_book.gd")
const DB := preload("res://core/life/progression/upgrade_db.gd")
const GearDB := preload("res://core/items/gear_db.gd")
const GearRuntime := preload("res://core/items/gear_runtime.gd")
const HorseDB := preload("res://core/world/mount/horse_db.gd")

var main: Node
var _done := false
var _t := 0.0


func _ready() -> void:
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _process(d: float) -> void:
	_t += d
	if _t > 280.0:
		print("GOD timeout")
		get_tree().quit(1)
	if _done or not is_instance_valid(main) or not main.has_meta("realm_done"):
		return
	_done = true
	_build()
	await get_tree().create_timer(1.0).timeout
	Travel.save_game()
	print("GOD saved to ", Travel.SAVE_PATH)
	get_tree().quit(0)


func _build() -> void:
	# currencies and materials
	Travel.give("grave_ash", 99999, false)
	for m: String in ["ember_shard", "relic_fragment", "ash_bloom", "grave_iron"]:
		Travel.give(m, 999, false)
	# story: arrived, met everyone
	if not (Travel.story.get("flags") is Dictionary):
		Travel.story["flags"] = {}
	for f: String in ["arrived", "met_keep", "met_hesk", "met_harrow", "met_brannoc"]:
		(Travel.story.flags as Dictionary)[f] = true
	# every task done, bar what waits on the Warden; every bell's tongue carried home
	var n := 0
	for id: String in Chains.QUESTS:
		var qd: Dictionary = Chains.QUESTS[id]
		if String(qd.get("avail", "")).contains("ascended_warden") or ["the_latch", "still_climbing", "names_under", "full_peal"].has(id):
			continue
		if Book.done(id):
			continue
		Book.start(id)
		if Chains.BELLS.has(id):
			Book.choose(id, "carried")
		Book.complete(id)
		n += 1
	print("GOD quests done ", n)
	# relics: every one, on its first variant
	for k: String in Reliquary.VARIANTS:
		Travel.relics[k] = (Reliquary.VARIANTS[k] as Array)[0]
	# the Kindling: every spell known and ranked, every ember and rite at its top
	var k := get_tree().get_first_node_in_group("progression")
	var st: Dictionary = Travel.system_state("progression")
	st["taught"] = DB.TAUGHT_LATER.duplicate()
	var known: Array = st.get("known", []) if st.get("known") is Array else []
	var ranks: Dictionary = st.get("ranks", {}) if st.get("ranks") is Dictionary else {}
	for s: Dictionary in DB.SPELLS:
		var sid := String(s.id)
		if DB.learnable(sid) or sid == "peal":
			if not known.has(sid):
				known.append(sid)
		ranks[sid] = 3
	for e: Dictionary in DB.EMBERS:
		ranks[String(e.id)] = int(e.max)
	for r: Dictionary in DB.RITES:
		ranks[String(r.id)] = 1
	st["known"] = known
	st["ranks"] = ranks
	st["memory"] = 99999
	if k and k.has_method("refresh"):
		k.call("refresh")
	# gear: the four legends (worn), then every set piece at the top rarity
	var rng := RandomNumberGenerator.new()
	rng.seed = 1777
	for l: String in GearDB.LEGEND_ORDER:
		GearRuntime.store(GearDB.make(rng, {"legend": l, "rarity": 4}))
	for s: String in GearDB.SET_ORDER:
		for slot: String in GearDB.SLOTS:
			GearRuntime.store(GearDB.make(rng, {"set": s, "slot": slot, "rarity": 3}))
	# every horse
	var stab := Travel.system_state("stable")
	stab["owned"] = (HorseDB.BREEDS.keys() as Array).duplicate()
	stab["ride"] = "palfrey"
	# the seals broken (rooms open); the great ones stand
	for seal: String in ["henge", "oss_gallery", "summit"]:
		Travel.seals_broken[seal] = true
	Travel.bosses_slain.clear()
	# every fire kindled (recorded by name for the night's scene, as Travel does for the current scene)
	var lit := PackedStringArray()
	for b in get_tree().get_nodes_in_group(Groups.BRAZIER):
		if b is Brazier and main.is_ancestor_of(b):
			(b as Brazier).kindle_quiet()
			lit.append(b.name)
	Travel.lit_by_path["res://world/main.tscn"] = lit
	print("GOD fires ", lit.size())
	print("GOD ash ", Travel.count("grave_ash"), " relics ", Travel.relics.size(), " spells known ", known.size(),
		" bells ", Book.bells(), " gear ", (Travel.system_state("gear").get("bag", []) as Array).size())
