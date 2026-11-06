extends Spitter
## Tollman (r31, docs/enshrouded/enemies.md): a hooded bell-ringer in the Chanter's rags, a
## hand-bell of black iron on its staff. It does not fight you. It calls.
##   sighted  the moment it sees you it turns and runs for its pack (or just away), and starts to
##            ring: a gold ring spreads on the ground round it and the bell tolls three times
##            (2.4 s). Nothing about the toll hurts -- there is no red.
##   the toll  if it finishes, every hollowed within 34 m wakes and hunts you past its leash for a
##            while (Enemy.toll): the camp beyond the rise comes too.
##   interrupt  any blow on it while it rings spoils the toll (and staggers it). The bell is its
##            weak point. Kill it first, or get to it first.
##   clang   close in on it and it swings the bell: a short disc fills round it, then a clang.
## It rings again 14 s after a toll (or 4 s after a spoiled one). Light-averse; two blows kill it.
## No class_name (project rule): the spawner and Tiers load it by path.

const KinLook := preload("res://core/enemy/kin_look.gd")
const GruntModel := preload("res://core/enemy/grunt_model.gd")
const RING := 2.4
const TOLL_R := 34.0
const CLANG_TELL := 0.6
const CLANG_R := 2.3
const GOLD := Color(2.4, 1.7, 0.6)
var look_kind := "chanter"

var _toll_cd := 0.0
var _clang_cd := 1.5
var _act: StringName = &""
var _rings := 0
var _run_t := 0.0
var tolls := 0                     ## completed tolls (tests read it)
var _bell: Node3D
static var _mat: ShaderMaterial
static var _bell_mesh: Mesh
static var _bell_mat: Material


func _init() -> void:
	super._init()
	max_hp = 2
	hp = 2.0
	walk_speed = 3.1
	chase_range = 16.0
	hunt_leash = 18.0
	kite_min = 8.0
	kite_max = 13.0
	fire_range = 0.0                   # it never spits
	poise = 0.8
	hp_bar_y = 2.1
	can_call = false
	weak_socket = "hand_r"
	weak_offset = Vector3(0.0, -0.2, 0.02)
	weak_r = 0.07


func voice_family() -> String:
	return "whisper"


func _build() -> void:
	name = "Tollman"
	attach_rig()
	posture({"hunch": 0.5, "crouch": 0.2, "arm_reach": 0.2, "head_jut": 0.7, "sway": 0.6, "twitch": 0.25, "splay": 0.08})
	if _rig:
		_rig.scale = Vector3(0.92, 1.0, 0.92)
	set_flesh(KinLook.dress(self, "chanter"))
	# its own copy of the Chanter's look: ember-gold where the Chanter is corpse-green
	if _mat == null and not _flesh.is_empty() and _flesh[0].material_override is ShaderMaterial:
		_mat = (_flesh[0].material_override as ShaderMaterial).duplicate() as ShaderMaterial
		_mat.set_shader_parameter("rim_col", Color(0.9, 0.62, 0.3))
		_mat.set_shader_parameter("rim_amount", 0.3)
		_mat.set_shader_parameter("emit_pulse", 0.0)
	if _mat:
		for mi in _flesh:
			if is_instance_valid(mi):
				mi.material_override = _mat
	# the hand-bell, hung from the staff's head
	var hand := _rig.socket("hand_r") if _rig else null
	if hand:
		if _bell_mesh == null:
			_bell_mesh = ProcMesh.cyl(0.035, 0.11, 0.17, 12, 2)
			_bell_mat = ProcMesh.std_mat(Color(0.12, 0.1, 0.09), 0.45, 0.8)
		var bell := MeshInstance3D.new()
		bell.name = "Bell"
		bell.mesh = _bell_mesh
		bell.material_override = _bell_mat
		bell.position = Vector3(0.0, -0.2, 0.02)            # hung from the fist, under the staff's head
		bell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		hand.add_child(bell)
		_bell = bell


func _bell_at() -> Vector3:
	return _bell.global_position if is_instance_valid(_bell) else global_position + Vector3.UP * 2.0


func _think() -> void:
	_update_separation()
	_update_detour()
	var step := 1.0 / think_hz
	_toll_cd = maxf(0.0, _toll_cd - step)
	_clang_cd = maxf(0.0, _clang_cd - step)
	_strafe_t -= step
	if _strafe_t <= 0.0:
		_strafe_t = randf_range(1.2, 2.2)
		_strafe = -_strafe
	if _p == null:
		_hold_post(_home_planar())
		return
	var from_home := _home_planar()
	match _state:
		IDLE:
			if _dist <= chase_range and _calm_t <= 0.0 and not LightGrid.is_lit(_p.global_position):
				_run_t = 1.2                      # first it runs a few steps, then it rings
				_set_state(CHASE)
			else:
				_calm_t = maxf(0.0, _calm_t - step)
				_hold_post(from_home)
		CHASE:
			_run_t = maxf(0.0, _run_t - step)
			if _dist > chase_range * (2.0 if _hunt_t > 0.0 else 1.3) or from_home > hunt_leash * 1.5:
				_set_state(IDLE)
				_hold_post(from_home)
			elif _clang_cd <= 0.0 and _dist < 2.6 and _take_token():
				_start_clang()
			elif _run_t <= 0.0 and _toll_cd <= 0.0 and can_cast() and _dist < chase_range * 1.6:
				_start_toll()
			elif _run_t > 0.0:
				_run_off()
			else:
				_kite()
		SPECIAL:
			_special_think()
		RECOVER:
			_wish = Vector3.ZERO
			if _state_t >= 0.5:
				_set_state(CHASE)
		_:
			_set_state(CHASE)


## Away from you, toward its nearest packmate if it has one.
func _run_off() -> void:
	var away := -_to / maxf(_dist, 0.001)
	if is_instance_valid(_shield_ally) and _shield_ally.is_alive():
		var to_ally := _shield_ally.global_position - global_position
		to_ally.y = 0.0
		if to_ally.length() > 2.0:
			away = (away + to_ally.normalized() * 1.2).normalized()
	_wish = _detour if _detour != Vector3.ZERO else away
	_face_dir = _to / maxf(_dist, 0.001)
	if LightGrid.is_lit(global_position):
		_wish *= 0.45


func _on_state(next: int) -> void:
	if next == SPECIAL or next == WINDUP:
		return
	super._on_state(next)


func _start_toll() -> void:
	_act = &"toll"
	_rings = 0
	_drive = Vector3.ZERO
	_wish = Vector3.ZERO
	_set_state(SPECIAL)
	begin_cast("Toll of the Dark", RING, true)            # r33: the cast bar; any blow breaks it
	if _rig and _rig.has_method("howl"):
		_rig.call("howl", RING)
	_glint = 1.0
	Hints.once(&"tollman", "A Tollman rings for the dark. Hit it before the third toll, or everything in earshot comes.")
	HitText.pop(global_position + Vector3.UP * (hp_bar_y + 0.5), "it rings", GOLD)


func _start_clang() -> void:
	_act = &"clang"
	_clang_cd = 4.0
	_drive = Vector3.ZERO
	_set_state(SPECIAL)
	if _rig and _rig.has_method("telegraph"):
		_rig.call("telegraph", CLANG_TELL)
	_glint = 1.0
	AttackKit.zone(self, global_position, CLANG_TELL, 14.0, {"radius": CLANG_R, "fx": "slam", "color": AttackKit.RED})


func _special_think() -> void:
	_wish = Vector3.ZERO
	_face_dir = _to / maxf(_dist, 0.001)
	match _act:
		&"toll":
			# three tolls across the ring, each a spreading gold ring on the ground (no red: no harm)
			var due := int(_state_t / (RING / 3.0))
			if due > _rings and _rings < 3:
				_rings += 1
				_toll_fx(_rings)
			if _state_t >= RING:
				_finish_toll()
		&"clang":
			if _state_t >= CLANG_TELL:
				Sfx.play_stream(Synth.get_stream("block"), _bell_at(), 2.0, 0.55)
				if _rig and _rig.has_method("strike"):
					_rig.call("strike")
				_set_state(RECOVER)
				_state_t = -0.2
		_:
			_set_state(RECOVER)


func _toll_fx(k: int) -> void:
	var at := _bell_at()
	Sfx.play("res://art/audio/ward_chime.wav", at, 0.0 + float(k) * 2.0, 0.42)
	Sfx.play_stream(Synth.get_stream("block"), at, -6.0, 0.4)
	Vfx.ring(global_position + Vector3.UP * 0.1, 3.0 + 4.0 * float(k), GOLD, 0.9, 0.08, Vector3.UP, 1.2)
	Vfx.ring(at, 0.6, GOLD, 0.35, 0.04, Vector3.BACK, 1.0)
	Vfx.light(at, Color(1.0, 0.7, 0.3), 2.0, 6.0, 0.4)
	if _rig and _rig.has_method("strike"):
		_rig.call("strike")


func _finish_toll() -> void:
	tolls += 1
	_toll_cd = 14.0
	var n := Enemy.toll(get_tree(), global_position, TOLL_R, self)
	HitText.pop(global_position + Vector3.UP * (hp_bar_y + 0.7), "the toll is rung", GOLD, true)
	Vfx.ring(global_position + Vector3.UP * 0.15, TOLL_R, Color(0.9, 0.65, 0.22), 1.4, 0.12, Vector3.UP, 0.8)    # the earshot, dim, under the bloom
	Sfx.play_stream(Synth.get_stream("roar"), global_position + Vector3.UP * 2.0, -4.0, 1.3)
	if n > 0:
		Events.toast.emit("The toll is rung. Everything in earshot is coming.")
	_set_state(RECOVER)


## r33: the toll broken by a blow (Enemy.interrupt): spoiled, and it reels.
func _on_cast_interrupted(n: String) -> void:
	if n != "Toll of the Dark" or not is_alive():
		return
	_toll_cd = 4.0
	_stagger_cd = 0.0
	stagger()
	HitText.pop(global_position + Vector3.UP * (hp_bar_y + 1.3), "the toll is spoiled", Color(1.0, 0.8, 0.5))


## A blow while it rings spoils the toll and staggers it.
func take_hit(dmg: float, from: Node = null) -> void:
	var ringing := _state == SPECIAL and _act == &"toll"
	super.take_hit(dmg, from)
	if ringing and is_alive() and _state == SPECIAL:
		_toll_cd = 4.0
		_stagger_cd = 0.0
		stagger()
		HitText.pop(global_position + Vector3.UP * (hp_bar_y + 0.9), "the toll is spoiled", Color(1.0, 0.8, 0.5))
	elif ringing and is_alive():
		_toll_cd = 4.0


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if is_instance_valid(_bell) and _state == SPECIAL and _act == &"toll":
		_bell.rotation.z = sin(_state_t * 14.0) * 0.6
	elif is_instance_valid(_bell):
		_bell.rotation.z = 0.0
