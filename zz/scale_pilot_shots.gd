extends Node
## Before / after stills of the scale pilot (Weirford and its approach, core/world/realm/scale_pilot.gd): the
## same views every run, so two runs compare.
##   godot --path . res://zz/scale_pilot_shots.tscn -- --tag=after [--only=a,b] [--no-scale-pilot]
## "eye" views stand the wanderer on the ground and use the game's own camera (the HUD hidden), once in the
## night's own look and once with a survey light; "air" views are a free camera with the survey light, the
## wanderer stood in frame for scale. Writes shots/scale_pilot/<tag>_<view>[_lit].jpg. Never writes the save
## (Travel._busy; exits by OS.kill).
const SETTLE := 10.0
const FRAMES := 30

## eye: [name, "eye", stand xz, yaw (0 = north, PI/2 = west), pitch]
## air: [name, "air", camera, look at, stand xz]
const VIEWS := [
	["01_gate_from_realm", "eye", Vector2(-128.0, 66.6), PI * 0.5, 0.02],
	["02_gate_from_marches", "eye", Vector2(-179.0, 67.4), -PI * 0.5 - 0.03, 0.05],
	["03_road_into_town", "eye", Vector2(-168.0, 66.3), PI * 0.5, 0.0],
	["04_street_inn", "eye", Vector2(-179.5, 66.0), PI * 0.5 - 0.95, 0.04],
	["05_smithy", "eye", Vector2(-177.0, 66.2), -2.5, 0.02],
	["06_square", "eye", Vector2(-203.5, 82.5), -0.75, 0.03],
	["07_square_south", "eye", Vector2(-190.0, 67.5), PI - 0.15, 0.0],
	["08_bridge_east_end", "eye", Vector2(-191.0, 65.6), PI * 0.5 + 0.05, 0.02],
	["09_bridge_mid_mill", "eye", Vector2(-207.0, 65.6), PI * 0.5 - 0.75, 0.08],
	["10_west_bank", "eye", Vector2(-236.0, 66.0), -PI * 0.5 + 0.1, 0.03],
	["11_stable_yard", "eye", Vector2(-189.5, 99.5), 0.0, 0.04],
	["12_air_town", "air", Vector3(-192.0, 42.0, 128.0), Vector3(-193.0, 2.0, 66.0), Vector2(-190.0, 68.0)],
	["13_air_gate", "air", Vector3(-186.0, 30.0, 70.0), Vector3(-157.0, 7.0, 67.0), Vector2(-166.0, 66.4)],
	["14_air_river", "air", Vector3(-236.0, 26.0, 96.0), Vector3(-210.0, 3.0, 62.0), Vector2(-208.0, 65.6)],
	["15_far_150m", "air", Vector3(-205.0, 30.0, 215.0), Vector3(-196.0, 4.0, 66.0), Vector2(-190.0, 68.0)],
	# the Realm's woods (the flora scale is realm-wide): under the crowns, and from above with the wanderer for scale
	["20_thornwood", "eye", Vector2(-100.0, -10.0), 0.4, 0.12],
	["21_sorrow", "eye", Vector2(-205.0, -20.0), -0.6, 0.12],
	["22_fen", "eye", Vector2(72.0, 5.0), 0.2, 0.08],
	["23_mere", "eye", Vector2(95.0, 120.0), 0.9, 0.08],
	["24_air_thornwood", "air", Vector3(-82.0, 14.0, 6.0), Vector3(-100.0, 2.0, -10.0), Vector2(-100.0, -10.0)],
	["16_plan", "air", Vector3(-192.0, 150.0, 68.5), Vector3(-192.0, 0.0, 68.0), Vector2(-190.0, 68.0)],
	["17_inn_door", "eye", Vector2(-183.0, 66.4), 0.1, 0.1],
	["18_smith_at_work", "eye", Vector2(-175.5, 67.6), PI, 0.02],
	["19_gate_arch", "eye", Vector2(-167.0, 66.6), -PI * 0.5, 0.16],
	["20_inn_inside", "eye", Vector2(-184.0, 55.0), -PI * 0.5, 0.0],
	["21_mill_door", "eye", Vector2(-228.5, 65.0), 0.5, 0.12],
	["22_wheel_weir", "air", Vector3(-204.0, 7.0, 44.0), Vector3(-216.0, 3.0, 56.5), Vector2(-208.0, 65.6)],
]

var tag := "after"
var only := PackedStringArray()
var main: Node
var p: Player
var t := 0.0
var done_t := -1.0
var cam: Camera3D
var game_cam: Camera3D
var lamp: DirectionalLight3D
var fill: DirectionalLight3D          ## a weaker light from the other shoulder: a street's two sides both read
var shots: Array = []               ## [file, view, lit]
var si := -1
var wait := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Travel._busy = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.trim_prefix("--tag=")
		elif a.begins_with("--only="):
			only = a.trim_prefix("--only=").split(",")
	Settings.fullscreen = false
	get_window().size = Vector2i(1600, 1000)
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _process(d: float) -> void:
	t += d
	if t > 600.0:
		print("PILOT SHOTS FAIL timed out")
		OS.kill(OS.get_process_id())
	if si < 0:
		if not main.has_meta("realm_done"):
			return
		if done_t < 0.0:
			done_t = t
		if t - done_t < SETTLE:
			return
		_begin()
		return
	if si >= shots.size():
		print("PILOT SHOTS DONE %s: %d stills in shots/scale_pilot" % [tag, shots.size()])
		OS.kill(OS.get_process_id())
		return
	var s: Array = shots[si]
	var v: Array = s[1]
	if wait == 0:
		_pose(v, bool(s[2]))
		wait = FRAMES
		return
	if String(v[1]) == "eye":
		p.velocity = Vector3.ZERO
		p.set_view(float(v[3]), float(v[4]))
	if not DisplayServer.window_can_draw():
		RenderingServer.force_draw(false)          # macOS stops drawing a covered window
	wait -= 1
	if wait == 0:
		get_viewport().get_texture().get_image().save_jpg(String(s[0]), 0.92)
		si += 1


func _begin() -> void:
	p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
	game_cam = get_viewport().get_camera_3d()
	for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if String(c.name) != "Grade":
			(c as CanvasLayer).visible = false
	cam = Camera3D.new()
	cam.fov = 60.0
	cam.far = 420.0
	get_tree().root.add_child(cam)
	lamp = DirectionalLight3D.new()
	lamp.light_energy = 1.0
	lamp.shadow_enabled = true
	lamp.directional_shadow_max_distance = 140.0
	lamp.visible = false
	get_tree().root.add_child(lamp)
	fill = DirectionalLight3D.new()
	fill.light_energy = 0.4
	fill.visible = false
	get_tree().root.add_child(fill)
	var dir := ProjectSettings.globalize_path("res://shots/scale_pilot")
	DirAccess.make_dir_recursive_absolute(dir)
	for v: Array in VIEWS:
		if not only.is_empty() and not (String(v[0]) in only or String(v[0]).get_slice("_", 0) in only):
			continue
		if String(v[1]) == "eye":
			shots.append(["%s/%s_%s.jpg" % [dir, tag, v[0]], v, false])
			shots.append(["%s/%s_%s_lit.jpg" % [dir, tag, v[0]], v, true])
		else:
			shots.append(["%s/%s_%s.jpg" % [dir, tag, v[0]], v, true])
	si = 0
	print("PILOT SHOTS %s: %d stills" % [tag, shots.size()])


func _pose(v: Array, lit: bool) -> void:
	lamp.visible = lit
	var eye := String(v[1]) == "eye"
	# the survey light falls over the camera's shoulder, so what the view looks at is lit
	var fwd: Vector3 = Vector3.ZERO if eye else ((v[3] as Vector3) - (v[2] as Vector3))
	var vy := float(v[3]) if eye else atan2(-fwd.x, -fwd.z)
	lamp.rotation = Vector3(deg_to_rad(-48.0), vy + 0.55, 0.0)
	fill.rotation = Vector3(deg_to_rad(-30.0), vy - 0.95, 0.0)
	fill.visible = lit
	var xz: Vector2 = v[2] if eye else v[4]
	var space := p.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(xz.x, 60.0, xz.y), Vector3(xz.x, -40.0, xz.y), Layers.WORLD)
	var hit := space.intersect_ray(q)
	var gy: float = (hit.position as Vector3).y if hit else RealmLayout.ground(space, xz.x, xz.y)
	var at := Vector3(xz.x, gy + 0.15, xz.y)
	if p.global_position.distance_to(at) > 0.3:
		p.global_position = at
		p.reset_physics_interpolation()
	p.velocity = Vector3.ZERO
	if eye:
		p.set_view(float(v[3]), float(v[4]))
		if game_cam != null and is_instance_valid(game_cam):
			game_cam.make_current()
	else:
		cam.global_position = v[2]
		var look: Vector3 = v[3]
		var up := Vector3.UP if absf((look - cam.global_position).normalized().y) < 0.98 else Vector3.FORWARD
		cam.look_at(look, up)
		cam.make_current()
