extends Node
## The Upward Falls' task (core/story/quest_chains_upward_falls.gd), data and ground: the giver exists, the zone is a
## Realm region, the visit point and the pickup stand on dry ground near the weir, off the weir's masonry.
## Ends: UPWARD FALLS QUEST TEST PASS  /  FAIL n

const Chains := preload("res://core/story/quest_chains_upward_falls.gd")
const Cast := preload("res://core/life/village/village_cast.gd")
const CastW := preload("res://core/life/village/village_cast_r37_west.gd")

var main: Node
var fails := 0


func ok(c: bool, what: String) -> void:
	if c:
		print("  ok   ", what)
	else:
		fails += 1
		print("  FAIL ", what)


func _ready() -> void:
	Travel._busy = true
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _process(_d: float) -> void:
	if main == null or not main.has_meta("realm_done"):
		return
	set_process(false)
	await get_tree().create_timer(2.0).timeout
	var space: PhysicsDirectSpaceState3D = main.get_world_3d().direct_space_state
	var zones := PackedStringArray()
	for r: Dictionary in RealmLayout.REGIONS:
		zones.append(String(r.id))
	for id: String in Chains.QUESTS:
		var q: Dictionary = Chains.QUESTS[id]
		ok(Cast.CAST.has(q.giver) or Cast.OUTPOSTS.has(q.giver) or CastW.CAST.has(q.giver), "%s: the giver %s exists" % [id, q.giver])
		ok(String(q.zone) in zones, "%s: zone %s is a region" % [id, q.zone])
		ok(not (q.steps as Array).is_empty() and (q.steps as Array).back().kind == "turnin", "%s: ends in a turn-in" % id)
		for st: Dictionary in q.steps:
			if st.has("at"):
				var at: Vector2 = st.at
				ok(at.distance_to(Vector2(-207.0, -18.0)) < 20.0, "%s: step point %s is at the weir" % [id, at])
	for pid: String in Chains.PICKUPS:
		var p: Dictionary = Chains.PICKUPS[pid]
		var near: Vector2 = p.near
		ok(near.distance_to(Vector2(-207.0, -18.0)) < 24.0, "%s is near the weir" % pid)
		ok(not RealmLayout.river_mask(near.x, near.y) > 0.3, "%s is not in the river" % pid)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(near.x, 40.0, near.y), Vector3(near.x, -5.0, near.y), 1))
		ok(hit and String((hit.collider as Node).name).begins_with("Terrain"), "%s stands on open ground (the first thing under the sky is the terrain)" % pid)
	print("UPWARD FALLS QUEST TEST %s" % ("PASS" if fails == 0 else "FAIL %d" % fails))
	get_tree().quit()
