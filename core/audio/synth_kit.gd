extends RefCounted
## The sound rework's instrument shelf: small, deterministic, thread-safe synthesis helpers over a mono float buffer (22.05 kHz).
## Everything renders into a PackedFloat32Array on a worker thread (cue_bank.gd, score_stems.gd), is encoded to 16-bit and cached
## through GenCache, and only wrapped in an AudioStreamWAV on the main thread. Nothing here touches the scene tree or a global RNG.
##   buf(sec)                                       a silent buffer
##   partial(out, t, dur, f, a, atk, dec, f_end)    one sine from t, a glide to f_end, linear attack, exponential decay (s)
##   stack(out, t, dur, f, ratios, amps, a, atk, dec, decays)  a chord of partials over one root (bells, organs, choirs)
##   noise(out, t, dur, a, lo, hi, atk, dec, seed, trem)       band-passed noise with a decay and an optional tremolo (Hz)
##   thud(out, t, f, f_end, dur, a, seed)           a pitch-dropping body with a noise knock: a footfall, a blow, a door
##   bell(out, t, f, a, dec)                        a struck bell (hum, prime, tierce, quint, nominal; detuned pairs beat)
##   pluck(out, t, f, a, dec)                       a plucked string (Karplus-Strong-ish: harmonics falling at their own rates)
##   choir(out, t, dur, f, a, atk)                  a vowel pad: partials weighted by two formants, a slow vibrato
##   horn(out, t, dur, f, a, atk)                   a brass-like swell
##   mix(out, other, t, g)                          add one buffer into another
##   lowpass / highpass (out, fc)                   one-pole filters, in place
##   finish(out, peak)                              fade the edges, normalise to `peak`
##   encode(out, loop) -> PackedByteArray / wav(bytes, loop) -> AudioStreamWAV
## No class_name. Load by path: const Kit := preload("res://core/audio/synth_kit.gd")

const RATE := 22050


static func buf(sec: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(maxi(1, int(sec * float(RATE))))
	return b


static func partial(out: PackedFloat32Array, t: float, dur: float, f: float, a: float, atk := 0.005, dec := 0.3, f_end := -1.0) -> void:
	var n := out.size()
	var s0 := int(t * float(RATE))
	var cnt := mini(int(dur * float(RATE)), n - s0)
	if cnt <= 0 or s0 < 0:
		return
	var an := maxf(1.0, atk * float(RATE))
	var k := exp(-1.0 / maxf(dec * float(RATE), 1.0))
	var env := 1.0
	var ph := 0.0
	var f1 := f if f_end <= 0.0 else f_end
	for i in cnt:
		var fi := lerpf(f, f1, float(i) / float(cnt))
		ph += TAU * fi / float(RATE)
		out[s0 + i] += sin(ph) * a * minf(1.0, float(i) / an) * env
		env *= k


static func stack(out: PackedFloat32Array, t: float, dur: float, f: float, ratios: Array, amps: Array, a: float, atk := 0.01, dec := 1.0, decays: Array = []) -> void:
	for i in ratios.size():
		var d := dec * (float(decays[i]) if i < decays.size() else 1.0)
		var fr := f * float(ratios[i])
		if fr > 9000.0:
			continue
		partial(out, t, dur, fr, a * float(amps[i]), atk, d)


static func noise(out: PackedFloat32Array, t: float, dur: float, a: float, lo := 200.0, hi := 4000.0, atk := 0.005, dec := 0.2, seed_v := 1, trem := 0.0) -> void:
	var n := out.size()
	var s0 := int(t * float(RATE))
	var cnt := mini(int(dur * float(RATE)), n - s0)
	if cnt <= 0 or s0 < 0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v * 7919 + 13
	var ah := clampf(TAU * hi / float(RATE), 0.0, 0.95)
	var al := clampf(TAU * lo / float(RATE), 0.0, 0.95)
	var h1 := 0.0
	var h2 := 0.0
	var l1 := 0.0
	var an := maxf(1.0, atk * float(RATE))
	var k := exp(-1.0 / maxf(dec * float(RATE), 1.0))
	var env := 1.0
	for i in cnt:
		var x := rng.randf() * 2.0 - 1.0
		h1 += ah * (x - h1)
		h2 += ah * (h1 - h2)
		l1 += al * (h2 - l1)
		var v := h2 - l1
		var m := 1.0
		if trem > 0.0:
			m = 0.6 + 0.4 * sin(TAU * trem * float(i) / float(RATE))
		out[s0 + i] += v * a * 2.4 * minf(1.0, float(i) / an) * env * m
		env *= k


static func thud(out: PackedFloat32Array, t: float, f: float, f_end: float, dur: float, a: float, seed_v := 1) -> void:
	partial(out, t, dur, f, a, 0.002, dur * 0.35, f_end)
	noise(out, t, dur * 0.5, a * 0.5, 80.0, 1800.0, 0.001, dur * 0.12, seed_v)


static func bell(out: PackedFloat32Array, t: float, f: float, a: float, dec := 2.0) -> void:
	var parts := [[0.5, 0.5, 1.3], [1.0, 1.0, 1.0], [1.19, 0.45, 0.7], [1.5, 0.35, 0.55], [2.0, 0.4, 0.45], [2.01, 0.22, 0.4], [2.76, 0.12, 0.25], [4.07, 0.07, 0.15]]
	for p: Array in parts:
		var fr := f * float(p[0])
		if fr < 9000.0:
			partial(out, t, dec * float(p[2]) * 2.4, fr, a * float(p[1]), 0.003, dec * float(p[2]) * 0.5)


static func pluck(out: PackedFloat32Array, t: float, f: float, a: float, dec := 0.8) -> void:
	for h in 6:
		var fr := f * float(h + 1)
		if fr > 8000.0:
			break
		partial(out, t, dec * 2.0, fr, a / float(h + 1) * (1.0 if h % 2 == 0 else 0.7), 0.002, dec / float(h + 1.4))


static func choir(out: PackedFloat32Array, t: float, dur: float, f: float, a: float, atk := 0.4) -> void:
	for h in 12:
		var hf := f * float(h + 1)
		if hf > 3400.0:
			break
		var form := exp(-pow((hf - 700.0) / 260.0, 2.0)) + 0.7 * exp(-pow((hf - 1150.0) / 320.0, 2.0)) + 0.2 / float(h + 1)
		partial(out, t, dur, hf * (1.0 + 0.003 * sin(float(h))), a * form * 0.5, atk, dur * 0.8)


static func horn(out: PackedFloat32Array, t: float, dur: float, f: float, a: float, atk := 0.25) -> void:
	for h in 8:
		var hf := f * float(h + 1)
		if hf > 4200.0:
			break
		partial(out, t, dur, hf, a / float(h + 1) * (1.5 if h < 3 else 1.0), atk, dur * 0.9)


static func mix(out: PackedFloat32Array, other: PackedFloat32Array, t: float, g := 1.0) -> void:
	var s0 := int(t * float(RATE))
	for i in other.size():
		var j := s0 + i
		if j >= out.size():
			break
		out[j] += other[i] * g


static func lowpass(out: PackedFloat32Array, fc: float) -> void:
	var a := clampf(TAU * fc / float(RATE), 0.0, 0.95)
	var y := 0.0
	for i in out.size():
		y += a * (out[i] - y)
		out[i] = y


static func highpass(out: PackedFloat32Array, fc: float) -> void:
	var a := clampf(TAU * fc / float(RATE), 0.0, 0.95)
	var y := 0.0
	for i in out.size():
		y += a * (out[i] - y)
		out[i] -= y


## Fade the first 2 ms and the last 8 ms (no click at either end), then scale so the loudest sample is `peak`.
static func finish(out: PackedFloat32Array, peak := 0.85, fade_out := 0.008) -> void:
	var n := out.size()
	var fi := mini(n, int(0.002 * float(RATE)))
	var fo := mini(n, int(fade_out * float(RATE)))
	for i in fi:
		out[i] *= float(i) / float(maxi(fi, 1))
	for i in fo:
		out[n - 1 - i] *= float(i) / float(maxi(fo, 1))
	var m := 0.0001
	for v in out:
		m = maxf(m, absf(v))
	var g := peak / m
	for i in n:
		out[i] *= g


static func encode(out: PackedFloat32Array) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(out.size() * 2)
	for i in out.size():
		bytes.encode_s16(i * 2, int(clampf(out[i], -1.0, 1.0) * 32767.0))
	return bytes


static func wav(bytes: PackedByteArray, loop := false) -> AudioStreamWAV:
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = bytes
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = bytes.size() / 2
	return s
