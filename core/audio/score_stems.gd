extends RefCounted
## The dynamic score's stems (score_director.gd plays them, cross-faded by what the night is doing). Rendered once on a worker
## thread, encoded and cached through GenCache like the boss themes; every loop is built from partials whose frequency fits a whole
## number of cycles into the loop, so no stem has a seam. Pure: safe on any thread.
##   tension       sixteen seconds of a minor second beating under a thin high tremolo: something is near
##   combat_lo     a war drum on 1 and 3 and a bowed low ostinato at 100 bpm: the fight's floor
##   combat_hi     snares on 2 and 4, a plucked sixteenth ostinato, a high choir: the fight's heat (crossfaded in by intensity)
##   aftermath     a slow choir, one bell falling every few seconds: the quiet after a fight
##   act1 / act2 / act3   the three acts' beds: Hearthward's warm D minor; the peal (a fifth drone, bells rising from the bottom);
##                 Aurel's wrong turn (a D / G-sharp dyad beating, a thin choir, a tick that counts)
##   motif_<family>  five regions' short phrases (village, wood, fen, heights, crypt) and motif_act1/2/3: the bell motif, rung bottom
##                 to top in the first two and top first in the third
## No class_name. Load by path: const Stems := preload("res://core/audio/score_stems.gd")

const Kit := preload("res://core/audio/synth_kit.gd")
const GenCache := preload("res://core/world/realm/gen_cache.gd")
const SELF := "res://core/audio/score_stems.gd"
const VERSION := 1

const LOOPS := ["tension", "combat_lo", "combat_hi", "aftermath", "act1", "act2", "act3", "hour_dusk", "hour_late", "hour_dawn", "ending"]
const MOTIFS := ["motif_village", "motif_wood", "motif_fen", "motif_heights", "motif_crypt", "motif_act1", "motif_act2", "motif_act3"]
const LEN := {"tension": 16.0, "combat_lo": 19.2, "combat_hi": 19.2, "aftermath": 20.0, "act1": 24.0, "act2": 24.0, "act3": 24.0, "hour_dusk": 24.0, "hour_late": 24.0, "hour_dawn": 24.0, "ending": 24.0}

static var _bytes := {}
static var _streams := {}
static var _mutex := Mutex.new()
static var _task := -1


static func warm() -> void:
	if _task >= 0:
		return
	_task = WorkerThreadPool.add_task(_work, false, "score_stems")


static func release() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	_mutex.lock()
	_bytes.clear()
	_mutex.unlock()
	_streams.clear()


static func _work() -> void:
	for id: String in LOOPS + MOTIFS:
		var key := "score_%s_v%d" % [id, VERSION]
		var data: Variant = GenCache.load_var(key, SELF)
		var bytes: PackedByteArray
		if data is PackedByteArray and (data as PackedByteArray).size() > 64:
			bytes = data
		else:
			bytes = Kit.encode(build(id))
			GenCache.save_var(key, SELF, bytes)
		_mutex.lock()
		_bytes[id] = bytes
		_mutex.unlock()


## The stream (looping for the loops), or null while it is still rendering.
static func stream(id: String) -> AudioStreamWAV:
	if _streams.has(id):
		return _streams[id]
	_mutex.lock()
	var b: Variant = _bytes.get(id)
	_mutex.unlock()
	if b == null:
		return null
	var w := Kit.wav(b as PackedByteArray, LOOPS.has(id))
	_streams[id] = w
	return w


static func build(id: String) -> PackedFloat32Array:
	var out: PackedFloat32Array
	match id:
		"tension":
			out = _tension()
		"combat_lo":
			out = _combat(false)
		"combat_hi":
			out = _combat(true)
		"aftermath":
			out = _aftermath()
		"act1":
			out = _act1()
		"act2":
			out = _act2()
		"act3":
			out = _act3()
		"hour_dusk":
			out = _hour_dusk()
		"hour_late":
			out = _hour_late()
		"hour_dawn":
			out = _hour_dawn()
		"ending":
			out = _ending()
		_:
			out = _motif(id)
	Kit.finish(out, 0.8, 0.05 if not LOOPS.has(id) else 0.0)
	return out


## A frequency adjusted so a whole number of its cycles fits `len` seconds (a seamless loop).
static func fit(f: float, length: float) -> float:
	return maxf(1.0, roundf(f * length)) / length


## Multiply a buffer by 1 + depth * sin(whole cycles over the loop): a slow swell that closes on itself.
static func _swell(out: PackedFloat32Array, cycles: float, depth: float, phase := 0.0) -> void:
	var n := out.size()
	for i in n:
		out[i] *= 1.0 - depth + depth * (0.5 + 0.5 * sin(TAU * cycles * float(i) / float(n) + phase))


static func _tension() -> PackedFloat32Array:
	var L: float = LEN["tension"]
	var out := Kit.buf(L)
	Kit.partial(out, 0.0, L, fit(73.4, L), 0.5, 0.0, 1.0e6)
	Kit.partial(out, 0.0, L, fit(77.8, L), 0.45, 0.0, 1.0e6)            # a minor second: it beats
	Kit.partial(out, 0.0, L, fit(36.7, L), 0.4, 0.0, 1.0e6)
	var hi := Kit.buf(L)
	Kit.partial(hi, 0.0, L, fit(1760.0, L), 0.12, 0.0, 1.0e6)
	Kit.partial(hi, 0.0, L, fit(1864.7, L), 0.1, 0.0, 1.0e6)
	for i in hi.size():
		hi[i] *= 0.5 + 0.5 * sin(TAU * 5.0 * float(i) / float(hi.size()) * L * 0.25)      # a tremolo of a few cycles a second
	Kit.mix(out, hi, 0.0, 1.0)
	_swell(out, 2.0, 0.5)
	return out


static func _combat(hot: bool) -> PackedFloat32Array:
	var beat := 0.6
	var bars := 8
	var L := beat * 4.0 * float(bars)
	var out := Kit.buf(L)
	for b in bars:
		var t0 := beat * 4.0 * float(b)
		if not hot:
			Kit.thud(out, t0, 110.0, 50.0, 0.4, 0.9, b * 3 + 1)
			Kit.thud(out, t0 + beat * 2.0, 100.0, 48.0, 0.4, 0.75, b * 3 + 2)
			if b % 2 == 1:
				Kit.thud(out, t0 + beat * 2.5, 120.0, 55.0, 0.3, 0.5, b * 3 + 3)
			var root := 73.4 if b % 4 < 2 else 65.4
			for q in 4:
				Kit.horn(out, t0 + beat * float(q), beat * 0.95, root, 0.22, 0.04)
		else:
			Kit.noise(out, t0 + beat, 0.22, 0.6, 800.0, 6500.0, 0.002, 0.07, b * 7 + 1)                  # the snare on 2
			Kit.noise(out, t0 + beat * 3.0, 0.22, 0.6, 800.0, 6500.0, 0.002, 0.07, b * 7 + 2)            # and on 4
			var notes := [293.7, 349.2, 293.7, 440.0, 392.0, 349.2, 293.7, 233.1]
			for s in 8:
				Kit.pluck(out, t0 + beat * 0.5 * float(s), float(notes[(s + b) % notes.size()]), 0.3, 0.25)
			if b % 2 == 0:
				Kit.choir(out, t0, beat * 4.0, 440.0 if b % 4 == 0 else 392.0, 0.2, 0.2)
	return out


static func _aftermath() -> PackedFloat32Array:
	var L: float = LEN["aftermath"]
	var out := Kit.buf(L)
	Kit.partial(out, 0.0, L, fit(220.0, L), 0.4, 0.0, 1.0e6)
	Kit.partial(out, 0.0, L, fit(329.6, L), 0.3, 0.0, 1.0e6)
	Kit.partial(out, 0.0, L, fit(110.0, L), 0.35, 0.0, 1.0e6)
	_swell(out, 2.0, 0.6)
	for i in 4:
		Kit.bell(out, 1.0 + 5.0 * float(i), [659.0, 587.0, 494.0, 440.0][i], 0.35, 1.6)             # one bell falling every five seconds
	return out


static func _act1() -> PackedFloat32Array:
	var L: float = LEN["act1"]
	var out := Kit.buf(L)
	for f: float in [73.4, 146.8, 220.0, 329.6]:
		Kit.partial(out, 0.0, L, fit(f, L), 0.3, 0.0, 1.0e6)
	var pad := Kit.buf(L)
	for f: float in [174.6, 261.6]:
		Kit.partial(pad, 0.0, L, fit(f, L), 0.22, 0.0, 1.0e6)
	_swell(pad, 3.0, 0.7)
	Kit.mix(out, pad, 0.0, 1.0)
	Kit.pluck(out, 4.0, 293.7, 0.3, 1.2)
	Kit.pluck(out, 12.0, 220.0, 0.3, 1.2)
	return out


static func _act2() -> PackedFloat32Array:
	var L: float = LEN["act2"]
	var out := Kit.buf(L)
	for f: float in [49.0, 73.4]:
		Kit.partial(out, 0.0, L, fit(f, L), 0.4, 0.0, 1.0e6)           # a fifth drone: G and D
	var notes := [98.0, 123.5, 146.8, 196.0]
	for i in 4:
		Kit.bell(out, 6.0 * float(i), float(notes[i]), 0.5, 2.0)         # the peal, rung from the bottom up
	return out


static func _act3() -> PackedFloat32Array:
	var L: float = LEN["act3"]
	var out := Kit.buf(L)
	Kit.partial(out, 0.0, L, fit(146.8, L), 0.4, 0.0, 1.0e6)
	Kit.partial(out, 0.0, L, fit(207.7, L), 0.32, 0.0, 1.0e6)           # D and G-sharp: the tritone, held
	Kit.partial(out, 0.0, L, fit(73.4, L), 0.35, 0.0, 1.0e6)
	var hi := Kit.buf(L)
	Kit.partial(hi, 0.0, L, fit(880.0, L), 0.1, 0.0, 1.0e6)
	_swell(hi, 3.0, 0.8)
	Kit.mix(out, hi, 0.0, 1.0)
	var k := 0.0
	while k < L - 0.3:
		Kit.noise(out, k, 0.03, 0.18, 2500.0, 8000.0, 0.001, 0.01, int(k * 10.0) + 5)               # the count
		k += 1.5
	return out


## Dusk: a warm major third over a low D, one plucked D now and again: the night has not yet made up its mind.
static func _hour_dusk() -> PackedFloat32Array:
	var L: float = LEN["hour_dusk"]
	var out := Kit.buf(L)
	for f: float in [73.4, 146.8, 185.0, 220.0]:
		Kit.partial(out, 0.0, L, fit(f, L), 0.28, 0.0, 1.0e6)
	_swell(out, 2.0, 0.5)
	Kit.pluck(out, 6.0, 293.7, 0.3, 1.4)
	Kit.pluck(out, 18.0, 370.0, 0.3, 1.4)
	return out


## The late hours: an open fifth with nothing in the middle and a high bell every eight seconds, very far off.
static func _hour_late() -> PackedFloat32Array:
	var L: float = LEN["hour_late"]
	var out := Kit.buf(L)
	for f: float in [98.0, 147.0]:
		Kit.partial(out, 0.0, L, fit(f, L), 0.35, 0.0, 1.0e6)
	_swell(out, 1.0, 0.6)
	for i in 3:
		Kit.bell(out, 2.0 + 8.0 * float(i), 1318.5, 0.2, 2.0)
	return out


## The grey before dawn: a choir rising a step at a time, three bells climbing.
static func _hour_dawn() -> PackedFloat32Array:
	var L: float = LEN["hour_dawn"]
	var out := Kit.buf(L)
	for f: float in [196.0, 294.0, 392.0]:
		Kit.partial(out, 0.0, L, fit(f, L), 0.25, 0.0, 1.0e6)
	_swell(out, 1.0, 0.8, -1.2)
	var notes := [392.0, 494.0, 587.0]
	for i in 3:
		Kit.bell(out, 4.0 + 6.0 * float(i), float(notes[i]), 0.3, 2.0)
	return out


## After the door is shut: open fifths in D major, one bell falling every six seconds. The cold stays; it no longer pulls.
static func _ending() -> PackedFloat32Array:
	var L: float = LEN["ending"]
	var out := Kit.buf(L)
	for f: float in [73.4, 110.0, 146.8, 220.0, 293.7]:
		Kit.partial(out, 0.0, L, fit(f, L), 0.22, 0.0, 1.0e6)
	_swell(out, 2.0, 0.5)
	var notes := [587.0, 440.0, 370.0, 293.7]
	for i in 4:
		Kit.bell(out, 1.0 + 6.0 * float(i), float(notes[i]), 0.3, 2.2)
	return out


static func _motif(id: String) -> PackedFloat32Array:
	var out := Kit.buf(7.0)
	match id:
		"motif_village":
			var n := [293.7, 349.2, 392.0, 440.0]
			for i in 4:
				Kit.pluck(out, 0.6 * float(i), float(n[i]), 0.45, 0.9)
			Kit.bell(out, 2.6, 523.0, 0.3, 1.6)
		"motif_wood":
			Kit.horn(out, 0.0, 3.4, 73.4, 0.5, 1.2)
			Kit.pluck(out, 1.2, 220.0, 0.35, 1.2)
			Kit.pluck(out, 2.2, 146.8, 0.35, 1.2)
			Kit.pluck(out, 3.2, 155.6, 0.3, 1.4)
		"motif_fen":
			Kit.choir(out, 0.0, 4.2, 164.8, 0.3, 1.5)
			Kit.pluck(out, 1.4, 493.9, 0.3, 1.6)
			Kit.pluck(out, 3.0, 392.0, 0.3, 1.8)
		"motif_heights":
			Kit.bell(out, 0.0, 880.0, 0.35, 2.0)
			Kit.bell(out, 1.2, 1318.5, 0.3, 2.0)
			Kit.noise(out, 0.0, 5.0, 0.12, 400.0, 2200.0, 1.5, 2.0, 11)
		"motif_crypt":
			Kit.bell(out, 0.0, 98.0, 0.55, 3.0)
			Kit.choir(out, 0.8, 4.4, 146.8, 0.18, 1.5)
			Kit.choir(out, 0.8, 4.4, 155.6, 0.16, 1.5)
		"motif_act1":
			var m := [196.0, 246.9, 293.7, 392.0]
			for i in 4:
				Kit.pluck(out, 0.55 * float(i), float(m[i]), 0.45, 1.0)
			Kit.bell(out, 2.3, 392.0, 0.35, 2.0)
		"motif_act2":
			var m2 := [98.0, 123.5, 146.8, 196.0]
			for i in 4:
				Kit.bell(out, 1.0 * float(i), float(m2[i]), 0.5, 2.0)
		"motif_act3":
			var m3 := [392.0, 293.7, 246.9, 196.0]        # the same four notes, top first: the way the bells stopped
			for i in 4:
				Kit.bell(out, 1.0 * float(i), float(m3[i]), 0.45, 2.0)
	return out
