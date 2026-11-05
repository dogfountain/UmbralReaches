extends RefCounted
## Realm module "encounters" (docs/LIFE_PLAN.md): danger, pacing and the endgame. Built last by
## Realm.build; everything lives in core/life/encounters (director.gd is the live system).
##   godot --path . -- --realm-modules=land,rift,bosses,lore,flora,encounters

const Director := preload("res://core/life/encounters/director.gd")


static func build(root: Node) -> void:
	if root == null or root.get_node_or_null("Encounters") != null:
		return
	var t0 := Time.get_ticks_msec()
	await root.get_tree().physics_frame
	var d := Director.new()
	root.add_child(d)
	d.setup(root as Node3D)
	print("REALM encounters: %d ms" % (Time.get_ticks_msec() - t0))
