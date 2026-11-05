extends RefCounted
## The wanderer's staff, synthesised: layered, with VARIANTS of every sound so a bolt chain never
## repeats one sample. Kinds:
##   bolt        a crystalline FM "zip" off the orb, an airy whoosh, a click and a small thump
##   lash        the Rift Lash (every 3rd bolt): the bolt plus a sub drop and a glass ring
##   bolt_hit    crackle, pop, sub thump, glassy tail
##   lance_fire  a fire roar thrown forward: grit saw, swept noise, crackle
##   lance_hit   an explosion: boom, burst, debris crackle
##   lance_charge (loop) a rising hum under ember crackle; pitch follows the charge
##   nova        deep drop, burst and a shimmering ring
##   tap         the staff's iron ferrule planted on the ground (walking, landing, stopping)
##   swish       the staff swung through the air
## r28 (skills, cores, combos):
##   split / ricochet / burn_hit / chill_hit / shatter   the staff cores (Prism, Lodestar, Cinder, Rime)
##   tether / tether_hit    Rift Tether's chain thrown and biting;  well_open / well_collapse / maelstrom
##   familiar / dart        a Bound Shade bound and loosing;  perfect (a Perfect Lance), echo (Nova I)
##   mote (Nova II), ward_pulse (Ward I), step_shock (Step I), rune_pull (Bolt II), combo (a synergy)
## play(kind, at, volume_db) picks a variant round-robin with a little pitch scatter.
## Built once behind the loading screen (prewarm) and cached through GenCache.
## Load by path (no class_name): const StaffSfx := preload("res://core/vfx/staff_sfx.gd")

const RATE := 32000
const VARIANTS := 4
const SELF := "res://core/vfx/staff_sfx.gd"
const GenCache := preload("res://core/world/realm/gen_cache.gd")
const KINDS := ["bolt", "lash", "bolt_hit", "lance_fire", "lance_hit", "nova", "tap", "swish", "lance_charge",
	"split", "ricochet", "burn_hit", "chill_hit", "shatter", "combo", "tether", "tether_hit", "well_open",
	"well_collapse", "maelstrom", "familiar", "dart", "perfect", "echo", "mote", "ward_pulse", "step_shock", "rune_pull"]
## Rarer sounds need fewer variants (each costs synthesis time on a cold cache).
const FEW := {"lance_charge": 1, "combo": 2, "perfect": 2, "familiar": 2, "well_open": 2, "well_collapse": 2,
	"maelstrom": 2, "shatter": 2, "echo": 2, "ward_pulse": 2, "rune_pull": 2, "step_shock": 3, "tether": 3, "tether_hit": 3}

static var _bank := {}       # kind -> Array[AudioStreamWAV]
static var _last := {}       # kind -> last variant index


## The app is closing: let the streams go before the audio server does.
static func release() -> void:
	_bank.clear()
	_last.clear()


static func play(kind: String, at: Vector3, volume_db := 0.0, pitch := 1.0, scatter := 0.04) -> void:
	var v := variants(kind)
	if v.is_empty():
		return
	var i := randi() % v.size()
	if v.size() > 1 and i == int(_last.get(kind, -1)):
		i = (i + 1) % v.size()
	_last[kind] = i
	Sfx.play_stream(v[i], at, volume_db, pitch, scatter)


static func stream(kind: String) -> AudioStreamWAV:
	var v := variants(kind)
	return v[0] if not v.is_empty() else null


static func prewarm() -> void:
	for k: String in KINDS:
		variants(k)


static func variants(kind: String) -> Array:
	if _bank.has(kind):
		return _bank[kind]
	var out: Array = []
	var cached: Variant = GenCache.load_var("staff_sfx_" + kind, SELF)
	if cached is Array and not (cached as Array).is_empty():
		for b: Variant in cached:
			out.append(_wav(b as PackedByteArray, kind == "lance_charge"))
	else:
		var raw: Array = []
		var n := int(FEW.get(kind, VARIANTS))
		for k in n:
			var rng := RandomNumberGenerator.new()
			rng.seed = hash(kind) * 31 + k * 977 + 5
			var pcm := _make(kind, rng)
			if pcm.is_empty():
				break
			var bytes := _bytes(pcm)
			raw.append(bytes)
			out.append(_wav(bytes, kind == "lance_charge"))
		GenCache.save_var("staff_sfx_" + kind, SELF, raw)
	_bank[kind] = out
	return out


static func _wav(bytes: PackedByteArray, loop := false) -> AudioStreamWAV:
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


static func _bytes(pcm: PackedFloat32Array) -> PackedByteArray:
	var peak := 0.0001
	for x in pcm:
		peak = maxf(peak, absf(x))
	var g := 0.9 / peak
	var b := PackedByteArray()
	b.resize(pcm.size() * 2)
	for i in pcm.size():
		b.encode_s16(i * 2, int(clampf(pcm[i] * g, -1.0, 1.0) * 32767.0))
	return b


# --- the recipes -----------------------------------------------------------------------------------

static func _make(kind: String, r: RandomNumberGenerator) -> PackedFloat32Array:
	match kind:
		"bolt":
			var n := _n(0.36)
			var out := _zeros(n)
			_add(out, _fm_chirp(n, r.randf_range(1900, 2400), r.randf_range(520, 700), r.randf_range(1.4, 2.1), 3.5, 0.0, 0.14), 0.55)
			_add(out, _swept_noise(n, r.randf_range(2600, 3400), 800.0, 0.6, 0.004, 0.22, r), 0.5)
			_add(out, _click(n, 3200.0, r), 0.35)
			_add(out, _thump(n, 120.0, 60.0, 0.07), 0.45)
			return out
		"lash":
			var n := _n(0.62)
			var out := _make("bolt", r)
			out.resize(n)
			_add(out, _thump(n, 90.0, 38.0, 0.22), 0.9)
			_add(out, _ring(n, [r.randf_range(1300, 1500), r.randf_range(2050, 2300), 3400.0], 0.42, 0.01), 0.35)
			_add(out, _swept_noise(n, 1800.0, 300.0, 0.9, 0.002, 0.4, r), 0.35)
			return out
		"bolt_hit":
			var n := _n(0.45)
			var out := _zeros(n)
			_add(out, _crackle(n, 0.16, r.randf_range(160.0, 260.0), 3500.0, r), 0.6)
			_add(out, _swept_noise(n, 1400.0, 300.0, 1.2, 0.001, 0.05, r), 0.8)
			_add(out, _thump(n, 95.0, 45.0, 0.12), 0.7)
			_add(out, _ring(n, [r.randf_range(1250, 1500), r.randf_range(1900, 2200)], 0.18, 0.003), 0.25)
			return out
		"lance_fire":
			var n := _n(0.95)
			var out := _zeros(n)
			_add(out, _swept_noise(n, 350.0, 2600.0, 0.5, 0.03, 0.75, r, 900.0), 0.8)
			_add(out, _saw_grit(n, r.randf_range(95, 120), 0.6, r), 0.35)
			_add(out, _crackle(n, 0.7, 120.0, 2600.0, r), 0.35)
			_add(out, _thump(n, 70.0, 40.0, 0.18), 0.6)
			return out
		"lance_hit":
			var n := _n(1.25)
			var out := _zeros(n)
			_add(out, _swept_noise(n, 2200.0, 180.0, 1.0, 0.001, 0.9, r), 0.9)
			_add(out, _thump(n, 75.0, 30.0, 0.45), 1.0)
			_add(out, _crackle(n, 1.1, 90.0, 2200.0, r, 0.15), 0.45)
			return out
		"nova":
			var n := _n(1.4)
			var out := _zeros(n)
			_add(out, _thump(n, 85.0, 28.0, 0.7), 1.0)
			_add(out, _swept_noise(n, 3000.0, 200.0, 1.1, 0.002, 0.8, r), 0.6)
			_add(out, _ring(n, [r.randf_range(620, 700), r.randf_range(930, 1050), r.randf_range(1480, 1650), 2350.0], 1.1, 0.02), 0.3)
			return out
		"tap":
			var n := _n(0.26)
			var out := _zeros(n)
			_add(out, _wood(n, r.randf_range(170, 210), r), 0.8)
			_add(out, _ring(n, [r.randf_range(2300, 2600), r.randf_range(3300, 3700)], 0.12, 0.001), 0.18)
			_add(out, _click(n, 2000.0, r), 0.3)
			return out
		"swish":
			var n := _n(0.3)
			var out := _zeros(n)
			_add(out, _swept_noise(n, 600.0, 2400.0, 0.4, 0.08, 0.22, r, 700.0), 1.0)
			return out
		"lance_charge":
			# 2 s loop: two detuned saws through a slowly breathing filter, with ember crackle; the
			# ends cross-fade so it loops without a seam (the player sweeps its pitch with the charge)
			var n := _n(2.0)
			var out := _zeros(n)
			_add(out, _saw_grit(n, 110.0, 0.0, r, 0.5), 0.5)
			_add(out, _saw_grit(n, 110.0 * 1.012, 0.0, r, 0.5), 0.5)
			_add(out, _crackle(n, 2.0, 60.0, 2400.0, r, 2.0), 0.3)
			return _seam(out, _n(0.25))
		# --- r28 ---
		"split":
			var n := _n(0.42)
			var out := _zeros(n)
			for k in 3:
				_add(out, _fm_chirp(n, r.randf_range(2400, 3000) + 380.0 * k, r.randf_range(1200, 1500), 2.0, 2.2, 0.022 * k, 0.1), 0.42)
			_add(out, _ring(n, [r.randf_range(3100, 3400), r.randf_range(4500, 4900), 6200.0], 0.22, 0.01), 0.3)
			_add(out, _click(n, 4200.0, r), 0.25)
			return out
		"ricochet":
			var n := _n(0.42)
			var out := _zeros(n)
			_add(out, _ring(n, [r.randf_range(2700, 3000), r.randf_range(4000, 4300), 5400.0], 0.26, 0.0), 0.55)
			_add(out, _fm_chirp(n, r.randf_range(800, 950), r.randf_range(2300, 2700), 1.5, 2.0, 0.02, 0.12), 0.4)
			_add(out, _click(n, 3600.0, r), 0.4)
			return out
		"burn_hit":
			var n := _n(0.5)
			var out := _zeros(n)
			_add(out, _crackle(n, 0.45, r.randf_range(140.0, 200.0), 2600.0, r), 0.6)
			_add(out, _swept_noise(n, 700.0, 2800.0, 0.6, 0.01, 0.3, r), 0.55)
			_add(out, _thump(n, 120.0, 55.0, 0.1), 0.5)
			return out
		"chill_hit":
			var n := _n(0.48)
			var out := _zeros(n)
			_add(out, _ring(n, [r.randf_range(3000, 3400), r.randf_range(4500, 4900), r.randf_range(5900, 6300)], 0.28, 0.0), 0.55)
			_add(out, _click(n, 5200.0, r), 0.45)
			_add(out, _swept_noise(n, 6500.0, 2800.0, 1.4, 0.002, 0.3, r), 0.3)
			return out
		"shatter":
			var n := _n(0.85)
			var out := _zeros(n)
			_add(out, _crackle(n, 0.35, 900.0, 4800.0, r), 0.7)
			_add(out, _ring(n, [r.randf_range(2000, 2200), r.randf_range(3200, 3500), 4600.0, 6000.0], 0.45, 0.005), 0.45)
			_add(out, _thump(n, 150.0, 55.0, 0.2), 0.7)
			_add(out, _swept_noise(n, 5000.0, 900.0, 1.0, 0.001, 0.25, r), 0.5)
			return out
		"combo":
			var n := _n(0.85)
			var out := _zeros(n)
			_add(out, _ring(n, [880.0, 1320.0, 1777.0, 2640.0], 0.55, 0.0), 0.7)
			_add(out, _fm_chirp(n, 1180.0, 1760.0, 2.0, 1.2, 0.0, 0.12), 0.3)
			_add(out, _click(n, 3000.0, r), 0.25)
			return out
		"tether":
			var n := _n(0.55)
			var out := _zeros(n)
			_add(out, _crackle(n, 0.4, 320.0, 3800.0, r), 0.6)
			_add(out, _swept_noise(n, 450.0, 2400.0, 0.5, 0.02, 0.3, r), 0.5)
			_add(out, _ring(n, [r.randf_range(1700, 1900), r.randf_range(2500, 2700)], 0.15, 0.03), 0.3)
			return out
		"tether_hit":
			var n := _n(0.55)
			var out := _zeros(n)
			_add(out, _thump(n, 110.0, 48.0, 0.18), 0.8)
			_add(out, _crackle(n, 0.3, 260.0, 2500.0, r), 0.5)
			_add(out, _ring(n, [r.randf_range(1400, 1600), r.randf_range(2250, 2450)], 0.2, 0.0), 0.4)
			return out
		"well_open":
			var n := _n(1.05)
			var out := _zeros(n)
			_add(out, _swept_noise(n, 220.0, 2600.0, 0.8, 0.45, 0.9, r), 0.7)
			_add(out, _saw_grit(n, 55.0, 0.7, r, 0.08), 0.5)
			_add(out, _fm_chirp(n, 130.0, 58.0, 0.5, 1.5, 0.0, 0.5), 0.6)
			return out
		"well_collapse":
			var n := _n(1.3)
			var out := _zeros(n)
			_add(out, _thump(n, 72.0, 24.0, 0.6), 1.0)
			_add(out, _swept_noise(n, 3200.0, 150.0, 1.0, 0.001, 0.8, r), 0.6)
			_add(out, _ring(n, [r.randf_range(380, 420), r.randf_range(590, 630), 930.0], 0.8, 0.02), 0.35)
			return out
		"maelstrom":
			var n := _n(1.2)
			var out := _zeros(n)
			_add(out, _swept_noise(n, 300.0, 1900.0, 0.5, 0.05, 1.0, r, 900.0), 0.8)
			_add(out, _saw_grit(n, 72.0, 0.5, r), 0.4)
			_add(out, _crackle(n, 1.1, 140.0, 2400.0, r, 1.0), 0.45)
			_add(out, _thump(n, 80.0, 35.0, 0.3), 0.6)
			return out
		"familiar":
			var n := _n(1.0)
			var out := _zeros(n)
			_add(out, _swept_noise(n, 700.0, 2600.0, 2.0, 0.25, 0.85, r, 1600.0), 0.55)
			_add(out, _ring(n, [660.0, 990.0, 1485.0, 1980.0], 0.7, 0.05), 0.45)
			return out
		"dart":
			var n := _n(0.26)
			var out := _zeros(n)
			_add(out, _fm_chirp(n, r.randf_range(1700, 2000), r.randf_range(800, 950), 1.5, 1.8, 0.0, 0.08), 0.55)
			_add(out, _swept_noise(n, 3200.0, 1200.0, 0.8, 0.003, 0.15, r), 0.4)
			return out
		"perfect":
			var n := _n(0.6)
			var out := _zeros(n)
			_add(out, _ring(n, [1568.0, 2350.0, 3136.0, 4700.0], 0.38, 0.0), 0.7)
			_add(out, _click(n, 6000.0, r), 0.4)
			_add(out, _thump(n, 200.0, 85.0, 0.12), 0.5)
			return out
		"echo":
			var n := _n(0.9)
			var out := _zeros(n)
			_add(out, _ring(n, [r.randf_range(480, 520), r.randf_range(740, 780), 1150.0, 1720.0], 0.6, 0.0), 0.6)
			_add(out, _swept_noise(n, 2200.0, 380.0, 1.0, 0.004, 0.5, r), 0.45)
			_add(out, _thump(n, 95.0, 45.0, 0.25), 0.4)
			return out
		"mote":
			var n := _n(0.26)
			var out := _zeros(n)
			_add(out, _ring(n, [r.randf_range(1700, 1850), r.randf_range(2600, 2750)], 0.12, 0.0), 0.6)
			_add(out, _click(n, 4000.0, r), 0.2)
			return out
		"ward_pulse":
			var n := _n(0.75)
			var out := _zeros(n)
			_add(out, _thump(n, 92.0, 52.0, 0.35), 0.9)
			_add(out, _swept_noise(n, 280.0, 950.0, 0.6, 0.03, 0.5, r), 0.45)
			_add(out, _ring(n, [440.0, 661.0, 880.0], 0.45, 0.02), 0.25)
			return out
		"step_shock":
			var n := _n(0.5)
			var out := _zeros(n)
			_add(out, _thump(n, 130.0, 44.0, 0.25), 0.9)
			_add(out, _swept_noise(n, 2600.0, 300.0, 0.9, 0.001, 0.28, r), 0.6)
			_add(out, _crackle(n, 0.2, 220.0, 3000.0, r), 0.3)
			return out
		"rune_pull":
			var n := _n(0.62)
			var out := _zeros(n)
			_add(out, _swept_noise(n, 3200.0, 280.0, 0.9, 0.18, 0.5, r), 0.7)
			_add(out, _fm_chirp(n, 950.0, 280.0, 0.5, 2.0, 0.0, 0.3), 0.45)
			return out
	return PackedFloat32Array()


# --- DSP pieces --------------------------------------------------------------------------------------

static func _n(sec: float) -> int:
	return int(sec * RATE)


static func _zeros(n: int) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(n)
	return a


static func _add(out: PackedFloat32Array, x: PackedFloat32Array, g: float) -> void:
	for i in mini(out.size(), x.size()):
		out[i] += x[i] * g


## FM tone gliding f0 -> f1, modulator ratio `ratio`, index decaying from `index`; tail `len`.
static func _fm_chirp(n: int, f0: float, f1: float, ratio: float, index: float, delay: float, length: float) -> PackedFloat32Array:
	var out := _zeros(n)
	var ph := 0.0
	var pm := 0.0
	var d0 := int(delay * RATE)
	var ln := maxi(1, int(length * RATE))
	for i in range(d0, mini(n, d0 + ln * 2)):
		var u := float(i - d0) / float(ln)
		var f := lerpf(f0, f1, 1.0 - exp(-u * 3.0))
		pm += TAU * f * ratio / RATE
		ph += TAU * f / RATE
		var env := minf(u * 60.0, 1.0) * exp(-u * 3.2)
		out[i] = sin(ph + index * exp(-u * 4.0) * sin(pm)) * env
	return out


## Noise through a resonant band-pass sweeping f0 -> f1 (log), attack `a`, decay to `len`.
static func _swept_noise(n: int, f0: float, f1: float, q: float, a: float, length: float, r: RandomNumberGenerator, mid := 0.0) -> PackedFloat32Array:
	var out := _zeros(n)
	var y1 := 0.0
	var y2 := 0.0
	var c := Vector3.ZERO
	var ln := maxi(1, int(length * RATE))
	for i in mini(n, ln + int(0.05 * RATE)):
		var u := float(i) / float(ln)
		if i % 32 == 0:
			var f := f0 * pow(f1 / f0, clampf(u, 0.0, 1.0))
			if mid > 0.0:
				f = lerpf(f0, mid, minf(u * 2.0, 1.0)) if u < 0.5 else lerpf(mid, f1, (u - 0.5) * 2.0)
			c = _res(f, f / maxf(q * 4.0, 0.5))
		var x := r.randf_range(-1.0, 1.0)
		var y := c.z * x + c.x * y1 - c.y * y2
		y2 = y1
		y1 = y
		var env := clampf(float(i) / maxf(a * RATE, 1.0), 0.0, 1.0) * pow(maxf(1.0 - u, 0.0), 2.0)
		out[i] = y * env * 4.0
	return out


static func _click(n: int, f: float, r: RandomNumberGenerator) -> PackedFloat32Array:
	var out := _zeros(n)
	var c := _res(f, f * 0.6)
	var y1 := 0.0
	var y2 := 0.0
	for i in mini(n, int(0.012 * RATE)):
		var x := r.randf_range(-1.0, 1.0) * exp(-float(i) / (0.002 * RATE))
		var y := c.z * x + c.x * y1 - c.y * y2
		y2 = y1
		y1 = y
		out[i] = y * 6.0
	return out


## A sine dropping f0 -> f1 over `length`: the body of a hit.
static func _thump(n: int, f0: float, f1: float, length: float) -> PackedFloat32Array:
	var out := _zeros(n)
	var ph := 0.0
	var ln := maxi(1, int(length * RATE))
	for i in mini(n, ln * 2):
		var u := float(i) / float(ln)
		ph += TAU * lerpf(f0, f1, minf(u, 1.0)) / RATE
		out[i] = sin(ph) * minf(float(i) / (0.002 * RATE), 1.0) * exp(-u * 2.5)
	return out


## Inharmonic partials decaying over `length` (glass, iron).
static func _ring(n: int, freqs: Array, length: float, delay: float) -> PackedFloat32Array:
	var out := _zeros(n)
	var d0 := int(delay * RATE)
	for k in freqs.size():
		var f := float(freqs[k])
		var dec := length * (1.0 - 0.15 * float(k))
		for i in range(d0, n):
			var t := float(i - d0) / RATE
			if t > dec * 3.0:
				break
			out[i] += sin(TAU * f * t) * exp(-t / maxf(dec, 0.01) * 2.5) / float(freqs.size())
	return out


## Sparse random impulses through a band-pass: embers, splinters, debris.
static func _crackle(n: int, length: float, rate_hz: float, f: float, r: RandomNumberGenerator, sustain := 0.0) -> PackedFloat32Array:
	var out := _zeros(n)
	var c := _res(f, f * 0.5)
	var y1 := 0.0
	var y2 := 0.0
	var ln := maxi(1, int(length * RATE))
	for i in mini(n, ln):
		var u := float(i) / float(ln)
		var dens := rate_hz / RATE * (1.0 if sustain > 0.0 else exp(-u * 2.0))
		var x := r.randf_range(-1.0, 1.0) * r.randf_range(0.3, 1.0) if r.randf() < dens else 0.0
		var y := c.z * x * 20.0 + c.x * y1 - c.y * y2
		y2 = y1
		y1 = y
		out[i] = y * (1.0 if sustain > 0.0 else (1.0 - u))
	return out


## A sawtooth with jittered pitch through a low-pass: roar grit, charge hum.
static func _saw_grit(n: int, f: float, decay: float, r: RandomNumberGenerator, lp_k := 0.18) -> PackedFloat32Array:
	var out := _zeros(n)
	var ph := 0.0
	var lp := 0.0
	var jit := 0.0
	for i in n:
		var u := float(i) / float(n)
		jit = clampf(jit + r.randf_range(-0.002, 0.002), -0.03, 0.03)
		ph += f * (1.0 + jit) / RATE
		ph -= floorf(ph)
		lp += ((ph * 2.0 - 1.0) - lp) * lp_k
		var env := minf(float(i) / (0.02 * RATE), 1.0) * (exp(-u * decay * 4.0) if decay > 0.0 else 1.0)
		out[i] = lp * env
	return out


## A wooden knock: noise burst into two low resonators.
static func _wood(n: int, f: float, r: RandomNumberGenerator) -> PackedFloat32Array:
	var out := _zeros(n)
	var c1 := _res(f, 40.0)
	var c2 := _res(f * 2.3, 90.0)
	var a := [0.0, 0.0, 0.0, 0.0]
	for i in mini(n, int(0.2 * RATE)):
		var x := r.randf_range(-1.0, 1.0) * exp(-float(i) / (0.003 * RATE))
		var y := c1.z * x + c1.x * float(a[0]) - c1.y * float(a[1])
		a[1] = a[0]
		a[0] = y
		var z := c2.z * x + c2.x * float(a[2]) - c2.y * float(a[3])
		a[3] = a[2]
		a[2] = z
		out[i] = (y * 1.0 + z * 0.6) * 8.0 * exp(-float(i) / (0.06 * RATE))
	return out


static func _res(f: float, bw: float) -> Vector3:
	var rr := exp(-PI * bw / RATE)
	return Vector3(2.0 * rr * cos(TAU * minf(f, RATE * 0.45) / RATE), rr * rr, 1.0 - rr)


## Cross-fade the last `fade` samples into the first so the buffer loops cleanly.
static func _seam(x: PackedFloat32Array, fade: int) -> PackedFloat32Array:
	var n := x.size() - fade
	var out := x.slice(0, n)
	for i in fade:
		var w := float(i) / float(fade)
		out[i] = x[i] * w + x[n + i] * (1.0 - w)
	return out
