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

const NEAR := 90.0
const FAR := 130.0
const PER_TICK := 2

var _live := {}                 ## place index -> holder
var _t := 1.5
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
	var p2 := Vector2(pl.global_position.x, pl.global_position.z)
	var made := 0
	var places: Array = StoryTexts.PLACES
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


func _spawn(i: int, id: String, at: Vector2, root: Node, pl: Node3D) -> bool:
	var space := pl.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(at.x, 400.0, at.y), Vector3(at.x, -120.0, at.y), Layers.WORLD)
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return false
	var n: Vector3 = hit.normal
	if n.y < 0.75:
		return false                                  # a steep face: no carrier here
	if RealmLand.in_water(at.x, at.y):
		return false
	var pos: Vector3 = hit.position
	var kind := String(LoreIndex.entry(id).get("kind", "tablet"))
	var prop := "page" if kind in ["letter", "ledger", "page"] else "slate"
	var xf := Transform3D(Basis(Vector3.UP, float(hash(id) % 628) * 0.01), pos)
	var holder := QuestProps.make(root as Node3D, "Readable_" + id, prop, xf)
	if holder == null:
		return false
	LoreMore.place(holder, id, Vector3(0.0, 0.45, 0.0))
	_live[i] = holder
	return true
