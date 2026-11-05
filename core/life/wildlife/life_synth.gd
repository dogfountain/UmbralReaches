extends RefCounted
## Procedural night sounds for the wildlife and weather (life system). Each kind is synthesised
## once into a 16-bit mono AudioStreamWAV; `zz/life_gen_audio.tscn` writes them to
## res://art/audio/life/<kind>.wav (imported like any asset) and `stream()` loads those, falling back
## to synthesising in memory if a file is missing. Loops (`LOOPS`) are made seamless (events wrap
## round the buffer, noise beds are cross-faded) and come back with loop_mode set.
## Load by path (no class_name):  const LifeSynth := preload("res://core/life/wildlife/life_synth.gd")

const RATE := 22050
const DIR := "res://art/audio/life/"
const KINDS := ["owl", "owl2", "crow", "frogs", "crickets", "wind", "rain", "thunder", "heron", "squeak", "plop", "flap", "snort"]
const LOOPS := ["frogs", "crickets", "wind", "rain"]

static var _cache := {}


static func stream(kind: String) -> AudioStreamWAV:
	if _cache.has(kind):
		return _cache[kind]
	var s: AudioStreamWAV = null
	var path := DIR + kind + ".wav"
	if ResourceLoader.exists(path):
		s = load(path) as AudioStreamWAV
		if s != null:
			s = s.duplicate() as AudioStreamWAV
	if s == null:
		s = build(kind)
	if s != null and kind in LOOPS:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = s.data.size() / 2
	_cache[kind] = s
	return s


static func build(kind: String) -> AudioStreamWAV:
	var pcm := PackedFloat32Array()
	match kind:
		"owl": pcm = _owl(0)
		"owl2": pcm = _owl(1)
		"crow": pcm = _crow()
		"frogs": pcm = _frogs()
		"crickets": pcm = _crickets()
		"wind": pcm = _wind()
		"rain": pcm = _rain()
		"thunder": pcm = _thunder()
		"heron": pcm = _heron()
		"squeak": pcm = _squeak()
		"plop": pcm = _plop()
		"flap": pcm = _flap()
		"snort": pcm = _snort()
		_: return null
	return _wav(pcm)


static func _wav(pcm: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(pcm.size() * 2)
	var peak := 0.0001
	for v in pcm:
		peak = maxf(peak, absf(v))
	var g := 0.9 / peak
	for i in pcm.size():
		bytes.encode_s16(i * 2, int(clampf(pcm[i] * g, -1.0, 1.0) * 32767.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = bytes
	return s


# --- helpers --------------------------------------------------------------------------------------

static func _noise(n: int, seed_v: int) -> PackedFloat32Array:
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = r.randf_range(-1.0, 1.0)
	return out


## RBJ biquad band-pass (constant peak gain) in place.
static func _bandpass(x: PackedFloat32Array, f0: float, q: float) -> PackedFloat32Array:
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
		var v := b0 * x[i] + b2 * x2 - a1 * y1 - a2 * y2
		x2 = x1
		x1 = x[i]
		y2 = y1
		y1 = v
		y[i] = v
	return y


static func _lowpass(x: PackedFloat32Array, k: float) -> PackedFloat32Array:
	var y := PackedFloat32Array()
	y.resize(x.size())
	var lp := 0.0
	for i in x.size():
		lp += (x[i] - lp) * k
		y[i] = lp
	return y


## Cross-fade the last `fade` seconds into the start so the buffer loops without a click.
static func _seam(x: PackedFloat32Array, fade: float) -> PackedFloat32Array:
	var nf := int(fade * RATE)
	var n := x.size() - nf
	var y := x.slice(0, n)
	for i in nf:
		var t := float(i) / float(nf)
		y[i] = x[i] * sqrt(t) + x[n + i] * sqrt(1.0 - t)
	return y


static func _env(t: float, a: float, d: float) -> float:
	if t < 0.0 or t > d:
		return 0.0
	return smoothstep(0.0, a, t) * (1.0 - smoothstep(d * 0.55, d, t))


# --- creatures ------------------------------------------------------------------------------------

## Tawny owl: "hoo ... hu-hoooo-o-o" (variant 1: a single long hoot, the female's distant reply).
static func _owl(variant: int) -> PackedFloat32Array:
	var dur := 3.4 if variant == 0 else 1.6
	var n := int(RATE * dur)
	var nz := _lowpass(_noise(n, 5 + variant), 0.08)
	var out := PackedFloat32Array()
	out.resize(n)
	var notes: Array = [[0.05, 0.5, 410.0, 385.0, 0.0], [1.35, 0.16, 360.0, 380.0, 0.0], [1.6, 1.55, 400.0, 375.0, 1.0]]
	if variant == 1:
		notes = [[0.05, 1.3, 370.0, 345.0, 1.0]]
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for nt: Array in notes:
			var lt: float = t - float(nt[0])
			var d: float = nt[1]
			if lt < 0.0 or lt > d:
				continue
			var k := lt / d
			var f := lerpf(float(nt[2]), float(nt[3]), k) * (1.0 + 0.012 * sin(TAU * 5.0 * lt))
			var trem := 1.0 - float(nt[4]) * smoothstep(0.45, 0.7, k) * (0.5 + 0.5 * sin(TAU * 13.0 * lt))
			ph += TAU * f / RATE
			var e := smoothstep(0.0, 0.07, lt) * (1.0 - smoothstep(0.7, 1.0, k)) * trem
			v += (sin(ph) + 0.18 * sin(ph * 2.0) + 0.05 * sin(ph * 3.0)) * e + nz[i] * e * 0.9
		out[i] = v
	return out


static func _crow() -> PackedFloat32Array:
	var n := int(RATE * 1.7)
	var nz := _noise(n, 17)
	var src := PackedFloat32Array()
	src.resize(n)
	var ph := 0.0
	var caws := [0.02, 0.5, 0.98]
	for i in n:
		var t := float(i) / RATE
		var e := 0.0
		var f := 500.0
		for c: float in caws:
			var lt := t - c
			if lt >= 0.0 and lt < 0.34:
				e = smoothstep(0.0, 0.025, lt) * (1.0 - smoothstep(0.2, 0.34, lt))
				f = lerpf(560.0, 470.0, lt / 0.34) * (1.0 - 0.04 * (c / 1.0))
		ph = fmod(ph + f / RATE, 1.0)
		var rasp := 0.6 + 0.4 * sin(TAU * 62.0 * t)
		src[i] = ((ph * 2.0 - 1.0) * 0.8 + nz[i] * 0.55) * e * rasp
	var a := _bandpass(src, 1150.0, 3.0)
	var b := _bandpass(src, 2350.0, 4.0)
	var c2 := _bandpass(src, 650.0, 2.0)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = a[i] * 1.0 + b[i] * 0.55 + c2[i] * 0.6
	return out


## A pool's chorus: seven frogs, each with its own pitch and rhythm, wrapped round a 7 s loop.
static func _frogs() -> PackedFloat32Array:
	var n := int(RATE * 7.0)
	var out := PackedFloat32Array()
	out.resize(n)
	var r := RandomNumberGenerator.new()
	r.seed = 31
	for fi in 7:
		var f0 := r.randf_range(320.0, 780.0)
		var rate := r.randf_range(28.0, 46.0)
		var period := r.randf_range(0.8, 1.9)
		var gain := r.randf_range(0.4, 1.0)
		var t0 := r.randf_range(0.0, period)
		while t0 < 7.0:
			var pulses := 2 if r.randf() < 0.6 else 3
			var plen := r.randf_range(0.07, 0.11)
			for pi in pulses:
				var st := t0 + float(pi) * (plen + 0.05)
				var ns := int(plen * RATE)
				var i0 := int(st * RATE)
				for k in ns:
					var lt := float(k) / RATE
					var am := maxf(0.0, sin(TAU * rate * lt))
					var e := sin(PI * lt / plen)
					var f := f0 * (1.0 + 0.08 * lt / plen)
					var v := (sin(TAU * f * lt) + 0.45 * sin(TAU * f * 2.0 * lt) + 0.2 * sin(TAU * f * 3.0 * lt)) * am * am * e * gain
					var idx := (i0 + k) % n
					out[idx] += v
			t0 += period * r.randf_range(0.8, 1.25)
	return out


static func _crickets() -> PackedFloat32Array:
	var n := int(RATE * 4.0)
	var out := PackedFloat32Array()
	out.resize(n)
	var r := RandomNumberGenerator.new()
	r.seed = 47
	for ci in 4:
		var f := r.randf_range(4200.0, 4900.0)
		var period := r.randf_range(0.42, 0.62)
		var gain := r.randf_range(0.3, 1.0)
		var t0 := r.randf_range(0.0, period)
		while t0 < 4.0:
			for pi in 3:
				var i0 := int((t0 + float(pi) * 0.032) * RATE)
				var ns := int(0.02 * RATE)
				for k in ns:
					var lt := float(k) / RATE
					var idx := (i0 + k) % n
					out[idx] += sin(TAU * f * lt) * sin(PI * lt / 0.02) * gain
			t0 += period
	return out


static func _heron() -> PackedFloat32Array:
	var n := int(RATE * 0.6)
	var nz := _noise(n, 61)
	var src := PackedFloat32Array()
	src.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		ph = fmod(ph + lerpf(260.0, 190.0, t / 0.6) / RATE, 1.0)
		src[i] = ((ph * 2.0 - 1.0) * 0.7 + nz[i] * 0.9) * _env(t, 0.02, 0.55) * (0.7 + 0.3 * sin(TAU * 38.0 * t))
	var a := _bandpass(src, 850.0, 2.5)
	var b := _bandpass(src, 1700.0, 3.0)
	for i in n:
		src[i] = a[i] + b[i] * 0.5
	return src


static func _squeak() -> PackedFloat32Array:
	var n := int(RATE * 0.5)
	var out := PackedFloat32Array()
	out.resize(n)
	for c in 3:
		var st := 0.02 + float(c) * 0.14
		var f0 := 3800.0 + float(c) * 350.0
		for i in int(0.06 * RATE):
			var lt := float(i) / RATE
			var f := f0 + 1200.0 * sin(PI * lt / 0.06)
			out[int(st * RATE) + i] += sin(TAU * f * lt) * sin(PI * lt / 0.06)
	return out


static func _plop() -> PackedFloat32Array:
	var n := int(RATE * 0.35)
	var nz := _lowpass(_noise(n, 71), 0.3)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		ph += TAU * lerpf(280.0, 950.0, minf(t / 0.09, 1.0)) / RATE
		out[i] = sin(ph) * exp(-t * 30.0) * 0.9 + nz[i] * exp(-t * 18.0) * 0.6
	return out


static func _flap() -> PackedFloat32Array:
	var n := int(RATE * 0.9)
	var nz := _lowpass(_noise(n, 83), 0.18)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var beat := pow(maxf(0.0, sin(TAU * 8.5 * t)), 3.0)
		out[i] = nz[i] * beat * exp(-t * 2.2)
	return out


static func _snort() -> PackedFloat32Array:
	var n := int(RATE * 0.45)
	var nz := _noise(n, 97)
	for i in n:
		var t := float(i) / RATE
		nz[i] *= _env(t, 0.015, 0.4)
	var a := _bandpass(nz, 520.0, 1.6)
	var b := _bandpass(nz, 1400.0, 2.0)
	for i in n:
		a[i] = a[i] + b[i] * 0.4
	return a


# --- weather ----------------------------------------------------------------------------------------

## Wind through the trees: low roar with slow swells and a faint whistle, seamless 10 s loop.
static func _wind() -> PackedFloat32Array:
	var n := int(RATE * 11.0)
	var nz := _noise(n, 101)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / RATE
		var sw := 0.55 + 0.25 * sin(TAU * t / 5.5) + 0.2 * sin(TAU * t / 2.75 + 1.3)
		var k := 0.012 + 0.03 * sw
		lp += (nz[i] - lp) * k
		lp2 += (lp - lp2) * k
		out[i] = lp2 * sw * 6.0
	var wh := _bandpass(nz, 780.0, 18.0)
	for i in n:
		var t := float(i) / RATE
		out[i] += wh[i] * 0.25 * (0.5 + 0.5 * sin(TAU * t / 3.67))
	return _seam(out, 1.0)


static func _rain() -> PackedFloat32Array:
	var n := int(RATE * 7.0)
	var nz := _noise(n, 113)
	var out := PackedFloat32Array()
	out.resize(n)
	var hp_prev := 0.0
	var hp := 0.0
	var lp := 0.0
	for i in n:
		hp = 0.9 * (hp + nz[i] - hp_prev)
		hp_prev = nz[i]
		lp += (hp - lp) * 0.35
		out[i] = lp * 0.5
	var r := RandomNumberGenerator.new()
	r.seed = 7
	for d in 900:                                   # drops on leaves and stone
		var i0 := r.randi_range(0, n - 1)
		var f := r.randf_range(1500.0, 5000.0)
		var g := r.randf_range(0.1, 0.5)
		for k in 120:
			var lt := float(k) / RATE
			out[(i0 + k) % n] += sin(TAU * f * lt) * exp(-lt * 900.0) * g
	return _seam(out, 0.6)


## Distant thunder over the Crowns: no crack, a long rolling rumble with two or three swells.
static func _thunder() -> PackedFloat32Array:
	var n := int(RATE * 7.5)
	var nz := _noise(n, 127)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	var lp3 := 0.0
	var swells := [[0.1, 1.4, 1.0], [1.1, 2.4, 0.8], [2.8, 3.5, 0.6], [4.5, 2.8, 0.35]]
	for i in n:
		var t := float(i) / RATE
		var e := 0.0
		for s: Array in swells:
			var lt: float = t - float(s[0])
			var d: float = s[1]
			if lt > 0.0 and lt < d:
				e += sin(PI * lt / d) * float(s[2]) * (0.75 + 0.25 * sin(TAU * 7.0 * t + float(s[0])))
		lp += (nz[i] - lp) * 0.02
		lp2 += (lp - lp2) * 0.03
		lp3 += (lp2 - lp3) * 0.05
		out[i] = (lp3 * 3.0 + lp * 0.25) * e * (1.0 - smoothstep(6.5, 7.5, t))
	return out
