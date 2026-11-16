extends Node
## r30 enemy AI: (1) an idle wretch shot from beyond its wake range turns and hunts, and its idle
## packmate wakes with it; (2) a chaser with a wall across the straight line goes round it.
## Run: HOME=<scratch> godot --headless --path . res://zz/enemy_ai_test.tscn
##
## The test finds its own ground and checks it is still open before it fights there: the first of SPOTS whose strip
## (x from STRIP_W to STRIP_E of the spot, STRIP_HALF either side; both checks run on it) is open, flat and unlit.
## On a 1 m grid the first thing straight down is the terrain itself (no prop, rock, wall or deck), nothing on
## WORLD or PROPS lies between neighbouring points at knee or chest height, and the heights stay within MAX_RISE;
## every 2 m the floor passes the spawn rules' ground checks (room for a body, no lip, no water, not steep, not in
## a town's ring) and no light reaches within 8 m. The old fixed spot (-24, 60) rotted when the Realm doubled:
## Hearthward's south cottage stands beside the line now, and the first wretch snagged on it. A spot that fails is
## skipped (the log says why); if none is open the test fails: add a fresh candidate rather than loosen the check.
## Found by scanning the Realm on a 5 m grid (16 Nov: 72 of 14,560 strips passed), one from each of six clusters,
## nearest the hub first.
const SPOTS: Array[Vector2] = [Vector2(29.0, 94.0), Vector2(79.0, 59.0), Vector2(-116.0, 74.0), Vector2(184.0, 204.0), Vector2(304.0, -1.0), Vector2(204.0, -131.0)]
const STRIP_W := -6.0                     ## behind the packmate (3 m west of the spot)
const STRIP_E := 24.0                     ## past the first wanderer (20 m east of the spot)
const STRIP_HALF := 6.0
const WALL_X := 8.0                       ## the wall check's wall, east of the spot: its chaser 4 m west, the wanderer 6 m east
const MAX_RISE := 2.0
const SpawnRules := preload("res://core/life/encounters/spawn_rules.gd")
var spot := Vector3.INF                   ## the spot in use (set in phase 0)
var p: Player
var t := 0
var phase := 0
var t0 := 0
var a: Enemy
var b: Enemy
var c: Enemy
var wall: StaticBody3D
var start_d := 0.0
var best_d := INF                           ## r34: closest c came to the player in the 7 s (not only the last frame)
var fails := 0


func _ready() -> void:
	Travel._busy = true
	var main: Node = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _gy(x: float, z: float) -> float:
	return RealmLayout.ground(p.get_world_3d().direct_space_state, x, z)


## "" when the strip round `c` is open, flat and unlit (see the header), else why not.
func _strip_open(c: Vector2) -> String:
	var space := p.get_world_3d().direct_space_state
	var nx := int(STRIP_E - STRIP_W) + 1
	var nz := int(STRIP_HALF * 2.0) + 1
	var pts := PackedVector3Array()
	var lo := INF
	var hi := -INF
	for iz in nz:
		for ix in nx:
			var at := Vector2(c.x + STRIP_W + ix, c.y - STRIP_HALF + iz)
			var down := PhysicsRayQueryParameters3D.create(Vector3(at.x + 0.0037, 90.0, at.y + 0.0029), Vector3(at.x + 0.0037, -60.0, at.y + 0.0029), Layers.WORLD | Layers.PROPS)
			var skip: Array[RID] = [p.get_rid()]
			var hit := {}
			for k in 4:                                       # a foe or a deer standing there is not the floor
				down.exclude = skip
				hit = space.intersect_ray(down)
				if hit.is_empty() or not (hit.collider is CharacterBody3D):
					break
				skip.append(hit.rid)
			var n := hit.get("collider") as Node
			if n == null or not String(n.name).begins_with("Terrain"):
				return "%s: the floor is %s" % [at, n.get_path() if n else "missing"]
			var g: Vector3 = hit.position
			if ix % 2 == 0 and iz % 2 == 0:
				var rules := SpawnRules.assess(space, g, {"ways": false})
				if not bool(rules.ok):
					return "%s: %s" % [at, rules.why]
				if LightGrid.repel(g, 8.0) != Vector3.ZERO:
					return "%s: a light within 8 m" % at
			for j: int in [pts.size() - 1 if ix > 0 else -1, pts.size() - nx]:      # the neighbours west and south
				if j < 0:
					continue
				for h: float in [0.45, 1.3]:
					var q := PhysicsRayQueryParameters3D.create(pts[j] + Vector3.UP * h, g + Vector3.UP * h, Layers.WORLD | Layers.PROPS)
					q.exclude = skip
					var o := space.intersect_ray(q).get("collider") as Node
					if o != null and not String(o.name).begins_with("Terrain") and not (o is CharacterBody3D):
						return "%s: %s across the strip" % [at, o.get_path()]
			lo = minf(lo, g.y)
			hi = maxf(hi, g.y)
			pts.append(g)
	if hi - lo > MAX_RISE:
		return "not flat (%.1f m)" % (hi - lo)
	return ""


func _spawn(path: String, at: Vector3) -> Enemy:
	var e := (load(path) as GDScript).new() as Enemy
	p.get_parent().add_child(e)
	e.global_position = Vector3(at.x, _gy(at.x, at.z) + 0.1, at.z)
	e.home = e.global_position
	e.wake()
	return e


func check(name: String, ok: bool, detail := "") -> void:
	print("ENEMYAI %s %s %s" % ["PASS" if ok else "FAIL", name, detail])
	if not ok:
		fails += 1


func _physics_process(_d: float) -> void:
	t += 1
	if t > 60 * 300:
		print("ENEMYAI FAIL timeout")
		get_tree().quit(1)
		return
	if p == null:
		p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		return
	var main := p.owner if p.owner else p.get_parent()
	if not main.has_meta("summit_dressed"):
		return
	match phase:
		0:
			for c: Vector2 in SPOTS:
				var why := _strip_open(c)
				if why == "":
					spot = Vector3(c.x, 0.0, c.y)
					break
				print("ENEMYAI spot %s skipped: %s" % [c, why])
			if spot == Vector3.INF:
				check("an open, flat, unlit strip to test on", false, "none of %d spots is open: add a fresh one to SPOTS" % SPOTS.size())
				get_tree().quit(1)
				return
			print("ENEMYAI testing at %s" % Vector2(spot.x, spot.z))
			var enc := main.find_child("Encounters", true, false)
			if enc:
				enc.process_mode = Node.PROCESS_MODE_DISABLED
			# r34 enemies: the flake in "rounds a wall" was the world's own foes -- a named rare (it
			# wakes within 95 m) and respawning camps walked in, took the attack turns and knocked the
			# player about, so the wretch waited in the ring instead of closing. The test owns its foes.
			for n: String in ["EnemySpawner", "Rares"]:
				var sv := main.find_child(n, true, false)
				if sv:
					sv.process_mode = Node.PROCESS_MODE_DISABLED
			for n in get_tree().get_nodes_in_group(Groups.ENEMY):
				(n as Node).queue_free()
			p.teleport(Vector3(spot.x + 20.0, _gy(spot.x + 20.0, spot.z) + 0.3, spot.z))
			a = _spawn("res://core/enemy/wretch.gd", spot)
			b = _spawn("res://core/enemy/wretch.gd", spot + Vector3(-3.0, 0.0, 4.0))
			phase = 1
			t0 = t
		1:
			if t - t0 == 30:
				start_d = a.global_position.distance_to(p.global_position)
				a.take_hit(0.5, p)                      # a bolt from 20 m
			if t - t0 == 30 + 60 * 3:
				var now := a.global_position.distance_to(p.global_position)
				check("shot from range, it hunts", now < start_d - 4.0, "%.1f m -> %.1f m" % [start_d, now])
				check("its idle packmate wakes", int(b.get("_state")) != 0, "state %d" % int(b.get("_state")))
				a.queue_free()
				b.queue_free()
				phase = 2
				t0 = t
		2:
			if t - t0 == 5:
				# a 7 m wall square across the line, the player 6 m on the far side (the first check's ground)
				var mid := spot + Vector3(WALL_X, 0.0, 0.0)
				var y := _gy(mid.x, mid.z)
				wall = StaticBody3D.new()
				wall.collision_layer = Layers.WORLD
				var cs := CollisionShape3D.new()
				var bx := BoxShape3D.new()
				bx.size = Vector3(0.6, 3.0, 7.0)
				cs.shape = bx
				wall.add_child(cs)
				main.add_child(wall)
				wall.global_position = Vector3(mid.x, y + 1.5, mid.z)
				p.teleport(Vector3(mid.x + 6.0, _gy(mid.x + 6.0, mid.z) + 0.3, mid.z))
				c = _spawn("res://core/enemy/wretch.gd", mid + Vector3(-4.0, 0.0, 0.0))
				c.set("chase_range", 20.0)
				for n in get_tree().get_nodes_in_group(Groups.ENEMY):
					if n != c:
						(n as Node).queue_free()
			if t - t0 > 5 and is_instance_valid(c):
				best_d = minf(best_d, c.global_position.distance_to(p.global_position))
			if t - t0 == 5 + 60 * 7:
				var dd := c.global_position.distance_to(p.global_position)
				var past := c.global_position.x > wall.global_position.x + 0.4
				check("rounds a wall to reach the player", best_d < 4.0 and past, "%.1f m now, closest %.1f m, past the wall %s" % [dd, best_d, past])
				print("ENEMYAI %s" % ("PASS" if fails == 0 else "FAIL"))
				get_tree().quit(0 if fails == 0 else 1)
