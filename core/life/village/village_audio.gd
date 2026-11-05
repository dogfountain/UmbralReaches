extends RefCounted
## Village sounds, synthesised once at load (village system; no class_name, no asset files):
## the anvil's ring (inharmonic partials, a hard transient), the quench's hiss (filtered noise
## with a falling bubble), an axe biting wood, a spade in earth, a slow knock on a plank door.
## Played through Sfx.play_stream (pooled positional voices). Load by path.

const RATE := 22050

const KINDS := ["anvil", "quench", "chop", "dig", "knock"]
const GenCache := preload("res://core/world/realm/gen_cache.gd")

static var _cache := {}


## Drop the engine resources held in static vars (called when the night is torn down): statics
## outlive the renderer at quit ("RID allocations leaked at exit"). Rebuilt on next use.
static func release() -> void:
	_cache.clear()


## Build every sound now (the village calls this during load). Synthesising one sample at a time
## in GDScript cost a ~30 ms frame the first time Hild struck the anvil; the PCM is cached too.
static func prewarm() -> void:
	for k: String in KINDS:
		stream(k)


static func stream(kind: String) -> AudioStreamWAV:
	if _cache.has(kind):
		return _cache[kind]
	var cached: Variant = GenCache.load_var("village_audio_" + kind, "res://core/life/village/village_audio.gd")
	if cached is PackedByteArray:
		_cache[kind] = _wav(cached)
		return _cache[kind]
	var s: AudioStreamWAV
	match kind:
		"anvil":
			s = _make(0.9, func(t: float, rng: RandomNumberGenerator) -> float:
				var v := 0.0
				for p: Array in [[612.0, 1.0, 5.0], [1187.0, 0.6, 7.0], [1903.0, 0.42, 9.0], [2741.0, 0.3, 12.0], [3622.0, 0.18, 16.0]]:
					v += sin(TAU * float(p[0]) * t) * float(p[1]) * exp(-t * float(p[2]))
				v += (rng.randf() * 2.0 - 1.0) * exp(-t * 90.0) * 0.8
				return v * 0.32)
		"quench":
			var lp := [0.0]
			s = _make(1.4, func(t: float, rng: RandomNumberGenerator) -> float:
				var n := rng.randf() * 2.0 - 1.0
				lp[0] = lerpf(lp[0], n, 0.35)
				var env := minf(t * 30.0, 1.0) * exp(-t * 2.2)
				var bub := sin(TAU * (380.0 - 160.0 * t) * t) * 0.12 * exp(-t * 3.0) * (0.5 + 0.5 * sin(t * 47.0))
				return (n - lp[0]) * env * 0.5 + bub)
		"chop":
			s = _make(0.35, func(t: float, rng: RandomNumberGenerator) -> float:
				var thud := sin(TAU * (160.0 - 90.0 * t) * t) * exp(-t * 22.0)
				var crack := (rng.randf() * 2.0 - 1.0) * exp(-t * 60.0)
				return (thud * 0.7 + crack * 0.5) * 0.6)
		"dig":
			var lp2 := [0.0]
			s = _make(0.45, func(t: float, rng: RandomNumberGenerator) -> float:
				var n := rng.randf() * 2.0 - 1.0
				lp2[0] = lerpf(lp2[0], n, 0.12)
				return lp2[0] * minf(t * 40.0, 1.0) * exp(-t * 9.0) * 1.4)
		"knock":
			s = _make(0.3, func(t: float, rng: RandomNumberGenerator) -> float:
				return (sin(TAU * 120.0 * t) * 0.8 + sin(TAU * 247.0 * t) * 0.3 + (rng.randf() - 0.5) * 0.4 * exp(-t * 80.0)) * exp(-t * 26.0) * 0.7)
		_:
			return null
	_cache[kind] = s
	GenCache.save_var("village_audio_" + kind, "res://core/life/village/village_audio.gd", s.data)
	return s


static func _make(seconds: float, fn: Callable) -> AudioStreamWAV:
	var n := int(seconds * RATE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var data := PackedByteArray()
	data.resize(n * 2)
	var fade := int(0.02 * RATE)
	for i in n:
		var v := float(fn.call(float(i) / RATE, rng))
		if i > n - fade:
			v *= float(n - i) / float(fade)
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32000.0))
	return _wav(data)


static func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s


static func play(kind: String, at: Vector3, volume_db := -6.0, pitch := 1.0) -> void:
	var s := stream(kind)
	if s:
		Sfx.play_stream(s, at, volume_db, pitch, 0.06)
