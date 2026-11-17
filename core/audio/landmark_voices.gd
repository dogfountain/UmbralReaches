extends Node
## Each of the landmarks has a sound of its own, heard before it is seen: the Sleeper breathes (a sub-bass swell and
## a long breath of air), the Hollow King groans and creaks in its hollow, the Salt Ship's rigging and planks work against a salt
## wind, a Wardens' tower hums with wind in its iron and a fire's tick, the Chain Span's links tick and groan in the draught, a Titan
## Gate holds one great stone chord, a hermit's pole lets a few chimes fall from its lantern. The beds are twelve-second loops, rendered
## once on a worker thread and cached (the same way as the score's stems); a landmark's bed fades in as the wanderer comes within
## ~85 m (hermit caches 40 m), and at most three play at once. The Wardens' towers also register their hall as a room for the
## reverb (acoustic_zones.gd). Landmarks are found as the group "world_poi" (wonders/wonder_kit.gd poi()); their position is the
## centre of their meshes' bounds. No class_name.

const Kit := preload("res://core/audio/synth_kit.gd")
const GenCache := preload("res://core/world/realm/gen_cache.gd")
const AcousticZones := preload("res://core/audio/acoustic_zones.gd")
const SELF := "res://core/audio/landmark_voices.gd"
const VERSION := 1
const LEN := 12.0
const BEDS := ["sleeper", "hollow_king", "salt_ship", "wardens", "chain_span", "titan_gates", "hermit"]
const PREFIX := {"TheSleeper": "sleeper", "HollowKing": "hollow_king", "SaltShip": "salt_ship", "WardensTower": "wardens", "ChainSpan": "chain_span", "TitanGate_": "titan_gates", "HermitCache": "hermit"}
const RANGE := {"hermit": 40.0}
const DB := {"sleeper": -14.0, "hollow_king": -15.0, "salt_ship": -16.0, "wardens": -17.0, "chain_span": -17.0, "titan_gates": -15.0, "hermit": -20.0}
const MAX_AT_ONCE := 3

static var _bytes := {}
static var _streams := {}
static var _mutex := Mutex.new()
static var _task := -1

var ambience: Ambience                 ## set by the Soundstage (unused here; every child takes the same two)
var stage: Node
var _t := 0.0
var _hosts: Array = []              ## [host, bed, centre]
var _scan_t := 0.0
var _live := {}                     ## host instance id -> AudioStreamPlayer3D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _task < 0:
		_task = WorkerThreadPool.add_task(_work, false, "landmark_beds")


func _exit_tree() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	_mutex.lock()
	_bytes.clear()
	_mutex.unlock()
	_streams.clear()
	AcousticZones.clear()


static func _work() -> void:
	for id: String in BEDS:
		var key := "landmark_%s_v%d" % [id, VERSION]
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


## A bed: sustained partials fitted to the loop, events (breaths, creaks, ticks, chimes) placed so their tails end inside it.
static func build(id: String) -> PackedFloat32Array:
	var o := Kit.buf(LEN)
	match id:
		"sleeper":
			Kit.partial(o, 0.0, LEN, _fit(38.0), 0.5, 0.0, 1.0e6)
			Kit.partial(o, 0.0, LEN, _fit(57.0), 0.3, 0.0, 1.0e6)
			for k in 2:
				var t := 6.0 * float(k)
				Kit.noise(o, t, 3.0, 0.5, 70.0, 700.0, 2.4, 0.5, 20 + k)             # the breath in
				Kit.noise(o, t + 3.0, 3.0, 0.45, 70.0, 600.0, 0.3, 1.8, 30 + k)      # and out
		"hollow_king":
			Kit.partial(o, 0.0, LEN, _fit(55.0), 0.4, 0.0, 1.0e6)
			Kit.partial(o, 0.0, LEN, _fit(82.5), 0.25, 0.0, 1.0e6)
			Kit.noise(o, 0.0, LEN - 0.5, 0.18, 300.0, 1800.0, 2.0, 1.0e6, 41, 0.25)     # wind in the leaves, far up
			Kit.partial(o, 2.5, 1.6, 90.0, 0.3, 0.2, 0.8, 140.0)                         # a great limb groans
			Kit.partial(o, 8.0, 1.8, 120.0, 0.28, 0.2, 0.9, 80.0)
		"salt_ship":
			Kit.noise(o, 0.0, LEN - 0.5, 0.2, 1000.0, 6500.0, 2.0, 1.0e6, 51, 0.3)       # salt wind through the rigging
			for t: float in [2.0, 6.5, 9.5]:
				Kit.partial(o, t, 0.9, 180.0, 0.3, 0.05, 0.4, 235.0)                      # a plank works
				Kit.noise(o, t, 0.8, 0.2, 200.0, 1000.0, 0.05, 0.4, int(t * 10.0), 12.0)
			Kit.noise(o, 4.5, 1.6, 0.35, 300.0, 1300.0, 0.05, 0.7, 53, 3.0)               # a torn sail flaps
		"wardens":
			Kit.partial(o, 0.0, LEN, _fit(110.0), 0.3, 0.0, 1.0e6)
			Kit.partial(o, 0.0, LEN, _fit(164.8), 0.12, 0.0, 1.0e6)
			Kit.noise(o, 0.0, LEN - 0.5, 0.16, 250.0, 1400.0, 2.0, 1.0e6, 61, 0.2)
			for i in 14:
				Kit.noise(o, 0.5 + float(i) * 0.8 + 0.1 * float(i % 3), 0.04, 0.5, 2000.0, 8000.0, 0.001, 0.015, 70 + i)     # a fire's tick
		"chain_span":
			Kit.partial(o, 0.0, LEN, _fit(70.0), 0.3, 0.0, 1.0e6)
			Kit.noise(o, 0.0, LEN - 0.5, 0.15, 400.0, 2600.0, 2.0, 1.0e6, 81, 0.3)
			for i in 8:
				Kit.bell(o, 0.6 + float(i) * 1.4, [1760.0, 2093.0, 1568.0, 2349.0][i % 4], 0.12, 0.25)       # links ticking
			Kit.partial(o, 5.0, 2.0, 70.0, 0.3, 0.3, 1.0, 75.0)
		"titan_gates":
			for f: float in [49.0, 73.5, 98.0]:
				Kit.partial(o, 0.0, LEN, _fit(f), 0.35, 0.0, 1.0e6)
			Kit.noise(o, 0.0, LEN - 0.5, 0.08, 80.0, 500.0, 2.0, 1.0e6, 91, 0.15)
		"hermit":
			Kit.noise(o, 0.0, LEN - 0.5, 0.1, 300.0, 1600.0, 2.0, 1.0e6, 101, 0.25)
			for p: Array in [[2.0, 1760.0], [5.5, 2093.0], [8.7, 1568.0], [10.3, 2349.0]]:
				Kit.bell(o, float(p[0]), float(p[1]), 0.22, 0.5)
	return o


func _process(dt: float) -> void:
	_t -= dt
	if _t > 0.0:
		return
	_t = 2.0
	var pl := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	if pl == null:
		return
	_scan_t -= 2.0
	if _scan_t <= 0.0:
		_scan_t = 12.0
		_rescan()
	var near: Array = []
	for h: Array in _hosts:
		if not is_instance_valid(h[0]):
			continue
		var d := pl.global_position.distance_to(h[2] as Vector3)
		if d < float(RANGE.get(String(h[1]), 85.0)):
			near.append([d, h])
	near.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var want := {}
	for i in mini(near.size(), MAX_AT_ONCE):
		var h: Array = (near[i] as Array)[1]
		want[(h[0] as Node).get_instance_id()] = h
	for id: int in _live.keys():
		if not want.has(id):
			var p := _live[id] as AudioStreamPlayer3D
			_live.erase(id)
			if is_instance_valid(p):
				var tw := p.create_tween()
				tw.tween_property(p, "volume_db", -60.0, 2.0)
				tw.tween_callback(p.queue_free)
	for id2: int in want:
		if _live.has(id2):
			continue
		var h2: Array = want[id2]
		var s := stream(String(h2[1]))
		if s == null:
			continue
		var p2 := AudioStreamPlayer3D.new()
		p2.name = "Landmark_" + String(h2[1])
		p2.stream = s
		p2.bus = &"AmbOut" if AudioServer.get_bus_index("AmbOut") >= 0 else &"Ambience"
		p2.unit_size = 14.0
		p2.max_distance = 110.0
		p2.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p2.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		p2.volume_db = -60.0
		p2.global_position = h2[2] as Vector3
		add_child(p2)
		p2.play(randf() * LEN)
		var tw2 := p2.create_tween()
		tw2.tween_property(p2, "volume_db", float(DB.get(String(h2[1]), -16.0)), 2.5)
		_live[id2] = p2


## Find the landmarks (the group is filled at build time) and where each stands.
func _rescan() -> void:
	_hosts.clear()
	for n: Node in get_tree().get_nodes_in_group("world_poi"):
		if not n.has_meta("wonder"):
			continue
		var nm := String(n.get_meta("wonder"))
		var bed := ""
		for pre: String in PREFIX:
			if nm.begins_with(pre):
				bed = String(PREFIX[pre])
		if bed == "":
			continue
		var box := _bounds(n)
		if box.size == Vector3.ZERO:
			continue
		_hosts.append([n, bed, box.get_center()])
		if bed == "wardens" and not n.has_meta("acoustic"):
			n.set_meta("acoustic", true)
			AcousticZones.register(AABB(box.position, Vector3(box.size.x, minf(box.size.y, 9.0), box.size.z)), "hall")
		elif bed == "hollow_king" and not n.has_meta("acoustic"):
			n.set_meta("acoustic", true)          # the hollow hall at the oak's root: the trunk is 16 m round
			var c := box.get_center()
			AcousticZones.register(AABB(Vector3(c.x - 7.0, box.position.y - 0.5, c.z - 7.0), Vector3(14.0, 6.0, 14.0)), "cave")


## The bounds of every mesh under a landmark, in world space.
static func _bounds(n: Node) -> AABB:
	var box := AABB()
	var first := true
	for c: Node in n.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh != null:
			var mi := c as MeshInstance3D
			var b := mi.global_transform * mi.get_aabb()
			box = b if first else box.merge(b)
			first = false
	return box
