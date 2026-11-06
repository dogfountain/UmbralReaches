extends Spitter
## Brood-Mother (r31 guardian, docs/enshrouded/enemies.md): a Spitter grown huge on the dark,
## its throat-sac a swollen, glowing womb. It holds a nest (core/life/encounters/guardians.gd
## spawns it at a point of interest) and does not leave it far.
##   lob     (as a Spitter) acid on a high arc, its landing disc filling under you; in pairs.
##   spray   close in and it spits a fan of three orbs (five once it is enraged).
##   brood   every 10 s (7 s enraged) it squats and the sac swells and burns gold for 1.6 s: then
##           three mites burst out round it. A bolt that bursts on the sac while it swells
##           ruptures the brood -- no mites, it reels, broken. The sac is always its weak point.
##   enrage  below half: a shriek, the sac splits open wider (bigger weak point), the brood comes
##           quicker and the spray widens. At most six of its mites live at once.
## No class_name (project rule): Guardians loads it by path.

const MITE := "res://core/enemy/mite.gd"
const BROOD_TELL := 1.6
const SCALE := 1.7
var look_kind := "spitter"

var enraged := false
var _brood_t := 5.0
var _spray_cd := 2.0
var _brooding := false
var broods := 0                    ## mites hatched (tests read it)
var ruptures := 0


func _init() -> void:
	super._init()
	max_hp = 44
	hp = 44.0
	walk_speed = 2.2
	chase_range = 18.0
	hunt_leash = 12.0
	kite_min = 5.0
	kite_max = 9.0
	fire_range = 18.0
	spit_cooldown = 2.6
	spit_gloom = 16.0
	poise = 7.0
	mass = 3.0
	hp_bar_y = 1.9 * SCALE
	can_flee = false


func _build() -> void:
	super._build()
	name = "BroodMother"
	if _rig:
		_rig.scale *= SCALE
	var col := get_node_or_null("Collision") as CollisionShape3D
	if col and col.shape is CapsuleShape3D:
		var cap := (col.shape as CapsuleShape3D).duplicate() as CapsuleShape3D
		cap.radius *= 1.5
		cap.height *= SCALE
		col.shape = cap
		col.position.y = cap.height * 0.5
	weak_r = 0.2
	if _sac:
		_sac.scale = Vector3.ONE * 1.4
		var l := OmniLight3D.new()
		l.name = "SacLight"
		l.light_color = Color(0.5, 1.0, 0.7)
		l.light_energy = 1.2
		l.omni_range = 4.0
		l.shadow_enabled = false
		_sac.add_child(l)


func _think() -> void:
	var step := 1.0 / think_hz
	_brood_t -= step
	_spray_cd = maxf(0.0, _spray_cd - step)
	if _state == SPECIAL:
		_special_think()
		return
	if _state == CHASE and _p != null and _brood_t <= 0.0 and _dist < 22.0:
		_start_brood()
		return
	if _state == CHASE and _p != null and _spray_cd <= 0.0 and _dist < 5.5 and _strike_clear(_p):
		_spray()
		return
	super._think()


func _lob() -> void:
	super._lob()
	if _p == null:
		return
	# the second glob lands where you are going
	var pv := Vector3(_p.velocity.x, 0.0, _p.velocity.z)
	var at := _p.global_position + (pv.normalized() * 3.0 if pv.length() > 1.0 else Vector3(randf_range(-2.5, 2.5), 0.0, randf_range(-2.5, 2.5)))
	AttackKit.zone(self, at, lob_flight + 0.3, spit_gloom, {"radius": LOB_R, "color": AttackKit.ACID, "fx": "acid", "bound": false,
		"on_land": AttackKit.linger.bind(at, LOB_R * 0.85, 3.2, 3.0, 0.5, Color(0.2, 1.1, 0.75))})
	AttackKit.lob(_sac.global_position if _sac else global_position + Vector3.UP * 2.4, at, lob_flight + 0.3, AttackKit.ACID)


func _spray() -> void:
	_spray_cd = 5.0
	var from := _sac.global_position if _sac else global_position + Vector3.UP * 2.4
	var aim := _p.global_position + Vector3.UP * 1.0 - from
	var n := 5 if enraged else 3
	for k in n:
		var ang := deg_to_rad(-12.0 * float(n - 1) * 0.5 + 12.0 * float(k))
		SpitOrb.launch(get_tree().current_scene, from, aim.rotated(Vector3.UP, ang), spit_gloom * 0.8)
	Sfx.play("res://art/audio/spit.wav", from, 0.0, 0.6)
	_set_state(RECOVER)


func _start_brood() -> void:
	_brood_t = 7.0 if enraged else 10.0
	_brooding = true
	_drive = Vector3.ZERO
	_wish = Vector3.ZERO
	_set_state(SPECIAL)
	if _rig and _rig.has_method("telegraph"):
		_rig.call("telegraph", BROOD_TELL)
	_glint = 1.0
	Sfx.play_stream(Synth.voice(voice_family(), "tell"), global_position + Vector3.UP * 2.0, 2.0, 0.55)
	begin_cast("Brood", BROOD_TELL, false)
	Hints.once(&"brood", "The swelling sac is about to hatch. A blow on the body leaves the brood; a bolt that bursts on the sac ruptures it.")


func _on_state(next: int) -> void:
	if next == SPECIAL:
		return
	super._on_state(next)


func _special_think() -> void:
	_wish = Vector3.ZERO
	if _p:
		_face_dir = _to / maxf(_dist, 0.001)
	if _state_t >= BROOD_TELL:
		_brooding = false
		_hatch()
		_set_state(RECOVER)
		_state_t = -0.4


func _hatch() -> void:
	var mine := 0
	var gid := "guardian_" + String(get_meta(&"guardian_key", "brood"))   # Guardians takes them back with her
	for e in get_tree().get_nodes_in_group(Groups.ENEMY):
		if (e as Node).get_meta(&"summoned_by", "") == gid and (e as Enemy).is_alive():
			mine += 1
	var n := mini(3, 6 - mine)
	if n <= 0:
		return
	var host := get_parent()
	var got := BossKit.summon(host, load(MITE) as GDScript, global_position, n, 1.8, gid)
	broods += got.size()
	for m in got:
		m.alerted(self)
	Vfx.burst(_sac.global_position if _sac else global_position + Vector3.UP * 2.0, Color(0.3, 1.6, 1.1), {"count": 40, "life": 0.6, "speed": Vector2(2.0, 5.0), "size": 0.07, "gravity": -8.0, "additive": false})
	Sfx.play("res://art/audio/spit.wav", global_position + Vector3.UP * 2.0, 2.0, 0.5)


func _special_breakable() -> bool:
	return false                             # only the sac breaks the brood


## The sac found: always the weak point's damage; during the brood it ruptures it.
func _on_weak_hit(_dmg: float) -> void:
	if not (_state == SPECIAL and _brooding):
		return
	_brooding = false
	ruptures += 1
	_stagger_cd = 0.0
	stagger()
	HitText.pop(global_position + Vector3.UP * (hp_bar_y + 0.9), "the brood ruptures", WEAK_COL, true)
	Vfx.burst(_sac.global_position if _sac else global_position + Vector3.UP * 2.0, Color(0.3, 1.6, 1.1), {"count": 50, "life": 0.7, "speed": Vector2(2.0, 6.0), "size": 0.08, "gravity": -9.0, "additive": false})
	AttackKit.linger(global_position, 1.6, 3.0, 3.0, 0.5, Color(0.2, 1.1, 0.75))


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _state == DEAD:
		return
	if not enraged and hp <= float(max_hp) * 0.5:
		enraged = true
		walk_speed *= 1.15
		weak_r = 0.28
		_brood_t = minf(_brood_t, 2.5)
		Sfx.play_stream(Synth.voice(voice_family(), "call"), global_position + Vector3.UP * 2.5, 3.0, 0.5)
		HitText.pop(global_position + Vector3.UP * (hp_bar_y + 0.9), "enraged", Color(1.2, 0.6, 0.3), true)
		Vfx.ring(global_position + Vector3.UP * 0.15, 6.0, Color(0.3, 1.6, 1.1), 0.8, 0.06, Vector3.UP, 1.2)
	if _sac and _state == SPECIAL and _brooding:
		var k := clampf(_state_t / BROOD_TELL, 0.0, 1.0)
		_sac.scale = Vector3.ONE * (1.4 + k * 1.1 + sin(_state_t * 24.0) * 0.1 * k)
		_sac.set_instance_shader_parameter(&"swell", k)
	elif _sac and _state != WINDUP:
		_sac.scale = Vector3.ONE * (1.4 if not enraged else 1.8)
