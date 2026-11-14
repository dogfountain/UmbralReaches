extends RefCounted
## Foley, made in code (no recorded assets): the horse's hooves by surface, tack, breath and snorts, the
## wanderer's footfall textures by surface, cloth, and two ambience beds (a river's rush, a settlement's
## murmur). Built once per kind on first use as 16-bit mono AudioStreamWAVs (cached on disk through
## GenCache), played through Sfx.play_stream (Sfx.release drops the caches at exit). Load by path (no class_name):
##   const Foley := preload("res://core/vfx/foley.gd")
## Every kind has several takes (VARIANTS); `take()` serves them round-robin so one take never sounds
## twice in a row, and the callers add their own pitch and level jitter on top.
##   Foley.hoof(at, surface, heft, gait, hind)      one hoof planting (gait 0 walk .. 1 gallop)
##   Foley.horse_sfx(kind, at, db, pitch)           "jingle" "creak" "snort" "breath" "grunt" "thump"
##   Foley.step(surface, at, run)                   the texture layer under a footstep (grass swish, squelch, crunch ...)
##   Foley.cloth(kind, at, db)                      "walk" "run" "flap"
##   Foley.surface_at(space, pos)                   what a horse is standing on
##   Foley.bed(kind)                                looping beds "river" and "murmur" for Ambience
## `python3 tools/analyze_foley.py` renders every kind to WAV and spectrograms (see that file).

const RATE := 32000
const BED_RATE := 22050
const VARIANTS := 3
const GenCache := preload("res://core/world/realm/gen_cache.gd")
const RealmLand := preload("res://core/world/realm/realm_land.gd")
const SURFACES: Array[StringName] = [&"grass", &"road", &"stone", &"wood", &"water", &"mud"]
## Per-surface level (dB) a hoof is played at over the gait's own: the stone is bright and carries, the grass is dull.
const HOOF_DB := {&"grass": -3.0, &"road": -1.0, &"stone": 1.0, &"wood": 0.0, &"water": -1.5, &"mud": -3.5}

static var _cache := {}
static var _turn := {}


static func release() -> void:
	_cache.clear()
	_turn.clear()


# --- playing -----------------------------------------------------------------------------------------

## The next take of a kind, round-robin from a random start (never the same take twice running).
static func take(kind: String) -> AudioStreamWAV:
	var n := int(_turn.get(kind, randi() % VARIANTS)) + 1
	_turn[kind] = n % VARIANTS
	return stream(kind, n % VARIANTS)


## One hoof planting. Heavier breeds (heft) are louder and lower; the walk is softer than the gallop; a hind hoof
## drives into the ground a little harder and lower than a fore.
static func hoof(at: Vector3, surface: StringName, heft: float, gait: float, hind: bool) -> void:
	var s := surface if HOOF_DB.has(surface) else &"grass"
	var pitch := pow(maxf(heft, 0.3), -0.35) * (0.93 if hind else 1.0) * lerpf(1.04, 0.97, clampf(gait, 0.0, 1.0))
	Sfx.play_stream(take("hoof_" + String(s)), at, hoof_db(s, heft, gait, hind), pitch, 0.05)


## A hoof's level (dB): the surface's own, from the walk's softness to the gallop's drive, plus breed heft (+4 dB for
## each doubling), a hind hoof a dB up.
static func hoof_db(surface: StringName, heft: float, gait: float, hind: bool) -> float:
	return float(HOOF_DB.get(surface, -3.0)) - 14.0 + 9.0 * clampf(gait, 0.0, 1.0) + 4.2 * log(maxf(heft, 0.3)) / log(2.0) + (1.0 if hind else 0.0)


static func horse_sfx(kind: String, at: Vector3, db := 0.0, pitch := 1.0) -> void:
	Sfx.play_stream(take("horse_" + kind), at, db, pitch, 0.06)


static func step(surface: StringName, at: Vector3, run: float) -> void:
	if not SURFACES.has(surface) and surface != &"ash" and surface != &"salt" and surface != &"fen":
		return
	var kind := "step_" + String(surface)
	var trim: float = {&"stone": -4.0, &"wood": -2.0, &"grass": -1.5}.get(surface, 0.0)
	Sfx.play_stream(take(kind), at, lerpf(-14.0, -7.0, run) + trim, lerpf(0.96, 1.05, run), 0.06)


static func cloth(kind: String, at: Vector3, db := -18.0) -> void:
	Sfx.play_stream(take("cloth_" + kind), at, db, 1.0, 0.08)


## Horse hoof surfaces from the ground under it: the carved road, grass and soil, mud (the fen), the ford,
## boards and bridges, and flagged or cobbled stone (any built ground that is not boards).
static func surface_at(space: PhysicsDirectSpaceState3D, pos: Vector3) -> StringName:
	if space == null:
		return &"grass"
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 0.6, pos + Vector3.DOWN * 1.4, Layers.WORLD | Layers.PROPS))
	var on_terrain := hit.is_empty() or (hit.collider is Node and String((hit.collider as Node).name).begins_with("Terrain"))
	if on_terrain:
		if RealmLand.in_water(pos.x, pos.z):
			return &"water"
		var biome := RealmLayout.biome_at(pos.x, pos.z)
		if biome == "fen":
			return &"mud"
		if RealmLayout.path_dist(Vector2(pos.x, pos.z)) < 0.4:
			return &"road"
		return &"grass"
	var nm := String((hit.collider as Node).name).to_lower() if hit.collider is Node else ""
	if nm.contains("board") or nm.contains("deck") or nm.contains("floor") or nm.contains("dock") or nm.contains("bridge") or nm.contains("plank"):
		return &"wood"
	return &"stone"


# --- the cache ---------------------------------------------------------------------------------------

static func stream(kind: String, variant: int) -> AudioStreamWAV:
	var key := "%s_%d" % [kind, variant]
	if _cache.has(key):
		return _cache[key]
	var cached: Variant = GenCache.load_var("foley_" + key, "res://core/vfx/foley.gd")
	if cached is PackedByteArray:
		_cache[key] = _wav_bytes(cached, kind.begins_with("bed_"))
		return _cache[key]
	var pcm := render(kind, variant)
	if pcm.is_empty():
		return null
	var s := _wav(pcm, kind.begins_with("bed_"))
	_cache[key] = s
	GenCache.save_var("foley_" + key, "res://core/vfx/foley.gd", s.data)
	return s


## A looping bed for Ambience: "river" or "murmur".
static func bed(kind: String) -> AudioStreamWAV:
	return stream("bed_" + kind, 0)


## The PCM of one kind and take (floats, -1..1, unnormalised): what `stream` wraps. Public for tools.
static func render(kind: String, v: int) -> PackedFloat32Array:
	var seed_v := 7000 + v * 131 + kind.hash() % 997
	if kind.begins_with("hoof_"):
		return _hoof(kind.trim_prefix("hoof_"), seed_v)
	if kind.begins_with("step_"):
		return _step(kind.trim_prefix("step_"), seed_v)
	if kind.begins_with("cloth_"):
		return _cloth(kind.trim_prefix("cloth_"), seed_v)
	if kind.begins_with("horse_"):
		return _horse(kind.trim_prefix("horse_"), seed_v)
	if kind == "bed_river":
		return _river()
	if kind == "bed_murmur":
		return _murmur()
	return PackedFloat32Array()


static func _wav(pcm: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(pcm.size() * 2)
	var peak := 0.0001
	for v in pcm:
		peak = maxf(peak, absf(v))
	if loop:
		var gl := 0.5 / peak
		for i in pcm.size():
			bytes.encode_s16(i * 2, int(clampf(pcm[i] * gl, -1.0, 1.0) * 32767.0))
		return _wav_bytes(bytes, loop)
	# One-shots are matched by how loud they SOUND, not by their tallest sample: peak-normalised, a click on stone
	# sat 8-10 dB under a squelch in mud (measured, tools/analyze_foley.py). The loudest 40 ms of every take is
	# brought to the same level, peaks are rounded off by a soft clip, and the ceiling leaves 2 dB for the
	# peaks between samples (three kinds read over 0 dBFS true peak).
	var win := maxi(1, int(RATE * 0.04))
	var acc := 0.0
	var best := 0.0
	for i in pcm.size():
		acc += pcm[i] * pcm[i]
		if i >= win:
			acc -= pcm[i - win] * pcm[i - win]
		best = maxf(best, acc)
	var rms := sqrt(maxf(best, 0.0) / float(win))
	var g := minf(0.4 / maxf(rms, 0.0001), 2.6 / peak)
	for i in pcm.size():
		bytes.encode_s16(i * 2, int(tanh(pcm[i] * g) * 0.8 * 32767.0))
	return _wav_bytes(bytes, loop)


static func _wav_bytes(bytes: PackedByteArray, loop: bool) -> AudioStreamWAV:
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = BED_RATE if loop else RATE
	s.stereo = false
	s.data = bytes
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = bytes.size() / 2
	return s


# --- DSP ---------------------------------------------------------------------------------------------

static func _buf(seconds: float, rate := RATE) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * rate))
	return b


static func _noise(n: int, r: RandomNumberGenerator) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = r.randf_range(-1.0, 1.0)
	return out


static func _lp(x: PackedFloat32Array, fc: float, rate := RATE) -> PackedFloat32Array:
	var k := 1.0 - exp(-TAU * fc / rate)
	var y := PackedFloat32Array()
	y.resize(x.size())
	var s := 0.0
	for i in x.size():
		s += (x[i] - s) * k
		y[i] = s
	return y


static func _hp(x: PackedFloat32Array, fc: float, rate := RATE) -> PackedFloat32Array:
	var l := _lp(x, fc, rate)
	var y := PackedFloat32Array()
	y.resize(x.size())
	for i in x.size():
		y[i] = x[i] - l[i]
	return y


## RBJ band-pass (constant 0 dB peak gain).
static func _bp(x: PackedFloat32Array, f0: float, q: float, rate := RATE) -> PackedFloat32Array:
	var w := TAU * minf(f0, rate * 0.45) / rate
	var alpha := sin(w) / (2.0 * q)
	var a0 := 1.0 + alpha
	var b0 := alpha / a0
	var b2 := -alpha / a0
	var a1 := -2.0 * cos(w) / a0
	var a2 := (1.0 - alpha) / a0
	var y := PackedFloat32Array()
	y.resize(x.size())
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	for i in x.size():
		var xi := x[i]
		var v := b0 * xi + b2 * x2 - a1 * y1 - a2 * y2
		x2 = x1
		x1 = xi
		y2 = y1
		y1 = v
		y[i] = v
	return y


## Add `ev` into `out` at time t (s), scaled by g.
static func _add(out: PackedFloat32Array, t: float, ev: PackedFloat32Array, g: float, rate := RATE, wrap := false) -> void:
	var i0 := int(t * rate)
	var n := out.size()
	for k in ev.size():
		var idx := i0 + k
		if idx >= n:
			if not wrap:
				return
			idx %= n
		out[idx] += ev[k] * g


## A decaying sinusoid sweeping f0 -> f1 (the body of a thump or a ring).
static func _sine(dur: float, f0: float, f1: float, decay: float, attack := 0.001) -> PackedFloat32Array:
	var b := _buf(dur)
	var ph := 0.0
	for i in b.size():
		var t := float(i) / RATE
		ph += TAU * lerpf(f0, f1, minf(t / maxf(dur * 0.6, 0.001), 1.0)) / RATE
		b[i] = sin(ph) * exp(-t * decay) * smoothstep(0.0, attack, t)
	return b


## Noise through a band-pass with an exponential decay.
static func _burst(r: RandomNumberGenerator, dur: float, f0: float, q: float, decay: float, attack := 0.0005) -> PackedFloat32Array:
	var b := _bp(_noise(int(dur * RATE), r), f0, q)
	for i in b.size():
		var t := float(i) / RATE
		b[i] *= exp(-t * decay) * smoothstep(0.0, attack, t)
	return b


## Soft noise (low-passed) with a decay.
static func _thud_noise(r: RandomNumberGenerator, dur: float, fc: float, decay: float, attack := 0.002) -> PackedFloat32Array:
	var b := _lp(_noise(int(dur * RATE), r), fc)
	for i in b.size():
		var t := float(i) / RATE
		b[i] *= exp(-t * decay) * smoothstep(0.0, attack, t)
	return b


static func _j(r: RandomNumberGenerator, v: float, amt := 0.07) -> float:
	return v * (1.0 + r.randf_range(-amt, amt))


# --- hooves ------------------------------------------------------------------------------------------

static func _hoof(surface: String, seed_v: int) -> PackedFloat32Array:
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	var out := _buf(0.34)
	match surface:
		"grass":      # a dull, damp thud of hoof and turf, a rustle of blades behind it
			_add(out, 0.0, _sine(0.2, _j(r, 88.0), 48.0, 26.0, 0.002), 1.0)
			_add(out, 0.0, _thud_noise(r, 0.16, _j(r, 950.0), 38.0), 0.6)
			_add(out, 0.012, _burst(r, 0.12, _j(r, 3600.0), 0.8, 20.0, 0.004), 0.22)
		"road":       # packed earth and grit: a firm clop, small stones thrown off it
			_add(out, 0.0, _sine(0.18, _j(r, 105.0), 58.0, 32.0, 0.001), 0.8)
			_add(out, 0.0, _burst(r, 0.14, _j(r, 720.0), 1.6, 48.0, 0.0008), 0.9)
			_add(out, 0.0, _burst(r, 0.03, _j(r, 2400.0), 0.9, 160.0, 0.0004), 0.5)
			for g in 14:
				_add(out, r.randf_range(0.004, 0.11), _burst(r, 0.02, r.randf_range(3000.0, 6200.0), 2.0, 260.0, 0.0003), r.randf_range(0.06, 0.2))
		"stone":      # iron shoe on flags: a sharp click, then the hoof's rings, bright and short
			_add(out, 0.0, _hp(_noise(int(0.012 * RATE), r), 2200.0), 1.0)
			for m: Array in [[1250.0, 55.0, 0.75], [2250.0, 85.0, 0.55], [3500.0, 130.0, 0.3], [4600.0, 190.0, 0.18]]:
				_add(out, 0.0, _sine(0.2, _j(r, float(m[0])), _j(r, float(m[0])) * 0.98, float(m[1])), float(m[2]))
			_add(out, 0.0, _sine(0.14, _j(r, 140.0), 85.0, 44.0), 0.55)
			_add(out, 0.0, _burst(r, 0.05, _j(r, 1700.0), 2.0, 90.0, 0.0004), 0.5)
		"wood":       # boards over a void: a knock, and the hollow under it ringing
			_add(out, 0.0, _burst(r, 0.04, _j(r, 1500.0), 1.2, 120.0, 0.0004), 0.7)
			for m: Array in [[172.0, 20.0, 1.0], [305.0, 30.0, 0.65], [520.0, 42.0, 0.4], [840.0, 70.0, 0.2]]:
				_add(out, 0.0, _sine(0.3, _j(r, float(m[0])), _j(r, float(m[0])) * 0.97, float(m[1])), float(m[2]))
			_add(out, 0.0, _thud_noise(r, 0.08, 700.0, 70.0), 0.5)
		"water":      # a splashing ford: the hoof going in, spray thrown up, bubbles
			_add(out, 0.0, _burst(r, 0.22, _j(r, 1300.0), 0.45, 15.0, 0.004), 1.0)
			_add(out, 0.02, _burst(r, 0.16, _j(r, 3800.0), 0.6, 22.0, 0.008), 0.4)
			_add(out, 0.0, _sine(0.15, _j(r, 78.0), 50.0, 30.0), 0.55)
			for b in 4:
				var f := r.randf_range(450.0, 900.0)
				_add(out, r.randf_range(0.02, 0.15), _sine(0.07, f, f * r.randf_range(1.6, 2.4), 55.0, 0.003), r.randf_range(0.12, 0.3))
		"mud":         # a heavy squelch: the foot sinks, and sucks free
			_add(out, 0.0, _sine(0.2, _j(r, 70.0), 42.0, 20.0, 0.004), 0.8)
			_add(out, 0.0, _thud_noise(r, 0.2, _j(r, 520.0), 17.0, 0.008), 0.9)
			_add(out, 0.07, _sine(0.14, 150.0, _j(r, 420.0), 24.0, 0.01), 0.35)
			_add(out, 0.075, _burst(r, 0.1, _j(r, 1100.0), 1.2, 28.0, 0.01), 0.3)
	return out


# --- the wanderer's footfall textures ----------------------------------------------------------------
# A layer under the stone samples that the wanderer already has: what the ground adds, not the thud.

static func _step(surface: String, seed_v: int) -> PackedFloat32Array:
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	var out := _buf(0.3)
	match surface:
		"grass":
			_add(out, 0.0, _burst(r, 0.22, _j(r, 3200.0), 0.7, 14.0, 0.012), 0.8)
			_add(out, 0.03, _burst(r, 0.15, _j(r, 5200.0), 0.9, 20.0, 0.01), 0.4)
		"fen", "mud":
			_add(out, 0.0, _thud_noise(r, 0.22, _j(r, 600.0), 14.0, 0.008), 0.9)
			_add(out, 0.06, _sine(0.12, 170.0, _j(r, 380.0), 26.0, 0.01), 0.3)
		"ash":
			for g in 22:
				_add(out, r.randf_range(0.0, 0.14), _burst(r, 0.02, r.randf_range(1800.0, 4500.0), 1.5, 300.0, 0.0003), r.randf_range(0.1, 0.35))
			_add(out, 0.0, _thud_noise(r, 0.12, 1400.0, 40.0), 0.5)
		"salt":
			for g in 26:
				_add(out, r.randf_range(0.0, 0.16), _burst(r, 0.015, r.randf_range(4200.0, 8200.0), 2.2, 380.0, 0.0002), r.randf_range(0.1, 0.4))
			_add(out, 0.0, _burst(r, 0.05, 2600.0, 1.0, 80.0), 0.3)
		"road":
			for g in 12:
				_add(out, r.randf_range(0.0, 0.1), _burst(r, 0.02, r.randf_range(2600.0, 5600.0), 1.8, 280.0, 0.0003), r.randf_range(0.1, 0.3))
			_add(out, 0.0, _burst(r, 0.06, _j(r, 800.0), 1.4, 70.0), 0.6)
		"stone":
			_add(out, 0.0, _hp(_noise(int(0.008 * RATE), r), 2500.0), 0.8)
			_add(out, 0.0, _sine(0.12, _j(r, 1500.0), 1450.0, 80.0), 0.45)
			_add(out, 0.0, _sine(0.1, _j(r, 2700.0), 2650.0, 110.0), 0.25)
		"wood":
			_add(out, 0.0, _sine(0.2, _j(r, 190.0), 180.0, 26.0), 0.8)
			_add(out, 0.0, _sine(0.16, _j(r, 340.0), 330.0, 38.0), 0.5)
			_add(out, 0.0, _burst(r, 0.03, 1700.0, 1.2, 140.0, 0.0004), 0.5)
		"water":
			_add(out, 0.0, _burst(r, 0.26, _j(r, 1500.0), 0.5, 11.0, 0.006), 1.0)
			_add(out, 0.02, _burst(r, 0.15, 4200.0, 0.6, 20.0, 0.006), 0.35)
			for b in 3:
				var f := r.randf_range(500.0, 1000.0)
				_add(out, r.randf_range(0.03, 0.16), _sine(0.06, f, f * 2.0, 60.0, 0.003), 0.16)
	return out


# --- cloth -------------------------------------------------------------------------------------------

static func _cloth(kind: String, seed_v: int) -> PackedFloat32Array:
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	var out := _buf(0.4)
	match kind:
		"walk":     # a coat's hem and a cloak dragging past: a soft, low swish
			_add(out, 0.0, _burst(r, 0.3, _j(r, 1500.0), 0.5, 9.0, 0.06), 0.8)
			_add(out, 0.02, _thud_noise(r, 0.25, 500.0, 12.0, 0.05), 0.4)
		"run":      # the same, quicker and brighter, with the pouches' knock
			_add(out, 0.0, _burst(r, 0.22, _j(r, 2100.0), 0.5, 14.0, 0.03), 0.9)
			_add(out, 0.0, _thud_noise(r, 0.2, 700.0, 18.0, 0.03), 0.4)
			_add(out, 0.04, _sine(0.08, _j(r, 260.0), 200.0, 50.0), 0.15)
		"flap":     # a landing: the cloak catches up with the body and snaps
			_add(out, 0.0, _burst(r, 0.3, _j(r, 1200.0), 0.45, 11.0, 0.01), 1.0)
			_add(out, 0.01, _burst(r, 0.05, 2800.0, 0.8, 80.0, 0.002), 0.35)
			_add(out, 0.0, _thud_noise(r, 0.3, 450.0, 11.0, 0.015), 0.6)
	return out


# --- the horse, its tack and its breath -------------------------------------------------------------

static func _horse(kind: String, seed_v: int) -> PackedFloat32Array:
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	var out := _buf(0.7)
	match kind:
		"jingle":    # bit rings, buckles and the stirrup iron: a few small bright metals, shaken
			var n := r.randi_range(4, 7)
			for k in n:
				var f := r.randf_range(2300.0, 6400.0)
				var t0 := r.randf_range(0.0, 0.13)
				var g := r.randf_range(0.25, 1.0)
				_add(out, t0, _sine(0.3, f, f * 0.995, r.randf_range(14.0, 40.0), 0.0004), g)
				_add(out, t0, _sine(0.2, f * 2.76, f * 2.74, r.randf_range(35.0, 80.0), 0.0004), g * 0.3)
			_add(out, 0.0, _burst(r, 0.04, 5000.0, 0.8, 120.0, 0.0004), 0.35)
		"creak":     # leather taking the rider's weight
			var sw := _buf(0.3)
			var ph := 0.0
			var f0 := r.randf_range(380.0, 620.0)
			for i in sw.size():
				var t := float(i) / RATE
				ph += TAU * (f0 * (1.0 + 0.5 * t / 0.3) + 25.0 * sin(t * 90.0)) / RATE
				sw[i] = (fmod(ph, TAU) / PI - 1.0) * smoothstep(0.0, 0.05, t) * (1.0 - smoothstep(0.12, 0.3, t))
			_add(out, 0.0, _bp(sw, 1100.0, 1.2), 0.5)
		"snort":     # a blow through the nostrils: a burst of air with a flutter, then a short settle
			var n_b := _noise(int(0.5 * RATE), r)
			var body := _bp(n_b, _j(r, 1100.0), 0.5)
			var hi := _bp(n_b, 3300.0, 0.7)
			var fl_f := r.randf_range(24.0, 32.0)
			var s := _buf(0.5)
			for i in s.size():
				var t := float(i) / RATE
				var env := smoothstep(0.0, 0.02, t) * exp(-t * 7.0)
				var flutter := 0.55 + 0.45 * sin(TAU * fl_f * t) * (1.0 - smoothstep(0.1, 0.4, t))
				s[i] = (body[i] + 0.4 * hi[i] * exp(-t * 6.0)) * env * flutter
			_add(out, 0.0, s, 1.0)
			_add(out, 0.0, _sine(0.2, 140.0, 90.0, 18.0, 0.01), 0.3)
		"breath":    # a long blown breath, in the stride at the gallop: air in the throat
			var s := _buf(0.4)
			var nb := _bp(_noise(s.size(), r), _j(r, 900.0), 0.6)
			for i in s.size():
				var t := float(i) / RATE
				s[i] = nb[i] * sin(PI * clampf(t / 0.36, 0.0, 1.0)) * (0.75 + 0.25 * sin(TAU * 17.0 * t))
			_add(out, 0.0, s, 1.0)
		"grunt":     # the effort of a take-off: voiced, low, short
			var s := _buf(0.3)
			var ph := 0.0
			var n_g := _noise(s.size(), r)
			for i in s.size():
				var t := float(i) / RATE
				ph += TAU * (95.0 - 25.0 * t / 0.3) / RATE
				s[i] = (sin(ph) + 0.5 * sin(2.0 * ph) + 0.3 * sin(3.0 * ph) + 0.25 * n_g[i]) * sin(PI * clampf(t / 0.28, 0.0, 1.0))
			_add(out, 0.0, _lp(s, 900.0), 1.0)
		"thump":     # the whole body arriving: weight, not hooves
			_add(out, 0.0, _sine(0.35, 78.0, 38.0, 14.0, 0.004), 1.0)
			_add(out, 0.0, _thud_noise(r, 0.25, 420.0, 18.0, 0.004), 0.7)
			_add(out, 0.01, _burst(r, 0.2, 1500.0, 0.5, 22.0, 0.004), 0.25)
	return out


# --- ambience beds -----------------------------------------------------------------------------------

## A river heard from its bank: a broad rush with the flow's slow swell, and gurgles and burbles on top.
## 12 s, seamless.
static func _river() -> PackedFloat32Array:
	var rate := BED_RATE
	var n := int(12.0 * rate)
	var r := RandomNumberGenerator.new()
	r.seed = 90210
	var nz := _noise(n, r)
	var rush := _lp(nz, 2600.0, rate)
	var mid := _bp(nz, 700.0, 0.6, rate)
	var air := _hp(_bp(nz, 5200.0, 0.5, rate), 3000.0, rate)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / rate
		var sw := 0.75 + 0.25 * sin(TAU * t / 12.0 * 2.0 + 0.7) + 0.12 * sin(TAU * t / 12.0 * 5.0)
		out[i] = (rush[i] * 0.5 + mid[i] * 0.6 * (0.7 + 0.3 * sin(TAU * t / 12.0 * 3.0)) + air[i] * 0.22) * sw
	for b in 70:      # burbles: tiny rising chirps over the rush
		var f := r.randf_range(380.0, 1100.0)
		var d := r.randf_range(0.05, 0.12)
		var ev := PackedFloat32Array()
		ev.resize(int(d * rate))
		var ph := 0.0
		for k in ev.size():
			var tt := float(k) / rate
			ph += TAU * f * (1.0 + 2.2 * tt / d) / rate
			ev[k] = sin(ph) * sin(PI * tt / d)
		_add(out, r.randf() * 12.0, ev, r.randf_range(0.04, 0.16), rate, true)
	return out


## A settlement heard from the edge: a few people talking, far off. Voiced syllables through vowel formants in
## words with pauses, the highs rolled off for the distance, a low room-tone under them. 14 s, seamless.
static func _murmur() -> PackedFloat32Array:
	var rate := BED_RATE
	var dur := 14.0
	var n := int(dur * rate)
	var r := RandomNumberGenerator.new()
	r.seed = 4417
	var out := PackedFloat32Array()
	out.resize(n)
	var vowels := [[730.0, 1090.0], [530.0, 1840.0], [270.0, 2290.0], [570.0, 840.0], [300.0, 870.0], [660.0, 1720.0]]
	for talker in 4:
		var f0: float = [118.0, 205.0, 150.0, 175.0][talker]
		var t := r.randf_range(0.0, 1.5)
		while t < dur - 0.2:
			var syl := r.randi_range(2, 6)               # a phrase of syllables, then a breath
			for s in syl:
				var d := r.randf_range(0.09, 0.2)
				var m := int(d * rate)
				var src := PackedFloat32Array()
				src.resize(m)
				var ph := 0.0
				var pf := f0 * r.randf_range(0.85, 1.2)
				for k in m:
					var tt := float(k) / rate
					ph += pf * (1.0 + 0.06 * sin(tt * 40.0)) / rate
					src[k] = (fposmod(ph, 1.0) * 2.0 - 1.0) * sin(PI * tt / d)
				var vw: Array = vowels[r.randi() % vowels.size()]
				var y1 := _bp(src, float(vw[0]), 4.0, rate)
				var y2 := _bp(src, float(vw[1]), 5.0, rate)
				for k in m:
					y1[k] = y1[k] * 1.0 + y2[k] * 0.6
				_add(out, t, y1, 0.5 * r.randf_range(0.5, 1.0), rate, true)
				t += d + r.randf_range(0.0, 0.05)
			t += r.randf_range(0.5, 2.6)
	out = _lp(out, 1700.0, rate)
	var room := _lp(_noise(n, r), 380.0, rate)
	for i in n:
		out[i] = out[i] * 1.3 + room[i] * 0.14
	return _seam(out, 1.0, rate)


## Cross-fade the last `fade` seconds into the start: a loop with no click.
static func _seam(x: PackedFloat32Array, fade: float, rate: int) -> PackedFloat32Array:
	var nf := int(fade * rate)
	var n := x.size() - nf
	var y := PackedFloat32Array()
	y.resize(n)
	for i in n:
		y[i] = x[i]
	for i in nf:
		var k := float(i) / nf
		y[i] = x[i] * sin(k * PI * 0.5) + x[n + i] * cos(k * PI * 0.5)
	return y
