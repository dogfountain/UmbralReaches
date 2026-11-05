class_name Thornwarden
extends Leaper
## Boss of the Thorn Henge: a leaper twice the size, bark and thorn, antlered with briar.
## Phase 1  long pounces across the ring; the landing spot fills red for the whole flight, and it
##          lands in a small slam. Melee rakes between pounces.
## Phase 2  (below half) a roar, three crawlers called from the stones (once), every landing throws
##          a wide thorn slam, and every 6.5 s it drives three lanes of thorns toward you (filled
##          red first; step out of the lanes).
## r31 (docs/enshrouded/enemies.md):
##   bramble lash  (both phases) stand in its blind half -- behind or under it -- for a second and a
##                 ring of thorns fills round its whole body: it will not be farmed from behind.
##   heart-knot    while it rears to drive the lanes, the knot of ember at its breast opens (a gold
##                 glow): a bolt that bursts on it tears the volley out of the ground (the lanes
##                 fade) and it reels, broken.
##   snare         (phase II, every 11 s) a ring of thorn fills round YOU, open only on the side
##                 facing it; as it closes the Warden coils and pounces into the middle. Go out
##                 through the gap (toward it, under the leap) or Rift Step through the briars.
## r33 (WoW encounter design; every move below is a cast the HUD shows, see BossKit):
##   Bramble Pounce / Thornlash Volley (interruptible: the heart-knot, or a heavy blow) / Briar Snare /
##   Bramble Lash (positional: never stand behind it)
##   Sap Mending   (phase II, below 45 %, every 24 s) it roots and drinks from the henge for 3 s: the
##                 heart-knot burns open. Interrupt it (a burst on the knot, or a heavy blow) or it heals
##                 MEND of its health.
##   Call of the Stones  (phase II, every 28 s) two Briarlings claw out of the stones (four at most).
##   Overgrowth    soft enrage at ENRAGE_AT s: its blows and thorns fill more Gloom, its moves come faster.

const SLAM_R := 2.6
const SLAM_R2 := 4.4
const LANES_EVERY := 6.5

var phase := 1
var _sig := 0                   ## r30: signature moves shown this phase (pounces in I, lane volleys in II)
var _land_at := Vector3.INF
var _lanes_t := 3.0
var _behind_t := 0.0
var _lash_cd := 3.0
var _snare_t := 7.0
var _knot_t := 0.0              ## seconds the heart-knot stays open (the lanes' windup)
const LASH_R := 3.9
const SNARE_R := 4.0
const SNARE_EVERY := 11.0
const MEND_EVERY := 24.0
const MEND_TIME := 3.0
const MEND := 0.08              ## of max health, if the mending is not broken
const WAVE_EVERY := 28.0
const ENRAGE_AT := 150.0
var _mend_t := 6.0
var _wave_t := 14.0


func _init() -> void:
	super._init()
	body_kind = &"thornwarden"
	max_hp = 110                # r30: 72 still ended before phase 2 showed its lanes twice (r29: 36)
	hp = 110.0
	walk_speed = 4.6
	strike_gloom = 38.0
	leap_max = 15.0
	leap_cooldown = 1.8
	leap_prep = 0.65
	weak_socket = "front"
	weak_offset = Vector3(0.0, 0.05, -0.2)
	weak_r = 0.12
	weak_open = false


func phase_marks() -> Array[float]:
	return [0.5]


func on_engaged(_arena: Node) -> void:
	BossKit.intro(self, BossKit.THORN)


func _absorb(dmg: float, from: Node) -> float:
	return BossKit.absorb(self, dmg, from, BossKit.phase_floor(self, phase, phase_marks(), _sig))


func _build() -> void:
	super._build()
	name = "Thornwarden"
	BossKit.embiggen(self, 2.0)


func _pounce(player: Player) -> void:
	super._pounce(player)
	if phase == 1:
		_sig += 1
	# the jump is committed: show where it comes down, for exactly the time it is in the air
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	var t := flight_time(leap_apex, player.global_position.y - global_position.y)
	_land_at = global_position + flat * t
	_land_at.y = player.global_position.y
	BossKit.zone(get_parent(), _land_at, maxf(t, 0.3), 30.0 if phase >= 2 else 22.0,
		{"by": self, "radius": SLAM_R2 if phase >= 2 else SLAM_R, "spikes": "thorn" if phase >= 2 else ""})


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _state == DEAD:
		return
	delta *= BossKit.enrage_tick(self, delta, ENRAGE_AT)     # r33: Overgrowth quickens every timer below
	if phase == 1 and hp <= float(max_hp) * 0.5:
		phase = 2
		_sig = 0
		BossKit.transition(self, "Keeper, keep. The thorns wake, and the stones bleed crawlers.", BossKit.THORN)
		BossKit.summon(get_parent(), Crawler, global_position, 3, 4.0, String(get_meta(&"boss_id", "")))
		_lanes_t = 2.0
	_knot_t = maxf(0.0, _knot_t - delta)
	weak_open = _knot_t > 0.0
	if _ward_t > 0.0 or _p == null:
		return                                  # shelled (intro, between phases): nothing new starts
	_lash_cd = maxf(0.0, _lash_cd - delta)
	_tick_lash(delta)
	if phase >= 2 and _state != AIRBORNE and _state != LEAP_PREP:
		_lanes_t -= delta
		_snare_t -= delta
		_mend_t -= delta
		_wave_t -= delta
		if casting() and cast_name == "Sap Mending":
			_state_t = minf(_state_t, 0.0)       # rooted while it drinks
		elif _mend_t <= 0.0 and hp < float(max_hp) * 0.45 and is_on_floor():
			_mend_t = MEND_EVERY
			_lanes_t = maxf(_lanes_t, MEND_TIME + 1.0)
			_snare_t = maxf(_snare_t, MEND_TIME + 2.0)
			_sap_mending()
		elif _wave_t <= 0.0:
			_wave_t = WAVE_EVERY
			BossKit.cast(self, "Call of the Stones", 1.4, false, _call_stones)
			if _rig and _rig.has_method("howl"):
				_rig.call("howl", 1.2)
		elif _lanes_t <= 0.0:
			_lanes_t = LANES_EVERY
			_thorn_lanes()
			_sig += 1
		elif _snare_t <= 0.0 and _dist < 13.0 and is_on_floor() and _lanes_t > 2.5:
			_snare_t = SNARE_EVERY
			_snare()


## Bramble lash: in its blind half (behind it, or under it) for a second, close: the whole ring.
func _tick_lash(delta: float) -> void:
	if _face == null or _state == AIRBORNE or _state == LEAP_PREP or _dist > LASH_R - 0.4:
		_behind_t = maxf(0.0, _behind_t - delta * 2.0)
		return
	var fwd := -_face.global_basis.z
	fwd.y = 0.0
	if _dist < 1.2 or fwd.normalized().dot(_to / maxf(_dist, 0.001)) < -0.1:
		_behind_t += delta
	else:
		_behind_t = maxf(0.0, _behind_t - delta)
	if _behind_t >= 1.0 and _lash_cd <= 0.0:
		_behind_t = 0.0
		_lash_cd = 5.0
		if _rig and _rig.has_method("telegraph"):
			_rig.call("telegraph", 0.85)
		_glint = 1.0
		Sfx.play_stream(Synth.voice(voice_family(), "tell"), global_position + Vector3.UP, 1.0, _voice_pitch())
		BossKit.cast(self, "Bramble Lash", 0.85)
		BossKit.zone(get_parent(), global_position, 0.85, 24.0, {"by": self, "radius": LASH_R, "spikes": "thorn"})


## The snare: a ring of thorn round you, its gap toward the Warden; then it pounces into the middle.
func _snare() -> void:
	var c := _p.global_position
	var toward := global_position - c
	toward.y = 0.0
	var gap_a := atan2(toward.z, toward.x)
	if _rig and _rig.has_method("howl"):
		_rig.call("howl", 1.0)
	BossKit.cast(self, "Briar Snare", 1.25)
	Sfx.play_stream(Synth.voice(voice_family(), "call"), global_position + Vector3.UP * 2.0, 2.0, 0.6)
	var n := 14
	for i in n:
		var a := gap_a + TAU * float(i) / float(n)
		if absf(wrapf(a - gap_a, -PI, PI)) < 0.5:
			continue                            # the way out: toward it
		var at := c + Vector3(cos(a), 0.0, sin(a)) * SNARE_R
		BossKit.zone(get_parent(), at, 1.25, 22.0, {"by": self, "radius": 1.0, "spikes": "thorn"})
	Vfx.arc(global_position + Vector3.UP * hp_bar_y * 0.5, c + Vector3.UP * 0.4, BossKit.THORN, 0.35, 0.4)
	# the pounce follows the closing ring (Leaper's LEAP_PREP: its own red disc under you)
	var eid := get_instance_id()
	get_tree().create_timer(0.75, false).timeout.connect(func() -> void:
		var me := instance_from_id(eid) as Thornwarden
		if me != null and me.is_alive() and me._ward_t <= 0.0 and me.is_on_floor() and (me._state == CHASE or me._state == RECOVER or me._state == IDLE):
			me._leap_cd = 0.0
			me._set_state(LEAP_PREP))


## The heart-knot found while it rears to drive the lanes (or drinks for the mending): the cast breaks.
func _on_weak_hit(_dmg: float) -> void:
	if _knot_t <= 0.0:
		return
	_knot_t = 0.0
	weak_open = false
	if not interrupt(null):
		_torn("the knot tears")


## r33: Thornlash Volley or Sap Mending broken (the knot, or a heavy blow).
func _on_cast_interrupted(n: String) -> void:
	if n == "Thornlash Volley":
		_torn("the knot tears")
	elif n == "Sap Mending":
		_torn("the mending tears")


func _torn(line: String) -> void:
	_knot_t = 0.0
	weak_open = false
	cancel_moves()
	_stagger_cd = 0.0
	stagger()
	_broken_t = BOSS_BROKEN
	HitText.pop(global_position + Vector3.UP * (hp_bar_y + 1.0), line, WEAK_COL, true)
	Vfx.burst(global_position + Vector3.UP * hp_bar_y * 0.5, BossKit.THORN, {"count": 40, "life": 0.6, "speed": Vector2(2.0, 6.0), "size": 0.06, "gravity": -6.0})


## Sap Mending: rooted, it drinks from the henge; the knot burns open. Unbroken, it heals MEND.
func _sap_mending() -> void:
	_set_state(RECOVER)
	_state_t = -MEND_TIME
	_knot_t = MEND_TIME
	_glint = 1.0
	if _rig and _rig.has_method("howl"):
		_rig.call("howl", MEND_TIME)
	BossKit.cast(self, "Sap Mending", MEND_TIME, true, _mended)
	Events.toast.emit("The Thornwarden drinks from the henge. Break it before it mends.")
	SpellFx.shell(global_position + Vector3.UP * hp_bar_y * 0.5, hp_bar_y * 0.35, hp_bar_y * 0.6, Color(0.9, 1.4, 0.3), MEND_TIME)
	Vfx.ring(global_position + Vector3.UP * 0.1, 3.0, Color(1.2, 1.8, 0.4), MEND_TIME, 0.08, Vector3.UP, 1.0)
	Sfx.play_stream(Synth.get_stream("chant"), global_position + Vector3.UP * 2.0, 0.0, 0.5)


func _mended() -> void:
	_knot_t = 0.0
	var gain := float(max_hp) * MEND
	hp = minf(float(max_hp), hp + gain)
	_refresh_hp(false)
	HitText.pop(global_position + Vector3.UP * (hp_bar_y + 1.0), "+%d mended" % roundi(gain), Color(1.0, 1.6, 0.5), true)
	Vfx.burst(global_position + Vector3.UP * hp_bar_y * 0.5, Color(1.2, 1.8, 0.4), {"count": 40, "life": 0.8, "speed": Vector2(1.0, 4.0), "size": 0.06, "gravity": -2.0})


## Call of the Stones: two Briarlings out of the stones (four of its adds at most).
func _call_stones() -> void:
	var adds := BossKit.add_wave(self, Crawler, global_position, 2, 4, "Briarling", 4.0)
	if not adds.is_empty():
		HitText.pop(global_position + Vector3.UP * (hp_bar_y + 1.0), "the stones bleed", BossKit.THORN)


func _on_state(next: int) -> void:
	super._on_state(next)
	if next == LEAP_PREP:
		begin_cast("Bramble Pounce", leap_prep, false)     # r33: bound to the crouch


## Three lanes of thorns from its feet, fanned 28 degrees apart, aimed through the player.
func _thorn_lanes() -> void:
	var to := _p.global_position - global_position
	to.y = 0.0
	if to.length() < 0.5:
		return
	var yaw := atan2(-to.x, -to.z)
	_face_dir = to.normalized()
	if _rig and _rig.has_method("telegraph"):
		_rig.call("telegraph", 0.9)
	_knot_t = 0.95                              # the knot opens for the lanes' windup
	BossKit.cast(self, "Thornlash Volley", 1.0, true)
	for k in 3:
		var a := yaw + deg_to_rad(28.0) * float(k - 1)
		BossKit.zone(get_parent(), global_position, 1.0, 26.0, {"by": self, "rect": Vector2(0.9, 7.0), "yaw": a, "spikes": "thorn"})
