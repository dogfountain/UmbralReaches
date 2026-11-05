extends Node
## r29 (agent A): how combat colours survive the night grade, through the real player camera.
## A row of ground telegraphs and enemy health bars in candidate colours, in the world.
##   godot --path . res://zz/critA_color_shot.tscn [-- --at=x,z --yaw=deg --name=n]
## -> shots/critA_color_<name>_0.png (fills a third in) and _1.png (fills full, pulsing). Quits itself.

const DANGERS := [Color(2.6, 0.55, 0.1), Color(2.6, 0.5, 0.1), Color(2.6, 0.62, 0.1), Color(0.75, 1.9, 0.45), Color(1.4, 0.6, 2.6)]
const BARS := [Color(0.92, 0.36, 0.12), Color(0.92, 0.36, 0.12), Color(0.92, 0.36, 0.12), Color(0.92, 0.36, 0.12)]
var at := Vector2(58.0, 18.0)
var yaw := 0.0
var nm := "row"
var p: Player
var main: Node
var frames := 0
var t := -1.0
var shot := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var v := a.split("=")
		if v.size() < 2:
			continue
		match v[0]:
			"--at":
				var c := v[1].split(",")
				at = Vector2(float(c[0]), float(c[1]))
			"--yaw": yaw = deg_to_rad(float(v[1]))
			"--name": nm = v[1]
	Travel._busy = true
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	get_tree().create_timer(120.0, true, false, true).timeout.connect(func() -> void:
		print("COLOR timeout")
		get_tree().quit(2))


func _physics_process(_d: float) -> void:
	frames += 1
	if p == null:
		p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		return
	p.gloom = 0.0
	if t < 0.0:
		if frames < 90 or not main.has_meta("summit_dressed"):
			return
		var space := p.get_world_3d().direct_space_state
		var h := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(at.x, 90, at.y), Vector3(at.x, -40, at.y), Layers.WORLD))
		var ground: Vector3 = h.position if h else Vector3(at.x, 2.0, at.y)
		p.global_position = ground + Vector3.UP * 0.3
		p.velocity = Vector3.ZERO
		p.reset_physics_interpolation()
		p.set_view(yaw, -0.42)
		for e in get_tree().get_nodes_in_group(Groups.ENEMY):
			(e as Node).queue_free()
		for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
			if c.name != "Grade":
				(c as CanvasLayer).visible = false
		var fwd := Basis(Vector3.UP, yaw) * Vector3.FORWARD
		var side := fwd.cross(Vector3.UP)
		for i in DANGERS.size() * 2:
			var row := float(i / DANGERS.size())
			var spot := ground + fwd * (2.2 + row * 4.6) + side * (float(i % DANGERS.size()) - 2.0) * 2.3
			var hq := space.intersect_ray(PhysicsRayQueryParameters3D.create(spot + Vector3.UP * 10.0, spot + Vector3.DOWN * 10.0, Layers.WORLD))
			if hq:
				spot = hq.position
			SpellFx.danger(spot, 3.0, {"radius": 1.05, "color": DANGERS[i % DANGERS.size()], "hold": 10.0})
		SpellFx.danger(ground, 3.0, {"radius": 1.6, "half_angle": deg_to_rad(70.0), "yaw": yaw + PI, "hold": 10.0})
		var shader := load("res://core/enemy/health_bar.gdshader") as Shader
		for i in BARS.size():
			var m := ShaderMaterial.new()
			m.shader = shader
			m.set_shader_parameter(&"fill_col", BARS[i])
			var q := QuadMesh.new()
			q.material = m
			var mi := MeshInstance3D.new()
			mi.mesh = q
			main.add_child(mi)
			mi.global_position = ground + fwd * 4.5 + side * (float(i) - 1.5) * 1.1 + Vector3.UP * 1.9
			mi.set_instance_shader_parameter(&"fill", 0.66)
			mi.set_instance_shader_parameter(&"trail", 0.85)
			mi.set_instance_shader_parameter(&"segments", 3.0)
		t = 0.0
		return
	t += 1.0 / 60.0
	if (shot == 0 and t >= 1.0) or (shot == 1 and t >= 3.05):
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://shots/critA_color_%s_%d.png" % [nm, shot]))
		shot += 1
	if shot >= 2:
		print("COLOR saved ", nm)
		get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
		OS.kill(OS.get_process_id())
