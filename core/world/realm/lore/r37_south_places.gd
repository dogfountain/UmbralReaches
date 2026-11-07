extends RefCounted
## The South pass's written lore: waystones, graves, cairns and notices on the southern downs, in the
## oak's shade and by the Well. The carriers are the Waiting Field's builders' (r34_places.gd: a stone, a
## grave, a notice board, a page under a stone), the texts are in lore_db.gd (poi_r37s_* are the
## places' own, built in realm_pois_r37_south.gd). Built by RealmLore after the places reserved their
## ground, so every piece registers a site and keeps clear of the others.

const LK := preload("res://core/world/realm/lore/lore_kit.gd")
const Places := preload("res://core/world/realm/lore/r34_places.gd")


static func build(parent: Node) -> void:
	var L: RefCounted = LK.begin(parent, "SouthPlaces", 37037)
	# --- the Southern Downs ----------------------------------------------------------------------
	Places._way(L, "r37s_down_way", "r37s_site_dway", "downs_track", [40.0, 60.0, 200.0, 215.0, 80.0])
	Places._grave(L, "r37s_down_grave", "r37s_site_dgrave", [Vector2(-22, 214), Vector2(-14, 220), Vector2(30, 218), Vector2(16, 226)], false, 3)
	Places._rune(L, "r37s_down_cairn", "r37s_site_dcairn", [Vector2(-42, 220), Vector2(64, 224), Vector2(104, 218), Vector2(-100, 220)], 0.0)
	# --- the Grandmother Oak ---------------------------------------------------------------------
	Places._notice(L, "r37s_oak_notice", "r37s_site_onotice", [Vector2(-64, 173), Vector2(-76, 174), Vector2(-60, 176), Vector2(-80, 177)])   # on the approach, past the earth heaped round the roots
	# --- the Well of Echoes ----------------------------------------------------------------------
	Places._page_stone(L, "r37s_well_page", "r37s_site_wpage", [Vector2(34, 190), Vector2(36, 204), Vector2(108, 196), Vector2(112, 186)])
	L.finish()
	L.note("The Southern Downs", Vector3(0, 0, 210))
