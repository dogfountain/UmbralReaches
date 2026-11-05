extends Node
## Draws / primitives at a few rift views, with and without the RealmRift node (its share).
##   godot --path . res://zz/realm_rift_perf.tscn -- --realm --realm-modules=land,rift
var main: Node
var cam: Camera3D
var t := 0
var vi := 0
var phase := 0
var wait := 0
var on := {}
const VIEWS := [["rim", Vector3(0, 2.4, -4), Vector3(-7, 5, -28)], ["overview", Vector3(14, 30, 8), Vector3(-6, 6, -45)],
	["west", Vector3(-40, 20, -28), Vector3(-4, 10, -52)], ["spindle", Vector3(-2, 22.5, -52), Vector3(-1.8, 25, -70)],
	["landing_back", Vector3(0, 26.9, -68), Vector3(0, 10, -20)]]
func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1600, 1000))
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
func _process(_d: float) -> void:
	t += 1
	if main == null or not main.has_meta("summit_dressed") or t < 400:
		return
	if cam == null:
		for c in get_tree().root.find_children("*", "CanvasLayer", true, false): (c as CanvasLayer).visible = false
		cam = Camera3D.new(); cam.far = 400.0; cam.fov = 70.0
		get_tree().root.add_child(cam); cam.current = true
	if vi >= VIEWS.size():
		get_tree().quit(); return
	var v: Array = VIEWS[vi]
	var rift := main.get_node_or_null("RealmRift") as Node3D
	if wait == 0:
		cam.global_position = v[1]; cam.look_at(v[2])
		if rift: rift.visible = phase == 0
	wait += 1
	if wait < 20: return
	var dc := get_viewport().get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME) + get_viewport().get_render_info(Viewport.RENDER_INFO_TYPE_SHADOW, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
	var pr := get_viewport().get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME) + get_viewport().get_render_info(Viewport.RENDER_INFO_TYPE_SHADOW, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)
	if phase == 0:
		on = {"d": dc, "p": pr}; phase = 1
	else:
		print("PERF %s: draws %d prims %d (rift share: %d draws, %d prims)" % [v[0], on.d, on.p, on.d - dc, on.p - pr])
		phase = 0; vi += 1
	wait = 0
