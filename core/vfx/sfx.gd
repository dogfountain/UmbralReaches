class_name Sfx
extends RefCounted
## Fire-and-forget positional sounds. Streams are loaded once; one-shots share a fixed pool of
## players (a new AudioStreamPlayer3D per sound was a steady stream of node allocations in combat).
##   play(path, at, volume_db, pitch, jitter)        a sound file by path
##   play_stream(stream, at, volume_db, pitch, jitter) a stream built in code (synth.gd, staff_sfx.gd)
## r29 (critique D):
##   - the same stream started again within STACK_S of itself (within 4 m) is turned down 4 dB per repeat (five
##     mites hurt by one Nova, a pack's calls, a chain of hits: summed in phase they clipped at 0 dBFS
##     in real-mix renders and sounded like one flanged smear)
##   - when every voice is busy, the one stolen is the oldest started (it has rung longest), never
##     one started in the last few frames
##   - a sound beyond earshot (MAX_D + 2 m from the camera) is not played at all: it took a voice
##   - freed or foreign voices are dropped (a voice freed with its scene, or reparented, is rebuilt)
##   - `--sfx-trace` prints every one-shot ("SFX <ms> <name> <dB> d=<m>") for mix debugging

const FoleyLib := preload("res://core/vfx/foley.gd")

static var _streams := {}


static func stream(path: String) -> AudioStream:
	if not _streams.has(path):
		_streams[path] = load(path) if ResourceLoader.exists(path) else null
	return _streams[path]


static var _voices: Array[AudioStreamPlayer3D] = []
static var _started: PackedInt64Array = PackedInt64Array()    ## per voice: msec it last started
static var _next := 0
static var _recent := {}                 ## stream instance id -> [msec, repeats]
static var _trace := -1                  ## -1 unknown, 0 off, 1 on
const VOICES := 24
const STACK_S := 0.04
const STACK_DB := 4.0
const MAX_D := 34.0


static func play(path: String, at: Vector3, volume_db := 0.0, pitch := 1.0, jitter := 0.08) -> void:
	_fire(stream(path), at, volume_db, pitch, jitter, path.get_file())


## Same voice pool for a stream built in code (core/vfx/synth.gd) rather than loaded by path.
static func play_stream(s: AudioStream, at: Vector3, volume_db := 0.0, pitch := 1.0, jitter := 0.08) -> void:
	_fire(s, at, volume_db, pitch, jitter, "")


static func _fire(s: AudioStream, at: Vector3, volume_db: float, pitch: float, jitter: float, label: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if s == null or tree == null or tree.current_scene == null or not tree.current_scene.is_inside_tree():
		return
	if not at.is_finite():
		return
	# out of earshot (voices stop at MAX_D): skip it rather than spend a voice on silence. A third
	# of all one-shots in a render were the village's anvil and spade 50-70 m away, any of which
	# could steal a voice from a fight in front of you.
	var cam := tree.root.get_camera_3d()
	if cam != null and cam.global_position.distance_squared_to(at) > (MAX_D + 2.0) * (MAX_D + 2.0):
		return
	var now := Time.get_ticks_msec()
	var key := s.get_instance_id()
	var rec: Array = _recent.get(key, [-100000, 0, at])
	var reps := int(rec[1]) + 1 if now - int(rec[0]) < int(STACK_S * 1000.0) and (rec[2] as Vector3).distance_to(at) < 4.0 else 0
	_recent[key] = [now, reps, at]
	if _recent.size() > 256:
		_recent.clear()
	var db := volume_db - STACK_DB * float(mini(reps, 4))
	var p := _voice(tree.current_scene, now)
	if p == null:
		return
	p.stream = s
	p.volume_db = db
	if s.resource_path.begins_with("res://art/audio/kit/"):
		pitch = pow(maxf(pitch, 0.1), 0.4)        # the kit's takes are rendered with their weight: a call site's 0.5 only darkens them a little
	p.pitch_scale = maxf(pitch * randf_range(1.0 - jitter, 1.0 + jitter), 0.05)
	p.global_position = at
	p.play()
	if _trace < 0:
		_trace = 1 if "--sfx-trace" in OS.get_cmdline_user_args() else 0
	if _trace == 1:
		var d := cam.global_position.distance_to(at) if cam != null else -1.0
		var nm := label if label != "" else _name_of(s)
		print("SFX %d %s %.1f d=%.1f%s" % [now, nm, db, d, " (stacked x%d)" % reps if reps > 0 else ""])


static func _voice(host: Node, now: int) -> AudioStreamPlayer3D:
	# drop voices that died with a previous scene (or were freed under us)
	if not _voices.is_empty():
		var ok := true
		for v in _voices:
			if not is_instance_valid(v) or v.get_parent() != host:
				ok = false
				break
		if not ok:
			for v in _voices:
				if is_instance_valid(v) and v.get_parent() == host:
					v.queue_free()
			_voices.clear()
			_started.clear()
			_next = 0
	if _voices.size() < VOICES:
		var p := AudioStreamPlayer3D.new()
		p.name = "SfxVoice%d" % _voices.size()
		p.max_distance = MAX_D
		p.unit_size = 4.0
		p.max_db = 6.0                          # a toll or a chant may sit a decibel over a roar (+3 asked, +4/5 allowed)
		p.bus = &"SFX"
		p.attenuation_filter_cutoff_hz = 3800.0     # the far ones are duller: a distance low-pass
		p.attenuation_filter_db = -18.0
		p.panning_strength = 1.15                   # a little wider than flat, so a side reads in headphones
		p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		host.add_child(p)
		_voices.append(p)
		_started.append(now)
		return p
	for i in VOICES:
		var j := (_next + i) % VOICES
		var c := _voices[j]
		if not c.playing:
			_next = (j + 1) % VOICES
			_started[j] = now
			return c
	# all busy: steal the one started longest ago
	var best := 0
	for i in VOICES:
		if _started[i] < _started[best]:
			best = i
	_started[best] = now
	_next = (best + 1) % VOICES
	return _voices[best]


## Drop every cached stream and the voice list (Ambience calls it as the zone leaves the tree): the
## static caches otherwise held AudioStreamWAVs past the engine's shutdown ("leaked at exit").
static func release() -> void:
	for v in _voices:
		if is_instance_valid(v):
			v.stop()
	_voices.clear()
	_started.clear()
	_next = 0
	_streams.clear()
	_recent.clear()
	EnemyAudio.release()
	FoleyLib.release()


static var _names := {}


## Trace only: a readable name for a stream built in code (looked up in the synth caches by path, so
## nothing here loads those scripts unless --sfx-trace is on).
static func _name_of(s: AudioStream) -> String:
	if s.resource_path != "":
		return s.resource_path.get_file()
	var id := s.get_instance_id()
	if not _names.has(id):
		for spec: Array in [["res://core/vfx/synth.gd", "_cache", "synth:"], ["res://core/vfx/staff_sfx.gd", "_bank", "staff:"],
				["res://core/life/village/village_audio.gd", "_cache", "village:"], ["res://core/life/wildlife/scape_synth.gd", "_cache", "scape:"]]:
			var scr := load(String(spec[0])) as GDScript
			var bank: Variant = scr.get(String(spec[1])) if scr != null else null
			if not bank is Dictionary:
				continue
			for k: Variant in bank:
				var v: Variant = bank[k]
				for one: Variant in (v if v is Array else [v]):
					if one is Object:
						_names[(one as Object).get_instance_id()] = String(spec[2]) + str(k)
	return String(_names.get(id, "stream#%d" % id))
