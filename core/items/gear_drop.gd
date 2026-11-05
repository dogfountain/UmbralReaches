extends Node3D
## A piece of gear lying where it fell (gear_runtime.gd lays it): a thin shaft of light in the
## piece's rarity colour, tall for the rare ones, with a few motes rising. Walk through it (it drifts
## to you inside a few metres) and it goes in the satchel. A drop the world frees before you reach
## it (an area streamed out, the night left) is kept anyway: gear is never lost. Load by path.

const GearDB := preload("res://core/items/gear_db.gd")
const TAKE_R := 1.3
const DRIFT_R := 4.5
const SETTLE_S := 0.7

var piece: Dictionary = {}
var _t := 0.0
var _taken := false
var _beam: MeshInstance3D


func _ready() -> void:
	add_to_group("gear_drop")
	var r := int(piece.get("rarity", 0))
	var col := GearDB.rarity_color(r)
	var h := 1.4 + 0.7 * float(r)
	var mat := ProcMesh.glow_mat(Color(col.r * 1.6, col.g * 1.6, col.b * 1.6, 0.55))
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_beam = ProcMesh.mesh(self, "Beam", ProcMesh.cyl(0.035, 0.07, h, 8), mat, Vector3(0, h * 0.5, 0), Vector3.ZERO, false)
	var core := ProcMesh.glow_mat(Color(col.r * 2.4, col.g * 2.4, col.b * 2.4))
	ProcMesh.mesh(self, "Mote", ProcMesh.sphere(0.07, 0.14, 8, 4), core, Vector3(0, 0.25, 0), Vector3.ZERO, false)
	var motes := Vfx.emitter(Color(col.r * 2.0, col.g * 2.0, col.b * 2.0), {"count": 8 + 4 * r, "life": 1.2, "speed": Vector2(0.2, 0.6), "size": 0.03, "gravity": -0.6, "radius": 0.15})
	motes.name = "Motes"
	add_child(motes)
	motes.emitting = true
	# r33 loot: the piece's name hangs over the shaft in its quality colour (WoW's ground names)
	var lab := Label3D.new()
	lab.name = "Name"
	lab.text = String(piece.get("name", ""))
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.font_size = 36
	lab.pixel_size = 0.004
	lab.outline_size = 9
	lab.modulate = col.lightened(0.15)
	lab.position = Vector3(0, h + 0.2, 0)
	lab.visibility_range_end = 18.0
	add_child(lab)


func _process(delta: float) -> void:
	_t += delta
	if _beam:
		_beam.rotation.y += delta * 0.8
		_beam.scale = Vector3.ONE * (1.0 + 0.06 * sin(_t * 3.0))
	if _taken or _t < SETTLE_S:
		return
	var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	if p == null:
		return
	var to := p.global_position - global_position
	var d := to.length()
	if d <= TAKE_R:
		take()
	elif d <= DRIFT_R:
		global_position += to.normalized() * minf(d, delta * 6.0)


func take() -> void:
	if _taken:
		return
	_taken = true
	var GearRuntime: GDScript = load("res://core/items/gear_runtime.gd")
	Events.toast.emit(String(GearRuntime.call("store", piece)))
	queue_free()


func _exit_tree() -> void:
	if not _taken and not piece.is_empty():
		_taken = true
		var GearRuntime: GDScript = load("res://core/items/gear_runtime.gd")
		GearRuntime.call("store", piece)
