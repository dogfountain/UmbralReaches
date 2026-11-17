class_name Thornwarden
extends Leaper
## Boss of the Thorn Henge: a leaper of bark and thorn, antlered with briar, at raid scale (r34: 2.6x,
## in a 62 m room -- core/world/henge_raid.gd). docs/r34/raids_overworld.md has the whole fight.
##
## Phase I    "The Keeper" (100-70 %)
##   Bramble Pounce    long pounces; the landing disc fills for exactly the flight.
##   Thornlash Volley  (interruptible: the heart-knot at its breast, or a heavy blow) five lanes.
##   Bramble Lash      in its blind half for a second: a ring of thorns round its body (positional).
##   Briar Snare       a ring round you, open toward it, then it pounces into the middle.
##   Thornstorm        (3.2 s, cannot be broken) it flings the henge's thorns out over the whole floor:
##                     only what stands behind a great stone (or a grown wall) is spared. Line of sight.
## Intermission "Heart of the Henge" (at 70 %)
##   It roots into the altar (immune). Three heart-knots grow out of the outer ring and the bramble
##   maze erupts in three stages while you burn them; Root Eruption opens under you every few seconds;
##   Briarlings crawl out of the knots. All knots burned: it tears itself up, reeling. Not in time
##   (KNOT_TIME): "The Henge Closes" -- each knot left heals it and hurts you.
## Phase II   "The Overgrowth" (70-35 %), in the maze
##   Sap Mending       (interruptible) it drinks from the henge; unbroken, it heals MEND.
##   Call of the Stones  two Briarlings and a Thornspeaker: while a speaker lives the Warden takes half
##                     damage (kill it first). The volley, snare, lash, pounce and Thornstorm go on.
## Phase III  "The Last Bloom" (35-0 %), the burn
##   the maze withers; the closing briars shrink the floor every 14 s; Bloom of Thorns: three rings of
##   thorn burst outward from it one after another (stand between them); everything comes faster.

const SLAM_R := 3.2
const SLAM_R2 := 5.0
const LANES_EVERY := 7.0
const SCALE := 3.8              ## 2.6 -> 3.8 (about 6.4 m, 9 m across): the smallest thing in his own arena no more

var phase := 1
var rooted := false             ## the intermission: rooted in the altar, immune
var _sig := 0                   ## signature moves shown this phase (pounces in I, volleys in II, blooms in III)
var _land_at := Vector3.INF
var _slam_locked := false
var _lanes_t := 4.0
var _behind_t := 0.0
var _lash_cd := 3.0
var _snare_t := 9.0
var _knot_t := 0.0              ## seconds the heart-knot stays open (the lanes' windup)
const LASH_R := 4.6
const SNARE_R := 4.4
const SNARE_EVERY := 13.0
const MEND_EVERY := 26.0
const MEND_TIME := 3.0
const MEND := 0.06              ## of max health, if the mending is not broken
const WAVE_EVERY := 32.0
const STORM_EVERY := 34.0
const STORM_TIME := 3.2
const STORM_GLOOM := 48.0
const KNOT_TIME := 55.0         ## seconds to burn the knots before the henge closes
const ERUPT_EVERY := 5.5
const BLOOM_EVERY := 15.0
const HP := 600
const BeastRig := preload("res://core/enemy/beast_rig.gd")
const ThornBody := preload("res://core/enemy/thorn_body.gd")
const QuestBook := preload("res://core/story/quest_book.gd")
var _attuned := false
var _mend_t := 8.0
var _wave_t := 12.0
var _storm_t := 22.0
var _root_t := 0.0              ## seconds into the intermission
var _erupt_t := 3.0
var _brood_t := 10.0
var _bloom_t := 6.0
var _stage := 0
var _speak_t := 0.0
var _room: Node = null
var _arena_c := Vector3.INF


func _init() -> void:
	super._init()
	body_kind = &"thornwarden"
	max_hp = HP                 # r34 raids: 600 (r30: 110) for a 4-6 minute fight with an intermission
	hp = float(HP)
	walk_speed = 5.0
	strike_gloom = 38.0
	leap_max = 20.0
	leap_apex = 3.0
	leap_cooldown = 1.8
	leap_prep = 0.7
	weak_socket = "front"
	weak_offset = Vector3(0.0, 0.05, -0.2)
	weak_r = 0.12
	weak_open = false


func phase_marks() -> Array[float]:
	return [0.7, 0.35]


func on_engaged(arena: Node) -> void:
	BossKit.intro(self, BossKit.THORN, 2.4)
	_room = arena.get("room") as Node if arena != null else null
	if arena is Node3D:
		_arena_c = (arena as Node3D).global_position
	# r34 merge: attunement (Ruan's ward-stones): its Thornspeakers' song only takes a quarter off your blows
	_attuned = QuestBook.attuned("thornwarden")
	# r35: world cues, not text: one short line a mechanic, no instructions (the arena shows what to do)
	if _attuned:
		BossKit.emote(self, "The ward-stones hold. Its song is weak.")


func _absorb(dmg: float, from: Node) -> float:
	if rooted:
		BossKit.warded_hit(self, "burn the heart-knots", Color(0.9, 1.0, 0.5), from)
		return 0.0
	if speakers() > 0:
		dmg *= 0.75 if _attuned else 0.5       # its Thornspeakers' song: kill them first
		var now2 := Time.get_ticks_msec()
		if now2 - int(get_meta(&"speak_pop", 0)) > 700:
			set_meta(&"speak_pop", now2)
			HitText.pop(global_position + Vector3.UP * (hp_bar_y + 0.6), "the song is thin" if _attuned else "shrouded", Color(0.75, 1.0, 0.45))
	return BossKit.absorb(self, dmg, from, BossKit.phase_floor(self, phase, phase_marks(), _sig))


func _build() -> void:
	name = "Thornwarden"
	# (17 Nov, Luke: bosses "simple like the villager", "4/5x size") built in the villagers' style to its own design
	# (core/enemy/thorn_body.gd): a great stag-wolf of bark and thorn, briar antlers, a glowing heart-knot at its breast;
	# posed by formula on a beast's skeleton (core/enemy/beast_rig.gd). The Blender model and its clips stay in art/.
	var _r: CharacterRig = BeastRig.fit(self, ThornBody, {"scale": 1.25, "walk_stride": 0.9, "run_stride": 1.9, "run_at": 0.95})
	var col := get_node_or_null("Collision") as CollisionShape3D
	if col and col.shape is CapsuleShape3D:
		var cap := col.shape as CapsuleShape3D
		cap.height = 1.1
		cap.radius = 0.42
		col.position.y = 0.6
	BossKit.embiggen(self, SCALE)


## Living Thornspeakers (its priority adds).
func speakers() -> int:
	if not is_inside_tree():
		return 0
	var n := 0
	var bid := String(get_meta(&"boss_id", ""))
	for e in get_tree().get_nodes_in_group(Groups.ENEMY):
		if e != self and e is Enemy and (e as Enemy).is_alive() and String((e as Node).get_meta(&"display_name", "")) == "Thornspeaker" and String((e as Node).get_meta(&"summoned_by", "")) == bid:
			n += 1
	return n


func _pounce(player: Player) -> void:
	super._pounce(player)
	_slam_locked = false
	if phase == 1:
		_sig += 1


## The slam's circle is read at the crouch and the jump comes down on it (the red is the truth).
func _leap_target(player: Player) -> Vector3:
	return _land_at if _slam_locked else super._leap_target(player)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _state == DEAD:
		return
	if rooted:
		_tick_rooted(delta)
		return
	if phase == 1 and hp <= float(max_hp) * 0.7:
		phase = 2
		_sig = 0
		if _room != null and _room.has_method("spawn_knots"):
			_begin_rooting()
			return
		BossKit.transition(self, "Keeper, keep. The thorns wake, and the stones bleed.", BossKit.THORN)
		_lanes_t = 2.0
	elif phase == 2 and hp <= float(max_hp) * 0.35:
		phase = 3
		_sig = 0
		_begin_bloom()
	_knot_t = maxf(0.0, _knot_t - delta)
	weak_open = _knot_t > 0.0
	if _speak_t > 0.0:
		_speak_t -= delta
	elif speakers() > 0:
		_speak_t = 1.2
		for e in get_tree().get_nodes_in_group(Groups.ENEMY):
			if String((e as Node).get_meta(&"display_name", "")) == "Thornspeaker" and (e as Enemy).is_alive():
				Vfx.arc((e as Node3D).global_position + Vector3.UP * 1.6, global_position + Vector3.UP * hp_bar_y * 0.6, Color(0.75, 1.9, 0.45), 0.3, 0.3)
	if _ward_t > 0.0 or _p == null:
		return                                  # shelled (intro, between phases): nothing new starts
	_lash_cd = maxf(0.0, _lash_cd - delta)
	_tick_lash(delta)
	if _state == AIRBORNE or _state == LEAP_PREP:
		return
	_lanes_t -= delta
	_snare_t -= delta
	_storm_t -= delta
	if phase >= 2:
		_mend_t -= delta
		_wave_t -= delta
	if phase >= 3:
		_bloom_t -= delta
	if casting() and cast_name in ["Sap Mending", "Thornstorm"]:
		_state_t = minf(_state_t, 0.0)           # rooted while it drinks or gathers the storm
		velocity.x = 0.0
		velocity.z = 0.0
		return
	if casting():
		return
	if phase == 2 and _mend_t <= 0.0 and hp < float(max_hp) * 0.6 and is_on_floor():
		_mend_t = MEND_EVERY
		_lanes_t = maxf(_lanes_t, MEND_TIME + 1.0)
		_snare_t = maxf(_snare_t, MEND_TIME + 2.0)
		_sap_mending()
	elif phase == 2 and _wave_t <= 0.0:
		_wave_t = WAVE_EVERY
		BossKit.cast(self, "Call of the Stones", 1.6, false, _call_stones)
		BossKit.emote(self, "A Thornspeaker answers. The song is weak: your blows land at three quarters." if _attuned else "A Thornspeaker answers. Its song is up: your blows are halved.")
		if _rig and _rig.has_method("howl"):
			_rig.call("howl", 1.4)
	elif phase <= 2 and _storm_t <= 0.0 and is_on_floor():
		_storm_t = STORM_EVERY - (4.0 if phase == 2 else 0.0)
		_lanes_t = maxf(_lanes_t, STORM_TIME + 1.5)
		_snare_t = maxf(_snare_t, STORM_TIME + 2.5)
		_thornstorm()
	elif phase >= 3 and _bloom_t <= 0.0 and is_on_floor():
		_bloom_t = BLOOM_EVERY
		_lanes_t = maxf(_lanes_t, 3.0)
		_bloom()
	elif _lanes_t <= 0.0:
		_lanes_t = LANES_EVERY - (1.5 if phase >= 3 else 0.0)
		_thorn_lanes()
		if phase == 2:
			_sig += 1
	elif _snare_t <= 0.0 and _dist < 15.0 and is_on_floor() and _lanes_t > 2.5:
		_snare_t = SNARE_EVERY - (3.0 if phase >= 3 else 0.0)
		_snare()


## Bramble lash: in its blind half (behind it, or under it) for a second, close: the whole ring.
func _tick_lash(delta: float) -> void:
	if _face == null or _state == AIRBORNE or _state == LEAP_PREP or _dist > LASH_R - 0.4:
		_behind_t = maxf(0.0, _behind_t - delta * 2.0)
		return
	var fwd := -_face.global_basis.z
	fwd.y = 0.0
	if _dist < 1.6 or fwd.normalized().dot(_to / maxf(_dist, 0.001)) < -0.1:
		_behind_t += delta
	else:
		_behind_t = maxf(0.0, _behind_t - delta)
	if _behind_t >= 1.0 and _lash_cd <= 0.0:
		_behind_t = 0.0
		_lash_cd = 5.0
		if _rig and _rig.has_method("telegraph"):
			_rig.call("telegraph", 1.0)
		_glint = 1.0
		say("windup", global_position + Vector3.UP, 1.0, _voice_pitch())
		BossKit.cast(self, "Bramble Lash", 1.0)
		BossKit.zone(get_parent(), global_position, 1.0, 24.0, {"by": self, "radius": LASH_R, "spikes": "thorn"})


## The snare: a ring of thorn round you, its gap toward the Warden; then it pounces into the middle.
func _snare() -> void:
	var c := _p.global_position
	var toward := global_position - c
	toward.y = 0.0
	var gap_a := atan2(toward.z, toward.x)
	if _rig and _rig.has_method("howl"):
		_rig.call("howl", 1.0)
	BossKit.cast(self, "Briar Snare", 1.3)
	say("alert", global_position + Vector3.UP * 2.0, 2.0, 0.6)
	var n := 16
	for i in n:
		var a := gap_a + TAU * float(i) / float(n)
		if absf(wrapf(a - gap_a, -PI, PI)) < 0.5:
			continue                            # the way out: toward it
		var at := c + Vector3(cos(a), 0.0, sin(a)) * SNARE_R
		BossKit.zone(get_parent(), at, 1.3, 22.0, {"by": self, "radius": 1.05, "spikes": "thorn"})
	Vfx.arc(global_position + Vector3.UP * hp_bar_y * 0.5, c + Vector3.UP * 0.4, BossKit.THORN, 0.35, 0.4)
	var eid := get_instance_id()
	get_tree().create_timer(0.8, false).timeout.connect(func() -> void:
		var me := instance_from_id(eid) as Thornwarden
		if me != null and me.is_alive() and me._ward_t <= 0.0 and not me.rooted and me.is_on_floor() and (me._state == CHASE or me._state == RECOVER or me._state == IDLE):
			me._leap_cd = 0.0
			me._set_state(LEAP_PREP))


## Thornstorm: the whole floor is in the storm; only what a stone or a wall shields is spared.
func _thornstorm() -> void:
	_set_state(RECOVER)
	_state_t = -STORM_TIME
	velocity = Vector3.ZERO
	_glint = 1.0
	if _rig and _rig.has_method("howl"):
		_rig.call("howl", STORM_TIME)
	BossKit.cast(self, "Thornstorm", STORM_TIME, false, _storm_lands)
	BossKit.emote(self, "Every thorn in the henge rises.", Color(1.0, 0.55, 0.3))
	# the lee of every standing stone lights up for the storm's whole gathering
	if _room != null and "stones" in _room:
		var shields: Array = []
		for st: Variant in _room.get("stones"):
			if st is Node3D and is_instance_valid(st):
				shields.append((st as Node3D).global_position)
		BossKit.lee_marks(global_position, shields, STORM_TIME, Color(1.0, 1.7, 0.8))
	var c: Vector3 = _arena_c if _arena_c != Vector3.INF else global_position
	var r := 30.0 if _arena_c != Vector3.INF else 20.0
	var cone := SpellFx.danger(c, STORM_TIME, {"radius": r, "color": BossKit.THORN})
	if cone:
		track_move(cone)
	Vfx.ring(global_position + Vector3.UP * 0.2, 6.0, BossKit.THORN, STORM_TIME, 0.12, Vector3.UP, 1.3)
	Sfx.play_stream(Synth.get_stream("chant"), global_position + Vector3.UP * 2.0, 2.0, 0.4)


func _storm_lands() -> void:
	if not is_alive() or rooted:
		return
	var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Player
	var from := global_position + Vector3.UP * hp_bar_y * 0.5
	for k in 12:
		var a := TAU * float(k) / 12.0
		Vfx.burst(from, Color(0.22, 0.12, 0.08), {"count": 26, "life": 1.0, "speed": Vector2(14.0, 26.0), "size": 0.09, "gravity": -2.0, "dir": Vector3(cos(a), 0.15, sin(a)), "spread": 12.0, "additive": false, "trail": 0.12})
	Sfx.play_stream(Synth.get_stream("spike"), from, 3.0, 0.5)
	if p == null:
		return
	var safe := false
	if _room != null and _room.has_method("shelter"):
		safe = bool(_room.call("shelter", global_position + Vector3.UP * 1.0, p.global_position))
	var d := p.global_position - global_position
	if Vector2(d.x, d.z).length() > 34.0:
		safe = true
	if safe:
		HitText.pop(p.global_position + Vector3.UP * 2.2, "sheltered", Color(0.75, 0.9, 1.0))
	elif p.is_evading():
		p.on_evaded(self)
	else:
		p.take_wound(STORM_GLOOM * dmg_mult, global_position)


## The heart-knot found while it rears to drive the lanes (or drinks for the mending): the cast breaks.
func _on_weak_hit(_dmg: float) -> void:
	if _knot_t <= 0.0:
		return
	_knot_t = 0.0
	weak_open = false
	if not interrupt(null):
		_torn("the knot tears")


## Thornlash Volley or Sap Mending broken (the knot, or a heavy blow).
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
	BossKit.emote(self, "The Thornwarden drinks from the henge.", Color(0.85, 1.0, 0.45))
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


## Call of the Stones: two Briarlings and a Thornspeaker out of the stones (five of its adds at most).
func _call_stones() -> void:
	var adds := BossKit.add_wave(self, Crawler, global_position, 2, 5, "Briarling", 4.5)
	var sp_at := global_position
	if _arena_c != Vector3.INF:
		var away := (global_position - _arena_c)
		away.y = 0.0
		sp_at = _arena_c - (away.normalized() if away.length() > 0.5 else Vector3.FORWARD) * 14.0
	var sp := BossKit.add_wave(self, preload("res://core/enemy/chanter.gd"), sp_at, 1, 5, "Thornspeaker", 1.5)
	for s in sp:
		SpellFx.column(s.global_position, 0.8, 4.0, 0.6)
	if not adds.is_empty() or not sp.is_empty():
		HitText.pop(global_position + Vector3.UP * (hp_bar_y + 1.0), "the stones bleed", BossKit.THORN)


func _on_state(next: int) -> void:
	super._on_state(next)
	if next == LEAP_PREP:
		begin_cast("Bramble Pounce", leap_prep, false)     # bound to the crouch
		if is_instance_valid(_danger):
			_danger.queue_free()                           # the slam's own circle replaces the small disc
		if _p != null:
			_slam_locked = false
			_land_at = _leap_target(_p)
			_slam_locked = true
			var t := flight_time(leap_apex, _land_at.y - global_position.y)
			BossKit.zone(get_parent(), _land_at, leap_prep + maxf(t, 0.3), 30.0 if phase >= 2 else 22.0,
				{"by": self, "radius": SLAM_R2 if phase >= 2 else SLAM_R, "spikes": "thorn" if phase >= 2 else ""})


## Thornlash Volley: five lanes of thorns from its feet, fanned 22 degrees apart, aimed through you.
func _thorn_lanes() -> void:
	var to := _p.global_position - global_position
	to.y = 0.0
	if to.length() < 0.5:
		return
	var yaw := atan2(-to.x, -to.z)
	_face_dir = to.normalized()
	if _rig and _rig.has_method("telegraph"):
		_rig.call("telegraph", 1.0)
	_knot_t = 1.05                              # the knot opens for the lanes' windup
	BossKit.cast(self, "Thornlash Volley", 1.1, true)
	var n := 5 if phase >= 2 else 3
	for k in n:
		var a := yaw + deg_to_rad(22.0) * (float(k) - float(n - 1) * 0.5)
		BossKit.zone(get_parent(), global_position, 1.1, 26.0, {"by": self, "rect": Vector2(1.0, 8.5), "yaw": a, "spikes": "thorn"})


# --- the intermission: Heart of the Henge ---------------------------------------------------------

func _begin_rooting() -> void:
	rooted = true
	_root_t = 0.0
	_stage = 0
	_erupt_t = 4.0
	_brood_t = 12.0
	_finish_cast(true, false)
	cancel_moves()
	_combo_left = 0
	_knot_t = 0.0
	weak_open = false
	set_meta(&"phase_label", "HEART OF THE HENGE")
	set_meta(&"ward_hint", "burn the heart-knots")
	var c: Vector3 = _arena_c if _arena_c != Vector3.INF else global_position
	SpellFx.rift_in(global_position)
	var to := c + (global_position - c).normalized() * 3.2 if global_position.distance_to(c) > 1.0 else c + Vector3(3.2, 0, 0)
	to.y = global_position.y
	global_position = to
	velocity = Vector3.ZERO
	reset_physics_interpolation()
	SpellFx.rift_in(to)
	_set_state(RECOVER)
	_state_t = -1.0
	if _rig and _rig.has_method("howl"):
		_rig.call("howl", 2.0)
	BossKit.roar(self, "", BossKit.THORN)
	BossKit.emote(self, "It roots into the henge's heart.", Color(0.9, 1.0, 0.45))
	_room.call("set_mood", "rooted")
	_room.call("spawn_knots", self)
	_room.call("grow_stage", 1, self)
	_stage = 1


func _tick_rooted(delta: float) -> void:
	_state_t = -1.0
	velocity.x = 0.0
	velocity.z = 0.0
	_root_t += delta
	if _room == null or not is_instance_valid(_room):
		_end_rooting(0)
		return
	if _stage == 1 and _root_t >= 12.0:
		_stage = 2
		_room.call("grow_stage", 2, self)
		BossKit.emote(self, "The brambles grow.", Color(1.0, 0.6, 0.35))
	elif _stage == 2 and _root_t >= 24.0:
		_stage = 3
		_room.call("grow_stage", 3, self)
		BossKit.emote(self, "The brambles close about the knots.", Color(1.0, 0.6, 0.35))
	var left := int(_room.call("knots_left"))
	if left == 0:
		_end_rooting(0)
		return
	if _root_t >= KNOT_TIME:
		_end_rooting(left)
		return
	if _root_t >= KNOT_TIME - 10.0 and _root_t - delta < KNOT_TIME - 10.0:
		BossKit.emote(self, "The henge is closing. %d heart-knot%s still beat%s." % [left, "" if left == 1 else "s", "s" if left == 1 else ""], Color(1.0, 0.45, 0.3))
	_erupt_t -= delta
	if _erupt_t <= 0.0 and _p != null:
		_erupt_t = ERUPT_EVERY
		BossKit.cast(self, "Root Eruption", 1.4)
		BossKit.zone(get_parent(), _p.global_position, 1.4, 20.0, {"by": self, "radius": 3.0, "spikes": "thorn"})
	_brood_t -= delta
	if _brood_t <= 0.0:
		_brood_t = 14.0
		for kn: Node in _room.get("knots"):
			if is_instance_valid(kn) and bool(kn.call("is_alive")):
				BossKit.add_wave(self, Crawler, (kn as Node3D).global_position, 1, 4, "Briarling", 2.0)


## Out of the altar: all knots burned (`left` 0), or the henge closed on the ones still beating.
func _end_rooting(left: int) -> void:
	rooted = false
	set_meta(&"phase_label", "")
	remove_meta(&"ward_hint")
	_finish_cast(true, false)
	if left > 0:
		var gain := float(max_hp) * 0.05 * float(left)
		hp = minf(float(max_hp), hp + gain)
		_refresh_hp(false)
		HitText.pop(global_position + Vector3.UP * (hp_bar_y + 1.0), "+%d the henge closes" % roundi(gain), Color(1.0, 1.6, 0.5), true)
		var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		if p:
			p.take_wound(16.0 * float(left), global_position)
			HitText.pop(p.global_position + Vector3.UP * 2.4, "%d on the plate" % (16 * left), Color(1.0, 0.45, 0.3), true)
		for kn: Node in _room.get("knots") if _room != null else []:
			if is_instance_valid(kn):
				kn.queue_free()
		BossKit.emote(self, "The henge closes on the knots you left.", Color(1.0, 0.45, 0.3))
	else:
		BossKit.emote(self, "The last knot bursts. It tears free, reeling.", Color(1.0, 0.75, 0.4))
	if _room != null and is_instance_valid(_room):
		_room.call("wither_stage", 3)
		_room.call("set_mood", "fight")
	BossKit.transition(self, "Keeper, keep. The maze is yours now.", BossKit.THORN, 1.6)
	if left == 0:
		_broken_t = BOSS_BROKEN * 2.0           # a reward: it reels open for a while
	_lanes_t = 3.0
	_wave_t = 4.0
	_storm_t = 18.0
	_mend_t = 10.0


# --- phase III: the Last Bloom ---------------------------------------------------------------------

func _begin_bloom() -> void:
	BossKit.transition(self, "", BossKit.RAGE, 1.6)
	BossKit.emote(self, "It bleeds into bloom. The briars close.", Color(1.0, 0.4, 0.3))
	leap_cooldown = 1.3
	walk_speed = 5.8
	if _room != null and is_instance_valid(_room):
		_room.call("wither_stage", 1)
		_room.call("wither_stage", 2)
		_room.call("wither_stage", 3)
		_room.call("set_mood", "bloom")
		_room.call("start_briars")
	_bloom_t = 5.0
	_lanes_t = 3.5
	_snare_t = 8.0


## Bloom of Thorns: three rings burst out from it one after another; stand between them.
func _bloom() -> void:
	var c := global_position
	_set_state(RECOVER)
	_state_t = -1.2
	velocity = Vector3.ZERO
	_glint = 1.0
	if _rig and _rig.has_method("howl"):
		_rig.call("howl", 1.2)
	BossKit.cast(self, "Bloom of Thorns", 1.4)
	BossKit.emote(self, "Bloom of Thorns.", Color(1.0, 0.5, 0.35))
	var rings := [[1.4, 2.5, 5.0], [2.2, 8.5, 11.0], [3.0, 14.5, 17.0]]
	for rg: Array in rings:
		BossKit.zone(get_parent(), c, float(rg[0]), 24.0, {"by": self, "radius": float(rg[2]), "holes": [[c, float(rg[1])]], "color": BossKit.THORN, "h": 2.5})
	_sig += 1


func voice_family() -> String:
	return "thorn"


func _hit_sound() -> String:
	return "wood"
