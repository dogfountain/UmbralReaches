extends Node
## r35 (docs/critique/r35_full.md "Decisions, round two"): a composed theme for each of the three
## great ones and the ending's great bell, synthesised (no recordings), like the rest of the music.
## Each theme is a loop in two stems that play in lockstep: BASE (from the pull) and HIGH (it rises
## with the fight's phase, full in the last one). Rendered once, on a worker thread when a fight
## begins, and cached through GenCache, so the first pull plays the night's danger pad for the few
## seconds it takes and every pull after starts on the downbeat.
##   THORNWARDEN      D dorian, 6/8, 88 bpm: frame drum and rim, a drone on D-A, a plucked ostinato
##                    walking Dm / C / Bb / C; HIGH: a bowed fiddle line and a doubled drum.
##   BONE ABBOT       D phrygian, 4/4, 56 bpm: organ on Dm / Eb / Dm / Bbm-A, a low choir, a toll on
##                    every downbeat (he counts), a bone tick on every beat; HIGH: the chant and timpani.
##   ASCENDED WARDEN  D lydian, 3/4, 72 bpm: a high choir on D / E / D / C#m, bell arpeggios rising
##                    through each bar, a sub drone; HIGH: timpani and a falling brass line.
## The node follows the fight (Events.boss_engaged, the boss's `phase`, its death, the wanderer
## walking away) and ScapeMusic stands its danger pad and heartbeat down while a theme plays.
## Load by path (no class_name).

const RATE := 22050
const SELF := "res://core/life/wildlife/boss_themes.gd"
const GenCache := preload("res://core/world/realm/gen_cache.gd")
const VERSION := 1
const IDS := ["thornwarden", "bone_abbot", "ascended_warden"]
const LAST_PHASE := {"thornwarden": 3, "bone_abbot": 4, "ascended_warden": 3}
const DB := -9.0                    ## the theme under the fight (the Music bus slider sits on top)
const FADE_IN := 2.5
const FADE_OUT := 3.5
const REACH := 70.0                 ## the theme holds while the boss stands this near

var theme_k := 0.0                  ## 0 .. 1 how much a theme is playing (ScapeMusic ducks under it)
var playing_id := ""                ## tests, debug

var _base: AudioStreamPlayer
var _high: AudioStreamPlayer
var _boss: Node3D = null
var _boss_id := ""
var _want := 0.0
var _high_k := 0.0
var _pending: Dictionary = {}       ## id -> WorkerThreadPool task id
static var _cache := {}             ## "id:layer" -> AudioStreamWAV


func _ready() -> void:
	name = "BossThemes"
	add_to_group(&"boss_themes")
	_base = _player("ThemeBase")
	_high = _player("ThemeHigh")
	if Events.has_signal("boss_engaged"):
		Events.boss_engaged.connect(_on_engaged)
	if Events.has_signal("boss_slain"):
		Events.boss_slain.connect(func(_id: String) -> void: _want = 0.0)


func _player(nm: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.name = nm
	p.bus = &"Music" if AudioServer.get_bus_index("Music") >= 0 else &"Master"
	p.volume_db = -80.0
	add_child(p)
	return p


func _on_engaged(b: Node, _title: String) -> void:
	var id := String(b.get_meta(&"boss_id", "")) if b else ""
	if not IDS.has(id) or not (b is Node3D):
		return
	_boss = b as Node3D
	_boss_id = id
	_want = 1.0
	if _ready_for(id):
		_start(id)
	else:
		_build_async(id)               # the arena normally did this on the approach (prepare)


func _process(dt: float) -> void:
	_collect_built()
	if _want > 0.0:
		var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
		var alive := _boss != null and is_instance_valid(_boss) and _boss.is_inside_tree() and not _boss.is_queued_for_deletion() \
			and _boss.process_mode != Node.PROCESS_MODE_DISABLED
		if not alive or p == null or _boss.global_position.distance_to(p.global_position) > REACH:
			_want = 0.0                          # slain, freed, the fight held (walked out) or left far behind
	if _want > 0.0 and playing_id == "" and _ready_for(_boss_id):
		_start(_boss_id)
	var target := _want if playing_id != "" else 0.0
	theme_k = move_toward(theme_k, target, dt / (FADE_IN if target > theme_k else FADE_OUT))
	if playing_id != "":
		var ph := int(_boss.get("phase")) if _boss != null and is_instance_valid(_boss) and "phase" in _boss else 1
		var last := int(LAST_PHASE.get(playing_id, 3))
		var hk := clampf(float(ph - 1) / float(maxi(1, last - 1)), 0.0, 1.0)
		_high_k = move_toward(_high_k, hk, dt / 3.0)
		_base.volume_db = DB + linear_to_db(maxf(theme_k, 0.0001))
		_high.volume_db = DB + linear_to_db(maxf(theme_k * _high_k, 0.0001))
		if theme_k <= 0.0 and _want <= 0.0:
			_base.stop()
			_high.stop()
			playing_id = ""


func _start(id: String) -> void:
	_base.stream = stream(id, "base")
	_high.stream = stream(id, "high")
	if _base.stream == null or _high.stream == null:
		return
	_base.volume_db = -80.0
	_high.volume_db = -80.0
	_base.play()
	_high.play()                            # same length, started together: they stay in step
	playing_id = id
	_high_k = 0.0


# --- building -------------------------------------------------------------------------------------

## A theme the pull can start at once: both stems are wrapped and held in memory.
func _ready_for(id: String) -> bool:
	return _cache.has(id + ":base") and _cache.has(id + ":high")


## Called by the arena as the wanderer nears (BossKit.warm): reads the cached stems, or renders them,
## on a worker thread, so the pull itself touches neither the disk nor the synthesiser.
func prepare(id: String) -> void:
	if IDS.has(id) and not _ready_for(id):
		_build_async(id)


## r35 fix: the worker holds only its own locals (the script, a box, a mutex), never this node: a
## night freed mid-render (a test ending in a fight) left it locking a freed node's mutex.
func _build_async(id: String) -> void:
	if _pending.has(id):
		return
	var scr: GDScript = get_script()
	var box := {"done": false, "bytes": []}
	var m := Mutex.new()
	var task := WorkerThreadPool.add_task(func() -> void:
		var b: PackedByteArray = scr.call("_fetch", id, "base")
		var h: PackedByteArray = scr.call("_fetch", id, "high")
		m.lock()
		box["bytes"] = [b, h]
		box["done"] = true
		m.unlock())
	_pending[id] = [task, box, m]


func _collect_built() -> void:
	if _pending.is_empty():
		return
	for id: String in _pending.keys():
		var job: Array = _pending[id]
		var m: Mutex = job[2]
		m.lock()
		var done := bool((job[1] as Dictionary)["done"])
		var pair: Array = (job[1] as Dictionary)["bytes"]
		m.unlock()
		if not done:
			continue
		WorkerThreadPool.wait_for_task_completion(int(job[0]))
		_pending.erase(id)
		_cache[id + ":base"] = _wav(pair[0])
		_cache[id + ":high"] = _wav(pair[1])


func _exit_tree() -> void:
	for id: String in _pending.keys():
		WorkerThreadPool.wait_for_task_completion(int((_pending[id] as Array)[0]))
	_pending.clear()


static func _key(id: String, layer: String) -> String:
	return "boss_theme_%s_%s_v%d" % [id, layer, VERSION]


## One stem's bytes: the cache if it holds them, else rendered and cached. Safe on a worker thread.
static func _fetch(id: String, layer: String) -> PackedByteArray:
	var data: Variant = GenCache.load_var(_key(id, layer), SELF)
	if data is PackedByteArray and (data as PackedByteArray).size() > 64:
		return data
	var bytes := _encode(build(id, layer))
	if not bytes.is_empty():
		GenCache.save_var(_key(id, layer), SELF, bytes)
	return bytes


## The theme's stem as a looping stream (built on this thread if it was never cached: tests, bakes).
static func stream(id: String, layer: String) -> AudioStreamWAV:
	var k := id + ":" + layer
	if _cache.has(k):
		return _cache[k]
	var data: Variant = GenCache.load_var(_key(id, layer), SELF)
	var bytes: PackedByteArray
	if data is PackedByteArray and (data as PackedByteArray).size() > 64:
		bytes = data
	else:
		bytes = _encode(build(id, layer))
		if bytes.is_empty():
			return null
		GenCache.save_var(_key(id, layer), SELF, bytes)
	_cache[k] = _wav(bytes)
	return _cache[k]


static func _wav(bytes: PackedByteArray) -> AudioStreamWAV:
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = bytes
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = bytes.size() / 2
	return s


static func _encode(pcm: PackedFloat32Array) -> PackedByteArray:
	var bytes := PackedByteArray()
	if pcm.is_empty():
		return bytes
	bytes.resize(pcm.size() * 2)
	var peak := 0.0001
	for v in pcm:
		peak = maxf(peak, absf(v))
	var g := 0.85 / peak
	for i in pcm.size():
		bytes.encode_s16(i * 2, int(clampf(pcm[i] * g, -1.0, 1.0) * 32767.0))
	return bytes


static func build(id: String, layer: String) -> PackedFloat32Array:
	match id:
		"thornwarden":
			return _thorn(layer == "high")
		"bone_abbot":
			return _abbot(layer == "high")
		"ascended_warden":
			return _warden(layer == "high")
	return PackedFloat32Array()


# --- the three themes -----------------------------------------------------------------------------

static func _hz(semi_from_a4: float) -> float:
	return 440.0 * pow(2.0, semi_from_a4 / 12.0)


## semitones from A4 for a note name in octave 4 (D4 = -7) -- callers add 12 per octave
const N := {"C": -9, "C#": -8, "Db": -8, "D": -7, "D#": -6, "Eb": -6, "E": -5, "F": -4, "F#": -3, "G": -2, "G#": -1, "Ab": -1,
	"A": 0, "A#": 1, "Bb": 1, "B": 2}


static func _n(name: String, octave: int) -> float:
	return _hz(float(int(N[name]) + 12 * (octave - 4)))


## THORNWARDEN: D dorian, 6/8 at 88 bpm, 16 bars.
static func _thorn(high: bool) -> PackedFloat32Array:
	var e := 60.0 / 88.0 / 3.0                     # an eighth (three to the dotted beat)
	var bar := e * 6.0
	var out := _buf(bar * 16.0)
	var roots := ["D", "D", "C", "C", "Bb", "Bb", "C", "A"]
	if not high:
		_drone(out, 0.0, out.size() / float(RATE), [_n("D", 2), _n("A", 2)], 0.22)
	for b in 16:
		var t0 := bar * float(b)
		var r := String(roots[b % 8])
		if not high:
			# the frame drum on the two dotted beats, a third stroke every other bar; the rim between
			_drum(out, t0, 0.9, 1.0)
			_drum(out, t0 + e * 3.0, 0.75, 0.9)
			if b % 2 == 1:
				_drum(out, t0 + e * 5.0, 0.5, 1.05)
			_rim(out, t0 + e * 2.0, 0.25)
			_rim(out, t0 + e * 4.0, 0.2)
			# the plucked ostinato over the bar's root (root, fifth, octave, seventh, fifth, third)
			var o := 3
			var pat := [[r, o], [_up(r, 7), o], [r, o + 1], [_up(r, 10), o], [_up(r, 7), o], [_up(r, 3), o]]
			for i in 6:
				_pluck(out, t0 + e * float(i), _n(String(pat[i][0]), int(pat[i][1])), 0.45 if i == 0 else 0.32)
		else:
			# the fiddle: a line that climbs over the first half and falls back, two notes a bar
			var line := ["D", "E", "F", "A", "G", "F", "E", "C", "D", "F", "A", "C", "Bb", "A", "G", "A"]
			var nt := String(line[b])
			_bowed(out, t0, bar * 0.62, _n(nt, 5 if nt != "C" or b < 8 else 6), 0.32)
			_bowed(out, t0 + bar * 0.62, bar * 0.38, _n(_up(nt, -2), 5), 0.22)
			# the drum doubled: sixteenth pickups into every dotted beat
			_drum(out, t0, 1.0, 1.0)
			_drum(out, t0 + e * 2.5, 0.35, 1.2)
			_drum(out, t0 + e * 3.0, 0.8, 0.9)
			_drum(out, t0 + e * 5.5, 0.35, 1.2)
	return out


## BONE ABBOT: D phrygian, 4/4 at 56 bpm, 8 bars. A toll on every downbeat: he counts.
static func _abbot(high: bool) -> PackedFloat32Array:
	var q := 60.0 / 56.0
	var bar := q * 4.0
	var out := _buf(bar * 8.0)
	# chords: [root, octave, third (semitones), fifth]
	var chords := [["D", 3, 3], ["D", 3, 3], ["Eb", 3, 4], ["Eb", 3, 4], ["D", 3, 3], ["D", 3, 3], ["Bb", 2, 3], ["A", 2, 4]]
	for b in 8:
		var t0 := bar * float(b)
		var c: Array = chords[b]
		var root := _n(String(c[0]), int(c[1]))
		if not high:
			_organ(out, t0, bar, [root * 0.5, root, root * pow(2.0, float(int(c[2])) / 12.0), root * 1.4983], 0.24)
			_choir(out, t0, bar, [root, root * 1.4983], 0.18, 0.0)
			_bell_hit(out, t0, _n("D", 3), 0.55, 4.0)                    # the toll
			for k in 4:
				_tick(out, t0 + q * float(k), 0.18)                   # the count
		else:
			var chant := ["A", "Bb", "A", "G", "F", "G", "Eb", "D"]
			_choir(out, t0, q * 2.6, [_n(String(chant[b]), 4)], 0.3, 1.0)
			_choir(out, t0 + q * 2.6, q * 1.4, [_n(_up(String(chant[b]), -2), 4)], 0.22, 1.0)
			_timpani(out, t0, _n("D", 2), 0.7)
			_timpani(out, t0 + q * 2.0, _n("A", 1), 0.45)
			_bell_hit(out, t0 + q * 2.0, _n("D", 4), 0.25, 2.5)
	return out


## ASCENDED WARDEN: D lydian, 3/4 at 72 bpm, 12 bars. Holy, and wrong by a sharpened fourth.
static func _warden(high: bool) -> PackedFloat32Array:
	var q := 60.0 / 72.0
	var bar := q * 3.0
	var out := _buf(bar * 12.0)
	# [root, octave, third semis] -- D, E (the lydian II), D, C#m, Bm, E, D, D
	var chords := [["D", 4, 4], ["E", 4, 4], ["D", 4, 4], ["C#", 4, 3], ["B", 3, 3], ["E", 4, 4], ["D", 4, 4], ["G#", 3, 3],
		["D", 4, 4], ["E", 4, 4], ["B", 3, 3], ["D", 4, 4]]
	if not high:
		_sub(out, 0.0, out.size() / float(RATE), _n("D", 1), 0.3)
	for b in 12:
		var t0 := bar * float(b)
		var c: Array = chords[b]
		var root := _n(String(c[0]), int(c[1]))
		var third := root * pow(2.0, float(int(c[2])) / 12.0)
		var fifth := root * 1.4983
		if not high:
			_choir(out, t0, bar * 1.02, [root, third, fifth, root * 2.0], 0.16, 0.0)
			# bell arpeggio rising through the bar: root, third, fifth, octave, octave third, octave fifth
			var arp := [root, third, fifth, root * 2.0, third * 2.0, fifth * 2.0]
			for i in 6:
				_celesta(out, t0 + q * 0.5 * float(i), float(arp[i]) * 2.0, 0.2)
		else:
			_timpani(out, t0, _n("D", 2), 0.8)
			_timpani(out, t0 + q * 2.0, _n("A", 1), 0.4)
			# the brass falls a step a bar, the sky with it
			var fall := ["A", "G#", "F#", "E", "D", "C#", "B", "A", "G#", "F#", "E", "D"]
			_bowed(out, t0, bar * 0.95, _n(String(fall[b]), 4), 0.3, true)
			_bowed(out, t0, bar * 0.95, _n(String(fall[b]), 3), 0.22, true)
	return out


static func _up(name: String, semis: int) -> String:
	var order := ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"]
	var flat := {"Db": "C#", "D#": "Eb", "G#": "Ab", "A#": "Bb"}
	var nm := String(flat.get(name, name))
	var i := order.find(nm)
	if i < 0:
		return name
	return String(order[(i + semis + 120) % 12])


# --- the ending's great bell ----------------------------------------------------------------------

## A tower bell's partials over the strike note (A2 here): hum an octave below, prime, minor-third
## tierce, quint, nominal an octave up, then superquint and octave nominal; each pair slightly
## detuned so it beats, the hum swelling in a moment after the strike ("from the bottom up").
static func great_bell() -> AudioStreamWAV:
	if _cache.has("great_bell"):
		return _cache["great_bell"]
	var key := "great_bell_v%d" % VERSION
	var data: Variant = GenCache.load_var(key, SELF)
	var bytes: PackedByteArray
	if data is PackedByteArray and (data as PackedByteArray).size() > 64:
		bytes = data
	else:
		bytes = _encode(_great_bell(110.0, 24.0))
		GenCache.save_var(key, SELF, bytes)
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.data = bytes
	_cache["great_bell"] = s
	return s


static func _great_bell(f: float, seconds: float) -> PackedFloat32Array:
	var out := _buf(seconds)
	# [ratio, amp, decay s, attack s]
	var parts := [[0.5, 0.55, 22.0, 0.9], [1.0, 0.5, 14.0, 0.01], [1.2, 0.42, 12.0, 0.01], [1.5, 0.25, 8.0, 0.01],
		[2.0, 0.4, 9.0, 0.01], [2.5, 0.12, 4.0, 0.01], [3.0, 0.16, 5.0, 0.01], [4.0, 0.1, 3.5, 0.01], [5.33, 0.06, 1.6, 0.01]]
	for pr: Array in parts:
		var fr := f * float(pr[0])
		# a real bell's partials beat gently (the casting is never round): a second, weaker copy a
		# fraction of a hertz off. Equal copies cancelled to silence every two seconds (a throb).
		_partial(out, 0.0, seconds, fr, float(pr[1]) * 0.8, float(pr[2]), float(pr[3]))
		_partial(out, 0.0, seconds, fr + 0.18, float(pr[1]) * 0.22, float(pr[2]) * 0.85, float(pr[3]))
	# the strike: a short dark clank
	var n := int(0.03 * RATE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var lp := 0.0
	for i in n:
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.25
		out[i] += lp * 0.6 * (1.0 - float(i) / float(n))
	return out


# --- instruments ----------------------------------------------------------------------------------

static func _buf(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * RATE))
	return b


## One sine partial from t (s) for dur (s): linear attack, exponential decay. Wraps round the loop.
static func _partial(out: PackedFloat32Array, t: float, dur: float, f: float, amp: float, decay: float, attack := 0.005) -> void:
	var n := out.size()
	var s0 := int(t * RATE)
	var cnt := int(dur * RATE)
	var w := TAU * f / RATE
	var a_n := maxf(1.0, attack * RATE)
	var k := exp(-1.0 / maxf(decay * RATE, 1.0))
	var env := 1.0
	for i in cnt:
		var a := minf(1.0, float(i) / a_n)
		out[(s0 + i) % n] += sin(w * float(i)) * amp * a * env
		env *= k


static func _pluck(out: PackedFloat32Array, t: float, f: float, amp: float) -> void:
	# Karplus-Strong: a noise burst through a loop that averages (a gut string, briefly)
	var n := out.size()
	var p := maxi(2, int(RATE / f))
	var line := PackedFloat32Array()
	line.resize(p)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(f * 13.0)
	for i in p:
		line[i] = rng.randf_range(-1.0, 1.0)
	var s0 := int(t * RATE)
	var cnt := int(1.6 * RATE)
	var j := 0
	for i in cnt:
		var a := line[j]
		var b := line[(j + 1) % p]
		line[j] = 0.497 * (a + b)
		out[(s0 + i) % n] += a * amp
		j = (j + 1) % p


static func _drum(out: PackedFloat32Array, t: float, amp: float, pitch: float) -> void:
	# a frame drum: a falling thump and a skin slap
	var n := out.size()
	var s0 := int(t * RATE)
	var cnt := int(0.45 * RATE)
	var ph := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = s0
	for i in cnt:
		var x := float(i) / RATE
		var f := (52.0 + 70.0 * exp(-x * 30.0)) * pitch
		ph += TAU * f / RATE
		var body := sin(ph) * exp(-x * 9.0)
		var slap := rng.randf_range(-1.0, 1.0) * exp(-x * 80.0) * 0.35
		out[(s0 + i) % n] += (body + slap) * amp * 0.8


static func _rim(out: PackedFloat32Array, t: float, amp: float) -> void:
	var n := out.size()
	var s0 := int(t * RATE)
	var rng := RandomNumberGenerator.new()
	rng.seed = s0 + 3
	var hp := 0.0
	var prev := 0.0
	for i in int(0.06 * RATE):
		var x := rng.randf_range(-1.0, 1.0)
		hp = 0.7 * (hp + x - prev)
		prev = x
		out[(s0 + i) % n] += hp * amp * exp(-float(i) / RATE * 70.0)


static func _tick(out: PackedFloat32Array, t: float, amp: float) -> void:
	# a dry bone tick: two short high partials
	_partial(out, t, 0.08, 1830.0, amp * 0.6, 0.018)
	_partial(out, t, 0.08, 2710.0, amp * 0.4, 0.012)


static func _timpani(out: PackedFloat32Array, t: float, f: float, amp: float) -> void:
	for pr: Array in [[1.0, 1.0, 1.6], [1.5, 0.5, 1.1], [1.99, 0.35, 0.8], [2.44, 0.2, 0.5]]:
		_partial(out, t, 2.0, f * float(pr[0]), amp * float(pr[1]) * 0.6, float(pr[2]))
	_drum(out, t, amp * 0.5, 0.7)


static func _bell_hit(out: PackedFloat32Array, t: float, f: float, amp: float, decay: float) -> void:
	for pr: Array in [[0.5, 0.5, 1.4], [1.0, 0.6, 1.0], [1.2, 0.45, 0.8], [1.5, 0.3, 0.6], [2.0, 0.4, 0.55], [3.0, 0.15, 0.3]]:
		_partial(out, t, decay * 1.2, f * float(pr[0]), amp * float(pr[1]) * 0.5, decay * float(pr[2]))


static func _celesta(out: PackedFloat32Array, t: float, f: float, amp: float) -> void:
	_partial(out, t, 1.6, f, amp, 0.7)
	_partial(out, t, 1.0, f * 2.0, amp * 0.35, 0.35)
	_partial(out, t, 0.6, f * 4.07, amp * 0.12, 0.15)


const TBL := 2048


## One cycle of a waveform: amps[h] is partial h + 1's amplitude.
static func _table(amps: Array) -> PackedFloat32Array:
	var tb := PackedFloat32Array()
	tb.resize(TBL)
	for h in amps.size():
		var a: float = amps[h]
		if a == 0.0:
			continue
		var w := TAU * float(h + 1) / float(TBL)
		for i in TBL:
			tb[i] += sin(w * float(i)) * a
	return tb


## Play a wavetable at f from t for dur: attack / release ramps, a vibrato that comes in after
## vib_delay s, and an optional slow swell (cycles over the note). One lookup a sample.
static func _play(out: PackedFloat32Array, t: float, dur: float, f: float, tb: PackedFloat32Array, amp: float,
		att: float, rel: float, vib := 0.0, vib_delay := 0.0, swell := 0.0, phase0 := 0.0) -> void:
	var n := out.size()
	var s0 := int(t * RATE)
	var cnt := int(dur * RATE)
	var a_n := maxf(1.0, att * RATE)
	var r_n := maxf(1.0, rel * RATE)
	var d_n := maxf(1.0, vib_delay * RATE)
	var inc := f / RATE
	var ph := phase0
	var vw := TAU * 5.3 / RATE
	var sw := TAU * swell / maxf(1.0, float(cnt))
	for i in cnt:
		var fi := float(i)
		ph += inc * (1.0 + vib * minf(1.0, fi / d_n) * sin(vw * fi))
		ph -= floorf(ph)
		var e := minf(1.0, fi / a_n) * minf(1.0, float(cnt - i) / r_n)
		if swell > 0.0:
			e *= 0.75 + 0.25 * sin(sw * fi)
		out[(s0 + i) % n] += tb[int(ph * TBL) & (TBL - 1)] * amp * e


static func _drone(out: PackedFloat32Array, t: float, dur: float, fs: Array, amp: float) -> void:
	# a sustained reed drone: odd-leaning partials with a slow breathing swell (no decay)
	for f: float in fs:
		var amps: Array = []
		for h in 7:
			amps.append(1.0 / float(h + 1) * (1.0 if h % 2 == 0 else 0.55))
		_play(out, t, dur, f, _table(amps), amp, 0.01, 0.01, 0.0, 0.0, 2.0)


static func _sub(out: PackedFloat32Array, t: float, dur: float, f: float, amp: float) -> void:
	_play(out, t, dur, f, _table([1.0]), amp, 0.01, 0.01, 0.0, 0.0, 3.0)


static func _organ(out: PackedFloat32Array, t: float, dur: float, fs: Array, amp: float) -> void:
	# drawbars 8' 4' 2 2/3' 2': partials 1, 2, 3, 4; a short attack and release
	var tb := _table([1.0, 0.55, 0.3, 0.25])
	for f: float in fs:
		_play(out, t, dur, f, tb, amp / float(fs.size()), 0.03, 0.15)


static func _choir(out: PackedFloat32Array, t: float, dur: float, fs: Array, amp: float, lead: float) -> void:
	# voices on "ah": partials weighted by two formants (~700 and ~1150 Hz) for the note's own pitch,
	# a slow vibrato, two voices a part detuned a few cents; lead = 1 brings it forward and brighter
	for f: float in fs:
		var amps: Array = []
		for h in 14:
			var hf: float = f * float(h + 1)
			if hf > 3600.0:
				break
			var form := exp(-pow((hf - 700.0) / 260.0, 2.0)) + 0.7 * exp(-pow((hf - 1150.0) / 320.0, 2.0)) + 0.25 / float(h + 1)
			if lead > 0.0:
				form += lead * 0.3 * exp(-pow((hf - 2600.0) / 400.0, 2.0))
			amps.append(form)
		var tb := _table(amps)
		# two voices a part, the second softer and a few cents off (equal voices beat to silence)
		for v in 2:
			var fv: float = f * (1.0 + float(v) * 0.005)
			_play(out, t, dur, fv, tb, amp / float(fs.size()) * (0.62 if v == 0 else 0.38), 0.35, 0.4, 0.004 + 0.002 * float(v), 0.0, 0.0, 0.37 * float(v))


static func _bowed(out: PackedFloat32Array, t: float, dur: float, f: float, amp: float, brass := false) -> void:
	# a bowed string (or, brass = true, a horn): rich partials, a slow swell, vibrato after the attack
	var amps: Array = []
	for h in 8:
		if f * float(h + 1) > 5000.0:
			break
		amps.append(1.0 / float(h + 1) * (1.4 if brass and h < 3 else 1.0))
	_play(out, t, dur, f, _table(amps), amp, 0.12 if brass else 0.08, 0.12, 0.006, 0.3)
