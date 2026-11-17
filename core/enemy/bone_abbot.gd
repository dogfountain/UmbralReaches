class_name BoneAbbot
extends Ossuant
## Boss of the Ossuary crypt: Abbot Osric, still counting. A crowned Ossuant (2.6x since r34), robed
## in a tattered cassock and a deep cowl crowned with rib tines, ember eyes in the dark of the hood, a
## reliquary lantern glowing at its breast.
## r34 crypt (docs/r34/raid_crypt.md): a raid boss in the pit hall under the bank (world/areas/ossuary/
## oss_hall.gd), WoW encounter design adapted for one player. 620 HP (r30-r33: 160), four phases and an
## intermission, every move a named cast (BossKit.cast / Enemy.cast_info) told on the ground first.
##
##   I    the Vespers (100-66 %): Crozier Sweep (never stand before him), Ossuary Ring (out of his
##        reach), Grave Spikes (keep moving), THE TOLLING: he rings the bell over your side of the hall
##        and the whole floor fills, all but the sound-shadow behind the great mound (a pale pool):
##        get round the mound into it.
##   INTERMISSION  "The Count Is Taken" (at 66 %): he sinks into the mound; three Tallies rise on the
##        chapels' plinths and feed him on threads of grave-light; the dead climb out of the mound in
##        waves. Break the three Tallies and he rises at once; any left when the count is done (45 s)
##        heal him 6 % each.
##   II   the Choir (66-33 %): he rises with the HYMN OF THE CHOIR -- two Choir of the Count (Chanters)
##        on the floor's edge; while one lives he takes half damage and every rite quickens: kill
##        them first. THE RECKONING: gold plates appear about the floor and he counts; step on each
##        before the count ends (it names how many are counted) -- each one missed raises a Risen
##        Faithful and costs Gloom. BONE RAIN: three fields fill and the vault drops bones on them;
##        they stay foul with ossuary dust a while. Raise the Faithful (interrupt), Tithe Line,
##        triples of Grave Spikes, the Tolling.
##   III  the Requiem (33-12 %): THE FLOOR REMEMBERS: four of the floor's eight sectors shake and
##        fall into the Uncounted Deep (a fall throws you back up for Gloom); the Requiem's rings
##        (only the reliquary breaks it), the Bone Cage, Bone Rain, the Tolling, the Reckoning
##        (four plates), the Choir once more.
##   IV   the Last Count (12 % - 0): three more sectors fall, leaving the inner disc and the door's
##        tongue; he no longer wards himself (+20 % taken) but every rite comes faster. Burn him.
## Kept from r29-r33 (tests call them): _tithe, _requiem, _raise_faithful, _cage, the reliquary at his
## breast (two bursts break the Requiem; one breaks Raise the Faithful), the phase floors.

const ClipRig := preload("res://core/enemy/clip_rig.gd")
const VillagerBossRig := preload("res://core/enemy/villager_boss_rig.gd")
const AbbotBody := preload("res://core/enemy/abbot_body.gd")
const ChanterScript := preload("res://core/enemy/chanter.gd")
const TallyScript := preload("res://core/enemy/tally_reliquary.gd")
const Kit := preload("res://core/life/secrets/kit.gd")
const Hall := preload("res://world/areas/ossuary/oss_hall.gd")   ## the pit hall's numbers (its node is _hall)
const QuestBook := preload("res://core/story/quest_book.gd")

const SCALE := 2.6               ## r34: 1.8 -> 2.6 for a 45 m hall
const HP := 620                  ## r34: 160 -> 620 (~4.5-5.5 min at ~3.5 dps of uptime; the overworld raids: 600 and 760)
const REQUIEM_EVERY := 11.0
const CAGE_EVERY := 8.0
const SWEEP_EVERY := 6.0
const TITHE_EVERY := 9.0
const RAISE_EVERY := 26.0
const RAISE_TIME := 2.5
const GRAVE_FIRE := Color(2.6, 1.3, 0.3)     ## r30: candle-gold, the Ossuary's own light (violet went blue under the grade)
const GRAVE := Color(0.62, 0.8, 0.68)        ## grave-light (the Tallies, the sound-shadow)
const DUST := Color(0.9, 0.82, 0.62)
const INTER_AT := 0.66
const P3_AT := 0.33
const BURN_AT := 0.12
const INTER_TIME := 45.0
const WAVE_EVERY := 10.0
const TALLY_HEAL := 0.06
const TOLL_TIME := 3.6
const TOLL_GLOOM := 45.0
const SHADOW_AT := 6.6           ## the sound-shadow's centre, metres behind the mound's centre
const SHADOW_R := 3.2
const RAIN_TIME := 2.0
const RAIN_R := 4.0
const RECKON_TIME := 9.5
const PLATE_R := 1.5
const SHORT_GLOOM := 14.0        ## per plate the Reckoning misses
const CHOIR_HP := 4
const BURN_TAKEN := 1.2

var phase := 1
var _sig := 0                   ## r30: signature moves this phase (I: rings + tollings, II: grave triples/tithes/reckonings, III: Requiems)
var _spike_t := 4.0
var _grave_t := 2.5
var _sweep_t := 3.0
var _requiem_t := 3.0
var _cage_t := 6.0
var _tithe_t := 4.0
var _reliq_t := 0.0             ## the reliquary is open (a Requiem is being sung)
var _reliq_hits := 0
var _raise_t := 12.0
var _toll_t := 12.0
var _rain_t := 6.0
var _reckon_t := 12.0
var _choir_t := 99.0
var _choir_calls := 0
var _busy := 0.0                ## a great rite holds the hall (the Tolling, a Requiem): nothing else starts
var _hall: Node3D               ## the pit hall (oss_hall.gd) when he is fought in it
var _inter := 0                 ## 0 not yet, 1 in the mound, 2 risen
var _inter_t := 0.0
var _wave_t := 0.0
var _waves := 0
var _tallies: Array[Enemy] = []
var _plates: Array = []         ## the Reckoning: [{at: Vector3, done: bool}]
var _reckon_n := 0
var _hymn := false
var _hymn_fx := 0.0
var _falls: Array = []          ## pending sector falls: [sector, seconds]
var _crozier_mi: Node3D
var _attuned := false           ## Sister Agathe's chain done (QuestBook.attuned): his count comes up short


func _init() -> void:
	super._init()
	body_kind = &"bone_abbot"
	max_hp = HP
	hp = float(HP)
	walk_speed = 2.5
	strike_gloom = 40.0
	weak_socket = "chest"                       # the reliquary (where its light hangs)
	weak_offset = Vector3(0.0, -0.06, -0.36)
	weak_r = 0.11
	weak_open = false


func phase_marks() -> Array[float]:
	return [INTER_AT, P3_AT, BURN_AT]


func on_engaged(arena: Node) -> void:
	BossKit.intro(self, BossKit.BONE)
	# r34 quests: WoW-style attunement. His count comes up short: one plate fewer in each Reckoning,
	# one fewer of the faithful in each raising and wave, and the count in the mound runs 10 s shorter.
	_attuned = QuestBook.attuned("bone_abbot")
	var line := "\"...one thousand and ninety... and...\" His count comes up short." if _attuned \
		else "\"One thousand and ninety.\" Abbot Osric turns from his dead to count you."
	get_tree().create_timer(0.25, false).timeout.connect(func() -> void:
		if is_instance_valid(self) and is_alive():
			BossKit.emote(self, line))
	if arena and arena.get_parent():
		_hall = arena.get_parent().get_node_or_null("Crypt") as Node3D
		if _hall and not bool(_hall.get("built")):
			_hall = null


func _absorb(dmg: float, from: Node) -> float:
	if _inter == 1:
		BossKit.warded_hit(self, "break the three tallies", Color(0.7, 1.0, 0.8), from)
		return 0.0                              # in the mound: nothing reaches him
	if phase >= 4:
		dmg *= BURN_TAKEN
	return BossKit.absorb(self, dmg, from, BossKit.phase_floor(self, phase, phase_marks(), _sig))


func _build() -> void:
	name = "BoneAbbot"
	# (17 Nov, Luke: "reduce boss to simple model like villager, these models suck"; "the style, not the exact look")
	# ("have some creativity") built in the villagers' style (their skeleton, soft skinning, shader, procedural
	# primitives) to his own design (core/enemy/abbot_body.gd): hunched under a hooked hood with a bone crown, ember
	# eyes in the dark, a ribcage torn open on a burning reliquary heart, a ragged mantle with candles, skeletal hands, a
	# vertebra crozier; posed by formula (core/enemy/villager_boss_rig.gd). The Blender model and its clips
	# (boss_bone_abbot.py, boss_humanoid_anim.py, ClipRig) are kept for the record.
	var rig: CharacterRig = VillagerBossRig.new()
	rig.set("body_script", AbbotBody)
	rig.set("stoop", 0.04)                     # the hunch is in his own skeleton
	rig.set("opts", {"seed": 6101, "sex": "m", "age": "adult"})
	attach_rig(rig)
	_rig.scale = Vector3.ONE * 1.34          # 1.95 tall in body units: at SCALE 2.6 and this, about 7.5 m (Luke: bosses 4-5x a man)
	_rig_xf = _rig.transform
	var col := get_node_or_null("Collision") as CollisionShape3D
	if col and col.shape is CapsuleShape3D:
		var cap := col.shape as CapsuleShape3D
		cap.height = CAPSULE_H * 0.92
		col.position.y = cap.height * 0.5
	set_flesh(rig.dress(&"bone_abbot"))
	set_meta(&"yield_cast", "Bone Rain")           # the rain's long bar gives way to the next rite's
	BossKit.embiggen(self, SCALE)
	strike_range = 3.0                          # embiggen caps reach at 1.7x; his arms are 2.6x
	# upright and slow: a priest, not a grunt (no twitch at this size: big means deliberate)
	posture({"hunch": 0.1, "crouch": 0.06, "arm_reach": 0.12, "head_jut": 0.2, "limp": 0.0, "sway": 0.2, "twitch": 0.0, "splay": 0.22})
	# the reliquary lights its own ribs and the floor round it; on the villager rig it is the lantern in his left hand
	# (held a hand before his chest, its light lit his face and beard orange)
	var lamp := _rig.get("lantern_node") as Node3D if _rig else null
	var chest := lamp if lamp != null else (_rig.socket("chest") if _rig else null)
	if chest:
		var l := OmniLight3D.new()
		l.name = "Reliquary"
		l.light_color = Color(1.0, 0.68, 0.32)
		l.light_energy = 0.75                     # (hooded, 17 Nov: at 1.6 it flooded the surplice a hand in front of it)
		l.omni_range = 5.0
		l.shadow_enabled = false
		chest.add_child(l)
		l.position = Vector3.ZERO if lamp != null else Vector3(0.0, -0.06, -0.5)


## The crozier is carried upright in the right hand (it hung from the swinging arm like a cane, the
## hook behind the head): each frame its mesh is turned back to vertical about the hand.
func _process(_delta: float) -> void:
	if _rig != null and (_rig.get_script() == ClipRig or _rig.get_script() == VillagerBossRig):
		set_process(false)                   # the authored clips carry the crozier themselves
		return
	if _crozier_mi == null:
		var hand := _rig.socket("hand_r") if _rig else null
		_crozier_mi = hand.get_node_or_null("Kin_glow_hand_r") as Node3D if hand else null
		if _crozier_mi == null:
			return
	if _state == DEAD or _face == null:
		return
	var f := _face.global_basis.z
	var sc := _crozier_mi.global_basis.get_scale()
	_crozier_mi.global_basis = Basis(Vector3.UP, atan2(f.x, f.z)).scaled(sc)


func _hit_sound() -> String:
	return "bone"


## Always the end at 0 HP (an Ossuant knits back unless Marked: the Abbot's count is finished).
func _die() -> void:
	marks = maxi(marks, 1)
	_end_plates(false)
	super._die()
	var bid := String(get_meta(&"boss_id", ""))
	if bid == "":
		return
	# his dead go down with him
	for n in get_tree().get_nodes_in_group(Groups.ENEMY):
		var e := n as Enemy
		if e and e != self and e.get_meta(&"summoned_by", "__") == bid and e.is_alive():
			e.marks = maxi(e.marks, 1)
			e.set_meta(&"test_no_floor", true)
			e.call_deferred("take_hit", 999.0, null)


func _hall_ok() -> bool:
	return _hall != null and is_instance_valid(_hall)


func _physics_process(delta: float) -> void:
	if _inter == 1:
		_tick_cast(delta)                       # the intermission's own bar
		_intermission(delta)
		return
	super._physics_process(delta)
	if _state == DEAD:
		return
	var haste := 1.0                                # r35: no soft enrage (the Last Count is gone)
	_tick_choir(delta)
	if _hymn:
		haste *= 1.2
	_tick_plates()
	_tick_falls(delta)
	_keep_on_floor()
	if _phase_change():
		return
	delta *= haste
	_reliq_t = maxf(0.0, _reliq_t - delta)
	weak_open = _reliq_t > 0.0
	if _ward_t > 0.0:
		return                              # reeling between phases: nothing new starts
	_busy = maxf(0.0, _busy - delta)
	for k: String in ["_tithe_t", "_spike_t", "_grave_t", "_sweep_t", "_requiem_t", "_cage_t", "_raise_t", "_toll_t", "_rain_t", "_reckon_t", "_choir_t"]:
		set(k, float(get(k)) - delta)
	if _busy > 0.0 or _p == null:
		return
	# the great rites, one at a time
	if not casting():
		if _choir_t <= 0.0 and phase in [2, 3]:
			_choir_t = 99.0
			_summon_choir()
			return
		if phase >= 3 and _requiem_t <= 0.0:
			_requiem_t = REQUIEM_EVERY if phase == 3 else 8.0
			_cage_t = maxf(_cage_t, 3.5)
			_requiem()
			_busy = 2.6
			_sig += 1
			return
		if _hall_ok() and _toll_t <= 0.0 and _plates.is_empty():
			_tolling()
			return
		if phase in [2, 3] and _reckon_t <= 0.0:
			_reckon_t = 34.0 if phase == 2 else 30.0
			_reckoning(3 if phase == 2 else 4)
			if phase == 2:
				_sig += 1
			return
		if phase in [2, 3] and _raise_t <= 0.0 and can_cast():
			_raise_t = RAISE_EVERY if phase == 2 else 30.0
			_grave_t = maxf(_grave_t, RAISE_TIME + 0.5)
			_raise_faithful()
			return
	# the lesser ones
	if phase >= 2 and _rain_t <= 0.0:
		_rain_t = [0.0, 0.0, 15.0, 13.0, 9.0][phase]
		_bone_rain()
		return
	if phase >= 3:
		if _cage_t <= 0.0 and _dist < 18.0:
			_cage_t = CAGE_EVERY if phase == 3 else 9.0
			_cage()
		elif _sweep_t <= 0.0 and _sweep_ready():
			_sweep()
		return
	if phase == 1 and _spike_t <= 0.0:
		_spike_t = 9.0
		if _rig and _rig.has_method("telegraph"):
			_rig.call("telegraph", 1.0)
		BossKit.cast(self, "Ossuary Ring", 1.1)
		BossKit.zone(get_parent(), global_position, 1.1, 28.0, {"by": self, "radius": 6.5, "color": BossKit.BONE, "spikes": "bone"})
		_grave_t = maxf(_grave_t, 2.0)
		_sig += 1
	elif _sweep_t <= 0.0 and _sweep_ready():
		_sweep()
	elif phase == 2 and _tithe_t <= 0.0 and _dist > 5.0 and _dist < 19.0:
		_tithe_t = TITHE_EVERY
		_grave_t = maxf(_grave_t, 1.8)
		_tithe()
	elif _grave_t <= 0.0 and _dist < 22.0:
		_grave_t = 5.0 if phase == 1 else 4.5
		_grave_spikes()
		if phase == 2:
			_sig += 1


## Thresholds: I -> the mound (or straight to II with no hall), II -> III, III -> IV. True on the
## frame a change begins (nothing else starts that frame).
func _phase_change() -> bool:
	var r := hp / float(max_hp)
	if phase == 1 and _inter == 0 and r <= INTER_AT:
		if _hall_ok() and not (_hall.get("sockets") as Array).is_empty():
			_begin_intermission()
		else:
			_inter = 2
			_rise_phase_two(0)
		return true
	if phase == 2 and r <= P3_AT:
		phase = 3
		_sig = 0
		_end_plates(false)
		BossKit.transition(self, "The Abbot counts you among the faithful. The floor remembers its dead: keep to the stone that stands.", GRAVE_FIRE, 1.6)
		_requiem_t = 8.0
		_cage_t = 6.0
		_toll_t = maxf(_toll_t, 16.0)
		_rain_t = 10.0
		_reckon_t = 22.0
		_raise_t = 18.0
		_choir_t = 25.0 if _choir_calls < 2 else 99.0
		_spike_t = 99.0
		if _hall_ok():
			for i in Hall.FALL_III.size():
				_falls.append([int(Hall.FALL_III[i]), 1.8 + 3.5 * float(i / 2)])
		return true
	if phase == 3 and r <= BURN_AT:
		phase = 4
		_sig = BossKit.SIG_NEEDED              # no ward in the burn
		_end_plates(false)
		BossKit.transition(self, "\"Eleven thousand and four.\" The count is finished, or you are. He wards himself no longer.", BossKit.RAGE, 1.4)
		_requiem_t = 5.0
		_rain_t = 4.0
		_toll_t = maxf(_toll_t, 10.0)
		_choir_t = 99.0
		_reckon_t = 99.0
		_raise_t = 99.0
		if _hall_ok():
			for s: int in Hall.FALL_IV:
				_falls.append([s, 1.5])
		return true
	return false


# --- the intermission: The Count Is Taken -------------------------------------------------------

func _begin_intermission() -> void:
	_inter = 1
	_end_plates(false)
	BossKit.transition(self, "\"One thousand and ninety. One thousand and ninety-one.\" The Abbot sinks into his dead. Break the three Tallies.", GRAVE_FIRE, 1.6)
	var it := INTER_TIME - (10.0 if _attuned else 0.0)
	_inter_t = it + 1.6
	_wave_t = 4.0
	_waves = 0
	set_meta(&"phase_label", "THE COUNT IS TAKEN")
	set_meta(&"ward_hint", "break the three tallies")
	BossKit.cast(self, "The Count Is Taken", it + 1.6)
	BossKit.emote(self, "The Abbot sinks into the mound.")
	var eid := get_instance_id()
	get_tree().create_timer(1.4, false).timeout.connect(func() -> void:
		var me := instance_from_id(eid) as BoneAbbot
		if me != null and me.is_alive() and me._inter == 1:
			me._sink())


## Into the mound: untouchable, unseen; the Tallies rise in the chapels.
func _sink() -> void:
	cancel_moves()
	_combo_left = 0
	_set_state(RECOVER)
	remove_from_group(Groups.ENEMY)
	collision_layer = 0
	if _hp_bar:
		_hp_bar.visible = false
	if _weak:
		_weak.visible = false
	var top := Vector3(Hall.WC.x, OssFrame.ORIGIN.y + Hall.MOUND_TOP, Hall.WC.z)    # (MOUND_TOP is the hall's own height)
	SpellFx.rift_out(global_position)
	Vfx.burst(global_position + Vector3.UP * 2.0, Color(0.85, 0.8, 0.7), {"count": 60, "life": 1.0, "speed": Vector2(2.0, 6.0), "size": 0.08, "gravity": -9.0, "additive": false})
	global_position = top
	velocity = Vector3.ZERO
	reset_physics_interpolation()
	if _visual:
		var tw := create_tween()
		tw.tween_property(_visual, "position:y", -7.0, 1.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(func() -> void: _visual.visible = false)
	Vfx.burst(top + Vector3.UP * 0.5, GRAVE, {"count": 50, "life": 1.4, "speed": Vector2(1.0, 4.0), "size": 0.06, "gravity": 1.0, "radius": 2.0, "turbulence": true})
	Sfx.play_stream(Synth.get_stream("chant"), top + Vector3.UP * 2.0, 4.0, 0.55)
	var bid := String(get_meta(&"boss_id", ""))
	_tallies.clear()
	for sp: Vector3 in (_hall.get("sockets") as Array):
		var t := TallyScript.new() as Enemy
		t.set_meta(&"summoned_by", bid)
		get_parent().add_child(t)
		t.global_position = sp
		t.set("feed_to", top + Vector3.UP * 0.6)
		t.wake()
		SpellFx.rift_in(sp)
		_tallies.append(t)
	Events.toast.emit("The Tallies feed him from the chapels.")


func _tallies_left() -> int:
	var n := 0
	for t in _tallies:
		if is_instance_valid(t) and t.is_alive():
			n += 1
	return n


func _intermission(delta: float) -> void:
	_inter_t -= delta
	_wave_t -= delta
	var left := _tallies_left()
	if _wave_t <= 0.0 and _inter_t > 4.0:
		_wave_t = WAVE_EVERY
		_waves += 1
		var at := Hall.WC
		var bid := String(get_meta(&"boss_id", ""))
		var cap := left + 4 + _choir_count()
		var per := 1 if _attuned else 2
		if _waves % 2 == 1:
			var w := BossKit.add_wave(self, Wretch, at, per, cap, "the Uncounted", 5.5)
			_mark_adds(w, bid)
		else:
			var o := BossKit.add_wave(self, Ossuant, at, per, cap, "Risen Faithful", 5.5)
			_mark_adds(o, bid)
		Sfx.play_stream(Synth.get_stream("bone"), at + Vector3.UP * 3.0, 4.0, 0.6)
		HitText.pop(at + Vector3.UP * 6.5, "the dead climb out", BossKit.BONE)
	if left == 0 and _inter_t < INTER_TIME:
		_end_intermission(0)
	elif _inter_t <= 0.0:
		_end_intermission(left)


func _mark_adds(adds: Array, _bid: String) -> void:
	for a in adds:
		(a as Enemy).set_meta(&"abbot_add", true)


## Out of the mound into phase II. `fed`: Tallies still standing (each heals him TALLY_HEAL).
func _end_intermission(fed: int) -> void:
	if _inter != 1:
		return
	_inter = 2
	remove_meta(&"phase_label")
	remove_meta(&"ward_hint")
	if casting():
		_finish_cast(false, false)
	for t in _tallies:
		if is_instance_valid(t) and t.is_alive():
			Vfx.arc(t.global_position + Vector3.UP * 1.6, global_position + Vector3.UP * 1.0, GRAVE, 0.5, 0.3)
			t.queue_free()
	_tallies.clear()
	add_to_group(Groups.ENEMY)
	collision_layer = Layers.HURTBOX | Layers.PROPS
	if _visual:
		_visual.visible = true
		var tw := create_tween()
		tw.tween_property(_visual, "position:y", 0.0, 1.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# he climbs down off the mound to its foot on the side away from you
	var c := Hall.WC
	var away := Vector3(c.x, 0, c.z) - (Vector3(_p.global_position.x, 0, _p.global_position.z) if _p else Vector3(c.x + 1.0, 0, c.z))
	away = away.normalized() if away.length() > 0.1 else Vector3.RIGHT
	global_position = Vector3(c.x, c.y + 0.1, c.z) + away * (Hall.MOUND_R + 1.6)
	velocity = Vector3.ZERO
	reset_physics_interpolation()
	if _hp_bar:
		_hp_bar.visible = true
	if fed > 0:
		hp = minf(float(max_hp), hp + float(max_hp) * TALLY_HEAL * float(fed))
		_refresh_hp(true)
		HitText.pop(global_position + Vector3.UP * (hp_bar_y + 1.0), "fed by %d %s" % [fed, "tally" if fed == 1 else "tallies"], GRAVE, true)
	_rise_phase_two(fed)


func _rise_phase_two(fed: int) -> void:
	phase = 2
	_sig = 0
	var line := "The Abbot rises from his dead, %s. His Choir takes up the hymn." % ("unfed" if fed == 0 else "fed")
	BossKit.transition(self, line, BossKit.BONE, 1.4)
	_spike_t = 99.0
	_choir_t = 1.6
	_reckon_t = 14.0
	_rain_t = 7.0
	_raise_t = 22.0
	_toll_t = maxf(_toll_t, 20.0)
	_tithe_t = 5.0


# --- the Choir --------------------------------------------------------------------------------------

func _choir() -> Array[Enemy]:
	var out: Array[Enemy] = []
	for n in get_tree().get_nodes_in_group(Groups.ENEMY):
		var e := n as Enemy
		if e and e.has_meta(&"abbot_choir") and e.is_alive() and e.get_meta(&"summoned_by", "") == get_meta(&"boss_id", "-"):
			out.append(e)
	return out


func _choir_count() -> int:
	return _choir().size()


## Hymn of the Choir: two chanters on the floor's edge, away from you. While one lives he takes half
## damage (the shroud) and every rite comes a fifth faster.
func _summon_choir() -> void:
	_choir_calls += 1
	BossKit.cast(self, "Hymn of the Choir", 1.4)
	if _rig and _rig.has_method("howl"):
		_rig.call("howl", 1.2)
	Sfx.play_stream(Synth.get_stream("chant"), global_position + Vector3.UP * 3.0, 4.0, 0.8)
	var bid := String(get_meta(&"boss_id", ""))
	var spots: Array[Vector3] = []
	var base := global_position
	var pa := 0.0
	if _p:
		pa = atan2(_p.global_position.z - base.z, _p.global_position.x - base.x)
	if _hall_ok():
		var c := Hall.WC
		base = c
		if _p:
			pa = atan2(_p.global_position.z - c.z, _p.global_position.x - c.x)
	for s: float in [-1.0, 1.0]:
		for tries in 6:
			var a := pa + PI + s * (0.9 + 0.25 * float(tries))
			var r := 15.0 if _hall_ok() else 9.0
			var at := base + Vector3(cos(a) * r, 0.0, sin(a) * r)
			if _hall_ok() and not bool(_hall.call("floor_under", at)):
				at = base + Vector3(cos(a) * 8.5, 0.0, sin(a) * 8.5)
			var f := _floor_at(at)
			if f != Vector3.INF:
				spots.append(f)
				break
	for sp in spots:
		var got := BossKit.summon(get_parent(), ChanterScript, sp, 1, 0.4, bid)
		for e in got:
			e.max_hp = CHOIR_HP
			e.hp = float(CHOIR_HP)
			e.set_meta(&"display_name", "Choir of the Count")
			e.set_meta(&"abbot_choir", true)
			e._refresh_hp(false)
			if e._hp_bar:
				e._hp_bar.set_instance_shader_parameter(&"segments", Enemy.hp_segments(CHOIR_HP))
			e._rally_t = 4.0
	if not spots.is_empty():
		BossKit.emote(self, "The Choir wards him while they sing. Silence them.")


func _tick_choir(delta: float) -> void:
	var was := _hymn
	var ch := _choir()
	_hymn = not ch.is_empty()
	if _hymn:
		_shroud_t = maxf(_shroud_t, 0.3)        # Enemy.take_hit: half damage while shrouded
		_hymn_fx -= delta
		if _hymn_fx <= 0.0:
			_hymn_fx = 0.6
			for e in ch:
				Vfx.arc(e.global_position + Vector3.UP * 1.6, global_position + Vector3.UP * hp_bar_y * 0.6, AttackKit.GLOAM, 0.35, 0.2)
		if not was:
			HitText.pop(global_position + Vector3.UP * (hp_bar_y + 1.2), "warded", AttackKit.GLOAM, true)
	elif was:
		_shroud_t = 0.0
		HitText.pop(global_position + Vector3.UP * (hp_bar_y + 1.2), "the hymn falters", WEAK_COL, true)


# --- the Tolling ------------------------------------------------------------------------------------

## He raises the crozier to the bell over your side of the hall; the floor fills, all but the
## sound-shadow behind the mound (and the mound's own foot). He stands while it rings.
func _tolling() -> void:
	_toll_t = [0.0, 26.0, 28.0, 24.0, 18.0][phase]
	_busy = TOLL_TIME + 0.4
	var c := Hall.WC
	var bells: Array = Hall.BELLS
	var pa := rad_to_deg(atan2(_p.global_position.z - c.z, _p.global_position.x - c.x))
	var bi := 0
	var best := 999.0
	var quarter := rad_to_deg(-OssFrame.YAW)                  # the hall's own angles, turned into the world's
	for i in bells.size():
		var d := absf(angle_difference(deg_to_rad(pa), deg_to_rad(float(bells[i]) + quarter)))
		if d < best:
			best = d
			bi = i
	var ba := deg_to_rad(float(bells[bi]) + quarter)
	var away := Vector3(-cos(ba), 0.0, -sin(ba))
	var hole := Vector3(c.x, c.y, c.z) + away * SHADOW_AT
	if _hall_ok():
		_hall.call("toll", bi)
	BossKit.cast(self, "The Tolling", TOLL_TIME)
	BossKit.emote(self, "He raises his crozier to the %s bell." % ["south", "west", "north", "east"][bi])
	BossKit.zone(get_parent(), Vector3(c.x, c.y, c.z), TOLL_TIME, TOLL_GLOOM, {"by": self, "radius": 27.5, "color": BossKit.BONE,
		"holes": [[hole, SHADOW_R], [Vector3(c.x, c.y, c.z), Hall.MOUND_R + 0.4]], "h": 3.0})
	SpellFx.column(hole, SHADOW_R * 0.8, 6.0, TOLL_TIME + 0.3)
	Vfx.ring(hole + Vector3.UP * 0.1, SHADOW_R, GRAVE, TOLL_TIME, 0.14, Vector3.UP, 1.4)
	Vfx.light(hole + Vector3.UP * 2.0, Color(GRAVE.r * 0.6, GRAVE.g * 0.6, GRAVE.b * 0.6), 2.4, SHADOW_R * 1.25, TOLL_TIME + 0.3)   # reaches the ring and stops
	Vfx.ring(Vector3(c.x, c.y + 0.1, c.z), Hall.MOUND_R + 0.4, GRAVE, TOLL_TIME, 0.14, Vector3.UP, 1.4)   # the mound's foot is safe too
	_glint = 1.0
	if _rig and _rig.has_method("howl"):
		_rig.call("howl", TOLL_TIME * 0.8)
	if _state != DEAD:
		_set_state(RECOVER)
		_state_t = -(TOLL_TIME - recover_time)
	if _hall_ok():
		var hall_id := _hall.get_instance_id()
		get_tree().create_timer(TOLL_TIME, false).timeout.connect(func() -> void:
			var h := instance_from_id(hall_id) as Node3D
			if h and is_instance_valid(self) and is_alive():
				Kit.play("bell_great", h.call("bell_at", bi), 8.0, 0.66))
	if phase == 1:
		_sig += 1


# --- Bone Rain -----------------------------------------------------------------------------------

## The vault lets go: three fields fill (one where you stand), bones crash down on them, and they
## stay foul with ossuary dust for a while.
func _bone_rain() -> void:
	BossKit.cast(self, "Bone Rain", RAIN_TIME + 5.0)     # the bar stays up while the dust can hurt
	if _rig and _rig.has_method("telegraph"):
		_rig.call("telegraph", 0.8)
	var under := _floor_at(_p.global_position)
	var spots: Array[Vector3] = [under if under != Vector3.INF else _p.global_position]
	for tries in 12:
		if spots.size() >= 3:
			break
		var a := randf() * TAU
		var q := _p.global_position + Vector3(cos(a), 0.0, sin(a)) * randf_range(6.5, 12.0)
		var ok := true
		for s in spots:
			if Vector2(s.x - q.x, s.z - q.z).length() < RAIN_R * 1.6:
				ok = false
		if _hall_ok() and not bool(_hall.call("floor_under", q)):
			ok = false
		var f := _floor_at(q) if ok else Vector3.INF
		if f != Vector3.INF:
			spots.append(f)
	for s in spots:
		var land := s
		BossKit.zone(get_parent(), land, RAIN_TIME, 26.0, {"by": self, "radius": RAIN_R, "color": BossKit.BONE})
		Vfx.burst(land + Vector3.UP * 14.0, Color(0.85, 0.8, 0.7), {"count": 26, "life": 1.6, "speed": Vector2(0.2, 1.0), "size": 0.12, "gravity": -9.0, "radius": RAIN_R * 0.8, "additive": false})
		for k in 3:                                      # the bones themselves, each carrying a pale light down
			var off := Vector3(randf_range(-RAIN_R, RAIN_R) * 0.6, 0.0, randf_range(-RAIN_R, RAIN_R) * 0.6)
			AttackKit.lob(land + off + Vector3.UP * 14.0, land + off + Vector3.UP * 0.3, RAIN_TIME, BossKit.BONE)
		get_tree().create_timer(RAIN_TIME, false).timeout.connect(func() -> void:
			if not is_instance_valid(self) or not is_alive():
				return
			Vfx.burst(land + Vector3.UP * 0.4, Color(0.85, 0.8, 0.7), {"count": 50, "life": 0.9, "speed": Vector2(2.0, 6.5), "size": 0.08, "gravity": -9.0, "radius": RAIN_R * 0.7, "additive": false})
			AttackKit.linger(land, RAIN_R - 0.6, 5.0, 4.0, 0.5, DUST))


# --- the Reckoning -----------------------------------------------------------------------------------

## He counts the living: `n` gold plates about the floor; step on each before the count ends. Each
## left uncounted raises a Risen Faithful there and costs SHORT_GLOOM.
func _reckoning(n: int) -> void:
	_end_plates(false)
	if _attuned:
		n = maxi(2, n - 1)                        # attuned: his count comes up short
	_reckon_n = n
	var c := global_position
	var lo := 5.5
	var hi := 11.0
	if _hall_ok():
		c = Hall.WC
		lo = Hall.MOUND_R + 2.4
		hi = Hall.FLOOR_R - 1.8
	var pp := _p.global_position
	for tries in 60:
		if _plates.size() >= n:
			break
		var a := randf() * TAU
		var q := c + Vector3(cos(a), 0.0, sin(a)) * randf_range(lo, hi)
		if Vector2(q.x - pp.x, q.z - pp.z).length() < 4.0:
			continue
		var ok := true
		for pl: Dictionary in _plates:
			if Vector2((pl.at as Vector3).x - q.x, (pl.at as Vector3).z - q.z).length() < 7.0:
				ok = false
		if not ok or (_hall_ok() and not bool(_hall.call("floor_under", q))):
			continue
		var f := _floor_at(q)
		if f != Vector3.INF:
			_plates.append({"at": f, "done": false})
	if _plates.is_empty():
		return
	BossKit.cast(self, _reckon_label(), RECKON_TIME, false, _reckoned)
	say("alert", global_position + Vector3.UP * 3.0, 3.0, 0.5)
	for pl: Dictionary in _plates:
		var at: Vector3 = pl.at
		Vfx.ring(at + Vector3.UP * 0.08, PLATE_R, BossKit.HOLY, RECKON_TIME, 0.12, Vector3.UP, 1.3)
		Vfx.light(at + Vector3.UP * 1.2, Color(0.9, 0.6, 0.25), 1.6, PLATE_R * 2.0, RECKON_TIME)
		SpellFx.column(at, PLATE_R * 0.55, 3.0, RECKON_TIME)
	BossKit.emote(self, "The Reckoning. He counts the living.")


func _reckon_label() -> String:
	var done := 0
	for pl: Dictionary in _plates:
		if pl.done:
			done += 1
	return "The Reckoning · %d of %d counted" % [done, _plates.size()]


func _tick_plates() -> void:
	if _plates.is_empty() or _p == null:
		return
	var pp := _p.global_position
	for pl: Dictionary in _plates:
		if pl.done:
			continue
		var at: Vector3 = pl.at
		if Vector2(pp.x - at.x, pp.z - at.z).length() <= PLATE_R + 0.2 and absf(pp.y - at.y) < 2.0:
			pl.done = true
			Vfx.burst(at + Vector3.UP * 0.5, BossKit.HOLY, {"count": 30, "life": 0.6, "speed": Vector2(1.0, 4.0), "size": 0.05, "gravity": -2.0})
			Vfx.ring(at + Vector3.UP * 0.1, PLATE_R + 0.4, BossKit.HOLY, 0.4, 0.1, Vector3.UP, 1.6)
			Kit.play("bell_treble", at + Vector3.UP, 0.0, 1.0)
			if casting() and cast_name.begins_with("The Reckoning"):
				cast_name = _reckon_label()
			HitText.pop(at + Vector3.UP * 2.2, "counted", BossKit.HOLY, true)


func _reckoned() -> void:
	_end_plates(true)


## The count ends: `judge` -- every plate not stood on raises one of the faithful and costs Gloom.
func _end_plates(judge: bool) -> void:
	if _plates.is_empty():
		return
	var short := 0
	var bid := String(get_meta(&"boss_id", ""))
	for pl: Dictionary in _plates:
		if pl.done or not judge:
			continue
		short += 1
		var at: Vector3 = pl.at
		Vfx.burst(at + Vector3.UP * 0.4, Color(0.85, 0.8, 0.7), {"count": 30, "life": 0.8, "speed": Vector2(1.5, 4.0), "size": 0.07, "gravity": -9.0, "additive": false})
		if is_inside_tree() and is_alive():
			var w := BossKit.add_wave(self, Ossuant, at, 1, 6 + _choir_count(), "Risen Faithful", 0.6)
			_mark_adds(w, bid)
	_plates.clear()
	if short > 0 and _p and is_alive():
		var cost := SHORT_GLOOM * float(short) * dmg_mult
		_p.take_wound(cost, global_position)
		HitText.pop(_p.global_position + Vector3.UP * 2.4, "the count is short by %d: %d on the plate" % [short, roundi(cost)], BossKit.BONE, true)
	elif judge and is_alive():
		HitText.pop(global_position + Vector3.UP * (hp_bar_y + 1.0), "all are counted", BossKit.HOLY, true)


# --- the floor -----------------------------------------------------------------------------------

func _tick_falls(delta: float) -> void:
	if _falls.is_empty() or not _hall_ok():
		return
	var keep: Array = []
	for f: Array in _falls:
		f[1] = float(f[1]) - delta
		if float(f[1]) <= 0.0:
			if bool(_hall.call("collapse", int(f[0]), 4.0)) and int(_hall.call("fallen_count")) in [1, 5]:
				BossKit.emote(self, "The floor gives way into the Uncounted Deep.")
		else:
			keep.append(f)
	_falls = keep


## Over a fallen sector he is set back on stone (he does not chase you into the deep).
func _keep_on_floor() -> void:
	if not _hall_ok() or phase < 3 or _inter == 1:
		return
	if bool(_hall.call("floor_under", global_position)):
		return
	var c := Hall.WC
	var a := atan2(global_position.z - c.z, global_position.x - c.x)
	var r := Hall.INNER_R - 0.6
	global_position = Vector3(c.x + cos(a) * r, global_position.y, c.z + sin(a) * r)
	velocity = Vector3.ZERO


# --- r29-r33 moves (scaled to the hall) -------------------------------------------------------------

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
		BossKit.zone(get_parent(), s, 1.1, 22.0, {"by": self, "radius": 2.0, "color": BossKit.BONE, "spikes": "bone"})
	Vfx.burst(global_position + Vector3.UP * hp_bar_y * 0.6, Color(1.4, 0.6, 2.6), {"count": 20, "life": 0.5, "speed": Vector2(1.0, 3.0), "size": 0.05, "gravity": 1.0})


## The crozier: only when you stand in front of it, inside its reach.
func _sweep_ready() -> bool:
	if _p == null or _dist > 7.0 or _face == null or _state == WINDUP or _state == STRIKE:
		return false
	var fwd := -_face.global_basis.z
	fwd.y = 0.0
	return fwd.normalized().dot(_to / maxf(_dist, 0.001)) > 0.2


func _sweep() -> void:
	_sweep_t = SWEEP_EVERY
	var yaw := atan2(-_to.x, -_to.z)
	_face_dir = _to / maxf(_dist, 0.001)
	if _rig and _rig.has_method("telegraph"):
		_rig.call("telegraph", 1.05)
	_glint = 1.0
	say("windup", global_position + Vector3.UP * 2.0, 3.0, 0.6)
	BossKit.cast(self, "Crozier Sweep", 1.05)
	BossKit.zone(get_parent(), global_position, 1.05, 30.0, {"by": self, "radius": 7.5, "half_angle": deg_to_rad(75.0), "yaw": yaw, "color": BossKit.BONE})
	get_tree().create_timer(1.05, false).timeout.connect(func() -> void:
		if is_instance_valid(self) and is_alive() and _rig and _rig.has_method("strike"):
			_rig.call("strike"))


## Three rings of bone outward from it, landing in turn; each ring's gaps sit where the last
## ring's discs were. Then two pools of grave-fire drip from the reliquary.
func _requiem() -> void:
	_reliq_t = 2.4
	_reliq_hits = 0
	BossKit.cast(self, "Requiem", 3.0, true)       # up until the last drip has landed
	if _rig and _rig.has_method("howl"):
		_rig.call("howl", 2.2)
	_glint = 1.0
	Sfx.play_stream(Synth.get_stream("chant"), global_position + Vector3.UP * 2.5, 3.0, 0.6)
	var c := global_position
	var radii := [3.4, 6.5, 9.6]
	var counts := [7, 12, 18]
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
			BossKit.zone(get_parent(), at, float(delays[k]), 24.0, {"by": self, "radius": 1.5, "color": BossKit.BONE, "spikes": "bone" if k < 2 or i % 2 == 0 else ""})
	for i in 2:
		var a := randf() * TAU
		var spot := _floor_at(c + Vector3(cos(a), 0.0, sin(a)) * randf_range(4.5, 9.0))
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
	var n := int(clampf((to.length() + 3.0) / 2.0, 4.0, 11.0))
	if _rig and _rig.has_method("telegraph"):
		_rig.call("telegraph", 0.75 + 0.16 * float(n - 1))      # the arms stay up for the whole line
	_face_dir = dir
	_glint = 1.0
	Sfx.play_stream(Synth.get_stream("spike"), global_position + Vector3.UP, 0.0, 0.7)
	BossKit.cast(self, "Tithe Line", 0.75 + 0.16 * float(n - 1))
	for i in n:
		var at := _floor_at(global_position + dir * (3.0 + 2.0 * float(i)))
		if at == Vector3.INF:
			continue
		BossKit.zone(get_parent(), at, 0.75 + 0.16 * float(i), 22.0, {"by": self, "radius": 1.5, "color": BossKit.BONE, "spikes": "bone"})
		get_tree().create_timer(0.75 + 0.16 * float(i), false).timeout.connect(func() -> void:
			if not (is_instance_valid(self) and is_alive()):
				return
			var r: Variant = _rig                                              # HunchRig or ClipRig: both strike
			if r != null:
				r.strike())                                # the crozier meets each spike


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
	Vfx.ring(global_position + Vector3.UP * 0.1, 5.0, GRAVE_FIRE, RAISE_TIME, 0.06, Vector3.UP, 1.0)


func _raised() -> void:
	_reliq_t = 0.0
	var w := BossKit.add_wave(self, Ossuant, global_position, 1 if _attuned else 2, 4 + _choir_count(), "Risen Faithful", 4.4)
	_mark_adds(w, "")
	HitText.pop(global_position + Vector3.UP * (hp_bar_y + 1.0), "the faithful rise", BossKit.BONE)


func _break_song() -> void:
	_reliq_t = 0.0
	weak_open = false
	cancel_moves()
	stagger()
	_broken_t = BOSS_BROKEN
	_busy = 0.0
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
		var at := _floor_at(c + Vector3(cos(a), 0.0, sin(a)) * 3.0)
		if at != Vector3.INF:
			BossKit.zone(get_parent(), at, 1.0, 20.0, {"by": self, "radius": 1.2, "color": BossKit.BONE, "spikes": "bone"})
	BossKit.zone(get_parent(), c, 1.6, 26.0, {"by": self, "radius": 2.3, "color": GRAVE_FIRE, "spikes": "bone"})
	Vfx.arc(global_position + Vector3.UP * hp_bar_y * 0.6, c + Vector3.UP * 0.5, GRAVE_FIRE, 0.3, 0.3)


func _floor_at(p: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 3.0, p + Vector3.DOWN * 5.0, Layers.WORLD))
	return (hit.position as Vector3) if not hit.is_empty() else Vector3.INF


func voice_family() -> String:
	return "abbot"
