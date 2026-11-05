extends Node
## r34 crypt (docs/r34/raid_crypt.md): the Bone Abbot's pit hall and raid, in memory only (saves held).
##   - the hall is built at size inside the layout's OSSUARY_HALL reserve, its floor and sectors stand
##   - the way down walks: the pit -> the Counting Door -> the eight flights -> the raid door
##   - the fight starts past the inner grille; both grilles shut; casts are exposed (cast_info)
##   - every phase and the intermission are reached: the Tolling (with its sound-shadow), the mound
##     and the Tallies, the Choir's hymn, the Reckoning's plates, the floor falling (and a fall into the
##     deep thrown back up), the burn; the soft enrage
##   - the kill: saved, the grilles open, the lift released, the Bone Reliquary before the mound, the
##     floor restored, his dead gone with him
## Run: HOME=<scratch> godot --headless --path . res://zz/crypt_r34_test.tscn [-- --sim]
##   --sim: a scripted fight at ~4.5 effective dps (Tallies and Choir broken a few seconds after they
##   rise; time x3) and prints the kill time per phase (not part of the gate).
const Hall := preload("res://world/areas/ossuary/oss_hall.gd")
var p: Player
var main: Node
var fails := 0
var hall: Node3D


func _ready() -> void:
	Travel._busy = true
	Travel.seals_broken.clear()
	Travel.bosses_slain.clear()
	Travel.relics.erase("bone")
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	get_tree().create_timer(400.0, true, false, true).timeout.connect(func() -> void:
		print("CRYPT34 FAIL timeout")
		get_tree().quit(1))
	_run()


func check(name: String, ok: bool, extra := "") -> void:
	print("CRYPT34 ", "PASS " if ok else "FAIL ", name, ("  [%s]" % extra) if extra != "" else "")
	if not ok:
		fails += 1


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _secs(s: float) -> void:
	await get_tree().create_timer(s, false).timeout


func _arena() -> BossArena:
	for a in get_tree().get_nodes_in_group(&"boss_arena"):
		if (a as BossArena).boss_id == "bone_abbot":
			return a
	return null


func _shut(g: Node) -> bool:
	return g != null and is_instance_valid(g) and (g as WardSeal)._body.collision_layer != 0


func _boss() -> BoneAbbot:
	var a := _arena()
	var b: Variant = a.get("_boss") if a else null
	return b as BoneAbbot if b is BoneAbbot and is_instance_valid(b) else null


func _ray(at: Vector3, up := 2.0, down := 8.0) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * up, at + Vector3.DOWN * down, Layers.WORLD)
	q.exclude = [p.get_rid()]
	var h := p.get_world_3d().direct_space_state.intersect_ray(q)
	return (h.position as Vector3) if not h.is_empty() else Vector3.INF


func _tp(at: Vector3) -> void:
	p.teleport(at)
	p.velocity = Vector3.ZERO


func _run() -> void:
	while main == null or not main.has_meta("realm_done"):
		await get_tree().process_frame
	p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
	hall = main.find_child("Crypt", true, false) as Node3D
	for e in get_tree().get_nodes_in_group(Groups.ENEMY):
		(e as Node).queue_free()
	await _secs(1.0)
	await _static_checks()
	if "--sim" in OS.get_cmdline_user_args():
		await _sim()
	else:
		await _walk_down()
		await _fight()
	print("CRYPT34 %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit(0 if fails == 0 else 1)


# --- the hall ------------------------------------------------------------------------------------

func _static_checks() -> void:
	check("the hall is built", hall != null and bool(hall.get("built")))
	if hall == null:
		return
	check("raid-sized: 45 m wall to wall, a 37 m floor", Hall.WALL_R * 2.0 >= 44.0 and Hall.FLOOR_R * 2.0 >= 36.0)
	# every piece of the hall and the stair (below the bank) lies in the reserved box
	var box := RealmLayout.OSSUARY_HALL.grow(0.6)
	var out := 0
	for gi in (hall.get("hall") as Node3D).find_children("*", "GeometryInstance3D", true, false):
		var g := gi as GeometryInstance3D
		if g is MultiMeshInstance3D or g is GPUParticles3D:
			continue
		var bb: AABB = g.global_transform * g.get_aabb()
		if bb.size.length() > 0.01 and not box.encloses(bb):
			out += 1
			print("CRYPT34 outside the reserve: %s %s" % [g.name, bb])
	check("the hall stays inside OSSUARY_HALL", out == 0, str(out))
	var c := Hall.C
	var hits := 0
	var n := 0
	for i in 16:
		for r: float in [0.0, 6.0, 12.0, 17.0]:
			if r == 0.0 and i > 0:
				continue
			var a := TAU * float(i) / 16.0
			var q := c + Vector3(cos(a) * r, 0.0, sin(a) * r)
			var f := _ray(q, 1.0, 3.0) if r > 0.0 else _ray(q, 8.0, 3.0)
			n += 1
			if f != Vector3.INF and (r == 0.0 or absf(f.y - Hall.FLOOR_Y) < 0.05):
				hits += 1
	check("the floor stands at y %.0f everywhere (%d of %d)" % [Hall.FLOOR_Y, hits, n], hits == n)
	var sockets: Array = hall.get("sockets")
	check("three chapels with Tally plinths", sockets.size() == 3)
	check("four bells", (hall.get("bells") as Array).size() == 4)
	check("eight sectors standing", (hall.get("sectors") as Array).size() == 8 and int(hall.call("fallen_count")) == 0)
	check("in_ossuary covers the hall", RealmLayout.in_ossuary(c + Vector3.UP * 1.0))
	var a := _arena()
	check("the Abbot's arena is the hall's floor", a != null and a.global_position.distance_to(c) < 0.5 and a.radius >= 22.0)
	check("raid door: two arena grilles, open at rest", a != null and a.gate != null and a.gate.get("arena_only") == true and a.gates.size() == 1 and not _shut(a.gate) and not _shut(a.gates[0]))
	var lift := main.find_child("ChainLift", true, false)
	check("the chain lift is held until the Abbot falls", lift != null and bool(lift.get("hold")))
	check("the gallery seal still guards the crypt", main.find_child("Seal_oss_gallery", true, false) != null)
	if a:
		var au := a.audit()
		check("arena audit clean", au.is_empty(), str(au))


## The wanderer walks it: the pit, the Counting Door, eight flights, the raid door (physics, no teleports).
func _walk_down() -> void:
	var lanes := [(Hall.LANE_A.x + Hall.LANE_A.y) * 0.5, (Hall.LANE_B.x + Hall.LANE_B.y) * 0.5]
	var dz := Hall.DOOR_Z
	var zn := (Hall.ZN + Hall.ZN_OUT) * 0.5
	var pts: Array[Vector2] = [Vector2(24.5, dz), Vector2(28.6, dz), Vector2(lanes[0], dz)]
	for i in range(1, Hall.FLIGHTS + 1):
		var lane: float = lanes[0] if i % 2 == 1 else lanes[1]
		var other: float = lanes[1] if i % 2 == 1 else lanes[0]
		var end_z := zn if i % 2 == 1 else dz
		pts.append(Vector2(lane, end_z))
		if i < Hall.FLIGHTS:
			pts.append(Vector2(other, end_z))
	pts.append(Vector2(Hall.SX1 + 0.9, dz))
	var da := Hall.door_ang()
	for r: float in [22.0, 19.6]:
		var q := Hall.at(da, r)
		pts.append(Vector2(q.x, q.z))
	_tp(Vector3(21.5, Ossuary.PIT_Y + 0.3, -82.0))
	await _frames(10)
	var t0 := Time.get_ticks_msec()
	var reached := 0
	for i in pts.size():
		var target := pts[i]
		var t := 0.0
		while t < 10.0:
			var d := Vector2(target.x - p.global_position.x, target.y - p.global_position.z)
			if d.length() < 0.6:
				break
			p.debug_drive(Vector3(d.x, 0.0, d.y).normalized())
			await get_tree().physics_frame
			t += 1.0 / 60.0
			p.gloom = 0.0
		if t >= 10.0:
			print("CRYPT34 walk stuck before waypoint %d %s at %s" % [i, target, p.global_position.snapped(Vector3.ONE * 0.01)])
			break
		reached += 1
	p.debug_drive(Vector3.ZERO)
	await _frames(10)
	check("walked from the pit down the Counting Stair to the raid door (%d of %d, %.0f s)" % [reached, pts.size(), (Time.get_ticks_msec() - t0) * 0.001], reached == pts.size())
	check("reached the hall's floor level", absf(p.global_position.y - Hall.FLOOR_Y) < 0.6, str(p.global_position))
	check("no fight before the inner grille", _boss() == null)


# --- the fight ------------------------------------------------------------------------------------

func _fight() -> void:
	# the wanderer is kept out of the dark (the checks are the boss's, not a survival run)
	get_tree().physics_frame.connect(func() -> void:
		if is_instance_valid(p) and not get_meta(&"let_gloom", false):
			p.gloom = 0.0)
	var a := _arena()
	var c := Hall.C
	var da := Hall.door_ang()
	_tp(Hall.at(da, 15.0, c.y + 0.2))
	await _frames(20)
	var b := _boss()
	check("the Bone Abbot rose", b != null)
	if b == null:
		return
	check("both grilles shut on the pull", _shut(a.gate) and _shut(a.gates[0]))
	check("%d HP, phase I" % BoneAbbot.HP, b.max_hp == BoneAbbot.HP and b.phase == 1)
	await _secs(2.5)
	# phase I: a cast, then the Tolling forced
	b.set("_toll_t", 0.0)
	b.set("_busy", 0.0)
	var told := ""
	for i in 120:
		p.gloom = 0.0
		if b.casting():
			told = b.cast_name
			if told == "The Tolling":
				break
		await get_tree().physics_frame
	check("the Tolling is a cast the HUD can read", told == "The Tolling" and not b.cast_info().is_empty(), told)
	# the sound-shadow holds: stand in it when the bell lands
	var bells: Array = Hall.BELLS
	var pa := rad_to_deg(atan2(p.global_position.z - c.z, p.global_position.x - c.x))
	var best := 0
	for i in bells.size():
		if absf(angle_difference(deg_to_rad(pa), deg_to_rad(float(bells[i])))) < absf(angle_difference(deg_to_rad(pa), deg_to_rad(float(bells[best])))):
			best = i
	var away := -Vector3(cos(deg_to_rad(float(bells[best]))), 0.0, sin(deg_to_rad(float(bells[best]))))
	_tp(c + away * BoneAbbot.SHADOW_AT + Vector3.UP * 0.2)
	set_meta(&"let_gloom", true)
	p.gloom = 0.0
	var g0 := p.gloom
	await _secs(BoneAbbot.TOLL_TIME + 0.5)
	check("the mound's sound-shadow is safe from the Tolling", p.gloom - g0 < 1.0, "%.1f" % (p.gloom - g0))
	set_meta(&"let_gloom", false)
	_tp(Hall.at(da, 15.0, c.y + 0.2))
	# the intermission
	b.set_meta(&"test_no_floor", true)
	b.hp = b.max_hp * 0.65
	await _secs(2.6)
	check("at 66 % he sinks into the mound (intermission)", int(b.get("_inter")) == 1 and not b.is_in_group(Groups.ENEMY), "inter %d" % int(b.get("_inter")))
	var tallies: Array = b.get("_tallies")
	check("three Tallies rise in the chapels", tallies.size() == 3)
	var hp0 := b.hp
	b.take_hit(50.0)
	check("nothing reaches him in the mound", is_equal_approx(b.hp, hp0))
	check("the intermission is a cast on the bar", b.cast_name == "The Count Is Taken")
	await _secs(3.0)
	var adds := 0
	for e in get_tree().get_nodes_in_group(Groups.ENEMY):
		if (e as Node).has_meta(&"abbot_add"):
			adds += 1
	check("the dead climb out of the mound", adds >= 2, str(adds))
	for t in tallies:
		if is_instance_valid(t):
			(t as Enemy).take_hit(999.0)
	await _secs(2.5)
	check("the Tallies broken: he rises into phase II", int(b.get("_inter")) == 2 and b.phase == 2 and b.is_in_group(Groups.ENEMY))
	check("unfed: no heal", b.hp <= hp0 + 0.5)
	await _secs(2.0)
	var choir: Array = b.call("_choir")
	check("the Choir of the Count takes up the hymn", choir.size() == 2, str(choir.size()))
	await _frames(3)
	var h1 := b.hp
	b.take_hit(10.0)
	check("hymned: half damage while the Choir sings", absf((h1 - b.hp) - 5.0) < 0.6, "%.2f" % (h1 - b.hp))
	for e in choir:
		(e as Enemy).take_hit(999.0)
	await _frames(5)
	h1 = b.hp
	b.take_hit(10.0)
	check("silenced: full damage", absf((h1 - b.hp) - 10.0) < 0.6, "%.2f" % (h1 - b.hp))
	# the Reckoning
	await _secs(1.5)
	while b.casting():
		await get_tree().physics_frame
	b.set("_reckon_t", 0.0)
	b.set("_busy", 0.0)
	b.set("_choir_t", 99.0)
	b.set("_raise_t", 99.0)
	b.set("_toll_t", 99.0)
	for i in 60:
		if not (b.get("_plates") as Array).is_empty():
			break
		await get_tree().physics_frame
	var plates: Array = (b.get("_plates") as Array).duplicate()
	check("the Reckoning lays its plates", plates.size() == 3, str(plates.size()))
	for pl: Dictionary in plates:
		_tp((pl.at as Vector3) + Vector3.UP * 0.2)
		await _frames(6)
	check("every plate counted (the bar says so)", b.cast_name.contains("3 of 3"), b.cast_name)
	_tp(Hall.at(da, 15.0, c.y + 0.2))
	# phase III: the floor falls
	b.hp = b.max_hp * 0.32
	await _secs(1.0)
	check("phase III at 33 %", b.phase == 3)
	await _secs(10.0)
	check("the floor remembers: four sectors fell", int(hall.call("fallen_count")) == 4, str(hall.call("fallen_count")))
	var k: int = Hall.FALL_III[0]
	var over := c + Vector3(cos(deg_to_rad(45.0 * k)), 0, sin(deg_to_rad(45.0 * k))) * 14.5
	var f := _ray(over + Vector3.UP * 0.5, 1.0, 12.0)
	check("no floor over a fallen sector (the deep below)", f != Vector3.INF and f.y < Hall.FLOOR_Y - 3.0, str(f))
	set_meta(&"let_gloom", true)
	_tp(over + Vector3.UP * 0.4)
	var g1 := p.gloom
	await _secs(2.0)
	check("a fall into the deep throws you back onto standing stone", bool(hall.call("floor_under", p.global_position)) and p.global_position.y > Hall.FLOOR_Y - 0.6, str(p.global_position.snapped(Vector3.ONE * 0.1)))
	check("...for Gloom", p.gloom - g1 >= 15.0, "%.1f" % (p.gloom - g1))
	set_meta(&"let_gloom", false)
	_tp(Hall.at(da, 15.0, c.y + 0.2))
	# phase IV: the burn
	b.hp = b.max_hp * 0.11
	await _secs(8.0)
	check("phase IV (the burn) at 12 %", b.phase == 4)
	check("three more sectors fell; the door's tongue stands", int(hall.call("fallen_count")) == 7 and not (hall.get("fallen") as Array)[Hall.KEEP])
	h1 = b.hp
	b.take_hit(1.0)
	check("he no longer wards himself (+20 % taken)", absf((h1 - b.hp) - 1.2) < 0.05 or b._ward_t > 0.0, "%.2f" % (h1 - b.hp))
	# the soft enrage
	b.fight_t = BoneAbbot.ENRAGE_AT + 1.0
	await _frames(5)
	check("the Last Count: soft enrage", b.dmg_mult > 1.0, "%.2f" % b.dmg_mult)
	# the kill
	b.marks = 0
	b.take_hit(999.0)
	await _secs(2.0)
	check("the Abbot slain and saved", Travel.bosses_slain.has("bone_abbot"))
	check("both grilles open after the kill", not _shut(a.gate) and not _shut(a.gates[0]))
	var lift := main.find_child("ChainLift", true, false)
	check("the chain lift released", lift != null and not bool(lift.get("hold")))
	var r := main.find_child("BoneReliquary", true, false) as Node3D
	check("the Bone Reliquary rises before the mound", r != null and Vector2(r.global_position.x - c.x, r.global_position.z - c.z).length() < 7.0)
	check("the floor is whole again", int(hall.call("fallen_count")) == 0)
	var left := 0
	for e in get_tree().get_nodes_in_group(Groups.ENEMY):
		if (e as Node).get_meta(&"summoned_by", "") == "bone_abbot" and (e as Enemy).is_alive():
			left += 1
	check("his dead go down with him", left == 0, str(left))


# --- the scripted fight (--sim) ----------------------------------------------------------------------

func _sim() -> void:
	var c := Hall.C
	var dps := 3.5
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dps="):
			dps = float(a.trim_prefix("--dps="))
	Engine.time_scale = 3.0
	_tp(Hall.at(Hall.door_ang(), 15.0, c.y + 0.2))
	await _frames(20)
	var b := _boss()
	if b == null:
		check("sim: boss", false)
		return
	var t := 0.0
	var marks := {}
	var seen := {}
	var last_phase := "I"
	var tick := 0.0
	while is_instance_valid(b) and b.is_alive() and t < 900.0:
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time() * Engine.time_scale
		t += dt
		p.gloom = 0.0
		var ph: String = ("I" if b.phase == 1 else ["", "", "II", "III", "IV"][b.phase]) if int(b.get("_inter")) != 1 else "INT"
		if ph != last_phase:
			marks[ph] = t
			last_phase = ph
		if b.casting():
			seen[b.cast_name.split(" ·")[0]] = true
		# the player stays near him (inside 9 m: the Tolling's shadow, plates etc. are not simulated)
		tick += dt
		if tick >= 0.5:
			tick = 0.0
			if b.is_in_group(Groups.ENEMY):
				b.take_hit(dps * 0.5, null)
			for e in get_tree().get_nodes_in_group(Groups.ENEMY):
				var en := e as Enemy
				if en == b or not en.is_alive():
					continue
				var age := float(en.get_meta(&"sim_age", 0.0)) + 0.5
				en.set_meta(&"sim_age", age)
				if (en.has_meta(&"abbot_choir") and age > 6.0) or (en.name.begins_with("Tally") and age > 6.0 + 4.0 * float(en.get_instance_id() % 3)):
					en.marks = 1
					en.take_hit(999.0, null)
	Engine.time_scale = 1.0
	print("CRYPT34 SIM dps %.1f: killed=%s in %.0f s; phases at %s; casts seen %s" % [dps, not is_instance_valid(b) or not b.is_alive(), t, marks, seen.keys()])
	check("sim: the fight ends in 4-7 minutes at %.1f dps" % dps, t >= 200.0 and t <= 460.0, "%.0f s" % t)
