extends RefCounted
## NPC voices: Sims-style babble, synthesised (no recordings). A voice FAMILY (dwarf, keep, man,
## old_man, woman, old_woman, teen, child) owns a bank of syllables made the way a throat makes them:
## a glottal pulse train (with jitter, breath and, for the gruff, a creak) through three vowel
## formant resonators, after a consonant onset (plosive burst, fricative hiss, nasal murmur, liquid
## glide) and sometimes before a coda. Each NPC then gets its own PROFILE: family + pitch + pace +
## lilt + loudness from its seed, so no two people in the Realm sound alike.
##   profile(family, seed)          -> {family, pitch, pace, lilt, vol}
##   family_of(sex, age) / for_node(npc)
##   speaker3d(host) / speaker2d(host) -> a player with a polyphonic stream (several syllables overlap)
##   say(player, prof, syllables, stress, question)   a word, syllable by syllable, on timers
##   syllable(player, prof, pitch_mult, vol_add)      one syllable now (the dialogue box types with it)
##   laugh(player, prof)                               "ha-ha-ha", falling
##   prewarm(families)                                 build (or load) the banks behind the loading screen
## Banks are cached through GenCache. Load by path (no class_name):
##   const Voice := preload("res://core/npc/npc_voice.gd")

const RATE := 22050
const BANK := 16
const SELF := "res://core/npc/npc_voice.gd"
const GenCache := preload("res://core/world/realm/gen_cache.gd")

## f0 (Hz), formant scale, breath, pitch jitter, creak, syllable length (s)
const FAMILIES := {
	"dwarf":     {"f0": 96.0,  "fs": 0.86, "breath": 0.10, "jit": 0.014, "creak": 0.35, "len": 0.13},
	"keep":      {"f0": 106.0, "fs": 0.90, "breath": 0.07, "jit": 0.010, "creak": 0.22, "len": 0.12},
	"man":       {"f0": 120.0, "fs": 1.00, "breath": 0.06, "jit": 0.008, "creak": 0.08, "len": 0.115},
	"old_man":   {"f0": 128.0, "fs": 0.97, "breath": 0.24, "jit": 0.028, "creak": 0.30, "len": 0.14},
	"woman":     {"f0": 205.0, "fs": 1.17, "breath": 0.12, "jit": 0.008, "creak": 0.0,  "len": 0.11},
	"old_woman": {"f0": 188.0, "fs": 1.12, "breath": 0.26, "jit": 0.030, "creak": 0.12, "len": 0.13},
	"teen":      {"f0": 228.0, "fs": 1.22, "breath": 0.14, "jit": 0.010, "creak": 0.0,  "len": 0.10},
	"child":     {"f0": 272.0, "fs": 1.32, "breath": 0.12, "jit": 0.012, "creak": 0.0,  "len": 0.095},
}
## F1, F2, F3 (Hz, adult male reference): a, e, i, o, u, schwa, ae
const VOWELS := [
	Vector3(730, 1090, 2440), Vector3(530, 1840, 2480), Vector3(300, 2250, 3000),
	Vector3(570, 840, 2410), Vector3(320, 870, 2240), Vector3(500, 1500, 2500), Vector3(660, 1720, 2410),
]
const ONSETS := ["", "", "p", "t", "k", "b", "d", "g", "m", "n", "l", "r", "w", "s", "sh", "h", "v", "f"]
const CODAS := ["", "", "", "", "n", "m", "s", "k", "l", "r"]

static var _banks := {}          # family -> Array[AudioStreamWAV]


## Drop the engine resources held in static vars (called when the night is torn down): statics
## outlive the renderer at quit ("RID allocations leaked at exit"). Rebuilt on next use.
static func release() -> void:
	_banks.clear()


# --- profiles --------------------------------------------------------------------------------------

static func family_of(sex: String, age: String) -> String:
	match age:
		"child":
			return "child"
		"teen":
			return "teen"
		"old":
			return "old_woman" if sex == "f" else "old_man"
	return "woman" if sex == "f" else "man"


static func profile(family: String, seed_v: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v * 7919 + 17
	return {
		"family": family if FAMILIES.has(family) else "man",
		"pitch": rng.randf_range(0.88, 1.13),      # playback pitch on top of the family's f0
		"pace": rng.randf_range(0.85, 1.18),       # syllables per second, relative
		"lilt": rng.randf_range(0.03, 0.10),       # how far the pitch wanders between syllables
		"vol": rng.randf_range(-1.5, 1.5),
		"seed": seed_v,
	}


## A profile for an NPC node: its own `voice` if it has one, else from its rig options.
static func for_node(n: Object) -> Dictionary:
	if n == null:
		return profile("dwarf", 1)
	var v: Variant = n.get("voice")
	if v is Dictionary and not (v as Dictionary).is_empty():
		return v
	return profile("dwarf", hash(str(n.get("name"))))


# --- players ---------------------------------------------------------------------------------------

static func speaker3d(host: Node3D, max_dist := 18.0) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.name = "Voice"
	var poly := AudioStreamPolyphonic.new()
	poly.polyphony = 6
	p.stream = poly
	p.bus = "SFX"
	p.unit_size = 3.0
	p.max_distance = max_dist
	p.attenuation_filter_cutoff_hz = 6000.0
	p.position = Vector3(0.0, 1.5, 0.0)
	host.add_child(p)
	return p


static func speaker2d(host: Node) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.name = "Voice"
	var poly := AudioStreamPolyphonic.new()
	poly.polyphony = 6
	p.stream = poly
	p.bus = "SFX"
	host.add_child(p)
	return p


static func _playback(player: Node) -> AudioStreamPlaybackPolyphonic:
	if player == null or not is_instance_valid(player) or not player.is_inside_tree():
		return null
	if not player.call("is_playing"):
		player.call("play")
	return player.call("get_stream_playback") as AudioStreamPlaybackPolyphonic


## One syllable now, in this profile's voice.
static func syllable(player: Node, prof: Dictionary, pitch_mult := 1.0, vol_add := 0.0) -> void:
	var pb := _playback(player)
	if pb == null:
		return
	var bank := bank_of(String(prof.get("family", "man")))
	if bank.is_empty():
		return
	var s: AudioStreamWAV = bank[randi() % bank.size()]
	var lilt := float(prof.get("lilt", 0.05))
	var pitch := float(prof.get("pitch", 1.0)) * pitch_mult * (1.0 + randf_range(-lilt, lilt))
	pb.play_stream(s, 0.0, float(prof.get("vol", 0.0)) + vol_add, pitch)


## A spoken word of `n` syllables, spaced by the profile's pace; a question lifts its tail.
static func say(player: Node, prof: Dictionary, n := 2, stress := 0.5, question := false, vol_add := 0.0) -> void:
	if player == null or not is_instance_valid(player):
		return
	var gap := 0.12 / float(prof.get("pace", 1.0))
	var tree := player.get_tree()
	for k in n:
		var lift := 1.0 + (0.08 * float(k) if question else -0.025 * float(k)) + (0.06 * stress if k == 0 else 0.0)
		var loud := vol_add + (2.0 * stress if k == 0 else 0.0)
		if k == 0:
			syllable(player, prof, lift, loud)
		else:
			tree.create_timer(gap * float(k) * randf_range(0.85, 1.15), false).timeout.connect(
				func() -> void: syllable(player, prof, lift, loud))


## Ambient talk: each time `life` (npc_life.gd) begins a word and the camera is within `max_r`, say
## it from `host` (its own positional Voice player, made on first use). Call after life.step().
static func chatter(host: Node3D, life: Object, prof: Dictionary, vol := -12.0, max_r := 16.0) -> void:
	var w := int(life.get("words"))
	if not host.has_meta(&"voice_words"):
		host.set_meta(&"voice_words", w)
		return
	if w == int(host.get_meta(&"voice_words")):
		return
	host.set_meta(&"voice_words", w)
	var vp := host.get_viewport()
	var cam := vp.get_camera_3d() if vp else null
	if cam == null or cam.global_position.distance_squared_to(host.global_position) > max_r * max_r:
		return
	var p: Node = host.get_node_or_null("Voice")
	if p == null:
		p = speaker3d(host, max_r + 4.0)
	say(p, prof, int(life.get("word_syll")), float(life.get("word_stress")), false, vol)


## Laugh from `host`'s own Voice player when the camera is near.
static func laugh_at(host: Node3D, prof: Dictionary, vol := -10.0, max_r := 18.0) -> void:
	var vp := host.get_viewport()
	var cam := vp.get_camera_3d() if vp else null
	if cam == null or cam.global_position.distance_squared_to(host.global_position) > max_r * max_r:
		return
	var p: Node = host.get_node_or_null("Voice")
	if p == null:
		p = speaker3d(host, max_r + 4.0)
	laugh(p, prof, vol)


## Laughter: breathy "ha" syllables, quick and falling.
static func laugh(player: Node, prof: Dictionary, vol_add := 0.0) -> void:
	if player == null or not is_instance_valid(player):
		return
	var n := randi_range(3, 6)
	var tree := player.get_tree()
	for k in n:
		var lift := 1.18 - 0.05 * float(k)
		var t := 0.11 * float(k) / float(prof.get("pace", 1.0))
		if k == 0:
			syllable(player, prof, lift, vol_add + 1.0)
		else:
			tree.create_timer(t, false).timeout.connect(func() -> void: syllable(player, prof, lift, vol_add))


# --- banks -----------------------------------------------------------------------------------------

static func prewarm(families: Array = FAMILIES.keys()) -> void:
	for f: String in families:
		bank_of(f)


static func bank_of(family: String) -> Array:
	if _banks.has(family):
		return _banks[family]
	var out: Array = []
	var cached: Variant = GenCache.load_var("npc_voice_" + family, SELF)
	if cached is Array and (cached as Array).size() == BANK:
		for b: Variant in cached:
			out.append(_wav(b as PackedByteArray))
	else:
		var fam: Dictionary = FAMILIES.get(family, FAMILIES["man"])
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(family) + 101
		var raw: Array = []
		for k in BANK:
			var bytes := _to_bytes(_synth(fam, rng))
			raw.append(bytes)
			out.append(_wav(bytes))
		GenCache.save_var("npc_voice_" + family, SELF, raw)
	_banks[family] = out
	return out


static func _wav(bytes: PackedByteArray) -> AudioStreamWAV:
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = bytes
	return s


static func _to_bytes(pcm: PackedFloat32Array) -> PackedByteArray:
	var peak := 0.0001
	for v in pcm:
		peak = maxf(peak, absf(v))
	var g := 0.85 / peak
	var b := PackedByteArray()
	b.resize(pcm.size() * 2)
	for i in pcm.size():
		b.encode_s16(i * 2, int(clampf(pcm[i] * g, -1.0, 1.0) * 32767.0))
	return b


## A two-pole resonator's coefficients for centre f, bandwidth bw: [a1, a2, gain].
static func _res(f: float, bw: float) -> Vector3:
	var r := exp(-PI * bw / RATE)
	return Vector3(2.0 * r * cos(TAU * minf(f, RATE * 0.45) / RATE), r * r, 1.0 - r)


## One syllable: onset + vowel (possibly gliding to a second) + coda, as float PCM.
static func _synth(fam: Dictionary, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var fs: float = fam.fs
	var len_s := float(fam.len) * rng.randf_range(0.85, 1.25)
	var onset: String = ONSETS[rng.randi() % ONSETS.size()]
	var coda: String = CODAS[rng.randi() % CODAS.size()]
	var va: Vector3 = VOWELS[rng.randi() % VOWELS.size()] * fs
	var vb: Vector3 = va if rng.randf() < 0.6 else VOWELS[rng.randi() % VOWELS.size()] * fs
	var on_len := 0.0
	match onset:
		"p", "t", "k", "b", "d", "g":
			on_len = 0.022
		"s", "sh", "f", "v":
			on_len = rng.randf_range(0.045, 0.065)
		"m", "n", "l", "r", "w", "h":
			on_len = 0.04
	var co_len := 0.0 if coda == "" else rng.randf_range(0.03, 0.05)
	var total := on_len + len_s + co_len
	var n := int(total * RATE)
	var pcm := PackedFloat32Array()
	pcm.resize(n)
	var f0: float = fam.f0 * rng.randf_range(0.94, 1.06)
	var ph := 0.0
	var ph2 := 0.0
	var g_prev := 0.0
	var jit := 0.0
	var y := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]   # 3 formants + 1 consonant resonator, 2 taps each
	var lp := 0.0
	var res: Array = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
	var cres := Vector3.ZERO
	var plosive_f := {"p": 900.0, "b": 700.0, "t": 4200.0, "d": 3200.0, "k": 2200.0, "g": 1800.0}
	var fric_f := {"s": 6200.0, "sh": 2900.0, "f": 4800.0, "v": 1600.0}
	var liquid := {"l": Vector3(360, 1300, 2700), "r": Vector3(420, 1150, 1600), "w": Vector3(300, 700, 2200),
		"m": Vector3(250, 1100, 2300), "n": Vector3(250, 1500, 2500)}
	for i in n:
		var t := float(i) / RATE
		var in_onset := t < on_len
		var in_coda := co_len > 0.0 and t > total - co_len
		# formant targets: the vowel (gliding a -> b), led in by a liquid/nasal onset, out to a coda
		var vt := clampf((t - on_len) / maxf(len_s, 0.01), 0.0, 1.0)
		var form := va.lerp(vb, smoothstep(0.3, 0.9, vt))
		if liquid.has(onset) and t < on_len + 0.03:
			form = (liquid[onset] as Vector3 * fs).lerp(form, clampf((t) / (on_len + 0.03), 0.0, 1.0))
		if in_coda and liquid.has(coda):
			form = form.lerp(liquid[coda] as Vector3 * fs, clampf((t - (total - co_len)) / co_len, 0.0, 1.0))
		if i % 32 == 0:
			res[0] = _res(form.x, 80.0 * fs)
			res[1] = _res(form.y, 100.0 * fs)
			res[2] = _res(form.z, 150.0 * fs)
		# glottal source: Rosenberg pulse, differentiated; jitter random-walks the pitch
		jit = clampf(jit + rng.randf_range(-1.0, 1.0) * float(fam.jit) * 0.15, -float(fam.jit), float(fam.jit))
		var f := f0 * (1.0 + 0.05 * (1.0 - 2.0 * vt) * 0.5 + jit)
		ph += f / RATE
		ph2 += f * 0.5 / RATE
		ph -= floorf(ph)
		ph2 -= floorf(ph2)
		var g := 0.0
		if ph < 0.4:
			g = 0.5 * (1.0 - cos(PI * ph / 0.4))
		elif ph < 0.56:
			g = cos(PI * (ph - 0.4) / 0.32)
		var src := (g - g_prev) * 9.0
		g_prev = g
		src *= 1.0 - float(fam.creak) * 0.5 * (1.0 + sin(TAU * ph2))     # creak: a subharmonic flutter
		var noise := rng.randf_range(-1.0, 1.0)
		# voicing amount and noise by segment
		var voiced := 1.0
		var hiss := 0.0
		var hiss_f := 0.0
		if in_onset:
			match onset:
				"p", "t", "k":
					voiced = 0.0
					hiss = 0.9 if t > on_len - 0.009 else 0.0
					hiss_f = plosive_f[onset]
				"b", "d", "g":
					voiced = 0.25
					hiss = 0.5 if t > on_len - 0.008 else 0.0
					hiss_f = plosive_f[onset]
				"s", "sh", "f":
					voiced = 0.0
					hiss = 0.55
					hiss_f = fric_f[onset]
				"v":
					voiced = 0.35
					hiss = 0.35
					hiss_f = fric_f[onset]
				"h":
					voiced = 0.0
					hiss = 0.0
				"m", "n":
					voiced = 0.55
		elif in_coda:
			var ct := (t - (total - co_len)) / co_len
			match coda:
				"s":
					voiced = 1.0 - ct
					hiss = 0.45 * ct
					hiss_f = 6000.0
				"k":
					voiced = 0.0 if ct > 0.3 else 1.0 - ct * 3.0
					hiss = 0.8 if ct > 0.75 else 0.0
					hiss_f = 2200.0
				"m", "n":
					voiced = 0.6
		# breath rides on the voice; "h" is all breath through the vowel's own formants
		var exc := src * voiced + noise * float(fam.breath) * (0.6 + voiced * 0.4)
		if in_onset and onset == "h":
			exc = noise * 0.7
		var out := 0.0
		var gains := [1.0, 0.55, 0.28]
		for k in 3:
			var c: Vector3 = res[k]
			var v: float = c.z * exc + c.x * float(y[k * 2]) - c.y * float(y[k * 2 + 1])
			y[k * 2 + 1] = y[k * 2]
			y[k * 2] = v
			out += v * float(gains[k])
		if (in_onset and onset in ["m", "n"]) or (in_coda and coda in ["m", "n"]):
			out *= 0.5                                             # nasal murmur: muffled
		if hiss > 0.0:
			if cres.x == 0.0 or i % 64 == 0:
				cres = _res(hiss_f, hiss_f * 0.25)
			var hv: float = cres.z * noise + cres.x * float(y[6]) - cres.y * float(y[7])
			y[7] = y[6]
			y[6] = hv
			out += hv * hiss * 3.0
		# envelope: soft attack into the vowel, release at the end
		var env := clampf((t - on_len * 0.6) / 0.012, 0.0, 1.0) if not in_onset else 0.8
		env *= clampf((total - t) / 0.03, 0.0, 1.0)
		lp += (out * env - lp) * 0.55                               # gentle lowpass
		pcm[i] = lp
	return pcm
