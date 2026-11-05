extends Node3D
## Script cost of the wanderer, A/B: the same scripted run (idle, walk, sprint, stops, turns,
## a jump) driven twice in a flat studio, once with the current player.gd + character_rig.gd and
## once with another pair (--old=<dir> holding old_player.gd / old_rig.gd, class_name stripped),
## timing every Player._physics_process and _process call (the engine's own calls are switched
## off; this node calls them). Prints "MOVECOST <variant> physics x.xxx ms process x.xxx ms".
##   godot --headless --path . res://zz/move_cost.tscn -- [--old=/abs/dir] [--rounds=3]
const RUN := [[0.0, Vector3.ZERO, false], [1.0, Vector3(0, 0, -1), false], [3.0, Vector3(0, 0, -1), true],
	[5.0, Vector3(1, 0, 0), true], [6.0, Vector3.ZERO, false], [7.0, Vector3(-1, 0, 1), false], [9.0, Vector3.ZERO, false]]
const LEN := 10.0
var variants: Array = []          ## [name, player script, rig script]
var vi := 0
var p: Node
var t := 0.0
var ri := 0
var phys := 0
var proc := 0
var n_phys := 0
var n_proc := 0
var results := {}
var rounds := 3
var round_i := 0


func _ready() -> void:
	Travel._busy = true
	var old := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--old="):
			old = a.trim_prefix("--old=")
		elif a.begins_with("--rounds="):
			rounds = int(a.trim_prefix("--rounds="))
	var b := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(200, 1, 200)
	cs.shape = sh
	b.add_child(cs)
	b.position.y = -0.5
	add_child(b)
	variants.append(["new", load("res://core/player/player.gd"), load("res://core/player/character_rig.gd")])
	if old != "":
		variants.append(["old", load(old.path_join("old_player.gd")), load(old.path_join("old_rig.gd"))])
	_spawn()


func _spawn() -> void:
	var v: Array = variants[vi]
	var pl := CharacterBody3D.new()
	pl.name = "Player"
	pl.set_script(v[1])
	var col := CollisionShape3D.new()
	col.name = "Collision"
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.7
	col.shape = cap
	col.position.y = 0.85
	pl.add_child(col)
	var vis := Node3D.new()
	vis.name = "Visual"
	vis.set_script(v[2])
	pl.add_child(vis)
	var rig := Node3D.new()
	rig.name = "CameraRig"
	rig.position.y = 1.55
	pl.add_child(rig)
	var pitch := Node3D.new()
	pitch.name = "Pitch"
	rig.add_child(pitch)
	var arm := SpringArm3D.new()
	arm.name = "SpringArm"
	pitch.add_child(arm)
	var cam := Camera3D.new()
	cam.name = "Camera"
	arm.add_child(cam)
	pl.position = Vector3(0, 0.05, 0)
	add_child(pl)
	pl.set_physics_process(false)
	pl.set_process(false)
	p = pl
	t = -0.5
	ri = 0
	phys = 0
	proc = 0
	n_phys = 0
	n_proc = 0


func _physics_process(delta: float) -> void:
	if p == null:
		return
	t += delta
	if t >= 0.0:
		while ri < RUN.size() and t >= float(RUN[ri][0]):
			p.call("debug_drive", RUN[ri][1], RUN[ri][2])
			ri += 1
		if absf(t - 4.0) < delta * 0.5:
			Input.action_press("jump")
		elif absf(t - 4.2) < delta * 0.5:
			Input.action_release("jump")
	var t0 := Time.get_ticks_usec()
	p.call("_physics_process", delta)
	if t >= 0.0:
		phys += Time.get_ticks_usec() - t0
		n_phys += 1
	if t >= LEN:
		var key: String = variants[vi][0]
		var r: Array = results.get(key, [])
		r.append(Vector2(phys * 0.001 / maxf(n_phys, 1), proc * 0.001 / maxf(n_proc, 1)))
		results[key] = r
		p.queue_free()
		p = null
		vi += 1
		if vi >= variants.size():
			vi = 0
			round_i += 1
		if round_i >= rounds:
			for k: String in results:
				var ph := PackedFloat32Array()
				var pr := PackedFloat32Array()
				for x: Vector2 in results[k]:
					ph.append(x.x)
					pr.append(x.y)
				ph.sort()
				pr.sort()
				print("MOVECOST %s physics %.3f ms process %.3f ms (median of %d)" % [k, ph[ph.size() / 2], pr[pr.size() / 2], ph.size()])
			get_tree().quit()
			return
		_spawn.call_deferred()


func _process(delta: float) -> void:
	if p == null or t < 0.0:
		return
	var t0 := Time.get_ticks_usec()
	p.call("_process", delta)
	var rig := p.get_node("Visual")
	rig.call("_process", delta)
	proc += Time.get_ticks_usec() - t0
	n_proc += 1
