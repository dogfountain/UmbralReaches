class_name BoneAbbot
extends Ossuant
## Boss of the Ossuary crypt. A crowned Ossuant at 1.8x, robed in a tattered cassock under a
## mitre of bone, a reliquary lantern glowing at its breast. It collapses and knits back like its
## brethren unless Marked.
## Phase 1  melee; a ring of bone spikes round itself every 6.5 s (the ring fills first), and grave
##          spikes under you every 5 s (one disc where you stand: keep moving).
## Phase 2  (below half) it reels, then roars; two Ossuants raised from the charnel mound (once), a
##          wider ring, the grave spikes come in threes leading your run, and the crozier sweeps a
##          wide arc in front of it when you stand there (a 150-degree cone fills first).
## Phase 3  (below a quarter) the Requiem: it reels again and sings. Every 9 s three rings of bone
##          rise outward from it in turn (each ring's discs fill together, the gaps between them
##          shift ring to ring: weave out through them), and the reliquary drips grave-fire, pools
##          that burn for 4 s where they fall. Between Requiems it cages you: a ring of small discs
##          round you with ONE gap, then the middle -- leave by the gap, or Rift Step out.
## r31 (docs/enshrouded/enemies.md):
##   tithe    (phase II, every 7.5 s when you keep your distance) it drives the crozier into the
##            floor and a line of bone discs walks out from it toward where you stand, one after
##            another: step off the line, sideways.
##   reliquary  through each Requiem the reliquary at its breast burns open (a gold knot): two
##            bolts that burst on it break the song -- the rings still unrisen fade, it reels,
##            broken. The Requiem still counts as sung (the phase floor holds as before).
## r33 (WoW encounter design; every move is a cast the HUD shows, see BossKit):
##   Ossuary Ring / Grave Spikes / Crozier Sweep (positional: never stand before it) / Tithe Line /
##   Requiem (only the reliquary breaks it) / Bone Cage
##   Raise the Faithful  (phases II-III, every 26 s) a 2.5 s cast with the reliquary open: one burst on
##            it or one heavy blow interrupts; unbroken, two Risen Faithful climb out (four at most).
##   The Last Count  soft enrage at ENRAGE_AT s: more Gloom per blow and spike, quicker rites.

const REQUIEM_EVERY := 9.0
const CAGE_EVERY := 7.0
const SWEEP_EVERY := 6.0
const GRAVE_FIRE := Color(2.6, 1.3, 0.3)     ## r30: candle-gold, the Ossuary's own light (violet went blue under the grade)

var phase := 1
var _sig := 0                   ## r30: signature moves this phase (I: bone rings, II: grave triples, III: Requiems)
var _spike_t := 4.0
var _grave_t := 2.5
var _sweep_t := 3.0
var _requiem_t := 3.0
var _cage_t := 6.0
var _tithe_t := 4.0
var _reliq_t := 0.0             ## the reliquary is open (a Requiem is being sung)
var _reliq_hits := 0
const TITHE_EVERY := 7.5
const RAISE_EVERY := 26.0
const RAISE_TIME := 2.5
const ENRAGE_AT := 180.0
var _raise_t := 12.0


func _init() -> void:
	super._init()
	body_kind = &"bone_abbot"
	max_hp = 160                # r30: at 90 the Requiem got one cast (r29: 45); phase floors hold each phase for two
	hp = 160.0
	walk_speed = 2.5
	strike_gloom = 40.0
	weak_socket = "chest"                       # the reliquary (where its light hangs)
	weak_offset = Vector3(0.0, -0.06, -0.36)
	weak_r = 0.11
	weak_open = false


func phase_marks() -> Array[float]:
	return [0.5, 0.25]


func on_engaged(_arena: Node) -> void:
	BossKit.intro(self, BossKit.BONE)


func _absorb(dmg: float, from: Node) -> float:
	return BossKit.absorb(self, dmg, from, BossKit.phase_floor(self, phase, phase_marks(), _sig))


func _build() -> void:
	super._build()
	name = "BoneAbbot"
	BossKit.embiggen(self, 1.8)
	# upright and slow: a priest, not a grunt (no twitch at 1.8x: big means deliberate)
	posture({"hunch": 0.1, "crouch": 0.06, "arm_reach": 0.12, "head_jut": 0.2, "limp": 0.0, "sway": 0.2, "twitch": 0.0, "splay": 0.22})
	# the reliquary lights its own ribs and the pit floor round it
	var chest := _rig.socket("chest") if _rig else null
	if chest:
		var l := OmniLight3D.new()
		l.name = "Reliquary"
		l.light_color = Color(1.0, 0.68, 0.32)
		l.light_energy = 1.6
		l.omni_range = 4.5
		l.shadow_enabled = false
		chest.add_child(l)
		l.position = Vector3(0.0, -0.06, -0.36)


## The crozier is carried upright in the right hand (it hung from the swinging arm like a cane, the
## hook behind the head): each frame its mesh is turned back to vertical about the hand.
func _process(_delta: float) -> void:
	if _crozier_mi == null:
		var hand := _rig.socket("hand_r") if _rig else null
		_crozier_mi = hand.get_node_or_null("Boss_hand_r") as Node3D if hand else null
		if _crozier_mi == null:
			return
	if _state == DEAD or _face == null:
		return
	var f := _face.global_basis.z
	var sc := _crozier_mi.global_basis.get_scale()
	_crozier_mi.global_basis = Basis(Vector3.UP, atan2(f.x, f.z)).scaled(sc)


var _crozier_mi: Node3D


func _hit_sound() -> String:
	return "bone"


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _state == DEAD:
		return
	delta *= BossKit.enrage_tick(self, delta, ENRAGE_AT)     # r33: the Last Count quickens every rite
	if phase == 1 and hp <= float(max_hp) * 0.5:
		phase = 2
		_sig = 0
		BossKit.transition(self, "\"One thousand and ninety. One thousand and ninety-one.\" The faithful rise from the bones.", BossKit.BONE)
		BossKit.summon(get_parent(), Ossuant, global_position, 3, 3.2, String(get_meta(&"boss_id", "")))
		_spike_t = maxf(_spike_t, 2.5)
	elif phase == 2 and hp <= float(max_hp) * 0.25:
		phase = 3
		_sig = 0
		BossKit.transition(self, "The Abbot counts you among the faithful. The floor remembers its dead.", GRAVE_FIRE, 1.6)
		_requiem_t = 2.2
		_cage_t = 5.5
		_spike_t = 99.0                     # the Requiem replaces the plain ring
	_reliq_t = maxf(0.0, _reliq_t - delta)
	weak_open = _reliq_t > 0.0
	if _ward_t > 0.0:
		return                              # reeling between phases: nothing new starts
	_tithe_t -= delta
	_spike_t -= delta
	_grave_t -= delta
	_sweep_t -= delta
	_requiem_t -= delta
	_cage_t -= delta
	_raise_t -= delta
	if phase >= 2 and _raise_t <= 0.0 and not casting() and _p != null:
		_raise_t = RAISE_EVERY
		_grave_t = maxf(_grave_t, RAISE_TIME + 0.5)
		_raise_faithful()
		return
	if phase >= 3:
		if _requiem_t <= 0.0:
			_requiem_t = REQUIEM_EVERY
			_cage_t = maxf(_cage_t, 3.5)
			_requiem()
			_sig += 1
		elif _cage_t <= 0.0 and _p != null and _dist < 16.0:
			_cage_t = CAGE_EVERY
			_cage()
		elif _sweep_t <= 0.0 and _sweep_ready():
			_sweep()
		return
	if _spike_t <= 0.0:
		_spike_t = 6.5 if phase == 1 else 5.0
		if _rig and _rig.has_method("telegraph"):
			_rig.call("telegraph", 1.0)
		BossKit.cast(self, "Ossuary Ring", 1.1 if phase == 1 else 0.95)
		BossKit.zone(get_parent(), global_position, 1.1 if phase == 1 else 0.95, 28.0,
			{"by": self, "radius": 4.8 if phase == 1 else 6.2, "color": BossKit.BONE, "spikes": "bone"})
		_grave_t = maxf(_grave_t, 2.0)
		if phase == 1:
			_sig += 1
	elif phase >= 2 and _sweep_t <= 0.0 and _sweep_ready():
		_sweep()
	elif phase == 2 and _tithe_t <= 0.0 and _p != null and _dist > 4.5 and _dist < 17.0:
		_tithe_t = TITHE_EVERY
		_grave_t = maxf(_grave_t, 1.8)
		_tithe()
	elif _grave_t <= 0.0 and _p != null and _dist < 18.0:
		_grave_t = 5.0 if phase == 1 else 4.0
		_grave_spikes()
		if phase == 2:
			_sig += 1


func _grave_spikes() -> void:
	var at := _p.global_position
	var run := Vector3(_p.velocity.x, 0.0, _p.velocity.z)
	var spots: Array[Vector3] = [at]
	if phase >= 2:
		var ahead := run * 0.9 if run.length() > 1.0 else (at - global_position).normalized() * 2.5
		spots.append(at + ahead)
		spots.append(at + ahead.rotated(Vector3.UP, 1.9) * 0.9)
	BossKit.cast(self, "Grave Spikes", 1.1)
	for s in spots:
		BossKit.zone(get_parent(), s, 1.1, 22.0, {"by": self, "radius": 1.8, "color": BossKit.BONE, "spikes": "bone"})
	Vfx.burst(global_position + Vector3.UP * hp_bar_y * 0.6, Color(1.4, 0.6, 2.6), {"count": 20, "life": 0.5, "speed": Vector2(1.0, 3.0), "size": 0.05, "gravity": 1.0})


## The crozier: only when you stand in front of it, inside its reach.
func _sweep_ready() -> bool:
	if _p == null or _dist > 5.0 or _face == null or _state == WINDUP or _state == STRIKE:
		return false
	var fwd := -_face.global_basis.z
	fwd.y = 0.0
	return fwd.normalized().dot(_to / maxf(_dist, 0.001)) > 0.2


func _sweep() -> void:
	_sweep_t = SWEEP_EVERY
	var yaw := atan2(-_to.x, -_to.z)
	_face_dir = _to / maxf(_dist, 0.001)
	if _rig and _rig.has_method("telegraph"):
		_rig.call("telegraph", 0.9)
	_glint = 1.0
	Sfx.play_stream(Synth.voice(voice_family(), "tell"), global_position + Vector3.UP * 2.0, 3.0, 0.6)
	BossKit.cast(self, "Crozier Sweep", 0.9)
	BossKit.zone(get_parent(), global_position, 0.9, 30.0, {"by": self, "radius": 5.6, "half_angle": deg_to_rad(75.0), "yaw": yaw, "color": BossKit.BONE})
	get_tree().create_timer(0.9, false).timeout.connect(func() -> void:
		if is_instance_valid(self) and is_alive() and _rig and _rig.has_method("strike"):
			_rig.call("strike"))


## Three rings of bone outward from it, landing in turn; each ring's gaps sit where the last
## ring's discs were. Then two pools of grave-fire drip from the reliquary.
func _requiem() -> void:
	_reliq_t = 2.4
	_reliq_hits = 0
	BossKit.cast(self, "Requiem", 2.4, true)
	if _rig and _rig.has_method("howl"):
		_rig.call("howl", 2.2)
	_glint = 1.0
	Sfx.play_stream(Synth.get_stream("chant"), global_position + Vector3.UP * 2.5, 3.0, 0.6)
	var c := global_position
	var radii := [2.6, 5.0, 7.4]
	var counts := [6, 10, 14]
	var delays := [1.0, 1.6, 2.2]
	var base := randf() * TAU
	for k in 3:
		var n: int = counts[k]
		var off := base + (PI / float(n)) * float(k % 2)
		for i in n:
			var a := off + TAU * float(i) / float(n)
			var at := _floor_at(c + Vector3(cos(a), 0.0, sin(a)) * float(radii[k]))
			if at == Vector3.INF:
				continue
			BossKit.zone(get_parent(), at, float(delays[k]), 24.0, {"by": self, "radius": 1.3, "color": BossKit.BONE, "spikes": "bone" if k < 2 or i % 2 == 0 else ""})
	for i in 2:
		var a := randf() * TAU
		var spot := _floor_at(c + Vector3(cos(a), 0.0, sin(a)) * randf_range(3.5, 7.0))
		if spot == Vector3.INF:
			continue
		var land := spot
		get_tree().create_timer(2.5 + 0.3 * float(i), false).timeout.connect(func() -> void:
			if not is_instance_valid(self) or not is_alive():
				return
			Vfx.burst(land + Vector3.UP * 0.3, GRAVE_FIRE, {"count": 24, "life": 0.6, "speed": Vector2(1.0, 3.0), "size": 0.06, "gravity": 2.0})
			AttackKit.linger(land, 1.8, 4.0, 4.0, 0.5, GRAVE_FIRE))


## The tithe: a line of discs walks out from it toward where you stand (and a step past).
func _tithe() -> void:
	var to := _p.global_position - global_position
	to.y = 0.0
	var dir := to.normalized()
	if _rig and _rig.has_method("telegraph"):
		_rig.call("telegraph", 0.7)
	_face_dir = dir
	_glint = 1.0
	Sfx.play_stream(Synth.get_stream("spike"), global_position + Vector3.UP, 0.0, 0.7)
	var n := int(clampf((to.length() + 3.0) / 1.7, 4.0, 11.0))
	BossKit.cast(self, "Tithe Line", 0.75 + 0.16 * float(n - 1))
	for i in n:
		var at := _floor_at(global_position + dir * (2.2 + 1.7 * float(i)))
		if at == Vector3.INF:
			continue
		BossKit.zone(get_parent(), at, 0.75 + 0.16 * float(i), 22.0, {"by": self, "radius": 1.25, "color": BossKit.BONE, "spikes": "bone"})


## The reliquary found while the Requiem is sung: two such bolts break the song. While it raises the
## faithful, one breaks that.
func _on_weak_hit(_dmg: float) -> void:
	if _reliq_t <= 0.0:
		return
	if casting() and cast_name == "Raise the Faithful":
		interrupt(null)
		return
	_reliq_hits += 1
	Vfx.burst(global_position + Vector3.UP * hp_bar_y * 0.55, GRAVE_FIRE, {"count": 20, "life": 0.5, "speed": Vector2(1.0, 4.0), "size": 0.05, "gravity": 2.0})
	if _reliq_hits < 2:
		return
	if not interrupt(null):
		_break_song()


## r33: the Requiem is broken only by the reliquary (two bursts), never a plain heavy blow.
func _interrupts(dmg: float, from: Node, weak: bool) -> bool:
	if cast_name == "Requiem":
		return false
	return super._interrupts(dmg, from, weak)


func _on_cast_interrupted(n: String) -> void:
	if n == "Requiem":
		_break_song()
	elif n == "Raise the Faithful":
		_reliq_t = 0.0
		weak_open = false
		_stagger_cd = 0.0
		stagger()
		_broken_t = BOSS_BROKEN
		HitText.pop(global_position + Vector3.UP * (hp_bar_y + 1.0), "the faithful stay down", WEAK_COL, true)


## Raise the Faithful: hands up, the reliquary open; unbroken, two Risen Faithful climb out.
func _raise_faithful() -> void:
	_reliq_t = RAISE_TIME
	_reliq_hits = 0
	_glint = 1.0
	if _rig and _rig.has_method("howl"):
		_rig.call("howl", RAISE_TIME)
	BossKit.cast(self, "Raise the Faithful", RAISE_TIME, true, _raised)
	Sfx.play_stream(Synth.get_stream("chant"), global_position + Vector3.UP * 2.5, 0.0, 0.75)
	Vfx.ring(global_position + Vector3.UP * 0.1, 4.0, GRAVE_FIRE, RAISE_TIME, 0.06, Vector3.UP, 1.0)


func _raised() -> void:
	_reliq_t = 0.0
	BossKit.add_wave(self, Ossuant, global_position, 2, 4, "Risen Faithful", 3.4)
	HitText.pop(global_position + Vector3.UP * (hp_bar_y + 1.0), "the faithful rise", BossKit.BONE)


func _break_song() -> void:
	_reliq_t = 0.0
	weak_open = false
	cancel_moves()
	stagger()
	_broken_t = BOSS_BROKEN
	HitText.pop(global_position + Vector3.UP * (hp_bar_y + 1.0), "the Requiem breaks", WEAK_COL, true)
	Sfx.play_stream(Synth.get_stream("bone"), global_position + Vector3.UP * 2.0, 3.0, 0.5)


## The cage: eight small discs round you with one gap, then the middle.
func _cage() -> void:
	var c := _p.global_position
	var gap := randi() % 8
	var base := randf() * TAU
	BossKit.cast(self, "Bone Cage", 1.6)
	if _rig and _rig.has_method("telegraph"):
		_rig.call("telegraph", 1.0)
	for i in 8:
		if i == gap:
			continue
		var a := base + TAU * float(i) / 8.0
		var at := _floor_at(c + Vector3(cos(a), 0.0, sin(a)) * 2.6)
		if at != Vector3.INF:
			BossKit.zone(get_parent(), at, 1.0, 20.0, {"by": self, "radius": 1.05, "color": BossKit.BONE, "spikes": "bone"})
	BossKit.zone(get_parent(), c, 1.6, 26.0, {"by": self, "radius": 2.0, "color": GRAVE_FIRE, "spikes": "bone"})
	Vfx.arc(global_position + Vector3.UP * hp_bar_y * 0.6, c + Vector3.UP * 0.5, GRAVE_FIRE, 0.3, 0.3)


func _floor_at(p: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 3.0, p + Vector3.DOWN * 5.0, Layers.WORLD))
	return (hit.position as Vector3) if not hit.is_empty() else Vector3.INF


func voice_family() -> String:
	return "rattle"
