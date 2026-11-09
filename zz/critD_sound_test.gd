extends Node
## Critique D (r29) sound and life fixes, headless:
##   godot --headless --path . res://zz/critD_sound_test.tscn
## Checks: the Music bus (sends to Master, music players on it, level follows the slider), the
## limiter last on Master; Sfx: a stream re-fired on the same spot is turned down, the pool never
## grows past its voices and steals the oldest, a freed voice is rebuilt without errors, a non-finite
## position is ignored, one out of earshot is not played; rain hushes the crickets; no rain bed deep in the Ossuary; the night bed's
## twin plays; a wheeling flock glides between its ticks (the buffer moves on frames it is not
## ticked); Sfx.release() clears. Holds Travel._busy; quits by itself.
## Ends CRITD SOUND PASS / CRITD SOUND FAIL n.

var main: Node
var t := 0.0
var started := false
var fails := 0


func _ready() -> void:
	Travel._busy = true
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func check(ok: bool, msg: String) -> void:
	if ok:
		print("CRITD ok  ", msg)
	else:
		fails += 1
		print("CRITD FAIL ", msg)


func _process(d: float) -> void:
	t += d
	if Time.get_ticks_msec() > 240000:
		print("CRITD TIMEOUT")
		get_tree().quit(1)
		return
	if started:
		for e in get_tree().get_nodes_in_group(Groups.ENEMY):
			if not (e as Node).is_queued_for_deletion():
				(e as Node).queue_free()
		return
	if main == null or not main.has_meta("realm_done") or main.get_node_or_null("Wildlife") == null:
		return
	started = true
	_run()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _run() -> void:
	var amb := main.get_node_or_null("Ambience")
	var wild := main.get_node_or_null("Wildlife")
	if amb == null or wild == null or not wild.has_meta("weather"):
		check(false, "the zone has its Ambience and Wildlife (main.gd ran)")
		print("CRITD SOUND FAIL %d" % fails)
		get_tree().quit(1)
		return
	var wx: Node = wild.get_meta("weather")
	var player := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	# ---- buses
	var mi := AudioServer.get_bus_index("Music")
	check(mi >= 0 and AudioServer.get_bus_send(mi) == &"Master", "Music bus sends to Master")
	var mu: Node = amb.get("music")
	var on_music := mu != null
	if mu != null:
		for c in mu.get_children():
			if c is AudioStreamPlayer and (c as AudioStreamPlayer).bus != &"Music":
				on_music = false
	check(on_music, "the music's players are on the Music bus")
	var lim := false
	var master := AudioServer.get_bus_index("Master")
	var n_fx := AudioServer.get_bus_effect_count(master)
	lim = n_fx > 0 and AudioServer.get_bus_effect(master, n_fx - 1) is AudioEffectHardLimiter
	check(lim, "a hard limiter is the last effect on Master")
	var want: Variant = Settings.get("music_volume")
	if want == null:
		want = Settings.get("ambience_volume")
	await _frames(20)
	check(absf(AudioServer.get_bus_volume_db(mi) - linear_to_db(maxf(float(want), 0.0001))) < 0.1, "Music bus at the slider's level (%.1f dB)" % AudioServer.get_bus_volume_db(mi))
	var db := float((mu.get_script() as Script).get_script_constant_map().get("DB", -99.0)) if mu != null else -99.0
	check(db >= 0.0, "music layer raised (DB %.1f)" % db)
	# ---- Sfx pool
	var s := load("res://art/audio/mark_tick.wav") as AudioStream
	var at := player.global_position + Vector3(2, 1, 0)
	for i in 3:
		Sfx.play_stream(s, at, 0.0, 1.0, 0.0)
	var vols: Array = []
	for v in Sfx._voices:
		if is_instance_valid(v) and v.stream == s and v.playing:
			vols.append(snappedf(float(v.get_meta(&"rise_db")) if v.has_meta(&"rise_db") else v.volume_db, 0.1))   # (Sfx fades each in over 14 ms)
	vols.sort()
	check(vols.size() == 3 and float(vols[0]) <= -7.9 and float(vols[2]) >= -0.1, "a stream re-fired on the spot is turned down %s" % str(vols))
	for i in 40:
		Sfx.play_stream(Synth_stream(i), at + Vector3(float(i % 8) * 0.6, 0, float(i / 8) * 0.6), -20.0, 1.0, 0.0)
	check(Sfx._voices.size() == Sfx.VOICES, "the pool stays at %d voices (%d)" % [Sfx.VOICES, Sfx._voices.size()])
	var victim: Node = Sfx._voices[3]
	victim.free()
	Sfx.play_stream(s, at + Vector3(0, 0, 4), -20.0)
	var all_ok := true
	for v in Sfx._voices:
		all_ok = all_ok and is_instance_valid(v)
	check(all_ok and not Sfx._voices.is_empty(), "a freed voice: the pool is rebuilt (%d voices)" % Sfx._voices.size())
	var n0 := Sfx._voices.size()
	Sfx.play_stream(s, Vector3(NAN, 0, 0), 0.0)
	check(Sfx._voices.size() == n0, "a non-finite position is ignored")
	var far := Synth_stream(99)
	Sfx.play_stream(far, at + Vector3(300, 0, 0), 0.0)
	var used := false
	for v in Sfx._voices:
		used = used or (is_instance_valid(v) and v.stream == far)
	check(not used, "a sound 300 m off is not given a voice")
	# ---- rain and the beds
	var y := RealmLayout.ground(player.get_world_3d().direct_space_state, 8.0, 42.0)
	player.global_position = Vector3(8, y + 0.2, 42)
	wx.force("clear", true)
	await get_tree().create_timer(4.0).timeout
	var dry := float((amb.get("bed_want") as Dictionary).get("crickets", 0.0))
	wx.force("drizzle", true)
	await get_tree().create_timer(1.0).timeout
	var wet := float((amb.get("bed_want") as Dictionary).get("crickets", 0.0))
	check(dry > 0.3 and wet < dry * 0.3, "rain hushes the crickets (%.2f -> %.2f)" % [dry, wet])
	var twin := amb.get_node_or_null("Bed_night_twin") as AudioStreamPlayer
	check(twin != null and twin.playing and absf(twin.pitch_scale - 1.0) > 0.01, "the night bed's detuned twin plays")
	# stand deep in the crypt (the camera follows): the surface check reads where she is
	player.global_position = Vector3(16.0, -3.0, -60.0)
	wx.set("_biome_t", 0.0)
	await _frames(30)
	wx.set("_biome_t", 0.0)
	await _frames(3)
	check(String(wx.get("surface")) == "under", "no rain on a roof deep in the Ossuary (%s)" % wx.get("surface"))
	wx.force("clear", true)
	# ---- glide: a lifted flock is redrawn between its ticks
	var flock: Node = null
	for g in wild.groups:
		if String(g.kind) == "plover":
			flock = g
			break
	if flock == null:
		check(false, "a lapwing flock to lift")
	else:
		var fc: Vector3 = flock.center
		var cam := get_viewport().get_camera_3d()
		player.global_position = fc + Vector3(18, 0, 0)
		player.global_position.y = RealmLayout.ground(player.get_world_3d().direct_space_state, fc.x + 18, fc.z) + 0.2
		if player.has_method("set_view"):
			player.call("set_view", PI * 0.5, -0.1)          # facing the flock (it glides only in view)
		await _frames(10)
		flock.call("_lift", fc + Vector3(18, 0, 0))
		await _frames(30)
		var mm: MultiMesh = flock.get("mmi").multimesh
		var changed := 0
		# r30: the drawn rows are the interpolated copy (LifeGroup._ld); _buf is the newest tick only
		var last := PackedFloat32Array(flock.get("_ld"))
		for i in 30:
			await get_tree().process_frame
			var now := PackedFloat32Array(flock.get("_ld"))
			if now != last:
				changed += 1
			last = now
		check(changed >= 25, "the flock's buffer moves on %d of 30 frames (logic at 20 Hz + glide)" % changed)
		check(mm.instance_count > 0 and cam != null, "flock drawn")
	# ---- release
	Sfx.release()
	check(Sfx._voices.is_empty() and Sfx._streams.is_empty(), "Sfx.release() clears its caches")
	print("CRITD SOUND PASS" if fails == 0 else "CRITD SOUND FAIL %d" % fails)
	get_tree().quit(0 if fails == 0 else 1)


## A distinct stream per index (so the stacking guard does not turn them down).
func Synth_stream(i: int) -> AudioStream:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = 22050
	var b := PackedByteArray()
	b.resize(22050)
	for k in b.size() / 2:
		b.encode_s16(k * 2, int(sin(float(k) * 0.05 * float(i + 1)) * 3000.0))
	w.data = b
	return w
