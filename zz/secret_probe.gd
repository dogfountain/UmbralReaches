extends Node
## Agent D (secrets / Ossuary depths) probe: terrain-only height grid (streamed Ossuary structure
## excluded) and what the Ossuary holds at a point. Save-safe (Travel._busy).
##   HOME=<scratch>/home godot --headless --path . res://zz/secret_probe.tscn -- --grid=x0,z0,x1,z1,step
##   [--under=x0,z0,x1,z1,step]   (the lowest Ossuary/structure underside over each column)
var main: Node
var t := 0
var done := false


func _ready() -> void:
	Travel.set("_busy", true)
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _physics_process(_d: float) -> void:
	t += 1
	if done or main == null or not main.has_meta("realm_done"):
		if t > 60 * 150:
			print("PROBE timeout")
			get_tree().quit()
		return
	if t < 200:
		return
	done = true
	var space := (main as Node3D).get_world_3d().direct_space_state
	var oss := main.find_child("ossuary", true, false)
	if oss == null:
		for a in main.find_children("*", "Area", true, false):
			oss = a
	print("OSS node ", oss.get_path() if oss else "none")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--grid=") or a.begins_with("--under="):
			var under := a.begins_with("--under=")
			var v := a.substr(a.find("=") + 1).split(",")
			var stp := float(v[4])
			var hdr := "GRID   z\\x "
			var x := float(v[0])
			while x <= float(v[2]) + 0.01:
				hdr += "%6.0f" % x
				x += stp
			print(hdr)
			var z := float(v[1])
			while z <= float(v[3]) + 0.01:
				var row := ("UNDR" if under else "GRID") + " %7.1f " % z
				x = float(v[0])
				while x <= float(v[2]) + 0.01:
					row += _col(space, oss, x, z, under)
					x += stp
				print(row)
				z += stp
	if "--drum" in OS.get_cmdline_user_args():
		var lc := main.find_child("LowerCount", true, false)
		var db := lc.get("drum_body") as Node3D if lc else null
		if db:
			print("DRUM body ", db.global_position, " rot ", db.rotation)
			for mi in db.find_children("*", "GeometryInstance3D", true, false):
				var gi := mi as GeometryInstance3D
				print("DRUM child ", gi.name, " at ", gi.global_position, " aabb ", gi.get_aabb())
	if "--skulls" in OS.get_cmdline_user_args():
		var lc2 := main.find_child("LowerCount", true, false)
		for mmi in lc2.find_children("Skull*", "MultiMeshInstance3D", true, false):
			print("SKMM ", mmi.get_path(), " n ", (mmi as MultiMeshInstance3D).multimesh.instance_count)
			var mm := (mmi as MultiMeshInstance3D).multimesh
			for i in mm.instance_count:
				var o := mm.get_instance_transform(i).origin
				if o.x < 13.0 and o.z < -95.0:
					print("SKULL ", mmi.name, " ", o, " vis ", (mmi as MultiMeshInstance3D).visibility_range_end, " aabb ", (mmi as MultiMeshInstance3D).get_aabb())
	print("PROBE done")
	get_tree().quit()


func _col(space: PhysicsDirectSpaceState3D, oss: Node, x: float, z: float, under: bool) -> String:
	var ex: Array[RID] = []
	var from := Vector3(x + 0.0037, 120, z + 0.0029) if not under else Vector3(x + 0.0037, -30, z + 0.0029)
	var to := Vector3(x, -60, z) if not under else Vector3(x, 60, z)
	for i in 12:
		var q := PhysicsRayQueryParameters3D.create(from, to, 1, ex)
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			return "   -- "
		var n := hit.collider as Node
		var is_oss := oss != null and (oss == n or oss.is_ancestor_of(n))
		if under:
			if is_oss:
				return "%5.1f " % (hit.position as Vector3).y
			return "%5.1fT" % (hit.position as Vector3).y
		if is_oss:
			ex.append(hit.rid)
			continue
		return "%5.1f%s" % [(hit.position as Vector3).y, " " if String(n.name).begins_with("Terrain") else String(n.name).substr(0, 1).to_lower()]
	return "   ?? "
