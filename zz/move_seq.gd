extends Node3D
## Motion filmstrips of the real Player in a lit studio (checker floor, so a sliding foot shows):
## a scripted run, and at chosen moments a burst of consecutive frames laid out as one strip per
## moment (a gait cycle, a stop, a landing...). Also measures foot slide: how far a sole moves
## while it is on the ground, per metre travelled.
##   godot --path . res://zz/move_seq.tscn -- [--tag=x] [--plan=loco|trav|combat] [--cam=side|q34|back|front]
##                                           [--legacy-legs]  (CharacterRig.foot_ik off: the old sine stride)
## -> shots/seq_<tag>_<plan>_<cam>.png (one row per burst) ; prints "SEQ slide ..." and "SEQ done".
## Never writes the save (Travel._busy).

const WORLD := 1
## [time s, wish (x right, z back; camera yaw 0), sprint, action]
const PLANS := {
	"loco": [
		[0.0, Vector3.ZERO, false, ""], [1.6, Vector3(0, 0, -1), false, ""], [4.2, Vector3(0, 0, -1), true, ""],
		[7.0, Vector3.ZERO, false, ""], [8.6, Vector3(0, 0, 1), false, "face"], [10.2, Vector3(1, 0, 0), false, "face"],
		[11.8, Vector3.ZERO, false, "spin"], [13.4, Vector3.ZERO, false, ""], [14.0, Vector3.ZERO, false, "end"],
	],
	"combat": [
		[0.0, Vector3.ZERO, false, "foe"], [0.5, Vector3.ZERO, false, "lock"], [0.8, Vector3(1, 0, 0), false, ""],
		[3.4, Vector3(0, 0, 1), false, ""], [4.8, Vector3.ZERO, false, "unlock"], [5.0, Vector3(-1, 0, -1), true, "cast"],
		[6.6, Vector3(1, 0, 0), true, "cast"], [8.0, Vector3.ZERO, false, ""], [8.2, Vector3.ZERO, false, "still"],
		[21.0, Vector3.ZERO, false, "end"],
	],
	"trav": [
		[0.0, Vector3.ZERO, false, "tp:10,0,6"], [0.3, Vector3(0, 0, -1), true, ""],
		[2.6, Vector3.ZERO, false, "tp:20,0,4"], [2.9, Vector3(0, 0, -1), false, ""], [3.85, Vector3(0, 0, -1), false, "jump"],
		[4.15, Vector3(0, 0, -1), false, ""],
		[6.6, Vector3.ZERO, false, "tp:30,0,3"], [6.9, Vector3(0, 0, -1), false, ""], [7.6, Vector3(0, 0, -1), false, "jump"],
		[7.72, Vector3(0, 0, -1), false, ""], [7.92, Vector3(0, 0, -1), false, "jump"], [8.1, Vector3.ZERO, false, ""],
		[9.6, Vector3.ZERO, false, "tp:40,1.5,4"], [9.9, Vector3(0, 0, -1), false, ""],
		[13.4, Vector3.ZERO, false, "tp:50,0,4"], [13.7, Vector3(0, 0, -1), false, ""], [14.3, Vector3(0, 0, -1), false, "dodge"],
		[14.45, Vector3(0, 0, -1), false, ""], [15.4, Vector3.ZERO, false, ""],
		[15.8, Vector3.ZERO, false, "tp:60,4,6"], [16.0, Vector3(0, 0, -1), true, ""], [18.2, Vector3.ZERO, false, ""],
		[18.6, Vector3.ZERO, false, "tp:70,7,5.5"], [18.9, Vector3(0, 0, -1), false, ""], [21.5, Vector3.ZERO, false, "end"],
	],
	"jump": [
		[0.0, Vector3.ZERO, false, ""], [1.0, Vector3(0, 0, -1), true, ""], [2.6, Vector3(0, 0, -1), true, "jump"],
		[2.9, Vector3(0, 0, -1), true, ""], [4.2, Vector3(0, 0, -1), true, "slide"], [5.6, Vector3.ZERO, false, ""],
		[7.0, Vector3.ZERO, false, "end"],
	],
}
## [name, start time s, frames, every n rendered frames]
const BURSTS := {
	"loco": [["start", 1.55, 10, 3], ["walk", 3.0, 10, 2], ["sprint", 6.0, 10, 2], ["stop", 6.95, 12, 3],
		["back", 9.6, 10, 3], ["strafe", 11.1, 10, 3], ["spin", 11.9, 10, 5]],
	"jump": [["jump", 2.55, 10, 4], ["land", 3.0, 10, 3], ["slide", 4.15, 10, 4]],
	"combat": [["lock_strafe", 1.6, 10, 4], ["backpedal", 3.8, 10, 3], ["cast_diag", 5.6, 10, 3], ["cast_side", 7.1, 10, 3],
		["idle", 12.5, 12, 40]],
	"trav": [["vault", 0.95, 10, 2], ["grab", 3.9, 10, 3], ["climb", 4.5, 10, 3], ["wallkick", 7.8, 10, 3],
		["beam", 10.6, 10, 4], ["roll", 14.25, 10, 2], ["fall_roll", 16.7, 12, 4], ["steep", 19.5, 12, 4]],
}
var p: Player
var rig: CharacterRig
var cam: Camera3D
var tag := "now"
var plan_name := "loco"
var view := "side"
var t := 0.0
var started := false
var plan_i := 0
var face := false
var spin := false
var burst_i := 0
var burst_frame := 0
var burst_skip := 0
var rows: Array = []                 ## [name, Array[Image]]
var cur: Array[Image] = []
var slide_d := 0.0
var raw_d := 0.0                  ## the same with every grounded sole counted, rolls and steep scrambles too
var seg_slide := {}                ## plan step index -> [planted slide m, travel m]
var slide_tgt := 0.0
var prev_tgt := [Vector3.INF, Vector3.INF]
var seg_sw := {}
var slide_sw := 0.0              ## the part of slide_d made while that foot was in its swing (not planted)
var travel := 0.0
var prev_feet := [Vector3.INF, Vector3.INF]
var prev_pos := Vector3.INF
var legacy := false
var foe: Enemy
var casting := false
var cast_t := 0.0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.trim_prefix("--tag=")
		elif a.begins_with("--plan="):
			plan_name = a.trim_prefix("--plan=")
		elif a.begins_with("--cam="):
			view = a.trim_prefix("--cam=")
		elif a == "--legacy-legs":
			legacy = true
	Travel._busy = true
	Engine.max_fps = 60
	process_physics_priority = -10
	get_window().size = Vector2i(960, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	_studio()
	_spawn_player()


func _studio() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.3, 0.31, 0.34)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.6, 0.6, 0.65)
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(-0.7, 0.6, 0)
	key.light_energy = 1.3
	key.shadow_enabled = true
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(-0.3, -2.4, 0)
	fill.light_energy = 0.5
	add_child(fill)
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for y in 64:
		for x in 64:
			var on := ((x / 32) + (y / 32)) % 2 == 0
			img.set_pixel(x, y, Color(0.34, 0.34, 0.36) if on else Color(0.2, 0.2, 0.22))
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3(1, 1, 1) * 2.0          # 0.5 m checks
	mat.roughness = 0.95
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_box(Vector3(30, -0.5, -30), Vector3(110, 1, 140), mat)
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.42, 0.4, 0.38)
	stone.roughness = 0.9
	_box(Vector3(10, 0.45, -2.2), Vector3(4, 0.9, 0.4), stone)                  # vault wall
	_box(Vector3(20, 1.0, -6), Vector3(4, 2.0, 8), stone)                       # 2 m block (face z -2)
	_box(Vector3(30, 2.5, -2.5), Vector3(4, 5, 1), stone)                       # tall wall (face z -2)
	_box(Vector3(40, 0.75, 4), Vector3(4, 1.5, 4), stone)                       # beam: platform,
	_box(Vector3(40, 1.35, -4), Vector3(0.3, 0.3, 12), stone)                   # the beam,
	_box(Vector3(40, 0.75, -12), Vector3(4, 1.5, 4), stone)                     # platform
	_box(Vector3(60, 2.0, 6), Vector3(4, 4, 6), stone)                          # 4 m drop at z 3
	var sa := deg_to_rad(55.0)
	var srun := 7.0 / tan(sa)
	_box(Vector3(70, 3.5, 5), Vector3(4, 7, 4), stone)                          # 7 m top, edge z 3
	_box(Vector3(70, 3.5 - 0.5 * cos(sa), 3.0 - srun * 0.5), Vector3(4, 1, 7.0 / sin(sa) + 0.3), stone, Vector3(-sa, 0, 0))


func _box(pos: Vector3, size: Vector3, mat: Material, rot := Vector3.ZERO) -> void:
	var b := StaticBody3D.new()
	b.collision_layer = WORLD
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	b.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	b.add_child(mi)
	add_child(b)
	b.position = pos
	b.rotation = rot


func _spawn_player() -> void:
	var pl := CharacterBody3D.new()
	pl.name = "Player"
	pl.set_script(load("res://core/player/player.gd"))
	pl.floor_max_angle = 0.80285144
	pl.floor_snap_length = 0.5
	var col := CollisionShape3D.new()
	col.name = "Collision"
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.7
	col.shape = cap
	col.position.y = 0.85
	pl.add_child(col)
	var vis := Node3D.new()
	vis.name = "Visual"
	vis.set_script(load("res://core/player/character_rig.gd"))
	pl.add_child(vis)
	var r := Node3D.new()
	r.name = "CameraRig"
	r.position.y = 1.55
	pl.add_child(r)
	var pitch := Node3D.new()
	pitch.name = "Pitch"
	r.add_child(pitch)
	var arm := SpringArm3D.new()
	arm.name = "SpringArm"
	pitch.add_child(arm)
	var pcam := Camera3D.new()
	pcam.name = "Camera"
	arm.add_child(pcam)
	pl.position = Vector3(0, 0.05, 20)
	add_child(pl)
	p = pl as Player
	rig = vis as CharacterRig
	if legacy:
		rig.foot_ik = false
	cam = Camera3D.new()
	cam.fov = 38.0
	add_child(cam)
	cam.current = true


func _physics_process(delta: float) -> void:
	if p == null:
		return
	if not started:
		t += delta
		if t > 0.5:
			started = true
			t = 0.0
			p.teleport(Vector3(0, 0.05, 20))
			p.set_view(0.0, -0.2)
		return
	t += delta
	var plan: Array = PLANS[plan_name]
	while plan_i < plan.size() and t >= float(plan[plan_i][0]):
		var e: Array = plan[plan_i]
		var act := String(e[3])
		face = act == "face"
		spin = act == "spin"
		casting = act == "cast"
		match act:
			"foe":
				foe = (load("res://core/enemy/wretch.gd") as GDScript).new() as Enemy
				add_child(foe)
				foe.global_position = Vector3(0, 0.1, 13)
				foe.home = foe.global_position
				foe.sleep()
				foe.chase_range = 0.0
			"lock":
				p._toggle_lock()
			"unlock":
				p._release_lock()
				if is_instance_valid(foe):
					foe.queue_free()
				p.set_view(0.0, -0.2)
		if act == "end":
			_finish()
			return
		if act.begins_with("tp:"):
			var v := act.trim_prefix("tp:").split(",")
			p.teleport(Vector3(float(v[0]), float(v[1]) + 0.05, float(v[2])))
			p.set_view(0.0, -0.2)
		p.debug_drive(e[1] as Vector3, e[2])
		for a: String in ["jump", "slide", "dodge"]:
			if a == act:
				Input.action_press(a)
			elif Input.is_action_pressed(a):
				Input.action_release(a)
		plan_i += 1
	if casting:
		cast_t -= delta
		p.set_view(0.0, -0.2)
		if cast_t <= 0.0:
			cast_t = 0.3
			p.note_combat()
			p.fire_bolt({})
			Events.skill_cast.emit(&"bolt")
	if face:
		p.note_combat()                      # body faces the camera yaw: back-pedal / strafe
	if spin:
		p.note_combat()
		p.set_view(p._yaw + delta * 2.4, -0.2)
	if OS.get_cmdline_user_args().has("--trace") and plan_name == "trav" and t > 18.6:
		print("  t=%.2f pos=%s v=%s steep=%.2f rig_steep=%.2f grounded=%s" % [t, p.global_position.snapped(Vector3.ONE * 0.01), p.velocity.snapped(Vector3.ONE * 0.01), p._steep_k, rig.steep, p.is_grounded()])
	if OS.get_cmdline_user_args().has("--trace-idle") and Engine.get_physics_frames() % 30 == 0:
		print("  t=%.1f still=%.2f ia=%d k=%.2f next=%.1f cast_t=%.2f hit=%.2f mv_t=%.2f slide=%.2f charge=%.2f" % [t, rig._still, rig._ia, rig._ia_k, rig._ia_next, rig._cast_t, rig._hit, rig._mv_t, rig.slide, rig.charge])
	# foot slide: a sole low enough to be on the ground that still moved
	for i in 2:
		var f := rig.socket("foot_" + ("l" if i == 0 else "r")).global_position
		if prev_feet[i] != Vector3.INF and f.y < 0.03 and (prev_feet[i] as Vector3).y < 0.03 and p.is_grounded():
			raw_d += Vector2(f.x - prev_feet[i].x, f.z - prev_feet[i].z).length()
		if prev_feet[i] != Vector3.INF and f.y < 0.03 and (prev_feet[i] as Vector3).y < 0.03 and p.is_grounded() and rig._plant_k > 0.5:
			var dd := Vector2(f.x - prev_feet[i].x, f.z - prev_feet[i].z).length()
			slide_d += dd
			if rig._f_sw[i]:
				slide_sw += dd
				var sw3: Array = seg_sw.get(plan_i, [0.0])
				sw3[0] += dd
				seg_sw[plan_i] = sw3
			else:
				var sg: Array = seg_slide.get(plan_i, [0.0, 0.0])
				sg[0] += dd
				seg_slide[plan_i] = sg
		var tg: Vector3 = rig._f_out[i]
		if prev_tgt[i] != Vector3.INF and not rig._f_sw[i] and f.y < 0.03 and p.is_grounded():
			slide_tgt += Vector2(tg.x - prev_tgt[i].x, tg.z - prev_tgt[i].z).length()
		if OS.get_cmdline_user_args().has("--ft") and t > 3.0 and t < 3.6 and i == 0:
			print("FT t=%.3f sw=%s out=%s foot=%s d=%.4f" % [t, rig._f_sw[i], (tg - p.global_position).snapped(Vector3.ONE * 0.001), f.snapped(Vector3.ONE * 0.001), Vector2(tg.x - prev_tgt[i].x, tg.z - prev_tgt[i].z).length() if prev_tgt[i] != Vector3.INF else 0.0])
		prev_tgt[i] = tg
		prev_feet[i] = f
	if prev_pos != Vector3.INF:
		var td := Vector2(p.global_position.x - prev_pos.x, p.global_position.z - prev_pos.z).length()
		travel += td
		var sg2: Array = seg_slide.get(plan_i, [0.0, 0.0])
		sg2[1] += td
		seg_slide[plan_i] = sg2
	prev_pos = p.global_position


func _process(_d: float) -> void:
	if p == null or not started:
		return
	var body := p.get_global_transform_interpolated().origin
	var dir := Vector3(1, 0, 0)
	match view:
		"q34":
			dir = Vector3(0.7, 0, -0.7).normalized()
		"back":
			dir = Vector3(0, 0, 1)
		"front":
			dir = Vector3(0, 0, -1)
	cam.global_position = body + dir * 4.2 + Vector3.UP * 1.05
	cam.look_at(body + Vector3.UP * 0.85)
	var bursts: Array = BURSTS.get(plan_name, [])
	if burst_i >= bursts.size():
		return
	var b: Array = bursts[burst_i]
	if t < float(b[1]):
		return
	burst_skip -= 1
	if burst_skip > 0:
		return
	burst_skip = int(b[3])
	var img := get_viewport().get_texture().get_image()
	var w := img.get_width()
	var h := img.get_height()
	img = img.get_region(Rect2i(w / 2 - h * 3 / 8, 0, h * 3 / 4, h))
	img.resize(180, 240, Image.INTERPOLATE_BILINEAR)
	cur.append(img)
	burst_frame += 1
	if burst_frame >= int(b[2]):
		rows.append([String(b[0]), cur.duplicate()])
		cur.clear()
		burst_frame = 0
		burst_skip = 0
		burst_i += 1


func _finish() -> void:
	set_physics_process(false)
	print("SEQ slide %.3f m over %.1f m travelled = %.1f cm/m (swing part %.1f, planted part %.1f)%s" % [slide_d, travel, 100.0 * slide_d / maxf(travel, 0.01), 100.0 * slide_sw / maxf(travel, 0.01), 100.0 * (slide_d - slide_sw) / maxf(travel, 0.01), " (legacy legs)" if legacy else ""])
	print("SEQ raw (all grounded soles, rolls included) %.1f cm/m" % (100.0 * raw_d / maxf(travel, 0.01)))
	print("SEQ tgt-slide %.1f cm/m" % (100.0 * slide_tgt / maxf(travel, 0.01)))
	if OS.get_cmdline_user_args().has("--segs"):
		for k: int in seg_slide:
			var sg: Array = seg_slide[k]
			print("SEQ seg %d (t>=%.1f) planted slide %.3f m, swing %.3f m, over %.2f m (%s)" % [k - 1, float(PLANS[plan_name][maxi(k - 1, 0)][0]), sg[0], (seg_sw.get(k, [0.0]) as Array)[0], sg[1], PLANS[plan_name][maxi(k - 1, 0)][3]])
	if not rows.is_empty():
		var cols := 0
		for r: Array in rows:
			cols = maxi(cols, (r[1] as Array).size())
		var sheet := Image.create(180 * cols, 240 * rows.size(), false, Image.FORMAT_RGB8)
		for ri in rows.size():
			var frames: Array = rows[ri][1]
			for ci in frames.size():
				var im: Image = frames[ci]
				im.convert(Image.FORMAT_RGB8)
				sheet.blit_rect(im, Rect2i(0, 0, 180, 240), Vector2i(ci * 180, ri * 240))
		var path := "res://shots/seq_%s_%s_%s.png" % [tag, plan_name, view]
		sheet.save_png(ProjectSettings.globalize_path(path))
		print("SEQ sheet ", path, " rows=", rows.map(func(r: Array) -> String: return r[0]))
	print("SEQ done")
	get_tree().quit()
