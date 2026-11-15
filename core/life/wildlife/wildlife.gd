extends RefCounted
## The life system's Realm module (docs/LIFE_PLAN.md): wildlife, weather and ambience. Realm.build
## calls `build(root)` after progression and village. Everything lives under one node, "Wildlife"
## (life_director.gd), which places the creatures from what the Realm built and runs the weather.
##   moths round flames, fireflies, bats over the rift   shader-only MultiMesh flocks (no script time)
##   crows, owls, herons, deer, foxes, rats, the elk     small state machines, one MultiMesh per group
##   frogs, fish rings, drizzle rings                    per fen pool (life_pond.gd)
##   mist banks, drizzle, gusts, thunder on the Crowns   weather.gd
## Test alone: godot --path . -- --realm-modules=land,rift,bosses,lore,flora,life
## Tests: zz/life_test.tscn.  Sounds: zz/life_gen_audio.tscn writes art/audio/life/*.wav.

const Director := preload("res://core/life/wildlife/life_director.gd")
const Wayfarers := preload("res://core/life/wayfarers/wayfarers.gd")       ## people on the roads (docs/living_realm.md)


static func build(root: Node) -> void:
	if root.get_node_or_null("Wildlife") != null:
		return
	var t := Time.get_ticks_usec()
	var d := Director.new()
	d.name = "Wildlife"
	root.add_child(d)
	d.setup(root)
	Realm.prof_add("life: wildlife", t)
	Wayfarers.build(root)
