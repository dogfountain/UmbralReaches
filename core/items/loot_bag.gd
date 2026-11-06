extends Interactable
## A loot bag (r33, WoW's lootable corpse / chest): what an elite, a rare, a great one or a chest
## leaves. It stands in a shaft of light coloured by the best thing inside (taller for the better
## ones), with the best thing's name hanging over it in that colour. [E] opens the loot window
## (ui/loot_window.gd): take one, or take all. Laid by gear_runtime.gd drop_bag(); no class_name.
##
## entries: [{kind: "gear", piece: {...}} | {kind: "item", id: ItemDB id, n: int}]
## Whatever is left when the bag leaves the tree (an area streams out, the night ends) goes in the
## satchel anyway: loot is never lost (as gear_drop.gd).

const GearDB := preload("res://core/items/gear_db.gd")
const LootDB := preload("res://core/items/loot_db.gd")

var entries: Array = []
var title := "Remains"
var _t := 0.0
var _beam: MeshInstance3D
var _beam_mat: ShaderMaterial
const BEAM_SHADER := preload("res://core/items/loot_beam.gdshader")
var _label: Label3D
var _done := false
var kept := false             ## the last save wrote this bag: while the game closes it is not poured (Continue lays it back)


func _ready() -> void:
	add_to_group(Groups.INTERACTABLE)
	add_to_group("loot_bag")
	var q := best_quality()
	var col := LootDB.quality_color(q)
	var h := 1.6 + 0.8 * float(q)
	# a soft column of light, not a pole: wide, faint, fading upward (loot_beam.gdshader)
	var mat := ShaderMaterial.new()
	mat.shader = BEAM_SHADER
	mat.set_shader_parameter("beam_color", Color(col.r * 1.3, col.g * 1.3, col.b * 1.3))
	mat.set_shader_parameter("strength", 0.85 + 0.25 * float(q))
	_beam_mat = mat
	var tube := ProcMesh.cyl(0.2, 0.32, h, 16)
	tube.cap_top = false                # an open tube: a cap read as a floating disc at the top
	tube.cap_bottom = false
	_beam = ProcMesh.mesh(self, "Beam", tube, mat, Vector3(0, h * 0.5, 0), Vector3.ZERO, false)
	# the bundle: a dark cloth mound with a glint in the quality colour
	ProcMesh.mesh(self, "Bundle", ProcMesh.sphere(0.24, 0.26, 10, 5), ProcMesh.std_mat(Color(0.16, 0.12, 0.13), 0.95), Vector3(0, 0.1, 0), Vector3.ZERO, false)
	ProcMesh.mesh(self, "Glint", ProcMesh.sphere(0.06, 0.12, 8, 4), ProcMesh.glow_mat(Color(col.r * 2.4, col.g * 2.4, col.b * 2.4)), Vector3(0, 0.26, 0), Vector3.ZERO, false)
	var motes := Vfx.emitter(Color(col.r * 2.0, col.g * 2.0, col.b * 2.0), {"count": 10 + 5 * q, "life": 1.3, "speed": Vector2(0.2, 0.7), "size": 0.03, "gravity": -0.6, "radius": 0.2})
	motes.name = "Motes"
	add_child(motes)
	motes.emitting = true
	_label = Label3D.new()
	_label.name = "Name"
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = false
	_label.font_size = 40
	_label.pixel_size = 0.004
	_label.outline_size = 10
	_label.modulate = col.lightened(0.15)
	_label.position = Vector3(0, h + 0.25, 0)
	_label.visibility_range_end = 22.0
	_refresh_label()
	add_child(_label)


func _process(delta: float) -> void:
	_t += delta
	if _beam:
		_beam_mat.set_shader_parameter("pulse", sin(_t * 2.6))


func best_quality() -> int:
	var q := 0
	for e: Dictionary in entries:
		q = maxi(q, entry_quality(e))
	return q


static func entry_quality(e: Dictionary) -> int:
	if String(e.get("kind", "")) == "gear":
		return int((e.get("piece", {}) as Dictionary).get("rarity", 0))
	return LootDB.item_quality(String(e.get("id", "")))


static func entry_name(e: Dictionary) -> String:
	if String(e.get("kind", "")) == "gear":
		return String((e.get("piece", {}) as Dictionary).get("name", "gear"))
	var n := int(e.get("n", 1))
	return "%s%s" % [String(ItemDB.def(String(e.get("id", ""))).get("name", "?")), (" x%d" % n) if n > 1 else ""]


func _refresh_label() -> void:
	if _label == null:
		return
	var best := {}
	for e: Dictionary in entries:
		if best.is_empty() or entry_quality(e) > entry_quality(best):
			best = e
	_label.text = entry_name(best) + ("  +%d" % (entries.size() - 1) if entries.size() > 1 else "") if not best.is_empty() else ""


func can_interact() -> bool:
	return not _done and not entries.is_empty()


func interact_text() -> String:
	return "[%s]  Loot %s" % [Interactable.prompt_key(), title]


func interact_feel() -> StringName:
	return &"use"


func interact(_by: Node) -> void:
	open_window()


## Show the loot window on this bag, or take everything when there is no window (tests, no UI).
func open_window() -> void:
	var w := get_tree().get_first_node_in_group("loot_window") if is_inside_tree() else null
	if w and w.has_method("open_bag"):
		w.call("open_bag", self)
	else:
		take_all()


## Take entry `i` into the satchel / gear bag. Returns the toast line ("" when nothing).
func take(i: int) -> String:
	if i < 0 or i >= entries.size():
		return ""
	var e: Dictionary = entries.pop_at(i)
	var line := _store(e)
	_refresh_label()
	if kept:
		Travel.save_soon()                          # the record must not still hold what was taken
	if entries.is_empty():
		_finish()
	return line


func take_all() -> PackedStringArray:
	var out := PackedStringArray()
	while not entries.is_empty():
		out.append(take(0))
	return out


static func _store(e: Dictionary) -> String:
	if String(e.get("kind", "")) == "gear":
		var GearRuntime: GDScript = load("res://core/items/gear_runtime.gd")
		return String(GearRuntime.call("store", e.get("piece", {})))
	var id := String(e.get("id", ""))
	var n := int(e.get("n", 1))
	if id == "" or n <= 0:
		return ""
	Travel.give(id, n, false)
	return "%s x%d" % [String(ItemDB.def(id).get("name", id)), n]


func _finish() -> void:
	if _done:
		return
	_done = true
	Travel.save_soon()
	if is_inside_tree():
		Vfx.burst(global_position + Vector3(0, 0.4, 0), Color(1.6, 1.2, 0.7), {"count": 16, "life": 0.6, "speed": Vector2(0.4, 1.2), "size": 0.03, "gravity": -0.5})
	queue_free()


func _exit_tree() -> void:
	if kept and Travel.leaving:
		return                                       # the save holds this bag: pouring it too would grant it twice
	if not entries.is_empty():
		for e: Dictionary in entries:
			_store(e)
		entries.clear()
