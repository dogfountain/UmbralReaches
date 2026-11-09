extends Node3D
## The tasks' world side (story; no class_name). Added by the village director (village.gd) once
## its people stand; "Quests" in group "quests". From quest_book.gd's state it keeps the world true:
##   - pickups (quest_pickup.gd) for the step that wants them: Edda's tongs, the name-slates, the
##     Keg's mugs, Father Harrow's lantern; taking one reads it out (subtitles) and moves the task on
##   - Oswin's walk to the forty-first waystone (head of the rim road): he follows the wanderer (villager.gd `follow`) off
##     the walking network, waits when left behind, kneels at the stone; after the choice he keeps a
##     vigil there for good, or takes the west road and is gone
##   - Father Harrow: a hollowed man who wakes over his lantern in the fen and falls on step 1
##   - outcomes left standing in the village: the tongs at the forge or back on Edda's stone, three
##     carved names in the Kindlers' Yard, a mug of ale by the green's fire, the lantern on the
##     Keg's bar (lit if Ostrin was told the truth), Oswin's staff on the west road
## Spots are floor points found near the data's xz at load (prepare(), clear and dry), so nothing
## floats or sinks. Ticks at 4 Hz (one distance check per live piece).
## Load by path: const QuestWorld := preload("res://core/story/quest_world.gd")

const Book := preload("res://core/story/quest_book.gd")
const Chains := preload("res://core/story/quest_chains.gd")
const QProps := preload("res://core/story/quest_props.gd")
const Pickup := preload("res://core/story/quest_pickup.gd")
const RealmLayout := preload("res://core/world/realm/realm_layout.gd")

## Found floor points: pickup key / "stair" / "names" / "staff" -> Vector3 (tests read them).
static var spots := {}
static var report: Array[String] = []

var village: Node3D
var pickups := {}                 ## key -> pickup node
var props := {}                   ## outcome id -> holder
var hollow: Node3D                ## Father Harrow while he stands
var _tick := 0.0
var _leaving: Node3D              ## Oswin taking the west road
var _leave_t := 0.0


# --- before the people spawn ------------------------------------------------------------------------

## Find the floor spots and add the stair's foot to the walking network (as a lone node: Oswin is
## placed there, never routed).
static func prepare(v: Node3D) -> void:
	spots.clear()
	report.clear()
	var nav: RefCounted = v.get("nav")
	for k: String in Chains.PICKUPS:
		var near: Vector2 = Chains.PICKUPS[k].near
		# r34: a coal or lamp taken from a giver's outpost fire is found beside that fire
		var camp := String(Chains.PICKUPS[k].get("camp", ""))
		if camp != "" and v.has_method("anchor"):
			var f: Vector3 = v.call("anchor", "@fire_" + camp)
			if f != Vector3.INF:
				near = Vector2(f.x + 0.9, f.z - 0.9)
		spots[k] = _spot(nav, near)
	spots["stair"] = _spot(nav, Chains.ESCORT.to)
	spots["hollow"] = spots.get("lantern", Vector3.INF)
	spots["names"] = _spot(nav, Vector2(-82.3, 44.6), 0.5)
	spots["waystone"] = _spot(nav, Chains.ESCORT.stone)
	spots["staff"] = _spot(nav, Vector2(-22.4, 52.0))
	for k2: String in spots:
		if spots[k2] == Vector3.INF:
			report.append("no floor for %s" % k2)
	if spots.stair != Vector3.INF:
		(nav.get("nodes") as Dictionary)["q_stair"] = spots.stair


static func _spot(nav: RefCounted, near: Vector2, r := 0.3) -> Vector3:
	for ring: float in [0.0, 0.5, 1.0, 1.6, 2.4, 3.4, 4.6, 6.0]:
		var n := 1 if ring == 0.0 else 12
		for i in n:
			var a := TAU * float(i) / float(n)
			var x := near.x + cos(a) * ring
			var z := near.y + sin(a) * ring
			var p: Vector3 = nav.call("ok_at", x, z)
			if p == Vector3.INF:
				continue
			# on the floor people walk on, not on top of a tomb or a wall
			var walk_y: float = RealmLayout.ground(nav.get("_space"), x, z)
			# (a plinth standing in the shallows is the floor there: the ground under it is the river bed)
			var wl := RealmLayout.water_level_at(x, z)
			if p.y - walk_y > 0.6 and (is_nan(wl) or walk_y >= wl):
				continue
			if r > 0.35:
				var ok := true
				for j in 4:
					var q: Vector3 = nav.call("ok_at", x + cos(TAU * float(j) / 4.0) * r, z + sin(TAU * float(j) / 4.0) * r)
					if q == Vector3.INF or absf(q.y - p.y) > 0.25:
						ok = false
						break
				if not ok:
					continue
			return p
	return Vector3.INF


## The villager data to spawn with after the tasks' outcomes ({} = not here any more).
static func override(id: String, d: Dictionary) -> Dictionary:
	if id == "oswin" and Book.done("forty_first"):
		if Book.pick("forty_first") == "truth":
			return {}
		return vigil(d)
	return d


## Oswin keeping his vigil at the forty-first stone (he chose to go on believing).
static func vigil(d: Dictionary) -> Dictionary:
	var o := d.duplicate(true)
	var stone: Vector2 = Chains.ESCORT.stone
	o["home"] = "q_stair"
	o["fearless"] = true
	o["schedule"] = {"dusk": "vigil", "work": "vigil", "midnight": "vigil", "late": "vigil"}
	o["routines"] = {"vigil": [
		{"act": "kneel", "at": "q_stair", "face": stone, "t": [40.0, 60.0]},
		{"act": "look_up", "at": "q_stair", "face": Vector2(0.0, -95.0), "t": [8.0, 12.0]},
		{"act": "sit", "at": "q_stair", "face": stone, "t": [30.0, 50.0], "seat": 0.0},
	]}
	return o


# --- runtime -----------------------------------------------------------------------------------------

func _ready() -> void:
	add_to_group("quests")
	# the forty-first waystone stands whether or not anybody walks Oswin to it
	var ws: Vector3 = spots.get("waystone", Vector3.INF)
	if ws != Vector3.INF:
		var st: Vector3 = spots.get("stair", ws)
		var yaw := atan2(-(st.x - ws.x), -(st.z - ws.z))
		QProps.make(self, "Waystone41", "waystone", Transform3D(Basis(Vector3.UP, yaw), ws))
	Events.quest_changed.connect(func(_id: String, _s: int, _d: bool) -> void: sync.call_deferred())
	Events.enemy_killed.connect(_on_killed)
	sync()


func _exit_tree() -> void:
	if is_instance_valid(hollow):
		hollow.queue_free()


func _villager(id: String) -> Node3D:
	return (village.get("villagers") as Dictionary).get(id) if village else null


func _player() -> Node3D:
	return get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D


## Bring the world in line with the tasks' state (pickups, Oswin, outcome props).
func sync() -> void:
	if not is_inside_tree():
		return
	# pickups wanted now
	var want := {}
	for k: String in Chains.PICKUPS:
		var p: Dictionary = Chains.PICKUPS[k]
		var qid := String(p.quest)
		if not Book.active(qid) or spots.get(k, Vector3.INF) == Vector3.INF:
			continue
		var s := Book.step(qid)
		if s == int(p.step) and not Book.found(qid).has(k):
			want[k] = true
		elif k == "lantern" and s < int(p.step):
			want[k] = false          # shown, not yet takeable: he stands over it
	for k2: String in pickups.keys():
		if not want.has(k2):
			if String(Chains.PICKUPS[k2].kind) == "bell":
				_bell_taken[k2] = true            # the choice was just made here: its outcome prop swings once
			(pickups[k2] as Node).queue_free()
			pickups.erase(k2)
	for k3: String in want:
		if not pickups.has(k3):
			_add_pickup(k3)
		(pickups[k3] as Node).set("live", bool(want[k3]))
	_sync_oswin()
	_sync_props()


var _bell_taken := {}              ## bell pickup key -> true: it was answered this session


func _add_pickup(k: String) -> void:
	var d: Dictionary = Chains.PICKUPS[k]
	var p: Node3D = Pickup.new()
	p.name = "Pickup_" + k
	p.set("key", k)
	p.set("world", self)
	p.set("label", String(d.name))
	p.set("verb", String(d.verb))
	add_child(p)
	var at: Vector3 = spots[k]
	if at == Vector3.INF:
		# nav never found a floor: still stand the thing on the designed land, not at y=0 in the void
		var near: Vector2 = d.near
		at = Vector3(near.x, RealmLayout.macro_height(near.x, near.y), near.y)
		spots[k] = at
	p.global_position = at
	var yaw := float(hash(k) % 628) * 0.01
	QProps.make(p, "Look", String(d.kind), Transform3D(Basis(Vector3.UP, yaw), at))
	QProps.glint(p, String(d.kind) != "slate")
	# r33: the minimap's quest pin (ui/minimap.gd draws group "map_marker")
	p.add_to_group("map_marker")
	p.set_meta("map_kind", "quest_target")
	p.set_meta("map_label", "%s: %s" % [String(Chains.QUESTS[d.quest].name), String(d.name)])
	pickups[k] = p


## The wanderer used a pickup: read it out, move the task on.
func take(k: String) -> void:
	var d: Dictionary = Chains.PICKUPS.get(k, {})
	if d.is_empty():
		return
	var qid := String(d.quest)
	if not Book.active(qid) or Book.step(qid) != int(d.step):
		return
	# r36: a pickup with a conversation (the Founder's bells) asks what to do; the conversation's
	# choice records it and moves the task on (qp: / qa:), so nothing advances here
	if d.has("conv"):
		var story := get_tree().get_first_node_in_group("story")
		if story and story.has_method("talk"):
			story.call("talk", String(d.conv), null, _player())
		return
	_narrate(String(d.say))
	var st: Dictionary = (Chains.QUESTS[qid].steps as Array)[int(d.step)]
	match String(st.kind):
		"gather":
			var n := Book.find(qid, k)
			if n >= int(st.get("of", 1)):
				Book.advance(qid)
			else:
				Book._toast("%d of %d found." % [n, int(st.get("of", 1))])
		"place":
			if qid == "edda_tongs":
				Book.add_att("abel", 2)
				Book.add_att("hild", 1)
				Book.grant({"items": {"relic_fragment": 1}})
			Book.advance(qid)
		_:
			Book.advance(qid)
	sync()


func _narrate(s: String) -> void:
	var story := get_tree().get_first_node_in_group("story")
	var ui: Variant = story.get("ui") if story else null
	if ui and is_instance_valid(ui):
		(ui as Object).call("narrate", [s])


# --- Oswin's walk -------------------------------------------------------------------------------------

func _sync_oswin() -> void:
	var o := _villager("oswin")
	if o == null:
		return
	var s := Book.step("forty_first")
	if Book.active("forty_first") and s == 0:
		if o.get("follow") == null:
			o.call("release")
			o.set("follow", _player())
			o.set("pinned", true)
	elif Book.active("forty_first") and s == 1:
		# one point, the stone: he walks to it, and kneels with his hands on it (process() decides when)
		if not (bool(o.get("pinned")) and String(o.get("act")) == "kneel") and not (o.get("follow") is Vector3):
			o.call("release")
			o.set("pinned", true)
			o.set("follow", _stone3())
	elif not Book.started("forty_first") and (o.get("follow") != null or bool(o.get("pinned"))):
		# the walk was set aside (or a reload lost it): back to his own night from wherever he stands
		o.call("release")
		if village and village.has_method("routine_for"):
			o.call("begin", String(village.call("routine_for", "oswin")))
	elif Book.done("forty_first") and o != _leaving:
		var vig := Book.pick("forty_first") != "truth"
		if vig and String(o.get("routine")) != "vigil":
			o.call("release")
			o.set("data", vigil(o.get("data")))
			o.set("at_node", "q_stair")
			o.call("begin", "vigil", true)          # place at the stone: he was already kneeling there
		elif not vig:
			# he takes the west road, and is gone
			o.call("release")
			o.set("pinned", true)
			var away := (o.global_position + Vector3(-1.0, 0.0, 0.35).normalized() * 30.0)
			o.set("follow", away)
			_leaving = o
			_leave_t = 0.0


const KNEEL_R := 0.8          ## m from the stone (xz) at which Oswin kneels
const KNEEL_STUCK_S := 3.0    ## or after this long without closing on it
var _esc_best := INF
var _esc_stuck := 0.0
var _esc_waited := false


## One line, his, when he has stopped because you ran ahead; he walks on when you are back inside the wait radius.
func _oswin_waits(o: Node3D) -> void:
	var w := bool(o.get("waiting"))
	if w and not _esc_waited:
		_esc_waited = true
		_narrate("Oswin stops on the road. \"I will wait here. Go on, I will keep.\"")
	elif not w:
		_esc_waited = false


func _stone3() -> Vector3:
	var w: Vector3 = spots.get("waystone", Vector3.INF)
	if w != Vector3.INF:
		return w + Vector3.UP * 0.5
	var s: Vector2 = Chains.ESCORT.stone
	return Vector3(s.x, spots.get("stair", Vector3.ZERO).y, s.y)


func _process(delta: float) -> void:
	if _leaving and is_instance_valid(_leaving):
		_leave_t += delta
		var cam := get_viewport().get_camera_3d()
		var seen := cam != null and cam.is_position_in_frustum(_leaving.global_position + Vector3.UP) and cam.global_position.distance_to(_leaving.global_position) < 40.0
		if _leave_t > 26.0 or (_leave_t > 8.0 and not seen):
			(village.get("villagers") as Dictionary).erase("oswin")
			_leaving.queue_free()
			_leaving = null
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.25
	var pl := _player()
	if pl == null:
		return
	# the escort arrives
	var stone := _stone3()
	if Book.active("forty_first") and Book.step("forty_first") == 0:
		var o := _villager("oswin")
		if o and spots.get("stair", Vector3.INF) != Vector3.INF and Vector2(o.global_position.x - stone.x, o.global_position.z - stone.z).length() < float(Chains.ESCORT.reach):
			Book.advance("forty_first")
			_narrate("Oswin stops at the stone. He touches it with both hands. \"Forty-one.\"")
		elif o:
			_oswin_waits(o)
	elif Book.active("forty_first") and Book.step("forty_first") == 1:
		var o2 := _villager("oswin")
		if o2 and o2.get("follow") is Vector3:
			# he kneels once he has closed to the stone, or has been stuck against it (a wall in the last step)
			var d2 := Vector2(o2.global_position.x - stone.x, o2.global_position.z - stone.z).length()
			if d2 < KNEEL_R or _esc_stuck >= KNEEL_STUCK_S:
				o2.call("hold", "kneel", stone)
				_esc_stuck = 0.0
				_esc_best = INF
			else:
				if d2 < _esc_best - 0.15:
					_esc_best = d2
					_esc_stuck = 0.0
				else:
					_esc_stuck += 0.25
	# Father Harrow stands over his lantern where a gallop can see him; he wakes (the step, his name) at `wake`
	if Book.active("slow_way") and Book.step("slow_way") <= 1:
		var at: Vector3 = spots.get("hollow", Vector3.INF)
		if at != Vector3.INF:
			var d := pl.global_position.distance_to(at)
			var s := Book.step("slow_way")
			if d > HOLLOW_STAND_R + 20.0:
				_hollow_failed = false
			if not is_instance_valid(hollow) and d < HOLLOW_STAND_R and not _hollow_failed:
				if not _wake_hollow(at):
					# the step stays where it is: the objective is still the man, not the lantern
					_hollow_failed = true
					_narrate("The reeds would not give him up.")
			if s == 0 and is_instance_valid(hollow) and d < float(Chains.HOLLOW.wake):
				Book.advance("slow_way")
				# one voice: his name is the banner; the narrator says it only when there is no banner to carry it
				var lg := get_tree().get_first_node_in_group("quest_log")
				if lg and lg.has_method("banner"):
					lg.call("banner", "IN THE REEDS", String(Chains.HOLLOW.title), "Ostrin's father. His face is a hole. Put him to rest.")
				else:
					_narrate("A man stands over a cold lantern in the reeds. He turns. His face is a hole.")


const HOLLOW_STAND_R := 70.0   ## the body stands this far out, in view on a gallop; it wakes at Chains.HOLLOW.wake
var _hollow_failed := false


func _wake_hollow(at: Vector3) -> bool:
	# by path, not by class name: the enemy scripts change under other hands; a broken one must not
	# take the village down with it
	var scr := load("res://core/enemy/husk.gd") as GDScript
	if scr == null or not scr.can_instantiate():
		push_warning("QuestWorld: husk.gd unavailable; Father Harrow cannot wake")
		return false
	var e: Node3D = scr.new()
	e.name = "FatherHarrow"
	e.set("max_hp", int(Chains.HOLLOW.hp))
	e.set_meta("quest", "slow_way")
	var host := village.get_parent() if village else get_parent()
	host.add_child(e)
	var off := Vector3(1.2, 0.0, 0.8)
	if e.has_method("station"):
		e.call("station", at + off)
	else:
		e.global_position = at + off + Vector3.UP * 0.05
	hollow = e
	return true


func _on_killed(e: Node) -> void:
	if e == hollow and e != null:
		hollow = null
		if Book.active("slow_way") and Book.step("slow_way") == 1:
			Book.advance("slow_way")
			_narrate("He lies down in the reeds as if he had only been waiting to be told.")


# --- outcomes -----------------------------------------------------------------------------------------

func _sync_props() -> void:
	var want := {}
	if Book.done("edda_tongs"):
		want["tongs"] = "stone" if Book.pick("edda_tongs") == "stone" else "forge"
	if Book.done("names_yard"):
		want["names"] = "names"
	if Book.done("keg_thief"):
		want["mug"] = "mug"
	if Book.done("slow_way"):
		want["lantern"] = "lit" if Book.pick("slow_way") == "truth" else "cold"
	if Book.done("forty_first") and Book.pick("forty_first") == "truth":
		want["staff"] = "staff"
	# the Founder's bells stay where they hang: rung (tongue still in) or carried (the loop empty)
	for bk: String in Chains.PICKUPS:
		var bd: Dictionary = Chains.PICKUPS[bk]
		if String(bd.kind) == "bell" and Book.started(String(bd.quest)) and not pickups.has(bk) and Book.pick(String(bd.quest)) in ["rung", "carried"]:
			want["bell:" + bk] = Book.pick(String(bd.quest))
	if Book.done("alms_loaf"):
		want["loaf"] = "loaf"
	if Book.done("ring_heart"):
		want["thorn"] = "thorn"
	for id: String in props.keys():
		if not want.has(id) or String((props[id] as Node).get_meta("v", "")) != String(want[id]):
			(props[id] as Node).queue_free()
			props.erase(id)
	for id2: String in want:
		if props.has(id2):
			continue
		var xf: Variant = _prop_xf(id2, String(want[id2]))
		if xf == null:
			continue
		if id2.begins_with("bell:"):
			var bkey := id2.trim_prefix("bell:")
			var bat: Vector3 = spots.get(bkey, Vector3.INF)
			if bat == Vector3.INF:
				continue
			var bh := QProps.make(self, "Outcome_" + bkey, "bell" if want[id2] == "rung" else "bell_bare", Transform3D(Basis(Vector3.UP, float(hash(bkey) % 628) * 0.01), bat))
			bh.set_meta("v", String(want[id2]))
			props[id2] = bh
			if want[id2] == "rung" and _bell_taken.has(bkey):
				QProps.ring_bell(bh, 1.0)            # rung on the choice, once, where you are looking
			_bell_taken.erase(bkey)
			continue
		var kind: String = {"tongs": "tongs", "names": "slabs", "mug": "mug_full", "staff": "staff", "loaf": "loaf_circle", "thorn": "thorn"}.get(id2, "lantern_lit" if want[id2] == "lit" else "lantern")
		var h := QProps.make(self, "Outcome_" + id2, kind, xf as Transform3D)
		h.set_meta("v", String(want[id2]))
		props[id2] = h


func _prop_xf(id: String, v: String) -> Variant:
	match id:
		"tongs":
			if v == "stone":
				var p: Vector3 = spots.get("tongs", Vector3.INF)
				return null if p == Vector3.INF else Transform3D(Basis(Vector3.UP, 0.7), p)
			var an: Vector3 = village.call("anchor", "@anvil") if village else Vector3.INF
			if an == Vector3.INF:
				return null
			# hung up by the anvil's foot, where Hild can reach them
			return Transform3D(Basis(Vector3.UP, 1.2), Vector3(an.x + 0.55, an.y - 0.86, an.z + 0.42))
		"names":
			var p2: Vector3 = spots.get("names", Vector3.INF)
			return null if p2 == Vector3.INF else Transform3D(Basis(Vector3.UP, -0.3), p2)
		"mug":
			var p3: Vector3 = spots.get("mug_fire", Vector3.INF)
			return null if p3 == Vector3.INF else Transform3D(Basis.IDENTITY, p3)
		"loaf":
			# beside the mug, inside its own chalk circle
			var pl2: Vector3 = spots.get("mug_fire", Vector3.INF)
			return null if pl2 == Vector3.INF else Transform3D(Basis(Vector3.UP, 0.2), pl2 + Vector3(0.9, 0.0, -0.3))
		"thorn":
			# by Wyck's fire: wherever he stands in the Thornwood, a pace to the side
			var wy := _villager("wyck")
			if wy == null:
				return null
			return Transform3D(Basis(Vector3.UP, 0.5), wy.global_position + Vector3(0.9, 0.0, 0.4))
		"staff":
			var p4: Vector3 = spots.get("staff", Vector3.INF)
			return null if p4 == Vector3.INF else Transform3D(Basis(Vector3.UP, 0.4), p4)
		"lantern":
			# on the Keg's counter beside Ostrin (Tavern: counter top 1.08 over the floor at -0.7)
			return Transform3D(Basis(Vector3.UP, 0.3), Vector3(16.95, 0.38, 32.98))
	return null


## For the tests and the studio: where everything is.
func info() -> Dictionary:
	return {"pickups": pickups.keys(), "props": props.keys(), "hollow": is_instance_valid(hollow), "spots": spots.duplicate()}
