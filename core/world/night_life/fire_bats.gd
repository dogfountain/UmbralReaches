extends Node3D
## BATS COME TO A LIT FIRE (the night's small creatures answering light, after the moths). Every lit brazier in the night registry gathers a few
## bats that circle high over its glow (four a fire, up to twenty fires), and a fire kindled in the dark draws its own within
## seconds: the wildlife's bat body and its orbit shader do the flying (each bat is an instance whose centre is the fire, the radius, speed, tilt and phase in
## its custom data: no CPU per bat, no node per fire), so the whole set is ONE draw call and no per-frame script. Seen from far they
## are specks wheeling above the points of light, which says where the fires are even when the cards are small. Visible within 160 m.
## Rows are read every four seconds (and on a kindling); the instances are written once as a fire is found. Settings.night_life off hides the group.
const Kit := preload("res://core/life/wildlife/life_kit.gd")
const Reg := preload("res://core/world/night_life/night_registry.gd")

const PER_FIRE := 4
const MAX_FIRES := 20
const RANGE := 160.0

var _mmi: MultiMeshInstance3D
var _slots := {}                          ## registry key row -> slot
var _scan := 0.5
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	_rng.seed = 424242
	_mmi = Kit.group("bat", PER_FIRE * MAX_FIRES)
	_mmi.name = "FireBats"
	_mmi.multimesh.visible_instance_count = 0
	_mmi.multimesh.custom_aabb = AABB(Vector3(-1000, -100, -1000), Vector3(2000, 400, 2000))
	_mmi.visibility_range_end = RANGE
	_mmi.visibility_range_end_margin = 20.0
	add_child(_mmi)
	Events.brazier_kindled.connect(func(_b: Node3D) -> void: _scan = 0.2)


func _process(delta: float) -> void:
	_mmi.visible = Reg.enabled
	if not Reg.enabled:
		return
	_scan -= delta
	if _scan > 0.0:
		return
	_scan = 4.0
	var mm := _mmi.multimesh
	for i in Reg.size():
		if _slots.size() >= MAX_FIRES:
			break
		if Reg.on[i] == 0 or Reg.real[i] == 0 or int(Reg.kind[i]) != Reg.Kind.FIRE or _slots.has(i):
			continue
		var slot := _slots.size()
		_slots[i] = slot
		var at: Vector3 = (Reg.pos[i] as Vector3) + Vector3(0.0, 4.5, 0.0)
		for j in PER_FIRE:
			var k := slot * PER_FIRE + j
			mm.set_instance_transform(k, Transform3D(Basis.IDENTITY, at + Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0))))
			var sp := _rng.randf_range(0.45, 0.9) * (1.0 if _rng.randf() < 0.6 else -1.0)
			mm.set_instance_custom_data(k, Color(3.5 * _rng.randf_range(0.45, 1.0), sp, _rng.randf_range(1.0, 3.0), _rng.randf_range(0.0, TAU)))
	mm.visible_instance_count = _slots.size() * PER_FIRE
