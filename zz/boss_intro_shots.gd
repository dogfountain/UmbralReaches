extends Node
## The boss rising, through the real player camera and HUD (windowed; headless cannot render).
##   godot --path . res://zz/boss_intro_shots.tscn -- --id=thornwarden --out=<dir>
## Teleports the wanderer to just inside the arena's gate (the pull), then saves a frame at fixed
## seconds after the boss appears: the rise, the title, the roar, control coming back.
const TIMES: Array[float] = [0.2, 0.9, 1.8, 2.8, 3.8, 5.0]
var main: Node
var p: Player
var id := "thornwarden"
var out := "/tmp/boss_intro"
var arena: BossArena
var t := -1.0
var ti := 0
var frames := 0
var placed := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Travel._busy = true
	Travel.bosses_slain.clear()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--id="):
			id = a.trim_prefix("--id=")
		elif a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	get_window().size = Vector2i(1600, 900)
	DirAccess.make_dir_recursive_absolute(out)
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _process(delta: float) -> void:
	frames += 1
	if p == null:
		p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		return
	p.gloom = 0.0
	p.wounds = 0.0
	if not placed:
		if frames < 600 or not main.has_meta("realm_done"):
			return
		for a in get_tree().get_nodes_in_group(&"boss_arena"):
			if (a as BossArena).boss_id == id:
				arena = a as BossArena
		if arena == null:
			print("BFAIL no arena ", id)
			get_tree().quit()
			return
		for e in get_tree().get_nodes_in_group(Groups.ENEMY):
			(e as Node).queue_free()
		var g: Vector3 = arena.gate.global_position if arena.gate != null else arena.global_position + Vector3(0, 0, 20)
		if id == "r37_anchoress":                                  # no gate node: the raid's own gate point
			var rg: Vector2 = RealmLayout.raid("anchorhold").gate
			g = Vector3(rg.x, arena.global_position.y, rg.y)
		var inward := arena.global_position - g
		inward.y = 0.0
		inward = inward.normalized()
		var at := g + inward * 3.2
		var q := PhysicsRayQueryParameters3D.create(Vector3(at.x, arena.global_position.y + 6.0, at.z), at + Vector3.DOWN * 30.0, Layers.WORLD)
		var h := p.get_world_3d().direct_space_state.intersect_ray(q)
		p.global_position = (h.position if h else at) + Vector3.UP * 0.3
		p.velocity = Vector3.ZERO
		p.reset_physics_interpolation()
		p.set_view(atan2(-inward.x, -inward.z) + 0.5, -0.18)      # the view is not already on him
		placed = true
		print("BSHOT placed at ", p.global_position, " arena ", arena.global_position)
		return
	if t < 0.0:
		if arena.get("_active") == true:
			t = 0.0
			print("BSHOT engaged, boss at ", (arena.get("_boss") as Node3D).global_position)
		elif frames > 1500:
			print("BFAIL never engaged")
			get_tree().quit()
		return
	t += delta
	if ti < TIMES.size() and t >= TIMES[ti]:
		get_viewport().get_texture().get_image().save_png(out.path_join("%s_%d.png" % [id, ti]))
		print("BSHOT frame ", ti, " yaw ", p._yaw)
		ti += 1
	if ti >= TIMES.size():
		print("BOSSINTRO done")
		get_tree().quit()
