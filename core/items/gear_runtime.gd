extends Node
## Gear runtime (docs/enshrouded/equipment.md). One per Realm, added by progression.gd beside the
## Kindling. It owns Travel.system_state("gear") and does four things:
##   - drops: foes, elites and the great ones drop gear (gear_drop.gd: a rarity-coloured shaft of
##     light you walk through to take); chances and rarities are GearDB.drop_chance / drop_rarity,
##     with a pity that builds between drops of common foes
##   - acts for the gear panel (ui/gear_panel.gd): wear, take off, raise (ash + ember shards, at a
##     kindled fire), reforge an affix (shards, relic fragments for Hallowed+, at a fire), salvage
##   - after any change it has the progression runtime recompute the live modifiers (gear lands in
##     them through gear_stats.gd, the one hook) and saves
##   - the look: the lantern's light takes the worn glass's rarity (wanderer_lantern's own light;
##     nothing on the wanderer is remodelled), and a full set or an Umbral glass adds faint motes
## Load by path (no class_name).
##
## r33 loot (WoW-style): elites, rares, the great ones and chests leave a LOOT BAG (loot_bag.gd: a
## quality-coloured shaft of light; [E] opens ui/loot_window.gd: take one / take all). Common foes
## still drop a single walk-in shaft (gear_drop.gd). Tables: loot_db.gd.
##
## FOR THE ENEMIES PASS (rares): either
##   - set meta on the rare before it dies:  enemy.set_meta(&"rare_id", "the_tollman")
##     (and optionally &"rare_name", "The Tollman"); its death lays the rare's bag by itself, or
##   - call it yourself:  get_tree().get_first_node_in_group("gear").call("drop_rare", "the_tollman", at)
##     (at: Vector3; opts {"name": String} titles the bag). Returns the entries laid.
## A rare's FIRST fall (per rare_id, saved in gear.rares) adds a named piece from LootDB.RARE_TABLE
## (or LootDB.RARE_OWN[rare_id]); every fall gives a Hallowed-or-better piece and ember shards.
## XP: hearth.gd gives LevelDB.XP.rare for a kill that carries &"rare_id".

const GearDB := preload("res://core/items/gear_db.gd")
const GearStats := preload("res://core/items/gear_stats.gd")
const GearDrop := preload("res://core/items/gear_drop.gd")
const LootDB := preload("res://core/items/loot_db.gd")
const LootBag := preload("res://core/items/loot_bag.gd")
const AUTO_OPEN_R := 3.5          ## a chest's bag opens its window at once when you stand this close
const SID := "gear"
const PITY_STEP := 0.004

var rng := RandomNumberGenerator.new()
var _lantern_base := {}                ## LanternLight instance id -> [colour, energy]
var _look_key := "?"
var _scan := 0.0


func _ready() -> void:
	name = "Gear"
	add_to_group("gear")
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	GearStats.state()
	Events.enemy_killed.connect(_on_killed)
	Events.boss_slain.connect(_on_boss)


func _process(delta: float) -> void:
	_scan -= delta
	if _scan > 0.0:
		return
	_scan = 0.6
	apply_look()


func state() -> Dictionary:
	return GearStats.state()


# --- drops --------------------------------------------------------------------------------------

## What kind of foe `e` was, for the drop tables.
static func source_of(e: Node) -> String:
	if e == null:
		return "kill"
	if e.has_meta(&"boss_id"):
		return "boss"
	if e.has_meta(&"rare_id"):
		return "rare"
	if e.has_meta(&"elite_id"):
		return "umbral" if e.has_meta(&"enc_umbral") else "elite"
	if e.has_meta(&"enc_variant") or int(e.get_meta(&"enc_tier", 0)) > 0:
		return "tough"
	return "kill"


func _on_killed(e: Node) -> void:
	if not is_instance_valid(e) or not (e is Node3D):
		return
	var src := source_of(e)
	if src == "boss":
		return                                     # the arena's boss_slain drops its piece
	var at := (e as Node3D).global_position
	if src == "rare":
		drop_rare(String(e.get_meta(&"rare_id")), at, {"name": String(e.get_meta(&"rare_name", ""))})
		return
	var piece := roll_drop(src)
	if piece.is_empty():
		return
	if src == "elite" or src == "umbral":
		# r33 loot: an elite's remains are a bag: its piece and a few shards
		drop_bag([{"kind": "gear", "piece": piece}, {"kind": "item", "id": "ember_shard", "n": 1 + rng.randi_range(0, 2)}], at, "the remains")
		return
	drop_at(piece, at)


func _on_boss(id: String) -> void:
	var st := state()
	var got: Dictionary = st.get("boss_drops", {}) if st.get("boss_drops") is Dictionary else {}
	if got.has(id):
		return
	got[id] = true
	st["boss_drops"] = got
	var entries := boss_loot(id)
	var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	if p:
		drop_bag(entries, p.global_position + (-p.global_basis.z) * 2.5, "the great one's hoard")
	else:
		for e: Dictionary in entries:
			Events.toast.emit(LootBag._store(e))


# --- r33 loot: tables, bags, rares, chests ------------------------------------------------------

## A great one's hoard (first kill): a named piece off its table you do not own yet, a set piece,
## ember shards, and a LootDB.LEGEND_CHANCE chance at an Umbral legend you have not found.
func boss_loot(id: String) -> Array:
	var st := state()
	var out: Array = []
	var table: Array = LootDB.BOSS_TABLE.get(id, LootDB.BOSS_FALLBACK)
	var nm := _pick_named(st, table)
	if nm != "":
		out.append({"kind": "gear", "piece": GearDB.make(rng, {"named": nm, "uid": _next_uid()})})
	out.append({"kind": "gear", "piece": roll_drop("boss")})
	if rng.randf() < LootDB.LEGEND_CHANCE:
		var lg := _missing_legend(st)
		if lg != "":
			out.append({"kind": "gear", "piece": GearDB.make(rng, {"legend": lg, "uid": _next_uid()})})
	out.append({"kind": "item", "id": "ember_shard", "n": LootDB.BOSS_SHARDS})
	return out


## A named id from `table` that is not in the bag yet (any when all are owned).
func _pick_named(st: Dictionary, table: Array) -> String:
	var open: Array = []
	for nm: Variant in table:
		if GearDB.NAMED.has(String(nm)) and not _owned(st, "named", String(nm)):
			open.append(String(nm))
	if open.is_empty():
		open = table.filter(func(x: Variant) -> bool: return GearDB.NAMED.has(String(x)))
	return "" if open.is_empty() else String(open[rng.randi_range(0, open.size() - 1)])


## A rare's bag (see the header). Returns the entries laid.
func drop_rare(rare_id: String, at: Vector3, opts := {}) -> Array:
	var st := state()
	var seen: Dictionary = st.get("rares", {}) if st.get("rares") is Dictionary else {}
	var first := not seen.has(rare_id)
	seen[rare_id] = int(seen.get(rare_id, 0)) + 1
	st["rares"] = seen
	var out: Array = []
	if first:
		var own := String(LootDB.RARE_OWN.get(rare_id, ""))
		var nm := own if GearDB.NAMED.has(own) else _pick_named(st, LootDB.RARE_TABLE)
		if nm != "":
			out.append({"kind": "gear", "piece": GearDB.make(rng, {"named": nm, "uid": _next_uid()})})
	var r := 3 if rng.randf() < 0.3 else 2
	var o2 := {"rarity": r, "uid": _next_uid()}
	if rng.randf() < 0.4:
		var pick := _missing_set_piece(st)
		o2["set"] = pick[0]
		o2["slot"] = pick[1]
	out.append({"kind": "gear", "piece": GearDB.make(rng, o2)})
	out.append({"kind": "item", "id": "ember_shard", "n": rng.randi_range(LootDB.RARE_SHARDS.x, LootDB.RARE_SHARDS.y)})
	if rng.randf() < LootDB.RARE_FRAG_CHANCE:
		out.append({"kind": "item", "id": "relic_fragment", "n": 1})
	var title := String(opts.get("name", ""))
	drop_bag(out, at, title if title != "" else "the rare one's remains")
	Travel.save_soon()
	return out


## Called by loot_chest.gd when it opens: the chest's piece (iron and reliquary always, wood often),
## marked so drop_at lays it as a bag with the chest's extras (LootDB.CHEST_EXTRA).
func roll_chest(tier: String, _chest_id: String) -> Dictionary:
	var src := String(LootDB.CHEST_SRC.get(tier, "tough"))
	var piece := {}
	if tier != "wood" or rng.randf() < 0.6:
		var opts := {"rarity": maxi(1, GearDB.drop_rarity(src, rng.randf())), "uid": _next_uid()}
		if int(opts.rarity) >= 2 and rng.randf() < 0.5:
			var pick := _missing_set_piece(state())
			opts["set"] = pick[0]
			opts["slot"] = pick[1]
		piece = GearDB.make(rng, opts)
	else:
		return {}                                 # a burner's box sometimes holds only its ash
	piece["_chest"] = tier
	return piece


## Lay a loot bag at `at` (see loot_bag.gd). `auto_open`: show the window at once when the
## wanderer stands within AUTO_OPEN_R.
func drop_bag(entries: Array, at: Vector3, title := "the remains", auto_open := false) -> Node3D:
	var clean: Array = entries.filter(func(e: Variant) -> bool:
		return e is Dictionary and (String(e.get("kind", "")) != "gear" or not (e.get("piece", {}) as Dictionary).is_empty()))
	if clean.is_empty():
		return null
	var root := get_tree().current_scene if is_inside_tree() else null
	if root == null:
		for e: Dictionary in clean:
			Events.toast.emit(LootBag._store(e))
		return null
	var b: Node3D = LootBag.new()
	b.set("entries", clean)
	b.set("title", title)
	root.add_child(b)
	b.global_position = at + Vector3(0, 0.05, 0)
	if auto_open:
		var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
		if p and p.global_position.distance_to(at) <= AUTO_OPEN_R and not get_tree().paused:
			b.call_deferred("open_window")
	return b


## Roll a drop for a source, or {} for nothing. Elites and bosses always drop; Hallowed and better
## are set pieces half the time (bosses: always), favouring a set piece you do not have yet; an
## Umbral roll is a legend you have not found while any remain.
func roll_drop(src: String) -> Dictionary:
	var st := state()
	var chance := GearDB.drop_chance(src)
	if chance < 1.0:
		chance += PITY_STEP * float(st.get("pity", 0))
		if rng.randf() >= chance:
			st["pity"] = int(st.get("pity", 0)) + 1
			return {}
		st["pity"] = 0
	var rarity := GearDB.drop_rarity(src, rng.randf())
	var opts := {"rarity": rarity, "uid": _next_uid()}
	if rarity == 4:
		var lg := _missing_legend(st)
		if lg != "":
			opts["legend"] = lg
	if rarity >= 2 and not opts.has("legend") and (src == "boss" or rng.randf() < 0.5):
		var pick := _missing_set_piece(st)
		opts["set"] = pick[0]
		opts["slot"] = pick[1]
	return GearDB.make(rng, opts)


func _next_uid() -> int:
	var st := state()
	var n := int(st.get("next_uid", 1))
	st["next_uid"] = n + 1
	return n


func _owned(st: Dictionary, key: String, val: String, slot := "") -> bool:
	for p: Variant in st.get("bag", []):
		if p is Dictionary and String((p as Dictionary).get(key, "")) == val and (slot == "" or String(p.slot) == slot):
			return true
	return false


func _missing_legend(st: Dictionary) -> String:
	var open: Array = []
	for lg: String in GearDB.LEGEND_ORDER:
		if not _owned(st, "legend", lg):
			open.append(lg)
	return "" if open.is_empty() else String(open[rng.randi_range(0, open.size() - 1)])


## [set id, slot]: a piece not yet owned (any set) if one is left, else any.
func _missing_set_piece(st: Dictionary) -> Array:
	var open: Array = []
	for s: String in GearDB.SET_ORDER:
		for slot: String in GearDB.SLOTS:
			if not _owned(st, "set", s, slot):
				open.append([s, slot])
	if open.is_empty():
		return [GearDB.SET_ORDER[rng.randi_range(0, 3)], GearDB.SLOTS[rng.randi_range(0, 3)]]
	return open[rng.randi_range(0, open.size() - 1)]


## Lay `piece` in the world at `at` as a shaft of light (walk through it to take it).
func drop_at(piece: Dictionary, at: Vector3) -> void:
	if piece.has("_chest"):                       # r33 loot: a chest's piece comes as a bag
		var tier := String(piece.get("_chest", "wood"))
		var pc := piece.duplicate(true)
		pc.erase("_chest")
		var entries: Array = [{"kind": "gear", "piece": pc}]
		var ex: Dictionary = LootDB.CHEST_EXTRA.get(tier, {})
		for id: String in ex:
			entries.append({"kind": "item", "id": id, "n": int(ex[id])})
		drop_bag(entries, at, "the chest", true)
		return
	var root := get_tree().current_scene
	if root == null:
		Events.toast.emit(store(piece))
		return
	var d: Node3D = GearDrop.new()
	d.piece = piece
	root.add_child(d)
	d.global_position = at + Vector3(0, 0.1, 0)


## Put a piece in the bag (from a drop, a test or a reward). A full bag salvages it into shards.
## A piece for an empty slot is worn at once. Returns a line for the toast.
static func store(piece: Dictionary) -> String:
	piece.erase("_chest")
	var st := GearStats.state()
	var bag: Array = st.bag
	var nm := String(piece.get("name", "gear"))
	if int(piece.get("uid", 0)) <= 0:
		var n := int(st.get("next_uid", 1))
		st["next_uid"] = n + 1
		piece["uid"] = n
	var line := ""
	if bag.size() >= GearDB.BAG_CAP:
		var v := GearDB.salvage_value(piece)
		Travel.give("ember_shard", v, false)
		line = "%s: the satchel is full, so the fire took it. +%d Ember Shards." % [nm, v]
	else:
		bag.append(piece)
		var w: Dictionary = st.worn
		var slot := String(piece.get("slot", ""))
		if not w.has(slot) or GearStats.find(st, int(w[slot])).is_empty():
			w[slot] = int(piece.uid)
			line = "%s %s. You wear it." % [GearDB.rarity_name(int(piece.rarity)), nm]
		else:
			line = "%s %s." % [GearDB.rarity_name(int(piece.rarity)), nm]
		if not st.get("told", false):
			st["told"] = true
			line += " [%s] to see your gear." % _gear_key()
	_changed()
	return line


static func _gear_key() -> String:
	if not InputMap.has_action("gear"):
		return "G"
	for e: InputEvent in InputMap.action_get_events("gear"):
		if e is InputEventKey:
			var k := e as InputEventKey
			return OS.get_keycode_string(k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode)
	return "G"


## After any change: recompute the live modifiers (gear rides in through gear_stats.gd), save.
static func _changed() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree:
		var k := tree.get_first_node_in_group("progression")
		if k and k.has_method("refresh"):
			k.call("refresh")
		var g := tree.get_first_node_in_group("gear")
		if g and g.has_method("apply_look"):
			g.set("_look_key", "?")
			g.call("apply_look")
	Travel.save_soon()


# --- acting for the panel -----------------------------------------------------------------------

func equip(uid: int) -> String:
	var st := state()
	var p := GearStats.find(st, uid)
	if p.is_empty():
		return "That is not in the satchel."
	(st.worn as Dictionary)[String(p.slot)] = uid
	_changed()
	return ""


func unequip(slot: String) -> String:
	var st := state()
	(st.worn as Dictionary).erase(slot)
	_changed()
	return ""


func why_not_upgrade(uid: int, at_fire: bool) -> String:
	var p := GearStats.find(state(), uid)
	if p.is_empty():
		return "That is not in the satchel."
	var c := GearDB.upgrade_cost(p)
	if c.is_empty():
		return "It will take no more. (%s pieces stop at +%d.)" % [GearDB.rarity_name(int(p.rarity)), GearDB.max_level(p)]
	if Travel.count("grave_ash") < int(c.ash):
		return "Needs %d grave ash (you carry %d)." % [c.ash, Travel.count("grave_ash")]
	if Travel.count("ember_shard") < int(c.shards):
		return "Needs %d ember shards (you carry %d). Salvage gear for them." % [c.shards, Travel.count("ember_shard")]
	if not at_fire:
		return "Only at a kindled fire."
	return ""


func upgrade(uid: int, at_fire: bool) -> String:
	var why := why_not_upgrade(uid, at_fire)
	if why != "":
		return why
	var p := GearStats.find(state(), uid)
	var c := GearDB.upgrade_cost(p)
	_spend("grave_ash", int(c.ash))
	_spend("ember_shard", int(c.shards))
	p["level"] = int(p.get("level", 0)) + 1
	_changed()
	return ""


func why_not_reforge(uid: int, at_fire: bool) -> String:
	var p := GearStats.find(state(), uid)
	if p.is_empty():
		return "That is not in the satchel."
	var c := GearDB.reforge_cost(p)
	if c.is_empty():
		return "Worn pieces carry nothing to reforge."
	if Travel.count("ember_shard") < int(c.shards):
		return "Needs %d ember shards (you carry %d)." % [c.shards, Travel.count("ember_shard")]
	if Travel.count("relic_fragment") < int(c.frag):
		return "Needs a relic fragment."
	if not at_fire:
		return "Only at a kindled fire."
	return ""


## Reroll affix `idx` of a piece: a new affix the piece does not carry, or the same one rerolled.
func reforge(uid: int, idx: int, at_fire: bool) -> String:
	var why := why_not_reforge(uid, at_fire)
	if why != "":
		return why
	var p := GearStats.find(state(), uid)
	var aff: Array = p.aff
	idx = clampi(idx, 0, aff.size() - 1)
	var c := GearDB.reforge_cost(p)
	_spend("ember_shard", int(c.shards))
	_spend("relic_fragment", int(c.frag))
	var pool: Array = []
	for a: String in GearDB.SLOT_AFFIX[String(p.slot)]:
		var held := false
		for i in aff.size():
			if i != idx and String(aff[i][0]) == a:
				held = true
		if not held:
			pool.append(a)
	var pick := String(pool[rng.randi_range(0, pool.size() - 1)])
	aff[idx] = [pick, GearDB.roll_value(rng, pick)]
	p["name"] = GearDB.name_of(p)
	_changed()
	return ""


func salvage(uid: int) -> String:
	var st := state()
	var p := GearStats.find(st, uid)
	if p.is_empty():
		return "That is not in the satchel."
	var w: Dictionary = st.worn
	for slot: String in w.keys():
		if int(w[slot]) == uid:
			w.erase(slot)
	(st.bag as Array).erase(p)
	Travel.give("ember_shard", GearDB.salvage_value(p), false)
	_changed()
	return ""


func _spend(id: String, n: int) -> void:
	if n <= 0:
		return
	Travel.items[id] = maxi(0, Travel.count(id) - n)
	if Travel.count(id) <= 0:
		Travel.items.erase(id)
	Events.item_gained.emit(id, -n, Travel.count(id))


# --- the look -----------------------------------------------------------------------------------

## The lantern's own light takes the worn glass's rarity colour; a full set or an Umbral glass
## adds a few motes round it. Nothing is remodelled (umbral-donts).
func apply_look() -> void:
	var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Node
	if p == null:
		return
	var light := p.find_child("LanternLight", true, false) as OmniLight3D
	if light == null:
		return
	var st := state()
	var w := GearStats.worn(st)
	var glass: Dictionary = w.get("lantern", {})
	var full := false
	for n: int in GearStats.set_counts(st).values():
		full = full or n >= 4
	var key := "%d|%d|%s|%s" % [light.get_instance_id(), int(glass.get("rarity", -1)), str(full), String(glass.get("legend", ""))]
	if key == _look_key:
		return
	_look_key = key
	var id := light.get_instance_id()
	if not _lantern_base.has(id):
		_lantern_base[id] = [light.light_color, light.light_energy]
	var base: Array = _lantern_base[id]
	var r := int(glass.get("rarity", -1))
	if r < 0:
		light.light_color = base[0]
		light.light_energy = base[1]
	else:
		light.light_color = (base[0] as Color).lerp(GearDB.rarity_color(r), 0.18 + 0.06 * float(r))
		light.light_energy = float(base[1]) * (1.0 + 0.04 * float(r))
	var holder := light.get_parent()
	var old := holder.get_node_or_null("GearMotes")
	if old:
		old.queue_free()
	if full or String(glass.get("legend", "")) != "":
		var col := GearDB.rarity_color(r if r >= 0 else 3)
		var motes := Vfx.emitter(Color(col.r * 2.2, col.g * 2.2, col.b * 2.2), {"count": 10, "life": 1.1, "speed": Vector2(0.03, 0.15), "size": 0.022, "gravity": -0.25, "radius": 0.08, "turbulence": true})
		motes.name = "GearMotes"
		motes.position = light.position
		holder.add_child(motes)
		motes.emitting = true
