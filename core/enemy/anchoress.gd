extends "res://core/enemy/wretch.gd"
## boss of the Anchorholds (RealmLayout.RAIDS "anchorhold"): the Anchoress. A hermit who had
## herself walled into the Crowns' face to pray the sky still, and would not come out when the wall was
## opened: a gaunt woman at 2.3x, in grey wool and the chain she bound herself with, a cairn-stone
## anchor swinging from her right hand, a caged lantern in her left. 560 HP, three phases on a cliff
## terrace with four hermits' cairns standing in it (the room: core/world/realm/realm_pois_east_marches.gd).
##
## Phase I    "The Vow" (100-70 %)
##   Anchor Swing     the anchor flung down a lane (a long red strip, 1.3 s). Step out of the lane.
##   Chain Ring       (1.7 s) the chain whips a ring round her: stay out of it, or in the lee past it.
##   Toll of the Cell (interruptible: the lantern at her hip, or a heavy blow) she calls two Walled
##                    Hermits out of the cells; unbroken, they join the fight. The signature of the phase.
## Phase II   "The Cell Closes" (70-35 %)
##   Rockfall         stones come down off the cliff round you, one disc after another (keep moving).
##   The Undertow     (3.4 s, cannot be broken) she drags the anchor and the whole terrace slides toward
##                    her: get behind a cairn (its lee is lit) or take the full weight. The signature.
##   and the Swing, the Ring and the Toll go on.
## Phase III  "The Last Prayer" (35-0 %)
##   the lantern flares; everything quickens, the Swing comes twice (the second turned across the
##   first), the Rockfall comes in sixes and the Undertow every 17 s.

const QuestBook := preload("res://core/story/quest_book.gd")
const HermitScript := preload("res://core/enemy/wretch.gd")

const ID := "r37_anchoress"
const HP := 560
const SCALE := 2.3
const LANE_LEN := 6.4                 ## half length of the Swing's strip (x2 on the ground)
const LANE_W := 1.7
const RING_R := 5.4
const SWING_EVERY := 6.5
const RING_EVERY := 10.5
const TOLL_EVERY := 24.0
const TOLL_TIME := 2.4
const ROCK_EVERY := 8.0
const UNDER_EVERY := 21.0
const UNDER_TIME := 3.4
const UNDER_GLOOM := 44.0
const PULL := 3.4                      ## m/s the undertow drags
const GLOW := Color(2.4, 1.5, 0.5)
const SALT := Color(1.8, 1.9, 2.0)

var phase := 1
var _sig := 0
var _swing_t := 3.5
var _ring_t := 8.0
var _toll_t := 13.0
var _rock_t := 6.0
var _under_t := 15.0
var _knot_t := 0.0
var _under_left := 0.0
var _busy := 0.0
var _attuned := false
var _room: Node = null
var _arena_c := Vector3.INF


func _init() -> void:
	super._init()
	max_hp = HP
	hp = float(HP)
	walk_speed = 3.2
	strike_gloom = 38.0
	chase_range = 40.0
	feint_chance = 0.0
	combo_max = 0
	can_call = false
	weak_socket = "pelvis"                       # the lantern at her hip
	weak_offset = Vector3(0.14, 0.0, -0.16)
	weak_r = 0.12
	weak_open = false


func phase_marks() -> Array[float]:
	return [0.7, 0.35]


func _build() -> void:
	super._build()
	name = "Anchoress"
	_dress()
	BossKit.embiggen(self, SCALE)


func on_engaged(arena: Node) -> void:
	BossKit.intro(self, GLOW, 2.2)
	_room = arena.get("room") as Node if arena != null else null
	if arena is Node3D:
		_arena_c = (arena as Node3D).global_position
	_attuned = QuestBook.attuned(ID)
	get_tree().create_timer(0.3, false).timeout.connect(func() -> void:
		if is_instance_valid(self) and is_alive():
			BossKit.emote(self, "\"Not yet. Not yet.\" The Anchoress turns in her chain and does not stop praying."))


func _absorb(dmg: float, from: Node) -> float:
	return BossKit.absorb(self, dmg, from, BossKit.phase_floor(self, phase, phase_marks(), _sig))


# --- the look: wool, chain, a stone on a chain, a caged lantern ------------------------------------

const WOOL := Color(0.46, 0.43, 0.38)
const WOOL2 := Color(0.34, 0.32, 0.3)
const IRON := Color(0.26, 0.25, 0.28)
const STONE := Color(0.5, 0.52, 0.5)
static var _parts_cache := {}
static var _mat_cache: ShaderMaterial = null


static func _mat() -> ShaderMaterial:
	if _mat_cache == null:
		_mat_cache = EnemyBody.material(&"wretch").duplicate() as ShaderMaterial
		_mat_cache.set_shader_parameter("skin", Color(0.5, 0.47, 0.42))
		_mat_cache.set_shader_parameter("deep", Color(0.16, 0.14, 0.12))
		_mat_cache.set_shader_parameter("eye_col", GLOW)
		_mat_cache.set_shader_parameter("rim_col", Color(0.8, 0.6, 0.4))
	return _mat_cache


func _dress() -> void:
	if _rig == null:
		return
	if _parts_cache.is_empty():
		_parts_cache = _make_parts()
	var dressed: Array[MeshInstance3D] = []
	for mi0 in _flesh:
		if is_instance_valid(mi0):
			dressed.append(mi0)
	for sock: String in _parts_cache:
		var at := _rig.socket(sock)
		if at == null:
			continue
		var mi := MeshInstance3D.new()
		mi.name = "Anchoress_" + sock
		mi.mesh = _parts_cache[sock]
		mi.material_override = _mat()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if sock in ["chest", "head", "pelvis"] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		at.add_child(mi)
		dressed.append(mi)
	set_flesh(dressed)


static func _make_parts() -> Dictionary:
	var parts := {}
	# head: a hood of grey wool, a rope across the mouth, a salt-crust on the brow
	var h := CreatureMesh.new(37001)
	h.blob(Vector3(0, 0.05, 0.03), Vector3(0.17, 0.18, 0.18), Basis.IDENTITY, WOOL, 0.0, 0.2, 0.0, 7, 12, 1.0)
	h.tube(PackedVector3Array([Vector3(0, 0.16, 0.07), Vector3(0, 0.1, 0.19), Vector3(0, -0.02, 0.23), Vector3(0, -0.14, 0.2)]),
		PackedFloat32Array([0.07, 0.06, 0.04, 0.0]), 6, WOOL2, 0.0, 0.15, 0.0, Vector2(1.0, 0.5), 1.0)
	h.tube(PackedVector3Array([Vector3(-0.11, -0.04, -0.12), Vector3(0, -0.05, -0.15), Vector3(0.11, -0.04, -0.12)]), PackedFloat32Array([0.01, 0.01, 0.01]), 4, Color(0.6, 0.5, 0.36), 0.0, 0.0)
	for k in 5:
		h.blob(Vector3(-0.08 + 0.04 * float(k), 0.12, -0.12), Vector3(0.016, 0.02, 0.014), Basis.IDENTITY, Color(0.86, 0.88, 0.84), 1.0, 0.1, 0.0, 4, 6)
	parts["head"] = h.commit()
	# chest: chain wrapped over the shoulders and down, a shawl, a pendant cairn-stone, the lamp's chain
	var c := CreatureMesh.new(37002)
	for k in 4:
		c.wrap(Vector3(-0.26, 0.18 - 0.04 * float(k), 0.0), Vector3(0.26, -0.22 - 0.03 * float(k), 0.0), 0.22 + 0.012 * float(k), 1.4 + 0.3 * float(k), 0.022, IRON)
	for k in 12:
		var ang := TAU * float(k) / 12.0
		c.strand(Vector3(cos(ang) * 0.2, 0.2, sin(ang) * 0.16), Vector3(cos(ang) * 0.3, -1.0, sin(ang) * 0.3).normalized(), 0.4 + 0.1 * float(k % 3), 0.07, 0.04, WOOL, 1.0, 0.3, 5)
	c.blob(Vector3(0.0, -0.06, -0.24), Vector3(0.06, 0.07, 0.05), Basis.IDENTITY, STONE, 1.0, 0.14, 0.0, 6, 9)
	c.tube(PackedVector3Array([Vector3(-0.1, 0.18, -0.16), Vector3(0, -0.02, -0.24), Vector3(0.1, 0.18, -0.16)]), PackedFloat32Array([0.008, 0.008, 0.008]), 4, IRON, 1.0, 0.0)
	parts["chest"] = c.commit()
	# pelvis: a long grey skirt tied with rope, the lantern's hook
	var p := CreatureMesh.new(37003)
	p.skirt(Vector3(0, 0.02, 0), 0.26, 0.22, 0.95, 0.1, 0.5, 9, 0.3, WOOL2)
	p.tube(PackedVector3Array([Vector3(-0.22, 0.0, 0), Vector3(0, -0.02, -0.24), Vector3(0.22, 0.0, 0)]), PackedFloat32Array([0.016, 0.016, 0.016]), 4, Color(0.55, 0.45, 0.32), 0.0, 0.0)
	parts["pelvis"] = p.commit()
	# right hand: the anchor: a cairn-stone on a chain, an iron ring, hanging a body-length
	var r := CreatureMesh.new(37004)
	r.tube(PackedVector3Array([Vector3(0, -0.02, 0), Vector3(0.01, -0.3, -0.02), Vector3(0.0, -0.58, 0.0)]), PackedFloat32Array([0.012, 0.012, 0.012]), 4, IRON, 1.0, 0.0)
	r.blob(Vector3(0, -0.74, 0), Vector3(0.17, 0.2, 0.17), Basis.IDENTITY, STONE, 1.0, 0.2, 0.0, 7, 10)
	r.blob(Vector3(0.04, -0.62, 0.02), Vector3(0.05, 0.03, 0.05), Basis.IDENTITY, Color(0.85, 0.86, 0.82), 1.0, 0.1, 0.0, 4, 6)
	r.ring(Vector3(0, -0.6, 0), Vector3.FORWARD, 0.07, 0.014, IRON, 1.0, 0.0, 12)
	parts["hand_r"] = r.commit()
	# left hand: a lantern in an iron cage, hot inside
	var l := CreatureMesh.new(37005)
	l.tube(PackedVector3Array([Vector3(0, -0.02, 0), Vector3(0, -0.12, 0)]), PackedFloat32Array([0.008, 0.008]), 4, IRON, 1.0, 0.0)
	l.blob(Vector3(0, -0.2, 0), Vector3(0.05, 0.07, 0.05), Basis.IDENTITY, Color(1.0, 0.6, 0.2), 0.0, 0.0, 1.0, 5, 8)
	for k in 6:
		var a := TAU * float(k) / 6.0
		l.tube(PackedVector3Array([Vector3(cos(a) * 0.06, -0.13, sin(a) * 0.06), Vector3(cos(a) * 0.07, -0.2, sin(a) * 0.07), Vector3(cos(a) * 0.06, -0.27, sin(a) * 0.06)]), PackedFloat32Array([0.004, 0.004, 0.004]), 3, IRON, 1.0, 0.0)
	parts["hand_l"] = l.commit()
	return parts


# --- the fight ------------------------------------------------------------------------------------

func _cairns() -> Array[Vector3]:
	var out: Array[Vector3] = []
	if _room != null and is_instance_valid(_room) and _room.has_meta("cairns"):
		for c: Variant in _room.get_meta("cairns"):
			out.append(c as Vector3)
	return out


## Is `at` in the lee of a cairn against the Anchoress (the lit spot 1.6 m behind it)?
func sheltered(at: Vector3) -> bool:
	for c: Vector3 in _cairns():
		var d := c - global_position
		d.y = 0.0
		if d.length() < 0.5:
			continue
		var spot := c + d.normalized() * 1.6
		if Vector2(at.x - spot.x, at.z - spot.z).length() < 2.3:
			return true
	return false


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _state == DEAD:
		return
	if phase == 1 and hp <= float(max_hp) * 0.7:
		phase = 2
		_sig = 0
		_busy = 0.0
		BossKit.transition(self, "The wall closes. The cliff remembers every stone.", GLOW)
		_rock_t = 3.0
		_under_t = 9.0
	elif phase == 2 and hp <= float(max_hp) * 0.35:
		phase = 3
		_sig = 0
		_busy = 0.0
		BossKit.transition(self, "The lantern flares. The last prayer is the loudest.", Color(2.6, 1.0, 0.3))
		walk_speed *= 1.15
	_knot_t = maxf(0.0, _knot_t - delta)
	weak_open = _knot_t > 0.0
	_busy = maxf(0.0, _busy - delta)
	if _under_left > 0.0:
		_tick_under(delta)
	if _ward_t > 0.0 or _p == null:
		return
	var q := 0.78 if phase >= 3 else 1.0
	_swing_t -= delta
	_ring_t -= delta
	_toll_t -= delta
	if phase >= 2:
		_rock_t -= delta
		_under_t -= delta
	if casting() or _busy > 0.0:
		if casting() and cast_name in ["Chain Ring", "The Undertow", "Toll of the Cell", "Anchor Swing"]:
			_state_t = minf(_state_t, 0.0)
			velocity.x = 0.0
			velocity.z = 0.0
		return
	if phase >= 2 and _under_t <= 0.0 and _dist < 30.0:
		_under_t = (UNDER_EVERY - (4.0 if phase >= 3 else 0.0))
		_swing_t = maxf(_swing_t, UNDER_TIME + 1.5)
		_ring_t = maxf(_ring_t, UNDER_TIME + 2.5)
		_undertow()
	elif _toll_t <= 0.0 and _hermits() < 3:
		_toll_t = TOLL_EVERY * q
		_swing_t = maxf(_swing_t, TOLL_TIME + 1.0)
		_toll()
	elif phase >= 2 and _rock_t <= 0.0:
		_rock_t = ROCK_EVERY * q
		_rockfall()
	elif _swing_t <= 0.0:
		_swing_t = SWING_EVERY * q
		_swing(0.0)
		if phase >= 3:
			_double_swing()
	elif _ring_t <= 0.0 and _dist < RING_R + 4.0:
		_ring_t = RING_EVERY * q
		_chain_ring()


func _hermits() -> int:
	if not is_inside_tree():
		return 0
	var n := 0
	var bid := String(get_meta(&"boss_id", ""))
	for e in get_tree().get_nodes_in_group(Groups.ENEMY):
		if e != self and e is Enemy and (e as Enemy).is_alive() and String((e as Node).get_meta(&"summoned_by", "")) == bid:
			n += 1
	return n


## Anchor Swing: the strip down which the anchor flies, from her feet through where you stand.
func _swing(turn: float) -> void:
	var to := _p.global_position - global_position
	to.y = 0.0
	if to.length() < 0.5:
		return
	var yaw := atan2(-to.x, -to.z) + turn
	_face_dir = to.normalized().rotated(Vector3.UP, -turn)
	_set_state(RECOVER)
	_state_t = -1.3
	_tell(1.3)
	_glint = 1.0
	BossKit.cast(self, "Anchor Swing", 1.3)
	if turn == 0.0:
		_sig += 1 if phase == 1 else 0
	BossKit.zone(get_parent(), global_position, 1.3, 30.0, {"by": self, "rect": Vector2(LANE_W, LANE_LEN), "yaw": yaw, "color": GLOW})
	say("windup", global_position + Vector3.UP * 2.0, 1.0, 0.6)


func _double_swing() -> void:
	get_tree().create_timer(1.35, false).timeout.connect(_second_swing)


func _second_swing() -> void:
	if is_alive() and _p != null and _ward_t <= 0.0 and not casting():
		_swing(0.7 if randf() < 0.5 else -0.7)


func _tell(dur: float) -> void:
	if _rig is HunchRig:
		(_rig as HunchRig).telegraph(dur)


func _howl(dur: float) -> void:
	if _rig is HunchRig:
		(_rig as HunchRig).howl(dur)


## Chain Ring: the chain whips out round her.
func _chain_ring() -> void:
	_set_state(RECOVER)
	_state_t = -1.7
	_glint = 1.0
	_tell(1.7)
	var r := RING_R + (1.8 if phase >= 3 else 0.0)
	BossKit.cast(self, "Chain Ring", 1.7)
	BossKit.zone(get_parent(), global_position, 1.7, 28.0, {"by": self, "radius": r, "color": SALT})
	Vfx.ring(global_position + Vector3.UP * 0.2, r, SALT, 1.7, 0.1, Vector3.UP, 1.1)


## Toll of the Cell: she calls the cells. The lantern at her hip burns open; break it and the call dies.
func _toll() -> void:
	_set_state(RECOVER)
	_state_t = -TOLL_TIME
	_knot_t = TOLL_TIME
	_glint = 1.0
	_howl(TOLL_TIME)
	BossKit.cast(self, "Toll of the Cell", TOLL_TIME, true, _tolled)
	BossKit.emote(self, "The Anchoress lifts her lantern to the cells.", Color(1.0, 0.82, 0.5))
	if phase == 1:
		_sig += 1
	SpellFx.shell(global_position + Vector3.UP * hp_bar_y * 0.5, hp_bar_y * 0.3, hp_bar_y * 0.55, Color(0.9, 0.6, 0.3), TOLL_TIME)


func _tolled() -> void:
	_knot_t = 0.0
	var adds := BossKit.add_wave(self, HermitScript, global_position, 2 if not _attuned else 1, 4, "Walled Hermit", 4.5)
	if not adds.is_empty():
		HitText.pop(global_position + Vector3.UP * (hp_bar_y + 1.0), "the cells open", GLOW)


func _on_weak_hit(_dmg: float) -> void:
	if _knot_t <= 0.0:
		return
	_knot_t = 0.0
	weak_open = false
	if not interrupt(null):
		_torn("the lantern gutters")


func _on_cast_interrupted(n: String) -> void:
	if n == "Toll of the Cell":
		_torn("the lantern gutters")


func _torn(line: String) -> void:
	_knot_t = 0.0
	weak_open = false
	cancel_moves()
	_stagger_cd = 0.0
	stagger()
	_broken_t = BOSS_BROKEN
	HitText.pop(global_position + Vector3.UP * (hp_bar_y + 1.0), line, WEAK_COL, true)
	Vfx.burst(global_position + Vector3.UP * hp_bar_y * 0.5, GLOW, {"count": 40, "life": 0.6, "speed": Vector2(2.0, 6.0), "size": 0.06, "gravity": -6.0})


## Rockfall: discs of falling stone round you, one after another; the first on your own feet.
func _rockfall() -> void:
	BossKit.cast(self, "Rockfall", 1.4)
	BossKit.emote(self, "Stones come down off the cliff.", Color(1.0, 0.7, 0.4))
	var n := 6 if phase >= 3 else 4
	var c := _p.global_position
	for i in n:
		var a := TAU * float(i) / float(n) + randf() * 0.6
		var at := c + Vector3(cos(a), 0.0, sin(a)) * (0.0 if i == 0 else randf_range(3.0, 6.5))
		if _arena_c != Vector3.INF:
			var off := at - _arena_c
			off.y = 0.0
			if off.length() > 15.5:
				at = _arena_c + off.normalized() * 15.5
		var eid := get_instance_id()
		var delay := 1.4 + 0.45 * float(i)
		BossKit.zone(get_parent(), at, delay, 24.0, {"by": self, "radius": 2.6, "spikes": "bone", "color": Color(1.5, 0.8, 0.4)})
		if i == 0:
			_busy = 1.2
	Sfx.play_stream(Synth.get_stream("stagger"), global_position + Vector3.UP * 2.0, 0.0, 0.5)


## The Undertow: the whole terrace slides toward her; only a cairn's lee holds.
func _undertow() -> void:
	_set_state(RECOVER)
	_state_t = -UNDER_TIME
	velocity = Vector3.ZERO
	_glint = 1.0
	_howl(UNDER_TIME)
	BossKit.cast(self, "The Undertow", UNDER_TIME, false, _under_lands)
	BossKit.emote(self, "She drags the anchor. The terrace slides toward her.", Color(1.0, 0.6, 0.35))
	_under_left = UNDER_TIME
	_sig += 1 if phase == 2 else 0
	var shields: Array = []
	for c: Vector3 in _cairns():
		shields.append(c)
	BossKit.lee_marks(global_position, shields, UNDER_TIME, Color(1.4, 1.5, 1.9))
	Vfx.ring(global_position + Vector3.UP * 0.2, 14.0, GLOW, UNDER_TIME, 0.1, Vector3.UP, 1.0)
	Sfx.play_stream(Synth.get_stream("chant"), global_position + Vector3.UP * 2.0, 2.0, 0.4)


func _tick_under(delta: float) -> void:
	_under_left -= delta
	var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Player
	if p == null:
		return
	var d := global_position - p.global_position
	d.y = 0.0
	if d.length() < 2.6 or sheltered(p.global_position):
		return
	BossKit.push(p, d, PULL, delta)


func _under_lands() -> void:
	_under_left = 0.0
	if not is_alive():
		return
	var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Player
	if p == null:
		return
	var d := p.global_position - global_position
	Vfx.burst(global_position + Vector3.UP * 0.3, SALT, {"count": 40, "life": 0.8, "speed": Vector2(4.0, 10.0), "size": 0.07, "gravity": -1.0, "ring": 8.0})
	if sheltered(p.global_position):
		HitText.pop(p.global_position + Vector3.UP * 2.2, "sheltered", Color(0.75, 0.9, 1.0))
	elif p.is_evading():
		p.on_evaded(self)
	elif Vector2(d.x, d.z).length() < 2.8:
		HitText.pop(p.global_position + Vector3.UP * 2.2, "under the anchor", Color(1.0, 0.7, 0.4))
		p.take_wound(UNDER_GLOOM * 0.6 * dmg_mult, global_position)
	else:
		p.take_wound(UNDER_GLOOM * dmg_mult, global_position)


func voice_family() -> String:
	return "anchoress"
