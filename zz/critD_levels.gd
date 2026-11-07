extends Node
## Level audit of every sound in the game (critique D, r29), headless:
##   godot --headless --path . res://zz/critD_levels.tscn [-- --out=<dir>]
## Builds (or loads from GenCache) every stream: the art/audio files, combat Synth kinds and creature
## voices, the staff, the village's work sounds, NPC voice syllables, LifeSynth and ScapeSynth (beds,
## spots, music voices), and measures each: peak, loudest 100 ms RMS (one-shots) or whole RMS (loops),
## all dBFS. Then adds the level the game plays it at (its volume_db, the distance it is usually heard
## from with its attenuation model, and its bus at default settings) to give the level AT THE LISTENER.
## Prints one line per source ("LEVEL <name> ...") sorted loudest first, and the spread per group.
## Writes <out>/levels.tsv (and each stream as <out>/wav/<name>.wav with --wav).
## Ends LEVELS DONE n.

const Synth := preload("res://core/vfx/synth.gd")
const StaffSfx := preload("res://core/vfx/staff_sfx.gd")
const LifeSynth := preload("res://core/life/wildlife/life_synth.gd")
const ScapeSynth := preload("res://core/life/wildlife/scape_synth.gd")
const VillageAudio := preload("res://core/life/village/village_audio.gd")
const NpcVoice := preload("res://core/npc/npc_voice.gd")

## Default bus gains (Settings defaults): Master 0.9, SFX 0.85, Ambience 0.7 (linear)
var BUS := {"SFX": linear_to_db(0.85), "Ambience": linear_to_db(0.7), "AmbOut": linear_to_db(0.7), "Music": linear_to_db(0.7)}

var out_dir := ""
var write_wav := false
var rows: Array = []


func _ready() -> void:
	Travel._busy = true
	out_dir = OS.get_user_data_dir() + "/critD"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.trim_prefix("--out=")
		elif a == "--wav":
			write_wav = true
	DirAccess.make_dir_recursive_absolute(out_dir + "/wav")
	_run.call_deferred()


## Godot's inverse-distance attenuation: 20 log10(unit / d) (capped at max_db 3 together with volume).
static func att(unit: float, d: float) -> float:
	return linear_to_db(1.0 / (d / unit + 0.00001))


## name, group, stream, volume_db, bus, distance (m, 0 = 2D), unit_size, loop
func add(nm: String, grp: String, s: AudioStream, vol: float, bus: String, dist := 0.0, unit := 4.0, loop := false, src := "") -> void:
	if s == null:
		print("LEVEL MISSING ", nm)
		return
	var m := measure(s, src)
	if m.is_empty():
		print("LEVEL UNREADABLE ", nm)
		return
	var a := 0.0
	if dist > 0.0:
		a = att(unit, dist)
	var lvl := float(m.loud) + minf(vol + a, 3.0) + float(BUS.get(bus, 0.0)) + linear_to_db(0.9)
	var pk := float(m.peak) + minf(vol + a, 3.0) + float(BUS.get(bus, 0.0)) + linear_to_db(0.9)
	rows.append({"name": nm, "grp": grp, "peak_src": m.peak, "loud_src": m.loud, "rms_src": m.rms, "len": m.len,
		"vol": vol, "bus": bus, "dist": dist, "att": a, "at_ear": lvl, "peak_ear": pk, "loop": loop, "rate": m.rate})
	if write_wav and s is AudioStreamWAV:
		(s as AudioStreamWAV).save_to_wav(out_dir + "/wav/" + nm.replace("/", "_").replace(":", "_") + ".wav")


## Peak, loudest 100 ms RMS and whole-stream RMS (dBFS) of a 16-bit (or 8-bit) PCM AudioStreamWAV.
static func measure(s: AudioStream, src_path := "") -> Dictionary:
	var w := s as AudioStreamWAV
	if w == null:
		return {}
	var d := w.data
	var fmt := w.format
	var ch := 2 if w.stereo else 1
	var rate := float(w.mix_rate)
	if fmt != AudioStreamWAV.FORMAT_16_BITS and fmt != AudioStreamWAV.FORMAT_8_BITS:
		# imported files are QOA-compressed: read the 16-bit source .wav next to the import instead
		var src := riff(w.resource_path if w.resource_path.ends_with(".wav") else src_path)
		if src.is_empty():
			return {}
		d = src.data
		fmt = AudioStreamWAV.FORMAT_16_BITS
		ch = int(src.ch)
		rate = float(src.rate)
	var n := 0
	var x := PackedFloat32Array()
	if fmt == AudioStreamWAV.FORMAT_16_BITS:
		n = d.size() / 2
		x.resize(n)
		for i in n:
			x[i] = float(d.decode_s16(i * 2)) / 32768.0
	elif fmt == AudioStreamWAV.FORMAT_8_BITS:
		n = d.size()
		x.resize(n)
		for i in n:
			x[i] = float(d.decode_s8(i)) / 128.0
	else:
		return {}
	var win := maxi(int(rate * 0.1) * ch, 1)
	var peak := 0.0
	var sum := 0.0
	var wsum := 0.0
	var best := 0.0
	for i in n:
		var v := x[i]
		peak = maxf(peak, absf(v))
		sum += v * v
		wsum += v * v
		if i >= win:
			var o := x[i - win]
			wsum -= o * o
		if i >= win - 1:
			best = maxf(best, wsum / float(win))
	if n < win:
		best = sum / float(maxi(n, 1))
	return {"peak": linear_to_db(maxf(peak, 1e-6)), "loud": linear_to_db(sqrt(maxf(best, 1e-12))),
		"rms": linear_to_db(sqrt(maxf(sum / float(maxi(n, 1)), 1e-12))), "len": float(n / ch) / rate, "rate": rate}


## The PCM of a 16-bit RIFF .wav source file: {data, ch, rate} (empty if it is not one).
static func riff(path: String) -> Dictionary:
	if path == "" or not FileAccess.file_exists(path):
		return {}
	var b := FileAccess.get_file_as_bytes(path)
	if b.size() < 44 or b.slice(0, 4).get_string_from_ascii() != "RIFF":
		return {}
	var i := 12
	var ch := 1
	var rate := 44100
	var bits := 16
	while i + 8 <= b.size():
		var id := b.slice(i, i + 4).get_string_from_ascii()
		var n := b.decode_u32(i + 4)
		if id == "fmt ":
			ch = b.decode_u16(i + 10)
			rate = b.decode_u32(i + 12)
			bits = b.decode_u16(i + 22)
		elif id == "data":
			if bits != 16:
				return {}
			return {"data": b.slice(i + 8, i + 8 + n), "ch": ch, "rate": rate}
		i += 8 + n + (n & 1)
	return {}


func _run() -> void:
	var t0 := Time.get_ticks_msec()
	# ---- the wanderer (camera ~3.7 m behind; the body is ~4 m from the listener)
	for i in 8:
		add("step_%d run" % i, "player", load("res://art/audio/step_%d.wav" % i), -4.0, "SFX", 4.0, 3.0)
	add("step_0 walk", "player", load("res://art/audio/step_0.wav"), -11.0, "SFX", 4.0, 3.0)
	add("bolt_cast.wav (rig)", "player", load("res://art/audio/bolt_cast.wav"), 0.0, "SFX", 4.0, 1.0)
	add("jump_air", "player", load("res://art/audio/jump_air.wav"), -5.0, "SFX", 4.0)
	add("hurt", "player", load("res://art/audio/hurt.wav"), -3.0, "SFX", 4.0)
	add("slide_scrape", "player", load("res://art/audio/slide_scrape.wav"), -8.0, "SFX", 4.0, 1.0)
	add("mark_tick", "player", load("res://art/audio/mark_tick.wav"), 0.0, "SFX", 8.0)
	var Foley := load("res://core/vfx/foley.gd")
	for sf: StringName in Foley.SURFACES:
		add("hoof_%s trot (4 m)" % sf, "horse", Foley.stream("hoof_" + String(sf), 0), Foley.hoof_db(sf, 1.0, 0.5, false), "SFX", 4.0)
		add("hoof_%s gallop draught (4 m)" % sf, "horse", Foley.stream("hoof_" + String(sf), 0), Foley.hoof_db(sf, 1.6, 1.0, true), "SFX", 4.0)
	for k: String in ["jingle", "creak", "snort", "breath", "grunt", "thump"]:
		add("horse_" + k, "horse", Foley.stream("horse_" + k, 0), {"jingle": -17.0, "creak": -26.0, "snort": -10.0, "breath": -16.0, "grunt": -10.0, "thump": -5.0}[k], "SFX", 4.0)
	for k: String in ["grass", "stone", "wood", "water", "mud", "ash", "salt"]:
		add("step_%s layer run" % k, "player", Foley.stream("step_" + k, 0), -7.0, "SFX", 4.0, 3.0)
	add("cloth_run", "player", Foley.stream("cloth_run", 0), -20.0, "SFX", 4.0)
	for k: String in StaffSfx.KINDS:
		var v := StaffSfx.variants(k)
		if v.is_empty():
			continue
		var vol := 0.0
		var dist := 4.0
		match k:
			"tap": vol = -12.0
			"swish": vol = -8.0
			"lance_fire": vol = -1.0
			"lance_charge": vol = -7.0
			"bolt_hit", "lance_hit", "burn_hit", "chill_hit", "shatter", "tether_hit": dist = 14.0
			"dart": vol = -6.0
			"combo": vol = -5.0
			"mote": vol = -6.0
			"ward_pulse": vol = -4.0
		add("staff:" + k, "staff", v[0], vol, "SFX", dist, 4.0, k == "lance_charge")
	# ---- combat (hollowed things ~8 m off, hits 10-14 m down the bolt)
	for k: String in Synth.KINDS:
		var vol := 0.0
		var dist := 10.0
		match k:
			"flesh", "bone": vol = -3.0
			"growl": vol = 2.0
			"roar": vol = 2.0; dist = 18.0
			"stagger": vol = 0.0
			"spike": vol = 0.0
			"block": vol = -1.0
			"burrow": vol = -2.0
			"chant": vol = -4.0
		add("synth:" + k, "combat", Synth.get_stream(k), vol, "SFX", dist)
	for fam: String in Synth.VOICES:
		for act: String in Synth.ACTS:
			var vol := {"tell": -8.0, "hurt": -9.0, "die": -4.0, "call": 0.0, "flee": -6.0}[act] as float
			add("voice:%s/%s" % [fam, act], "creature", Synth._voice_take(fam, act, 0), vol, "SFX", 9.0)
	add("enemy_die.wav", "combat", load("res://art/audio/enemy_die.wav"), -6.0, "SFX", 9.0)
	add("pounce_shriek.wav", "combat", load("res://art/audio/pounce_shriek.wav"), -4.0, "SFX", 9.0)
	add("spit.wav", "combat", load("res://art/audio/spit.wav"), -4.0, "SFX", 9.0)
	add("shade_whisper.wav", "combat", load("res://art/audio/shade_whisper.wav"), -14.0, "SFX", 8.0, 1.0, true)
	for f in ["ward_chime", "nova_boom", "bolt_impact", "lance_impact", "lance_fire", "lance_charge", "brazier_loop", "step_blink"]:
		var p := "res://art/audio/%s.wav" % f
		if ResourceLoader.exists(p):
			add(f + ".wav", "world", load(p), -2.0 if f == "ward_chime" else 0.0, "Ambience" if f == "brazier_loop" else "SFX", 6.0, 4.0 if f != "brazier_loop" else 1.0, f == "brazier_loop")
	# ---- village work, NPC voices (a villager ~6 m off; the dialogue box in 2D)
	for k: String in VillageAudio.KINDS:
		add("village:" + k, "village", VillageAudio.stream(k), -6.0, "SFX", 12.0)
	for fam: String in NpcVoice.FAMILIES:
		var bank: Array = NpcVoice.bank_of(fam)
		if bank.is_empty():
			continue
		add("npc:%s 3d" % fam, "npc", bank[0], 0.0, "SFX", 6.0, 3.0)
		add("npc:%s dialogue" % fam, "npc", bank[0], 0.0, "SFX")
	# ---- the night: beds at full weight, spot calls at their palette distance, wildlife calls
	var Amb := preload("res://core/world/ambience.gd")
	for key: String in Amb.BEDS:
		var src := String(Amb.BEDS[key][0])
		var s: AudioStream = Amb._bed_stream(src)
		add("bed:" + key, "bed", s, float(Amb.BEDS[key][1]), "AmbOut" if bool(Amb.BEDS[key][2]) else "Ambience", 0.0, 1.0, true, src if src.begins_with("res://") else LifeSynth.DIR + src.trim_prefix("life:") + ".wav")
	for k: String in ["twig", "creak", "drip", "pebbles", "blurp", "bittern", "nightjar", "vixen", "bellow", "howl", "bones", "whisper", "bell_far", "peewit"]:
		var loud := k in ["bittern", "howl", "bell_far", "bellow"]
		add("spot:" + k, "spot", ScapeSynth.stream(k), -6.5 + (3.0 if loud else 0.0), "AmbOut", 30.0, 10.0)
	for k: String in ["owl", "owl2", "crow", "heron", "squeak", "plop", "flap", "snort"]:
		var vol: float = {"owl": -12.0, "owl2": -12.0, "crow": -8.0, "heron": -8.0, "squeak": -16.0, "plop": -14.0, "flap": -14.0, "snort": -10.0}[k]
		var unit: float = {"owl": 12.0, "owl2": 12.0, "crow": 9.0, "heron": 10.0, "squeak": 3.0, "plop": 3.0, "flap": 5.0, "snort": 8.0}[k]
		add("life:" + k, "wildlife", LifeSynth.stream(k), vol, "AmbOut", 20.0, unit, false, LifeSynth.DIR + k + ".wav")
	add("life:frogs (chorus)", "wildlife", LifeSynth.stream("frogs"), float(load("res://core/life/wildlife/life_pond.gd").get_script_constant_map().get("CHORUS_DB", -15.0)), "AmbOut", 15.0, 7.0, true, LifeSynth.DIR + "frogs.wav")
	for k: String in ["bellow", "vixen", "hooves", "peewit", "pounce", "squeak_soft"]:
		add("scape:%s (wild)" % k, "wildlife", ScapeSynth.stream(k), -10.0, "AmbOut", 25.0, 10.0)
	# ---- weather
	add("rain_open", "weather", LifeSynth.stream("rain"), -10.5, "AmbOut", 0.0, 1.0, true, LifeSynth.DIR + "rain.wav")
	for k: String in ["rain_leaves", "rain_roof", "rain_water"]:
		add(k, "weather", ScapeSynth.stream(k), {"rain_leaves": -12.0, "rain_roof": -9.5, "rain_water": -13.0}[k], "AmbOut", 0.0, 1.0, true)
	add("wind (gust 1.0)", "weather", LifeSynth.stream("wind"), -15.0 + linear_to_db(0.88), "AmbOut", 0.0, 1.0, true, LifeSynth.DIR + "wind.wav")
	add("thunder far", "weather", LifeSynth.stream("thunder"), -7.0, "AmbOut", 0.0, 1.0, false, LifeSynth.DIR + "thunder.wav")
	add("crack near", "weather", ScapeSynth.stream("crack"), -1.0, "AmbOut")
	add("phen:surge (rift 80 m)", "phenomena", ScapeSynth.stream("surge"), -4.0, "Ambience", 80.0, 70.0)
	add("phen:bolide", "phenomena", ScapeSynth.stream("bolide"), -9.0, "AmbOut")
	add("phen:chime (wisp 8 m)", "phenomena", ScapeSynth.stream("chime"), -9.0, "Ambience", 8.0, 6.0)
	add("phen:wisp_hum (6 m)", "phenomena", ScapeSynth.stream("wisp_hum"), -14.0, "Ambience", 6.0, 3.0, true)
	# ---- music (its DB on top of each voice's level; on the Music bus, which follows the Ambience slider by default)
	var mdb := float(load("res://core/life/wildlife/scape_music.gd").get_script_constant_map().get("DB", -9.0))
	add("music:pad_rest", "music", ScapeSynth.stream("pad_rest"), mdb - 27.0, "Music", 0.0, 1.0, true)
	add("music:pad_dark", "music", ScapeSynth.stream("pad_dark"), mdb - 25.0, "Music", 0.0, 1.0, true)
	add("music:pulse", "music", ScapeSynth.stream("pulse"), mdb - 20.0, "Music")
	add("music:harp", "music", ScapeSynth.stream("harp"), mdb - 15.0 - 3.0, "Music")
	add("music:bell", "music", ScapeSynth.stream("bell"), mdb - 15.0 - 5.0, "Music")
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.at_ear) > float(b.at_ear))
	var f := FileAccess.open(out_dir + "/levels.tsv", FileAccess.WRITE)
	f.store_line("name\tgroup\tsrc_peak\tsrc_loud100ms\tsrc_rms\tlen_s\tvolume_db\tbus\tdist_m\tatt_db\tear_loud\tear_peak\tloop\trate")
	for r: Dictionary in rows:
		var line := "%s\t%s\t%.1f\t%.1f\t%.1f\t%.2f\t%.1f\t%s\t%.0f\t%.1f\t%.1f\t%.1f\t%s\t%d" % [r.name, r.grp, r.peak_src, r.loud_src, r.rms_src, r.len, r.vol, r.bus, r.dist, r.att, r.at_ear, r.peak_ear, r.loop, int(r.rate)]
		f.store_line(line)
		print("LEVEL ", line)
	f.close()
	var by := {}
	for r: Dictionary in rows:
		var g: String = r.grp
		if not by.has(g):
			by[g] = [INF, -INF]
		by[g][0] = minf(by[g][0], float(r.at_ear))
		by[g][1] = maxf(by[g][1], float(r.at_ear))
	for g: String in by:
		print("LEVELS group %-10s at ear %.1f .. %.1f dBFS" % [g, by[g][0], by[g][1]])
	print("LEVELS DONE %d in %d ms -> %s" % [rows.size(), Time.get_ticks_msec() - t0, out_dir])
	get_tree().quit(0)
