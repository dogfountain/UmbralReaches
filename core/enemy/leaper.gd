class_name Leaper
extends Enemy
## Big four-legged stalker: the long jumper. Circles at range, coils for half a second (body drops,
## eyes flare, shriek) and pounces 4.5-13 m with lead on your movement. Lands hard and staggers —
## the punish window. Heavy haunches and a spined tail so it reads at distance.
## Close in and at its flank it lashes the spined tail round: a disc fills round its body, then
## it spins. Get out, or step through it.

const GruntModel := preload("res://core/enemy/grunt_model.gd")
const SWEEP_TELL := 0.55
const SWEEP_R := 2.5
var _sweep_cd := 2.0
var _spun := 0.0


func _init() -> void:
	max_hp = 4
	hp = 4.0
	walk_speed = 4.2
	chase_range = 15.0
	hunt_leash = 19.0
	strike_range = 1.6
	strike_gloom = 28.0
	light_averse = true
	leaper = true
	leap_min = 4.5
	leap_max = 13.0
	leap_apex = 2.1
	leap_prep = 0.5
	leap_cooldown = 2.8
	leap_lead = 0.55
	hp_bar_y = 1.45
	role = &"flanker"
	mass = 1.2


func _build() -> void:
	name = "Leaper"
	var rig := QuadRig.new()
	rig.body_height = 0.56
	rig.body_len = 1.15
	rig.hip_spread = 0.2
	rig.upper_len = 0.32
	rig.stride_len = 0.7
	# r30: the modelled leaper stands on hound legs, and so does the Thornwarden's skinned body (a Leaper
	# too); the procedural fallback keeps the spider layout
	rig.upright = _kind(&"leaper") in [&"leaper", &"thornwarden"] and GruntModel.has(_kind(&"leaper"))
	attach_rig(rig)
	var col := get_node_or_null("Collision") as CollisionShape3D
	if col and col.shape is CapsuleShape3D:
		var cap := col.shape as CapsuleShape3D
		cap.height = 1.1
		cap.radius = 0.42
		col.position.y = 0.6
	set_flesh(EnemyBody.dress(_rig, _kind(&"leaper")))


func voice_family() -> String:
	return "leaper"


## Tail sweep: only when you are close and NOT in front of its jaws (that is the rake's job).
func _try_special(d: float) -> bool:
	_sweep_cd = maxf(0.0, _sweep_cd - 1.0 / think_hz)
	if _sweep_cd > 0.0 or d > 2.6 or _p == null or _face == null or not is_on_floor():
		return false
	var fwd := -_face.global_basis.z
	fwd.y = 0.0
	var beside := fwd.normalized().dot(_to / maxf(d, 0.001)) <= 0.5
	# at its flank, or crowding it very close (then sometimes): the jaws cannot reach you there
	if not (beside or (d < 1.5 and randf() < 0.3)) or not _take_token():
		return false
	_sweep_cd = 5.5
	_spun = 0.0
	_drive = Vector3.ZERO
	_set_state(SPECIAL)
	if _rig and _rig.has_method("telegraph"):
		_rig.call("telegraph", SWEEP_TELL)
	_glint = 1.0
	say("windup", global_position + Vector3.UP, 0.0, _voice_pitch())
	var r := SWEEP_R * maxf(_rig.scale.x if _rig else 1.0, 1.0)
	AttackKit.zone(self, global_position, SWEEP_TELL, strike_gloom * 0.8, {"radius": r, "fx": "slam", "h": 1.4})
	return true


func _special_think() -> void:
	if _state_t >= SWEEP_TELL + 0.12:
		_set_state(RECOVER)
		_state_t = -0.15


## The spin itself: one full turn in 0.3 s right as the disc lands.
func _special_frame(delta: float) -> void:
	if _state_t >= SWEEP_TELL - 0.3 and _spun < TAU and _face:       # the turn ends as the disc lands
		var step := minf(TAU * delta / 0.3, TAU - _spun)
		_spun += step
		_face.rotation.y += step
		if _spun >= TAU:
			if _rig and _rig.has_method("strike"):
				_rig.call("strike")
