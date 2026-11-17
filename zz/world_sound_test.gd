extends Node
## Regional soundscape (r28) headless test:
##   godot --headless --path . res://zz/world_sound_test.tscn [-- --write-samples]
## Checks: the buses (AmbOut with its low-pass, a reverb on SFX and Ambience, idle outdoors); the
## soundscape at each region (village, heath, wood, fen, the Crossing, the summit, the tavern, the
## Ossuary) and the rooms (tavern, Ossuary, down in the rift); walking from the meadow into the
## Thornwood crossfades without jumps; the tavern's reverb and muffle ease in and out; spot calls land
## in 3D at the palette's distances; the music answers danger (dark pad, heartbeat), relief and rest
## (warm pad by a lit brazier) and plays notes; synthesis is deterministic and the cache matches a
## fresh build. --write-samples also writes shots/agentF_*.wav.
## Ends WORLD SOUND PASS / WORLD SOUND FAIL n.
const RL := preload("res://core/world/realm/realm_land.gd")
const ScapeSynth := preload("res://core/life/wildlife/scape_synth.gd")
const AmbienceScript := preload("res://core/world/ambience.gd")

var t := 0.0
var fails := 0
var main: Node
var started := false
var amb: Node
var player: CharacterBody3D


func _ready() -> void:
	Travel._busy = true                       # never write the player's real save from a test
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func fail(msg: String) -> void:
	fails += 1
	print("WORLD FAIL ", msg)


func check(ok: bool, msg: String) -> void:
	if not ok:
		fail(msg)
	else:
		print("WORLD ok  ", msg)


func _process(d: float) -> void:
	t += d
	if Time.get_ticks_msec() > 300000:             # WATCHDOG (real time): never outlive a stuck step
		print("WORLD TIMEOUT after %.0f s" % (Time.get_ticks_msec() / 1000.0))
		Engine.time_scale = 1.0
		get_tree().quit(1)
		return
	if started:
		for e in get_tree().get_nodes_in_group(Groups.ENEMY):
			if not (e as Node).has_meta("world_fake") and not (e as Node).is_queued_for_deletion():
				(e as Node).queue_free()
		return
	if main == null or not main.has_meta("realm_done") or main.get_node_or_null("Wildlife") == null:
		if t > 150.0:
			fail("Realm never finished")
			_end()
		return
	started = true
	_run()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _secs(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func _put(p: Vector3) -> void:
	var y := RealmLayout.ground(player.get_world_3d().direct_space_state, p.x, p.z)
	player.global_position = Vector3(p.x, maxf(y, p.y) + 0.2, p.z)
	player.velocity = Vector3.ZERO
	await _frames(3)


func _verb(bus: String) -> AudioEffectReverb:
	var bi := AudioServer.get_bus_index(bus)
	for i in AudioServer.get_bus_effect_count(bi):
		if AudioServer.get_bus_effect(bi, i) is AudioEffectReverb:
			return AudioServer.get_bus_effect(bi, i)
	return null


func _verb_on(bus: String) -> bool:
	var bi := AudioServer.get_bus_index(bus)
	for i in AudioServer.get_bus_effect_count(bi):
		if AudioServer.get_bus_effect(bi, i) is AudioEffectReverb:
			return AudioServer.is_bus_effect_enabled(bi, i)
	return false


func _run() -> void:
	await _frames(5)
	amb = main.get_node("Ambience")
	player = get_tree().get_first_node_in_group(Groups.PLAYER) as CharacterBody3D
	main.get_node("Wildlife").phenomena.quiet = true
	amb.quiet = true
	# ---- buses
	var oi := AudioServer.get_bus_index("AmbOut")
	check(oi >= 0 and AudioServer.get_bus_send(oi) == &"Ambience", "AmbOut bus sends to Ambience")
	check(_verb("SFX") != null and _verb("Ambience") != null, "reverbs on SFX and Ambience")
	await _put(Vector3(-30, 0, 66))
	await _secs(2.0)
	check(_verb("SFX").wet < 0.08 and amb.muffle < 0.01, "outdoors: only a thin open-air tail, no muffle")

	# ---- the soundscape per region (static mix) and the rooms
	var where := {"village": Vector3(6, 0.5, 40), "heath": Vector3(-60, 0.5, 70), "wood": Vector3(-85, 4, -40), "fen": Vector3(75, -1, -30),
		"crossing": Vector3(0, -6, -50) + Endgame.O, "summit": Vector3(0, 26, -95) + Endgame.O, "tavern": Vector3(18, 0.6, 30.2),
		# the Far Reaches' own (docs/living_realm.md)
		"lanternwood": Vector3(-330, 2, 0), "reedmere": Vector3(-330, 0, 340), "fields": Vector3(-170, 0.5, 340),
		"bellfall": Vector3(340, 0, 104), "cairns": Vector3(330, 6, 330), "southwood": Vector3(180, 2, 340)}
	for sc: String in where:
		var p: Vector3 = where[sc]
		var mix: Dictionary = AmbienceScript.mix_at(p)
		var best := ""
		var bw := 0.0
		for k: String in mix:
			if float(mix[k]) > bw:
				bw = float(mix[k])
				best = k
		check(best == sc, "%s at %s (%s)" % [sc, p, str(mix)])
	check(AmbienceScript.zone_at(Vector3(18, 0.6, 30.2), "", "tavern") == "tavern", "the tavern is a room")
	check(AmbienceScript.zone_at(Vector3(0, -8, -50) + Endgame.O, "", "crossing") == "rift", "down in the rift is a room")
	check(AmbienceScript.zone_at(Vector3(0, 6, -50), "", "crossing") == "", "up on the Crossing is open air")
	check(AmbienceScript.zone_at(Vector3(20, 2, -60), "ossuary", "ossuary") == "ossuary", "the Ossuary is a room")
	var g_open: Dictionary = AmbienceScript.room_goal("", {"heath": 1.0})
	var g_wood: Dictionary = AmbienceScript.room_goal("", {"wood": 1.0})
	var g_cliff: Dictionary = AmbienceScript.room_goal("", {"crossing": 1.0})
	var g_mix: Dictionary = AmbienceScript.room_goal("", {"heath": 0.5, "wood": 0.5})
	check(float(g_open.wet) < float(g_wood.wet) and float(g_wood.wet) < float(g_cliff.wet), "open land, wood and cliff each have their own reverb")
	check(float(g_mix.wet) > float(g_open.wet) and float(g_mix.wet) < float(g_wood.wet), "and a blend of regions blends them")
	check(float(AmbienceScript.room_goal("ossuary", {"wood": 1.0}).wet) > 0.2, "a room overrides the place")

	# ---- walking from the meadow into the Thornwood: a gradual crossfade
	await _put(Vector3(8, 0, 42))
	await _secs(3.0)
	var g0: Dictionary = (amb.bed_gain as Dictionary).duplicate()
	check(float(g0.get("crickets", 0.0)) > 0.4 and float(g0.get("leaves", 0.0)) < 0.2, "the village bed (crickets %.2f, leaves %.2f)" % [float(g0.get("crickets", 0.0)), float(g0.get("leaves", 0.0))])
	var a := Vector3(-30, 0, 30)
	var b := Vector3(-90, 0, -30)
	var jump := 0.0
	var prev: Dictionary = (amb.bed_gain as Dictionary).duplicate()
	var trace := []
	for i in 61:
		var p := a.lerp(b, float(i) / 60.0)
		await _put(p)
		await _secs(0.12)
		var g: Dictionary = amb.bed_gain
		for k: String in g:
			jump = maxf(jump, absf(float(g[k]) - float(prev.get(k, 0.0))))
		prev = g.duplicate()
		if i % 10 == 0:
			trace.append("%s %.2f/%.2f" % [amb.scape, float(g.get("crickets", 0.0)), float(g.get("leaves", 0.0))])
	print("WORLD crossfade (scape crickets/leaves): ", trace)
	await _secs(3.0)
	var g1: Dictionary = amb.bed_gain
	check((amb.scape == "wood" or amb.scape == "ring") and float(g1.get("leaves", 0.0)) > 0.8, "the wood's bed at the end (leaves %.2f)" % float(g1.get("leaves", 0.0)))
	check(jump < 0.12, "no bed jumps more than 0.12 between steps (%.3f)" % jump)

	# ---- the tavern: reverb and muffle ease in and out
	await _put(Vector3(18.0, 0.6, 30.2))
	await _secs(0.5)
	var wet_early := (_verb("SFX") as AudioEffectReverb).wet
	await _secs(2.5)
	var rv := _verb("SFX")
	print("WORLD tavern: scape %s zone %s wet %.3f muffle %.2f cutoff %.0f" % [amb.scape, amb.reverb_zone, rv.wet, amb.muffle, (amb._lowpass as AudioEffectLowPassFilter).cutoff_hz])
	check(amb.scape == "tavern" and amb.reverb_zone == "tavern", "inside the Kindled Keg")
	check(_verb_on("SFX") and rv.wet > 0.09 and wet_early < rv.wet, "its room comes in (wet %.3f -> %.3f)" % [wet_early, rv.wet])
	check(amb.muffle > 0.95 and (amb._lowpass as AudioEffectLowPassFilter).cutoff_hz < 900.0, "and the night outside is muffled")
	check(float(amb.bed_gain.get("hearth", 0.0)) > 0.8, "the hearth's room tone (%.2f)" % float(amb.bed_gain.get("hearth", 0.0)))
	await _put(Vector3(30, 0, 44))
	await _secs(3.0)
	check(_verb("SFX").wet < 0.08 and amb.muffle < 0.01, "outside again: no room, no muffle")

	# ---- the Ossuary
	var area := main.get_node_or_null("Area_ossuary") as Node3D
	if area == null:
		print("WORLD (Ossuary not streamed in: skipped)")
	else:
		var inside := Vector3.INF
		for nm: String in ["HallFill", "GalleryA", "GalleryB", "PitCandles"]:
			var l := area.get_node_or_null(nm) as Node3D
			if l == null:
				continue
			var hit := player.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(l.global_position, l.global_position - Vector3(0, 14, 0), 1))
			if not hit.is_empty():
				inside = (hit.position as Vector3) + Vector3(0, 0.3, 0)
				break
		print("WORLD ossuary floor at ", inside)
		player.global_position = inside
		player.velocity = Vector3.ZERO
		await _secs(3.0)
		print("WORLD ossuary: at %s scape %s zone %s wet %.3f" % [player.global_position, amb.scape, amb.reverb_zone, _verb("SFX").wet])
		check(amb.scape == "ossuary" and amb.reverb_zone == "ossuary" and _verb("SFX").wet > 0.2, "the crypt's long stone room")
		var sp: AudioStreamPlayer3D = amb.play_spot("drip", 2.5, 4.0, 14.0)
		check(sp != null and float(amb.last_spot.dist) < 18.0, "drips close by in the dark (%.1f m)" % float(amb.last_spot.dist))

	# ---- spot calls in 3D
	await _put(Vector3(-85, 4, -40))
	await _secs(1.0)
	var bad := 0
	for i in 12:
		var spot: AudioStreamPlayer3D = amb.play_spot("twig", 0.2, 12.0, 40.0)
		var d := float(amb.last_spot.dist)
		var p: Vector3 = amb.last_spot.pos
		if spot == null or d < 8.0 or d > 46.0 or absf(p.y - 0.2 - RL.height_at(p.x, p.z)) > 3.0:
			bad += 1
	check(bad == 0, "spot calls in the wood land 12-40 m off on the ground (%d off)" % bad)
	amb.quiet = false
	var n0: int = amb.spots_played
	amb._spot_t = 0.0
	await _secs(0.3)
	check(amb.spots_played > n0, "the wood calls by itself (%s)" % str(amb.last_spot.get("kind", "")))
	amb.quiet = true

	# ---- music: danger, relief, rest
	var mu: Node = amb.music
	await _put(Vector3(-30, 0, 66))
	await _secs(1.0)
	var fake := Node3D.new()
	fake.add_to_group(Groups.ENEMY)
	fake.set_meta("world_fake", true)
	main.add_child(fake)
	fake.global_position = player.global_position + Vector3(8, 0, 0)
	await _secs(4.0)
	check(mu.state == "danger" and mu.intensity > 0.6 and mu._pad_dark.playing, "danger: the dark pad comes in (%.2f)" % mu.intensity)
	var pulse_seen := false
	for i in 20:
		await _secs(0.1)
		if mu._pulse.playing:
			pulse_seen = true
	check(pulse_seen, "a heartbeat under it")
	var r0: int = mu.reliefs
	fake.queue_free()
	await _secs(3.0)
	if mu.state == "danger":
		print("WORLD music still danger: near ", mu.near_names)
	check(mu.state == "explore" and mu.reliefs > r0, "it passes: one resolving phrase (reliefs %d)" % mu.reliefs)
	var lit: Node3D = null
	for n in get_tree().get_nodes_in_group(Groups.INTERACTABLE):
		if n is Brazier and (n as Brazier).lit:
			lit = n
			break
	if lit == null:
		print("WORLD (no lit brazier: rest skipped)")
	else:
		await _put(lit.global_position + Vector3(2.5, 0, 1.5))
		mu._scan_t = 0.0
		await _secs(6.0)
		if mu.state != "rest":
			print("WORLD music at the brazier: %s near %s" % [mu.state, mu.near_names])
		check(mu.state == "rest" and mu._pad_rest.playing, "by a lit brazier: rest, the warm pad (%s)" % mu.state)
	var notes0: int = mu.notes_played
	mu._note_t = 0.0
	await _secs(4.0)
	check(mu.notes_played > notes0, "the lyre plays (%d notes)" % (mu.notes_played - notes0))

	# ---- synthesis: deterministic, cache matches a fresh build
	for k: String in ["drip", "twig", "chime", "pulse", "peewit"]:
		var a1 := ScapeSynth.build(k)
		var a2 := ScapeSynth.build(k)
		check(a1 == a2, "%s synthesises the same twice" % k)
		var fresh := ScapeSynth._wav(a1)
		check(fresh.data == ScapeSynth.stream(k).data, "%s cached = fresh build" % k)
	var missing := []
	for k: String in ScapeSynth.kinds():
		var s := ScapeSynth.stream(k)
		if s == null or s.get_length() < 0.1:
			missing.append(k)
	check(missing.is_empty(), "every soundscape sound builds %s" % str(missing))
	if "--write-samples" in OS.get_cmdline_user_args():
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
		for k: String in ["leaves", "fen", "chasm", "high_wind", "hearth", "rain_leaves", "rain_roof", "rain_water", "pad_rest", "pad_dark",
				"bittern", "nightjar", "vixen", "bellow", "howl", "crack", "surge", "bolide", "chime", "harp", "peewit", "whisper", "bones"]:
			ScapeSynth.stream(k).save_to_wav(ProjectSettings.globalize_path("res://shots/agentF_%s.wav" % k))
		print("WORLD samples written to shots/agentF_*.wav")
	_end()


func _end() -> void:
	print("WORLD SOUND PASS" if fails == 0 else "WORLD SOUND FAIL %d" % fails)
	get_tree().quit()
