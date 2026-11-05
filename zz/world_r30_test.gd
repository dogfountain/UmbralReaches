extends Node
## r30 world-builder checks (docs/critique/r30/world_builder.md), in memory only (saves held):
##   - the Abbot's and the Warden's fights shut their own arena-mouth gates, and a reset/kill opens
##     them again WITHOUT forcing the progression seals (portcullis, summit ward) open
##   - the Ossuary lift is held at the pit floor until the Abbot falls
##   - region_at names the five landmarks at their centres (most specific place wins)
##   - every Realm camp stands 10 m+ inside BOUNDS
##   - no stair-era WindowRig under the Realm
## Run: HOME=<scratch> godot --headless --path . res://zz/world_r30_test.tscn
var p: Player
var main: Node
var t := 0
var step := 0
var wait := 0
var fails := 0
var climb_route: Array = []
var climb_i := 0
var climb_t := 0.0
var climb_j := -1.0


func _ready() -> void:
	Travel._busy = true
	Travel.seals_broken.clear()
	Travel.bosses_slain.clear()
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func check(name: String, ok: bool) -> void:
	print("WORLD30 ", "PASS " if ok else "FAIL ", name)
	if not ok:
		fails += 1


func _arena(id: String) -> BossArena:
	for a in get_tree().get_nodes_in_group(&"boss_arena"):
		if (a as BossArena).boss_id == id:
			return a
	return null


func _seal(id: String) -> WardSeal:
	for s in get_tree().get_nodes_in_group(&"ward_seal"):
		if (s as WardSeal).seal_id == id:
			return s
	return null


func _shut(g: Node) -> bool:
	return g != null and is_instance_valid(g) and (g as WardSeal)._body.collision_layer != 0


func _boss() -> Enemy:
	for e in get_tree().get_nodes_in_group(Groups.ENEMY):
		if (e as Node).has_meta(&"boss_id"):
			return e
	return null


func _tp(at: Vector3) -> void:
	p.global_position = at
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()


func _physics_process(_d: float) -> void:
	t += 1
	if t > 60 * 300:
		print("WORLD30 FAIL timeout at step ", step)
		get_tree().quit(1)
		return
	if p == null:
		p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		return
	if wait > 0:
		wait -= 1
		return
	var abbot := _arena("bone_abbot")
	var warden := _arena("ascended_warden")
	match step:
		0:
			if not main.has_meta("realm_done") or abbot == null or warden == null:
				return
			p.set_physics_process(true)
			# static checks
			for id: String in ["chapel", "henge", "barrows", "summit", "glade", "ossuary", "hearth"]:
				var c := Vector2.ZERO
				for r: Dictionary in RealmLayout.REGIONS:
					if r.id == id:
						c = r.c if r.has("c") else (r.rect as Rect2).get_center()
				check("region_at names %s at its centre (got %s)" % [id, RealmLayout.region_at(c.x, c.y).get("id", "")], RealmLayout.region_at(c.x, c.y).get("id", "") == id)
			var inner := RealmLayout.BOUNDS.grow(-10.0)
			for cmp: Dictionary in EnemySpawner.REALM_CAMPS:
				var a: Vector3 = cmp.at
				if not inner.has_point(Vector2(a.x, a.z)):
					check("camp %s 10 m inside BOUNDS" % a, false)
			check("camps 10 m inside BOUNDS", fails == 0)
			if "--suggest" in OS.get_cmdline_user_args():
				_suggest()
			check("no WindowRig under the Realm", main.get_node_or_null("WindowRig") == null)
			for bn in main.find_children("Beacon_*", "", true, false):
				var bm := (bn as Node3D).get_child(0) as MeshInstance3D
				print("WORLD30 beacon %s at %s vis %s in_tree_vis %s range_end %.1f cam_far %.1f" % [bn.name, (bn as Node3D).global_position, (bn as Node3D).visible, bm.is_visible_in_tree(), bm.visibility_range_end, get_viewport().get_camera_3d().far])
			# r34: the places agents add their own beacons; the two boss landmarks must still stand
			check("two landmark beacons (henge, summit)", main.find_child("Beacon_thornwarden", true, false) != null and main.find_child("Beacon_ascended_warden", true, false) != null)
			_tower()
			var lift := main.find_child("ChainLift", true, false)
			check("Ossuary lift held until the Abbot falls", lift != null and bool(lift.get("hold")))
			check("abbot arena has mouth gates", abbot.gate != null and abbot.gate.get("arena_only") == true and abbot.gates.size() == 1)
			check("warden arena has a mouth veil", warden.gate != null and warden.gate.get("arena_only") == true)
			check("arena gates open at rest", not _shut(abbot.gate) and not _shut(abbot.gates[0]) and not _shut(warden.gate))
			check("portcullis shut (guards alive)", _shut(_seal("oss_gallery")))
			check("summit ward shut (guards alive)", _shut(_seal("summit")))
			step = 40                                   # climb the watchtower, then the arenas
		40:
			var tw := main.find_child("Watchtower", true, false)
			if tw == null:
				step = 49
				return
			climb_route = tw.get_meta("route", [])
			var ap: Vector3 = tw.get_meta("approach")
			ap.y = RealmLayout.ground(p.get_world_3d().direct_space_state, ap.x, ap.z) + 0.1
			_tp(ap)
			climb_i = 0
			climb_t = 0.0
			climb_j = -1.0
			step = 41
			wait = 10
		41:
			_climb_tick(1.0 / 60.0)
		49:
			p.debug_drive(Vector3.ZERO)
			Input.action_release("jump")
			# the Abbot (r34: in the pit hall under the bank): step past the raid door's inner grille
			_tp(Ossuary.abbot_pull_at())
			step = 1
			wait = 20
		1:
			check("bone abbot rose", _boss() is BoneAbbot)
			check("raid door's inner grille shut behind", _shut(abbot.gate))
			check("raid door's outer grille shut", _shut(abbot.gates[0]))
			check("portcullis untouched", _shut(_seal("oss_gallery")))
			# run up the stair past the leash: r35, the fight is HELD (it used to reset)
			_tp(Vector3(21.0, Ossuary.GAL_Y + 0.6, -64.0))
			step = 2
			wait = 30
		2:
			check("abbot fight held, not reset", _held("bone_abbot"))
			check("grilles open after the reset", not _shut(abbot.gate) and not _shut(abbot.gates[0]))
			check("portcullis NOT forced open by the reset", _shut(_seal("oss_gallery")))
			_tp(Ossuary.abbot_pull_at())
			step = 3
			wait = 20
		3:
			var b := _boss()
			check("abbot rises again", b is BoneAbbot)
			if b:
				Events.enemy_killed.emit(b)               # the kill itself (bosses gate their phases)
				b.queue_free()
			step = 4
			wait = 30
		4:
			check("abbot slain", Travel.bosses_slain.has("bone_abbot"))
			check("grilles open after the kill", not _shut(abbot.gate) and not _shut(abbot.gates[0]))
			var lift := main.find_child("ChainLift", true, false)
			check("lift released by the Abbot's fall", lift != null and not bool(lift.get("hold")))
			# the Warden (the Thornwarden counted as fallen)
			Travel.bosses_slain["thornwarden"] = true
			_tp(SummitDress.SUMMIT + Vector3(SummitDress.DAIS_C.x, SummitDress.TOP_DECK_Y + 0.45, SummitDress.DAIS_C.y + 4.0))
			step = 5
			wait = 20
		5:
			check("ascended warden rose", _boss() is AscendedWarden)
			check("dais mouth veil shut", _shut(warden.gate))
			check("summit ward untouched", _shut(_seal("summit")))
			_tp(SummitDress.SUMMIT + Vector3(0.0, SummitDress.TOP_DECK_Y + 0.5, 2.0) + Vector3(0, 0, 18.0))
			step = 6
			wait = 30
		6:
			check("warden fight held, not reset", _held("ascended_warden"))
			check("veil open after the reset", not _shut(warden.gate))
			check("summit ward NOT forced open by the reset (guards alive)", _shut(_seal("summit")))
			print("WORLD30 %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
			get_tree().quit(0 if fails == 0 else 1)


## Dev aid: nearest clear camp spot (off sites, off paths, inside BOUNDS-10, 13 m from fires).
func _suggest() -> void:
	for want: Vector2 in [Vector2(96, -64), Vector2(92, -72), Vector2(98, -50)]:
		var best := Vector2.INF
		for r in range(0, 26):
			for k in 24:
				var q := want + Vector2(cos(TAU * k / 24.0), sin(TAU * k / 24.0)) * float(r)
				if not RealmLayout.BOUNDS.grow(-10.5).has_point(q):
					continue
				if not WorldLanes.site_at(q, 2.0).is_empty() or RealmLayout.path_dist(q) < 4.5:
					continue
				var ok := true
				for b in get_tree().get_nodes_in_group(Groups.BRAZIER):
					if Vector2((b as Node3D).global_position.x, (b as Node3D).global_position.z).distance_to(q) < 14.0:
						ok = false
				if ok:
					best = q
					break
			if best != Vector2.INF:
				break
		print("WORLD30 suggest %s -> %s" % [want, best])


## The watchtower climb: every stand point is real ground (a ray finds it within 0.1 m) and each rise
## is above the vault reach and inside the grab reach (Player.VAULT_MAX .. GRAB_MAX).
func _tower() -> void:
	var tw := main.find_child("Watchtower", true, false)
	check("watchtower built", tw != null)
	if tw == null:
		return
	var route: Array = tw.get_meta("route", [])
	var space := p.get_world_3d().direct_space_state
	var prev := RealmLayout.ground(space, (route[0] as Vector3).x, (route[0] as Vector3).z + 0.0)
	var ok := route.size() == 5
	for i in route.size():
		var pt: Vector3 = route[i]
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(pt + Vector3.UP * 3.0, pt + Vector3.DOWN * 1.0, Layers.WORLD))
		var y: float = (hit.position as Vector3).y if not hit.is_empty() else -INF
		var rise := y - prev
		var lo := 0.4 if i == 0 else 1.1
		print("WORLD30 tower step %d at %s: top %.2f rise %.2f" % [i, pt.snapped(Vector3.ONE * 0.1), y, rise])
		if absf(y - pt.y) > 0.12 or rise > 2.25 or rise < lo:
			ok = false
		prev = y
	check("watchtower climb: each rise grabbable, each top standable", ok)


## Drive the real player up the watchtower: walk at the next block, jump when close, hold the stick
## through the hang (the climb finishes it), stand on the top; 6 s a step.
func _climb_tick(dt: float) -> void:
	climb_t += dt
	if climb_i >= climb_route.size():
		check("climbed the watchtower to its top (%.1f m)" % p.global_position.y, true)
		step = 49
		return
	var target: Vector3 = climb_route[climb_i]
	var d := Vector3(target.x - p.global_position.x, 0.0, target.z - p.global_position.z)
	p.debug_drive(d.normalized() if d.length() > 0.25 else Vector3.ZERO)
	if p.is_grounded() and p.global_position.y > target.y - 0.15 and d.length() < 0.9:
		print("WORLD30 climb step %d reached in %.1f s at %s" % [climb_i, climb_t, p.global_position.snapped(Vector3.ONE * 0.01)])
		climb_i += 1
		climb_t = 0.0
		climb_j = -1.0
		Input.action_release("jump")
		return
	if climb_j < 0.0 and p.is_grounded() and p.global_position.y < target.y - 0.5 and d.length() < 2.0:
		Input.action_press("jump")
		climb_j = climb_t
	elif climb_j >= 0.0 and climb_t - climb_j > 0.3:
		Input.action_release("jump")
		if p.is_grounded() and climb_t - climb_j > 1.2:
			climb_j = -1.0                     # landed short: try again
	if "--trace" in OS.get_cmdline_user_args() and climb_i == 4 and int(climb_t * 60.0) % 6 == 0:
		print("WORLD30 trace t=%.2f pos=%s v=%s grounded=%s hang=%s jump=%s" % [climb_t, p.global_position.snapped(Vector3.ONE * 0.01), p.velocity.snapped(Vector3.ONE * 0.01), p.is_grounded(), p.is_hanging(), Input.is_action_pressed("jump")])
	if climb_t > 6.0:
		check("climbed watchtower step %d (stuck at %s, hanging %s)" % [climb_i, p.global_position.snapped(Vector3.ONE * 0.01), p.is_hanging()], false)
		step = 49


## r35: a walk-out holds the fight (BossArena._hold_fight): the arena reports it held, and nothing in
## it is fighting (the boss frozen where it stood).
func _held(id: String) -> bool:
	for a in get_tree().get_nodes_in_group(&"boss_arena"):
		if a is BossArena and (a as BossArena).boss_id == id:
			return (a as BossArena).is_held() and not Player.boss_fight_active(get_tree())
	return false
