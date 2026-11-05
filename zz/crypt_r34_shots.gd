extends Node
## r34 crypt captures (windowed): the pit hall, the Counting Stair and door, then the Bone Abbot's
## phases (the fight forced through its thresholds; the wanderer's Gloom held at 0). In memory only.
##   HOME=<scratch> godot --path . res://zz/crypt_r34_shots.tscn -- --out=<dir> [--only=name,name]
const Hall := preload("res://world/areas/ossuary/oss_hall.gd")
## [name, camera position, look-at point] (static views, no fight)
var VIEWS: Array = []
var FIGHT := ["p1_tolling", "intermission", "p2_choir", "p2_reckoning", "p3_collapse", "p4_burn"]
var main: Node
var cam: Camera3D
var p: Player
var step := -1
var wait := 0
var out := "/tmp"
var only: PackedStringArray = []
var _fight_i := -1
var _boss: BoneAbbot


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Travel._busy = true
	Travel.bosses_slain.clear()
	Travel.seals_broken["oss_gallery"] = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a.begins_with("--only="):
			only = a.trim_prefix("--only=").split(",")
	var c := Hall.C
	var da := Hall.door_ang()
	VIEWS = [
		["hall_door", Hall.at(da, 17.0, c.y + 2.2), c + Vector3.UP * 3.0],
		["hall_high", Vector3(36.4, Hall.TOP_Y - Hall.RISE * 5.0 + 1.7, Hall.GLIMPSE_Z), c + Vector3.UP * 1.0],
		["hall_wide", Hall.at(da + 180.0, 17.5, c.y + 9.0), c + Vector3(-6.0, 3.0, 0.0)],
		["hall_mound", Hall.at(80.0, 9.0, c.y + 1.7), c + Vector3.UP * 3.0],
		["chapel", Hall.at(315.0, 16.0, c.y + 1.8), Hall.at(315.0, 26.0, c.y + 1.4)],
		["vault", c + Vector3(4.0, 1.6, 6.0), c + Vector3(0.0, 22.0, 0.0)],
		["stair", Vector3(32.4, Hall.TOP_Y - Hall.RISE * 3.0 + 1.7, -95.8), Vector3(34.4, Hall.TOP_Y - Hall.RISE * 4.0, -84.0)],
		["count_door", Vector3(18.0, 6.2, -80.0), Vector3(29.2, 6.0, Hall.DOOR_Z)],
		["raid_door", Hall.at(da, 25.4, c.y + 1.7), c + Vector3.UP * 2.0],
	]
	if not only.is_empty():
		VIEWS = VIEWS.filter(func(v: Array) -> bool: return String(v[0]) in only)
		FIGHT = FIGHT.filter(func(n: String) -> bool: return n in only)
	get_window().size = Vector2i(1600, 1000)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DirAccess.make_dir_recursive_absolute(out)
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _shot(n: String) -> void:
	print("CRYPTPERF %s fps %d draws %d prims %dk frame %.2f ms (process %.2f)" % [n, Engine.get_frames_per_second(),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000.0),
		1000.0 / maxf(Engine.get_frames_per_second(), 1.0), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0])
	var path := out.path_join("crypt_%s.png" % n)
	get_viewport().get_texture().get_image().save_png(path)
	print("CRYPTSHOT ", path)


func _process(_d: float) -> void:
	if main == null or not main.has_meta("realm_done"):
		return
	if p == null:
		p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		if p == null:
			return
		cam = Camera3D.new()
		cam.name = "CryptShotCam"
		cam.far = 300.0
		main.add_child(cam)
		for e in get_tree().get_nodes_in_group(Groups.ENEMY):
			(e as Node).queue_free()
		for cl in get_tree().root.find_children("*", "CanvasLayer", true, false):
			if String(cl.name) != "Grade" and not String(cl.get_parent().name).begins_with("Arena_"):
				(cl as CanvasLayer).visible = false
		wait = 60
		return
	p.gloom = 0.0
	if wait > 0:
		wait -= 1
		cam.current = true
		return
	if step < VIEWS.size():
		if step >= 0:
			_shot(String(VIEWS[step][0]))
			if step == 0:
				for d in get_tree().root.find_children("*", "DirectionalLight3D", true, false):
					print("CRYPTMOON %s vis %s e %.2f mask %x col %s" % [d.get_path(), (d as Light3D).is_visible_in_tree(), (d as Light3D).light_energy, (d as Light3D).light_cull_mask, (d as Light3D).light_color])
				var we := get_tree().root.find_children("*", "WorldEnvironment", true, false)
				if not we.is_empty():
					var env := (we[0] as WorldEnvironment).environment
					print("CRYPTENV ambient src %d col %s e %.2f sky_contrib %.2f fog %s %.3f vfog %s tonemap %d exposure %.2f" % [env.ambient_light_source, env.ambient_light_color, env.ambient_light_energy, env.ambient_light_sky_contribution, env.fog_enabled, env.fog_density, env.volumetric_fog_enabled, env.tonemap_mode, env.tonemap_exposure])
				for l in get_tree().root.find_child("Crypt", true, false).find_children("*", "OmniLight3D", true, false):
					var o := l as OmniLight3D
					print("CRYPTLIGHT %s vis %s e %.2f r %.1f mask %x fade %s %.0f at %s" % [o.name, o.is_visible_in_tree(), o.light_energy, o.omni_range, o.light_cull_mask, o.distance_fade_enabled, o.distance_fade_begin, o.global_position.snapped(Vector3.ONE * 0.1)])
		step += 1
		if step < VIEWS.size():
			if "--boost" in OS.get_cmdline_user_args():
				for l in get_tree().root.find_child("Crypt", true, false).find_children("*", "OmniLight3D", true, false):
					(l as OmniLight3D).light_energy *= 10.0
			var v: Array = VIEWS[step]
			# the wanderer stands near the camera (the hall is drawn while you are in the crypt)
			p.teleport(Hall.at(Hall.door_ang(), 20.5, Hall.C.y + 0.2) if (v[1] as Vector3).y < 0.0 else Vector3(18.0, 4.5, -82.0))
			p.visible = false
			cam.global_position = v[1]
			cam.look_at(v[2], Vector3.UP)
			wait = 45
		return
	_fight_tick()


func _arena() -> BossArena:
	for a in get_tree().get_nodes_in_group(&"boss_arena"):
		if (a as BossArena).boss_id == "bone_abbot":
			return a
	return null


func _follow(pos: Vector3, look: Vector3) -> void:
	cam.global_position = pos
	cam.look_at(look, Vector3.UP)


func _fight_tick() -> void:
	if _fight_i == -1:
		if FIGHT.is_empty():
			get_tree().quit()
			return
		p.visible = true
		p.teleport(Hall.at(Hall.door_ang(), 12.0, Hall.C.y + 0.2))
		_fight_i = 0
		wait = 90
		return
	var ar := _arena()
	_boss = ar.get("_boss") as BoneAbbot if ar else null
	if _boss == null or not is_instance_valid(_boss):
		print("CRYPTSHOT no boss")
		get_tree().quit()
		return
	var c := Hall.C
	var behind := (p.global_position - c)
	behind.y = 0.0
	behind = behind.normalized() if behind.length() > 0.5 else Vector3.RIGHT
	var cpos := p.global_position + behind * 7.0 + Vector3.UP * 6.5
	if _fight_i >= FIGHT.size():
		get_tree().quit()
		return
	var n: String = FIGHT[_fight_i]
	match n:
		"p1_tolling":
			if wait == 0 and not has_meta("armed"):
				set_meta("armed", true)
				_boss.set("_toll_t", 0.0)
				_boss.set("_busy", 0.0)
				wait = 75
				return
		"intermission":
			if not has_meta("armed2"):
				set_meta("armed2", true)
				_boss.set_meta(&"test_no_floor", true)
				_boss.hp = _boss.max_hp * 0.65
				wait = 300
				return
		"p2_choir":
			if not has_meta("armed3"):
				set_meta("armed3", true)
				for t in _boss.get("_tallies"):
					if is_instance_valid(t):
						(t as Enemy).take_hit(999.0)
				wait = 150
				return
		"p2_reckoning":
			if not has_meta("armed4"):
				set_meta("armed4", true)
				_boss.set("_reckon_t", 0.0)
				_boss.set("_busy", 0.0)
				wait = 90
				return
		"p3_collapse":
			if not has_meta("armed5"):
				set_meta("armed5", true)
				_boss.hp = _boss.max_hp * 0.32
				wait = 640
				return
		"p4_burn":
			if not has_meta("armed6"):
				set_meta("armed6", true)
				_boss.hp = _boss.max_hp * 0.11
				wait = 450
				return
	_follow(c + Vector3(-4.0, 15.0, 11.0) if n in ["intermission", "p3_collapse", "p4_burn", "p2_reckoning", "p1_tolling", "p2_choir"] else cpos, c if n != "p1_tolling" else _boss.global_position)
	if wait > 0:
		wait -= 1
		if wait == 1:
			_follow(c + Vector3(-4.0, 15.0, 11.0) if n in ["intermission", "p3_collapse", "p4_burn", "p2_reckoning", "p1_tolling", "p2_choir"] else cpos, c if n != "p1_tolling" else _boss.global_position)
		return
	_shot(n)
	print("CRYPTSHOT %s phase %d inter %d hp %.0f cast '%s' fallen %d" % [n, _boss.phase, int(_boss.get("_inter")), _boss.hp, _boss.cast_name, int(get_tree().root.find_child("Crypt", true, false).call("fallen_count"))])
	_fight_i += 1
