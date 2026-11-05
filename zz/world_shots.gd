extends Node
## Living-world renders (r28), windowed:
##   godot --path . res://zz/world_shots.tscn -- --tag=after [--only=storm,rain,...]
##   godot --path . res://zz/world_shots.tscn -- --tag=before --scape-off      (the r23 world, same views)
## Writes shots/agentF_<view>_<tag>.png. Views: storm (a near strike), rain (splashes on the road),
## meteors (a shower, 24 frames max-stacked: a long exposure), surge (the vortex flaring), wisp,
## hart (the white hart), owl (an owl over its mouse), fox (a pounce), lapwings (the flock up),
## tracks (prints where the herd ran), mist (banks in the fen).
## Saves are locked (Travel._busy); the HUD is hidden; enemies are cleared.
const RL := preload("res://core/world/realm/realm_land.gd")
const LifePlace := preload("res://core/life/wildlife/life_place.gd")
const LifeGroup := preload("res://core/life/wildlife/life_group.gd")

var t := 0.0
var main: Node
var started := false
var cam: Camera3D
var tag := "after"
var only: Array = []
var w: Node3D
var player: CharacterBody3D
var off := false


func _ready() -> void:
	Travel._busy = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.trim_prefix("--tag=")
		elif a.begins_with("--only="):
			only = Array(a.trim_prefix("--only=").split(","))
	off = "--scape-off" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _process(d: float) -> void:
	t += d
	if Time.get_ticks_msec() > 480000:             # WATCHDOG (real time): never outlive a stuck step
		print("WORLD TIMEOUT after %.0f s" % (Time.get_ticks_msec() / 1000.0))
		Engine.time_scale = 1.0
		get_tree().quit(1)
		return
	if cam != null and not cam.current:
		cam.current = true
	if started:
		for e in get_tree().get_nodes_in_group(Groups.ENEMY):
			if not (e as Node).is_queued_for_deletion():
				(e as Node).queue_free()
		return
	if main == null or not main.has_meta("realm_done") or main.get_node_or_null("Wildlife") == null or t < 10.0:
		if t > 160.0:
			print("SHOTS realm never finished")
			get_tree().quit()
		return
	started = true
	_run()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _secs(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func _put(p: Vector3) -> void:
	var y := RealmLayout.ground(player.get_world_3d().direct_space_state, p.x, p.z)
	player.global_position = Vector3(p.x, maxf(y, p.y) + 0.2, p.z)
	player.velocity = Vector3.ZERO
	await _frames(2)


## A camera spot `dist` m from the subject at eye height h with a clear view: open ground, no canopy,
## nothing solid between (tries round the circle, nearest to `pref` direction first).
func _frame(target: Vector3, dist: float, h: float, aim_h := 0.5, pref := 0.0) -> void:
	var sp := player.get_world_3d().direct_space_state
	var best := Vector3.INF
	for k in 24:
		var a := pref + float((k + 1) / 2) * 0.27 * (1.0 if k % 2 == 0 else -1.0)
		var q := target + Vector3(sin(a), 0, cos(a)) * dist
		var gy := RL.height_at(q.x, q.z)
		var c := Vector3(q.x, gy + h, q.z)
		if RL.in_water(q.x, q.z) or LifePlace.Flora.cover_at(q.x, q.z) > 0.15:
			continue
		var hit := sp.intersect_ray(PhysicsRayQueryParameters3D.create(c, target + Vector3(0, aim_h, 0)))
		if not hit.is_empty() and (hit.position as Vector3).distance_to(target) > 1.0:
			continue
		best = c
		break
	if best == Vector3.INF:
		best = target + Vector3(0, h, dist)
	cam.global_position = best
	cam.look_at(target + Vector3(0, aim_h, 0))


func _view(at: Vector3, look: Vector3) -> void:
	var gy := RL.height_at(at.x, at.z)
	cam.global_position = Vector3(at.x, gy + at.y, at.z)
	var ly := RL.height_at(look.x, look.z) + look.y
	cam.look_at(Vector3(look.x, ly, look.z))


func _save(view: String, img: Image = null) -> void:
	if img == null:
		img = get_viewport().get_texture().get_image()
	var path := "res://shots/agentF_%s_%s.png" % [view, tag]
	img.save_png(ProjectSettings.globalize_path(path))
	print("SHOTS saved ", path)


func _want(v: String) -> bool:
	return only.is_empty() or v in only


func _run() -> void:
	w = main.get_node("Wildlife")
	player = get_tree().get_first_node_in_group(Groups.PLAYER) as CharacterBody3D
	for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).visible = false
	player.visible = false                       # the free camera stands where the wanderer is
	var pc := get_viewport().get_camera_3d()
	cam = Camera3D.new()
	cam.fov = pc.fov if pc != null else 70.0
	cam.far = pc.far if pc != null else 82.0
	cam.near = 0.08
	if pc != null and pc.attributes != null:
		cam.attributes = pc.attributes
	get_tree().root.add_child(cam)
	cam.current = true
	var wx: Node3D = w.weather
	var ph: Node3D = w.get("phenomena")
	if ph != null:
		ph.quiet = true
	wx.force("clear", true)
	await _secs(1.0)

	if _want("storm"):
		await _put(Vector3(-30, 0, 70))
		_view(Vector3(-30, 1.7, 70), Vector3(-30, 6.0, 20))
		wx.force("storm", true)
		wx._thunder_t = 999.0
		await _secs(2.0)
		if off:
			wx.strike()
		else:
			wx.strike_near(420.0, PI + 0.1)
		# hold the first instant of the flash for the picture
		for i in 6:
			wx._flash_t = 0.0
			await _frames(1)
		print("SHOTS storm bolt %s flash %.2f cloud %s" % [wx._bolt.visible, wx.flash, wx._sky_flash.visible])
		_save("storm")
		await _secs(2.0)
	if _want("rain"):
		await _put(Vector3(-6, 0, 56))
		_view(Vector3(-4, 1.1, 58), Vector3(-10, 0.0, 46))
		wx.force("drizzle", true)
		await _secs(3.0)
		_save("rain")
	wx.force("clear", true)
	await _secs(1.0)
	if _want("meteors"):
		await _put(Vector3(-40, 0, 64))
		_view(Vector3(-40, 1.7, 64), Vector3(-75, 40.0, 30))
		if ph != null:
			ph.start_shower(60.0)
			await _secs(7.0)
		# a long exposure: frames go to user://meteor_frames; stack them with a lighten blend
		# (ffmpeg, see the report) into shots/agentF_meteors_<tag>.png. Frame 0 is saved as the shot too.
		var dir := OS.get_user_data_dir() + "/meteor_frames_" + tag
		DirAccess.make_dir_recursive_absolute(dir)
		for i in 30:
			await _frames(3)
			get_viewport().get_texture().get_image().save_png(dir + "/f%02d.png" % i)
		print("SHOTS meteor frames in ", dir)
		_save("meteors")
		if ph != null:
			ph._shower_left = 0.0
			ph.shower = 0.0
	if _want("surge"):
		await _put(Vector3(0, 0, 20))
		_view(Vector3(0, 1.7, 20), Vector3(0, 30.0, -40))
		if ph != null:
			ph.start_surge()
			await _secs(4.6)
		else:
			await _secs(1.0)
		_save("surge")
		await _secs(10.0)
	if _want("mist"):
		wx.force("mist", true)
		await _put(Vector3(60, 0, 0))
		_frame(Vector3(80, 0, -28), 26.0, 1.8, 1.0, 0.6)
		await _secs(3.0)
		_save("mist")
		wx.force("clear", true)
		await _secs(1.0)
	if _want("wisp"):
		await _put(Vector3(70, 0, -10))
		await _secs(0.5)
		var goal := Vector3(70, 0, -55)
		if ph != null:
			ph.start_wisp(Vector3(goal.x, RL.height_at(goal.x, goal.z), goal.z))
			await _secs(3.0)
			var wp: Vector3 = ph._wisp.global_position
			var gw := Vector3(wp.x, RL.height_at(wp.x, wp.z), wp.z)
			_frame(gw, 6.0, 1.4, wp.y - gw.y)
		else:
			_view(Vector3(70, 1.6, -7.5), Vector3(70, 1.0, -20))
		await _frames(3)
		_save("wisp")
	if _want("hart"):
		await _put(Vector3(-40, 0, 30))
		var hart_at := Vector3(-40, 0, 30)
		if ph != null and ph.start_hart(30.0):
			await _secs(4.0)
			hart_at = ph._hart_pos
		_frame(hart_at, 16.0, 1.5, 1.1, LifeGroup.yaw_to(player.global_position - hart_at) + PI)
		await _frames(3)
		_save("hart")
	if _want("owl"):
		var owls: Node3D = null
		for g in w.groups:
			if g.kind == "owl" and not (g.get("mice") as Array).is_empty():
				owls = g
				break
		if owls != null:
			var mp: Vector3 = (owls.mice[0] as Dictionary).home
			await _put(mp + Vector3(20, 0, 20))
			_frame(mp, 6.0, 1.4, 0.6)
			await _secs(1.5)
			for m: Dictionary in owls.mice:
				m.state = 0
			owls._hunt_t = 0.0
			var got := false
			for i in 200:
				await _frames(1)
				for b: Dictionary in owls.birds:
					if int(b.state) == 8:
						got = true
						_frame(b.pos, 3.2, 0.9, 0.25)
				if got:
					break
			await _frames(4)
			_save("owl")
	if _want("fox"):
		var fox: Node3D = null
		for g in w.groups:
			if g.kind == "fox":
				fox = g
				break
		if fox != null:
			var fp: Vector3 = fox.positions()[0]
			await _put(fp + Vector3(30, 0, 0))
			_frame(fp, 6.0, 1.0, 0.3)
			await _secs(1.5)
			for a: Dictionary in fox.animals:
				a.hunt_t = 0.0
				a.t = 0.0
			var got := false
			for i in 900:
				await _frames(1)
				var a: Dictionary = fox.animals[0]
				var pa: Vector3 = a.pos
				if (int(a.state) == 5 or int(a.state) == 6) and not got:
					if not bool(a.get("framed", false)):
						a.framed = true
						_frame(pa, 4.0, 0.8, 0.4, float(a.yaw) + PI * 0.5)
				if int(a.state) == 6 and float(a.k) > 0.4:
					got = true
					break
			_save("fox")
	if _want("lapwings"):
		var fl: Node3D = null
		for g in w.groups:
			if g.kind == "plover":
				fl = g
				break
		if fl != null:
			var pp: Vector3 = fl.patch
			await _put(pp + Vector3(30, 0, 0))
			_frame(pp, 6.0, 0.7, 0.1)
			await _secs(1.5)
			var mid := Vector3.ZERO
			for q: Vector3 in fl.positions():
				mid += q
			mid /= float(fl.positions().size())
			_frame(mid, 5.0, 0.6, 0.1)
			await _frames(2)
			_save("lapwings_feed")
			if not off:
				fl._lift(cam.global_position)
				await _secs(2.2)
				var m2 := Vector3.ZERO
				for q: Vector3 in fl.positions():
					m2 += q
				m2 /= float(fl.positions().size())
				cam.look_at(m2)
				await _frames(2)
				_save("lapwings_up")
	if _want("tracks"):
		var herd: Node3D = null
		for g in w.groups:
			if g.kind == "deer":
				herd = g
				break
		if herd != null:
			var lp: Vector3 = herd.positions()[0]
			await _put(lp + Vector3(8, 0, 0))
			await _secs(5.0)
			await _put(lp + Vector3(40, 0, 40))
			var rows: PackedFloat32Array = w.tracks._rows
			var idx := int(w.tracks._next) - 14
			if idx < w.tracks.SIGNS:
				idx += w.tracks.N - w.tracks.SIGNS
			if rows[idx * 16 + 13] > -1e5:
				var pt := Vector3(rows[idx * 16 + 3], rows[idx * 16 + 7], rows[idx * 16 + 11])
				cam.global_position = pt + Vector3(0.9, 1.6, 0.9)
				cam.look_at(pt)
			await _secs(0.5)
			_save("tracks")
	print("SHOTS done")
	get_tree().quit()
