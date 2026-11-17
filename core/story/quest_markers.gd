extends Node3D
## The marks that say who has a task (story, r33; no class_name). One per night, added by the story
## director (story.gd) as "QuestMarkers". Adapts the floating quest-giver marks of an MMO to the
## valley's own look: an engraved bronze lozenge over the person's head, cut with
##   a gold mark  "!"   a task they would give you (a pale one for a daily at the Hearthfire)
##   a gold "?"         something to hand in or to say to them
##   a grey "?"         a task of theirs under way
## The same marks and the places a task sends you are map markers (group "map_marker", meta
## map_kind "quest_available" / "quest_turnin" / "quest_target", map_label = the task's name); the
## minimap (ui/minimap.gd, not ours) draws them. Pickups carry their own (quest_world.gd).
## Cost: the givers are found every 3 s (villagers, the keep, the Keg's talkers), their states and
## the targets refreshed twice a second; a mark only bobs (one tween each).
## Load by path: const QuestMarkers := preload("res://core/story/quest_markers.gd")

const Book := preload("res://core/story/quest_book.gd")
const Chains := preload("res://core/story/quest_chains.gd")
const Giver := preload("res://core/story/quest_giver.gd")
const StoryDB := preload("res://core/story/quest_db.gd")
const RealmLayout := preload("res://core/world/realm/realm_layout.gd")
const VerbKit := preload("res://core/story/verb_kit.gd")      ## clues and trails send you to an area (a circle), not a point

const GOLD := Color(1.0, 0.74, 0.32)
const DAILY := Color(0.7, 0.84, 1.0)
const GREY := Color(0.62, 0.62, 0.66)
const RIM := Color(0.78, 0.52, 0.24)
const FAR := 70.0
const NEAR_HIDE := 3.5               ## r35: closer than this (m, camera to person) the mark hides

var _scan := 0.0
var _poll := 0.0
var _givers: Array = []            ## [[node, npc id], ...]
var _marks := {}                   ## giver instance id -> mark Node3D
var _targets := {}                 ## "quest:step" -> Node3D (map only)
var _plaque: Texture2D
var _font: Font


func _ready() -> void:
	name = "QuestMarkers"
	add_to_group("quest_markers")
	_font = load("res://ui/fonts/Cinzel.ttf")
	_plaque = _make_plaque()
	Events.quest_changed.connect(func(_id: String, _s: int, _d: bool) -> void: _poll = minf(_poll, 0.05))


func _process(delta: float) -> void:
	_scan -= delta
	_poll -= delta
	if _scan <= 0.0:
		_scan = 3.0
		_find_givers()
		_poll = 0.0
	if _poll > 0.0:
		return
	_poll = 0.5
	refresh()


func _find_givers() -> void:
	var seen := {}
	var out: Array = []
	var pool: Array = get_tree().get_nodes_in_group("villager")
	pool.append_array(get_tree().get_nodes_in_group("keep"))
	for n: Node in get_tree().get_nodes_in_group(Groups.INTERACTABLE):
		var tid: Variant = n.get("talk_id")
		if tid is String and String(tid) != "":
			pool.append(n)
	var ids := {}
	for n2: Node in pool:
		if not is_instance_valid(n2) or not (n2 is Node3D) or seen.has(n2.get_instance_id()):
			continue
		var nid := Giver.npc_id(n2)
		if nid == "" or ids.has(nid):
			continue                         # r35: one mark a person (the keep was his body AND his talk spot: two)
		seen[n2.get_instance_id()] = true
		ids[nid] = true
		out.append([n2, nid])
	_givers = out


## Bring every mark and target in line with the tasks (tests call it directly).
func refresh() -> void:
	var live := {}
	var all := Giver.states(get_tree())
	for g: Array in _givers:
		if not is_instance_valid(g[0]):
			continue                          # a villager gone home for good, a patron freed
		var n: Node3D = g[0]
		if not n.is_inside_tree():
			continue
		var st: Array = all.get(String(g[1]), ["", "", false])
		var key := n.get_instance_id()
		if String(st[0]) == "":
			continue
		live[key] = true
		var mv: Variant = _marks.get(key)
		var m: Node3D = mv as Node3D if is_instance_valid(mv) else null
		if m == null:
			m = _make_mark(n)
			_marks[key] = m
		_set_mark(m, n, String(st[0]), String(st[1]), bool(st[2]))
		# r35: within talking range the mark has done its job: it fades so it never sits over a face
		var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
		m.visible = cam == null or cam.global_position.distance_to(n.global_position) > NEAR_HIDE
	for k: int in _marks.keys():
		if not live.has(k):
			var m2: Variant = _marks[k]
			if is_instance_valid(m2):
				(m2 as Node).queue_free()
			_marks.erase(k)
	_refresh_targets()


## The mark state over `n` ("" = none), for the tests.
func mark_of(n: Node) -> String:
	var m: Variant = _marks.get(n.get_instance_id())
	return String((m as Node).get_meta("state", "")) if m != null and is_instance_valid(m) else ""


func marks() -> Array:
	var out: Array = []
	for k: int in _marks:
		if is_instance_valid(_marks[k]):
			out.append(_marks[k])
	return out


func targets() -> Array:
	return _targets.values()


func _make_mark(n: Node3D) -> Node3D:
	var m := Node3D.new()
	m.name = "QuestMark"
	m.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF   # bobbed by a tween on rendered frames
	var top := 2.05
	var rig: Variant = n.get("rig")
	if rig is Object and is_instance_valid(rig) and (rig as Object).has_method("head_top"):
		top = float((rig as Object).call("head_top")) + 0.75    # r35: was +0.5 (its foot hung over the face)
	m.position = Vector3(0.0, top, 0.0)
	n.add_child(m)
	var sp := Sprite3D.new()
	sp.name = "Plaque"
	sp.texture = _plaque
	sp.pixel_size = 0.0042                # r35: was 0.0062 (as tall as the person's torso)
	sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sp.shaded = false
	sp.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sp.visibility_range_end = FAR
	m.add_child(sp)
	var lb := Label3D.new()
	lb.name = "Glyph"
	lb.font = _font
	lb.font_size = 72
	lb.pixel_size = 0.0039
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lb.shaded = false
	lb.outline_size = 14
	lb.outline_modulate = Color(0.12, 0.06, 0.03, 0.95)
	lb.position = Vector3(0.0, 0.01, 0.0)
	lb.sorting_offset = 0.2
	lb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lb.visibility_range_end = FAR
	m.add_child(lb)
	# a slow bob, like a lantern on a hook
	var tw := m.create_tween().set_loops()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(m, "position:y", top + 0.09, 1.3)
	tw.tween_property(m, "position:y", top, 1.3)
	return m


func _set_mark(m: Node3D, n: Node3D, state: String, qid: String, daily: bool) -> void:
	var lb := m.get_node("Glyph") as Label3D
	var sp := m.get_node("Plaque") as Sprite3D
	var col := GREY
	var glyph := "?"
	match state:
		"available":
			col = DAILY if daily else GOLD
			glyph = "!"
		"turnin":
			col = GOLD
	lb.text = glyph
	lb.modulate = col
	sp.modulate = Color(1, 1, 1, 0.92) if state != "progress" else Color(0.72, 0.72, 0.76, 0.8)
	m.visible = n.get("hidden") != true
	m.set_meta("state", state)
	m.set_meta("quest", qid)
	# the map: offers and turn-ins (a grey mark is only shown over the head)
	var kind: String = {"available": "quest_available", "turnin": "quest_turnin"}.get(state, "")
	if kind == "":
		if m.is_in_group("map_marker"):
			m.remove_from_group("map_marker")
		return
	m.set_meta("map_kind", kind)
	var label := String((Chains.QUESTS.get(qid, {}) as Dictionary).get("name", ""))
	if qid.begins_with("main:"):                  # r34 merge: a main-story objective (quest_db.gd)
		label = String(StoryDB.objective(qid.substr(5)).get("text", ""))
	# a giver indoors (villager.hidden: the whole body, mark and all, is switched off) keeps its pin, sitting at the
	# door they went in by, and says so: the map skips anything not visible in the tree unless it is map_always
	if n.get("hidden") == true:
		m.set_meta("map_always", true)
		label = (label + " (" if label != "" else "(") + "indoors for now)"
	elif m.has_meta("map_always"):
		m.remove_meta("map_always")
	m.set_meta("map_label", label)
	m.set_meta("map_color", col)
	if not m.is_in_group("map_marker"):
		m.add_to_group("map_marker")


## The places the tracked steps send you: one map pin each (quest_target).
func _refresh_targets() -> void:
	var want := {}
	for id: String in Chains.ORDER:
		if not Book.active(id):
			continue
		var s := Book.step(id)
		var stp := Chains.step(id, s)
		var at: Variant = stp.get("to", stp.get("at"))
		if id == "forty_first" and s == 0:
			at = Chains.ESCORT.to
		var bell := ""
		if not (at is Vector2) and (String(stp.get("cond", "")).begins_with("bells:") or String(stp.get("cond", "")).begins_with("peal:")):
			var pl := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
			# the peal's step wants bells, not a place: the Marches' bell first, else the nearest bell on offer
			bell = next_bell(get_tree(), Vector2.ZERO if pl == null else Vector2(pl.global_position.x, pl.global_position.z))
			if bell != "":
				at = bell_place(bell)
		var seen: Array = []
		if not (at is Vector2) and not (stp.get("rares", []) as Array).is_empty():
			seen = _last_seen(stp.rares)          # a standing bounty on named rares: pin the nearest one still up
			if not seen.is_empty():
				at = seen[1]
		var ar := VerbKit.area(id, stp, Book.q(id))
		if not ar.is_empty():
			at = ar.c                               # the area's centre: the pin gets a circle (meta map_radius), the waypoint no exact spot
		if not (at is Vector2):
			continue
		var key := "%s:%d:%s%s%s" % [id, s, bell, String(seen[0]) if not seen.is_empty() else "", (":a%d" % int(ar.i)) if not ar.is_empty() else ""]
		want[key] = true
		var tv: Variant = _targets.get(key)
		var t: Node3D = tv as Node3D if is_instance_valid(tv) else null
		if t == null:
			t = Node3D.new()
			t.name = "Target_%s_%d" % [id, s]
			add_child(t)
			var xz: Vector2 = at
			# pin on the land, not at y=0 (bells in the Marches sat 10 m under the Spire's bluff)
			var y := RealmLayout.macro_height(xz.x, xz.y)
			var space := get_world_3d().direct_space_state if is_inside_tree() and get_world_3d() else null
			if space != null:
				var g := RealmLayout.ground(space, xz.x, xz.y)
				if not is_nan(g):
					y = g
			t.global_position = Vector3(xz.x, y, xz.y)
			t.add_to_group("map_marker")
			t.set_meta("map_kind", "quest_target")
			t.set_meta("map_color", GOLD)
			t.set_meta("quest", id)
			_targets[key] = t
		t.set_meta("map_radius", float(ar.get("r", 0.0)))
		var lbl := String(stp.get("label", Chains.step(bell, maxi(0, Book.step(bell))).get("label", "") if bell != "" else ""))
		if not seen.is_empty():
			lbl = "%s, last seen" % String(seen[2])
		t.set_meta("map_label", String(Chains.QUESTS[id].name) + ((": " + lbl) if lbl != "" else ""))
	for k: String in _targets.keys():
		if not want.has(k):
			var t2: Variant = _targets[k]
			if is_instance_valid(t2):
				(t2 as Node).queue_free()
			_targets.erase(k)


## The nearest of the named rares `ids` still up, as [id, xz, title] ([] when none is): a rare's own map
## marker (core/enemy/rares.gd) is on the map while it is alive and its haunt is dark, so the markers are the
## "unslain" list, and the marker's place is where it was last seen.
func _last_seen(ids: Array) -> Array:
	var pl := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	var from := Vector2.ZERO if pl == null else Vector2(pl.global_position.x, pl.global_position.z)
	var best: Array = []
	var best_d := INF
	for n: Node in get_tree().get_nodes_in_group(&"map_marker"):
		var nm := String(n.name)
		if not (n is Node3D) or not nm.begins_with("RareMarker_") or not nm.trim_prefix("RareMarker_") in ids:
			continue
		var xz := Vector2((n as Node3D).global_position.x, (n as Node3D).global_position.z)
		var d := from.distance_to(xz)
		if d < best_d:
			best_d = d
			best = [nm.trim_prefix("RareMarker_"), xz, String(n.get_meta("map_label", "A named rare"))]
	return best


## Where Saltmarket's fire is (RealmLayout.ZONES "saltmarket"): the shut-out bell is reached through Ardel Wick, who keeps the Spire's coal.
const SALTMARKET := Vector2(212.0, 92.0)


## The next of the Founder's bells to go to, as a task id ("" when none is left): the Marches' bell first while it
## stands unanswered (the door insists on it), else the nearest bell whose task is under way or on offer. A bell whose
## task is not yet on offer (its `avail` chain is not done) is skipped, and when the Marches' is one of those the
## answer is the task that unlocks it (Ardel's spire_coal, at Saltmarket, which has no gate of its own).
static func next_bell(tree: SceneTree, from: Vector2) -> String:
	var shut := Chains.BELL_SHUT_OUT
	if Book.pick(shut) == "":
		if Book.active(shut) or Giver.available(shut, tree):
			return shut
		var gate := unlock_of(shut, tree)
		if gate != "":
			return gate
	var best := ""
	var best_d := INF
	for bid: String in Chains.BELLS:
		if Book.pick(bid) != "" or not (Book.active(bid) or Giver.available(bid, tree)):
			continue
		var at: Variant = Chains.step(bid, 0).get("at")
		if not (at is Vector2):
			continue
		var d := from.distance_to(at as Vector2)
		if d < best_d:
			best_d = d
			best = bid
	return best


## The task to do next to open task `id` ("" when it is open or nothing names a way): the first of its `qd:` prerequisites
## not yet done (and itself on offer or under way), found through their own prerequisites.
static func unlock_of(id: String, tree: SceneTree, depth := 0) -> String:
	if depth > 6:
		return ""
	for part: String in Chains.avail_cond(id).split(","):
		if not part.begins_with("qd:"):
			continue
		var pre := part.trim_prefix("qd:")
		if Book.done(pre) or not Chains.QUESTS.has(pre):
			continue
		if Book.active(pre) or Giver.available(pre, tree):
			return pre
		var deeper := unlock_of(pre, tree, depth + 1)
		if deeper != "":
			return deeper
	return ""


## Where task `id` (a bell, or what unlocks one) sends the wanderer, as a map xz (null: nowhere to name). A bell: where it
## hangs. A task under way: its step's place. A task not yet taken up: its giver's town, Saltmarket for the Marches'.
static func bell_place(id: String) -> Variant:
	if Book.active(id):
		var stp := Chains.step(id, Book.step(id))
		var at: Variant = stp.get("to", stp.get("at"))
		if at is Vector2:
			return at
	elif id in Chains.BELLS:
		return Chains.step(id, 0).get("at")
	if Chains.giver(id) == "marl" or Chains.giver(id) == "ardel":
		return SALTMARKET
	var first: Variant = Chains.step(id, 0).get("at")
	return first if first is Vector2 else null


## An engraved lozenge: a bronze rim, a soot-dark face, a thin inner line (drawn once per night).
func _make_plaque() -> Texture2D:
	var w := 72
	var h := 104
	var img := Image.create(w, h, true, Image.FORMAT_RGBA8)
	var face := Color(0.07, 0.045, 0.05, 0.86)
	for y in h:
		for x in w:
			var u := absf((float(x) + 0.5) / float(w) * 2.0 - 1.0)
			var v := absf((float(y) + 0.5) / float(h) * 2.0 - 1.0)
			var d := u + v * 0.92                       # 1.0 at the lozenge's edge
			var c := Color(0, 0, 0, 0)
			if d <= 1.0:
				if d > 0.84:
					# the rim, lit from above: warmer at the top, darker under
					var shade := 1.05 - 0.35 * ((float(y) / float(h)))
					var bevel := 1.0 - absf(d - 0.92) * 5.0
					c = Color(RIM.r * shade * (0.75 + 0.35 * bevel), RIM.g * shade * (0.75 + 0.35 * bevel), RIM.b * shade, 1.0)
				elif d > 0.76 and d < 0.79:
					c = Color(0.55, 0.36, 0.17, 0.9)    # the engraved inner line
				else:
					c = face
				c.a *= clampf((1.0 - d) * 40.0, 0.0, 1.0)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
