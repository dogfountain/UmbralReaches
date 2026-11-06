extends RefCounted
## Procedural combat sounds (no new .wav assets): built once per kind on first use as 16-bit mono
## AudioStreamWAVs, then cached. Played through Sfx.play_stream. Load by path (no class_name):
##   const Synth := preload("res://core/vfx/synth.gd")
## Kinds: "flesh" (wet thud + crunch on a hit), "bone" (dry clack, ossuants and the Abbot),
## "growl" (a rattling rise for a strike windup: the audible tell), "stagger" (a heavy downward
## thump), "roar" (a boss phase change), "spike" (bone/thorn eruption), "block" (a blow turned on
## a shield), "burrow" (earth churned from below), "chant" (a caster's rising drone).
## Kinds with rendered takes (art/audio/kit, see EnemyAudio) are served from those, a take at a time; the
## code below is the fallback. Creature voices (r28): voice(family, act) -> a variant of that family's cry, round-robin so the
## same take never plays twice in a row. Families: rasp (wretch), bellow (husk, bulwark), chitter
## (crawler, mite, burrower), shriek (leaper), gurgle (spitter), rattle (ossuant), whisper (chanter).
## Acts: tell (windup), hurt, die, call (a pack's alarm howl), flee (a hurt one falling back).

const RATE := 22050

const KINDS := ["flesh", "bone", "growl", "roar", "stagger", "spike", "block", "burrow", "chant"]
const GenCache := preload("res://core/world/realm/gen_cache.gd")

static var _cache := {}


## Drop the synthesised PCM (the app is closing): engine resources must not outlive the
## renderer and audio server in static vars (see the r28 exit abort). Rebuilt lazily if needed.
static func release() -> void:
	_cache.clear()
	_last_take.clear()


## Build every kind now (called during load by the encounter director). Built lazily, the first
## hit / growl / roar of a fight synthesised in script and cost a visible frame; the PCM is cached.
static func prewarm() -> void:
	# the rendered takes (EnemyAudio) replace these: only a kind or family without one is still built here
	for k: String in KINDS:
		if EnemyAudio.kit(k) == null:
			get_stream(k)


static func get_stream(kind: String) -> AudioStreamWAV:
	var banked := EnemyAudio.kit(kind) as AudioStreamWAV         # rendered, layered, several takes: preferred
	if banked != null:
		return banked
	if _cache.has(kind):
		return _cache[kind]
	var cached: Variant = GenCache.load_var("synth_" + kind, "res://core/vfx/synth.gd")
	if cached is PackedByteArray:
		_cache[kind] = _wav_bytes(cached)
		return _cache[kind]
	var pcm := PackedFloat32Array()
	match kind:
		"flesh": pcm = _flesh()
		"bone": pcm = _bone()
		"growl": pcm = _growl(0.55, 1.0)
		"roar": pcm = _growl(1.5, 0.55)
		"stagger": pcm = _stagger()
		"spike": pcm = _spike()
		"block": pcm = _block()
		"burrow": pcm = _burrow()
		"chant": pcm = _chant()
		_: return null
	var s := _wav(pcm)
	_cache[kind] = s
	GenCache.save_var("synth_" + kind, "res://core/vfx/synth.gd", s.data)
	return s


static func _wav(pcm: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(pcm.size() * 2)
	var peak := 0.0001
	for v in pcm:
		peak = maxf(peak, absf(v))
	var g := 0.92 / peak
	for i in pcm.size():
		bytes.encode_s16(i * 2, int(clampf(pcm[i] * g, -1.0, 1.0) * 32767.0))
	return _wav_bytes(bytes)


static func _wav_bytes(bytes: PackedByteArray) -> AudioStreamWAV:
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = bytes
	return s


## Deterministic white noise (same sound every run).
static func _noise(n: int, seed_v: int) -> PackedFloat32Array:
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = r.randf_range(-1.0, 1.0)
	return out


static func _flesh() -> PackedFloat32Array:
	var n := int(RATE * 0.2)
	var nz := _noise(n, 11)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := lerpf(95.0, 42.0, minf(t / 0.12, 1.0))
		ph += TAU * f / RATE
		var thud := sin(ph) * exp(-t * 26.0)
		lp += (nz[i] - lp) * 0.35                 # dull the noise: a wet crunch, not a hiss
		var crunch := lp * exp(-t * 55.0) * 0.9
		var squelch := lp * exp(-pow((t - 0.05) * 30.0, 2.0)) * 0.35
		out[i] = thud * 0.9 + crunch + squelch
	return out


static func _bone() -> PackedFloat32Array:
	var n := int(RATE * 0.16)
	var nz := _noise(n, 23)
	var out := PackedFloat32Array()
	out.resize(n)
	var hp_prev := 0.0
	var hp := 0.0
	for i in n:
		var t := float(i) / RATE
		hp = 0.7 * (hp + nz[i] - hp_prev)         # high-pass: a dry click
		hp_prev = nz[i]
		var ring := sin(TAU * 820.0 * t) * 0.5 + sin(TAU * 1370.0 * t) * 0.3
		out[i] = hp * exp(-t * 70.0) + ring * exp(-t * 38.0) * 0.6 + sin(TAU * 120.0 * t) * exp(-t * 30.0) * 0.5
	return out


## A throaty rattle: saw + noise, low-passed, chopped at ~26 Hz, swelling to a cut-off.
static func _growl(dur: float, pitch: float) -> PackedFloat32Array:
	var n := int(RATE * dur)
	var nz := _noise(n, 37)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		var k := t / dur
		var f := (70.0 + 30.0 * k + 6.0 * sin(t * 9.0)) * pitch
		ph = fmod(ph + f / RATE, 1.0)
		var saw := ph * 2.0 - 1.0
		var src := saw * 0.6 + nz[i] * 0.7
		var cut := 0.06 + 0.1 * k
		lp += (src - lp) * cut
		lp2 += (lp - lp2) * cut
		var chop := 0.55 + 0.45 * sin(TAU * (24.0 + 8.0 * k) * pitch * t)
		var env := smoothstep(0.0, 0.25, k) * (1.0 - smoothstep(0.85, 1.0, k))
		out[i] = lp2 * chop * env
	return out


static func _stagger() -> PackedFloat32Array:
	var n := int(RATE * 0.32)
	var nz := _noise(n, 41)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		ph += TAU * lerpf(140.0, 38.0, minf(t / 0.25, 1.0)) / RATE
		lp += (nz[i] - lp) * 0.2
		out[i] = sin(ph) * exp(-t * 11.0) + lp * exp(-t * 30.0) * 0.6
	return out


static func _spike() -> PackedFloat32Array:
	var n := int(RATE * 0.45)
	var nz := _noise(n, 53)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp += (nz[i] - lp) * 0.5
		var crack := 0.0
		for k in 4:                                # a quick run of cracks as the spikes break ground
			var tk := t - 0.025 * float(k)
			if tk > 0.0:
				crack += nz[i] * exp(-tk * 90.0) * 0.6
		out[i] = crack + lp * exp(-t * 8.0) * 0.5 + sin(TAU * 55.0 * t) * exp(-t * 9.0) * 0.8
	return out


static func _block() -> PackedFloat32Array:
	var n := int(RATE * 0.22)
	var nz := _noise(n, 61)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		# a dull wooden-iron knock with a short ring: the blow did not get through
		var ring := sin(TAU * 610.0 * t) * 0.5 + sin(TAU * 1490.0 * t) * 0.25 + sin(TAU * 2310.0 * t) * 0.12
		out[i] = ring * exp(-t * 22.0) + nz[i] * exp(-t * 120.0) * 0.8 + sin(TAU * 90.0 * t) * exp(-t * 35.0) * 0.6
	return out


static func _burrow() -> PackedFloat32Array:
	var n := int(RATE * 0.7)
	var nz := _noise(n, 67)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / RATE
		var k := t / 0.7
		lp += (nz[i] - lp) * 0.08
		lp2 += (lp - lp2) * 0.08
		var grit := nz[i] * (0.15 + 0.15 * sin(TAU * 13.0 * t)) * smoothstep(0.0, 0.1, k)
		out[i] = (lp2 * 3.0 + grit) * (1.0 - smoothstep(0.6, 1.0, k)) + sin(TAU * 42.0 * t) * 0.4 * exp(-t * 4.0)
	return out


## A low two-note drone that swells: the caster's working (in time with its raised staff).
static func _chant() -> PackedFloat32Array:
	var n := int(RATE * 1.1)
	var nz := _noise(n, 71)
	var out := PackedFloat32Array()
	out.resize(n)
	var bp := [0.0, 0.0]
	for i in n:
		var t := float(i) / RATE
		var k := t / 1.1
		var f := 146.8 if k < 0.55 else 138.6
		var tone := sin(TAU * f * t) * 0.5 + sin(TAU * f * 2.0 * t) * 0.25 + sin(TAU * f * 3.01 * t) * 0.12
		var breath := _svf(bp, nz[i], 900.0, 0.4) * 0.5
		out[i] = (tone * (0.6 + 0.4 * sin(TAU * 5.0 * t)) + breath) * smoothstep(0.0, 0.3, k) * (1.0 - smoothstep(0.85, 1.0, k))
	return out


# --- creature voices ----------------------------------------------------------------------------

## family -> f0 (Hz), formants F1/F2, noise (breath/rasp), chop (rattle Hz), clicks (Hz, chitter),
## bubble (wet blips), bone (dry clacks).
const VOICES := {
	"rasp":    {"f0": 210.0, "f1": 760.0, "f2": 1900.0, "noise": 0.55, "chop": 31.0, "clicks": 0.0, "bubble": 0.0, "bone": 0.0},
	"bellow":  {"f0": 82.0,  "f1": 420.0, "f2": 980.0,  "noise": 0.3,  "chop": 19.0, "clicks": 0.0, "bubble": 0.0, "bone": 0.0},
	"chitter": {"f0": 420.0, "f1": 2300.0, "f2": 3900.0, "noise": 0.45, "chop": 0.0, "clicks": 38.0, "bubble": 0.0, "bone": 0.0},
	"shriek":  {"f0": 520.0, "f1": 1300.0, "f2": 3100.0, "noise": 0.4,  "chop": 47.0, "clicks": 0.0, "bubble": 0.0, "bone": 0.0},
	"gurgle":  {"f0": 160.0, "f1": 520.0, "f2": 1350.0, "noise": 0.35, "chop": 0.0,  "clicks": 0.0, "bubble": 1.0, "bone": 0.0},
	"rattle":  {"f0": 96.0,  "f1": 480.0, "f2": 1150.0, "noise": 0.4,  "chop": 23.0, "clicks": 0.0, "bubble": 0.0, "bone": 1.0},
	"whisper": {"f0": 190.0, "f1": 640.0, "f2": 2300.0, "noise": 0.85, "chop": 0.0,  "clicks": 0.0, "bubble": 0.0, "bone": 0.0},
}
const ACTS := ["tell", "hurt", "die", "call", "flee"]
## act -> seconds, pitch contour (start, peak, end as f0 multiples), where the peak sits (0..1)
const SHAPES := {
	"tell": {"dur": 0.5,  "a": 0.8,  "b": 1.35, "c": 1.25, "peak": 0.85},
	"hurt": {"dur": 0.2,  "a": 1.45, "b": 1.6,  "c": 0.95, "peak": 0.2},
	"die":  {"dur": 0.95, "a": 1.3,  "b": 1.45, "c": 0.45, "peak": 0.15},
	"call": {"dur": 1.05, "a": 0.85, "b": 1.6,  "c": 1.15, "peak": 0.45},
	"flee": {"dur": 0.42, "a": 1.5,  "b": 1.7,  "c": 1.2,  "peak": 0.35},
}
const TAKES := {"tell": 3, "hurt": 3, "die": 2, "call": 2, "flee": 2}
static var _last_take := {}


static func _takes(act: String) -> Array:
	return range(int(TAKES.get(act, 1)))


## One of the family's takes for this act, never the one played last (pitch jitter on top keeps
## a pack from sounding like one voice). Unknown family/act -> the old shared growl.
static func voice(family: String, act: String) -> AudioStreamWAV:
	if not VOICES.has(family) or not SHAPES.has(act):
		return get_stream("growl")
	var n := int(TAKES.get(act, 1))
	var key := family + "/" + act
	var v := randi() % n
	if n > 1 and _last_take.get(key, -1) == v:
		v = (v + 1 + randi() % (n - 1)) % n
	_last_take[key] = v
	return _voice_take(family, act, v)


static func _voice_take(family: String, act: String, take: int) -> AudioStreamWAV:
	var id := "v_%s_%s_%d" % [family, act, take]
	if _cache.has(id):
		return _cache[id]
	var cached: Variant = GenCache.load_var("synth_" + id, "res://core/vfx/synth.gd")
	if cached is PackedByteArray:
		_cache[id] = _wav_bytes(cached)
		return _cache[id]
	var s := _wav(_creature(VOICES[family], SHAPES[act], take, hash(id) % 100000))
	_cache[id] = s
	GenCache.save_var("synth_" + id, "res://core/vfx/synth.gd", s.data)
	return s


## Chamberlin state-variable band-pass, state in st[0] (low) / st[1] (band).
static func _svf(st: Array, x: float, fc: float, q: float) -> float:
	var f := 2.0 * sin(PI * minf(fc, RATE * 0.22) / RATE)
	var low: float = st[0] + f * float(st[1])
	var high := x - low - q * float(st[1])
	var band: float = st[1] + f * high
	st[0] = low
	st[1] = band
	return band


## A throat: a pulse train on a pitch contour (with jitter), plus breath, through two formant
## resonators; then the family's texture -- a rattle chop, a click train, wet blips, bone clacks.
static func _creature(v: Dictionary, sh: Dictionary, take: int, seed_v: int) -> PackedFloat32Array:
	var var_pitch: float = [1.0, 0.9, 1.11][take % 3]
	var var_len: float = [1.0, 1.12, 0.9][take % 3]
	var dur: float = float(sh.dur) * var_len
	var n := int(RATE * dur)
	var nz := _noise(n, seed_v)
	var out := PackedFloat32Array()
	out.resize(n)
	var f1 := [0.0, 0.0]
	var f2 := [0.0, 0.0]
	var ph := 0.0
	var wob := float(take) * 1.7
	var peak: float = sh.peak
	var noise_amt: float = v.noise
	var chop: float = v.chop
	var clicks: float = v.clicks
	var bubble: float = v.bubble
	var bone: float = v.bone
	var f0: float = float(v.f0) * var_pitch
	var click_ph := 0.0
	var blip_t := -1.0
	var blip_f := 600.0
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v + 5
	for i in n:
		var t := float(i) / RATE
		var k := t / dur
		var m: float = lerpf(sh.a, sh.b, smoothstep(0.0, 1.0, k / peak)) if k < peak else lerpf(sh.b, sh.c, smoothstep(0.0, 1.0, (k - peak) / maxf(1.0 - peak, 0.01)))
		var f := f0 * m * (1.0 + 0.03 * sin(t * (17.0 + wob)) + 0.02 * nz[(i * 7) % n])
		ph = fmod(ph + f / RATE, 1.0)
		var pulse := (1.0 - 2.0 * ph) * (1.0 - noise_amt * 0.6)       # bright saw-like pulse
		var src := pulse + nz[i] * noise_amt
		var y := _svf(f1, src, float(v.f1) * (0.9 + 0.2 * m * 0.5), 0.35) + _svf(f2, src, float(v.f2) * (0.95 + 0.1 * m), 0.45) * 0.6
		if chop > 0.0:
			y *= 0.5 + 0.5 * absf(sin(PI * chop * (1.0 + 0.3 * k) * t))
		if clicks > 0.0:
			click_ph += clicks * (0.8 + 0.6 * m) / RATE
			if click_ph >= 1.0:
				click_ph -= 1.0
			y = y * 0.45 + nz[(i * 3) % n] * exp(-click_ph * 22.0) * 1.1
		if bubble > 0.0:
			if blip_t < 0.0 and rng.randf() < 0.0016:
				blip_t = 0.0
				blip_f = rng.randf_range(380.0, 900.0)
			if blip_t >= 0.0:
				blip_t += 1.0 / RATE
				y += sin(TAU * blip_f * (1.0 + blip_t * 6.0) * blip_t) * exp(-blip_t * 45.0) * 0.9
				if blip_t > 0.08:
					blip_t = -1.0
		if bone > 0.0:
			var cp := fmod(t * (14.0 + 6.0 * k), 1.0)
			y += nz[(i * 5) % n] * exp(-cp * 60.0) * 0.6 + sin(TAU * 1100.0 * t) * exp(-cp * 45.0) * 0.25
		var env := smoothstep(0.0, 0.06, k) * (1.0 - smoothstep(0.7, 1.0, k))
		out[i] = y * env
	return out
