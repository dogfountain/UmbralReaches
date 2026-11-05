extends Node
## The henge stair curls round the hill inside the arena's radius: the fight (and its gate) must not
## start until the wanderer is through the trilithon. Walks the built stair (ThornHenge.stair_pts)
## in 0.4 m steps and reports where the arena wakes, relative to the gate line.
## Run: HOME=<scratch> godot --headless --path . res://zz/arena_gate_test.tscn
var p: Player
var t := 0
var pts: Array[Vector3] = []
var i := 0
var hold := 0
var arena: BossArena
var outside_in_radius := 0      ## samples where the old rule (radius only) would have fired outside
var woke_at := -1.0


func _ready() -> void:
	Travel._busy = true
	Travel.bosses_slain.clear()
	var main: Node = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _physics_process(_d: float) -> void:
	t += 1
	if t > 60 * 240:
		print("ARENAGATE FAIL timeout")
		get_tree().quit(1)
		return
	if p == null:
		p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		return
	var main := p.owner if p.owner else p.get_parent()
	if not main.has_meta("summit_dressed"):
		return
	if arena == null:
		for a in get_tree().get_nodes_in_group(&"boss_arena"):
			if (a as BossArena).boss_id == "thornwarden":
				arena = a
		var h := main.find_child("ThornHenge", true, false)
		if arena == null or h == null:
			print("ARENAGATE FAIL no henge arena")
			get_tree().quit(1)
			return
		for e in get_tree().get_nodes_in_group(Groups.ENEMY):
			(e as Node).queue_free()
		var sp: Array = h.get("stair_pts")
		for k in range(sp.size() - 1):
			var a: Vector3 = sp[k]
			var b: Vector3 = sp[k + 1]
			var n := maxi(1, int(a.distance_to(b) / 0.4))
			for j in n:
				pts.append(a.lerp(b, float(j) / float(n)))
		pts.append(sp[sp.size() - 1])
		print("ARENAGATE stair samples %d, arena r %.1f, gate %s" % [pts.size(), arena.radius, arena.gate.global_position.snapped(Vector3.ONE * 0.1) if arena.gate else "none"])
		return
	if hold > 0:
		hold -= 1
		return
	if bool(arena.get("_active")):
		woke_at = _past(p.global_position)
		print("ARENAGATE woke at sample %d/%d, %.2f m past the gate line" % [i, pts.size(), woke_at])
		_finish()
		return
	if i >= pts.size():
		print("ARENAGATE walked the whole stair without waking (end %s)" % p.global_position.snapped(Vector3.ONE * 0.1))
		_finish()
		return
	var at := pts[i]
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 3.0, at + Vector3.DOWN * 3.0, Layers.WORLD)
	q.exclude = [p.get_rid()]
	var g := p.get_world_3d().direct_space_state.intersect_ray(q)
	var pos := ((g.position as Vector3) if not g.is_empty() else at) + Vector3.UP * 0.1
	p.teleport(pos)
	var d := pos - arena.global_position
	if Vector2(d.x, d.z).length() <= arena.radius and d.y >= -1.0 and _past(pos) <= 0.0:
		outside_in_radius += 1
	i += 1
	hold = 3


func _past(at: Vector3) -> float:
	if arena.gate == null:
		return 99.0
	var g := arena.gate.global_position
	var inward := arena.global_position - g
	inward.y = 0.0
	var rel := at - g
	rel.y = 0.0
	return rel.dot(inward.normalized())


func _finish() -> void:
	print("ARENAGATE stair samples outside the gate but inside the old radius: %d" % outside_in_radius)
	var ok := woke_at >= BossArena.GATE_CLEAR - 0.05
	print("ARENAGATE %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
