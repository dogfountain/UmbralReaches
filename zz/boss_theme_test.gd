extends Node
## r35: the boss themes and the great bell (core/life/wildlife/boss_themes.gd), rendered headless.
## Each stem: renders, lasts a whole number of its bars, has body (RMS) and no clipping or NaN, and its
## loop seam is quiet (the last and first samples meet). The two stems of a theme are the same length
## (they play in lockstep). The bell rings long and starts from its strike. Prints render times.
##   HOME=<scratch> godot --headless --path . res://zz/boss_theme_test.tscn [-- --dump=<dir>]
## --dump writes every stem as a WAV to listen to.

const Themes := preload("res://core/life/wildlife/boss_themes.gd")

var bad := 0


func _ready() -> void:
	var dump := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dump="):
			dump = a.trim_prefix("--dump=")
	var lengths := {"thornwarden": 60.0 / 88.0 * 2.0 * 16.0, "bone_abbot": 60.0 / 56.0 * 4.0 * 8.0, "ascended_warden": 60.0 / 72.0 * 3.0 * 12.0}
	for id: String in Themes.IDS:
		var sizes: Array = []
		for layer: String in ["base", "high"]:
			var t0 := Time.get_ticks_usec()
			var pcm := Themes.build(id, layer)
			var ms := float(Time.get_ticks_usec() - t0) / 1000.0
			var secs := pcm.size() / float(Themes.RATE)
			var st := _stats(pcm)
			print("THEMES %s %s: %.1f s rendered in %.0f ms, peak %.2f, rms %.3f, seam %.3f" % [id, layer, secs, ms, st.peak, st.rms, st.seam])
			_ok(absf(secs - float(lengths[id])) < 0.05, "%s %s lasts its bars (%.2f s, want %.2f)" % [id, layer, secs, float(lengths[id])])
			_ok(not st.nan and st.peak > 0.05 and st.rms > 0.01, "%s %s has body and no NaN" % [id, layer])
			_ok(st.seam < 0.25 * st.peak, "%s %s loops without a click (seam %.3f of peak %.2f)" % [id, layer, st.seam, st.peak])
			sizes.append(pcm.size())
			if dump != "":
				var s := Themes.stream(id, layer)
				s.save_to_wav("%s/%s_%s.wav" % [dump, id, layer])
		_ok(sizes[0] == sizes[1], "%s: the two stems are the same length (they play in step)" % id)
	var t1 := Time.get_ticks_usec()
	var bell := Themes._great_bell(110.0, 24.0)
	var st := _stats(bell)
	print("THEMES great bell: %.1f s in %.0f ms, peak %.2f" % [bell.size() / float(Themes.RATE), float(Time.get_ticks_usec() - t1) / 1000.0, st.peak])
	var tail := 0.0
	for i in range(bell.size() - Themes.RATE, bell.size()):
		tail = maxf(tail, absf(bell[i]))
	_ok(tail > 0.01 * st.peak, "the great bell still sounds at 23 s (its hum decays over ~20 s)")
	var head := 0.0
	for i in int(0.05 * Themes.RATE):
		head = maxf(head, absf(bell[i]))
	_ok(head > 0.2 * st.peak, "it starts from its strike")
	if dump != "":
		Themes.great_bell().save_to_wav("%s/great_bell.wav" % dump)
	print("THEMES %s (%d failed)" % ["PASS" if bad == 0 else "FAIL", bad])
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
	print(("THEMES ok   " if cond else "THEMES FAIL ") + what)
	if not cond:
		bad += 1
