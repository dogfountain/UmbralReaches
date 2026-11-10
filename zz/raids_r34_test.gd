extends Node
## r34 overworld raids (docs/r34/raids_overworld.md): both raid rooms built at size, their gates (shut
## while guarded, shut on the pull, open on a reset or the kill), every phase and intermission of the
## Thornwarden and the Ascended Warden reached and checked, the room mechanics (Thornstorm shelter,
## the maze, heart-knots, the closing briars, pylons, the Gale, the Eclipse), no soft enrage (r35), the kill
## flow, and the Ember Road shut during a fight. The fights are scripted deterministically: the test
## sets each phase's health (and its signature count) and calls the moves itself.
## Run: SCRATCH=<dir> tools/run_tests.sh raids_r34
var p: Player
var main: Node
var fails := 0
var started := false
var keep_gloom := false


func _init() -> void:
	Engine.set_meta(&"full_night", true)   # the 30-minute slice hides horses, watch, roaming events, dailies, attunements


func _ready() -> void:
	Travel._busy = true
	Travel.bosses_slain.clear()
	Travel.seals_broken.clear()
	# r36 Act II: the summit opens to a peal; four of the Founder's bells answered for (rung, so
	# the Warden keeps his whole life for the fight's numbers)
	var qb := preload("res://core/story/quest_book.gd")
	for bid: String in (preload("res://core/story/quest_chains.gd").BELLS as Array).slice(0, 4):
		qb.start(bid)
		qb.choose(bid, "rung")
	
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func check(name: String, ok: bool, detail := "") -> void:
	print("RAIDS34 %s %s %s" % ["PASS" if ok else "FAIL", name, detail])
	if not ok:
		fails += 1


func _physics_process(_d: float) -> void:
	if started:
		return
	if Engine.get_physics_frames() > 60 * 300:
		print("RAIDS34 FAIL timeout waiting for the world")
		get_tree().quit(1)
		return
	if p == null:
		p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		return
	if not main.has_meta("realm_done") or not main.has_meta("summit_dressed"):
		return
	for sp in get_tree().root.find_children("EnemySpawner", "", true, false):
		if (sp._slots as Array).is_empty():
			return
	started = true
	_run()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
		if not keep_gloom and p:
			p.gloom = 0.0; p.wounds = 0.0


func _secs(s: float) -> void:
	await _frames(int(s * 60.0))


func _ground(x: float, z: float) -> Vector3:
	return Vector3(x, RealmLayout.ground(p.get_world_3d().direct_space_state, x, z), z)


func _tp(at: Vector3) -> void:
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 3.0, at + Vector3.DOWN * 6.0, Layers.WORLD)
	q.exclude = [p.get_rid()]
	var hit := p.get_world_3d().direct_space_state.intersect_ray(q)
	p.teleport(((hit.position as Vector3) if not hit.is_empty() else at) + Vector3.UP * 0.15)
	p.gloom = 0.0; p.wounds = 0.0


func _seal(id: String) -> WardSeal:
	for s in get_tree().get_nodes_in_group(&"ward_seal"):
		if (s as WardSeal).seal_id == id:
			return s
	return null


func _arena(id: String) -> BossArena:
	for a in get_tree().get_nodes_in_group(&"boss_arena"):
		if (a as BossArena).boss_id == id:
			return a
	return null


func _boss() -> Enemy:
	for e in get_tree().get_nodes_in_group(Groups.ENEMY):
		if (e as Node).has_meta(&"boss_id") and (e as Enemy).is_alive():
			return e
	return null


func _shut(g: Node) -> bool:
	return g != null and int((g as WardSeal)._body.collision_layer) != 0


func _kill_seal(id: String) -> int:
	var n := 0
	for sp in get_tree().root.find_children("EnemySpawner", "", true, false):
		for slot in sp._slots:
			if slot.get("seal", "") == id and is_instance_valid(slot.pawn) and slot.pawn is Enemy and (slot.pawn as Enemy).is_alive():
				(slot.pawn as Enemy).take_hit(999.0)
				n += 1
	return n


func _clear_others() -> void:
	for e in get_tree().get_nodes_in_group(Groups.ENEMY):
		if not (e as Node).has_meta(&"boss_id") and not (e as Node).has_meta(&"summoned_by"):
			(e as Node).queue_free()


## Into a phase: its signature counted (the HP floor lifted), health just under the mark.
func _to_hp(b: Enemy, ratio: float) -> void:
	b.set("_sig", 2)
	b.hp = float(b.max_hp) * ratio - 1.0
	b._ward_t = 0.0


func _run() -> void:
	for n: String in ["Encounters", "Rares"]:
		var x := main.find_child(n, true, false)
		if x:
			x.process_mode = Node.PROCESS_MODE_DISABLED
	# the summit's guards first (the spawner is held still during the fights), and the Abbot counted
	# as fallen (his crypt is another agent's test)
	Travel.bosses_slain["bone_abbot"] = true
	_tp(_ground(RealmLayout.CROSSING_FOOT.x + 4.0, RealmLayout.CROSSING_FOOT.z + 6.0))
	await _frames(30)
	print("RAIDS34 summit guards killed ", _kill_seal("summit"))
	await _frames(30)
	await _henge()
	await _summit()
	print("RAIDS34 %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit(0 if fails == 0 else 1)


# --- Thorn Henge: the Thornwarden ----------------------------------------------------------------

func _henge() -> void:
	var arena := _arena("thornwarden")
	var room := arena.room if arena else null
	check("henge: arena and room exist", arena != null and room != null)
	if room == null:
		return
	var C: Vector3 = arena.global_position
	var raid := RealmLayout.raid("henge")
	check("henge: the room is raid-sized", arena.radius >= 28.0 and float(room.get("WALL_R")) >= 29.5 and float(raid.r) >= 30.0, "arena r %.1f, wall r %.1f" % [arena.radius, float(room.get("WALL_R"))])
	var body := room.get_node_or_null("RaidWallBody")
	check("henge: an outer wall all round but the door", body != null and body.get_child_count() >= 85, str(body.get_child_count() if body else -1))
	check("henge: great stones for shelter", (room.get("stones") as Array).size() >= 8)
	var walls: Array = room.get("walls")
	var stage := {1: 0, 2: 0, 3: 0}
	for w in walls:
		stage[int(w.get("stage"))] += 1
	check("henge: a three-stage maze, all down at rest", walls.size() >= 15 and stage[1] > 0 and stage[2] > 0 and stage[3] > 0 and int(room.call("grown_count")) == 0, str(stage))
	check("henge: the arena floor audits clean", arena.audit().is_empty(), str(arena.audit()))
	var seal := _seal("henge")
	check("henge: the raid door is the thorn seal, on the rim", seal != null and arena.gate == seal and Vector2(seal.global_position.x - C.x, seal.global_position.z - C.z).length() > 28.0)
	check("henge: the door is shut while its guards live", _shut(seal))
	var fire := main.find_child("HengeFire", true, false) as Node3D
	check("henge: the fire stands outside the room", fire != null and Vector2(fire.global_position.x - C.x, fire.global_position.z - C.z).length() > arena.radius, "%.1f m" % (Vector2(fire.global_position.x - C.x, fire.global_position.z - C.z).length() if fire else -1.0))
	print("RAIDS34 henge guards killed ", _kill_seal("henge"))
	await _frames(30)
	var sp := main.find_child("EnemySpawner", true, false)
	if sp:
		sp.process_mode = Node.PROCESS_MODE_DISABLED
	_clear_others()
	check("henge: the door opens once its guards fall", seal.is_open() and not _shut(seal))
	# the pull
	var gout := (seal.global_position - C)
	gout.y = 0.0
	gout = gout.normalized()
	_tp(C + gout * 14.0)
	await _frames(20)
	var b := _boss() as Thornwarden
	check("henge: the Thornwarden rises on the pull", b != null)
	if b == null:
		return
	check("henge: the raid door shuts behind you", _shut(seal) and Player.boss_fight_active(get_tree()))
	check("henge: the boss is raid-sized", b._rig != null and b._rig.scale.x >= 2.5 and b.max_hp >= 500, "x%.1f, %d hp" % [b._rig.scale.x if b._rig else 0.0, b.max_hp])
	check("henge: the pull is announced (emote)", arena.last_emote != "", arena.last_emote)
	await _secs(2.6)
	# r35: its own theme (boss_themes.gd), rendered on a thread on the first pull
	var themes := get_tree().get_first_node_in_group(&"boss_themes")
	# the render runs on a worker thread: on a loaded machine it takes longer than the 2.6 s above, so
	# wait for the fade (up to 12 s more) instead of reading it at one fixed moment
	var waited := 0.0
	while themes != null and waited < 12.0 and not (String(themes.get("playing_id")) == "thornwarden" and float(themes.get("theme_k")) > 0.3):
		await _secs(0.5)
		waited += 0.5
	check("henge: the Thornwarden's theme plays (not the shared danger pad)", themes != null and String(themes.get("playing_id")) == "thornwarden" and float(themes.get("theme_k")) > 0.3,
		"%s %.2f" % [themes.get("playing_id") if themes else "-", float(themes.get("theme_k")) if themes else 0.0])
	# phase I: the Thornstorm, line of sight
	b.global_position = C + Vector3.UP * 0.2
	b.velocity = Vector3.ZERO
	_tp(C + gout * 10.0)
	await _frames(3)
	b.call("_thornstorm")
	check("henge: Thornstorm is a cast that cannot be broken", b.cast_name == "Thornstorm" and not b.cast_interruptible)
	# r35: world cues, not text: one short line, no instruction (the lee of each stone lights up instead)
	check("henge: ...and it is announced in one short line", arena.last_emote != "" and arena.last_emote.length() <= 48 and not arena.last_emote.contains("!"), arena.last_emote)
	var g0 := p.wounds
	b.call("_storm_lands")
	check("henge: in the open, the storm hits", p.wounds > g0 + 20.0, "%.1f -> %.1f" % [g0, p.wounds])
	var stone := (room.get("stones") as Array)[2] as Node3D
	var out := stone.global_position - C
	out.y = 0.0
	_tp(stone.global_position + out.normalized() * 2.4)
	await _frames(3)
	check("henge: behind a great stone you are sheltered", bool(room.call("shelter", b.global_position + Vector3.UP, p.global_position)))
	g0 = p.wounds
	b.call("_storm_lands")
	check("henge: ...and the storm spares you", p.wounds <= g0 + 0.01, "%.1f -> %.1f" % [g0, p.wounds])
	b._finish_cast(true, false)
	# the intermission
	_tp(C + gout * 14.0)
	_to_hp(b, 0.7)
	await _frames(4)
	check("henge: at 70 % it roots into the heart (intermission)", b.rooted and b.phase == 2 and String(b.get_meta(&"phase_label", "")) != "")
	check("henge: three heart-knots grow", int(room.call("knots_left")) == 3)
	var hp_r := b.hp
	b.take_hit(25.0, null)
	check("henge: rooted, it takes no harm", absf(b.hp - hp_r) < 0.01)
	await _secs(2.2)
	check("henge: the first maze stage erupts after its warning", int(room.call("grown_count")) >= stage[1], str(room.call("grown_count")))
	await _secs(12.0)
	check("henge: the maze grows on (stage two)", int(room.call("grown_count")) >= stage[1] + stage[2], str(room.call("grown_count")))
	# r35: walking out mid-fight HOLDS it (it used to reset it): the boss, its adds and the room are
	# frozen as they stand, the gates open, and the dark gathers on you again out there
	var grown_before := int(room.call("grown_count"))
	var hp_before := b.hp
	var held_b := b
	_tp(_ground(C.x + gout.x * 44.0, C.z + gout.z * 44.0))
	await _frames(20)
	check("henge: leaving holds the fight (not a reset)", is_instance_valid(held_b) and held_b.is_alive() and arena.is_held() and held_b.process_mode == Node.PROCESS_MODE_DISABLED and not _shut(seal) and not Player.boss_fight_active(get_tree()))
	await _secs(1.5)
	check("henge: ...and the room stands frozen (maze and knots kept)", int(room.call("grown_count")) == grown_before and int(room.call("knots_left")) == 3, "%d / %d" % [int(room.call("grown_count")), int(room.call("knots_left"))])
	# walk back in: the same fight resumes where it was
	_tp(C + gout * 14.0)
	await _frames(20)
	b = _boss() as Thornwarden
	check("henge: coming back resumes it (same boss, same health, still rooted)", b == held_b and not arena.is_held() and absf(b.hp - hp_before) < 0.01 and b.rooted and Player.boss_fight_active(get_tree()))
	if b == null:
		return
	for kn in room.get("knots"):
		if is_instance_valid(kn):
			kn.call("take_hit", 999.0, null)
	await _frames(4)
	check("henge: every knot burned, it tears free into phase II", not b.rooted and b.phase == 2 and int(room.call("knots_left")) == 0)
	await _secs(2.0)
	check("henge: the knots' bays wither", int(room.call("grown_count")) <= grown_before, "%d of %d" % [int(room.call("grown_count")), grown_before])
	# phase II: the Thornspeaker. r35: the held fight kept its earlier adds (a walk-out no longer frees
	# them), and add waves are capped at five alive: clear them so this wave is the one measured
	for e in get_tree().get_nodes_in_group(Groups.ENEMY):
		if (e as Node).get_meta(&"summoned_by", "") == "thornwarden":
			(e as Node).queue_free()
	await _frames(2)
	b._ward_t = 0.0
	b._broken_t = 0.0
	b.call("_call_stones")
	await _frames(3)
	check("henge: Call of the Stones brings a Thornspeaker", int(b.call("speakers")) == 1)
	var h0 := b.hp
	b.take_hit(4.0, null)
	check("henge: while it sings the Thornwarden takes half", absf((h0 - b.hp) - 2.0) < 0.05, "%.2f" % (h0 - b.hp))
	for e in get_tree().get_nodes_in_group(Groups.ENEMY):
		if (e as Node).get_meta(&"summoned_by", "") == "thornwarden":
			(e as Enemy).take_hit(999.0)
	await _frames(3)
	h0 = b.hp
	b.take_hit(4.0, null)
	check("henge: the speaker dead, full damage again", absf((h0 - b.hp) - 4.0) < 0.05, "%.2f" % (h0 - b.hp))
	# phase III: the Last Bloom
	_to_hp(b, 0.35)
	await _frames(4)
	check("henge: at 35 % the Last Bloom (phase III)", b.phase == 3 and bool(room.get("briars_on")) and String(room.get("mood")) == "bloom")
	await _secs(2.0)
	check("henge: the maze withers for the burn", int(room.call("grown_count")) == 0)
	b._ward_t = 0.0
	b.call("_bloom")
	check("henge: Bloom of Thorns lays three rings", b.cast_name == "Bloom of Thorns" and (b.get("_moves") as Array).filter(func(m: Variant) -> bool: return is_instance_valid(m)).size() >= 3)
	await _secs(float(room.get("BRIAR_STEP")) - 1.0)
	check("henge: the briars close in", float(room.get("briars_r")) < float(room.get("BRIAR_START")) - 0.1, "%.1f" % float(room.get("briars_r")))
	keep_gloom = true
	_tp(C + gout * (float(room.get("briars_r")) + 1.8))
	p.gloom = 0.0; p.wounds = 0.0
	await _secs(1.2)
	check("henge: outside the briars you suffer", p.wounds > 3.0, "%.1f" % p.wounds)
	keep_gloom = false
	p.gloom = 0.0; p.wounds = 0.0
	_tp(C + gout * 6.0)
	check("henge: no soft enrage (r35)", not (Thornwarden as Script).get_script_constant_map().has("ENRAGE_AT") and is_equal_approx(b.dmg_mult, 1.0))
	check("henge: the theme's high stem has risen with the phases", themes != null and float(themes.get("_high_k")) > 0.3, "%.2f" % (float(themes.get("_high_k")) if themes else 0.0))
	# the kill
	b._ward_t = 0.0
	b.set_meta(&"test_no_floor", true)
	b.take_hit(9999.0)
	await _frames(40)
	check("henge: the kill is saved", Travel.bosses_slain.has("thornwarden"))
	check("henge: its theme lets go when it falls", themes != null and float(themes.get("_want")) == 0.0)
	check("henge: the raid door opens on the kill", not _shut(seal) and not Player.boss_fight_active(get_tree()))
	check("henge: the room settles (briars off)", not bool(room.get("briars_on")) and String(room.get("mood")) == "won")
	for e in get_tree().get_nodes_in_group(Groups.ENEMY):
		(e as Node).queue_free()
	await _frames(3)


# --- the Summit: the Ascended Warden -------------------------------------------------------------

func _summit() -> void:
	var arena := _arena("ascended_warden")
	var room := arena.room if arena else null
	check("summit: arena and room exist", arena != null and room != null)
	if room == null:
		return
	var C: Vector3 = arena.global_position
	check("summit: the deck is raid-sized", arena.radius >= 27.0 and absf(C.x) < 0.5 and absf(C.z + 118.0) < 0.5, "r %.1f at %s" % [arena.radius, C])
	var space := p.get_world_3d().direct_space_state
	var floor_ok := 0
	for i in 8:
		var a := TAU * float(i) / 8.0
		var at := C + Vector3(cos(a), 0, sin(a)) * 25.0
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 2.0, at + Vector3.DOWN * 3.0, Layers.WORLD))
		if not hit.is_empty() and absf((hit.position as Vector3).y - C.y) < 0.3:
			floor_ok += 1
	check("summit: deck under every side out to r 25", floor_ok == 8, str(floor_ok))
	check("summit: the arena floor audits clean", arena.audit().is_empty(), str(arena.audit()))
	var edge_open := space.intersect_ray(PhysicsRayQueryParameters3D.create(C + Vector3(24.0, 0.5, 0), C + Vector3(30.0, 0.5, 0), Layers.WORLD)).is_empty()
	var north_wall := not space.intersect_ray(PhysicsRayQueryParameters3D.create(C + Vector3(0, 0.5, -24.0), C + Vector3(0, 0.5, -30.0), Layers.WORLD)).is_empty()
	check("summit: the east edge is broken open, the north has its parapet", edge_open and north_wall)
	check("summit: four pylons, lit at rest", (room.get("pylons") as Array).size() == 4 and int(room.call("lit_count")) == 4)
	var fire := main.find_child("SummitFire", true, false) as Node3D
	check("summit: the fire stands outside the deck", fire != null and Vector2(fire.global_position.x - C.x, fire.global_position.z - C.z).length() > arena.radius + BossArena.LEAVE)
	check("summit: the mouth veil is open at rest", arena.gate != null and not _shut(arena.gate))
	check("summit: the ward opens (guards dead, both bosses down)", _seal("summit") != null and _seal("summit").is_open())
	# the pull
	_tp(C + Vector3(0, 0.3, 8.0))
	await _frames(20)
	var b := _boss() as AscendedWarden
	check("summit: the Warden rises on the pull", b != null)
	if b == null:
		return
	check("summit: the veil shuts", _shut(arena.gate) and Player.boss_fight_active(get_tree()))
	check("summit: the boss is raid-sized", b._rig != null and b._rig.scale.x >= 2.8 and b.max_hp >= 700)
	check("summit: eight blink points over the deck", (b.get("anchors") as Array).size() == 8, str((b.get("anchors") as Array).size()))
	await _secs(2.6)
	b._ward_t = 0.0
	b.call("_judgement")
	check("summit: Judgement shows as a cast", b.cast_name == "Judgement")
	b._finish_cast(true, false)
	b.cancel_moves()
	# the Ascension
	_to_hp(b, 0.65)
	await _frames(4)
	check("summit: at 65 % it ascends (intermission)", b.ascended and b.phase == 2 and int(room.call("lit_count")) == 0 and String(b.get_meta(&"phase_label", "")) != "")
	await _secs(3.0)
	check("summit: it hangs over the deck", b.global_position.y > C.y + 6.0, "%.1f" % (b.global_position.y - C.y))
	var hp_a := b.hp
	b.take_hit(30.0, null)
	check("summit: ascended, it takes no harm", absf(b.hp - hp_a) < 0.01)
	check("summit: the sky falls (stars on the deck)", (b.get("_moves") as Array).filter(func(m: Variant) -> bool: return is_instance_valid(m)).size() >= 1)
	var pyl: Array = room.get("pylons")
	for i in pyl.size():
		_tp((pyl[i] as Node3D).global_position + Vector3(1.6, 0.3, 0.0))
		await _secs(float(room.get("RELIGHT")) + 0.4)
		check("summit: pylon %d rekindled by standing in its ring" % i, bool(pyl[i].get("lit")))
	await _frames(4)
	check("summit: four pylons lit, it falls back to the deck (phase II)", not b.ascended and b.phase == 2 and b.global_position.y < C.y + 2.0)
	await _secs(2.0)
	# phase II: the Gale
	b._ward_t = 0.0
	b._broken_t = 0.0
	b.global_position = C + Vector3.UP * 0.1
	b.velocity = Vector3.ZERO
	_tp(C + Vector3(6.0, 0.3, 0.0))
	await _frames(2)
	var d0 := Vector2(p.global_position.x - C.x, p.global_position.z - C.z).length()
	b.call("_begin_gale")
	check("summit: Gale of the Door is announced and cast", b.cast_name == "Gale of the Door" and arena.last_emote.contains("door"))
	await _secs(AscendedWarden.GALE_CAST + 2.0)
	var d1 := Vector2(p.global_position.x - C.x, p.global_position.z - C.z).length()
	check("summit: the gale drives you toward the edge", d1 > d0 + 3.0, "%.1f -> %.1f m" % [d0, d1])
	var py: Node3D = pyl[0]
	var out := py.global_position - C
	out.y = 0.0
	var lee := py.global_position + out.normalized() * 2.2
	check("summit: a lit pylon is a windbreak", bool(room.call("gale_shelter", b.global_position, lee)))
	_tp(lee)
	await _frames(2)
	var s0 := p.global_position
	await _secs(1.0)
	check("summit: ...and behind it the gale does not move you", Vector2(p.global_position.x - s0.x, p.global_position.z - s0.z).length() < 0.6, "%.2f m" % Vector2(p.global_position.x - s0.x, p.global_position.z - s0.z).length())
	await _secs(AscendedWarden.GALE_TIME - 2.0)
	# the Eclipse: the lit rings are the pools, and the one you used is spent
	b._finish_cast(true, false)
	b.cancel_moves()
	b._gale_left = 0.0
	_tp(py.global_position + Vector3(1.6, 0.3, 0.0))
	await _frames(3)
	var lit0 := int(room.call("lit_count"))
	b.call("_eclipse")
	var holes: Array = []
	for at: Vector3 in room.call("pylon_points", true):
		holes.append([at, float(room.get("RING_R"))])
	check("summit: in a lit ring the eclipse spares you", not BossKit.inside(p.global_position, C, {"radius": arena.radius + 1.0, "holes": holes, "h": 3.0}))
	check("summit: ...outside one it does not", BossKit.inside(C + Vector3(0, 0.3, 4.0), C, {"radius": arena.radius + 1.0, "holes": holes, "h": 3.0}))
	await _secs(AscendedWarden.ECLIPSE_FILL + 0.3)
	check("summit: the ring you stood in is spent", int(room.call("lit_count")) == lit0 - 1, "%d -> %d" % [lit0, int(room.call("lit_count"))])
	# phase III: Aurel, Hierarch
	_to_hp(b, 0.3)
	await _frames(4)
	check("summit: at 30 % the Hierarch (phase III): every pylon blazes", b.phase == 3 and int(room.call("lit_count")) == 4 and String(room.get("mood")) == "hierarch")
	await _frames(2)
	check("summit: the bar names him", arena._bar_name != null and arena._bar_name.text.contains("AUREL"), arena._bar_name.text if arena._bar_name else "")
	check("summit: no soft enrage (r35)", not (AscendedWarden as Script).get_script_constant_map().has("ENRAGE_AT") and is_equal_approx(b.dmg_mult, 1.0))
	b._ward_t = 0.0
	b.set_meta(&"test_no_floor", true)
	b.take_hit(9999.0)
	await _frames(40)
	check("summit: the kill is saved", Travel.bosses_slain.has("ascended_warden"))
	check("summit: the veil lifts on the kill", not _shut(arena.gate) and not Player.boss_fight_active(get_tree()))
	check("summit: the room settles", String(room.get("mood")) == "won")
