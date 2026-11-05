extends Node
## The generative music layer (life system r28): no tracks, only a few synthesised voices
## (scape_synth.gd: a plucked lyre, a soft bell, two pads, a low heartbeat) played by rules, so it is
## never the same twice and never loops audibly. It sits well under the beds and answers the night:
##   rest     by a lit brazier or in the tavern, nobody hostile near: the warm pad swells and the
##            lyre plays slow phrases in D minor pentatonic (a random walk; phrases end on a dyad)
##   explore  the default: long silences, now and then a single lyre phrase or a low bell
##   danger   a hollowed thing within reach or a boss fight: the dark pad (a low cluster) comes in,
##            the lyre falls quiet but for the odd tritone, a heartbeat drum underneath
##   relief   the last enemy near you falls: one rising arpeggio that resolves to D
## Deterministic for a seed; Ambience owns it ("Music"). Everything on the Music bus (Ambience makes
## it; its level is the Music slider, or the Ambience slider until Settings has one).
## Load by path (no class_name).

const ScapeSynth := preload("res://core/life/wildlife/scape_synth.gd")

## the whole layer, relative to its voices' levels. Was -9: renders of real moments put the pads at
## -47..-50 dBFS and the lyre at -42 under beds at -25..-33, i.e. never heard (critique D, r29).
const DB := 3.0
const PENTA := [-7, -4, -2, 0, 3, 5, 8, 10, 12, 15]      ## D3 F3 G3 A3 C4 D4 F4 G4 A4 C5 (semitones from A3)
const DARK := [-7, -6, -1, 0, 6, 5]                      ## D3 Eb3 Ab3 A3 Eb4 D4
const DANGER_R := 20.0
const REST_R := 9.0

var state := "explore"
var intensity := 0.0              ## 0 calm .. 1 danger (eased; Ambience thins spot calls with it)
var rest_k := 0.0                 ## 0 .. 1 how restful (eased)
var notes_played := 0
var reliefs := 0
var boss := false
var forced := ""                  ## tests: force a state

var _rng := RandomNumberGenerator.new()
var _pad_rest: AudioStreamPlayer
var _pad_dark: AudioStreamPlayer
var _pulse: AudioStreamPlayer
var _voices: Array[AudioStreamPlayer] = []
var _vi := 0
var _t := 0.0
var _note_t := 6.0
var _phrase: Array = []           ## pending [delay, semitone, voice] notes
var _walk := 4
var _pulse_t := 0.0
var _danger_was := false
var _boss: Node = null
var _braziers: Array = []
var _scan_t := 0.0
var _seen := 0                    ## consecutive senses with something hostile near
var _clear := 0                   ## consecutive senses with nothing near
var near_names: Array = []        ## what made it danger (tests, debug)
## r33 world: each region plays in its own key (the explore and rest phrases shift by this many
## semitones; danger stays put), and finding a place answers with a short cue (WoW's zone-in sting).
const REGION_KEY := {"hearth": 0, "road": 0, "chapel": 2, "glade": 5, "thornwood": -2, "henge": -2, "fen": -4, "barrows": -4,
	"rift": -5, "ossuary": -5, "summit": 3, "crags": 3,
	# r34 flora: the new regions
	"quarry": 3, "holds": -2, "foundry": -5, "moor": 0, "orchard": -3, "necropolis": 2, "mere": -4}
var key := 0
var cues := 0                     ## tests


func _ready() -> void:
	_rng.seed = 2207
	_pad_rest = _player(ScapeSynth.stream("pad_rest"), "PadRest")
	_pad_dark = _player(ScapeSynth.stream("pad_dark"), "PadDark")
	_pulse = _player(ScapeSynth.stream("pulse"), "Pulse")
	for i in 4:
		_voices.append(_player(null, "Voice%d" % i))
	if Events.has_signal("boss_engaged"):
		Events.boss_engaged.connect(func(b: Node, _t2: String) -> void:
			_boss = b)
	if Events.has_signal("boss_slain"):
		Events.boss_slain.connect(func(_id: String) -> void:
			_boss = null)


func _player(s: AudioStream, nm: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.name = nm
	p.stream = s
	p.bus = &"Music" if AudioServer.get_bus_index("Music") >= 0 else &"Ambience"
	p.volume_db = -80.0
	add_child(p)
	return p


func _process(dt: float) -> void:
	_t -= dt
	if _t <= 0.0:
		_t = 0.5
		_sense()
	var danger := 1.0 if state == "danger" else 0.0
	intensity = move_toward(intensity, danger, dt / (2.0 if danger > intensity else 6.0))
	rest_k = move_toward(rest_k, 1.0 if state == "rest" else 0.0, dt / 5.0)
	_pad(_pad_rest, -27.0, rest_k * (1.0 - intensity), dt)
	_pad(_pad_dark, -25.0, intensity, dt)
	# the heartbeat under danger
	if intensity > 0.4:
		_pulse_t -= dt
		if _pulse_t <= 0.0:
			_pulse_t = 0.82 if boss else 1.05
			_pulse.volume_db = DB - 20.0 + linear_to_db(intensity)
			_pulse.play()
	# pending phrase notes, then the next phrase
	if not _phrase.is_empty():
		var n: Array = _phrase[0]
		n[0] = float(n[0]) - dt
		if float(n[0]) <= 0.0:
			_phrase.pop_front()
			_note(int(n[1]), String(n[2]), float(n[3]))
	else:
		_note_t -= dt
		if _note_t <= 0.0:
			_next_phrase()


func _pad(p: AudioStreamPlayer, top: float, g: float, _dt: float) -> void:
	if g <= 0.01:
		if p.playing:
			p.stop()
		return
	p.volume_db = DB + top + linear_to_db(g)
	if not p.playing:
		p.play(_rng.randf() * p.stream.get_length())


## What the wanderer is living through right now.
func _sense() -> void:
	var was := state
	if forced != "":
		state = forced
	else:
		var pl := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
		if pl == null:
			return
		var p := pl.global_position
		var near := 0
		near_names.clear()
		for e in get_tree().get_nodes_in_group(Groups.ENEMY):
			var n3 := e as Node3D
			# a camp asleep (process disabled until it wakes) behind the hill is no danger yet
			if n3 != null and n3.is_inside_tree() and n3.can_process() and n3.global_position.distance_to(p) < DANGER_R and not (n3 as Node).is_queued_for_deletion():
				near += 1
				near_names.append(String(n3.name))
		# a boss fight lasts while the boss stands within reach of you
		boss = _boss != null and is_instance_valid(_boss) and _boss.is_inside_tree() and not _boss.is_queued_for_deletion() \
			and _boss is Node3D and (_boss as Node3D).global_position.distance_to(p) < 60.0
		if not boss:
			_boss = null if _boss != null and not is_instance_valid(_boss) else _boss
		# hysteresis: a second of something near before the music turns, two of quiet before it lets go
		if near > 0:
			_seen += 1
			_clear = 0
		else:
			_clear += 1
			_seen = 0
		if boss or _seen >= 2 or (state == "danger" and _clear < 4):
			state = "danger"
		elif _resting(p):
			state = "rest"
		else:
			state = "explore"
	if was == "danger" and state != "danger":
		_relief()
	if state != was and state == "rest":
		_note_t = minf(_note_t, 2.0)


func _resting(p: Vector3) -> bool:
	if RealmLayout.TAVERN.has_point(Vector2(p.x, p.z)) and p.y < 6.0:
		return true
	_scan_t -= 0.5
	if _scan_t <= 0.0:
		_scan_t = 8.0
		_braziers.clear()
		for n in get_tree().get_nodes_in_group(Groups.INTERACTABLE):
			if n is Brazier:
				_braziers.append(n)
	for b in _braziers:
		if is_instance_valid(b) and bool((b as Brazier).lit) and (b as Node3D).global_position.distance_to(p) < REST_R:
			return true
	return false


func _next_phrase() -> void:
	match state:
		"rest":
			_phrase = _melody(_rng.randi_range(4, 7), 0.55, 1.3, "harp", 0.0)
			_note_t = _rng.randf_range(7.0, 14.0)
		"danger":
			if _rng.randf() < 0.5:
				var s: int = DARK[_rng.randi() % DARK.size()]
				_phrase = [[0.0, s, _bell_voice(), -6.0]]
			_note_t = _rng.randf_range(9.0, 16.0)
		_:
			var r := _rng.randf()
			if r < 0.45:
				_phrase = _melody(_rng.randi_range(3, 5), 0.8, 1.8, "harp", -3.0)
			elif r < (0.52 if _rung() else 0.7):
				_phrase = [[0.0, PENTA[_rng.randi_range(0, 4)], _bell_voice(), -5.0]]
			_note_t = _rng.randf_range(16.0, 34.0)


## The story saves the bell for its ending (story.gd rings one, once): until then the music's bell
## notes are plucked instead; afterwards the bell comes back, rarely.
static func _rung() -> bool:
	var f: Variant = Travel.story.get("flags", {})
	return f is Dictionary and bool((f as Dictionary).get("ending_seen", false))


func _bell_voice() -> String:
	return "bell" if _rung() else "harp"


## A phrase: a random walk over the scale, steps of at most two, ending on a dyad.
func _melody(n: int, gap_min: float, gap_max: float, voice: String, db: float) -> Array:
	var out: Array = []
	for i in n:
		_walk = clampi(_walk + _rng.randi_range(-2, 2), 0, PENTA.size() - 1)
		out.append([_rng.randf_range(gap_min, gap_max) if i > 0 else 0.0, PENTA[_walk], voice, db])
	var root: int = PENTA[clampi(_walk - 2, 0, PENTA.size() - 1)]
	out.append([0.04, root, voice, db - 4.0])
	return out


## The region the wanderer walked into (realm_discovery.gd): later phrases are in its key.
func set_region(id: String) -> void:
	key = int(REGION_KEY.get(id, 0))


## A place was found: a rising phrase in its key (big: a region, ending on a dyad and, after the
## ending, the bell; small: a named spot, three notes). Never over danger.
func cue_discovery(id: String, big: bool) -> void:
	if state == "danger":
		return
	if big:
		set_region(id)
	cues += 1
	var k := 0                                            # _note adds the region's key
	if big:
		_phrase = [[0.25, -7 + k, "harp", -1.0], [0.3, 0 + k, "harp", -1.0], [0.3, 5 + k, "harp", -1.5], [0.42, 8 + k, "harp", -2.0],
			[0.55, 12 + k, _bell_voice(), -3.0], [0.04, 5 + k, "harp", -5.0]]
	else:
		_phrase = [[0.2, 0 + k, "harp", -3.0], [0.24, 5 + k, "harp", -3.0], [0.3, 10 + k, "harp", -4.0]]
	_note_t = maxf(_note_t, 10.0)


func _relief() -> void:
	reliefs += 1
	_phrase = [[0.6, -7, "harp", -2.0], [0.35, 0, "harp", -2.0], [0.35, 5, "harp", -2.0], [0.35, 8, "harp", -3.0], [0.05, -7, "harp", -6.0]]
	_note_t = _rng.randf_range(12.0, 20.0)


func _note(semi: int, voice: String, db: float) -> void:
	var a := _voices[_vi]
	_vi = (_vi + 1) % _voices.size()
	a.stream = ScapeSynth.stream(voice)
	var base := 0 if voice == "harp" else 12              # bell sample is A4, harp A3
	if state != "danger":
		semi += key                                       # r33: the region's key
	a.pitch_scale = pow(2.0, float(semi - base) / 12.0)
	a.volume_db = DB - 15.0 + db - (intensity * 6.0 if voice == "harp" else 0.0)
	a.play()
	notes_played += 1
