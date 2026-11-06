extends Spitter
## Chanter: a robed, hooded wretch with a bone staff caging a corpse-light. Pack support -- it
## keeps a packmate between you (Spitter's kiting), and works three things, each told first:
##   sigil    staff up (0.5 s): a pale-green disc appears under you and fills for 1.5 s in all,
##            then erupts. Keep moving.
##   shroud   staff toward a packmate, a green thread between them and a rising drone (1.1 s):
##            that packmate takes half damage for 6 s. Any hit on the Chanter breaks the working.
##   slip     you get within 3.5 m: it crouches, a tear opens where it is going, and it steps
##            through the dark to there (no damage: it is running away).
## Two hits kill it. Kill it first.
## r33: the sigil and the shroud are casts with bars (Enemy.begin_cast); any blow interrupts them and it
## cannot cast again for Enemy.SILENCE seconds. The slip shows a bar too, but cannot be broken.
## No class_name (project rule): the spawner preloads it.

const KinLook := preload("res://core/enemy/kin_look.gd")
const SIGIL_CAST := 0.5
const SIGIL_FALL := 1.0
const SIGIL_R := 1.8
const CHANNEL := 1.1
const SLIP_TELL := 0.4
const GLOAM := Color(0.75, 1.9, 0.45)

var _shroud_cd := 3.0
var _slip_cd := 2.0
var _act: StringName = &""
var _ally: Enemy
var _slip_to := Vector3.INF
var _thread_t := 0.0
var _staff: Node3D


func _init() -> void:
	super._init()
	max_hp = 2
	hp = 2.0
	walk_speed = 2.6
	kite_min = 7.0
	kite_max = 11.0
	fire_range = 16.0
	spit_cooldown = 3.4
	spit_gloom = 14.0
	poise = 0.9
	hp_bar_y = 2.05
	can_call = true
	# r31: the caged corpse-light at the staff's head (over its shoulder) is its weak point
	weak_socket = "hand_r"
	weak_offset = Vector3(0.0, 0.85, 0.0)
	weak_r = 0.08


func voice_family() -> String:
	return "chanter"


func _build() -> void:
	name = "Chanter"
	attach_rig()
	posture({"hunch": 0.42, "crouch": 0.15, "arm_reach": 0.35, "head_jut": 0.6, "sway": 0.8, "twitch": 0.35, "splay": 0.1})
	if _rig:
		_rig.scale = Vector3(0.95, 1.05, 0.95)
	set_flesh(KinLook.dress(self, "chanter"))
	if _rig:
		_staff = _rig.find_child("Kin_glow_hand_r", true, false) as Node3D


func _staff_tip() -> Vector3:
	if is_instance_valid(_staff):
		return _staff.global_transform * Vector3(0, 0.85, 0)
	return global_position + Vector3.UP * 2.2


func _think() -> void:
	_update_separation()
	var step := 1.0 / think_hz
	_shot_cd = maxf(0.0, _shot_cd - step)
	_shroud_cd = maxf(0.0, _shroud_cd - step)
	_slip_cd = maxf(0.0, _slip_cd - step)
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
			if _dist <= chase_range and _calm_t <= 0.0:
				_set_state(CALL if _should_call() else CHASE)
			else:
				_calm_t = maxf(0.0, _calm_t - step)
				_hold_post(from_home)
		CALL:
			_wish = Vector3.ZERO
			_face_dir = _to / maxf(_dist, 0.001)
			if _state_t >= 0.85:
				_set_state(CHASE)
		CHASE:
			if _dist > chase_range * 1.25 or from_home > hunt_leash:
				_set_state(IDLE)
				_hold_post(from_home)
			elif _slip_cd <= 0.0 and _dist < 3.5 and _start_slip():
				pass
			elif _shroud_cd <= 0.0 and can_cast() and _pick_ally():
				_start_shroud()
			elif _shot_cd <= 0.0 and can_cast() and _dist <= fire_range and not LightGrid.is_lit(_p.global_position):
				_wish = Vector3.ZERO
				_face_dir = _to / maxf(_dist, 0.001)
				_set_state(WINDUP)
			else:
				_kite()
		WINDUP:
			_wish = Vector3.ZERO
			_face_dir = _to / maxf(_dist, 0.001)
			if _state_t >= SIGIL_CAST + SIGIL_FALL:                 # the arms stay up while the disc is live
				if _rig and _rig.has_method("strike"):
					_rig.call("strike")
				_shot_cd = spit_cooldown + randf_range(-0.3, 0.5)
				_set_state(RECOVER)
		SPECIAL:
			_special_think()
		RECOVER:
			_wish = Vector3.ZERO
			if _state_t >= 0.6:
				_set_state(CHASE)
		_:
			_set_state(CHASE)


func _on_state(next: int) -> void:
	if next == WINDUP:
		# the sigil: it shows under you the moment the staff goes up, and lands 1.5 s later
		if _rig and _rig.has_method("telegraph"):
			_rig.call("telegraph", SIGIL_CAST + SIGIL_FALL)
		_glint = 1.0
		begin_cast("Grave Sigil", SIGIL_CAST, true)          # r33: a cast bar; any blow breaks it (and the sigil fades)
		say("windup", global_position + Vector3.UP * 1.5, 0.0, _voice_pitch())
		if _p:
			var at := _p.global_position
			var space := get_world_3d().direct_space_state
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 1.0, at + Vector3.DOWN * 3.0, Layers.WORLD))
			if not hit.is_empty():
				at = hit.position
			AttackKit.zone(self, at, SIGIL_CAST + SIGIL_FALL, spit_gloom, {"radius": SIGIL_R, "color": GLOAM, "fx": "sigil", "release": SIGIL_CAST})
			Vfx.arc(_staff_tip(), at + Vector3.UP * 0.3, GLOAM, 0.4, 0.3)
		return
	if next == SPECIAL:
		return
	super._on_state(next)


# --- the working on a packmate ------------------------------------------------------------------

func _pick_ally() -> bool:
	_ally = null
	var best := 81.0
	for node in get_tree().get_nodes_in_group(Groups.ENEMY):
		var e := node as Enemy
		if e == null or e == self or not e.is_alive() or e.boss or e.role == &"support" or e._shroud_t > 0.5:
			continue
		if e._state == IDLE:
			continue
		var d2 := e.global_position.distance_squared_to(global_position)
		if d2 < best:
			best = d2
			_ally = e
	return _ally != null


func _start_shroud() -> void:
	_act = &"shroud"
	_shroud_cd = 9.0
	_thread_t = 0.0
	_drive = Vector3.ZERO
	_set_state(SPECIAL)
	begin_cast("Shroud of Gloam", CHANNEL, true)               # r33: interrupt it and the packmate goes bare
	if _rig and _rig.has_method("telegraph"):
		_rig.call("telegraph", CHANNEL)
	_glint = 1.0
	Sfx.play_stream(Synth.get_stream("chant"), global_position + Vector3.UP * 1.6, -4.0, 1.0)


func _start_slip() -> bool:
	var away := -_to / maxf(_dist, 0.001)
	var space := get_world_3d().direct_space_state
	for k in 5:
		var dir := away.rotated(Vector3.UP, [0.0, 0.6, -0.6, 1.2, -1.2][k])
		var p := global_position + dir * 8.0
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 4.0, p + Vector3.DOWN * 6.0, Layers.WORLD))
		if hit.is_empty() or LightGrid.is_lit(hit.position) or absf((hit.position as Vector3).y - global_position.y) > 3.0:
			continue
		_slip_to = hit.position
		_act = &"slip"
		_slip_cd = 7.0
		_drive = Vector3.ZERO
		_set_state(SPECIAL)
		begin_cast("Dark Slip", SLIP_TELL, false)
		if _rig and _rig.has_method("telegraph"):
			_rig.call("telegraph", SLIP_TELL)
		SpellFx.tear(_slip_to, 2.0, SLIP_TELL + 0.3)
		say("flee", global_position + Vector3.UP, -6.0, _voice_pitch())
		return true
	_slip_cd = 2.0
	return false


func _special_think() -> void:
	_wish = Vector3.ZERO
	match _act:
		&"shroud":
			if not is_instance_valid(_ally) or not _ally.is_alive():
				_set_state(RECOVER)
				return
			_face_dir = (_ally.global_position - global_position).normalized()
			_thread_t -= 1.0 / think_hz
			if _thread_t <= 0.0:
				_thread_t = 0.2
				Vfx.arc(_staff_tip(), _ally.global_position + Vector3.UP * (_ally.hp_bar_y * 0.55), GLOAM, 0.45, 0.08)      # arcs overlap into one steady beam
			if _state_t >= CHANNEL:
				_ally.shroud(6.0)
				HitText.pop(_ally.global_position + Vector3.UP * (_ally.hp_bar_y + 0.4), "shrouded", GLOAM)
				_set_state(RECOVER)
		&"slip":
			if _state_t >= SLIP_TELL:
				SpellFx.rift_out(global_position)
				global_position = _slip_to + Vector3.UP * 0.05
				velocity = Vector3.ZERO
				SpellFx.rift_in(_slip_to)
				reset_physics_interpolation()
				_set_state(RECOVER)
				_state_t = 0.2
		_:
			_set_state(RECOVER)
