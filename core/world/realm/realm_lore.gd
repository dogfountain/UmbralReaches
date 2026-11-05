extends RefCounted
## RealmLore (module 5, docs/REALM_PLAN.md): the valley's landmarks and its written lore.
## Builds, under one `RealmLore` node, Hearthward (the village round the spawn brazier, not the
## tavern), the Chapel of the First Kindling, the Pilgrims' Road (gates, waystones, graves, cart,
## shrine), the Glimmer Glade's shrine to the lost, the Barrow Field and the Hollow Fen's drowned
## graves, and the Thornwood's ruins and tablets. Every structure registers a WorldLanes site and
## sits under a holder with meta "site". Texts: lore_db.gd; canon: docs/LORE.md.
## Builders live in core/world/realm/lore/ (no class_name; preloaded by path).

const LK := preload("res://core/world/realm/lore/lore_kit.gd")
const CODEX := "res://ui/codex.gd"
const PARTS := [
	"res://core/world/realm/lore/hearthward.gd",
	"res://core/world/realm/lore/chapel.gd",
	"res://core/world/realm/lore/road.gd",
	"res://core/world/realm/lore/glade.gd",
	"res://core/world/realm/lore/barrows.gd",
	"res://core/world/realm/lore/wilds.gd",
	"res://core/world/realm/lore/rim.gd",
	"res://core/world/realm/lore/r34_places.gd",     # r34 places: the new ground's writings (docs/r34/places.md)
]


static func build(root: Node) -> void:
	if root.get_node_or_null("RealmLore") != null:
		return
	LK.reset()
	# the Journal (reading panel, region banners, the book): one CanvasLayer on the zone
	if root.get_node_or_null("Codex") == null and ResourceLoader.exists(CODEX):
		var cx: Node = (load(CODEX) as GDScript).new()
		cx.name = "Codex"
		root.add_child(cx)
	var holder := Node3D.new()
	holder.name = "RealmLore"
	holder.set_meta("site", "realm_lore")
	root.add_child(holder)
	await root.get_tree().physics_frame
	for path: String in PARTS:
		if not ResourceLoader.exists(path):
			continue
		var s := load(path) as GDScript
		if s == null or not s.can_instantiate():
			push_error("RealmLore: %s failed to load" % path)
			continue
		var t := Time.get_ticks_msec()
		s.call("build", holder)
		print("REALM_LORE %s in %d ms" % [path.get_file().get_basename(), Time.get_ticks_msec() - t])
	holder.set_meta("scraps", LK.scraps.size())
	print("REALM_LORE built: %d inscriptions, %d sites, %d lights, %d landmarks, %d mesh instances" % [LK.scraps.size(), LK.site_names.size(), LK.lights_used, LK.landmarks.size(), LK.draws_total])
