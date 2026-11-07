extends Node
## ACTION TRAILER, directed and recorded in one pass (no editing): every cut, camera move, cast,
## spawn and weather cue happens in this script, frame-exact, while Godot's Movie Maker writes the
## frames and the engine's own audio mix.
##   HOME=<scratch>/home godot --path . --write-movie /abs/trailer.avi --fixed-fps 60 \
##       --resolution 1920x1080 res://zz/trailer.tscn
## Camera grammar, four styles: the game's own GAMEPLAY camera (runs, the first fight), a fixed north-up
## TOP-DOWN view at 65 deg like a top-down game (the big fight, the boss's rings), true FIRST PERSON
## (the run, the lance) and slow CINEMATIC framing (hero, storm, depths, the boss's heroic angle, the
## finale). Every free camera is collision-checked against the world (a camera arm) and eased, and
## every shot's framing is measured: `FRAME <shot> h=<subject height / frame> in=<inside> occl=...`. The action plays on the open green (villagers stood down for the shoot), a
## soft fill light follows it. Cinematic settings in memory (TAA), HUD and floating words hidden.
## Saves held. Quits by itself.

const Order := preload("res://zz/trailer_order.gd")
const Cam := preload("res://zz/trailer_cam.gd")
const Qc := preload("res://zz/trailer_qc.gd")
const Act1 := preload("res://zz/trailer_shots_act1.gd")
const Act2 := preload("res://zz/trailer_shots_act2.gd")
const Act3 := preload("res://zz/trailer_shots_act3.gd")
const Act4 := preload("res://zz/trailer_shots_act4.gd")
const LEAD_FRAMES := 6                         ## black frames while a far cut settles (trimmed by the assembly)
var SHOTS: Array = []
const GREEN := Vector3(2.0, 0.0, 34.0)        ## the village green (the finale's foreground)
const ARENA := Vector3(-24.0, 0.0, 60.0)      ## the fight ground: open, outside every sanctuary's light
const WEST := PI * 0.5                         ## facing west down the road
const WRETCH_P := "res://core/enemy/wretch.gd"
const HUSK_P := "res://core/enemy/husk.gd"
const BULWARK_P := "res://core/enemy/bulwark.gd"
const CHANTER_P := "res://core/enemy/chanter.gd"
const MITE_P := "res://core/enemy/mite.gd"
const ABBOT_P := "res://core/enemy/bone_abbot.gd"
const StaffSfx := preload("res://core/vfx/staff_sfx.gd")
const PIT := Vector3(16.0, 4.3, -86.0)         ## the Ossuary pit floor (16 x 16 m at y 4.2): the Abbot's own ground
const PIT_PLAYER := Vector3(16.0, 4.3, -80.5)
const PIT_BOSS := Vector3(16.0, 4.3, -90.5)
const TOP_PITCH := 65.0                        ## degrees down for the top-down view
const TOUGH := 1.0                             ## enemies' health for the shoot: the game's own, so they fall to the bolts

var main: Node
var _qc := Qc.new(self)
var p: Player
var book: Node
var life: Node
var cam: Camera3D
var pcam: Camera3D
var key: OmniLight3D
var phase := "load"
var wait := 0.0
var si := -1
var t := 0.0
var frame := 0
var spawned: Array[Node] = []
var boss: Node
var flags := {}
var _cam_pos := Vector3.ZERO
var _cam_at := Vector3.ZERO
var _snap := true
var _want: PackedStringArray = []
var _preview := false
var _provs: Array = []
var _cur: Object
var _lead := 0
var hollow_ok := false                        ## a shot that shows the Gloom lets it run (cleared at each cut)
var lead_black: ColorRect
var keep_menus := false                        ## menu layers (58..64) are left alone this shot
var keep_hud := false                          ## HUD layers (up to 12) are left alone this shot
var keep_layers: Array[CanvasLayer] = []   ## UI the shot wants on screen (the rest is hidden every frame)
# title layer
var layer: CanvasLayer
var black: ColorRect
var title: Label
var _font: Font


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	SHOTS = Order.ORDER.duplicate()
	for a in OS.get_cmdline_user_args():
		if a == "--list":
			for sh: Array in SHOTS:
				print("SHOT %-14s %.1f s  %s" % [sh[0], float(sh[1]), sh[3] if sh.size() > 3 else ""])
			get_tree().quit()
			return
		elif a.begins_with("--shot=") or a.begins_with("--shots=") or a.begins_with("--only="):
			_want = a.split("=")[1].split(",")
		elif a == "--preview":
			_preview = true
	_provs = [Act4.new(self), Act3.new(self), Act2.new(self), Act1.new(self), self]   # acts first: a rebuilt shot outranks the old director's of the same name
	Travel._busy = true
	Settings.set_preset_fields(2)
	Settings.shadow_quality = 2
	Settings.aa_mode = 2                       # SMAA: clean edges, no TAA ghosting in motion
	if not _preview:
		Settings.window_size_index = 2         # 1920x1080: the window sets Movie Maker's frame size
	Settings.fov = 80.0
	Settings.fullscreen = false
	Settings.monitor = -1
	Settings.vsync = false
	Settings.fps_limit = 0
	_stage_state()
	_build_titles()
	_card("THE SKY TURNS INWARD", 1.0)
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


## The wanderer as the trailer shows them (in memory; Travel._busy holds the save): ranks and oaths sworn, ash in the
## satchel, the Hearthfire raised so the tithe and the Kindling have something to show.
func _stage_state() -> void:
	Travel.story = {"flags": {"arrived": true, "met_keep": true}, "picked": {}}
	Travel.items = {"grave_ash": 160, "relic_fragment": 2}
	Travel.systems = {"progression": {"memory": 900, "ranks": {"bolt": 2, "lance": 2, "nova": 1, "ward": 1, "step": 1, "will": 2, "warmth": 2},
			"oaths": {"1": "a", "2": "a"}, "known": ["tether", "well", "familiar"], "spent": 120},
		"hearth": {"tier": 1, "works": {"baskets": true}, "rested": 300.0}}


# --- titles ---------------------------------------------------------------------------------------

func _build_titles() -> void:
	_font = load("res://ui/fonts/Cinzel.ttf")
	layer = CanvasLayer.new()
	layer.name = "TrailerTitles"
	layer.layer = 125
	add_child(layer)
	black = ColorRect.new()
	black.color = Color(0.0, 0.0, 0.01)
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(black)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(box)
	title = Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", _font)
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color("#C9B8FF"))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	title.add_theme_constant_override("outline_size", 6)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(title)
	lead_black = ColorRect.new()
	lead_black.color = Color(0.0, 0.0, 0.01, 0.0)
	lead_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	lead_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(lead_black)


func _card(text: String, bg_a: float) -> void:
	title.text = text
	title.modulate.a = 1.0
	black.color.a = bg_a


func _clear_card() -> void:
	title.text = ""
	black.color.a = 0.0


# --- the run --------------------------------------------------------------------------------------

func _process(d: float) -> void:
	frame += 1
	if p == null:
		p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		if p:
			Settings.changed.emit()
		return
	if phase == "load":
		if Realm.enabled() and not main.has_meta("realm_done"):
			return
		phase = "settle"
		wait = 0.0
		return
	if phase == "settle":
		wait += d
		if wait < 2.0:
			return
		_setup_world()
		phase = "shots"
		_next_shot()
		return
	if phase != "shots":
		return
	if _lead > 0:
		_lead -= 1
		_hide_overlays()
		_fn("u", String(SHOTS[si][0])).call(0.0)
		_apply_cam(d)
		if _lead == 0:
			lead_black.color.a = 0.0
			print("CLIP %s start=%d drawn=%d dur=%.2f" % [SHOTS[si][0], frame + 1, Engine.get_frames_drawn() + 1, float(SHOTS[si][1])])
		return
	t += d
	if not hollow_ok:
		p.gloom = 0.0; p.wounds = 0.0                                      # the wanderer is the star: no hollowing
	_keep_alive()
	_cull_strays()
	_steer(d)
	_drive_now(d)
	_motion_stats(d)
	_hide_overlays()                                    # every frame: a popped word must never show
	var id: String = SHOTS[si][0]
	if t < 1.1 and int(round(t * 60.0)) % 15 == 1:
		var vc := get_viewport().get_camera_3d()
		print("CUTDBG %s t=%.2f frame=%d drawn=%d proc=%d cam=%s paused=%s pp=%s" % [id, t, frame, Engine.get_frames_drawn(), Engine.get_process_frames(), vc.name if vc else "-", get_tree().paused, pp().snapped(Vector3.ONE * 0.1)])
	_fn("u", id).call(t)
	_apply_cam(d)
	_qc.step(id, t, d, _drive_to, _sprint)
	if frame % 15 == 0 and not (id in Order.NO_SUBJECT):
		_frame_check(id)
	if t >= float(SHOTS[si][1]):
		_next_shot()


func _setup_world() -> void:
	for n in get_tree().get_nodes_in_group(Groups.ENEMY):
		(n as Node).queue_free()
	# the villagers are stood down for the shoot: the green is the stage
	for n in main.find_children("*", "Node3D", true, false):
		var s: Script = n.get_script()
		if s and String(s.resource_path).ends_with("villager.gd"):
			(n as Node3D).visible = false
			n.process_mode = Node.PROCESS_MODE_DISABLED
	for c in p.get_children():
		if c is SkillBook:
			book = c
	if book:
		book.set("using_pad", true)                    # the book only reads input with a pad or captured mouse
	# a little more light for the camera than the game uses (in memory only)
	var we := main.find_child("WorldEnvironment", true, false) as WorldEnvironment
	if we and we.environment:
		we.environment.tonemap_exposure *= 1.22
	# the game's own encounter spawner is stood down: the script casts every fight
	var enc := main.find_child("Encounters", true, false)
	if enc:
		enc.process_mode = Node.PROCESS_MODE_DISABLED
	life = main.find_child("Wildlife", true, false)
	if life:
		life.set("glide", false)                        # creatures near the lens think every frame: no stepping
	pcam = p.get_node_or_null("CameraRig/Pitch/SpringArm/Camera") as Camera3D
	cam = Camera3D.new()
	cam.name = "TrailerCam"
	cam.fov = 62.0
	cam.far = 500.0
	if pcam:
		cam.attributes = pcam.attributes
		cam.environment = pcam.environment
	main.add_child(cam)
	key = OmniLight3D.new()                             # a soft fill that follows the action
	key.name = "TrailerKey"
	key.light_color = Color(0.62, 0.72, 1.0)
	key.light_energy = 3.0
	key.omni_range = 24.0
	key.omni_attenuation = 1.4
	key.shadow_enabled = false
	main.add_child(key)
	print("TRAILER start frame %d window %s screen %s usable %s scale %s" % [frame, get_window().size, DisplayServer.screen_get_size(get_window().current_screen), DisplayServer.screen_get_usable_rect(get_window().current_screen).size, DisplayServer.screen_get_scale(get_window().current_screen)])


func _next_shot() -> void:
	if si >= 0 and _cur != null:
		var prev: String = SHOTS[si][0]
		_motion_report(prev)
		_qc.report(prev)
		var ef := _fn("e", prev)
		if ef.is_valid():
			ef.call()
		print("CLIP_END %s frame=%d drawn=%d" % [prev, frame, Engine.get_frames_drawn()])
	si += 1
	while not _want.is_empty() and si < SHOTS.size() and not (SHOTS[si][0] in _want):
		si += 1
	t = 0.0
	_snap = true
	flags.clear()
	hollow_ok = false
	if si >= SHOTS.size():
		print("TRAILER done frame %d" % frame)
		phase = "done"
		get_tree().quit()
		return
	var id: String = SHOTS[si][0]
	print("TRAILER shot %s at frame %d drawn %d" % [id, frame, Engine.get_frames_drawn()])
	_cur = null
	for pv in _provs:
		if pv.has_method("_u_" + id) or (pv.has_method("_u_any") and pv.call("handles", id)):
			_cur = pv
			break
	if _cur == null:
		print("TRAILER no shot named %s: skipped" % id)
		_next_shot()
		return
	_release_inputs()
	_clear_card()
	keep_layers.clear()
	keep_menus = false
	keep_hud = false
	var sf := _fn("s", id)
	if sf.is_valid():
		sf.call()
	_lead = LEAD_FRAMES
	lead_black.color.a = 1.0


func _fn(k: String, id: String) -> Callable:
	if _cur.has_method("_%s_%s" % [k, id]):
		return Callable(_cur, "_%s_%s" % [k, id])
	if _cur.has_method("_%s_any" % k):
		return Callable(_cur, "_%s_any" % k).bind(id)
	return Callable()


func _kept(c: Node) -> bool:
	var ly := (c as CanvasLayer).layer
	if keep_menus and ly >= 58 and ly <= 64:
		return true                                       # the character screen and the pages it hosts open themselves
	if keep_hud and ly <= 12:
		return true                                       # the HUD and its readouts (they show and hide themselves)
	for k in keep_layers:
		if k == c or k.is_ancestor_of(c):
			return true
	return false


func _hide_overlays() -> void:
	for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if c == layer or String(c.name) == "Grade":
			continue
		if _kept(c):
			if (keep_menus and String(c.name) in ["CharacterScreen", "Backdrop", "GearPanel", "Kindling", "Codex", "WorldMap"]) or keep_hud:
				(c as CanvasLayer).visible = true      # an earlier cut hid it; it shows and hides its own contents
		else:
			(c as CanvasLayer).visible = false
	for l in get_tree().root.find_children("*", "Label3D", true, false):
		(l as Label3D).visible = false                  # floating combo words and damage numbers



## Anything the script didn't cast (an ambush, a tide) leaves the stage at once.
## Glitch meter: the wanderer's largest turn in one frame (deg) and the fastest any foe moved between
## two frames (m/s), per shot, printed at each cut as `MOTION <shot> turn=.. foe=..`.
var _m_yaw := NAN
var _m_turn := 0.0
var _m_foe := 0.0
var _m_last := {}


func _motion_stats(d: float) -> void:
	var y := float(p.get("_yaw"))
	if not is_nan(_m_yaw) and t > 0.05:
		_m_turn = maxf(_m_turn, rad_to_deg(absf(wrapf(y - _m_yaw, -PI, PI))))
	_m_yaw = y
	for e in spawned:
		if not is_instance_valid(e) or not (e is Node3D):
			continue
		var pos := (e as Node3D).global_position
		var id := e.get_instance_id()
		if _m_last.has(id) and t > 0.05 and d > 0.0:
			_m_foe = maxf(_m_foe, (pos - (_m_last[id] as Vector3)).length() / d)
		_m_last[id] = pos


func _motion_report(id: String) -> void:
	print("MOTION %-11s turn %.1f deg/frame  foe %.1f m/s" % [id, _m_turn, _m_foe])
	_m_turn = 0.0
	_m_foe = 0.0
	_m_yaw = NAN
	_m_last.clear()


func _cull_strays() -> void:
	for e in get_tree().get_nodes_in_group(Groups.ENEMY):
		if is_instance_valid(e) and not spawned.has(e):
			(e as Node).queue_free()


# --- performance: the wanderer is steered like a player, never snapped -------------------------------

var _aiming := false
var _aim := Vector3.ZERO
var _target: Node3D
var _drive := Vector3.ZERO
var _drive_to := Vector3.ZERO
var _sprint := false


## Turn toward `v` the way a mouse would: eased, capped at ~230 deg/s.
func aim_at(v: Vector3) -> void:
	_aim = v
	_aiming = true


func _steer(d: float) -> void:
	if not _aiming:
		return
	var to := _aim - p.global_position
	to.y = 0.0
	if to.length() < 0.4:
		return
	var cur := float(p.get("_yaw"))
	var diff := wrapf(atan2(-to.x, -to.z) - cur, -PI, PI)
	var step := clampf(diff * (1.0 - exp(-d * 7.0)), -d * 4.0, d * 4.0)
	p.set_view(cur + step, float(p.get("_pitch")))


## One foe at a time: keep it until it falls, then take the nearest.
func target() -> Node3D:
	if not is_instance_valid(_target) or not _target.is_in_group(Groups.ENEMY):
		_target = nearest_foe()
	return _target


## Walk/run where `dir` points (world space); the stick eases in and out instead of switching.
func drive(dir: Vector3, run := false) -> void:
	_drive_to = Vector3(dir.x, 0.0, dir.z)
	_sprint = run


func _drive_now(d: float) -> void:
	_drive = _drive.move_toward(_drive_to, d * 3.5)
	p.debug_drive(_drive, _sprint)


func _keep_alive() -> void:
	for e in spawned:
		if is_instance_valid(e) and e != boss:
			continue
		if is_instance_valid(e) and e == boss:
			var mx := float(boss.get("max_hp"))
			if float(boss.get("hp")) < mx * 0.12:
				boss.set("hp", mx * 0.12)              # the Abbot stays up for the whole sequence


# --- camera ---------------------------------------------------------------------------------------

## Aim the free camera: from `from` at `at`, pulled in toward `at` if the world is in the way (a
## camera arm). Eased unless the shot just cut.
func frame_cam(from: Vector3, at: Vector3) -> void:
	var space: PhysicsDirectSpaceState3D = (main as Node3D).get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(at, from, Layers.WORLD | Layers.PROPS)
	q.exclude = [p.get_rid()]
	var hit: Dictionary = space.intersect_ray(q)
	if not hit.is_empty():
		from = (hit.position as Vector3) + (at - from).normalized() * 0.35
	_cam_pos = from
	_cam_at = at


func _apply_cam(d: float) -> void:
	if cam == null or not cam.current:
		return
	var snap := _snap
	_snap = false
	cam.global_position = _cam_pos if snap else cam.global_position.lerp(_cam_pos, 1.0 - exp(-d * 9.0))
	var dirv := _cam_at - cam.global_position
	if dirv.length() > 0.01:
		var up := Vector3.UP if absf(dirv.normalized().y) < 0.985 else Vector3.FORWARD
		var want := Transform3D.IDENTITY.looking_at(dirv, up).basis
		cam.global_basis = want if snap else cam.global_basis.slerp(want, 1.0 - exp(-d * 10.0)).orthonormalized()


## A camera spot near `around` that can see every point in `look`: tried at `dist` metres out along
## yaw `yaw0` (direction from `around` to the lens: (sin, 0, cos)), then swinging either side and
## nearer/farther, `h` above the floor. Rejected: inside or within half a metre of anything solid,
## anything solid between the lens and a look point, hanging over a drop.
func solve_cam(look: Array, around: Vector3, yaw0: float, dist: float, h: float) -> Vector3:
	var space := (main as Node3D).get_world_3d().direct_space_state
	var ball := SphereShape3D.new()
	ball.radius = 0.5
	var sq := PhysicsShapeQueryParameters3D.new()
	sq.shape = ball
	sq.collision_mask = Layers.WORLD | Layers.PROPS
	sq.exclude = _actor_rids()
	for pass_i in 3:
		ball.radius = 0.5 if pass_i < 2 else 0.3
		var hh := h + (1.4 if pass_i == 1 else 0.0)
		var c := _solve_pass(look, around, yaw0, dist, hh, space, sq)
		if c != Vector3.INF:
			_whys.clear()
			return c
	print("TRAILER solve_cam: no clear spot near %s %s" % [around, _whys])
	_whys.clear()
	return around + Vector3(sin(yaw0), 0.0, cos(yaw0)) * dist * 0.5 + Vector3.UP * (h + 1.5)


func _solve_pass(look: Array, around: Vector3, yaw0: float, dist: float, h: float, space: PhysicsDirectSpaceState3D, sq: PhysicsShapeQueryParameters3D) -> Vector3:
	for dd: float in [dist, dist * 0.8, dist * 1.25, dist * 0.6]:
		for off: float in [0.0, 0.3, -0.3, 0.6, -0.6, 0.9, -0.9, 1.3, -1.3, 1.8, -1.8, 2.4, -2.4, PI]:
			var y := yaw0 + off
			var c := around + Vector3(sin(y), 0.0, cos(y)) * dd
			var fl := space.intersect_ray(PhysicsRayQueryParameters3D.create(c + Vector3.UP * (h + 1.5), c + Vector3.DOWN * 4.0, Layers.WORLD))
			if fl.is_empty():
				_why("nofloor")
				continue
			var floor_y: float = (fl.position as Vector3).y
			c.y = maxf(around.y + h, floor_y + 0.7)
			if c.y - floor_y > h + 2.5:
				_why("drop")
				continue
			sq.transform = Transform3D(Basis(), c)
			var bh := space.intersect_shape(sq, 1)
			if not bh.is_empty():
				_why("ball:" + _cname(bh[0]))
				continue
			var ok := true
			for v: Vector3 in look:
				var q := PhysicsRayQueryParameters3D.create(c, v, Layers.WORLD | Layers.PROPS)
				q.exclude = _actor_rids()
				var lh := space.intersect_ray(q)
				if not lh.is_empty():
					_why("los:" + _cname(lh))
					ok = false
					break
			if ok:
				return c
	return Vector3.INF


var _whys := {}


## The wanderer and the cast: the lens looks at them, they never block it.
func _actor_rids() -> Array[RID]:
	var out: Array[RID] = [p.get_rid()]
	for e in spawned:
		if is_instance_valid(e) and e is CollisionObject3D:
			out.append((e as CollisionObject3D).get_rid())
	return out


func _why(k: String) -> void:
	_whys[k] = int(_whys.get(k, 0)) + 1


func _cname(hit: Dictionary) -> String:
	var o: Object = hit.get("collider")
	return String((o as Node).name) if o is Node else str(o)


func yaw_to(v: Vector3) -> float:
	return atan2(v.x, v.z)


## A locked-off lens at `at` that pans to follow `look` (no arm, no pull-in).
func hold_cam(at: Vector3, look: Vector3) -> void:
	_cam_pos = at
	_cam_at = look

func light_at(v: Vector3, h := 6.0) -> void:
	key.global_position = v + Vector3.UP * h


# --- helpers --------------------------------------------------------------------------------------

func gy(x: float, z: float) -> float:
	return RealmLayout.ground(main.get_world_3d().direct_space_state, x, z)


func on_ground(v: Vector3, up := 0.0) -> Vector3:
	return Vector3(v.x, gy(v.x, v.z) + up, v.z)


func fwd_of(yaw: float) -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


func use_free_cam() -> void:
	cam.current = true


func use_player_cam() -> void:
	if pcam:
		pcam.current = true


func sm(a: float) -> float:
	return a * a * (3.0 - 2.0 * a)


func once(k: String) -> bool:
	if flags.has(k):
		return false
	flags[k] = true
	return true


func press(action: StringName) -> void:
	if action != &"":
		Input.action_press(action)


func release(action: StringName) -> void:
	if action != &"":
		Input.action_release(action)


func _release_inputs() -> void:
	for a in ["skill_bolt", "skill_lance", "jump", "slide", "sprint"]:
		if InputMap.has_action(a):
			Input.action_release(a)


func slot_action(i: int) -> StringName:
	if book == null:
		return &""
	var slots: Array = book.get("slots")
	return slots[i].action if i < slots.size() else &""


func cast(i: int) -> void:
	if book:
		book.call("try_cast", i, 0.0, true)


func spawn(path: String, at: Vector3, tough := TOUGH, probe := true) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var e := (load(path) as GDScript).new() as Node3D
	main.add_child(e)
	e.global_position = on_ground(at, 0.1) if probe else at
	e.set("home", e.global_position)
	var mx: Variant = e.get("max_hp")
	if mx != null:
		e.set("max_hp", int(round(float(mx) * tough)))
		e.set("hp", float(mx) * tough)
	if e.has_method("wake"):
		e.call("wake")
	if e.get("chase_range") != null and e != null and path != ABBOT_P:
		e.set("chase_range", 40.0)
		e.set("hunt_leash", 60.0)
	spawned.append(e)
	return e


func clear_spawned() -> void:
	for e in spawned:
		if is_instance_valid(e):
			e.queue_free()
	spawned.clear()
	boss = null


func put_player(at: Vector3, yaw: float, pitch := -0.12, probe := true) -> void:
	p.teleport(on_ground(at, 0.2) if probe else at)
	p.set_view(yaw, pitch)
	_aiming = false
	_target = null
	_drive = Vector3.ZERO
	_drive_to = Vector3.ZERO
	p.debug_drive(Vector3.ZERO)


func pp() -> Vector3:
	return p.get_global_transform_interpolated().origin


func head() -> Vector3:
	return pp() + Vector3.UP * 1.62


func foes() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for e in spawned:
		if is_instance_valid(e) and e is Node3D and (e as Node).is_in_group(Groups.ENEMY):
			out.append(e as Node3D)
	return out


func nearest_foe() -> Node3D:
	var best: Node3D = null
	var bd := INF
	for e in foes():
		var dd := e.global_position.distance_squared_to(p.global_position)
		if dd < bd:
			bd = dd
			best = e
	return best


func pack_mid() -> Vector3:
	var f := foes()
	if f.is_empty():
		return pp()
	var s := pp()
	for e in f:
		s += e.global_position
	return s / float(f.size() + 1)




func boom(kind := "nova", vol := -2.0) -> void:
	StaffSfx.play(kind, p.global_position, vol, 0.9, 0.0)


## A pack in front of `at` (facing `yaw`), `near` metres out at its closest: far enough that it is
## still closing in when the shot cuts (no close-up brawl, no forcing them back).
func spawn_pack(at: Vector3, yaw: float, near: float) -> void:
	clear_spawned()
	var f := fwd_of(yaw)
	var r := f.cross(Vector3.UP)
	for i in 3:
		spawn(MITE_P, at + f * (near + float(i) * 0.8) + r * (float(i) - 1.0) * 2.2)
	spawn(WRETCH_P, at + f * (near + 2.5) + r * -2.5)
	spawn(WRETCH_P, at + f * (near + 3.0) + r * 2.5)
	spawn(HUSK_P, at + f * (near + 4.5) + r * 0.5)
	spawn(CHANTER_P, at + f * (near + 7.0) + r * -3.5)

# --- shots ----------------------------------------------------------------------------------------
# _s_<id>() setup, _u_<id>(t) every frame, _e_<id>() teardown

func _s_cold() -> void:
	_card("THE SKY TURNS INWARD", 1.0)
	put_player(GREEN, WEST)
	use_free_cam()
	frame_cam(on_ground(GREEN, 3.0), on_ground(GREEN + Vector3(0, 0, -40), 20.0))


func _u_cold(tt: float) -> void:
	title.modulate.a = clampf(tt / 0.3, 0.0, 1.0) * clampf((1.6 - tt) / 0.3, 0.0, 1.0)

func _s_fp_run() -> void:
	put_player(ARENA + Vector3(4.0, 0.0, 0.0), WEST)    # west down the open road toward the wood
	drive(fwd_of(WEST), true)
	_drive = _drive_to                                  # already running as the shot opens
	(p.get_node("Visual") as Node3D).visible = false   # first person: no body in the lens
	use_free_cam()
	cam.fov = 84.0


func _u_fp_run(tt: float) -> void:
	var bob := sin(tt * 15.0) * 0.03
	var h := head() + Vector3.UP * bob
	var f := fwd_of(WEST)
	hold_cam(h + f * 0.25, h + f * 12.0 + Vector3.UP * 0.6)
	_snap = true                                        # first person rides the head exactly
	light_at(h + f * 6.0, 3.0)
	if tt > 0.45 and once("fp_jump"):
		press("jump")
	if tt > 0.55 and once("fp_jump_up"):
		release("jump")
	if tt > 0.85 and once("fp_jump2"):
		press("jump")
	if tt > 0.95 and once("fp_jump2_up"):
		release("jump")
	if tt > 1.45 and once("fp_slide"):
		press("slide")

func _e_fp_run() -> void:
	(p.get_node("Visual") as Node3D).visible = true
	release("slide")
	cam.fov = 62.0


func _s_card_dark() -> void:
	drive(Vector3.ZERO)
	_card("WHAT CLIMBS COMES DOWN HOLLOW", 1.0)
	boom("nova", -1.0)


func _u_card_dark(tt: float) -> void:
	title.modulate.a = clampf(tt / 0.25, 0.0, 1.0)


func _s_fight_otc() -> void:
	_clear_card()
	put_player(ARENA, WEST)
	spawn_pack(ARENA, WEST, 8.0)
	use_player_cam()

func _u_fight_otc(tt: float) -> void:
	# the game's own camera: the pack charging up the road into the bolts, falling as it comes
	light_at(pack_mid(), 7.0)
	var foe := target()
	if foe:
		aim_at(foe.global_position)
	if tt > 0.6:
		drive(-fwd_of(WEST) * 0.4)                      # giving ground while casting
	if tt > 0.15 and once("otc_bolts"):
		press(slot_action(0))                           # Rift Bolt held: a chain, the third a Lash
	if tt > 1.9 and once("otc_lance"):
		release(slot_action(0))
		press(slot_action(1))                           # Ember Lance: draw back...
	if tt > 2.6 and once("otc_lance_go"):
		release(slot_action(1))                         # ...and throw

func _s_fp_lance() -> void:
	release(slot_action(0))
	put_player(ARENA, WEST)
	spawn_pack(ARENA, WEST, 9.0)
	(p.get_node("Visual") as Node3D).visible = false
	use_free_cam()
	cam.fov = 80.0
	press(slot_action(1))

func _u_fp_lance(tt: float) -> void:
	var foe := target()
	aim_at(foe.global_position if foe else pack_mid())
	var aim := fwd_of(float(p.get("_yaw")))           # the lens looks where the wanderer looks
	var h := head()
	hold_cam(h + aim * 0.2, h + aim * 10.0 + Vector3.DOWN * 0.7)
	_snap = true
	light_at(h + aim * 5.0, 3.0)
	if tt > 0.7 and once("fpl_go"):
		release(slot_action(1))
	if tt > 1.0 and once("fpl_bolt"):
		press(slot_action(0))


func _e_fp_lance() -> void:
	release(slot_action(0))
	(p.get_node("Visual") as Node3D).visible = true
	cam.fov = 62.0
	clear_spawned()


func _s_storm() -> void:
	if life and life.get("weather"):
		(life.get("weather") as Node).call("force", "storm", true)
	put_player(ARENA + Vector3(-4.0, 0.0, 0.0), WEST, 0.1)
	use_free_cam()
	cam.fov = 55.0


func _u_storm(tt: float) -> void:
	# low behind the wanderer on the open road, the sky splitting ahead; a slow push in
	var k := sm(clampf(tt / 2.0, 0.0, 1.0))
	var f0 := fwd_of(WEST)
	var from := pp() - f0 * lerpf(4.8, 4.2, k) + Vector3.UP * 1.6 + f0.cross(Vector3.UP) * -1.2
	frame_cam(from, pp() + f0 * 12.0 + Vector3.UP * 2.6)
	light_at(pp(), 4.0)
	var wx: Node = life.get("weather") if life else null
	if wx:
		var f := -cam.global_basis.z
		var yaw := atan2(f.x, f.z)
		if tt > 0.2 and once("strike1"):
			wx.call("strike_near", 70.0, yaw + 0.12)
		if tt > 1.2 and once("strike2"):
			wx.call("strike_near", 40.0, yaw - 0.2)


func _e_storm() -> void:
	var wx: Node = life.get("weather") if life else null
	if wx:
		wx.call("force", "clear", true)
	cam.fov = 62.0


func _s_card_depths() -> void:
	_card("DESCEND", 1.0)
	clear_spawned()
	boom("lance_hit", -3.0)


func _u_card_depths(tt: float) -> void:
	title.modulate.a = clampf(tt / 0.2, 0.0, 1.0)


func _s_depths() -> void:
	_clear_card()
	put_player(Vector3(16.0, 4.6, -83.0), PI)
	use_free_cam()


func _u_depths(tt: float) -> void:
	# in the Ossuary pit: a slow crane up the shaft, turning past the candles and the skulls
	var k := sm(clampf(tt / 4.5, 0.0, 1.0))
	var c := Vector3(16.0, 5.0, -86.0)
	var a := lerpf(-0.6, 1.4, k)
	frame_cam(c + Vector3(sin(a) * 3.0, lerpf(0.8, 6.5, k), cos(a) * 3.0), c + Vector3(0.0, lerpf(1.2, 2.0, k), 0.0))
	light_at(c, 3.0)


var _bl_cam := Vector3.ZERO


func _s_boss_low() -> void:
	use_free_cam()
	cam.fov = 78.0
	(p.get_node("Visual") as Node3D).visible = false
	var bp := (boss as Node3D).global_position if is_instance_valid(boss) else PIT_BOSS
	var back := pp() - bp
	back.y = 0.0
	var spot := solve_cam([bp + Vector3.UP * 2.2, bp + Vector3.UP * 0.8], bp, yaw_to(back.normalized()), 7.0, 1.6)
	var at := Vector3(clampf(spot.x, 9.5, 22.5), PIT.y, clampf(spot.z, -93.0, -79.0))
	back = at - bp
	back.y = 0.0
	put_player(at, yaw_to(back.normalized()), -0.02, false)
	press(slot_action(1))                               # the lance already drawing as we cut in

func _u_boss_low(tt: float) -> void:
	# first person: the Abbot looming up out of the candlelight, the lance thrown into his chest
	var bp := PIT_BOSS
	if is_instance_valid(boss):
		bp = (boss as Node3D).global_position
		aim_at(bp)
	var f := fwd_of(float(p.get("_yaw")))
	var h := head()
	hold_cam(h + f * 0.2, h + f * 8.0 + Vector3.UP * 0.9)
	_snap = true
	light_at(bp + Vector3.UP * 1.5 - f * 1.5, 3.0)
	var away := p.global_position - bp
	away.y = 0.0
	if away.length() < 5.5:
		drive(away.normalized() * 0.45)                 # giving ground as he comes
	if tt > 0.9 and once("boss_lance_go"):
		release(slot_action(1))
	if tt > 1.3 and once("boss_bolts2"):
		press(slot_action(0))

func _e_boss_low() -> void:
	(p.get_node("Visual") as Node3D).visible = true
	drive(Vector3.ZERO)
	_release_inputs()
	cam.fov = 62.0


func _s_finale() -> void:
	clear_spawned()
	put_player(GREEN, 0.0, 0.05)
	use_free_cam()
	var ph: Node = life.get("phenomena") if life else null
	if ph:
		ph.call("trigger", "shower")
		ph.call("trigger", "bolide")


func _u_finale(tt: float) -> void:
	# the wanderer small against the valley, the camera tilting up into the vortex; the title
	var k := sm(clampf(tt / 2.2, 0.0, 1.0))
	frame_cam(pp() + Vector3(1.5, 1.4, 5.0), pp() + Vector3(0.0, lerpf(1.6, 40.0, k), -lerpf(4.0, 60.0, k)))
	light_at(pp(), 4.0)
	if tt > 1.8 and once("title_in"):
		boom("lance_hit", 0.0)
		_card("UMBRAL REACHES", 0.0)
		title.modulate.a = 0.0
	if tt > 1.8:
		title.modulate.a = clampf((tt - 1.8) / 0.5, 0.0, 1.0)
		black.color.a = clampf((tt - 3.8) / 0.7, 0.0, 1.0)

# --- framing ---------------------------------------------------------------------------------------

## How the wanderer sits in the frame: height as a share of the frame, inside or cut, anything solid
## between the lens and the chest, horizontal centre (0..1).
func _frame_check(id: String) -> void:
	var c := get_viewport().get_camera_3d()
	if c == null:
		return
	var feet := pp() + Vector3.UP * 0.05
	var top := pp() + Vector3.UP * 1.95
	if c.is_position_behind(feet) or c.is_position_behind(top):
		print("FRAME %-11s t=%.1f BEHIND" % [id, t])
		return
	var vs := get_viewport().get_visible_rect().size
	var a := c.unproject_position(feet)
	var b := c.unproject_position(top)
	var r := Rect2(Vector2.ZERO, vs)
	var h := absf(a.y - b.y) / vs.y
	var q := PhysicsRayQueryParameters3D.create(c.global_position, pp() + Vector3.UP * 1.2, Layers.WORLD | Layers.PROPS)
	q.exclude = [p.get_rid()]
	var occl := not (main as Node3D).get_world_3d().direct_space_state.intersect_ray(q).is_empty()
	print("FRAME %-11s t=%.1f h=%.2f in=%s occl=%s cx=%.2f cy=%.2f" % [id, t, h, r.has_point(a) and r.has_point(b), occl, (a.x + b.x) * 0.5 / vs.x, (a.y + b.y) * 0.5 / vs.y])


## A fixed north-up top-down view over `center` (TOP_PITCH down), `height` metres up.
func top_down(center: Vector3, height: float, pitch := TOP_PITCH) -> void:
	var back := height / tan(deg_to_rad(pitch))
	hold_cam(center + Vector3(0.0, height, back), center + Vector3.UP * 0.4)


# --- the new shots ---------------------------------------------------------------------------------

func _s_run_game() -> void:
	_clear_card()
	put_player(Vector3(0.0, 0.0, 70.0), 0.0, -0.16)
	drive(Vector3(0, 0, -1), true)                      # the game's own camera: a sprint up the road
	use_player_cam()
	boom("lance_hit", -4.0)


func _u_run_game(tt: float) -> void:
	light_at(pp() + Vector3(0, 0, -2), 4.0)
	if tt > 0.55 and once("rg_j"):
		press("jump")
	if tt > 0.65 and once("rg_j_up"):
		release("jump")
	if tt > 0.95 and once("rg_j2"):
		press("jump")                                   # the double jump
	if tt > 1.05 and once("rg_j2_up"):
		release("jump")

func _e_run_game() -> void:
	drive(Vector3.ZERO)


func _s_hero() -> void:
	# slow cinematic: the wanderer walking toward us down the road, lantern up, framed big
	put_player(ARENA + Vector3(-6.0, 0.0, 0.0), -WEST)
	drive(fwd_of(-WEST) * 0.55)                         # an unhurried walk
	use_free_cam()
	cam.fov = 48.0


func _u_hero(tt: float) -> void:
	var k := sm(clampf(tt / 4.0, 0.0, 1.0))
	var f := fwd_of(-WEST)
	var side := f.cross(Vector3.UP)
	frame_cam(pp() + f * lerpf(5.0, 4.3, k) + side * 0.8 + Vector3.UP * 1.25, pp() + Vector3.UP * 1.15)
	light_at(pp() + f * 1.5, 2.5)


func _e_hero() -> void:
	drive(Vector3.ZERO)
	cam.fov = 62.0


func _s_fight_top() -> void:
	key.light_energy = 7.0                              # night from above is all grass: light the floor
	key.omni_range = 30.0
	put_player(ARENA + Vector3(-6.0, 0.0, 2.0), WEST)
	spawn_pack(ARENA + Vector3(-6.0, 0.0, 2.0), WEST, 8.0)
	use_free_cam()
	cam.fov = 55.0

func _u_fight_top(tt: float) -> void:
	# top-down over the brawl, high enough to hold the wanderer and the pack together
	var mid := pp().lerp(pack_mid(), 0.45)
	top_down(mid, clampf(pp().distance_to(pack_mid()) * 0.8 + 4.0, 7.5, 10.0), 55.0)
	light_at(mid, 6.0)
	var foe := target()
	if foe:
		aim_at(foe.global_position)
	drive(-fwd_of(WEST) * 0.35 + fwd_of(WEST).cross(Vector3.UP) * 0.3)   # kiting back and aside
	if tt > 0.1 and once("td_bolts"):
		press(slot_action(0))
	if tt > 1.2 and once("td_nova"):
		release(slot_action(0))
		cast(2)                                         # Umbral Nova: the Marks go off
	if tt > 1.6 and once("td_bolts2"):
		press(slot_action(0))
	if tt > 2.5 and once("td_step"):
		release(slot_action(0))
		cast(4)                                         # Rift Step out of the press

func _e_fight_top() -> void:
	cam.fov = 62.0
	key.light_energy = 3.0
	key.omni_range = 24.0


func _s_road_game() -> void:
	put_player(ARENA + Vector3(18.0, 0.0, 0.0), WEST, -0.14)
	drive(fwd_of(WEST), true)
	use_player_cam()


func _u_road_game(tt: float) -> void:
	light_at(pp(), 4.0)
	if tt > 0.45 and once("rd_j"):
		press("jump")
	if tt > 0.55 and once("rd_j_up"):
		release("jump")
	if tt > 0.85 and once("rd_j2"):
		press("jump")
	if tt > 0.95 and once("rd_j2_up"):
		release("jump")
	if tt > 1.6 and once("rd_slide"):
		press("slide")

func _e_road_game() -> void:
	release("slide")
	drive(Vector3.ZERO)


func _s_boss_top() -> void:
	use_free_cam()
	cam.fov = 55.0


func _u_boss_top(tt: float) -> void:
	# fixed top-down: the Requiem's rings of bone rising outward, the wanderer weaving through them
	var mid := pp()
	if is_instance_valid(boss):
		mid = pp().lerp((boss as Node3D).global_position, 0.15)
		if tt > 0.1 and once("abbot_p3"):
			boss.call("take_hit", float(boss.get("hp")) - float(boss.get("max_hp")) * 0.22, p)   # the Requiem
		aim_at((boss as Node3D).global_position)
		var away := p.global_position - (boss as Node3D).global_position
		away.y = 0.0
		drive(away.normalized() * 0.35 + away.normalized().cross(Vector3.UP) * 0.3)   # backing off, circling
	top_down(mid, 9.0)
	light_at(mid, 8.0)
	if tt > 0.8 and once("boss_bolts"):
		press(slot_action(0))


# --- r: wildlife, the tavern, treasure ------------------------------------------------------------

func _by_script(suffix: String) -> Array[Node]:
	var out: Array[Node] = []
	for n in main.find_children("*", "Node", true, false):
		var sc: Script = n.get_script()
		if sc and String(sc.resource_path).ends_with(suffix):
			out.append(n)
	return out


var _herd: Node3D
var _herd_at := Vector3.ZERO
var _herd_dir := Vector3.FORWARD


## Pick the plover flock and put it up: called as the shot before ends, so the birds are already
## climbing when we cut to them (a flock deep in the grass reads as nothing).
func _flush_flock() -> void:
	if _herd != null:
		return
	_herd = null
	var best := INF
	for g in (life.get("groups") as Array if life else []):
		if is_instance_valid(g) and String(g.get("kind")) == "plover":
			var c: Vector3 = g.get("center")
			if Vector2(c.x - ARENA.x, c.z - ARENA.z).length() < 35.0:
				continue                                    # the fights next door have already put it up
			var n := float((g.call("positions") as Array).size())
			if -n < best:
				best = -n                                   # the biggest flock on the open flats
				_herd = g
	if _herd == null:
		print("TRAILER no plover flock")
		return
	_herd_at = _flock_mid()
	_herd.call("alarm", _herd_at, 1.0)


func _s_wildlife() -> void:
	_flush_flock()
	for g in (life.get("groups") as Array if life else []):
		if is_instance_valid(g) and String(g.get("kind")) in ["deer", "elk", "stag", "fox"]:
			(g as Node3D).visible = false               # the herds' gait steps: not in this shot
	use_free_cam()
	cam.fov = 38.0
	if _herd == null:
		return
	_herd_dir = Vector3(_herd_at.x - ARENA.x, 0.0, _herd_at.z - ARENA.z).normalized()
	if _herd_dir.length() < 0.5:
		_herd_dir = Vector3.FORWARD
	put_player(_herd_at - _herd_dir * 40.0, 0.0)
	_herd_cam = solve_cam([_herd_at + Vector3.UP * 1.0, _herd_at + Vector3.UP * 6.0], _herd_at, yaw_to(-_herd_dir), 7.0, 1.6)
	hold_cam(_herd_cam, _flock_mid() + Vector3.UP * 0.3)

func _u_wildlife(tt: float) -> void:
	if _herd == null or not is_instance_valid(_herd):
		return
	# the lens stays put and tilts after the flock as it lifts and spreads
	hold_cam(_herd_cam, _flock_mid() + Vector3.UP * 0.3)   # the lens follows the flock up into the sky
	light_at(_herd_at, 6.0)


var _herd_cam := Vector3.ZERO


func _flock_mid() -> Vector3:
	var ps: Array = _herd.call("positions")
	if ps.is_empty():
		return _herd.get("center")
	var c := Vector3.ZERO
	for v: Vector3 in ps:
		c += v
	return c / float(ps.size())

func _e_wildlife() -> void:
	cam.fov = 62.0
	for g in (life.get("groups") as Array if life else []):
		if is_instance_valid(g) and String(g.get("kind")) in ["deer", "elk", "stag", "fox"]:
			(g as Node3D).visible = true


var _patrons: Array[Node] = []


func _s_tavern() -> void:
	_patrons = _by_script("dwarf_npc.gd")
	p.teleport(Vector3(11.4, -0.5, 27.0))               # inside the Keg (no ground probe: it would find the roof)
	for k in _by_script("keg_scenes.gd"):
		k.call("play", "song")                          # the patrons break into song
	use_free_cam()
	cam.fov = 50.0


func _u_tavern(tt: float) -> void:
	var c := Vector3(11.4, -0.5, 27.0)
	if not _patrons.is_empty():
		c = Vector3.ZERO
		var n := 0
		for d in _patrons:
			if is_instance_valid(d):
				c += (d as Node3D).global_position
				n += 1
		c = c / float(maxi(n, 1))
	var a := lerpf(0.7, 1.1, sm(clampf(tt / 1.5, 0.0, 1.0)))
	frame_cam(c + Vector3(sin(a) * 2.8, 1.25, cos(a) * 2.8), c + Vector3.UP * 0.75)
	light_at(c, 2.0)


func _e_tavern() -> void:
	cam.fov = 62.0


var _charm: Node3D
var _tr_cam := Vector3.ZERO


func _s_treasure() -> void:
	_charm = null
	var best := INF
	for c in _by_script("charm_pickup.gd"):
		if c is Node3D and c.call("can_interact"):
			var d := (c as Node3D).global_position.distance_to(ARENA)
			if d < best:
				best = d
				_charm = c
	use_free_cam()
	cam.fov = 50.0
	if _charm == null:
		return
	var at := _charm.global_position
	put_player(at + Vector3(0.0, 0.0, 2.2), 0.0)        # two steps south of it, facing it


func _u_treasure(tt: float) -> void:
	if _charm == null or not is_instance_valid(_charm):
		return
	var at := _charm.global_position
	# low, the glint in the foreground, the wanderer walking up to it
	if once("tr_cam"):
		_tr_cam = solve_cam([at + Vector3.UP * 0.3, pp() + Vector3.UP * 1.2], at, yaw_to(Vector3(1.0, 0.0, -0.4).normalized()), 2.6, 0.9)
		_snap = true
	hold_cam(_tr_cam, at.lerp(pp(), 0.4) + Vector3.UP * 0.7)
	light_at(at, 2.5)
	if tt < 0.85:
		aim_at(at)
		drive((at - p.global_position).normalized() * 0.55)
	elif once("take_charm"):
		drive(Vector3.ZERO)
		p._visual.cast_pose(&"reach")
		_charm.call("interact", p)                       # into the satchel
		boom("lash", -6.0)


func _e_treasure() -> void:
	drive(Vector3.ZERO)
	cam.fov = 62.0


# --- movement: real vault / ledge / wall-kick spots (the scan from zz/trav_realm) --------------------

## Spots for each move on a 2 m grid within `radius` of `c`: {kind: [[ground point, dir, rise]]}.
func _spots(c: Vector2, radius: float) -> Dictionary:
	var space := (main as Node3D).get_world_3d().direct_space_state
	var found := {"vault": [], "grab": [], "kick": []}
	var dirs: Array[Vector3] = []
	for k in 8:
		dirs.append(Vector3(cos(TAU * k / 8.0), 0, sin(TAU * k / 8.0)))
	var r := int(radius)
	for gx in range(int(c.x) - r, int(c.x) + r + 1, 2):
		for gz in range(int(c.y) - r, int(c.y) + r + 1, 2):
			var g := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(gx, 60, gz), Vector3(gx, -30, gz), Layers.WORLD))
			if g.is_empty() or (g.normal as Vector3).y < 0.85:
				continue
			var y0: float = (g.position as Vector3).y
			var o := Vector3(gx, y0, gz)
			for d in dirs:
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(o + Vector3.UP * 0.35, o + Vector3.UP * 0.35 + d * 1.2, Layers.WORLD))
				if hit.is_empty() or absf((hit.normal as Vector3).y) > 0.3:
					continue
				var over: Vector3 = (hit.position as Vector3) + d * 0.12
				var top_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(over.x, y0 + 6.0, over.z), Vector3(over.x, y0 + 0.3, over.z), Layers.WORLD))
				if top_hit.is_empty():
					var tall := space.intersect_ray(PhysicsRayQueryParameters3D.create(o + Vector3.UP * 3.0, o + Vector3.UP * 3.0 + d * 1.6, Layers.WORLD))
					var mid := space.intersect_ray(PhysicsRayQueryParameters3D.create(o + Vector3.UP * 1.65, o + Vector3.UP * 1.65 + d * 1.6, Layers.WORLD))
					if not tall.is_empty() and not mid.is_empty():
						(found["kick"] as Array).append([o, d, 6.0])
					continue
				var rise: float = (top_hit.position as Vector3).y - y0
				var deep := space.intersect_ray(PhysicsRayQueryParameters3D.create(over + d * 0.6 + Vector3.UP * (rise + 0.3), over + d * 0.6 + Vector3.UP * (rise - 0.25), Layers.WORLD))
				if rise >= 0.55 and rise <= 1.2 and deep.is_empty():
					var land := space.intersect_ray(PhysicsRayQueryParameters3D.create(over + d * 1.6 + Vector3.UP * (rise + 0.3), over + d * 1.6 + Vector3.UP * (rise - 2.4), Layers.WORLD))
					if not land.is_empty():
						(found["vault"] as Array).append([o, d, rise])
				elif rise >= 1.25 and rise <= 2.15 and p._fits((top_hit.position as Vector3) + d * 0.2 + Vector3.UP * 0.05):
					(found["grab"] as Array).append([o, d, rise])
	return found


## A run-up for `kind` near any of `hints`: [start, the spot, dir] or [].
func _approach(kind: String, hints: Array, back: float) -> Array:
	var space := (main as Node3D).get_world_3d().direct_space_state
	for hint: Vector2 in hints:
		for e: Array in _spots(hint, 8.0)[kind]:
			var o: Vector3 = e[0]
			var d: Vector3 = e[1]
			var s0 := o - d * back
			var g := space.intersect_ray(PhysicsRayQueryParameters3D.create(s0 + Vector3.UP * 3.0, s0 + Vector3.DOWN * 3.0, Layers.WORLD))
			if g.is_empty() or absf((g.position as Vector3).y - o.y) > 0.4:
				continue
			if not space.intersect_ray(PhysicsRayQueryParameters3D.create(s0 + Vector3.UP * 1.0, o + Vector3.UP * 1.0, Layers.WORLD)).is_empty():
				continue
			return [(g.position as Vector3) + Vector3.UP * 0.05, o, d]
	return []


var _mv: Array = []


func _start_move(kind: String, hints: Array, back: float) -> void:
	_mv = _approach(kind, hints, back)
	if _mv.is_empty():
		print("TRAILER no %s spot" % kind)
		return
	var d: Vector3 = _mv[2]
	p.teleport(_mv[0])
	p.set_view(atan2(-d.x, -d.z), -0.15)
	_aiming = false
	_drive = Vector3.ZERO
	_drive_to = Vector3.ZERO


## A side-on tracking frame on the move: square to the run, a little behind, at chest height.
func _side_cam(dist := 4.2, lead := 0.6) -> void:
	if _mv.is_empty():
		return
	var d: Vector3 = _mv[2]
	var side := d.cross(Vector3.UP)
	frame_cam(pp() + side * dist - d * 0.8 + Vector3.UP * 1.3, pp() + d * lead + Vector3.UP * 1.0)


var _mv_cam := Vector3.ZERO


## A locked-off lens for a move: side-on to the run, able to see the start, the obstacle and beyond.
func _solve_move_cam(dist: float, h: float, back_bias: float) -> void:
	var o: Vector3 = _mv[1]
	var d: Vector3 = _mv[2]
	var side := d.cross(Vector3.UP)
	var look := [(_mv[0] as Vector3) + Vector3.UP * 1.0, o + Vector3.UP * 1.2, o + d * 1.6 + Vector3.UP * 2.0]
	_mv_cam = solve_cam(look, o - d * 1.5, yaw_to((side - d * back_bias).normalized()), dist, h)
	hold_cam(_mv_cam, pp() + Vector3.UP * 1.0)


func _s_vault() -> void:
	_start_move("vault", [Vector2(-22, 10), Vector2(-30, 14), Vector2(-20, 24)], 7.0)
	use_free_cam()
	cam.fov = 55.0
	if not _mv.is_empty():
		drive(_mv[2], true)
		_drive = _drive_to
		_solve_move_cam(4.6, 1.3, 0.2)


func _u_vault(_tt: float) -> void:
	if not _mv.is_empty():
		hold_cam(_mv_cam, pp() + (_mv[2] as Vector3) * 0.8 + Vector3.UP * 1.0)
	light_at(pp(), 4.0)

func _e_vault() -> void:
	drive(Vector3.ZERO)
	cam.fov = 62.0


func _s_grab() -> void:
	_start_move("grab", [Vector2(-20, 12), Vector2(-32, 30), Vector2(2, -20), Vector2(-14, -28), Vector2(-64, 40)], 3.0)
	use_free_cam()
	cam.fov = 55.0
	if not _mv.is_empty():
		drive(_mv[2])
		_solve_move_cam(5.0, 1.8, 0.5)

func _u_grab(tt: float) -> void:
	if not _mv.is_empty():
		hold_cam(_mv_cam, pp() + Vector3.UP * 1.1)       # the jump, the hang, the climb
	light_at(pp(), 4.0)
	if _mv.is_empty():
		return
	var to_face := ((_mv[1] as Vector3) - p.global_position).dot(_mv[2] as Vector3)
	if to_face < 1.0 and once("grab_j"):
		press("jump")
		flags["grab_j_t"] = tt
	if flags.has("grab_j_t") and tt - float(flags["grab_j_t"]) > 0.3 and once("grab_j_up"):
		release("jump")


func _e_grab() -> void:
	release("jump")
	drive(Vector3.ZERO)
	cam.fov = 62.0


func _s_kick() -> void:
	_start_move("kick", [Vector2(-4, -14), Vector2(-13, -30), Vector2(-1.8, -40), Vector2(4, -18), Vector2(-8, -50)], 2.5)
	if not _mv.is_empty():
		drive(_mv[2])
	use_player_cam()


func _u_kick(tt: float) -> void:
	light_at(pp(), 4.0)
	if _mv.is_empty():
		return
	if tt > 0.2 and once("kick_j"):
		press("jump")                                   # up the wall...
		flags["kick_t"] = tt
	if flags.has("kick_t") and tt - float(flags["kick_t"]) > 0.25 and once("kick_r"):
		release("jump")
	if flags.has("kick_r") and not p.is_grounded() and float(p.get("_wall_t")) > 0.0 and once("kick_k"):
		press("jump")                                   # ...and off it
		flags["kick_k_t"] = tt
	if flags.has("kick_k_t") and tt - float(flags["kick_k_t"]) > 0.08 and once("kick_k_up"):
		release("jump")
		drive(-(_mv[2] as Vector3))


func _e_kick() -> void:
	release("jump")
	drive(Vector3.ZERO)


# --- the boss, in his own pit ---------------------------------------------------------------------------

func _s_boss_reveal() -> void:
	_clear_card()
	put_player(PIT_PLAYER, 0.0, -0.05, false)
	var b := spawn(ABBOT_P, PIT_BOSS, 1.0, false)
	boss = b
	if b:
		b.set_meta(&"boss_id", "bone_abbot")
	use_free_cam()
	cam.fov = 48.0
	boom("nova", -1.0)


func _u_boss_reveal(tt: float) -> void:
	# low and close in the candlelight, looking up at the Abbot as he turns on the wanderer
	var bp := PIT_BOSS
	if is_instance_valid(boss):
		bp = (boss as Node3D).global_position
		aim_at(bp)
		if tt > 0.4 and once("abbot_p2"):
			boss.call("take_hit", float(boss.get("max_hp")) * 0.55, p)   # the roar, the second phase
	var k := sm(clampf(tt / 2.5, 0.0, 1.0))
	frame_cam(bp + Vector3(lerpf(3.2, 2.4, k), 0.7, lerpf(4.6, 3.8, k)), bp + Vector3.UP * lerpf(2.2, 2.8, k))
	light_at(bp + Vector3(0, 0, 2.0), 3.0)


func _s_boss_game() -> void:
	use_player_cam()


func _u_boss_game(tt: float) -> void:
	# the game's own camera: the wanderer backing off, the bolts and the lance into the Abbot
	if is_instance_valid(boss):
		aim_at((boss as Node3D).global_position)
		_pit_drive((boss as Node3D).global_position)
	light_at(pp(), 5.0)
	if tt > 0.15 and once("bg_bolts"):
		press(slot_action(0))
	if tt > 1.5 and once("bg_lance"):
		release(slot_action(0))
		press(slot_action(1))
	if tt > 2.6 and once("bg_lance_go"):
		release(slot_action(1))


# --- the side-on fight: a wide two-shot, the wanderer on one side, the pack on the other -----------

var _fs_cam := Vector3.ZERO


func _s_fight_side() -> void:
	var at := ARENA + Vector3(-6.0, 0.0, 2.0)
	put_player(at, WEST)
	spawn_pack(at, WEST, 8.0)
	use_free_cam()
	cam.fov = 50.0
	var mid := at + fwd_of(WEST) * 5.0
	_fs_cam = solve_cam([at + Vector3.UP * 1.2, mid + Vector3.UP * 1.0, at + fwd_of(WEST) * 11.0 + Vector3.UP * 1.0],
			mid, yaw_to(fwd_of(WEST).cross(Vector3.UP)), 7.5, 1.8)
	hold_cam(_fs_cam, mid + Vector3.UP * 1.0)


func _u_fight_side(tt: float) -> void:
	var mid := pp().lerp(pack_mid(), 0.5)
	hold_cam(_fs_cam, mid + Vector3.UP * 1.0)
	light_at(mid, 7.0)
	var foe := target()
	if foe:
		aim_at(foe.global_position)
	if tt > 0.5:
		drive(-fwd_of(WEST) * 0.35)
	if tt > 0.1 and once("sd_bolts"):
		press(slot_action(0))
	if tt > 1.3 and once("sd_lance"):
		release(slot_action(0))
		press(slot_action(1))
	if tt > 2.0 and once("sd_lance_go"):
		release(slot_action(1))
	if tt > 2.3 and once("sd_nova"):
		cast(2)


func _e_fight_side() -> void:
	_release_inputs()
	drive(Vector3.ZERO)
	cam.fov = 62.0


# --- the boss, wide: the Requiem in the pit, from high in the corner ------------------------------

var _bw_cam := Vector3.ZERO


func _s_boss_wide() -> void:
	use_free_cam()
	cam.fov = 60.0
	var bp := (boss as Node3D).global_position if is_instance_valid(boss) else PIT_BOSS
	var mid := pp().lerp(bp, 0.5)
	var axis := bp - pp()
	axis.y = 0.0
	_bw_cam = solve_cam([pp() + Vector3.UP * 1.2, bp + Vector3.UP * 2.4], mid, yaw_to(axis.normalized().cross(Vector3.UP)), 6.5, 3.2)
	hold_cam(_bw_cam, mid + Vector3.UP * 1.3)


func _u_boss_wide(tt: float) -> void:
	var bp := PIT_BOSS
	if is_instance_valid(boss):
		bp = (boss as Node3D).global_position
		if tt > 0.1 and once("abbot_p3"):
			boss.call("take_hit", float(boss.get("hp")) - float(boss.get("max_hp")) * 0.22, p)   # the Requiem
		aim_at(bp)
	_pit_drive(bp)
	hold_cam(_bw_cam, pp().lerp(bp, 0.5) + Vector3.UP * 1.3)
	light_at(pp().lerp(bp, 0.5), 5.0)
	if tt > 0.5 and once("bw_bolts"):
		press(slot_action(0))
	if tt > 1.1 and once("bw_bolts_off"):
		release(slot_action(0))
	if tt > 2.0 and once("bw_nova"):
		cast(2)


func _e_boss_wide() -> void:
	_release_inputs()
	cam.fov = 62.0


## Circle the Abbot inside the pit: round him, out of his reach, pulled back toward the middle of the
## floor so the wanderer never backs into a pillar or the wall.
func _pit_drive(bp: Vector3) -> void:
	var away := p.global_position - bp
	away.y = 0.0
	var dist := away.length()
	away = away.normalized()
	var wish := away.cross(Vector3.UP) * 0.45
	if dist < 6.0:
		wish += away * 0.35
	var home := PIT - p.global_position
	home.y = 0.0
	if home.length() > 3.0:
		wish += home.normalized() * 0.4
	drive(wish.limit_length(0.7))
