extends Node
## Player-eye renders of the realm flora at fixed views (camera 1.7 m over the ground, or --high):
##   godot --path . res://zz/realm_flora_shots.tscn -- --realm --realm-modules=land,flora [--only=a,b] [--high]
## -> shots/flora_<view>.png (1600 x 1000)
const VIEWS := {
	"thorn_in": [Vector2(-75, 20), -2.4, 0.05],
	"thorn_edge": [Vector2(-28, 30), -2.0, 0.0],
	"thorn_deep": [Vector2(-90, -40), 0.4, 0.05],
	"henge_path": [Vector2(-48, 4), -2.3, 0.0],
	"glade": [Vector2(-30, 14), -2.0, -0.05],
	"meadow": [Vector2(8, 48), -2.2, -0.04],
	"spawn": [Vector2(0, 26.5), PI, -0.05],
	"road": [Vector2(-30, 62), -1.57, -0.03],
	"heath": [Vector2(60, 70), 1.0, -0.03],
	"fen": [Vector2(52, 12), 2.3, -0.04],
	"fen_pool": [Vector2(85, -10), 2.8, -0.08],
	"barrows": [Vector2(64, -30), 2.2, -0.04],
	"rift_rim": [Vector2(14, -6), 3.6, -0.15],
	"crags": [Vector2(-60, -112), 0.3, 0.1],
	"chapel": [Vector2(-60, 46), 0.9, -0.03],
}
var t := 0.0
var cam: Camera3D
var keys: Array = []
var ki := -1
var wait := 0.0
var high := false
func _ready() -> void:
	get_window().size = Vector2i(1600, 1000)
	keys = VIEWS.keys()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="): keys = Array(a.trim_prefix("--only=").split(","))
		elif a == "--high": high = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	var main: Node = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
func _process(d: float) -> void:
	t += d
	var main := get_tree().root.get_node_or_null("Main")
	if cam == null:
		if main == null or main.get_node_or_null("RealmFlora") == null or t < 8.0:
			return
		for n in get_tree().get_nodes_in_group(Groups.ENEMY): (n as Node).queue_free()
		for c in get_tree().root.find_children("*", "CanvasLayer", true, false): (c as CanvasLayer).visible = false
		var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
		if p: p.visible = false
		cam = Camera3D.new(); cam.fov = 70.0; cam.far = 82.0; cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		get_tree().root.add_child(cam); cam.current = true
		_next(main)
		return
	wait -= d
	if wait <= 0.0:
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://shots/flora_%s.png" % keys[ki]))
		print("FLORA_SHOT ", keys[ki], " fps ", Engine.get_frames_per_second(), " draws ", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " prims ", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		_next(main)
func _next(main: Node) -> void:
	ki += 1
	if ki >= keys.size():
		print("FLORA_SHOT done")
		get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST); OS.kill(OS.get_process_id())
		return
	var v: Array = VIEWS[keys[ki]]
	var xz: Vector2 = v[0]
	var space := (main as Node3D).get_world_3d().direct_space_state
	var y := RealmLayout.ground(space, xz.x, xz.y)
	cam.global_position = Vector3(xz.x, y + (14.0 if high else 1.7), xz.y)
	cam.rotation = Vector3(float(v[2]) - (0.35 if high else 0.0), float(v[1]), 0)
	cam.reset_physics_interpolation()
	wait = 1.2
