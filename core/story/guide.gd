extends Node
## The guide: a new player's way through the first act (Luke, 16 Nov: "there should be more guidance in the game, as
## soon as you start a new save, it doesn't show you what to do"). One per night, a child of the story director
## (story.gd), group "guide". After WoW's and Enshrouded's onboarding, in the game's own look:
##   - On for a save whose arrival played with it (story flag "guide", set by a new game's opening) until the first act
##     is done (flag "guide_done": both keepers down and Brannoc spoken to), and while Settings > Interface > Guidance
##     is on (HudPrefs.guide). A returning save never has the flag and plays as before.
##   - story_step(): the story's first open spine objective (quest_db.gd OBJECTIVES; "first_fire" is the guide's own) and
##     a place for it: the keep (the Keg's door while outside it), the nearest cold valley brazier, the nearer seal, a
##     keeper's arena, Brannoc, the summit ward and dais. Always resolved, guide on or off: it is the place the tracked
##     "story" is (core/story/quest_track.gd), which the HUD draws: ui/waypoint.gd (a painted mark over it with its
##     distance), ui/compass.gd (its mark on the strip), core/story/objective_line.gd, and the trail's marks on the way
##     (core/story/quest_trail.gd). The guide no longer draws any of it; it teaches. step() is the guided first act's
##     step: {} when the guide is off.
##   - A step done, the next is announced in the task banner's lane: "Next" + the objective + where (guide_lines.gd).
##   - The first controls are taught when they first matter, with painted key caps (ui/key_cap.gd tokens, through
##     Hints lessons): the world map when the step is far, the ledger at the first task, the journal at the first
##     place found, the gold marks over people with work, the objective key when the guide lets go.
##   - Hearthward's people point the way: walking past one, they call out where the step is and turn to point (once per
##     person per step, one every BARK_GAP seconds); "Which way?" is in their conversations (village_talk.gd).
## Load by path (no class_name): const Guide := preload("res://core/story/guide.gd")

const QuestDB := preload("res://core/story/quest_db.gd")
const Lines := preload("res://core/story/guide_lines.gd")
const Hints := preload("res://ui/hints.gd")
const HudPrefs := preload("res://ui/hud_prefs.gd")
const Voice := preload("res://core/npc/npc_voice.gd")
const RealmLayout := preload("res://core/world/realm/realm_layout.gd")
const OssFrame := preload("res://world/areas/ossuary/oss_frame.gd")

const KEG_DOOR := Vector3(17.6, 0.2, 22.4)        ## the Kindled Keg's porch, outside its door (Tavern.DOOR_X)
const BARK_R := 6.5                               ## a villager this near the wanderer may call out
const BARK_GAP := 22.0                            ## seconds between two calls
const HOME_R := 75.0                              ## the calls are Hearthward's: its people, its directions
const FAR_MAP := 80.0                             ## a step this far teaches the world map
const MARK_R := 14.0                              ## a person with work this near teaches the gold mark
## How high over its foot the waypoint hangs, by kind of target.
const LIFT := {"person": 2.4, "door": 2.6, "fire": 2.3, "seal": 3.6, "boss": 5.0}
const ART := {"person": "quest_available", "door": "quest_available", "fire": "fire", "seal": "seal", "boss": "boss"}
## The spine objectives past the first act: the guide lets go when one of these is the step.
const PAST := ["summit_seal", "warden", "return"]

var _story                                         ## the director (parent; story.gd preloads this file, so untyped)
var _step: Dictionary = {}
var _last_id := ""
var _poll := 0.0
var _scan := 0.0
var _nodes := {}                                   ## "keep" / "brannoc" / "seal:<id>" / "arena:<id>" / "fire:<name>" -> Node3D
var _bark_t := 8.0
var _barked := {}                                  ## "<villager id>:<step id>" -> true
var _tip_t := 0.0
var _was_on := false
var said: Array[String] = []                       ## the calls made (tests)


func _ready() -> void:
	name = "Guide"
	add_to_group("guide")
	_story = get_parent()
	Events.quest_changed.connect(func(_id: String, s: int, done: bool) -> void:
		if active() and s == 0 and not done:
			_tip("tasks", "{quest_log} Your tasks: each one taken up is kept here, and the one you track stays on screen"))
	Events.region_discovered.connect(func(_id: String, _kind: String) -> void:
		if active():
			_tip("journal", "{codex} The journal keeps every place you have found, and what was written there"))


## Is the guide on for this save, now? (static: the HUD asks without finding the node)
static func on() -> bool:
	HudPrefs.ensure()
	var f: Variant = Travel.story.get("flags", {})
	return HudPrefs.guide and f is Dictionary and bool((f as Dictionary).get("guide", false)) and not bool((f as Dictionary).get("guide_done", false))


func active() -> bool:
	return on()


## What to do now: {id, text, where, target (Vector3; INF when it has no place yet), kind, art, label}; {} when off.
func step() -> Dictionary:
	return _step if active() else {}


## The story's step with its place, guide on or off ({} before the first poll and once the story is told).
func story_step() -> Dictionary:
	return _step


## Where the waypoint and the compass point (Vector3.INF: nowhere).
func target_pos() -> Vector3:
	var s := step()
	return s.get("target", Vector3.INF) if not s.is_empty() else Vector3.INF


## For harnesses and tests: the step and its distance from the wanderer.
func target_info() -> String:
	var s := step()
	if s.is_empty():
		return "off"
	var p := _player()
	var t: Vector3 = s.target
	return "%s %s %s" % [s.id, s.kind, ("%d m" % roundi(p.global_position.distance_to(t))) if p and t != Vector3.INF else "no place"]


## The line a person gives when asked "Which way?" ("" while the guide is off).
func answer() -> String:
	var s := step()
	return String(Lines.ANSWER.get(String(s.get("id", "")), "")) if not s.is_empty() else ""


## The story director tells the guide each conversation that ended (story.gd _end).
func talked(conv: String) -> void:
	if conv == "brannoc" and String(_step.get("id", "")) == "peal" and active():
		_finish()


func _process(delta: float) -> void:
	var on := active()
	if on != _was_on:
		_was_on = on
		if not on and bool((Travel.story.get("flags", {}) as Dictionary).get("guide_done", false)):
			_tip("objective", "{show_objective} Hold to see your objective. From here the way is yours to find.")
	_scan -= delta
	if _scan <= 0.0:
		_scan = 2.0
		_find()
	_poll -= delta
	if _poll <= 0.0:
		_poll = 0.25
		_update()
	if not on:
		return                                     # the step is kept for the tracker; the teaching is over
	_bark_t -= delta
	if _bark_t <= 0.0:
		_bark_t = 0.6
		_barks()
	_tip_t -= delta
	if _tip_t <= 0.0:
		_tip_t = 1.0
		_tips()


func _player() -> Node3D:
	return get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D if is_inside_tree() else null


# --- the step ----------------------------------------------------------------------------------------------

func _update() -> void:
	var ws: Dictionary = _story.world() if _story is Node and "ui" in _story else {}
	var next := {}
	for o: Dictionary in QuestDB.OBJECTIVES:
		if not bool(o.main) or not QuestDB.test(String(o.when), ws) or QuestDB.test(String(o.done), ws):
			continue
		var id := String(o.id)
		if id in PAST and active():
			_finish()                              # the first act is told: the lessons stop, the step stays the story's
		next = {"id": id, "text": String(o.text), "where": String(Lines.WHERE.get(id, ""))}
		next.merge(_place(id))
		break
	var nid := String(next.get("id", ""))
	if nid != _last_id:
		if _last_id != "" and nid != "" and active():
			_announce(next)
		_last_id = nid
	_step = next


## A step's place: {target, kind, art, label}.
func _place(id: String) -> Dictionary:
	var p := _player()
	var at := Vector3.INF
	var kind := "door"
	var label := ""
	match id:
		"arrive", "peal", "return":
			var who: Node3D = _nodes.get("brannoc" if id == "peal" else "keep")
			kind = "person"
			label = "Brannoc" if id == "peal" else "The keep"
			if who != null and is_instance_valid(who):
				at = who.global_position
			if p != null and not _in_keg(p.global_position):
				at = KEG_DOOR            # the way in first: a mark over a man behind a wall is no help from the yard
				kind = "door"
				label = "The Kindled Keg"
		"first_fire":
			kind = "fire"
			var best := INF
			for n: String in QuestDB.BRAZIERS:
				var b: Node3D = _nodes.get("fire:" + n)
				if b == null or not is_instance_valid(b) or bool(b.get("lit")):
					continue
				var d := b.global_position.distance_to(p.global_position) if p else 0.0
				if d < best:
					best = d
					at = b.global_position
					label = String(Brazier.FIRE_NAMES.get(n, "A brazier"))
		"doors", "thorn_seal", "oss_seal":
			kind = "seal"
			var ids: Array = ["henge", "oss_gallery"] if id == "doors" else (["henge"] if id == "thorn_seal" else ["oss_gallery"])
			var best2 := INF
			for sid: String in ids:
				var s := _seal_pos(sid)
				var d2 := s.distance_to(p.global_position) if p and s != Vector3.INF else INF
				if s != Vector3.INF and (d2 < best2 or at == Vector3.INF):
					best2 = d2
					at = s
					label = "The thorn seal" if sid == "henge" else "The gallery seal"
		"summit_seal":
			kind = "seal"
			var ss: Node3D = _nodes.get("seal:summit")
			at = ss.global_position if ss != null and is_instance_valid(ss) else RealmLayout.SUMMIT_WARD
			label = "The summit ward"
		"warden":
			kind = "boss"
			var wa: Node3D = _nodes.get("arena:ascended_warden")
			at = wa.global_position if wa != null and is_instance_valid(wa) else RealmLayout.SUMMIT_DAIS
			label = "The Ascended Warden"
		"thornwarden", "bone_abbot":
			kind = "boss"
			var a: Node3D = _nodes.get("arena:" + id)
			if id == "bone_abbot" and _outside_ossuary():
				at = _oss_way_in()
			elif a != null and is_instance_valid(a):
				at = a.global_position
			else:
				at = ThornHenge.C if id == "thornwarden" else _oss_way_in()
			label = "The Thornwarden" if id == "thornwarden" else "The Bone Abbot"
	if at != Vector3.INF:
		at += Vector3.UP * float(LIFT.get(kind, 2.4))
	return {"target": at, "kind": kind, "art": String(ART.get(kind, "quest_target")), "label": label}


func _seal_pos(sid: String) -> Vector3:
	if sid == "oss_gallery" and _outside_ossuary():
		return _oss_way_in()
	var s: Node3D = _nodes.get("seal:" + sid)
	if s != null and is_instance_valid(s):
		return s.global_position
	if sid == "henge":
		return ThornHenge.C
	return _oss_way_in()


## The Ossuary is a pit: from outside it the mark is its way in (the Pilgrims' Landing, where the bone bridge starts),
## not a seal or a hall under the ground.
func _outside_ossuary() -> bool:
	var p := _player()
	return p == null or not RealmLayout.OSSUARY.grow(4.0).has_point(p.global_position)


func _oss_way_in() -> Vector3:
	return OssFrame.w(OssFrame.LANDING)


func _in_keg(at: Vector3) -> bool:
	return RealmLayout.TAVERN.grow(0.3).has_point(Vector2(at.x, at.z))


## Find the step's people and places (every 2 s: villagers walk, the Ossuary may build late).
func _find() -> void:
	var tree := get_tree()
	var k := tree.get_first_node_in_group("keep") as Node3D
	if k:
		_nodes["keep"] = k
	for n in tree.get_nodes_in_group(Groups.INTERACTABLE):
		if n is Node3D and "talk_id" in n and String(n.get("talk_id")) == "brannoc":
			_nodes["brannoc"] = n
	for s in tree.get_nodes_in_group(&"ward_seal"):
		if s is Node3D and "seal_id" in s:
			_nodes["seal:" + String(s.get("seal_id"))] = s
	for a in tree.get_nodes_in_group(&"boss_arena"):
		if a is Node3D and "boss_id" in a:
			_nodes["arena:" + String(a.get("boss_id"))] = a
	var scene := tree.current_scene
	if scene:
		for n2: String in QuestDB.BRAZIERS:
			var b := scene.get_node_or_null("Zone/Braziers/" + n2) as Node3D
			if b:
				_nodes["fire:" + n2] = b


func _announce(s: Dictionary) -> void:
	var log_ui = _story.get("log_ui") if _story is Node else null
	if log_ui is Object and is_instance_valid(log_ui):
		log_ui.drop_queued("NEXT")                 # a step that came and went while the lane was busy is not announced late
		log_ui.banner("NEXT", String(Lines.SHORT.get(String(s.id), s.text)), String(s.where))


func _finish() -> void:
	if not (_story is Node) or not ("ui" in _story):
		return
	_story.set_flag("guide_done")
	_step = {}


# --- first-time lessons ---------------------------------------------------------------------------------

func _tip(id: String, text: String) -> void:
	Hints.once(StringName("tip_guide_" + id), text, true)


func _tips() -> void:
	var p := _player()
	if p == null or _step.is_empty():
		return
	var t: Vector3 = _step.get("target", Vector3.INF)
	if t != Vector3.INF and p.global_position.distance_to(t) > FAR_MAP and bool((Travel.story.get("flags", {}) as Dictionary).get("met_keep", false)):
		_tip("map", "{world_map} The world map: the mark you are following is on it, and every fire you have lit")
	var qm = get_tree().get_first_node_in_group("quest_markers")
	if not Hints.seen(&"tip_guide_marks") and qm != null and bool((Travel.story.get("flags", {}) as Dictionary).get("met_keep", false)):
		for v in get_tree().get_nodes_in_group("villager"):
			var n := v as Node3D
			if n != null and n.global_position.distance_to(p.global_position) < MARK_R and String(qm.mark_of(n)) == "available":
				_tip("marks", "A gold mark over someone: they have work for you.   {interact} Talk")
				break


# --- people point the way -----------------------------------------------------------------------------

func _barks() -> void:
	var p := _player()
	if p == null or _step.is_empty() or get_tree().paused:
		return
	var sid := String(_step.id)
	var pool: Array = Lines.BARKS.get(sid, [])
	if pool.is_empty() or p.global_position.distance_to(RealmLayout.SPAWN) > HOME_R:
		return
	var tgt0: Vector3 = _step.get("target", Vector3.INF)
	if tgt0 != Vector3.INF and p.global_position.distance_to(tgt0) < 15.0:
		return                                     # the place is right here: nobody points at the bar you lean on
	var ui = _story.get("ui") if _story is Node else null
	if not (ui is Object) or not is_instance_valid(ui) or bool(ui.is_open()) or bool(ui.narrating()):
		return
	for v in get_tree().get_nodes_in_group("villager"):
		var n := v as Node3D
		if n == null or not n.is_inside_tree() or not n.is_visible_in_tree() or not ("display_name" in n):
			continue
		if n.global_position.distance_to(p.global_position) > BARK_R or n.get("attend") != null:
			continue
		var vid := String(n.get("id"))
		var key := "%s:%s" % [vid, sid]
		if _barked.has(key):
			continue
		_barked[key] = true
		_bark_t = BARK_GAP
		var line := String(pool[absi(hash(vid)) % pool.size()])
		said.append("%s: %s" % [vid, line])
		ui.narrate(["%s: \"%s\"" % [String(n.get("display_name")), line]])
		var voice := n.get_node_or_null("Voice")
		if voice == null:
			voice = Voice.speaker3d(n, 18.0)
		Voice.say(voice, Voice.for_node(n), 3 + line.length() / 24, 0.6)
		var tgt: Vector3 = _step.get("target", Vector3.INF)
		if "point_at" in n:
			n.set("point_at", tgt if tgt != Vector3.INF else p.global_position)
			n.set("point_t", 3.2)
		return
