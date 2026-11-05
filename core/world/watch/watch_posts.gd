extends RefCounted
## r36 the Kindled Watch: where its posts stand (on the roads between the far countries, in the
## dark) and the one call that builds them once the Realm's camps are planted (EnemySpawner).
## Load by path (no class_name).

const Watch := preload("res://core/world/watch/watch.gd")

## id -> {name, at (xz), face (xz: the way the dark comes from)}
const POSTS := {
	"west_road": {"name": "The Watch on the West Road", "at": Vector2(-98.0, -38.0), "face": Vector2(-1.0, 0.2)},
	"pits_road": {"name": "The Watch at the Pits' Gate", "at": Vector2(100.0, -46.0), "face": Vector2(0.6, -0.8)},
	"orchard_way": {"name": "The Watch on the Orchard Way", "at": Vector2(-62.0, 98.0), "face": Vector2(-0.7, 0.7)},
	"mere_way": {"name": "The Watch on the Mere Way", "at": Vector2(76.0, 92.0), "face": Vector2(0.7, 0.7)},
}


static func build(host: Node3D) -> void:
	if host == null or host.get_node_or_null("Watches") != null:
		return
	var village: Node = null
	for v in host.get_tree().get_nodes_in_group("villager"):
		village = v.get("village")
		if village != null:
			break
	# prewarm the Watch's two uniforms now, under the load, so no post builds a mesh in play
	var Rig: GDScript = load("res://core/life/village/villager_rig.gd")
	for look: Dictionary in Watch.LOOKS:
		var o := look.duplicate()
		o["name"] = "watch_prewarm"
		var r: Node = Rig.call("create", o)
		r.free()
	var root := Node3D.new()
	root.name = "Watches"
	host.add_child(root)
	var space := host.get_world_3d().direct_space_state
	for id: String in POSTS:
		var d: Dictionary = POSTS[id]
		var at: Vector2 = d.at
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(at.x, 90.0, at.y), Vector3(at.x, -40.0, at.y), Layers.WORLD))
		var w: Node3D = Watch.new()
		w.name = "Watch_" + id
		w.call("setup", id, d, village)
		w.position = (hit.position as Vector3) if not hit.is_empty() else Vector3(at.x, 0.0, at.y)
		root.add_child(w)
