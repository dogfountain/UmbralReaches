extends Interactable
## A gathering node (r33, WoW's herb and ore nodes, set in the night): an ASH-BLOOM (pale flowers
## that open after dark where something burned) or a GRAVE-IRON stone (rust-red ore bleeding up
## through old graves). [E] gathers 1-2 of it (sometimes a little more), then it is spent for
## RESPAWN seconds. It is a map marker (group "map_marker", map_kind "gather") while it can be
## gathered. Placed by gather.gd; no class_name. Nothing here runs per frame.

const KINDS := {
	"ash_bloom": {"label": "Ash-bloom", "verb": "Gather", "color": Color(0.86, 0.84, 0.96), "bonus": ["ember_shard", 0.08]},
	"grave_iron": {"label": "Grave-iron", "verb": "Mine", "color": Color(0.85, 0.42, 0.3), "bonus": ["relic_fragment", 0.06]},
}
const RESPAWN := 300.0
const XP := 5

var kind := "ash_bloom"
var rng_seed := 0
var _ready_to_take := true
var _vis: Node3D


func _ready() -> void:
	add_to_group(Groups.INTERACTABLE)
	add_to_group("gather_node")
	var k: Dictionary = KINDS.get(kind, KINDS.ash_bloom)
	set_meta("map_kind", "gather")
	set_meta("map_label", String(k.label))
	set_meta("map_color", k.color)
	set_meta("gather_kind", kind)
	_build()
	_set_ready(true)


func _build() -> void:
	_vis = Node3D.new()
	_vis.name = "Look"
	add_child(_vis)
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	if kind == "grave_iron":
		var stone := ProcMesh.std_mat(Color(0.2, 0.18, 0.19), 0.95)
		var rock := ProcMesh.mesh(_vis, "Rock", ProcMesh.sphere(0.75, 1.0, 8, 5), stone, Vector3(0, 0.3, 0), Vector3(0, rng.randf() * TAU, 0), true)
		rock.scale = Vector3(1.0, 0.75, 0.85)
		ProcMesh.mesh(_vis, "Rock2", ProcMesh.sphere(0.3, 0.4, 7, 4), stone, Vector3(0.42, 0.12, 0.18), Vector3(0, rng.randf() * TAU, 0), true)
		var vein := ProcMesh.glow_mat(Color(1.3, 0.42, 0.22))
		for i in 4:
			var a := rng.randf() * TAU
			var v := ProcMesh.mesh(_vis, "Vein%d" % i, ProcMesh.box(Vector3(0.06, 0.06, 0.6)), vein,
				Vector3(cos(a) * 0.74, 0.3 + rng.randf() * 0.25, sin(a) * 0.64), Vector3(rng.randf_range(-0.6, 0.6), a, 0), false)
			v.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	else:
		var stem := ProcMesh.std_mat(Color(0.18, 0.22, 0.2), 0.9)
		var petal := ProcMesh.glow_mat(Color(1.5, 1.42, 1.8))
		# a pale ring of ash on the ground, where something burned
		var ash := ProcMesh.glow_mat(Color(0.5, 0.46, 0.62, 0.35))
		ash.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var ring := ProcMesh.mesh(_vis, "AshRing", ProcMesh.cyl(0.7, 0.7, 0.01, 16), ash, Vector3(0, 0.03, 0), Vector3.ZERO, false)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for i in 9:
			var a := rng.randf() * TAU
			var r := rng.randf_range(0.05, 0.4)
			var h := rng.randf_range(0.5, 0.95)          # above the meadow grass
			var at := Vector3(cos(a) * r, 0.0, sin(a) * r)
			ProcMesh.mesh(_vis, "Stem%d" % i, ProcMesh.cyl(0.008, 0.012, h, 4), stem, at + Vector3(0, h * 0.5, 0), Vector3(rng.randf_range(-0.2, 0.2), 0, rng.randf_range(-0.2, 0.2)), false)
			var f := ProcMesh.mesh(_vis, "Bloom%d" % i, ProcMesh.sphere(0.07, 0.08, 6, 3), petal, at + Vector3(0, h, 0), Vector3.ZERO, false)
			f.scale = Vector3(1.4, 0.6, 1.4)
	var col: Color = (KINDS.get(kind, KINDS.ash_bloom) as Dictionary).color
	var motes := Vfx.emitter(Color(col.r * 1.6, col.g * 1.6, col.b * 1.6), {"count": 10, "life": 2.2, "speed": Vector2(0.1, 0.3), "size": 0.035, "gravity": -0.25, "radius": 0.45})
	motes.position = Vector3(0, 0.6, 0)
	motes.name = "Motes"
	_vis.add_child(motes)
	motes.emitting = true


func _set_ready(on: bool) -> void:
	_ready_to_take = on
	if _vis:
		_vis.visible = on
	if on:
		add_to_group("map_marker")
	elif is_in_group("map_marker"):
		remove_from_group("map_marker")


func can_interact() -> bool:
	return _ready_to_take


func interact_text() -> String:
	var k: Dictionary = KINDS.get(kind, KINDS.ash_bloom)
	return "[%s]  %s %s" % [Interactable.prompt_key(), String(k.verb), String(k.label).to_lower()]


func interact_feel() -> StringName:
	return &"use"


func interact(_by: Node) -> void:
	gather()


## Take what the node holds (1-2, and now and then a little extra). Returns {id -> amount}.
func gather() -> Dictionary:
	if not _ready_to_take:
		return {}
	var got := {}
	var n := 1 + (1 if randf() < 0.5 else 0)
	Travel.give(kind, n, false)
	got[kind] = n
	var bonus: Array = (KINDS.get(kind, KINDS.ash_bloom) as Dictionary).bonus
	if randf() < float(bonus[1]):
		Travel.give(String(bonus[0]), 1, false)
		got[String(bonus[0])] = 1
	Travel.save_soon()
	if is_inside_tree():
		var h := get_tree().get_first_node_in_group("hearth")
		if h and h.has_method("give_memory"):
			h.call("give_memory", XP, "gather")
		var col: Color = (KINDS.get(kind, KINDS.ash_bloom) as Dictionary).color
		Vfx.burst(global_position + Vector3(0, 0.3, 0), Color(col.r * 2.0, col.g * 2.0, col.b * 2.0), {"count": 18, "life": 0.7, "speed": Vector2(0.5, 1.5), "size": 0.03, "gravity": -0.8})
		_set_ready(false)
		get_tree().create_timer(RESPAWN, false).timeout.connect(func() -> void:
			if is_instance_valid(self):
				_set_ready(true))
	else:
		_set_ready(false)
	return got
