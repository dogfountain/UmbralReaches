extends Node
## Creature audio, headless:  godot --headless --path . res://zz/enemy_audio_test.tscn
## Every take in the bank loads as 44.1 kHz mono with headroom; every enemy kind's voice set exists; picking
## never repeats a take; cooldowns, the voice cap and priorities (a wind-up beats a far cry, a boss beats a pack)
## hold; hit materials, the shared kit and the wanderer's combat all play.
## Ends ENEMYAUDIO PASS / ENEMYAUDIO FAIL n.

const Bank := preload("res://core/vfx/enemy_bank.gd")
const KINDS := ["wretch", "gaunt", "pilgrim", "husk", "bulwark", "crawler", "mite", "burrower", "leaper", "spitter", "cinder_caster",
	"chanter", "tollman", "quiller", "ossuant", "thornwarden", "bone_abbot", "ascended_warden", "brood_mother", "tally_reliquary", "anchoress", "hierarch_voice"]
var fails := 0


func check(ok: bool, msg: String) -> void:
	if ok:
		print("ENEMYAUDIO ok  ", msg)
	else:
		fails += 1
		print("ENEMYAUDIO FAIL ", msg)


## Peak of the source .wav (the importer stores them compressed, so read the file: 16-bit after a 44-byte header).
func _peak(path: String) -> float:
	var d := FileAccess.get_file_as_bytes(path)
	var pk := 0
	for i in range(44, d.size() - 1, 2):
		pk = maxi(pk, absi(d.decode_s16(i)))
	return float(pk) / 32768.0


func _ready() -> void:
	# ---- the bank on disk
	var bad := 0
	var worst := 0.0
	var files := 0
	var paths: Array[String] = []
	for set_name: String in Bank.SETS:
		for act: String in Bank.SETS[set_name]:
			for i in int(Bank.SETS[set_name][act]):
				paths.append("res://art/audio/enemy/%s/%s_%d.wav" % [set_name, act, i])
	for body: String in Bank.STEPS:
		for surf: String in Bank.STEPS[body]:
			for i in int(Bank.STEPS[body][surf]):
				paths.append("res://art/audio/enemy/step/%s_%s_%d.wav" % [body, surf, i])
	for k: String in Bank.KIT:
		for i in int(Bank.KIT[k]):
			paths.append("res://art/audio/kit/%s_%d.wav" % [k, i])
	for m: String in Bank.HITS:
		for i in int(Bank.HITS[m][0]):
			paths.append("res://art/audio/kit/hit_%s_%d.wav" % [m, i])
		for i in int(Bank.HITS[m][1]):
			paths.append("res://art/audio/kit/hit_%s_heavy_%d.wav" % [m, i])
	for k: String in Bank.PLAYER:
		for i in int(Bank.PLAYER[k]):
			paths.append("res://art/audio/player/%s_%d.wav" % [k, i])
	for p in paths:
		var s := load(p) as AudioStreamWAV
		files += 1
		if s == null or s.mix_rate != 44100 or s.stereo or s.data.size() < 300:
			bad += 1
			print("  bad take ", p)
			continue
		worst = maxf(worst, _peak(p))
	check(bad == 0, "%d takes load as 44.1 kHz mono (%d bad)" % [files, bad])
	check(worst <= 0.9 and worst > 0.3, "peaks leave headroom (loudest %.3f)" % worst)

	# ---- every enemy kind has a voice set with every act it can ask for
	var missing := []
	for k in KINDS:
		var e: Object = (load("res://core/enemy/%s.gd" % k) as GDScript).new()
		var fam: String = e.voice_family()
		(e as Node).free()
		for act in ["idle", "alert", "windup", "attack", "hurt", "stagger", "die"]:
			if int(Bank.SETS.get(fam, {}).get(act, 0)) < 2:
				missing.append("%s/%s" % [fam, act])
	check(missing.is_empty(), "every kind's voice set has 2+ takes of each act %s" % [missing])

	# ---- scene for the 3D voices
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	get_tree().current_scene = self
	await get_tree().process_frame

	# ---- picking never repeats
	var rep := 0
	var prev := -1
	for i in 300:
		var j := EnemyAudio._pick("test/pick", 3)
		if j == prev:
			rep += 1
		prev = j
	check(rep == 0, "a take never plays twice in a row")

	# ---- cooldowns
	var at := Vector3(0, 0, -8)
	check(EnemyAudio.say("hollow", "hurt", at, 1), "a cry plays")
	check(not EnemyAudio.say("hollow", "hurt", at, 1), "the same creature may not repeat it at once")
	check(not EnemyAudio.say("hollow", "hurt", at, 2), "nor may its pack answer in unison")
	check(not EnemyAudio.say("nosuch", "hurt", at, 3), "an unknown set plays nothing")
	check(not EnemyAudio.say("hollow", "idle", Vector3(0, 0, -40), 4), "a murmur 40 m away is not worth a voice")

	# ---- the cap and the priorities
	var sets: Array = Bank.SETS.keys()
	var n := 0
	for a in ["stagger", "hurt", "alert", "flee"]:
		for s: String in sets:
			if n >= 40:
				break
			EnemyAudio.say(s, a, Vector3(float(n % 7) - 3.0, 0, -12 - float(n % 5)), 100 + n)
			n += 1
	var playing := 0
	for v in get_children():
		if v is AudioStreamPlayer3D and (v as AudioStreamPlayer3D).playing and String(v.name).begins_with("EnemyVoice"):
			playing += 1
	check(playing <= EnemyAudio.POOL and playing >= 8, "a crowd of %d is held to the pool (%d playing, cap %d)" % [n, playing, EnemyAudio.POOL])
	check(EnemyAudio.say("husk", "windup", Vector3(0, 0, -6), 900), "a wind-up takes a voice from the crowd")
	check(not EnemyAudio.say("hollow", "flee", Vector3(0, 0, -33), 901), "a far low-priority cry is dropped when the pool is full")
	check(EnemyAudio.say("hierarch", "phase", Vector3(0, 0, -30), 902, 0.0, 1.0, true), "a boss's roar always gets through")

	# ---- material layers, the kit, the wanderer
	for m: String in Bank.HITS:
		check(EnemyAudio.hit(m, Vector3(0, 0, -5), 1.0) and EnemyAudio.hit(m, Vector3(0, 0, -5), 4.0), "hit material %s (light and heavy)" % m)
	var kit_ok := true
	for k: String in Bank.KIT:
		kit_ok = kit_ok and EnemyAudio.kit(k) != null
	check(kit_ok, "every shared kit sound loads")
	check(Synth_roar_is_banked(), "Synth.get_stream serves the rendered kit")
	for k: String in Bank.PLAYER:
		check(EnemyAudio.player(k, Vector3(0, 1, -2)), "the wanderer's %s" % k)
	EnemyAudio.step("heavy", &"stone", Vector3(0, 0, -6))
	EnemyAudio.step("skittering", &"water", Vector3(0, 0, -6))
	EnemyAudio.step("bony", &"fen", Vector3(0, 0, -6))
	check(EnemyAudio._steps.size() == EnemyAudio.STEP_POOL, "footfalls have their own small pool")
	Sfx.release()
	check(EnemyAudio._voices.is_empty() and EnemyAudio._streams.is_empty(), "Sfx.release() lets the creature voices go")
	print("ENEMYAUDIO PASS" if fails == 0 else "ENEMYAUDIO FAIL %d" % fails)
	get_tree().quit(0 if fails == 0 else 1)


func Synth_roar_is_banked() -> bool:
	var s: AudioStream = (load("res://core/vfx/synth.gd") as GDScript).get_stream("roar")
	return s != null and s.resource_path.begins_with("res://art/audio/kit/")
