extends Node
## The tracked task (docs/quest_trail.md): which task the HUD follows and where its step is. One per night, a child of
## the story director (story.gd), group "quest_track". It is the one source the waypoint (ui/waypoint.gd), the compass
## mark (ui/compass.gd), the objective line (core/story/objective_line.gd), the map pin and the trail's marks
## (core/story/quest_trail.gd) read, so there is one way of guiding, not a guide's beside the tasks'.
##   - the pick: the ledger's Track (quest_book.gd follow()): a task id, or MAIN, the story's own way ("The night's
##     road": the spine of quest_db.gd OBJECTIVES, whose place the guide (guide.gd) resolves). Nothing picked: the guided
##     first act's step while the guide is on, else the newest task under way, else the story. A task that ended
##     hands back to the default.
##   - current(): {id, title, text, kind, art, label, key, target (the point the waypoint hangs from, Vector3.INF when
##     the step has no place), foot (the same point on the ground), src}. Polled four times a second and on
##     Events.quest_changed / quest_tracked; a few group lookups and no searching.
## Places of a task's step, in order: the task's own map target (quest_markers.gd: `at`, `to`, the next bell, a rare's
## last seen), a pickup the step wants, the person to speak to, the seal, the boss's arena, the region its foes are in.
## Load by path: const QuestTrack := preload("res://core/story/quest_track.gd")

const Book := preload("res://core/story/quest_book.gd")
const Chains := preload("res://core/story/quest_chains.gd")
const Guide := preload("res://core/story/guide.gd")
const Giver := preload("res://core/story/quest_giver.gd")
const QuestWorld := preload("res://core/story/quest_world.gd")
const QuestMarkers := preload("res://core/story/quest_markers.gd")
const RealmLayout := preload("res://core/world/realm/realm_layout.gd")

const MAIN_TITLE := Book.MAIN_TITLE
## How high over its foot the waypoint hangs, by kind of place.
const LIFT := {"person": 2.4, "door": 2.6, "fire": 2.3, "seal": 3.6, "boss": 5.0, "pickup": 1.4, "place": 2.4}

signal changed                                     ## the followed task, its step or its place changed (the trail rebuilds)

var current_id := ""                               ## MAIN, a task id, or "" (nothing to follow)
var _cur: Dictionary = {}
var _poll := 0.0
var _scan := 0.0
var _story: Node
var _people := {}                                  ## npc id -> Node3D
var _pin: Node3D                                   ## where the step is, on the minimap and the world map
var _key := ""


func _ready() -> void:
	name = "QuestTrack"
	add_to_group("quest_track")
	_story = get_parent()
	Events.quest_changed.connect(func(_id: String, _s: int, _d: bool) -> void: _poll = 0.0)
	Events.quest_tracked.connect(func(_id: String) -> void: refresh())
	refresh()


## The followed task's step and place ({} before the first poll).
func current() -> Dictionary:
	return _cur


## The point the waypoint hangs from (Vector3.INF: nowhere).
func target_pos() -> Vector3:
	return _cur.get("target", Vector3.INF)


func _process(delta: float) -> void:
	_scan -= delta
	if _scan <= 0.0:
		_scan = 2.0
		_find_people()
	_poll -= delta
	if _poll <= 0.0:
		_poll = 0.25
		refresh()


## Bring the choice and the place up to date (the poll calls it; the ledger's pick does too, so it answers at once).
func refresh() -> void:
	current_id = _pick()
	var c := _resolve(current_id)
	var key := "%s|%s|%s" % [current_id, String(c.get("key", "")), "" if c.get("foot", Vector3.INF) == Vector3.INF else "p"]
	_cur = c
	_pin_to(c)
	if key != _key:
		_key = key
		changed.emit()


func _pick() -> String:
	var f := Book.followed()
	if f == Book.MAIN:
		return Book.MAIN
	if f != "" and Book.active(f) and not Chains.hidden(f):
		return f
	if Guide.on():
		return Book.MAIN
	var n := Book.newest()
	return n if n != "" else Book.MAIN


func _player() -> Node3D:
	return get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D if is_inside_tree() else null


# --- the step and its place ------------------------------------------------------------------------------

func _resolve(id: String) -> Dictionary:
	if id == Book.MAIN:
		return _story_step()
	if not Book.active(id):
		return {}
	var s := Book.step(id)
	var stp := Chains.step(id, s)
	var out := {"id": id, "title": String(Chains.QUESTS[id].name), "text": Chains.step_text(id, s, Book.q(id)), "key": "%s:%d" % [id, s],
		"kind": "place", "art": "followed", "label": "", "target": Vector3.INF, "foot": Vector3.INF, "src": ""}
	var at := _place(id, s, stp, out)
	out.art = {"seal": "seal", "boss": "boss"}.get(String(out.kind), "followed")
	if at != Vector3.INF:
		out.foot = at
		out.target = at + Vector3.UP * float(LIFT.get(String(out.kind), 2.4))
	return out


## The story's way: the guide's step (guide.gd resolves it for the spine, the guide's lessons on or off).
func _story_step() -> Dictionary:
	var g := get_tree().get_first_node_in_group("guide") as Guide if is_inside_tree() else null
	var st: Dictionary = g.story_step() if g != null else {}
	if st.is_empty():
		return {"id": Book.MAIN, "title": MAIN_TITLE, "text": "", "key": "", "kind": "place", "art": "quest_target", "label": "", "target": Vector3.INF, "foot": Vector3.INF, "src": ""}
	var t: Vector3 = st.get("target", Vector3.INF)
	var kind := String(st.get("kind", "place"))
	return {"id": Book.MAIN, "title": MAIN_TITLE, "text": String(st.get("text", "")), "key": String(st.get("id", "")), "kind": kind,
		"art": String(st.get("art", "quest_target")), "label": String(st.get("label", "")), "target": t,
		"foot": t - Vector3.UP * float(LIFT.get(kind, 2.4)) if t != Vector3.INF else Vector3.INF, "src": "guide", "where": String(st.get("where", ""))}


## A task step's foot point; sets out.kind / art / label / src on the way.
func _place(id: String, s: int, stp: Dictionary, out: Dictionary) -> Vector3:
	# 1) the task's own map target (a place, a destination, the next bell, a rare's last seen)
	var markers := _story.get("markers") as QuestMarkers if _story != null else null
	if markers != null and is_instance_valid(markers):
		for t: Node in markers.targets():
			if is_instance_valid(t) and String(t.get_meta("quest", "")) == id:
				out.src = "markers"
				out.label = String(stp.get("label", ""))
				return (t as Node3D).global_position
	var kind := String(stp.get("kind", ""))
	# 2) a pickup this step wants, the nearest not yet taken
	var p := _player()
	var best := INF
	var at := Vector3.INF
	for k: String in Chains.PICKUPS:
		var pd: Dictionary = Chains.PICKUPS[k]
		if String(pd.quest) != id or int(pd.step) != s or Book.found(id).has(k):
			continue
		var sp: Vector3 = QuestWorld.spots.get(k, Vector3.INF)
		if sp == Vector3.INF:
			var near: Vector2 = pd.near
			sp = Vector3(near.x, RealmLayout.macro_height(near.x, near.y), near.y)
		var d := sp.distance_to(p.global_position) if p != null else 0.0
		if d < best:
			best = d
			at = sp
			out.label = String(pd.name)
	if at != Vector3.INF:
		out.kind = "pickup"
		out.src = "pickup"
		return at
	# 3) the person to speak to
	if kind in ["talk", "turnin", "escort"] or stp.has("who"):
		var who := String(stp.get("who", Chains.giver(id)))
		var n: Node3D = _people.get(who)
		if n != null and is_instance_valid(n) and n.is_inside_tree():
			out.kind = "person"
			out.src = "person"
			out.label = String(Book.NAMES.get(who, who.capitalize()))
			return n.global_position
	# 4) a seal's guards, a boss's arena
	var cond := String(stp.get("cond", "")).split(":", true, 1)
	if kind == "seal" or (cond.size() > 1 and cond[0] == "seal"):
		var sid := String(stp.get("seal", cond[1] if cond.size() > 1 else ""))
		for sn in get_tree().get_nodes_in_group(&"ward_seal"):
			if sn is Node3D and "seal_id" in sn and String(sn.get("seal_id")) == sid:
				out.kind = "seal"
				out.src = "seal"
				return (sn as Node3D).global_position
	if cond.size() > 1 and cond[0] == "boss":
		for an in get_tree().get_nodes_in_group(&"boss_arena"):
			if an is Node3D and "boss_id" in an and String(an.get("boss_id")) == cond[1]:
				out.kind = "boss"
				out.src = "arena"
				return (an as Node3D).global_position
	# 5) the country its foes are in
	var region := String(stp.get("region", ""))
	if region != "":
		var c := _region_centre(region)
		if c != Vector3.INF:
			out.src = "region"
			return c
	return Vector3.INF


func _region_centre(rid: String) -> Vector3:
	for r: Dictionary in RealmLayout.REGIONS:
		if String(r.id) != rid:
			continue
		var c := Vector2.ZERO
		if r.has("c"):
			c = r.c
		elif r.has("rect"):
			c = (r.rect as Rect2).get_center()
		else:
			return Vector3.INF
		return Vector3(c.x, RealmLayout.macro_height(c.x, c.y), c.y)
	return Vector3.INF


## Find the people tasks send you to (every 2 s: villagers walk, patrons come and go).
func _find_people() -> void:
	var tree := get_tree()
	var pool: Array = tree.get_nodes_in_group("villager")
	pool.append_array(tree.get_nodes_in_group("keep"))
	for n: Node in tree.get_nodes_in_group(Groups.INTERACTABLE):
		var tid: Variant = n.get("talk_id")
		if tid is String and String(tid) != "":
			pool.append(n)
	var out := {}
	for n2: Node in pool:
		if not is_instance_valid(n2) or not (n2 is Node3D):
			continue
		var nid := Giver.npc_id(n2)
		if nid != "" and not out.has(nid):
			out[nid] = n2
	_people = out


# --- the map pin ---------------------------------------------------------------------------------------------

## The place on the minimap and the world map, as a task's target is (quest_markers.gd): for the story's way, and for
## the places the markers do not pin (a pickup, a person, a seal).
func _pin_to(c: Dictionary) -> void:
	var t: Vector3 = c.get("foot", Vector3.INF)
	if t == Vector3.INF or String(c.get("src", "")) == "markers":
		if _pin != null and _pin.is_in_group("map_marker"):
			_pin.remove_from_group("map_marker")
		return
	if _pin == null:
		_pin = Node3D.new()
		_pin.name = "TrackPin"
		add_child(_pin)
		_pin.set_meta("map_kind", "quest_target")
		_pin.set_meta("map_color", Color(1.0, 0.74, 0.32))
		_pin.set_meta("quest", "track")
	if not _pin.is_in_group("map_marker"):
		_pin.add_to_group("map_marker")
	_pin.global_position = t
	_pin.set_meta("map_label", String(c.get("title", "")) + (": " + String(c.text) if String(c.get("text", "")) != "" else ""))
