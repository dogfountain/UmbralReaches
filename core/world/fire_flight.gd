extends Node3D
## r33 world: the flight along the Ember Road (fire_road.gd). The wanderer burns down into embers at
## one fire and a wisp of them flies a high arc over the valley to the other; the camera rides
## behind the wisp, looking ahead, and comes down behind the wanderer standing up out of the far
## fire. 3-6.5 s by distance. The player is hidden and frozen (process disabled) for the flight and
## stands at the far fire's spawn point from its start, so streaming, the region names and the
## night's systems settle there; the place's name is shown on landing (realm_discovery waits for
## no flight in GROUP). Load by path (no class_name).

const GROUP := "fire_flight"
const HorseScript := preload("res://core/world/mount/horse.gd")
const SPEED := 26.0                     ## metres a second along the ground
const CLEAR := 20.0                     ## the arc's top clears the land under it by this much
const EMBER := Color(3.2, 1.5, 0.5)     ## HDR: blooms under the 1.15 threshold

var player: Player
var from_fire: Brazier
var to_fire: Brazier
var t := 0.0                            ## 0..1 along the flight
var dur := 4.0
var landed := false
var _p := [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
var _cam: Camera3D
var _old_cam: Camera3D
var _wisp: Node3D
var _trail: GPUParticles3D
var _fade: ColorRect
var _fade_layer: CanvasLayer
var _land_at := Vector3.ZERO
var _land_yaw := 0.0
var _end_eye := Vector3.ZERO
var _handed := false


func _ready() -> void:
	add_to_group(GROUP)
	process_mode = Node.PROCESS_MODE_PAUSABLE
	top_level = true


func start(p: Player, a: Brazier, b: Brazier) -> void:
	player = p
	from_fire = a
	to_fire = b
	_old_cam = get_viewport().get_camera_3d()
	var eye := _old_cam.global_position if _old_cam else p.global_position + Vector3(0, 2.2, 3.0)
	# where the wanderer will stand: the far fire's spawn point, turned to the flames (the camera comes
	# down behind them, the fire and its ember-post ahead)
	_land_at = b.spawn_point()
	var away := _land_at - b.global_position
	away.y = 0.0
	away = away.normalized() if away.length_squared() > 0.01 else Vector3.FORWARD
	_land_yaw = atan2(away.x, away.z)
	_end_eye = _land_at + away * 4.2 + Vector3.UP * 2.3
	# the arc: up out of this fire, over the land, down behind the wanderer at the other
	var flat := Vector2(_end_eye.x - eye.x, _end_eye.z - eye.z).length()
	var top := maxf(eye.y, _end_eye.y) + 10.0
	for i in 9:
		var q := eye.lerp(_end_eye, float(i) / 8.0)
		top = maxf(top, RealmLayout.macro_height(q.x, q.z) + CLEAR)
	var toward := Vector3(_end_eye.x - eye.x, 0.0, _end_eye.z - eye.z)
	_p = [eye, Vector3(eye.x, top, eye.z) + toward * 0.22, Vector3(_end_eye.x, top, _end_eye.z) - toward * 0.22, _end_eye]
	dur = clampf(flat / SPEED + 1.4, 3.0, 6.5)
	# the camera that flies
	_cam = Camera3D.new()
	_cam.name = "FlightCam"
	_cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_cam)
	if _old_cam:
		_cam.fov = _old_cam.fov
		_cam.far = _old_cam.far
		_cam.near = _old_cam.near
		_cam.cull_mask = _old_cam.cull_mask
		_cam.environment = _old_cam.environment
		_cam.attributes = _old_cam.attributes
		_cam.global_transform = _old_cam.global_transform
	else:
		_cam.global_position = eye
	_cam.current = true
	_make_wisp(p.global_position + Vector3.UP * 1.0)
	_make_fade()
	# the wanderer burns down into the fire's embers
	Vfx.burst(p.global_position + Vector3.UP * 0.9, EMBER, {"count": 46, "life": 1.1, "speed": Vector2(0.6, 2.6), "size": 0.07,
		"gravity": 2.6, "spread": 70.0, "dir": Vector3.UP, "radius": 0.45, "turbulence": true})
	Vfx.light(p.global_position + Vector3.UP, Color(1.0, 0.55, 0.25), 3.0, 7.0, 0.6)
	Sfx.play("res://art/audio/ward_chime.wav", p.global_position, -6.0, 0.7)
	var mount := p.riding as HorseScript
	if mount != null:
		mount.dismount()                 # you arrive on your feet; the horse stays where it stood
	p.visible = false
	p.velocity = Vector3.ZERO
	p.teleport(_land_at)
	p.set_view(_land_yaw, -0.18)
	p.process_mode = Node.PROCESS_MODE_DISABLED
	Events.interact_hint.emit("")


func _bez(u: float) -> Vector3:
	u = clampf(u, 0.0, 1.0)
	var v := 1.0 - u
	return _p[0] * v * v * v + _p[1] * 3.0 * v * v * u + _p[2] * 3.0 * v * u * u + _p[3] * u * u * u


func _process(delta: float) -> void:
	if landed:
		return
	if player == null or not is_instance_valid(player) or to_fire == null or not is_instance_valid(to_fire):
		_finish()
		return
	t = minf(1.0, t + delta / dur)
	var e := t * t * (3.0 - 2.0 * t)                      # ease in and out
	var eye := _bez(e)
	# the wisp leads; near the end it settles into the far fire
	var lead := _bez(minf(1.0, e + 0.12))
	var fire := to_fire.global_position + Vector3.UP * 1.1
	var wk := smoothstep(0.82, 1.0, t)
	if _wisp:
		_wisp.global_position = lead.lerp(fire, wk) + Vector3.UP * (sin(t * 19.0) * 0.25) * (1.0 - wk)
	# look: ahead along the arc, down at the fire as it comes in
	var look := lead.lerp(_bez(minf(1.0, e + 0.2)), 0.5).lerp(fire, smoothstep(0.6, 1.0, t))
	if look.distance_squared_to(eye) > 0.01:
		var want := Basis.looking_at(look - eye, Vector3.UP)
		var q := _cam.global_basis.get_rotation_quaternion().slerp(want.get_rotation_quaternion(), 1.0 - exp(-5.0 * delta))
		_cam.global_transform = Transform3D(Basis(q), eye)
	else:
		_cam.global_position = eye
	if _fade:
		_fade.color.a = smoothstep(0.86, 1.0, t) * 0.8
	if t >= 1.0:
		_finish()


func _finish() -> void:
	if landed:
		return
	landed = true
	if player and is_instance_valid(player):
		player.process_mode = Node.PROCESS_MODE_INHERIT
		player.visible = true
		player.teleport(_land_at)
		player.set_view(_land_yaw, -0.18)
		var pc := player.get_node_or_null("CameraRig/Pitch/SpringArm/Camera") as Camera3D
		if pc:
			pc.current = true
		elif _old_cam and is_instance_valid(_old_cam):
			_old_cam.current = true
		if to_fire and is_instance_valid(to_fire):
			to_fire.remember(player)
		Vfx.burst(_land_at + Vector3.UP * 0.9, EMBER, {"count": 46, "life": 1.0, "speed": Vector2(0.4, 2.0), "size": 0.07,
			"gravity": -1.2, "spread": 80.0, "dir": Vector3.UP, "radius": 0.6, "turbulence": true})
		Sfx.play("res://art/audio/ward_chime.wav", _land_at, -6.0, 0.9)
	if from_fire and to_fire and is_instance_valid(from_fire) and is_instance_valid(to_fire):
		Events.fire_travelled.emit(String(from_fire.name), String(to_fire.name))
	if _wisp:
		_wisp.queue_free()
		_wisp = null
	if _cam:
		_cam.queue_free()
	# lift the ember-dark off the arrival
	if _fade:
		var tw := create_tween()
		tw.tween_property(_fade, "color:a", 0.0, 0.6)
		tw.tween_callback(queue_free)
	else:
		queue_free()


func _make_wisp(at: Vector3) -> void:
	_wisp = Node3D.new()
	_wisp.name = "Wisp"
	_wisp.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_wisp)
	_wisp.global_position = at
	var core := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.16
	sph.height = 0.32
	sph.radial_segments = 12
	sph.rings = 6
	core.mesh = sph
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.7, 0.35)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.55, 0.22)
	m.emission_energy_multiplier = 1.2
	core.material_override = m
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_wisp.add_child(core)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.6, 0.3)
	l.light_energy = 2.2
	l.omni_range = 7.0
	l.shadow_enabled = false
	_wisp.add_child(l)
	# short-lived: the camera follows the wisp's line, and sparks still hanging there met the lens
	_trail = Vfx.emitter(EMBER, {"count": 60, "life": 0.32, "speed": Vector2(0.1, 0.6), "size": 0.045, "gravity": -0.4,
		"spread": 180.0, "radius": 0.14, "turbulence": true})
	_trail.emitting = true
	_wisp.add_child(_trail)


func _make_fade() -> void:
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 79
	add_child(_fade_layer)
	_fade = ColorRect.new()
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.color = Color(0.12, 0.04, 0.02, 0.0)
	_fade_layer.add_child(_fade)
