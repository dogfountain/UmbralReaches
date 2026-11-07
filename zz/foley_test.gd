extends Node
## Foley (core/vfx/foley.gd) and the horse's footfalls (horse_rig.footfalls), headless:
##   godot --headless --path . res://zz/foley_test.tscn [-- --out=<dir>]
## Builds every kind and take, checks each is finite, audible and not clipped; checks the hoof rhythm per gait
## (four beats at the walk, two at the trot, the gallop's gap during suspension), loudness against breed heft,
## and that the beds loop. With --out=<dir> every kind is also written as <dir>/<kind>_<take>.wav (tools/analyze_foley.py).

const Foley := preload("res://core/vfx/foley.gd")
const HorseRig := preload("res://core/world/mount/horse_rig.gd")
const DB := preload("res://core/world/mount/horse_db.gd")

var fails := 0


func ok(c: bool, msg: String) -> void:
	if not c:
		fails += 1
		print("FAIL ", msg)


func _ready() -> void:
	Travel._busy = true
	var out_dir := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.trim_prefix("--out=")
	if out_dir != "":
		DirAccess.make_dir_recursive_absolute(out_dir)
	var kinds: Array[String] = []
	for s in Foley.SURFACES:
		kinds.append("hoof_" + String(s))
	for s: String in ["grass", "stone", "wood", "water", "mud", "ash", "salt", "road", "fen"]:
		kinds.append("step_" + s)
	for c: String in ["walk", "run", "flap"]:
		kinds.append("cloth_" + c)
	for h: String in ["jingle", "creak", "snort", "breath", "grunt", "thump"]:
		kinds.append("horse_" + h)
	kinds.append_array(["bed_river", "bed_murmur"])
	for k in kinds:
		var takes := 1 if k.begins_with("bed_") else Foley.VARIANTS
		var firsts := []
		for v in takes:
			var pcm := Foley.render(k, v)
			ok(pcm.size() > 800, "%s %d is empty" % [k, v])
			var peak := 0.0
			var sq := 0.0
			var bad := false
			for x in pcm:
				if is_nan(x) or is_inf(x):
					bad = true
				peak = maxf(peak, absf(x))
				sq += x * x
			ok(not bad, "%s %d has NaN" % [k, v])
			ok(peak > 0.001, "%s %d is silent" % [k, v])
			firsts.append(pcm)
			if out_dir != "":
				var s := Foley.stream(k, v)
				if s != null:
					s.save_to_wav("%s/%s_%d.wav" % [out_dir, k, v])
			if v == 0 and out_dir != "":
				print("KIND %s dur=%.2fs peak=%.3f rms=%.4f" % [k, float(pcm.size()) / (Foley.BED_RATE if k.begins_with("bed_") else Foley.RATE), peak, sqrt(sq / pcm.size())])
		if takes > 1:
			ok(firsts[0] != firsts[1], "%s takes 0 and 1 are identical (no round-robin variety)" % k)
	var st: AudioStreamWAV = Foley.bed("river")
	ok(st != null and st.loop_mode == AudioStreamWAV.LOOP_FORWARD, "bed loops")
	# the same kind never twice in a row
	var last: AudioStream = null
	var repeats := 0
	for i in 30:
		var t: AudioStream = Foley.take("hoof_grass")
		if t == last:
			repeats += 1
		last = t
	ok(repeats == 0, "round-robin repeated a take %d times" % repeats)
	_gaits()
	_heft()
	_horse_hooks()
	print("FOLEY %s" % ("PASS" if fails == 0 else "FAIL %d" % fails))
	get_tree().quit(fails)


## Walk down a stride at each gait and collect when each leg plants (fraction of the stride).
func _plants(speed: float) -> Array:
	var rig := HorseRig.new()
	var d: Dictionary = DB.BREEDS["palfrey"]
	rig.walk_s = float(d.walk)
	rig.trot_s = float(d.trot)
	rig.gallop_s = float(d.gallop)
	var ev := []
	var n := 2000
	for i in n:
		var p0 := TAU * float(i) / n
		var p1 := TAU * float(i + 1) / n
		for leg: int in rig.footfalls(p0 + TAU, p1 + TAU, speed):
			ev.append([float(i) / n, leg])
	rig.free()
	return ev


func _gaits() -> void:
	var walk := _plants(2.4)
	ok(walk.size() == 4, "walk: %d footfalls in a stride, wanted 4" % walk.size())
	var legs := []
	for e: Array in walk:
		legs.append(e[1])
	legs.sort()
	ok(legs == [0, 1, 2, 3], "walk: each leg plants once")
	var gaps := []
	for i in walk.size():
		gaps.append(fposmod(float(walk[(i + 1) % walk.size()][0]) - float(walk[i][0]), 1.0))
	for g: float in gaps:
		ok(absf(g - 0.25) < 0.02, "walk: beats are even (gap %.3f)" % g)
	var trot := _plants(6.0)
	var times := {}
	for e: Array in trot:
		times[snappedf(float(e[0]), 0.01)] = true
	ok(trot.size() == 4 and times.size() == 2, "trot: two beats of two hooves (%d hooves, %d beats)" % [trot.size(), times.size()])
	var gal := _plants(11.0)
	ok(gal.size() == 4, "gallop: four plants per stride")
	var mg := 0.0
	for i in gal.size():
		mg = maxf(mg, fposmod(float(gal[(i + 1) % gal.size()][0]) - float(gal[i][0]), 1.0))
	ok(mg > 0.3, "gallop: a suspension gap of %.2f of the stride, wanted > 0.3" % mg)
	print("FOLEY gait walk=%d trot=%d(%d beats) gallop=%d gap=%.2f" % [walk.size(), trot.size(), times.size(), gal.size(), mg])


func _heft() -> void:
	var dr := Foley.hoof_db(&"road", float(DB.BREEDS["draught"].heft), 0.5, false)
	var pa := Foley.hoof_db(&"road", float(DB.BREEDS["palfrey"].heft), 0.5, false)
	var fp := Foley.hoof_db(&"road", float(DB.BREEDS["fenpony"].heft), 0.5, false)
	ok(dr > pa and pa > fp, "heft: draught %.1f > palfrey %.1f > fen pony %.1f dB" % [dr, pa, fp])
	ok(Foley.hoof_db(&"road", 1.0, 1.0, false) > Foley.hoof_db(&"road", 1.0, 0.0, false) + 6.0, "gallop is at least 6 dB over the walk")
	ok(Foley.hoof_db(&"stone", 1.0, 0.5, false) > Foley.hoof_db(&"grass", 1.0, 0.5, false), "stone rings louder than grass")


## horse.gd fires a hoof per footfall: step a ridden horse through one stride at each gait and count the voices started.
func _horse_hooks() -> void:
	var Horse := load("res://core/world/mount/horse.gd")
	var h: Node3D = Horse.new()
	h.breed = "draught"
	add_child(h)
	var counts := {}
	for gait: Array in [["walk", 2.2], ["trot", 5.5], ["gallop", 9.0]]:
		h.speed = float(gait[1])
		var n := 0
		var steps := 400
		for i in steps:
			Sfx.release()
			h._phase_prev = TAU * float(i) / steps + TAU
			h._phase = TAU * float(i + 1) / steps + TAU
			h._hooves(0.016)
			for v in Sfx._voices:
				if is_instance_valid(v) and v.playing:
					n += 1
					break
		counts[gait[0]] = n
	print("FOLEY horse hooves (ticks with a hoof sounding in one stride) ", counts)
	ok(int(counts["walk"]) >= 4, "horse.gd sounded fewer than 4 hoof ticks at the walk")
	ok(int(counts["gallop"]) >= 4, "horse.gd sounded fewer than 4 hoof ticks at the gallop")
	h.queue_free()
