extends Node
## The game's events as sound. Everything the rework adds that happens *because of* something (a blow, a cast, a fire, a boss, the
## eclipse) is wired here, once, so no gameplay script grows an audio call and every cue is throttled in one place.
##   combat   a crit's shimmer, a school's colour under the hit (ember crackle, umbral swell, light chime), a kill's low flourish
##   the body the wanderer's own hurt (weight by the blow), the gloom's heartbeat as it fills past 80%, being hollowed (a defeat)
##   tells    an interruptible wind-up rises bright, an unbreakable one rises low, a broken cast snaps
##   fires    a kindled fire breathes in; a beacon tower roars once (a horn, a bell, a choir) and the music steps back for it
##   items    a pickup's pluck, the ash's grain; a quest step's tick
##   bosses   each great one's intro on engage, a cue as its phase turns, its death and the stinger after it (the act's bell peal for
##            the three of the story, a plainer one for the rest); the music and beds duck under every stinger
##   night    the eclipse's three cues (the approach, the totality, the return; the score falls silent in the totality), moths
##            fluttering at the lit fire the wanderer stands near, fog breathing across the fen's low ground
##   camp     the rite's settling pad and its dawn bell (CampRite, found as it enters the tree)
## No class_name.

const CueBank := preload("res://core/audio/cue_bank.gd")
const MixDirector := preload("res://core/audio/mix_director.gd")
const Soundstage := preload("res://core/audio/soundstage.gd")
const Reg := preload("res://core/world/night_life/night_registry.gd")
const ScoreDirector := preload("res://core/audio/score_director.gd")

const FOG_SCAPES := ["fen", "tally", "mere", "reedmere", "stillwater", "nave", "sorrow"]
const MAIN_BOSSES := ["thornwarden", "bone_abbot", "ascended_warden"]

var ambience: Ambience
var stage: Node

var _last := {}                     ## throttle key -> msec
var _boss: Node = null
var _boss_id := ""
var _boss_phase := 0
var _room := ""
var _fight := false
var _e_state := 0                   ## 0 none, 1 warned, 2 totality, 3 returned
var _tick := 0.0
var _moth_t := 4.0
var _fog_t := 50.0
var _braziers: Array = []
var _scan_t := 0.0
var _heart_t := 0.0
var _detail_t := 20.0
var _gloom_k := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 8821
	Events.combat_damage.connect(_on_damage)
	Events.enemy_killed.connect(_on_killed)
	Events.player_hurt.connect(_on_hurt)
	Events.enemy_cast_started.connect(_on_cast)
	Events.enemy_cast_ended.connect(_on_cast_end)
	Events.brazier_kindled.connect(_on_kindled)
	Events.item_gained.connect(_on_item)
	Events.quest_changed.connect(_on_quest)
	Events.boss_engaged.connect(_on_boss)
	Events.boss_slain.connect(_on_slain)
	Events.hollowed.connect(_on_hollowed)
	Events.gloom_tide.connect(_on_tide)
	Events.proc_triggered.connect(_on_proc)
	Events.toast.connect(_on_toast)
	Events.gloom_changed.connect(func(v: float, m: float) -> void: _gloom_k = v / maxf(m, 0.001))
	get_tree().node_added.connect(_on_node)


## False when the same key sounded less than `gap` seconds ago (and stamps it otherwise).
func _gate(key: String, gap: float) -> bool:
	var now := Time.get_ticks_msec()
	if now - int(_last.get(key, -100000)) < int(gap * 1000.0):
		return false
	_last[key] = now
	return true


func _player() -> Node3D:
	return get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D


func _mix() -> MixDirector:
	return get_tree().get_first_node_in_group(&"mix_director") as MixDirector


# --- combat --------------------------------------------------------------------------------------------

func _on_damage(_target: Node, amount: float, crit: bool, school: StringName, at: Vector3) -> void:
	if not at.is_finite():
		return
	if crit and _gate("crit", 0.12):
		CueBank.play_at("crit_shimmer", at, 0.0)
	var cue := ""
	match school:
		&"ember":
			cue = "school_ember"
		&"umbral":
			cue = "school_umbral" if amount >= 8.0 else ""
		&"light":
			cue = "school_light"
	if cue != "" and _gate("school_" + cue, 0.16):
		CueBank.play_at(cue, at, clampf(linear_to_db(maxf(amount, 1.0) / 12.0), -6.0, 3.0))


## Lines the world seat's places say through the toast are heard as well: a Wardens' beacon catching rings its horn, the last one lights the Line.
func _on_toast(text: String) -> void:
	if text.begins_with("The beacon catches") and _gate("wbeacon", 1.0):
		var pl := _player()
		if pl != null:
			CueBank.play_at("beacon_light", pl.global_position + Vector3.UP * 3.0, -2.0)
	elif text.begins_with("The last beacon takes") or text.begins_with("The Line burns"):
		CueBank.play(self, "stinger_victory", -2.0)


## A parry rings, a dodge is cloth on the air, a riposte shimmers: the wanderer's own reads, under the library takes.
func _on_proc(_id: StringName, reason: StringName) -> void:
	var pl := _player()
	if pl == null:
		return
	match reason:
		&"parry":
			if _gate("parry", 0.15):
				CueBank.play_at("parry_spark", pl.global_position + Vector3.UP * 1.2, 0.0)
		&"dodge":
			if _gate("dodge", 0.15):
				CueBank.play_at("dodge_cloth", pl.global_position + Vector3.UP, 0.0)
		&"riposte":
			if _gate("riposte", 0.15):
				CueBank.play_at("crit_shimmer", pl.global_position + Vector3.UP * 1.4, -2.0)


func _on_killed(enemy: Node) -> void:
	if enemy is Node3D and _gate("kill", 0.3):
		CueBank.play_at("kill_flourish", (enemy as Node3D).global_position + Vector3.UP, 0.0)


func _on_hurt(amount: float, _from: Vector3) -> void:
	if _gate("hurt", 0.3):
		var cue := "hurt_light" if amount < 6.0 else ("hurt_body" if amount < 18.0 else "hurt_heavy")
		CueBank.play(self, cue, clampf(-10.0 + amount * 0.15, -10.0, -2.0))       # under the wanderer's own hurt take: it adds weight, it does not repeat it


func _on_cast(enemy: Node, _cast: String, _time: float, interruptible: bool) -> void:
	if not enemy is Node3D or not _gate("tell_%d" % enemy.get_instance_id(), 0.8):
		return
	var at := (enemy as Node3D).global_position + Vector3.UP * 1.4
	CueBank.play_at("tell_windup" if interruptible else "tell_heavy", at, 0.0)



func _on_cast_end(enemy: Node, _cast: String, interrupted: bool) -> void:
	if interrupted and enemy is Node3D and _gate("tellbreak", 0.2):
		CueBank.play_at("tell_break", (enemy as Node3D).global_position + Vector3.UP * 1.4, 0.0)


# --- fires, items, the story ---------------------------------------------------------------------------

func _on_kindled(b: Node3D) -> void:
	if b == null or not is_instance_valid(b):
		return
	var nm := (String(b.name) + String(b.get_meta(&"map_label", ""))).to_lower()
	if nm.contains("beacon") or nm.contains("spire"):
		CueBank.play_at("beacon_light", b.global_position + Vector3.UP * 2.0, 0.0)
		var md := _mix()
		if md != null:
			md.stinger(-9.0, -6.0, 3.0, 2.5)
	else:
		CueBank.play_at("kindle_breath", b.global_position + Vector3.UP * 0.6, 0.0)


func _on_item(id: String, amount: int, _total: int) -> void:
	if amount > 0 and _gate("item", 0.12):
		CueBank.play(self, "ash_gain" if id.contains("ash") else "pickup", 0.0)


func _on_quest(_id: String, step: int, done: bool) -> void:
	if not done and step > 0 and _gate("qstep", 0.6):
		CueBank.play(self, "quest_step", 0.0)


# --- the great ones -------------------------------------------------------------------------------------

func _on_boss(b: Node, _title: String) -> void:
	_boss = b
	_boss_id = String(b.get_meta(&"boss_id", "")) if b != null else ""
	_boss_phase = int(b.get("phase")) if b != null and "phase" in b else 0
	if _boss_id != "" and CueBank.has("boss_%s_intro" % _boss_id):
		CueBank.play(self, "boss_%s_intro" % _boss_id, 0.0)


func _on_slain(id: String) -> void:
	if CueBank.has("boss_%s_death" % id):
		CueBank.play(self, "boss_%s_death" % id, 0.0)
	get_tree().create_timer(2.4, true).timeout.connect(func() -> void:
		CueBank.play(self, "stinger_act" if MAIN_BOSSES.has(id) else "stinger_victory", 0.0))
	var md := _mix()
	if md != null:
		md.stinger(-14.0, -9.0, 6.0, 3.0)
	_boss = null
	_boss_id = ""


func _on_hollowed() -> void:
	CueBank.play(self, "stinger_defeat", 0.0)
	var md := _mix()
	if md != null:
		md.stinger(-12.0, -8.0, 3.0, 3.0)


func _on_tide(on: bool) -> void:
	if on:
		CueBank.play(self, "tell_heavy", 3.0)
		var md := _mix()
		if md != null:
			md.duck_ambience(-5.0, 4.0, 3.0)


# --- the night ------------------------------------------------------------------------------------------

func _on_node(n: Node) -> void:
	if n is CampRite:
		CueBank.play(self, "camp_begin", 0.0)
		(n as CampRite).ended.connect(func(rested: bool) -> void:
			if rested:
				CueBank.play(self, "camp_end", 0.0))


func _process(dt: float) -> void:
	# the gloom's heart: past 80% it beats, faster and louder as it fills
	if _gloom_k > 0.8:
		_heart_t -= dt
		if _heart_t <= 0.0:
			_heart_t = 1.5 - _gloom_k * 0.6
			CueBank.play(self, "gloom_heart", -8.0 + (_gloom_k - 0.8) * 40.0)
	_tick -= dt
	if _tick > 0.0:
		return
	_tick = 0.25
	_poll_boss()
	_poll_fight()
	_poll_eclipse()
	_poll_room()
	_moths(0.25)
	_fog(0.25)
	_details(0.25)


## Crossing into a room (the tavern, a hall, a cave, a crypt) is a door: a creak and a latch behind, the other way a thud.
func _poll_room() -> void:
	if ambience == null:
		return
	var z := ambience.reverb_zone
	if z == _room:
		return
	var was := _room
	_room = z
	var pl := _player()
	if pl == null or was == "rift" or z == "rift" or not _gate("door", 2.0):
		return
	if z != "":
		CueBank.play_at("door_open", pl.global_position + Vector3.UP, -6.0, 1.0 if z == "tavern" else 0.8)
	else:
		CueBank.play_at("door_close", pl.global_position + Vector3.UP, -6.0, 1.0 if was == "tavern" else 0.8)


## A fight ducks the ambience a little (the beds step back so the blows read), and lets it back a few seconds after.
func _poll_fight() -> void:
	var sd := get_tree().get_first_node_in_group(&"score_director") as ScoreDirector
	var fighting := sd != null and sd.combat > 0.5
	if fighting and not _fight and _gate("fightduck", 5.0):
		var md := _mix()
		if md != null:
			md.duck_ambience(-3.0, 6.0, 3.0)
	_fight = fighting


func _poll_boss() -> void:
	if _boss == null or not is_instance_valid(_boss) or not "phase" in _boss:
		return
	var ph := int(_boss.get("phase"))
	if ph != _boss_phase:
		var was := _boss_phase
		_boss_phase = ph
		if was > 0 and ph > was and CueBank.has("boss_%s_phase" % _boss_id):
			CueBank.play(self, "boss_%s_phase" % _boss_id, 0.0)


func _poll_eclipse() -> void:
	if not Reg.enabled:
		return
	var e := Soundstage.eclipse_amount(Reg.clock)
	if _e_state == 0 and e > 0.03:
		_e_state = 1
		CueBank.play(self, "eclipse_warn", 0.0)
	elif _e_state == 1 and e >= 0.99:
		_e_state = 2
		CueBank.play(self, "eclipse_total", 0.0)
		var sd := get_tree().get_first_node_in_group(&"score_director") as ScoreDirector
		if sd != null:
			sd.silence(10.0)
		var md := _mix()
		if md != null:
			md.duck_ambience(-8.0, 9.0, 4.0)
	elif _e_state == 2 and e < 0.9:
		_e_state = 3
		CueBank.play(self, "eclipse_return", 0.0)


## Moths at a fire the wanderer stands near: a dry flicker of wings from the flame's height every few seconds.
func _moths(dt: float) -> void:
	_moth_t -= dt
	if _moth_t > 0.0:
		return
	_moth_t = _rng.randf_range(3.0, 7.0)
	var pl := _player()
	if pl == null:
		return
	_scan_t -= 1.0
	if _scan_t <= 0.0:
		_scan_t = 8.0
		_braziers.clear()
		for n: Node in get_tree().get_nodes_in_group(Groups.INTERACTABLE):
			if n is Brazier:
				_braziers.append(n)
	for b: Variant in _braziers:
		if is_instance_valid(b) and bool((b as Brazier).lit) and (b as Node3D).global_position.distance_to(pl.global_position) < 10.0:
			var off := Vector3(_rng.randf_range(-0.8, 0.8), _rng.randf_range(0.8, 1.8), _rng.randf_range(-0.8, 0.8))
			CueBank.play_at("moth_flutter", (b as Node3D).global_position + off, 0.0, _rng.randf_range(0.9, 1.15))
			return


## Small things by the hour and the region: a dawn chorus in the last tenth of the night, owls in its late hours, and by place a
## shutter, a far chime, a rockfall, bones settling, a gust. Never in a fight, the eclipse's totality or a heavy gloom.
func _details(dt: float) -> void:
	_detail_t -= dt
	if _detail_t > 0.0:
		return
	var c := Reg.clock
	var dawn := c > 0.9
	_detail_t = _rng.randf_range(5.0, 11.0) if dawn else _rng.randf_range(14.0, 32.0)
	var pl := _player()
	if pl == null or ambience == null or _gloom_k > 0.5 or _e_state == 2:
		return
	var sd := get_tree().get_first_node_in_group(&"score_director") as ScoreDirector
	if sd != null and (sd.combat > 0.1 or sd.tension > 0.3):
		return
	var family := String(ScoreDirector.SCAPE_FAMILY.get(ambience.scape, "village"))
	var picks: Array = []
	if dawn and family != "crypt":
		picks = ["bird_a", "bird_b", "bird_c"]
	elif c > 0.55 and c < 0.88 and family in ["wood", "fen", "village"]:
		picks = ["owl_far", "owl_far", "wind_gust"]
	else:
		match family:
			"village":
				picks = ["shutter_creak", "chime_far", "wind_gust"]
			"wood":
				picks = ["stone_tick", "wind_gust", "owl_far"]
			"fen":
				picks = ["wind_gust", "chime_far", "owl_far"]
			"heights":
				picks = ["rockfall_far", "wind_gust", "stone_tick"]
			"crypt":
				picks = ["bone_settle", "stone_tick", "chime_far"]
	if picks.is_empty():
		return
	var cue := String(picks[_rng.randi() % picks.size()])
	var n := _rng.randi_range(2, 3) if dawn and cue.begins_with("bird") else 1
	for i in n:
		var a := _rng.randf() * TAU
		var d := _rng.randf_range(12.0, 30.0)
		var at := pl.global_position + Vector3(cos(a) * d, _rng.randf_range(0.6, 5.0), sin(a) * d)
		get_tree().create_timer(0.4 + 0.7 * float(i) + _rng.randf() * 0.4, true).timeout.connect(func() -> void: CueBank.play_at(cue, at, 0.0, _rng.randf_range(0.92, 1.1)))


## Fog breathing over the fen's low ground (the drifting banks of night_life/fog_banks.gd): a long soft breath off to one side.
func _fog(dt: float) -> void:
	_fog_t -= dt
	if _fog_t > 0.0:
		return
	_fog_t = _rng.randf_range(45.0, 80.0)
	var pl := _player()
	if pl == null or ambience == null or not FOG_SCAPES.has(ambience.scape):
		return
	var a := _rng.randf() * TAU
	CueBank.play_at("fog_breath", pl.global_position + Vector3(cos(a), 0.4, sin(a)) * 16.0, 0.0, _rng.randf_range(0.85, 1.1))
