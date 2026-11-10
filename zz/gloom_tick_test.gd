extends Node
## The Gloom's clock keeps running whatever the wanderer is doing: standing in open dark, and
## hanging from a ledge (a branch of Player._physics_process that returns early).
##   godot --headless --path . res://zz/gloom_tick_test.tscn     (tools/run_tests.sh gloom_tick)
## The hang is a real one: a slab on the world layer in open dark, the wanderer let fall beside its
## face at grab height with the stick held toward it, so Traversal._try_grab catches the lip.
## Ends: GLOOM TICK TEST PASS  /  GLOOM TICK TEST FAIL n

var fails := 0
var main: Node
var p: Player
var _sweep_t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Travel.set("_busy", true)
	await _load_world()
	if p == null:
		fails += 1
		print("GLOOMTICK FAIL no player")
	else:
		var spot := _dark_spot()
		if spot == Vector3.INF:
			fails += 1
			print("GLOOMTICK FAIL no dark open ground found")
		else:
			await _standing(spot)
			await _hanging(spot)
	print("GLOOM TICK TEST %s" % ("PASS" if fails == 0 else "FAIL %d" % fails))
	Travel.set("_busy", true)
	get_tree().quit(0 if fails == 0 else 1)


func _process(delta: float) -> void:
	_sweep_t += delta
	if _sweep_t > 0.5:
		_sweep_t = 0.0
		for e in get_tree().get_nodes_in_group(Groups.ENEMY):
			(e as Node).queue_free()


func _load_world() -> void:
	main = (load("res://world/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 90000:
		await get_tree().process_frame
		if main.has_meta("realm_done"):
			break
	for i in 30:
		await get_tree().physics_frame
	p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
	for e in get_tree().get_nodes_in_group(Groups.ENEMY):
		(e as Node).queue_free()
	await get_tree().create_timer(0.7).timeout


## Open ground out of every fire's reach, on the Pilgrims' Road side of the Realm.
func _dark_spot() -> Vector3:
	var space := p.get_world_3d().direct_space_state
	for xz: Vector2 in [Vector2(62, 60), Vector2(70, 66), Vector2(56, 70), Vector2(80, 55), Vector2(90, 80), Vector2(50, 90)]:
		var y := RealmLayout.ground(space, xz.x, xz.y)
		var at := Vector3(xz.x, y, xz.y)
		if LightGrid.drain_at(at) == 0.0 and LightGrid.drain_at(at + Vector3.UP * 3.0) == 0.0:
			return at
	return Vector3.INF


func _standing(spot: Vector3) -> void:
	p.teleport(spot + Vector3.UP * 0.3)
	for i in 40:
		await get_tree().physics_frame
	p.gloom = 20.0
	var g0 := p.gloom
	await get_tree().create_timer(2.0).timeout
	if p.gloom > g0 and LightGrid.drain_at(p.global_position) == 0.0:
		print("GLOOMTICK ok standing (%.2f -> %.2f)" % [g0, p.gloom])
	else:
		fails += 1
		print("GLOOMTICK FAIL standing (%.2f -> %.2f, drain %.2f)" % [g0, p.gloom, LightGrid.drain_at(p.global_position)])


func _hanging(spot: Vector3) -> void:
	# A slab 4 m wide, 3 m tall, its +Z face toward the wanderer; the lip is the ledge to catch.
	var slab := StaticBody3D.new()
	slab.collision_layer = Layers.WORLD
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.0, 3.0, 4.0)
	shape.shape = box
	slab.add_child(shape)
	add_child(slab)
	var base := spot + Vector3(0.0, 0.0, -8.0)
	var space := p.get_world_3d().direct_space_state
	base.y = RealmLayout.ground(space, base.x, base.z)
	slab.global_position = base + Vector3(0.0, 1.4, 0.0)          # top 0.1 m above base + 3.0
	var top := slab.global_position.y + 1.5
	await get_tree().physics_frame
	# in the air with the lip 1.7 m above the feet and 0.9 m off the face, falling toward it
	var face_z := slab.global_position.z + 2.0
	p.teleport(Vector3(base.x, top - 1.7, face_z + 0.9))
	p.set_view(atan2(0.0, -1.0), -0.2)
	var toward := Vector3(0.0, 0.0, -1.0)
	var got := false
	for i in 90:
		p.debug_drive(toward)
		await get_tree().physics_frame
		if p._hang:
			got = true
			break
	p.debug_drive(Vector3.ZERO)
	if not got:
		fails += 1
		print("GLOOMTICK FAIL hanging (no hang caught; pos %s, lip %.2f)" % [p.global_position.snapped(Vector3.ONE * 0.01), top])
		slab.queue_free()
		return
	var drain := LightGrid.drain_at(p.global_position)
	p.gloom = 20.0
	var g0 := p.gloom
	var t := 0.0
	var held := true
	while t < 2.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		if not p._hang:
			held = false
			break
	if drain == 0.0 and held and p._hang and p.gloom > g0:
		print("GLOOMTICK ok hanging (%.2f -> %.2f)" % [g0, p.gloom])
	else:
		fails += 1
		print("GLOOMTICK FAIL hanging (hang %s held %s drain %.2f gloom %.2f -> %.2f)" % [p._hang, held, drain, g0, p.gloom])
	# a wanderer who falls through the world while hanging is caught all the same
	if p._hang:
		p.global_position.y = -50.0
		await get_tree().create_timer(0.5).timeout
		if p.global_position.y > -40.0 and not p._hang:
			print("GLOOMTICK ok rescued while hanging")
		else:
			fails += 1
			print("GLOOMTICK FAIL rescued while hanging (y %.1f, hang %s)" % [p.global_position.y, p._hang])
	else:
		fails += 1
		print("GLOOMTICK FAIL rescued while hanging (not hanging to begin with)")
	slab.queue_free()
