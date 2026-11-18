class_name AscendedWarden
extends Husk
## Boss of the summit: a towering hollowed priest that floats in a bell robe, a white-gold mask and a
## mandorla of light behind its head, at raid scale (r35: 5x, about 9 m, on a 56 m deck over the chasm --
## core/world/summit_raid.gd). docs/r34/raids_overworld.md has the whole fight.
##
## Phase I    "The Hierarch's Judgement" (100-65 %)
##   Rift Step       it blinks to another point of the deck (rift-out, rift-in).
##   Radiant Fan     (interruptible: the halo behind its head, or a heavy blow) a cone fills, seven orbs.
##   Judgement       two lanes of light crossing at you.
##   Mandorla Flare  the deck burns from FLARE_IN to FLARE_R round it: only under it is safe.
## Intermission "The Ascension" (at 65 %)
##   It rises over the deck (immune) and the four pylons go out. The sky falls: stars strike at random
##   and on you, never inside a lit pylon's ring. Stand in each dark pylon's ring to rekindle it; two
##   Gilded Acolytes come out of the light. All four lit: it falls back to the deck, reeling. Not in time
##   (ASCEND_TIME): "The Sky Breaks" -- a blow that only a lit ring shelters you from.
## Phase II   "The Door Opened" (65-30 %)
##   Gale of the Door  (1.6 s cast, then 5 s) a wind from it that drives you toward the broken edges;
##                   lean into it, or shelter behind a lit pylon. The fall is the price.
##   Eclipse         the deck fills dark-gold; only the lit pylons' rings are spared, and the ring you
##                   stood in is spent (rekindle it: RELIGHT s in its ring).
##   Call the Acolytes  (interruptible) two Gilded Acolytes; arrival rings on every blink; the rest go on.
## Phase III  "Aurel, Hierarch" (30-0 %), the burn
##   he lets go of the door: every pylon blazes again, the halo breaks open: blinks every 2.6 s, double
##   fans, the falling sky on you, eclipses and flares. (r35: no soft enrage.)

const VillagerBossRig := preload("res://core/enemy/villager_boss_rig.gd")
const ClipRig := preload("res://core/enemy/clip_rig.gd")
const WardenBody := preload("res://core/enemy/warden_body.gd")
const FAN_WINDUP := 0.85
const HP := 760
const QuestBook := preload("res://core/story/quest_book.gd")
var _attuned := false
const WardenPeal := preload("res://core/enemy/warden_peal.gd")
const AurelLines := preload("res://core/story/aurel_lines.gd")
const BELL_HOLD := 0.05
const BELL_WORDS := ["", "one bell", "two bells", "three bells", "four bells", "five bells", "six bells", "seven bells", "eight bells"]
const SCALE := 5.0               ## r35: 3 -> 5 (~9 m): the final boss towers over the 56 m deck, "halfway into the sky"

var phase := 1
var ascended := false           ## the intermission: risen over the deck, immune
var _sig := 0                   ## signature moves this phase (I: fans, II: judgements, III: double fans)
var anchors: Array[Vector3] = []
var _blink_t := 5.0
var _fan_t := 99.0
var _fan_cone: MeshInstance3D
var _fan_yaw := 0.0
var _fans_left := 0
var _judge_t := 4.0
var _eclipse_t := 16.0
var _arena_c := Vector3.INF
var _arena_r := 10.0
const ECLIPSE_EVERY := 24.0
const ECLIPSE_FILL := 2.8
const POOL_R := 2.3
const FLARE_EVERY := 19.0
const FLARE_TIME := 2.0
const FLARE_IN := 3.6
const FLARE_R := 16.0
const ACOLYTES_EVERY := 34.0
const GALE_EVERY := 28.0
const GALE_CAST := 1.6
const GALE_TIME := 5.0
const GALE_SPEED := 3.0
const ASCEND_TIME := 60.0
const ASCEND_H := 15.0           ## r35: 10 -> 15 with the 5x scale, so the risen Warden still clears the deck
const SKY_GLOOM := 55.0
const ACOLYTE := preload("res://core/enemy/chanter.gd")
var _flare_t := 14.0
var _acolytes_t := 10.0
var _gale_t := 12.0
var _gale_left := 0.0
var _gale_fx := 0.0
var _lee_said := false       ## "sheltered" is said once on entering the lee
var _star_t := 2.0
var _star_p_t := 3.0
var _asc_t := 0.0
var _asc_from := Vector3.ZERO
var _room: Node = null
var _grav := 16.0


func _init() -> void:
	super._init()
	body_kind = &"ascended_warden"
	max_hp = HP                 # r34 raids: 760 (r30: 220) for a 5-7 minute fight with an intermission
	hp = float(HP)
	walk_speed = 2.4
	strike_gloom = 42.0
	weak_socket = "head"                        # the halo, behind the mask
	weak_offset = Vector3(0.0, 0.14, 0.22)
	weak_r = 0.12
	weak_open = false


func phase_marks() -> Array[float]:
	return [0.65, 0.3]


func _build() -> void:
	# (17 Nov, Luke: bosses "simple like the villager", "4/5x size") built in the villagers' style to its own design
	# (core/enemy/warden_body.gd): a floating priest in an ivory bell robe, a gold mask, a mandorla of rays; posed by
	# formula (core/enemy/villager_boss_rig.gd). The Blender model and its clips stay in art/ for the record.
	# (18 Nov, Luke: "all models in the game should be blender") modelled and animated in Blender
	# (tools/blender/vb_ascended_warden.py): floating in an ivory bell robe with the light of the door pouring from its
	# hem, a gold mask under an ivory hood, a mandorla with rays swept out like wings and a sun-disc at its heart (the
	# weak point), long lined sleeves, the key of the door at its hip; a move of its own for each rite. The code-built
	# body above stays as the fallback.
	var model: String = BossKit.AUTHORED.get(&"ascended_warden", "")
	var authored := model != "" and ResourceLoader.exists(model)
	if authored:
		ClipRig.fit(self, model, &"ascended_warden", {"body": "spine", "front": "chest", "muzzle": "head", "halo": "halo"},
				{"walk_stride": 2.0, "villager_look": true, "cap": 0.86})
		_rig.scale = Vector3.ONE * 0.92             # 2.3 m to the halo's top in body units: about 10 m at SCALE
		weak_socket = "halo"                        # the sun-disc at the mandorla's heart
		weak_offset = Vector3(0.0, 0.1, 0.03)
	else:
		VillagerBossRig.fit(self, WardenBody, {}, {"hover": 0.22, "scale": 0.57, "cap": 0.86, "stoop": 0.0})
	name = "AscendedWarden"
	BossKit.embiggen(self, SCALE)
	posture({"hunch": 0.05, "crouch": 0.0, "arm_reach": 0.1, "head_jut": 0.1, "limp": 0.0, "sway": 0.4, "twitch": 0.0, "splay": 0.15, "hover": 1.0})
	# its halo lights the deck round it
	var head := (_rig.socket("halo") if authored else _rig.socket("head")) if _rig else null
	if head:
		var l := OmniLight3D.new()
		l.name = "Halo"
		l.light_color = Color(1.0, 0.9, 0.7)
		l.light_energy = 3.0                    # r35: a halo for a 9 m Warden (was 2.2 / 12 m at 3x)
		l.omni_range = 20.0
		l.shadow_enabled = false
		head.add_child(l)
		l.position = weak_offset if authored else Vector3(0.0, 0.14, 0.22)


## One of its own moves when the model has it (a clip of that name, timed to the cast), else false.
func _rite(clip: StringName) -> bool:
	return _rig is ClipRig and (_rig as ClipRig).boss_move(clip, 0.0)


func _absorb(dmg: float, from: Node) -> float:
	if ascended:
		BossKit.warded_hit(self, "rekindle the pylons", Color(1.0, 0.9, 0.6), from)
		return 0.0
	return BossKit.absorb(self, dmg, from, BossKit.phase_floor(self, phase, phase_marks(), _sig))


func on_engaged(arena: Node) -> void:
	BossKit.intro(self, BossKit.HOLY, 2.4)
	_room = arena.get("room") as Node if arena != null else null
	if anchors.is_empty() and arena is Node3D:
		var c := (arena as Node3D).global_position
		_arena_c = c
		_arena_r = (arena as BossArena).radius if arena is BossArena else 11.0
		var space := (arena as Node3D).get_world_3d().direct_space_state
		# eight blink points: four near (between the pylons' lines) and four far (by the rim)
		for ring: Array in [[0.33, PI * 0.25], [0.68, 0.0]]:
			for i in 4:
				var a := TAU * float(i) / 4.0 + float(ring[1])
				var p := c + Vector3(cos(a), 0.0, sin(a)) * _arena_r * float(ring[0]) + Vector3.UP * 3.0
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p, p + Vector3.DOWN * 8.0, Layers.WORLD))
				if hit:
					anchors.append(hit.position as Vector3)
	# r34 merge: attunement (Elspeth's bell): the ascension runs 15 s longer before the sky breaks
	_attuned = QuestBook.attuned("ascended_warden")
	# r35: world cues, not text: one short line a mechanic, no instructions (the arena shows what to do)
	# r36 Act II: every bell-tongue carried to Hearthward rings at the Keg as he wakes: he holds the
	# door with that much less (5% of his life a bell, up to 40% for all eight)
	var carried := QuestBook.bells_carried()
	var rung := maxi(0, QuestBook.bells() - carried)
	var hold := WardenPeal.hold_factor(carried, rung, BELL_HOLD)
	if hold < 1.0:
		max_hp = maxi(1, roundi(float(max_hp) * hold))   # a shorter life, a full bar
		hp = float(max_hp)
	WardenPeal.scene(self, carried, rung, _attuned, BELL_WORDS)       # the answered bells ring in, one by one, then his wake line


var _aurel_spoke := false


## his last word, by the third edict's pick (aurel_voice.gd), before the fall the ending is built on.
func _die() -> void:
	if not _aurel_spoke:
		_aurel_spoke = true
		AurelLines.fight(self, "dead")
	super._die()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _state == DEAD:
		return
	if ascended:
		_tick_ascended(delta)
		return
	if phase == 1 and hp <= float(max_hp) * 0.65:
		phase = 2
		_sig = 0
		_fan_t = 99.0                           # a volley still winding up is taken back with its cone
		_fans_left = 0
		if _room != null and _room.has_method("snuff_all") and _arena_c != Vector3.INF:
			_ascend()
			return
		BossKit.transition(self, "His light turns to judgement. One hand never leaves the door.", BossKit.HOLY)
		AurelLines.fight(self, "ph2")
		_blink_t = 1.5
	elif phase == 2 and hp <= float(max_hp) * 0.3:
		phase = 3
		_sig = 0
		_fan_t = 99.0
		_fans_left = 0
		_gale_left = 0.0
		BossKit.transition(self, "He lets go of the door with one hand. What it held pours out.", BossKit.HOLY, 1.4)
		BossKit.emote(self, "Aurel lets go of the door. The sky falls.", Color(1.0, 0.9, 0.6))
		AurelLines.fight(self, "ph3")
		if _room != null and is_instance_valid(_room):
			_room.call("light_all")
			_room.call("set_mood", "hierarch")
		_blink_t = 1.25
		_star_p_t = 4.0
		_star_t = 2.0
	if _ward_t > 0.0:
		return                                  # reeling between phases: nothing new starts
	_blink_t -= delta
	_fan_t -= delta
	_track_fan()
	_judge_t -= delta
	_eclipse_t -= delta
	_flare_t -= delta
	_acolytes_t -= delta
	_gale_t -= delta
	weak_open = _fan_t > 0.0 and _fan_t <= FAN_WINDUP + 0.05
	if _gale_left > 0.0:
		_tick_gale(delta)
		return                                  # it holds the wind: no blink, no new move
	if phase >= 3 and _room != null:
		_star_t -= delta
		_star_p_t -= delta
		if _star_t <= 0.0:
			_star_t = 2.2
			_room.call("star", _random_deck_point(), self)
		if _star_p_t <= 0.0 and _p != null:
			_star_p_t = 4.0
			_room.call("star", _p.global_position, self)
	if casting():
		return
	if phase >= 2 and _fan_t > 50.0 and _p != null:
		if phase == 2 and _acolytes_t <= 0.0:
			_acolytes_t = ACOLYTES_EVERY
			_blink_t = maxf(_blink_t, 2.4)
			BossKit.cast(self, "Call the Acolytes", 2.0, true, _call_acolytes)
			BossKit.emote(self, "He calls his acolytes out of the light.", BossKit.EMOTE_COL)
			if not _rite(&"call") and _rig and _rig.has_method("howl"):
				_rig.call("howl", 2.0)
			return
		if phase == 2 and _gale_t <= 0.0 and _room != null:
			_gale_t = GALE_EVERY
			_begin_gale()
			return
		if _eclipse_t <= 0.0 and _arena_c != Vector3.INF and anchors.size() >= 2:
			_eclipse_t = ECLIPSE_EVERY - (4.0 if phase >= 3 else 0.0)
			_blink_t = maxf(_blink_t, ECLIPSE_FILL + 0.4)
			_flare_t = maxf(_flare_t, ECLIPSE_FILL + 3.0)
			_eclipse()
			return
	if _flare_t <= 0.0 and _eclipse_t > FLARE_TIME + 1.0 and _fan_t > 50.0 and _p != null:
		_flare_t = FLARE_EVERY - (3.0 if phase >= 3 else 0.0)
		_mandorla_flare()
		return
	if _blink_t <= 0.0 and not anchors.is_empty() and _state != WINDUP and _state != STRIKE:
		_blink_t = [5.0, 3.8, 2.6][phase - 1]
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
	if _judge_t <= 0.0 and _p != null and _fan_t > 50.0:
		_judge_t = [7.0, 5.0, 3.8][phase - 1]
		_judgement()
		if phase == 2:
			_sig += 1


func _random_deck_point() -> Vector3:
	var a := randf() * TAU
	var r := sqrt(randf()) * (_arena_r - 1.0)
	return _arena_c + Vector3(cos(a) * r, 0.0, sin(a) * r)


func _blink() -> void:
	var to := anchors.pick_random() as Vector3
	SpellFx.rift_in(global_position)
	global_position = to + Vector3.UP * 0.1
	velocity = Vector3.ZERO
	reset_physics_interpolation()           # a blink, not a one-frame smear across the deck
	_set_state(IDLE if _p == null else CHASE)
	SpellFx.rift_in(to)
	if phase >= 2:
		BossKit.zone(get_parent(), to, 1.0, 26.0, {"by": self, "radius": 4.6 if phase == 2 else 6.2, "color": BossKit.HOLY})
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
	var cone := SpellFx.danger(global_position, FAN_WINDUP, {"radius": 20.0, "half_angle": deg_to_rad(33.0), "yaw": atan2(-to.x, -to.z), "color": BossKit.HOLY})
	if cone:
		track_move(cone)
	_fan_cone = cone
	_fan_yaw = atan2(-to.x, -to.z)
	_fan_t = FAN_WINDUP
	_fans_left = 2 if double else 1


## The cone follows you until the last 0.2 s, then holds; the volley flies along the frozen yaw.
func _track_fan() -> void:
	if _fan_t <= 0.2 or _fan_t > FAN_WINDUP or _p == null or not is_instance_valid(_fan_cone):
		return
	var to := _p.global_position - global_position
	to.y = 0.0
	if to.length() < 0.5:
		return
	_fan_yaw = atan2(-to.x, -to.z)
	_face_dir = to.normalized()
	var origin := _fan_cone.global_position
	_fan_cone.global_transform = Transform3D(Basis(Vector3.UP, _fan_yaw) * Basis.from_scale(Vector3(20.0, 1.0, 20.0)), origin)


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
	var flat := Vector2(aim.x, aim.z).length()
	var fwd := Basis(Vector3.UP, _fan_yaw) * Vector3.FORWARD           # the locked cone, not where you are now
	if not (phase >= 3 and _fans_left == 1):
		aim = Vector3(fwd.x * flat, aim.y, fwd.z * flat)
	var off := 5.0 if _fans_left == 1 and phase >= 3 else 0.0     # the second volley fills the gaps
	for k in 7:
		var ang := deg_to_rad(-30.0 + 10.0 * float(k) + off)
		SpitOrb.launch(get_tree().current_scene, from, aim.rotated(Vector3.UP, ang), 17.0, k != 3)
	Vfx.burst(from, Color(2.2, 1.8, 1.0), {"count": 30, "life": 0.4, "speed": Vector2(2.0, 5.0), "size": 0.05, "dir": aim.normalized(), "spread": 40.0, "gravity": 0.0})


## Two lanes of light crossing at the player, 1.2 s to step out of both.
func _judgement() -> void:
	var at := _p.global_position
	var base := randf() * PI
	_rite(&"judgement")                         # the right hand raised and brought down across as the lanes land
	BossKit.cast(self, "Judgement", 1.2)
	for k in 2:
		var yaw := base + PI * 0.5 * float(k)
		var dir := Basis(Vector3.UP, yaw) * Vector3.FORWARD
		BossKit.zone(get_parent(), at - dir * 10.0, 1.2, 24.0, {"by": self, "rect": Vector2(1.1, 10.0), "yaw": yaw, "color": BossKit.HOLY})


## The halo found while its hands are up: the volley scatters.
func _on_weak_hit(_dmg: float) -> void:
	if not (_fan_t > 0.0 and _fan_t <= FAN_WINDUP + 0.05):
		return
	if not interrupt(null):
		_scatter()


## The fan broken by the halo or a heavy blow; the acolytes' call by a heavy blow.
func _on_cast_interrupted(n: String) -> void:
	if n == "Radiant Fan":
		_scatter()
	elif n == "Call the Acolytes":
		_stagger_cd = 0.0
		stagger()
		_broken_t = BOSS_BROKEN
		HitText.pop(global_position + Vector3.UP * (hp_bar_y + 1.0), "no one answers", WEAK_COL, true)


func _call_acolytes() -> void:
	var at := global_position
	if _arena_c != Vector3.INF:
		var away := global_position - _arena_c
		away.y = 0.0
		at = _arena_c - (away.normalized() if away.length() > 0.5 else Vector3.FORWARD) * 9.0
	var adds := BossKit.add_wave(self, ACOLYTE, at, 2, 3, "Gilded Acolyte", 4.5)
	for a in adds:
		SpellFx.column(a.global_position, 0.8, 4.0, 0.6)


## Mandorla Flare: the deck burns from FLARE_IN to FLARE_R round it; only under it is safe.
func _mandorla_flare() -> void:
	var c := global_position
	_set_state(RECOVER)
	_state_t = -FLARE_TIME
	velocity = Vector3.ZERO
	_blink_t = maxf(_blink_t, FLARE_TIME + 0.6)
	_judge_t = maxf(_judge_t, FLARE_TIME + 0.8)
	_glint = 1.0
	if not _rite(&"flare") and _rig and _rig.has_method("howl"):     # folded, then flung wide as the deck burns
		_rig.call("howl", FLARE_TIME)
	BossKit.cast(self, "Mandorla Flare", FLARE_TIME)
	BossKit.emote(self, "The mandorla flares.", BossKit.EMOTE_COL)
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


## Eclipse: the deck fills, but for the lit pylons' rings (the room) or two pillars of its light at
## blink points away from it (no room). A ring that sheltered you is spent.
func _eclipse() -> void:
	if not _rite(&"eclipse") and _rig and _rig.has_method("howl"):  # the hands rise and cup over the head
		_rig.call("howl", ECLIPSE_FILL)
	_glint = 1.0
	Sfx.play_stream(Synth.get_stream("chant"), global_position + Vector3.UP * 3.0, 3.0, 0.45)
	BossKit.cast(self, "Eclipse", ECLIPSE_FILL, false, _eclipse_lands)
	var holes: Array = []
	var pools: Array[Vector3] = []
	var pr := POOL_R
	if _room != null and is_instance_valid(_room) and int(_room.call("lit_count")) > 0:
		pools = _room.call("pylon_points", true)
		pr = float(_room.get("RING_R"))
		BossKit.emote(self, "The light goes out of the deck.", Color(1.0, 0.85, 0.4))
	else:
		var picks := anchors.duplicate()
		picks.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.distance_to(global_position) > b.distance_to(global_position))
		for k in 2:
			pools.append(picks[k])
		BossKit.emote(self, "The light goes out of the deck.", Color(1.0, 0.85, 0.4))
	for at in pools:
		holes.append([at, pr])
		SpellFx.column(at, pr * 0.8, 6.0, ECLIPSE_FILL + 0.3)
		Vfx.ring(at + Vector3.UP * 0.1, pr, BossKit.HOLY, ECLIPSE_FILL, 0.12, Vector3.UP, 1.6)
	BossKit.zone(get_parent(), _arena_c, ECLIPSE_FILL, 34.0, {"by": self, "radius": _arena_r + 1.0, "color": BossKit.HOLY, "holes": holes, "h": 3.0})


func _eclipse_lands() -> void:
	if _room == null or not is_instance_valid(_room) or _p == null:
		return
	var used: Node = _room.call("in_light", _p.global_position)
	if used != null:
		_room.call("snuff", used)
		HitText.pop(_p.global_position + Vector3.UP * 2.4, "the ring is spent", Color(0.8, 0.8, 1.0))


# --- Gale of the Door ------------------------------------------------------------------------------

func _begin_gale() -> void:
	_set_state(RECOVER)
	_state_t = -(GALE_CAST + GALE_TIME)
	velocity = Vector3.ZERO
	_blink_t = maxf(_blink_t, GALE_CAST + GALE_TIME + 0.8)
	_judge_t = maxf(_judge_t, GALE_CAST + GALE_TIME + 1.5)
	_flare_t = maxf(_flare_t, GALE_CAST + GALE_TIME + 3.0)
	_eclipse_t = maxf(_eclipse_t, GALE_CAST + GALE_TIME + 4.0)
	if not _rite(&"gale") and _rig and _rig.has_method("howl"):     # drawn back, then both palms driving the wind
		_rig.call("howl", GALE_CAST)
	BossKit.cast(self, "Gale of the Door", GALE_CAST, false, func() -> void:
		if is_alive() and not ascended and phase == 2:
			_gale_left = GALE_TIME
			BossKit.cast(self, "Gale of the Door", GALE_TIME, false))
	_lee_said = false
	BossKit.emote(self, "The door behind him opens a crack. The lit pylons are the lee.", Color(0.85, 0.9, 1.0))
	# the lee of every lit pylon lights up for the whole gale
	if _room != null and "pylons" in _room:
		var shields: Array = []
		for py: Variant in _room.get("pylons"):
			if py is Node3D and is_instance_valid(py) and bool((py as Node3D).get("lit")):
				shields.append((py as Node3D).global_position)
		BossKit.lee_marks(global_position, shields, GALE_CAST + GALE_TIME)
	Vfx.ring(global_position + Vector3.UP * 0.2, 5.0, Color(1.4, 1.5, 1.8), GALE_CAST, 0.1, Vector3.UP, 1.2)


func _tick_gale(delta: float) -> void:
	_gale_left -= delta
	_state_t = minf(_state_t, -0.2)
	velocity.x = 0.0
	velocity.z = 0.0
	var p := _p
	if p == null:
		return
	var away := p.global_position - global_position
	away.y = 0.0
	var sheltered := _room != null and bool(_room.call("gale_shelter", global_position, p.global_position))
	if not sheltered and not p.is_evading():
		BossKit.push(p, away, GALE_SPEED * minf(dmg_mult, 1.3), delta)
	if sheltered != _lee_said:
		_lee_said = sheltered
		if sheltered:
			HitText.pop(p.global_position + Vector3.UP * 2.2, "sheltered", Color(0.85, 0.9, 1.0))
	_gale_fx -= delta
	if _gale_fx <= 0.0:
		_gale_fx = 0.18
		var n := away.normalized()
		Vfx.burst(p.global_position + Vector3.UP * 1.2 - n * 3.0, Color(1.3, 1.35, 1.6, 0.7), {"count": 10, "life": 0.5, "speed": Vector2(8.0, 12.0), "size": 0.04, "dir": n, "spread": 8.0, "gravity": 0.0, "trail": 0.12, "radius": 2.0})
	if _gale_left <= 0.0:
		_gale_left = 0.0
		_finish_cast(false, false)


# --- the intermission: the Ascension ---------------------------------------------------------------

func _ascend() -> void:
	ascended = true
	_asc_t = 0.0
	_asc_from = global_position
	_finish_cast(true, false)
	cancel_moves()
	_combo_left = 0
	weak_open = false
	_grav = gravity
	gravity = 0.0
	velocity = Vector3.ZERO
	set_meta(&"phase_label", "THE ASCENSION")
	set_meta(&"ward_hint", "rekindle the pylons")
	_star_t = 2.5
	_star_p_t = 3.5
	if not _rite(&"ascend") and _rig and _rig.has_method("howl"):
		_rig.call("howl", 2.0)
	BossKit.roar(self, "", BossKit.HOLY)
	BossKit.emote(self, "The Warden ascends. The pylons go dark.", Color(1.0, 0.9, 0.6))
	AurelLines.fight(self, "ascend")
	_room.call("snuff_all")
	_room.call("set_mood", "ascension")
	BossKit.add_wave(self, ACOLYTE, _arena_c + Vector3(0, 0, 9.0), 2, 3, "Gilded Acolyte", 6.0)


func _tick_ascended(delta: float) -> void:
	_asc_t += delta
	_set_state(RECOVER)
	_state_t = -1.0
	velocity = Vector3.ZERO
	var top := _arena_c + Vector3(0.0, ASCEND_H, -9.0)        # up toward the door in the cirque, off the beacon
	global_position = _asc_from.lerp(top, smoothstep(0.0, 2.5, _asc_t))
	if _room == null or not is_instance_valid(_room):
		_descend(0)
		return
	var left := 4 - int(_room.call("lit_count"))
	if left <= 0:
		_descend(0)
		return
	if _asc_t >= ASCEND_TIME + (15.0 if _attuned else 0.0):
		_descend(left)
		return
	var asc_end := ASCEND_TIME + (15.0 if _attuned else 0.0)
	if _asc_t >= asc_end - 10.0 and _asc_t - delta < asc_end - 10.0:
		BossKit.emote(self, "The sky is breaking.", Color(1.0, 0.6, 0.4))
	_star_t -= delta
	_star_p_t -= delta
	if _star_t <= 0.0:
		_star_t = 0.9
		_room.call("star", _random_deck_point(), self)
	if _star_p_t <= 0.0 and _p != null:
		_star_p_t = 3.0
		_room.call("star", _p.global_position, self)


## A pylon was rekindled (the room tells us).
func on_pylon_lit(_p2: Node) -> void:
	if not ascended or _room == null:
		return
	var n := int(_room.call("lit_count"))
	if n < 4:
		BossKit.emote(self, "%d of 4 pylons burn." % n, Color(1.0, 0.85, 0.5))


## Back to the deck: all pylons lit (`left` 0), or the sky broke on those still dark.
func _descend(left: int) -> void:
	ascended = false
	set_meta(&"phase_label", "")
	remove_meta(&"ward_hint")
	gravity = _grav
	if left > 0:
		BossKit.emote(self, "The sky breaks!", Color(1.0, 0.5, 0.35))
		var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		if p and (_room == null or _room.call("in_light", p.global_position) == null):
			p.take_wound(SKY_GLOOM * dmg_mult, _arena_c)
		Vfx.light(_arena_c + Vector3.UP * 8.0, Color(1.0, 0.85, 0.6), 6.0, 40.0, 0.6)
		Vfx.ring(_arena_c + Vector3.UP * 0.2, _arena_r, BossKit.HOLY, 0.8, 0.2, Vector3.UP, 1.8)
	else:
		BossKit.emote(self, "Four pylons burn. He falls, blinded.", Color(1.0, 0.9, 0.6))
	var land := _arena_c + Vector3.UP * 0.1
	SpellFx.rift_in(global_position)
	global_position = land
	velocity = Vector3.ZERO
	reset_physics_interpolation()
	SpellFx.rift_in(land)
	if _room != null and is_instance_valid(_room):
		_room.call("set_mood", "fight")
	BossKit.transition(self, "His light turns to judgement. One hand never leaves the door.", BossKit.HOLY, 1.6)
	if left == 0:
		_broken_t = BOSS_BROKEN * 2.0
	_blink_t = 3.0
	_judge_t = 4.0
	_gale_t = 10.0
	_eclipse_t = 18.0
	_acolytes_t = 24.0
	_flare_t = 14.0


func voice_family() -> String:
	return "warden"


func _hit_sound() -> String:
	return "stone"
