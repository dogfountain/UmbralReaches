extends RefCounted
## West Marches: the places' writings (graves, notices, pages) laid along the new ground by RealmLore,
## in the manner of doubled_realm_places.gd (same carriers, same camp keep-out). Texts: west_marches_texts.gd. Built
## before the stamp and the flora, so every piece registers a site and keeps clear of the others.

const LK := preload("res://core/world/realm/lore/lore_kit.gd")
const DoubledPlaces := preload("res://core/world/realm/lore/doubled_realm_places.gd")


static func build(parent: Node) -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--no-r37-west":
			return
	var L: RefCounted = LK.begin(parent, "R37WestPlaces", 37037)
	# --- Weirford ------------------------------------------------------------------------------
	DoubledPlaces._grave(L, "wf_grave", "r37w_wf_grave", [Vector2(-226.0, 74.0), Vector2(-228.0, 77.5), Vector2(-224.0, 78.5)], false, 4)
	# --- the Sorrow's Banks --------------------------------------------------------------------
	DoubledPlaces._notice(L, "sr_ford", "r37w_sr_ford", [Vector2(-194.0, -26.0), Vector2(-186.0, -18.0), Vector2(-192.0, -34.0)])
	DoubledPlaces._grave(L, "sr_reeve", "r37w_sr_reeve", [Vector2(-228.0, -22.0), Vector2(-224.0, -34.0), Vector2(-232.0, -12.0)], true)
	DoubledPlaces._page_stone(L, "sr_boats", "r37w_sr_boats", [Vector2(-222.0, 8.0), Vector2(-226.0, -2.0), Vector2(-214.0, 24.0)])
	# --- the Fallen Hierarch -------------------------------------------------------------------
	DoubledPlaces._notice(L, "hr_warning", "r37w_hr_warning", [Vector2(-194.0, -80.0), Vector2(-198.0, -72.0), Vector2(-190.0, -86.0)])
	DoubledPlaces._grave(L, "hr_mason", "r37w_hr_mason", [Vector2(-238.0, -94.0), Vector2(-244.0, -88.0), Vector2(-232.0, -100.0)], false, 1)
	DoubledPlaces._page_stone(L, "hr_boy", "r37w_hr_boy", [Vector2(-196.0, -96.0), Vector2(-200.0, -100.0), Vector2(-192.0, -90.0)])
	# --- the Siege Lines -------------------------------------------------------------------------
	DoubledPlaces._page_stone(L, "sg_roll_1", "r37w_sg_roll_1", [Vector2(-210.0, 132.0), Vector2(-216.0, 140.0), Vector2(-204.0, 126.0)])
	DoubledPlaces._page_stone(L, "sg_roll_2", "r37w_sg_roll_2", [Vector2(-226.0, 176.0), Vector2(-230.0, 184.0), Vector2(-220.0, 168.0)])
	DoubledPlaces._page_stone(L, "sg_roll_3", "r37w_sg_roll_3", [Vector2(-196.0, 218.0), Vector2(-188.0, 224.0), Vector2(-204.0, 214.0)])
	DoubledPlaces._grave(L, "sg_grave", "r37w_sg_grave", [Vector2(-210.0, 160.0), Vector2(-200.0, 170.0), Vector2(-216.0, 156.0)], true, 0)
	L.finish()
	L.note("The Outer Marches, west (r37)", Vector3(-214.0, 0.0, 40.0))
