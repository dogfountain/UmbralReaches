extends Node3D
## Small scenes at the Kindled Keg (tavern NPCs; no class_name). Added by Tavern._patrons with the
## patrons and the keep; group "keg_scenes". Every minute or so, while the wanderer is in or by the
## Keg, one of these plays (never the same twice running):
##   song      four or more seated regulars sing "The Keg Stays Lit": swaying, mugs up, each in his
##             own voice on the tune's notes (npc_voice syllables at the melody's pitch), a toast
##             and a laugh at the end
##   dice      a bench pair throws dice: shake, throw, two bone dice tumble on the board (clack),
##             one cheers and one groans, three throws
##   argue     a bench pair argues: raised voices, jabbing, fists on the board (thump), the keep
##             shouts them down, they laugh it off and toast
##   round     (bought at the keep's slate, play("round")) the room raises its mugs to the wanderer
## While the Gloom tide is up nobody sings: the room falls quiet and looks at the door.
## Overheard lines are subtitled (the dialogue box's narration) only when the wanderer is close
## and nothing else is being said. Cost: a 2 Hz check between scenes; a running scene steps its
## own small timeline (no physics, no new materials: the dice use the bone material).

const Voice := preload("res://core/npc/npc_voice.gd")
const RATE := 22050

## The tune: [semitones from the singer's pitch, beats]. Dorian, in the Keg's register.
const SONG := [[0, 1], [3, 1], [5, 1], [7, 2], [5, 1], [3, 1], [2, 2], [0, 1], [2, 1], [3, 1], [5, 2], [3, 1], [2, 1], [0, 3],
	[7, 1], [7, 1], [8, 1], [7, 2], [5, 1], [3, 1], [5, 2], [3, 1], [2, 1], [0, 1], [-2, 1], [0, 3]]
const BEAT := 0.42
const ARGUE := [
	["\"The bells stopped top first. I heard them go.\"", "\"Everything stops top first. Look at you.\""],
	["\"Edda never wore boots in her life.\"", "\"She wore my father's. He said so at her burying.\""],
	["\"Four thousand steps. I counted.\"", "\"You counted to forty and fell asleep.\""],
	["\"The Abbot was a fair man once.\"", "\"He was a fair counter. That's not the same thing.\""],
	["\"Hollows can't open a latch.\"", "\"Then who's been at the back keg?\""],
	["\"My father saw the Door open.\"", "\"Your father saw two of everything.\""],
	["\"The oaks moved last night. A yard. I paced it.\"", "\"You paced it drunk. It was you that moved.\""],
	["\"There's no such thing as a warm hollow.\"", "\"There's no such thing as a warm anything. Drink.\""],
]
const KEEP_SHOUT := ["\"Oi! Not in my Keg. Take it outside, where it's dark.\"", "\"Sit down, the pair of you, or I'm watering it.\""]
const DICE := ["\"Two skulls! Pay up.\"", "\"Loaded. They're loaded. Everything in this valley's loaded.\"",
	"\"Snake eyes. Again. The bones hate me.\"", "\"Double the stake. No? Coward.\"", "\"That's my ale you're betting.\""]

var patrons: Array = []                 ## DwarfNpc (Tavern sets them)
var keep: Node3D
var scene := ""                         ## the one playing now ("" none)
var played: Array[String] = []          ## every scene started (tests)
var _wait := 40.0
var _last := ""
var _t := 0.0
var _step := 0
var _cast: Array = []
var _rng := RandomNumberGenerator.new()
var _dice: Array[MeshInstance3D] = []
var _dice_v: Array[Vector3] = []
var _sfx: Dictionary = {}
var _poll := 0.0
var _tide := false


func _ready() -> void:
	add_to_group("keg_scenes")
	_rng.seed = 7341
	_wait = _rng.randf_range(25.0, 45.0)
	_sfx["clack"] = _make_clack()
	_sfx["thump"] = _make_thump()
	Events.gloom_tide.connect(_on_tide)


## The Gloom tide rises: the song stops, every face turns to the door; it breaks: a nervous laugh.
func _on_tide(on: bool) -> void:
	_tide = on
	if on and scene != "" and scene != "round":
		_finish()
	for d: Node in patrons:
		if _free(d):
			if on:
				_cue(d, "look", 6.0)
				d.set("_look_to", Vector2(clampf(_door_yaw(d as Node3D), -0.9, 0.9), 0.02))
			else:
				_cue(d, "laugh", 1.8)


func _door_yaw(d: Node3D) -> float:
	var l := d.to_local(Vector3(17.6, d.global_position.y + 1.2, 25.0))
	return atan2(-l.x, -l.z)


func _player() -> Node3D:
	return get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D


func _near(r := 24.0) -> bool:
	var p := _player()
	var c := Vector3(18.0, 0.0, 30.2)
	return p != null and Vector2(p.global_position.x - c.x, p.global_position.z - c.z).length() < r


func _free(d: Node) -> bool:
	return is_instance_valid(d) and not bool(d.get("away")) and d.get("attend") == null and not bool(d.get("speaking")) and String(d.get("_trip")) == ""


## Play a scene now ("song", "dice", "argue", "round"). false when it can't (no cast, one running).
func play(id: String) -> bool:
	if scene != "" and id != "round":
		return false
	if scene != "":
		_finish()
	_cast = _pick_cast(id)
	if _cast.is_empty():
		return false
	scene = id
	played.append(id)
	_last = id
	_t = 0.0
	_step = 0
	return true


func _pick_cast(id: String) -> Array:
	var free: Array = patrons.filter(func(d: Node) -> bool: return _free(d))
	match id:
		"song":
			var seated := free.filter(func(d: Node) -> bool: return bool(d.get("seated")))
			return seated if seated.size() >= 4 else []
		"dice", "argue":
			var pairs: Array = []
			for d: Node in free:
				var m: Variant = d.get("partner")
				if bool(d.get("leader")) and m != null and _free(m):
					pairs.append([d, m])
			if pairs.is_empty():
				return []
			return pairs[_rng.randi() % pairs.size()]
		"round":
			return free
	return []


func _process(delta: float) -> void:
	if scene != "":
		_t += delta
		match scene:
			"song":
				_song()
			"dice":
				_dice_step(delta)
			"argue":
				_argue()
			"round":
				_round()
		return
	_poll -= delta
	if _poll > 0.0:
		return
	_poll = 0.5
	_wait -= 0.5
	if _wait > 0.0:
		return
	_wait = _rng.randf_range(55.0, 95.0)
	if not _near() or _tide:
		return
	var opts: Array[String] = ["song", "dice", "argue"]
	opts.erase(_last)
	opts.shuffle()
	for id: String in opts:
		if play(id):
			return


func _finish() -> void:
	for d: MeshInstance3D in _dice:
		if is_instance_valid(d):
			d.queue_free()
	_dice.clear()
	_dice_v.clear()
	scene = ""
	_cast = []


func _bark(s: String, who: Node3D) -> void:
	var p := _player()
	if p == null or not is_instance_valid(who) or p.global_position.distance_to(who.global_position) > 7.5:
		return
	var story := get_tree().get_first_node_in_group("story")
	var ui: Variant = story.get("ui") if story else null
	if ui and is_instance_valid(ui) and not bool((ui as Object).call("is_open")) and not bool((ui as Object).call("narrating")):
		(ui as Object).call("narrate", [s])


func _voice_of(d: Node3D) -> Node:
	var v := d.get_node_or_null("Voice")
	if v == null:
		v = Voice.speaker3d(d, 22.0)
	return v


func _cue(d: Node, act: String, len: float) -> void:
	if is_instance_valid(d):
		d.call("cue", act, len)


# --- the song --------------------------------------------------------------------------------------

func _song() -> void:
	var total := 0.0
	for n: Array in SONG:
		total += float(n[1]) * BEAT
	if _step == 0:
		_step = 1
		for d: Node in _cast:
			_cue(d, "sing", total + 0.6)
		_bark("(They sing \"The Keg Stays Lit\". Badly, and with feeling.)", _cast[0])
	# which note is sounding
	var at := 0.0
	var idx := -1
	for i in SONG.size():
		var len := float(SONG[i][1]) * BEAT
		if _t >= at and _t < at + len:
			idx = i
			# held notes are re-voiced every half beat ("la-a-a")
			var sub := int((_t - at) / (BEAT * 0.5))
			idx = i * 16 + sub
			break
		at += len
	if idx >= 0 and idx != _step - 2:
		_step = idx + 2
		var ni := idx / 16
		var semi := float(SONG[ni][0])
		var cam := get_viewport().get_camera_3d()
		for k in _cast.size():
			var d: Node3D = _cast[k]
			if not is_instance_valid(d):
				continue
			d.set("note", 1.0 if idx % 16 == 0 else 0.6)
			if cam and cam.global_position.distance_to(d.global_position) < 20.0:
				var harm := 0.0 if k % 3 != 2 else -5.0            # every third man takes the low part
				Voice.syllable(_voice_of(d), d.get("voice"), pow(2.0, (semi + harm) / 12.0) * 0.94, -9.0 if idx % 16 == 0 else -13.0)
	if _t >= total + 0.4:
		for d2: Node in _cast:
			_cue(d2, "toast", 3.6)
		var lead: Node3D = _cast[_rng.randi() % _cast.size()]
		Voice.laugh_at(lead, lead.get("voice"), -10.0)
		_finish()


# --- dice ------------------------------------------------------------------------------------------

func _dice_step(delta: float) -> void:
	var a: Node3D = _cast[0]
	var b: Node3D = _cast[1]
	if not (is_instance_valid(a) and is_instance_valid(b)):
		_finish()
		return
	# three throws, turn about: 0..2.6 s each, then the reaction
	var throw_i := int(_t / 4.6)
	if throw_i >= 3:
		var winner: Node3D = a if _rng.randf() < 0.5 else b
		var loser: Node3D = b if winner == a else a
		_cue(winner, "cheer", 2.6)
		_cue(loser, "groan", 2.6)
		Voice.laugh_at(winner, winner.get("voice"), -9.0)
		_bark(DICE[_rng.randi() % DICE.size()], winner)
		_finish()
		return
	var thrower: Node3D = a if throw_i % 2 == 0 else b
	var watcher: Node3D = b if thrower == a else a
	if _step != throw_i + 1:
		_step = throw_i + 1
		_cue(thrower, "dice", 2.6)
		_cue(watcher, "listen", 2.6)
		for d: MeshInstance3D in _dice:
			d.queue_free()
		_dice.clear()
		_dice_v.clear()
		# throw on a timer too: dice_out is a one-frame flag and misses when the dwarf poses at 12 Hz
		get_tree().create_timer(1.55, false).timeout.connect(func() -> void:
			if is_inside_tree() and scene == "dice" and _dice.is_empty() and is_instance_valid(thrower):
				_throw(thrower, watcher))
	if bool(thrower.get("dice_out")):
		thrower.set("dice_out", false)
		if _dice.is_empty():
			_throw(thrower, watcher)
	# tumble
	for i in _dice.size():
		var m := _dice[i]
		var v := _dice_v[i]
		var top := float(thrower.global_position.y) + float(thrower.get("table_top"))
		if v.length() > 0.02:
			m.global_position += v * delta
			m.rotate_object_local(Vector3(1, 0.3, 0.2).normalized(), v.length() * delta * 18.0)
			v *= pow(0.04, delta)
			if m.global_position.y < top + 0.015:
				m.global_position.y = top + 0.015
				v.y = 0.0
			else:
				v.y -= 9.8 * delta
			_dice_v[i] = v
		elif v != Vector3.ZERO:
			_dice_v[i] = Vector3.ZERO
			# come to rest square on the board
			var yaw := m.global_rotation.y
			m.global_basis = Basis(Vector3.UP, yaw)
			m.global_position.y = top + 0.015


func _throw(thrower: Node3D, watcher: Node3D) -> void:
	var mid := (thrower.global_position + watcher.global_position) * 0.5
	var top := thrower.global_position.y + float(thrower.get("table_top"))
	var from := thrower.global_position.lerp(mid, 0.45) + Vector3.UP * (float(thrower.get("table_top")) + 0.12)
	var mat := OssKit.mat("bone")
	for i in 2:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.03, 0.03, 0.03)
		mi.mesh = bm
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		mi.global_position = from + Vector3(_rng.randf_range(-0.03, 0.03), 0, _rng.randf_range(-0.03, 0.03))
		# beside the candles in the middle of the board, toward the thrower's free hand
		var across := (watcher.global_position - thrower.global_position)
		across.y = 0.0
		var side := across.normalized().cross(Vector3.UP)
		var to := mid - side * (0.34 + _rng.randf_range(-0.06, 0.08)) + across.normalized() * _rng.randf_range(-0.12, 0.12)
		to.y = top
		var v := (to - mi.global_position) * 2.2
		v.y = 0.6
		_dice.append(mi)
		_dice_v.append(v)
	_play(_sfx.clack, mid + Vector3.UP * (float(thrower.get("table_top"))), -8.0)
	get_tree().create_timer(0.22, false).timeout.connect(func() -> void:
		if is_inside_tree():
			_play(_sfx.clack, mid + Vector3.UP * float(thrower.get("table_top")), -11.0, 1.15))


# --- an argument -------------------------------------------------------------------------------------

func _argue() -> void:
	var a: Node3D = _cast[0]
	var b: Node3D = _cast[1]
	if not (is_instance_valid(a) and is_instance_valid(b)):
		_finish()
		return
	var lines: Array = ARGUE[(int(a.get("seed_n")) + played.size()) % ARGUE.size()]
	match _step:
		0:
			_step = 1
			_cue(a, "argue", 3.4)
			_cue(b, "listen", 3.4)
			_bark(String(lines[0]), a)
		1:
			if _t > 3.4:
				_step = 2
				_cue(b, "argue", 3.6)
				_cue(a, "listen", 3.6)
				_bark(String(lines[1]), b)
		2:
			if _t > 7.0:
				_step = 3
				_cue(a, "argue", 2.8)
				_cue(b, "argue", 2.8)
		3:
			if _t > 9.6:
				_step = 4
				if is_instance_valid(keep):
					var kv: Variant = keep.get("voice")
					Voice.say(_voice_of(keep), kv if kv is Dictionary else Voice.profile("keep", 5150), 4, 1.0, false, -4.0)
					_bark(KEEP_SHOUT[_rng.randi() % KEEP_SHOUT.size()], keep)
				_cue(a, "look", 1.6)
				_cue(b, "look", 1.6)
		4:
			if _t > 11.4:
				_cue(a, "laugh", 2.2)
				_cue(b, "laugh", 2.5)
				Voice.laugh_at(a, a.get("voice"), -10.0)
				_step = 5
		5:
			if _t > 13.8:
				_cue(a, "toast", 4.0)
				_cue(b, "toast", 4.0)
				_finish()
	for d: Node3D in [a, b]:
		if is_instance_valid(d) and bool(d.get("slam_hit")):
			d.set("slam_hit", false)
			_play(_sfx.thump, d.global_position + Vector3.UP * float(d.get("table_top")), -6.0, _rng.randf_range(0.9, 1.1))


# --- a round for the room ------------------------------------------------------------------------------

func _round() -> void:
	if _step == 0:
		_step = 1
		for i in _cast.size():
			var d: Node = _cast[i]
			get_tree().create_timer(0.08 * float(i), false).timeout.connect(func() -> void:
				if is_instance_valid(d):
					_cue(d, "cheer", 2.4))
		if not _cast.is_empty():
			var lead: Node3D = _cast[0]
			Voice.laugh_at(lead, lead.get("voice"), -8.0)
			_bark("\"To the kindled!\"", lead)
	elif _step == 1 and _t > 2.6:
		_step = 2
		for d: Node in _cast:
			_cue(d, "drink", 4.6)
		_finish()


# --- sounds ---------------------------------------------------------------------------------------------

func _play(stream: AudioStream, at: Vector3, db: float, pitch := 1.0) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or cam.global_position.distance_to(at) > 22.0:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.bus = "SFX"
	p.volume_db = db
	p.pitch_scale = pitch
	p.unit_size = 3.0
	p.max_distance = 24.0
	add_child(p)
	p.global_position = at
	p.play()
	p.finished.connect(p.queue_free)


## Bone dice on oak: three quick dry ticks.
static func _make_clack() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var n := int(RATE * 0.26)
	var pcm := PackedFloat32Array()
	pcm.resize(n)
	for hit: float in [0.0, 0.07, 0.15]:
		var s0 := int(hit * RATE)
		var amp := 0.7 if hit == 0.0 else 0.45
		var f := rng.randf_range(2600.0, 3400.0)
		for i in int(RATE * 0.03):
			var t := float(i) / RATE
			if s0 + i < n:
				pcm[s0 + i] += amp * exp(-t * 260.0) * (sin(TAU * f * t) * 0.6 + rng.randf_range(-0.5, 0.5))
	return _wav(pcm)


## A fist on a trestle: a low knock and a rattle of mugs.
static func _make_thump() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	var n := int(RATE * 0.32)
	var pcm := PackedFloat32Array()
	pcm.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp = lerpf(lp, rng.randf_range(-1.0, 1.0), 0.08)
		pcm[i] = 0.9 * exp(-t * 28.0) * sin(TAU * (82.0 - 30.0 * t) * t) + 0.5 * exp(-t * 60.0) * lp
		if t > 0.05:
			pcm[i] += 0.08 * exp(-(t - 0.05) * 40.0) * sin(TAU * 1900.0 * t) * rng.randf()
	return _wav(pcm)


static func _wav(pcm: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(pcm.size() * 2)
	for i in pcm.size():
		bytes.encode_s16(i * 2, int(clampf(pcm[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	return w
