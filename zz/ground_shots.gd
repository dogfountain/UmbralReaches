extends Node
## Full-size stills of the spots tools/ground_rank.py ranked (and of any listed view): the camera stands on the ground at the player's eye
## height on the downhill side of the spot and looks at it. In memory only.
##   godot --path . res://zz/ground_shots.tscn -- --spots=spots.json --out=dir --tag=before [--from=0 --count=60]
## A spot may carry "cam_x","cam_z" (where to stand) and "look_y" (height above the ground to aim at) to override the pick.
const SETTLE := 60
var p: Player
var main: Node
var spots: Array = []
var i := -1
var wait := 0
var out := "/tmp"
var tag := "shot"
var t := 0
var first := 0
var count := 1000
var rank_out := ""
var cam3: Camera3D              ## the stills' own camera: the Player's rig stopped following the wanderer after a few far moves (the fx views all showed one boardwalk)
var fx_views := true
var keep_spots := false
var fx_only := false              ## no ground spots: only the sky effects (--probe/--rank are ignored)
var probe_out := ""             ## --probe=file.tsv: measure the whole Realm first (zz/ground_probe.gd), then shoot


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Travel._busy = true
	Travel.bosses_slain.clear()
	var path := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a.begins_with("--tag="):
			tag = a.trim_prefix("--tag=")
		elif a.begins_with("--spots="):
			path = a.trim_prefix("--spots=")
		elif a.begins_with("--rank="):
			rank_out = a.trim_prefix("--rank=")        ## after the probe, rank it (tools/ground_rank.py) and shoot the worst 60 written here
		elif a.begins_with("--no-fx"):
			fx_views = false
		elif a == "--keep-spots":
			keep_spots = true                         ## the after run: rank the new probe for the counts, but shoot the spots given by --spots
		elif a == "--fx-only":
			fx_only = true
		elif a.begins_with("--probe="):
			probe_out = a.trim_prefix("--probe=")
		elif a.begins_with("--from="):
			first = int(a.trim_prefix("--from="))
		elif a.begins_with("--count="):
			count = int(a.trim_prefix("--count="))
	for f: String in path.split(",", false):
		spots.append_array(JSON.parse_string(FileAccess.get_file_as_string(f)) as Array)
	if path != "":
		spots = spots.slice(first, mini(spots.size(), first + count))
	get_window().size = Vector2i(1280, 800)
	DirAccess.make_dir_recursive_absolute(out)
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _ground(x: float, z: float) -> float:
	var space := (main as Node3D).get_world_3d().direct_space_state
	var ex: Array[RID] = []
	for k in 12:
		var q := PhysicsRayQueryParameters3D.create(Vector3(x, 140, z), Vector3(x, -60, z), 1)
		q.exclude = ex
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			break
		if String((hit.collider as Node).name).begins_with("Terrain"):
			return (hit.position as Vector3).y
		ex.append(hit.rid)
	return NAN


func _process(_d: float) -> void:
	t += 1
	if p == null:
		p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		return
	if not main.has_meta("realm_done") or t < 600:
		return
	(p.get_node("Visual") as Node3D).visible = false
	if i == -1:
		if probe_out != "" and not fx_only:
			var pr: Node = preload("res://zz/ground_probe.gd").new()
			pr.call("run", main, probe_out)
			pr.free()
			if rank_out != "":
				var res: Array = []
				var rc := OS.execute("python3", [ProjectSettings.globalize_path("res://tools/ground_rank.py"), probe_out, "--n", "60", "--spots", rank_out], res, true)
				print("GRANK exit ", rc)
				FileAccess.open(probe_out + ".rank.txt", FileAccess.WRITE).store_string(String(res[0]) if not res.is_empty() else "")
				if not keep_spots:
					spots = JSON.parse_string(FileAccess.get_file_as_string(rank_out)) as Array
					spots = spots.slice(0, 60)
		if fx_views:
			_add_fx_views()
		for n in get_tree().get_nodes_in_group(Groups.ENEMY):
			(n as Node).queue_free()
		for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
			if String(c.name) != "Grade":
				(c as CanvasLayer).visible = false
	if i >= 0 and i < spots.size():
		_hold()
	if wait > 0:
		wait -= 1
		return
	if i >= 0:
		var s: Dictionary = spots[i]
		var path := out.path_join(("%s_%s.png" % [String(s["file"]), tag]) if s.has("file") else "spot_%03d_%s.png" % [first + i, tag])
		get_viewport().get_texture().get_image().save_png(path)
		var img := get_viewport().get_texture().get_image()
		var lum := 0.0
		for k in 40:
			lum += img.get_pixel(40 + k * 28, 100 + (k % 7) * 90).get_luminance()
		print("GSHOT ", path, " ", s.get("why", ""), " ", s.get("kind", ""), " lum %.3f pos %s" % [lum / 40.0, p.global_position])
	i += 1
	while i < spots.size() and not _setup():
		i += 1
	if i >= spots.size():
		FileAccess.open(out.path_join("spots_used_%s.json" % tag), FileAccess.WRITE).store_string(JSON.stringify(spots, " "))
		print("GSHOTS done")
		get_tree().quit()


## Put the wanderer at spot i's camera and aim; false (the spot is skipped, printed) with no ground, no camera spot, or beside the Ossuary's area.
func _setup() -> bool:
	var s: Dictionary = spots[i]
	var at := Vector2(float(s.x), float(s.z))
	var gy := _ground(at.x, at.y)
	if is_nan(gy) or (Rect2(-150.0, 60.0, 260.0, 210.0).has_point(at) and not s.has("cam_x")):
		print("GSHOT_SKIP ", s.get("kind", ""), " ", at, " (no ground, or beside the Ossuary's area)")
		return false
	var r := clampf(float(s.get("size", 1.0)) * 1.5 + 4.0, 5.0, 16.0)
	var cam := Vector2(float(s.get("cam_x", NAN)), float(s.get("cam_z", NAN)))
	if is_nan(cam.x):
		var best := INF
		for k in 8:
			var a := TAU * float(k) / 8.0
			var q := at + Vector2(cos(a), sin(a)) * r
			var h := _ground(q.x, q.y)
			if not is_nan(h) and h < best and _cam_ok(q):
				best = h
				cam = q
	if is_nan(cam.x) or is_nan(_ground(cam.x, cam.y)):
		print("GSHOT_SKIP ", s.get("kind", ""), " ", at, " (no camera spot)")
		return false
	s["cam_x"] = cam.x
	s["cam_z"] = cam.y
	var eye := _ground(cam.x, cam.y) + 1.7
	var tgt := gy + float(s.get("look_y", minf(float(s.get("h", 1.0)), 3.0) * 0.35))
	var d := Vector3(at.x - cam.x, tgt - eye, at.y - cam.y)
	if not (d.length() > 0.1):
		return false
	if not (is_finite(eye) and is_finite(tgt)):
		print("GSHOT_SKIP ", s.get("kind", ""), " not finite")
		return false
	p.global_position = Vector3(cam.x, eye - 1.65, cam.y)
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()
	if cam3 == null:
		cam3 = Camera3D.new()
		cam3.fov = 70.0
		cam3.near = 0.05
		cam3.far = 700.0
		get_tree().root.add_child(cam3)
		cam3.make_current()
	cam3.global_position = Vector3(cam.x, eye, cam.y)
	cam3.look_at(Vector3(at.x, tgt, at.y), Vector3.UP)
	wait = SETTLE
	return true


func _hold() -> void:
	var s: Dictionary = spots[i]
	var cam := Vector2(float(s.get("cam_x", NAN)), float(s.get("cam_z", NAN)))
	if is_nan(cam.x) or is_nan(_ground(cam.x, cam.y)):
		return
	p.global_position = Vector3(cam.x, _ground(cam.x, cam.y) + 0.05, cam.y)
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()


## The effects that rise into the sky (the far plume, beacons, smoke and ember columns): each from 60, 150 and 300 m on the side the wanderer comes from.
func _add_fx_views() -> void:
	var seen: Array[Vector3] = []
	var names := ["farplume", "smoke", "chimneysmoke", "flames", "beaconembers", "plumepuffs", "embers"]
	var stack: Array[Node] = [main]
	var picks: Array[Node3D] = []
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if not (n is Node3D):
			continue
		var low := String(n.name).to_lower()
		var path := String(main.get_path_to(n)).to_lower()
		if path.contains("ossuary") or path.contains("realmrift") or path.contains("riftscorch"):
			continue
		var hit := low in names or n.is_in_group(&"landmark_beacon") or low.begins_with("beacon_")
		if hit:
			picks.append(n as Node3D)
	for n3 in picks:
		var pos := n3.global_position
		if pos.length() < 0.01:
			continue
		var dup := false
		for q in seen:
			if q.distance_to(pos) < 5.0:
				dup = true
		if dup:
			continue
		seen.append(pos)
		var away := Vector2(0.0, 33.0) - Vector2(pos.x, pos.z)
		var dir0 := away.normalized() if away.length() > 120.0 else Vector2(0.0, 1.0)
		for dist: float in [60.0, 150.0, 300.0]:
			# toward the wanderer's side when that stands on the Realm and off the Ossuary's area (walking in loads it); else the first free way round
			var cam := Vector2(pos.x, pos.z) + dir0 * dist
			# the first bearing, from the wanderer's side round, that stands on the Realm, off the Ossuary's area and sees the effect (a ray from the eye to a point
			# 8 m over its foot meets nothing nearer than 5 m to it): in a wood the effect is not to be read from inside the trees
			var seen_ok := false
			for k in 24:
				var cand := Vector2(pos.x, pos.z) + dir0.rotated(float((k + 1) / 2) * TAU / 24.0 * (1.0 if k % 2 == 1 else -1.0)) * dist
				if not _cam_ok(cand):
					continue
				var cg := _ground(cand.x, cand.y)
				if is_nan(cg):
					continue
				if _sees(Vector3(cand.x, cg + 1.7, cand.y), pos + Vector3.UP * 8.0):
					cam = cand
					seen_ok = true
					break
			if not seen_ok:
				print("FXVIEW no clear sight of ", n3.name, " at ", int(dist), " m: kept the first free bearing")
				for k in 12:
					var cand2 := Vector2(pos.x, pos.z) + dir0.rotated(TAU * float(k) / 12.0) * dist
					if _cam_ok(cand2):
						cam = cand2
						break
			spots.append({"x": pos.x, "z": pos.z, "cam_x": cam.x, "cam_z": cam.y, "look_y": maxf(pos.y - _ground(pos.x, pos.z), 0.0) + (22.0 if low_is_plume(n3) else 4.0), "why": "fx", "kind": "%s@%dm" % [n3.name, int(dist)],
				"file": "fx_%s_%d_%d_%dm" % [String(n3.name), roundi(pos.x), roundi(pos.z), int(dist)]})


func low_is_plume(n: Node) -> bool:
	var l := String(n.name).to_lower()
	return l.contains("plume") or l.contains("smoke")


func _cam_ok(v: Vector2) -> bool:
	if not RealmLayout.BOUNDS.grow(-10.0).has_point(v):
		return false
	if Rect2(-150.0, 60.0, 260.0, 210.0).has_point(v):          # the Ossuary's streamed area and the lych way
		return false
	return true


func _sees(from: Vector3, to: Vector3) -> bool:
	var space := (main as Node3D).get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to, 0xFFFFF)
	var hit := space.intersect_ray(q)
	return hit.is_empty() or (hit.position as Vector3).distance_to(to) < 5.0
