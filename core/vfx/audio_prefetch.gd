extends Node
## The creatures' sound takes and the shared one-shots, loaded on the loader's worker threads behind the loading cover
## (camps and villages perf pass, 21 Nov). EnemyAudio and Sfx loaded each take from disk on the main thread the first
## time it played: a fight's first seconds met a dozen of them (each kind's alert, wind-up, strike, hurt and steps on
## the ground it stands on, the hit materials), one to a few in a frame, as the fight started. Every take EnemyAudio can
## pick (enemy_bank.gd lists them) and the top-level one-shots under art/audio are asked for at once and handed to the
## two caches as they arrive, a share a frame; nothing waits on a load. QOA-compressed takes: ~10 MB for all of them.
## Started by the encounters' staging (staging.gd); frees itself when done. Load by path (no class_name).

const Bank := preload("res://core/vfx/enemy_bank.gd")
const SELF := "res://core/vfx/audio_prefetch.gd"
const ONE_SHOTS := "res://art/audio/"
const PER_FRAME := 32                  ## arrivals looked at a frame

var _enemy := PackedStringArray()      ## for EnemyAudio
var _sfx := PackedStringArray()        ## for Sfx
var _i := 0
var _t0 := 0


static func start(host: Node) -> void:
	if host == null or host.has_meta(&"audio_prefetch"):
		return
	host.set_meta(&"audio_prefetch", true)
	var n := (load(SELF) as GDScript).new() as Node
	n.name = "AudioPrefetch"
	host.add_child(n)


## Every path EnemyAudio can build (say, step, hit, kit, player).
static func enemy_paths() -> PackedStringArray:
	var out := PackedStringArray()
	for vs: String in Bank.SETS:
		for act: String in Bank.SETS[vs]:
			for k in int(Bank.SETS[vs][act]):
				out.append("res://art/audio/enemy/%s/%s_%d.wav" % [vs, act, k])
	for body: String in Bank.STEPS:
		for surf: String in Bank.STEPS[body]:
			for k in int(Bank.STEPS[body][surf]):
				out.append("res://art/audio/enemy/step/%s_%s_%d.wav" % [body, surf, k])
	for kind: String in Bank.KIT:
		for k in int(Bank.KIT[kind]):
			out.append("res://art/audio/kit/%s_%d.wav" % [kind, k])
	for mat: String in Bank.HITS:
		for k in int(Bank.HITS[mat][0]):
			out.append("res://art/audio/kit/hit_%s_%d.wav" % [mat, k])
		for k in int(Bank.HITS[mat][1]):
			out.append("res://art/audio/kit/hit_%s_heavy_%d.wav" % [mat, k])
	for kind: String in Bank.PLAYER:
		for k in int(Bank.PLAYER[kind]):
			out.append("res://art/audio/player/%s_%d.wav" % [kind, k])
	return out


func _ready() -> void:
	_t0 = Time.get_ticks_msec()
	for p in enemy_paths():
		if ResourceLoader.exists(p):
			_enemy.append(p)
	for f in ResourceLoader.list_directory(ONE_SHOTS):
		# the top level only (its folders are the bank's and the wildlife's own), not the ambient beds (Ambience's)
		if f.ends_with(".wav") and not f.begins_with("amb_"):
			_sfx.append(ONE_SHOTS + f)
	for p in _enemy + _sfx:
		ResourceLoader.load_threaded_request(p, "", false, ResourceLoader.CACHE_MODE_REUSE)


func _process(_dt: float) -> void:
	var n := _enemy.size() + _sfx.size()
	var looked := 0
	while _i < n and looked < PER_FRAME:
		var p := _enemy[_i] if _i < _enemy.size() else _sfx[_i - _enemy.size()]
		var st := ResourceLoader.load_threaded_get_status(p)
		if st == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return                          # in order: wait for this one (the rest arrive meanwhile)
		if st == ResourceLoader.THREAD_LOAD_LOADED:
			var s := ResourceLoader.load_threaded_get(p) as AudioStream
			if _i < _enemy.size():
				EnemyAudio.keep(p, s)
			else:
				Sfx.keep(p, s)
		_i += 1
		looked += 1
	if _i >= n:
		print("AUDIOPREFETCH %d creature takes and %d one-shots kept (%.1f s)" % [_enemy.size(), _sfx.size(), (Time.get_ticks_msec() - _t0) / 1000.0])
		queue_free()
