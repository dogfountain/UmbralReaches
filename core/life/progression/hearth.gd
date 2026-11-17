extends Node
## The Hearthfire runtime (progression; docs/enshrouded/progression.md). One per Realm, added by
## progression.gd beside the Kindling runtime. Data: hearth_db.gd (the Hearthfire, Hild's works,
## meals, Rested) and paths_db.gd (the Paths and memory). It:
##   - gathers MEMORY from deeds (kills, kindles, seals, the keepers, settled tasks, keepsakes,
##     homecomings in Hearthward) and says when a Remembrance comes back
##   - takes and gives back Path steps (the Kindling's PATHS tab)
##   - raises the Hearthfire at Hearthward's fire, opens the village's trades (village flags
##     svc_smith / svc_herbs, which village_talk_db.gd's choices read)
##   - widens every kindled fire's sanctuary (Brazier.set_reach) by the tier, the works and the Paths
##   - counts meals and Rested down in play time, and grants Rested at home (the green's fire, the Keg)
##   - walks the wanderer from fire to fire once Brannoc's bells are hung
##   - the Ash-Gleaner's second pinch
## Every change to the numbers goes through the Kindling runtime's refresh() (kindling.gd), which
## folds the Paths and this state into UpgradeDB.live.
## r33 progression: the level / XP bar contract (signals xp_changed, leveled_up; xp_info()) and the
## XP rules (by foe, discovery, rested XP) are documented in level.gd.

const HearthDB := preload("res://core/life/progression/hearth_db.gd")
const PathsDB := preload("res://core/life/progression/paths_db.gd")
const VState := preload("res://core/life/village/village_state.gd")
const SID := "hearth"
const UiSound := preload("res://ui/ui_sound.gd")
const DB := preload("res://core/life/progression/upgrade_db.gd")
const SVC_FLAG := {"smith": "svc_smith", "herbs": "svc_herbs", "bells": "svc_bells", "beacon": "svc_beacon"}
const LevelDB := preload("res://core/life/progression/level.gd")
const QuestChains := preload("res://core/story/quest_chains.gd")
const QuestBook := preload("res://core/story/quest_book.gd")
const GearRuntime := preload("res://core/items/gear_runtime.gd")

## r33 progression (see level.gd): the XP bar's data source.
signal xp_changed(info: Dictionary)
signal leveled_up(level: int, points: int)

var last_gain := 0
var last_why := ""

var _tick := 0.0
var _home_t := 0.0                 ## seconds stood at home (Rested)
var _reach_t := 0.0
var _homes := -1                   ## restorations seen (memory for each new one)
var _dirty := false                ## a meal or Rested ran out: refresh the numbers
## Rested is earned by coming home: armed once the wanderer has been ARM_R from Hearthward's fire
## (a fresh wake on the green is not a rest), spent by the rest.
var armed := false
const ARM_R := 40.0


func _ready() -> void:
	name = "Hearth"
	add_to_group("hearth")
	_ensure()
	Events.enemy_killed.connect(_on_killed)
	Events.brazier_kindled.connect(func(_b: Node3D) -> void: give_memory(LevelDB.xp_for("kindle"), "kindle"))
	Events.seal_broken.connect(func(_id: String) -> void: give_memory(LevelDB.xp_for("seal"), "seal"))
	Events.boss_slain.connect(func(_id: String) -> void: give_memory(LevelDB.xp_for("boss"), "boss"))
	Events.quest_changed.connect(func(id: String, _step: int, done: bool) -> void:
		if done:
			var qd: Dictionary = QuestChains.QUESTS.get(id, {})
			var again := int(QuestBook.q(id).get("c", 0)) > 1
			give_memory(LevelDB.quest_xp(int((qd.get("reward", {}) as Dictionary).get("ash", 0)), again), "quest"))
	Events.item_gained.connect(_on_item)
	Events.zone_entered.connect(_on_zone)
	# r33 merge: the Realm's discovery (realm_discovery.gd) fires region_discovered once per place
	# per save; zone titles alone no longer name every place. Same "seen" ledger, keyed by id.
	if Events.has_signal("region_discovered"):
		Events.region_discovered.connect(func(id: String, _kind: String) -> void: _on_zone("place:" + id, ""))
	if Events.has_signal("world_event"):
		Events.world_event.connect(func(_id: String, phase: String, _at: Vector3) -> void:
			if phase == "won":
				give_memory(LevelDB.xp_for("elite"), "world event"))


func hs() -> Dictionary:
	return Travel.system_state(SID)


func ps() -> Dictionary:
	return Travel.system_state("progression")


func _ensure() -> void:
	var h := hs()
	h["tier"] = HearthDB.tier(h)
	if not (h.get("works") is Dictionary):
		h["works"] = {}
	if not (h.get("meals") is Dictionary):
		h["meals"] = {}
	h["rested"] = maxf(0.0, float(h.get("rested", 0.0)))
	h.erase("ward")                    # a ward lasts a night, and the village's night count starts again with the Realm
	h.erase("ward_night")
	var p := ps()
	if not (p.get("paths") is Dictionary):
		p["paths"] = {}
	p["memory"] = int(p.get("memory", 0))
	p["rested_xp"] = maxi(0, int(p.get("rested_xp", 0)))
	if not (p.get("seen") is Dictionary):
		p["seen"] = {}
	_sync_flags()


func _kindling() -> Node:
	return get_tree().get_first_node_in_group("progression")


func _refresh() -> void:
	var k := _kindling()
	if k:
		k.call("refresh")


func bosses() -> int:
	return Travel.bosses_slain.size()


func _player() -> Node3D:
	return get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D


# --- the clock ------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_tick += delta
	if _tick < 0.5:
		return
	var dt := _tick
	_tick = 0.0
	step(dt)


## One step of `dt` seconds (tests call it with large steps).
func step(dt: float) -> void:
	var h := hs()
	# meals and Rested burn down in play time
	var meals := HearthDB.meals(h)
	for kind: String in meals.keys():
		var e: Variant = meals[kind]
		if not (e is Dictionary):
			meals.erase(kind)
			continue
		var left := float((e as Dictionary).get("left", 0.0)) - dt
		if left <= 0.0:
			meals.erase(kind)
			_dirty = true
			Events.toast.emit("%s wears off." % String(HearthDB.meal(String((e as Dictionary).get("id", ""))).get("name", "A meal")))
		else:
			(e as Dictionary)["left"] = left
	if bool(h.get("ward", false)) and _night() != int(h.get("ward_night", -1)):
		h.erase("ward")
		h.erase("ward_night")
		_dirty = true
		Events.toast.emit("The night-ward burns down with the night.")
	var r := float(h.get("rested", 0.0))
	if r > 0.0:
		r = maxf(0.0, r - dt)
		h["rested"] = r
		if r <= 0.0:
			_dirty = true
			Events.toast.emit("The fire's ease is gone." if int(ps().get("rested_xp", 0)) > 0 else "The fire's ease is gone, and the memory it kept with it.")
	# Rested: come home from the dark (ARM_R out), then stand at home a few seconds
	var p := _player()
	if p and Vector2(p.global_position.x, p.global_position.z).distance_to(HearthDB.HOME) > ARM_R:
		armed = true
	if p and armed and HearthDB.at_home(p.global_position) and (LightGrid.is_fire(p.global_position) or HearthDB.KEG.has_point(Vector2(p.global_position.x, p.global_position.z))):
		_home_t += dt
		if _home_t >= HearthDB.REST_STAND:
			rest_here()
	else:
		_home_t = 0.0
	# homecomings in Hearthward are memories too
	var homes := _restored()
	if _homes < 0:
		_homes = homes
	elif homes > _homes:
		give_memory(LevelDB.xp_for("home") * (homes - _homes), "home")
		_homes = homes
	_reach_t -= dt
	if _reach_t <= 0.0:
		_reach_t = 1.0
		apply_reach()
	if _dirty:
		_dirty = false
		_refresh()


func _restored() -> int:
	return (VState.data().restored as Dictionary).size()


## Rested at full (unless it is already most of the way there). Returns true when it was granted.
func rest_here() -> bool:
	var h := hs()
	var full := rest_full()
	if float(h.get("rested", 0.0)) >= full * 0.8:
		return false
	var was := float(h.get("rested", 0.0)) > 0.0
	h["rested"] = full
	ps()["rested_xp"] = LevelDB.rest_pool(ps())          # r33: rested XP (level.gd)
	xp_changed.emit(xp_info())
	_home_t = 0.0
	armed = false
	Events.toast.emit("Rested (comfort %d, %s): Gloom gathers slower and your spells recover sooner, and the pale stretch on the bar pays kills twice." % [comfort(), HearthDB.fmt_secs(full)] if not was else "Rested again: %s." % HearthDB.fmt_secs(full))
	_refresh()
	Travel.save_soon()
	return true


func comfort() -> int:
	return HearthDB.comfort(hs(), _restored())


func rest_full() -> float:
	return HearthDB.rest_secs(hs(), _restored(), float(_live("rest_add", 0.0)))


## Every lit brazier's sanctuary set to its base reach + the Hearthfire + works + Paths.
func apply_reach() -> void:
	var add := HearthDB.reach(hs(), float(_live("reach_add", 0.0)))
	for n in get_tree().get_nodes_in_group(Groups.BRAZIER):
		if not n.has_method("set_reach"):
			continue
		var base: Variant = n.get_meta(&"reach_base") if n.has_meta(&"reach_base") else Vector2(float(n.get("light_radius")), 0.0)
		n.call("set_reach", (base as Vector2).x + add)


# --- memory and the Paths -------------------------------------------------------------------------

func memory() -> int:
	return int(ps().get("memory", 0))


func level() -> Dictionary:
	return PathsDB.level_of(memory())


func free_points() -> int:
	return PathsDB.free_pts(ps(), bosses())


## The XP bar's data (level.gd documents every key).
func xp_info() -> Dictionary:
	var d := LevelDB.info(ps(), bosses())
	d["last_gain"] = last_gain
	d["last_why"] = last_why
	return d


func give_memory(n: int, why: String) -> void:
	if n <= 0:
		return
	var p := ps()
	var rs := LevelDB.with_rested(p, n, why)                 # r33: rested XP doubles kills
	n = int(rs[0])
	if int(rs[1]) > 0:
		p["rested_xp"] = maxi(0, int(p.get("rested_xp", 0)) - int(rs[1]))
	var before := int(PathsDB.level_of(int(p.get("memory", 0))).level)
	p["memory"] = int(p.get("memory", 0)) + n
	var after := int(PathsDB.level_of(int(p.memory)).level)
	last_gain = n
	last_why = why
	if after > before:
		Events.toast.emit("Something comes back to you. Level %d: a step on the Paths [%s]." % [after, InputSetup.live_label("kindling", Settings.using_pad, "K")])
		_ding()
		leveled_up.emit(after, free_points())
		Travel.save_soon()
	xp_changed.emit(xp_info())


## A level-up's flourish: a column of warm motes round the wanderer and a chime (WoW's "ding").
func _ding() -> void:
	var pl := _player()
	if pl == null or not pl.is_inside_tree():
		return
	Vfx.burst(pl.global_position + Vector3(0, 0.2, 0), Color(2.4, 1.7, 0.8), {"count": 60, "life": 1.4, "speed": Vector2(1.5, 4.0), "size": 0.05, "gravity": -1.2, "radius": 0.5})
	UiSound.play(self, "level_up")        # its own rising run (the ward chime is the chest's, the pickups' and the kindling's cue)


func why_not_path(id: String) -> String:
	return PathsDB.why_not(ps(), id, bosses())


func take_path(id: String) -> String:
	var why := why_not_path(id)
	if why != "":
		return why
	(ps().paths as Dictionary)[id] = 1
	_refresh()
	Travel.save_game()
	return ""


func unremember_cost() -> int:
	return HearthDB.UNREMEMBER_PER * PathsDB.taken(ps()).size()


func why_not_unremember(at_home_fire: bool) -> String:
	if PathsDB.taken(ps()).is_empty():
		return "Nothing to unremember."
	if not at_home_fire:
		return "Only at Hearthward's fire."
	if Travel.count("grave_ash") < unremember_cost():
		return "Needs %d grave ash (you carry %d)." % [unremember_cost(), Travel.count("grave_ash")]
	return ""


## Give every Path step back (the points return; the ash does not).
func unremember(at_home_fire: bool) -> String:
	var why := why_not_unremember(at_home_fire)
	if why != "":
		return why
	_spend(unremember_cost())
	ps()["paths"] = {}
	_refresh()
	Travel.save_game()
	return ""


# --- the Hearthfire -------------------------------------------------------------------------------

func tier() -> int:
	return HearthDB.tier(hs())


## True when `fire` is Hearthward's own (the brazier on the green).
static func is_home_fire(fire: Node3D) -> bool:
	if fire == null or not is_instance_valid(fire):
		return false
	var p := fire.global_position
	return Vector2(p.x, p.z).distance_to(HearthDB.HOME) <= HearthDB.HOME_R


func why_not_raise(at_home_fire: bool) -> String:
	var t := tier()
	if t >= HearthDB.TIERS.size() - 1:
		return "The Hearthfire burns as high as it will."
	var nx: Dictionary = HearthDB.TIERS[t + 1]
	if not VState.test(String(nx.need), VState.world(get_tree())):
		return "The fire will take this once %s." % String(nx.need_text)
	if Travel.count("relic_fragment") < int(nx.frag):
		return "Needs %d relic fragment%s (you carry %d)." % [int(nx.frag), "" if int(nx.frag) == 1 else "s", Travel.count("relic_fragment")]
	if Travel.count("grave_ash") < int(nx.ash):
		return "Needs %d grave ash (you carry %d)." % [int(nx.ash), Travel.count("grave_ash")]
	if not at_home_fire:
		return "Only at Hearthward's fire, on the green."
	return ""


func raise(at_home_fire: bool) -> String:
	var why := why_not_raise(at_home_fire)
	if why != "":
		return why
	var nx: Dictionary = HearthDB.TIERS[tier() + 1]
	_spend(int(nx.ash))
	Travel.items["relic_fragment"] = maxi(0, Travel.count("relic_fragment") - int(nx.frag))
	hs()["tier"] = tier() + 1
	_sync_flags()
	_refresh()
	apply_reach()
	Travel.save_game()
	var svc: Dictionary = HearthDB.SERVICES.get(String(nx.get("opens", "")), {})
	Events.toast.emit("The Hearthfire: %s. %s" % [String(nx.name).to_upper(), String(nx.text)])
	if not svc.is_empty():
		Events.zone_entered.emit("HEARTHWARD", svc.name)
	return ""


## Village flags for the trades that are open (the talk table's choices read v:svc_*).
func _sync_flags() -> void:
	var h := hs()
	for id: String in SVC_FLAG:
		var open := HearthDB.service_open(h, id)
		if open and not VState.flag(SVC_FLAG[id]):
			VState.set_flag(SVC_FLAG[id])


func service_why(id: String) -> String:
	var s: Dictionary = HearthDB.SERVICES.get(id, {})
	if s.is_empty():
		return "?"
	if tier() < int(s.tier):
		return "Opens with the Hearthfire %s (%s)." % [["", "I", "II", "III", "IV"][int(s.tier)], String(HearthDB.TIERS[int(s.tier)].name)]
	if s.has("needs") and not VState.test(String(s.needs), VState.world(get_tree())):
		return "Waits on %s." % String(s.needs_text)
	return ""


# --- the tithe: ash given to the green's fire --------------------------------------------------------

## The village's night count (Village.nights): a night-ward lasts until it turns over.
func _night() -> int:
	var v := get_tree().root.find_child("Village", true, false) if get_tree() else null
	return int(v.get("nights")) if v else 0


func ward_active() -> bool:
	return bool(hs().get("ward", false))


## "" when the tithe `id` can be paid now, else why not.
func why_not_tithe(id: String, at_home_fire: bool) -> String:
	var t := HearthDB.tithe(id)
	if t.is_empty():
		return "?"
	if tier() < int(t.tier):
		return "The fire takes no tithe until it draws (the Hearthfire I)."
	if not at_home_fire:
		return "Only at Hearthward's fire, on the green."
	if id == "rest":
		if int(PathsDB.level_of(memory()).level) >= PathsDB.MAX_LEVEL:
			return "There is nothing left for the fire to keep."
		if LevelDB.rest_pool(ps()) <= int(ps().get("rested_xp", 0)):
			return "The fire holds all the pale stretch it can for you."
	elif ward_active():
		return "The night-ward still holds."
	if Travel.count("grave_ash") < int(t.price):
		return "Needs %d grave ash (you carry %d)." % [int(t.price), Travel.count("grave_ash")]
	return ""


func tithe(id: String, at_home_fire: bool) -> String:
	var why := why_not_tithe(id, at_home_fire)
	if why != "":
		return why
	var t := HearthDB.tithe(id)
	_spend(int(t.price))
	if id == "rest":
		ps()["rested_xp"] = LevelDB.rest_pool(ps())
		xp_changed.emit(xp_info())
		Events.toast.emit("The fire keeps the memory: rested XP, and kills pay double until it is spent.")
	else:
		var h := hs()
		h["ward"] = true
		h["ward_night"] = _night()
		Events.toast.emit("The night-ward takes: +15 Gloom held, Gloom gathers 8% slower, the Lantern Ward burns 2 s longer, until the night ends.")
	_refresh()
	Travel.save_game()
	return ""


# --- Hild's works, meals, smelting ------------------------------------------------------------------

func why_not_work(id: String) -> String:
	var w := HearthDB.work(id)
	if w.is_empty():
		return "?"
	if HearthDB.works(hs()).has(id):
		return "Done."
	var sw := service_why("smith")
	if sw != "":
		return sw
	if tier() < int(w.tier):
		return "Hild needs a hotter fire: the Hearthfire %s." % ["", "I", "II", "III", "IV"][int(w.tier)]
	if Travel.count("relic_fragment") < int(w.get("frag", 0)):
		return "Needs %d relic fragment (you carry %d)." % [int(w.frag), Travel.count("relic_fragment")]
	var mw := HearthDB.mats_why(w.get("mats", {}))          # r33 gathering
	if mw != "":
		return mw
	if Travel.count("grave_ash") < int(w.price):
		return "You need %d more grave ash." % (int(w.price) - Travel.count("grave_ash"))
	return ""


func buy_work(id: String) -> String:
	var why := why_not_work(id)
	if why != "":
		return why
	var w := HearthDB.work(id)
	_spend(int(w.price))
	_spend_mats(w.get("mats", {}))
	Travel.items["relic_fragment"] = maxi(0, Travel.count("relic_fragment") - int(w.get("frag", 0)))
	(hs().works as Dictionary)[id] = true
	_refresh()
	apply_reach()
	Travel.save_game()
	return ""


func belly() -> int:
	return HearthDB.BELLY + int(_live("belly", 0.0))


func why_not_eat(id: String) -> String:
	var m := HearthDB.meal(id)
	if m.is_empty():
		return "?"
	if String(m.who) == "bet":
		var sw := service_why("herbs")
		if sw != "":
			return sw
	var meals := HearthDB.meals(hs())
	var same: Variant = meals.get(String(m.kind))
	if same is Dictionary and String((same as Dictionary).get("id", "")) == id and float((same as Dictionary).get("left", 0.0)) > float(m.secs) * 0.25:
		return "You've had that. Wait till it wears thin."
	if not meals.has(String(m.kind)) and meals.size() >= belly():
		return "You couldn't eat another thing (%d dishes at once)." % belly()
	var mw := HearthDB.mats_why(m.get("mats", {}))          # r33 gathering
	if mw != "":
		return mw
	if Travel.count("grave_ash") < int(m.price):
		return "You need %d more grave ash." % (int(m.price) - Travel.count("grave_ash"))
	return ""


## Eat or drink `id`: replaces a dish of the same kind. Ash is taken by the caller (the shop)
## when `paid`; otherwise here.
func eat(id: String, paid := false) -> String:
	if not paid:
		var why := why_not_eat(id)
		if why != "":
			return why
		_spend(int(HearthDB.meal(id).price))
		_spend_mats(HearthDB.meal(id).get("mats", {}))
	var m := HearthDB.meal(id)
	if m.is_empty():
		return "?"
	(hs().meals as Dictionary)[String(m.kind)] = {"id": id, "left": float(m.secs)}
	_refresh()
	Travel.save_soon()
	return ""


## Ember shards (the equipment system's metal) for ash, at Hild's forge. "" or why not.
func why_not_smelt() -> String:
	var sw := service_why("smith")
	if sw != "":
		return sw
	if not shards_supported():
		return "Hild has nothing to smelt it into yet."
	if Travel.count("grave_ash") < int(HearthDB.SMELT.ash):
		return "You need %d grave ash." % int(HearthDB.SMELT.ash)
	return ""


## The equipment system (core/items/gear_runtime.gd) spends "ember_shard" from Travel's items.
static func shards_supported() -> bool:
	return ItemDB.DEFS.has("ember_shard") or ResourceLoader.exists("res://core/items/gear_runtime.gd")


static func give_shards(n: int) -> void:
	Travel.give("ember_shard", n)


# --- r33 gathering trades (HearthDB.TRADES; the shop shows them through village_shop.gd's hook) -----

func why_not_trade(id: String) -> String:
	var t := HearthDB.trade(id)
	if t.is_empty():
		return "?"
	var sw := service_why(String(t.get("service", "")))
	if sw != "" and String(t.get("service", "")) != "":
		return sw
	var mw := HearthDB.mats_why(t.get("mats", {}))
	if mw != "":
		return mw
	if Travel.count("grave_ash") < int(t.price):
		return "You need %d more grave ash." % (int(t.price) - Travel.count("grave_ash"))
	return ""


func trade(id: String) -> String:
	var why := why_not_trade(id)
	if why != "":
		return why
	var t := HearthDB.trade(id)
	_spend(int(t.price))
	_spend_mats(t.get("mats", {}))
	var gives: Dictionary = t.get("gives", {})
	for g: String in gives:
		Travel.give(g, int(gives[g]), false)
	Travel.save_soon()
	return ""


## Shop rows for `who`'s gathering trades (shaped like village_shop.gd's hearth rows).
func trade_rows(who: String) -> Array:
	var out: Array = []
	for t: Dictionary in HearthDB.TRADES:
		if String(t.who) != who:
			continue
		var why := why_not_trade(String(t.id))
		out.append({"id": "trade:" + String(t.id), "name": String(t.name), "text": String(t.text), "price": int(t.price),
			"glyph": String(t.glyph), "left": -1, "group": "Gathered goods", "sub": "as often as you like",
			"ok": why == "", "why": why, "hearth": true})
	return out


func _spend_mats(mats: Dictionary) -> void:
	for id: String in mats:
		var n := int(mats[id])
		Travel.items[id] = maxi(0, Travel.count(id) - n)
		if Travel.count(id) <= 0:
			Travel.items.erase(id)
		Events.item_gained.emit(id, -n, Travel.count(id))


func smelt() -> String:
	var why := why_not_smelt()
	if why != "":
		return why
	_spend(int(HearthDB.SMELT.ash))
	give_shards(int(HearthDB.SMELT.shards))
	return ""


# --- Brannoc's bells: walking between fires ----------------------------------------------------------

## Kindled fires the wanderer can walk to from `from` (lit braziers in the tree, but not `from`).
func walk_targets(from: Node3D) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for n in get_tree().get_nodes_in_group(Groups.BRAZIER):
		var b := n as Node3D
		if b == null or b == from or not bool(b.get("lit")) or not b.is_inside_tree():
			continue
		out.append(b)
	out.sort_custom(func(a: Node3D, c: Node3D) -> bool: return fire_name(a) < fire_name(c))
	return out


static func fire_name(b: Node3D) -> String:
	if b == null:
		return "?"
	if Vector2(b.global_position.x, b.global_position.z).distance_to(HearthDB.HOME) <= HearthDB.HOME_R:
		return "Hearthward's fire"
	var named: String = {"StairFoot": "The meadow fire", "Shrine": "The glade's fire", "Landing": "The Barrow Field fire",
		"Threshold": "The fen fire", "HengeFire": "The henge fire", "SummitFire": "The summit fire"}.get(String(b.name), "")
	return named if named != "" else "A fire (%s)" % String(b.name).capitalize()


func why_not_walk(from: Node3D, to: Node3D) -> String:
	if not service_open(hs(), "bells"):
		return service_why("bells")
	if from == null or not is_instance_valid(from):
		return "Ring the bell at a kindled fire."
	if not HearthDB.works(hs()).has("bells"):
		return "Brannoc's bells are not hung yet."
	if to == null or not is_instance_valid(to) or not bool(to.get("lit")):
		return "That fire is out."
	return ""


static func service_open(h: Dictionary, id: String) -> bool:
	return HearthDB.service_open(h, id)


## Hang Brannoc's bells (once, at the Hearthfire III).
const BELLS_PRICE := 24


func why_not_bells() -> String:
	if HearthDB.works(hs()).has("bells"):
		return "Hung."
	var sw := service_why("bells")
	if sw != "":
		return sw
	if Travel.count("grave_ash") < BELLS_PRICE:
		return "Needs %d grave ash (you carry %d)." % [BELLS_PRICE, Travel.count("grave_ash")]
	return ""


func hang_bells() -> String:
	var why := why_not_bells()
	if why != "":
		return why
	_spend(BELLS_PRICE)
	(hs().works as Dictionary)["bells"] = true
	Travel.save_game()
	Events.toast.emit("Brannoc's hand-bells hang at every kindled fire. Ring one to walk to another.")
	return ""


func walk(from: Node3D, to: Node3D) -> String:
	var why := why_not_walk(from, to)
	if why != "":
		return why
	var p := _player()
	if p == null:
		return "?"
	var at: Vector3 = to.call("spawn_point") if to.has_method("spawn_point") else to.global_position + Vector3(0, 0.3, 1.8)
	Vfx.burst(p.global_position + Vector3.UP, Color(2.6, 1.2, 0.4), {"count": 40, "life": 0.8, "speed": Vector2(1.0, 3.0), "size": 0.05, "gravity": -2.0})
	if p.has_method("teleport"):
		p.call("teleport", at)
	else:
		p.global_position = at
	if to.has_method("remember"):
		to.call("remember", p)
	Vfx.burst(at + Vector3.UP, Color(2.6, 1.2, 0.4), {"count": 50, "life": 0.9, "speed": Vector2(1.0, 3.5), "size": 0.05, "gravity": -2.0})
	Sfx.play("res://art/audio/ward_chime.wav", at, -2.0, 0.7)
	Events.toast.emit("A bell answers at %s." % fire_name(to).to_lower())
	return ""


# --- events -------------------------------------------------------------------------------------------

func _on_killed(e: Node) -> void:
	var src := GearRuntime.source_of(e if is_instance_valid(e) else null)   # r33: XP by the foe
	if src != "boss":
		give_memory(LevelDB.xp_for(src), src)
	if float(_live("glean", 0.0)) <= 0.0 or not (e is Node3D):
		return
	var h := hs()
	h["gleaned"] = int(h.get("gleaned", 0)) + 1
	if int(h.gleaned) % 5 == 0:
		Travel.give("grave_ash", 1, false)


func _on_item(id: String, amount: int, _total: int) -> void:
	if amount <= 0:
		return
	var kind := String(ItemDB.def(id).get("kind", ""))
	if kind in ["charm", "core", "relic", "trophy"]:
		give_memory(LevelDB.xp_for("keepsake"), "keepsake")


## r33: discovery XP, the first time a place's banner shows (by its title).
func _on_zone(title: String, _sub: String) -> void:
	if title == "":
		return
	var p := ps()
	if not (p.get("seen") is Dictionary):
		p["seen"] = {}
	var seen: Dictionary = p.seen
	if seen.has(title):
		return
	seen[title] = true
	give_memory(LevelDB.xp_for("discover"), "discover")


func _spend(n: int) -> void:
	Travel.items["grave_ash"] = maxi(0, Travel.count("grave_ash") - n)



static func _live(key: String, d: float) -> float:
	return float(DB.live.get(key, d))
