extends SceneTree
## Staff sound synth check: builds every kind (timed, uncached), checks level and length, writes
## shots/staff_<kind>_<variant>.wav to listen to.   godot --headless --path . -s zz/staff_sfx_test.gd
const S := preload("res://core/vfx/staff_sfx.gd")
func _init() -> void:
	var bad := 0
	var total := 0.0
	for k: String in S.KINDS:
		S._bank.erase(k)
		var t0 := Time.get_ticks_usec()
		var raw: Array = []
		var n := 1 if k == "lance_charge" else S.VARIANTS
		for v in n:
			var rng := RandomNumberGenerator.new()
			rng.seed = hash(k) * 31 + v * 977 + 5
			raw.append(S._make(k, rng))
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		total += ms
		var line := ""
		for v in raw.size():
			var pcm: PackedFloat32Array = raw[v]
			var peak := 0.0
			var bad_v := false
			for x in pcm:
				if is_nan(x) or is_inf(x):
					bad_v = true
				peak = maxf(peak, absf(x))
			if bad_v or peak < 1e-4:
				bad += 1
			var w := AudioStreamWAV.new()
			w.format = AudioStreamWAV.FORMAT_16_BITS
			w.mix_rate = S.RATE
			w.data = S._bytes(pcm)
			w.save_to_wav(ProjectSettings.globalize_path("res://shots/staff_%s_%d.wav" % [k, v]))
			line += " %.2fs%s" % [pcm.size() / float(S.RATE), "!" if bad_v or peak < 1e-4 else ""]
		print("STAFF %-12s %6.1f ms %s" % [k, ms, line])
	print("STAFF DONE bad=%d total %.0f ms" % [bad, total])
	quit()
