extends Node
## r30 enemy AI: (1) an idle wretch shot from beyond its wake range turns and hunts, and its idle
## packmate wakes with it; (2) a chaser with a wall across the straight line goes round it.
## Run: HOME=<scratch> godot --headless --path . res://zz/enemy_ai_test.tscn
const AT := Vector3(-24.0, 0.0, 60.0)     ## open ground outside every sanctuary light
var p: Player
var t := 0
var phase := 0
var t0 := 0
var a: Enemy
var b: Enemy
var c: Enemy
var wall: StaticBody3D
var start_d := 0.0
var fails := 0


func _ready() -> void:
	Travel._busy = true
	var main: Node = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _gy(x: float, z: float) -> float:
	return RealmLayout.ground(p.get_world_3d().direct_space_state, x, z)


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
			var enc := main.find_child("Encounters", true, false)
			if enc:
				enc.process_mode = Node.PROCESS_MODE_DISABLED
			for n in get_tree().get_nodes_in_group(Groups.ENEMY):
				(n as Node).queue_free()
			p.teleport(Vector3(AT.x + 20.0, _gy(AT.x + 20.0, AT.z) + 0.3, AT.z))
			a = _spawn("res://core/enemy/wretch.gd", AT)
			b = _spawn("res://core/enemy/wretch.gd", AT + Vector3(-3.0, 0.0, 4.0))
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
				# a 7 m wall square across the line, the player 6 m on the far side
				var mid := AT + Vector3(-30.0, 0.0, 0.0)
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
			if t - t0 == 5 + 60 * 7:
				var dd := c.global_position.distance_to(p.global_position)
				check("rounds a wall to reach the player", dd < 4.0, "%.1f m from the player after 7 s" % dd)
				print("ENEMYAI %s" % ("PASS" if fails == 0 else "FAIL"))
				get_tree().quit(0 if fails == 0 else 1)
