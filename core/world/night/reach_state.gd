extends Node
## r36 the night progresses (docs/critique/r36_plan.md, step 6): one place that reads what the
## wanderer has done and changes the Realm to match. Built with the watch (realm only); refreshes on
## every quest change, kill of a great one and seal, never per frame.
##   act       1 before both seals' bosses fall, 2 while the peal is gathered, 3 once it is answered
##             (Brannoc's task done), 4 after the Warden. The dark presses harder from act to act:
##             roaming events come sooner and stronger, watch assaults are bigger (pressure()).
##   quiet     a far country whose bell was rung where it hung: its camps come back three times
##             slower, and the bell stands lit on its frame (a mirror light: no rest, but the
##             hollowed keep off it), a place to breathe
##   factions  the Rooted (the Holds, the Thornwood), the Kindlers (Hearthward, the Orchard, the
##             chapel) and the road folk (the moor, the mere, the pits, the quarry). Standing comes
##             from tasks done in their country and bells answered for them; at FRIEND it brings one
##             gift, at KIN their country's camps come back twice as slow and their watch-posts'
##             men stand longer. Each change is announced once.
##   state: Travel.system_state("reach") = {announced: {key: true}}

const Chains := preload("res://core/story/quest_chains.gd")
const Book := preload("res://core/story/quest_book.gd")
const QProps := preload("res://core/story/quest_props.gd")

const FACTIONS := {
	"rooted": {"name": "the Rooted", "zones": ["holds", "thornwood"], "bells": ["bell_holds"],
		"gift": {"relic_fragment": 3, "ash_bloom": 4}, "friend": "The Rooted leave a bundle by the next fire you light: bark-wrapped, tied with a knot you know now.",
		"kin": "The Rooted call you kin. Their dead lie quieter where you walk."},
	"kindlers": {"name": "the Kindlers", "zones": ["hearth", "orchard", "road"], "bells": ["bell_orchard"],
		"gift": {"ember_shard": 4, "grave_ash": 20}, "friend": "Someone has left coals and ash in your satchel. The Kindlers' way of saying it.",
		"kin": "The Kindlers count you one of theirs. Their fires burn a little higher when you pass."},
	"road": {"name": "the road folk", "zones": ["moor", "mere", "foundry", "quarry"], "bells": ["bell_moor", "bell_mere", "bell_foundry", "bell_quarry"],
		"gift": {"grave_iron": 3, "relic_fragment": 2}, "friend": "The road folk know your face. Ysolt sends iron; Cadoc sends nothing, and says so.",
		"kin": "On the moor and the mere they keep a place at the fire for you now."},
}
const FRIEND := 6
const KIN := 12
## the far countries (RealmLayout region ids) each bell answers for
const BELL_REGION := {"bell_holds": "holds", "bell_quarry": "quarry", "bell_moor": "moor", "bell_foundry": "foundry",
	"bell_orchard": "orchard", "bell_necropolis": "necropolis", "bell_mere": "mere"}
const FACTION_REGIONS := {"rooted": ["holds", "thornwood"], "kindlers": ["hearth", "orchard"], "road": ["moor", "mere", "foundry", "quarry"]}

var _lit := {}                   ## bell quest id -> the standing bell node


func _ready() -> void:
	add_to_group(&"reach_state")
	Events.quest_changed.connect(func(_id: String, _s: int, _d: bool) -> void: refresh.call_deferred())
	Events.boss_slain.connect(func(_id: String) -> void: refresh.call_deferred())
	refresh.call_deferred()


static func act() -> int:
	if Book.done("names_under"):
		return 5
	if Travel.bosses_slain.has("ascended_warden"):
		return 4
	if Book.done("founders_peal"):
		return 3
	if Travel.bosses_slain.has("thornwarden") and Travel.bosses_slain.has("bone_abbot"):
		return 2
	return 1


## How hard the dark presses: 1.0 in act 1, more after.
static func pressure() -> float:
	var a := act()
	if a == 5:
		# Act III's end: a latched door quiets the dark; one left on the latch keeps the roads busy
		return {"latched": 0.6, "broken": 0.8}.get(Book.pick("the_latch"), 1.0)
	return [1.0, 1.0, 1.3, 1.5, 1.2][a]


## r36 Act III: the door left on the latch: the ones above come home (roam_events favours the
## living pilgrim, who now walks down the road rather than up).
static func homecoming() -> bool:
	return Book.pick("the_latch") == "open"


static func quiet(region: String) -> bool:
	for b: String in BELL_REGION:
		if String(BELL_REGION[b]) == region and Book.pick(b) == "rung":
			return true
	return false


static func standing(f: String) -> int:
	var d: Dictionary = FACTIONS.get(f, {})
	var n := 0
	for id: String in Chains.QUESTS:
		if Book.done(id) and (d.zones as Array).has(String(Chains.QUESTS[id].get("zone", ""))):
			n += 2
	for b: String in d.get("bells", []):
		match Book.pick(b):
			"rung":
				n += 3
			"carried":
				n += 1
	if f == "kindlers":
		n += Book.bells_carried()          # every tongue hung at the Keg is Hearthward's
	return n


static func tier(f: String) -> int:
	var s := standing(f)
	return 2 if s >= KIN else (1 if s >= FRIEND else 0)


## What a camp's respawn waits, as a multiple (EnemySpawner._respawn_delay): quiet x3, kin x2.
static func respawn_mult(at: Vector3) -> float:
	var region := String(RealmLayout.region_at(at.x, at.z).get("id", ""))
	if region == "":
		return 1.0
	var m := 1.0
	if quiet(region):
		m *= 3.0
	for f: String in FACTION_REGIONS:
		if (FACTION_REGIONS[f] as Array).has(region) and tier(f) >= 2:
			m *= 2.0
	return m


## A watch-post's men stand longer in a kin country (watch.gd).
static func watch_hp_mult(at: Vector3) -> float:
	var region := String(RealmLayout.region_at(at.x, at.z).get("id", ""))
	for f: String in FACTION_REGIONS:
		if (FACTION_REGIONS[f] as Array).has(region) and tier(f) >= 2:
			return 1.5
	return 1.0


func refresh() -> void:
	if not is_inside_tree():
		return
	var st := Travel.system_state("reach")
	if not (st.get("announced") is Dictionary):
		st["announced"] = {}
	var ann: Dictionary = st.announced
	# acts
	var a := act()
	var akey := "act_%d" % a
	if a >= 2 and not ann.has(akey):
		ann[akey] = true
		Events.toast.emit(String({2: "The dark knows two of its keepers are gone. It comes looking.",
			3: "Bells ring in the far countries. Up at the summit, something listens.",
			4: "The sky has stopped turning. The dark is slower now, and sullen.",
			5: {"latched": "The door is latched. The dark in the valley has nothing behind it now; it thins.",
				"broken": "No door. The valley's dark is only night now, and night ends.",
				}.get(Book.pick("the_latch"), "Lights on the road at night: people coming down from the Stair. Some of them alive.")}.get(a, "")))
	# bells rung where they hung: the bell stands lit
	for b: String in BELL_REGION:
		if Book.pick(b) == "rung" and not _lit.has(b):
			_light_bell(b)
			var qkey := "quiet_" + b
			if not ann.has(qkey):
				ann[qkey] = true
				Events.toast.emit("%s is quieter now. The bell stands lit." % _region_name(String(BELL_REGION[b])))
	# factions
	for f: String in FACTIONS:
		var t := tier(f)
		var d: Dictionary = FACTIONS[f]
		if t >= 1 and not ann.has(f + "_friend"):
			ann[f + "_friend"] = true
			for item: String in d.gift:
				Travel.give(item, int(d.gift[item]), false)
			Events.toast.emit(String(d.friend))
		if t >= 2 and not ann.has(f + "_kin"):
			ann[f + "_kin"] = true
			Events.toast.emit(String(d.kin))
	Travel.save_soon()


## The bell left where it hung: its frame on the ground at the bell's place, a lantern under it, and
## a mirror light (no rest, no checkpoint; the hollowed keep off it).
func _light_bell(b: String) -> void:
	var keys := Chains.gather_keys(b, 1)
	if keys.is_empty():
		return
	var near: Vector2 = Chains.PICKUPS[keys[0]].near
	var space := (get_parent() as Node3D).get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(near.x, 90.0, near.y), Vector3(near.x, -40.0, near.y), Layers.WORLD))
	if hit.is_empty():
		return
	var at: Vector3 = hit.position
	var n := Node3D.new()
	n.name = "RungBell_" + b
	get_parent().add_child(n)
	n.global_position = at
	QProps.make(n, "Bell", "bell", Transform3D(Basis(Vector3.UP, float(hash(b) % 628) * 0.01), at))
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.72, 0.4)
	l.light_energy = 1.2
	l.omni_range = 6.5
	l.shadow_enabled = false
	l.distance_fade_enabled = true
	l.distance_fade_begin = 60.0
	l.distance_fade_length = 15.0
	l.position = Vector3.UP * 0.9
	n.add_child(l)
	LightGrid.register(n, 5.0, LightGrid.MIRROR)
	n.set_meta(&"map_kind", "travel")
	n.set_meta(&"map_label", "A rung bell")
	n.add_to_group("map_marker")
	_lit[b] = n


static func _region_name(id: String) -> String:
	for r: Dictionary in RealmLayout.REGIONS:
		if String(r.id) == id:
			return String(r.name)
	return "The country"


func info() -> Dictionary:
	var f := {}
	for k: String in FACTIONS:
		f[k] = [standing(k), tier(k)]
	return {"act": act(), "factions": f, "lit": _lit.keys()}
