extends Node
## Life system renders: godot --path . res://zz/life_shots.tscn -- [--life-weather=storm] [--only=name,name]
## Free-camera views of the wildlife (several frames each, so motion shows) and a lineup of every
## creature mesh in the brazier's light. -> shots/life_<name>_<i>.png
const LifeKit := preload("res://core/life/wildlife/life_kit.gd")
var main: Node
var cam: Camera3D
var t := 0.0
var ready_t := -1.0
var shots: Array = []
var si := 0
var fi := 0
var next_t := 0.0
var only: PackedStringArray = []

## [name, at, look, frames, spacing s]
const VIEWS := [
	["lineup", Vector3(0.0, 1.1, 22.5), Vector3(0.0, 0.7, 27.0), 2, 0.4],
	["moths", Vector3(1.8, 1.9, 30.8), Vector3(0.0, 1.9, 33.0), 3, 0.25],
	["doorlamp", Vector3(17.6, 2.3, 20.0), Vector3(19.2, 2.4, 22.7), 2, 0.3],
	["henge", Vector3(-63.0, 13.5, -12.0), Vector3(-74.0, 10.5, -21.0), 3, 0.5],
	["rift", Vector3(22.0, 22.0, -35.0), Vector3(0.0, 0.0, -55.0), 3, 0.5],
	["rift2", Vector3(10.0, 25.0, -22.0), Vector3(0.0, -3.0, -30.0), 3, 0.5],
	["crowns", Vector3(0.0, 2.2, 40.0), Vector3(0.0, 40.0, -150.0), 3, 0.12],
	["fenwide", Vector3(66.0, 3.0, 20.0), Vector3(80.0, -1.0, -10.0), 2, 0.5],
	["fenmid", Vector3(75.0, 2.0, -20.0), Vector3(60.0, -1.0, -45.0), 2, 0.5],
]


func _ready() -> void:
	Travel._busy = true                       # renders never write the player's save
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.trim_prefix("--only=").split(",")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _process(d: float) -> void:
	t += d
	if ready_t >= 0.0:
		for n in get_tree().get_nodes_in_group(Groups.ENEMY):      # camps respawn: keep the views calm
			if not (n as Node).is_queued_for_deletion():
				(n as Node).queue_free()
	if ready_t < 0.0:
		if main != null and main.has_meta("realm_done") and main.get_node_or_null("Wildlife") != null:
			ready_t = t
			_prepare()
		elif t > 120.0:
			_quit()
		return
	if t - ready_t < 3.0 or si >= shots.size():
		if si >= shots.size() and t - ready_t > 3.0:
			_quit()
		return
	var v: Array = shots[si]
	if fi == 0 and next_t == 0.0:
		if v.size() > 5 and is_instance_valid(v[5]) and (v[5] as Node).has_method("busy") and v[5].busy() and t - ready_t < 60.0:
			return                                   # let the animals settle (they may be mid-bolt)
		var at: Vector3 = v[1]
		var look: Vector3 = v[2]
		if v.size() > 5 and is_instance_valid(v[5]) and not (v[5] as Node).positions().is_empty():
			# follow the creature to where it is now (it may have wandered or fled)
			var now: Vector3 = (v[5] as Node).positions()[0]
			var was: Vector3 = v[6]
			at += now - was
			look += now - was
		if String(v[0]) in ["deer", "deerclose", "fox"] and v.size() > 5:
			# aim at the animal itself, then find a clear spot round it
			# a clear spot round the animal: open sky (no canopy) and nothing solid in between
			var c: Vector3 = (v[5] as Node).positions()[0] + Vector3(0, float((v[2] as Vector3).y - (v[6] as Vector3).y), 0)
			look = c
			var dist := Vector2(at.x - c.x, at.z - c.z).length()
			var hgt := at.y - c.y
			const Flora := preload("res://core/world/realm/realm_flora.gd")
			for k in 16:
				var a := float(k) / 16.0 * TAU + 0.6
				var q := c + Vector3(cos(a) * dist, hgt, sin(a) * dist)
				var sp := cam.get_world_3d().direct_space_state
				var hit := sp.intersect_ray(PhysicsRayQueryParameters3D.create(c, q, 1))
				if hit.is_empty() and Flora.cover_at(q.x, q.z) < 0.15 and Flora.cover_at((q.x + c.x) * 0.5, (q.z + c.z) * 0.5) < 0.15:
					at = q
					break
		cam.global_position = at
		cam.look_at(look)
		if String(v[0]) == "deerclose" and "--life-debug" in OS.get_cmdline_user_args():
			var cp := LifeKit.group("deer", 1)
			cp.multimesh.set_instance_transform(0, Transform3D(Basis.IDENTITY, Vector3.ZERO))
			main.add_child(cp)
			cp.global_position = look + Vector3(1.0, -0.9, 0.0)
			var gm: MultiMeshInstance3D = v[5].mmis["deer"]
			if "--life-freeze" in OS.get_cmdline_user_args():
				main.get_node("Wildlife").process_mode = Node.PROCESS_MODE_DISABLED
				print("LIFE_DBG6 froze Wildlife")
			# A: the herd's exact buffer in a fresh group, 3 m to the right; B: same with custom zeroed, 6 m
			for e in 2:
				var g2 := LifeKit.group("deer", gm.multimesh.instance_count)
				var b2: PackedFloat32Array = gm.multimesh.buffer
				if e == 1:
					for r in gm.multimesh.instance_count:
						for q in 4:
							b2[r * 16 + 12 + q] = 0.0
				g2.multimesh.buffer = b2
				if e == 1:
					main.get_node("Wildlife").add_child(g2)   # C: under the Wildlife node
				else:
					main.add_child(g2)
				g2.global_position = (v[5] as Node3D).global_position + Vector3(0, 0, 3.0 + 3.0 * e)
				print("LIFE_DBG5 copy %d at %s" % [e, g2.global_position])
			print("LIFE_DBG3 group mmi mesh %s mat %s cast %s gi_mode %s lod_bias %s tree %s" % [gm.multimesh.mesh, gm.material_override, gm.cast_shadow, gm.gi_mode, gm.lod_bias, gm.get_path()])
			var gn := v[5] as Node3D
			print("LIFE_DBG view %s group %s vis %s at %s cam %s" % [v[0], gn.name, gn.is_visible_in_tree(), gn.global_position, at])
		next_t = t + 1.2
		return
	if t >= next_t:
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://shots/life_%s_%d.png" % [v[0], fi]))
		if fi == 0:
			await _perf_share(String(v[0]))
		print("LIFE_SHOT ", v[0], " ", fi)
		if v.size() > 5 and is_instance_valid(v[5]) and v[5].get("mmis") != null:
			for k: String in v[5].mmis:
				var mi: MultiMeshInstance3D = v[5].mmis[k]
				var bf: PackedFloat32Array = v[5].get("_dbg_buf") if false else PackedFloat32Array()
				print("LIFE_DBG2 %s vis %s/%s gpos %s n %d custom %s range %s/%s layers %d anim0 %s cam %s" % [k, mi.visible, mi.is_visible_in_tree(), mi.global_position, mi.multimesh.instance_count, mi.multimesh.custom_aabb, mi.visibility_range_begin, mi.visibility_range_end, mi.layers, str(v[5].animals[0].pos), cam.global_position])
				var sts := []
				for an in v[5].animals:
					sts.append([int(an.state), String(an.mesh)])
				var bf4: PackedFloat32Array = mi.multimesh.buffer
				print("LIFE_DBG4 states %s buf_len %d row0 %s" % [sts, bf4.size(), bf4.slice(0, 16)])
		if v[0] == "crowns" and fi == 0:
			main.get_node("Wildlife").weather.strike()
		if v[0] == "henge":
			for g in main.get_node("Wildlife").groups:
				if g.name == "Crows_henge":
					var sts := []
					for b: Dictionary in g.birds:
						sts.append(int(b.state))
					print("LIFE_DBG henge vis ", g.visible, " mmi ", g.mmi.visible, " ", g.mmi.multimesh.instance_count, " states ", sts, " aabb ", g.mmi.get_aabb(), " xf0 ", g.mmi.multimesh.get_instance_transform(0))
		fi += 1
		next_t = t + float(v[4])
		if fi >= int(v[3]):
			fi = 0
			si += 1
			next_t = 0.0


func _prepare() -> void:
	for n in get_tree().get_nodes_in_group(Groups.ENEMY):
		(n as Node).queue_free()
	for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if c.name != "Grade":
			(c as CanvasLayer).visible = false
	var pl := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	if pl != null:
		pl.visible = false
		pl.process_mode = Node.PROCESS_MODE_DISABLED
	cam = Camera3D.new()
	cam.fov = 55.0
	cam.far = 500.0
	get_tree().root.add_child(cam)
	cam.current = true
	var w: Node = main.get_node("Wildlife")
	# dynamic views: the first group of each kind
	var extra := []
	for g in w.groups:
		var k: String = g.kind
		var ps: Array = g.positions()
		if ps.is_empty():
			continue
		var p: Vector3 = ps[0]
		match k:
			"owl":
				extra.append(["owl", p + Vector3(1.6, -0.3, 1.6), p + Vector3(0, 0.2, 0), 3, 0.6, g, p])
			"deer":
				extra.append(["deer", p + Vector3(7.0, 2.6, 7.0), p + Vector3(0, 0.8, 0), 3, 0.6, g, p])
				extra.append(["deerclose", p + Vector3(3.2, 1.3, 2.4), p + Vector3(0, 0.9, 0), 2, 0.6, g, p])
			"heron":
				var hy := float(g.birds[0].yaw)
				var fw := Vector3(-sin(hy), 0, -cos(hy))
				extra.append(["heron", p + fw * 3.2 + Vector3(0, 0.7, 0), p + Vector3(0, 0.55, 0), 2, 0.6, g, p])
			"pond":
				if g.frogs.size() >= 3:
					var f: Dictionary = g.frogs[0]
					var wat: Vector3 = f.water
					var away := (wat - (f.home as Vector3))
					away.y = 0.0
					away = away.normalized()
					extra.append(["fen", f.home + away * 1.3 + Vector3(0, 0.45, 0), f.home + Vector3(0, 0.05, 0), 3, 0.5])
					extra.append(["pool", f.home + away * 0.2 + Vector3(0, 1.7, 0), wat + away * 4.0, 3, 0.7])
			"fox":
				extra.append(["fox", p + Vector3(1.8, 0.7, 1.4), p + Vector3(0, 0.3, 0), 2, 0.5, g, p])
			"elk":
				extra.append(["elk", p + Vector3(16, 1.5, 10), p + Vector3(0, 2.2, 0), 2, 0.6, g, p])
	for g in w.groups:
		if g.kind in ["crow", "elk", "owl"]:
			print("LIFE_GROUP %s %s %s" % [g.name, g.center, str(g.positions().slice(0, 3))])
	var done := {}
	var all := VIEWS.duplicate()
	for e: Array in extra:
		if not done.has(e[0]):
			done[e[0]] = true
			all.append(e)
	for v: Array in all:
		if only.is_empty() or String(v[0]) in only:
			shots.append(v)
	# the lineup: one of each creature in front of the spawn brazier
	var kinds := ["crow", "owl", "heron", "frog", "deer", "stag", "fox", "rat", "elk"]
	var x := -2.6
	for k: String in kinds:
		var g := LifeKit.group(k, 1)
		var s := 0.5 if k == "elk" else (2.2 if k in ["frog", "rat"] else 1.0)
		g.multimesh.set_instance_transform(0, Transform3D(Basis(Vector3.UP, PI * 0.5 + 0.35).scaled(Vector3.ONE * s), Vector3.ZERO))
		g.multimesh.set_instance_custom_data(0, Color(0, 0.4, 0, 0))
		main.add_child(g)
		g.global_position = Vector3(x, 0.02, 27.0)
		g.set_meta("lineup", true)
		x += 0.65 if k in ["crow", "owl", "frog", "rat"] else 0.9
	# flyers mid-air in the lineup
	for k: String in ["crow", "owl"]:
		var g := LifeKit.group(k, 1)
		g.multimesh.set_instance_transform(0, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3.ZERO))
		g.multimesh.set_instance_custom_data(0, Color(1, 0, 0, 0))
		main.add_child(g)
		g.global_position = Vector3(-1.5 if k == "crow" else 0.6, 1.5, 27.5)


## Draws and primitives in this view with the wildlife shown and hidden (its share of the frame).
func _perf_share(nm: String) -> void:
	var w := main.get_node("Wildlife") as Node3D
	var on := _counts()
	w.visible = false
	await get_tree().process_frame
	await get_tree().process_frame
	var off := _counts()
	w.visible = true
	print("LIFE_PERF %s draws %d (life %d) prims %d (life %d)" % [nm, on.x, on.x - off.x, on.y, on.y - off.y])


func _counts() -> Vector2i:
	return Vector2i(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))


func _quit() -> void:
	print("LIFE_SHOTS done")
	get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
	OS.kill(OS.get_process_id())
