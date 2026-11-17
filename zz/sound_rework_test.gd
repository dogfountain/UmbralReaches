extends Node
## The sound rework, rendered headless and checked (no world): every cue of core/audio/cue_bank.gd renders to its length with body
## and no NaN or clipping; every score stem (core/audio/score_stems.gd) renders, loops seamlessly (the loops' ends meet) and has
## body; the occlusion helper is quiet with no camera; the acoustic-zone registry answers; Settings knows the three new sliders; the
## stinger duck math keeps the smallest request. Prints render times.
##   HOME=<scratch> godot --headless --path . res://zz/sound_rework_test.tscn [-- --dump=<dir>]

const CueBank := preload("res://core/audio/cue_bank.gd")
const Stems := preload("res://core/audio/score_stems.gd")
const Kit := preload("res://core/audio/synth_kit.gd")
const Occlusion := preload("res://core/audio/occlusion.gd")
const AcousticZones := preload("res://core/audio/acoustic_zones.gd")
const MixDirector := preload("res://core/audio/mix_director.gd")
const BarkDB := preload("res://core/life/village/village_bark_db.gd")
const Chains := preload("res://core/story/quest_chains.gd")
const DialogueDB := preload("res://core/story/dialogue_db.gd")
const Village := preload("res://core/life/village/village.gd")

var bad := 0


func _ready() -> void:
	var dump := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dump="):
			dump = a.trim_prefix("--dump=")
	var total := 0.0
	for id: String in CueBank.ids():
		var t0 := Time.get_ticks_usec()
		var pcm := CueBank.render(id, CueBank.takes_of(id) - 1)
		var ms := float(Time.get_ticks_usec() - t0) / 1000.0
		total += ms
		var st := _stats(pcm)
		var want := float(CueBank.recipe(id).len)
		_ok(absf(float(pcm.size()) / float(Kit.RATE) - want) < 0.01, "%s lasts %.2f s" % [id, want])
		_ok(not st.nan and st.peak > 0.5 and st.peak <= 1.0 and st.rms > 0.003, "%s has body, no NaN, no clipping (peak %.2f rms %.3f, %.0f ms)" % [id, st.peak, st.rms, ms])
		_ok(absf(pcm[pcm.size() - 1]) < 0.02, "%s ends quiet" % id)
		if dump != "":
			Kit.wav(Kit.encode(pcm)).save_to_wav("%s/cue_%s.wav" % [dump, id])
	print("SOUNDRW %d cues rendered in %.1f s" % [CueBank.ids().size(), total / 1000.0])
	for id2: String in Stems.LOOPS + Stems.MOTIFS:
		var t1 := Time.get_ticks_usec()
		var pcm2 := Stems.build(id2)
		var st2 := _stats(pcm2)
		print("SOUNDRW stem %s: %.1f s in %.0f ms, peak %.2f rms %.3f seam %.3f" % [id2, float(pcm2.size()) / float(Kit.RATE), float(Time.get_ticks_usec() - t1) / 1000.0, st2.peak, st2.rms, st2.seam])
		_ok(not st2.nan and st2.peak > 0.5 and st2.rms > 0.01, "%s has body and no NaN" % id2)
		if Stems.LOOPS.has(id2):
			_ok(absf(float(pcm2.size()) / float(Kit.RATE) - float(Stems.LEN.get(id2, 0.0) if Stems.LEN.has(id2) else 19.2)) < 0.01, "%s lasts its bars" % id2)
			_ok(st2.seam < 0.35 * st2.peak, "%s loops without a click (seam %.3f of peak %.2f)" % [id2, st2.seam, st2.peak])
		if dump != "":
			Kit.wav(Kit.encode(pcm2)).save_to_wav("%s/stem_%s.wav" % [dump, id2])
	_ok(Occlusion.db(null, Vector3.ZERO) == 0.0, "no camera, no occlusion")
	AcousticZones.clear()
	AcousticZones.register(AABB(Vector3(0, 0, 0), Vector3(10, 5, 10)), "hall")
	_ok(AcousticZones.at(Vector3(5, 2, 5)) == "hall" and AcousticZones.at(Vector3(50, 2, 5)) == "", "a registered hall answers, open ground does not")
	AcousticZones.clear()
	var md := MixDirector.new()
	md._request("Music", -6.0, 5.0, 2.0)
	md._request("Music", -12.0, 5.0, 2.0)
	md._request("Music", -3.0, 5.0, 2.0)
	for i in 120:
		md._process(0.05)
	_ok(is_equal_approx(float(md._cur["Music"]), -12.0), "two stingers never stack: the smallest request wins (%.1f)" % float(md._cur["Music"]))
	md.free()
	_ok(Settings.voices_volume > 0.0 and Settings.ui_volume > 0.0 and Settings.score_intensity > 0.0, "the Voices, Interface and Score sliders exist")
	_bark_ids()
	print("SOUNDRW %s (%d failed)" % ["PASS" if bad == 0 else "FAIL", bad])
	get_tree().quit(0 if bad == 0 else 1)


func _stats(pcm: PackedFloat32Array) -> Dictionary:
	var peak := 0.0
	var sq := 0.0
	var nan := false
	for v in pcm:
		if is_nan(v):
			nan = true
		peak = maxf(peak, absf(v))
		sq += v * v
	var seam := absf(pcm[pcm.size() - 1] - pcm[0]) if pcm.size() > 1 else 0.0
	return {"peak": peak, "rms": sqrt(sq / maxf(1.0, float(pcm.size()))), "nan": nan, "seam": seam}


func _ok(cond: bool, what: String) -> void:
	print(("SOUNDRW ok   " if cond else "SOUNDRW FAIL ") + what)
	if not cond:
		bad += 1


## Every bark and scene condition names a task, a pick, a boss and a speaker that exist (a bark that names an id that is not there never plays).
func _bark_ids() -> void:
	var picks := {}                                  # "task:pick" -> true, from the tasks' own data and every conversation's `do`
	for qid: String in Chains.QUESTS:
		var q: Dictionary = Chains.QUESTS[qid]
		for key: String in ["outcome", "leaves", "alt"]:
			for pk: Variant in (q.get(key, {}) as Dictionary):
				picks["%s:%s" % [qid, String(pk).split("+")[0]]] = true
	var re := RegEx.create_from_string("qp:([a-z_0-9]+):([a-z_0-9]+)")
	for cid: String in DialogueDB.CONV:
		for n: Dictionary in (DialogueDB.CONV[cid].nodes as Dictionary).values():
			for m in re.search_all(str(n)):
				picks["%s:%s" % [m.get_string(1), m.get_string(2)]] = true
	var bosses := ["thornwarden", "bone_abbot", "ascended_warden", "r37_hierarch", "r37_anchoress"]
	var conds: Array[String] = []
	for b: Dictionary in BarkDB.BARKS:
		conds.append(String(b.get("if", "")))
	for sc: Dictionary in BarkDB.SCENES:
		conds.append(String(sc.get("if", "")))
	var unknown: Array[String] = []
	for c: String in conds:
		for term: String in c.replace("|", ",").split(","):
			var t := term.strip_edges().trim_prefix("!")
			var f := t.split(":")
			if f.size() >= 3 and f[0] == "qp" and not picks.has("%s:%s" % [f[1], f[2]]):
				unknown.append(t)
			elif f.size() >= 2 and f[0] in ["qd", "q", "qat"] and not Chains.QUESTS.has(f[1]):
				unknown.append(t)
			elif f.size() >= 2 and f[0] == "boss" and not f[1] in bosses:
				unknown.append(t)
	_ok(unknown.is_empty(), "every bark condition names a real task, pick and boss (unknown: %s)" % str(unknown))
	var speakers: Array[String] = []
	for b2: Dictionary in BarkDB.BARKS:
		if String(b2.who) != "*" and not Village.cast_all().has(String(b2.who)) and not ["hesk", "harrow", "brannoc", "keep"].has(String(b2.who)):
			speakers.append(String(b2.who))
	_ok(speakers.is_empty(), "every bark's speaker is a villager of the cast (unknown: %s)" % str(speakers))
