extends Node
## Every NPC of the night, close up and at talking distance, with the colour grade ON (critique C):
##   HOME=<scratch>/home godot --path . res://zz/critc_npc_tour.tscn [-- --tag=before --only=hild,keep]
## Villagers (all four returning ones forced present in a sandbox), the Keg's patrons and the keep.
## Writes shots/critC_npc_<id>_<tag>.png (face, 1.1 m), shots/critC_npc_<id>_<tag>_mid.png (3 m) and
## _high.png (the wanderer's camera height as he walks up),
## prints each NPC's height and face light. Never writes the save (Travel._busy, village sandbox);
## exits with OS.kill, and by itself after 240 s.

const VState := preload("res://core/life/village/village_state.gd")

var t := 0.0
var tag := "now"
var only: PackedStringArray = []
var cam: Camera3D
var _started := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Travel._busy = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.trim_prefix("--tag=")
		elif a.begins_with("--only="):
			only = a.trim_prefix("--only=").split(",")
	VState.sandbox = {"restored": {"wrights_home": true, "reed_home": true, "wenna": true, "pell": true, "lamps_more": true}}
	get_window().size = Vector2i(1280, 800)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	var main: Node = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _process(d: float) -> void:
	t += d
	if t > 240.0:
		print("NPCTOUR timeout")
		OS.kill(OS.get_process_id())
	var v := get_tree().root.find_child("Village", true, false)
	if _started or v == null or not v.has_meta("village_done") or t < 8.0:
		return
	_started = true
	_run(v)


func _targets(v: Node) -> Array:
	var out: Array = []
	var vs: Dictionary = v.get("villagers")
	for id: String in vs:
		out.append([id, vs[id]])
	var keep := get_tree().get_first_node_in_group("keep")
	if keep:
		out.append(["keep", keep])
	for p in get_tree().root.find_children("Patron*", "", true, false):
		if p is Node3D:
			out.append([String(p.name).to_lower(), p])
	return out


func _box(n: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for c in n.find_children("*", "VisualInstance3D", true, false):
		var vi := c as VisualInstance3D
		if not vi.is_visible_in_tree() or vi is Light3D:
			continue
		var b := vi.global_transform * vi.get_aabb()
		if b.size.length() > 6.0:
			continue
		box = b if first else box.merge(b)
		first = false
	return box


func _run(v: Node) -> void:
	for n in get_tree().get_nodes_in_group(Groups.ENEMY):
		(n as Node).queue_free()
	for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if String(c.name) != "Grade":
			(c as CanvasLayer).visible = false
	cam = Camera3D.new()
	cam.fov = 40.0
	cam.far = 300.0
	get_tree().root.add_child(cam)
	cam.current = true
	var pl := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	for pair: Array in _targets(v):
		var id := String(pair[0])
		var n := pair[1] as Node3D
		if not only.is_empty() and not id in only:
			continue
		if not is_instance_valid(n):
			continue
		# the wanderer stands where a talker would (NPCs look at him)
		var fwd := -(Basis(Vector3.UP, n.global_rotation.y).z)
		if pl:
			pl.global_position = n.global_position + fwd * 2.0 - fwd.cross(Vector3.UP).normalized() * 1.6
		await get_tree().create_timer(0.5).timeout
		if not is_instance_valid(n):
			continue
		var box := _box(n)
		var top := box.position.y + box.size.y if box.size != Vector3.ZERO else n.global_position.y + 1.6
		var head := Vector3(n.global_position.x, top - 0.16, n.global_position.z)
		fwd = -(Basis(Vector3.UP, n.global_rotation.y).z)
		var side := fwd.cross(Vector3.UP).normalized()
		cam.global_position = head + fwd * 1.1 + side * 0.25 + Vector3.UP * 0.05
		cam.look_at(head - Vector3.UP * 0.04)
		await get_tree().create_timer(0.35).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://shots/critC_npc_%s_%s.png" % [id, tag]))
		var mid := Vector3(n.global_position.x, top * 0.55 + n.global_position.y * 0.45, n.global_position.z)
		cam.global_position = mid + fwd * 3.0 + side * 0.9 + Vector3.UP * 0.35
		cam.look_at(mid)
		await get_tree().create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://shots/critC_npc_%s_%s_mid.png" % [id, tag]))
		# where the wanderer's camera sits when he walks up to talk: above and behind him
		var feet := n.global_position
		cam.global_position = feet + fwd * 3.4 + side * 0.5 + Vector3.UP * 2.05
		cam.look_at(Vector3(feet.x, top - 0.25, feet.z))
		await get_tree().create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://shots/critC_npc_%s_%s_high.png" % [id, tag]))
		print("NPCTOUR %s height %.2f at %s" % [id, top - n.global_position.y, n.global_position])
	print("NPCTOUR done")
	VState.sandbox = null
	OS.kill(OS.get_process_id())
