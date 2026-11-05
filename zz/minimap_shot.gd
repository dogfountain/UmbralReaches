extends Node
## The minimap at three spots (needs a renderer): near the thorn seal's guards, the same wide, and
## at the Crossing's foot. -> shots/minimap_<n>.png. Never writes the save (Travel._busy).
##   HOME=<scratch> godot --path . res://zz/minimap_shot.tscn
var main: Node
var t := 0
var p: Player
const SPOTS := [[Vector3(-44.0, 4.0, 2.0), 0], [Vector3(-44.0, 4.0, 2.0), 1], [Vector3(2.0, 1.5, -2.0), 0]]
var i := 0
var wait := 0


func _ready() -> void:
	Travel._busy = true
	get_window().size = Vector2i(1600, 900)
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _process(_d: float) -> void:
	t += 1
	if t > 60 * 120:
		print("MINIMAP_SHOT timeout")
		get_tree().quit(1)
		return
	if p == null:
		p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		return
	var mm := get_tree().root.find_child("Minimap", true, false)
	if mm == null or mm.get("_tex") == null:
		return
	if wait > 0:
		wait -= 1
		if wait == 0:
			var img := get_viewport().get_texture().get_image()
			img.save_png("res://shots/minimap_%d.png" % i)
			var kinds := {}
			for m: Dictionary in mm.get("_marks"):
				kinds[m.kind] = int(kinds.get(m.kind, 0)) + 1
			print("MINIMAP_SHOT saved ", i, " guards ", (mm.get("_guards") as Array).size(), " marks ", kinds)
			i += 1
			if i >= SPOTS.size():
				get_tree().quit(0)
		return
	var lo := get_tree().current_scene.get_node_or_null("LoadingScreen") if get_tree().current_scene else null
	if lo != null:
		return
	var s: Array = SPOTS[i]
	p.global_position = s[0]
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()
	mm.set("_range_i", int(s[1]))
	wait = 150
