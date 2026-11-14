extends Node
## Sight lines from the Hearthward spawn to the far landmarks, at eye height, on the built Realm (headless).
##   godot --headless --path . res://zz/sight_probe.tscn
## For each landmark: rays from the eye to points up its height; prints which are open and what first blocks the rest.
var EYE := Vector3(0.0, 1.9, 26.5)
const EYES := [Vector3(0.0, 1.9, 26.5), Vector3(-4.0, 1.9, 40.0), Vector3(4.0, 1.9, 44.0), Vector3(30.0, 1.9, 40.0), Vector3(60.0, 1.9, 50.0)]
## [name, xz, y from, y to]
const TARGETS := [
	["spire", Vector2(245.0, 4.0), 12.0, 48.0],
	["hierarch_head", Vector2(-206.0, 148.0), 1.0, 100.0],
	["oak", Vector2(-70.0, 206.0), 16.0, 58.0],
]
var main: Node
var t := 0.0
var done := false


func _ready() -> void:
	Travel._busy = true
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _process(d: float) -> void:
	t += d
	if done or main == null or not main.has_meta("realm_done") or t < 4.0:
		return
	if t > 200.0:
		get_tree().quit(1)
	done = true
	await get_tree().physics_frame
	var space := (main as Node3D).get_world_3d().direct_space_state
	for nm: String in ["Poi_hierarch_statue", "Poi_lamp_spire", "Poi_r37s_oak"]:
		var nd := main.find_child(nm, true, false)
		if nd != null:
			var top := -INF
			var lo := INF
			for mi: Node in nd.find_children("*", "MeshInstance3D", true, false):
				var bb := (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
				top = maxf(top, bb.end.y)
				lo = minf(lo, bb.position.y)
			print("SIGHT %s meshes y %.1f..%.1f" % [nm, lo, top])
	for pth: Dictionary in RealmLayout.PATHS:
		if String(pth.id) == "anchor_track":
			var pts: Array = pth.pts
			var line := ""
			for i in range(maxi(0, pts.size() - 26), pts.size()):
				var q: Vector2 = pts[i]
				line += "(%.0f,%.0f:%.1f) " % [q.x, q.y, RealmLayout.ground(space, q.x, q.y)]
			print("SIGHT track ", line)
	for ey: Vector3 in EYES:
		EYE = ey
		print("SIGHT eye %s" % ey)
		_look(space)
	get_tree().quit()


func _look(space: PhysicsDirectSpaceState3D) -> void:
	for tg: Array in TARGETS:
		var xz: Vector2 = tg[1]
		var open := []
		var shut := {}
		var y: float = tg[2]
		while y <= float(tg[3]):
			var to := Vector3(xz.x, y, xz.y)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(EYE, to, Layers.WORLD))
			if hit.is_empty() or (hit.position as Vector3).distance_to(to) < 4.0:
				open.append(y)
			else:
				var hp: Vector3 = hit.position
				shut[y] = "%s at (%.0f,%.0f,%.0f)" % [(hit.collider as Node).name, hp.x, hp.y, hp.z]
			y += 4.0
		var first := ""
		for k in shut:
			first = "%.0f %s" % [k, shut[k]]
			break
		print("SIGHT   %s open y %s; lowest shut: %s" % [tg[0], open, first])
