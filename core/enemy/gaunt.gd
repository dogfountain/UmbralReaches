extends Wretch
## Gaunt (r31, docs/enshrouded/enemies.md): a long-shanked wretch that hunts by the hit-and-run.
## It never queues in the ring of waiting packmates: it stalks round you at 6-8 m, working to your
## off-side, then darts --
##   dart   it drops low and a narrow lane fills from its feet THROUGH you (0.55 s); it runs the
##          lane at speed, raking whatever it passes, and keeps going out the far side. Step out of
##          the lane. A blow on the tell breaks it like any windup.
##   after  it is winded a moment where it stops (the punish window), then circles to a new angle.
## Fragile (two blows), quick, light-averse. Built on the Wretch's rig and modelled body, drawn
## out long and pale (its own tint, so a pack reads which is which).
## No class_name (project rule): the spawner and Tiers load it by path.

const GruntModel := preload("res://core/enemy/grunt_model.gd")
const DART_TELL := 0.55
const DART_SPEED := 11.5
const STALK_R := 7.0
var look_kind := "wretch"          ## Variants dress it as a wretch

var _dart_cd := 2.2
var _dart_dir := Vector3.ZERO
var _dart_len := 0.0
var _dart_from := Vector3.ZERO
var _dart_hit := false
var _lane: MeshInstance3D
static var _mat: ShaderMaterial


func _init() -> void:
	super._init()
	max_hp = 2
	hp = 2.0
	walk_speed = 4.3
	chase_range = 14.0
	hunt_leash = 17.0
	strike_gloom = 22.0
	poise = 1.8
	combo_max = 0
	feint_chance = 0.0
	role = &"flanker"
	token_pool = &"dart"               ## its own turns: it does not take a melee token from a Husk
	pool_max = 2
	mass = 0.85
	hp_bar_y = 2.2


func _build() -> void:
	super._build()
	name = "Gaunt"
	if _rig:
		_rig.scale = Vector3(0.9, 1.12, 0.9)
	posture({"hunch": 0.7, "crouch": 0.45, "arm_reach": 0.7, "head_jut": 0.9, "sway": 0.3, "twitch": 1.0, "splay": 0.2})
	_tint()


## Its own copy of the Wretch's material: bone-pale skin, a cold rim, ember eyes.
func _tint() -> void:
	if _mat == null:
		var base: Material = null
		for mi in _flesh:
			if is_instance_valid(mi) and mi.material_override != null:
				base = mi.material_override
				break
		if not (base is ShaderMaterial):
			return
		_mat = (base as ShaderMaterial).duplicate() as ShaderMaterial
		if GruntModel.has(&"wretch") and _mat.shader == GruntModel.SHADER:
			_mat.set_shader_parameter("rim_col", Color(0.75, 0.82, 1.0))
			_mat.set_shader_parameter("rim_amount", 0.38)
			_mat.set_shader_parameter("emit_pulse", 0.5)
			_mat.set_shader_parameter("pulse_rate", 2.4)
		else:
			_mat.set_shader_parameter("rim_amount", 0.5)
	for mi in _flesh:
		if is_instance_valid(mi):
			mi.material_override = _mat


func _chases_directly() -> bool:
	return false                           # it stalks; _think sets where it goes


## Stalking: round you at STALK_R toward your off-side; in the dart's reach with a clear line and
## a free turn, it darts.
func _try_special(d: float) -> bool:
	_dart_cd = maxf(0.0, _dart_cd - 1.0 / think_hz)
	if _p == null:
		return false
	if _dart_cd <= 0.0 and d >= 3.0 and d <= 10.0 and is_on_floor() and _lit_t <= 0.0 \
			and absf(_p.global_position.y - global_position.y) < 1.2 and _strike_clear(_p) and _take_token():
		_start_dart(d)
		return true
	_stalk(d)
	return true


func _stalk(d: float) -> void:
	var dir := _to / maxf(d, 0.001)
	# the off-side: the side of you away from the camera's forward
	var fwd := Basis(Vector3.UP, _p._yaw) * Vector3.FORWARD
	var bearing := -dir
	var side := signf(fwd.cross(bearing).y)
	if side == 0.0:
		side = 1.0
	var want := fwd.rotated(Vector3.UP, side * deg_to_rad(110.0))
	var tgt := _p.global_position + want * STALK_R
	var tangent := Vector3(-dir.z, 0.0, dir.x)
	_orbit = 1.0 if tangent.dot(tgt - global_position) >= 0.0 else -1.0
	var radial := clampf((d - STALK_R) * 0.8, -1.0, 1.0)
	_wish = (tangent * _orbit * 0.9 + dir * radial).normalized()
	if _detour != Vector3.ZERO and d > 3.0:
		_wish = _detour
	if light_averse and LightGrid.is_lit(global_position):
		_wish *= 0.45
	_face_dir = dir
	_waiting = true


func _start_dart(d: float) -> void:
	_dart_cd = randf_range(4.2, 5.4)
	_dart_dir = _to / maxf(d, 0.001)
	_face_dir = _dart_dir
	_dart_len = minf(d + 4.0, 13.0)
	_dart_hit = false
	_drive = Vector3.ZERO
	_waiting = false
	_set_state(SPECIAL)
	if _rig and _rig.has_method("telegraph"):
		_rig.call("telegraph", DART_TELL)
	_glint = 1.0
	_squash = 0.2
	Sfx.play_stream(Synth.voice(voice_family(), "tell"), global_position + Vector3.UP, 0.0, _voice_pitch() * 1.2)
	_lane = SpellFx.danger(global_position, DART_TELL, {"rect": Vector2(0.7, _dart_len * 0.5), "yaw": atan2(-_dart_dir.x, -_dart_dir.z), "hold": _dart_len / DART_SPEED + 0.1})
	if _lane:
		track_move(_lane)


func _special_breakable() -> bool:
	return _state_t < DART_TELL               # the tell breaks; the run does not


func _special_think() -> void:
	if _state_t >= DART_TELL and _drive == Vector3.ZERO:
		if not is_instance_valid(_lane):
			_set_state(RECOVER)                    # broken on the tell (cancel_moves took the lane)
			return
		_dart_from = global_position
		_drive = _dart_dir * DART_SPEED
		if _rig and _rig.has_method("strike"):
			_rig.call("strike")
		Sfx.play_stream(Synth.voice(voice_family(), "call"), global_position + Vector3.UP, -6.0, _voice_pitch() * 1.3)


func _special_frame(_delta: float) -> void:
	if _drive == Vector3.ZERO:
		return
	var run := global_position - _dart_from
	run.y = 0.0
	if not _dart_hit and _p != null:
		var to := _p.global_position - global_position
		var dy := to.y
		to.y = 0.0
		if to.length() < 1.15 and absf(dy) < 1.8:
			_dart_hit = true
			if _p.is_evading():
				_p.on_evaded(self)
			else:
				_p.add_gloom_from_enemy(strike_gloom, global_position)
				Vfx.burst(_p.global_position + Vector3.UP * 1.1, Color(0.9, 0.12, 0.1), {"count": 12, "life": 0.3, "speed": Vector2(2.0, 4.0), "size": 0.04, "gravity": -4.0, "trail": 0.06})
				_swipe_fx()
	if run.length() >= _dart_len or is_on_wall() or _state_t > DART_TELL + 1.6:
		_drive = Vector3.ZERO
		velocity.x = 0.0
		velocity.z = 0.0
		if is_instance_valid(_lane):
			_lane.queue_free()
		_set_state(RECOVER)
		_state_t = -0.35                           # winded: the punish window
	elif int(_state_t * 14.0) % 2 == 0:
		Vfx.burst(global_position + Vector3.UP * 0.1, Color(0.15, 0.12, 0.1, 0.8), {"count": 3, "life": 0.5, "speed": Vector2(0.3, 1.0), "size": 0.12, "gravity": -1.0, "additive": false})
