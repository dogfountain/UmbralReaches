class_name Reliquary
extends Interactable
## A relic on an altar. Taking it unlocks a skill variant (Travel.relics[relic_id]); using it
## again swaps between the relic's two variants. See docs/ZONE_PLAN.md §4.

@export var relic_id := "bone"
@export var size := 1.0                 ## the whole shrine scales (the mound's relic is 2.4)

const VARIANTS := {
	"bone": [&"implosion", &"wake"],
	"thorn": [&"splinter", &"briar"],
	# r36: the bell keepers' relics (rares.gd BELL keepers drop them; ItemDB "relic"), one spell each
	"kin": [&"hearth", &"cinder"],          # Lantern Ward  (the Kin-Caller's lamp)
	"slag": [&"scatter", &"brand"],         # Ember Lance   (the Slag-Born's heart)
	"fog": [&"harrow", &"mist"],            # Rift Step     (the Fog-Shepherd's crook)
	"coin": [&"anchor", &"haul"],           # Rift Tether   (the Fare-Caller's coin)
	"seed": [&"bloom", &"wander"],          # Umbral Well   (the Ash-Sower's seed)
	"rope": [&"swarm", &"vigil"],           # Bound Shade   (the Passing-Ringer's rope)
	"mason": [&"toll", &"carillon"],        # Founder's Peal (the Bell-Hewer's mark)
}
## r36: which spell each relic changes (the Kindling's relic page and the tests read it).
const SPELL_OF := {"bone": "nova", "thorn": "bolt", "kin": "ward", "slag": "lance", "fog": "step", "coin": "tether",
	"seed": "well", "rope": "familiar", "mason": "peal"}
const TEXT := {
	&"implosion": "NOVA · IMPLOSION — drags everything within 9.5 m in, marks it, then detonates.",
	&"wake": "NOVA · WAKE — leaves a violet field for 3 s that marks whatever stands in it.",
	&"splinter": "RIFT BOLT · SPLINTER — each bolt bursts into thorns that find and mark up to three more within 4.5 m.",
	&"briar": "RIFT BOLT · BRIAR — whatever a bolt hits is rooted in brambles: slowed hard for 2 s.",
	&"hearth": "LANTERN WARD · HEARTH — burns 2 s shorter, but mends 2 Wounds a second while you stand in it.",
	&"cinder": "LANTERN WARD · CINDER — its edge burns: a foe that crosses it takes 0.6 and a Mark, once a second.",
	&"scatter": "EMBER LANCE · SCATTER — throws three lances in a fan, each at half strength and a smaller burst.",
	&"brand": "EMBER LANCE · BRAND — every foe in the burst is Marked twice; the throw hits 15% softer.",
	&"harrow": "RIFT STEP · HARROW — you arrive Marking every foe within 3.5 m, and the step recovers 30% faster.",
	&"mist": "RIFT STEP · MIST — the place you leave fills with fog for 3 s: foes in it are slowed by half.",
	&"anchor": "RIFT TETHER · ANCHOR — the chain pins the foe where it stands for 2.5 s instead of dragging it, and Marks it twice.",
	&"haul": "RIFT TETHER · HAUL — the chain drags you to any foe, and you land with a shock that throws back what stands near.",
	&"bloom": "UMBRAL WELL · BLOOM — the well pushes foes out of it instead of drawing them in, and slows them harder.",
	&"wander": "UMBRAL WELL · WANDER — the well drifts after the nearest foe, 2.5 m a second, dragging what it passes.",
	&"swarm": "BOUND SHADE · SWARM — binds three small shades at 60% strength, for 10 s.",
	&"vigil": "BOUND SHADE · VIGIL — the shade keeps watch where you bound it, darting faster, for 6 s longer.",
	&"toll": "FOUNDER'S PEAL · TOLL — one great stroke in a narrow cone: twice the damage, and it staggers twice.",
	&"carillon": "FOUNDER'S PEAL · CARILLON — three quick rings all round you, each a light blow and a Mark.",
}


## r36: the variant attuned for relic `key` (&"" when that relic is not yours).
static func variant(key: String) -> StringName:
	return Travel.relics.get(key, &"")

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
	var line: String = TEXT.get(next, String(next))
	if next == &"implosion" and bool(DB.get_mod("deep", false)):
		line = line.replace("9.5 m", "13 m")        # the Deep Reliquary rite widens the drag
	Events.toast.emit(line)
	var p := (Engine.get_main_loop() as SceneTree).get_first_node_in_group(Groups.PLAYER) as Node3D
	if p:
		Sfx.play("res://art/audio/ward_chime.wav", p.global_position, -2.0)
