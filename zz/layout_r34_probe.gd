extends Node
const LifePlaceP := preload("res://core/life/wildlife/life_place.gd")
## r34 layout: after the Realm is built, print what stands at given xz points (top hit on WORLD|PROPS
## and the node path), and the realm build time. -- --pts=x,z;x,z;...
##   HOME=<scratch> godot --headless --path . res://zz/layout_r34_probe.tscn -- --pts=-7.8,30
var main: Node
var t := 0.0
var done := false


func _ready() -> void:
	Travel._busy = true
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _process(d: float) -> void:
	t += d
	if done or main == null or not main.has_meta("realm_done"):
		if t > 200.0:
			get_tree().quit(1)
		return
	done = true
	await get_tree().create_timer(2.0).timeout
	var space := (main as Node3D).get_world_3d().direct_space_state
	for a in OS.get_cmdline_user_args():
		if not a.begins_with("--pts="):
			continue
		for s: String in a.trim_prefix("--pts=").split(";"):
			var v := s.split(",")
			var x := float(v[0])
			var z := float(v[1])
			var from := Vector3(x, 80, z)
			var ex: Array[RID] = []
			for k in 6:
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, Vector3(x, -60, z), 0xFFFF, ex))
				if hit.is_empty():
					break
				var c := hit.collider as Node
				print("PROBE %.1f,%.1f hit y=%.2f %s layer=%d" % [x, z, (hit.position as Vector3).y, c.get_path(), (c as CollisionObject3D).collision_layer])
				ex.append((c as CollisionObject3D).get_rid())
			var st := WorldLanes.site_at(Vector2(x, z), 2.0)
			print("PROBE %.1f,%.1f open_ground=%s site=%s" % [x, z, str(LifePlaceP.open_ground(x, z)), String(st.get("name", "")) if not st.is_empty() else "-"])
	for a3 in OS.get_cmdline_user_args():
		if a3.begins_with("--blocker="):
			for s3: String in a3.trim_prefix("--blocker=").split(";"):
				var v3 := s3.split(",")
				var hf := float(v3[2])
				var rc := Rect2(float(v3[0]) - hf, float(v3[1]) - hf, hf * 2.0, hf * 2.0)
				var why := String((load("res://core/world/realm/lore/lore_kit.gd") as GDScript).call("blocker", rc, float(v3[3])))
				var names := PackedStringArray()
				for st: Dictionary in WorldLanes.sites:
					if (st.rect as Rect2).grow(float(v3[3])).intersects(rc):
						names.append(String(st.name))
				print("BLOCKER %s: %s (sites %s; path_dist %.1f)" % [s3, why, names, RealmLayout.path_dist(rc.get_center())])
	if "--life" in OS.get_cmdline_user_args():
		for n in get_tree().root.find_children("Deer*", "", true, false):
			print("LIFEP %s %s" % [n.name, n.call("positions") if n.has_method("positions") else "?"])
		var spots: Dictionary = (load("res://core/world/realm/realm_pois.gd") as GDScript).get("spots")
		for k in spots:
			print("POIP %s %s" % [k, spots[k].at])
	if "--postern" in OS.get_cmdline_user_args():
		var st: Dictionary = (load("res://core/life/secrets/state.gd") as GDScript).call("site", "postern")
		print("POSTERN route ", st.route, " stair ", st.stair, " gate ", st.gate, " dir ", st.dir)
	for a2 in OS.get_cmdline_user_args():
		if not a2.begins_with("--near="):
			continue
		for s2: String in a2.trim_prefix("--near=").split(";"):
			var v2 := s2.split(",")
			var c := Vector3(float(v2[0]), 0, float(v2[1]))
			c.y = RealmLayout.ground(space, c.x, c.z) + 1.0
			var sh := SphereShape3D.new()
			sh.radius = float(v2[2])
			var q := PhysicsShapeQueryParameters3D.new()
			q.shape = sh
			q.transform = Transform3D(Basis.IDENTITY, c)
			q.collision_mask = Layers.WORLD | Layers.PROPS
			for r in space.intersect_shape(q, 32):
				var n := r.collider as Node
				if String(n.name).begins_with("Terrain"):
					continue
				print("NEAR %s: %s at %s" % [s2, n.get_path(), (n as Node3D).global_position.snapped(Vector3.ONE * 0.1)])
	get_tree().quit()
