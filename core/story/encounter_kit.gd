extends RefCounted
## The shared pieces of the two live task steps, escort (escort.gd) and defend (defend.gd): foes
## near a point, a foe spawned from the enemy scripts, the ground under a point, and the small
## health frame at the top of the screen. Statics only; nothing is held here (no class_name).
## Load by path: const Kit := preload("res://core/story/encounter_kit.gd")

const FRAME_TOP := 84.0


## Living foes within `r` metres (on the ground plane) of `at`.
static func foes_near(tree: SceneTree, at: Vector3, r: float) -> Array[Enemy]:
	var out: Array[Enemy] = []
	for n: Node in tree.get_nodes_in_group(Groups.ENEMY):
		var e := n as Enemy
		if e == null or not e.is_inside_tree() or e.is_queued_for_deletion() or e.hp <= 0.0 or not e.visible:
			continue
		if Vector2(e.global_position.x - at.x, e.global_position.z - at.z).length() < r:
			out.append(e)
	return out


## The floor under x, z (the terrain; the macro shape before it exists).
static func ground_y(node: Node3D, x: float, z: float) -> float:
	var w := node.get_world_3d()
	return RealmLayout.ground(w.direct_space_state if w else null, x, z)


## Where feet go: the floor, or a hand's breadth under the surface in shallows (never the river bed).
static func walk_y(node: Node3D, x: float, z: float) -> float:
	var g := ground_y(node, x, z)
	var wl := RealmLayout.water_level_at(x, z)
	return g if is_nan(wl) or g >= wl else maxf(g, wl - 0.3)


## One foe of `kind` ("wretch", "husk", ...: core/enemy/<kind>.gd) standing at `at`, tagged so it
## counts for no other task. With a `ward` it goes for that target (Enemy.ward) and its range and
## leash cover the whole step. Null when the kind is not there.
static func spawn_foe(host: Node, kind: String, at: Vector3, tag: String, ward: WardTarget = null) -> Enemy:
	var path := "res://core/enemy/%s.gd" % kind
	if not ResourceLoader.exists(path):
		return null
	var scr := load(path) as GDScript
	if scr == null or not scr.can_instantiate():
		return null
	var e := scr.new() as Enemy
	if e == null:
		return null
	e.set_meta("quest", tag)
	host.add_child(e)
	e.station(at)
	if ward != null:
		e.ward = ward
		e.chase_range = maxf(e.chase_range, 40.0)
		e.hunt_leash = maxf(e.hunt_leash, 60.0)
	return e


## A ring of `n` foes of the given kinds round `centre` at `radius`, starting at angle `a0`
## (`arc` of the circle: TAU = all round).
static func spawn_ring(host: Node3D, kinds: Array, n: int, centre: Vector3, radius: float, a0: float, tag: String, arc := TAU, ward: WardTarget = null) -> Array[Enemy]:
	var out: Array[Enemy] = []
	if kinds.is_empty():
		return out
	for i in n:
		var a := a0 + arc * float(i) / float(maxi(n, 1))
		var x := centre.x + cos(a) * radius
		var z := centre.z + sin(a) * radius
		var e := spawn_foe(host, String(kinds[i % kinds.size()]), Vector3(x, ground_y(host, x, z), z), tag, ward)
		if e:
			out.append(e)
	return out


## Free the foes still standing from a list.
static func clear_foes(foes: Array[Enemy]) -> void:
	for v: Variant in foes:                  # (a foe freed by its own death is not an Enemy any more)
		if is_instance_valid(v):
			(v as Enemy).queue_free()
	foes.clear()


## Drop the foes that are gone or down from a list.
static func prune(foes: Array[Enemy]) -> void:
	var keep: Array[Enemy] = []
	for v: Variant in foes:
		if is_instance_valid(v) and not (v as Enemy).is_queued_for_deletion() and (v as Enemy).hp > 0.0:
			keep.append(v as Enemy)
	foes.assign(keep)


## The small frame: {"layer", "bar", "label"}. Parent `layer` anywhere; free it with the encounter.
static func make_frame(title: String, max_hp: float) -> Dictionary:
	var layer := CanvasLayer.new()
	layer.name = "WardFrame"
	layer.layer = 6
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.035, 0.04, 0.82)
	sb.border_color = Color(0.55, 0.36, 0.17)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(6)
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.offset_top = FRAME_TOP
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	panel.add_child(box)
	var label := Label.new()
	label.text = title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.93, 0.83, 0.62))
	box.add_child(label)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(190.0, 9.0)
	bar.show_percentage = false
	bar.max_value = max_hp
	bar.value = max_hp
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.78, 0.3, 0.16)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.1, 0.07, 0.07)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", back)
	box.add_child(bar)
	layer.add_child(panel)
	return {"layer": layer, "bar": bar, "label": label}


## The audit's view of a live step (escort with a `path`, or defend): [] = fine.
static func audit(id: String, si: int, stp: Dictionary) -> Array[String]:
	var bad: Array[String] = []
	var kind := String(stp.get("kind", ""))
	if not ((kind == "escort" and stp.has("path")) or kind == "defend"):
		return bad
	if not (stp.get("at", stp.get("to")) is Vector2):
		bad.append("%s step %d (%s) has no map target" % [id, si, kind])
	if kind == "escort" and (stp.path as Array).size() < 2:
		bad.append("%s step %d: an escort walks at least two points" % [id, si])
	if float(stp.get("hp", 0.0)) <= 0.0 or (kind == "defend" and float(stp.get("time", 0.0)) <= 0.0):
		bad.append("%s step %d: a %s step has health (and a time to hold)" % [id, si, kind])
	return bad
