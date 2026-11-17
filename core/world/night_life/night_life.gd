extends Node
## THE LIVING NIGHT, one node that holds every system of the night's light and life (Luke: "brighter landmarks with
## fire lights, mysteries etc, with a darker moon"; "a living night where lights change across the hours and react to
## the player"). The moon is darker; the land is dark; the places that matter carry their own light and are walked toward.
##   light_signatures  far cards and ground pools for every fire, window, tower and mystery (night_registry rows)
##   mystery_lights    a cold light on every unfound secret, a flare when it is found
##   fixture_pool      ten real lights lent to the nearest rows without one
##   living_windows    cottages that light at dusk, gutter out late, stir as the wanderer passes
##   moon_course       the moon's slow course, its cloud veils, and the one eclipse of the run
##   kindling_surge    a kindled brazier's ring of heat, its far surge, the cold fires that glint in answer
##   light_moths       moths at every fire, a scatter when he runs, moths to his own lantern when he stands
##   fog_banks         drifting mist stained warm and cold by what burns in it
##   hit_reads         rings, starbursts, a death's rising motes, tinted by damage school
##   telegraph_glow    the caster lit amber as it winds up, the interruptible one cold; the snap of a broken cast
##   wanderer_life     warming his hands at a fire, a hand to the moths, his lantern swelling in the eclipse
## Villagers' new gestures and their de-synced gait live in core/life/village (villager_fidgets.gd).
## Settings.night_life (Settings > Effects > Living Night) switches the lot off at once: cards and pools hide, lent
## lights go dark, the moon returns to its fixed place, effects stop. Attached by world/main.gd after the atmosphere.
## Cost (measured by reading, not yet timed in the engine): three MultiMesh draws, about twenty lights' worth of
## uniform writes a second, ten unshadowed lights, no shaders compiled at runtime but the stock material.

const Reg := preload("res://core/world/night_life/night_registry.gd")
const Signatures := preload("res://core/world/night_life/light_signatures.gd")
const Pool := preload("res://core/world/night_life/fixture_pool.gd")
const Windows := preload("res://core/world/night_life/living_windows.gd")
const Mysteries := preload("res://core/world/night_life/mystery_lights.gd")
const Course := preload("res://core/world/night_life/moon_course.gd")
const Surge := preload("res://core/world/night_life/kindling_surge.gd")
const Moths := preload("res://core/world/night_life/light_moths.gd")
const Banks := preload("res://core/world/night_life/fog_banks.gd")
const Hits := preload("res://core/world/night_life/hit_reads.gd")
const Tells := preload("res://core/world/night_life/telegraph_glow.gd")
const Wanderer := preload("res://core/world/night_life/wanderer_life.gd")

var _poll := 0.0


## Attach to the night's root (once).
static func attach(root: Node) -> void:
	if root.get_node_or_null("NightLife") != null:
		return
	var n := (load("res://core/world/night_life/night_life.gd") as GDScript).new() as Node
	n.name = "NightLife"
	root.add_child(n)


func _ready() -> void:
	Reg.clear()
	Reg.enabled = Settings.night_life
	var root := get_parent()
	var moon := root.get_node_or_null("Moon") as DirectionalLight3D
	var we := root.get_node_or_null("WorldEnvironment") as WorldEnvironment
	_add(Signatures.new(), "LightSignatures")
	_add(Pool.new(), "FixturePool")
	_add(Windows.new(), "LivingWindows")
	_add(Mysteries.new(), "MysteryLights")
	var course := Course.new()
	course.moon = moon
	course.env = we.environment if we != null else null
	course.fill = moon.get_parent().get_node_or_null("NightFill") as DirectionalLight3D if moon != null else null
	_add(course, "MoonCourse")
	_add(Surge.new(), "KindlingSurge")
	_add(Moths.new(), "LightMoths")
	_add(Banks.new(), "FogBanks")
	_add(Hits.new(), "HitReads")
	_add(Tells.new(), "TelegraphGlow")
	_add(Wanderer.new(), "WandererLife")


func _add(n: Node, nm: String) -> void:
	n.name = nm
	add_child(n)


func _process(delta: float) -> void:
	_poll -= delta
	if _poll <= 0.0:
		_poll = 0.5
		Reg.enabled = Settings.night_life
