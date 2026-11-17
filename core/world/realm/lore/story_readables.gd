extends Node
## Puts the story seat's readables (story_texts.gd PLACES) in the world, only while the wanderer is near. Every two seconds: a place
## within 90 m that has no carrier yet gets one (a slate for a stone, a notice, a grave, a page for a letter or a ledger, found on the
## ground with a ray), at most two a tick; a carrier more than 130 m away is freed. So nothing stands, draws or is built at rest and the
## net cost is a handful of small props near the player. Reading is the existing Inscription (E, the reading panel, the journal).
## Added by the story director. No class_name.

const StoryTexts := preload("res://core/world/realm/lore/story_texts.gd")
const LoreMore := preload("res://core/world/realm/lore/lore_more.gd")
const LoreIndex := preload("res://core/world/realm/lore/lore_index.gd")
const QuestProps := preload("res://core/story/quest_props.gd")
const Voices := preload("res://core/audio/landmark_voices.gd")
const RealmLand := preload("res://core/world/realm/realm_land.gd")

const NEAR := 90.0
const FAR := 130.0
const PER_TICK := 2

var _live := {}                 ## place index -> holder
var _t := 1.5
var _lm_done := {}              ## landmark host instance id -> true
var _lm_t := 3.0
var _dead := {}                 ## place index -> true: no ground there (water, a cliff face); not tried again


func _process(dt: float) -> void:
	_t -= dt
	if _t > 0.0:
		return
	_t = 2.0
	var pl := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	var root := get_tree().current_scene
	if pl == null or root == null:
		return
	_lm_t -= 2.0
	if _lm_t <= 0.0:
		_lm_t = 6.0
		_landmarks(pl, root)
	var p2 := Vector2(pl.global_position.x, pl.global_position.z)
	var made := 0
	var places: Array = StoryTexts.all_places()
	for i in places.size():
		var at: Vector2 = (places[i] as Array)[1]
		var d := p2.distance_to(at)
		if _live.has(i):
			if d > FAR or not is_instance_valid(_live[i]):
				if is_instance_valid(_live[i]):
					(_live[i] as Node).queue_free()
				_live.erase(i)
			continue
		if d < NEAR and made < PER_TICK and not _dead.has(i):
			if _spawn(i, String((places[i] as Array)[0]), at, root, pl):
				made += 1
			else:
				_dead[i] = true


## The landmarks' readables: each landmark host (the group world_poi, meta wonder) gets its texts beside it, on the side the wanderer comes
## from, once the wanderer is within 70 m of its walls. Checked every six seconds.
func _landmarks(pl: Node3D, root: Node) -> void:
	for n: Node in get_tree().get_nodes_in_group("world_poi"):
		if not n.has_meta("wonder"):
			continue
		var nm := String(n.get_meta("wonder"))
		var ids: Array = []
		for pre: String in StoryTexts.LANDMARKS:
			if nm.begins_with(pre):
				ids = StoryTexts.LANDMARKS[pre]
		if ids.is_empty() or _lm_done.has(n.get_instance_id()):
			continue
		var box: AABB = Voices._bounds(n)
		if box.size == Vector3.ZERO:
			continue
		var p := pl.global_position
		var edge := Vector3(clampf(p.x, box.position.x, box.end.x), 0.0, clampf(p.z, box.position.z, box.end.z))
		var out := Vector3(p.x - edge.x, 0.0, p.z - edge.z)
		if out.length() < 0.01:
			out = Vector3(1.0, 0.0, 0.0)
		if Vector2(p.x - edge.x, p.z - edge.z).length() > 70.0:
			continue
		var tang := out.normalized().cross(Vector3.UP)
		_lm_done[n.get_instance_id()] = true
		for k in ids.size():
			var at := edge + out.normalized() * 4.0 + tang * (float(k) - float(ids.size() - 1) * 0.5) * 2.2
			_spawn_at(String(ids[k]), Vector2(at.x, at.z), root, pl, "L%d_%d" % [n.get_instance_id(), k])


func _spawn(i: int, id: String, at: Vector2, root: Node, pl: Node3D) -> bool:
	var h := _spawn_at(id, at, root, pl, "P%d" % i)
	if h == null:
		return false
	_live[i] = h
	return true


func _spawn_at(id: String, at: Vector2, root: Node, pl: Node3D, tag: String) -> Node3D:
	var space := pl.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(at.x, 400.0, at.y), Vector3(at.x, -120.0, at.y), Layers.WORLD)
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return null
	var n: Vector3 = hit.normal
	if n.y < 0.75 or RealmLand.in_water(at.x, at.y):
		return null                                   # a steep face, or water: no carrier here
	var pos: Vector3 = hit.position
	var kind := String(LoreIndex.entry(id).get("kind", "tablet"))
	var prop := "page" if kind in ["letter", "ledger", "page"] else "slate"
	var xf := Transform3D(Basis(Vector3.UP, float(hash(id) % 628) * 0.01), pos)
	var holder := QuestProps.make(root as Node3D, "Readable_" + tag + "_" + id, prop, xf)
	if holder == null:
		return null
	LoreMore.place(holder, id, Vector3(0.0, 0.45, 0.0))
	return holder
