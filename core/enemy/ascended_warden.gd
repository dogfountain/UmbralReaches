class_name AscendedWarden
extends Husk
## Boss of the summit: a towering hollowed priest at 2.2x that floats in a bell robe (no legs), a
## white-gold mask and a mandorla of light behind its head (r30: it was violet, a hedgehog of rods). It blinks round the dais and judges from range.
## Phase 1  every 5 s it blinks to another point of the dais (rift-out, rift-in), raises its hands
##          (the fan's cone fills on the ground) and throws a fan of seven orbs.
## Phase 2  (below 60 %) blinks every 3.5 s and each arrival throws a shock ring; between blinks it
##          calls judgement: two lanes of light across the dais, through you.
## Phase 3  (below 30 %) the halo breaks open: blinks every 2.6 s, two fans, and a wide ring of
##          light round itself after each arrival.
## r31 (docs/enshrouded/enemies.md):
##   halo     while its hands are up for a fan, the broken halo behind its head burns open (a gold
##            knot): a bolt that bursts on it scatters the volley (the cone fades, no orbs) and it
##            reels, broken. The fan still counts as shown.
##   eclipse  (phase III, every 12 s) the light goes out of the dais: the whole floor fills dark-
##            gold for 2.6 s, save two pillars of light at its blink points. Stand in its light.
## r33 (WoW encounter design; every move is a cast the HUD shows, see BossKit):
##   Radiant Fan (interruptible: the halo, or a heavy blow) / Judgement / Eclipse (stand IN the light)
##   Mandorla Flare  (phase II+, every 14 s) the light behind it flares: the whole dais from FLARE_IN to
##            FLARE_R round it fills for 2 s -- only its own feet are safe. Get under it.
##   Call the Acolytes  (phase II+, every 30 s) a 2 s cast (a heavy blow interrupts); unbroken, two
##            Gilded Acolytes (Chanters) step out of the light to sigil you and shroud each other.
##   The Door Closes  soft enrage at ENRAGE_AT s: more Gloom per orb and lane, quicker judgement.

const FAN_WINDUP := 0.85

var phase := 1
var _sig := 0                   ## r30: signature moves this phase (I: fans, II: judgements, III: double fans)
var anchors: Array[Vector3] = []
var _blink_t := 5.0
var _fan_t := 99.0
var _fans_left := 0
var _judge_t := 3.0
var _eclipse_t := 6.0
var _arena_c := Vector3.INF
var _arena_r := 10.0
const ECLIPSE_EVERY := 12.0
const ECLIPSE_FILL := 2.6
const POOL_R := 2.3
const FLARE_EVERY := 14.0
const FLARE_TIME := 2.0
const FLARE_IN := 3.2
const FLARE_R := 11.0
const ACOLYTES_EVERY := 30.0
const ENRAGE_AT := 210.0
const ACOLYTE := preload("res://core/enemy/chanter.gd")
var _flare_t := 6.0
var _acolytes_t := 10.0


func _init() -> void:
	super._init()
	body_kind = &"ascended_warden"
	max_hp = 220                # r30: at 120 phase III was ~5 s, two blinks (r29: 60)
	hp = 220.0
	walk_speed = 2.2
	strike_gloom = 42.0
	weak_socket = "head"                        # the halo, behind the mask
	weak_offset = Vector3(0.0, 0.14, 0.22)
	weak_r = 0.12
	weak_open = false


func phase_marks() -> Array[float]:
	return [0.6, 0.3]


func _build() -> void:
	super._build()
	name = "AscendedWarden"
	BossKit.embiggen(self, 2.2)
	posture({"hunch": 0.05, "crouch": 0.0, "arm_reach": 0.1, "head_jut": 0.1, "limp": 0.0, "sway": 0.4, "twitch": 0.0, "splay": 0.15})
	# its halo lights the dais (it was lit only by the player's lantern)
	var head := _rig.socket("head") if _rig else null
	if head:
		var l := OmniLight3D.new()
		l.name = "Halo"
		l.light_color = Color(1.0, 0.9, 0.7)
		l.light_energy = 1.8
		l.omni_range = 8.0
		l.shadow_enabled = false
		head.add_child(l)
		l.position = Vector3(0.0, 0.14, 0.22)


func _absorb(dmg: float, from: Node) -> float:
	return BossKit.absorb(self, dmg, from, BossKit.phase_floor(self, phase, phase_marks(), _sig))


func on_engaged(arena: Node) -> void:
	BossKit.intro(self, BossKit.HOLY)
	if anchors.is_empty() and arena is Node3D:
		var c := (arena as Node3D).global_position
		# six blink points over the whole dais, each dropped onto whatever floor is below it
		var reach: float = (arena as BossArena).radius * 0.7 if arena is BossArena else 8.0
		_arena_c = c
		_arena_r = (arena as BossArena).radius if arena is BossArena else 11.0
		var space := (arena as Node3D).get_world_3d().direct_space_state
		for i in 6:
			var a := TAU * float(i) / 6.0 + PI / 6.0
			var p := c + Vector3(cos(a) * reach, 3.0, sin(a) * reach)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p, p + Vector3.DOWN * 8.0, Layers.WORLD))
			if hit:
				anchors.append(hit.position as Vector3)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _state == DEAD:
		return
	delta *= BossKit.enrage_tick(self, delta, ENRAGE_AT)     # r33: the Door Closes: quicker judgement
	if phase == 1 and hp <= float(max_hp) * 0.6:
		phase = 2
		_sig = 0
		_fan_t = 99.0                           # a volley still winding up is taken back with its cone
		_fans_left = 0
		BossKit.transition(self, "His light turns to judgement. One hand never leaves the door.", BossKit.HOLY)
		_blink_t = 1.5
	elif phase == 2 and hp <= float(max_hp) * 0.3:
		phase = 3
		_sig = 0
		_fan_t = 99.0
		_fans_left = 0
		BossKit.transition(self, "He lets go of the door with one hand. What it held pours out.", BossKit.HOLY, 1.2)
		_blink_t = 1.25
	if _ward_t > 0.0:
		return                                  # reeling between phases: nothing new starts
	_blink_t -= delta
	_fan_t -= delta
	_judge_t -= delta
	_eclipse_t -= delta
	_flare_t -= delta
	_acolytes_t -= delta
	weak_open = _fan_t > 0.0 and _fan_t <= FAN_WINDUP + 0.05
	if phase >= 2 and _fan_t > 50.0 and not casting() and _p != null:
		if _acolytes_t <= 0.0:
			_acolytes_t = ACOLYTES_EVERY
			_blink_t = maxf(_blink_t, 2.4)
			BossKit.cast(self, "Call the Acolytes", 2.0, true, _call_acolytes)
			if _rig and _rig.has_method("howl"):
				_rig.call("howl", 2.0)
			return
		if _flare_t <= 0.0 and _eclipse_t > FLARE_TIME + 1.0:
			_flare_t = FLARE_EVERY
			_mandorla_flare()
			return
	if phase >= 3 and _eclipse_t <= 0.0 and anchors.size() >= 2 and _arena_c != Vector3.INF and _fan_t > 50.0:
		_eclipse_t = ECLIPSE_EVERY
		_blink_t = maxf(_blink_t, ECLIPSE_FILL + 0.4)
		_eclipse()
		return
	if _blink_t <= 0.0 and not anchors.is_empty() and _state != WINDUP and _state != STRIKE:
		_blink_t = [5.0, 3.5, 2.6][phase - 1]
		_blink()
	if _fan_t <= 0.0:
		_fan_t = 99.0
		_fan()
		_fans_left -= 1
		if _fans_left <= 0 and phase != 2:
			_sig += 1                       # a whole volley (single in I, double in III) shown
		if _fans_left > 0:
			_fan_t = 0.55
			BossKit.cast(self, "Radiant Fan", 0.55, true)
	if phase >= 2 and _judge_t <= 0.0 and _p != null and _fan_t > 50.0:
		_judge_t = 4.5 if phase == 2 else 3.6
		_judgement()
		if phase == 2:
			_sig += 1


func _blink() -> void:
	var to := anchors.pick_random() as Vector3
	SpellFx.rift_in(global_position)
	global_position = to + Vector3.UP * 0.1
	velocity = Vector3.ZERO
	reset_physics_interpolation()           # a blink, not a one-frame smear across the dais
	_set_state(IDLE if _p == null else CHASE)
	SpellFx.rift_in(to)
	if phase >= 2:
		BossKit.zone(get_parent(), to, 0.65, 26.0, {"by": self, "radius": 4.0 if phase == 2 else 5.6, "color": BossKit.HOLY})
	_aim_fan(phase >= 3)


## Hands up and the fan's cone fills on the ground before the orbs leave.
func _aim_fan(double: bool) -> void:
	if _p == null:
		return
	var to := _p.global_position - global_position
	to.y = 0.0
	_face_dir = to.normalized()
	if _rig and _rig.has_method("telegraph"):
		_rig.call("telegraph", FAN_WINDUP)
	_glint = 1.0
	BossKit.cast(self, "Radiant Fan", FAN_WINDUP, true)
	var cone := SpellFx.danger(global_position, FAN_WINDUP, {"radius": 14.0, "half_angle": deg_to_rad(33.0), "yaw": atan2(-to.x, -to.z), "color": BossKit.HOLY})
	if cone:
		track_move(cone)
	_fan_t = FAN_WINDUP
	_fans_left = 2 if double else 1


func _fan() -> void:
	var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	if p == null:
		return
	if casting() and cast_name == "Radiant Fan":
		_finish_cast(false, false)              # the volley is away (the bar may trail a hastened clock)
	if _rig and _rig.has_method("strike"):
		_rig.call("strike")
	var from := global_position + Vector3.UP * (hp_bar_y * 0.7)
	var aim := (p.global_position + Vector3.UP - from)
	var off := 5.0 if _fans_left == 1 and phase >= 3 else 0.0     # the second volley fills the gaps
	for k in 7:
		var ang := deg_to_rad(-30.0 + 10.0 * float(k) + off)
		SpitOrb.launch(get_tree().current_scene, from, aim.rotated(Vector3.UP, ang), 17.0)
	Vfx.burst(from, Color(1.4, 0.6, 2.6), {"count": 30, "life": 0.4, "speed": Vector2(2.0, 5.0), "size": 0.05, "dir": aim.normalized(), "spread": 40.0, "gravity": 0.0})


## Two lanes of light crossing at the player, 1.1 s to step out of both.
func _judgement() -> void:
	var at := _p.global_position
	var base := randf() * PI
	BossKit.cast(self, "Judgement", 1.1)
	for k in 2:
		var yaw := base + PI * 0.5 * float(k)
		var dir := Basis(Vector3.UP, yaw) * Vector3.FORWARD
		BossKit.zone(get_parent(), at - dir * 7.0, 1.1, 24.0, {"by": self, "rect": Vector2(1.0, 7.0), "yaw": yaw, "color": BossKit.HOLY})


## The halo found while its hands are up: the volley scatters.
func _on_weak_hit(_dmg: float) -> void:
	if not (_fan_t > 0.0 and _fan_t <= FAN_WINDUP + 0.05):
		return
	if not interrupt(null):
		_scatter()


## r33: the fan broken by the halo or a heavy blow; the acolytes' call by a heavy blow.
func _on_cast_interrupted(n: String) -> void:
	if n == "Radiant Fan":
		_scatter()
	elif n == "Call the Acolytes":
		_stagger_cd = 0.0
		stagger()
		_broken_t = BOSS_BROKEN
		HitText.pop(global_position + Vector3.UP * (hp_bar_y + 1.0), "no one answers", WEAK_COL, true)


func _call_acolytes() -> void:
	var adds := BossKit.add_wave(self, ACOLYTE, global_position, 2, 3, "Gilded Acolyte", 4.5)
	for a in adds:
		SpellFx.column(a.global_position, 0.8, 4.0, 0.6)


## Mandorla Flare: the dais burns from FLARE_IN to FLARE_R round it; only under it is safe.
func _mandorla_flare() -> void:
	var c := global_position
	_set_state(RECOVER)
	_state_t = -FLARE_TIME
	velocity = Vector3.ZERO
	_blink_t = maxf(_blink_t, FLARE_TIME + 0.6)
	_judge_t = maxf(_judge_t, FLARE_TIME + 0.8)
	_glint = 1.0
	if _rig and _rig.has_method("howl"):
		_rig.call("howl", FLARE_TIME)
	BossKit.cast(self, "Mandorla Flare", FLARE_TIME)
	Hints.once(&"mandorla", "Mandorla Flare: only the ground under the Warden is spared. Get close.")
	# the safe ground reads like the eclipse's pillars: a column of its own light at its feet
	SpellFx.column(c, FLARE_IN * 0.8, 6.0, FLARE_TIME + 0.3)
	Vfx.ring(c + Vector3.UP * 0.1, FLARE_IN, Color(1.0, 0.9, 0.6), FLARE_TIME, 0.12, Vector3.UP, 1.6)
	Vfx.light(c + Vector3.UP * 1.0, Color(1.0, 0.85, 0.55), 2.0, FLARE_IN * 2.0, FLARE_TIME)
	Sfx.play_stream(Synth.get_stream("chant"), c + Vector3.UP * 3.0, 2.0, 0.6)
	BossKit.zone(get_parent(), c, FLARE_TIME, 30.0, {"by": self, "radius": FLARE_R, "color": BossKit.HOLY, "holes": [[c, FLARE_IN]], "h": 3.0})


func _scatter() -> void:
	if _fans_left > 0 and phase != 2:
		_sig += 1                               # the volley was shown (the floor's count is kept)
	_fan_t = 99.0
	_fans_left = 0
	weak_open = false
	cancel_moves()
	stagger()
	_broken_t = BOSS_BROKEN
	HitText.pop(global_position + Vector3.UP * (hp_bar_y + 1.0), "the halo cracks", WEAK_COL, true)
	Vfx.burst(global_position + Vector3.UP * hp_bar_y * 0.95, BossKit.HOLY, {"count": 50, "life": 0.7, "speed": Vector2(2.0, 7.0), "size": 0.06, "gravity": -3.0})


## Eclipse: the dais fills, but for two pillars of its light at blink points away from it.
func _eclipse() -> void:
	if _rig and _rig.has_method("howl"):
		_rig.call("howl", ECLIPSE_FILL)
	_glint = 1.0
	Sfx.play_stream(Synth.get_stream("chant"), global_position + Vector3.UP * 3.0, 3.0, 0.45)
	Events.toast.emit("The light goes out of the dais. Stand in what is left of it.")
	BossKit.cast(self, "Eclipse", ECLIPSE_FILL)
	var picks := anchors.duplicate()
	picks.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.distance_to(global_position) > b.distance_to(global_position))
	var holes: Array = []
	for k in 2:
		var at: Vector3 = picks[k]
		holes.append([at, POOL_R])
		SpellFx.column(at, POOL_R * 0.8, 6.0, ECLIPSE_FILL + 0.3)
		Vfx.ring(at + Vector3.UP * 0.1, POOL_R, BossKit.HOLY, ECLIPSE_FILL, 0.12, Vector3.UP, 1.6)
		Vfx.light(at + Vector3.UP * 2.0, Color(1.0, 0.85, 0.55), 3.0, POOL_R * 3.0, ECLIPSE_FILL + 0.3)
	BossKit.zone(get_parent(), _arena_c, ECLIPSE_FILL, 34.0, {"by": self, "radius": _arena_r * 0.92, "color": Color(1.6, 1.0, 0.25), "holes": holes, "h": 3.0})
