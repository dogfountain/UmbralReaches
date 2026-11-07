extends Node
## The Tether line (r31): the staff casts a line of rift-light at an anchor (group "grapple_anchor",
## see grapple_anchor.gd) and hauls the wanderer to it. The anchor nearest the crosshair within
## REACH and in sight is marked; interact (E / pad X) bites it when nothing else is there to use.
## The haul ends just under and in front of the anchor with an upward pop, so a ledge above it is
## grabbed, landed on, or glided from. Costs Breath (Stamina.GRAPPLE).
## Child of Player, named "Grapple". Load by path (no class_name).

const Stamina := preload("res://core/player/stamina.gd")
const StaffSfx := preload("res://core/vfx/staff_sfx.gd")
const Hints := preload("res://ui/hints.gd")
const GROUP := "grapple_anchor"
const REACH := 24.0
const MIN_D := 2.5
const AIM_COS := 0.94            ## ~20 degrees off the crosshair
const SPEED := 21.0
const ACCEL := 60.0
const MAX_TIME := 2.2
const POP_UP := 6.2
const POP_OUT := 3.5
const COL := Color(1.2, 0.55, 2.8)

var player: Player
var target: Node3D               ## the anchor marked now (null: none)
var pulls := 0
var _scan_t := 0.0
var _pulling := false
var _to := Vector3.ZERO
var _anchor: Node3D
var _t := 0.0
var _speed := 0.0
var _stuck := 0.0
var _mark: MeshInstance3D
var _line: MeshInstance3D


func _ready() -> void:
	player = get_parent() as Player


func pulling() -> bool:
	return _pulling


## The line is placed every rendered frame at the staff head as it is drawn (a physics-tick muzzle stepped at 60 Hz).
func _process(_delta: float) -> void:
	if _pulling:
		_draw_line()


func _physics_process(delta: float) -> void:
	if player == null:
		return
	_scan_t -= delta
	if _scan_t <= 0.0 and not _pulling:
		_scan_t = 0.1
		target = _pick()
	_show_mark()


func _pick() -> Node3D:
	var nodes := get_tree().get_nodes_in_group(GROUP)
	if nodes.is_empty() or not player.is_inside_tree():
		return null
	var cam := player.get_viewport().get_camera_3d()
	if cam == null:
		return null
	var eye := cam.global_position
	var fwd := -cam.global_basis.z
	var body := player.global_position + Vector3.UP * 1.2
	var best: Node3D = null
	var best_s := -INF
	for n in nodes:
		var a := n as Node3D
		if a == null or not a.is_inside_tree() or not a.is_visible_in_tree():
			continue
		var reach := float(a.get_meta("reach", REACH))
		var d := a.global_position.distance_to(body)
		if d > reach or d < MIN_D:
			continue
		var dt := (a.global_position - eye).normalized().dot(fwd)
		if dt < AIM_COS:
			continue
		var s := dt * 6.0 - d / reach
		if s <= best_s:
			continue
		var space := player.get_world_3d().direct_space_state
		if space:
			var q := PhysicsRayQueryParameters3D.create(body, a.global_position, Layers.WORLD | Layers.PROPS, [player.get_rid()])
			var hit := space.intersect_ray(q)
			if not hit.is_empty() and (hit.position as Vector3).distance_to(a.global_position) > 0.6:
				continue
		best_s = s
		best = a
	return best


## Bite the marked anchor, if there is one and Breath for it. True when the haul began.
func try_fire() -> bool:
	if _pulling or target == null or not is_instance_valid(target):
		return false
	if player.skills_locked_for_arts():
		return false
	var st := player.stamina()
	if st and not st.spend(Stamina.GRAPPLE):
		return false
	return start(target)


## Haul to `a` now (tests and the input path).
func start(a: Node3D) -> bool:
	if a == null or not is_instance_valid(a):
		return false
	_anchor = a
	var body := player.global_position
	var land: Vector3
	if a.has_meta("land"):
		land = a.global_transform * (a.get_meta("land") as Vector3)
	else:
		var out := body - a.global_position
		out.y = 0.0
		out = out.normalized() if out.length() > 0.1 else Vector3.ZERO
		land = a.global_position + Vector3.DOWN * 1.2 + out * 0.9
	_to = land
	_pulling = true
	_t = 0.0
	_stuck = 0.0
	_speed = maxf(Vector3(player.velocity.x, 0.0, player.velocity.z).length(), 6.0)
	pulls += 1
	player.call("_grapple_begin")
	player.call("_visual_pose", &"tether")
	StaffSfx.play("tether", body + Vector3.UP * 1.3, -2.0)
	Vfx.burst(a.global_position, COL, {"count": 20, "life": 0.35, "speed": Vector2(1.5, 4.0), "size": 0.04, "gravity": 0.0, "trail": 0.06})
	Hints.once(&"tether_line", "The Tether line hauls you to rift-iron anchors. Glide from the top.")
	return true


## Player._physics_process calls this while hauling (it skips its own movement).
func tick(delta: float) -> void:
	_t += delta
	var from := player.global_position + Vector3.UP * 0.9
	var to := _to + Vector3.UP * 0.9
	var d := from.distance_to(to)
	_speed = minf(SPEED, _speed + ACCEL * delta)
	var dir := (to - from) / maxf(d, 0.001)
	player.velocity = dir * minf(_speed, d / maxf(delta, 0.001))
	var before := player.global_position
	player.move_and_slide()
	var moved := player.global_position.distance_to(before)
	_stuck = _stuck + delta if moved < _speed * delta * 0.2 else 0.0
	if d < 0.7 or _t > MAX_TIME or _stuck > 0.2:
		finish(_stuck <= 0.2)


## End the haul; `pop` throws the body up and over (the anchor reached).
func finish(pop := true) -> void:
	if not _pulling:
		return
	_pulling = false
	var out := Vector3.ZERO
	if is_instance_valid(_anchor):
		out = _anchor.global_position - player.global_position
		out.y = 0.0
		out = out.normalized() if out.length() > 0.05 else -player.global_basis.z
	player.velocity = (out * POP_OUT + Vector3.UP * POP_UP) if pop else Vector3(player.velocity.x * 0.3, 0.0, player.velocity.z * 0.3)
	if _line:
		_line.visible = false
	player.call("_grapple_end")
	if pop:
		StaffSfx.play("tether_hit", player.global_position + Vector3.UP, -4.0)


func cancel() -> void:
	if _pulling:
		_pulling = false
		if _line:
			_line.visible = false


func _draw_line() -> void:
	if not is_instance_valid(_anchor):
		return
	if _line == null:
		_line = MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.025
		cyl.bottom_radius = 0.025
		cyl.height = 1.0
		cyl.radial_segments = 6
		cyl.rings = 1
		_line.mesh = cyl
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = COL
		_line.material_override = m
		_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_line.top_level = true
		_line.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF   # placed every rendered frame at the drawn staff head
		add_child(_line)
	var a: Vector3 = player._visual.muzzle_drawn() if player._visual != null else player.global_position + Vector3.UP * 1.5
	var b := _anchor.global_position
	var ln := a.distance_to(b)
	if ln < 0.05:
		_line.visible = false
		return
	var y := (b - a) / ln
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	_line.global_transform = Transform3D(Basis(x, y * ln, z), (a + b) * 0.5)
	_line.visible = true


func _show_mark() -> void:
	var on := target != null and is_instance_valid(target) and not _pulling
	if not on:
		if _mark:
			_mark.visible = false
		return
	if _mark == null:
		var q := QuadMesh.new()
		q.size = Vector2(0.05, 0.05)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.no_depth_test = true
		m.fixed_size = true
		m.albedo_texture = _ring_tex()
		m.albedo_color = Color(1.3, 0.7, 2.6, 0.9)
		_mark = MeshInstance3D.new()
		_mark.mesh = q
		_mark.material_override = m
		_mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_mark.top_level = true
		add_child(_mark)
	_mark.global_position = target.global_position
	_mark.visible = true


static func _ring_tex() -> ImageTexture:
	var img := Image.create(48, 48, false, Image.FORMAT_RGBA8)
	for y in 48:
		for x in 48:
			var r := Vector2(x - 23.5, y - 23.5).length()
			var a := clampf(1.0 - absf(r - 18.0) / 2.5, 0.0, 1.0) + clampf(1.0 - r / 3.0, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)
