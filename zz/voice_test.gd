extends SceneTree
## NPC voice synth check: builds every family's bank (timed), checks the PCM, estimates the pitch,
## and writes shots/voice_<family>.wav (a babbled phrase) to listen to.
##   godot --headless --path . -s zz/voice_test.gd
const Voice := preload("res://core/npc/npc_voice.gd")
func _init() -> void:
	var bad := 0
	var expect := {"dwarf": [70, 140], "keep": [80, 150], "man": [90, 170], "old_man": [95, 180], "woman": [150, 280], "old_woman": [140, 270], "teen": [170, 300], "child": [200, 360]}
	for fam: String in Voice.FAMILIES:
		var t0 := Time.get_ticks_usec()
		Voice._banks.erase(fam)
		var bank: Array = Voice.bank_of(fam)
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		var f0s: Array[float] = []
		var phrase := PackedByteArray()
		for k in 10:
			var s: AudioStreamWAV = bank[k % bank.size()]
			var d := s.data
			var n := d.size() / 2
			var peak := 0
			for i in n:
				peak = maxi(peak, absi(d.decode_s16(i * 2)))
			if peak < 1000:
				bad += 1
				print("VOICE bad: silent syllable ", fam, " ", k)
			# autocorrelation pitch on the middle 40 ms
			var a := n / 2 - 440
			var best := 0.0
			var lag_best := 0
			for lag in range(50, 330):
				var acc := 0.0
				for i in range(a, a + 880, 2):
					acc += float(d.decode_s16(i * 2)) * float(d.decode_s16((i + lag) * 2))
				if acc > best:
					best = acc
					lag_best = lag
			if lag_best > 0:
				f0s.append(22050.0 / lag_best)
			phrase.append_array(d)
			var gap := PackedByteArray()
			gap.resize(int(22050 * randf_range(0.01, 0.05)) * 2)
			phrase.append_array(gap)
		f0s.sort()
		var med: float = f0s[f0s.size() / 2] if f0s.size() > 0 else 0.0
		var ok: bool = med >= expect[fam][0] and med <= expect[fam][1]
		if not ok:
			bad += 1
		print("VOICE %-9s bank %d in %6.1f ms  pitch ~%3.0f Hz %s" % [fam, bank.size(), ms, med, "ok" if ok else "OUT OF RANGE"])
		var w := AudioStreamWAV.new()
		w.format = AudioStreamWAV.FORMAT_16_BITS
		w.mix_rate = 22050
		w.data = phrase
		w.save_to_wav(ProjectSettings.globalize_path("res://shots/voice_%s.wav" % fam))
	print("VOICE DONE bad=%d" % bad)
	quit()
