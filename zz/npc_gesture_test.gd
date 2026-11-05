extends Node
## r35: NPC speech is one human gesture a line, not babble (core/npc/npc_voice.gd gesture_for /
## gestures_of). Headless:
##   - every family renders every gesture: the right length, body, no NaN, deterministic
##   - the mood picker on real lines: a question hums up, "..." sighs, "!" grunts, a first line greets,
##     a laugh-line is a "heh"
##   - a deep family's grunt sits lower than a child's (the family's throat is kept)
##   HOME=<scratch> godot --headless --path . res://zz/npc_gesture_test.tscn [-- --dump=<dir>]

const Voice := preload("res://core/npc/npc_voice.gd")

var bad := 0
const LENGTHS := {"breath": [0.4, 0.65], "hm": [0.25, 0.45], "hm_q": [0.25, 0.45], "sigh": [0.65, 1.0],
	"grunt": [0.15, 0.3], "heh": [0.22, 0.35], "hah": [0.22, 0.4]}


func _ready() -> void:
	var dump := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dump="):
			dump = a.trim_prefix("--dump=")
	var t0 := Time.get_ticks_usec()
	for fam: String in Voice.FAMILIES.keys():
		for kind: String in Voice.GESTURES:
			var bank := Voice.gestures_of(fam, kind)
			_ok(bank.size() == Voice.GEST_VARIANTS, "%s %s: %d variants" % [fam, kind, bank.size()], fam == "dwarf")
			for s: AudioStreamWAV in bank:
				var secs := s.data.size() / 2.0 / float(Voice.RATE)
				var r: Array = LENGTHS[kind]
				_ok(secs >= float(r[0]) and secs <= float(r[1]), "%s %s lasts %.2f s (%.2f-%.2f)" % [fam, kind, secs, r[0], r[1]], false)
				var peak := 0
				for i in range(0, s.data.size(), 2):
					peak = maxi(peak, absi(s.data.decode_s16(i)))
				_ok(peak > 8000, "%s %s has body (peak %d)" % [fam, kind, peak], false)
			if dump != "" and (fam == "dwarf" or fam == "keep" or fam == "old_woman" or fam == "child"):
				(bank[0] as AudioStreamWAV).save_to_wav("%s/%s_%s.wav" % [dump, fam, kind])
	print("GESTURE rendered %d families x %d gestures in %.0f ms" % [Voice.FAMILIES.size(), Voice.GESTURES.size(), (Time.get_ticks_usec() - t0) / 1000.0])
	# deterministic: the same seed, the same sound
	var a := Voice._to_bytes(Voice._gesture_pcm(Voice.FAMILIES["keep"], "hah", _rng(3)))
	var b := Voice._to_bytes(Voice._gesture_pcm(Voice.FAMILIES["keep"], "hah", _rng(3)))
	_ok(a == b, "a gesture is deterministic for its seed")
	# the mood picker, on the game's own lines
	_ok(Voice.gesture_for("Shut the door. No, leave it. The fire's done arguing with the dark tonight.", true) == "hah", "a first line greets (hah)")
	_ok(Voice.gesture_for("Well? Who's drinking my ale?") == "hm_q", "a question hums upward")
	_ok(Voice.gesture_for("Nan. ...For Pell. Well. I'm not taking a mug off a child for that...") == "sigh", "a trailing ... sighs")
	_ok(Voice.gesture_for("Find the three ward-stones!") == "grunt", "an exclamation grunts")
	_ok(Voice.gesture_for("Ha! The kindled one.") == "heh", "a laugh-line is a heh")
	var long_line := "Somebody opened the sky at the top of the Stair. It opened inward. It's been drinking ever since."
	_ok(Voice.gesture_for(long_line) in ["breath", "hm"], "a long plain line breathes or hums (%s)" % Voice.gesture_for(long_line))
	# the family's throat is kept: a dwarf's grunt is lower than a child's
	_ok(_centroid(Voice.gestures_of("dwarf", "grunt")[0]) < _centroid(Voice.gestures_of("child", "grunt")[0]), "a dwarf's grunt sits lower than a child's")
	print("GESTURE %s (%d failed)" % ["PASS" if bad == 0 else "FAIL", bad])
	get_tree().quit(0 if bad == 0 else 1)


func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


## Zero-crossing rate (Hz): a rough brightness / pitch measure.
func _centroid(s: AudioStreamWAV) -> float:
	var z := 0
	var prev := 0
	for i in range(0, s.data.size(), 2):
		var v := s.data.decode_s16(i)
		if (v >= 0) != (prev >= 0):
			z += 1
		prev = v
	return float(z) / (s.data.size() / 2.0 / float(Voice.RATE)) * 0.5


func _ok(cond: bool, what: String, loud := true) -> void:
	if not cond or loud:
		print(("GESTURE ok   " if cond else "GESTURE FAIL ") + what)
	if not cond:
		bad += 1
