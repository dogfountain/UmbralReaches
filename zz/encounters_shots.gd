extends Node
## Encounters renders through the real player camera (grade, fog, moonlight, the lantern):
##   godot --path . res://zz/encounters_shots.tscn -- --fresh --set=elites|variants|tide [--at=x,z] [--yaw=deg]
##   elites    each named elite in turn, 4 m in front of the wanderer -> shots/encounters/elite_<id>.png
##   variants  a wretch, a husk and a leaper in each variant, side by side -> shots/encounters/var_<v>.png
##   tide      a Gloom tide forced where you stand; frames as the hunters close -> shots/encounters/tide_<i>.png
const Elites := preload("res://core/life/encounters/elites.gd")
const Variants := preload("res://core/life/encounters/variants.gd")
const Tiers := preload("res://core/life/encounters/tiers.gd")

var at := Vector2(62.0, 4.0)
var yaw := 0.0
var set_name := "elites"
var umbral := false
var p: Player
var main: Node
var d: Node


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var v := a.split("=")
		if v.size() < 2: continue
		match v[0]:
			"--at": at = Vector2(float(v[1].split(",")[0]), float(v[1].split(",")[1]))
			"--yaw": yaw = deg_to_rad(float(v[1]))
			"--set": set_name = v[1]
			"--umbral": umbral = v[1] == "1"
	Travel._busy = true                                 # no save writes from this tool
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/encounters"))
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ground(x: float, z: float) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, 90, z), Vector3(x, -40, z), Layers.WORLD)
	var h := p.get_world_3d().direct_space_state.intersect_ray(q)
	return (h.position as Vector3) if h else Vector3(x, 2.0, z)


func _shot(n: String) -> void:
	await _frames(2)
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://shots/encounters/%s.png" % n))
	print("ENCSHOT saved ", n)


func _run() -> void:
	while true:
		await get_tree().process_frame
		p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		if p and main.has_meta("realm_done") and main.get_node_or_null("Encounters") and bool(main.get_node("Encounters").get("ready_done")):
			break
	d = main.get_node("Encounters")
	d.set("ready_done", false)                         # the director only moves when we step it
	await _frames(30)
	var g := _ground(at.x, at.y)
	p.global_position = g + Vector3.UP * 0.3
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()
	p.set_view(yaw, -0.1)
	_clear()
	for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if c.name != "Grade" and c.name != "EncounterHud":
			(c as CanvasLayer).visible = false
	await _frames(20)
	var fwd := Basis(Vector3.UP, yaw) * Vector3.FORWARD
	var right := Basis(Vector3.UP, yaw) * Vector3.RIGHT
	match set_name:
		"elites":
			for id: String in Elites.ELITES:
				_clear()
				p.gloom = 0.0
				var e := (load(String(Elites.ELITES[id].script)) as GDScript).new() as Enemy
				if umbral:
					e.set_meta(&"enc_umbral", true)
				main.add_child(e)
				var spot := _ground(g.x + fwd.x * 4.2, g.z + fwd.z * 4.2)
				e.global_position = spot + Vector3.UP * 0.05
				e.look_at(Vector3(g.x, e.global_position.y, g.z), Vector3.UP)
				e.rotate_y(0.4)
				await _frames(40)
				e.sleep()
				_close_cam(e, -fwd)
				await _frames(8)
				await _shot("elite_%s%s" % [id, "_umbral" if umbral else ""])
				e.queue_free()
			if _cam:
				_cam.queue_free()
				_cam = null
		"variants":
			for v: String in ["plain", "scarred", "ironclad", "tideborn", "deeper"]:
				_clear()
				var row := ["wretch", "husk", "leaper"]
				for i in row.size():
					var e := Tiers.script_for(row[i]).new() as Enemy
					if v != "plain":
						Variants.pre(e, v)
					main.add_child(e)
					if v != "plain":
						Variants.dress(e, v)
					var spot := _ground(g.x + fwd.x * 4.6 + right.x * (float(i) - 1.0) * 1.9, g.z + fwd.z * 4.6 + right.z * (float(i) - 1.0) * 1.9)
					e.global_position = spot + Vector3.UP * 0.05
					e.look_at(Vector3(g.x, e.global_position.y, g.z), Vector3.UP)
					e.rotate_y(0.5)
				await _frames(40)
				var mid: Enemy = null
				for e in get_tree().get_nodes_in_group(Groups.ENEMY):
					(e as Enemy).sleep()
					if e is Husk:
						mid = e
				if mid:
					_close_cam(mid, -fwd, 2.2)
				await _frames(6)
				await _shot("var_%s" % v)
		"tide":
			p.set_view(yaw, -0.02)
			d.set("tide_clock", float(d.call("tide_period")) + 1.0)
			d.call("step", 0.3)
			d.call("step", 0.3)
			var hunters: Array = d.get("hunters")
			# bring the pack round in front of the camera (they spawn all round), 12-16 m out
			for i in hunters.size():
				var h := hunters[i] as Enemy
				var spot := _ground(g.x + fwd.x * (12.0 + 2.0 * float(i)) + right.x * (float(i) - 1.0) * 3.5, g.z + fwd.z * (12.0 + 2.0 * float(i)) + right.z * (float(i) - 1.0) * 3.5)
				h.global_position = spot + Vector3.UP * 0.05
			print("ENCSHOT tide hunters ", hunters.size())
			for i in 6:
				p.gloom = 0.0
				for k in 50:
					await get_tree().process_frame
					p.global_position = g + Vector3.UP * 0.3      # hold still: the pack comes to us
					p.velocity = Vector3.ZERO
					d.call("step", 0.02)
				await _shot("tide_%d" % i)
	print("ENCSHOT done")
	get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
	OS.kill(OS.get_process_id())


var _cam: Camera3D


## A close camera on `e` from direction `dir`, the wanderer just behind it so the lantern lights it.
func _close_cam(e: Enemy, dir: Vector3, extra := 0.0) -> void:
	if _cam == null:
		_cam = Camera3D.new()
		_cam.fov = 50.0
		_cam.far = 300.0
		get_tree().root.add_child(_cam)
	var h := e.hp_bar_y
	var dist := 1.6 + h * 1.15 + extra
	var side := Vector3(-dir.z, 0, dir.x)
	_cam.global_position = e.global_position + dir * dist + side * 0.6 + Vector3.UP * (h * 0.62 + 0.35)
	_cam.look_at(e.global_position + Vector3.UP * h * 0.5, Vector3.UP)
	_cam.current = true
	p.global_position = _cam.global_position + dir * 0.9 - Vector3.UP * (h * 0.62)
	p.velocity = Vector3.ZERO


func _clear() -> void:
	for e in get_tree().get_nodes_in_group(Groups.ENEMY):
		(e as Node).queue_free()
