extends RefCounted
## The South pass's two hidden things, each beside a place the player already has a reason to climb to:
##   oak_crown      THE CROWN OF THE OAK (Grandmother Oak): on the crown deck at the top of the stair, in a
##                  hollow of the broken rim, the Rooted's casket of the first fire's oak-knot and a leaf
##                  of their reckoning. Reached by the 170-tread stair inside the trunk, or by gliding in
##                  off a limb.
##   well_listener  THE LISTENER'S CAIRN (Well of Echoes): on the landing where the ledge path crosses
##                  under the waterfall, a cairn of listening stones and a box left by whoever sat there
##                  to hear the Well answer. You have to walk through the fall to reach it.
## State: the secrets' own (State: looted.*, found.*, pages.*). Texts: pages.gd.

const Kit := preload("res://core/life/secrets/kit.gd")
const State := preload("res://core/life/secrets/state.gd")
const LK := preload("res://core/world/realm/lore/lore_kit.gd")
const South := preload("res://core/world/realm/realm_pois_r37_south.gd")


static func build(root: Node, host: Node3D) -> void:
	var pois := root.get_node_or_null("RealmPois")
	if pois == null:
		print("SECRETS south: no places built")
		return
	var south := pois.get_node_or_null("R37South")
	if south == null:
		print("SECRETS south: the South pass is not built")
		return
	_crown(root, host, south.get_node_or_null("Poi_r37s_oak") as Node3D)
	_listener(root, host, south.get_node_or_null("Poi_r37s_well") as Node3D)


static func _bx(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


# --- the Crown of the Oak ----------------------------------------------------------------------

static func _crown(root: Node, host: Node3D, oak: Node3D) -> void:
	if oak == null or not oak.has_meta("crown"):
		print("SECRETS crown of the oak: no oak")
		return
	var crown: Vector3 = oak.get_meta("crown")
	var xf: Transform3D = oak.get_meta("oak_xf")
	var node := Node3D.new()
	node.name = "OakCrown"
	node.set_meta("site", "secrets_oak_crown")
	host.add_child(node)
	LK.ensure_mats()
	var k := OssKit.new()
	k.keep_lanes = false
	var b := xf.basis
	# a knot of oak-heart as big as a bread-oven, hollowed, set into the deck against the rim, with a
	# plank lid; a lean of roots over it
	var kn := crown
	k.box("wood", kn + Vector3(0, 0.3, 0), Vector3(1.3, 0.6, 0.9), b, true, 0.7)
	k.box("wood", kn + Vector3(0, 0.62, 0), Vector3(1.4, 0.1, 1.0), b, false, 0.6)
	k.box("iron", kn + Vector3(0, 0.42, 0.46), Vector3(0.9, 0.06, 0.04), b, false, 0.7)
	for i in 3:
		k.box("wood", kn + b * Vector3(-0.9 + 0.9 * float(i), 1.1, -0.5), Vector3(0.1, 2.2, 0.1), b * Basis(Vector3.BACK, 0.12 * float(i - 1)), false, 0.5)
	k.commit(node, "CrownBody")
	var lid := Kit.mi(node, _bx(Vector3(1.4, 0.1, 1.0)), OssKit.mat("wood"), Transform3D(b, kn + Vector3(0, 0.67, 0)), 80.0)
	var open_lid := func(_animate: bool) -> void:
		if is_instance_valid(lid):
			lid.position = kn + b * Vector3(0.7, 0.9, 0.0)
			lid.rotation = Vector3(0.0, 0.0, -0.7)
	var sync := func(animate: bool) -> void:
		if State.has("looted", "oak_crown"):
			open_lid.call(animate)
	State.cache(node, "oak_crown", kn + Vector3(0, 0.9, 0), "the Rooted's casket", open_lid)
	State.reading(node, "sc_oak_top", crown + b * Vector3(1.2, 0.9, 0.8))
	Kit.site(root, "secrets_oak_crown", Rect2(crown.x - 2.0, crown.z - 2.0, 4.0, 4.0), crown.y - 30.0)
	var ground := crown
	ground.y = RealmLayout.ground(Kit.space(root), crown.x, crown.z)
	State.register({"id": "oak_crown", "name": "The Crown of the Oak", "at": crown, "r": 4.2, "node": node, "climb_only": true, "foot": ground, "sync": sync})
	print("SECRETS crown of the oak at %s (%.1f m up)" % [crown.snapped(Vector3.ONE * 0.1), crown.y - ground.y])


# --- the Listener's Cairn ----------------------------------------------------------------------

static func _listener(root: Node, host: Node3D, well: Node3D) -> void:
	var info: Dictionary = South.well
	if well == null or not info.has("listener"):
		print("SECRETS listener's cairn: no ledge landing under the fall")
		return
	var pos: Vector3 = info.listener
	var bs: Basis = info.listener_basis
	var node := Node3D.new()
	node.name = "ListenerCairn"
	node.set_meta("site", "secrets_well_listener")
	host.add_child(node)
	LK.ensure_mats()
	var k := OssKit.new()
	k.keep_lanes = false
	var wall := -bs.x                                 # the wall side of the landing
	var c := pos + wall * 1.35 + Vector3.UP * 0.02
	var rng := RandomNumberGenerator.new()
	rng.seed = 37501
	# a cairn of flat listening stones, an ear's height, each one a little off the one below
	for i in 7:
		var w := 0.9 - 0.09 * float(i)
		k.box("lore_rock", c + Vector3(rng.randf_range(-0.05, 0.05), 0.12 + 0.2 * float(i), rng.randf_range(-0.05, 0.05)), Vector3(w, 0.2, w * 0.85), bs * Basis(Vector3.UP, rng.randf() * TAU), true, rng.randf_range(0.8, 0.9))
	# a box left beside it, and a stone to sit on and hear
	var bx := pos + wall * 1.2 + bs.z * 1.3
	k.box("wood", bx + Vector3(0, 0.22, 0), Vector3(0.7, 0.44, 0.45), bs, true, 0.7)
	k.box("lore_rock", pos + wall * 0.9 - bs.z * 1.4 + Vector3(0, 0.18, 0), Vector3(1.1, 0.36, 0.5), bs, true, 0.85)
	k.commit(node, "ListenerBody")
	var lid := Kit.mi(node, _bx(Vector3(0.7, 0.1, 0.45)), OssKit.mat("wood"), Transform3D(bs, bx + Vector3(0, 0.48, 0)), 60.0)
	var open_lid := func(_animate: bool) -> void:
		if is_instance_valid(lid):
			lid.position = bx + Vector3(0.0, 0.7, 0.0)
			lid.rotation = Vector3(0.0, 0.0, -0.8)
	var sync := func(animate: bool) -> void:
		if State.has("looted", "well_listener"):
			open_lid.call(animate)
	State.cache(node, "well_listener", bx + Vector3(0, 0.7, 0), "the listener's box", open_lid)
	State.reading(node, "sc_well_listener", c + Vector3(0, 1.8, 0))
	Kit.site(root, "secrets_well_listener", Rect2(pos.x - 3.0, pos.z - 3.0, 6.0, 6.0), pos.y - 3.0)
	State.register({"id": "well_listener", "name": "The Listener's Cairn", "at": pos, "r": 5.0, "node": node, "sync": sync})
	print("SECRETS listener's cairn at %s" % [pos.snapped(Vector3.ONE * 0.1)])
