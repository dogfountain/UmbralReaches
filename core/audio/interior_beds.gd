extends Node
## A bed of its own for every interior (Luke: every enterable interior and cave gets its own layered bed and reverb). The reverb room comes from
## AcousticZones (hall, cave, crypt, with the tavern, the Ossuary and the Rift already Ambience's own); this adds the bed: when the wanderer stands in a
## registered zone, the zone's named loop fades in (non-positional, on the Ambience bus, so the outdoor layers' indoor muffle does not touch it) and fades out
## on leaving. Eight beds, twelve seconds each, rendered once on a worker thread and cached (the same way as the landmarks'):
##   hall     stone hum and a far drip          cave     drips and a draught             crypt    a cold hum and bones settling
##   tower    wind in iron and a fire's tick    hollow   wood groaning, leaves far up    heart    a furnace's slow pulse and breath
##   hold     a ship's timbers and slopping water    nave   a choir's held chord and dripping water
## A builder registers a zone with `AcousticZones.register(aabb, room, label)` (label = one of the names above, else the room's); a zone with no bed of its
## own gets its room's. Polled twice a second; one player pair; nothing runs while the wanderer is outdoors. No class_name.

const Kit := preload("res://core/audio/synth_kit.gd")
const GenCache := preload("res://core/world/realm/gen_cache.gd")
const AcousticZones := preload("res://core/audio/acoustic_zones.gd")
const SELF := "res://core/audio/interior_beds.gd"
const VERSION := 1
const LEN := 12.0
const BEDS := ["hall", "cave", "crypt", "tower", "hollow", "heart", "hold", "nave"]
const DB := -14.0
const FADE := 2.0

static var _bytes := {}
static var _streams := {}
static var _mutex := Mutex.new()
static var _task := -1

var ambience: Ambience
var stage: Node
var current := ""
var _player: AudioStreamPlayer
var _t := 0.0
var _gain := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _task < 0:
		_task = WorkerThreadPool.add_task(_work, false, "interior_beds")
	_player = AudioStreamPlayer.new()
	_player.name = "InteriorBed"
	_player.bus = &"Ambience"
	_player.volume_db = -80.0
	add_child(_player)


func _exit_tree() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	_mutex.lock()
	_bytes.clear()
	_mutex.unlock()
	_streams.clear()


static func _work() -> void:
	for id: String in BEDS:
		var key := "interior_%s_v%d" % [id, VERSION]
		var data: Variant = GenCache.load_var(key, SELF)
		var bytes: PackedByteArray
		if data is PackedByteArray and (data as PackedByteArray).size() > 64:
			bytes = data
		else:
			var pcm := build(id)
			Kit.finish(pcm, 0.8, 0.0)
			bytes = Kit.encode(pcm)
			GenCache.save_var(key, SELF, bytes)
		_mutex.lock()
		_bytes[id] = bytes
		_mutex.unlock()


static func stream(id: String) -> AudioStreamWAV:
	if _streams.has(id):
		return _streams[id]
	_mutex.lock()
	var b: Variant = _bytes.get(id)
	_mutex.unlock()
	if b == null:
		return null
	var w := Kit.wav(b as PackedByteArray, true)
	_streams[id] = w
	return w


static func _fit(f: float) -> float:
	return maxf(1.0, roundf(f * LEN)) / LEN


static func _drips(o: PackedFloat32Array, times: Array, f: float) -> void:
	for t: float in times:
		Kit.partial(o, t, 0.25, f, 0.18, 0.001, 0.06, f * 0.7)
		Kit.noise(o, t, 0.05, 0.12, 1500.0, 6000.0, 0.001, 0.02, int(t * 100.0))


static func build(id: String) -> PackedFloat32Array:
	var o := Kit.buf(LEN)
	match id:
		"hall":
			Kit.partial(o, 0.0, LEN, _fit(65.0), 0.4, 0.0, 1.0e6)
			Kit.partial(o, 0.0, LEN, _fit(98.0), 0.25, 0.0, 1.0e6)
			Kit.noise(o, 0.0, LEN - 0.5, 0.08, 150.0, 900.0, 2.0, 1.0e6, 301, 0.2)
			_drips(o, [2.5, 7.8, 10.6], 1100.0)
		"cave":
			Kit.noise(o, 0.0, LEN - 0.5, 0.2, 100.0, 700.0, 2.0, 1.0e6, 311, 0.3)
			Kit.partial(o, 0.0, LEN, _fit(48.0), 0.25, 0.0, 1.0e6)
			_drips(o, [0.8, 2.9, 4.1, 6.6, 9.0, 11.0], 1500.0)
		"crypt":
			Kit.partial(o, 0.0, LEN, _fit(55.0), 0.35, 0.0, 1.0e6)
			Kit.partial(o, 0.0, LEN, _fit(58.0), 0.3, 0.0, 1.0e6)
			for t: float in [1.5, 5.2, 9.4]:
				Kit.noise(o, t, 0.06, 0.4, 2000.0, 7500.0, 0.001, 0.02, int(t * 10.0) + 321)
				Kit.thud(o, t + 0.02, 120.0, 70.0, 0.08, 0.25, int(t))
			_drips(o, [3.4, 8.2], 1300.0)
		"tower":
			Kit.partial(o, 0.0, LEN, _fit(110.0), 0.28, 0.0, 1.0e6)
			Kit.noise(o, 0.0, LEN - 0.5, 0.16, 250.0, 1600.0, 2.0, 1.0e6, 331, 0.25)
			for i in 12:
				Kit.noise(o, 0.4 + float(i) * 0.95 + 0.1 * float(i % 3), 0.04, 0.45, 2000.0, 8000.0, 0.001, 0.015, 340 + i)
		"hollow":
			Kit.partial(o, 0.0, LEN, _fit(55.0), 0.35, 0.0, 1.0e6)
			Kit.partial(o, 0.0, LEN, _fit(82.5), 0.2, 0.0, 1.0e6)
			Kit.noise(o, 0.0, LEN - 0.5, 0.15, 300.0, 1800.0, 2.0, 1.0e6, 351, 0.25)
			Kit.partial(o, 3.0, 1.6, 90.0, 0.25, 0.2, 0.8, 140.0)
			Kit.partial(o, 8.5, 1.8, 120.0, 0.22, 0.2, 0.9, 80.0)
		"heart":
			Kit.partial(o, 0.0, LEN, _fit(42.0), 0.45, 0.0, 1.0e6)
			for k in 10:
				Kit.thud(o, 0.2 + 1.2 * float(k), 60.0, 40.0, 0.3, 0.45, k)                   # a slow pulse: the furnace, or what is in it
			Kit.noise(o, 0.0, 5.0, 0.15, 80.0, 600.0, 2.0, 1.2, 361)
			Kit.noise(o, 6.0, 5.0, 0.15, 80.0, 600.0, 2.0, 1.2, 362)
		"hold":
			Kit.noise(o, 0.0, LEN - 0.5, 0.18, 200.0, 1200.0, 2.0, 1.0e6, 371, 0.35)
			for t: float in [1.4, 5.0, 9.2]:
				Kit.partial(o, t, 0.9, 170.0, 0.3, 0.05, 0.4, 230.0)
				Kit.noise(o, t, 0.8, 0.2, 200.0, 1000.0, 0.05, 0.4, int(t * 10.0) + 372, 11.0)
			for t2: float in [3.0, 7.0, 10.5]:
				Kit.noise(o, t2, 0.5, 0.3, 300.0, 2500.0, 0.05, 0.2, int(t2 * 10.0) + 380)
		"nave":
			for f: float in [98.0, 147.0, 196.0]:
				Kit.partial(o, 0.0, LEN, _fit(f), 0.3, 0.0, 1.0e6)
			_drips(o, [1.2, 3.8, 5.9, 8.5, 10.9], 1000.0)
	return o


func _process(dt: float) -> void:
	_t -= dt
	var want := current
	if _t <= 0.0:
		_t = 0.5
		var pl := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
		want = AcousticZones.label_at(pl.global_position) if pl != null else ""
		if want != "" and not BEDS.has(want):
			want = _room_bed(want)
		if want != current:
			current = want
			if want != "":
				var s := stream(want)
				if s != null and _player.stream != s:
					_player.stream = s
					_player.play(randf() * LEN)
	var goal := 1.0 if current != "" and _player.stream != null else 0.0
	_gain = move_toward(_gain, goal, dt / FADE)
	if _gain <= 0.001:
		if _player.playing:
			_player.stop()
		return
	_player.volume_db = DB + linear_to_db(_gain)


## A zone whose label is not one of the beds (a room name, or nothing): its room's bed.
static func _room_bed(room: String) -> String:
	match room:
		"tavern", "ossuary", "rift", "":
			return ""
	return room if BEDS.has(room) else ""
