class_name Reliquary
extends Interactable
## A relic on an altar. Taking it unlocks a skill variant (Travel.relics[relic_id]); using it
## again swaps between the relic's two variants. See docs/ZONE_PLAN.md §4.

@export var relic_id := "bone"
@export var size := 1.0                 ## the whole shrine scales (the mound's relic is 2.4)

const VARIANTS := {
	"bone": [&"implosion", &"wake"],
	"thorn": [&"splinter", &"briar"],
}
const TEXT := {
	&"implosion": "NOVA · IMPLOSION — drags everything within 7.5 m in, marks it, then detonates.",
	&"wake": "NOVA · WAKE — leaves a violet field for 3 s that marks whatever stands in it.",
	&"splinter": "RIFT BOLT · SPLINTER — each bolt bursts into thorns that find and mark up to three more within 4.5 m.",
	&"briar": "RIFT BOLT · BRIAR — whatever a bolt hits is rooted in brambles: slowed hard for 2 s.",
}

var _vis: Node3D
var _t := 0.0
var _light: OmniLight3D


func _ready() -> void:
	add_to_group(Groups.INTERACTABLE)
	_vis = Node3D.new()
	_vis.scale = Vector3.ONE * size
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
	_light.light_color = Color(1.0, 0.68, 0.36) if relic_id == "bone" else Color(0.75, 0.45, 1.0)   # r34 crypt: the pit hall's candle-gold, not violet
	_light.omni_range = 3.5 * size
	_light.light_energy = 1.4 + 0.3 * size
	_light.position = Vector3(0, 0.8 * size, 0)
	add_child(_light)
	var motes := Vfx.emitter(Color(2.2, 1.3, 0.45) if relic_id == "bone" else Color(1.3, 0.6, 3.0), {"count": 24, "life": 1.6, "speed": Vector2(0.05, 0.25), "size": 0.03, "gravity": -0.4, "radius": 0.35, "swirl": 1.5, "turbulence": true})
	motes.position = Vector3(0, 0.45 * size, 0)
	motes.scale = Vector3.ONE * size
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
	_vis.position.y = (0.06 + sin(_t * 1.4) * 0.04) * size
	_vis.rotation.y += delta * 0.35
	_light.light_energy = 1.2 + 0.3 * sin(_t * 2.3)


func can_interact() -> bool:
	return VARIANTS.has(relic_id) and not Travel.relics.has(relic_id)


func interact_text() -> String:
	return "[%s]  Take the Bone Reliquary" % Interactable.prompt_key()


## Taking it is permanent: saved at once, and the relic leaves the world. Its two variants are
## swapped at any kindled fire from then on (Brazier -> Reliquary.attune).
func interact_feel() -> StringName:
	return &"cast"


func interact(_by: Node) -> void:
	if Travel.relics.has(relic_id):
		return
	attune(relic_id)
	Travel.give("bone_reliquary", 1)
	Events.toast.emit("Bone Reliquary taken. It is in your satchel [Tab]. Attune it at any kindled fire.")
	SpellFx.rift_in(global_position - Vector3.UP * 1.15)
	remove_from_group(Groups.INTERACTABLE)
	var tw := create_tween()
	tw.tween_property(_vis, "scale", Vector3.ONE * 0.01 * size, 0.6)
	tw.parallel().tween_property(_light, "light_energy", 0.0, 0.6)
	tw.tween_callback(queue_free)


## Cycle (or first set) a relic's variant, save immediately, announce it.
static func attune(id: String) -> void:
	if not VARIANTS.has(id):
		return
	var opts: Array = VARIANTS[id]
	var cur: StringName = Travel.relics.get(id, &"")
	var next: StringName = opts[0] if cur == &"" else opts[(opts.find(cur) + 1) % opts.size()]
	Travel.relics[id] = next
	Travel.save_now()
	Events.toast.emit(TEXT.get(next, String(next)))
	var p := (Engine.get_main_loop() as SceneTree).get_first_node_in_group(Groups.PLAYER) as Node3D
	if p:
		Sfx.play("res://art/audio/ward_chime.wav", p.global_position, -2.0)
