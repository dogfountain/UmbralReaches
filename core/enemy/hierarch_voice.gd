class_name HierarchVoice
extends Husk
## The Speaking Crown: boss of the Fallen Hierarch's skull (core/world/hierarch_raid.gd). The colossus's
## head was hollow so that one voice could be heard across the Marches; the cantor who spoke the Hierarch's
## edicts through it was never let out. A husk of cracked stone cope and a speaking-horn for a head, 3.4x,
## on the floor of the split skull. Sound is its weapon: everything it does is a cone, a ring or a sweep that
## fills red first, and its tell is the horn opening (the mouth is the weak point while it gathers an edict).
##
## Phase I   "The Edict" (100-65 %)
##   Edict of Silence   (interruptible: a blow into the open horn, or a heavy blow) a wide cone fills; if it
##                      lands it wounds. The signature: break it or stand out of it.
##   Echo               (after an edict) the same voice returns: a ring round it, its own feet safe.
##   Falling Crown      the skull sheds its tiara: discs of falling stone round you, each filled first.
##   the husk's own fist and rake (Husk), with a ground tell.
## Phase II  "The Fall" (65-30 %)
##   Choir              two Cantors answer from the dark (chanters), up to four. While one lives the Crown
##                      takes a third less: kill the Cantors first.
##   Toll of the Crown  (cannot be broken) the crown's tines fall in a sweep: lanes from the centre, one after
##                      another, round the whole floor like a clock hand. Move with the gap, not against it.
##   Double Edict       two cones at once.
## Phase III "The Turning Sky" (30-0 %)
##   Verdict            three rings burst outward, one after another: stand in the gaps between them.
##   everything comes quicker; the stone falls more often.
## Save state: Travel.bosses_slain "r37_hierarch" (the arena). Loot: the fallback table + the trophy.

const SCALE := 3.4
const HP := 640
const EDICT_TIME := 2.2
const EDICT_R := 17.0
const EDICT_EVERY := 11.0
const FALL_EVERY := 8.5
const CHOIR_EVERY := 30.0
const TOLL_EVERY := 24.0
const VERDICT_EVERY := 17.0
const CANTOR := preload("res://core/enemy/chanter.gd")
const Raid := preload("res://core/world/hierarch_raid.gd")

var phase := 1
var _sig := 0                    ## edicts shown (landed or broken) this phase
var _edict_t := 6.0
var _fall_t := 3.0
var _choir_t := 12.0
var _toll_t := 14.0
var _verdict_t := 5.0
var _open_t := 0.0               ## seconds the horn stays open (the edict's windup)
var _echo_pending := 0.0
var _arena_c := Vector3.INF
var _arena_r := 20.0
var _room: Raid = null
var _edict_dir := Vector3.FORWARD


func _init() -> void:
	super._init()
	body_kind = &"hierarch"
	max_hp = HP
	hp = float(HP)
	walk_speed = 3.0
	strike_gloom = 40.0
	weak_socket = "head"                      # the horn's mouth
	weak_offset = Vector3(0.0, 0.52, -0.2)
	weak_r = 0.22
	weak_open = false


func phase_marks() -> Array[float]:
	return [0.65, 0.3]


func _build() -> void:
	super._build()
	name = "HierarchVoice"
	BossKit.embiggen(self, SCALE)
	posture({"hunch": 0.0, "crouch": 0.0, "arm_reach": 0.12, "head_jut": 0.0, "limp": 0.0, "sway": 0.25, "twitch": 0.0, "splay": 0.2})


func on_engaged(arena: Node) -> void:
	BossKit.intro(self, BossKit.BONE, 2.4)
	_room = (arena as BossArena).room as Raid if arena is BossArena else null
	if arena is Node3D:
		_arena_c = (arena as Node3D).global_position
		_arena_r = (arena as BossArena).radius if arena is BossArena else 20.0
	BossKit.emote(self, "The skull rings. Something in the horn draws breath.")


func _absorb(dmg: float, from: Node) -> float:
	if phase == 2 and cantors() > 0:
		dmg *= 0.67
		var now := Time.get_ticks_msec()
		if now - int(get_meta(&"choir_pop", 0)) > 700:
			set_meta(&"choir_pop", now)
			HitText.pop(global_position + Vector3.UP * (hp_bar_y + 0.6), "the choir holds it", Color(0.95, 0.9, 0.7))
	return BossKit.absorb(self, dmg, from, BossKit.phase_floor(self, phase, phase_marks(), _sig))


## The rig's roar, when it has one (the husk's hunch rig does).
func _howl(t: float) -> void:
	if _rig is HunchRig:
		(_rig as HunchRig).howl(t)


func cantors() -> int:
	if not is_inside_tree():
		return 0
	var n := 0
	var bid := String(get_meta(&"boss_id", ""))
	for e in get_tree().get_nodes_in_group(Groups.ENEMY):
		if e != self and e is Enemy and (e as Enemy).is_alive() and String((e as Node).get_meta(&"display_name", "")) == "Cantor" and String((e as Node).get_meta(&"summoned_by", "")) == bid:
			n += 1
	return n


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _state == DEAD:
		return
	if phase == 1 and hp <= float(max_hp) * 0.65:
		phase = 2
		_sig = 0
		_edict_t = 8.0
		_choir_t = 3.0
		_toll_t = 12.0
		BossKit.transition(self, "The horn splits. A second voice, and a third.", BossKit.BONE)
		BossKit.emote(self, "The crown sheds its tines. The Choir answers.", Color(1.0, 0.82, 0.5))
		if _room != null:
			_room.set_mood("fall")
	elif phase == 2 and hp <= float(max_hp) * 0.3:
		phase = 3
		_sig = 0
		_verdict_t = 5.0
		_edict_t = 7.0
		walk_speed = 3.7
		BossKit.transition(self, "", BossKit.RAGE, 1.6)
		BossKit.emote(self, "The sky turns in the horn. The Verdict.", Color(1.0, 0.45, 0.3))
		if _room != null:
			_room.set_mood("sky")
	_open_t = maxf(0.0, _open_t - delta)
	weak_open = _open_t > 0.0
	if _ward_t > 0.0 or _p == null:
		return
	var quick := 0.8 if phase >= 3 else 1.0
	_fall_t -= delta
	_edict_t -= delta
	if phase >= 2:
		_choir_t -= delta
		_toll_t -= delta
	if phase >= 3:
		_verdict_t -= delta
	if _echo_pending > 0.0:
		_echo_pending -= delta
		if _echo_pending <= 0.0:
			_echo()
	if casting() and cast_name in ["Edict of Silence", "Double Edict", "Toll of the Crown", "Verdict"]:
		_state_t = minf(_state_t, 0.0)           # it holds still while it speaks
		velocity.x = 0.0
		velocity.z = 0.0
		return
	if casting():
		return
	if not is_on_floor():
		return
	if phase >= 3 and _verdict_t <= 0.0:
		_verdict_t = VERDICT_EVERY * quick
		_edict_t = maxf(_edict_t, 4.5)
		_toll_t = maxf(_toll_t, 5.0)
		_verdict()
	elif phase >= 2 and _toll_t <= 0.0:
		_toll_t = TOLL_EVERY * quick
		_edict_t = maxf(_edict_t, 5.0)
		_toll()
	elif phase >= 2 and _choir_t <= 0.0:
		_choir_t = CHOIR_EVERY
		BossKit.cast(self, "Call the Choir", 1.6, false, _choir)
		BossKit.emote(self, "Cantors answer from the cracks. Its voice is thick: your blows are cut by a third.")
		_howl(1.4)
	elif _edict_t <= 0.0 and _dist < 24.0:
		_edict_t = EDICT_EVERY * quick - (1.5 if phase == 2 else 0.0)
		_fall_t = maxf(_fall_t, EDICT_TIME + 1.0)
		_edict(2 if phase >= 2 else 1)
	elif _fall_t <= 0.0:
		_fall_t = FALL_EVERY * quick
		_falling_crown()


## Edict of Silence: the horn opens, a cone fills toward you. `n` cones (two fan apart in phase II).
func _edict(n: int) -> void:
	var to := _p.global_position - global_position
	to.y = 0.0
	if to.length() < 0.5:
		return
	_edict_dir = to.normalized()
	_face_dir = _edict_dir
	_set_state(RECOVER)
	_state_t = -EDICT_TIME
	velocity = Vector3.ZERO
	_glint = 1.0
	_open_t = EDICT_TIME + 0.05
	_howl(EDICT_TIME)
	var label := "Edict of Silence" if n == 1 else "Double Edict"
	BossKit.cast(self, label, EDICT_TIME, true, _edict_lands)
	BossKit.emote(self, "The horn opens on you. A blow into its mouth breaks the edict.", Color(1.0, 0.82, 0.45))
	var yaw0 := atan2(-_edict_dir.x, -_edict_dir.z)
	for k in n:
		var yaw := yaw0 + (0.0 if n == 1 else deg_to_rad(26.0) * (float(k) - 0.5) * 2.0)
		BossKit.zone(get_parent(), global_position, EDICT_TIME, 30.0, {"by": self, "radius": EDICT_R, "half_angle": 0.62, "yaw": yaw, "h": 3.0,
			"color": BossKit.BONE})
	Sfx.play_stream(Synth.get_stream("chant"), global_position + Vector3.UP * 3.0, 3.0, 0.55)


func _edict_lands() -> void:
	if not is_alive():
		return
	_sig += 1
	_open_t = 0.0
	Vfx.ring(global_position + Vector3.UP * 0.2, 9.0, BossKit.BONE, 0.7, 0.08, Vector3.UP, 1.3)
	_echo_pending = 1.5


## The voice returns off the walls: a ring round it, its own feet the safe place.
func _echo() -> void:
	if not is_alive() or _ward_t > 0.0:
		return
	BossKit.cast(self, "Echo", 1.3)
	var c := global_position
	BossKit.zone(get_parent(), c, 1.3, 24.0, {"by": self, "radius": 8.0, "holes": [[c, 2.4]], "color": Color(2.0, 1.4, 0.6), "h": 2.5})


func _on_weak_hit(_dmg: float) -> void:
	if _open_t <= 0.0:
		return
	_open_t = 0.0
	weak_open = false
	if not interrupt(null):
		_torn("the horn chokes")


func _on_cast_interrupted(n: String) -> void:
	if n == "Edict of Silence" or n == "Double Edict":
		_sig += 1
		_torn("the edict breaks in its mouth")


func _torn(line: String) -> void:
	_open_t = 0.0
	weak_open = false
	_echo_pending = 0.0
	cancel_moves()
	_stagger_cd = 0.0
	stagger()
	_broken_t = BOSS_BROKEN
	HitText.pop(global_position + Vector3.UP * (hp_bar_y + 1.0), line, WEAK_COL, true)
	Vfx.burst(global_position + Vector3.UP * hp_bar_y * 0.6, BossKit.BONE, {"count": 40, "life": 0.6, "speed": Vector2(2.0, 6.0), "size": 0.06, "gravity": -6.0})


## Falling Crown: stone drops round you (and one on you), every disc filled first.
func _falling_crown() -> void:
	var n := 4 if phase == 1 else (5 if phase == 2 else 7)
	var space := get_world_3d().direct_space_state
	var c: Vector3 = _arena_c if _arena_c != Vector3.INF else global_position
	BossKit.cast(self, "Falling Crown", 1.5)
	BossKit.emote(self, "The skull sheds its crown.", Color(1.0, 0.7, 0.4))
	for i in n:
		var at := _p.global_position
		if i > 0:
			var a := randf() * TAU
			at += Vector3(cos(a), 0.0, sin(a)) * randf_range(3.0, 11.0)
		var d := at - c
		d.y = 0.0
		if d.length() > _arena_r - 2.0:
			at = c + d.normalized() * (_arena_r - 2.0)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 4.0, at + Vector3.DOWN * 8.0, Layers.WORLD))
		if not hit.is_empty():
			at = hit.position
		BossKit.zone(get_parent(), at, 1.5 + 0.12 * float(i), 24.0, {"by": self, "radius": 2.7, "spikes": "", "color": Color(1.8, 1.1, 0.5), "h": 2.5})
		if _room != null:
			_room.rain_stone(at, 1.5 + 0.12 * float(i))


func _choir() -> void:
	var adds := BossKit.add_wave(self, CANTOR, global_position, 2, 4, "Cantor", 7.0)
	for a in adds:
		SpellFx.column(a.global_position, 0.8, 4.0, 0.6)
	if not adds.is_empty():
		HitText.pop(global_position + Vector3.UP * (hp_bar_y + 1.0), "the choir answers", BossKit.BONE)


## Toll of the Crown: lanes from the centre, one after another, a clock hand round the floor.
func _toll() -> void:
	_set_state(RECOVER)
	_state_t = -2.6
	velocity = Vector3.ZERO
	_glint = 1.0
	_howl(2.4)
	BossKit.cast(self, "Toll of the Crown", 2.4)
	BossKit.emote(self, "The crown's tines fall in order. Go with the gap.", Color(1.0, 0.6, 0.35))
	var c: Vector3 = _arena_c if _arena_c != Vector3.INF else global_position
	var from := atan2(_p.global_position.z - c.z, _p.global_position.x - c.x)
	var dirn := -1.0 if randf() < 0.5 else 1.0
	var steps := 14
	for i in steps:
		var a := from + dirn * (0.32 * float(i) + 0.4)
		var yaw := atan2(-cos(a), -sin(a))                        # the lane runs from the centre out along `a`
		var delay := 1.6 + 0.2 * float(i)
		BossKit.zone(get_parent(), c, delay, 26.0, {"by": self, "rect": Vector2(1.2, _arena_r * 0.5), "yaw": yaw, "spikes": "", "color": Color(1.9, 1.0, 0.45), "h": 3.0})


## Verdict: three rings out from it, one after another; the gaps between are safe.
func _verdict() -> void:
	_set_state(RECOVER)
	_state_t = -1.6
	velocity = Vector3.ZERO
	_glint = 1.0
	_howl(1.4)
	BossKit.cast(self, "Verdict", 1.5)
	BossKit.emote(self, "The Verdict: three voices. Stand between them.", Color(1.0, 0.45, 0.3))
	var c := global_position
	for rg: Array in [[1.4, 2.6, 5.4], [2.3, 9.0, 12.0], [3.2, 15.5, 18.5]]:
		BossKit.zone(get_parent(), c, float(rg[0]), 26.0, {"by": self, "radius": float(rg[2]), "holes": [[c, float(rg[1])]], "color": Color(2.4, 0.9, 0.35), "h": 3.0})
	_sig += 1


func voice_family() -> String:
	return "hierarch"


func _hit_sound() -> String:
	return "stone"
