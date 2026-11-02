class_name Reliquary
extends Interactable
## A relic on an altar. Taking it unlocks a skill variant (Travel.relics[relic_id]); using it
## again swaps between the relic's two variants. See docs/ZONE_PLAN.md §4.

@export var relic_id := "bone"

const VARIANTS := {
	"bone": [&"implosion", &"wake"],
}
const TEXT := {
	&"implosion": "NOVA · IMPLOSION — drags everything within 7.5 m in, marks it, then detonates.",
	&"wake": "NOVA · WAKE — leaves a violet field for 3 s that marks whatever stands in it.",
}

var _vis: Node3D
var _t := 0.0
var _light: OmniLight3D


func _ready() -> void:
	add_to_group(Groups.INTERACTABLE)
	_vis = Node3D.new()
	add_child(_vis)
	var bone := OssKit.mat("bone")
	var iron := OssKit.mat("iron")
	_part(_vis, Vector3(0, 0.22, 0), Vector3(0.42, 0.26, 0.3), iron)
	_part(_vis, Vector3(0, 0.38, 0), Vector3(0.36, 0.06, 0.24), bone)
	for x: float in [-0.19, 0.19]:
		for z: float in [-0.13, 0.13]:
			_part(_vis, Vector3(x, 0.08, z), Vector3(0.06, 0.16, 0.06), bone)
	var sk := MeshInstance3D.new()
	sk.mesh = OssKit.skull_mesh()
	sk.material_override = bone
	sk.position = Vector3(0, 0.42, 0)
	sk.scale = Vector3.ONE * 1.3
	_vis.add_child(sk)
	_light = OmniLight3D.new()
	_light.light_color = Color(0.75, 0.45, 1.0)
	_light.omni_range = 3.5
	_light.light_energy = 1.4
	_light.position = Vector3(0, 0.8, 0)
	add_child(_light)
	var motes := Vfx.emitter(Color(1.3, 0.6, 3.0), {"count": 24, "life": 1.6, "speed": Vector2(0.05, 0.25), "size": 0.03, "gravity": -0.4, "radius": 0.35, "swirl": 1.5, "turbulence": true})
	motes.position = Vector3(0, 0.45, 0)
	add_child(motes)
	motes.emitting = true


func _part(p: Node3D, at: Vector3, size: Vector3, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	mi.position = at
	p.add_child(mi)


func _process(delta: float) -> void:
	_t += delta
	_vis.position.y = 0.06 + sin(_t * 1.4) * 0.04
	_vis.rotation.y += delta * 0.35
	_light.light_energy = 1.2 + 0.3 * sin(_t * 2.3)


func can_interact() -> bool:
	return VARIANTS.has(relic_id)


func interact_text() -> String:
	var key := Interactable.prompt_key()
	if not Travel.relics.has(relic_id):
		return "[%s]  Take the Bone Reliquary" % key
	return "[%s]  Attune the Reliquary  (now: %s)" % [key, String(Travel.relics[relic_id]).capitalize()]


func interact(_by: Node) -> void:
	var opts: Array = VARIANTS[relic_id]
	var cur: StringName = Travel.relics.get(relic_id, &"")
	var next: StringName = opts[0] if cur == &"" else opts[(opts.find(cur) + 1) % opts.size()]
	Travel.relics[relic_id] = next
	Events.toast.emit(TEXT.get(next, String(next)))
	SpellFx.rift_in(global_position - Vector3.UP * 1.15)
	Sfx.play("res://art/audio/ward_chime.wav", global_position, -2.0)
