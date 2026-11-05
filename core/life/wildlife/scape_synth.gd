extends RefCounted
## Procedural sounds for the regional soundscape, the weather's drama and the night's phenomena
## (life system r28). Everything is synthesised from noise, filters and oscillators: no recorded or
## licensed audio. Deterministic (fixed seeds), built once and kept in GenCache as 16-bit PCM, so
## after the first dev run a sound is a file read (prewarm() runs at load under the loading screen).
## Load by path (no class_name):  const ScapeSynth := preload("res://core/life/wildlife/scape_synth.gd")
##
##   beds (seamless loops)  leaves, fen, chasm, high_wind, meadow, hearth, rain_leaves, rain_roof,
##                          rain_water
##   spots (one-shots)      twig, creak, drip, pebbles, blurp, bittern, nightjar, vixen, bellow,
##                          howl, bones, whisper, bell_far, peewit, pounce, hooves, squeak_soft
##   weather / sky          crack (near lightning: crack + rolling rumble), surge (the rift's swell),
##                          bolide (a fireball's far boom), chime (a will-o'-wisp), wisp_hum (loop)
##   music                  harp (A3 pluck), bell (A4), pad_rest, pad_dark (loops), pulse (heartbeat)

const RATE := 22050
const SELF := "res://core/life/wildlife/scape_synth.gd"
const GenCache := preload("res://core/world/realm/gen_cache.gd")

const BEDS := ["leaves", "fen", "chasm", "high_wind", "meadow", "hearth", "rain_leaves", "rain_roof", "rain_water", "wisp_hum", "pad_rest", "pad_dark"]
const SPOTS := ["twig", "creak", "drip", "pebbles", "blurp", "bittern", "nightjar", "vixen", "bellow", "howl", "bones", "whisper",
	"bell_far", "peewit", "pounce", "hooves", "squeak_soft", "crack", "surge", "bolide", "chime", "harp", "bell", "pulse"]
const VERSION := 3

static var _cache := {}
static var built_ms := 0.0          ## time spent synthesising (not loading) this session


static func kinds() -> Array:
	return BEDS + SPOTS


## Build or load everything now (Ambience calls this during the load).
static func prewarm() -> void:
	for k: String in kinds():
		stream(k)


static func stream(kind: String) -> AudioStreamWAV:
	if _cache.has(kind):
		return _cache[kind]
	var key := "scape_%s_v%d" % [kind, VERSION]
	var data: Variant = GenCache.load_var(key, SELF)
	var s: AudioStreamWAV
	if data is PackedByteArray and (data as PackedByteArray).size() > 64:
		s = _wav_bytes(data)
	else:
		var t0 := Time.get_ticks_usec()
		var pcm := build(kind)
		if pcm.is_empty():
			return null
		s = _wav(pcm)
		built_ms += float(Time.get_ticks_usec() - t0) / 1000.0
		GenCache.save_var(key, SELF, s.data)
	if kind in BEDS:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = s.data.size() / 2
	_cache[kind] = s
	return s


## A stable fingerprint of a sound's samples (tests: synthesis is deterministic).
static func fingerprint(kind: String) -> int:
	var s := stream(kind)
	return hash(s.data) if s != null else 0


static func build(kind: String) -> PackedFloat32Array:
	match kind:
		"leaves": return _leaves()
		"fen": return _fen()
		"chasm": return _chasm()
		"high_wind": return _high_wind()
		"meadow": return _meadow()
		"hearth": return _hearth()
		"rain_leaves": return _rain_leaves()
		"rain_roof": return _rain_roof()
		"rain_water": return _rain_water()
		"wisp_hum": return _wisp_hum()
		"twig": return _twig()
		"creak": return _creak()
		"drip": return _drip()
		"pebbles": return _pebbles()
		"blurp": return _blurp()
		"bittern": return _bittern()
		"nightjar": return _nightjar()
		"vixen": return _vixen()
		"bellow": return _bellow()
		"howl": return _howl()
		"bones": return _bones()
		"whisper": return _whisper()
		"bell_far": return _bell(196.0, 6.0, 0.35, 41)
		"peewit": return _peewit()
		"pounce": return _pounce()
		"hooves": return _hooves()
		"squeak_soft": return _squeak_soft()
		"crack": return _crack()
		"surge": return _surge()
		"bolide": return _bolide()
		"chime": return _chime()
		"harp": return _harp(220.0)
		"bell": return _bell(440.0, 5.0, 1.0, 43)
		"pad_rest": return _pad_rest()
		"pad_dark": return _pad_dark()
		"pulse": return _pulse()
	return PackedFloat32Array()


# --- encoding ---------------------------------------------------------------------------------------

static func _wav(pcm: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(pcm.size() * 2)
	var peak := 0.0001
	for v in pcm:
		peak = maxf(peak, absf(v))
	var g := 0.9 / peak
	for i in pcm.size():
		bytes.encode_s16(i * 2, int(clampf(pcm[i] * g, -1.0, 1.0) * 32767.0))
	return _wav_bytes(bytes)


static func _wav_bytes(b: PackedByteArray) -> AudioStreamWAV:
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = b
	return s


# --- helpers ----------------------------------------------------------------------------------------

static func _buf(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * RATE))
	return b


static func _noise(n: int, seed_v: int) -> PackedFloat32Array:
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = r.randf_range(-1.0, 1.0)
	return out


## RBJ biquad band-pass (constant 0 dB peak).
static func _bp(x: PackedFloat32Array, f0: float, q: float) -> PackedFloat32Array:
	var w := TAU * f0 / RATE
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


## One-pole low-pass, k = 1 - exp(-2 pi fc / rate).
static func _lp(x: PackedFloat32Array, fc: float) -> PackedFloat32Array:
	var k := 1.0 - exp(-TAU * fc / RATE)
	var y := PackedFloat32Array()
	y.resize(x.size())
	var s := 0.0
	for i in x.size():
		s += (x[i] - s) * k
		y[i] = s
	return y


static func _hp(x: PackedFloat32Array, fc: float) -> PackedFloat32Array:
	var l := _lp(x, fc)
	var y := PackedFloat32Array()
	y.resize(x.size())
	for i in x.size():
		y[i] = x[i] - l[i]
	return y


static func _mix(a: PackedFloat32Array, b: PackedFloat32Array, gb: float) -> void:
	for i in mini(a.size(), b.size()):
		a[i] += b[i] * gb


## Cross-fade the last `fade` seconds into the start: a seamless loop.
static func _seam(x: PackedFloat32Array, fade: float) -> PackedFloat32Array:
	var nf := int(fade * RATE)
	var n := x.size() - nf
	var y := x.slice(0, n)
	for i in nf:
		var t := float(i) / float(nf)
		y[i] = x[i] * sqrt(t) + x[n + i] * sqrt(1.0 - t)
	return y


## Add a short event at time t (wrapping round the buffer for loops).
static func _add(out: PackedFloat32Array, t: float, ev: PackedFloat32Array, g: float, wrap := true) -> void:
	var i0 := int(t * RATE)
	var n := out.size()
	for k in ev.size():
		var idx := i0 + k
		if idx >= n:
			if not wrap:
				return
			idx %= n
		out[idx] += ev[k] * g


static func _env(t: float, a: float, d: float) -> float:
	if t < 0.0 or t > d:
		return 0.0
	return smoothstep(0.0, a, t) * (1.0 - smoothstep(d * 0.55, d, t))


## A decaying sine tick (drops, clicks, knocks).
static func _tick(f: float, decay: float, dur: float) -> PackedFloat32Array:
	var b := _buf(dur)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = sin(TAU * f * t) * exp(-t * decay)
	return b


# --- beds -------------------------------------------------------------------------------------------

## Wind in leaves: a high rustle (band-passed noise) that swells in gusts, with leaf flutter.
static func _leaves() -> PackedFloat32Array:
	var n := int(RATE * 13.0)
	var nz := _noise(n, 211)
	var hi := _bp(nz, 3200.0, 0.7)
	var mid := _bp(nz, 1100.0, 0.9)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var sw := 0.45 + 0.3 * sin(TAU * t / 6.5) + 0.25 * sin(TAU * t / 3.25 + 1.1)
		var flut := 0.75 + 0.25 * sin(TAU * 11.0 * t + sin(TAU * 0.7 * t) * 3.0)
		out[i] = (hi[i] * 0.8 * flut + mid[i] * 0.45) * sw * sw
	return _seam(out, 1.2)


## The fen at night: a drone of insects (dense narrow buzzes), water lapping at the banks, a low hum.
static func _fen() -> PackedFloat32Array:
	var n := int(RATE * 12.0)
	var out := PackedFloat32Array()
	out.resize(n)
	var r := RandomNumberGenerator.new()
	r.seed = 223
	# insects: a few voices, each a buzz with its own slow beat
	for v in 6:
		var f := r.randf_range(2600.0, 5200.0)
		var am := r.randf_range(18.0, 34.0)
		var slow := r.randf_range(0.1, 0.3)
		var ph := r.randf_range(0.0, TAU)
		var g := r.randf_range(0.05, 0.12)
		for i in n:
			var t := float(i) / RATE
			var e := 0.5 + 0.5 * sin(TAU * slow * t + ph)
			out[i] += sin(TAU * f * t) * (0.6 + 0.4 * sin(TAU * am * t)) * e * e * g
	# lapping: low-passed noise in soft, irregular laps
	var lap := _lp(_noise(n, 227), 380.0)
	for i in n:
		var t := float(i) / RATE
		var e := maxf(0.0, sin(TAU * t / 2.3)) * (0.6 + 0.4 * sin(TAU * t / 5.7))
		out[i] += lap[i] * e * 2.2
	# a low marsh hum
	var hum := _lp(_noise(n, 229), 90.0)
	_mix(out, hum, 4.0)
	return _seam(out, 1.5)


## Down in the Ashen Rift: the lava's deep roar, slow surges, bubbles bursting, a hot hiss.
static func _chasm() -> PackedFloat32Array:
	var n := int(RATE * 14.0)
	var nz := _noise(n, 233)
	var roar := _lp(_lp(nz, 70.0), 110.0)
	var hiss := _bp(nz, 2400.0, 0.5)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var sw := 0.65 + 0.35 * sin(TAU * t / 7.0) * sin(TAU * t / 3.5 + 0.6)
		out[i] = roar[i] * 14.0 * sw + hiss[i] * 0.12 * (0.5 + 0.5 * sw)
	var r := RandomNumberGenerator.new()
	r.seed = 239
	for k in 22:
		var b := _blurp_ev(r.randf_range(55.0, 120.0), r.randf_range(0.18, 0.4), r.randi())
		_add(out, r.randf_range(0.0, 14.0), b, r.randf_range(0.25, 0.7))
	return _seam(out, 1.5)


## High, cold wind on the summit and the Crowns: a howl whose pitch wanders, and a thin whistle.
static func _high_wind() -> PackedFloat32Array:
	var n := int(RATE * 15.0)
	var nz := _noise(n, 241)
	var out := PackedFloat32Array()
	out.resize(n)
	# a resonator whose centre sweeps (state-variable filter, coefficients per sample)
	var low := 0.0
	var band := 0.0
	for i in n:
		var t := float(i) / RATE
		var fc := 420.0 + 260.0 * sin(TAU * t / 5.0) + 140.0 * sin(TAU * t / 1.9 + 0.8)
		var f := 2.0 * sin(PI * fc / RATE)
		var q := 0.12
		low += f * band
		var high := nz[i] - low - q * band
		band += f * high
		var gust := 0.45 + 0.55 * pow(0.5 + 0.5 * sin(TAU * t / 7.5), 2.0)
		out[i] = band * 0.35 * gust
	var body := _lp(nz, 260.0)
	for i in n:
		var t := float(i) / RATE
		out[i] += body[i] * 2.4 * (0.6 + 0.4 * sin(TAU * t / 5.0 + 2.0))
	var wh := _bp(nz, 1650.0, 25.0)
	for i in n:
		var t := float(i) / RATE
		out[i] += wh[i] * 0.5 * pow(maxf(0.0, sin(TAU * t / 3.75)), 3.0)
	return _seam(out, 1.5)


## The meadow round Hearthward: grasshoppers' long trills under a light breeze.
static func _meadow() -> PackedFloat32Array:
	var n := int(RATE * 10.0)
	var out := PackedFloat32Array()
	out.resize(n)
	var r := RandomNumberGenerator.new()
	r.seed = 251
	for v in 5:
		var f := r.randf_range(2900.0, 3800.0)
		var rate := r.randf_range(48.0, 70.0)
		var on := r.randf_range(1.2, 3.0)
		var off := r.randf_range(0.8, 2.5)
		var g := r.randf_range(0.25, 0.6)
		var t0 := r.randf_range(0.0, on + off)
		while t0 < 10.0:
			var ns := int(on * RATE)
			var i0 := int(t0 * RATE)
			for k in ns:
				var lt := float(k) / RATE
				var e := smoothstep(0.0, 0.15, lt) * (1.0 - smoothstep(on - 0.2, on, lt))
				var am := pow(maxf(0.0, sin(TAU * rate * lt)), 4.0)
				out[(i0 + k) % n] += sin(TAU * f * lt) * am * e * g
			t0 += on + off * r.randf_range(0.7, 1.3)
	var breeze := _bp(_noise(n, 257), 700.0, 0.6)
	for i in n:
		var t := float(i) / RATE
		out[i] += breeze[i] * 0.18 * (0.6 + 0.4 * sin(TAU * t / 5.0))
	return _seam(out, 1.0)


## A room with a fire in it (the Kindled Keg): a warm low room tone and the hearth's crackle.
static func _hearth() -> PackedFloat32Array:
	var n := int(RATE * 9.0)
	var out := _lp(_lp(_noise(n, 263), 140.0), 220.0)
	for i in n:
		out[i] *= 5.0
	var hiss := _bp(_noise(n, 269), 1800.0, 0.7)
	_mix(out, hiss, 0.05)
	var r := RandomNumberGenerator.new()
	r.seed = 271
	for k in 70:
		var f := r.randf_range(900.0, 3500.0)
		var ev := _tick(f, r.randf_range(300.0, 900.0), 0.03)
		var nz := _noise(ev.size(), r.randi())
		for i in ev.size():
			ev[i] = ev[i] * 0.4 + nz[i] * exp(-float(i) / RATE * 400.0)
		_add(out, r.randf_range(0.0, 9.0), ev, r.randf_range(0.1, 0.6) * (2.0 if r.randf() < 0.1 else 1.0))
	return _seam(out, 0.8)


## Rain on leaves: heavy, uneven drops pattering on a canopy, and the hiss under it.
static func _rain_leaves() -> PackedFloat32Array:
	var n := int(RATE * 8.0)
	var out := _bp(_noise(n, 281), 1800.0, 0.5)
	for i in n:
		out[i] *= 0.25
	var r := RandomNumberGenerator.new()
	r.seed = 283
	for k in 1400:
		var f := r.randf_range(700.0, 2600.0)
		var ev := _tick(f, r.randf_range(150.0, 400.0), 0.04)
		_add(out, r.randf_range(0.0, 8.0), ev, r.randf_range(0.05, 0.4))
	return _seam(out, 0.6)


## Rain on a roof (heard from inside): dull drumming on boards and thatch, a gutter's trickle.
static func _rain_roof() -> PackedFloat32Array:
	var n := int(RATE * 8.0)
	var out := _lp(_noise(n, 293), 500.0)
	for i in n:
		out[i] *= 0.8
	var r := RandomNumberGenerator.new()
	r.seed = 307
	for k in 1800:
		var f := r.randf_range(140.0, 420.0)
		var ev := _tick(f, r.randf_range(60.0, 140.0), 0.06)
		_add(out, r.randf_range(0.0, 8.0), ev, r.randf_range(0.05, 0.3))
	var trickle := _bp(_noise(n, 311), 1300.0, 3.0)
	for i in n:
		var t := float(i) / RATE
		out[i] += trickle[i] * 0.35 * (0.6 + 0.4 * sin(TAU * 3.1 * t) * sin(TAU * 0.4 * t))
	return _seam(out, 0.6)


## Rain on open water (the fen pools): bright plinks over a soft hiss.
static func _rain_water() -> PackedFloat32Array:
	var n := int(RATE * 8.0)
	var out := _hp(_noise(n, 313), 2500.0)
	for i in n:
		out[i] *= 0.18
	var r := RandomNumberGenerator.new()
	r.seed = 317
	for k in 900:
		var f0 := r.randf_range(900.0, 2800.0)
		var d := 0.05
		var ev := _buf(d)
		var ph := 0.0
		for i in ev.size():
			var t := float(i) / RATE
			ph += TAU * f0 * (1.0 + 2.5 * t / d) / RATE        # the bubble's rising chirp
			ev[i] = sin(ph) * exp(-t * 90.0)
		_add(out, r.randf_range(0.0, 8.0), ev, r.randf_range(0.05, 0.35))
	return _seam(out, 0.6)


## A will-o'-wisp's hum: two glassy tones beating slowly with a breathy shimmer.
static func _wisp_hum() -> PackedFloat32Array:
	var n := int(RATE * 6.0)
	var out := PackedFloat32Array()
	out.resize(n)
	var sh := _bp(_noise(n, 331), 3000.0, 4.0)
	for i in n:
		var t := float(i) / RATE
		var a := sin(TAU * 660.0 * t) + sin(TAU * 663.0 * t + 0.4) * 0.8 + sin(TAU * 990.0 * t) * 0.25
		out[i] = a * 0.25 * (0.7 + 0.3 * sin(TAU * t / 3.0)) + sh[i] * 0.15
	return _seam(out, 0.8)


# --- spots ------------------------------------------------------------------------------------------

## A twig snapping under something unseen in the wood.
static func _twig() -> PackedFloat32Array:
	var out := _buf(0.4)
	var nz := _noise(out.size(), 401)
	var cracks := [0.0, 0.025, 0.06]
	for c: float in cracks:
		var i0 := int(c * RATE)
		for k in int(0.03 * RATE):
			var t := float(k) / RATE
			out[i0 + k] += nz[i0 + k] * exp(-t * 180.0)
	var b := _bp(out, 2200.0, 1.2)
	var l := _bp(out, 600.0, 1.0)
	_mix(b, l, 0.6)
	return b


## An old trunk creaking in the wind: a slow stick-slip groan.
static func _creak() -> PackedFloat32Array:
	var d := 1.6
	var out := _buf(d)
	var ph := 0.0
	var nz := _noise(out.size(), 409)
	for i in out.size():
		var t := float(i) / RATE
		var f := 7.0 + 18.0 * sin(PI * t / d)        # stick-slip rate rises and falls
		ph += f / RATE
		var pulse := pow(fmod(ph, 1.0), 6.0)
		out[i] = (pulse * 2.0 - 0.3 + nz[i] * 0.2) * _env(t, 0.2, d)
	var a := _bp(out, 340.0, 4.0)
	var b := _bp(out, 820.0, 5.0)
	_mix(a, b, 0.6)
	return a


## A drop falling into a still pool in the dark (the Ossuary, caves): a bright rising plink.
static func _drip() -> PackedFloat32Array:
	var out := _buf(0.5)
	var ph := 0.0
	for i in out.size():
		var t := float(i) / RATE
		ph += TAU * (900.0 + 1400.0 * minf(t / 0.04, 1.0)) / RATE
		out[i] = sin(ph) * exp(-t * 28.0) + sin(TAU * 2900.0 * t) * exp(-t * 200.0) * 0.3
	return out


## Stones skittering down a slope (the Crossing, the summit).
static func _pebbles() -> PackedFloat32Array:
	var out := _buf(1.6)
	var r := RandomNumberGenerator.new()
	r.seed = 419
	var t := 0.0
	var gap := 0.03
	while t < 1.4:
		var ev := _tick(r.randf_range(1500.0, 4200.0), r.randf_range(250.0, 600.0), 0.05)
		var nz := _noise(ev.size(), r.randi())
		for i in ev.size():
			ev[i] = ev[i] * 0.6 + nz[i] * exp(-float(i) / RATE * 500.0) * 0.5
		_add(out, t, ev, (1.0 - t / 1.5) * r.randf_range(0.4, 1.0), false)
		gap *= r.randf_range(1.05, 1.3)
		t += gap * r.randf_range(0.5, 1.5)
	return out


static func _blurp_ev(f: float, d: float, seed_v: int) -> PackedFloat32Array:
	var ev := _buf(d)
	var nz := _lp(_noise(ev.size(), seed_v), 300.0)
	var ph := 0.0
	for i in ev.size():
		var t := float(i) / RATE
		ph += TAU * f * (1.0 + 0.8 * t / d) / RATE
		ev[i] = (sin(ph) * 0.8 + nz[i] * 3.0) * sin(PI * t / d) * exp(-t * 4.0)
	return ev


## Lava bubbling up and bursting.
static func _blurp() -> PackedFloat32Array:
	var out := _blurp_ev(70.0, 0.5, 421)
	var pop := _blurp_ev(140.0, 0.18, 431)
	_add(out, 0.3, pop, 0.7, false)
	return out


## A bittern booming in the reeds: a low hollow "oo-WOOMP", far carrying.
static func _bittern() -> PackedFloat32Array:
	var out := _buf(2.6)
	var nz := _lp(_noise(out.size(), 433), 200.0)
	for b in 3:
		var st := 0.1 + float(b) * 0.85
		var ph := 0.0
		for k in int(0.7 * RATE):
			var t := float(k) / RATE
			var e := 0.0
			if t < 0.12:
				e = 0.35 * smoothstep(0.0, 0.05, t)                      # the in-breath "oo"
			else:
				e = smoothstep(0.12, 0.2, t) * exp(-(t - 0.2) * 5.0)     # the boom
			ph += TAU * (128.0 - 18.0 * t) / RATE
			var i := int(st * RATE) + k
			if i < out.size():
				out[i] += (sin(ph) + 0.3 * sin(ph * 2.0) + nz[i] * 0.8) * e
	return out


## A nightjar churring over the heath: a long, rapid wooden trill that shifts pitch.
static func _nightjar() -> PackedFloat32Array:
	var d := 3.4
	var out := _buf(d)
	var ph := 0.0
	for i in out.size():
		var t := float(i) / RATE
		var shift := 1.0 if fmod(t, 1.4) < 0.9 else 1.12
		var rate := 28.0 * shift
		var am := pow(maxf(0.0, sin(TAU * rate * t)), 3.0)
		ph += TAU * 1250.0 * shift / RATE
		out[i] = (sin(ph) + 0.4 * sin(ph * 1.5)) * am * _env(t, 0.1, d)
	return _bp(out, 1350.0, 1.5)


## A vixen's scream: a hoarse, rising-falling cry, twice.
static func _vixen() -> PackedFloat32Array:
	var out := _buf(1.9)
	var nz := _noise(out.size(), 443)
	for c in 2:
		var st := 0.05 + float(c) * 0.95
		var d := 0.62
		var ph := 0.0
		for k in int(d * RATE):
			var t := float(k) / RATE
			var f := 780.0 + 520.0 * sin(PI * t / d) - 200.0 * t
			ph = fmod(ph + f / RATE, 1.0)
			var i := int(st * RATE) + k
			out[i] += ((ph * 2.0 - 1.0) * 0.6 + nz[i] * 0.5) * _env(t, 0.03, d) * (0.8 + 0.2 * sin(TAU * 31.0 * t))
	var a := _bp(out, 1300.0, 2.5)
	var b := _bp(out, 2700.0, 3.0)
	_mix(a, b, 0.6)
	return a


## A red stag's bellow: a deep, rough roar with a few grunts after it.
static func _bellow() -> PackedFloat32Array:
	var out := _buf(3.2)
	var nz := _noise(out.size(), 449)
	var calls := [[0.05, 1.5, 1.0], [1.75, 0.35, 0.6], [2.25, 0.3, 0.5], [2.7, 0.28, 0.4]]
	for c: Array in calls:
		var st: float = c[0]
		var d: float = c[1]
		var ph := 0.0
		for k in int(d * RATE):
			var t := float(k) / RATE
			var f := 95.0 + 45.0 * sin(PI * t / d)
			ph = fmod(ph + f / RATE, 1.0)
			var i := int(st * RATE) + k
			if i >= out.size():
				break
			var rough := 0.7 + 0.3 * sin(TAU * 27.0 * t)
			out[i] += ((ph * 2.0 - 1.0) + nz[i] * 0.25) * _env(t, 0.06, d) * rough * float(c[2])
	var a := _bp(out, 380.0, 2.2)
	var b := _bp(out, 950.0, 3.0)
	var l := _lp(out, 220.0)
	_mix(a, b, 0.35)
	_mix(a, l, 1.1)
	return _lp(a, 1600.0)


## A wolf howling far off in the Crowns: a long pure rising-falling tone, a second voice under it.
static func _howl() -> PackedFloat32Array:
	var d := 4.2
	var out := _buf(d)
	var nz := _lp(_noise(out.size(), 457), 900.0)
	var ph := 0.0
	var ph2 := 0.0
	for i in out.size():
		var t := float(i) / RATE
		var k := t / d
		var f := 420.0 + 230.0 * smoothstep(0.0, 0.25, k) - 120.0 * smoothstep(0.55, 1.0, k)
		f *= 1.0 + 0.01 * sin(TAU * 5.5 * t)
		ph += TAU * f / RATE
		ph2 += TAU * f * 0.79 / RATE
		var e := _env(t, 0.4, d)
		var e2 := _env(t - 0.9, 0.5, d - 1.0) * 0.4
		out[i] = (sin(ph) + 0.15 * sin(ph * 2.0)) * e + sin(ph2) * e2 + nz[i] * e * 0.25
	return out


## Bones shifting somewhere in the crypt: dry hollow knocks rattling to rest.
static func _bones() -> PackedFloat32Array:
	var out := _buf(1.2)
	var r := RandomNumberGenerator.new()
	r.seed = 461
	var t := 0.0
	var g := 1.0
	while t < 1.0 and g > 0.05:
		var f := r.randf_range(520.0, 1100.0)
		var ev := _tick(f, r.randf_range(70.0, 140.0), 0.08)
		var ev2 := _tick(f * 2.63, 200.0, 0.05)
		_mix(ev, ev2, 0.4)
		_add(out, t, ev, g, false)
		t += r.randf_range(0.04, 0.16)
		g *= r.randf_range(0.65, 0.9)
	return out


## A breathy whisper with no words (formant-shaped noise), for the crypt's dark.
static func _whisper() -> PackedFloat32Array:
	var d := 1.8
	var nz := _noise(int(d * RATE), 467)
	var out := _buf(d)
	var formants := [[700.0, 1200.0], [400.0, 2100.0], [550.0, 1700.0], [300.0, 2400.0]]
	var segs := 6
	var parts: Array = []
	for f: Array in formants:
		parts.append([_bp(nz, float(f[0]), 5.0), _bp(nz, float(f[1]), 6.0)])
	for i in out.size():
		var t := float(i) / RATE
		var seg := int(t / d * float(segs)) % formants.size()
		var p: Array = parts[seg]
		var syl := pow(maxf(0.0, sin(PI * fmod(t * float(segs) / d, 1.0))), 1.5)
		out[i] = ((p[0] as PackedFloat32Array)[i] + (p[1] as PackedFloat32Array)[i] * 0.7) * syl * _env(t, 0.15, d)
	return out


## A struck bell (inharmonic partials: hum, prime, tierce, quint, nominal).
static func _bell(f: float, d: float, bright: float, seed_v: int) -> PackedFloat32Array:
	var out := _buf(d)
	var parts := [[0.5, 0.6, 0.6], [1.0, 1.0, 1.0], [1.19, 0.5, 1.4], [1.5, 0.35, 1.8], [2.0, 0.5 * bright, 2.2], [2.74, 0.25 * bright, 3.0], [3.76, 0.12 * bright, 4.0]]
	var nz := _noise(out.size(), seed_v)
	for i in out.size():
		var t := float(i) / RATE
		var v := 0.0
		for p: Array in parts:
			v += sin(TAU * f * float(p[0]) * t + float(p[0])) * float(p[1]) * exp(-t * float(p[2]) * 6.0 / d)
		v += nz[i] * exp(-t * 300.0) * 0.4 * bright
		out[i] = v * smoothstep(0.0, 0.004, t)
	return out


## Lapwings' calls as a flock lifts: thin, wheezy "pee-wit"s from several birds.
static func _peewit() -> PackedFloat32Array:
	var out := _buf(1.8)
	var r := RandomNumberGenerator.new()
	r.seed = 479
	for c in 5:
		var st := r.randf_range(0.0, 1.2)
		var d := 0.32
		var base := r.randf_range(0.9, 1.1)
		var ph := 0.0
		var ev := _buf(d)
		for k in ev.size():
			var t := float(k) / RATE
			var f := (1800.0 + 1600.0 * sin(PI * minf(t / 0.2, 1.0))) * base - 900.0 * maxf(0.0, t - 0.2) / 0.12
			ph += TAU * f / RATE
			ev[k] = sin(ph) * _env(t, 0.02, d)
		_add(out, st, ev, r.randf_range(0.4, 1.0), false)
	return out


## A fox landing on its prey in long grass: a rustle and a soft thump.
static func _pounce() -> PackedFloat32Array:
	var out := _buf(0.6)
	var nz := _noise(out.size(), 487)
	var rustle := _bp(nz, 2600.0, 0.8)
	for i in out.size():
		var t := float(i) / RATE
		out[i] = rustle[i] * exp(-t * 9.0) * 0.8 + sin(TAU * (90.0 - 40.0 * t) * t) * exp(-t * 25.0)
	return out


## Hooves drumming away over soft ground (a herd bolting).
static func _hooves() -> PackedFloat32Array:
	var d := 2.4
	var out := _buf(d)
	var r := RandomNumberGenerator.new()
	r.seed = 491
	var t := 0.0
	var beat := 0
	while t < d - 0.1:
		var ev := _tick(r.randf_range(70.0, 110.0), r.randf_range(35.0, 55.0), 0.12)
		var nz := _lp(_noise(ev.size(), r.randi()), 1200.0)
		for i in ev.size():
			ev[i] += nz[i] * exp(-float(i) / RATE * 60.0) * 1.5
		_add(out, t, ev, (1.0 - t / d) * r.randf_range(0.6, 1.0), false)
		beat += 1
		t += 0.07 if beat % 4 != 0 else 0.2           # a gallop's four-beat stride
	return out


static func _squeak_soft() -> PackedFloat32Array:
	var out := _buf(0.35)
	for c in 2:
		var st := 0.02 + float(c) * 0.12
		for i in int(0.05 * RATE):
			var lt := float(i) / RATE
			var f := 5200.0 + 900.0 * sin(PI * lt / 0.05)
			out[int(st * RATE) + i] += sin(TAU * f * lt) * sin(PI * lt / 0.05)
	return out


# --- weather and sky --------------------------------------------------------------------------------

## Lightning close by: a tearing crack, a hard clap, then the long roll off the hills.
static func _crack() -> PackedFloat32Array:
	var d := 7.0
	var n := int(d * RATE)
	var nz := _noise(n, 503)
	var out := PackedFloat32Array()
	out.resize(n)
	# the tear: a burst of crackles over ~0.25 s
	var r := RandomNumberGenerator.new()
	r.seed = 509
	for k in 40:
		var t := r.randf_range(0.0, 0.25)
		var ev := _buf(0.012)
		var en := _noise(ev.size(), r.randi())
		for i in ev.size():
			ev[i] = en[i] * exp(-float(i) / RATE * 400.0)
		_add(out, t, ev, r.randf_range(0.4, 1.0), false)
	var lp := 0.0
	var lp2 := 0.0
	var swells := [[0.2, 0.7, 1.4], [0.6, 2.2, 0.9], [2.0, 3.0, 0.6], [3.8, 2.8, 0.35]]
	for i in n:
		var t := float(i) / RATE
		var e := 0.0
		for s: Array in swells:
			var lt: float = t - float(s[0])
			var sd: float = s[1]
			if lt > 0.0 and lt < sd:
				e += pow(sin(PI * lt / sd), 0.7) * float(s[2])
		lp += (nz[i] - lp) * 0.03
		lp2 += (lp - lp2) * 0.05
		out[i] += (lp2 * 5.0 + lp * 0.6) * e * (0.8 + 0.2 * sin(TAU * 9.0 * t)) * (1.0 - smoothstep(6.0, 7.0, t))
	return out


## The rift surging: a sub-bass swell that rises over four seconds with a choir-like whine on top.
static func _surge() -> PackedFloat32Array:
	var d := 9.0
	var out := _buf(d)
	var nz := _noise(out.size(), 521)
	var rumble := _lp(_lp(nz, 60.0), 90.0)
	var air := _bp(nz, 900.0, 3.0)
	var ph := [0.0, 0.0, 0.0]
	var fs := [55.0, 82.4, 116.5]
	for i in out.size():
		var t := float(i) / RATE
		var e := smoothstep(0.0, 4.0, t) * (1.0 - smoothstep(5.0, 9.0, t))
		var v := 0.0
		for k in 3:
			ph[k] = float(ph[k]) + TAU * float(fs[k]) * (1.0 + 0.04 * e) / RATE
			v += sin(float(ph[k])) * (0.5 if k > 0 else 1.0)
		var whine := sin(TAU * (440.0 + 60.0 * e) * t) * 0.12 * e * e * (0.6 + 0.4 * sin(TAU * 0.7 * t))
		out[i] = (v * 0.5 + rumble[i] * 9.0) * e + air[i] * 0.35 * e * e + whine
	return out


## A fireball's sonic boom, far off: a double thud and a long rumble.
static func _bolide() -> PackedFloat32Array:
	var d := 5.0
	var out := _buf(d)
	var nz := _noise(out.size(), 541)
	var rum := _lp(_lp(nz, 80.0), 140.0)
	for i in out.size():
		var t := float(i) / RATE
		var boom := sin(TAU * (48.0 - 10.0 * t) * t) * (exp(-t * 6.0) + exp(-maxf(0.0, t - 0.22) * 6.0) * float(t > 0.22) * 0.8)
		out[i] = boom * 0.8 + rum[i] * 10.0 * exp(-t * 0.8) * smoothstep(0.0, 0.2, t)
	return out


## A will-o'-wisp's chime: glassy partials with a slow shimmer.
static func _chime() -> PackedFloat32Array:
	var d := 2.5
	var out := _buf(d)
	var notes := [[0.0, 1320.0], [0.12, 1760.0], [0.24, 2217.0]]
	for nt: Array in notes:
		var st: float = nt[0]
		var f: float = nt[1]
		for k in int((d - st) * RATE):
			var t := float(k) / RATE
			var i := int(st * RATE) + k
			out[i] += (sin(TAU * f * t) + 0.3 * sin(TAU * f * 2.76 * t) * exp(-t * 4.0)) * exp(-t * 2.2) * (0.85 + 0.15 * sin(TAU * 6.0 * t)) * smoothstep(0.0, 0.004, t)
	return out


# --- music ------------------------------------------------------------------------------------------

## A plucked string (Karplus-Strong) at f: the generative layer's lyre.
static func _harp(f: float) -> PackedFloat32Array:
	var d := 4.5
	var out := _buf(d)
	var p := int(RATE / f)
	var ring := _lp(_noise(p, 601), 4000.0)
	var idx := 0
	var prev := 0.0
	for i in out.size():
		var v := ring[idx]
		var nv := (v + prev) * 0.5 * 0.9985
		prev = v
		ring[idx] = nv
		idx = (idx + 1) % p
		out[i] = v
	for i in out.size():
		var t := float(i) / RATE
		out[i] *= smoothstep(0.0, 0.003, t) * (1.0 - smoothstep(d - 0.6, d, t))
	return _lp(out, 3000.0)


## A soft sustained chord for rest (D minor add 9: D3 A3 D4 E4 F4 A4), slowly breathing.
static func _pad_rest() -> PackedFloat32Array:
	var d := 16.0
	var out := _buf(d + 2.0)
	var notes := [146.83, 220.0, 293.66, 329.63, 349.23, 440.0]
	var gains := [1.0, 0.7, 0.55, 0.25, 0.45, 0.3]
	for k in notes.size():
		var f: float = notes[k]
		var g: float = gains[k]
		var rate := 0.05 + 0.03 * float(k)
		for i in out.size():
			var t := float(i) / RATE
			var vib := 1.0 + 0.003 * sin(TAU * 4.6 * t + float(k))
			var a := TAU * f * vib * t
			var v := sin(a) + 0.32 * sin(a * 2.0 + 0.3) + 0.12 * sin(a * 3.0 + 0.9) + 0.6 * sin(TAU * f * 1.003 * t)
			out[i] += v * g * (0.65 + 0.35 * sin(TAU * rate * t + float(k) * 1.7))
	var air := _bp(_noise(out.size(), 607), 1200.0, 1.5)
	_mix(out, air, 0.15)
	return _seam(_lp(out, 1800.0), 2.0)


## Danger: a low cluster (D2 Ab2 Eb3) grinding in slow tremolo over a sub drone.
static func _pad_dark() -> PackedFloat32Array:
	var d := 12.0
	var out := _buf(d + 2.0)
	var notes := [73.42, 103.83, 155.56, 77.78]
	var gains := [1.0, 0.6, 0.45, 0.35]
	for k in notes.size():
		var f: float = notes[k]
		var g: float = gains[k]
		var ph := 0.0
		for i in out.size():
			var t := float(i) / RATE
			ph = fmod(ph + f * (1.0 + 0.002 * sin(TAU * 0.3 * t + float(k))) / RATE, 1.0)
			var saw := ph * 2.0 - 1.0
			var trem := 0.6 + 0.4 * sin(TAU * (0.25 + 0.1 * float(k)) * t + float(k))
			out[i] += saw * g * trem
	var dark := _lp(_lp(out, 420.0), 600.0)
	var nz := _lp(_noise(dark.size(), 613), 120.0)
	_mix(dark, nz, 2.0)
	return _seam(dark, 2.0)


## A slow heartbeat on a low drum (lub-dub) under danger.
static func _pulse() -> PackedFloat32Array:
	var out := _buf(0.9)
	for b in 2:
		var st := 0.0 if b == 0 else 0.26
		var g := 1.0 if b == 0 else 0.7
		for k in int(0.5 * RATE):
			var t := float(k) / RATE
			out[int(st * RATE) + k] += sin(TAU * (62.0 - 25.0 * t) * t) * exp(-t * 11.0) * g
	return out
